// opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/internal/tui/components/focus/manager.go
// Package focus — interfaz Component y FocusManager (§3 manual).
// Base para todos los componentes interactivos del TUI.
package focus

import tea "github.com/charmbracelet/bubbletea"

// Component es el contrato que todo widget del design system debe cumplir.
type Component interface {
	tea.Model
	Focus() tea.Cmd
	Blur() tea.Cmd
	Focused() bool
	SetEnabled(bool)
	Enabled() bool
	ID() string
}

// BaseComponent provee implementación por defecto para embeder.
type BaseComponent struct {
	IDStr      string
	FocusedBtn bool
	EnabledBtn bool
}

func (b *BaseComponent) ID() string        { return b.IDStr }
func (b *BaseComponent) Focused() bool     { return b.FocusedBtn }
func (b *BaseComponent) Enabled() bool     { return b.EnabledBtn }
func (b *BaseComponent) SetEnabled(v bool) { b.EnabledBtn = v }
func (b *BaseComponent) Focus() tea.Cmd    { b.FocusedBtn = true; return nil }
func (b *BaseComponent) Blur() tea.Cmd      { b.FocusedBtn = false; return nil }

// Manager orquesta el foco entre N componentes. Solo uno tiene foco a la vez.
type Manager struct {
	Components []Component
	ActiveIdx  int
}

func NewManager(comps ...Component) *Manager {
	fm := &Manager{Components: comps}
	if len(comps) > 0 {
		fm.Components[0].Focus()
	}
	return fm
}

func (fm *Manager) Active() Component { return fm.Components[fm.ActiveIdx] }

func (fm *Manager) Next() tea.Cmd { return fm.move(+1) }
func (fm *Manager) Prev() tea.Cmd { return fm.move(-1) }

func (fm *Manager) move(delta int) tea.Cmd {
	if len(fm.Components) == 0 {
		return nil
	}
	fm.Components[fm.ActiveIdx].Blur()
	n := len(fm.Components)
	for range n {
		fm.ActiveIdx = (fm.ActiveIdx + delta + n) % n
		if fm.Components[fm.ActiveIdx].Enabled() {
			break
		}
	}
	return fm.Components[fm.ActiveIdx].Focus()
}

func (fm *Manager) FocusByID(id string) tea.Cmd {
	for i, c := range fm.Components {
		if c.ID() == id {
			fm.Components[fm.ActiveIdx].Blur()
			fm.ActiveIdx = i
			return c.Focus()
		}
	}
	return nil
}
