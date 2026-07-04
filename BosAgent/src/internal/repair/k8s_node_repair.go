package repair

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"log/slog"
)

// K8sRepairResult holds the outcome of the K8s node repair phase.
type K8sRepairResult struct {
	Success  bool
	Steps    []RepairStep
	Duration time.Duration
}

// K8sNodeRepairer ejecuta reparación a nivel de nodo K8s.
// Secuencia: cordon → drain → restart kubelet → uncordon.
//
// Thread safety: una sola reparación a la vez — no es seguro para uso concurrente.
// El nodeName se obtiene de os.Hostname() al construir.
type K8sNodeRepairer struct {
	nodeName string
	dryRun   bool
	logger   *slog.Logger
}

// NewK8sNodeRepairer crea un reparador de nodo K8s para el hostname actual.
//
// Recibe:
//   - dryRun: bool — si true, solo reporta las acciones sin ejecutarlas.
//   - logger: *slog.Logger — logger del repair manager padre.
func NewK8sNodeRepairer(dryRun bool, logger *slog.Logger) *K8sNodeRepairer {
	nodeName, _ := os.Hostname()
	return &K8sNodeRepairer{nodeName: nodeName, dryRun: dryRun, logger: logger}
}

// Repair ejecuta la secuencia completa de reparación K8s del nodo actual.
//
// Retorna: *K8sRepairResult con el resultado de cada paso (cordon/drain/restart/uncordon).
//
// Callers conocidos:
//   - internal/repair/repair_manager.go:RepairManager.runPhaseK8s — Fase 2 de la reparación.
//
// Efectos secundarios:
//   - Ejecuta kubectl cordon/drain/uncordon sobre el nodo actual.
//   - Reinicia el servicio kubelet via systemctl.
//   - dryRun=true solo reporta las acciones previstas sin ejecutarlas.
func (r *K8sNodeRepairer) Repair() *K8sRepairResult {
	result := &K8sRepairResult{Steps: make([]RepairStep, 0)}
	start := time.Now()

	steps := []struct {
		name string
		fn   func() RepairStep
	}{
		{"k8s-cordon", r.repairCordon},
		{"k8s-drain", r.repairDrain},
		{"k8s-restart-kubelet", r.repairRestartKubelet},
		{"k8s-uncordon", r.repairUncordon},
	}

	for _, s := range steps {
		r.logger.Info("k8s repair: starting", "step", s.name, "node", r.nodeName)
		step := s.fn()
		step.Action = s.name
		result.Steps = append(result.Steps, step)
		if step.Status == "fail" {
			r.logger.Warn("k8s repair: failed", "step", s.name, "error", step.Error)
		} else {
			r.logger.Info("k8s repair: "+step.Status, "step", s.name, "elapsed", step.Elapsed)
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

func (r *K8sNodeRepairer) repairCordon() RepairStep {
	step := RepairStep{}
	start := time.Now()
	defer func() { step.Elapsed = time.Since(start) }()

	if r.dryRun {
		step.Status = "dry_run"
		step.Output = fmt.Sprintf("Would run: kubectl cordon %s", r.nodeName)
		return step
	}

	cmd := exec.Command("kubectl", "cordon", r.nodeName)
	out, err := cmd.CombinedOutput()
	step.Output = strings.TrimSpace(string(out))
	if err != nil {
		// Node might already be cordoned — not fatal
		if strings.Contains(step.Output, "already") || strings.Contains(step.Output, "SchedulingDisabled") {
			step.Status = "skip"
			return step
		}
		step.Status = "fail"
		step.Error = fmt.Sprintf("cordon %s: %v", r.nodeName, err)
		return step
	}
	step.Status = "ok"
	return step
}

func (r *K8sNodeRepairer) repairDrain() RepairStep {
	step := RepairStep{}
	start := time.Now()
	defer func() { step.Elapsed = time.Since(start) }()

	if r.dryRun {
		step.Status = "dry_run"
		step.Output = fmt.Sprintf("Would run: kubectl drain %s --ignore-daemonsets --delete-emptydir-data", r.nodeName)
		return step
	}

	args := []string{"drain", r.nodeName,
		"--ignore-daemonsets", "--delete-emptydir-data",
		"--grace-period=30", "--timeout=120s", "--force"}
	cmd := exec.Command("kubectl", args...)
	out, err := cmd.CombinedOutput()
	step.Output = strings.TrimSpace(string(out))
	if err != nil {
		step.Status = "fail"
		step.Error = fmt.Sprintf("drain %s: %v", r.nodeName, err)
		return step
	}
	step.Status = "ok"
	return step
}

func (r *K8sNodeRepairer) repairRestartKubelet() RepairStep {
	step := RepairStep{}
	start := time.Now()
	defer func() { step.Elapsed = time.Since(start) }()

	if r.dryRun {
		step.Status = "dry_run"
		step.Output = "Would run: systemctl restart kubelet"
		return step
	}

	cmd := exec.Command("systemctl", "restart", "kubelet")
	out, err := cmd.CombinedOutput()
	step.Output = strings.TrimSpace(string(out))
	if err != nil {
		step.Status = "fail"
		step.Error = fmt.Sprintf("restart kubelet: %v", err)
		return step
	}
	// Wait for kubelet to be ready
	time.Sleep(5 * time.Second)
	step.Status = "ok"
	return step
}

func (r *K8sNodeRepairer) repairUncordon() RepairStep {
	step := RepairStep{}
	start := time.Now()
	defer func() { step.Elapsed = time.Since(start) }()

	if r.dryRun {
		step.Status = "dry_run"
		step.Output = fmt.Sprintf("Would run: kubectl uncordon %s", r.nodeName)
		return step
	}

	cmd := exec.Command("kubectl", "uncordon", r.nodeName)
	out, err := cmd.CombinedOutput()
	step.Output = strings.TrimSpace(string(out))
	if err != nil {
		step.Status = "fail"
		step.Error = fmt.Sprintf("uncordon %s: %v", r.nodeName, err)
		return step
	}
	step.Status = "ok"
	return step
}

// IsK8sAvailable verifica si kubectl puede alcanzar el apiserver del cluster.
// Ejecuta kubectl get nodes --no-headers y retorna true si no hay error.
func IsK8sAvailable() bool {
	cmd := exec.Command("kubectl", "get", "nodes", "--no-headers")
	return cmd.Run() == nil
}
