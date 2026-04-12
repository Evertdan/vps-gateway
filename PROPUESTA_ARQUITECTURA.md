# Arquitectura VPS Gateway - Propuesta Técnica

## 🎯 Objetivo

El VPS `vps1.dgetahgo.edu.mx` actúa como **gateway seguro** para exponer proyectos Docker de equipos clientes a Internet mediante:
- VPN (túnel seguro cliente ↔ VPS)
- Subdominio por proyecto
- SSL/TLS por subdominio
- Nginx como proxy reverso a través de la VPN

## 🏗️ Arquitectura Propuesta

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                       │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    vps1.dgetahgo.edu.mx                             │   │
│  │                    195.26.244.180 (VPS)                             │   │
│  │                                                                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │   │
│  │  │   Route 53   │  │   Nginx      │  │     OpenVPN Server       │  │   │
│  │  │   DNS        │──│   Proxy SSL  │──│     192.168.255.1        │  │   │
│  │  │              │  │              │  │                          │  │   │
│  │  └──────────────┘  └──────┬───────┘  └──────────┬───────────────┘  │   │
│  │                           │                     │                  │   │
│  │              proyecto1.vps1.dgetahgo.edu.mx:443│                  │   │
│  │                           │    ════════════════╪════VPN Tunnel════╪═══╪═══╗
│  │                           │                    │                  │   │   ║
│  │              proyecto2.vps1.dgetahgo.edu.mx:443│                  │   │   ║
│  │                           ▼                    ▼                  │   │   ║
│  │                   ┌──────────────────────────────────────────┐   │   │   ║
│  │                   │        VPN TUNNEL (UDP 1194)             │   │   │   ║
│  │                   │        Subnet: 192.168.255.0/24          │   │   │   ║
│  └───────────────────┼──────────────────────────────────────────┘   │   │   ║
│                      │                                               │   │   ║
└──────────────────────╪───────────────────────────────────────────────┘   │   ║
                       │                                                   │   ║
                       ║                                                   │   ║
                       ║  VPN Client: proyecto1 (192.168.255.10)          │   ║
                       ╚════════════════════════════════════════════╗      │   ║
                                                                    ║      │   ║
┌───────────────────────────────────────────────────────────────────╫──────┘   ║
│                         CLIENTE (Local)                           ║          ║
│                                                                   ║          ║
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────────┐  ║          ║
│  │ OpenVPN Client  ║════║ Docker Compose  ║════║ Proyecto Web ║══╝          ║
│  │ 192.168.255.10  ║    │ Puerto: 3000    ║    │ localhost    ║             ║
│  └─────────────────┘    └─────────────────┘    └──────────────┘             ║
│                                                                             ║
│  Flujo: proyecto1.vps1.dgetahgo.edu.mx → Nginx SSL → VPN → Docker:3000     ║
└─────────────────────────────────────────────────────────────────────────────╝
```

## 📋 Componentes

### 1. OpenVPN con IPs Estáticas (CCD)

**Configuración CCD (Client Config Directory):**
- Ruta: `/opt/openvpn/data/ccd/`
- Asigna IP estática a cada cliente
- Formato: archivo con nombre del cliente, contenido: `ifconfig-push IP NETMASK`

**Asignación de IPs:**
| Rango | Uso |
|-------|-----|
| 192.168.255.1 | Servidor VPN |
| 192.168.255.2-9 | Reservado (servicios VPS) |
| 192.168.255.10-100 | Clientes de proyectos (IPs estáticas) |
| 192.168.255.101-254 | Clientes dinámicos |

### 2. Sistema de Mapeo Proyecto ↔ IP

**Registro de proyectos:**
```json
{
  "proyecto1": {
    "client_name": "cliente-juan-laptop",
    "vpn_ip": "192.168.255.10",
    "domain": "proyecto1.vps1.dgetahgo.edu.mx",
    "local_port": 3000,
    "ssl": true,
    "created_at": "2026-04-12T20:30:00Z"
  }
}
```

### 3. Nginx Proxy Dinámico

**Configuración por proyecto:**
```nginx
server {
    listen 443 ssl http2;
    server_name proyecto1.vps1.dgetahgo.edu.mx;
    
    ssl_certificate /etc/letsencrypt/live/proyecto1.vps1.dgetahgo.edu.mx/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/proyecto1.vps1.dgetahgo.edu.mx/privkey.pem;
    
    location / {
        proxy_pass http://192.168.255.10:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts para conexión VPN
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

server {
    listen 80;
    server_name proyecto1.vps1.dgetahgo.edu.mx;
    return 301 https://$server_name$request_uri;
}
```

### 4. Flujo de Automatización

```
┌────────────────────────────────────────────────────────────────────────────┐
│                      FLUJO DE CREACIÓN DE PROYECTO                         │
└────────────────────────────────────────────────────────────────────────────┘

1. Verificar/Crear Cliente VPN
   ├─ ¿Existe cliente para este proyecto?
   │  ├─ SÍ → Obtener IP estática asignada
   │  └─ NO → Generar cliente VPN
   │         ├─ Crear certificado
   │         ├─ Asignar IP estática (CCD)
   │         ├─ Generar archivo .ovpn
   │         └─ Copiar a cliente (SCP/Email)
   │
2. Crear DNS (Route 53)
   └─ proyecto.vps1.dgetahgo.edu.mx → A → 195.26.244.180
   │
3. Emitir SSL (acme-dns + certbot)
   ├─ Crear CNAME _acme-challenge → auth.dgetahgo.edu.mx
   ├─ Ejecutar certbot
   └─ Obtener certificado en /etc/letsencrypt/live/
   │
4. Configurar Nginx
   └─ Crear server block proxy a VPN_IP:LOCAL_PORT
   │
5. Registrar en proyecto
   └─ Guardar en /opt/projects/registry.json
   │
6. Notificar cliente
   └─ Proyecto listo en: https://proyecto.vps1.dgetahgo.edu.mx
```

## 🔧 Implementación Técnica

### Cambios Requeridos en VPS Actual

#### 1. OpenVPN CCD (IPs Estáticas)

**Modificar server.conf:**
```bash
# Añadir a /opt/openvpn/data/openvpn.conf
client-config-dir /etc/openvpn/ccd
ifconfig-pool-persist /etc/openvpn/ipp.txt 0
```

**Estructura CCD:**
```
/opt/openvpn/data/ccd/
├── cliente-juan-laptop    # Contenido: ifconfig-push 192.168.255.10 255.255.255.0
├── cliente-maria-desktop  # Contenido: ifconfig-push 192.168.255.11 255.255.255.0
└── cliente-pedro-mac      # Contenido: ifconfig-push 192.168.255.12 255.255.255.0
```

#### 2. Nginx con Proxy a VPN

**No requiere cambios mayores**, solo crear server blocks dinámicos que apunten a IPs VPN.

#### 3. Registro de Proyectos

**Crear estructura:**
```
/opt/projects/
├── registry.json          # Base de datos de proyectos
├── nginx-conf.d/          # Configs nginx por proyecto
└── scripts/
    ├── create-project.sh
    ├── delete-project.sh
    └── list-projects.sh
```

### Scripts IaC a Desarrollar

| Script | Propósito | Ubicación |
|--------|-----------|-----------|
| `create-project.sh` | Pipeline completo: VPN → DNS → SSL → Nginx | `/opt/projects/scripts/` |
| `delete-project.sh` | Eliminar proyecto y limpiar | `/opt/projects/scripts/` |
| `list-projects.sh` | Listar proyectos activos | `/opt/projects/scripts/` |
| `verify-vpn-client.sh` | Verificar estado cliente VPN | `/opt/projects/scripts/` |
| `terraform-dns.tf` | DNS records via Terraform | `/terraform/projects.tf` |

### CI/CD Pipeline GitHub Actions

```yaml
name: Create Project Gateway

on:
  workflow_dispatch:
    inputs:
      project_name:
        description: 'Nombre del proyecto'
        required: true
      client_name:
        description: 'Nombre del cliente/equipo'
        required: true
      local_port:
        description: 'Puerto local Docker'
        required: true
        default: '3000'
      client_exists:
        description: '¿Cliente VPN ya existe?'
        type: boolean
        default: false

jobs:
  create-gateway:
    runs-on: ubuntu-latest
    steps:
      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.8.0
        with:
          ssh-private-key: ${{ secrets.VPS_SSH_KEY }}
      
      - name: Create Project Gateway
        run: |
          ssh usuario@vps1.dgetahgo.edu.mx \
            "/opt/projects/scripts/create-project.sh \
              --project=${{ github.event.inputs.project_name }} \
              --client=${{ github.event.inputs.client_name }} \
              --port=${{ github.event.inputs.local_port }} \
              --client-exists=${{ github.event.inputs.client_exists }}"
      
      - name: Download VPN Config
        if: ${{ github.event.inputs.client_exists == 'false' }}
        run: |
          scp usuario@vps1.dgetahgo.edu.mx:/home/usuario/vpn-clients/${{ github.event.inputs.client_name }}.ovpn .
      
      - name: Upload VPN Config
        if: ${{ github.event.inputs.client_exists == 'false' }}
        uses: actions/upload-artifact@v4
        with:
          name: vpn-config-${{ github.event.inputs.client_name }}
          path: "*.ovpn"
```

## 📊 Comparativa: Antes vs Después

| Aspecto | Estado Actual | Estado Propuesto |
|---------|---------------|------------------|
| **VPN** | Clientes dinámicos | IPs estáticas por proyecto |
| **DNS** | Manual por dominio | Automático por proyecto |
| **SSL** | Manual con scripts | Automático vía CI/CD |
| **Proxy** | Solo localhost | VPN + localhost |
| **Nuevo Proyecto** | 15-20 min manual | 2-3 min automatizado |
| **Seguridad** | HTTP | HTTPS siempre |

## 🚀 Plan de Implementación

### Fase 1: Configuración Base (Hora 1)
- [ ] Configurar OpenVPN CCD para IPs estáticas
- [ ] Crear estructura /opt/projects/
- [ ] Instalar dependencias adicionales

### Fase 2: Scripts Core (Horas 2-3)
- [ ] Desarrollar create-project.sh
- [ ] Desarrollar delete-project.sh
- [ ] Desarrollar verify-vpn-client.sh

### Fase 3: Terraform (Hora 4)
- [ ] Crear módulo DNS para proyectos
- [ ] Integrar con scripts bash

### Fase 4: CI/CD (Hora 5)
- [ ] Crear GitHub Actions workflows
- [ ] Configurar secrets
- [ ] Testing

### Fase 5: Documentación (Hora 6)
- [ ] Actualizar skills
- [ ] Crear guía de usuario
- [ ] Video/demo

**Tiempo Total Estimado:** 6 horas de desarrollo + 2 horas de testing

## 💡 Mejoras Futuras Sugeridas

1. **Dashboard Web**: Panel para ver proyectos activos y sus estados
2. **Auto-Scaling**: Múltiples clientes por proyecto (balanceo)
3. **Monitoring**: Métricas de uso por proyecto (Prometheus/Grafana)
4. **Rate Limiting**: Protección contra abuso por proyecto
5. **Webhooks**: Notificaciones a clientes cuando gateway está listo
6. **API REST**: Endpoints para integración con otros sistemas

## 📝 Conclusión

Esta arquitectura convierte el VPS en un **PaaS (Platform as a Service)** para equipos de desarrollo, permitiendo:
- Exponer proyectos locales a Internet en minutos
- URLs personalizadas con SSL
- Seguridad mediante VPN
- Totalmente automatizado vía CI/CD

**Beneficio clave:** Los desarrolladores solo necesitan:
1. Conectar VPN (archivo .ovpn)
2. Ejecutar Docker local
3. Solicitar proyecto vía CI/CD
4. Obtener URL pública con SSL
