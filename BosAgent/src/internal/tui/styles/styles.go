// Package styles centraliza estilos, iconos y tokens de color del TUI bos.
// La lógica real vive en los archivos especializados del paquete:
//
//	tokens_primitive.go  — paleta completa 50–950 (PrimXxx, valores hex crudos)
//	tokens_state.go      — colores de estado INDEPENDIENTES (StatusXxx / ColorStateXxx)
//	tokens_semantic.go   — vars ColorXxx (roles de interfaz; usa primitive + state)
//	tokens_component.go  — estilos lipgloss, Badge(), NotifyBar(), RenderMFAToggle()
//	grid.go              — Mode(), ColW(), ContentW(), MarginW()
//	icons.go             — íconos, RawXxx, SpinnerFrames (TUI-LIB-005)
//
// Sistema de color en 3 capas:
//   Capa 1 — PrimXxx       : paleta de marca/diseño (Tailwind-compatible, 50–950)
//   Capa 2 — StatusXxx     : estados UX independientes (WCAG AA, distinguibles)
//   Capa 3 — ColorXxx      : roles semánticos que mapean capa 1 o capa 2 según contexto
package styles

// ── Backward-compat: alias HexXxx → PrimXxx ──────────────────────────────────
// Las pantallas que referencien styles.HexXxx siguen compilando sin cambios.
const (
	HexGreen  = PrimGreen500
	HexCyan   = PrimCyan500
	HexYellow = PrimYellow500
	HexRed    = PrimRed500
	HexDim    = PrimGray500
	HexBlack  = PrimSlate950
	HexWhite  = PrimSlate50
	HexSlate  = PrimSlate700
	HexMuted  = PrimSlate600
	HexBg2    = PrimNavy900
	HexBg3    = PrimSlate800
)
