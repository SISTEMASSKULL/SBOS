// Package ficha — Health checker declarativo (F11.D.1).
// BOS-REPAIR Plan Maestro v3.
//
// Cada ficha define su propio health check en manifest.yml → sección health.
// El BOS ejecuta cada check según el intervalo declarado (default: 30s).
// 3 fallos consecutivos → transición a DEGRADADA (ADR-021 #8).
// 1 éxito → transición de DEGRADADA a INSTALADA.
// ALERTA exactamente al 3er fallo consecutivo.
//
// Tipos de health check soportados:
//   - command: ejecuta un comando shell, opcionalmente verifica expected_output
//   - http:    GET al endpoint, espera HTTP 200
//   - tcp:     TCP connect al puerto
//   - none:    no se ejecuta health check (ficha no tiene probe aún)
//
// Estándares: SBOS-019 §manifest.health, ADR-021, ISO 27001 A.8.15.
package ficha

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"os/exec"
	"strings"
	"sync"
	"time"

	"log/slog"
)

// ── Tipos ────────────────────────────────────────────────────────────

// HealthType clasifica el tipo de health check.
type HealthType string

const (
	HealthCommand HealthType = "command"
	HealthHTTP    HealthType = "http"
	HealthTCP     HealthType = "tcp"
	HealthNone    HealthType = "none"
)

// HealthDef define el health check de una ficha (desde manifest.yml).
type HealthDef struct {
	Type            HealthType `json:"type" yaml:"type"`
	Command         string     `json:"command,omitempty" yaml:"command,omitempty"`
	HTTPPath        string     `json:"http_path,omitempty" yaml:"http_path,omitempty"`
	TCPAddress      string     `json:"tcp_address,omitempty" yaml:"tcp_address,omitempty"`
	ExpectedOutput  string     `json:"expected_output,omitempty" yaml:"expected_output,omitempty"`
	TimeoutSeconds  int        `json:"timeout_seconds" yaml:"timeout_seconds"`
	IntervalSeconds int        `json:"interval_seconds" yaml:"interval_seconds"` // default: 30
	FailureThreshold int      `json:"failure_threshold" yaml:"failure_threshold"` // default: 3
}

// DefaultHealthDef retorna un HealthDef con valores por defecto.
func DefaultHealthDef() HealthDef {
	return HealthDef{
		Type:             HealthNone,
		TimeoutSeconds:   10,
		IntervalSeconds:  30,
		FailureThreshold: 3,
	}
}

// HealthResult contiene el resultado de ejecutar un health check.
type HealthResult struct {
	FichaID   string        `json:"ficha_id"`
	Healthy   bool          `json:"healthy"`
	Type      HealthType    `json:"type"`
	Output    string        `json:"output,omitempty"`
	Error     string        `json:"error,omitempty"`
	Duration  time.Duration `json:"duration"`
	Timestamp time.Time     `json:"timestamp"`
}

// ── Rastreador de fallos consecutivos ─────────────────────────────────

// HealthTracker mantiene el conteo de fallos consecutivos por ficha.
// Thread-safe: usa sync.Mutex para acceso concurrente desde el observer.
type HealthTracker struct {
	mu      sync.Mutex
	failures map[string]int // ficha_id → fallos consecutivos
}

// NewHealthTracker crea un rastreador de fallos.
func NewHealthTracker() *HealthTracker {
	return &HealthTracker{failures: make(map[string]int)}
}

// Record registra un resultado de health check.
// Retorna true si se alcanzó el umbral de fallos (debe disparar DEGRADADA).
func (t *HealthTracker) Record(fichaID string, healthy bool, threshold int) (degraded bool) {
	t.mu.Lock()
	defer t.mu.Unlock()

	if healthy {
		t.failures[fichaID] = 0
		return false
	}

	t.failures[fichaID]++
	if t.failures[fichaID] >= threshold {
		return true // umbral alcanzado → DEGRADADA
	}
	return false
}

// ConsecutiveFailures retorna el número de fallos consecutivos de una ficha.
func (t *HealthTracker) ConsecutiveFailures(fichaID string) int {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.failures[fichaID]
}

// Reset limpia el contador de fallos de una ficha.
func (t *HealthTracker) Reset(fichaID string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	delete(t.failures, fichaID)
}

// Statuses retorna un mapa de ficha_id → fallos consecutivos.
func (t *HealthTracker) Statuses() map[string]int {
	t.mu.Lock()
	defer t.mu.Unlock()
	result := make(map[string]int, len(t.failures))
	for k, v := range t.failures {
		result[k] = v
	}
	return result
}

// ── Health checker ────────────────────────────────────────────────────

// HealthChecker ejecuta health checks declarativos para fichas.
// StateNotifier es llamado cuando una ficha debe transicionar de estado.
type StateNotifier func(fichaID string, newState string, reason string)

// HealthChecker ejecuta y rastrea health checks de fichas.
type HealthChecker struct {
	tracker  *HealthTracker
	notifier StateNotifier // llamado al alcanzar el umbral de fallos
	logger   *slog.Logger
}

// NewHealthChecker crea un health checker con el notificador dado.
// notifier puede ser nil si no se requiere transición automática de estado.
func NewHealthChecker(notifier StateNotifier, logger *slog.Logger) *HealthChecker {
	if logger == nil {
		logger = slog.Default()
	}
	return &HealthChecker{
		tracker:  NewHealthTracker(),
		notifier: notifier,
		logger:   logger,
	}
}

// Check ejecuta un health check para una ficha según su HealthDef.
// Retorna el resultado y si se debe transicionar a DEGRADADA.
func (h *HealthChecker) Check(fichaID string, def HealthDef) HealthResult {
	start := time.Now()
	result := HealthResult{
		FichaID:   fichaID,
		Type:      def.Type,
		Timestamp: start,
	}

	// Aplicar defaults
	if def.Type == "" {
		def.Type = HealthNone
	}
	if def.TimeoutSeconds <= 0 {
		def.TimeoutSeconds = 10
	}
	if def.FailureThreshold <= 0 {
		def.FailureThreshold = 3
	}

	timeout := time.Duration(def.TimeoutSeconds) * time.Second
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	var err error

	switch def.Type {
	case HealthCommand:
		err = h.checkCommand(ctx, def, &result)
	case HealthHTTP:
		err = h.checkHTTP(ctx, def, &result)
	case HealthTCP:
		err = h.checkTCP(ctx, def, &result)
	case HealthNone:
		result.Healthy = true
		result.Output = "health check deshabilitado (type=none)"
	default:
		err = fmt.Errorf("tipo de health check desconocido: %s", def.Type)
	}

	result.Duration = time.Since(start)

	if err != nil {
		result.Healthy = false
		result.Error = err.Error()
	} else if !result.Healthy {
		result.Error = "health check falló"
	}

	// Registrar en el tracker y notificar si aplica
	degraded := h.tracker.Record(fichaID, result.Healthy, def.FailureThreshold)
	if degraded && h.notifier != nil {
		h.notifier(fichaID, "DEGRADADA",
			fmt.Sprintf("%d fallos consecutivos de health check (threshold=%d)",
				h.tracker.ConsecutiveFailures(fichaID), def.FailureThreshold))
	}

	if result.Healthy {
		h.logger.Debug("health check OK", "ficha", fichaID, "type", def.Type, "duration", result.Duration)
	} else {
		failures := h.tracker.ConsecutiveFailures(fichaID)
		h.logger.Warn("health check falló",
			"ficha", fichaID,
			"type", def.Type,
			"error", result.Error,
			"consecutive_failures", failures,
			"threshold", def.FailureThreshold,
		)
	}

	return result
}

// checkCommand ejecuta un health check tipo command.
func (h *HealthChecker) checkCommand(ctx context.Context, def HealthDef, result *HealthResult) error {
	if def.Command == "" {
		result.Healthy = false
		return fmt.Errorf("health command vacío")
	}

	cmd := exec.CommandContext(ctx, "bash", "-c", def.Command)
	output, err := cmd.Output()
	result.Output = strings.TrimSpace(string(output))

	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return fmt.Errorf("timeout después de %ds", def.TimeoutSeconds)
		}
		return fmt.Errorf("comando falló: %w — output: %s", err, result.Output)
	}

	// Verificar expected_output si está definido
	if def.ExpectedOutput != "" {
		if !strings.Contains(result.Output, def.ExpectedOutput) {
			result.Healthy = false
			return fmt.Errorf("output no contiene %q: %s", def.ExpectedOutput, result.Output)
		}
	}

	result.Healthy = true
	return nil
}

// checkHTTP ejecuta un health check tipo http.
func (h *HealthChecker) checkHTTP(ctx context.Context, def HealthDef, result *HealthResult) error {
	if def.HTTPPath == "" {
		result.Healthy = false
		return fmt.Errorf("health http_path vacío")
	}

	timeout := time.Duration(def.TimeoutSeconds) * time.Second
	client := &http.Client{Timeout: timeout}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, def.HTTPPath, nil)
	if err != nil {
		return fmt.Errorf("crear request HTTP: %w", err)
	}

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("HTTP GET %s: %w", def.HTTPPath, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		result.Healthy = true
		result.Output = fmt.Sprintf("HTTP %d", resp.StatusCode)
	} else {
		result.Healthy = false
		result.Output = fmt.Sprintf("HTTP %d", resp.StatusCode)
		return fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	return nil
}

// checkTCP ejecuta un health check tipo tcp (dial).
func (h *HealthChecker) checkTCP(ctx context.Context, def HealthDef, result *HealthResult) error {
	if def.TCPAddress == "" {
		result.Healthy = false
		return fmt.Errorf("health tcp_address vacío")
	}

	timeout := time.Duration(def.TimeoutSeconds) * time.Second
	d := net.Dialer{Timeout: timeout}
	conn, err := d.DialContext(ctx, "tcp", def.TCPAddress)
	if err != nil {
		return fmt.Errorf("TCP dial %s: %w", def.TCPAddress, err)
	}
	conn.Close()

	result.Healthy = true
	result.Output = fmt.Sprintf("TCP connect %s OK", def.TCPAddress)
	return nil
}

// ── Helpers ────────────────────────────────────────────────────────────

// Tracker retorna el rastreador interno para consultas externas.
func (h *HealthChecker) Tracker() *HealthTracker {
	return h.tracker
}

// CheckAll ejecuta health checks para múltiples fichas en paralelo.
// Retorna un mapa ficha_id → HealthResult.
func (h *HealthChecker) CheckAll(fichas map[string]HealthDef) map[string]HealthResult {
	results := make(map[string]HealthResult, len(fichas))
	var mu sync.Mutex
	var wg sync.WaitGroup

	for id, def := range fichas {
		wg.Add(1)
		go func(fichaID string, healthDef HealthDef) {
			defer wg.Done()
			result := h.Check(fichaID, healthDef)
			mu.Lock()
			results[fichaID] = result
			mu.Unlock()
		}(id, def)
	}

	wg.Wait()
	return results
}

// ParseHealthFromManifest extrae la configuración de health de un YAML de manifiesto.
// Acepta el contenido crudo del manifest.yml y retorna un HealthDef.
func ParseHealthFromManifest(manifestContent string) HealthDef {
	def := DefaultHealthDef()

	for _, line := range strings.Split(manifestContent, "\n") {
		trimmed := strings.TrimSpace(line)

		switch {
		case strings.HasPrefix(trimmed, "type:"):
			typeVal := strings.Trim(strings.TrimPrefix(trimmed, "type:"), ` "'`)
			switch typeVal {
			case "command":
				def.Type = HealthCommand
			case "http":
				def.Type = HealthHTTP
			case "tcp":
				def.Type = HealthTCP
			case "none":
				def.Type = HealthNone
			}
		case strings.HasPrefix(trimmed, "command:"):
			def.Command = strings.Trim(strings.TrimPrefix(trimmed, "command:"), ` "'`)
		case strings.HasPrefix(trimmed, "http_path:"):
			def.HTTPPath = strings.Trim(strings.TrimPrefix(trimmed, "http_path:"), ` "'`)
		case strings.HasPrefix(trimmed, "tcp_address:"):
			def.TCPAddress = strings.Trim(strings.TrimPrefix(trimmed, "tcp_address:"), ` "'`)
		case strings.HasPrefix(trimmed, "expected_output:"):
			def.ExpectedOutput = strings.Trim(strings.TrimPrefix(trimmed, "expected_output:"), ` "'`)
		}
	}

	return def
}
