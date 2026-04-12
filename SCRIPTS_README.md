# 🚀 Sistema de Creación de Proyectos - DGETAHGO VPS

## 📋 Arquitectura Híbrida (Corregida)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              TU MÁQUINA LOCAL                            │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  create-project-local.sh                                        │    │
│  │  ├─ Verifica SSH al VPS                                         │    │
│  │  ├─ Obtiene credenciales acme-dns (del VPS)                     │    │
│  │  ├─ Ejecuta Terraform LOCAL → Crea DNS en AWS Route 53          │    │
│  │  │   ├─ Registro A: proyecto.vps1.dgetahgo.edu.mx → 195.26.244.180  │
│  │  │   └─ Registro CNAME: _acme-challenge.proyecto → uuid.auth... │    │
│  │  └─ SSH al VPS → Ejecuta create-project-vps.sh                  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ SSH
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         VPS (195.26.244.180)                             │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  create-project-vps.sh                                          │    │
│  │                                                                 │    │
│  │  PASO 1/10: Validar prerequisitos                               │    │
│  │   ├─ Docker corriendo                                           │    │
│  │   ├─ OpenVPN container activo                                   │    │
│  │   ├─ acme-dns service activo                                    │    │
│  │   ├─ Nginx activo                                               │    │
│  │   └─ Certbot instalado                                          │    │
│  │                                                                 │    │
│  │  PASO 2/10: Parsear argumentos                                  │    │
│  │   ├─ --project=nombre                                           │    │
│  │   ├─ --client=cliente_vpn                                       │    │
│  │   ├─ --port=5678                                                │    │
│  │   └─ --acme-file=/tmp/acme.json                                 │    │
│  │                                                                 │    │
│  │  PASO 3/10: Verificar proyecto existente                        │    │
│  │   └─ Chequea registry.json                                      │    │
│  │                                                                 │    │
│  │  PASO 4/10: Crear cliente VPN                                   │    │
│  │   ├─ Calcular IP disponible (192.168.255.10-100)                │    │
│  │   ├─ Generar certificado con vpn-generate-client.sh             │    │
│  │   ├─ Crear archivo CCD con IP estática                          │    │
│  │   ├─ Guardar archivo .ovpn en /home/usuario/vpn-clients/        │    │
│  │   └─ Actualizar registry.json                                   │    │
│  │                                                                 │    │
│  │  PASO 5/10: Emitir certificado SSL                              │    │
│  │   ├─ Verificar que CNAME ACME existe (espera propagación)       │    │
│  │   ├─ Crear hook script para acme-dns                            │    │
│  │   ├─ Ejecutar certbot con DNS-01 challenge                      │    │
│  │   ├─ Certbot actualiza TXT record vía hook                      │    │
│  │   ├─ Let's Encrypt valida y emite certificado                   │    │
│  │   └─ Guardar en /etc/letsencrypt/live/proyecto.vps1.../         │    │
│  │                                                                 │    │
│  │  PASO 6/10: Configurar Nginx                                    │    │
│  │   ├─ Crear server block con SSL                                 │    │
│  │   ├─ Configurar proxy a IP_VPN:PUERTO                           │    │
│  │   ├─ Incluir headers para WebSocket                             │    │
│  │   ├─ Testear config: nginx -t                                   │    │
│  │   └─ Reload Nginx: systemctl reload nginx                       │    │
│  │                                                                 │    │
│  │  PASO 7/10: Registrar proyecto                                  │    │
│  │   └─ Guardar en /opt/projects/registry.json                     │    │
│  │                                                                 │    │
│  │  PASO 8/10: Verificación final                                  │    │
│  │   ├─ VPN: CCD existe, .ovpn existe                              │    │
│  │   ├─ SSL: certificado existe y es válido                        │    │
│  │   ├─ Nginx: config existe, sitio habilitado, puerto 443 OK      │    │
│  │   └─ Todo verificado ✓                                          │    │
│  │                                                                 │    │
│  │  PASO 9/10: Mostrar resumen                                     │    │
│  │   └─ URLs, comandos, instrucciones                              │    │
│  │                                                                 │    │
│  │  PASO 10/10: Configurar auto-renovación                         │    │
│  │   └─ certbot renew --dry-run                                    │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ VPN Tunnel (192.168.255.x)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          TU MÁQUINA LOCAL                                │
│  ├─ Docker con n8n corriendo en puerto 5678                             │
│  ├─ Conectado a VPN (IP: 192.168.255.10)                                │
│  └─ Servicio accesible desde VPS via IP VPN                             │
└─────────────────────────────────────────────────────────────────────────┘
```

## 🔧 Componentes

### 1. Script Local (`create-project-local.sh`)

**Ubicación:** Tu máquina (`~/servcontabo/scripts/`)

**Función:**
- Orquesta todo el proceso
- Usa Terraform para crear DNS en AWS
- Se conecta por SSH al VPS para ejecutar el script remoto

**Requisitos:**
```bash
# En tu máquina local:
- Terraform instalado
- AWS CLI configurado (con credenciales de Route 53)
- SSH key: ~/.ssh/usuario_vps1_key
```

### 2. Script VPS (`create-project-vps.sh`)

**Ubicación:** VPS (`/opt/projects/scripts/`)

**Función:**
- Crea VPN client con IP estática
- Emite certificado SSL con Let's Encrypt
- Configura Nginx como reverse proxy
- Registra todo en `registry.json`

**Requisitos en VPS:**
- Docker + OpenVPN container
- acme-dns service
- Nginx
- Certbot
- Scripts VPN en `/home/usuario/vpn-scripts/`

### 3. Terraform (Local)

**Ubicación:** Tu máquina (`~/servcontabo/terraform/`)

**Función:**
- Crea registro A en Route 53
- Crea registro CNAME para ACME challenge

**Variables:**
- `subdomains`: Map de registros A
- `acme_challenges`: Map de registros CNAME

## 🚀 Uso

### Primer proyecto

```bash
# 1. Ir al directorio scripts
cd ~/servcontabo/scripts

# 2. Ejecutar script local
./create-project-local.sh \
  --project=n8n-mi-proyecto \
  --client=cliente-01 \
  --port=5678
```

### Qué hace automáticamente

1. **Verifica conexión** SSH al VPS
2. **Obtiene credenciales** de acme-dns del VPS
3. **Crea DNS** con Terraform:
   - `n8n-mi-proyecto.vps1.dgetahgo.edu.mx` → A → 195.26.244.180
   - `_acme-challenge.n8n-mi-proyecto.vps1.dgetahgo.edu.mx` → CNAME → uuid.auth...
4. **Espera propagación** DNS (20-30 segundos)
5. **Ejecuta en VPS** (por SSH):
   - Crea cliente VPN con IP 192.168.255.x
   - Emite certificado SSL
   - Configura Nginx
   - Verifica todo

### Acceder a tu proyecto

```bash
# 1. Descargar config VPN
scp usuario@195.26.244.180:/home/usuario/vpn-clients/cliente-01.ovpn ~/Downloads/

# 2. Conectar VPN
sudo openvpn --config ~/Downloads/cliente-01.ovpn

# 3. Iniciar tu servicio local (ejemplo n8n)
cd ~/n8n-local
docker compose up -d

# 4. Acceder
open https://n8n-mi-proyecto.vps1.dgetahgo.edu.mx
```

## ✅ Validaciones del Script VPS (10 Pasos)

| Paso | Validación | Detalle |
|------|------------|---------|
| 1 | Prerequisitos | Docker, OpenVPN, acme-dns, Nginx, certbot |
| 2 | Argumentos | project, client, port, acme-file presentes |
| 3 | Proyecto existente | No sobrescribe sin confirmar |
| 4 | VPN | IP disponible, certificado generado, CCD creado |
| 5 | SSL | DNS propagado, certbot emite cert, archivos existen |
| 6 | Nginx | Config válida, test pasa, reload OK |
| 7 | Registro | Guardado en registry.json |
| 8 | Verificación final | Todos los componentes revisados |
| 9 | Resumen | Muestra URLs e instrucciones |
| 10 | Auto-renovación | certbot renew configurado |

## 📁 Archivos Importantes

### Local (tu máquina)
```
~/servcontabo/
├── scripts/
│   ├── create-project-local.sh      # Script orquestador
│   └── create-project-vps.sh        # Copia al VPS
└── terraform/
    ├── main.tf                      # Recursos DNS
    ├── variables.tf                 # Variables
    └── terraform.tfvars             # Credenciales (no commitear)
```

### VPS
```
/opt/projects/
├── scripts/
│   ├── create-project-vps.sh        # Script principal
│   ├── create-project.sh            # Script antiguo
│   └── ...
└── registry.json                    # Base de datos de proyectos

/etc/letsencrypt/
├── live/proyecto.vps1.../           # Certificados SSL
└── acme-dns-accounts.json           # Cuentas acme-dns

/etc/nginx/sites-available/          # Configs Nginx
/etc/nginx/sites-enabled/            # Symlinks activos

/opt/openvpn/data/ccd/               # IPs estáticas VPN
/home/usuario/vpn-clients/           # Archivos .ovpn
```

## 🔍 Troubleshooting

### "AWS CLI no configurado"
```bash
aws configure
# Access Key ID: TU_ACCESS_KEY
# Secret Access Key: TU_SECRET_KEY
# Region: us-east-1
```

### "DNS no se propaga"
Esperar más tiempo (hasta 5 minutos) o verificar:
```bash
dig +short _acme-challenge.proyecto.vps1.dgetahgo.edu.mx CNAME
```

### "Certbot falla"
Revisar logs:
```bash
ssh usuario@195.26.244.180 "cat /var/log/create-project.log"
```

### "Nginx no recarga"
Verificar sintaxis:
```bash
ssh usuario@195.26.244.180 "sudo nginx -t"
```

## 🔐 Seguridad

- **SSH Key**: Guardada en `~/.ssh/usuario_vps1_key` (chmod 600)
- **AWS Creds**: En `~/.aws/credentials` (nunca commitear)
- **VPN Certs**: En VPS con permisos restringidos
- **ACME Creds**: Temporales, se borran después de usar

## 📊 Límites

- **IPs VPN**: 192.168.255.10 - 192.168.255.100 (90 proyectos)
- **Certificados**: Let's Encrypt rate limits (50/week por dominio)
- **DNS**: Limitado por AWS Route 53 (no hay límite práctico)

## 🔄 Flujo de Datos

```
Usuario
  ↓
Script Local (SSH al VPS + Terraform AWS)
  ↓                    ↓
VPS (VPN+SSL+Nginx)   AWS Route 53 (DNS)
  ↓
Internet → HTTPS → Nginx → VPN Tunnel → Servicio Local
```

## 📞 Soporte

- **Logs VPS**: `/var/log/create-project.log`
- **Registry**: `/opt/projects/registry.json`
- **Status servicios**: `systemctl status nginx acme-dns`
- **Docker**: `docker logs openvpn`
