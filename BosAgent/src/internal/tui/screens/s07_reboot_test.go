package screens_test

import (
	"strings"
	"testing"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/screens"
)

// newRebootModel crea un modelo en estado de countdown de reinicio (S07).
func newRebootModel() tuimodel.Model {
	m := newPostInstallModel()
	m.CurrentScreen = tuimodel.ScreenReboot
	m.CountdownSec = 5
	return m
}

// ── S07 — RenderReboot ────────────────────────────────────────────────────────

func TestScreen07_SinPanic_80x24(t *testing.T) {
	m := newRebootModel()
	m.Width = 80
	m.Height = 24
	if out := screens.RenderReboot(m); out == "" {
		t.Fatal("RenderReboot 80×24: retornó vacío")
	}
}

func TestScreen07_SinPanic_120x40(t *testing.T) {
	m := newRebootModel()
	if out := screens.RenderReboot(m); out == "" {
		t.Fatal("RenderReboot 120×40: retornó vacío")
	}
}

func TestScreen07_SinPanic_xs(t *testing.T) {
	m := newRebootModel()
	m.Width = 50
	m.Height = 20
	if out := screens.RenderReboot(m); out == "" {
		t.Fatal("RenderReboot XS: retornó vacío")
	}
}

func TestScreen07_Paridad_countdown(t *testing.T) {
	m := newRebootModel()
	m.CountdownSec = 7
	out := screens.RenderReboot(m)
	if !strings.Contains(out, "7") {
		t.Error("RenderReboot countdown=7: no muestra '7'")
	}
	if !strings.Contains(out, "Reiniciando") {
		t.Error("RenderReboot: falta 'Reiniciando'")
	}
}

func TestScreen07_Paridad_barraProgreso(t *testing.T) {
	m := newRebootModel()
	out := screens.RenderReboot(m)
	if !strings.Contains(out, "█") && !strings.Contains(out, "░") {
		t.Error("RenderReboot: falta barra de progreso (█ / ░)")
	}
}

func TestScreen07_Logs_Aparecen_Con_Countdown_Bajo(t *testing.T) {
	m := newRebootModel()
	m.CountdownSec = 3
	out := screens.RenderReboot(m)
	if !strings.Contains(out, "Sincronizando") && !strings.Contains(out, "Log guardado") {
		t.Error("RenderReboot countdown=3: falta log de sincronización")
	}
}

func TestScreen07_Logs_NoAparecen_Con_Countdown_Alto(t *testing.T) {
	m := newRebootModel()
	m.CountdownSec = 10
	out := screens.RenderReboot(m)
	if strings.Contains(out, "Guardando configuración") {
		t.Error("RenderReboot countdown=10: log de configuración no debe aparecer aún")
	}
}

func TestScreen07_CTA_Presente(t *testing.T) {
	m := newRebootModel()
	out := screens.RenderReboot(m)
	if !strings.Contains(out, "Enter") {
		t.Error("RenderReboot: falta hint '[Enter] reiniciar ahora'")
	}
}

func TestScreen07_BarraLlenaCuandoCountdownCero(t *testing.T) {
	m := newRebootModel()
	m.CountdownSec = 0
	out := screens.RenderReboot(m)
	barFilled := strings.Count(out, "█")
	if barFilled < 5 {
		t.Errorf("RenderReboot countdown=0: barra debe estar llena, solo %d █", barFilled)
	}
}
