# S01-dataserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
Motor de persistencia unificado. Todo el stack lee y escribe aquí.

## Criticidad
**MÁXIMA**

## Unidad de migración
Al crecer, `S01-dataserver/` se lleva entero a un VPS dedicado (`tipo=dataserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: commonserver + dbsyncserver (BASE 8100).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| PostgreSQL | 5432→8100 | ✅ existe | Motor principal (90%+ del stack) |
| Patroni REST | 8008→8103 | ⬜ falta | Health checks HA / routing a primario |
| PgBouncer | 5432→8110 | ⬜ falta | Connection pooling |
| Redis | 6379→8120 | ✅ existe | Caché, sesiones, colas |
| Redis Sentinel | 26379→8127 | ⬜ falta | HA Redis |
| MinIO S3 | 9000→8130 | ✅ existe | Object storage |
| MinIO Console | 9001→8131 | ✅ existe | Consola MinIO |
| MySQL | 3306→8140 | ⬜ falta | Apps legacy (OrangeHRM, FreePBX) |
| SymmetricDS | 31415→8147 | ⬜ falta | Sync PG↔MySQL (CDC) |
| MongoDB | 27017→8148 | ⬜ falta | Backend Rocket.Chat |
| PgAdmin 4 | 5050→8149 | ⬜ falta | Administración PostgreSQL |

## Daemons soberanos declarados

| Daemon | Ficha | Binario | Estado |
|--------|-------|---------|:------:|
| bi18n | `bi18n/` | `bi18nd` (Rust MUSL) — Orquestador de i18n, servidor canónico de traducciones | 🆕 declarada |

## Fichas existentes ratificadas
`PostgreSQL`, `Redis`, `MinIO S3`, `MinIO Console`  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
