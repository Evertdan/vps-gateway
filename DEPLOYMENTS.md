# 📊 Deployment History

## Overview

Este archivo registra automáticamente cada deployment realizado a través de GitHub Actions.

## Last Deployed

Last deployed: Sun Apr 13 00:25:00 UTC 2026

## Deployment Log

| Fecha | Versión | Commit | Estado |
|-------|---------|--------|--------|
| 2026-04-13 | v1.0.0 | Initial | ✅ Success |

## Deployment Process

Los deployments se realizan automáticamente cuando se crea un tag con formato `v*`, por ejemplo:

```bash
git tag -a v1.1.0 -m "Release version 1.1.0"
git push origin v1.1.0
```

Esto activará el workflow `cd-release.yml` que:
1. Creará un release en GitHub
2. Generará un changelog automático
3. Desplegará los scripts al VPS
4. Actualizará este archivo

## Rollback

En caso de necesitar rollback, usar el tag anterior:

```bash
git checkout v1.0.0
```