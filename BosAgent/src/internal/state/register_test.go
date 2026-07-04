// Package state — tests T8.6 (F8): Register, SetBackend y SetVersion.
package state

import (
	"path/filepath"
	"testing"
)

// TestRegister_SetBackend_SetVersion: ciclo de registro y mutadores de
// metadatos de una ficha; Register es idempotente.
func TestRegister_SetBackend_SetVersion(t *testing.T) {
	mgr, err := NewManager(filepath.Join(t.TempDir(), "state.json"))
	if err != nil {
		t.Fatal(err)
	}
	defer mgr.Close()

	if err := mgr.Register("redis", StateLista, "8.6.2", true, "dataserver", 1, "helm"); err != nil {
		t.Fatalf("Register: %v", err)
	}
	// idempotente: segundo registro del mismo nombre no falla ni duplica
	if err := mgr.Register("redis", StatePendiente, "9.0.0", false, "otro", 2, "apt"); err != nil {
		t.Fatalf("Register duplicado debe ser no-op: %v", err)
	}

	st, _ := mgr.Read()
	f := st.Fichas["redis"]
	if f == nil || f.Version != "8.6.2" || f.Server != "dataserver" {
		t.Fatalf("el registro original debe prevalecer: %+v", f)
	}

	if err := mgr.SetBackend("redis", "apt"); err != nil {
		t.Fatalf("SetBackend: %v", err)
	}
	if err := mgr.SetVersion("redis", "8.7.0"); err != nil {
		t.Fatalf("SetVersion: %v", err)
	}

	st, _ = mgr.Read()
	f = st.Fichas["redis"]
	if f.Backend != "apt" || f.Version != "8.7.0" {
		t.Errorf("mutadores no aplicados: backend=%s version=%s", f.Backend, f.Version)
	}

	// sobre ficha inexistente → error
	if err := mgr.SetBackend("fantasma", "x"); err == nil {
		t.Error("SetBackend de ficha inexistente debe fallar")
	}
	if err := mgr.SetVersion("fantasma", "1"); err == nil {
		t.Error("SetVersion de ficha inexistente debe fallar")
	}
}
