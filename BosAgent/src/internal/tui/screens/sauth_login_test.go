package screens_test

import (
	"strings"
	"testing"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/screens"
)

func newAuthLoginModel() tuimodel.Model {
	cfg := tuimodel.Config{DemoMode: true}
	m := tuimodel.New(cfg, tuimodel.SeedData{})
	m.Width = 80
	m.Height = 24
	m.CurrentScreen = tuimodel.ScreenAuthLogin
	return *m
}

// TestRenderAuthLogin_SinForm verifica que la pantalla no panique cuando AuthForm es nil.
func TestRenderAuthLogin_SinForm(t *testing.T) {
	m := newAuthLoginModel()
	out := screens.RenderAuthLogin(m)
	if out == "" {
		t.Error("RenderAuthLogin() devolvió vacío sin form")
	}
}

// TestRenderAuthLogin_ConForm verifica que los campos Usuario y Contraseña sean visibles.
func TestRenderAuthLogin_ConForm(t *testing.T) {
	m := newAuthLoginModel()
	m.AuthForm = tuimodel.NewAuthLoginForm(&m)
	m.AuthForm.Init() // puebla el viewport interno del grupo; el tea.Cmd resultante se descarta
	out := screens.RenderAuthLogin(m)
	if out == "" {
		t.Fatal("RenderAuthLogin() devolvió vacío con form")
	}
	if !strings.Contains(out, "Usuario") {
		t.Error("esperaba campo 'Usuario' en el output")
	}
	if !strings.Contains(out, "Contraseña") {
		t.Error("esperaba campo 'Contraseña' en el output")
	}
}

// TestRenderAuthLogin_MuestraError verifica que m.AuthErr sea visible en el output.
func TestRenderAuthLogin_MuestraError(t *testing.T) {
	m := newAuthLoginModel()
	m.AuthErr = "Credenciales inválidas"
	out := screens.RenderAuthLogin(m)
	if !strings.Contains(out, "Credenciales inválidas") {
		t.Errorf("esperaba mensaje de error en el output, got: %q", out)
	}
}

// TestRenderAuthLogin_ErrorConForm verifica error visible cuando hay form activo.
func TestRenderAuthLogin_ErrorConForm(t *testing.T) {
	m := newAuthLoginModel()
	m.AuthForm = tuimodel.NewAuthLoginForm(&m)
	m.AuthForm.Init() // puebla el viewport interno del grupo
	m.AuthErr = "bauth no disponible"
	out := screens.RenderAuthLogin(m)
	if !strings.Contains(out, "bauth no disponible") {
		t.Errorf("esperaba 'bauth no disponible' en el output, got: %q", out)
	}
	if !strings.Contains(out, "Usuario") {
		t.Error("esperaba campo 'Usuario' junto al error")
	}
}

// TestRenderAuthLogin_NoPanic verifica que la función no panique en ninguna variante.
func TestRenderAuthLogin_NoPanic(t *testing.T) {
	tests := []struct {
		name  string
		setup func(*tuimodel.Model)
	}{
		{"form nil", func(m *tuimodel.Model) {}},
		{"con form", func(m *tuimodel.Model) { f := tuimodel.NewAuthLoginForm(m); f.Init(); m.AuthForm = f }},
		{"error largo", func(m *tuimodel.Model) { m.AuthErr = strings.Repeat("error ", 40) }},
		{"con form y error", func(m *tuimodel.Model) {
			f := tuimodel.NewAuthLoginForm(m)
			f.Init()
			m.AuthForm = f
			m.AuthErr = "Acceso denegado"
		}},
	}
	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			m := newAuthLoginModel()
			tc.setup(&m)
			defer func() {
				if r := recover(); r != nil {
					t.Errorf("RenderAuthLogin() paniqueó: %v", r)
				}
			}()
			screens.RenderAuthLogin(m)
		})
	}
}
