# PROPOSITO — SBOS Bootstrap Hardening

**Ficha:** `sbos-bootstrap-hardening` - **Servidor:** S00-hostserver - **Version:** 1.0
**Criticidad:** True - **Namespace:** sbos-installer - **Tipo:** Deployment
**Orden de instalacion:** 300

## Que es
CIS hardening: kernel params, auditd, AppArmor, firewalld, no root SSH

## Dependencias
keycloak, kong, prometheus, linkerd

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
