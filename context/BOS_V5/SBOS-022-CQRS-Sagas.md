# SBOS-022-EXT — CQRS Formal y Patrones Saga Cross-Bounded-Context
## Extensión de SBOS-022 — Bounded Contexts y Modelo de Mensajería

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-022-EXT-CQRS
**Versión:** 1.0
**Estado:** ACTIVO
**Extiende:** SBOS-022-BoundedContexts-v1_0
**Clasificación:** Especificación Técnica — Arquitectura de Dominios

---

## Índice

1. [CQRS implícito del bKernel — documentación formal](#1-cqrs-implicito)
2. [Garantías de consistencia eventual](#2-garantias-consistencia-eventual)
3. [Modelos de lectura optimizados — proyecciones materializadas](#3-modelos-de-lectura)
4. [Patrones Saga cross-bounded-context](#4-patrones-saga)
5. [Ejemplo completo: Onboarding de empleado nuevo](#5-saga-onboarding-empleado)
6. [Ejemplo completo: Cierre de factura y actualización de CRM](#6-saga-factura-crm)
7. [Tabla de garantías por tipo de transacción](#7-tabla-de-garantias)

---

## 1. CQRS Implícito del bKernel — Documentación Formal

### 1.1 Qué es CQRS en el contexto de SBOS

CQRS (Command Query Responsibility Segregation) es el patrón arquitectónico que separa las operaciones de escritura (comandos) de las operaciones de lectura (consultas), permitiendo optimizar cada lado de forma independiente.

En SBOS, **el bKernel implementa CQRS implícito** sin que las aplicaciones lo sepan ni lo requieran. Las aplicaciones solo hacen escrituras SQL normales en sus propias bases de datos. El bKernel observa esas escrituras vía WAL y produce modelos de lectura optimizados de forma asíncrona.

### 1.2 Arquitectura CQRS en SBOS

```
LADO DE ESCRITURA (COMANDOS)
══════════════════════════════════════════════════════════════
  Usuario → App (OrangeHRM/Tryton/Saleor) → SQL INSERT/UPDATE/DELETE
                                              ↓
                                         PostgreSQL WAL
                                         (log de eventos — inmutable)
                                              ↓
══════════════════════════════════════════════════════════════
PROCESAMIENTO (bKernel — daemon soberano del host)
══════════════════════════════════════════════════════════════
                                         bKernel CDC Engine
                                         lee WAL via slot pgoutput
                                              ↓
                                         Rule Engine (YAML)
                                         evalúa qué reglas aplican
                                              ↓
                                         Writer Pool (idempotente)
                                         escribe en destinos configurados
                                              ↓
══════════════════════════════════════════════════════════════
LADO DE LECTURA (PROYECCIONES)
══════════════════════════════════════════════════════════════
                                    Tablas de proyección en PostgreSQL
                                    (actualizadas por bKernel)
                                              ↓
                              Apps leen directamente via SQL
                              (misma BD, sin overhead de red)
```

### 1.3 Terminología CQRS en SBOS

| Término CQRS | Equivalente en SBOS | Descripción |
|---|---|---|
| **Comando** | SQL INSERT/UPDATE/DELETE de una aplicación | La aplicación modifica su estado. Esto es el comando. |
| **Event Log** | WAL de PostgreSQL (`wal_level=logical`) | El WAL es el registro inmutable de todos los comandos ejecutados. |
| **Event** | Fila del WAL decodificada por pgoutput | Cada cambio en la BD es un evento. |
| **Proyector** | bKernel Rule Engine + Writer Pool | Aplica las reglas y produce las proyecciones. |
| **Proyección / Read Model** | Tabla materializada en PostgreSQL | El modelo de lectura optimizado para las consultas frecuentes. |
| **Consistencia eventual** | Lag WAL del bKernel (SLO: < 500ms P99) | Las proyecciones se actualizan en < 500ms tras el comando. |

### 1.4 Principio de no invasión (cero modificaciones a las aplicaciones)

El CQRS del bKernel es no invasivo por diseño. Las aplicaciones del stack (Tryton, OrangeHRM, Saleor, etc.) no saben que:

1. Su WAL está siendo observado
2. Sus escrituras producen proyecciones en otras tablas
3. Existen modelos de lectura derivados de sus datos

Esta propiedad permite añadir o modificar proyecciones sin tocar el código de ninguna aplicación — solo añadiendo o modificando reglas YAML en `/etc/bos/blibs/bkernel/rules/`.

---

## 2. Garantías de Consistencia Eventual

### 2.1 El modelo at-least-once y la idempotencia

El bKernel garantiza **at-least-once delivery**: cada evento del WAL será procesado al menos una vez. En caso de fallo antes del checkpoint, el evento se procesará de nuevo al reiniciar.

La idempotencia está implementada en el Writer Pool mediante la tabla `bkernel_db.processed_events`:

```sql
-- Estructura de la tabla de idempotencia
CREATE TABLE bkernel_db.processed_events (
  event_id    UUID PRIMARY KEY,           -- ID único del evento WAL
  processed_at TIMESTAMPTZ NOT NULL,      -- Cuándo fue procesado
  source_lsn  PG_LSN NOT NULL,            -- LSN del evento en el WAL
  source_app  TEXT NOT NULL,              -- Aplicación origen
  rule_name   TEXT NOT NULL,              -- Regla que lo procesó
  destination TEXT NOT NULL               -- Destino de la escritura
);

-- El Writer Pool verifica antes de escribir:
-- IF EXISTS (SELECT 1 FROM processed_events WHERE event_id = $1)
--   THEN SKIP (ya procesado — idempotencia garantizada)
-- ELSE
--   INSERT INTO destino ... + INSERT INTO processed_events ...
--   (atómico via transacción)
```

### 2.2 SLO de consistencia eventual

El lag máximo entre un comando (escritura en la aplicación) y su proyección actualizada es el **bKernel WAL lag**:

| Percentil | SLO objetivo | Cuándo se viola |
|---|---|---|
| P50 | < 50ms | Nunca en condiciones normales |
| P95 | < 200ms | Solo bajo carga alta sostenida |
| P99 | < 500ms | Solo en eventos de burst extremo |
| P99.9 | < 2s | Solo en caso de restart del bKernel |

Métrica de monitoreo: `bkernel_wal_lag_seconds` en Prometheus (S12 monitorserver).
Alerta configurada en SBOS-024: `WALReplicationLagCritical` dispara si lag > 500ms por > 5 minutos.

### 2.3 Cuándo la consistencia eventual NO es aceptable

Algunas operaciones en SBOS requieren consistencia fuerte (lectura inmediata del dato escrito). En esos casos, la aplicación debe leer de su propia base de datos (la fuente de verdad), **no de la proyección**:

| Operación | Modelo correcto | Razón |
|---|---|---|
| Confirmar una factura en Tryton | Leer de `tryton_db` directamente | La factura acaba de ser creada — la proyección no existe aún |
| Verificar el saldo disponible antes de aprobar un pago | Leer de `tryton_db` directamente | Requiere el dato más reciente — no puede haber lag |
| Crear un empleado en OrangeHRM | Leer de `orangehrm_db` para confirmación | El empleado debe existir antes de continuar el flujo |
| Buscar empleados en el Core UI | Leer de la proyección `active_employees_with_roles` | No es crítico tener el dato más reciente — consistencia eventual es aceptable |
| Dashboard de facturas abiertas | Leer de la proyección `dashboard_invoices_open` | Datos de reporting — 500ms de lag es aceptable |

---

## 3. Modelos de Lectura Optimizados — Proyecciones Materializadas

Las proyecciones son tablas en `bkernel_db` que el bKernel mantiene actualizadas a partir de los eventos WAL. Las aplicaciones pueden leer de ellas directamente via SQL — están en el mismo servidor PostgreSQL (S01 dataserver), por lo que el overhead de red es cero.

### 3.1 Proyección: `dashboard_invoices_open` (BC-01 Finanzas)

**Propósito:** Dashboard de facturas abiertas con datos de cliente desnormalizados. Tryton almacena facturas y clientes en tablas separadas con JOINs complejos. Esta proyección pre-materializa la vista más consultada.

**Regla YAML que la mantiene:**

```yaml
# /etc/bos/blibs/bkernel/rules/tryton/invoice_dashboard_projection.yml

rule:
  name: "update_dashboard_invoices_open"
  version: "1.2"
  description: "Proyección materializada de facturas abiertas con cliente desnormalizado"

  trigger:
    - source: tryton_db
      table: account_invoice
      operations: [INSERT, UPDATE, DELETE]

  conditions:
    - field: "state"
      operator: "in"
      values: ["draft", "validated", "posted"]

  actions:
    - type: upsert
      destination: bkernel_db
      table: dashboard_invoices_open
      key_column: invoice_id
      mapping:
        invoice_id:     "NEW.id"
        invoice_number: "NEW.number"
        invoice_date:   "NEW.invoice_date"
        amount_total:   "NEW.amount_total"
        currency_code:  "NEW.currency_symbol"
        state:          "NEW.state"
        due_date:       "NEW.payment_term_date"
        # Datos del cliente desnormalizados (evita JOIN en el dashboard)
        customer_name:  "LOOKUP(party_party, id=NEW.party, field=name)"
        customer_tax_id: "LOOKUP(party_party, id=NEW.party, field=vat_number)"
        # Datos del usuario que la creó (desde Keycloak via bKernel crossref)
        created_by:     "NEW.create_uid_keycloak_email"

    - type: delete_if
      condition: "NEW.state = 'cancelled' OR OPERATION = 'DELETE'"
      destination: bkernel_db
      table: dashboard_invoices_open
      where: "invoice_id = NEW.id"
```

**Esquema de la tabla proyectada:**

```sql
CREATE TABLE bkernel_db.dashboard_invoices_open (
  invoice_id      INTEGER PRIMARY KEY,
  invoice_number  VARCHAR(20),
  invoice_date    DATE,
  amount_total    NUMERIC(18,2),
  currency_code   VARCHAR(3),
  state           VARCHAR(20),
  due_date        DATE,
  customer_name   VARCHAR(200),
  customer_tax_id VARCHAR(50),
  created_by      VARCHAR(200),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_invoices_open_state ON bkernel_db.dashboard_invoices_open(state);
CREATE INDEX idx_invoices_open_due ON bkernel_db.dashboard_invoices_open(due_date);
```

### 3.2 Proyección: `active_employees_with_roles` (BC-02 RRHH)

**Propósito:** Vista de empleados activos con sus roles de Keycloak desnormalizados. La aplicación de RRHH (OrangeHRM) y el sistema de identidad (Keycloak) almacenan datos separados. Esta proyección une ambas fuentes.

**Regla YAML que la mantiene:**

```yaml
# /etc/bos/blibs/bkernel/rules/cross_app/employee_identity_projection.yml

rule:
  name: "update_active_employees_with_roles"
  version: "1.0"

  trigger:
    - source: orangehrm_db
      table: hs_hr_employee
      operations: [INSERT, UPDATE, DELETE]
    - source: keycloak_db
      table: user_role_mapping
      operations: [INSERT, DELETE]

  conditions:
    - field: "emp_work_status"
      operator: "eq"
      value: "Active"

  actions:
    - type: upsert
      destination: bkernel_db
      table: active_employees_with_roles
      key_column: employee_id
      mapping:
        employee_id:        "ORANGEHRM.emp_number"
        full_name:          "CONCAT(ORANGEHRM.emp_firstname, ' ', ORANGEHRM.emp_lastname)"
        email:              "ORANGEHRM.emp_work_email"
        department:         "LOOKUP(ohrm_department, id=ORANGEHRM.department_id, field=name)"
        job_title:          "LOOKUP(ohrm_job_title, id=ORANGEHRM.job_title_code, field=jobTitleName)"
        keycloak_user_id:   "CROSSREF(orangehrm_db.emp_number → keycloak_db.user_entity.id)"
        keycloak_roles:     "ARRAY_AGG(KEYCLOAK.role_name)"
        contract_end_date:  "ORANGEHRM.term_date"

    - type: delete_if
      condition: "ORANGEHRM.emp_work_status != 'Active' OR OPERATION = 'DELETE'"
      destination: bkernel_db
      table: active_employees_with_roles
      where: "employee_id = ORANGEHRM.emp_number"
```

### 3.3 Proyección: `product_catalog_availability` (BC-03 Ventas)

**Propósito:** Catálogo de productos con disponibilidad de stock en tiempo real, combinando datos de Saleor (catálogo/precios) con datos de inventario de Tryton.

**Regla YAML que la mantiene:**

```yaml
# /etc/bos/blibs/bkernel/rules/cross_app/product_catalog_projection.yml

rule:
  name: "update_product_catalog_availability"
  version: "1.1"

  trigger:
    - source: saleor_db
      table: product_product
      operations: [INSERT, UPDATE]
    - source: tryton_db
      table: stock_quantity
      operations: [UPDATE]

  actions:
    - type: upsert
      destination: bkernel_db
      table: product_catalog_availability
      key_column: product_sku
      mapping:
        product_sku:        "SALEOR.sku"
        product_name:       "SALEOR.name"
        price_sale:         "SALEOR.price_amount"
        currency:           "SALEOR.currency"
        is_available:       "SALEOR.is_available"
        stock_quantity:     "LOOKUP(tryton_db.stock_quantity, product_sku=SALEOR.sku, field=quantity)"
        stock_status:       "CASE WHEN stock_quantity > 0 THEN 'in_stock' ELSE 'out_of_stock' END"
        last_updated:       "NOW()"
```

---

## 4. Patrones Saga Cross-Bounded-Context

### 4.1 Por qué Sagas en lugar de transacciones distribuidas

Las transacciones distribuidas (2PC — Two-Phase Commit) entre bounded contexts son arquitectónicamente problemáticas en SBOS:

- Crean acoplamiento temporal entre contextos independientes
- Requieren un coordinador central que puede convertirse en SPOF
- Son incompatibles con el principio de autonomía de cada bounded context

El patrón **Saga** resuelve el mismo problema mediante secuencias de transacciones locales con **compensaciones** (acciones de reversión si una etapa falla).

### 4.2 Sagas en SBOS: el bKernel como orquestador

En SBOS, el bKernel actúa como orquestador de Sagas mediante su Rule Engine. Cada paso de la Saga es una regla YAML. Si un paso falla, el Rule Engine dispara la regla de compensación correspondiente.

```
Saga en SBOS:

Evento WAL (trigger)
       ↓
bKernel Rule Engine evalúa reglas
       ↓
Paso 1: escritura en BD de destino A
       ↓ (si OK)
Paso 2: escritura en BD de destino B
       ↓ (si FALLO en paso 2)
Compensación 1: revertir la escritura en BD A
       ↓
Emitir evento de fallo de Saga a bkernel_db.saga_events
```

### 4.3 Tabla de estado de Sagas en bkernel_db

```sql
CREATE TABLE bkernel_db.saga_state (
  saga_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  saga_name      TEXT NOT NULL,           -- ej: "employee_onboarding"
  trigger_event  TEXT NOT NULL,           -- ej: "orangehrm.employee.created"
  trigger_entity_id INTEGER NOT NULL,     -- ID de la entidad que disparó la Saga
  current_step   INTEGER NOT NULL DEFAULT 1,
  total_steps    INTEGER NOT NULL,
  status         TEXT NOT NULL DEFAULT 'in_progress',  -- in_progress | completed | compensating | failed
  started_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at   TIMESTAMPTZ,
  error_details  JSONB
);

CREATE TABLE bkernel_db.saga_step_log (
  id             BIGSERIAL PRIMARY KEY,
  saga_id        UUID REFERENCES bkernel_db.saga_state(saga_id),
  step_number    INTEGER NOT NULL,
  step_name      TEXT NOT NULL,
  status         TEXT NOT NULL,   -- pending | completed | compensated | failed
  executed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  compensation_executed_at TIMESTAMPTZ,
  details        JSONB
);
```

---

## 5. Ejemplo Completo: Saga de Onboarding de Empleado Nuevo

### 5.1 Descripción del flujo

Cuando un nuevo empleado es contratado en OrangeHRM, deben ocurrir de forma coordinada varias acciones en diferentes bounded contexts:

1. **BC-02 RRHH** → OrangeHRM: empleado creado (fuente de verdad)
2. **BC-04 Identidad** → Keycloak: usuario creado con roles apropiados
3. **BC-05 Comunicaciones** → Postfix + Mattermost: buzón de correo y canal creados
4. **BC-01 Finanzas** → Tryton: party.party creado (para nómina)
5. **BC-02 RRHH** → OrangeHRM: keycloak_user_id vinculado al empleado (cierre del loop)

Si algún paso falla, las acciones de los pasos anteriores deben ser compensadas.

### 5.2 Reglas YAML de la Saga

```yaml
# /etc/bos/blibs/bkernel/rules/cross_app/employee_onboarding.yml

saga:
  name: "employee_onboarding"
  version: "2.0"
  description: "Saga de onboarding completo de empleado nuevo across bounded contexts"
  total_steps: 5
  timeout_minutes: 10   # Si la Saga no completa en 10 min → compensar automáticamente

  trigger:
    source: orangehrm_db
    table: hs_hr_employee
    operation: INSERT
    condition: "NEW.emp_work_status = 'Active'"

  steps:

    - step: 1
      name: "create_keycloak_user"
      description: "Crear usuario en Keycloak (BC-04 Identidad)"
      action:
        type: keycloak_api
        endpoint: "POST /admin/realms/{realm}/users"
        payload:
          username:   "{NEW.emp_work_email}"
          email:      "{NEW.emp_work_email}"
          firstName:  "{NEW.emp_firstname}"
          lastName:   "{NEW.emp_lastname}"
          enabled:    true
          attributes:
            bos_employee_id: "{NEW.emp_number}"
            bos_department:  "{NEW.department_name}"
        capture_response:
          keycloak_user_id: "response.headers.Location | extract_id()"

      compensation:
        description: "Eliminar usuario de Keycloak si pasos posteriores fallan"
        type: keycloak_api
        endpoint: "DELETE /admin/realms/{realm}/users/{keycloak_user_id}"

    - step: 2
      name: "assign_keycloak_roles"
      description: "Asignar roles según departamento (SBOS Auth Enforce)"
      depends_on: [1]
      action:
        type: keycloak_api
        endpoint: "POST /admin/realms/{realm}/users/{keycloak_user_id}/role-mappings/clients/{client_id}"
        payload:
          roles: "{LOOKUP(bos_role_mapping, department=NEW.department_name)}"

      compensation:
        description: "Revocar roles asignados"
        type: keycloak_api
        endpoint: "DELETE /admin/realms/{realm}/users/{keycloak_user_id}/role-mappings"

    - step: 3
      name: "create_mailbox_and_channel"
      description: "Crear buzón Postfix + canal Mattermost (BC-05 Comunicaciones)"
      depends_on: [1]
      parallel: true   # Puede ejecutarse en paralelo con step 4
      action:
        type: task
        task_name: "create_employee_communications"
        params:
          email:     "{NEW.emp_work_email}"
          fullname:  "{NEW.emp_firstname} {NEW.emp_lastname}"
          team_id:   "{LOOKUP(mattermost_teams, department=NEW.department_name, field=team_id)}"

      compensation:
        type: task
        task_name: "delete_employee_communications"
        params:
          email: "{NEW.emp_work_email}"

    - step: 4
      name: "create_tryton_party"
      description: "Crear party.party en Tryton ERP para nómina (BC-01 Finanzas)"
      depends_on: [1]
      parallel: true   # En paralelo con step 3
      action:
        type: sql_write
        destination: tryton_db
        table: party_party
        mapping:
          name:           "{NEW.emp_firstname} {NEW.emp_lastname}"
          tax_identifier: "{NEW.emp_ssn_num}"
          is_employee:    true
          orangehrm_id:   "{NEW.emp_number}"

      compensation:
        type: sql_write
        operation: DELETE
        destination: tryton_db
        table: party_party
        where: "orangehrm_id = {NEW.emp_number}"

    - step: 5
      name: "link_keycloak_id_in_orangehrm"
      description: "Vincular keycloak_user_id en OrangeHRM (cierre del loop)"
      depends_on: [2, 3, 4]   # Espera a que todos los pasos anteriores completen
      action:
        type: sql_write
        destination: orangehrm_db
        table: hs_hr_employee
        operation: UPDATE
        set:
          keycloak_user_id: "{saga_context.keycloak_user_id}"
        where: "emp_number = {NEW.emp_number}"

  on_saga_completed:
    - type: event_emit
      event: "sbos.saga.employee_onboarding.completed"
      payload:
        employee_id:     "{NEW.emp_number}"
        keycloak_user_id: "{saga_context.keycloak_user_id}"

  on_saga_failed:
    - type: event_emit
      event: "sbos.saga.employee_onboarding.failed"
      payload:
        employee_id: "{NEW.emp_number}"
        failed_step: "{saga_context.failed_step}"
    - type: notification
      channel: "#hr-alerts"
      message: "⚠️ Onboarding fallido para empleado {NEW.emp_firstname} {NEW.emp_lastname}. Requiere intervención manual."
```

### 5.3 Cómo el bKernel detecta el fallo de un paso

El bKernel detecta fallos mediante:

1. **Respuesta de error de la API** (para llamadas a Keycloak API): HTTP 4xx/5xx
2. **Excepción en escritura SQL**: constraint violation, connection timeout
3. **Timeout del paso**: si el paso no completa en `step.timeout_seconds` (default: 30s)

Ante cualquier fallo, el bKernel:
1. Registra el fallo en `bkernel_db.saga_step_log`
2. Actualiza `bkernel_db.saga_state.status = 'compensating'`
3. Ejecuta las compensaciones de todos los pasos ya completados, en orden inverso
4. Emite el evento `on_saga_failed`

---

## 6. Ejemplo Completo: Saga de Factura → CRM

### 6.1 Descripción del flujo

Cuando Tryton confirma una factura (`tryton.invoice.confirmed`), el CRM (EspoCRM) debe actualizar el estado de la oportunidad de venta correspondiente, y el cliente debe recibir una notificación por email.

```yaml
# /etc/bos/blibs/bkernel/rules/cross_app/invoice_crm_sync.yml

saga:
  name: "invoice_confirmed_to_crm"
  version: "1.0"
  total_steps: 3

  trigger:
    source: tryton_db
    table: account_invoice
    operation: UPDATE
    condition: "NEW.state = 'posted' AND OLD.state != 'posted'"

  steps:

    - step: 1
      name: "update_espocrm_opportunity"
      action:
        type: sql_write
        destination: espocrm_db
        table: opportunity
        operation: UPDATE
        set:
          stage:          "Closed Won"
          close_date:     "{NEW.invoice_date}"
          amount:         "{NEW.amount_total}"
          invoice_number: "{NEW.number}"
        where: "tryton_invoice_id = {NEW.id}"

      compensation:
        type: sql_write
        destination: espocrm_db
        table: opportunity
        operation: UPDATE
        set:
          stage:          "Negotiation"
          invoice_number: null
        where: "tryton_invoice_id = {NEW.id}"

    - step: 2
      name: "send_invoice_email"
      description: "Enviar factura por email al cliente via Postfix"
      depends_on: [1]
      action:
        type: task
        task_name: "send_invoice_email"
        params:
          invoice_id:     "{NEW.id}"
          customer_email: "{LOOKUP(party_party, id=NEW.party, field=email)}"
          amount:         "{NEW.amount_total}"
          currency:       "{NEW.currency_symbol}"
          due_date:       "{NEW.payment_term_date}"

      compensation:
        # El email ya fue enviado — no se puede compensar el envío
        # Solo se registra que la compensación no es posible
        type: log_only
        message: "Email de factura enviado — compensación no aplicable"

    - step: 3
      name: "update_invoice_projection"
      description: "Actualizar proyección materializada"
      depends_on: [1]
      action:
        type: sql_write
        destination: bkernel_db
        table: dashboard_invoices_open
        operation: UPDATE
        set:
          state: "posted"
        where: "invoice_id = {NEW.id}"
```

---

## 7. Tabla de Garantías por Tipo de Transacción

| Tipo de transacción | Patrón | Consistencia | Compensable | Tiempo máximo |
|---|---|---|---|---|
| Escritura en una sola BD | Transacción SQL local | Fuerte | N/A | < 10ms |
| Proyección CQRS (bKernel) | Eventual via WAL | Eventual (SLO: 500ms P99) | No aplica | < 500ms P99 |
| Saga intra-bounded-context | Saga local con transacciones SQL | Fuerte dentro del BC | Sí — compensación SQL | < 1s |
| Saga cross-bounded-context (onboarding) | Saga orquestada por bKernel | Eventual — compensación si falla | Sí — compensación por paso | < 10 min (timeout Saga) |
| Saga con API externa (SIAT/AFIP/SAT) | Saga con SBOS Data Integration | Eventual — reintentos + compensación | Parcialmente (ver nota) | Hasta 30 min (timeout API externa) |

**Nota sobre compensación en APIs externas:** Las llamadas a APIs tributarias (SBOS Data Integration) no siempre son compensables. Una factura ya autorizada por el SIN/AFIP no puede "des-autorizarse" vía API — requiere el proceso de nota de crédito. La Saga registra esto en `saga_step_log` con `status = 'compensation_not_applicable'` y genera una alerta para intervención manual.

---

## 8. Referencias Cruzadas

- **SBOS-022** — Bounded Contexts (base de este documento)
- **SBOS-010** — bKernel (implementación del CDC, Rule Engine y Writer Pool)
- **SBOS-005** — IAM Installer (Sagas de instalación — patrón de referencia)
- **SBOS-024** — Operaciones (SLO de lag WAL, alertas bKernel)
- **SBOS-027** — Observabilidad de Daemons (métricas OTEL del bKernel para monitorear Sagas)

---

## 9. Registro de Cambios

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| 1.0 | Marzo 2026 | SKULL Team — Backend Lead + Arquitecto | Documento inicial — CQRS formal, tres proyecciones materializadas con reglas YAML, Saga de onboarding completo con compensaciones, Saga factura-CRM |

---

*SKULL · SBOS · SBOS-022-EXT-CQRS · v1.0 · Marzo 2026*
*Extiende: SBOS-022-BoundedContexts-v1_0*
*Clasificación: Especificación Técnica — Arquitectura de Dominios*
