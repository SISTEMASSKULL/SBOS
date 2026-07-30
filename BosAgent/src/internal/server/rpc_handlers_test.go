// Package server — tests T8.5/T8.6 (F8): handlers JSON-RPC de ficha,
// saga, bootstrap, health y ctx legacy con FichaService real sobre stubs.
package server

import (
	"errors"
	"net/http/httptest"
	"strings"
	"testing"

	"bos/internal/domain"
	"bos/internal/installer"
	"bos/internal/plugin"
	"bos/internal/state"
)

// stubInstaller implementa domain.InstallerPort con resultados configurables.
type stubInstaller struct {
	success bool
	err     error
}

func (s stubInstaller) result(cmd, id string) (*installer.SagaResult, error) {
	if s.err != nil {
		return nil, s.err
	}
	return &installer.SagaResult{
		Command: cmd, FichaID: id, Success: s.success,
		Steps: []installer.Step{{Name: "paso1"}}, ExitCode: 0,
	}, nil
}
func (s stubInstaller) Install(id, v string) (*installer.SagaResult, error) {
	return s.result("install", id)
}
func (s stubInstaller) Update(id, v string) (*installer.SagaResult, error) {
	return s.result("update", id)
}
func (s stubInstaller) Repair(id string) (*installer.SagaResult, error) {
	return s.result("repair", id)
}
func (s stubInstaller) Remove(id string) (*installer.SagaResult, error) {
	return s.result("remove", id)
}
func (s stubInstaller) Probe(id string) (*installer.SagaResult, error) {
	return s.result("probe", id)
}

// stubCatalog implementa domain.CatalogPort.
type stubCatalog struct {
	fichas map[string]*plugin.FichaManifest
}

func (c stubCatalog) List() []*plugin.FichaManifest {
	out := make([]*plugin.FichaManifest, 0, len(c.fichas))
	for _, f := range c.fichas {
		out = append(out, f)
	}
	return out
}
func (c stubCatalog) Get(id string) (*plugin.FichaManifest, bool) {
	f, ok := c.fichas[id]
	return f, ok
}
func (c stubCatalog) Count() int  { return len(c.fichas) }
func (c stubCatalog) Reload() int { return len(c.fichas) }

// makeRPCServer arma un Server con FichaService/BootstrapService reales
// sobre stubs — sin daemon, sin bash, sin K8s.
func makeRPCServer(installOK bool) *Server {
	st := queryStateStub{fichas: map[string]*state.Ficha{
		"redis":      fichaOK("redis", "8.6.2"),
		"postgresql": {Name: "postgresql", Version: "18.4", State: state.StateDegradada, HealthStatus: "FAIL"},
	}}
	cat := stubCatalog{fichas: map[string]*plugin.FichaManifest{
		"redis": {ID: "redis", Version: "8.6.2", AutoInstall: true},
	}}
	s := makeCtxTestServer()
	s.stateMgr = st
	s.fichaSvc = domain.NewFichaService(stubInstaller{success: installOK}, st, cat)
	s.bootstrapSvc = domain.NewBootstrapService(st)
	// ctxSvc eliminado en M-14 — Create/Validate ahora en bosCtxSvc
	return s
}

// TestRPCFicha_CicloCompleto: install/update/repair/remove/probe responden
// con el contrato documentado cuando la saga tiene éxito.
func TestRPCFicha_CicloCompleto(t *testing.T) {
	s := makeRPCServer(true)
	params := map[string]string{"ficha_id": "redis", "version": "8.6.2"}

	for metodo, handler := range map[string]func(*RPCRequest) RPCResponse{
		"bos.ficha.install": s.rpcFichaInstall,
		"bos.ficha.update":  s.rpcFichaUpdate,
		"bos.ficha.repair":  s.rpcFichaRepair,
		"bos.ficha.remove":  s.rpcFichaRemove,
		"bos.ficha.probe":   s.rpcFichaProbe,
	} {
		resp := handler(buildRPC(metodo, params))
		if resp.Error != nil {
			t.Errorf("%s: %v", metodo, resp.Error)
			continue
		}
		out := resp.Result.(map[string]interface{})
		if out["ficha_id"] != "redis" {
			t.Errorf("%s: ficha_id perdido: %+v", metodo, out)
		}
	}

	// sin ficha_id → InvalidParams en todos
	resp := s.rpcFichaInstall(buildRPC("bos.ficha.install", map[string]string{}))
	if resp.Error == nil || resp.Error.Code != ErrInvalidParams {
		t.Errorf("install sin ficha_id: want InvalidParams, got %+v", resp)
	}
}

// TestRPCFicha_SagaFallida: installer con Success=false → ErrSagaFailed
// con los pasos fallidos en Data.
func TestRPCFicha_SagaFallida(t *testing.T) {
	s := makeRPCServer(false)

	resp := s.rpcFichaInstall(buildRPC("bos.ficha.install",
		map[string]string{"ficha_id": "redis"}))
	if resp.Error == nil {
		t.Fatal("saga fallida debe retornar error")
	}
	if resp.Error.Code != ErrSagaFailed {
		t.Errorf("code: want %d (SagaFailed), got %d", ErrSagaFailed, resp.Error.Code)
	}
}

// TestRPCSagaExecute: el comando se valida y la saga reporta steps.
func TestRPCSagaExecute(t *testing.T) {
	s := makeRPCServer(true)

	resp := s.rpcSagaExecute(buildRPC("bos.saga.execute",
		map[string]string{"ficha_id": "redis", "command": "repair"}))
	if resp.Error != nil {
		t.Fatalf("saga.execute: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	if out["command"] != "repair" || out["success"] != true {
		t.Errorf("contrato saga.execute: %+v", out)
	}

	// comando inválido
	bad := s.rpcSagaExecute(buildRPC("bos.saga.execute",
		map[string]string{"ficha_id": "redis", "command": "destruir"}))
	if bad.Error == nil || bad.Error.Code != ErrInvalidParams {
		t.Errorf("comando inválido: want InvalidParams, got %+v", bad)
	}
}

// TestRPCFichaStatusYList: status individual, status global y list.
func TestRPCFichaStatusYList(t *testing.T) {
	s := makeRPCServer(true)

	uno := s.rpcFichaStatus(buildRPC("bos.ficha.status", map[string]string{"ficha_id": "redis"}))
	if uno.Error != nil {
		t.Fatalf("status individual: %v", uno.Error)
	}

	todas := s.rpcFichaStatus(buildRPC("bos.ficha.status", map[string]string{}))
	if todas.Error != nil {
		t.Fatalf("status global: %v", todas.Error)
	}

	lista := s.rpcFichaList(buildRPC("bos.ficha.list", nil))
	if lista.Error != nil {
		t.Fatalf("ficha.list: %v", lista.Error)
	}
	out := lista.Result.(map[string]interface{})
	if out["total"] != 1 {
		t.Errorf("list total: want 1, got %v", out["total"])
	}

	noExiste := s.rpcFichaStatus(buildRPC("bos.ficha.status", map[string]string{"ficha_id": "nada"}))
	if noExiste.Error == nil || noExiste.Error.Code != ErrFichaNotFound {
		t.Errorf("ficha inexistente: want -32010 FichaNotFound, got %+v", noExiste)
	}
}

// TestRPCHealthCheck: vista global cuenta ok/alerta; individual reporta healthy.
func TestRPCHealthCheck(t *testing.T) {
	s := makeRPCServer(true)

	global := s.rpcHealthCheck(buildRPC("bos.health.check", nil))
	if global.Error != nil {
		t.Fatalf("health global: %v", global.Error)
	}
	out := global.Result.(map[string]interface{})
	if out["fichas_total"] != 2 || out["fichas_ok"] != 1 || out["fichas_alerta"] != 1 {
		t.Errorf("conteo health: %+v", out)
	}
	if out["healthy"] != false {
		t.Error("con una DEGRADADA el sistema no está healthy")
	}

	una := s.rpcHealthCheck(buildRPC("bos.health.check", map[string]string{"ficha_id": "redis"}))
	indiv := una.Result.(map[string]interface{})
	if indiv["healthy"] != true {
		t.Errorf("redis INSTALADA debe ser healthy: %+v", indiv)
	}
}

// TestRPCBootstrapStatusYVerify: el estado agrega conteos del bootstrap y
// verify retorna los criterios C-01..C-08.
func TestRPCBootstrapStatusYVerify(t *testing.T) {
	s := makeRPCServer(true)

	st := s.rpcBootstrapStatus(buildRPC("bos.bootstrap.status", nil))
	if st.Error != nil {
		t.Fatalf("bootstrap.status: %v", st.Error)
	}

	v := s.rpcBootstrapVerify(buildRPC("bos.bootstrap.verify", nil))
	if v.Error != nil {
		t.Fatalf("bootstrap.verify: %v", v.Error)
	}
}

// TestRPCCtxLegacy: bos.ctx.create genera traceparent W3C válido y
// bos.ctx.validate lo acepta; tenant_id es obligatorio.
func TestRPCCtxLegacy(t *testing.T) {
	s := makeRPCServer(true)

	creado := s.rpcCtxCreate(buildRPC("bos.ctx.create", map[string]interface{}{
		"tenant_id": "skull", "empresa_id": "E1", "user_id": "ana",
	}))
	if creado.Error != nil {
		t.Fatalf("ctx.create: %v", creado.Error)
	}
	tp := creado.Result.(map[string]interface{})["traceparent"].(string)
	if len(tp) < 55 || !strings.HasPrefix(tp, "00-") {
		t.Errorf("traceparent W3C inválido: %q", tp)
	}

	valido := s.rpcCtxValidate(buildRPC("bos.ctx.validate", map[string]string{"traceparent": tp}))
	if valido.Error != nil {
		t.Fatalf("ctx.validate: %v", valido.Error)
	}

	sinTenant := s.rpcCtxCreate(buildRPC("bos.ctx.create", map[string]string{}))
	if sinTenant.Error == nil || sinTenant.Error.Code != ErrInvalidParams {
		t.Errorf("create sin tenant: want InvalidParams, got %+v", sinTenant)
	}
}

// TestDomainErrToRPC_Mapeos: cada error de dominio mapea a su código.
func TestDomainErrToRPC_Mapeos(t *testing.T) {
	cases := []struct {
		err  error
		want int
	}{
		{domain.ErrFichaNotFound, ErrFichaNotFound},
		{domain.ErrFichaIDRequired, ErrInvalidParams},
		{domain.ErrCommandInvalid, ErrInvalidParams},
		{domain.ErrBootstrapInProgress, ErrStateConflict},
		{domain.ErrInstallerUnavailable, ErrInternal},
		{errors.New("desconocido"), ErrInternal},
	}
	for _, c := range cases {
		if got := domainErrToRPC(nil, c.err); got.Code != c.want {
			t.Errorf("%v: want %d, got %d", c.err, c.want, got.Code)
		}
	}
}

// TestHandleJSONRPC_HTTP: el endpoint /rpc rechaza GET, JSON inválido y
// jsonrpc ≠ 2.0; responde una llamada simple bien formada.
func TestHandleJSONRPC_HTTP(t *testing.T) {
	s := makeRPCServer(true)

	// método HTTP incorrecto
	w := httptest.NewRecorder()
	s.handleJSONRPC(w, httptest.NewRequest("GET", "/rpc", nil))
	if w.Code != 405 {
		t.Errorf("GET debe dar 405, got %d", w.Code)
	}

	// JSON inválido → -32700
	w = httptest.NewRecorder()
	s.handleJSONRPC(w, httptest.NewRequest("POST", "/rpc", strings.NewReader("{no es json")))
	if !strings.Contains(w.Body.String(), "-32700") {
		t.Errorf("JSON roto debe dar ParseError: %s", w.Body.String())
	}

	// jsonrpc != 2.0 → -32600
	w = httptest.NewRecorder()
	s.handleJSONRPC(w, httptest.NewRequest("POST", "/rpc",
		strings.NewReader(`{"jsonrpc":"1.0","method":"bos.ficha.list","id":1}`)))
	if !strings.Contains(w.Body.String(), "-32600") {
		t.Errorf("jsonrpc 1.0 debe rechazarse: %s", w.Body.String())
	}

	// llamada válida
	w = httptest.NewRecorder()
	s.handleJSONRPC(w, httptest.NewRequest("POST", "/rpc",
		strings.NewReader(`{"jsonrpc":"2.0","method":"bos.ficha.list","id":1}`)))
	if !strings.Contains(w.Body.String(), `"total":1`) {
		t.Errorf("llamada válida debe responder: %s", w.Body.String())
	}

	// batch vacío → -32600
	w = httptest.NewRecorder()
	s.handleJSONRPC(w, httptest.NewRequest("POST", "/rpc", strings.NewReader("[]")))
	if !strings.Contains(w.Body.String(), "-32600") {
		t.Errorf("batch vacío debe rechazarse: %s", w.Body.String())
	}
}
