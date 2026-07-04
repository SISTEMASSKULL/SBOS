# Fichas descartadas del catálogo

Fichas retiradas de `servers/` (catálogo activo) por decisión del proyecto.
**No se borran** — se resguardan aquí por si se necesitan de nuevo (regla: no perder trabajo).

## ferretdb — retirada 2026-07-04
- **Qué es:** capa de compatibilidad que emula la API de MongoDB **sobre PostgreSQL**.
- **Motivo:** el proyecto necesita **MongoDB completo** (real) para la personalización de
  Rocket.Chat, que requiere funcionalidades nativas (replica set / oplog / change streams)
  que FerretDB no cubre. MongoDB vive en `servers/S10-commsserver/mongodb/`.
- **Original intacto en:** `BosAgent/src/servers/S06/ferretdb/`.
