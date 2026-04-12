#!/bin/bash
# create-project-local.sh - Script LOCAL que orquesta la creación completa
# Uso: ./create-project-local.sh --project=nombre --client=cliente [--port=3000]

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
VPS_IP="195.26.244.180"
VPS_USER="usuario"
SSH_KEY="${HOME}/.ssh/usuario_vps1_key"
DOMAIN="vps1.dgetahgo.edu.mx"

# Funciones de log
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Variables
PROJECT_NAME=""
CLIENT_NAME=""
LOCAL_PORT="5678"

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --project=*) PROJECT_NAME="${1#*=}" ;;
        --client=*) CLIENT_NAME="${1#*=}" ;;
        --port=*) LOCAL_PORT="${1#*=}" ;;
        --help|-h)
            echo "Uso: $0 --project=nombre --client=cliente [--port=5678]"
            exit 0
            ;;
        *) echo "Opción desconocida: $1"; exit 1 ;;
    esac
    shift
done

# Validaciones
if [[ -z "$PROJECT_NAME" || -z "$CLIENT_NAME" ]]; then
    log_error "Faltan argumentos: --project y --client"
    exit 1
fi

FULL_DOMAIN="${PROJECT_NAME}.${DOMAIN}"

echo "======================================"
echo "Creando Proyecto: $PROJECT_NAME"
echo "Cliente VPN: $CLIENT_NAME"
echo "Dominio: $FULL_DOMAIN"
echo "======================================"

# ============================================
# PASO 1: Verificar conexión SSH al VPS
# ============================================
log_step "PASO 1/5: Verificando conexión al VPS..."

if [[ ! -f "$SSH_KEY" ]]; then
    log_error "No existe la clave SSH: $SSH_KEY"
    exit 1
fi

if ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$VPS_USER@$VPS_IP" "echo 'OK'" &>/dev/null; then
    log_error "No se puede conectar al VPS"
    exit 1
fi

log_info "✅ Conexión SSH OK"

# ============================================
# PASO 2: Verificar Terraform y AWS
# ============================================
log_step "PASO 2/5: Verificando Terraform y AWS..."

if ! command -v terraform &>/dev/null; then
    log_error "Terraform no está instalado"
    exit 1
fi

if ! aws sts get-caller-identity &>/dev/null; then
    log_error "AWS CLI no configurado en LOCAL"
    log_error "Ejecuta: aws configure"
    exit 1
fi

log_info "✅ Terraform y AWS CLI OK"

# ============================================
# PASO 3: Obtener fulldomain de acme-dns desde VPS
# ============================================
log_step "PASO 3/5: Obteniendo datos de acme-dns..."

ACME_RESPONSE=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$VPS_USER@$VPS_IP" \
    "curl -sk -X POST https://auth.dgetahgo.edu.mx:8444/register 2>/dev/null")

if [[ -z "$ACME_RESPONSE" || "$ACME_RESPONSE" != *"fulldomain"* ]]; then
    log_error "No se pudo obtener fulldomain de acme-dns"
    exit 1
fi

ACME_FULLDOMAIN=$(echo "$ACME_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('fulldomain', ''))")
ACME_SUBDOMAIN=$(echo "$ACME_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('subdomain', ''))")
ACME_USERNAME=$(echo "$ACME_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('username', ''))")
ACME_PASSWORD=$(echo "$ACME_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('password', ''))")

if [[ -z "$ACME_FULLDOMAIN" ]]; then
    log_error "No se pudo extraer fulldomain"
    exit 1
fi

log_info "✅ ACME fulldomain: $ACME_FULLDOMAIN"

# Guardar credenciales para el VPS
ACME_JSON="/tmp/acme-${PROJECT_NAME}.json"
echo "$ACME_RESPONSE" > "$ACME_JSON"

# ============================================
# PASO 4: Crear DNS con Terraform
# ============================================
log_step "PASO 4/5: Creando registros DNS con Terraform..."

cd "$(dirname "$0")/../terraform"

# Crear archivo de variables temporales
TFVARS_FILE="/tmp/terraform-${PROJECT_NAME}.tfvars"
cat > "$TFVARS_FILE" << EOF
subdomains = {
  "${PROJECT_NAME}" = {
    name    = "${PROJECT_NAME}.${DOMAIN}"
    type    = "A"
    ttl     = 300
    records = ["${VPS_IP}"]
  }
}

acme_challenges = {
  "_acme-challenge.${PROJECT_NAME}.${DOMAIN}" = "${ACME_FULLDOMAIN}."
}
EOF

log_info "Aplicando Terraform..."

if ! terraform init &>/dev/null; then
    log_error "Falló terraform init"
    exit 1
fi

if terraform apply -var-file="$TFVARS_FILE" -auto-approve; then
    log_info "✅ Registros DNS creados"
else
    log_error "❌ Falló terraform apply"
    exit 1
fi

# Esperar propagación DNS
log_info "⏳ Esperando propagación DNS (20 segundos)..."
sleep 20

# Verificar propagación
for i in {1..5}; do
    CNAME_CHECK=$(dig +short "_acme-challenge.${FULL_DOMAIN}" CNAME @8.8.8.8 2>/dev/null || echo "")
    if [[ "$CNAME_CHECK" == *"auth.dgetahgo.edu.mx"* ]]; then
        log_info "✅ DNS propagado correctamente"
        break
    fi
    if [[ $i -eq 5 ]]; then
        log_warn "⚠️  DNS no se propagó completamente, continuando..."
    else
        log_info "⏳ Esperando propagación... ($i/5)"
        sleep 10
    fi
done

# ============================================
# PASO 5: Ejecutar script en VPS
# ============================================
log_step "PASO 5/5: Configurando VPS (VPN + SSL + Nginx)..."

# Copiar script al VPS
SCRIPT_LOCAL="$(dirname "$0")/create-project-vps.sh"
SCRIPT_REMOTE="/tmp/create-project-vps.sh"

if [[ ! -f "$SCRIPT_LOCAL" ]]; then
    log_error "No existe el script VPS: $SCRIPT_LOCAL"
    exit 1
fi

log_info "Copiando script al VPS..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SCRIPT_LOCAL" "$VPS_USER@$VPS_IP:$SCRIPT_REMOTE"

# Copiar credenciales acme
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no "$ACME_JSON" "$VPS_USER@$VPS_IP:/tmp/acme-credentials.json"

# Ejecutar script en VPS
log_info "Ejecutando script en VPS..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$VPS_USER@$VPS_IP" \
    "sudo bash $SCRIPT_REMOTE --project=$PROJECT_NAME --client=$CLIENT_NAME --port=$LOCAL_PORT --acme-file=/tmp/acme-credentials.json"

# ============================================
# RESUMEN
# ============================================
echo ""
echo "======================================"
echo "✅ PROYECTO CREADO EXITOSAMENTE"
echo "======================================"
echo ""
echo "📋 Información:"
echo "   Proyecto:   $PROJECT_NAME"
echo "   Cliente:    $CLIENT_NAME"
echo "   URL:        https://$FULL_DOMAIN"
echo ""
echo "📝 Siguientes pasos:"
echo "   1. Descargar VPN config:"
echo "      scp -i $SSH_KEY $VPS_USER@$VPS_IP:/home/usuario/vpn-clients/$CLIENT_NAME.ovpn ~/"
echo ""
echo "   2. Conectar VPN:"
echo "      sudo openvpn --config ~/$CLIENT_NAME.ovpn"
echo ""
echo "   3. Iniciar tu servicio local en puerto $LOCAL_PORT"
echo ""
echo "   4. Acceder a: https://$FULL_DOMAIN"
echo ""
echo "======================================"

# Limpieza
rm -f "$TFVARS_FILE" "$ACME_JSON"
