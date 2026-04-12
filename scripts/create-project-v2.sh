#!/bin/bash
# create-project.sh - Crea un proyecto completo: VPN + DNS + SSL + Proxy
# Uso: ./create-project.sh --project=nombre --client=cliente --port=3000 [--client-exists]

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables por defecto
PROJECT_NAME=""
CLIENT_NAME=""
LOCAL_PORT="3000"
CLIENT_EXISTS="false"
SERVER_IP="195.26.244.180"
DOMAIN="vps1.dgetahgo.edu.mx"
HOSTED_ZONE_ID="Z0748356URLST7BWNN9D"
PROJECTS_REGISTRY="/opt/projects/registry.json"
VPN_SCRIPTS="/home/usuario/vpn-scripts"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
LETSENCRYPT_DIR="/etc/letsencrypt"

# Funciones de log
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_manual() { echo -e "${YELLOW}[MANUAL]${NC} $1"; }

# Verificar AWS CLI configurado
check_aws_credentials() {
    if ! aws sts get-caller-identity &>/dev/null; then
        return 1
    fi
    return 0
}

# Verificar si registro DNS existe
check_dns_record() {
    local record_name="$1"
    
    if ! check_aws_credentials; then
        return 2  # No podemos verificar
    fi
    
    local result=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --query "ResourceRecordSets[?Name=='$record_name.']" \
        --output text 2>/dev/null)
    
    if [[ -n "$result" && "$result" == *"$record_name"* ]]; then
        return 0  # Existe
    else
        return 1  # No existe
    fi
}

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --project=*) PROJECT_NAME="${1#*=}" ;;
        --client=*) CLIENT_NAME="${1#*=}" ;;
        --port=*) LOCAL_PORT="${1#*=}" ;;
        --client-exists) CLIENT_EXISTS="true" ;;
        --help|-h)
            echo "Uso: $0 --project=nombre --client=cliente [--port=3000] [--client-exists]"
            exit 0
            ;;
        *) log_error "Opción desconocida: $1"; exit 1 ;;
    esac
    shift
done

# Validaciones
if [[ -z "$PROJECT_NAME" || -z "$CLIENT_NAME" ]]; then
    log_error "Faltan argumentos requeridos: --project y --client"
    exit 1
fi

# Validar formato (alphanumeric, hyphen)
if [[ ! "$PROJECT_NAME" =~ ^[a-z0-9-]+$ ]]; then
    log_error "Nombre de proyecto inválido. Usar solo minúsculas, números y guiones"
    exit 1
fi

echo "======================================"
echo "Creando Proyecto: $PROJECT_NAME"
echo "Cliente: $CLIENT_NAME"
echo "Puerto Local: $LOCAL_PORT"
echo "======================================"

# ============================================
# PASO 0: Verificar prerequisitos
# ============================================
log_step "PASO 0/6: Verificando prerequisitos..."

AWS_CONFIGURED=false
if check_aws_credentials; then
    AWS_CONFIGURED=true
    log_info "✅ AWS CLI configurado correctamente"
else
    log_warn "⚠️  AWS CLI no configurado. Los registros DNS deben crearse manualmente."
    log_manual "Para configurar AWS CLI: aws configure"
fi

# Verificar directorios necesarios
mkdir -p "$VPN_SCRIPTS" /home/usuario/vpn-clients /opt/openvpn/data/ccd

# ============================================
# PASO 1: Verificar/Crear Cliente VPN
# ============================================
log_step "PASO 1/6: Verificando cliente VPN..."

VPN_IP=""

if [[ "$CLIENT_EXISTS" == "true" ]]; then
    # Verificar si cliente existe
    if [[ -f "/opt/openvpn/data/ccd/$CLIENT_NAME" ]]; then
        VPN_IP=$(cat "/opt/openvpn/data/ccd/$CLIENT_NAME" | grep ifconfig-push | awk '{print $2}')
        log_info "Cliente VPN existe con IP: $VPN_IP"
    else
        log_warn "Cliente no encontrado en CCD. Creando nuevo..."
        CLIENT_EXISTS="false"
    fi
fi

if [[ "$CLIENT_EXISTS" == "false" ]]; then
    log_info "Generando nuevo cliente VPN..."
    
    # Obtener siguiente IP disponible
    NEXT_IP=$(python3 << 'PYTHON'
import json
import sys

try:
    with open("/opt/projects/registry.json", "r") as f:
        data = json.load(f)
    
    next_ip = data.get("ip_pool", {}).get("next_ip", 10)
    
    # Verificar si IP está en uso
    used_ips = set()
    for client, info in data.get("clients", {}).items():
        if "vpn_ip" in info:
            ip = info["vpn_ip"].split(".")[-1]
            used_ips.add(int(ip))
    
    while next_ip in used_ips or next_ip > 100:
        next_ip += 1
        if next_ip > 100:
            print("ERROR: Pool de IPs agotado", file=sys.stderr)
            sys.exit(1)
    
    print(next_ip)
except Exception as e:
    print("10")  # Default
PYTHON
)
    
    if [[ "$NEXT_IP" == "ERROR:"* ]] || [[ -z "$NEXT_IP" ]]; then
        log_error "No hay IPs disponibles en el pool"
        exit 1
    fi
    
    VPN_IP="192.168.255.$NEXT_IP"
    log_info "Asignando IP estática: $VPN_IP"
    
    # Verificar que existe el script de generación
    if [[ ! -f "$VPN_SCRIPTS/vpn-generate-client.sh" ]]; then
        log_error "No existe el script vpn-generate-client.sh"
        exit 1
    fi
    
    # Generar certificado cliente
    if $VPN_SCRIPTS/vpn-generate-client.sh "$CLIENT_NAME"; then
        log_info "✅ Certificado VPN generado"
    else
        log_error "❌ Falló la generación del certificado VPN"
        exit 1
    fi
    
    # Crear archivo CCD
    echo "ifconfig-push $VPN_IP 255.255.255.0" > "/opt/openvpn/data/ccd/$CLIENT_NAME"
    chown root:root "/opt/openvpn/data/ccd/$CLIENT_NAME"
    chmod 644 "/opt/openvpn/data/ccd/$CLIENT_NAME"
    
    # Actualizar registro
    python3 << PYTHON
import json
import os

registry_path = "/opt/projects/registry.json"

# Crear archivo si no existe
if not os.path.exists(registry_path):
    data = {"projects": {}, "clients": {}, "ip_pool": {"next_ip": 10}}
else:
    with open(registry_path, "r") as f:
        data = json.load(f)

# Inicializar estructuras si no existen
if "clients" not in data:
    data["clients"] = {}
if "ip_pool" not in data:
    data["ip_pool"] = {"next_ip": 10}
if "projects" not in data:
    data["projects"] = {}

data["clients"]["$CLIENT_NAME"] = {
    "vpn_ip": "$VPN_IP",
    "created_at": "$(date -Iseconds)"
}
data["ip_pool"]["next_ip"] = $NEXT_IP + 1

with open(registry_path, "w") as f:
    json.dump(data, f, indent=2)

print(f"✅ Registro actualizado: $CLIENT_NAME -> $VPN_IP")
PYTHON
    
    log_info "✅ Cliente VPN creado: $CLIENT_NAME ($VPN_IP)"
    log_info "📄 Config VPN: /home/usuario/vpn-clients/$CLIENT_NAME.ovpn"
fi

# ============================================
# PASO 2: Crear DNS (Route 53)
# ============================================
log_step "PASO 2/6: Creando registro DNS..."

FULL_DOMAIN="$PROJECT_NAME.$DOMAIN"
DNS_CREATED=false

if [[ "$AWS_CONFIGURED" == "false" ]]; then
    log_warn "⚠️  AWS CLI no configurado. Saltando creación automática de DNS."
    log_manual "CREAR MANUALMENTE en AWS Route 53:"
    log_manual "  - Hosted Zone: $HOSTED_ZONE_ID"
    log_manual "  - Name: $PROJECT_NAME"
    log_manual "  - Type: A"
    log_manual "  - Value: $SERVER_IP"
    log_manual "  - TTL: 300"
    log_manual ""
    log_manual "Comando AWS CLI:"
    log_manual "aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{\"Changes\":[{\"Action\":\"CREATE\",\"ResourceRecordSet\":{\"Name\":\"$FULL_DOMAIN\",\"Type\":\"A\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"$SERVER_IP\"}]}}]}'"
    echo ""
    read -p "Presiona ENTER cuando hayas creado el registro DNS..."
else
    # Verificar si registro existe
    if check_dns_record "$FULL_DOMAIN"; then
        log_warn "Registro DNS ya existe: $FULL_DOMAIN"
        DNS_CREATED=true
    else
        # Crear registro A
        if aws route53 change-resource-record-sets \
            --hosted-zone-id "$HOSTED_ZONE_ID" \
            --change-batch "{
                \"Changes\": [{
                    \"Action\": \"CREATE\",
                    \"ResourceRecordSet\": {
                        \"Name\": \"$FULL_DOMAIN\",
                        \"Type\": \"A\",
                        \"TTL\": 300,
                        \"ResourceRecords\": [{\"Value\": \"$SERVER_IP\"}]
                    }
                }]
            }" &>/dev/null; then
            log_info "✅ Registro DNS creado: $FULL_DOMAIN → $SERVER_IP"
            DNS_CREATED=true
            
            # Esperar propagación
            log_info "⏳ Esperando propagación DNS (10 segundos)..."
            sleep 10
        else
            log_error "❌ Falló la creación del registro DNS"
            log_manual "CREAR MANUALMENTE en AWS Route 53:"
            log_manual "  Name: $PROJECT_NAME"
            log_manual "  Type: A"
            log_manual "  Value: $SERVER_IP"
            echo ""
            read -p "Presiona ENTER cuando hayas creado el registro DNS..."
        fi
    fi
fi

# ============================================
# PASO 3: Preparar ACME-DNS
# ============================================
log_step "PASO 3/6: Preparando ACME-DNS para SSL..."

# Verificar si ya tenemos cuenta acme-dns para este dominio
ACME_ACCOUNT_FILE="$LETSENCRYPT_DIR/acmedns-$PROJECT_NAME.json"
ACME_CREDENTIALS=""

if [[ -f "$ACME_ACCOUNT_FILE" ]]; then
    log_info "✅ Cuenta acme-dns existente encontrada"
    ACME_CREDENTIALS=$(cat "$ACME_ACCOUNT_FILE")
else
    log_info "Registrando dominio en acme-dns..."
    
    # Registrar en acme-dns
    ACME_RESPONSE=$(curl -sk -X POST "https://auth.dgetahgo.edu.mx:8444/register" 2>/dev/null)
    
    if [[ -n "$ACME_RESPONSE" && "$ACME_RESPONSE" == *"username"* ]]; then
        echo "$ACME_RESPONSE" > "$ACME_ACCOUNT_FILE"
        chmod 600 "$ACME_ACCOUNT_FILE"
        ACME_CREDENTIALS="$ACME_RESPONSE"
        log_info "✅ Dominio registrado en acme-dns"
    else
        log_error "❌ Falló el registro en acme-dns"
        log_error "Respuesta: $ACME_RESPONSE"
        exit 1
    fi
fi

# Extraer datos para CNAME
ACME_FULLDOMAIN=$(echo "$ACME_CREDENTIALS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('fulldomain', ''))" 2>/dev/null)
ACME_SUBDOMAIN=$(echo "$ACME_CREDENTIALS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('subdomain', ''))" 2>/dev/null)

if [[ -z "$ACME_FULLDOMAIN" || -z "$ACME_SUBDOMAIN" ]]; then
    log_error "❌ No se pudieron extraer datos de acme-dns"
    exit 1
fi

log_info "ACME-DNS fulldomain: $ACME_FULLDOMAIN"

# Verificar/crear CNAME para ACME challenge
ACME_CNAME_NAME="_acme-challenge.$FULL_DOMAIN"
ACME_CNAME_VALUE="$ACME_FULLDOMAIN."

if [[ "$AWS_CONFIGURED" == "true" ]]; then
    if check_dns_record "$ACME_CNAME_NAME"; then
        log_info "✅ CNAME ACME ya existe"
    else
        log_info "Creando CNAME para ACME challenge..."
        
        if aws route53 change-resource-record-sets \
            --hosted-zone-id "$HOSTED_ZONE_ID" \
            --change-batch "{
                \"Changes\": [{
                    \"Action\": \"CREATE\",
                    \"ResourceRecordSet\": {
                        \"Name\": \"$ACME_CNAME_NAME\",
                        \"Type\": \"CNAME\",
                        \"TTL\": 300,
                        \"ResourceRecords\": [{\"Value\": \"$ACME_CNAME_VALUE\"}]
                    }
                }]
            }" &>/dev/null; then
            log_info "✅ CNAME ACME creado: $ACME_CNAME_NAME → $ACME_CNAME_VALUE"
            
            # Esperar propagación
            log_info "⏳ Esperando propagación CNAME (15 segundos)..."
            sleep 15
        else
            log_warn "⚠️  No se pudo crear CNAME ACME automáticamente"
        fi
    fi
else
    log_manual "CREAR MANUALMENTE el CNAME para ACME:"
    log_manual "  - Name: _acme-challenge.$PROJECT_NAME"
    log_manual "  - Type: CNAME"
    log_manual "  - Value: $ACME_CNAME_VALUE"
    log_manual "  - TTL: 300"
    echo ""
    read -p "Presiona ENTER cuando hayas creado el CNAME..."
fi

# Verificar propagación CNAME
log_info "Verificando propagación DNS..."
for i in {1..6}; do
    CNAME_CHECK=$(dig +short "$ACME_CNAME_NAME" CNAME @8.8.8.8 2>/dev/null || echo "")
    if [[ "$CNAME_CHECK" == *"auth.dgetahgo.edu.mx"* ]]; then
        log_info "✅ CNAME propagado correctamente"
        break
    fi
    if [[ $i -eq 6 ]]; then
        log_warn "⚠️  CNAME no se propagó completamente, continuando de todos modos..."
    else
        log_info "⏳ Esperando propagación... ($i/6)"
        sleep 10
    fi
done

# ============================================
# PASO 4: Emitir SSL
# ============================================
log_step "PASO 4/6: Emitiendo certificado SSL..."

CERT_PATH="$LETSENCRYPT_DIR/live/$FULL_DOMAIN"

if [[ -d "$CERT_PATH" ]]; then
    log_warn "Certificado SSL ya existe para $FULL_DOMAIN"
else
    log_info "Generando certificado con Let's Encrypt..."
    
    # Extraer credenciales para el hook
    ACME_USER=$(echo "$ACME_CREDENTIALS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('username', ''))")
    ACME_KEY=$(echo "$ACME_CREDENTIALS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('password', ''))")
    
    if [[ -z "$ACME_USER" || -z "$ACME_KEY" ]]; then
        log_error "❌ No se pudieron extraer credenciales acme-dns"
        exit 1
    fi
    
    # Crear script de hook temporal
    HOOK_SCRIPT="/tmp/acme-hook-$PROJECT_NAME.sh"
    cat > "$HOOK_SCRIPT" << 'HOOK'
#!/bin/bash
# ACME-DNS Auth Hook

curl -sk -X POST "https://auth.dgetahgo.edu.mx:8444/update" \
    -H "Content-Type: application/json" \
    -H "X-Api-User: ACME_USER_PLACEHOLDER" \
    -H "X-Api-Key: ACME_KEY_PLACEHOLDER" \
    -d "{\"subdomain\": \"ACME_SUBDOMAIN_PLACEHOLDER\", \"txt\": \"$CERTBOT_VALIDATION\"}"
HOOK
    
    sed -i "s/ACME_USER_PLACEHOLDER/$ACME_USER/g" "$HOOK_SCRIPT"
    sed -i "s/ACME_KEY_PLACEHOLDER/$ACME_KEY/g" "$HOOK_SCRIPT"
    sed -i "s/ACME_SUBDOMAIN_PLACEHOLDER/$ACME_SUBDOMAIN/g" "$HOOK_SCRIPT"
    chmod +x "$HOOK_SCRIPT"
    
    # Ejecutar certbot
    log_info "Ejecutando certbot (esto puede tomar 30-60 segundos)..."
    
    if certbot certonly \
        --manual \
        --preferred-challenges dns \
        --manual-auth-hook "$HOOK_SCRIPT" \
        --manual-cleanup-hook "/bin/true" \
        --manual-public-ip-logging-ok \
        --agree-tos \
        --email infraestructura@computocontable.com \
        -d "$FULL_DOMAIN" \
        --non-interactive \
        --quiet 2>&1 | tee /tmp/certbot-$PROJECT_NAME.log; then
        
        log_info "✅ Certificado SSL emitido para $FULL_DOMAIN"
        
        # Limpiar hook temporal
        rm -f "$HOOK_SCRIPT"
    else
        log_error "❌ Falló la emisión del certificado"
        log_error "Revise: /tmp/certbot-$PROJECT_NAME.log"
        
        # Mostrar log de error
        if [[ -f "/tmp/certbot-$PROJECT_NAME.log" ]]; then
            log_error "Últimas líneas del log:"
            tail -20 "/tmp/certbot-$PROJECT_NAME.log"
        fi
        
        exit 1
    fi
fi

# Verificar certificado
if [[ ! -f "$CERT_PATH/fullchain.pem" ]]; then
    log_error "❌ Certificado no encontrado en $CERT_PATH"
    exit 1
fi

log_info "✅ Certificado verificado: $CERT_PATH"

# ============================================
# PASO 5: Configurar Nginx
# ============================================
log_step "PASO 5/6: Configurando proxy Nginx..."

NGINX_CONFIG="$NGINX_AVAILABLE/$FULL_DOMAIN"

if [[ -f "$NGINX_CONFIG" ]]; then
    log_warn "Configuración Nginx ya existe: $FULL_DOMAIN"
else
    cat > "$NGINX_CONFIG" << EOF
server {
    listen 443 ssl http2;
    server_name $FULL_DOMAIN;
    
    ssl_certificate $CERT_PATH/fullchain.pem;
    ssl_certificate_key $CERT_PATH/privkey.pem;
    
    # SSL moderno
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    location / {
        proxy_pass http://$VPN_IP:$LOCAL_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts para VPN
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

server {
    listen 80;
    server_name $FULL_DOMAIN;
    return 301 https://\$server_name\$request_uri;
}
EOF
    
    # Habilitar sitio
    ln -sf "$NGINX_CONFIG" "$NGINX_ENABLED/$FULL_DOMAIN"
    
    # Test y reload
    if nginx -t; then
        systemctl reload nginx
        log_info "✅ Nginx configurado para $FULL_DOMAIN"
        log_info "   → Proxy: $VPN_IP:$LOCAL_PORT"
    else
        log_error "❌ Error en configuración Nginx"
        rm "$NGINX_CONFIG"
        rm -f "$NGINX_ENABLED/$FULL_DOMAIN"
        exit 1
    fi
fi

# ============================================
# PASO 6: Registrar Proyecto
# ============================================
log_step "PASO 6/6: Registrando proyecto..."

python3 << PYTHON
import json
import os

registry_path = "/opt/projects/registry.json"

with open(registry_path, "r") as f:
    data = json.load(f)

if "projects" not in data:
    data["projects"] = {}

data["projects"]["$PROJECT_NAME"] = {
    "client_name": "$CLIENT_NAME",
    "vpn_ip": "$VPN_IP",
    "local_port": $LOCAL_PORT,
    "domain": "$FULL_DOMAIN",
    "ssl": True,
    "created_at": "$(date -Iseconds)",
    "status": "active"
}

with open(registry_path, "w") as f:
    json.dump(data, f, indent=2)

print(f"✅ Proyecto registrado: $PROJECT_NAME")
PYTHON

# ============================================
# RESUMEN
# ============================================
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
echo "   URL:        https://$FULL_DOMAIN"
echo "   Dominio:    $FULL_DOMAIN"
echo ""

if [[ "$CLIENT_EXISTS" == "false" ]]; then
    echo "📄 Configuración VPN:"
    echo "   Archivo:    /home/usuario/vpn-clients/$CLIENT_NAME.ovpn"
    echo ""
    echo "📝 Instrucciones para el cliente:"
    echo "   1. Descargar: scp usuario@$SERVER_IP:/home/usuario/vpn-clients/$CLIENT_NAME.ovpn ."
    echo "   2. Importar en OpenVPN Connect"
    echo "   3. Conectar VPN"
    echo "   4. Iniciar proyecto Docker en puerto $LOCAL_PORT"
    echo "   5. Acceder a: https://$FULL_DOMAIN"
else
    echo "📝 Instrucciones:"
    echo "   1. Conectar VPN (cliente ya configurado)"
    echo "   2. Iniciar proyecto Docker en puerto $LOCAL_PORT"
    echo "   3. Acceder a: https://$FULL_DOMAIN"
fi

echo ""
echo "======================================"
