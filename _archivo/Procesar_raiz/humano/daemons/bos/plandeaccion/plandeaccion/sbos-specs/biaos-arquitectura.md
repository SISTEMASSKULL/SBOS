# biaos — Arquitectura, Implementación e Integración en el daemon bos

> **Restricciones respetadas:** Go 1.25 stdlib, sin frameworks de agentes externos, Ollama offline, configuración única vía `bosctl set`, HITL obligatorio, audit ISO 27001 A.8.15, todo acceso IA pasa por biaos.

---

## PARTE 1 — Implementación como componente dentro del daemon bos

### 1.1 Estructura de paquete y arranque como goroutine

El patrón correcto es el **componente autónomo con contexto de ciclo de vida**. biaos no es un servidor independiente — es un subsistema que corre en el mismo proceso que bos y expone una interfaz interna limpia.

#### Estructura de directorios

```
internal/
  biaos/
    gateway.go       ← Gateway singleton + interfaz pública hacia el resto del daemon
    router.go        ← migración de internal/ai/model_router.go
    client.go        ← migración de internal/ai/client.go
    agent.go         ← loop ReAct OS-only
    tools.go         ← wrappers para llamar JSON-RPC del mismo proceso (sin red)
    session.go       ← estado HITL entre iteraciones del loop ReAct
    audit.go         ← ISO 27001 A.8.15: log antes de cada herramienta OS
```

#### gateway.go — Singleton thread-safe con sync.Once

```go
package biaos

import (
    "context"
    "fmt"
    "sync"
)

// Gateway es el punto de acceso único a IA en todo el proceso bos.
// Ningún componente instancia modelos directamente — todos pasan por aquí.
type Gateway struct {
    router *ModelRouter
    agent  *ReActAgent
    mu     sync.RWMutex
}

var (
    instance *Gateway
    once     sync.Once
)

// New inicializa el singleton. Llamado UNA sola vez por runNormal().
func New(cfg Config) (*Gateway, error) {
    var initErr error
    once.Do(func() {
        router, err := newModelRouter(cfg)
        if err != nil {
            initErr = fmt.Errorf("biaos: router init: %w", err)
            return
        }
        instance = &Gateway{
            router: router,
            agent:  newReActAgent(router),
        }
    })
    if initErr != nil {
        return nil, initErr
    }
    return instance, nil
}

// Instance devuelve el singleton ya inicializado.
// Panics si se llama antes de New() — comportamiento correcto: fallo rápido.
func Instance() *Gateway {
    if instance == nil {
        panic("biaos: Instance() called before New()")
    }
    return instance
}

// Ask es el método que usan todos los callers (bosctl, bCompass via RPC, etc.)
// caller identifica quién llama — se registra en audit log.
func (g *Gateway) Ask(ctx context.Context, req AskRequest) (*AskResponse, error) {
    return g.router.ask(ctx, req)
}

// RunAgent arranca el loop ReAct OS-only para una consulta operacional.
// Devuelve un canal de eventos para streaming al cliente.
func (g *Gateway) RunAgent(ctx context.Context, req AgentRequest) (<-chan AgentEvent, error) {
    return g.agent.run(ctx, req)
}
```

#### Arranque en cmd/bos/main.go — sin bloquear el event loop

```go
func runNormal(ctx context.Context, cfg *config.Config) error {
    // 1. Inicializar biaos ANTES de registrar métodos JSON-RPC que lo usan
    biaosGW, err := biaos.New(biaos.Config{
        DeepSeekAPIKey:  cfg.AI.DeepSeekAPIKey,
        AnthropicAPIKey: cfg.AI.AnthropicAPIKey,
        LocalEndpoint:   cfg.AI.LocalEndpoint,
        LocalModel:      cfg.AI.LocalModel,
    })
    if err != nil {
        return fmt.Errorf("biaos init: %w", err)
    }

    // 2. Arrancar el subsistema en background — no bloquea
    // biaos no tiene goroutines propias permanentes en este diseño;
    // cada llamada Ask() o RunAgent() genera goroutines por-request.
    // El contexto ctx propagado garantiza shutdown limpio.

    // 3. Registrar método JSON-RPC bos.ai.ask
    server.Register("bos.ai.ask", func(ctx context.Context, params json.RawMessage) (any, error) {
        var req biaos.AskRequest
        if err := json.Unmarshal(params, &req); err != nil {
            return nil, err
        }
        return biaosGW.Ask(ctx, req)
    })

    // ... resto de métodos JSON-RPC existentes ...
    return eventLoop(ctx, cfg)
}
```

#### Shutdown limpio

biaos no mantiene goroutines permanentes propias. Cuando `ctx` se cancela (señal SIGTERM → `shutdown()`), las goroutines en vuelo en `router.ask()` u `agent.run()` reciben la cancelación vía `context.Context` y terminan limpiamente. No se necesita lógica de shutdown adicional en biaos.

---

### 1.2 Gateway IA centralizado

#### Por qué centralizar (mismo principio que Kong o Vault)

- Una sola configuración de API keys — `bosctl set apikey` escribe en Vault, biaos lee en startup
- Un solo circuit breaker — si DeepSeek cae, todos los callers hacen failover automático
- Un solo audit log — cada llamada IA queda registrada con `caller` identificado
- Zero dispersión — ningún componente puede "colarse" con su propia configuración

#### AskRequest / AskResponse — contrato interno

```go
// AskRequest es el contrato que todos los callers usan.
type AskRequest struct {
    Prompt   string `json:"prompt"`
    System   string `json:"system,omitempty"`
    Caller   string `json:"caller"` // "bosctl", "bcompass", "bsearch", etc.
    MaxTok   int    `json:"max_tokens,omitempty"`
}

type AskResponse struct {
    Text      string `json:"text"`
    ModelUsed string `json:"model_used"` // "deepseek", "claude", "ollama:qwen3:14b"
    Tier      int    `json:"tier"`
    LatencyMs int64  `json:"latency_ms"`
}
```

#### Garantía singleton — un solo ModelRouter en todo el proceso

`sync.Once` en la función `New()` garantiza esto. El compilador de Go y el runtime garantizan que `once.Do()` se ejecuta exactamente una vez incluso bajo concurrencia masiva. No se necesita ningún mutex adicional para la inicialización.

Para acceso concurrente al router después de inicializar: el router es inmutable después de `New()` (la configuración no cambia en runtime, solo se puede leer). Las goroutines de requests son independientes entre sí.

#### Exposición via JSON-RPC para bCompass (pod K8s separado)

**Opción correcta: JSON-RPC sobre el Unix socket existente `/run/bos/bos.sock`**

Razón: bCompass ya se comunica con bos vía este socket para otros métodos. Agregar `bos.ai.ask` es coherente con la arquitectura existente. No se abre ningún puerto nuevo, no se viola ADR-012.

```json
// Request de bCompass → bos.ai.ask
{
  "jsonrpc": "2.0",
  "method": "bos.ai.ask",
  "params": {
    "prompt": "Analiza el patrón de ventas del último trimestre...",
    "system": "Eres un analista de negocio...",
    "caller": "bcompass",
    "max_tokens": 2048
  },
  "id": 1
}

// Response
{
  "result": {
    "text": "El análisis indica...",
    "model_used": "deepseek",
    "tier": 1,
    "latency_ms": 342
  }
}
```

**bCompass no configura modelos — solo llama `bos.ai.ask` con su prompt de negocio.** La elección de tier, failover y audit son invisibles para bCompass.

---

### 1.3 El agente ReAct OS-only dentro de biaos

#### Loop ReAct implementado en Go puro — sin frameworks

El patrón ReAct (Reasoning + Acting) es estructuralmente simple: un loop `for` que alterna entre llamar al LLM y ejecutar herramientas. No requiere ninguna librería externa.

```go
// agent.go

package biaos

import (
    "context"
    "encoding/json"
    "fmt"
    "strings"
    "time"
)

const maxIterations = 10

// AgentRequest es la petición del operador al agente OS.
type AgentRequest struct {
    Query     string `json:"query"`    // "¿Por qué está degradado el namespace sbos-erp?"
    SessionID string `json:"session_id,omitempty"` // para continuidad HITL
    Caller    string `json:"caller"`
}

// AgentEvent es un evento del loop enviado al cliente via canal (streaming).
type AgentEvent struct {
    Type    string `json:"type"`    // "thought", "action", "observation", "hitl", "final"
    Content string `json:"content"`
    Tool    string `json:"tool,omitempty"`
    Args    any    `json:"args,omitempty"`
    Done    bool   `json:"done"`
    Error   string `json:"error,omitempty"`
}

type ReActAgent struct {
    router   *ModelRouter
    tools    *ToolRegistry
    sessions *SessionStore
}

func newReActAgent(r *ModelRouter) *ReActAgent {
    return &ReActAgent{
        router:   r,
        tools:    newToolRegistry(),
        sessions: newSessionStore(),
    }
}

// run arranca el loop ReAct y devuelve un canal de eventos para streaming.
// El cliente (bosctl, Core UI via WebSocket) lee del canal.
func (a *ReActAgent) run(ctx context.Context, req AgentRequest) (<-chan AgentEvent, error) {
    events := make(chan AgentEvent, 32) // buffer evita bloquear el loop si el cliente es lento

    go func() {
        defer close(events)
        a.loop(ctx, req, events)
    }()

    return events, nil
}

func (a *ReActAgent) loop(ctx context.Context, req AgentRequest, events chan<- AgentEvent) {
    history := a.sessions.get(req.SessionID) // para continuidad HITL
    history = append(history, Message{Role: "user", Content: req.Query})

    for i := 0; i < maxIterations; i++ {
        select {
        case <-ctx.Done():
            events <- AgentEvent{Type: "error", Content: "contexto cancelado", Done: true}
            return
        default:
        }

        // --- FASE THINK: llamar al LLM con el historial ---
        resp, err := a.router.ask(ctx, AskRequest{
            Prompt: buildReActPrompt(history),
            System: osAgentSystemPrompt,
            Caller: req.Caller,
        })
        if err != nil {
            events <- AgentEvent{Type: "error", Content: err.Error(), Done: true}
            return
        }

        thought, action, isFinal := parseReActOutput(resp.Text)

        // Emitir "pensando..." al cliente
        if thought != "" {
            events <- AgentEvent{Type: "thought", Content: thought}
        }

        if isFinal {
            events <- AgentEvent{Type: "final", Content: action, Done: true}
            a.sessions.save(req.SessionID, history)
            return
        }

        // --- FASE ACT: parsear la herramienta a ejecutar ---
        toolName, args, parseErr := parseToolCall(action)
        if parseErr != nil {
            events <- AgentEvent{Type: "error", Content: parseErr.Error(), Done: true}
            return
        }

        events <- AgentEvent{Type: "action", Tool: toolName, Args: args}

        // --- GATE HITL: toda acción OS requiere aprobación ---
        if a.tools.requiresHITL(toolName) {
            hitlReq := HITLRequest{
                SessionID: req.SessionID,
                Tool:      toolName,
                Args:      args,
            }
            events <- AgentEvent{Type: "hitl", Content: "Esperando aprobación del operador...",
                Tool: toolName, Args: args}

            approved := a.sessions.waitForApproval(ctx, hitlReq, 5*time.Minute)
            if !approved {
                events <- AgentEvent{Type: "observation",
                    Content: "Operador rechazó la acción. Reconsiderando..."}
                history = append(history, Message{Role: "assistant", Content: resp.Text})
                history = append(history, Message{Role: "user",
                    Content: "El operador rechazó la acción propuesta. Considera una alternativa."})
                continue
            }
        }

        // --- FASE OBSERVE: ejecutar herramienta y observar resultado ---
        auditBefore(req.Caller, toolName, args) // ISO 27001 A.8.15
        observation, toolErr := a.tools.execute(ctx, toolName, args)
        if toolErr != nil {
            observation = fmt.Sprintf("Error ejecutando %s: %v", toolName, toolErr)
        }

        events <- AgentEvent{Type: "observation", Content: observation}

        // Actualizar historial con el turno completo
        history = append(history, Message{Role: "assistant", Content: resp.Text})
        history = append(history, Message{Role: "user",
            Content: fmt.Sprintf("Observación: %s", observation)})
    }

    events <- AgentEvent{Type: "error",
        Content: fmt.Sprintf("Max iteraciones (%d) alcanzadas", maxIterations), Done: true}
}
```

#### Llamada directa a funciones Go — sin network round-trip

Las herramientas del agente OS llaman directamente a las funciones Go del mismo proceso, no via JSON-RPC de red:

```go
// tools.go

package biaos

import (
    "context"
    "encoding/json"

    "github.com/SISTEMASSKULL/sbos/internal/server" // módulo interno existente
)

// ToolRegistry registra las herramientas disponibles para el agente OS.
// Todas son funciones Go — ninguna hace network call interna.
type ToolRegistry struct {
    tools map[string]Tool
}

type Tool struct {
    Name        string
    Description string
    RequiresHITL bool // true = requiere aprobación del operador
    Fn          func(ctx context.Context, args json.RawMessage) (string, error)
}

func newToolRegistry() *ToolRegistry {
    r := &ToolRegistry{tools: make(map[string]Tool)}

    // Herramientas de solo lectura — no requieren HITL
    r.register(Tool{
        Name:        "query_system_status",
        Description: "Consulta el estado de todas las fichas instaladas",
        RequiresHITL: false,
        Fn: func(ctx context.Context, args json.RawMessage) (string, error) {
            // Llamada DIRECTA a la función Go, no via red
            return server.BosQuerySystem(ctx)
        },
    })

    r.register(Tool{
        Name:        "get_pod_logs",
        Description: "Obtiene los últimos N logs de un pod o ficha",
        RequiresHITL: false,
        Fn: func(ctx context.Context, args json.RawMessage) (string, error) {
            var p struct { Ficha string `json:"ficha"`; Lines int `json:"lines"` }
            json.Unmarshal(args, &p)
            return server.BosGetLogs(ctx, p.Ficha, p.Lines)
        },
    })

    r.register(Tool{
        Name:        "check_node_resources",
        Description: "CPU, RAM y disco del nodo",
        RequiresHITL: false,
        Fn: func(ctx context.Context, args json.RawMessage) (string, error) {
            return server.BosQueryNode(ctx)
        },
    })

    // Herramientas de escritura — REQUIEREN HITL siempre
    r.register(Tool{
        Name:        "repair_ficha",
        Description: "Ejecuta el ciclo repair de una ficha específica",
        RequiresHITL: true, // ← Operador debe aprobar
        Fn: func(ctx context.Context, args json.RawMessage) (string, error) {
            var p struct { Ficha string `json:"ficha"` }
            json.Unmarshal(args, &p)
            return server.BosFichaRepair(ctx, p.Ficha)
        },
    })

    r.register(Tool{
        Name:        "scale_deployment",
        Description: "Ajusta réplicas de un deployment",
        RequiresHITL: true,
        Fn: func(ctx context.Context, args json.RawMessage) (string, error) {
            var p struct { Name string `json:"name"`; Replicas int `json:"replicas"` }
            json.Unmarshal(args, &p)
            return server.BosFichaScale(ctx, p.Name, p.Replicas)
        },
    })

    return r
}
```

#### Gestión de estado HITL entre llamadas

El operador puede aprobar/rechazar desde un mensaje posterior (por ejemplo, via `bosctl ia approve <session_id>`):

```go
// session.go

package biaos

import (
    "context"
    "sync"
    "time"
)

type HITLRequest struct {
    SessionID string
    Tool      string
    Args      any
}

type SessionStore struct {
    mu       sync.RWMutex
    sessions map[string][]Message
    pending  map[string]chan bool // sessionID → canal de aprobación
}

func newSessionStore() *SessionStore {
    return &SessionStore{
        sessions: make(map[string][]Message),
        pending:  make(map[string]chan bool),
    }
}

// waitForApproval bloquea la goroutine del agente hasta que el operador
// aprueba/rechaza o se agota el timeout. No bloquea el event loop principal.
func (s *SessionStore) waitForApproval(ctx context.Context, req HITLRequest, timeout time.Duration) bool {
    ch := make(chan bool, 1)

    s.mu.Lock()
    s.pending[req.SessionID] = ch
    s.mu.Unlock()

    defer func() {
        s.mu.Lock()
        delete(s.pending, req.SessionID)
        s.mu.Unlock()
    }()

    select {
    case approved := <-ch:
        return approved
    case <-time.After(timeout):
        return false // timeout → rechazado por default
    case <-ctx.Done():
        return false
    }
}

// Approve es llamado desde el método JSON-RPC bos.ai.approve
// cuando el operador ejecuta `bosctl ia approve <session_id>`
func (s *SessionStore) Approve(sessionID string, approved bool) {
    s.mu.RLock()
    ch, ok := s.pending[sessionID]
    s.mu.RUnlock()

    if ok {
        ch <- approved
    }
}
```

#### Streaming del loop ReAct — el operador ve cada paso

En `bosctl`, la lectura del canal de eventos es un bucle simple:

```go
// bosctl/ia/run.go

events, err := biaosClient.RunAgent(ctx, biaos.AgentRequest{
    Query:  args[0],
    Caller: "bosctl",
})

for event := range events {
    switch event.Type {
    case "thought":
        fmt.Printf("🧠 Pensando: %s\n", event.Content)
    case "action":
        fmt.Printf("⚙️  Acción: %s(%v)\n", event.Tool, event.Args)
    case "hitl":
        fmt.Printf("⏸️  Esperando aprobación (session: %s)\n", sessionID)
        fmt.Printf("   Aprobar: bosctl ia approve %s\n", sessionID)
        fmt.Printf("   Rechazar: bosctl ia reject %s\n", sessionID)
    case "observation":
        fmt.Printf("👁️  Observación: %s\n", event.Content)
    case "final":
        fmt.Printf("✅ Respuesta final:\n%s\n", event.Content)
    case "error":
        fmt.Fprintf(os.Stderr, "❌ Error: %s\n", event.Content)
    }

    if event.Done {
        break
    }
}
```

---

## PARTE 2 — Entrenamiento y especialización del modelo

### 2.1 Qué significa "entrenar" para un sistema soberano con presupuesto limitado

En el contexto de SBOS, "entrenar" no significa re-entrenar el modelo base (eso requiere decenas de miles de dólares en GPUs y semanas de cómputo). Significa **especializar el comportamiento del modelo** hacia el dominio OS. Hay cuatro enfoques en orden de costo:

| Enfoque | Costo GPU | Tiempo | Mejora | Recomendación SBOS |
|---|---|---|---|---|
| System prompt engineering | $0 | Inmediato | Alta para tareas acotadas | **Hacer YA — Tier 3** |
| Few-shot prompting | $0 | Días | Media-alta | **Hacer YA — incluir en system prompt** |
| RAG (documentación SBOS) | Mínimo | Semanas | Alta para consultas factuales | **Hacer en Fase 2** |
| Fine-tuning LoRA/QLoRA | GPU + tiempo | Meses | Muy alta | **Hacer cuando haya 500+ ejemplos reales** |

**Orden correcto de inversión:**

1. System prompt OS-only + few-shot (semana 1) — máximo impacto, cero costo
2. RAG con corpus HUMAN-DOC (mes 1-2) — el modelo consulta documentación SBOS real
3. LoRA fine-tuning (mes 3+) — cuando hay suficientes ejemplos de operación real

### 2.2 Dataset de entrenamiento OS-específico — formato JSONL

Cada entrada captura un par (contexto operacional → acción correcta). El formato Alpaca-style funciona con la mayoría de pipelines de fine-tuning (Unsloth, axolotl, llama.cpp):

```json
// /var/log/bos/ai-training-dataset.jsonl

// Ejemplo 1: diagnóstico de CrashLoopBackOff
{"instruction": "El pod tryton-0 en namespace sbos-erp está en CrashLoopBackOff. Los logs muestran: 'FATAL: connection to server on socket \"/var/run/postgresql/.s.PGSQL.5432\" failed: No such file or directory'. ¿Cuál es la causa y qué herramienta ejecutarías primero?", "input": "", "output": "Thought: El pod de Tryton no puede conectar a PostgreSQL vía socket Unix. Esto indica que PostgreSQL no está corriendo o el socket no está montado correctamente. El CrashLoopBackOff sugiere que el pod reinicia repetidamente por este fallo de conexión.\nAction: query_system_status({})\nObservation esperada: Estado de postgresql en sbos-data.\n\nSi PostgreSQL está ALERTA o NO_INSTALADO, la causa raíz es que el servicio de datos está caído. La acción correcta es repair_ficha({\"ficha\": \"postgresql\"}) tras aprobación del operador, NO repair_ficha({\"ficha\": \"tryton\"})."}

// Ejemplo 2: alta de WAL lag
{"instruction": "bKernel reporta WAL lag de 847ms (SLO: <500ms). La DLQ tiene 3 eventos pendientes con regla OHRM-001. ¿Qué pasos seguirías?", "input": "", "output": "Thought: El lag supera el SLO de 500ms. Con 3 eventos en DLQ para OHRM-001 (empleados OrangeHRM → Tryton), hay un bottleneck en la sincronización de identidad. El lag puede ser causado por CPU saturado en el nodo o por un lock en PostgreSQL.\nAction: check_node_resources({})\nObservation: Evaluaré CPU y memoria del nodo dataserver.\n\nSi CPU > 80%: buscar proceso que consume. Si normal: revisar pg_stat_activity para locks. Los eventos DLQ se reintentan con: bosctl bkernel retry --rule=OHRM-001 (requiere HITL)."}

// Ejemplo 3: rechazo correcto de acción fuera de dominio
{"instruction": "El operador pregunta: '¿Puedes analizar las ventas del mes y decirme qué productos tienen margen negativo?'", "input": "", "output": "Final: Lo siento, estoy especializado exclusivamente en operaciones de infraestructura OS del SBOS (fichas, pods, nodos, daemons soberanos). El análisis de ventas y márgenes es responsabilidad de bCompass. Por favor dirígete a `bosctl compass ask` para consultas de negocio."}
```

**Acumulación automática de ejemplos reales:**

```go
// audit.go — captura automática de ejemplos de entrenamiento

func auditBefore(caller, tool string, args any) {
    entry := map[string]any{
        "ts":     time.Now().UTC(),
        "caller": caller,
        "tool":   tool,
        "args":   args,
        "type":   "pre_execution",
    }
    writeAuditLog(entry) // a /var/log/bos/ai-audit.jsonl
}

// Llamado después de que el operador aprueba/rechaza y conocemos el resultado
func auditAfter(sessionID, tool string, approved bool, observation string, operatorFeedback string) {
    entry := map[string]any{
        "ts":               time.Now().UTC(),
        "session_id":       sessionID,
        "tool":             tool,
        "approved":         approved,
        "observation":      observation,
        "operator_feedback": operatorFeedback, // si el operador escribió por qué rechazó
        "type":             "training_example",
    }
    writeAuditLog(entry) // /var/log/bos/ai-audit.jsonl
    // Los ejemplos con approved=true → positivos
    // Los ejemplos con approved=false + operatorFeedback → negativos valiosos
}
```

### 2.3 Especialización del modelo Ollama local — Modelfile

Sin fine-tuning, el 80% de la especialización viene del **Modelfile** con system prompt OS-only + parámetros deterministas:

```
# /etc/bos/ai/Modelfile.biaos

FROM qwen3:14b

# Temperature 0.1: máxima coherencia, mínima creatividad
# Para operaciones OS, queremos respuestas predecibles y correctas
PARAMETER temperature 0.1
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER repeat_penalty 1.1

# Contexto amplio para historial ReAct largo
PARAMETER num_ctx 8192

# Stop tokens — el agente parsea estos para saber cuándo terminó el turno
PARAMETER stop "Observation:"
PARAMETER stop "Human:"
PARAMETER stop "User:"

SYSTEM """Eres biaos, el agente de operaciones del SBOS (Sovereign Business Operating System).

DOMINIO ESTRICTO — SOLO puedes:
- Consultar estado de fichas, pods y nodos del sistema
- Analizar logs y métricas de infraestructura
- Diagnosticar problemas de daemons soberanos (bos, bkernel, bauth, biedata, bcompass, bsearch, bhnexus)
- Proponer acciones de reparación (que el operador debe aprobar)

PROHIBIDO ABSOLUTAMENTE — NUNCA:
- Analizar datos de negocio (ventas, facturas, clientes, empleados)
- Ejecutar código arbitrario fuera de las herramientas definidas
- Acceder a secretos o credenciales directamente
- Realizar acciones sobre infraestructura SIN aprobación del operador (HITL)

FORMATO DE RESPUESTA — usa SIEMPRE este formato:
Thought: [tu razonamiento sobre qué está pasando]
Action: nombre_herramienta({"param": "valor"})

O si tienes la respuesta final:
Thought: [razonamiento]
Final: [respuesta completa para el operador]

HERRAMIENTAS DISPONIBLES:
- query_system_status: estado de todas las fichas
- get_pod_logs: logs de un pod (args: ficha, lines)
- check_node_resources: CPU, RAM, disco del nodo
- repair_ficha: [HITL] ejecuta repair de una ficha (args: ficha)
- scale_deployment: [HITL] ajusta réplicas (args: name, replicas)

[HITL] significa que el operador debe aprobar antes de ejecutar.
"""
```

**Crear el modelo especializado en Ollama:**

```bash
ollama create biaos -f /etc/bos/ai/Modelfile.biaos
# → El modelo 'biaos' queda disponible en Ollama local
# → bosctl set aimodel local=biaos apunta al modelo especializado
```

#### Con LoRA — cuando hay suficientes ejemplos reales (Fase 3)

Una vez acumulados 500+ ejemplos en `/var/log/bos/ai-audit.jsonl`:

```
# Modelfile con LoRA adapter (post fine-tuning)
FROM qwen3:14b
ADAPTER /etc/bos/ai/adapters/biaos-v1.gguf    ← adapter entrenado con Unsloth

PARAMETER temperature 0.05    ← aún más determinista con adapter
PARAMETER num_ctx 8192
PARAMETER stop "Observation:"
```

**Tamaño mínimo suficiente para dominio OS-only en 8GB VRAM:**
- qwen3:4b-q4: ~3 GB VRAM — funciona en 8GB, respuestas aceptables
- qwen3:8b-q4: ~6 GB VRAM — **recomendado**, mejor comprensión de logs y errores
- qwen3:14b-q4: ~9 GB VRAM — no cabe en 8GB con sistema operativo, usar CPU-only

Para 8GB VRAM: **qwen3:8b-q4 es el punto óptimo**. Con LoRA adapter del dominio OS, compensa el tamaño menor.

### 2.4 Aprendizaje continuo — acumulación de ejemplos sin afectar rendimiento

El escritor de audit log es asíncrono — nunca bloquea la goroutine del agente:

```go
// audit.go

var auditQueue = make(chan map[string]any, 1024) // buffer grande

func init() {
    go func() {
        f, _ := os.OpenFile("/var/log/bos/ai-audit.jsonl",
            os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
        defer f.Close()
        enc := json.NewEncoder(f)
        for entry := range auditQueue {
            enc.Encode(entry) // escritura en background
        }
    }()
}

func writeAuditLog(entry map[string]any) {
    select {
    case auditQueue <- entry:
    default:
        // Si el buffer está lleno, drop silencioso — operación no se bloquea
        // Nunca sacrificamos latencia del agente por audit log
    }
}
```

**Política de retención y conversión a dataset:**

```bash
# Cron semanal — convierte audit log en ejemplos de entrenamiento JSONL
bosctl ai dataset build \
  --input /var/log/bos/ai-audit.jsonl \
  --output /var/lib/bos/ai/training/week-$(date +%V).jsonl \
  --filter "approved=true OR (approved=false AND operator_feedback!=''"
```

---

## PARTE 3 — Integración con el ecosistema SBOS

### 3.1 Canal de comunicación biaos ↔ bCompass (pod K8s)

**Opción correcta: JSON-RPC sobre el Unix socket existente `/run/bos/bos.sock`**

```
bCompass (pod sbos-apps) → hostPath mount /run/bos/ → Unix socket → bos daemon → biaos
```

bCompass ya monta este socket para otros métodos bos. Agregar `bos.ai.ask` no requiere cambios en la configuración de red ni en las NetworkPolicies.

**Configuración del hostPath en la ficha de bCompass:**

```yaml
# En manifest.yml de bCompass (ya existe, agregar volumen)
volumes:
  - name: bos-socket
    hostPath:
      path: /run/bos/
      type: Directory
volumeMounts:
  - name: bos-socket
    mountPath: /run/bos/
    readOnly: false  # necesita escribir requests
```

**Por qué NO las otras opciones:**

- HTTP ClusterIP: viola ADR-012 (comunicación HTTP entre daemons soberanos y pods)
- Socket dedicado `/run/bos/biaos.sock`: crea un segundo canal de control innecesario, complica el monitoreo y el RBAC de operaciones

### 3.2 Guardia de dominio en runtime — validación del system prompt del caller

El gateway debe verificar que bCompass no intente usar el agente OS para ejecutar herramientas de infraestructura:

```go
// gateway.go — validación de dominio

// domainGuard verifica que el system prompt del caller no cruce fronteras.
// Regla: si caller='bcompass', no puede usar el agente OS ni mencionar herramientas OS.
func (g *Gateway) validateRequest(req AskRequest) error {
    switch req.Caller {
    case "bcompass":
        // bCompass puede usar Ask() para LLM genérico de negocio
        // pero NO puede activar el agente OS ni sus herramientas
        if req.System != "" && containsOSKeywords(req.System) {
            return fmt.Errorf("biaos: bcompass no puede usar system prompts de dominio OS")
        }
        // bCompass usa solo Ask(), nunca RunAgent()
    case "bosctl":
        // bosctl puede usar tanto Ask() como RunAgent() — acceso total
    }
    return nil
}

var osKeywords = []string{
    "repair_ficha", "scale_deployment", "query_system_status",
    "kubectl", "systemctl", "bosctl", "ficha", "daemon soberano",
}

func containsOSKeywords(s string) bool {
    lower := strings.ToLower(s)
    for _, kw := range osKeywords {
        if strings.Contains(lower, kw) {
            return true
        }
    }
    return false
}
```

**Separación clara de uso por caller:**

| Caller | Puede usar | No puede usar |
|---|---|---|
| `bosctl` | `Ask()` + `RunAgent()` + todas las herramientas OS | — |
| `bcompass` | Solo `Ask()` con prompts de negocio | `RunAgent()`, herramientas OS |
| `bsearch` | Solo `Ask()` para Schema Discoverer | `RunAgent()`, herramientas OS |
| `bosctl-audit` | Solo `Ask()` read-only | Herramientas con `RequiresHITL: true` |

### 3.3 Migración de internal/ai/model_router.go a internal/biaos/ — sin downtime

El plan de 3 pasos garantiza que `cmd/bosctl/ask.go` nunca se rompe:

#### Paso 1: biaos como wrapper del model_router existente

```go
// internal/biaos/router.go — wrap del router existente sin modificarlo

package biaos

import (
    "context"
    oldai "github.com/SISTEMASSKULL/sbos/internal/ai" // alias del paquete viejo
)

type ModelRouter struct {
    legacy *oldai.ModelRouter // delegación al router existente
}

func newModelRouter(cfg Config) (*ModelRouter, error) {
    legacyRouter, err := oldai.NewModelRouter(oldai.Config{
        DeepSeekAPIKey:  cfg.DeepSeekAPIKey,
        AnthropicAPIKey: cfg.AnthropicAPIKey,
        LocalEndpoint:   cfg.LocalEndpoint,
        LocalModel:      cfg.LocalModel,
    })
    if err != nil {
        return nil, err
    }
    return &ModelRouter{legacy: legacyRouter}, nil
}

func (r *ModelRouter) ask(ctx context.Context, req AskRequest) (*AskResponse, error) {
    // Delegar al router legacy durante la transición
    resp, err := r.legacy.Ask(ctx, oldai.AskRequest{
        Prompt:  req.Prompt,
        System:  req.System,
        MaxToks: req.MaxTok,
    })
    if err != nil {
        return nil, err
    }
    return &AskResponse{
        Text:      resp.Text,
        ModelUsed: resp.ModelUsed,
        Tier:      resp.Tier,
        LatencyMs: resp.LatencyMs,
    }, nil
}
```

En este paso: `cmd/bosctl/ask.go` sigue usando `internal/ai` directamente. biaos funciona como gateway pero delega internamente. Zero cambios en el caller.

#### Paso 2: bosctl/ask.go llama bos.ai.ask via JSON-RPC

```go
// cmd/bosctl/ask.go — ANTES (importa internal/ai directamente)
import "github.com/SISTEMASSKULL/sbos/internal/ai"
router := ai.NewModelRouter(cfg)
resp, err := router.Ask(ctx, req)

// cmd/bosctl/ask.go — DESPUÉS (llama JSON-RPC, idéntico al resto de comandos bosctl)
resp, err := bosctlClient.Call(ctx, "bos.ai.ask", biaos.AskRequest{
    Prompt: prompt,
    Caller: "bosctl",
})
```

Este cambio es retrocompatible en comportamiento — el operador no nota diferencia. Lo único que cambia es el transporte interno.

#### Paso 3: eliminar internal/ai/ cuando todos migraron

```bash
# Verificar que nada importa internal/ai
grep -r "internal/ai" --include="*.go" .
# Si el resultado está vacío → safe to delete
rm -rf internal/ai/
```

---

## Resumen de decisiones arquitectónicas

| Decisión | Opción elegida | Razón |
|---|---|---|
| Singleton pattern | `sync.Once` en `biaos.New()` | Thread-safe, stdlib, sin dependencias |
| Goroutines permanentes en biaos | Ninguna — goroutines por-request | Simplicidad, shutdown vía context |
| Canal bCompass → biaos | Unix socket `/run/bos/bos.sock` (existente) | Coherencia arquitectural, no rompe ADR |
| Streaming del agente | Canal `chan AgentEvent` en Go | Sin SSE, sin WebSocket extra, stdlib |
| Estado HITL entre mensajes | `map[sessionID]chan bool` + `sync.RWMutex` | In-memory, simple, correcto |
| Especialización modelo | Modelfile + system prompt OS-only (ahora) + LoRA (fase 3) | Costo/beneficio progresivo |
| Fine-tuning pipeline | Unsloth QLoRA → safetensors → Ollama ADAPTER | Soportado por Ollama Modelfile oficialmente |
| Tamaño modelo para 8GB VRAM | qwen3:8b-q4 (~6GB) | Cabe con margen, dominio limitado OS |
| Audit log async | Canal Go buffereado + goroutine writer | Nunca bloquea el agente por I/O |
| Guardia de dominio | `validateRequest()` en gateway | Previene cross-domain en runtime |

---

## System prompt ReAct — texto completo para Modelfile

```
const osAgentSystemPrompt = `Eres biaos, el agente de operaciones OS del SBOS.

DOMINIO: exclusivamente infraestructura. Fichas, pods, nodos, daemons soberanos.
PROHIBIDO: datos de negocio, ventas, empleados, facturas, análisis financiero.

FORMATO OBLIGATORIO — elige UNO por turno:

Opción A (necesitas usar una herramienta):
Thought: [razonamiento]
Action: nombre_herramienta({"param": "valor"})

Opción B (tienes la respuesta final):
Thought: [razonamiento]
Final: [respuesta para el operador]

HERRAMIENTAS DISPONIBLES:
- query_system_status(): estado de todas las fichas instaladas
- get_pod_logs({"ficha": "nombre", "lines": 50}): logs recientes
- check_node_resources(): CPU, RAM, disco del nodo
- repair_ficha({"ficha": "nombre"}): [REQUIERE HITL] ejecuta repair
- scale_deployment({"name": "nombre", "replicas": N}): [REQUIERE HITL] ajusta réplicas

[REQUIERE HITL] = el operador debe aprobar antes de ejecutar. Propón, no ejecutes.

PRINCIPIOS:
1. Diagnóstica primero (query_system_status, get_pod_logs) antes de proponer acciones
2. Nunca propones repair sin evidencia en los logs que lo justifique
3. Si no sabes la causa, di claramente que necesitas más información
4. Si la pregunta es de negocio, responde que debes derivarla a bCompass`
```

---

*Versión: 1.0 | Fecha: Junio 2026 | Proyecto: SBOS biaos*
*Restricciones: Go 1.25 stdlib, sin frameworks externos, Ollama offline, HITL obligatorio, ISO 27001 A.8.15*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
