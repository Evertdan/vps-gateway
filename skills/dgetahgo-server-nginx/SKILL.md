---
name: dgetahgo-server-nginx
description: >
  Nginx reverse proxy configuration for dgetahgo.edu.mx infrastructure.
  Trigger: When configuring nginx server blocks, proxy settings, or SSL termination.
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## When to Use

- Adding new server blocks (subdomains)
- Configuring reverse proxy for Docker/internal services
- Setting up SSL/TLS termination
- Troubleshooting nginx errors or 502/503 errors
- Adding WebSocket support (Upgrade headers)

## Critical Patterns

### Server Layout

| Server Block | Type | Destination | File |
|--------------|------|-------------|------|
| `vps1.dgetahgo.edu.mx` | Static | `/var/www/vps1` | `sites-available/vps1.dgetahgo.edu.mx` |
| `test.dgetahgo.edu.mx` | Static | `/var/www/test` | `sites-available/test.dgetahgo.edu.mx` |
| `n8n.dgetahgo.edu.mx` | Proxy | `http://127.0.0.1:5678` | `sites-available/n8n.dgetahgo.edu.mx` |
| `pbx.dgetahgo.edu.mx` | Proxy | `http://127.0.0.1:8080` | `sites-available/pbx.dgetahgo.edu.mx` |
| `pve.dgetahgo.edu.mx` | Proxy (HTTPS) | `https://127.0.0.1:8006` | `sites-available/pve.dgetahgo.edu.mx` |
| `webmail.dgetahgo.edu.mx` | Proxy | `http://127.0.0.1:8888` | `sites-available/webmail.dgetahgo.edu.mx` |

### Required Proxy Headers (ALL proxy blocks)

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

### Special Case: Proxmox (HTTPS backend)

Proxmox uses self-signed certs, so disable verification:

```nginx
proxy_pass https://127.0.0.1:8006;
proxy_ssl_verify off;  # REQUIRED for Proxmox
```

### File Locations

- **Available**: `/etc/nginx/sites-available/`
- **Enabled**: `/etc/nginx/sites-enabled/` (symlinks)
- **Default removed**: No `default` server block
- **Test config**: `nginx -t`
- **Reload**: `systemctl reload nginx`

## Commands

### Test and reload
```bash
nginx -t && systemctl reload nginx
```

### Check active server blocks
```bash
ls -la /etc/nginx/sites-enabled/
```

### View error logs
```bash
tail -f /var/log/nginx/error.log
tail -f /var/log/nginx/access.log
```

### Check nginx status
```bash
systemctl status nginx
ss -tlnp | grep nginx
```

## Code Examples

### Add new static site
```nginx
server {
    listen 80;
    server_name subdomain.dgetahgo.edu.mx;
    root /var/www/subdomain;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

### Add new proxy (Docker/internal service)
```nginx
server {
    listen 80;
    server_name service.dgetahgo.edu.mx;

    location / {
        proxy_pass http://127.0.0.1:PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Enable new site
```bash
ln -s /etc/nginx/sites-available/site.dgetahgo.edu.mx \
      /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

### Add SSL (after certbot)
```nginx
server {
    listen 443 ssl http2;
    server_name n8n.dgetahgo.edu.mx;
    
    ssl_certificate /etc/letsencrypt/live/n8n.dgetahgo.edu.mx/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/n8n.dgetahgo.edu.mx/privkey.pem;
    
    location / {
        proxy_pass http://127.0.0.1:5678;
        # ... proxy headers
    }
}

server {
    listen 80;
    server_name n8n.dgetahgo.edu.mx;
    return 301 https://$server_name$request_uri;
}
```

## Troubleshooting

### 502 Bad Gateway
- Backend service not running
- Wrong port in proxy_pass
- Check with: `curl http://127.0.0.1:PORT`

### 404 Not Found (static)
- Root directory doesn't exist
- File not in correct location
- Check with: `ls -la /var/www/site/`

### "Address already in use"
- Another process on port 80
- Check with: `ss -tlnp | grep :80`

### Config test fails
```bash
nginx -t
# Check syntax errors, usually missing semicolons
```

## Resources

- **Templates**: See [assets/](assets/) for server block templates
- **Documentation**: [PROJECT.md](../../PROJECT.md)
- **Nginx Docs**: https://nginx.org/en/docs/
