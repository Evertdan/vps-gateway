#!/bin/bash
# telegram-notify.sh - Envía notificaciones a Telegram
# Uso: ./telegram-notify.sh "Mensaje" [tipo: info|success|warning|error]

set -e

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-7663086908:AAGnLRT8RYSnbohB2KdPLXlG4GCMKVlFO90}"
CHAT_ID="${TELEGRAM_CHAT_ID:-""}"
MESSAGE="$1"
TYPE="${2:-info}"

# Colores para emojis
 case $TYPE in
    success)
        EMOJI="✅"
        ;;
    warning)
        EMOJI="⚠️"
        ;;
    error)
        EMOJI="❌"
        ;;
    *)
        EMOJI="ℹ️"
        ;;
esac

# Construir mensaje formateado
FORMATTED_MESSAGE="${EMOJI} *VPS Gateway* ${EMOJI}

${MESSAGE}

⏰ $(date '+%Y-%m-%d %H:%M:%S')"

# Enviar a Telegram
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=${FORMATTED_MESSAGE}" \
    -d "parse_mode=Markdown" \
    -d "disable_web_page_preview=true" 2>/dev/null || echo "No se pudo enviar notificación"