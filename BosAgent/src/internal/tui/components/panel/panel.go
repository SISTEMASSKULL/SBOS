// opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/internal/tui/components/panel/panel.go
// Package panel — paneles con Focus/Blur + PanelManager + GridLayout (§4 manual).
package panel

import (
	"strings"

	"bos/internal/tui/components/focus"
	"bos/internal/tui/styles"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Status representa el estado semántico de un panel.
type Status int

const (
	StatusNormal Status = iota
	StatusSuccess
	StatusWarning
	StatusError
	StatusCritical
)

var StatusNames = []string{"Normal", "Success", "Warning", "Error", "Critical"}

// Content implementa focus.Component con contenido interno.
type Content struct {
	focus.BaseComponent
	Title   string
	Content string
	Status  Status
	Width   int
	Height  int
}

func NewContent(id, title, content string) *Content {
	return &Content{
		BaseComponent: focus.BaseComponent{IDStr: id, EnabledBtn: true},
		Title:         title,
		Content:       content,
	}
}

func (p *Content) Init() tea.Cmd { return nil }

func (p *Content) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if km, ok := msg.(tea.KeyMsg); ok && p.FocusedBtn {
		if km.String() == "enter" {
			p.Status = (p.Status + 1) % 5
		}
	}
	return p, nil
}

func (p *Content) SetSize(w, h int) { p.Width, p.Height = w, h }

func (p *Content) View() string {
	box := styles.PanelResolve(p.FocusedBtn, !p.EnabledBtn)

	switch p.Status {
	case StatusSuccess:
		box = box.Copy().BorderForeground(styles.ColorStateOKBorder)
	case StatusWarning:
		box = box.Copy().BorderForeground(styles.ColorStateWarnBorder)
	case StatusError:
		box = box.Copy().BorderForeground(styles.ColorStateErrBorder)
	case StatusCritical:
		box = box.Copy().BorderForeground(styles.ColorStateCritBorder).
			Background(styles.ColorStateCritBg)
	}

	prefix := "  "
	if p.FocusedBtn {
		prefix = "> "
	}
	title := styles.Heading.Render(prefix + p.Title)
	if p.Status != StatusNormal {
		title += " " + styles.Dim.Render("["+StatusNames[p.Status]+"]")
	}

	body := title + "\n" + styles.Text.Render("   "+p.Content)
	if p.Width > 0 {
		return box.Copy().Width(p.Width).Render(body)
	}
	return box.Render(body)
}

// Def describe un panel dentro del layout.
type Def struct {
	Component focus.Component
	Title     string
	GridCols  int // columnas del grid (1-10)
	MinWidth  int
	MinHeight int
}

// Manager organiza paneles en filas con FocusManager interno.
type Manager struct {
	Rows   [][]Def
	Focus  *focus.Manager
	Width  int
	Height int
}

func NewManager(rows [][]Def) *Manager {
	var comps []focus.Component
	for _, row := range rows {
		for _, p := range row {
			comps = append(comps, p.Component)
		}
	}
	return &Manager{Rows: rows, Focus: focus.NewManager(comps...)}
}

// SetSize aplica el Grid de 12 columnas a los paneles.
func (pm *Manager) SetSize(g styles.Grid) {
	pm.Width, pm.Height = g.ContentW, g.BodyH
	if len(pm.Rows) == 0 {
		return
	}
	rowH := g.BodyH / len(pm.Rows)
	for _, row := range pm.Rows {
		for _, p := range row {
			w := g.Span(p.GridCols)
			if w < p.MinWidth {
				w = p.MinWidth
			}
			h := rowH
			if h < p.MinHeight {
				h = p.MinHeight
			}
			if pc, ok := p.Component.(*Content); ok {
				pc.SetSize(w-2, h-2)
			}
		}
	}
}

func (pm *Manager) View() string {
	var rendered []string
	for _, row := range pm.Rows {
		var cols []string
		for _, p := range row {
			cols = append(cols, p.Component.View())
		}
		rendered = append(rendered, lipgloss.JoinHorizontal(lipgloss.Top, cols...))
	}
	return lipgloss.JoinVertical(lipgloss.Left, rendered...)
}

// ── Floating (modal) ──────────────────────────────────────────────────────

// FloatingPanel es un modal centrado con overlay.
type FloatingPanel struct {
	Title   string
	Content string
	Visible bool
	Width   int
	Height  int
}

// Render sobrepone el modal sobre el fondo conservando el contenido debajo.
func (f *FloatingPanel) Render(bg string, screenW, screenH int) string {
	if !f.Visible {
		return bg
	}
	w, h := f.Width, f.Height
	if w == 0 {
		w = 40
	}
	if h == 0 {
		h = 8
	}
	box := styles.PanelFocused.Copy().Width(w).Height(h)
	title := styles.Heading.Render(" " + f.Title + " ")
	body := title + "\n" + styles.Text.Render("  "+f.Content) + "\n\n" + styles.Dim.Render("  esc = cerrar")
	return overlay(bg, box.Render(body), screenW, screenH)
}

func overlay(bg, fg string, screenW, screenH int) string {
	bgLines := strings.Split(bg, "\n")
	fgLines := strings.Split(fg, "\n")
	fgW := lipgloss.Width(fgLines[0])
	fgH := len(fgLines)
	startX := (screenW - fgW) / 2
	startY := (screenH - fgH) / 2
	if startX < 0 {
		startX = 0
	}
	if startY < 0 {
		startY = 0
	}
	for len(bgLines) < screenH {
		bgLines = append(bgLines, "")
	}
	for i, fgLine := range fgLines {
		y := startY + i
		if y < 0 || y >= len(bgLines) {
			continue
		}
		bgRunes := []rune(bgLines[y])
		fgRunes := []rune(fgLine)
		for len(bgRunes) < startX+len(fgRunes) {
			bgRunes = append(bgRunes, ' ')
		}
		for j, r := range fgRunes {
			bgRunes[startX+j] = r
		}
		bgLines[y] = string(bgRunes)
	}
	return strings.Join(bgLines, "\n")
}
