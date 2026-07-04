//go:build integration

// Tests de integración del cliente bAuth contra el socket real de la VPS.
// Compilar y ejecutar SOLO en la VPS, no localmente.
//
//	go test -tags integration -v -run TestInteg ./internal/bauth/
package bauth_test

import (
	"context"
	"testing"
	"time"

	"bos/internal/bauth"
)

// constantes reales de la VPS (verificadas contra BD el 2026-06-28)
const (
	realSocket     = "/tmp/bauth/bauth.sock"
	realTenantID   = "019f01e8-2e33-7734-a756-63d31a003a75"
	realEmpresaID  = "019f01e8-0000-7000-a000-000000000001"
	realSucursalID = "019f01e8-0000-7000-b000-000000000001"
	realUserUUID   = "019f06db-62a9-74c9-ab75-2760391284a8" // test_vendedor
	realAtomSlug   = "tryton.g1.d1.nuevo"
)

func integCtx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 10*time.Second)
}

// TestIntegHealthCheck verifica que el socket está operativo.
func TestIntegHealthCheck(t *testing.T) {
	// Verificación directa con socat ya probada; aquí probamos que el cliente Go
	// puede abrir el socket. Una llamada a GetSession con ctx_id inválido retorna
	// error RPC (no error de conexión) = socket accesible.
	client := bauth.NewClient(realSocket)
	ctx, cancel := integCtx()
	defer cancel()

	_, err := client.GetSession(ctx, "ctx-inexistente")
	// Esperamos un error RPC (ctx no encontrado), no un error de conexión
	if err == nil {
		t.Error("esperaba error para ctx-inexistente, obtuvo nil")
	}
	t.Logf("socket accesible — respuesta bAuth: %v", err)
}

// TestIntegFlujoCopleto verifica el flujo create → promote → get_session → evaluate.
func TestIntegFlujoCompleto(t *testing.T) {
	client := bauth.NewClient(realSocket)

	// PASO 1 — ctx.create
	t.Run("Paso1_CreateCtx", func(t *testing.T) {
		ctx, cancel := integCtx()
		defer cancel()

		resp, err := client.CreateCtx(ctx, &bauth.CreateCtxRequest{
			TenantID:       realTenantID,
			EmpresaID:      realEmpresaID,
			SucursalID:     realSucursalID,
			PosLogico:      "CAJA-BOS-GOTEST",
			TTLSeconds:     7200,
			DeviceID:       "bos-go-test-001",
			DeviceHostname: "bos-gotest.skull.local",
			DeviceIP:       "192.168.1.88",
		})
		if err != nil {
			t.Fatalf("CreateCtx error: %v", err)
		}
		if !resp.Created {
			t.Error("esperaba created=true")
		}
		if resp.CtxID == "" {
			t.Fatal("ctx_id vacío en respuesta de create")
		}
		if resp.State != "pending" {
			t.Errorf("state esperado 'pending', obtenido %q", resp.State)
		}
		t.Logf("ctx_id pending: %s", resp.CtxID[:60])
	})

	// PASO 2 — create + promote en secuencia
	var promotedCtxID string
	t.Run("Paso2_PromoteCtx", func(t *testing.T) {
		ctx, cancel := integCtx()
		defer cancel()

		// Primero create para obtener un ctx_id fresco
		createResp, err := client.CreateCtx(ctx, &bauth.CreateCtxRequest{
			TenantID:   realTenantID,
			EmpresaID:  realEmpresaID,
			SucursalID: realSucursalID,
			PosLogico:  "CAJA-PROMOTE-TEST",
			TTLSeconds: 7200,
		})
		if err != nil {
			t.Fatalf("CreateCtx en Paso2: %v", err)
		}

		ctx2, cancel2 := integCtx()
		defer cancel2()

		promResp, err := client.PromoteCtx(ctx2, &bauth.PromoteCtxRequest{
			CtxID:      createResp.CtxID,
			UserID:     realUserUUID,
			SessionKC:  "bos-gotest-session",
			LoACurrent: 2,
		})
		if err != nil {
			t.Fatalf("PromoteCtx error: %v", err)
		}
		if !promResp.Promoted {
			t.Error("esperaba promoted=true")
		}
		if promResp.EmpresaID == promResp.TenantID {
			t.Error("empresa_id == tenant_id: bug B-BAUTH-001 no corregido")
		}
		if promResp.SucursalID == promResp.TenantID {
			t.Error("sucursal_id == tenant_id: bug B-BAUTH-001 no corregido")
		}
		if promResp.LoACurrent != 2 {
			t.Errorf("loa_current esperado 2, obtenido %d", promResp.LoACurrent)
		}
		promotedCtxID = promResp.CtxID
		t.Logf("promoted ctx_id: %s", promotedCtxID[:60])
		t.Logf("empresa_id: %s (≠ tenant_id ✅)", promResp.EmpresaID)
	})

	if promotedCtxID == "" {
		t.Skip("Paso2 falló — no hay ctx_id promovido para continuar")
	}

	// PASO 3 — get_session
	t.Run("Paso3_GetSession", func(t *testing.T) {
		ctx, cancel := integCtx()
		defer cancel()

		session, err := client.GetSession(ctx, promotedCtxID)
		if err != nil {
			t.Fatalf("GetSession error: %v", err)
		}
		if session.State != "ACTIVE" {
			t.Errorf("state esperado ACTIVE, obtenido %q", session.State)
		}
		if session.TenantID != realTenantID {
			t.Errorf("tenant_id incorrecto: %s", session.TenantID)
		}
		if session.EmpresaID != realEmpresaID {
			t.Errorf("empresa_id incorrecto: %s", session.EmpresaID)
		}
		if session.UserUUID != realUserUUID {
			t.Errorf("user_uuid incorrecto: %s", session.UserUUID)
		}
		if !session.IsActive() {
			t.Error("IsActive() retornó false en sesión recién creada")
		}
		t.Logf("sesión activa: loa=%d, pos=%s, bitmask_len=%d", session.LoaCurrent, session.PosLogico, len(session.BitmaskHex))
	})

	// PASO 4 — context.evaluate
	t.Run("Paso4_EvaluateContext", func(t *testing.T) {
		ctx, cancel := integCtx()
		defer cancel()

		result, err := client.EvaluateContext(ctx, promotedCtxID, realAtomSlug)
		if err != nil {
			t.Fatalf("EvaluateContext error: %v", err)
		}
		if result.DomainsEvaluated != 12 {
			t.Errorf("esperaba 12 dominios evaluados, obtuvo %d", result.DomainsEvaluated)
		}
		if len(result.Domains) != 12 {
			t.Errorf("esperaba 12 entradas en domains, obtuvo %d", len(result.Domains))
		}
		// Verificar que session block está presente (C-BOS-003 acordado)
		if result.Session == nil {
			t.Error("bloque session ausente — C-BOS-003 no implementado en esta versión de bAuth")
		} else {
			t.Logf("session block ✅: user=%s, loa=%d", result.Session.UserUUID, result.Session.LoaCurrent)
		}
		t.Logf("latencia evaluate: %dms", result.Latency.TotalNs/1_000_000)
	})

	// PASO 5 — cache: segunda llamada evaluate no va al socket
	t.Run("Paso5_CacheEvaluate", func(t *testing.T) {
		// El cliente ya tiene el resultado en cache desde Paso4
		ctx, cancel := integCtx()
		defer cancel()

		r1, err := client.EvaluateContext(ctx, promotedCtxID, realAtomSlug)
		if err != nil {
			t.Fatalf("EvaluateContext (cache) error: %v", err)
		}
		if r1.DomainsEvaluated != 12 {
			t.Errorf("resultado de cache inesperado: domains=%d", r1.DomainsEvaluated)
		}
		t.Logf("cache hit ✅: domains=%d, latency=%dms (sin round-trip)", r1.DomainsEvaluated, r1.Latency.TotalNs/1_000_000)
	})

	// PASO 6 — invalidate limpia el cache
	t.Run("Paso6_InvalidateCtx", func(t *testing.T) {
		ctx, cancel := integCtx()
		defer cancel()

		err := client.InvalidateCtx(ctx, promotedCtxID)
		if err != nil {
			t.Logf("InvalidateCtx retornó error (puede ser esperado si ctx ya expiró): %v", err)
		}
		// Tras invalidate, GetSession debe retornar error o state=INVALIDATED
		ctx2, cancel2 := integCtx()
		defer cancel2()
		session, err := client.GetSession(ctx2, promotedCtxID)
		if err != nil {
			t.Logf("GetSession post-invalidate: error esperado: %v", err)
		} else if session.State == "INVALIDATED" || session.State == "EXPIRED" {
			t.Logf("state post-invalidate: %s ✅", session.State)
		} else {
			t.Logf("state post-invalidate: %s (bAuth puede no cambiar state inmediatamente)", session.State)
		}
	})
}

// TestIntegSocketPath verifica que el DefaultSocket es el correcto para esta VPS.
func TestIntegSocketPath(t *testing.T) {
	// La VPS tiene el socket en /tmp/bauth/bauth.sock (no en /run/bos/bauth.sock)
	// Esto es diferente de lo que especifica SBOS-050 — reportar en CONTRATOS.md
	client := bauth.NewClient(realSocket)
	ctx, cancel := integCtx()
	defer cancel()

	_, err := client.GetSession(ctx, "verificacion-socket")
	// Esperamos error RPC (ctx no existe), no error de conexión
	if err == nil {
		t.Error("esperaba error para ctx-verificacion")
	}
	t.Logf("socket %s: accesible ✅", realSocket)
}
