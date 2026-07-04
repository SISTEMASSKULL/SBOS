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
