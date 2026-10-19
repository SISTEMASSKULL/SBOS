# PROPOSITO — SBOS Unified Package Manager

**Ficha:** `sbos-package-manager` - **Servidor:** S00-hostserver - **Version:** 1.0
**Criticidad:** True - **Namespace:** sbos-installer - **Tipo:** Deployment
**Orden de instalacion:** 19

## Que es
Multi-backend package manager: apt (system), pip (python), helm (kubernetes). Auto-generates fichas on install.

## Dependencias
sbos-repair

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
