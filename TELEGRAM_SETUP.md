# 🤖 Configuración de Notificaciones Telegram

## Bot Configurado

- **Bot**: @RespaldosCC_bot
- **Token**: `7663086908:AAGnLRT8RYSnbohB2KdPLXlG4GCMKVlFO90`
- **Estado**: ✅ Configurado en GitHub Secrets

## Obtener Chat ID

### Paso 1: Enviar mensaje al bot

1. Abre Telegram
2. Busca: `@RespaldosCC_bot`
3. Envía un mensaje (cualquier texto)

### Paso 2: Obtener Chat ID

```bash
# Ejecutar localmente:
curl -s "https://api.telegram.org/bot7663086908:AAGnLRT8RYSnbohB2KdPLXlG4GCMKVlFO90/getUpdates" | grep -o '"chat":{"id":[0-9]*'

# O usar el script:
bash scripts/get-telegram-chat-id.sh
```

### Paso 3: Configurar en GitHub

```bash
gh secret set TELEGRAM_CHAT_ID --repo Evertdan/vps-gateway --body "TU_CHAT_ID"
```

## Mensajes por Cada Paso

El pipeline enviará notificaciones en cada etapa:

| Paso | Icono | Descripción |
|------|-------|-------------|
| Inicio | 🚀 | Pipeline iniciado |
| Terraform | ⚙️ | Creando registros DNS |
| ACME | 🔐 | Obteniendo credenciales SSL |
| DNS | 🌍 | Aplicando cambios Route 53 |
| VPS SSH | 🔑 | Conectando a VPS |
| VPN | 🔐 | Creando cliente VPN |
| SSL | 🔒 | Generando certificado |
| Verify | 🔍 | Verificando configuración |
| Éxito | ✅ | Proyecto creado |
| Error | ❌ | Pipeline fallido |

## Ejemplo de Notificación

```
🚀 VPS Gateway - Creación de Proyecto

📋 Proyecto: mi-proyecto
👤 Cliente: mi-cliente
🔌 Puerto: 5678

⏳ Iniciando pipeline...
🔄 Job 1/3: Terraform DNS
```

## Notificación de Éxito

```
🎉 PROYECTO CREADO EXITOSAMENTE

✅ Job 3/3 Completado

📋 Resumen:
• Proyecto: mi-proyecto
• Cliente: mi-cliente
• URL: https://mi-proyecto.vps1.dgetahgo.edu.mx
• Puerto: 5678

📝 Pasos siguientes:
1. Descargar .ovpn desde artifacts
2. Conectar: sudo openvpn --config mi-cliente.ovpn
3. Iniciar servicio en puerto 5678
4. Acceder a la URL
```

## Notificación de Error

```
❌ Pipeline Fallido

Algunos jobs no completaron correctamente.

🔗 Revisa los logs: [URL de GitHub Actions]
```

## Configuración Completa

```bash
# Tokens ya configurados:
✅ TELEGRAM_BOT_TOKEN=7663086908:AAGnLRT8RYSnbohB2KdPLXlG4GCMKVlFO90
⏳ TELEGRAM_CHAT_ID=[PENDIENTE]

# Configurar Chat ID:
gh secret set TELEGRAM_CHAT_ID --repo Evertdan/vps-gateway --body "123456789"
```

## Probar Bot

```bash
# Enviar mensaje de prueba:
curl -X POST "https://api.telegram.org/bot7663086908:AAGnLRT8RYSnbohB2KdPLXlG4GCMKVlFO90/sendMessage" \
  -d "chat_id=TU_CHAT_ID" \
  -d "text=🧪 Prueba de notificación"
```

---

## ⚠️ IMPORTANTE

Para que las notificaciones funcionen:

1. **Enviar mensaje al bot**: @RespaldosCC_bot
2. **Obtener Chat ID**: Usar el método arriba
3. **Configurar secret**: `TELEGRAM_CHAT_ID` en GitHub

Sin el Chat ID, las notificaciones no se enviarán.