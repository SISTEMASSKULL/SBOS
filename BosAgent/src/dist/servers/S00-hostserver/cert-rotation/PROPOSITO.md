# PROPOSITO — Certificate Rotation

**Ficha:** `cert-rotation` - **Servidor:** S00-hostserver - **Version:** 1.0
**Criticidad:** True - **Namespace:** sbos-installer - **Tipo:** Deployment
**Orden de instalacion:** 320

## Que es
TLS cert renewal every 90 days via Let's Encrypt + Vault

## Dependencias
vault, certbot

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
