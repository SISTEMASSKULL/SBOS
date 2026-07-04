# REGISTRO-ESTADO — Plan de Desarrollo bKernel
## Estado actual de cada átomo · Actualizar en cada Informe de Cierre

**Última actualización:** 2026-06-19 · **Progreso:** 8✅ / 0🟡 / 35🔴
**Estados:** 🔴 NO INICIADA · 🟡 EN PROGRESO · ✅ COMPLETA · ⚠️ BLOQUEADA
**Revisión (columna Rev):** ☐ = pendiente · ☑ = verificado contra spec + gates
**Gate (columna G):** 0=build · 1=tests · 2=diseño(spec+Rust idioms) · 3=docs · 4=ADR

**Documentos normativos activos (brújula del proyecto):**
- `BKERNEL-PLAN-MAESTRO-v1.md` — plan maestro de desarrollo
- `context/sbos/Procesar/humano/daemons/bkernel/SBOS_bkernel_VISION.md` v3.0 — visión y fronteras
- `context/sbos/Procesar/humano/daemons/bkernel/SBOS_bkernel_ARQUITECTURA.md` v3.0 — arquitectura Rust
- `context/sbos/Procesar/humano/daemons/bkernel/SBOS_bkernel_DOMINIO.md` v3.0 — modelo de dominio
- `context/sbos/Procesar/humano/daemons/bkernel/SBOS_bkernel_FUNCIONALIDADES.md` v3.0 — funcionalidades
- `context/sbos/Procesar/humano/daemons/bkernel/SBOS_bkernel_DATOS.md` v3.0 — esquema bkernel_db
- `context/sbos/Procesar/humano/daemons/bkernel/SBOS_bkernel_INTEGRACIONES.md` v3.0 — contratos Redis Streams
- `BOS_V8/BOS_V8_SBOS-023-DAEMON-BKERNEL.md` — documento canónico V8 (v5+v6+bAuth compilado)
- `context/sbos/BibliotecaSBOS/src/001_bkernel_db.sql` — DDL operativo de referencia
- `BOS_V8/BOS_V8_SBOS-049-CONTEXT-PLANE.md` — Context Plane spec (tablas context_sessions, device_contexts)
- **SBOS-050-PORT-CATALOG.md** — política de puertos (9460/9461 métricas/health, cero API)
- **SBOS-054-NETWORK-SECURITY.md** — 🔒 Zero Trust, sin HTTP entre daemons

**Stack canónico (ADR-017):**
| Componente | Versión | Componente | Versión |
|-----------|---------|-----------|---------|
| Rust | 1.85+ (Edition 2024) | tokio | 1.x (rt-multi-thread) |
| PostgreSQL | 18.4 | Redis | 8.6.2 |
| Ubuntu Server | 26.04 LTS | MUSL | static linking |

**Ruta del código fuente:** `/opt/skull/orquestador/proyectos/desarrollo/sbos/BkernelAgent/src/`
**Ruta de este documento:** `context/sbos/Procesar/humano/daemons/bkernel/plandeaccion/bkernel/REGISTRO-ESTADO.md`

---

## Sistema de tracking

- **FASE G0–G5** = orden de ejecución según el plan atómico bK-190
- **Cada átomo** tiene ID único, entregable, criterio MEDIBLE, dependencias y SSOT
- **Progress** se mide en átomos completados
- **Rev ☑** = verificado contra documentación canónica y normas activas
- **Gate** = punto de control: 0=build, 1=tests, 2=diseño, 3=docs, 4=ADR
- **D** = documento SSOT asociado (bK-XXX)

**Orden de ejecución:** el siguiente átomo es siempre el primer 🔴 leyendo de arriba hacia abajo.
Las dependencias se respetan estrictamente — no se ejecuta un átomo hasta que sus dependencias estén ✅.

---

## G0 — Esqueleto del Binario y CI

**Objetivo:** binario Rust MUSL estático que compila, arranca, lee config, responde señales, expone métricas readonly.
**DoD G0:** `cargo build --release` limpio · `cargo clippy -- -D warnings` limpio · `cargo test` verde · binario < 15MB MUSL · systemd unit funcional.

| ID | Átomo | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|
| G0.E2.T1 | Workspace Cargo + estructura de módulos | ✅ | 44f3785 | 📝 Migrado edition 2021→2024. Perfil release LTO+z+strip. 9 mods compilando. `cargo check` + `cargo clippy -- -D warnings` limpios. bkernel-common compila como crate externo | ☑ | 0,2,3 | bK-050 |
| G0.E2.T2 | Build MUSL estático + budget | ✅ | 44f3785 | 📝 `file` reporta "ELF 64-bit, static-pie linked, stripped". 3.2 MB (< 15 MB). `ldd` confirma "statically linked". Rust 1.96.0 + x86_64-unknown-linux-musl | ☑ | 0,1 | C-08 |
| G0.E2.T3 | Config TOML + carga tipada | ✅ | 47dab94 | 📝 `validate()` verifica 14 campos. 15 tests (14 invalid + 1 carga bundled .toml). Error incluye campo exacto + razón. Puerto metrics corregido 9100→9460 (SBOS-050) | ☑ | 0,1,2 | bK-050 |
| G0.E2.T4 | Señales SIGTERM/SIGHUP | ✅ | e21cd98 | 📝 signals.rs: módulo SignalPair. 3 tests integración con signal_tester real: SIGHUP sobrevive, SIGTERM sale ≤5s, 3×HUP+TERM. 19 tests total | ☑ | 0,1 | bK-010(D2) |
| G0.E2.T5 | systemd unit + sd_notify | ✅ | 8b78b66 | 📝 daemon.rs: notify_ready() + WatchdogHandle. bkernel.service: Type=notify, WatchdogSec=30, hardening CIS. Watchdog cada 10s. sd-notify 0.5 pure Rust | ☑ | 0,1,3 | bK-180 |
| G0.E2.T6 | Métricas + health (sin HTTP) | ✅ | e11f0c7 | 📝 bkernel CERRADO (F-02). Métricas en memoria→Redis. Health vía systemd watchdog. Cero TCP. grpc/ preparado para ADR-020. 3 tests métricas | ☑ | 0,1,2 | bK-110, D5 |
| G0.E2.T7 | CI pipeline completo | ✅ | 481bf0d | 📝 .github/workflows/bkernel-ci.yml: fmt+clippy+test+build+budget+port-scan. 22 tests. Port scan verifica ZERO TCP. cargo fmt aplicado (8 archivos) | ☑ | 0,1,3 | ECO-007 |

### G0.E4 — Base operacional

| ID | Átomo | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|
| G0.E4.T1 | Migraciones núcleo `bkernel_db` | ✅ | 0525b0e | 📝 7 tablas + 7 índices en schema bkernel. Incluye context_sessions + device_contexts (SBOS-049). Todo IF NOT EXISTS idempotente. 23 tests | ☑ | 0,1,2,3 | bK-130, D2(C-04) |
| G0.E4.T2 | Pool PostgreSQL + Vault Agent | 🔴 | — | 📝 *Pendiente* — Conexión vía credencial de Vault (sidecar). Rotación en caliente sin caída. Scaffold en `main.rs` usa env var `BKERNEL_PG_PASSWORD` — migrar a Vault | ☐ | 0,1,2,4 | bK-160(F-09) |

---

## G1 — CDC Multi-Motor (PostgreSQL Primero)

**Objetivo:** leer WAL pgoutput, normalizar BkernelEvent, publicar en Redis Streams, checkpoint LSN persistente, anti-loop.
**DoD G1:** captura INSERT/UPDATE/DELETE de PostgreSQL · checkpoint sobrevive kill -9 · outbox transaccional · zero pérdida ante caída Redis 60s.

### G1.E1 — Listener CDC pgoutput

| ID | Átomo | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|
| G1.E1.T1 | Cliente replicación pgoutput | 🔴 | — | 📝 *Pendiente* — Conexión a slot, decodificación begin/commit/insert/update/delete. Suite captura 5 tipos contra PG18 fixture. Scaffold en `cdc/wal_reader.rs` | ☐ | 0,1,2 | bK-060, A2 |
| G1.E1.T2 | Canal por fuente (Fix-01) | 🔴 | — | 📝 *Pendiente* — `HashMap<SourceId, bounded_channel>` con prioridad. Bajo carga concurrente de 2 fuentes, lag independiente (bench). Scaffold en `engine/` | ☐ | 0,1,2 | bK-050 |
| G1.E1.T3 | Checkpoint LSN persistente | 🔴 | — | 📝 *Pendiente* — Guarda/lee `LSN:{hex}`. kill -9 en mitad de lote → reanuda sin pérdida NI duplicado (test 20 iteraciones). Scaffold en `state/checkpoint.rs` | ☐ | 0,1 | bK-060 |
| G1.E1.T4 | source.yml v1 parser + carga de ficha | 🔴 | — | 📝 *Pendiente* — Lee `servers/<srv>/<app>/source.yml`, registra fuente. Ficha de ejemplo carga; inválida → rechazo con campo exacto | ☐ | 0,1,2,3 | bK-140 |
| G1.E1.T5 | Métricas CDC | 🔴 | — | 📝 *Pendiente* — eventos/s, lag por listener, slot bytes retenidos. Visibles en :9460. Alerta de retención simulable. Scaffold en `metrics.rs` | ☐ | 0,1,2 | bK-110 |

### G1.E2 — Outbox → Streams de Intención

| ID | Átomo | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|
| G1.E2.T1 | Struct de intención + validador | 🔴 | — | 📝 *Pendiente* — Tipos serde EXACTOS del contrato. Golden-files validan 100%. Scaffold en `writers/` | ☐ | 0,1,2 | ECO-020, ECO-010 §10 |
| G1.E2.T2 | Outbox transaccional | 🔴 | — | 📝 *Pendiente* — Tabla outbox + publicación `bkernel:stream:biedata.*` con XADD. Evento en BD sin publicar sobrevive a crash y se publica al reinicio (test) | ☐ | 0,1 | ECO-020 |
| G1.E2.T3 | Reintentos/backoff a Redis | 🔴 | — | 📝 *Pendiente* — Política exponencial + DLQ. Redis caído 60s → cero pérdidas. Métricas de reintento. Scaffold en `state/dlq.rs` | ☐ | 0,1,2 | bK-170 |

### G1.E5 — Anti-Loop (Skipback)

| ID | Átomo | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|
| G1.E5.T1 | Filtro por origin | 🔴 | — | 📝 *Pendiente* — Descarta eventos `origin='biedata'` hacia biedata. Test de eco: escritura de biedata NO produce intención a biedata; SÍ propaga a otros destinos | ☐ | 0,1,2 | ECO-020, F-06 |
| G1.E5.T2 | Segunda capa (verificación event_id) | 🔴 | — | 📝 *Pendiente* — Consulta dedup según contrato. Inyección de duplicado artificial → 1 sola propagación | ☐ | 0,1 | ECO-020 |

---

## G2 — Pipeline Decisor

**Objetivo:** destination_registry CRUD, parser CESQL, routing condicional, ejecución task_catalog.sh.
**DoD G2:** regla pausada NO enruta · CESQL suite gramática 100% · evento enruta a ≥2 destinos según contenido · 2 fichas de ejemplo completas.

| ID | Átomo | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|
| G2.E1.T1 | DDL destination_registry | 🔴 | — | 📝 *Pendiente* — Tabla `destination_registry` en `bkernel_db`. CRUD completo | ☐ | 0,1,2,3 | bK-080 |
| G2.E1.T2 | CRUD `bosctl bkernel dest` | 🔴 | — | 📝 *Pendiente* — Subcomandos: add/list/pause/resume. Vía JSON-RPC `bkernel.dest.*` | ☐ | 0,1,2,3 | bK-080, A5 |
| G2.E1.T3 | Migración de reglas | 🔴 | — | 📝 *Pendiente* — Regla pausada NO enruta eventos. Hot-reload vía SIGHUP | ☐ | 0,1 | bK-080 |
| G2.E2.T1 | Parser CESQL | 🔴 | — | 📝 *Pendiente* — Subset: comparaciones, AND/OR/NOT, field access. Suite de gramática (casos válidos+inválidos) 100% | ☐ | 0,1,2 | bK-080 |
| G2.E2.T2 | Integración routing→engine | 🔴 | — | 📝 *Pendiente* — Evento enruta a ≥2 destinos según contenido (H2 parcial). Scaffold en `engine/matcher.rs` + `engine/rule_index.rs` | ☐ | 0,1 | bK-080/090 |
| G2.E2.T3 | Compatibilidad task_catalog.sh | 🔴 | — | 📝 *Pendiente* — Contrato de invocación: env vars, exit codes, timeout. Tests BATS | ☐ | 0,1,2,3 | bK-090 (V-05) |
| G2.E5.T1 | 2 fichas de ejemplo completas | 🔴 | — | 📝 *Pendiente* — 4 archivos por ficha (source.yml, transform.yml, task_catalog.sh, setup.sh). Cargan por SIGHUP sin reinicio. BATS happy/error/idempotencia | ☐ | 0,1,2,3 | bK-140 (V-03) |

---

## G3 — Contexto y Grafo

**Objetivo:** grafo AGE en bkernel_db, DDL context_sessions + device_contexts (Context Plane SBOS-049), enriquecimiento de contexto, cross-reference entity_crossref.
**DoD G3:** consultas jerarquía con aislamiento por tenant · evento sin tenant_id resuelto < 2ms P99 · context_sessions poblada · entity_crossref funcional.

| ID | Átomo | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|
| G3.E1.T1 | Extensión AGE en bkernel_db | 🔴 | — | 📝 *Pendiente* — Apache AGE habilitado en `bkernel_db`. DDL grafo: vértices tenant/empresa/sucursal/dispositivo, aristas belongs_to/authenticated_from | ☐ | 0,1,2,3,4 | bK-070, bK-130 |
| G3.E1.T2 | DDL Context Plane + migración crossref | 🔴 | — | 📝 *Pendiente* — `context_sessions` + `device_contexts` (SBOS-049). `entity_crossref` (mapeo identidades entre apps). Idempotente | ☐ | 0,1,2,3 | bK-070, bK-130, SBOS-049 |
| G3.E1.T3 | Consultas grafo multi-tenant | 🔴 | — | 📝 *Pendiente* — Jerarquía con aislamiento por tenant. Test multi-tenant: tenant A no ve datos de tenant B | ☐ | 0,1 | bK-070 |
| G3.E2.T1 | mod enricher | 🔴 | — | 📝 *Pendiente* — Resuelve tenant_id, empresa_id, sucursal_id desde grafo para eventos sin contexto. < 2ms P99 (bench 10k) | ☐ | 0,1,2 | bK-070 |
| G3.E2.T2 | source.yml v2 (context_enrichment) | 🔴 | — | 📝 *Pendiente* — Campos `context_enrichment` en source.yml. Evento sin tenant_id resuelto automáticamente | ☐ | 0,1,2,3 | bK-070 |

---

## G4 — Protección y Linaje

**Objetivo:** DDL Guardian (schema drift detection), fingerprint watcher, clasificación 5 niveles, response engine, OpenLineage.
**DoD G4:** BREAKING pausa fichas <100ms · SAFE no interrumpe · SECURITY detiene+notifica · RunEvent OpenLineage válido.

| ID | Átomo | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|
| G4.E1.T1 | DDL Guardian — event triggers | 🔴 | — | 📝 *Pendiente* — Event triggers en PostgreSQL para DDL. Captura CREATE/ALTER/DROP TABLE | ☐ | 0,1,2,3,4 | bK-100, B3 |
| G4.E1.T2 | Fingerprint watcher | 🔴 | — | 📝 *Pendiente* — Schema fingerprint (hash de estructura). Comparación contra baseline. Alerta en drift | ☐ | 0,1,2 | bK-100 |
| G4.E1.T3 | Clasificador 5 niveles | 🔴 | — | 📝 *Pendiente* — BREAKING/SAFE/SECURITY/MAINTENANCE/UNKNOWN. BREAKING pausa fichas <100ms. SAFE no interrumpe | ☐ | 0,1,2 | bK-100 |
| G4.E1.T4 | Response engine + maintenance_windows | 🔴 | — | 📝 *Pendiente* — SECURITY detiene pipeline + notifica SIEM. Maintenance windows: cambios esperados no generan alerta | ☐ | 0,1,2 | bK-100 |
| G4.E2.T1 | RunEvent OpenLineage | 🔴 | — | 📝 *Pendiente* — Emisión fire-and-forget de eventos OpenLineage. RunEvent válido contra spec | ☐ | 0,1,2,3 | bK-110 |
| G4.E2.T2 | Caída del colector no afecta pipeline | 🔴 | — | 📝 *Pendiente* — Si el colector OpenLineage no responde, el pipeline CDC sigue operando. Sin bloqueo | ☐ | 0,1 | bK-110 |

---

## G5 — Cluster (Condicional > 25 Fuentes)

**Objetivo:** arquitectura Coordinator/Worker, distribución de slots, heartbeat, failover automático.
**DoD G5:** matar Worker → redistribución < 30s sin pérdida (checkpoints). Solo se activa si hay > 25 fuentes registradas.

| ID | Átomo | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|
| G5.E1.T1 | Coordinator — distribución + heartbeat | 🔴 | — | 📝 *Pendiente* — Distribuye slots entre Workers. Heartbeat cada 5s. Detecta Worker muerto en ≤15s | ☐ | 0,1,2,4 | bK-120 |
| G5.E1.T2 | Worker — ejecución aislada | 🔴 | — | 📝 *Pendiente* — Cada Worker ejecuta listeners asignados. Checkpoint independiente. No comparte estado mutable con otros Workers | ☐ | 0,1,2 | bK-120 |
| G5.E1.T3 | Failover automático | 🔴 | — | 📝 *Pendiente* — Matar Worker → Coordinator redistribuye slots < 30s. Sin pérdida de eventos (checkpoint resume) | ☐ | 0,1 | bK-120 |

---

## FASE FICHA — Declaración como Ficha BOS

**Objetivo:** bkernel operativo → declarado como ficha `sbos-bkernel` en `servers/S-HOST/` → instalable vía `bosctl ficha install sbos-bkernel`.
**DoD Ficha:** `bosctl ficha install sbos-bkernel` instala systemd unit + binario + config + DDL en ≤ 3 min.

| ID | Átomo | Estado | Commit | Solución / Bitácora | Rev | G | D |
|---|---|---|---|---|---|---|---|
| FICHA.T1 | manifest.yml sbos-bkernel | 🔴 | — | 📝 *Pendiente* — Declaración completa: identity, workload (Rust systemd), dependencies (postgresql, redis), health check, ports (9460/9461) | ☐ | 0,2,3 | bK-180 |
| FICHA.T2 | task_catalog.sh | 🔴 | — | 📝 *Pendiente* — ficha_pre_install: verificar Rust runtime no requerido (binario MUSL estático). ficha_install: copiar binario + config + systemd unit. ficha_post_install: ejecutar DDL AutoMigrate. ficha_test: verificar métricas + health + CDC conectado | ☐ | 0,1,2,3 | bK-180 |
| FICHA.T3 | Integración en deploy.go | 🔴 | — | 📝 *Pendiente* — Paso [7/8]: después de kong, instalar `sbos-bkernel`. Seed `seed-skull.yml`: agregar `sbos-bkernel` a la lista de fichas | ☐ | 0,1,2 | bK-180 |

---

## Tabla resumen por Gate

| Gate | Átomos totales | Completados | Pendientes | Progreso |
|------|---------------|-------------|------------|----------|
| G0 — Esqueleto + CI | 9 | 8 | 1 | 89% |
| G1 — CDC + Outbox + Anti-loop | 10 | 0 | 10 | 0% |
| G2 — Pipeline Decisor | 7 | 0 | 7 | 0% |
| G3 — Contexto y Grafo | 5 | 0 | 5 | 0% |
| G4 — Protección y Linaje | 6 | 0 | 6 | 0% |
| G5 — Cluster | 3 | 0 | 3 | 0% |
| FICHA — Declaración | 3 | 0 | 3 | 0% |
| **TOTAL** | **43** | **8** | **35** | **18.6%** |

---

## YAML canónico de estado

```yaml
bkernel_state:
  schema_version: 1
  updated: "2026-06-19"
  updated_by_session: "S-002"
  proyecto: bkernel
  codigo: "/opt/skull/orquestador/proyectos/desarrollo/sbos/BkernelAgent/src/"
  binario: "bkernel-daemon"
  lenguaje: "Rust 1.85+ (Edition 2024, MUSL estático, LTO, tokio)"
  superficie: "CERO — sin API REST, sin puerto TCP (solo :9460 métricas + :9461 health readonly)"
  docs_canonicos:
    completos: ["VISION","ARQUITECTURA","DOMINIO","FUNCIONALIDADES","DATOS","INTEGRACIONES","GLOSARIO","SEGURIDAD","OPERACION","README","000-INDICE"]
    pendientes: []
  gates:
    G0_esqueleto_ci: { estado: EN_PROGRESO, atomos: 9, completados: 8, next: "G0.E4.T2" }
    G1_cdc_outbox:  { estado: NO_INICIADO, atomos: 10, completados: 0 }
    G2_pipeline:    { estado: NO_INICIADO, atomos: 7, completados: 0 }
    G3_contexto:    { estado: NO_INICIADO, atomos: 5, completados: 0 }
    G4_proteccion:  { estado: NO_INICIADO, atomos: 6, completados: 0 }
    G5_cluster:     { estado: NO_INICIADO, atomos: 3, completados: 0 }
    FICHA_declaracion: { estado: NO_INICIADO, atomos: 3, completados: 0 }
  prerequisitos:
    rust_toolchain: { estado: INSTALADO, nota: "rustc 1.96.0 + cargo 1.96.0 + x86_64-unknown-linux-musl" }
    postgresql_18:  { estado: DISPONIBLE, nota: "VPS 13.140.128.230 sbos-data/postgresql-0" }
    redis_8:        { estado: DISPONIBLE, nota: "VPS 13.140.128.230 sbos-data/redis-0" }
    bkernel_db:     { estado: CREADA_VACIA, nota: "0 tablas — G0.E4.T1 poblará" }
  next: "G0.E4.T2 — Pool PostgreSQL + Vault Agent (último de G0)"
```

---

## Reglas

1. Solo se edita el YAML y las filas de tabla; evidencia obligatoria por transición (comando+salida o ruta de artefacto).
2. Divergencia con BKERNEL-PLAN-MAESTRO-v1.md: gana este registro; reconciliar en la misma sesión.
3. Cada átomo completado debe tener: commit SHA, nota de lo realizado, Rev ☑ verificada.
4. El orden de ejecución es secuencial por Gate (G0→G1→G2→G3→G4→G5→FICHA). Dentro de cada gate, respetar dependencias.
5. No se avanza a un gate sin que el anterior esté 100% ✅.

---
*REGISTRO-ESTADO v1.0 · 2026-06-19 · SKULL · maestro: BKERNEL-PLAN-MAESTRO-v1.md*
