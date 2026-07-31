package ficha

import (
	"testing"
	"time"
)

func TestExecuteRepair_Simulacion_Falla3Reintentos(t *testing.T) {
	lc := NewLifecycle(nil) // sin executor → simulación

	// Error no recuperable: agota inmediatamente (no retries)
	result := lc.ExecuteRepair("postgresql", 3, 0, "segfault in process")
	if result.FichaID != "postgresql" {
		t.Errorf("FichaID: %s", result.FichaID)
	}
	if result.Success {
		t.Error("segfault no es recuperable — no debe tener éxito")
	}
	if result.FinalState != StateUnrecoverable {
		t.Errorf("esperado ERROR_NO_CORREGIBLE, obtenido %s", result.FinalState)
	}
	if result.TotalAttempts < 1 {
		t.Error("debe haber al menos 1 intento")
	}
}

func TestExecuteRepair_Simulacion_ConfigRecuperable(t *testing.T) {
	lc := NewLifecycle(nil)

	// Error de configuración: recuperable en 2do intento (simulación)
	result := lc.ExecuteRepair("keycloak", 3, 0, "invalid config value")
	if result.FinalState != StateInstalled {
		t.Errorf("config recoverable: esperado INSTALADA en 2do intento, obtenido %s", result.FinalState)
	}
	if !result.Success {
		t.Error("config recoverable debe tener éxito")
	}
	if result.TotalAttempts != 2 {
		t.Errorf("config recoverable: esperado 2 intentos, obtenido %d", result.TotalAttempts)
	}
}

func TestExecuteRepair_Simulacion_AgotaReintentos(t *testing.T) {
	lc := NewLifecycle(nil)

	// maxAttempts=1 garantiza agotamiento: intento 1 falla (la simulación
	// solo tiene éxito en intento==2, que nunca llega con maxAttempts=1).
	result := lc.ExecuteRepair("vault", 1, 0, "unknown failure XYZ")
	if result.FinalState != StateUnrecoverable {
		t.Errorf("reintentos agotados: esperado ERROR_NO_CORREGIBLE, obtenido %s", result.FinalState)
	}
	if result.Success {
		t.Error("reintentos agotados no debe ser success")
	}
}

func TestExecuteRepair_DefaultMaxAttempts(t *testing.T) {
	lc := NewLifecycle(nil)

	// maxAttempts=0 → usa DefaultRepairMaxAttempts
	result := lc.ExecuteRepair("redis", 0, 0, "unknown error")
	if len(result.Attempts) == 0 {
		t.Error("debe haber intentos con maxAttempts=0 (usa default)")
	}
}

func TestExecuteRepair_Duracion(t *testing.T) {
	lc := NewLifecycle(nil)
	result := lc.ExecuteRepair("nginx", 1, 0, "segfault")
	if result.TotalDuration <= 0 {
		t.Error("TotalDuration debe ser positivo")
	}
	if result.TotalDuration > 10*time.Second {
		t.Errorf("TotalDuration demasiado alto en simulación: %v", result.TotalDuration)
	}
}

func TestRepairAttempt_Campos(t *testing.T) {
	lc := NewLifecycle(nil)
	result := lc.ExecuteRepair("bauth", 3, 0, "segfault crash")

	for _, ra := range result.Attempts {
		if ra.Attempt <= 0 {
			t.Errorf("Attempt debe ser positivo: %d", ra.Attempt)
		}
		if ra.Diagnosis.Category == "" {
			t.Errorf("Attempt %d: Diagnosis.Category vacío", ra.Attempt)
		}
	}
}
