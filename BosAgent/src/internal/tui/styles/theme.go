// Package styles — theme.go: sistema de temas intercambiable del TUI SBOS.
//
// Arquitectura (ver §7.12 de TUI-MAESTRO.md + SBOS-THEME-ABYSS.md):
//   - Solo la Capa 2B (tokens semánticos de acento + superficie) cambia por tema.
//   - La Capa 1 (primitivos) es la paleta completa — siempre fija.
//   - La Capa 3 (componentes) se reconstruye después de aplicar el tema.
//   - Los colores de estado (OK/Warn/Error/Crit) son perceptuales — NUNCA se tematizan.
//
// Temas disponibles:
//   abyss     — slate profundo + cyan único (identidad Abyss, default nuevo)
//   obsidian  — navy profundo + cyan eléctrico (identidad SBOS clásica)
//   pizarron  — slate azul-gris + cyan brillante (look corporativo neutro)
//   esmeralda — verde soberano
//   indigo    — nocturno violeta
//   fuchsia   — rosa vivaz
//   ambar     — dorado cálido
//
// Uso:
//
//	styles.ApplyTheme("abyss")    // antes de tea.NewProgram()
//	styles.ApplyTheme("")         // → abyss (default)
//
// CORRECCIONES v1.1:
//   - AccentLight, AccentDark, AccentBorder agregados al struct Theme
//   - ApplyTheme muta ColorAccentLight, ColorAccentDark, ColorAccentBorder
//   - Todos los temas actualizados con los tres campos nuevos
//   - AppFrame construido en rebuildThemeComponents() (Normal vs Rounded según tema)
//   - StepFail agregado en rebuildThemeComponents()
//   - ProgressIndeterminate agregado en rebuildThemeComponents()
//   - TopBarRestart/Critical/Goodbye robustecidos con tokens semánticos
package styles

import "github.com/charmbracelet/lipgloss"

// Theme agrupa todos los tokens que varían entre temas.
// Cambiar un tema = cambiar este struct. Sin tocar ninguna pantalla.
type Theme struct {
	Name  string // identificador único — usado en --theme flag y config
	Label string // nombre visible al usuario

	// Tokens de acento — escala completa del color primario del tema
	AccentLight  lipgloss.Color // acento más claro (Cyan-100 equiv) → ColorAccentLight
	AccentText   lipgloss.Color // texto sobre fondo acento (Cyan-400) → ColorAccentText
	Accent       lipgloss.Color // acento principal (Cyan-500) → ColorAccent
	AccentDark   lipgloss.Color // acento oscuro (Cyan-700) → ColorAccentDark
	AccentBorder lipgloss.Color // borde de acento (Cyan-800) → ColorAccentBorder

	// Tokens de superficie — jerarquía de profundidad
	BgBase     lipgloss.Color // fondo base del terminal → ColorBgBase
	BgSurface  lipgloss.Color // paneles, bloques → ColorBgSurface
	BgElevated lipgloss.Color // bordes, separadores elevados → ColorBgElevated

	// Tokens de layout
	TopBarBg lipgloss.Color // fondo de topbar → ColorTopBarBg
	MenuBg   lipgloss.Color // fondo de opción de menú activa → ColorMenuActiveBg

	// Tokens de texto — escala tipográfica del tema
	// Cada tema define sus propios neutros; no todos son slate.
	TextPrimary   lipgloss.Color // texto principal (cabeceras, datos) → ColorTextPrimary
	TextSecondary lipgloss.Color // texto secundario (etiquetas, timestamps) → ColorTextSecondary
	TextDisabled  lipgloss.Color // texto inactivo/deshabilitado (subtle, separadores) → ColorTextDisabled
}

// Themes es el catálogo completo de temas disponibles.
// Para agregar un tema nuevo: una sola entrada aquí. Sin tocar ninguna pantalla.
var Themes = map[string]Theme{

	// ── Abyss — identidad Abyss: slate-950 + cyan único ──────────────────────
	"abyss": {
		Name:          "abyss",
		Label:         "Abyss (slate + cyan)",
		AccentLight:   lipgloss.Color(PrimCyan100),  // #cffafe
		AccentText:    lipgloss.Color(PrimCyan400),  // #22d3ee
		Accent:        lipgloss.Color(PrimCyan500),  // #06b6d4
		AccentDark:    lipgloss.Color(PrimCyan700),  // #0e7490
		AccentBorder:  lipgloss.Color(PrimCyan800),  // #155e75
		BgBase:        lipgloss.Color(PrimSlate950), // #020617
		BgSurface:     lipgloss.Color(PrimSlate900), // #0f172a
		BgElevated:    lipgloss.Color(PrimSlate800), // #1e293b
		TopBarBg:      lipgloss.Color(PrimSlate950), // #020617
		MenuBg:        lipgloss.Color(PrimCyan900),  // #164e63
		TextPrimary:   lipgloss.Color(PrimSlate100), // #f1f5f9 — texto principal
		TextSecondary: lipgloss.Color(PrimSlate400), // #94a3b8 — texto secundario
		TextDisabled:  lipgloss.Color(PrimSlate600), // #475569 — texto inactivo
	},

	// ── Obsidian — identidad SBOS clásica: navy profundo + cyan eléctrico ────
	"obsidian": {
		Name:          "obsidian",
		Label:         "Obsidian (classic SBOS)",
		AccentLight:   lipgloss.Color(PrimCyan100),
		AccentText:    lipgloss.Color(PrimCyan400),
		Accent:        lipgloss.Color(PrimCyan500),
		AccentDark:    lipgloss.Color(PrimCyan700),
		AccentBorder:  lipgloss.Color(PrimCyan800),
		BgBase:        lipgloss.Color(PrimSlate900),
		BgSurface:     lipgloss.Color(PrimNavy900),
		BgElevated:    lipgloss.Color(PrimSlate800),
		TopBarBg:      lipgloss.Color(PrimNavy900),
		MenuBg:        lipgloss.Color(PrimNavy800),
		TextPrimary:   lipgloss.Color(PrimSlate100), // #f1f5f9
		TextSecondary: lipgloss.Color(PrimSlate400), // #94a3b8
		TextDisabled:  lipgloss.Color(PrimSlate600), // #475569
	},

	// ── Pizarrón — slate azul-gris + cyan brillante ───────────────────────────
	"pizarron": {
		Name:          "pizarron",
		Label:         "Pizarrón (slate + cyan brillante)",
		AccentLight:   lipgloss.Color(PrimCyan100),
		AccentText:    lipgloss.Color(PrimCyan300),
		Accent:        lipgloss.Color(PrimCyan400),
		AccentDark:    lipgloss.Color(PrimCyan600),
		AccentBorder:  lipgloss.Color(PrimCyan700),
		BgBase:        lipgloss.Color(PrimSlate900),
		BgSurface:     lipgloss.Color(PrimSlate800),
		BgElevated:    lipgloss.Color(PrimSlate700),
		TopBarBg:      lipgloss.Color(PrimSlate800),
		MenuBg:        lipgloss.Color(PrimSlate700),
		TextPrimary:   lipgloss.Color(PrimSlate100), // #f1f5f9
		TextSecondary: lipgloss.Color(PrimSlate300), // #cbd5e1 — un paso más claro
		TextDisabled:  lipgloss.Color(PrimSlate500), // #64748b
	},

	// ── Esmeralda — verde soberano: dark green forest ─────────────────────────
	"esmeralda": {
		Name:          "esmeralda",
		Label:         "Esmeralda (verde soberano)",
		AccentLight:   lipgloss.Color(PrimGreen100),
		AccentText:    lipgloss.Color(PrimGreen400),
		Accent:        lipgloss.Color(PrimGreen500),
		AccentDark:    lipgloss.Color(PrimGreen700),
		AccentBorder:  lipgloss.Color(PrimGreen800),
		BgBase:        lipgloss.Color(PrimGreen950),
		BgSurface:     lipgloss.Color(PrimGreenBg),
		BgElevated:    lipgloss.Color(PrimGreenDeep),
		TopBarBg:      lipgloss.Color(PrimGreenBg),
		MenuBg:        lipgloss.Color(PrimGreenDeep),
		TextPrimary:   lipgloss.Color(PrimGreen100), // #dcfce7 — texto claro sobre verde oscuro
		TextSecondary: lipgloss.Color(PrimGreen300), // #86efac — verde medio legible
		TextDisabled:  lipgloss.Color(PrimGreen800), // #166534 — verde muy oscuro
	},

	// ── Índigo — nocturno: deep indigo violet ─────────────────────────────────
	"indigo": {
		Name:          "indigo",
		Label:         "Índigo (nocturno)",
		AccentLight:   lipgloss.Color(PrimIndigo100),
		AccentText:    lipgloss.Color(PrimIndigo300),
		Accent:        lipgloss.Color(PrimIndigo400),
		AccentDark:    lipgloss.Color(PrimIndigo600),
		AccentBorder:  lipgloss.Color(PrimIndigo700),
		BgBase:        lipgloss.Color(PrimIndigo950),
		BgSurface:     lipgloss.Color(PrimIndigo950),
		BgElevated:    lipgloss.Color(PrimIndigo900),
		TopBarBg:      lipgloss.Color(PrimIndigo950),
		MenuBg:        lipgloss.Color(PrimIndigo900),
		TextPrimary:   lipgloss.Color(PrimIndigo100), // #e0e7ff — lavanda muy claro
		TextSecondary: lipgloss.Color(PrimIndigo300), // #a5b4fc — lavanda medio
		TextDisabled:  lipgloss.Color(PrimIndigo800), // #3730a3 — indigo oscuro
	},

	// ── Fuchsia — vivid pink: marca alternativa llamativa ─────────────────────
	"fuchsia": {
		Name:          "fuchsia",
		Label:         "Fuchsia (vivaz)",
		AccentLight:   lipgloss.Color(PrimPink100),
		AccentText:    lipgloss.Color(PrimPink400),
		Accent:        lipgloss.Color(PrimPink500),
		AccentDark:    lipgloss.Color(PrimPink700),
		AccentBorder:  lipgloss.Color(PrimPink800),
		BgBase:        lipgloss.Color(PrimPink950),
		BgSurface:     lipgloss.Color(PrimPink950),
		BgElevated:    lipgloss.Color(PrimPink900),
		TopBarBg:      lipgloss.Color(PrimPink950),
		MenuBg:        lipgloss.Color(PrimPink900),
		TextPrimary:   lipgloss.Color(PrimPink50),  // #fdf2f8 — rosa muy pálido
		TextSecondary: lipgloss.Color(PrimPink300), // #f9a8d4 — rosa medio
		TextDisabled:  lipgloss.Color(PrimPink800), // #9d174d — rosa oscuro
	},

	// ── Ámbar — golden warmth: dorado sobre oscuro ────────────────────────────
	"ambar": {
		Name:          "ambar",
		Label:         "Ámbar (dorado cálido)",
		AccentLight:   lipgloss.Color(PrimAmber100),
		AccentText:    lipgloss.Color(PrimAmber300),
		Accent:        lipgloss.Color(PrimAmber400),
		AccentDark:    lipgloss.Color(PrimAmber600),
		AccentBorder:  lipgloss.Color(PrimAmber700),
		BgBase:        lipgloss.Color(PrimAmberBg),
		BgSurface:     lipgloss.Color(PrimAmberBg),
		BgElevated:    lipgloss.Color(PrimAmber900),
		TopBarBg:      lipgloss.Color(PrimAmberBg),
		MenuBg:        lipgloss.Color(PrimAmber900),
		TextPrimary:   lipgloss.Color(PrimAmber50),  // #fffbeb — crema muy claro
		TextSecondary: lipgloss.Color(PrimAmber300), // #fcd34d — dorado medio
		TextDisabled:  lipgloss.Color(PrimAmber900), // #78350f — marrón oscuro
	},
}

// ActiveTheme es el tema activo en esta sesión.
// Se establece una sola vez vía ApplyTheme() antes del loop TEA.
var ActiveTheme = Themes["abyss"]

// ApplyTheme aplica el tema con el ID dado mutando los tokens semánticos
// y reconstruyendo los componentes de Capa 3 que dependen de ellos.
//
// DEBE llamarse antes de tea.NewProgram() — una sola vez, nunca en runtime.
// Si id es vacío o desconocido, aplica "abyss" como fallback.
func ApplyTheme(id string) {
	t, ok := Themes[id]
	if !ok {
		t = Themes["abyss"]
	}
	ActiveTheme = t

	// ── Mutar tokens de acento — escala completa (Capa 2B) ───────────────────
	ColorAccent       = t.Accent
	ColorAccentText   = t.AccentText
	ColorAccentLight  = t.AccentLight  // v1.1 — necesario para temas no-cyan
	ColorAccentDark   = t.AccentDark   // v1.1
	ColorAccentBorder = t.AccentBorder // v1.1

	// ── Mutar tokens de superficie ────────────────────────────────────────────
	ColorBgBase     = t.BgBase
	ColorBgSurface  = t.BgSurface
	ColorBgElevated = t.BgElevated
	ColorBorder     = t.BgElevated // borde = superficie elevada
	ColorBg1        = t.BgBase
	ColorBg2        = t.BgSurface
	ColorBg3        = t.BgElevated
	ColorBlack      = t.BgBase // alias histórico

	// ── Mutar tokens de layout ────────────────────────────────────────────────
	ColorTopBarBg     = t.TopBarBg
	ColorMenuActiveBg = t.MenuBg

	// ── Mutar tokens de texto — escala tipográfica del tema ──────────────────
	// Cada tema define sus propios neutros. Sin esto, Slate/Dim/Muted siempre
	// serían azul-gris (slate) aunque el tema sea verde, índigo o ámbar.
	ColorTextPrimary   = t.TextPrimary
	ColorTextSecondary = t.TextSecondary
	ColorTextDisabled  = t.TextDisabled
	// Mantener aliases históricos alineados con la escala del tema activo
	ColorWhite = t.TextPrimary  // texto principal (no literalmente blanco)
	ColorMuted = t.TextDisabled // texto tenue (alias → disabled del tema)

	// Reconstruir componentes de Capa 3 que leen los tokens mutados
	rebuildThemeComponents()
}

// rebuildThemeComponents reconstruye todos los estilos de Capa 3 (tokens_component.go)
// que dependen de los tokens mutados por ApplyTheme.
//
// REGLA: Todo estilo de pantalla viene de aquí — ninguna pantalla crea lipgloss.NewStyle() inline.
// Se llama automáticamente al final de ApplyTheme(). No llamar manualmente.
func rebuildThemeComponents() {

	// ── APP FRAME (§3.4 del manual de layout) ─────────────────────────────────
	// Borde tipo Normal para temas corporativos (abyss/obsidian/pizarron).
	// Borde tipo Rounded para temas expresivos (esmeralda/indigo/fuchsia/ambar).
	// Width y Height se aplican al render en View() del Model raíz:
	//   lipgloss.NewStyle().Margin(1, 2).Render(AppFrame.Width(frameW).Height(frameH).Render(inner))
	{
		borderStyle := lipgloss.NormalBorder()
		switch ActiveTheme.Name {
		case "esmeralda", "indigo", "fuchsia", "ambar":
			borderStyle = lipgloss.RoundedBorder()
		}
		AppFrame = lipgloss.NewStyle().
			Border(borderStyle).
			BorderForeground(ColorBorder).
			BorderBackground(ColorBgBase).
			Background(ColorBgSurface).
			Padding(1, 2)
	}

	// ═══════════════════════════════════════════════════════════════════════════
	// TEXTO
	// ═══════════════════════════════════════════════════════════════════════════
	Heading     = lipgloss.NewStyle().Foreground(ColorTextHeading).Bold(true)
	Text        = lipgloss.NewStyle().Foreground(ColorTextPrimary)
	TextBold    = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true)
	Subtitle    = lipgloss.NewStyle().Foreground(ColorTextSecondary)
	Muted       = lipgloss.NewStyle().Foreground(ColorTextSecondary)
	Dim         = lipgloss.NewStyle().Foreground(ColorTextMuted)
	Slate       = lipgloss.NewStyle().Foreground(ColorTextMuted)
	Inactive    = lipgloss.NewStyle().Foreground(ColorTextDisabled)
	DimItalic   = lipgloss.NewStyle().Foreground(ColorTextDisabled).Italic(true)
	TextLink    = lipgloss.NewStyle().Foreground(ColorTextLink).Underline(true)
	TextInverse = lipgloss.NewStyle().Foreground(ColorTextInverse)

	// ═══════════════════════════════════════════════════════════════════════════
	// ACENTO
	// ═══════════════════════════════════════════════════════════════════════════
	Accent        = lipgloss.NewStyle().Foreground(ColorAccent)
	AccentBold    = lipgloss.NewStyle().Foreground(ColorAccentText).Bold(true)
	AccentText    = lipgloss.NewStyle().Foreground(ColorAccentText)
	AccentHover   = lipgloss.NewStyle().Foreground(ColorAccentHover)
	AccentPressed = lipgloss.NewStyle().Foreground(ColorAccentPressed)

	// ═══════════════════════════════════════════════════════════════════════════
	// PANELES / CONTENEDORES (§2.3 Variant + §4.7 compact)
	// ═══════════════════════════════════════════════════════════════════════════
	{
		_panelBase := lipgloss.NewStyle().
			BorderStyle(lipgloss.NormalBorder()).
			Background(ColorBgSurface).BorderBackground(ColorBgSurface).
			Foreground(ColorTextPrimary).
			Padding(0, 0)

		PanelBlurred  = _panelBase.Copy().BorderForeground(ColorBorder)
		PanelFocused  = _panelBase.Copy().BorderForeground(ColorBorderFocus)
		PanelDisabled = _panelBase.Copy().BorderForeground(ColorBorderDisabled).Foreground(ColorTextDisabled)
		PanelSurface  = PanelBlurred.Copy()
		PanelElevated = _panelBase.Copy().Background(ColorBgElevated).BorderBackground(ColorBgElevated).BorderForeground(ColorBorder)
		PanelActive   = _panelBase.Copy().Background(ColorBgSurfaceActive).BorderBackground(ColorBgSurfaceActive).BorderForeground(ColorBorder)
		PanelSuccess  = _panelBase.Copy().BorderForeground(ColorStateOKBorder)
		PanelWarning  = _panelBase.Copy().BorderForeground(ColorStateWarnBorder)
		PanelError    = _panelBase.Copy().BorderForeground(ColorStateErrBorder)
		PanelInfo     = _panelBase.Copy().BorderForeground(ColorStateInfoBorder)
		PanelCritical = _panelBase.Copy().BorderForeground(ColorStateCritBorder).Background(ColorStateCritBg).BorderBackground(ColorStateCritBg)
		Panel         = PanelBlurred
		PanelHover    = PanelElevated
	}

	// ═══════════════════════════════════════════════════════════════════════════
	// BORDES
	// ═══════════════════════════════════════════════════════════════════════════
	Box           = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorBorder).Padding(0, 1)
	BoxFocus      = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorBorderFocus).Padding(0, 1)
	BoxActive     = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorAccent).Padding(0, 1)
	BoxError      = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorInputErrorBorder).Padding(0, 1)
	BoxSuccess    = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorStateOKBorder).Padding(0, 1)
	Divider       = lipgloss.NewStyle().Foreground(ColorDivider)
	DividerStrong = lipgloss.NewStyle().Foreground(ColorBorderStrong)
	PanelDiv      = lipgloss.NewStyle().BorderLeft(true).BorderStyle(lipgloss.NormalBorder()).BorderForeground(ColorBorder).PaddingLeft(2)
	HelpBox       = lipgloss.NewStyle().BorderLeft(true).BorderStyle(lipgloss.NormalBorder()).BorderForeground(ColorBorder).PaddingLeft(2).Foreground(ColorTextSecondary)

	// ═══════════════════════════════════════════════════════════════════════════
	// INPUTS / TEXTBOX (§11.15 — TX01–TX10)
	// NormalBorder + Padding(0,0) + Background(ColorBgSurface).
	// Background + BorderBackground fijos (hereda S02).
	// Solo cambian BorderForeground y Foreground entre estados.
	// ═══════════════════════════════════════════════════════════════════════════
	{
		_inputBase := lipgloss.NewStyle().
			Border(lipgloss.NormalBorder()).
			Background(ColorBgSurface).BorderBackground(ColorBgSurface).
			Foreground(ColorTextPrimary).
			Padding(0, 0)

		Input         = _inputBase.Copy().BorderForeground(ColorTextDisabled)                               // TX01
		InputFocus    = _inputBase.Copy().BorderForeground(ColorAccentBorder)                               // TX02
		InputHover    = _inputBase.Copy().BorderForeground(ColorAccentSubtle).Foreground(ColorAccentLight)  // TX03
		InputDisabled = _inputBase.Copy().BorderForeground(ColorTextDisabled).Foreground(ColorTextDisabled) // TX04
		InputError    = lipgloss.NewStyle().Border(lipgloss.NormalBorder()).                                 // TX05 — bg propio
				Background(ColorStateCritBg).BorderBackground(ColorStateCritBg).
				BorderForeground(ColorStateCritBorder).
				Foreground(ColorStateCritFg).Padding(0, 0)
		InputSuccess  = _inputBase.Copy().BorderForeground(ColorStateOKBorder).Foreground(ColorStateOKFg)   // TX06
		InputReadOnly = _inputBase.Copy().BorderForeground(ColorBgElevated).Foreground(ColorTextSecondary)  // TX07

		Label       = lipgloss.NewStyle().Foreground(ColorTextMuted).Width(22)
		LabelActive = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true).Width(22)
		Placeholder = lipgloss.NewStyle().Foreground(ColorAccentDark)   // TX08 — Cyan-700
		Cursor      = lipgloss.NewStyle().Foreground(ColorAccentSubtle) // TX09 — Cyan-900

		InputActive   = InputFocus
		InputInactive = Input
	}

	// ═══════════════════════════════════════════════════════════════════════════
	// BOTONES (§5.11.1 + §4.7 compact)
	// Background + BorderBackground fijos entre focused/blurred.
	// Solo cambian BorderForeground y Foreground/Bold.
	// ═══════════════════════════════════════════════════════════════════════════
	{
		_btnBorder := lipgloss.RoundedBorder()
		_btnPad    := lipgloss.NewStyle().Padding(0, 0).Background(ColorBgSurface).BorderBackground(ColorBgSurface).Align(lipgloss.Center)

		// BT01 - Primary
		BtnPrimary = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorAccentBorder).
			Foreground(ColorAccentBorder).Bold(true)
		BtnPrimaryFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorAccent).
			Foreground(ColorAccent).Bold(true)

		// BT02 - Secondary
		BtnSecondary = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorAccentLight).
			Foreground(ColorAccentLight)
		BtnSecondaryFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorAccentDark).
			Foreground(ColorAccentDark).Bold(true)

		// BT03 - Danger
		BtnDanger = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorStateCritBorder).
			Foreground(ColorStateCritFg).Bold(true)
		BtnDangerFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorStateCritFg).
			Foreground(ColorStateCritBorder).Bold(true)

		// BT04 - Ghost
		BtnGhost = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorTextDisabled).
			Foreground(ColorTextDisabled)
		BtnGhostFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorTextSecondary).
			Foreground(ColorTextDisabled).Bold(true)

		// BT05 - Disabled
		BtnDisabled = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorBorderDisabled).
			Foreground(ColorTextDisabled)

		// BtnSpacer
		BtnSpacer = lipgloss.NewStyle().Background(ColorBgSurface)

		// BT06 - Success
		BtnSuccess = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorStateOKBorder).
			Foreground(lipgloss.Color("#15803d")).Bold(true) // Green-700 spec
		BtnSuccessFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(lipgloss.Color("#166534")). // Green-800 spec
			Foreground(ColorStateOKFg).Bold(true)

		// BT07 - Warning
		BtnWarning = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorStateWarnBorder).
			Foreground(ColorStateWarnFg)
		BtnWarningFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorStateWarnFg).
			Foreground(ColorStateWarnBorder).Bold(true)

		// BT08 - Info
		BtnInfo = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorStateInfoBorder).
			Foreground(ColorStateInfoFg)
		BtnInfoFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorStateInfoFg).
			Foreground(ColorStateInfoBorder).Bold(true)

		// BT09 - Link
		BtnLink = _btnPad.Copy().
			Border(lipgloss.HiddenBorder()).BorderBackground(ColorBgSurface).
			Foreground(ColorAccentDark).Background(ColorBgSurface).Align(lipgloss.Center)
		BtnLinkFocused = _btnPad.Copy().
			Border(lipgloss.HiddenBorder()).BorderBackground(ColorBgSurface).
			Foreground(ColorAccent).Bold(true).Underline(true).Background(ColorBgSurface).Align(lipgloss.Center)

		// BT10 - Icon
		BtnIcon = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorAccentDark).
			Foreground(ColorTextSecondary)
		BtnIconFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorTextSecondary).
			Foreground(ColorAccentDark).Bold(true)

		// Aliases de dashboard
		BtnRestart  = BtnWarning
		BtnShutdown = BtnDanger
	}

	// ═══════════════════════════════════════════════════════════════════════════
	// MENÚ
	// ═══════════════════════════════════════════════════════════════════════════
	MenuItem         = lipgloss.NewStyle().Foreground(ColorMenuItemNormalFg)
	MenuItemHover    = lipgloss.NewStyle().Foreground(ColorMenuItemNormalFg).Background(ColorMenuItemHoverBg)
	MenuItemActive   = lipgloss.NewStyle().Foreground(ColorMenuItemActiveFg).Background(ColorMenuItemActiveBg).Bold(true)
	MenuItemDisabled = lipgloss.NewStyle().Foreground(ColorMenuItemDisabledFg)
	MenuSeparator    = lipgloss.NewStyle().Foreground(ColorDivider)
	MenuGroupTitle   = lipgloss.NewStyle().Foreground(ColorTextMuted).Bold(true)
	MenuIndicator    = lipgloss.NewStyle().Foreground(ColorMenuItemActiveIndicator)

	// ═══════════════════════════════════════════════════════════════════════════
	// TABS
	// ═══════════════════════════════════════════════════════════════════════════
	Tab         = lipgloss.NewStyle().Foreground(ColorTextSecondary)
	TabActive   = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true).BorderBottom(true).BorderForeground(ColorAccent)
	TabHover    = lipgloss.NewStyle().Foreground(ColorTextPrimary).Background(ColorBgSurfaceHover)
	TabDisabled = lipgloss.NewStyle().Foreground(ColorTextDisabled)

	// ═══════════════════════════════════════════════════════════════════════════
	// SCROLL
	// ═══════════════════════════════════════════════════════════════════════════
	ScrollTrack = lipgloss.NewStyle().Foreground(ColorScrollTrack)
	ScrollThumb = lipgloss.NewStyle().Foreground(ColorScrollThumb)

	// ═══════════════════════════════════════════════════════════════════════════
	// PROGRESO
	// ═══════════════════════════════════════════════════════════════════════════
	ProgressFill          = lipgloss.NewStyle().Foreground(ColorProgressFill)
	ProgressTrack         = lipgloss.NewStyle().Foreground(ColorProgressTrack)
	ProgressIndeterminate = lipgloss.NewStyle().Foreground(ColorProgressIndeterminate) // v1.1

	// ═══════════════════════════════════════════════════════════════════════════
	// BADGES
	// ═══════════════════════════════════════════════════════════════════════════
	Badge        = lipgloss.NewStyle().Foreground(ColorAccentText).Background(ColorAccentSubtle).Padding(0, 1)
	BadgeCounter = lipgloss.NewStyle().Foreground(ColorTextHeading).Background(ColorStateErrFg).Bold(true).Padding(0, 1) // v1.1
	BadgeDot     = lipgloss.NewStyle().Foreground(ColorAccentText)                                                        // v1.1

	// ═══════════════════════════════════════════════════════════════════════════
	// NOTIFICACIONES
	// ═══════════════════════════════════════════════════════════════════════════
	NotifySuccess = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorStateOKBorder).Foreground(ColorStateOKFg).Background(ColorStateOKBg).Padding(0, 1)
	NotifyWarning = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorStateWarnBorder).Foreground(ColorStateWarnFg).Background(ColorStateWarnBg).Padding(0, 1)
	NotifyError   = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorStateErrBorder).Foreground(ColorStateErrFg).Background(ColorStateErrBg).Padding(0, 1)
	NotifyInfo    = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorStateInfoBorder).Foreground(ColorStateInfoFg).Background(ColorStateInfoBg).Padding(0, 1)

	// ═══════════════════════════════════════════════════════════════════════════
	// STEPPER
	// ═══════════════════════════════════════════════════════════════════════════
	StepOK      = lipgloss.NewStyle().Foreground(ColorAccentText).Bold(true)
	StepActive  = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true)
	StepPending = lipgloss.NewStyle().Foreground(ColorTextDisabled)
	StepFail    = lipgloss.NewStyle().Foreground(ColorStateErrFg).Bold(true) // v1.1

	// ═══════════════════════════════════════════════════════════════════════════
	// BARRA SUPERIOR / INFERIOR
	// Width se aplica al render: TopBar.Width(m.contentW).Render(content)
	// ═══════════════════════════════════════════════════════════════════════════
	TopBar = lipgloss.NewStyle().Background(ColorBgBase).Foreground(ColorTextHeading).Bold(true).Padding(0, 1)
	Footer = lipgloss.NewStyle().Background(ColorBgSurface).Foreground(ColorTextSecondary).Padding(0, 1)
	Title  = lipgloss.NewStyle().Foreground(ColorTextHeading).Bold(true).Padding(0, 1)

	// ═══════════════════════════════════════════════════════════════════════════
	// TABLAS
	// ═══════════════════════════════════════════════════════════════════════════
	TableHeader    = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true)
	TableCell      = lipgloss.NewStyle().Foreground(ColorTextPrimary)
	TableCellMuted = lipgloss.NewStyle().Foreground(ColorTextSecondary)

	// ═══════════════════════════════════════════════════════════════════════════
	// ALIAS — Compatibilidad
	// ═══════════════════════════════════════════════════════════════════════════
	White             = Heading
	Green             = AccentText
	Cyan              = Accent
	Red               = StatusErr
	MenuItemFocused   = MenuItem
	MenuItemNormal    = MenuItem
	WizardMenuActive  = MenuItemActive
	ListItemActive    = MenuItemActive
	NotifyBarBg       = Panel
	Rule              = Divider
	SectionTitle      = Subtitle
	Tooltip           = lipgloss.NewStyle().Foreground(ColorTextInverse).Background(ColorBgTooltip).Border(lipgloss.RoundedBorder()).BorderForeground(ColorBorder).Padding(0, 1)
	BtnShutdown       = BtnDanger
	BtnRestart        = BtnWarning
	TopBarRestart     = lipgloss.NewStyle().Background(ColorRestartBg).Foreground(ColorRestartFg).Bold(true).Padding(0, 1)
	TopBarCritical    = lipgloss.NewStyle().Background(ColorCriticalBg).Foreground(ColorCriticalFg).Bold(true).Padding(0, 1)
	TopBarGoodbye     = lipgloss.NewStyle().Background(ColorGoodbyeBg).Foreground(ColorGoodbyeFg).Bold(true).Padding(0, 1)
	MetricOK          = AccentText
	MetricTX          = AccentText
	CountErr          = StatusErr
	BadgeAccent       = Badge
	BadgeSubtle       = Badge
	BadgeMuted        = Badge
	ErrorBanner       = NotifyError
	CriticalText      = StatusCrit
	Disabled          = lipgloss.NewStyle().Foreground(ColorStateOffFg)
}