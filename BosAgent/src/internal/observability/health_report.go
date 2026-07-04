package observability

import (
	"context"
	"fmt"
	"os/exec"
	"sort"
	"strings"
	"time"

	"bos/internal/paths"
	"bos/internal/query"
	"bos/internal/state"
)

// HealthReport provee una vista estructurada del estado de salud en las tres capas BOS.
//
// Thread safety: inmutable tras CollectReport() — seguro para lectura concurrente.
type HealthReport struct {
	Timestamp time.Time     `json:"timestamp"`
	Ubuntu    UbuntuHealth  `json:"ubuntu"`
	K8s       K8sHealth     `json:"k8s"`
	BOS       BOSHealth     `json:"bos"`
	Overall   OverallHealth `json:"overall"`
}

// UbuntuHealth encapsula el estado de salud de la capa OS (disco, memoria, servicios críticos).
type UbuntuHealth struct {
	DiskSpaceOK  bool   `json:"disk_space_ok"`
	DiskDetail   string `json:"disk_detail"`
	MemoryOK     bool   `json:"memory_ok"`
	MemoryDetail string `json:"memory_detail"`
	ServicesOK   bool   `json:"services_ok"`
	Services     string `json:"services"`
}

// K8sHealth encapsula el estado de salud del cluster Kubernetes (nodos, pods, kubelet).
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

// FichaHealthStatus contiene el estado de salud individual de una ficha para reporting detallado.
type FichaHealthStatus struct {
	Name   string `json:"name"`
	State  string `json:"state"`
	Health string `json:"health"`
}

// BOSHealth encapsula el resumen de salud a nivel de fichas (totales, healthy, degraded, down).
type BOSHealth struct {
	FichasTotal    int                 `json:"fichas_total"`
	FichasHealthy  int                 `json:"fichas_healthy"`
	FichasDegraded int                 `json:"fichas_degraded"`
	FichasDown     int                 `json:"fichas_down"`
	Fichas         []FichaHealthStatus `json:"fichas,omitempty"`
}

// OverallHealth resume el estado de salud global del Business OS (pass/fail con mensaje).
type OverallHealth struct {
	Pass   bool   `json:"pass"`
	Status string `json:"status"`
}

// CollectReport recolecta un informe de salud completo a través de las tres capas (Ubuntu/K8s/BOS).
//
// Retorna: *HealthReport con estado de disco, memoria, servicios, nodos, pods y fichas.
//
// Callers conocidos:
//   - cmd/bosctl/app.go — subcomando "bosctl health-report".
//   - internal/server/ws.go — handler "health" (modo no-pending).
//
// Efectos secundarios:
//   - Ejecuta: df, free, systemctl, kubectl get nodes/pods.
//   - Instancia un state.Manager para leer .sbos_state.json.
//   - NUNCA registrar contraseñas ni tokens en logs.
//
// Estándares: SBOS-018 §Day-2 (Reconciliación 3 capas).
func CollectReport() *HealthReport {
	report := &HealthReport{Timestamp: time.Now().UTC()}
	report.Ubuntu = collectUbuntuHealth()
	report.K8s = collectK8sHealth()
	report.BOS = collectBOSHealth()
	report.Overall = computeOverall(report.Ubuntu, report.K8s, report.BOS)
	return report
}

// collectUbuntuHealth usa query.UbuntuSnapshot (M-16) — elimina exec df/free/systemctl duplicados.
func collectUbuntuHealth() UbuntuHealth {
	result, err := query.UbuntuSnapshot(context.Background())
	if err != nil {
		return UbuntuHealth{
			DiskDetail:   fmt.Sprintf("snapshot falló: %v", err),
			MemoryDetail: "no disponible",
			Services:     "no disponible",
		}
	}
	m, ok := result.(map[string]interface{})
	if !ok {
		return UbuntuHealth{}
	}

	diskPct, _ := m["disk_pct"].(int)
	memPct, _ := m["mem_pct"].(int)
	svcMap, _ := m["services"].(map[string]string)

	var failing []string
	for svc, estado := range svcMap {
		if estado != "active" {
			failing = append(failing, svc)
		}
	}
	sort.Strings(failing) // orden determinista para tests

	svcsOK := len(failing) == 0
	svcsDetail := "containerd+kubelet active"
	if !svcsOK {
		svcsDetail = "inactive: " + strings.Join(failing, ", ")
	}

	return UbuntuHealth{
		DiskSpaceOK:  diskPct <= 90,
		DiskDetail:   fmt.Sprintf("%d%% disco", diskPct),
		MemoryOK:     memPct <= 90,
		MemoryDetail: fmt.Sprintf("%d%% memoria", memPct),
		ServicesOK:   svcsOK,
		Services:     svcsDetail,
	}
}

// collectK8sHealth usa query.K8sNodesSummary para los nodos (M-16).
// Pods y kubelet conservan su lógica original (query no los cubre aún).
func collectK8sHealth() K8sHealth {
	h := K8sHealth{}

	if _, err := exec.LookPath("kubectl"); err != nil {
		return h // Available=false
	}
	h.Available = true

	// Kubelet vía systemctl (query.UbuntuSnapshot cubre servicios, pero K8sHealth
	// necesita KubeletOK como campo propio de esta capa).
	h.KubeletOK = exec.Command("systemctl", "is-active", "kubelet").Run() == nil

	// Nodos vía query.K8sNodesSummary (M-16 — elimina exec kubectl get nodes duplicado).
	if result, err := query.K8sNodesSummary(context.Background()); err == nil {
		if m, ok := result.(map[string]interface{}); ok {
			if v, ok := m["nodes_total"].(int); ok {
				h.NodeCount = v
			}
			if v, ok := m["nodes_ready"].(int); ok {
				h.NodesReady = v
			}
		}
	}
	h.NodesOK = h.NodeCount > 0 && h.NodesReady == h.NodeCount

	// Pods — sin cobertura en query aún (F9 agregará bos.query.node multi-nodo).
	podOut, err := exec.Command("kubectl", "get", "pods", "--all-namespaces", "--no-headers").Output()
	if err == nil {
		for _, line := range strings.Split(strings.TrimSpace(string(podOut)), "\n") {
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
	stateMgr, err := state.NewManager(paths.StatePath)
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

// Format retorna el informe de salud en formato legible para consola.
//
// Retorna: string multilínea con secciones Ubuntu/K8s/BOS/Overall.
//
// Efectos secundarios: ninguno — solo lectura del receptor.
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
