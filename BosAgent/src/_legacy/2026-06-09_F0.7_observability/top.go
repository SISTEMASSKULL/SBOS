package observability

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"bos/internal/state"
)

// TopSnapshot provides a unified metrics view across Ubuntu, K8s, and BOS layers.
type TopSnapshot struct {
	Timestamp time.Time `json:"timestamp"`
	CPU       CPUInfo   `json:"cpu"`
	Memory    MemInfo   `json:"memory"`
	Disk      DiskInfo  `json:"disk"`
	K8s       K8sInfo   `json:"k8s"`
	Fichas    FichaInfo `json:"fichas"`
}

// CPUInfo holds system load averages.
type CPUInfo struct {
	Load1  float64 `json:"load_1m"`
	Load5  float64 `json:"load_5m"`
	Load15 float64 `json:"load_15m"`
}

// MemInfo holds memory usage stats.
type MemInfo struct {
	TotalMB int `json:"total_mb"`
	UsedMB  int `json:"used_mb"`
	FreeMB  int `json:"free_mb"`
	UsedPct int `json:"used_pct"`
}

// DiskInfo holds disk usage for root mount.
type DiskInfo struct {
	TotalGB int    `json:"total_gb"`
	UsedGB  int    `json:"used_gb"`
	AvailGB int    `json:"avail_gb"`
	UsedPct int    `json:"used_pct"`
	Mount   string `json:"mount"`
}

// K8sInfo holds Kubernetes cluster summary.
type K8sInfo struct {
	NodesTotal  int `json:"nodes_total"`
	NodesReady  int `json:"nodes_ready"`
	PodsTotal   int `json:"pods_total"`
	PodsRunning int `json:"pods_running"`
}

// FichaInfo holds BOS ficha health summary.
type FichaInfo struct {
	Total    int `json:"total"`
	Healthy  int `json:"healthy"`
	Degraded int `json:"degraded"`
	Down     int `json:"down"`
}

// CollectTopSnapshot gathers a unified snapshot of system + K8s + BOS metrics.
func CollectTopSnapshot() *TopSnapshot {
	snap := &TopSnapshot{Timestamp: time.Now().UTC()}
	snap.CPU = collectCPU()
	snap.Memory = collectMemory()
	snap.Disk = collectDisk()
	snap.K8s = collectK8s()
	snap.Fichas = collectFichas()
	return snap
}

// CollectTopSnapshotWithState gathers metrics using an existing state manager handle.
func CollectTopSnapshotWithState(stateMgr *state.Manager) *TopSnapshot {
	snap := &TopSnapshot{Timestamp: time.Now().UTC()}
	snap.CPU = collectCPU()
	snap.Memory = collectMemory()
	snap.Disk = collectDisk()
	snap.K8s = collectK8s()
	snap.Fichas = collectFichasFromState(stateMgr)
	return snap
}

func collectCPU() CPUInfo {
	data, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		return CPUInfo{}
	}
	fields := strings.Fields(string(data))
	info := CPUInfo{}
	if len(fields) >= 3 {
		fmt.Sscanf(fields[0], "%f", &info.Load1)
		fmt.Sscanf(fields[1], "%f", &info.Load5)
		fmt.Sscanf(fields[2], "%f", &info.Load15)
	}
	return info
}

func collectMemory() MemInfo {
	cmd := exec.Command("free", "-m")
	out, err := cmd.Output()
	if err != nil {
		return MemInfo{}
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) < 2 {
		return MemInfo{}
	}
	fields := strings.Fields(lines[1])
	if len(fields) < 3 {
		return MemInfo{}
	}
	total, _ := strconv.Atoi(fields[1])
	used, _ := strconv.Atoi(fields[2])
	info := MemInfo{TotalMB: total, UsedMB: used, FreeMB: total - used}
	if total > 0 {
		info.UsedPct = int(float64(used) / float64(total) * 100)
	}
	return info
}

func collectDisk() DiskInfo {
	cmd := exec.Command("df", "-h", "--output=size,used,avail,pcent,target", "/")
	out, err := cmd.Output()
	if err != nil {
		return DiskInfo{Mount: "/"}
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) < 2 {
		return DiskInfo{Mount: "/"}
	}
	fields := strings.Fields(lines[1])
	if len(fields) < 5 {
		return DiskInfo{Mount: "/"}
	}
	total := parseSize(fields[0])
	used := parseSize(fields[1])
	avail := parseSize(fields[2])
	pct, _ := strconv.Atoi(strings.TrimSuffix(fields[3], "%"))
	return DiskInfo{
		TotalGB: total, UsedGB: used, AvailGB: avail,
		UsedPct: pct, Mount: fields[4],
	}
}

func parseSize(s string) int {
	isG := strings.HasSuffix(s, "G")
	isM := strings.HasSuffix(s, "M")
	s = strings.TrimRight(s, "GM")
	val, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return 0
	}
	if isG {
		return int(val)
	}
	if isM {
		return int(val / 1024)
	}
	return int(val)
}

func collectK8s() K8sInfo {
	info := K8sInfo{}

	// Nodes
	nodeOut, err := exec.Command("kubectl", "get", "nodes", "--no-headers").Output()
	if err != nil {
		return info
	}
	nodeLines := strings.Split(strings.TrimSpace(string(nodeOut)), "\n")
	info.NodesTotal = len(nodeLines)
	for _, line := range nodeLines {
		if strings.Contains(line, "Ready") && !strings.Contains(line, "NotReady") {
			info.NodesReady++
		}
	}

	// Pods
	podOut, err := exec.Command("kubectl", "get", "pods", "--all-namespaces", "--no-headers").Output()
	if err != nil {
		return info
	}
	podLines := strings.Split(strings.TrimSpace(string(podOut)), "\n")
	for _, line := range podLines {
		if strings.TrimSpace(line) == "" {
			continue
		}
		info.PodsTotal++
		if strings.Contains(line, "Running") {
			info.PodsRunning++
		}
	}
	return info
}

func collectFichas() FichaInfo {
	stateMgr, err := state.NewManager("/etc/bos/.sbos_state.json")
	if err != nil {
		return FichaInfo{}
	}
	defer stateMgr.Close()
	return collectFichasFromState(stateMgr)
}

func collectFichasFromState(stateMgr *state.Manager) FichaInfo {
	info := FichaInfo{}
	st, err := stateMgr.Read()
	if err != nil {
		return info
	}
	info.Total = len(st.Fichas)
	for _, f := range st.Fichas {
		switch f.HealthStatus {
		case "HEALTHY":
			info.Healthy++
		case "DEGRADED":
			info.Degraded++
		case "DOWN":
			info.Down++
		}
	}
	return info
}

// Format returns a human-readable multi-line string.
func (s *TopSnapshot) Format() string {
	return fmt.Sprintf(`Top Snapshot — %s
CPU:    load %.2f / %.2f / %.2f
MEM:    %d MB / %d MB (%d%%)
DISK:   %d GB / %d GB (%d%%) on %s
K8s:    %d nodes (%d Ready) · %d pods (%d Running)
Fichas: %d total · %d healthy · %d degraded · %d down`,
		s.Timestamp.Format(time.RFC3339),
		s.CPU.Load1, s.CPU.Load5, s.CPU.Load15,
		s.Memory.UsedMB, s.Memory.TotalMB, s.Memory.UsedPct,
		s.Disk.UsedGB, s.Disk.TotalGB, s.Disk.UsedPct, s.Disk.Mount,
		s.K8s.NodesTotal, s.K8s.NodesReady, s.K8s.PodsTotal, s.K8s.PodsRunning,
		s.Fichas.Total, s.Fichas.Healthy, s.Fichas.Degraded, s.Fichas.Down,
	)
}
