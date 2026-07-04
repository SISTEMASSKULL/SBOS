# SBOS-043-DATABASE-CATALOG
## Catalogo de Bases de Datos — Estandar HUMAN-DOC
### SKULL · SBOS · V8 Enriquecido · Mayo 2026

---

## 1. Motor

PostgreSQL 17 (90%+ apps). Patroni HA 3 nodos con streaming replication + failover automatico. Excepciones MySQL: OrangeHRM, FreePBX, Easy!Appointments (sync via SymmetricDS).

### Enriquecimiento Smart CMS: Modelo de datos SBOS CMS

Smart CMS define (BOSCMS-007-DATOS) una base de datos dedicada `sbos_cms_db` con PostgreSQL 17, schema principal `cms`. Las tablas principales incluyen:
- `cms.content_entry` — entradas de contenido multi-tenant con ctx_id, tenant, campos personalizados
- `cms.content_version` — versionado de contenido (historial completo de cambios)
- `cms.content_relation` — relaciones entre entradas de contenido
- `cms.media_asset` — activos multimedia referenciados desde MinIO
- `cms.publishing_queue` — cola de publicacion con estados (draft, review, published, archived)
- `cms.taxonomy_term` — taxonomias y categorias multi-nivel

Este modelo se integra con el WAL de bKernel para propagacion de cambios a bSearch (indexacion) y a Centrifugo (notificaciones en tiempo real).

### Enriquecimiento Smart Pay: Modelo de datos SmartPay

Smart Pay define (SBOS-PAY-007-DATOS) `bpay_db` como base de datos independiente PostgreSQL 16, schema `bpay`. Principio de soberania de datos: bpay tiene su propia BD completa; Tryton es el destino contable, no la fuente de verdad de pagos. Tablas principales:
- `bpay.payment_transaction` — registro maestro de toda transaccion
- `bpay.payment_session_log` — eventos inmutables del ciclo de vida
- `bpay.qr_session` — QR dinamicos activos y su estado
- `bpay.payment_queue` — cola de pagos y cobros pendientes
- `bpay.client_ledger` — kardex de cuenta corriente de cada cliente
- `bpay.client_balance` — saldo consolidado por cliente (vista materializada)
- `bpay.advance_account` — registro de anticipos y saldos a favor
- `bpay.pending_verification` — cheques y transferencias asincronas en espera
- `bpay.reconciliation_import` — extractos bancarios importados para conciliacion

Campos obligatorios de contexto SBOS: `ctx_id`, `tenant`, `empresa`, `sucursal` en toda tabla principal.

### Enriquecimiento Smart Rates: Modelo de datos SmartRates

Smart Rates define (SBOS-Rates-007-DATOS) `brates_db` como base de datos independiente PostgreSQL 16, schema `brates`. Gestiona tipos de cambio, tasas y conversiones. Tablas principales:
- `brates.rate_source` — fuentes de tasa (BCB, bancos, market makers)
- `brates.rate_entry` — registro historico de tasas por fuente y par
- `brates.cross_rate` — tasas cruzadas calculadas
- `brates.black_rate` — tasas paralelas/dolar blue
- `brates.usdt_rate` — tasas USDT/stablecoin
- `brates.conversion_log` — log de conversiones realizadas

## 2. BDs de Daemons Soberanos (DDL completo)

### 2.1 bkernel_db (Owner: bkernel)
```sql
CREATE TABLE bkernel_state (
    id SERIAL PRIMARY KEY, slot_name VARCHAR(100) DEFAULT 'bkernel_slot',
    last_lsn PG_LSN NOT NULL, last_processed TIMESTAMPTZ DEFAULT NOW(),
    events_since BIGINT DEFAULT 0, status VARCHAR(20) DEFAULT 'active');

CREATE TABLE bkernel_dlq (
    id BIGSERIAL PRIMARY KEY, event_id UUID NOT NULL, rule_id VARCHAR(50),
    source_app VARCHAR(100), source_table VARCHAR(200), operation VARCHAR(10),
    event_data JSONB NOT NULL, error_message TEXT NOT NULL,
    retry_count INT DEFAULT 0, max_retries INT DEFAULT 3,
    status VARCHAR(20) DEFAULT 'pending', created_at TIMESTAMPTZ DEFAULT NOW());

CREATE TABLE bkernel_entity_crossref (
    id BIGSERIAL PRIMARY KEY, entity_type VARCHAR(100), source_app VARCHAR(100),
    source_table VARCHAR(200), source_id VARCHAR(200), target_app VARCHAR(100),
    target_table VARCHAR(200), target_id VARCHAR(200),
    UNIQUE(source_app, source_table, source_id, target_app, target_table));

CREATE TABLE bkernel_rule_log (
    id BIGSERIAL PRIMARY KEY, rule_id VARCHAR(50), event_lsn PG_LSN,
    source_app VARCHAR(100), operation VARCHAR(10), actions_count INT,
    duration_ms INT, status VARCHAR(20), executed_at TIMESTAMPTZ DEFAULT NOW());
```

### 2.2 biedata_db (Owner: biedata)
```sql
CREATE TABLE biedata_audit_log (
    id BIGSERIAL PRIMARY KEY, job_id UUID, box_id VARCHAR(50), box_type VARCHAR(10),
    started_at TIMESTAMPTZ, status VARCHAR(20), rows_processed INT, rows_failed INT,
    external_system VARCHAR(100), duration_ms INT);

CREATE TABLE biedata_dlq (
    id BIGSERIAL PRIMARY KEY, job_id UUID, box_id VARCHAR(50),
    row_data JSONB NOT NULL, error_message TEXT, retry_count INT DEFAULT 0);

CREATE TABLE biedata_circuit_state (
    id SERIAL PRIMARY KEY, external_system VARCHAR(100) UNIQUE,
    state VARCHAR(20) DEFAULT 'closed', failure_count INT DEFAULT 0,
    last_failure TIMESTAMPTZ, opened_at TIMESTAMPTZ);
```

### 2.3 bauth_db (Owner: bauth)
```sql
CREATE TABLE bauth_sync_log (
    id BIGSERIAL PRIMARY KEY, template_type VARCHAR(20), template_id VARCHAR(100),
    action VARCHAR(30), kc_status VARCHAR(20), tryton_status VARCHAR(20),
    duration_ms INT, synced_at TIMESTAMPTZ DEFAULT NOW());

CREATE TABLE bauth_drift_history (
    id BIGSERIAL PRIMARY KEY, template_id VARCHAR(100), drift_type VARCHAR(50),
    expected_value JSONB, actual_value JSONB, corrected BOOLEAN DEFAULT FALSE,
    detected_at TIMESTAMPTZ DEFAULT NOW());

CREATE TABLE bauth_delegations (
    id BIGSERIAL PRIMARY KEY, delegated_to UUID, delegated_from UUID,
    role_template VARCHAR(100), reason TEXT, valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ, auto_revoke BOOLEAN DEFAULT TRUE,
    status VARCHAR(20) DEFAULT 'active');

CREATE TABLE bauth_access_log (
    id BIGSERIAL PRIMARY KEY, user_id UUID, node_id VARCHAR(100),
    input_type VARCHAR(20), domain_logical VARCHAR(10), domain_physical VARCHAR(10),
    domain_financial VARCHAR(10), result VARCHAR(10), bitmask BIGINT,
    latency_ms INT, evaluated_at TIMESTAMPTZ DEFAULT NOW());
```

### 2.4 bcompass_db (Owner: bcompass)
```sql
CREATE TABLE bcompass_route_log (
    id BIGSERIAL PRIMARY KEY, route_id VARCHAR(50), route_type VARCHAR(20),
    user_id UUID, model_used VARCHAR(50), prompt_tokens INT, completion_tokens INT,
    latency_ms INT, status VARCHAR(20), langfuse_trace_id VARCHAR(100));

CREATE TABLE bcompass_feedback (
    id BIGSERIAL PRIMARY KEY, route_log_id BIGINT REFERENCES bcompass_route_log(id),
    user_id UUID, rating SMALLINT CHECK (rating BETWEEN 1 AND 5), useful BOOLEAN);

CREATE TABLE bcompass_proposals (
    id BIGSERIAL PRIMARY KEY, route_id VARCHAR(50), proposal_type VARCHAR(50),
    proposal_data JSONB, confidence DECIMAL(3,2),
    status VARCHAR(20) DEFAULT 'pending', approved_by UUID, expires_at TIMESTAMPTZ);
```

### 2.5 bos_db (Owner: bos)
```sql
CREATE TABLE bos_operation_log (
    id BIGSERIAL PRIMARY KEY, operation_id UUID, operation_type VARCHAR(20),
    ficha_name VARCHAR(100), product_name VARCHAR(100), phase VARCHAR(30),
    status VARCHAR(20), duration_ms INT, operator VARCHAR(100));

CREATE TABLE bos_health_snapshot (
    id BIGSERIAL PRIMARY KEY, fichas_total INT, fichas_healthy INT,
    fichas_degraded INT DEFAULT 0, k8s_nodes INT, k8s_pods_total INT,
    pg_connections INT, snapshot_at TIMESTAMPTZ DEFAULT NOW());
```

## 3. Replication Slots WAL

| Slot | Daemon | Escucha |
|---|---|---|
| bkernel_slot | bkernel | TODAS las apps del stack (tryton, orangehrm, saleor, espocrm) |
| biedata_slot | biedata | Tablas de integracion (facturas, comprobantes de tryton_db) |
| bcompass_slot | bcompass | Tablas analiticas (ventas, inventario, contabilidad) |

## 4. Extensions PostgreSQL

| Extension | Proposito | Requerida por |
|---|---|---|
| pg_replication_origin | Prevencion loop CDC | bkernel |
| pgcrypto | Funciones criptograficas | bauth, KC |
| unaccent | Busqueda sin acentos | bsearch, Tryton |
| pg_trgm | Fuzzy matching trigrams | bsearch |
| uuid-ossp | UUIDs | Todos los daemons |
| pg_stat_statements | Estadisticas queries | Prometheus exporter |
| timescaledb | Series de tiempo | Metricas negocio, IoT |

## 5. BDs de Aplicaciones — Referencia (30 PostgreSQL + 3 MySQL + 7 no-relacional)

### Enriquecimiento V5: BDs adicionales Smart*

Las BDs de aplicaciones Smart* se integran en el catalogo:

| App | BD | Server | Notas |
|---|---|---|---|
| SmartTax | smartax_db | S05 | Datos fiscales, configuracion por jurisdiccion |
| SmartReport | sreport_db | S05 | Reportes, dashboards, plantillas |
| SmartRates | brates_db | S05 | Tipos de cambio, tasas, conversiones |
| SmartORC | borc_db | S05 | Orquestacion de workflows |
| SmartVaultFlow | bvaultflow_db | S05 | Flujos de vault y aprobaciones |
| SmartPortfolio | bportfolio_db | S05 | Catalogo de productos, pipeline de ingesta |
| SmartPay | bpay_db | S05 | Pagos, transacciones, conciliacion |
| SBOS IAM Style | biamstyle_db | S05 | Estilos IAM, personalizacion |
| SBOS CMS | sbos_cms_db | S05 | Contenido multi-tenant |

### PostgreSQL (30 apps)
| App | BD | Server | Notas |
|---|---|---|---|
| Tryton | tryton | S04 | Fuente verdad negocio |
| Keycloak | keycloak | S03 | Realms, users, sessions |
| Kong | kong | S02 | Rutas, plugins |
| Saleor | saleor | S06 | Productos, ordenes |
| EspoCRM | espocrm | S06 | Oportunidades, pipeline |
| Zammad | zammad_production | S06 | Tickets, articulos |
| GitLab | gitlabhq_production | S14 | Repos, CI/CD |
| Grafana | grafana | S12 | Dashboards, alertas |
| Nextcloud | nextcloud | S11 | Archivos, calendarios |
| Paperless-NGX | paperless | S08 | Documentos, OCR |
| Roundcube | roundcube | S10 | Contactos, identidades |
| PostfixAdmin | postfixadmin | S10 | Dominios, buzones |
| Mattermost | mattermost | S10 | Channels, posts |
| Langfuse | langfuse | S15 | Traces, prompts |
| + 16 mas | (Zabbix, Superset, Airflow, OpenMetadata, Bareos, DocuSeal, etc.) | — | — |

### MySQL (3 excepciones — sync SymmetricDS → PG)
OrangeHRM, FreePBX+Asterisk, Easy!Appointments.

### No-relacional
Redis (cache/pubsub), MinIO (object storage), Qdrant (vectores), Typesense (full-text), Elasticsearch (Wazuh logs), Prometheus (TSDB), Loki (log aggregation).

## 6. Politica Backup por BD

| Categoria | BDs | Frecuencia | Retencion |
|---|---|---|---|
| Critica | tryton, keycloak, bkernel_db, bauth_db | 1h incremental + diario full | 90 dias |
| Alta | saleor, orangehrm, espocrm, biedata_db, bpay_db, brates_db | 4h incremental + diario full | 60 dias |
| Media | grafana, gitlab, zammad, paperless, nextcloud, sbos_cms_db, smartax_db | Diario full | 30 dias |
| Baja | langfuse, bcompass_db, calcom, bportfolio_db | Semanal full | 14 dias |
| Sistema | bos_db | Diario full | 30 dias |

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1 Motor | SBOS-040 v1.0 | §1 (PG 17, Patroni HA, excepciones MySQL) |
| §2 DDL daemons | SBOS-040 v1.0 | §2 completo (5 BDs: bkernel 4 tablas, biedata 3, bauth 4, bcompass 3, bos 2) |
| §3 Slots | SBOS-040 v1.0 | §2.6 (3 slots con publicaciones) |
| §4 Extensions | SBOS-040 v1.0 | §2.7 (7 extensions con proposito) |
| §5 Apps | SBOS-040 v1.0 | §3 completo (30 PG + 3 MySQL + 7 no-relacional) |
| §6 Backup | SBOS-040 v1.0 | §4 (tabla por categoria con frecuencia/retencion) |

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Aportacion |
|---|---|---|
| V5 | /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-040-DATABASE-CATALOG-v1_0.md | BDs de aplicaciones Smart* ampliadas |
| Smart CMS | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS CMS/context/BOSCMS-007-DATOS.md | Modelo de datos sbos_cms_db con tablas content_entry, content_version, media_asset, publishing_queue, taxonomy_term |
| Smart Pay | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Pay/context/SBOS-PAY-007-DATOS.md | Modelo de datos bpay_db con payment_transaction, qr_session, client_ledger, reconciliation_import y principio de soberania de datos |
| Smart Rates | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Rates/context/SBOS-Rates-007-DATOS.md | Modelo de datos brates_db con rate_source, rate_entry, cross_rate, black_rate, usdt_rate |

---

_SKULL · SBOS · SBOS-043-DATABASE-CATALOG · V8 Enriquecido · Mayo 2026_
