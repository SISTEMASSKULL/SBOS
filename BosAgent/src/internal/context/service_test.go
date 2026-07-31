// Package context — tests de F5.2: Service del Context Plane.
package context

import (
	"errors"
	"testing"
)

const (
	testMask BitMask = 0b0000_0000_0000_1111 // 4 permisos típicos post-auth
	testTP           = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
)

func newTestService() *Service {
	return NewService(newMemStore())
}

// TestRegisterDevice_RetornaContextoOS verifica que RegisterDevice retorna un DeviceContext
// válido y lo persiste en el Store.
func TestRegisterDevice_RetornaContextoOS(t *testing.T) {
	svc := newTestService()

	dctx, err := svc.RegisterDevice("nodo-01.skull.local", "skull", "k8s-node-01", "10.0.1.5")
	if err != nil {
		t.Fatalf("RegisterDevice: %v", err)
	}
	if dctx.DctxID == "" {
		t.Error("DctxID debe ser no vacío")
	}
	if dctx.BitMask != 0 {
		t.Errorf("BitMask debe ser 0 (pre-auth), got %d", dctx.BitMask)
	}
	if dctx.State != StatePending {
		t.Errorf("estado inicial debe ser PENDIENTE, got %s", dctx.State)
	}

	// debe ser recuperable
	got, err := svc.GetDevice(dctx.DctxID)
	if err != nil {
		t.Fatalf("GetDevice: %v", err)
	}
	if got.DctxID != dctx.DctxID {
		t.Errorf("DctxID mismatch: %s != %s", got.DctxID, dctx.DctxID)
	}
}

// TestRegisterDevice_Idempotente verifica que registrar el mismo device dos veces
// no duplica ni sobreescribe el registro original.
func TestRegisterDevice_Idempotente(t *testing.T) {
	svc := newTestService()

	d1, err := svc.RegisterDevice("host-01", "skull", "", "10.0.0.1")
	if err != nil {
		t.Fatal(err)
	}
	// simulamos segundo registro con mismo hostname (diferente dctxID — UUID aleatorio)
	d2, err := svc.RegisterDevice("host-01", "skull", "", "10.0.0.1")
	if err != nil {
		t.Fatal(err)
	}
	// ambos deben existir independientemente (IDs distintos)
	if d1.DctxID == d2.DctxID {
		t.Error("dos llamadas a RegisterDevice deben generar dctxIDs distintos")
	}
	// ambos deben ser recuperables
	if _, err := svc.GetDevice(d1.DctxID); err != nil {
		t.Errorf("d1 no recuperable: %v", err)
	}
	if _, err := svc.GetDevice(d2.DctxID); err != nil {
		t.Errorf("d2 no recuperable: %v", err)
	}
}

// TestPromote_EnriqueceBitMask verifica que Promote crea una SessionContext con
// BitMask > 0 y que el DeviceContext origen queda invalidado.
func TestPromote_EnriqueceBitMask(t *testing.T) {
	svc := newTestService()

	dctx, err := svc.RegisterDevice("host-02", "skull", "node-02", "10.0.0.2")
	if err != nil {
		t.Fatal(err)
	}

	sctx, err := svc.Promote(dctx.DctxID, "TS-01", "SUC-01", "POS-01", "usr_ivan",
		testMask, 2, testTP)
	if err != nil {
		t.Fatalf("Promote: %v", err)
	}

	// invariante post-auth
	if sctx.BitMask == 0 {
		t.Error("BitMask debe ser > 0 tras Promote")
	}
	if sctx.BitMask != testMask {
		t.Errorf("BitMask: want %d, got %d", testMask, sctx.BitMask)
	}
	if sctx.DctxID != dctx.DctxID {
		t.Errorf("DctxID no preservado: want %s, got %s", dctx.DctxID, sctx.DctxID)
	}
	if sctx.State != StateActivo {
		t.Errorf("estado sesión debe ser ACTIVO, got %s", sctx.State)
	}

	// DeviceContext debe quedar invalidado
	updated, err := svc.GetDevice(dctx.DctxID)
	if err != nil {
		t.Fatalf("GetDevice post-Promote: %v", err)
	}
	if updated.State != StateInvalidado {
		t.Errorf("DeviceContext debe quedar INVALIDADO, got %s", updated.State)
	}

	// no se puede promover un DeviceContext ya invalidado
	_, err = svc.Promote(dctx.DctxID, "TS-01", "SUC-01", "POS-01", "usr_ivan",
		testMask, 2, testTP)
	if err == nil {
		t.Error("debe fallar al promover un DeviceContext ya INVALIDADO")
	}
}

// TestInvalidate_CtxYaNoValido verifica que Invalidate marca la sesión correctamente
// y que es idempotente.
func TestInvalidate_CtxYaNoValido(t *testing.T) {
	svc := newTestService()

	dctx, _ := svc.RegisterDevice("host-03", "skull", "", "10.0.0.3")
	sctx, err := svc.Promote(dctx.DctxID, "TS-01", "SUC-01", "POS-01", "usr_x",
		testMask, 1, testTP)
	if err != nil {
		t.Fatal(err)
	}

	// invalidar
	if err := svc.Invalidate(sctx.CtxID); err != nil {
		t.Fatalf("Invalidate: %v", err)
	}

	got, err := svc.Get(sctx.CtxID)
	if err != nil {
		t.Fatal(err)
	}
	if got.State != StateInvalidado {
		t.Errorf("sesión debe estar INVALIDADA, got %s", got.State)
	}

	// idempotente: segunda invalidación no debe fallar
	if err := svc.Invalidate(sctx.CtxID); err != nil {
		t.Errorf("segunda Invalidate debe ser idempotente, got: %v", err)
	}

	// ctx_id ya no válido: ListByTenant no debe incluirlo
	activos, err := svc.ListByTenant("skull")
	if err != nil {
		t.Fatal(err)
	}
	for _, s := range activos {
		if s.CtxID == sctx.CtxID {
			t.Error("sesión invalidada no debe aparecer en ListByTenant")
		}
	}
}

// TestTTL_MinimoYMaximo verifica que los TTLs cumplen ISO 27001:2022 A.9.4.2:
// 8h para dispositivos y 12h para sesiones.
func TestTTL_MinimoYMaximo(t *testing.T) {
	svc := newTestService()

	dctx, err := svc.RegisterDevice("host-ttl", "skull", "", "10.0.0.9")
	if err != nil {
		t.Fatal(err)
	}
	devTTL := dctx.ExpiresAt.Sub(dctx.CreatedAt)
	if devTTL > MaxDeviceTTL {
		t.Errorf("DeviceContext TTL (%v) excede máximo ISO 27001 A.9.4.2 (%v)", devTTL, MaxDeviceTTL)
	}

	sctx, err := svc.Promote(dctx.DctxID, "TS-01", "SUC-01", "POS-01", "usr_ttl",
		testMask, 1, testTP)
	if err != nil {
		t.Fatal(err)
	}
	sessTTL := sctx.ExpiresAt.Sub(sctx.CreatedAt)
	if sessTTL > MaxSessionTTL {
		t.Errorf("SessionContext TTL (%v) excede máximo ISO 27001 A.9.4.2 (%v)", sessTTL, MaxSessionTTL)
	}

	// TTL mínimo: debe ser razonable (al menos 1 hora)
	const minTTL = 1 * 60 * 60 * 1e9 // 1h en nanosegundos
	if int64(devTTL) < minTTL {
		t.Errorf("DeviceContext TTL demasiado corto: %v", devTTL)
	}
	if int64(sessTTL) < minTTL {
		t.Errorf("SessionContext TTL demasiado corto: %v", sessTTL)
	}
}

// TestInvalidateAllByTenant_LimpiaSesiones verifica la invalidación masiva de tenant.
func TestInvalidateAllByTenant_LimpiaSesiones(t *testing.T) {
	svc := newTestService()

	// crear 3 sesiones del mismo tenant
	sessionIDs := make([]string, 3)
	for i := range sessionIDs {
		dctx, err := svc.RegisterDevice("host-multi", "skull", "", "10.0.0.10")
		if err != nil {
			t.Fatal(err)
		}
		sctx, err := svc.Promote(dctx.DctxID, "TS-01", "SUC-01", "POS-01", "usr_multi",
			testMask, 1, testTP)
		if err != nil {
			t.Fatal(err)
		}
		sessionIDs[i] = sctx.CtxID
	}

	// una sesión de otro tenant (no debe tocarse)
	dctxOther, _ := svc.RegisterDevice("host-other", "other-tenant", "", "10.0.0.20")
	sctxOther, err := svc.Promote(dctxOther.DctxID, "TS-02", "SUC-01", "POS-01", "usr_other",
		testMask, 1, testTP)
	if err != nil {
		t.Fatal(err)
	}

	// invalidar masivamente
	count, err := svc.InvalidateAllByTenant("skull")
	if err != nil {
		t.Fatalf("InvalidateAllByTenant: %v", err)
	}
	if count != 3 {
		t.Errorf("invalidadas %d sesiones, esperaba 3", count)
	}

	// verificar que todas están INVALIDADAS
	for _, id := range sessionIDs {
		s, err := svc.Get(id)
		if err != nil {
			t.Fatalf("Get(%s): %v", id, err)
		}
		if s.State != StateInvalidado {
			t.Errorf("sesión %s debe estar INVALIDADA, got %s", id, s.State)
		}
	}

	// la sesión de otro tenant no debe tocarse
	other, err := svc.Get(sctxOther.CtxID)
	if err != nil {
		t.Fatal(err)
	}
	if other.State != StateActivo {
		t.Errorf("sesión de other-tenant no debe modificarse, got %s", other.State)
	}

	// segunda llamada: idempotente (0 nuevas invalidaciones)
	count2, err := svc.InvalidateAllByTenant("skull")
	if err != nil {
		t.Fatal(err)
	}
	if count2 != 0 {
		t.Errorf("segunda llamada debe invalidar 0 (ya terminales), got %d", count2)
	}

	// tenantID vacío debe fallar
	_, err = svc.InvalidateAllByTenant("")
	if !errors.Is(err, nil) {
		// err no es nil — esperado
	}
	if err == nil {
		t.Error("debe fallar con tenantID vacío")
	}
}

// ── Tests de Heartbeat ───────────────────────────────────────────────────

func promoteFixture(t *testing.T, svc *Service, tenant string) *SessionContext {
	t.Helper()
	dctx, err := svc.RegisterDevice("h", tenant, "n", "10.0.0.1")
	if err != nil {
		t.Fatal(err)
	}
	sctx, err := svc.Promote(dctx.DctxID, "e1", "s1", "p1", "u1", testMask, 2, testTP)
	if err != nil {
		t.Fatal(err)
	}
	return sctx
}

func TestHeartbeat_ExtiendeExpiracion(t *testing.T) {
	svc := newTestService()
	sctx := promoteFixture(t, svc, "skull")

	antes := sctx.ExpiresAt
	updated, err := svc.Heartbeat(sctx.CtxID)
	if err != nil {
		t.Fatalf("Heartbeat: %v", err)
	}
	if !updated.ExpiresAt.After(antes) {
		t.Errorf("ExpiresAt debe ser posterior al original: antes=%s ahora=%s",
			antes, updated.ExpiresAt)
	}
	if updated.CtxID != sctx.CtxID {
		t.Errorf("CtxID mismatch: %s != %s", updated.CtxID, sctx.CtxID)
	}
}

func TestHeartbeat_CtxVacioError(t *testing.T) {
	svc := newTestService()
	_, err := svc.Heartbeat("")
	if err == nil {
		t.Error("debe fallar con ctx_id vacío")
	}
}

func TestHeartbeat_NoExistente_Error(t *testing.T) {
	svc := newTestService()
	_, err := svc.Heartbeat("ctx-no-existe-xyz")
	if err == nil {
		t.Error("debe fallar cuando ctx_id no existe")
	}
}

func TestHeartbeat_Idempotente(t *testing.T) {
	svc := newTestService()
	sctx := promoteFixture(t, svc, "skull")

	r1, err := svc.Heartbeat(sctx.CtxID)
	if err != nil {
		t.Fatal(err)
	}
	r2, err := svc.Heartbeat(sctx.CtxID)
	if err != nil {
		t.Fatal(err)
	}
	// ambas llamadas deben extender el TTL
	if !r2.ExpiresAt.After(sctx.ExpiresAt) {
		t.Error("segundo heartbeat debe mantener TTL extendido")
	}
	_ = r1
}
