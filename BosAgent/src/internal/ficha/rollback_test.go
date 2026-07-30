package ficha

import (
	"testing"
)

func TestRollbackSteps_Canónicos(t *testing.T) {
	lc := NewLifecycle(nil)
	from, _ := ParseVersion("2.0.0")
	to, _ := ParseVersion("1.0.0")

	steps := lc.RollbackSteps(from, to)
	if len(steps) != 6 {
		t.Fatalf("esperados 6 pasos canónicos, obtenidos %d", len(steps))
	}

	canonicos := []string{
		"verify_backup", "stop_current", "restore_backup",
		"start_service", "health_verify", "commit_state",
	}
	for i, name := range canonicos {
		if steps[i].Name != name {
			t.Errorf("paso[%d]: esperado %s, obtenido %s", i, name, steps[i].Name)
		}
		if steps[i].Status != "pending" {
			t.Errorf("paso[%d] %s: status debe ser 'pending', obtenido %s", i, name, steps[i].Status)
		}
	}
}

func TestExecuteRollback_Simulacion_Exitoso(t *testing.T) {
	lc := NewLifecycle(nil)
	from, _ := ParseVersion("2.0.0")
	to, _ := ParseVersion("1.0.0")

	result := lc.ExecuteRollback("postgresql", from, to)

	if !result.Success {
		t.Errorf("rollback simulado debe ser exitoso: %s", result.Error)
	}
	if result.FichaID != "postgresql" {
		t.Errorf("FichaID: %s", result.FichaID)
	}
	if result.FromVersion.String() != "2.0.0" {
		t.Errorf("FromVersion: %s", result.FromVersion.String())
	}
	if result.ToVersion.String() != "1.0.0" {
		t.Errorf("ToVersion: %s", result.ToVersion.String())
	}
	if result.Duration <= 0 {
		t.Error("Duration debe ser positivo")
	}
	if result.Error != "" {
		t.Errorf("Error debe ser vacío en éxito: %s", result.Error)
	}
}

func TestExecuteRollback_Pasos_OK(t *testing.T) {
	lc := NewLifecycle(nil)
	from, _ := ParseVersion("3.0.0")
	to, _ := ParseVersion("2.5.0")

	result := lc.ExecuteRollback("keycloak", from, to)

	for _, step := range result.Steps {
		if step.Status != "ok" {
			t.Errorf("paso %s: esperado 'ok', obtenido '%s'", step.Name, step.Status)
		}
	}
}

func TestExecuteRollback_DetallePasos(t *testing.T) {
	lc := NewLifecycle(nil)
	from, _ := ParseVersion("2.0.0")
	to, _ := ParseVersion("1.0.0")

	steps := lc.RollbackSteps(from, to)

	// restore_backup debe mencionar la versión destino
	restoreStep := steps[2] // restore_backup es el 3er paso
	if restoreStep.Name != "restore_backup" {
		t.Fatalf("paso[2] debe ser restore_backup, obtenido %s", restoreStep.Name)
	}
	if restoreStep.Detail == "" {
		t.Error("restore_backup debe tener Detail con la versión a restaurar")
	}
}
