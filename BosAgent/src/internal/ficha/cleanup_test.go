package ficha

import (
	"testing"
)

func TestCleanupSteps_Canónicos(t *testing.T) {
	lc := NewLifecycle(nil)
	steps := lc.CleanupSteps()

	if len(steps) != 7 {
		t.Fatalf("esperados 7 pasos, obtenidos %d", len(steps))
	}

	canonicos := []string{
		"stop_pods", "delete_workloads", "delete_configmaps",
		"delete_secrets", "delete_pvcs_temp", "clean_host_files", "verify_no_residue",
	}
	for i, name := range canonicos {
		if steps[i].Name != name {
			t.Errorf("paso[%d]: esperado %s, obtenido %s", i, name, steps[i].Name)
		}
		if steps[i].Status != "pending" {
			t.Errorf("paso[%d] %s: status debe ser 'pending'", i, name)
		}
	}
}

func TestExecuteCleanup_Simulacion_Exitoso(t *testing.T) {
	lc := NewLifecycle(nil) // sin executor → simulación

	result := lc.ExecuteCleanup("redis")

	if !result.Success {
		t.Errorf("cleanup simulado debe ser exitoso: %s", result.Error)
	}
	if result.FichaID != "redis" {
		t.Errorf("FichaID: %s", result.FichaID)
	}
	if result.Duration <= 0 {
		t.Error("Duration debe ser positivo")
	}
}

func TestExecuteCleanup_Pasos_OK(t *testing.T) {
	lc := NewLifecycle(nil)
	result := lc.ExecuteCleanup("vault")

	// Los 7 pasos canónicos deben estar marcados OK en simulación
	canonicCount := 0
	for _, step := range result.Steps {
		if step.Name == "residue_found" {
			continue // step extra solo si hay residuos
		}
		if step.Status != "ok" {
			t.Errorf("paso %s: esperado 'ok', obtenido '%s'", step.Name, step.Status)
		}
		canonicCount++
	}
	if canonicCount < 7 {
		t.Errorf("esperados ≥7 pasos canónicos, obtenidos %d", canonicCount)
	}
}

func TestExecuteCleanup_SinResiduos_VerifyNoResidue(t *testing.T) {
	lc := NewLifecycle(nil)
	result := lc.ExecuteCleanup("bos-test-ficha")

	// verifyNoResidue retorna [] en stub → no debe haber residuos
	if len(result.Residue) != 0 {
		t.Errorf("verifyNoResidue stub debe retornar sin residuos, obtenidos: %v", result.Residue)
	}
}

func TestExecuteCleanup_FichaID(t *testing.T) {
	lc := NewLifecycle(nil)
	fichas := []string{"postgresql", "keycloak", "vault", "bauth"}
	for _, id := range fichas {
		result := lc.ExecuteCleanup(id)
		if result.FichaID != id {
			t.Errorf("FichaID: esperado %s, obtenido %s", id, result.FichaID)
		}
	}
}
