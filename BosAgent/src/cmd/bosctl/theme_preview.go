package main

import (
	"fmt"
	"os"
	"strings"

	"bos/internal/tui/components/button"
	"bos/internal/tui/components/panel"
	"bos/internal/tui/styles"

	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/bubbles/textarea"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	zone "github.com/lrstanley/bubblezone"
	"github.com/muesli/termenv"
)

type focus int

const (
	focusMenu focus = iota
	focusInput1
	focusInput2
	focusButtons
	focusPanels
	focusPalette
	focusCount
)

var (
	group1  = []string{"Dashboard", "Servicios", "Red"}
	group2  = []string{"Nuevo", "Editar", "Eliminar", "Exportar"}
	allMenu = append(append([]string{}, group1...), group2...)

	allPalettes = []struct {
		family string
		scale  []struct{ name, hex string }
	}{
		{"Slate", []struct{ name, hex string }{{"50","#f8fafc"},{"100","#f1f5f9"},{"200","#e2e8f0"},{"300","#cbd5e1"},{"400","#94a3b8"},{"500","#64748b"},{"600","#475569"},{"700","#334155"},{"800","#1e293b"},{"900","#0f172a"},{"950","#020617"}}},
		{"Gray", []struct{ name, hex string }{{"50","#f9fafb"},{"100","#f3f4f6"},{"200","#e5e7eb"},{"300","#d1d5db"},{"400","#9ca3af"},{"500","#6b7280"},{"600","#4b5563"},{"700","#374151"},{"800","#1f2937"},{"900","#111827"},{"950","#030712"}}},
		{"Cyan", []struct{ name, hex string }{{"50","#ecfeff"},{"100","#cffafe"},{"200","#a5f3fc"},{"300","#67e8f9"},{"400","#22d3ee"},{"500","#06b6d4"},{"600","#0891b2"},{"700","#0e7490"},{"800","#155e75"},{"900","#164e63"},{"950","#083344"}}},
		{"Red", []struct{ name, hex string }{{"50","#fef2f2"},{"100","#fee2e2"},{"200","#fecaca"},{"300","#fca5a5"},{"400","#f87171"},{"500","#ef4444"},{"600","#dc2626"},{"700","#b91c1c"},{"800","#991b1b"},{"900","#7f1d1d"},{"950","#450a0a"}}},
		{"Green", []struct{ name, hex string }{{"50","#f0fdf4"},{"100","#dcfce7"},{"200","#bbf7d0"},{"300","#86efac"},{"400","#4ade80"},{"500","#22c55e"},{"600","#16a34a"},{"700","#15803d"},{"800","#166534"},{"900","#14532d"},{"950","#052e16"}}},
		{"Amber", []struct{ name, hex string }{{"50","#fffbeb"},{"100","#fef3c7"},{"200","#fde68a"},{"300","#fcd34d"},{"400","#fbbf24"},{"500","#f59e0b"},{"600","#d97706"},{"700","#b45309"},{"800","#92400e"},{"900","#78350f"},{"950","#451a03"}}},
		{"Blue", []struct{ name, hex string }{{"50","#eff6ff"},{"100","#dbeafe"},{"200","#bfdbfe"},{"300","#93c5fd"},{"400","#60a5fa"},{"500","#3b82f6"},{"600","#2563eb"},{"700","#1d4ed8"},{"800","#1e40af"},{"900","#1e3a8a"},{"950","#172554"}}},
	}
)

type model struct {
	width, height int
	focus         focus
	input1, input2, input3, input4 textinput.Model
	textarea1     textarea.Model
	toggleMFA, toggleDebug *button.Model
	inputFocus    int // 0-5: inputs + textarea + toggle
	err1, err2    bool
	menuCursor    int
	buttons       []*button.Model
	buttonCursor  int
	panels        *panel.Manager
	modal         panel.FloatingPanel
	msg           string
}

func newModel(ti1, ti2 textinput.Model) model {
	ti3 := textinput.New(); ti3.Placeholder = "ejemplo@correo.com"; ti3.PromptStyle = styles.Cyan; ti3.TextStyle = styles.Text; ti3.PlaceholderStyle = styles.Dim; ti3.Cursor.Style = styles.AccentBold; ti3.Width = 28
	ti4 := textinput.New(); ti4.Placeholder = "buscar..."; ti4.PromptStyle = styles.Cyan; ti4.TextStyle = styles.Text; ti4.PlaceholderStyle = styles.Dim; ti4.Cursor.Style = styles.AccentBold; ti4.Width = 28
	pa := panel.NewContent("panel-a", "Panel A", "Sidebar. GridCols=3, MinWidth 25.")
	pb := panel.NewContent("panel-b", "Panel B", "Contenido principal. GridCols=7, MinWidth 30.")
	pc := panel.NewContent("panel-c", "Panel C", "Logs en tiempo real. GridCols=10, MinWidth 50.")
	pm := panel.NewManager([][]panel.Def{
		{{Component: pa, Title: "Navegacion", GridCols: 3, MinWidth: 25, MinHeight: 6},
		 {Component: pb, Title: "Servicios", GridCols: 7, MinWidth: 30, MinHeight: 6}},
		{{Component: pc, Title: "Logs", GridCols: 10, MinWidth: 50, MinHeight: 5}},
	})
	ta := textarea.New()
	ta.Placeholder = "Escribe aqui...\nVarias lineas permitidas"
	ta.CharLimit = 500
	ta.SetHeight(4)
	ta.SetWidth(35)

	toggleMFA := button.New(styles.IconCheckboxOn+" MFA", button.Primary).SetToggle(false)
	toggleDebug := button.New(styles.IconCheckboxOff+" Debug", button.Disabled).SetToggle(false) // disabled variant

	return model{
		input1: ti1, input2: ti2, input3: ti3, input4: ti4,
		textarea1: ta,
		toggleMFA: toggleMFA, toggleDebug: toggleDebug,
		buttons: func() []*button.Model {
			btns := []*button.Model{
				button.New("Primary", button.Primary), button.New("Secondary", button.Secondary),
				button.New("Danger", button.Danger), button.New("Ghost", button.Ghost),
				button.New("Disabled", button.Disabled),
				button.New("Success", button.Success), button.New("Warning", button.Warning),
				button.New("Info", button.Info), button.New("Link", button.Link),
				button.New(styles.IconDotActive, button.Icon),
			}
			button.SetUniformWidth(btns, button.MaxWidth(btns)) // una sola vez (§13.2 Gap 5)
			return btns
		}(),
		panels: pm,
		modal:  panel.FloatingPanel{Title: "Modal - FloatingPanel", Content: "Panel flotante centrado con overlay.\n  Captura el foco. Esc para cerrar.", Width: 42, Height: 9},
	}
}

func (m model) Init() tea.Cmd { return tea.Batch(m.input1.Focus(), textinput.Blink, textarea.Blink) }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd
	var cmd tea.Cmd

	if m.modal.Visible {
		if km, ok := msg.(tea.KeyMsg); ok {
			if km.String() == "esc" || km.String() == "q" { m.modal.Visible = false }
		}
		return m, nil
	}

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c": return m, tea.Quit
		case "tab":
			if m.focus == focusInput1 || m.focus == focusInput2 {
				m.inputFocus = (m.inputFocus + 1) % 6
				cmds = append(cmds, m.focusInputByIndex())
			} else {
				m.blurCurrent()
				m.focus = (m.focus + 1) % focusCount
				cmds = append(cmds, m.focusCurrent())
			}
		case "shift+tab":
			if m.focus == focusInput1 || m.focus == focusInput2 {
				m.inputFocus = (m.inputFocus - 1 + 6) % 6
				cmds = append(cmds, m.focusInputByIndex())
			} else {
				m.blurCurrent()
				m.focus = (m.focus - 1 + focusCount) % focusCount
				cmds = append(cmds, m.focusCurrent())
			}
		case "left", "h":
			switch m.focus {
			case focusButtons:
				m.buttons[m.buttonCursor].Blur(); m.moveButtonCursor(-1)
				cmds = append(cmds, m.buttons[m.buttonCursor].Focus())
			case focusPanels: cmds = append(cmds, m.panels.Focus.Prev())
			}
		case "right", "l":
			switch m.focus {
			case focusButtons:
				m.buttons[m.buttonCursor].Blur(); m.moveButtonCursor(+1)
				cmds = append(cmds, m.buttons[m.buttonCursor].Focus())
			case focusPanels: cmds = append(cmds, m.panels.Focus.Next())
			}
		case "up", "k":
			switch m.focus {
			case focusMenu: if m.menuCursor > 0 { m.menuCursor-- }
			case focusButtons:
				m.buttons[m.buttonCursor].Blur(); m.moveButtonCursor(-1)
				cmds = append(cmds, m.buttons[m.buttonCursor].Focus())
			case focusPanels: cmds = append(cmds, m.panels.Focus.Prev())
			}
		case "down", "j":
			switch m.focus {
			case focusMenu: if m.menuCursor < len(allMenu)-1 { m.menuCursor++ }
			case focusButtons:
				m.buttons[m.buttonCursor].Blur(); m.moveButtonCursor(+1)
				cmds = append(cmds, m.buttons[m.buttonCursor].Focus())
			case focusPanels: cmds = append(cmds, m.panels.Focus.Next())
			}
		case "enter":
			switch m.focus {
			case focusMenu: m.msg = "Menu: " + allMenu[m.menuCursor]
			case focusInput1:
				m.err1 = strings.TrimSpace(m.input1.Value()) == ""
				if !m.err1 { m.msg = "Input 1: OK" }
			case focusInput2:
				m.err2 = len(strings.TrimSpace(m.input2.Value())) < 3
				if !m.err2 { m.msg = "Input 2: OK" }
			case focusButtons: m.msg = "Boton: " + m.buttons[m.buttonCursor].Label
			case focusPanels:
				if pc, ok := m.panels.Focus.Active().(*panel.Content); ok {
					m.msg = "Panel " + pc.Title + " -> " + panel.StatusNames[pc.Status]
				}
			}
		case "esc": m.err1, m.err2, m.msg = false, false, ""
		case "m": m.modal.Visible = true
		case "1", "2", "3":
			if m.focus == focusPanels {
				ids := []string{"panel-a", "panel-b", "panel-c"}
				idx := int(msg.String()[0] - '1')
				if idx < len(ids) { cmds = append(cmds, m.panels.Focus.FocusByID(ids[idx])) }
			}
		}
	}

	// Propagar eventos a los botones (mouse hover/press)
	for _, btn := range m.buttons {
		_, btnCmd := btn.Update(msg)
		if btnCmd != nil { cmds = append(cmds, btnCmd) }
	}
	m.input1, cmd = m.input1.Update(msg); cmds = append(cmds, cmd)
	m.input2, cmd = m.input2.Update(msg); cmds = append(cmds, cmd)
	m.input3, cmd = m.input3.Update(msg); cmds = append(cmds, cmd)
	m.input4, cmd = m.input4.Update(msg); cmds = append(cmds, cmd)
	m.textarea1, cmd = m.textarea1.Update(msg); cmds = append(cmds, cmd)
	_, cmd = m.toggleMFA.Update(msg); cmds = append(cmds, cmd)
	_, cmd = m.toggleDebug.Update(msg); cmds = append(cmds, cmd)
	return m, tea.Batch(cmds...)
}

func (m *model) focusInputByIndex() tea.Cmd {
	m.input1.Blur(); m.input2.Blur(); m.input3.Blur(); m.input4.Blur(); m.textarea1.Blur()
	m.toggleMFA.Blur()
	switch m.inputFocus {
	case 0: m.focus = focusInput1; return m.input1.Focus()
	case 1: m.focus = focusInput2; return m.input2.Focus()
	case 2: m.focus = focusInput1; return m.textarea1.Focus()
	case 3: m.focus = focusInput1; m.toggleMFA.Focus(); return nil
	}
	return nil
}

func (m *model) blurCurrent() {
	m.input1.Blur(); m.input2.Blur(); m.input3.Blur(); m.input4.Blur()
	if m.focus == focusButtons { m.buttons[m.buttonCursor].Blur() }
}
func (m *model) focusCurrent() tea.Cmd {
	switch m.focus {
	case focusInput1: return m.input1.Focus()
	case focusInput2: return m.input2.Focus()
	case focusButtons: return m.buttons[m.buttonCursor].Focus()
	case focusPanels: return m.panels.Focus.Active().Focus()
	}
	return nil
}
func (m *model) moveButtonCursor(delta int) {
	n := len(m.buttons)
	for range n {
		m.buttonCursor = (m.buttonCursor + delta + n) % n
		if m.buttons[m.buttonCursor].Variant != button.Disabled { return }
	}
}

func renderColorRow(scale []struct{ name, hex string }) string {
	var blocks []string
	for _, c := range scale {
		fg := lipgloss.Color("#f8fafc")
		if c.name == "50" || c.name == "100" || c.name == "200" || c.name == "300" {
			fg = lipgloss.Color("#0f172a")
		}
		swatch := lipgloss.NewStyle().Background(lipgloss.Color(c.hex)).Foreground(fg).Bold(true).Padding(0,1).Render(fmt.Sprintf("%3s",c.name)+" "+c.hex)
		blocks = append(blocks, swatch)
	}
	return lipgloss.JoinHorizontal(lipgloss.Top, blocks...)
}

func indicator(name string, active bool) string {
	if active { return styles.TabActive.Render(" " + name + " ") }
	return styles.Tab.Render(" " + name + " ")
}

func (m model) View() string {
	w := m.width - 4
	if w < 50 { w = 50 }
	var b strings.Builder

	b.WriteString(styles.TopBar.Width(m.width).Render(" SBOS Theme Preview - " + styles.ActiveTheme.Label))
	b.WriteString("\n")
	names := []string{"Menu", "Input 1", "Input 2", "Botones", "Paneles", "Paleta"}
	var tabs []string
	for i, name := range names { tabs = append(tabs, indicator(name, focus(i) == m.focus)) }
	b.WriteString(strings.Join(tabs, " | "))
	b.WriteString("    " + styles.Dim.Render("Tab navegar . m = modal . q salir"))
	b.WriteString("\n")
	b.WriteString(styles.Divider.Render(strings.Repeat("-", w+2)))
	b.WriteString("\n\n")

	switch m.focus {
	case focusMenu:
		var sb strings.Builder
		sb.WriteString(styles.Heading.Render("Menu") + "\n")
		sb.WriteString(styles.MenuGroupTitle.Render(" PRINCIPAL") + "\n")
		for i, item := range group1 {
			if i == m.menuCursor { sb.WriteString(styles.MenuItemActive.Render("  > " + item) + "\n")
			} else { sb.WriteString(styles.MenuItem.Render("    " + item) + "\n") }
		}
		sb.WriteString("\n")
		sb.WriteString(styles.MenuGroupTitle.Render(" ACCIONES") + "\n")
		for i, item := range group2 {
			idx := len(group1) + i
			if idx == m.menuCursor { sb.WriteString(styles.MenuItemActive.Render("  > " + item) + "\n")
			} else if item == "Eliminar" { sb.WriteString(styles.MenuItemDisabled.Render("    " + item + " (disabled)") + "\n")
			} else { sb.WriteString(styles.MenuItem.Render("    " + item) + "\n") }
		}
		sb.WriteString("\n" + styles.Dim.Render("up/down navegar . Enter seleccionar"))
		b.WriteString(styles.PanelResolve(true, false).Width(w).Render(sb.String()))

	case focusInput1, focusInput2:
		colW := (w - 8) / 3
		if colW < 28 { colW = 28 }

		// === COLUMNA 1: Funcional ===
		var c1 strings.Builder
		c1.WriteString(styles.Heading.Render("Funcional") + "\n\n")

		c1.WriteString(styles.Label.Render("Nombre *") + "\n")
		var s1 lipgloss.Style
		switch { case m.err1: s1 = styles.InputError; case m.focus == focusInput1: s1 = styles.InputFocus; default: s1 = styles.Input }
		if m.err1 { c1.WriteString(styles.Error.Render("x requerido") + "\n") }
		c1.WriteString(s1.Width(colW).Render(m.input1.View()) + "\n\n")

		c1.WriteString(styles.Label.Render("Codigo") + "\n")
		var s2 lipgloss.Style
		switch { case m.err2: s2 = styles.InputError; case m.focus == focusInput2: s2 = styles.InputFocus; default: s2 = styles.Input }
		if m.err2 { c1.WriteString(styles.Error.Render("x min 3 chars") + "\n") }
		c1.WriteString(s2.Width(colW).Render(m.input2.View()) + "\n\n")

		c1.WriteString(styles.Label.Render("Bio (TextArea)") + "\n")
		taStyle := styles.Input
		if m.focus == focusInput1 { taStyle = styles.InputFocus }
		c1.WriteString(taStyle.Width(colW).Height(4).Render(m.textarea1.View()) + "\n")
		c1.WriteString(styles.Dim.Render(fmt.Sprintf("%d/500", len(m.textarea1.Value()))) + "\n\n")

		c1.WriteString(styles.Label.Render("Toggle / Checkbox") + "\n")
		c1.WriteString(m.toggleMFA.View() + "\n")
		c1.WriteString(m.toggleDebug.View() + "\n")
		c1.WriteString(styles.Dim.Render("Enter = toggle") + "\n")

		// === COLUMNA 2: Estados ===
		var c2 strings.Builder
		c2.WriteString(styles.Heading.Render("Estados") + "\n\n")

		c2.WriteString(styles.Label.Render("Email") + "\n")
		c2.WriteString(styles.InputFocus.Width(colW).Render(m.input3.View()) + "\n")
		c2.WriteString(styles.Dim.Render("placeholder: correo") + "\n\n")

		c2.WriteString(styles.Label.Render("Disabled") + "\n")
		c2.WriteString(styles.InputDisabled.Width(colW).Render("deshabilitado") + "\n\n")

		c2.WriteString(styles.Label.Render("Error") + "\n")
		c2.WriteString(styles.InputError.Width(colW).Render("valor invalido") + "\n")
		c2.WriteString(styles.Error.Render("x no valido") + "\n\n")

		c2.WriteString(styles.Label.Render("Success") + "\n")
		c2.WriteString(styles.InputSuccess.Width(colW).Render("valor correcto") + "\n")
		c2.WriteString(styles.Success.Render(styles.IconOK+" OK") + "\n\n")

		c2.WriteString(styles.Label.Render("Read Only") + "\n")
		c2.WriteString(styles.InputReadOnly.Width(colW).Render("no editable") + "\n")
		c2.WriteString(styles.Dim.Render("sin cursor") + "\n\n")

		c2.WriteString(styles.Label.Render("Password") + "\n")
		c2.WriteString(styles.InputFocus.Width(colW).Render("••••••••") + "\n\n")

		// === COLUMNA 3: Tipos ===
		var c3 strings.Builder
		c3.WriteString(styles.Heading.Render("Tipos") + "\n\n")

		c3.WriteString(styles.Label.Render("Buscar") + "\n")
		c3.WriteString(styles.InputFocus.Width(colW).Render(m.input4.View()) + "\n")
		c3.WriteString(styles.Dim.Render("placeholder: busqueda") + "\n\n")

		c3.WriteString(styles.Label.Render("RadioButton") + "\n")
		c3.WriteString(styles.Tint(styles.IconRadioOn, styles.ColorAccent)+" " + styles.Text.Render("HA (alta disponibilidad)") + "\n")
		c3.WriteString(styles.Tint(styles.IconCircleOpen, styles.ColorTextSecondary)+" " + styles.Text.Render("Standalone") + "\n")
		c3.WriteString(styles.Tint(styles.IconCircleOpen, styles.ColorTextDisabled)+" " + styles.Dim.Render("Dev local") + "\n\n")

		c3.WriteString(styles.Label.Render("Checkbox") + "\n")
		c3.WriteString(styles.Tint(styles.IconCheckboxOn, styles.ColorAccent)+" " + styles.Text.Render("MFA habilitado") + "\n")
		c3.WriteString(styles.Tint(styles.IconCheckboxOff, styles.ColorTextSecondary)+" " + styles.Text.Render("Notificaciones") + "\n")
		c3.WriteString(styles.Tint(styles.IconCheckboxOff, styles.ColorTextDisabled)+" " + styles.Dim.Render("Beta (no disponible)") + "\n\n")

		c3.WriteString(styles.Label.Render("Confirm") + "\n")
		c3.WriteString(styles.InputFocus.Width(colW).Render("  [ "+styles.AccentBold.Render("Si")+" ]  [ No ]") + "\n\n")

		c3.WriteString(styles.Label.Render("FilePicker") + "\n")
		c3.WriteString(styles.Input.Width(colW).Render("  > config.yaml  2.1KB") + "\n")
		c3.WriteString(styles.Input.Width(colW).Render("    theme.yaml   890B") + "\n")

		// Unir 3 columnas
		row := lipgloss.JoinHorizontal(lipgloss.Top,
			c1.String(),
			styles.Dim.Render(" │ ")+c2.String(),
			styles.Dim.Render(" │ ")+c3.String(),
		)
		b.WriteString(styles.PanelResolve(true, false).Width(w).Render(row))
	case focusButtons:
		var sb strings.Builder
		sb.WriteString(styles.Heading.Render("Botones - Vertical") + "\n\n")
		for _, btn := range m.buttons { sb.WriteString(btn.View() + "\n") }
		sb.WriteString("\n" + styles.Heading.Render("Botones - Horizontal (responsive)") + "\n\n")
		group := button.ButtonGroup{
			Buttons:        m.buttons,
			Gap:            1,
			AvailableWidth: w - 4,
		}
		sb.WriteString(group.View())
		sb.WriteString("\n" + styles.Dim.Render("circular . foco = borde bright + bold (WCAG 2.4.11) . Disabled se saltea"))
		sb.WriteString("\n" + styles.Dim.Render("circular . foco = borde bright + bold (WCAG 2.4.11) . Disabled se saltea"))
		b.WriteString(styles.PanelResolve(true, false).Width(w).Render(sb.String()))

	case focusPanels:
		var sb strings.Builder
		sb.WriteString(styles.Heading.Render("PanelManager - Grid 12 cols + FloatingPanel") + "\n\n")
		g := styles.NewGrid(m.width, m.height)
		m.panels.SetSize(g)
		sb.WriteString(m.panels.View())
		sb.WriteString("\n")
		active := m.panels.Focus.Active()
		pc, _ := active.(*panel.Content)
		statusStr := ""
		if pc != nil { statusStr = panel.StatusNames[pc.Status] }
		sb.WriteString("\n" + styles.Dim.Render("FocusManager . 1/2/3 = FocusByID . Enter = rotar ("+statusStr+")"))
		sb.WriteString("\n" + styles.Dim.Render("m = FloatingPanel . Grid: Span(3)+Span(7)=ContentW"))
		b.WriteString(styles.PanelResolve(true, false).Width(w).Render(sb.String()))

	case focusPalette:
		var sb strings.Builder
		sb.WriteString(styles.Heading.Render("Paleta de colores - 18 familias (Tailwind 50-950)") + "\n\n")
		for _, family := range allPalettes {
			sb.WriteString(styles.Subtitle.Render("  " + family.family) + "\n")
			sb.WriteString(renderColorRow(family.scale))
			sb.WriteString("\n")
		}
		sb.WriteString(styles.Dim.Render("Tonos: 50 (claro) -> 950 (oscuro)"))
		b.WriteString(styles.PanelResolve(true, false).Width(w).Render(sb.String()))
	}

	b.WriteString("\n\n")
	if m.msg != "" { b.WriteString(styles.NotifySuccess.Width(w).Render(" > " + m.msg) + "\n\n") }
	b.WriteString(styles.Heading.Render("Badges + Estado") + "\n")
	b.WriteString(styles.Badge.Render(" Badge ") + "  " + styles.BadgeCounter.Render(" 99+ ") + "  " + styles.BadgeDot.Render("*") + "\n")
	b.WriteString(styles.Success.Render(" Success ") + " " + styles.Warning.Render(" Warning ") + " " + styles.Error.Render(" Error ") + " " + styles.Danger.Render(" Danger ") + "\n\n")
	b.WriteString(styles.NotifySuccess.Width(w).Render(" Success banner - StatusOK") + "\n\n")
	b.WriteString(styles.NotifyError.Width(w).Render(" Error banner - StatusErr") + "\n")
	b.WriteString("\n" + styles.Footer.Width(m.width).Render(" Tab navegar . cursor . Enter accionar . m = modal . q salir"))
	view := b.String()
	if m.modal.Visible { view = m.modal.Render(view, m.width, m.height) }
	return zone.Scan(view)
}

func cmdThemePreview(args []string) int {
	lipgloss.SetColorProfile(termenv.TrueColor)
	themeID := "abyss"
	if len(args) > 0 && args[0] != "" { themeID = args[0] }
	styles.ApplyTheme(themeID)
	ti1 := textinput.New(); ti1.Placeholder = "Nombre (requerido)"; ti1.PromptStyle = styles.Cyan; ti1.TextStyle = styles.Text; ti1.PlaceholderStyle = styles.Dim; ti1.Cursor.Style = styles.AccentBold; ti1.Width = 28
	ti2 := textinput.New(); ti2.Placeholder = "Codigo (min 3 chars)"; ti2.PromptStyle = styles.Cyan; ti2.TextStyle = styles.Text; ti2.PlaceholderStyle = styles.Dim; ti2.Cursor.Style = styles.AccentBold; ti2.Width = 28
	ti3 := textinput.New(); ti3.Placeholder = "ejemplo@correo.com"; ti3.PromptStyle = styles.Cyan; ti3.TextStyle = styles.Text; ti3.PlaceholderStyle = styles.Dim; ti3.Cursor.Style = styles.AccentBold; ti3.Width = 28
	ti4 := textinput.New(); ti4.Placeholder = "Selecciona..."; ti4.PromptStyle = styles.Cyan; ti4.TextStyle = styles.Text; ti4.PlaceholderStyle = styles.Dim; ti4.Cursor.Style = styles.AccentBold; ti4.Width = 28
	zone.NewGlobal()
	tty, cleanup := openTTY()
	defer cleanup()
	p := tea.NewProgram(newModel(ti1, ti2), tea.WithInput(tty), tea.WithOutput(os.Stdout), tea.WithAltScreen(), tea.WithMouseAllMotion())
	if _, err := p.Run(); err != nil { fmt.Fprintf(os.Stderr, "theme-preview: %v\n", err); return 1 }
	return 0
}
