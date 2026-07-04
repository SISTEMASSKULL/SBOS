// Package model — keys.go: key bindings del TUI por pantalla.
// Extraído de cmd/bosctl/install_ui.go en F3.9 (BOS-REPAIR).
package model

import (
	"github.com/charmbracelet/bubbles/key"
	tea "github.com/charmbracelet/bubbletea"
)

// ── KeyMap structs declarativos (TUI-LIB-003) ─────────────────────────────────
// Cada struct implementa help.KeyMap y provee un Default* listo para usar.
// T-051 migrará los handlers existentes a key.Matches() usando estos defaults.

// WizardKeyMap cubre las pantallas P1–P4 y Capacity del wizard de instalación.
type WizardKeyMap struct {
	Next      key.Binding // Tab / ↓ — siguiente campo
	Prev      key.Binding // Shift+Tab / ↑ — campo anterior
	Confirm   key.Binding // Enter — confirmar / continuar
	Back      key.Binding // Esc — volver pantalla anterior
	ToggleMFA key.Binding // M — activar/desactivar MFA (P3 únicamente)
}

func (k WizardKeyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Next, k.Confirm, k.Back}
}
func (k WizardKeyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.Next, k.Prev},
		{k.Confirm, k.Back, k.ToggleMFA},
	}
}

// DefaultWizardKeyMap es el KeyMap canónico del wizard.
var DefaultWizardKeyMap = WizardKeyMap{
	Next:      key.NewBinding(key.WithKeys("tab", "down"), key.WithHelp("tab/↓", "siguiente")),
	Prev:      key.NewBinding(key.WithKeys("shift+tab", "up"), key.WithHelp("⇧tab/↑", "anterior")),
	Confirm:   key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "confirmar")),
	Back:      key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "volver")),
	ToggleMFA: key.NewBinding(key.WithKeys("m"), key.WithHelp("M", "toggle MFA")),
}

// InstallingKeyMap cubre ScreenInstalling, ScreenInstallLog y ScreenInstallErr.
type InstallingKeyMap struct {
	ViewLog         key.Binding // L — ver log completo (S05B)
	ViewError       key.Binding // E — ver panel de error (S05C)
	ToggleTimestamp key.Binding // T — mostrar/ocultar timestamp
	NextPanel       key.Binding // Tab — panel siguiente (A→B→C)
	PrevPanel       key.Binding // Shift+Tab — panel anterior
	ScrollUp        key.Binding // ↑/k/PgUp — desplazar arriba
	ScrollDown      key.Binding // ↓/j/PgDown — desplazar abajo
	ScrollTop       key.Binding // Home/g — ir al inicio
	ScrollBottom    key.Binding // End/G — ir al final (reactiva autoScroll)
	ScrollLeft      key.Binding // ← — desplazar izquierda (cols B/C)
	ScrollRight     key.Binding // → — desplazar derecha (cols B/C)
	Abort           key.Binding // Ctrl+C — cancelar instalación
}

func (k InstallingKeyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.ViewLog, k.ViewError, k.ScrollUp, k.ScrollDown, k.Abort}
}
func (k InstallingKeyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.ViewLog, k.ViewError, k.ToggleTimestamp},
		{k.NextPanel, k.PrevPanel},
		{k.ScrollUp, k.ScrollDown, k.ScrollTop, k.ScrollBottom},
		{k.Abort},
	}
}

// DefaultInstallingKeyMap es el KeyMap canónico de la pantalla de instalación.
var DefaultInstallingKeyMap = InstallingKeyMap{
	ViewLog:         key.NewBinding(key.WithKeys("l"), key.WithHelp("L", "ver log")),
	ViewError:       key.NewBinding(key.WithKeys("e"), key.WithHelp("E", "ver error")),
	ToggleTimestamp: key.NewBinding(key.WithKeys("t"), key.WithHelp("T", "timestamp")),
	NextPanel:       key.NewBinding(key.WithKeys("tab"), key.WithHelp("tab", "panel →")),
	PrevPanel:       key.NewBinding(key.WithKeys("shift+tab"), key.WithHelp("⇧tab", "panel ←")),
	ScrollUp:        key.NewBinding(key.WithKeys("up", "k", "pgup"), key.WithHelp("↑/k", "subir")),
	ScrollDown:      key.NewBinding(key.WithKeys("down", "j", "pgdown"), key.WithHelp("↓/j", "bajar")),
	ScrollTop:       key.NewBinding(key.WithKeys("home", "g"), key.WithHelp("g/Home", "inicio")),
	ScrollBottom:    key.NewBinding(key.WithKeys("end", "G"), key.WithHelp("G/End", "final")),
	ScrollLeft:      key.NewBinding(key.WithKeys("left"), key.WithHelp("←", "izquierda")),
	ScrollRight:     key.NewBinding(key.WithKeys("right"), key.WithHelp("→", "derecha")),
	Abort:           key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "cancelar")),
}

// DashboardKeyMap cubre ScreenDashboard.
// Restart y Shutdown comienzan deshabilitados y se activan según el LoA del usuario (T-060+).
type DashboardKeyMap struct {
	Up       key.Binding // ↑/k — navegar arriba
	Down     key.Binding // ↓/j — navegar abajo
	Enter    key.Binding // Enter — abrir / ejecutar
	Refresh  key.Binding // r — refrescar panel activo
	Logs     key.Binding // L — ir a pantalla de logs
	Restart  key.Binding // R — reiniciar sistema (requiere LoA ≥ 2)
	Shutdown key.Binding // S — apagar sistema (requiere LoA ≥ 3)
	Quit     key.Binding // Q / Ctrl+C — salir
}

func (k DashboardKeyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Up, k.Down, k.Enter, k.Logs, k.Quit}
}
func (k DashboardKeyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.Up, k.Down, k.Enter},
		{k.Refresh, k.Logs},
		{k.Restart, k.Shutdown},
		{k.Quit},
	}
}

// DefaultDashboardKeyMap es el KeyMap canónico del dashboard.
// Restart y Shutdown se habilitan vía SetEnabled cuando el LoA lo permite.
var DefaultDashboardKeyMap = DashboardKeyMap{
	Up:       key.NewBinding(key.WithKeys("up", "k"), key.WithHelp("↑/k", "arriba")),
	Down:     key.NewBinding(key.WithKeys("down", "j"), key.WithHelp("↓/j", "abajo")),
	Enter:    key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "abrir")),
	Refresh:  key.NewBinding(key.WithKeys("r"), key.WithHelp("r", "refrescar")),
	Logs:     key.NewBinding(key.WithKeys("l"), key.WithHelp("L", "logs")),
	Restart:  key.NewBinding(key.WithKeys("R"), key.WithHelp("R", "reiniciar"), key.WithDisabled()),
	Shutdown: key.NewBinding(key.WithKeys("s"), key.WithHelp("S", "apagar"), key.WithDisabled()),
	Quit:     key.NewBinding(key.WithKeys("q", "ctrl+c"), key.WithHelp("q", "salir")),
}

// SAuthKeyMap cubre ScreenAuthLogin y ScreenAuthConfirm (T-070, T-071).
type SAuthKeyMap struct {
	Next    key.Binding // Tab / ↓ — siguiente campo
	Prev    key.Binding // Shift+Tab / ↑ — campo anterior
	Confirm key.Binding // Enter — confirmar credenciales
	Cancel  key.Binding // Esc — cancelar y volver
}

func (k SAuthKeyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Next, k.Confirm, k.Cancel}
}
func (k SAuthKeyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.Next, k.Prev},
		{k.Confirm, k.Cancel},
	}
}

// DefaultSAuthKeyMap es el KeyMap canónico de las pantallas de autenticación.
var DefaultSAuthKeyMap = SAuthKeyMap{
	Next:    key.NewBinding(key.WithKeys("tab", "down"), key.WithHelp("tab/↓", "siguiente")),
	Prev:    key.NewBinding(key.WithKeys("shift+tab", "up"), key.WithHelp("⇧tab/↑", "anterior")),
	Confirm: key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "confirmar")),
	Cancel:  key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "cancelar")),
}

// ScreenKeyMap implementa help.KeyMap para un conjunto variable de teclas por pantalla.
type ScreenKeyMap []key.Binding

// ShortHelp cumple help.KeyMap.
func (km ScreenKeyMap) ShortHelp() []key.Binding { return km }

// FullHelp cumple help.KeyMap.
func (km ScreenKeyMap) FullHelp() [][]key.Binding { return [][]key.Binding{km} }

// IsNavKey informa si msg es una tecla de navegación (enter, esc, tab, flechas, ctrl+c/d).
func IsNavKey(msg tea.KeyMsg) bool {
	switch msg.Type {
	case tea.KeyEnter, tea.KeyEsc, tea.KeyTab, tea.KeyShiftTab,
		tea.KeyUp, tea.KeyDown, tea.KeyCtrlC, tea.KeyCtrlD:
		return true
	}
	return false
}

// KeysFor retorna los key bindings para la pantalla s.
// Usado por viewFooter() para construir el footer de ayuda.
func KeysFor(s Screen) ScreenKeyMap {
	switch s {
	case ScreenWizardP1:
		return ScreenKeyMap{
			key.NewBinding(key.WithKeys("up", "down"), key.WithHelp("↑↓", "navegar")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "seleccionar")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "salir")),
		}
	case ScreenWizardP2:
		return ScreenKeyMap{
			key.NewBinding(key.WithKeys("tab", "up", "down"), key.WithHelp("tab/↑↓", "campo sig")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "continuar")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "volver")),
		}
	case ScreenWizardP3:
		return ScreenKeyMap{
			key.NewBinding(key.WithKeys("tab", "up", "down"), key.WithHelp("tab/↑↓", "campo sig")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "continuar")),
			key.NewBinding(key.WithKeys("m"), key.WithHelp("M", "toggle MFA")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "volver")),
		}
	case ScreenWizardCapacity:
		return ScreenKeyMap{
			key.NewBinding(key.WithKeys("tab", "up", "down"), key.WithHelp("tab/↑↓", "navegar campos")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "sig campo / continuar")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "volver")),
		}
	case ScreenWizardP4:
		return ScreenKeyMap{
			key.NewBinding(key.WithKeys("up", "down"), key.WithHelp("↑↓", "navegar")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "seleccionar")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "volver")),
		}
	case ScreenInstalling:
		return ScreenKeyMap{
			key.NewBinding(key.WithKeys("tab"), key.WithHelp("tab", "panel")),
			key.NewBinding(key.WithKeys("up", "down"), key.WithHelp("↑↓", "scroll")),
			key.NewBinding(key.WithKeys("l"), key.WithHelp("L", "log")),
			key.NewBinding(key.WithKeys("e"), key.WithHelp("E", "error")),
			key.NewBinding(key.WithKeys("t"), key.WithHelp("T", "timestamp")),
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "cancelar")),
		}
	case ScreenInstallLog:
		return ScreenKeyMap{
			key.NewBinding(key.WithKeys("up", "down"), key.WithHelp("↑↓", "scroll")),
			key.NewBinding(key.WithKeys("g"), key.WithHelp("G", "final")),
			key.NewBinding(key.WithKeys("l"), key.WithHelp("L", "volver")),
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "cancelar")),
		}
	case ScreenInstallErr:
		return ScreenKeyMap{
			key.NewBinding(key.WithKeys("e"), key.WithHelp("E", "volver")),
			key.NewBinding(key.WithKeys("l"), key.WithHelp("L", "log")),
			key.NewBinding(key.WithKeys("r"), key.WithHelp("R", "reintentar")),
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "cancelar")),
		}
	case ScreenInstallDone:
		return ScreenKeyMap{
			key.NewBinding(key.WithKeys("left", "right"), key.WithHelp("←→", "sección")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "continuar")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "salir")),
		}
	case ScreenReboot:
		return ScreenKeyMap{
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "reiniciar ahora")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "cancelar")),
		}
	case ScreenDashboard:
		return ScreenKeyMap{
			key.NewBinding(key.WithKeys("l"), key.WithHelp("L", "logs")),
			key.NewBinding(key.WithKeys("r"), key.WithHelp("R", "restart")),
			key.NewBinding(key.WithKeys("s"), key.WithHelp("S", "shutdown")),
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "salir")),
		}
	case ScreenLogs:
		return ScreenKeyMap{
			key.NewBinding(key.WithKeys("/"), key.WithHelp("/", "buscar")),
			key.NewBinding(key.WithKeys("g"), key.WithHelp("G", "final")),
			key.NewBinding(key.WithKeys("t"), key.WithHelp("T", "timestamp")),
			key.NewBinding(key.WithKeys("q"), key.WithHelp("Q", "volver")),
		}
	case ScreenShutdown:
		return ScreenKeyMap{
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "forzar (peligroso)")),
		}
	default:
		return ScreenKeyMap{
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "salir")),
		}
	}
}
