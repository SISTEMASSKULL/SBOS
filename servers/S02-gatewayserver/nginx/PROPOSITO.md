# PROPOSITO — NGINX Reverse Proxy + TLS Termination

**Ficha:** `nginx` - **Servidor:** S02-gatewayserver - **Version:** 1.26
**Criticidad:** True - **Namespace:** sbos-gateway - **Tipo:** Deployment
**Orden de instalacion:** 50

## Que es
Reverse proxy, TLS termination, HTTP/2, wildcard cert via certbot, virtual hosts parametrizados

## Dependencias
network-validator

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
