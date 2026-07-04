package ai

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

const (
	defaultTimeout     = 120 * time.Second
	defaultMaxTokens   = 1024
	defaultTemperature = 0.3
)

func clientTimeout() time.Duration {
	if s := os.Getenv("BOS_AI_TIMEOUT_SECONDS"); s != "" {
		if d, err := time.ParseDuration(s + "s"); err == nil && d > 0 {
			return d
		}
	}
	return defaultTimeout
}

// Client envía prompts al backend IA resuelto por el Router.
// En HTTP 429 (rate limit) escala: primary → fallback → local.
//
// Thread safety: seguro para uso concurrente — router.mu protege el estado de circuito.
type Client struct {
	router *Router
	http   *http.Client
}

// NewClient crea un cliente IA respaldado por el circuit breaker de 3 niveles del Router.
//
// Retorna: (*Client, error). Error si el Router no puede inicializarse (Router lee API keys de env).
//
// Callers conocidos:
//   - cmd/bosctl/app.go:cmdAsk — inicializa el cliente bajo demanda.
//
// Efectos secundarios: crea http.Client con timeout configurable (BOS_AI_TIMEOUT_SECONDS).
func NewClient() (*Client, error) {
	r, err := NewRouter()
	if err != nil {
		return nil, err
	}
	return &Client{
		router: r,
		http:   &http.Client{Timeout: clientTimeout()},
	}, nil
}

// SetModelOverride establece un override de modelo para la siguiente llamada Route().
// Usado por el flag --model= de bosctl.
func (c *Client) SetModelOverride(model string) {
	c.router.SetOverride(model)
}

// ── Anthropic-compatible Messages API types ──────────────────────────

type messagesRequest struct {
	Model       string        `json:"model"`
	MaxTokens   int           `json:"max_tokens"`
	Temperature float64       `json:"temperature"`
	System      string        `json:"system"`
	Messages    []messageTurn `json:"messages"`
}

type messageTurn struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type messagesResponse struct {
	Content []contentBlock `json:"content"`
	Usage   *usageInfo     `json:"usage,omitempty"`
	Error   *apiError      `json:"error,omitempty"`
}

type contentBlock struct {
	Type      string `json:"type"`
	Text      string `json:"text"`
	Thinking  string `json:"thinking"`  // DeepSeek reasoning blocks
	Signature string `json:"signature"` // DeepSeek thinking signature
}

type usageInfo struct {
	InputTokens  int `json:"input_tokens"`
	OutputTokens int `json:"output_tokens"`
}

type apiError struct {
	Type    string `json:"type"`
	Message string `json:"message"`
}

// ── Ollama API types ──────────────────────────────────────────────────

type ollamaRequest struct {
	Model   string `json:"model"`
	Prompt  string `json:"prompt"`
	Stream  bool   `json:"stream"`
	Options struct {
		Temperature float64 `json:"temperature"`
		NumPredict  int     `json:"num_predict"`
	} `json:"options"`
}

type ollamaResponse struct {
	Response string `json:"response"`
	Error    string `json:"error,omitempty"`
}

// ── Prompts ───────────────────────────────────────────────────────────

const systemPrompt = `Eres BOS, el asistente del Business Operating System (SBOS).
BOS unifica Ubuntu + Kubernetes bajo una sola superficie de control: bosctl.

Tu rol es ayudar al operador a diagnosticar, explicar y planificar acciones sobre el sistema.
Responde siempre en español, de forma concisa y orientada a la accion.

Contexto que recibiras:
- Resumen del state file (.sbos_state.json): fichas instaladas, versiones, estados
- Uso de disco (df -h), memoria (free -h), nodos K8s (kubectl get nodes)

Reglas:
- NUNCA sugieras comandos destructivos (rm -rf, kubectl delete --all, DROP, etc.)
- Siempre propon comandos bosctl cuando aplique (bosctl repair, bosctl top, bosctl health-report)
- Si no tienes suficiente contexto, dilo y sugiere que comandos ejecutar para obtenerlo
- Se breve. El operador quiere respuestas accionables, no ensayos.`

// ── Public API ────────────────────────────────────────────────────────

// Ask envía un prompt con contexto del sistema a través del circuit breaker del router.
// Escala primary → fallback → local ante errores de rate-limit (HTTP 429).
//
// Recibe:
//   - prompt: string — pregunta del operador.
//   - ctx: *AIContext — contexto del sistema (fichas, disco, memoria, K8s).
//   - modelOverride: string — override de modelo desde --model= (vacío = auto).
//
// Retorna: (respuesta, error). Error si los 3 niveles fallan.
//
// Callers conocidos:
//   - cmd/bosctl/app.go:cmdAsk — entrada principal del comando bosctl ia.
//
// Efectos secundarios:
//   - Hace HTTP POST a los backends configurados.
//   - NUNCA registrar contraseñas ni tokens en logs.
//
// Estándares: ADR-003.
func (c *Client) Ask(prompt string, ctx *AIContext, modelOverride string) (string, error) {
	if modelOverride != "" {
		c.router.SetOverride(modelOverride)
	}

	// Cascade through tiers: try primary → fallback → local.
	// Rate-limit errors (429) trigger circuit breaker; other errors cascade
	// without disabling the backend permanently.
	var errors []string
	for tier := 0; tier < 3; tier++ {
		backend := c.router.Route()

		result, err := c.callBackend(backend, prompt, ctx)
		if err == nil {
			return result, nil
		}

		errors = append(errors, fmt.Sprintf("%s: %v", backend.Name, err))

		// Only engage circuit breaker on actual rate-limit errors.
		if IsRateLimited(err) {
			c.router.ReportRateLimit(backend.Name, err.Error())
		}
		// Continue to next tier.
	}

	// All tiers exhausted — report each backend's error.
	return "", fmt.Errorf("ai: all backends exhausted: %s", strings.Join(errors, "; "))
}

// ActiveBackend retorna una descripción legible del backend activo actualmente.
func (c *Client) ActiveBackend() string {
	return c.router.ActiveBackendName()
}

// RouterStats retorna los datos de observabilidad del router (tokens, errores, niveles).
func (c *Client) RouterStats() RouterStats {
	return c.router.Stats()
}

// ── Backend dispatcher ────────────────────────────────────────────────

func (c *Client) callBackend(backend Backend, prompt string, ctx *AIContext) (string, error) {
	if backend.IsLocal {
		if backend.APIType == "openai" {
			return c.callOpenAI(backend, prompt, ctx)
		}
		return c.callOllama(backend, prompt, ctx)
	}
	return c.callAnthropicAPI(backend, prompt, ctx)
}

// ── Anthropic-compatible API (Claude + DeepSeek) ──────────────────────

func (c *Client) callAnthropicAPI(backend Backend, prompt string, ctx *AIContext) (string, error) {
	body := messagesRequest{
		Model:       backend.Model,
		MaxTokens:   defaultMaxTokens,
		Temperature: defaultTemperature,
		System:      systemPrompt,
		Messages: []messageTurn{
			{Role: "user", Content: ctx.Format(prompt)},
		},
	}

	payload, err := json.Marshal(body)
	if err != nil {
		return "", fmt.Errorf("ai: marshal: %w", err)
	}

	url := backend.BaseURL + "/v1/messages"
	req, err := http.NewRequest("POST", url, bytes.NewReader(payload))
	if err != nil {
		return "", fmt.Errorf("ai: request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", backend.AuthToken)
	req.Header.Set("anthropic-version", "2023-06-01")

	resp, err := c.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("ai: %s: %w", backend.BaseURL, err)
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return "", fmt.Errorf("ai: read response: %w", err)
	}

	if resp.StatusCode == 429 {
		return "", fmt.Errorf("ai: rate limit (%d): %s", resp.StatusCode, truncate(string(bodyBytes), 200))
	}
	if resp.StatusCode >= 500 {
		return "", fmt.Errorf("ai: server error (%d): %s", resp.StatusCode, truncate(string(bodyBytes), 200))
	}
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("ai: %s (status %d)", truncate(string(bodyBytes), 300), resp.StatusCode)
	}

	var mr messagesResponse
	if err := json.Unmarshal(bodyBytes, &mr); err != nil {
		return "", fmt.Errorf("ai: parse response: %w", err)
	}
	if mr.Error != nil {
		return "", fmt.Errorf("ai: %s: %s", mr.Error.Type, mr.Error.Message)
	}
	if len(mr.Content) == 0 {
		return "(respuesta vacia del modelo)", nil
	}

	if mr.Usage != nil {
		c.router.ReportSuccess(mr.Usage.InputTokens + mr.Usage.OutputTokens)
	}

	// Collect text from all content blocks (handles both "text" and "thinking" types).
	var parts []string
	for _, block := range mr.Content {
		switch block.Type {
		case "text":
			if block.Text != "" {
				parts = append(parts, block.Text)
			}
		case "thinking":
			if block.Thinking != "" {
				parts = append(parts, "[thinking] "+block.Thinking)
			}
		}
	}
	if len(parts) > 0 {
		return strings.Join(parts, "\n"), nil
	}
	return "(respuesta sin texto)", nil
}

// ── Ollama local API ──────────────────────────────────────────────────

func (c *Client) callOllama(backend Backend, prompt string, ctx *AIContext) (string, error) {
	fullPrompt := systemPrompt + "\n\n" + ctx.Format(prompt)

	body := ollamaRequest{
		Model:  backend.Model,
		Prompt: fullPrompt,
		Stream: false,
	}
	body.Options.Temperature = defaultTemperature
	body.Options.NumPredict = defaultMaxTokens

	payload, err := json.Marshal(body)
	if err != nil {
		return "", fmt.Errorf("ai: marshal ollama: %w", err)
	}

	url := backend.BaseURL + "/api/generate"
	req, err := http.NewRequest("POST", url, bytes.NewReader(payload))
	if err != nil {
		return "", fmt.Errorf("ai: ollama request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("ai: ollama %s: %w", backend.BaseURL, err)
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return "", fmt.Errorf("ai: ollama read: %w", err)
	}

	// Ollama retorna ndjson en streaming; solicitamos stream=false para obtener un único objeto JSON.
	// Si retorna múltiples líneas, tomar la última (respuesta final).
	lines := strings.Split(strings.TrimSpace(string(bodyBytes)), "\n")
	lastLine := lines[len(lines)-1]

	var or ollamaResponse
	if err := json.Unmarshal([]byte(lastLine), &or); err != nil {
		return "", fmt.Errorf("ai: ollama parse: %w (body: %s)", err, truncate(string(bodyBytes), 200))
	}
	if or.Error != "" {
		return "", fmt.Errorf("ai: ollama: %s", or.Error)
	}

	c.router.ReportSuccess(defaultMaxTokens) // Ollama doesn't report exact token counts
	return or.Response, nil
}

// ── OpenAI-compatible API (vLLM / llama.cpp / LocalAI / LiteLLM) ──────

type openaiChatRequest struct {
	Model       string          `json:"model"`
	Messages    []openaiMessage `json:"messages"`
	Temperature float64         `json:"temperature"`
	MaxTokens   int             `json:"max_tokens"`
}

type openaiMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type openaiChatResponse struct {
	Choices []openaiChoice `json:"choices"`
	Usage   *openaiUsage   `json:"usage,omitempty"`
	Error   *openaiError   `json:"error,omitempty"`
}

type openaiChoice struct {
	Message openaiMessage `json:"message"`
}

type openaiUsage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
}

type openaiError struct {
	Message string `json:"message"`
}

func (c *Client) callOpenAI(backend Backend, prompt string, ctx *AIContext) (string, error) {
	body := openaiChatRequest{
		Model: backend.Model,
		Messages: []openaiMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: ctx.Format(prompt)},
		},
		Temperature: defaultTemperature,
		MaxTokens:   defaultMaxTokens,
	}

	payload, err := json.Marshal(body)
	if err != nil {
		return "", fmt.Errorf("ai: marshal openai: %w", err)
	}

	url := backend.BaseURL + "/v1/chat/completions"
	req, err := http.NewRequest("POST", url, bytes.NewReader(payload))
	if err != nil {
		return "", fmt.Errorf("ai: openai request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	if backend.AuthToken != "" {
		req.Header.Set("Authorization", "Bearer "+backend.AuthToken)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("ai: openai %s: %w", backend.BaseURL, err)
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return "", fmt.Errorf("ai: openai read: %w", err)
	}

	if resp.StatusCode == 429 {
		return "", fmt.Errorf("ai: rate limit (%d): %s", resp.StatusCode, truncate(string(bodyBytes), 200))
	}
	if resp.StatusCode >= 500 {
		return "", fmt.Errorf("ai: server error (%d): %s", resp.StatusCode, truncate(string(bodyBytes), 200))
	}
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("ai: openai (status %d): %s", resp.StatusCode, truncate(string(bodyBytes), 300))
	}

	var cr openaiChatResponse
	if err := json.Unmarshal(bodyBytes, &cr); err != nil {
		return "", fmt.Errorf("ai: openai parse: %w (body: %s)", err, truncate(string(bodyBytes), 200))
	}
	if cr.Error != nil {
		return "", fmt.Errorf("ai: openai: %s", cr.Error.Message)
	}
	if len(cr.Choices) == 0 {
		return "(respuesta vacia del modelo)", nil
	}

	if cr.Usage != nil {
		c.router.ReportSuccess(cr.Usage.PromptTokens + cr.Usage.CompletionTokens)
	}

	return cr.Choices[0].Message.Content, nil
}

func truncate(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max] + "..."
}
