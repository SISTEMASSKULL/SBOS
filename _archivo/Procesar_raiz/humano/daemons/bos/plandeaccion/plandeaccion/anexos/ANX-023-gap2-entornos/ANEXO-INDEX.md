# ANX-023 — Índice del Anexo
**Directorio:** ANX-023-gap2-entornos
**Tipo:** B — Archivo subido en la conversación
**Átomos relacionados:** F0.6 (GAP 2 cerrado)
**Fecha:** 07 de Junio, 2026

## Archivos
- `ENVIRONMENTS.md` — Matriz completa de entornos DEV/STAGING/PROD
- `staging-runner-setup.sh` — Script de instalación del self-hosted runner en VPS staging

## Resumen de contenido
Infraestructura real del proyecto: VPS DEV (144.91.76.130, usuario skull) y
VPS STAGING (13.140.128.230, usuario root). GitHub Actions corre build+race en
ubuntu-latest y despliega a staging via self-hosted runner con labels
[self-hosted, linux, staging]. Feature flags por entorno. Política de promoción
a prod: un sprint completo en staging sin incidentes. Deuda técnica documentada:
staging corre como root — solución incluida en el archivo.

## Decisión de diseño importante
Windows laptop → SSH → VPS DEV → git push → GitHub Actions → VPS STAGING.
El desarrollador nunca trabaja directamente en staging.
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
