// Package styles — tokens_semantic.go: W3C Design Tokens Nivel 2.
//
// Tokens semánticos: mapean primitivos a ROLES de interfaz con nombre significativo.
// Construidos sobre tokens_primitive.go; usados por tokens_component.go e icons.go.
//
// REGLA: Código de pantallas NUNCA referencia primitivos directamente — solo semánticos.
// Si necesitas un color nuevo, agrega aquí primero; si el primitivo no existe, agrégalo
// en tokens_primitive.go.
package styles

import "github.com/charmbracelet/lipgloss"

var (
	// ════════════════════════════════════════════════════════════════════════════
	// PALETA BASE — Colores de propósito general del sistema
	// ════════════════════════════════════════════════════════════════════════════

	// Colores de acento (identidad SBOS)
	ColorGreen  = lipgloss.Color(PrimGreen500)  // legacy — usar ColorAccentText  // verde principal
	ColorAccent  = lipgloss.Color(PrimCyan400)   // cian identidad
	ColorBlue   = lipgloss.Color(PrimBlue500)   // azul secciones
	ColorIndigo = lipgloss.Color(PrimIndigo500) // índigo acentos secundarios
	ColorPurple = lipgloss.Color(PrimPurple500) // púrpura IA / experimental

	// Colores de estado semántico — apuntan al sistema de estado independiente (tokens_state.go).
	// NUNCA referenciar PrimXxx aquí: los colores de estado son un grupo separado por estándar.
	ColorSuccess  = ColorStateOKFg    // éxito, OK, instalado, confirmado
	ColorWarning  = ColorStateWarnFg  // advertencia, atención, degradado
	ColorError    = ColorStateErrFg   // error, fallo, inválido
	ColorInfo     = ColorStateInfoFg  // informativo, dato del sistema
	ColorPending  = ColorStateIdleFg  // en progreso, esperando, encolado
	ColorCritical = ColorStateCritFg  // acción destructiva, shutdown, irreversible

	// Aliases de color históricos (compatibilidad con código anterior)
	ColorYellow = lipgloss.Color(PrimAmber500) // era PrimYellow500="#f59e0b" = PrimAmber500 ✓
	ColorRed    = lipgloss.Color(PrimRed500)
	ColorDim    = lipgloss.Color(PrimGray500)

	// Tonos neutros
	ColorBlack = lipgloss.Color(PrimSlate900) // fondo más profundo — preserve visual original
	ColorWhite = lipgloss.Color(PrimSlate100) // blanco suave — preserve visual original
	ColorSlate = lipgloss.Color(PrimSlate700) // bordes, divisores
	ColorMuted = lipgloss.Color(PrimSlate600) // texto tenue, timestamps

	// Fondos estructurales (capas de profundidad)
	ColorBg1 = lipgloss.Color(PrimSlate900)  // fondo base (mismo que ColorBlack)
	ColorBg2 = lipgloss.Color(PrimNavy900)   // fondo nivel 2 — paneles, topbar
	ColorBg3 = lipgloss.Color(PrimSlate800)  // fondo nivel 3 — divisores, secciones

	// ════════════════════════════════════════════════════════════════════════════
	// ESTRUCTURA DE PANTALLA — Componentes del layout principal
	// ════════════════════════════════════════════════════════════════════════════

	ColorTopBarBg     = lipgloss.Color(PrimGreen900) // TopBar fondo — verde oscuro identidad
	ColorSubtitle     = lipgloss.Color(PrimSlate400) // subtítulos, labels tenues
	ColorHelpBorder   = lipgloss.Color(PrimNavyHelp) // borde lateral HelpBox
	ColorMenuActiveBg = lipgloss.Color(PrimNavy800)  // fondo opción de menú activa

	// ════════════════════════════════════════════════════════════════════════════
	// ESTADOS DEL SISTEMA — TopBar dinámico según contexto
	// ════════════════════════════════════════════════════════════════════════════

	ColorRestartBg  = lipgloss.Color(PrimAmberBg)  // TopBar modo reinicio — fondo
	ColorRestartFg  = lipgloss.Color(PrimAmber200) // TopBar modo reinicio — texto
	ColorCriticalBg = lipgloss.Color(PrimRedBg)    // TopBar shutdown crítico — fondo
	ColorCriticalFg = lipgloss.Color(PrimRed300)   // TopBar shutdown crítico — texto
	ColorGoodbyeBg  = lipgloss.Color(PrimGreenBg)  // TopBar goodbye — fondo (verde casi negro)
	ColorGoodbyeFg  = lipgloss.Color(PrimGreen800) // TopBar goodbye — texto
	ColorBosActivo  = lipgloss.Color(PrimGreen300) // indicador "bos activo" en dashboard

	// Botones de poder del dashboard (BottomBar)
	ColorBtnRestartFg  = lipgloss.Color(PrimSky100)  // botón Reiniciar — texto (cian muy claro)
	ColorBtnRestartBg  = lipgloss.Color(PrimBlueRow) // botón Reiniciar — fondo (navy azul)
	ColorBtnShutdownFg = lipgloss.Color(PrimRed100)  // botón Apagar — texto (rojo muy claro)
	ColorBtnShutdownBg = lipgloss.Color(PrimRedRow)  // botón Apagar — fondo (rojo oscuro)

	// ════════════════════════════════════════════════════════════════════════════
	// PANTALLA DE INSTALACIÓN — S05, banners, log viewer
	// ════════════════════════════════════════════════════════════════════════════

	ColorOKBannerFg  = lipgloss.Color(PrimGreen200)  // banner éxito — texto (verde claro)
	ColorOKBannerBg  = lipgloss.Color(PrimGreenDeep) // banner éxito — fondo oscuro custom
	ColorHeader      = lipgloss.Color(PrimSlate200)  // encabezados de sección
	ColorErrorBorder = lipgloss.Color(PrimRed900)    // panel error — borde
	ColorErrorBg     = lipgloss.Color(PrimRedBg)     // panel error — fondo custom
	ColorLogFilter   = lipgloss.Color(PrimSky400)    // etiqueta filtro "Todos" en log
	ColorDebugText   = lipgloss.Color(PrimSlate500)  // texto categoría DEBUG (muted)

	// ════════════════════════════════════════════════════════════════════════════
	// TABLAS DE DATOS — Estilos para filas con estado
	// ════════════════════════════════════════════════════════════════════════════

	ColorTableSelFg = lipgloss.Color(PrimBlue100)  // fila seleccionada — texto (azul claro)
	ColorTableSelBg = lipgloss.Color(PrimBlueRow)  // fila seleccionada — fondo custom
	ColorTableErrFg = lipgloss.Color(PrimRed50)    // fila de error — texto (rojo muy claro)
	ColorTableErrBg = lipgloss.Color(PrimRedRow)   // fila de error — fondo custom

	// ════════════════════════════════════════════════════════════════════════════
	// TIPOGRAFÍA ESPECIAL — Títulos de marca y sección
	// ════════════════════════════════════════════════════════════════════════════

	ColorProductTitle = lipgloss.Color(PrimGreen400) // título producto en splash (verde vivo)
	ColorSectionTitle = lipgloss.Color(PrimBlue500)  // título de sección en wizard
	ColorPureWhite    = lipgloss.Color(PrimWhite)    // blanco puro — cabeceras de tabla

	// ════════════════════════════════════════════════════════════════════════════
	// AUTH / FORMULARIOS — Pantallas P12 y P13
	// ════════════════════════════════════════════════════════════════════════════

	ColorAuthBorder       = lipgloss.Color(PrimIndigo700) // borde formulario de login (identidad de marca, no estado)
	ColorAuthBorderActive = lipgloss.Color(PrimCyan500)   // borde campo activo (identidad de marca, no estado)
	ColorAuthError        = ColorStateErrFg               // error de autenticación — usa sistema de estado
	ColorStepUpBg         = ColorStateCritBg              // fondo step-up — acción destructiva → sistema estado Critical
	ColorStepUpBorder     = ColorStateCritBorder          // borde step-up — sistema estado Critical

	// ════════════════════════════════════════════════════════════════════════════
	// NOTIFICACIONES / INLINE FEEDBACK — Mensajes dentro de pantallas
	// ════════════════════════════════════════════════════════════════════════════

	// Notificaciones inline — también usan el sistema de estado independiente.
	ColorNotifySuccess = ColorStateOKFg              // notificación de éxito
	ColorNotifyWarn    = ColorStateWarnFg            // notificación de advertencia
	ColorNotifyError   = ColorStateErrFg             // notificación de error
	ColorNotifyInfo    = ColorStateInfoFg            // notificación informativa
	ColorNotifyBg      = lipgloss.Color(PrimSlate800) // fondo de barra — sí es primitiva: es estructural, no de estado

	// ════════════════════════════════════════════════════════════════════════════
	// SISTEMA ABYSS — Tokens semánticos del theme Abyss (mutables por ApplyTheme)
	// Compatibles con todos los themes: defaults = valores obsidian equivalentes.
	// ════════════════════════════════════════════════════════════════════════════

	// Capas de superficie (jerarquía de profundidad)
	ColorBgBase     = lipgloss.Color(PrimSlate900)  // fondo base del terminal
	ColorBgSurface  = lipgloss.Color(PrimSlate800)   // paneles, bloques, listas
	ColorBgElevated = lipgloss.Color(PrimSlate800)  // bordes, separadores, secciones

	// Bordes
	ColorBorder       = lipgloss.Color(PrimSlate700) // borde principal
	ColorBorderSubtle = lipgloss.Color(PrimSlate700) // borde suave / input

	// Acento extendido (escala completa para badges, sparklines, etc.)
	ColorAccentLight  = lipgloss.Color(PrimCyan100)  // acento mas claro — themed
	ColorAccentDark   = lipgloss.Color(PrimCyan700)  // acento oscuro — themed
	ColorAccentSubtle = lipgloss.Color(PrimCyan900)  // fondo badge / seleccion sutil
	ColorAccentBorder = lipgloss.Color(PrimCyan800)  // borde badge activo — themed
	// ── Texto (§11) ──────────────────────────────────────────────────────
	ColorTextHeading   = lipgloss.Color(PrimCyan300)  // T01 — títulos, TopBar fg
	ColorTextLink      = lipgloss.Color(PrimCyan400)  // T07 — enlaces
	ColorTextInverse   = lipgloss.Color(PrimSlate900)  // T06 — texto sobre fondo claro
	
	// ── Superficies (§11) ──────────────────────────────────────────────────
	ColorBgSurfaceHover  = lipgloss.Color(PrimSlate800)  // S04 — panel hover
	ColorBgSurfaceActive = lipgloss.Color(PrimSlate700)  // S05 — panel active
	ColorBgInputDisabled = lipgloss.Color(PrimSlate900)  // S07 — input disabled bg
	ColorBgTooltip      = lipgloss.Color(PrimSlate300)  // S09 — tooltip bg
	
	// ── Bordes (§11) ───────────────────────────────────────────────────────
	ColorDivider       = lipgloss.Color(PrimSlate700)  // B10 — separador
	ColorBorderFocus   = lipgloss.Color(PrimCyan500)   // B02 — foco WCAG
	ColorBorderHover   = lipgloss.Color(PrimSlate600)  // B03 — hover
	ColorBorderStrong  = lipgloss.Color(PrimSlate500)  // B09 — borde prominente
	ColorBorderDisabled = lipgloss.Color(PrimSlate600)  // B07 — borde deshabilitado (#475569)
	
	// ── Acento (§11) ───────────────────────────────────────────────────────
	ColorAccentHover   = lipgloss.Color(PrimCyan300)   // A02 — hover
	ColorAccentPressed = lipgloss.Color(PrimCyan500)   // A03 — pressed
	
	// ── Scroll (§11) ──────────────────────────────────────────────────────
	ColorScrollTrack = lipgloss.Color(PrimSlate800)  // R01 — track
	ColorScrollThumb = lipgloss.Color(PrimSlate600)  // R02 — thumb
	
	// ── Progreso (§11) ─────────────────────────────────────────────────────
	ColorProgressFill  = lipgloss.Color(PrimCyan600)   // P01 — relleno
	ColorProgressTrack = lipgloss.Color(PrimSlate800)  // P02 — track
	ColorProgressIndeterminate = lipgloss.Color(PrimCyan700)  // P03
	
	// ── Formularios (§11) ──────────────────────────────────────────────────
	ColorInputBg              = lipgloss.Color(PrimSlate900)  // F01 — input bg
	ColorInputNormalBorder    = lipgloss.Color(PrimSlate700)  // F02 — border normal
	ColorInputFocusBorder     = lipgloss.Color(PrimCyan600)   // F04 — border focus
	ColorInputPlaceholder     = lipgloss.Color(PrimSlate600)  // F09 — placeholder
	ColorInputErrorBg         = lipgloss.Color(PrimSlate950)  // F05 — error bg
	ColorInputErrorBorder     = lipgloss.Color(StatusErrFg)   // F06 — error border
	ColorInputDisabledBg      = lipgloss.Color(PrimSlate900)  // F07 — disabled bg
	ColorInputDisabledBorder  = lipgloss.Color(PrimSlate700)  // F08 — disabled border
	
	// ── Menú (§11) ────────────────────────────────────────────────────────
	ColorMenuItemNormalFg     = lipgloss.Color(PrimCyan500)   // M01 — normal fg
	ColorMenuItemActiveFg     = lipgloss.Color(PrimCyan400)   // M03 — active fg
	ColorMenuItemActiveBg     = lipgloss.Color(PrimCyan900)   // M04 — active bg
	ColorMenuItemActiveIndicator = lipgloss.Color(PrimCyan500) // M05 — indicator
	ColorMenuItemHoverBg      = lipgloss.Color(PrimSlate800)  // M02 — hover bg
	ColorMenuItemDisabledFg   = lipgloss.Color(PrimCyan700)   // M06 — disabled fg
	ColorAccentDim    = lipgloss.Color(PrimCyan700)  // sparkline nivel medio
	ColorAccentBright = lipgloss.Color(PrimCyan300)  // texto en badge oscuro
	ColorAccentText   = lipgloss.Color(PrimCyan400)  // texto sobre fondo accent

	// Escala de texto (todos los roles de tipografía)
	ColorTextPrimary   = lipgloss.Color(PrimCyan400) // texto primario (= ColorWhite)
	ColorTextSecondary = lipgloss.Color(PrimCyan500) // texto secundario (= ColorSubtitle)
	ColorTextDisabled  = lipgloss.Color(PrimCyan700) // texto deshabilitado (= ColorMuted +1 tono)
	ColorTextMuted     = lipgloss.Color(PrimCyan600)   // T04 — hints, metadatos
)
