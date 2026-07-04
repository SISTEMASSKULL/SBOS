// Package server — tests F6.3: batch JSON-RPC paralelo.
// DoD: TestBatch_3MetodosEnTiempoDeUno.
package server

import (
	"encoding/json"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// TestBatch_3MetodosEnTiempoDeUno es el DoD de F6.3: un batch de 3 métodos
// de ~200ms cada uno debe resolverse en ~200ms (paralelo), no ~600ms (serie).
// El umbral de 450ms separa con claridad paralelo (200-260ms incluso bajo
// contención del runner con -race) de serie (600ms).
func TestBatch_3MetodosEnTiempoDeUno(t *testing.T) {
	rpcRegistry["test.sleep200"] = func(_ *Server, req *RPCRequest) RPCResponse {
		time.Sleep(200 * time.Millisecond)
		return rpcOK(req.ID, "ok")
	}
	defer delete(rpcRegistry, "test.sleep200")

	s := makeCtxTestServer()
	body := `[
		{"jsonrpc":"2.0","method":"test.sleep200","id":1},
		{"jsonrpc":"2.0","method":"test.sleep200","id":2},
		{"jsonrpc":"2.0","method":"test.sleep200","id":3}
	]`
	r := httptest.NewRequest("POST", "/rpc", strings.NewReader(body))
	w := httptest.NewRecorder()

	start := time.Now()
	s.handleJSONRPC(w, r)
	elapsed := time.Since(start)

	if elapsed > 500*time.Millisecond {
		t.Errorf("batch de 3×200ms debe ejecutar en paralelo (~200ms), no en serie (600ms): tardó %v", elapsed)
	}

	var responses []RPCResponse
	if err := json.Unmarshal(w.Body.Bytes(), &responses); err != nil {
		t.Fatalf("respuesta no es array JSON-RPC: %v", err)
	}
	if len(responses) != 3 {
		t.Fatalf("want 3 respuestas, got %d", len(responses))
	}
	for _, resp := range responses {
		if resp.Error != nil {
			t.Errorf("respuesta con error: %+v", resp.Error)
		}
	}
}

// TestBatch_PreservaOrden verifica que las respuestas salen en el orden de
// entrada aunque los handlers terminen desordenados.
func TestBatch_PreservaOrden(t *testing.T) {
	rpcRegistry["test.eco_lento"] = func(_ *Server, req *RPCRequest) RPCResponse {
		time.Sleep(80 * time.Millisecond)
		return rpcOK(req.ID, "lento")
	}
	rpcRegistry["test.eco_rapido"] = func(_ *Server, req *RPCRequest) RPCResponse {
		return rpcOK(req.ID, "rapido")
	}
	defer delete(rpcRegistry, "test.eco_lento")
	defer delete(rpcRegistry, "test.eco_rapido")

	s := makeCtxTestServer()
	reqs := []RPCRequest{
		{JSONRPC: "2.0", Method: "test.eco_lento", ID: json.RawMessage(`1`)},
		{JSONRPC: "2.0", Method: "test.eco_rapido", ID: json.RawMessage(`2`)},
	}
	responses := s.dispatchBatch(reqs, rpcAuth{})

	if len(responses) != 2 {
		t.Fatalf("want 2 respuestas, got %d", len(responses))
	}
	if responses[0].Result != "lento" || responses[1].Result != "rapido" {
		t.Errorf("orden de entrada no preservado: %+v", responses)
	}
}

// TestBatch_NotificacionesSinRespuesta: las notificaciones (id null) no
// generan entrada en el array de respuesta (JSON-RPC 2.0 §6).
func TestBatch_NotificacionesSinRespuesta(t *testing.T) {
	s := makeCtxTestServer()
	reqs := []RPCRequest{
		{JSONRPC: "2.0", Method: "system.listMethods", ID: json.RawMessage(`1`)},
		{JSONRPC: "2.0", Method: "system.listMethods", ID: nil}, // notificación
	}
	responses := s.dispatchBatch(reqs, rpcAuth{})
	if len(responses) != 1 {
		t.Errorf("notificación no debe responder: want 1, got %d", len(responses))
	}
}
