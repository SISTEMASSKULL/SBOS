package screens_test

import (
	"testing"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/screens"
)

// TestScreens_TodasRegistradasEnDispatcher verifica que cada constante Screen
// gestionada por screens.Render() produzca output no vacío.
//
// NOTA: ScreenDashboard y ScreenLogs NO se incluyen aquí porque no pasan por
// screens.Render() — son interceptados en app/app.go:View() y despachados a
// ctrl.Render(m.Ctrl) directamente (SCREEN-005, Paso 0.5).
//
// Al agregar pantallas nuevas en screens/, insertar aquí (POLICY.md §6 paso 3).
func TestScreens_TodasRegistradasEnDispatcher(t *testing.T) {
	cfg := tuimodel.Config{DemoMode: true}
	base := tuimodel.New(cfg, tuimodel.SeedData{})
	base.Width = 80
	base.Height = 24

	knownScreens := []struct {
		name   string
		screen tuimodel.Screen
	}{
		{"ScreenWelcome", tuimodel.ScreenWelcome},
		{"ScreenGoodbye", tuimodel.ScreenGoodbye},
		{"ScreenWizardP1", tuimodel.ScreenWizardP1},
		{"ScreenWizardP2", tuimodel.ScreenWizardP2},
		{"ScreenWizardP3", tuimodel.ScreenWizardP3},
		{"ScreenWizardCapacity", tuimodel.ScreenWizardCapacity},
		{"ScreenWizardP4", tuimodel.ScreenWizardP4},
		{"ScreenInstalling", tuimodel.ScreenInstalling},
		{"ScreenInstallLog", tuimodel.ScreenInstallLog},
		{"ScreenInstallErr", tuimodel.ScreenInstallErr},
		{"ScreenInstallDone", tuimodel.ScreenInstallDone},
		{"ScreenReboot", tuimodel.ScreenReboot},
		{"ScreenBoot", tuimodel.ScreenBoot},
		{"ScreenShutdown", tuimodel.ScreenShutdown},
		{"ScreenAuthLogin", tuimodel.ScreenAuthLogin},
		{"ScreenAuthConfirm", tuimodel.ScreenAuthConfirm},
		// ScreenDashboard → ctrl.Render() en app/app.go (no pasa por screens.Render)
		// ScreenLogs      → panel logs en ctrl/ (no pasa por screens.Render)
		// ── Al agregar pantallas nuevas en screens/, insertar aquí ──
	}

	for _, tc := range knownScreens {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			m := *base
			m.CurrentScreen = tc.screen
			out := screens.Render(m)
			if out == "" {
				t.Errorf("%s: Render() devolvió '' — falta en dispatcher.go o render retorna vacío", tc.name)
			}
		})
	}
}
