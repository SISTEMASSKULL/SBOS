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
	require.NoError(t, m.Transition(name, StateInstalando))

	switch target {
	case StateInstalando:
		return

	case StateInstalada:
		require.NoError(t, m.Transition(name, StateInstalada))

	case StateDegradada:
		require.NoError(t, m.Transition(name, StateInstalada))
		require.NoError(t, m.Transition(name, StateDegradada))

	case StateActualizacionDisp:
		require.NoError(t, m.Transition(name, StateInstalada))
		require.NoError(t, m.Transition(name, StateActualizacionDisp))

	case StateActualizacionAprobada:
		require.NoError(t, m.Transition(name, StateInstalada))
		require.NoError(t, m.Transition(name, StateActualizacionDisp))
		require.NoError(t, m.Transition(name, StateActualizacionAprobada))

	case StateActualizando:
		require.NoError(t, m.Transition(name, StateInstalada))
		require.NoError(t, m.Transition(name, StateActualizacionDisp))
		require.NoError(t, m.Transition(name, StateActualizacionAprobada))
		require.NoError(t, m.Transition(name, StateActualizando))

	case StateReparando:
		require.NoError(t, m.Transition(name, StateInstalada))
		require.NoError(t, m.Transition(name, StateDegradada))
		require.NoError(t, m.Transition(name, StateReparando))

	case StateErrorFisico:
		require.NoError(t, m.Transition(name, StateInstalada))
		require.NoError(t, m.Transition(name, StateDegradada))
		require.NoError(t, m.Transition(name, StateErrorFisico))

	case StateErrorLogico:
		require.NoError(t, m.Transition(name, StateInstalada))
		require.NoError(t, m.Transition(name, StateDegradada))
		require.NoError(t, m.Transition(name, StateErrorLogico))

	case StateFallaInstalacion:
		require.NoError(t, m.Transition(name, StateFallaInstalacion))

	case StateLimpieza:
		require.NoError(t, m.Transition(name, StateFallaInstalacion))
		require.NoError(t, m.Transition(name, StateLimpieza))

	case StateLista:
		// LISTA es el estado inicial antes de INSTALANDO.
		// Para volver a LISTA desde INSTALANDO: fallo → limpieza → lista.
		require.NoError(t, m.Transition(name, StateFallaInstalacion))
		require.NoError(t, m.Transition(name, StateLimpieza))
		require.NoError(t, m.Transition(name, StateLista))

	case StateDesinstalada:
		require.NoError(t, m.Transition(name, StateInstalada))
		require.NoError(t, m.Transition(name, StateDesinstalada))

	case StatePendiente:
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
	require.NoError(t, m1.Transition("test-ficha", StateInstalando))
	m1.Close()

	m2 := newTestManager(t, path)
	st, err := m2.Read()
	require.NoError(t, err)

	f, ok := st.Fichas["test-ficha"]
	require.True(t, ok)
	assert.Equal(t, StateInstalando, f.State)
	m2.Close()
}

// ── Canonical States ────────────────────────────────────────

func TestStableStates(t *testing.T) {
	stable := StableStates()
	assert.Len(t, stable, 13)
	for _, s := range []FichaState{
		StatePendiente, StateLista, StateInstalada,
		StateActualizacionDisp, StateActualizacionAprobada,
		StateDegradada, StateErrorFisico, StateErrorLogico,
		StateErrorNoCorregible, StateFallaInstalacion, StateFallaActualizacion,
		StatePausada, StateDesinstalada,
	} {
		assert.Contains(t, stable, s, "stable debería contener %s", s)
	}
}

func TestTransitionalStates(t *testing.T) {
	trans := TransitionalStates()
	assert.Len(t, trans, 5)
	for _, s := range []FichaState{
		StateInstalando, StateActualizando, StateReparando,
		StateRollback, StateLimpieza,
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
		StateErrorFisico, StateErrorLogico, StateErrorNoCorregible,
		StateFallaInstalacion, StateFallaActualizacion,
	} {
		assert.True(t, s.IsError(), "%s debería ser error", s)
	}
	assert.False(t, StateInstalada.IsError())
	assert.False(t, StateDegradada.IsError())
}

func TestIsHealthy(t *testing.T) {
	assert.True(t, StateInstalada.IsHealthy())
	assert.False(t, StateDegradada.IsHealthy())
	assert.False(t, StateErrorLogico.IsHealthy())
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
				{StateInstalando, "LISTA→INSTALANDO (auto-create)"},
				{StateInstalada, "install exitoso"},
			},
		},
		{
			"install_falla_limpieza_lista",
			[]step{
				{StateInstalando, "auto-create"},
				{StateFallaInstalacion, "saga falló"},
				{StateLimpieza, "limpiando artefactos"},
				{StateLista, "listo para reintentar"},
			},
		},
		{
			"install_falla_reintento",
			[]step{
				{StateInstalando, "auto-create"},
				{StateFallaInstalacion, "saga falló"},
				{StateInstalando, "reintento"},
				{StateInstalada, "reintento exitoso"},
			},
		},
		{
			"degradada_reparando_ok",
			[]step{
				{StateInstalando, "auto-create"},
				{StateInstalada, "ok"},
				{StateDegradada, "health check falla"},
				{StateReparando, "reparando"},
				{StateInstalada, "recuperado"},
			},
		},
		{
			"degradada_error_fisico_reparando",
			[]step{
				{StateInstalando, "auto-create"},
				{StateInstalada, "ok"},
				{StateDegradada, "degradado"},
				{StateErrorFisico, "causa física confirmada"},
				{StateReparando, "reparando"},
			},
		},
		{
			"degradada_error_logico_reparando",
			[]step{
				{StateInstalando, "auto-create"},
				{StateInstalada, "ok"},
				{StateDegradada, "degradado"},
				{StateErrorLogico, "causa lógica confirmada"},
				{StateReparando, "reparando"},
			},
		},
		{
			"update_flow_completo",
			[]step{
				{StateInstalando, "auto-create"},
				{StateInstalada, "ok"},
				{StateActualizacionDisp, "drift detectado"},
				{StateActualizacionAprobada, "evaluación OK"},
				{StateActualizando, "actualizando"},
				{StateInstalada, "actualizado"},
			},
		},
		{
			"update_falla_rollback_ok",
			[]step{
				{StateInstalando, "auto-create"},
				{StateInstalada, "ok"},
				{StateActualizacionDisp, "drift"},
				{StateActualizacionAprobada, "aprobado"},
				{StateActualizando, "actualizando"},
				{StateFallaActualizacion, "falla update"},
				{StateRollback, "rollback"},
				{StateInstalada, "rollback exitoso"},
			},
		},
		{
			"error_no_corregible_hitl_reintento",
			[]step{
				{StateInstalando, "auto-create"},
				{StateInstalada, "ok"},
				{StateDegradada, "degradado"},
				{StateReparando, "reparando"},
				{StateErrorNoCorregible, "reintentos agotados"},
				{StateReparando, "HITL interviene"},
				{StateInstalada, "recuperado"},
			},
		},
		{
			"pausada_y_reanuda",
			[]step{
				{StateInstalando, "auto-create"},
				{StateInstalada, "ok"},
				{StatePausada, "admin pausa"},
				{StateInstalada, "admin reanuda"},
			},
		},
		{
			"desinstalar",
			[]step{
				{StateInstalando, "auto-create"},
				{StateInstalada, "ok"},
				{StateDesinstalada, "desinstalada"},
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
		{"instalando→pendiente", StateInstalando, StatePendiente},
		{"instalando→actualizacion_disp", StateInstalando, StateActualizacionDisp},
		{"instalando→instalada_directo_desde_falla", StateFallaInstalacion, StateInstalada},
		// Saltos prohibidos desde INSTALADA
		{"instalada→instalando", StateInstalada, StateInstalando},
		{"instalada→error_logico_directo", StateInstalada, StateErrorLogico},
		{"instalada→lista_directo", StateInstalada, StateLista},
		// Saltos prohibidos desde estados de error
		{"error_logico→instalada", StateErrorLogico, StateInstalada},
		{"error_fisico→instalada", StateErrorFisico, StateInstalada},
		// ACTUALIZACION_DISPONIBLE no puede saltar directo a ACTUALIZANDO
		{"actualizacion_disp→actualizando_sin_aprobar", StateActualizacionDisp, StateActualizando},
		// DESINSTALADA es estado final — ninguna transición posible
		{"desinstalada→lista", StateDesinstalada, StateLista},
		{"desinstalada→instalando", StateDesinstalada, StateInstalando},
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
	seedFicha(t, m, "ficha-a", StateInstalada)

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
	seedFicha(t, m, "svc", StateInstalada)

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
	seedFicha(t, m, "pkg", StateInstalada)

	require.NoError(t, m.SetDriftDetected("pkg"))

	st, _ := m.Read()
	assert.Equal(t, StateActualizacionDisp, st.Fichas["pkg"].State)
}

// ── Block / Unblock ─────────────────────────────────────────

func TestSetBlocked(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)
	seedFicha(t, m, "dep", StateInstalando)

	err := m.SetBlocked("dep")
	assert.NoError(t, err)

	st, _ := m.Read()
	assert.Equal(t, StatePendiente, st.Fichas["dep"].State)
}

func TestSetBlocked_FromOK(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)
	seedFicha(t, m, "dep", StateInstalada)

	err := m.SetBlocked("dep")
	assert.NoError(t, err)

	st, _ := m.Read()
	assert.Equal(t, StatePendiente, st.Fichas["dep"].State)
}

func TestUnblock(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)
	seedFicha(t, m, "dep", StatePendiente)

	require.NoError(t, m.Unblock("dep"))

	st, _ := m.Read()
	assert.Equal(t, StateLista, st.Fichas["dep"].State)
}

func TestUnblock_NotBlocked(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)
	seedFicha(t, m, "dep", StateInstalada)

	err := m.Unblock("dep")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "PENDIENTE")
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

	require.NoError(t, m.Transition("ts", StateInstalando))
	st1, _ := m.Read()
	t1 := st1.UpdatedAt

	time.Sleep(10 * time.Millisecond)

	require.NoError(t, m.Transition("ts", StateInstalada))
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
				State:   StateInstalada,
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
	assert.Equal(t, StateInstalada, s2.Fichas["svc"].State)
}

// ── Concurrent access ───────────────────────────────────────

func TestConcurrentReads(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)
	seedFicha(t, m, "c", StateInstalada)

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
	require.NoError(t, m1.Transition("x", StateInstalando))
	require.NoError(t, m1.Close())

	m2, err := NewManager(path)
	require.NoError(t, err, "reopen after close should succeed")
	m2.Close()
}

// ── Transition creates ficha for Instalando ─────────────────

func TestTransition_AutoCreateForInstalando(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)

	err := m.Transition("new-app", StateInstalando)
	require.NoError(t, err)

	st, _ := m.Read()
	f, ok := st.Fichas["new-app"]
	require.True(t, ok)
	assert.Equal(t, StateInstalando, f.State)
}

func TestTransition_AutoCreateFailsForNonInstalando(t *testing.T) {
	path := tempStateFile(t)
	m := newTestManager(t, path)

	err := m.Transition("ghost", StateInstalada)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not found")
}

// ── Valid transitions map integrity ─────────────────────────

func TestValidTransitions_TodosEstablesDefinidos(t *testing.T) {
	// Todo estado estable (excepto DESINSTALADA que es final) debe tener transiciones.
	for _, from := range StableStates() {
		if from == StateDesinstalada {
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
