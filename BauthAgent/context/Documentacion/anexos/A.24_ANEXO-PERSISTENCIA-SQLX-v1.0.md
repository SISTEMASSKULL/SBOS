# Anexo A.24 — La persistencia: por qué sqlx, y el estado de migraciones y seeds
## Documento de respaldo de sustentación (tipo C+D)

**Versión:** 1.0.0 · **Fecha:** 2026-07-11 · **Respalda a:** MANUAL-DDL-SEEDS (1.05) · A.15 (stack)
**Verificación de código:** `Cargo.toml` (sqlx 0.8) + `DDLs/migrations/` (12) + `DDLs/seeds/` (101) — leída 2026-07-11
**Normas:** PostgreSQL 18 · idempotencia (SBOS-ddl)

## 1. La decisión justificada — sqlx (no diesel/sea-orm)
`sqlx 0.8` con `runtime-tokio` + `tls-rustls` + `postgres`. Por qué sqlx y no un ORM:
| Criterio | sqlx (elegido) | diesel / sea-orm |
|---|---|---|
| SQL | **SQL crudo verificado en compilación** — el control total que un IdP necesita | ORM abstrae el SQL |
| Async | nativo tokio | diesel sync (sea-orm async) |
| PG18 features | acceso directo (uuidv7, WITHOUT OVERLAPS del motor 1.13) | limitado por la capa ORM |
| TLS | rustls (sin OpenSSL — coherente con la independencia A.15) | variable |

La decisión es coherente con la soberanía: SQL explícito y auditable, sin una capa que oculte
lo que va a la BD (crítico para un sistema de seguridad).

## 2. El estado real — 12 migraciones + 101 seeds
Sustancial: 12 migraciones (`bauth_10..44`) + **101 seeds** (`bauth_01..62`, `bglobal_*`,
`bcalendar_*`). Convención `bauth_NN__objeto`, idempotentes (SBOS-ddl). Es un esquema maduro.

## 3. Lo que FALTA — específico
| # | Brecha | Prioridad |
|---|---|:---:|
| P1 | **`bauth_44` (WORM) sin aplicar en VPS** (A.27-AU2) | P1 |
| P2 | Seeds de átomos D2–D12 y D13 pendientes (A.17-C3, A.05) | P1 |
| P3 | Migración de `idn_identity_attribute` ausente (A.31-AT1) | P1 |
| P4 | Verificar que toda migración es reversible/diagnosticable | P3 |

**Industria:** [sqlx](https://github.com/launchbadge/sqlx) · [PostgreSQL 18](https://www.postgresql.org/docs/18/)

| Ver. | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-11 | sqlx justificado (SQL crudo verificado en compilación = soberanía, vs ORM); estado real 12 migraciones + 101 seeds (maduro); brechas P1 bauth_44 sin aplicar, P2 átomos sin sembrar, P3 idn_identity_attribute ausente. |
