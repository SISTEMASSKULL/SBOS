// Package server — tests T8.6 (F8): handlers WebSocket de bootstrap
// (Vía 1 — ADR-019). El Client se fabrica con canal buffered; sendResponse
// usa select/default y no requiere conexión real.
package server

import (
	"encoding/json"
	"testing"
)

// makeWSClient fabrica un Client de prueba y un lector de la Response.
func makeWSClient() (*Client, func(t *testing.T) Response) {
	c := &Client{send: make(chan []byte, 8), User: "tester"}
	leer := func(t *testing.T) Response {
		t.Helper()
		select {
		case raw := <-c.send:
			var resp Response
			if err := json.Unmarshal(raw, &resp); err != nil {
				t.Fatalf("respuesta WS inválida: %v", err)
			}
			return resp
		default:
			t.Fatal("el handler no envió respuesta al cliente")
			return Response{}
		}
	}
	return c, leer
}

// TestWSBootstrapStatus: agrega conteos y progreso desde el estado.
func TestWSBootstrapStatus(t *testing.T) {
	s := makeRPCServer(true)
	c, leer := makeWSClient()

	s.wsHandleBootstrapStatus(c, &Request{ID: "r1", Action: "bootstrap_status"})

	resp := leer(t)
	if !resp.OK {
		t.Fatalf("status debe responder OK: %+v", resp)
	}
	data := resp.Data.(map[string]interface{})
	if data["total_fichas"] != float64(2) {
		t.Errorf("total_fichas: want 2, got %v", data["total_fichas"])
	}
	if data["alert_fichas"] != float64(1) {
		t.Errorf("alert_fichas (postgresql DEGRADADA): want 1, got %v", data["alert_fichas"])
	}
}

// TestWSBootstrapVerify: ejecuta los criterios C-01..C-08 y responde.
func TestWSBootstrapVerify(t *testing.T) {
	s := makeRPCServer(true)
	c, leer := makeWSClient()

	s.wsHandleBootstrapVerify(c, &Request{ID: "r2", Action: "bootstrap_verify"})

	resp := leer(t)
	if resp.ID != "r2" {
		t.Errorf("correlation ID perdido: %+v", resp)
	}
	// en host de test los criterios fallan, pero la respuesta llega formada
	if resp.Data == nil {
		t.Error("verify debe adjuntar el detalle de criterios")
	}
}

// TestWSBootstrapResume: reporta el progreso para reanudar.
func TestWSBootstrapResume(t *testing.T) {
	s := makeRPCServer(true)
	c, leer := makeWSClient()

	s.wsHandleBootstrapResume(c, &Request{ID: "r3", Action: "bootstrap_resume"})

	resp := leer(t)
	if !resp.OK {
		t.Fatalf("resume: %+v", resp)
	}
	data := resp.Data.(map[string]interface{})
	if data["fichas_total"] != float64(2) || data["fichas_completadas"] != float64(1) {
		t.Errorf("progreso resume: %+v", data)
	}
}

// TestWSBootstrapReset_RequiereConfirmacion: la operación destructiva exige
// confirmed:true (HITL); confirmada, reinicia solo fichas en error/transitorio.
func TestWSBootstrapReset_RequiereConfirmacion(t *testing.T) {
	s := makeRPCServer(true)
	c, leer := makeWSClient()

	// sin confirmación → rechazo
	s.wsHandleBootstrapReset(c, &Request{ID: "r4", Params: map[string]interface{}{}})
	if resp := leer(t); resp.OK {
		t.Error("reset sin confirmed:true debe rechazarse")
	}

	// confirmado → procede (la DEGRADADA del stub es elegible para reset)
	s.wsHandleBootstrapReset(c, &Request{ID: "r5",
		Params: map[string]interface{}{"confirmed": true}})
	resp := leer(t)
	if !resp.OK {
		t.Fatalf("reset confirmado: %+v", resp)
	}
}

// TestWSBootstrapStart_SinInstaller: en config-pending el start se rechaza
// con mensaje claro.
func TestWSBootstrapStart_SinInstaller(t *testing.T) {
	s := makeRPCServer(true) // installer nil en el stub server
	c, leer := makeWSClient()

	s.wsHandleBootstrapStart(c, &Request{ID: "r6", Params: map[string]interface{}{"mode": "unattended"}})

	resp := leer(t)
	if resp.OK {
		t.Error("sin installer el start debe rechazarse")
	}
}

// TestStringParamYConteo: helpers puros del módulo bootstrap WS.
func TestStringParamYConteo(t *testing.T) {
	v, ok := stringParam(map[string]interface{}{"k": "valor"}, "k")
	if !ok || v != "valor" {
		t.Errorf("stringParam: %q %v", v, ok)
	}
	if _, ok := stringParam(nil, "k"); ok {
		t.Error("params nil: ok debe ser false")
	}
	if _, ok := stringParam(map[string]interface{}{"k": 7}, "k"); ok {
		t.Error("tipo no-string: ok debe ser false")
	}
}
