# Project: VPS DGETAHGO Infrastructure

## Overview

Servidor VPS principal para `dgetahgo.edu.mx` con infraestructura completa de DNS, ACME, proxy reverso, VPN y automatización CI/CD.

## System Information

| Attribute | Value |
|-----------|-------|
| **Hostname** | `vps1.dgetahgo.edu.mx` |
| **IP Pública** | `195.26.244.180` |
| **Proveedor** | Contabo (VM) |
| **OS** | Ubuntu 24.04.4 LTS |
| **Kernel** | 6.8.0-106-generic |
| **Arquitectura** | x86_64 |
| **Primary User** | `usuario` (sudo, SSH key auth) |

## Services Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    195.26.244.180                           │
│                    vps1.dgetahgo.edu.mx                     │
├─────────────────────────────────────────────────────────────┤
│  Puerto 22    │  SSH (usuario, key-only)                    │
│  Puerto 53    │  acme-dns (DNS)                             │
│  Puerto 80    │  nginx (reverse proxy)                      │
│  Puerto 443   │  nginx + SSL (futuro)                       │
│  Puerto 8444  │  acme-dns (API HTTPS)                       │
│  Puerto 1194  │  OpenVPN (Docker)                           │
│  Puerto 5678  │  n8n (Docker, stopped)                      │
│  Puerto 8080  │  PBX (futuro)                               │
│  Puerto 8006  │  Proxmox (futuro)                           │
│  Puerto 8888  │  Webmail (futuro)                           │
└─────────────────────────────────────────────────────────────┘
```

## User Configuration

### User: `usuario`

| Attribute | Value |
|-----------|-------|
| **UID** | 1000 |
| **Groups** | usuario, sudo, users |
| **Sudo** | Passwordless (NOPASSWD:ALL) |
| **SSH Auth** | Key-only (no password) |
| **Home** | `/home/usuario` |

### SSH Access

**Key-based authentication only** - Password authentication disabled

**Authorized Keys** (`/home/usuario/.ssh/authorized_keys`):
- SSH key: `evertdan@gmail.com` (ed25519)

**Connect**:
```bash
ssh usuario@195.26.244.180
```

## DNS Configuration

### Route 53 - Hosted Zone: dgetahgo.edu.mx

| Record | Type | Value | TTL |
|--------|------|-------|-----|
| `n8n` | A | `195.26.244.180` | 300 |
| `_acme-challenge.n8n` | CNAME | `*.auth.dgetahgo.edu.mx` | 300 |
| `pbx` | A | `195.26.244.180` | 300 |
| `_acme-challenge.pbx` | CNAME | `*.auth.dgetahgo.edu.mx` | 300 |
| `pve` | A | `195.26.244.180` | 300 |
| `test` | A | `195.26.244.180` | 3600 |
| `_acme-challenge.test` | CNAME | `*.auth.dgetahgo.edu.mx` | 300 |
| `vps1` | A | `195.26.244.180` | 86400 |
| `_acme-challenge.vps1` | CNAME | `*.auth.dgetahgo.edu.mx` | 300 |
| `webmail` | A | `195.26.244.180` | 300 |
| `auth` | A | `195.26.244.180` | 300 |
| `ns1.auth` | A | `195.26.244.180` | 300 |
| `auth` | NS | `ns1.auth.dgetahgo.edu.mx.` | 300 |

### /etc/hosts

```
195.26.244.180 n8n.dgetahgo.edu.mx n8n
195.26.244.180 pbx.dgetahgo.edu.mx pbx
195.26.244.180 pve.dgetahgo.edu.mx pve
195.26.244.180 test.dgetahgo.edu.mx test
195.26.244.180 vps1.dgetahgo.edu.mx vps1
195.26.244.180 webmail.dgetahgo.edu.mx webmail
```

## ACME-DNS Configuration

### Server Config: /etc/acme-dns/config.cfg

```ini
[general]
listen = "195.26.244.180:53"
protocol = "both"
domain = "auth.dgetahgo.edu.mx"
nsname = "ns1.auth.dgetahgo.edu.mx"
nsadmin = "admin.dgetahgo.edu.mx"
records = [
    "auth.dgetahgo.edu.mx. A 195.26.244.180",
    "ns1.auth.dgetahgo.edu.mx. A 195.26.244.180",
    "auth.dgetahgo.edu.mx. NS ns1.auth.dgetahgo.edu.mx."
]
debug = false

[database]
engine = "sqlite3"
connection = "/var/lib/acme-dns/acme-dns.db"

[api]
ip = "0.0.0.0"
port = "8444"
tls = "cert"
tls_cert_privkey = "/etc/acme-dns/certs/privkey.pem"
tls_cert_fullchain = "/etc/acme-dns/certs/fullchain.pem"
corsorigins = ["*"]
use_header = false

[logconfig]
loglevel = "info"
logtype = "stdout"
logformat = "text"
logfile = "/var/log/acme-dns/acme-dns.log"
```

### Service Status

```bash
systemctl status acme-dns  # active (running)
```

### API Endpoint

- **URL**: `https://auth.dgetahgo.edu.mx:8444`
- **Method**: POST `/register` - Crea nueva cuenta
- **Method**: POST `/update` - Actualiza registro TXT

## Nginx Configuration

### Server Blocks

#### Static Sites

**vps1.dgetahgo.edu.mx** (default_server)
```nginx
server {
    listen 80 default_server;
    server_name vps1.dgetahgo.edu.mx;
    root /var/www/vps1;
    index index.html;
}
```

**test.dgetahgo.edu.mx**
```nginx
server {
    listen 80;
    server_name test.dgetahgo.edu.mx;
    root /var/www/test;
    index index.html;
}
```

#### Proxy Pass Sites

**n8n.dgetahgo.edu.mx** → `http://127.0.0.1:5678`
```nginx
location / {
    proxy_pass http://127.0.0.1:5678;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

**pbx.dgetahgo.edu.mx** → `http://127.0.0.1:8080`

**pve.dgetahgo.edu.mx** → `https://127.0.0.1:8006` (con `proxy_ssl_verify off`)

**webmail.dgetahgo.edu.mx** → `http://127.0.0.1:8888`

## OpenVPN Server

### Status

| Component | Status |
|-----------|--------|
| **Container** | ✅ Running |
| **Port** | 1194/udp |
| **Image** | `kylemanna/openvpn:latest` |
| **VPN Subnet** | `192.168.255.0/24` |

### Docker Compose: /opt/openvpn/docker-compose.yml

```yaml
services:
  openvpn:
    image: kylemanna/openvpn:latest
    container_name: openvpn
    cap_add:
      - NET_ADMIN
    ports:
      - "1194:1194/udp"
    volumes:
      - ./data:/etc/openvpn
    restart: always
    environment:
      - EASYRSA_BATCH=1
```

### Management Scripts

Located in `/home/usuario/vpn-scripts/`:

| Script | Purpose | Usage |
|--------|---------|-------|
| `vpn-generate-client.sh` | Create new client | `./vpn-generate-client.sh <name>` |
| `vpn-revoke-client.sh` | Revoke client | `./vpn-revoke-client.sh <name>` |
| `vpn-list-clients.sh` | List clients | `./vpn-list-clients.sh [--format=csv\|json]` |
| `vpn-backup.sh` | Backup PKI | `./vpn-backup.sh [--retention=days]` |
| `deploy-vpn-infrastructure.sh` | Full deploy | `./deploy-vpn-infrastructure.sh` |

### Generate Client

```bash
# On server
/home/usuario/vpn-scripts/vpn-generate-client.sh cliente1

# Or via SSH
ssh usuario@195.26.244.180 /home/usuario/vpn-scripts/vpn-generate-client.sh cliente1

# Download config
scp usuario@195.26.244.180:/home/usuario/vpn-clients/cliente1.ovpn .
```

## SSL Certificates Automation

### Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| `acme-dns-auth.py` | Certbot hook → actualiza TXT | `/etc/letsencrypt/` |
| `registro_acme.py` | Interactivo: registro + certbot | `/etc/letsencrypt/` |

### Usage

```bash
# Emitir certificado para un dominio
python3 /etc/letsencrypt/registro_acme.py

# Certbot manual con hook
sudo certbot certonly \
  --manual \
  --preferred-challenges dns \
  --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py \
  --manual-cleanup-hook /bin/true \
  -d n8n.dgetahgo.edu.mx
```

### Storage

- **Accounts**: `/etc/letsencrypt/acmedns.json`
- **Certificates**: `/etc/letsencrypt/live/`
- **Logs**: `/var/log/letsencrypt/`

## Docker Services

### n8n (Workflow Automation)

**Status**: ⏸️ Configured, stopped

**Compose**: `/opt/n8n/docker-compose.yml`

```yaml
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=n8n.dgetahgo.edu.mx
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://n8n.dgetahgo.edu.mx/
      - GENERIC_TIMEZONE=America/Mexico_City
      - TZ=America/Mexico_City
    volumes:
      - ./data:/home/node/.n8n
```

**Start:**
```bash
cd /opt/n8n && docker compose up -d
```

### OpenVPN

**Status**: ✅ Running

**Compose**: `/opt/openvpn/docker-compose.yml`

**Start:**
```bash
cd /opt/openvpn && docker compose up -d
```

## CI/CD Configuration

### GitHub Actions

**File**: `.github/workflows/vpn.yml` (local copy)

#### Workflows

| Trigger | Action | Description |
|---------|--------|-------------|
| `push: main` | Deploy | Auto-deploy infrastructure |
| `workflow_dispatch` | Backup | Manual backup |
| `workflow_dispatch` | Generate Client | Create VPN client |
| `schedule: */15 * * * *` | Health Check | Monitor services |

#### Required Secrets

```yaml
VPS_SSH_KEY: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ... (usuario SSH private key)
  -----END OPENSSH PRIVATE KEY-----
```

### Automation Scripts

All scripts support CI/CD:
- Exit codes: 0=success, 1=error
- Non-interactive (when run via SSH)
- Logging to `/var/log/vpn-scripts.log`

### Example CI/CD Usage

```bash
# Deploy via SSH
ssh usuario@195.26.244.180 \
  /home/usuario/vpn-scripts/deploy-vpn-infrastructure.sh

# Generate client
ssh usuario@195.26.244.180 \
  /home/usuario/vpn-scripts/vpn-generate-client.sh cliente1

# Download client
scp usuario@195.26.244.180:/home/usuario/vpn-clients/cliente1.ovpn .
```

## AWS CLI Configuration

**Version**: `aws-cli/2.34.29`

**Credentials**: `~/.aws/credentials`
```ini
[default]
aws_access_key_id = AKIAUPMYNKFIPADNMBQF
aws_secret_access_key = [REDACTED]
```

**Config**: `~/.aws/config`
```ini
[default]
region = us-east-1
output = json
```

**IAM User**: `route53-linux`
- **Account**: `307946672464`
- **Permissions**: `route53:ChangeResourceRecordSets`

## Installed Packages

### Core
- nginx 1.24.0
- certbot + python3-certbot-nginx
- docker.io 29.1.3
- docker-compose-v2 2.40.3
- aws-cli 2.34.29

### Python
- python3-requests

### DNS
- acme-dns (binary: `/usr/local/bin/acme-dns`)
- bind-utils (dig, host)

## File Structure

```
/etc/
├── nginx/
│   ├── sites-available/
│   │   ├── n8n.dgetahgo.edu.mx
│   │   ├── pbx.dgetahgo.edu.mx
│   │   ├── pve.dgetahgo.edu.mx
│   │   ├── test.dgetahgo.edu.mx
│   │   ├── vps1.dgetahgo.edu.mx
│   │   └── webmail.dgetahgo.edu.mx
│   └── sites-enabled/  (symlinks)
├── acme-dns/
│   ├── config.cfg
│   └── certs/
│       ├── privkey.pem
│       └── fullchain.pem
├── letsencrypt/
│   ├── acme-dns-auth.py
│   ├── registro_acme.py
│   └── acmedns.json
├── systemd/system/
│   └── acme-dns.service
└── ssh/
    └── sshd_config  (key-only auth)

/opt/
├── n8n/
│   ├── docker-compose.yml
│   └── data/
└── openvpn/
    ├── docker-compose.yml
    └── data/
        └── pki/

/home/usuario/
├── .ssh/
│   └── authorized_keys
├── .aws/
│   ├── credentials
│   └── config
├── vpn-scripts/
│   ├── vpn-generate-client.sh
│   ├── vpn-revoke-client.sh
│   ├── vpn-list-clients.sh
│   ├── vpn-backup.sh
│   └── deploy-vpn-infrastructure.sh
├── vpn-clients/
│   └── *.ovpn files
└── vpn-backups/
    └── *.tar.gz files

/var/
├── www/
│   ├── vps1/index.html
│   └── test/index.html
├── lib/acme-dns/
│   └── acme-dns.db
└── log/
    ├── vpn-scripts.log
    └── nginx/
```

## Common Operations

### Check Services
```bash
# Ver todos los servicios
systemctl status nginx acme-dns
docker ps

# Ver puertos en uso
ss -tlnp

# Ver logs
tail -f /var/log/nginx/access.log
tail -f /var/log/vpn-scripts.log
journalctl -u acme-dns -f
docker logs openvpn -f
```

### DNS Validation
```bash
# Verificar DNS externo
dig +short n8n.dgetahgo.edu.mx @8.8.8.8
dig +short auth.dgetahgo.edu.mx NS @8.8.8.8

# Verificar acme-dns
nslookup -type=SOA auth.dgetahgo.edu.mx ns1.auth.dgetahgo.edu.mx
```

### SSL Certificate Operations
```bash
# Emitir nuevo certificado
python3 /etc/letsencrypt/registro_acme.py

# Renovar certificados
sudo certbot renew

# Ver certificados existentes
sudo certbot certificates
```

### VPN Operations
```bash
# Generar cliente
/home/usuario/vpn-scripts/vpn-generate-client.sh cliente1

# Listar clientes
/home/usuario/vpn-scripts/vpn-list-clients.sh

# Revocar cliente
/home/usuario/vpn-scripts/vpn-revoke-client.sh cliente1

# Backup
/home/usuario/vpn-scripts/vpn-backup.sh
```

## Troubleshooting

### SSH Access Denied
```bash
# Verificar llave
ssh -v usuario@195.26.244.180

# Verificar authorized_keys
cat /home/usuario/.ssh/authorized_keys

# Permisos correctos
chmod 700 /home/usuario/.ssh
chmod 600 /home/usuario/.ssh/authorized_keys
```

### ACME-DNS no responde
```bash
# Verificar proceso
systemctl status acme-dns

# Reiniciar
systemctl restart acme-dns

# Ver logs
journalctl -u acme-dns -n 50
```

### Nginx error
```bash
# Test config
nginx -t

# Reload
systemctl reload nginx

# Ver errores
tail -f /var/log/nginx/error.log
```

### OpenVPN Issues
```bash
# Check container
docker ps | grep openvpn
docker logs openvpn

# Check port
ss -ulnp | grep 1194

# Check firewall
sudo ufw status | grep 1194

# List connected clients
docker exec openvpn ovpn_status
```

### Docker issues
```bash
# List containers
docker ps -a

# View logs
docker logs n8n -f --tail 100

# Restart
cd /opt/n8n && docker compose restart
```

## Security Considerations

- **SSH**: Key-only authentication (password disabled)
- **User**: `usuario` has passwordless sudo
- **AWS Keys**: Stored in `/home/usuario/.aws/` (permissions 600)
- **ACME-DNS**: API on 8444 with self-signed certs
- **Nginx**: HTTP only (certificates pending)
- **VPN**: Separate certificates per client, CRL enabled
- **Backups**: Automated daily, 30-day retention

## Future Additions

- [x] OpenVPN Server (✅ Done)
- [x] CI/CD GitHub Actions (✅ Done)
- [x] Terraform IaC (✅ Done)
- [ ] Certificados SSL para todos los dominios
- [ ] Firewall (ufw) hardening
- [ ] Fail2ban
- [ ] Monitoring (Prometheus/Grafana)
- [ ] Backups automatizados a S3
- [ ] n8n levantado y configurado
- [ ] PBX/Proxmox/Webmail

## Skills

| Skill | Description | Path |
|-------|-------------|------|
| `dgetahgo-server-acme` | ACME-DNS management | [skills/dgetahgo-server-acme/](skills/dgetahgo-server-acme/) |
| `dgetahgo-server-nginx` | Nginx reverse proxy | [skills/dgetahgo-server-nginx/](skills/dgetahgo-server-nginx/) |
| `dgetahgo-server-route53` | AWS Route 53 DNS | [skills/dgetahgo-server-route53/](skills/dgetahgo-server-route53/) |
| `dgetahgo-server-docker` | Docker services | [skills/dgetahgo-server-docker/](skills/dgetahgo-server-docker/) |
| `dgetahgo-server-openvpn` | OpenVPN server | [skills/dgetahgo-server-openvpn/](skills/dgetahgo-server-openvpn/) |
| `dgetahgo-server-cicd` | CI/CD automation | [skills/dgetahgo-server-cicd/](skills/dgetahgo-server-cicd/) |
| `dgetahgo-server-terraform` | Terraform IaC | [skills/dgetahgo-server-terraform/](skills/dgetahgo-server-terraform/) |

## References

- [ACME-DNS Documentation](https://github.com/joohoi/acme-dns)
- [Certbot Documentation](https://eff-certbot.readthedocs.io/)
- [AWS Route 53 API](https://docs.aws.amazon.com/cli/latest/reference/route53/)
- [Nginx Proxy Documentation](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
- [OpenVPN Docker](https://github.com/kylemanna/docker-openvpn)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Terraform](https://www.terraform.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)

## Team

- **Infrastructure**: infraestructura@computocontable.com
- **Project**: DGETAHGO Educational Infrastructure
- **Created**: 2026-04-12
- **Last Updated**: 2026-04-12 (Added Terraform IaC)

---
*This project is documented following agents.md specifications*
