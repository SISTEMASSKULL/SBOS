// Package ficha — Ejecutor de 5 fases (F11.A.4).
// BOS-REPAIR Plan Maestro v3.
//
// Pipeline canónico de instalación de cualquier ficha SBOS:
//
//	pre_install → install → post_install → verify → commit
//
// Cada fase invoca la función correspondiente en task_catalog.sh y parsea
// las señales __SBOS__STEP_START__/OK/FAIL/SKIP emitidas por el script.
//
// Políticas de fallo:
//   - abort: detiene el pipeline inmediatamente (default para pre_install, install, verify)
//   - continue: registra el fallo y prosigue (default para post_install)
//
// Timeouts por fase (configurables, defaults de F11.G.3):
//   - pre_install:  2 min
//   - install:      5 min (K8s) / 10 min (DB) / 2 min (daemon)
//   - post_install: 3 min
//   - verify:       2 min
//   - commit:       1 min
//
// Eventos: cada fase emite un PhaseEvent que se transmite vía WebSocket al TUI
// (DTC-04) y se registra en audit_log (ISO 27001 A.8.15).
package ficha

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os/exec"
	"strings"
	"sync"
	"time"

	"log/slog"
)

// ── Tipos ────────────────────────────────────────────────────────────

// Phase representa una de las 5 fases del pipeline de instalación.
type Phase string

const (
	PhasePreInstall  Phase = "pre_install"
	PhaseInstall     Phase = "install"
	PhasePostInstall Phase = "post_install"
	PhaseVerify      Phase = "verify"
	PhaseCommit      Phase = "commit"
)

// PhaseOrder retorna las 5 fases en orden canónico de ejecución.
func PhaseOrder() []Phase {
	return []Phase{PhasePreInstall, PhaseInstall, PhasePostInstall, PhaseVerify, PhaseCommit}
}

// OnFailure define la política ante fallo de una fase.
type OnFailure string

const (
	OnFailureAbort    OnFailure = "abort"    // detener el pipeline
	OnFailureContinue OnFailure = "continue" // registrar fallo y seguir
)

// PhaseConfig define la configuración de ejecución de una fase.
type PhaseConfig struct {
	Phase    Phase
	Timeout  time.Duration
	OnFail   OnFailure
}

// DefaultPhaseConfigs retorna la configuración por defecto para las 5 fases.
// Los timeouts siguen F11.G.3 — ajustables por tipo de ficha.
func DefaultPhaseConfigs(workloadType string) []PhaseConfig {
	timeouts := defaultPhaseTimeouts(workloadType)
	return []PhaseConfig{
		{Phase: PhasePreInstall, Timeout: timeouts.preInstall, OnFail: OnFailureAbort},
		{Phase: PhaseInstall, Timeout: timeouts.install, OnFail: OnFailureAbort},
		{Phase: PhasePostInstall, Timeout: timeouts.postInstall, OnFail: OnFailureContinue},
		{Phase: PhaseVerify, Timeout: timeouts.verify, OnFail: OnFailureAbort},
		{Phase: PhaseCommit, Timeout: timeouts.commit, OnFail: OnFailureAbort},
	}
}

type phaseTimeouts struct {
	preInstall  time.Duration
	install     time.Duration
	postInstall time.Duration
	verify      time.Duration
	commit      time.Duration
}

// defaultPhaseTimeouts retorna los timeouts por fase delegando en DefaultTimeoutFor
// (timeouts.go), que es la fuente única de verdad para timeouts por tipo de workload.
// Esto elimina la duplicación que existía entre executor.go y timeouts.go.
func defaultPhaseTimeouts(workloadType string) phaseTimeouts {
	cfg := DefaultTimeoutFor(workloadType)
	return phaseTimeouts{
		preInstall:  cfg.PreInstall,
		install:     cfg.Install,
		postInstall: cfg.PostInstall,
		verify:      cfg.Verify,
		commit:      cfg.Commit,
	}
}

// ── Resultados ────────────────────────────────────────────────────────

// PhaseResult contiene el resultado de ejecutar una fase.
type PhaseResult struct {
	Phase      Phase         `json:"phase"`
	Status     string        `json:"status"` // "ok", "fail", "skip", "timeout"
	Duration   time.Duration `json:"duration"`
	Output     string        `json:"output"`
	Error      string        `json:"error,omitempty"`
	ExitCode   int           `json:"exit_code"`
	Steps      []string      `json:"steps"` // pasos ejecutados dentro de la fase
}

// ExecutionResult contiene el resultado completo de la ejecución del pipeline.
type ExecutionResult struct {
	FichaID  string        `json:"ficha_id"`
	Command  string        `json:"command"` // install, update, repair, remove
	Success  bool          `json:"success"`
	Phases   []PhaseResult `json:"phases"`
	Duration time.Duration `json:"duration"`
	Error    string        `json:"error,omitempty"`
}

// ── Observador de fases ───────────────────────────────────────────────

// PhaseObserver es llamado al inicio y fin de cada fase.
// Usado por el TUI para mostrar progreso en tiempo real (DTC-04).
type PhaseObserver func(event PhaseEvent)

// PhaseEvent representa un evento de ciclo de vida de una fase.
type PhaseEvent struct {
	FichaID   string    `json:"ficha_id"`
	Phase     Phase     `json:"phase"`
	Event     string    `json:"event"` // "started", "completed", "failed", "skipped", "timeout"
	Message   string    `json:"message"`
	Timestamp time.Time `json:"timestamp"`
}

// ── Ejecutor ──────────────────────────────────────────────────────────

// Executor ejecuta el pipeline de 5 fases para una ficha.
// Invoca task_catalog.sh para cada fase y parsea las señales __SBOS__.
type Executor struct {
	phases   []PhaseConfig
	observer PhaseObserver
	logger   *slog.Logger
}

// NewExecutor crea un ejecutor con la configuración de fases dada.
func NewExecutor(phases []PhaseConfig, observer PhaseObserver, logger *slog.Logger) *Executor {
	if len(phases) == 0 {
		phases = DefaultPhaseConfigs("")
	}
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	return &Executor{phases: phases, observer: observer, logger: logger}
}

// Execute ejecuta el pipeline completo para una ficha y comando dados.
// command: "install", "update", "repair", "remove"
// taskDir: ruta al directorio de la ficha (contiene task_catalog.sh)
func (e *Executor) Execute(fichaID, command, taskDir string) (*ExecutionResult, error) {
	start := time.Now()
	result := &ExecutionResult{
		FichaID: fichaID,
		Command: command,
		Phases:  make([]PhaseResult, 0, len(e.phases)),
	}

	e.logger.Info("ejecutando pipeline de fases",
		"ficha", fichaID,
		"command", command,
		"phases", len(e.phases),
		"task_dir", taskDir,
	)

	for _, cfg := range e.phases {
		// Emitir evento de inicio de fase
		e.emit(PhaseEvent{
			FichaID:   fichaID,
			Phase:     cfg.Phase,
			Event:     "started",
			Timestamp: time.Now(),
		})

		e.logger.Debug("fase iniciada", "ficha", fichaID, "phase", cfg.Phase, "timeout", cfg.Timeout)

		// Ejecutar la fase con timeout
		phaseResult := e.runPhase(fichaID, command, taskDir, cfg)
		phaseResult.Phase = cfg.Phase
		result.Phases = append(result.Phases, phaseResult)

		// Emitir evento según resultado
		event := PhaseEvent{
			FichaID:   fichaID,
			Phase:     cfg.Phase,
			Timestamp: time.Now(),
		}
		switch phaseResult.Status {
		case "ok":
			event.Event = "completed"
			event.Message = fmt.Sprintf("%s completado (%v)", cfg.Phase, phaseResult.Duration)
		case "skip":
			event.Event = "skipped"
			event.Message = fmt.Sprintf("%s omitido", cfg.Phase)
		case "timeout":
			event.Event = "timeout"
			event.Message = fmt.Sprintf("%s excedió timeout de %v", cfg.Phase, cfg.Timeout)
		case "fail":
			event.Event = "failed"
			event.Message = phaseResult.Error
		}
		e.emit(event)

		// Manejar fallo según política
		if phaseResult.Status == "fail" || phaseResult.Status == "timeout" {
			if cfg.OnFail == OnFailureAbort {
				result.Error = fmt.Sprintf("fase %s falló: %s", cfg.Phase, phaseResult.Error)
				result.Success = false
				result.Duration = time.Since(start)
				e.logger.Error("pipeline abortado",
					"ficha", fichaID,
					"phase", cfg.Phase,
					"status", phaseResult.Status,
					"error", phaseResult.Error,
				)
				return result, nil
			}
			e.logger.Warn("fase falló pero pipeline continúa",
				"ficha", fichaID,
				"phase", cfg.Phase,
				"status", phaseResult.Status,
			)
		}
	}

	result.Success = true
	result.Duration = time.Since(start)
	e.logger.Info("pipeline completado",
		"ficha", fichaID,
		"success", result.Success,
		"duration", result.Duration,
		"phases_ok", countByStatus(result.Phases, "ok"),
	)
	return result, nil
}

// runPhase ejecuta una fase individual llamando a task_catalog.sh.
func (e *Executor) runPhase(fichaID, command, taskDir string, cfg PhaseConfig) PhaseResult {
	start := time.Now()
	result := PhaseResult{Status: "fail"}

	// Construir script que invoca la función específica de la fase
	script := buildPhaseScript(string(cfg.Phase), fichaID, command, taskDir)

	ctx, cancel := context.WithTimeout(context.Background(), cfg.Timeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, "bash", "-c", script)
	cmd.Dir = taskDir

	// Conectar stdout para parsear señales __SBOS__
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		result.Error = fmt.Sprintf("pipe stdout: %v", err)
		result.Duration = time.Since(start)
		return result
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		result.Error = fmt.Sprintf("pipe stderr: %v", err)
		result.Duration = time.Since(start)
		return result
	}

	if err := cmd.Start(); err != nil {
		result.Error = fmt.Sprintf("iniciar fase %s: %v", cfg.Phase, err)
		result.Duration = time.Since(start)
		return result
	}

	// C-03: leer stdout y stderr concurrentemente para evitar deadlock de pipe
	// (buffer kernel 64KB — lectura secuencial bloquea si stderr se llena mientras stdout no termina)
	var (
		steps      []string
		output     string
		stderrData []byte
	)
	var pipeWg sync.WaitGroup
	pipeWg.Add(2)
	go func() {
		defer pipeWg.Done()
		steps, output = parsePhaseSignals(stdout)
	}()
	go func() {
		defer pipeWg.Done()
		stderrData, _ = io.ReadAll(stderr)
	}()
	pipeWg.Wait()

	if err := cmd.Wait(); err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			result.Status = "timeout"
			result.Error = fmt.Sprintf("timeout después de %v", cfg.Timeout)
			result.Duration = time.Since(start)
			return result
		}
		if exitErr, ok := err.(*exec.ExitError); ok {
			result.ExitCode = exitErr.ExitCode()
		} else {
			result.ExitCode = 1
		}
		// Si el comando falló pero tenemos pasos, verificar si fue skip
		if result.ExitCode == 2 {
			// Convención: exit code 2 = skip (idempotente, ya instalado)
			result.Status = "skip"
			result.Output = string(stderrData)
			result.Duration = time.Since(start)
			return result
		}
		result.Error = fmt.Sprintf("%s: %s", err.Error(), string(stderrData))
		result.Status = "fail"
		result.Output = output
		result.Duration = time.Since(start)
		return result
	}

	result.Status = "ok"
	result.ExitCode = 0
	result.Output = output
	result.Steps = steps
	result.Duration = time.Since(start)
	return result
}

// emit envía un evento de fase al observador registrado.
func (e *Executor) emit(event PhaseEvent) {
	if e.observer != nil {
		e.observer(event)
	}
	// TODO(ctx-plane): persistir audit_event en bkernel_db cuando F5 esté operativo
	// audit.LogPhaseEvent(event) — ISO 27001 A.8.15
}

// ── Construcción de script por fase ───────────────────────────────────

// buildPhaseScript construye un script bash que invoca la función
// correspondiente a la fase en task_catalog.sh.
//
// El script:
//  1. Define las señales __SBOS__STEP_*__ (igual que 00_MASTER_INSTALL_SBOS.sh)
//  2. Sourcea task_catalog.sh
//  3. Invoca la función de la fase (ficha_<phase> o fase genérica)
//  4. Emite señales de inicio/fin para que el parser Go las capture
func buildPhaseScript(phase, fichaID, command, taskDir string) string {
	taskCatalog := fmt.Sprintf("%s/task_catalog.sh", taskDir)

	// Construir el script que invoca la fase
	var sb strings.Builder
	sb.WriteString("#!/usr/bin/env bash\n")
	sb.WriteString("set -euo pipefail\n\n")

	// Señales (mismas constantes que usa 00_MASTER_INSTALL_SBOS.sh)
	sb.WriteString("export __SBOS__STEP_START__=\"__SBOS__STEP_START__\"\n")
	sb.WriteString("export __SBOS__STEP_OK__=\"__SBOS__STEP_OK__\"\n")
	sb.WriteString("export __SBOS__STEP_FAIL__=\"__SBOS__STEP_FAIL__\"\n")
	sb.WriteString("export __SBOS__STEP_SKIP__=\"__SBOS__STEP_SKIP__\"\n\n")

	// Variables de entorno que task_catalog.sh espera
	sb.WriteString(fmt.Sprintf("export FICHA_ID=\"%s\"\n", fichaID))
	sb.WriteString(fmt.Sprintf("export FICHA_COMMAND=\"%s\"\n", command))
	sb.WriteString(fmt.Sprintf("export FICHA_DIR=\"%s\"\n", taskDir))
	sb.WriteString(fmt.Sprintf("export FICHA_LOG=\"${FICHA_LOG:-/var/log/bos/fichas/%s.log}\"\n", fichaID))
	sb.WriteString("export KUBECONFIG_DEST=\"${KUBECONFIG_DEST:-/etc/bos/.kube/config}\"\n\n")

	// Sourcear helpers del core si existen
	sb.WriteString("# Sourcear task_catalog.sh de la ficha\n")
	sb.WriteString(fmt.Sprintf("if [[ -f \"%s\" ]]; then source \"%s\"; fi\n\n", taskCatalog, taskCatalog))

	// Invocar la función de la fase
	funcName := fmt.Sprintf("ficha_%s", phase)
	sb.WriteString(fmt.Sprintf("echo \"${__SBOS__STEP_START__} %s\"\n", phase))
	sb.WriteString(fmt.Sprintf("if declare -f %s > /dev/null 2>&1; then\n", funcName))
	sb.WriteString(fmt.Sprintf("    if %s; then\n", funcName))
	sb.WriteString(fmt.Sprintf("        echo \"${__SBOS__STEP_OK__} %s\"\n", phase))
	sb.WriteString("    else\n")
	sb.WriteString(fmt.Sprintf("        echo \"${__SBOS__STEP_FAIL__} %s\"\n", phase))
	sb.WriteString("        exit 1\n")
	sb.WriteString("    fi\n")
	sb.WriteString("else\n")
	// Si la función no existe, es skip (no aplica para esta ficha)
	sb.WriteString(fmt.Sprintf("    echo \"${__SBOS__STEP_SKIP__} %s (funcion no definida)\"\n", phase))
	sb.WriteString("    exit 0\n")
	sb.WriteString("fi\n")

	return sb.String()
}

// ── Parser de señales ─────────────────────────────────────────────────

// parsePhaseSignals lee stdout línea por línea y extrae las señales __SBOS__.
// Retorna los nombres de los pasos y el output completo.
func parsePhaseSignals(stdout io.Reader) (steps []string, output string) {
	var outBuilder strings.Builder
	scanner := bufio.NewScanner(stdout)
	for scanner.Scan() {
		line := scanner.Text()
		outBuilder.WriteString(line)
		outBuilder.WriteString("\n")

		switch {
		case strings.HasPrefix(line, "__SBOS__STEP_START__"):
			name := strings.TrimSpace(strings.TrimPrefix(line, "__SBOS__STEP_START__"))
			steps = append(steps, "▶ "+name)
		case strings.HasPrefix(line, "__SBOS__STEP_OK__"):
			name := strings.TrimSpace(strings.TrimPrefix(line, "__SBOS__STEP_OK__"))
			steps = append(steps, "✓ "+name)
		case strings.HasPrefix(line, "__SBOS__STEP_FAIL__"):
			name := strings.TrimSpace(strings.TrimPrefix(line, "__SBOS__STEP_FAIL__"))
			steps = append(steps, "✗ "+name)
		case strings.HasPrefix(line, "__SBOS__STEP_SKIP__"):
			name := strings.TrimSpace(strings.TrimPrefix(line, "__SBOS__STEP_SKIP__"))
			steps = append(steps, "○ "+name)
		}
	}
	return steps, outBuilder.String()
}

// ── Helpers ────────────────────────────────────────────────────────────

func countByStatus(phases []PhaseResult, status string) int {
	n := 0
	for _, p := range phases {
		if p.Status == status {
			n++
		}
	}
	return n
}

// FailedPhases retorna las fases que fallaron.
func (r *ExecutionResult) FailedPhases() []PhaseResult {
	var failed []PhaseResult
	for _, p := range r.Phases {
		if p.Status == "fail" || p.Status == "timeout" {
			failed = append(failed, p)
		}
	}
	return failed
}

// PhaseSummary retorna un resumen legible de la ejecución.
func (r *ExecutionResult) PhaseSummary() string {
	var sb strings.Builder
	fmt.Fprintf(&sb, "Pipeline %s %s (%v):\n", r.Command, r.FichaID, r.Duration)
	for _, p := range r.Phases {
		icon := "✓"
		switch p.Status {
		case "fail":
			icon = "✗"
		case "skip":
			icon = "○"
		case "timeout":
			icon = "⏰"
		}
		fmt.Fprintf(&sb, "  %s %-15s %s", icon, p.Phase, p.Duration)
		if p.Error != "" {
			fmt.Fprintf(&sb, " — %s", p.Error)
		}
		fmt.Fprintf(&sb, "\n")
	}
	return sb.String()
}
