package watchdog

import (
	"fmt"

	"bos/internal/audit"
	"bos/internal/paths"
	"net"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"

	"bos/internal/health"
	"bos/internal/repair"
	"bos/internal/state"

	"log/slog"
)

// UnifiedWatchdog ejecuta un ciclo periódico verificando las tres capas del SBOS:
// Ubuntu host, Kubernetes cluster y fichas BOS.
//
// Thread safety: Run() y Stop() son seguros para llamar desde goroutines distintas.
// mu protege el flag running y el cierre de stopCh.
type UnifiedWatchdog struct {
	mu       sync.Mutex
	stateMgr *state.Manager
	interval time.Duration
	logger   *slog.Logger
	stopCh   chan struct{}
	running  bool

	diskThresholdPct int
	memThresholdPct  int

	k8sNodeCheck  bool
	k8sPodCheck   bool
	bosFichaCheck bool
	autoRepair    bool

	repairMgr *repair.RepairManager

	// diagnosticar consulta bos.query.repair ANTES del auto-repair (F6.14 —
	// BOS-REPAIR-12 §5.2: diagnóstico pre-remediación). nil = sin gate.
	diagnosticar Diagnosticador
}

// Diagnosticador es el puerto al pre-diagnóstico (bos.query.repair).
// Retorna la causa probable y los usuarios afectados por la ficha.
type Diagnosticador func(fichaID string) (causa string, usuariosAfectados int, err error)

// UmbralUsuariosAfectados: por encima de este impacto el watchdog NO
// auto-repara — difiere a HITL (BOS-REPAIR-12 §5.2).
const UmbralUsuariosAfectados = 50

// SetDiagnosticador inyecta el pre-diagnóstico (run_normal, tras crear el
// server). Llamar antes de Run() — no es thread-safe respecto al loop.
func (w *UnifiedWatchdog) SetDiagnosticador(d Diagnosticador) { w.diagnosticar = d }

// Snapshot is the aggregated output of one watchdog cycle.
type Snapshot struct {
	Timestamp time.Time
	Ubuntu    []repair.HealthCheck
	K8s       []repair.HealthCheck
	BOS       []repair.HealthCheck
	AllPass   bool
	Duration  time.Duration
}

// NewUnifiedWatchdog crea un watchdog unificado con 3 fases de verificación:
// Ubuntu (disco, memoria, systemd), K8s (nodos, pods) y BOS (fichas).
//
// Recibe:
//   - stateMgr: *state.Manager — para leer el estado de fichas BOS.
//   - interval: time.Duration — intervalo entre ciclos de verificación.
//   - diskThresholdPct, memThresholdPct: int — umbrales de uso (0-100).
//   - k8sNodeCheck, k8sPodCheck, bosFichaCheck: bool — qué fases habilitar.
//   - autoRepair: bool — si true, dispara repair cuando hay fallos.
//   - repairMgr: *repair.RepairManager — usado solo si autoRepair=true.
//
// Callers conocidos:
//   - cmd/bos/main.go:runNormal — crea e inicia el watchdog con go wd.Run().
func NewUnifiedWatchdog(
	stateMgr *state.Manager,
	interval time.Duration,
	diskThresholdPct int,
	memThresholdPct int,
	k8sNodeCheck bool,
	k8sPodCheck bool,
	bosFichaCheck bool,
	autoRepair bool,
	repairMgr *repair.RepairManager,
	logger *slog.Logger,
) *UnifiedWatchdog {
	return &UnifiedWatchdog{
		stateMgr:         stateMgr,
		interval:         interval,
		logger:           logger,
		stopCh:           make(chan struct{}),
		diskThresholdPct: diskThresholdPct,
		memThresholdPct:  memThresholdPct,
		k8sNodeCheck:     k8sNodeCheck,
		k8sPodCheck:      k8sPodCheck,
		bosFichaCheck:    bosFichaCheck,
		autoRepair:       autoRepair,
		repairMgr:        repairMgr,
	}
}

// Run inicia el loop del watchdog. Bloquea hasta que Stop() sea llamado.
//
// Efectos secundarios:
//   - Ejecuta runCycle() inmediatamente y luego cada interval.
//   - Si autoRepair=true, puede disparar reparaciones vía repairMgr.
func (w *UnifiedWatchdog) Run() {
	w.mu.Lock()
	w.running = true
	w.mu.Unlock()

	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	w.logger.Info("unified watchdog started", "interval", w.interval)

	w.runCycle()

	for {
		select {
		case <-ticker.C:
			w.runCycle()
		case <-w.stopCh:
			w.logger.Info("unified watchdog stopped")
			return
		}
	}
}

// Stop señaliza al watchdog para que detenga el loop.
//
// Efectos secundarios: cierra stopCh (una sola vez bajo mu).
func (w *UnifiedWatchdog) Stop() {
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.running {
		close(w.stopCh)
		w.running = false
	}
}

func (w *UnifiedWatchdog) runCycle() {
	start := time.Now()
	snap := Snapshot{Timestamp: start}

	// Phase 1: Ubuntu
	snap.Ubuntu = append(snap.Ubuntu, w.checkDiskSpace())
	snap.Ubuntu = append(snap.Ubuntu, w.checkMemoryUsage())
	snap.Ubuntu = append(snap.Ubuntu, w.checkSystemdServices())

	// Phase 2: K8s
	if w.k8sNodeCheck {
		snap.K8s = append(snap.K8s, w.checkK8sNodes())
	}
	if w.k8sPodCheck {
		snap.K8s = append(snap.K8s, w.checkK8sPods())
	}

	// Phase 3: BOS fichas
	if w.bosFichaCheck {
		snap.BOS = w.checkBOSFichas()
	}

	snap.Duration = time.Since(start)

	// Compute all-pass
	snap.AllPass = true
	for _, c := range snap.Ubuntu {
		if !c.Pass {
			snap.AllPass = false
		}
	}
	for _, c := range snap.K8s {
		if !c.Pass {
			snap.AllPass = false
		}
	}
	for _, c := range snap.BOS {
		if !c.Pass {
			snap.AllPass = false
		}
	}

	// Log cycle summary
	ubuntuOK, ubuntuTotal := countPass(snap.Ubuntu)
	k8sOK, k8sTotal := countPass(snap.K8s)
	bosOK, bosTotal := countPass(snap.BOS)

	w.logger.Info("watchdog cycle",
		"duration_ms", snap.Duration.Milliseconds(),
		"all_pass", snap.AllPass,
		"ubuntu", fmt.Sprintf("%d/%d", ubuntuOK, ubuntuTotal),
		"k8s", fmt.Sprintf("%d/%d", k8sOK, k8sTotal),
		"bos", fmt.Sprintf("%d/%d", bosOK, bosTotal),
	)

	// Log individual failures
	for _, c := range snap.Ubuntu {
		if !c.Pass {
			w.logger.Warn("watchdog: ubuntu check failed", "check", c.Name, "detail", c.Detail)
		}
	}
	for _, c := range snap.K8s {
		if !c.Pass {
			w.logger.Warn("watchdog: k8s check failed", "check", c.Name, "detail", c.Detail)
		}
	}
	for _, c := range snap.BOS {
		if !c.Pass {
			w.logger.Warn("watchdog: bos check failed", "check", c.Name, "detail", c.Detail)
		}
	}

	// Auto-repair trigger (disabled by default)
	if w.autoRepair && !snap.AllPass && w.repairMgr != nil {
		// F6.14 — diagnóstico ANTES de remediar: reparar a ciegas puede
		// empeorar el estado. Con impacto alto se difiere a HITL.
		if !w.preDiagnosticoPermite(snap) {
			return
		}
		w.logger.Info("watchdog: auto-repair triggered")
		go func() {
			result := w.repairMgr.Run(repair.TargetAll)
			if result.Success {
				w.logger.Info("watchdog: auto-repair completed", "duration", result.Duration)
			} else {
				w.logger.Warn("watchdog: auto-repair had failures", "duration", result.Duration)
			}
		}()
	}

	w.sdNotify()
}

// preDiagnosticoPermite ejecuta bos.query.repair por cada ficha BOS fallida
// del snapshot y decide si el auto-repair procede (F6.14, BOS-REPAIR-12
// §5.2). Registra cada diagnóstico en el audit log ANTES de actuar; con
// usuarios afectados > UmbralUsuariosAfectados difiere a HITL y retorna
// false. Sin Diagnosticador inyectado retorna true (compatibilidad).
func (w *UnifiedWatchdog) preDiagnosticoPermite(snap Snapshot) bool {
	if w.diagnosticar == nil {
		return true
	}
	for _, c := range snap.BOS {
		if c.Pass {
			continue
		}
		causa, usuarios, err := w.diagnosticar(c.Name)
		if err != nil {
			w.logger.Warn("watchdog: pre-diagnóstico falló — auto-repair continúa",
				"ficha", c.Name, "err", err)
			continue
		}
		audit.Log(paths.AuditLog, "WATCHDOG_DIAGNOSIS",
			"ficha="+c.Name,
			"causa="+causa,
			fmt.Sprintf("usuarios_afectados=%d", usuarios))
		if usuarios > UmbralUsuariosAfectados {
			w.logger.Warn("watchdog: impacto alto — auto-repair diferido a HITL",
				"ficha", c.Name, "usuarios", usuarios)
			audit.Log(paths.AuditLog, "WATCHDOG_DEFER",
				"ficha="+c.Name,
				"reason=high_impact",
				fmt.Sprintf("usuarios=%d", usuarios))
			return false
		}
	}
	return true
}

// ── Ubuntu checks ────────────────────────────────────────────────────

func (w *UnifiedWatchdog) checkDiskSpace() repair.HealthCheck {
	cmd := exec.Command("df", "-h", "/")
	out, err := cmd.Output()
	if err != nil {
		return repair.HealthCheck{Name: "disk-space", Pass: false, Detail: fmt.Sprintf("df failed: %v", err)}
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) > 1 {
		fields := strings.Fields(lines[1])
		if len(fields) >= 5 {
			pctStr := strings.TrimSuffix(fields[4], "%")
			use, _ := strconv.Atoi(pctStr)
			if use > w.diskThresholdPct {
				return repair.HealthCheck{Name: "disk-space", Pass: false,
					Detail: fmt.Sprintf("disk %s used (threshold %d%%)", fields[4], w.diskThresholdPct)}
			}
		}
	}
	return repair.HealthCheck{Name: "disk-space", Pass: true, Detail: "ok"}
}

func (w *UnifiedWatchdog) checkMemoryUsage() repair.HealthCheck {
	cmd := exec.Command("free", "-m")
	out, err := cmd.Output()
	if err != nil {
		return repair.HealthCheck{Name: "memory-usage", Pass: false, Detail: fmt.Sprintf("free failed: %v", err)}
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) >= 2 {
		fields := strings.Fields(lines[1])
		if len(fields) >= 3 {
			total, _ := strconv.ParseFloat(fields[1], 64)
			used, _ := strconv.ParseFloat(fields[2], 64)
			if total > 0 {
				pct := int((used / total) * 100)
				if pct > w.memThresholdPct {
					return repair.HealthCheck{Name: "memory-usage", Pass: false,
						Detail: fmt.Sprintf("memory %d%% used (%d/%d MB, threshold %d%%)",
							pct, int(used), int(total), w.memThresholdPct)}
				}
			}
		}
	}
	return repair.HealthCheck{Name: "memory-usage", Pass: true, Detail: "ok"}
}

func (w *UnifiedWatchdog) checkSystemdServices() repair.HealthCheck {
	services := []string{"containerd", "kubelet"}
	var failures []string
	for _, svc := range services {
		if err := exec.Command("systemctl", "is-active", svc).Run(); err != nil {
			failures = append(failures, svc)
		}
	}
	if len(failures) > 0 {
		return repair.HealthCheck{Name: "systemd-services", Pass: false,
			Detail: fmt.Sprintf("inactive: %s", strings.Join(failures, ", "))}
	}
	return repair.HealthCheck{Name: "systemd-services", Pass: true, Detail: "containerd+kubelet active"}
}

// ── K8s checks ───────────────────────────────────────────────────────

func (w *UnifiedWatchdog) checkK8sNodes() repair.HealthCheck {
	cmd := exec.Command("kubectl", "get", "nodes", "--no-headers")
	out, err := cmd.Output()
	if err != nil {
		return repair.HealthCheck{Name: "k8s-nodes", Pass: false, Detail: fmt.Sprintf("cannot list nodes: %v", err)}
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
		return repair.HealthCheck{Name: "k8s-nodes", Pass: false,
			Detail: fmt.Sprintf("NotReady: %s", strings.Join(notReady, ", "))}
	}
	return repair.HealthCheck{Name: "k8s-nodes", Pass: true, Detail: fmt.Sprintf("%d nodes Ready", len(lines))}
}

func (w *UnifiedWatchdog) checkK8sPods() repair.HealthCheck {
	cmd := exec.Command("kubectl", "get", "pods", "--all-namespaces", "--no-headers",
		"--field-selector=status.phase!=Running,status.phase!=Succeeded")
	out, err := cmd.Output()
	if err != nil {
		return repair.HealthCheck{Name: "k8s-pods", Pass: false, Detail: fmt.Sprintf("cannot list pods: %v", err)}
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	nonRunning := 0
	for _, line := range lines {
		if strings.TrimSpace(line) != "" {
			nonRunning++
		}
	}
	if nonRunning > 0 {
		return repair.HealthCheck{Name: "k8s-pods", Pass: false,
			Detail: fmt.Sprintf("%d pods not Running/Succeeded", nonRunning)}
	}
	return repair.HealthCheck{Name: "k8s-pods", Pass: true, Detail: "all pods Running/Succeeded"}
}

// ── BOS ficha checks ──────────────────────────────────────────────────

func (w *UnifiedWatchdog) checkBOSFichas() []repair.HealthCheck {
	st, err := w.stateMgr.Read()
	if err != nil {
		return []repair.HealthCheck{{Name: "bos-state-read", Pass: false, Detail: fmt.Sprintf("state read failed: %v", err)}}
	}

	var results []repair.HealthCheck
	for name, ficha := range st.Fichas {
		if ficha.State == state.StatePendiente {
			continue
		}
		status := health.Status(ficha.HealthStatus)
		pass := status == health.StatusHealthy || status == health.StatusUnknown
		detail := fmt.Sprintf("state=%s health=%s", ficha.State, ficha.HealthStatus)
		if !pass {
			detail = fmt.Sprintf("DEGRADED: state=%s health=%s", ficha.State, ficha.HealthStatus)
		}
		results = append(results, repair.HealthCheck{
			Name:   fmt.Sprintf("ficha-%s", name),
			Pass:   pass,
			Detail: detail,
		})
	}
	return results
}

// ── Helpers ───────────────────────────────────────────────────────────

func (w *UnifiedWatchdog) sdNotify() {
	socketPath := os.Getenv("NOTIFY_SOCKET")
	if socketPath == "" {
		return
	}
	addr := &net.UnixAddr{Name: resolveAbstract(socketPath), Net: "unixgram"}
	conn, err := net.DialUnix("unixgram", nil, addr)
	if err != nil {
		return
	}
	defer conn.Close()
	conn.Write([]byte("WATCHDOG=1"))
}

func resolveAbstract(path string) string {
	if strings.HasPrefix(path, "@") {
		return "\x00" + path[1:]
	}
	return path
}

func countPass(checks []repair.HealthCheck) (pass, total int) {
	total = len(checks)
	for _, c := range checks {
		if c.Pass {
			pass++
		}
	}
	return
}
