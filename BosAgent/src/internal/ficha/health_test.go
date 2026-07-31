package ficha

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

func TestHealthTracker_Record(t *testing.T) {
	tracker := NewHealthTracker()

	// Primer fallo — no debe degradar
	if tracker.Record("test", false, 3) {
		t.Error("1er fallo no debe degradar")
	}
	if tracker.ConsecutiveFailures("test") != 1 {
		t.Errorf("esperado 1 fallo, obtenido %d", tracker.ConsecutiveFailures("test"))
	}

	// Segundo fallo — no debe degradar
	if tracker.Record("test", false, 3) {
		t.Error("2do fallo no debe degradar")
	}

	// Tercer fallo — DEBE degradar
	if !tracker.Record("test", false, 3) {
		t.Error("3er fallo DEBE degradar")
	}
	if tracker.ConsecutiveFailures("test") != 3 {
		t.Errorf("esperado 3 fallos, obtenido %d", tracker.ConsecutiveFailures("test"))
	}
}

func TestHealthTracker_Recovery(t *testing.T) {
	tracker := NewHealthTracker()

	// 2 fallos
	tracker.Record("test", false, 3)
	tracker.Record("test", false, 3)
	if tracker.ConsecutiveFailures("test") != 2 {
		t.Errorf("esperado 2 fallos, obtenido %d", tracker.ConsecutiveFailures("test"))
	}

	// 1 éxito — resetea el contador
	if tracker.Record("test", true, 3) {
		t.Error("éxito no debe degradar")
	}
	if tracker.ConsecutiveFailures("test") != 0 {
		t.Errorf("éxito debe resetear fallos, obtenido %d", tracker.ConsecutiveFailures("test"))
	}
}

func TestHealthTracker_Reset(t *testing.T) {
	tracker := NewHealthTracker()
	tracker.Record("test", false, 3)
	tracker.Record("test", false, 3)
	tracker.Record("test", false, 3)

	tracker.Reset("test")
	if tracker.ConsecutiveFailures("test") != 0 {
		t.Error("Reset debe limpiar el contador")
	}
}

func TestHealthTracker_Concurrent(t *testing.T) {
	tracker := NewHealthTracker()
	var wg sync.WaitGroup

	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			tracker.Record("test", false, 3)
		}()
	}
	wg.Wait()

	failures := tracker.ConsecutiveFailures("test")
	if failures != 100 {
		t.Errorf("esperado 100 fallos concurrentes, obtenido %d", failures)
	}
}

func TestHealthChecker_CheckNone(t *testing.T) {
	checker := NewHealthChecker(nil, nil)
	def := HealthDef{Type: HealthNone, TimeoutSeconds: 10, FailureThreshold: 3}

	result := checker.Check("test-none", def)

	if !result.Healthy {
		t.Error("type=none debe ser healthy")
	}
	if result.Type != HealthNone {
		t.Errorf("esperado type=none, obtenido %s", result.Type)
	}
}

func TestHealthChecker_CheckCommand_Success(t *testing.T) {
	checker := NewHealthChecker(nil, nil)
	def := HealthDef{
		Type:             HealthCommand,
		Command:          "echo PONG",
		ExpectedOutput:   "PONG",
		TimeoutSeconds:   5,
		FailureThreshold: 3,
	}

	result := checker.Check("test-cmd", def)

	if !result.Healthy {
		t.Errorf("comando echo PONG debe ser healthy: %s", result.Error)
	}
	if result.Output != "PONG" {
		t.Errorf("esperado output PONG, obtenido %s", result.Output)
	}
}

func TestHealthChecker_CheckCommand_Failure(t *testing.T) {
	checker := NewHealthChecker(nil, nil)
	def := HealthDef{
		Type:             HealthCommand,
		Command:          "exit 1",
		TimeoutSeconds:   5,
		FailureThreshold: 3,
	}

	result := checker.Check("test-fail", def)

	if result.Healthy {
		t.Error("comando exit 1 NO debe ser healthy")
	}
}

func TestHealthChecker_CheckCommand_Timeout(t *testing.T) {
	checker := NewHealthChecker(nil, nil)
	def := HealthDef{
		Type:             HealthCommand,
		Command:          "sleep 10",
		TimeoutSeconds:   1,
		FailureThreshold: 3,
	}

	result := checker.Check("test-timeout", def)

	if result.Healthy {
		t.Error("comando que excede timeout NO debe ser healthy")
	}
}

func TestHealthChecker_CheckHTTP(t *testing.T) {
	// Crear servidor HTTP de prueba
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health" {
			w.WriteHeader(http.StatusOK)
			fmt.Fprint(w, "OK")
		} else {
			w.WriteHeader(http.StatusInternalServerError)
		}
	}))
	defer server.Close()

	checker := NewHealthChecker(nil, nil)

	// Endpoint saludable
	def := HealthDef{
		Type:             HealthHTTP,
		HTTPPath:         server.URL + "/health",
		TimeoutSeconds:   5,
		FailureThreshold: 3,
	}

	result := checker.Check("test-http", def)
	if !result.Healthy {
		t.Errorf("HTTP /health debe ser healthy: %s", result.Error)
	}

	// Endpoint no saludable
	def2 := HealthDef{
		Type:             HealthHTTP,
		HTTPPath:         server.URL + "/bad",
		TimeoutSeconds:   5,
		FailureThreshold: 3,
	}

	result2 := checker.Check("test-http-bad", def2)
	if result2.Healthy {
		t.Error("HTTP /bad NO debe ser healthy (500)")
	}
}

func TestHealthChecker_DegradationNotification(t *testing.T) {
	var notifications []struct {
		fichaID  string
		newState string
	}
	notifier := func(fichaID, newState, reason string) {
		notifications = append(notifications, struct {
			fichaID  string
			newState string
		}{fichaID, newState})
	}

	checker := NewHealthChecker(notifier, nil)
	def := HealthDef{
		Type:             HealthCommand,
		Command:          "exit 1",
		TimeoutSeconds:   5,
		FailureThreshold: 2, // degradar con solo 2 fallos
	}

	// Primer fallo — sin notificación
	checker.Check("test-degrade", def)
	if len(notifications) != 0 {
		t.Error("1er fallo no debe notificar")
	}

	// Segundo fallo — debe notificar DEGRADADA
	checker.Check("test-degrade", def)
	if len(notifications) != 1 {
		t.Fatalf("2do fallo debe notificar (1 notificación), obtenido %d", len(notifications))
	}
	if notifications[0].newState != "DEGRADED" {
		t.Errorf("esperado DEGRADADA, obtenido %s", notifications[0].newState)
	}
}

func TestHealthChecker_CheckAll(t *testing.T) {
	checker := NewHealthChecker(nil, nil)

	fichas := map[string]HealthDef{
		"pg":  {Type: HealthCommand, Command: "echo PONG", ExpectedOutput: "PONG", TimeoutSeconds: 5, FailureThreshold: 3},
		"rd":  {Type: HealthCommand, Command: "echo PONG", ExpectedOutput: "PONG", TimeoutSeconds: 5, FailureThreshold: 3},
		"vlt": {Type: HealthCommand, Command: "exit 1", TimeoutSeconds: 5, FailureThreshold: 3},
		"kc":  {Type: HealthNone, TimeoutSeconds: 5, FailureThreshold: 3},
	}

	results := checker.CheckAll(fichas)

	if len(results) != 4 {
		t.Fatalf("esperado 4 resultados, obtenido %d", len(results))
	}
	if !results["pg"].Healthy {
		t.Error("pg debe ser healthy")
	}
	if !results["rd"].Healthy {
		t.Error("rd debe ser healthy")
	}
	if results["vlt"].Healthy {
		t.Error("vlt NO debe ser healthy")
	}
	if !results["kc"].Healthy {
		t.Error("kc (none) debe ser healthy")
	}
}

func TestParseHealthFromManifest(t *testing.T) {
	manifest := `
health:
  type: command
  command: "pg_isready -U postgres"
  expected_output: "accepting connections"
  timeout_seconds: 10
`
	def := ParseHealthFromManifest(manifest)

	if def.Type != HealthCommand {
		t.Errorf("esperado command, obtenido %s", def.Type)
	}
	if !strings.Contains(def.Command, "pg_isready") {
		t.Errorf("comando mal parseado: %s", def.Command)
	}
	if def.ExpectedOutput != "accepting connections" {
		t.Errorf("expected_output mal parseado: %s", def.ExpectedOutput)
	}
}

func TestParseHealthFromManifest_None(t *testing.T) {
	manifest := `
health:
  type: none
`
	def := ParseHealthFromManifest(manifest)

	if def.Type != HealthNone {
		t.Errorf("esperado none, obtenido %s", def.Type)
	}
}

func TestDefaultHealthDef(t *testing.T) {
	def := DefaultHealthDef()

	if def.Type != HealthNone {
		t.Errorf("default type debe ser none, obtenido %s", def.Type)
	}
	if def.TimeoutSeconds != 10 {
		t.Errorf("default timeout debe ser 10, obtenido %d", def.TimeoutSeconds)
	}
	if def.IntervalSeconds != 30 {
		t.Errorf("default interval debe ser 30, obtenido %d", def.IntervalSeconds)
	}
	if def.FailureThreshold != 3 {
		t.Errorf("default threshold debe ser 3, obtenido %d", def.FailureThreshold)
	}
}
