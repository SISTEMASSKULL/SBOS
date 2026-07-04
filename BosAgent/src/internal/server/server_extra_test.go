// Package server — tests T8.6 (F8): ctx.list/tenant.suspend, bootstrap
// start/resume, guards de servicios opcionales y ciclo del Server.
package server

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

// TestRPCCtxListYTenantSuspend: lista por tenant y suspensión masiva
// (SBOS-049 §5.1 — ISO 27001 A.9.2.6).
func TestRPCCtxListYTenantSuspend(t *testing.T) {
	s := makeCtxTestServer()
	crearSesion(t, s, "skull", "ana")
	crearSesion(t, s, "skull", "luis")

	lista := s.rpcCtxList(buildRPC("bos.ctx.list", map[string]string{"tenant_id": "skull"}))
	if lista.Error != nil {
		t.Fatalf("ctx.list: %v", lista.Error)
	}
	out := lista.Result.(map[string]interface{})
	if out["total"] != 2 {
		t.Errorf("ctx.list total: want 2, got %v", out["total"])
	}

	susp := s.rpcCtxTenantSuspend(buildRPC("bos.ctx.tenant.suspend",
		map[string]string{"tenant_id": "skull"}))
	if susp.Error != nil {
		t.Fatalf("tenant.suspend: %v", susp.Error)
	}
	n := susp.Result.(map[string]interface{})["invalidated"]
	if n != 2 {
		t.Errorf("suspend debe invalidar las 2 sesiones, got %v", n)
	}

	// tras suspender, la lista operativa queda vacía
	lista2 := s.rpcCtxList(buildRPC("bos.ctx.list", map[string]string{"tenant_id": "skull"}))
	if total := lista2.Result.(map[string]interface{})["total"]; total != 0 {
		t.Errorf("tras suspend: want 0 activas, got %v", total)
	}

	// tenant vacío → InvalidParams
	bad := s.rpcCtxTenantSuspend(buildRPC("bos.ctx.tenant.suspend", map[string]string{}))
	if bad.Error == nil {
		t.Error("tenant.suspend sin tenant_id debe fallar")
	}
}

// TestRPCBootstrapStartYResume: start retorna bootstrap_id y totales;
// resume reporta progreso del observer.
func TestRPCBootstrapStartYResume(t *testing.T) {
	s := makeRPCServer(true)

	start := s.rpcBootstrapStart(buildRPC("bos.bootstrap.start", map[string]string{"mode": "unattended"}))
	if start.Error != nil {
		t.Fatalf("bootstrap.start: %v", start.Error)
	}

	resume := s.rpcBootstrapResume(buildRPC("bos.bootstrap.resume", nil))
	if resume.Error != nil {
		t.Fatalf("bootstrap.resume: %v", resume.Error)
	}
	out := resume.Result.(map[string]interface{})
	if out["fichas_total"] != 2 {
		t.Errorf("resume fichas_total: want 2, got %v", out["fichas_total"])
	}
}

// TestRPCServiciosOpcionales_Guards: pg_auxiliar y release sin servicio
// inyectado responden error interno claro, nunca panic.
func TestRPCServiciosOpcionales_Guards(t *testing.T) {
	s := makeCtxTestServer() // pgAuxSvc y releaseMgr nil

	for nombre, handler := range map[string]func(*RPCRequest) RPCResponse{
		"pg_auxiliar_start":   s.rpcPgAuxiliarStart,
		"pg_auxiliar_sync":    s.rpcPgAuxiliarSync,
		"pg_auxiliar_status":  s.rpcPgAuxiliarStatus,
		"pg_auxiliar_cleanup": s.rpcPgAuxiliarCleanup,
		"release_check":       s.rpcReleaseCheck,
		"release_list":        s.rpcReleaseList,
	} {
		resp := handler(buildRPC(nombre, nil))
		if resp.Error == nil || resp.Error.Code != ErrInternal {
			t.Errorf("%s sin servicio: want ErrInternal, got %+v", nombre, resp)
		}
	}
}

// TestNewServer_CicloBasico: el constructor arma los servicios de dominio,
// los broadcasts no bloquean y Shutdown sin listeners es seguro.
func TestNewServer_CicloBasico(t *testing.T) {
	st := queryStateStub{fichas: nil}
	s := NewServer(Config{}, st, stubCatalog{}, nil, nil, nil, nil, makeTestLogger(), nil, nil)

	if s.fichaSvc == nil || s.bootstrapSvc == nil || s.bosCtxSvc == nil {
		t.Fatal("NewServer debe construir los servicios de dominio")
	}

	// broadcasts con hub activo — no deben bloquear ni entrar en pánico
	s.BroadcastStepEvent(EventStepStart, "redis", "instalar", "")
	s.BroadcastFichaLog("redis", "línea de log")

	s.SetReleaseManager(nil)
	s.Shutdown() // sin listeners — no debe entrar en pánico

	// modo config-pending
	cp := NewConfigPendingServer(Config{}, "/tmp/bos.toml", makeTestLogger())
	if !cp.configPending {
		t.Error("NewConfigPendingServer debe marcar configPending")
	}
	cp.Shutdown()
}

// TestWithLogging: el middleware envuelve el handler sin alterar la respuesta.
func TestWithLogging(t *testing.T) {
	s := makeCtxTestServer()
	llamado := false
	inner := s.withLogging(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		llamado = true
	}))

	w := httptest.NewRecorder()
	inner.ServeHTTP(w, httptest.NewRequest("GET", "/x", nil))
	if !llamado {
		t.Error("el middleware debe invocar el handler interno")
	}
}
