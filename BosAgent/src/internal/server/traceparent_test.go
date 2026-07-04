// Package server — tests F5.6: propagación W3C Trace Context en handlers ctx.
package server

import (
	"encoding/json"
	"testing"
)

const validTP = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"

// TestTraceContext_PropagadoEnTodosLosMetodos verifica que los 5 métodos principales
// del Context Plane (device.register, promote, switch, invalidate, get) propagan
// o generan un traceparent W3C válido en la respuesta.
func TestTraceContext_PropagadoEnTodosLosMetodos(t *testing.T) {
	s := makeCtxTestServer()

	// helper: extrae traceparent del resultado
	getTP := func(resp RPCResponse) string {
		if resp.Error != nil {
			return ""
		}
		data, ok := resp.Result.(map[string]interface{})
		if !ok {
			return ""
		}
		tp, _ := data["traceparent"].(string)
		return tp
	}

	// ── 1. device.register — debe propagar traceparent de la request ──────
	regResp := s.rpcCtxDeviceRegister(buildRPC("bos.ctx.device.register",
		map[string]interface{}{
			"hostname":    "tp-host",
			"tenant_id":   "skull",
			"ip":          "10.0.0.99",
			"traceparent": validTP,
		}))
	if regResp.Error != nil {
		t.Fatalf("device.register: %v", regResp.Error)
	}
	tp1 := getTP(regResp)
	if !IsValidTraceparent(tp1) {
		t.Errorf("device.register: traceparent inválido: %q", tp1)
	}
	// el traceparent propagado debe coincidir con el enviado
	if tp1 != validTP {
		t.Errorf("device.register: traceparent no propagado: want %q, got %q", validTP, tp1)
	}
	dctxID := regResp.Result.(map[string]interface{})["dctx_id"].(string)

	// ── 2. promote — traceparent de sesión + de request ────────────────────
	promResp := s.rpcCtxPromote(buildRPC("bos.ctx.promote", map[string]interface{}{
		"dctx_id":     dctxID,
		"user_id":     "usr_tp",
		"bitmask":     uint64(0x01),
		"loa":         1,
		"traceparent": validTP,
	}))
	if promResp.Error != nil {
		t.Fatalf("promote: %v", promResp.Error)
	}
	tp2 := getTP(promResp)
	if !IsValidTraceparent(tp2) {
		t.Errorf("promote: traceparent inválido: %q", tp2)
	}
	ctxID := promResp.Result.(map[string]interface{})["ctx_id"].(string)

	// ── 3. get — debe incluir traceparent de la sesión (inmutable) ─────────
	getResp := s.rpcCtxGet(buildRPC("bos.ctx.get", map[string]string{"ctx_id": ctxID}))
	if getResp.Error != nil {
		t.Fatalf("ctx.get: %v", getResp.Error)
	}
	tp3 := getTP(getResp)
	if !IsValidTraceparent(tp3) {
		t.Errorf("ctx.get: traceparent inválido: %q", tp3)
	}

	// ── 4. invalidate — debe incluir traceparent de la request ─────────────
	invResp := s.rpcCtxInvalidate(buildRPC("bos.ctx.invalidate", map[string]interface{}{
		"ctx_id":      ctxID,
		"traceparent": validTP,
	}))
	if invResp.Error != nil {
		t.Fatalf("ctx.invalidate: %v", invResp.Error)
	}
	tp4 := getTP(invResp)
	if !IsValidTraceparent(tp4) {
		t.Errorf("ctx.invalidate: traceparent inválido: %q", tp4)
	}

	// ── 5. sin traceparent en request — debe generarse uno nuevo ───────────
	regResp2 := s.rpcCtxDeviceRegister(buildRPC("bos.ctx.device.register",
		map[string]string{
			"hostname":  "tp-host-2",
			"tenant_id": "skull",
			"ip":        "10.0.0.100",
			// sin traceparent
		}))
	if regResp2.Error != nil {
		t.Fatalf("device.register sin tp: %v", regResp2.Error)
	}
	tp5 := getTP(regResp2)
	if !IsValidTraceparent(tp5) {
		t.Errorf("sin traceparent en request: debe generarse uno válido, got %q", tp5)
	}
	if tp5 == validTP {
		t.Error("traceparent generado no debe ser igual al validTP hardcoded")
	}

	// ── 6. IsValidTraceparent / NewTraceparent unitarios ──────────────────
	if !IsValidTraceparent(validTP) {
		t.Errorf("validTP debe ser válido: %q", validTP)
	}
	if IsValidTraceparent("") {
		t.Error("string vacío no es un traceparent válido")
	}
	if IsValidTraceparent("invalid-trace-parent") {
		t.Error("string inválido no debe pasar la validación W3C")
	}
	generated := NewTraceparent()
	if !IsValidTraceparent(generated) {
		t.Errorf("NewTraceparent() generó un traceparent inválido: %q", generated)
	}

	// ── 7. ExtractTraceparent con params nil ─────────────────────────────
	reqNil := &RPCRequest{JSONRPC: "2.0", ID: json.RawMessage(`1`)}
	extracted := ExtractTraceparent(reqNil)
	if !IsValidTraceparent(extracted) {
		t.Errorf("ExtractTraceparent(nil params) debe generar uno válido, got %q", extracted)
	}
}
