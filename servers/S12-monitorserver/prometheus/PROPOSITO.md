# PROPOSITO — Prometheus

**Ficha:** `prometheus` - **Servidor:** S12-monitorserver - **Version:** 3.5.0
**Criticidad:** True - **Namespace:** sbos-monitor - **Tipo:** StatefulSet
**Orden de instalacion:** 200

## Que es
Métricas y alertas — retención 90d, scrape 30s, SLO recording rules

## Dependencias
network-validator

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
