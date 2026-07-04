package ficha

import (
	"testing"
	"time"
)

func TestDefaultTimeoutFor_StatefulSet(t *testing.T) {
	tc := DefaultTimeoutFor("StatefulSet")
	if tc.Install != 10*time.Minute {
		t.Errorf("StatefulSet install debe ser 10min, obtenido %v", tc.Install)
	}
	if tc.Update != 5*time.Minute {
		t.Errorf("StatefulSet update debe ser 5min, obtenido %v", tc.Update)
	}
	if tc.Repair != 10*time.Minute {
		t.Errorf("StatefulSet repair debe ser 10min, obtenido %v", tc.Repair)
	}
}

func TestDefaultTimeoutFor_Deployment(t *testing.T) {
	tc := DefaultTimeoutFor("Deployment")
	if tc.Install != 5*time.Minute {
		t.Errorf("Deployment install debe ser 5min, obtenido %v", tc.Install)
	}
	if tc.Update != 3*time.Minute {
		t.Errorf("Deployment update debe ser 3min, obtenido %v", tc.Update)
	}
}

func TestDefaultTimeoutFor_Bash(t *testing.T) {
	tc := DefaultTimeoutFor("bash")
	if tc.Install != 2*time.Minute {
		t.Errorf("bash install debe ser 2min, obtenido %v", tc.Install)
	}
	if tc.Update != 1*time.Minute {
		t.Errorf("bash update debe ser 1min, obtenido %v", tc.Update)
	}
}

func TestDefaultTimeoutFor_Unknown(t *testing.T) {
	tc := DefaultTimeoutFor("custom-runtime")
	// Desconocido: default seguro (K8s estándar)
	if tc.Install != 5*time.Minute {
		t.Errorf("desconocido debe usar 5min default, obtenido %v", tc.Install)
	}
}

func TestGlobalTimeoutLimits(t *testing.T) {
	limits := GlobalTimeoutLimits()
	if limits.Install != 30*time.Minute {
		t.Errorf("límite install debe ser 30min, obtenido %v", limits.Install)
	}
	if limits.Update != 15*time.Minute {
		t.Errorf("límite update debe ser 15min, obtenido %v", limits.Update)
	}
	if limits.Repair != 10*time.Minute {
		t.Errorf("límite repair debe ser 10min, obtenido %v", limits.Repair)
	}
}

func TestResolveTimeout_UseManifest(t *testing.T) {
	manifest := TimeoutConfig{Install: 8 * time.Minute}
	result := ResolveTimeout(manifest, "Deployment")

	// 8min está entre el default (5min) y el límite (30min) → usar 8min
	if result.Install != 8*time.Minute {
		t.Errorf("manifest 8min debe usarse, obtenido %v", result.Install)
	}
}

func TestResolveTimeout_UseDefault(t *testing.T) {
	manifest := TimeoutConfig{Install: 0} // no declarado
	result := ResolveTimeout(manifest, "StatefulSet")

	// 0 → usar default del tipo (10min)
	if result.Install != 10*time.Minute {
		t.Errorf("no declarado debe usar default 10min, obtenido %v", result.Install)
	}
}

func TestResolveTimeout_ExceedsLimit(t *testing.T) {
	manifest := TimeoutConfig{Install: 60 * time.Minute} // excede límite de 30min
	result := ResolveTimeout(manifest, "Deployment")

	// 60min > 30min límite → debe limitarse a 30min
	if result.Install != 30*time.Minute {
		t.Errorf("60min debe limitarse a 30min, obtenido %v", result.Install)
	}
}

func TestResolveTimeout_NegativeValue(t *testing.T) {
	manifest := TimeoutConfig{Install: -5 * time.Minute}
	result := ResolveTimeout(manifest, "Deployment")

	// negativo → usar default
	if result.Install != 5*time.Minute {
		t.Errorf("negativo debe usar default, obtenido %v", result.Install)
	}
}

func TestParseTimeoutsFromManifest(t *testing.T) {
	manifest := `
timeouts:
  install: 15m
  update: 7m
  repair: 5m
  remove: 3m
  pre_install: 3m
  verify: 2m
`
	tc := ParseTimeoutsFromManifest(manifest)

	if tc.Install != 15*time.Minute {
		t.Errorf("install debe ser 15min, obtenido %v", tc.Install)
	}
	if tc.Update != 7*time.Minute {
		t.Errorf("update debe ser 7min, obtenido %v", tc.Update)
	}
	if tc.Repair != 5*time.Minute {
		t.Errorf("repair debe ser 5min, obtenido %v", tc.Repair)
	}
	if tc.Remove != 3*time.Minute {
		t.Errorf("remove debe ser 3min, obtenido %v", tc.Remove)
	}
	if tc.PreInstall != 3*time.Minute {
		t.Errorf("pre_install debe ser 3min, obtenido %v", tc.PreInstall)
	}
}

func TestParseTimeoutsFromManifest_Empty(t *testing.T) {
	tc := ParseTimeoutsFromManifest("")
	if !tc.IsEmpty() {
		t.Error("manifiesto vacío debe producir timeouts vacíos")
	}
}

func TestParseTimeoutsFromManifest_InvalidValues(t *testing.T) {
	manifest := `
timeouts:
  install: abc
  update: "not a duration"
`
	tc := ParseTimeoutsFromManifest(manifest)

	// Valores inválidos deben ignorarse
	if tc.Install != 0 {
		t.Errorf("valor inválido debe ser 0, obtenido %v", tc.Install)
	}
	if tc.Update != 0 {
		t.Errorf("valor inválido debe ser 0, obtenido %v", tc.Update)
	}
}

func TestTimeoutConfig_IsEmpty(t *testing.T) {
	var zero TimeoutConfig
	if !zero.IsEmpty() {
		t.Error("zero value debe ser empty")
	}
	withInstall := TimeoutConfig{Install: 5 * time.Minute}
	if withInstall.IsEmpty() {
		t.Error("con install=5min NO debe ser empty")
	}
}

func TestTimeoutConfig_ForOp(t *testing.T) {
	tc := TimeoutConfig{
		Install: 10 * time.Minute,
		Update:  8 * time.Minute,
		Repair:  6 * time.Minute,
		Remove:  4 * time.Minute,
	}

	if tc.ForOp(OpInstall) != 10*time.Minute {
		t.Error("ForOp Install incorrecto")
	}
	if tc.ForOp(OpUpdate) != 8*time.Minute {
		t.Error("ForOp Update incorrecto")
	}
	if tc.ForOp(OpRepair) != 6*time.Minute {
		t.Error("ForOp Repair incorrecto")
	}
	if tc.ForOp(OpRemove) != 4*time.Minute {
		t.Error("ForOp Remove incorrecto")
	}
	if tc.ForOp("unknown") != DefaultUnknownOpTimeout {
		t.Errorf("op desconocida debe usar default %v", DefaultUnknownOpTimeout)
	}
}

func TestTimeoutConfig_Validate(t *testing.T) {
	// Dentro de límites — sin warnings
	tc := TimeoutConfig{Install: 5 * time.Minute, Update: 3 * time.Minute}
	warnings := tc.Validate()
	if len(warnings) != 0 {
		t.Errorf("dentro de límites no debe tener warnings: %v", warnings)
	}

	// Excede límites — debe warning
	tc2 := TimeoutConfig{Install: 60 * time.Minute, Update: 45 * time.Minute}
	warnings = tc2.Validate()
	if len(warnings) != 2 {
		t.Errorf("excede límites debe tener 2 warnings, obtenido %d: %v", len(warnings), warnings)
	}
}

func TestResolveTimeout_AllDefaultsForStatefulSet(t *testing.T) {
	manifest := TimeoutConfig{} // vacío
	result := ResolveTimeout(manifest, "StatefulSet")

	defaults := DefaultTimeoutFor("StatefulSet")
	if result.Install != defaults.Install {
		t.Errorf("Install: esperado %v, obtenido %v", defaults.Install, result.Install)
	}
	if result.Update != defaults.Update {
		t.Errorf("Update: esperado %v, obtenido %v", defaults.Update, result.Update)
	}
	if result.Repair != defaults.Repair {
		t.Errorf("Repair: esperado %v, obtenido %v", defaults.Repair, result.Repair)
	}
}
