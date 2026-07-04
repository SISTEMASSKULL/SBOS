# ADR-024 — PostgreSQL como Única Base de Datos Relacional

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §18 Regla 2 + §7.1 del Master v2.1  
**Corrección:** El Master §7.1 cita erróneamente "ADR-005" para esta regla. ADR-005 es "Abstracción bosctl". Esta decisión queda formalizada correctamente en ADR-024.  
**Relacionado:** ADR-017 (versiones), DAEMON-BKERNEL, §7 Data Plane

---

## Contexto y problema

La razón de ser de PostgreSQL como única BD no es solo de preferencia técnica: el bus de eventos del SBOS **es** el Write-Ahead Log (WAL) de PostgreSQL. bKernel escucha el WAL vía `pgoutput` para propagar cambios a través de Redis Streams. Si hubiera múltiples motores de BD (MySQL nativo, SQLite, etc.), el bus de eventos se fragmentaría y el CDC (Change Data Capture) de bKernel no podría funcionar de forma unificada.

## La Decisión

**PostgreSQL 18.4 con Patroni HA (ADR-017) es la única BD relacional del SBOS.**

```
PERMITIDO:
  ✅ PostgreSQL 18.4 (versión canónica)
  ✅ Patroni HA (3 nodos, failover automático < 30s)
  ✅ pgvector, pg_trgm, GIN, tsvector (extensiones nativas)
  ✅ MySQL como excepción EXPLÍCITA con SymmetricDS (solo para sincronización con ERP legacy)
  ✅ 9 BDs predefinidas por tenant (separación lógica, no física)

VETADO:
  ❌ SQLite en producción (cualquier daemon)
  ❌ MariaDB / MySQL nativo sin autorización explícita
  ❌ CockroachDB, TiDB u otros compatibles-PG que quiebren el CDC
  ❌ Cualquier BD sin soporte nativo de WAL replication slots
```

## Las 9 Bases de Datos Predefinidas por Tenant

| BD | Propietario | Propósito |
|----|-------------|-----------|
| `keycloak_db` | Keycloak | Realms, usuarios, sesiones KC |
| `bkernel_db` | bKernel | CDC events, context_sessions |
| `bauth_db` | bAuth | RolTemplates, BitMasks, audit |
| `tryton_db` | Tryton | ERP multi-company |
| `minio_meta` | MinIO | Metadatos de objetos |
| `bsearch_catalog` | bSearch | Índices FTS y catálogos |
| `bcompass_db` | bCompass | Estado de agentes IA |
| `bnotify_db` | bNotify | Plantillas, canales, estado |
| `audit_db` | bos | audit_events central |

## Regla de Aislamiento Absoluta

```sql
-- ❌ NUNCA — query sin tenant_id
SELECT * FROM facturas;

-- ✅ SIEMPRE — tenant_id en el WHERE
SELECT * FROM facturas WHERE tenant_id = current_setting('app.tenant_id');
```

Ninguna query puede existir sin `tenant_id` en el `WHERE`. Validado en CI mediante linter de queries (pganalyze / sqlfluff).

## Consecuencias

**Positivas:**
- bKernel funciona con un solo protocolo CDC (pgoutput) en toda la plataforma
- Las 9 BDs predefinidas dan estructura predecible al tenant lifecycle
- pgvector disponible desde el primer día para búsqueda semántica futura

**Negativas/Riesgos:**
- PostgreSQL es punto único de fallo si Patroni falla
- Mitigación: 3 nodos Patroni + pgBackRest + monitoreo en bos + ficha `postgresql` con 18 estados

## Normas relacionadas

- SBOS-023-DAEMON-BKERNEL (CDC/WAL)
- SBOS-043-DATABASE-CATALOG (catálogo completo de BDs)
- ISO/IEC 27001:2022 A.8.3 (separación de entornos)
- ADR-026 (biedata único gateway — no queries directas desde exterior)
