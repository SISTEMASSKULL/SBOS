# PROPOSITO — Grafana Alloy

**Ficha:** `alloy` - **Servidor:** S12-monitorserver - **Version:** 1.7.0
**Criticidad:** False - **Namespace:** sbos-monitor - **Tipo:** DaemonSet
**Orden de instalacion:** 215

## Que es
Log collector — journald + archivos → Loki, reemplaza Promtail

## Dependencias
loki

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
