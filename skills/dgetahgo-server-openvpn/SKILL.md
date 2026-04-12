---
name: dgetahgo-server-openvpn
description: >
  OpenVPN server deployment and management for dgetahgo.edu.mx infrastructure.
  Trigger: When installing, configuring, or managing OpenVPN server and client certificates.
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.1"
---

## When to Use

- OpenVPN server is already installed and running
- Creating new VPN client certificates
- Revoking existing client certificates
- Backing up VPN PKI infrastructure
- Troubleshooting VPN connectivity issues
- CI/CD automation for VPN management

## Current Status

| Component | Status | Details |
|-----------|--------|---------|
| **OpenVPN Container** | ✅ Running | `kylemanna/openvpn:latest` |
| **Port** | ✅ Active | `1194/udp` |
| **VPN Subnet** | ✅ Configured | `192.168.255.0/24` |
| **Scripts** | ✅ Available | 4 automation scripts |
| **CI/CD** | ✅ Ready | GitHub Actions compatible |

## Architecture

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

### Directory Structure
```
/opt/openvpn/
├── docker-compose.yml
├── data/
│   └── pki/              # PKI certificates
│       ├── ca.crt
│       ├── issued/       # Client certificates
│       └── private/      # Private keys
│
/home/usuario/
├── vpn-scripts/          # Management scripts
│   ├── vpn-generate-client.sh
│   ├── vpn-revoke-client.sh
│   ├── vpn-list-clients.sh
│   └── vpn-backup.sh
├── vpn-clients/          # Generated .ovpn files
└── vpn-backups/          # Automated backups
```

## Automation Scripts

### vpn-generate-client.sh
**Purpose**: Create new VPN client certificate and .ovpn file

```bash
Usage: ./vpn-generate-client.sh <client-name> [email]
Output: /home/usuario/vpn-clients/<client-name>.ovpn
```

**Features**:
- Validates client name (alphanumeric, hyphen, underscore)
- Generates certificate with EasyRSA
- Creates .ovpn config file
- Logs to `/var/log/vpn-scripts.log`
- CI/CD friendly (exit codes: 0=success, 1=error, 2=invalid args)

### vpn-revoke-client.sh
**Purpose**: Revoke client certificate

```bash
Usage: ./vpn-revoke-client.sh <client-name>
Actions: Revokes cert, removes .ovpn file, generates CRL
```

### vpn-list-clients.sh
**Purpose**: List all VPN clients

```bash
Usage: ./vpn-list-clients.sh [--format=table|csv|json]
Formats: table (default), csv, json
```

### vpn-backup.sh
**Purpose**: Backup OpenVPN PKI

```bash
Usage: ./vpn-backup.sh [--output=path] [--retention=days]
Default: /home/usuario/vpn-backups/, 30-day retention
Cron: Daily at 2 AM
```

### deploy-vpn-infrastructure.sh
**Purpose**: Complete deployment/redeployment

```bash
Usage: ./deploy-vpn-infrastructure.sh [environment]
Actions: Setup directories, deploy container, configure firewall, verify
```

## Commands

### Server Management
```bash
# Check status
sudo docker ps | grep openvpn
sudo docker compose -f /opt/openvpn/docker-compose.yml ps

# View logs
sudo docker logs openvpn -f
sudo docker logs openvpn --tail 100

# Restart
sudo docker compose -f /opt/openvpn/docker-compose.yml restart

# Enter container
sudo docker exec -it openvpn sh
```

### Client Operations
```bash
# Generate client (interactive)
/home/usuario/vpn-scripts/vpn-generate-client.sh client-name

# Generate client (CI/CD)
ssh usuario@195.26.244.180 /home/usuario/vpn-scripts/vpn-generate-client.sh client-name

# Download client config
scp usuario@195.26.244.180:/home/usuario/vpn-clients/client-name.ovpn .

# Revoke client
/home/usuario/vpn-scripts/vpn-revoke-client.sh client-name

# List clients
/home/usuario/vpn-scripts/vpn-list-clients.sh
/home/usuario/vpn-scripts/vpn-list-clients.sh --format=json
```

### Manual Operations (if scripts fail)
```bash
# Generate client manually
cd /opt/openvpn
sudo docker run -v $PWD/data:/etc/openvpn --rm -e EASYRSA_BATCH=1 \
  kylemanna/openvpn easyrsa build-client-full client-name nopass

# Get .ovpn file
sudo docker run -v /opt/openvpn/data:/etc/openvpn --rm \
  kylemanna/openvpn ovpn_getclient client-name > client-name.ovpn

# Revoke manually
sudo docker run -v /opt/openvpn/data:/etc/openvpn --rm -e EASYRSA_BATCH=1 \
  kylemanna/openvpn ovpn_revokeclient client-name remove
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/vpn.yml
name: VPN Infrastructure Deploy

on:
  workflow_dispatch:
    inputs:
      action:
        type: choice
        options:
          - generate-client
          - revoke-client
          - backup
      client_name:
        required: false

jobs:
  manage-vpn:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.8.0
        with:
          ssh-private-key: ${{ secrets.VPS_SSH_KEY }}
      
      - name: Execute VPN Action
        run: |
          ssh usuario@195.26.244.180 \
            "/home/usuario/vpn-scripts/vpn-${{ github.event.inputs.action }}.sh ${{ github.event.inputs.client_name }}"
```

### Required Secret
```yaml
VPS_SSH_KEY: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ... (usuario private key)
  -----END OPENSSH PRIVATE KEY-----
```

## Firewall Configuration

### UFW Rules (Already Applied)
```bash
# Allow OpenVPN port
sudo ufw allow 1194/udp comment 'OpenVPN'

# Enable IP forwarding
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-openvpn.conf
sudo sysctl -p

# NAT for VPN clients (applied via Docker)
sudo iptables -t nat -A POSTROUTING -s 192.168.255.0/24 -o eth0 -j MASQUERADE
```

## Monitoring

### Health Checks
```bash
# Check if container is running
sudo docker ps | grep openvpn

# Check port is listening
sudo ss -ulnp | grep 1194

# Check connected clients
sudo docker exec openvpn ovpn_status

# View logs
sudo docker logs openvpn --tail 50
```

### Automated Monitoring
- Health check every 15 minutes via GitHub Actions
- Logs written to `/var/log/vpn-scripts.log`
- Backup verification daily

## Troubleshooting

### Container won't start
```bash
# Check logs
sudo docker logs openvpn

# Check port conflicts
sudo ss -ulnp | grep 1194

# Verify data directory
ls -la /opt/openvpn/data/pki/
```

### Client cannot connect
1. Verify server is running: `sudo docker ps | grep openvpn`
2. Check firewall: `sudo ufw status | grep 1194`
3. Verify client cert: `openssl x509 -in client.ovpn -text -noout`
4. Check logs: `sudo docker logs openvpn | grep client-name`

### Certificate issues
```bash
# Regenerate CRL
sudo docker run -v /opt/openvpn/data:/etc/openvpn --rm \
  kylemanna/openvpn easyrsa gen-crl

# Update CRL in container
sudo docker exec openvpn ovpn_crl_update
```

## Security

- **Client isolation**: Each client has unique certificate
- **CRL**: Certificate Revocation List enabled
- **No password**: Client certs use nopass (PKI secured)
- **Firewall**: UFW + iptables rules applied
- **Backup encryption**: Backups stored with restricted permissions

## Resources

- **Templates**: See [assets/](assets/) for docker-compose template
- **Project Docs**: [PROJECT.md](../../PROJECT.md)
- **Upstream**: https://github.com/kylemanna/docker-openvpn
- **OpenVPN**: https://openvpn.net/community-resources/
