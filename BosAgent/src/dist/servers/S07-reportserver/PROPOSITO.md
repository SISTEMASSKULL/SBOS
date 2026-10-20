# S07-reportserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
Reportes fiscales Bolivia SIN, BI, ETL y catálogo de datos.

## Criticidad
**ALTA**

## Unidad de migración
Al crecer, `S07-reportserver/` se lleva entero a un VPS dedicado (`tipo=reportserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: reportserver + biserver + orchestrator + datacatalog (BASE 8500).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| Superset | 8088→8500 | ⬜ falta | Dashboards BI |
| Airflow | 8080→8510 | ⬜ falta | ETL / orquestación de flujos |
| OpenMetadata | 8585→8520 | ⬜ falta | Catálogo de datos / gobierno |
| JasperReports | 8080→8530 | ⬜ falta | Reportes fiscales SIN Bolivia |

## Fichas existentes ratificadas
_(ninguna todavía)_  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
