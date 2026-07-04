// Package ficha — Reconciliador automático (F11.D.3).
// BOS-REPAIR Plan Maestro v3.
//
// El reconciliador ejecuta un ciclo cada 5 minutos que:
//  1. Detecta drift comparando hashes declarados vs estado real (DriftDetector)
//  2. Ejecuta health checks en todas las fichas (HealthChecker)
//  3. Aplica la política configurada por ficha para decidir la acción
//
// Políticas de reconciliación (por ficha, configurable en manifest.yml):
//   - autonomous:      repara automáticamente sin intervención humana
//   - recommend:        notifica el drift/fallo pero no actúa (default)
//   - block_and_alert:  bloquea la ficha y escala a HITL (requiere 2 admins)
//
// El ciclo de reconciliación:
//   drift detectado → health check → política decide →
//     autonomous → Executor.Repair() → verify → INSTALADA o ERROR_NO_CORREGIBLE
//     recommend  → log + notificar → ficha sigue DEGRADADA
//     block_and_alert → 🚨 HITL → espera confirmación humana
//
// Estándares: ADR-021 (18 estados), SBOS-019 §13 (governance),
// ISO 27001 A.8.15 (audit_events), CIS Benchmark v8 §4.1.
package ficha

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"log/slog"
)

// ── Políticas ─────────────────────────────────────────────────────────

// ReconcilePolicy define la acción automática ante drift o fallo de health.
type ReconcilePolicy string

const (
	// PolicyAutonomous: repara automáticamente sin preguntar.
	// Para fichas no críticas o entornos de desarrollo.
	PolicyAutonomous ReconcilePolicy = "autonomous"

	// PolicyRecommend: notifica el problema pero no actúa.
	// Default para la mayoría de fichas. El operador decide.
	PolicyRecommend ReconcilePolicy = "recommend"

	// PolicyBlockAndAlert: bloquea y escala a HITL.
	// Para fichas críticas (postgresql, keycloak, vault).
	// Requiere confirmación de 2 administradores (F11.F.5).
	PolicyBlockAndAlert ReconcilePolicy = "block_and_alert"
)

// DefaultPolicy retorna la política por defecto para una ficha.
// Las fichas críticas usan block_and_alert, el resto recommend.
func DefaultPolicy(critical bool) ReconcilePolicy {
	if critical {
		return PolicyBlockAndAlert
	}
	return PolicyRecommend
}

// ── Tipos ─────────────────────────────────────────────────────────────

// ReconcileAction describe la acción tomada (o recomendada) por el reconciliador.
type ReconcileAction struct {
	FichaID   string          `json:"ficha_id"`
	Policy    ReconcilePolicy `json:"policy"`
	Trigger   string          `json:"trigger"` // "drift", "health_failure", "both"
	Action    string          `json:"action"`   // "repair", "notify", "block", "none"
	Reason    string          `json:"reason"`
	AutoRepair bool           `json:"auto_repair"` // true si se ejecutó repair automático
	Timestamp  time.Time      `json:"timestamp"`
}

// ReconcileResult contiene el resultado de un ciclo de reconciliación.
type ReconcileResult struct {
	CycleID     string            `json:"cycle_id"`
	StartedAt   time.Time         `json:"started_at"`
	Duration    time.Duration     `json:"duration"`
	TotalFichas int               `json:"total_fichas"`
	Drifted     int               `json:"drifted"`
	Unhealthy   int               `json:"unhealthy"`
	Actions     []ReconcileAction `json:"actions"`
}

// ── Reconciliador ─────────────────────────────────────────────────────

// DataProvider alimenta al Reconciler con los datos necesarios para cada ciclo.
// Retorna el mapa de fichas para drift detection y el mapa de health definitions.
// Inyectado por el servidor gRPC o CLI al inicializar el Reconciler.
type DataProvider func() (fichas map[string]DriftInput, healthDefs map[string]HealthDef)

// Reconciler ejecuta ciclos periódicos de reconciliación.
// Integra DriftDetector, HealthChecker y Executor en un solo pipeline.
type Reconciler struct {
	driftDetector *DriftDetector
	healthChecker *HealthChecker
	executor      *Executor

	dataProvider DataProvider                 // proveedor de datos para runCycle()
	policies     map[string]ReconcilePolicy   // ficha_id → política (poblado desde manifest)
	interval     time.Duration
	logger       *slog.Logger

	// Observer llamado tras cada acción de reconciliación
	observer func(action ReconcileAction)
}

// NewReconciler crea un reconciliador.
// executor puede ser nil si no se desea auto-repair.
func NewReconciler(
	drift *DriftDetector,
	health *HealthChecker,
	exec *Executor,
	interval time.Duration,
	logger *slog.Logger,
) *Reconciler {
	if interval <= 0 {
		interval = 5 * time.Minute
	}
	if logger == nil {
		logger = slog.Default()
	}
	return &Reconciler{
		driftDetector: drift,
		healthChecker: health,
		executor:      exec,
		policies:      make(map[string]ReconcilePolicy),
		interval:      interval,
		logger:        logger,
	}
}

// SetDataProvider inyecta el proveedor de datos para que runCycle() pueda obtener
// fichas reales del catálogo. Sin esto, runCycle() es no-op.
func (r *Reconciler) SetDataProvider(provider DataProvider) {
	r.dataProvider = provider
}

// SetPolicy establece la política de reconciliación para una ficha.
func (r *Reconciler) SetPolicy(fichaID string, policy ReconcilePolicy) {
	r.policies[fichaID] = policy
}

// GetPolicy retorna la política para una ficha (recommend si no está configurada).
func (r *Reconciler) GetPolicy(fichaID string) ReconcilePolicy {
	if policy, ok := r.policies[fichaID]; ok {
		return policy
	}
	return PolicyRecommend
}

// SetObserver registra un callback llamado tras cada acción de reconciliación.
func (r *Reconciler) SetObserver(obs func(action ReconcileAction)) {
	r.observer = obs
}

// Run ejecuta el ciclo de reconciliación en un loop infinito.
// Bloquea hasta que el contexto se cancela.
func (r *Reconciler) Run(ctx context.Context) {
	ticker := time.NewTicker(r.interval)
	defer ticker.Stop()

	r.logger.Info("reconciliador iniciado", "interval", r.interval)

	// Primer ciclo inmediato
	r.runCycle()

	for {
		select {
		case <-ctx.Done():
			r.logger.Info("reconciliador detenido")
			return
		case <-ticker.C:
			r.runCycle()
		}
	}
}

// ReconcileNow ejecuta un ciclo único de reconciliación bajo demanda.
// Retorna el resultado para inspección (CLI, JSON-RPC, tests).
func (r *Reconciler) ReconcileNow(fichas map[string]DriftInput, healthDefs map[string]HealthDef) *ReconcileResult {
	return r.runCycleWithData(fichas, healthDefs)
}

// ── Ciclo interno ─────────────────────────────────────────────────────

// runCycle ejecuta un ciclo completo de reconciliación usando el DataProvider.
// Si no hay DataProvider configurado, registra el hecho y omite el ciclo.
func (r *Reconciler) runCycle() {
	if r.dataProvider == nil {
		r.logger.Debug("ciclo de reconciliación omitido — dataProvider no configurado")
		return
	}

	fichas, healthDefs := r.dataProvider()
	if len(fichas) == 0 && len(healthDefs) == 0 {
		r.logger.Debug("ciclo de reconciliación omitido — sin fichas que reconciliar")
		return
	}

	result := r.runCycleWithData(fichas, healthDefs)
	r.logger.Info("ciclo de reconciliación completado",
		"cycle", result.CycleID,
		"total", result.TotalFichas,
		"drifted", result.Drifted,
		"unhealthy", result.Unhealthy,
		"actions", len(result.Actions),
		"duration", result.Duration,
	)
}

func (r *Reconciler) runCycleWithData(fichas map[string]DriftInput, healthDefs map[string]HealthDef) *ReconcileResult {
	result := &ReconcileResult{
		CycleID:   fmt.Sprintf("rec-%d", time.Now().UnixNano()),
		StartedAt: time.Now(),
		Actions:   make([]ReconcileAction, 0),
	}

	// ── Fase 1: Detección de drift ─────────────────────────────────
	drifSummary := r.driftDetector.DetectAll(fichas)
	result.TotalFichas = drifSummary.TotalFichas
	result.Drifted = drifSummary.DriftedFichas

	// ── Fase 2: Health checks ────────────────────────────────────
	if r.healthChecker != nil {
		healthResults := r.healthChecker.CheckAll(healthDefs)
		for _, hr := range healthResults {
			if !hr.Healthy {
				result.Unhealthy++
			}
		}
	}

	// ── Fase 3: Decidir acciones según política ───────────────────
	var wg sync.WaitGroup
	var mu sync.Mutex

	for _, report := range drifSummary.Reports {
		if !report.HasDrift {
			continue
		}

		policy := r.GetPolicy(report.FichaID)
		action := r.decideAction(report.FichaID, policy, "drift", &report)

		mu.Lock()
		result.Actions = append(result.Actions, action)
		mu.Unlock()

		// Auto-repair en goroutine si la política es autonomous
		if action.AutoRepair && r.executor != nil {
			wg.Add(1)
			go func(fichaID, fichaPath string) {
				defer wg.Done()
				r.executeRepair(fichaID, fichaPath, &action)
			}(report.FichaID, report.FichaPath)
		}

		if r.observer != nil {
			r.observer(action)
		}
	}

	wg.Wait()
	result.Duration = time.Since(result.StartedAt)

	r.logger.Info("ciclo de reconciliación completado",
		"cycle", result.CycleID,
		"total", result.TotalFichas,
		"drifted", result.Drifted,
		"unhealthy", result.Unhealthy,
		"actions", len(result.Actions),
		"duration", result.Duration,
	)

	return result
}

// decideAction determina qué hacer ante drift o fallo de health.
func (r *Reconciler) decideAction(fichaID string, policy ReconcilePolicy, trigger string, report *DriftReport) ReconcileAction {
	action := ReconcileAction{
		FichaID:   fichaID,
		Policy:    policy,
		Trigger:   trigger,
		Timestamp: time.Now(),
	}

	switch policy {
	case PolicyAutonomous:
		action.Action = "repair"
		action.AutoRepair = true
		action.Reason = fmt.Sprintf("drift detectado en %s (%d items) — reparación automática",
			fichaID, countDrifted(report))

	case PolicyRecommend:
		action.Action = "notify"
		action.AutoRepair = false
		action.Reason = fmt.Sprintf("drift detectado en %s — se recomienda reparación manual", fichaID)
		r.logger.Warn("drift requiere atención",
			"ficha", fichaID,
			"policy", policy,
			"items", countDrifted(report),
		)

	case PolicyBlockAndAlert:
		action.Action = "block"
		action.AutoRepair = false
		action.Reason = fmt.Sprintf("🚨 %s es CRÍTICA — drift detectado, requiere HITL (2 admins)",
			fichaID)
		r.logger.Error("ficha crítica con drift — HITL requerido",
			"ficha", fichaID,
			"policy", policy,
			"items", countDrifted(report),
		)
		// TODO(ctx-plane): emitir alerta HITL cuando el Context Plane (F5) esté operativo

	default:
		action.Action = "none"
		action.Reason = fmt.Sprintf("política desconocida: %s", policy)
	}

	return action
}

// executeRepair ejecuta la reparación automática de una ficha.
func (r *Reconciler) executeRepair(fichaID, fichaPath string, action *ReconcileAction) {
	r.logger.Info("iniciando reparación automática", "ficha", fichaID)

	// TODO(F11.A.4): integrar con Executor.Execute() cuando resolveTaskDir funcione
	result, err := r.executor.Execute(fichaID, "repair", fichaPath)
	if err != nil {
		r.logger.Error("reparación automática falló",
			"ficha", fichaID,
			"err", err,
		)
		// TODO(F11.B.4): 3 reintentos → ERROR_NO_CORREGIBLE → HITL
		return
	}

	if result.Success {
		r.logger.Info("reparación automática exitosa",
			"ficha", fichaID,
			"duration", result.Duration,
		)
		action.AutoRepair = true
	} else {
		r.logger.Error("reparación automática falló",
			"ficha", fichaID,
			"error", result.Error,
			"phases", len(result.Phases),
		)
	}
}

// ── Helpers ────────────────────────────────────────────────────────────

func countDrifted(report *DriftReport) int {
	if report == nil {
		return 0
	}
	n := 0
	for _, item := range report.Items {
		if item.Status != DriftOK {
			n++
		}
	}
	return n
}

// ReconcileSummary genera un resumen legible del resultado de reconciliación.
func (r *ReconcileResult) Summary() string {
	var sb strings.Builder
	fmt.Fprintf(&sb, "Reconciliación %s (%v):\n", r.CycleID, r.Duration.Round(time.Millisecond))
	fmt.Fprintf(&sb, "  Fichas: %d total, %d con drift, %d unhealthy\n",
		r.TotalFichas, r.Drifted, r.Unhealthy)

	if len(r.Actions) == 0 {
		fmt.Fprintf(&sb, "  ✅ sin acciones requeridas\n")
		return sb.String()
	}

	fmt.Fprintf(&sb, "  Acciones:\n")
	for _, a := range r.Actions {
		icon := "🔧"
		switch a.Action {
		case "repair":
			icon = "🔧"
		case "notify":
			icon = "📢"
		case "block":
			icon = "🚨"
		}
		fmt.Fprintf(&sb, "  %s %s: %s — %s\n", icon, a.FichaID, a.Action, a.Reason)
	}
	return sb.String()
}
