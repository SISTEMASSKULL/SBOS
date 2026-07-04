package observability

import (
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"bos/internal/state"
)

// HealthReport provides a structured health view across all three BOS layers.
type HealthReport struct {
	Timestamp time.Time     `json:"timestamp"`
	Ubuntu    UbuntuHealth  `json:"ubuntu"`
	K8s       K8sHealth     `json:"k8s"`
	BOS       BOSHealth     `json:"bos"`
	Overall   OverallHealth `json:"overall"`
}

// UbuntuHealth captures OS-layer health.
type UbuntuHealth struct {
	DiskSpaceOK  bool   `json:"disk_space_ok"`
	DiskDetail   string `json:"disk_detail"`
	MemoryOK     bool   `json:"memory_ok"`
	MemoryDetail string `json:"memory_detail"`
	ServicesOK   bool   `json:"services_ok"`
	Services     string `json:"services"`
}

// K8sHealth captures Kubernetes cluster health.
type K8sHealth struct {
	Available   bool `json:"available"`
	KubeletOK   bool `json:"kubelet_ok"`
	NodesOK     bool `json:"nodes_ok"`
	NodeCount   int  `json:"node_count"`
	NodesReady  int  `json:"nodes_ready"`
	PodsOK      bool `json:"pods_ok"`
	PodCount    int  `json:"pod_count"`
	PodsRunning int  `json:"pods_running"`
}

// FichaHealthStatus holds per-ficha health for detailed reporting.
type FichaHealthStatus struct {
	Name   string `json:"name"`
	State  string `json:"state"`
	Health string `json:"health"`
}

// BOSHealth captures ficha-level health summary.
type BOSHealth struct {
	FichasTotal    int                 `json:"fichas_total"`
	FichasHealthy  int                 `json:"fichas_healthy"`
	FichasDegraded int                 `json:"fichas_degraded"`
	FichasDown     int                 `json:"fichas_down"`
	Fichas         []FichaHealthStatus `json:"fichas,omitempty"`
}

// OverallHealth summarizes the health of the entire Business OS.
type OverallHealth struct {
	Pass   bool   `json:"pass"`
	Status string `json:"status"`
}

// CollectReport gathers a full health report across all layers.
func CollectReport() *HealthReport {
	report := &HealthReport{Timestamp: time.Now().UTC()}
	report.Ubuntu = collectUbuntuHealth()
	report.K8s = collectK8sHealth()
	report.BOS = collectBOSHealth()
	report.Overall = computeOverall(report.Ubuntu, report.K8s, report.BOS)
	return report
}

func collectUbuntuHealth() UbuntuHealth {
	h := UbuntuHealth{}

	// Disk space
	cmd := exec.Command("df", "-h", "/")
	out, err := cmd.Output()
	if err != nil {
		h.DiskSpaceOK = false
		h.DiskDetail = fmt.Sprintf("df failed: %v", err)
	} else {
		lines := strings.Split(strings.TrimSpace(string(out)), "\n")
		if len(lines) > 1 {
			fields := strings.Fields(lines[1])
			if len(fields) >= 5 {
				pct, _ := strconv.Atoi(strings.TrimSuffix(fields[4], "%"))
				if pct > 90 {
					h.DiskSpaceOK = false
					h.DiskDetail = fmt.Sprintf("disk %s full (threshold 90%%)", fields[4])
				} else {
					h.DiskSpaceOK = true
					h.DiskDetail = fmt.Sprintf("%s used of %s", fields[4], fields[1])
				}
			}
		}
	}

	// Memory
	cmd = exec.Command("free", "-m")
	out, err = cmd.Output()
	if err != nil {
		h.MemoryOK = false
		h.MemoryDetail = fmt.Sprintf("free failed: %v", err)
	} else {
		lines := strings.Split(strings.TrimSpace(string(out)), "\n")
		if len(lines) >= 2 {
			fields := strings.Fields(lines[1])
			if len(fields) >= 3 {
				total, _ := strconv.Atoi(fields[1])
				used, _ := strconv.Atoi(fields[2])
				pct := 0
				if total > 0 {
					pct = int(float64(used) / float64(total) * 100)
				}
				h.MemoryDetail = fmt.Sprintf("%d%% used (%d/%d MB)", pct, used, total)
				h.MemoryOK = pct <= 90
			}
		}
	}

	// Systemd services
	services := []string{"containerd", "kubelet"}
	var failing []string
	for _, svc := range services {
		if err := exec.Command("systemctl", "is-active", svc).Run(); err != nil {
			failing = append(failing, svc)
		}
	}
	if len(failing) > 0 {
		h.ServicesOK = false
		h.Services = fmt.Sprintf("inactive: %s", strings.Join(failing, ", "))
	} else {
		h.ServicesOK = true
		h.Services = "containerd+kubelet active"
	}

	return h
}

func collectK8sHealth() K8sHealth {
	h := K8sHealth{}

	// Check if kubectl is available
	if _, err := exec.LookPath("kubectl"); err != nil {
		h.Available = false
		return h
	}
	h.Available = true

	// Kubelet
	if err := exec.Command("systemctl", "is-active", "kubelet").Run(); err != nil {
		h.KubeletOK = false
	} else {
		h.KubeletOK = true
	}

	// Nodes
	nodeOut, err := exec.Command("kubectl", "get", "nodes", "--no-headers").Output()
	if err == nil {
		nodeLines := strings.Split(strings.TrimSpace(string(nodeOut)), "\n")
		h.NodeCount = len(nodeLines)
		for _, line := range nodeLines {
			if strings.Contains(line, "Ready") && !strings.Contains(line, "NotReady") {
				h.NodesReady++
			}
		}
	}
	h.NodesOK = h.NodeCount > 0 && h.NodesReady == h.NodeCount

	// Pods
	podOut, err := exec.Command("kubectl", "get", "pods", "--all-namespaces", "--no-headers").Output()
	if err == nil {
		podLines := strings.Split(strings.TrimSpace(string(podOut)), "\n")
		for _, line := range podLines {
			if strings.TrimSpace(line) == "" {
				continue
			}
			h.PodCount++
			if strings.Contains(line, "Running") || strings.Contains(line, "Succeeded") {
				h.PodsRunning++
			}
		}
	}
	h.PodsOK = h.PodCount == h.PodsRunning

	return h
}

func collectBOSHealth() BOSHealth {
	h := BOSHealth{}
	stateMgr, err := state.NewManager("/etc/bos/.sbos_state.json")
	if err != nil {
		return h
	}
	defer stateMgr.Close()

	st, err := stateMgr.Read()
	if err != nil {
		return h
	}

	h.FichasTotal = len(st.Fichas)
	for name, f := range st.Fichas {
		switch f.HealthStatus {
		case "HEALTHY":
			h.FichasHealthy++
		case "DEGRADED":
			h.FichasDegraded++
		case "DOWN":
			h.FichasDown++
		}
		h.Fichas = append(h.Fichas, FichaHealthStatus{
			Name:   name,
			State:  string(f.State),
			Health: f.HealthStatus,
		})
	}
	return h
}

func computeOverall(u UbuntuHealth, k K8sHealth, b BOSHealth) OverallHealth {
	allOS := u.DiskSpaceOK && u.MemoryOK && u.ServicesOK
	allK8s := true
	if k.Available {
		allK8s = k.KubeletOK && k.NodesOK && k.PodsOK
	}
	allBOS := b.FichasDegraded == 0 && b.FichasDown == 0

	if allOS && allK8s && allBOS {
		return OverallHealth{Pass: true, Status: "HEALTHY"}
	}
	if b.FichasDown > 0 || (k.Available && !k.KubeletOK) {
		return OverallHealth{Pass: false, Status: "DOWN"}
	}
	return OverallHealth{Pass: false, Status: "DEGRADED"}
}

// Format returns a human-readable health report string.
func (r *HealthReport) Format() string {
	var b strings.Builder
	b.WriteString(fmt.Sprintf("Health Report — %s\n\n", r.Timestamp.Format(time.RFC3339)))

	// Ubuntu
	b.WriteString("Ubuntu:\n")
	b.WriteString(fmt.Sprintf("  Disk:     %s [%s]\n", statusIcon(r.Ubuntu.DiskSpaceOK), r.Ubuntu.DiskDetail))
	b.WriteString(fmt.Sprintf("  Memory:   %s [%s]\n", statusIcon(r.Ubuntu.MemoryOK), r.Ubuntu.MemoryDetail))
	b.WriteString(fmt.Sprintf("  Services: %s [%s]\n", statusIcon(r.Ubuntu.ServicesOK), r.Ubuntu.Services))

	// K8s
	b.WriteString("\nK8s:\n")
	if !r.K8s.Available {
		b.WriteString("  kubectl not available\n")
	} else {
		b.WriteString(fmt.Sprintf("  Kubelet: %s\n", statusIcon(r.K8s.KubeletOK)))
		b.WriteString(fmt.Sprintf("  Nodes:   %s [%d/%d Ready]\n", statusIcon(r.K8s.NodesOK), r.K8s.NodesReady, r.K8s.NodeCount))
		b.WriteString(fmt.Sprintf("  Pods:    %s [%d/%d Running]\n", statusIcon(r.K8s.PodsOK), r.K8s.PodsRunning, r.K8s.PodCount))
	}

	// BOS
	b.WriteString("\nBOS:\n")
	b.WriteString(fmt.Sprintf("  Fichas:  %d total · %d healthy · %d degraded · %d down\n",
		r.BOS.FichasTotal, r.BOS.FichasHealthy, r.BOS.FichasDegraded, r.BOS.FichasDown))

	// Overall
	b.WriteString(fmt.Sprintf("\nOverall: %s [%s]\n", statusIcon(r.Overall.Pass), r.Overall.Status))

	return b.String()
}

func statusIcon(ok bool) string {
	if ok {
		return "OK"
	}
	return "FAIL"
}
