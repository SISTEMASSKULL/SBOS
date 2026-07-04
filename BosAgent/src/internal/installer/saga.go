// Package installer implementa el patrón saga para operaciones del ciclo de vida de fichas.
// Cada saga (install/update/repair/remove) tiene una cadena de compensación explícita
// que se ejecuta ante fallos (Principios P6, P12).
//
// Las operaciones se ejecutan invocando 00_MASTER_INSTALL_SBOS.sh,
// parseando su protocolo de señales para observabilidad a nivel de paso.
package installer

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

// Signal constants matching the Bash engine protocol.
const (
	SignalStepStart   = "__SBOS__STEP_START__"
	SignalStepOK      = "__SBOS__STEP_OK__"
	SignalStepFail    = "__SBOS__STEP_FAIL__"
	SignalStepSkip    = "__SBOS__STEP_SKIP__"
	SignalCleanupDone = "__SBOS__CLEANUP_DONE__"
	SignalRollback    = "__SBOS__ROLLBACK_START__"
)

// Command representa una operación del ciclo de vida de una ficha.
type Command string

const (
	CmdInstall  Command = "install"
	CmdUpdate   Command = "update"
	CmdRepair   Command = "repair"
	CmdRemove   Command = "remove"
	CmdStatus   Command = "status"
	CmdProbe    Command = "probe"
	CmdShutdown Command = "shutdown"
)

// Step representa una fase individual dentro de una saga (nombre, estado, output).
type Step struct {
	Name    string
	FichaID string
	Status  string // "ok", "fail", "skip", "running"
	Output  string
	Error   string
}

// SagaResult contiene el resultado de una ejecución de saga.
//
// Thread safety: inmutable tras retorno de execute(); seguro para lectura concurrente.
type SagaResult struct {
	Command  string
	FichaID  string
	Success  bool
	Steps    []Step
	Duration time.Duration
	ExitCode int
}

// StepObserver es llamado para cada evento de paso durante la ejecución de una saga.
type StepObserver func(step Step)

// LogObserver es llamado por cada línea cruda del script Bash.
// Usado para streaming en tiempo real al TUI.
type LogObserver func(fichaID, line string)

// Orchestrator ejecuta comandos de ciclo de vida de fichas vía el motor Bash.
//
// Thread safety: execute() serializa las sagas con mu.Lock(). Llamadas
// concurrentes de Install/Repair desde goroutines distintas se encolan.
type Orchestrator struct {
	mu             sync.Mutex
	masterScript   string
	taskCatalog    string
	yamlEngine     string
	defaultTimeout time.Duration
	logger         *slog.Logger
	observer       StepObserver
	logObserver    LogObserver
	compensator    *Compensator
}

// NewOrchestrator crea un orquestador de sagas.
//
// Recibe:
//   - masterScript: string — ruta absoluta a 00_MASTER_INSTALL_SBOS.sh.
//   - coreDir: string — directorio core/ donde están los scripts de soporte.
//   - timeout: time.Duration — timeout por defecto para sagas (0 → 30min).
//   - logger: *slog.Logger — logger estructurado.
//
// Retorna: *Orchestrator listo para registrar observadores y ejecutar sagas.
//
// Callers conocidos:
//   - cmd/bos/main.go:runNormal — paso 3.
//
// Efectos secundarios: ninguno — solo inicialización.
func NewOrchestrator(masterScript, coreDir string, timeout time.Duration, logger *slog.Logger) *Orchestrator {
	if timeout == 0 {
		timeout = 30 * time.Minute
	}
	return &Orchestrator{
		masterScript:   masterScript,
		taskCatalog:    coreDir + "/00_TASK_CATALOG_SBOS.sh",
		yamlEngine:     coreDir + "/00_YAML_ENGINE_SBOS.sh",
		defaultTimeout: timeout,
		logger:         logger,
	}
}

// SetLogObserver registra un observador de líneas crudas para streaming al TUI.
//
// Efectos secundarios: sustituye logObserver; no requiere sincronización (se llama antes de Run()).
func (o *Orchestrator) SetLogObserver(obs LogObserver) {
	o.logObserver = obs
}

// SetObserver registra un observador de eventos Step para streaming en tiempo real.
//
// Efectos secundarios: sustituye observer; no requiere sincronización (se llama antes de Run()).
func (o *Orchestrator) SetObserver(obs StepObserver) {
	o.observer = obs
}

// SetCompensator conecta un compensador para rollback automático ante fallo de saga.
//
// Efectos secundarios: sustituye compensator; no requiere sincronización.
func (o *Orchestrator) SetCompensator(c *Compensator) {
	o.compensator = c
}

// timeoutForCommand returns the appropriate timeout for a command.
func (o *Orchestrator) TimeoutForCommand(cmd Command, cfg interface{ SagaTimeout(string) time.Duration }) time.Duration {
	return cfg.SagaTimeout(string(cmd))
}

// Install ejecuta la saga de instalación para una ficha.
//
// Recibe:
//   - fichaID: string — ID de la ficha (e.g. "postgresql").
//   - version: string — versión a instalar (e.g. "18.4").
//
// Retorna:
//   - *SagaResult — resultado con pasos, duración y exit code.
//   - error — si el script maestro no puede ejecutarse (no si falla la instalación).
//
// Callers conocidos:
//   - internal/observer/observer.go:tick — Fase 2.
//   - internal/domain/ficha_service.go — FichaService.Install.
//
// Efectos secundarios:
//   - Ejecuta 00_MASTER_INSTALL_SBOS.sh con timeout defaultTimeout.
//   - Si falla, activa la cadena de compensación del Compensator.
//
// Estándares: ADR-021 #3 (INSTALANDO), P6 (compensación).
func (o *Orchestrator) Install(fichaID, version string) (*SagaResult, error) {
	return o.execute(CmdInstall, fichaID, version)
}

// Update ejecuta la saga de actualización para una ficha.
//
// Efectos secundarios: igual que Install pero con comando "update". Activa compensación en fallo.
func (o *Orchestrator) Update(fichaID, version string) (*SagaResult, error) {
	return o.execute(CmdUpdate, fichaID, version)
}

// Repair ejecuta la saga de reparación (diagnosis_first per P14).
//
// Callers conocidos:
//   - internal/reconcile/scheduler.go — auto-repair por drift o health DEGRADED.
//   - internal/observer/observer.go — Fase 3 (repair de fichas DEGRADADA).
//
// Efectos secundarios: ejecuta 00_MASTER_INSTALL_SBOS.sh repair. Activa compensación en fallo.
func (o *Orchestrator) Repair(fichaID string) (*SagaResult, error) {
	return o.execute(CmdRepair, fichaID, "")
}

// Remove ejecuta la saga de eliminación tras verificaciones de gobernanza.
//
// Efectos secundarios: ejecuta 00_MASTER_INSTALL_SBOS.sh remove. Activa compensación en fallo.
func (o *Orchestrator) Remove(fichaID string) (*SagaResult, error) {
	return o.execute(CmdRemove, fichaID, "")
}

// Probe ejecuta un dry-run de la saga de instalación sin aplicar cambios.
//
// Efectos secundarios: ejecuta 00_MASTER_INSTALL_SBOS.sh probe (no modifica el sistema).
func (o *Orchestrator) Probe(fichaID string) (*SagaResult, error) {
	return o.execute(CmdProbe, fichaID, "")
}

// Status consulta el estado actual de una ficha (o todas si fichaID es vacío).
//
// Recibe:
//   - fichaID: string — ID de la ficha, o "" para todas.
//
// Retorna: output de texto del script maestro, trimmed.
//
// Efectos secundarios: ejecuta 00_MASTER_INSTALL_SBOS.sh status (solo lectura).
func (o *Orchestrator) Status(fichaID string) (string, error) {
	args := []string{o.masterScript, string(CmdStatus)}
	if fichaID != "" {
		args = append(args, fichaID)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "bash", args...)
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("installer: status %s: %w", fichaID, err)
	}
	return strings.TrimSpace(string(out)), nil
}

// ShutdownPhase represents one phase of the graceful shutdown sequence.
type ShutdownPhase struct {
	Name    string
	Elapsed time.Duration
	Err     error
}

// Shutdown executes the graceful K8s shutdown sequence (best-effort per phase).
// Phases: drain node → stop kubelet → stop containerd.
// Each phase has its own context timeout. Failures are logged and the next
// phase continues regardless.
func (o *Orchestrator) Shutdown(nodeName string) []ShutdownPhase {
	phases := make([]ShutdownPhase, 0, 3)

	// Phase 1: drain K8s node (120s timeout)
	phase1 := ShutdownPhase{Name: "drain-k8s-node"}
	start := time.Now()
	o.logger.Info("shutdown phase 1/3: draining K8s node", "node", nodeName)
	drainArgs := []string{"drain", nodeName,
		"--ignore-daemonsets", "--delete-emptydir-data",
		"--grace-period=30", "--timeout=120s", "--force"}
	phase1.Err = runCmd(120*time.Second, "kubectl", drainArgs...)
	phase1.Elapsed = time.Since(start)
	phases = append(phases, phase1)
	if phase1.Err != nil {
		o.logger.Warn("shutdown phase 1/3 FAILED — continuing", "err", phase1.Err, "elapsed", phase1.Elapsed)
	} else {
		o.logger.Info("shutdown phase 1/3 OK", "elapsed", phase1.Elapsed)
	}

	// Phase 2: stop kubelet (30s timeout)
	phase2 := ShutdownPhase{Name: "stop-kubelet"}
	start = time.Now()
	o.logger.Info("shutdown phase 2/3: stopping kubelet")
	phase2.Err = runCmd(30*time.Second, "systemctl", "stop", "kubelet")
	phase2.Elapsed = time.Since(start)
	phases = append(phases, phase2)
	if phase2.Err != nil {
		o.logger.Warn("shutdown phase 2/3 FAILED — continuing", "err", phase2.Err, "elapsed", phase2.Elapsed)
	} else {
		o.logger.Info("shutdown phase 2/3 OK", "elapsed", phase2.Elapsed)
	}

	// Phase 3: stop containerd (30s timeout)
	phase3 := ShutdownPhase{Name: "stop-containerd"}
	start = time.Now()
	o.logger.Info("shutdown phase 3/3: stopping containerd")
	phase3.Err = runCmd(30*time.Second, "systemctl", "stop", "containerd")
	phase3.Elapsed = time.Since(start)
	phases = append(phases, phase3)
	if phase3.Err != nil {
		o.logger.Warn("shutdown phase 3/3 FAILED", "err", phase3.Err, "elapsed", phase3.Elapsed)
	} else {
		o.logger.Info("shutdown phase 3/3 OK", "elapsed", phase3.Elapsed)
	}

	return phases
}

// runCmd executes a command with a context timeout and returns any error.
func runCmd(timeout time.Duration, name string, args ...string) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Stdout = nil // discard
	cmd.Stderr = nil
	return cmd.Run()
}

func (o *Orchestrator) execute(cmd Command, fichaID, version string) (*SagaResult, error) {
	o.mu.Lock()
	defer o.mu.Unlock()

	result := &SagaResult{
		Command: string(cmd),
		FichaID: fichaID,
		Steps:   make([]Step, 0),
	}

	args := []string{o.masterScript, string(cmd), fichaID}
	if version != "" {
		args = append(args, version)
	}

	o.logger.Info("saga starting", "command", string(cmd), "ficha", fichaID)

	ctx, cancel := context.WithTimeout(context.Background(), o.defaultTimeout)
	defer cancel()

	shellCmd := exec.CommandContext(ctx, "bash", args...)

	stdout, err := shellCmd.StdoutPipe()
	if err != nil {
		return nil, fmt.Errorf("installer: pipe stdout: %w", err)
	}
	stderr, err := shellCmd.StderrPipe()
	if err != nil {
		return nil, fmt.Errorf("installer: pipe stderr: %w", err)
	}

	start := time.Now()
	if err := shellCmd.Start(); err != nil {
		return nil, fmt.Errorf("installer: start %s: %w", string(cmd), err)
	}

	// Parse signal protocol from stdout
	o.parseOutput(stdout, stderr, result)

	if err := shellCmd.Wait(); err != nil {
		result.ExitCode = 1
		if exitErr, ok := err.(*exec.ExitError); ok {
			result.ExitCode = exitErr.ExitCode()
		}
	}

	result.Duration = time.Since(start)
	result.Success = result.ExitCode == 0

	if result.Success {
		o.logger.Info("saga completed successfully", "ficha", fichaID, "duration", result.Duration)
	} else {
		o.logger.Error("saga failed", "ficha", fichaID, "exit", result.ExitCode)
		// Execute compensation chain on failure
		if o.compensator != nil {
			chain := SelectChain(cmd)
			if len(chain.Actions) > 0 {
				o.logger.Warn("triggering compensation", "ficha", fichaID, "actions", len(chain.Actions))
				_ = o.compensator.Compensate(chain, fichaID, o.taskCatalog)
			}
		}
	}

	return result, nil
}

func (o *Orchestrator) parseOutput(stdout, stderr io.Reader, result *SagaResult) {
	var currentStep Step
	var errorLines []string

	// C-03: drenar stderr en goroutine paralela para evitar deadlock de pipe
	// (buffer kernel 64KB — si stderr se llena mientras stdout no termina, deadlock circular)
	var stderrData []byte
	var stderrWg sync.WaitGroup
	stderrWg.Add(1)
	go func() {
		defer stderrWg.Done()
		stderrData, _ = io.ReadAll(stderr)
	}()

	scanner := bufio.NewScanner(stdout)
	for scanner.Scan() {
		line := scanner.Text()

		switch {
		case strings.HasPrefix(line, SignalStepStart):
			// Flush previous step
			if currentStep.Name != "" {
				result.Steps = append(result.Steps, currentStep)
			}
			name := strings.TrimSpace(strings.TrimPrefix(line, SignalStepStart))
			currentStep = Step{Name: name, FichaID: result.FichaID, Status: "running"}
			o.logger.Debug("step started", "step", name)
			if o.observer != nil {
				o.observer(currentStep)
			}

		case strings.HasPrefix(line, SignalStepOK):
			if currentStep.Name != "" {
				currentStep.Status = "ok"
				result.Steps = append(result.Steps, currentStep)
				if o.observer != nil {
					o.observer(currentStep)
				}
				o.logger.Debug("step ok", "step", currentStep.Name)
				currentStep = Step{}
			}

		case strings.HasPrefix(line, SignalStepFail):
			if currentStep.Name != "" {
				currentStep.Status = "fail"
				currentStep.Error = strings.Join(errorLines, "\n")
				result.Steps = append(result.Steps, currentStep)
				if o.observer != nil {
					o.observer(currentStep)
				}
				o.logger.Warn("step failed", "step", currentStep.Name, "error", currentStep.Error)
				currentStep = Step{}
				errorLines = nil
			}

		case strings.HasPrefix(line, SignalStepSkip):
			if currentStep.Name != "" {
				currentStep.Status = "skip"
				result.Steps = append(result.Steps, currentStep)
				currentStep = Step{}
			}

		case strings.HasPrefix(line, SignalRollback):
			o.logger.Warn("rollback initiated", "ficha", result.FichaID)

		case strings.HasPrefix(line, SignalCleanupDone):
			o.logger.Info("cleanup complete", "ficha", result.FichaID)

		default:
			if currentStep.Name != "" {
				currentStep.Output += line + "\n"
			}
			if strings.Contains(strings.ToLower(line), "error") || strings.Contains(strings.ToLower(line), "fatal") {
				errorLines = append(errorLines, line)
			}
			// Emitir línea cruda al logObserver para streaming en tiempo real al TUI
			if o.logObserver != nil && line != "" {
				o.logObserver(result.FichaID, line)
			}
		}
	}

	// Flush last step if any
	if currentStep.Name != "" {
		currentStep.Status = "incomplete"
		result.Steps = append(result.Steps, currentStep)
	}

	// Esperar goroutine de stderr (ya drena concurrentemente con stdout)
	stderrWg.Wait()
	if len(stderrData) > 0 {
		result.Steps = append(result.Steps, Step{
			Name:   "stderr",
			Status: "output",
			Output: string(stderrData),
		})
	}
}

// FailedSteps retorna los pasos que fallaron o quedaron incompletos.
//
// Efectos secundarios: ninguno — función pura.
func (r *SagaResult) FailedSteps() []Step {
	var failed []Step
	for _, s := range r.Steps {
		if s.Status == "fail" || s.Status == "incomplete" {
			failed = append(failed, s)
		}
	}
	return failed
}

// StepSummary returns a human-readable summary of all steps.
func (r *SagaResult) StepSummary() string {
	var b strings.Builder
	fmt.Fprintf(&b, "Saga %s %s (%v):\n", r.Command, r.FichaID, r.Duration)
	for _, s := range r.Steps {
		icon := "✓"
		switch s.Status {
		case "fail":
			icon = "✗"
		case "skip":
			icon = "○"
		case "running", "incomplete":
			icon = "…"
		}
		fmt.Fprintf(&b, "  %s %s\n", icon, s.Name)
	}
	return b.String()
}
