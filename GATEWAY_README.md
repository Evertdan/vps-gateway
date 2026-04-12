# VPS Gateway - Sistema de Túneles VPN para Proyectos Docker

## 🎯 Propósito

Este sistema convierte el VPS `vps1.dgetahgo.edu.mx` en un **gateway seguro** que permite exponer proyectos Docker locales (en equipos de desarrollo) a Internet mediante:

1. **VPN (OpenVPN)**: Túnel seguro entre cliente ↔ VPS
2. **Subdominio único**: Cada proyecto obtiene URL propia
3. **SSL/TLS**: Certificados automáticos vía acme-dns
4. **Proxy Nginx**: Enrutamiento HTTPS → VPN → Docker local

## 🏗️ Arquitectura

```
Internet → DNS (subdominio.vps1.dgetahgo.edu.mx) → Nginx SSL → VPN → Docker Cliente
```

### Flujo de Datos

1. Usuario accede a `https://proyecto.vps1.dgetahgo.edu.mx`
2. DNS resuelve a IP del VPS (195.26.244.180)
3. Nginx termina SSL y proxy a IP VPN del cliente
4. Tráfico viaja por túnel VPN al equipo cliente
5. Nginx local del cliente (o Docker) recibe en puerto configurado

## 📋 Requisitos

### En el VPS (Ya configurado)
- ✅ OpenVPN con CCD (IPs estáticas)
- ✅ Nginx con soporte proxy
- ✅ acme-dns para SSL
- ✅ Scripts de automatización

### En el Equipo Cliente
- OpenVPN Client (Tunnelblick, OpenVPN Connect, etc.)
- Docker y docker-compose
- Proyecto Docker corriendo en puerto específico

## 🚀 Uso Rápido

### 1. Crear Nuevo Proyecto

**Vía GitHub Actions (Recomendado):**
1. Ir a Actions → "Create Project Gateway"
2. Click "Run workflow"
3. Completar:
   - `project_name`: nombre-del-proyecto
   - `client_name`: nombre-del-equipo
   - `local_port`: 3000 (puerto Docker local)
4. Descargar archivo VPN si es cliente nuevo

**Vía SSH (Manual):**
```bash
ssh usuario@vps1.dgetahgo.edu.mx
sudo /opt/projects/scripts/create-project.sh \
  --project=mi-proyecto \
  --client=mi-equipo \
  --port=3000
```

### 2. Configurar Cliente VPN

**Primera vez (nuevo cliente):**
```bash
# Descargar configuración
scp usuario@vps1.dgetahgo.edu.mx:/home/usuario/vpn-clients/mi-equipo.ovpn .

# Importar en OpenVPN Connect
# Conectar
```

**Cliente existente:**
- Solo conectar VPN (ya está configurado)

### 3. Iniciar Proyecto Docker

```bash
# En equipo cliente, con VPN conectada
cd proyecto/
docker-compose up -d

# Verificar en puerto local
curl http://localhost:3000
```

### 4. Acceder

```
https://mi-proyecto.vps1.dgetahgo.edu.mx
```

## 📁 Estructura del Sistema

```
/opt/projects/
├── registry.json              # Base de datos de proyectos
├── scripts/
│   ├── create-project.sh      # Crear proyecto completo
│   ├── delete-project.sh      # Eliminar proyecto
│   ├── list-projects.sh       # Listar proyectos
│   └── verify-vpn-client.sh   # Verificar estado cliente
└── nginx-conf.d/              # Configs nginx generados

/opt/openvpn/data/
├── ccd/                       # Client Config Directory
│   ├── cliente1              # ifconfig-push 192.168.255.10
│   └── cliente2              # ifconfig-push 192.168.255.11
└── pki/                       # Certificados

/etc/nginx/sites-available/    # Configs nginx
├── proyecto1.vps1.dgetahgo.edu.mx
└── proyecto2.vps1.dgetahgo.edu.mx

/home/usuario/vpn-clients/     # Archivos .ovpn
├── cliente1.ovpn
└── cliente2.ovpn
```

## 🔧 Comandos Administrativos

### Ver Proyectos
```bash
# Tabla bonita
/opt/projects/scripts/list-projects.sh

# JSON
/opt/projects/scripts/list-projects.sh --format=json

# CSV
/opt/projects/scripts/list-projects.sh --format=csv
```

### Verificar Cliente VPN
```bash
/opt/projects/scripts/verify-vpn-client.sh nombre-cliente
```

### Eliminar Proyecto
```bash
/opt/projects/scripts/delete-project.sh --project=nombre-proyecto
```

### Configurar CCD (One-time setup)
```bash
/opt/projects/scripts/configure-openvpn-ccd.sh
```

## 📝 Flujo Detallado

### Creación de Proyecto (create-project.sh)

```
1. Verificar/Crear Cliente VPN
   └─ Si no existe:
      ├─ Generar certificado
      ├─ Asignar IP estática (192.168.255.10-100)
      ├─ Crear archivo CCD
      └─ Generar .ovpn

2. Crear DNS (Route 53)
   └─ proyecto.vps1.dgetahgo.edu.mx → A → 195.26.244.180

3. Emitir SSL (acme-dns + certbot)
   ├─ Crear CNAME _acme-challenge
   ├─ Ejecutar certbot
   └─ Guardar certificado

4. Configurar Nginx
   ├─ Crear server block
   ├─ Configurar proxy a VPN_IP:PUERTO
   └─ Recargar nginx

5. Registrar en JSON
   └─ Guardar metadata del proyecto
```

## 🔐 Seguridad

### VPN
- Cada cliente tiene certificado único
- IPs estáticas asignadas por proyecto
- Túnel cifrado UDP 1194

### SSL/TLS
- Certificados Let's Encrypt vía acme-dns
- TLS 1.2/1.3
- Auto-renovación con certbot

### Aislamiento
- Proyectos aislados por VPN IP
- Un subdominio por proyecto
- No hay acceso directo entre proyectos

## 🐛 Troubleshooting

### No puedo conectar VPN
```bash
# Verificar certificado
openssl x509 -in cliente.ovpn -text -noout

# Verificar si está revocado
/opt/projects/scripts/verify-vpn-client.sh cliente
```

### Error 502 Bad Gateway
```bash
# Verificar si cliente está conectado
docker exec openvpn cat /tmp/openvpn-status.log | grep cliente

# Verificar IP del cliente
ping 192.168.255.XX  # IP asignada

# Verificar puerto local
curl http://192.168.255.XX:3000  # Desde VPS
```

### Certificado SSL expirado
```bash
# Renovar manualmente
certbot renew --force-renewal -d proyecto.vps1.dgetahgo.edu.mx
```

### DNS no resuelve
```bash
# Verificar registro
dig +short proyecto.vps1.dgetahgo.edu.mx @8.8.8.8

# Debe responder: 195.26.244.180
```

## 📊 Monitoreo

### Ver Clientes Conectados
```bash
docker exec openvpn ovpn_status
cat /tmp/openvpn-status.log
```

### Ver Logs Nginx
```bash
tail -f /var/log/nginx/proyecto.vps1.dgetahgo.edu.mx-access.log
tail -f /var/log/nginx/proyecto.vps1.dgetahgo.edu.mx-error.log
```

### Ver Logs Proyecto
```bash
cat /var/log/projects.log
```

## 🔄 CI/CD Integración

### GitHub Actions

Workflow: `.github/workflows/project-gateway.yml`

**Secrets requeridos:**
- `VPS_SSH_KEY`: Llave privada SSH
- `AWS_ACCESS_KEY_ID`: Credenciales AWS
- `AWS_SECRET_ACCESS_KEY`: Credenciales AWS

**Uso:**
1. Acceder a Actions → "Create Project Gateway"
2. Click "Run workflow"
3. Completar parámetros
4. Workflow crea todo automáticamente
5. Descargar archivo VPN si es necesario

## 🗺️ Pool de IPs VPN

| Rango | Uso |
|-------|-----|
| 192.168.255.1 | Servidor VPN |
| 192.168.255.2-9 | Reservado (servicios VPS) |
| 192.168.255.10-100 | Proyectos (IPs estáticas) |
| 192.168.255.101-254 | Clientes dinámicos (fallback) |

## 📝 Ejemplos

### Ejemplo 1: Nuevo Proyecto con Nuevo Cliente

```bash
# En VPS
sudo /opt/projects/scripts/create-project.sh \
  --project=mi-webapp \
  --client=desarrollador-juan \
  --port=3000

# Descargar VPN
scp usuario@vps1.dgetahgo.edu.mx:/home/usuario/vpn-clients/desarrollador-juan.ovpn .

# En equipo de Juan:
# 1. Importar .ovpn en OpenVPN Connect
# 2. Conectar VPN
# 3. docker-compose up -d
# 4. Acceder a: https://mi-webapp.vps1.dgetahgo.edu.mx
```

### Ejemplo 2: Segundo Proyecto (Mismo Cliente)

```bash
# En VPS
sudo /opt/projects/scripts/create-project.sh \
  --project=api-backend \
  --client=desarrollador-juan \
  --port=8080 \
  --client-exists

# Juan ya tiene VPN conectada
# Solo inicia segundo docker en puerto 8080
# Acceder a: https://api-backend.vps1.dgetahgo.edu.mx
```

### Ejemplo 3: Proyecto con Puerto Específico

```bash
# Django en puerto 8000
sudo /opt/projects/scripts/create-project.sh \
  --project=django-demo \
  --client=equipo-python \
  --port=8000
```

## 🎓 Buenas Prácticas

1. **Nombres descriptivos**: `api-produccion` mejor que `proyecto1`
2. **Un proyecto = Un puerto**: No reusar puertos locales
3. **VPN siempre conectada**: Mantener conexión estable
4. **Firewall local**: Permitir acceso desde 192.168.255.0/24
5. **Documentación**: Mantener registro de qué proyecto usa qué puerto

## 🚧 Limitaciones

- Máximo 90 proyectos simultáneos (pool de IPs 10-100)
- Velocidad limitada por ancho de banda del VPS
- No balanceo de carga (1 instancia por proyecto)
- Requiere conexión VPN activa para funcionar

## 📞 Soporte

- **Infrastructure**: infraestructura@computocontable.com
- **Server**: vps1.dgetahgo.edu.mx
- **Documentation**: Este README

---

**Versión**: 1.0  
**Última actualización**: 2026-04-12  
**Estado**: ✅ Producción
