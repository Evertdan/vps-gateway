# VPS Gateway - DGETAHGO Infrastructure

[![CI](https://github.com/Evertdan/vps-gateway/actions/workflows/ci.yml/badge.svg)](https://github.com/Evertdan/vps-gateway/actions/workflows/ci.yml)
[![CodeQL](https://github.com/Evertdan/vps-gateway/actions/workflows/codeql.yml/badge.svg)](https://github.com/Evertdan/vps-gateway/actions/workflows/codeql.yml)
[![Release](https://github.com/Evertdan/vps-gateway/actions/workflows/cd-release.yml/badge.svg)](https://github.com/Evertdan/vps-gateway/actions/workflows/cd-release.yml)

## 🚀 Descripción

VPS Gateway es una infraestructura completa que permite exponer proyectos Docker locales a internet de forma segura mediante:

- **OpenVPN**: Túneles seguros con IPs estáticas
- **Let's Encrypt**: Certificados SSL automatizados
- **Nginx**: Reverse proxy con terminación SSL
- **Route 53**: Gestión DNS en AWS
- **GitHub Actions**: CI/CD con notificaciones Telegram

## 📋 Arquitectura

```
Internet → DNS (Route 53) → Nginx SSL (VPS) → VPN Tunnel → Docker Local
```

## 🛠️ Tecnologías

- **VPS**: Ubuntu 24.04 en Contabo (195.26.244.180)
- **VPN**: OpenVPN con Docker
- **SSL**: Let's Encrypt + acme-dns
- **DNS**: AWS Route 53
- **IaC**: Terraform
- **CI/CD**: GitHub Actions con notificaciones Telegram

## 🔄 Workflows de CI/CD

### CI Pipeline (ci.yml)
Se ejecuta en cada push y PR:
- ✅ Lint de código (shellcheck, yamllint)
- ✅ Validación de Terraform
- ✅ Security scan (Trivy + CodeQL)
- ✅ Test de scripts
- ✅ Verificación de documentación

### Security Scan (codeql.yml)
Análisis de seguridad automatizado:
- 🔐 CodeQL para JavaScript, Python y Bash
- 🔐 Ejecución semanal programada
- 🔐 Análisis en cada push a main

### CD Release (cd-release.yml)
Se ejecuta en cada tag:
- 🏷️ Creación automática de releases
- 🚀 Deploy a VPS
- 📚 Actualización de documentación

### Create Project (create-project.yml)
Crea proyectos nuevos con notificaciones:
- 🌍 Terraform DNS (Route 53)
- 🖥️ VPS Setup (VPN + SSL + Nginx)
- ✅ Verificación final
- 📱 Notificaciones Telegram en cada paso

## 🚀 Uso

### Crear Proyecto

1. Ir a Actions → "Create Project - VPS Gateway"
2. Ejecutar workflow con:
   - `project_name`: nombre-del-proyecto
   - `client_name`: nombre-cliente-vpn
   - `local_port`: puerto-local (ej: 5678)

### Conectar VPN

```bash
# Descargar configuración desde artifacts
sudo openvpn --config cliente.ovpn
```

## 📁 Estructura

```
.
├── .github/workflows/         # Workflows de CI/CD
│   ├── ci.yml               # CI: Validación y tests
│   ├── codeql.yml           # Security: CodeQL
│   ├── cd-release.yml       # CD: Releases
│   ├── create-project.yml   # Creación de proyectos
│   └── manage-projects.yml  # Gestión de proyectos
├── scripts/                  # Scripts de automatización
├── terraform/                # Infraestructura como Código
├── skills/                   # Documentación de skills
└── docs/                     # Documentación
```

## 📚 Documentación

- [CI/CD Guide](CI_CD_GUIDE.md) - Guía completa del pipeline
- [Telegram Setup](TELEGRAM_SETUP.md) - Configuración de notificaciones
- [Scripts README](SCRIPTS_README.md) - Documentación de scripts
- [AGENTS.md](AGENTS.md) - Especificación agents.md

## 🔐 Seguridad

Los secrets se configuran en GitHub:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `VPS_SSH_KEY`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`

## 📝 Notificaciones Telegram

El bot @RespaldosCC_bot envía notificaciones en cada paso:
- 🚀 Inicio del pipeline
- ⚙️ Progreso de cada job
- ✅ Éxito o ❌ Fallo
- 🔗 Links a los logs

## 📄 Licencia

MIT - Ver [LICENSE](LICENSE)

---

**Autor**: Ever Daniel Romero (@Evertdan)  
**Repositorio**: https://github.com/Evertdan/vps-gateway