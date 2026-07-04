package screens_test

import (
	"strings"
	"testing"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/screens"
)

// newModelAt construye un Model mínimo con dimensiones fijas para tests de pantallas completas.
func newModelAt(w, h int) tuimodel.Model {
	cfg := tuimodel.Config{DemoMode: true}
	m := tuimodel.New(cfg, tuimodel.SeedData{})
	m.Width = w
	m.Height = h
	m.TermW = w
	return *m
}

// ── S00 — RenderWelcome ────────────────────────────────────────────────────

func TestScreen00_RenderSinPanic_80x24(t *testing.T) {
	m := newModelAt(80, 24)
	out := screens.RenderWelcome(m)
	if out == "" {
		t.Fatal("RenderWelcome 80×24 retornó cadena vacía")
	}
}

func TestScreen00_RenderSinPanic_120x40(t *testing.T) {
	m := newModelAt(120, 40)
	out := screens.RenderWelcome(m)
	if out == "" {
		t.Fatal("RenderWelcome 120×40 retornó cadena vacía")
	}
}

func TestScreen00_RenderSinPanic_ancho_cero(t *testing.T) {
	m := newModelAt(0, 0)
	out := screens.RenderWelcome(m)
	if out == "" {
		t.Fatal("RenderWelcome ancho=0 retornó cadena vacía")
	}
}

func TestScreen00_Paridad_contenido_clave(t *testing.T) {
	m := newModelAt(80, 24)
	out := screens.RenderWelcome(m)

	claves := []string{
		"S K U L L",
		"SBOS v1.0 GA",
		"SISTEMA OPERATIVO EMPRESARIAL SOBERANO",
		"skull-sksistemas",
		"© 2026 SKULL",
		"ISO 27001",
		"Ed25519",
	}
	for _, clave := range claves {
		if !strings.Contains(out, clave) {
			t.Errorf("RenderWelcome: falta %q en el output", clave)
		}
	}
}

func TestScreen00_Paridad_barra_boot(t *testing.T) {
	m := newModelAt(80, 24)
	m.BootPct = 0.5
	m.BootMsg = "Verificando Ubuntu"
	out := screens.RenderWelcome(m)
	if !strings.Contains(out, "Verificando") {
		t.Error("RenderWelcome: 'Verificando' de BootMsg no aparece en el output")
	}
	if !strings.Contains(out, "50%") {
		t.Error("RenderWelcome: porcentaje de boot no aparece")
	}
}

func TestScreen00_Paridad_tenant_personalizado(t *testing.T) {
	cfg := tuimodel.Config{DemoMode: true}
	m := tuimodel.New(cfg, tuimodel.SeedData{RazonSocial: "mi-empresa"})
	m.Width = 80
	m.Height = 24
	m.TenantName = "mi-empresa"
	out := screens.RenderWelcome(*m)
	if !strings.Contains(out, "mi-empresa") {
		t.Error("RenderWelcome: nombre de tenant personalizado no aparece")
	}
}

func TestS00_Race_Welcome(t *testing.T) {
	m := newModelAt(80, 24)
	for i := 0; i < 20; i++ {
		t.Run("", func(t *testing.T) {
			t.Parallel()
			out := screens.RenderWelcome(m)
			if out == "" {
				t.Error("output vacío")
			}
		})
	}
}
