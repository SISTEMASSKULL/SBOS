// Package components — catálogo de componentes reutilizables del TUI SBOS.
//
// Cada componente vive en su propia carpeta y expone una API limpia
// basada en la interfaz común focus.Component (Focus/Blur/View).
//
// Estructura:
//
//	focus/     — interfaz Component + FocusManager (§3 manual)
//	button/    — botones con estados Focused/Blurred (§5.11.1)
//	panel/     — paneles con PanelManager + GridLayout (§4)
//	floating/  — modales flotantes con overlay (§5.16)
//	spacer/    — separadores entre componentes
//
// Uso desde cualquier parte del proyecto:
//
//	import "bos/internal/tui/components/button"
//	btn := button.New("Primary", button.Primary)
//	btn.Focus()
//	view := btn.View()
package components
