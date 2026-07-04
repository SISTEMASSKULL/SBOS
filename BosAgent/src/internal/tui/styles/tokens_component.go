// Package styles — tokens_component.go: Capa 3 — Estilos lipgloss.
// Todos los estilos usan tokens §11. Reconstruidos por rebuildThemeComponents().
// CERO lipgloss.NewStyle() en pantallas. Solo se usan estos estilos.
//
// CORRECCIONES v1.1:
//   - AppFrame agregado (var declarada aquí, construida en rebuildThemeComponents)
//   - Subtitle duplicado eliminado — queda solo en rebuildThemeComponents
//   - TextBold agregado al bloque de texto
//   - StepFail agregado al stepper
//   - PanelElevated con BorderBackground correcto
//   - Todos los bloques var al nivel de paquete (sin indentación incorrecta)
package styles

import "github.com/charmbracelet/lipgloss"

// ═══════════════════════════════════════════════════════════════════════════════
// APP FRAME — Marco exterior de toda la aplicación (§3.4 del manual de layout)
//
// Borde según tema activo — construido en rebuildThemeComponents().
// Margen exterior: Margin(1, 2) aplicado en View() del Model raíz.
// Padding interno: Padding(1, 2) dentro del borde.
// Width y Height se aplican al render, nunca aquí:
//   AppFrame.Width(frameW).Height(frameH).Render(inner)
// ═══════════════════════════════════════════════════════════════════════════════

var AppFrame lipgloss.Style // reconstruido en rebuildThemeComponents()

// ═══════════════════════════════════════════════════════════════════════════════
// TEXTO — Escala tipográfica (§11: T01–T07)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	Heading     = lipgloss.NewStyle().Foreground(ColorTextHeading).Bold(true)         // T01 — títulos
	Text        = lipgloss.NewStyle().Foreground(ColorTextPrimary)                    // T02 — body, datos
	TextBold    = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true)         // T02 bold
	Subtitle    = lipgloss.NewStyle().Foreground(ColorTextSecondary)                  // T03 — subtítulos
	Muted       = lipgloss.NewStyle().Foreground(ColorTextSecondary)                  // T04 — hints (alias T03)
	Dim         = lipgloss.NewStyle().Foreground(ColorTextMuted)                      // T04 — alias
	Slate       = lipgloss.NewStyle().Foreground(ColorTextMuted)                      // T04 — alias
	Inactive    = lipgloss.NewStyle().Foreground(ColorTextDisabled)                   // T05 — disabled
	DimItalic   = lipgloss.NewStyle().Foreground(ColorTextDisabled).Italic(true)      // T05 italic
	TextLink    = lipgloss.NewStyle().Foreground(ColorTextLink).Underline(true)       // T07 — enlaces
	TextInverse = lipgloss.NewStyle().Foreground(ColorTextInverse)                    // T06 — sobre claro
)

// ═══════════════════════════════════════════════════════════════════════════════
// ACENTO — Cyan (§11: A01–A06)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	Accent        = lipgloss.NewStyle().Foreground(ColorAccent)                       // A01 — cursor, foco
	AccentBold    = lipgloss.NewStyle().Foreground(ColorAccentText).Bold(true)        // A04 — valor positivo bold
	AccentText    = lipgloss.NewStyle().Foreground(ColorAccentText)                   // A04 — valor positivo
	AccentHover   = lipgloss.NewStyle().Foreground(ColorAccentHover)                  // A02 — hover
	AccentPressed = lipgloss.NewStyle().Foreground(ColorAccentPressed)                // A03 — pressed
)

// ═══════════════════════════════════════════════════════════════════════════════
// PANELES / CONTENEDORES (§2.3 Variant + §4 PanelManager)
//
// Patrón Variant{Base, Focused, Blurred, Disabled} del manual.
// Focused/Blurred comparten fondo — solo cambia el color del borde.
// WCAG 2.4.11: foco = borde bright (≥3:1 contraste vs blur).
// Width y Height se aplican al render, nunca en la definición.
// ═══════════════════════════════════════════════════════════════════════════════

var (
	_panelBase = lipgloss.NewStyle().
		BorderStyle(lipgloss.NormalBorder()).
		Background(ColorBgSurface).
		BorderBackground(ColorBgSurface).
		Foreground(ColorTextPrimary).
		Padding(0, 0) // §4.7 compact + BorderBackground = sin hueco borde↔fondo

	// ── Focus / Blur ── mismo fondo, distinto borde ──────────────────────────
	PanelBlurred  = _panelBase.Copy().BorderForeground(ColorBorder)
	PanelFocused  = _panelBase.Copy().BorderForeground(ColorBorderFocus)
	PanelDisabled = _panelBase.Copy().BorderForeground(ColorBorderDisabled).Foreground(ColorTextDisabled)

	// ── Superficies (capas de profundidad) ── mismo borde blur, distinto bg ──
	PanelSurface  = PanelBlurred.Copy() // S02 — bg Slate-800
	PanelElevated = _panelBase.Copy().  // S03
				Background(ColorBgElevated).
				BorderBackground(ColorBgElevated).
				BorderForeground(ColorBorder)
	PanelActive = _panelBase.Copy(). // S05 — bg Slate-600 (seleccionado)
				Background(ColorBgSurfaceActive).
				BorderBackground(ColorBgSurfaceActive).
				BorderForeground(ColorBorder)

	// ── Estados semánticos ── borde coloreado + bg sutil del estado ──────────
	PanelSuccess  = _panelBase.Copy().BorderForeground(ColorStateOKBorder)
	PanelWarning  = _panelBase.Copy().BorderForeground(ColorStateWarnBorder)
	PanelError    = _panelBase.Copy().BorderForeground(ColorStateErrBorder)
	PanelInfo     = _panelBase.Copy().BorderForeground(ColorStateInfoBorder)
	PanelCritical = _panelBase.Copy().
				BorderForeground(ColorStateCritBorder).
				Background(ColorStateCritBg).
				BorderBackground(ColorStateCritBg)

	// ── Aliases de compatibilidad ─────────────────────────────────────────────
	Panel      = PanelBlurred  // alias → PanelBlurred
	PanelHover = PanelElevated // alias → PanelElevated
)

// PanelResolve replica Variant.Resolve del manual §2.3 para paneles.
func PanelResolve(focused, disabled bool) lipgloss.Style {
	switch {
	case disabled:
		return PanelDisabled
	case focused:
		return PanelFocused
	default:
		return PanelBlurred
	}
}

// ═══════════════════════════════════════════════════════════════════════════════
// CAJAS Y BORDES (§11: B01–B10)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	// Box — caja normal con borde redondeado
	Box = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(ColorBorder).
		Padding(0, 1)

	// BoxFocus — caja con foco (WCAG 2.4.11)
	BoxFocus = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(ColorBorderFocus).
		Padding(0, 1)

	// BoxActive — caja activa/seleccionada
	BoxActive = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(ColorAccent).
		Padding(0, 1)

	// BoxError — caja con error
	BoxError = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(ColorInputErrorBorder).
		Padding(0, 1)

	// BoxSuccess — caja con éxito
	BoxSuccess = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(ColorStateOKBorder).
		Padding(0, 1)

	// Divider — línea separadora horizontal
	Divider = lipgloss.NewStyle().Foreground(ColorDivider)

	// DividerStrong — separador prominente
	DividerStrong = lipgloss.NewStyle().Foreground(ColorBorderStrong)

	// PanelDiv — divisor vertical entre paneles (solo borde izquierdo)
	PanelDiv = lipgloss.NewStyle().
		BorderLeft(true).
		BorderStyle(lipgloss.NormalBorder()).
		BorderForeground(ColorBorder).
		PaddingLeft(2)

	// HelpBox — caja de ayuda con borde izquierdo
	HelpBox = lipgloss.NewStyle().
		BorderLeft(true).
		BorderStyle(lipgloss.NormalBorder()).
		BorderForeground(ColorBorder).
		PaddingLeft(2).
		Foreground(ColorTextSecondary)
)

// ═══════════════════════════════════════════════════════════════════════════════
// INPUTS Y FORMULARIOS (§11: F01–F11)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	// Input — campo en reposo (TX01)
	Input = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(ColorInputNormalBorder).
		Background(ColorInputBg).
		BorderBackground(ColorInputBg).
		Padding(0)

	// InputFocus — campo con foco (TX02 — WCAG 2.4.11)
	InputFocus = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(ColorInputFocusBorder).
		Background(ColorInputBg).
		BorderBackground(ColorInputBg).
		Padding(0)

	// InputError — campo con error (TX05)
	InputError = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(ColorInputErrorBorder).
		Background(ColorInputErrorBg).
		BorderBackground(ColorInputErrorBg).
		Padding(0)

	// InputDisabled — campo deshabilitado (TX04)
	InputDisabled = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(ColorInputDisabledBorder).
		Background(ColorInputDisabledBg).
		BorderBackground(ColorInputDisabledBg).
		Padding(0)

	// InputHover — campo con hover (TX03)
	InputHover = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(ColorAccentSubtle).
		Background(ColorBgSurface).
		BorderBackground(ColorBgSurface).
		Foreground(ColorAccentLight).
		Padding(0)

	// InputSuccess — campo con validación OK (TX06)
	InputSuccess = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(ColorStateOKBorder).
		Background(ColorBgSurface).
		BorderBackground(ColorBgSurface).
		Foreground(ColorStateOKFg).
		Padding(0)

	// InputReadOnly — campo solo lectura (TX07)
	InputReadOnly = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(ColorBgElevated).
		Background(ColorBgSurface).
		BorderBackground(ColorBgSurface).
		Foreground(ColorTextSecondary).
		Padding(0)

	// Label — etiqueta de campo
	Label = lipgloss.NewStyle().Foreground(ColorTextMuted).Width(22)

	// LabelActive — etiqueta de campo activo
	LabelActive = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true).Width(22)

	// Placeholder — texto placeholder (TX08)
	Placeholder = lipgloss.NewStyle().Foreground(ColorInputPlaceholder)

	// Cursor — cursor de texto (TX09)
	Cursor = lipgloss.NewStyle().Foreground(ColorAccentText)

	// Aliases de compatibilidad
	InputActive   = InputFocus // alias → InputFocus
	InputInactive = Input      // alias → Input
)

// ═══════════════════════════════════════════════════════════════════════════════
// BOTONES — Variantes Focused/Blurred por tipo (§5.11.1 + §4.7 + WCAG 2.4.11)
//
// TODOS comparten RoundedBorder + Padding(0,0) + Background(ColorBgSurface).
// Background + BorderBackground heredan del panel (S02) — sin hueco negro.
// Solo Primary/Danger cambian el fondo al color de la acción.
// ═══════════════════════════════════════════════════════════════════════════════

var (
	_btnBorder = lipgloss.RoundedBorder()
	_btnPad    = lipgloss.NewStyle().Padding(0, 0) // §4.7 compact

	// BT01 - Primary: bg fijo ColorAccent. Blur: borde más oscuro. Focus: borde bright.
	BtnPrimary = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorAccentBorder).BorderBackground(ColorAccent).
		Foreground(ColorTextInverse).Background(ColorAccent).Bold(true)
	BtnPrimaryFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorAccent).
		Foreground(ColorTextInverse).Background(ColorAccent).Bold(true)

	// BT02 - Secondary: fondo surface, hereda del panel.
	BtnSecondary = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorder).BorderBackground(ColorBgSurface).
		Foreground(ColorTextPrimary).Background(ColorBgSurface)
	BtnSecondaryFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorBgSurface).
		Foreground(ColorAccentText).Bold(true).Background(ColorBgSurface)

	// BT03 - Danger: bg fijo ColorStateCritFg.
	BtnDanger = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorStateCritBorder).BorderBackground(ColorStateCritFg).
		Foreground(ColorTextInverse).Background(ColorStateCritFg).Bold(true)
	BtnDangerFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorStateCritFg).
		Foreground(ColorTextInverse).Background(ColorStateCritFg).Bold(true)

	// BT04 - Ghost: fondo surface, sin relleno de color.
	BtnGhost = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorder).BorderBackground(ColorBgSurface).
		Foreground(ColorTextSecondary).Background(ColorBgSurface)
	BtnGhostFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorBgSurface).
		Foreground(ColorAccentText).Bold(true).Background(ColorBgSurface)

	// BT05 - Disabled: fondo surface, texto muted.
	BtnDisabled = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderDisabled).BorderBackground(ColorBgSurface).
		Foreground(ColorTextDisabled).Background(ColorBgSurface)

	// BtnSpacer — separador entre botones, mismo fondo del panel.
	BtnSpacer = lipgloss.NewStyle().Background(ColorBgSurface)

	// BT06 - Success: bg fijo ColorStateOKFg.
	BtnSuccess = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorStateOKBorder).BorderBackground(ColorStateOKFg).
		Foreground(ColorTextInverse).Background(ColorStateOKFg).Bold(true)
	BtnSuccessFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorStateOKFg).
		Foreground(ColorTextInverse).Background(ColorStateOKFg).Bold(true)

	// BT07 - Warning: fondo surface.
	BtnWarning = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorStateWarnBorder).BorderBackground(ColorBgSurface).
		Foreground(ColorTextPrimary).Background(ColorBgSurface)
	BtnWarningFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorBgSurface).
		Foreground(ColorAccentText).Bold(true).Background(ColorBgSurface)

	// BT08 - Info: fondo surface.
	BtnInfo = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorStateInfoBorder).BorderBackground(ColorBgSurface).
		Foreground(ColorTextPrimary).Background(ColorBgSurface)
	BtnInfoFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorBgSurface).
		Foreground(ColorAccentText).Bold(true).Background(ColorBgSurface)

	// BT09 - Link: sin borde visible, fondo surface.
	BtnLink = lipgloss.NewStyle().Padding(0, 1).
		Foreground(ColorTextLink)
	BtnLinkFocused = lipgloss.NewStyle().Padding(0, 1).
		Foreground(ColorAccentText).Bold(true).Underline(true)

	// BT10 - Icon: fondo surface.
	BtnIcon = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorder).BorderBackground(ColorBgSurface).
		Foreground(ColorTextPrimary).Background(ColorBgSurface)
	BtnIconFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorBgSurface).
		Foreground(ColorAccentText).Bold(true).Background(ColorBgSurface)

	// Aliases de dashboard
	BtnRestart  = BtnWarning
	BtnShutdown = BtnDanger
)

// BtnResolve aplica Variant.Resolve del manual §2.3:
// focused=true → estilo Focused; default → Blurred.
func BtnResolve(blurred, focused lipgloss.Style, isFocused bool) lipgloss.Style {
	if isFocused {
		return focused
	}
	return blurred
}

// ═══════════════════════════════════════════════════════════════════════════════
// MENÚ Y NAVEGACIÓN (§11: M01–M08)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	// MenuItem — item de menú normal
	MenuItem = lipgloss.NewStyle().Foreground(ColorMenuItemNormalFg)

	// MenuItemHover — item de menú con cursor encima
	MenuItemHover = lipgloss.NewStyle().
		Foreground(ColorMenuItemNormalFg).
		Background(ColorMenuItemHoverBg)

	// MenuItemActive — item de menú seleccionado
	MenuItemActive = lipgloss.NewStyle().
		Foreground(ColorMenuItemActiveFg).
		Background(ColorMenuItemActiveBg).
		Bold(true)

	// MenuItemDisabled — item de menú deshabilitado
	MenuItemDisabled = lipgloss.NewStyle().Foreground(ColorMenuItemDisabledFg)

	// MenuSeparator — separador entre items
	MenuSeparator = lipgloss.NewStyle().Foreground(ColorDivider)

	// MenuGroupTitle — título de grupo en menú
	MenuGroupTitle = lipgloss.NewStyle().Foreground(ColorTextMuted).Bold(true)

	// MenuIndicator — barra indicadora de item activo
	MenuIndicator = lipgloss.NewStyle().Foreground(ColorMenuItemActiveIndicator)
)

// ═══════════════════════════════════════════════════════════════════════════════
// TABS / PESTAÑAS (§11: K01–K05)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	// Tab — tab normal
	Tab = lipgloss.NewStyle().Foreground(ColorTextSecondary)

	// TabActive — tab seleccionada
	TabActive = lipgloss.NewStyle().
		Foreground(ColorTextPrimary).
		Bold(true).
		BorderBottom(true).
		BorderForeground(ColorAccent)

	// TabHover — tab con cursor encima
	TabHover = lipgloss.NewStyle().
		Foreground(ColorTextPrimary).
		Background(ColorBgSurfaceHover)

	// TabDisabled — tab deshabilitada
	TabDisabled = lipgloss.NewStyle().Foreground(ColorTextDisabled)
)

// ═══════════════════════════════════════════════════════════════════════════════
// SCROLL (§11: R01–R03)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	ScrollTrack = lipgloss.NewStyle().Foreground(ColorScrollTrack)
	ScrollThumb = lipgloss.NewStyle().Foreground(ColorScrollThumb)
)

// ═══════════════════════════════════════════════════════════════════════════════
// PROGRESO (§11: P01–P03)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	ProgressFill          = lipgloss.NewStyle().Foreground(ColorProgressFill)
	ProgressTrack         = lipgloss.NewStyle().Foreground(ColorProgressTrack)
	ProgressIndeterminate = lipgloss.NewStyle().Foreground(ColorProgressIndeterminate)
)

// ═══════════════════════════════════════════════════════════════════════════════
// BADGES Y CHIPS (§11: G01–G06)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	// Badge — chip/badge normal
	Badge = lipgloss.NewStyle().
		Foreground(ColorAccentText).
		Background(ColorAccentSubtle).
		Padding(0, 1)

	// BadgeCounter — badge numérico (rojo)
	BadgeCounter = lipgloss.NewStyle().
		Foreground(ColorTextHeading).
		Background(ColorStateErrFg).
		Bold(true).
		Padding(0, 1)

	// BadgeDot — indicador de presencia
	BadgeDot = lipgloss.NewStyle().Foreground(ColorAccentText)
)

// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFICACIONES (§11: N01–N12)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	NotifySuccess = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(ColorStateOKBorder).
		Foreground(ColorStateOKFg).
		Background(ColorStateOKBg).
		Padding(0, 1)

	NotifyWarning = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(ColorStateWarnBorder).
		Foreground(ColorStateWarnFg).
		Background(ColorStateWarnBg).
		Padding(0, 1)

	NotifyError = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(ColorStateErrBorder).
		Foreground(ColorStateErrFg).
		Background(ColorStateErrBg).
		Padding(0, 1)

	NotifyInfo = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(ColorStateInfoBorder).
		Foreground(ColorStateInfoFg).
		Background(ColorStateInfoBg).
		Padding(0, 1)
)

// ═══════════════════════════════════════════════════════════════════════════════
// ESTADO — Semáforo perceptual (NO se tematiza)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	Success  = lipgloss.NewStyle().Foreground(ColorStateOKFg).Bold(true)
	Warning  = lipgloss.NewStyle().Foreground(ColorStateWarnFg).Bold(true)
	Error    = lipgloss.NewStyle().Foreground(ColorStateErrFg).Bold(true)
	Info     = lipgloss.NewStyle().Foreground(ColorStateInfoFg)
	Pending  = lipgloss.NewStyle().Foreground(ColorStateIdleFg)
	Disabled = lipgloss.NewStyle().Foreground(ColorStateOffFg)
	Danger   = lipgloss.NewStyle().Foreground(ColorStateCritFg).Bold(true).Underline(true)

	StatusOK   = lipgloss.NewStyle().Foreground(ColorStateOKFg)
	StatusWarn = lipgloss.NewStyle().Foreground(ColorStateWarnFg)
	StatusErr  = lipgloss.NewStyle().Foreground(ColorStateErrFg)
	StatusInfo = lipgloss.NewStyle().Foreground(ColorStateInfoFg)
	StatusCrit = lipgloss.NewStyle().Foreground(ColorStateCritFg)
	StatusIdle = lipgloss.NewStyle().Foreground(ColorStateIdleFg)
	StatusOff  = lipgloss.NewStyle().Foreground(ColorStateOffFg)
)

// ═══════════════════════════════════════════════════════════════════════════════
// TOOLTIP (§11: L01–L03)
// ═══════════════════════════════════════════════════════════════════════════════

var Tooltip = lipgloss.NewStyle().
	Foreground(ColorTextInverse).
	Background(ColorBgTooltip).
	Border(lipgloss.RoundedBorder()).
	BorderForeground(ColorBorder).
	Padding(0, 1)

// ═══════════════════════════════════════════════════════════════════════════════
// STEPPER — Pasos de instalación
// ═══════════════════════════════════════════════════════════════════════════════

var (
	StepOK      = lipgloss.NewStyle().Foreground(ColorAccentText).Bold(true)
	StepActive  = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true)
	StepPending = lipgloss.NewStyle().Foreground(ColorTextDisabled)
	StepFail    = lipgloss.NewStyle().Foreground(ColorStateErrFg).Bold(true) // agregado v1.1
)

// ═══════════════════════════════════════════════════════════════════════════════
// BARRA SUPERIOR / INFERIOR
// Width se aplica al render: TopBar.Width(m.contentW).Render(content)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	TopBar = lipgloss.NewStyle().
		Background(ColorBgBase).
		Foreground(ColorTextHeading).
		Bold(true).
		Padding(0, 1)

	Footer = lipgloss.NewStyle().
		Background(ColorBgSurface).
		Foreground(ColorTextSecondary).
		Padding(0, 1)

	Title = lipgloss.NewStyle().
		Foreground(ColorTextHeading).
		Bold(true).
		Padding(0, 1)

	// TopBar especiales — pantallas de estado crítico
	TopBarRestart  = lipgloss.NewStyle().Background(ColorRestartBg).Foreground(ColorRestartFg).Bold(true).Padding(0, 1)
	TopBarCritical = lipgloss.NewStyle().Background(ColorCriticalBg).Foreground(ColorCriticalFg).Bold(true).Padding(0, 1)
	TopBarGoodbye  = lipgloss.NewStyle().Background(ColorGoodbyeBg).Foreground(ColorGoodbyeFg).Bold(true).Padding(0, 1)
)

// ═══════════════════════════════════════════════════════════════════════════════
// TABLAS
// ═══════════════════════════════════════════════════════════════════════════════

var (
	TableHeader    = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true)
	TableCell      = lipgloss.NewStyle().Foreground(ColorTextPrimary)
	TableCellMuted = lipgloss.NewStyle().Foreground(ColorTextSecondary)
)

// ═══════════════════════════════════════════════════════════════════════════════
// ALIAS — Compatibilidad con código existente
// ═══════════════════════════════════════════════════════════════════════════════

var (
	White        = Heading   // alias → T01
	Bold         = lipgloss.NewStyle().Bold(true)
	Green        = AccentText // alias → A04
	Cyan         = Accent     // alias → A01
	Blue         = lipgloss.NewStyle().Foreground(ColorBlue)
	Indigo       = lipgloss.NewStyle().Foreground(ColorIndigo)
	Red          = StatusErr  // alias → perceptual
	RedText      = lipgloss.NewStyle().Foreground(ColorRed)
	Yellow       = lipgloss.NewStyle().Foreground(ColorYellow)
	Purple       = lipgloss.NewStyle().Foreground(ColorPurple)
	CriticalText = StatusCrit

	DebugText = lipgloss.NewStyle().Foreground(ColorDebugText)
	BosActivo = lipgloss.NewStyle().Foreground(ColorBosActivo)
)

// ── ALIAS 2 — Más compatibilidad ──────────────────────────────────────────────
var (
	MenuItemFocused  = MenuItem       // alias
	MenuItemNormal   = MenuItem       // alias
	WizardMenuActive = MenuItemActive // alias
	ListItemActive   = MenuItemActive // alias
	NotifyBarBg      = Panel          // alias
	Rule             = Divider        // alias
	SectionTitle     = Subtitle       // alias → T03 (Subtitle declarado arriba — sin duplicado)
)

// ── ALIAS 3 — Métricas (usadas por ctrl/) ─────────────────────────────────────
var (
	MetricOK = AccentText // alias → A04 (valor OK)
	MetricTX = AccentText // alias → A04 (métrica TX)
)

// ── ALIAS 5 — Badges y misc ───────────────────────────────────────────────────
var (
	BadgeAccent = Badge
	BadgeSubtle = Badge
	BadgeMuted  = Badge
	CountErr    = StatusErr
	ErrorBanner = NotifyError
)