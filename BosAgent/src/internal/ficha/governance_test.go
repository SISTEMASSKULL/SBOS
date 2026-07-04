package ficha

import (
	"testing"
	"time"
)

func TestClassifyOperation(t *testing.T) {
	if ClassifyOperation(OpInstall) != RiskWrite {
		t.Error("install debe ser cat 2 (write)")
	}
	if ClassifyOperation(OpUpdate) != RiskWrite {
		t.Error("update debe ser cat 2 (write)")
	}
	if ClassifyOperation(OpRepair) != RiskWrite {
		t.Error("repair debe ser cat 2 (write)")
	}
	if ClassifyOperation(OpRemove) != RiskDestructive {
		t.Error("remove debe ser cat 3 (destructive)")
	}
	if ClassifyOperation("status") != RiskRead {
		t.Error("status debe ser cat 1 (read)")
	}
}

func TestClassifyCommand(t *testing.T) {
	if ClassifyCommand("scale", 0) != RiskDestructive {
		t.Error("scale a 0 debe ser cat 3")
	}
	if ClassifyCommand("scale", 3) != RiskWrite {
		t.Error("scale a 3 debe ser cat 2")
	}
	if ClassifyCommand("remove", 0) != RiskDestructive {
		t.Error("remove debe ser cat 3")
	}
	if ClassifyCommand("reset_state", 0) != RiskDestructive {
		t.Error("reset_state debe ser cat 3")
	}
}

func TestRequiresDualControl(t *testing.T) {
	if !RequiresDualControl(OpRemove) {
		t.Error("remove requiere dual-control")
	}
	if RequiresDualControl(OpInstall) {
		t.Error("install NO requiere dual-control")
	}
	if RequiresDualControl(OpRepair) {
		t.Error("repair NO requiere dual-control")
	}
}

func TestGenerateConfirmText(t *testing.T) {
	text := GenerateConfirmText("postgresql", OpRemove)
	expected := "REMOVE-POSTGRESQL"
	if text != expected {
		t.Errorf("esperado %q, obtenido %q", expected, text)
	}

	text2 := GenerateConfirmText("sbos-bootstrap-k8s", OpRemove)
	expected2 := "REMOVE-SBOSBOOTSTRAPK8S" // guiones removidos
	if text2 != expected2 {
		t.Errorf("esperado %q, obtenido %q", expected2, text2)
	}
}

func TestGovernanceEngine_RequestApproval(t *testing.T) {
	engine := NewGovernanceEngine()

	req, err := engine.RequestApproval("postgresql", OpRemove, "admin1")
	if err != nil {
		t.Fatalf("RequestApproval falló: %v", err)
	}

	if req.FichaID != "postgresql" {
		t.Errorf("ficha debe ser postgresql, obtenido %s", req.FichaID)
	}
	if req.Operation != OpRemove {
		t.Errorf("operación debe ser remove, obtenido %s", req.Operation)
	}
	if req.RequesterID != "admin1" {
		t.Errorf("requester debe ser admin1, obtenido %s", req.RequesterID)
	}
	if req.Status != "pending" {
		t.Errorf("estado debe ser pending, obtenido %s", req.Status)
	}
	if req.ID == "" {
		t.Error("token no debe estar vacío")
	}
	if req.ConfirmText == "" {
		t.Error("confirmText no debe estar vacío")
	}
	if len(req.AuditEvents) != 1 {
		t.Errorf("debe tener 1 audit event, obtenido %d", len(req.AuditEvents))
	}
}

func TestGovernanceEngine_RequestApproval_NonDestructive(t *testing.T) {
	engine := NewGovernanceEngine()

	_, err := engine.RequestApproval("nginx", OpInstall, "admin1")
	if err == nil {
		t.Error("install NO debe requerir aprobación dual")
	}
}

func TestGovernanceEngine_Approve(t *testing.T) {
	engine := NewGovernanceEngine()

	req, _ := engine.RequestApproval("keycloak", OpRemove, "admin1")

	// Admin B aprueba con texto correcto
	approved, err := engine.Approve(req.ID, req.ConfirmText, "admin2")
	if err != nil {
		t.Fatalf("Approve falló: %v", err)
	}
	if approved.Status != "approved" {
		t.Errorf("debe ser approved, obtenido %s", approved.Status)
	}
	if approved.ApproverID != "admin2" {
		t.Errorf("approver debe ser admin2, obtenido %s", approved.ApproverID)
	}
	if len(approved.AuditEvents) != 2 {
		t.Errorf("debe tener 2 audit events, obtenido %d", len(approved.AuditEvents))
	}
}

func TestGovernanceEngine_Approve_WrongText(t *testing.T) {
	engine := NewGovernanceEngine()

	req, _ := engine.RequestApproval("redis", OpRemove, "admin1")

	_, err := engine.Approve(req.ID, "TEXTO INCORRECTO", "admin2")
	if err == nil {
		t.Error("texto incorrecto debe rechazar")
	}
}

func TestGovernanceEngine_Approve_SameAdmin(t *testing.T) {
	engine := NewGovernanceEngine()

	req, _ := engine.RequestApproval("vault", OpRemove, "admin1")

	_, err := engine.Approve(req.ID, req.ConfirmText, "admin1")
	if err == nil {
		t.Error("el mismo admin no puede aprobar su propia solicitud")
	}
}

func TestGovernanceEngine_Approve_Expired(t *testing.T) {
	engine := NewGovernanceEngine()
	engine.approvalWindow = 1 * time.Millisecond // expira casi inmediato

	req, _ := engine.RequestApproval("kong", OpRemove, "admin1")

	time.Sleep(5 * time.Millisecond) // esperar que expire

	_, err := engine.Approve(req.ID, req.ConfirmText, "admin2")
	if err == nil {
		t.Error("solicitud expirada debe rechazar")
	}
}

func TestGovernanceEngine_Reject(t *testing.T) {
	engine := NewGovernanceEngine()

	req, _ := engine.RequestApproval("minio", OpRemove, "admin1")

	rejected, err := engine.Reject(req.ID, "admin2", "no es necesario eliminar")
	if err != nil {
		t.Fatalf("Reject falló: %v", err)
	}
	if rejected.Status != "rejected" {
		t.Errorf("debe ser rejected, obtenido %s", rejected.Status)
	}
}

func TestGovernanceEngine_GetPending(t *testing.T) {
	engine := NewGovernanceEngine()

	req, _ := engine.RequestApproval("prometheus", OpRemove, "admin1")

	found, ok := engine.GetPending(req.ID)
	if !ok {
		t.Fatal("debe encontrar la solicitud pendiente")
	}
	if found.FichaID != "prometheus" {
		t.Errorf("ficha incorrecta: %s", found.FichaID)
	}
}

func TestGovernanceEngine_ListPending(t *testing.T) {
	engine := NewGovernanceEngine()

	engine.RequestApproval("pg", OpRemove, "admin1")
	engine.RequestApproval("rd", OpRemove, "admin1")
	engine.RequestApproval("kc", OpRemove, "admin1")

	pending := engine.ListPending()
	if len(pending) != 3 {
		t.Errorf("debe haber 3 pendientes, obtenido %d", len(pending))
	}
}

func TestGovernanceEngine_CleanupExpired(t *testing.T) {
	engine := NewGovernanceEngine()
	engine.approvalWindow = 1 * time.Millisecond

	engine.RequestApproval("test1", OpRemove, "admin1")
	engine.RequestApproval("test2", OpRemove, "admin1")

	time.Sleep(5 * time.Millisecond)

	removed := engine.CleanupExpired()
	if removed != 2 {
		t.Errorf("debe limpiar 2 expiradas, limpió %d", removed)
	}
	if len(engine.ListPending()) != 0 {
		t.Error("no deben quedar pendientes tras cleanup")
	}
}

func TestGovernanceEngine_DualControlFullFlow(t *testing.T) {
	engine := NewGovernanceEngine()

	// 1. Admin A solicita eliminar postgresql
	req, err := engine.RequestApproval("postgresql", OpRemove, "alice")
	if err != nil {
		t.Fatalf("paso 1 falló: %v", err)
	}

	// 2. Verificar que está pendiente
	if _, ok := engine.GetPending(req.ID); !ok {
		t.Fatal("debe estar pendiente tras solicitud")
	}

	// 3. Intentar aprobar con el mismo admin (debe fallar)
	_, err = engine.Approve(req.ID, req.ConfirmText, "alice")
	if err == nil {
		t.Error("mismo admin debe ser rechazado")
	}

	// 4. Intentar aprobar con texto incorrecto (debe fallar)
	_, err = engine.Approve(req.ID, "wrong", "bob")
	if err == nil {
		t.Error("texto incorrecto debe ser rechazado")
	}

	// 5. Admin B aprueba correctamente
	approved, err := engine.Approve(req.ID, req.ConfirmText, "bob")
	if err != nil {
		t.Fatalf("aprobación final falló: %v", err)
	}
	if approved.Status != "approved" {
		t.Errorf("debe ser approved, obtenido %s", approved.Status)
	}

	// 6. Verificar que ya no está pendiente
	if _, ok := engine.GetPending(req.ID); ok {
		t.Error("no debe estar pendiente tras aprobación")
	}

	// 7. Verificar audit trail
	if len(approved.AuditEvents) != 3 {
		t.Errorf("debe tener 3 audit events: requested + rejected(wrong text) + approved, obtenido %d", len(approved.AuditEvents))
	}
}
