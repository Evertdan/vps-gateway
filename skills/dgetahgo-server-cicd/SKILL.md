---
name: dgetahgo-server-cicd
description: >
  CI/CD automation and Infrastructure as Code for dgetahgo.edu.mx.
  Trigger: When setting up GitHub Actions, automated deployments, or infrastructure provisioning.
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## When to Use

- Setting up GitHub Actions workflows
- Automating VPN client generation
- Configuring Infrastructure as Code
- Setting up automated backups
- SSH key management for CI/CD
- GitHub Secrets configuration

## Current Setup

### SSH Access for CI/CD

| User | Auth Method | Sudo | Purpose |
|------|-------------|------|---------|
| `usuario` | SSH Key | Passwordless | CI/CD automation |

**SSH Key Location**: `/home/usuario/.ssh/authorized_keys`

**Test Connection**:
```bash
ssh usuario@195.26.244.180 "sudo whoami"
# Should return: root
```

### GitHub Actions Workflows

#### vpn.yml - Main Workflow
```yaml
name: VPN Infrastructure Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      action:
        type: choice
        options: [deploy, backup, generate-client, revoke-client]
      client_name:
        required: false
```

**Jobs**:
- `deploy`: Full infrastructure deployment
- `backup`: Create and download backup
- `generate-client`: Create client and upload .ovpn
- `revoke-client`: Revoke client certificate
- `health-check`: Scheduled monitoring (every 15 min)

### Required GitHub Secrets

```yaml
VPS_SSH_KEY: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  (usuario private key - ed25519)
  -----END OPENSSH PRIVATE KEY-----
```

**How to get the key**:
```bash
# From local machine with access
cat ~/.ssh/id_ed25519
# OR if using the generated key
cat ~/.ssh/usuario_vps1_key
```

## Infrastructure as Code

### File Structure
```
.github/
└── workflows/
    └── vpn.yml                 # Main CI/CD workflow

vpn/
├── scripts/
│   ├── vpn-generate-client.sh
│   ├── vpn-revoke-client.sh
│   ├── vpn-list-clients.sh
│   └── vpn-backup.sh
└── README.md

ansible/                        # (Optional)
terraform/                      # (Optional)
```

### Deployment Scripts

#### deploy-vpn-infrastructure.sh
**Location**: `/home/usuario/vpn-scripts/`

**Purpose**: Idempotent deployment script

```bash
./deploy-vpn-infrastructure.sh [environment]

Actions:
1. Check requirements (docker, docker-compose)
2. Setup directories
3. Deploy/Update OpenVPN container
4. Configure firewall
5. Setup monitoring
6. Verify deployment
```

**Exit Codes**:
- `0`: Success
- `1`: Error (check logs)

### Automated Tasks

#### Cron Jobs (Server-side)
```bash
# Daily backup at 2 AM
0 2 * * * /home/usuario/vpn-scripts/vpn-backup.sh

# Health check every 5 minutes
*/5 * * * * /usr/local/bin/vpn-health-check.sh
```

## Commands

### Manual CI/CD Operations

```bash
# Deploy infrastructure
ssh usuario@195.26.244.180 \
  "/home/usuario/vpn-scripts/deploy-vpn-infrastructure.sh production"

# Generate client via SSH
ssh usuario@195.26.244.180 \
  "/home/usuario/vpn-scripts/vpn-generate-client.sh cliente1"

# Download client config
scp usuario@195.26.244.180:/home/usuario/vpn-clients/cliente1.ovpn .

# Backup and download
ssh usuario@195.26.244.180 "/home/usuario/vpn-scripts/vpn-backup.sh"
scp usuario@195.26.244.180:/home/usuario/vpn-backups/*.tar.gz ./backups/
```

### GitHub Actions Usage

#### Trigger Workflow via GitHub CLI
```bash
# Deploy
gh workflow run vpn.yml -f action=deploy

# Generate client
gh workflow run vpn.yml \
  -f action=generate-client \
  -f client_name=empleado-juan

# Backup
gh workflow run vpn.yml -f action=backup
```

#### Check Workflow Status
```bash
gh run list --workflow=vpn.yml
gh run watch <run-id>
```

## CI/CD Patterns

### Generate Client via GitHub Actions
1. Go to Actions → VPN Infrastructure Deploy
2. Click "Run workflow"
3. Select action: `generate-client`
4. Enter client name
5. Workflow creates client and uploads .ovpn as artifact
6. Download artifact from workflow run

### Automated Backup
- **Scheduled**: Daily at 2 AM (cron on server)
- **Manual**: Via GitHub Actions workflow
- **Retention**: 30 days (configurable)
- **Storage**: `/home/usuario/vpn-backups/`

### Health Monitoring
- **Frequency**: Every 15 minutes
- **Method**: GitHub Actions scheduled workflow
- **Checks**:
  - OpenVPN container running
  - Port 1194 accessible
  - Certificate validity
- **Alerts**: Workflow failure notification

## Setup Instructions

### Initial Setup

1. **Create Repository**
   ```bash
   mkdir dgetahgo-infra
   cd dgetahgo-infra
   git init
   ```

2. **Add Workflow File**
   ```bash
   mkdir -p .github/workflows
   # Copy vpn.yml content
   ```

3. **Configure GitHub Secrets**
   - Go to Settings → Secrets and variables → Actions
   - Add `VPS_SSH_KEY` with private key content

4. **Test Deployment**
   ```bash
   git add .
   git commit -m "Initial CI/CD setup"
   git push
   # Check Actions tab for deployment
   ```

### SSH Key Rotation

1. Generate new key pair locally
2. Add public key to server:
   ```bash
   ssh usuario@195.26.244.180
   echo 'NEW_PUBLIC_KEY' >> ~/.ssh/authorized_keys
   ```
3. Update `VPS_SSH_KEY` secret in GitHub
4. Remove old key from `authorized_keys`

## Troubleshooting

### GitHub Actions Failures

#### "Permission denied (publickey)"
- Check `VPS_SSH_KEY` secret is correct
- Verify key is added to `/home/usuario/.ssh/authorized_keys`
- Ensure key format (OpenSSH, not PEM)

#### "docker: command not found"
- Verify Docker is installed: `ssh usuario@195.26.244.180 "docker --version"`
- Check if user has docker group: `groups usuario`

#### Script fails silently
- Add `set -x` to scripts for debug output
- Check logs: `ssh usuario@195.26.244.180 "cat /var/log/vpn-scripts.log"`

### SSH Connection Issues

```bash
# Test SSH connection
ssh -v usuario@195.26.244.180

# Check authorized_keys
ssh usuario@195.26.244.180 "cat ~/.ssh/authorized_keys"

# Verify permissions
ssh usuario@195.26.244.180 "ls -la ~/.ssh/"
# Should be: 700 (dir), 600 (authorized_keys)
```

## Security Best Practices

- **SSH Key**: Use dedicated key for CI/CD (not personal key)
- **Secrets**: Never commit secrets to repository
- **Permissions**: Use minimal required permissions
- **Audit**: Review GitHub Actions logs regularly
- **Rotation**: Rotate SSH keys every 90 days

## Resources

- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **SSH Key Management**: https://docs.github.com/en/authentication/connecting-to-github-with-ssh
- **Project**: [PROJECT.md](../../PROJECT.md)
- **VPN Skill**: [dgetahgo-server-openvpn](../dgetahgo-server-openvpn/SKILL.md)
