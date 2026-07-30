// Package server — tests F11: JSON-RPC y WebSocket para métodos del Ficha Engine v2.
// Cubre: bos.ficha.pause, resume, rescan, plan, diff, validate, logs + ws ficha_log_tail.
package server

import (
	"fmt"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"bos/internal/domain"
	"bos/internal/plugin"
	"bos/internal/state"
)

// mockLogReader implementa domain.LogPort con entradas predefinidas.
type mockLogReader struct {
	entries []domain.LogEntry
	err     error
}

func (m *mockLogReader) ReadLog(_ string, _ int32) ([]domain.LogEntry, error) {
	return m.entries, m.err
}
func (m *mockLogReader) FollowLog(_ string) (<-chan domain.LogEntry, error) {
	ch := make(chan domain.LogEntry)
	close(ch)
	return ch, m.err
}

// makeF11Server arma un servidor con estado realista para pruebas F11:
// redis=INSTALADA, vault=PAUSADA, dos fichas en el catálogo.
func makeF11Server() *Server {
	st := queryStateStub{fichas: map[string]*state.Ficha{
		"redis": fichaOK("redis", "8.6.2"),
		"vault": {Name: "vault", Version: "2.0.1", State: state.StatePausada, HealthStatus: "OK"},
	}}
	cat := stubCatalog{fichas: map[string]*plugin.FichaManifest{
		"redis": {ID: "redis", Version: "8.6.2", AutoInstall: true},
		"vault": {ID: "vault", Version: "2.0.1"},
	}}
	s := makeCtxTestServer()
	s.stateMgr = st
	s.fichaSvc = domain.NewFichaService(stubInstaller{success: true}, st, cat)
	return s
}

// ── bos.ficha.pause ───────────────────────────────────────────────

func TestRPCFichaPause_OK(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaPause(buildRPC("bos.ficha.pause", map[string]string{"ficha_id": "redis"}))
	if resp.Error != nil {
		t.Fatalf("pause redis: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	if out["ficha_id"] != "redis" {
		t.Errorf("ficha_id: %v", out["ficha_id"])
	}
	if out["success"] != true {
		t.Errorf("success debe ser true: %+v", out)
	}
}

func TestRPCFichaPause_FichaInexistente(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaPause(buildRPC("bos.ficha.pause", map[string]string{"ficha_id": "nada"}))
	if resp.Error == nil {
		t.Fatal("ficha inexistente debe retornar error")
	}
	if resp.Error.Code != ErrFichaNotFound {
		t.Errorf("code: want %d (FichaNotFound), got %d", ErrFichaNotFound, resp.Error.Code)
	}
}

func TestRPCFichaPause_SinFichaID(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaPause(buildRPC("bos.ficha.pause", map[string]string{}))
	if resp.Error == nil || resp.Error.Code != ErrInvalidParams {
		t.Errorf("sin ficha_id: want InvalidParams, got %+v", resp.Error)
	}
}

// ── bos.ficha.resume ──────────────────────────────────────────────

func TestRPCFichaResume_OK(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaResume(buildRPC("bos.ficha.resume", map[string]string{"ficha_id": "vault"}))
	if resp.Error != nil {
		t.Fatalf("resume vault: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	if out["ficha_id"] != "vault" {
		t.Errorf("ficha_id: %v", out["ficha_id"])
	}
	if out["success"] != true {
		t.Errorf("success debe ser true: %+v", out)
	}
}

func TestRPCFichaResume_FichaInexistente(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaResume(buildRPC("bos.ficha.resume", map[string]string{"ficha_id": "fantasma"}))
	if resp.Error == nil || resp.Error.Code != ErrFichaNotFound {
		t.Errorf("ficha inexistente: want FichaNotFound, got %+v", resp.Error)
	}
}

func TestRPCFichaResume_SinFichaID(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaResume(buildRPC("bos.ficha.resume", map[string]string{}))
	if resp.Error == nil || resp.Error.Code != ErrInvalidParams {
		t.Errorf("sin ficha_id: want InvalidParams, got %+v", resp.Error)
	}
}

// ── bos.ficha.rescan ──────────────────────────────────────────────

func TestRPCFichaRescan_OK(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaRescan(buildRPC("bos.ficha.rescan", nil))
	if resp.Error != nil {
		t.Fatalf("rescan: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	if _, ok := out["total"]; !ok {
		t.Errorf("rescan debe retornar total: %+v", out)
	}
	if _, ok := out["discovered"]; !ok {
		t.Errorf("rescan debe retornar discovered: %+v", out)
	}
}

// ── bos.ficha.plan ────────────────────────────────────────────────

func TestRPCFichaPlan_CatalogoConFichas(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaPlan(buildRPC("bos.ficha.plan", nil))
	if resp.Error != nil {
		t.Fatalf("plan: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	total, ok := out["total"]
	if !ok {
		t.Fatal("plan debe retornar total")
	}
	if total.(int) != 2 {
		t.Errorf("total: want 2, got %v", total)
	}
	if hasCycles, ok := out["has_cycles"]; ok && hasCycles.(bool) {
		t.Error("sin dependencias circulares: has_cycles debe ser false")
	}
}

func TestRPCFichaPlan_CatalogoVacio(t *testing.T) {
	s := makeCtxTestServer()
	s.stateMgr = queryStateStub{fichas: map[string]*state.Ficha{}}
	s.fichaSvc = domain.NewFichaService(stubInstaller{success: true},
		queryStateStub{fichas: nil}, stubCatalog{})

	resp := s.rpcFichaPlan(buildRPC("bos.ficha.plan", nil))
	if resp.Error != nil {
		t.Fatalf("plan vacío: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	if out["total"].(int) != 0 {
		t.Errorf("catálogo vacío → total=0, got %v", out["total"])
	}
}

// ── bos.ficha.diff ────────────────────────────────────────────────

func TestRPCFichaDiff_Individual(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaDiff(buildRPC("bos.ficha.diff", map[string]string{"ficha_id": "redis"}))
	if resp.Error != nil {
		t.Fatalf("diff individual: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	if out["ficha_id"] != "redis" {
		t.Errorf("ficha_id: %v", out["ficha_id"])
	}
	if _, ok := out["has_drift"]; !ok {
		t.Errorf("diff debe retornar has_drift: %+v", out)
	}
}

func TestRPCFichaDiff_Resumen(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaDiff(buildRPC("bos.ficha.diff", map[string]string{}))
	if resp.Error != nil {
		t.Fatalf("diff resumen: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	if _, ok := out["total_fichas"]; !ok {
		t.Errorf("resumen debe retornar total_fichas: %+v", out)
	}
}

func TestRPCFichaDiff_FichaInexistente(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaDiff(buildRPC("bos.ficha.diff", map[string]string{"ficha_id": "nada"}))
	if resp.Error == nil || resp.Error.Code != ErrFichaNotFound {
		t.Errorf("ficha inexistente: want FichaNotFound, got %+v", resp.Error)
	}
}

// ── bos.ficha.validate ────────────────────────────────────────────

func TestRPCFichaValidate_Individual(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaValidate(buildRPC("bos.ficha.validate", map[string]string{"ficha_id": "redis"}))
	if resp.Error != nil {
		t.Fatalf("validate individual: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	if out["total_fichas"].(int) != 1 {
		t.Errorf("total_fichas: want 1, got %v", out["total_fichas"])
	}
}

func TestRPCFichaValidate_Todas(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaValidate(buildRPC("bos.ficha.validate", map[string]string{}))
	if resp.Error != nil {
		t.Fatalf("validate todas: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	if out["total_fichas"].(int) != 2 {
		t.Errorf("total_fichas: want 2 (redis+vault), got %v", out["total_fichas"])
	}
}

func TestRPCFichaValidate_FichaInexistente(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaValidate(buildRPC("bos.ficha.validate", map[string]string{"ficha_id": "nada"}))
	if resp.Error == nil || resp.Error.Code != ErrFichaNotFound {
		t.Errorf("ficha inexistente: want FichaNotFound, got %+v", resp.Error)
	}
}

// ── bos.ficha.logs ────────────────────────────────────────────────

func TestRPCFichaLogs_OK(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaLogs(buildRPC("bos.ficha.logs",
		map[string]interface{}{"ficha_id": "redis", "tail_lines": float64(20)}))
	if resp.Error != nil {
		t.Fatalf("logs: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	if out["ficha_id"] != "redis" {
		t.Errorf("ficha_id: %v", out["ficha_id"])
	}
}

func TestRPCFichaLogs_SinFichaID(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaLogs(buildRPC("bos.ficha.logs", map[string]interface{}{}))
	if resp.Error == nil || resp.Error.Code != ErrInvalidParams {
		t.Errorf("sin ficha_id: want InvalidParams, got %+v", resp.Error)
	}
}

func TestRPCFichaLogs_DefaultTailLines(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaLogs(buildRPC("bos.ficha.logs", map[string]interface{}{"ficha_id": "redis"}))
	if resp.Error != nil {
		t.Fatalf("logs sin tail_lines: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	if out["tail_lines"] == float64(0) {
		t.Error("tail_lines default no debe ser 0")
	}
}

// ── bos.ficha.scale (F9) ─────────────────────────────────────────

func TestRPCFichaScale_SinK8sOp(t *testing.T) {
	s := makeF11Server() // k8sOp=nil

	resp := s.rpcFichaScale(buildRPC("bos.ficha.scale",
		map[string]interface{}{"ficha_id": "redis", "replicas": float64(3)}))
	if resp.Error == nil {
		t.Fatal("scale sin k8sOp debe retornar error")
	}
	if resp.Error.Code != ErrInternal {
		t.Errorf("scale sin k8sOp: want ErrInternal, got %d", resp.Error.Code)
	}
}

func TestRPCFichaScale_SinFichaID(t *testing.T) {
	s := makeF11Server()

	resp := s.rpcFichaScale(buildRPC("bos.ficha.scale", map[string]interface{}{"replicas": float64(2)}))
	if resp.Error == nil || resp.Error.Code != ErrInvalidParams {
		t.Errorf("sin ficha_id: want InvalidParams, got %+v", resp.Error)
	}
}

func TestRPCFichaScale_FichaInexistente(t *testing.T) {
	s, stub := makeK8sServer()
	s.stateMgr = queryStateStub{fichas: map[string]*state.Ficha{}}
	s.plugins = stubCatalog{}
	s.fichaSvc = domain.NewFichaService(stubInstaller{success: true}, s.stateMgr.(StateManager), s.plugins)
	_ = stub

	resp := s.rpcFichaScale(buildRPC("bos.ficha.scale",
		map[string]interface{}{"ficha_id": "nada", "replicas": float64(2)}))
	if resp.Error == nil || resp.Error.Code != ErrFichaNotFound {
		t.Errorf("ficha inexistente: want FichaNotFound, got %+v", resp.Error)
	}
}

func TestRPCFichaScale_OK(t *testing.T) {
	// Preparar directorio de ficha con manifest.yml + yaml_engine.yml
	dir := t.TempDir()
	_ = os.WriteFile(filepath.Join(dir, "manifest.yml"), []byte(`
identity:
  id: redis
  server: S01
  version: 8.6.2
workload:
  type: Deployment
  runtime: kubernetes
meta:
  backend: apt
`), 0o644)
	_ = os.WriteFile(filepath.Join(dir, "yaml_engine.yml"), []byte("namespace: sbos-data\n"), 0o644)

	s, stub := makeK8sServer()
	s.plugins = stubCatalog{fichas: map[string]*plugin.FichaManifest{
		"redis": {ID: "redis", Version: "8.6.2", Path: dir},
	}}

	resp := s.rpcFichaScale(buildRPC("bos.ficha.scale",
		map[string]interface{}{"ficha_id": "redis", "replicas": float64(3)}))
	if resp.Error != nil {
		t.Fatalf("scale OK: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	if out["success"] != true {
		t.Errorf("success debe ser true: %+v", out)
	}
	if out["new_replicas"] != int32(3) {
		t.Errorf("new_replicas: want 3, got %v (%T)", out["new_replicas"], out["new_replicas"])
	}
	if out["namespace"] != "sbos-data" {
		t.Errorf("namespace: want sbos-data, got %v", out["namespace"])
	}
	if stub.ultima() == "" {
		t.Error("k8sOp.ScaleDeployment no fue llamado")
	}
}

// ── handleJSONRPC HTTP / Unix Socket ─────────────────────────────

func TestHandleJSONRPC_F11_PauseViaHTTP(t *testing.T) {
	s := makeF11Server()

	w := httptest.NewRecorder()
	s.handleJSONRPC(w, httptest.NewRequest("POST", "/rpc",
		strings.NewReader(`{"jsonrpc":"2.0","method":"bos.ficha.pause","params":{"ficha_id":"redis"},"id":1}`)))

	if !strings.Contains(w.Body.String(), `"success":true`) {
		t.Errorf("pause via HTTP debe responder success:true: %s", w.Body.String())
	}
}

func TestHandleJSONRPC_F11_PlanViaHTTP(t *testing.T) {
	s := makeF11Server()

	w := httptest.NewRecorder()
	s.handleJSONRPC(w, httptest.NewRequest("POST", "/rpc",
		strings.NewReader(`{"jsonrpc":"2.0","method":"bos.ficha.plan","id":2}`)))

	if w.Code != 200 {
		t.Errorf("plan via HTTP: status %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), `"total":2`) {
		t.Errorf("plan via HTTP debe retornar total:2: %s", w.Body.String())
	}
}

func TestHandleJSONRPC_F11_RescanViaHTTP(t *testing.T) {
	s := makeF11Server()

	w := httptest.NewRecorder()
	s.handleJSONRPC(w, httptest.NewRequest("POST", "/rpc",
		strings.NewReader(`{"jsonrpc":"2.0","method":"bos.ficha.rescan","id":3}`)))

	if !strings.Contains(w.Body.String(), `"discovered"`) {
		t.Errorf("rescan via HTTP debe retornar discovered: %s", w.Body.String())
	}
}

// ── WebSocket: ficha_log_tail ─────────────────────────────────────

func TestWSFichaLogTail_SinFicha(t *testing.T) {
	s := makeF11Server()
	c, leer := makeWSClient()

	s.wsHandleFichaLogTail(c, &Request{ID: "r1", Params: map[string]interface{}{}})

	resp := leer(t)
	if resp.OK {
		t.Error("sin ficha: debe rechazarse")
	}
}

func TestWSFichaLogTail_ArchivoInexistente(t *testing.T) {
	s := makeF11Server()
	c, leer := makeWSClient()

	s.wsHandleFichaLogTail(c, &Request{
		ID:     "r2",
		Params: map[string]interface{}{"ficha": "redis"},
	})

	resp := leer(t)
	if !resp.OK {
		t.Errorf("archivo inexistente debe responder OK (vacío): %+v", resp)
	}
}

// ── bos.ficha.logs con logReader inyectado ────────────────────────────

func TestRPCFichaLogs_ConLogReader(t *testing.T) {
	s := makeF11Server()
	ahora := time.Now().UTC().Truncate(time.Second)
	s.SetLogReader(&mockLogReader{entries: []domain.LogEntry{
		{FichaID: "redis", Level: "INFO", Message: "inicio ok", Timestamp: ahora, LineNumber: 1},
		{FichaID: "redis", Level: "WARN", Message: "memoria alta", Timestamp: ahora, LineNumber: 2},
	}})

	resp := s.rpcFichaLogs(buildRPC("bos.ficha.logs",
		map[string]interface{}{"ficha_id": "redis", "tail_lines": float64(10)}))
	if resp.Error != nil {
		t.Fatalf("logs con reader: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	lines, ok := out["lines"].([]map[string]interface{})
	if !ok {
		t.Fatalf("lines debe ser []map[string]interface{}, got %T", out["lines"])
	}
	if len(lines) != 2 {
		t.Fatalf("esperaba 2 líneas, got %d", len(lines))
	}
	if lines[0]["level"] != "INFO" {
		t.Errorf("línea 0 level: want INFO, got %v", lines[0]["level"])
	}
	if lines[1]["message"] != "memoria alta" {
		t.Errorf("línea 1 message: want 'memoria alta', got %v", lines[1]["message"])
	}
}

func TestRPCFichaLogs_LogReaderError(t *testing.T) {
	s := makeF11Server()
	s.SetLogReader(&mockLogReader{err: fmt.Errorf("disco lleno")})

	resp := s.rpcFichaLogs(buildRPC("bos.ficha.logs",
		map[string]interface{}{"ficha_id": "redis"}))
	if resp.Error == nil {
		t.Fatal("error de logReader debe propagarse")
	}
	if resp.Error.Code != ErrInternal {
		t.Errorf("code: want ErrInternal, got %d", resp.Error.Code)
	}
}

func TestRPCFichaLogs_SinLogReader(t *testing.T) {
	s := makeF11Server()
	// sin SetLogReader: retorna slice vacío, sin error

	resp := s.rpcFichaLogs(buildRPC("bos.ficha.logs",
		map[string]interface{}{"ficha_id": "redis"}))
	if resp.Error != nil {
		t.Fatalf("sin logReader: debe ser nil-safe: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	lines, ok := out["lines"].([]map[string]interface{})
	if !ok {
		t.Fatalf("lines debe ser []map[string]interface{}, got %T", out["lines"])
	}
	if len(lines) != 0 {
		t.Errorf("sin logReader: esperaba 0 líneas, got %d", len(lines))
	}
}
