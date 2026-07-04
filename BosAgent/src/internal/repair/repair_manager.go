package repair

import (
	"fmt"
	"time"

	"bos/internal/state"

	"log/slog"
)

// Target especifica qué capas reparar (all, os, k8s, bos).
type Target string

const (
	TargetAll Target = "all"
	TargetOS  Target = "os"
	TargetK8s Target = "k8s"
	TargetBOS Target = "bos"
)

// ManagerResult contiene el resultado completo de la reparación a través de todas las fases.
type ManagerResult struct {
	Target   Target
	DryRun   bool
	Success  bool
	Phases   []PhaseResult
	Verify   *HealthVerifyResult
	Duration time.Duration
	Error    string
}

// PhaseResult contiene el resultado de una fase individual de reparación.
type PhaseResult struct {
	Phase   string
	Success bool
	Steps   []RepairStep
	Error   string
	Elapsed time.Duration
}

// BOSFichaRepairer defines the contract for BOS-layer ficha repair.
// Implemented by the installer orchestrator (via Saga Repair method).
type BOSFichaRepairer interface {
	Repair(fichaID string) (success bool, steps []RepairStep, err error)
}

// RepairManager orquesta la reparación multicapa (Fase B — D1):
//
//	Fase 1 — Ubuntu:    dpkg audit → apt --fix-broken → reset de unidades fallidas.
//	Fase 2 — K8s:       cordon → drain → restart kubelet → uncordon.
//	Fase 3 — BOS:       reconcile state file → saga repair por ficha degradada.
//	Fase 4 — Verificar: dpkg clean → nodos Ready → pods Running → fichas HEALTHY.
//
// Thread safety: no concurrent — una reparación a la vez.
// timeout: duración máxima total; 10min si se pasa 0.
type RepairManager struct {
	osRepairer  *OSRepairer
	k8sRepairer *K8sNodeRepairer
	verifier    *HealthVerifier
	stateMgr    *state.Manager
	bosRepairer BOSFichaRepairer
	timeout     time.Duration
	dryRun      bool
	logger      *slog.Logger
}

// NewRepairManager crea un manager de reparación multicapa.
//
// Recibe:
//   - stateMgr: *state.Manager — STATE_MANAGER para leer/escribir estados de fichas.
//   - bosRepairer: BOSFichaRepairer — implementación del repair saga (installer.Orchestrator).
//   - timeout: time.Duration — timeout total; 0 = 10min.
//   - dryRun: bool — si true, solo reporta sin ejecutar.
//   - logger: *slog.Logger.
//
// Callers conocidos:
//   - cmd/bosctl/app.go — subcomando "bosctl repair".
//   - internal/server/ws.go — handler "ficha_repair" (target=all).
func NewRepairManager(stateMgr *state.Manager, bosRepairer BOSFichaRepairer, timeout time.Duration, dryRun bool, logger *slog.Logger) *RepairManager {
	if timeout == 0 {
		timeout = 10 * time.Minute
	}
	return &RepairManager{
		osRepairer:  NewOSRepairer(dryRun, logger),
		k8sRepairer: NewK8sNodeRepairer(dryRun, logger),
		verifier:    NewHealthVerifier(logger),
		stateMgr:    stateMgr,
		bosRepairer: bosRepairer,
		timeout:     timeout,
		dryRun:      dryRun,
		logger:      logger,
	}
}

// Run ejecuta la secuencia de reparación multicapa para el target especificado.
//
// Recibe:
//   - target: Target — "all" | "os" | "k8s" | "bos". Error descriptivo si es inválido.
//
// Retorna: *ManagerResult con todas las fases, verificación y duración total.
//
// Efectos secundarios:
//   - Según target: ejecuta apt, kubectl, systemctl, y/o sagas de fichas.
//   - Escribe transiciones de estado en .sbos_state.json (Fase 3).
//   - NUNCA registrar contraseñas ni tokens en logs.
//
// Estándares: SBOS-018 §Day-2 Reconciliación 3 capas.
func (m *RepairManager) Run(target Target) *ManagerResult {
	result := &ManagerResult{
		Target: target,
		DryRun: m.dryRun,
		Phases: make([]PhaseResult, 0, 4),
	}
	start := time.Now()

	switch target {
	case TargetAll:
		m.runPhaseOS(result)
		m.runPhaseK8s(result)
		m.runPhaseBOS(result)
		m.runPhaseVerify(result)

	case TargetOS:
		m.runPhaseOS(result)
		m.runPhaseVerify(result) // verify OS only

	case TargetK8s:
		m.runPhaseK8s(result)
		m.runPhaseVerify(result)

	case TargetBOS:
		m.runPhaseBOS(result)
		m.runPhaseVerify(result)

	default:
		result.Error = fmt.Sprintf("unknown repair target: %s (valid: all, os, k8s, bos)", target)
		return result
	}

	result.Duration = time.Since(start)
	result.Success = true
	for _, p := range result.Phases {
		if p.Phase != "verify" && !p.Success {
			result.Success = false
			break
		}
	}
	return result
}

func (m *RepairManager) runPhaseOS(result *ManagerResult) {
	m.logger.Info("repair phase 1/4: Ubuntu OS repair", "dry_run", m.dryRun)
	phase := PhaseResult{Phase: "ubuntu-os"}
	phaseStart := time.Now()

	osResult := m.osRepairer.Repair()
	phase.Steps = osResult.Steps
	phase.Success = osResult.Success
	phase.Elapsed = time.Since(phaseStart)
	if !osResult.Success {
		phase.Error = "Ubuntu repair had failures"
	}
	result.Phases = append(result.Phases, phase)
	m.logger.Info("repair phase 1/4: Ubuntu OS done", "success", phase.Success, "elapsed", phase.Elapsed)
}

func (m *RepairManager) runPhaseK8s(result *ManagerResult) {
	m.logger.Info("repair phase 2/4: K8s node repair", "dry_run", m.dryRun)
	phase := PhaseResult{Phase: "k8s-node"}
	phaseStart := time.Now()

	k8sResult := m.k8sRepairer.Repair()
	phase.Steps = k8sResult.Steps
	phase.Success = k8sResult.Success
	phase.Elapsed = time.Since(phaseStart)
	if !k8sResult.Success {
		phase.Error = "K8s node repair had failures"
	}
	result.Phases = append(result.Phases, phase)
	m.logger.Info("repair phase 2/4: K8s node done", "success", phase.Success, "elapsed", phase.Elapsed)
}

func (m *RepairManager) runPhaseBOS(result *ManagerResult) {
	m.logger.Info("repair phase 3/4: BOS ficha reconciliation", "dry_run", m.dryRun)
	phase := PhaseResult{Phase: "bos-fichas"}
	phaseStart := time.Now()

	st, err := m.stateMgr.Read()
	if err != nil {
		phase.Error = fmt.Sprintf("cannot read state: %v", err)
		phase.Success = false
		result.Phases = append(result.Phases, phase)
		m.logger.Error("repair phase 3/4: BOS state read failed", "err", err)
		return
	}

	var repairSteps []RepairStep

	// Repair each degraded ficha
	for name, ficha := range st.Fichas {
		if ficha.State == state.StateDegradada || ficha.State == state.StateErrorLogico {
			m.logger.Info("repair phase 3: repairing ficha", "ficha", name, "state", string(ficha.State))

			if m.dryRun {
				repairSteps = append(repairSteps, RepairStep{
					Action: fmt.Sprintf("repair-ficha-%s", name),
					Status: "dry_run",
					Output: fmt.Sprintf("Would repair: %s (state=%s)", name, ficha.State),
				})
				continue
			}

			// Transition to REPARANDO
			if ficha.State != state.StateReparando {
				_ = m.stateMgr.Transition(name, state.StateReparando)
			}

			if m.bosRepairer != nil {
				ok, steps, err := m.bosRepairer.Repair(name)
				repairSteps = append(repairSteps, steps...)
				if err != nil || !ok {
					m.logger.Warn("repair phase 3: ficha repair failed — reverting to ALERTA", "ficha", name, "err", err)
					_ = m.stateMgr.Transition(name, state.StateDegradada)
					repairSteps = append(repairSteps, RepairStep{
						Action: fmt.Sprintf("repair-ficha-%s", name),
						Status: "fail",
						Error:  fmt.Sprintf("repair failed: %v", err),
					})
				} else {
					_ = m.stateMgr.Transition(name, state.StateInstalada)
					m.logger.Info("repair phase 3: ficha repaired OK", "ficha", name)
				}
			}
		}
	}

	if len(repairSteps) == 0 && !m.dryRun {
		repairSteps = append(repairSteps, RepairStep{
			Action: "bos-all-fichas",
			Status: "ok",
			Output: "no degraded fichas found",
		})
	}

	phase.Steps = repairSteps
	phase.Success = true
	for _, s := range repairSteps {
		if s.Status == "fail" {
			phase.Success = false
			break
		}
	}
	phase.Elapsed = time.Since(phaseStart)
	result.Phases = append(result.Phases, phase)
	m.logger.Info("repair phase 3/4: BOS fichas done", "success", phase.Success, "elapsed", phase.Elapsed)
}

func (m *RepairManager) runPhaseVerify(result *ManagerResult) {
	m.logger.Info("repair phase 4/4: post-repair verification")
	verifyResult := m.verifier.VerifyAll()
	result.Verify = verifyResult
	m.logger.Info("repair phase 4/4: verification complete", "all_pass", verifyResult.Success, "elapsed", verifyResult.Duration)
}
