# SBOS-026-DAEMON-BSEARCH
## bSearch: Motor de Búsqueda Federada — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Identidad

| Campo | Valor |
|---|---|
| Nombre | bSearch: Sovereign Federated Intelligent Search (RAG) |
| Daemon | `bsearch` |
| Servicio | `bsearch.service` |
| Unidad declarativa | Patrón de búsqueda (en `patterns/`) |
| Directorio | `/etc/bsearch/patterns/<app>/` |
| Índice | Meilisearch (multi-tenant por realm) |
| Input | Redis Stream `bkernel:index_queue` + SQL SELECT directo (solo lectura) |
| Auth | Keycloak JWT (realm = tenant isolation) |

## 2. Las 3 Dimensiones del Problema

1. **Búsqueda universal** — encontrar dato en cualquier app con una consulta
2. **Routing a entidad** — deep-link directo al formulario correcto vía `sbos://`
3. **Investigación por pista** — dato ambiguo (monto, número) → mapa de dónde aparece

## 3. Meta-Patrón de Daemons SBOS

| Daemon | Unidad | Motor | Agregar capacidad |
|---|---|---|---|
| IAM Installer | Ficha en servers/ | 00_MASTER_INSTALL.sh | Crear carpeta servers/ |
| bKernel | Regla en rules/ | Rule Engine | Crear YAML en rules/ |
| biedata | Caja en boxes/ | Box Engine | Crear carpeta boxes/ |
| bCompass | Ruta en router/ | Route Engine | Crear carpeta router/ |
| **bSearch** | **Patrón en patterns/** | **Search Engine** | **Crear carpeta patterns/** |

## 4. Dos Modos de Búsqueda

| Modo | Cuándo | Cómo | Latencia |
|---|---|---|---|
| Indexado (Meilisearch) | Búsqueda global | Índice pre-construido vía bKernel | < 50ms |
| Directo (SQL SELECT) | Widget dentro de app | SELECT solo lectura + pg_trgm | Tiempo real — cero lag |

## 5. Widget bSearch

### 3 Puntos de Anclaje

| Anclaje | Nivel | Scope |
|---|---|---|
| Barra tareas KDE `Meta+Space` | 0 Global | Todas las apps del realm |
| sbos-app-container `Ctrl+K` | 1 Aplicación | Solo la app actual |
| Core UI header | 0 Global | Realm del administrador |

### 2 Modos del Widget

| Modo | Cuándo | Qué hace |
|---|---|---|
| Estándar | Coincidencia alta confianza | Resultados agrupados por app, ordenados por relevancia |
| Investigación (`Ctrl+Shift+K`) | Consulta ambigua (monto, número, pista) | Busca en TODOS los campos → mapa por tipo de documento |

Freshness indicator: cada resultado muestra cuándo fue indexado. Panel de cobertura: qué apps se buscaron, cuáles no y por qué.

Regla de scope: el anfitrión declara, el widget obedece. Scope solo desciende, nunca se amplía.

## 6. Motor de Relevancia — 7 Capas

| Capa | Función |
|---|---|
| 0 | Normalización por tipo (text→minúsculas+unaccent, numeric→sin separadores, date→ISO, code→sin guiones) |
| 1 | Pre-procesamiento texto (acentos, puntuación) |
| 2 | Expansión semántica (synonyms/business.yml, corrections/business_states.yml) |
| 3 | Tolerancia typos: Damerau-Levenshtein (nombres sí, números/NIT/SKU no) |
| 4 | Keyboard Distance Model (teclas físicamente cercanas = mayor similitud) |
| 5 | pg_trgm en modo directo (similarity > 0.30 para texto, exacto para números) |
| 6 | Ranking cascada: exacta campo alta prioridad → fuzzy 1 error → sinónimo → prefijo → recencia |

## 7. Patrones de Búsqueda — 4 Contratos

```
/etc/bsearch/patterns/<app>/
├── manifest.yml         ← app_id, status (DRAFT→APPROVED→ACTIVE), coverage
├── connection.yml       ← db_host, db_user (SELECT only), pg_extensions
├── entities/
│   ├── invoices.yml     ← tabla, joins, campos con weight/typo_tolerance/field_type
│   ├── parties.yml      ← routing uri_pattern sbos://
│   └── products.yml
└── forms/
    └── invoice_form.yml ← display (title, subtitle, meta_fields, quick_actions)
```

### Ejemplo entities/invoices.yml

```yaml
entity_type: document
entity_subtype: invoice
source:
  table: account_invoice
  joins: [{ table: party_party, on: "account_invoice.party = party_party.id" }]
fields:
  - name: number      column: account_invoice.number   field_type: code   weight: 10 typo_tolerance: false
  - name: party_name  column: party_party.name         field_type: text   weight: 8  typo_tolerance: true
  - name: total_amount column: account_invoice.total_amount field_type: numeric weight: 5
  - name: state        column: account_invoice.state    filterable: true display: true
routing:
  uri_pattern: "sbos://erp/open/invoice?id={id}"
```

## 8. Contrato bsearch_config en Fichas

```yaml
# En manifest.yml de cada ficha del IAM Installer
bsearch_config:
  enabled: true
  priority: high           # high=5min | medium=30min | low=2h re-indexación
  schema_discoverer: auto  # auto | manual
  index_entities:
    - entity: invoice
      table: account_invoice
      primary_field: number
      display_fields: [number, party, amount_total]
      searchable_fields: [number, party, amount_total]
      routing:
        uri_pattern: "sbos://erp/open/invoice?id={id}"
```

Fichas sin entidades buscables: `bsearch_config: { enabled: false }` (Redis, VDI).

## 9. Evento bKernel → bSearch (Redis Stream)

```json
{
  "event_id": "bk-1741891234567-0",
  "event_type": "index_update",
  "source": {
    "app_id": "tryton",
    "table": "account_invoice",
    "operation": "UPDATE",
    "record_id": 3451,
    "realm": "empresa_abc"
  },
  "payload": {
    "after": { "id": 3451, "number": "INV-3451", "party": "Constructora Andina", "total_amount": 45200, "state": "posted" },
    "changed_fields": ["state"]
  },
  "index_hints": {
    "entity_type": "invoice",
    "index_name": "document_invoice_empresa_abc",
    "action": "upsert"
  }
}
```

Tipos: index_update, index_delete, index_create, schema_change. Consumer Group: `bsearch_indexer`. Dead-letter en fallos 3x.

## 10. Schema Discoverer — 5 Fases Idempotentes

| Fase | Qué hace |
|---|---|
| 1 Detección | ¿manifest existe? ¿versión cambió? → respeta `human_edited: true` |
| 2 Extractor estructural | pg_catalog → tablas, campos, tipos, FKs, índices (determinístico, sin LLM) |
| 3 Análisis semántico | aiserver (Ollama qwen3-coder:30b) → labels español, pesos, tipos entidad, routing |
| 4 Generación patrones | Deposita YAML en patterns/<app>/ con status: DRAFT |
| 5 Notificación | Core UI → admin revisa → APPROVED → ACTIVE |

Triggers: IAM Installer instala/actualiza app, admin ejecuta manual.

## 11. Search Learning Engine

### Distinción fundamental: 2 clases de error

| | Caso A — Error teclado usuario | Caso B — Error en dato almacenado |
|---|---|---|
| Búsqueda | "tpiota" (mal escrito) | "toyota" (bien escrito) |
| Dato BD | "Toyota S.A." (correcto) | "tpiota" (incorrecto) |
| Aprende | **Nada — no contaminar** | Puente temporal en data_errors.yml |
| Acción BD | Ninguna | Reparación vía bCompass |

Diálogo de clarificación: el usuario confirma qué pasó → Ruta A descarta, Ruta B registra, Ruta C acumula.

### 3 Tipos de conocimiento acumulable

| Tipo | Archivo destino | Ejemplo |
|---|---|---|
| Alias entidad | synonyms/discovered.yml | "IBM" = razón social completa |
| Abreviatura negocio | synonyms/business.yml | cxc, oc, nc, rrhh |
| Error dato almacenado | corrections/data_errors.yml | "tpiota" → "toyota" |

## 12. 4 Rutas bCompass

| Ruta | Tipo | Trigger | Función |
|---|---|---|---|
| bsearch_data_repair | flow | Evento data_repair_request | Reparar dato en BD app |
| bsearch_quality_agent | analyst | Schedule diario 3AM | Detectar errores proactivamente |
| bsearch_synonym_discovery | analyst | Schedule semanal lunes | Descubrir vocabulario negocio |
| bsearch_nlu_rewriter | agent | Evento nlu_rewrite_request | Lenguaje natural → filtros Meilisearch |

NLU ejemplo: "facturas sin pagar del mes" → `{entity_type: document, filters: "state != paid", date_filter: ">=2026-03-01"}`

## 13. Arquitectura del Daemon

```
CAPA 1 — CONOCIMIENTO ESTRUCTURAL: patterns/<app>/ (Schema Discoverer)
CAPA 2 — CONOCIMIENTO SEMÁNTICO: synonyms/ + corrections/ (Learning Engine + bCompass)
CAPA 3 — MOTOR DE BÚSQUEDA:
  INDEXER (Redis Stream consumer) · MEILISEARCH · API SERVER (JWT + scope)
  SCOPE REGISTRY · SCHEMA DISCOVERER · LEARNING ENGINE
CAPA 4 — WIDGET: textbox agnóstico, scope declarado por anfitrión
```

## 14. Multi-Tenant

Índices separados físicamente por `entity_type + realm`. Realm extraído del JWT, nunca del cliente. Tenant Tokens Meilisearch: JWT firmado por API key maestra restringe índices accesibles.

## 15. 11 Fronteras Inviolables

| # | Regla | Consecuencia |
|---|---|---|
| B1 | Solo lectura en BDs apps (SELECT) | Modificación accidental |
| B2 | Solo escribe en su índice y patrones | Corrupción datos |
| B3 | Realm del JWT, nunca del cliente | Fuga cross-tenant |
| B4 | Errores teclado usuario nunca al diccionario | Contaminar conocimiento |
| B5 | Scope lo declara el anfitrión | Resultados fuera de contexto |
| B6 | Scope solo desciende | Apps fuera del contexto |
| B7 | Patrones DRAFT nunca activos | Búsqueda en estructuras no validadas |
| B8 | Reparaciones vía bCompass | Sin trazabilidad |
| B9 | aiserver criticality false (modo degradado OK) | Búsqueda bloqueada |
| B10 | Datos indexados = proyecciones con lag (siempre deep-link) | Decisiones sobre datos desactualizados |
| B11 | Vocabulario solo vía bCompass con aprobación | Cambios no trazables |

## 16. Calidad de Búsqueda

| Dimensión | Nota v5.0 |
|---|---|
| Búsqueda exacta | 10/10 |
| Typos usuario | 9/10 |
| Errores datos almacenados | 8/10 |
| Abreviaturas/sinónimos | 8/10 |
| Lenguaje natural | 7/10 |
| Cross-app multi-contexto | 10/10 |
| Routing a entidad | 10/10 |
| Autocorrección | 9/10 |
| Búsqueda semántica vectorial | 0/10 (Fase 4) |
| **Global** | **8.8/10** |

## 17. Posicionamiento vs Industria

| Sistema | Lo que adopta bSearch | Lo que supera |
|---|---|---|
| Glean/Guru | Índice centralizado, multi-fuente, routing | CDC vs polling (segundos vs horas) |
| Odoo Global Search | SQL SELECT directo | Busca en 110+ apps, no solo una |
| Elasticsearch | Motor dedicado, pipeline desacoplado | Sin JVM — Meilisearch nativo |
| Windows 11 Search | Widget textbox + panel + teclado | Datos de negocio del realm |
| Google "Did you mean" | Detección typos | **Distingue error usuario vs error dato** |

---

## §18 — ENRIQUECIMIENTO V5: Indexación, Fuzzy Search y Smart Routing

### V5-1: Motor de Indexación (desde SBOS-013-001 v1.0)

```
bkernel procesa evento WAL
  │
  ├── Regla con acción "enqueue" → target: "bsearch"
  │     └── Publica en Redis: bsearch:index_queue
  │
  ▼
bsearch Index Worker (loop continuo)
  │
  ├── Lee de Redis: bsearch:index_queue
  ├── Normaliza documento (lowercase, strip accents, tokenize)
  ├── Genera embedding via Embedding Worker (Ollama nomic-embed-text)
  ├── Indexa en Qdrant (vector) + Typesense (full-text)
  └── Confirma procesamiento (Redis ACK)
```

### V5-2: Estrategia de Indexación por App (desde SBOS-013-001 v1.0)

| Aplicación | Tabla/Entidad | Campos indexados | Frecuencia | Tipo |
|---|---|---|---|---|
| Tryton | party.party | name, email, vat_number, phone | Evento WAL | Incremental |
| Tryton | account.invoice | number, date, total, party_name | Evento WAL | Incremental |
| Tryton | sale.sale | number, date, party_name, total | Evento WAL | Incremental |
| Tryton | product.product | name, code, description, list_price | Evento WAL | Incremental |
| OrangeHRM | hs_hr_employee | emp_firstname, emp_lastname, emp_work_email | Evento WAL | Incremental |
| Saleor | product_product | name, description, slug | Evento WAL | Incremental |
| Paperless-NGX | documents_document | title, content (OCR), correspondent | Evento WAL | Incremental |
| Wiki.js | pages | title, content, path | Evento WAL | Incremental |
| Zammad | tickets | title, note, customer_name | Evento WAL | Incremental |

### V5-3: Reindexación Completa (desde SBOS-013-001 v1.0)

```bash
bosctl bsearch reindex --app=tryton          # reindexar una app
bosctl bsearch reindex --all                 # reindexar todo
bosctl bsearch reindex --app=tryton --since=2026-03-01  # desde fecha

# El proceso:
# 1. Marca índice como "reindexing" (búsquedas siguen funcionando con índice actual)
# 2. Crea índice temporal nuevo
# 3. Lee todos los registros de la BD fuente
# 4. Indexa batch por batch (1000 docs por batch)
# 5. Swap atómico: índice temporal → índice activo
# 6. Elimina índice anterior
# Tiempo estimado: ~5 min por 100k documentos
```

### V5-4: Pipeline de Fuzzy Search Multi-Capa (desde SBOS-013-001 v1.0)

```
Query del usuario: "facura 345"
  │
  ▼
CAPA 1: Normalización
  ├── Lowercase: "facura 345"
  ├── Strip accents: "facura 345"
  └── Tokenize: ["facura", "345"]

CAPA 2: Corrección ortográfica
  ├── Diccionario de sinónimos: "facura" → ¿"factura"?
  │   Levenshtein distance("facura", "factura") = 1 → SÍ, corregir
  └── Query corregida: ["factura", "345"]

CAPA 3: Expansión de sinónimos
  ├── "factura" → ["factura", "fra", "fact", "comprobante", "invoice"]
  └── Query expandida: ["factura|fra|fact|comprobante|invoice", "345"]

CAPA 4: Heurística de teclado
  ├── Si Levenshtein no encuentra match:
  │   Generar variantes por proximidad de teclas
  │   "facyura" → "factura" (y→t son teclas adyacentes)
  └── Solo se aplica si las capas anteriores no resuelven

CAPA 5: Búsqueda federada
  ├── Typesense: full-text search con fuzzy en todos los índices
  ├── Qdrant: semantic search con embedding de la query
  └── Merge: combinar resultados por relevancia ponderada
```

### V5-5: Diccionario de Sinónimos (desde SBOS-013-001 v1.0)

```yaml
# /etc/bos/blibs/bsearch/dictionaries/es.yml
synonyms:
  factura: ["fra", "fact", "comprobante", "invoice", "boleta"]
  cliente: ["customer", "comprador", "party"]
  producto: ["item", "artículo", "mercadería", "product"]
  empleado: ["trabajador", "staff", "employee", "colaborador"]
  pago: ["payment", "cobro", "abono", "transferencia"]
  venta: ["sale", "pedido", "order"]
  inventario: ["stock", "existencia", "almacén"]

abbreviations:
  nit: "número de identificación tributaria"
  cuf: "código único de facturación"
  ruc: "registro único de contribuyente"
```

### V5-6: Verificación de Permisos en Resultados (desde SBOS-013-001 v1.0)

bSearch SIEMPRE verifica con bAuth antes de mostrar un resultado. Si el usuario no tiene permiso para la app, el resultado aparece con routing deshabilitado:

```json
{
  "routing": {
    "app_url": null,
    "app_name": "Tryton ERP",
    "module": "Contabilidad",
    "action": "denied",
    "reason": "No tiene permiso APP_TRYTON"
  }
}
```

### V5-7: Métricas Prometheus (desde SBOS-013-001 v1.0)

```
bsearch_queries_total{correction="none|fuzzy|synonym|keyboard"}
bsearch_query_duration_seconds
bsearch_index_size{app="tryton"}
bsearch_reindex_duration_seconds{app="tryton"}
bsearch_embedding_queue_size
bsearch_results_per_query{bucket="0|1-5|6-20|20+"}
```

---

## §19 — ENRIQUECIMIENTO V7: Integración con Dominios Reconceptualizados

### V7-1: bSearch como Consumidor del LogicalDomainMask (desde V7 Dominios)

bSearch opera dentro del **LogicalDomainMask** como herramienta de acceso a datos. Las consultas de bSearch están gobernadas por las zonas lógicas a las que el usuario tiene acceso READ:

```yaml
# En la política de búsqueda, cada entidad se asocia a una zona lógica:
logical_zone_mapping:
  invoice:    ZONE_CONTABILIDAD
  party:      ZONE_CONTABILIDAD
  product:    ZONE_CONTABILIDAD
  employee:   ZONE_RRHH
  ticket:     ZONE_SOPORTE
  order:      ZONE_VENTAS
```

Cuando un usuario busca, bSearch filtra resultados según las zonas activas en su LogicalDomainMask:
- Si el usuario tiene ZONE_CONTABILIDAD → muestra facturas, terceros, productos
- Si el usuario tiene ZONE_RRHH → muestra empleados, nómina
- Si no tiene ZONE_SOPORTE → los tickets no aparecen en resultados

### V7-2: Integración con el Zone Application Map (desde V7 Dominios)

```yaml
# zone_application_map.yaml — las apps que bSearch indexa pertenecen a zonas
zone_applications:
  ZONE_CONTABILIDAD:
    apps: [tryton, superset, paperless-ngx]
  ZONE_VENTAS:
    apps: [saleor, espocrm]
  ZONE_RRHH:
    apps: [orangehrm]
  ZONE_SOPORTE:
    apps: [zammad]
```

El Scope Registry de bSearch se actualiza para soportar filtrado por zona lógica, no solo por app individual.

### V7-3: BitmaskBundle para Resultados de Búsqueda (desde V7 SAM-128)

Cada resultado de bSearch incluye la máscara de acceso requerida:

```go
type SearchResult struct {
    Score       float64        `json:"score"`
    Source      ResultSource   `json:"source"`
    Display     ResultDisplay  `json:"display"`
    Routing     ResultRouting  `json:"routing"`
    RequiredMask uint64        `json:"required_mask"`  // LogicalDomainMask requerido
}
```

bSearch verifica en backend que el LogicalDomainMask del usuario tenga los bits necesarios antes de devolver resultados con routing habilitado.

---

## §20 — ENRIQUECIMIENTO Smart* (V8)

### V8-1: Smart Report — Patrones de Búsqueda Global/Local (desde SBOS-REPORT-015-REPORTES-GLOBAL-LOCAL.md)

La jerarquía de plantillas de Smart Report introduce patrones de búsqueda y resolución de templates que complementan el modelo de bSearch:

**Jerarquía de plantillas (7 niveles):**
| Nivel | Ámbito | Resolución de búsqueda |
|---|---|---|
| 0 (global) | Todo SBOS | Templates base search |
| 1 (app) | Por aplicación | Templates por app |
| 2 (tenant) | Por tenant | Templates multiempresa |
| 3 (empresa) | Por empresa | Templates por organización |
| 4 (sucursal) | Por sucursal | Templates por localidad |
| 5 (rol) | Por rol | Templates por perfil |
| 6 (usuario) | Personal | Templates personales |

**TemplateResolver algorithm:** La búsqueda asciende desde el nivel más específico (usuario) hasta el más general (global). Si el template no existe en el nivel actual, sube al siguiente. Tiempo de resolución objetivo: < 50ms P99.

**Catalog schema impact on bSearch:** Los índices de bSearch deben incluir `tipo_catalogo` y `tiene_version_global` como metadatos de los resultados, permitiendo filtrar por ámbito de template.

**Vista de catálogo en la UI:** Dos secciones — "Personalizados" (niveles 5-6) y "Estándar" (niveles 0-4). La búsqueda en cada sección usa índices separados en Meilisearch.

### V8-2: Contratos de API — Endpoints de Búsqueda y Catálogo (desde SBOS-REPORT-013-API-CONTRACT.md)

Smart Report expone 7 grupos de endpoints (A-G) que definen contratos de búsqueda que bSearch debe considerar para indexación de reportes:

**Grupo B — Catalog API:** GET /v1/catalog/templates, GET /v1/catalog/categories. Responde con `tipo_catalogo`, `tiene_version_global`, metadata del template. Esta API es consumible por bSearch para indexar templates como documentos buscables.

**Grupo C — Reports API (Preview/Export/Save):** POST /v1/reports/preview, POST /v1/reports/export/{format}. Los resultados de generación de reportes deben ser buscables desde bSearch. Cada reporte generado se indexa con metadatos: tenant_id, empresa_id, usuario_id, fecha_generacion, tipo_reporte.

**Grupo A — System API:** Health check, información de versión. Relevante para el health_evaluator de bSearch.

**RFC 9457 Problem Details:** Todos los errores usan el formato estándar RFC 9457 con 22 códigos de error documentados. Cada código incluye HTTP status, code, y client_action. Esto permite a bSearch presentar errores semánticamente ricos en lugar de códigos genéricos.

**Resilience patterns relevantes para bSearch:**
- Timeout de 90s para generación de reportes
- Cache de catálogo por 5 minutos
- No auto-retry en timeout de generación (evita sobrecarga)
- Circuit breaker en endpoints de JasperStarter

### V8-3: Funcionalidades de Reportes Indexables (desde SBOS-REPORT-004-FUNCIONALIDADES.md)

18 funcionalidades en 6 módulos que definen qué debe indexar bSearch:

**Módulo A — Gestión de Plantillas (F-001 a F-005):**
- F-001: CRUD plantillas .jrxml — indexar metadatos de plantillas
- F-002: Versionado — indexar historial de versiones
- F-003: Clasificación por categorías — indexar taxonomía
- F-004: Búsqueda de plantillas — directamente relacionado con bSearch
- F-005: Importación/exportación — indexar paquetes de plantillas

**Módulo B — Generación de Reportes (F-006 a F-010):**
- F-006: Generación bajo demanda — indexar reportes generados
- F-007: Programación recurrente — indexar programaciones
- F-008: Notificación de reporte listo — integración Centrifugo
- F-009: Múltiples formatos (PDF, XLSX, DOCX, HTML) — indexar por formato
- F-010: Parámetros dinámicos — indexar configuraciones de parámetros

**Módulo D — Seguridad (F-012 a F-013):**
- F-012: Permisos por template — alineado con LogicalDomainMask
- F-013: Filtro por tenant/empresa — alineado con ctx_id

**Módulo E — Auditoría (F-014 a F-015):**
- F-014: Log de generación — eventos indexables para bSearch Audit
- F-015: Trazabilidad de cambios — histórico de versiones

**Cada funcionalidad tiene criterios de aceptación que definen el comportamiento esperado del endpoint, directamente mapeables a tests de integración con bSearch.**

### V8-4: Modelo de Datos de Catálogo para bSearch (desde SBOS-REPORT-007-DATOS.md)

El schema de datos de Smart Report define la estructura que bSearch debe indexar:

```sql
-- Schema catalogo: fuentes de datos para bSearch
catalogo.aplicaciones   → filtro "buscar en esta app"
catalogo.tenants        → aislamiento multi-tenant
catalogo.empresas       → filtro por organización
catalogo.sucursales     → filtro por ubicación
catalogo.roles          → filtro por perfil
catalogo.usuarios       → filtro por usuario
catalogo.plantillas     → documento principal a indexar
catalogo.versiones      → historial versionado
```

**Plantilla lifecycle para indexación:**
```
borrador → NO indexar (no público)
  ↓
compilado → indexar metadatos
  ↓
activo → indexar metadatos + contenido
  ↓
reemplazado → mantener en índice con flag deprecated=true
deprecado → mantener en índice con flag deprecated=true
```

**Vigencia temporal:** `vigente_desde` / `vigente_hasta` en plantillas. bSearch debe soportar filtros temporales: "solo plantillas vigentes", "plantillas vigentes en fecha X".

**Schema ejecucion:** Log de ejecuciones particionado por mes. Cada entrada de log es un documento indexable para bSearch Audit (quién, cuándo, qué reporte, cuánto tardó, éxito/fallo).

**Schema sistema:** `integridad_alertas` para monitoreo de consistencia del catálogo.

---

## Trazabilidad V8

| Sección | Fuente |
|---|---|
| §1-17 (V6 completo) | BOS_V6_SBOS-026-DAEMON-BSEARCH.md |
| §18 V5-1 a V5-7 | BOS_V5_SBOS-013-bSearch-v4_0.md, BOS_V5_SBOS-013-001-INDEXING-FUZZY-ROUTING-v1_0.md |
| §19 V7-1 a V7-3 | BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md, BOS_V7_SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md |
| §20 V8-1 a V8-4 | SBOS Smart Report (SBOS-REPORT-015-REPORTES-GLOBAL-LOCAL.md, SBOS-REPORT-013-API-CONTRACT.md, SBOS-REPORT-004-FUNCIONALIDADES.md, SBOS-REPORT-007-DATOS.md) |

---

_SKULL · SBOS · SBOS-026-DAEMON-BSEARCH · HUMAN-DOC V8 ENRIQUECIDO · Mayo 2026_
