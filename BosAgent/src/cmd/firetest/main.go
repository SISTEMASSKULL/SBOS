package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"bos/internal/health"
	"bos/internal/reconcile"
	"bos/internal/state"
	"log/slog"
)

var logger = slog.New(slog.NewTextHandler(os.Stderr, nil))
var passed, failed int

func check(name string, ok bool, detail string) {
	if ok {
		fmt.Printf("  ✓ %s: %s\n", name, detail)
		passed++
	} else {
		fmt.Printf("  ✗ %s: %s\n", name, detail)
		failed++
	}
}

func main() {
	fmt.Println("╔══════════════════════════════════════════════════╗")
	fmt.Println("║  PRUEBA DE FUEGO — BOS DAEMON                   ║")
	fmt.Println("║  Health Checker + Reconcile Scheduler           ║")
	fmt.Println("╚══════════════════════════════════════════════════╝")
	fmt.Println()

	tmpDir, _ := os.MkdirTemp("/tmp", "firetest-*")
	defer os.RemoveAll(tmpDir)

	serversDir := filepath.Join(tmpDir, "servers")
	statePath := filepath.Join(tmpDir, "state.json")

	fmt.Println("─ Setup ─────────────────────────────────────────────────")
	fmt.Printf("  servers: %s\n", serversDir)
	fmt.Printf("  state:   %s\n", statePath)

	// Pre-create all ficha directories and state JSON — must include Server
	createFichaDir(serversDir, "firesrv", "fire-svc", map[string]string{
		"manifest.yml":    "id: fire-svc\nversion: 1.0\nhealth:\n  check_command: \"curl -sf http://localhost:9999/health\"\n  check_interval_seconds: 5\n  check_timeout_seconds: 3\n  consecutive_failures_threshold: 2",
		"task_catalog.sh": "#!/bin/bash\n# TASK CATALOG v1.0\necho 'install'\necho 'health'\n",
		"yaml_engine.yml": "resources:\n  - name: config\n    type: deployment\n",
	})
	createFichaDir(serversDir, "firesrv", "zero-svc", map[string]string{
		"manifest.yml":    "id: zero-svc\nversion: 1.0\nhealth:\n  check_command: \"curl -sf --max-time 1 http://localhost:19999/health\"\n  check_interval_seconds: 5\n  check_timeout_seconds: 2\n  consecutive_failures_threshold: 3",
		"task_catalog.sh": "#!/bin/bash\necho ok\n",
		"yaml_engine.yml": "resources: []\n",
	})

	hashesFire, _ := reconcile.ComputeHashes(serversDir, "firesrv", "fire-svc")
	hashesZero, _ := reconcile.ComputeHashes(serversDir, "firesrv", "zero-svc")

	initial := state.SBOSState{
		Version:  "1.0.0",
		Hostname: "firetest",
		Fichas: map[string]*state.Ficha{
			"fire-svc": {Name: "fire-svc", Version: "1.0", State: state.StateInstalada, Server: "firesrv", Hashes: hashesFire},
			"zero-svc": {Name: "zero-svc", Version: "1.0", State: state.StateInstalada, Server: "firesrv", Hashes: hashesZero},
		},
		Meta: map[string]string{},
	}
	raw, _ := json.MarshalIndent(initial, "", "  ")
	os.WriteFile(statePath, raw, 0600)

	mgr, err := state.NewManager(statePath)
	if err != nil {
		fmt.Printf("FATAL: state manager: %v\n", err)
		os.Exit(1)
	}
	defer mgr.Close()

	// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	// ESCENARIO 1: Health Checker — detecta caída de servicio
	// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	fmt.Println()
	fmt.Println("═══ ESCENARIO 1: Health Checker detecta caída de servicio ═══")

	fmt.Println("1a. Iniciando servidor HTTP en :9999...")
	httpd := exec.Command("/usr/local/bin/firetest-httpd", "9999")
	httpd.Stdout = nil
	httpd.Stderr = nil
	if err := httpd.Start(); err != nil {
		fmt.Printf("  ✗ No se pudo iniciar firetest-httpd: %v\n", err)
		fmt.Println("  ¿Compilaste y copiaste firetest-httpd al contenedor?")
		os.Exit(1)
	}
	defer httpd.Process.Kill()
	time.Sleep(500 * time.Millisecond)

	resp, _ := exec.Command("curl", "-sf", "http://localhost:9999/health").CombinedOutput()
	check("HTTP server responde", strings.Contains(string(resp), "HEALTHY"), strings.TrimSpace(string(resp)))

	checker := health.NewChecker(mgr, 5*time.Second, serversDir, logger)

	fmt.Println()
	fmt.Println("1b. Health check con servicio UP...")
	r1 := checker.CheckNow()
	check("fire-svc → HEALTHY", r1["fire-svc"] == health.StatusHealthy, string(r1["fire-svc"]))

	fmt.Println()
	fmt.Println("1c. Matando servidor HTTP...")
	httpd.Process.Signal(syscall.SIGKILL)
	time.Sleep(300 * time.Millisecond)

	_, err = exec.Command("curl", "-sf", "--max-time", "2", "http://localhost:9999/health").CombinedOutput()
	check("Servidor HTTP caído confirmado", err != nil, "curl falla → servicio down")

	fmt.Println()
	fmt.Println("1d. Health check con servicio DOWN...")
	r2 := checker.CheckNow()
	check("fire-svc → DEGRADED (1er fallo)", r2["fire-svc"] == health.StatusDegraded, string(r2["fire-svc"]))

	fmt.Println()
	fmt.Println("1e. Segundo health check — escalamiento a DOWN...")
	r3 := checker.CheckNow()
	check("fire-svc → DOWN (2º fallo, threshold=2)", r3["fire-svc"] == health.StatusDown, string(r3["fire-svc"]))

	// Verify state file
	st, _ := mgr.Read()
	check("State: fire-svc health_status=DOWN", st.Fichas["fire-svc"].HealthStatus == "DOWN", st.Fichas["fire-svc"].HealthStatus)

	fmt.Println()
	fmt.Println("1f. Restaurando servidor y reseteando contadores...")
	httpd2 := exec.Command("/usr/local/bin/firetest-httpd", "9999")
	httpd2.Start()
	defer httpd2.Process.Kill()
	time.Sleep(400 * time.Millisecond)

	checker.ResetCounters("fire-svc")
	r4 := checker.CheckNow()
	check("fire-svc → HEALTHY (servicio restaurado)", r4["fire-svc"] == health.StatusHealthy, string(r4["fire-svc"]))

	st, _ = mgr.Read()
	check("State: fire-svc health_status=HEALTHY", st.Fichas["fire-svc"].HealthStatus == "HEALTHY", st.Fichas["fire-svc"].HealthStatus)

	httpd2.Process.Signal(syscall.SIGKILL)

	// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	// ESCENARIO 2: Reconcile — drift por archivo corrupto
	// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	fmt.Println()
	fmt.Println("═══ ESCENARIO 2: Reconcile detecta archivo corrupto (drift) ═══")

	sched := reconcile.NewScheduler(mgr, nil, 10*time.Second, serversDir, false, logger)

	fmt.Println("2a. Verificando sin drift inicial...")
	dr1 := sched.ReconcileNow()
	check("Sin drift", len(dr1) == 0, fmt.Sprintf("%d drifts", len(dr1)))

	fmt.Println()
	fmt.Println("2b. Inyectando backdoor en task_catalog.sh...")
	taskPath := filepath.Join(serversDir, "firesrv", "fire-svc", "task_catalog.sh")
	corrupted := "#!/bin/bash\n# TASK CATALOG v1.0\necho 'install'\n# !!DRIFT!! backdoor inyectada\necho 'reverse shell'\n"
	os.WriteFile(taskPath, []byte(corrupted), 0644)

	data, _ := os.ReadFile(taskPath)
	check("Archivo corrupto en disco", strings.Contains(string(data), "backdoor"), fmt.Sprintf("%d bytes", len(data)))

	fmt.Println()
	fmt.Println("2c. Ejecutando reconcile — debe detectar drift...")
	dr2 := sched.ReconcileNow()
	check("Drift detectado", len(dr2) >= 1, fmt.Sprintf("%d archivos con drift", len(dr2)))
	if len(dr2) > 0 {
		check("Archivo correcto señalado", dr2[0].File == "task_catalog.sh", dr2[0].File)
	}

	st, _ = mgr.Read()
	check("State: fire-svc → ACTUALIZACION_DISPONIBLE",
		st.Fichas["fire-svc"].State == state.StateActualizacionDisp,
		string(st.Fichas["fire-svc"].State))

	fmt.Println()
	fmt.Println("2d. Segundo reconcile sin cambios...")
	dr3 := sched.ReconcileNow()
	check("Sin drift nuevo", len(dr3) == 0, "hashes ya sincronizados")

	// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	// ESCENARIO 3: Health Checker — 0 réplicas (servicio inexistente)
	// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	fmt.Println()
	fmt.Println("═══ ESCENARIO 3: Health Checker — 0 réplicas (servicio nunca existe) ═══")

	// Use the existing checker (same mgr)
	checker3 := health.NewChecker(mgr, 5*time.Second, serversDir, logger)

	fmt.Println("3a. Simulando deployment con 0 réplicas...")
	fmt.Println("    (puerto 19999 sin servicio → 3 checks consecutivos)")

	var zeroStatuses []health.Status
	for i := 1; i <= 3; i++ {
		r := checker3.CheckNow()
		zeroStatuses = append(zeroStatuses, r["zero-svc"])
		fmt.Printf("    Check %d → %s\n", i, r["zero-svc"])
	}

	check("Check 1 → DEGRADED (1/3)", zeroStatuses[0] == health.StatusDegraded, string(zeroStatuses[0]))
	check("Check 2 → DEGRADED (2/3)", zeroStatuses[1] == health.StatusDegraded, string(zeroStatuses[1]))
	check("Check 3 → DOWN (3/3)", zeroStatuses[2] == health.StatusDown, string(zeroStatuses[2]))

	st, _ = mgr.Read()
	check("State: zero-svc health_status=DOWN", st.Fichas["zero-svc"].HealthStatus == "DOWN", st.Fichas["zero-svc"].HealthStatus)

	fmt.Println()
	fmt.Println("3b. Restaurando servicio (cambiando check a /bin/true)...")
	checker3.ResetCounters("zero-svc")
	createFichaDir(serversDir, "firesrv", "zero-svc", map[string]string{
		"manifest.yml":    "id: zero-svc\nversion: 1.0\nhealth:\n  check_command: \"/bin/true\"\n  check_interval_seconds: 5\n  check_timeout_seconds: 2\n  consecutive_failures_threshold: 3",
		"task_catalog.sh": "#!/bin/bash\necho ok\n",
		"yaml_engine.yml": "resources: []\n",
	})
	rFinal := checker3.CheckNow()
	check("zero-svc → HEALTHY (servicio restaurado)", rFinal["zero-svc"] == health.StatusHealthy, string(rFinal["zero-svc"]))

	// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	// RESULTADO
	// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	fmt.Println()
	fmt.Println("╔══════════════════════════════════════════════════╗")
	if failed > 0 {
		fmt.Printf("║  RESULTADO: %d PASS / %d FAIL  ⚠️               ║\n", passed, failed)
	} else {
		fmt.Printf("║  RESULTADO: %d PASS / %d FAIL  ✓                ║\n", passed, failed)
	}
	fmt.Println("╚══════════════════════════════════════════════════╝")
	if failed > 0 {
		os.Exit(1)
	}
}

func createFichaDir(base, server, name string, files map[string]string) {
	dir := filepath.Join(base, server, name)
	os.MkdirAll(dir, 0755)
	for fname, content := range files {
		os.WriteFile(filepath.Join(dir, fname), []byte(content), 0644)
	}
}
