---
name: dgetahgo-server-docker
description: >
  Docker container management for dgetahgo.edu.mx services (n8n, and future services).
  Trigger: When deploying, updating, or debugging Docker containers and compose services.
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## When to Use

- Deploying new Docker services
- Updating existing containers
- Debugging container issues
- Managing Docker networks and volumes
- Viewing container logs

## Critical Patterns

### Service Locations

| Service | Path | Compose File | Container Name | Port |
|---------|------|--------------|----------------|------|
| n8n | `/opt/n8n` | `docker-compose.yml` | `n8n` | 5678 |

### Docker Versions

- **Docker Engine**: `29.1.3`
- **Docker Compose**: `2.40.3`
- **API Version**: `1.49`

### Network Mode

- Default bridge network created per compose project
- Services exposed via `ports:` map to host
- Inter-container communication via service names

### Data Persistence

- Use named volumes or bind mounts
- n8n: `./data:/home/node/.n8n` (bind mount relative to compose)
- Always backup volumes before updates

## Commands

### n8n Operations

```bash
cd /opt/n8n

# Start
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f

# Restart
docker compose restart

# Update image
docker compose pull
docker compose up -d

# Check status
docker compose ps
```

### General Docker

```bash
# List all containers
docker ps -a

# List images
docker images

# View container logs
docker logs n8n -f --tail 100

# Execute command in container
docker exec -it n8n sh

# Check container resource usage
docker stats

# Prune unused data
docker system prune -a
```

## Code Examples

### Basic n8n docker-compose.yml
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

### Add new service template
```yaml
services:
  new-service:
    image: owner/image:tag
    container_name: service-name
    restart: always
    ports:
      - "INTERNAL_PORT:EXTERNAL_PORT"
    environment:
      - KEY=value
    volumes:
      - ./data:/app/data
    networks:
      - default

networks:
  default:
    name: service-network
```

### Backup n8n data
```bash
cd /opt/n8n
sudo tar czf /backup/n8n-$(date +%Y%m%d).tar.gz data/
```

### Restore n8n data
```bash
cd /opt/n8n
docker compose down
sudo rm -rf data/
sudo tar xzf /backup/n8n-20260101.tar.gz
docker compose up -d
```

## Troubleshooting

### Container won't start
```bash
# Check logs
docker logs n8n --tail 50

# Check for port conflicts
ss -tlnp | grep 5678

# Check compose syntax
docker compose config
```

### "Port already in use"
- Another service using the port
- Previous container not fully stopped
- Check with: `docker ps -a | grep PORT`

### Volume permission issues
```bash
# Fix n8n permissions (runs as node user 1000:1000)
sudo chown -R 1000:1000 /opt/n8n/data
```

### Image pull failures
```bash
# Check internet connectivity
curl -I https://registry-1.docker.io

# Check DNS
docker run --rm alpine ping -c 3 google.com
```

### Out of disk space
```bash
# Clean up
docker system prune -a --volumes

# Check usage
docker system df -v
```

## Best Practices

1. **Always use restart: always** for production services
2. **Pin image versions** in production (avoid `:latest`)
3. **Backup volumes** before major updates
4. **Use environment files** for secrets (`.env`)
5. **Monitor resource usage** with `docker stats`

## Future Services

Planned Docker deployments:
- OpenVPN Server
- Monitoring (Prometheus/Grafana)
- Log aggregation (Loki/Grafana)
- Additional workflow tools

## Resources

- **Docker Docs**: https://docs.docker.com/
- **n8n Docker**: https://docs.n8n.io/hosting/installation/docker/
- **Project**: [PROJECT.md](../../PROJECT.md)
