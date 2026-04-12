---
# Agent Registry - DGETAHGO Infrastructure
# https://agents.md/ specification

name: dgetahgo-infrastructure-registry
description: |
  Agent skills and operational context for vps1.dgetahgo.edu.mx VPS infrastructure.
  Provides secure VPN gateway for exposing local Docker projects to internet with 
  automated SSL, DNS, and reverse proxy.
version: "1.2.0"
last_updated: "2026-04-12"
license: MIT

# Agent Metadata
agent:
  name: Infrastructure Agent
  role: VPS Infrastructure Management
  capabilities:
    - VPN management (OpenVPN)
    - SSL certificate automation (acme-dns)
    - DNS management (Route 53)
    - Reverse proxy (Nginx)
    - Docker orchestration
    - Infrastructure as Code (Terraform)
    - CI/CD automation (GitHub Actions)

# Project Context
project:
  name: DGETAHGO VPS Gateway
  type: infrastructure-gateway
  domain: dgetahgo.edu.mx
  server:
    hostname: vps1.dgetahgo.edu.mx
    ip: 195.26.244.180
    provider: Contabo
    os: Ubuntu 24.04.4 LTS
  
# Environment
environment:
  primary_user: usuario
  auth_method: ssh_key
  sudo_access: passwordless
  
# External Services
services:
  aws:
    account: "307946672464"
    region: us-east-1
    route53_zone: Z0748356URLST7BWNN9D
  
  acme_dns:
    domain: auth.dgetahgo.edu.mx
    api_port: 8444
    dns_port: 53
  
  openvpn:
    port: 1194
    protocol: udp
    subnet: 192.168.255.0/24
    image: kylemanna/openvpn:latest
---

# Agent Skills Registry

> **Specification**: This registry follows [agents.md](https://agents.md/) standard for agent context management.

## Quick Start

### Activate Agent
```yaml
context: dgetahgo-infrastructure-registry
skills:
  - dgetahgo-server-openvpn
  - dgetahgo-server-nginx
  - dgetahgo-server-acme
```

### Common Operations

| Operation | Skills Required | Command |
|-----------|-----------------|---------|
| Create VPN client | `openvpn` | `vpn-generate-client.sh <name>` |
| Setup SSL | `acme`, `route53` | `registro_acme.py` |
| Deploy project | `docker`, `nginx`, `cicd` | GitHub Actions workflow |
| Manage DNS | `route53`, `terraform` | `terraform apply` |

---

## Registered Skills

### Core Infrastructure

| Skill | Version | Status | Path |
|-------|---------|--------|------|
| [dgetahgo-server-openvpn](skills/dgetahgo-server-openvpn/SKILL.md) | 1.1.0 | active | `skills/dgetahgo-server-openvpn/` |
| [dgetahgo-server-nginx](skills/dgetahgo-server-nginx/SKILL.md) | 1.0.0 | active | `skills/dgetahgo-server-nginx/` |
| [dgetahgo-server-acme](skills/dgetahgo-server-acme/SKILL.md) | 1.0.0 | active | `skills/dgetahgo-server-acme/` |
| [dgetahgo-server-route53](skills/dgetahgo-server-route53/SKILL.md) | 1.0.0 | active | `skills/dgetahgo-server-route53/` |

### Automation & Deployment

| Skill | Version | Status | Path |
|-------|---------|--------|------|
| [dgetahgo-server-docker](skills/dgetahgo-server-docker/SKILL.md) | 1.0.0 | active | `skills/dgetahgo-server-docker/` |
| [dgetahgo-server-cicd](skills/dgetahgo-server-cicd/SKILL.md) | 1.0.0 | active | `skills/dgetahgo-server-cicd/` |
| [dgetahgo-server-terraform](skills/dgetahgo-server-terraform/SKILL.md) | 1.0.0 | active | `skills/dgetahgo-server-terraform/` |

---

## Skill Activation Matrix

### When to Load Each Skill

```yaml
# VPN Management
load: dgetahgo-server-openvpn
when:
  - generating VPN clients
  - configuring static IPs (CCD)
  - troubleshooting VPN connectivity
  - managing certificates
  - "openvpn" mentioned in query

# Web Server
load: dgetahgo-server-nginx
when:
  - configuring reverse proxy
  - adding server blocks
  - SSL termination setup
  - "nginx" or "proxy" mentioned

# SSL Automation
load: dgetahgo-server-acme
when:
  - issuing SSL certificates
  - DNS-01 challenges
  - acme-dns configuration
  - "ssl", "certbot", "certificate" mentioned

# DNS Management
load: dgetahgo-server-route53
when:
  - creating DNS records
  - managing subdomains
  - AWS Route 53 operations
  - "dns", "route53" mentioned

# Container Management
load: dgetahgo-server-docker
when:
  - deploying containers
  - docker-compose operations
  - troubleshooting docker
  - "docker" mentioned

# CI/CD Automation
load: dgetahgo-server-cicd
when:
  - GitHub Actions workflows
  - automated deployments
  - SSH key management
  - "cicd", "github actions" mentioned

# Infrastructure as Code
load: dgetahgo-server-terraform
when:
  - provisioning infrastructure
  - managing Terraform state
  - Route 53 via Terraform
  - "terraform", "iac" mentioned
```

---

## System Architecture

```mermaid
graph TB
    subgraph "Internet"
        USER[User]
    end

    subgraph "VPS Gateway vps1.dgetahgo.edu.mx"
        DNS[Route 53 DNS]
        NGINX[Nginx Proxy SSL]
        ACME[acme-dns]
        OPENVPN[OpenVPN Server]
        
        subgraph "Automation"
            SCRIPTS[Shell Scripts]
            TERRAFORM[Terraform]
            CICD[GitHub Actions]
        end
    end

    subgraph "Client Projects"
        VPN_CLIENT[VPN Client]
        DOCKER[Docker Projects]
    end

    USER --> DNS
    DNS --> NGINX
    NGINX -->|HTTPS| VPN_CLIENT
    OPENVPN -->|Tunnel| VPN_CLIENT
    VPN_CLIENT --> DOCKER
    SCRIPTS -->|Manages| OPENVPN
    SCRIPTS -->|Manages| NGINX
    TERRAFORM -->|Provisions| DNS
```

---

## Service Inventory

| Port | Service | Protocol | Status | Managed By |
|------|---------|----------|--------|------------|
| 22 | SSH | TCP | ✅ Active | systemd |
| 53 | acme-dns DNS | UDP/TCP | ✅ Active | systemd |
| 80 | Nginx HTTP | TCP | ✅ Active | systemd |
| 443 | Nginx HTTPS | TCP | ✅ Active | certbot |
| 8444 | acme-dns API | TCP | ✅ Active | systemd |
| 1194 | OpenVPN | UDP | ✅ Active | Docker |
| 5678 | n8n | TCP | ⏸️ Ready | Docker |

---

## File System Map

```
/etc/
├── nginx/
│   ├── sites-available/    # Server block definitions
│   └── sites-enabled/      # Active symlinks
├── acme-dns/
│   └── config.cfg          # DNS server config
├── letsencrypt/
│   ├── acme-dns-auth.py    # Certbot hook
│   └── registro_acme.py    # Interactive script
└── systemd/system/
    └── acme-dns.service

/opt/
├── openvpn/
│   ├── docker-compose.yml
│   ├── data/
│   │   ├── openvpn.conf    # Server config
│   │   ├── ccd/            # Client static IPs
│   │   └── pki/            # Certificates
│   └── data/ccd/           # Client Config Directory
├── projects/
│   ├── scripts/            # Automation scripts
│   │   ├── create-project.sh
│   │   ├── delete-project.sh
│   │   ├── list-projects.sh
│   │   └── verify-vpn-client.sh
│   └── registry.json       # Project database
├── n8n/
│   └── docker-compose.yml
└── */                      # Other services

/home/usuario/
├── vpn-scripts/            # Legacy scripts
├── vpn-clients/            # Generated .ovpn files
├── vpn-backups/            # Automated backups
└── .ssh/authorized_keys    # SSH access

terraform/
├── main.tf                 # DNS records
├── variables.tf
├── provider.tf             # AWS provider
├── backend.tf              # State config
└── modules/
    └── projects/           # Reusable module
```

---

## Automation Scripts

### Project Management

| Script | Purpose | Location | CI/CD |
|--------|---------|----------|-------|
| `create-project.sh` | Full project pipeline | `/opt/projects/scripts/` | ✅ |
| `delete-project.sh` | Remove project | `/opt/projects/scripts/` | ✅ |
| `list-projects.sh` | List all projects | `/opt/projects/scripts/` | ✅ |
| `verify-vpn-client.sh` | Check client status | `/opt/projects/scripts/` | ✅ |

### VPN Management

| Script | Purpose | Location |
|--------|---------|----------|
| `vpn-generate-client.sh` | Create client cert | `/home/usuario/vpn-scripts/` |
| `vpn-revoke-client.sh` | Revoke client | `/home/usuario/vpn-scripts/` |
| `vpn-list-clients.sh` | List clients | `/home/usuario/vpn-scripts/` |
| `vpn-backup.sh` | Backup PKI | `/home/usuario/vpn-scripts/` |

---

## CI/CD Integration

### GitHub Actions

**Workflow**: `.github/workflows/project-gateway.yml`

```yaml
Triggers:
  workflow_dispatch:
    inputs:
      project_name: string
      client_name: string
      local_port: number
      client_exists: boolean

Jobs:
  create-gateway:
    - Setup SSH
    - Copy scripts
    - Execute create-project.sh
    - Upload VPN config (artifact)
```

### Required Secrets

```yaml
VPS_SSH_KEY: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  [usuario private key]
  -----END OPENSSH PRIVATE KEY-----

AWS_ACCESS_KEY_ID: AKIA...
AWS_SECRET_ACCESS_KEY: ...
```

---

## Operational Commands

### System Health
```bash
# Check all services
systemctl status nginx acme-dns
docker ps

# View logs
journalctl -u acme-dns -f
docker logs openvpn -f
tail -f /var/log/vpn-scripts.log
```

### VPN Operations
```bash
# Generate client
/home/usuario/vpn-scripts/vpn-generate-client.sh <name>

# Verify connection
/opt/projects/scripts/verify-vpn-client.sh <name>

# List connected clients
docker exec openvpn ovpn_status
```

### Project Operations
```bash
# Create project
/opt/projects/scripts/create-project.sh \
  --project=<name> \
  --client=<client> \
  --port=<port>

# List projects
/opt/projects/scripts/list-projects.sh --format=table

# Delete project
/opt/projects/scripts/delete-project.sh --project=<name>
```

### SSL Management
```bash
# Issue certificate
python3 /etc/letsencrypt/registro_acme.py

# Renew all
sudo certbot renew

# Check certificates
sudo certbot certificates
```

### Terraform
```bash
cd terraform/
terraform init
terraform plan
terraform apply -auto-approve
```

---

## Emergency Procedures

### VPN Down
```bash
# Restart OpenVPN
cd /opt/openvpn && docker compose restart

# Check logs
docker logs openvpn --tail 100
```

### SSL Expired
```bash
# Force renewal
sudo certbot renew --force-renewal

# Reload nginx
sudo systemctl reload nginx
```

### Nginx Error
```bash
# Test config
sudo nginx -t

# Check error logs
sudo tail -f /var/log/nginx/error.log
```

---

## Contact & Support

| Role | Contact |
|------|---------|
| Infrastructure | infraestructura@computocontable.com |
| Server | vps1.dgetahgo.edu.mx (195.26.244.180) |
| Documentation | See [DOCUMENTACION_COMPLETA.md](DOCUMENTACION_COMPLETA.md) |

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.2.0 | 2026-04-12 | Added Terraform IaC, project automation scripts, updated agents.md format |
| 1.1.0 | 2026-04-12 | Added OpenVPN CCD, CI/CD workflows, usuario SSH setup |
| 1.0.0 | 2026-04-12 | Initial setup: nginx, acme-dns, docker |

---

*This registry follows [agents.md](https://agents.md/) specification v1.0*
