# BibliotecaSBOS
**Proyecto:** SBOS — Sovereign Business Operating System
**Árbol:** 26a83fa0-d71c-476b-b52c-4cb14bdd2929
**Nodo SKDATA:** Biblioteca-SBOS
**Perfil:** fundacional
**Materializado:** 2026-05-12
**DDL generado:** 2026-05-12 — Sesión S-10

## Entregables

| Archivo | Contenido | Líneas |
|---|---|---|
| `src/000_extensions.sql` | 6 extensiones PostgreSQL requeridas | 9 |
| `src/001_bkernel_db.sql` | bkernel_db — 8 tablas (2 particionadas) | 219 |
| `src/002_biedata_db.sql` | biedata_db — 3 tablas | 101 |
| `src/003_bauth_db.sql` | bauth_db — 4 tablas | 143 |
| `src/004_bcompass_db.sql` | bcompass_db — 3 tablas | 114 |
| `src/005_bos_db.sql` | bos_db — 2 tablas | 94 |
| `src/100_replication_slots.sql` | 3 WAL slots (bkernel, biedata, bcompass) | 28 |
| `src/seed_identity.yml` | Seed data: realms, clients, roles, usuarios | 97 |
| `src/fixtures_test_data.sql` | Datos sintéticos para CI testing | 132 |
| `src/deploy_all.sh` | Script de despliegue en orden de dependencias | 62 |

**Total:** 20 tablas en 5 bases de datos · 62 índices · 47 CHECKs · 6 UNIQUEs · 41 comentarios

## Gate de validación

- [x] Todas las FK resueltas — solo 2 FK intra-schema (bcompass)
- [x] Índices correctos — 62 índices B-tree + BRIN
- [x] Sin cruces entre schemas — cada schema independiente
- [x] Particionado para tablas de alto volumen (sync_log, audit_events)
- [x] Extensiones requeridas declaradas
- [x] WAL slots configurados con idempotencia
- [x] Seed data de identidad (4 realms, 1 admin, 1 operador)
- [x] Fixtures de prueba para CI

## ISO 27001 Controles Cubiertos

- **A.8.15** — Registro de actividades (audit_events, sync_log, access_log)
- **A.8.16** — Monitoreo (health_snapshot, anomaly_events, circuit_state)
- **A.5.15** — Control de acceso (bauth_access_log, delegations)
- **A.5.18** — Derechos de acceso (bauth_sync_log, drift_history)
- **A.8.12** — Prevención de fuga de datos (biedata_audit_log, circuit_state)
- **A.8.5** — Autenticación segura (bauth_access_log con LoA y 3 dominios)
