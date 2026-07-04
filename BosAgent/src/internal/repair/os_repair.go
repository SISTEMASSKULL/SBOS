// Package repair implementa la reparación multi-capa unificada del SBOS (D1).
//
// Fase 1 — Reparación Ubuntu:
//
//	dpkg --audit → apt --fix-broken → systemctl restart services
//
// Todas las operaciones son idempotentes. El modo dry-run registra sin ejecutar.
package repair

import (
	"fmt"
	"os/exec"
	"strings"
	"time"

	"log/slog"
)

// OSRepairResult contiene el resultado de la fase de reparación Ubuntu.
type OSRepairResult struct {
	Success  bool
	Steps    []RepairStep
	Duration time.Duration
}

// RepairStep representa una acción individual dentro de una secuencia de reparación.
type RepairStep struct {
	Action  string
	Status  string // "ok", "fail", "skip", "dry_run"
	Output  string
	Error   string
	Elapsed time.Duration
}

// OSRepairer ejecuta la secuencia de reparación de Ubuntu/Debian a nivel de SO.
//
// Thread safety: no es seguro para uso concurrente; las sagas de reparación son secuenciales.
type OSRepairer struct {
	dryRun bool
	logger *slog.Logger
}

// NewOSRepairer crea un repairer de nivel SO.
//
// Recibe:
//   - dryRun: bool — si true, loguea acciones sin ejecutarlas.
//   - logger: *slog.Logger — logger estructurado.
func NewOSRepairer(dryRun bool, logger *slog.Logger) *OSRepairer {
	return &OSRepairer{dryRun: dryRun, logger: logger}
}

// Repair ejecuta la secuencia completa de reparación Ubuntu:
// dpkg-audit → apt-fix-broken → systemctl-reset-failed.
//
// Retorna: *OSRepairResult con pasos, duración y éxito general.
//
// Efectos secundarios:
//   - En modo normal: ejecuta dpkg, apt-get y systemctl.
//   - En modo dry-run: solo loguea las acciones que se ejecutarían.
//
// Estándares: P14 (diagnosis_first) — dpkg --audit como paso inicial.
func (r *OSRepairer) Repair() *OSRepairResult {
	result := &OSRepairResult{Steps: make([]RepairStep, 0)}
	start := time.Now()

	steps := []struct {
		name string
		fn   func() RepairStep
	}{
		{"dpkg-audit", r.repairDpkgAudit},
		{"apt-fix-broken", r.repairAptFixBroken},
		{"systemctl-reset-failed", r.repairSystemctlReset},
	}

	for _, s := range steps {
		r.logger.Info("os repair: starting", "step", s.name)
		step := s.fn()
		step.Action = s.name
		result.Steps = append(result.Steps, step)
		if step.Status == "fail" {
			r.logger.Warn("os repair: failed", "step", s.name, "error", step.Error)
		} else {
			r.logger.Info("os repair: "+step.Status, "step", s.name, "elapsed", step.Elapsed)
		}
	}

	result.Duration = time.Since(start)
	result.Success = true
	for _, s := range result.Steps {
		if s.Status == "fail" {
			result.Success = false
			break
		}
	}
	return result
}

func (r *OSRepairer) repairDpkgAudit() RepairStep {
	step := RepairStep{}
	start := time.Now()
	defer func() { step.Elapsed = time.Since(start) }()

	if r.dryRun {
		step.Status = "dry_run"
		step.Output = "Would run: dpkg --audit"
		return step
	}

	cmd := exec.Command("dpkg", "--audit")
	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))
	step.Output = output
	if err != nil {
		// dpkg --audit exits non-zero when broken packages found — that's expected
		if output != "" {
			step.Status = "ok"
			r.logger.Info("dpkg audit found issues (expected)", "output", output)
		} else {
			step.Status = "ok"
		}
	} else {
		step.Status = "ok"
	}
	return step
}

func (r *OSRepairer) repairAptFixBroken() RepairStep {
	step := RepairStep{}
	start := time.Now()
	defer func() { step.Elapsed = time.Since(start) }()

	if r.dryRun {
		step.Status = "dry_run"
		step.Output = "Would run: apt-get --fix-broken install -y"
		return step
	}

	cmd := exec.Command("apt-get", "--fix-broken", "install", "-y")
	out, err := cmd.CombinedOutput()
	step.Output = strings.TrimSpace(string(out))
	if err != nil {
		step.Status = "fail"
		step.Error = fmt.Sprintf("apt --fix-broken: %v", err)
		return step
	}
	step.Status = "ok"
	return step
}

func (r *OSRepairer) repairSystemctlReset() RepairStep {
	step := RepairStep{}
	start := time.Now()
	defer func() { step.Elapsed = time.Since(start) }()

	if r.dryRun {
		step.Status = "dry_run"
		step.Output = "Would run: systemctl reset-failed"
		return step
	}

	cmd := exec.Command("systemctl", "reset-failed")
	out, err := cmd.CombinedOutput()
	step.Output = strings.TrimSpace(string(out))
	if err != nil {
		// reset-failed exits 0 even when nothing to reset
		step.Status = "fail"
		step.Error = fmt.Sprintf("systemctl reset-failed: %v", err)
		return step
	}
	step.Status = "ok"
	return step
}

// RestartService restarts a systemd service if it's running.
func (r *OSRepairer) RestartService(name string) RepairStep {
	step := RepairStep{}
	start := time.Now()
	defer func() { step.Elapsed = time.Since(start) }()

	if r.dryRun {
		step.Status = "dry_run"
		step.Output = fmt.Sprintf("Would restart: %s", name)
		return step
	}

	// Check if service exists and is active
	active := exec.Command("systemctl", "is-active", name)
	if err := active.Run(); err != nil {
		step.Status = "skip"
		step.Output = fmt.Sprintf("service %s not active, skipping restart", name)
		return step
	}

	cmd := exec.Command("systemctl", "restart", name)
	out, err := cmd.CombinedOutput()
	step.Output = strings.TrimSpace(string(out))
	if err != nil {
		step.Status = "fail"
		step.Error = fmt.Sprintf("restart %s: %v", name, err)
		return step
	}
	step.Status = "ok"
	return step
}
