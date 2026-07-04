# SBOS Theme — Abyss
**Versión:** 1.1.0
**Estado:** Draft
**Proyecto:** Sovereign Business Operating System (SKULL)
**Contextos:** Web UI · TUI (lipgloss/bubbletea)

---

## 1. Nombre y filosofía

El theme se llama **Abyss**. El nombre refleja la intención visual: un fondo profundo y casi negro del que emergen las señales con precisión quirúrgica. No hay ruido decorativo. Cada color que no es negro tiene un propósito.

Dos paletas, dos roles fijos:

- **Slate** es la base neutral. Provee fondos, superficies, bordes y texto en toda la escala de profundidad. Cuanto más oscuro el tono, más "abajo" está en la jerarquía visual.
- **Cyan** es el único acento. Se reserva exclusivamente para elementos con intención activa: acción primaria, ítem seleccionado, señal positiva. Cualquier toque de cyan en la pantalla significa "aquí pasa algo".

**Regla cardinal: un solo acento.** Agregar un segundo color activo destruye la función de señal del primero.

---

## 2. Paleta de colores

### 2.1 Slate — base neutral

| Nombre | Hex | Muestra | Rol en Web UI | Rol en TUI |
|--------|-----|---------|--------------|-----------|
| slate-950 | #0f172a | <span style="display:inline-block;width:36px;height:12px;background:#0f172a;border-radius:3px;"></span> | Fondo raíz / bg inputs | ColorBgBase |
| slate-900 | #1e293b | <span style="display:inline-block;width:36px;height:12px;background:#1e293b;border-radius:3px;"></span> | Sidebar / cards | ColorBgSurface |
| slate-800 | #334155 | <span style="display:inline-block;width:36px;height:12px;background:#334155;border-radius:3px;"></span> | Bordes principales | ColorBorder |
| slate-700 | #475569 | <span style="display:inline-block;width:36px;height:12px;background:#475569;border-radius:3px;"></span> | Bordes de inputs | ColorBorderSubtle |
| slate-600 | #64748b | <span style="display:inline-block;width:36px;height:12px;background:#64748b;border-radius:3px;"></span> | Texto deshabilitado | ColorTextDisabled |
| slate-500 | #94a3b8 | <span style="display:inline-block;width:36px;height:12px;background:#94a3b8;border-radius:3px;"></span> | Labels muted / nav | ColorTextMuted |
| slate-400 | #cbd5e1 | <span style="display:inline-block;width:36px;height:12px;background:#cbd5e1;border-radius:3px;"></span> | Nav inactivo / roles | ColorTextSecondary |
| slate-200 | #f1f5f9 | <span style="display:inline-block;width:36px;height:12px;background:#f1f5f9;border-radius:3px;border:1px solid #333;"></span> | Texto secundario activo | ColorTextSubtle |
| slate-100 | #f8fafc | <span style="display:inline-block;width:36px;height:12px;background:#f8fafc;border-radius:3px;border:1px solid #333;"></span> | Texto primario | ColorTextPrimary |

**Tokens Slate — Catálogo de uso**

| Token | Hex | Muestra | Componentes / Uso |
|-------|-----|---------|-------------------|
| ColorBgBase | #0f172a | <span style="display:inline-block;width:36px;height:12px;background:#0f172a;border-radius:50%;"></span> | Fondo del terminal, InputBackground, TopBarBg |
| ColorBgSurface | #1e293b | <span style="display:inline-block;width:36px;height:12px;background:#1e293b;border-radius:50%;"></span> | Paneles, bloques, Footer bg, Panel bg |
| ColorBgElevated | #334155 | <span style="display:inline-block;width:36px;height:12px;background:#334155;border-radius:50%;"></span> | Bordes, separadores, Rule, Box border |
| ColorBorder | #334155 | <span style="display:inline-block;width:36px;height:12px;background:#334155;border-radius:50%;"></span> | Box, InputInactive, Divider, PanelDiv |
| ColorTextPrimary | #f8fafc | <span style="display:inline-block;width:36px;height:12px;background:#f8fafc;border-radius:50%;border:1px solid #333;"></span> | Títulos, headers, datos, White, Bold |
| ColorTextSecondary | #cbd5e1 | <span style="display:inline-block;width:36px;height:12px;background:#cbd5e1;border-radius:50%;"></span> | Subtítulos, timestamps, Muted, Footer |
| ColorTextDisabled | #64748b | <span style="display:inline-block;width:36px;height:12px;background:#64748b;border-radius:50%;"></span> | Placeholders, Dim, Inactive, ScrollTrack, StepPending |
| ColorTextMuted | #94a3b8 | <span style="display:inline-block;width:36px;height:12px;background:#94a3b8;border-radius:50%;"></span> | Texto tenue, hints, metadatos |

| Nombre | Hex | Muestra | Rol en Web UI | Rol en TUI |
|--------|-----|---------|--------------|-----------|
| cyan-900 | #164e63 | <span style="display:inline-block;width:36px;height:12px;background:#164e63;border-radius:3px;"></span> | Fondo badges de conteo | ColorAccentSubtle |
| cyan-800 | #155e75 | <span style="display:inline-block;width:36px;height:12px;background:#155e75;border-radius:3px;"></span> | Border badges activos | ColorAccentBorder |
| cyan-700 | #0e7490 | <span style="display:inline-block;width:36px;height:12px;background:#0e7490;border-radius:3px;"></span> | Sparklines nivel medio | ColorAccentDim |
| cyan-500 | #06b6d4 | <span style="display:inline-block;width:36px;height:12px;background:#06b6d4;border-radius:3px;"></span> | Acento principal | ColorAccent |
| cyan-400 | #22d3ee | <span style="display:inline-block;width:36px;height:12px;background:#22d3ee;border-radius:3px;"></span> | Texto sobre acento | ColorAccentText |
| cyan-300 | #67e8f9 | <span style="display:inline-block;width:36px;height:12px;background:#67e8f9;border-radius:3px;border:1px solid #333;"></span> | Texto en badge oscuro | ColorAccentBright |

---

## 3. Tokens semánticos

### 3.1 Web UI (CSS custom properties)

```css
:root {
  /* ── Superficies ── */
  --bg-base:        #0f172a;   /* slate-950 */
  --bg-surface:     #1e293b;   /* slate-900 */
  --bg-elevated:    #334155;   /* slate-800 */

  /* ── Texto ── */
  --text-primary:   #f8fafc;   /* slate-100 */
  --text-secondary: #f1f5f9;   /* slate-200 */
  --text-muted:     #cbd5e1;   /* slate-400 */
  --text-disabled:  #94a3b8;   /* slate-500 */

  /* ── Bordes ── */
  --border-default: #334155;   /* slate-800 */
  --border-input:   #475569;   /* slate-700 */

  /* ── Acento (cyan) ── */
  --accent:         #06b6d4;   /* cyan-500 */
  --accent-text:    #22d3ee;   /* cyan-400 */
  --accent-subtle:  #164e63;   /* cyan-900 */
  --accent-border:  #155e75;   /* cyan-800 */
  --accent-badge:   #67e8f9;   /* cyan-300 */

  /* ── Inputs ── */
  --input-bg:          #0f172a; /* mismo que --bg-base */
  --input-border:      #475569;
  --input-text:        #f8fafc;
  --input-placeholder: #64748b;
  --input-focus-ring:  #06b6d4;
}
```

### 3.2 TUI (Go — lipgloss)

```go
// Package styles — abyss.go
// Tokens de color del theme Abyss para el TUI de SBOS.
// Todos los valores son colores ANSI true-color (#RRGGBB).
package styles

import "github.com/charmbracelet/lipgloss"

// Paleta Abyss — colores base
const (
    // Slate — superficies y texto
    ColorBgBase      = lipgloss.Color("#0f172a") // slate-950
    ColorBgSurface   = lipgloss.Color("#1e293b") // slate-900
    ColorBgElevated  = lipgloss.Color("#334155") // slate-800

    ColorBorder       = lipgloss.Color("#334155") // slate-800
    ColorBorderSubtle = lipgloss.Color("#475569") // slate-700

    ColorTextPrimary   = lipgloss.Color("#f8fafc") // slate-100
    ColorTextSubtle    = lipgloss.Color("#f1f5f9") // slate-200
    ColorTextSecondary = lipgloss.Color("#cbd5e1") // slate-400
    ColorTextMuted     = lipgloss.Color("#94a3b8") // slate-500
    ColorTextDisabled  = lipgloss.Color("#64748b") // slate-600

    // Cyan — acento único
    ColorAccent       = lipgloss.Color("#06b6d4") // cyan-500
    ColorAccentText   = lipgloss.Color("#22d3ee") // cyan-400
    ColorAccentDim    = lipgloss.Color("#0e7490") // cyan-700
    ColorAccentSubtle = lipgloss.Color("#164e63") // cyan-900
    ColorAccentBorder = lipgloss.Color("#155e75") // cyan-800
    ColorAccentBright = lipgloss.Color("#67e8f9") // cyan-300

**Tokens Cyan — Catálogo de uso**

| Token | Hex | Muestra | Componentes / Uso |
|-------|-----|---------|-------------------|
| ColorAccent / ColorCyan | #06b6d4 | <span style="display:inline-block;width:36px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Cursor, foco, Cyan, AccentBold, BoxActive, InputActive, TopBar fg, StepOK, StepActive, ScrollThumb, LabelActive, WizardMenuActive fg, huh |
| ColorAccentText | #22d3ee | <span style="display:inline-block;width:36px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Texto sobre acento, MenuItemActive fg, ListItemActive fg, DataAccent, MetricRX |
| ColorAccentDim | #0e7490 | <span style="display:inline-block;width:36px;height:12px;background:#0e7490;border-radius:50%;"></span> | Barras progreso nivel medio, sparklines |
| ColorAccentSubtle | #164e63 | <span style="display:inline-block;width:36px;height:12px;background:#164e63;border-radius:50%;"></span> | Badges, bg selección |
| ColorAccentBorder | #155e75 | <span style="display:inline-block;width:36px;height:12px;background:#155e75;border-radius:50%;"></span> | Bordes de badges |
| ColorAccentBright | #67e8f9 | <span style="display:inline-block;width:36px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> | Texto en badge oscuro |
| ColorTopBarBg | #0f172a | <span style="display:inline-block;width:36px;height:12px;background:#0f172a;border-radius:50%;"></span> | Fondo de TopBar |
| ColorMenuActiveBg | #164e63 | <span style="display:inline-block;width:36px;height:12px;background:#164e63;border-radius:50%;"></span> | Fondo menú activo, WizardMenuActive bg |
)

**§7.1 — Estilos base reutilizables — Catálogo**

| Estilo | Token usado | Hex | Muestra | Uso |
|--------|------------|-----|---------|-----|
| StylePanel | bg:ColorBgSurface, fg:ColorTextPrimary, border:ColorBorder | #1e293b/#f8fafc/#334155 | <span style="display:inline-block;width:36px;height:12px;background:#1e293b;border-radius:50%;"></span> | Paneles, bloques, tarjetas |
| StyleText | fg:ColorTextPrimary | #f8fafc | <span style="display:inline-block;width:36px;height:12px;background:#f8fafc;border-radius:50%;border:1px solid #333;"></span> | Texto principal |
| StyleMuted | fg:ColorTextMuted | #94a3b8 | <span style="display:inline-block;width:36px;height:12px;background:#94a3b8;border-radius:50%;"></span> | Labels, hints, texto secundario |
| StyleListItem | fg:ColorTextSecondary | #cbd5e1 | <span style="display:inline-block;width:36px;height:12px;background:#cbd5e1;border-radius:50%;"></span> | Items de lista inactivos |
| StyleListItemActive | fg:ColorAccentText, bg:ColorAccentSubtle, border:ColorAccent | #22d3ee/#164e63/#06b6d4 | <span style="display:inline-block;width:36px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Item de lista seleccionado/activo |
| StyleBadge | fg:ColorAccentBright, bg:ColorAccentSubtle | #67e8f9/#164e63 | <span style="display:inline-block;width:36px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> | Badges, contadores, chips |
| StyleAccent | fg:ColorBgBase, bg:ColorAccent | #0f172a/#06b6d4 | <span style="display:inline-block;width:36px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Botón primario, CTA, cursor |
| StyleTopBar | bg:ColorBgBase, fg:ColorTextPrimary | #0f172a/#f8fafc | <span style="display:inline-block;width:36px;height:12px;background:#0f172a;border-radius:50%;"></span> | Barra superior del TUI |
| StyleFooter | bg:ColorBgBase, fg:ColorTextMuted | #0f172a/#94a3b8 | <span style="display:inline-block;width:36px;height:12px;background:#0f172a;border-radius:50%;"></span> | Barra inferior / statusbar |
| StyleRule | fg:ColorBorder | #334155 | <span style="display:inline-block;width:36px;height:12px;background:#334155;border-radius:50%;"></span> | Separador horizontal, regla |
```

---

## 4. Jerarquía de superficies

### Web UI

```
slate-950  ← fondo raíz / inputs ("se hunden")
  └── slate-900  ← cards / sidebar / paneles
        └── slate-800  ← bordes / separadores
```

### TUI

```
ColorBgBase     ← fondo del terminal completo
  └── ColorBgSurface   ← paneles, bloques, listas
        └── ColorBgElevated  ← bordes, separadores, reglas
```

En el TUI la "profundidad" no viene de sombras sino de la diferencia de luminosidad entre capas adyacentes. Un bloque `ColorBgSurface` sobre `ColorBgBase` es perceptiblemente diferente en una terminal true-color.

---

## 5. Reglas de uso del acento

El acento cyan se aplica en exactamente **4 contextos** — tanto en Web como en TUI:

| Contexto               | Web UI                              | TUI (lipgloss)                          |
|------------------------|-------------------------------------|-----------------------------------------|
| Ítem activo / foco     | `border-left` + `color` cyan        | `BorderLeft` cyan + `Foreground` cyan   |
| Acción primaria        | `background` cyan / texto negro     | `Background` cyan / `Foreground` negro  |
| Valor positivo / delta | `color: --accent-text`              | `Foreground(ColorAccentText)`           |
| Badge / contador       | `bg: --accent-subtle` / texto cyan  | `Background(ColorAccentSubtle)` + texto |

> Todo lo demás usa la escala slate. Usar cyan fuera de estos 4 contextos diluye su función de señal.

---

## 6. Componentes — Web UI

### 6.1 Botones

```css
.btn-primary {
  background: var(--accent);
  color: var(--bg-base);
  border: none;
  border-radius: 7px;
  font-size: 12px;
  font-weight: 500;
  padding: 6px 14px;
}

.btn-ghost {
  background: transparent;
  color: var(--text-secondary);
  border: 1px solid var(--border-input);
  border-radius: 7px;
  font-size: 12px;
  padding: 6px 14px;
}
```

### 6.2 Inputs

```css
input, select, textarea {
  background: var(--input-bg) !important;
  color:      var(--input-text) !important;
  border: 1px solid var(--input-border);
  border-radius: 7px;
  padding: 7px 10px;
  font-size: 12px;
}
input::placeholder { color: var(--input-placeholder); }
input:focus {
  border-color: var(--input-focus-ring);
  box-shadow: 0 0 0 2px rgba(6,182,212,0.20);
  outline: none;
}
```

### 6.3 Nav sidebar

```css
.nav-item         { color: var(--text-muted); border-radius: 7px; padding: 8px 10px; }
.nav-item:hover   { background: var(--bg-elevated); color: var(--text-secondary); }
.nav-item.active  {
  color: var(--accent-text);
  border-left: 2px solid var(--accent);
  background: rgba(6,182,212,0.12);
  padding-left: 8px;
}
```

### 6.4 Cards / paneles

```css
.card {
  background: var(--bg-surface);
  border: 1px solid var(--border-default);
  border-radius: 10px;
  padding: 16px;
}
```

### 6.5 Badges y status pills

```css
.badge-count {
  background: var(--accent-subtle);
  color: var(--accent-badge);
  border: 1px solid var(--accent-border);
  font-size: 11px;
  font-weight: 500;
  padding: 1px 7px;
  border-radius: 20px;
}

.status-active {
  background: rgba(6,182,212,0.12);
  color: var(--accent-text);
  border: 1px solid var(--accent-border);
}
.status-idle {
  background: var(--bg-elevated);
  color: var(--text-muted);
  border: 1px solid var(--border-input);
}
```

### 6.6 Stat cards

```css
.stat-card   { background: var(--bg-surface); border: 1px solid var(--border-default); border-radius: 10px; padding: 16px; }
.stat-label  { color: var(--text-disabled); font-size: 11px; text-transform: uppercase; letter-spacing: 0.04em; }
.stat-value  { color: var(--text-primary);  font-size: 22px; font-weight: 500; }
.stat-delta  { color: var(--accent-text);   font-size: 12px; }
```

### 6.7 Sparklines

| Nivel | Token | Hex | Muestra |
|-------|------|-----|---------|
| Bajo | --bg-elevated | #334155 | <span style="display:inline-block;width:36px;height:12px;background:#334155;border-radius:50%;"></span> |
| Medio | --accent-dim | #0e7490 | <span style="display:inline-block;width:36px;height:12px;background:#0e7490;border-radius:50%;"></span> |
| Alto | --accent | #06b6d4 | <span style="display:inline-block;width:36px;height:12px;background:#06b6d4;border-radius:50%;"></span> |

---

## 7. Componentes — TUI (lipgloss)

### 7.1 Estilos base reutilizables

```go
// Package styles — components.go
package styles

import "github.com/charmbracelet/lipgloss"

var (
    // Panel / bloque general
    StylePanel = lipgloss.NewStyle().
        Background(ColorBgSurface).
        Foreground(ColorTextPrimary).
        BorderStyle(lipgloss.NormalBorder()).
        BorderForeground(ColorBorder)

    // Texto primario
    StyleText = lipgloss.NewStyle().
        Foreground(ColorTextPrimary)

    // Texto muted (labels, hints)
    StyleMuted = lipgloss.NewStyle().
        Foreground(ColorTextMuted)

    // Ítem de lista inactivo
    StyleListItem = lipgloss.NewStyle().
        Foreground(ColorTextSecondary).
        PaddingLeft(1)

    // Ítem de lista activo / seleccionado
    StyleListItemActive = lipgloss.NewStyle().
        Foreground(ColorAccentText).
        Background(ColorAccentSubtle).
        BorderLeft(true).
        BorderForeground(ColorAccent).
        PaddingLeft(1)

    // Badge / contador
    StyleBadge = lipgloss.NewStyle().
        Foreground(ColorAccentBright).
        Background(ColorAccentSubtle).
        PaddingLeft(1).PaddingRight(1)

    // Cursor / acento primario (texto sobre fondo cyan)
    StyleAccent = lipgloss.NewStyle().
        Foreground(ColorBgBase).
        Background(ColorAccent).
        Bold(true)

    // TopBar
    StyleTopBar = lipgloss.NewStyle().
        Background(ColorBgBase).
        Foreground(ColorTextPrimary).
        Bold(true)

    // Footer / statusbar
    StyleFooter = lipgloss.NewStyle().
        Background(ColorBgBase).
        Foreground(ColorTextMuted)

    // Separador horizontal (border rule)
    StyleRule = lipgloss.NewStyle().
        Foreground(ColorBorder)
)
```

### 7.2 Uso en render

```go
// Ítem de lista con estado activo/inactivo
func renderItem(label string, active bool) string {
    if active {
        return styles.StyleListItemActive.Render("▎ " + label)
    }
    return styles.StyleListItem.Render("  " + label)
}

// Badge de conteo
func renderBadge(n int) string {
    return styles.StyleBadge.Render(fmt.Sprintf(" %d ", n))
}

// Acento primario (ej. nombre del tenant seleccionado)
func renderAccent(s string) string {
    return styles.StyleAccent.Render(s)
}
```

**§7.2 — Funciones de render — Referencia**

| Función | Estilo usado | Resultado visual |
|---------|-------------|-----------------|
| renderItem(label, true) | StyleListItemActive | Texto cyan brillante con barra izquierda cyan y fondo cyan-900 |
| renderItem(label, false) | StyleListItem | Texto slate-400 sin indicador |
| renderBadge(n) | StyleBadge | Texto cyan-300 sobre fondo cyan-900 con padding |
| renderAccent(s) | StyleAccent | Texto casi negro sobre fondo cyan-500, negrita |

---

## 8. Sistema de Grid TUI — 12 columnas

### 8.1 Concepto

El viewport del TUI se divide en 12 columnas de igual ancho, análogo al grid de 12 columnas web. Las reglas son:

```
col 1             → margen izquierdo (MarginL)
cols 2–11         → área de uso     (ContentW = 10 cols)
col 12            → margen derecho  (MarginR)
```

Verticalmente el viewport tiene tres zonas fijas:

```
┌─────────────────────────────────┐  ← y=0
│           TopBar                │  TopBarH líneas
├─────────────────────────────────┤  ← y=TopBarH
│                                 │
│         área de uso             │  BodyH = termH - TopBarH - FooterH
│                                 │
├─────────────────────────────────┤  ← y=termH-FooterH
│           Footer                │  FooterH líneas
└─────────────────────────────────┘  ← y=termH
```

### 8.2 Struct `Grid`

```go
// Package styles — grid.go
package styles

// TopBarH y FooterH son las alturas fijas en líneas de terminal.
const (
    TopBarH = 1
    FooterH = 1
)

// Grid centraliza la aritmética del viewport.
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
    ContentW int // ancho del área de uso (cols 2–11 = 10 cols)

    // Zonas verticales
    TopY  int // siempre 0
    TopH  int // altura del topbar
    FootY int // y de inicio del footer
    FootH int // altura del footer
    BodyY int // y de inicio del área de contenido (= TopH)
    BodyH int // altura del área de contenido
}

// NewGrid construye un Grid a partir del tamaño actual del terminal.
func NewGrid(w, h int) Grid {
    if w < 12 {
        w = 12 // mínimo absoluto para mantener el grid
    }

    colUnit  := w / 12
    marginL  := colUnit
    marginR  := colUnit
    contentX := marginL
    contentW := w - marginL - marginR

    bodyH := h - TopBarH - FooterH
    if bodyH < 0 {
        bodyH = 0
    }

    return Grid{
        TermW: w, TermH: h,
        Cols: 12, ColUnit: colUnit,

        MarginL:  marginL,
        MarginR:  marginR,
        ContentX: contentX,
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

// InnerW retorna el ContentW descontando el padding interno
// de lipgloss Padding(0,1) — consume 1 char por lado = 2 totales.
func (g Grid) InnerW() int {
    return ColW(g.ContentW)
}
```

### 8.3 Helpers auxiliares (mantener compatibilidad con grid.go existente)

```go
// Mode retorna "xs", "sm" o "md" según el ancho del terminal.
func Mode(w int) string {
    if w < 60 { return "xs" }
    if w < 80 { return "sm" }
    return "md"
}

// ColW retorna el ancho utilizable de un panel con Padding(0,1).
// lipgloss Padding(0,1) consume 1 char por lado → 2 totales.
func ColW(w int) int {
    if w < 4 { return 0 }
    return w - 2
}

// ContentW retorna el ancho del contenido interior con padding adicional.
func ContentW(w int) int {
    if w < 6 { return 0 }
    return w - 4
}

// MarginW retorna el margen horizontal lateral para WrapWithMargin.
func MarginW(w int) int {
    if w == 0 { return 0 }
    m := w / 12
    if m == 0 { return 1 }
    return m
}
```

### 8.4 Uso en una screen

```go
// screens/dashboard.go
func (m Model) View() string {
    g := styles.NewGrid(m.width, m.height)

    // Cada zona recibe exactamente el ancho que le corresponde
    topBar  := renderTopBar(g.ContentW)
    footer  := renderFooter(g.ContentW)
    body    := renderBody(g.ContentW, g.BodyH)

    // El bloque central tiene los márgenes col-1 y col-12 aplicados
    content := lipgloss.NewStyle().
        MarginLeft(g.MarginL).
        MarginRight(g.MarginR).
        Render(body)

    return lipgloss.JoinVertical(lipgloss.Left,
        topBar,
        content,
        footer,
    )
}
```

### 8.5 Uso con paneles internos (Span)

```go
// Dividir el área de uso en sidebar (3 cols) + main (7 cols)
func renderBody(contentW, bodyH int) string {
    g := styles.NewGrid(contentW+2*styles.MarginW(contentW), bodyH)

    sidebarW := g.Span(3)
    mainW    := g.Span(7)

    sidebar := styles.StylePanel.
        Width(sidebarW).Height(bodyH).
        Render(renderNav())

    main := styles.StylePanel.
        Width(mainW).Height(bodyH).
        Render(renderContent())

    return lipgloss.JoinHorizontal(lipgloss.Top, sidebar, main)
}
```

### 8.6 Reglas del grid

- `ColUnit` es siempre `termW / 12`. Las fracciones se descartan (enteros).
- Los márgenes `MarginL` y `MarginR` son exactamente 1 `ColUnit` cada uno.
- Nunca pasar `termW` crudo a un componente — siempre pasar `g.ContentW` o `g.Span(n)`.
- `BodyH` puede ser 0 si el terminal es muy pequeño; los componentes deben tolerar `height=0`.
- `TopBar` y `Footer` usan `g.ContentW` (no tienen márgenes propios, se extienden al ancho total menos los márgenes ya aplicados al bloque contenedor).

---

## 9. Integración Theme + Grid

El grid y el theme son independientes pero se usan siempre juntos. La regla de integración es simple:

```go
// En el init del programa o en el Update al recibir tea.WindowSizeMsg:
g   := styles.NewGrid(msg.Width, msg.Height)
// A partir de aquí, g.ContentW y g.BodyH son los únicos valores
// que se pasan a los componentes. Nunca msg.Width o msg.Height directos.
```

Los estilos Abyss se aplican sobre las dimensiones que provee el grid:

```go
topBar := styles.StyleTopBar.
    Width(g.TermW).              // TopBar sí ocupa todo el ancho
    Render(fmt.Sprintf(" SBOS  %s", versionBadge))

footer := styles.StyleFooter.
    Width(g.TermW).              // Footer también ocupa todo el ancho
    Render(fmt.Sprintf(" %s  %s", modeName, keyHints))
```

---

## 10. Integración Tailwind (Web UI)

```javascript
// tailwind.config.js
const colors = require('tailwindcss/colors');

module.exports = {
  theme: {
    extend: {
      colors: {
        brand:   colors.cyan,   // acento Abyss
        surface: colors.slate,  // base neutral Abyss
      }
    }
  }
}
```

Clases frecuentes:

```
Fondos:   bg-slate-950  bg-slate-900  bg-slate-800
Texto:    text-slate-100  text-slate-400  text-slate-500
Bordes:   border-slate-800  border-slate-700
Acento:   text-cyan-400  bg-cyan-500  border-cyan-500  bg-cyan-900
```

---

## 11. Checklist de implementación

### Web UI
- [ ] Variables CSS del bloque `:root` (sección 3.1) definidas en el entry point CSS
- [ ] `background: var(--bg-base)` en `<body>`
- [ ] Todos los `input`, `select`, `textarea` usan `--input-bg` (slate-950)
- [ ] El cyan no aparece en más de 4 contextos (sección 5)
- [ ] Placeholders usan `--input-placeholder` (slate-600), no slate-400
- [ ] Sin sombras para profundidad — diferencia de bg entre capas

### TUI
- [ ] Constantes de color en `styles/abyss.go`
- [ ] `NewGrid(msg.Width, msg.Height)` llamado en el handler de `tea.WindowSizeMsg`
- [ ] Ningún componente recibe `termW` o `termH` directos — solo `g.ContentW`, `g.BodyH`, `g.Span(n)`
- [ ] `TopBar` y `Footer` con `Width(g.TermW)` — ocupan el ancho total
- [ ] `body` con `MarginLeft(g.MarginL).MarginRight(g.MarginR)`
- [ ] Ítems activos usan `StyleListItemActive` (acento cyan, border left)
- [ ] `BodyH` tolerado como 0 en terminales muy pequeñas
- [ ] Sin unicode art para bordes — usar `lipgloss.NormalBorder()` o `lipgloss.RoundedBorder()`

---

*SBOS / SKULL — Theme Abyss v1.1.0 — Ivan — 2026*

---

## 9. Propuesta de reestructuración de tokens

> **Problema:** rebuildThemeComponents() asigna ColorCyan a ~20 componentes. No hay jerarquía visual.
> **Solución:** Slate para jerarquía estructural (95% del TUI). Cyan solo en 4 contextos del spec §5 (5% del TUI).

### 9.3 Comparativa ANTES vs DESPUÉS

#### Textos

| Componente | ANTES (hex) | Muestra ANTES | DESPUÉS (hex) | Muestra DESPUÉS |
|-----------|-------------|---------------|---------------|-----------------|
| TopBar fg | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #f8fafc | <span style="display:inline-block;width:28px;height:12px;background:#f8fafc;border-radius:50%;border:1px solid #333;"></span> |
| AccentBold | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #f8fafc | <span style="display:inline-block;width:28px;height:12px;background:#f8fafc;border-radius:50%;border:1px solid #333;"></span> |
| StepOK | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| StepActive | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #f1f5f9 | <span style="display:inline-block;width:28px;height:12px;background:#f1f5f9;border-radius:50%;border:1px solid #333;"></span> |
| LabelActive | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #f8fafc | <span style="display:inline-block;width:28px;height:12px;background:#f8fafc;border-radius:50%;border:1px solid #333;"></span> |
| DataAccent | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| MetricRX | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #cbd5e1 | <span style="display:inline-block;width:28px;height:12px;background:#cbd5e1;border-radius:50%;"></span> |
| CountOK | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| ResourceName | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #f8fafc | <span style="display:inline-block;width:28px;height:12px;background:#f8fafc;border-radius:50%;border:1px solid #333;"></span> |
| DaemonName | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #f8fafc | <span style="display:inline-block;width:28px;height:12px;background:#f8fafc;border-radius:50%;border:1px solid #333;"></span> |
| LinkText | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| KeyHint | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #cbd5e1 | <span style="display:inline-block;width:28px;height:12px;background:#cbd5e1;border-radius:50%;"></span> |
| TabActive | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #f8fafc + border #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#f8fafc;border-radius:50%;border:1px solid #333;"></span> |
| MenuItemActive fg | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> |

#### Bordes, barras y scroll

| Componente | ANTES (hex) | Muestra ANTES | DESPUÉS (hex) | Muestra DESPUÉS |
|-----------|-------------|---------------|---------------|-----------------|
| ScrollThumb | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #94a3b8 | <span style="display:inline-block;width:28px;height:12px;background:#94a3b8;border-radius:50%;"></span> |
| AccentBar | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #0e7490 | <span style="display:inline-block;width:28px;height:12px;background:#0e7490;border-radius:50%;"></span> |
| BoxActive border | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> |
| InputActive border | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> |

---

## 10. Inventario de estilos — ANTES vs PROPUESTA

> **Recorrido:** internal/tui/**/*.go. 175 Foreground + 34 Background + 25 BorderForeground.
> **Criterio:** Slate para estructura, Cyan solo spec §5, Status perceptuales.


### 10.1 Texto — Escala tipográfica

| Estilo | ANTES (hex) | Muestra | PROPUESTA (hex) | Muestra | Paleta |
|--------|-------------|---------|-----------------|---------|--------|
| Heading | — | — | #f8fafc | <span style="display:inline-block;width:28px;height:12px;background:#f8fafc;border-radius:50%;border:1px solid #333;"></span> | Slate-50 |
| White | #f8fafc | <span style="display:inline-block;width:28px;height:12px;background:#f8fafc;border-radius:50%;border:1px solid #333;"></span> | #f8fafc | <span style="display:inline-block;width:28px;height:12px;background:#f8fafc;border-radius:50%;border:1px solid #333;"></span> | Slate-50 |
| AccentBold | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #f8fafc | <span style="display:inline-block;width:28px;height:12px;background:#f8fafc;border-radius:50%;border:1px solid #333;"></span> | Slate-50 |
| Muted | #cbd5e1 | <span style="display:inline-block;width:28px;height:12px;background:#cbd5e1;border-radius:50%;"></span> | #cbd5e1 | <span style="display:inline-block;width:28px;height:12px;background:#cbd5e1;border-radius:50%;"></span> | Slate-300 |
| Dim | #64748b | <span style="display:inline-block;width:28px;height:12px;background:#64748b;border-radius:50%;"></span> | #94a3b8 | <span style="display:inline-block;width:28px;height:12px;background:#94a3b8;border-radius:50%;"></span> | Slate-400 |
| StepOK | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Cyan-400 |
| StepActive | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #f1f5f9 | <span style="display:inline-block;width:28px;height:12px;background:#f1f5f9;border-radius:50%;border:1px solid #333;"></span> | Slate-100 |
| DataAccent | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Cyan-400 |
| MetricRX | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #cbd5e1 | <span style="display:inline-block;width:28px;height:12px;background:#cbd5e1;border-radius:50%;"></span> | Slate-300 |
| CountOK | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Cyan-400 |
| ResourceName | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #f8fafc | <span style="display:inline-block;width:28px;height:12px;background:#f8fafc;border-radius:50%;border:1px solid #333;"></span> | Slate-50 |
| LinkText | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Cyan-400 |
| KeyHint | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #cbd5e1 | <span style="display:inline-block;width:28px;height:12px;background:#cbd5e1;border-radius:50%;"></span> | Slate-300 |
| ScrollThumb | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #94a3b8 | <span style="display:inline-block;width:28px;height:12px;background:#94a3b8;border-radius:50%;"></span> | Slate-400 |
| AccentBar | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #0e7490 | <span style="display:inline-block;width:28px;height:12px;background:#0e7490;border-radius:50%;"></span> | Cyan-700 |
| MenuItemActive fg | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Cyan-500 |
| BoxActive border | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Cyan-500 |
| InputActive border | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Cyan-500 |


---

## 11. Inventario basado en estándares — Códigos para corrección

> **Referencias:** WCAG 2.2 (§2.4.11), Material Design 3 (States), IBM Carbon (Tokens), W3C Design Tokens v1.0.
> **Paletas:** Slate (fondos/bordes), Cyan (textos/foreground), Status (perceptual, no se toca).
> **Uso:** Referenciar por código. Ej: "F04 → slate-700", "M03 → cyan-500".

### 11.1 Superficies y Fondos

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| S01 | ColorBgBase | #0f172a | <span style="display:inline-block;width:28px;height:12px;background:#0f172a;border-radius:50%;"></span> | Slate-900 | Fondo raíz del terminal | ✅ |
| S02 | ColorBgSurface | #1e293b | <span style="display:inline-block;width:28px;height:12px;background:#1e293b;border-radius:50%;"></span> | Slate-800 | Fondo de panel, card, bloque | ✅ |
| S03 | ColorBgElevated | #334155 | <span style="display:inline-block;width:28px;height:12px;background:#334155;border-radius:50%;"></span> | Slate-700 | Fondo elevado: modals, dropdowns | ✅ |
| S04 | ColorBgSurfaceHover | #334155 | <span style="display:inline-block;width:28px;height:12px;background:#334155;border-radius:50%;"></span> | Slate-700 | Panel hover | 🔴 |
| S05 | ColorBgSurfaceActive | #475569 | <span style="display:inline-block;width:28px;height:12px;background:#475569;border-radius:50%;"></span> | Slate-600 | Panel activo/seleccionado | 🔴 |
| S06 | ColorBgInput | #0f172a | <span style="display:inline-block;width:28px;height:12px;background:#0f172a;border-radius:50%;"></span> | Slate-900 | Fondo campo formulario | ✅ |
| S07 | ColorBgInputDisabled | #1e293b | <span style="display:inline-block;width:28px;height:12px;background:#1e293b;border-radius:50%;"></span> | Slate-800 | Fondo campo deshabilitado | 🔴 |
| S08 | ColorBgOverlay | #0f172a | <span style="display:inline-block;width:28px;height:12px;background:#0f172a;border-radius:50%;"></span> | Slate-900 | Fondo overlay modales | 🔴 |
| S09 | ColorBgTooltip | #cbd5e1 | <span style="display:inline-block;width:28px;height:12px;background:#cbd5e1;border-radius:50%;border:1px solid #333;"></span> | Slate-300 | Fondo tooltip invertido | 🔴 |
| S10 | ColorBgBadge | #164e63 | <span style="display:inline-block;width:28px;height:12px;background:#164e63;border-radius:50%;"></span> | Cyan-900 | Fondo badge/chip | 🟡 |
| S11 | ColorBgSelected | #164e63 | <span style="display:inline-block;width:28px;height:12px;background:#164e63;border-radius:50%;"></span> | Cyan-900 | Fondo ítem seleccionado | 🟡 |

### 11.2 Texto

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| T01 | ColorTextHeading | #67e8f9 | <span style="display:inline-block;width:28px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> | Cyan-300 | Títulos | 🔴 |
| T02 | ColorTextPrimary | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Cyan-400 | Texto principal | ✅ |
| T03 | ColorTextSecondary | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Cyan-500 | Labels, timestamps | ✅ |
| T04 | ColorTextMuted | #0891b2 | <span style="display:inline-block;width:28px;height:12px;background:#0891b2;border-radius:50%;"></span> | Cyan-600 | Hints | ✅ |
| T05 | ColorTextDisabled | #0e7490 | <span style="display:inline-block;width:28px;height:12px;background:#0e7490;border-radius:50%;"></span> | Cyan-700 | Deshabilitado | ✅ |
| T06 | ColorTextInverse | #083344 | <span style="display:inline-block;width:28px;height:12px;background:#083344;border-radius:50%;"></span> | Cyan-950 | Sobre fondo claro | 🔴 |
| T07 | ColorTextLink | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Cyan-400 | Enlace | 🟡 |
| T08 | ColorTextError | #f87474 | <span style="display:inline-block;width:28px;height:12px;background:#f87474;border-radius:50%;"></span> | Status | Error | ✅ |
| T09 | ColorTextSuccess | #2dd4a2 | <span style="display:inline-block;width:28px;height:12px;background:#2dd4a2;border-radius:50%;"></span> | Status | Éxito | ✅ |
| T10 | ColorTextWarning | #f9c84a | <span style="display:inline-block;width:28px;height:12px;background:#f9c84a;border-radius:50%;"></span> | Status | Advertencia | ✅ |

### 11.3 Bordes y Líneas

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| B01 | ColorBorder | #334155 | <span style="display:inline-block;width:28px;height:12px;background:#334155;border-radius:50%;"></span> | Slate-700 | Borde normal | ✅ |
| B02 | ColorBorderFocus | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Cyan-500 | Borde foco WCAG 2.4.11 | 🔴 |
| B03 | ColorBorderHover | #64748b | <span style="display:inline-block;width:28px;height:12px;background:#64748b;border-radius:50%;"></span> | Slate-500 | Borde hover | 🔴 |
| B04 | ColorBorderActive | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Cyan-500 | Borde activo | 🟡 |
| B05 | ColorBorderError | #f87474 | <span style="display:inline-block;width:28px;height:12px;background:#f87474;border-radius:50%;"></span> | Status | Borde error | 🔴 |
| B06 | ColorBorderSuccess | #2dd4a2 | <span style="display:inline-block;width:28px;height:12px;background:#2dd4a2;border-radius:50%;"></span> | Status | Borde éxito | 🔴 |
| B07 | ColorBorderDisabled | #475569 | <span style="display:inline-block;width:28px;height:12px;background:#475569;border-radius:50%;"></span> | Slate-600 | Borde deshabilitado | 🔴 |
| B08 | ColorBorderSubtle | #475569 | <span style="display:inline-block;width:28px;height:12px;background:#475569;border-radius:50%;"></span> | Slate-600 | Borde suave | ✅ |
| B09 | ColorBorderStrong | #94a3b8 | <span style="display:inline-block;width:28px;height:12px;background:#94a3b8;border-radius:50%;"></span> | Slate-400 | Borde prominente | 🔴 |
| B10 | ColorDivider | #334155 | <span style="display:inline-block;width:28px;height:12px;background:#334155;border-radius:50%;"></span> | Slate-700 | Separador horizontal | ✅ |

### 11.4 Acento

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| A01 | ColorAccent | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Cyan-400 | Acento principal | ✅ |
| A02 | ColorAccentHover | #67e8f9 | <span style="display:inline-block;width:28px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> | Cyan-300 | Hover | 🔴 |
| A03 | ColorAccentPressed | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Cyan-500 | Pressed | 🔴 |
| A04 | ColorAccentText | #67e8f9 | <span style="display:inline-block;width:28px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> | Cyan-300 | Texto valor positivo | ✅ |
| A05 | ColorAccentSubtle | #164e63 | <span style="display:inline-block;width:28px;height:12px;background:#164e63;border-radius:50%;"></span> | Cyan-900 | Fondo acento suave | ✅ |
| A06 | ColorAccentBorder | #155e75 | <span style="display:inline-block;width:28px;height:12px;background:#155e75;border-radius:50%;"></span> | Cyan-800 | Borde de acento | ✅ |

### 11.5 Scroll

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| R01 | ColorScrollTrack | #334155 | <span style="display:inline-block;width:28px;height:12px;background:#334155;border-radius:50%;"></span> | Slate-700 | Track | 🟡 |
| R02 | ColorScrollThumb | #64748b | <span style="display:inline-block;width:28px;height:12px;background:#64748b;border-radius:50%;"></span> | Slate-500 | Thumb | 🟡 |
| R03 | ColorScrollThumbHover | #94a3b8 | <span style="display:inline-block;width:28px;height:12px;background:#94a3b8;border-radius:50%;"></span> | Slate-400 | Thumb hover | 🔴 |

### 11.6 Iconos

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| I01 | ColorIconPrimary | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Cyan-500 | Icono principal | 🔴 |
| I02 | ColorIconSecondary | #0e7490 | <span style="display:inline-block;width:28px;height:12px;background:#0e7490;border-radius:50%;"></span> | Cyan-700 | Icono secundario | 🔴 |
| I03 | ColorIconDisabled | #164e63 | <span style="display:inline-block;width:28px;height:12px;background:#164e63;border-radius:50%;"></span> | Cyan-900 | Icono deshabilitado | 🔴 |
| I04 | ColorIconAccent | #67e8f9 | <span style="display:inline-block;width:28px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> | Cyan-300 | Icono activo | 🟡 |
| I05 | ColorIconError | #f87474 | <span style="display:inline-block;width:28px;height:12px;background:#f87474;border-radius:50%;"></span> | Status | Error | ✅ |
| I06 | ColorIconSuccess | #2dd4a2 | <span style="display:inline-block;width:28px;height:12px;background:#2dd4a2;border-radius:50%;"></span> | Status | Éxito | ✅ |
| I07 | ColorIconWarning | #f9c84a | <span style="display:inline-block;width:28px;height:12px;background:#f9c84a;border-radius:50%;"></span> | Status | Advertencia | ✅ |


### 11.7 Barras de Progreso

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| P01 | ColorProgressFill | #0891b2 | <span style="display:inline-block;width:28px;height:12px;background:#0891b2;border-radius:50%;"></span> | Cyan-600 | Relleno de barra | 🟡 |
| P02 | ColorProgressTrack | #1e293b | <span style="display:inline-block;width:28px;height:12px;background:#1e293b;border-radius:50%;"></span> | Slate-800 | Track de barra | 🔴 |
| P03 | ColorProgressIndeterminate | #475569 | <span style="display:inline-block;width:28px;height:12px;background:#475569;border-radius:50%;"></span> | Slate-600 | Barra sin % conocido | 🔴 |

### 11.8 Notificaciones

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| N01 | ColorNotifySuccessBg | #051a10 | <span style="display:inline-block;width:28px;height:12px;background:#051a10;border-radius:50%;"></span> | Status | Fondo éxito | 🔴 |
| N02 | ColorNotifySuccessBorder | #0a9e62 | <span style="display:inline-block;width:28px;height:12px;background:#0a9e62;border-radius:50%;"></span> | Status | Borde éxito | 🔴 |
| N03 | ColorNotifySuccessText | #2dd4a2 | <span style="display:inline-block;width:28px;height:12px;background:#2dd4a2;border-radius:50%;"></span> | Status | Texto éxito | 🟡 |
| N04 | ColorNotifyWarnBg | #1a1100 | <span style="display:inline-block;width:28px;height:12px;background:#1a1100;border-radius:50%;"></span> | Status | Fondo warning | 🔴 |
| N05 | ColorNotifyWarnBorder | #a87b00 | <span style="display:inline-block;width:28px;height:12px;background:#a87b00;border-radius:50%;"></span> | Status | Borde warning | 🔴 |
| N06 | ColorNotifyWarnText | #f9c84a | <span style="display:inline-block;width:28px;height:12px;background:#f9c84a;border-radius:50%;"></span> | Status | Texto warning | 🟡 |
| N07 | ColorNotifyErrorBg | #1a0505 | <span style="display:inline-block;width:28px;height:12px;background:#1a0505;border-radius:50%;"></span> | Status | Fondo error | 🔴 |
| N08 | ColorNotifyErrorBorder | #c41c1c | <span style="display:inline-block;width:28px;height:12px;background:#c41c1c;border-radius:50%;"></span> | Status | Borde error | 🔴 |
| N09 | ColorNotifyErrorText | #f87474 | <span style="display:inline-block;width:28px;height:12px;background:#f87474;border-radius:50%;"></span> | Status | Texto error | 🟡 |
| N10 | ColorNotifyInfoBg | #030f1e | <span style="display:inline-block;width:28px;height:12px;background:#030f1e;border-radius:50%;"></span> | Status | Fondo info | 🔴 |
| N11 | ColorNotifyInfoBorder | #1a6fa8 | <span style="display:inline-block;width:28px;height:12px;background:#1a6fa8;border-radius:50%;"></span> | Status | Borde info | 🔴 |
| N12 | ColorNotifyInfoText | #5ab8f5 | <span style="display:inline-block;width:28px;height:12px;background:#5ab8f5;border-radius:50%;"></span> | Status | Texto info | 🟡 |

### 11.9 Formularios

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| F01 | InputNormalBg | #0f172a | <span style="display:inline-block;width:28px;height:12px;background:#0f172a;border-radius:50%;"></span> | Slate-900 | Fondo campo reposo | ✅ |
| F02 | InputNormalBorder | #334155 | <span style="display:inline-block;width:28px;height:12px;background:#334155;border-radius:50%;"></span> | Slate-700 | Borde campo reposo | ✅ |
| F03 | InputFocusBg | #1e293b | <span style="display:inline-block;width:28px;height:12px;background:#1e293b;border-radius:50%;"></span> | Slate-800 | Fondo campo foco | ✅ |
| F04 | InputFocusBorder | #0891b2 | <span style="display:inline-block;width:28px;height:12px;background:#0891b2;border-radius:50%;"></span> | Cyan-600 | Borde campo foco WCAG 2.4.11 | ✅ |
| F05 | InputErrorBg | #0f172a | <span style="display:inline-block;width:28px;height:12px;background:#0f172a;border-radius:50%;"></span> | Slate-900 | Fondo campo error | 🔴 |
| F06 | InputErrorBorder | #f87474 | <span style="display:inline-block;width:28px;height:12px;background:#f87474;border-radius:50%;"></span> | Status | Borde campo error | 🔴 |
| F07 | InputDisabledBg | #1e293b | <span style="display:inline-block;width:28px;height:12px;background:#1e293b;border-radius:50%;"></span> | Slate-800 | Fondo campo disabled | 🔴 |
| F08 | InputDisabledBorder | #475569 | <span style="display:inline-block;width:28px;height:12px;background:#475569;border-radius:50%;"></span> | Slate-600 | Borde campo disabled | 🔴 |
| F09 | InputPlaceholder | #0e7490 | <span style="display:inline-block;width:28px;height:12px;background:#0e7490;border-radius:50%;"></span> | Cyan-700 | Texto placeholder | ✅ |
| F10 | InputCursor | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Cyan-400 | Cursor de texto | 🔴 |
| F11 | InputSelection | #164e63 | <span style="display:inline-block;width:28px;height:12px;background:#164e63;border-radius:50%;"></span> | Cyan-900 | Selección de texto | 🔴 |

### 11.10 Menú y Navegación

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| M01 | MenuItemNormalFg | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Cyan-500 | Item menú — texto | ✅ |
| M02 | MenuItemHoverBg | #334155 | <span style="display:inline-block;width:28px;height:12px;background:#334155;border-radius:50%;"></span> | Slate-700 | Item menú hover — fondo | 🔴 |
| M03 | MenuItemActiveFg | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Cyan-400 | Item menú activo — texto | 🟡 |
| M04 | MenuItemActiveBg | #164e63 | <span style="display:inline-block;width:28px;height:12px;background:#164e63;border-radius:50%;"></span> | Cyan-900 | Item menú activo — fondo | ✅ |
| M05 | MenuItemActiveIndicator | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Cyan-500 | Item menú activo — barra lateral | ✅ |
| M06 | MenuItemDisabledFg | #0e7490 | <span style="display:inline-block;width:28px;height:12px;background:#0e7490;border-radius:50%;"></span> | Cyan-700 | Item menú disabled — texto | 🔴 |
| M07 | MenuSeparator | #334155 | <span style="display:inline-block;width:28px;height:12px;background:#334155;border-radius:50%;"></span> | Slate-700 | Separador entre items | ✅ |
| M08 | MenuGroupTitle | #0891b2 | <span style="display:inline-block;width:28px;height:12px;background:#0891b2;border-radius:50%;"></span> | Cyan-600 | Título de grupo | 🔴 |

### 11.11 Tabs / Pestañas

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| K01 | TabNormalFg | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Cyan-500 | Tab reposo — texto | 🔴 |
| K02 | TabActiveFg | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Cyan-400 | Tab activa — texto | 🟡 |
| K03 | TabActiveIndicator | #06b6d4 | <span style="display:inline-block;width:28px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Cyan-500 | Tab activa — indicador | 🟡 |
| K04 | TabHoverBg | #334155 | <span style="display:inline-block;width:28px;height:12px;background:#334155;border-radius:50%;"></span> | Slate-700 | Tab hover — fondo | 🔴 |
| K05 | TabDisabledFg | #0e7490 | <span style="display:inline-block;width:28px;height:12px;background:#0e7490;border-radius:50%;"></span> | Cyan-700 | Tab disabled — texto | 🔴 |

### 11.12 Badges / Chips

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| G01 | BadgeBg | #164e63 | <span style="display:inline-block;width:28px;height:12px;background:#164e63;border-radius:50%;"></span> | Cyan-900 | Badge — fondo | 🟡 |
| G02 | BadgeFg | #67e8f9 | <span style="display:inline-block;width:28px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> | Cyan-300 | Badge — texto | 🟡 |
| G03 | BadgeBorder | #0e7490 | <span style="display:inline-block;width:28px;height:12px;background:#0e7490;border-radius:50%;"></span> | Cyan-700 | Badge — borde | 🟡 |
| G04 | BadgeCounterBg | #f87474 | <span style="display:inline-block;width:28px;height:12px;background:#f87474;border-radius:50%;"></span> | Status | Badge numérico — fondo | 🔴 |
| G05 | BadgeCounterFg | #f8fafc | <span style="display:inline-block;width:28px;height:12px;background:#f8fafc;border-radius:50%;border:1px solid #333;"></span> | Slate-50 | Badge numérico — texto | 🔴 |
| G06 | BadgeDot | #22d3ee | <span style="display:inline-block;width:28px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Cyan-400 | Indicador presencia | 🔴 |

### 11.13 Tooltip

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| L01 | TooltipBg | #0f172a | <span style="display:inline-block;width:28px;height:12px;background:#0f172a;border-radius:50%;"></span> | Slate-900 | Fondo tooltip | 🔴 |
| L02 | TooltipFg | #f1f5f9 | <span style="display:inline-block;width:28px;height:12px;background:#f1f5f9;border-radius:50%;border:1px solid #333;"></span> | Slate-100 | Texto tooltip | 🔴 |
| L03 | TooltipBorder | #334155 | <span style="display:inline-block;width:28px;height:12px;background:#334155;border-radius:50%;"></span> | Slate-700 | Borde tooltip | 🔴 |

### 11.14 Botones

> **Referencias:** WCAG 2.2 (§2.4.11 Focus Appearance), Material Design 3 (Button states), IBM Carbon (Button variants), W3C Design Tokens v1.0.
> **Reglas:** Background + BorderBackground fijos entre focused/blurred. Solo cambian BorderForeground (foco) y Foreground/Bold (texto).
> **Padding:** `(0, 0)` compact (§4.7). **Border:** `RoundedBorder()` en todos. **Color de foco:** `ColorBorderFocus` (#06b6d4) universal.

| Código | Tipo | BG (hereda S02) | Fore (texto) | Border | Descripción | Estado |
|--------|------|-----------------|-------------|--------|------------|--------|
| BT01 | BtnPrimary | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#155e75;border-radius:50%;"></span> #155e75 | <span style="display:inline-block;width:18px;height:18px;background:#155e75;border-radius:50%;"></span> #155e75 | bg S02 Slate-900, fg Cyan-800, border Cyan-800 | 🔴 |
| BT01-F | BtnPrimaryFocused | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#06b6d4;border-radius:50%;"></span> #06b6d4 | <span style="display:inline-block;width:18px;height:18px;background:#06b6d4;border-radius:50%;"></span> #06b6d4 | foco: fg Cyan-500, border Cyan-500, bold | 🔴 |
| BT02 | BtnSecondary | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#cffafe;border-radius:50%;border:1px solid #333;"></span> #cffafe | <span style="display:inline-block;width:18px;height:18px;background:#cffafe;border-radius:50%;border:1px solid #333;"></span> #cffafe | bg S02 Slate-900, fg Cyan-100, border Cyan-100 | 🔴 |
| BT02-F | BtnSecondaryFocused | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0e7490;border-radius:50%;"></span> #0e7490 | <span style="display:inline-block;width:18px;height:18px;background:#0e7490;border-radius:50%;"></span> #0e7490 | foco: fg Cyan-700, border Cyan-700, bold | 🔴 |
| BT03 | BtnDanger | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#ff5555;border-radius:50%;"></span> #ff5555 | <span style="display:inline-block;width:18px;height:18px;background:#cc0000;border-radius:50%;"></span> #cc0000 | bg S02 Slate-900, fg CritFg, border CritBorder | 🔴 |
| BT03-F | BtnDangerFocused | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#cc0000;border-radius:50%;"></span> #cc0000 | <span style="display:inline-block;width:18px;height:18px;background:#ff5555;border-radius:50%;"></span> #ff5555 | foco: fg CritBorder, border CritFg, bold | 🔴 |
| BT04 | BtnGhost | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#475569;border-radius:50%;"></span> #475569 | <span style="display:inline-block;width:18px;height:18px;background:#475569;border-radius:50%;"></span> #475569 | bg S02 Slate-900, fg Slate-600, border Slate-600 | 🔴 |
| BT04-F | BtnGhostFocused | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#475569;border-radius:50%;"></span> #475569 | <span style="display:inline-block;width:18px;height:18px;background:#94a3b8;border-radius:50%;border:1px solid #333;"></span> #94a3b8 | foco: fg Slate-600, border Slate-400, bold | 🔴 |
| BT05 | BtnDisabled | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#475569;border-radius:50%;"></span> #475569 | <span style="display:inline-block;width:18px;height:18px;background:#475569;border-radius:50%;"></span> #475569 | bg S02 Slate-900, fg/border B07 Slate-600 | 🔴 |
| BT06 | BtnSuccess | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#15803d;border-radius:50%;"></span> #15803d | <span style="display:inline-block;width:18px;height:18px;background:#0a9e62;border-radius:50%;"></span> #0a9e62 | bg S02 Slate-900, fg Green-700, border OKBorder | 🔴 |
| BT06-F | BtnSuccessFocused | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#2dd4a2;border-radius:50%;"></span> #2dd4a2 | <span style="display:inline-block;width:18px;height:18px;background:#166534;border-radius:50%;"></span> #166534 | foco: fg OKFg, border Green-800, bold | 🔴 |
| BT07 | BtnWarning | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#f9c84a;border-radius:50%;border:1px solid #333;"></span> #f9c84a | <span style="display:inline-block;width:18px;height:18px;background:#a87b00;border-radius:50%;"></span> #a87b00 | bg S02 Slate-900, fg WarnFg, border WarnBorder | 🔴 |
| BT07-F | BtnWarningFocused | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#a87b00;border-radius:50%;"></span> #a87b00 | <span style="display:inline-block;width:18px;height:18px;background:#f9c84a;border-radius:50%;border:1px solid #333;"></span> #f9c84a | foco: fg WarnBorder, border WarnFg, bold | 🔴 |
| BT08 | BtnInfo | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#5ab8f5;border-radius:50%;"></span> #5ab8f5 | <span style="display:inline-block;width:18px;height:18px;background:#1a6fa8;border-radius:50%;"></span> #1a6fa8 | bg S02 Slate-900, fg InfoFg, border InfoBorder | 🔴 |
| BT08-F | BtnInfoFocused | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#1a6fa8;border-radius:50%;"></span> #1a6fa8 | <span style="display:inline-block;width:18px;height:18px;background:#5ab8f5;border-radius:50%;"></span> #5ab8f5 | foco: fg InfoBorder, border InfoFg, bold | 🔴 |
| BT09 | BtnLink | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0e7490;border-radius:50%;"></span> #0e7490 | — | bg S02 Slate-900, fg Cyan-700, sin borde | 🔴 |
| BT09-F | BtnLinkFocused | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#06b6d4;border-radius:50%;"></span> #06b6d4 | — | foco: fg Cyan-500 bold + underline | 🔴 |
| BT10 | BtnIcon | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#94a3b8;border-radius:50%;border:1px solid #333;"></span> #94a3b8 | <span style="display:inline-block;width:18px;height:18px;background:#0e7490;border-radius:50%;"></span> #0e7490 | bg S02 Slate-900, fg Slate-400, border Cyan-700 | 🔴 |
| BT10-F | BtnIconFocused | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0e7490;border-radius:50%;"></span> #0e7490 | <span style="display:inline-block;width:18px;height:18px;background:#94a3b8;border-radius:50%;border:1px solid #333;"></span> #94a3b8 | foco: fg Cyan-700, border Slate-400, bold | 🔴 |

> **Regla de herencia de fondo:** **Ningún botón declara `Background()` ni `BorderBackground()`.** Todos los botones heredan el fondo del contenedor donde se renderizan (S02 = `ColorBgSurface` = #0f172a en Abyss). La distinción entre tipos se logra solo con `BorderForeground` + `Foreground` + `Bold`. Esto se logra sin código: lipgloss aplica `panel.Render(button.View())` y el `Background()` del panel rellena todo el área.

### 11.15 TextBox / Inputs

> **Referencias:** WCAG 2.2 (§2.4.11 Focus Appearance, §3.3.2 Labels), Material Design 3 (Text field states), IBM Carbon (Text input variants), W3C Design Tokens v1.0.
> **Reglas:** Background + BorderBackground fijos entre estados. Solo cambian BorderForeground y Foreground. Cursor visible solo en Focused (F10).
> **Padding:** `(0, 1)` comfortable, `(0, 0)` compact. **Border:** `NormalBorder()` en todos.

| Código | Tipo | BG (hereda S02) | Fore (texto) | Border | Descripción | Estado |
|--------|------|-----------------|-------------|--------|------------|--------|
| TX01 | InputNormal | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#e2e8f0;border-radius:50%;border:1px solid #333;"></span> #e2e8f0 | <span style="display:inline-block;width:18px;height:18px;background:#475569;border-radius:50%;"></span> #475569 | **Blurred** — bg S02, fg Slate-200, border Slate-600 | 🔴 |
| TX02 | InputFocus | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#e2e8f0;border-radius:50%;border:1px solid #333;"></span> #e2e8f0 | <span style="display:inline-block;width:18px;height:18px;background:#155e75;border-radius:50%;"></span> #155e75 | **Focused** — bg S02, fg Slate-200, border Cyan-800 | 🔴 |
| TX03 | InputHover | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#a5f3fc;border-radius:50%;border:1px solid #333;"></span> #a5f3fc | <span style="display:inline-block;width:18px;height:18px;background:#164e63;border-radius:50%;"></span> #164e63 | **Hovered** — bg S02, fg Cyan-200, border Cyan-900 | 🔴 |
| TX04 | InputDisabled | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#475569;border-radius:50%;"></span> #475569 | <span style="display:inline-block;width:18px;height:18px;background:#475569;border-radius:50%;"></span> #475569 | **Disabled** — bg S02, fg T05, border F08 Slate-600 | 🔴 |
| TX05 | InputError | <span style="display:inline-block;width:18px;height:18px;background:#020617;border-radius:50%;border:1px solid #334155;"></span> #020617 | <span style="display:inline-block;width:18px;height:18px;background:#ff5555;border-radius:50%;"></span> #ff5555 | <span style="display:inline-block;width:18px;height:18px;background:#cc0000;border-radius:50%;"></span> #cc0000 | **Error** — bg F05 Slate-950, fg CritFg, border CritBorder | 🔴 |
| TX06 | InputSuccess | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#2dd4a2;border-radius:50%;"></span> #2dd4a2 | <span style="display:inline-block;width:18px;height:18px;background:#0a9e62;border-radius:50%;"></span> #0a9e62 | **Success** — bg S02, fg OKFg, border OKBorder | 🔴 |
| TX07 | InputReadOnly | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #334155;"></span> #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#64748b;border-radius:50%;"></span> #64748b | <span style="display:inline-block;width:18px;height:18px;background:#1e293b;border-radius:50%;border:1px solid #334155;"></span> #1e293b | **Read Only** — bg S02, fg Slate-500, border Slate-800 | 🔴 |

**Placeholder / Texto interno:**

| Código | Token | Hex | Muestra | Descripción | Estado |
|--------|-------|-----|---------|------------|--------|
| TX08 | InputPlaceholder | #0e7490 | <span style="display:inline-block;width:18px;height:18px;background:#0e7490;border-radius:50%;"></span> | Placeholder — Cyan-700 | 🔴 |
| TX09 | InputCursor | #164e63 | <span style="display:inline-block;width:18px;height:18px;background:#164e63;border-radius:50%;"></span> | Cursor — Cyan-900, solo visible en Focused | 🔴 |
| TX10 | InputSelection | #0e7490 | <span style="display:inline-block;width:18px;height:18px;background:#0e7490;border-radius:50%;"></span> | Selección de texto — Cyan-700 | 🔴 |

**Estados por input (WCAG 2.4.11 + Material Design 3):**

| Estado | Cambia | No cambia |
|--------|--------|-----------|
| Focused | BorderForeground → F04 Cyan-600, Foreground → T02, cursor visible | Background, BorderBackground |
| Blurred | BorderForeground → F02 Slate-700, Foreground → T02, sin cursor | Background, BorderBackground |
| Hovered | BorderForeground → B03 Slate-500 | Background, BorderBackground |
| Disabled | BorderForeground → F08, Foreground → T05, sin cursor | Background, BorderBackground |
| Error | BorderForeground → F06 ErrFg, texto error → T08 | Background (cambia a F05) |
| Success | BorderForeground → B06 OKFg | Background, BorderBackground |

### 11.15.2 TextArea — texto multilínea

> **Librería:** `bubbles/textarea` — similar a `<textarea>` en HTML.
> **Reglas:** mismas que TextBox (TX01–TX07). Border `NormalBorder()`, bg heredado S02.

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| TA01 | TextAreaNormal | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:1px solid #475569;"></span> #0f172a | S02 + Slate-600 | **Blurred** — bg S02, fg Slate-200, border Slate-600 | 🔴 |
| TA02 | TextAreaFocus | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:2px solid #155e75;"></span> #0f172a | S02 + Cyan-800 | **Focused** — bg S02, fg Slate-200, border Cyan-800 | 🔴 |
| TA03 | TextAreaDisabled | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:1px solid #475569;"></span> #0f172a | S02 + Slate-600 | **Disabled** — bg S02, fg Slate-600, border Slate-600 | 🔴 |

### 11.15.3 Select / Dropdown

> **Librería:** `huh.Select` / `bubbles/list` — análogo a `<select>` en HTML.
> **Reglas:** usa `Item` variant para opciones (Base=normal, Selected=focused, Disabled).

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| SL01 | SelectNormal | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:1px solid #475569;"></span> #0f172a | S02 + Slate-600 | **Blurred** — bg S02, fg Slate-200, border Slate-600 | 🔴 |
| SL02 | SelectFocus | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:2px solid #155e75;"></span> #0f172a | S02 + Cyan-800 | **Focused** — bg S02, fg Slate-200, border Cyan-800 | 🔴 |
| SL03 | SelectOpen | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:2px solid #06b6d4;"></span> #0f172a | S02 + Cyan-500 | **Open** — bg S02, fg Slate-200, border Cyan-500 | 🔴 |
| SL04 | SelectDisabled | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:1px solid #475569;"></span> #0f172a | S02 + Slate-600 | **Disabled** — bg S02, fg Slate-600 | 🔴 |
| SL05 | SelectOption | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;"></span> #0f172a | S02 | **Option** — bg S02, fg Slate-200 | 🔴 |
| SL06 | SelectOptionActive | #164e63 | <span style="display:inline-block;width:18px;height:18px;background:#164e63;border-radius:3px;"></span> #164e63 | Cyan-900 | **Option Active** — bg Cyan-900, fg Cyan-400 | 🔴 |

### 11.15.4 MultiSelect

> **Librería:** `huh.MultiSelect` — selección múltiple con checkmarks.

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| MS01 | MultiSelectNormal | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:1px solid #475569;"></span> #0f172a | S02 + Slate-600 | **Blurred** — igual que Select | 🔴 |
| MS02 | MultiSelectFocus | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:2px solid #155e75;"></span> #0f172a | S02 + Cyan-800 | **Focused** — igual que Select | 🔴 |
| MS03 | MultiSelectChecked | #22d3ee | <span style="display:inline-block;width:18px;height:18px;background:#22d3ee;border-radius:50%;"></span> #22d3ee | Cyan-400 | **Checked mark** — fg Cyan-400 | 🔴 |
| MS04 | MultiSelectUnchecked | #475569 | <span style="display:inline-block;width:18px;height:18px;background:#475569;border-radius:50%;"></span> #475569 | Slate-600 | **Unchecked mark** — fg Slate-600 | 🔴 |

### 11.15.5 Checkbox

> **Librería:** Custom (no existe en bubbles/huh nativo). Basado en `IconCheckboxOn`/`IconCheckboxOff`.
> **Reglas:** mismo patrón que botones — bg S02, border cambia por estado.

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| CB01 | CheckboxOff | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:1px solid #475569;"></span> #0f172a | S02 + Slate-600 | **Unchecked** — bg S02, fg Slate-200, border Slate-600 | 🔴 |
| CB02 | CheckboxOffHover | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:1px solid #06b6d4;"></span> #0f172a | S02 + Cyan-500 | **Unchecked Hover** — border Cyan-500 | 🔴 |
| CB03 | CheckboxOn | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:1px solid #06b6d4;"></span> #0f172a | S02 + Cyan-500 | **Checked** — bg S02, fg Cyan-500, border Cyan-500 | 🔴 |
| CB04 | CheckboxDisabled | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:1px solid #475569;"></span> #0f172a | S02 + Slate-600 | **Disabled** — bg S02, fg Slate-600 | 🔴 |

### 11.15.6 RadioButton

> **Librería:** Custom. `IconRadioOn` / `IconCircleOpen`. Selección exclusiva.

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| RB01 | RadioOff | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #475569;"></span> #0f172a | S02 + Slate-600 | **Unselected** — circle open, fg Slate-600 | 🔴 |
| RB02 | RadioOffHover | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:2px solid #06b6d4;"></span> #0f172a | S02 + Cyan-500 | **Unselected Hover** — border Cyan-500 | 🔴 |
| RB03 | RadioOn | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:2px solid #06b6d4;"></span> #0f172a | S02 + Cyan-500 | **Selected** — dot filled, fg Cyan-500 | 🔴 |
| RB04 | RadioDisabled | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:50%;border:1px solid #475569;"></span> #0f172a | S02 + Slate-600 | **Disabled** — fg Slate-600 | 🔴 |

### 11.15.7 Confirm / Toggle

> **Librería:** `huh.Confirm` — sí/no, true/false.

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| CF01 | ConfirmNormal | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:1px solid #475569;"></span> #0f172a | S02 + Slate-600 | **Blurred** — fg Slate-200, border Slate-600 | 🔴 |
| CF02 | ConfirmFocus | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:2px solid #155e75;"></span> #0f172a | S02 + Cyan-800 | **Focused** — border Cyan-800 | 🔴 |
| CF03 | ConfirmYes | #2dd4a2 | <span style="display:inline-block;width:18px;height:18px;background:#2dd4a2;border-radius:50%;"></span> #2dd4a2 | OKFg | **Yes/True** — fg OKFg | 🔴 |
| CF04 | ConfirmNo | #f87474 | <span style="display:inline-block;width:18px;height:18px;background:#f87474;border-radius:50%;"></span> #f87474 | ErrFg | **No/False** — fg ErrFg | 🔴 |

### 11.15.8 FilePicker

> **Librería:** `bubbles/filepicker` — navegación de archivos/directorios.

| Código | Token | Hex | Muestra | Paleta | Descripción | Estado |
|--------|-------|-----|---------|--------|------------|--------|
| FP01 | FilePickerBorder | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:1px solid #475569;"></span> #0f172a | S02 + Slate-600 | **Border** — bg S02, border Slate-600 | 🔴 |
| FP02 | FilePickerFocus | #0f172a | <span style="display:inline-block;width:18px;height:18px;background:#0f172a;border-radius:3px;border:2px solid #155e75;"></span> #0f172a | S02 + Cyan-800 | **Focused** — border Cyan-800 | 🔴 |
| FP03 | FilePickerDirectory | #22d3ee | <span style="display:inline-block;width:18px;height:18px;background:#22d3ee;border-radius:50%;"></span> #22d3ee | Cyan-400 | **Directory** — fg Cyan-400, bold | 🔴 |
| FP04 | FilePickerFile | #e2e8f0 | <span style="display:inline-block;width:18px;height:18px;background:#e2e8f0;border-radius:50%;border:1px solid #333;"></span> #e2e8f0 | Slate-200 | **File** — fg Slate-200 | 🔴 |
| FP05 | FilePickerSelected | #164e63 | <span style="display:inline-block;width:18px;height:18px;background:#164e63;border-radius:3px;"></span> #164e63 | Cyan-900 | **Selected** — bg Cyan-900, fg Cyan-400 | 🔴 |
| FP06 | FilePickerDisabled | #475569 | <span style="display:inline-block;width:18px;height:18px;background:#475569;border-radius:50%;"></span> #475569 | Slate-600 | **Disabled** — fg Slate-600 | 🔴 |

### 11.16 Resumen

| Categoría | Códigos | Total | ✅ | 🟡 | 🔴 |
|-----------|---------|-------|----|----|-----|
| Superficies | S01–S11 | 11 | 3 | 2 | 6 |
| Texto | T01–T10 | 10 | 4 | 1 | 5 |
| Bordes | B01–B10 | 10 | 3 | 1 | 6 |
| Acento | A01–A06 | 6 | 4 | 0 | 2 |
| Scroll | R01–R03 | 3 | 0 | 2 | 1 |
| Iconos | I01–I07 | 7 | 3 | 1 | 3 |
| Progreso | P01–P03 | 3 | 0 | 1 | 2 |
| Notificaciones | N01–N12 | 12 | 0 | 4 | 8 |
| Formularios | F01–F11 | 11 | 5 | 0 | 6 |
| Menú | M01–M08 | 8 | 3 | 1 | 4 |
| Tabs | K01–K05 | 5 | 0 | 2 | 3 |
| Badges | G01–G06 | 6 | 0 | 3 | 3 |
| Tooltip | L01–L03 | 3 | 0 | 0 | 3 |
| Botones | BT01–BT10 | 20 | 0 | 0 | 20 |
| TextBox | TX01–TX10 | 10 | 0 | 0 | 10 |
| TextArea | TA01–TA03 | 3 | 0 | 0 | 3 |
| Select | SL01–SL06 | 6 | 0 | 0 | 6 |
| MultiSelect | MS01–MS04 | 4 | 0 | 0 | 4 |
| Checkbox | CB01–CB04 | 4 | 0 | 0 | 4 |
| RadioButton | RB01–RB04 | 4 | 0 | 0 | 4 |
| Confirm | CF01–CF04 | 4 | 0 | 0 | 4 |
| FilePicker | FP01–FP06 | 6 | 0 | 0 | 6 |
| **TOTAL** | — | **169** | **25** | **18** | **126** |


---

## 12. Registro de estado de reparación

> **Referencia:** §13 — 81 acciones token por token.
> **Orden:** FASE 1 → 2 → 3 → 4 → 5.

### FASE 1 — tokens_semantic.go (§13.1)

Archivo: `styles/tokens_semantic.go`. 24 tokens.

| Estado | Progreso |
|--------|----------|
| 🔴 PENDIENTE | 0/24 |

### FASE 2 — theme.go:rebuildThemeComponents() (§13.2)

Archivo: `styles/theme.go`. 36 estilos. Depende de FASE 1.

| Estado | Progreso |
|--------|----------|
| 🔴 PENDIENTE | 0/36 |

### FASE 3 — Otros archivos (§13.3)

Archivos: `model/model.go`, `styles/icons.go`, `styles/huh_theme.go`. 8 estilos.

| Estado | Progreso |
|--------|----------|
| 🔴 PENDIENTE | 0/8 |

### FASE 4 — Tokens nuevos (§13.4)

Crear 13 tokens. Archivo: `styles/tokens_semantic.go`.

| Estado | Progreso |
|--------|----------|
| 🔴 PENDIENTE | 0/13 |

### FASE 5 — Pantallas, dashboard, modelo

29 archivos: screens/ (16), ctrl/ (8), model/ (2), app/ (1), shared (2).

| Estado | Progreso |
|--------|----------|
| 🔴 PENDIENTE | 0/29 |

---

| Fase | Alcance | Acciones | Estado |
|------|---------|----------|--------|
| 1 | tokens_semantic.go | 24 | 🔴 0/24 |
| 2 | theme.go:rebuildThemeComponents | 36 | 🔴 0/36 |
| 3 | model + icons + huh_theme | 8 | 🔴 0/8 |
| 4 | tokens nuevos | 13 | 🔴 0/13 |
| 5 | pantallas + dashboard + modelo | 29 | 🔴 0/29 |
| **TOTAL** | — | **110** | 🔴 **0/110** |


---

## 13. Plan de ejecución — Token por token

> **Columnas:** Archivo, Código §11, Token §11, Hex, Muestra, Tipo (REEMPLAZO o NUEVO), Acción.

### 13.1 tokens_semantic.go — REEMPLAZOS (24)

| # | Código | Token §11 | Hex | Muestra | Acción |
|---|--------|----------|-----|---------|--------|
| 1 | A01 | ColorAccent | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> | `ColorCyan = lipgloss.Color(PrimCyan400)` |
| 2 | A04 | ColorAccentText | #67e8f9 | <span style="display:inline-block;width:20px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> | `ColorAccentText = lipgloss.Color(PrimCyan300)` |
| 3 | T01 | ColorTextHeading | #67e8f9 | <span style="display:inline-block;width:20px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> | Nuevo: `ColorTextHeading = lipgloss.Color(PrimCyan300)` |
| 4 | T02 | ColorTextPrimary | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> | `ColorTextPrimary = lipgloss.Color(PrimCyan400)` |
| 5 | T03 | ColorTextSecondary | #06b6d4 | <span style="display:inline-block;width:20px;height:12px;background:#06b6d4;border-radius:50%;"></span> | `ColorTextSecondary = lipgloss.Color(PrimCyan500)` |
| 6 | T04 | ColorTextMuted | #0891b2 | <span style="display:inline-block;width:20px;height:12px;background:#0891b2;border-radius:50%;"></span> | `ColorTextMuted = lipgloss.Color(PrimCyan600)` |
| 7 | T05 | ColorTextDisabled | #0e7490 | <span style="display:inline-block;width:20px;height:12px;background:#0e7490;border-radius:50%;"></span> | `ColorTextDisabled = lipgloss.Color(PrimCyan700)` |
| 8 | T07 | ColorTextLink | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Nuevo: `ColorTextLink = lipgloss.Color(PrimCyan400)` |
| 9 | S01 | ColorBgBase | #0f172a | <span style="display:inline-block;width:20px;height:12px;background:#0f172a;border-radius:50%;"></span> | `ColorBgBase = lipgloss.Color(PrimSlate900)` |
| 10 | S02 | ColorBgSurface | #1e293b | <span style="display:inline-block;width:20px;height:12px;background:#1e293b;border-radius:50%;"></span> | `ColorBgSurface = lipgloss.Color(PrimSlate800)` |
| 11 | B01 | ColorBorder | #334155 | <span style="display:inline-block;width:20px;height:12px;background:#334155;border-radius:50%;"></span> | `ColorBorder = lipgloss.Color(PrimSlate700)` |
| 12 | B10 | ColorDivider | #334155 | <span style="display:inline-block;width:20px;height:12px;background:#334155;border-radius:50%;"></span> | Nuevo: `ColorDivider = lipgloss.Color(PrimSlate700)` |
| 13 | R01 | ColorScrollTrack | #1e293b | <span style="display:inline-block;width:20px;height:12px;background:#1e293b;border-radius:50%;"></span> | Nuevo: `ColorScrollTrack = lipgloss.Color(PrimSlate800)` |
| 14 | R02 | ColorScrollThumb | #475569 | <span style="display:inline-block;width:20px;height:12px;background:#475569;border-radius:50%;"></span> | Nuevo: `ColorScrollThumb = lipgloss.Color(PrimSlate600)` |
| 15 | P01 | ColorProgressFill | #0891b2 | <span style="display:inline-block;width:20px;height:12px;background:#0891b2;border-radius:50%;"></span> | Nuevo: `ColorProgressFill = lipgloss.Color(PrimCyan600)` |
| 16 | P02 | ColorProgressTrack | #1e293b | <span style="display:inline-block;width:20px;height:12px;background:#1e293b;border-radius:50%;"></span> | Nuevo: `ColorProgressTrack = lipgloss.Color(PrimSlate800)` |
| 17 | F01 | ColorInputBg | #0f172a | <span style="display:inline-block;width:20px;height:12px;background:#0f172a;border-radius:50%;"></span> | `ColorInputBg = lipgloss.Color(PrimSlate900)` |
| 18 | F02 | ColorInputNormalBorder | #334155 | <span style="display:inline-block;width:20px;height:12px;background:#334155;border-radius:50%;"></span> | Nuevo: `ColorInputNormalBorder = lipgloss.Color(PrimSlate700)` |
| 19 | F04 | ColorInputFocusBorder | #0891b2 | <span style="display:inline-block;width:20px;height:12px;background:#0891b2;border-radius:50%;"></span> | Nuevo: `ColorInputFocusBorder = lipgloss.Color(PrimCyan600)` |
| 20 | F09 | ColorInputPlaceholder | #475569 | <span style="display:inline-block;width:20px;height:12px;background:#475569;border-radius:50%;"></span> | Nuevo: `ColorInputPlaceholder = lipgloss.Color(PrimSlate600)` |
| 21 | M01 | ColorMenuItemNormalFg | #06b6d4 | <span style="display:inline-block;width:20px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Nuevo: `ColorMenuItemNormalFg = lipgloss.Color(PrimCyan500)` |
| 22 | M03 | ColorMenuItemActiveFg | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> | Nuevo: `ColorMenuItemActiveFg = lipgloss.Color(PrimCyan400)` |
| 23 | M04 | ColorMenuItemActiveBg | #164e63 | <span style="display:inline-block;width:20px;height:12px;background:#164e63;border-radius:50%;"></span> | Nuevo: `ColorMenuItemActiveBg = lipgloss.Color(PrimCyan900)` |
| 24 | M05 | ColorMenuItemActiveIndicator | #06b6d4 | <span style="display:inline-block;width:20px;height:12px;background:#06b6d4;border-radius:50%;"></span> | Nuevo: `ColorMenuItemActiveIndicator = lipgloss.Color(PrimCyan500)` |

### 13.2 theme.go:rebuildThemeComponents() — REEMPLAZOS (36)

| # | Estilo actual | → | Token §11 | Hex | Muestra |
|---|-------------|---|----------|-----|---------|
| 25 | White #f1f5f9 | → | T01 ColorTextHeading | #67e8f9 | <span style="display:inline-block;width:20px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> |
| 26 | Dim #475569 | → | T04 ColorTextMuted | #0891b2 | <span style="display:inline-block;width:20px;height:12px;background:#0891b2;border-radius:50%;"></span> |
| 27 | Muted #94a3b8 | → | T03 ColorTextSecondary | #06b6d4 | <span style="display:inline-block;width:20px;height:12px;background:#06b6d4;border-radius:50%;"></span> |
| 28 | Slate #475569 | → | T04 ColorTextMuted | #0891b2 | <span style="display:inline-block;width:20px;height:12px;background:#0891b2;border-radius:50%;"></span> |
| 29 | Inactive #475569 | → | T05 ColorTextDisabled | #0e7490 | <span style="display:inline-block;width:20px;height:12px;background:#0e7490;border-radius:50%;"></span> |
| 30 | Cyan #06b6d4 | → | A01 ColorAccent | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| 31 | AccentBold #06b6d4 | → | A04 ColorAccentText bold | #67e8f9 | <span style="display:inline-block;width:20px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> |
| 32 | TopBar fg #06b6d4 | → | T01 ColorTextHeading | #67e8f9 | <span style="display:inline-block;width:20px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> |
| 33 | TopBar bg #020617 | → | S01 ColorBgBase | #0f172a | <span style="display:inline-block;width:20px;height:12px;background:#0f172a;border-radius:50%;"></span> |
| 34 | Panel bg #0f172a | → | S02 ColorBgSurface | #1e293b | <span style="display:inline-block;width:20px;height:12px;background:#1e293b;border-radius:50%;"></span> |
| 35 | Panel fg #f1f5f9 | → | T02 ColorTextPrimary | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| 36 | Panel border #1e293b | → | B01 ColorBorder | #334155 | <span style="display:inline-block;width:20px;height:12px;background:#334155;border-radius:50%;"></span> |
| 37 | Box border #1e293b | → | B01 ColorBorder | #334155 | <span style="display:inline-block;width:20px;height:12px;background:#334155;border-radius:50%;"></span> |
| 38 | BoxActive border #06b6d4 | → | A01 ColorAccent | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| 39 | Rule #1e293b | → | B10 ColorDivider | #334155 | <span style="display:inline-block;width:20px;height:12px;background:#334155;border-radius:50%;"></span> |
| 40 | InputActive border #06b6d4 | → | F04 ColorInputFocusBorder | #0891b2 | <span style="display:inline-block;width:20px;height:12px;background:#0891b2;border-radius:50%;"></span> |
| 41 | InputInactive border #1e293b | → | F02 ColorInputNormalBorder | #334155 | <span style="display:inline-block;width:20px;height:12px;background:#334155;border-radius:50%;"></span> |
| 42 | InputActive bg #020617 | → | F01 ColorInputBg | #0f172a | <span style="display:inline-block;width:20px;height:12px;background:#0f172a;border-radius:50%;"></span> |
| 43 | InputInactive bg #020617 | → | F01 ColorInputBg | #0f172a | <span style="display:inline-block;width:20px;height:12px;background:#0f172a;border-radius:50%;"></span> |
| 44 | StepOK #06b6d4 | → | A04 ColorAccentText | #67e8f9 | <span style="display:inline-block;width:20px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> |
| 45 | StepActive #06b6d4 bold | → | T02 ColorTextPrimary bold | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| 46 | StepPending #475569 | → | T05 ColorTextDisabled | #0e7490 | <span style="display:inline-block;width:20px;height:12px;background:#0e7490;border-radius:50%;"></span> |
| 47 | ScrollTrack #475569 | → | R01 ColorScrollTrack | #1e293b | <span style="display:inline-block;width:20px;height:12px;background:#1e293b;border-radius:50%;"></span> |
| 48 | ScrollThumb #06b6d4 | → | R02 ColorScrollThumb | #475569 | <span style="display:inline-block;width:20px;height:12px;background:#475569;border-radius:50%;"></span> |
| 49 | TableHeader #f1f5f9 | → | T02 ColorTextPrimary | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| 50 | Label #475569 | → | T04 ColorTextMuted | #0891b2 | <span style="display:inline-block;width:20px;height:12px;background:#0891b2;border-radius:50%;"></span> |
| 51 | LabelActive #06b6d4 bold | → | T02 ColorTextPrimary bold | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| 52 | SectionTitle #94a3b8 | → | T03 ColorTextSecondary | #06b6d4 | <span style="display:inline-block;width:20px;height:12px;background:#06b6d4;border-radius:50%;"></span> |
| 53 | Footer bg #0f172a | → | S02 ColorBgSurface | #1e293b | <span style="display:inline-block;width:20px;height:12px;background:#1e293b;border-radius:50%;"></span> |
| 54 | Footer fg #94a3b8 | → | T03 ColorTextSecondary | #06b6d4 | <span style="display:inline-block;width:20px;height:12px;background:#06b6d4;border-radius:50%;"></span> |
| 55 | MenuItemActive fg #22d3ee | → | M03 ColorMenuItemActiveFg | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| 56 | MenuItemActive bg #164e63 | → | M04 ColorMenuItemActiveBg | #164e63 | <span style="display:inline-block;width:20px;height:12px;background:#164e63;border-radius:50%;"></span> |
| 57 | MenuItemNormal fg #94a3b8 | → | M01 ColorMenuItemNormalFg | #06b6d4 | <span style="display:inline-block;width:20px;height:12px;background:#06b6d4;border-radius:50%;"></span> |
| 58 | ListItemActive fg #22d3ee | → | M03 ColorMenuItemActiveFg | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| 59 | WizardMenuActive fg #06b6d4 | → | A01 ColorAccent | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| 60 | WizardMenuActive bg #164e63 | → | M04 ColorMenuItemActiveBg | #164e63 | <span style="display:inline-block;width:20px;height:12px;background:#164e63;border-radius:50%;"></span> |

### 13.3 Otros archivos — REEMPLAZOS (8)

| # | Archivo | Estilo | → | Token §11 | Hex | Muestra |
|---|---------|--------|---|----------|-----|---------|
| 61 | model/model.go | Spinner.Style #06b6d4 | → | A01 ColorAccent | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| 62 | model/model.go | ProgBar gradient1 #22c55e | → | P01 ColorProgressFill | #0891b2 | <span style="display:inline-block;width:20px;height:12px;background:#0891b2;border-radius:50%;"></span> |
| 63 | model/model.go | ProgBar gradient2 #06b6d4 | → | P02 ColorProgressTrack | #1e293b | <span style="display:inline-block;width:20px;height:12px;background:#1e293b;border-radius:50%;"></span> |
| 64 | styles/icons.go | IconOK green #22c55e | → | A04 ColorAccentText | #67e8f9 | <span style="display:inline-block;width:20px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> |
| 65 | styles/icons.go | IconActive green #22c55e | → | A01 ColorAccent | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| 66 | styles/huh_theme.go | Titles/Selectors #22d3ee | → | A01 ColorAccent | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| 67 | styles/huh_theme.go | FocusedButton #06b6d4 | → | A01 ColorAccent | #22d3ee | <span style="display:inline-block;width:20px;height:12px;background:#22d3ee;border-radius:50%;"></span> |
| 68 | styles/huh_theme.go | BlurredButton #475569 | → | T04 ColorTextMuted | #0891b2 | <span style="display:inline-block;width:20px;height:12px;background:#0891b2;border-radius:50%;"></span> |

### 13.4 Tokens NUEVOS (13)

| # | Código | Token a crear | Hex | Muestra |
|---|--------|-------------|-----|---------|
| 69 | A02 | ColorAccentHover | #67e8f9 | <span style="display:inline-block;width:20px;height:12px;background:#67e8f9;border-radius:50%;border:1px solid #333;"></span> |
| 70 | A03 | ColorAccentPressed | #06b6d4 | <span style="display:inline-block;width:20px;height:12px;background:#06b6d4;border-radius:50%;"></span> |
| 71 | S04 | ColorBgSurfaceHover | #1e293b | <span style="display:inline-block;width:20px;height:12px;background:#1e293b;border-radius:50%;"></span> |
| 72 | S05 | ColorBgSurfaceActive | #334155 | <span style="display:inline-block;width:20px;height:12px;background:#334155;border-radius:50%;"></span> |
| 73 | S07 | ColorBgInputDisabled | #0f172a | <span style="display:inline-block;width:20px;height:12px;background:#0f172a;border-radius:50%;"></span> |
| 74 | B02 | ColorBorderFocus | #06b6d4 | <span style="display:inline-block;width:20px;height:12px;background:#06b6d4;border-radius:50%;"></span> |
| 75 | B03 | ColorBorderHover | #475569 | <span style="display:inline-block;width:20px;height:12px;background:#475569;border-radius:50%;"></span> |
| 76 | F05 | ColorInputErrorBg | #020617 | <span style="display:inline-block;width:20px;height:12px;background:#020617;border-radius:50%;"></span> |
| 77 | F06 | ColorInputErrorBorder | #f87474 | <span style="display:inline-block;width:20px;height:12px;background:#f87474;border-radius:50%;"></span> |
| 78 | F07 | ColorInputDisabledBg | #0f172a | <span style="display:inline-block;width:20px;height:12px;background:#0f172a;border-radius:50%;"></span> |
| 79 | F08 | ColorInputDisabledBorder | #334155 | <span style="display:inline-block;width:20px;height:12px;background:#334155;border-radius:50%;"></span> |
| 80 | M02 | ColorMenuItemHoverBg | #1e293b | <span style="display:inline-block;width:20px;height:12px;background:#1e293b;border-radius:50%;"></span> |
| 81 | M06 | ColorMenuItemDisabledFg | #0e7490 | <span style="display:inline-block;width:20px;height:12px;background:#0e7490;border-radius:50%;"></span> |

---

**Total: 81 acciones. FASE 1 (24) + FASE 2 (36) + FASE 3 (8) + FASE 4 (13) = 81.**
