package screens_test

import (
	"strings"
	"testing"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/screens"
)

// newBootModel crea un modelo en estado de arranque progresivo (S08).
func newBootModel() tuimodel.Model {
	m := newPostInstallModel()
	m.CurrentScreen = tuimodel.ScreenBoot
	m.BootPct = 0.5
	m.BootMsg = "Iniciando Kubernetes..."
	return m
}

// ── S08 — RenderBoot ──────────────────────────────────────────────────────────

func TestScreen08_SinPanic_80x24(t *testing.T) {
	m := newBootModel()
	m.Width = 80
	m.Height = 24
	if out := screens.RenderBoot(m); out == "" {
		t.Fatal("RenderBoot 80×24: retornó vacío")
	}
}

func TestScreen08_SinPanic_120x40(t *testing.T) {
	m := newBootModel()
	if out := screens.RenderBoot(m); out == "" {
		t.Fatal("RenderBoot 120×40: retornó vacío")
	}
}

func TestScreen08_SinPanic_xs(t *testing.T) {
	m := newBootModel()
	m.Width = 50
	m.Height = 20
	if out := screens.RenderBoot(m); out == "" {
		t.Fatal("RenderBoot XS: retornó vacío")
	}
}

func TestScreen08_Paridad_GruposArranque(t *testing.T) {
	m := newBootModel()
	out := screens.RenderBoot(m)
	for _, grp := range []string{"Ubuntu", "Kubernetes", "Stack de datos", "Seguridad", "Daemons SBOS", "Context Plane"} {
		if !strings.Contains(out, grp) {
			t.Errorf("RenderBoot: falta grupo %q", grp)
		}
	}
}

func TestScreen08_Paridad_Progreso50(t *testing.T) {
	m := newBootModel()
	m.BootPct = 0.5
	out := screens.RenderBoot(m)
	if !strings.Contains(out, "Ubuntu") {
		t.Error("RenderBoot 50%: falta 'Ubuntu'")
	}
}

func TestScreen08_Progreso100_SistemaListo(t *testing.T) {
	m := newBootModel()
	m.BootPct = 1.0
	out := screens.RenderBoot(m)
	if !strings.Contains(out, "listo") {
		t.Error("RenderBoot 100%: falta mensaje 'listo'")
	}
}

func TestScreen08_SidePanelPresente_Normal(t *testing.T) {
	m := newBootModel()
	m.Width = 120
	out := screens.RenderBoot(m)
	if !strings.Contains(out, "Arranque SBOS") {
		t.Error("RenderBoot ancho 120: falta panel lateral 'Arranque SBOS'")
	}
}

func TestScreen08_SinSidePanel_xs(t *testing.T) {
	m := newBootModel()
	m.Width = 60
	out := screens.RenderBoot(m)
	if !strings.Contains(out, "Ubuntu") {
		t.Error("RenderBoot XS: falta 'Ubuntu' en secuencia principal")
	}
}

func TestScreen08_BootMsg_Aparece(t *testing.T) {
	m := newBootModel()
	m.Width = 120
	m.BootMsg = "Cargando servicios de red..."
	out := screens.RenderBoot(m)
	if !strings.Contains(out, "Cargando") {
		t.Error("RenderBoot: BootMsg no aparece en el panel lateral")
	}
}

func TestScreen08_BootMsg_Default_SinMsg(t *testing.T) {
	m := newBootModel()
	m.Width = 120
	m.BootMsg = ""
	out := screens.RenderBoot(m)
	if !strings.Contains(out, "Iniciando") {
		t.Error("RenderBoot BootMsg='': debe mostrar mensaje por defecto")
	}
}

func TestScreen08_Elapsed_Presente(t *testing.T) {
	m := newBootModel()
	m.Width = 120
	out := screens.RenderBoot(m)
	if !strings.Contains(out, "Elapsed") {
		t.Error("RenderBoot: falta 'Elapsed' en panel lateral")
	}
}

func TestScreen08_TenantName_Aparece(t *testing.T) {
	m := newBootModel()
	m.Width = 120
	out := screens.RenderBoot(m)
	if !strings.Contains(out, "Empresa Demo") {
		t.Error("RenderBoot: falta nombre del tenant 'Empresa Demo'")
	}
}

// ── Race ──────────────────────────────────────────────────────────────────────

func TestPostInstall_Race(t *testing.T) {
	renders := []struct {
		name string
		fn   func(tuimodel.Model) string
		sc   tuimodel.Screen
	}{
		{"S06", screens.RenderInstallDone, tuimodel.ScreenInstallDone},
		{"S07", screens.RenderReboot, tuimodel.ScreenReboot},
		{"S08", screens.RenderBoot, tuimodel.ScreenBoot},
	}
	for _, r := range renders {
		r := r
		t.Run(r.name, func(t *testing.T) {
			m := newPostInstallModel()
			m.CurrentScreen = r.sc
			switch r.sc {
			case tuimodel.ScreenReboot:
				m.CountdownSec = 5
			case tuimodel.ScreenBoot:
				m.BootPct = 0.6
				m.BootMsg = "Test arranque"
			}
			for i := 0; i < 10; i++ {
				t.Run("", func(t *testing.T) {
					t.Parallel()
					if out := r.fn(m); out == "" {
						t.Error("output vacío")
					}
				})
			}
		})
	}
}
