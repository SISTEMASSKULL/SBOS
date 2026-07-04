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
