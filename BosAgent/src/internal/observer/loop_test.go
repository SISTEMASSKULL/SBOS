// Package observer — tests T8.1 (F8): loop de observación con dependencias
// reales en TempDir (state.Manager con flock, plugin.Loader con ficha de
// prueba, installer.Orchestrator con master script fake). Sin root, sin K8s.
package observer

import (
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"testing"
	"time"

	"bos/internal/health"
	"bos/internal/installer"
	"bos/internal/plugin"
	"bos/internal/state"
)

// crearFicha fabrica una ficha mínima válida (task_catalog.sh + manifest.yml)
// dentro de serversDir. deps en formato YAML de lista inline-block.
func crearFicha(t *testing.T, serversDir, id string, autoInstall bool, order int, deps []string) {
	t.Helper()
	dir := filepath.Join(serversDir, "testsrv", id)
	if err := os.MkdirAll(dir, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "task_catalog.sh"),
		[]byte("#!/bin/bash\nexit 0\n"), 0755); err != nil {
		t.Fatal(err)
	}
	manifest := "identity:\n  server: testsrv\n  version: 1.0.0\norder:\n  execution_order: " +
		itoa(order) + "\ngovernance:\n  auto_install: " + boolStr(autoInstall) + "\n"
	if len(deps) > 0 {
		manifest += "requirements:\n  dependencies:\n"
		for _, d := range deps {
			manifest += "    - " + d + "\n"
		}
	}
	if err := os.WriteFile(filepath.Join(dir, "manifest.yml"), []byte(manifest), 0644); err != nil {
		t.Fatal(err)
	}
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	out := ""
	for n > 0 {
		out = string(rune('0'+n%10)) + out
		n /= 10
	}
	return out
}

func boolStr(b bool) string {
	if b {
		return "true"
	}
	return "false"
}

// entornoTest construye loader+state+orchestrator reales en TempDir.
// masterExit controla el exit code del master script fake.
func entornoTest(t *testing.T, masterExit int) (*plugin.Loader, *state.Manager, *installer.Orchestrator) {
	t.Helper()
	dir := t.TempDir()

	serversDir := filepath.Join(dir, "servers")
	crearFicha(t, serversDir, "ficha-a", true, 100, nil)

	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	loader := plugin.NewLoader(serversDir, logger)
	if _, err := loader.Scan(); err != nil {
		t.Fatal(err)
	}

	stateMgr, err := state.NewManager(filepath.Join(dir, "state.json"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { stateMgr.Close() })

	master := filepath.Join(dir, "master.sh")
	script := "#!/bin/bash\nexit " + itoa(masterExit) + "\n"
	if err := os.WriteFile(master, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}
	orch := installer.NewOrchestrator(master, dir, 10*time.Second, logger)

	return loader, stateMgr, orch
}

// TestNew_IntervalPorDefecto: Interval 0 → 5s (contrato del constructor).
func TestNew_IntervalPorDefecto(t *testing.T) {
	loop := New(Config{})
	if loop.cfg.Interval != 5*time.Second {
		t.Errorf("interval por defecto: want 5s, got %v", loop.cfg.Interval)
	}
	loop2 := New(Config{Interval: time.Millisecond})
	if loop2.cfg.Interval != time.Millisecond {
		t.Error("interval explícito debe respetarse")
	}
}

// TestLoop_InstalaFichaYSeDetiene: ciclo completo del observer — la ficha
// auto_install sin deps arranca LISTA, el tick la instala (master exit 0)
// y queda INSTALADA. Stop() detiene el loop y es idempotente.
func TestLoop_InstalaFichaYSeDetiene(t *testing.T) {
	loader, stateMgr, orch := entornoTest(t, 0)

	InitializeFichaStates(loader, stateMgr)

	st, _ := stateMgr.Read()
	if st.Fichas["ficha-a"].State != state.StateLista {
		t.Fatalf("auto_install sin deps debe arrancar LISTA, got %s", st.Fichas["ficha-a"].State)
	}

	loop := New(Config{
		Orchestrator: orch,
		Loader:       loader,
		StateMgr:     stateMgr,
		Interval:     20 * time.Millisecond,
	})
	done := make(chan struct{})
	go func() { loop.Run(); close(done) }()

	// esperar a que el tick instale la ficha
	deadline := time.After(3 * time.Second)
	for {
		st, _ := stateMgr.Read()
		if st.Fichas["ficha-a"].State == state.StateInstalada {
			break
		}
		select {
		case <-deadline:
			t.Fatalf("la ficha no llegó a INSTALADA: %s", st.Fichas["ficha-a"].State)
		case <-time.After(10 * time.Millisecond):
		}
	}

	loop.Stop()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("Run() no retornó tras Stop()")
	}
	loop.Stop() // idempotente — no debe entrar en pánico
}

// TestLoop_FallaInstalacion: master script exit 1 → la ficha termina en
// FALLA_INSTALACION (ADR-021 #3→#13), no en INSTALADA.
func TestLoop_FallaInstalacion(t *testing.T) {
	loader, stateMgr, orch := entornoTest(t, 1)
	InitializeFichaStates(loader, stateMgr)

	loop := New(Config{
		Orchestrator: orch,
		Loader:       loader,
		StateMgr:     stateMgr,
		Interval:     20 * time.Millisecond,
	})
	done := make(chan struct{})
	go func() { loop.Run(); close(done) }()
	defer func() { loop.Stop(); <-done }()

	deadline := time.After(3 * time.Second)
	for {
		st, _ := stateMgr.Read()
		if st.Fichas["ficha-a"].State == state.StateFallaInstalacion {
			return // ✅
		}
		select {
		case <-deadline:
			t.Fatalf("want FALLA_INSTALACION, got %s", st.Fichas["ficha-a"].State)
		case <-time.After(10 * time.Millisecond):
		}
	}
}

// TestInitializeFichaStates_EstadosIniciales: con deps → PENDIENTE;
// sin deps + auto_install → LISTA; sin auto_install → PENDIENTE.
func TestInitializeFichaStates_EstadosIniciales(t *testing.T) {
	dir := t.TempDir()
	serversDir := filepath.Join(dir, "servers")
	crearFicha(t, serversDir, "base", true, 10, nil)
	crearFicha(t, serversDir, "dependiente", true, 20, []string{"base"})
	crearFicha(t, serversDir, "opcional", false, 30, nil)

	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	loader := plugin.NewLoader(serversDir, logger)
	if _, err := loader.Scan(); err != nil {
		t.Fatal(err)
	}
	stateMgr, err := state.NewManager(filepath.Join(dir, "state.json"))
	if err != nil {
		t.Fatal(err)
	}
	defer stateMgr.Close()

	InitializeFichaStates(loader, stateMgr)

	st, _ := stateMgr.Read()
	if got := st.Fichas["base"].State; got != state.StateLista {
		t.Errorf("base (auto, sin deps): want LISTA, got %s", got)
	}
	if got := st.Fichas["dependiente"].State; got != state.StatePendiente {
		t.Errorf("dependiente (auto, con deps): want PENDIENTE, got %s", got)
	}
	if got := st.Fichas["opcional"].State; got != state.StatePendiente {
		t.Errorf("opcional (sin auto): want PENDIENTE, got %s", got)
	}
}

// TestStartupReconcile_Ramas: sin K8s registrado retorna temprano; con K8s
// INSTALADA y kubelet caído dispara CheckNow sin jitter.
func TestStartupReconcile_Ramas(t *testing.T) {
	dir := t.TempDir()
	stateMgr, err := state.NewManager(filepath.Join(dir, "state.json"))
	if err != nil {
		t.Fatal(err)
	}
	defer stateMgr.Close()

	// rama 1: sin sbos-bootstrap-k8s → retorno temprano (healthChecker nil
	// es seguro porque no se llega a usar)
	StartupReconcile(stateMgr, nil, func(action, service string) error { return nil })

	// rama 2: K8s INSTALADA + kubelet inactivo → CheckNow inmediato (sin jitter)
	if err := stateMgr.Register("sbos-bootstrap-k8s", state.StateInstalada,
		"1.32", true, "hostserver", 1, "bash"); err != nil {
		t.Fatal(err)
	}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	hc := health.NewChecker(stateMgr, time.Minute, filepath.Join(dir, "servers"), logger)

	llamado := false
	systemctlCaido := func(action, service string) error {
		llamado = true
		return os.ErrNotExist // kubelet inactivo → sin jitter
	}
	StartupReconcile(stateMgr, hc, systemctlCaido)
	if !llamado {
		t.Error("StartupReconcile debe consultar systemctl is-active kubelet")
	}
}
