#!/bin/bash
# setup-mcp-github.sh - Configura el MCP de GitHub para OpenCode
# Uso: ./setup-mcp-github.sh

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

echo "======================================"
echo "Setup MCP GitHub for OpenCode"
echo "======================================"
echo ""

# ============================================
# Verificar prerequisitos
# ============================================
log_step "1. Verificando prerequisitos..."

if ! command -v npx &>/dev/null; then
    log_error "npx no está instalado. Instala Node.js primero."
    exit 1
fi

if ! command -v node &>/dev/null; then
    log_error "Node.js no está instalado."
    exit 1
fi

log_info "✅ Node.js y npx disponibles"

# ============================================
# Configurar directorio MCP
# ============================================
log_step "2. Configurando directorio MCP..."

MCP_DIR="${HOME}/.config/opencode/mcp"
mkdir -p "$MCP_DIR"

log_info "✅ Directorio creado: $MCP_DIR"

# ============================================
# Verificar/Instalar server-github
# ============================================
log_step "3. Instalando MCP Server GitHub..."

log_info "Instalando @modelcontextprotocol/server-github..."
npx -y @modelcontextprotocol/server-github --version &>/dev/null || true

log_info "✅ MCP Server GitHub instalado"

# ============================================
# Configurar Token
# ============================================
log_step "4. Configurando token de GitHub..."

if [[ -z "$GITHUB_TOKEN" ]]; then
    log_warn "Variable GITHUB_TOKEN no está definida"
    echo ""
    read -s -p "Ingresa tu GitHub Personal Access Token: " GITHUB_TOKEN
    echo ""
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_error "Token requerido"
        exit 1
    fi
fi

# ============================================
# Crear configuración MCP
# ============================================
log_step "5. Creando configuración MCP..."

CONFIG_FILE="${HOME}/.config/opencode/mcp_config.json"

cat > "$CONFIG_FILE" << EOF
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
EOF

chmod 600 "$CONFIG_FILE"

log_info "✅ Configuración guardada en: $CONFIG_FILE"

# ============================================
# Probar conexión
# ============================================
log_step "6. Probando conexión con GitHub..."

# Obtener info del usuario
USER_INFO=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
    https://api.github.com/user)

if [[ "$USER_INFO" == *"login"* ]]; then
    USERNAME=$(echo "$USER_INFO" | grep -o '"login": "[^"]*"' | cut -d'"' -f4)
    log_info "✅ Conexión exitosa! Usuario: $USERNAME"
else
    log_error "❌ Error en la conexión. Verifica tu token."
    exit 1
fi

# ============================================
# Resumen
# ============================================
echo ""
echo "======================================"
echo "✅ MCP GitHub configurado exitosamente!"
echo "======================================"
echo ""
echo "📋 Configuración:"
echo "   Archivo: ~/.config/opencode/mcp_config.json"
echo "   Usuario: $USERNAME"
echo ""
echo "🚀 Uso:"
echo "   El MCP de GitHub está listo para usar con OpenCode."
echo ""
echo "🔧 Herramientas disponibles:"
echo "   - Crear/Editar archivos en repos"
echo "   - Gestionar Issues y PRs"
echo "   - Buscar código"
echo "   - Gestionar releases"
echo ""
echo "======================================"
