# SBOS-003-DOMAIN
## Modelo de Dominio — Estandar HUMAN-DOC (Enriquecido V8)
### SKULL · SBOS v1.1-V8 · Mayo 2026

---

## 1. Bounded Contexts

El SBOS tiene 9 bounded contexts con fuentes de verdad y contratos de integracion definidos.

| # | Bounded Context | Servidor logico | Fuente de Verdad | Entidad central |
|---|---|---|---|---|
| BC-01 | Financiero-Contable | erpserver | Tryton ERP | party.party |
| BC-02 | RRHH | appsserver | OrangeHRM | hs_hr_employee |
| BC-03 | Ventas y CRM | appsserver | Saleor + EspoCRM | contacts, orders |
| BC-04 | Identidad | identityserver | Keycloak + bAuth | user, realm, role |
| BC-05 | Comunicaciones | commsserver | Postfix + Mattermost + Centrifugo | mailbox, channel |
| BC-06 | Reportes e Inteligencia | reportserver | Superset + Airflow | dashboard, pipeline |
| BC-07 | IA Soberana | aiserver | Qdrant + bCompass | embedding, query |
| BC-08 | Integracion Exterior | daemon biedata | biedata | caja, mensaje externo |
| BC-09 | Plataforma | host + K8s | IAM Installer + K8s + bKernel | ficha, cluster state |

---

## 2. Entidades por Bounded Context

### BC-01 — Financiero-Contable (Tryton)

| Entidad | Descripcion | Atributos clave |
|---|---|---|
| party.party | Persona/empresa (hub MDM) | name, vat_number, addresses, contact_mechanisms |
| account.invoice | Factura | number, party, total_amount, state, currency |
| account.move | Asiento contable | period, journal, lines, state |
| account.account | Cuenta contable | code, name, type, company |
| purchase.purchase | Orden de compra | party, lines, state, total_amount |
| sale.sale | Orden de venta | party, lines, state, total_amount |
| product.product | Producto/servicio | name, code, type, list_price, cost_price |
| account.period | Periodo fiscal | name, start_date, end_date, state |

**Eventos emitidos:** tryton.invoice.confirmed, tryton.payment.done, tryton.purchase.created, tryton.purchase.confirmed, tryton.period.closed

### BC-02 — RRHH (OrangeHRM)

| Entidad | Descripcion | Atributos clave |
|---|---|---|
| hs_hr_employee | Empleado | emp_number, emp_firstname, emp_lastname, emp_work_email |
| ohrm_subunit | Departamento/unidad | name, description, level |
| ohrm_job_title | Cargo | job_title_name, job_description |
| hs_hr_emp_contract | Contrato de trabajo | contract_id, start_date, end_date |
| ohrm_leave_request | Solicitud de licencia | leave_type, date_from, date_to, status |

**Eventos emitidos:** orangehrm.employee.created, orangehrm.employee.terminated, orangehrm.employee.updated, orangehrm.leave.approved

### BC-03 — Ventas y CRM (Saleor + EspoCRM)

| Entidad | Descripcion | Atributos clave |
|---|---|---|
| contacts (EspoCRM) | Cliente/contacto | name, email, phone, account |
| orders (Saleor) | Pedido e-commerce | number, user, total, status |
| opportunities (EspoCRM) | Oportunidad de venta | name, amount, stage, probability |
| products (Saleor) | Catalogo de venta | name, slug, price, category |

**Eventos emitidos:** espocrm.customer.created, saleor.order.placed, saleor.order.paid

### BC-04 — Identidad (Keycloak + bAuth)

| Entidad | Descripcion | Atributos clave |
|---|---|---|
| user_entity (KC) | Usuario del sistema | id, email, username, realm_id |
| keycloak_role | Rol | name, description, realm_id |
| realm | Realm (tenant) | name, enabled, ssl_required |
| client (KC) | Cliente OIDC | client_id, secret, redirect_uris |
| RolTemplate (bAuth) | Contrato de privilegios | bos_perm_base, bos_perm_ui, bos_perm_vdi |
| BitMask 64-bit (bAuth) | Permisos codificados | logical[21], physical[21], financial[22] |

**Eventos emitidos:** keycloak.user.created, keycloak.user.disabled, keycloak.session.started, keycloak.role.assigned

### BC-05 — Comunicaciones

| Entidad | Descripcion | Atributos clave |
|---|---|---|
| mailbox (Postfix) | Buzon de correo | username, domain, quota |
| channel (Mattermost) | Canal de mensajeria | name, team_id, type |
| ws_channel (Centrifugo) | Canal WebSocket | namespace, channel_name, presence |

### BC-06 — Reportes e Inteligencia

| Entidad | Descripcion | Atributos clave |
|---|---|---|
| dashboard (Superset) | Dashboard publicado | title, owner, charts |
| dag (Airflow) | Pipeline de datos | dag_id, schedule, tasks |
| metadata_entity (OpenMetadata) | Catalogo de metadatos | fqn, type, owner |

### BC-07 — IA Soberana

| Entidad | Descripcion | Atributos clave |
|---|---|---|
| model_deployment (Ollama) | Modelo LLM desplegado | model_name, version, parameters |
| collection (Qdrant) | Indice vectorial | name, vectors_count, dimension |
| suggestion (bCompass) | Sugerencia de IA | route_id, type, status, confidence |
| search_result (bSearch) | Resultado de busqueda | query, results, relevance_score |

### BC-08 — Integracion Exterior (biedata)

| Entidad | Descripcion | Atributos clave |
|---|---|---|
| caja | Conector con sistema externo | manifest.yml, box_engine.yml |
| external_message | Mensaje recibido/enviado | source, destination, status, payload |
| circuit_breaker | Estado del circuito | target, state, failure_count |

### BC-09 — Plataforma

| Entidad | Descripcion | Atributos clave |
|---|---|---|
| ficha | Unidad de despliegue | manifest.yml, state, version |
| cluster_state | Estado K8s | nodes, pods, namespaces |
| sbos_state.json | Estado del IAM Installer | fichas_installed, health, last_check |

---

## 3. Relaciones entre Bounded Contexts

| Origen | Destino | Relacion DDD | Mecanismo |
|---|---|---|---|
| BC-02 (RRHH) | BC-01 (Financiero) | Customer-Supplier | WAL → bKernel → party.party |
| BC-03 (Ventas) | BC-01 (Financiero) | Customer-Supplier | WAL → bKernel → invoices |
| BC-04 (Identidad) | Todos | Shared Kernel (JWT) | JWT a todas las apps |
| BC-02 (RRHH) | BC-04 (Identidad) | Partnership | Email como vinculo |
| BC-05 (Comms) | BC-04 (Identidad) | Conformist | SSO Keycloak |
| BC-06 (Reportes) | Todos | Conformist (solo lectura) | Replica PostgreSQL |
| BC-07 (IA) | Todos | ACL via bCompass/bSearch | Redis Stream → embeddings |
| BC-08 (Integracion) | BC-01, BC-02, BC-03 | ACL (biedata) | Traduce modelos externos |
| BC-09 (Plataforma) | Todos | Shared Kernel infra | Base de ejecucion |

---

## 4. Fronteras del Dominio

### Dentro del alcance del SBOS
- Gestion financiera y contable (Tryton)
- RRHH completo (OrangeHRM)
- CRM y e-commerce (EspoCRM + Saleor)
- Comunicaciones internas (email, chat, WebSocket)
- Identidad y gobierno de acceso (Keycloak + bAuth)
- BI y reporteria (Superset + Airflow)
- IA soberana (Ollama + Qdrant + bCompass)
- Documentos y archivos (Paperless + Nextcloud)
- Escritorio corporativo (SBOS VDI)
- Integracion fiscal LATAM (SIN/AFIP/SAT via biedata)

### Fuera del alcance
- Manufactura avanzada (MRP extendido) — roadmap futuro
- E-learning / LMS (Moodle) — roadmap futuro
- Geolocalizacion avanzada (Traccar) — opcional, no core
- Telefonia IP (FreePBX) — integrado pero no core

---

## 5. Bases de Datos del Sistema

### Motor principal: PostgreSQL 17 (Patroni HA 3 nodos)

| Categoria | Bases de datos | Cantidad |
|---|---|---|
| Daemons soberanos | bkernel_db, biedata_db, bauth_db, bcompass_db, bos_db | 5 |
| Apps con PostgreSQL | tryton, keycloak, kong, saleor, espocrm, zammad + 24 mas | 30 |
| Apps con MySQL (excepciones) | orangehrm, asterisk/asteriskcdrdb, easyappointments | 3 |
| No-SQL / especializado | Redis, MinIO, Qdrant, Typesense, Elasticsearch, Prometheus, Loki | 7 |

### Replication Slots WAL

| Slot | Daemon | Escucha |
|---|---|---|
| bkernel_slot | bKernel | Cambios en TODAS las apps del stack |
| biedata_slot | biedata | Triggers de integracion con exterior |
| bcompass_slot | bCompass | Eventos para analisis de inteligencia |

### Extensions PostgreSQL requeridas
pg_replication_origin, pgcrypto, unaccent, pg_trgm, uuid-ossp, pg_stat_statements, timescaledb (opcional), citus (opcional)

---

## 6. Schemas de Base de Datos

Los schemas de las aplicaciones del stack son gestionados por cada app (Tryton, Keycloak, OrangeHRM, etc.) — el SBOS no los modifica. Esta es la esencia del principio de **cero invasion** (P2 en SBOS-004-RULES §1).

El DDL completo de las **5 BDs de daemons soberanos** (`bkernel_db`, `biedata_db`, `bauth_db`, `bcompass_db`, `bos_db`) esta en **SBOS-043-DATABASE-CATALOG §2** con las siguientes tablas:

| BD | Tablas definidas | Proposito |
|---|---|---|
| bkernel_db | bkernel_state, bkernel_dlq, bkernel_entity_crossref, bkernel_rule_log | Estado operacional bKernel |
| biedata_db | biedata_audit_log, biedata_dlq, biedata_circuit_state | Historial integraciones biedata |
| bauth_db | bauth_sync_log, bauth_drift_history, bauth_delegations, bauth_access_log | Log identidad bAuth |
| bcompass_db | bcompass_route_log, bcompass_feedback, bcompass_proposals | Rutas e IA bCompass |
| bos_db | bos_operation_log, bos_health_snapshot | Estado IAM Installer |

El catalogo completo de 40 BDs de aplicaciones (con servidor logico, notas y politica de backup) esta en **SBOS-043-DATABASE-CATALOG §5**.

---

## 7. Diagrama de Relaciones entre BCs

```
                    +------------------------------+
                    |  BC-09 PLATAFORMA             |
                    |  (Shared Kernel infra)        |
                    +--------------+---------------+
                                   |
              +-------------------+-------------------+
              |                   |                    |
   +----------v------+  +-------v-------+  +--------v----------+
   |  BC-04 IDENTIDAD|  |  BC-05 COMMS  |  |  BC-06 REPORTES   |
   |  (Shared K. JWT)|  |               |  |  (solo lectura)   |
   +----------+------+  +---------------+  +-------------------+
              | JWT
   +----------v------+  +---------------+
   |  BC-02 RRHH     |  |  BC-03 VENTAS |
   |  OrangeHRM      |  |  Saleor+Espo  |
   +----------+------+  +-------+-------+
              |                  |
              +------+-----------+
                     v
          +------------------+
          |  BC-01 FINANCIERO|        +--------------+
          |  Tryton (hub MDM)|<------>| BC-08 biedata|
          +------------------+        |  (ACL ext.)  |
                     |                +--------------+
                     v
          +------------------+
          |  BC-07 IA        |
          |  Qdrant+bCompass |
          +------------------+
```

---

## 8. V7 Enriquecimiento — Dominios de Autenticacion como Capa Transversal al Modelo de Dominio

El V7 introduce una reconceptualizacion del modelo de dominio al anadir los **dominios de autenticacion** como capa transversal que afecta a todos los BCs:

| Dominio de autenticacion | BC afectados | Impacto en el modelo de dominio |
|---|---|---|
| Logico | BC-04 (Identidad), BC-01 a BC-09 (todos) | LogicalDomainMask gobierna acceso a entidades en todos los BCs |
| Fisico | BC-04 (Identidad), BC-09 (Plataforma) | PhysicalDomainMask gobierna acceso fisico a endpoints |
| Financiero | BC-01 (Financiero-Contable) | FinancialDomainMask especifica para Tryton (SoD, limites, aprobaciones) |
| Red | BC-09 (Plataforma) | Control de acceso a red para todos los BCs |
| Aplicacion | BC-04 (Identidad), BC-01 a BC-09 | Permisos granulares por aplicacion dentro de cada BC |

### Correccion de nomenclatura V7

El modelo de dominio V7 corrige el error de colapsar dominios con tecnologias:

| Termino V6 | Termino V7 corregido | Dominio abstracto |
|---|---|---|
| ERPMask | LogicalDomainMask | Permisos de aplicaciones de negocio (no solo Tryton) |
| VDIMask | PhysicalDomainMask | Permisos de hardware y acceso fisico (no solo Fedora) |
| (ausente) | FinancialDomainMask | SoD, limites de transaccion, aprobaciones |

---

## 9. Smart* Enriquecimiento — Extension del Modelo de Dominio por Subproyecto

Cada subproyecto Smart* extiende los BCs existentes con entidades y relaciones propias de su dominio de negocio:

### SmartORC — Extension de BC-05 (Comunicaciones) y BC-06 (Reportes)

| Entidad SmartORC | Descripcion | BC base |
|---|---|---|
| hoja_ruta | Documento de correspondencia con ID unico e inmutable | BC-06 |
| transferencia_custodia | Transferencia entre responsables con firma WebAuthn | BC-04 |
| hilo_chat | Conversacion alrededor de un documento (paradigma conversacional) | BC-05 |
| despacho_externo | Documento transferido a bvault para entrega | BC-06 |

### SmartVaultFlow — Extension de BC-06 (Reportes)

| Entidad bvault | Descripcion | BC base |
|---|---|---|
| vault_id | Identificador unico permanente de activo documental | BC-06 |
| flujo_aprobacion | Ruta multi-firmante con plazos y escalamiento | BC-04 |
| ventanilla_virtual | Entrega controlada a destinatarios externos | BC-08 |

### SmartTax — Extension de BC-01 (Financiero) y BC-08 (Integracion)

| Entidad SmartTax | Descripcion | BC base |
|---|---|---|
| comprobante_fiscal | Factura electronica (SIN, AFIP, SAT) | BC-01 |
| invariante_fiscal | Regla de validacion fiscal por pais | BC-08 |
| envio_siat | Paquete XML firmado enviado a SIAT | BC-08 |

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1 Bounded Contexts | SBOS-022 v1.0 | §2 BC-01 a BC-09 completos |
| §2 Entidades | SBOS-022 v1.0, SBOS-040 v1.0 | Entidades de cada BC + DDL daemons |
| §3 Relaciones | SBOS-022 v1.0 | §3 Mapa de relaciones |
| §4 Fronteras | SBOS-002-ARCH v4.0, SBOS-022 v1.0 | §7 BCs, §16 Fronteras |
| §5 BDs | SBOS-040 v1.0 | §2 BDs daemons, §3 BDs apps |
| §6 Schemas | SBOS-043-DATABASE-CATALOG v1.0 | §2 DDL 5 BDs daemons |
| §7 Diagrama | SBOS-022 v1.0 | §3 Context Map |
| §8 V7 | BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md | Dominios como capa transversal, correccion nomenclatura V7 |
| §9 Smart* | BOSORC-002-DOMINIO, SBOS-VAULT-002-DOMINIO, SBOS_TAX_00_PLAN_MAESTRO_INGENIERIA_v6.md, SBOS-Rates-002-DOMINIO, SBOS-PAY-002-DOMINIO, SBOS-REPORT-002-DOMINIO, BOSCMS-002-DOMINIO | Extensiones de dominio por subproyecto |

---

## Fuentas de Enriquecimiento V8

| Fuente | Tipo | Contenido aportado |
|---|---|---|
| BOS_V6_SBOS-003-DOMAIN.md | V6 (canonico) | Contenido base completo preservado |
| BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md | V7 | Dominios como capa transversal, correccion nomenclatura, tabla de impacto |
| BOSORC-002-DOMINIO.md (Smart ORC) | Smart* | Entidades de correspondencia (hoja_ruta, transferencia_custodia, hilo_chat) |
| SBOS-VAULT-002-DOMINIO.md (Smart Vault Flow) | Smart* | Entidades de vault documental (vault_id, flujo_aprobacion, ventanilla) |
| SBOS-Rates-002-DOMINIO.md (Smart Rates) | Smart* | Entidades de pricing |
| SBOS-PAY-002-DOMINIO.md (Smart Pay) | Smart* | Entidades de pagos |
| SBOS-REPORT-002-DOMINIO.md (Smart Report) | Smart* | Entidades de reportes |
| SBOS_TAX_00_PLAN_MAESTRO_INGENIERIA_v6.md (Smart Tax) | Smart* | Entidades fiscales (comprobante, invariante, envio SIAT) |

---

_SKULL · SBOS · SBOS-003-DOMAIN · HUMAN-DOC v1.1-V8 · Mayo 2026_
_Enriquecimiento V8: V7 dominios como capa transversal + correccion de nomenclatura + Smart* extensiones de dominio por subproyecto_
