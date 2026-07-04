// Package screens — shared.go: componentes compartidos por múltiples pantallas.
// RenderHeader, RenderFooter, RenderStepper, RenderMenu, Mode, WrapWithMargin.
// Migrado de cmd/bosctl/install_ui_impl.go en F3.13 (BOS-REPAIR).
package screens



import (
	"strings"
	"time"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/lipgloss"
)

// WrapWithMargin añade márgenes laterales simétricos y líneas en blanco alrededor del contenido.
// termW es el ancho total del terminal; el margen es styles.MarginW(termW) con clamp.
// Usa lipgloss.PaddingLeft para respetar códigos ANSI y mantener simetría izq/der.
func WrapWithMargin(content string, termW int) string {
	col := styles.MarginW(termW)
	if col == 0 {
		return "\n\n" + content + "\n\n"
	}
	padded := lipgloss.NewStyle().PaddingLeft(col).Render(content)
	return "\n\n" + padded + "\n\n"
}

// MenuItem representa una opción navegable de menú con etiqueta y descripción.
type MenuItem struct {
	Label string
	Desc  string
}

// RenderMenu renderiza un menú vertical navegable con cursor visible.
// El cursor (›) apunta a la opción activa con fondo oscuro.
func RenderMenu(items []MenuItem, focus int, width int) string {
	sDesc := styles.Muted.PaddingLeft(6)

	var rows []string
	for i, item := range items {
		if i == focus {
			rows = append(rows, styles.IconCursor+" "+styles.WizardMenuActive.Render(item.Label))
			if item.Desc != "" {
				rows = append(rows, sDesc.Render(item.Desc))
			}
		} else {
			rows = append(rows, styles.Muted.PaddingLeft(4).Render("   "+item.Label))
		}
		rows = append(rows, "")
	}
	hint := styles.Dim.Render("  ↑↓ · Tab  navegar    Enter  seleccionar")
	rows = append(rows, hint)
	return strings.Join(rows, "\n")
}

// RenderStepper renderiza el stepper de 5 pasos del wizard de instalación.
// Solo se muestra cuando la pantalla está entre P1 (WizardP1) y P5 (Installing).
func RenderStepper(m tuimodel.Model) string {
	if m.CurrentScreen < tuimodel.ScreenWizardP1 || m.CurrentScreen > tuimodel.ScreenInstalling {
		return ""
	}
	steps := []struct {
		name string
		sc   tuimodel.Screen
	}{
		{"Bienvenida", tuimodel.ScreenWizardP1},
		{"Empresa", tuimodel.ScreenWizardP2},
		{"Admin", tuimodel.ScreenWizardP3},
		{"Confirmar", tuimodel.ScreenWizardP4},
		{"Instalando", tuimodel.ScreenInstalling},
	}
	parts := make([]string, len(steps))
	for i, s := range steps {
		var icon, tx string
		switch {
		case m.CurrentScreen > s.sc:
			icon = styles.Tint(styles.IconOK, styles.ColorStateOKFg)
			tx = styles.Dim.Render(" " + s.name)
		case m.CurrentScreen == s.sc:
			icon = m.Spinner.View()
			tx = styles.Cyan.Render(" " + s.name)
		default:
			icon = styles.Inactive.Render("·")
			tx = styles.Inactive.Render(" " + s.name)
		}
		parts[i] = icon + tx
	}
	sep := styles.Inactive.Render(" — ")
	return styles.CellCenter(m.Width, strings.Join(parts, sep))
}

// RenderHeader renderiza la barra superior, el stepper opcional y el título de pantalla.
// Termina con una línea separadora ─────.
func RenderHeader(m tuimodel.Model) string {
	titles := map[tuimodel.Screen]string{
		tuimodel.ScreenWelcome:     "",
		tuimodel.ScreenWizardP1:    "Bienvenida",
		tuimodel.ScreenWizardP2:    "Datos de la Empresa",
		tuimodel.ScreenWizardP3:      "Cuenta de Administrador",
		tuimodel.ScreenWizardCapacity: "Estimados de Capacidad",
		tuimodel.ScreenWizardP4:       "Confirmar instalación",
		tuimodel.ScreenInstalling:  "Instalando SBOS...",
		tuimodel.ScreenInstallLog:  "Log completo",
		tuimodel.ScreenInstallErr:  "Error de instalación",
		tuimodel.ScreenInstallDone: "Instalación completada ✓",
		tuimodel.ScreenReboot:      "Reiniciando sistema...",
		tuimodel.ScreenBoot:        "Iniciando SBOS",
		tuimodel.ScreenDashboard:   "Dashboard bos",
		tuimodel.ScreenLogs:        "Logs del sistema",
		tuimodel.ScreenShutdown:    "Apagando SBOS",
		tuimodel.ScreenGoodbye:     "",
	}
	brand := "SBOS — Sistema Operativo Empresarial Soberano"
	if m.Width < 60 {
		brand = "SBOS"
	} else if m.Width < 80 {
		brand = "SBOS Instalador"
	}

	topBarStyle := styles.TopBar.Width(m.Width - 2) // Padding(0,1) = 2 chars overhead
	if m.CurrentScreen == tuimodel.ScreenShutdown {
		if m.ShutdownMode == "restart" {
			topBarStyle = styles.TopBarRestart.Width(m.Width - 2)
		} else {
			topBarStyle = styles.TopBarCritical.Width(m.Width - 2)
		}
	} else if m.CurrentScreen == tuimodel.ScreenGoodbye {
		topBarStyle = styles.TopBarGoodbye.Width(m.Width - 2)
	}

	var bar string
	if m.CurrentScreen == tuimodel.ScreenDashboard {
		clock := time.Now().Format("15:04:05")
		right := styles.Tint(styles.IconDotActive, styles.ColorAccentText) + " " +
			styles.BosActivo.Render("bos activo") +
			"  " + styles.Muted.Render(clock)
		leftW := m.Width - styles.TextWidth(right) - 2
		if leftW < 0 {
			leftW = 0
		}
		barContent := styles.Cell(leftW, brand) + right
		bar = topBarStyle.Render(barContent)
	} else {
		bar = topBarStyle.Render(brand)
	}

	stepper := RenderStepper(m)
	title := styles.Title.Width(m.Width).Render(titles[m.CurrentScreen])
	sep := styles.Dim.Render(strings.Repeat("─", m.Width))

	parts := []string{bar}
	if stepper != "" {
		parts = append(parts, stepper)
	}
	if titles[m.CurrentScreen] != "" {
		parts = append(parts, title)
	}
	parts = append(parts, sep)
	return styles.JoinV(styles.PosLeft, parts...)
}

// screenKeyMap implementa help.KeyMap para un conjunto variable de teclas por pantalla.
type screenKeyMap []key.Binding

func (km screenKeyMap) ShortHelp() []key.Binding  { return km }
func (km screenKeyMap) FullHelp() [][]key.Binding { return [][]key.Binding{km} }

// RenderFooter renderiza el footer de ayuda de teclas para la pantalla actual.
func RenderFooter(m tuimodel.Model) string {
	var keys screenKeyMap
	switch m.CurrentScreen {
	case tuimodel.ScreenWizardP1:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("up", "down"), key.WithHelp("↑↓", "navegar")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "seleccionar")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "salir")),
		}
	case tuimodel.ScreenWizardP2:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("tab", "up", "down"), key.WithHelp("tab/↑↓", "campo sig")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "continuar")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "volver")),
		}
	case tuimodel.ScreenWizardP3:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("tab", "up", "down"), key.WithHelp("tab/↑↓", "campo sig")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "continuar")),
			key.NewBinding(key.WithKeys("m"), key.WithHelp("M", "toggle MFA")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "volver")),
		}
	case tuimodel.ScreenWizardP4:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("up", "down"), key.WithHelp("↑↓", "navegar")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "seleccionar")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "volver")),
		}
	case tuimodel.ScreenInstalling:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("tab"), key.WithHelp("tab", "panel")),
			key.NewBinding(key.WithKeys("up", "down"), key.WithHelp("↑↓", "scroll")),
			key.NewBinding(key.WithKeys("l"), key.WithHelp("L", "log")),
			key.NewBinding(key.WithKeys("e"), key.WithHelp("E", "error")),
			key.NewBinding(key.WithKeys("t"), key.WithHelp("T", "timestamp")),
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "cancelar")),
		}
	case tuimodel.ScreenInstallLog:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("up", "down"), key.WithHelp("↑↓", "scroll")),
			key.NewBinding(key.WithKeys("g"), key.WithHelp("G", "final")),
			key.NewBinding(key.WithKeys("l"), key.WithHelp("L", "volver")),
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "cancelar")),
		}
	case tuimodel.ScreenInstallErr:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("e"), key.WithHelp("E", "volver")),
			key.NewBinding(key.WithKeys("l"), key.WithHelp("L", "log")),
			key.NewBinding(key.WithKeys("r"), key.WithHelp("R", "reintentar")),
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "cancelar")),
		}
	case tuimodel.ScreenInstallDone:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("left", "right"), key.WithHelp("←→", "sección")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "continuar")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "salir")),
		}
	case tuimodel.ScreenReboot:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "reiniciar ahora")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "cancelar")),
		}
	case tuimodel.ScreenDashboard:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("l"), key.WithHelp("L", "logs")),
			key.NewBinding(key.WithKeys("r"), key.WithHelp("R", "restart")),
			key.NewBinding(key.WithKeys("s"), key.WithHelp("S", "shutdown")),
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "salir")),
		}
	case tuimodel.ScreenLogs:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("/"), key.WithHelp("/", "buscar")),
			key.NewBinding(key.WithKeys("g"), key.WithHelp("G", "final")),
			key.NewBinding(key.WithKeys("t"), key.WithHelp("T", "timestamp")),
			key.NewBinding(key.WithKeys("q"), key.WithHelp("Q", "volver")),
		}
	case tuimodel.ScreenShutdown:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "forzar (peligroso)")),
		}
	default:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "salir")),
		}
	}
	return styles.Footer.Width(m.Width - 2).Render(m.HelpModel.View(keys)) // Padding(0,1) = 2 chars overhead
}

// assembleScreen ensambla una pantalla completa: header + cuerpo + sep + footer.
// Aplica centrado vertical si m.BodyHeight > 0.
// WrapWithMargin se aplica UNA sola vez en app.View() — NO duplicarlo aquí.
func assembleScreen(m tuimodel.Model, body string) string {
	if m.BodyHeight > 0 && m.Width > 0 {
		h := styles.TextHeight(body)
		if h < m.BodyHeight {
			body = styles.Place(m.Width, m.BodyHeight,
				styles.PosCenter, styles.PosCenter, body)
		}
	}
	header := RenderHeader(m)
	sep := styles.Dim.Render(strings.Repeat("─", m.Width))
	footer := RenderFooter(m)
	bottom := styles.JoinV(styles.PosLeft, sep, footer)
	return styles.JoinV(styles.PosLeft, header, body, bottom)
}

