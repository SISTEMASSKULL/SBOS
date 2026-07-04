package screens_test

import (
	"strings"
	"testing"
	"time"

	"bos/internal/tui/screens"
)

// ── S99 — RenderGoodbye ───────────────────────────────────────────────────

func TestScreen99_RenderSinPanic_80x24(t *testing.T) {
	m := newModelAt(80, 24)
	out := screens.RenderGoodbye(m)
	if out == "" {
		t.Fatal("RenderGoodbye 80×24 retornó cadena vacía")
	}
}

func TestScreen99_RenderSinPanic_120x40(t *testing.T) {
	m := newModelAt(120, 40)
	out := screens.RenderGoodbye(m)
	if out == "" {
		t.Fatal("RenderGoodbye 120×40 retornó cadena vacía")
	}
}

func TestScreen99_RenderSinPanic_ancho_cero(t *testing.T) {
	m := newModelAt(0, 0)
	out := screens.RenderGoodbye(m)
	if out == "" {
		t.Fatal("RenderGoodbye ancho=0 retornó cadena vacía")
	}
}

func TestScreen99_Paridad_contenido_clave(t *testing.T) {
	m := newModelAt(80, 24)
	out := screens.RenderGoodbye(m)

	claves := []string{
		"G O O D  B Y E",
		"S K U L L",
		"Tenant",
		"Sesión",
		"Duración",
		"Fichas activas",
		"Apagado",
		"© 2026 SKULL",
		"Ed25519",
	}
	for _, clave := range claves {
		if !strings.Contains(out, clave) {
			t.Errorf("RenderGoodbye: falta %q en el output", clave)
		}
	}
}

func TestScreen99_Paridad_fichas_OK(t *testing.T) {
	m := newModelAt(80, 24)
	m.FichasOK = 18
	m.FichasTotal = 22
	out := screens.RenderGoodbye(m)
	if !strings.Contains(out, "18 / 22 OK") {
		t.Error("RenderGoodbye: fichas OK no aparece correctamente")
	}
}

func TestScreen99_Paridad_fichas_default(t *testing.T) {
	m := newModelAt(80, 24)
	m.FichasTotal = 0
	m.FichasOK = 0
	out := screens.RenderGoodbye(m)
	if !strings.Contains(out, "22 / 22 OK") {
		t.Error("RenderGoodbye: fichas default '22 / 22 OK' no aparece con FichasTotal=0")
	}
}

func TestScreen99_Paridad_duracion_sesion(t *testing.T) {
	m := newModelAt(80, 24)
	now := time.Date(2026, 6, 11, 10, 30, 0, 0, time.UTC)
	m.StartTime = now.Add(-3 * time.Minute)
	out := screens.RenderGoodbye(m)
	if !strings.Contains(out, "Duración") {
		t.Error("RenderGoodbye: campo Duración no aparece")
	}
}

func TestS99_Race_Goodbye(t *testing.T) {
	m := newModelAt(80, 24)
	for i := 0; i < 20; i++ {
		t.Run("", func(t *testing.T) {
			t.Parallel()
			out := screens.RenderGoodbye(m)
			if out == "" {
				t.Error("output vacío")
			}
		})
	}
}
