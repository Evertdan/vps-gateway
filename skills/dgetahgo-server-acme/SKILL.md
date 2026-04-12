---
name: dgetahgo-server-acme
description: >
  ACME-DNS server management for automated SSL certificate generation using DNS-01 challenge.
  Trigger: When configuring acme-dns, issuing SSL certificates, or managing DNS-01 validation.
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## When to Use

- Installing or configuring acme-dns server
- Issuing SSL certificates via DNS-01 challenge
- Debugging certificate issuance failures
- Registering new domains for ACME validation
- Managing acme-dns accounts (registration/updates)

## Critical Patterns

### ACME-DNS Server Location
- **Server**: `vps1.dgetahgo.edu.mx` (195.26.244.180)
- **DNS Port**: `195.26.244.180:53` (TCP/UDP)
- **API URL**: `https://auth.dgetahgo.edu.mx:8444`
- **Config**: `/etc/acme-dns/config.cfg`
- **Database**: `/var/lib/acme-dns/acme-dns.db`
- **Service**: `systemctl status acme-dns`

### Required DNS Records in Route 53

For acme-dns to function, these MUST exist in Route 53:

| Name | Type | Value | Purpose |
|------|------|-------|---------|
| `auth` | A | `195.26.244.180` | Points to acme-dns server |
| `ns1.auth` | A | `195.26.244.180` | Nameserver for auth subdomain |
| `auth` | NS | `ns1.auth.dgetahgo.edu.mx.` | Delegates auth subdomain |

### Certificate Issuance Flow

1. **Register** domain in acme-dns → get `fulldomain` (e.g., `uuid.auth.dgetahgo.edu.mx`)
2. **Create CNAME** in Route 53: `_acme-challenge.domain → fulldomain`
3. **Wait** for DNS propagation (up to 5 min with TTL 300)
4. **Run certbot** with auth hook → hook updates TXT record in acme-dns
5. **Let's Encrypt validates** TXT record via CNAME chain

### Scripts

| Script | Path | Purpose |
|--------|------|---------|
| `acme-dns-auth.py` | `/etc/letsencrypt/` | Certbot hook - updates TXT records |
| `registro_acme.py` | `/etc/letsencrypt/` | Interactive: register + verify + certbot |
| `acmedns.json` | `/etc/letsencrypt/` | Storage of acme-dns accounts |

## Commands

### Check acme-dns status
```bash
systemctl status acme-dns
journalctl -u acme-dns -f
```

### Test API
```bash
curl -sk https://auth.dgetahgo.edu.mx:8444/register -X POST
curl -sk https://auth.dgetahgo.edu.mx:8444/update \
  -H "X-Api-User: USERNAME" \
  -H "X-Api-Key: PASSWORD" \
  -d '{"subdomain": "SUBDOMAIN", "txt": "TOKEN"}'
```

### Issue certificate interactively
```bash
python3 /etc/letsencrypt/registro_acme.py
```

### Issue certificate manually
```bash
# First, get credentials from acmedns.json
cat /etc/letsencrypt/acmedns.json

# Then run certbot
sudo certbot certonly \
  --manual \
  --preferred-challenges dns \
  --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py \
  --manual-cleanup-hook /bin/true \
  --email infraestructura@computocontable.com \
  --agree-tos \
  -d n8n.dgetahgo.edu.mx
```

### Renew certificates
```bash
# Test renewal
sudo certbot renew --dry-run

# Actual renewal
sudo certbot renew
```

## Code Examples

### Register new domain in acme-dns
```python
import requests

response = requests.post(
    "https://auth.dgetahgo.edu.mx:8444/register",
    verify=False
)
account = response.json()
# Returns: username, password, fulldomain, subdomain
```

### Update TXT record
```python
import requests

update = {"subdomain": account["subdomain"], "txt": validation_token}
headers = {
    "X-Api-User": account["username"],
    "X-Api-Key": account["password"],
    "Content-Type": "application/json"
}

response = requests.post(
    "https://auth.dgetahgo.edu.mx:8444/update",
    headers=headers,
    json=update,
    verify=False
)
```

## Configuration Reference

### /etc/acme-dns/config.cfg
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

[api]
ip = "0.0.0.0"
port = "8444"
tls = "cert"
tls_cert_privkey = "/etc/acme-dns/certs/privkey.pem"
tls_cert_fullchain = "/etc/acme-dns/certs/fullchain.pem"
```

## Troubleshooting

### "Could not resolve auth.dgetahgo.edu.mx"
- Verify Route 53 has A record for `auth`
- Verify NS record delegates `auth` to `ns1.auth`
- Check with: `dig auth.dgetahgo.edu.mx @8.8.8.8`

### "No TXT record found"
- Verify CNAME exists: `dig _acme-challenge.domain CNAME @8.8.8.8`
- Check acme-dns received update via API
- Wait for DNS propagation (may take 5-10 min)

### "Connection refused to :8444"
- Check acme-dns is running: `systemctl status acme-dns`
- Verify firewall allows port 8444
- Check certs exist: `ls /etc/acme-dns/certs/`

## Resources

- **Templates**: See [assets/](assets/) for config templates
- **Documentation**: [PROJECT.md](../../PROJECT.md)
- **Upstream**: https://github.com/joohoi/acme-dns
