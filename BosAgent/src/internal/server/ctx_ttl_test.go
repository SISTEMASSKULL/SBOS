// Package server — tests F6.5: validación TTL de ctx_id.
// DoD: ctx expirado → -32001 ContextExpired.
package server

import (
	"context"
	"errors"
	"testing"
	"time"

	bosctx "bos/internal/context"
)

// expiredStore implementa bosctx.Store retornando siempre una sesión cuyo
// TTL ya venció — simula un ctx_id válido en BD pero caducado.
type expiredStore struct{}

func expiredSession(ctxID string) *bosctx.SessionContext {
	return &bosctx.SessionContext{
		CtxID:     ctxID,
		DctxID:    "dctx-origen",
		TenantID:  "skull",
		UserID:    "usr_caducado",
		BitMask:   bosctx.BitMask(0xFF),
		LoA:       2,
		State:     bosctx.StateActivo,
		CreatedAt: time.Now().UTC().Add(-13 * time.Hour),
		ExpiresAt: time.Now().UTC().Add(-1 * time.Hour), // venció hace 1h
	}
}

func (expiredStore) SaveDevice(*bosctx.DeviceContext) error { return nil }
func (expiredStore) GetDevice(string) (*bosctx.DeviceContext, error) {
	return nil, errors.New("no usado en este test")
}
func (expiredStore) SaveSession(*bosctx.SessionContext) error { return nil }
func (expiredStore) GetSession(ctxID string) (*bosctx.SessionContext, error) {
	return expiredSession(ctxID), nil
}
func (expiredStore) ListSessionsByTenant(string) ([]*bosctx.SessionContext, error) {
	return nil, nil
}
func (expiredStore) UpdateDeviceState(string, bosctx.ContextState) error  { return nil }
func (expiredStore) UpdateSessionState(string, bosctx.ContextState) error { return nil }
func (expiredStore) AutoMigrate(ctx context.Context) error               { return nil }

func makeExpiredServer() *Server {
	return &Server{
		bosCtxSvc: bosctx.NewService(expiredStore{}),
		logger:    makeTestLogger(),
	}
}

// TestCtxTTL_GetExpirado_32001 es el DoD de F6.5: bos.ctx.get sobre un
// ctx_id con TTL vencido retorna -32001 ContextExpired.
func TestCtxTTL_GetExpirado_32001(t *testing.T) {
	s := makeExpiredServer()

	resp := s.rpcCtxGet(buildRPC("bos.ctx.get", map[string]string{"ctx_id": "ctx-caducado"}))

	if resp.Error == nil {
		t.Fatal("ctx expirado debe retornar error")
	}
	if resp.Error.Code != ErrContextExpired {
		t.Errorf("code: want %d (ContextExpired), got %d", ErrContextExpired, resp.Error.Code)
	}
}

// TestCtxTTL_SwitchSobreExpirado_32001: conmutar empresa partiendo de una
// sesión caducada también debe rechazarse con -32001.
func TestCtxTTL_SwitchSobreExpirado_32001(t *testing.T) {
	s := makeExpiredServer()

	resp := s.rpcCtxSwitch(buildRPC("bos.ctx.switch", map[string]string{
		"ctx_id":     "ctx-caducado",
		"empresa_id": "EMP-02",
	}))

	if resp.Error == nil {
		t.Fatal("switch sobre ctx expirado debe retornar error")
	}
	if resp.Error.Code != ErrContextExpired {
		t.Errorf("code: want %d (ContextExpired), got %d", ErrContextExpired, resp.Error.Code)
	}
}

// TestCtxTTL_GetVigente_OK: una sesión con TTL vigente sigue resolviendo
// normalmente tras F6.5 (regresión del flujo feliz, cubre register→promote→get).
func TestCtxTTL_GetVigente_OK(t *testing.T) {
	s := makeCtxTestServer()

	reg := s.rpcCtxDeviceRegister(buildRPC("bos.ctx.device.register", map[string]string{
		"hostname": "host-ttl", "tenant_id": "skull", "ip": "10.0.0.9",
	}))
	dctxID := reg.Result.(map[string]interface{})["dctx_id"].(string)

	prom := s.rpcCtxPromote(buildRPC("bos.ctx.promote", map[string]interface{}{
		"dctx_id": dctxID, "user_id": "usr_ok", "bitmask": uint64(0x01), "loa": 1,
	}))
	ctxID := prom.Result.(map[string]interface{})["ctx_id"].(string)

	resp := s.rpcCtxGet(buildRPC("bos.ctx.get", map[string]string{"ctx_id": ctxID}))
	if resp.Error != nil {
		t.Fatalf("ctx vigente no debe fallar: %v", resp.Error)
	}
	if expired, _ := resp.Result.(map[string]interface{})["expired"].(bool); expired {
		t.Error("ctx vigente debe reportar expired=false")
	}
}
