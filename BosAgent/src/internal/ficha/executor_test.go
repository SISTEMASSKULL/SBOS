package ficha

import (
	"strings"
	"testing"
	"time"
)

func TestPhaseOrder(t *testing.T) {
	phases := PhaseOrder()
	if len(phases) != 5 {
		t.Fatalf("esperado 5 fases, obtenido %d", len(phases))
	}
	expected := []Phase{PhasePreInstall, PhaseInstall, PhasePostInstall, PhaseVerify, PhaseCommit}
	for i, p := range phases {
		if p != expected[i] {
			t.Errorf("fase[%d]: esperado %s, obtenido %s", i, expected[i], p)
		}
	}
}

func TestDefaultPhaseConfigs(t *testing.T) {
	tests := []struct {
		workload     string
		expectInstall time.Duration
	}{
		{"StatefulSet", 10 * time.Minute},
		{"Deployment", 5 * time.Minute},
		{"DaemonSet", 5 * time.Minute},
		{"bash", 2 * time.Minute},
		{"", 5 * time.Minute}, // default
	}

	for _, tt := range tests {
		configs := DefaultPhaseConfigs(tt.workload)
		if len(configs) != 5 {
			t.Errorf("%s: esperado 5 fases, obtenido %d", tt.workload, len(configs))
			continue
		}
		// La fase install es la segunda (índice 1)
		installPhase := configs[1]
		if installPhase.Timeout != tt.expectInstall {
			t.Errorf("%s: timeout install esperado %v, obtenido %v",
				tt.workload, tt.expectInstall, installPhase.Timeout)
		}
		if installPhase.Phase != PhaseInstall {
			t.Errorf("%s: esperado PhaseInstall, obtenido %s", tt.workload, installPhase.Phase)
		}
	}
}

func TestOnFailurePolicies(t *testing.T) {
	// pre_install + install: abort
	// post_install: continue
	// verify + commit: abort
	configs := DefaultPhaseConfigs("Deployment")

	if configs[0].OnFail != OnFailureAbort {
		t.Error("pre_install debe ser abort")
	}
	if configs[1].OnFail != OnFailureAbort {
		t.Error("install debe ser abort")
	}
	if configs[2].OnFail != OnFailureContinue {
		t.Error("post_install debe ser continue")
	}
	if configs[3].OnFail != OnFailureAbort {
		t.Error("verify debe ser abort")
	}
	if configs[4].OnFail != OnFailureAbort {
		t.Error("commit debe ser abort")
	}
}

func TestParsePhaseSignals(t *testing.T) {
	input := `__SBOS__STEP_START__ pre_install
__SBOS__STEP_OK__ pre_install
__SBOS__STEP_START__ install
Some output from install
__SBOS__STEP_OK__ install
__SBOS__STEP_START__ post_install
__SBOS__STEP_SKIP__ post_install (funcion no definida)
`
	steps, output := parsePhaseSignals(strings.NewReader(input))

	if len(steps) != 6 {
		t.Fatalf("esperado 6 pasos (señales), obtenido %d: %v", len(steps), steps)
	}

	expectedSteps := []string{
		"▶ pre_install",
		"✓ pre_install",
		"▶ install",
		"✓ install",
		"▶ post_install",
		"○ post_install (funcion no definida)",
	}
	for i, expected := range expectedSteps {
		if i >= len(steps) {
			break
		}
		if steps[i] != expected {
			t.Errorf("paso[%d]: esperado %q, obtenido %q", i, expected, steps[i])
		}
	}

	if !strings.Contains(output, "Some output from install") {
		t.Error("output debe contener las líneas no-señal")
	}
}

func TestParsePhaseSignals_Failure(t *testing.T) {
	input := `__SBOS__STEP_START__ pre_install
__SBOS__STEP_FAIL__ pre_install
`
	steps, _ := parsePhaseSignals(strings.NewReader(input))

	if len(steps) != 2 {
		t.Fatalf("esperado 2 pasos, obtenido %d", len(steps))
	}
	if steps[1] != "✗ pre_install" {
		t.Errorf("esperado ✗ pre_install, obtenido %s", steps[1])
	}
}

func TestBuildPhaseScript(t *testing.T) {
	script := buildPhaseScript("install", "postgresql", "install", "/servers/S01/postgresql")

	// Debe contener los elementos clave
	assertions := []string{
		"__SBOS__STEP_START__",
		"__SBOS__STEP_OK__",
		"__SBOS__STEP_FAIL__",
		"__SBOS__STEP_SKIP__",
		"FICHA_ID=\"postgresql\"",
		"FICHA_COMMAND=\"install\"",
		"/servers/S01/postgresql/task_catalog.sh",
		"ficha_install",
		"declare -f ficha_install",
	}

	for _, a := range assertions {
		if !strings.Contains(script, a) {
			t.Errorf("script debe contener %q", a)
		}
	}
}

func TestBuildPhaseScript_SkipWhenMissing(t *testing.T) {
	// Si la función de fase no está definida, el script debe emitir SKIP
	script := buildPhaseScript("verify", "redis", "install", "/servers/S01/redis")

	if !strings.Contains(script, "__SBOS__STEP_SKIP__") {
		t.Error("script debe emitir SKIP cuando la función no existe")
	}
	if !strings.Contains(script, "funcion no definida") {
		t.Error("mensaje de skip debe indicar función no definida")
	}
}

func TestExecutionResult_PhaseSummary(t *testing.T) {
	result := &ExecutionResult{
		FichaID: "postgresql",
		Command: "install",
		Success: true,
		Phases: []PhaseResult{
			{Phase: PhasePreInstall, Status: "ok", Duration: 100 * time.Millisecond},
			{Phase: PhaseInstall, Status: "ok", Duration: 3 * time.Second},
			{Phase: PhasePostInstall, Status: "skip", Duration: 0},
			{Phase: PhaseVerify, Status: "ok", Duration: 500 * time.Millisecond},
			{Phase: PhaseCommit, Status: "ok", Duration: 50 * time.Millisecond},
		},
	}

	summary := result.PhaseSummary()
	if !strings.Contains(summary, "postgresql") {
		t.Error("summary debe contener el ficha_id")
	}
	if !strings.Contains(summary, "✓") {
		t.Error("summary debe contener ✓ para fases ok")
	}
	if !strings.Contains(summary, "○") {
		t.Error("summary debe contener ○ para fases skip")
	}
}

func TestFailedPhases(t *testing.T) {
	result := &ExecutionResult{
		FichaID: "test",
		Phases: []PhaseResult{
			{Phase: PhasePreInstall, Status: "ok"},
			{Phase: PhaseInstall, Status: "fail", Error: "timeout"},
			{Phase: PhasePostInstall, Status: "ok"},
		},
	}

	failed := result.FailedPhases()
	if len(failed) != 1 {
		t.Fatalf("esperado 1 fase fallida, obtenido %d", len(failed))
	}
	if failed[0].Phase != PhaseInstall {
		t.Errorf("esperado PhaseInstall, obtenido %s", failed[0].Phase)
	}
}

func TestPhaseObserverEvents(t *testing.T) {
	var events []PhaseEvent
	observer := func(e PhaseEvent) {
		events = append(events, e)
	}

	exec := NewExecutor(DefaultPhaseConfigs("Deployment"), observer, nil)

	if exec == nil {
		t.Fatal("NewExecutor no debe retornar nil")
	}

	// Emitir un evento manual para verificar que el observer lo recibe
	exec.emit(PhaseEvent{
		FichaID: "test",
		Phase:   PhasePreInstall,
		Event:   "started",
	})

	if len(events) != 1 {
		t.Fatalf("esperado 1 evento, obtenido %d", len(events))
	}
	if events[0].FichaID != "test" || events[0].Phase != PhasePreInstall || events[0].Event != "started" {
		t.Error("evento no coincide con lo emitido")
	}
}
