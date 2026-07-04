# SBOS-040-DATABASE-CATALOG
## Catálogo de Bases de Datos del SBOS
### Estructura de BDs de Daemons + Referencia de BDs de Aplicaciones

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-040
**Estado:** NUEVO
**Clasificación:** Especificación Técnica — Modelo de Datos
**Propósito:** Centralizar en un solo documento (1) la estructura completa de las bases de datos propias de los daemons soberanos con sus tablas, campos y DDL, y (2) un listado de referencia de las bases de datos que usa cada aplicación del stack tecnológico.

---

## 1. Motor de Base de Datos

El SBOS usa **PostgreSQL 17** como motor principal. El 90%+ de las aplicaciones del stack usan PostgreSQL directamente. Tres apps legacy (OrangeHRM, FreePBX, Easy!Appointments) usan **MySQL 8** por carecer de soporte nativo de PostgreSQL; estas se sincronizan con el ecosistema vía SymmetricDS (ver SBOS-003 §S01).

Todas las bases de datos PostgreSQL residen en un cluster **Patroni HA** de 3 nodos con replicación streaming y failover automático.

---

## 2. Bases de Datos de los Daemons Soberanos

Estas son las bases de datos propias de los daemons del SBOS. Cada daemon gestiona sus propias tablas de estado, auditoría y operaciones internas. Son la parte del catálogo que requiere especificación completa.

---

### 2.1 bkernel_db — SBOS Data Kernel

**Owner PostgreSQL:** `bkernel`
**Propósito:** Estado operativo del bkernel, Dead Letter Queue, mapeo de IDs entre apps, checkpoints de WAL.

```sql
-- Tabla de checkpoints LSN (punto de lectura del WAL)
CREATE TABLE bkernel_state (
    id              SERIAL PRIMARY KEY,
    slot_name       VARCHAR(100) NOT NULL DEFAULT 'bkernel_slot',
    last_lsn        PG_LSN NOT NULL,
    last_processed  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    events_since    BIGINT DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'active'  -- active | paused | recovering
);

-- Dead Letter Queue (eventos que fallaron tras max_retries)
CREATE TABLE bkernel_dlq (
    id              BIGSERIAL PRIMARY KEY,
    event_id        UUID NOT NULL,
    rule_id         VARCHAR(50) NOT NULL,
    source_app      VARCHAR(100) NOT NULL,
    source_table    VARCHAR(200) NOT NULL,
    operation       VARCHAR(10) NOT NULL,        -- INSERT | UPDATE | DELETE
    event_data      JSONB NOT NULL,
    error_message   TEXT NOT NULL,
    error_code      VARCHAR(50),
    retry_count     INT DEFAULT 0,
    max_retries     INT DEFAULT 3,
    first_failure   TIMESTAMPTZ DEFAULT NOW(),
    last_retry      TIMESTAMPTZ,
    status          VARCHAR(20) DEFAULT 'pending', -- pending | retrying | resolved | discarded
    resolved_at     TIMESTAMPTZ,
    resolved_by     VARCHAR(100),
    resolution_note TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_bkernel_dlq_status ON bkernel_dlq(status);
CREATE INDEX idx_bkernel_dlq_rule ON bkernel_dlq(rule_id);
CREATE INDEX idx_bkernel_dlq_created ON bkernel_dlq(created_at);

-- Mapeo de IDs entre apps (entity_crossref)
-- Permite saber que el employee #45 de OrangeHRM es el party #1203 de Tryton
CREATE TABLE bkernel_entity_crossref (
    id              BIGSERIAL PRIMARY KEY,
    entity_type     VARCHAR(100) NOT NULL,       -- employee | customer | product | invoice
    source_app      VARCHAR(100) NOT NULL,       -- orangehrm | saleor | espocrm
    source_table    VARCHAR(200) NOT NULL,
    source_id       VARCHAR(200) NOT NULL,
    target_app      VARCHAR(100) NOT NULL,       -- tryton (hub)
    target_table    VARCHAR(200) NOT NULL,
    target_id       VARCHAR(200) NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(source_app, source_table, source_id, target_app, target_table)
);

CREATE INDEX idx_crossref_source ON bkernel_entity_crossref(source_app, source_id);
CREATE INDEX idx_crossref_target ON bkernel_entity_crossref(target_app, target_id);

-- Log de reglas ejecutadas (para auditoría y métricas)
CREATE TABLE bkernel_rule_log (
    id              BIGSERIAL PRIMARY KEY,
    rule_id         VARCHAR(50) NOT NULL,
    event_lsn       PG_LSN NOT NULL,
    source_app      VARCHAR(100) NOT NULL,
    source_table    VARCHAR(200) NOT NULL,
    operation       VARCHAR(10) NOT NULL,
    actions_count   INT DEFAULT 0,
    duration_ms     INT,
    status          VARCHAR(20) NOT NULL,        -- success | partial | failed
    error_summary   TEXT,
    executed_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_rule_log_rule ON bkernel_rule_log(rule_id);
CREATE INDEX idx_rule_log_time ON bkernel_rule_log(executed_at);
```

---

### 2.2 biedata_db — SBOS Data Integration

**Owner PostgreSQL:** `biedata`
**Propósito:** Auditoría de ejecución de cajas, DLQ de integración, estado de circuit breakers.

```sql
-- Log de auditoría de ejecución de cajas
CREATE TABLE biedata_audit_log (
    id              BIGSERIAL PRIMARY KEY,
    job_id          UUID NOT NULL,
    box_id          VARCHAR(50) NOT NULL,
    box_type        VARCHAR(10) NOT NULL,         -- import | export
    started_at      TIMESTAMPTZ NOT NULL,
    completed_at    TIMESTAMPTZ,
    status          VARCHAR(20) NOT NULL,          -- success | partial | failed | aborted
    rows_processed  INT DEFAULT 0,
    rows_succeeded  INT DEFAULT 0,
    rows_failed     INT DEFAULT 0,
    error_summary   TEXT,
    external_system VARCHAR(100),
    external_endpoint VARCHAR(500),
    duration_ms     INT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_biedata_audit_box ON biedata_audit_log(box_id);
CREATE INDEX idx_biedata_audit_time ON biedata_audit_log(started_at);
CREATE INDEX idx_biedata_audit_status ON biedata_audit_log(status);

-- Dead Letter Queue de biedata
CREATE TABLE biedata_dlq (
    id              BIGSERIAL PRIMARY KEY,
    job_id          UUID NOT NULL,
    box_id          VARCHAR(50) NOT NULL,
    row_data        JSONB NOT NULL,
    error_message   TEXT NOT NULL,
    retry_count     INT DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'pending',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Estado de circuit breakers por sistema externo
CREATE TABLE biedata_circuit_state (
    id              SERIAL PRIMARY KEY,
    external_system VARCHAR(100) NOT NULL UNIQUE,
    state           VARCHAR(20) NOT NULL DEFAULT 'closed', -- closed | open | half_open
    failure_count   INT DEFAULT 0,
    last_failure    TIMESTAMPTZ,
    last_success    TIMESTAMPTZ,
    opened_at       TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

---

### 2.3 bauth_db — SBOS Auth Enforce

**Owner PostgreSQL:** `bauth`
**Propósito:** Log de sincronización KC↔Tryton, historial de correcciones de drift, delegaciones temporales, auditoría de acceso.

```sql
-- Log de sincronización atómica KC↔Tryton
CREATE TABLE bauth_sync_log (
    id              BIGSERIAL PRIMARY KEY,
    template_type   VARCHAR(20) NOT NULL,          -- rol_template | user_template
    template_id     VARCHAR(100) NOT NULL,
    action          VARCHAR(30) NOT NULL,           -- create | update | delete | drift_correction
    kc_status       VARCHAR(20),                    -- success | failed | skipped
    tryton_status   VARCHAR(20),                    -- success | failed | skipped
    duration_ms     INT,
    error_detail    TEXT,
    synced_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sync_log_template ON bauth_sync_log(template_id);
CREATE INDEX idx_sync_log_time ON bauth_sync_log(synced_at);

-- Historial de correcciones de drift
CREATE TABLE bauth_drift_history (
    id              BIGSERIAL PRIMARY KEY,
    template_id     VARCHAR(100) NOT NULL,
    drift_type      VARCHAR(50) NOT NULL,           -- kc_missing_attribute | tryton_extra_permission | bitmask_mismatch
    expected_value  JSONB,
    actual_value    JSONB,
    corrected       BOOLEAN DEFAULT FALSE,
    correction_detail TEXT,
    detected_at     TIMESTAMPTZ DEFAULT NOW(),
    corrected_at    TIMESTAMPTZ
);

-- Delegaciones temporales activas
CREATE TABLE bauth_delegations (
    id              BIGSERIAL PRIMARY KEY,
    delegated_to    UUID NOT NULL,
    delegated_from  UUID NOT NULL,
    role_template   VARCHAR(100) NOT NULL,
    reason          TEXT NOT NULL,
    valid_from      TIMESTAMPTZ NOT NULL,
    valid_until     TIMESTAMPTZ NOT NULL,
    auto_revoke     BOOLEAN DEFAULT TRUE,
    approved_by     UUID,
    approved_at     TIMESTAMPTZ,
    revoked_at      TIMESTAMPTZ,
    status          VARCHAR(20) DEFAULT 'active',   -- active | expired | revoked
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_delegations_active ON bauth_delegations(status) WHERE status = 'active';

-- Auditoría de evaluaciones de acceso
CREATE TABLE bauth_access_log (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL,
    node_id         VARCHAR(100),
    input_type      VARCHAR(20),                    -- qr | nfc | rfid | biometric | session
    domain_logical  VARCHAR(10),                    -- grant | deny
    domain_physical VARCHAR(10),                    -- grant | deny | n/a
    domain_financial VARCHAR(10),                   -- grant | deny | n/a
    result          VARCHAR(10) NOT NULL,           -- grant | deny
    deny_reason     VARCHAR(100),
    bitmask         BIGINT,
    latency_ms      INT,
    evaluated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_access_log_user ON bauth_access_log(user_id);
CREATE INDEX idx_access_log_time ON bauth_access_log(evaluated_at);
CREATE INDEX idx_access_log_denied ON bauth_access_log(result) WHERE result = 'deny';
```

---

### 2.4 bcompass_db — SBOS AI Tools

**Owner PostgreSQL:** `bcompass`
**Propósito:** Estado de rutas de inteligencia, caché de análisis, feedback de usuarios para fine-tuning.

```sql
-- Registro de ejecución de rutas
CREATE TABLE bcompass_route_log (
    id              BIGSERIAL PRIMARY KEY,
    route_id        VARCHAR(50) NOT NULL,
    route_type      VARCHAR(20) NOT NULL,           -- analytical | research | conversational | report
    user_id         UUID,
    model_used      VARCHAR(50) NOT NULL,           -- qwen3:8b | qwen3:1.5b | phi-3-mini
    prompt_tokens   INT,
    completion_tokens INT,
    total_tokens    INT,
    latency_ms      INT,
    status          VARCHAR(20) NOT NULL,           -- success | failed | timeout | fallback
    langfuse_trace_id VARCHAR(100),
    executed_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_route_log_route ON bcompass_route_log(route_id);
CREATE INDEX idx_route_log_time ON bcompass_route_log(executed_at);

-- Feedback de usuarios (para aprendizaje federado)
CREATE TABLE bcompass_feedback (
    id              BIGSERIAL PRIMARY KEY,
    route_log_id    BIGINT REFERENCES bcompass_route_log(id),
    user_id         UUID NOT NULL,
    rating          SMALLINT CHECK (rating BETWEEN 1 AND 5),
    comment         TEXT,
    useful          BOOLEAN,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Caché de propuestas pendientes de aprobación humana
CREATE TABLE bcompass_proposals (
    id              BIGSERIAL PRIMARY KEY,
    route_id        VARCHAR(50) NOT NULL,
    proposal_type   VARCHAR(50) NOT NULL,           -- purchase_order | price_adjustment | alert
    proposal_data   JSONB NOT NULL,
    confidence      DECIMAL(3,2),
    status          VARCHAR(20) DEFAULT 'pending',  -- pending | approved | rejected | expired
    approved_by     UUID,
    approved_at     TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_proposals_pending ON bcompass_proposals(status) WHERE status = 'pending';
```

---

### 2.5 bos_db — IAM Installer (Estado del Sistema)

**Nota:** El daemon bos almacena su estado principal en el archivo `.sbos_state.json` (ver SBOS-005 §state.json). Sin embargo, para auditoría persistente usa una BD PostgreSQL.

**Owner PostgreSQL:** `bos`

```sql
-- Log de operaciones del IAM Installer
CREATE TABLE bos_operation_log (
    id              BIGSERIAL PRIMARY KEY,
    operation_id    UUID NOT NULL,
    operation_type  VARCHAR(20) NOT NULL,           -- install | update | repair | uninstall
    ficha_name      VARCHAR(100) NOT NULL,
    product_name    VARCHAR(100),
    phase           VARCHAR(30),                    -- pre_check | execute | post_verify | rollback
    status          VARCHAR(20) NOT NULL,           -- started | success | failed | rolled_back
    duration_ms     INT,
    error_detail    TEXT,
    operator        VARCHAR(100),                   -- admin user or 'auto-heal'
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_bos_ops_ficha ON bos_operation_log(ficha_name);
CREATE INDEX idx_bos_ops_time ON bos_operation_log(created_at);

-- Estado de salud del stack (snapshots periódicos)
CREATE TABLE bos_health_snapshot (
    id              BIGSERIAL PRIMARY KEY,
    fichas_total    INT NOT NULL,
    fichas_healthy  INT NOT NULL,
    fichas_degraded INT DEFAULT 0,
    fichas_failed   INT DEFAULT 0,
    k8s_nodes       INT,
    k8s_pods_total  INT,
    k8s_pods_ready  INT,
    pg_connections  INT,
    snapshot_at     TIMESTAMPTZ DEFAULT NOW()
);
```

---

### 2.6 Replication Slots WAL

```sql
-- Slots creados en PostgreSQL para CDC
-- Cada daemon tiene su propio slot para leer el WAL de forma independiente

SELECT pg_create_logical_replication_slot('bkernel_slot', 'pgoutput');
SELECT pg_create_logical_replication_slot('biedata_slot', 'pgoutput');
SELECT pg_create_logical_replication_slot('bcompass_slot', 'pgoutput');
```

| Slot | Daemon | Escucha | Publicaciones |
|------|--------|---------|--------------|
| `bkernel_slot` | bkernel | Cambios en TODAS las apps del stack | Todas las tablas de tryton_db, orangehrm_db, saleor_db, espocrm_db |
| `biedata_slot` | biedata | Triggers de integración con exterior | Tablas específicas de tryton_db (facturas, comprobantes) |
| `bcompass_slot` | bcompass | Eventos para análisis de inteligencia | Tablas de tryton_db (ventas, inventario, contabilidad) |

---

### 2.7 Extensions PostgreSQL Requeridas

| Extension | Propósito | Requerida por |
|-----------|-----------|--------------|
| `pg_replication_origin` | Prevención de loop infinito en CDC | bkernel (marca sus escrituras para ignorarlas al leer WAL) |
| `pgcrypto` | Funciones criptográficas | bauth (hashing de tokens), Keycloak |
| `unaccent` | Búsqueda sin acentos | bsearch, Tryton |
| `pg_trgm` | Similitud de texto (trigrams) | bsearch (fuzzy matching) |
| `uuid-ossp` | Generación de UUIDs | Todos los daemons |
| `pg_stat_statements` | Estadísticas de queries | Monitoreo (Prometheus exporter) |
| `timescaledb` | Series de tiempo | Métricas de negocio, IoT |
| `citus` | Sharding horizontal | Workloads analíticos (opcional) |

---

## 3. Bases de Datos de las Aplicaciones del Stack — Listado de Referencia

Estas son las bases de datos que las aplicaciones del stack crean y gestionan por sí mismas. El SBOS no modifica su estructura — solo las lee vía WAL (bkernel) o les escribe vía Writer Pool con UPSERT idempotente.

### 3.1 Aplicaciones con PostgreSQL

| # | Aplicación | Nombre BD por defecto | Owner | Servidor Lógico | Notas |
|:-:|-----------|----------------------|-------|----------------|-------|
| 1 | Tryton ERP | `tryton` | `tryton` | S04 erpserver | BD configurable con `-d` en `trytond-admin`. Fuente de verdad del negocio |
| 2 | Keycloak | `keycloak` | `keycloak` | S03 identityserver | Env `KC_DB_URL_DATABASE`. Almacena realms, users, sessions, clients |
| 3 | Kong Gateway | `kong` | `kong` | S02 gatewayserver | Env `KONG_PG_DATABASE`. Rutas, plugins, consumers |
| 4 | Saleor Commerce | `saleor` | `saleor` | S06 appsserver | Env `DATABASE_URL`. Productos, órdenes, checkout |
| 5 | EspoCRM | `espocrm` | `espocrm` | S06 appsserver | Env `ESPOCRM_DATABASE_NAME`. Soporta MySQL y PostgreSQL |
| 6 | Zammad | `zammad_production` | `zammad` | S06 appsserver | Config `database.yml`. Tickets, artículos, usuarios |
| 7 | GitLab CE | `gitlabhq_production` | `gitlab` | S14 opsserver | Nombre estándar de GitLab Omnibus |
| 8 | Grafana | `grafana` | `grafana` | S12 monitorserver | Env `GF_DATABASE_NAME`. Dashboards, alertas, users |
| 9 | Nextcloud | `nextcloud` | `nextcloud` | S11 vdiserver | Config `config.php` `dbname`. Archivos, calendarios, contactos |
| 10 | Paperless-NGX | `paperless` | `paperless` | S08 docserver | Env `PAPERLESS_DBNAME`. Documentos, tags, correspondents |
| 11 | Wiki.js | `wikijs` | `wikijs` | S06 appsserver | Config `config.yml` `db.db`. Páginas, assets |
| 12 | Roundcube | `roundcube` | `roundcube` | S10 commsserver | Config `config.inc.php` `db_dsnw`. Contactos, identidades |
| 13 | PostfixAdmin | `postfixadmin` | `postfixadmin` | S10 commsserver | Config `config.local.php`. Dominios, buzones, alias |
| 14 | Taiga | `taiga` | `taiga` | S06 appsserver | Env `POSTGRES_DB`. Proyectos, sprints, user stories |
| 15 | OpenProject | `openproject` | `openproject` | S06 appsserver | Config `database.yml`. Proyectos, work packages, Gantt |
| 16 | Zabbix | `zabbix` | `zabbix` | S12 monitorserver | Config `zabbix_server.conf` `DBName`. Hosts, items, triggers |
| 17 | Superset | `superset` | `superset` | S07 reportserver | Env `SQLALCHEMY_DATABASE_URI`. Dashboards, charts, datasets |
| 18 | Airflow | `airflow` | `airflow` | S07 reportserver | Env `AIRFLOW__DATABASE__SQL_ALCHEMY_CONN`. DAGs, task instances |
| 19 | Langfuse | `langfuse` | `langfuse` | S15 aiserver | Env `DATABASE_URL`. Traces, prompts, scores |
| 20 | Bareos | `bareos` | `bareos` | S14 opsserver | Config `bareos-dir.conf`. Jobs, volumes, clients |
| 21 | DocuSeal | `docuseal` | `docuseal` | S08 docserver | Env `DATABASE_URL`. Documentos, firmantes, submissions |
| 22 | Cal.com | `calcom` | `calcom` | S06 appsserver | Env `DATABASE_URL`. Bookings, event types, availability |
| 23 | LimeSurvey | `limesurvey` | `limesurvey` | S06 appsserver | Config `config.php`. Surveys, responses, tokens |
| 24 | Portainer | `portainer` | — | S12 monitorserver | Usa BoltDB local (no PostgreSQL) |
| 25 | GNU Health | `gnuhealth` | `gnuhealth` | S06 appsserver | Basado en Tryton — misma convención |
| 26 | Wazuh | — | — | S03 identityserver | Usa Elasticsearch/OpenSearch como backend (no PostgreSQL) |
| 27 | PgAdmin 4 | `pgadmin` | `pgadmin` | S01 dataserver | Env `PGADMIN_CONFIG_CONFIG_DATABASE_URI` |
| 28 | OpenMetadata | `openmetadata` | `openmetadata` | S07 reportserver | Env `DATABASE_HOST`. Catálogo de datos, linaje |
| 29 | Mattermost | `mattermost` | `mattermost` | S10 commsserver | Env `MM_SQLSETTINGS_DATASOURCE`. Channels, posts, teams |
| 30 | Rocket.Chat | `rocketchat` | — | S10 commsserver | Usa MongoDB (no PostgreSQL). Excepción del stack |

### 3.2 Aplicaciones con MySQL (excepciones)

| # | Aplicación | Nombre BD MySQL | Owner MySQL | Notas |
|:-:|-----------|----------------|-------------|-------|
| 1 | OrangeHRM | `orangehrm` | `orangehrm` | Nombre configurable en instalador. Default: `orangehrm` |
| 2 | FreePBX + Asterisk | `asterisk` + `asteriskcdrdb` | `freepbx` | FreePBX requiere MySQL estrictamente |
| 3 | Easy!Appointments | `easyappointments` | `easyapp` | PHP app sin soporte PostgreSQL nativo |

**Sincronización MySQL→PostgreSQL:** SymmetricDS replica las tablas clave de MySQL al cluster PostgreSQL para que el bkernel pueda escucharlas vía WAL.

### 3.3 Aplicaciones sin Base de Datos Relacional

| Aplicación | Almacenamiento | Notas |
|-----------|---------------|-------|
| Redis 7 | In-memory (RDB + AOF) | Caché, sesiones, pub/sub, broker Celery |
| MinIO | Object storage S3 | Documentos, logs, backups, modelos AI |
| Qdrant | Vector database (Raft) | Embeddings semánticos para bSearch/bCompass |
| Typesense | Search engine (propio) | Índices full-text para bSearch |
| Elasticsearch | Search/analytics (Lucene) | Logs Wazuh, búsqueda unificada |
| Prometheus | TSDB (propio) | Métricas del stack |
| Loki | Log aggregation (chunks en MinIO) | Logs del stack |

---

## 4. Política de Backup por Base de Datos

| Categoría | BDs | Frecuencia | Herramienta | Retención |
|-----------|-----|-----------|-------------|-----------|
| **Crítica** | tryton, keycloak, bkernel_db, bauth_db | Cada 1h (incremental) + diario (full) | pgBackRest PITR | 90 días |
| **Alta** | saleor, orangehrm, espocrm, biedata_db | Cada 4h (incremental) + diario (full) | pgBackRest | 60 días |
| **Media** | grafana, gitlab, zammad, paperless, nextcloud | Diario (full) | pgBackRest | 30 días |
| **Baja** | langfuse, bcompass_db, calcom, limesurvey | Semanal (full) | pgBackRest | 14 días |
| **Sistema** | bos_db | Diario (full) | pgBackRest | 30 días |

---

## 5. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Estructura completa de 5 bases de datos de daemons con DDL (bkernel_db: 4 tablas, biedata_db: 3 tablas, bauth_db: 4 tablas, bcompass_db: 3 tablas, bos_db: 2 tablas). Replication slots WAL. Extensions PostgreSQL requeridas. Listado de referencia de 30 aplicaciones con PostgreSQL, 3 con MySQL, y 7 sin BD relacional. Política de backup por categoría.

---

*SKULL · SBOS · SBOS-040-DATABASE-CATALOG · v1.0 · Marzo 2026*
