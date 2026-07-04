// Package styles — huh_theme.go: adaptador de tema SBOS → huh forms.
//
// huh v1.0.0 usa su propio sistema ThemeCharm() con colores rosa/morado.
// Este archivo genera un *huh.Theme dinámico a partir de los tokens del
// tema SBOS activo (Capa 2B + tokens_state), respetando la política:
//   - Capa 1 (primitivos) → fija, no se toca
//   - Capa 2B (ActiveTheme + tokens_state) → fuente de colores
//   - Capa 3 (componentes) → aquí se construye el huh.Theme
//
// CERO valores hardcodeados. Todo color sale de los tokens del sistema.
//
// Uso:  form.WithTheme(styles.HuhTheme())
// Tras ApplyTheme("esmeralda"), HuhTheme() devuelve acentos verdes.
package styles

import (
	"github.com/charmbracelet/bubbles/help"
	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/lipgloss"
)

// HuhKeyMap retorna un keymap huh con Quit mapeado a "esc" en vez de "ctrl+c".
// En el TUI de BOS, ctrl+c es salida de emergencia global; esc es cancelar/volver.
func HuhKeyMap() *huh.KeyMap {
	km := huh.NewDefaultKeyMap()
	km.Quit = key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "volver"))
	return km
}

// HuhTheme retorna un tema huh dinámico basado en el tema SBOS activo.
// Los colores de acento (foco, cursores, botones) usan los tokens mutables
// del tema. Los colores de estado usan tokens_state (invariantes perceptuales).
// Cambiar de tema con ApplyTheme() → HuhTheme() refleja el nuevo tema.
func HuhTheme() *huh.Theme {
	t := huh.ThemeBase()

	// ── Tokens del tema activo (Capa 2B, mutados por ApplyTheme) ────────────
	accent   := ColorAccentText             // acento brillante del tema
	textPri  := ActiveTheme.TextPrimary     // texto principal
	textSec  := ActiveTheme.TextSecondary   // texto secundario
	textOff  := ActiveTheme.TextDisabled    // texto inactivo/deshabilitado
	surface  := ActiveTheme.BgSurface       // fondo de panel (bg medio)
	elevated := ActiveTheme.BgElevated      // fondo elevado (bg claro)

	// ── Tokens de estado (tokens_state.go — invariantes perceptuales) ──────
	stateOK  := lipgloss.Color(ColorStateOKFg)    // teal-verde éxito
	stateErr := lipgloss.Color(ColorStateErrFg)   // coral error

	_ = surface
	_ = elevated

	// ── Foco: acento del tema activo ────────────────────────────────────────
	t.Focused.Base = t.Focused.Base.BorderForeground(textOff)
	t.Focused.Card = t.Focused.Base
	t.Focused.Title = t.Focused.Title.Foreground(accent).Bold(true)
	t.Focused.NoteTitle = t.Focused.NoteTitle.Foreground(accent).Bold(true).MarginBottom(1)
	t.Focused.Description = t.Focused.Description.Foreground(textSec)
	t.Focused.ErrorIndicator = t.Focused.ErrorIndicator.Foreground(stateErr)
	t.Focused.ErrorMessage = t.Focused.ErrorMessage.Foreground(stateErr)
	t.Focused.SelectSelector = t.Focused.SelectSelector.Foreground(accent)
	t.Focused.NextIndicator = t.Focused.NextIndicator.Foreground(accent)
	t.Focused.PrevIndicator = t.Focused.PrevIndicator.Foreground(accent)
	t.Focused.Option = t.Focused.Option.Foreground(textPri)
	t.Focused.MultiSelectSelector = t.Focused.MultiSelectSelector.Foreground(accent)
	t.Focused.SelectedOption = t.Focused.SelectedOption.Foreground(stateOK)
	t.Focused.SelectedPrefix = lipgloss.NewStyle().
		Foreground(stateOK).
		SetString("✓ ")
	t.Focused.UnselectedPrefix = lipgloss.NewStyle().
		Foreground(textOff).
		SetString("• ")
	t.Focused.UnselectedOption = t.Focused.UnselectedOption.Foreground(textPri)
	t.Focused.FocusedButton = t.Focused.FocusedButton.
		Foreground(textPri).
		Background(accent)
	t.Focused.Next = t.Focused.FocusedButton
	t.Focused.BlurredButton = t.Focused.BlurredButton.
		Foreground(textPri).
		Background(textOff)

	t.Focused.TextInput.Cursor = t.Focused.TextInput.Cursor.Foreground(stateOK)
	t.Focused.TextInput.Placeholder = t.Focused.TextInput.Placeholder.
		Foreground(textOff)
	t.Focused.TextInput.Prompt = t.Focused.TextInput.Prompt.Foreground(accent)

	// ── Blur: mismo que focus, sin borde ni indicadores ─────────────────────
	t.Blurred = t.Focused
	t.Blurred.Base = t.Focused.Base.BorderStyle(lipgloss.HiddenBorder())
	t.Blurred.Card = t.Blurred.Base
	t.Blurred.NextIndicator = lipgloss.NewStyle()
	t.Blurred.PrevIndicator = lipgloss.NewStyle()

	// ── Grupo: títulos heredan del foco ─────────────────────────────────────
	t.Group.Title = t.Focused.Title
	t.Group.Description = t.Focused.Description

	// ── Help interno del form: escala tipográfica del tema ─────────────────
	t.Help = HuhHelpStyles()

	return t
}

// ── Adaptador de bubbles/help ───────────────────────────────────────────────

// HuhHelpStyles retorna help.Styles adaptados al tema SBOS activo.
// El default de bubbles/help usa grises genéricos; aquí usamos la escala
// tipográfica del tema (TextPrimary, TextSecondary, TextDisabled).
func HuhHelpStyles() help.Styles {
	keyStyle := lipgloss.NewStyle().Foreground(ColorTextSecondary)
	descStyle := lipgloss.NewStyle().Foreground(ColorMuted)
	sepStyle := lipgloss.NewStyle().Foreground(ColorTextDisabled)
	ellipsis := lipgloss.NewStyle().Foreground(ColorTextDisabled)

	return help.Styles{
		ShortKey:       keyStyle,
		ShortDesc:      descStyle,
		ShortSeparator: sepStyle,
		Ellipsis:       ellipsis,
		FullKey:        keyStyle,
		FullDesc:       descStyle,
		FullSeparator:  sepStyle,
	}
}
