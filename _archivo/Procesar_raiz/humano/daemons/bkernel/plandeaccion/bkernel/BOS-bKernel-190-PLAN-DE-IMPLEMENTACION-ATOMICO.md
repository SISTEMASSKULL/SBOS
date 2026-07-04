# BOS-bKernel-190 — PLAN DE IMPLEMENTACIÓN ATÓMICO (nivel micro)

## 0. Metadatos
| Campo | Valor |
|---|---|
| **Documento** | BOS-bKernel-190-PLAN-DE-IMPLEMENTACION-ATOMICO · **Versión** 1.0 · **Estado** VIGENTE—REDACTADO, vivo (estado de tareas en bK-004) · **Fecha** 2026-06-10 |
| **Fase asociada** | G0–G5 (tablero y gates: → ECO-008, manda en sincronización) |
| **Fuentes que absorbe** | `05-BKERNEL-PROPUESTA` §Plan (Fases 0–5, tareas y semanas — adaptado: la Fase 0 documental de A5 quedó ejecutada/superada por la Fase 0 del proyecto documental; puertos 9460/9461 por C-01/D5) |
| **Normas** | ISO/IEC/IEEE 12207:2017 §6.3.1; ISO/IEC/IEEE 15289:2019 cl.10 (plan) |
| **Audiencia/Custodio** | agente programador / arquitecto (alcance) |

Regla de atomicidad y formato de tarea: → ECO-008 §1. Estimaciones (h/d) = referencia A5;
el avance se mide SOLO por criterio cumplido. Estados y evidencia: en bK-004.

---

## G0.E2 — Esqueleto del binario y CI

| ID | Tarea atómica | Entregable | Criterio MEDIBLE | Dep. | SSOT |
|---|---|---|---|---|---|
| bK-G0.E2.T1 | Workspace Cargo + estructura de módulos vacíos | repo `bkernel/` con `Cargo.toml` (edition 2024, perfil release LTO) y `src/` con mods stub | `cargo build` OK; `cargo clippy -- -D warnings` limpio | — | bK-050 |
| bK-G0.E2.T2 | Build MUSL estático + budget | target `x86_64-unknown-linux-musl` | `file` reporta "statically linked"; tamaño < 15 MB (gate CI) | T1 | C-08 |
| bK-G0.E2.T3 | Config TOML + carga tipada | `bkernel.toml` ejemplo + structs serde + validación al boot | boot con config inválida falla con error explícito; test unit | T1 | bK-050 |
| bK-G0.E2.T4 | Señales SIGTERM/SIGHUP | handler tokio: TERM=drain+exit limpio; HUP=reload stub | test de integración: HUP no mata el proceso; TERM sale ≤ 5s | T1 | bK-010(D2) |
| bK-G0.E2.T5 | systemd unit + sd_notify | `bkernel.service` Type=notify, watchdog | `systemctl start/stop/status` OK en sandbox; watchdog dispara restart al colgar | T2,T4 | bK-180 |
| bK-G0.E2.T6 | Métricas/health readonly | exporter :9460 `/metrics`, :9461 `/health` (GET only) | curl OK; cualquier método ≠GET → 405; escaneo: NINGÚN otro puerto (D2) | T1 | bK-110, D5 |
| bK-G0.E2.T7 | CI pipeline | build musl + fmt + clippy + test + budget + escaneo de puertos | pipeline verde en commit vacío de feature | T2,T6 | ECO-007 |

## G0.E4(bK) — Base operacional

| ID | Tarea | Entregable | Criterio | Dep. | SSOT |
|---|---|---|---|---|---|
| bK-G0.E4.T1 | Migraciones núcleo `sbos_kernel_db.bkernel` | source_registry, checkpoints, dlq, schema_change_log (núcleo) | up/down limpios en PG17; idempotentes (re-up no-op) | E2.T1 | bK-130, D2(C-04) |
| bK-G0.E4.T2 | Pool PG + Vault Agent | conexión vía credencial de Vault, rotación | rotar secreto en caliente sin caída (test) | T1 | bK-160(F-09) |

## G1.E1 — mod cdc (PostgreSQL primero)

| ID | Tarea | Entregable | Criterio | Dep. | SSOT |
|---|---|---|---|---|---|
| bK-G1.E1.T1 | Cliente replicación pgoutput | conexión a slot, decodificación begin/commit/insert/update/delete | suite captura los 5 tipos contra PG17 fixture | G0 gate | bK-060, A2 |
| bK-G1.E1.T2 | Canal por fuente (Fix-01) | `HashMap<SourceId, bounded_channel>` con prioridad | bajo carga concurrente de 2 fuentes, lag independiente (bench) | T1 | bK-050 |
| bK-G1.E1.T3 | Checkpoint LSN persistente | guarda/lee `LSN:{hex}`; avance del slot | kill -9 en mitad de lote → reanuda sin pérdida NI duplicado (test 20 iteraciones) | T1,G0.E4 | bK-060 |
| bK-G1.E1.T4 | source.yml v1 parser + carga de ficha | lee `servers/<srv>/<app>/source.yml`, registra fuente | ficha de ejemplo carga; inválida → rechazo con campo exacto | T1 | bK-140 |
| bK-G1.E1.T5 | Métricas CDC | eventos/s, lag por listener, slot bytes retenidos | visibles en :9460; alerta de retención simulable | T2 | bK-110 |

## G1.E2 — Outbox → streams de intención

| ID | Tarea | Entregable | Criterio | Dep. | SSOT |
|---|---|---|---|---|---|
| bK-G1.E2.T1 | Struct de intención + validador | tipos serde EXACTOS del contrato | golden-files del contrato validan 100% | ECO-020 VALIDADO | ECO-020, ECO-010 §10 |
| bK-G1.E2.T2 | Outbox transaccional | tabla outbox + publicación `bkernel:stream:biedata.*` con XADD | evento en BD sin publicar sobrevive a crash y se publica al reinicio (test) | T1,G1.E1.T3 | ECO-020 |
| bK-G1.E2.T3 | Reintentos/backoff a Redis | política exponencial + DLQ | Redis caído 60s → cero pérdidas; métricas de reintento | T2 | bK-170 |

## G1.E5 — Anti-loop (skipback)

| ID | Tarea | Entregable | Criterio | Dep. | SSOT |
|---|---|---|---|---|---|
| bK-G1.E5.T1 | Filtro por origin | descarta eventos `origin='biedata'` hacia biedata | test de eco: escritura de biedata NO produce intención a biedata; SÍ propaga a otros destinos | G1.E1 | ECO-020, F-06 |
| bK-G1.E5.T2 | Segunda capa (verificación inbox/event_id) | consulta dedup según contrato | inyección de duplicado artificial → 1 sola propagación | T1 | ECO-020 |

## G2 — Pipeline decisor (resumen de tareas; mismo formato)

| ID | Tarea | Criterio clave | SSOT |
|---|---|---|---|
| bK-G2.E1.T1–T3 | DDL destination_registry + CRUD `bosctl bkernel dest add/list/pause/resume` + migración de reglas | CRUD operativo; regla pausada NO enruta | bK-080, A5 |
| bK-G2.E2.T1 | Parser CESQL (subset: comparaciones, AND/OR/NOT, field access) | suite de gramática (casos válidos+inválidos) 100% | bK-080 |
| bK-G2.E2.T2 | Integración routing→engine pre-ejecución | evento enruta a ≥2 destinos según contenido (H2 parcial) | bK-080/090 |
| bK-G2.E2.T3 | Compatibilidad task_catalog.sh | contrato de invocación (env, exit codes, timeout) + tests BATS | bK-090 (V-05) |
| bK-G2.E5.T1 | 2 fichas de ejemplo completas (4 archivos) | cargan por SIGHUP sin reinicio; BATS happy/error/idempotencia | bK-140 (V-03) |

## G3 — Contexto y grafo

| ID | Tarea | Criterio clave | SSOT |
|---|---|---|---|
| bK-G3.E1.T1–T2 | AGE en sbos_kernel_db + DDL grafo + migración crossref | consultas jerarquía con aislamiento por tenant (test multi-tenant) | bK-070, bK-130 |
| bK-G3.E2.T1–T2 | mod enricher + source.yml v2 (context_enrichment) | evento sin tenant_id resuelto < 2ms p99 (bench 10k) | bK-070 |

## G4 — Protección y linaje

| ID | Tarea | Criterio clave | SSOT |
|---|---|---|---|
| bK-G4.E1.T1–T4 | Event triggers + fingerprint + clasificador 5 niveles + response engine + maintenance_windows | BREAKING pausa fichas <100ms; SAFE no interrumpe; SECURITY detiene+SIEM | bK-100, B3 |
| bK-G4.E2.T1–T2 | RunEvent OpenLineage + emisión fire-and-forget | RunEvent válido contra spec por escritura ejecutada; caída del colector no afecta pipeline | bK-110 |

## G5 — Cluster (condicional > 25 fuentes)

| ID | Tarea | Criterio clave | SSOT |
|---|---|---|---|
| bK-G5.E1.T1–T3 | Coordinator (distribución+heartbeat) + Worker + failover | matar Worker → redistribución < 30s sin pérdida (checkpoints) = H5 | bK-120 |

## Criterios de completitud del documento
- [x] G0–G1 a nivel tarea atómica completa (ID/entregable/criterio/dep/SSOT); G2–G5 a nivel tarea con criterio clave (se micro-detallan al VALIDARSE sus docs SSOT en lotes 6/8 — regla de gates ECO-008 §3).
- [x] Derivado de A5 con adaptaciones registradas (Fase 0 superada; puertos C-01/D5; writers redefinidos D1).
- [ ] Paridad permanente con ECO-008 y bK-004. · [ ] Validación del arquitecto.

---
*bK-190 v1.0 · tablero/gates: → ECO-008 · estado: → bK-004*
