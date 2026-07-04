package repair

import (
	"fmt"
	"os/exec"
	"strings"
	"time"

	"log/slog"
)

// HealthVerifyResult holds post-repair verification results.
type HealthVerifyResult struct {
	Success  bool
	Checks   []HealthCheck
	Duration time.Duration
}

// HealthCheck represents a single post-repair health check.
type HealthCheck struct {
	Name   string
	Pass   bool
	Detail string
}

// HealthVerifier runs post-repair health verification across all layers.
type HealthVerifier struct {
	logger *slog.Logger
}

// NewHealthVerifier creates a health verifier.
func NewHealthVerifier(logger *slog.Logger) *HealthVerifier {
	return &HealthVerifier{logger: logger}
}

// VerifyAll runs the complete post-repair health check suite.
func (v *HealthVerifier) VerifyAll() *HealthVerifyResult {
	result := &HealthVerifyResult{Checks: make([]HealthCheck, 0)}
	start := time.Now()

	// Ubuntu checks
	result.Checks = append(result.Checks, v.verifyDpkg())
	result.Checks = append(result.Checks, v.verifySystemdServices())
	result.Checks = append(result.Checks, v.verifyDiskSpace())

	// K8s checks (non-fatal if kubectl not reachable)
	if IsK8sAvailable() {
		result.Checks = append(result.Checks, v.verifyK8sNodes())
		result.Checks = append(result.Checks, v.verifyK8sPods())
	} else {
		v.logger.Warn("health verifier: kubectl not available — skipping K8s checks")
		result.Checks = append(result.Checks, HealthCheck{
			Name: "k8s-available", Pass: false, Detail: "kubectl not reachable",
		})
	}

	result.Duration = time.Since(start)
	result.Success = true
	for _, c := range result.Checks {
		if !c.Pass {
			result.Success = false
			v.logger.Warn("health check failed", "check", c.Name, "detail", c.Detail)
		}
	}
	return result
}

func (v *HealthVerifier) verifyDpkg() HealthCheck {
	cmd := exec.Command("dpkg", "--audit")
	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))
	if err != nil && output != "" {
		return HealthCheck{Name: "dpkg-audit", Pass: false, Detail: output}
	}
	return HealthCheck{Name: "dpkg-audit", Pass: true, Detail: "clean"}
}

func (v *HealthVerifier) verifySystemdServices() HealthCheck {
	services := []string{"containerd", "kubelet", "systemd-journald"}
	var failures []string
	for _, svc := range services {
		cmd := exec.Command("systemctl", "is-active", svc)
		if err := cmd.Run(); err != nil {
			failures = append(failures, svc)
		}
	}
	if len(failures) > 0 {
		return HealthCheck{
			Name: "systemd-services", Pass: false,
			Detail: fmt.Sprintf("inactive: %s", strings.Join(failures, ", ")),
		}
	}
	return HealthCheck{Name: "systemd-services", Pass: true, Detail: "all active"}
}

func (v *HealthVerifier) verifyDiskSpace() HealthCheck {
	cmd := exec.Command("df", "-h", "/")
	out, err := cmd.Output()
	if err != nil {
		return HealthCheck{Name: "disk-space", Pass: false, Detail: fmt.Sprintf("df failed: %v", err)}
	}
	// Parse: check if use% > 90
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) > 1 {
		fields := strings.Fields(lines[1])
		if len(fields) >= 5 {
			pct := strings.TrimSuffix(fields[4], "%")
			if pct != "" {
				var use int
				fmt.Sscanf(pct, "%d", &use)
				if use > 90 {
					return HealthCheck{Name: "disk-space", Pass: false,
						Detail: fmt.Sprintf("disk %s used", fields[4])}
				}
			}
		}
	}
	return HealthCheck{Name: "disk-space", Pass: true, Detail: "ok"}
}

func (v *HealthVerifier) verifyK8sNodes() HealthCheck {
	cmd := exec.Command("kubectl", "get", "nodes", "--no-headers")
	out, err := cmd.Output()
	if err != nil {
		return HealthCheck{Name: "k8s-nodes", Pass: false, Detail: fmt.Sprintf("cannot list nodes: %v", err)}
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	var notReady []string
	for _, line := range lines {
		if strings.Contains(line, "NotReady") || strings.Contains(line, "SchedulingDisabled") {
			fields := strings.Fields(line)
			if len(fields) > 0 {
				notReady = append(notReady, fields[0])
			}
		}
	}
	if len(notReady) > 0 {
		return HealthCheck{Name: "k8s-nodes", Pass: false,
			Detail: fmt.Sprintf("NotReady: %s", strings.Join(notReady, ", "))}
	}
	return HealthCheck{Name: "k8s-nodes", Pass: true, Detail: fmt.Sprintf("%d nodes Ready", len(lines))}
}

func (v *HealthVerifier) verifyK8sPods() HealthCheck {
	cmd := exec.Command("kubectl", "get", "pods", "--all-namespaces", "--no-headers",
		"--field-selector=status.phase!=Running,status.phase!=Succeeded")
	out, err := cmd.Output()
	if err != nil {
		return HealthCheck{Name: "k8s-pods", Pass: false, Detail: fmt.Sprintf("cannot list pods: %v", err)}
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	nonRunning := 0
	for _, line := range lines {
		if line != "" {
			nonRunning++
		}
	}
	if nonRunning > 0 {
		return HealthCheck{Name: "k8s-pods", Pass: false,
			Detail: fmt.Sprintf("%d pods not Running/Succeeded", nonRunning)}
	}
	return HealthCheck{Name: "k8s-pods", Pass: true, Detail: "all Running/Succeeded"}
}
