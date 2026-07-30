package ficha

import (
	"testing"
	"time"
)

func TestDiagnose_ErrPhysical(t *testing.T) {
	lc := NewLifecycle(nil)

	cases := []struct {
		input    string
		wantCause string
	}{
		{"no space left on device", "disco lleno o error de I/O"},
		{"io error reading block", "disco lleno o error de I/O"},
		{"connection refused 127.0.0.1:5432", "error de red o conectividad"},
		{"dial tcp: no route to host", "error de red o conectividad"},
		{"out of memory: kill process", "memoria insuficiente"},
		{"oom killer triggered", "memoria insuficiente"},
		{"cpu throttling detected", "CPU throttling"},
	}

	for _, tc := range cases {
		d := lc.Diagnose(tc.input, "command")
		if d.Category != ErrPhysical {
			t.Errorf("input=%q: esperado ErrPhysical, obtenido %s", tc.input, d.Category)
		}
		if d.Cause != tc.wantCause {
			t.Errorf("input=%q: causa %q != %q", tc.input, d.Cause, tc.wantCause)
		}
		if d.RepairAction == "" {
			t.Errorf("input=%q: RepairAction no debe ser vacío", tc.input)
		}
	}
}

func TestDiagnose_ErrLogical(t *testing.T) {
	lc := NewLifecycle(nil)

	cases := []struct {
		input       string
		wantCause   string
		recoverable bool
	}{
		{"invalid configuration value", "error de configuración", true},
		{"syntax error in yaml: line 3", "error de configuración", true},
		{"missing dependency: libssl", "dependencia faltante o archivo no encontrado", true},
		{"no such file or directory: /etc/bos/manifest.yml", "dependencia faltante o archivo no encontrado", true},
		{"permission denied: /var/log/bos", "error de permisos o RBAC", true},
		{"schema drift detected in table users", "schema drift o error de base de datos", true},
		{"segfault in process 1234", "crash de la aplicación (segfault/panic)", false},
		{"panic: runtime error: nil pointer", "crash de la aplicación (segfault/panic)", false},
	}

	for _, tc := range cases {
		d := lc.Diagnose(tc.input, "command")
		if d.Category != ErrLogical {
			t.Errorf("input=%q: esperado ErrLogical, obtenido %s", tc.input, d.Category)
		}
		if d.Cause != tc.wantCause {
			t.Errorf("input=%q: causa %q != %q", tc.input, d.Cause, tc.wantCause)
		}
		if d.Recoverable != tc.recoverable {
			t.Errorf("input=%q: Recoverable=%v, esperado %v", tc.input, d.Recoverable, tc.recoverable)
		}
	}
}

func TestDiagnose_ErrUnknown(t *testing.T) {
	lc := NewLifecycle(nil)

	d := lc.Diagnose("completely unknown error XYZ-999", "command")
	if d.Category != ErrUnknown {
		t.Errorf("esperado ErrUnknown, obtenido %s", d.Category)
	}
	if !d.Recoverable {
		t.Error("ErrUnknown debe ser recuperable por defecto")
	}
	if d.RepairAction == "" {
		t.Error("ErrUnknown debe tener RepairAction")
	}
}

func TestDiagnose_EmptyInput(t *testing.T) {
	lc := NewLifecycle(nil)
	d := lc.Diagnose("", "command")
	if d.Category != ErrUnknown {
		t.Errorf("input vacío debe dar ErrUnknown, obtenido %s", d.Category)
	}
}

func TestClassifyState(t *testing.T) {
	lc := NewLifecycle(nil)

	cases := []struct {
		cat  ErrorCategory
		want FichaState
	}{
		{ErrPhysical, StateErrorFisico},
		{ErrLogical, StateErrorLogico},
		{ErrUnknown, StateErrorLogico}, // default conservador
	}

	for _, tc := range cases {
		diag := ErrorDiagnosis{Category: tc.cat}
		got := lc.ClassifyState(diag)
		if got != tc.want {
			t.Errorf("ClassifyState(%s): esperado %s, obtenido %s", tc.cat, tc.want, got)
		}
	}
}

func TestEscalateToHITL(t *testing.T) {
	lc := NewLifecycle(nil)
	diag := ErrorDiagnosis{Category: ErrLogical, Cause: "config mal formado", Recoverable: true}

	req := lc.EscalateToHITL("postgresql", diag, 3, 3)

	if req.FichaID != "postgresql" {
		t.Errorf("FichaID: %s", req.FichaID)
	}
	if req.State != StateErrorNoCorregible {
		t.Errorf("State: esperado ERROR_NO_CORREGIBLE, obtenido %s", req.State)
	}
	if req.Attempts != 3 {
		t.Errorf("Attempts: %d", req.Attempts)
	}
	if req.Reason == "" {
		t.Error("Reason no debe ser vacío")
	}
	if req.Timestamp.IsZero() {
		t.Error("Timestamp no debe ser zero")
	}
	if time.Since(req.Timestamp) > 5*time.Second {
		t.Error("Timestamp debe ser reciente")
	}
}

func TestIsRecoverableError(t *testing.T) {
	lc := NewLifecycle(nil)

	if !lc.IsRecoverableError(ErrorDiagnosis{Recoverable: true}) {
		t.Error("Recoverable=true debe retornar true")
	}
	if lc.IsRecoverableError(ErrorDiagnosis{Recoverable: false}) {
		t.Error("Recoverable=false debe retornar false")
	}
}
