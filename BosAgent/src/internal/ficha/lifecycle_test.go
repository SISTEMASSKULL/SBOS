package ficha

import (
	"testing"
	"time"
)

func TestLifecycle_BeginInstall(t *testing.T) {
	lc := NewLifecycle(nil)

	// Desde LISTA: debe permitir
	next, err := lc.BeginInstall(StateReady)
	if err != nil {
		t.Errorf("BeginInstall(LISTA): %v", err)
	}
	if next != StateInstalling {
		t.Errorf("esperado INSTALANDO, obtenido %s", next)
	}

	// Desde INSTALADA: debe fallar (ya instalada)
	_, err = lc.BeginInstall(StateInstalled)
	if err == nil {
		t.Error("BeginInstall(INSTALADA) debe fallar")
	}
}

func TestLifecycle_EvaluateInstall(t *testing.T) {
	lc := NewLifecycle(nil)

	// Éxito → INSTALADA
	result := lc.EvaluateInstall(true, false)
	if result.NewState != StateInstalled {
		t.Errorf("éxito debe ser INSTALADA, obtenido %s", result.NewState)
	}

	// Fallo sin versión anterior → LIMPIEZA
	result = lc.EvaluateInstall(false, false)
	if result.NewState != StateCleanup {
		t.Errorf("fallo sin backup debe ser LIMPIEZA, obtenido %s", result.NewState)
	}
	if !result.NeedsCleanup {
		t.Error("debe necesitar limpieza")
	}

	// Fallo con versión anterior → ROLLBACK
	result = lc.EvaluateInstall(false, true)
	if result.NewState != StateRollback {
		t.Errorf("fallo con backup debe ser ROLLBACK, obtenido %s", result.NewState)
	}
	if !result.NeedsRollback {
		t.Error("debe necesitar rollback")
	}
}

func TestLifecycle_BeginUpdate(t *testing.T) {
	lc := NewLifecycle(nil)

	next, err := lc.BeginUpdate(StateInstalled)
	if err != nil {
		t.Errorf("BeginUpdate(INSTALADA): %v", err)
	}
	if next != StateUpdating {
		t.Errorf("esperado ACTUALIZANDO, obtenido %s", next)
	}

	_, err = lc.BeginUpdate(StatePending)
	if err == nil {
		t.Error("BeginUpdate(PENDIENTE) debe fallar")
	}
}

func TestLifecycle_EvaluateUpdate(t *testing.T) {
	lc := NewLifecycle(nil)

	// Éxito → INSTALADA
	result := lc.EvaluateUpdate(true)
	if result.NewState != StateInstalled {
		t.Errorf("éxito debe ser INSTALADA, obtenido %s", result.NewState)
	}

	// Fallo → ROLLBACK (siempre hay versión anterior)
	result = lc.EvaluateUpdate(false)
	if result.NewState != StateRollback {
		t.Errorf("fallo debe ser ROLLBACK, obtenido %s", result.NewState)
	}
	if !result.NeedsRollback {
		t.Error("update fallido debe necesitar rollback")
	}
}

func TestLifecycle_BeginRepair(t *testing.T) {
	lc := NewLifecycle(nil)

	next, err := lc.BeginRepair(StateDegraded)
	if err != nil {
		t.Errorf("BeginRepair(DEGRADADA): %v", err)
	}
	if next != StateRepairing {
		t.Errorf("esperado REPARANDO, obtenido %s", next)
	}

	// INSTALADA permite repair preventivo (consistente con ValidTransitions).
	next, err = lc.BeginRepair(StateInstalled)
	if err != nil || next != StateRepairing {
		t.Errorf("BeginRepair(INSTALADA) debe ser REPARANDO (repair preventivo): next=%s err=%v", next, err)
	}
	// LISTA no puede repararse
	_, err = lc.BeginRepair(StateReady)
	if err == nil {
		t.Error("BeginRepair(LISTA) debe fallar")
	}
}

func TestLifecycle_EvaluateRepair(t *testing.T) {
	lc := NewLifecycle(nil)

	// Éxito → INSTALADA
	result := lc.EvaluateRepair(true, 1, 3)
	if result.NewState != StateInstalled {
		t.Errorf("éxito debe ser INSTALADA, obtenido %s", result.NewState)
	}

	// Fallo intento 1 de 3 → reintentar
	result = lc.EvaluateRepair(false, 1, 3)
	if result.NewState != StateRepairing {
		t.Errorf("intento 1/3 debe ser REPARANDO, obtenido %s", result.NewState)
	}

	// Fallo intento 2 de 3 → reintentar
	result = lc.EvaluateRepair(false, 2, 3)
	if result.NewState != StateRepairing {
		t.Errorf("intento 2/3 debe ser REPARANDO, obtenido %s", result.NewState)
	}

	// Fallo intento 3 de 3 → ERROR_NO_CORREGIBLE
	result = lc.EvaluateRepair(false, 3, 3)
	if result.NewState != StateUnrecoverable {
		t.Errorf("intento 3/3 debe ser ERROR_NO_CORREGIBLE, obtenido %s", result.NewState)
	}

	// Excede máximo
	result = lc.EvaluateRepair(false, 5, 3)
	if result.NewState != StateUnrecoverable {
		t.Errorf("intento 5/3 debe ser ERROR_NO_CORREGIBLE, obtenido %s", result.NewState)
	}
}

func TestLifecycle_BeginRemove(t *testing.T) {
	lc := NewLifecycle(nil)

	next, err := lc.BeginRemove(StateInstalled)
	if err != nil {
		t.Errorf("BeginRemove(INSTALADA): %v", err)
	}
	if next != StateUninstalled {
		t.Errorf("esperado DESINSTALADA, obtenido %s", next)
	}

	_, err = lc.BeginRemove(StatePending)
	if err == nil {
		t.Error("BeginRemove(PENDIENTE) debe fallar")
	}
}

func TestLifecycle_Timeouts(t *testing.T) {
	lc := NewLifecycle(nil)

	if lc.TimeoutFor(OpInstall) != 30*time.Minute {
		t.Errorf("timeout install debe ser 30min, obtenido %v", lc.TimeoutFor(OpInstall))
	}
	if lc.TimeoutFor(OpUpdate) != 15*time.Minute {
		t.Errorf("timeout update debe ser 15min, obtenido %v", lc.TimeoutFor(OpUpdate))
	}
	if lc.TimeoutFor(OpRepair) != 10*time.Minute {
		t.Errorf("timeout repair debe ser 10min, obtenido %v", lc.TimeoutFor(OpRepair))
	}
	if lc.TimeoutFor(OpRemove) != 10*time.Minute {
		t.Errorf("timeout remove debe ser 10min, obtenido %v", lc.TimeoutFor(OpRemove))
	}

	// Custom timeout
	lc.SetTimeout(OpInstall, 5*time.Minute)
	if lc.TimeoutFor(OpInstall) != 5*time.Minute {
		t.Error("SetTimeout no funcionó")
	}
}

func TestVersionLabel(t *testing.T) {
	if VersionLabel("18.4.0") != "INSTALLED_v18.4.0" {
		t.Errorf("esperado INSTALLED_v18.4.0, obtenido %s", VersionLabel("18.4.0"))
	}
	if VersionLabel("") != "INSTALLED" {
		t.Error("versión vacía debe ser INSTALADA")
	}
	if VersionLabel("latest") != "INSTALLED" {
		t.Error("latest debe ser INSTALADA")
	}
}

func TestLifecycle_CompleteInstall(t *testing.T) {
	lc := NewLifecycle(nil)

	// Éxito
	state, compensated := lc.CompleteInstall(true, false)
	if state != StateInstalled || compensated {
		t.Error("éxito: INSTALADA, sin compensación")
	}

	// Fallo con backup → ROLLBACK
	state, compensated = lc.CompleteInstall(false, true)
	if state != StateRollback || compensated {
		t.Error("fallo con backup: ROLLBACK, sin compensación inmediata")
	}

	// Fallo sin backup → LIMPIEZA
	state, compensated = lc.CompleteInstall(false, false)
	if state != StateCleanup || compensated {
		t.Error("fallo sin backup: LIMPIEZA, sin compensación inmediata")
	}
}

func TestLifecycle_UpdateAvailability(t *testing.T) {
	lc := NewLifecycle(nil)

	// Hay update disponible (2.0.0 > 1.0.0)
	available, state := lc.UpdateAvailability(
		Version{1, 0, 0}, Version{2, 0, 0},
	)
	if !available || state != StateUpdateAvailable {
		t.Errorf("2.0.0 > 1.0.0 debe estar disponible, obtenido %v/%s", available, state)
	}

	// Misma versión → no disponible
	available, state = lc.UpdateAvailability(
		Version{1, 0, 0}, Version{1, 0, 0},
	)
	if available {
		t.Error("misma versión no debe estar disponible")
	}

	// Downgrade → no disponible
	available, state = lc.UpdateAvailability(
		Version{2, 0, 0}, Version{1, 0, 0},
	)
	if available {
		t.Error("downgrade no debe aparecer como disponible")
	}

	// MINOR bump → disponible
	available, state = lc.UpdateAvailability(
		Version{1, 0, 0}, Version{1, 5, 0},
	)
	if !available || state != StateUpdateAvailable {
		t.Error("MINOR bump debe estar disponible")
	}
}

func TestLifecycle_ApproveUpdate(t *testing.T) {
	lc := NewLifecycle(nil)

	// Aprobación normal MINOR
	state, err := lc.ApproveUpdate(
		Version{1, 0, 0}, Version{1, 1, 0}, true,
	)
	if err != nil || state != StateUpdateApproved {
		t.Errorf("MINOR debe aprobarse: state=%s err=%v", state, err)
	}

	// MAJOR sin compatibilidad → rechazado
	_, err = lc.ApproveUpdate(
		Version{1, 0, 0}, Version{2, 0, 0}, true,
	)
	if err == nil {
		t.Error("MAJOR sin script debe rechazarse (necesita migración)")
	}

	// Health degradado → rechazado
	_, err = lc.ApproveUpdate(
		Version{1, 0, 0}, Version{1, 1, 0}, false,
	)
	if err == nil {
		t.Error("health degradado debe rechazar actualización")
	}
}

func TestLifecycle_RejectUpdate(t *testing.T) {
	lc := NewLifecycle(nil)
	state := lc.RejectUpdate()
	if state != StateInstalled {
		t.Errorf("rechazar debe volver a INSTALADA, obtenido %s", state)
	}
}

func TestLifecycle_CompleteUpdate(t *testing.T) {
	lc := NewLifecycle(nil)

	// Éxito
	state, needsRollback := lc.CompleteUpdate(true, Version{1, 0, 0})
	if state != StateInstalled || needsRollback {
		t.Error("update exitoso: INSTALADA, sin rollback")
	}

	// Fallo → rollback
	state, needsRollback = lc.CompleteUpdate(false, Version{1, 0, 0})
	if state != StateRollback || !needsRollback {
		t.Error("update fallido: ROLLBACK con needsRollback=true")
	}
}

func TestLifecycle_Degrade(t *testing.T) {
	lc := NewLifecycle(nil)

	// No alcanza umbral
	_, err := lc.Degrade(2, 3)
	if err == nil {
		t.Error("2 fallos de 3 no debe degradar")
	}

	// Alcanza umbral
	state, err := lc.Degrade(3, 3)
	if err != nil || state != StateDegraded {
		t.Errorf("3 fallos debe degradar: state=%s err=%v", state, err)
	}
}

func TestLifecycle_RecoverAfterRepair(t *testing.T) {
	lc := NewLifecycle(nil)
	if lc.RecoverAfterRepair() != StateInstalled {
		t.Error("recover debe ser INSTALADA")
	}
}

func TestLifecycle_CleanupComplete(t *testing.T) {
	lc := NewLifecycle(nil)
	if lc.CleanupComplete() != StatePending {
		t.Error("cleanup debe devolver a PENDIENTE")
	}
}

func TestLifecycle_RollbackComplete(t *testing.T) {
	lc := NewLifecycle(nil)

	if lc.RollbackComplete(true) != StateInstalled {
		t.Error("rollback exitoso → INSTALADA")
	}
	if lc.RollbackComplete(false) != StateUnrecoverable {
		t.Error("rollback fallido → ERROR_NO_CORREGIBLE (HITL)")
	}
}

func TestLifecycle_Diagnose_Physical_Disk(t *testing.T) {
	lc := NewLifecycle(nil)

	diag := lc.Diagnose("ERROR: no space left on device /var/lib/postgresql", "command")
	if diag.Category != ErrPhysical {
		t.Errorf("disco lleno debe ser physical, obtenido %s", diag.Category)
	}
	if diag.Cause == "" {
		t.Error("debe tener causa")
	}
	if !diag.Recoverable {
		t.Error("disco lleno debe ser recuperable")
	}
}

func TestLifecycle_Diagnose_Physical_Network(t *testing.T) {
	lc := NewLifecycle(nil)

	diag := lc.Diagnose("dial tcp 10.0.0.1:5432: connect: connection refused", "command")
	if diag.Category != ErrPhysical {
		t.Errorf("red debe ser physical, obtenido %s", diag.Category)
	}
}

func TestLifecycle_Diagnose_Physical_Memory(t *testing.T) {
	lc := NewLifecycle(nil)

	diag := lc.Diagnose("FATAL: out of memory - process killed by OOM killer", "command")
	if diag.Category != ErrPhysical {
		t.Errorf("OOM debe ser physical, obtenido %s", diag.Category)
	}
}

func TestLifecycle_Diagnose_Logical_Config(t *testing.T) {
	lc := NewLifecycle(nil)

	diag := lc.Diagnose("syntax error in manifest.yml: invalid yaml at line 42", "command")
	if diag.Category != ErrLogical {
		t.Errorf("syntax error debe ser logical, obtenido %s", diag.Category)
	}
}

func TestLifecycle_Diagnose_Logical_Dependency(t *testing.T) {
	lc := NewLifecycle(nil)

	diag := lc.Diagnose("Error: dependency 'vault' not found - cannot resolve", "command")
	if diag.Category != ErrLogical {
		t.Errorf("dependency missing debe ser logical, obtenido %s", diag.Category)
	}
}

func TestLifecycle_Diagnose_Logical_Permission(t *testing.T) {
	lc := NewLifecycle(nil)

	diag := lc.Diagnose("permission denied: cannot access /etc/bos/certs/bos.key", "command")
	if diag.Category != ErrLogical {
		t.Errorf("permisos debe ser logical, obtenido %s", diag.Category)
	}
}

func TestLifecycle_Diagnose_Logical_Schema(t *testing.T) {
	lc := NewLifecycle(nil)

	diag := lc.Diagnose("ERROR: column \"new_field\" does not exist - schema migration required", "command")
	if diag.Category != ErrLogical {
		t.Errorf("schema debe ser logical, obtenido %s", diag.Category)
	}
}

func TestLifecycle_Diagnose_Crash(t *testing.T) {
	lc := NewLifecycle(nil)

	diag := lc.Diagnose("SIGSEGV: segmentation fault at 0x7f8a4000", "command")
	if diag.Category != ErrLogical {
		t.Errorf("crash debe ser logical, obtenido %s", diag.Category)
	}
	if diag.Recoverable {
		t.Error("segfault NO debe ser recuperable automáticamente")
	}
}

func TestLifecycle_Diagnose_Unknown(t *testing.T) {
	lc := NewLifecycle(nil)

	diag := lc.Diagnose("some random error that doesn't match any pattern", "command")
	if diag.Category != ErrUnknown {
		t.Errorf("error genérico debe ser unknown, obtenido %s", diag.Category)
	}
	if diag.Cause == "" {
		t.Error("unknown debe tener causa")
	}
}

func TestLifecycle_ClassifyState(t *testing.T) {
	lc := NewLifecycle(nil)

	if lc.ClassifyState(ErrorDiagnosis{Category: ErrPhysical}) != StatePhysicalError {
		t.Error("physical → ERROR_FISICO")
	}
	if lc.ClassifyState(ErrorDiagnosis{Category: ErrLogical}) != StateLogicalError {
		t.Error("logical → ERROR_LOGICO")
	}
	if lc.ClassifyState(ErrorDiagnosis{Category: ErrUnknown}) != StateLogicalError {
		t.Error("unknown → ERROR_LOGICO (default seguro)")
	}
}

func TestLifecycle_HITLRequest(t *testing.T) {
	lc := NewLifecycle(nil)

	diag := lc.Diagnose("SIGSEGV: core dump", "command")
	req := lc.EscalateToHITL("postgresql", diag, 3, 3)

	if req.FichaID != "postgresql" {
		t.Errorf("ficha debe ser postgresql, obtenido %s", req.FichaID)
	}
	if req.State != StateUnrecoverable {
		t.Errorf("estado debe ser ERROR_NO_CORREGIBLE, obtenido %s", req.State)
	}
	if req.Attempts != 3 {
		t.Errorf("attempts debe ser 3, obtenido %d", req.Attempts)
	}
	if req.Reason == "" {
		t.Error("debe tener razón")
	}
}

func TestLifecycle_IsRecoverableError(t *testing.T) {
	lc := NewLifecycle(nil)

	recoverable := ErrorDiagnosis{Category: ErrPhysical, Recoverable: true}
	if !lc.IsRecoverableError(recoverable) {
		t.Error("physical debe ser recuperable")
	}

	crash := ErrorDiagnosis{Category: ErrLogical, Recoverable: false}
	if lc.IsRecoverableError(crash) {
		t.Error("crash no debe ser recuperable")
	}
}

func TestLifecycle_FullErrorFlow(t *testing.T) {
	lc := NewLifecycle(nil)

	// 1. Health check falla → instalar está OK pero health degradado
	state, _ := lc.Degrade(3, 3)
	if state != StateDegraded {
		t.Fatalf("3 fallos deben degradar, obtenido %s", state)
	}

	// 2. Iniciar reparación
	next, err := lc.BeginRepair(state)
	if err != nil || next != StateRepairing {
		t.Fatalf("BeginRepair(DEGRADADA): %s err=%v", next, err)
	}

	// 3. Diagnosticar — es error lógico
	diag := lc.Diagnose("ERROR: configuration invalid: missing required field 'port'", "command")
	classified := lc.ClassifyState(diag)
	if classified != StateLogicalError {
		t.Errorf("config error → ERROR_LOGICO, obtenido %s", classified)
	}

	// 4. Reintento 1 — falla
	result := lc.EvaluateRepair(false, 1, 3)
	if result.NewState != StateRepairing {
		t.Error("intento 1 debe reintentar")
	}

	// 5. Reintento 3 — HITL
	result = lc.EvaluateRepair(false, 3, 3)
	if result.NewState != StateUnrecoverable {
		t.Error("intento 3 debe requerir HITL")
	}

	// 6. Escalar
	req := lc.EscalateToHITL("keycloak", diag, 3, 3)
	if req.State != StateUnrecoverable {
		t.Error("HITL debe ser ERROR_NO_CORREGIBLE")
	}
}

func TestLifecycle_RollbackSteps(t *testing.T) {
	lc := NewLifecycle(nil)
	steps := lc.RollbackSteps(Version{2, 0, 0}, Version{1, 0, 0})

	if len(steps) != 6 {
		t.Fatalf("esperado 6 pasos de rollback, obtenido %d", len(steps))
	}

	expectedSteps := []string{"verify_backup", "stop_current", "restore_backup", "start_service", "health_verify", "commit_state"}
	for i, expected := range expectedSteps {
		if steps[i].Name != expected {
			t.Errorf("paso[%d]: esperado %s, obtenido %s", i, expected, steps[i].Name)
		}
	}
}

func TestLifecycle_ExecuteRollback(t *testing.T) {
	lc := NewLifecycle(nil)

	result := lc.ExecuteRollback("postgresql", Version{2, 0, 0}, Version{1, 0, 0})

	if result.FichaID != "postgresql" {
		t.Errorf("ficha debe ser postgresql, obtenido %s", result.FichaID)
	}
	if !result.Success {
		t.Error("rollback simulado debe ser exitoso")
	}
	if result.FromVersion.String() != "2.0.0" {
		t.Errorf("from debe ser 2.0.0, obtenido %s", result.FromVersion)
	}
	if result.ToVersion.String() != "1.0.0" {
		t.Errorf("to debe ser 1.0.0, obtenido %s", result.ToVersion)
	}
	if len(result.Steps) != 6 {
		t.Errorf("esperado 6 pasos ejecutados, obtenido %d", len(result.Steps))
	}
	for _, step := range result.Steps {
		if step.Status != "ok" {
			t.Errorf("paso %s debe estar ok, está %s", step.Name, step.Status)
		}
	}
}

func TestLifecycle_CleanupSteps(t *testing.T) {
	lc := NewLifecycle(nil)
	steps := lc.CleanupSteps()

	if len(steps) != 7 {
		t.Fatalf("esperado 7 pasos de limpieza, obtenido %d", len(steps))
	}

	expectedSteps := []string{"stop_pods", "delete_workloads", "delete_configmaps", "delete_secrets",
		"delete_pvcs_temp", "clean_host_files", "verify_no_residue"}
	for i, expected := range expectedSteps {
		if steps[i].Name != expected {
			t.Errorf("paso[%d]: esperado %s, obtenido %s", i, expected, steps[i].Name)
		}
	}
}

func TestLifecycle_ExecuteCleanup(t *testing.T) {
	lc := NewLifecycle(nil)

	result := lc.ExecuteCleanup("test-ficha")

	if result.FichaID != "test-ficha" {
		t.Errorf("ficha debe ser test-ficha, obtenido %s", result.FichaID)
	}
	if !result.Success {
		t.Error("limpieza debe ser exitosa (sin residuos)")
	}
	if len(result.Residue) > 0 {
		t.Errorf("no debe haber residuos, encontrados: %v", result.Residue)
	}
	if len(result.Steps) != 7 {
		t.Errorf("esperado 7 pasos ejecutados, obtenido %d", len(result.Steps))
	}
}

func TestLifecycle_ExecuteRepair_Success(t *testing.T) {
	lc := NewLifecycle(nil)

	// Error de configuración (recuperable) — debe recuperarse en el 2do intento
	result := lc.ExecuteRepair("keycloak", 3, 10*time.Minute,
		"ERROR: configuration invalid: missing required port")

	if !result.Success {
		t.Errorf("debe recuperarse en 2do intento, pero falló: %v", result.Attempts)
	}
	if result.FinalState != StateInstalled {
		t.Errorf("final debe ser INSTALADA, obtenido %s", result.FinalState)
	}
	if result.TotalAttempts != 2 {
		t.Errorf("debe tomar 2 intentos, tomó %d", result.TotalAttempts)
	}
}

func TestLifecycle_ExecuteRepair_Exhausted(t *testing.T) {
	lc := NewLifecycle(nil)

	// Segfault (no recuperable) — debe agotar los 3 intentos
	result := lc.ExecuteRepair("postgresql", 3, 10*time.Minute,
		"SIGSEGV: segmentation fault at 0x7f8a4000")

	if result.Success {
		t.Error("crash no debe ser recuperable")
	}
	if result.FinalState != StateUnrecoverable {
		t.Errorf("final debe ser ERROR_NO_CORREGIBLE, obtenido %s", result.FinalState)
	}
	if result.TotalAttempts != 3 {
		t.Errorf("debe agotar 3 intentos, tomó %d", result.TotalAttempts)
	}
}

func TestLifecycle_ExecuteRepair_CustomMaxAttempts(t *testing.T) {
	lc := NewLifecycle(nil)

	// Solo 1 intento disponible
	result := lc.ExecuteRepair("redis", 1, 5*time.Minute,
		"connection refused to redis")

	if result.Success {
		t.Error("con 1 intento no debe recuperarse")
	}
	if result.FinalState != StateUnrecoverable {
		t.Errorf("final debe ser ERROR_NO_CORREGIBLE, obtenido %s", result.FinalState)
	}
	if result.TotalAttempts != 1 {
		t.Errorf("debe tomar 1 intento, tomó %d", result.TotalAttempts)
	}
}

func TestLifecycle_TransitionalStates_Complete(t *testing.T) {
	lc := NewLifecycle(nil)

	// Verificar que los 3 estados transicionales tienen íconos y descripciones
	for _, state := range []FichaState{StateRepairing, StateRollback, StateCleanup} {
		icon := StateIcon(state)
		if icon == "❓" {
			t.Errorf("estado %s debe tener ícono", state)
		}
		desc := StateDescription(state)
		if len(desc) < 10 {
			t.Errorf("estado %s debe tener descripción (>10 chars): %q", state, desc)
		}
		if !lc.sm.IsTransitional(state) {
			t.Errorf("%s debe ser transicional", state)
		}
	}
}

func TestDegradedHandler_EnterDegraded(t *testing.T) {
	lc := NewLifecycle(nil)
	dh := NewDegradedHandler("postgresql", lc, nil)

	err := dh.EnterDegraded(3, 3)
	if err != nil {
		t.Fatalf("EnterDegraded falló: %v", err)
	}
	if dh.state.DegradedSince.IsZero() {
		t.Error("debe registrar timestamp de degradación")
	}
	if dh.state.ConsecutiveHealthFails != 3 {
		t.Errorf("debe registrar 3 health fails, obtenido %d", dh.state.ConsecutiveHealthFails)
	}
}

func TestDegradedHandler_EnterDegraded_InsufficientFails(t *testing.T) {
	lc := NewLifecycle(nil)
	dh := NewDegradedHandler("redis", lc, nil)

	err := dh.EnterDegraded(2, 3)
	if err == nil {
		t.Error("2 fallos de 3 no deben degradar")
	}
}

func TestDegradedHandler_AttemptRepair_Recoverable(t *testing.T) {
	lc := NewLifecycle(nil)
	dh := NewDegradedHandler("keycloak", lc, nil)
	dh.EnterDegraded(3, 3)

	// Error de configuración (recuperable) — éxito en 2do intento
	ok, state := dh.AttemptRepair("ERROR: configuration invalid: port missing")
	if ok || state != StateRepairing {
		t.Logf("intento 1: ok=%v state=%s (esperado: reintentar)", ok, state)
	}

	// 2do intento — debe recuperar
	ok, state = dh.AttemptRepair("ERROR: configuration invalid: port missing")
	if !ok {
		t.Error("2do intento debe ser exitoso (simulación)")
	}
	if state != StateInstalled {
		t.Errorf("debe recuperar a INSTALADA, obtenido %s", state)
	}
	if dh.state.RepairAttempts != 2 {
		t.Errorf("debe registrar 2 intentos, obtenido %d", dh.state.RepairAttempts)
	}
}

func TestDegradedHandler_AttemptRepair_Exhausted(t *testing.T) {
	lc := NewLifecycle(nil)
	dh := NewDegradedHandler("vault", lc, nil)
	dh.EnterDegraded(5, 3)

	// 3 intentos fallidos → ERROR_NO_CORREGIBLE
	for i := 1; i <= 3; i++ {
		ok, state := dh.AttemptRepair("connection refused to vault")
		if i < 3 {
			if ok {
				t.Errorf("intento %d no debe ser exitoso", i)
			}
		} else {
			if ok {
				t.Error("intento 3 no debe ser exitoso")
			}
			if state != StateUnrecoverable {
				t.Errorf("intento 3: esperado ERROR_NO_CORREGIBLE, obtenido %s", state)
			}
		}
	}
}

func TestDegradedHandler_AttemptRepair_NonRecoverable(t *testing.T) {
	lc := NewLifecycle(nil)
	dh := NewDegradedHandler("bkernel", lc, nil)
	dh.EnterDegraded(3, 3)

	// Crash no recuperable → HITL inmediato
	ok, state := dh.AttemptRepair("SIGSEGV: segmentation fault in bkernel")
	if ok {
		t.Error("crash no debe ser recuperable")
	}
	if state != StateUnrecoverable {
		t.Errorf("crash debe ser ERROR_NO_CORREGIBLE, obtenido %s", state)
	}
}

func TestDegradedHandler_Recover(t *testing.T) {
	lc := NewLifecycle(nil)
	dh := NewDegradedHandler("nginx", lc, nil)
	dh.EnterDegraded(3, 3)

	state := dh.Recover()
	if state != StateInstalled {
		t.Errorf("recover debe ser INSTALADA, obtenido %s", state)
	}
}

func TestDegradedHandler_Escalate(t *testing.T) {
	lc := NewLifecycle(nil)
	dh := NewDegradedHandler("postgresql", lc, nil)
	dh.EnterDegraded(4, 3)

	diag := lc.Diagnose("no space left on device", "command")
	req := dh.Escalate(diag)

	if req.FichaID != "postgresql" {
		t.Errorf("ficha debe ser postgresql, obtenido %s", req.FichaID)
	}
	if req.State != StateUnrecoverable {
		t.Errorf("estado debe ser ERROR_NO_CORREGIBLE")
	}
}

func TestDegradedHandler_ShouldRetry(t *testing.T) {
	lc := NewLifecycle(nil)
	dh := NewDegradedHandler("test", lc, nil)
	dh.EnterDegraded(3, 3)

	if !dh.ShouldRetry() {
		t.Error("sin intentos debe poder reintentar")
	}
	if dh.RemainingAttempts() != 3 {
		t.Errorf("debe tener 3 intentos restantes, obtenido %d", dh.RemainingAttempts())
	}

	dh.AttemptRepair("error")
	if dh.RemainingAttempts() != 2 {
		t.Errorf("debe tener 2 intentos restantes, obtenido %d", dh.RemainingAttempts())
	}
}

func TestDegradedHandler_DegradedDuration(t *testing.T) {
	lc := NewLifecycle(nil)
	dh := NewDegradedHandler("test", lc, nil)

	if dh.DegradedDuration() != 0 {
		t.Error("sin degradar, duración debe ser 0")
	}

	dh.EnterDegraded(3, 3)
	dur := dh.DegradedDuration()
	if dur <= 0 {
		t.Error("tras degradar, duración debe ser > 0")
	}
}

func TestDegradedHandler_State(t *testing.T) {
	lc := NewLifecycle(nil)
	dh := NewDegradedHandler("postgresql", lc, nil)
	dh.EnterDegraded(3, 3)

	st := dh.State()
	if st.FichaID != "postgresql" {
		t.Errorf("ficha incorrecta: %s", st.FichaID)
	}
	if st.MaxAttempts != 3 {
		t.Errorf("maxAttempts debe ser 3, obtenido %d", st.MaxAttempts)
	}
	if !st.AutoRepairEnabled {
		t.Error("autoRepair debe estar enabled por defecto")
	}
}
