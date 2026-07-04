// Package context — tests T8.3 (F8): ciclo de vida completo del Context Plane.
// Cubre Service.Switch / ListAllByTenant y el CRUD del PGRedisStore con
// stubs (Exec configurable + Redis en memoria) — sin PostgreSQL real.
package context

import (
	"database/sql"
	"encoding/json"
	"testing"
	"time"
)

// execStub implementa SQLExecutor solo para Exec, con filas afectadas y
// error configurables. QueryRow/Query no se usan en los métodos bajo test.
type execStub struct {
	rows int64
	err  error
}

func (e execStub) Exec(string, ...any) (sql.Result, error) {
	return sqlResultStub{n: e.rows}, e.err
}
func (e execStub) QueryRow(string, ...any) *sql.Row        { return nil }
func (e execStub) Query(string, ...any) (*sql.Rows, error) { return nil, sql.ErrNoRows }

// ─── Service: Switch y ListAllByTenant ────────────────────────────────────

// TestService_Switch_CicloCompleto: el switch de empresa crea una sesión
// nueva que hereda tenant/user/bitmask y deja la anterior INVALIDADA
// (el ctx_id es inmutable — SBOS-049).
func TestService_Switch_CicloCompleto(t *testing.T) {
	svc := NewServiceWithMemStore()

	dev, err := svc.RegisterDevice("host-sw", "skull", "node-01", "10.0.0.8")
	if err != nil {
		t.Fatal(err)
	}
	prev, err := svc.Promote(dev.DctxID, "EMP-A", "SUC-1", "POS-1", "usr_sw",
		BitMask(0xAA), 2, testTP)
	if err != nil {
		t.Fatal(err)
	}

	nueva, err := svc.Switch(prev.CtxID, "EMP-B", "SUC-2", "POS-2", testTP)
	if err != nil {
		t.Fatalf("Switch: %v", err)
	}

	if nueva.CtxID == prev.CtxID {
		t.Error("el switch debe generar un ctx_id nuevo (inmutabilidad)")
	}
	if nueva.TenantID != "skull" || nueva.UserID != "usr_sw" {
		t.Errorf("la nueva sesión hereda tenant/user: %+v", nueva)
	}
	if nueva.BitMask != BitMask(0xAA) || nueva.LoA != 2 {
		t.Error("la nueva sesión hereda BitMask y LoA")
	}
	if nueva.EmpresaID != "EMP-B" || nueva.SucursalID != "SUC-2" {
		t.Error("la nueva sesión toma la empresa/sucursal destino")
	}

	anterior, err := svc.Get(prev.CtxID)
	if err != nil {
		t.Fatal(err)
	}
	if anterior.State != StateInvalidado {
		t.Errorf("la sesión anterior debe quedar INVALIDADA, got %s", anterior.State)
	}

	// switch sobre una sesión terminal debe fallar
	if _, err := svc.Switch(prev.CtxID, "EMP-C", "", "", testTP); err == nil {
		t.Error("switch sobre sesión INVALIDADA debe fallar")
	}
}

// TestService_ListAllByTenant_IncluyeTerminales: la vista de diagnóstico
// (F6.11) ve todas las sesiones; la operativa (ListByTenant) solo activas.
func TestService_ListAllByTenant_IncluyeTerminales(t *testing.T) {
	svc := NewServiceWithMemStore()

	d1, _ := svc.RegisterDevice("h1", "skull", "", "10.0.0.1")
	s1, _ := svc.Promote(d1.DctxID, "E", "S", "P", "u1", BitMask(1), 1, testTP)
	d2, _ := svc.RegisterDevice("h2", "skull", "", "10.0.0.2")
	_, _ = svc.Promote(d2.DctxID, "E", "S", "P", "u2", BitMask(1), 1, testTP)

	if err := svc.Invalidate(s1.CtxID); err != nil {
		t.Fatal(err)
	}

	todas, err := svc.ListAllByTenant("skull")
	if err != nil {
		t.Fatal(err)
	}
	if len(todas) != 2 {
		t.Errorf("ListAllByTenant ve también terminales: want 2, got %d", len(todas))
	}

	activas, err := svc.ListByTenant("skull")
	if err != nil {
		t.Fatal(err)
	}
	if len(activas) != 1 {
		t.Errorf("ListByTenant solo activas: want 1, got %d", len(activas))
	}

	if _, err := svc.ListAllByTenant(""); err == nil {
		t.Error("tenantID vacío debe fallar")
	}
}

// ─── Store: CRUD con stubs ────────────────────────────────────────────────

// TestStore_SaveDevice_Guards: persiste vía Exec; sin SQLExecutor falla.
func TestStore_SaveDevice_Guards(t *testing.T) {
	dev, _ := NewDeviceContext("host-st", "skull", "", "10.0.0.9")

	conDB := &PGRedisStore{db: execStub{rows: 1}, cache: newRedisStub()}
	if err := conDB.SaveDevice(dev); err != nil {
		t.Errorf("SaveDevice con db: %v", err)
	}

	sinDB := &PGRedisStore{db: nil, cache: newRedisStub()}
	if err := sinDB.SaveDevice(dev); err == nil {
		t.Error("SaveDevice sin SQLExecutor debe fallar")
	}
	if err := sinDB.SaveSession(&SessionContext{CtxID: "x"}); err == nil {
		t.Error("SaveSession sin SQLExecutor debe fallar")
	}
	if err := sinDB.UpdateDeviceState("d", StateActivo); err == nil {
		t.Error("UpdateDeviceState sin SQLExecutor debe fallar")
	}
	if err := sinDB.UpdateSessionState("c", StateActivo); err == nil {
		t.Error("UpdateSessionState sin SQLExecutor debe fallar")
	}
}

// TestStore_GetDevice_CacheHitYMiss: el cache responde O(1); sin cache ni
// db el dispositivo no existe (errNotFound).
func TestStore_GetDevice_CacheHitYMiss(t *testing.T) {
	cache := newRedisStub()
	store := &PGRedisStore{db: nil, cache: cache}

	dev, _ := NewDeviceContext("host-cache", "skull", "node-01", "10.0.0.7")
	raw, _ := json.Marshal(dev)
	_ = cache.Set("dctx:"+dev.DctxID, raw, MaxDeviceTTL)

	got, err := store.GetDevice(dev.DctxID)
	if err != nil {
		t.Fatalf("GetDevice cache-hit: %v", err)
	}
	if got.Hostname != "host-cache" || got.BitMask != 0 {
		t.Errorf("device del cache: %+v", got)
	}

	if _, err := store.GetDevice("dctx-no-existe"); err == nil {
		t.Error("cache-miss sin db debe retornar errNotFound")
	}
}

// TestStore_SaveSession_PueblaCache: SaveSession escribe en PG y deja el
// ctx_id listo en Redis para el lookup O(1) del Kong plugin.
func TestStore_SaveSession_PueblaCache(t *testing.T) {
	cache := newRedisStub()
	store := &PGRedisStore{db: execStub{rows: 1}, cache: cache}

	sess, err := NewSessionContext("dctx-ps", "skull", "E", "S", "P", "usr_ps",
		testMask, 2, testTP)
	if err != nil {
		t.Fatal(err)
	}
	if err := store.SaveSession(sess); err != nil {
		t.Fatalf("SaveSession: %v", err)
	}

	if ok, _ := cache.Exists("ctx:" + sess.CtxID); !ok {
		t.Error("SaveSession debe poblar el cache Redis")
	}

	got, err := store.GetSession(sess.CtxID)
	if err != nil {
		t.Fatalf("GetSession tras SaveSession: %v", err)
	}
	if got.Traceparent != testTP {
		t.Error("traceparent debe sobrevivir el ciclo save→get")
	}

	// una sesión ya expirada no se cachea (TTL ≤ 0)
	caduca := *sess
	caduca.CtxID = "ctx-caduca"
	caduca.ExpiresAt = time.Now().Add(-time.Minute)
	if err := store.SaveSession(&caduca); err != nil {
		t.Fatal(err)
	}
	if ok, _ := cache.Exists("ctx:ctx-caduca"); ok {
		t.Error("una sesión expirada no debe entrar al cache")
	}
}

// TestStore_UpdateStates_InvalidanCache: actualizar estado elimina la
// entrada del cache (Kong deja de aceptar el ctx_id de inmediato —
// SBOS-049 §8); 0 filas afectadas → errNotFound.
func TestStore_UpdateStates_InvalidanCache(t *testing.T) {
	cache := newRedisStub()
	store := &PGRedisStore{db: execStub{rows: 1}, cache: cache}

	_ = cache.Set("ctx:ctx-upd", []byte("{}"), time.Hour)
	if err := store.UpdateSessionState("ctx-upd", StateInvalidado); err != nil {
		t.Fatalf("UpdateSessionState: %v", err)
	}
	if ok, _ := cache.Exists("ctx:ctx-upd"); ok {
		t.Error("UpdateSessionState debe eliminar el ctx del cache")
	}

	_ = cache.Set("dctx:dctx-upd", []byte("{}"), time.Hour)
	if err := store.UpdateDeviceState("dctx-upd", StateActivo); err != nil {
		t.Fatalf("UpdateDeviceState: %v", err)
	}
	if ok, _ := cache.Exists("dctx:dctx-upd"); ok {
		t.Error("UpdateDeviceState debe invalidar el cache del device")
	}

	// 0 filas afectadas → el registro no existe
	vacio := &PGRedisStore{db: execStub{rows: 0}, cache: cache}
	if err := vacio.UpdateSessionState("ctx-fantasma", StateInvalidado); err == nil {
		t.Error("update sin filas afectadas debe retornar errNotFound")
	}
	if err := vacio.UpdateDeviceState("dctx-fantasma", StateActivo); err == nil {
		t.Error("update de device sin filas debe retornar errNotFound")
	}
}

// TestStore_ListSinDB_YConstructor: degraded mode documentado — sin db la
// lista es vacía sin error; el constructor acepta nil/nil.
func TestStore_ListSinDB_YConstructor(t *testing.T) {
	store := NewPGRedisStore(nil, nil)
	sessions, err := store.ListSessionsByTenant("skull")
	if err != nil || sessions != nil {
		t.Errorf("sin db: want (nil, nil), got (%v, %v)", sessions, err)
	}
}

// TestTypes_IsExpired: el TTL gobierna ambos tipos de contexto.
func TestTypes_IsExpired(t *testing.T) {
	dev, _ := NewDeviceContext("h", "t", "", "")
	if dev.IsExpired() {
		t.Error("device recién creado no está expirado (TTL 8h)")
	}
	dev.ExpiresAt = time.Now().UTC().Add(-time.Second)
	if !dev.IsExpired() {
		t.Error("device con ExpiresAt pasado debe estar expirado")
	}

	ses, _ := NewSessionContext("d", "t", "", "", "", "u", BitMask(1), 1, "")
	if ses.IsExpired() {
		t.Error("sesión recién creada no está expirada (TTL 12h)")
	}
	ses.ExpiresAt = time.Now().UTC().Add(-time.Second)
	if !ses.IsExpired() {
		t.Error("sesión con ExpiresAt pasado debe estar expirada")
	}
}
