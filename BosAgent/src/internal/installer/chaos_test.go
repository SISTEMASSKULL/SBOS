// Package installer — test T8.7 (F8): chaos mínimo de saga.
//
// Simula la interrupción abrupta de una saga de instalación a mitad de sus
// pasos (equivalente observable de un kill durante la saga: el script muere
// con pasos a medias) y verifica el principio de reversibilidad de ADR-021:
// la cadena de compensación se ejecuta SIEMPRE tras el fallo (P6/P12).
//
// El chaos completo del plan (kill -9 al daemon + recuperación del
// SagaEngine desde /var/lib/bos/ai/sagas/) requiere la persistencia de
// sagas de biaos (F10.17/F10.19) — se completará en la Fase 10.
package installer

import (
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// TestChaos_SagaInterrumpidaCompensa: master script que muere a mitad de la
// saga (paso 1 OK, paso 2 FAIL + exit 1) → el Orchestrator reporta el fallo
// con los pasos parseados Y ejecuta la compensación (remove), dejando
// constancia verificable. P15: la compensación usa "remove", no "uninstall"
// (el master script no reconoce "uninstall"; "remove" incluye governance check).
func TestChaos_SagaInterrumpidaCompensa(t *testing.T) {
	dir := t.TempDir()
	testigo := filepath.Join(dir, "compensacion-ejecutada")

	// El master script simula: install muere a mitad; remove (la
	// compensación de P15) deja un archivo testigo.
	master := filepath.Join(dir, "master.sh")
	script := `#!/bin/bash
cmd="$1"
if [ "$cmd" = "install" ]; then
  echo "__SBOS__STEP_START__ preparar"
  echo "__SBOS__STEP_OK__ preparar"
  echo "__SBOS__STEP_START__ desplegar"
  echo "__SBOS__STEP_FAIL__ desplegar"
  exit 1
fi
if [ "$cmd" = "remove" ]; then
  touch "` + testigo + `"
  exit 0
fi
exit 0
`
	if err := os.WriteFile(master, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}

	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	orch := NewOrchestrator(master, dir, 30*time.Second, logger)
	// mismo cableado que producción (cmd/bos/run_normal.go) — P6
	orch.SetCompensator(NewCompensator(master, logger))

	result, err := orch.Install("ficha-chaos", "1.0.0")
	if err != nil {
		t.Fatalf("Install no debe retornar error Go (el fallo va en result): %v", err)
	}

	// 1. El fallo queda reportado con exit code real
	if result.Success {
		t.Error("la saga interrumpida no puede reportar éxito")
	}
	if result.ExitCode != 1 {
		t.Errorf("exit code: want 1, got %d", result.ExitCode)
	}

	// 2. Los pasos hasta la interrupción quedaron registrados (protocolo de señales)
	if len(result.Steps) < 2 {
		t.Fatalf("deben registrarse los pasos hasta el fallo: %+v", result.Steps)
	}
	fallidos := result.FailedSteps()
	if len(fallidos) != 1 {
		t.Errorf("want 1 paso fallido (desplegar), got %d", len(fallidos))
	}

	// 3. La compensación se ejecutó (P6 — toda saga tiene compensación)
	if _, err := os.Stat(testigo); err != nil {
		t.Error("la cadena de compensación (uninstall) debe ejecutarse tras el fallo")
	}
}

// TestChaos_SagaExitosaNoCompensa: el camino feliz nunca dispara compensación.
func TestChaos_SagaExitosaNoCompensa(t *testing.T) {
	dir := t.TempDir()
	testigo := filepath.Join(dir, "no-deberia-existir")

	master := filepath.Join(dir, "master.sh")
	script := `#!/bin/bash
if [ "$1" = "install" ]; then
  echo "__SBOS__STEP_START__ unico"
  echo "__SBOS__STEP_OK__ unico"
  exit 0
fi
touch "` + testigo + `"
exit 0
`
	if err := os.WriteFile(master, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}

	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	orch := NewOrchestrator(master, dir, 30*time.Second, logger)
	orch.SetCompensator(NewCompensator(master, logger))

	result, err := orch.Install("ficha-ok", "1.0.0")
	if err != nil || !result.Success {
		t.Fatalf("saga exitosa: err=%v result=%+v", err, result)
	}
	if _, err := os.Stat(testigo); err == nil {
		t.Error("una saga exitosa no debe disparar compensación")
	}
}

// TestSelectChain_PorComando: install tiene cadena Go-level; update/repair tienen
// cadenas vacías porque el bash gestiona su propio rollback interno (P15):
//   - install falla → "remove" limpia la ficha (compensación Go).
//   - update falla  → cmd_update() llama restore_ficha_resources() antes de exit 3 (bash).
//   - repair falla  → cmd_repair() gestiona su propio fallo (bash).
//
// Comandos de lectura (status, probe) nunca tienen compensación.
func TestSelectChain_PorComando(t *testing.T) {
	// Install debe tener exactamente 1 acción Go-level (remove)
	installChain := SelectChain(CmdInstall)
	if len(installChain.Actions) != 1 {
		t.Errorf("install debe tener 1 acción de compensación Go-level (remove), got %d", len(installChain.Actions))
	}
	if len(installChain.Actions) == 1 && installChain.Actions[0].Handler != "remove" {
		t.Errorf("install compensation handler debe ser 'remove', got %q", installChain.Actions[0].Handler)
	}

	// Update y Repair tienen cadenas vacías — P15: el bash gestiona rollback interno
	for _, cmd := range []Command{CmdUpdate, CmdRepair} {
		chain := SelectChain(cmd)
		if len(chain.Actions) != 0 {
			t.Errorf("%s debe tener cadena vacía (bash gestiona rollback interno — P15), got %d acciones",
				cmd, len(chain.Actions))
		}
	}

	// Comandos de lectura nunca tienen compensación
	if len(ChainForSaga(Command("status")).Actions) != 0 {
		t.Error("comandos de lectura no tienen compensación")
	}
}

// TestSagas_WrappersYObservadores: update/repair/remove/probe delegan en el
// mismo motor execute; los observadores reciben los eventos de paso.
func TestSagas_WrappersYObservadores(t *testing.T) {
	dir := t.TempDir()
	master := filepath.Join(dir, "master.sh")
	script := `#!/bin/bash
echo "__SBOS__STEP_START__ unico"
echo "__SBOS__STEP_OK__ unico"
exit 0
`
	if err := os.WriteFile(master, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	orch := NewOrchestrator(master, dir, 30*time.Second, logger)

	var pasos, lineas int
	orch.SetObserver(func(Step) { pasos++ })
	orch.SetLogObserver(func(string, string) { lineas++ })

	type saga func() (*SagaResult, error)
	for nombre, fn := range map[string]saga{
		"update": func() (*SagaResult, error) { return orch.Update("f", "1.0") },
		"repair": func() (*SagaResult, error) { return orch.Repair("f") },
		"remove": func() (*SagaResult, error) { return orch.Remove("f") },
		"probe":  func() (*SagaResult, error) { return orch.Probe("f") },
	} {
		r, err := fn()
		if err != nil || !r.Success {
			t.Errorf("%s: err=%v success=%v", nombre, err, r != nil && r.Success)
		}
	}
	if pasos == 0 {
		t.Error("el StepObserver debe recibir eventos de paso")
	}

	// TimeoutForCommand delega en la configuración inyectada
	cfg := timeoutCfgStub{}
	if got := orch.TimeoutForCommand(CmdInstall, cfg); got != 42*time.Minute {
		t.Errorf("TimeoutForCommand debe delegar en cfg: got %v", got)
	}
}

// timeoutCfgStub satisface el puerto de configuración de timeouts de saga.
type timeoutCfgStub struct{}

func (timeoutCfgStub) SagaTimeout(string) time.Duration { return 42 * time.Minute }
