# SBOS-010-001
## Anexo: Catálogo de Reglas, DLQ y Protocolo bkernel↔Apps
### Especificación de Nivel de Código para el Data Kernel

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-010-001
**Complementa:** SBOS-010-BKERNEL-v7_0.md + SBOS-010-WAL-ReplayStrategy-v1_0.md
**Propósito:** Completar la especificación del bkernel al NIVEL 5 (listo para código) cubriendo los gaps identificados en SBOS-MP03 Etapa 2.

---

## 1. Catálogo Completo de Reglas por Aplicación

### 1.1 Reglas Core (cross-app)

| ID | Nombre | Source → Target | Evento | Prioridad |
|----|--------|-----------------|--------|-----------|
| CORE-001 | employee_onboarding | OrangeHRM → Tryton + Keycloak | INSERT en hs_hr_employee | 10 |
| CORE-002 | employee_offboarding | OrangeHRM → Tryton + Keycloak | UPDATE emp_status='terminated' | 10 |
| CORE-003 | customer_merge | Tryton → EspoCRM + Saleor | UPDATE en party.party con merge_target | 20 |
| CORE-004 | product_price_sync | Tryton → Saleor | UPDATE en product.product.list_price | 30 |
| CORE-005 | invoice_to_accounting | Saleor → Tryton | INSERT en order_order con status='confirmed' | 20 |
| CORE-006 | payment_reconciliation | Tryton → Tryton (cross-module) | INSERT en account.payment con state='succeeded' | 15 |
| CORE-007 | inventory_alert | Tryton → Redis (bcompass queue) | UPDATE stock.move cuando quantity < reorder_point | 40 |

### 1.2 Reglas OrangeHRM

| ID | Nombre | Evento | Acción |
|----|--------|--------|--------|
| OHRM-001 | employee_to_tryton_party | INSERT/UPDATE en hs_hr_employee | UPSERT en party.party |
| OHRM-002 | leave_to_tryton_attendance | INSERT en hs_hr_leave | INSERT en attendance.line |
| OHRM-003 | department_sync | INSERT/UPDATE en ohrm_subunit | UPSERT en company.department |

### 1.3 Reglas Saleor

| ID | Nombre | Evento | Acción |
|----|--------|--------|--------|
| SALE-001 | order_to_tryton_sale | INSERT en order_order status='confirmed' | INSERT en sale.sale |
| SALE-002 | product_stock_update | UPDATE en warehouse_stock | UPDATE en stock.move |
| SALE-003 | customer_to_tryton | INSERT en account_user | UPSERT en party.party |
| SALE-004 | refund_to_tryton | INSERT en order_fulfillmentreturn | INSERT en sale.return |

### 1.4 Reglas EspoCRM

| ID | Nombre | Evento | Acción |
|----|--------|--------|--------|
| ESPO-001 | contact_to_tryton | INSERT/UPDATE en contact | UPSERT en party.party |
| ESPO-002 | opportunity_to_tryton | UPDATE opportunity status='Won' | INSERT en sale.opportunity |

### 1.5 Reglas Zammad

| ID | Nombre | Evento | Acción |
|----|--------|--------|--------|
| ZMMD-001 | ticket_to_espocrm | INSERT en tickets | INSERT en EspoCRM case |
| ZMMD-002 | ticket_close_to_tryton | UPDATE ticket status='closed' | UPDATE service.contract |

### 1.6 Formato Completo de una Regla (todos los campos)

```yaml
rule:
  id: "OHRM-001"
  name: "employee_to_tryton_party"
  description: "Sincroniza empleados de OrangeHRM a party.party en Tryton"
  version: "1.0.0"
  enabled: true
  priority: 50                      # menor = mayor prioridad

  when:
    source: "orangehrm"             # app origen (nombre de la BD)
    table: "hs_hr_employee"         # tabla que dispara la regla
    operation: "INSERT, UPDATE"     # INSERT | UPDATE | DELETE | ALL
    condition: '.new.emp_work_email != null'  # jq expression sobre el evento

  transform:
    - map:                          # mapeo de campos
        name: '"\(.new.emp_firstname) \(.new.emp_lastname)"'
        email: .new.emp_work_email
        type: '"employee"'
        vat_code: .new.emp_tax_id
    - normalize:                    # normalización
        field: email
        to_lowercase: true
    - lookup:                       # lookup en otra tabla
        field: department_id
        source: "orangehrm"
        table: "ohrm_subunit"
        key: "id"
        value: "name"
    - validate:                     # validación pre-escritura
        field: email
        regex: '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        on_fail: "skip"             # skip | dlq | abort

  then:
    - action: "write"
      target: "tryton"
      table: "party.party"
      upsert_key: ["email"]
      idempotency: true             # UPSERT en vez de INSERT
    - action: "notify"
      target: "redis"
      channel: "bkernel:events"
      payload: '{"type":"employee_synced","id":.new.emp_number}'
    - action: "enqueue"
      target: "bsearch"
      index: "employees"
      document_id: .new.emp_number

  error_handling:
    max_retries: 3
    retry_delay_ms: [1000, 5000, 15000]   # exponential backoff
    on_max_retries: "dlq"                  # dlq | skip | abort
    dlq_topic: "bkernel:dlq:ohrm-001"

  metadata:
    author: "SKULL Team"
    created_at: "2026-03-14"
    tags: ["hr", "employee", "tryton"]
```

---

## 2. Dead Letter Queue (DLQ)

### 2.1 Arquitectura

```
Evento WAL
  │
  ├── Rule Engine match → acción
  │     │
  │     ├── Writer ejecuta → OK → checkpoint LSN
  │     │
  │     └── Writer falla → Retry Manager
  │           │
  │           ├── Retry 1 (1s delay) → OK → checkpoint
  │           ├── Retry 2 (5s delay) → OK → checkpoint
  │           ├── Retry 3 (15s delay) → FAIL
  │           │
  │           └── DLQ → bkernel_dlq (tabla PostgreSQL)
  │                 │
  │                 ├── Alerta a admin (Redis → WebSocket → Core UI)
  │                 └── Evento queda en DLQ hasta resolución manual
  │
  └── Evento sin reglas → descartado (log debug, no DLQ)
```

### 2.2 Tabla DLQ en PostgreSQL

```sql
CREATE TABLE bkernel_dlq (
    id              BIGSERIAL PRIMARY KEY,
    event_id        UUID NOT NULL,
    rule_id         VARCHAR(50) NOT NULL,
    source_table    VARCHAR(200) NOT NULL,
    operation       VARCHAR(10) NOT NULL,
    event_data      JSONB NOT NULL,
    error_message   TEXT NOT NULL,
    error_code      VARCHAR(50),
    retry_count     INT DEFAULT 0,
    max_retries     INT DEFAULT 3,
    first_failure   TIMESTAMPTZ DEFAULT NOW(),
    last_retry      TIMESTAMPTZ,
    status          VARCHAR(20) DEFAULT 'pending',  -- pending | retrying | resolved | discarded
    resolved_at     TIMESTAMPTZ,
    resolved_by     VARCHAR(100),
    resolution_note TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_dlq_status ON bkernel_dlq(status);
CREATE INDEX idx_dlq_rule ON bkernel_dlq(rule_id);
```

### 2.3 Comandos de gestión DLQ

```bash
bosctl bkernel dlq list                    # listar eventos en DLQ
bosctl bkernel dlq list --rule=OHRM-001    # filtrar por regla
bosctl bkernel dlq retry <event_id>        # reintentar un evento
bosctl bkernel dlq retry-all --rule=OHRM-001  # reintentar todos de una regla
bosctl bkernel dlq discard <event_id>      # descartar (marcar como resuelto)
bosctl bkernel dlq stats                   # estadísticas de DLQ
```

---

## 3. Protocolo bkernel ↔ Tryton

### 3.1 Mecanismo de escritura

El bkernel escribe en Tryton mediante **SQL directo** usando el Writer Pool con conexiones de pool dedicadas. No usa la API XML-RPC de Tryton porque:

1. XML-RPC añade latencia de serialización/deserialización
2. XML-RPC no permite UPSERT nativo
3. El bkernel necesita control transaccional completo (BEGIN/COMMIT/ROLLBACK)

```rust
// Writer Pool para Tryton
impl TrytonWriter {
    async fn upsert(&self, table: &str, data: &Value, upsert_key: &[String]) -> Result<()> {
        let conn = self.pool.get().await?;
        
        // UPSERT idempotente usando ON CONFLICT
        let sql = format!(
            "INSERT INTO {} ({}) VALUES ({}) ON CONFLICT ({}) DO UPDATE SET {}",
            table,
            columns.join(", "),
            placeholders.join(", "),
            upsert_key.join(", "),
            update_set.join(", ")
        );
        
        // pg_replication_origin para evitar loop infinito
        conn.execute("SELECT pg_replication_origin_session_setup('bkernel')", &[]).await?;
        conn.execute(&sql, &params).await?;
        conn.execute("SELECT pg_replication_origin_session_reset()", &[]).await?;
        
        Ok(())
    }
}
```

### 3.2 Prevención del loop infinito

Cuando bkernel escribe en Tryton, esa escritura genera un nuevo evento WAL. Sin protección, el bkernel lo detectaría como un cambio nuevo y ejecutaría reglas sobre él — loop infinito.

**Solución:** `pg_replication_origin` (nativo de PostgreSQL 10+)

```
1. bkernel registra un origen de replicación: 'bkernel'
2. Antes de escribir: pg_replication_origin_session_setup('bkernel')
3. Escribe en Tryton
4. Después de escribir: pg_replication_origin_session_reset()
5. Al leer WAL: filtra eventos con origin = 'bkernel'
6. Resultado: bkernel ignora sus propias escrituras
```

### 3.3 Manejo de Tryton caído

```
bkernel detecta timeout en Writer Pool (> 5s)
  │
  ├── Marcar Writer Pool de Tryton como "degraded"
  ├── Eventos destinados a Tryton van a retry queue (Redis)
  ├── Health check cada 10s: intenta reconectar
  │
  ├── Tryton vuelve:
  │     ├── Marcar Writer Pool como "healthy"
  │     ├── Drenar retry queue en orden
  │     └── Log: "Tryton recovered, N events replayed"
  │
  └── Tryton no vuelve en 5 min:
        ├── Eventos de retry queue → DLQ
        ├── Alerta crítica al admin
        └── bkernel sigue procesando reglas de otras apps
```

---

## 4. Redis como Bus de Eventos

### 4.1 Canales Redis

```
bkernel:events                  → Todos los eventos procesados (para monitoreo)
bkernel:events:<app>            → Eventos por aplicación (para suscriptores específicos)
bkernel:dlq:<rule_id>           → Notificaciones de DLQ
bkernel:health                  → Heartbeat del bkernel (cada 10s)
bkernel:metrics                 → Métricas agregadas cada minuto
bsearch:index_queue             → Cola para reindexación de bSearch
bcompass:analysis_queue          → Cola para análisis de bCompass
```

### 4.2 Formato de evento en Redis

```json
{
  "event_id": "uuid",
  "source": "orangehrm",
  "table": "hs_hr_employee",
  "operation": "INSERT",
  "lsn": "0/1A2B3C4D",
  "timestamp": "2026-03-14T10:30:00Z",
  "data": {
    "old": null,
    "new": { "emp_number": 123, "emp_firstname": "María", "emp_lastname": "García" }
  },
  "rules_matched": ["OHRM-001"],
  "actions_executed": [
    { "rule": "OHRM-001", "target": "tryton", "result": "ok", "duration_ms": 12 }
  ]
}
```

---

## 5. Integración con SBOS-010-WAL-ReplayStrategy

La estrategia de replay WAL documentada en SBOS-010-WAL se integra con el DLQ:

```
Escenario: bkernel se reinicia después de un crash
  │
  ├── Lee último LSN del checkpoint en bkernel_state
  ├── Conecta al replication slot (que retuvo los WAL no confirmados)
  ├── Re-procesa desde el último LSN confirmado
  │
  ├── Idempotencia: todas las escrituras usan UPSERT (ON CONFLICT)
  │   → reprocesar el mismo evento produce el mismo resultado
  │
  └── DLQ: eventos que fallaron antes del crash siguen en la tabla DLQ
        → el admin puede reintentarlos con bosctl bkernel dlq retry-all
```

---

## 6. Métricas Prometheus del bkernel

```
# Contadores
bkernel_events_received_total{source="orangehrm"}
bkernel_events_processed_total{source="orangehrm", rule="OHRM-001"}
bkernel_events_failed_total{source="orangehrm", rule="OHRM-001"}
bkernel_dlq_events_total{rule="OHRM-001"}
bkernel_writes_total{target="tryton"}

# Histogramas
bkernel_event_processing_duration_seconds{rule="OHRM-001"}
bkernel_write_duration_seconds{target="tryton"}

# Gauges
bkernel_replication_lag_bytes
bkernel_dlq_pending_count
bkernel_writer_pool_active{target="tryton"}
bkernel_rules_loaded_count
```

---

## 7. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Catálogo de 16 reglas por aplicación con formato completo, arquitectura DLQ con tabla PostgreSQL y comandos de gestión, protocolo bkernel↔Tryton con prevención de loop infinito via pg_replication_origin, Redis como bus de eventos con formato de mensajes, integración con replay WAL, y métricas Prometheus.

---

*SKULL · SBOS · SBOS-010-001 · Anexo 001 · v1.0 · Marzo 2026*
