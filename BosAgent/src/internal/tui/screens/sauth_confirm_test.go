package screens_test

import (
	"strings"
	"testing"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/screens"
)

func newAuthConfirmModel() tuimodel.Model {
	cfg := tuimodel.Config{DemoMode: true}
	m := tuimodel.New(cfg, tuimodel.SeedData{})
	m.Width = 80
	m.Height = 24
	m.CurrentScreen = tuimodel.ScreenAuthConfirm
	m.AuthConfirmAction = "Apagar servidor"
	return *m
}

// TestRenderAuthConfirm_TituloVisible verifica que el título de confirmación esté presente.
func TestRenderAuthConfirm_TituloVisible(t *testing.T) {
	m := newAuthConfirmModel()
	out := screens.RenderAuthConfirm(m)
	if !strings.Contains(out, "Confirmar") {
		t.Errorf("esperaba 'Confirmar' en el output, got: %q", out[:min(out, 200)])
	}
}

// TestRenderAuthConfirm_CampoContrasena verifica que el campo de contraseña sea visible con form.
func TestRenderAuthConfirm_CampoContrasena(t *testing.T) {
	m := newAuthConfirmModel()
	f := tuimodel.NewAuthConfirmForm(&m)
	f.Init()
	m.AuthConfirmForm = f
	out := screens.RenderAuthConfirm(m)
	if !strings.Contains(out, "Contraseña") {
		t.Errorf("esperaba campo 'Contraseña' en el output, got: %q", out[:min(out, 300)])
	}
}

// TestRenderAuthConfirm_SkipSiLoA3 verifica que con LoA >= 3 se muestre acceso confirmado.
func TestRenderAuthConfirm_SkipSiLoA3(t *testing.T) {
	m := newAuthConfirmModel()
	m.AuthLoA = 3
	out := screens.RenderAuthConfirm(m)
	// Debe mostrar mensaje de acceso confirmado, no el formulario de contraseña
	if !strings.Contains(out, "✓") && !strings.Contains(out, "autorizada") {
		t.Errorf("esperaba indicador de acceso confirmado con LoA=3, got: %q", out[:min(out, 200)])
	}
	// No debe pedir contraseña
	if strings.Contains(out, "Contraseña / PIN") {
		t.Error("no debería mostrar campo contraseña cuando LoA >= 3")
	}
}

// TestRenderAuthConfirm_MuestraError verifica que m.AuthErr sea visible.
func TestRenderAuthConfirm_MuestraError(t *testing.T) {
	m := newAuthConfirmModel()
	m.AuthErr = "PIN incorrecto"
	out := screens.RenderAuthConfirm(m)
	if !strings.Contains(out, "PIN incorrecto") {
		t.Errorf("esperaba 'PIN incorrecto' en el output, got: %q", out[:min(out, 200)])
	}
}

// TestRenderAuthConfirm_NoPanic verifica que la función no panique en ninguna variante.
func TestRenderAuthConfirm_NoPanic(t *testing.T) {
	tests := []struct {
		name  string
		setup func(*tuimodel.Model)
	}{
		{"form nil loa 0", func(m *tuimodel.Model) {}},
		{"con form loa 0", func(m *tuimodel.Model) {
			f := tuimodel.NewAuthConfirmForm(m)
			f.Init()
			m.AuthConfirmForm = f
		}},
		{"loa 3 skip", func(m *tuimodel.Model) { m.AuthLoA = 3 }},
		{"loa 3 con form", func(m *tuimodel.Model) {
			m.AuthLoA = 3
			f := tuimodel.NewAuthConfirmForm(m)
			f.Init()
			m.AuthConfirmForm = f
		}},
		{"error y form", func(m *tuimodel.Model) {
			f := tuimodel.NewAuthConfirmForm(m)
			f.Init()
			m.AuthConfirmForm = f
			m.AuthErr = "Acceso denegado"
		}},
	}
	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			m := newAuthConfirmModel()
			tc.setup(&m)
			defer func() {
				if r := recover(); r != nil {
					t.Errorf("RenderAuthConfirm() paniqueó: %v", r)
				}
			}()
			screens.RenderAuthConfirm(m)
		})
	}
}

