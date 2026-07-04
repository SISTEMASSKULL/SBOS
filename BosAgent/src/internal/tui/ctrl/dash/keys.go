// Package dash — keys.go: key bindings del dashboard de control.
// Patrón idéntico al de model/keys.go: structs con ShortHelp/FullHelp + Default* listo.
// DashMenuKeyMap y DashBodyKeyMap se usan en ctrl/render.go via dm.HelpModel.View().
package dash

import "github.com/charmbracelet/bubbles/key"

// DashMenuKeyMap cubre el foco sobre el menú lateral del dashboard.
type DashMenuKeyMap struct {
	Nav     key.Binding // ↑↓ — navegar menú
	Focus   key.Binding // Tab — cambiar foco a body
	Enter   key.Binding // Enter — abrir vista
	Refresh key.Binding // r — refrescar
	Quit    key.Binding // q / Ctrl+C — salir
}

func (k DashMenuKeyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Nav, k.Focus, k.Enter, k.Refresh, k.Quit}
}
func (k DashMenuKeyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.Nav, k.Focus, k.Enter},
		{k.Refresh, k.Quit},
	}
}

// DefaultDashMenuKeyMap es el KeyMap canónico cuando el foco está en el menú.
var DefaultDashMenuKeyMap = DashMenuKeyMap{
	Nav:     key.NewBinding(key.WithKeys("up", "down", "k", "j"), key.WithHelp("↑↓", "menú")),
	Focus:   key.NewBinding(key.WithKeys("tab"), key.WithHelp("tab", "→ body")),
	Enter:   key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "abrir")),
	Refresh: key.NewBinding(key.WithKeys("r"), key.WithHelp("r", "refresh")),
	Quit:    key.NewBinding(key.WithKeys("q", "ctrl+c"), key.WithHelp("q", "salir")),
}

// DashBodyKeyMap cubre el foco sobre el panel de contenido del dashboard.
// SubTab se habilita dinámicamente cuando la vista activa tiene sub-tabs.
type DashBodyKeyMap struct {
	Scroll  key.Binding // ↑↓/k/j — desplazar
	Focus   key.Binding // Tab — cambiar foco a menú
	Top     key.Binding // g — ir al inicio
	Bot     key.Binding // G — ir al final
	Refresh key.Binding // r — refrescar
	SubTab  key.Binding // ←→ — cambiar sub-tab (se deshabilita si no hay sub-tabs)
	Quit    key.Binding // q / Ctrl+C — salir
}

func (k DashBodyKeyMap) ShortHelp() []key.Binding {
	// SubTab se incluye siempre; help.View() lo omite automáticamente cuando está disabled.
	return []key.Binding{k.Scroll, k.Focus, k.Top, k.Refresh, k.SubTab, k.Quit}
}
func (k DashBodyKeyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{k.ShortHelp()}
}

// DefaultDashBodyKeyMap es el KeyMap canónico cuando el foco está en el body.
// Llamar a .WithSubTab(true/false) para habilitar/deshabilitar el sub-tab binding.
var DefaultDashBodyKeyMap = DashBodyKeyMap{
	Scroll:  key.NewBinding(key.WithKeys("up", "down", "k", "j"), key.WithHelp("↑↓", "scroll")),
	Focus:   key.NewBinding(key.WithKeys("tab"), key.WithHelp("tab", "→ menú")),
	Top:     key.NewBinding(key.WithKeys("g", "G"), key.WithHelp("g/G", "top/bot")),
	Refresh: key.NewBinding(key.WithKeys("r"), key.WithHelp("r", "refresh")),
	SubTab:  key.NewBinding(key.WithKeys("left", "right"), key.WithHelp("←→", "sub-tab"), key.WithDisabled()),
	Quit:    key.NewBinding(key.WithKeys("q", "ctrl+c"), key.WithHelp("q", "salir")),
}

// DashBodyKeyMapWithSubTab retorna una copia de DefaultDashBodyKeyMap
// con el binding SubTab habilitado o deshabilitado según hasSubTab.
func DashBodyKeyMapWithSubTab(hasSubTab bool) DashBodyKeyMap {
	km := DefaultDashBodyKeyMap
	km.SubTab.SetEnabled(hasSubTab)
	return km
}
