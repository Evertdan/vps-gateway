# DGETAHGO Infrastructure - Project Index

## Documentation Files

| File | Description |
|------|-------------|
| [DOCUMENTACION_COMPLETA.md](DOCUMENTACION_COMPLETA.md) | **Documentación técnica maestra** |
| [PROJECT.md](PROJECT.md) | Complete project documentation |
| [AGENTS.md](AGENTS.md) | Agent skills registry (agents.md format) |
| [INDEX.md](INDEX.md) | This file - project navigation |

## Skills (agents.md + skills.sh format)

| Skill | Purpose | Status |
|-------|---------|--------|
| [dgetahgo-server-acme](skills/dgetahgo-server-acme/SKILL.md) | ACME-DNS SSL management | ✅ Active |
| [dgetahgo-server-nginx](skills/dgetahgo-server-nginx/SKILL.md) | Nginx reverse proxy | ✅ Active |
| [dgetahgo-server-route53](skills/dgetahgo-server-route53/SKILL.md) | AWS Route 53 DNS | ✅ Active |
| [dgetahgo-server-docker](skills/dgetahgo-server-docker/SKILL.md) | Docker containers | ✅ Active |
| [dgetahgo-server-openvpn](skills/dgetahgo-server-openvpn/SKILL.md) | OpenVPN server | ✅ Active |
| [dgetahgo-server-cicd](skills/dgetahgo-server-cicd/SKILL.md) | CI/CD automation | ✅ Active |
| [dgetahgo-server-terraform](skills/dgetahgo-server-terraform/SKILL.md) | Terraform IaC | ✅ Active |

## Server Configuration Files

### Nginx
- `/etc/nginx/sites-available/n8n.dgetahgo.edu.mx`
- `/etc/nginx/sites-available/pbx.dgetahgo.edu.mx`
- `/etc/nginx/sites-available/pve.dgetahgo.edu.mx`
- `/etc/nginx/sites-available/test.dgetahgo.edu.mx`
- `/etc/nginx/sites-available/vps1.dgetahgo.edu.mx`
- `/etc/nginx/sites-available/webmail.dgetahgo.edu.mx`

### ACME-DNS
- `/etc/acme-dns/config.cfg`
- `/etc/acme-dns/certs/privkey.pem`
- `/etc/acme-dns/certs/fullchain.pem`
- `/etc/systemd/system/acme-dns.service`

### SSL Automation
- `/etc/letsencrypt/acme-dns-auth.py`
- `/etc/letsencrypt/registro_acme.py`
- `/etc/letsencrypt/acmedns.json`

### OpenVPN
- `/opt/openvpn/docker-compose.yml`
- `/opt/openvpn/data/pki/` (certificates)
- `/home/usuario/vpn-scripts/vpn-generate-client.sh`
- `/home/usuario/vpn-scripts/vpn-revoke-client.sh`
- `/home/usuario/vpn-scripts/vpn-list-clients.sh`
- `/home/usuario/vpn-scripts/vpn-backup.sh`
- `/home/usuario/vpn-scripts/deploy-vpn-infrastructure.sh`

### Docker
- `/opt/n8n/docker-compose.yml`
- `/opt/openvpn/docker-compose.yml`

### AWS
- `~/.aws/credentials`
- `~/.aws/config`

### SSH
- `/home/usuario/.ssh/authorized_keys`

### Terraform
- `terraform/main.tf`                    # DNS records
- `terraform/variables.tf`               # Variables
- `terraform/provider.tf`                # AWS provider
- `terraform/backend.tf`                 # State backend
- `terraform/outputs.tf`                 # Outputs
- `terraform/terraform.tfvars`           # Values (gitignored)

## CI/CD Configuration

### GitHub Actions
```yaml
# .github/workflows/vpn.yml
Triggers:
  - push: main (auto-deploy)
  - workflow_dispatch (manual)
    - action: deploy | backup | generate-client | revoke-client
  - schedule: */15 * * * * (health check)

Secrets Required:
  - VPS_SSH_KEY (usuario private key)
```

### Scripts Location
```
/home/usuario/vpn-scripts/
├── vpn-generate-client.sh      # Create client cert + .ovpn
├── vpn-revoke-client.sh        # Revoke client
├── vpn-list-clients.sh         # List all clients
├── vpn-backup.sh               # Backup PKI
└── deploy-vpn-infrastructure.sh # Full deployment
```

## Quick Commands

```bash
# SSH to server
ssh usuario@195.26.244.180

# Check all services
systemctl status nginx acme-dns
sudo docker ps

# View logs
journalctl -u acme-dns -f
sudo docker logs openvpn -f
tail -f /var/log/vpn-scripts.log

# Issue SSL certificate
python3 /etc/letsencrypt/registro_acme.py

# Start n8n
cd /opt/n8n && docker compose up -d

# VPN - Generate client
ssh usuario@195.26.244.180 \
  /home/usuario/vpn-scripts/vpn-generate-client.sh <name>

# VPN - Download client config
scp usuario@195.26.244.180:/home/usuario/vpn-clients/<name>.ovpn .

# Check DNS propagation
dig +short n8n.dgetahgo.edu.mx @8.8.8.8

# Terraform - Plan changes
cd terraform/ && terraform init && terraform plan

# Terraform - Apply changes
cd terraform/ && terraform apply -auto-approve

```

## Project Status

| Component | Status | Notes |
|-----------|--------|-------|
| DNS (Route 53) | ✅ Complete | All A and NS records active |
| acme-dns | ✅ Complete | DNS + API operational |
| nginx | ✅ Complete | 6 server blocks configured |
| SSL Scripts | ✅ Complete | Both Python scripts ready |
| OpenVPN | ✅ Complete | Running, CI/CD scripts ready |
| n8n | ⏸️ Ready | Configured, not started |
| SSL Certs | ⏸️ Pending | Run registro_acme.py |
| CI/CD GitHub | ✅ Ready | Workflow files created locally |
| Terraform | ✅ Ready | Configuration files created |

## Service Ports

| Port | Service | Status | Description |
|------|---------|--------|-------------|
| 22 | SSH | ✅ Active | Key-only auth (usuario) |
| 53 | acme-dns | ✅ Active | DNS server |
| 80 | nginx | ✅ Active | Reverse proxy |
| 443 | nginx | ⏸️ Pending | HTTPS (needs certs) |
| 8444 | acme-dns | ✅ Active | API HTTPS |
| 1194/udp | OpenVPN | ✅ Active | VPN server |
| 5678 | n8n | ⏸️ Stopped | Workflow automation |

## External Resources

- **ACME-DNS**: https://github.com/joohoi/acme-dns
- **Certbot**: https://certbot.eff.org/
- **AWS Route 53**: https://aws.amazon.com/route53/
- **n8n**: https://n8n.io/
- **OpenVPN**: https://openvpn.net/
- **kylemanna/docker-openvpn**: https://github.com/kylemanna/docker-openvpn
- **Terraform**: https://www.terraform.io/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest

## Team

- **Infrastructure**: infraestructura@computocontable.com
- **Created**: 2026-04-12
- **Last Updated**: 2026-04-12 (Terraform IaC added)

---
*Generated: 2026-04-12*