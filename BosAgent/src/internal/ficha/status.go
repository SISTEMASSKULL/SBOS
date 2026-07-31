// Package ficha — Recolector de estado integral (F11.D.4).
// BOS-REPAIR Plan Maestro v3.
//
// El recolector consulta múltiples fuentes para producir un estado detallado
// de cada ficha, útil para CLI (bosctl ficha status), JSON-RPC y dashboards.
//
// Fuentes consultadas:
//   - state.Manager: estado (18 estados ADR-021), versión, servidor
//   - HealthChecker: último health check, fallos consecutivos
//   - DriftDetector: drift vs estado declarado
//   - Runtime: uptime, réplicas, CPU/RAM (stub hasta F9 K8s integration)
//
// El resultado se presenta como FichaStatusDetail, con soporte para
// salida JSON (CI/CD) y tabla coloreada (terminal).
package ficha

import (
	"fmt"
	"strings"
	"time"
)

// ── Tipos ────────────────────────────────────────────────────────────

// FichaStatusDetail contiene el estado completo de una ficha desde todas las fuentes.
type FichaStatusDetail struct {
	// Identidad
	ID          string `json:"id"`
	Server      string `json:"server"`
	Version     string `json:"version"`
	Category    int    `json:"category"`
	Criticality bool   `json:"criticality"`
	Description string `json:"description,omitempty"`

	// Estado operativo (18 estados ADR-021)
	State       string    `json:"state"`
	PrevState   string    `json:"prev_state,omitempty"`
	InstalledAt time.Time `json:"installed_at,omitempty"`
	UpdatedAt   time.Time `json:"updated_at"`

	// Health
	HealthStatus        string    `json:"health_status"`        // "healthy", "degraded", "down", "unknown"
	LastHealthCheck     time.Time `json:"last_health_check,omitempty"`
	ConsecutiveFailures int       `json:"consecutive_failures"`
	HealthType          string    `json:"health_type,omitempty"`

	// Drift
	HasDrift      bool       `json:"has_drift"`
	DriftItems    int        `json:"drift_items,omitempty"`
	LastDriftCheck time.Time `json:"last_drift_check,omitempty"`

	// Runtime (K8s) — stub hasta F9
	Replicas     int32  `json:"replicas,omitempty"`
	ReadyReplicas int32 `json:"ready_replicas,omitempty"`
	CPUUsage     string `json:"cpu_usage,omitempty"`
	MemoryUsage  string `json:"memory_usage,omitempty"`
	Uptime       string `json:"uptime,omitempty"`

	// Metadatos
	WorkloadType    string   `json:"workload_type,omitempty"`
	ExecutionOrder  int      `json:"execution_order"`
	Dependencies    []string `json:"dependencies,omitempty"`
	AutoInstall     bool     `json:"auto_install"`
	Backend         string   `json:"backend,omitempty"`
	Policy          string   `json:"reconcile_policy,omitempty"`
}

// FichaStatusSummary resume el estado de todas las fichas.
type FichaStatusSummary struct {
	Total       int `json:"total"`
	Installed   int `json:"installed"`
	Degraded    int `json:"degraded"`
	Error       int `json:"error"`
	Pending     int `json:"pending"`
	Paused      int `json:"paused"`
	WithDrift   int `json:"with_drift"`
	Unhealthy   int `json:"unhealthy"`
	Fichas      []FichaStatusDetail `json:"fichas,omitempty"`
	GeneratedAt time.Time           `json:"generated_at"`
}

// ── Recolector ────────────────────────────────────────────────────────

// StatusCollector recolecta el estado de fichas desde múltiples fuentes.
type StatusCollector struct {
	healthTracker *HealthTracker
	driftDetector *DriftDetector
	reconciler    *Reconciler
}

// NewStatusCollector crea un recolector de estado.
// Todos los parámetros son opcionales — si son nil, esa sección queda con defaults.
func NewStatusCollector(
	health *HealthTracker,
	drift *DriftDetector,
	reconciler *Reconciler,
) *StatusCollector {
	return &StatusCollector{
		healthTracker: health,
		driftDetector: drift,
		reconciler:    reconciler,
	}
}

// StatusInput contiene los datos necesarios para recolectar el estado de una ficha.
type StatusInput struct {
	// Desde state.Manager
	ID          string
	Server      string
	Version     string
	Category    int
	Criticality bool
	State       string
	InstalledAt time.Time
	UpdatedAt   time.Time

	// Desde plugin.Loader
	WorkloadType   string
	ExecutionOrder int
	Dependencies   []string
	AutoInstall    bool
	Backend        string
	Description    string

	// Desde manifest
	HealthType string

	// Para drift
	FichaPath    string
	KnownHashes  map[string]string
}

// Collect recolecta el estado completo de una ficha.
func (c *StatusCollector) Collect(input StatusInput) FichaStatusDetail {
	detail := FichaStatusDetail{
		ID:             input.ID,
		Server:         input.Server,
		Version:        input.Version,
		Category:       input.Category,
		Criticality:    input.Criticality,
		Description:    input.Description,
		State:          input.State,
		InstalledAt:    input.InstalledAt,
		UpdatedAt:      input.UpdatedAt,
		WorkloadType:   input.WorkloadType,
		ExecutionOrder: input.ExecutionOrder,
		Dependencies:   input.Dependencies,
		AutoInstall:    input.AutoInstall,
		Backend:        input.Backend,
		HealthType:     input.HealthType,
	}

	// ── Health ────────────────────────────────────────────────────
	if c.healthTracker != nil {
		detail.ConsecutiveFailures = c.healthTracker.ConsecutiveFailures(input.ID)

		switch {
		case detail.ConsecutiveFailures == 0 && detail.State == "INSTALLED":
			detail.HealthStatus = "healthy"
		case detail.ConsecutiveFailures >= 3:
			detail.HealthStatus = "down"
		case detail.ConsecutiveFailures > 0:
			detail.HealthStatus = "degraded"
		default:
			detail.HealthStatus = "unknown"
		}
	} else {
		detail.HealthStatus = "unknown"
	}

	// ── Drift ─────────────────────────────────────────────────────
	if c.driftDetector != nil && input.FichaPath != "" {
		report, err := c.driftDetector.Detect(input.ID, input.FichaPath, input.KnownHashes)
		if err == nil {
			detail.HasDrift = report.HasDrift
			detail.DriftItems = countDrifted(report)
			detail.LastDriftCheck = report.CheckedAt
		}
	}

	// ── Política de reconciliación ────────────────────────────────
	if c.reconciler != nil {
		detail.Policy = string(c.reconciler.GetPolicy(input.ID))
	} else {
		detail.Policy = string(DefaultPolicy(input.Criticality))
	}

	// ── Runtime (stub hasta F9) ──────────────────────────────────
	// TODO(F9): obtener réplicas, CPU, RAM de K8s cuando el operator esté integrado
	detail.Replicas = 0
	detail.ReadyReplicas = 0
	detail.CPUUsage = ""
	detail.MemoryUsage = ""
	detail.Uptime = ""

	return detail
}

// CollectAll recolecta el estado de múltiples fichas y produce un resumen.
func (c *StatusCollector) CollectAll(inputs []StatusInput) *FichaStatusSummary {
	summary := &FichaStatusSummary{
		Total:       len(inputs),
		GeneratedAt: time.Now(),
		Fichas:      make([]FichaStatusDetail, 0, len(inputs)),
	}

	for _, input := range inputs {
		detail := c.Collect(input)
		summary.Fichas = append(summary.Fichas, detail)

		switch {
		case detail.State == "INSTALLED" && detail.HealthStatus == "healthy":
			summary.Installed++
		case detail.State == "DEGRADED" || detail.ConsecutiveFailures > 0:
			summary.Degraded++
		case detail.State == "PHYSICAL_ERROR" || detail.State == "LOGICAL_ERROR" ||
			detail.State == "UNRECOVERABLE" || detail.State == "INSTALL_FAILED" ||
			detail.State == "UPDATE_FAILED":
			summary.Error++
		case detail.State == "PENDING" || detail.State == "READY":
			summary.Pending++
		case detail.State == "PAUSED":
			summary.Paused++
		default:
			summary.Installed++
		}

		if detail.HasDrift {
			summary.WithDrift++
		}
		if detail.HealthStatus != "healthy" && detail.HealthStatus != "unknown" {
			summary.Unhealthy++
		}
	}

	return summary
}

// ── Representación ────────────────────────────────────────────────────

// TableHeaders retorna los encabezados de la tabla de estado.
func (FichaStatusDetail) TableHeaders() []string {
	return []string{"ID", "ESTADO", "VERSIÓN", "HEALTH", "DRIFT", "FAILS", "POLÍTICA"}
}

// TableRow retorna la fila de tabla para esta ficha.
func (d *FichaStatusDetail) TableRow() []string {
	drift := "✓"
	if d.HasDrift {
		drift = fmt.Sprintf("⚠ %d", d.DriftItems)
	}

	health := d.HealthStatus
	switch health {
	case "healthy":
		health = "🟢 healthy"
	case "degraded":
		health = "🟡 degraded"
	case "down":
		health = "🔴 down"
	}

	fails := ""
	if d.ConsecutiveFailures > 0 {
		fails = fmt.Sprintf("%d", d.ConsecutiveFailures)
	} else {
		fails = "-"
	}

	policy := d.Policy
	switch d.Policy {
	case "autonomous":
		policy = "auto"
	case "recommend":
		policy = "rec"
	case "block_and_alert":
		policy = "🚨 block"
	}

	return []string{
		d.ID,
		d.State,
		d.Version,
		health,
		drift,
		fails,
		policy,
	}
}

// DetailText retorna una representación detallada en texto para una ficha.
func (d *FichaStatusDetail) DetailText() string {
	var sb strings.Builder

	// Encabezado con color
	stateIcon := "✅"
	switch {
	case d.State == "DEGRADED" || d.HealthStatus == "degraded":
		stateIcon = "🟡"
	case d.State == "PHYSICAL_ERROR" || d.State == "LOGICAL_ERROR" || d.State == "UNRECOVERABLE":
		stateIcon = "🔴"
	case d.State == "PAUSED":
		stateIcon = "⏸️"
	case d.State == "INSTALLING" || d.State == "REPAIRING" || d.State == "UPDATING":
		stateIcon = "⏳"
	case d.State == "PENDING" || d.State == "READY":
		stateIcon = "⬜"
	}

	fmt.Fprintf(&sb, "%s %s — %s v%s\n", stateIcon, d.ID, d.State, d.Version)
	fmt.Fprintf(&sb, "  Servidor:      %s\n", d.Server)
	fmt.Fprintf(&sb, "  Workload:      %s\n", d.WorkloadType)
	fmt.Fprintf(&sb, "  Orden:         %d\n", d.ExecutionOrder)
	if len(d.Dependencies) > 0 {
		fmt.Fprintf(&sb, "  Dependencias:  %s\n", strings.Join(d.Dependencies, ", "))
	}
	if d.Description != "" {
		fmt.Fprintf(&sb, "  Descripción:   %s\n", d.Description)
	}

	fmt.Fprintf(&sb, "\n  ── Salud ──\n")
	fmt.Fprintf(&sb, "  Estado:        %s\n", d.HealthStatus)
	if d.HealthType != "" {
		fmt.Fprintf(&sb, "  Tipo check:    %s\n", d.HealthType)
	}
	if d.ConsecutiveFailures > 0 {
		fmt.Fprintf(&sb, "  Fallos consec: %d ⚠️\n", d.ConsecutiveFailures)
	}
	if !d.LastHealthCheck.IsZero() {
		fmt.Fprintf(&sb, "  Último check:  %s\n", d.LastHealthCheck.Format("2006-01-02 15:04:05"))
	}

	fmt.Fprintf(&sb, "\n  ── Drift ──\n")
	if d.HasDrift {
		fmt.Fprintf(&sb, "  Estado:        ⚠️ %d items con drift\n", d.DriftItems)
	} else {
		fmt.Fprintf(&sb, "  Estado:        ✅ sin drift\n")
	}
	if !d.LastDriftCheck.IsZero() {
		fmt.Fprintf(&sb, "  Último check:  %s\n", d.LastDriftCheck.Format("2006-01-02 15:04:05"))
	}

	fmt.Fprintf(&sb, "\n  ── Política ──\n")
	fmt.Fprintf(&sb, "  Reconciliación: %s\n", d.Policy)
	fmt.Fprintf(&sb, "  Auto-install:   %v\n", d.AutoInstall)

	if !d.InstalledAt.IsZero() {
		fmt.Fprintf(&sb, "\n  ── Ciclo de vida ──\n")
		fmt.Fprintf(&sb, "  Instalada:     %s\n", d.InstalledAt.Format("2006-01-02 15:04:05"))
		fmt.Fprintf(&sb, "  Actualizada:   %s\n", d.UpdatedAt.Format("2006-01-02 15:04:05"))
	}

	return sb.String()
}

// SummaryText retorna un resumen de estado de todas las fichas.
func (s *FichaStatusSummary) SummaryText() string {
	var sb strings.Builder
	fmt.Fprintf(&sb, "Fichas: %d total", s.Total)
	if s.Installed > 0 {
		fmt.Fprintf(&sb, " | 🟢 %d instaladas", s.Installed)
	}
	if s.Degraded > 0 {
		fmt.Fprintf(&sb, " | 🟡 %d degradadas", s.Degraded)
	}
	if s.Error > 0 {
		fmt.Fprintf(&sb, " | 🔴 %d error", s.Error)
	}
	if s.Paused > 0 {
		fmt.Fprintf(&sb, " | ⏸️ %d pausadas", s.Paused)
	}
	if s.Pending > 0 {
		fmt.Fprintf(&sb, " | ⬜ %d pendientes", s.Pending)
	}
	if s.WithDrift > 0 {
		fmt.Fprintf(&sb, " | ⚠️ %d con drift", s.WithDrift)
	}
	if s.Unhealthy > 0 {
		fmt.Fprintf(&sb, " | 🔴 %d unhealthy", s.Unhealthy)
	}
	fmt.Fprintf(&sb, "\nGenerado: %s\n", s.GeneratedAt.Format("2006-01-02 15:04:05"))
	return sb.String()
}
