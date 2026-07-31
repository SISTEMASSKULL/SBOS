package state

import (
	"encoding/json"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func tempStateFile(t *testing.T) string {
	t.Helper()
	return filepath.Join(t.TempDir(), ".sbos_state.json")
}

func newTestManager(t *testing.T, path string) *Manager {
	t.Helper()
	m, err := NewManager(path)
	require.NoError(t, err)
	t.Cleanup(func() { m.Close() })
	return m
}

// seedFicha pone una ficha en el estado deseado siguiendo transiciones válidas de ADR-021.
// El punto de entrada es siempre LISTA (auto-create) → INSTALANDO.
func seedFicha(t *testing.T, m *Manager, name string, target FichaState) {
	t.Helper()

	// Auto-create: LISTA → INSTALANDO (ver Transition para la lógica de auto-create)
	require.NoError(t, m.Transition(name, StateInstalling))

	switch target {
	case StateInstalling:
		return

	case StateInstalled:
		require.NoError(t, m.Transition(name, StateInstalled))

	case StateDegraded:
		require.NoError(t, m.Transition(name, StateInstalled))
		require.NoError(t, m.Transition(name, StateDegraded))

	case StateUpdateAvailable:
		require.NoError(t, m.Transition(name, StateInstalled))
		require.NoError(t, m.Transition(name, StateUpdateAvailable))

	case StateUpdateApproved:
		require.NoError(t, m.Transition(name, StateInstalled))
		require.NoError(t, m.Transition(name, StateUpdateAvailable))
		require.NoError(t, m.Transition(name, StateUpdateApproved))

	case StateUpdating:
		require.NoError(t, m.Transition(name, StateInstalled))
		require.NoError(t, m.Transition(name, StateUpdateAvailable))
		require.NoError(t, m.Transition(name, StateUpdateApproved))
		require.NoError(t, m.Transition(name, StateUpdating))

	case StateRepairing:
		require.NoError(t, m.Transition(name, StateInstalled))
		require.NoError(t, m.Transition(name, StateDegraded))
		require.NoError(t, m.Transition(name, StateRepairing))

	case StatePhysicalError:
		require.NoError(t, m.Transition(name, StateInstalled))
		require.NoError(t, m.Transition(name, StateDegraded))
		require.NoError(t, m.Transition(name, StatePhysicalError))

	case StateLogicalError:
		require.NoError(t, m.Transition(name, StateInstalled))
		require.NoError(t, m.Transition(name, StateDegraded))
		require.NoError(t, m.Transition(name, StateLogicalError))

	case StateInstallFailed:
		require.NoError(t, m.Transition(name, StateInstallFailed))

	case StateCleanup:
		require.NoError(t, m.Transition(name, StateInstallFailed))
		require.NoError(t, m.Transition(name, StateCleanup))

	case StateReady:
		// LISTA es el estado inicial antes de INSTALANDO.
		// Para volver a LISTA desde INSTALANDO: fallo → limpieza → lista.
		require.NoError(t, m.Transition(name, StateInstallFailed))
		require.NoError(t, m.Transition(name, StateCleanup))
		require.NoError(t, m.Transition(name, StateReady))

	case StateUninstalled:
		require.NoError(t, m.Transition(name, StateInstalled))
		require.NoError(t, m.Transition(name, StateUninstalled))

	case StatePending:
		// PENDIENTE es forzado por SetPendiente (bypassa ValidTransitions)
		require.NoError(t, m.SetPendiente(name))

	default:
		t.Fatalf("seedFicha: estado no soportado %s", target)
	}
}

// ── Creation ────────────────────────────────────────────────

func TestNewManager_CreatesFile(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)

	st, err := m.Read()
	require.NoError(t, err)

	assert.Equal(t, "1.0.0", st.Version)
	assert.NotEmpty(t, st.Hostname)
	assert.NotZero(t, st.UpdatedAt)
	assert.NotNil(t, st.Fichas)
	assert.NotNil(t, st.Meta)
}

func TestNewManager_OpensExisting(t *testing.T) {
	path := tempStateFile(t)

	m1 := newTestManager(t, path)
	require.NoError(t, m1.Transition("test-ficha", StateInstalling))
	m1.Close()

	m2 := newTestManager(t, path)
	st, err := m2.Read()
	require.NoError(t, err)

	f, ok := st.Fichas["test-ficha"]
	require.True(t, ok)
	assert.Equal(t, StateInstalling, f.State)
	m2.Close()
}

// ── Canonical States ────────────────────────────────────────

func TestStableStates(t *testing.T) {
	stable := StableStates()
	assert.Len(t, stable, 13)
	for _, s := range []FichaState{
		StatePending, StateReady, StateInstalled,
		StateUpdateAvailable, StateUpdateApproved,
		StateDegraded, StatePhysicalError, StateLogicalError,
		StateUnrecoverable, StateInstallFailed, StateUpdateFailed,
		StatePaused, StateUninstalled,
	} {
		assert.Contains(t, stable, s, "stable debería contener %s", s)
	}
}

func TestTransitionalStates(t *testing.T) {
	trans := TransitionalStates()
	assert.Len(t, trans, 5)
	for _, s := range []FichaState{
		StateInstalling, StateUpdating, StateRepairing,
		StateRollback, StateCleanup,
	} {
		assert.Contains(t, trans, s, "transitional debería contener %s", s)
	}
}

func TestIsStable(t *testing.T) {
	// Todos los estables
	for _, s := range StableStates() {
		assert.True(t, s.IsStable(), "%s debería ser stable", s)
		assert.False(t, s.IsTransitional(), "%s no debería ser transitional", s)
	}
}

func TestIsTransitional(t *testing.T) {
	for _, s := range TransitionalStates() {
		assert.True(t, s.IsTransitional(), "%s debería ser transitional", s)
		assert.False(t, s.IsStable(), "%s no debería ser stable", s)
	}
}

func TestIsError(t *testing.T) {
	for _, s := range []FichaState{
		StatePhysicalError, StateLogicalError, StateUnrecoverable,
		StateInstallFailed, StateUpdateFailed,
	} {
		assert.True(t, s.IsError(), "%s debería ser error", s)
	}
	assert.False(t, StateInstalled.IsError())
	assert.False(t, StateDegraded.IsError())
}

func TestIsHealthy(t *testing.T) {
	assert.True(t, StateInstalled.IsHealthy())
	assert.False(t, StateDegraded.IsHealthy())
	assert.False(t, StateLogicalError.IsHealthy())
}

// ── Valid Transitions (via seedFicha)→───────────────────────

func TestTransition_ValidPaths(t *testing.T) {
	type step struct {
		state FichaState
		desc  string
	}

	paths := []struct {
		name  string
		steps []step
	}{
		{
			"install_ok",
			[]step{
				{StateInstalling, "LISTA→INSTALANDO (auto-create)"},
				{StateInstalled, "install exitoso"},
			},
		},
		{
			"install_falla_limpieza_lista",
			[]step{
				{StateInstalling, "auto-create"},
				{StateInstallFailed, "saga falló"},
				{StateCleanup, "limpiando artefactos"},
				{StateReady, "listo para reintentar"},
			},
		},
		{
			"install_falla_reintento",
			[]step{
				{StateInstalling, "auto-create"},
				{StateInstallFailed, "saga falló"},
				{StateInstalling, "reintento"},
				{StateInstalled, "reintento exitoso"},
			},
		},
		{
			"degradada_reparando_ok",
			[]step{
				{StateInstalling, "auto-create"},
				{StateInstalled, "ok"},
				{StateDegraded, "health check falla"},
				{StateRepairing, "reparando"},
				{StateInstalled, "recuperado"},
			},
		},
		{
			"degradada_error_fisico_reparando",
			[]step{
				{StateInstalling, "auto-create"},
				{StateInstalled, "ok"},
				{StateDegraded, "degradado"},
				{StatePhysicalError, "causa física confirmada"},
				{StateRepairing, "reparando"},
			},
		},
		{
			"degradada_error_logico_reparando",
			[]step{
				{StateInstalling, "auto-create"},
				{StateInstalled, "ok"},
				{StateDegraded, "degradado"},
				{StateLogicalError, "causa lógica confirmada"},
				{StateRepairing, "reparando"},
			},
		},
		{
			"update_flow_completo",
			[]step{
				{StateInstalling, "auto-create"},
				{StateInstalled, "ok"},
				{StateUpdateAvailable, "drift detectado"},
				{StateUpdateApproved, "evaluación OK"},
				{StateUpdating, "actualizando"},
				{StateInstalled, "actualizado"},
			},
		},
		{
			"update_falla_rollback_ok",
			[]step{
				{StateInstalling, "auto-create"},
				{StateInstalled, "ok"},
				{StateUpdateAvailable, "drift"},
				{StateUpdateApproved, "aprobado"},
				{StateUpdating, "actualizando"},
				{StateUpdateFailed, "falla update"},
				{StateRollback, "rollback"},
				{StateInstalled, "rollback exitoso"},
			},
		},
		{
			"error_no_corregible_hitl_reintento",
			[]step{
				{StateInstalling, "auto-create"},
				{StateInstalled, "ok"},
				{StateDegraded, "degradado"},
				{StateRepairing, "reparando"},
				{StateUnrecoverable, "reintentos agotados"},
				{StateRepairing, "HITL interviene"},
				{StateInstalled, "recuperado"},
			},
		},
		{
			"pausada_y_reanuda",
			[]step{
				{StateInstalling, "auto-create"},
				{StateInstalled, "ok"},
				{StatePaused, "admin pausa"},
				{StateInstalled, "admin reanuda"},
			},
		},
		{
			"desinstalar",
			[]step{
				{StateInstalling, "auto-create"},
				{StateInstalled, "ok"},
				{StateUninstalled, "desinstalada"},
			},
		},
	}

	for _, tc := range paths {
		t.Run(tc.name, func(t *testing.T) {
			path := tempStateFile(t)
			m := newTestManager(t, path)

			for _, s := range tc.steps {
				err := m.Transition("app", s.state)
				if !assert.NoError(t, err, "step %s", s.desc) {
					return
				}
			}

			last := tc.steps[len(tc.steps)-1]
			st, _ := m.Read()
			assert.Equal(t, last.state, st.Fichas["app"].State)
		})
	}
}

func TestTransition_InvalidPaths(t *testing.T) {
	tests := []struct {
		name  string
		seed  FichaState
		badTo FichaState
	}{
		// Saltos prohibidos desde INSTALANDO
		{"instalando→pendiente", StateInstalling, StatePending},
		{"instalando→actualizacion_disp", StateInstalling, StateUpdateAvailable},
		{"instalando→instalada_directo_desde_falla", StateInstallFailed, StateInstalled},
		// Saltos prohibidos desde INSTALADA
		{"instalada→instalando", StateInstalled, StateInstalling},
		{"instalada→error_logico_directo", StateInstalled, StateLogicalError},
		{"instalada→lista_directo", StateInstalled, StateReady},
		// Saltos prohibidos desde estados de error
		{"error_logico→instalada", StateLogicalError, StateInstalled},
		{"error_fisico→instalada", StatePhysicalError, StateInstalled},
		// ACTUALIZACION_DISPONIBLE no puede saltar directo a ACTUALIZANDO
		{"actualizacion_disp→actualizando_sin_aprobar", StateUpdateAvailable, StateUpdating},
		// DESINSTALADA es estado final — ninguna transición posible
		{"desinstalada→lista", StateUninstalled, StateReady},
		{"desinstalada→instalando", StateUninstalled, StateInstalling},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			path := tempStateFile(t)
			m := newTestManager(t, path)
			seedFicha(t, m, "f", tc.seed)

			err := m.Transition("f", tc.badTo)
			assert.Error(t, err)
			assert.Contains(t, err.Error(), "invalid transition")
		})
	}
}

// ── Hashes ──────────────────────────────────────────────────

func TestRegisterHashes(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)
	seedFicha(t, m, "ficha-a", StateInstalled)

	hashes := map[string]string{
		"manifest.yml": "sha256:abc123def456",
		"task_catalog": "sha256:789012abc345",
	}
	require.NoError(t, m.RegisterHashes("ficha-a", hashes))

	st, _ := m.Read()
	assert.Equal(t, hashes, st.Fichas["ficha-a"].Hashes)
}

func TestRegisterHashes_NotFound(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)

	err := m.RegisterHashes("nonexistent", map[string]string{})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

// ── Health ──────────────────────────────────────────────────

func TestSetHealth(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)
	seedFicha(t, m, "svc", StateInstalled)

	require.NoError(t, m.SetHealth("svc", "degraded"))
	st, _ := m.Read()
	assert.Equal(t, "degraded", st.Fichas["svc"].HealthStatus)

	require.NoError(t, m.SetHealth("svc", "healthy"))
	st, _ = m.Read()
	assert.Equal(t, "healthy", st.Fichas["svc"].HealthStatus)
}

func TestSetHealth_NotFound(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)

	err := m.SetHealth("ghost", "healthy")
	assert.Error(t, err)
}

// ── Drift Detection ─────────────────────────────────────────

func TestSetDriftDetected(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)
	seedFicha(t, m, "pkg", StateInstalled)

	require.NoError(t, m.SetDriftDetected("pkg"))

	st, _ := m.Read()
	assert.Equal(t, StateUpdateAvailable, st.Fichas["pkg"].State)
}

// ── Block / Unblock ─────────────────────────────────────────

func TestSetBlocked(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)
	seedFicha(t, m, "dep", StateInstalling)

	err := m.SetBlocked("dep")
	assert.NoError(t, err)

	st, _ := m.Read()
	assert.Equal(t, StatePending, st.Fichas["dep"].State)
}

func TestSetBlocked_FromOK(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)
	seedFicha(t, m, "dep", StateInstalled)

	err := m.SetBlocked("dep")
	assert.NoError(t, err)

	st, _ := m.Read()
	assert.Equal(t, StatePending, st.Fichas["dep"].State)
}

func TestUnblock(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)
	seedFicha(t, m, "dep", StatePending)

	require.NoError(t, m.Unblock("dep"))

	st, _ := m.Read()
	assert.Equal(t, StateReady, st.Fichas["dep"].State)
}

func TestUnblock_NotBlocked(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)
	seedFicha(t, m, "dep", StateInstalled)

	err := m.Unblock("dep")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "PENDING")
}

// ── Metadata ────────────────────────────────────────────────

func TestMetaPersistence(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)

	st, _ := m.Read()
	assert.NotNil(t, st.Meta)
	assert.Empty(t, st.Meta)
}

// ── Timestamp updates ───────────────────────────────────────

func TestTransitionUpdatesTimestamps(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)

	require.NoError(t, m.Transition("ts", StateInstalling))
	st1, _ := m.Read()
	t1 := st1.UpdatedAt

	time.Sleep(10 * time.Millisecond)

	require.NoError(t, m.Transition("ts", StateInstalled))
	st2, _ := m.Read()
	t2 := st2.UpdatedAt

	assert.True(t, t2.After(t1), "UpdatedAt should advance after transition")
	assert.True(t, st2.Fichas["ts"].UpdatedAt.After(t1))
}

// ── JSON serialization ──────────────────────────────────────

func TestStateSerialization(t *testing.T) {
	s := SBOSState{
		Version:  "1.0.0",
		Hostname: "test",
		Fichas: map[string]*Ficha{
			"svc": {
				Name:    "svc",
				Version: "2.0",
				State:   StateInstalled,
				Hashes:  map[string]string{"k": "v"},
			},
		},
		Meta: map[string]string{"env": "test"},
	}

	b, err := json.Marshal(s)
	require.NoError(t, err)

	var s2 SBOSState
	require.NoError(t, json.Unmarshal(b, &s2))
	assert.Equal(t, "svc", s2.Fichas["svc"].Name)
	assert.Equal(t, StateInstalled, s2.Fichas["svc"].State)
}

// ── Concurrent access ───────────────────────────────────────

func TestConcurrentReads(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)
	seedFicha(t, m, "c", StateInstalled)

	var wg sync.WaitGroup
	errs := make(chan error, 10)

	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, err := m.Read()
			if err != nil {
				errs <- err
			}
		}()
	}
	wg.Wait()
	close(errs)

	for e := range errs {
		t.Errorf("concurrent Read error: %v", e)
	}
}

// ── Close releases lock ─────────────────────────────────────

func TestCloseAllowsReopen(t *testing.T) {
	path := tempStateFile(t)

	m1 := newTestManager(t, path)
	require.NoError(t, m1.Transition("x", StateInstalling))
	require.NoError(t, m1.Close())

	m2, err := NewManager(path)
	require.NoError(t, err, "reopen after close should succeed")
	m2.Close()
}

// ── Transition creates ficha for Instalando ─────────────────

func TestTransition_AutoCreateForInstalando(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)

	err := m.Transition("new-app", StateInstalling)
	require.NoError(t, err)

	st, _ := m.Read()
	f, ok := st.Fichas["new-app"]
	require.True(t, ok)
	assert.Equal(t, StateInstalling, f.State)
}

func TestTransition_AutoCreateFailsForNonInstalando(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)

	err := m.Transition("ghost", StateInstalled)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

// ── Valid transitions map integrity ─────────────────────────

func TestValidTransitions_TodosEstablesDefinidos(t *testing.T) {
	// Todo estado estable (excepto DESINSTALADA que es final) debe tener transiciones.
	for _, from := range StableStates() {
		if from == StateUninstalled {
			continue // estado final, sin transiciones salientes
		}
		_, ok := ValidTransitions[from]
		assert.True(t, ok, "estado estable %s debe tener transiciones definidas", from)
	}
}

func TestValidTransitions_TransicionalesAlcanzan_EstableOTransicional(t *testing.T) {
	for _, tr := range TransitionalStates() {
		targets, ok := ValidTransitions[tr]
		require.True(t, ok, "estado transicional %s debe tener transiciones definidas", tr)
		assert.NotEmpty(t, targets, "estado transicional %s debe tener al menos un destino", tr)
	}
}
