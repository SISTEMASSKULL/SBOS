# S09-searchserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
Búsqueda empresarial e indexación masiva + mensajería async.

## Criticidad
**ALTA**

## Unidad de migración
Al crecer, `S09-searchserver/` se lleva entero a un VPS dedicado (`tipo=searchserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: searchengine + messagequeue (BASE 8600).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| Elasticsearch HTTP | 9200→8600 | ⬜ falta | Indexación masiva + backend SIEM |
| Elasticsearch Cluster | 9300→8607 | ⬜ falta | Comunicación entre nodos ES |
| Typesense | 8108→8610 | ⬜ falta | Full-text alternativo (bSearch) |
| RabbitMQ | 5672→8620 | ⬜ falta | Mensajería async |

## Fichas existentes ratificadas
_(ninguna todavía)_  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
