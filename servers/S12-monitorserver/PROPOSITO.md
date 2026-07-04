# S12-monitorserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
Observabilidad. Nodo dedicado — nunca compite con lo que monitorea.

## Criticidad
**MÁXIMA**

## Unidad de migración
Al crecer, `S12-monitorserver/` se lleva entero a un VPS dedicado (`tipo=monitorserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: monitorserver LGTM+Z (BASE 8800).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| Prometheus | 9090→8800 | ✅ existe | Métricas + PromQL |
| Alertmanager | 9093→8803 | ✅ existe | Alertas |
| Grafana | 3000→8810 | ✅ existe | Dashboards |
| Loki | 3100→8820 | ⬜ falta | Log aggregation |
| Grafana Alloy | 12345→8824 | ✅ existe | Recolector telemetría (DaemonSet) |
| Tempo | 3200→8830 | ⬜ falta | Trazas distribuidas |
| OTel Collector | 4317/4318→8840/1 | ⬜ falta | Receiver OpenTelemetry |
| Zabbix Server | 10051→8848 | ⬜ falta | Monitoreo de infraestructura |
| Portainer CE | 9000→8864 | ⬜ falta | Gestión de contenedores |
| blockchain | — | ⚠️ revisar | Ficha en BauthAgent/S12; su daemon ratifica/reubica |

## Fichas existentes ratificadas
`Prometheus`, `Alertmanager`, `Grafana`, `Grafana Alloy`, `blockchain`  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
