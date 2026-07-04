package biaos

// gateway.go — F10.1: Gateway LLM singleton del bos (BOS-REPAIR-10 §5.2).
//
// UN solo punto de acceso a los backends LLM para todo el daemon
// (sync.Once): los handlers bos.ai.*, el agente ReAct y el ICAP comparten
// el mismo Gateway. Circuit breaker propio: tras MaxFallos consecutivos el
// circuito se abre durante Cooldown — las llamadas fallan rápido sin
// castigar al backend caído (el Router ya rota entre backends; el breaker
// protege el conjunto).

import (
	"errors"
	"fmt"
	"sync"
	"time"

	"bos/internal/biaos/audit"
	"bos/internal/biaos/icap"
)

// ErrCircuitoAbierto: el gateway está en cooldown tras fallos consecutivos.
var ErrCircuitoAbierto = errors.New("biaos: circuito abierto — backends LLM en cooldown")

// ErrSinBackend: ningún backend LLM configurado (sin API keys ni Ollama).
var ErrSinBackend = errors.New("biaos: sin backend LLM disponible — configurar BOS_AI_* o Ollama local")

// Gateway es el singleton de acceso LLM.
//
// Thread safety: client es inmutable tras New; el breaker usa mutex propio.
type Gateway struct {
	client  *Client
	agente  *Agente
	auditor *audit.Logger

	mu             sync.Mutex
	fallosSeguidos int
	abiertoHasta   time.Time
}

// breaker: parámetros del circuito (variables para tests).
var (
	breakerMaxFallos = 3
	breakerCooldown  = 60 * time.Second
)

var (
	gwOnce sync.Once
	gwInst *Gateway
	gwErr  error
)

// GetGateway retorna el Gateway singleton, construyéndolo la primera vez
// (sync.Once — F10.1). El error de construcción se memoriza: si no hay
// backends configurados todas las llamadas lo reportan consistentemente.
func GetGateway() (*Gateway, error) {
	gwOnce.Do(func() {
		client, err := NewClient()
		if err != nil {
			gwErr = fmt.Errorf("%w: %v", ErrSinBackend, err)
			return
		}
		gwInst = &Gateway{client: client}
	})
	return gwInst, gwErr
}

// newGatewayParaTest construye un Gateway aislado (sin tocar el singleton).
func newGatewayParaTest(c *Client) *Gateway { return &Gateway{client: c} }

// Config ensambla las dependencias del agente biaos (BOS-REPAIR-10 §5.2).
type Config struct {
	CatalogPath  string      // /etc/bos/ai/action_catalog.yml
	AuditLogPath string      // /var/log/bos/ai-audit.jsonl
	OllamaURL    string      // endpoint de embeddings (vacío → fallback términos)
	OllamaModel  string      // modelo de embeddings
	RBAC         RBACPort    // proveedor RBAC del server (puede ser nil)
	Exec         RPCExecutor // dispatcher RPC del server — herramientas del agente
}

// Agente devuelve el agente ReAct ensamblado (nil si New no lo construyó).
func (g *Gateway) Agente() *Agente { return g.agente }

// New ensambla el agente biaos completo: catálogo ICAP + sesiones HITL +
// auditor + ejecutor RPC. El LLM (client) es opcional — el ICAP funciona
// por términos sin él; biaos no inventa comandos, así que un LLM caído
// degrada la redacción, no la seguridad.
func New(cfg Config) (*Gateway, error) {
	embed := icap.OllamaEmbed(cfg.OllamaURL, cfg.OllamaModel)
	cat, err := icap.CargarCatalogo(cfg.CatalogPath, embed)
	if err != nil {
		return nil, fmt.Errorf("biaos.New: catálogo: %w", err)
	}
	var auditor *audit.Logger
	if cfg.AuditLogPath != "" {
		if l, err := audit.NewLogger(cfg.AuditLogPath); err == nil {
			auditor = l
		}
	}
	g := &Gateway{}
	if client, err := NewClient(); err == nil {
		g.client = client
	}
	g.agente = NewAgente(cat, cfg.Exec, cfg.RBAC, newSesionStore(), auditor)
	g.auditor = auditor
	return g, nil
}

// Close libera el auditor (drena el JSONL).
func (g *Gateway) Close() {
	if g.auditor != nil {
		g.auditor.Close()
	}
}

// Ask envía el prompt al LLM con contexto operativo, aplicando el breaker.
func (g *Gateway) Ask(prompt string, ctx *AIContext, modelOverride string) (string, error) {
	if err := g.permitir(); err != nil {
		return "", err
	}
	resp, err := g.client.Ask(prompt, ctx, modelOverride)
	g.registrar(err)
	return resp, err
}

// Backend reporta el backend activo (para model_used en las respuestas).
func (g *Gateway) Backend() string { return g.client.ActiveBackend() }

// permitir verifica el estado del circuito.
func (g *Gateway) permitir() error {
	g.mu.Lock()
	defer g.mu.Unlock()
	if time.Now().Before(g.abiertoHasta) {
		return fmt.Errorf("%w (reintentar en %s)", ErrCircuitoAbierto,
			time.Until(g.abiertoHasta).Round(time.Second))
	}
	return nil
}

// registrar actualiza el breaker con el resultado de la llamada.
func (g *Gateway) registrar(err error) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if err == nil {
		g.fallosSeguidos = 0
		return
	}
	g.fallosSeguidos++
	if g.fallosSeguidos >= breakerMaxFallos {
		g.abiertoHasta = time.Now().Add(breakerCooldown)
		g.fallosSeguidos = 0
	}
}
