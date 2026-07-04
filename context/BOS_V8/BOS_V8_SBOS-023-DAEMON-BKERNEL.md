# SBOS-023-DAEMON-BKERNEL
## SBOS Data Kernel: Active Orchestration Engine — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026
### ENRIQUECIDO V8 — con V5 + V7 + Smart* Enrichment

---

## 1. Identidad del Daemon

| Campo | Valor |
|---|---|
| Nombre | SBOS Data Kernel: Active Orchestration Engine |
| Daemon | `bkernel` |
| Servicio | `bkernel.service` |
| Lenguaje | **Rust 1.85+ (Edition 2024)** — definitivo, sin implementación alternativa |
| Runtime async | tokio 1.x (rt-multi-thread) |
| Unidad declarativa | Regla (archivo YAML) |
| Directorio | `/etc/bos/blibs/bkernel/rules/<app>/<nombre_regla>/` |
| Config | `/etc/bos/blibs/bkernel/bkernel.toml` |
| BD propia | `bkernel_db` (solo estado operacional, nunca datos de negocio) |

## 2. Función

Corazón de datos del SBOS. Daemon binario soberano en host Ubuntu (no en K8s). Escucha el WAL de PostgreSQL, detecta cambios en cualquier app del stack, aplica reglas YAML declarativas, y produce escrituras idempotentes — sin que las apps sean modificadas.

Es al dominio de los DATOS lo que el IAM Installer es al dominio de la INFRAESTRUCTURA.

### Las 6 Capacidades

1. **CDC Real-Time** — captura INSERT/UPDATE/DELETE con latencia de milisegundos vía WAL pgoutput
2. **MDM Hub** — Tryton como fuente de verdad + entity_crossref para identidad unificada
3. **Rule Engine Declarativo** — YAML hot-reloadable sin recompilar binario
4. **Event Bus Implícito (CQRS)** — WAL de PostgreSQL como bus de eventos nativo
5. **Auditoría Global** — bkernel_db.audit_events con contexto KC completo (ISO 27001)
6. **Indexación Federada** — cola Redis para bSearch (Meilisearch) y aiserver (Qdrant embeddings)

## 3. Tres Inputs, Cero Superficie de Ataque

```
INPUTS VÁLIDOS:
  1. WAL de PostgreSQL (eventos de datos)
  2. SIGTERM (apagado graceful)
  3. SIGHUP (hot-reload reglas sin reiniciar)

No tiene API REST. No tiene puerto abierto. No tiene interfaz web.
```

Daemon sin superficie de ataque externa. Nunca pierde un evento — si se apaga inesperadamente, retoma desde último LSN checkpointed.

## 4. Cero Invasión

Ninguna app es modificada. No se instalan agentes, no se modifican schemas, no se agregan webhooks. Única configuración necesaria:

```sql
-- postgresql.conf:
wal_level = logical
max_replication_slots = 20

-- Un slot por BD:
SELECT pg_create_logical_replication_slot('bkernel_orangehrm', 'pgoutput');
SELECT pg_create_logical_replication_slot('bkernel_tryton', 'pgoutput');
```

## 5. Arquitectura Rust

```rust
mod cdc;        // CDC Engine: lectura WAL via pgoutput
mod engine;     // Rule Engine: match + transform + forward-chaining
mod writers;    // Writer Pool: UPSERT idempotente multi-destino
mod catalog;    // Task Catalog: plugins nativos y externos (.so)
mod state;      // State Manager: LSN + DLQ + entity_crossref
mod fanout;     // Fanout: Redis + MinIO + cola bSearch + cola embedding

#[tokio::main]
async fn main() -> Result<()> {
    let config  = Config::from_file("bkernel.toml")?;
    let rules   = engine::RuleIndex::load("rules/")?;
    let writers = writers::Pool::new(&config.writers)?;
    let state   = state::Manager::open(&config.state_db)?;
    let fanout  = fanout::Engine::new(&config.fanout)?;
    let pool    = rayon::ThreadPoolBuilder::new().num_threads(num_cpus::get()).build()?;

    let mut wal = cdc::WalReader::new(&config.postgres, &state).await?;
    loop {
        let batch = wal.read_batch(1_000).await?;
        pool.install(|| {
            batch.par_iter().for_each(|event| {
                if let Some(actions) = rules.match_event(event) {
                    for action in &actions { writers.execute(action); }
                }
                fanout.dispatch(event);
            });
        });
        state.save_checkpoint(batch.last_lsn())?;
    }
}
```

### Por qué Rust (no Go, no C++)

| Criterio | Rust | Go | C++ |
|---|---|---|---|
| GC | Zero GC (ownership) | GC 0.5-50ms pausas | Zero GC (manual) |
| Memoria | Borrow checker en compilación | Runtime | Manual (RAII) |
| Data races | Imposibles en safe code | Posibles | Posibles |
| Latencia p999 | Determinista | Spikes GC | Determinista |
| Caso SBOS | **WAL CDC alta frecuencia** | HTTP APIs, WebSocket | Sin ventaja sobre Rust |

SLO bkernel: < 500ms P99. Pausa GC Go de 50ms durante WAL = datos inconsistentes.

## 6. CDC Engine — pgoutput

```
PostgreSQL WAL → pgoutput (nativo PG10+) → Logical Replication Slot
→ BkernelEvent {
    app: "orangehrm", table: "hs_hr_employee",
    operation: INSERT|UPDATE|DELETE,
    old_row: Option<HashMap>, new_row: Option<HashMap>,
    lsn: u64, timestamp: i64, origin: Option<String>
  }
```

### Loop Prevention: pg_replication_origin

```sql
-- Antes de escribir:
SELECT pg_replication_origin_session_setup('bkernel');
INSERT INTO party_party ...;  -- marcado origin='bkernel'
-- CDC Engine filtra automáticamente eventos con origin='bkernel'
```

Solución nativa PostgreSQL, irrompible, sin condiciones en reglas.

## 7. Rule Engine — Forward-Chaining

### Rule Index O(1)

```
(orangehrm, hs_hr_employee, INSERT) → [OHRM-001, CROSS-001]
(tryton, product_product, UPDATE)   → [TRY-023, TRY-024]
(saleor, order_line, INSERT)        → [SAL-089, CROSS-031]
```

Matching O(1) para 95% de eventos (sin condición jq). Condiciones jq evaluadas solo cuando la regla las tiene.

Forward-chaining: acciones write generan nuevos eventos CDC → disparan otras reglas → cascada automática.

## 8. Formato Regla YAML Completo

```yaml
rule:
  id: "OHRM-001"
  name: "employee_to_tryton_party"
  version: "1.0.0"
  enabled: true
  priority: 50

  when:
    source: "orangehrm"
    table: "hs_hr_employee"
    operation: "INSERT, UPDATE"
    condition: '.new.emp_work_email != null'

  transform:
    - map:
        name: '"\(.new.emp_firstname) \(.new.emp_lastname)"'
        email: .new.emp_work_email
    - normalize: { field: email, to_lowercase: true }
    - lookup: { field: department_id, source: "orangehrm", table: "ohrm_subunit", key: "id", value: "name" }
    - validate: { field: email, regex: '^[a-zA-Z0-9._%+-]+@...', on_fail: "skip" }

  then:
    - action: "write"
      target: "tryton"
      table: "party.party"
      upsert_key: ["email"]
      idempotency: true
    - action: "notify"
      target: "redis"
      channel: "bkernel:events"
    - action: "enqueue"
      target: "bsearch"
      index: "employees"
    - action: "catalog"
      task: "update_entity_crossref"
    - action: "catalog"
      task: "enqueue_embedding"
      params: { queue: "ai:embed_queue", entity_type: "employee" }

  error_handling:
    max_retries: 3
    retry_delay_ms: [1000, 5000, 15000]
    on_max_retries: "dlq"
```

## 9. Writer Pool — Escritura Idempotente

UPSERT sobre clave de negocio con only_if_changed:

```sql
INSERT INTO party_party (name, email, type, active, bkernel_synced_at)
VALUES ('Juan Pérez', 'juan@empresa.com', 'employee', true, NOW())
ON CONFLICT (email)
DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, active=EXCLUDED.active
WHERE party_party.name != EXCLUDED.name
   OR party_party.type != EXCLUDED.type;
-- Si datos idénticos → no UPDATE → no evento WAL
```

Pool por destino:
```toml
[writers.tryton]
type = "postgres"
pool_size = 20

[writers.keycloak]
type = "http"
pool_size = 10

[writers.redis]
pool_size = 30
```

## 10. Task Catalog — Plugins

### Capa 1 — Core (compilados en binario)

| Tarea | Descripción |
|---|---|
| update_entity_crossref | orangehrm.42 ↔ tryton.1089 |
| log_audit_event | bkernel_db.audit_events con contexto KC |
| enqueue_search | Redis bkernel:index_queue → bSearch |
| enqueue_embedding | Redis ai:embed_queue → Qdrant |
| notify_bcompass | Trigger para workflow IA |

### Capa 2 — Externos (.so shared objects)

```rust
#[repr(C)]
pub struct BkernelPlugin {
    pub name: *const c_char,
    pub execute: extern "C" fn(ctx: *const BkernelEventContext, handles: *const BkernelHandles) -> BkernelResult,
    pub validate: extern "C" fn(handles: *const BkernelHandles) -> BkernelResult,
}
#[no_mangle]
pub extern "C" fn bkernel_plugin_init() -> *const BkernelPlugin { ... }
```

Plugins distribuidos: full_employee_migration, fiscal_year_close, customer_merge, new_company_bootstrap, realm_bootstrap, product_catalog_bulk_sync, offboarding_complete, salary_history_sync, chart_of_accounts_init.

Seguridad: firma Ed25519 obligatoria, validate() en startup, timeout 5s, DLQ si excede.

## 11. MDM Hub — Tryton como Fuente de Verdad

```
                    TRYTON (Hub MDM)
                    party_party, product_product, account_*
                         │
    ┌────────────────────┼────────────────────┐
    OrangeHRM         Saleor             EspoCRM
    (empleados)       (productos)        (contactos)
```

entity_crossref registra IDs cruzados: orangehrm.42 ↔ tryton.1089 ↔ keycloak.abc-123.

## 12. Fuentes de Verdad por Entidad

| Entidad | Sistema primario | Secundarios | Lag |
|---|---|---|---|
| Empleado (RRHH) | OrangeHRM | Tryton, KC, EspoCRM | <3s |
| Empleado (nómina) | Tryton | OrangeHRM | <3s |
| Cliente | EspoCRM | Tryton, Saleor | <3s |
| Producto (maestro) | Tryton | Saleor | <3s |
| Factura | Tryton | **No se proyecta** | N/A |
| Cuenta contable | Tryton | **No se proyecta** | N/A |
| Rol acceso | bos_bauth_template | KC, Tryton | <5s |
| Ticket | Zammad | EspoCRM | <3s |

Lag: evento → WAL → bkernel < 100ms. bkernel → escritura destino < 2s (p99). Total E2E < 3s p99.

## 13. Dead Letter Queue

```
Evento WAL → Rule Engine → Writer → OK → checkpoint
                                   → FAIL → Retry (1s, 5s, 15s)
                                            → max_retries → DLQ (PostgreSQL)
                                                           → Alerta admin
```

```sql
CREATE TABLE bkernel_dlq (
    id BIGSERIAL PRIMARY KEY,
    event_id UUID NOT NULL,
    rule_id VARCHAR(50) NOT NULL,
    event_data JSONB NOT NULL,
    error_message TEXT NOT NULL,
    retry_count INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pending',  -- pending|retrying|resolved|discarded
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

Gestión: `bosctl bkernel dlq list`, `retry <id>`, `retry-all --rule=OHRM-001`, `discard <id>`, `stats`.

## 14. bkernel_db — Esquema Completo

8 tablas (solo estado operacional, nunca datos de negocio):

| Tabla | Propósito |
|---|---|
| replication_state | LSN por slot, lag, eventos totales |
| sync_log | Sincronizaciones ejecutadas (particionada por fecha) |
| rule_execution_log | Evaluación de reglas (tiempos, condiciones) |
| conflict_log | Conflictos entre apps detectados |
| audit_events | Auditoría global ISO 27001 (particionada) |
| anomaly_events | Anomalías detectadas (severidad, notificación) |
| dead_letter_queue | Eventos fallidos para reintentar |
| entity_crossref | IDs cruzados entre apps (app_a.id_a ↔ app_b.id_b) |

## 15. Thread Pool y Rendimiento

```
PROCESO BKERNEL (PID único)
├── Hilo 0: WAL Reader (dedicado, alta prioridad)
├── Hilo 1: Rule Matcher / Dispatcher
├── Hilo 2: Monitor / Health / sd_notify watchdog
└── Worker Pool (N hilos, ajuste dinámico)
```

| Métrica | Valor |
|---|---|
| CPU 32 cores | 32 workers paralelos |
| Memoria RSS | < 512 MB |
| Throughput | 500K–1M eventos/s |
| Latencia p50 | < 2 ms |
| Latencia p99 | < 10 ms |
| Latencia p999 | < 50 ms |

## 16. Catálogo de Reglas Distribuidas

### Core (cross-app)

| ID | Source → Target | Evento |
|---|---|---|
| CORE-001 | OrangeHRM → Tryton + KC | INSERT hs_hr_employee |
| CORE-002 | OrangeHRM → Tryton + KC | UPDATE emp_status='terminated' |
| CORE-003 | Tryton → EspoCRM + Saleor | UPDATE party.party merge |
| CORE-004 | Tryton → Saleor | UPDATE product.list_price |
| CORE-005 | Saleor → Tryton | INSERT order status='confirmed' |
| CORE-006 | Tryton → Tryton | INSERT payment state='succeeded' |
| CORE-007 | Tryton → Redis bcompass | UPDATE stock < reorder_point |

### Por app: OHRM-001 a OHRM-003 (OrangeHRM), SALE-001 a SALE-004 (Saleor), ESPO-001/002 (EspoCRM), ZMMD-001/002 (Zammad)

## 17. Stack Tecnológico

| Componente | Crate/Herramienta | Propósito |
|---|---|---|
| Lenguaje | Rust 1.85+ (Edition 2024) | Daemon principal |
| Async runtime | tokio 1.x (rt-multi-thread) | Event loop WAL |
| WAL/CDC | pgwire-replication 0.2 | Wire protocol PG directo |
| PostgreSQL | tokio-postgres 0.7 | Control plane |
| Pool | deadpool-postgres 0.13 | Pool async escritura |
| Redis | redis-rs 0.25 (tokio) | Publicación eventos |
| Serialización | serde 1.x + serde_json | Eventos WAL |
| YAML | serde_yaml 0.9 | Reglas |
| Plugins .so | libloading 0.8 | Carga dinámica |
| Config | toml 0.8 | bkernel.toml |
| Logging | tracing + tracing-subscriber | Logs estructurados |
| Métricas | prometheus-client 0.22 | Puerto 9100 |
| Errores | anyhow + thiserror | Propagación ergonómica |
| Build | cargo --release (LTO=true, MUSL) | Binario estático |

### CI/CD

Format (cargo fmt) → Lint (clippy -D warnings) → Check → Test → Audit (cargo audit) → Build (cross MUSL) → Sign (ed25519)

## 18. Fronteras Inviolables

| Frontera | El bkernel NUNCA | Consecuencia si viola |
|---|---|---|
| D1 Cero Invasión | Modifica apps | Apps dejan de ser actualizables independientemente |
| D2 Solo WAL | Expone API REST | Superficie de ataque aumenta |
| D3 Solo Rust | Se compila como .jar o .py | Pierde latencia determinista |
| D4 Reglas declarativas | Hardcodea lógica de negocio | Pierde extensibilidad |
| D5 Solo PostgreSQL WAL | Escucha otros motores | Complejidad sin valor |
| D6 pg_replication_origin | Usa otro mecanismo anti-loop | Riesgo de loop infinito |
| D7 bkernel_db solo estado | Guarda datos de negocio | Mezcla responsabilidades |
| D8 bSearch separado | Indexa directamente | Acoplamiento |
| D9 bkAI no modifica reglas | Aplica sugerencias sin humano | Autonomía sin supervisión |
| D10 Cero ingesta externa | Importa CSV/Excel | biedata es para eso |

## 19. Posicionamiento vs Industria

| Producto | CDC | MDM | Rule Engine | Sin GC | Soberano | Cero Invasión |
|---|---|---|---|---|---|---|
| **bkernel** | ✅ | ✅ | ✅ | ✅ Rust | ✅ | ✅ |
| Debezium | ✅ | ❌ | ❌ | ❌ JVM | ✅ | ✅ |
| MuleSoft/Boomi | ❌ invasivo | Parcial | ✅ | ❌ JVM | ❌ SaaS | ❌ |
| Kafka+Flink | ✅ infra | ❌ | ❌ | ❌ JVM | ✅ | ✅ requiere código |

---

## §20 — ENRIQUECIMIENTO V5: bKernel v7.0 + DLQ + WAL Replay (SBOS-010)

### V5-1: Regla ROLF-001 para Sincronización de RolTemplate (desde SBOS-010 v7.0)

```yaml
rule:
  id:   "ROLF-001"
  when:
    source:    "bos_core"
    table:     "bos_bauth_template"
    operation: "INSERT, UPDATE"
  then:
    - action: "plugin"
      name:   "bauth_sync"
    - action: "catalog"
      task:   "log_audit_event"
```

El plugin `bauth_sync` es el punto de integración entre bKernel y bauth: bKernel detecta cambios en templates de identidad, bauth ejecuta la sincronización en Keycloak y Tryton.

### V5-2: WAL Replay Strategy — Arquitectura de Recuperación (desde SBOS-010-WAL-ReplayStrategy)

**Escenarios de recuperación:**

| Escenario | Trigger | Acción |
|---|---|---|
| bkernel detenido < 5 min | Reinicio normal | Retoma desde último LSN checkpointed |
| bkernel detenido > 5 min | Lag detectado | Replay de eventos desde checkpoint hasta NOW() |
| BD PostgreSQL reiniciada | Conexión WAL perdida | Reconexión automática con timeout exponencial |
| Slot de replicación eliminado | Error fatal | Crear nuevo slot + full re-index desde snapshot |

**Replay seguro:**
```rust
// En state::Manager:
fn recover(&mut self) -> Result<LSN> {
    let last_lsn = self.load_checkpoint()?;
    let current_lsn = self.get_current_wal_lsn()?;
    if current_lsn - last_lsn > RECOVERY_THRESHOLD {
        // Replay lento: batch de 100 eventos, pausa 100ms entre batches
        self.replay_events(last_lsn, current_lsn, 100, Duration::from_millis(100))?;
    }
    Ok(last_lsn)
}
```

**Idempotencia en replay:** todas las escrituras usan UPSERT con `only_if_changed`. Replay no duplica datos.

### V5-3: DLQ Completo (desde SBOS-010-001)

**Comandos bosctl para gestión de DLQ:**
```
bosctl bkernel dlq list [--status=pending|retrying|resolved|discarded] [--rule=OHRM-001] [--limit=50]
bosctl bkernel dlq retry <dlq_id>
bosctl bkernel dlq retry-all --rule=OHRM-001
bosctl bkernel dlq discard <dlq_id>
bosctl bkernel dlq stats
```

**Estadísticas DLQ:**
```json
{
  "total": 47,
  "by_status": { "pending": 23, "retrying": 5, "resolved": 15, "discarded": 4 },
  "by_rule": { "OHRM-001": 12, "TRY-023": 8 },
  "oldest": "2025-03-01T10:00:00Z",
  "avg_retries": 2.3
}
```

**Parámetros de retry por regla:**
```yaml
error_handling:
  max_retries: 3
  retry_delay_ms: [1000, 5000, 15000]
  on_max_retries: "dlq"        # dlq | skip | notify
  dlq_notification: "admin"     # admin | channel | both
```

### V5-4: Fronteras Extendidas desde V5

| Frontera | En V5 | En V6 |
|---|---|---|
| D11 | El bkernel no ejecuta plugins que requieren red externa | No explicitado en V6 |
| D12 | El bkernel no es un motor de workflows | bCompass es para eso |

---

## §21 — ENRIQUECIMIENTO V7: Correcciones y Extensiones

### V7-1: pg_replication_origin como estándar obligatorio

V7 confirma que `pg_replication_origin` es el mecanismo canónico anti-loop. No hay alternativa. Se formaliza el filtro:

```rust
fn should_process(event: &WalEvent) -> bool {
    // Filtrar eventos producidos por el propio bkernel
    if event.origin == Some("bkernel".to_string()) {
        return false;  // Loop prevention
    }
    if event.origin == Some("biedata".to_string()) {
        return true;   // Datos de importación externa
    }
    true
}
```

### V7-2: Conexión con Dominios Reconceptualizados

bKernel alimenta el modelo de 3 dominios:
- **LogicalDomainMask**: bKernel sincroniza datos entre apps que implementan una zona de negocio
- **PhysicalDomainMask**: bKernel detecta eventos de banexus (accesos físicos)
- **FinancialDomainMask**: bKernel propaga transacciones financieras entre Tryton y otros sistemas

### V7-3: Rule Index v2 — Prioridad y DAG

V7 introduce prioridad explícita + DAG de reglas para evitar dependencias circulares en forward-chaining:

```yaml
rule:
  id: "CORE-001"
  priority: 50     # Mayor número = mayor prioridad
  depends_on: []   # Reglas que deben ejecutarse antes
```

---

## ENRIQUECIMIENTO Smart* (V8)

### Smart*-1: Propagación de ctx_id en Eventos WAL (desde BOSCMS-B-01)

El Context Plane (ctx_id) se propaga a través de bKernel como parte integral del procesamiento de eventos CDC. Este es el mecanismo que permite trazar cada operación de datos hasta su sesión de origen.

**Proceso de 4 pasos + PASO 0:**

```
PASO 0 — VALIDACIÓN (antes de cualquier procesamiento)
  └── bKernel recibe evento WAL → verifica que ctx_id existe en context_sessions
  └── Si ctx_id NO existe en Redis Context Registry → REJECT + DLQ + alerta
  └── Si ctx_id OK → continúa con PASO 1

PASO 1 — Almacenamiento de metadatos de contexto
  └── bKernel inyecta ctx_id como metadata en cada escritura UPSERT
  └── Tablas destino reciben columna sbos_ctx_id cuando aplica

PASO 2 — bKernel reacciona según reglas YAML
  └── Cada regla evalúa el ctx_id del evento origen
  └── Reglas de routing multi-tenant usan ctx_id para dirigir a BD correcta

PASO 3 — Enrutamiento con contexto preservado
  └── Escrituras a destinos (Tryton, KC, Redis) incluyen ctx_id en metadata
  └── Fanout a bSearch y embeddings preservan ctx_id para trazabilidad

PASO 4 — Auditoría completa
  └── bkernel_db.audit_events incluye ctx_id en cada registro
  └── join con context_sessions permite reconstruir sesión completa
```

**Regla YAML para ctx_id (nueva regla de infraestructura):**
```yaml
rule:
  id: "CTX-001"
  name: "context_propagation"
  enabled: true
  priority: 100          # Máxima prioridad — ejecuta primero
  when:
    source: "*"
    table: "*"
    operation: "*"
  then:
    - action: "catalog"
      task: "validate_ctx_id"      # PASO 0 — validación antes de cualquier regla
    - action: "catalog"
      task: "store_context_metadata"  # Registra ctx_id en bkernel_db
```

**Integración con Kong para inyección de headers:**
```yaml
# Kong plugin configuration
plugins:
  - name: request-transformer
    config:
      add:
        headers:
          - "sbos-ctx-id:{ctx_id}"          # Header canónico
          - "baggage:sbos-ctx-id={ctx_id}"   # OpenTelemetry Baggage
          - "traceparent:{traceparent}"      # W3C Trace Context
```

### Smart*-2: BKERNEL en Flujo 3 (Híbrido) — Regla Completa (desde BOSCMS-B-04)

```yaml
rule:
  id: "CMS-F3-001"
  name: "flujo_hibrido_fulfillment"
  enabled: true
  priority: 70
  when:
    source: "tryton"
    table: "sale_order"
    operation: "UPDATE"
    condition: '.new.state == "confirmed" and .new.cms_flow == "hibrido"'
  then:
    - action: "write"
      target: "tryton"
      table: "stock_move"
      upsert_key: ["order_id", "product_id"]
      with_ctx_id: true
    - action: "catalog"
      task: "notify_bcompass"
      params:
        flow: "flujo_3_hibrido"
        ctx_validation: true       # PASO 0 obligatorio
```

**Comportamiento:** El pedido híbrido (parte pickup, parte delivery) se procesa en Tryton. bKernel detecta `state=confirmed` y genera los `stock_move` correspondientes. Cada movimiento incluye el ctx_id del checkout original, permitiendo al cliente ver el estado en tiempo real.

### Smart*-3: BKERNEL en Flujo 4 (BOPIS) — Regla Completa (desde BOSCMS-B-04)

```yaml
rule:
  id: "CMS-F4-001"
  name: "flujo_bopis_ready_for_pickup"
  enabled: true
  priority: 70
  when:
    source: "tryton"
    table: "stock_move"
    operation: "UPDATE"
    condition: '.new.state == "done" and .new.shop_id == .new.pickup_shop_id'
  then:
    - action: "write"
      target: "tryton"
      table: "sale_order"
      data:
        state: "ready_for_pickup"
      upsert_key: ["id"]
    - action: "notify"
      target: "redis"
      channel: "bkernel:events:cms"
      data:
        event_type: "order_ready_for_pickup"
    - action: "catalog"
      task: "send_customer_notification"
      params:
        channel: "email_push"
        template: "pickup_ready"
```

### Smart*-4: BKERNEL en Flujo 5 (MSI) — Regla Completa (desde BOSCMS-B-04)

```yaml
rule:
  id: "CMS-F5-001"
  name: "flujo_msi_credit_validation"
  enabled: true
  priority: 80
  when:
    source: "saleor"
    table: "order"
    operation: "UPDATE"
    condition: '.new.cms_flow == "msi" and .new.state == "awaiting_credit"'
  then:
    - action: "plugin"
      name: "credit_validation"
      params:
        credit_check: true
        ctx_id_required: true
    - action: "write"
      target: "tryton"
      table: "sale_order"
      data:
        credit_status: "pending"
      upsert_key: ["saleor_order_id"]
    - action: "catalog"
      task: "log_audit_event"
```

### Smart*-5: Cola Inteligente — Integración BKERNEL + Tryton (desde BOSCMS-C-06)

La cola inteligente de CMS se integra con bKernel mediante WAL para procesar pedidos en una secuencia FIFO con planificación:

```
CMS API (TypeScript) recibe pedido:
  └── POST /api/queue enqueue { order_id, ctx_id, ... }
      └── INSERT en tryton.queue_entry con sbos_ctx_id

bKernel detecta WAL en queue_entry:
  └── Regla CMS-Q-001: queue_entry.status = "pending" → procesar
      └── Evalúa time_slot: ¿está dentro de la ventana de entrega?
      └── Evalúa prioridad: ¿es MSI prioritario o pago contado?
      └── Evalúa ctx_id: ¿sesión del checkout sigue activa?

Cola completa → bKernel detecta UPDATE status="ready":
  └── Notifica vía Centrifugo al frontend del operador
  └── Trigger Flujo 2 (picking + packing)
```

**Endpoint TypeScript con ctx_id:**
```typescript
async function enqueueOrder(order: Order, ctx_id: string): Promise<void> {
    await db.query(
        `INSERT INTO queue_entry (order_id, status, sbos_ctx_id, estimated_time)
         VALUES ($1, 'pending', $2, $3)
         ON CONFLICT (order_id) DO NOTHING`,
        [order.id, ctx_id, estimateCompletion(order)]
    );
}
```

### Smart*-6: Checkout 5 Flujos — ctx_id como PASO 0 (desde BOSCMS-C-04)

El checkout detecta 5 flujos de pago y en todos ellos el ctx_id es el primer elemento validado:

```typescript
async function completeCheckout(ctx_id: string, orderId: string): Promise<void> {
    // PASO 0 — validación de contexto
    const ctx = await validateCtxId(ctx_id);
    if (!ctx.valid) throw new Error(`ctx_id inválido o expirado: ${ctx_id}`);

    // Detectar flujo de pago según productos y método
    const flow = detectPaymentFlow(order.line_flows, ctx);
    
    // Cada flujo preserva ctx_id en metadata
    const metadata = {
        ctx_id,
        line_flows: order.line_flows,
        detected_flow: flow,
        device_id: ctx.device_id,
        pos_logico: ctx.pos_logico
    };
    
    await bpay.createPayment({
        orderId,
        amount: order.total,
        metadata,
        ctx_id
    });
}
```

**Integración con bKernel:**
```
checkout completa → bpay procesa pago → Tryton recibe orden confirmada
  → bKernel detecta WAL en sale_order con ctx_id
  → bKernel propaga ctx_id a stock_move, invoice, payment
  → Todas las tablas involucradas tienen trazabilidad hasta el checkout original
```

---

## Trazabilidad V8

| Sección | Fuente |
|---|---|
| §1-19 (V6 completo) | BOS_V6_SBOS-023-DAEMON-BKERNEL.md |
| §20 V5-1 a V5-4 | BOS_V5_SBOS-010-BKERNEL-v7_0.md, BOS_V5_SBOS-010-001-DLQ-RULES-PROTOCOL-v1_0.md, BOS_V5_SBOS-010-WAL-ReplayStrategy-v1_0.md |
| §21 V7-1 a V7-3 | BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md, BOS_V7_SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md |
| Smart*-1 | Enriquecimiento Smart* V8 | BOSCMS-B-01-CTX-ID-BKERNEL.md |
| Smart*-2 a Smart*-4 | Enriquecimiento Smart* V8 | BOSCMS-B-04-BKERNEL-FLUJOS-3-4-5.md |
| Smart*-5 | Enriquecimiento Smart* V8 | BOSCMS-C-06-COLA-INTELIGENTE.md |
| Smart*-6 | Enriquecimiento Smart* V8 | BOSCMS-C-04-CHECKOUT-5-FLUJOS.md |

---

_SKULL · SBOS · SBOS-023-DAEMON-BKERNEL · HUMAN-DOC V8 ENRIQUECIDO · Mayo 2026_
