# SBOS-027-DAEMON-BCOMPASS
## SBOS AI Tools: Collaborative & Federated Intelligence — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Identidad

| Campo | Valor |
|---|---|
| Nombre | SBOS AI Tools: Collaborative & Federated Intelligence |
| Daemon | `bcompass` |
| Servicio | `bcompass.service` |
| Lenguaje | Go |
| Unidad declarativa | Ruta |
| Directorio | `/etc/bos/blibs/bcompass/router/<tipo>/<nombre_ruta>/` |
| BD propia | `bcompass_db` |
| LLM | Ollama local soberano (qwen3, deepseek-r1) |

Principio fundamental: DATOS → bCompass OBSERVA → ANALIZA → ORIENTA → HUMANO DECIDE → SISTEMA EJECUTA. Nunca autónomo en decisiones de alto impacto.

bCompass *usa* LLMs como herramienta, igual que bKernel *usa* PostgreSQL. La IA es el motor de algunas rutas — no el producto. El producto es la orientación inteligente al negocio.

## 2. Capa 4 — Orquestación de Inteligencia

```
CAPA 4 — ORQUESTACIÓN: bCompass (Routes = Casos de Uso del Negocio)
CAPA 3 — INTEGRACIÓN: bKernel + biedata (Reglas, Cajas)
CAPA 2 — DATOS: PostgreSQL, Redis, Qdrant
CAPA 1 — INFRAESTRUCTURA: Host Ubuntu + K8s (bos)
```

Routes = casos de uso de negocio formales. Approval Gates = compensación humana en Sagas de inteligencia.

| Governance | Impacto | Approval Gate | Ejemplos |
|---|---|---|---|
| 1 | Bajo | No — ejecuta directo | Generar reporte, responder pregunta |
| 2 | Medio | Sí — rol CONFIG | Sugerir desactivar regla bKernel |
| 3 | Alto | Sí — rol OWNER | Cambio config stack, impacto financiero |

## 3. 7 Principios

P1: Ruta = unidad de conocimiento (motor no sabe qué analiza cada ruta). P2: route_engine.yml = intención, route_catalog.so = lógica. P3: Solo lectura sobre stack (SELECT). P4: Humano aprueba alto impacto. P5: LLM local soberano (Ollama, datos nunca salen). P6: Binario motor + .so conocimiento (dlopen). P7: Auditoría completa en bcompass_db.

## 4. Modelo de Rutas — Estructura

```
/etc/bos/blibs/bcompass/router/
├── analyst/                    ← análisis de patrones
│   ├── reglas_inactivas/       ← manifest.yml + route_engine.yml + route_catalog.so + resources/
│   ├── correlaciones_sin_regla/
│   └── errores_recurrentes_biedata/
├── agent/                      ← agentes conversacionales
│   ├── asistente_empleado/
│   └── asistente_admin/
├── flow/                       ← automatización de procesos
│   ├── reporte_ventas_mensual/
│   └── alerta_anomalia_contable/
└── report/                     ← reportes automáticos
    ├── estado_semanal_bkernel/
    └── integraciones_mensual_biedata/
```

## 5. Los 4 Tipos de Ruta

### analyst
Observa datos históricos → análisis estadístico → sugerencias con status `pending` → admin aprueba/rechaza en Core UI.

### agent
Agente conversacional con Ollama local + RAG del stack. Responde en lenguaje natural con contexto de datos del usuario.

### flow
Workflows de automatización: consultas + análisis LLM + generación archivos + Approval Gates + notificaciones.

### report
Reportes periódicos automáticos en Excel/PDF. Variante simplificada de flow para documentos.

## 6. Los 4 Contratos de una Ruta

| Contrato | Archivo | Función |
|---|---|---|
| Identidad | manifest.yml | Tipo, trigger, fuentes, governance |
| Temporal | route_engine.yml | Fases declarativas (observe/analyze/suggest/respond/distribute) |
| Lógica | route_catalog.so | Queries, prompts, análisis (dlopen C ABI) |
| Conocimiento | resources/ | SQL, prompts, templates Excel, data_queries.yml |

## 7. manifest.yml — Ejemplos por Tipo

### analyst: reglas_inactivas
```yaml
identity:
  id: "analyst_reglas_inactivas"
  route_type: "analyst"
trigger:
  type: schedule
  cron: "0 3 * * 0"     # domingos 3AM
sources:
  - db: bkernel_db
    access: readonly
output:
  type: suggestion
  pending_review: true
governance:
  category: 2
```

### agent: asistente_empleado
```yaml
identity:
  id: "agent_asistente_empleado"
  route_type: "agent"
trigger:
  type: event
  source: redis
  stream: "bcompass:agent_requests"
sources:
  - app: orangehrm
    access: readonly
    scope: user_own_data_only
llm:
  model: "qwen3:4b-q4"
  system_prompt: "resources/system_prompt.txt"
output:
  type: response
  store_conversation: true
governance:
  category: 1
  data_scope: own_user_only
```

### flow: reporte_ventas_mensual
```yaml
identity:
  id: "flow_reporte_ventas_mensual"
  route_type: "flow"
trigger:
  type: schedule
  cron: "0 9 1 * *"
sources:
  - app: tryton
    query_file: "resources/query.sql"
llm:
  model: "qwen3:8b-q4"
  prompt_file: "resources/prompt.txt"
output:
  type: document
  format: excel
  template: "resources/template.xlsx"
  distribute:
    - channel: "#gerencia-ventas"
    - email: "{config.gerencia_emails}"
    - nextcloud_path: "/empresa/reportes/ventas/"
governance:
  category: 1
```

## 8. route_engine.yml — Ejemplos Completos

### analyst: reglas_inactivas
```yaml
phases:
  observe:
    tasks:
      - task: "check_source_connection"         # GLOBAL
      - task: "analyst_query_inactive_rules"     # ESPECÍFICA (route_catalog.so)
        params: { query_file: "resources/query.sql", inactive_threshold_days: 90 }
        output: inactive_rules
  analyze:
    tasks:
      - task: "analyst_score_suggestions"        # ESPECÍFICA
        params: { data: "{inactive_rules}", min_confidence: 0.80 }
        output: scored_suggestions
  suggest:
    tasks:
      - task: "store_suggestions"                # GLOBAL → bcompass_db status: pending
      - task: "notify_if_new"                    # GLOBAL → canal #bcompass-insights
```

### flow: reporte_ventas_mensual
```yaml
phases:
  read:
    tasks:
      - task: "db_query"                         # GLOBAL
        params: { app: tryton, query_file: "resources/query.sql" }
        output: ventas_data
  analyze:
    tasks:
      - task: "llm_prompt"                       # GLOBAL → Ollama local
        params: { model: "qwen3:8b-q4", prompt_file: "resources/prompt.txt", context: { data: "{ventas_data}" } }
        output: analisis_ejecutivo
  generate:
    tasks:
      - task: "flow_generate_excel"              # ESPECÍFICA
        params: { data: "{ventas_data}", analysis: "{analisis_ejecutivo}", template: "resources/template.xlsx" }
        output: reporte_excel
  distribute:
    tasks:
      - task: "notify_with_attachment"           # GLOBAL → canal + attach
      - task: "send_email"                       # GLOBAL → gerencia
      - task: "save_to_nextcloud"                # GLOBAL → /empresa/reportes/
```

### agent: asistente_empleado
```yaml
phases:
  retrieve_context:
    tasks:
      - task: "agent_fetch_user_data"            # ESPECÍFICA → datos del usuario
        output: user_context
      - task: "rag_fetch_documents"              # GLOBAL → RAG Nextcloud
        params: { path: "/empresa/politicas/", query: "{event.user_message}", top_k: 3 }
        output: doc_context
  respond:
    tasks:
      - task: "llm_prompt"                       # GLOBAL → Ollama
        params: { model: "qwen3:4b-q4", system_prompt_file: "resources/system_prompt.txt",
                  context: { user_data: "{user_context}", documents: "{doc_context}" } }
        output: agent_response
      - task: "send_response"                    # GLOBAL → responde al usuario
      - task: "log_conversation"                 # GLOBAL → bcompass_db
```

### flow con Approval Gate
```yaml
phases:
  analyze:
    tasks:
      - task: "flow_analyze_financial_anomaly"
        output: anomaly_report
  approval_gate:
    tasks:
      - task: "request_human_approval"           # GLOBAL
        params: { title: "Anomalía contable requiere revisión", data: "{anomaly_report}", timeout_hours: 24 }
        output: approval_decision
  execute:
    condition: "{approval_decision.approved == true}"
    tasks:
      - task: "flow_execute_corrective_action"
```

## 9. Route API — C ABI

```c
typedef struct {
    const char* name;
    const char* version;
    const char* route_type;
    CompassResult (*execute_task)(const char* task_name, const BCompassContext* ctx, const CompassHandles* handles);
    CompassResult (*validate)(const CompassHandles* handles);
} BCompassRoute;

BCompassRoute* bcompass_route_init();  // dlsym()
```

## 10. Motor Binario

```
bCompass (binario Go)
├── Event Listener   — Redis Stream, cron, manual, webhook
├── Route Resolver   — dado evento → encuentra ruta en router/
├── Route Loader     — manifest + route_engine + route_catalog.so (dlopen)
├── Engine Executor  — ejecuta fases en orden
│   ├── Task Dispatcher — GLOBAL (motor) vs ESPECÍFICA (.so)
│   ├── Context Manager — pipeline outputs entre tareas
│   └── Approval Gate Manager — pausa ejecución, espera Core UI
├── Ollama Client    — httpx directo a Ollama local
├── Result Emitter   — sugerencias, respuestas, reportes, notificaciones
└── Hot-Reload (SIGUSR1) — recarga rutas sin reiniciar
```

Tareas globales: check_source_connection, db_query, llm_prompt, store_suggestions, notify_if_new, send_response, log_conversation, notify_with_attachment, send_email, save_to_nextcloud, request_human_approval, rag_fetch_documents.

## 11. n8n Vetado + Flowise Complementario

**n8n:** Sustainable Use License — no es software libre. Viola Principio 3. Explícitamente vetado.

**Flowise (Apache 2.0):** prototipador rápido de agentes. Diseña en Flowise → valida → migra como ruta agent de bCompass para producción.

**Ollama sí se usa:** LLM = hardware + modelos, no software de negocio. 100% local. Datos nunca salen del servidor.

## 12. Fronteras Inviolables

| # | Regla | Consecuencia |
|---|---|---|
| C1 | Solo lectura sobre stack | Modificación accidental |
| C2 | Solo escribe en bcompass_db | Corrupción datos producción |
| C3 | Humano aprueba alto impacto (cat 2-3) | Autonomía sin supervisión |
| C4 | LLM local Ollama (datos nunca salen) | Pérdida soberanía |
| C5 | Suggestions tienen status pending | Cambios sin trazabilidad |
| C6 | Cero conocimiento en el binario | Recompilar para nueva ruta |
| C7 | Agent solo accede datos del usuario (own_user_only) | Fuga de datos entre usuarios |
| C8 | Rutas no modifican reglas bKernel directamente | Bypass del governance |

---

## §13 — ENRIQUECIMIENTO V5: Contrato LLM, Agentes y Aprendizaje Federado

### V5-1: Pipeline de Inferencia LLM en 5 Fases (desde SBOS-014-001 v1.0)

```
Usuario solicita análisis (via Core UI o API)
  │
  ▼
Route Engine lee route_engine.yml de la ruta solicitada
  │
  ▼
FASE 1: CONTEXT ASSEMBLY
  ├── Consulta bkernel vía Redis: datos relevantes del negocio
  ├── Consulta bsearch: documentos relacionados (RAG)
  ├── Consulta Qdrant: embeddings similares (memoria semántica)
  └── Arma el contexto con max_tokens respetado

FASE 2: PROMPT CONSTRUCTION
  ├── Lee prompt template de Langfuse (versionado)
  ├── Inyecta variables: {context}, {user_query}, {constraints}
  ├── Aplica system prompt del manifiesto de la ruta
  └── Genera el prompt final (logged en Langfuse con trace_id)

FASE 3: LLM INFERENCE
  ├── Envía al modelo via Ollama API (localhost:11434)
  ├── Modelo: según route_engine.yml (default: qwen3:8b)
  ├── Temperature, max_tokens, top_p del manifiesto
  ├── Timeout: 120 segundos (configurable)
  └── SI FALLA → fallback (ver §4)

FASE 4: RESPONSE VALIDATION
  ├── Parsear respuesta del modelo
  ├── Validar contra schema esperado (si la ruta define uno)
  ├── Verificar: ¿la respuesta referencia datos reales? (anti-alucinación)
  │   └── Cross-check con datos del contexto
  ├── SI VÁLIDA → formatear y entregar
  └── SI INVÁLIDA → retry con prompt refinado (max 2 retries)

FASE 5: AUDIT & LEARN
  ├── Log en Langfuse: prompt, response, latency, tokens, trace_id
  ├── Si el usuario da feedback → almacenar para fine-tuning futuro
  └── Métricas: bcompass_inference_duration_seconds, bcompass_inference_total
```

### V5-2: Formato Extendido de route_engine.yml (desde SBOS-014-001 v1.0)

```yaml
route:
  id: "INVENTORY-ALERT-001"
  name: "Alerta de Stock Mínimo"
  type: "analytical"
  enabled: true

  context:
    sources:
      - type: "bkernel_redis"
        channel: "bkernel:events:tryton"
        filter: "stock.move"
      - type: "bsearch_rag"
        index: "inventory"
        query: "productos con stock bajo"
      - type: "sql"
        database: "tryton_db"
        query: "SELECT name, quantity FROM stock_move WHERE quantity < reorder_point"
    max_context_tokens: 4000

  prompt:
    langfuse_name: "inventory_alert_v3"
    system: "Eres un analista de inventario. Genera propuestas de compra basadas en datos reales."
    temperature: 0.3
    max_tokens: 2000
    model: "qwen3:8b"

  validation:
    require_data_reference: true
    output_schema: "json"

  human_approval:
    required: true
    approval_role: "sbos-operator"
    auto_expire_hours: 24

  error_handling:
    max_retries: 2
    fallback_model: "qwen3:1.5b"
    on_failure: "notify_admin"
```

### V5-3: Aprendizaje Federado (Privacy-Preserving) (desde SBOS-014-001 v1.0)

```
CLIENTE A (SBOS instalación)          SKULL Release Plane
  │                                     │
  ├── Fine-tune local con datos         │
  │   del cliente (Ollama)              │
  │                                     │
  ├── Extraer gradientes del            │
  │   fine-tune (diferencias de pesos)  │
  │                                     │
  ├── Anonimizar: eliminar cualquier    │
  │   dato que pueda identificar al     │
  │   cliente (differential privacy)    │
  │                                     │
  ├── Enviar gradientes anónimos ──────►│ Agregar gradientes
  │   (NO datos, NO prompts)            │ de múltiples clientes
  │                                     │
  │                                     ├── Federated averaging
  │                                     │   (promediar gradientes)
  │                                     │
  │◄── Recibir modelo mejorado ────────│ Distribuir modelo
  │   (via Release Plane normal)        │ actualizado
  │                                     │
  └── Desplegar modelo mejorado         │
      en Ollama local                   │
```

Configuración:
```yaml
[federated_learning]
enabled = false                    # desactivado por defecto
opt_in_required = true             # requiere consentimiento explícito del cliente
gradient_upload_schedule = "weekly" # weekly | monthly | manual
differential_privacy_epsilon = 1.0 # nivel de ruido para privacidad
min_local_samples = 1000           # mínimo de muestras antes de contribuir
```

### V5-4: Agentes de Investigación por Manifiestos (desde SBOS-014-001 v1.0)

```yaml
agent:
  id: "RESEARCH-MARKET-001"
  name: "Investigación de Precios de Mercado"
  type: "research"
  max_steps: 10
  max_duration_minutes: 30
  max_tokens_total: 50000

  boundaries:
    data_sources: ["tryton", "saleor", "bsearch"]
    forbidden_sources: ["keycloak", "vault", "system_config"]
    forbidden_actions: ["write", "delete", "modify"]
    read_only: true

  steps:
    - step: 1
      action: "query"
      source: "tryton"
      query: "SELECT category, AVG(list_price) FROM product_product GROUP BY category"
      store_as: "avg_prices"
    - step: 2
      action: "query"
      source: "saleor"
      query: "SELECT product_name, sale_price FROM order_line WHERE date > :last_month"
      store_as: "recent_sales"
    - step: 3
      action: "analyze"
      model: "qwen3:8b"
      prompt: "Compara los precios promedio de catálogo ({avg_prices}) con los precios reales de venta ({recent_sales}). Identifica productos con margen inferior al 15%."
      store_as: "margin_analysis"
    - step: 4
      action: "report"
      format: "markdown"
      template: "resources/market_report_template.md"
      data: ["avg_prices", "recent_sales", "margin_analysis"]

  output:
    type: "report"
    deliver_to: "core_ui"
    notify: "sbos-operator"
    requires_human_review: true
```

### V5-5: Jerarquía de Fallback sin GPU (desde SBOS-014-001 v1.0)

```
Jerarquía de modelos (bcompass intenta en orden):
  1. Modelo principal: qwen3:8b (requiere ~6GB VRAM)
  2. Modelo reducido: qwen3:1.5b (requiere ~2GB VRAM)
  3. Modelo CPU-only: phi-3-mini (3.8B, funciona en CPU)
  4. Sin modelo: respuesta basada solo en datos estructurados (sin LLM)

Detección automática:
  bcompass al iniciar consulta Ollama: GET /api/tags
  Si modelo principal no disponible → degradar al siguiente
  Log: "Model qwen3:8b not available, falling back to qwen3:1.5b"
  Métrica: bcompass_model_fallback_total{from="qwen3:8b",to="qwen3:1.5b"}
```

---

## §14 — ENRIQUECIMIENTO V7: Integración con LogicalDomainMask y Zones

### V7-1: bCompass como Evaluador del LogicalDomainMask (desde V7 Dominios)

bCompass actúa como el **LogicalDomainEvaluator** — determina qué zonas lógicas puede acceder un usuario y qué aplicaciones están disponibles en cada zona:

```go
type LogicalDomainEvaluator interface {
    // CanAccessZone — verifica si el usuario tiene permiso READ en una zona
    CanAccessZone(userSub string, zone ZoneID) (bool, error)
    
    // GetZoneApplications — resuelve qué apps pertenecen a una zona
    GetZoneApplications(zone ZoneID) ([]string, error)
    
    // GetActiveZones — obtiene todas las zonas activas para un usuario
    GetActiveZones(userSub string) ([]ZoneID, error)
}
```

### V7-2: Zone Application Map para rutas bCompass (desde V7 Dominios)

Las rutas de bCompass se asocian a zonas lógicas para governance:

```yaml
# En manifest.yml de cada ruta bCompass
governance:
  category: 2
  logical_zone: ZONE_CONTABILIDAD  # Solo usuarios con esta zona pueden ver sugerencias
```

### V7-3: Protocolo de Notificación con BitmaskBundle (desde V7 SAM-128)

Las notificaciones de bCompass al escritorio VDI incluyen el contexto de máscara requerido:

```go
type VDIEventPayload struct {
    Title         string        `json:"title"`
    Body          string        `json:"body"`
    ActionURL     string        `json:"action_url"`
    RequiredMask  BitmaskBundle `json:"required_mask"`  // Máscara mínima requerida
}
```

---

## §15 — ENRIQUECIMIENTO Smart* (V8)

### V8-1: Smart Report — Simulación del Compositor y Brechas de Arquitectura (desde SBOS-REPORT-016-SIMULACION-COMPOSITOR.md)

La simulación del AI Compositor sobre Smart Report identificó 9 gaps arquitectónicos que impactan directamente el diseño de bCompass como orquestador de rutas:

**Los 10 niveles de entendimiento validados por el Compositor:**
Los mismos que usa bCompass para clasificar sus rutas (analyst/agent/flow/report). La simulación confirmó que el modelo de 10 niveles es correcto y completo para el dominio de reportes.

**5 perfiles de usuario identificados:**
Coinciden con los perfiles de bCompass: usuario final, analista, administrador, auditor, desarrollador. Cada perfil tiene rutas bCompass específicas.

**9 Gaps identificados (impacto en bCompass):**
| Gap | Descripción | Impacto en bCompass |
|---|---|---|
| G-01 | 7vs8 niveles de template | La jerarquía de plantillas debe ser configurable en route_engine.yml |
| G-02 | Orden tenant/app | El resolvedor de contexto debe evaluar tenant antes que app |
| G-03 | Gestión como nivel o temporal | bCompass debe soportar reglas temporales en rutas de gestión |
| G-04 | Estrategia de caché | bCompass debe declarar política de caché por ruta |
| G-05 | Comportamiento del Viewer | Las rutas de visualización deben respetar el IRM del documento |
| G-06 | Recompilación | bCompass debe orquestar recompilación cuando cambia la plantilla |
| G-07 | Subreportes | bCompass debe resolver dependencias de subreportes en cascada |
| G-08 | Tipo Java N2W | El conversor de tipos debe incluir mapping JasperReports→Web |
| G-09 | Retención de logs | bCompass debe definir política de retención por ruta |

**Veredicto de la simulación:** Proyecto ready with gaps. bCompass puede consumir Smart Report como ruta tipo "report" con los gaps documentados como technical debt.

### V8-2: Edge Cases — Fallos y Recuperación en bCompass Routes (desde SBOS-REPORT-014-EDGE-CASES.md)

Smart Report define 9 edge cases que bCompass debe manejar como patrones de fallo en sus rutas:

| EC | Condición | Código HTTP | Comportamiento bCompass |
|---|---|---|---|
| EC-01 | JasperStarter timeout (>90s) | 504 | SIGTERM→SIGKILL→circuit breaker, retry con backoff |
| EC-02 | PDO inválido | 502 | No exponer JDBC details, log estructurado |
| EC-03 | Paperless no disponible | 202 | Queue con backoff: 1m→5m→15m, notificar cuando esté listo |
| EC-04 | SHA-256 violation | 503 BLOCK | Congelar activo, alertar Admin bos, no continuar la ruta |
| EC-05 | Reprocesamiento con 2FA | Step-up | Re-autenticación WebAuthn antes de re-ejecutar |
| EC-06 | .jrxml incompatible | 422 | Validación en staging antes de compilar |
| EC-07 | Histórico sin versión | 404 | Devolver error semántico con sugerencia |
| EC-08 | Concurrencia (JASPER_MAX_CONCURRENT=5) | 429 | Laravel Queue, esperar turno |
| EC-09 | JWT expira mid-request | 401 | Validar al inicio de la ruta, no re-validar |

Estos edge cases se traducen en patrones de compensación en las rutas de bCompass. Cada ruta debe declarar su política de retry y compensación.

### V8-3: Smart Portfolio — Motor de Aprendizaje Continuo (desde SBOS-Portfolio-017-MOTOR-APRENDIZAJE-CONTINUO.md)

El Motor de Aprendizaje Continuo de bportfolio se integra con bCompass como fuente de conocimiento para las rutas analyst y agent:

**4 estados de conocimiento del sistema:**
| Estado | Nivel | Rango confianza | Uso en bCompass |
|---|---|---|---|
| Terra Incognita | 0 | 40-65% | Ruta analyst con supervisión humana |
| Reconocimiento Parcial | 1 | 65-80% | Ruta analyst con validación automática |
| Competencia | 2 | 80-92% | Ruta agent autónomo |
| Maestría | 3 | 95%+ | Ruta agent without supervision |
| Generalización | 4 | Cross-dominio | Ruta agent multi-dominio |

**5 componentes del motor:**
1. `DetectorEstado` — evalúa el nivel de conocimiento actual para cada dominio
2. `Modo Exploración` — genera rutas de exploración (mapa del documento primero)
3. `GestorTransferencia` — transfiere aprendizaje entre dominios relacionados
4. `EvaluadorCalidad` — evalúa la calidad de las respuestas de bCompass
5. `GeneradorSintetico` — genera ejemplos sintéticos para entrenamiento

**3 tipos de HITL (Human-In-The-Loop):**
| Tipo | Cuándo se activa | Acción de bCompass |
|---|---|---|
| Tipo 1 (reactive) | El usuario reporta error en respuesta | Revisión de producto, registrar corrección |
| Tipo 2 (proactive — MOST VALUABLE) | El usuario explora documento nuevo | Registrar patrón de exploración, extraer conocimiento |
| Tipo 3 (knowledge validation) | El sistema alcanza 80% de confianza | Solicitar validación humana antes de pasar a autónomo |

**8 KPIs objetivo** que bCompass monitorea: accuracy, coverage, latency, user satisfaction, learning velocity, transfer efficiency, hallucination rate, correction rate.

**Learning curves per catalog type:** Cada tipo de catálogo (contabilidad, RRHH, ventas, soporte) tiene su propia curva de aprendizaje. bCompass ajusta el nivel de supervisión según la madurez de cada dominio.

### V8-4: Smart Portfolio — Estrategia de Entrenamiento IA (desde SBOS-Portfolio-021-ENTRENAMIENTO-IA.md)

La estrategia de entrenamiento IA de bportfolio define cómo bCompass mejora sus modelos de inferencia:

**3 fases de entrenamiento:**
| Fase | Timeline | Técnica | Ejemplos necesarios | Modelo |
|---|---|---|---|---|
| F1 (ahora) | Inmediato | RAG + Active Learning | < 100 | qwen3:8b (actual bCompass) |
| F2 | 6-12 meses | QLoRA fine-tuning | 1,000+ | Qwen2-VL-7B 4-bit, r=16, Unsloth |
| F3 | 12-24 meses | Specialist model | 10,000+ | Modelo propio por dominio |

**Bibliotecario context selection:** Máximo 6000 tokens de contexto. El Bibliotecario selecciona los fragmentos más relevantes del knowledge base para cada consulta de bCompass.

**Active Learning priority scoring:**
| Factor | Peso |
|---|---|
| Uncertainty (alta varianza entre modelos) | 40 pts |
| New error type (error no visto antes) | 35 pts |
| Industry coverage (sector sub-representado) | 20 pts |
| Image quality (para VLMs) | 8 pts |

**Dataset format:** ChatML para VLMs. Los ejemplos se almacenan en `training_examples` con split estratificado por industria (40% train, 30% validation, 30% test).

**Dataset DDL:**
```sql
training_examples (
  id UUID, prompt TEXT, response TEXT, domain VARCHAR(50),
  industry VARCHAR(50), confidence DECIMAL, source_route VARCHAR(50),
  split VARCHAR(10), created_at TIMESTAMPTZ
);
```

**Evaluation benchmarks** para catalog extraction: precisión, recall, F1, exact match en extracción de campos de documentos.

### V8-5: Smart Tax — Sistema de Prompts Estandarizados para bCompass (desde SBOS_TAX_E4_PROMPT_SISTEMA_ESTANDAR.md)

El sistema de prompts estandarizados de Smart Tax define el formato que bCompass debe usar para sus rutas de generación de código fiscal:

**8-bloque template estándar:**
| Bloque | Naturaleza | Descripción |
|---|---|---|
| B1 Identity | Never modify | Identidad del agente, version, restricciones inmutables |
| B2 Sector Context | Variable | Contexto del sector fiscal aplicable |
| B3 Fiscal Formulas | Variable | Fórmulas y cálculos fiscales específicos |
| B4 Invariants | 15 universal + sectorial | Invariantes que toda respuesta debe cumplir |
| B5 Decision Tables | Variable | Tablas de decisión para casos complejos |
| B6 Test Vector | Variable | Vector de prueba para validar la respuesta |
| B7 Files to Generate | Variable | Especificación de archivos a generar |
| B8 Completeness Criteria | Variable | Criterios que determinan cuándo la respuesta está completa |

**Los 15 invariantes fiscales universales** que toda ruta de bCompass de tipo "tax" debe cumplir:
1. Todo monto debe incluir moneda (BOB por defecto)
2. Todo cálculo debe redondear a 2 decimales
3. IT (3%) se aplica sobre el monto total
4. IUE (12.5% servicios / 5% bienes) se aplica sobre el monto sin IT
5. IVA (13%) se aplica sobre el monto neto
6. Facturación obligatoria en toda transacción B2B
7. Bancarización obligatoria ≥ 50,000 BOB
8. Retención de proveedores sin factura
9. Trueque = compra + venta, ambas facturadas
10. Pago en especie valorado a Fair Market Value
11. F-570 para retenciones IUE
12. F-410 para retenciones IT
13. Plazo máximo de reporte: 10 días hábiles
14. Período fiscal mensual (cierre día 15)
15. Auditoría retentiva mínima 5 años

**QA cross-protocol (Auditor vs Generator):** Las rutas de bCompass que usen este template deben incluir un paso de validación cruzada donde el rol "Auditor" verifica la respuesta del "Generator" contra los invariantes antes de presentarla al usuario.

---

## §16 — ENRIQUECIMIENTO SBOS (Primera Versión)

### SBOS-014-EXT-016-1: Arquitectura de Gestión de Prompts Separada del Código (desde SBOS-014-LLM-Prompts-Langfuse.md)

Los prompts de SBOS AI Tools son conocimiento de negocio ajustable por el cliente, no lógica de sistema. El ciclo de vida del prompt (iteración rápida para mejorar calidad) es diferente al del plugin `.so`. La separación permite:

- **Hot-reload via symlink:** `/etc/bos/blibs/bcompass/prompts/active -> v1.3/`. Cambiar la versión activa es actualizar el symlink y enviar SIGUSR1.
- **Versionado semver independiente para prompts** (separado del `.so` y del binario):
  - **MAJOR:** el prompt produce un tipo de respuesta diferente que requiere actualizar el plugin que lo consume (ej: prosa a JSON estructurado)
  - **MINOR:** respuestas mejoradas pero compatibles (ej: más contexto, mejor calidad, ejemplos few-shot)
  - **PATCH:** typos, aclaraciones, ajuste fino del tono
- **Estructura de directorios por versión:**
  ```
  /etc/bos/blibs/bcompass/prompts/v1.3/
    ├── metadata.yaml
    ├── agent/       (system.txt, context.yaml, few_shot_examples.yaml)
    ├── flow/        (system.txt, context.yaml)
    ├── analyst/     (system.txt, context.yaml, few_shot_examples.yaml)
    └── report/      (system.txt, context.yaml)
  ```

### SBOS-014-EXT-016-2: metadata.yaml y context.yaml de Prompts (desde SBOS-014-LLM-Prompts-Langfuse.md)

**metadata.yaml** declara compatibilidad con versiones de plugin y modelos, y métricas de prueba:

```yaml
version: "1.3.0"
compatible_plugin_versions: ">=1.5.0"
compatible_models: ["qwen2.5:14b", "llama3.1:8b", "mistral:7b"]
tested_with:
  dataset_size: 127
  pass_rate: 0.91
```

**context.yaml** declara las variables de contexto que bCompass inyecta automáticamente antes de la llamada a Ollama:

```yaml
context_variables:
  - name: "current_fiscal_period"
    source: "bcompass_db.fiscal_context.current_period"
  - name: "company_name"
    source: "bcompass_db.tenant_config.company_name"
  - name: "user_role"
    source: "jwt_claims.bos_perm_base"
injection_format: |
  Contexto del negocio:
  - Empresa: {company_name}
  - Período fiscal activo: {current_fiscal_period}
  - Rol del usuario: {user_role}
```

### SBOS-014-EXT-016-3: Hot-Reload Atómico de Prompts con SIGUSR1 (desde SBOS-014-LLM-Prompts-Langfuse.md)

El hot-reload de prompts está integrado al mecanismo SIGUSR1 de bCompass:

```bash
ln -sfn /etc/bos/blibs/bcompass/prompts/v1.4 /etc/bos/blibs/bcompass/prompts/active.new
mv -f /etc/bos/blibs/bcompass/prompts/active.new /etc/bos/blibs/bcompass/prompts/active
sudo kill -SIGUSR1 $(systemctl show bcompass --property=MainPID | cut -d= -f2)
```

Durante ~200ms: las rutas en vuelo completan con el prompt anterior; las nuevas rutas usan el prompt nuevo. No hay pérdida de solicitudes.

### SBOS-014-EXT-016-4: Integración Detallada con Langfuse (desde SBOS-014-LLM-Prompts-Langfuse.md)

Cada llamada que bCompass realiza a Ollama genera automáticamente un trace en Langfuse con estos campos obligatorios:

| Campo | Valor | Propósito |
|---|---|---|
| `name` | Nombre de la ruta (analyst_financial, etc.) | Filtrar traces por ruta en Langfuse |
| `route_type` | agent / flow / analyst / report | Clasificar por tipo de ruta |
| `prompt_version` | Semver del prompt activo (1.3.0) | Correlacionar calidad con versión del prompt |
| `model` | Nombre del modelo Ollama | Comparar modelos |
| `tenant_realm` | Realm de Keycloak del tenant | Aislamiento de datos por cliente |
| `input_tokens` | Número de tokens del prompt | Monitoreo de costos |
| `output_tokens` | Número de tokens de la respuesta | Monitoreo de verbosidad |
| `latency_ms` | Latencia total de la llamada Ollama | SLO de latencia |

Langfuse expone interfaz web en `https://langfuse.{dominio_cliente}/` protegida por Keycloak SSO. Solo administradores con rol `bos_admin` pueden ver los traces.

### SBOS-014-EXT-016-5: Métricas OTEL Específicas del Ciclo de Vida LLM (desde SBOS-014-LLM-Prompts-Langfuse.md)

Métricas adicionales a Langfuse, emitidas al OTEL Collector (localhost:4317) para alertas en tiempo real:

```yaml
metrics:
  - name: bcompass_llm_calls_total        # counter: route, model, status
  - name: bcompass_llm_latency_ms          # histogram, buckets: [100,500,1000,2000,5000,10000,30000]
  - name: bcompass_llm_tokens_total        # counter: route, type (input|output)
  - name: bcompass_prompt_version          # gauge: route_type (valor = fecha unix de carga)
  - name: bcompass_routes_executed_total   # counter: route_type, status (completed|failed|timeout)
```

Alertas de Alertmanager para el aiserver:
- `SBOSAIToolsLLMLatencyHigh`: P95 > 5s por más de 5 minutos (severity: medium)
- `SBOSAIToolsLLMErrorRateHigh`: tasa de errores > 10% en 10 minutos (severity: high)
- `OllamaServerUnreachable`: Ollama no responde por más de 2 minutos (severity: high)

### SBOS-014-EXT-016-6: Evaluación de Prompts con Dataset Mínimo (desde SBOS-014-LLM-Prompts-Langfuse.md)

Cada ruta de bCompass tiene un dataset de evaluación mínimo de **20 casos por ruta**:

```yaml
dataset_version: "2026-03"
route: analyst_financial
cases:
  - id: "AF-001"
    input:
      query: "Cuales son las facturas vencidas del ultimo mes?"
      context:
        fiscal_period: "2026-Q1"
        company: "Acme Corp"
        user_role: "finance_manager"
    expected_output_contains: ["facturas vencidas", "monto", "fecha de vencimiento"]
    expected_output_format: "lista estructurada"
    must_not_contain: ["no tengo acceso", "no puedo", "error"]
```

**Proceso de aprobación:** desarrollar prompt nuevo -> ejecutar eval dataset completo -> pass_rate >= 85% -> A/B test en Langfuse (opcional) -> actualizar symlink + SIGUSR1 -> monitorear métricas OTEL 30 min.

Comando de evaluación: `bos-ctl prompt eval --route analyst --prompt-version v1.4 --dataset /etc/bos/blibs/bcompass/prompts/eval/analyst_financial_eval.yaml --model qwen2.5:14b --output /tmp/eval-report-$(date +%Y%m%d).json`

### SBOS-014-EXT-016-7: Rollback y Política de Retención de Prompts (desde SBOS-014-LLM-Prompts-Langfuse.md)

**Rollback inmediato** (< 1 segundo, sin recompilación ni reinicio):

```bash
ln -sfn /etc/bos/blibs/bcompass/prompts/v1.3 /etc/bos/blibs/bcompass/prompts/active.new
mv -f /etc/bos/blibs/bcompass/prompts/active.new /etc/bos/blibs/bcompass/prompts/active
sudo kill -SIGUSR1 $(systemctl show bcompass --property=MainPID | cut -d= -f2)
echo "$(date) [ROLLBACK] v1.4 -> v1.3: Degradacion de latencia detectada." >> /etc/bos/blibs/bcompass/prompts/CHANGELOG.md
```

**Política de retención:** mantener al menos las últimas 5 versiones en disco. La versión activa nunca puede ser eliminada. Eliminar versiones antiguas con `bos-ctl prompt prune --keep-last=5`. Los logs de Langfuse retienen los prompts usados en cada trace.

---

## Trazabilidad V8

| Sección | Fuente |
|---|---|
| §1-12 (V6 completo) | BOS_V6_SBOS-027-DAEMON-BCOMPASS.md |
| §13 V5-1 a V5-5 | BOS_V5_SBOS-014-bCompass-v4_0.md, BOS_V5_SBOS-014-001-LLM-CONTRACT-AGENTS-v1_0.md |
| §14 V7-1 a V7-3 | BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md, BOS_V7_SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md |
| §15 V8-1 a V8-5 | SBOS Smart Report (SBOS-REPORT-016-SIMULACION-COMPOSITOR.md, SBOS-REPORT-014-EDGE-CASES.md), SBOS Smart Portfolio (SBOS-Portfolio-017-MOTOR-APRENDIZAJE-CONTINUO.md, SBOS-Portfolio-021-ENTRENAMIENTO-IA.md), SBOS Smart Tax (SBOS_TAX_E4_PROMPT_SISTEMA_ESTANDAR.md) |
| §16 SBOS-016-1 a SBOS-016-7 | SBOS-014-LLM-Prompts-Langfuse.md (Gestión de ciclo de vida de prompts, Langfuse, métricas OTEL, evaluación y rollback) |

---

## Fuentes de Enriquecimiento V8

| Fuente | Tipo | Contenido aportado |
|---|---|---|
| BOS_V6_SBOS-027-DAEMON-BCOMPASS.md | V6 (canónico) | Contenido base completo preservado |
| BOS_V5_SBOS-014-bCompass-v4_0.md, BOS_V5_SBOS-014-001-LLM-CONTRACT-AGENTS-v1_0.md | V5 | Pipeline LLM 5 fases, formato extendido route_engine.yml, aprendizaje federado, agentes de investigación, jerarquía de fallback |
| BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md, BOS_V7_SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md | V7 | LogicalDomainMask, Zone Application Map, protocolo de notificación |
| SBOS Smart Report, Smart Portfolio, Smart Tax | Smart* (V8) | Simulación Compositor, edge cases, motor de aprendizaje continuo, entrenamiento IA, prompts estandarizados |
| SBOS-014-LLM-Prompts-Langfuse.md | SBOS (V8) | Gestión de ciclo de vida de prompts (hot-reload via symlink, semver independiente, metadata.yaml), integración Langfuse (traces, campos obligatorios), métricas OTEL LLM (bcompass_llm_*), evaluación de prompts con dataset mínimo, rollback y retención |

---

_SKULL · SBOS · SBOS-027-DAEMON-BCOMPASS · HUMAN-DOC V8 ENRIQUECIDO · Mayo 2026_
