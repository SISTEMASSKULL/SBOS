// Package context — tests de F5.1: tipos fundamentales del Context Plane.
package context

import (
	"testing"
	"time"
)

// TestContextState_7EstadosDefinidos verifica que los 7 estados canónicos existen
// y que sus representaciones en string coinciden con la nomenclatura SBOS-049.
func TestContextState_7EstadosDefinidos(t *testing.T) {
	estados := []struct {
		estado ContextState
		nombre string
	}{
		{StatePendiente, "PENDIENTE"},
		{StateActivo, "ACTIVO"},
		{StateSuspendido, "SUSPENDIDO"},
		{StateBloqueado, "BLOQUEADO"},
		{StateInvalidado, "INVALIDADO"},
		{StateExpirado, "EXPIRADO"},
		{StateArchivado, "ARCHIVADO"},
	}
	if len(estados) != 7 {
		t.Fatalf("deben ser exactamente 7 estados, se definieron %d", len(estados))
	}
	for _, tc := range estados {
		if got := tc.estado.String(); got != tc.nombre {
			t.Errorf("estado %d: String() = %q, quiero %q", int(tc.estado), got, tc.nombre)
		}
	}
	// estados terminales
	terminales := []ContextState{StateInvalidado, StateExpirado, StateArchivado}
	for _, s := range terminales {
		if !s.IsTerminal() {
			t.Errorf("estado %s debe ser terminal", s)
		}
	}
	// estados no terminales
	noTerminales := []ContextState{StatePendiente, StateActivo, StateSuspendido, StateBloqueado}
	for _, s := range noTerminales {
		if s.IsTerminal() {
			t.Errorf("estado %s NO debe ser terminal", s)
		}
	}
}

// TestBitMask_OperacionesBasicas verifica Has/Add/Remove y los invariantes de BitMask.
func TestBitMask_OperacionesBasicas(t *testing.T) {
	const (
		FlagRead  BitMask = 1 << 0
		FlagWrite BitMask = 1 << 1
		FlagAdmin BitMask = 1 << 63
	)

	var mask BitMask

	// estado inicial
	if !mask.IsZero() {
		t.Error("BitMask nueva debe ser cero")
	}
	if mask.Has(FlagRead) {
		t.Error("BitMask cero no debe tener ningún flag")
	}

	// Add
	mask = mask.Add(FlagRead)
	if !mask.Has(FlagRead) {
		t.Error("tras Add(FlagRead) debe tener FlagRead")
	}
	if mask.Has(FlagWrite) {
		t.Error("no debe tener FlagWrite aún")
	}

	// Add múltiple
	mask = mask.Add(FlagWrite).Add(FlagAdmin)
	if !mask.Has(FlagRead) || !mask.Has(FlagWrite) || !mask.Has(FlagAdmin) {
		t.Error("debe tener los tres flags")
	}

	// Remove
	mask = mask.Remove(FlagWrite)
	if mask.Has(FlagWrite) {
		t.Error("tras Remove(FlagWrite) no debe tener FlagWrite")
	}
	if !mask.Has(FlagRead) || !mask.Has(FlagAdmin) {
		t.Error("los otros flags deben permanecer")
	}

	// Has con flag == 0 es siempre false (evita falsos positivos)
	if mask.Has(0) {
		t.Error("Has(0) debe retornar false")
	}

	// idempotencia Add
	antes := mask
	mask = mask.Add(FlagRead)
	if mask != antes {
		t.Error("Add de un flag ya presente no debe cambiar la máscara")
	}
}

// TestDeviceContext_BitMaskCero verifica que DeviceContext siempre tiene BitMask == 0.
func TestDeviceContext_BitMaskCero(t *testing.T) {
	dctx, err := NewDeviceContext("host-01.skull.local", "skull", "node-01", "10.0.0.5")
	if err != nil {
		t.Fatalf("NewDeviceContext: %v", err)
	}

	// invariante pre-auth
	if dctx.BitMask != 0 {
		t.Errorf("DeviceContext.BitMask debe ser 0, got %d", dctx.BitMask)
	}
	if err := dctx.Validate(); err != nil {
		t.Errorf("Validate() no debe fallar: %v", err)
	}

	// ID generado correctamente
	if dctx.DctxID == "" {
		t.Error("DctxID debe ser no vacío")
	}
	if len(dctx.DctxID) < 5 {
		t.Errorf("DctxID muy corto: %q", dctx.DctxID)
	}

	// TTL correcto
	if dctx.ExpiresAt.IsZero() {
		t.Error("ExpiresAt no debe ser zero")
	}
	duracion := dctx.ExpiresAt.Sub(dctx.CreatedAt)
	if duracion < MaxDeviceTTL-time.Second || duracion > MaxDeviceTTL+time.Second {
		t.Errorf("TTL esperado ~%v, got %v", MaxDeviceTTL, duracion)
	}

	// estado inicial
	if dctx.State != StatePendiente {
		t.Errorf("estado inicial debe ser PENDIENTE, got %s", dctx.State)
	}

	// Validate falla si se asigna BitMask > 0 (invariante)
	dctx.BitMask = 1
	if err := dctx.Validate(); err == nil {
		t.Error("Validate debe fallar cuando BitMask != 0 en DeviceContext")
	}

	// campos obligatorios
	_, err = NewDeviceContext("", "skull", "", "")
	if err == nil {
		t.Error("debe fallar con hostname vacío")
	}
	_, err = NewDeviceContext("host", "", "", "")
	if err == nil {
		t.Error("debe fallar con tenantID vacío")
	}
}

// TestSessionContext_BitMaskPositivo verifica que SessionContext requiere BitMask > 0.
func TestSessionContext_BitMaskPositivo(t *testing.T) {
	const mask BitMask = 0b1010_1010_0000_0001 // permisos típicos post-auth

	sctx, err := NewSessionContext(
		"dctx-abc12345",
		"skull", "TS-01", "SUC-01", "POS-01",
		"usr_ivan",
		mask,
		2,
		"00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
	)
	if err != nil {
		t.Fatalf("NewSessionContext: %v", err)
	}

	// invariante post-auth
	if sctx.BitMask == 0 {
		t.Error("SessionContext.BitMask no debe ser 0 (post-auth)")
	}
	if sctx.BitMask != mask {
		t.Errorf("BitMask: want %d, got %d", mask, sctx.BitMask)
	}
	if err := sctx.Validate(); err != nil {
		t.Errorf("Validate() no debe fallar: %v", err)
	}

	// campo CtxID generado
	if sctx.CtxID == "" {
		t.Error("CtxID debe ser no vacío")
	}

	// DctxID preservado
	if sctx.DctxID != "dctx-abc12345" {
		t.Errorf("DctxID: want dctx-abc12345, got %s", sctx.DctxID)
	}

	// LoA
	if sctx.LoA != 2 {
		t.Errorf("LoA: want 2, got %d", sctx.LoA)
	}

	// TTL correcto
	duracion := sctx.ExpiresAt.Sub(sctx.CreatedAt)
	if duracion < MaxSessionTTL-time.Second || duracion > MaxSessionTTL+time.Second {
		t.Errorf("TTL esperado ~%v, got %v", MaxSessionTTL, duracion)
	}

	// estado inicial ACTIVO (post-auth, ya validado)
	if sctx.State != StateActivo {
		t.Errorf("estado inicial debe ser ACTIVO, got %s", sctx.State)
	}

	// Traceparent preservado
	if sctx.Traceparent == "" {
		t.Error("Traceparent no debe ser vacío")
	}

	// Label() correcto
	label := sctx.Label()
	if label != "skull/TS-01/SUC-01/POS-01/usr_ivan" {
		t.Errorf("Label() = %q", label)
	}

	// debe fallar con BitMask == 0
	_, err = NewSessionContext("dctx-1", "skull", "TS-01", "SUC-01", "POS-01", "usr", 0, 1, "")
	if err == nil {
		t.Error("debe fallar con BitMask == 0")
	}

	// debe fallar con LoA inválido
	_, err = NewSessionContext("dctx-1", "skull", "", "", "", "usr", mask, 5, "")
	if err == nil {
		t.Error("debe fallar con LoA = 5")
	}
	_, err = NewSessionContext("dctx-1", "skull", "", "", "", "usr", mask, 0, "")
	if err == nil {
		t.Error("debe fallar con LoA = 0")
	}

	// campos obligatorios
	_, err = NewSessionContext("", "", "", "", "", "", mask, 1, "")
	if err == nil {
		t.Error("debe fallar con tenantID y userID vacíos")
	}
}
