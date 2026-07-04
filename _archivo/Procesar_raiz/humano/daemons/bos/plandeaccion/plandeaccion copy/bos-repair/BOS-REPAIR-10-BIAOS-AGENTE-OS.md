# BOS-REPAIR-10 — biaos: Agente IA Soberano + Gateway IA Centralizado
## Arquitectura completa, Entrenamiento e Integración JSON-RPC en el daemon bos
## SKULL · SBOS · BOS-REPAIR · v3.0 · Junio 2026

**Nombre:** biaos — Inteligencia Operativa Agente Sistema Operativo
**Componente nuevo. Separación de dominios inviolable:**
```
bkernel  → daemon Rust, WAL/PostgreSQL, nivel datos          (RESERVADO)
bcompass → Route Engine IA, nivel aplicaciones/negocio       (RESERVADO)
biaos    → agente IA OS + gateway IA centralizado            (ESTE DOCUMENTO)
```

**Documentos base incorporados:**
- `biaos-arquitectura.md` — Gateway singleton, ReAct Go puro, migración sin downtime
- `biaos-proyecto-ia-robusta.md` — ICAP Engine, 3 fases entrenamiento, NAACL/MetaKube/Agent-S
- `JSON-RPC-01..09` — Manual completo JSON-RPC del SBOS, especialmente Parte 9 (sagas)
- `00_MASTER_INSTALL_SBOS.sh` — Patrón Absorb/Execute/Release reutilizado en ICAP
- `00_YAML_ENGINE_SBOS.sh` — lifecycle phases, yaml_dispatch como base de catalog.go
- `00_ARCHITECTURE_SBOS.yml` — Modelo declarativo base de action_catalog.yml

---

## Parte 1 — Fundamento conceptual: dos responsabilidades, un componente

### 1.1 Las dos responsabilidades de biaos

```
┌─────────────────────────────────────────────────────────────────┐
│  RESPONSABILIDAD 1 — GATEWAY IA CENTRALIZADO                     │
│                                                                   │
│  Principio: mismo patrón que Kong (rutas HTTP) o Vault (secrets) │
│  Una sola configuración de modelos para todo el servidor.         │
│                                                                   │
│  bosctl set apikey deepseek=sk-...   ← una sola vez              │
│  bosctl set aimodel local=qwen3:8b   ← una sola vez              │
│                                                                   │
│  Todos los callers obtienen su cliente LLM aquí:                  │
│    bosctl ia  → bos.ai.ask (JSON-RPC) → biaos → LLM              │
│    bCompass   → bos.ai.ask (JSON-RPC) → biaos → LLM              │
│    bsearch    → bos.ai.ask (JSON-RPC) → biaos → LLM              │
│                                                                   │
│  Un solo circuit breaker: DeepSeek V4 → Claude → Ollama local    │
│  Un solo audit log de todas las llamadas IA del servidor          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  RESPONSABILIDAD 2 — AGENTE OS SOBERANO                          │
│                                                                   │
│  Interpreta lenguaje natural → orquesta sagas JSON-RPC           │
│  Dominio: Ubuntu + K8s + bos + fichas de infraestructura         │
│                                                                   │
│  "bos, por qué el sistema está lento"                            │
│    → ejecuta bos.query.system + bos.query.repair en paralelo     │
│    → analiza resultados con el modelo LLM                        │
│    → presenta diagnóstico + opciones del catálogo ICAP           │
│    → espera confirmación HITL                                    │
│    → ejecuta la saga de reparación via JSON-RPC                  │
│    → verifica resultado con bos.query.system                     │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Por qué JSON-RPC es la columna vertebral de biaos

El Manual JSON-RPC del SBOS (Partes 1-9) establece el principio fundamental:
el cliente no accede a *recursos* sino que invoca *procedimientos*. Para biaos
esto es exactamente correcto: el agente no "lee" el estado del sistema, *invoca*
`bos.query.system`. No "modifica" una ficha, *invoca* `bos.ficha.repair`.

El protocolo JSON-RPC 2.0 aporta cuatro capacidades críticas para biaos:

**Batch requests** (Parte 1 §3.5): las sagas de consulta del agente ejecutan
múltiples RPCs en paralelo enviando un solo array de requests. Redis, PostgreSQL
y el estado K8s se consultan simultáneamente en lugar de secuencialmente.

**Notificaciones** (Parte 1 §3.4): el agente puede emitir eventos "dispara y
olvida" al WebSocket de Core UI mientras ejecuta una saga larga, sin bloquear
el loop principal.

**Sagas con compensación** (Parte 9 §4): cuando una acción de reparación falla
a mitad, el motor de orquestación ejecuta las compensaciones en orden inverso.
Un nodo que queda en `cordon` sin `uncordon` es el ejemplo más crítico.

**Contexto distribuido** (Parte 9 §6): el `ctx_id` del operador se propaga sin
modificación a cada llamada RPC que el agente ejecuta. Todos los audit logs
quedan correlacionados bajo el mismo contexto.

### 1.3 El problema raíz: por qué NL libre no es viable en infraestructura

La investigación de NAACL 2025 establece que medir si un comando generado
libremente por un LLM es "correcto" es en sí mismo un problema no resuelto —
heurísticos anteriores fallaban en al menos 16% de casos. En infraestructura
productiva Kubernetes ese margen de error es inaceptable.

MetaKube (ACM Web 2026) confirma: Qwen3-8B sin especialización opera al 50.9%
de efectividad en diagnóstico K8s. Con fine-tuning sobre 7,000 ejemplos reales
llega al 90.5%. Sin ese fine-tuning el modelo improvisa comandos incorrectos.

El paper Agent-S (arXiv 2503.15520, 2025) propone la solución validada:
usar embeddings para identificar la acción del conjunto de acciones posibles
del catálogo mediante búsqueda por similitud coseno. La mejor coincidencia
es la acción seleccionada. El LLM nunca genera un comando — solo ayuda a
*encontrar* el más adecuado dentro de un conjunto cerrado y validado.

**La distinción fundamental:**

```
TIPO A — LECTURA (bajo riesgo — ReAct libre):
  El agente ejecuta bos.query.* con autonomía razonable
  Un error produce información incorrecta, no daño al sistema
  Ejemplos: consultar estado, leer logs, ver métricas, diagnosticar

TIPO B — ESCRITURA/EJECUCIÓN (alto riesgo — ICAP Engine):
  El agente NO genera comandos nuevos libremente
  Un error puede derribar servicios en producción
  Solución: catálogo cerrado + similitud coseno + HITL
  Ejemplos: repair, scale, drain, restart, cordon
```

---

## Parte 2 — JSON-RPC como protocolo de operación del agente

### 2.1 biaos como motor JSON-RPC (Parte 9 §9 del manual)

El manual JSON-RPC §9 establece: *"El orquestador es en sí mismo un motor
JSON-RPC. Sigue exactamente el patrón del manual: tiene un dispatcher, un
registro de métodos, autenticación y contexto."*

biaos cumple exactamente este patrón. Sus métodos públicos:

```json
// Catálogo de biaos via system.listMethods
{
  "id": 1,
  "method": "system.listMethods",
  "params": []
}
→ {
  "result": [
    "bos.ai.ask",        // Gateway LLM — todos los callers
    "bos.ai.run",        // Agente OS con ICAP — solo bosctl
    "bos.ai.confirm",    // Confirmar HITL pendiente
    "bos.ai.history",    // Historial de sesiones del agente
    "bos.ai.catalog",    // Ver catálogo de acciones disponibles
    "system.listMethods"
  ]
}
```

### 2.2 bos.ai.ask — el gateway para todos los callers

```json
// bCompass (pod K8s) → bos via Unix socket /run/bos/bos.sock
{
  "jsonrpc": "2.0",
  "id": "bcompass-req-001",
  "method": "bos.ai.ask",
  "params": {
    "prompt": "Analiza el patrón de ventas del último trimestre...",
    "system": "Eres un analista de negocio soberano...",
    "caller": "bcompass",
    "max_tokens": 2048,
    "ctx_id": "ctx-88291-a4f9"
  }
}

→ {
  "jsonrpc": "2.0",
  "id": "bcompass-req-001",
  "result": {
    "text": "El análisis indica...",
    "model_used": "deepseek-v4-pro",
    "tier": 1,
    "latency_ms": 342
  },
  "error": null
}
```

```json
// bsearch → bos.ai.ask para Schema Discoverer
{
  "jsonrpc": "2.0",
  "id": "bsearch-schema-007",
  "method": "bos.ai.ask",
  "params": {
    "prompt": "Analiza esta tabla PostgreSQL y genera patrones de búsqueda...",
    "system": "Eres un especialista en motores de búsqueda...",
    "caller": "bsearch",
    "max_tokens": 1024,
    "ctx_id": "ctx-system-bsearch"
  }
}
```

### 2.3 bos.ai.run — el agente OS con ICAP

```json
// bosctl ia "por qué el sistema está lento"
{
  "jsonrpc": "2.0",
  "id": "bosctl-ia-001",
  "method": "bos.ai.run",
  "params": {
    "query": "por qué el sistema está lento",
    "caller": "bosctl",
    "tenant_id": "skull",
    "ctx_id": "ctx-88291-a4f9",
    "stream": true
  }
}

// Respuesta streaming via WebSocket — eventos del loop ReAct:
{"type": "thought",      "content": "Consultando estado general del sistema"}
{"type": "action",       "content": "bos.query.system", "tool": "system_status"}
{"type": "observation",  "content": "{cpu:89%, redis:DEGRADADA, ctx:45}"}
{"type": "thought",      "content": "Redis degradado. Necesito diagnóstico específico"}
{"type": "action",       "content": "bos.query.repair", "tool": "diagnose_ficha",
                          "params": {"ficha_id":"redis"}}
{"type": "observation",  "content": "{causa:OOMKilled, mem:3.9/4GB, ctx_using:45}"}
{"type": "icap_options", "content": [
    {"rank":1,"id":"repair_ficha","score":0.91,"description":"Reparar redis..."},
    {"rank":2,"id":"scale_deployment","score":0.73,"description":"Escalar memoria..."}
  ]
}
{"type": "hitl",         "content": "¿Qué acción ejecuto? (1/2/cancelar)"}
```

### 2.4 bos.ai.confirm — reanudar después de HITL

```json
// Operador responde: "1"
{
  "jsonrpc": "2.0",
  "id": "bosctl-ia-002",
  "method": "bos.ai.confirm",
  "params": {
    "session_id": "sess-biaos-abc123",
    "selected": "repair_ficha",
    "params": {"ficha_id": "redis"},
    "confirmed": true,
    "ctx_id": "ctx-88291-a4f9"
  }
}

// El agente ejecuta la saga y retorna el resultado
→ {
  "result": {
    "action_executed": "repair_ficha",
    "rpc_called": "bos.ficha.repair",
    "outcome": "success",
    "duration_ms": 187432,
    "verification": {
      "bos_query_system": {"redis": "INSTALADA", "health": "OK"}
    }
  }
}
```

### 2.5 Batch requests en las sagas de consulta del agente

El agente usa batch JSON-RPC para ejecutar consultas paralelas (Parte 1 §3.5):

```json
// El agente envía internamente un batch para el diagnóstico inicial
[
  {
    "jsonrpc": "2.0",
    "id": "diag-1",
    "method": "bos.query.system",
    "params": {"tenant_id": "skull"}
  },
  {
    "jsonrpc": "2.0",
    "id": "diag-2",
    "method": "bos.health.check",
    "params": {}
  },
  {
    "jsonrpc": "2.0",
    "id": "diag-3",
    "method": "bos.ctx.list",
    "params": {"tenant_id": "skull"}
  }
]

// Las tres respuestas llegan en paralelo — correlación por id:
[
  {"id": "diag-1", "result": {"cpu_pct":89, "redis":"DEGRADADA", ...}},
  {"id": "diag-3", "result": {"ctx_activos":45, "promote_p99_ms":1240}},
  {"id": "diag-2", "result": {"critical_ok":false, "failed":["redis"]}}
]
```

---

## Parte 3 — Sagas de operación via JSON-RPC con compensación

### 3.1 Sagas de consulta (TIPO A — lectura, sin HITL)

Las sagas de consulta ejecutan múltiples RPCs en paralelo y agregan los resultados.
El agente las usa internamente para obtener evidencia antes de responder al operador.

```go
// internal/biaos/sagas/query.go

// SagaConsulta ejecuta múltiples bos.query.* en paralelo.
// Equivalente a un batch JSON-RPC desde el punto de vista del protocolo.
// Implementa el patrón de la Parte 9 §3 del manual: pasos sin depende_de
// se ejecutan concurrentemente.
type SagaConsulta struct {
    steps    []QueryStep
    timeout  time.Duration
    rpcConn  RPCCaller
}

type QueryStep struct {
    ID     string            // correlación — igual que id en JSON-RPC
    Method string            // "bos.query.system", "bos.query.repair", etc.
    Params map[string]any
    Result any               // llenado por Execute()
    Err    error
}

func (s *SagaConsulta) Execute(ctx context.Context) map[string]any {
    // Construir batch request (Parte 1 §3.5)
    batch := make([]map[string]any, len(s.steps))
    for i, step := range s.steps {
        batch[i] = map[string]any{
            "jsonrpc": "2.0",
            "id":      step.ID,
            "method":  step.Method,
            "params":  step.Params,
        }
    }

    // Un solo envío al socket — respuestas en paralelo
    responses, err := s.rpcConn.BatchCall(ctx, batch)
    if err != nil {
        // Si el batch falla completamente, degradar a llamadas individuales
        return s.executeSequential(ctx)
    }

    // Correlacionar respuestas por id (Parte 1 §3.5: no necesariamente en orden)
    results := make(map[string]any)
    for _, resp := range responses {
        results[resp["id"].(string)] = resp["result"]
    }
    return results
}
```

### 3.2 Sagas de acción (TIPO B — escritura, con HITL y compensación)

Las sagas de acción siguen el patrón Saga del manual (Parte 9 §4) con pasos
y compensaciones. El agente las ejecuta SOLO después de confirmación HITL.

```yaml
# /etc/bos/ai/sagas/repair-ficha.yml
# Mismo formato que flujos multi-motor del manual JSON-RPC Parte 9 §5

id: repair-ficha
nombre: "Reparación controlada de una ficha SBOS"
version: "1.0.0"

entrada:
  ficha_id: {tipo: string, requerido: true}
  tenant_id: {tipo: string, requerido: false}

reintentos:
  max_intentos: 2
  espera_inicial_ms: 5000
  tipo: exponencial

pasos:
  - id: pre-diagnose
    motor: bos
    metodo: bos.query.repair
    params:
      ficha_id: "{{entrada.ficha_id}}"
      tenant_id: "{{entrada.tenant_id}}"
    guardar_como: diagnosis
    on_failure: abort
    # No tiene compensación — es solo lectura

  - id: validate-safe-to-repair
    motor: bos
    metodo: bos.query.system
    params: {}
    guardar_como: system_state
    on_failure: abort
    # Verifica que el sistema tiene capacidad para absorber la reparación

  - id: execute-repair
    motor: bos
    metodo: bos.ficha.repair
    depende_de: [pre-diagnose, validate-safe-to-repair]
    params:
      ficha_id: "{{entrada.ficha_id}}"
    guardar_como: repair_result
    compensar:
      metodo: bos.ficha.rollback      # si disponible en la ficha
      params:
        ficha_id: "{{entrada.ficha_id}}"
        snapshot_id: "{{repair_result.snapshot_id}}"
    on_failure: abort

  - id: verify-recovery
    motor: bos
    metodo: bos.ficha.probe
    depende_de: execute-repair
    params:
      ficha_id: "{{entrada.ficha_id}}"
    on_failure: continue             # si probe falla, reportar pero no compensar
```

```yaml
# /etc/bos/ai/sagas/node-maintain.yml

id: node-maintain
nombre: "Mantenimiento controlado de nodo (cordon→drain→op→uncordon)"
version: "1.0.0"

entrada:
  node:      {tipo: string,  requerido: true}
  op:        {tipo: string,  requerido: true}
  schedule:  {tipo: string,  requerido: false}

pasos:
  - id: check-capacity
    motor: bos
    metodo: bos.query.node
    params:
      node: "{{entrada.node}}"
    guardar_como: node_state
    # Verifica que el cluster tiene capacidad para absorber el drain
    on_failure: abort

  - id: cordon-node
    motor: bos
    metodo: bos.k8s.node.cordon
    depende_de: check-capacity
    params:
      node: "{{entrada.node}}"
    guardar_como: cordon_result
    compensar:
      # CRÍTICO: si algo falla después del cordon, siempre uncordon
      metodo: bos.k8s.node.uncordon
      params:
        node: "{{entrada.node}}"
    on_failure: abort

  - id: drain-node
    motor: bos
    metodo: bos.k8s.node.drain
    depende_de: cordon-node
    params:
      node: "{{entrada.node}}"
      timeout: "300s"
    guardar_como: drain_result
    compensar:
      metodo: bos.k8s.node.uncordon
      params:
        node: "{{entrada.node}}"
    on_failure: abort

  - id: execute-op
    motor: bos
    metodo: bos.maintenance.execute_op
    depende_de: drain-node
    params:
      node: "{{entrada.node}}"
      op:   "{{entrada.op}}"
    guardar_como: op_result
    compensar:
      metodo: bos.k8s.node.uncordon
      params:
        node: "{{entrada.node}}"
    on_failure: abort

  - id: uncordon-node
    motor: bos
    metodo: bos.k8s.node.uncordon
    depende_de: execute-op
    params:
      node: "{{entrada.node}}"
    on_failure: continue              # intentar uncordon aunque falle
    # No tiene compensación — el uncordon es la compensación de todo lo anterior

  - id: verify-node
    motor: bos
    metodo: bos.query.node
    depende_de: uncordon-node
    params:
      node: "{{entrada.node}}"
    on_failure: continue
```

### 3.3 Motor de sagas de biaos en Go — implementación

```go
// internal/biaos/sagas/engine.go

// SagaEngine ejecuta sagas declarativas YAML (mismo formato que Parte 9 manual).
// Mantiene estado de ejecución con compensación automática en fallo.
//
// Callers: internal/biaos/icap.go (acciones del catálogo ICAP)
// Estándar: Parte 9 JSON-RPC manual SBOS — Patrón Saga
type SagaEngine struct {
    rpc     RPCCaller         // llama a métodos bos.* via JSON-RPC
    store   ExecutionStore    // persiste estado de ejecución
    logger  *slog.Logger
    auditFn AuditFn           // ISO 27001 A.8.15
}

// Execute ejecuta una saga definida en YAML.
// Bloqueante hasta completar, compensar, o agotar reintentos.
// ctxID se propaga a CADA llamada RPC (Parte 9 §6 — contexto distribuido).
func (e *SagaEngine) Execute(
    ctx     context.Context,
    sagaDef *SagaDefinition,
    params  map[string]any,
    ctxID   string,           // ctx_id del operador — propagado a todos los pasos
    caller  string,
) (*SagaExecution, error) {

    ejec := &SagaExecution{
        ID:        uuid.New().String(),
        SagaID:    sagaDef.ID,
        Estado:    EstadoEjecutando,
        Variables: maps.Clone(params),  // inputs disponibles como {{entrada.*}}
        CtxID:     ctxID,
        Caller:    caller,
    }
    e.store.Save(ejec)

    // Audit de inicio (ISO 27001 A.8.15)
    e.auditFn("SAGA_START", caller, sagaDef.ID, params)

    // Resolver orden de ejecución (DAG — pasos con depende_de)
    ordered, err := e.topoSort(sagaDef.Pasos)
    if err != nil {
        return nil, fmt.Errorf("saga %s: topological sort: %w", sagaDef.ID, err)
    }

    for _, paso := range ordered {
        if err := e.executeStep(ctx, ejec, paso, ctxID); err != nil {
            // Paso falló con política abort → compensar en orden inverso
            e.compensate(ctx, ejec, ctxID)
            e.auditFn("SAGA_COMPENSATED", caller, sagaDef.ID, err.Error())
            return ejec, err
        }
    }

    ejec.Estado = EstadoCompletado
    e.store.Save(ejec)
    e.auditFn("SAGA_COMPLETED", caller, sagaDef.ID, ejec.Variables)
    return ejec, nil
}

func (e *SagaEngine) executeStep(
    ctx   context.Context,
    ejec  *SagaExecution,
    paso  *SagaPaso,
    ctxID string,
) error {
    // Resolver plantillas {{entrada.*}} y {{guardar_como}} (Parte 9 §5)
    resolvedParams := resolveTemplates(paso.Params, ejec.Variables)

    // Audit antes de ejecutar (ISO 27001 A.8.15)
    e.auditFn("SAGA_STEP_START", ejec.Caller, paso.ID, resolvedParams)

    // Llamar JSON-RPC con ctx_id propagado (Parte 9 §6)
    result, err := e.rpc.Call(ctx, paso.Metodo, resolvedParams, RPCContext{
        CtxID:    ctxID,
        Caller:   "biaos",
        StepID:   paso.ID,
        SagaID:   ejec.SagaID,
        ExecID:   ejec.ID,
    })

    if err != nil {
        e.auditFn("SAGA_STEP_FAIL", ejec.Caller, paso.ID, err.Error())

        // Reintentos con backoff exponencial (Parte 6 §3 del manual)
        if paso.Reintentos > 0 {
            result, err = e.retryWithBackoff(ctx, paso, resolvedParams, ctxID)
        }

        if err != nil && paso.OnFailure == "abort" {
            return fmt.Errorf("paso '%s' falló: %w", paso.ID, err)
        }
        return nil  // on_failure: continue o skip
    }

    // Guardar output para plantillas de pasos siguientes
    if paso.GuardarComo != "" {
        ejec.Variables[paso.GuardarComo] = result
    }
    ejec.PasosOK = append(ejec.PasosOK, paso)
    e.store.Save(ejec)
    e.auditFn("SAGA_STEP_OK", ejec.Caller, paso.ID, result)
    return nil
}

// compensate ejecuta compensaciones en orden inverso (Parte 9 §4)
func (e *SagaEngine) compensate(ctx context.Context, ejec *SagaExecution, ctxID string) {
    ejec.Estado = EstadoCompensando
    e.store.Save(ejec)

    for i := len(ejec.PasosOK) - 1; i >= 0; i-- {
        paso := ejec.PasosOK[i]
        if paso.Compensar == nil {
            continue
        }

        // Las compensaciones usan {{guardar_como}} del paso (Parte 9 §4)
        compensParams := resolveTemplates(paso.Compensar.Params, ejec.Variables)
        e.auditFn("SAGA_COMPENSATE", ejec.Caller, paso.ID, compensParams)

        _, err := e.rpc.Call(ctx, paso.Compensar.Metodo, compensParams, RPCContext{
            CtxID:  ctxID,
            Caller: "biaos-compensate",
        })
        if err != nil {
            // Errores de compensación se loguean pero no abortan la compensación
            // (Parte 9 §4: compensación falla → continuar con el anterior)
            e.logger.Error("compensación falló", "paso", paso.ID, "err", err)
        }
    }

    ejec.Estado = EstadoCompensado
    e.store.Save(ejec)
}
```

---

## Parte 4 — El ICAP Engine: catálogo de acciones como fichas del bos

### 4.1 El insight arquitectónico central

Las fichas del bos tienen un patrón maduro y probado:
- `00_ARCHITECTURE_SBOS.yml` → declara qué fichas existen y sus fases del lifecycle
- `00_YAML_ENGINE_SBOS.sh` → lee el YAML y despacha handlers (yaml_dispatch)
- `00_TASK_CATALOG_SBOS.sh` → funciones handler concretas
- `00_MASTER_INSTALL_SBOS.sh` → orquesta con Absorb/Execute/Release

El ICAP Engine de biaos replica este patrón con exactitud quirúrgica:

```
fichas del bos               ICAP Engine de biaos
─────────────────────────────────────────────────────────
00_ARCHITECTURE_SBOS.yml  →  /etc/bos/ai/action_catalog.yml
yaml_dispatch()            →  catalog.go:FindSimilar()
Absorb/Execute/Release     →  icap.go:ExecuteAction()
Señales __SBOS__STEP_*__   →  AgentEvent{type:"action"|"ok"|"fail"}
lifecycle.fases            →  SagaDefinition.Pasos
task_catalog.sh funciones  →  bos.ficha.* JSON-RPC handlers
```

### 4.2 El catálogo de acciones — declaración completa

```yaml
# /etc/bos/ai/action_catalog.yml
# Equivalente a 00_ARCHITECTURE_SBOS.yml pero para acciones IA

metadata:
  version: "1.0"
  dominio: "os"           # NUNCA "negocio" — guardia de dominio en runtime

# ── ACCIONES DE LECTURA (categoria: 1) — ReAct libre, sin HITL ──────────

acciones:
  query_system:
    descripcion: "Estado completo del sistema OS, K8s y fichas"
    categoria: 1
    rpc_method: "bos.query.system"
    saga_id: null                    # lectura simple, sin saga multi-paso
    requiere_hitl: false
    embedding_texto: >
      estado sistema salud health fichas pods kubernetes ubuntu
      lento error degradado problema fallo general revisar

  diagnose_ficha:
    descripcion: "Diagnóstico detallado de una ficha específica"
    categoria: 1
    rpc_method: "bos.query.repair"
    requiere_hitl: false
    embedding_texto: >
      diagnosticar investigar por qué falla causa error crash
      diagnose pod log específico ficha kubernetes bos

  check_node:
    descripcion: "Estado de recursos y fichas en un nodo K8s"
    categoria: 1
    rpc_method: "bos.query.node"
    requiere_hitl: false
    embedding_texto: >
      nodo node recurso cpu memoria disco capacidad
      host servidor hardware estado kubernetes

  get_logs:
    descripcion: "Logs recientes de una ficha de infraestructura"
    categoria: 1
    rpc_method: "bos.ficha.logs"
    requiere_hitl: false
    embedding_texto: >
      logs registros errores stderr stdout output
      log journal journal ficha pod container

  vdi_status:
    descripcion: "Estado del VDI Layer: pods Fedora, sesiones, Nextcloud"
    categoria: 1
    rpc_method: "bos.query.vdi"
    requiere_hitl: false
    embedding_texto: >
      vdi virtual desktop escritorio fedora guacamole nextcloud
      sesión usuario acceso remoto navegador

# ── ACCIONES DE ESCRITURA (categoria: 2) — ICAP + HITL simple ──────────

  repair_ficha:
    descripcion: "Reparación controlada de una ficha SBOS degradada"
    categoria: 2
    saga_id: "repair-ficha"          # ejecuta la saga completa con compensación
    requiere_hitl: true
    hitl_doble: false
    params_requeridos: ["ficha_id"]
    riesgo: "Interrupción del servicio ~2-5 minutos"
    embedding_texto: >
      reparar reiniciar recuperar ficha degradada falla
      repair restart fix pod kubernetes bos service

  scale_deployment:
    descripcion: "Ajustar réplicas o recursos (memoria/CPU) de una ficha"
    categoria: 2
    saga_id: null
    rpc_method: "bos.ficha.scale"
    requiere_hitl: true
    hitl_doble: false
    params_requeridos: ["ficha_id"]
    params_opcionales: ["replicas", "memory_limit", "cpu_limit"]
    riesgo: "Redistribución de pods, posible downtime breve"
    embedding_texto: >
      escalar recursos memoria cpu réplicas aumentar crecer
      scale up down deployment kubernetes ajustar capacidad

  upgrade_ficha:
    descripcion: "Actualizar una ficha a nueva versión con rollback automático"
    categoria: 2
    saga_id: "upgrade-ficha"
    requiere_hitl: true
    hitl_doble: false
    params_requeridos: ["ficha_id", "version"]
    riesgo: "Downtime ~5-10 min, rollback automático si falla"
    embedding_texto: >
      actualizar upgrade versión nueva update parche
      upgrade ficha version kubernetes deploy

# ── ACCIONES DESTRUCTIVAS (categoria: 3) — HITL doble ───────────────────

  node_maintain:
    descripcion: "Mantenimiento de nodo: cordon → drain → operación → uncordon"
    categoria: 3
    saga_id: "node-maintain"         # saga completa con compensación (siempre uncordon)
    requiere_hitl: true
    hitl_doble: true                 # dos confirmaciones requeridas
    params_requeridos: ["node", "op"]
    riesgo: "Migración de todos los pods del nodo, ~10-15 minutos"
    embedding_texto: >
      mantenimiento nodo maintenance node cordon drain
      actualizar parche nodo host servidor kubernetes

  tenant_suspend:
    descripcion: "Suspender todos los contextos de un tenant"
    categoria: 3
    saga_id: "tenant-suspend"
    requiere_hitl: true
    hitl_doble: true
    params_requeridos: ["tenant_id"]
    riesgo: "TODOS los usuarios del tenant pierden acceso inmediatamente"
    embedding_texto: >
      suspender tenant empresa suspender acceso bloquear
      suspend tenant disable lock all users
```

### 4.3 Búsqueda por similitud coseno — el corazón del ICAP

```go
// internal/biaos/icap/catalog.go

// FindSimilar implementa la búsqueda coseno del paper Agent-S (arXiv 2503.15520):
// "usamos un modelo de embeddings para identificar la acción del catálogo.
//  Realizamos una búsqueda por similitud coseno — la mejor coincidencia
//  es la acción seleccionada."
//
// Los vectores del catálogo se pre-calculan en startup y se actualizan
// solo cuando cambia action_catalog.yml.
func (c *Catalog) FindSimilar(queryVec []float32, topN int) []ScoredAction {
    c.mu.RLock()
    defer c.mu.RUnlock()

    type scored struct {
        id    string
        score float32
    }
    results := make([]scored, 0, len(c.vectors))

    for id, vec := range c.vectors {
        score := cosineSimilarity(queryVec, vec)
        results = append(results, scored{id, score})
    }

    sort.Slice(results, func(i, j int) bool {
        return results[i].score > results[j].score
    })

    top := make([]ScoredAction, 0, topN)
    for i := 0; i < topN && i < len(results); i++ {
        action := c.actions[results[i].id]
        top = append(top, ScoredAction{
            Action: action,
            Score:  results[i].score,
        })
    }
    return top
}

// cosineSimilarity calcula similitud coseno entre dos vectores float32.
// stdlib únicamente — sin librerías de álgebra lineal externas.
func cosineSimilarity(a, b []float32) float32 {
    var dot, normA, normB float32
    for i := range a {
        dot   += a[i] * b[i]
        normA += a[i] * a[i]
        normB += b[i] * b[i]
    }
    if normA == 0 || normB == 0 {
        return 0
    }
    return dot / (float32(math.Sqrt(float64(normA))) * float32(math.Sqrt(float64(normB))))
}
```

---

## Parte 5 — Arquitectura completa del componente

### 5.1 Estructura de paquetes

```
internal/biaos/
├── doc.go                  ← godoc: propósito dual, frontera de dominio, callers
├── gateway.go              ← Gateway singleton sync.Once — punto único de acceso
├── router.go               ← ModelRouter (migrado de internal/ai/model_router.go)
├── client.go               ← Cliente LLM (migrado de internal/ai/client.go)
├── agent.go                ← ReAct loop OS-only (TIPO A — lectura)
├── safety.go               ← RBAC + guardia de dominio + audit
├── session.go              ← Estado HITL (map[sessionID]SessionState + RWMutex)
├── prompt.go               ← System Prompt OS-only + Modelfile
├── icap/
│   ├── doc.go              ← godoc del subpaquete ICAP
│   ├── catalog.go          ← carga action_catalog.yml + pre-calcula vectores
│   ├── engine.go           ← ExecuteAction con Absorb/Execute/Release
│   └── embed.go            ← embeddings via Ollama API + cosine similarity
├── sagas/
│   ├── doc.go              ← godoc del motor de sagas
│   ├── engine.go           ← SagaEngine: Execute + compensate + retryWithBackoff
│   ├── loader.go           ← carga sagas/*.yml (mismo formato Parte 9 manual)
│   └── store.go            ← persistencia de ejecuciones en /var/lib/bos/ai/sagas/
└── audit/
    ├── doc.go
    └── logger.go           ← ISO 27001 A.8.15: audit async via canal buffereado
```

### 5.2 Gateway singleton — arranque en runNormal()

```go
// cmd/bos/main.go — biaos se inicializa UNA SOLA VEZ

func runNormal(ctx context.Context, cfg *config.Config) error {
    // 1. biaos PRIMERO — todos los métodos RPC que lo usan vienen después
    biaosGW, err := biaos.New(biaos.Config{
        DeepSeekAPIKey:  cfg.AI.DeepSeekAPIKey,
        AnthropicAPIKey: cfg.AI.AnthropicAPIKey,
        LocalEndpoint:   cfg.AI.LocalEndpoint,
        LocalModel:      cfg.AI.LocalModel,
        CatalogPath:     "/etc/bos/ai/action_catalog.yml",
        SagasDir:        "/etc/bos/ai/sagas/",
        AuditLogPath:    "/var/log/bos/ai-audit.jsonl",
    })
    if err != nil {
        return fmt.Errorf("biaos init: %w", err)
    }

    // 2. Registrar métodos JSON-RPC de biaos en el server
    server.Register("bos.ai.ask",     biaosGW.HandleAsk)      // todos los callers
    server.Register("bos.ai.run",     biaosGW.HandleRunAgent)  // solo bosctl
    server.Register("bos.ai.confirm", biaosGW.HandleConfirm)   // HITL
    server.Register("bos.ai.history", biaosGW.HandleHistory)   // historial
    server.Register("bos.ai.catalog", biaosGW.HandleCatalog)   // introspección

    // 3. biaos no tiene goroutines permanentes propias.
    // Cada llamada Ask/RunAgent genera goroutines por-request.
    // ctx cancela todo en shutdown limpio.

    return eventLoop(ctx, cfg)
}
```

### 5.3 Guardia de dominio en runtime

```go
// internal/biaos/safety.go

// validateRequest verifica que el caller no cruce la frontera de dominio.
// bCompass puede usar Ask() para LLM de negocio — NUNCA RunAgent() OS.
// Implementa la tabla de la Parte 3.3 de la arquitectura.
func (g *Gateway) validateRequest(req AskRequest) error {
    switch req.Caller {
    case "bcompass":
        // bCompass: solo Ask() con prompts de negocio
        // Nunca puede activar herramientas OS ni el agente OS
        if containsOSKeywords(req.System) {
            return fmt.Errorf("biaos: %w — bcompass no puede usar dominio OS",
                ErrDomainViolation)
        }
    case "bsearch":
        // bsearch: solo Ask() para Schema Discoverer
        if containsOSKeywords(req.System) {
            return fmt.Errorf("biaos: %w — bsearch no puede usar dominio OS",
                ErrDomainViolation)
        }
    case "bosctl":
        // bosctl: acceso completo — Ask() + RunAgent() + todas las herramientas
    default:
        return fmt.Errorf("biaos: caller desconocido: %s", req.Caller)
    }
    return nil
}

var osKeywords = []string{
    "repair_ficha", "scale_deployment", "query_system_status",
    "kubectl", "systemctl", "bosctl", "ficha", "daemon soberano",
    "kubernetes", "pod", "nodo", "k8s", "ubuntu", "systemd",
}
```

### 5.4 Manejo de errores JSON-RPC (Parte 6 del manual)

```go
// internal/biaos/agent.go
// Manejo de errores siguiendo la taxonomía del manual (Parte 6 §1)

func (a *ReActAgent) executeToolRPC(ctx context.Context,
    method string, params map[string]any) (any, error) {

    result, err := a.rpcConn.Call(ctx, method, params)
    if err == nil {
        return result, nil
    }

    // Clasificar el error según código JSON-RPC (Parte 6 §1)
    var rpcErr *RPCError
    if errors.As(err, &rpcErr) {
        switch rpcErr.Code {
        case -32601: // MethodNotFound
            return nil, fmt.Errorf("herramienta %s no disponible: %w",
                method, ErrToolNotFound)
        case -32602: // InvalidParams
            return nil, fmt.Errorf("parámetros inválidos para %s: %w",
                method, ErrInvalidParams)
        case -32000: // GovernanceDeny
            return nil, fmt.Errorf("operación denegada por governance: %w",
                ErrGovernanceDeny)
        case -32603: // InternalError — reintentar con backoff
            return a.retryWithBackoff(ctx, method, params, 3)
        }
    }
    return nil, fmt.Errorf("tool %s: %w", method, err)
}
```

---

## Parte 6 — Entrenamiento progresivo en 3 fases

### Fase 1 — HOY (costo $0): Modelfile + System Prompt OS-only

```
# /etc/bos/ai/Modelfile.biaos

FROM qwen3:8b-q4

PARAMETER temperature 0.1    # determinismo — infraestructura no tolera creatividad
PARAMETER top_p 0.9
PARAMETER num_ctx 8192

SYSTEM """
Eres biaos, el agente de operaciones OS del SBOS.

DOMINIO EXCLUSIVO — solo esto:
  Ubuntu, Kubernetes, fichas de infraestructura bos.
  Fichas: postgresql, redis, vault, keycloak, kong, calico,
          linkerd, prometheus, grafana, certbot, minio, notifier.

PROHIBIDO ABSOLUTAMENTE — nunca respondas sobre:
  Datos de negocio: facturas, ventas, empleados, inventario.
  Apps de negocio: Tryton, OrangeHRM, Saleor, biedata.
  Si te preguntan esto: "Esa consulta corresponde a bCompass."

FORMATO OBLIGATORIO — elige UNO por turno:

  Opción A: necesitas datos del sistema
  Thought: [razonamiento en una línea]
  Action: nombre_herramienta({"param": "valor"})

  Opción B: tienes evidencia suficiente para responder
  Thought: [razonamiento en una línea]
  Final: [respuesta para el operador con datos reales]

HERRAMIENTAS DE LECTURA (ejecutar sin confirmación):
  query_system_status()                           → estado general
  diagnose_ficha({"ficha_id": "nombre"})          → diagnóstico
  check_node_resources({"node": "nombre"})        → recursos nodo
  get_pod_logs({"ficha_id": "nombre", "lines": 50}) → logs
  vdi_status({"tenant_id": "nombre"})             → VDI Layer

ACCIONES (proponer al operador — ICAP las ejecuta):
  repair_ficha      — [REQUIERE CONFIRMACIÓN] reparar ficha
  scale_deployment  — [REQUIERE CONFIRMACIÓN] escalar recursos
  node_maintain     — [REQUIERE DOBLE CONFIRMACIÓN] mantenimiento nodo

PRINCIPIOS INVIOLABLES:
  1. Siempre diagnostica ANTES de proponer acciones.
  2. Sin evidencia en logs: no propones repair.
  3. Respuesta sin usar al menos UNA herramienta = PROHIBIDO.
  4. Propones acciones — el ICAP Engine ejecuta. Nunca al revés.
  5. Responde en español, conciso, orientado a la solución.
"""
```

```bash
# Activar:
ollama create biaos -f /etc/bos/ai/Modelfile.biaos
bosctl set aimodel local=biaos
```

**Resultado esperado Fase 1:** 50-60% efectividad en diagnóstico complejo.
Las acciones de escritura son 100% seguras via ICAP + HITL.

### Fase 2 — Mes 2-3: SFT desde el audit log real

**Trigger:** 300+ trayectorias completas verificadas en el audit log.

El audit log de biaos tiene formato JSONL desde el primer día:

```jsonl
{
  "timestamp": "2026-06-07T14:32:00Z",
  "session_id": "sess-abc123",
  "caller": "bosctl",
  "ctx_id": "ctx-88291-a4f9",
  "query": "bos, por qué el sistema está lento",
  "trajectory": [
    {
      "step": 1,
      "thought": "Consultar estado general primero",
      "action": "query_system_status",
      "params": {},
      "observation": "{\"cpu_pct\":89,\"redis\":\"DEGRADADA\",\"ctx_activos\":45}"
    },
    {
      "step": 2,
      "thought": "Redis DEGRADADA. Necesito diagnóstico específico",
      "action": "diagnose_ficha",
      "params": {"ficha_id":"redis"},
      "observation": "{\"causa\":\"OOMKilled\",\"mem\":\"3.9/4GB\"}"
    },
    {
      "step": 3,
      "thought": "Tengo evidencia. Presentar ICAP options",
      "final": "Redis usa 97% de memoria..."
    }
  ],
  "icap": {
    "options_shown": ["repair_ficha","scale_deployment"],
    "selected": "repair_ficha",
    "confirmed": true,
    "saga_id": "repair-ficha",
    "saga_outcome": "completed"
  },
  "outcome_verified": true,
  "system_recovered": true,
  "operator_feedback": "correcto, resolvió el problema"
}
```

```bash
# Pipeline SFT (cuando haya 300+ trayectorias):
bosctl ai dataset build \
  --input /var/log/bos/ai-audit.jsonl \
  --output /var/lib/bos/ai/training/sft-v1.jsonl \
  --filter "outcome_verified=true AND system_recovered=true" \
  --format qwen3-chat    # Qwen3 chat template para tool use

# Fine-tuning con Unsloth QLoRA (8GB VRAM, qwen3:8b-q4 ~6GB)
unsloth-train \
  --model qwen3:8b \
  --dataset /var/lib/bos/ai/training/sft-v1.jsonl \
  --output /var/lib/bos/ai/adapters/biaos-sft-v1 \
  --method qlora --r 16 --alpha 32

# Activar:
echo "ADAPTER /var/lib/bos/ai/adapters/biaos-sft-v1" >> /etc/bos/ai/Modelfile.biaos
ollama create biaos -f /etc/bos/ai/Modelfile.biaos
```

**Resultado esperado Fase 2:** 75-80% efectividad (basado en MetaKube).

### Fase 3 — Mes 4+: RLVR con outcome real verificable

```
Señal de recompensa objetiva y verificable:

  SAGA repair-ficha completada
    → bos.ficha.probe en la ficha reparada
    → probe healthy: true  → recompensa +1.0
    → probe healthy: false → recompensa -0.5

  SAGA node-maintain completada
    → bos.query.node después del uncordon
    → node.status == "Ready" → recompensa +1.0
    → node.status != "Ready" → recompensa -1.0

  Respuesta TIPO A sin ejecutar herramientas:
    → recompensa -2.0 (anti-hallucination fuerte)

SFT enseña a imitar trayectorias correctas.
RLVR enseña a generalizar hacia fallos nuevos no vistos.
Resultado esperado: ~90%+ (basado en MetaKube con fine-tuning completo).
```

---

## Parte 7 — Migración sin downtime de internal/ai/

```
Paso 1 (Fase 10 del plan):
  biaos.New() wrappea internal/ai/model_router.go
  cmd/bosctl/ask.go sigue funcionando igual
  bos.ai.ask disponible como nuevo endpoint

Paso 2 (cuando bCompass y bsearch migren):
  cmd/bosctl/ask.go llama bos.ai.run via JSON-RPC
  bCompass usa bos.ai.ask via hostPath socket

Paso 3 (verificación):
  grep -r "internal/ai" --include="*.go" .
  # Si vacío → safe to delete

  rm -rf internal/ai/
```

---

## Parte 8 — Tareas para BOS-REPAIR-05 §Fase 10

```
F10.1  /etc/bos/ai/action_catalog.yml     ← catálogo ICAP (TIPO A y B)
F10.2  /etc/bos/ai/sagas/repair-ficha.yml ← saga con compensación
F10.3  /etc/bos/ai/sagas/node-maintain.yml← saga con compensación siempre uncordon
F10.4  /etc/bos/ai/sagas/upgrade-ficha.yml← saga con rollback automático
F10.5  /etc/bos/ai/Modelfile.biaos        ← especialización OS-only
F10.6  internal/biaos/doc.go              ← godoc propósito dual + frontera
F10.7  internal/biaos/gateway.go          ← singleton sync.Once
F10.8  internal/biaos/router.go           ← migrar de internal/ai/model_router.go
F10.9  internal/biaos/client.go           ← migrar de internal/ai/client.go
F10.10 internal/biaos/agent.go            ← ReAct loop TIPO A (≤6 iter)
F10.11 internal/biaos/safety.go           ← RBAC + guardia dominio
F10.12 internal/biaos/session.go          ← HITL state (map + RWMutex + TTL)
F10.13 internal/biaos/prompt.go           ← System Prompt OS-only
F10.14 internal/biaos/icap/catalog.go     ← carga YAML + pre-calcula vectores
F10.15 internal/biaos/icap/engine.go      ← ExecuteAction Absorb/Execute/Release
F10.16 internal/biaos/icap/embed.go       ← embeddings Ollama API + cosine
F10.17 internal/biaos/sagas/engine.go     ← SagaEngine (Parte 9 JSON-RPC manual)
F10.18 internal/biaos/sagas/loader.go     ← carga sagas/*.yml
F10.19 internal/biaos/sagas/store.go      ← persistencia ejecuciones
F10.20 internal/biaos/audit/logger.go     ← ISO 27001 A.8.15 async
F10.21 jsonrpc: bos.ai.ask/run/confirm/history/catalog
F10.22 cmd/bosctl/ask.go → migrar a bos.ai.run via JSON-RPC (Paso 2 migración)
F10.23 bosctl ai dataset build             ← extrae trayectorias del audit log
F10.24 Tests:
         TestICAPEngine_NeverGeneratesCommands
         TestSaga_AlwaysUncordonOnFail
         TestBatchQuery_ExecutesParallel
         TestGateway_CompassCannotRunAgent
         TestDomainGuard_RejectsBusinessData
         TestAudit_AlwaysBeforeToolExecution
         TestHITL_ExpiresAfterTimeout
         TestPhase1_ModelfileActivates
```

---

## Parte 9 — Prompt de investigación ampliado

```
═══════════════════════════════════════════════════════════════════
PROMPT — biaos: Implementación Go, Entrenamiento y Sagas JSON-RPC
Versión 2.0 — incluye patrón Parte 9 del manual JSON-RPC SBOS
═══════════════════════════════════════════════════════════════════

CONTEXTO DEL SISTEMA:
biaos es un subsistema Go (Go 1.25 stdlib, sin frameworks externos)
que vive dentro del daemon bos. Tiene dos roles:
1. Gateway IA centralizado (sync.Once singleton, único punto de modelos)
2. Agente OS soberano con ICAP Engine y motor de sagas JSON-RPC

MÉTODO JSON-RPC EN SBOS (Partes 1-9 del manual):
El protocolo JSON-RPC 2.0 es la columna vertebral del SBOS.
biaos ya tiene acceso a estos métodos via Unix socket:
  bos.query.system/repair/vdi/node/context (lectura — batch paralelo)
  bos.ficha.repair/scale/probe (escritura — con HITL)
  bos.k8s.node.cordon/drain/uncordon (destructivo — saga con compensación)
  bos.maintenance.start (saga multi-paso — siempre uncordon en compensación)

EL MOTOR DE SAGAS (Parte 9 del manual, implementar en Go):
El motor de orquestación multi-motor del manual (Python) debe
reimplementarse en Go para ejecutarse dentro del daemon bos.
El formato YAML de las sagas es idéntico al manual:
  - pasos con depende_de (DAG de ejecución)
  - compensar por paso (rollback en orden inverso)
  - on_failure: abort|continue|skip
  - guardar_como para pasar outputs entre pasos
  - reintentos con backoff exponencial

PREGUNTA 1 — Motor de sagas en Go (Parte 9):
Implementar SagaEngine.Execute() que:
  a) Resuelva el DAG de pasos con topologicalSort()
  b) Ejecute pasos sin depende_de en paralelo (goroutines)
  c) Propague ctx_id a cada llamada RPC (Parte 9 §6)
  d) En fallo: ejecute compensaciones en orden inverso (Parte 9 §4)
  e) Persista estado en /var/lib/bos/ai/sagas/ (recovery ante crash)
¿Cómo garantizar que el uncordon siempre se ejecuta aunque el proceso
crash antes de llegar al paso de compensación?

PREGUNTA 2 — ICAP Engine con catálogo como fichas:
El action_catalog.yml sigue el mismo patrón que 00_ARCHITECTURE_SBOS.yml.
catalog.go carga el YAML y pre-calcula embeddings via Ollama API
(/api/embeddings con nomic-embed o similar).
¿Cómo guardar los vectores pre-calculados en /var/lib/bos/ai/catalog-vectors.bin
(formato binario eficiente) para no recalcularlos en cada arranque?
¿Cuándo invalidar el caché? (cuando cambia action_catalog.yml — hash SHA-256)

PREGUNTA 3 — Batch JSON-RPC para sagas de consulta paralelas:
El agente envía internamente un batch de 3-6 queries simultáneas
(bos.query.system + bos.query.repair + bos.ctx.list) en un solo
array JSON-RPC. ¿Cómo implementar BatchCall() en Go sobre Unix socket
garantizando correlación de respuestas por id aunque lleguen desordenadas?

PREGUNTA 4 — Entrenamiento Fase 2 (SFT desde audit log):
El audit log tiene formato JSONL con trayectorias ReAct completas.
Qwen3 usa el chat template específico para tool use.
¿Cuál es el formato exacto de cada entrada JSONL para el fine-tuning
con Unsloth QLoRA sobre Qwen3-8B? Específicamente:
  - ¿Cómo se representa Thought/Action/Observation en el chat template?
  - ¿Cómo se incluye el system prompt del Modelfile en el dataset?
  - ¿Qué hace que una trayectoria sea "buena" para SFT vs "mala"?

PREGUNTA 5 — RLVR con outcome verificable de sagas:
La señal de recompensa proviene del resultado real de la saga:
  repair-ficha → bos.ficha.probe → healthy:true/false → +1/-0.5
  node-maintain → bos.query.node → status:Ready → +1.0/-1.0
¿Cómo implementar el ambiente de evaluación aislado en k3s?
Opciones: vcluster (cluster virtual dentro del cluster real),
namespace aislado con NetworkPolicy, o cluster de prueba separado.
¿Cuál tiene el menor overhead para un servidor con 8GB VRAM?

PREGUNTA 6 — Estado HITL con TTL y recovery:
El mapa de sesiones HITL (map[sessionID]SessionState + RWMutex)
debe expirar sesiones sin confirmar después de X minutos.
Si el proceso bos se reinicia, las sesiones HITL pendientes deben
recuperarse desde el SagaStore (pasos completados hasta el HITL).
¿Cómo implementar esto sin Redis (solo filesystem)?

PREGUNTA 7 — Guardia de dominio anti-escape del LLM:
El modelo puede intentar cruzar la frontera respondiendo sobre
temas de negocio aunque el system prompt lo prohíba.
¿Cómo implementar una guardia post-generación que detecte si la
respuesta del modelo menciona entidades de negocio y la intercepte
antes de mostrarla al operador? ¿Regex sobre output? ¿Clasificador
binario de embedding sobre la respuesta? ¿Segunda llamada al modelo?

PREGUNTA 8 — Anti-hallucination: garantizar que el agente usa herramientas:
La regla más crítica: sin datos reales, sin respuesta.
¿Cómo implementar en el parser del loop ReAct la detección de que
el modelo intentó saltar a "Final:" sin pasar por "Action:"?
Si detecta este patrón: re-prompt automático con "Debes usar al menos
una herramienta antes de responder. Intenta de nuevo."
¿Cuántas re-prompts máximo? ¿Qué hacer si el modelo persiste?
═══════════════════════════════════════════════════════════════════
```

---

## Referencias

| Fuente | Aporte |
|---|---|
| Westenfelder et al., NL2SH, NAACL 2025 | NL libre: >16% error en infraestructura productiva |
| MetaKube, ACM Web 2026 | SFT: 50.9% → 90.5% con Qwen3-8B mismo dominio |
| KubeIntellect, arXiv Sep 2025 | HITL + intent pre-processing validado en 200 consultas |
| Agent-S, arXiv 2503.15520, 2025 | Cosine similarity sobre catálogo — elimina alucinación |
| ToolLLM, Qin et al. 2024 | Dataset de trayectorias para SFT de tool-use |
| AI Safety Report 2026 | HITL obligatorio en infraestructura sensible |
| JSON-RPC-01 (fundamentos) | Protocolo, batch requests, notificaciones |
| JSON-RPC-06 (errores) | Taxonomía de errores y reintentos con backoff |
| JSON-RPC-09 (orquestación) | Motor de sagas, patrón Saga, compensación, contexto distribuido |
| 00_MASTER_INSTALL_SBOS.sh | Patrón Absorb/Execute/Release reutilizado en ICAP |
| 00_YAML_ENGINE_SBOS.sh | yaml_dispatch → base de catalog.go |
| 00_ARCHITECTURE_SBOS.yml | Modelo declarativo → action_catalog.yml |
| biaos-arquitectura.md | Gateway singleton Go, ReAct stdlib, migración sin downtime |
| biaos-proyecto-ia-robusta.md | ICAP Engine, 3 fases entrenamiento, evidencia industria |

---

*BOS-REPAIR-10 — SKULL · SBOS · Junio 2026*
*Versión 3.0 — integra Manual JSON-RPC §1-9 + biaos-arquitectura + biaos-proyecto-ia-robusta + patrón 00_fichas*
*Referencia: BOS-REPAIR-04 (sagas de consulta), BOS-REPAIR-05 §Fase 10 (F10.1..F10.24)*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
