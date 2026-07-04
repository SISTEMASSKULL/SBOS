package screens_test

import (
	"strings"
	"testing"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/screens"
)

func newShutdownModel() tuimodel.Model {
	cfg := tuimodel.Config{DemoMode: true}
	m := tuimodel.New(cfg, tuimodel.SeedData{})
	m.Width = 120
	m.Height = 40
	m.TermW = 120
	m.CurrentScreen = tuimodel.ScreenShutdown
	m.ShutdownMode = "shutdown"
	m.ShutdownPct = 0.4
	return *m
}

func TestScreen11_SinPanic_80x24(t *testing.T) {
	m := newShutdownModel()
	m.Width = 80
	m.Height = 24
	if out := screens.RenderShutdown(m); out == "" {
		t.Fatal("RenderShutdown 80×24: retornó vacío")
	}
}

func TestScreen11_SinPanic_120x40(t *testing.T) {
	m := newShutdownModel()
	if out := screens.RenderShutdown(m); out == "" {
		t.Fatal("RenderShutdown 120×40: retornó vacío")
	}
}

func TestScreen11_SinPanic_xs(t *testing.T) {
	m := newShutdownModel()
	m.Width = 50
	m.Height = 20
	if out := screens.RenderShutdown(m); out == "" {
		t.Fatal("RenderShutdown XS: retornó vacío")
	}
}

func TestScreen11_Paridad_SecuenciaApagado(t *testing.T) {
	m := newShutdownModel()
	out := screens.RenderShutdown(m)
	for _, grp := range []string{"Daemons SBOS", "Context Plane", "Seguridad", "Stack de datos", "Kubernetes", "Ubuntu"} {
		if !strings.Contains(out, grp) {
			t.Errorf("RenderShutdown: falta grupo %q en secuencia", grp)
		}
	}
}

func TestScreen11_ModoShutdown_Accion(t *testing.T) {
	m := newShutdownModel()
	m.Width = 120
	m.ShutdownMode = "shutdown"
	out := screens.RenderShutdown(m)
	if !strings.Contains(out, "Apagando") {
		t.Error("RenderShutdown mode=shutdown: falta 'Apagando'")
	}
}

func TestScreen11_ModoRestart_Accion(t *testing.T) {
	m := newShutdownModel()
	m.Width = 120
	m.ShutdownMode = "restart"
	out := screens.RenderShutdown(m)
	if !strings.Contains(out, "Reiniciando") {
		t.Error("RenderShutdown mode=restart: falta 'Reiniciando'")
	}
}

func TestScreen11_SidePanel_Presente(t *testing.T) {
	m := newShutdownModel()
	m.Width = 120
	out := screens.RenderShutdown(m)
	if !strings.Contains(out, "No interrumpir") {
		t.Error("RenderShutdown ancho≥70: falta 'No interrumpir' en side panel")
	}
}

func TestScreen11_SidePanel_Ausente_xs(t *testing.T) {
	m := newShutdownModel()
	m.Width = 60
	out := screens.RenderShutdown(m)
	if strings.Contains(out, "No interrumpir") {
		t.Error("RenderShutdown ancho<70: 'No interrumpir' no debe aparecer sin side panel")
	}
}

func TestScreen11_Progreso_Barra(t *testing.T) {
	m := newShutdownModel()
	m.Width = 120
	m.ShutdownPct = 0.5
	out := screens.RenderShutdown(m)
	if !strings.Contains(out, "█") {
		t.Error("RenderShutdown 50%: falta barra de progreso (█)")
	}
}

func TestScreen11_Progreso_100_TodosDone(t *testing.T) {
	m := newShutdownModel()
	m.Width = 120
	m.ShutdownPct = 1.0
	out := screens.RenderShutdown(m)
	if !strings.Contains(out, "✓") {
		t.Error("RenderShutdown 100%: falta ✓ de grupo completado")
	}
	if !strings.Contains(out, "100%") {
		t.Error("RenderShutdown 100%: falta '100%' en barra")
	}
}

func TestScreen11_Advertencia_CtrlC(t *testing.T) {
	m := newShutdownModel()
	m.Width = 120
	out := screens.RenderShutdown(m)
	if !strings.Contains(out, "Ctrl+C") {
		t.Error("RenderShutdown: falta advertencia 'Ctrl+C' en side panel")
	}
}

func TestScreen11_Race(t *testing.T) {
	m := newShutdownModel()
	for i := 0; i < 10; i++ {
		t.Run("", func(t *testing.T) {
			t.Parallel()
			if out := screens.RenderShutdown(m); out == "" {
				t.Error("output vacío")
			}
		})
	}
}
