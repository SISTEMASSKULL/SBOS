# SBOS Theme System — Código completo

> Orden de dependencias: primitives → state → semantic → icons → components → theme

---

## `/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/internal/tui/styles/tokens_primitive.go`

```go
// Package styles — tokens_primitive.go: W3C Design Tokens Nivel 1.
//
// Paleta de color completa (50–950) compatible con Tailwind CSS v3 para cada familia.
// Ningún hex literal debe aparecer fuera de este archivo.
//
// ORGANIZACIÓN:
//   1. Paletas estándar completas (50–950)  — los 100% compatibles con Tailwind
//   2. Paletas SBOS extendidas              — custom para el sistema de diseño del proyecto
//   3. Aliases de migración                 — nombres heredados del código anterior
//
// CONVENCIÓN:
//   PrimXxx{N}    → paso estándar de la paleta (50–950)
//   PrimXxxBrand  → tono custom SBOS que no cae en paso estándar
//   HexXxx        → alias de compatibilidad (no usar en código nuevo)
package styles

const (
	// ════════════════════════════════════════════════════════════════════════════
	// PALETAS ESTÁNDAR 50–950 (Tailwind CSS v3 compatible)
	// ════════════════════════════════════════════════════════════════════════════

	// ── Slate — gris azulado neutro, fondos y texto base ────────────────────────
	PrimSlate50  = "#f8fafc"
	PrimSlate100 = "#f1f5f9"
	PrimSlate200 = "#e2e8f0"
	PrimSlate300 = "#cbd5e1"
	PrimSlate400 = "#94a3b8"
	PrimSlate500 = "#64748b"
	PrimSlate600 = "#475569"
	PrimSlate700 = "#334155"
	PrimSlate800 = "#1e293b"
	PrimSlate900 = "#0f172a"
	PrimSlate950 = "#020617"

	// ── Gray — gris neutro puro ─────────────────────────────────────────────────
	PrimGray50  = "#f9fafb"
	PrimGray100 = "#f3f4f6"
	PrimGray200 = "#e5e7eb"
	PrimGray300 = "#d1d5db"
	PrimGray400 = "#9ca3af"
	PrimGray500 = "#6b7280"
	PrimGray600 = "#4b5563"
	PrimGray700 = "#374151"
	PrimGray800 = "#1f2937"
	PrimGray900 = "#111827"
	PrimGray950 = "#030712"

	// ── Zinc — gris con tinte metálico ──────────────────────────────────────────
	PrimZinc50  = "#fafafa"
	PrimZinc100 = "#f4f4f5"
	PrimZinc200 = "#e4e4e7"
	PrimZinc300 = "#d4d4d8"
	PrimZinc400 = "#a1a1aa"
	PrimZinc500 = "#71717a"
	PrimZinc600 = "#52525b"
	PrimZinc700 = "#3f3f46"
	PrimZinc800 = "#27272a"
	PrimZinc900 = "#18181b"
	PrimZinc950 = "#09090b"

	// ── Green — verde primario del SBOS ─────────────────────────────────────────
	PrimGreen50  = "#f0fdf4"
	PrimGreen100 = "#dcfce7"
	PrimGreen200 = "#bbf7d0"
	PrimGreen300 = "#86efac"
	PrimGreen400 = "#4ade80"
	PrimGreen500 = "#22c55e"
	PrimGreen600 = "#16a34a"
	PrimGreen700 = "#15803d"
	PrimGreen800 = "#166534"
	PrimGreen900 = "#14532d"
	PrimGreen950 = "#052e16"

	// ── Emerald — variante más fría del verde ────────────────────────────────────
	PrimEmerald50  = "#ecfdf5"
	PrimEmerald100 = "#d1fae5"
	PrimEmerald200 = "#a7f3d0"
	PrimEmerald300 = "#6ee7b7"
	PrimEmerald400 = "#34d399"
	PrimEmerald500 = "#10b981"
	PrimEmerald600 = "#059669"
	PrimEmerald700 = "#047857"
	PrimEmerald800 = "#065f46"
	PrimEmerald900 = "#064e3b"
	PrimEmerald950 = "#022c22"

	// ── Teal — verde-cian para status y tags ────────────────────────────────────
	PrimTeal50  = "#f0fdfa"
	PrimTeal100 = "#ccfbf1"
	PrimTeal200 = "#99f6e4"
	PrimTeal300 = "#5eead4"
	PrimTeal400 = "#2dd4bf"
	PrimTeal500 = "#14b8a6"
	PrimTeal600 = "#0d9488"
	PrimTeal700 = "#0f766e"
	PrimTeal800 = "#115e59"
	PrimTeal900 = "#134e4a"
	PrimTeal950 = "#042f2e"

	// ── Cyan — cian principal del SBOS (identidad) ──────────────────────────────
	PrimCyan50  = "#ecfeff"
	PrimCyan100 = "#cffafe"
	PrimCyan200 = "#a5f3fc"
	PrimCyan300 = "#67e8f9"
	PrimCyan400 = "#22d3ee"
	PrimCyan500 = "#06b6d4"
	PrimCyan600 = "#0891b2"
	PrimCyan700 = "#0e7490"
	PrimCyan800 = "#155e75"
	PrimCyan900 = "#164e63"
	PrimCyan950 = "#083344"

	// ── Sky — azul cielo, log viewer y filtros ──────────────────────────────────
	PrimSky50  = "#f0f9ff"
	PrimSky100 = "#e0f2fe"
	PrimSky200 = "#bae6fd"
	PrimSky300 = "#7dd3fc"
	PrimSky400 = "#38bdf8"
	PrimSky500 = "#0ea5e9"
	PrimSky600 = "#0284c7"
	PrimSky700 = "#0369a1"
	PrimSky800 = "#075985"
	PrimSky900 = "#0c4a6e"
	PrimSky950 = "#082f49"

	// ── Blue — azul profundo, secciones y títulos ────────────────────────────────
	PrimBlue50  = "#eff6ff"
	PrimBlue100 = "#dbeafe"
	PrimBlue200 = "#bfdbfe"
	PrimBlue300 = "#93c5fd"
	PrimBlue400 = "#60a5fa"
	PrimBlue500 = "#3b82f6"
	PrimBlue600 = "#2563eb"
	PrimBlue700 = "#1d4ed8"
	PrimBlue800 = "#1e40af"
	PrimBlue900 = "#1e3a8a"
	PrimBlue950 = "#172554"

	// ── Indigo — acciones secundarias, step-up, badges ──────────────────────────
	PrimIndigo50  = "#eef2ff"
	PrimIndigo100 = "#e0e7ff"
	PrimIndigo200 = "#c7d2fe"
	PrimIndigo300 = "#a5b4fc"
	PrimIndigo400 = "#818cf8"
	PrimIndigo500 = "#6366f1"
	PrimIndigo600 = "#4f46e5"
	PrimIndigo700 = "#4338ca"
	PrimIndigo800 = "#3730a3"
	PrimIndigo900 = "#312e81"
	PrimIndigo950 = "#1e1b4b"

	// ── Violet — hover states, selección activa ──────────────────────────────────
	PrimViolet50  = "#f5f3ff"
	PrimViolet100 = "#ede9fe"
	PrimViolet200 = "#ddd6fe"
	PrimViolet300 = "#c4b5fd"
	PrimViolet400 = "#a78bfa"
	PrimViolet500 = "#8b5cf6"
	PrimViolet600 = "#7c3aed"
	PrimViolet700 = "#6d28d9"
	PrimViolet800 = "#5b21b6"
	PrimViolet900 = "#4c1d95"
	PrimViolet950 = "#2e1065"

	// ── Purple — elementos IA, bCompass, experimental ────────────────────────────
	PrimPurple50  = "#faf5ff"
	PrimPurple100 = "#f3e8ff"
	PrimPurple200 = "#e9d5ff"
	PrimPurple300 = "#d8b4fe"
	PrimPurple400 = "#c084fc"
	PrimPurple500 = "#a855f7"
	PrimPurple600 = "#9333ea"
	PrimPurple700 = "#7e22ce"
	PrimPurple800 = "#6b21a8"
	PrimPurple900 = "#581c87"
	PrimPurple950 = "#3b0764"

	// ── Pink — alertas soft, notificaciones bnotify ──────────────────────────────
	PrimPink50  = "#fdf2f8"
	PrimPink100 = "#fce7f3"
	PrimPink200 = "#fbcfe8"
	PrimPink300 = "#f9a8d4"
	PrimPink400 = "#f472b6"
	PrimPink500 = "#ec4899"
	PrimPink600 = "#db2777"
	PrimPink700 = "#be185d"
	PrimPink800 = "#9d174d"
	PrimPink900 = "#831843"
	PrimPink950 = "#500724"

	// ── Red — errores, alertas críticas, shutdown ────────────────────────────────
	PrimRed50  = "#fef2f2"
	PrimRed100 = "#fee2e2"
	PrimRed200 = "#fecaca"
	PrimRed300 = "#fca5a5"
	PrimRed400 = "#f87171"
	PrimRed500 = "#ef4444"
	PrimRed600 = "#dc2626"
	PrimRed700 = "#b91c1c"
	PrimRed800 = "#991b1b"
	PrimRed900 = "#7f1d1d"
	PrimRed950 = "#450a0a"

	// ── Orange — advertencias de hardware, eventos nexus ────────────────────────
	PrimOrange50  = "#fff7ed"
	PrimOrange100 = "#ffedd5"
	PrimOrange200 = "#fed7aa"
	PrimOrange300 = "#fdba74"
	PrimOrange400 = "#fb923c"
	PrimOrange500 = "#f97316"
	PrimOrange600 = "#ea580c"
	PrimOrange700 = "#c2410c"
	PrimOrange800 = "#9a3412"
	PrimOrange900 = "#7c2d12"
	PrimOrange950 = "#431407"

	// ── Amber — modo restart, advertencias ──────────────────────────────────────
	PrimAmber50  = "#fffbeb"
	PrimAmber100 = "#fef3c7"
	PrimAmber200 = "#fde68a"
	PrimAmber300 = "#fcd34d"
	PrimAmber400 = "#fbbf24"
	PrimAmber500 = "#f59e0b"
	PrimAmber600 = "#d97706"
	PrimAmber700 = "#b45309"
	PrimAmber800 = "#92400e"
	PrimAmber900 = "#78350f"
	PrimAmber950 = "#451a03"

	// ── Yellow — highlights, tips, step active ──────────────────────────────────
	PrimYellow50  = "#fefce8"
	PrimYellow100 = "#fef9c3"
	PrimYellow200 = "#fef08a"
	PrimYellow300 = "#fde047"
	PrimYellow400 = "#facc15"
	PrimYellow500 = "#eab308"
	PrimYellow600 = "#ca8a04"
	PrimYellow700 = "#a16207"
	PrimYellow800 = "#854d0e"
	PrimYellow900 = "#713f12"
	PrimYellow950 = "#422006"

	// ── White / Black absolutos ──────────────────────────────────────────────────
	PrimWhite = "#ffffff"
	PrimBlack = "#000000"

	// ════════════════════════════════════════════════════════════════════════════
	// PALETA NAVY — Custom SBOS (no existe en Tailwind)
	// Azul marino profundo para fondos de UI, menús activos, paneles.
	// Progresión alineada con los valores existentes en los pasos 800 y 900.
	// ════════════════════════════════════════════════════════════════════════════
	PrimNavy50  = "#f0f5ff"
	PrimNavy100 = "#e0eaf7"
	PrimNavy200 = "#c0d5ef"
	PrimNavy300 = "#95b5e0"
	PrimNavy400 = "#6491cc"
	PrimNavy500 = "#3a6db5"
	PrimNavy600 = "#2b5090"
	PrimNavy700 = "#1e3a6e"
	PrimNavy800 = "#0f2433" // ColorMenuActiveBg, tabs
	PrimNavy900 = "#0c1525" // ColorBg2
	PrimNavy950 = "#060d18"

	// ── Navy custom (sin paso estándar equivalente) ──────────────────────────────
	PrimNavyHelp = "#1e3a5f" // borde HelpBox — entre Navy700 y Navy800

	// ════════════════════════════════════════════════════════════════════════════
	// CUSTOM SBOS — Fondos especiales que no caen en ningún paso de paleta
	// ════════════════════════════════════════════════════════════════════════════

	// Green custom
	PrimGreenBg    = "#0c1a0c" // topbar goodbye — bg (entre Green-950 y pure black)
	PrimGreenDeep  = "#0e3a1a" // banner éxito — fondo oscuro (entre Green-950 y pure black)
	PrimGreenBadge = "#0a1f12" // wizard badge verde — bg

	// Blue custom (tabla / UI components)
	PrimBlueRow   = "#1a3a5c" // tabla — fila seleccionada bg
	PrimBlueBadge = "#0c1a2e" // wizard badge azul — bg

	// Amber custom
	PrimAmberBg    = "#1c1003" // topbar modo restart — bg
	PrimAmberBadge = "#1c0f03" // wizard badge amarillo — bg

	// Red custom
	PrimRedBg  = "#1a0808" // topbar shutdown / panel error — bg
	PrimRedRow = "#5c1a1a" // tabla — fila de error bg

	// ════════════════════════════════════════════════════════════════════════════
	// ALIASES DE MIGRACIÓN — Nombres heredados, usar sólo si rompe código nuevo.
	// En código nuevo referenciar siempre la paleta estándar (PrimXxx{N}).
	// ════════════════════════════════════════════════════════════════════════════

	// Amber500 era usado como "amarillo principal" (en Tailwind Amber-500 = #f59e0b)
	// El PrimYellow500 anterior (mismo valor) queda reemplazado por PrimAmber500.
	PrimYellow500Legacy = PrimAmber500 // era "#f59e0b" — ahora usar PrimAmber500

	// Slate aliases: el código anterior nombraba Slate-50 al valor que Tailwind
	// asigna a Slate-100, y Slate-950 al valor de Slate-900.
	// Los nombres PrimSlateXX ahora apuntan a valores estándar Tailwind.
	// Si algún código dependía del valor anterior:
	//   PrimSlate50  era "#f1f5f9" → usar PrimSlate100
	//   PrimSlate950 era "#0f172a" → usar PrimSlate900

	// Green aliases: PrimGreen100 era "#bbf7d0" (Tailwind Green-200).
	// Ahora PrimGreen100 = "#dcfce7" (correcto), PrimGreen200 = "#bbf7d0".
	// Si algún código usaba el valor anterior de PrimGreen100:
	//   PrimGreen100Legacy = PrimGreen200 — ya no se necesita, queda como doc.
)
```

---

## `/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/internal/tui/styles/tokens_state.go`

```go
// Package styles — tokens_state.go: Sistema de Colores de Estado.
//
// LOS COLORES DE ESTADO SON UN GRUPO INDEPENDIENTE.
//
// No derivan de la paleta primitiva (tokens_primitive.go). Cada valor fue elegido
// específicamente para cumplir tres criterios simultaneos:
//
//  1. WCAG AA mínimo 4.5:1 sobre fondo oscuro (#0f172a) — texto de tamaño normal
//  2. Distinguibilidad perceptual — cada estado es claramente diferente al resto
//  3. Semántica universal — alineado con IBM Carbon, Material Design 3, WCAG 2.2
//
// Organización por estado:
//
//	StatusOK     → operación exitosa, saludable, confirmado, instalado
//	StatusWarn   → atención requerida, degradado, reintento, advertencia
//	StatusErr    → fallo, inválido, no encontrado, rechazado
//	StatusInfo   → informativo, neutro, datos del sistema
//	StatusCrit   → acción destructiva, shutdown, eliminación, irreversible
//	StatusIdle   → en progreso, cargando, esperando, encolado
//	StatusOff    → deshabilitado, bloqueado, inactivo, sin licencia
//
// Cada estado tiene 4 tokens:
//
//	{State}Fg     → texto / ícono sobre fondo oscuro (brillo alto)
//	{State}Subtle → texto secundario del mismo estado (brillo medio)
//	{State}Bg     → relleno de bloque / caja de mensaje (tinte muy oscuro)
//	{State}Border → borde / ring de foco (brillo medio-alto)
package styles

import "github.com/charmbracelet/lipgloss"

// ════════════════════════════════════════════════════════════════════════════
// NIVEL 1 — Primitivos de Estado (hex independientes de paleta)
// ════════════════════════════════════════════════════════════════════════════

const (
	// ── StatusOK — éxito, saludable, instalado, confirmado ──────────────────
	// Familia teal-verde (hue ~160°), distinto del verde de marca SBOS (hue ~145°)
	StatusOKFg     = "#2dd4a2" // teal-verde vivo     — contraste ~9.8:1 sobre #0f172a
	StatusOKSubtle = "#6ee6c5" // teal-verde suave     — contraste ~14.4:1
	StatusOKBg     = "#051a10" // teal muy oscuro       — fondo de bloque OK
	StatusOKBorder = "#0a9e62" // teal-verde medio      — borde de caja OK

	// ── StatusWarn — advertencia, atención, degradado, reintento ─────────────
	// Familia dorado-ámbar (hue ~42°), temperatura cálida = "precaución"
	StatusWarnFg     = "#f9c84a" // dorado vivo          — contraste ~10.8:1
	StatusWarnSubtle = "#fbd97a" // dorado suave          — contraste ~13.8:1
	StatusWarnBg     = "#1a1100" // ámbar muy oscuro      — fondo de bloque Warn
	StatusWarnBorder = "#a87b00" // dorado medio          — borde de caja Warn

	// ── StatusErr — error, fallo, inválido, rechazado ─────────────────────────
	// Familia coral-rojo (hue ~0°), temperatura fría = "fallo"
	StatusErrFg     = "#f87474" // coral rojo vivo      — contraste ~6.1:1
	StatusErrSubtle = "#faabab" // coral suave           — contraste ~9.8:1
	StatusErrBg     = "#1a0505" // rojo muy oscuro       — fondo de bloque Error
	StatusErrBorder = "#c41c1c" // carmesí medio         — borde de caja Error

	// ── StatusInfo — informativo, datos del sistema, ayuda contextual ─────────
	// Familia sky-azul (hue ~205°), distinto del cian de marca SBOS (hue ~190°)
	StatusInfoFg     = "#5ab8f5" // azul cielo vivo      — contraste ~7.5:1
	StatusInfoSubtle = "#8cd4fa" // azul cielo suave      — contraste ~11.0:1
	StatusInfoBg     = "#030f1e" // azul muy oscuro       — fondo de bloque Info
	StatusInfoBorder = "#1a6fa8" // azul cielo medio      — borde de caja Info

	// ── StatusCrit — acción destructiva, shutdown, eliminación, irreversible ──
	// Familia rojo-vivo (hue ~0°), más saturado que StatusErr = "urgente"
	StatusCritFg     = "#ff5555" // rojo vivo puro       — contraste ~5.9:1
	StatusCritSubtle = "#ff8888" // rojo vivo suave       — contraste ~8.6:1
	StatusCritBg     = "#1f0000" // casi-negro rojo       — fondo de bloque Critical
	StatusCritBorder = "#cc0000" // rojo puro             — borde de caja Critical

	// ── StatusIdle — en progreso, cargando, esperando, encolado ─────────────
	// Familia índigo (hue ~232°), calma = "procesando sin urgencia"
	StatusIdleFg     = "#9ea9f8" // índigo claro         — contraste ~6.0:1
	StatusIdleSubtle = "#bcc5fb" // índigo muy claro      — contraste ~9.1:1
	StatusIdleBg     = "#08091e" // índigo muy oscuro     — fondo de bloque Idle
	StatusIdleBorder = "#3d47c9" // índigo medio          — borde de caja Idle

	// ── StatusOff — deshabilitado, bloqueado, inactivo, sin licencia ─────────
	// Familia gris-azulado (hue ~215°), deliberadamente bajo contraste = "no disponible"
	// Nota: el contraste de StatusOffFg (~3.2:1) es intencional — el estado "deshabilitado"
	// comunica indisponibilidad precisamente porque es menos prominente que los demás.
	StatusOffFg     = "#7c8698" // gris-azul medio      — contraste ~3.2:1 (intencional)
	StatusOffSubtle = "#545c6a" // gris-azul oscuro      — texto secundario deshabilitado
	StatusOffBg     = "#0f1219" // casi-negro            — fondo de bloque Disabled
	StatusOffBorder = "#323b47" // gris-azul oscuro      — borde de caja Disabled
)

// ════════════════════════════════════════════════════════════════════════════
// NIVEL 2 — Semánticos de Estado (lipgloss.Color listos para usar)
// ════════════════════════════════════════════════════════════════════════════

var (
	// ── OK ───────────────────────────────────────────────────────────────────
	ColorStateOKFg     = lipgloss.Color(StatusOKFg)
	ColorStateOKSubtle = lipgloss.Color(StatusOKSubtle)
	ColorStateOKBg     = lipgloss.Color(StatusOKBg)
	ColorStateOKBorder = lipgloss.Color(StatusOKBorder)

	// ── Warn ─────────────────────────────────────────────────────────────────
	ColorStateWarnFg     = lipgloss.Color(StatusWarnFg)
	ColorStateWarnSubtle = lipgloss.Color(StatusWarnSubtle)
	ColorStateWarnBg     = lipgloss.Color(StatusWarnBg)
	ColorStateWarnBorder = lipgloss.Color(StatusWarnBorder)

	// ── Error ─────────────────────────────────────────────────────────────────
	ColorStateErrFg     = lipgloss.Color(StatusErrFg)
	ColorStateErrSubtle = lipgloss.Color(StatusErrSubtle)
	ColorStateErrBg     = lipgloss.Color(StatusErrBg)
	ColorStateErrBorder = lipgloss.Color(StatusErrBorder)

	// ── Info ─────────────────────────────────────────────────────────────────
	ColorStateInfoFg     = lipgloss.Color(StatusInfoFg)
	ColorStateInfoSubtle = lipgloss.Color(StatusInfoSubtle)
	ColorStateInfoBg     = lipgloss.Color(StatusInfoBg)
	ColorStateInfoBorder = lipgloss.Color(StatusInfoBorder)

	// ── Critical ──────────────────────────────────────────────────────────────
	ColorStateCritFg     = lipgloss.Color(StatusCritFg)
	ColorStateCritSubtle = lipgloss.Color(StatusCritSubtle)
	ColorStateCritBg     = lipgloss.Color(StatusCritBg)
	ColorStateCritBorder = lipgloss.Color(StatusCritBorder)

	// ── Idle / Pending ────────────────────────────────────────────────────────
	ColorStateIdleFg     = lipgloss.Color(StatusIdleFg)
	ColorStateIdleSubtle = lipgloss.Color(StatusIdleSubtle)
	ColorStateIdleBg     = lipgloss.Color(StatusIdleBg)
	ColorStateIdleBorder = lipgloss.Color(StatusIdleBorder)

	// ── Disabled / Off ────────────────────────────────────────────────────────
	ColorStateOffFg     = lipgloss.Color(StatusOffFg)
	ColorStateOffSubtle = lipgloss.Color(StatusOffSubtle)
	ColorStateOffBg     = lipgloss.Color(StatusOffBg)
	ColorStateOffBorder = lipgloss.Color(StatusOffBorder)
)
```

---

## `/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/internal/tui/styles/tokens_semantic.go`

```go
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
```

---

## `/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/internal/tui/styles/icons.go`

```go
// Package styles — icons.go: catálogo único de íconos del TUI SBOS (TUI-LIB-005).
//
// REGLA: todo símbolo Unicode/emoji del TUI proviene de aquí.
// Ningún archivo de screens/ ni ctrl/ puede declarar símbolos inline.
// Para cambiar un ícono globalmente: editar solo este archivo.
//
// DISEÑO (revisión junio 2026 — integración con theme system):
// Los íconos son glyphs PLANOS, sin color. El color se inyecta en el call
// site usando Tint()/TintBold() con un color del theme activo o uno
// personalizado. Este archivo NO importa ni depende de ningún color del
// theme — esa responsabilidad es exclusiva de quien renderiza.
//
//	// con color del theme:
//	styles.Tint(styles.IconOK, theme.Success)
//	// con color personalizado (ej. preferencia de usuario, severidad dinámica):
//	styles.Tint(styles.IconWarn, lipgloss.Color("#FF8800"))
//
// Los comentarios "color sugerido" junto a cada ícono documentan qué color
// usaba el diseño anterior (antes de decolorearlos) a modo de guía semántica,
// no son vinculantes — el theme define el color real.
package styles

import "github.com/charmbracelet/lipgloss"

// ── Inyección de color ────────────────────────────────────────────────────
//
// Tint/TintBold agregan automáticamente un espacio de padding después del
// glyph. Esto NO es estético: varios símbolos de este catálogo tienen
// presentación "wide"/emoji en ciertas terminales (renderizan ocupando 2
// columnas) mientras que el cálculo de ancho de Go/lipgloss asume 1 columna.
// Ese desfase corrompe visualmente el carácter siguiente. El espacio
// absorbe la columna extra y evita tener que recordarlo en cada call site
// (que era justo el bug recurrente que motivó normalizar este archivo).
//
// Usar TintTight() únicamente si el layout ya maneja el espaciado a mano
// (ej. celdas de ancho fijo en una tabla donde el padding rompería la
// alineación).

// Tint aplica color + padding de seguridad a un ícono. Uso por defecto.
func Tint(glyph string, color lipgloss.TerminalColor) string {
	return lipgloss.NewStyle().Foreground(color).Render(glyph + " ")
}

// TintBold aplica color + negrita + padding (uso típico: cursores, estados críticos).
func TintBold(glyph string, color lipgloss.TerminalColor) string {
	return lipgloss.NewStyle().Foreground(color).Bold(true).Render(glyph + " ")
}

// TintTight aplica color SIN padding. Usar solo cuando el layout controla
// el espaciado manualmente (tablas, celdas de ancho fijo, etc.).
func TintTight(glyph string, color lipgloss.TerminalColor) string {
	return lipgloss.NewStyle().Foreground(color).Render(glyph)
}

// ── Categoría: Estado ─────────────────────────────────────────────────────

const (
	IconOK   = "✓" // U+2713 — color sugerido: éxito/acento
	IconErr  = "✗" // U+2717 — color sugerido: error
	IconWarn = "⚠" // U+26A0 — color sugerido: advertencia
	IconInfo = "›" // U+203A — color sugerido: info (cyan)
)

// IconDone es alias semántico de IconOK para estados "completado".
const IconDone = IconOK

// IconDelete es alias semántico de IconErr para acciones destructivas.
const IconDelete = IconErr

// ── Categoría: Actividad ──────────────────────────────────────────────────
// Nota: las 4 constantes de "dot" comparten el mismo glyph (●); antes se
// distinguían solo por color. Mantenidas como nombres separados por
// claridad semántica en el call site — el color las diferencia en runtime.

const (
	IconDotActive  = "●" // U+25CF — color sugerido: éxito/acento (antes IconActive)
	IconDotPending = "●" // U+25CF — color sugerido: advertencia (antes IconDotYellow)
	IconDotError   = "●" // U+25CF — color sugerido: error (antes IconDotRed)
	IconDotDim     = "●" // U+25CF — color sugerido: tenue/inactivo
	IconCircleOpen = "○" // U+25CB — color sugerido: neutro/pendiente (antes IconPending)
	IconSync       = "↻" // U+21BB — color sugerido: advertencia (en progreso)
)

// ── Categoría: Acciones del sistema ───────────────────────────────────────

const (
	IconPower      = "⏻" // U+23FB — color sugerido: error (apagado)
	IconRestart    = "↺" // U+21BA — color sugerido: advertencia
	IconRun        = "›" // U+203A — color sugerido: info/cyan (mismo glyph que IconInfo)
	IconStepRun    = "›" // U+203A — color sugerido: advertencia (paso activo en instalación)
	IconArrowUp    = "↑" // U+2191 — antes IconInstall/IconUpdate (mismo glyph, distinto color)
	IconRepair     = "⚙" // U+2699 — color sugerido: advertencia
)

// ── Categoría: Fichas / Paquetes ────────────────────────────────────────────
// Reemplazan los emojis 📦 y 🚀, inestables en terminales sin emoji support.

const (
	IconFicha     = "◆" // U+25C6 — color sugerido: cyan
	IconBootstrap = "▶" // U+25B6 — color sugerido: acento
)

// ── Categoría: Navegación / Cursor ──────────────────────────────────────────

const (
	IconCursor = "›" // U+203A — color sugerido: cyan (mismo glyph que IconInfo/IconRun)
	IconArrowR = "→" // U+2192 — color sugerido: muted
	IconSep    = "│" // U+2502 — color sugerido: slate/tenue
)

// ── Categoría: Daemons SBOS ──────────────────────────────────────────────
// Identificadores visuales únicos por daemon soberano.

const (
	IconBos     = "⬡" // U+2B21 — daemon BOS (instalador) — color sugerido: cyan
	IconBAuth   = "⊕" // U+2295 — daemon bAuth (identidad) — color sugerido: acento
	IconBKernel = "⊙" // U+2299 — daemon bKernel (WAL/CDC) — color sugerido: cyan
	IconBiedata = "⊗" // U+2297 — daemon biedata (JSON-RPC gateway) — color sugerido: advertencia
	IconBSearch = "◎" // U+25CE — daemon bSearch (búsqueda PG) — color sugerido: cyan
	IconBNexus  = "⊘" // U+2298 — daemon bhnexus/banexus (conectividad física) — color sugerido: muted
	IconBNotify = "◇" // U+25C7 — daemon bnotify (notificaciones/MFA) — color sugerido: advertencia
)

// IconBGeneric: glyph reservado y libre para el próximo daemon SBOS que se
// agregue (no colisiona con ninguno de los anteriores).
const IconBGeneric = "⊚" // U+229A

// ── Categoría: Seguridad / Auth ───────────────────────────────────────────

const (
	IconLock = "⊡" // U+22A1 — color sugerido: advertencia
	IconKey  = "✦" // U+2726 — color sugerido: advertencia
	IconMFA  = "⊕" // U+2295 — color sugerido: cyan (mismo glyph que IconBAuth, contexto distinto)
)

// ── Categoría: Progreso ───────────────────────────────────────────────────

// SpinnerFrames: frames Braille para animaciones de espera. Sin color —
// aplicar Tint() por frame si se necesita un color fijo.
// Uso: styles.Tint(styles.SpinnerFrames[tick%len(styles.SpinnerFrames)], theme.Accent)
var SpinnerFrames = []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}

// SpinnerFramesClock: alternativa de 4 frames "reloj", para contextos donde
// se prefiera ese look (ej. countdown de instalación, timeouts).
var SpinnerFramesClock = []string{"◴", "◵", "◶", "◷"} // U+25F4–25F7

// Spin/SpinClock NO manejan el reloj — el contador `tick` lo posee y avanza
// el modelo Bubbletea (vía tea.Tick en Update()). Estas funciones solo
// traducen ese contador al frame correcto + color, para no repetir el
// cálculo de módulo en cada pantalla. Ver tutorial al final del archivo
// para el wiring completo con tea.Tick.

// Spin devuelve el frame de spinner Braille correspondiente a tick, coloreado.
func Spin(tick int, color lipgloss.TerminalColor) string {
	frame := SpinnerFrames[tick%len(SpinnerFrames)]
	return Tint(frame, color)
}

// SpinClock devuelve el frame de spinner "reloj" correspondiente a tick, coloreado.
func SpinClock(tick int, color lipgloss.TerminalColor) string {
	frame := SpinnerFramesClock[tick%len(SpinnerFramesClock)]
	return Tint(frame, color)
}

// ── Categoría: Red / Conectividad ─────────────────────────────────────────
// Para estados de daemons que dependen de red (bSearch, bhnexus, Kong GW).

const (
	IconUploadActivity   = "⇡" // U+21E1 — color sugerido: advertencia
	IconDownloadActivity = "⇣" // U+21E3 — color sugerido: acento
	IconSyncBidi         = "⇄" // U+21C4 — color sugerido: cyan
	IconLinkBroken       = "⇏" // U+21CF — color sugerido: error
	IconPulse            = "◌" // U+25CC — color sugerido: tenue
)

// ── Categoría: Almacenamiento / Datos ─────────────────────────────────────

const (
	IconDatabase = "▤" // U+25A4 — color sugerido: cyan
	IconVolume   = "▥" // U+25A5 — color sugerido: muted
	IconArchive  = "▦" // U+25A6 — color sugerido: advertencia
	IconBackup   = "⟲" // U+27F2 — color sugerido: acento
	IconRestore  = "⟳" // U+27F3 — color sugerido: advertencia
)

// ── Categoría: Métricas / Barras de progreso ──────────────────────────────
// Pensados para medidores de uso (CPU/RAM/disco) y sparklines simples.

const (
	IconBlockFull = "█" // U+2588 — ~100%
	IconBlockHigh = "▓" // U+2593 — ~75%
	IconBlockMed  = "▒" // U+2592 — ~50%
	IconBlockLow  = "░" // U+2591 — ~25%
	IconTrendUp   = "◢" // U+25E2 — color sugerido: acento
	IconTrendDown = "◣" // U+25E3 — color sugerido: error
	IconGaugeHalf = "◐" // U+25D0 — color sugerido: advertencia
)

// ── Categoría: Jerarquía / Árbol ──────────────────────────────────────────
// Conectores para listas anidadas (ej. árbol de procesos, dependencias).

const (
	IconTreeBranch = "├" // U+251C — rama intermedia
	IconTreeLast   = "└" // U+2514 — última rama
	IconTreeLine   = "─" // U+2500 — relleno horizontal
	IconTreeVert   = "│" // U+2502 — continuación vertical (mismo glyph que IconSep)
)

// ── Categoría: Selección / Formularios ────────────────────────────────────
// Para wizards estilo DevInstaller (selección múltiple, opciones exclusivas).

const (
	IconCheckboxOn  = "☑" // U+2611 — color sugerido: acento
	IconCheckboxOff = "☐" // U+2610 — color sugerido: tenue
	IconRadioOn     = "◉" // U+25C9 — color sugerido: cyan
	// Para "radio off" reutilizar IconCircleOpen — mismo semántico de "no seleccionado".
)

// ── Categoría: CI / CD y Build ─────────────────────────────────────────────
// Pensado para el pipeline GAP1 (GitHub Actions, validate.sh, cobertura).
// Para pass/fail de build reutilizar IconOK / IconErr — no duplicar glyphs.

const (
	IconCoverage = "◔" // U+25D4 — color sugerido: advertencia
	IconLint     = "◧" // U+25E7 — color sugerido: cyan
	IconRelease  = "⚑" // U+2691 — color sugerido: acento
)

// ═══════════════════════════════════════════════════════════════════════
// TUTORIAL DE USO
// ═══════════════════════════════════════════════════════════════════════
//
// 1. Ícono estático con color del theme activo:
//
//	fmt.Println(styles.Tint(styles.IconOK, theme.Success))
//
// 2. Ícono con color personalizado, sin pasar por el theme (ej. severidad
//    calculada dinámicamente, preferencia de usuario):
//
//	fmt.Println(styles.Tint(styles.IconWarn, lipgloss.Color("#FF8800")))
//
// 3. Cursor de selección activa en un menú (negrita + padding):
//
//	linea := styles.TintBold(styles.IconCursor, theme.Accent) + "Instalar bAuth"
//
// 4. Ícono SIN padding, dentro de una celda de ancho fijo (tablas, donde
//    el espacio extra de Tint() rompería la alineación de columnas):
//
//	celda := lipgloss.NewStyle().Width(3).Render(
//		styles.TintTight(styles.IconDotActive, theme.Success),
//	)
//
// 5. Checkbox en un wizard de selección múltiple (DevInstaller):
//
//	if seleccionado {
//		fmt.Println(styles.Tint(styles.IconCheckboxOn, theme.Accent), "Kong Gateway")
//	} else {
//		fmt.Println(styles.Tint(styles.IconCheckboxOff, theme.Dim), "Kong Gateway")
//	}
//
// 6. Árbol de jerarquía (ej. dependencias de un daemon):
//
//	fmt.Println(styles.IconTreeBranch + styles.IconTreeLine + " bKernel")
//	fmt.Println(styles.IconTreeLast + styles.IconTreeLine + " bSearch")
//
// 7. Spinner animado — el "tick" lo posee y avanza el modelo Bubbletea,
//    NO este archivo. icons.go solo traduce ese contador a frame+color.
//    Wiring completo con tea.Tick:
//
//	type tickMsg struct{}
//
//	type model struct {
//		tick int
//	}
//
//	func (m model) Init() tea.Cmd {
//		return tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg {
//			return tickMsg{}
//		})
//	}
//
//	func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
//		switch msg.(type) {
//		case tickMsg:
//			m.tick++
//			return m, tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg {
//				return tickMsg{}
//			})
//		}
//		return m, nil
//	}
//
//	func (m model) View() string {
//		return styles.Spin(m.tick, theme.Accent) + " Instalando bKernel..."
//	}
//
//    Si preferís el look "reloj" en vez de Braille, mismo wiring pero
//    llamando styles.SpinClock(m.tick, theme.Accent) en View().
//
// REGLA general: si necesitás un símbolo nuevo, agregalo en la categoría
// correspondiente de este archivo (como const plana, sin color) — nunca
// inline en screens/ o ctrl/.
```

---

## `/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/internal/tui/styles/tokens_component.go`

```go
// Package styles — tokens_component.go: Capa 3 — Estilos lipgloss.
// Todos los estilos usan tokens §11. Reconstruidos por rebuildThemeComponents().
// CERO lipgloss.NewStyle() en pantallas. Solo se usan estos estilos.
package styles

import "github.com/charmbracelet/lipgloss"

// ═══════════════════════════════════════════════════════════════════════════════
// TEXTO — Escala tipográfica (§11: T01–T07)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	Heading    = lipgloss.NewStyle().Foreground(ColorTextHeading).Bold(true)              // T01 — títulos
	Text       = lipgloss.NewStyle().Foreground(ColorTextPrimary)                          // T02 — body, datos
	TextBold   = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true)               // T02 bold

	Muted      = lipgloss.NewStyle().Foreground(ColorTextMuted)                            // T04 — hints
	Dim        = lipgloss.NewStyle().Foreground(ColorTextMuted)                            // T04 — alias
	Slate      = lipgloss.NewStyle().Foreground(ColorTextMuted)                            // T04 — alias
	Inactive   = lipgloss.NewStyle().Foreground(ColorTextDisabled)                         // T05 — disabled
	DimItalic  = lipgloss.NewStyle().Foreground(ColorTextDisabled).Italic(true)            // T05 italic
	TextLink   = lipgloss.NewStyle().Foreground(ColorTextLink).Underline(true)             // T07 — enlaces
	TextInverse = lipgloss.NewStyle().Foreground(ColorTextInverse)                         // T06 — sobre claro
)

// ═══════════════════════════════════════════════════════════════════════════════
// ACENTO — Cyan (§11: A01–A06)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	Accent        = lipgloss.NewStyle().Foreground(ColorAccent)                           // A01 — cursor, foco
	AccentBold    = lipgloss.NewStyle().Foreground(ColorAccentText).Bold(true)            // A04 — valor positivo bold
	AccentText    = lipgloss.NewStyle().Foreground(ColorAccentText)                       // A04 — valor positivo
	AccentHover   = lipgloss.NewStyle().Foreground(ColorAccentHover)                      // A02 — hover
	AccentPressed = lipgloss.NewStyle().Foreground(ColorAccentPressed)                    // A03 — pressed
)

	// ═══════════════════════════════════════════════════════════════════════════════
	// PANELES / CONTENEDORES (§2.3 Variant + §4 PanelManager)
	//
	// Patrón Variant{Base, Focused, Blurred, Disabled} del manual.
	// Focused/Blurred comparten fondo — solo cambia el color del borde.
	// WCAG 2.4.11: foco = borde bright (≥3:1 contraste vs blur).
	// ═══════════════════════════════════════════════════════════════════════════════

	var (
		_panelBase = lipgloss.NewStyle().
			BorderStyle(lipgloss.NormalBorder()).
			Background(ColorBgSurface).
			BorderBackground(ColorBgSurface).
			Foreground(ColorTextPrimary).
			Padding(0, 0) // §4.7 compact + BorderBackground = sin hueco borde↔fondo

		// ── Focus / Blur ── mismo fondo, distinto borde ──────────────────────
		PanelBlurred = _panelBase.Copy().
			BorderForeground(ColorBorder)
		PanelFocused = _panelBase.Copy().
			BorderForeground(ColorBorderFocus)
		PanelDisabled = _panelBase.Copy().
			BorderForeground(ColorBorderDisabled).
			Foreground(ColorTextDisabled)

		// ── Superficies (capas de profundidad) ── mismo borde blur, distinto bg ─
		PanelSurface  = PanelBlurred.Copy()  // S02 — bg Slate-800
		PanelElevated = _panelBase.Copy().    // S03
			Background(ColorBgElevated).
			BorderForeground(ColorBorder)
		PanelActive = _panelBase.Copy().      // S05 — bg Slate-600 (seleccionado)
			Background(ColorBgSurfaceActive).
			BorderForeground(ColorBorder)

		// ── Estados semánticos ── borde coloreado + bg sutil del estado ─────
		PanelSuccess = _panelBase.Copy().
			BorderForeground(ColorStateOKBorder)
		PanelWarning = _panelBase.Copy().
			BorderForeground(ColorStateWarnBorder)
		PanelError = _panelBase.Copy().
			BorderForeground(ColorStateErrBorder)
		PanelInfo = _panelBase.Copy().
			BorderForeground(ColorStateInfoBorder)
		PanelCritical = _panelBase.Copy().
			BorderForeground(ColorStateCritBorder).
			Background(ColorStateCritBg)
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

	// ── ALIAS — compatibilidad con código existente ──────────────────────────
	var (
		Panel      = PanelBlurred // alias → PanelBlurred
		PanelHover = PanelElevated // alias → PanelElevated
	)

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

	// PanelDiv — divisor vertical entre paneles
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
	// Input — campo en reposo
	Input = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(ColorInputNormalBorder).
		Background(ColorInputBg).
		Padding(0)

	// InputFocus — campo con foco (WCAG 2.4.11)
	InputFocus = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(ColorInputFocusBorder).
		Background(ColorInputBg).
		Padding(0)

	// InputError — campo con error
	InputError = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(ColorInputErrorBorder).
		Background(ColorInputErrorBg).
		Padding(0)

	// InputDisabled — campo deshabilitado
	InputDisabled = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(ColorInputDisabledBorder).
		Background(ColorInputDisabledBg).
		Padding(0)

		// InputHover — campo con hover (§11.15 TX03)
		InputHover = lipgloss.NewStyle().
			Border(lipgloss.NormalBorder()).
			BorderForeground(ColorAccentSubtle).
			Background(ColorBgSurface).BorderBackground(ColorBgSurface).
			Foreground(ColorAccentLight).
			Padding(0)

		// InputSuccess — campo con validacion OK (§11.15 TX06)
		InputSuccess = lipgloss.NewStyle().
			Border(lipgloss.NormalBorder()).
			BorderForeground(ColorStateOKBorder).
			Background(ColorBgSurface).BorderBackground(ColorBgSurface).
			Foreground(ColorStateOKFg).
			Padding(0)

		// InputReadOnly — campo solo lectura (§11.15 TX07)
		InputReadOnly = lipgloss.NewStyle().
			Border(lipgloss.NormalBorder()).
			BorderForeground(ColorBgElevated).
			Background(ColorBgSurface).BorderBackground(ColorBgSurface).
			Foreground(ColorTextSecondary).
			Padding(0)

	// Label — etiqueta de campo
	Label = lipgloss.NewStyle().Foreground(ColorTextMuted).Width(22)

	// LabelActive — etiqueta de campo activo
	LabelActive = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true).Width(22)

	// Placeholder — texto placeholder
	Placeholder = lipgloss.NewStyle().Foreground(ColorInputPlaceholder)

	// Cursor — cursor de texto
	Cursor = lipgloss.NewStyle().Foreground(ColorAccentText)
)

// ═══════════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════
// BOTONES — Variantes Focused/Blurred por tipo (§5.11.1 + §4.7 + WCAG 2.4.11)
//
// TODOS comparten RoundedBorder + Padding(0,0) + Background(ColorBgSurface).
// Background + BorderBackground heredan del panel (S02 #1e293b) — sin hueco negro.
// Solo Primary/Danger cambian el fondo al color de la accion.
// =========================================================================

var (
	_btnBorder = lipgloss.RoundedBorder()
	_btnPad    = lipgloss.NewStyle().Padding(0, 0) // §4.7 compact

	// -- Primary: bg fijo ColorAccent. Blur: borde mas oscuro. Focus: borde bright --
	BtnPrimary = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorAccentBorder).BorderBackground(ColorAccent).
		Foreground(ColorTextInverse).Background(ColorAccent).Bold(true)
	BtnPrimaryFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorAccent).
		Foreground(ColorTextInverse).Background(ColorAccent).Bold(true)

	// -- Secondary — fondo surface (hereda del panel) --
	BtnSecondary = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorder).BorderBackground(ColorBgSurface).
		Foreground(ColorTextPrimary).Background(ColorBgSurface)
	BtnSecondaryFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorBgSurface).
		Foreground(ColorAccentText).Bold(true).Background(ColorBgSurface)

	// -- Danger: bg fijo ColorStateCritFg. Blur: borde mas oscuro. Focus: borde bright --
	BtnDanger = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorStateCritBorder).BorderBackground(ColorStateCritFg).
		Foreground(ColorTextInverse).Background(ColorStateCritFg).Bold(true)
	BtnDangerFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorStateCritFg).
		Foreground(ColorTextInverse).Background(ColorStateCritFg).Bold(true)

	// -- Ghost — fondo surface, sin relleno de color --
	BtnGhost = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorder).BorderBackground(ColorBgSurface).
		Foreground(ColorTextSecondary).Background(ColorBgSurface)
	BtnGhostFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorBgSurface).
		Foreground(ColorAccentText).Bold(true).Background(ColorBgSurface)

	// -- Disabled — fondo surface, texto muted --
	BtnDisabled = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderDisabled).BorderBackground(ColorBgSurface).
		Foreground(ColorTextDisabled).Background(ColorBgSurface)

		// BtnSpacer — separador entre botones, mismo fondo del panel
		BtnSpacer = lipgloss.NewStyle() // sin fondo — hereda del panel contenedor

	// -- BT06-BT10: variantes adicionales (estándar Material/IBM) --
	BtnSuccess = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorStateOKBorder).BorderBackground(ColorStateOKFg).
		Foreground(ColorTextInverse).Background(ColorStateOKFg).Bold(true)
	BtnSuccessFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorStateOKFg).
		Foreground(ColorTextInverse).Background(ColorStateOKFg).Bold(true)

	BtnWarning = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorStateWarnBorder).BorderBackground(ColorBgSurface).
		Foreground(ColorTextPrimary).Background(ColorBgSurface)
	BtnWarningFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorBgSurface).
		Foreground(ColorAccentText).Bold(true).Background(ColorBgSurface)

	BtnInfo = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorStateInfoBorder).BorderBackground(ColorBgSurface).
		Foreground(ColorTextPrimary).Background(ColorBgSurface)
	BtnInfoFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorBgSurface).
		Foreground(ColorAccentText).Bold(true).Background(ColorBgSurface)

	BtnLink = lipgloss.NewStyle().Padding(0, 1).
		Foreground(ColorTextLink)
	BtnLinkFocused = lipgloss.NewStyle().Padding(0, 1).
		Foreground(ColorAccentText).Bold(true).Underline(true)

	BtnIcon = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorder).BorderBackground(ColorBgSurface).
		Foreground(ColorTextPrimary).Background(ColorBgSurface)
	BtnIconFocused = _btnPad.Copy().
		Border(_btnBorder).BorderForeground(ColorBorderFocus).BorderBackground(ColorBgSurface).
		Foreground(ColorAccentText).Bold(true).Background(ColorBgSurface)

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
	ProgressFill    = lipgloss.NewStyle().Foreground(ColorProgressFill)
	ProgressTrack   = lipgloss.NewStyle().Foreground(ColorProgressTrack)
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

	StatusOK    = lipgloss.NewStyle().Foreground(ColorStateOKFg)
	StatusWarn  = lipgloss.NewStyle().Foreground(ColorStateWarnFg)
	StatusErr   = lipgloss.NewStyle().Foreground(ColorStateErrFg)
	StatusInfo  = lipgloss.NewStyle().Foreground(ColorStateInfoFg)
	StatusCrit  = lipgloss.NewStyle().Foreground(ColorStateCritFg)
	StatusIdle  = lipgloss.NewStyle().Foreground(ColorStateIdleFg)
	StatusOff   = lipgloss.NewStyle().Foreground(ColorStateOffFg)
)

// ═══════════════════════════════════════════════════════════════════════════════
// TOOLTIP (§11: L01–L03)
// ═══════════════════════════════════════════════════════════════════════════════

var (
	Tooltip = lipgloss.NewStyle().
		Foreground(ColorTextInverse).
		Background(ColorBgTooltip).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(ColorBorder).
		Padding(0, 1)
)

// ═══════════════════════════════════════════════════════════════════════════════
// STEPPER — Pasos de instalación
// ═══════════════════════════════════════════════════════════════════════════════

var (
	StepOK      = lipgloss.NewStyle().Foreground(ColorAccentText).Bold(true)
	StepActive  = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true)
	StepPending = lipgloss.NewStyle().Foreground(ColorTextDisabled)
	StepFail    = lipgloss.NewStyle().Foreground(ColorStateErrFg).Bold(true)
)

// ═══════════════════════════════════════════════════════════════════════════════
// BARRA SUPERIOR / INFERIOR
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
)

// ═══════════════════════════════════════════════════════════════════════════════
// TABLAS
// ═══════════════════════════════════════════════════════════════════════════════

var (
	TableHeader = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true)
	TableCell   = lipgloss.NewStyle().Foreground(ColorTextPrimary)
	TableCellMuted = lipgloss.NewStyle().Foreground(ColorTextSecondary)
)

// ═══════════════════════════════════════════════════════════════════════════════
// ALIAS — Compatibilidad con código existente
// ═══════════════════════════════════════════════════════════════════════════════

var (
	White       = Heading        // alias → T01
	Bold        = lipgloss.NewStyle().Bold(true)
	Green       = AccentText     // alias → A04
	Cyan        = Accent         // alias → A01
	Blue        = lipgloss.NewStyle().Foreground(ColorBlue)
	Indigo      = lipgloss.NewStyle().Foreground(ColorIndigo)
	Red         = StatusErr      // alias → perceptual
	RedText     = lipgloss.NewStyle().Foreground(ColorRed)
	Yellow      = lipgloss.NewStyle().Foreground(ColorYellow)
	Purple      = lipgloss.NewStyle().Foreground(ColorPurple)
	CriticalText = StatusCrit

	DebugText   = lipgloss.NewStyle().Foreground(ColorDebugText)
	BosActivo   = lipgloss.NewStyle().Foreground(ColorBosActivo)
)

var (
	Subtitle = lipgloss.NewStyle().Foreground(ColorTextSecondary) // T03
)
// ── ALIAS 2 — Más compatibilidad ──────────────────────────────────────────────
var (
	MenuItemFocused  = MenuItem        // alias
	MenuItemNormal   = MenuItem        // alias
	WizardMenuActive = MenuItemActive  // alias
	ListItemActive   = MenuItemActive  // alias
	NotifyBarBg      = Panel           // alias
	InputActive      = InputFocus      // alias
	InputInactive    = Input           // alias
	Rule             = Divider         // alias
	SectionTitle     = Subtitle        // alias
)

// ── ALIAS 3 — Métricas (usadas por ctrl/) ────────────────────────────────────
var (
	MetricOK = AccentText  // alias → A04 (valor OK)
	MetricTX = AccentText  // alias → A04 (métrica TX)
)

// ── ALIAS 4 — Dashboard buttons ──────────────────────────────────────────────
var (
	BtnRestart  = BtnWarning
	BtnShutdown = BtnDanger
)

// ── ALIAS 5 — Badges y misc ──────────────────────────────────────────────────
var (
	BadgeAccent  = Badge
	BadgeSubtle  = Badge
	BadgeMuted   = Badge
	CountErr     = StatusErr
	ErrorBanner  = NotifyError
	TopBarRestart  = lipgloss.NewStyle().Background(ColorRestartBg).Foreground(ColorRestartFg).Bold(true).Padding(0, 1)
	TopBarCritical = lipgloss.NewStyle().Background(ColorCriticalBg).Foreground(ColorCriticalFg).Bold(true).Padding(0, 1)
	TopBarGoodbye  = lipgloss.NewStyle().Background(ColorGoodbyeBg).Foreground(ColorGoodbyeFg).Bold(true).Padding(0, 1)
)
```

---

## `/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/internal/tui/styles/theme.go`

```go
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
//	styles.ApplyTheme("")         // → obsidian (default)
package styles

import "github.com/charmbracelet/lipgloss"

// Theme agrupa todos los tokens que varían entre temas.
// Cambiar un tema = cambiar este struct. Sin tocar ninguna pantalla.
type Theme struct {
	Name  string // identificador único — usado en --theme flag y config
	Label string // nombre visible al usuario

	// Tokens de acento — color primario de señal del tema
	AccentLight  lipgloss.Color // acento mas claro (Cyan-100) → ColorAccentLight
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

	// ── Abyss — identidad Abyss: slate-950 + cyan único (SBOS-THEME-ABYSS.md) ──
	"abyss": {
		Name:          "abyss",
		Label:         "Abyss (slate + cyan)",
		Accent:        lipgloss.Color(PrimCyan500),   // #06b6d4
		AccentText:    lipgloss.Color(PrimCyan400),   // #22d3ee
		BgBase:        lipgloss.Color(PrimSlate950),  // #020617
		BgSurface:     lipgloss.Color(PrimSlate900),  // #0f172a
		BgElevated:    lipgloss.Color(PrimSlate800),  // #1e293b
		TopBarBg:      lipgloss.Color(PrimSlate950),  // #020617
		MenuBg:        lipgloss.Color(PrimCyan900),   // #164e63
		TextPrimary:   lipgloss.Color(PrimSlate100),  // #f1f5f9 — texto principal
		TextSecondary: lipgloss.Color(PrimSlate400),  // #94a3b8 — texto secundario
		TextDisabled:  lipgloss.Color(PrimSlate600),  // #475569 — texto inactivo
	},

	// ── Obsidian — identidad SBOS clásica: navy profundo + cyan eléctrico ──────
	"obsidian": {
		Name:          "obsidian",
		Label:         "Obsidian (classic SBOS)",
		Accent:        lipgloss.Color(PrimCyan500),
		AccentText:    lipgloss.Color(PrimCyan400),
		BgBase:        lipgloss.Color(PrimSlate900),
		BgSurface:     lipgloss.Color(PrimNavy900),
		BgElevated:    lipgloss.Color(PrimSlate800),
		TopBarBg:      lipgloss.Color(PrimNavy900),
		MenuBg:        lipgloss.Color(PrimNavy800),
		TextPrimary:   lipgloss.Color(PrimSlate100),  // #f1f5f9
		TextSecondary: lipgloss.Color(PrimSlate400),  // #94a3b8
		TextDisabled:  lipgloss.Color(PrimSlate600),  // #475569
	},

	// ── Pizarrón — slate azul-gris + cyan brillante ────────────────────────────
	"pizarron": {
		Name:          "pizarron",
		Label:         "Pizarrón (slate + cyan brillante)",
		Accent:        lipgloss.Color(PrimCyan400),
		AccentText:    lipgloss.Color(PrimCyan300),
		BgBase:        lipgloss.Color(PrimSlate900),
		BgSurface:     lipgloss.Color(PrimSlate800),
		BgElevated:    lipgloss.Color(PrimSlate700),
		TopBarBg:      lipgloss.Color(PrimSlate800),
		MenuBg:        lipgloss.Color(PrimSlate700),
		TextPrimary:   lipgloss.Color(PrimSlate100),  // #f1f5f9
		TextSecondary: lipgloss.Color(PrimSlate300),  // #cbd5e1 — un paso más claro (contrast sobre slate-800)
		TextDisabled:  lipgloss.Color(PrimSlate500),  // #64748b
	},

	// ── Esmeralda — verde soberano: dark green forest ────────────────────────────
	"esmeralda": {
		Name:          "esmeralda",
		Label:         "Esmeralda (verde soberano)",
		Accent:        lipgloss.Color(PrimGreen500),
		AccentText:    lipgloss.Color(PrimGreen400),
		BgBase:        lipgloss.Color(PrimGreen950),
		BgSurface:     lipgloss.Color(PrimGreenBg),
		BgElevated:    lipgloss.Color(PrimGreenDeep),
		TopBarBg:      lipgloss.Color(PrimGreenBg),
		MenuBg:        lipgloss.Color(PrimGreenDeep),
		TextPrimary:   lipgloss.Color(PrimGreen100),  // #dcfce7 — texto claro sobre verde oscuro
		TextSecondary: lipgloss.Color(PrimGreen300),  // #86efac — verde medio legible
		TextDisabled:  lipgloss.Color(PrimGreen800),  // #166534 — verde muy oscuro, apenas visible
	},

	// ── Índigo — nocturno: deep indigo violet ────────────────────────────────────
	"indigo": {
		Name:          "indigo",
		Label:         "Índigo (nocturno)",
		Accent:        lipgloss.Color(PrimIndigo400),
		AccentText:    lipgloss.Color(PrimIndigo300),
		BgBase:        lipgloss.Color(PrimIndigo950),
		BgSurface:     lipgloss.Color(PrimIndigo950),
		BgElevated:    lipgloss.Color(PrimIndigo900),
		TopBarBg:      lipgloss.Color(PrimIndigo950),
		MenuBg:        lipgloss.Color(PrimIndigo900),
		TextPrimary:   lipgloss.Color(PrimIndigo100),  // #e0e7ff — lavanda muy claro
		TextSecondary: lipgloss.Color(PrimIndigo300),  // #a5b4fc — lavanda medio
		TextDisabled:  lipgloss.Color(PrimIndigo800),  // #3730a3 — indigo oscuro
	},

	// ── Fuchsia — vivid pink: marca alternativa llamativa ────────────────────────
	"fuchsia": {
		Name:          "fuchsia",
		Label:         "Fuchsia (vivaz)",
		Accent:        lipgloss.Color(PrimPink500),
		AccentText:    lipgloss.Color(PrimPink400),
		BgBase:        lipgloss.Color(PrimPink950),
		BgSurface:     lipgloss.Color(PrimPink950),
		BgElevated:    lipgloss.Color(PrimPink900),
		TopBarBg:      lipgloss.Color(PrimPink950),
		MenuBg:        lipgloss.Color(PrimPink900),
		TextPrimary:   lipgloss.Color(PrimPink50),   // #fdf2f8 — rosa muy pálido
		TextSecondary: lipgloss.Color(PrimPink300),  // #f9a8d4 — rosa medio
		TextDisabled:  lipgloss.Color(PrimPink800),  // #9d174d — rosa oscuro
	},

	// ── Ámbar — golden warmth: dorado sobre oscuro ───────────────────────────────
	"ambar": {
		Name:          "ambar",
		Label:         "Ámbar (dorado cálido)",
		Accent:        lipgloss.Color(PrimAmber400),
		AccentText:    lipgloss.Color(PrimAmber300),
		BgBase:        lipgloss.Color(PrimAmberBg),
		BgSurface:     lipgloss.Color(PrimAmberBg),
		BgElevated:    lipgloss.Color(PrimAmber900),
		TopBarBg:      lipgloss.Color(PrimAmberBg),
		MenuBg:        lipgloss.Color(PrimAmber900),
		TextPrimary:   lipgloss.Color(PrimAmber50),   // #fffbeb — crema muy claro
		TextSecondary: lipgloss.Color(PrimAmber300),  // #fcd34d — dorado medio
		TextDisabled:  lipgloss.Color(PrimAmber900),  // #78350f — marrón oscuro
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

	// ── Mutar tokens de acento (Capa 2B) ─────────────────────────────────────
	ColorAccent        = t.Accent
	ColorAccentText  = t.AccentText

	// ── Mutar tokens de superficie ────────────────────────────────────────────
	ColorBgBase     = t.BgBase
	ColorBgSurface  = t.BgSurface
	ColorBgElevated = t.BgElevated
	ColorBorder     = t.BgElevated    // borde = superficie elevada
	ColorBg1        = t.BgBase
	ColorBg2        = t.BgSurface
	ColorBg3        = t.BgElevated
	ColorBlack      = t.BgBase        // alias histórico

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
	ColorWhite = t.TextPrimary   // texto principal (no literalmente blanco)
	ColorMuted = t.TextDisabled  // texto tenue (alias → disabled del tema)

	// Reconstruir componentes de Capa 3 que leen los tokens mutados
	rebuildThemeComponents()
}

// rebuildThemeComponents reconstruye todos los estilos de Capa 3 (tokens_component.go)
// que dependen de los tokens mutados por ApplyTheme.
// REGLA: Todo estilo de pantalla viene de aquí — ninguna pantalla crea lipgloss.NewStyle() inline.
func rebuildThemeComponents() {
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
		// ═══════════════════════════════════════════════════════════════════════════
		// PANELES / CONTENEDORES (§2.3 Variant + §4.7 compact)
		// ═══════════════════════════════════════════════════════════════════════════
		_panelBase := lipgloss.NewStyle().
			BorderStyle(lipgloss.NormalBorder()).
			Background(ColorBgSurface).BorderBackground(ColorBgSurface).
			Foreground(ColorTextPrimary).
			Padding(0, 0)

		PanelBlurred = _panelBase.Copy().BorderForeground(ColorBorder)
		PanelFocused = _panelBase.Copy().BorderForeground(ColorBorderFocus)
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

		// ═══════════════════════════════════════════════════════════════════════════
		// BORDES
		// ═══════════════════════════════════════════════════════════════════════════
		Box = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorBorder).Padding(0, 1)
		BoxFocus = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorBorderFocus).Padding(0, 1)
		BoxActive = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorAccent).Padding(0, 1)
		BoxError = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorInputErrorBorder).Padding(0, 1)
		BoxSuccess = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorStateOKBorder).Padding(0, 1)
		Divider = lipgloss.NewStyle().Foreground(ColorDivider)
		DividerStrong = lipgloss.NewStyle().Foreground(ColorBorderStrong)
		PanelDiv = lipgloss.NewStyle().BorderLeft(true).BorderStyle(lipgloss.NormalBorder()).BorderForeground(ColorBorder).PaddingLeft(2)
		HelpBox = lipgloss.NewStyle().BorderLeft(true).BorderStyle(lipgloss.NormalBorder()).BorderForeground(ColorBorder).PaddingLeft(2).Foreground(ColorTextSecondary)

		// ═══════════════════════════════════════════════════════════════════════════
		// INPUTS / TEXTBOX (§11.15 — TX01–TX10)
		// NormalBorder + Padding(0,0) + Background(ColorBgSurface).
		// Background + BorderBackground fijos (hereda S02).
		// Solo cambian BorderForeground y Foreground entre estados.
		// ═══════════════════════════════════════════════════════════════════════════
		_inputBase := lipgloss.NewStyle().
			Border(lipgloss.NormalBorder()).
			Background(ColorBgSurface).BorderBackground(ColorBgSurface).
			Foreground(ColorTextPrimary).
			Padding(0, 0)

		Input          = _inputBase.Copy().BorderForeground(ColorTextDisabled)  // TX01 — border Slate-600
		InputFocus     = _inputBase.Copy().BorderForeground(ColorAccentBorder)   // TX02 — border Cyan-800
		InputHover     = _inputBase.Copy().BorderForeground(ColorAccentSubtle).  // TX03 — border Cyan-900
					Foreground(ColorAccentLight)                               // TX03 — fg Cyan-200
		InputDisabled  = _inputBase.Copy().BorderForeground(ColorTextDisabled).  // TX04
					Foreground(ColorTextDisabled)
		InputError     = lipgloss.NewStyle().Border(lipgloss.NormalBorder()).     // TX05 — bg propio
					Background(ColorStateCritBg).BorderBackground(ColorStateCritBg).
					BorderForeground(ColorStateCritBorder).
					Foreground(ColorStateCritFg).Padding(0, 0)
		InputSuccess   = _inputBase.Copy().BorderForeground(ColorStateOKBorder).  // TX06
					Foreground(ColorStateOKFg)
		InputReadOnly  = _inputBase.Copy().BorderForeground(ColorBgElevated).     // TX07 — border Slate-800
					Foreground(ColorTextSecondary)                              // TX07 — fg Slate-500

		Label      = lipgloss.NewStyle().Foreground(ColorTextMuted).Width(22)
		LabelActive = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true).Width(22)
		Placeholder = lipgloss.NewStyle().Foreground(ColorAccentDark)              // TX08 — Cyan-700
		Cursor      = lipgloss.NewStyle().Foreground(ColorAccentSubtle)            // TX09 — Cyan-900
		// TX10 InputSelection = Background(ColorAccentDark) — no es un estilo lipgloss,
		// lo aplica el textinput de bubbles internamente.

		// ═══════════════════════════════════════════════════════════════════════════
		// BOTONES (§5.11.1 + §4.7 compact)
		// Background + BorderBackground fijos entre focused/blurred.
		// Solo cambian BorderForeground y Foreground/Bold.
		// ═══════════════════════════════════════════════════════════════════════════
		_btnBorder := lipgloss.RoundedBorder()
		_btnPad    := lipgloss.NewStyle().Padding(0, 0).Background(ColorBgSurface).BorderBackground(ColorBgSurface).Align(lipgloss.Center)

		// BT01 - Primary: fg Cyan-800, border Cyan-800. Focus: fg Cyan-500, border Cyan-500.
		BtnPrimary = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorAccentBorder).
			Foreground(ColorAccentBorder).Bold(true)
		BtnPrimaryFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorAccent).
			Foreground(ColorAccent).Bold(true)

		// BT02 - Secondary: fg Cyan-100, border Cyan-100. Focus: fg Cyan-700, border Cyan-700.
		BtnSecondary = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorAccentLight).
			Foreground(ColorAccentLight)
		BtnSecondaryFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorAccentDark).
			Foreground(ColorAccentDark).Bold(true)

		// BT03 - Danger: fg CritFg, border CritBorder. Focus: fg CritBorder, border CritFg.
		BtnDanger = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorStateCritBorder).
			Foreground(ColorStateCritFg).Bold(true)
		BtnDangerFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorStateCritFg).
			Foreground(ColorStateCritBorder).Bold(true)

		// BT04 - Ghost: fg Slate-600, border Slate-600. Focus: fg Slate-600, border Slate-400.
		BtnGhost = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorTextDisabled).
			Foreground(ColorTextDisabled)
		BtnGhostFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorTextSecondary).
			Foreground(ColorTextDisabled).Bold(true)

		// BT05 - Disabled: fg Slate-600, border Slate-600. Sin focus.
		BtnDisabled = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorBorderDisabled).
			Foreground(ColorTextDisabled)

		// BtnSpacer — fondo del panel para gaps entre botones
		BtnSpacer = lipgloss.NewStyle().Background(ColorBgSurface) // mismo token que el panel, sin borde

		// BT06 - Success: fg Green-700, border OKBorder. Focus: fg OKFg, border Green-800.
		BtnSuccess = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorStateOKBorder).
			Foreground(lipgloss.Color("#15803d")).Bold(true) // Green-700 spec
		BtnSuccessFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(lipgloss.Color("#166534")). // Green-800 spec
			Foreground(ColorStateOKFg).Bold(true)

		// BT07 - Warning: fg WarnFg, border WarnBorder. Focus: fg WarnBorder, border WarnFg.
		BtnWarning = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorStateWarnBorder).
			Foreground(ColorStateWarnFg)
		BtnWarningFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorStateWarnFg).
			Foreground(ColorStateWarnBorder).Bold(true)

		// BT08 - Info: fg InfoFg, border InfoBorder. Focus: fg InfoBorder, border InfoFg.
		BtnInfo = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorStateInfoBorder).
			Foreground(ColorStateInfoFg)
		BtnInfoFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorStateInfoFg).
			Foreground(ColorStateInfoBorder).Bold(true)

		// BT09 - Link: fg Cyan-700, sin borde. Focus: fg Cyan-500, sin borde.
		BtnLink = _btnPad.Copy().
			Border(lipgloss.HiddenBorder()).BorderBackground(ColorBgSurface).
			Foreground(ColorAccentDark).Background(ColorBgSurface).Align(lipgloss.Center)
		BtnLinkFocused = _btnPad.Copy().
			Border(lipgloss.HiddenBorder()).BorderBackground(ColorBgSurface).
			Foreground(ColorAccent).Bold(true).Underline(true).Background(ColorBgSurface).Align(lipgloss.Center)

		// BT10 - Icon: fg Slate-400, border Cyan-700. Focus: fg Cyan-700, border Slate-400.
		BtnIcon = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorAccentDark).
			Foreground(ColorTextSecondary)
		BtnIconFocused = _btnPad.Copy().
			Border(_btnBorder).BorderForeground(ColorTextSecondary).
			Foreground(ColorAccentDark).Bold(true)

	

		// // ═══════════════════════════════════════════════════════════════════════════
				// ═══════════════════════════════════════════════════════════════════════════
		MenuItem = lipgloss.NewStyle().Foreground(ColorMenuItemNormalFg)
	MenuItemHover = lipgloss.NewStyle().Foreground(ColorMenuItemNormalFg).Background(ColorMenuItemHoverBg)
	MenuItemActive = lipgloss.NewStyle().Foreground(ColorMenuItemActiveFg).Background(ColorMenuItemActiveBg).Bold(true)
	MenuItemDisabled = lipgloss.NewStyle().Foreground(ColorMenuItemDisabledFg)
	MenuSeparator = lipgloss.NewStyle().Foreground(ColorDivider)
	MenuGroupTitle = lipgloss.NewStyle().Foreground(ColorTextMuted).Bold(true)
	MenuIndicator = lipgloss.NewStyle().Foreground(ColorMenuItemActiveIndicator)

	// ═══════════════════════════════════════════════════════════════════════════
	// TABS
	// ═══════════════════════════════════════════════════════════════════════════
	Tab = lipgloss.NewStyle().Foreground(ColorTextSecondary)
	TabActive = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true).BorderBottom(true).BorderForeground(ColorAccent)
	TabHover = lipgloss.NewStyle().Foreground(ColorTextPrimary).Background(ColorBgSurfaceHover)
	TabDisabled = lipgloss.NewStyle().Foreground(ColorTextDisabled)

	// ═══════════════════════════════════════════════════════════════════════════
	// SCROLL
	// ═══════════════════════════════════════════════════════════════════════════
	ScrollTrack = lipgloss.NewStyle().Foreground(ColorScrollTrack)
	ScrollThumb = lipgloss.NewStyle().Foreground(ColorScrollThumb)

	// ═══════════════════════════════════════════════════════════════════════════
	// PROGRESO
	// ═══════════════════════════════════════════════════════════════════════════
	ProgressFill = lipgloss.NewStyle().Foreground(ColorProgressFill)
	ProgressTrack = lipgloss.NewStyle().Foreground(ColorProgressTrack)

	// ═══════════════════════════════════════════════════════════════════════════
	// BADGES
	// ═══════════════════════════════════════════════════════════════════════════
	Badge = lipgloss.NewStyle().Foreground(ColorAccentText).Background(ColorAccentSubtle).Padding(0, 1)

	// ═══════════════════════════════════════════════════════════════════════════
	// NOTIFICACIONES
	// ═══════════════════════════════════════════════════════════════════════════
	NotifySuccess = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorStateOKBorder).Foreground(ColorStateOKFg).Background(ColorStateOKBg).Padding(0, 1)
	NotifyWarning = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorStateWarnBorder).Foreground(ColorStateWarnFg).Background(ColorStateWarnBg).Padding(0, 1)
	NotifyError = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorStateErrBorder).Foreground(ColorStateErrFg).Background(ColorStateErrBg).Padding(0, 1)
	NotifyInfo = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorStateInfoBorder).Foreground(ColorStateInfoFg).Background(ColorStateInfoBg).Padding(0, 1)

	// ═══════════════════════════════════════════════════════════════════════════
	// STEPPER
	// ═══════════════════════════════════════════════════════════════════════════
	StepOK = lipgloss.NewStyle().Foreground(ColorAccentText).Bold(true)
	StepActive = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true)
	StepPending = lipgloss.NewStyle().Foreground(ColorTextDisabled)

	// ═══════════════════════════════════════════════════════════════════════════
	// BARRA SUPERIOR / INFERIOR
	// ═══════════════════════════════════════════════════════════════════════════
	TopBar = lipgloss.NewStyle().Background(ColorBgBase).Foreground(ColorTextHeading).Bold(true).Padding(0, 1)
	Footer = lipgloss.NewStyle().Background(ColorBgSurface).Foreground(ColorTextSecondary).Padding(0, 1)
	Title  = lipgloss.NewStyle().Foreground(ColorTextHeading).Bold(true).Padding(0, 1)

	// ═══════════════════════════════════════════════════════════════════════════
	// TABLAS
	// ═══════════════════════════════════════════════════════════════════════════
	TableHeader = lipgloss.NewStyle().Foreground(ColorTextPrimary).Bold(true)
	TableCell = lipgloss.NewStyle().Foreground(ColorTextPrimary)
	TableCellMuted = lipgloss.NewStyle().Foreground(ColorTextSecondary)

	// ═══════════════════════════════════════════════════════════════════════════
	// ALIAS — Compatibilidad
	// ═══════════════════════════════════════════════════════════════════════════
	White = Heading
	Green = AccentText
	Cyan  = Accent
	Red   = StatusErr
	MenuItemFocused = MenuItem
	MenuItemNormal = MenuItem
	WizardMenuActive = MenuItemActive
	ListItemActive = MenuItemActive
	NotifyBarBg = Panel
	InputActive = InputFocus
	InputInactive = Input
	Rule = Divider
	SectionTitle = Subtitle
	Tooltip = lipgloss.NewStyle().Foreground(ColorTextInverse).Background(ColorBgTooltip).Border(lipgloss.RoundedBorder()).BorderForeground(ColorBorder).Padding(0, 1)
	BadgeCounter = lipgloss.NewStyle().Foreground(ColorTextHeading).Background(ColorStateErrFg).Bold(true).Padding(0, 1)
	BadgeDot = AccentText
	BtnShutdown = BtnDanger
	BtnRestart = lipgloss.NewStyle().Foreground(ColorStateWarnFg).Border(lipgloss.RoundedBorder()).BorderForeground(ColorStateWarnBorder).Padding(0, 1)
	TopBarRestart = lipgloss.NewStyle().Background(ColorRestartBg).Foreground(ColorRestartFg).Bold(true).Padding(0, 1)
	TopBarCritical = lipgloss.NewStyle().Background(ColorCriticalBg).Foreground(ColorCriticalFg).Bold(true).Padding(0, 1)
	TopBarGoodbye = lipgloss.NewStyle().Background(ColorGoodbyeBg).Foreground(ColorGoodbyeFg).Bold(true).Padding(0, 1)
	MetricOK = AccentText
	MetricTX = AccentText
	CountErr = StatusErr
	BadgeAccent = Badge
	BadgeSubtle = Badge
	BadgeMuted = Badge
	ErrorBanner = NotifyError
	ProgressIndeterminate = lipgloss.NewStyle().Foreground(ColorProgressIndeterminate)
	CriticalText = StatusCrit
	Disabled = lipgloss.NewStyle().Foreground(ColorStateOffFg)
	Cursor = AccentText
}
```

---

## `/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/internal/tui/styles/grid.go`

```go
// Package styles — grid.go: sistema de grid de 12 columnas del TUI SBOS.
//
// El viewport se divide en 12 columnas iguales (ColUnit = TermW/12).
// Zonas horizontales: col 1 = margen izq, cols 2-11 = área de uso, col 12 = margen der.
// Zonas verticales: TopBar (TopBarH líneas) + Body (BodyH) + Footer (FooterH).
//
// Reglas:
//   - Nunca pasar TermW/TermH crudo a un componente — siempre g.ContentW o g.Span(n).
//   - TopBar y Footer usan g.TermW (ocupan el ancho total).
//   - Body usa MarginLeft(g.MarginL).MarginRight(g.MarginR).
//   - BodyH puede ser 0; los componentes deben tolerarlo.
package styles

// TopBarH y FooterH son las alturas fijas en líneas del TUI.
const (
	TopBarH = 3 // título + contexto + separador (dashboard: 3 líneas)
	FooterH = 2 // separador + hints (2 líneas)
)

// Grid centraliza la aritmética del viewport del TUI.
// Todas las medidas son en caracteres / líneas de terminal.
type Grid struct {
	TermW int // ancho total del terminal
	TermH int // alto total del terminal

	// Columnas
	Cols    int // siempre 12
	ColUnit int // ancho de cada columna = TermW / 12

	// Zonas horizontales
	MarginL  int // col 1  — margen izquierdo
	MarginR  int // col 12 — margen derecho
	ContentX int // x de inicio del área de uso (= MarginL)
	ContentW int // ancho del área de uso (cols 2-11 = 10 cols)

	// Zonas verticales
	TopY  int // siempre 0
	TopH  int // altura del topbar (TopBarH)
	FootY int // y de inicio del footer
	FootH int // altura del footer (FooterH)
	BodyY int // y de inicio del área de contenido (= TopH)
	BodyH int // altura del área de contenido
}

// NewGrid construye un Grid a partir del tamaño actual del terminal.
// topH y footH permiten ajustar las zonas fijas según la pantalla activa.
// Si topH/footH son 0 se usan las constantes TopBarH/FooterH.
func NewGrid(w, h int) Grid {
	if w < 12 {
		w = 12
	}

	colUnit := w / 12
	if colUnit < 1 {
		colUnit = 1
	}
	marginL := colUnit
	marginR := colUnit
	contentW := w - marginL - marginR
	if contentW < 1 {
		contentW = 1
	}

	bodyH := h - TopBarH - FooterH
	if bodyH < 0 {
		bodyH = 0
	}

	return Grid{
		TermW: w, TermH: h,
		Cols: 12, ColUnit: colUnit,

		MarginL:  marginL,
		MarginR:  marginR,
		ContentX: marginL,
		ContentW: contentW,

		TopY:  0,
		TopH:  TopBarH,
		FootY: h - FooterH,
		FootH: FooterH,
		BodyY: TopBarH,
		BodyH: bodyH,
	}
}

// Span retorna el ancho en caracteres de n columnas del grid.
// Útil para paneles internos: g.Span(5) = 5 cols del área de uso.
func (g Grid) Span(cols int) int {
	return cols * g.ColUnit
}

// InnerW retorna ContentW descontando el padding de Padding(0,1) de lipgloss.
// Padding(0,1) consume 1 char por lado = 2 totales.
func (g Grid) InnerW() int {
	return ColW(g.ContentW)
}

// ── Helpers de aritmética de anchos ──────────────────────────────────────────

// Mode retorna "xs", "sm" o "md" según el ancho del terminal.
func Mode(w int) string {
	if w < 60 {
		return "xs"
	}
	if w < 80 {
		return "sm"
	}
	return "md"
}

// ColW retorna el ancho utilizable de un panel con Padding(0,1).
// lipgloss Padding(0,1) consume 1 char por lado → 2 totales.
func ColW(w int) int {
	if w < 4 {
		return 0
	}
	return w - 2
}

// ContentW retorna el ancho del contenido interior con padding adicional.
func ContentW(w int) int {
	if w < 6 {
		return 0
	}
	return w - 4
}

// MarginW retorna el margen horizontal lateral para WrapWithMargin.
// Equivalente a termW/12 con mínimo 1 y máximo 16 (clamp superior B-05).
func MarginW(w int) int {
	if w == 0 {
		return 0
	}
	m := w / 12
	if m == 0 {
		return 1
	}
	if m > 16 {
		return 16
	}
	return m
}
```

---

## `/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/internal/tui/styles/layout.go`

```go
package styles

import "github.com/charmbracelet/lipgloss"

// Alias de tipos — screens y ctrl usan styles.Style/Color/Position/Border
// sin importar lipgloss directamente.
type (
	Style    = lipgloss.Style
	Color    = lipgloss.Color
	Position = lipgloss.Position
	Border   = lipgloss.Border
)

// NewStyle construye un estilo vacío — punto único de entrada a lipgloss.
func NewStyle() lipgloss.Style { return lipgloss.NewStyle() }

// Posiciones de alineación — re-exportadas de lipgloss.
var (
	PosTop    = lipgloss.Top
	PosBottom = lipgloss.Bottom
	PosCenter = lipgloss.Center
	PosLeft   = lipgloss.Left
	PosRight  = lipgloss.Right
)

// JoinH une strings horizontalmente con la posición vertical indicada.
func JoinH(pos lipgloss.Position, strs ...string) string {
	return lipgloss.JoinHorizontal(pos, strs...)
}

// JoinV une strings verticalmente con la posición horizontal indicada.
func JoinV(pos lipgloss.Position, strs ...string) string {
	return lipgloss.JoinVertical(pos, strs...)
}

// TextWidth devuelve el ancho visual (en celdas de terminal) de s.
func TextWidth(s string) int { return lipgloss.Width(s) }

// TextHeight devuelve la altura en líneas de s.
func TextHeight(s string) int { return lipgloss.Height(s) }

// Cell renderiza text en una columna de ancho fijo w (sin color).
func Cell(w int, text string) string {
	return lipgloss.NewStyle().Width(w).Render(text)
}

// CellCenter renderiza text centrado en una columna de ancho w.
func CellCenter(w int, text string) string {
	return lipgloss.NewStyle().Width(w).Align(lipgloss.Center).Render(text)
}

// MaxCell aplica un ancho máximo maxW a text.
func MaxCell(maxW int, text string) string {
	return lipgloss.NewStyle().MaxWidth(maxW).Render(text)
}

// Place posiciona text en un área w×h con alineación hPos/vPos.
func Place(w, h int, hPos, vPos lipgloss.Position, str string) string {
	return lipgloss.Place(w, h, hPos, vPos, str)
}

// NormalBorder devuelve el borde normal de lipgloss.
func NormalBorder() lipgloss.Border { return lipgloss.NormalBorder() }

// RoundedBorder devuelve el borde redondeado de lipgloss.
func RoundedBorder() lipgloss.Border { return lipgloss.RoundedBorder() }

// ThickBorder devuelve el borde grueso de lipgloss.
func ThickBorder() lipgloss.Border { return lipgloss.ThickBorder() }

// DoubleBorder devuelve el borde doble de lipgloss.
func DoubleBorder() lipgloss.Border { return lipgloss.DoubleBorder() }
```

---

## `/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/internal/tui/styles/huh_theme.go`

```go
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
```

---

## `/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/internal/tui/styles/styles.go`

```go
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
```

---

## `/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/internal/tui/styles/doc.go`

```go
// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package styles centraliza todas las constantes de color y variables lipgloss
// del TUI del instalador bos. Es el único lugar donde se definen estilos.
//
// # Responsabilidades
//
// Exportar variables lipgloss reutilizables y constantes de color para que
// ningún otro paquete defina estilos inline:
//
//   - Constantes de color HEX: [ColorGreen], [ColorAccent], [ColorRed], etc.
//   - Estilos base: [Bold], [Dim], [Green], [Cyan], [Red], [Yellow], [Muted]
//   - Componentes estructurales: [TopBar], [Footer], [Box], [BoxActive]
//   - Estilos de pasos: [StepOK], [StepActive], [StepPending], [StepFail]
//   - Estilos de inputs: [InputActive], [InputInactive]
//   - Funciones de icono: [IconOK()], [IconRun()], [IconPend()], [IconErr()], [IconWarn()]
//
// # Fuera de alcance
//
// No importa bubbletea — este paquete no conoce el ciclo TEA. No define
// tipos de datos del modelo. No calcula dimensiones de viewport. No contiene
// lógica condicional — solo constantes y variables inmutables.
//
// # Dependencias
//
// Ninguna dependencia de otros paquetes internos. Zero import cycles.
// Dependencia externa única: github.com/charmbracelet/lipgloss.
//
// # Callers principales
//
// internal/tui/screens/*: cada archivo de pantalla importa styles para renderizar.
// internal/tui/model/doc.go: puede importar para tipos de Color (no estilos completos).
// cmd/bosctl/install_ui.go: usa los estilos directamente hasta que F3 complete la migración.
//
// # Estándares y referencias
//
// BOS-REPAIR-03 F3.1 — styles/styles.go como primer átomo de F3.
// install_ui.go L52-155 — definición actual de colores y estilos (referencia hasta F3.1).
// POLICY.md §2 — todo nuevo estilo va aquí, nunca inline en screens/.
//
// # Ejemplo de uso
//
//	import "bos/internal/tui/styles"
//
//	// En una función View de screens/:
//	header := styles.TopBar.Render("⬡ SBOS IAM Installer")
//	ok := styles.IconOK() + " " + styles.Green.Render("postgresql — instalada")
//	err := styles.IconErr() + " " + styles.Red.Render("vault — error")
package styles
```

