# BOS-bKernel-007 — SKILL ESPECÍFICO DEL PROGRAMADOR bKernel

## 0. Metadatos
| **Documento** | BOS-bKernel-007 · **Versión** 1.0 · **Estado** VIGENTE—REDACTADO · **Fecha** 2026-06-10 |
|---|---|
| **Serie** | BOS-bKernel — se carga JUNTO a → ECO-007 (maestro, manda) |

## SKILL — específico bKernel (añadir al maestro)

### Naturaleza del binario
Motor genérico de CDC+decisión. Cero servidor de entrada (D2): los únicos sockets
permitidos son 9460 (métricas) y 9461 (health), HTTP de SOLO respuesta. Inputs: WAL
pgoutput / Binlog ROW / Change Streams / SQL Server CDC + SIGTERM + SIGHUP.

### Estructura y módulos (SSOT: bK-050; del corpus A7)
`mod cdc` (listeners por motor, canal por fuente con prioridad, checkpoints por motor:
`LSN:{hex}` · `BinlogPos:{archivo}:{pos}:{gtid}` · `SQLCDC:{lsn_hex}` · `ResumeToken:{b64}`)
· `mod enricher` (AGE) · `mod routing` (CESQL) · `mod engine`/`mod catalog`
(task_catalog.sh como plugin: env vars, exit codes, timeout — contrato en bK-090) ·
`mod writers` REDEFINIDO (D1): construye intenciones y publica Outbox→streams; escribe
SOLO estado operacional · `mod ddl_guardian` · `mod lineage` · `mod coordinator`/`mod state`.

### Reglas de código específicas
- Estado SOLO en `sbos_kernel_db.bkernel` (C-04). Migraciones versionadas.
- Loop prevention SIEMPRE doble capa: `pg_replication_origin`/`_origen` + verificación
  inbox (F-06). Test de eco obligatorio.
- Reglas/fichas hot-reload por SIGHUP sin perder eventos (canal pausado, no drenado).
- Backpressure: bounded channels por fuente; jamás canal compartido (Fix-01).
- SLOs canónicos C-02: `slo_deteccion_wal` p999<2ms · `slo_pipeline_interno` p50<5ms
  p99<20ms · `slo_evento_a_escritura` p99<50ms p999<200ms · throughput >50K ev/s —
  cada uno con su par de timestamps definido; bench por tarea que los toque.
- Métricas en :9460 con catálogo en bK-110; lag por listener obligatorio.
- DDL Guardian: triggers solo de DDL en schema `bkernel_audit`; jamás triggers de datos
  en BDs de negocio (excepción documentada de cero invasión, Master §02.2).

### Fixtures de prueba (D10)
BDs de prueba declaradas por fichas de ejemplo (`servers/test/<app_ejemplo>/`); nombres
de apps reales solo como ejemplo ilustrativo.

## Criterios de completitud
- [x] Específicos: naturaleza D2, módulos, checkpoints por motor, anti-loop, SLOs, fixtures. · [ ] Validación.

---
*bK-007 v1.0 · maestro: → ECO-007*
