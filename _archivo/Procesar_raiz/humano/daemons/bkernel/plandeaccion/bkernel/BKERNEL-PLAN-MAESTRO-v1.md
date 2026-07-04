# BKERNEL-PLAN-MAESTRO-v1 — Plan de Desarrollo Atómico
## bKernel: Active Data Orchestration Engine · SBOS

**Versión:** 1.0 · **Fecha:** 2026-06-19 · **Estado:** VIGENTE
**Ruta:** `context/sbos/Procesar/humano/daemons/bkernel/plandeaccion/bkernel/BKERNEL-PLAN-MAESTRO-v1.md`
**Código fuente:** `/opt/skull/orquestador/proyectos/desarrollo/sbos/BkernelAgent/src/`
**Documentos canónicos:** `context/sbos/Procesar/humano/daemons/bkernel/`
**Tracking:** `REGISTRO-ESTADO.md` (este documento define QUÉ; REGISTRO-ESTADO define CUÁNDO y ESTADO)

---

## PARTE I — VISIÓN Y ALCANCE

### 1. Qué es bKernel

bKernel es el **Motor de Datos Soberano del SBOS.** Escucha los cambios en TODAS las bases
de datos del stack vía CDC (Change Data Capture), los normaliza en un formato canónico
(BkernelEvent), aplica reglas declarativas de enrutamiento, y publica **intenciones
estructuradas** en Redis Streams para que biedata las ejecute.

**bKernel NUNCA escribe en bases de datos de aplicaciones.** Es un orquestador de eventos,
no un sincronizador de datos. La escritura es responsabilidad exclusiva de biedata (D1/D2/D3).

### 2. Las 11 Fronteras (F-01 a F-11)

| # | Frontera | Regla |
|---|----------|-------|
| F-01 | bKernel escucha CDC de PostgreSQL (pgoutput) | Obligatorio — primer motor |
| F-02 | bKernel NUNCA expone API REST, HTTP, ni puerto TCP | Solo :9460 (métricas) + :9461 (health) readonly |
| F-03 | bKernel NUNCA escribe en BDs de aplicaciones | Publica en Redis Streams; biedata escribe |
| F-04 | Cada evento tiene LSN inmutable y único | WAL pgoutput garantiza orden total |
| F-05 | Checkpoint avanza solo tras XADD exitoso en Redis | Sin pérdida de eventos |
| F-06 | Loop prevention: descartar eventos con `origin='biedata'` hacia biedata | Anti-loop de 2 capas |
| F-07 | Binario MUSL estático, sin dependencias del SO | Ejecutable en Ubuntu 26.04 sin Rust instalado |
| F-08 | Cero hardcoding de aplicaciones | Todo declarativo: source.yml + transform.yml + task_catalog.sh |
| F-09 | Secretos vía Vault Agent sidecar | bKernel nunca habla con Vault directamente |
| F-10 | SD_NOTIFY Type=notify + watchdog | systemd supervisa; restart automático al colgar |
| F-11 | ctx_id obligatorio en audit_events | ISO 27001 A.8.15 — trazabilidad completa |

### 3. La Unidad Declarativa: la Ficha

Cada aplicación que bKernel escucha se declara en 4 archivos:

```
servers/<servidor>/<app>/
├── source.yml          ← qué BD, tabla, slot WAL, columnas
├── transform.yml        ← reglas CESQL: condiciones + acciones
├── task_catalog.sh      ← comandos bash que biedata ejecutará
└── setup.sh             ← creación de slot, publicación, permisos
```

**bKernel no sabe nada de OrangeHRM, Tryton, Saleor ni ninguna app concreta.**
Solo sabe leer fichas y ejecutar reglas. Zero hardcoding (R16).

---

## PARTE II — POLÍTICAS GLOBALES DE DESARROLLO

### P1 — Atomicidad de tareas

Cada tarea en el REGISTRO-ESTADO es atómica: tiene un ID único, un entregable concreto
y un criterio de aceptación MEDIBLE. No hay tareas "de exploración" o "de diseño" sin
entregable tangible.

### P2 — Testing first (Beck Gate 2)

- **Unit tests:** `cargo test` — coverage ≥ 80% en mods cdc, engine, state, writers
- **Integration tests:** `//go:build integration` equivalente en Rust — `#[cfg(test)]` con fixtures PG reales
- **BATS tests:** para task_catalog.sh de fichas de ejemplo
- **Bench tests:** criterios de latencia (G1.E1.T2, G3.E2.T1)

### P3 — Diseño (SOLID + Rust idioms)

- **S** — cada módulo una responsabilidad (cdc, engine, writers, state, fanout son independientes)
- **O** — nuevas fuentes = nuevas fichas, sin tocar el binario (open/closed)
- **L** — traits Rust sustituibles: `Store`, `RuleEngine`, `Writer` (Liskov)
- **I** — interfaces pequeñas: `SQLExecutor` (4 métodos), `RedisClient` (4 métodos)
- **D** — dependencia de traits, no de impls concretas (dependency inversion)

### P4 — Documentación sincronizada

Cada átomo completado actualiza simultáneamente:
1. `REGISTRO-ESTADO.md` — fila del átomo → ✅ con commit SHA
2. `LOG-DE-SESIONES.md` — entrada con fecha, átomo, resumen
3. Documento canónico asociado (bK-XXX) si el átomo cambia la arquitectura

### P5 — Sin intervención manual

- El binario se compila UNA vez (MUSL estático)
- La instalación la hace BOS vía ficha `sbos-bkernel`
- El DDL se ejecuta vía AutoMigrate al arrancar (G0.E4.T1)
- Cero comandos manuales en la VPS

### P6 — Puertos (SBOS-050)

| Puerto | Propósito | Exposición |
|--------|-----------|------------|
| 9460 | `/metrics` Prometheus | Solo ClusterIP — nunca externo |
| 9461 | `/health` GET only | Solo ClusterIP — nunca externo |
| — | Cualquier otro puerto | **PROHIBIDO** |

---

## PARTE III — PLAN ATÓMICO POR FASES

### G0 — ESQUELETO DEL BINARIO Y CI (9 átomos)

**Objetivo:** binario que compila, arranca, lee config, responde señales, expone métricas.

#### G0.E2.T1 — Workspace Cargo + estructura de módulos
- **Entregable:** `Cargo.toml` (edition 2024, perfil release LTO thin), `src/` con 9 mods stub compilando
- **Criterio:** `cargo build` OK; `cargo clippy -- -D warnings` limpio
- **Dep:** —
- **SSOT:** bK-050 (arquitectura)
- **Nota:** El scaffold actual (`BkernelAgent/`) usa edition 2021 y no tiene perfil release. Debe migrarse a 2024 + LTO.

#### G0.E2.T2 — Build MUSL estático + budget
- **Entregable:** target `x86_64-unknown-linux-musl`, binario estático
- **Criterio:** `file bkernel-daemon` reporta "statically linked"; tamaño < 15MB
- **Dep:** G0.E2.T1
- **SSOT:** C-08
- **Nota:** Requiere `rustup target add x86_64-unknown-linux-musl` + `musl-tools`

#### G0.E2.T3 — Config TOML + carga tipada
- **Entregable:** `bkernel.toml` ejemplo + structs serde con validación
- **Criterio:** boot con config inválida → error explícito con campo exacto; test unit
- **Dep:** G0.E2.T1
- **SSOT:** bK-050
- **Nota:** El scaffold en `config.rs` requiere revisión de campos obligatorios

#### G0.E2.T4 — Señales SIGTERM/SIGHUP
- **Entregable:** handler tokio para graceful shutdown + hot-reload
- **Criterio:** test de integración: SIGHUP no mata el proceso; SIGTERM sale ≤ 5s
- **Dep:** G0.E2.T1
- **SSOT:** bK-010(D2)

#### G0.E2.T5 — systemd unit + sd_notify
- **Entregable:** `bkernel.service` Type=notify, WatchdogSec=30
- **Criterio:** `systemctl start/stop/status` OK en sandbox; watchdog dispara restart al colgar
- **Dep:** G0.E2.T2, G0.E2.T4
- **SSOT:** bK-180

#### G0.E2.T6 — Métricas :9460 + health :9461
- **Entregable:** endpoints Prometheus + health check readonly
- **Criterio:** `curl :9460/metrics` OK; `curl :9461/health` → 200; cualquier método ≠GET → 405; escaneo: NINGÚN otro puerto abierto
- **Dep:** G0.E2.T1
- **SSOT:** bK-110, D5

#### G0.E2.T7 — CI pipeline
- **Entregable:** pipeline completo (build musl + fmt + clippy + test + budget + escaneo de puertos)
- **Criterio:** pipeline verde en commit vacío de feature
- **Dep:** G0.E2.T2, G0.E2.T6
- **SSOT:** ECO-007

#### G0.E4.T1 — Migraciones núcleo
- **Entregable:** DDL idempotente en `bkernel_db` schema `bkernel`:
  - `replication_state` — estado de slots WAL
  - `checkpoints` — LSN persistente
  - `dead_letter_queue` — eventos fallidos
  - `schema_change_log` — migraciones aplicadas
  - `source_registry` — fuentes registradas
  - **`context_sessions`** — Context Plane SBOS-049 (tabla de sesiones)
  - **`device_contexts`** — Context Plane SBOS-049 (tabla de dispositivos)
- **Criterio:** up/down limpios; idempotentes (re-up no-op)
- **Dep:** G0.E2.T1
- **SSOT:** bK-130, D2(C-04), SBOS-049

#### G0.E4.T2 — Pool PG + Vault Agent
- **Entregable:** conexión a PostgreSQL vía credencial de Vault sidecar, rotación automática
- **Criterio:** rotar secreto en caliente sin caída (test)
- **Dep:** G0.E2.T1, G0.E4.T1
- **SSOT:** bK-160(F-09)

---

### G1 — CDC MULTI-MOTOR (10 átomos)

**Objetivo:** leer WAL PostgreSQL, normalizar eventos, publicar en Redis Streams,
checkpoint LSN persistente, anti-loop de 2 capas.

#### G1.E1.T1 — Cliente replicación pgoutput
- **Entregable:** conexión a slot de replicación, decodificación de 5 tipos de mensaje
- **Criterio:** suite captura begin/commit/insert/update/delete contra PG18 fixture
- **Dep:** G0 completo
- **SSOT:** bK-060, A2

#### G1.E1.T2 — Canal por fuente con prioridad
- **Entregable:** `HashMap<SourceId, bounded_channel>` con capacity configurable
- **Criterio:** bajo carga concurrente de 2 fuentes, lag independiente (bench)
- **Dep:** G1.E1.T1
- **SSOT:** bK-050

#### G1.E1.T3 — Checkpoint LSN persistente
- **Entregable:** guarda/lee LSN en `checkpoints`; avance atómico post-XADD
- **Criterio:** kill -9 en mitad de lote → reanuda sin pérdida NI duplicado (test 20 iteraciones)
- **Dep:** G1.E1.T1, G0.E4.T1
- **SSOT:** bK-060

#### G1.E1.T4 — source.yml v1 parser
- **Entregable:** lee `servers/<srv>/<app>/source.yml`, registra fuente en `source_registry`
- **Criterio:** ficha de ejemplo carga; inválida → rechazo con campo exacto
- **Dep:** G1.E1.T1
- **SSOT:** bK-140

#### G1.E1.T5 — Métricas CDC
- **Entregable:** eventos/s, lag por listener, slot bytes retenidos → Prometheus
- **Criterio:** visibles en :9460; alerta de retención simulable
- **Dep:** G1.E1.T2
- **SSOT:** bK-110

#### G1.E2.T1 — Struct de intención + validador
- **Entregable:** tipos serde exactos del contrato bKernel↔biedata (ECO-020)
- **Criterio:** golden-files del contrato validan 100%
- **Dep:** —
- **SSOT:** ECO-020, ECO-010 §10

#### G1.E2.T2 — Outbox transaccional
- **Entregable:** tabla `outbox` + publicación `bkernel:stream:biedata.*` con XADD
- **Criterio:** evento en BD sin publicar sobrevive a crash y se publica al reinicio (test)
- **Dep:** G1.E2.T1, G1.E1.T3
- **SSOT:** ECO-020

#### G1.E2.T3 — Reintentos/backoff a Redis
- **Entregable:** política exponencial (1s, 5s, 15s) + DLQ
- **Criterio:** Redis caído 60s → cero pérdidas; métricas de reintento
- **Dep:** G1.E2.T2
- **SSOT:** bK-170

#### G1.E5.T1 — Filtro por origin
- **Entregable:** descarta eventos `origin='biedata'` hacia biedata
- **Criterio:** test de eco: escritura de biedata NO produce intención a biedata; SÍ propaga a otros destinos
- **Dep:** G1.E1 completo
- **SSOT:** ECO-020, F-06

#### G1.E5.T2 — Segunda capa anti-loop (event_id dedup)
- **Entregable:** consulta de duplicados por event_id antes de publicar
- **Criterio:** inyección de duplicado artificial → 1 sola propagación
- **Dep:** G1.E5.T1
- **SSOT:** ECO-020

---

### G2 — PIPELINE DECISOR (7 átomos)

**Objetivo:** registry de destinos, parser CESQL, routing condicional, ejecución task_catalog.sh, fichas de ejemplo.

#### G2.E1.T1 — DDL destination_registry
- **Entregable:** tabla `destination_registry` con CRUD completo
- **Criterio:** insert/update/delete/pause/resume funcional
- **Dep:** G0.E4.T1
- **SSOT:** bK-080

#### G2.E1.T2 — CRUD vía JSON-RPC `bkernel.dest.*`
- **Entregable:** comandos `bkernel.dest.add|list|pause|resume|remove` vía Unix socket (ADR-020)
- **Criterio:** pausar destino → eventos no enrutan; resumir → reanuda enrutamiento
- **Dep:** G2.E1.T1
- **SSOT:** bK-080, A5

#### G2.E1.T3 — Migración de reglas + hot-reload
- **Entregable:** reglas cargadas desde `servers/`; SIGHUP recarga sin reinicio
- **Criterio:** regla pausada NO enruta; regla nueva activa tras SIGHUP
- **Dep:** G2.E1.T2
- **SSOT:** bK-080

#### G2.E2.T1 — Parser CESQL
- **Entregable:** parser para subset CESQL: comparaciones (=, !=, >, <, IN), AND/OR/NOT, field access
- **Criterio:** suite de gramática 100% (casos válidos + inválidos)
- **Dep:** —
- **SSOT:** bK-080

#### G2.E2.T2 — Integración routing→engine
- **Entregable:** Motor evalúa condiciones CESQL → enruta a ≥2 destinos según contenido
- **Criterio:** test H2 parcial: evento con tenant_id=5 → solo destinos del tenant 5
- **Dep:** G2.E2.T1, G2.E1.T1
- **SSOT:** bK-080/090

#### G2.E2.T3 — Compatibilidad task_catalog.sh
- **Entregable:** contrato de invocación: env vars (TENANT_ID, EVENT_ID, OPERATION, TABLE_NAME), exit codes (0=ok, 1=retry, 2=dlq), timeout configurable
- **Criterio:** tests BATS con casos happy/error/timeout
- **Dep:** G2.E2.T2
- **SSOT:** bK-090 (V-05)

#### G2.E5.T1 — 2 fichas de ejemplo completas
- **Entregable:** 2 apps de ejemplo con 4 archivos cada una (source.yml, transform.yml, task_catalog.sh, setup.sh)
- **Criterio:** cargan por SIGHUP sin reinicio; BATS happy/error/idempotencia
- **Dep:** G2.E2.T3
- **SSOT:** bK-140 (V-03)

---

### G3 — CONTEXTO Y GRAFO (5 átomos)

**Objetivo:** Apache AGE en bkernel_db, DDL Context Plane (SBOS-049), enrichment automático de tenant_id, cross-reference de entidades.

#### G3.E1.T1 — Extensión AGE
- **Entregable:** Apache AGE habilitado en `bkernel_db`. Grafo: vértices (tenant, empresa, sucursal, dispositivo), aristas (belongs_to, authenticated_from)
- **Criterio:** `SELECT * FROM ag_catalog.ag_graph` retorna grafo creado
- **Dep:** G0.E4.T1
- **SSOT:** bK-070, bK-130

#### G3.E1.T2 — DDL Context Plane + entity_crossref
- **Entregable:** tablas `context_sessions` + `device_contexts` (SBOS-049) + `entity_crossref`
- **Criterio:** idempotente; `context_sessions` acepta ctx_id de 64 chars; `entity_crossref` unifica identidades entre apps
- **Dep:** G0.E4.T1
- **SSOT:** bK-070, bK-130, SBOS-049

#### G3.E1.T3 — Consultas grafo multi-tenant
- **Entregable:** queries Cypher con aislamiento por tenant
- **Criterio:** test multi-tenant: tenant A no ve datos de tenant B
- **Dep:** G3.E1.T1, G3.E1.T2
- **SSOT:** bK-070

#### G3.E2.T1 — mod enricher
- **Entregable:** resuelve tenant_id, empresa_id, sucursal_id desde grafo para eventos sin contexto
- **Criterio:** < 2ms P99 (bench 10k eventos)
- **Dep:** G3.E1.T1
- **SSOT:** bK-070

#### G3.E2.T2 — source.yml v2 (context_enrichment)
- **Entregable:** campos `context_enrichment` en source.yml; enricher automático
- **Criterio:** evento sin tenant_id resuelto automáticamente vía grafo
- **Dep:** G3.E2.T1
- **SSOT:** bK-070

---

### G4 — PROTECCIÓN Y LINAJE (6 átomos)

**Objetivo:** DDL Guardian, fingerprint watcher, clasificación 5 niveles, response engine, OpenLineage.

#### G4.E1.T1 — DDL Guardian event triggers
- **Entregable:** event triggers PostgreSQL para CREATE/ALTER/DROP TABLE
- **Criterio:** DDL ejecutado → evento capturado → clasificado
- **Dep:** G1.E1.T1
- **SSOT:** bK-100, B3

#### G4.E1.T2 — Fingerprint watcher
- **Entregable:** hash de estructura de schema; comparación contra baseline
- **Criterio:** drift detectado → alerta en :9460 métricas
- **Dep:** G4.E1.T1
- **SSOT:** bK-100

#### G4.E1.T3 — Clasificador 5 niveles
- **Entregable:** BREAKING/SAFE/SECURITY/MAINTENANCE/UNKNOWN con políticas por nivel
- **Criterio:** BREAKING pausa fichas <100ms; SAFE no interrumpe; SECURITY detiene+notifica
- **Dep:** G4.E1.T1
- **SSOT:** bK-100

#### G4.E1.T4 — Response engine + maintenance_windows
- **Entregable:** motor de respuesta automática + ventanas de mantenimiento
- **Criterio:** SECURITY → detiene pipeline + notifica; MAINTENANCE → no alerta en ventana programada
- **Dep:** G4.E1.T3
- **SSOT:** bK-100

#### G4.E2.T1 — RunEvent OpenLineage
- **Entregable:** emisión fire-and-forget de eventos OpenLineage
- **Criterio:** RunEvent válido contra spec por escritura ejecutada
- **Dep:** G1.E2.T2
- **SSOT:** bK-110

#### G4.E2.T2 — Tolerancia a caída del colector
- **Entregable:** si el colector OpenLineage no responde, el pipeline sigue operando
- **Criterio:** inyectar fallo de red → pipeline CDC sin degradación
- **Dep:** G4.E2.T1
- **SSOT:** bK-110

---

### G5 — CLUSTER (3 átomos, condicional > 25 fuentes)

**Objetivo:** arquitectura Coordinator/Worker para escalar horizontalmente cuando hay > 25 fuentes CDC.

#### G5.E1.T1 — Coordinator
- **Entregable:** distribución de slots entre Workers, heartbeat cada 5s
- **Criterio:** detecta Worker muerto en ≤15s
- **Dep:** G1 completo
- **SSOT:** bK-120

#### G5.E1.T2 — Worker
- **Entregable:** ejecución aislada de listeners; checkpoint independiente
- **Criterio:** 2 Workers con 3 slots cada uno; sin interferencia
- **Dep:** G5.E1.T1
- **SSOT:** bK-120

#### G5.E1.T3 — Failover automático
- **Entregable:** redistribución de slots al morir un Worker
- **Criterio:** kill -9 Worker → slots redistribuidos < 30s; sin pérdida (checkpoint resume)
- **Dep:** G5.E1.T2
- **SSOT:** bK-120

---

### FASE FICHA — DECLARACIÓN COMO FICHA BOS (3 átomos)

**Objetivo:** bkernel operativo → declarado como ficha → instalable vía `bosctl ficha install sbos-bkernel`.

#### FICHA.T1 — manifest.yml
- **Entregable:** `servers/S-HOST/sbos-bkernel/manifest.yml` con:
  - identity: id, version, server, category=1 (daemon soberano), criticality=true
  - workload: type=systemd, runtime=Rust MUSL
  - dependencies: postgresql, redis
  - ports: 9460 (metrics), 9461 (health)
  - health: type=command (curl :9461/health)
- **Criterio:** `bosctl ficha describe sbos-bkernel` retorna manifest completo
- **Dep:** G0 completo
- **SSOT:** bK-180

#### FICHA.T2 — task_catalog.sh
- **Entregable:** script con 5 funciones:
  - `ficha_pre_install`: verificar que el host tiene systemd ≥ 255
  - `ficha_install`: copiar binario MUSL + config + systemd unit + ejecutar DDL AutoMigrate
  - `ficha_post_install`: verificar systemd active + métricas responden
  - `ficha_test`: verificar health endpoint + métricas + CDC conectado
  - `ficha_repair`: reinstalar binario + regenerar config + reejecutar DDL
- **Criterio:** `bosctl ficha install sbos-bkernel` → bkernel active + métricas respondiendo en ≤ 3 min
- **Dep:** FICHA.T1
- **SSOT:** bK-180

#### FICHA.T3 — Integración en deploy.go
- **Entregable:** seed `seed-skull.yml` actualizado: paso [7/8] instala `sbos-bkernel` después de kong
- **Criterio:** `bosctl deploy seed-skull.yml` → bkernel instalado automáticamente
- **Dep:** FICHA.T2
- **SSOT:** bK-180

---

## PARTE IV — CRITERIOS DE CERTIFICACIÓN

Al completar los 43 átomos, bkernel debe pasar 8 criterios de certificación:

| ID | Criterio | Condición |
|----|----------|-----------|
| C-01 | Build limpio | `cargo build --release` + `cargo clippy -- -D warnings` sin errores |
| C-02 | Tests verdes | `cargo test` 100% pass; `cargo bench` sin regresiones |
| C-03 | CDC PostgreSQL | Captura INSERT/UPDATE/DELETE de tabla fixture en < 100ms |
| C-04 | Checkpoint sobrevive kill -9 | 20 iteraciones sin pérdida ni duplicado |
| C-05 | Outbox transaccional | Evento en BD sin publicar → sobrevive crash → publicado al reinicio |
| C-06 | Anti-loop 2 capas | Evento origin=biedata NO propaga a biedata; duplicado → 1 sola emisión |
| C-07 | Redis caído 60s → cero pérdidas | Reintentos + backoff + DLQ funcional |
| C-08 | Binario < 15MB MUSL estático | `file` reporta "statically linked"; `ls -lh` < 15MB |

---

## PARTE V — GOBERNANZA

### Documentos vinculados

| Documento | Relación |
|-----------|----------|
| `REGISTRO-ESTADO.md` | Tracking en vivo de cada átomo |
| `MAPA-NAVEGACION.md` | Estructura de directorios y reglas de lectura |
| `PROTOCOLO-SESION-AGENTE.md` | Apertura/ejecución/cierre de sesiones |
| `INSTRUCCIONES-DE-USO.md` | Cómo ejecutar cada gate |
| `SKILL-AGENTE-PROGRAMADOR.md` | Skill de Claude Code para desarrollo bkernel |
| `LOG-DE-SESIONES.md` | Bitácora cronológica |
| `GESTION-RIESGOS-OPERATIVOS.md` | Riesgos, mitigaciones, contingencias |
| `action_catalog.yml` | Catálogo de acciones biaos para bkernel |

### Reglas de modificación

1. **Este documento** solo se modifica al: agregar/quitar átomos, cambiar criterios de certificación, o actualizar políticas globales.
2. **Cambios requieren:** revisión del arquitecto + actualización de `REGISTRO-ESTADO.md` + entrada en `LOG-DE-SESIONES.md`.
3. **Versionado semántico:** MAJOR (cambio de gates), MINOR (cambio de átomos), PATCH (corrección de errores en texto).

---
*BKERNEL-PLAN-MAESTRO-v1 · 2026-06-19 · SKULL · 43 átomos · 7 gates*
