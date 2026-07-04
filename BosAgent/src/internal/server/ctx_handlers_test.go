// Package server — tests F5.4: handlers JSON-RPC del Context Plane.
// TestRPC_CtxDeviceRegister_RetornaEnMenos2s (SLO C-13)
// TestRPC_CtxPromote_BitMaskPositivo
// TestRPC_CtxInvalidate_YaNoValido
package server

import (
	"encoding/json"
	"io"
	"log/slog"
	"testing"
	"time"

	bosctx "bos/internal/context"
)

func makeTestLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

// toUint64 convierte un valor interface{} a uint64 (uint64 o float64).
func toUint64(v interface{}) uint64 {
	switch x := v.(type) {
	case uint64:
		return x
	case float64:
		return uint64(x)
	case int:
		return uint64(x)
	case int64:
		return uint64(x)
	}
	return 0
}

// makeServer crea un Server mínimo con bosCtxSvc para tests.
func makeCtxTestServer() *Server {
	return &Server{
		bosCtxSvc: bosctx.NewServiceWithMemStore(),
		logger:    makeTestLogger(),
	}
}

// buildRPC construye un RPCRequest válido para los tests.
func buildRPC(method string, params interface{}) *RPCRequest {
	raw, _ := json.Marshal(params)
	return &RPCRequest{
		JSONRPC: "2.0",
		Method:  method,
		Params:  json.RawMessage(raw),
		ID:      json.RawMessage(`1`),
	}
}

// TestRPC_CtxDeviceRegister_RetornaEnMenos2s verifica que el registro de un
// DeviceContext cumpla el SLO C-13: tiempo de respuesta < 2 segundos.
func TestRPC_CtxDeviceRegister_RetornaEnMenos2s(t *testing.T) {
	s := makeCtxTestServer()

	start := time.Now()
	resp := s.rpcCtxDeviceRegister(buildRPC("bos.ctx.device.register", map[string]string{
		"hostname":  "test-host.skull.local",
		"tenant_id": "skull",
		"node_k8s":  "node-01",
		"ip":        "10.0.0.5",
	}))
	elapsed := time.Since(start)

	if resp.Error != nil {
		t.Fatalf("rpcCtxDeviceRegister error: %v", resp.Error)
	}
	if elapsed > 2*time.Second {
		t.Errorf("SLO C-13: tiempo %v excede 2s", elapsed)
	}

	data, ok := resp.Result.(map[string]interface{})
	if !ok {
		t.Fatal("resultado no es map")
	}
	dctxID, _ := data["dctx_id"].(string)
	if dctxID == "" {
		t.Error("dctx_id debe ser no vacío")
	}
	state, _ := data["state"].(string)
	if state != "PENDIENTE" {
		t.Errorf("estado inicial debe ser PENDIENTE, got %s", state)
	}

	// registro con hostname vacío debe fallar
	resp2 := s.rpcCtxDeviceRegister(buildRPC("bos.ctx.device.register", map[string]string{
		"tenant_id": "skull",
	}))
	if resp2.Error == nil {
		t.Error("debe fallar con hostname vacío")
	}
}

// TestRPC_CtxPromote_BitMaskPositivo verifica que Promote retorna una sesión
// con BitMask > 0 y que el DeviceContext origen queda invalidado.
func TestRPC_CtxPromote_BitMaskPositivo(t *testing.T) {
	s := makeCtxTestServer()

	// registrar dispositivo
	regResp := s.rpcCtxDeviceRegister(buildRPC("bos.ctx.device.register", map[string]string{
		"hostname":  "host-promote",
		"tenant_id": "skull",
		"ip":        "10.0.0.6",
	}))
	if regResp.Error != nil {
		t.Fatal(regResp.Error)
	}
	regData := regResp.Result.(map[string]interface{})
	dctxID := regData["dctx_id"].(string)

	// promover
	const testMask uint64 = 0x0F
	promResp := s.rpcCtxPromote(buildRPC("bos.ctx.promote", map[string]interface{}{
		"dctx_id":     dctxID,
		"empresa_id":  "TS-01",
		"sucursal_id": "SUC-01",
		"pos_logico":  "POS-01",
		"user_id":     "usr_test",
		"bitmask":     testMask,
		"loa":         2,
		"traceparent": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
	}))
	if promResp.Error != nil {
		t.Fatalf("rpcCtxPromote error: %v", promResp.Error)
	}

	promData := promResp.Result.(map[string]interface{})
	ctxID, _ := promData["ctx_id"].(string)
	if ctxID == "" {
		t.Error("ctx_id debe ser no vacío")
	}

	// BitMask > 0 (el mapa interno usa uint64, no float64)
	bitmask := toUint64(promData["bitmask"])
	if bitmask == 0 {
		t.Error("bitmask debe ser > 0 (post-auth)")
	}
	if bitmask != testMask {
		t.Errorf("bitmask: want %d, got %d", testMask, bitmask)
	}

	// state debe ser ACTIVO
	state, _ := promData["state"].(string)
	if state != "ACTIVO" {
		t.Errorf("estado debe ser ACTIVO, got %s", state)
	}

	// traceparent preservado
	tp, _ := promData["traceparent"].(string)
	if tp == "" {
		t.Error("traceparent debe propagarse")
	}

	// no se puede promover de nuevo el mismo dctx_id
	promResp2 := s.rpcCtxPromote(buildRPC("bos.ctx.promote", map[string]interface{}{
		"dctx_id":     dctxID,
		"empresa_id":  "TS-01",
		"sucursal_id": "SUC-01",
		"pos_logico":  "POS-01",
		"user_id":     "usr_test",
		"bitmask":     testMask,
		"loa":         1,
		"traceparent": "",
	}))
	if promResp2.Error == nil {
		t.Error("segunda promoción del mismo dctx_id debe fallar")
	}
}

// TestRPC_CtxInvalidate_YaNoValido verifica que Invalidate marca el ctx_id como
// INVALIDADO y que bos.ctx.get retorna el estado correcto.
func TestRPC_CtxInvalidate_YaNoValido(t *testing.T) {
	s := makeCtxTestServer()

	// crear ciclo completo: register → promote → get → invalidate → get
	regResp := s.rpcCtxDeviceRegister(buildRPC("bos.ctx.device.register", map[string]string{
		"hostname":  "host-invalidate",
		"tenant_id": "skull",
		"ip":        "10.0.0.7",
	}))
	dctxID := regResp.Result.(map[string]interface{})["dctx_id"].(string)

	promResp := s.rpcCtxPromote(buildRPC("bos.ctx.promote", map[string]interface{}{
		"dctx_id":     dctxID,
		"user_id":     "usr_inv",
		"bitmask":     uint64(0xFF),
		"loa":         1,
		"traceparent": "",
	}))
	ctxID := promResp.Result.(map[string]interface{})["ctx_id"].(string)

	// get: debe estar ACTIVO
	getResp := s.rpcCtxGet(buildRPC("bos.ctx.get", map[string]string{"ctx_id": ctxID}))
	if getResp.Error != nil {
		t.Fatalf("rpcCtxGet: %v", getResp.Error)
	}
	stateActivo := getResp.Result.(map[string]interface{})["state"].(string)
	if stateActivo != "ACTIVO" {
		t.Errorf("antes de invalidar: want ACTIVO, got %s", stateActivo)
	}

	// invalidar
	invResp := s.rpcCtxInvalidate(buildRPC("bos.ctx.invalidate", map[string]string{"ctx_id": ctxID}))
	if invResp.Error != nil {
		t.Fatalf("rpcCtxInvalidate: %v", invResp.Error)
	}
	invalidated, _ := invResp.Result.(map[string]interface{})["invalidated"].(bool)
	if !invalidated {
		t.Error("invalidated debe ser true")
	}

	// get tras invalidar: state debe ser INVALIDADO
	getResp2 := s.rpcCtxGet(buildRPC("bos.ctx.get", map[string]string{"ctx_id": ctxID}))
	if getResp2.Error != nil {
		t.Fatalf("rpcCtxGet tras invalidar: %v", getResp2.Error)
	}
	stateInv := getResp2.Result.(map[string]interface{})["state"].(string)
	if stateInv != "INVALIDADO" {
		t.Errorf("después de invalidar: want INVALIDADO, got %s", stateInv)
	}

	// invalidar de nuevo: debe ser idempotente (sin error)
	invResp2 := s.rpcCtxInvalidate(buildRPC("bos.ctx.invalidate", map[string]string{"ctx_id": ctxID}))
	if invResp2.Error != nil {
		t.Errorf("segunda invalidación debe ser idempotente: %v", invResp2.Error)
	}

	// ctx_id vacío debe retornar error
	invBad := s.rpcCtxInvalidate(buildRPC("bos.ctx.invalidate", map[string]string{"ctx_id": ""}))
	if invBad.Error == nil {
		t.Error("ctx_id vacío debe retornar error")
	}
}
