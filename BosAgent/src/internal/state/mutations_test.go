// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package state

import (
	"os"
	"path/filepath"
	"testing"
)

func nuevoMgr(t *testing.T) *Manager {
	t.Helper()
	m, err := NewManager(filepath.Join(t.TempDir(), "s.json"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { m.Close() })
	return m
}

// ── SetK8sDiscoveredState ─────────────────────────────────────────────────────

// SetK8sDiscoveredState solo actualiza fichas que ya existen y están en estados
// estables (no PENDING/READY/transitional). Documenta el comportamiento real.

func TestSetK8sDiscoveredState_TransicionaDesdeInstalada(t *testing.T) {
	m := nuevoMgr(t)

	// Registrar en estado INSTALLED directamente via ForceState
	if err := m.Register("svc-a", StatePending, "1.0.0", false, "testsrv", 1, "bash"); err != nil {
		t.Fatal(err)
	}
	if err := m.ForceState("svc-a", StateInstalled); err != nil {
		t.Fatal(err)
	}

	// Ahora K8s descubre que está DEGRADADA
	if err := m.SetK8sDiscoveredState("svc-a", StateDegraded); err != nil {
		t.Fatalf("SetK8sDiscoveredState: %v", err)
	}

	st, _ := m.Read()
	if st.Fichas["svc-a"].State != StateDegraded {
		t.Errorf("estado = %s, quería DEGRADADA", st.Fichas["svc-a"].State)
	}
}

func TestSetK8sDiscoveredState_NoPisaEstadoPending(t *testing.T) {
	m := nuevoMgr(t)

	if err := m.Register("svc-p", StatePending, "1.0.0", false, "testsrv", 1, "bash"); err != nil {
		t.Fatal(err)
	}

	// K8s no debe pisar PENDING — el observer gestiona ese estado
	if err := m.SetK8sDiscoveredState("svc-p", StateInstalled); err != nil {
		t.Fatalf("SetK8sDiscoveredState: %v", err)
	}

	st, _ := m.Read()
	if st.Fichas["svc-p"].State != StatePending {
		t.Errorf("PENDING no debe pisarse: estado = %s", st.Fichas["svc-p"].State)
	}
}

func TestSetK8sDiscoveredState_FichaInexistente_SilenciosoSinError(t *testing.T) {
	m := nuevoMgr(t)

	// Ficha no registrada → retorna nil silenciosamente (no crea)
	if err := m.SetK8sDiscoveredState("no-existe", StateDegraded); err != nil {
		t.Errorf("SetK8sDiscoveredState en ficha inexistente debe retornar nil, got: %v", err)
	}

	st, _ := m.Read()
	if _, ok := st.Fichas["no-existe"]; ok {
		t.Error("SetK8sDiscoveredState no debe crear fichas nuevas")
	}
}

func TestSetK8sDiscoveredState_NoPisaEstadoTransitorio(t *testing.T) {
	m := nuevoMgr(t)

	if err := m.Register("svc-t", StatePending, "1.0.0", false, "testsrv", 1, "bash"); err != nil {
		t.Fatal(err)
	}
	// Poner en INSTALLING (transitorio)
	if err := m.ForceState("svc-t", StateInstalling); err != nil {
		t.Fatal(err)
	}

	// K8s no debe pisar estados transitorios
	if err := m.SetK8sDiscoveredState("svc-t", StateDegraded); err != nil {
		t.Fatalf("SetK8sDiscoveredState: %v", err)
	}

	st, _ := m.Read()
	if st.Fichas["svc-t"].State != StateInstalling {
		t.Errorf("estado transitorio no debe pisarse: estado = %s", st.Fichas["svc-t"].State)
	}
}

// ── ForceState ────────────────────────────────────────────────────────────────

func TestForceState_SaltaValidacionDeTranisicion(t *testing.T) {
	m := nuevoMgr(t)
	if err := m.Register("svc-b", StatePending, "1.0.0", false, "testsrv", 1, "bash"); err != nil {
		t.Fatal(err)
	}

	// Forzar un estado terminal arbitrario sin seguir la máquina de estados
	if err := m.ForceState("svc-b", StatePhysicalError); err != nil {
		t.Fatalf("ForceState: %v", err)
	}

	st, _ := m.Read()
	if st.Fichas["svc-b"].State != StatePhysicalError {
		t.Errorf("ForceState: estado = %s, quería PHYSICAL_ERROR", st.Fichas["svc-b"].State)
	}
}

func TestForceState_FichaInexistente(t *testing.T) {
	m := nuevoMgr(t)
	err := m.ForceState("no-existe", StateInstalled)
	if err == nil {
		t.Error("ForceState en ficha inexistente debe retornar error")
	}
}

// ── NewManager con archivo existente corrupto ─────────────────────────────────

func TestNewManager_ArchivoCorrupto(t *testing.T) {
	path := filepath.Join(t.TempDir(), "corrupto.json")
	if err := os.WriteFile(path, []byte("{ no es json }"), 0644); err != nil {
		t.Fatal(err)
	}
	// Manager debe arrancar con estado limpio si el archivo es inválido
	m, err := NewManager(path)
	if err != nil {
		// Aceptable: fallar es una respuesta válida ante corrupción
		return
	}
	defer m.Close()
	// Si abre, el estado debe ser coherente (no entrar en pánico)
	st, readErr := m.Read()
	if readErr != nil {
		t.Fatalf("Read() tras estado corrupto: %v", readErr)
	}
	if st == nil {
		t.Error("Read() retornó nil state")
	}
}

// ── Concurrencia: lecturas paralelas no corrompen ─────────────────────────────

func TestManager_LecturasConcurrentes(t *testing.T) {
	m := nuevoMgr(t)
	if err := m.Register("svc-c", StatePending, "1.0.0", false, "testsrv", 1, "bash"); err != nil {
		t.Fatal(err)
	}

	done := make(chan struct{})
	for i := 0; i < 20; i++ {
		go func() {
			defer func() { done <- struct{}{} }()
			for j := 0; j < 50; j++ {
				st, err := m.Read()
				if err != nil {
					return
				}
				_ = st.Fichas["svc-c"].State
			}
		}()
	}
	for i := 0; i < 20; i++ {
		<-done
	}
}
