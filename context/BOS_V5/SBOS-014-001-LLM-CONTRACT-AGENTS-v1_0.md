# SBOS-014-001
## Anexo: Contrato Ruta→LLM, Aprendizaje Federado y Agentes por Manifiesto
### Especificación de Nivel de Código para SBOS AI Tools

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-014-001
**Complementa:** SBOS-014-bCompass-v4_0.md, SBOS-014-LLM-Prompts-Langfuse.md

---

## 1. Contrato Ruta → LLM → Respuesta

### 1.1 Flujo de invocación

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

### 1.2 Formato del route_engine.yml

```yaml
route:
  id: "INVENTORY-ALERT-001"
  name: "Alerta de Stock Mínimo"
  type: "analytical"           # analytical | research | conversational | report
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
    system: "Eres un analista de inventario. Genera propuestas de compra basadas en datos reales. No inventes datos. Si no tienes información suficiente, dilo explícitamente."
    temperature: 0.3
    max_tokens: 2000
    model: "qwen3:8b"

  validation:
    require_data_reference: true    # respuesta debe citar datos del contexto
    output_schema: "json"           # json | text | markdown
    json_schema:
      type: "object"
      properties:
        alerts: { type: "array" }
        purchase_proposals: { type: "array" }
        confidence: { type: "number" }

  human_approval:
    required: true                  # propuestas requieren aprobación humana
    approval_role: "sbos-operator"
    auto_expire_hours: 24

  error_handling:
    max_retries: 2
    fallback_model: "qwen3:1.5b"   # modelo más pequeño si el principal falla
    on_failure: "notify_admin"
```

---

## 2. Aprendizaje Federado (Privacy-Preserving)

### 2.1 Principio

El SBOS NUNCA envía datos crudos del cliente fuera de la infraestructura. El aprendizaje federado permite mejorar modelos compartiendo solo optimizaciones matemáticas (gradientes), no datos.

### 2.2 Flujo

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

### 2.3 Configuración

```yaml
# En bcompass.toml
[federated_learning]
enabled = false                    # desactivado por defecto
opt_in_required = true             # requiere consentimiento explícito del cliente
gradient_upload_schedule = "weekly" # weekly | monthly | manual
differential_privacy_epsilon = 1.0 # nivel de ruido para privacidad
min_local_samples = 1000           # mínimo de muestras antes de contribuir
```

---

## 3. Agentes de Investigación por Manifiestos

### 3.1 Concepto

Un agente es una ruta de tipo "research" que ejecuta múltiples pasos de recolección, estructuración y síntesis de información. Está regulado por un manifiesto que define sus límites.

### 3.2 Formato del manifiesto de agente

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

---

## 4. Fallback sin GPU

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

## 5. Registro de Cambios

### v1.0 — Marzo 2026

Contrato ruta→LLM→respuesta con 5 fases, aprendizaje federado privacy-preserving, agentes de investigación por manifiestos con boundaries, y jerarquía de fallback sin GPU.

---

*SKULL · SBOS · SBOS-014-001 · Anexo 001 · v1.0 · Marzo 2026*
