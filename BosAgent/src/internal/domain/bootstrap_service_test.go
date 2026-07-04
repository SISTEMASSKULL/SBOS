package domain

import (
	"errors"
	"fmt"
	"testing"

	"bos/internal/state"
)

func newBootstrapSvc(st StatePort) *BootstrapService {
	return NewBootstrapService(st)
}

// ── Start ─────────────────────────────────────────────────────────

func TestBootstrapService_Start(t *testing.T) {
	t.Run("ok — modo default es unattended", func(t *testing.T) {
		result, err := newBootstrapSvc(okState()).Start("")
		if err != nil {
			t.Fatalf("error inesperado: %v", err)
		}
		if result.Mode != "unattended" {
			t.Errorf("Mode=%q, quería 'unattended'", result.Mode)
		}
		if result.BootstrapID == "" {
			t.Error("BootstrapID no debe ser vacío")
		}
		if len(result.BootstrapID) < 4 || result.BootstrapID[:3] != "bs-" {
			t.Errorf("BootstrapID=%q, debe empezar con 'bs-'", result.BootstrapID)
		}
	})

	t.Run("modo explícito se preserva", func(t *testing.T) {
		result, err := newBootstrapSvc(okState()).Start("interactive")
		if err != nil {
			t.Fatal(err)
		}
		if result.Mode != "interactive" {
			t.Errorf("Mode=%q, quería 'interactive'", result.Mode)
		}
	})

	t.Run("estado vacío — conteos son 0", func(t *testing.T) {
		result, err := newBootstrapSvc(okState()).Start("")
		if err != nil {
			t.Fatal(err)
		}
		if result.Total != 0 {
			t.Errorf("Total=%d, quería 0", result.Total)
		}
		if result.Completados != 0 {
			t.Errorf("Completados=%d, quería 0", result.Completados)
		}
	})

	t.Run("conteos reflejan el estado real", func(t *testing.T) {
		st := &mockState{
			readFn: func() (*state.SBOSState, error) {
				return stateWith(map[string]state.FichaState{
					"sbos-bootstrap-os": state.StateInstalada,
					"postgresql":        state.StateInstalada,
					"redis":             state.StateLista,
				}), nil
			},
		}
		result, err := newBootstrapSvc(st).Start("")
		if err != nil {
			t.Fatal(err)
		}
		if result.Total != 3 {
			t.Errorf("Total=%d, quería 3", result.Total)
		}
		if result.Completados != 2 {
			t.Errorf("Completados=%d, quería 2", result.Completados)
		}
	})

	t.Run("ficha INSTALANDO → ErrBootstrapInProgress", func(t *testing.T) {
		st := &mockState{
			readFn: func() (*state.SBOSState, error) {
				return stateWith(map[string]state.FichaState{
					"postgresql": state.StateInstalando,
				}), nil
			},
		}
		_, err := newBootstrapSvc(st).Start("")
		if err == nil {
			t.Fatal("esperaba error")
		}
		if !errors.Is(err, ErrBootstrapInProgress) {
			t.Errorf("error=%v, quería ErrBootstrapInProgress", err)
		}
		if !IsBootstrapInProgress(err) {
			t.Error("IsBootstrapInProgress debería ser true")
		}
	})

	t.Run("error de estado → ErrStateUnavailable", func(t *testing.T) {
		st := &mockState{readFn: func() (*state.SBOSState, error) { return nil, fmt.Errorf("disco lleno") }}
		_, err := newBootstrapSvc(st).Start("")
		if !errors.Is(err, ErrStateUnavailable) {
			t.Errorf("error=%v, quería ErrStateUnavailable", err)
		}
	})
}

// ── Verify ────────────────────────────────────────────────────────

func TestBootstrapService_Verify(t *testing.T) {
	t.Run("0/8 sin fichas registradas", func(t *testing.T) {
		result, err := newBootstrapSvc(okState()).Verify()
		if err != nil {
			t.Fatal(err)
		}
		if result.Total != 8 {
			t.Errorf("Total=%d, quería 8", result.Total)
		}
		if result.Passed != 0 {
			t.Errorf("Passed=%d, quería 0", result.Passed)
		}
		if result.Certified {
			t.Error("Certified debería ser false")
		}
		if len(result.Criterios) != 8 {
			t.Errorf("len(Criterios)=%d, quería 8", len(result.Criterios))
		}
	})

	t.Run("criterios tienen IDs C-01..C-08 en orden", func(t *testing.T) {
		result, _ := newBootstrapSvc(okState()).Verify()
		for i, c := range result.Criterios {
			want := fmt.Sprintf("C-0%d", i+1)
			if c.ID != want {
				t.Errorf("Criterios[%d].ID=%q, quería %q", i, c.ID, want)
			}
		}
	})

	t.Run("8/8 — todas INSTALADA_OK → Certified=true", func(t *testing.T) {
		fichas := map[string]state.FichaState{
			"sbos-bootstrap-os":  state.StateInstalada,
			"sbos-bootstrap-k8s": state.StateInstalada,
			"sbos-bootstrap-cni": state.StateInstalada,
			"postgresql":         state.StateInstalada,
			"redis":              state.StateInstalada,
			"vault":              state.StateInstalada,
			"keycloak":           state.StateInstalada,
			"kong":               state.StateInstalada,
		}
		st := &mockState{readFn: func() (*state.SBOSState, error) { return stateWith(fichas), nil }}
		result, err := newBootstrapSvc(st).Verify()
		if err != nil {
			t.Fatal(err)
		}
		if result.Passed != 8 {
			t.Errorf("Passed=%d, quería 8", result.Passed)
		}
		if !result.Certified {
			t.Error("Certified debería ser true")
		}
		for _, c := range result.Criterios {
			if !c.OK {
				t.Errorf("Criterio %s debería ser OK", c.ID)
			}
		}
	})

	t.Run("5/8 — vault/keycloak/kong pendientes", func(t *testing.T) {
		fichas := map[string]state.FichaState{
			"sbos-bootstrap-os":  state.StateInstalada,
			"sbos-bootstrap-k8s": state.StateInstalada,
			"sbos-bootstrap-cni": state.StateInstalada,
			"postgresql":         state.StateInstalada,
			"redis":              state.StateInstalada,
		}
		st := &mockState{readFn: func() (*state.SBOSState, error) { return stateWith(fichas), nil }}
		result, err := newBootstrapSvc(st).Verify()
		if err != nil {
			t.Fatal(err)
		}
		if result.Passed != 5 {
			t.Errorf("Passed=%d, quería 5", result.Passed)
		}
		if result.Certified {
			t.Error("Certified debería ser false")
		}
		// C-06 (vault) debe estar fallido y decir "no registrada"
		c06 := result.Criterios[5]
		if c06.ID != "C-06" {
			t.Errorf("Criterios[5].ID=%q, quería C-06", c06.ID)
		}
		if c06.OK {
			t.Error("C-06 debería ser false")
		}
		if !containsSubstr(c06.Detalle, "no registrada") {
			t.Errorf("Detalle=%q, debería contener 'no registrada'", c06.Detalle)
		}
	})

	t.Run("ficha DEGRADADA no certifica", func(t *testing.T) {
		fichas := map[string]state.FichaState{
			"sbos-bootstrap-os": state.StateDegradada,
		}
		st := &mockState{readFn: func() (*state.SBOSState, error) { return stateWith(fichas), nil }}
		result, _ := newBootstrapSvc(st).Verify()
		if result.Criterios[0].OK {
			t.Error("C-01 debería ser false cuando está DEGRADADA")
		}
		if !containsSubstr(result.Criterios[0].Detalle, "DEGRADADA") {
			t.Errorf("Detalle=%q debería mencionar 'DEGRADADA'", result.Criterios[0].Detalle)
		}
	})

	t.Run("Timestamp no es zero", func(t *testing.T) {
		result, _ := newBootstrapSvc(okState()).Verify()
		if result.Timestamp.IsZero() {
			t.Error("Timestamp no debe ser zero")
		}
	})

	t.Run("error de estado → ErrStateUnavailable", func(t *testing.T) {
		st := &mockState{readFn: func() (*state.SBOSState, error) { return nil, fmt.Errorf("roto") }}
		_, err := newBootstrapSvc(st).Verify()
		if !errors.Is(err, ErrStateUnavailable) {
			t.Errorf("error=%v", err)
		}
	})
}

// ── Status ────────────────────────────────────────────────────────

func TestBootstrapService_Status(t *testing.T) {
	t.Run("estado vacío — progress=0, total=0", func(t *testing.T) {
		result, err := newBootstrapSvc(okState()).Status()
		if err != nil {
			t.Fatal(err)
		}
		if result.Progress != 0.0 {
			t.Errorf("Progress=%v, quería 0", result.Progress)
		}
		if result.Total != 0 {
			t.Errorf("Total=%d, quería 0", result.Total)
		}
	})

	t.Run("progress = completados/total", func(t *testing.T) {
		fichas := map[string]state.FichaState{
			"a": state.StateInstalada,
			"b": state.StateInstalada,
			"c": state.StateLista,
			"d": state.StatePendiente,
		}
		st := &mockState{readFn: func() (*state.SBOSState, error) { return stateWith(fichas), nil }}
		result, err := newBootstrapSvc(st).Status()
		if err != nil {
			t.Fatal(err)
		}
		if result.Total != 4 {
			t.Errorf("Total=%d", result.Total)
		}
		if result.Completados != 2 {
			t.Errorf("Completados=%d", result.Completados)
		}
		// 0.499 < progress < 0.501
		if result.Progress < 0.499 || result.Progress > 0.501 {
			t.Errorf("Progress=%v, quería ~0.5", result.Progress)
		}
		if result.Pendientes != 1 {
			t.Errorf("Pendientes=%d", result.Pendientes)
		}
		if result.Bloqueadas != 1 {
			t.Errorf("Bloqueadas=%d", result.Bloqueadas)
		}
	})

	t.Run("conteo alerta e instalando", func(t *testing.T) {
		fichas := map[string]state.FichaState{
			"a": state.StateDegradada,
			"b": state.StateInstalando,
			"c": state.StateInstalada,
		}
		st := &mockState{readFn: func() (*state.SBOSState, error) { return stateWith(fichas), nil }}
		result, err := newBootstrapSvc(st).Status()
		if err != nil {
			t.Fatal(err)
		}
		if result.Alerta != 1 {
			t.Errorf("Alerta=%d, quería 1", result.Alerta)
		}
		if result.Instalando != 1 {
			t.Errorf("Instalando=%d, quería 1", result.Instalando)
		}
	})

	t.Run("error → ErrStateUnavailable", func(t *testing.T) {
		st := &mockState{readFn: func() (*state.SBOSState, error) { return nil, fmt.Errorf("io error") }}
		_, err := newBootstrapSvc(st).Status()
		if !errors.Is(err, ErrStateUnavailable) {
			t.Errorf("error=%v", err)
		}
	})
}

// ── Resume ────────────────────────────────────────────────────────

func TestBootstrapService_Resume(t *testing.T) {
	t.Run("delega a Status correctamente", func(t *testing.T) {
		fichas := map[string]state.FichaState{
			"postgresql": state.StateInstalada,
			"redis":      state.StateLista,
		}
		st := &mockState{readFn: func() (*state.SBOSState, error) { return stateWith(fichas), nil }}
		result, err := newBootstrapSvc(st).Resume()
		if err != nil {
			t.Fatal(err)
		}
		if result.Total != 2 {
			t.Errorf("Total=%d, quería 2", result.Total)
		}
		if result.Completados != 1 {
			t.Errorf("Completados=%d, quería 1", result.Completados)
		}
	})

	t.Run("error de estado → ErrStateUnavailable", func(t *testing.T) {
		st := &mockState{readFn: func() (*state.SBOSState, error) { return nil, fmt.Errorf("err") }}
		_, err := newBootstrapSvc(st).Resume()
		if !errors.Is(err, ErrStateUnavailable) {
			t.Errorf("error=%v", err)
		}
	})
}

// ── countByState ──────────────────────────────────────────────────

func TestCountByState(t *testing.T) {
	st := stateWith(map[string]state.FichaState{
		"a": state.StateInstalada,
		"b": state.StateInstalada,
		"c": state.StateInstalando,
		"d": state.StatePendiente,
	})
	checks := []struct {
		target state.FichaState
		want   int
	}{
		{state.StateInstalada, 2},
		{state.StateInstalando, 1},
		{state.StatePendiente, 1},
		{state.StateLista, 0},
	}
	for _, tc := range checks {
		got := countByState(st, tc.target)
		if got != tc.want {
			t.Errorf("countByState(%v)=%d, quería %d", tc.target, got, tc.want)
		}
	}
	if countByState(emptyState(), state.StateInstalada) != 0 {
		t.Error("countByState en estado vacío debería ser 0")
	}
}
