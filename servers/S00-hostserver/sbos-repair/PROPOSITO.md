# PROPOSITO — SBOS Unified Repair Engine

**Ficha:** `sbos-repair` - **Servidor:** S00-hostserver - **Version:** 1.0
**Criticidad:** True - **Namespace:** sbos-installer - **Tipo:** Deployment
**Orden de instalacion:** 18

## Que es
Multi-layer repair: Ubuntu (dpkg/apt/systemd), K8s (cordon/drain/restart/uncordon), BOS (ficha reconciliation saga)

## Dependencias
sbos-security

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
