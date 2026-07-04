// Package server — tests F6.2: timeout por categoría de método JSON-RPC.
// DoD: TestTimeout_LecturaExpira5s.
package server

import (
	"testing"
	"time"
)

// TestTimeout_LecturaExpira5s es el DoD de F6.2: la categoría lectura tiene
// plazo 5s y un handler que lo excede recibe -32006. Para no esperar 5s
// reales, el plazo se acorta temporalmente — la clasificación se verifica
// con los valores de producción en TestTimeout_CategoriasCanonicas.
func TestTimeout_LecturaExpira5s(t *testing.T) {
	if got := methodTimeout("bos.state.read"); got != 5*time.Second {
		t.Fatalf("lectura: want 5s, got %v", got)
	}

	// acortar el plazo de lectura para el experimento
	orig := timeoutByCategory[catLectura]
	timeoutByCategory[catLectura] = 50 * time.Millisecond
	defer func() { timeoutByCategory[catLectura] = orig }()

	// handler lento registrado solo para este test — 2s de trabajo contra un
	// plazo de 50ms; el umbral de 1s tolera ruido de scheduler y sigue
	// probando que la respuesta NO esperó al handler.
	rpcRegistry["test.slow_read"] = func(_ *Server, req *RPCRequest) RPCResponse {
		time.Sleep(2 * time.Second)
		return rpcOK(req.ID, "nunca debería llegar a tiempo")
	}
	defer delete(rpcRegistry, "test.slow_read")

	s := makeCtxTestServer()
	start := time.Now()
	resp := s.dispatchRPC(buildRPC("test.slow_read", nil), rpcAuth{})
	elapsed := time.Since(start)

	if resp == nil || resp.Error == nil {
		t.Fatal("handler lento debe retornar error de timeout")
	}
	if resp.Error.Code != ErrTimeout {
		t.Errorf("code: want %d, got %d", ErrTimeout, resp.Error.Code)
	}
	if elapsed >= time.Second {
		t.Errorf("la respuesta debe llegar al expirar el plazo (50ms), no al terminar el handler (2s): %v", elapsed)
	}
}

// TestTimeout_CategoriasCanonicas fija los plazos del plan:
// 5s lectura, 30s escritura, 600s sagas.
func TestTimeout_CategoriasCanonicas(t *testing.T) {
	cases := []struct {
		method string
		want   time.Duration
	}{
		{"bos.state.read", 5 * time.Second},
		{"bos.health.check", 5 * time.Second},
		{"bos.ficha.status", 5 * time.Second},
		{"system.listMethods", 5 * time.Second},
		{"bos.ctx.promote", 30 * time.Second},
		{"bos.ctx.invalidate", 30 * time.Second},
		{"bos.ficha.install", 600 * time.Second},
		{"bos.ficha.repair", 600 * time.Second},
		{"bos.saga.execute", 600 * time.Second},
		{"bos.bootstrap.start", 600 * time.Second},
	}
	for _, c := range cases {
		if got := methodTimeout(c.method); got != c.want {
			t.Errorf("%s: want %v, got %v", c.method, c.want, got)
		}
	}
}

// TestTimeout_HandlerRapidoNoExpira: un handler dentro del plazo responde normal.
func TestTimeout_HandlerRapidoNoExpira(t *testing.T) {
	s := makeCtxTestServer()
	resp := s.dispatchRPC(buildRPC("system.listMethods", nil), rpcAuth{})
	if resp == nil || resp.Error != nil {
		t.Fatalf("handler rápido no debe expirar: %+v", resp)
	}
}
