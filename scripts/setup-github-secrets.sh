#!/bin/bash
# setup-github-secrets.sh - Configura los secrets necesarios para GitHub Actions
# Uso: ./setup-github-secrets.sh --repo=usuario/repo

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

REPO=""

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo=*) REPO="${1#*=}" ;;
        *) echo "Opción desconocida: $1"; exit 1 ;;
    esac
    shift
done

if [[ -z "$REPO" ]]; then
    log_error "Falta argumento: --repo=usuario/repo"
    exit 1
fi

echo "======================================"
echo "Setup GitHub Secrets"
echo "Repositorio: $REPO"
echo "======================================"
echo ""

# Verificar gh CLI
if ! command -v gh &>/dev/null; then
    log_error "GitHub CLI (gh) no está instalado"
    log_info "Instalar: https://cli.github.com/"
    exit 1
fi

# Verificar autenticación
if ! gh auth status &>/dev/null; then
    log_error "No estás autenticado en GitHub CLI"
    log_info "Ejecuta: gh auth login"
    exit 1
fi

log_step "Configurando secrets para: $REPO"
echo ""

# ============================================
# AWS Credentials
# ============================================
log_step "1. AWS Credentials"
echo "Necesitas:"
echo "  - AWS Access Key ID"
echo "  - AWS Secret Access Key"
echo "  - Región: us-east-1"
echo ""

read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
read -s -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo ""

if [[ -n "$AWS_ACCESS_KEY_ID" && -n "$AWS_SECRET_ACCESS_KEY" ]]; then
    log_info "Configurando AWS_ACCESS_KEY_ID..."
    gh secret set AWS_ACCESS_KEY_ID --repo "$REPO" --body "$AWS_ACCESS_KEY_ID"
    
    log_info "Configurando AWS_SECRET_ACCESS_KEY..."
    gh secret set AWS_SECRET_ACCESS_KEY --repo "$REPO" --body "$AWS_SECRET_ACCESS_KEY"
    
    log_info "✅ AWS credentials configuradas"
else
    log_warn "⚠️  AWS credentials no configuradas (vacías)"
fi

echo ""

# ============================================
# VPS SSH Key
# ============================================
log_step "2. VPS SSH Key"
echo "Se necesita la clave SSH privada para conectar al VPS (195.26.244.180)"
echo "Archivo: ~/.ssh/usuario_vps1_key"
echo ""

SSH_KEY_PATH="${HOME}/.ssh/usuario_vps1_key"

if [[ -f "$SSH_KEY_PATH" ]]; then
    log_info "Encontrada clave SSH: $SSH_KEY_PATH"
    read -p "¿Usar esta clave? (S/n): " USE_DEFAULT
    
    if [[ "$USE_DEFAULT" != "n" && "$USE_DEFAULT" != "N" ]]; then
        VPS_SSH_KEY=$(cat "$SSH_KEY_PATH")
    else
        read -p "Path a la clave SSH: " CUSTOM_PATH
        if [[ -f "$CUSTOM_PATH" ]]; then
            VPS_SSH_KEY=$(cat "$CUSTOM_PATH")
        else
            log_error "Archivo no encontrado: $CUSTOM_PATH"
            exit 1
        fi
    fi
else
    log_warn "No se encontró $SSH_KEY_PATH"
    read -p "Path a la clave SSH: " CUSTOM_PATH
    if [[ -f "$CUSTOM_PATH" ]]; then
        VPS_SSH_KEY=$(cat "$CUSTOM_PATH")
    else
        log_error "Archivo no encontrado"
        exit 1
    fi
fi

if [[ -n "$VPS_SSH_KEY" ]]; then
    log_info "Configurando VPS_SSH_KEY..."
    gh secret set VPS_SSH_KEY --repo "$REPO" --body "$VPS_SSH_KEY"
    log_info "✅ VPS SSH Key configurada"
else
    log_error "❌ No se pudo leer la clave SSH"
    exit 1
fi

echo ""

# ============================================
# Resumen
# ============================================
log_step "Resumen"
echo ""
echo "Secrets configurados en: $REPO"
echo ""
echo "✅ AWS_ACCESS_KEY_ID"
echo "✅ AWS_SECRET_ACCESS_KEY"
echo "✅ VPS_SSH_KEY"
echo ""
echo "Para verificar:"
echo "  gh secret list --repo $REPO"
echo ""
echo "======================================"
