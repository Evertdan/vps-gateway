#!/bin/bash
# get-telegram-chat-id.sh - Obtiene el Chat ID para Telegram

BOT_TOKEN="7663086908:AAGnLRT8RYSnbohB2KdPLXlG4GCMKVlFO90"

echo "🤖 Bot: @RespaldosCC_bot"
echo ""
echo "Para obtener tu Chat ID:"
echo "1. Envía un mensaje al bot @RespaldosCC_bot"
echo "2. Ejecuta este script"
echo ""

# Obtener actualizaciones
UPDATES=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates")

if [[ "$UPDATES" == *"chat"* ]]; then
    echo "✅ Mensajes encontrados:"
    echo "$UPDATES" | grep -o '"chat":{[^}]*}' | grep -o '"id":[0-9]*' | head -5
    echo ""
    echo "Tu Chat ID es uno de los números de arriba (sin comillas)"
    echo "Ejemplo: 123456789"
else
    echo "❌ No se encontraron mensajes"
    echo "Envía un mensaje al bot primero: https://t.me/RespaldosCC_bot"
fi