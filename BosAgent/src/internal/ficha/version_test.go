package ficha

import (
	"testing"
)

func TestParseVersion(t *testing.T) {
	tests := []struct {
		input   string
		want    Version
		wantErr bool
	}{
		{"1.0.0", Version{1, 0, 0}, false},
		{"18.4.0", Version{18, 4, 0}, false},
		{"26.6.2", Version{26, 6, 2}, false},
		{"2.0", Version{2, 0, 0}, false},     // sin patch
		{"0.1.0", Version{0, 1, 0}, false},
		{"1.0", Version{1, 0, 0}, false},
		{"", Version{}, true},
		{"latest", Version{}, true},
		{"abc", Version{}, true},
		{"1.x.0", Version{}, true},
		{"-1.0.0", Version{}, true},
	}

	for _, tt := range tests {
		v, err := ParseVersion(tt.input)
		if tt.wantErr && err == nil {
			t.Errorf("ParseVersion(%q): esperado error, obtenido %v", tt.input, v)
		}
		if !tt.wantErr && err != nil {
			t.Errorf("ParseVersion(%q): error inesperado: %v", tt.input, err)
		}
		if !tt.wantErr && v != tt.want {
			t.Errorf("ParseVersion(%q): esperado %v, obtenido %v", tt.input, tt.want, v)
		}
	}
}

func TestVersion_String(t *testing.T) {
	v := Version{18, 4, 0}
	if v.String() != "18.4.0" {
		t.Errorf("String: esperado 18.4.0, obtenido %s", v.String())
	}
}

func TestVersion_Compare(t *testing.T) {
	tests := []struct {
		a, b Version
		want int
	}{
		{Version{1, 0, 0}, Version{1, 0, 0}, 0},
		{Version{2, 0, 0}, Version{1, 0, 0}, 1},
		{Version{1, 0, 0}, Version{2, 0, 0}, -1},
		{Version{1, 2, 0}, Version{1, 1, 0}, 1},
		{Version{1, 0, 5}, Version{1, 0, 3}, 1},
		{Version{18, 4, 0}, Version{18, 3, 0}, 1},
	}

	for _, tt := range tests {
		got := tt.a.Compare(tt.b)
		if got != tt.want {
			t.Errorf("%s.Compare(%s): esperado %d, obtenido %d", tt.a, tt.b, tt.want, got)
		}
	}
}

func TestVersion_LessThan_GreaterThan_Equals(t *testing.T) {
	v1 := Version{1, 0, 0}
	v2 := Version{2, 0, 0}
	v3 := Version{1, 0, 0}

	if !v1.LessThan(v2) {
		t.Error("1.0.0 < 2.0.0 debe ser true")
	}
	if v2.LessThan(v1) {
		t.Error("2.0.0 < 1.0.0 debe ser false")
	}
	if !v2.GreaterThan(v1) {
		t.Error("2.0.0 > 1.0.0 debe ser true")
	}
	if !v1.Equals(v3) {
		t.Error("1.0.0 == 1.0.0 debe ser true")
	}
	if v1.Equals(v2) {
		t.Error("1.0.0 == 2.0.0 debe ser false")
	}
}

func TestIsCompatibleUpgrade(t *testing.T) {
	tests := []struct {
		current, target Version
		wantErr         bool
	}{
		// MINOR/PATCH upgrades — siempre OK
		{Version{1, 0, 0}, Version{2, 0, 0}, true},  // MAJOR → necesita migración
		{Version{1, 0, 0}, Version{1, 1, 0}, false},   // MINOR OK
		{Version{1, 0, 0}, Version{1, 0, 1}, false},   // PATCH OK
		{Version{18, 4, 0}, Version{18, 4, 1}, false}, // PATCH OK
		{Version{18, 4, 0}, Version{18, 5, 0}, false}, // MINOR OK

		// +2 MAJOR — BLOQUEADO
		{Version{1, 0, 0}, Version{3, 0, 0}, true},

		// Rollback N-1 — permitido
		{Version{2, 0, 0}, Version{1, 0, 0}, false},

		// Rollback N-2 — BLOQUEADO
		{Version{3, 0, 0}, Version{1, 0, 0}, true},

		// Downgrade MINOR N-1 — OK
		{Version{1, 2, 0}, Version{1, 1, 0}, false},
	}

	for _, tt := range tests {
		err := IsCompatibleUpgrade(tt.current, tt.target)
		hasErr := err != nil
		if hasErr != tt.wantErr {
			if tt.wantErr {
				t.Errorf("%s → %s: esperado error, no se obtuvo", tt.current, tt.target)
			} else {
				t.Errorf("%s → %s: error inesperado: %v", tt.current, tt.target, err)
			}
		}
	}
}

func TestNeedsMigration(t *testing.T) {
	if !NeedsMigration(Version{1, 0, 0}, Version{2, 0, 0}) {
		t.Error("MAJOR bump debe necesitar migración")
	}
	if NeedsMigration(Version{1, 0, 0}, Version{1, 1, 0}) {
		t.Error("MINOR bump NO debe necesitar migración")
	}
}

func TestNeedsBackup(t *testing.T) {
	if !NeedsBackup(Version{1, 0, 0}, Version{2, 0, 0}) {
		t.Error("MAJOR bump debe necesitar backup")
	}
	if !NeedsBackup(Version{2, 0, 0}, Version{1, 0, 0}) {
		t.Error("downgrade MAJOR debe necesitar backup")
	}
	if NeedsBackup(Version{1, 0, 0}, Version{1, 1, 0}) {
		t.Error("MINOR bump NO debe necesitar backup")
	}
}

func TestBumpHelpers(t *testing.T) {
	v := Version{1, 2, 3}

	if v.BumpMajor() != (Version{2, 0, 0}) {
		t.Errorf("BumpMajor: esperado 2.0.0, obtenido %s", v.BumpMajor())
	}
	if v.BumpMinor() != (Version{1, 3, 0}) {
		t.Errorf("BumpMinor: esperado 1.3.0, obtenido %s", v.BumpMinor())
	}
	if v.BumpPatch() != (Version{1, 2, 4}) {
		t.Errorf("BumpPatch: esperado 1.2.4, obtenido %s", v.BumpPatch())
	}

	// Original no debe mutar
	if v.String() != "1.2.3" {
		t.Error("Bump no debe mutar la versión original")
	}
}

func TestNMinusOne(t *testing.T) {
	if v := (Version{5, 0, 0}).NMinusOne(); v != (Version{4, 0, 0}) {
		t.Errorf("N-1 de 5.0.0 debe ser 4.0.0, obtenido %s", v)
	}
	if v := (Version{0, 1, 0}).NMinusOne(); !v.IsZero() {
		t.Error("N-1 de 0.1.0 debe ser 0.0.0 (zero)")
	}
}

func TestUpdateStrategy(t *testing.T) {
	if !IsValidStrategy("hot") {
		t.Error("hot debe ser válido")
	}
	if !IsValidStrategy("cold") {
		t.Error("cold debe ser válido")
	}
	if !IsValidStrategy("canary") {
		t.Error("canary debe ser válido")
	}
	if IsValidStrategy("bluegreen") {
		t.Error("bluegreen NO debe ser válido")
	}
}

func TestDefaultUpdateStrategy(t *testing.T) {
	if DefaultUpdateStrategy("StatefulSet") != StrategyCold {
		t.Error("StatefulSet debe ser cold")
	}
	if DefaultUpdateStrategy("Deployment") != StrategyHot {
		t.Error("Deployment debe ser hot")
	}
	if DefaultUpdateStrategy("bash") != StrategyCold {
		t.Error("bash debe ser cold")
	}
	if DefaultUpdateStrategy("unknown") != StrategyHot {
		t.Error("desconocido debe ser hot (default)")
	}
}

func TestCanarySteps(t *testing.T) {
	steps := CanarySteps()
	if len(steps) != 3 {
		t.Fatalf("esperado 3 pasos, obtenido %d", len(steps))
	}
	if steps[0] != 10 || steps[1] != 50 || steps[2] != 100 {
		t.Errorf("pasos canary deben ser 10→50→100, obtenido %v", steps)
	}
}

func TestVersionRange(t *testing.T) {
	r := VersionRange{Min: Version{1, 0, 0}, Max: Version{2, 0, 0}}

	if !r.Contains(Version{1, 0, 0}) {
		t.Error("1.0.0 debe estar en rango [1.0.0, 2.0.0]")
	}
	if !r.Contains(Version{1, 5, 0}) {
		t.Error("1.5.0 debe estar en rango")
	}
	if !r.Contains(Version{2, 0, 0}) {
		t.Error("2.0.0 debe estar en rango")
	}
	if r.Contains(Version{0, 9, 0}) {
		t.Error("0.9.0 NO debe estar en rango")
	}
	if r.Contains(Version{3, 0, 0}) {
		t.Error("3.0.0 NO debe estar en rango")
	}
}

func TestNMinusOneRange(t *testing.T) {
	r := NMinusOneRange(Version{2, 5, 0})

	if r.Min != (Version{1, 0, 0}) {
		t.Errorf("min debe ser 1.0.0, obtenido %s", r.Min)
	}
	if r.Max != (Version{2, 5, 0}) {
		t.Errorf("max debe ser 2.5.0, obtenido %s", r.Max)
	}
}
