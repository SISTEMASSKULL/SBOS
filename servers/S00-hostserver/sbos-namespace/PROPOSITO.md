# PROPOSITO — sbos-namespace

**Ficha:** `sbos-namespace` - **Servidor:** S00-hostserver - **Version:** 1.0.0
**Criticidad:** True - **Namespace:** - - **Tipo:** bash
**Orden de instalacion:** 5

## Que es
Namespace K8s + NetworkPolicy default-deny por tenant. Recibe TENANT_ID como variable de entorno.

## Dependencias
sbos-bootstrap-k8s

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
