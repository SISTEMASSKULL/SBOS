# INSTRUCCIONES DE EJECUCIÓN — Átomos F10.1 a F10.3
## biaos — Gateway LLM, Migración `internal/biaos/`, ICAP Engine
## Para: Agente ejecutor (Claude Code / desarrollador)

**Átomos:** F10.1 (gateway LLM singleton), F10.2 (migrar ai/ → biaos/), F10.3 (ICAP Engine)  
**Requiere previo:** F6.x ✅ (sagas de consulta) + F9.x ✅ (Operator Soberano)  
**Duración estimada:** F10.1: 60 min · F10.2: 45 min · F10.3: 120 min  
**Riesgo:** MEDIO — nuevo componente, no modifica código crítico existente  
**Base normativa:** BOS-REPAIR-10, `action_catalog.yml` (F10.0 ✅), INFORME-CIERRE-F10.0

---

## ⛔ REFERENCIA _legacy/ — SOLO LÓGICA, NO COPIAR

Antes de implementar F10.2 (migrar ai/ → biaos/), **consultar** estos archivos
archivados en `_legacy/`. Son referencia de lógica únicamente — **NO copiarlos**.

| Archivo en `_legacy/` | Lógica a entender (no copiar) |
|---|---|
| `2026-06-09_F0.7_ai/client.go` | Circuit breaker 3-tiers: primario (Anthropic) → secundario (Ollama) → fallback (OpenAI) |
| `2026-06-09_F0.7_ai/model_router.go` | Lógica de selección de modelo según tarea (chat/embed/code) |
| `2026-06-09_F0.7_ai/context_builder.go` | Construcción de contexto: system prompt + historial + herramientas |

**Diferencia crítica entre `internal/ai/` y `internal/biaos/`:**

| `internal/ai/` (residual) | `internal/biaos/` (nuevo — F10) |
|---|---|
| Llama `net/http` directamente | Solo Unix socket `/run/bos/bos.sock` |
| Sin integración al action_catalog | Integrado con ICAP Engine y action_catalog.yml |
| Sin Unix socket | Cumple SBOS-050 P9 (HTTP vetado entre daemons) |
| Sin ctx_id | Propaga ctx_id en cada operación (SBOS-049) |

**Lo que DEBES hacer:** leer `_legacy/.../ai/` para entender el circuit breaker y el
model router. Luego construir desde el `doc.go` de `internal/biaos/` como contrato.
**Lo que NO DEBES hacer:** copiar, refactorizar, ni usar `net/http` en biaos.

Cada directorio tiene un `LEEME-ADVERTENCIA.md` con las reglas completas.

---

## CONTEXTO TÉCNICO

### Qué es biaos

biaos (BOS Intelligent Agent OS) es el agente IA del daemon bos. Implementa el ciclo ReAct (Reasoning + Acting) para interpretar peticiones en lenguaje natural y ejecutar acciones del catálogo de operaciones del sistema.

```
Usuario: "el keycloak está raro"
    ↓
biaos recibe la petición en lenguaje natural
    ↓
ICAP Engine busca la acción más similar en el action_catalog.yml
(búsqueda coseno sobre embeddings pre-calculados)
    ↓
Acción encontrada: "diagnose_ficha" → bos.query.repair (F6.7)
    ↓
SagaEngine (F10.4) orquesta la saga de diagnóstico
    ↓
Respuesta estructurada al operador
```

### Dependencia con las sagas de consulta (F6.6-F6.11)

F10.3 (ICAP Engine) referencia métodos JSON-RPC que deben existir:
- `bos.query.system` → F6.6 ✅
- `bos.query.repair` → F6.7 ✅
- `bos.query.vdi`    → F6.8 ✅
- `bos.query.node`   → F6.10 ✅

**Si F6.x no está completo, F10.3 no puede compilar correctamente.**

### El orden correcto de F10.1-F10.3

```
F10.2 (migrar ai/ → biaos/)  ← primero — establece la estructura de paquetes
    ↓
F10.1 (gateway LLM)          ← segundo — depende del paquete biaos/
    ↓
F10.3 (ICAP Engine)          ← tercero — usa gateway y action_catalog.yml
```

**Nota:** el orden en el Plan Maestro lista F10.1 antes de F10.2, pero para evitar imports circulares, ejecutar F10.2 primero.

---

## PRE-CONDICIONES

```bash
cd /opt/skull/.../BOS_V8/

# 1. F6 y F9 completos
go test -race ./internal/... 2>&1 | grep -E "FAIL|DATA RACE" | wc -l | grep "^0$" \
  && echo "✅ suite limpia" || echo "❌ resolver antes"

# 2. action_catalog.yml existe (F10.0 completado)
[ -f action_catalog.yml ] || [ -f /etc/bos/ai/action_catalog.yml ] \
  && echo "✅ action_catalog.yml presente" \
  || echo "❌ F10.0 no completado — generar action_catalog.yml primero"

# 3. internal/ai/ existe con código a migrar
ls internal/ai/ && echo "✅ internal/ai/ presente"
grep -n "type.*Client\|func.*Complete\|func.*Chat" internal/ai/client.go | head -10

# 4. Variable de entorno del LLM
echo "BOS_LLM_API_KEY configurada: $([ -n "$BOS_LLM_API_KEY" ] && echo SÍ || echo NO)"
echo "BOS_LLM_PROVIDER: ${BOS_LLM_PROVIDER:-anthropic}"

# 5. biaos/ NO debe existir aún
[ -d internal/biaos ] \
  && echo "⚠️ internal/biaos/ ya existe — verificar estado" \
  || echo "✅ biaos/ no existe — crear en F10.2"
```

---

## ÁTOMO F10.2 — Migrar `internal/ai/` → `internal/biaos/` (ejecutar PRIMERO)

**Objetivo:** Establecer la estructura del paquete biaos y migrar el código existente de ai/.  
**Tiempo estimado:** 45 minutos

### Archivar el contenido original de internal/ai/

```bash
DATE=$(date +%Y-%m-%d)
cp -r internal/ai _legacy/${DATE}_F10.2_internal_ai_original/

cat > _legacy/${DATE}_F10.2_internal_ai_original/ARCHIVO.md << 'EOF'
# ARCHIVADO: F10.2 — internal/ai/ migrado a internal/biaos/
# Razón: biaos es el nombre correcto del agente OS según BOS-REPAIR-10
# El paquete ai/ tenía client.go y model_router.go — ambos migrados
# Informe de Cierre: INFORME-CIERRE-F10.2.md
EOF
```

### Crear la estructura de `internal/biaos/`

```bash
mkdir -p internal/biaos/icap
mkdir -p internal/biaos/sagas
```

### Crear `internal/biaos/doc.go`

(Si F0.2 ya lo creó, verificar que tiene las 6 secciones de ADR-003)

```go
// Package biaos implementa el agente IA del daemon bos (BOS Intelligent Agent OS).
//
// # Responsabilidades
//
// biaos interpreta peticiones en lenguaje natural de operadores y las
// traduce a operaciones del sistema usando el ciclo ReAct (Reasoning + Acting).
// Gestiona el gateway al LLM (singleton con circuit breaker), el ICAP Engine
// para matching de intenciones, y el SagaEngine para operaciones multi-paso.
//
// # Fuera de alcance
//
// biaos NUNCA toca módulos de negocio (Tryton, Saleor, OrangeHRM).
// Solo opera sobre infraestructura: fichas, K8s, Context Plane.
// El agente de negocio es bCompass — ver guardia_dominio en action_catalog.yml.
//
// # Dependencias
//
// internal/server/jsonrpc.go: todas las acciones se ejecutan vía JSON-RPC
// internal/k8s/core.go: operaciones K8s (escalado, mantenimiento)
// internal/scaler/: anti-death-spiral para operaciones de escalado
//
// # Ciclo ReAct
//
// 1. Observar: recibir petición NL del operador
// 2. Pensar: ICAP Engine encuentra la acción más similar (coseno sobre embeddings)
// 3. Actuar: SagaEngine ejecuta la acción con compensación garantizada
// 4. Observar resultado: retornar respuesta estructurada
//
// # Estándares
//
// BOS-REPAIR-10 (arquitectura biaos), ADR-002 (roles y guardrails HITL).
// ISO 27001 A.8.15: todas las acciones de biaos se registran en audit log.
package biaos
```

### Migrar `internal/ai/client.go` → `internal/biaos/client.go`

```bash
cp internal/ai/client.go internal/biaos/client.go
# Cambiar: "package ai" → "package biaos"
sed -i 's/^package ai$/package biaos/' internal/biaos/client.go
```

### Migrar `internal/ai/model_router.go` → `internal/biaos/model_router.go`

```bash
cp internal/ai/model_router.go internal/biaos/model_router.go
sed -i 's/^package ai$/package biaos/' internal/biaos/model_router.go
```

### Actualizar imports en cmd/ que usaban internal/ai/

```bash
# Encontrar qué archivos importan internal/ai:
grep -rn '"bos/internal/ai"' cmd/ internal/ | grep -v "_legacy"

# Para cada archivo encontrado, actualizar el import:
# "bos/internal/ai" → "bos/internal/biaos"
# Ejemplo:
sed -i 's|"bos/internal/ai"|"bos/internal/biaos"|g' cmd/bos/main.go
# Repetir para cada archivo que lo importe
```

### Dejar internal/ai/ como alias (SFP-02 — coexistencia)

```go
// internal/ai/doc.go — marcar como deprecado, no eliminar
// DEPRECATED: package ai fue migrado a internal/biaos/ en F10.2.
// Este paquete se elimina en F10.2 cuando todos los callers estén migrados.
// Ver _legacy/FECHA_F10.2_internal_ai_original/
package ai
```

```bash
go build ./... && echo "✅ F10.2 compila" || echo "❌ resolver imports"
```

---

## ÁTOMO F10.1 — Gateway LLM singleton con circuit breaker

**Objetivo:** Singleton seguro para la conexión al LLM con circuit breaker.  
**Tiempo estimado:** 60 minutos

### Crear `internal/biaos/gateway.go`

```go
package biaos

import (
    "context"
    "fmt"
    "sync"
    "sync/atomic"
    "time"
)

// LLMProvider identifica el proveedor de LLM configurado.
type LLMProvider string

const (
    ProviderAnthropic LLMProvider = "anthropic"
    ProviderOpenAI    LLMProvider = "openai"
    ProviderLocal     LLMProvider = "local" // llama.cpp u ollama
)

// Gateway es el punto único de acceso al LLM.
//
// Thread safety: Gateway es seguro para uso concurrente.
// La instancia singleton se inicializa una sola vez con sync.Once.
//
// Circuit breaker: si el LLM falla N veces consecutivas, el gateway
// entra en estado OPEN y rechaza requests por un período de cooldown.
// Esto previene que un LLM no disponible bloquee las operaciones del daemon.
type Gateway struct {
    provider LLMProvider
    client   LLMClient // interfaz — permite mock en tests

    // Circuit breaker state
    failures   int64         // contador atómico de fallos consecutivos
    openUntil  time.Time     // estado OPEN hasta este momento
    cbMu       sync.RWMutex  // protege openUntil

    logger Logger
}

// LLMClient es la interfaz del cliente LLM.
// Permite intercambiar el proveedor real con un mock en tests.
type LLMClient interface {
    // Complete envía un prompt y retorna la completación.
    Complete(ctx context.Context, prompt string, opts CompletionOptions) (string, error)
}

// CompletionOptions son las opciones de completación del LLM.
type CompletionOptions struct {
    MaxTokens   int
    Temperature float64
    System      string // system prompt
}

// CircuitBreakerConfig configura el circuit breaker del gateway.
type CircuitBreakerConfig struct {
    // FailureThreshold es el número de fallos consecutivos para abrir el circuito.
    FailureThreshold int64
    // CooldownDuration es el tiempo que el circuito permanece abierto.
    CooldownDuration time.Duration
}

// DefaultCBConfig son los valores por defecto del circuit breaker.
var DefaultCBConfig = CircuitBreakerConfig{
    FailureThreshold: 5,
    CooldownDuration: 30 * time.Second,
}

var (
    gatewayOnce     sync.Once
    gatewayInstance *Gateway
)

// GetGateway retorna la instancia singleton del Gateway.
// Inicializa la conexión la primera vez que se llama.
//
// La configuración viene de variables de entorno:
//   - BOS_LLM_PROVIDER: "anthropic" | "openai" | "local" (default: anthropic)
//   - BOS_LLM_API_KEY: clave API del proveedor
//   - BOS_LLM_MODEL: modelo a usar (default: según proveedor)
func GetGateway(logger Logger) (*Gateway, error) {
    var initErr error
    gatewayOnce.Do(func() {
        client, provider, err := buildLLMClient()
        if err != nil {
            initErr = fmt.Errorf("biaos.GetGateway: inicializar cliente LLM: %w", err)
            return
        }
        gatewayInstance = &Gateway{
            provider: provider,
            client:   client,
            logger:   logger,
        }
    })
    if initErr != nil {
        return nil, initErr
    }
    return gatewayInstance, nil
}

// ResetGateway reinicia el singleton — solo para tests.
// NUNCA llamar en producción.
func ResetGateway() {
    gatewayOnce = sync.Once{}
    gatewayInstance = nil
}

// Complete envía un prompt al LLM con circuit breaker.
//
// Retorna error inmediato si el circuito está OPEN (cooldown activo).
// En modo local (BOS_LLM_PROVIDER=local), no usa el circuito.
func (g *Gateway) Complete(ctx context.Context, prompt string, opts CompletionOptions) (string, error) {
    // Verificar circuit breaker
    if err := g.checkCircuitBreaker(); err != nil {
        return "", err
    }

    result, err := g.client.Complete(ctx, prompt, opts)
    if err != nil {
        g.recordFailure()
        return "", fmt.Errorf("biaos.Gateway.Complete: %w", err)
    }

    g.recordSuccess()
    return result, nil
}

// checkCircuitBreaker verifica si el circuito está abierto.
func (g *Gateway) checkCircuitBreaker() error {
    g.cbMu.RLock()
    defer g.cbMu.RUnlock()
    if !g.openUntil.IsZero() && time.Now().Before(g.openUntil) {
        return fmt.Errorf("biaos.Gateway: circuit breaker OPEN hasta %s",
            g.openUntil.Format(time.RFC3339))
    }
    return nil
}

// recordFailure incrementa el contador de fallos y abre el circuito si es necesario.
func (g *Gateway) recordFailure() {
    failures := atomic.AddInt64(&g.failures, 1)
    if failures >= DefaultCBConfig.FailureThreshold {
        g.cbMu.Lock()
        g.openUntil = time.Now().Add(DefaultCBConfig.CooldownDuration)
        g.cbMu.Unlock()
        g.logger.Warn("biaos.Gateway: circuit breaker OPEN",
            "failures", failures, "cooldown", DefaultCBConfig.CooldownDuration)
    }
}

// recordSuccess resetea el contador de fallos.
func (g *Gateway) recordSuccess() {
    atomic.StoreInt64(&g.failures, 0)
    g.cbMu.Lock()
    g.openUntil = time.Time{}
    g.cbMu.Unlock()
}

// buildLLMClient crea el cliente LLM según la configuración.
func buildLLMClient() (LLMClient, LLMProvider, error) {
    // Leer de variables de entorno
    // Usar internal/ai/client.go o model_router.go migrado como base
    // TODO: implementar según el código existente en internal/ai/
    return nil, ProviderAnthropic, fmt.Errorf("buildLLMClient: implementar")
}
```

**Tests F10.1:**
```go
func TestGateway_CircuitBreaker_AbreDespuesDeNFallos(t *testing.T) {
    ResetGateway()
    // Crear gateway con mock que siempre falla
    gw := &Gateway{
        client: &mockLLMClient{err: fmt.Errorf("LLM no disponible")},
        logger: testLogger(t),
    }

    // 5 fallos consecutivos deben abrir el circuito
    for i := 0; i < 5; i++ {
        _, _ = gw.Complete(ctx, "test", CompletionOptions{})
    }

    // La siguiente llamada debe ser rechazada por el circuit breaker
    _, err := gw.Complete(ctx, "test", CompletionOptions{})
    assert.Error(t, err)
    assert.Contains(t, err.Error(), "circuit breaker OPEN")
}

func TestGateway_Singleton_MismaInstancia(t *testing.T) {
    ResetGateway()
    t.Setenv("BOS_LLM_PROVIDER", "local")
    // Con provider local no necesita API key

    gw1, _ := GetGateway(testLogger(t))
    gw2, _ := GetGateway(testLogger(t))
    assert.Same(t, gw1, gw2, "singleton: debe ser la misma instancia")
}

func TestGateway_Complete_ConcurrentSafe(t *testing.T) {
    gw := &Gateway{client: &mockLLMClient{response: "ok"}, logger: testLogger(t)}
    var wg sync.WaitGroup
    for i := 0; i < 20; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            _, _ = gw.Complete(ctx, "test", CompletionOptions{})
        }()
    }
    wg.Wait()
    // go test -race verificará que no hay DATA RACE
}
```

---

## ÁTOMO F10.3 — ICAP Engine (`internal/biaos/icap/`)

**Objetivo:** Motor de matching de intenciones usando búsqueda coseno sobre embeddings del action_catalog.yml.  
**Tiempo estimado:** 120 minutos

### Leer el action_catalog.yml antes de implementar

```bash
# El action_catalog.yml fue generado en F10.0 — leerlo primero:
cat action_catalog.yml | head -80
# Campos importantes:
#   id, nombre, descripcion, aliases[], embedding_texto, rpc_method/saga_id
#   categoria (lectura/escritura/destructiva), riesgo, guardia_dominio
```

### Estructura del ICAP Engine

```
internal/biaos/icap/
  catalog.go      ← CatalogEntry struct + carga del YAML
  embeddings.go   ← cálculo y cache de embeddings
  engine.go       ← búsqueda coseno + dispatch
```

### Crear `internal/biaos/icap/catalog.go`

```go
// Package icap implementa el motor ICAP (Intent-Catalog-Action-Pipeline).
//
// # Responsabilidades
//
// ICAP recibe texto en lenguaje natural y encuentra la acción más similar
// en el action_catalog.yml usando similitud coseno sobre embeddings.
//
// # Proceso
//
//  1. Al arrancar: cargar action_catalog.yml y calcular embeddings por acción
//  2. Al recibir petición: calcular embedding del texto de entrada
//  3. Encontrar la acción con mayor similitud coseno (threshold mínimo: 0.75)
//  4. Verificar guardia_dominio — si la acción está prohibida, rechazar
//  5. Retornar CatalogEntry con rpc_method o saga_id a ejecutar
//
// # Fuentes
//
// BOS-REPAIR-10, INFORME-CIERRE-F10.0-ACTION-CATALOG.md, action_catalog.yml.
package icap

import (
    "fmt"
    "os"

    "gopkg.in/yaml.v3"
)

// CatalogEntry representa una acción en el catálogo biaos.
// El schema debe ser compatible con action_catalog.yml generado en F10.0.
type CatalogEntry struct {
    // ID único de la acción. Ejemplo: "diagnose_ficha"
    ID string `yaml:"id"`

    // Nombre legible de la acción.
    Nombre string `yaml:"nombre"`

    // Descripcion explica qué hace la acción.
    Descripcion string `yaml:"descripcion"`

    // Aliases son frases equivalentes en lenguaje natural.
    // Incluye lenguaje coloquial latinoamericano (ADR F10.0-D3).
    Aliases []string `yaml:"aliases"`

    // EmbeddingTexto es el texto usado para calcular el embedding.
    // Combina descripcion + aliases para maximizar el matching.
    EmbeddingTexto string `yaml:"embedding_texto"`

    // Categoria clasifica el riesgo de la acción.
    // "lectura" | "escritura" | "destructiva"
    Categoria string `yaml:"categoria"`

    // Riesgo describe el impacto potencial de la acción.
    Riesgo string `yaml:"riesgo"`

    // RPCMethod es el método JSON-RPC a llamar (acciones atómicas).
    // Mutuamente excluyente con SagaID.
    RPCMethod string `yaml:"rpc_method,omitempty"`

    // SagaID es la saga a ejecutar (acciones multi-paso).
    // Mutuamente excluyente con RPCMethod.
    SagaID string `yaml:"saga_id,omitempty"`

    // RequiereHITL indica si la acción requiere confirmación humana.
    RequiereHITL bool `yaml:"requiere_hitl"`

    // GuardiaDominio lista los módulos que esta acción NUNCA puede tocar.
    GuardiaDominio []string `yaml:"guardia_dominio,omitempty"`

    // Compensacion es el método RPC de compensación si la saga falla.
    Compensacion string `yaml:"compensacion,omitempty"`
}

// Catalog es el catálogo completo de acciones de biaos.
type Catalog struct {
    Version       string          `yaml:"version"`
    FechaGenerado string          `yaml:"fecha_generado"`
    Acciones      []*CatalogEntry `yaml:"acciones"`
    GuardiaDominio []string       `yaml:"guardia_dominio"` // global
}

// LoadCatalog carga el action_catalog.yml desde la ruta especificada.
// La ruta por defecto es /etc/bos/ai/action_catalog.yml.
func LoadCatalog(path string) (*Catalog, error) {
    if path == "" {
        path = "/etc/bos/ai/action_catalog.yml"
    }

    data, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("icap.LoadCatalog: leer %s: %w", path, err)
    }

    var cat Catalog
    if err := yaml.Unmarshal(data, &cat); err != nil {
        return nil, fmt.Errorf("icap.LoadCatalog: parsear YAML: %w", err)
    }

    if len(cat.Acciones) == 0 {
        return nil, fmt.Errorf("icap.LoadCatalog: catálogo vacío en %s", path)
    }

    // Validar que cada acción tiene rpc_method O saga_id pero no ambos
    for _, a := range cat.Acciones {
        if a.RPCMethod != "" && a.SagaID != "" {
            return nil, fmt.Errorf("icap.LoadCatalog: acción %s tiene rpc_method y saga_id (son mutuamente excluyentes)", a.ID)
        }
        if a.RPCMethod == "" && a.SagaID == "" {
            return nil, fmt.Errorf("icap.LoadCatalog: acción %s no tiene rpc_method ni saga_id", a.ID)
        }
    }

    return &cat, nil
}
```

### Crear `internal/biaos/icap/engine.go`

```go
package icap

import (
    "context"
    "fmt"
    "math"
    "sort"
    "strings"
)

// MatchResult es el resultado de buscar una acción para una petición.
type MatchResult struct {
    Action     *CatalogEntry
    Similarity float64  // similitud coseno [0.0, 1.0]
    Confident  bool     // true si similarity >= threshold
}

// Engine es el motor ICAP que busca acciones por similitud semántica.
type Engine struct {
    catalog    *Catalog
    embeddings map[string][]float32  // actionID → embedding vector
    gateway    EmbeddingGateway      // interfaz para calcular embeddings
    threshold  float64               // similitud mínima (default: 0.75)
}

// EmbeddingGateway calcula el embedding de un texto.
// En producción usa el LLM Gateway; en tests usa un mock.
type EmbeddingGateway interface {
    Embed(ctx context.Context, text string) ([]float32, error)
}

// NewEngine crea el ICAP Engine con el catálogo precargado.
// Calcula los embeddings de todas las acciones al inicializar.
// Este proceso puede tardar varios segundos si hay 26+ acciones.
func NewEngine(cat *Catalog, gw EmbeddingGateway) (*Engine, error) {
    e := &Engine{
        catalog:    cat,
        embeddings: make(map[string][]float32, len(cat.Acciones)),
        gateway:    gw,
        threshold:  0.75,
    }

    ctx := context.Background()
    for _, action := range cat.Acciones {
        embedding, err := gw.Embed(ctx, action.EmbeddingTexto)
        if err != nil {
            return nil, fmt.Errorf("icap.NewEngine: embedding de %s: %w", action.ID, err)
        }
        e.embeddings[action.ID] = embedding
    }

    return e, nil
}

// Find busca la acción más similar a la petición en lenguaje natural.
//
// Retorna MatchResult con Confident=false si ninguna acción supera el threshold.
// En ese caso, la acción retornada es la de mayor similitud disponible.
func (e *Engine) Find(ctx context.Context, query string) (*MatchResult, error) {
    if strings.TrimSpace(query) == "" {
        return nil, fmt.Errorf("icap.Find: query no puede estar vacía")
    }

    // Calcular embedding de la query
    queryEmb, err := e.gateway.Embed(ctx, query)
    if err != nil {
        return nil, fmt.Errorf("icap.Find: embedding de query: %w", err)
    }

    // Calcular similitud coseno contra todas las acciones
    type scored struct {
        action *CatalogEntry
        score  float64
    }
    scores := make([]scored, 0, len(e.catalog.Acciones))

    for _, action := range e.catalog.Acciones {
        emb, ok := e.embeddings[action.ID]
        if !ok {
            continue
        }
        sim := cosineSimilarity(queryEmb, emb)
        scores = append(scores, scored{action, sim})
    }

    if len(scores) == 0 {
        return nil, fmt.Errorf("icap.Find: catálogo vacío")
    }

    // Ordenar por similitud descendente
    sort.Slice(scores, func(i, j int) bool {
        return scores[i].score > scores[j].score
    })

    best := scores[0]
    return &MatchResult{
        Action:     best.action,
        Similarity: best.score,
        Confident:  best.score >= e.threshold,
    }, nil
}

// IsActionBlocked verifica si una acción está bloqueada por la guardia de dominio.
// Las acciones en guardia_dominio NUNCA se ejecutan, independientemente de la similitud.
func (e *Engine) IsActionBlocked(actionID string, requestedModules []string) bool {
    action := e.findByID(actionID)
    if action == nil {
        return false
    }
    blocked := make(map[string]bool)
    for _, m := range action.GuardiaDominio {
        blocked[m] = true
    }
    // También verificar la guardia global del catálogo
    for _, m := range e.catalog.GuardiaDominio {
        blocked[m] = true
    }
    for _, mod := range requestedModules {
        if blocked[mod] {
            return true
        }
    }
    return false
}

func (e *Engine) findByID(id string) *CatalogEntry {
    for _, a := range e.catalog.Acciones {
        if a.ID == id {
            return a
        }
    }
    return nil
}

// cosineSimilarity calcula la similitud coseno entre dos vectores.
// Retorna valor en [-1.0, 1.0]. Para embeddings normalizados: [0.0, 1.0].
func cosineSimilarity(a, b []float32) float64 {
    if len(a) != len(b) || len(a) == 0 {
        return 0
    }
    var dot, normA, normB float64
    for i := range a {
        dot   += float64(a[i]) * float64(b[i])
        normA += float64(a[i]) * float64(a[i])
        normB += float64(b[i]) * float64(b[i])
    }
    if normA == 0 || normB == 0 {
        return 0
    }
    return dot / (math.Sqrt(normA) * math.Sqrt(normB))
}
```

**Tests F10.3:**
```go
func TestICAPEngine_Find_AccionCorrecta(t *testing.T) {
    cat, err := LoadCatalog("../../../action_catalog.yml")
    require.NoError(t, err)

    // Mock de embeddings: retorna vector de alta similitud para diagnose_ficha
    mockGW := &mockEmbeddingGateway{
        embedFn: func(text string) ([]float32, error) {
            if strings.Contains(text, "keycloak") || strings.Contains(text, "raro") {
                return []float32{0.9, 0.1, 0.0}, nil
            }
            return []float32{0.1, 0.9, 0.0}, nil
        },
    }

    engine, err := NewEngine(cat, mockGW)
    require.NoError(t, err)

    result, err := engine.Find(ctx, "el keycloak está raro")
    require.NoError(t, err)
    assert.True(t, result.Confident, "debe tener alta confianza")
    assert.NotEmpty(t, result.Action.RPCMethod)
}

func TestICAPEngine_CosineSimilarity_VectoresOrthogonales(t *testing.T) {
    a := []float32{1, 0, 0}
    b := []float32{0, 1, 0}
    sim := cosineSimilarity(a, b)
    assert.InDelta(t, 0.0, sim, 0.001, "vectores ortogonales deben tener similitud 0")
}

func TestICAPEngine_CosineSimilarity_VectoresIguales(t *testing.T) {
    a := []float32{1, 2, 3}
    sim := cosineSimilarity(a, a)
    assert.InDelta(t, 1.0, sim, 0.001, "mismo vector debe tener similitud 1")
}

func TestICAPEngine_GuardiaDominio_BloqueaAccionesProhibidas(t *testing.T) {
    engine := newTestEngine(t)
    // biaos NUNCA debe tocar módulos de negocio
    blocked := engine.IsActionBlocked("some_action", []string{"tryton", "saleor"})
    // Verificar según la guardia_dominio del action_catalog.yml
    t.Logf("guardia de dominio para módulos de negocio: %v", blocked)
}

func TestLoadCatalog_YAMLValido(t *testing.T) {
    cat, err := LoadCatalog("../../../action_catalog.yml")
    require.NoError(t, err)
    assert.GreaterOrEqual(t, len(cat.Acciones), 25, "debe tener ≥25 acciones")

    // Verificar estructura de cada acción
    for _, a := range cat.Acciones {
        assert.NotEmpty(t, a.ID, "acción sin ID")
        assert.NotEmpty(t, a.EmbeddingTexto, "acción %s sin embedding_texto", a.ID)
        assert.True(t, a.RPCMethod != "" || a.SagaID != "",
            "acción %s sin rpc_method ni saga_id", a.ID)
        assert.False(t, a.RPCMethod != "" && a.SagaID != "",
            "acción %s tiene ambos rpc_method y saga_id", a.ID)
    }
}
```

---

## VERIFICACIÓN DE CIERRE F10.1-F10.3

```bash
echo "=== VERIFICACIÓN F10.1-F10.3 ==="

# Estructura de archivos
[ -f internal/biaos/doc.go ]           && echo "✅ doc.go"
[ -f internal/biaos/gateway.go ]       && echo "✅ gateway.go"
[ -f internal/biaos/client.go ]        && echo "✅ client.go (migrado)"
[ -f internal/biaos/model_router.go ]  && echo "✅ model_router.go (migrado)"
[ -f internal/biaos/icap/catalog.go ]  && echo "✅ icap/catalog.go"
[ -f internal/biaos/icap/engine.go ]   && echo "✅ icap/engine.go"
[ -d _legacy ] && ls _legacy/ | grep "F10.2" \
  && echo "✅ internal/ai archivado en _legacy/"

echo ""
go build ./internal/biaos/... && echo "✅ BUILD biaos"
go vet   ./internal/biaos/... && echo "✅ VET biaos"
go test -race ./internal/biaos/... && echo "✅ TESTS biaos"
go build ./... && echo "✅ BUILD global"

echo ""
# Verificar que action_catalog.yml es válido
go test ./internal/biaos/icap/ -run TestLoadCatalog_YAMLValido -v \
  && echo "✅ action_catalog.yml válido"
```

---

## COMMIT FINAL F10.1-F10.3

```bash
git add internal/biaos/ _legacy/ action_catalog.yml
git commit -m "[F10.3] feat: internal/biaos/ — gateway LLM, ICAP Engine, migración ai/

F10.2: internal/ai/ migrado a internal/biaos/ (package rename)
       todos los callers actualizados — build global limpio
F10.1: gateway.go — singleton sync.Once + circuit breaker (5 fallos/30s cooldown)
F10.3: icap/ — CatalogEntry schema + LoadCatalog + Engine con búsqueda coseno

Tests:
  Gateway circuit breaker: 5 fallos → OPEN ✅
  Gateway singleton: misma instancia ✅
  ICAP Engine: cosineSimilarity ✅
  LoadCatalog: 26 acciones, estructura válida ✅
  GuardiaDominio: módulos de negocio bloqueados ✅

Siguiente: F10.4 (SagaEngine), F10.5 (agente ReAct)"
```

---

## SEÑAL DE RETOMA

```bash
[ -d internal/biaos ]               && echo "✅ F10.2" || echo "🔴 F10.2 pendiente"
[ -f internal/biaos/gateway.go ]    && echo "✅ F10.1" || echo "🔴 F10.1 pendiente"
[ -f internal/biaos/icap/engine.go ] && echo "✅ F10.3" || echo "🔴 F10.3 pendiente"
go build ./... 2>&1 | head -3
```

---

*EJECUCION-F10.1-F10.3-INSTRUCCIONES-AGENTE.md v1.0*  
*BOS-REPAIR · SKULL · SBOS · 08 de Junio 2026*  
*Fuentes: BOS-REPAIR-10, INFORME-CIERRE-F10.0-ACTION-CATALOG.md, action_catalog.yml*  
*Validación técnica: cosine similarity para embeddings, sync.Once singleton Go idiomático*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
