// Package model — types.go: enumeraciones del TUI del instalador bos.
// Extraído de cmd/bosctl/install_ui.go en F3.2 (BOS-REPAIR).
// Corrige P11: Screen estaba duplicado (step+screen en el modelo).
package model

import "fmt"

// Screen identifica la pantalla activa del TUI.
// Un único campo Model.CurrentScreen usa este tipo (corrige P11).
type Screen int

const (
	ScreenWelcome          Screen = iota // P0  — splash bienvenida
	ScreenWizardP1                       // P1  — bienvenida instalador
	ScreenWizardP2                       // P2  — datos empresa (tenant)
	ScreenWizardP3                       // P3  — cuenta admin
	ScreenWizardCapacity                 // P3B — estimados de capacidad (tenants, empresas, sucursales, usuarios)
	ScreenWizardP4                       // P4  — confirmar instalación
	ScreenInstalling                     // P5  — instalación en progreso
	ScreenInstallLog                // P5B — log completo
	ScreenInstallErr                // P5C — panel de error
	ScreenInstallDone               // P6  — instalación completada
	ScreenReboot                    // P7  — reinicio post-instalación
	ScreenBoot                      // P8  — arranque bos
	ScreenDashboard                 // P9  — dashboard permanente
	ScreenLogs                      // P10 — logs puros
	ScreenShutdown                  // P11 — apagado/reinicio
	ScreenAuthLogin                 // P12 — login antes del dashboard
	ScreenAuthConfirm               // P13 — step-up LoA 3 para acciones destructivas

	ScreenGoodbye // P14 — splash despedida
)

// String retorna el nombre legible de la pantalla — usado en tuilog.
func (s Screen) String() string {
	switch s {
	case ScreenWelcome:        return "Welcome"
	case ScreenWizardP1:       return "WizardP1"
	case ScreenWizardP2:       return "WizardP2"
	case ScreenWizardP3:       return "WizardP3"
	case ScreenWizardCapacity: return "WizardCapacity"
	case ScreenWizardP4:       return "WizardP4"
	case ScreenInstalling:     return "Installing"
	case ScreenInstallLog:     return "InstallLog"
	case ScreenInstallErr:     return "InstallErr"
	case ScreenInstallDone:    return "InstallDone"
	case ScreenReboot:         return "Reboot"
	case ScreenBoot:           return "Boot"
	case ScreenDashboard:      return "Dashboard"
	case ScreenLogs:           return "Logs"
	case ScreenShutdown:       return "Shutdown"
	case ScreenAuthLogin:      return "AuthLogin"
	case ScreenAuthConfirm:    return "AuthConfirm"
	case ScreenGoodbye:        return "Goodbye"
	default:                   return fmt.Sprintf("Screen(%d)", int(s))
	}
}

// StepID es un alias de Screen para el stepper del wizard (P1–P6).
type StepID = Screen

const (
	StepWelcome    = ScreenWizardP1
	StepTenant     = ScreenWizardP2
	StepAdmin      = ScreenWizardP3
	StepCapacity   = ScreenWizardCapacity
	StepConfirm    = ScreenWizardP4
	StepInstalling = ScreenInstalling
	StepComplete   = ScreenInstallDone
)

// StepStatus indica el estado de cada paso (step) dentro de una ficha.
type StepStatus int

const (
	StepPending StepStatus = iota
	StepActive
	StepDone
	StepFailed
	StepSkipped
)

// FichaStatus indica el estado de instalación de una ficha.
type FichaStatus int

const (
	FichaPending FichaStatus = iota
	FichaActive
	FichaDone
	FichaFailed
)

// LogLevel clasifica las entradas del log en vivo del TUI.
type LogLevel int

const (
	LogInfo LogLevel = iota
	LogOK
	LogStep
	LogError
	LogWarn
)
