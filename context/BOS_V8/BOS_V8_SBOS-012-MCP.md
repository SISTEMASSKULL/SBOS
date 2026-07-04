# SBOS-012-MCP
## Servidores MCP del Ecosistema SBOS — Estándar HUMAN-DOC
### SKULL · SBOS · V8 · Mayo 2026

---

## 1. Arquitectura MCP del SBOS

El Model Context Protocol (MCP) es un protocolo abierto (JSON-RPC 2.0) que estandariza la comunicación entre modelos de lenguaje y sistemas externos. Según las mejores prácticas de la industria (Anthropic, Google Cloud, especificación MCP 2025-11-25), cada servidor MCP expone 3 primitivas: **Tools** (acciones ejecutables), **Resources** (datos de solo lectura), **Prompts** (templates de instrucción). El SBOS implementa MCP para que bCompass (el daemon de IA soberana) acceda de forma segura y estandarizada a todos los subsistemas.

### Principios de diseño MCP en SBOS

| Principio | Implementación |
|---|---|
| Un servidor por responsabilidad | Cada daemon/servicio tiene su propio MCP server |
| Least-privilege | Cada MCP server expone solo lo que bCompass necesita |
| Auth via KC JWT | Todos los MCP servers verifican JWT de KC antes de responder |
| Transport stdio para daemons locales | bKernel, bAuth, bSearch usan Unix socket (mismo host) |
| Transport HTTP+SSE para servicios K8s | KC, Kong, PG, Vault usan HTTP dentro del cluster |
| Sin acceso directo a BD | Los MCP servers encapsulan la lógica — bCompass nunca ejecuta SQL crudo |
| HITL obligatorio para escrituras | Toda Tool que modifica datos requiere aprobación humana (bCompass proposal) |

### Diagrama

```
bCompass (MCP Host)
  │
  ├── stdio ──► MCP-bKernel (Unix socket)
  ├── stdio ──► MCP-bAuth (Unix socket)
  ├── stdio ──► MCP-bSearch (Unix socket)
  ├── HTTP  ──► MCP-PostgreSQL (cluster interno)
  ├── HTTP  ──► MCP-Keycloak (Admin API)
  ├── HTTP  ──► MCP-Kong (Admin API)
  ├── HTTP  ──► MCP-Vault (Vault API)
  ├── HTTP  ──► MCP-Prometheus (PromQL API)
  ├── HTTP  ──► MCP-Release (Release Server API)
  └── HTTP  ──► MCP-Tryton (XML-RPC)
```

## 2. Catálogo de Servidores MCP

### MCP-01: mcp-postgresql

| Campo | Valor |
|---|---|
| Daemon/Servicio | PostgreSQL 17 (S01 dataserver) |
| Transport | HTTP (puerto 5432 via PgBouncer) |
| Auth | JWT KC → rol `mcp-reader` en PG |

**Tools:**
| Tool | Descripción | HITL |
|---|---|---|
| `query_readonly` | Ejecuta SELECT en cualquier BD del catálogo (SBOS-043). Read-only, timeout 30s | No |
| `explain_query` | Ejecuta EXPLAIN ANALYZE de un SELECT (sin ejecutar) | No |
| `list_databases` | Lista todas las BDs del cluster con tamaño y owner | No |
| `table_schema` | Retorna DDL de una tabla específica (columnas, tipos, constraints, índices) | No |
| `table_stats` | Retorna estadísticas de una tabla (filas, tamaño, dead tuples, last vacuum) | No |

**Resources:**
| Resource | Descripción |
|---|---|
| `pg://databases` | Lista de 40 BDs con owner, servidor lógico, criticidad |
| `pg://schemas/{db}` | Schemas y tablas de una BD específica |
| `pg://extensions` | Extensions PG instaladas (SBOS-043 §4) |
| `pg://replication_slots` | Estado de los 3 slots WAL (bkernel, biedata, bcompass) |

**Restricciones:** Solo SELECT. Sin INSERT/UPDATE/DELETE. Sin DDL. Sin acceso a pg_authid ni tablas de credenciales.

---

### MCP-02: mcp-bkernel

| Campo | Valor |
|---|---|
| Daemon | bKernel (systemd host) |
| Transport | stdio (Unix socket /run/bos/bkernel-mcp.sock) |
| Auth | Proceso local (mismo usuario systemd) |

**Tools:**
| Tool | Descripción | HITL |
|---|---|---|
| `get_wal_lag` | Retorna lag actual del WAL en ms | No |
| `get_dlq_summary` | Retorna conteo DLQ por regla, status, antigüedad | No |
| `get_dlq_events` | Lista eventos de la DLQ con detalle (primeros N) | No |
| `retry_dlq_event` | Reintenta un evento específico de la DLQ | **Sí** |
| `get_crossref` | Busca en entity_crossref (ej: "¿cuál es el party de Tryton para el empleado #45 de OrangeHRM?") | No |
| `get_rule_stats` | Estadísticas de ejecución de reglas (éxitos, fallos, duración promedio) | No |
| `list_rules` | Lista todas las reglas YAML activas con sus triggers | No |

**Resources:**
| Resource | Descripción |
|---|---|
| `bkernel://state` | Estado del daemon (active/paused/recovering), último LSN, eventos procesados |
| `bkernel://rules/{rule_id}` | Contenido YAML de una regla específica |
| `bkernel://metrics` | Métricas Prometheus del bKernel (throughput, latencia, errores) |

**Integración con Smart* CMS:** bKernel es el bus de integración reactivo para el
ecosistema SBOS. Escucha el WAL de PostgreSQL (latencia <50μs), evalúa reglas YAML
y propaga cambios. En el contexto de SBOS CMS, bKernel reacciona a eventos WAL en
tablas de comercio (orders, products) y propaga ctx_id a Tryton para trazabilidad
fiscal. Ver SBOS CMS B-01 ctx_id para detalle de integración WAL→Tryton.

---

### MCP-03: mcp-bauth

| Campo | Valor |
|---|---|
| Daemon | bAuth (systemd host) |
| Transport | stdio (Unix socket /run/bos/bauth-mcp.sock) |

**Tools:**
| Tool | Descripción | HITL |
|---|---|---|
| `evaluate_access` | Simula evaluación de acceso para un usuario+nodo+dominio (dry run) | No |
| `get_user_bitmask` | Retorna BitMask 64-bit actual de un usuario con desglose de bits | No |
| `get_template` | Retorna un RolTemplate o UserTemplate completo | No |
| `list_templates` | Lista todos los templates con tipo y estado | No |
| `get_drift_history` | Historial de correcciones de drift KC↔Tryton | No |
| `get_delegations` | Delegaciones temporales activas | No |
| `create_delegation` | Crear delegación temporal de rol | **Sí** |
| `get_access_log` | Últimos N accesos de un usuario con resultado grant/deny | No |

**Resources:**
| Resource | Descripción |
|---|---|
| `bauth://sync_status` | Estado de sincronización KC↔Tryton (último sync, errores) |
| `bauth://stats` | Estadísticas: accesos grant/deny último día, drifts corregidos |

---

### MCP-04: mcp-bsearch

| Campo | Valor |
|---|---|
| Daemon | bSearch (systemd host) |
| Transport | stdio (Unix socket /run/bos/bsearch-mcp.sock) |

**Tools:**
| Tool | Descripción | HITL |
|---|---|---|
| `search` | Búsqueda federada (Typesense full-text + Qdrant semántica). Retorna resultados rankeados con links | No |
| `search_entity` | Búsqueda específica por tipo de entidad (empleado, factura, producto, cliente) | No |
| `get_index_stats` | Estado de los índices Typesense y colecciones Qdrant | No |
| `reindex` | Forzar reindexación de una entidad o tabla | **Sí** |

**Resources:**
| Resource | Descripción |
|---|---|
| `bsearch://indices` | Lista de índices Typesense con conteo de documentos |
| `bsearch://collections` | Colecciones Qdrant con conteo de vectores |

---

### MCP-05: mcp-keycloak

| Campo | Valor |
|---|---|
| Servicio | Keycloak 26.x (S03 identityserver) |
| Transport | HTTP (Admin REST API via Kong) |
| Auth | JWT con scope `admin` del realm master |

**Tools:**
| Tool | Descripción | HITL |
|---|---|---|
| `list_users` | Lista usuarios de un realm con filtros (email, grupo, enabled) | No |
| `get_user` | Detalle completo de un usuario (atributos, roles, grupos, sesiones) | No |
| `list_realms` | Lista realms con estadísticas (usuarios, clients, sesiones activas) | No |
| `list_clients` | Clients OIDC de un realm | No |
| `get_user_sessions` | Sesiones activas de un usuario | No |
| `disable_user` | Deshabilitar un usuario | **Sí** |
| `assign_role` | Asignar rol a un usuario | **Sí** |

**Resources:**
| Resource | Descripción |
|---|---|
| `keycloak://realm/{name}` | Configuración del realm (auth flows, token settings) |
| `keycloak://events` | Últimos eventos de admin y login (auditoría) |

---

### MCP-06: mcp-kong

| Campo | Valor |
|---|---|
| Servicio | Kong API Gateway (S02 gatewayserver) |
| Transport | HTTP (Admin API puerto 8001) |

**Tools:**
| Tool | Descripción | HITL |
|---|---|---|
| `list_routes` | Todas las rutas configuradas con service y plugins | No |
| `list_services` | Servicios registrados con upstream | No |
| `get_rate_limiting` | Estado del rate limiting por consumer/ruta | No |
| `list_consumers` | Consumers OAuth2 registrados | No |

**Resources:**
| Resource | Descripción |
|---|---|
| `kong://status` | Estado del gateway (BD, configuración, uptime) |
| `kong://plugins` | Plugins activos por ruta |

---

### MCP-07: mcp-vault

| Campo | Valor |
|---|---|
| Servicio | HashiCorp Vault (S03 identityserver) |
| Transport | HTTP (Vault API) |
| Auth | AppRole con política read-only para bCompass |

**Tools:**
| Tool | Descripción | HITL |
|---|---|---|
| `list_secrets` | Lista paths de secretos (sin valores) | No |
| `get_lease_status` | Estado de leases activos (expiración, renovación) | No |
| `get_pki_certs` | Certificados PKI emitidos con expiración | No |
| `check_seal_status` | Estado sealed/unsealed de Vault | No |

**Restricciones:** NUNCA retorna valores de secretos. Solo metadata (paths, leases, expiración).

---

### MCP-08: mcp-prometheus

| Campo | Valor |
|---|---|
| Servicio | Prometheus (S12 monitorserver) |
| Transport | HTTP (PromQL API puerto 9090) |

**Tools:**
| Tool | Descripción | HITL |
|---|---|---|
| `query` | Ejecuta PromQL instantáneo | No |
| `query_range` | Ejecuta PromQL con rango de tiempo | No |
| `get_alerts` | Alertas activas en Alertmanager | No |
| `get_slo_status` | Estado de SLOs (SBOS-032) con error budget restante | No |

**Resources:**
| Resource | Descripción |
|---|---|
| `prometheus://targets` | Scrape targets con estado up/down |
| `prometheus://rules` | Reglas de alertas configuradas |

---

### MCP-09: mcp-release

| Campo | Valor |
|---|---|
| Servicio | SKULL Release Server (externo) |
| Transport | HTTP (API release.skull.systems) |

**Tools:**
| Tool | Descripción | HITL |
|---|---|---|
| `get_latest_version` | Última versión disponible por canal (canary/early/stable) | No |
| `get_changelog` | Changelog de una versión específica | No |
| `get_fichas_catalog` | Catálogo de fichas disponibles con versiones | No |
| `check_update_available` | ¿Hay update pendiente para este sistema? | No |

---

### MCP-10: mcp-tryton

| Campo | Valor |
|---|---|
| Servicio | Tryton ERP (S04 erpserver) |
| Transport | HTTP (XML-RPC via Kong) |
| Auth | JWT KC con scope ERP |

**Tools:**
| Tool | Descripción | HITL |
|---|---|---|
| `search_records` | Buscar registros en cualquier modelo Tryton (party, invoice, sale, purchase) | No |
| `read_record` | Leer un registro específico con todos sus campos | No |
| `get_chart_of_accounts` | Plan de cuentas completo | No |
| `get_fiscal_periods` | Períodos fiscales con estado (abierto/cerrado) | No |
| `create_record` | Crear registro en Tryton | **Sí** |
| `get_report` | Generar reporte (ventas, inventario, balance) | No |

---

## 3. Matriz de Permisos HITL

| Acción | HITL Requerido | Razón |
|---|---|---|
| Lectura de datos (SELECT, search, list) | No | Solo lectura, sin riesgo |
| Simulación/dry-run (explain, evaluate) | No | No modifica estado |
| Reintento DLQ | **Sí** | Puede duplicar efectos colaterales |
| Delegación temporal | **Sí** | Otorga permisos a otro usuario |
| Deshabilitar usuario KC | **Sí** | Revoca acceso a todo el sistema |
| Asignar rol KC | **Sí** | Modifica permisos del usuario |
| Crear registro Tryton | **Sí** | Modifica datos de negocio |
| Reindexar bSearch | **Sí** | Consume recursos intensivos |

**Regla general:** si la Tool modifica estado o datos, requiere HITL. bCompass genera una `proposal` (SBOS-027 §bcompass_proposals) que el humano aprueba o rechaza.

## 4. Seguridad MCP

| Control | Implementación |
|---|---|
| Autenticación | JWT KC verificado en cada request HTTP. Unix socket con permisos FS para stdio |
| Autorización | Políticas read-only por defecto. Escrituras solo vía proposals aprobadas |
| Rate limiting | 100 req/min por MCP server (Kong plugin) |
| Audit | Toda invocación logueada en bcompass_route_log con langfuse_trace_id |
| Secretos | MCP-Vault NUNCA retorna valores — solo metadata |
| Timeout | 30s por default, 120s para queries complejas (configurable) |
| OAuth Resource Server | Según especificación MCP 2025-11-25, cada MCP server es un OAuth Resource Server con Resource Indicators (RFC 8707) |

## 5. Configuración bCompass (mcp_servers.toml)

```toml
[[mcp_servers]]
name = "mcp-postgresql"
transport = "http"
url = "http://pgbouncer.sbos-data.svc:5432"
auth = "jwt"
timeout_seconds = 30

[[mcp_servers]]
name = "mcp-bkernel"
transport = "stdio"
socket = "/run/bos/bkernel-mcp.sock"
auth = "local"

[[mcp_servers]]
name = "mcp-bauth"
transport = "stdio"
socket = "/run/bos/bauth-mcp.sock"
auth = "local"

[[mcp_servers]]
name = "mcp-bsearch"
transport = "stdio"
socket = "/run/bos/bsearch-mcp.sock"
auth = "local"

[[mcp_servers]]
name = "mcp-keycloak"
transport = "http"
url = "https://keycloak.sbos-identity.svc/admin/realms"
auth = "jwt"
scope = "admin"

[[mcp_servers]]
name = "mcp-kong"
transport = "http"
url = "http://kong.sbos-gateway.svc:8001"
auth = "jwt"

[[mcp_servers]]
name = "mcp-vault"
transport = "http"
url = "http://vault.sbos-identity.svc:8200/v1"
auth = "approle"
policy = "mcp-readonly"

[[mcp_servers]]
name = "mcp-prometheus"
transport = "http"
url = "http://prometheus.sbos-monitor.svc:9090/api/v1"
auth = "none"  # interno cluster, NetworkPolicy protege

[[mcp_servers]]
name = "mcp-release"
transport = "http"
url = "https://release.skull.systems/api/v1"
auth = "ed25519"

[[mcp_servers]]
name = "mcp-tryton"
transport = "http"
url = "http://tryton.sbos-erp.svc:8000"
auth = "jwt"
```

---

## 6. Integración MCP en el Ecosistema Smart*

Los servidores MCP del SBOS sirven como puente de integración para todos los
subproyectos Smart* del ecosistema. Cada subproyecto puede consumir los MCP servers
a través de bCompass para operaciones de lectura/escritura autorizadas:

| Subproyecto | MCP Server Clave | Caso de Uso |
|---|---|---|
| SBOS CMS | mcp-bkernel, mcp-tryton | ctx_id en eventos WAL, pedidos Medusa a Tryton |
| SBOS Smart ORC | mcp-bauth, mcp-vault | Correspondencia segura, vault flow |
| SBOS Smart Pay | mcp-postgresql, mcp-tryton | Consultas de crédito, reconciliación contable |
| SBOS Smart Tax | mcp-postgresql, mcp-tryton | Facturación electrónica, planes de cuentas |
| SBOS Smart Report | mcp-postgresql | Generación de reportes, catálogo de reportes |
| SBOS Tryton | mcp-tryton, mcp-bkernel | Operaciones ERP, sincronización contable |
| SBOS Smart Vault Flow | mcp-vault, mcp-bauth | Custodia documental, firmas autorizadas |

El MCP server de bKernel (MCP-02) es particularmente relevante para la integración
Smart* porque expone el bus de eventos WAL del ecosistema. Cada subproyecto puede
suscribirse a eventos de tablas específicas vía reglas YAML de bKernel.

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1 Arquitectura | Investigación web + conocimiento ecosistema SBOS | MCP spec 2025-11-25, Google Cloud MCP guide, Anthropic best practices |
| §2 Catálogo 10 servers | Síntesis de SBOS-010 (bKernel), SBOS-008 (RolFramework/bAuth), SBOS-013 (bSearch), SBOS-014 (bCompass), SBOS-019 (KC), SBOS-024 (Operations), SBOS-040 (Database Catalog) | Tools/Resources derivados de las APIs internas de cada daemon/servicio |
| §3 HITL | SBOS-014 v4.0 | bCompass proposals + HITL pattern |
| §4 Seguridad | Investigación web | MCP spec security, OAuth Resource Server, RFC 8707 |
| §5 Config | Conocimiento ecosistema | Puertos, sockets, auth methods de cada servicio SBOS |
| §6 Smart* | SBOS CMS B-01, subproyectos Smart* | Integración MCP en el ecosistema Smart* |

---

## Fuentes de Enriquecimiento V8

| Fuente | Ruta | Tipo | Detalle |
|---|---|---|---|
| BOS_V6_SBOS-012-MCP.md | Procesar/ | V6 Base | Contenido completo preservado |
| SBOS CMS B-01 CTX-ID-BKERNEL.md | sbos/subproyectos/ | Smart* | bKernel como bus reactivo WAL, ctx_id propagation |
| SBOS-IAM-Style 09 dev-environment-setup.md | sbos/subproyectos/ | Smart* | Integración MCP con herramientas de desarrollo |

---

_SKULL · SBOS · SBOS-012-MCP · V8 · Mayo 2026_
