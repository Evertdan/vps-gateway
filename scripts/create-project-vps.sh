#!/bin/bash
# create-project-vps.sh - Script que corre en el VPS
# Uso: sudo ./create-project-vps.sh --project=nombre --client=cliente --port=3000 --acme-file=/path/to/credentials.json

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables
PROJECT_NAME=""
CLIENT_NAME=""
LOCAL_PORT=""
ACME_FILE=""
SERVER_IP="195.26.244.180"
DOMAIN="vps1.dgetahgo.edu.mx"
PROJECTS_REGISTRY="/opt/projects/registry.json"
VPN_SCRIPTS="/home/usuario/vpn-scripts"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
LETSENCRYPT_DIR="/etc/letsencrypt"
LOG_FILE="/var/log/create-project.log"

# Funciones de log
log_info() { 
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}
log_warn() { 
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}
log_error() { 
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}
log_step() { 
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}
log_detail() { 
    echo -e "${CYAN}  →${NC} $1" | tee -a "$LOG_FILE"
}

# Inicializar log
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "========================================" >> "$LOG_FILE"
echo "Script iniciado: $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# ============================================
# FUNCIÓN: Validar prerequisitos del sistema
# ============================================
validate_prerequisites() {
    log_step "VALIDACIÓN 1/10: Verificando prerequisitos del sistema..."
    
    local errors=0
    
    # Verificar directorios
    log_detail "Verificando directorios..."
    for dir in "$VPN_SCRIPTS" "/home/usuario/vpn-clients" "/opt/openvpn/data/ccd" "/opt/projects"; do
        if [[ ! -d "$dir" ]]; then
            log_warn "Creando directorio: $dir"
            mkdir -p "$dir"
        fi
    done
    
    # Verificar scripts VPN
    log_detail "Verificando scripts VPN..."
    if [[ ! -f "$VPN_SCRIPTS/vpn-generate-client.sh" ]]; then
        log_error "Falta script: $VPN_SCRIPTS/vpn-generate-client.sh"
        ((errors++))
    fi
    
    # Verificar Docker
    log_detail "Verificando Docker..."
    if ! docker ps &>/dev/null; then
        log_error "Docker no está corriendo"
        ((errors++))
    fi
    
    # Verificar OpenVPN container
    log_detail "Verificando OpenVPN..."
    if ! docker ps | grep -q openvpn; then
        log_error "Contenedor OpenVPN no está corriendo"
        ((errors++))
    fi
    
    # Verificar acme-dns
    log_detail "Verificando acme-dns..."
    if ! systemctl is-active acme-dns &>/dev/null; then
        log_error "acme-dns no está corriendo"
        ((errors++))
    fi
    
    # Verificar Nginx
    log_detail "Verificando Nginx..."
    if ! systemctl is-active nginx &>/dev/null; then
        log_error "Nginx no está corriendo"
        ((errors++))
    fi
    
    # Verificar certbot
    log_detail "Verificando Certbot..."
    if ! command -v certbot &>/dev/null; then
        log_error "Certbot no está instalado"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Hay $errors errores de prerequisitos. Corrígelos antes de continuar."
        exit 1
    fi
    
    log_info "✅ Prerequisitos OK"
    return 0
}

# ============================================
# FUNCIÓN: Parsear argumentos
# ============================================
parse_arguments() {
    log_step "VALIDACIÓN 2/10: Parseando argumentos..."
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project=*) PROJECT_NAME="${1#*=}" ;;
            --client=*) CLIENT_NAME="${1#*=}" ;;
            --port=*) LOCAL_PORT="${1#*=}" ;;
            --acme-file=*) ACME_FILE="${1#*=}" ;;
            *) log_error "Opción desconocida: $1"; exit 1 ;;
        esac
        shift
    done
    
    # Validaciones
    if [[ -z "$PROJECT_NAME" || -z "$CLIENT_NAME" || -z "$LOCAL_PORT" ]]; then
        log_error "Faltan argumentos requeridos: --project, --client, --port"
        exit 1
    fi
    
    if [[ -z "$ACME_FILE" || ! -f "$ACME_FILE" ]]; then
        log_error "Archivo de credenciales ACME no válido: $ACME_FILE"
        exit 1
    fi
    
    if [[ ! "$PROJECT_NAME" =~ ^[a-z0-9-]+$ ]]; then
        log_error "Nombre de proyecto inválido. Usar solo minúsculas, números y guiones"
        exit 1
    fi
    
    log_info "✅ Argumentos válidos:"
    log_detail "Proyecto: $PROJECT_NAME"
    log_detail "Cliente: $CLIENT_NAME"
    log_detail "Puerto: $LOCAL_PORT"
}

# ============================================
# FUNCIÓN: Verificar si proyecto ya existe
# ============================================
check_existing_project() {
    log_step "VALIDACIÓN 3/10: Verificando proyecto existente..."
    
    local full_domain="${PROJECT_NAME}.${DOMAIN}"
    
    # Verificar en registry
    if [[ -f "$PROJECTS_REGISTRY" ]]; then
        local existing=$(python3 -c "
import json
import sys
try:
    with open('$PROJECTS_REGISTRY', 'r') as f:
        data = json.load(f)
    if '$PROJECT_NAME' in data.get('projects', {}):
        print('EXISTE')
    else:
        print('NUEVO')
except:
    print('NUEVO')
")
        if [[ "$existing" == "EXISTE" ]]; then
            log_warn "El proyecto '$PROJECT_NAME' ya existe en el registry"
            read -p "¿Continuar de todos modos? (s/N): " response
            if [[ "$response" != "s" && "$response" != "S" ]]; then
                log_info "Cancelado por el usuario"
                exit 0
            fi
        fi
    fi
    
    # Verificar si existe config nginx
    if [[ -f "$NGINX_AVAILABLE/$full_domain" ]]; then
        log_warn "Configuración Nginx ya existe: $full_domain"
    fi
    
    # Verificar si existe certificado SSL
    if [[ -d "$LETSENCRYPT_DIR/live/$full_domain" ]]; then
        log_warn "Certificado SSL ya existe: $full_domain"
    fi
    
    log_info "✅ Verificación completada"
}

# ============================================
# FUNCIÓN: Crear cliente VPN
# ============================================
create_vpn_client() {
    log_step "PASO 4/10: Creando cliente VPN..."
    
    VPN_IP=""
    
    # Verificar si cliente ya existe
    if [[ -f "/opt/openvpn/data/ccd/$CLIENT_NAME" ]]; then
        log_warn "Cliente VPN ya existe, obteniendo IP..."
        VPN_IP=$(cat "/opt/openvpn/data/ccd/$CLIENT_NAME" | grep ifconfig-push | awk '{print $2}')
        log_info "✅ Usando IP existente: $VPN_IP"
        return 0
    fi
    
    # Obtener siguiente IP disponible
    log_detail "Calculando IP disponible..."
    
    NEXT_IP=$(python3 << 'PYTHON'
import json
import sys
import os

registry_path = "/opt/projects/registry.json"

try:
    if not os.path.exists(registry_path):
        data = {"projects": {}, "clients": {}, "ip_pool": {"next_ip": 10}}
    else:
        with open(registry_path, "r") as f:
            data = json.load(f)
    
    next_ip = data.get("ip_pool", {}).get("next_ip", 10)
    
    # Verificar IPs en uso
    used_ips = set()
    for client, info in data.get("clients", {}).items():
        if "vpn_ip" in info:
            ip_parts = info["vpn_ip"].split(".")
            if len(ip_parts) == 4:
                used_ips.add(int(ip_parts[3]))
    
    # Verificar archivos CCD
    ccd_dir = "/opt/openvpn/data/ccd"
    if os.path.exists(ccd_dir):
        for filename in os.listdir(ccd_dir):
            filepath = os.path.join(ccd_dir, filename)
            try:
                with open(filepath, 'r') as f:
                    for line in f:
                        if 'ifconfig-push' in line:
                            parts = line.split()
                            if len(parts) >= 2:
                                ip_parts = parts[1].split(".")
                                if len(ip_parts) == 4:
                                    used_ips.add(int(ip_parts[3]))
            except:
                pass
    
    # Encontrar IP disponible
    while next_ip in used_ips:
        next_ip += 1
        if next_ip > 100:
            print("ERROR: Pool de IPs agotado (10-100)", file=sys.stderr)
            sys.exit(1)
    
    print(next_ip)
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON
)
    
    if [[ "$NEXT_IP" == "ERROR"* ]] || [[ -z "$NEXT_IP" ]]; then
        log_error "No se pudo obtener IP disponible"
        exit 1
    fi
    
    VPN_IP="192.168.255.${NEXT_IP}"
    log_detail "IP asignada: $VPN_IP"
    
    # Generar certificado
    log_detail "Generando certificado cliente..."
    if ! "$VPN_SCRIPTS/vpn-generate-client.sh" "$CLIENT_NAME"; then
        log_error "Falló la generación del certificado VPN"
        exit 1
    fi
    
    # Verificar que se creó el archivo .ovpn
    if [[ ! -f "/home/usuario/vpn-clients/${CLIENT_NAME}.ovpn" ]]; then
        log_error "No se encontró archivo .ovpn del cliente"
        exit 1
    fi
    
    log_detail "Archivo .ovpn creado"
    
    # Crear archivo CCD
    log_detail "Creando configuración CCD..."
    echo "ifconfig-push $VPN_IP 255.255.255.0" > "/opt/openvpn/data/ccd/$CLIENT_NAME"
    chmod 644 "/opt/openvpn/data/ccd/$CLIENT_NAME"
    
    # Actualizar registry
    python3 << PYTHON
import json
import os

registry_path = "/opt/projects/registry.json"

if not os.path.exists(registry_path):
    data = {"projects": {}, "clients": {}, "ip_pool": {"next_ip": 10}}
else:
    with open(registry_path, "r") as f:
        data = json.load(f)

if "clients" not in data:
    data["clients"] = {}
if "ip_pool" not in data:
    data["ip_pool"] = {"next_ip": 10}

data["clients"]["$CLIENT_NAME"] = {
    "vpn_ip": "$VPN_IP",
    "created_at": "$(date -Iseconds)"
}

# Actualizar next_ip si es necesario
current_next = data["ip_pool"].get("next_ip", 10)
if $NEXT_IP >= current_next:
    data["ip_pool"]["next_ip"] = $NEXT_IP + 1

with open(registry_path, "w") as f:
    json.dump(data, f, indent=2)

print(f"Registry actualizado: $CLIENT_NAME -> $VPN_IP")
PYTHON
    
    log_info "✅ Cliente VPN creado exitosamente"
    log_detail "IP: $VPN_IP"
    log_detail "Config: /home/usuario/vpn-clients/${CLIENT_NAME}.ovpn"
}

# ============================================
# FUNCIÓN: Emitir certificado SSL
# ============================================
issue_ssl_certificate() {
    log_step "PASO 5/10: Emitiendo certificado SSL..."
    
    local full_domain="${PROJECT_NAME}.${DOMAIN}"
    local cert_path="$LETSENCRYPT_DIR/live/$full_domain"
    
    # Verificar si ya existe certificado
    if [[ -d "$cert_path" && -f "$cert_path/fullchain.pem" ]]; then
        log_warn "Certificado SSL ya existe"
        log_detail "Ruta: $cert_path"
        return 0
    fi
    
    # Leer credenciales ACME
    log_detail "Leyendo credenciales acme-dns..."
    
    ACME_FULLDOMAIN=$(cat "$ACME_FILE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('fulldomain', ''))")
    ACME_SUBDOMAIN=$(cat "$ACME_FILE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('subdomain', ''))")
    ACME_USER=$(cat "$ACME_FILE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('username', ''))")
    ACME_KEY=$(cat "$ACME_FILE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('password', ''))")
    
    if [[ -z "$ACME_FULLDOMAIN" || -z "$ACME_SUBDOMAIN" || -z "$ACME_USER" || -z "$ACME_KEY" ]]; then
        log_error "Credenciales ACME incompletas"
        exit 1
    fi
    
    log_detail "ACME fulldomain: $ACME_FULLDOMAIN"
    
    # Verificar que DNS esté propagado
    log_detail "Verificando propagación DNS..."
    local dns_propagated=false
    for i in {1..10}; do
        local cname_check=$(dig +short "_acme-challenge.${full_domain}" CNAME @8.8.8.8 2>/dev/null || echo "")
        if [[ "$cname_check" == *"auth.dgetahgo.edu.mx"* ]]; then
            log_info "✅ DNS propagado correctamente"
            dns_propagated=true
            break
        fi
        log_detail "Esperando propagación DNS... ($i/10)"
        sleep 5
    done
    
    if [[ "$dns_propagated" == "false" ]]; then
        log_warn "⚠️  DNS no se propagó completamente, intentando de todos modos..."
    fi
    
    # Crear script de hook
    local hook_script="/tmp/acme-hook-${PROJECT_NAME}.sh"
    cat > "$hook_script" << 'HOOK'
#!/bin/bash
# ACME-DNS Auth Hook
API_URL="https://auth.dgetahgo.edu.mx:8444/update"
ACME_USER="USER_PLACEHOLDER"
ACME_KEY="KEY_PLACEHOLDER"
ACME_SUBDOMAIN="SUBDOMAIN_PLACEHOLDER"

curl -sk -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -H "X-Api-User: $ACME_USER" \
    -H "X-Api-Key: $ACME_KEY" \
    -d "{\"subdomain\": \"$ACME_SUBDOMAIN\", \"txt\": \"$CERTBOT_VALIDATION\"}"

# Dar tiempo a la propagación
sleep 10
HOOK
    
    # Reemplazar placeholders
    sed -i "s/USER_PLACEHOLDER/$ACME_USER/g" "$hook_script"
    sed -i "s/KEY_PLACEHOLDER/$ACME_KEY/g" "$hook_script"
    sed -i "s/SUBDOMAIN_PLACEHOLDER/$ACME_SUBDOMAIN/g" "$hook_script"
    chmod +x "$hook_script"
    
    log_detail "Ejecutando certbot..."
    
    # Ejecutar certbot
    if certbot certonly \
        --manual \
        --preferred-challenges dns \
        --manual-auth-hook "$hook_script" \
        --manual-cleanup-hook "/bin/true" \
        --manual-public-ip-logging-ok \
        --agree-tos \
        --email infraestructura@computocontable.com \
        -d "$full_domain" \
        --non-interactive \
        --quiet; then
        
        log_info "✅ Certificado SSL emitido exitosamente"
        
        # Verificar archivos
        if [[ -f "$cert_path/fullchain.pem" && -f "$cert_path/privkey.pem" ]]; then
            log_detail "Certificado: $cert_path/fullchain.pem"
            log_detail "Private key: $cert_path/privkey.pem"
        else
            log_error "Certificado no encontrado en ruta esperada"
            exit 1
        fi
    else
        log_error "❌ Falló la emisión del certificado SSL"
        log_detail "Revisa los logs de certbot"
        exit 1
    fi
    
    # Limpiar hook
    rm -f "$hook_script"
}

# ============================================
# FUNCIÓN: Configurar Nginx
# ============================================
configure_nginx() {
    log_step "PASO 6/10: Configurando Nginx..."
    
    local full_domain="${PROJECT_NAME}.${DOMAIN}"
    local nginx_config="$NGINX_AVAILABLE/$full_domain"
    local cert_path="$LETSENCRYPT_DIR/live/$full_domain"
    
    # Verificar si ya existe
    if [[ -f "$nginx_config" ]]; then
        log_warn "Configuración Nginx ya existe: $full_domain"
        return 0
    fi
    
    # Verificar que existe certificado
    if [[ ! -f "$cert_path/fullchain.pem" ]]; then
        log_error "No existe certificado SSL para $full_domain"
        exit 1
    fi
    
    log_detail "Creando configuración..."
    
    cat > "$nginx_config" << EOF
# Proyecto: $PROJECT_NAME
# Cliente: $CLIENT_NAME
# Creado: $(date)

server {
    listen 443 ssl http2;
    server_name $full_domain;
    
    # SSL
    ssl_certificate $cert_path/fullchain.pem;
    ssl_certificate_key $cert_path/privkey.pem;
    ssl_trusted_certificate $cert_path/chain.pem;
    
    # SSL moderno
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    
    # Proxy al cliente VPN
    location / {
        proxy_pass http://$VPN_IP:$LOCAL_PORT;
        proxy_http_version 1.1;
        
        # Headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts (importante para VPN)
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering off;
        proxy_request_buffering off;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name $full_domain;
    return 301 https://\$server_name\$request_uri;
}
EOF
    
    log_detail "Configuración creada: $nginx_config"
    
    # Habilitar sitio
    log_detail "Habilitando sitio..."
    ln -sf "$nginx_config" "$NGINX_ENABLED/$full_domain"
    
    # Test configuración
    log_detail "Validando configuración Nginx..."
    if nginx -t; then
        log_info "✅ Configuración Nginx válida"
    else
        log_error "❌ Configuración Nginx inválida"
        rm -f "$nginx_config"
        rm -f "$NGINX_ENABLED/$full_domain"
        exit 1
    fi
    
    # Reload Nginx
    log_detail "Recargando Nginx..."
    if systemctl reload nginx; then
        log_info "✅ Nginx recargado exitosamente"
    else
        log_error "❌ Falló el reload de Nginx"
        exit 1
    fi
    
    log_detail "Proxy configurado: $full_domain → $VPN_IP:$LOCAL_PORT"
}

# ============================================
# FUNCIÓN: Registrar proyecto
# ============================================
register_project() {
    log_step "PASO 7/10: Registrando proyecto..."
    
    local full_domain="${PROJECT_NAME}.${DOMAIN}"
    
    python3 << PYTHON
import json
import os

registry_path = "/opt/projects/registry.json"

# Leer registry actual
if not os.path.exists(registry_path):
    data = {"projects": {}, "clients": {}, "ip_pool": {"next_ip": 10}}
else:
    with open(registry_path, "r") as f:
        data = json.load(f)

# Inicializar estructuras
if "projects" not in data:
    data["projects"] = {}
if "clients" not in data:
    data["clients"] = {}
if "ip_pool" not in data:
    data["ip_pool"] = {"next_ip": 10}

# Registrar proyecto
data["projects"]["$PROJECT_NAME"] = {
    "client_name": "$CLIENT_NAME",
    "vpn_ip": "$VPN_IP",
    "local_port": $LOCAL_PORT,
    "domain": "$full_domain",
    "ssl": True,
    "created_at": "$(date -Iseconds)",
    "status": "active"
}

# Guardar
with open(registry_path, "w") as f:
    json.dump(data, f, indent=2)

print(f"✅ Proyecto registrado: $PROJECT_NAME")
PYTHON
    
    log_info "✅ Proyecto registrado en $PROJECTS_REGISTRY"
}

# ============================================
# FUNCIÓN: Verificación final
# ============================================
final_verification() {
    log_step "PASO 8/10: Verificación final..."
    
    local full_domain="${PROJECT_NAME}.${DOMAIN}"
    local errors=0
    
    # Verificar VPN
    log_detail "Verificando cliente VPN..."
    if [[ -f "/opt/openvpn/data/ccd/$CLIENT_NAME" ]]; then
        log_detail "✅ CCD config existe"
    else
        log_error "❌ CCD config no encontrado"
        ((errors++))
    fi
    
    if [[ -f "/home/usuario/vpn-clients/${CLIENT_NAME}.ovpn" ]]; then
        log_detail "✅ Archivo .ovpn existe"
    else
        log_error "❌ Archivo .ovpn no encontrado"
        ((errors++))
    fi
    
    # Verificar SSL
    log_detail "Verificando certificado SSL..."
    if [[ -f "$LETSENCRYPT_DIR/live/$full_domain/fullchain.pem" ]]; then
        log_detail "✅ Certificado SSL existe"
        # Verificar fecha de expiración
        local expiry=$(openssl x509 -in "$LETSENCRYPT_DIR/live/$full_domain/fullchain.pem" -noout -enddate 2>/dev/null | cut -d= -f2)
        log_detail "   Expira: $expiry"
    else
        log_error "❌ Certificado SSL no encontrado"
        ((errors++))
    fi
    
    # Verificar Nginx
    log_detail "Verificando Nginx..."
    if [[ -f "$NGINX_AVAILABLE/$full_domain" ]]; then
        log_detail "✅ Config Nginx existe"
    else
        log_error "❌ Config Nginx no encontrada"
        ((errors++))
    fi
    
    if [[ -L "$NGINX_ENABLED/$full_domain" ]]; then
        log_detail "✅ Sitio habilitado"
    else
        log_error "❌ Sitio no habilitado"
        ((errors++))
    fi
    
    # Verificar que Nginx está escuchando
    if ss -tlnp | grep -q ":443"; then
        log_detail "✅ Nginx escuchando en 443"
    else
        log_error "❌ Nginx no escucha en 443"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_info "✅ Verificación final: TODOS LOS COMPONENTES OK"
        return 0
    else
        log_error "❌ Verificación final: $errors errores encontrados"
        return 1
    fi
}

# ============================================
# FUNCIÓN: Mostrar resumen
# ============================================
show_summary() {
    log_step "PASO 9/10: Resumen del proyecto"
    
    local full_domain="${PROJECT_NAME}.${DOMAIN}"
    
    echo ""
    echo "======================================"
    echo "✅ PROYECTO CREADO EXITOSAMENTE"
    echo "======================================"
    echo ""
    echo "📋 Información del Proyecto:"
    echo "   Nombre:     $PROJECT_NAME"
    echo "   Cliente:    $CLIENT_NAME"
    echo "   VPN IP:     $VPN_IP"
    echo "   Puerto:     $LOCAL_PORT"
    echo ""
    echo "🌐 Acceso Público:"
    echo "   URL:        https://$full_domain"
    echo "   Dominio:    $full_domain"
    echo ""
    echo "📄 Configuración VPN:"
    echo "   Archivo:    /home/usuario/vpn-clients/${CLIENT_NAME}.ovpn"
    echo "   IP:         $VPN_IP"
    echo ""
    echo "🔒 SSL:"
    echo "   Cert:       $LETSENCRYPT_DIR/live/$full_domain/fullchain.pem"
    echo "   Key:        $LETSENCRYPT_DIR/live/$full_domain/privkey.pem"
    echo ""
    echo "📝 Instrucciones para el cliente:"
    echo "   1. Descargar VPN config:"
    echo "      scp usuario@$SERVER_IP:/home/usuario/vpn-clients/${CLIENT_NAME}.ovpn ."
    echo ""
    echo "   2. Conectar VPN:"
    echo "      sudo openvpn --config ${CLIENT_NAME}.ovpn"
    echo ""
    echo "   3. Iniciar servicio local en puerto $LOCAL_PORT"
    echo ""
    echo "   4. Acceder a: https://$full_domain"
    echo ""
    echo "======================================"
    echo "Log guardado en: $LOG_FILE"
    echo "======================================"
}

# ============================================
# FUNCIÓN: Setup auto-renewal
# ============================================
setup_renewal() {
    log_step "PASO 10/10: Configurando auto-renovación..."
    
    # Verificar que certbot renewal funciona
    log_detail "Probando certbot renew --dry-run..."
    
    if certbot renew --dry-run &>/dev/null; then
        log_info "✅ Auto-renovación SSL configurada"
    else
        log_warn "⚠️  Revisa la configuración de auto-renovación"
    fi
}

# ============================================
# MAIN
# ============================================
main() {
    echo "======================================"
    echo "CREATE PROJECT - VPS Script"
    echo "======================================"
    echo ""
    
    # Ejecutar pasos
    validate_prerequisites
    parse_arguments "$@"
    check_existing_project
    create_vpn_client
    issue_ssl_certificate
    configure_nginx
    register_project
    final_verification
    show_summary
    setup_renewal
    
    log_info "✅ Script completado exitosamente"
    exit 0
}

# Ejecutar main
main "$@"
