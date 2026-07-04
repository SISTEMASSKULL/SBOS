# Manual de Componentes TUI Profesionales en Go (Charm Stack)

Guía de referencia para construir interfaces de terminal (TUI) robustas usando `bubbletea`, `lipgloss`, `bubbles` y `huh`, con un **sistema de design tokens centralizado** (estilo Tailwind/PrimeVue), un **componente base reutilizable** con manejo de foco/blur, y un **sistema de paneles (layout manager)** para aplicaciones multi-zona.

> **Nota de versiones (2026):** Charm está en plena transición a v2 (`charm.land/bubbletea/v2`, `charm.land/bubbles/v2`, `charm.land/lipgloss/v2`). Este manual cubre **ambas rutas**: la API v1 estable (`github.com/charmbracelet/...`, usada en producción hoy) y las novedades de v2 (Styles inmutables tipo valor, compositing con `Layer`/`Canvas`, detección de fondo vía `tea.BackgroundColorMsg`, mensajes `FocusMsg`/`BlurMsg`). Si tu proyecto ya está en v2, sustituye los imports `github.com/charmbracelet/lipgloss` → `charm.land/lipgloss/v2`, etc.

---

## 1. Arquitectura general

```
┌─────────────────────────────────────────────────────────┐
│              bubbletea (runtime)                          │  Model / Update / View, eventos, ticks, focus/blur
├─────────────────────────────────────────────────────────┤
│   Focus Manager  │  Panel Manager (layout multi-zona)     │  Capa de orquestación: foco, navegación, tabs
├─────────────────────────────────────────────────────────┤
│   bubbles (componentes)  │  huh (formularios)             │  spinner, list, table, viewport, forms
├─────────────────────────────────────────────────────────┤
│             lipgloss (estilos)                             │  colores, bordes, layout, join/place, layers
├─────────────────────────────────────────────────────────┤
│   Design Tokens (theme.yaml)  →  Theme  →  Variants        │  paleta + escalas + variantes por estado, tipo PrimeVue/Tailwind
└─────────────────────────────────────────────────────────┘
```

Reglas de oro:

1. **Ningún componente define sus propios colores hardcodeados.** Todos consumen un `Theme` construido desde `theme.yaml`.
2. **Ningún componente maneja su propio foco de forma aislada.** El `FocusManager` decide quién está activo y propaga `Focus()`/`Blur()`.
3. **Ningún layout se calcula a mano con strings.** El `PanelManager` resuelve dimensiones, bordes y estados visuales (focused/blurred/disabled).

---

## 2. Sistema de Design Tokens (theme.yaml)

Esto es lo que en Tailwind serían las "design tokens" y en PrimeVue los "design tokens / presets". La idea: **3 capas**.

```
Capa 1: Paleta primitiva   →  colores crudos (azul-500, gris-900, etc.)
Capa 2: Tokens semánticos  →  primary, surface, border, text, danger...
Capa 3: Variantes de componente → estilos resueltos por estado (focused, blurred, disabled, hover/selected)
```

### 2.1 `theme.yaml` extendido

```yaml
# theme.yaml
name: "sbos-dark"
extends: "base"          # herencia opcional de un tema padre

# --- Capa 1: paleta primitiva (opcional, para reutilizar valores) ---
palette:
  blue-500:  "#3B5BDB"
  blue-300:  "#7AA2F7"
  violet-300: "#BB9AF7"
  red-500:   "#C92A2A"
  red-300:   "#F7768E"
  green-600: "#2B8A3E"
  green-300: "#9ECE6A"
  amber-600: "#E8590C"
  amber-300: "#E0AF68"
  gray-100:  "#CED4DA"
  gray-500:  "#868E96"
  gray-800:  "#3B4261"
  gray-900:  "#1A1B26"

# --- Capa 2: tokens semánticos (lo que consumen los componentes) ---
colors:
  primary:    { light: "#3B5BDB", dark: "#7AA2F7" }
  secondary:  { light: "#5C7CFA", dark: "#BB9AF7" }
  accent:     { light: "#D9480F", dark: "#FF9E64" }
  success:    { light: "#2B8A3E", dark: "#9ECE6A" }
  warning:    { light: "#E8590C", dark: "#E0AF68" }
  error:      { light: "#C92A2A", dark: "#F7768E" }
  muted:      { light: "#868E96", dark: "#565F89" }
  border:     { light: "#CED4DA", dark: "#3B4261" }
  background: { light: "#FFFFFF", dark: "#1A1B26" }
  surface:    { light: "#F8F9FA", dark: "#16161E" } # paneles, cards
  text:       { light: "#212529", dark: "#C0CAF5" }

# --- Capa 3: tokens de estado / interacción (clave para focus/blur) ---
states:
  focusBorder:   { light: "#3B5BDB", dark: "#7AA2F7" }   # borde cuando el panel tiene foco
  blurBorder:    { light: "#CED4DA", dark: "#3B4261" }   # borde sin foco (atenuado)
  disabledText:  { light: "#ADB5BD", dark: "#414868" }
  selectionBg:   { light: "#3B5BDB", dark: "#7AA2F7" }
  selectionFg:   { light: "#FFFFFF", dark: "#1A1B26" }
  hoverBg:       { light: "#E9ECEF", dark: "#292E42" }

# --- Espaciado / radios / tipografía (tokens de layout, como Tailwind spacing scale) ---
spacing:
  xs: 0
  sm: 1
  md: 2
  lg: 4

# Densidad por componente (padding interno) — ver sección 4.7 para el
# desarrollo completo (paneles "pegados" estilo tmux vs. comfortable).
density: compact   # compact | comfortable

radius:
  none: "none"      # lipgloss.NoBorder / sin borde
  sm:   "rounded"   # lipgloss.RoundedBorder
  md:   "thick"     # lipgloss.ThickBorder
  lg:   "double"    # lipgloss.DoubleBorder

typography:
  bold: true
  italic: false
```

### 2.2 Estructura Go: `Theme` + `Tokens` (capa intermedia tipo PrimeVue)

```go
package theme

import (
    "os"

    "github.com/charmbracelet/lipgloss"
    "gopkg.in/yaml.v3"
)

type ColorPair struct {
    Light string `yaml:"light"`
    Dark  string `yaml:"dark"`
}

type ThemeConfig struct {
    Name    string               `yaml:"name"`
    Extends string               `yaml:"extends"`
    Palette map[string]string    `yaml:"palette"`
    Colors  map[string]ColorPair `yaml:"colors"`
    States  map[string]ColorPair `yaml:"states"`
    Spacing map[string]int       `yaml:"spacing"`
    Radius  map[string]string    `yaml:"radius"`
}

// Theme = tokens semánticos resueltos (Capa 2 + 3)
type Theme struct {
    Name       string
    Primary    lipgloss.AdaptiveColor
    Secondary  lipgloss.AdaptiveColor
    Accent     lipgloss.AdaptiveColor
    Success    lipgloss.AdaptiveColor
    Warning    lipgloss.AdaptiveColor
    Error      lipgloss.AdaptiveColor
    Muted      lipgloss.AdaptiveColor
    Border     lipgloss.AdaptiveColor
    Background lipgloss.AdaptiveColor
    Surface    lipgloss.AdaptiveColor
    Text       lipgloss.AdaptiveColor

    // Estados (Capa 3) — clave para focus/blur/disabled
    FocusBorder  lipgloss.AdaptiveColor
    BlurBorder   lipgloss.AdaptiveColor
    DisabledText lipgloss.AdaptiveColor
    SelectionBg  lipgloss.AdaptiveColor
    SelectionFg  lipgloss.AdaptiveColor
    HoverBg      lipgloss.AdaptiveColor

    Spacing map[string]int
    Radius  map[string]lipgloss.Border
}

func radiusFromToken(name string) lipgloss.Border {
    switch name {
    case "rounded":
        return lipgloss.RoundedBorder()
    case "thick":
        return lipgloss.ThickBorder()
    case "double":
        return lipgloss.DoubleBorder()
    case "none":
        return lipgloss.HiddenBorder()
    default:
        return lipgloss.NormalBorder()
    }
}

func Load(path string) (*Theme, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }

    var cfg ThemeConfig
    if err := yaml.Unmarshal(data, &cfg); err != nil {
        return nil, err
    }

    // Soporte de herencia: si "extends" está definido, cargar el padre primero
    // y hacer merge (cfg sobreescribe al padre). Implementación simplificada:
    if cfg.Extends != "" && cfg.Extends != cfg.Name {
        parentPath := "themes/" + cfg.Extends + ".yaml"
        if parent, err := Load(parentPath); err == nil {
            return mergeTheme(parent, &cfg), nil
        }
    }

    get := func(m map[string]ColorPair, key string) lipgloss.AdaptiveColor {
        c := m[key]
        return lipgloss.AdaptiveColor{Light: c.Light, Dark: c.Dark}
    }

    radii := map[string]lipgloss.Border{}
    for k, v := range cfg.Radius {
        radii[k] = radiusFromToken(v)
    }

    return &Theme{
        Name:       cfg.Name,
        Primary:    get(cfg.Colors, "primary"),
        Secondary:  get(cfg.Colors, "secondary"),
        Accent:     get(cfg.Colors, "accent"),
        Success:    get(cfg.Colors, "success"),
        Warning:    get(cfg.Colors, "warning"),
        Error:      get(cfg.Colors, "error"),
        Muted:      get(cfg.Colors, "muted"),
        Border:     get(cfg.Colors, "border"),
        Background: get(cfg.Colors, "background"),
        Surface:    get(cfg.Colors, "surface"),
        Text:       get(cfg.Colors, "text"),

        FocusBorder:  get(cfg.States, "focusBorder"),
        BlurBorder:   get(cfg.States, "blurBorder"),
        DisabledText: get(cfg.States, "disabledText"),
        SelectionBg:  get(cfg.States, "selectionBg"),
        SelectionFg:  get(cfg.States, "selectionFg"),
        HoverBg:      get(cfg.States, "hoverBg"),

        Spacing: cfg.Spacing,
        Radius:  radii,
    }, nil
}

// mergeTheme: el hijo sobreescribe los campos no vacíos del padre.
func mergeTheme(parent *Theme, child *ThemeConfig) *Theme {
    out := *parent
    out.Name = child.Name
    // ... merge selectivo de cfg.Colors/States sobre `out` (omitido por brevedad)
    return &out
}
```

### 2.3 Derivar `Styles` con **variantes** (patrón PrimeVue: `root`, `focused`, `blurred`, `disabled`)

En PrimeVue cada componente expone "pass-through" classes por estado (`root`, `focus`, `disabled`, `invalid`...). Replicamos esto con un mapa de **variantes de estilo** por componente:

```go
package theme

import "github.com/charmbracelet/lipgloss"

// Variant agrupa los estilos de un mismo elemento en sus distintos estados,
// igual que PrimeVue separa "root" / "focus" / "disabled" / "invalid".
type Variant struct {
    Base     lipgloss.Style
    Focused  lipgloss.Style
    Blurred  lipgloss.Style
    Disabled lipgloss.Style
    Selected lipgloss.Style
    Error    lipgloss.Style
}

type Styles struct {
    Title     lipgloss.Style
    Subtitle  lipgloss.Style
    Muted     lipgloss.Style
    Success   lipgloss.Style
    Warning   lipgloss.Style
    Error     lipgloss.Style
    Base      lipgloss.Style
    Highlight lipgloss.Style

    // Variantes reutilizables por tipo de elemento visual
    Panel Variant // contenedor con borde (panel/card)
    Input Variant // textinput, select, etc.
    Item  Variant // ítem de lista/tabla (fila)
    Tab   Variant // pestaña de un TabBar
    Badge Variant // etiquetas de estado (success/warning/error)
    Button Variant // botones de acción (ver sección 5.11.1)
}

func (t Theme) Styles() Styles {
    border := t.Radius["sm"] // default: rounded

    panel := Variant{
        Base: lipgloss.NewStyle().
            Border(border).
            BorderForeground(t.BlurBorder).
            Padding(0, 1),
        Focused: lipgloss.NewStyle().
            Border(border).
            BorderForeground(t.FocusBorder).
            Padding(0, 1),
        Blurred: lipgloss.NewStyle().
            Border(border).
            BorderForeground(t.BlurBorder).
            Padding(0, 1),
        Disabled: lipgloss.NewStyle().
            Border(border).
            BorderForeground(t.Muted).
            Foreground(t.DisabledText).
            Padding(0, 1),
    }

    // input: ver corrección de fondo inconsistente (Background/BorderBackground
    // + sub-estilos de textinput.Model) en la sección 5.3.1
    input := Variant{
        Base: lipgloss.NewStyle().
            Foreground(t.Text).Background(t.Surface).
            Border(lipgloss.NormalBorder()).
            BorderForeground(t.BlurBorder).BorderBackground(t.Surface).
            Padding(0, 1),
        Focused: lipgloss.NewStyle().
            Foreground(t.Text).Background(t.Surface).
            Border(lipgloss.NormalBorder()).
            BorderForeground(t.FocusBorder).BorderBackground(t.Surface).
            Padding(0, 1),
        Blurred: lipgloss.NewStyle().
            Foreground(t.Muted).Background(t.Surface).
            Border(lipgloss.NormalBorder()).
            BorderForeground(t.BlurBorder).BorderBackground(t.Surface).
            Padding(0, 1),
        Disabled: lipgloss.NewStyle().
            Foreground(t.DisabledText).Background(t.Surface).
            Border(lipgloss.NormalBorder()).
            BorderForeground(t.Muted).BorderBackground(t.Surface).
            Padding(0, 1),
        Error: lipgloss.NewStyle().
            Foreground(t.Text).Background(t.Surface).
            Border(lipgloss.NormalBorder()).
            BorderForeground(t.Error).BorderBackground(t.Surface).
            Padding(0, 1),
    }

    item := Variant{
        Base: lipgloss.NewStyle().Foreground(t.Text).Padding(0, 1),
        Selected: lipgloss.NewStyle().
            Foreground(t.SelectionFg).
            Background(t.SelectionBg).
            Padding(0, 1),
        Disabled: lipgloss.NewStyle().Foreground(t.DisabledText).Padding(0, 1),
    }

    tab := Variant{
        Base: lipgloss.NewStyle().
            Foreground(t.Muted).
            Padding(0, 2),
        Selected: lipgloss.NewStyle().
            Foreground(t.SelectionFg).
            Background(t.Primary).
            Bold(true).
            Padding(0, 2),
        Disabled: lipgloss.NewStyle().
            Foreground(t.DisabledText).
            Padding(0, 2),
    }

    badge := Variant{
        Base:     lipgloss.NewStyle().Padding(0, 1).Foreground(t.Text).Background(t.Muted),
        Selected: lipgloss.NewStyle().Padding(0, 1).Foreground(t.SelectionFg).Background(t.Success),
        Error:    lipgloss.NewStyle().Padding(0, 1).Foreground(t.SelectionFg).Background(t.Error),
    }

    // button: ver definición completa y corrección de marcos deformes
    // (consistencia de Border/Padding entre variantes) en la sección 5.11.1,
    // y corrección de fondo inconsistente (Background/BorderBackground) en 5.11.3
    buttonBorder := lipgloss.RoundedBorder()
    button := Variant{
        Base: lipgloss.NewStyle().
            Border(buttonBorder).BorderForeground(t.BlurBorder).BorderBackground(t.Surface).
            Padding(0, 2).Foreground(t.Text).Background(t.Surface),
        Focused: lipgloss.NewStyle().
            Border(buttonBorder).BorderForeground(t.FocusBorder).BorderBackground(t.Surface).
            Padding(0, 2).Bold(true).
            Foreground(t.SelectionFg).Background(t.Primary),
        Blurred: lipgloss.NewStyle().
            Border(buttonBorder).BorderForeground(t.BlurBorder).BorderBackground(t.Surface).
            Padding(0, 2).Foreground(t.Text).Background(t.Surface),
        Disabled: lipgloss.NewStyle().
            Border(buttonBorder).BorderForeground(t.Muted).BorderBackground(t.Surface).
            Padding(0, 2).Foreground(t.DisabledText).Background(t.Surface),
        Selected: lipgloss.NewStyle(). // ej. "Danger"
            Border(buttonBorder).BorderForeground(t.Error).BorderBackground(t.Surface).
            Padding(0, 2).Foreground(t.SelectionFg).Background(t.Error),
        Error: lipgloss.NewStyle(). // ej. "Ghost" — mismo espacio, borde invisible
            Border(lipgloss.HiddenBorder()).BorderBackground(t.Surface).
            Padding(0, 2).Foreground(t.Muted).Background(t.Surface),
    }


    return Styles{
        Title:     lipgloss.NewStyle().Bold(true).Foreground(t.Primary),
        Subtitle:  lipgloss.NewStyle().Foreground(t.Secondary),
        Muted:     lipgloss.NewStyle().Foreground(t.Muted),
        Success:   lipgloss.NewStyle().Foreground(t.Success),
        Warning:   lipgloss.NewStyle().Foreground(t.Warning),
        Error:     lipgloss.NewStyle().Foreground(t.Error),
        Highlight: lipgloss.NewStyle().Foreground(t.Background).Background(t.Primary).Padding(0, 1),
        Base:      lipgloss.NewStyle().Foreground(t.Text).Background(t.Background),

        Panel:  panel,
        Input:  input,
        Item:   item,
        Tab:    tab,
        Badge:  badge,
        Button: button,
    }
}

// Helper para resolver estilo según estado booleano (focused/disabled)
func (v Variant) Resolve(focused, disabled bool) lipgloss.Style {
    switch {
    case disabled:
        return v.Disabled
    case focused:
        return v.Focused
    default:
        return v.Blurred
    }
}
```

### 2.4 Cambio de tema en runtime y detección automática de fondo (v1 y v2)

**v1 (estable):**

```go
type model struct {
    theme  *theme.Theme
    styles theme.Styles
    themes []string
    idx    int
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        if msg.String() == "ctrl+t" {
            m.idx = (m.idx + 1) % len(m.themes)
            t, _ := theme.Load("themes/" + m.themes[m.idx] + ".yaml")
            m.theme = t
            m.styles = t.Styles()
        }
    }
    return m, nil
}

func init() {
    var defaultTheme string
    if lipgloss.HasDarkBackground() {
        defaultTheme = "sbos-dark"
    } else {
        defaultTheme = "sbos-light"
    }
    _ = defaultTheme
}
```

**v2 (recomendado para nuevos proyectos):** el fondo se detecta de forma explícita y asíncrona vía mensaje, lo cual es más confiable en SSH/CI:

```go
import (
    tea "charm.land/bubbletea/v2"
    "charm.land/lipgloss/v2"
)

func (m model) Init() tea.Cmd {
    return tea.RequestBackgroundColor // pide al terminal su color de fondo
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.BackgroundColorMsg:
        // msg.IsDark() determina la variante del theme a cargar
        if msg.IsDark() {
            m.theme, _ = theme.Load("themes/sbos-dark.yaml")
        } else {
            m.theme, _ = theme.Load("themes/sbos-light.yaml")
        }
        m.styles = m.theme.Styles()
    }
    return m, nil
}
```

Como `Styles` se recalcula desde `Theme`, **todos los componentes que reciben `m.styles` se repintan automáticamente** con la nueva paleta en el siguiente `View()`.

---

## 3. Componente base + Focus/Blur (núcleo del "design system")

Esta es la pieza que faltaba para acercarte a PrimeVue/Tailwind: una **interfaz común** que todo componente implementa, y un **FocusManager** que orquesta quién recibe input.

### 3.1 Interfaz `Component`

```go
package ui

import tea "github.com/charmbracelet/bubbletea"

// Component es el contrato mínimo que cualquier widget del design system debe cumplir.
// Es una extensión de tea.Model que añade gestión explícita de foco, tamaño y habilitación.
type Component interface {
    tea.Model

    // Focus / Blur — análogo a CSS :focus / onBlur en Tailwind/PrimeVue
    Focus() tea.Cmd
    Blur()
    Focused() bool

    // Habilitar/deshabilitar — análogo a :disabled
    SetEnabled(bool)
    Enabled() bool

    // Redimensionar — análogo a w-full / responsive sizing
    SetSize(width, height int)

    // ID único para que el FocusManager y el PanelManager lo identifiquen
    ID() string
}

// BaseComponent: struct embebible que da una implementación por defecto
// de los métodos de estado, para que cada widget solo sobreescriba lo necesario.
type BaseComponent struct {
    id      string
    focused bool
    enabled bool
    width   int
    height  int
}

func NewBase(id string) BaseComponent {
    return BaseComponent{id: id, enabled: true}
}

func (b *BaseComponent) ID() string         { return b.id }
func (b *BaseComponent) Focused() bool      { return b.focused }
func (b *BaseComponent) Enabled() bool      { return b.enabled }
func (b *BaseComponent) SetEnabled(v bool)  { b.enabled = v }
func (b *BaseComponent) SetSize(w, h int)   { b.width, b.height = w, h }
func (b *BaseComponent) Size() (int, int)   { return b.width, b.height }

// Focus/Blur por defecto solo cambian el flag; los widgets que envuelven
// componentes de `bubbles` (textinput, list, etc.) deben sobreescribir
// y delegar también al sub-componente: ti.Focus(), ti.Blur(), etc.
func (b *BaseComponent) Focus() tea.Cmd { b.focused = true; return nil }
func (b *BaseComponent) Blur()          { b.focused = false }
```

### 3.2 Ejemplo: envolver `textinput.Model` como `Component`

```go
package widgets

import (
    tea "github.com/charmbracelet/bubbletea"
    "github.com/charmbracelet/bubbles/textinput"
    "yourapp/theme"
    "yourapp/ui"
)

type TextField struct {
    ui.BaseComponent
    input  textinput.Model
    styles theme.Styles
    label  string
}

func NewTextField(id, label string, s theme.Styles) *TextField {
    ti := textinput.New()
    ti.Placeholder = label
    ti.CharLimit = 64

    return &TextField{
        BaseComponent: ui.NewBase(id),
        input:         ti,
        styles:        s,
        label:         label,
    }
}

func (f *TextField) Init() tea.Cmd { return nil }

func (f *TextField) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    if !f.Focused() || !f.Enabled() {
        return f, nil
    }
    var cmd tea.Cmd
    f.input, cmd = f.input.Update(msg)
    return f, cmd
}

// Focus delega tanto al estado del Component como al sub-modelo textinput
func (f *TextField) Focus() tea.Cmd {
    f.BaseComponent.Focus()
    return f.input.Focus()
}

func (f *TextField) Blur() {
    f.BaseComponent.Blur()
    f.input.Blur()
}

func (f *TextField) SetSize(w, h int) {
    f.BaseComponent.SetSize(w, h)
    f.input.Width = w
}

func (f *TextField) View() string {
    variant := f.styles.Input.Resolve(f.Focused(), !f.Enabled())
    return variant.Render(f.input.View())
}
```

> Este patrón es exactamente lo que en PrimeVue sería un componente con `:class="{ 'p-focus': focused, 'p-disabled': disabled }"`: el estado decide qué variante de estilo se aplica, no al revés.

### 3.3 `FocusManager` — orquestación de foco entre N componentes

```go
package ui

import tea "github.com/charmbracelet/bubbletea"

// FocusManager mantiene una lista ordenada de Components y garantiza
// que solo uno tenga foco a la vez (como un grupo de tabs/inputs).
type FocusManager struct {
    components []Component
    activeIdx  int
}

func NewFocusManager(components ...Component) *FocusManager {
    fm := &FocusManager{components: components}
    if len(components) > 0 {
        fm.components[0].Focus()
    }
    return fm
}

// Active devuelve el componente actualmente enfocado.
func (fm *FocusManager) Active() Component {
    if len(fm.components) == 0 {
        return nil
    }
    return fm.components[fm.activeIdx]
}

// Next mueve el foco al siguiente componente habilitado (cíclico).
// Devuelve los tea.Cmd resultantes de Focus()/Blur() para hacer tea.Batch.
func (fm *FocusManager) Next() tea.Cmd {
    return fm.move(1)
}

func (fm *FocusManager) Prev() tea.Cmd {
    return fm.move(-1)
}

func (fm *FocusManager) move(delta int) tea.Cmd {
    if len(fm.components) == 0 {
        return nil
    }
    fm.components[fm.activeIdx].Blur()

    n := len(fm.components)
    next := fm.activeIdx
    for i := 0; i < n; i++ {
        next = (next + delta + n) % n
        if fm.components[next].Enabled() {
            break
        }
    }
    fm.activeIdx = next
    return fm.components[fm.activeIdx].Focus()
}

// FocusByID enfoca un componente específico por ID (útil para clicks de mouse
// o atajos directos como "ir al panel de logs").
func (fm *FocusManager) FocusByID(id string) tea.Cmd {
    for i, c := range fm.components {
        if c.ID() == id {
            fm.components[fm.activeIdx].Blur()
            fm.activeIdx = i
            return c.Focus()
        }
    }
    return nil
}

// Update delega el mensaje SOLO al componente activo (patrón estándar),
// pero también permite que componentes "siempre activos" (ej. spinners
// de fondo) reciban ticks — ver UpdateAll.
func (fm *FocusManager) Update(msg tea.Msg) tea.Cmd {
    active := fm.Active()
    if active == nil {
        return nil
    }
    updated, cmd := active.Update(msg)
    if c, ok := updated.(Component); ok {
        fm.components[fm.activeIdx] = c
    }
    return cmd
}

// UpdateAll propaga el mensaje a TODOS los componentes (para WindowSizeMsg,
// spinner.TickMsg, etc. que deben seguir aunque no tengan foco).
func (fm *FocusManager) UpdateAll(msg tea.Msg) []tea.Cmd {
    cmds := make([]tea.Cmd, 0, len(fm.components))
    for i, c := range fm.components {
        updated, cmd := c.Update(msg)
        if uc, ok := updated.(Component); ok {
            fm.components[i] = uc
        }
        if cmd != nil {
            cmds = append(cmds, cmd)
        }
    }
    return cmds
}
```

### 3.4 Manejo de `tea.FocusMsg` / `tea.BlurMsg` a nivel de **terminal** (ventana completa)

Distinto del foco *interno* entre widgets: bubbletea también reporta cuando la **ventana del terminal** pierde el foco del sistema operativo (útil para pausar animaciones/spinners costosos).

```go
// Habilitar el reporte de foco de terminal:
p := tea.NewProgram(model{}, tea.WithReportFocus())

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.FocusMsg:
        m.terminalFocused = true
        // reanudar animaciones, spinners, polling
    case tea.BlurMsg:
        m.terminalFocused = false
        // pausar spinner.Tick, reducir polling, etc.
    }
    return m, nil
}
```

> Nota: requiere terminal/multiplexor compatible (tmux necesita `set -g focus-events on`).

---

---

## 4. `PanelManager` — layout multi-zona con foco visual

Esto resuelve "necesito manejar paneles, focus/lost focus, backgrounds" de forma declarativa, similar a un grid de Tailwind o un `<Splitter>`/`<TabView>` de PrimeVue.

### 4.1 Definición de un `Panel`

```go
package ui

import (
    "github.com/charmbracelet/lipgloss"
    "yourapp/theme"
)

// Panel envuelve un Component con metadatos de layout.
type Panel struct {
    Component Component
    Title     string

    // Layout: igual que flex-basis / grid-template en CSS
    FlexRatio float64 // proporción de espacio (0.0–1.0) dentro de su fila/columna
    MinWidth  int
    MinHeight int
}

// PanelManager organiza N paneles en un grid simple (filas de paneles)
// y delega el foco al FocusManager interno.
type PanelManager struct {
    rows   [][]Panel
    focus  *FocusManager
    styles theme.Styles
    width  int
    height int
}

func NewPanelManager(s theme.Styles, rows [][]Panel) *PanelManager {
    var components []Component
    for _, row := range rows {
        for _, p := range row {
            components = append(components, p.Component)
        }
    }
    return &PanelManager{
        rows:   rows,
        focus:  NewFocusManager(components...),
        styles: s,
    }
}

func (pm *PanelManager) SetSize(width, height int) {
    pm.width, pm.height = width, height

    rowHeight := height / len(pm.rows)
    for _, row := range pm.rows {
        x := 0
        for i := range row {
            w := int(float64(width) * row[i].FlexRatio)
            if w < row[i].MinWidth {
                w = row[i].MinWidth
            }
            row[i].Component.SetSize(w-2, rowHeight-2) // -2 por bordes
            x += w
        }
    }
}

// View renderiza cada panel con su variante (Focused/Blurred) según
// si su Component tiene el foco actual.
func (pm *PanelManager) View() string {
    var rendered []string
    for _, row := range pm.rows {
        var cols []string
        for _, p := range row {
            variant := pm.styles.Panel.Resolve(p.Component.Focused(), !p.Component.Enabled())
            title := pm.styles.Title.Render(p.Title)
            body := title + "\n" + p.Component.View()
            cols = append(cols, variant.Render(body))
        }
        rendered = append(rendered, lipgloss.JoinHorizontal(lipgloss.Top, cols...))
    }
    return lipgloss.JoinVertical(lipgloss.Left, rendered...)
}

// Update: tab/shift+tab navegan entre paneles; el resto va al panel activo.
func (pm *PanelManager) Update(msg tea.Msg) tea.Cmd {
    if km, ok := msg.(tea.KeyMsg); ok {
        switch km.String() {
        case "tab":
            return pm.focus.Next()
        case "shift+tab":
            return pm.focus.Prev()
        }
    }
    return pm.focus.Update(msg)
}
```

### 4.2 Ejemplo de uso: layout de 3 paneles (sidebar + main + logs)

```go
func buildLayout(s theme.Styles) *ui.PanelManager {
    sidebar := widgets.NewListPanel("sidebar", s, items)
    main := widgets.NewTablePanel("main", s, columns, rows)
    logs := widgets.NewLogPanel("logs", s)

    return ui.NewPanelManager(s, [][]ui.Panel{
        {
            {Component: sidebar, Title: "Navegación", FlexRatio: 0.25, MinWidth: 20},
            {Component: main, Title: "Servicios", FlexRatio: 0.75},
        },
        {
            {Component: logs, Title: "Logs", FlexRatio: 1.0},
        },
    })
}
```

Esto da, visualmente, un layout tipo:

```
┌─ Navegación ─────┐┌─ Servicios ──────────────────────┐
│ ➜ Item 1         ││ bos-daemon   running   2.3       │
│   Item 2         ││ kong-gateway running   5.1       │
│   Item 3         ││ rust-svc     stopped   0.0       │
└──────────────────┘└────────────────────────────────────┘
┌─ Logs ──────────────────────────────────────────────────┐
│ [12:03:01] INFO  servicio iniciado                       │
└───────────────────────────────────────────────────────────┘
```

Con `tab`/`shift+tab` el borde del panel activo cambia a `t.FocusBorder` y los demás a `t.BlurBorder` — el equivalente exacto de `:focus-within` en CSS.

### 4.3 Backgrounds dinámicos por panel (estado)

Para que un panel cambie de "background" según estado lógico (ej. error, cargando, éxito) — como las variantes de color de un `<Card>` en PrimeVue (`severity="danger"`):

```go
// PanelStatus representa el estado semántico de un panel.
type PanelStatus int

const (
    StatusNormal PanelStatus = iota
    StatusLoading
    StatusSuccess
    StatusWarning
    StatusError
)

// StyleFor devuelve el estilo de fondo/borde correspondiente al estado,
// combinando con el estado de foco.
func StyleFor(s theme.Styles, t theme.Theme, status PanelStatus, focused bool) lipgloss.Style {
    base := s.Panel.Resolve(focused, false)
    switch status {
    case StatusError:
        return base.BorderForeground(t.Error)
    case StatusWarning:
        return base.BorderForeground(t.Warning)
    case StatusSuccess:
        return base.BorderForeground(t.Success)
    case StatusLoading:
        return base.BorderForeground(t.Secondary)
    default:
        return base
    }
}
```

---

### 4.4 Layout responsive con grid de filas/columnas y matemática de bordes

`PanelManager.SetSize` (4.1) reparte el espacio por filas con `FlexRatio`, pero para layouts más generales — **fila superior con N paneles + fila inferior de ancho completo**, headers fijos, paneles con tamaño fijo en líneas, etc. — conviene una versión extendida de `resize()` que separa explícitamente: *(a)* el "presupuesto" de alto/ancho disponible, *(b)* la resta del borde por panel, y *(c)* el reparto proporcional vs. fijo.

#### 4.4.1 Estructura del layout

```
┌─────────────────────────────────────────────┐
│  Panel A (arriba-izq)  │  Panel B (arriba-der) │  ← topRow: 65% del alto
│                         │                       │
├─────────────────────────────────────────────┤
│              Panel C (abajo, ancho completo)   │  ← bottomRow: resto
│                                                 │
└─────────────────────────────────────────────┘
```

#### 4.4.2 Regla de oro: el borde se resta una sola vez, en el lugar correcto

Cada panel con `lipgloss.RoundedBorder()` (o cualquier borde no-`Hidden`/`NoBorder`) agrega **2 columnas y 2 filas** al tamaño final renderizado (1 por lado). Esto da dos tamaños distintos que NO deben confundirse:

- **Tamaño externo** (`outerWidth`/`outerHeight`): lo que ocupa la caja completa, incluido el borde. Es lo que se pasa a `.Width()`/`.Height()` del `lipgloss.Style` del panel, y lo que se usa para sumar/repartir el espacio del grid.
- **Tamaño interno** (`innerWidth`/`innerHeight` = `outer - borderSize`): el espacio real disponible para el contenido (`viewport`, `table`, `list`, etc.). Es lo que se pasa a `SetSize()` del componente interno.

```go
const borderSize = 2 // 1 columna/fila por lado (top+bottom o left+right)

// PanelDims encapsula ambos tamaños para evitar mezclarlos por error.
type PanelDims struct {
    OuterWidth, OuterHeight int // incluye borde — para el lipgloss.Style del panel
    InnerWidth, InnerHeight int // sin borde — para el componente interno (viewport, table...)
}

func NewPanelDims(outerW, outerH int) PanelDims {
    return PanelDims{
        OuterWidth: outerW, OuterHeight: outerH,
        InnerWidth:  max(0, outerW-borderSize),
        InnerHeight: max(0, outerH-borderSize),
    }
}
```

#### 4.4.3 `GridLayout` — fila superior (N columnas) + fila inferior (ancho completo)

```go
package ui

import tea "github.com/charmbracelet/bubbletea"

// GridLayout describe un layout de 2 filas: la superior con columnas
// proporcionales (topRatios) y la inferior de ancho completo.
// headerHeight permite reservar una franja fija arriba de todo
// (p.ej. el título "DevInstaller").
type GridLayout struct {
    HeaderHeight int     // 0 si no hay header
    TopRowRatio  float64 // % del alto del body para la fila superior (0.0–1.0)
    TopRatios    []float64 // proporciones de ancho dentro de la fila superior, deben sumar 1.0

    // Alternativa a TopRowRatio: alto fijo para la fila inferior (ej. logs = 8 líneas)
    BottomFixedHeight int // si > 0, tiene prioridad sobre TopRowRatio
}

// Resize calcula los PanelDims de cada celda dados el ancho/alto totales
// de la terminal (tea.WindowSizeMsg.Width/Height).
func (gl GridLayout) Resize(totalW, totalH int) (top []PanelDims, bottom PanelDims) {
    bodyHeight := totalH - gl.HeaderHeight

    var topHeight, bottomHeight int
    if gl.BottomFixedHeight > 0 {
        bottomHeight = gl.BottomFixedHeight
        topHeight = bodyHeight - bottomHeight
    } else {
        topHeight = int(float64(bodyHeight) * gl.TopRowRatio)
        bottomHeight = bodyHeight - topHeight
    }

    // --- Reparto de ancho en la fila superior ---
    top = make([]PanelDims, len(gl.TopRatios))
    used := 0
    for i, ratio := range gl.TopRatios {
        var w int
        if i == len(gl.TopRatios)-1 {
            // El ÚLTIMO panel se lleva el resto exacto — evita perder
            // columnas por redondeo cuando totalW es impar.
            w = totalW - used
        } else {
            w = int(float64(totalW) * ratio)
            used += w
        }
        top[i] = NewPanelDims(w, topHeight)
    }

    bottom = NewPanelDims(totalW, bottomHeight)
    return top, bottom
}
```

#### 4.4.4 Integración en el modelo principal

```go
type model struct {
    width, height int
    styles         theme.Styles
    layout         ui.GridLayout

    panelA, panelB, panelC ui.Component // p.ej. viewport/table envueltos en ui.Component
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        m.width, m.height = msg.Width, msg.Height

        top, bottom := m.layout.Resize(m.width, m.height)

        m.panelA.SetSize(top[0].InnerWidth, top[0].InnerHeight)
        m.panelB.SetSize(top[1].InnerWidth, top[1].InnerHeight)
        m.panelC.SetSize(bottom.InnerWidth, bottom.InnerHeight)

        // guardar también los OuterWidth/Height para View() (sección 4.4.5)
        m.dimsA, m.dimsB, m.dimsC = top[0], top[1], bottom
    }
    return m, nil
}
```

```go
// Configuración equivalente al ejemplo original (65% arriba / 35% abajo, 2 columnas):
layout := ui.GridLayout{
    HeaderHeight: 3,                 // título "DevInstaller" con borde
    TopRowRatio:  0.65,
    TopRatios:    []float64{0.5, 0.5},
}

// Variante: panel inferior fijo en 8 líneas para logs
layoutFixedLogs := ui.GridLayout{
    HeaderHeight:      3,
    TopRatios:         []float64{0.3, 0.7},
    BottomFixedHeight: 8,
}
```

#### 4.4.5 `View()` — usar `OuterWidth/OuterHeight` en el estilo, `InnerWidth/InnerHeight` en el componente

```go
func (m model) View() string {
    s := m.styles

    renderPanel := func(c ui.Component, dims ui.PanelDims, title string) string {
        variant := s.Panel.Resolve(c.Focused(), !c.Enabled())
        body := s.Title.Render(title) + "\n" + c.View()
        return variant.
            Width(dims.OuterWidth - borderSize*0). // ancho EXTERNO total
            Height(dims.OuterHeight).
            Render(body)
    }

    topRow := lipgloss.JoinHorizontal(lipgloss.Top,
        renderPanel(m.panelA, m.dimsA, "Panel A"),
        renderPanel(m.panelB, m.dimsB, "Panel B"),
    )
    bottomRow := renderPanel(m.panelC, m.dimsC, "Panel C")

    header := s.Title.Render("DevInstaller")

    return lipgloss.JoinVertical(lipgloss.Left, header, topRow, bottomRow)
}
```

> **Nota sobre `Width()`/`Height()` del estilo vs. del borde:** en lipgloss, `Style.Width(n)`/`Height(n)` definen el tamaño del **área de contenido**, y el borde se dibuja *adicionalmente* alrededor — por lo tanto el tamaño final renderizado es `n + borderSize`. Si en tu grid `OuterWidth` ya representa el tamaño final deseado (con borde incluido), debes pasar `OuterWidth - borderSize` a `.Width()`. Ajusta `renderPanel` según cuál de las dos convenciones uses consistentemente en todo el layout — el punto crítico es **no mezclarlas**.

---

### 4.5 Window Manager — paneles con título, foco y eventos de ventana (close, move, resize, maximize, minimize)

Para acercarse a un "gestor de ventanas" dentro de la TUI (estilo paneles flotantes de `tmux`/`i3` o `<Dialog>` arrastrable de PrimeVue), se extiende `FloatingPanel` (sección 5.16) con una barra de título interactiva y comandos de ventana, usando `lipgloss.Layer`/`Canvas` (v2) para el compositing.

#### 4.5.1 Modelo de una `Window`

```go
package ui

import (
    "charm.land/lipgloss/v2"
    tea "charm.land/bubbletea/v2"
    "yourapp/theme"
)

// WindowState representa el estado de presentación de una ventana flotante.
type WindowState int

const (
    WindowNormal WindowState = iota
    WindowMaximized
    WindowMinimized
)

// Window es un panel flotante completo: título, posición, tamaño,
// estado (normal/maximized/minimized) y el Component que renderiza.
type Window struct {
    BaseComponent
    Title    string
    Content  Component

    X, Y          int // posición top-left dentro del canvas
    Width, Height int // tamaño en estado Normal (se preserva al maximizar/restaurar)

    state  WindowState
    styles theme.Styles

    // Snapshot del tamaño/posición previos a Maximize(), para Restore()
    prevX, prevY, prevW, prevH int
}

func NewWindow(id, title string, content Component, x, y, w, h int, s theme.Styles) *Window {
    return &Window{
        BaseComponent: NewBase(id),
        Title:         title,
        Content:       content,
        X: x, Y: y, Width: w, Height: h,
        styles: s,
    }
}
```

#### 4.5.2 Barra de título con botones de ventana (estilo `[ ─ ][ □ ][ x ]`)

```go
// TitleBar renderiza "Título ... [_][□][x]" con el ancho de la ventana.
// Los botones usan la variante Button (5.11.1/5.11.2) — cursor inyectado
// dentro del contenido, mismo borde/padding entre estados.
func (w *Window) renderTitleBar(focused bool) string {
    s := w.styles

    titleStyle := s.Subtitle
    if focused {
        titleStyle = s.Title
    }

    minimizeBtn := "_"
    maximizeBtn := "□"
    if w.state == WindowMaximized {
        maximizeBtn = "❐" // ícono "restaurar"
    }
    closeBtn := "x"

    buttons := s.Muted.Render("[" + minimizeBtn + "][" + maximizeBtn + "][" + closeBtn + "]")

    title := titleStyle.Render(" " + w.Title + " ")

    gap := w.Width - lipgloss.Width(title) - lipgloss.Width(buttons) - 2 // -2 por bordes laterales
    if gap < 0 {
        gap = 0
    }

    return title + lipgloss.NewStyle().Width(gap).Render("") + buttons
}
```

```
┌─ Servicios ──────────────────────── [_][□][x] ─┐
│ bos-daemon   running   2.3                       │
│ kong-gateway running   5.1                       │
└───────────────────────────────────────────────────┘
```

#### 4.5.3 Eventos de ventana: `Close`, `Move`, `Resize`, `Maximize`, `Minimize`, `Restore`

```go
// WindowEvent es el conjunto de acciones que el WindowManager puede aplicar
// a una Window — análogo a los eventos de un <Dialog> de PrimeVue
// (@close, @maximize, @dragend, @resizeend).
type WindowEvent int

const (
    EventClose WindowEvent = iota
    EventMaximize
    EventMinimize
    EventRestore
    EventMoveStart
    EventResizeStart
)

// ClosedMsg se emite cuando una ventana se cierra, para que el
// WindowManager la remueva de la lista (y devuelva el foco a la anterior).
type ClosedMsg struct{ ID string }

// Move desplaza la ventana dentro de los límites del canvas.
func (w *Window) Move(dx, dy, canvasW, canvasH int) {
    if w.state != WindowNormal {
        return // no se mueve maximizada/minimizada
    }
    w.X = clamp(w.X+dx, 0, canvasW-w.Width)
    w.Y = clamp(w.Y+dy, 0, canvasH-w.Height)
}

// Resize cambia el tamaño respetando un mínimo y los límites del canvas.
func (w *Window) Resize(dw, dh, canvasW, canvasH int, minW, minH int) {
    if w.state != WindowNormal {
        return
    }
    w.Width = clamp(w.Width+dw, minW, canvasW-w.X)
    w.Height = clamp(w.Height+dh, minH, canvasH-w.Y)
    w.Content.SetSize(w.Width-2, w.Height-3) // -2 borde, -1 línea extra para titlebar
}

// Maximize guarda el estado actual y expande la ventana a todo el canvas.
func (w *Window) Maximize(canvasW, canvasH int) {
    if w.state == WindowMaximized {
        return
    }
    w.prevX, w.prevY, w.prevW, w.prevH = w.X, w.Y, w.Width, w.Height
    w.X, w.Y = 0, 0
    w.Width, w.Height = canvasW, canvasH
    w.state = WindowMaximized
    w.Content.SetSize(w.Width-2, w.Height-3)
}

// Restore regresa al tamaño/posición previos a Maximize().
func (w *Window) Restore() {
    if w.state != WindowMaximized {
        return
    }
    w.X, w.Y, w.Width, w.Height = w.prevX, w.prevY, w.prevW, w.prevH
    w.state = WindowNormal
    w.Content.SetSize(w.Width-2, w.Height-3)
}

// Minimize oculta la ventana del canvas (sigue viva en el WindowManager,
// se muestra como "pestaña" en una barra de tareas — sección 4.5.5).
func (w *Window) Minimize() {
    w.prevX, w.prevY, w.prevW, w.prevH = w.X, w.Y, w.Width, w.Height
    w.state = WindowMinimized
    w.Blur()
}

func clamp(v, lo, hi int) int {
    if hi < lo {
        hi = lo
    }
    if v < lo {
        return lo
    }
    if v > hi {
        return hi
    }
    return v
}
```

#### 4.5.4 `WindowManager` — orquesta foco, z-order, drag/resize con teclado y eventos de cierre

```go
package ui

import (
    tea "charm.land/bubbletea/v2"
    "charm.land/lipgloss/v2"
    "yourapp/theme"
)

// dragMode indica si la ventana activa está en modo "mover" o "redimensionar"
// (activado/desactivado con atajos, p.ej. ctrl+m / ctrl+r).
type dragMode int

const (
    dragNone dragMode = iota
    dragMove
    dragResize
)

type WindowManager struct {
    windows []*Window
    active  int // índice de la ventana con foco (z-order: la última = top)
    drag    dragMode
    canvasW, canvasH int
    styles  theme.Styles
}

func NewWindowManager(s theme.Styles) *WindowManager {
    return &WindowManager{styles: s, active: -1}
}

// Open agrega una ventana, le da el foco y la trae al frente (z-order).
func (wm *WindowManager) Open(w *Window) tea.Cmd {
    wm.windows = append(wm.windows, w)
    wm.focusIndex(len(wm.windows) - 1)
    return w.Content.Focus()
}

// Close cierra la ventana activa y emite ClosedMsg para que el modelo
// principal reaccione (p.ej. liberar recursos asociados).
func (wm *WindowManager) Close() tea.Cmd {
    if wm.active < 0 {
        return nil
    }
    closed := wm.windows[wm.active]
    closed.Content.Blur()
    wm.windows = append(wm.windows[:wm.active], wm.windows[wm.active+1:]...)

    if len(wm.windows) > 0 {
        wm.focusIndex(len(wm.windows) - 1) // foco a la siguiente ventana en z-order
    } else {
        wm.active = -1
    }
    return func() tea.Msg { return ClosedMsg{ID: closed.ID()} }
}

// focusIndex mueve la ventana al final de la lista (top del z-order) y
// le asigna el foco, quitándoselo a la anterior.
func (wm *WindowManager) focusIndex(i int) {
    if wm.active >= 0 && wm.active < len(wm.windows) {
        wm.windows[wm.active].Content.Blur()
        wm.windows[wm.active].Blur()
    }
    w := wm.windows[i]
    wm.windows = append(append(wm.windows[:i], wm.windows[i+1:]...), w)
    wm.active = len(wm.windows) - 1
    wm.windows[wm.active].Focus()
    wm.windows[wm.active].Content.Focus()
}

// CycleFocus pasa el foco a la siguiente ventana visible (alt+tab).
func (wm *WindowManager) CycleFocus() {
    visible := wm.visibleIndices()
    if len(visible) < 2 {
        return
    }
    // siguiente visible después de wm.active, cíclico
    for i, idx := range visible {
        if idx == wm.active {
            next := visible[(i+1)%len(visible)]
            wm.focusIndex(next)
            return
        }
    }
}

func (wm *WindowManager) visibleIndices() []int {
    var out []int
    for i, w := range wm.windows {
        if w.state != WindowMinimized {
            out = append(out, i)
        }
    }
    return out
}

func (wm *WindowManager) SetCanvasSize(w, h int) {
    wm.canvasW, wm.canvasH = w, h
    for _, win := range wm.windows {
        if win.state == WindowMaximized {
            win.Maximize(w, h) // re-expandir si la terminal cambió de tamaño
        }
    }
}

// Update maneja: alt+tab (cambiar ventana activa), atajos de ventana
// (ctrl+w cerrar, ctrl+m maximizar/restaurar, ctrl+n minimizar),
// modo drag/resize con flechas, y delega el resto al contenido activo.
func (wm *WindowManager) Update(msg tea.Msg) tea.Cmd {
    active := wm.activeWindow()

    if km, ok := msg.(tea.KeyMsg); ok {
        switch km.String() {
        case "alt+tab":
            wm.CycleFocus()
            return nil
        case "ctrl+w":
            return wm.Close()
        case "ctrl+m":
            if active == nil {
                return nil
            }
            if active.state == WindowMaximized {
                active.Restore()
            } else {
                active.Maximize(wm.canvasW, wm.canvasH)
            }
            return nil
        case "ctrl+n":
            if active != nil {
                active.Minimize()
                wm.CycleFocus()
            }
            return nil
        case "ctrl+g": // toggle modo "mover"
            wm.toggleDrag(dragMove)
            return nil
        case "ctrl+r": // toggle modo "redimensionar"
            wm.toggleDrag(dragResize)
            return nil
        }

        // Si está en modo drag/resize, las flechas mueven/redimensionan
        // en vez de ir al contenido.
        if active != nil && wm.drag != dragNone {
            switch km.String() {
            case "up":
                wm.applyDrag(active, 0, -1)
            case "down":
                wm.applyDrag(active, 0, 1)
            case "left":
                wm.applyDrag(active, -1, 0)
            case "right":
                wm.applyDrag(active, 1, 0)
            case "esc":
                wm.drag = dragNone
            }
            return nil
        }
    }

    if active == nil {
        return nil
    }
    updated, cmd := active.Content.Update(msg)
    if c, ok := updated.(Component); ok {
        active.Content = c
    }
    return cmd
}

func (wm *WindowManager) toggleDrag(mode dragMode) {
    if wm.drag == mode {
        wm.drag = dragNone
    } else {
        wm.drag = mode
    }
}

func (wm *WindowManager) applyDrag(w *Window, dx, dy int) {
    switch wm.drag {
    case dragMove:
        w.Move(dx, dy, wm.canvasW, wm.canvasH)
    case dragResize:
        w.Resize(dx, dy, wm.canvasW, wm.canvasH, 10, 4)
    }
}

func (wm *WindowManager) activeWindow() *Window {
    if wm.active < 0 || wm.active >= len(wm.windows) {
        return nil
    }
    return wm.windows[wm.active]
}
```

#### 4.5.5 Render del `WindowManager` con `Layer`/`Canvas` y barra de tareas (minimizadas)

```go
// Render compone el fondo, todas las ventanas visibles (z-order = orden
// de la lista, la última pintada queda arriba), y una barra de tareas
// con las ventanas minimizadas.
func (wm *WindowManager) Render(background string) string {
    layers := []*lipgloss.Layer{lipgloss.NewLayer(background)}

    for i, w := range wm.windows {
        if w.state == WindowMinimized {
            continue
        }

        focused := i == wm.active
        variant := wm.styles.Panel.Resolve(focused, false)

        if focused && wm.drag != dragNone {
            // feedback visual: borde de acento mientras se mueve/redimensiona
            variant = variant.BorderForeground(wm.styles.Title.GetForeground())
        }

        body := w.renderTitleBar(focused) + "\n" + w.Content.View()
        box := variant.
            Width(w.Width - 2).
            Height(w.Height - 1).
            Render(body)

        layers = append(layers, lipgloss.NewLayer(box).X(w.X).Y(w.Y).Z(i+1))
    }

    if taskbar := wm.renderTaskbar(); taskbar != "" {
        layers = append(layers,
            lipgloss.NewLayer(taskbar).X(0).Y(wm.canvasH-1).Z(len(wm.windows)+1))
    }

    canvas := lipgloss.NewCanvas(layers...)
    return canvas.Render()
}

// renderTaskbar muestra una "pestaña" por cada ventana minimizada.
// Útil para reabrirlas (ctrl+1..9, o click si hay soporte de mouse).
func (wm *WindowManager) renderTaskbar() string {
    var tabs []string
    for _, w := range wm.windows {
        if w.state == WindowMinimized {
            tabs = append(tabs, wm.styles.Tab.Base.Render(w.Title))
        }
    }
    if len(tabs) == 0 {
        return ""
    }
    return wm.styles.Panel.Base.
        Width(wm.canvasW - 2).
        Render(lipgloss.JoinHorizontal(lipgloss.Top, tabs...))
}
```

#### 4.5.6 Uso en el modelo principal

```go
type model struct {
    wm     *ui.WindowManager
    width, height int
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        m.width, m.height = msg.Width, msg.Height
        m.wm.SetCanvasSize(m.width, m.height)

    case ui.ClosedMsg:
        // p.ej. liberar un proceso/stream asociado a esa ventana
        log.Printf("ventana cerrada: %s", msg.ID)

    default:
        cmd := m.wm.Update(msg)
        return m, cmd
    }
    return m, nil
}

func (m model) View() string {
    background := m.styles.Base.
        Width(m.width).Height(m.height).
        Render("") // fondo vacío, o el layout base de la sección 4.4

    return m.wm.Render(background)
}
```

#### 4.5.7 Vista de referencia

```
┌─ Servicios ──────────────────────── [_][□][x] ─┐
│ bos-daemon   running   2.3                       │
│ kong-gateway running   5.1                       │
│ rust-svc     stopped   0.0                       │
└───────────────────────────────────────────────────┘
        ┌─ Logs ────────────── [_][❐][x] ─┐
        │ [12:03:04] INFO reintentando...   │
        │                                    │
        └──────────────────────────────────────┘

[ Config ]   ← barra de tareas: "Config" está minimizada
```

`ctrl+m` sobre "Logs" lo expande a `WindowMaximized` (todo el canvas, botón `[❐]` para restaurar). `ctrl+n` sobre "Servicios" lo envía a la barra de tareas inferior. `alt+tab` cicla el foco entre "Servicios" y "Logs" (las visibles), repintando los bordes con `FocusBorder`/`BlurBorder` según corresponda.

#### 4.5.8 Mapeo de eventos: PrimeVue/Tailwind ↔ `WindowManager`

| Evento PrimeVue `<Dialog>` | Equivalente en `WindowManager` |
|---|---|
| `@close` / `closable` | `ctrl+w` → `WindowManager.Close()` → emite `ClosedMsg` |
| `@maximize` (prop `maximizable`) | `ctrl+m` → `Window.Maximize()` / `Restore()` |
| minimizar (no nativo en PrimeVue, común en gestores de ventanas) | `ctrl+n` → `Window.Minimize()` + barra de tareas (4.5.5) |
| `@dragend` (mover) | `ctrl+g` activa modo drag, flechas mueven, `esc` confirma |
| `@resizeend` | `ctrl+r` activa modo resize, flechas redimensionan, `esc` confirma |
| `z-index` / orden de apilado | orden de `wm.windows` (la última = arriba); `focusIndex` la trae al frente |
| `:focus-within` | `Window.Focused()` resuelto vía `wm.active`, variante `Panel.Focused`/`Blurred` |

---

### 4.6 Combinando `GridLayout` (4.4) y `WindowManager` (4.5)

Patrón recomendado para una app robusta: el **layout base** (grid fijo de 4.4) ocupa todo el canvas como "escritorio", y el **WindowManager** (4.5) flota encima para diálogos, paneles desacoplables o vistas secundarias — exactamente como un entorno de escritorio con paneles anclados + ventanas flotantes.

```go
func (m model) View() string {
    // 1. Layout base (grid fijo): sidebar + main + logs (sección 4.4)
    desktop := renderGridLayout(m)

    // 2. Ventanas flotantes encima (modales, paneles desacoplados)
    return m.wm.Render(desktop)
}
```

Esto da control total: paneles anclados que se redimensionan automáticamente con `tea.WindowSizeMsg` (4.4), y ventanas flotantes con ciclo de vida completo — abrir, mover, redimensionar, maximizar, minimizar, cerrar — gestionadas con `lipgloss.Layer`/`Canvas` (4.5).

---

### 4.7 Densidad configurable: paneles "pegados al contenido" estilo tmux

Por defecto, `Padding(0, 2)` + `Border()` en cada panel genera mucho espacio "desperdiciado" entre el contenido y el marco — comparado con tmux, donde los splits casi no tienen margen y el borde está pegado al contenido. Esta sección agrega un **token de densidad** al theme para controlar esto globalmente, y un patrón de **bordes compartidos** para eliminar la duplicación de columnas entre paneles adyacentes.

#### 4.7.1 Causas del "padding gigante"

1. **Padding + Border se acumulan**: `Border()` ya agrega 1 columna/fila por lado; si además pones `Padding(0,2)`, el total son 3 columnas de espacio antes de llegar al texto, por lado.
2. **Doble padding**: el panel contenedor tiene `Padding`, y el componente interno (`viewport.Style`, `textinput`) también tiene su propio padding — se suman sin que se note a simple vista.
3. **Bordes no compartidos**: con `JoinHorizontal`, cada panel dibuja sus 4 bordes completos. Dos paneles vecinos producen `...│ │...` (2 columnas) donde tmux usa 1.
4. **Altura mínima de 3 líneas** por `Border()`, aunque el contenido sea 1 línea.

#### 4.7.2 Token de densidad en `theme.yaml`

Agregar una capa de "densidad" (`compact`/`comfortable`) a los tokens de espaciado (sección 2.1), análogo a las variantes `dense`/`compact` de Material/PrimeVue:

```yaml
# theme.yaml
density: compact   # compact | comfortable

spacing:
  # padding interno de paneles/inputs, según densidad
  compact:
    panelPadding: [0, 0]   # [vertical, horizontal] — pegado al borde
    inputPadding: [0, 1]
    buttonPadding: [0, 1]
  comfortable:
    panelPadding: [0, 1]
    inputPadding: [0, 1]
    buttonPadding: [0, 2]
```

```go
type SpacingSet struct {
    PanelPadding  [2]int `yaml:"panelPadding"`
    InputPadding  [2]int `yaml:"inputPadding"`
    ButtonPadding [2]int `yaml:"buttonPadding"`
}

type ThemeConfig struct {
    // ... campos existentes
    Density string                 `yaml:"density"`
    SpacingSets map[string]SpacingSet `yaml:"spacing"`
}

type Theme struct {
    // ... campos existentes
    Density SpacingSet // resuelto según ThemeConfig.Density
}
```

```go
func Load(path string) (*Theme, error) {
    // ... parseo existente
    density := cfg.SpacingSets[cfg.Density]
    if density == (SpacingSet{}) {
        density = cfg.SpacingSets["comfortable"] // fallback
    }
    // ... 
    return &Theme{
        // ...
        Density: density,
    }, nil
}
```

#### 4.7.3 Aplicar la densidad en `Styles()` — paneles pegados al contenido

```go
func (t Theme) Styles() Styles {
    border := lipgloss.RoundedBorder()
    pp := t.Density.PanelPadding  // p.ej. [0,0] en modo compact
    ip := t.Density.InputPadding
    bp := t.Density.ButtonPadding

    panel := Variant{
        Base: lipgloss.NewStyle().
            Border(border).
            BorderForeground(t.BlurBorder).
            Padding(pp[0], pp[1]), // ← configurable, NO hardcodeado a (0,1) o (0,2)
        Focused: lipgloss.NewStyle().
            Border(border).
            BorderForeground(t.FocusBorder).
            Padding(pp[0], pp[1]),
        Blurred: lipgloss.NewStyle().
            Border(border).
            BorderForeground(t.BlurBorder).
            Padding(pp[0], pp[1]),
        Disabled: lipgloss.NewStyle().
            Border(border).
            BorderForeground(t.Muted).
            Foreground(t.DisabledText).
            Padding(pp[0], pp[1]),
    }

    input := Variant{
        Blurred: lipgloss.NewStyle().
            Foreground(t.Muted).
            Border(lipgloss.NormalBorder()).
            BorderForeground(t.BlurBorder).
            Padding(ip[0], ip[1]),
        // ... resto igual, usando ip
    }

    button := Variant{
        Blurred: lipgloss.NewStyle().
            Border(border).BorderForeground(t.BlurBorder).
            Padding(bp[0], bp[1]),
        // ... resto igual, usando bp (sección 5.11.1: TODAS las variantes
        // de Button comparten el mismo bp, incluida Error/Ghost con HiddenBorder)
    }

    // ... resto de Styles()
}
```

Con `density: compact` y `panelPadding: [0, 0]`, el contenido queda **a 1 columna del borde** (la mínima separación visual posible con `Border()` activo) — sin el "hueco" de 2-3 columnas que da `Padding(0,2)`.

#### 4.7.4 Bordes compartidos entre paneles adyacentes (estilo tmux real)

Para eliminar por completo la duplicación de columnas de borde entre paneles vecinos, usar `BorderRight(false)`/`BorderLeft(false)`/`BorderBottom(false)`/`BorderTop(false)` de lipgloss, de modo que cada par de paneles comparta **una sola** columna/fila de borde:

```go
// SharedBorderStyle quita el borde del lado que se comparte con el
// panel vecino, para que JoinHorizontal/JoinVertical no dupliquen
// la columna/fila de separación — igual que un split de tmux.
func SharedBorderStyle(base lipgloss.Style, shareRight, shareBottom bool) lipgloss.Style {
    s := base
    if shareRight {
        s = s.BorderRight(false)
    }
    if shareBottom {
        s = s.BorderBottom(false)
    }
    return s
}
```

```go
// Layout de 2 columnas: el panel izquierdo cede su borde derecho,
// el derecho conserva el suyo — una sola columna divisoria total.
left := ui.SharedBorderStyle(s.Panel.Resolve(focA, false), true, false).
    Width(leftInner).Height(rowInner).Render(contentA)

right := s.Panel.Resolve(focB, false).
    Width(rightInner).Height(rowInner).Render(contentB)

topRow := lipgloss.JoinHorizontal(lipgloss.Top, left, right)
```

> **Importante:** al quitar un lado del borde con `BorderRight(false)`, ese panel "pierde" 1 columna de ancho reservado para borde — hay que sumarla al `Width()` del panel para que el ancho total del layout siga cuadrando (`leftInner` en el ejemplo ya debe contemplar esta columna extra recuperada).

#### 4.7.5 Comparación visual: `Padding(0,2)` vs. `compact` (`Padding(0,0)` + bordes compartidos)

**Antes (comfortable, `Padding(0,2)`, bordes duplicados):**

```
┌──────────────────────┐┌───────────────────────┐
│                        ││                         │
│    bos-daemon          ││    running              │
│                        ││                         │
└──────────────────────┘└───────────────────────┘
```

**Después (compact, `Padding(0,0)`, borde compartido):**

```
┌─────────────────┬────────────────────┐
│bos-daemon        │running             │
└─────────────────┴────────────────────┘
```

El segundo se ve mucho más parecido a un split de tmux: el texto queda a 1 columna del trazo, y solo hay **una** línea divisoria entre paneles (`┬`/`┴` en las uniones, gracias a que lipgloss ajusta los conectores de borde automáticamente cuando los bordes son contiguos).

#### 4.7.6 Recomendaciones de valores

| Elemento | `compact` | `comfortable` | Notas |
|---|---|---|---|
| `panelPadding` | `(0, 0)` | `(0, 1)` | `(0,0)` = texto pegado al borde; usar solo si el contenido interno (tabla/lista) ya trae su propio margen visual |
| `inputPadding` | `(0, 1)` | `(0, 1)` | rara vez necesita más de 1 — inputs con `(0,2)` se ven "flotando" |
| `buttonPadding` | `(0, 1)` | `(0, 2)` | ver tabla de mínimos en 5.11.1; `(0,1)` es el piso recomendado para botones |

**Regla general:** define `panelPadding`/`inputPadding`/`buttonPadding` **una sola vez** en el theme y haz que **todas** las variantes (`Base/Focused/Blurred/Disabled/...`) de cada `Variant` lean del mismo valor — así cambiar de `comfortable` a `compact` (o un valor intermedio como `(0,1)` para paneles) se aplica de forma consistente a toda la app con un solo cambio en `theme.yaml`, sin riesgo de reintroducir los marcos deformes de 5.11.1/5.11.2.

---

> Todos los componentes deben construirse mediante constructores `New(...)` que reciben `theme.Styles`/`theme.Theme` y devuelven un tipo que implementa `ui.Component` (sección 3), para que puedan integrarse al `FocusManager`/`PanelManager`.

### 5.1 Spinner — indicador de carga

```go
import "github.com/charmbracelet/bubbles/spinner"

type model struct {
    spinner spinner.Model
    styles  theme.Styles
}

func New(s theme.Styles, t theme.Theme) model {
    sp := spinner.New()
    sp.Spinner = spinner.Dot
    sp.Style = lipgloss.NewStyle().Foreground(t.Primary)
    return model{spinner: sp, styles: s}
}

func (m model) Init() tea.Cmd { return m.spinner.Tick }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case spinner.TickMsg:
        var cmd tea.Cmd
        m.spinner, cmd = m.spinner.Update(msg)
        return m, cmd
    }
    return m, nil
}

func (m model) View() string {
    return m.spinner.View() + " " + m.styles.Subtitle.Render("Instalando dependencias...")
}
```

**Variantes de `spinner.Spinner`:** `Line`, `Dot`, `MiniDot`, `Jump`, `Pulse`, `Points`, `Globe`, `Moon`, `Monkey`.

**Pausar con blur de terminal** (recomendado): si `tea.WithReportFocus()` está activo, detener `spinner.Tick` al recibir `tea.BlurMsg` y relanzarlo al recibir `tea.FocusMsg`, para no consumir CPU cuando la terminal no está visible.

---

### 5.2 Progress — barra de progreso

```go
import "github.com/charmbracelet/bubbles/progress"

func New(t theme.Theme) progress.Model {
    return progress.New(
        progress.WithScaledGradient(
            string(t.Primary.Dark),
            string(t.Success.Dark),
        ),
        progress.WithWidth(40),
    )
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case progress.FrameMsg:
        newModel, cmd := m.progress.Update(msg)
        m.progress = newModel.(progress.Model)
        return m, cmd
    case stepDoneMsg:
        cmd := m.progress.SetPercent(msg.percent)
        return m, cmd
    }
    return m, nil
}

func (m model) View() string {
    return m.progress.View()
}
```

---

### 5.3 TextInput — campo editable con variantes de foco/error

```go
import "github.com/charmbracelet/bubbles/textinput"

func New(s theme.Styles, t theme.Theme) textinput.Model {
    ti := textinput.New()
    ti.Placeholder = "nombre-del-host"
    ti.CharLimit = 64
    ti.Width = 30

    ti.PromptStyle = lipgloss.NewStyle().Foreground(t.Primary).Background(t.Surface)
    ti.TextStyle = lipgloss.NewStyle().Foreground(t.Text).Background(t.Surface)
    ti.PlaceholderStyle = lipgloss.NewStyle().Foreground(t.Muted).Background(t.Surface)
    ti.Cursor.Style = lipgloss.NewStyle().Foreground(t.SelectionFg).Background(t.Accent)

    ti.Focus()
    return ti
}

// Renderizado con variante según estado (focused/error), análogo a
// los estilos de validación de PrimeVue (p-invalid):
func RenderField(s theme.Styles, ti textinput.Model, hasError bool) string {
    variant := s.Input.Base
    switch {
    case hasError:
        variant = s.Input.Error
    case ti.Focused():
        variant = s.Input.Focused
    default:
        variant = s.Input.Blurred
    }
    return variant.Render(ti.View())
}
```

Para integración completa con `ui.Component`, ver `TextField` en la sección 3.2.

---

### 5.3.1 Fondo del TextInput distinto al fondo del panel (extensión de 5.11.3)

El mismo problema de "fondo casi igual pero no exacto" descrito en 5.11.3 para botones afecta a `TextField`/`textinput.Model` — con una causa adicional propia de este componente: `bubbles/textinput` expone **4 sub-estilos internos** que pintan partes distintas del campo, y cada uno necesita su propio `Background` seteado.

#### Causas específicas de TextInput

1. **Las mismas de 5.11.3**: si `Input.{Base,Focused,Blurred,Disabled,Error}` no declaran `Background`/`BorderBackground` con `t.Surface`, el marco del input cae al fondo "real" de la terminal.

2. **Sub-estilos de `textinput.Model` sin `Background`** — `ti.PromptStyle`, `ti.TextStyle`, `ti.PlaceholderStyle` y `ti.Cursor.Style` son estilos independientes del contenedor `Input.Focused`/`Input.Blurred`. Si solo el contenedor tiene `t.Surface` pero estos 4 no, **el texto que escribe el usuario** se renderiza con un fondo distinto al marco — se ve como una "ventana" más oscura/clara dentro del input.

3. **Cursor con color ANSI por nombre** — el cursor por defecto de `bubbles/textinput` a menudo usa `reverse video` o `lipgloss.Color("7")` (gris ANSI), ignorando completamente la paleta del tema. Es la causa más común de "el cursor se ve con un gris feo que no es de mi tema".

#### Solución: `Input` variant + los 4 sub-estilos, mismo token `t.Surface`

```go
input := Variant{
    Base: lipgloss.NewStyle().
        Border(lipgloss.NormalBorder()).
        BorderForeground(t.BlurBorder).
        BorderBackground(t.Surface).
        Background(t.Surface).
        Padding(ip[0], ip[1]).
        Foreground(t.Text),

    Focused: lipgloss.NewStyle().
        Border(lipgloss.NormalBorder()).
        BorderForeground(t.FocusBorder).
        BorderBackground(t.Surface).
        Background(t.Surface).
        Padding(ip[0], ip[1]).
        Foreground(t.Text),

    Blurred: lipgloss.NewStyle().
        Border(lipgloss.NormalBorder()).
        BorderForeground(t.BlurBorder).
        BorderBackground(t.Surface).
        Background(t.Surface).
        Padding(ip[0], ip[1]).
        Foreground(t.Muted),

    Disabled: lipgloss.NewStyle().
        Border(lipgloss.NormalBorder()).
        BorderForeground(t.Muted).
        BorderBackground(t.Surface).
        Background(t.Surface).
        Padding(ip[0], ip[1]).
        Foreground(t.DisabledText),

    Error: lipgloss.NewStyle().
        Border(lipgloss.NormalBorder()).
        BorderForeground(t.Error).
        BorderBackground(t.Surface).
        Background(t.Surface).
        Padding(ip[0], ip[1]).
        Foreground(t.Text),
}
```

```go
// Los 4 sub-estilos de textinput.Model — TODOS con t.Surface,
// mismo token que el contenedor Input.{...} de arriba.
ti.PromptStyle = lipgloss.NewStyle().
    Foreground(t.Primary).Background(t.Surface)

ti.TextStyle = lipgloss.NewStyle().
    Foreground(t.Text).Background(t.Surface)

ti.PlaceholderStyle = lipgloss.NewStyle().
    Foreground(t.Muted).Background(t.Surface)

ti.Cursor.Style = lipgloss.NewStyle().
    Foreground(t.SelectionFg).Background(t.Accent) // cursor visible con la paleta del tema
```

#### Checklist de diagnóstico

```go
fmt.Printf("Container bg:   %v\n", s.Input.Focused.GetBackground())
fmt.Printf("Prompt bg:      %v\n", ti.PromptStyle.GetBackground())
fmt.Printf("TextStyle bg:   %v\n", ti.TextStyle.GetBackground())
fmt.Printf("Placeholder bg: %v\n", ti.PlaceholderStyle.GetBackground())
fmt.Printf("Cursor bg:      %v\n", ti.Cursor.Style.GetBackground())
```

Los 5 valores deben coincidir con `t.Surface` (o el token que use el panel contenedor). Si `Cursor bg` aparece vacío o como un color ANSI genérico (`7`, `reverse`), ese es el cursor "gris feo" desalineado del tema.

#### Resumen

- Aplica exactamente la misma regla de 5.11.3 (`Background` + `BorderBackground` = mismo token que el panel) al `Input` variant.
- Adicionalmente, setea `Background(t.Surface)` en `ti.PromptStyle`, `ti.TextStyle`, `ti.PlaceholderStyle`, y dale a `ti.Cursor.Style` un `Background` explícito de la paleta (p. ej. `t.Accent`) para que el cursor no quede con el gris ANSI por defecto.
- Esta misma corrección aplica a cualquier otro componente de `bubbles` que expuso sub-estilos internos (p. ej. `textarea.Model` tiene los mismos 4 campos) — el patrón es idéntico: contenedor + sub-estilos, todos con el mismo token de fondo.

---

```go
import "github.com/charmbracelet/bubbles/list"

type item string

func (i item) FilterValue() string { return string(i) }

type itemDelegate struct{ styles theme.Styles }

func (d itemDelegate) Height() int                             { return 1 }
func (d itemDelegate) Spacing() int                            { return 0 }
func (d itemDelegate) Update(_ tea.Msg, _ *list.Model) tea.Cmd { return nil }

func (d itemDelegate) Render(w io.Writer, m list.Model, index int, listItem list.Item) {
    i, ok := listItem.(item)
    if !ok {
        return
    }

    str := string(i)
    if index == m.Index() {
        fmt.Fprint(w, d.styles.Item.Selected.Render("➜ "+str))
    } else {
        fmt.Fprint(w, d.styles.Item.Base.Render("  "+str))
    }
}

func New(s theme.Styles, items []string) list.Model {
    listItems := make([]list.Item, len(items))
    for i, it := range items {
        listItems[i] = item(it)
    }

    l := list.New(listItems, itemDelegate{styles: s}, 30, 14)
    l.Title = "Paquetes disponibles"
    l.Styles.Title = s.Title
    l.Styles.FilterPrompt = s.Subtitle
    l.Styles.FilterCursor = s.Highlight

    return l
}
```

---

### 5.5 Table — tabla navegable

```go
import "github.com/charmbracelet/bubbles/table"

func New(s theme.Styles, t theme.Theme) table.Model {
    columns := []table.Column{
        {Title: "Servicio", Width: 20},
        {Title: "Estado", Width: 12},
        {Title: "CPU %", Width: 8},
    }

    rows := []table.Row{
        {"bos-daemon", "running", "2.3"},
        {"kong-gateway", "running", "5.1"},
        {"rust-svc", "stopped", "0.0"},
    }

    tbl := table.New(
        table.WithColumns(columns),
        table.WithRows(rows),
        table.WithFocused(true),
        table.WithHeight(8),
    )

    st := table.DefaultStyles()
    st.Header = st.Header.
        BorderStyle(lipgloss.NormalBorder()).
        BorderForeground(t.Border).
        Bold(true).
        Foreground(t.Primary)
    st.Selected = s.Item.Selected
    tbl.SetStyles(st)

    return tbl
}
```

> **v1.1+**: usar `lipgloss/table` (sub-paquete) para tablas con wrap automático de contenido y nuevos estilos de borde (markdown, ASCII). En v2, importar desde `charm.land/lipgloss/v2/table`.

---

### 5.6 Viewport — área scrolleable (logs)

```go
import "github.com/charmbracelet/bubbles/viewport"

func New(s theme.Styles, width, height int) viewport.Model {
    vp := viewport.New(width, height)
    vp.Style = s.Panel.Base
    return vp
}

func (m model) appendLog(line string) model {
    m.viewport.SetContent(m.viewport.View() + "\n" + line)
    m.viewport.GotoBottom()
    return m
}
```

Combinado con `charmbracelet/log` para logs con color semántico:

```go
import charmlog "github.com/charmbracelet/log"

logger := charmlog.NewWithOptions(logBuffer, charmlog.Options{
    ReportTimestamp: true,
    TimeFormat:      "15:04:05",
})
logger.Styles().Levels[charmlog.ErrorLevel] = m.styles.Error
logger.Styles().Levels[charmlog.InfoLevel] = m.styles.Success
```

---

### 5.7 Paginator — indicador de páginas

```go
import "github.com/charmbracelet/bubbles/paginator"

func New(t theme.Theme, totalPages int) paginator.Model {
    p := paginator.New()
    p.Type = paginator.Dots
    p.ActiveDot = lipgloss.NewStyle().Foreground(t.Primary).Render("●")
    p.InactiveDot = lipgloss.NewStyle().Foreground(t.Muted).Render("○")
    p.SetTotalPages(totalPages)
    return p
}
```

---

### 5.8 Help — panel de atajos de teclado

```go
import "github.com/charmbracelet/bubbles/help"
import "github.com/charmbracelet/bubbles/key"

type keyMap struct {
    Next key.Binding
    Quit key.Binding
}

func (k keyMap) ShortHelp() []key.Binding {
    return []key.Binding{k.Next, k.Quit}
}

func (k keyMap) FullHelp() [][]key.Binding {
    return [][]key.Binding{{k.Next, k.Quit}}
}

var keys = keyMap{
    Next: key.NewBinding(
        key.WithKeys("tab"),
        key.WithHelp("tab", "siguiente panel"),
    ),
    Quit: key.NewBinding(
        key.WithKeys("q", "ctrl+c"),
        key.WithHelp("q", "salir"),
    ),
}

func New(t theme.Theme) help.Model {
    h := help.New()
    h.Styles.ShortKey = lipgloss.NewStyle().Foreground(t.Primary)
    h.Styles.ShortDesc = lipgloss.NewStyle().Foreground(t.Muted)
    return h
}
```

---

### 5.9 Huh — formularios y wizards

```go
import "github.com/charmbracelet/huh"

func New(t theme.Theme) *huh.Form {
    customTheme := huh.ThemeBase()
    customTheme.Focused.Title = customTheme.Focused.Title.Foreground(t.Primary)
    customTheme.Focused.SelectedOption = customTheme.Focused.SelectedOption.
        Foreground(t.Background).Background(t.Primary)
    customTheme.Blurred.Title = customTheme.Blurred.Title.Foreground(t.Muted)

    var entorno string
    var confirmar bool

    return huh.NewForm(
        huh.NewGroup(
            huh.NewSelect[string]().
                Title("Selecciona el entorno objetivo").
                Options(
                    huh.NewOption("Desarrollo (144.91.76.130)", "dev"),
                    huh.NewOption("Staging (13.140.128.230)", "staging"),
                ).
                Value(&entorno),

            huh.NewConfirm().
                Title("¿Confirmar instalación?").
                Value(&confirmar),
        ),
    ).WithTheme(customTheme)
}
```

---

### 5.10 TabBar — pestañas con foco (componente nuevo, estilo PrimeVue `<TabView>`)

No existe en `bubbles`, pero se construye fácil sobre los tokens `Tab`:

```go
package widgets

import (
    tea "github.com/charmbracelet/bubbletea"
    "github.com/charmbracelet/lipgloss"
    "yourapp/theme"
    "yourapp/ui"
)

type TabBar struct {
    ui.BaseComponent
    tabs   []string
    active int
    styles theme.Styles
}

func NewTabBar(id string, tabs []string, s theme.Styles) *TabBar {
    return &TabBar{BaseComponent: ui.NewBase(id), tabs: tabs, styles: s}
}

func (t *TabBar) Init() tea.Cmd { return nil }

func (t *TabBar) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    if !t.Focused() {
        return t, nil
    }
    if km, ok := msg.(tea.KeyMsg); ok {
        switch km.String() {
        case "right", "l":
            t.active = (t.active + 1) % len(t.tabs)
        case "left", "h":
            t.active = (t.active - 1 + len(t.tabs)) % len(t.tabs)
        }
    }
    return t, nil
}

func (t *TabBar) Active() int { return t.active }

func (t *TabBar) View() string {
    var rendered []string
    for i, tab := range t.tabs {
        if i == t.active {
            rendered = append(rendered, t.styles.Tab.Selected.Render(tab))
        } else {
            rendered = append(rendered, t.styles.Tab.Base.Render(tab))
        }
    }
    return lipgloss.JoinHorizontal(lipgloss.Top, rendered...)
}
```

---

### 5.11 Badge / StatusTag (estilo PrimeVue `<Tag severity="...">`)

```go
package widgets

import "yourapp/theme"

func RenderBadge(s theme.Styles, text string, status ui.PanelStatus) string {
    switch status {
    case ui.StatusSuccess:
        return s.Badge.Selected.Render(text) // verde
    case ui.StatusError:
        return s.Badge.Error.Render(text)    // rojo
    default:
        return s.Badge.Base.Render(text)     // gris
    }
}
```

---

### 5.11.1 Button — variantes consistentes y corrección de marcos deformes (focus/blur)

Un problema muy frecuente al construir filas de botones (`Primary`, `Secondary`, `Danger`, `Ghost`, `Disabled`) es que **el marco se deforma entre estados**:

```
                ╭───────────────╮            ╭─────────╮╭──────────────╮
   Primary   │   Secondary   │   Danger   │  Ghost  ││   Disabled   │
              ╰───────────────╯            ╰─────────╯╰──────────────╯
```

**Regla de oro:** todas las variantes de un mismo `Variant` deben declarar **exactamente el mismo `Border` struct y el mismo `Padding`** — solo cambian color de borde, color de fondo, `Bold`, etc. Para una variante "sin borde visible" (ej. `Ghost`), usar `lipgloss.HiddenBorder()` en lugar de omitir `.Border()`, ya que reserva el mismo espacio sin dibujar el trazo.

La variante `Button` ya está definida en `theme.Styles()` (sección 2.3) siguiendo esta regla: `Base/Focused/Blurred/Disabled/Selected` comparten `lipgloss.RoundedBorder()` y `Padding(0, 2)`, mientras que `Error` (usada para "Ghost") usa `lipgloss.HiddenBorder()` con el mismo padding — mismo espacio reservado, sin trazo visible.

#### Renderizado de la fila de botones con separación explícita

No depender del espacio implícito de `JoinHorizontal`: insertar un separador explícito entre botones evita que los bordes queden pegados o descuadrados al cambiar de estado.

```go
type Button struct {
    Label    string
    Focused  bool
    Disabled bool
    Status   ui.PanelStatus // para variantes Danger/Ghost
}

func RenderButtonRow(s theme.Styles, buttons []Button) string {
    var rendered []string
    for i, b := range buttons {
        var variant lipgloss.Style
        switch {
        case b.Disabled:
            variant = s.Button.Disabled
        case b.Status == ui.StatusError:
            variant = s.Button.Selected // Danger
        case b.Focused:
            variant = s.Button.Focused
        default:
            variant = s.Button.Blurred
        }

        rendered = append(rendered, variant.Render(b.Label))

        if i < len(buttons)-1 {
            rendered = append(rendered, " ") // separador fijo de 1 espacio
        }
    }
    return lipgloss.JoinHorizontal(lipgloss.Top, rendered...)
}
```

#### Resultado esperado

```
╭─────────╮ ╭───────────╮ ╭─────────╮ ╭─────────╮ ╭──────────╮
│ Primary │ │ Secondary │ │ Danger  │ │  Ghost  │ │ Disabled │
╰─────────╯ ╰───────────╯ ╰─────────╯ ╰─────────╯ ╰──────────╯
```

Todos los botones mantienen el mismo marco (`RoundedBorder` o `HiddenBorder` con igual padding), y solo cambian color de fondo/borde/texto según su variante y estado de foco. Al hacer `tab` entre botones, solo el color de `Focused` cambia — la geometría del marco permanece estable.

#### Mínimo de padding recomendado

| Padding | Resultado | Cuándo usarlo |
|---|---|---|
| `Padding(0, 0)` | Texto pegado al borde | Evitar — se ve apretado |
| `Padding(0, 1)` | Mínimo aceptable: 1 espacio a cada lado | Labels cortos (`OK`, `No`), espacios reducidos |
| `Padding(0, 2)` | **Recomendado** — estándar de facto en TUIs Charm | Botones normales (`Guardar`, `Cancelar`, `Eliminar`) |
| `Padding(0, 3-4)` | Más prominente | CTAs principales con espacio horizontal disponible |

El padding **vertical** debe mantenerse en `0` para botones de una sola línea; subirlo a `1` convierte el botón en una "card" de 3 líneas de alto, lo cual rara vez es deseable en una fila de acciones. Lo crítico no es el valor exacto sino que **sea idéntico en todas las variantes** del mismo componente — la inconsistencia entre variantes es la causa real de los marcos deformes.

---

### 5.11.2 Botones con cursor de navegación (`➜`) — bordes desalineados y layouts sin deformación

Esta sección cubre **dos problemas relacionados** que aparecen al añadir un indicador de cursor (`➜`, `▸`, etc.) para navegación con flechas (`↑↓`/`←→` + `Enter`):

**Problema A — alturas desiguales (`Ghost` sin caja):**

```
➜ ╭─────────────╮
│   Primary   │
╰─────────────╯
   ╭───────────────╮
│   Secondary   │
╰───────────────╯
    Ghost
   ╭──────────────╮
│   Disabled   │
╰──────────────╯
```

**Problema B — borde desplazado respecto al contenido (más sutil, más común):**

```
   ╭──────────────╮
│  ➜  Primary  │
╰──────────────╯
   ╭────────────────╮
│     Secondary  │
╰────────────────╯
      Ghost
   ╭───────────────╮
│     Disabled  │
╰───────────────╯
```

Aquí cada caja *sí* tiene 3 líneas, pero el borde superior/inferior aparece desplazado ~3 columnas a la derecha respecto a la línea de contenido (`│ ... │`). `Ghost` sigue sin caja.

#### Causas

1. **(Problema A)** `Ghost` sin borde mide 1 línea de alto, mientras los demás miden 3. Al unir con `JoinVertical`/`JoinHorizontal`, las alturas desiguales descuadran el bloque.
2. **(Problema B)** El borde y el contenido se construyen **por separado** y se concatenan a mano, por ejemplo:

```go
// ❌ INCORRECTO: el marco se "dibuja" como strings sueltos
topBorder    := "   ╭" + strings.Repeat("─", width) + "╮"
contentLine  := "│  " + cursor + label + "  │"
bottomBorder := "   ╰" + strings.Repeat("─", width) + "╯"
box := topBorder + "\n" + contentLine + "\n" + bottomBorder
```

El `"   "` (espacios de indentación) antes de `╭`/`╰` no existe antes de `│` en la línea de contenido — de ahí el desplazamiento. Es el mismo error de raíz que en 5.11.1 (variantes inconsistentes), pero a nivel de **construcción manual del marco** en vez de a nivel de `lipgloss.Style`.
3. **(Ambos)** El cursor `➜` se concatena como prefijo de texto **fuera** del área delimitada por el borde, en vez de ir dentro del contenido.

#### Regla de oro

1. **Nunca construir el marco (`╭─╮`/`╰─╯`) a mano con strings.** Usar siempre `style.Render(contenido)` de lipgloss, que genera borde + padding + contenido como **una sola unidad** ya alineada — lipgloss calcula el ancho de cada línea internamente, sin desplazamientos.
2. **`Ghost` también debe usar `lipgloss.HiddenBorder()`** con el mismo `Padding` que las demás variantes — mismo alto/ancho reservado, sin trazo visible.
3. **El cursor se inyecta dentro del string que recibe `.Render()`**, nunca como prefijo externo, y se sustituye por espacios del mismo ancho cuando el botón no tiene foco — el tamaño total no cambia entre estados.

```go
// RenderButton renderiza un botón como una caja completa generada
// por un único style.Render() — borde, padding y contenido quedan
// alineados automáticamente, sin construir el marco a mano.
func RenderButton(s theme.Styles, label string, focused, disabled bool, variant ui.ButtonVariant) string {
    var style lipgloss.Style
    switch {
    case disabled:
        style = s.Button.Disabled
    case variant == ui.ButtonDanger:
        style = s.Button.Selected
    case variant == ui.ButtonGhost:
        style = s.Button.Error // HiddenBorder, MISMO Padding(0,2) que los demás
    case focused:
        style = s.Button.Focused
    default:
        style = s.Button.Blurred
    }

    cursor := "  " // 2 espacios = mismo ancho visual que "➜ "
    if focused {
        cursor = "➜ "
    }

    // .Render() construye borde + padding + contenido como UNA pieza:
    // el resultado ya viene perfectamente alineado en columna 0.
    return style.Render(cursor + label)
}
```

```go
func (t Theme) Styles() Styles {
    border := lipgloss.RoundedBorder()

    button := Variant{
        Base: lipgloss.NewStyle().
            Border(border).BorderForeground(t.BlurBorder).
            Padding(0, 2),
        Focused: lipgloss.NewStyle().
            Border(border).BorderForeground(t.FocusBorder).
            Padding(0, 2).Bold(true).
            Foreground(t.SelectionFg).Background(t.Primary),
        Blurred: lipgloss.NewStyle().
            Border(border).BorderForeground(t.BlurBorder).
            Padding(0, 2),
        Disabled: lipgloss.NewStyle().
            Border(border).BorderForeground(t.Muted).
            Padding(0, 2).Foreground(t.DisabledText),
        Selected: lipgloss.NewStyle(). // Danger
            Border(border).BorderForeground(t.Error).
            Padding(0, 2).Foreground(t.SelectionFg).Background(t.Error),
        Error: lipgloss.NewStyle(). // Ghost — MISMO padding, borde invisible
            Border(lipgloss.HiddenBorder()).
            Padding(0, 2),
    }
    // ... añadir Button: button al return de Styles
}
```

#### Layout vertical (`↑↓` navega)

```go
func RenderButtonColumn(s theme.Styles, buttons []Button) string {
    var rendered []string
    for _, b := range buttons {
        rendered = append(rendered, RenderButton(s, b.Label, b.Focused, b.Disabled, b.Variant))
    }
    return lipgloss.JoinVertical(lipgloss.Left, rendered...)
}
```

Como **todas** las cajas salen de `style.Render()` con el mismo `Border`/`Padding` (incluida `Ghost` con `HiddenBorder`), todas miden 3 líneas y el mismo ancho de columna 0 — `JoinVertical` las alinea sin trucos adicionales.

#### Layout horizontal (`←→` navega)

```go
func RenderButtonRow(s theme.Styles, buttons []Button) string {
    var rendered []string
    for i, b := range buttons {
        rendered = append(rendered, RenderButton(s, b.Label, b.Focused, b.Disabled, b.Variant))
        if i < len(buttons)-1 {
            rendered = append(rendered, " ") // gap fijo entre botones
        }
    }
    return lipgloss.JoinHorizontal(lipgloss.Top, rendered...)
}
```

#### Resultado esperado

**Vertical** (`Primary` con foco):

```
╭──────────────╮
│ ➜  Primary   │
╰──────────────╯
╭──────────────╮
│    Secondary │
╰──────────────╯
╭──────────────╮
│    Danger    │
╰──────────────╯
╭──────────────╮
│    Ghost     │
╰──────────────╯
╭──────────────╮
│    Disabled  │
╰──────────────╯
```

**Horizontal** (`Primary` con foco):

```
╭──────────────╮ ╭────────────────╮ ╭─────────────╮ ╭─────────────╮ ╭───────────────╮
│ ➜  Primary   │ │    Secondary    │ │   Danger    │ │    Ghost    │ │   Disabled    │
╰──────────────╯ ╰────────────────╯ ╰─────────────╯ ╰─────────────╯ ╰───────────────╯
```

#### Resumen de la corrección

- **Nunca dibujar `╭─╮`/`╰─╯` con concatenación manual de strings.** Toda caja debe salir de `lipgloss.Style.Render()` — borde, padding y contenido alineados como una sola unidad.
- `Ghost` usa `Button.Error` (= `lipgloss.HiddenBorder()`, mismo `Padding(0,2)`) — nunca "sin borde" ni texto suelto, para conservar el mismo alto/ancho reservado que el resto.
- El cursor `➜`/`▸` va **dentro** del contenido que recibe `.Render()`, nunca como prefijo externo a la caja.
- Cuando el botón no tiene foco, el cursor se reemplaza por espacios del mismo ancho — el tamaño del botón no "salta" al enfocar/desenfocar.
- Para navegación vertical u horizontal, `JoinVertical`/`JoinHorizontal` funcionan sin contenedores adicionales **siempre que todas las cajas provengan de `.Render()` con el mismo `Border`/`Padding`**; no es necesario envolver cada botón en un panel extra.

---

### 5.11.3 Fondo del botón distinto al fondo del panel (mismo token, color "casi igual")

Un problema que aparece incluso con los marcos ya corregidos (5.11.1/5.11.2): el **fondo del botón no coincide exactamente** con el fondo del panel que lo contiene, aunque ambos usen el mismo token de `theme.yaml` (`t.Surface`/`t.Background`). Visualmente se ve como un "recuadro" sutil alrededor de cada botón, de un negro/gris ligeramente distinto al resto del panel.

#### Causas

1. **`Background()` no declarado explícitamente en la variante del botón.** Si la variante solo define `Border(...)`/`BorderForeground(...)` pero no `.Background(t.Surface)`, lipgloss rellena el área de padding/contenido con el **fondo por defecto de la terminal** (normalmente `#000000` puro), que casi nunca coincide exactamente con el `t.Surface`/`t.Background` de tu paleta (p. ej. `#1A1B26`).

2. **`BorderBackground()` es una propiedad separada de `Background()`.** `Background()` controla el relleno detrás del *texto/padding*; `BorderBackground()` controla el relleno detrás de los *caracteres del borde* (`─│╭╮╰╯`). Si solo seteas uno de los dos, el trazo del borde y el interior del botón quedan con fondos distintos entre sí — y ninguno de los dos necesariamente coincide con el panel.

3. **Perfil de color limitado (ver apéndice 12).** En `ANSI256`, dos hex muy cercanos del panel y del botón pueden redondearse a colores de 256 *distintos*, aunque en `TrueColor` sean indistinguibles. Verificar `lipgloss.ColorProfile()` antes de descartar esta causa.

4. **Componentes internos con `Background` hardcodeado.** Si el botón envuelve un `bubbles/textinput` (u otro) cuyo constructor ya seteó un color de fondo por nombre ANSI (`lipgloss.Color("0")`) en vez del token del tema, ese fondo "interno" prevalece sobre el del contenedor.

#### Checklist de diagnóstico

```go
// Imprimir los valores reales para comparar panel vs. botón
fmt.Printf("Panel   bg: %v\n", t.Surface)
fmt.Printf("Button  bg: %v\n", s.Button.Blurred.GetBackground())
fmt.Printf("Border  bg: %v\n", s.Button.Blurred.GetBorderTopBackground())
fmt.Printf("Color profile: %v\n", lipgloss.ColorProfile()) // debe ser 3 (TrueColor)
```

Si `Button bg` y `Border bg` están vacíos (`AdaptiveColor{}` / `NoColor{}`) mientras `Panel bg` tiene un valor, ahí está el problema: el botón está heredando el fondo "real" de la terminal en vez de `t.Surface`.

#### Solución: declarar `Background` + `BorderBackground` en TODAS las variantes

```go
button := Variant{
    Base: lipgloss.NewStyle().
        Border(buttonBorder).
        BorderForeground(t.BlurBorder).
        BorderBackground(t.Surface). // fondo DETRÁS del trazo del borde
        Background(t.Surface).       // fondo del padding/contenido
        Padding(bp[0], bp[1]).
        Foreground(t.Text),

    Focused: lipgloss.NewStyle().
        Border(buttonBorder).
        BorderForeground(t.FocusBorder).
        BorderBackground(t.Surface).
        Background(t.Surface).
        Padding(bp[0], bp[1]).
        Bold(true).
        Foreground(t.FocusBorder),

    Blurred: lipgloss.NewStyle().
        Border(buttonBorder).
        BorderForeground(t.BlurBorder).
        BorderBackground(t.Surface).
        Background(t.Surface).
        Padding(bp[0], bp[1]).
        Foreground(t.Text),

    Disabled: lipgloss.NewStyle().
        Border(buttonBorder).
        BorderForeground(t.Muted).
        BorderBackground(t.Surface).
        Background(t.Surface).
        Padding(bp[0], bp[1]).
        Foreground(t.DisabledText),

    Selected: lipgloss.NewStyle(). // Danger
        Border(buttonBorder).
        BorderForeground(t.Error).
        BorderBackground(t.Surface).
        Background(t.Surface).
        Padding(bp[0], bp[1]).
        Foreground(t.Error),

    Error: lipgloss.NewStyle(). // Ghost — mismo fondo, borde invisible
        Border(lipgloss.HiddenBorder()).
        BorderBackground(t.Surface).
        Background(t.Surface).
        Padding(bp[0], bp[1]).
        Foreground(t.Muted),
}
```

> **Importante:** usa **el mismo token** (`t.Surface` o `t.Background`, lo que use el panel contenedor) en `Background` y `BorderBackground` de *todas* las variantes del botón. Si el panel usa `t.Background` pero el botón usa `t.Surface` — aunque ambos existan y se vean "casi iguales" en el `theme.yaml` — seguirá apareciendo el recuadro sutil si son valores hex distintos.

#### Variantes semánticas (Danger/Success/Warning) con fondo de acento

Si en lugar de un fondo neutro quieres que `Danger`/`Success`/`Warning` tengan **su propio fondo de color** (botón "sólido" en vez de solo borde coloreado, como en la fila horizontal "Secondary" con foco de la captura), aplica el mismo principio pero con el color de acento en ambas propiedades, y ajusta `Foreground`/`BorderForeground` para mantener contraste suficiente entre texto y fondo (idealmente un ratio ≥4.5:1, según WCAG 2.1 AA):

```go
Selected: lipgloss.NewStyle(). // Danger "sólido"
    Border(buttonBorder).
    BorderForeground(t.Error).
    BorderBackground(t.Error).   // fondo de acento también detrás del borde
    Background(t.Error).
    Padding(bp[0], bp[1]).
    Bold(true).
    Foreground(t.SelectionFg),  // texto claro sobre fondo de color
```

#### Resumen

- `Background()` define el relleno del **contenido/padding**; `BorderBackground()` define el relleno **detrás del trazo del borde**. Ambos deben declararse — omitir uno deja un "marco" de color distinto al resto.
- Usa el **mismo token hex** que el panel contenedor en ambas propiedades, en **todas** las variantes (`Base/Focused/Blurred/Disabled/Selected/Error`).
- Si después de esto persiste una diferencia sutil, verifica `lipgloss.ColorProfile()` (apéndice 12) — en `ANSI256`, hex muy cercanos pueden redondear a colores distintos.
- Para botones "sólidos" con fondo de acento (Danger/Success/Warning), aplica el color de acento a `Background`+`BorderBackground` simultáneamente y ajusta el `Foreground` para mantener contraste legible.

---

### 5.12 Lipgloss v2 — Compositing con `Layer`/`Canvas` (overlays, modales)

Novedad clave de v2 para casos que antes eran muy manuales en v1 (modales flotantes, tooltips, dropdowns superpuestos):

```go
import "charm.land/lipgloss/v2"

box := lipgloss.NewStyle().Width(30).Height(8).Border(lipgloss.RoundedBorder())

background := lipgloss.NewLayer(mainView)
modal := lipgloss.NewLayer(box.Render("¿Confirmar acción?")).
    X(10).Y(5). // posición absoluta dentro del canvas
    Z(1)        // por encima del fondo

canvas := lipgloss.NewCanvas(background, modal)
output := canvas.Render()
```

Esto reemplaza trucos anteriores de superposición manual de strings y habilita **modales reales**, dropdowns y popovers — el equivalente de `<Dialog>`/`<OverlayPanel>` en PrimeVue.

---

### 5.14 TreePanel — árbol navegable (`lipgloss/tree` + foco)

`lipgloss` incluye un sub-paquete `tree` (v1: `github.com/charmbracelet/lipgloss/tree`; v2: `charm.land/lipgloss/v2/tree`) que renderiza árboles con estilos por nivel. No trae navegación con teclado, así que se envuelve en un `Component` propio para integrarlo al `FocusManager`/`PanelManager`.

```go
package widgets

import (
    tea "github.com/charmbracelet/bubbletea"
    "github.com/charmbracelet/lipgloss"
    ltree "github.com/charmbracelet/lipgloss/tree"
    "yourapp/theme"
    "yourapp/ui"
)

// TreeNode es un nodo de datos genérico (independiente del render de lipgloss/tree).
type TreeNode struct {
    Label    string
    Children []*TreeNode
    expanded bool
}

type TreePanel struct {
    ui.BaseComponent
    root     *TreeNode
    flat     []*TreeNode // vista plana (aplanado según expand/collapse) para navegación
    cursor   int
    styles   theme.Styles
}

func NewTreePanel(id string, root *TreeNode, s theme.Styles) *TreePanel {
    t := &TreePanel{BaseComponent: ui.NewBase(id), root: root, styles: s}
    t.rebuildFlat()
    return t
}

// rebuildFlat recorre el árbol respetando expanded/collapsed,
// y construye la lista lineal que se usa para mover el cursor con ↑/↓.
func (t *TreePanel) rebuildFlat() {
    t.flat = nil
    var walk func(n *TreeNode)
    walk = func(n *TreeNode) {
        t.flat = append(t.flat, n)
        if n.expanded {
            for _, c := range n.Children {
                walk(c)
            }
        }
    }
    for _, c := range t.root.Children {
        walk(c)
    }
}

func (t *TreePanel) Init() tea.Cmd { return nil }

func (t *TreePanel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    if !t.Focused() || !t.Enabled() {
        return t, nil
    }
    if km, ok := msg.(tea.KeyMsg); ok {
        switch km.String() {
        case "up", "k":
            if t.cursor > 0 {
                t.cursor--
            }
        case "down", "j":
            if t.cursor < len(t.flat)-1 {
                t.cursor++
            }
        case "right", "l", "enter":
            n := t.flat[t.cursor]
            if len(n.Children) > 0 {
                n.expanded = true
                t.rebuildFlat()
            }
        case "left", "h":
            n := t.flat[t.cursor]
            if n.expanded {
                n.expanded = false
                t.rebuildFlat()
            }
        }
    }
    return t, nil
}

// View construye un lipgloss/tree.Tree dinámicamente a partir de t.flat,
// aplicando Item.Selected al nodo bajo el cursor.
func (t *TreePanel) View() string {
    render := func(n *TreeNode, depth int) string {
        prefix := "  "
        if len(n.Children) > 0 {
            if n.expanded {
                prefix = "▾ "
            } else {
                prefix = "▸ "
            }
        }
        label := prefix + n.Label
        return label
    }

    var lines []string
    for i, n := range t.flat {
        depth := 0
        for p := t.root; p != nil; {
            // profundidad simplificada: en una implementación real
            // se calcula al construir `flat` (guardar depth junto al nodo)
            break
        }
        line := render(n, depth)
        if i == t.cursor {
            line = t.styles.Item.Selected.Render(line)
        } else {
            line = t.styles.Item.Base.Render(line)
        }
        lines = append(lines, line)
    }

    body := lipgloss.JoinVertical(lipgloss.Left, lines...)
    variant := t.styles.Panel.Resolve(t.Focused(), !t.Enabled())
    return variant.Render(body)
}
```

> Alternativa: para árboles puramente *informativos* (sin navegación), usar directamente `lipgloss/tree`:
> ```go
> t := ltree.New().
>     Root("proyecto/").
>     Child(
>         ltree.New().Root("cmd/").Child("main.go"),
>         ltree.New().Root("internal/").Child("theme/", "ui/"),
>         "go.mod",
>     )
> fmt.Println(t.String())
> ```
> Esto produce un árbol estático con conectores `├──`/`└──` automáticos — útil para vistas de "estructura de archivos" sin interacción.

---

### 5.15 FilePicker — selector de archivos (`bubbles/filepicker`)

`bubbles/filepicker` (incluido en v1 y v2) navega el sistema de archivos con teclado, con estilos propios por tipo de entrada (directorio, symlink, archivo, deshabilitado, seleccionado).

```go
import "github.com/charmbracelet/bubbles/filepicker"

func New(s theme.Styles, t theme.Theme) filepicker.Model {
    fp := filepicker.New()
    fp.CurrentDirectory, _ = os.UserHomeDir()
    fp.AllowedTypes = []string{".yaml", ".yml", ".json"}

    fp.Styles.Directory = lipgloss.NewStyle().Foreground(t.Primary)
    fp.Styles.File = lipgloss.NewStyle().Foreground(t.Text)
    fp.Styles.Symlink = lipgloss.NewStyle().Foreground(t.Secondary)
    fp.Styles.Permission = s.Muted
    fp.Styles.Selected = s.Item.Selected
    fp.Styles.DisabledFile = s.Item.Disabled
    fp.Styles.DisabledCursor = s.Item.Disabled
    fp.Styles.FileSize = s.Muted
    fp.Styles.EmptyDirectory = s.Muted

    return fp
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmd tea.Cmd
    m.filepicker, cmd = m.filepicker.Update(msg)

    if didSelect, path := m.filepicker.DidSelectFile(msg); didSelect {
        m.selectedFile = path
    }
    return m, cmd
}
```

> v2: importar `charm.land/bubbles/v2/filepicker`. La API de tamaño cambió a getters/setters (`fp.SetHeight(20)` en vez de `fp.Height = 20`), siguiendo la convención general de v2.

---

### 5.16 FloatingPanel / Modal — paneles flotantes (overlay)

Construye sobre `lipgloss.Layer`/`Canvas` (v2, sección 5.12) o, en v1, sobre superposición manual con `lipgloss.Place` + recorte de líneas. Se expone como `Component` para que el `PanelManager` lo trate como una capa adicional.

```go
package ui

import (
    "strings"

    "github.com/charmbracelet/lipgloss"
    "yourapp/theme"
)

// FloatingPanel representa un panel que se superpone sobre el layout principal
// (modal, tooltip, menú contextual, confirmación).
type FloatingPanel struct {
    BaseComponent
    title   string
    content Component
    width   int
    height  int
    visible bool
    styles  theme.Styles
}

func NewFloatingPanel(id, title string, content Component, s theme.Styles) *FloatingPanel {
    return &FloatingPanel{
        BaseComponent: NewBase(id),
        title:         title,
        content:       content,
        styles:        s,
    }
}

func (f *FloatingPanel) Show() { f.visible = true; f.Focus() }
func (f *FloatingPanel) Hide() { f.visible = false; f.Blur() }
func (f *FloatingPanel) Visible() bool { return f.visible }

// Render superpone el floating panel sobre `background` (string ya renderizado),
// centrado. Usa lipgloss.Place para v1; en v2 se recomienda Layer/Canvas (5.12).
func (f *FloatingPanel) Render(background string, screenW, screenH int) string {
    if !f.visible {
        return background
    }

    box := f.styles.Panel.Focused.
        Width(f.width).
        Height(f.height)

    body := f.styles.Title.Render(f.title) + "\n" + f.content.View()
    floating := box.Render(body)

    // v1: composición manual centrando el floating panel sobre el fondo
    return overlay(background, floating, screenW, screenH)
}

// overlay reemplaza las líneas/columnas centrales del fondo con el contenido flotante.
// Implementación simplificada; para casos complejos usar lipgloss.Layer/Canvas (v2).
func overlay(bg, fg string, screenW, screenH int) string {
    bgLines := strings.Split(bg, "\n")
    fgLines := strings.Split(fg, "\n")

    fgW := lipgloss.Width(fg)
    fgH := len(fgLines)

    startY := (screenH - fgH) / 2
    startX := (screenW - fgW) / 2

    for i, line := range fgLines {
        y := startY + i
        if y < 0 || y >= len(bgLines) {
            continue
        }
        bgLine := bgLines[y]
        bgRunes := []rune(bgLine)
        fgRunes := []rune(line)

        for j, r := range fgRunes {
            x := startX + j
            for len(bgRunes) <= x {
                bgRunes = append(bgRunes, ' ')
            }
            bgRunes[x] = r
        }
        bgLines[y] = string(bgRunes)
    }

    return strings.Join(bgLines, "\n")
}
```

**Uso típico (confirmación de acción destructiva):**

```go
confirmContent := widgets.NewTextField("confirm-msg", "¿Eliminar kong-gateway? (y/n)", s)
modal := ui.NewFloatingPanel("confirm-delete", "Confirmar", confirmContent, s)
modal.width, modal.height = 30, 5

// en View():
view := panels.View()
if modal.Visible() {
    view = modal.Render(view, m.width, m.height)
}
return view
```

**Recomendación v2:** usar `lipgloss.NewLayer(floating).X(x).Y(y).Z(1)` sobre un `lipgloss.NewCanvas(background, floating)` — evita el manejo manual de runas y respeta mejor anchos de caracteres anchos (CJK, emoji).

---

### 5.17 Charts — `ntcharts` (sparkline, barchart, linechart, heatmap)

`github.com/NimbleMarkets/ntcharts` (v1) / `github.com/NimbleMarkets/ntcharts/v2` añade visualización de datos tipo dashboard — el equivalente a los componentes `<Chart>` de PrimeVue.

```go
import "github.com/NimbleMarkets/ntcharts/sparkline"

func NewCPUSparkline(s theme.Styles, t theme.Theme, width, height int) sparkline.Model {
    sl := sparkline.New(width, height,
        sparkline.WithStyle(lipgloss.NewStyle().Foreground(t.Primary)),
    )
    return sl
}

// Actualizar con nuevos datos (ej. cada segundo vía tea.Tick):
func (m model) pushCPU(value float64) {
    m.cpuSparkline.Push(value)
    m.cpuSparkline.Draw()
}

func (m model) View() string {
    variant := m.styles.Panel.Resolve(false, false)
    return variant.Render("CPU\n" + m.cpuSparkline.View())
}
```

**Tipos disponibles:** `sparkline`, `barchart` (filas/columnas), `linechart` (genérico, con zoom/scroll vía mouse o teclado), `streamlinechart`, `timeserieslinechart`, `wavelinechart`, `heatmap`. Todos siguen el patrón `New(w, h, opts...)` + `Push`/`Draw` + `View()`, y aceptan `lipgloss.Style` para colorear según el `Theme` central — por lo tanto se integran igual que cualquier otro componente: se les pasa `t.Primary`, `t.Success`, etc. en su construcción.

> Para mouse (zoom/drag en `linechart`), `ntcharts` requiere `bubblezone` (`github.com/lrstanley/bubblezone` o `github.com/NimbleMarkets/...`) — gestor de "zonas" clicables, útil si tu app necesita soporte de mouse además de teclado.

---

### 5.18 Tabla de librerías complementarias (para ampliar el catálogo)

| Necesidad                          | Librería                                                   | Integración con este sistema |
|-------------------------------------|--------------------------------------------------------------|----------------------------------|
| Árbol navegable                     | `lipgloss/tree` (estático) + wrapper propio (interactivo)     | `TreePanel` (5.14), implementa `ui.Component` |
| Selector de archivos/directorios     | `bubbles/filepicker`                                          | Estilizar con `theme.Styles`, envolver en `Component` |
| Paneles flotantes / modales          | `lipgloss.Layer`+`Canvas` (v2) o overlay manual (v1)          | `FloatingPanel` (5.16) |
| Gráficos (sparkline, barras, líneas) | `NimbleMarkets/ntcharts`                                       | Pasar colores del `Theme` al construir cada chart |
| Soporte de mouse / zonas clicables   | `lrstanley/bubblezone`                                        | Registrar zonas por `Panel.ID()` para click-to-focus |
| Markdown renderizado (ayuda, changelog) | `charmbracelet/glamour`                                     | Usar `glamour.WithStylesFromJSONBytes` derivado del `Theme` |
| Animaciones (transiciones suaves)    | `charmbracelet/harmonica`                                     | Animar `FlexRatio` de paneles, progress bars, etc. |
| Formularios avanzados / wizards      | `charmbracelet/huh`                                           | Ya cubierto en 5.9; derivar `huh.Theme` del `Theme` central |
| Logging con color semántico          | `charmbracelet/log`                                           | Ya cubierto en 5.6 |
| Tablas avanzadas (wrap, bordes md)   | `lipgloss/table` (v1.1+) / `lipgloss/v2/table`                | Reemplaza a `bubbles/table` para tablas grandes/anchas |
| Listas con bullets/numeración        | `lipgloss/list` / `lipgloss/v2/list`                          | Útil para resúmenes, changelogs, ayuda |

Con estas piezas, el catálogo cubre: **inputs, listas, tablas, árboles, selección de archivos, tabs, badges, paneles con foco, paneles flotantes/modales, gráficos y formularios** — el conjunto mínimo equivalente a una librería de componentes tipo PrimeVue/Tailwind para terminal.

---

```go
// Unir paneles
row := lipgloss.JoinHorizontal(lipgloss.Top, panelIzq, panelDer)
col := lipgloss.JoinVertical(lipgloss.Left, header, body, footer)

// Centrar en pantalla completa
final := lipgloss.Place(
    width, height,
    lipgloss.Center, lipgloss.Center,
    content,
)
```

---

### 5.14 TreePanel — árbol navegable (estilo `<Tree>` de PrimeVue / explorador de archivos)

Basado en el sub-paquete `lipgloss/tree` (v1: `github.com/charmbracelet/lipgloss/tree`, v2: `charm.land/lipgloss/v2/tree`), que renderiza árboles con conectores `├──`/`└──`, combinado con un `ui.Component` que mantiene el nodo seleccionado y el estado expandido/colapsado.

```go
package widgets

import (
    "github.com/charmbracelet/lipgloss/tree"
    tea "github.com/charmbracelet/bubbletea"
    "yourapp/theme"
    "yourapp/ui"
)

// TreeNode es un nodo de dominio: cualquier estructura jerárquica
// (sistema de archivos, menú de configuración, organigrama, etc.)
type TreeNode struct {
    Label    string
    Children []*TreeNode
    Expanded bool
}

type TreePanel struct {
    ui.BaseComponent
    root      *TreeNode
    flat      []*TreeNode // representación plana visible (para navegación con cursor)
    cursor    int
    styles    theme.Styles
}

func NewTreePanel(id string, root *TreeNode, s theme.Styles) *TreePanel {
    tp := &TreePanel{BaseComponent: ui.NewBase(id), root: root, styles: s}
    tp.rebuildFlat()
    return tp
}

// rebuildFlat recorre el árbol y construye la lista de nodos visibles
// (respetando Expanded), para mapear el cursor a un nodo concreto.
func (tp *TreePanel) rebuildFlat() {
    tp.flat = nil
    var walk func(n *TreeNode)
    walk = func(n *TreeNode) {
        tp.flat = append(tp.flat, n)
        if n.Expanded {
            for _, c := range n.Children {
                walk(c)
            }
        }
    }
    for _, c := range tp.root.Children {
        walk(c)
    }
}

func (tp *TreePanel) Init() tea.Cmd { return nil }

func (tp *TreePanel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    if !tp.Focused() || !tp.Enabled() {
        return tp, nil
    }
    if km, ok := msg.(tea.KeyMsg); ok {
        switch km.String() {
        case "up", "k":
            if tp.cursor > 0 {
                tp.cursor--
            }
        case "down", "j":
            if tp.cursor < len(tp.flat)-1 {
                tp.cursor++
            }
        case "enter", " ", "right", "l":
            node := tp.flat[tp.cursor]
            if len(node.Children) > 0 {
                node.Expanded = !node.Expanded
                tp.rebuildFlat()
            }
        case "left", "h":
            node := tp.flat[tp.cursor]
            if node.Expanded {
                node.Expanded = false
                tp.rebuildFlat()
            }
        }
    }
    return tp, nil
}

// Selected devuelve el nodo actualmente bajo el cursor.
func (tp *TreePanel) Selected() *TreeNode {
    if tp.cursor < len(tp.flat) {
        return tp.flat[tp.cursor]
    }
    return nil
}

func (tp *TreePanel) View() string {
    t := tree.Root(tp.root.Label)

    var build func(n *TreeNode) *tree.Tree
    build = func(n *TreeNode) *tree.Tree {
        sub := tree.New()
        for _, c := range n.Children {
            label := c.Label
            if len(c.Children) > 0 {
                if c.Expanded {
                    label = "▾ " + label
                } else {
                    label = "▸ " + label
                }
            }
            // resaltar el nodo bajo el cursor con la variante Selected
            if c == tp.Selected() {
                label = tp.styles.Item.Selected.Render(label)
            } else {
                label = tp.styles.Item.Base.Render(label)
            }

            if c.Expanded && len(c.Children) > 0 {
                sub.Child(build(c))
            } else {
                sub.Child(label)
            }
        }
        return tree.Root(n.Label).Child(sub)
    }

    for _, c := range tp.root.Children {
        if c.Expanded && len(c.Children) > 0 {
            t.Child(build(c))
        } else {
            label := c.Label
            if c == tp.Selected() {
                label = tp.styles.Item.Selected.Render(label)
            }
            t.Child(label)
        }
    }

    t = t.
        Enumerator(tree.RoundedEnumerator).
        EnumeratorStyle(tp.styles.Muted).
        RootStyle(tp.styles.Title)

    variant := tp.styles.Panel.Resolve(tp.Focused(), !tp.Enabled())
    return variant.Render(t.String())
}
```

**Vista:**

```
┏━ Proyecto ━━━━━━━━━━━━━━━━━━━┓
┃ ⁜ Proyecto                   ┃
┃ ├── ▾ src                     ┃
┃ │   ├── main.go               ┃
┃ │   └── ➜ theme.go            ┃   ← nodo seleccionado (Item.Selected)
┃ ├── ▸ pkg                     ┃   ← colapsado
┃ └── go.mod                    ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

> Para árboles **muy** grandes (miles de nodos), conviene paginar `tp.flat` y renderizar solo la ventana visible (como hace `viewport`), en vez de construir el `tree.Tree` completo cada frame.

---

### 5.15 FilePicker — selector de archivos/directorios

`bubbles/filepicker` (v1: `github.com/charmbracelet/bubbles/filepicker`, v2: `charm.land/bubbles/v2/filepicker`) ya trae navegación de directorios, permisos, tamaños y tipos permitidos. Se integra al design system tematizando `filepicker.Styles`:

```go
import "github.com/charmbracelet/bubbles/filepicker"

func New(s theme.Styles, t theme.Theme, startPath string) filepicker.Model {
    fp := filepicker.New()
    fp.CurrentDirectory = startPath
    fp.ShowHidden = false
    fp.DirAllowed = true
    fp.FileAllowed = true
    fp.AllowedTypes = []string{".yaml", ".yml", ".json"}

    fp.Styles.Directory = lipgloss.NewStyle().Foreground(t.Primary).Bold(true)
    fp.Styles.File = lipgloss.NewStyle().Foreground(t.Text)
    fp.Styles.Symlink = lipgloss.NewStyle().Foreground(t.Secondary)
    fp.Styles.Cursor = s.Item.Selected
    fp.Styles.Disabled = lipgloss.NewStyle().Foreground(t.DisabledText)
    fp.Styles.Permission = lipgloss.NewStyle().Foreground(t.Muted)
    fp.Styles.Selected = s.Item.Selected
    fp.Styles.FileSize = lipgloss.NewStyle().Foreground(t.Muted)

    return fp
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmd tea.Cmd
    m.filepicker, cmd = m.filepicker.Update(msg)

    if didSelect, path := m.filepicker.DidSelectFile(msg); didSelect {
        m.selectedFile = path
    }
    if didSelect, path := m.filepicker.DidSelectDisabledFile(msg); didSelect {
        m.err = fmt.Errorf("tipo de archivo no permitido: %s", path)
    }
    return m, cmd
}
```

**Vista:**

```
┌─ Seleccionar archivo de config ──────────────┐
│ 📁 ..                                          │
│ 📁 themes/                                     │
│ 📄 config.yaml                       2.1 KB    │
│ ➜ 📄 theme.yaml                       890 B     │
│ 📄 theme.json          (no permitido) 1.4 KB    │
└──────────────────────────────────────────────┘
```

---

### 5.16 FloatingPanel / Modal interactivo (overlay real con `Layer`/`Canvas`, v2)

Un "panel flotante" completo: combina `lipgloss.Layer`/`Canvas` (sección 5.12) con el `FocusManager` para que, mientras el modal está abierto, **capture el foco exclusivamente** (patrón `<Dialog modal>` de PrimeVue).

```go
package ui

import (
    "charm.land/lipgloss/v2"
    tea "charm.land/bubbletea/v2"
    "yourapp/theme"
)

// FloatingPanel representa un overlay posicionado sobre el contenido base.
type FloatingPanel struct {
    BaseComponent
    content Component // cualquier ui.Component (form, lista, mensaje, etc.)
    title   string
    x, y    int
    width   int
    height  int
    visible bool
    styles  theme.Styles
}

func NewFloatingPanel(id, title string, content Component, s theme.Styles) *FloatingPanel {
    return &FloatingPanel{
        BaseComponent: NewBase(id),
        content:       content,
        title:         title,
        styles:        s,
    }
}

// Open centra el panel sobre un canvas de tamaño (canvasW, canvasH)
// y le da el foco — capturando todos los eventos hasta que se cierre.
func (fp *FloatingPanel) Open(canvasW, canvasH int) tea.Cmd {
    fp.visible = true
    fp.width = min(60, canvasW-4)
    fp.height = min(12, canvasH-4)
    fp.x = (canvasW - fp.width) / 2
    fp.y = (canvasH - fp.height) / 2
    fp.content.SetSize(fp.width-2, fp.height-2)
    return fp.content.Focus()
}

func (fp *FloatingPanel) Close() {
    fp.visible = false
    fp.content.Blur()
}

func (fp *FloatingPanel) Visible() bool { return fp.visible }

func (fp *FloatingPanel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    if !fp.visible {
        return fp, nil
    }
    if km, ok := msg.(tea.KeyMsg); ok && km.String() == "esc" {
        fp.Close()
        return fp, nil
    }
    updated, cmd := fp.content.Update(msg)
    if c, ok := updated.(Component); ok {
        fp.content = c
    }
    return fp, cmd
}

// Render compone el contenido base con el panel flotante encima usando
// lipgloss.Layer/Canvas. Si el panel no está visible, devuelve `base` sin cambios.
func (fp *FloatingPanel) Render(base string, canvasW, canvasH int) string {
    if !fp.visible {
        return base
    }

    box := fp.styles.Panel.Focused.
        Width(fp.width).
        Height(fp.height).
        BorderForeground(fp.styles.Panel.Focused.GetBorderTopForeground())

    title := fp.styles.Title.Render(" " + fp.title + " ")
    body := title + "\n" + fp.content.View()

    background := lipgloss.NewLayer(base)
    modal := lipgloss.NewLayer(box.Render(body)).
        X(fp.x).Y(fp.y).
        Z(1)

    canvas := lipgloss.NewCanvas(background, modal)
    return canvas.Render()
}
```

**Uso en el modelo principal:**

```go
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "ctrl+d": // abrir modal de confirmación
            return m, m.confirmDialog.Open(m.width, m.height)
        }
    }

    // Si el modal está visible, captura los eventos primero
    if m.confirmDialog.Visible() {
        _, cmd := m.confirmDialog.Update(msg)
        return m, cmd
    }

    // ... resto del Update normal (paneles, tabs, etc.)
    return m, nil
}

func (m model) View() string {
    base := m.panels.View() // layout normal
    return m.confirmDialog.Render(base, m.width, m.height)
}
```

**Vista:**

```
┌─ Navegación ─────┐┌─ Servicios ──────────────────────┐
│   Item 1         ││ bos-daemon   running   2.3       │
│ ➜ Item 2         ││ kong-gateway ┏━ Confirmar ━━━━━━┓│
│   Item 3         ││ rust-svc     ┃ ¿Eliminar        ┃│
└──────────────────┘│              ┃ kong-gateway?    ┃│
                     │              ┃  [ Sí ]   [ No ] ┃│
                     │              ┗━━━━━━━━━━━━━━━━━━┛│
                     └────────────────────────────────────┘
```

`esc` cierra el modal y devuelve el foco al panel que estaba activo antes de abrirlo (guardar ese ID en `FocusManager` antes de llamar `Open`).

---

### 5.17 Toast / Notification flotante (no modal, no captura foco)

Variante ligera del `FloatingPanel`: aparece en una esquina, no bloquea interacción, y se autodestruye con un `tea.Tick`.

```go
type ToastMsg struct {
    Text   string
    Status ui.PanelStatus
}

type clearToastMsg struct{}

func showToast(text string, status ui.PanelStatus) tea.Cmd {
    return func() tea.Msg { return ToastMsg{Text: text, Status: status} }
}

func clearToastAfter(d time.Duration) tea.Cmd {
    return tea.Tick(d, func(time.Time) tea.Msg { return clearToastMsg{} })
}

// En Update:
case ToastMsg:
    m.toast = &msg
    cmds = append(cmds, clearToastAfter(3*time.Second))
case clearToastMsg:
    m.toast = nil

// En View, igual que FloatingPanel pero anclado a una esquina (X/Y fijos)
// y sin capturar Update — solo lectura visual.
```

**Vista:**

```
                                          ┌─ ✓ ──────────────┐
                                          │ Guardado con éxito│
                                          └────────────────────┘
```

---

### 5.18 Librerías complementarias para ampliar el catálogo

Más allá de `bubbles` oficiales, el ecosistema Charm tiene proyectos comunitarios con componentes adicionales listos para tematizar:

| Librería | Componentes que aporta | Notas de integración |
|---|---|---|
| **`github.com/go-go-golems/bobatea`** | `filepicker` avanzado (multi-selección, preview, jail de directorio), `listbox`, `overlay` (modal/dialog ya resuelto), `autocomplete`, `chat`, `repl`, `textarea`, `sparkline` | API similar a `bubbles`; `pkg/overlay` resuelve compositing sin necesitar v2/`Canvas` si aún estás en v1 |
| **`github.com/NimbleMarkets/ntcharts`** | gráficos: barras, líneas, área, sparkline, heatmap, gauge | Acepta `lipgloss.Style` por serie → tematizable con `t.Primary/Success/Warning/Error` directamente |
| **`github.com/charmbracelet/glamour`** | renderizado de Markdown con sintaxis resaltada | Útil para paneles de "ayuda"/"documentación" dentro de un `FloatingPanel`; soporta estilos JSON propios (`glamour.WithStylesFromJSONBytes`) compilados desde tu `theme.yaml` |
| **`github.com/charmbracelet/harmonica`** | animaciones físicas (springs) | Para transiciones suaves de paneles/modales (posición X/Y interpolada cuadro a cuadro) |
| **`charm.land/lipgloss/v2/tree`** | árboles (sección 5.14) | Ya cubierto arriba |
| **`charm.land/lipgloss/v2/table`** | tablas con wrap automático, bordes markdown/ASCII | Reemplazo recomendado de `bubbles/table` para datos con texto largo |
| **`charm.land/lipgloss/v2/list`** | listas con enumeradores personalizados (`Roman`, `Bullet`, `Tree`, custom func) | Útil para listas de solo-lectura (changelogs, pasos de wizard) sin necesidad de `bubbles/list` |

Ejemplo rápido de gráfico con `ntcharts` tematizado:

```go
import "github.com/NimbleMarkets/ntcharts/barchart"

func New(t theme.Theme) barchart.Model {
    bc := barchart.New(40, 12)
    bc.PushAll([]barchart.BarData{
        {Label: "CPU", Values: []barchart.BarValue{
            {Name: "uso", Value: 62, Style: lipgloss.NewStyle().Foreground(t.Primary)},
        }},
        {Label: "RAM", Values: []barchart.BarValue{
            {Name: "uso", Value: 81, Style: lipgloss.NewStyle().Foreground(t.Warning)},
        }},
    })
    return bc
}
```

---

```go
type model struct {
    theme   *theme.Theme
    styles  theme.Styles
    tabs    *widgets.TabBar
    panels  *ui.PanelManager
    spinner spinner.Model
    width   int
    height  int
}

func (m model) Init() tea.Cmd {
    return tea.Batch(m.spinner.Tick, tea.RequestBackgroundColor)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmds []tea.Cmd

    switch msg := msg.(type) {
    case tea.BackgroundColorMsg:
        if msg.IsDark() {
            m.theme, _ = theme.Load("themes/sbos-dark.yaml")
        } else {
            m.theme, _ = theme.Load("themes/sbos-light.yaml")
        }
        m.styles = m.theme.Styles()

    case tea.WindowSizeMsg:
        m.width, m.height = msg.Width, msg.Height
        m.panels.SetSize(m.width, m.height-3) // -3 para tabs+help

    case tea.KeyMsg:
        switch msg.String() {
        case "ctrl+c", "q":
            return m, tea.Quit
        case "ctrl+t":
            m.idx = (m.idx + 1) % len(m.themes)
            m.theme, _ = theme.Load("themes/" + m.themes[m.idx] + ".yaml")
            m.styles = m.theme.Styles()
        }
        cmds = append(cmds, m.panels.Update(msg))

    case spinner.TickMsg:
        var cmd tea.Cmd
        m.spinner, cmd = m.spinner.Update(msg)
        cmds = append(cmds, cmd)

    case tea.FocusMsg:
        // terminal recuperó foco: reanudar spinner si estaba pausado
    case tea.BlurMsg:
        // terminal perdió foco: opcionalmente pausar animaciones
    }

    return m, tea.Batch(cmds...)
}

func (m model) View() string {
    s := m.styles

    header := s.Panel.Base.Width(m.width - 2).Render(
        s.Title.Render("DevInstaller") + "  " +
            m.tabs.View() + "  " +
            m.spinner.View(),
    )

    body := m.panels.View()

    return lipgloss.JoinVertical(lipgloss.Left, header, body)
}
```

---

## 7. Buenas prácticas de theming y arquitectura

1. **Nunca** llamar `lipgloss.NewStyle()` dentro de `View()` — crear los estilos una sola vez (`Init` o constructor) y reutilizarlos.
2. Usar `lipgloss.AdaptiveColor` (v1) o `lipgloss.LightDark()` (v2) para que la app se vea bien en terminales claros y oscuros.
3. Centralizar toda la paleta en `theme.yaml` con **3 capas**: paleta primitiva → tokens semánticos → variantes por estado. Ningún color hardcodeado en componentes individuales.
4. **Todo widget interactivo implementa `ui.Component`** (Focus/Blur/SetEnabled/SetSize/ID), para integrarse al `FocusManager` sin código especial.
5. **El `FocusManager` es la única fuente de verdad sobre quién tiene foco.** Los componentes nunca deciden por sí mismos si deben procesar `tea.KeyMsg`.
6. **El `PanelManager` resuelve el layout y aplica variantes visuales según foco/estado**, evitando lógica de estilos dispersa en cada `View()`.
7. Versionar varios temas (`sbos-dark.yaml`, `sbos-light.yaml`, `sbos-highcontrast.yaml`) con `extends` para reducir duplicación, y permitir alternar con un atajo de teclado.
8. Para `huh`, derivar `huh.Theme` a partir del mismo `Theme` central — evita que los formularios "desentonen" con el resto de la TUI.
9. Detectar el fondo del terminal: en v1 con `lipgloss.HasDarkBackground()`; en v2, de forma async vía `tea.RequestBackgroundColor` + `tea.BackgroundColorMsg`.
10. Habilitar `tea.WithReportFocus()` para pausar trabajo costoso (spinners, polling) cuando la ventana del terminal pierde el foco del SO.
11. Para overlays/modales, usar `lipgloss.Layer`/`lipgloss.Canvas` (v2) en lugar de superposición manual de strings.

```go
// v1
if lipgloss.HasDarkBackground() {
    defaultTheme = "sbos-dark"
} else {
    defaultTheme = "sbos-light"
}
```

---

## 8. Mapeo conceptual: PrimeVue/Tailwind ↔ este sistema

| Concepto PrimeVue/Tailwind            | Equivalente en este sistema                              |
|----------------------------------------|-----------------------------------------------------------|
| Design tokens (`primitive`, `semantic`, `component`) | `palette` → `colors`/`states` → `Styles.Variant` (sección 2) |
| Clases `p-focus` / `focus:` (Tailwind) | `Variant.Focused`, resuelto vía `FocusManager` |
| Clases `p-disabled` / `disabled:`      | `Variant.Disabled`, `Component.SetEnabled(false)` |
| `p-invalid` / `invalid:`               | `Variant.Error` (ver `Input.Error`) |
| `<Card>` / `<Panel>`                   | `Panel` + `PanelManager` (sección 4) |
| `<TabView>`                            | `TabBar` (sección 5.10) |
| `<Tag severity="...">`                 | `Badge` variant + `PanelStatus` (sección 5.11) |
| `<Dialog>` / `<OverlayPanel>`          | `lipgloss.Layer` + `Canvas` (sección 5.12, v2) |
| Theming dinámico (`PrimeVue.changeTheme()`) | `theme.Load()` + recalcular `Styles()` en runtime |
| `:focus-within`                        | Borde de panel resuelto vía `Component.Focused()` en `PanelManager.View()` |

---

## 9. Dependencias (`go.mod`)

**Ruta v1 (estable, producción):**
```
github.com/charmbracelet/bubbletea
github.com/charmbracelet/bubbles
github.com/charmbracelet/lipgloss
github.com/charmbracelet/huh
github.com/charmbracelet/log
gopkg.in/yaml.v3
```

**Ruta v2 (en desarrollo activo, recomendado para proyectos nuevos a mediano plazo):**
```
charm.land/bubbletea/v2
charm.land/bubbles/v2
charm.land/lipgloss/v2
gopkg.in/yaml.v3
```

Opcionales (ver sección 5.18, librerías complementarias):
```
github.com/charmbracelet/glamour
github.com/charmbracelet/harmonica
github.com/NimbleMarkets/ntcharts
github.com/go-go-golems/bobatea
```

---

## 10. Catálogo final: componentes disponibles y muestra visual

Resumen de todos los componentes cubiertos en este manual, con una vista previa aproximada de cómo se ven renderizados en una terminal (usando tema `sbos-dark`).

### 10.1 Spinner

```
⠋ Instalando dependencias...
```

### 10.2 Progress

```
████████████████████░░░░░░░░░░░░░░  58%
```

### 10.3 TextInput (variantes Focused / Blurred / Error)

```
Focused:  ┌──────────────────────────────┐
          │ host-prod-01█                 │
          └──────────────────────────────┘

Blurred:  ┌──────────────────────────────┐
          │ nombre-del-host                │
          └──────────────────────────────┘

Error:    ┌──────────────────────────────┐
          │ host inválido                  │
          └──────────────────────────────┘
```

### 10.4 List (con item seleccionado)

```
Paquetes disponibles
  nginx
➜ postgresql
  redis
  rust-toolchain
/ filtrar...
```

### 10.5 Table

```
 Servicio       Estado     CPU %
 bos-daemon     running    2.3
 kong-gateway   running    5.1
 rust-svc       stopped    0.0
```
(la fila seleccionada usa `Item.Selected`: fondo `primary`, texto invertido)

### 10.6 Viewport (logs)

```
┌─ Logs ──────────────────────────────────────┐
│ [12:03:01] INFO  servicio iniciado            │
│ [12:03:02] INFO  conectando a base de datos   │
│ [12:03:03] ERROR timeout al conectar          │
│ [12:03:04] INFO  reintentando...               │
└────────────────────────────────────────────────┘
```

### 10.7 Paginator

```
● ● ○ ○ ○
```

### 10.8 Help

```
tab siguiente panel • q salir
```

### 10.9 Huh — formulario

```
? Selecciona el entorno objetivo
  > Desarrollo (144.91.76.130)
    Staging (13.140.128.230)

¿Confirmar instalación? (y/n)
```

### 10.10 TabBar

```
[ General ]  Red  Almacenamiento  Avanzado
```
(la pestaña activa usa `Tab.Selected`: fondo `primary`, negrita)

### 10.11 Badge / StatusTag

```
 running    stopped    pending
(verde)     (rojo)     (gris)
```

### 10.11.1 Button row (focus/blur consistente)

```
╭─────────╮ ╭───────────╮ ╭─────────╮ ╭─────────╮ ╭──────────╮
│ Primary │ │ Secondary │ │ Danger  │ │  Ghost  │ │ Disabled │
╰─────────╯ ╰───────────╯ ╰─────────╯ ╰─────────╯ ╰──────────╯
```
(`Primary` con foco usa `Button.Focused`: fondo `primary`, borde `FocusBorder`; el resto usa `Button.Blurred`/`Selected`/`HiddenBorder`/`Disabled` con el mismo marco y padding)

### 10.12 PanelManager — layout completo con foco

```
┌─ Navegación ─────┐┏━ Servicios ━━━━━━━━━━━━━━━━━━━━━━┓
│   Item 1         │┃ bos-daemon   running   2.3       ┃
│ ➜ Item 2         │┃ kong-gateway running   5.1       ┃
│   Item 3         │┃ rust-svc     stopped   0.0       ┃
└──────────────────┘┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
┌─ Logs ──────────────────────────────────────────────────┐
│ [12:03:04] INFO  reintentando...                          │
└─────────────────────────────────────────────────────────┘
```

El panel "Servicios" tiene foco (`FocusBorder`, borde grueso/resaltado); "Navegación" y "Logs" están en `BlurBorder` (borde tenue). Con `tab` el foco pasa a "Logs", repintando los bordes automáticamente.

### 10.13 TreePanel

```
┌─ Estructura ──────────────┐
│ ▾ proyecto/                │
│   ▾ cmd/                   │
│ ➜   main.go                │
│   ▸ internal/               │
│   go.mod                    │
└────────────────────────────┘
```

### 10.14 FilePicker

```
┌─ Seleccionar archivo ─────────────────────┐
│ 📁 themes/                                 │
│ 📁 internal/                               │
│ ➜ theme.yaml          1.2 KB               │
│   theme.dark.yaml     1.1 KB               │
│   go.mod              340 B                │
└─────────────────────────────────────────────┘
```

### 10.15 FloatingPanel / Modal (overlay sobre layout principal)

```
┌─ Navegación ─────┐┌─ Servicios ──────────────────────┐
│   Item 1         ││ bos-daemon   running   2.3       │
│ ➜ Item 2         ││ kong-gateway   ┌─ Confirmar ─────┐│
│   Item 3         ││ rust-svc       │ ¿Eliminar       ││
└──────────────────┘│                │ kong-gateway?   ││
                     │                │  [Sí]   [No]    ││
                     │                └─────────────────┘│
                     └────────────────────────────────────┘
```

### 10.16 Charts (ntcharts: sparkline / barchart)

```
CPU  ▂▃▅▇█▆▄▃▂▁▂▃▅▇█

Estado de servicios
running  ████████████████████ 8
stopped  ███ 1
pending  █ 0
```

### 10.17 Toast / Notification

```
                                          ┌─ ✓ ──────────────┐
                                          │ Guardado con éxito│
                                          └────────────────────┘
```

### 10.19 WindowManager — ventanas flotantes con title bar y eventos

```
┌─ Servicios ──────────────────────── [_][□][x] ─┐
│ bos-daemon   running   2.3                       │
│ kong-gateway running   5.1                       │
│ rust-svc     stopped   0.0                       │
└───────────────────────────────────────────────────┘
        ┌─ Logs ────────────── [_][❐][x] ─┐
        │ [12:03:04] INFO reintentando...   │
        └──────────────────────────────────────┘

[ Config ]   ← barra de tareas (ventana minimizada)
```
`ctrl+m` maximiza/restaura, `ctrl+n` minimiza a la barra de tareas, `ctrl+w` cierra (emite `ClosedMsg`), `alt+tab` cicla foco, `ctrl+g`/`ctrl+r` + flechas mueven/redimensionan.

### 10.20 GridLayout — fila superior 2 columnas + fila inferior ancho completo

```
┌─ Panel A ─────────────┐┌─ Panel B ──────────────┐
│                         ││                          │
└────────────────────────┘└──────────────────────────┘
┌─ Panel C ──────────────────────────────────────────┐
│                                                       │
└───────────────────────────────────────────────────────┘
```
Recalculado en cada `tea.WindowSizeMsg`; `TopRowRatio`/`BottomFixedHeight` controlan la proporción vertical, `TopRatios` la horizontal del bloque superior.

### 10.18 Tabla resumen

| # | Componente      | Origen                          | Soporta Focus/Blur | Variantes de tema usadas |
|---|------------------|----------------------------------|---------------------|----------------------------|
| 1 | Spinner          | `bubbles/spinner`                | vía terminal focus  | `Primary` |
| 2 | Progress         | `bubbles/progress`                | No                  | `Primary` → `Success` (gradiente) |
| 3 | TextInput / TextField | `bubbles/textinput` + `ui.Component` | Sí           | `Input.{Focused,Blurred,Error,Disabled}` + sub-estilos (`Prompt/Text/Placeholder/Cursor`) con `Background`/`BorderBackground` = `t.Surface` (5.3.1) |
| 4 | List             | `bubbles/list`                    | Sí (vía FocusManager) | `Item.{Base,Selected}`, `Title`, `Subtitle` |
| 5 | Table            | `bubbles/table` / `lipgloss/v2/table` | Sí              | `Item.Selected`, `Border` |
| 6 | Viewport         | `bubbles/viewport`                | Sí                  | `Panel.{Focused,Blurred}` |
| 7 | Paginator        | `bubbles/paginator`               | No                  | `Primary`, `Muted` |
| 8 | Help             | `bubbles/help`                    | No                  | `Primary`, `Muted` |
| 9 | Form (Huh)       | `huh`                              | Sí (interno)        | tema derivado completo |
| 10 | TabBar          | custom (sección 5.10)             | Sí                  | `Tab.{Base,Selected,Disabled}` |
| 11 | Badge/StatusTag | custom (sección 5.11)             | No                  | `Badge.{Base,Selected,Error}` |
| 11.1 | Button (row) | custom (secciones 5.11.1–5.11.3)  | Sí (vía FocusManager) | `Button.{Base,Focused,Blurred,Disabled,Selected,Error}` con `Background`/`BorderBackground` = `t.Surface` |
| 12 | Panel/PanelManager | custom (sección 4)             | Sí (orquesta todo)  | `Panel.{Focused,Blurred,Disabled}`, `PanelStatus` |
| 13 | TreePanel        | `lipgloss/tree` + custom (5.14)    | Sí                  | `Item.{Base,Selected}`, `Title`, `Muted`, `Panel` |
| 14 | FilePicker       | `bubbles/filepicker` / `bobatea/filepicker` (5.15) | Sí (interno) | `Item.Selected`, `Primary`, `Secondary`, `Muted`, `DisabledText` |
| 15 | FloatingPanel/Modal | custom sobre `Layer`/`Canvas` (5.16) | Sí (captura foco) | `Panel.Focused`, `Title` |
| 16 | Toast/Notification | custom (5.17)                   | No (no captura foco) | `Badge.{Selected,Error}` según `PanelStatus` |
| 17 | Charts (sparkline/bar/line) | `NimbleMarkets/ntcharts` (5.18) | No              | `Primary`, `Success`, `Warning`, `Error` por serie |
| 18 | Markdown viewer  | `charmbracelet/glamour` (5.18)      | Sí (si va en `viewport`) | tema JSON derivado de `theme.yaml` |
| 19 | Listbox/Autocomplete/Chat/REPL | `bobatea` (5.18)        | Sí                  | tematizables vía `lipgloss.Style` |
| 20 | WindowManager (ventanas flotantes) | custom sobre `Layer`/`Canvas` (4.5) | Sí (z-order + ciclo alt+tab) | `Panel.{Focused,Blurred}`, `Title`, `Subtitle`, `Tab.Base` (taskbar) |
| 21 | GridLayout (paneles anclados responsive) | custom (4.4)         | delega a cada panel | `Panel.{Focused,Blurred,Disabled}` por celda |
| 22 | Densidad compacta / bordes compartidos | custom (4.7) — `Theme.Density` + `SharedBorderStyle` | N/A | `Panel/Input/Button` con `panelPadding/inputPadding/buttonPadding` |

---

## 11. Roadmap sugerido para una aplicación robusta

Para llevar este sistema a una aplicación TUI completa (tipo dashboard de administración), el orden recomendado de implementación es:

1. **Fundaciones**: `theme.yaml` con las 3 capas (sección 2), carga + `Styles()`.
2. **Núcleo de composición**: `ui.Component`, `BaseComponent`, `FocusManager` (sección 3).
3. **Layout**: `PanelManager`/`GridLayout` con al menos 2-3 zonas fijas (sidebar, main, footer/logs), recalculadas en `tea.WindowSizeMsg` (secciones 4, 4.4).
4. **Componentes de datos**: `Table`, `List`, `Viewport` para mostrar información real.
5. **Navegación jerárquica**: `TreePanel` para árboles de configuración/recursos, `FilePicker` para selección de archivos (5.14–5.15).
6. **Interacción del usuario**: `TextField`, formularios `huh`, `TabBar`, `Button` (5.10–5.11.2).
7. **Feedback visual**: `Badge`/`StatusTag`, `Toast`, `Progress`, `Spinner`.
8. **Overlays simples**: `FloatingPanel`/Modal con `Layer`/`Canvas` para confirmaciones y diálogos críticos (5.16).
9. **Ventanas flotantes completas**: `WindowManager` con title bar, close/move/resize/maximize/minimize y barra de tareas (4.5–4.6), si la app necesita paneles desacoplables tipo gestor de ventanas.
10. **Extras según necesidad**: gráficos (`ntcharts`), Markdown (`glamour`), chat/REPL (`bobatea`).
11. **Pulido**: animaciones con `harmonica`, detección de fondo (`BackgroundColorMsg`), `tea.WithReportFocus()` para pausar trabajo en background.

Cada punto puede desarrollarse y probarse de forma incremental sin romper los anteriores, porque todos los componentes comparten el mismo contrato (`ui.Component`) y la misma fuente de estilos (`theme.Styles`).

---

## 12. Apéndice: manejo de color profile — con y sin tmux, vía SSH

Un problema muy común al desplegar una TUI en producción: **los colores se ven "lavados" o desaturados** comparado con el diseño en `theme.yaml`, porque la app, la terminal, el multiplexor (tmux) y/o SSH negocian un perfil de color distinto al esperado (truecolor de 16M colores → degradado a 256 → degradado a 16 ANSI).

### 12.1 Diagnóstico — los 3 puntos de pérdida

```
[ Terminal local ] ──SSH──> [ Shell remoto ] ──> [ tmux opcional ] ──> [ tu app Go ]
      (1)                        (2)                   (3)                 (4)
```

En cualquiera de estos 4 puntos se puede perder fidelidad de color. Comandos de diagnóstico, de adentro hacia afuera:

```bash
# 4. ¿Qué perfil detecta tu app? (agregar temporalmente en main.go)
fmt.Fprintln(os.Stderr, "ColorProfile:", lipgloss.ColorProfile())
# 0=Ascii 1=ANSI(16) 2=ANSI256 3=TrueColor

# 3. ¿tmux tiene el flag Tc (truecolor)?
tmux info | grep -i Tc

# 2. ¿Qué variables ve el shell remoto?
echo $TERM        # xterm-256color, tmux-256color, etc.
echo $COLORTERM   # debería decir "truecolor"

# 1. ¿El terminal local realmente renderiza truecolor?
printf "\x1b[38;2;255;100;0mtest truecolor\x1b[0m\n"
```

Si el `printf` del punto 1 no se ve naranja real (sino un naranja "aproximado" de 256 colores), **el límite está en el emulador de terminal local** y nada en el servidor/app lo puede arreglar — hay que cambiar de terminal o habilitar truecolor en su configuración.

Si el `printf` se ve bien pero `ColorProfile()` reporta `2` (ANSI256), el problema está entre los puntos 2-4: la información de "soy truecolor" no está llegando a tu app.

---

### 12.2 Escenario A — SSH directo, SIN tmux

**Causa más común:** SSH **no propaga `$COLORTERM`** del cliente al servidor por defecto (a diferencia de `$TERM`, que normalmente sí viaja en la negociación de la pty). Tu terminal local soporta truecolor, pero la sesión remota no se entera.

#### Solución 1 — propagar `$COLORTERM` vía SSH (recomendada, una vez)

**Cliente** (`~/.ssh/config`):
```
Host mi-servidor
    SendEnv COLORTERM
```

**Servidor** (`/etc/ssh/sshd_config`, requiere `systemctl restart sshd` o equivalente):
```
AcceptEnv COLORTERM
```

Reconectar y verificar `echo $COLORTERM` → debe decir `truecolor`.

> Si no tienes acceso root al servidor para tocar `sshd_config`, usa la Solución 2.

#### Solución 2 — exportar la variable manualmente en la sesión remota

Workaround inmediato, sin tocar configuración de SSH:

```bash
export COLORTERM=truecolor
./mi-app-tui
```

O en una sola línea:

```bash
COLORTERM=truecolor ./mi-app-tui
```

#### Solución 3 — forzar el perfil de color desde el código Go (sin depender del entorno)

Si controlas el binario y quieres garantizar truecolor sin importar cómo llegue la sesión (útil para distribuir un binario a usuarios que no controlan su `sshd_config`):

**v1:**
```go
import (
    "github.com/charmbracelet/lipgloss"
    "github.com/muesli/termenv"
)

func init() {
    lipgloss.SetColorProfile(termenv.TrueColor)
}
```

**v2 (uso fuera de `tea.Program`, p.ej. en CLIs que imprimen con `lipgloss.Println`):**
```go
import "github.com/charmbracelet/colorprofile"

// en vez de colorprofile.Detect(os.Stdout, os.Environ()),
// que puede devolver Ansi256 si $COLORTERM no llegó:
profile := colorprofile.TrueColor
style := lipgloss.NewStyle().Foreground(profile.Convert(lipgloss.Color("#7AA2F7")))
```

**v2 dentro de `tea.Program`:** el perfil se detecta automáticamente al iniciar el programa a partir del entorno de la sesión (que ya debería tener `COLORTERM=truecolor` por la Solución 1 o 2). No suele requerir forzado adicional si las variables de entorno llegan correctamente.

> **Cuidado al forzar truecolor incondicionalmente:** si el binario se ejecuta en un entorno que de verdad solo soporta 256 colores (p. ej. una terminal antigua sin SSH de por medio), forzar `TrueColor` no "mejora" nada — simplemente lipgloss enviará secuencias ANSI truecolor que esa terminal no entiende, mostrando caracteres basura o colores incorrectos. La Solución 3 es apropiada cuando **sabes** que el terminal cliente soporta truecolor pero el entorno no lo está reportando (caso típico de SSH); no es un "arreglalo todo" universal.

---

### 12.3 Escenario B — SSH + tmux

tmux agrega una capa adicional de negociación: aunque `$COLORTERM=truecolor` llegue correctamente al shell remoto, **tmux por defecto no reenvía truecolor a las apps que corren dentro de sus paneles**, a menos que se configure explícitamente.

#### Verificar si tmux está limitando

```bash
tmux info | grep -i Tc
```

- Si aparece `Tc: (flag) true` → tmux está pasando truecolor correctamente.
- Si no aparece, o aparece `Tc: (flag) false` → tmux está limitando a 256 colores, sin importar lo que haga tu app Go.

#### Solución — habilitar `Tc` en `~/.tmux.conf`

```bash
# tmux >= 3.2 (recomendado)
set -as terminal-features ",xterm-256color:RGB"

# tmux < 3.2 (sintaxis anterior)
set -ag terminal-overrides ",xterm-256color:RGB"
```

Ajusta `xterm-256color` al valor real de `$TERM` fuera de tmux (verifica con `echo $TERM` **antes** de entrar a tmux). Recarga la config:

```bash
tmux source-file ~/.tmux.conf
```

Y vuelve a verificar `tmux info | grep -i Tc` dentro de una sesión nueva.

#### Caso SSH + tmux combinados

El orden de aplicación de soluciones es:

1. **SSH** debe propagar `$COLORTERM` (Escenario A, Solución 1 o 2) — esto afecta al *shell* dentro de tmux.
2. **tmux** debe tener `Tc` habilitado (esta sección) — esto afecta a lo que tmux *reenvía* a tu app dentro de sus paneles.
3. Si después de 1 y 2 los colores siguen mal, recurre a la Solución 3 de 12.2 (forzar perfil en el código Go) como último recurso, sabiendo la salvedad sobre terminales que no soportan truecolor.

#### `screen` (si aplica)

Si en lugar de/además de tmux usas `screen`, ten en cuenta que `screen` es mucho más restrictivo y en muchas versiones **no soporta truecolor en absoluto**, limitando a 256 colores sin posibilidad de configuración equivalente a `Tc`. Si tu paleta depende de truecolor, considera migrar de `screen` a tmux.

---

### 12.4 Resumen — árbol de decisión

```
¿printf con secuencia truecolor se ve bien en tu terminal LOCAL?
├─ NO  → el límite es el emulador de terminal local; cambiar de
│        terminal o habilitar truecolor en su configuración.
│        Nada del lado servidor/app puede compensar esto.
│
└─ SÍ  → ¿estás vía SSH?
         ├─ SÍ → ¿echo $COLORTERM dice "truecolor" en la sesión remota?
         │       ├─ NO → Escenario A: SendEnv/AcceptEnv (sol. 1)
         │       │       o exportar manualmente (sol. 2)
         │       └─ SÍ → ¿usas tmux?
         │               ├─ SÍ → tmux info | grep Tc
         │               │       ├─ false → habilitar Tc (12.3)
         │               │       └─ true  → revisar AdaptiveColor /
         │               │                   HasDarkBackground (sección 2.4)
         │               └─ NO → revisar ColorProfile() en tu app (12.2 sol. 3)
         │
         └─ NO  → revisar ColorProfile() y AdaptiveColor directamente
                  (entorno local, sección 2.4)
```

Además de la negociación de color, recuerda revisar **`lipgloss.HasDarkBackground()`** (sección 2.4): incluso con truecolor funcionando perfectamente, un `AdaptiveColor{Light, Dark}` que detecta el fondo equivocado mostrará la variante de color incorrecta para tu terminal, lo cual también puede percibirse como "colores distorsionados" aunque la fidelidad de color en sí sea correcta.

---

## 13. Apéndice: auditoría del componente `Button` — eventos, mouse, teclado y contenedor robusto

Esta sección audita una implementación real de `button.Model` (paquete propio sobre `bubblezone` + `bubbletea`) contra el patrón ARIA **Button** del W3C (`w3.org/WAI/ARIA/apg/patterns/button`) y las convenciones estándar de mouse/teclado en TUIs, identificando gaps y proponiendo el código corregido. Sirve como checklist para cualquier componente interactivo del design system, no solo `Button`.

### 13.1 Lo que la implementación ya hace bien

1. **Ciclo de press en 2 fases** (`BeforePress` → confirmación → `Press` → flash → `AfterPress`) con posibilidad de cancelar — equivalente a `preventDefault()` en el patrón web.
2. **Mouse y teclado unificados**: tanto `MouseActionRelease` como `enter`/`" "` (Espacio) llegan al mismo `confirmPress()` — esto **coincide exactamente** con el patrón ARIA Button, que especifica que tanto `Enter` como `Space` deben activar el botón.
3. **Cancelación al soltar fuera del botón** (`!zone.Get(b.ID).InBounds(msg)` → `b.pressed = false` sin disparar `OnPress`) — replica el comportamiento nativo de un `<button>` HTML, donde un mouseup fuera del elemento no dispara `click`.
4. **Separación `render()` (sin marcador de zona) vs `View()` (con marcador)** para que `MaxWidth`/medición de ancho no se vean afectadas por los bytes invisibles que inyecta `zone.Mark` — detalle correcto y fácil de pasar por alto.
5. **`Disabled` ignora todos los eventos** en `Update()` y `Focus()` — correcto a nivel de comportamiento.

### 13.2 Gaps identificados frente al patrón ARIA Button y convenciones de TUI

#### Gap 1 — Disabled debería seguir siendo *focusable* (APG: "determining when to make disabled interactive elements focusable")

La guía APG del W3C señala explícitamente que hay que **decidir deliberadamente** si un elemento deshabilitado debe permanecer en el orden de foco. La implementación actual hace `Focus()` un no-op para `Disabled`, lo cual **saca completamente el botón del flujo de navegación** — un usuario que navega con `tab` no puede ni siquiera saber que ese botón existe y está deshabilitado, ni leer su tooltip/razón.

**Recomendación:** permitir el foco visual en `Disabled` (para que el `FocusManager` lo incluya y el usuario vea "este botón existe pero está apagado"), pero seguir bloqueando la activación:

```go
func (b *Model) Focus() tea.Cmd {
    b.focused = true // SIEMPRE permite foco visual, incluso Disabled
    return nil
}

// La activación sigue bloqueada en Update() — esto ya está correcto:
func (b *Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    if b.Variant == Disabled {
        return b, nil // no procesa press, pero SÍ puede tener foco
    }
    // ...
}
```

#### Gap 2 — Falta el evento `Hover`/`MouseActionMotion` (equivalente a `:hover` CSS)

La implementación solo distingue `MouseActionPress`/`MouseActionRelease`. Con `tea.WithMouseCellMotion()` ya habilitado (requisito documentado en el paquete), también llegan eventos `tea.MouseActionMotion` — sin manejarlos, el botón no puede dar feedback visual al pasar el mouse por encima sin hacer click, que es una expectativa estándar de cualquier UI con mouse.

```go
// Agregar al Model:
type Model struct {
    // ... campos existentes
    hovered bool
}

// En Update(), dentro del case tea.MouseMsg:
case tea.MouseMsg:
    inBounds := zone.Get(b.ID).InBounds(msg)
    b.hovered = inBounds // actualizar SIEMPRE, no solo en press/release

    if !inBounds {
        b.pressed = false
        return b, nil
    }
    switch msg.Action {
    case tea.MouseActionMotion:
        return b, nil // ya actualizamos hovered arriba; sin más efecto
    case tea.MouseActionPress:
        // ... igual que antes
    case tea.MouseActionRelease:
        // ... igual que antes
    }
```

```go
// styleFor: agregar precedencia Hovered (entre Blurred y Focused)
func (b Model) styleFor() lipgloss.Style {
    s := b.blurred
    if b.hovered && !b.focused {
        s = s.Copy() // variante hover si existe en el paquete styles, o reusar Focused atenuado
    }
    if b.focused {
        s = b.focused_
    }
    if b.pressed {
        s = s.Reverse(true)
    }
    return s
}
```

> Si no quieres agregar una variante visual `Hover` separada en `styles` (sección 2.3), como mínimo expón `Hovered() bool` para que el screen pueda mostrar un tooltip/status bar con la descripción del botón bajo el cursor — un patrón común en TUIs con mouse (`htop`, `k9s`).

#### Gap 3 — No hay atajo de teclado *directo* (mnemonic) sin requerir foco previo

El botón solo responde a `enter`/`" "` **cuando ya tiene foco** (`if !b.focused { return b, nil }`). Esto es correcto para el patrón base de ARIA Button, pero una TUI profesional (y la mayoría de gestores con mouse+teclado como `k9s`, `lazygit`) típicamente añade **mnemonics**: una tecla que activa el botón sin necesidad de tabular hasta él (p. ej. `ctrl+s` para "Guardar", o subrayar la primera letra del label y permitir `alt+<letra>`).

```go
// Agregar al Model:
type Model struct {
    // ... campos existentes
    Shortcut string // p.ej. "ctrl+s" — vacío si no aplica
}

// En Update(), ANTES de chequear b.focused, para que funcione sin foco previo:
case tea.KeyMsg:
    if b.Variant != Disabled && b.Shortcut != "" && msg.String() == b.Shortcut {
        before := b.beforePress()
        if !b.pressed {
            return b, before
        }
        return b, tea.Batch(before, b.confirmPress())
    }
    if !b.focused {
        return b, nil
    }
    switch msg.String() {
    case "enter", " ":
        // ... código existente
    }
```

```go
// render(): mostrar el shortcut como hint visual, común en TUIs (k9s, lazygit)
// p.ej. "[s] Guardar" en vez de solo "Guardar"
func (b Model) render() string {
    label := b.Label
    if b.Shortcut != "" {
        label = styles.Muted.Render("["+shortcutHint(b.Shortcut)+"] ") + label
    }
    // ... resto igual
}
```

> **Cuidado con colisiones de atajos**: si varios botones visibles simultáneamente declaran el mismo `Shortcut`, gana ambigüedad. El `FocusManager`/`WindowManager` (secciones 3.3/4.5) debería validar unicidad de shortcuts al registrar componentes, similar a cómo un menú nativo evita mnemonics duplicados en el mismo nivel.

#### Gap 4 — Doble-click / doble-activación accidental no está protegida

El ciclo `beforePress → confirmPress` no tiene protección contra una segunda activación mientras la primera sigue "en vuelo" (por ejemplo, si `OnPress` dispara una operación async lenta y el usuario presiona `Enter` repetidamente). Esto puede causar múltiples `PressedMsg` para una sola intención del usuario — un problema real en botones tipo "Eliminar"/"Confirmar pago".

```go
// Agregar guard: mientras pressed==true, ignorar nuevas activaciones
case tea.KeyMsg:
    // ... chequeo de shortcut/focused
    switch msg.String() {
    case "enter", " ":
        if b.pressed {
            return b, nil // ya hay un press en curso (flash visual activo) — ignorar
        }
        before := b.beforePress()
        if !b.pressed {
            return b, before
        }
        return b, tea.Batch(before, b.confirmPress())
    }
```

```go
case tea.MouseActionPress:
    if msg.Button != tea.MouseButtonLeft || b.pressed {
        return b, nil // guard idéntico para mouse
    }
    return b, b.beforePress()
```

#### Gap 5 — `SetWidth` usa `.Copy()` que está deprecado en lipgloss reciente; y no hay mínimo de ancho

`lipgloss.Style.Copy()` fue removido en versiones recientes de lipgloss v1 (los `Style` son inmutables y se copian automáticamente al encadenar métodos) — si tu `go.mod` resuelve a una versión donde `Copy()` no existe más, este código no compila. Además, `SetWidth(0)` (usado en `MaxWidth` para "reset") puede colapsar el botón si `Width(0)` se interpreta como "sin restricción de ancho" en vez de "ancho cero" según la versión de lipgloss.

```go
// Versión segura sin .Copy() — los Style de lipgloss son value types,
// asignar devuelve una copia automáticamente.
func (b *Model) SetWidth(w int) {
    if w <= 0 {
        return // evitar Width(0) ambiguo; "sin override" = no tocar el estilo
    }
    b.blurred = b.blurred.Width(w)
    b.focused_ = b.focused_.Width(w)
}
```

```go
// MaxWidth: no llamar SetWidth(0) para "reset" — medir el label crudo
// con el estilo SIN width forzado, usando una copia temporal sin mutar b.
func MaxWidth(buttons []*Model) int {
    maxW := 0
    for _, b := range buttons {
        w := lipgloss.Width(b.render()) // render() ya refleja el estilo actual SIN forzar reset
        if w > maxW {
            maxW = w
        }
    }
    return maxW
}
```

#### Gap 6 — Falta `OnFocus`/`OnBlur` hooks (paridad con `OnBeforePress`/`OnPress`/`OnAfterPress`)

El componente expone hooks ricos para el ciclo de press, pero `Focus()`/`Blur()` no notifican al exterior. Para un design system robusto (p. ej. mostrar ayuda contextual en una status bar cuando el foco entra a un botón), conviene paridad:

```go
type Model struct {
    // ... campos existentes
    OnFocus func() tea.Cmd
    OnBlur  func() tea.Cmd
}

func (b *Model) Focus() tea.Cmd {
    b.focused = true
    if b.OnFocus != nil {
        return b.OnFocus()
    }
    return nil
}

func (b *Model) Blur() tea.Cmd {
    b.focused = false
    b.pressed = false
    if b.OnBlur != nil {
        return b.OnBlur()
    }
    return nil
}
```

> **Nota de compatibilidad:** esto cambia la firma de `Blur()` de `func()` a `func() tea.Cmd`, lo cual rompe la interfaz `ui.Component` de la sección 3.1, que define `Blur()` sin retorno. Si decides adoptar este patrón, actualiza también `ui.Component`/`BaseComponent` (sección 3.1) para que `Blur()` devuelva `tea.Cmd`, y propaga el cambio a `FocusManager.move()` (sección 3.3), que actualmente descarta el resultado de `Blur()` — deberá agregarlo a su `tea.Batch`.

#### Gap 7 — Toggle buttons (equivalente a `aria-pressed`) no están modelados

El patrón ARIA Button define explícitamente un segundo tipo: **toggle button** (dos estados, on/off, p. ej. un botón "Mute" o "Pausar/Reproducir"), donde el label **no debe cambiar** entre estados (solo el indicador visual/`aria-pressed`). El `Variant` actual no distingue press momentáneo de estado persistente.

```go
type Model struct {
    // ... campos existentes
    IsToggle bool // si true, Pressed() es persistente hasta el siguiente toggle
    toggled  bool
}

func (b *Model) confirmPress() tea.Cmd {
    if b.IsToggle {
        b.toggled = !b.toggled
        // el flash visual NO debe revertir el estado — solo dar feedback
        // de que el click se registró; el estilo "on" se mantiene vía Toggled()
    }
    // ... resto igual (emitir PressedMsg, etc.)
}

func (b Model) Toggled() bool { return b.toggled }

// styleFor: para toggle buttons, el estado "on" debe persistir más allá
// del flash de 120ms — usar b.toggled en vez de (o además de) b.pressed
// para decidir si aplicar el estilo "activo".
```

### 13.3 Contenedor robusto: por qué "es una representación de texto" y cómo no se deforma

El pedido original — "dotarle de un contenedor para que no se derrumbe por ser una representación de texto" — apunta al problema ya cubierto en 5.11.1/5.11.2/5.11.3: como el botón es *texto renderizado*, no un objeto con layout real, **toda** garantía de tamaño/alineación depende de que el `Style.Render()` sea la única fuente de verdad sobre la geometría. Aplicado a este paquete:

1. **`blurred`/`focused_` deben compartir exactamente el mismo `Border`+`Padding`+`Background`+`BorderBackground`** entre todas las variantes (`Primary`, `Secondary`, `Danger`, etc.) — si `styles.BtnGhost` usa un borde distinto a `styles.BtnPrimary`, el catálogo entero vuelve a deformarse como en las capturas anteriores. Auditar `styles.Btn*` contra la regla de 5.11.1.
2. **El `Reverse(true)` del estado `Pressed` no debe cambiar el ancho/alto** — `Reverse()` en lipgloss solo invierte fg/bg, no toca el `Border`/`Padding`, así que es seguro en este sentido; confirmar que ninguna variante en `styles` agregue `Bold()`/cambios de fuente que alteren el ancho percibido (en TUI no cambia columnas, pero sí puede verse "más grueso" visualmente de forma inconsistente).
3. **`SetWidth` debe aplicarse a AMBAS variantes (`blurred` Y `focused_`) simultáneamente** — el código ya lo hace correctamente; es el patrón correcto para que el botón no cambie de ancho al enfocar (mismo principio que el cursor de 5.11.2, pero a nivel de todo el componente).
4. **El wrapping del label dentro de `Render()`** — si `Label` viene de fuera (configurable) y es más largo que el ancho fijado por `SetUniformWidth`, lipgloss truncará o hará wrap según el comportamiento de `Width()` con contenido más largo que el límite. Si no quieres wrap (que rompería la altura fija de 3 líneas), considera truncar manualmente con elipsis antes de pasar a `Render()`:

```go
func truncateLabel(label string, maxWidth int) string {
    if lipgloss.Width(label) <= maxWidth {
        return label
    }
    // Recorta por runas, no por bytes, para no partir caracteres UTF-8/emoji
    runes := []rune(label)
    for len(runes) > 0 && lipgloss.Width(string(runes)+"…") > maxWidth {
        runes = runes[:len(runes)-1]
    }
    return string(runes) + "…"
}
```

### 13.4 Checklist final — eventos completos de un `Button` robusto

| Evento | ¿Cubierto en el código original? | Acción |
|---|---|---|
| Click completo (mouse down + up dentro del botón) | Sí | — |
| Activación por teclado (`Enter`/`Espacio` con foco) | Sí | — |
| Cancelación al soltar mouse fuera del botón | Sí | — |
| `BeforePress` cancelable | Sí | — |
| Flash visual tras press (`Pressed` temporal) | Sí | — |
| `AfterPress` al terminar el flash | Sí | — |
| Foco visual en estado `Disabled` (APG) | **No** | Gap 1 |
| Hover / `MouseActionMotion` | **No** | Gap 2 |
| Atajo de teclado sin foco previo (mnemonic) | **No** | Gap 3 |
| Guard contra doble-activación mientras hay un press en curso | **No** | Gap 4 |
| Compatibilidad de `.Copy()` con lipgloss reciente | **Riesgo** | Gap 5 |
| `OnFocus`/`OnBlur` hooks (paridad con hooks de press) | **No** | Gap 6 |
| Toggle button (`aria-pressed` persistente) | **No** | Gap 7 |
| Truncado seguro de label largo (sin romper altura fija) | **No** | 13.3.4 |
| Ancho uniforme entre variantes (`Blurred`/`Focused`) | Sí | — |
| Borde/padding/fondo consistentes entre variantes (5.11.1–5.11.3) | Depende del paquete `styles` — auditar | 13.3.1 |

### 13.5 Referencia: patrón ARIA Button (W3C) aplicado a TUI

| Convención ARIA Button | Equivalente en `button.Model` |
|---|---|
| `Space`/`Enter` activan el botón con foco | `case "enter", " "` en `Update()` |
| Tras activar, el foco se mueve según el efecto (abre diálogo → foco al diálogo; cierra diálogo → foco vuelve al invocador) | Responsabilidad del **screen**/`WindowManager` que escucha `PressedMsg`, no del botón en sí — documentar esta responsabilidad en cada uso |
| Toggle button: `aria-pressed`, label no cambia entre estados | Gap 7 — campo `IsToggle`/`Toggled()` |
| Elementos deshabilitados: decisión deliberada sobre si son focusables | Gap 1 |
| Nombre accesible = contenido o `aria-label` | Equivalente conceptual: `Label` siempre visible (TUI no tiene "accesible vs visual" separado, son lo mismo) |

---

## 14. Referencias

- Lip Gloss v2 — guía de migración y novedades (compositing, `LightDark`, `HasDarkBackground`): `github.com/charmbracelet/lipgloss/blob/main/UPGRADE_GUIDE_V2.md`
- Bubble Tea — `FocusMsg`/`BlurMsg`, `WithReportFocus`, `BackgroundColorMsg`: `pkg.go.dev/charm.land/bubbletea/v2`
- Patrón de foco multi-input (ejemplo oficial `textinputs`): `github.com/charmbracelet/bubbletea/blob/main/examples/textinputs/main.go`
- Lip Gloss v2 Beta 2 — compositing con `Layer`/`Canvas`: `charm.land/blog/lipgloss-v2-beta-2`

---

## 15. Tutorial: de cero a una mini-app funcional

Este tutorial recorre, paso a paso, cómo armar una aplicación pequeña pero completa usando las piezas del manual: tema centralizado, `FocusManager`, dos paneles, un `TextField` y una fila de `Button`. Al final tendrás un binario que corre, se ve coherente, y reacciona a teclado y `tea.WindowSizeMsg`. Cada paso compila por sí solo — puedes detenerte en cualquier punto y tener algo funcional.

### 15.0 Requisitos previos

```bash
go version   # Go 1.21+ recomendado
mkdir mi-tui && cd mi-tui
go mod init mi-tui

go get github.com/charmbracelet/bubbletea
go get github.com/charmbracelet/bubbles
go get github.com/charmbracelet/lipgloss
go get gopkg.in/yaml.v3
```

> Esta ruta usa la API v1 (estable). Si prefieres v2, sustituye los imports por `charm.land/bubbletea/v2`, `charm.land/bubbles/v2`, `charm.land/lipgloss/v2` y ajusta según las notas de la sección 1.

### 15.1 Paso 1 — Estructura de carpetas

```
mi-tui/
├── go.mod
├── main.go
├── theme/
│   └── theme.go
├── themes/
│   └── dark.yaml
└── ui/
    ├── component.go      (interfaz Component + BaseComponent, sección 3.1)
    └── focusmanager.go    (FocusManager, sección 3.3)
```

### 15.2 Paso 2 — El theme mínimo

Crea `themes/dark.yaml` con una versión reducida del ejemplo de la sección 2.1 — solo lo necesario para este tutorial:

```yaml
name: "tutorial-dark"

colors:
  primary:    { light: "#3B5BDB", dark: "#7AA2F7" }
  text:       { light: "#212529", dark: "#C0CAF5" }
  muted:      { light: "#868E96", dark: "#565F89" }
  surface:    { light: "#F8F9FA", dark: "#16161E" }
  error:      { light: "#C92A2A", dark: "#F7768E" }

states:
  focusBorder: { light: "#3B5BDB", dark: "#7AA2F7" }
  blurBorder:  { light: "#CED4DA", dark: "#3B4261" }
  selectionFg: { light: "#FFFFFF", dark: "#1A1B26" }
```

Crea `theme/theme.go` (versión reducida de la sección 2.2 + 2.3, solo los campos que usaremos):

```go
package theme

import (
	"os"

	"github.com/charmbracelet/lipgloss"
	"gopkg.in/yaml.v3"
)

type ColorPair struct {
	Light string `yaml:"light"`
	Dark  string `yaml:"dark"`
}

type config struct {
	Name   string               `yaml:"name"`
	Colors map[string]ColorPair `yaml:"colors"`
	States map[string]ColorPair `yaml:"states"`
}

type Theme struct {
	Primary, Text, Muted, Surface, Error             lipgloss.AdaptiveColor
	FocusBorder, BlurBorder, SelectionFg lipgloss.AdaptiveColor
}

func Load(path string) (*Theme, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}

	get := func(m map[string]ColorPair, key string) lipgloss.AdaptiveColor {
		c := m[key]
		return lipgloss.AdaptiveColor{Light: c.Light, Dark: c.Dark}
	}

	return &Theme{
		Primary:     get(cfg.Colors, "primary"),
		Text:        get(cfg.Colors, "text"),
		Muted:       get(cfg.Colors, "muted"),
		Surface:     get(cfg.Colors, "surface"),
		Error:       get(cfg.Colors, "error"),
		FocusBorder: get(cfg.States, "focusBorder"),
		BlurBorder:  get(cfg.States, "blurBorder"),
		SelectionFg: get(cfg.States, "selectionFg"),
	}, nil
}

// Variant agrupa estilos de un mismo tipo de elemento por estado
// (ver sección 2.3 para la versión completa con Panel/Input/Item/Tab/Badge).
type Variant struct {
	Base, Focused, Blurred, Disabled lipgloss.Style
}

func (v Variant) Resolve(focused, disabled bool) lipgloss.Style {
	switch {
	case disabled:
		return v.Disabled
	case focused:
		return v.Focused
	default:
		return v.Blurred
	}
}

type Styles struct {
	Title lipgloss.Style
	Panel Variant
	Input Variant
}

func (t Theme) Styles() Styles {
	border := lipgloss.RoundedBorder()

	panel := Variant{
		Base: lipgloss.NewStyle().Border(border).BorderForeground(t.BlurBorder).
			BorderBackground(t.Surface).Background(t.Surface).Padding(0, 1),
		Focused: lipgloss.NewStyle().Border(border).BorderForeground(t.FocusBorder).
			BorderBackground(t.Surface).Background(t.Surface).Padding(0, 1),
		Blurred: lipgloss.NewStyle().Border(border).BorderForeground(t.BlurBorder).
			BorderBackground(t.Surface).Background(t.Surface).Padding(0, 1),
		Disabled: lipgloss.NewStyle().Border(border).BorderForeground(t.Muted).
			BorderBackground(t.Surface).Background(t.Surface).Padding(0, 1).Foreground(t.Muted),
	}

	input := Variant{
		Focused: lipgloss.NewStyle().Foreground(t.Text).Background(t.Surface).
			Border(lipgloss.NormalBorder()).BorderForeground(t.FocusBorder).BorderBackground(t.Surface),
		Blurred: lipgloss.NewStyle().Foreground(t.Muted).Background(t.Surface).
			Border(lipgloss.NormalBorder()).BorderForeground(t.BlurBorder).BorderBackground(t.Surface),
	}

	return Styles{
		Title: lipgloss.NewStyle().Bold(true).Foreground(t.Primary),
		Panel: panel,
		Input: input,
	}
}
```

**Checkpoint:** en este punto nada compila aún porque no hay `main.go`, pero el paquete `theme` ya es válido por sí solo. Si tienes Go instalado, corre `go build ./theme/...` para confirmarlo antes de seguir.

### 15.3 Paso 3 — `ui.Component` y `FocusManager` (versión mínima)

Copia las versiones de la sección 3.1 y 3.3 del manual a `ui/component.go` y `ui/focusmanager.go` tal cual están — no requieren cambios para este tutorial. Si prefieres no copiarlas ahora, este paso es opcional: puedes empezar con un solo componente sin `FocusManager` y agregarlo en el paso 6.

### 15.4 Paso 4 — Un `main.go` mínimo: ventana + tema, sin componentes todavía

Primero, lo más simple posible: que la app abra, cargue el tema, y muestre un panel vacío que reacciona a `tea.WindowSizeMsg`. Esto confirma que el wiring básico de bubbletea + lipgloss + theme funciona antes de agregar complejidad.

```go
package main

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
	"mi-tui/theme"
)

type model struct {
	theme  *theme.Theme
	styles theme.Styles
	width, height int
}

func initialModel() model {
	t, err := theme.Load("themes/dark.yaml")
	if err != nil {
		fmt.Println("error cargando theme:", err)
		os.Exit(1)
	}
	return model{theme: t, styles: t.Styles()}
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
	case tea.KeyMsg:
		if msg.String() == "ctrl+c" || msg.String() == "q" {
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m model) View() string {
	s := m.styles
	header := s.Title.Render("Mi TUI")
	body := s.Panel.Base.Width(m.width - 4).Height(m.height - 6).Render("Contenido aquí")
	return header + "\n" + body
}

func main() {
	p := tea.NewProgram(initialModel(), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Println("error:", err)
		os.Exit(1)
	}
}
```

```bash
go run .
```

**Verifica:** deberías ver el título en el color `primary` de tu tema, un panel con borde redondeado, y `q`/`ctrl+c` debe cerrar la app limpiamente. Si el panel se ve sin color de fondo distinguible, revisa el apéndice 12 (color profile) antes de continuar — todo lo siguiente se construye sobre esta base visual.

### 15.5 Paso 5 — Agregar un `TextField` (sección 3.2 + 5.3.1)

Copia el `TextField` completo de la sección 3.2 a un nuevo archivo `widgets/textfield.go` (ajusta el import `yourapp/theme` → `mi-tui/theme`, y `yourapp/ui` → `mi-tui/ui`), incluyendo las correcciones de fondo de la sección 5.3.1 (los 4 sub-estilos de `textinput.Model`).

Actualiza `main.go` para incluir el campo y delegarle foco/eventos:

```go
type model struct {
	theme  *theme.Theme
	styles theme.Styles
	field  *widgets.TextField
	width, height int
}

func initialModel() model {
	t, err := theme.Load("themes/dark.yaml")
	if err != nil {
		fmt.Println("error cargando theme:", err)
		os.Exit(1)
	}
	s := t.Styles()
	field := widgets.NewTextField("nombre", "Nombre del host", s)
	field.Focus() // único componente por ahora: foco directo, sin FocusManager aún

	return model{theme: t, styles: s, field: field}
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
	case tea.KeyMsg:
		if msg.String() == "ctrl+c" {
			return m, tea.Quit
		}
	}
	updated, cmd := m.field.Update(msg)
	if f, ok := updated.(*widgets.TextField); ok {
		m.field = f
	}
	return m, cmd
}

func (m model) View() string {
	s := m.styles
	header := s.Title.Render("Mi TUI")
	body := s.Panel.Focused.Width(m.width - 4).Render(m.field.View())
	return header + "\n" + body
}
```

```bash
go run .
```

**Verifica:** deberías poder escribir en el campo, ver el cursor con el color de tu tema (no gris ANSI por defecto — si lo ves gris, revisa 5.3.1), y el borde del panel en `FocusBorder`.

### 15.6 Paso 6 — Agregar `Button` con la corrección de marcos (5.11.1–5.11.3)

Crea `widgets/button.go` con una versión simplificada inspirada en el apéndice 13 (sin necesitar `bubblezone` todavía — eso es el paso 8, mouse opcional):

```go
package widgets

import (
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"mi-tui/theme"
)

type Button struct {
	Label   string
	focused bool
	style   lipgloss.Style // estilo blurred
	focusedStyle lipgloss.Style
	OnPress func() tea.Cmd
}

func NewButton(label string, s theme.Styles, t theme.Theme) *Button {
	border := lipgloss.RoundedBorder()
	base := lipgloss.NewStyle().Border(border).
		BorderForeground(t.BlurBorder).BorderBackground(t.Surface).
		Background(t.Surface).Padding(0, 1).Foreground(t.Text)
	focused := base.BorderForeground(t.FocusBorder).Foreground(t.FocusBorder).Bold(true)

	return &Button{Label: label, style: base, focusedStyle: focused}
}

func (b *Button) Focus() { b.focused = true }
func (b *Button) Blur()  { b.focused = false }

func (b *Button) Update(msg tea.Msg) (*Button, tea.Cmd) {
	if !b.focused {
		return b, nil
	}
	if km, ok := msg.(tea.KeyMsg); ok && (km.String() == "enter" || km.String() == " ") {
		if b.OnPress != nil {
			return b, b.OnPress()
		}
	}
	return b, nil
}

func (b *Button) View() string {
	cursor := "  "
	if b.focused {
		cursor = "➜ "
	}
	s := b.style
	if b.focused {
		s = b.focusedStyle
	}
	return s.Render(cursor + b.Label) // regla de 5.11.2: cursor DENTRO del Render()
}
```

Para una versión completa con hover, shortcuts, toggle, mouse vía `bubblezone`, y los 7 gaps corregidos, usa el `button.go` del apéndice 13 directamente en vez de esta versión simplificada.

### 15.7 Paso 7 — `FocusManager` real: TextField + 2 botones

Ahora que hay más de un componente interactivo, vale la pena introducir el `FocusManager` de la sección 3.3 en vez de manejar foco a mano:

```go
type model struct {
	theme  *theme.Theme
	styles theme.Styles
	field  *widgets.TextField
	save   *widgets.Button
	cancel *widgets.Button
	focus  *ui.FocusManager
	width, height int
}

func initialModel() model {
	t, _ := theme.Load("themes/dark.yaml")
	s := t.Styles()

	field := widgets.NewTextField("nombre", "Nombre del host", s)
	save := widgets.NewButton("Guardar", s, *t)
	cancel := widgets.NewButton("Cancelar", s, *t)

	save.OnPress = func() tea.Cmd {
		return func() tea.Msg { return savedMsg{} }
	}

	fm := ui.NewFocusManager(field, save, cancel) // requiere que los 3 implementen ui.Component

	return model{theme: t, styles: s, field: field, save: save, cancel: cancel, focus: fm}
}
```

> **Nota práctica:** para que `*widgets.Button` implemente `ui.Component` (sección 3.1) necesitas adaptar sus métodos a la firma exacta de la interfaz (`Focus() tea.Cmd`, `SetSize(int,int)`, `ID() string`, etc.) — la versión simplificada del paso 6 no lo cumple todavía. Esto es intencional: te obliga a decidir, igual que en el apéndice 13, si tu `Blur()` devuelve `tea.Cmd` o no, y a propagar esa decisión consistentemente.

```go
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c":
			return m, tea.Quit
		case "tab":
			return m, m.focus.Next()
		case "shift+tab":
			return m, m.focus.Prev()
		}
	}
	cmd := m.focus.Update(msg)
	return m, cmd
}
```

```bash
go run .
```

**Verifica:** `tab`/`shift+tab` deben mover el foco entre el campo y los 2 botones, con el borde cambiando de `BlurBorder` a `FocusBorder` en el componente activo, y `Enter` sobre "Guardar" debe disparar `savedMsg`.

### 15.8 Paso 8 (opcional) — Mouse con `bubblezone`

Si quieres que los botones también respondan a click, sigue el wiring documentado en el apéndice 13 (`zone.NewGlobal()` en `main()`, `tea.WithMouseCellMotion()` al crear el `Program`, y `zone.Scan(...)` envolviendo el `View()` raíz), y usa el `button.go` completo del apéndice en vez del simplificado del paso 6.

### 15.9 Paso 9 (opcional) — Layout de 2 paneles con `GridLayout`

Una vez que el formulario funciona en un solo panel, puedes envolverlo en el patrón de la sección 4.4 (`GridLayout`) para mostrarlo junto a, por ejemplo, un panel de ayuda o logs — siguiendo el mismo `model.resize()` documentado ahí.

### 15.10 Checklist de salida del tutorial

Al completar los pasos 1–7 deberías tener:

1. Un binario que corre con `go run .` y se cierra limpio con `ctrl+c`.
2. Colores consistentes con tu `theme.yaml` (si no, revisar apéndice 12).
3. `tab`/`shift+tab` navegando entre campo y botones, con bordes que cambian de color según foco.
4. Un campo de texto con cursor y placeholder coloreados según el tema (no grises ANSI por defecto).
5. Botones con marco estable (sin deformarse) entre estados blurred/focused.

A partir de aquí, el resto del manual (TreePanel, FilePicker, WindowManager, charts, etc.) se agrega de forma incremental siguiendo el roadmap de la sección 11, reutilizando exactamente el mismo `theme.Styles()` y `FocusManager` que ya tienes funcionando.