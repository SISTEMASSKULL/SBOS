package ficha

import (
	"testing"
	"time"
)

func TestNewDegradedHandler_Defaults(t *testing.T) {
	dh := NewDegradedHandler("postgresql", nil, nil)

	if dh.state.FichaID != "postgresql" {
		t.Errorf("FichaID: %s", dh.state.FichaID)
	}
	if dh.state.MaxAttempts != DefaultDegradeMaxAttempts {
		t.Errorf("MaxAttempts: %d != %d", dh.state.MaxAttempts, DefaultDegradeMaxAttempts)
	}
	if dh.state.HealthInterval != DefaultHealthInterval {
		t.Errorf("HealthInterval: %v != %v", dh.state.HealthInterval, DefaultHealthInterval)
	}
	if !dh.state.AutoRepairEnabled {
		t.Error("AutoRepairEnabled debe ser true por defecto")
	}
	if dh.ShouldRetry() == false {
		t.Error("sin intentos, ShouldRetry debe ser true")
	}
	if dh.RemainingAttempts() != DefaultDegradeMaxAttempts {
		t.Errorf("RemainingAttempts: %d", dh.RemainingAttempts())
	}
}

func TestEnterDegraded_UmbralSatisfecho(t *testing.T) {
	dh := NewDegradedHandler("keycloak", nil, nil)

	err := dh.EnterDegraded(3, 3)
	if err != nil {
		t.Errorf("EnterDegraded(3, 3) no debe dar error: %v", err)
	}
	if dh.state.DegradedSince.IsZero() {
		t.Error("DegradedSince debe ser registrado")
	}
	if dh.state.ConsecutiveHealthFails != 3 {
		t.Errorf("ConsecutiveHealthFails: %d", dh.state.ConsecutiveHealthFails)
	}
}

func TestEnterDegraded_UmbralNoSatisfecho(t *testing.T) {
	dh := NewDegradedHandler("vault", nil, nil)

	err := dh.EnterDegraded(2, 3)
	if err == nil {
		t.Error("2 fallos < 3 umbral: debe dar error")
	}
	if !dh.state.DegradedSince.IsZero() {
		t.Error("DegradedSince no debe ser registrado si umbral no se cumple")
	}
}

func TestAttemptRepair_NoRecuperable(t *testing.T) {
	dh := NewDegradedHandler("bkernel", nil, nil)
	_ = dh.EnterDegraded(3, 3)

	ok, state := dh.AttemptRepair("segfault in process 123")
	if ok {
		t.Error("segfault no es recuperable")
	}
	if state != StateUnrecoverable {
		t.Errorf("esperado ERROR_NO_CORREGIBLE, obtenido %s", state)
	}
}

func TestAttemptRepair_AgotaReintentos(t *testing.T) {
	dh := NewDegradedHandler("redis", nil, nil)
	dh.state.MaxAttempts = 2
	_ = dh.EnterDegraded(3, 3)

	// Primer intento: no recuperable por razón desconocida → sigue reparando
	ok, state := dh.AttemptRepair("network timeout somewhere")
	if ok {
		t.Error("primer intento no debe ser exitoso (error desconocido)")
	}
	if state == StateUnrecoverable && dh.state.RepairAttempts < dh.state.MaxAttempts {
		t.Error("no debe escalar antes de agotar intentos")
	}

	// Segundo intento: agota maxAttempts
	ok2, state2 := dh.AttemptRepair("network timeout somewhere")
	if ok2 {
		t.Error("segundo intento no debe ser exitoso")
	}
	if state2 != StateUnrecoverable {
		t.Errorf("al agotar 2 intentos: esperado ERROR_NO_CORREGIBLE, obtenido %s", state2)
	}
}

func TestShouldRetry_YRemainingAttempts(t *testing.T) {
	dh := NewDegradedHandler("bos", nil, nil)
	dh.state.MaxAttempts = 3

	if !dh.ShouldRetry() {
		t.Error("0 intentos: debe poder reintentar")
	}
	if dh.RemainingAttempts() != 3 {
		t.Errorf("RemainingAttempts: %d", dh.RemainingAttempts())
	}

	dh.state.RepairAttempts = 3
	if dh.ShouldRetry() {
		t.Error("3/3 intentos: no debe poder reintentar")
	}
	if dh.RemainingAttempts() != 0 {
		t.Errorf("RemainingAttempts agotados: %d", dh.RemainingAttempts())
	}

	dh.state.RepairAttempts = 5 // excede max
	if dh.RemainingAttempts() != 0 {
		t.Errorf("RemainingAttempts nunca negativo: %d", dh.RemainingAttempts())
	}
}

func TestRecover(t *testing.T) {
	dh := NewDegradedHandler("nginx", nil, nil)
	_ = dh.EnterDegraded(3, 3)
	dh.state.RepairAttempts = 1

	state := dh.Recover()
	if state != StateInstalled {
		t.Errorf("Recover: esperado INSTALADA, obtenido %s", state)
	}
}

func TestEscalate(t *testing.T) {
	dh := NewDegradedHandler("postgresql", nil, nil)
	_ = dh.EnterDegraded(3, 3)
	dh.state.RepairAttempts = 3

	diag := ErrorDiagnosis{Category: ErrPhysical, Cause: "disco lleno", Recoverable: true}
	req := dh.Escalate(diag)

	if req.FichaID != "postgresql" {
		t.Errorf("FichaID: %s", req.FichaID)
	}
	if req.State != StateUnrecoverable {
		t.Errorf("State: %s", req.State)
	}
	if req.Attempts != 3 {
		t.Errorf("Attempts: %d", req.Attempts)
	}
}

func TestDegradedDuration(t *testing.T) {
	dh := NewDegradedHandler("vault", nil, nil)

	// Sin degradar → 0
	if dh.DegradedDuration() != 0 {
		t.Errorf("sin degradar: DegradedDuration debe ser 0, obtenido %v", dh.DegradedDuration())
	}

	_ = dh.EnterDegraded(3, 3)
	time.Sleep(10 * time.Millisecond)

	d := dh.DegradedDuration()
	if d < 10*time.Millisecond {
		t.Errorf("DegradedDuration debe ser >= 10ms, obtenido %v", d)
	}
}

func TestState_RetornaReferencia(t *testing.T) {
	dh := NewDegradedHandler("bauth", nil, nil)
	s := dh.State()
	if s == nil {
		t.Error("State() no debe retornar nil")
	}
	if s.FichaID != "bauth" {
		t.Errorf("FichaID: %s", s.FichaID)
	}
}
