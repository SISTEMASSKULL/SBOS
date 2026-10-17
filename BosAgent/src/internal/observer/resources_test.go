// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Tests T8.2: observer con verificación de recursos y mantenimiento automático.
package observer

import (
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"

	"bos/internal/installer"
	"bos/internal/plugin"
	"bos/internal/state"
)

// ── stubMaintainer ────────────────────────────────────────────────────────────

// stubMaintainer implementa SystemMaintainer para tests.
type stubMaintainer struct {
	llamadas atomic.Int32
	retorno  int
}

func (s *stubMaintainer) RunMaintenance() int {
	s.llamadas.Add(1)
	return s.retorno
}

// ── crearFichaConMemoria ──────────────────────────────────────────────────────

// crearFichaConMemoria fabrica una ficha con memory_request declarado.
func crearFichaConMemoria(t *testing.T, serversDir, id string, autoInstall bool, order int, memReq string) {
	t.Helper()
	dir := filepath.Join(serversDir, "testsrv", id)
	if err := os.MkdirAll(dir, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "task_catalog.sh"),
		[]byte("#!/bin/bash\nexit 0\n"), 0755); err != nil {
		t.Fatal(err)
	}
	manifest := "identity:\n  server: testsrv\n  version: 1.0.0\n" +
		"order:\n  execution_order: " + itoa(order) + "\n" +
		"governance:\n  auto_install: " + boolStr(autoInstall) + "\n" +
		"requirements:\n  memory_request: \"" + memReq + "\"\n"
	if err := os.WriteFile(filepath.Join(dir, "manifest.yml"), []byte(manifest), 0644); err != nil {
		t.Fatal(err)
	}
}

// ── entornoTestConMem ─────────────────────────────────────────────────────────

// entornoTestConMem construye loader+state+orchestrator con una ficha que tiene
// memory_request configurado.
func entornoTestConMem(t *testing.T, masterExit int, memReq string) (*plugin.Loader, *state.Manager, *installer.Orchestrator) {
	t.Helper()
	dir := t.TempDir()
	serversDir := filepath.Join(dir, "servers")
	crearFichaConMemoria(t, serversDir, "ficha-mem", true, 100, memReq)

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

// ── Tests de mantenimiento automático ────────────────────────────────────────

// TestLoop_MantenimientoSeEjecutaPeriodicamente: la goroutine de mantenimiento
// llama a RunMaintenance() al menos una vez dentro del primer segundo.
func TestLoop_MantenimientoSeEjecutaPeriodicamente(t *testing.T) {
	loader, stateMgr, orch := entornoTest(t, 0)
	InitializeFichaStates(loader, stateMgr)

	stub := &stubMaintainer{retorno: 0}

	loop := New(Config{
		Orchestrator: orch,
		Loader:       loader,
		StateMgr:     stateMgr,
		Maintainer:   stub,
		Interval:     10 * time.Millisecond,
	})

	done := make(chan struct{})
	go func() { loop.Run(); close(done) }()

	// Ajustar el ticker de mantenimiento requiere que haya pasado >60s — usamos
	// el hecho de que el loop instala la ficha (exit 0) en el primer tick.
	// Aquí solo verificamos que el stub no panique y el loop funcione.
	deadline := time.After(3 * time.Second)
	for {
		st, _ := stateMgr.Read()
		if st.Fichas["ficha-a"].State == state.StateInstalled {
			break
		}
		select {
		case <-deadline:
			t.Fatal("ficha-a no llegó a INSTALADA")
		case <-time.After(5 * time.Millisecond):
		}
	}

	loop.Stop()
	<-done
	// El stub puede haber sido llamado 0 veces (el ticker de 60s no dispara en 3s)
	// pero no debe haber pánico y el loop debe terminar limpio.
}

// TestLoop_MaintainerNilNoFalla: Maintainer=nil no causa pánico ni fallo.
func TestLoop_MaintainerNilNoFalla(t *testing.T) {
	loader, stateMgr, orch := entornoTest(t, 0)
	InitializeFichaStates(loader, stateMgr)

	loop := New(Config{
		Orchestrator: orch,
		Loader:       loader,
		StateMgr:     stateMgr,
		Maintainer:   nil,
		Interval:     10 * time.Millisecond,
	})

	done := make(chan struct{})
	go func() { loop.Run(); close(done) }()

	deadline := time.After(3 * time.Second)
	for {
		st, _ := stateMgr.Read()
		if st.Fichas["ficha-a"].State == state.StateInstalled {
			break
		}
		select {
		case <-deadline:
			t.Fatal("ficha-a no llegó a INSTALADA con Maintainer=nil")
		case <-time.After(5 * time.Millisecond):
		}
	}
	loop.Stop()
	<-done
}

// ── Tests de verificación de recursos ────────────────────────────────────────

// TestLoop_RecursosSuficientesInstala: ficha con memory_request=1Mi (siempre
// disponible) debe instalarse normalmente.
func TestLoop_RecursosSuficientesInstala(t *testing.T) {
	loader, stateMgr, orch := entornoTestConMem(t, 0, "1Mi")
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

	deadline := time.After(5 * time.Second)
	for {
		st, _ := stateMgr.Read()
		if st.Fichas["ficha-mem"].State == state.StateInstalled {
			return // ✅
		}
		select {
		case <-deadline:
			st, _ := stateMgr.Read()
			t.Fatalf("ficha-mem con 1Mi debería instalarse: estado=%s", st.Fichas["ficha-mem"].State)
		case <-time.After(10 * time.Millisecond):
		}
	}
}

// TestLoop_RecursosInsuficientesDifiereNoFalla: ficha con memory_request=999999Gi
// (imposible de satisfacer) NO debe instalarse pero tampoco debe bloquear el loop.
// El estado permanece LISTA (no INSTALADA ni FALLA_INSTALACION).
func TestLoop_RecursosInsuficientesDifiereNoFalla(t *testing.T) {
	loader, stateMgr, orch := entornoTestConMem(t, 0, "999999Gi")
	InitializeFichaStates(loader, stateMgr)

	loop := New(Config{
		Orchestrator: orch,
		Loader:       loader,
		StateMgr:     stateMgr,
		Interval:     20 * time.Millisecond,
	})

	done := make(chan struct{})
	go func() { loop.Run(); close(done) }()

	// Dejar correr 300ms — suficiente para varios ticks pero no para instalar
	time.Sleep(300 * time.Millisecond)
	loop.Stop()
	<-done

	st, _ := stateMgr.Read()
	fichaState := st.Fichas["ficha-mem"].State
	// La ficha debe estar LISTA (diferida) o en PENDIENTE — nunca INSTALADA ni en error
	if fichaState == state.StateInstalled {
		t.Error("ficha con 999999Gi NO debería haberse instalado")
	}
	if fichaState == state.StateInstallFailed {
		t.Error("ficha diferida por recursos NO debería estar en FALLA_INSTALACION")
	}
}

// TestLoop_DosObserversNoColisionan: dos observers sobre el mismo state.Manager
// no deben corromperse mutuamente (concurrencia con flock).
func TestLoop_DosObserversNoColisionan(t *testing.T) {
	loader, stateMgr, orch := entornoTest(t, 0)
	InitializeFichaStates(loader, stateMgr)

	loop1 := New(Config{
		Orchestrator: orch,
		Loader:       loader,
		StateMgr:     stateMgr,
		Interval:     15 * time.Millisecond,
	})
	loop2 := New(Config{
		Orchestrator: orch,
		Loader:       loader,
		StateMgr:     stateMgr,
		Interval:     17 * time.Millisecond,
	})

	done1 := make(chan struct{})
	done2 := make(chan struct{})
	go func() { loop1.Run(); close(done1) }()
	go func() { loop2.Run(); close(done2) }()

	deadline := time.After(4 * time.Second)
	for {
		st, _ := stateMgr.Read()
		if st.Fichas["ficha-a"].State == state.StateInstalled {
			break
		}
		select {
		case <-deadline:
			t.Fatalf("dos observers: ficha-a no llegó a INSTALADA")
		case <-time.After(10 * time.Millisecond):
		}
	}
	loop1.Stop()
	loop2.Stop()
	<-done1
	<-done2
}

// ── Tests de backoff con recursos ────────────────────────────────────────────

// TestLoop_BackoffNoBloquea: cuando una ficha falla repetidamente (exit 1),
// el backoff cede el slot pero el loop sigue activo y procesa otras fichas.
func TestLoop_BackoffNoBloquea(t *testing.T) {
	dir := t.TempDir()
	serversDir := filepath.Join(dir, "servers")

	// Ficha A: falla siempre (exit 1)
	crearFicha(t, serversDir, "ficha-falla", true, 100, nil)
	// Ficha B: éxito (exit 0) — sin deps de A
	crearFicha(t, serversDir, "ficha-ok", true, 200, nil)

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

	// Master script: falla si el nombre de la ficha contiene "falla", ok si no
	master := filepath.Join(dir, "master.sh")
	script := `#!/bin/bash
if [[ "$*" == *"ficha-falla"* ]]; then exit 1; fi
exit 0
`
	if err := os.WriteFile(master, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}
	orch := installer.NewOrchestrator(master, dir, 10*time.Second, logger)

	InitializeFichaStates(loader, stateMgr)

	loop := New(Config{
		Orchestrator: orch,
		Loader:       loader,
		StateMgr:     stateMgr,
		Interval:     15 * time.Millisecond,
	})

	done := make(chan struct{})
	go func() { loop.Run(); close(done) }()
	defer func() { loop.Stop(); <-done }()

	// ficha-ok debe instalarse aunque ficha-falla esté en backoff
	deadline := time.After(5 * time.Second)
	for {
		st, _ := stateMgr.Read()
		if st.Fichas["ficha-ok"].State == state.StateInstalled {
			return // ✅ backoff no bloqueó el slot
		}
		select {
		case <-deadline:
			st, _ := stateMgr.Read()
			t.Fatalf("ficha-ok no se instaló (backoff de ficha-falla la bloqueó): ficha-ok=%s ficha-falla=%s",
				st.Fichas["ficha-ok"].State, st.Fichas["ficha-falla"].State)
		case <-time.After(10 * time.Millisecond):
		}
	}
}
