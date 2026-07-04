// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package screens implementa la función View de cada pantalla del instalador
// como una función pura que recibe [model.Model] y devuelve string.
//
// # Responsabilidades
//
// Renderizar cada una de las 15 pantallas del TUI a partir del estado del modelo,
// sin modificarlo. Cada pantalla vive en su propio archivo:
//
//   - welcome.go     — P0  ScreenWelcome (splash inicial con progreso de arranque)
//   - wizard_p1.go   — P1  ScreenWizardP1 (bienvenida: botones Comenzar/Salir)
//   - wizard_p2.go   — P2  ScreenWizardP2 (datos empresa: tenantInputs × 4)
//   - wizard_p3.go   — P3  ScreenWizardP3 (cuenta admin: adminInputs × 4 + MFA toggle)
//   - wizard_p4.go   — P4  ScreenWizardP4 (confirmación: resumen + botones)
//   - installing.go  — P5  ScreenInstalling (3 columnas: árbol/pasos/log en vivo)
//   - install_log.go — P5B ScreenInstallLog (log completo fullscreen)
//   - install_err.go — P5C ScreenInstallErr (panel de error con menú lateral)
//   - done.go        — P6  ScreenInstallDone (instalación completada, 4 secciones)
//   - reboot.go      — P7  ScreenReboot (cuenta regresiva pre-reinicio)
//   - boot.go        — P8  ScreenBoot (progreso de arranque del sistema)
//   - dashboard.go   — P9  ScreenDashboard (dashboard permanente post-instalación)
//   - logs.go        — P10 ScreenLogs (logs puros con filtro por nivel y fuente)
//   - shutdown.go    — P11 ScreenShutdown (progreso de apagado/reinicio)
//   - goodbye.go     — P12 ScreenGoodbye (splash de cierre)
//
// El dispatcher principal [Render](m model.Model) delega a la función
// correspondiente según m.CurrentScreen.
//
// # Fuera de alcance
//
// No modifica el modelo — las funciones de View son puras. No envía comandos
// BubbleTea. No define estilos — los importa de [styles]. No tiene lógica de
// negocio — solo transforma estado en string renderizado.
//
// # Dependencias
//
// internal/tui/model:  tipo [Model] y enum [Screen]
// internal/tui/styles: todos los estilos lipgloss
//
// Dependencias externas: github.com/charmbracelet/lipgloss (render),
// github.com/mattn/go-runewidth (truncado por ancho de display).
//
// # Callers principales
//
// internal/tui/model: el método View() del modelo llama [screens.Render].
// cmd/bosctl/install_ui.go: usa la función View() del modelo monolítico hasta F3.
//
// # Estándares y referencias
//
// BOS-REPAIR-03 F3.8 — screens/: 15 pantallas en sub-átomos A/B/C/D/E.
// TEA invariante: View(model) → string es función pura, sin estado mutable.
// POLICY.md §3 — proceso de modificación de pantallas existentes.
// install_ui.go L2000+ — implementaciones actuales de cada View (referencia hasta F3).
//
// # Ejemplo de uso
//
//	// Dispatcher en model/model.go:
//	func (m Model) View() string {
//	    return screens.Render(m)
//	}
//
//	// En screens/dispatcher.go:
//	func Render(m model.Model) string {
//	    switch m.CurrentScreen {
//	    case model.ScreenWelcome:
//	        return RenderWelcome(m)
//	    case model.ScreenInstalling:
//	        return RenderInstalling(m)
//	    // ...
//	    }
//	    return ""
//	}
package screens
