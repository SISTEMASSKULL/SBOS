// Package screens — dispatcher.go: función Render principal del TUI.
// Extraído de cmd/bosctl/install_ui.go en F3.8 (BOS-REPAIR).
package screens

import (
	tuimodel "bos/internal/tui/model"
)

// Render despacha la pantalla correcta según m.CurrentScreen.
// Función pura: recibe Model, devuelve string, no modifica estado.
func Render(m tuimodel.Model) string {
	if m.Width == 0 {
		return "Iniciando SBOS..."
	}
	switch m.CurrentScreen {
	case tuimodel.ScreenWelcome:
		return RenderWelcome(m)
	case tuimodel.ScreenGoodbye:
		return RenderGoodbye(m)
	case tuimodel.ScreenWizardP1:
		return RenderWizardP1(m)
	case tuimodel.ScreenWizardP2:
		return RenderWizardP2(m)
	case tuimodel.ScreenWizardP3:
		return RenderWizardP3(m)
	case tuimodel.ScreenWizardCapacity:
		return RenderWizardCapacity(m)
	case tuimodel.ScreenWizardP4:
		return RenderWizardP4(m)
	case tuimodel.ScreenInstalling:
		return RenderInstalling(m)
	case tuimodel.ScreenInstallLog:
		return RenderInstallLog(m)
	case tuimodel.ScreenInstallErr:
		return RenderInstallErr(m)
	case tuimodel.ScreenInstallDone:
		return RenderInstallDone(m)
	case tuimodel.ScreenReboot:
		return RenderReboot(m)
	case tuimodel.ScreenBoot:
		return RenderBoot(m)
	case tuimodel.ScreenShutdown:
		return RenderShutdown(m)
	case tuimodel.ScreenAuthLogin:
		return RenderAuthLogin(m)
	case tuimodel.ScreenAuthConfirm:
		return RenderAuthConfirm(m)
	}
	return ""
}
