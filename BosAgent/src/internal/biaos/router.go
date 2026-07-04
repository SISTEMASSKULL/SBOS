// Package ai implementa D4 — router y cliente ligero de modelos IA.
// bCompass es el orquestador real de IA (Ollama local, rutas declarativas).
// Este paquete expone bosctl ia como puente ligero hacia modelos cloud
// (DeepSeek/Claude) vía la API Anthropic-compatible Messages, más un
// tier local configurable (Ollama nativo u OpenAI-compatible).
//
// Tiered architecture with automatic circuit breaker:
//
//	Tier 1: Cloud primary (DeepSeek V4) ──→ on error ──→ Tier 2
//	Tier 2: Cloud fallback (Claude Sonnet) ──→ on error ──→ Tier 3
//	Tier 3: Local (Ollama / vLLM / llama.cpp / LocalAI — configurable)
//
//	After cooldown (default 5 min), each tier attempts recovery.
//	The operator can force any tier via: bosctl ia --model=<model>
//
// Environment (cloud):
//
//	BOS_AI_PRIMARY_MODEL=deepseek-v4-pro
//	BOS_AI_FALLBACK_MODEL=claude-sonnet-4-20250514
//	DEEPSEEK_API_KEY                      Primary API key
//	ANTHROPIC_API_KEY                     Fallback API key
//	BOS_AI_COOLDOWN_MINUTES=5             Cooldown before retrying
//
// Environment (local — self-hosted):
//
//	BOS_AI_LOCAL_TYPE=ollama|openai       API protocol (default: ollama)
//	BOS_AI_LOCAL_MODEL=qwen3:14b          Model name
//	BOS_AI_LOCAL_ENDPOINT=http://IP:PORT  Endpoint (default: OLLAMA_HOST or localhost:11434)
//	BOS_AI_LOCAL_API_KEY=                 Optional auth token for local endpoint
package biaos

import (
	"fmt"
	"os"
	"strings"
	"sync"
	"time"
)

// Backend holds the resolved model, endpoint, credentials, and API protocol.
type Backend struct {
	Name      string // "deepseek", "anthropic", "ollama"
	Model     string
	BaseURL   string
	AuthToken string // empty for local without auth
	IsLocal   bool   // true for self-hosted backends
	APIType   string // "anthropic", "ollama", "openai"
}

// RouterState indicates which backend tier is currently active.
type RouterState int

const (
	StatePrimary  RouterState = iota // Tier 1: DeepSeek V4 (cloud primary)
	StateFallback                    // Tier 2: Claude Sonnet (cloud fallback)
	StateLocal                       // Tier 3: local Ollama
)

func (s RouterState) String() string {
	switch s {
	case StatePrimary:
		return "primary"
	case StateFallback:
		return "fallback"
	case StateLocal:
		return "local"
	}
	return "unknown"
}

// Router manages automatic failover between three AI backend tiers.
//
// Flow: Primary → (error) → Fallback → (error) → Local
// After cooldown, the next call probes the best available tier.
// Manual override via --model= bypasses the circuit breaker for one call.
//
// Local tier is configurable via BOS_AI_LOCAL_TYPE:
//   - "ollama" (default): Ollama native /api/generate
//   - "openai": OpenAI-compatible /v1/chat/completions (vLLM, llama.cpp, LocalAI, LiteLLM)
type Router struct {
	mu sync.RWMutex

	primary  Backend // Tier 1: DeepSeek
	fallback Backend // Tier 2: Claude
	local    Backend // Tier 3: self-hosted (Ollama or OpenAI-compatible)

	// Local tier configuration
	localType     string // "ollama" or "openai"
	localEndpoint string // override endpoint
	localAPIKey   string // optional auth for local endpoint

	state RouterState

	// Per-backend rate-limit tracking
	primaryLimited   bool
	fallbackLimited  bool
	primaryCooldown  time.Time
	fallbackCooldown time.Time

	cooldownDuration time.Duration

	// Override state (single-request, cleared after Route() call)
	overrideModel string

	// Stats
	totalTokens   int
	fallbackCount int
	localCount    int
	lastError     string
	lastErrorAt   time.Time
}

// RouterStats provides observability into the router state.
type RouterStats struct {
	State               string `json:"state"`
	ActiveModel         string `json:"active_model"`
	PrimaryModel        string `json:"primary_model"`
	FallbackModel       string `json:"fallback_model"`
	LocalModel          string `json:"local_model"`
	LocalType           string `json:"local_type"`
	PrimaryLimited      bool   `json:"primary_limited"`
	FallbackLimited     bool   `json:"fallback_limited"`
	PrimaryCooldownRem  string `json:"primary_cooldown_rem,omitempty"`
	FallbackCooldownRem string `json:"fallback_cooldown_rem,omitempty"`
	TotalTokens         int    `json:"total_tokens"`
	FallbackCount       int    `json:"fallback_count"`
	LocalCount          int    `json:"local_count"`
	LastError           string `json:"last_error,omitempty"`
}

// NewRouter creates a three-tier router from environment configuration.
// At least one tier must be configured.
func NewRouter() (*Router, error) {
	primaryModel := envOrDefault("BOS_AI_PRIMARY_MODEL", "deepseek-v4-pro")
	fallbackModel := envOrDefault("BOS_AI_FALLBACK_MODEL", "claude-sonnet-4-20250514")
	localType := envOrDefault("BOS_AI_LOCAL_TYPE", "ollama")
	localModel := envOrDefault("BOS_AI_LOCAL_MODEL", "qwen3:14b")
	ollamaHost := envOrDefault("OLLAMA_HOST", "localhost:11434")

	localEndpoint := envOrDefault("BOS_AI_LOCAL_ENDPOINT", "")
	if localEndpoint == "" {
		localEndpoint = fmt.Sprintf("http://%s", ollamaHost)
	}
	localAPIKey := os.Getenv("BOS_AI_LOCAL_API_KEY")

	primary := Backend{
		Name:    "deepseek",
		Model:   primaryModel,
		BaseURL: envOrDefault("BOS_AI_BASE_URL", "https://api.deepseek.com/anthropic"),
	}
	primary.AuthToken = firstNonEmpty(
		os.Getenv("BOS_AI_API_KEY"),
		os.Getenv("DEEPSEEK_API_KEY"),
	)

	fallback := Backend{
		Name:    "anthropic",
		Model:   fallbackModel,
		BaseURL: "https://api.anthropic.com",
	}
	fallback.AuthToken = firstNonEmpty(
		os.Getenv("ANTHROPIC_API_KEY"),
	)

	var localName string
	switch localType {
	case "openai":
		localName = "openai"
	default:
		localName = "ollama"
	}

	local := Backend{
		Name:      localName,
		Model:     localModel,
		BaseURL:   localEndpoint,
		AuthToken: localAPIKey,
		IsLocal:   true,
		APIType:   localType,
	}

	if primary.AuthToken == "" && fallback.AuthToken == "" {
		// No cloud keys — only local is available.
	}

	cooldown := 5 * time.Minute
	if s := os.Getenv("BOS_AI_COOLDOWN_MINUTES"); s != "" {
		if d, err := time.ParseDuration(s + "m"); err == nil {
			cooldown = d
		}
	}

	r := &Router{
		primary:          primary,
		fallback:         fallback,
		local:            local,
		localType:        localType,
		localEndpoint:    localEndpoint,
		localAPIKey:      localAPIKey,
		state:            StatePrimary,
		cooldownDuration: cooldown,
	}
	// Sync initial state to the best actually available backend.
	b := r.bestAvailable()
	switch b.Name {
	case r.primary.Name:
		r.state = StatePrimary
	case r.fallback.Name:
		r.state = StateFallback
	default:
		r.state = StateLocal
	}
	return r, nil
}

// SetOverride forces a specific model for the next Route() call.
// Used by CLI --model= flag. Cleared after one call.
func (r *Router) SetOverride(model string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.overrideModel = strings.ToLower(strings.TrimSpace(model))
}

// Route retorna el backend activo actualmente.
// Si hay un override manual vía SetOverride, lo usa para una sola llamada.
// De lo contrario, sigue el circuit breaker: primary → fallback → local.
func (r *Router) Route() Backend {
	r.mu.Lock()
	defer r.mu.Unlock()

	// Manual override for one request.
	if r.overrideModel != "" {
		b := r.resolveOverride(r.overrideModel)
		r.overrideModel = "" // consume
		return b
	}

	// Check recovery: if a higher tier's cooldown has elapsed, try it again.
	r.checkRecovery()

	// Return best available tier.
	b := r.bestAvailable()
	// Sync state with actual backend used.
	switch b.Name {
	case r.primary.Name:
		r.state = StatePrimary
	case r.fallback.Name:
		r.state = StateFallback
	default:
		r.state = StateLocal
	}
	return b
}

// ReportRateLimit is called when the active backend returns HTTP 429 or quota error.
// It marks that backend as rate-limited and downgrades to the next tier.
func (r *Router) ReportRateLimit(backendName string, errMsg string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.lastError = errMsg
	r.lastErrorAt = time.Now()

	switch backendName {
	case r.primary.Name:
		r.primaryLimited = true
		r.primaryCooldown = time.Now()
		if r.state == StatePrimary {
			r.state = StateFallback
			r.fallbackCount++
		}
	case r.fallback.Name:
		r.fallbackLimited = true
		r.fallbackCooldown = time.Now()
		if r.state == StateFallback {
			r.state = StateLocal
			r.localCount++
		}
	}
}

// ReportSuccess tracks token usage from a successful API call.
func (r *Router) ReportSuccess(tokens int) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.totalTokens += tokens
}

// Stats returns router observability data.
func (r *Router) Stats() RouterStats {
	r.mu.RLock()
	defer r.mu.RUnlock()

	s := RouterStats{
		State:           r.state.String(),
		PrimaryModel:    r.primary.Model,
		FallbackModel:   r.fallback.Model,
		LocalModel:      r.local.Model,
		LocalType:       r.localType,
		PrimaryLimited:  r.primaryLimited,
		FallbackLimited: r.fallbackLimited,
		TotalTokens:     r.totalTokens,
		FallbackCount:   r.fallbackCount,
		LocalCount:      r.localCount,
		LastError:       r.lastError,
	}
	// Show which model would be used (respect overrides, no state mutation).
	best := r.peekRoute()
	s.ActiveModel = best.Model
	if best.IsLocal {
		s.ActiveModel += " (local)"
	}
	// Current tier matches the active backend's identity.
	if r.overrideModel != "" {
		switch {
		case strings.Contains(r.overrideModel, "deepseek"):
			s.State = "primary"
		case strings.Contains(r.overrideModel, "claude"):
			s.State = "fallback"
		case strings.Contains(r.overrideModel, "local"), strings.Contains(r.overrideModel, "ollama"):
			s.State = "local"
		}
	}
	if r.primaryLimited {
		rem := r.cooldownDuration - time.Since(r.primaryCooldown)
		if rem > 0 {
			s.PrimaryCooldownRem = rem.Truncate(time.Second).String()
		}
	}
	if r.fallbackLimited {
		rem := r.cooldownDuration - time.Since(r.fallbackCooldown)
		if rem > 0 {
			s.FallbackCooldownRem = rem.Truncate(time.Second).String()
		}
	}
	return s
}

// ActiveBackendName returns a human-readable description without mutating state.
func (r *Router) ActiveBackendName() string {
	b := r.peekRoute()
	if b.IsLocal {
		return fmt.Sprintf("%s (local Ollama)", b.Model)
	}
	return fmt.Sprintf("%s @ %s", b.Model, b.BaseURL)
}

// peekRoute returns the backend that would be used next, without consuming overrides.
func (r *Router) peekRoute() Backend {
	r.mu.RLock()
	defer r.mu.RUnlock()
	if r.overrideModel != "" {
		return r.resolveOverride(r.overrideModel)
	}
	b := r.bestAvailable()
	return b
}

// IsCloudAvailable returns true if at least one cloud backend is not rate-limited.
func (r *Router) IsCloudAvailable() bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return !r.primaryLimited || !r.fallbackLimited
}

// allLimited returns true if all cloud backends are rate-limited (caller must hold lock).
func (r *Router) allLimited() bool {
	primaryDown := r.primaryLimited || r.primary.AuthToken == ""
	fallbackDown := r.fallbackLimited || r.fallback.AuthToken == ""
	return primaryDown && fallbackDown
}

// checkRecovery clears rate-limit flags for backends whose cooldown has elapsed.
// Caller must hold r.mu.
func (r *Router) checkRecovery() {
	now := time.Now()
	if r.primaryLimited && now.Sub(r.primaryCooldown) >= r.cooldownDuration {
		r.primaryLimited = false
	}
	if r.fallbackLimited && now.Sub(r.fallbackCooldown) >= r.cooldownDuration {
		r.fallbackLimited = false
	}
	// Si un tier superior se recuperó, promover el estado.
	if !r.primaryLimited && r.primary.AuthToken != "" && r.state != StatePrimary {
		r.state = StatePrimary
	} else if !r.fallbackLimited && r.fallback.AuthToken != "" && r.state == StateLocal {
		r.state = StateFallback
	}
}

// bestAvailable returns the best non-rate-limited backend.
// Caller must hold r.mu.
func (r *Router) bestAvailable() Backend {
	// Tier 1: primary (Claude)
	if !r.primaryLimited && r.primary.AuthToken != "" {
		return r.primary
	}
	// Tier 2: fallback (DeepSeek)
	if !r.fallbackLimited && r.fallback.AuthToken != "" {
		return r.fallback
	}
	// Tier 3: local Ollama (always available if configured)
	return r.local
}

// resolveOverride maps a --model= value to the matching backend.
// Special values: "claude"→primary, "deepseek"→fallback, "local"→ollama.
// Otherwise tries to match by model name prefix.
func (r *Router) resolveOverride(model string) Backend {
	switch model {
	case "deepseek":
		return r.primary // DeepSeek is now primary
	case "claude", "anthropic":
		return r.fallback // Claude is now fallback
	case "local", "ollama":
		return r.local
	}
	// Prefix matching
	if strings.Contains(model, "deepseek") {
		b := r.primary
		b.Model = model
		return b
	}
	if strings.Contains(model, "claude") {
		b := r.fallback
		b.Model = model
		return b
	}
	// Default: treat as primary model override
	b := r.primary
	b.Model = model
	return b
}

// IsRateLimited returns true if the given error indicates rate limiting or quota exhaustion.
func IsRateLimited(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "429") ||
		strings.Contains(msg, "rate limit") ||
		strings.Contains(msg, "rate_limit") ||
		strings.Contains(msg, "quota") ||
		strings.Contains(msg, "exceeded") ||
		strings.Contains(msg, "too many requests") ||
		strings.Contains(msg, "budget") ||
		strings.Contains(msg, "capacity")
}

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}
