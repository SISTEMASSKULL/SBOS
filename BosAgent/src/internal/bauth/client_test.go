package bauth_test

import (
	"context"
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"bos/internal/bauth"
)

// mockBAuthServer simula el socket Unix de bAuth para tests locales.
// Responde a los métodos JSON-RPC con datos fijos sin necesitar la VPS.
type mockBAuthServer struct {
	l        net.Listener
	mu       sync.RWMutex
	handlers map[string]func(params json.RawMessage) (any, *mockRPCErr)
}

type mockRPCErr struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type mockRPCReq struct {
	JSONRPC string          `json:"jsonrpc"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params"`
	ID      int64           `json:"id"`
}

type mockRPCResp struct {
	JSONRPC string      `json:"jsonrpc"`
	Result  any         `json:"result,omitempty"`
	Error   *mockRPCErr `json:"error,omitempty"`
	ID      int64       `json:"id"`
}

func newMockBAuthServer(t *testing.T) (*mockBAuthServer, string) {
	t.Helper()
	dir := t.TempDir()
	sockPath := filepath.Join(dir, "bauth.sock")
	l, err := net.Listen("unix", sockPath)
	if err != nil {
		t.Fatalf("mock: no se pudo abrir socket: %v", err)
	}
	s := &mockBAuthServer{
		l:        l,
		handlers: make(map[string]func(json.RawMessage) (any, *mockRPCErr)),
	}
	go s.serve()
	t.Cleanup(func() {
		l.Close()
		os.Remove(sockPath)
	})
	return s, sockPath
}

func (s *mockBAuthServer) handle(method string, fn func(json.RawMessage) (any, *mockRPCErr)) {
	s.mu.Lock()
	s.handlers[method] = fn
	s.mu.Unlock()
}

func (s *mockBAuthServer) serve() {
	for {
		conn, err := s.l.Accept()
		if err != nil {
			return
		}
		go s.handleConn(conn)
	}
}

func (s *mockBAuthServer) handleConn(conn net.Conn) {
	defer conn.Close()
	dec := json.NewDecoder(conn)
	enc := json.NewEncoder(conn)
	for {
		var req mockRPCReq
		if err := dec.Decode(&req); err != nil {
			return
		}
		s.mu.RLock()
		fn, ok := s.handlers[req.Method]
		s.mu.RUnlock()
		var resp mockRPCResp
		resp.JSONRPC = "2.0"
		resp.ID = req.ID
		if !ok {
			resp.Error = &mockRPCErr{Code: -32601, Message: "método no encontrado: " + req.Method}
		} else {
			result, rpcErr := fn(req.Params)
			if rpcErr != nil {
				resp.Error = rpcErr
			} else {
				resp.Result = result
			}
		}
		if err := enc.Encode(resp); err != nil {
			return
		}
	}
}

// ── Tests ──────────────────────────────────────────────────────────────────

func TestCreateCtx(t *testing.T) {
	srv, sockPath := newMockBAuthServer(t)
	srv.handle("bauth.ctx.create", func(params json.RawMessage) (any, *mockRPCErr) {
		var p bauth.CreateCtxRequest
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, &mockRPCErr{Code: -32600, Message: err.Error()}
		}
		if p.TenantID == "" {
			return nil, &mockRPCErr{Code: -32602, Message: "tenant_id requerido"}
		}
		return bauth.CreateCtxResponse{
			Created:     true,
			CtxID:       "ctx-4a2f9b1c",
			State:       "pending",
			Traceparent: "00-aabbccddeeff00112233445566778899-0011223344556677-01",
		}, nil
	})

	client := bauth.NewClient(sockPath)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	resp, err := client.CreateCtx(ctx, &bauth.CreateCtxRequest{
		TenantID:       "019f01e8-0000-7000-9000-000000000001",
		EmpresaID:      "019f01e8-0000-7000-a000-000000000001",
		SucursalID:     "019f01e8-0000-7000-b000-000000000001",
		PosLogico:      "CAJA-04",
		DeviceID:       "device-abc123",
		DeviceHostname: "pos-lapaz-04.skull.local",
		DeviceIP:       "192.168.1.104",
	})
	if err != nil {
		t.Fatalf("CreateCtx error: %v", err)
	}
	if !resp.Created {
		t.Error("CreateCtx: esperaba created=true")
	}
	if resp.CtxID != "ctx-4a2f9b1c" {
		t.Errorf("CreateCtx: ctx_id inesperado %q", resp.CtxID)
	}
	if resp.State != "pending" {
		t.Errorf("CreateCtx: state inesperado %q", resp.State)
	}
}

func TestPromoteCtx(t *testing.T) {
	srv, sockPath := newMockBAuthServer(t)
	srv.handle("bauth.ctx.promote", func(params json.RawMessage) (any, *mockRPCErr) {
		var p bauth.PromoteCtxRequest
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, &mockRPCErr{Code: -32600, Message: err.Error()}
		}
		if p.CtxID == "" || p.UserID == "" {
			return nil, &mockRPCErr{Code: -32602, Message: "ctx_id y user_id requeridos"}
		}
		return bauth.PromoteCtxResponse{
			Promoted:    true,
			CtxID:       "019f01e8-0000-7000-9000-000000000001:019f01e8-0000-7000-a000-000000000001:019f01e8-0000-7000-b000-000000000001:CAJA-04:" + p.UserID + ":00-aabb-01",
			TenantID:    "019f01e8-0000-7000-9000-000000000001",
			EmpresaID:   "019f01e8-0000-7000-a000-000000000001",
			SucursalID:  "019f01e8-0000-7000-b000-000000000001",
			PosLogico:   "CAJA-04",
			BitmaskHex:  "dGVzdC1iaXRtYXNr",
			BitmaskLen:  968,
			LoACurrent:  2,
			State:       "Active",
			Traceparent: "00-aabb-01",
		}, nil
	})

	client := bauth.NewClient(sockPath)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	resp, err := client.PromoteCtx(ctx, &bauth.PromoteCtxRequest{
		CtxID:      "ctx-4a2f9b1c",
		UserID:     "019f01e8-0000-7000-c000-000000000001",
		SessionKC:  "kc-session-xyz",
		LoACurrent: 2,
	})
	if err != nil {
		t.Fatalf("PromoteCtx error: %v", err)
	}
	if !resp.Promoted {
		t.Error("PromoteCtx: esperaba promoted=true")
	}
	if resp.BitmaskLen != 968 {
		t.Errorf("PromoteCtx: bitmask_len esperado 968, obtenido %d", resp.BitmaskLen)
	}
	if resp.EmpresaID == resp.TenantID {
		t.Error("PromoteCtx: empresa_id no debe ser igual a tenant_id (bug B-BAUTH-001 corregido)")
	}
	if resp.SucursalID == resp.TenantID {
		t.Error("PromoteCtx: sucursal_id no debe ser igual a tenant_id (bug B-BAUTH-001 corregido)")
	}
}

func TestGetSession(t *testing.T) {
	now := time.Now().UTC()
	srv, sockPath := newMockBAuthServer(t)
	srv.handle("bauth.ctx.get_session", func(params json.RawMessage) (any, *mockRPCErr) {
		var p map[string]string
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, &mockRPCErr{Code: -32600, Message: err.Error()}
		}
		ctxID := p["ctx_id"]
		if ctxID == "" {
			return nil, &mockRPCErr{Code: -32602, Message: "ctx_id requerido"}
		}
		return bauth.SessionData{
			CtxID:      ctxID,
			TenantID:   "019f01e8-0000-7000-9000-000000000001",
			EmpresaID:  "019f01e8-0000-7000-a000-000000000001",
			SucursalID: "019f01e8-0000-7000-b000-000000000001",
			PosLogico:  "CAJA-04",
			UserUUID:   "019f01e8-0000-7000-c000-000000000001",
			BitmaskHex: "dGVzdC1iaXRtYXNr",
			LoaCurrent: 2,
			State:      "ACTIVE",
			CreatedAt:  now,
			ExpiresAt:  now.Add(12 * time.Hour),
		}, nil
	})

	client := bauth.NewClient(sockPath)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	session, err := client.GetSession(ctx, "tenant:empresa:sucursal:pos:user:traceparent")
	if err != nil {
		t.Fatalf("GetSession error: %v", err)
	}
	if !session.IsActive() {
		t.Error("GetSession: sesión debe estar activa")
	}
	if session.LoaCurrent != 2 {
		t.Errorf("GetSession: loa esperado 2, obtenido %d", session.LoaCurrent)
	}
}

func TestEvaluateContextWithCache(t *testing.T) {
	callCount := 0
	srv, sockPath := newMockBAuthServer(t)
	srv.handle("bauth.context.evaluate", func(params json.RawMessage) (any, *mockRPCErr) {
		callCount++
		return bauth.ContextEvaluateResult{
			CtxID:            "test:ctx:id",
			AtomSlug:         "sistema.sesion.activa",
			DomainsEvaluated: 1,
			Domains: []bauth.DomainResult{
				{Domain: 1, Result: 1, Approved: true, LatencyNs: 450},
			},
		}, nil
	})

	client := bauth.NewClient(sockPath)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	ctxID := "test:ctx:id"

	// Primera llamada — debe ir al socket.
	r1, err := client.EvaluateContext(ctx, ctxID, "sistema.sesion.activa")
	if err != nil {
		t.Fatalf("EvaluateContext primera llamada error: %v", err)
	}
	if !r1.Allowed() {
		t.Error("EvaluateContext: esperaba Allowed=true")
	}
	if callCount != 1 {
		t.Errorf("EvaluateContext: esperaba 1 llamada al socket, tuvo %d", callCount)
	}

	// Segunda llamada — debe usar cache.
	r2, err := client.EvaluateContext(ctx, ctxID, "sistema.sesion.activa")
	if err != nil {
		t.Fatalf("EvaluateContext segunda llamada error: %v", err)
	}
	if r2.CtxID != r1.CtxID {
		t.Error("EvaluateContext: cache retornó resultado distinto")
	}
	if callCount != 1 {
		t.Errorf("EvaluateContext: cache debía evitar la segunda llamada, tuvo %d llamadas", callCount)
	}
}

func TestEvaluateContextCacheInvalidation(t *testing.T) {
	callCount := 0
	srv, sockPath := newMockBAuthServer(t)
	srv.handle("bauth.context.evaluate", func(params json.RawMessage) (any, *mockRPCErr) {
		callCount++
		return bauth.ContextEvaluateResult{
			CtxID:            "test:ctx",
			AtomSlug:         "sistema.sesion.activa",
			DomainsEvaluated: 1,
			Domains:          []bauth.DomainResult{{Domain: 1, Result: 1, Approved: true}},
		}, nil
	})
	srv.handle("bauth.ctx.invalidate", func(params json.RawMessage) (any, *mockRPCErr) {
		return map[string]bool{"ok": true}, nil
	})

	client := bauth.NewClient(sockPath)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	// Poblar cache.
	if _, err := client.EvaluateContext(ctx, "test:ctx", "sistema.sesion.activa"); err != nil {
		t.Fatalf("EvaluateContext: %v", err)
	}
	if callCount != 1 {
		t.Fatalf("esperaba 1 llamada, tuvo %d", callCount)
	}

	// Invalidar contexto — borra el cache.
	if err := client.InvalidateCtx(ctx, "test:ctx"); err != nil {
		t.Fatalf("InvalidateCtx: %v", err)
	}

	// Siguiente llamada debe ir al socket de nuevo.
	if _, err := client.EvaluateContext(ctx, "test:ctx", "sistema.sesion.activa"); err != nil {
		t.Fatalf("EvaluateContext post-invalidate: %v", err)
	}
	if callCount != 2 {
		t.Errorf("tras InvalidateCtx esperaba 2 llamadas al socket, tuvo %d", callCount)
	}
}

func TestContextTimeout(t *testing.T) {
	// Socket que no responde — verifica que el contexto de cancelación funciona.
	_, sockPath := newMockBAuthServer(t) // sin handlers → conexión acepta pero no responde
	client := bauth.NewClient(sockPath)

	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()

	_, err := client.GetSession(ctx, "ctx:timeout:test")
	if err == nil {
		t.Fatal("GetSession debía fallar por timeout")
	}
}

func TestSocketNotFound(t *testing.T) {
	client := bauth.NewClient("/tmp/socket-inexistente-sbos.sock")
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	_, err := client.GetSession(ctx, "ctx:x")
	if err == nil {
		t.Fatal("GetSession debía fallar con socket inexistente")
	}
}
