# TUI-MAESTRO — Plan Integral del TUI de BOS

> **Versión:** 1.8 — 2026-06-14  
> **Autor:** bos-developer (agente SBOS)  
> **Alcance:** `internal/tui/` — 105 archivos (incluye `tuilog/`), ~15,200 líneas  
> **Propósito:** Análisis de modularidad + normas + plan de corrección + registro de estado + manual de uso

---

## TABLA DE CONTENIDOS

0. [Normas Inmutables del TUI](#0-normas-inmutables-del-tui)
   - SCREEN-001 — Una pantalla, un archivo
   - SCREEN-002 — Jerarquía de archivos compartidos
   - SCREEN-003 — Estilos solo en `styles/`
   - SCREEN-004 — Responsividad global
   - SCREEN-005 — `ctrl/` es el único dashboard
   - SCREEN-006 — `ctrl/` convención atómica propia
   - SCREEN-007 — Design System en `styles/`
   - **TUI-LIB-001 — Formularios: `huh` obligatorio ✅ (wizard migrado)**
   - **TUI-LIB-002 — Listas: `bubbles/list` obligatorio ⬛**
   - **TUI-LIB-003 — Keybindings: `bubbles/key` obligatorio ⬛**
   - **TUI-LIB-004 — Help: `bubbles/help` obligatorio ✅ (wizard + dashboard)**
   - **TUI-LIB-005 — Iconos: `styles.IconXxx()` obligatorio ⬛**
   - **TUI-LIB-006 — Estilos: `styles/` obligatorio ⬛**
   - **TUI-LIB-007 — Spinners/progress: `bubbles/*` obligatorio**
   - **TUI-LIB-008 — Viewport: `bubbles/viewport` obligatorio**
   - **TUI-LIB-009 — Versiones de librerías**
1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Arquitectura Actual](#2-arquitectura-actual)
3. [Inventario de Problemas](#3-inventario-de-problemas)
4. [Plan de Acción](#4-plan-de-acción)
5. [Registro de Estado](#5-registro-de-estado)
6. [Manual de Uso — TUI como Herramienta de Pruebas Reales](#6-manual-de-uso)
7. [Design System — Estilos, Grid e Iconos](#7-design-system)
   - §7.11 — [Paleta Activa: Slate + Cyan — Decisión Formal](#711-paleta-activa-slate--cyan--decisión-formal)
   - §7.12 — [Sistema de Temas — Paleta Personalizable al Inicio](#712-sistema-de-temas--paleta-personalizable-al-inicio)
8. [Sistema de Menús y Navegación por Teclado](#8--sistema-de-menús-y-navegación-por-teclado)
9. [**Registro de Tareas Atómicas**](#9--registro-de-tareas-atómicas) ← iniciar aquí

---

## 0. NORMAS INMUTABLES DEL TUI

> Estas normas son la constitución del TUI. No se negocian, no se omiten por conveniencia.  
> Violarlas = el Bibliotecario rechaza el PR.

---

### SCREEN-001 — Una pantalla, un archivo ⬛ NORMA CARDINAL

**Una pantalla = un archivo `.go`. Sin excepciones.**

Esta es la norma más importante del TUI. Su propósito es garantizar que el sistema de pantallas sea **abierto a extensión, cerrado a modificación**: agregar una pantalla nueva significa crear un archivo nuevo, no modificar un archivo existente que ya contiene otras pantallas.

#### Motivación

Un archivo con múltiples pantallas crea:
1. **Presión de contexto falsa**: si S05, S05B y S05C están en un solo archivo, el programador tiende a crear helpers que los tres comparten pero que no son reutilizables por otras pantallas. La co-localización crea acoplamiento invisible.
2. **Crecimiento sin fricción**: es trivial añadir una cuarta pantalla al archivo existente. Con archivos separados, cada pantalla tiene su propio espacio de nombres visual.
3. **Conflictos en revisión de código**: modificar S05 y S05B en el mismo commit toca el mismo archivo, mezclando contextos en el diff.
4. **Discoverability**: `ls screens/` debe ser el índice completo de todas las pantallas del sistema. Si hay 3 pantallas en un archivo, el índice miente.

#### Convención de nombres

```
s{NN}{letra}_{nombre_descriptivo}.go

Ejemplos:
  s00_welcome.go        ← pantalla de bienvenida/splash
  s05_instalando.go     ← instalación activa (3 columnas)
  s05b_log.go           ← log completo (sub-vista de S05)
  s05c_error.go         ← panel de error (sub-vista de S05)
  s09_dashboard.go      ← panel de operaciones
```

- `NN` = número de orden de flujo (00–99), con letra para sub-vistas (`b`, `c`...)
- `nombre_descriptivo` = sustantivo en español, snake_case
- El número determina el orden en `ls`, que refleja el flujo del usuario

#### Contrato de cada archivo de pantalla

```go
// Package screens — s{NN}_{nombre}.go: descripción de la pantalla.
package screens

// Render{Nombre} es la función pública única y obligatoria.
// Recibe el modelo completo y retorna el string listo para imprimir.
func Render{Nombre}(m tuimodel.Model) string {
    body := build{Nombre}Body(m)
    return assembleScreen(m, body)
}

// build{Nombre}Body construye el cuerpo (privado).
func build{Nombre}Body(m tuimodel.Model) string { ... }

// Funciones privadas adicionales — solo si son específicas de ESTA pantalla.
// Si otra pantalla las necesita → mover a helpers.go.
```

#### Qué NO va en un archivo de pantalla

| ❌ No | ✅ Sí |
|-------|-------|
| Otra función `RenderXxx` | Una sola función `Render{Nombre}` |
| Estilos `lipgloss.NewStyle()` inline | `styles.XxxStyle` desde `styles/styles.go` |
| Helpers compartidos con otras pantallas | Solo helpers privados exclusivos de esta pantalla |
| Constantes de color hardcodeadas | `styles.HexXxx` o `styles.ColorXxx` |
| Lógica de update/teclado | Solo renderizado puro |

#### Relación con el dispatcher

`dispatcher.go` es el único archivo que conoce todos los nombres. Cuando se agrega una pantalla nueva, solo hay que añadir un `case` aquí:

```go
// dispatcher.go — ÚNICO lugar con el inventario completo
func Render(m tuimodel.Model) string {
    switch m.CurrentScreen {
    case tuimodel.ScreenWelcome:     return RenderWelcome(m)
    case tuimodel.ScreenWizardP1:    return RenderWizardP1(m)
    // ... cada screen tiene exactamente una línea aquí
    }
}
```

---

### SCREEN-002 — Jerarquía de archivos compartidos

Los archivos no-pantalla de `screens/` tienen roles fijos e inamovibles:

| Archivo | Rol | Regla |
|---------|-----|-------|
| `dispatcher.go` | Enrutador único | Solo `switch m.CurrentScreen` + llamada a `Render*` |
| `shared.go` | Infraestructura global | `Mode()`, `assembleScreen()`, `RenderHeader()`, `RenderFooter()`, `RenderStepper()`, `WrapWithMargin()` |
| `helpers.go` | Utilidades puras compartidas | `summaryRow`, `VersionSuffix`, `TruncByWidth`, `ClipColumn*`. Solo funciones sin lipgloss. |

Ninguna pantalla individual puede definir funciones que pertenezcan a estos tres archivos.

---

### SCREEN-003 — Estilos solo en `styles/styles.go`

Ningún archivo de pantalla puede contener `lipgloss.NewStyle()`. Toda llamada a lipgloss vive exclusivamente en `styles/styles.go`. Los archivos de pantalla usan `styles.XxxStyle`.

Verificación automática:
```bash
grep -rn "lipgloss.NewStyle()" internal/tui/screens/*.go | grep -v "styles.go"
# → debe retornar vacío
```

---

### SCREEN-004 — Responsividad global, no por pantalla

La función `Mode(w int) string` en `shared.go` es la única fuente de los breakpoints:

```
xs  → ancho < 60 cols
sm  → ancho 60–79 cols
md  → ancho ≥ 80 cols
```

Cada pantalla puede tener variantes de layout (`viewXxxXS`, `viewXxxSM`, `viewXxxMD`), pero **la decisión de qué modo aplicar** siempre es `switch Mode(m.Width)` — nunca condicionales directos sobre `m.Width` con valores numéricos hardcodeados.

---

### SCREEN-005 — `ctrl/` es el único dashboard ⬛ NORMA CARDINAL

**No existe un dashboard simplificado en `screens/`.** El `ctrl/` es la única implementación de dashboard, y es la que se usa siempre: durante la instalación, al iniciar el sistema, y al monitorear BOS en operación.

`screens/dashboard.go` fue la versión inicial provisional. Está **ELIMINADA** y reemplazada por `ctrl/render.go`.

#### Arquitectura del dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│  ctrl/render.go         — ÚNICO compositor del dashboard        │
│  ════════════════════════════════════════════════════════       │
│  ctrl/panel/  (12 paneles)  — Overview, logs, alertas, ...     │
│  ctrl/k8s/    (5 paneles)   — Control plane, workloads, ...    │
│  ctrl/sistema/ (6 paneles)  — Métricas /proc, systemd, ...     │
│  ctrl/dash/   (infraest.)   — DashModel, menu, tick, types     │
│                                                                  │
│  TopBar + Menu lateral + Container con 22 vistas navegables      │
│  Maneja su propio layout — NO usa assembleScreen() de screens/  │
└─────────────────────────────────────────────────────────────────┘
```

#### Dos modos operacionales de `ctrl/`

`ctrl/` funciona en dos contextos distintos, con el MISMO código:

| Modo | Comando | Flujo | Descripción |
|------|---------|-------|-------------|
| **Post-instalación** | `bosctl setup` | S08 Boot → `ScreenDashboard` → `ctrl.Render` | Aparece después del arranque inicial, muestra el estado real del stack recién instalado |
| **Observador BOS** | `bosctl dashboard` | `SetInstalledBoot()` → S08 → `ScreenDashboard` → `ctrl.Render` | BOS ya instalado, ctrl/ monitorea en tiempo real: K8s, daemons, métricas del SO |

#### Punto de integración: `app/app.go`

`ScreenDashboard` se renderiza **directamente** desde `app.View()`, sin pasar por `screens.Render()`:

```go
// app/app.go — View() diferencia el dashboard del resto
func (a *App) View() string {
    if a.m.Width == 0 {
        return "Iniciando SBOS..."
    }
    if a.m.CurrentScreen == tuimodel.ScreenDashboard {
        return ctrl.Render(a.m.Ctrl)  // ctrl maneja su propio layout y chrome
    }
    return screens.WrapWithMargin(screens.Render(*a.m), a.m.TermW)
}
```

**Por qué no a través de `screens.Render()`:** `ctrl.Render()` produce el layout completo con su propio TopBar y BottomBar. Envolverlo con `assembleScreen()` o `WrapWithMargin()` produciría doble chrome. La separación en `app.View()` es el punto correcto.

#### Dependencias — sin ciclo

```
app/ → ctrl/         ✓ (app ya importa model y screens; ctrl no importa ninguno de ellos)
app/ → model/        ✓
app/ → screens/      ✓
ctrl/ → ctrl/dash/   ✓
ctrl/ → styles/      ✓
ctrl/ NO importa model/ ni screens/
```

#### `ctrl/` — arquitectura atómica ya completa

| Subpaquete | Archivos | Estado |
|-----------|---------|--------|
| `ctrl/panel/` | 12 paneles | ✅ Atómico — 1 panel = 1 archivo |
| `ctrl/k8s/` | 5 paneles | ✅ Atómico — 1 vista K8s = 1 archivo |
| `ctrl/sistema/` | 6 paneles | ✅ Atómico — 1 métrica OS = 1 archivo |
| `ctrl/dash/` | Infraestructura | ✅ Correcto — menu, types, tick, widgets |
| `ctrl/render.go` | Compositor | ✅ Solo ensamblaje |

**`ctrl/` NO es objetivo de refactorización.** Ya tiene la arquitectura atómica correcta. Es el modelo a seguir.

#### Regla para agregar paneles al dashboard

```
Agregar un panel nuevo al ctrl/:
  1. Crear ctrl/panel/{nuevo_panel}.go → func NuevoPanel(dm DashModel, w, h int) string
  2. Agregar ViewKey en ctrl/dash/menu.go
  3. Agregar case en ctrl/render.go:renderContainerBody()
  4. Agregar ViewTitle en ctrl/dash/menu.go:ViewTitle()
  5. Sin tocar ningún panel existente
```

---

### SCREEN-006 — `ctrl/` sigue su propia convención atómica (no SCREEN-001)

`ctrl/` no usa el naming `s{NN}_*.go` porque no son pantallas TEA — son **paneles renderizables** sin su propio ciclo de vida. Su convención es:

```
ctrl/panel/{nombre_panel}.go    ← función: func {Nombre}(dm dash.DashModel, w, h int) string
ctrl/k8s/{nombre_vista}.go      ← función: func {Nombre}(dm dash.DashModel, w, h int) string
ctrl/sistema/{nombre_vista}.go  ← función: func {Nombre}(dm dash.DashModel, w, h int) string
```

Agregar un panel nuevo al `ctrl/`:
1. Crear `ctrl/panel/{nuevo_panel}.go` con la función `func NuevoPanel(dm DashModel, w, h int) string`
2. Agregar el `ViewKey` en `ctrl/dash/menu.go`
3. Agregar el `case` en `ctrl/render.go:renderContainerBody()`
4. Agregar el `ViewTitle` en `ctrl/dash/menu.go:ViewTitle()`
5. Sin tocar ningún panel existente

Esta convención ya funciona y **no se cambia**.

---

### SCREEN-007 — Design System estructurado en `styles/` ⬛ NORMA CARDINAL

**El sistema de diseño del TUI sigue la especificación W3C Design Tokens (v1.0 estable, Oct 2025)**
y se implementa en **tres capas jerárquicas** dentro de `styles/styles.go`.

Ningún color, tamaño, espaciado o estilo puede vivir fuera de `styles/`. Las pantallas consumen
tokens, no valores crudos.

#### Las cuatro capas obligatorias

```
CAPA 1 — Primitivos (PrimXxx)                   → tokens_primitive.go
  Raw hex values. Nunca se usan directamente en pantallas.
  Representan la paleta completa del sistema.
  Ejemplo: PrimCyan400 = "#22d3ee"

CAPA 2A — Estado (ColorStateXxx)                 → tokens_state.go  ← NUEVA
  Colores de estado INDEPENDIENTES de la paleta primitiva.
  No derivan de PrimXxx — tienen sus propios hex dedicados por accesibilidad.
  Estándar: IBM Carbon, Material Design 3, WCAG 2.2 AA (≥4.5:1 contraste).
  7 estados × 4 tokens = 28 vars: Fg, Bg, Border, Subtle.
  Ejemplo: ColorStateOKFg = lipgloss.Color("#2dd4a2")  ← teal-green perceptual

CAPA 2B — Semánticos (ColorXxx)                  → tokens_semantic.go
  Asignan INTENCIÓN a los primitivos o al sistema de estado.
  Son los que usan los estilos de componentes.
  Ejemplo: ColorBrandPrimary = PrimCyan400
  Ejemplo: ColorSuccess      = ColorStateOKFg  ← referencia al sistema de estado

CAPA 3 — Componentes (estilos lipgloss)          → tokens_component.go
  Estilos concretos listos para usar en pantallas.
  Consumen tokens semánticos, NUNCA primitivos directamente.
  Ejemplo: MenuActive = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorBrandPrimary))
```

**Regla de las capas de estado:**
Los colores de estado (success, warning, error, info, critical, idle, disabled)
son un grupo con identidad propia según los estándares de accesibilidad.
NO se derivan de `PrimGreen400`, `PrimRed400` etc. — tienen valores hex independientes
elegidos por distinguibilidad perceptual y ratio WCAG. Cambiar la paleta primitiva
NO afecta los colores de estado.

#### Grid de 12 columnas

El layout del TUI se basa en un **grid de 12 columnas** que escala con el ancho del terminal:
- **2 columnas de margen** a cada lado (izquierda y derecha)
- **8 columnas de contenido** central (8 de 12 = 66.7% del ancho)
- Cada columna = `termW / 12` caracteres de ancho

```go
// styles/grid.go (nuevo archivo)
func ColW(termW, cols int) int { return (termW / 12) * cols }
func ContentW(termW int) int   { return ColW(termW, 8) }
func MarginW(termW int) int    { return ColW(termW, 2) }
```

#### Breakpoints responsive (4 niveles)

```
XS  → termW < 60    → grid desactivado, columna única, sin margen
SM  → termW 60–79   → grid activo, 1 col margen (6.7%)
MD  → termW 80–119  → grid activo, 2 col margen (16.7%)  ← referencia
LG  → termW ≥ 120   → grid activo, 2 col margen, columnas más anchas
```

Ver especificación completa en **§7 — Design System**.

---

### TUI-LIB-001 — Formularios: `charmbracelet/huh` obligatorio ✅ NORMA CARDINAL (wizard migrado 2026-06-14)

**PROHIBIDO** implementar formularios, campos de texto, selects, confirmaciones o
toggles a mano. **TODO** elemento interactivo donde el usuario ingrese datos o
elija opciones usa exclusivamente `charmbracelet/huh`.

| Tipo de componente | Obligatorio | PROHIBIDO |
|-------------------|-------------|---------|
| Campo de texto (nombre, dominio, IP) | `huh.NewInput()` | `textinput.Model` + lógica de focus custom |
| Dropdown / combobox (plan, tipo) | `huh.NewSelect()` | cursor `int` + `[]string` + lógica de nav custom |
| Selección múltiple (módulos, permisos) | `huh.NewMultiSelect()` | checkboxes custom con bitmask manual |
| Sí/No, confirmación, toggle | `huh.NewConfirm()` | strings `"✓ Sí"/"○ No"` + tecla Enter manual |
| Contraseña (campo oculto) | `huh.NewInput().EchoMode(huh.EchoPassword)` | textinput con lógica de ocultación propia |
| Resumen informativo (solo lectura) | `huh.NewNote()` | bloque de texto hardcodeado |
| Formulario multi-campo multi-paso | `huh.NewForm()` con grupos | lógica de `wizardFocus++/--` manual |

**Estado de migración (Bloque 8 — ✅ COMPLETADO 2026-06-14):**

| Archivo | Violación original | Estado |
|---------|-------------------|--------|
| `screens/wizard.go` | 424 LOC — 5 formularios con `textinput` + `wizardFocus` custom | ✅ S01-S04 migradas a archivos propios con `huh.NewForm()` |
| `styles/styles.go:RenderMFAToggle()` | Toggle MFA custom de 15 LOC | ✅ Eliminado — S03 usa `huh.NewConfirm()` |
| `screens/wizard.go:renderSelectRow()` | Select custom con cursor y `›` manual | ✅ Eliminado — S01 usa `huh.NewSelect()` |
| `model/update_wizard.go` | 208 LOC de lógica de validación de wizard acoplada al Model | ✅ Validación movida a `huh.Validate()` callbacks en `wizard_forms.go` |

**Nuevos archivos creados (Bloque 8):**
- `model/wizard_forms.go` — constructores `NewWizardP1Form`→`NewWizardP4Form` + `WizardP4Summary()`
- `screens/s01_bienvenida.go` — `RenderWizardP1` con `huh.NewSelect[int]()`
- `screens/s02_empresa.go` — `RenderWizardP2` con `huh.NewForm()` 4 inputs + validaciones inline
- `screens/s03_admin.go` — `RenderWizardP3` con `huh.NewForm()` + `huh.EchoModePassword` + `huh.NewConfirm()` MFA
- `screens/s04_confirmar.go` — `RenderWizardP4` con `WizardP4Summary()` dinámico + `huh.NewConfirm()`

**Verificación (CI gate):**
```bash
# No debe haber textinput usado fuera de huh en screens/
grep -rn "textinput.New\(\)" internal/tui/screens/ | grep -v "_test.go"
# → debe retornar vacío

# No debe haber lógica de focus manual en screens/
grep -rn "WizardFocus\|wizardFocus\|focusIdx\|focusIndex" internal/tui/screens/
# → debe retornar vacío
```

---

### TUI-LIB-002 — Listas navegables: `bubbles/list` obligatorio ⬛ NORMA CARDINAL

**PROHIBIDO** implementar listas de más de 4 ítems con cursor manual.
**TODO** menú, lista de opciones, lista de fichas, lista de daemons usa `bubbles/list`.

| Caso | Obligatorio | PROHIBIDO |
|------|-------------|---------|
| Lista de fichas (panel dashboard) | `list.New(items, delegate, w, h)` | `cursor int` + `strings.Join` + highlight manual |
| Lista de daemons | `list.New(items, delegate, w, h)` | slice de strings con ítem activo en negrita |
| Log de eventos filtrable | `list.New` + `list.SetFilteringEnabled(true)` | filtro custom sobre `[]LogEntry` |
| Menú de 3 ítems o menos | `[]string` + cursor int es aceptable | (excepción explícita para menús pequeños) |

**Deuda de migración:**

| Archivo | Violación |
|---------|-----------|
| `ctrl/panel/logs.go` | Lista de logs con cursor propio — migrar a `bubbles/list` |
| Panel fichas (futuro) | Al implementar, usar `bubbles/list` desde el primer commit |

**Navegación builtin de `bubbles/list` (no reimplementar):**

```
↑/↓ o j/k  → mover cursor
/           → filtro fuzzy (no implementar filtro propio)
Enter       → seleccionar
Esc         → cancelar filtro / cerrar
```

---

### TUI-LIB-003 — Keybindings: `bubbles/key` obligatorio ⬛ NORMA CARDINAL

**PROHIBIDO** comparar teclas directamente con strings. **TODO** keybinding usa
`key.NewBinding()` declarativo para habilitar el help automático.

```go
// ✅ CORRECTO — key.Binding declarativo
var KeyReiniciar = key.NewBinding(
    key.WithKeys("r"),
    key.WithHelp("r", "reiniciar"),
)

// En Update():
case key.Matches(msg, KeyReiniciar):
    return m, cmdReiniciarBOS()

// ❌ PROHIBIDO — comparación de string directa
case tea.KeyMsg:
    if msg.String() == "r" {  // ← PROHIBIDO
        return m, cmdReiniciarBOS()
    }
```

**Regla de contexto:** Las teclas destructivas (reiniciar, apagar, desinstalar)
se deshabilitan dinámicamente según el nivel de autenticación LoA:

```go
// Si el usuario no tiene LoA 3, las teclas destructivas no responden
// y no aparecen en el help view
KeyReiniciar.SetEnabled(m.AuthLoA >= 3)
KeyApagar.SetEnabled(m.AuthLoA >= 3)
```

**Deuda de migración:**

| Archivo | Violación |
|---------|-----------|
| `model/keys.go` | Parcialmente migrado — 4 bindings correctos, expandir al catálogo completo |
| `screens/shared.go` | Comparaciones directas `msg.String()` para navegación de menú |
| `ctrl/dash/menu.go` | Navegación con comparaciones directas |

---

### TUI-LIB-004 — Help de teclado: `bubbles/help` obligatorio ✅ (implementado 2026-06-14)

**PROHIBIDO** hardcodear strings de ayuda de teclado. **TODO** footer/help bar
se genera automáticamente desde los `KeyMap` usando `help.New().View(keyMap)`.

```go
// ✅ CORRECTO — help auto-generado desde KeyMap
h := help.New()
footerHelp := h.View(screenKeyMap)

// ❌ PROHIBIDO — string hardcodeado
footer := "  ↑↓ navegar   Enter: seleccionar   q: salir"  // ← PROHIBIDO
```

**Estado (Bloque 9 — ✅ COMPLETADO 2026-06-14):**
- `model/model.go`: `HelpModel help.Model` — genera footer de wizard con `WizardKeyMap`
- `ctrl/dash/keys.go` (nuevo): `DashMenuKeyMap` + `DashBodyKeyMap` + `DashBodyKeyMapWithSubTab()`
- `ctrl/dash/model.go`: `DashModel.HelpModel help.Model` — inicializado en `dash.New()`
- `ctrl/render.go`: `renderBottomBar` usa `dm.HelpModel.View(dash.DefaultDashMenuKeyMap)` y `dm.HelpModel.View(dash.DashBodyKeyMapWithSubTab(...))`
- SubTab binding se habilita/deshabilita automáticamente; `help.View()` lo omite si está disabled

---

### TUI-LIB-005 — Iconos: `styles.IconXxx()` obligatorio ⬛ NORMA CARDINAL

**PROHIBIDO** escribir literales Unicode o emoji directamente en archivos de
pantalla o paneles. **TODO** ícono proviene de `styles/icons.go`.

```go
// ✅ CORRECTO
line := styles.IconOK() + " " + styles.Muted.Render("postgresql 18.4")

// ❌ PROHIBIDO
line := "✓ " + styles.Muted.Render("postgresql 18.4")  // literal inline
line := "✔ " + ...     // diferente char que ✓ — inconsistencia exacta del codebase actual
line := "📦 " + ...    // emoji inestable
```

**Verificación (CI gate):**
```bash
# No debe haber literales de ícono Unicode inline en pantallas (excepto icons.go)
grep -rn '"[✓✗✔✖⚠●○›↺↻⏻⬡◆▶↑]' internal/tui/screens/ internal/tui/ctrl/ \
  | grep -v "icons.go" | grep -v "_test.go"
# → debe retornar vacío
```

---

### TUI-LIB-006 — Estilos: `styles/` obligatorio ⬛ NORMA CARDINAL (refuerza SCREEN-003)

**PROHIBIDO** `lipgloss.NewStyle()` fuera de `styles/`. Esto ya existe como
SCREEN-003 pero se reitera como TUI-LIB porque el codebase tiene 126+ violaciones.

**Verificación:**
```bash
grep -rn "lipgloss.NewStyle()" internal/tui/ \
  | grep -v "styles/" | grep -v "_test.go"
# → debe retornar vacío
```

**Deuda actual:** 126 instancias en `screens/`, `ctrl/` y `model/`. Se migran en P5 y P6.

---

### TUI-LIB-007 — Spinners y progress: `bubbles/spinner` y `bubbles/progress` obligatorios

**PROHIBIDO** implementar animaciones de carga o barras de progreso custom.

| Componente | Obligatorio | PROHIBIDO |
|-----------|-------------|---------|
| Indicador de carga | `spinner.New()` con `spinner.Update()` | rotación de chars `|/-\` manual |
| Barra de progreso | `progress.New()` con `progress.SetPercent()` | `strings.Repeat("█", n)` manual |

`bubbles/progress` ya se usa en `model/model.go`. `bubbles/spinner` también.
No se necesita reimplementar, solo garantizar que pantallas nuevas los usen.

---

### TUI-LIB-008 — Viewport scrollable: `bubbles/viewport` obligatorio

**PROHIBIDO** gestionar offsets de scroll manualmente.
**TODO** contenido que puede exceder la pantalla usa `viewport.New()`.

```go
// ✅ CORRECTO
vp := viewport.New(w, h)
vp.SetContent(logContent)
// En Update(): vp, cmd = vp.Update(msg)
// En View():   return vp.View()

// ❌ PROHIBIDO
scrollOffset int  // campo en Model para hacer scroll manual
```

`bubbles/viewport` ya se usa en `model/viewport.go`. Extenderlo a los
paneles de logs del dashboard es parte de la migración.

---

### TUI-LIB-009 — Versiones de librerías (ADR-017 aplicado al TUI)

**Versiones canónicas del stack TUI (Junio 2026):**

| Paquete | go.mod actual | Versión objetivo | Notas |
|---------|--------------|-----------------|-------|
| `charmbracelet/bubbletea` | v1.3.10 | v1.3.10 ✅ | Mantener hasta migración a v2 |
| `charmbracelet/bubbles` | v1.0.0 | v1.0.0 ✅ | Mantener hasta migración a v2 |
| `charmbracelet/lipgloss` | v1.1.0 | v1.1.0 ✅ | |
| `charmbracelet/huh` | **v1.0.0** ✅ | v1.0.0 | Instalado 2026-06-14 — Bloque 8 wizard migrado |
| `evertras/bubble-table` | No instalado | v0.17.x | Agregar cuando se implemente panel fichas tabular |

> ✅ `huh v1.0.0` ya instalado (go.mod — 2026-06-14). Compatible con bubbletea v1.
> ⚠️ `github.com/charmbracelet/huh/v2` requiere `bubbletea v2` — NO instalar hasta
> que se decida migrar bubbletea. La migración a v2 es un proyecto separado (P7 futuro).

---

### Resumen de políticas TUI-LIB — tabla de decisión rápida

| Necesito... | Uso | PROHIBIDO |
|------------|-----|---------|
| Campo de texto, selección, confirm | `charmbracelet/huh` | Custom cursor/focus |
| Lista de 5+ ítems navegable | `bubbles/list` | cursor int + []string |
| Definir una tecla de teclado | `bubbles/key.NewBinding()` | `msg.String() == "x"` |
| Mostrar ayuda de atajos | `bubbles/help.View(keyMap)` | String hardcodeado |
| Un ícono o símbolo | `styles.IconXxx()` | Literal Unicode/emoji inline |
| Un color o estilo visual | `styles.XxxStyle` o `styles.ColorXxx` | `lipgloss.NewStyle()` inline |
| Animación de carga | `bubbles/spinner` | chars `\|/-\` manual |
| Barra de progreso | `bubbles/progress` | `strings.Repeat("█", n)` |
| Área scrollable | `bubbles/viewport` | offset scroll manual |

**Consecuencia de violación:** El Bibliotecario rechaza el PR. No hay excepciones sin ADR aprobado.

---

## 1. RESUMEN EJECUTIVO

El TUI del instalador BOS es funcional pero tiene **15 problemas estructurales** acumulados: 8 de la migración original + 7 de deuda TUI-LIB (rueda reinventada en lugar de usar las librerías disponibles). Uno es un **bug funcional activo** (viewports sin color). El resto aumentan el riesgo de regresión y duplivan código que las librerías ya resuelven.

| Severidad | Problema | Norma | Estado |
|-----------|----------|-------|--------|
| 🔴 CRÍTICO | SCREEN-001 violada — 16 pantallas en 5 archivos (debería ser 1:1) | SCREEN-001 | ✅ Resuelto (P0 — 2026-06-14) |
| 🔴 CRÍTICO | SCREEN-005 violada — `screens/dashboard.go` existe y NO usa `ctrl/` | SCREEN-005 | ✅ Resuelto (Paso 0.5) |
| 🔴 CRÍTICO | `BuildColA/B/C` duplicados — viewports muestran texto plano sin color | — | ✅ Resuelto (P2 — 2026-06-14) — `syncViewports` en `app/app.go` |
| 🔴 CRÍTICO | TUI-LIB-001 violada — wizard.go con 424 LOC de formularios custom (`textinput` + cursor manual) en lugar de `huh` | TUI-LIB-001 | ✅ Resuelto (Bloque 8 — 2026-06-14) |
| 🔴 CRÍTICO | TUI-LIB-001 violada — `huh` no está instalado (`go.mod`) | TUI-LIB-009 | ✅ Resuelto — huh v1.0.0 instalado |
| 🟠 ALTO | TUI-LIB-003 violada — keybindings con `msg.String()` en lugar de `key.Binding` | TUI-LIB-003 | Abierto |
| 🟠 ALTO | TUI-LIB-005 violada — `✔` vs `✓` (distinto char), `📦`, `🚀` hardcodeados (20+ archivos) | TUI-LIB-005 | Abierto |
| 🟠 ALTO | 5 helpers duplicados entre `model/` y `screens/` (~260 líneas idénticas) | — | ✅ Resuelto (P1 — 2026-06-14) — `util/format.go`, `model/update.go` limpio |
| 🟠 ALTO | `fichaVersions` — dos fuentes de verdad para versiones de fichas | — | ✅ Resuelto (P3 — 2026-06-14) — `util/ficha.go` fuente única |
| ✅ RESUELTO | TUI-LIB-006 violada — 0 llamadas `lipgloss.NewStyle()` inline en screens/ y ctrl/ | TUI-LIB-006 | Cerrado (T-100) |
| 🟡 MEDIO | TUI-LIB-004 violada — help de teclado hardcodeado en strings, no `bubbles/help` | TUI-LIB-004 | ✅ Resuelto (Bloque 9 — 2026-06-14) |
| 🟡 MEDIO | `summaryRow` definida en `wizard.go` pero es helper global | SCREEN-002 | ✅ Resuelto (P4 — 2026-06-14) — en `helpers.go:16` |
| 🟡 MEDIO | Menú lateral `ctrl/dash/` con cursor manual (4 ítems — excepción aceptable por tamaño) | TUI-LIB-002 | Abierto (baja prio) |
| 🟢 BAJO | Paquete `util/` no existe — impide compartir helpers sin circular dep | — | ✅ Resuelto (P1 — 2026-06-14) — `util/format.go` + `util/ficha.go` |
| 🟢 BAJO | `evertras/bubble-table` no instalado — panel fichas tabular pendiente | TUI-LIB-002 | Futuro |

---

## 2. ARQUITECTURA ACTUAL

### 2.1 Estructura de paquetes

```
internal/tui/                           (130+ archivos — ~18,000+ líneas)
│
├── app/        (2 arch,   ~120 lín)  Bridge tea.Model — syncViewports() estilizado ✅
├── ctrl/       (25+ arch, ~3,500)   Dashboard controller
│   ├── dash/   (7 arch)             Modelo, tick, widgets, tipos, DashMenuKeyMap/DashBodyKeyMap ✅
│   ├── k8s/                         Paneles de Kubernetes
│   ├── panel/                       Paneles UI (overview, backups, seguridad, etc.)
│   └── sistema/                     Métricas del SO (/proc, systemd)
├── demo/       (2 arch,   ~160 lín) Demo runner — simula eventos WS
├── model/      (18 arch, ~3,000 lín) Estado global + lógica Update + wizard_forms.go ✅
├── observer/   (2 arch,   ~340 lín) Lector real /proc → DashSnap
├── screens/    (30+ arch, ~6,000 lín) Renderers puros — SCREEN-001 cumplida ✅ (sXX.go por pantalla)
├── styles/     (8 arch,  ~1,071 lín) Design system — 4 capas + grid + iconos
├── util/       (4 arch,   ~200 lín)  Paquete hoja: format.go + ficha.go — fuente canónica ✅
│   ├── tokens_primitive.go           Capa 1: PrimXxx hex (35+ constantes)
│   ├── tokens_state.go               Capa 2A: ColorStateXxx independientes (✅ 2026-06-14)
│   ├── tokens_semantic.go            Capa 2B: ColorXxx intención sobre primitivos/estado
│   ├── tokens_component.go           Capa 3: estilos lipgloss de componentes
│   ├── grid.go                       Grid 12 col + Mode() + breakpoints
│   ├── icons.go                      25+ funciones IconXxx()
│   ├── doc.go                        Documentación del paquete
│   └── styles.go                     Re-exports + compat
└── tuilog/     (2 arch,  ~1,206 lín) Logger de seguimiento interno del TUI (✅ 2026-06-14)
    ├── tuilog.go                     Ring buffer + journald + BubbleTea integration
    └── tuilog_test.go                51 tests — 100% pasan
```

### 2.2 Grafo de dependencias (estado actual)

```
                    ┌─────────────┐
                    │  cmd/bosctl │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │    app/     │  ← bridge: importa model/ Y screens/
                    └──┬──────┬───┘
                       │      │
              ┌────────▼─┐  ┌─▼──────────┐
              │  model/  │  │  screens/  │
              │          │  │            │
              │ ⚠ copia  │  │ ⚠ copia   │
              │ helpers  │  │ fichaVer.  │
              └────┬─────┘  └─────┬──────┘
                   │              │
              ┌────▼──────────────▼────┐
              │        styles/         │
              └────────────────────────┘

ctrl/dash/ ←── model/       ✓
util/      ←── ✅ EXISTE    ✓ (format.go + ficha.go — fuente canónica, sin circular dep)
```

### 2.3 Inventario de archivos por paquete

#### `model/` — Estado y lógica de actualización (estado actual ✅)

| Archivo | Líneas | Contenido |
|---------|--------|-----------|
| `model.go` | 402 | Struct Model, New(), Init(), SetScreen(), HelpModel help.Model |
| `update.go` | — | HandleUpdate, HandleKey, switchLogTab() — SIN duplicados ✅ |
| `update_wizard.go` | 208 | validateTenant, validateAdmin, CapacityEstimate |
| `wizard_forms.go` | ~165 | ✅ NUEVO 2026-06-14 — NewWizardP{1-4}Form() + WizardP4Summary() — huh v1.0.0 |
| `auth.go` | — | AuthState, LoA helpers |
| `events.go` | — | Tipos de mensajes TEA + aliases tuilog |
| `keys.go` | 121 | IsNavKey, bindings de teclado, WizardKeyMap |
| `phases.go` | 48 | DefaultPhases, FichaVersions (delega a util.FichaVersions) ✅ |
| `preflight.go` | 187 | PreflightNeeded, StartPreflightCmd |
| `sysinfo.go` | 92 | DetectSystemInfo → /etc/os-release, /proc |
| `viewport.go` | — | VpDims, activePhaseLineIdx |
| `ws.go` | 252 | ConnectWS, AwaitWS, SendWS, DashTickCmd, EnsureDaemonRunning |
| `types.go` | — | Tipos exportados (LogEntry, FichaDetail, etc.) |
| `env_loader.go` | — | Carga de entorno |
| `env_schema.go` | — | Schema y validación de variables de entorno |

#### `screens/` — Renderers puros (estado actual — SCREEN-001 ✅ CUMPLIDA 2026-06-14)

| Archivo | Estado | Descripción |
|---------|--------|-------------|
| `dispatcher.go` | ✅ OK | Enrutador — delega a RenderXxx por pantalla |
| `shared.go` | 🟡 103 inline styles | Infraestructura compartida — limpiar en P5 |
| `helpers.go` | ✅ Limpio | summaryRow, StepMsgSuffix, TruncByWidth, ClipColumn* — SIN duplicados ✅ |
| `s00_welcome.go` | ✅ Existe | RenderWelcome — pantalla splash |
| `s01_bienvenida.go` | ✅ Existe | RenderWizardP1 — huh.NewSelect |
| `s02_empresa.go` | ✅ Existe | RenderWizardP2 — huh.NewForm 4 inputs |
| `s03_admin.go` | ✅ Existe | RenderWizardP3 — huh + EchoModePassword + MFA |
| `s03b_capacidad.go` | ✅ Existe | RenderWizardCapacity — estimados de capacidad |
| `s04_confirmar.go` | ✅ Existe | RenderWizardP4 — huh.NewConfirm + summary dinámico |
| `s05_instalando.go` | ✅ Existe | RenderInstalling — 3 columnas con colores ✅ |
| `s05b_log.go` | ✅ Existe | RenderInstallLog — log expandido |
| `s05c_error.go` | ✅ Existe | RenderInstallErr — panel de error |
| `s06_done.go` | ✅ Existe | RenderInstallDone — post-instalación |
| `s07_reboot.go` | ✅ Existe | RenderReboot — countdown |
| `s08_boot.go` | ✅ Existe | RenderBoot — progreso de arranque |
| `s11_shutdown.go` | ✅ Existe | RenderShutdown — apagado en progreso |
| `s99_goodbye.go` | ✅ Existe | RenderGoodbye — pantalla de despedida |
| `sauth_login.go` | ✅ Existe | RenderAuthLogin — login huh + LoA |
| `sauth_confirm.go` | ✅ Existe | RenderAuthConfirm — step-up LoA 3 |

**Archivos originales ELIMINADOS:** `wizard.go`, `installing.go`, `postinstall.go`, `splash.go`, `dashboard.go` — reemplazados por archivos individuales.

#### `screens/` — Estructura objetivo (después de aplicar SCREEN-001 + SCREEN-005)

```
screens/
├── dispatcher.go          ← ScreenDashboard case ELIMINADO (app.View() lo intercepta antes)
├── shared.go              ← sin cambios (Mode, assembleScreen, RenderHeader/Footer/Stepper)
├── helpers.go             ← limpio: solo TruncByWidth, ClipColumn*, summaryRow, VersionSuffix
│
├── s00_welcome.go         ← extraído de splash.go      → RenderWelcome
├── s01_bienvenida.go      ← extraído de wizard.go      → RenderWizardP1
├── s02_empresa.go         ← extraído de wizard.go      → RenderWizardP2
├── s03_admin.go           ← extraído de wizard.go      → RenderWizardP3
├── s03b_capacidad.go      ← extraído de wizard.go      → RenderWizardCapacity
├── s04_confirmar.go       ← extraído de wizard.go      → RenderWizardP4
├── s05_instalando.go      ← extraído de installing.go  → RenderInstalling + BuildColA/B/C + viewXxx*
├── s05b_log.go            ← extraído de installing.go  → RenderInstallLog
├── s05c_error.go          ← extraído de installing.go  → RenderInstallErr + buildErrBody
├── s06_done.go            ← extraído de postinstall.go → RenderInstallDone
├── s07_reboot.go          ← extraído de postinstall.go → RenderReboot
├── s08_boot.go            ← extraído de postinstall.go → RenderBoot
│   ↓ S09 ELIMINADA — ScreenDashboard → ctrl.Render(m.Ctrl) en app.View()
├── s11_shutdown.go        ← extraído de dashboard.go   → RenderShutdown (apagado en progreso)
└── s99_goodbye.go         ← extraído de splash.go      → RenderGoodbye
```

**Total:** 14 archivos de pantalla + 3 archivos compartidos = **17 archivos** (vs 5 actuales)

`screens/dashboard.go` **se elimina por completo.** Sus tres funciones se resuelven así:
- `RenderDashboard` (S09) → reemplazada por `ctrl.Render(m.Ctrl)` en `app/app.go`
- `RenderLogs` (S10) → reemplazada por panel `logs` del `ctrl/` (accesible desde el menú lateral)
- `RenderShutdown` (S11) → migrada a `s11_shutdown.go` (pantalla TEA válida, distinta del dashboard)

#### Punto de integración: `app/app.go` + `ctrl/`

```go
// app/app.go — la única modificación necesaria para conectar ctrl/
import (
    tuimodel "bos/internal/tui/model"
    "bos/internal/tui/screens"
    "bos/internal/tui/ctrl"
    "bos/internal/tui/demo"
    tea "github.com/charmbracelet/bubbletea"
)

func (a *App) View() string {
    if a.m.Width == 0 {
        return "Iniciando SBOS..."
    }
    // ctrl/ maneja su propio chrome (TopBar + BottomBar) — no usar assembleScreen
    if a.m.CurrentScreen == tuimodel.ScreenDashboard {
        return ctrl.Render(a.m.Ctrl)
    }
    return screens.WrapWithMargin(screens.Render(*a.m), a.m.TermW)
}
```

#### Mapa completo de pantallas — 14 pantallas en `screens/`

| ID | Archivo destino | Función pública | Descripción | Origen actual |
|----|----------------|-----------------|-------------|---------------|
| S00 | `s00_welcome.go` | `RenderWelcome` | Splash inicial + barra preflight | `splash.go:21` |
| S01 | `s01_bienvenida.go` | `RenderWizardP1` | Menú inicio: Comenzar / Salir + info sistema | `wizard.go:30` |
| S02 | `s02_empresa.go` | `RenderWizardP2` | Formulario: Razón Social, NIT, País, Dominio | `wizard.go:91` |
| S03 | `s03_admin.go` | `RenderWizardP3` | Formulario: Email, Nombre, Contraseña, MFA toggle | `wizard.go:153` |
| S03B | `s03b_capacidad.go` | `RenderWizardCapacity` | Estimados: Tenants, Empresas, Sucursales, Usuarios | `wizard.go:321` |
| S04 | `s04_confirmar.go` | `RenderWizardP4` | Resumen + menú Instalar / Volver / Salir | `wizard.go:244` |
| S05 | `s05_instalando.go` | `RenderInstalling` | 3 columnas: árbol fases + pasos activos + log | `installing.go:785` |
| S05B | `s05b_log.go` | `RenderInstallLog` | Vista expandida del log completo con búsqueda | `installing.go:796` |
| S05C | `s05c_error.go` | `RenderInstallErr` | Panel de error con causa, pasos fallidos, acciones | `installing.go:862` |
| S06 | `s06_done.go` | `RenderInstallDone` | Resumen post-instalación con tabs (Acceso/Pasos/Log) | `postinstall.go:21` |
| S07 | `s07_reboot.go` | `RenderReboot` | Countdown de reinicio con barra de progreso | `postinstall.go:241` |
| S08 | `s08_boot.go` | `RenderBoot` | Barra de progreso de arranque del sistema | `postinstall.go:308` |
| S11 | `s11_shutdown.go` | `RenderShutdown` | Pantalla de apagado/reinicio en progreso | `dashboard.go:213` |
| S99 | `s99_goodbye.go` | `RenderGoodbye` | Pantalla de despedida con resumen de sesión | `splash.go:106` |
| **DASH** | — | `ctrl.Render(m.Ctrl)` | Dashboard completo (22 paneles) — en `ctrl/`, no en `screens/` | `ctrl/render.go` |

#### Regla de helpers privados entre sub-vistas

Las sub-vistas S05B y S05C comparten helpers privados con S05 (`scriptTag`, `colorLogMsg`, `renderLogEntry`, `phaseStatusOf`, etc.). Como pertenecen al mismo paquete `screens`, los helpers privados de `s05_instalando.go` son accesibles desde `s05b_log.go` y `s05c_error.go` sin necesidad de exportarlos. Esto es correcto y se mantiene.

Si un helper privado de una pantalla es usado por otra pantalla **no relacionada**, entonces va a `helpers.go`.

---

## 3. INVENTARIO DE PROBLEMAS

### P-01 🔴 CRÍTICO — Viewports con texto plano ✅ RESUELTO 2026-06-14

**Solución aplicada:** `app/app.go` — `syncViewports(m *tuimodel.Model)` llama `screens.BuildColA/B/C` (versiones con lipgloss). `model/update.go` ya no tiene `BuildColAContent/B/C`. Las columnas S05 muestran colores correctos en tiempo real.

---

### P-02 🟠 ALTO — 5 helpers duplicados ✅ RESUELTO 2026-06-14

**Solución aplicada:** `util/format.go` es ahora la fuente única de `FormatDur`, `TruncA`, `WordWrap`, `MaxInt`, `BootMessage`. `model/update.go` y `screens/helpers.go` ya no contienen copias — las eliminaciones están verificadas.

---

### P-03 🟠 ALTO — Dos fuentes de verdad para versiones de fichas ✅ RESUELTO 2026-06-14

**Solución aplicada:** `util/ficha.go:FichaVersions` es la fuente única. `screens/helpers.go` ya no tiene copia privada `fichaVersions`. `model/phases.go` delega: `var FichaVersions = util.FichaVersions`.

---

### P-04 🟡 MEDIO — 126 instancias `lipgloss.NewStyle()` inline

Viola POLICY §2.1 ("Zero inline styles — all lipgloss styles must live in styles/styles.go").

**Desglose por archivo:**

| Archivo actual | Instancias (aprox) | Ejemplos de lo que falta en styles/ |
|----------------|---------------------|--------------------------------------|
| `s05_instalando.go` (ex `installing.go`) | ~35 | `LogTimestamp`, `LogError`, `LogWarn`, `LogInfo`, `StepTextDone`, `StepTextActive`, `ColTitle`, `BorderNormal`, `BorderFocus` |
| `s06_done.go` + `s07_reboot.go` + `s08_boot.go` (ex `postinstall.go`) | ~30 | `SectionLabel` (Dim+Italic repetido 12 veces), `CenteredBold`, `LogPad` |
| `s01_bienvenida.go`..`s04_confirmar.go` (ex `wizard.go`) | ~25 | `WizardCursor`, `WizardItem*`, `PhaseItem`, `FichaItem` |
| `s00_welcome.go` + `s99_goodbye.go` (ex `splash.go`) | ~20 | `SplashTitle`, `SplashSub`, `SplashProduct`, `SplashLegal*` |
| `shared.go` | ~12 | `MenuActive`, `MenuCursor`, `MenuInactive`, `MenuHint`, `StepperSep` |
| `s11_shutdown.go` (ex `dashboard.go`) | ~15 | `BtnLogs`, `BtnRestart`, `BtnShutdown`, `LiveIndicator`, `BarFilled` |
| **Total actual** | **~103** | ← verificado con grep 2026-06-14 |

**Colores hardcodeados encontrados (no están en styles/):**
```
"#ef4444"  — rojo error    (ya existe: HexRed ✓, pero se usa literal igualmente)
"#f59e0b"  — amarillo warn  (ya existe: HexYellow ✓, mismo problema)
"#94a3b8"  — slate claro    — FALTA ColorSlate2
"#e2e8f0"  — blanco cálido  — FALTA ColorWhite2
"#64748b"  — gris log       — FALTA ColorLogInfo
"#334155"  — timestamp dim  — FALTA ColorTimestamp (cercano a HexSlate)
"#1e293b"  — divider        — ya existe: HexBg3 ✓
"#86efac"  — verde claro    — FALTA ColorGreenLight
"#4ade80"  — verde medio    — FALTA ColorGreenMid
"#1e3a5f"  — azul oscuro    — FALTA ColorBlueDark
"#3b82f6"  — azul activo    — FALTA ColorBlue
"#0f2433"  — fondo menu     — FALTA ColorMenuBg
"#fca5a5"  — rojo claro     — FALTA ColorRedLight
"#fde68a"  — amarillo claro — FALTA ColorYellowLight
```

---

### P-05 🟡 MEDIO — `summaryRow` en el lugar incorrecto ✅ RESUELTO 2026-06-14

**Solución aplicada:** `summaryRow` está en `screens/helpers.go:16` — accesible a todos los `sXX.go` del paquete. `wizard.go` eliminado.

---

### P-06 🟢 BAJO — Paquete `util/` inexistente ✅ RESUELTO 2026-06-14

**Solución aplicada:** `internal/tui/util/` creado con `format.go` (FormatDur, TruncA, WordWrap, MaxInt, BootMessage) y `ficha.go` (FichaVersions, VersionSuffix). Resuelve P-02 y P-03.

---

### P-07 🔴 CRÍTICO — `ctrl/` no está conectado al flujo TUI ✅ RESUELTO (P0.5 — 2026-06-13)

**Solución aplicada:** `app/app.go` intercepta `ScreenDashboard` y llama `ctrl.Render(a.m.Ctrl)`. `screens/dashboard.go` eliminado. `s11_shutdown.go` extrae RenderShutdown. `dispatcher.go` ya no tiene case para ScreenDashboard.

---

## 4. PLAN DE ACCIÓN

### Principios del plan

- Cada paso es **autónomo** — compila y los tests pasan al terminar el paso
- Orden: **primero lo que corrige bugs**, luego lo que mejora estructura
- **No reescribir lo que funciona** — mínima superficie de cambio por paso
- Cada paso tiene **criterio de done verificable**

---

### PASO 0 — Dividir screens/ en 1 archivo por pantalla (SCREEN-001) ✅ COMPLETADO 2026-06-14

**Norma que implementa:** SCREEN-001  
**Estado:** Todos los sXX.go existen. wizard.go, installing.go, postinstall.go, splash.go, dashboard.go eliminados.

#### Estrategia de ejecución

El split es **mecánico**: mover el bloque de código de cada función `RenderXxx` (y sus builders privados exclusivos) a un nuevo archivo. Como todos los archivos están en el mismo paquete `screens`, las referencias entre ellos no cambian — ni siquiera los tests tocan.

**Orden recomendado** (de más simple a más complejo):

```
PREREQUISITO: Paso 0.5 debe estar completo — dashboard.go ya eliminado antes de llegar aquí

1. splash.go      → s00_welcome.go + s99_goodbye.go            (2 funciones, fácil)
2. postinstall.go → s06_done.go + s07_reboot.go + s08_boot.go  (3 funciones, fácil)
3. wizard.go      → s01..s04 + s03b (5 funciones, summaryRow a helpers.go)
4. installing.go  → s05 + s05b + s05c (más complejo — muchos helpers privados)

dashboard.go ya NO aparece aquí — se elimina completamente en Paso 0.5
(solo RenderShutdown sobrevive como s11_shutdown.go, también en Paso 0.5)
```

#### Protocolo de cada split

```bash
# 1. Crear el nuevo archivo con el encabezado correcto
# 2. Mover SOLO las funciones de esa pantalla
# 3. Verificar que compila
go build ./internal/tui/screens/
# 4. Verificar que los tests pasan
go test ./internal/tui/screens/...
# 5. Eliminar las funciones del archivo original
# 6. Compilar + test de nuevo
# 7. Repetir para la siguiente pantalla
```

#### Encabezado estándar de cada nuevo archivo

```go
// Package screens — s{NN}_{nombre}.go: {descripción una línea}.
package screens

import (
    tuimodel "bos/internal/tui/model"
    "bos/internal/tui/styles"
    // solo los imports que esta pantalla realmente usa
)
```

#### Split de `installing.go` (el más complejo)

`installing.go` tiene helpers privados compartidos entre S05, S05B y S05C. Distribución:

| Función | Destino |
|---------|---------|
| `scriptTag`, `colorLogMsg`, `renderLogEntry`, `renderLogEntryNoTS` | `s05_instalando.go` (helpers de log — S05B los usa, misma pkg) |
| `phaseStatusOf`, `phaseIconStr`, `fichaIconStr`, `stepNameToDesc` | `s05_instalando.go` (helpers de fases) |
| `renderSubComp`, `renderStepRow`, `activeFicha`, `fichaCountersOf` | `s05_instalando.go` (helpers de renderizado de ficha) |
| `filteredLogs`, `highlightMatch`, `lastLogLines` | `s05b_log.go` (usados solo por S05B) |
| `safeWidth` | `s05_instalando.go` (helper de dimensiones) |
| `BuildColA`, `BuildColB`, `BuildColC` | `s05_instalando.go` (builders de viewports) |
| `renderInstallFull`, `viewInstallingXS/SM/MD`, `viewInstallingNormal` | `s05_instalando.go` (layouts responsivos de S05) |
| `buildErrBody` | `s05c_error.go` (exclusivo de S05C) |
| `RenderInstalling` | `s05_instalando.go` ← función pública principal |
| `RenderInstallLog` | `s05b_log.go` ← función pública principal |
| `RenderInstallErr` | `s05c_error.go` ← función pública principal |

#### Criterio de done

```bash
# Verificar que existe exactamente 1 Render* por archivo de pantalla
grep -l "^func Render" internal/tui/screens/s*.go | wc -l
# → 14  (S09 y S10 no existen en screens/ — están en ctrl/)

# Verificar que ningún archivo s*.go tiene más de 1 función Render*
for f in internal/tui/screens/s*.go; do
  count=$(grep -c "^func Render" "$f")
  if [ "$count" -gt 1 ]; then echo "VIOLA SCREEN-001: $f ($count funciones)"; fi
done
# → sin output

# Verificar que archivos viejos ya no existen
ls internal/tui/screens/splash.go internal/tui/screens/wizard.go \
   internal/tui/screens/installing.go internal/tui/screens/postinstall.go 2>&1
# → No such file
# (dashboard.go ya fue eliminado en Paso 0.5)

# Build y tests limpios
/home/skull/go-dist/go/bin/go build ./internal/tui/...
/home/skull/go-dist/go/bin/go test ./internal/tui/...
```

---

### PASO 0.5 — Conectar `ctrl/` como dashboard y eliminar `screens/dashboard.go`

**Problema que resuelve:** P-07 🔴  
**Prioridad:** PRIMERA — antes incluso que el split general de SCREEN-001  
**Esfuerzo estimado:** 45min  
**Depende de:** Ninguno — es el cambio más atómico y de mayor impacto inmediato

#### Motivación

Este paso conecta 13,000 líneas de trabajo ya hecho (`ctrl/`) con el flujo real del TUI. Es el cambio de mayor retorno sobre inversión: 3 archivos editados, impacto total en el sistema.

#### Sub-paso A — Extraer `RenderShutdown` a su propio archivo

**Antes de eliminar `dashboard.go`**, extraer S11 porque es una pantalla TEA válida:

```bash
# Crear s11_shutdown.go con RenderShutdown y buildShutdownBody
# Fuente: dashboard.go:213 → final del archivo
```

Estructura de `s11_shutdown.go`:
```go
// Package screens — s11_shutdown.go: pantalla de apagado en progreso.
package screens

import (
    tuimodel "bos/internal/tui/model"
    "bos/internal/tui/styles"
    "github.com/charmbracelet/lipgloss"
    "fmt"
)

func RenderShutdown(m tuimodel.Model) string {
    return assembleScreen(m, buildShutdownBody(m))
}

func buildShutdownBody(m tuimodel.Model) string {
    // [código movido de dashboard.go:buildShutdownBody]
}
```

Verificar que compila:
```bash
/home/skull/go-dist/go/bin/go build ./internal/tui/screens/
```

#### Sub-paso B — Modificar `app/app.go`

Agregar import de `ctrl` e interceptar `ScreenDashboard`:

```go
import (
    tuimodel "bos/internal/tui/model"
    "bos/internal/tui/screens"
    "bos/internal/tui/ctrl"
    "bos/internal/tui/demo"
    tea "github.com/charmbracelet/bubbletea"
)

func (a *App) View() string {
    if a.m.Width == 0 {
        return "Iniciando SBOS..."
    }
    if a.m.CurrentScreen == tuimodel.ScreenDashboard {
        return ctrl.Render(a.m.Ctrl)
    }
    return screens.WrapWithMargin(screens.Render(*a.m), a.m.TermW)
}
```

#### Sub-paso C — Limpiar `dispatcher.go`

Eliminar los cases que ya no existen en `screens/`:

```go
// Eliminar:
case tuimodel.ScreenDashboard:
    return RenderDashboard(m)   // ← borrar estas 2 líneas
case tuimodel.ScreenLogs:
    return RenderLogs(m)        // ← borrar estas 2 líneas
```

El case `ScreenShutdown` se mantiene apuntando a `RenderShutdown` (ahora en `s11_shutdown.go`).

#### Sub-paso D — Eliminar `screens/dashboard.go`

```bash
rm internal/tui/screens/dashboard.go
/home/skull/go-dist/go/bin/go build ./internal/tui/...
```

#### Criterio de done

```bash
# 1. dashboard.go eliminado
ls internal/tui/screens/dashboard.go 2>&1
# → No such file or directory

# 2. s11_shutdown.go existe y compila
ls internal/tui/screens/s11_shutdown.go
/home/skull/go-dist/go/bin/go build ./internal/tui/screens/

# 3. app.go compila con ctrl importado
/home/skull/go-dist/go/bin/go build ./internal/tui/app/

# 4. Build completo limpio
/home/skull/go-dist/go/bin/go build ./cmd/bosctl/

# 5. Demo funciona y muestra ctrl/ dashboard al llegar a ScreenDashboard
./bos setup --demo
# → Navegar hasta la pantalla de dashboard → debe mostrar ctrl/ (TopBar azul, menú lateral, 22 vistas)
# → Verificar que "bosctl dashboard" arranca y muestra ctrl/
```

---

### PASO 1 — Crear `internal/tui/util/` ✅ COMPLETADO 2026-06-14

**Problema que resuelve:** P-02, P-06  
**Estado:** `util/format.go` + `util/ficha.go` existen. Duplicaciones eliminadas de model/ y screens/.

**Archivos nuevos:**
```
internal/tui/util/
├── format.go     — FormatDur, TruncA, Truncate, WordWrap, MaxInt, BootMessage
└── ficha.go      — FichaVersions, VersionSuffix (fuente única)
```

**Reglas del paquete `util/`:**
- Paquete hoja: NO importa ningún otro paquete del TUI
- Solo stdlib + `github.com/mattn/go-runewidth` (para TruncByWidth)
- Funciones puras — sin efectos secundarios

**Cambios en archivos existentes:**
- `model/update.go`: eliminar sección "Helpers de formato" (líneas ~998–1105)
- `model/update.go`: reemplazar llamadas locales por `util.FormatDur(...)` etc.
- `model/phases.go`: eliminar `FichaVersions` → mover a `util/ficha.go`
- `screens/helpers.go`: eliminar `fichaVersions`, `FormatDur`, `TruncA`, `WordWrap`, `MaxInt`, `BootMessage`
- `screens/helpers.go`: agregar `import "bos/internal/tui/util"` y reexportar o llamar directamente

**Criterio de done:**
```bash
/home/skull/go-dist/go/bin/go build ./internal/tui/...
/home/skull/go-dist/go/bin/go test ./internal/tui/...
grep -r "FormatDur\|TruncA\|WordWrap\|MaxInt\|BootMessage" internal/tui/model/update.go
# → solo llamadas (util.FormatDur), no definiciones
```

---

### PASO 2 — Corregir viewports (bug funcional) ✅ COMPLETADO 2026-06-14

**Problema que resuelve:** P-01  
**Estado:** `app/app.go:syncViewports()` llama `screens.BuildColA/B/C`. model/update.go ya no tiene BuildColXContent.

**Concepto:**

```
ANTES:                              DESPUÉS:
model/update.go                     app/app.go
  SyncViewports() {                   Update() {
    VpA.SetContent(                     newM, cmd := model.HandleUpdate(...)
      BuildColAContent(m) // plano       a.m = newM
    )                                   // sincronizar viewports CON estilos:
  }                                     syncViewports(a.m)
                                        return a, cmd
                                      }
                                      func syncViewports(m *model.Model) {
                                        wA, wB, wC, _ := model.VpDims(...)
                                        m.VpA.SetContent(screens.BuildColA(*m, wA-1))
                                        m.VpB.SetContent(screens.BuildColB(*m, wB-1))
                                        m.VpC.SetContent(screens.BuildColC(*m, wC-3))
                                      }
```

**Cambios:**
1. `app/app.go`: agregar `syncViewports(m *model.Model)` que llama `screens.BuildColA/B/C`
2. `app/app.go`: llamar `syncViewports` después de cada `HandleUpdate` cuando la pantalla es `ScreenInstalling`
3. `model/update.go`: eliminar `BuildColAContent`, `BuildColBContent`, `BuildColCContent` (~103 líneas)
4. `model/update.go`: `SyncViewports` pasa a ser no-op o se elimina (ya no actualiza viewports)
5. `model/update.go`: `AddLog` ya no llama viewport sync (lo hace `app/`)

**Criterio de done:**
```bash
# Compilar y ejecutar demo — verificar que las columnas tienen color
/home/skull/go-dist/go/bin/go build ./cmd/bosctl/
./bos setup --demo
# Columna A: fases con ✓ verde, › cyan, ○ slate
# Columna B: fichas instaladas con timestamp dim
# Columna C: logs con [OK] verde, [ERROR] rojo, [WARN] amarillo
```

---

### PASO 3 — Unificar fuente de versiones de fichas ✅ COMPLETADO 2026-06-14

**Problema que resuelve:** P-03  
**Estado:** `util/ficha.go:FichaVersions` es la fuente única. `model/phases.go` delega. `screens/helpers.go` limpio.

**Cambios:**
1. `screens/helpers.go`: eliminar `var fichaVersions` (líneas 13–20)
2. `screens/helpers.go`: `VersionSuffix(id)` → `util.VersionSuffix(id)`
3. `screens/s04_confirmar.go` (ex `wizard.go:296`): `fichaVersions[f]` → `util.FichaVersions[f]`
4. `screens/s05_instalando.go` (ex `installing.go:420`): `fichaVersions[fd.ID]` → `util.FichaVersions[fd.ID]`

**Criterio de done:**
```bash
grep -rn "fichaVersions" internal/tui/
# → 0 resultados (solo queda FichaVersions en util/)
```

---

### PASO 4 — Reubicar `summaryRow` ✅ COMPLETADO 2026-06-14

**Problema que resuelve:** P-05  
**Estado:** `summaryRow` en `screens/helpers.go:16`. `wizard.go` eliminado.

**Cambios:**
1. Al crear `s01_bienvenida.go` en P0: NO incluir `summaryRow`
2. Mover `summaryRow` a `screens/helpers.go`
3. Todos los archivos `s0x_*.go` que la usen la encuentran allí (misma package)

**Criterio de done:**
```bash
grep -rn "^func summaryRow" internal/tui/screens/
# → solo en helpers.go
grep -rn "summaryRow" internal/tui/screens/ | grep "^func"
# → screens/helpers.go:XX:func summaryRow(...)
```

---

### PASO 5 — Expandir `styles/styles.go` + eliminar inline calls

**Problema que resuelve:** P-04  
**Prioridad:** MEDIA  
**Esfuerzo estimado:** 3–4h (el más largo por volumen)

**Sub-paso 5.1 — Añadir colores y estilos faltantes a `styles/styles.go`:**

```go
// Colores adicionales
const (
    HexSlate2      = "#94a3b8"
    HexWhite2      = "#e2e8f0"
    HexLogInfo     = "#64748b"
    HexTimestamp   = "#334155"
    HexGreenLight  = "#86efac"
    HexGreenMid    = "#4ade80"
    HexBlueDark    = "#1e3a5f"
    HexBlue        = "#3b82f6"
    HexMenuBg      = "#0f2433"
    HexRedLight    = "#fca5a5"
    HexYellowLight = "#fde68a"
)

// Estilos de log
var (
    LogTimestamp = lipgloss.NewStyle().Foreground(ColorTimestamp)
    LogError     = lipgloss.NewStyle().Foreground(ColorRed)
    LogWarn      = lipgloss.NewStyle().Foreground(ColorYellow)
    LogInfo      = lipgloss.NewStyle().Foreground(ColorLogInfo)
    LogOKTag     = lipgloss.NewStyle().Foreground(ColorGreen).Bold(true)
)

// Estilos de menú
var (
    MenuActive   = lipgloss.NewStyle().Background(lipgloss.Color(HexMenuBg)).Foreground(ColorCyan).Bold(true).PaddingLeft(1).PaddingRight(2)
    MenuCursor   = lipgloss.NewStyle().Foreground(ColorCyan)
    MenuInactive = lipgloss.NewStyle().Foreground(ColorMuted).PaddingLeft(4)
    MenuHint     = lipgloss.NewStyle().Foreground(ColorDim)
    MenuDesc     = lipgloss.NewStyle().Foreground(ColorMuted).PaddingLeft(6)
)

// Estilos de wizard
var (
    WizardCursor  = lipgloss.NewStyle().Foreground(ColorGreen).Bold(true)
    SectionLabel  = lipgloss.NewStyle().Foreground(ColorDim).Italic(true)
    SummaryLabel  = lipgloss.NewStyle().Foreground(ColorDim).Width(10)
    SummaryValue  = lipgloss.NewStyle().Foreground(ColorWhite)
)

// Estilos de instalación
var (
    ColTitle      = lipgloss.NewStyle().Foreground(ColorWhite2).Bold(true)
    ColTitleDim   = lipgloss.NewStyle().Foreground(ColorSlate2)
    StepTextDone  = lipgloss.NewStyle().Foreground(ColorSlate2)
    StepTextActive= lipgloss.NewStyle().Foreground(ColorWhite2).Bold(true)
    StepTextPend  = lipgloss.NewStyle().Foreground(ColorSlate)
    StepTextErr   = lipgloss.NewStyle().Foreground(ColorRed)
    BorderNormal  = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorSlate)
    BorderFocus   = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(ColorCyan)
)

// Estilos de dashboard
var (
    LiveIndicator = lipgloss.NewStyle().Foreground(ColorGreen).Bold(true)
    BtnLogs       = lipgloss.NewStyle().Foreground(ColorCyan)
    BtnRestart    = lipgloss.NewStyle().Foreground(ColorYellow)
    BtnShutdown   = lipgloss.NewStyle().Foreground(ColorRed)
)
```

**Sub-paso 5.2 — Reemplazar inline calls en cada archivo:**

| Archivo | Instancias | Acción |
|---------|-----------|--------|
| `shared.go` | ~12 | Usar `styles.MenuActive`, `styles.MenuCursor`, etc. |
| `s05_instalando.go` | ~35 | Usar `styles.LogError`, `styles.ColTitle`, `styles.BorderFocus`, etc. |
| `s06_done.go`/`s07_reboot.go`/`s08_boot.go` | ~30 | Usar `styles.SectionLabel`, `styles.Muted`, etc. |
| `s01_bienvenida.go`..`s04_confirmar.go` | ~25 | Usar `styles.WizardCursor`, `styles.SummaryLabel`, etc. |
| `s00_welcome.go`/`s99_goodbye.go` | ~20 | Añadir `SplashTitle`, `SplashProduct`, `SplashLegal` a styles/ |
| `s11_shutdown.go` | ~15 | Usar `styles.BtnLogs`, `styles.LiveIndicator`, etc. |

**Criterio de done:**
```bash
grep -c "lipgloss.NewStyle()" internal/tui/screens/*.go
# → styles/styles.go: N (donde van todas)
# → resto: 0
grep -c "lipgloss.NewStyle()" internal/tui/screens/shared.go internal/tui/screens/installing.go
# → 0  0
```

---

## 5. REGISTRO DE ESTADO

> Actualizar este registro después de cada paso completado.  
> **Formato de estado:** `⬜ PENDIENTE` | `🔄 EN PROGRESO` | `✅ COMPLETADO` | `❌ BLOQUEADO`

### 5.1 Estado de pasos del plan

| Paso | Descripción | Norma/Problema | Estado | Fecha | Notas |
|------|-------------|----------------|--------|-------|-------|
| **P0.5** | Conectar `ctrl/` + eliminar `dashboard.go` | P-07, SCREEN-005 | ✅ COMPLETADO | 2026-06-13 | `s11_shutdown.go` creado, `app.View()` → `ctrl.Render`, todos los tests pasan |
| **P0** | Split screens/ — 1 archivo por pantalla | SCREEN-001 | ✅ COMPLETADO | 2026-06-14 | Todos los sXX.go existen — wizard.go/installing.go/postinstall.go/splash.go eliminados |
| **P1** | Crear `util/` — helpers compartidos | P-02, P-06 | ✅ COMPLETADO | 2026-06-14 | util/format.go + util/ficha.go — duplicaciones eliminadas |
| **P2** | Viewports estilizados desde `app/` | P-01 🔴 bug | ✅ COMPLETADO | 2026-06-14 | app/app.go:syncViewports() — columnas S05 en color |
| **P3** | Unificar `FichaVersions` en `util/` | P-03 | ✅ COMPLETADO | 2026-06-14 | util/ficha.go fuente única — model/phases.go delega |
| **P4** | Mover `summaryRow` a `helpers.go` | P-05 | ✅ COMPLETADO | 2026-06-14 | helpers.go:16 — wizard.go eliminado |
| **P5** | Expandir styles + eliminar inline | P-04, SCREEN-003 | ✅ COMPLETADO | 2026-06-14 | 0 instancias lipgloss.NewStyle() inline — T-100 + C-05/C-06/C-07 |

### 5.2 Inventario de pantallas — estado SCREEN-001 y SCREEN-005

| ID | Archivo actual | Archivo destino | Norma | Paso | Estado |
|----|---------------|-----------------|-------|------|--------|
| S00 | `splash.go` | `s00_welcome.go` | SCREEN-001 | P0 | ✅ COMPLETADO 2026-06-14 |
| S01 | `wizard.go` | `s01_bienvenida.go` | SCREEN-001 + TUI-LIB-001 | Bloque 8 | ✅ COMPLETADO 2026-06-14 — huh.NewSelect |
| S02 | `wizard.go` | `s02_empresa.go` | SCREEN-001 + TUI-LIB-001 | Bloque 8 | ✅ COMPLETADO 2026-06-14 — huh.NewForm 4 inputs |
| S03 | `wizard.go` | `s03_admin.go` | SCREEN-001 + TUI-LIB-001 | Bloque 8 | ✅ COMPLETADO 2026-06-14 — huh+EchoPassword+MFA |
| S03B | `wizard.go` | `s03b_capacidad.go` | SCREEN-001 | P0 | ✅ COMPLETADO 2026-06-14 |
| S04 | `wizard.go` | `s04_confirmar.go` | SCREEN-001 + TUI-LIB-001 | Bloque 8 | ✅ COMPLETADO 2026-06-14 — huh.NewConfirm+Summary |
| S05 | `installing.go` | `s05_instalando.go` | SCREEN-001 | P0 | ✅ COMPLETADO 2026-06-14 — colores via syncViewports ✅ |
| S05B | `installing.go` | `s05b_log.go` | SCREEN-001 | P0 | ✅ COMPLETADO 2026-06-14 |
| S05C | `installing.go` | `s05c_error.go` | SCREEN-001 | P0 | ✅ COMPLETADO 2026-06-14 |
| S06 | `postinstall.go` | `s06_done.go` | SCREEN-001 | P0 | ✅ COMPLETADO 2026-06-14 |
| S07 | `postinstall.go` | `s07_reboot.go` | SCREEN-001 | P0 | ✅ COMPLETADO 2026-06-14 |
| S08 | `postinstall.go` | `s08_boot.go` | SCREEN-001 | P0 | ✅ COMPLETADO 2026-06-14 |
| **S09** | `dashboard.go` | **ELIMINADA** → `ctrl.Render(m.Ctrl)` en `app.View()` | **SCREEN-005** | **P0.5** | ✅ COMPLETADO 2026-06-13 |
| **S10** | `dashboard.go` | **ELIMINADA** → panel `logs` en `ctrl/` | **SCREEN-005** | **P0.5** | ✅ COMPLETADO 2026-06-13 |
| S11 | `dashboard.go` | `s11_shutdown.go` | SCREEN-001 | P0.5 | ✅ COMPLETADO 2026-06-13 |
| S99 | `splash.go` | `s99_goodbye.go` | SCREEN-001 | P0 | ✅ COMPLETADO 2026-06-14 |

### 5.2b Estado de `ctrl/` — ya es atómico (SCREEN-005 + SCREEN-006 ✅)

`ctrl/` NO es objetivo de refactorización. Es el dashboard definitivo del SBOS:

| Subpaquete | Archivos | Estado | Conexión a flujo TUI |
|-----------|---------|--------|----------------------|
| `ctrl/panel/` | 12 paneles | ✅ Atómico | ✅ Conectado (P0.5) |
| `ctrl/k8s/` | 5 paneles | ✅ Atómico | ✅ Conectado (P0.5) |
| `ctrl/sistema/` | 6 paneles | ✅ Atómico | ✅ Conectado (P0.5) |
| `ctrl/dash/` | Infraestructura + `keys.go` | ✅ Correcto | ✅ `DashMenuKeyMap`/`DashBodyKeyMap` + `HelpModel` (Bloque 9) |
| `ctrl/render.go` | Compositor | ✅ Solo ensamblaje | ✅ `renderBottomBar` usa `dm.HelpModel.View(...)` (Bloque 9) |
| **`app/app.go`** | **Bridge** | ✅ `ctrl.Render(m.Ctrl)` | ✅ **Implementado en P0.5** |

Agregar funcionalidad nueva al dashboard → crear archivo en `ctrl/panel/` o `ctrl/k8s/` o `ctrl/sistema/`. No modificar archivos existentes.

### 5.3 Estado de archivos por paquete

#### `styles/`
| Archivo | Estado | Notas |
|---------|--------|-------|
| `tokens_primitive.go` | ✅ Completo | 35+ constantes PrimXxx |
| `tokens_state.go` | ✅ Completo | ✨ 2026-06-14 — 7 estados × 4 tokens = 28 ColorStateXxx independientes |
| `tokens_semantic.go` | ✅ Actualizado | Referencias a ColorStateXxx para success/warning/error/info/critical |
| `tokens_component.go` | ✅ Actualizado | Banners OK/Warn/Err/Crit/Idle + estilo Disabled |
| `grid.go` | ✅ Completo | ColW, ContentW, MarginW, Mode(), Span, Layout* |
| `icons.go` | ✅ Completo | 25+ funciones IconXxx() + SpinnerFrames |
| `doc.go` | ✅ Completo | Documentación del paquete (4-capa design system) |
| `styles.go` | ✅ Re-exports | Compat — re-exporta variables clave del paquete |

#### `tuilog/` (✅ nuevo — 2026-06-14)
| Archivo | Estado | Contenido |
|---------|--------|-----------|
| `tuilog.go` | ✅ Completo | Ring buffer thread-safe (cap 512) + journald backend + BubbleTea integration |
| `tuilog_test.go` | ✅ 51 tests | 100% pasan — Level, Ring, Sub/Watch, parseJSONLine, parseMessage, Follow args |

**tuilog — API pública:**
```go
// Niveles: LevelDebug, LevelInfo, LevelWarn, LevelError, LevelCrit
// Fuentes: SrcTUI, SrcWS, SrcAuth, SrcInstall, SrcBoot, SrcPreflight, SrcUI, SrcObserver

ring := tuilog.NewRing(512)       // journald "bos-tui" (nil en CI)
ring.Info(tuilog.SrcWS, "msg")    // escribe → journald + ring + notifica suscriptores
ring.Entries()                     // snapshot cronológico
ring.Last(n)                       // últimas n entradas
ring.Filter(minLevel)              // entradas ≥ nivel
ring.Sub()                         // chan struct{} — tick cuando llega entrada nueva
tuilog.WatchCmd(ch)                // tea.Cmd — emite TUILogTickMsg al canal
tuilog.Follow("bos.service", 50)   // (<-chan Entry, CancelFunc) — stream journalctl
tuilog.FollowCmd(ch)               // tea.Cmd — emite JournalEntryMsg por entrada
```

**tuilog — integración en el TUI:**
- `model.Model.TUILog *tuilog.Ring` — ring principal; inicializado en `New()`
- `model.Model.TUILogCh chan struct{}` — suscriptor; armado en `New()`
- `model.Model.JournalEntries []tuilog.Entry` — acumulador del Follow() activo
- `model.Model.JournalCh <-chan tuilog.Entry` — canal del Follow(); nil si inactivo
- `ctrl/dash/model.DashModel.TUIRing` — puntero al ring (se pasa por referencia)
- `ctrl/dash/model.DashModel.JournalEntries` — entradas de daemons externos
- `ctrl/panel/logs.go` — usa ambos (TUIRing + JournalEntries) para renderizado
- `ctrl/render.go:renderContainerBody("logs")` — llama `panel.Logs(dm, dm.TUIRing, dm.JournalEntries, w, h)`

#### `util/` ✅ COMPLETO (2026-06-14)
| Archivo | Estado | Contenido |
|---------|--------|-----------|
| `format.go` | ✅ Existe | FormatDur, TruncA, Truncate, WordWrap, MaxInt, BootMessage — fuente canónica |
| `format_test.go` | ✅ Existe | Tests de formato |
| `ficha.go` | ✅ Existe | FichaVersions, VersionSuffix — fuente canónica |
| `ficha_test.go` | ✅ Existe | Tests de ficha |

#### `model/`
| Archivo | Estado | Pendiente (paso) |
|---------|--------|-----------------|
| `update.go` | 🟠 Con deuda | Eliminar ~210 lín duplicadas (P1, P2) — `switchLogTab()` añadido (T-112) |
| `wizard_forms.go` | ✅ Nuevo — 2026-06-14 | `NewWizardP{1-4}Form()` + `WizardP4Summary()` — huh v1.0.0 |
| `phases.go` | 🟡 Fuente a mover | FichaVersions → util/ (P1) |
| `viewport.go` | ✅ OK | — |
| `ws.go` | ✅ OK | — |
| `preflight.go` | ✅ OK | — |
| `sysinfo.go` | ✅ OK | — |
| `model.go` | ✅ OK | — |

#### `screens/` — archivos infraestructura
| Archivo | Estado | Pendiente (paso) |
|---------|--------|-----------------|
| `dispatcher.go` | ✅ OK | Agregar cases para pantallas nuevas futuras |
| `shared.go` | 🟡 Inline styles | Reemplazar 12 inline styles (P5) |
| `helpers.go` | 🟠 Con deuda | Eliminar duplicados (P1), recibir summaryRow (P4) |

#### `screens/` — archivos de pantalla (P0 ✅ COMPLETADO 2026-06-14)
| Archivo | Estado | Inline styles restantes (P5) |
|---------|--------|-------------------------------|
| `s00_welcome.go` | ✅ Existe (P0) | ~10 instancias |
| `s01_bienvenida.go` | ✅ Existe (Bloque 8) | ~5 instancias |
| `s02_empresa.go` | ✅ Existe (Bloque 8) | ~5 instancias |
| `s03_admin.go` | ✅ Existe (Bloque 8) | ~8 instancias |
| `s03b_capacidad.go` | ✅ Existe (P0) | ~5 instancias |
| `s04_confirmar.go` | ✅ Existe (Bloque 8) | ~7 instancias |
| `s05_instalando.go` | ✅ Existe (P0) | ~20 instancias |
| `s05b_log.go` | ✅ Existe (P0) | ~5 instancias |
| `s05c_error.go` | ✅ Existe (P0) | ~10 instancias |
| `s06_done.go` | ✅ Existe (P0) | ~20 instancias |
| `s07_reboot.go` | ✅ Existe (P0) | ~5 instancias |
| `s08_boot.go` | ✅ Existe (P0) | ~5 instancias |
| `s09_dashboard.go` | ✅ ELIMINADA — `ctrl.Render()` (P0.5) | — |
| `s10_logs.go` | ✅ ELIMINADA — panel logs ctrl/ (P0.5) | — |
| `s11_shutdown.go` | ✅ Existe (P0.5) | ~3 instancias |
| `s99_goodbye.go` | ✅ Existe (P0) | ~10 instancias |
| `sauth_login.go` | ✅ Existe (Bloque 7) | — |
| `sauth_confirm.go` | ✅ Existe (Bloque 7) | — |

#### `app/`
| Archivo | Estado | Pendiente (paso) |
|---------|--------|-----------------|
| `app.go` | ✅ Completo | syncViewports() implementado (P2 ✅) — conecta ctrl.Render + screens |

### 5.4 Métricas de progreso

| Métrica | Línea base (2026-06-13) | Objetivo | Actual (2026-06-14) |
|---------|------------------------|----------|---------------------|
| `ctrl/` conectado al flujo TUI | ❌ No | ✅ Sí | **✅** |
| `screens/dashboard.go` eliminado | ❌ Existe | ✅ Eliminado | **✅** |
| Design system — archivos `styles/` | 2 (styles.go, icons.go) | 8 | **✅ 8** |
| Sistema de colores de estado independiente | ❌ No | ✅ tokens_state.go | **✅** |
| Paquete tuilog (journald + ring + BubbleTea) | ❌ No existe | ✅ Completo | **✅ 51 tests** |
| Panel logs integrado con tuilog.Ring | ❌ No | ✅ Sí | **✅** |
| `huh` instalado + wizard migrado (TUI-LIB-001) | ❌ No | ✅ huh + S01-S04 propios | **✅ huh v1.0.0** |
| `bubbles/help` en wizard + dashboard (TUI-LIB-004) | ❌ No | ✅ HelpModel ambos | **✅** |
| `DashMenuKeyMap`/`DashBodyKeyMap` exportados | ❌ No | ✅ `ctrl/dash/keys.go` | **✅** |
| Tabs del panel logs conectados a journald Follow | ❌ No | ✅ switchLogTab() | **✅** |
| Archivos que violan SCREEN-001 | 5 | 0 | **✅ 0** |
| Pantallas en archivo incorrecto | 14 | 0 | **✅ 0** |
| Pantallas en su propio archivo | 0 | 14 | **✅ 14** |
| Líneas duplicadas en `model/update.go` | ~211 | 0 | **✅ 0** (util/ resuelve P-02) |
| Instancias `lipgloss.NewStyle()` inline en screens/ | 126 | 0 | **0** ✅ (T-100 completado) |
| Fuentes de `fichaVersions`/`FichaVersions` | 2 | 1 | **✅ 1** — `util/ficha.go` |
| Fuentes de `FormatDur` | 2 | 1 | **✅ 1** — `util/format.go` |
| Viewports S05 con colores lipgloss | ❌ No | ✅ Sí | **✅** — syncViewports en app/ |
| P0 SCREEN-001 split completo | ❌ No | ✅ Sí | **✅** — todos los sXX.go creados |
| P1 util/ paquete hoja creado | ❌ No | ✅ Sí | **✅** — format.go + ficha.go |
| Build limpio | ✅ | ✅ | ✅ |
| Tests pasando | ✅ | ✅ | ✅ (tuilog 51 + util + screens + app) |

---

## 6. MANUAL DE USO

> Cómo usar el TUI de BOS como herramienta profesional para pruebas reales del SBOS

---

### 6.0 Arquitectura de sesión — fundamentos

#### Principio central: el daemon es el estado, el TUI es un cliente

BOS sigue el mismo patrón que los sistemas de administración más robustos del ecosistema Linux:

| Sistema | Daemon | Cliente TUI | Autenticación |
|---------|--------|-------------|---------------|
| **Cockpit** (Red Hat) | `cockpit-ws` (systemd) | Navegador web | PAM / SSO |
| **k9s** | `kube-apiserver` (K8s) | TUI stateless | kubeconfig / OIDC |
| **systemd-manager-tui** | `systemd` (D-Bus) | TUI stateless | D-Bus policy |
| **BOS** | `bos.service` (systemd) | `bosctl` (TUI) | bAuth (OIDC/LoA) |

**Consecuencia directa:** el TUI (`bosctl dashboard`) es **stateless**. No necesita persistir nada. El estado vive en `bos.service`. Si el admin cierra la terminal y vuelve a conectarse, el dashboard muestra el estado real porque lo lee del daemon en cada reconexión.

#### Mecanismo de persistencia de sesión

La investigación de estándares y comparativas 2026 confirma que para un daemon soberano de producción existen **dos capas de persistencia independientes**:

```
CAPA 1 — Persistencia del DAEMON (siempre activa)
───────────────────────────────────────────────────
bos.service     → systemd Type=simple, Restart=on-failure
                → estado en .sbos_state.json (fcntl.flock)
                → Unix socket /run/bos/bos.sock (no desaparece)

Resultado: el daemon no necesita TUI para existir.
El estado del sistema siempre está disponible vía socket.


CAPA 2 — Persistencia de SESIÓN DE TERMINAL (opcional, para admins remotos)
─────────────────────────────────────────────────────────────────────────────
tmux / Zellij   → sesión del shell del admin sobrevive a desconexión SSH
                → el admin puede: ssh → tmux attach → bosctl dashboard
                → si la conexión cae, el proceso bosctl sigue en el pane tmux

Comparativa 2026 (investigado):
  tmux    → maduro, scriptable, ideal para servidores, sin dependencias extra
  Zellij  → Rust, mejor UX, WebAssembly plugins, KDL config — más moderno
  screen  → legacy, solo para compatibilidad

Recomendación para BOS: tmux como capa 2 (ya instalado en el ecosistema SBOS).
Zellij como alternativa futura si el stack lo adopta.
```

**Por qué NO depender de tmux para el state del TUI:** si el proceso `bosctl` muere (crash, kill), la sesión tmux queda vacía pero el daemon sigue corriendo. Al reconectar con `bosctl dashboard` + auth, el admin vuelve al mismo estado porque el daemon nunca perdió nada.

#### Autenticación — bAuth como guardián del dashboard

`bosctl dashboard` es el centro de comandos del BOS. Acceso NO autorizado = control total del sistema. Por eso toda sesión requiere autenticación vía **bAuth** antes de mostrar el dashboard.

Patrón tomado de **Cockpit** (Red Hat, referencia de la industria):
- Cockpit autentica vía PAM antes de mostrar cualquier panel
- Revoca la sesión por timeout inactivo
- Requiere re-autenticación para operaciones destructivas

BOS sigue el mismo patrón pero usando **bAuth** (Keycloak + H-RBAC) en lugar de PAM:

```
Admin ejecuta: bosctl dashboard
        ↓
[SAuth] Pantalla de login TUI
  → Email + Contraseña
  → MFA token (si LoA ≥ 2 requerido)
  → llamada a bAuth Unix socket: bauth.session.create
        ↓
Token de sesión en memoria (duración: 8h o hasta Ctrl+C)
        ↓
CTRL Dashboard (acceso completo)
        ↓
Operación destructiva (restart / shutdown):
  → Re-autenticación inline (LoA Step-Up — RFC 9470)
  → Confirmación explícita con contraseña
        ↓
S11 Restart/Shutdown
```

#### Niveles de LoA requeridos por operación

| Operación | LoA mínimo | Re-auth |
|-----------|-----------|---------|
| Ver dashboard (métricas, logs) | LoA 1 (email+pass) | No |
| Navegar paneles K8s, procesos | LoA 1 | No |
| Pausar/reanudar fichas | LoA 2 (+ MFA) | No (si sesión LoA2) |
| Reiniciar el sistema | LoA 3 (+ MFA + confirmación) | Sí — Step-Up |
| Apagar el sistema | LoA 3 (+ MFA + confirmación) | Sí — Step-Up |
| Desinstalar BOS | LoA 4 (máximo) | Sí — Step-Up |

---

### 6.1 Modos de operación

El TUI tiene **4 modos de entrada**, controlados por el comando y los flags:

```bash
# Modo 1 — Instalación interactiva (producción)
bosctl setup

# Modo 2 — Demo completa sin instalar nada (desarrollo/pruebas de UI)
bosctl setup --demo

# Modo 3 — Instalación desatendida desde seed file
bosctl setup --unattended --seed-file /etc/sbos/seed.json

# Modo 4 — Dashboard del sistema ya instalado (requiere auth)
bosctl dashboard
```

---

### 6.2 Secuencias de pantallas por proceso

> **Estado:** PROPUESTA — pendiente de revisión y aprobación por el humano.  
> Las secuencias marcadas con `❓` no tienen diseño definido todavía.  
> Las secuencias marcadas con `✅` están implementadas o definidas.

**Nueva pantalla transversal — SAuth (autenticación):**
Aparece en TODOS los procesos que involucran el dashboard. Es el guardián.
Ver diseño completo en §6.0.

---

#### PROCESO 1 — Instalación (`bosctl setup`) ✅

La instalación NO requiere SAuth porque el administrador que instala es el que
crea las credenciales del sistema — es la única sesión sin autenticación previa.

```
[S00] Splash
  → preflight en background
  → si preflight falla → muestra errores en S00, no avanza

[S01] Bienvenida
  → menú: [ Comenzar ] [ Salir ]
  → Salir → [S99] Goodbye

[S02] Empresa
  → Razón Social · NIT/RUC · País (ISO 2) · Dominio
  → Esc → [S01]

[S03] Admin
  → Email · Nombre · Contraseña · Confirmar · toggle MFA
  → Esc → [S02]

[S03B] Capacidad
  → Tenants · Empresas/Tenant · Sucursales/Empresa · Usuarios/Sucursal
  → calcula recursos K8s necesarios
  → Esc → [S03]

[S04] Confirmar
  → resumen completo + menú: [ Instalar ] [ Volver ] [ Salir ]
  → Volver → [S03B]
  → Salir  → [S99] Goodbye

[S05] Instalando ←── eventos WebSocket del daemon bos
  ├── L → [S05B] Log expandido
  │         └── Esc → [S05]
  ├── E → [S05C] Error (solo si hay error activo)
  │         ├── Reintentar → [S05]
  │         └── Salir → [S99]
  └── al completar → [S06] Done

[S06] Done
  → resumen post-instalación (tabs: Acceso / Pasos / Log)
  → menú: [ Reiniciar ahora ] [ Ver logs ] [ Salir ]
  → Ver logs      → [S05B]
  → Salir         → [S99]
  → Reiniciar     → [S07]

[S07] Reboot countdown
  → contador 10s, cancelable con Esc → [S06]
  → al llegar a 0 → [S08]

[S08] Boot progress
  → barra de arranque del stack (systemd → K8s → fichas → daemons)
  → al completar → CTRL Dashboard
  (nota: la instalación entrega el dashboard directamente — el admin
   ya está autenticado implícitamente por haber instalado el sistema)

CTRL Dashboard  (ctrl.Render — 22 paneles, datos vivos)
  → tecla S → [SAuthConfirm] → [S11] Shutdown
  → tecla R → [SAuthConfirm] → [S11] Restart
  → tecla Q → [S99] Goodbye
```

---

#### PROCESO 2 — Observador / Centro de comandos (`bosctl dashboard`) ✅

Siempre requiere autenticación. El dashboard es el centro de comandos del BOS.
Ningún usuario sin credenciales puede acceder a él.

```
Admin ejecuta: bosctl dashboard
        ↓
[SAuth] Pantalla de login
  → Email + Contraseña
  → si MFA activo → campo TOTP o push bnotify
  → llamada: bauth.session.create (Unix socket /run/bos/bauth.sock)
  → si credenciales inválidas → error inline, reintento
  → si bloqueado (3 intentos) → [S99] con mensaje de bloqueo
  → si OK → token de sesión LoA 1–2 en memoria

[S08] Boot progress  (verificación del estado actual del sistema)
  → barra de carga: lee estado real del daemon vía /run/bos/bos.sock
  → al completar → CTRL Dashboard

CTRL Dashboard  (ctrl.Render — 22 paneles, datos vivos)
  → timeout inactivo 30min → cierra sesión → [SAuth]
  → tecla S → [SAuthConfirm LoA3] → [S11] Shutdown
  → tecla R → [SAuthConfirm LoA3] → [S11] Restart
  → tecla Q → [S99] Goodbye
```

---

#### PROCESO 3 — Apagado (desde dashboard, tecla `S`) ✅

```
CTRL Dashboard
  → S presionado → advertencia inline: "¿Apagar el sistema?"

[SAuthConfirm]  (Step-Up LoA 3 — RFC 9470)
  → "Confirme su contraseña para continuar"
  → si MFA activo → TOTP requerido
  → Cancelar → vuelve a CTRL Dashboard
  → si OK → continúa

[S11] Shutdown  (modo=shutdown, color=rojo)
  → secuencia inversa: daemons → Context Plane → Seguridad →
    Stack de datos → K8s → Ubuntu
  → barra de progreso + panel lateral: estado + advertencia Ctrl+C
  → al completar → [S99] Goodbye
  → OS apaga el servidor
```

---

#### PROCESO 4 — Reinicio (desde dashboard, tecla `R`) ✅

```
CTRL Dashboard
  → R presionado → advertencia inline: "¿Reiniciar el sistema?"

[SAuthConfirm]  (Step-Up LoA 3 — RFC 9470)
  → igual que Apagado
  → Cancelar → vuelve a CTRL Dashboard
  → si OK → continúa

[S11] Restart  (modo=restart, color=amarillo)
  → misma secuencia de apagado ordenado
  → al completar → kernel reinicia automáticamente
  → (la sesión bosctl termina — el admin debe reconectarse)

[SAuth]  (reconexión post-reinicio)
  → Admin vuelve a ejecutar: bosctl dashboard
  → nuevo login

[S08] Boot progress  (nuevo arranque)
  → al completar → CTRL Dashboard
```

---

#### PROCESO 5 — Desinstalación (`bosctl uninstall`) ❓ PROPUESTA

```
[SAuth]  (LoA 4 — máximo nivel)
  → credenciales + MFA + código de confirmación enviado a email

[SX0] Advertencia de desinstalación
  → "ADVERTENCIA: Esta acción es irreversible"
  → listado de qué se eliminará vs qué se conserva (backups)
  → campo: "Escriba 'DESINSTALAR' para confirmar"
  → menú: [ Confirmar ] [ Cancelar ]
  → Cancelar → [S99]

[SX1] Desinstalando  (color=rojo, estructura visual similar a S05)
  → secuencia: fichas → daemons → K8s → datos → configuración
  → progreso por pasos con resultado de cada uno
  → si falla → opción de abortar desinstalación + diagnóstico

[SX2] Desinstalado
  → resumen: qué se eliminó, ruta de backups conservados
  → → [S99] Goodbye
  → sistema queda limpio (Ubuntu virgen)
```

---

#### PROCESO 6 — Reparación (`bosctl repair`) ❓ PROPUESTA

```
[SAuth]  (LoA 2)

[SY0] Diagnóstico automático
  → BOS escanea: fichas DEGRADADA/ERROR, drift de config, heath checks
  → lista de problemas detectados con severidad
  → si no hay problemas → mensaje OK → [S99] / volver al CTRL

[SY1] Plan de reparación
  → pasos que se ejecutarán con compensación (sagas)
  → menú: [ Reparar ] [ Cancelar ]
  → Cancelar → [S99]

[SY2] Reparando  (similar a S05 pero solo fichas afectadas)
  → si repair falla → rollback automático → diagnóstico del fallo
  → al completar → CTRL Dashboard (con estado reparado)
```

---

#### PROCESO 7 — Actualización (`bosctl update`) ❓ PROPUESTA

```
[SAuth]  (LoA 2)

[SZ0] Versiones disponibles
  → lista de fichas con actualización + versión actual vs nueva + changelog
  → si no hay actualizaciones → mensaje + [S99]

[SZ1] Selección + confirmación
  → checkbox por ficha: cuáles actualizar
  → advertencia de downtime esperado
  → menú: [ Actualizar seleccionadas ] [ Actualizar todas ] [ Cancelar ]

[SZ2] Actualizando  (similar a S05 para las fichas seleccionadas)
  → rollback automático si falla (regresa a versión anterior estable)
  → → [SZ3] Resultado

[SZ3] Resultado
  → resumen: actualizado ✓ / rollback ↩ / error ✗ por ficha
  → → CTRL Dashboard
```

---

#### Tabla resumen — pantallas por proceso

| Proceso | Comando | Flujo de pantallas | Auth | Estado |
|---------|---------|-------------------|------|--------|
| Instalación | `bosctl setup` | S00→S01→S02→S03→S03B→S04→S05(B/C)→S06→S07→S08→CTRL | Sin auth (crea las credenciales) | ✅ |
| Observador | `bosctl dashboard` | SAuth→S08→CTRL | LoA 1-2 | ✅ |
| Apagado | tecla `S` en CTRL | CTRL→SAuthConfirm(LoA3)→S11(shutdown)→S99 | LoA 3 Step-Up | ✅ |
| Reinicio | tecla `R` en CTRL | CTRL→SAuthConfirm(LoA3)→S11(restart)→S08→CTRL | LoA 3 Step-Up | ✅ |
| Desinstalación | `bosctl uninstall` | SAuth(LoA4)→SX0→SX1→SX2→S99 | LoA 4 | ❓ |
| Reparación | `bosctl repair` | SAuth(LoA2)→SY0→SY1→SY2→CTRL | LoA 2 | ❓ |
| Actualización | `bosctl update` | SAuth(LoA2)→SZ0→SZ1→SZ2→SZ3→CTRL | LoA 2 | ❓ |

#### Nueva pantalla requerida: SAuth

| Pantalla | Archivo destino | Función pública | Descripción |
|----------|----------------|-----------------|-------------|
| **SAuth** | `sauth_login.go` | `RenderAuthLogin(m)` | Login: Email + Contraseña + TOTP opcional |
| **SAuthConfirm** | `sauth_confirm.go` | `RenderAuthConfirm(m)` | Re-auth inline para operaciones destructivas (Step-Up) |

Ambas pantallas son `screens/` normales (SCREEN-001), comunican con bAuth vía
Unix socket `/run/bos/bauth.sock` usando `bauth.session.create` y `bauth.session.stepup`.

---

### 6.3 Teclas por pantalla

#### Todas las pantallas
| Tecla | Acción |
|-------|--------|
| `Ctrl+C` | Salir inmediato |

#### S01 — Bienvenida
| Tecla | Acción |
|-------|--------|
| `↑` `↓` | Navegar entre Comenzar / Salir |
| `Enter` | Seleccionar opción |
| `Esc` | Salir |

#### S02 — Empresa
| Tecla | Acción |
|-------|--------|
| `Tab` / `↑` `↓` | Campo siguiente / anterior |
| `Enter` | Continuar (valida los campos) |
| `Esc` | Volver a S01 |

Campos: Razón Social, NIT/RUC, País (2 letras), Dominio (ej: empresa.com)

#### S03 — Admin
| Tecla | Acción |
|-------|--------|
| `Tab` / `↑` `↓` | Campo siguiente / anterior |
| `M` | Toggle MFA (activa sbos-notifier) |
| `Enter` | Continuar |
| `Esc` | Volver a S02 |

Campos: Email, Nombre, Contraseña, Confirmar contraseña, MFA toggle

#### S03B — Capacidad
| Tecla | Acción |
|-------|--------|
| `Tab` / `↑` `↓` | Campo siguiente |
| `Enter` | Calcular y continuar |
| `Esc` | Volver a S03 |

Campos: Tenants, Empresas/Tenant, Sucursales/Empresa, Usuarios/Sucursal

#### S04 — Confirmar
| Tecla | Acción |
|-------|--------|
| `↑` `↓` | Navegar entre Instalar / Volver / Salir |
| `Enter` | Seleccionar |
| `Esc` | Volver a S03B |

#### S05 — Instalando (pantalla principal de pruebas)
| Tecla | Acción |
|-------|--------|
| `Tab` | Cambiar panel activo (Fases → Pasos → Log) |
| `↑` `↓` / `K` `J` | Scroll en panel activo |
| `PgUp` `PgDn` | Scroll rápido |
| `L` | Ver log completo (S05B) |
| `E` | Ver panel de error (S05C) — solo si hay error |
| `T` | Toggle timestamps en log |
| `R` | Reintentar bootstraph (resume) |
| `Ctrl+C` | Cancelar instalación |

**3 columnas de S05:**
```
┌──────────────┬──────────────┬──────────────┐
│ COL A        │ COL B        │ COL C        │
│ Árbol fases  │ Pasos activos│ Log en vivo  │
│              │ de la ficha  │ con colores  │
│ N0 ✓ OS     │ › instalar   │ [OK] postgre │
│ N1 › Data   │   postgresql │ [INFO] redis │
│   › postgre  │ ○ configurar │ [WARN] cert  │
│   ○ redis   │              │              │
└──────────────┴──────────────┴──────────────┘
```

**Indicadores de estado en Col A:**
```
✓  verde   — fase/ficha completada
›  cyan    — fase/ficha activa (instalando ahora)
○  slate   — fase/ficha pendiente
✗  rojo    — fase/ficha con error
```

#### S05B — Log Completo
| Tecla | Acción |
|-------|--------|
| `↑` `↓` | Scroll |
| `G` | Ir al final (tail) |
| `T` | Toggle timestamps |
| `L` | Volver a S05 |

#### S05C — Panel de Error
| Tecla | Acción |
|-------|--------|
| `↑` `↓` | Scroll en detalle de error |
| `E` | Volver a S05 |
| `L` | Ver log completo (S05B) |
| `R` | Reintentar la ficha fallida |

#### S09 — Dashboard
| Tecla | Acción |
|-------|--------|
| `L` | Ver logs del sistema (S10) |
| `R` | Reiniciar (secuencia de apagado+arranque) |
| `S` | Apagar sistema |
| `Ctrl+C` | Salir del TUI (daemon sigue corriendo) |

#### S10 — Logs del Sistema
| Tecla | Acción |
|-------|--------|
| `/` | Buscar en logs |
| `G` | Ir al final |
| `T` | Toggle timestamps |
| `Q` | Volver al dashboard |

---

### 6.4 Modo Demo — Pruebas sin servidor real

El modo demo simula el flujo completo de instalación usando `demo/demo.go`. Es la herramienta principal para verificar el TUI sin necesidad de un servidor K8s ni el daemon bos corriendo.

```bash
# Ejecutar demo desde el repositorio (sin instalar)
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src
/home/skull/go-dist/go/bin/go run ./cmd/bosctl/ setup --demo

# Ejecutar demo en modo dev (requisitos no bloquean)
go run ./cmd/bosctl/ setup --demo --mode dev
```

**Qué verifica el modo demo:**
- Todas las pantallas del wizard (S01–S04) con navegación real
- Transición a S05 con eventos simulados del daemon
- Instalación de fichas con progreso real (retardos simulados)
- Panel de error con la ficha `kong` (siempre falla en el demo para probar S05C)
- Transición a S06 Done → S07 Reboot → S08 Boot → S09 Dashboard

**Secuencia de fichas en el demo:**
```
N0: sbos-bootstrap-os
N1: postgresql ✓ → redis ✓ → minio ✓ → mysql ✓
N2: keycloak ✓ → vault ✓
N3: kong ✗ (error simulado) → retry → kong ✓
N4: linkerd ✓
N5: prometheus ✓ → grafana ✓ → alertmanager ✓ → alloy ✓
N6: nginx ✓ → certbot ✓
```

---

### 6.5 Prueba con daemon real — Checklist pre-lanzamiento

Antes de ejecutar `bosctl setup` en un servidor real:

```bash
# 1. Verificar que el daemon bos está compilado
ls -la /usr/local/bin/bos  # o: which bos

# 2. Verificar conectividad del socket (si el daemon ya corre)
ls -la /run/bos/bos.sock

# 3. Verificar que bosctl puede conectar
BOS_SOCKET=/run/bos/bos.sock bosctl ficha status postgresql

# 4. Verificar preflight (dependencias del SO)
bosctl ficha status bos-preflight

# 5. Ejecutar setup
bosctl setup
```

**Variables de entorno útiles:**
```bash
BOS_SOCKET=/ruta/custom/bos.sock  # Override del socket Unix
BOS_DEV_SKIP_ROOT=1               # Saltar chequeo de root (desarrollo)
```

---

### 6.6 Interpretación de la pantalla S05 durante pruebas reales

#### Columna A — Árbol de fases

El árbol muestra 7 fases (N0–N6) y 22 fichas en orden de instalación del DAG:

```
N0 — Sistema Operativo         (1 ficha:  sbos-bootstrap-os)
N1 — Datos                     (4 fichas: postgresql, redis, minio, mysql)
N2 — Identidad y Secretos      (2 fichas: keycloak, vault)
N3 — Gateway y Conectividad    (2 fichas: kong, nginx)
N4 — Service Mesh              (1 ficha:  linkerd)
N5 — Observabilidad            (4 fichas: prometheus, grafana, alertmanager, alloy)
N6 — TLS y Aplicaciones        (2 fichas: certbot, ...)
```

**Qué verificar aquí:**
- Que las fases progresan en orden (N0 → N1 → N2...)
- Que no hay fichas saltadas (todas deben aparecer)
- Que los errores muestran `✗` inmediatamente

#### Columna B — Pasos activos

Muestra los pasos (`task_catalog.sh`) de la ficha activa en tiempo real:

```
postgresql 18.4
  ✓ Crear namespace (0:03)
  › Aplicar PersistentVolume...
  ○ Verificar health
  ○ Registrar en bos-state
```

**Qué verificar:**
- Pasos con tiempo (`0:03`) = completados con duración
- `›` = paso activo en este momento
- Si un paso se queda en `›` más de 5 minutos = posible cuelgue → revisar logs

#### Columna C — Log en vivo

Muestra la salida combinada del daemon bos y los `task_catalog.sh`:

```
[13:42:01] [OK] postgresql — namespace creado
[13:42:04] [INFO] Aplicando PersistentVolume claim...
[13:42:07] [WARN] Timeout esperando pod, reintentando...
[13:42:09] [OK] postgresql — pod Running
[13:42:10] [OK] postgresql — health check OK
[13:42:11] [OK] postgresql 18.4 instalada (0:10)
```

**Colores de log:**
```
verde  — [OK] [SUCCESS] — paso exitoso
cyan   — [INFO]         — información general
azul   — [DEBUG]        — debug detallado
slate  — [STEP]         — inicio de sub-paso
rojo   — [ERROR] [FAIL] — fallo
amarillo — [WARN]       — advertencia (no fatal)
```

---

### 6.7 Resolución de problemas comunes

#### TUI no arranca / pantalla en blanco
```bash
# 1. Verificar que la terminal es suficientemente ancha
stty size  # debe ser al menos 80x24

# 2. Forzar terminal explícita
TERM=xterm-256color bosctl setup

# 3. Verificar /dev/tty
ls -la /dev/tty
```

#### Daemon no disponible (error en S05)
```bash
# El TUI intenta auto-arrancar el daemon — si falla:
# 1. Arrancar manualmente
sudo bos &

# 2. Esperar socket
watch -n1 'ls -la /run/bos/bos.sock'

# 3. Re-ejecutar setup
bosctl setup
```

#### Instalación cuelgue en una ficha
```bash
# En otra terminal, ver logs del daemon:
journalctl -u bos.service -f

# Ver estado de fichas:
bosctl ficha status postgresql

# Forzar repair:
bosctl ficha repair postgresql
```

#### Reinstalar desde cero
```bash
# 1. Borrar estado de instalación
sudo rm -f /etc/sbos/tenant.conf

# 2. Desinstalar fichas (si necesario)
bosctl ficha remove postgresql redis ...

# 3. Volver a ejecutar
bosctl setup
```

---

### 6.8 Seed file para pruebas automatizadas

```json
{
  "razon_social": "SKULL Labs S.A.",
  "nit": "1234567890",
  "pais": "BO",
  "dominio": "skulllabs.local",
  "email": "admin@skulllabs.local",
  "nombre": "Administrador SBOS",
  "password": "Admin2026!Sbos",
  "mfa": true
}
```

```bash
# Usar en instalación desatendida (CI/CD, scripts de prueba)
bosctl setup --unattended --seed-file /etc/sbos/seed.json

# Con socket custom (entorno nspawn):
BOS_SOCKET=/run/bos-test/bos.sock bosctl setup --unattended --seed-file seed.json
```

---

### 6.9 Verificación post-instalación

Después de que S05 complete y el sistema entre en S09 (Dashboard):

```bash
# Verificar fichas instaladas
bosctl ficha status

# Verificar daemons SBOS
systemctl status bos.service bkernel.service biedata.service bauth.service

# Verificar stack K8s
kubectl get pods -A

# Verificar puertos (SBOS-050)
ss -tlnp | grep -E ':5432|:6379|:8080|:8200|:8000|:9443'

# Verificar context plane (SBOS-049)
curl -s http://localhost:9443/health | python3 -m json.tool
```

---

### 6.10 Responsividad del TUI

El TUI adapta su layout según el ancho del terminal:

| Modo | Ancho | Layout S05 | Layout Wizard |
|------|-------|------------|---------------|
| `xs` | < 60 cols | 1 columna + scroll | Formulario compacto |
| `sm` | 60–79 cols | 2 columnas (A+C) | Formulario normal |
| `md` | ≥ 80 cols | 3 columnas (A+B+C) | Formulario + ayuda |

**Mínimo recomendado para producción:** 80×24 (terminal estándar).  
**Óptimo para ver las 3 columnas:** 120×40 o más.

```bash
# Cambiar tamaño de terminal para probar responsividad
# (en la mayoría de emuladores de terminal)
printf '\e[8;40;80t'   # 80x40
printf '\e[8;40;120t'  # 120x40
printf '\e[8;50;200t'  # 200x50

# O desde resize:
resize -s 40 120
```

---

## 7. DESIGN SYSTEM — `styles/`

> **Fundamento normativo:** W3C Design Tokens Specification v1.0 (estable, Oct 2025) ·
> Material Design 3 · IBM Carbon Design System · WCAG 2.2 contrast ratios  
> **Estado:** PROPUESTA — pendiente de revisión y aprobación por el humano.

---

### 7.1 Principios del Design System

1. **Token único = fuente de verdad.** Un color existe una sola vez en el sistema. Si cambia, cambia en un solo lugar y se propaga a todos los componentes.
2. **Tres capas, dirección única.** Pantallas → Componentes → Semánticos → Primitivos. Nunca al revés.
3. **Contraste WCAG AA mínimo.** Texto sobre fondo: ratio ≥ 4.5:1 (normal) o ≥ 3:1 (grande/bold).
4. **Truecolor + fallback 256.** El sistema usa hex (#rrggbb). Lipgloss convierte a 256-color si el terminal no soporta truecolor.
5. **Grid de 12 columnas.** Todo layout se expresa en columnas del grid, nunca en píxeles ni caracteres hardcodeados.

---

### 7.2 Paleta Primitiva — Capa 1

> Valores crudos. **Nunca se usan directamente en pantallas ni componentes.**
> Solo los tokens semánticos (§7.3) pueden referenciarlos.

#### Escala de fondo (oscuro sobre oscuro — SBOS usa dark theme)

```go
// Escala BG — de más oscuro a más claro
const (
    PrimBg0    = "#080f1a"  // fondo base — pantalla completa
    PrimBg1    = "#0d1526"  // superficie — cards, panels
    PrimBg2    = "#111d35"  // elevado — modales, dropdowns
    PrimBg3    = "#1e293b"  // overlay — divisores, bordes
    PrimMenuBg = "#0f2433"  // sidebar/menú de navegación
)
```

#### Escala de texto (neutros — slate)

```go
const (
    PrimSlate50  = "#f8fafc"  // texto principal
    PrimSlate100 = "#f1f5f9"
    PrimSlate200 = "#e2e8f0"  // texto secundario
    PrimSlate300 = "#cbd5e1"  // subtítulos
    PrimSlate400 = "#94a3b8"  // bordes normales
    PrimSlate500 = "#64748b"  // texto muted / placeholder
    PrimSlate600 = "#475569"  // deshabilitado
    PrimSlate700 = "#334155"  // timestamp, dim
    PrimSlate800 = "#1e293b"  // = PrimBg3
    PrimSlate900 = "#0f172a"  // casi negro
)
```

#### Paleta de marca (cyan — color primario del SBOS)

```go
const (
    PrimCyan300 = "#67e8f9"
    PrimCyan400 = "#22d3ee"  // PRIMARIO — acciones, activo, focus
    PrimCyan500 = "#06b6d4"
    PrimCyan600 = "#0891b2"
)
```

#### Estados y semáforos

```go
const (
    // Verde — éxito, OK, completado
    PrimGreen300 = "#86efac"  // variante clara (texto sobre oscuro)
    PrimGreen400 = "#4ade80"  // estándar
    PrimGreen500 = "#22c55e"

    // Amarillo — advertencia, reinicio
    PrimYellow300 = "#fde68a"  // variante clara
    PrimYellow400 = "#facc15"  // estándar
    PrimYellow500 = "#eab308"

    // Rojo — error, apagado, peligro
    PrimRed300 = "#fca5a5"    // variante clara
    PrimRed400 = "#f87171"    // estándar
    PrimRed500 = "#ef4444"

    // Azul — información, K8s
    PrimBlue300 = "#93c5fd"
    PrimBlue400 = "#60a5fa"   // estándar
    PrimBlue500 = "#3b82f6"
    PrimBlueDark = "#1e3a5f"  // fondo de celdas K8s

    // Púrpura — auth, identidad
    PrimPurple300 = "#d8b4fe"
    PrimPurple400 = "#c084fc"

    // Naranja — métricas, rendimiento
    PrimOrange300 = "#fdba74"
    PrimOrange400 = "#fb923c"
)
```

---

### 7.3 Tokens Semánticos — Capa 2

> Asignan **intención** a los primitivos. Son los que usa el sistema de estilos.
> **Cambiar el tema = solo cambiar esta capa.** Ver §7.12 para el sistema de temas completo.

```go
// ── Texto ────────────────────────────────────────────────────────────────────
const (
    ColorTextPrimary   = PrimSlate50   // contenido principal
    ColorTextSecondary = PrimSlate200  // etiquetas, subtítulos
    ColorTextMuted     = PrimSlate500  // pistas, placeholders
    ColorTextDisabled  = PrimSlate600  // deshabilitado
    ColorTextInverse   = PrimBg0       // texto sobre fondos claros
)

// ── Fondo ────────────────────────────────────────────────────────────────────
const (
    ColorBgBase     = PrimBg0   // fondo de pantalla completa
    ColorBgSurface  = PrimBg1   // cards, paneles
    ColorBgElevated = PrimBg2   // modales, overlays
    ColorBgBorder   = PrimBg3   // bordes estructurales
    ColorBgMenu     = PrimMenuBg
)

// ── Marca / Interactivo ──────────────────────────────────────────────────────
const (
    ColorBrandPrimary = PrimCyan400  // acción principal, focus, activo
    ColorBrandLight   = PrimCyan300  // hover, variante clara
    ColorBrandDark    = PrimCyan600  // pressed
)

// ── Estados ──────────────────────────────────────────────────────────────────
const (
    ColorSuccess      = PrimGreen400
    ColorSuccessLight = PrimGreen300
    ColorWarning      = PrimYellow400
    ColorWarningLight = PrimYellow300
    ColorError        = PrimRed400
    ColorErrorLight   = PrimRed300
    ColorInfo         = PrimBlue400
    ColorInfoLight    = PrimBlue300
)

// ── Bordes ───────────────────────────────────────────────────────────────────
const (
    ColorBorderDefault = PrimSlate400
    ColorBorderActive  = PrimCyan400
    ColorBorderError   = PrimRed400
    ColorBorderSuccess = PrimGreen400
)

// ── Log ──────────────────────────────────────────────────────────────────────
const (
    ColorLogTimestamp = PrimSlate700
    ColorLogInfo      = PrimSlate500
    ColorLogSuccess   = PrimGreen400
    ColorLogWarn      = PrimYellow400
    ColorLogError     = PrimRed400
    ColorLogSource    = PrimCyan400
)
```

---

### 7.4 Tokens de Componente — Capa 3

> Estilos lipgloss concretos. Únicos que las pantallas importan y usan.

```go
// ── Tipografía (estilos base) ─────────────────────────────────────────────────
var (
    TextPrimary   = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextPrimary))
    TextSecondary = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextSecondary))
    TextMuted     = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextMuted))
    TextBold      = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextPrimary)).Bold(true)
    TextDim       = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextMuted)).Faint(true)
)

// ── Indicadores de estado ─────────────────────────────────────────────────────
var (
    StatusSuccess = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorSuccess)).Bold(true)
    StatusWarn    = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorWarning)).Bold(true)
    StatusError   = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorError)).Bold(true)
    StatusInfo    = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorInfo))
    StatusMuted   = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextMuted))
)

// ── Bordes y paneles ──────────────────────────────────────────────────────────
var (
    BoxDefault = lipgloss.NewStyle().
        Border(lipgloss.RoundedBorder()).
        BorderForeground(lipgloss.Color(ColorBorderDefault))

    BoxActive = lipgloss.NewStyle().
        Border(lipgloss.RoundedBorder()).
        BorderForeground(lipgloss.Color(ColorBorderActive))

    BoxError = lipgloss.NewStyle().
        Border(lipgloss.RoundedBorder()).
        BorderForeground(lipgloss.Color(ColorBorderError))

    PanelDiv = lipgloss.NewStyle().
        Foreground(lipgloss.Color(ColorBgBorder))
)

// ── Menú / Navegación (sidebar ctrl/) ────────────────────────────────────────
var (
    MenuBg = lipgloss.NewStyle().
        Background(lipgloss.Color(ColorBgMenu))

    MenuItemActive = lipgloss.NewStyle().
        Background(lipgloss.Color(ColorBgMenu)).
        Foreground(lipgloss.Color(ColorBrandPrimary)).
        Bold(true).PaddingLeft(1).PaddingRight(2)

    MenuItemInactive = lipgloss.NewStyle().
        Foreground(lipgloss.Color(ColorTextMuted)).PaddingLeft(4)

    MenuCursor = lipgloss.NewStyle().
        Foreground(lipgloss.Color(ColorBrandPrimary))

    MenuHint = lipgloss.NewStyle().
        Foreground(lipgloss.Color(ColorTextDisabled))
)

// ── Formularios / Inputs ──────────────────────────────────────────────────────
var (
    InputDefault = lipgloss.NewStyle().
        Border(lipgloss.RoundedBorder()).
        BorderForeground(lipgloss.Color(ColorBorderDefault))

    InputFocus = lipgloss.NewStyle().
        Border(lipgloss.RoundedBorder()).
        BorderForeground(lipgloss.Color(ColorBrandPrimary))

    InputError = lipgloss.NewStyle().
        Border(lipgloss.RoundedBorder()).
        BorderForeground(lipgloss.Color(ColorError))

    InputLabel    = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextSecondary))
    InputText     = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextPrimary))
    InputHint     = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextMuted)).Italic(true)
    InputErrorMsg = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorError)).Italic(true)
)

// ── Log ───────────────────────────────────────────────────────────────────────
var (
    LogTimestamp = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorLogTimestamp))
    LogInfo      = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorLogInfo))
    LogOK        = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorLogSuccess)).Bold(true)
    LogWarn      = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorLogWarn))
    LogError     = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorLogError))
    LogSource    = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorLogSource))
)

// ── Stepper / Pasos de instalación ───────────────────────────────────────────
var (
    StepDone    = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorSuccess))
    StepActive  = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorBrandPrimary)).Bold(true)
    StepPending = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextMuted))
    StepError   = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorError))

    StepTextDone   = lipgloss.NewStyle().Foreground(lipgloss.Color(PrimSlate400))
    StepTextActive = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextPrimary)).Bold(true)
    StepTextPend   = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextMuted))
)

// ── Columnas de instalación (S05) ─────────────────────────────────────────────
var (
    ColTitle    = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextPrimary)).Bold(true)
    ColTitleDim = lipgloss.NewStyle().Foreground(lipgloss.Color(PrimSlate400))
    ColBorderN  = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color(ColorBorderDefault))
    ColBorderF  = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color(ColorBrandPrimary))
)

// ── Botones ───────────────────────────────────────────────────────────────────
var (
    BtnPrimary = lipgloss.NewStyle().
        Foreground(lipgloss.Color(ColorBrandPrimary)).
        Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color(ColorBrandPrimary)).
        Padding(0, 1)

    BtnDanger = lipgloss.NewStyle().
        Foreground(lipgloss.Color(ColorError)).
        Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color(ColorError)).
        Padding(0, 1)

    BtnWarning = lipgloss.NewStyle().
        Foreground(lipgloss.Color(ColorWarning)).
        Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color(ColorWarning)).
        Padding(0, 1)

    BtnSuccess = lipgloss.NewStyle().
        Foreground(lipgloss.Color(ColorSuccess)).
        Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color(ColorSuccess)).
        Padding(0, 1)
)

// ── Pantalla de apagado/reinicio ──────────────────────────────────────────────
var (
    ShutdownBar   = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorError))
    ShutdownTitle = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorErrorLight)).Bold(true)
    RestartBar    = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorWarning))
    RestartTitle  = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorWarningLight)).Bold(true)
    WarnInline    = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorError)).Italic(true)
)

// ── Pantalla de auth ──────────────────────────────────────────────────────────
var (
    AuthTitle    = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorBrandPrimary)).Bold(true)
    AuthSubtitle = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextSecondary))
    AuthLock     = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorWarning))
    AuthBlocked  = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorError)).Bold(true)
)

// ── TopBar / Header ───────────────────────────────────────────────────────────
var (
    TopBarBg     = lipgloss.NewStyle().Background(lipgloss.Color(ColorBgSurface))
    TopBarTitle  = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextPrimary)).Bold(true)
    TopBarAccent = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorBrandPrimary))
    TopBarDim    = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextMuted))
)

// ── Dashboard live indicator ──────────────────────────────────────────────────
var (
    LiveDot     = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorSuccess)).Bold(true)
    LiveLabel   = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextMuted))
    MetricValue = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorBrandPrimary)).Bold(true)
    MetricLabel = lipgloss.NewStyle().Foreground(lipgloss.Color(ColorTextMuted))
)
```

---

### 7.5 Grid de 12 columnas — `styles/grid.go`

**Nuevo archivo a crear:** `internal/tui/styles/grid.go`

```go
// Package styles — grid.go: sistema de grid de 12 columnas para el TUI.
// Inspirado en CSS Grid / Bootstrap pero adaptado a terminales de texto.
// Toda pantalla que necesite layout debe usar estas funciones.
package styles

// Breakpoints (en caracteres de ancho de terminal)
const (
    BPxs = 60   // < 60   → sin grid, columna única, sin margen
    BPsm = 80   // 60–79  → grid activo, 1 col margen cada lado
    BPmd = 120  // 80–119 → grid activo, 2 col margen (referencia)
    BPlg = 160  // ≥ 120  → grid activo, columnas anchas
)

// ColW retorna el ancho en caracteres de N columnas del grid de 12.
// Es la función base de todo el sistema de layout.
func ColW(termW, cols int) int {
    if termW < 1 || cols < 1 {
        return 0
    }
    unit := termW / 12
    if unit < 1 {
        unit = 1
    }
    return unit * cols
}

// ContentW retorna el ancho del área de contenido (8/12 del total).
// Los 4 cols restantes son 2 de margen izquierdo + 2 de margen derecho.
func ContentW(termW int) int {
    if termW < BPsm {
        return termW  // en xs no hay margen, todo es contenido
    }
    if termW < BPmd {
        return ColW(termW, 10)  // sm: 1 col margen cada lado
    }
    return ColW(termW, 8)  // md/lg: 2 col margen cada lado
}

// MarginW retorna el ancho de UN margen lateral según el modo.
func MarginW(termW int) int {
    if termW < BPsm {
        return 0
    }
    if termW < BPmd {
        return ColW(termW, 1)
    }
    return ColW(termW, 2)
}

// Span retorna el ancho exacto de N columnas del grid.
// Equivalente a col-N en Bootstrap CSS.
func Span(termW, cols int) int {
    return ColW(termW, cols)
}

// Mode retorna el breakpoint activo como string ("xs"/"sm"/"md"/"lg").
// Fuente única de breakpoints — reemplaza la función Mode() de shared.go.
func Mode(termW int) string {
    switch {
    case termW >= BPlg:
        return "lg"
    case termW >= BPmd:
        return "md"
    case termW >= BPsm:
        return "sm"
    default:
        return "xs"
    }
}

// Layouts predefinidos más comunes
func LayoutTwoCol(termW int) (left, right int) {
    c := ContentW(termW)
    return ColW(c, 8), ColW(c, 4)  // 8+4 = ratio 2:1
}

func LayoutThreeCol(termW int) (a, b, c int) {
    cw := ContentW(termW)
    col := cw / 3
    return col, col, cw - col*2  // A, B, C (C absorbe residuo)
}

func LayoutSidebar(termW, sidebarCols int) (main, sidebar int) {
    c := ContentW(termW)
    s := ColW(c, sidebarCols)
    return c - s - 1, s  // -1 por separador
}
```

---

### 7.6 Responsive — breakpoints y variantes de layout

**Regla:** Toda pantalla usa `styles.Mode(m.Width)` — nunca valores numéricos directos.

```
termW < 60  (xs) — Móvil o ventana muy pequeña
├── Sin margen lateral
├── Sin columnas múltiples
├── Formularios en una sola columna
├── S05 Instalando: solo columna C (log) con scroll
└── Dashboard: solo panel activo, sin menú lateral

termW 60–79 (sm) — Terminal estándar mínimo
├── Margen: 1 col cada lado (~5–6 chars)
├── S05: columna A + columna C (sin B)
├── Wizard: formulario con etiquetas alineadas
└── Dashboard: menú colapsado (solo iconos)

termW 80–119 (md) — Terminal estándar recomendado ← REFERENCIA
├── Margen: 2 cols cada lado (~13–16 chars)
├── S05: las 3 columnas completas (A + B + C)
├── Wizard: formulario + panel de ayuda lateral
└── Dashboard: menú expandido + panel completo

termW ≥ 120 (lg) — Terminal ancho / pantalla grande
├── Margen: 2 cols cada lado (más anchas)
├── S05: 3 columnas con más espacio para logs
├── Dashboard: menú + panel + panel de detalles
└── Modo multi-panel disponible
```

---

### 7.7 Contraste y accesibilidad — WCAG 2.2 AA

La paleta primitiva cumple los ratios mínimos de contraste sobre el fondo base (`PrimBg0 = #080f1a`):

| Token semántico | Color | Ratio vs BG0 | WCAG nivel |
|----------------|-------|-------------|-----------|
| `ColorTextPrimary` | `#f8fafc` | ~18:1 | AAA ✅ |
| `ColorTextSecondary` | `#e2e8f0` | ~14:1 | AAA ✅ |
| `ColorTextMuted` | `#64748b` | ~4.7:1 | AA ✅ |
| `ColorBrandPrimary` | `#22d3ee` | ~9.3:1 | AAA ✅ |
| `ColorSuccess` | `#4ade80` | ~10.1:1 | AAA ✅ |
| `ColorWarning` | `#facc15` | ~11.2:1 | AAA ✅ |
| `ColorError` | `#f87171` | ~6.8:1 | AA ✅ |
| `ColorTextDisabled` | `#475569` | ~3.2:1 | AA (large) ⚠️ |

`ColorTextDisabled` cumple solo para texto grande (≥14pt bold o ≥18pt normal). En terminal, toda fuente es monoespaciada — se considera "large" cuando está en bold.

---

### 7.8 Estructura de archivos del Design System

```
internal/tui/styles/                           ← ✅ ESTADO ACTUAL (2026-06-14)
│
├── tokens_primitive.go   ← ✅ CAPA 1: PrimXxx — valores crudos hex (35+ constantes)
├── tokens_state.go       ← ✅ CAPA 2A: ColorStateXxx — colores de estado INDEPENDIENTES
│                              7 estados × 4 tokens: OK, Warn, Err, Info, Crit, Idle, Off
│                              No derivados de PrimXxx — hex propios por accesibilidad WCAG
├── tokens_semantic.go    ← ✅ CAPA 2B: ColorXxx — intención; referencias ColorStateXxx
├── tokens_component.go   ← ✅ CAPA 3: estilos lipgloss para componentes
├── grid.go               ← ✅ Sistema de grid 12 cols + breakpoints + Mode()
├── icons.go              ← ✅ 25+ funciones IconXxx() + SpinnerFrames
├── doc.go                ← ✅ Documentación del paquete (4-capa design system)
└── styles.go             ← ✅ Re-exports de compat (mínimo)
```

**Estado de migración:**
- `styles.go` ya no tiene lógica propia — delegó todo a los 4 archivos de tokens + grid + icons
- La función `Mode()` vive en `styles/grid.go` — `shared.go` puede importar `styles.Mode()`
- Todos los componentes (`ctrl/`, `screens/`) consumen tokens de capa 3 (`tokens_component.go`)
- Los colores de estado (`tuilog`, `ctrl/panel/logs.go`, dashboards) usan `ColorStateXxxFg/Bg/Border/Subtle`

---

### 7.9 Sistema de Iconos — `styles/icons.go`

**Problema identificado:** Los íconos están dispersos en ≥15 archivos como literales
Unicode hardcodeados con estilos inline. Esto produce:

- Inconsistencias: `✓` (U+2713) y `✔` (U+2714) usados como sinónimos para "éxito"
- Emojis frágiles (`📦`, `🚀`) que fallan en terminales sin emoji support
- Imposible cambiar un ícono globalmente — hay que buscar en todos los archivos
- Colores duplicados: `lipgloss.NewStyle().Foreground(ColorGreen).Render("✔")` repetido 20+ veces

**Solución:** Un único archivo `styles/icons.go` es el único lugar donde se define
qué símbolo Unicode representa cada concepto. Cambiar un ícono = editar una línea.

---

#### 7.9.1 Inventario de íconos actuales (auditoría 2026-06-13)

**En `styles/styles.go` (funciones existentes):**

| Función | Símbolo | Unicode | Color | Uso |
|---------|---------|---------|-------|-----|
| `IconOK()` | `✓` | U+2713 | green | éxito, completado |
| `IconRun()` | `›` | U+203A | cyan | cursor activo, ejecutando |
| `IconPending()` | `○` | U+25CB | slate | pendiente, en espera |
| `IconErr()` | `✗` | U+2717 | red | error, fallo |
| `IconWarn()` | `⚠` | U+26A0 | yellow | advertencia |
| `IconBos()` | `⬡` | U+2B21 | cyan | daemon BOS (hexágono) |

**Hardcodeados en `screens/` y `ctrl/`:**

| Símbolo | Unicode | Archivos | Problema |
|---------|---------|----------|----------|
| `✔` | U+2714 | ctrl/* (15+ usos) | **Duplica** a `✓` (U+2713) — misma semántica, distinto char |
| `●` | U+25CF | shared.go, ctrl/render.go | Punto activo — sin función en styles |
| `↺` | U+21BA | s11_shutdown.go, postinstall.go | Reiniciar — sin función |
| `↻` | U+21BB | ctrl/sistema, ctrl/panel | Sincronizando/aplicando — sin función |
| `⏻` | U+23FB | s11_shutdown.go | Apagado/power — sin función |
| `>` | U+003E | ctrl/render.go | Cursor ASCII — sin función |
| `📦` | U+1F4E6 | installing.go, model/update.go | Emoji inestable — reemplazar |
| `🚀` | U+1F680 | model/update.go | Emoji inestable — reemplazar |

**Total: 8 íconos huérfanos + 1 duplicado + 2 emojis problemáticos.**

---

#### 7.9.2 Estándar de referencia — dos fuentes

**Fuente A — Unicode Standard (sin dependencia de fuente)**

Símbolos del Plano Básico Multilingüe (BMP) que funcionan en cualquier terminal
con soporte UTF-8, incluyendo OpenSSH, tmux, tty puro:

| Bloque Unicode | Rango | Símbolos disponibles |
|---------------|-------|---------------------|
| Miscellaneous Symbols | U+2600–U+26FF | ⚠ ⚡ ✦ ♦ ⚙ ★ |
| Dingbats | U+2700–U+27BF | ✓ ✗ ✔ ✖ ✘ ➜ ➤ |
| Geometric Shapes | U+25A0–U+25FF | ● ○ ◆ ◇ ■ □ ▶ ▸ |
| Arrows | U+2190–U+21FF | → ← ↑ ↓ ↺ ↻ ⇒ |
| Misc Technical | U+2300–U+23FF | ⏻ ⏼ ⏽ ⏾ ⌚ ⌛ |
| Enclosed Alphanumeric Sup | U+1F100–U+1F1FF | ① ② ③ ④ ⑤ |
| Miscellaneous Symbols Ext | U+2B00–U+2BFF | ⬡ ⬢ ⬣ ⬤ |

Referencia: [r-lib/clisymbols](https://github.com/r-lib/clisymbols) y
[ehmicky/cross-platform-terminal-characters](https://github.com/ehmicky/cross-platform-terminal-characters)

**Fuente B — Nerd Fonts (requiere fuente parcheada, Tier B opcional)**

Nerd Fonts parchea 67+ familias tipográficas con 10,000+ íconos de:
Font Awesome 6, Material Design Icons, Octicons, Devicons, Codicons, etc.
Requiere detección en runtime (verificar variable `TERM`, `NERD_FONTS`, o enviar
carácter de prueba y medir ancho con `wcwidth`).

Para SBOS: **Tier A es obligatorio. Tier B es opt-in** (detección automática).

---

#### 7.9.3 Catálogo canónico — `styles/icons.go`

Organizado por categoría. Todos los íconos son Tier A (Unicode puro, sin emoji).
El archivo expone funciones, no variables, para aplicar color en el momento de render.

```go
// styles/icons.go — Catálogo único de íconos del TUI SBOS.
// REGLA: todo ícono del TUI proviene de aquí. Ningún archivo de screens/
// o ctrl/ puede declarar símbolos Unicode/emoji inline.
package styles

import "github.com/charmbracelet/lipgloss"

// ── Categoría: Estado ──────────────────────────────────────────────────────
// Símbolos de estado operativo de servicios y fichas.

func IconOK() string   { return lipgloss.NewStyle().Foreground(ColorGreen).Render("✓") }  // U+2713
func IconErr() string  { return lipgloss.NewStyle().Foreground(ColorRed).Render("✗") }    // U+2717
func IconWarn() string { return lipgloss.NewStyle().Foreground(ColorYellow).Render("⚠") } // U+26A0
func IconInfo() string { return lipgloss.NewStyle().Foreground(ColorCyan).Render("›") }   // U+203A

// ── Categoría: Actividad ───────────────────────────────────────────────────
// Símbolos de ciclo de vida: activo, pendiente, sincronizando.

func IconActive()  string { return lipgloss.NewStyle().Foreground(ColorGreen).Render("●") }   // U+25CF
func IconPending() string { return lipgloss.NewStyle().Foreground(ColorSlate).Render("○") }   // U+25CB
func IconSync()    string { return lipgloss.NewStyle().Foreground(ColorYellow).Render("↻") }  // U+21BB
func IconDone()    string { return lipgloss.NewStyle().Foreground(ColorGreen).Render("✓") }   // alias semántico de IconOK

// ── Categoría: Acciones del sistema ───────────────────────────────────────

func IconPower()   string { return lipgloss.NewStyle().Foreground(ColorRed).Render("⏻") }    // U+23FB
func IconRestart() string { return lipgloss.NewStyle().Foreground(ColorYellow).Render("↺") } // U+21BA
func IconRun()     string { return lipgloss.NewStyle().Foreground(ColorCyan).Render("›") }   // U+203A

// ── Categoría: Fichas / Paquetes ──────────────────────────────────────────
// Reemplazo de emojis 📦 y 🚀 (inestables en terminales sin emoji support).

func IconFicha()     string { return lipgloss.NewStyle().Foreground(ColorCyan).Render("◆") }   // U+25C6
func IconBootstrap() string { return lipgloss.NewStyle().Foreground(ColorGreen).Render("▶") }  // U+25B6
func IconInstall()   string { return lipgloss.NewStyle().Foreground(ColorGreen).Render("↑") }  // U+2191
func IconUpdate()    string { return lipgloss.NewStyle().Foreground(ColorYellow).Render("↑") } // U+2191 (amarillo)
func IconRepair()    string { return lipgloss.NewStyle().Foreground(ColorYellow).Render("⚙") } // U+2699
func IconDelete()    string { return lipgloss.NewStyle().Foreground(ColorRed).Render("✗") }    // alias de IconErr

// ── Categoría: Navegación / Cursor ────────────────────────────────────────

func IconCursor()   string { return lipgloss.NewStyle().Foreground(ColorCyan).Render("›") }    // U+203A
func IconArrowR()   string { return lipgloss.NewStyle().Foreground(ColorMuted).Render("→") }   // U+2192
func IconArrowD()   string { return lipgloss.NewStyle().Foreground(ColorMuted).Render("↓") }   // U+2193
func IconSep()      string { return lipgloss.NewStyle().Foreground(ColorSlate).Render("│") }   // U+2502

// ── Categoría: Daemons SBOS ───────────────────────────────────────────────
// Identificadores visuales de cada daemon soberano.

func IconBos()     string { return lipgloss.NewStyle().Foreground(ColorCyan).Render("⬡") }    // U+2B21 — hexágono
func IconBAuth()   string { return lipgloss.NewStyle().Foreground(ColorGreen).Render("⊕") }   // U+2295 — identidad
func IconBKernel() string { return lipgloss.NewStyle().Foreground(ColorCyan).Render("⊙") }    // U+2299 — kernel/WAL
func IconBiedata() string { return lipgloss.NewStyle().Foreground(ColorYellow).Render("⊗") }  // U+2297 — gateway
func IconBSearch() string { return lipgloss.NewStyle().Foreground(ColorCyan).Render("◎") }    // U+25CE — búsqueda
func IconBNexus()  string { return lipgloss.NewStyle().Foreground(ColorMuted).Render("⊘") }   // U+2298 — nexus/proxy
func IconBNotify() string { return lipgloss.NewStyle().Foreground(ColorYellow).Render("◇") }  // U+25C7 — notificaciones

// ── Categoría: Seguridad / Auth ────────────────────────────────────────────

func IconLock()    string { return lipgloss.NewStyle().Foreground(ColorYellow).Render("⊡") }  // U+22A1
func IconKey()     string { return lipgloss.NewStyle().Foreground(ColorYellow).Render("✦") }  // U+2726
func IconShield()  string { return lipgloss.NewStyle().Foreground(ColorGreen).Render("⬡") }   // U+2B21 (alias BOS)
func IconMFA()     string { return lipgloss.NewStyle().Foreground(ColorCyan).Render("⊕") }    // U+2295

// ── Categoría: Progreso ────────────────────────────────────────────────────

// SpinnerFrames es el conjunto de frames para animaciones de espera.
// Uso: frame := styles.SpinnerFrames[tick%len(styles.SpinnerFrames)]
var SpinnerFrames = []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"} // Braille dots
```

---

#### 7.9.4 Consolidaciones obligatorias

| Situación actual | Acción requerida |
|-----------------|-----------------|
| `✔` (U+2714) en ctrl/* (15+ usos) | → Reemplazar por `styles.IconOK()` |
| `📦` en installing.go + model/update.go | → Reemplazar por `styles.IconFicha()` |
| `🚀` en model/update.go | → Reemplazar por `styles.IconBootstrap()` |
| `●` hardcodeado en shared.go, render.go | → Reemplazar por `styles.IconActive()` |
| `↺` hardcodeado en s11_shutdown, postinstall | → Reemplazar por `styles.IconRestart()` |
| `↻` hardcodeado en ctrl/ | → Reemplazar por `styles.IconSync()` |
| `⏻` hardcodeado en s11_shutdown | → Reemplazar por `styles.IconPower()` |
| `>` ASCII cursor en ctrl/render.go | → Reemplazar por `styles.IconCursor()` |
| `lipgloss.NewStyle().Foreground(X).Render("✓")` inline | → Reemplazar por `styles.IconOK()` |

**Regla de oro:** Si el carácter aparece en más de un archivo, es un ícono y
debe vivir en `styles/icons.go`. No hay excepciones.

---

#### 7.9.5 Detección de Nerd Fonts (Tier B opcional)

```go
// styles/icons.go — detección de Nerd Fonts en runtime
import "os"

// HasNerdFonts detecta si el entorno tiene una fuente Nerd Fonts instalada.
// Comprueba variables de entorno comunes; no envía caracteres de prueba
// (lo cual requeriría modo raw de terminal y complicaría el startup).
func HasNerdFonts() bool {
    for _, v := range []string{"NERD_FONT", "TERM_PROGRAM"} {
        if os.Getenv(v) != "" {
            return true
        }
    }
    return os.Getenv("NERD_FONTS") == "1"
}

// IconOKNF devuelve la versión Nerd Fonts de IconOK si está disponible,
// o el fallback Unicode estándar en caso contrario.
// Úsase solo donde la riqueza visual justifica la complejidad.
func IconOKNF() string {
    if HasNerdFonts() {
        return lipgloss.NewStyle().Foreground(ColorGreen).Render("") // fa-check-circle
    }
    return IconOK()
}
```

**Política SBOS:** Los paneles del dashboard pueden usar Tier B cuando `HasNerdFonts()`.
Las pantallas de instalación usan solo Tier A (accesibilidad: el servidor puede ser
SSH puro sin fuentes patched).

---

#### 7.9.6 Regla de uso para desarrolladores

```
ANTES de usar un carácter Unicode/emoji en cualquier pantalla:
  1. Buscar en styles/icons.go si ya existe una función para ese concepto
  2. Si existe → usar la función (no el literal)
  3. Si no existe → agregar la función a icons.go, luego usarla
  4. Nunca usar emojis multi-codepoint (📦 🚀 🔒) en pantallas TUI
     Solo en mensajes de log donde el rendering se delega al terminal del usuario
```

Esta regla es la causa directa de la inconsistencia `✓`/`✔` actual — se usaron
literales directos porque no se consultó `styles/icons.go` primero.

---

### 7.10 Registro de estado del Design System

| Componente | Estado | Fecha | Notas |
|-----------|--------|-------|-------|
| `tokens_primitive.go` | ✅ Completo | 2026-06-13 | 35+ constantes PrimXxx |
| `tokens_state.go` | ✅ Completo | 2026-06-14 | ✨ NUEVO — 7 estados × 4 tokens independientes de paleta |
| `tokens_semantic.go` | ✅ Actualizado | 2026-06-14 | ColorSuccess/Warning/Error → ColorStateXxx |
| `tokens_component.go` | ✅ Actualizado | 2026-06-14 | Banners OK/Warn/Err/Crit/Idle, Disabled style |
| `grid.go` | ✅ Completo | 2026-06-13 | ColW, ContentW, MarginW, Mode(), Span, Layout* |
| `icons.go` | ✅ Completo | 2026-06-13 | 25+ funciones + SpinnerFrames |
| `doc.go` | ✅ Completo | 2026-06-14 | 4-capa system documentada |
| `styles.go` | ✅ Re-exports | 2026-06-13 | Compat mínimo |
| `screens/shared.go:Mode()` | 🟡 Pendiente | — | Puede delegar a `styles.Mode()` (baja prio) |
| `✔` vs `✓` inconsistencia | 🔴 15+ en ctrl/ | — | Unificar a `styles.IconOK()` en T-021 |
| `📦` `🚀` emojis | 🔴 4 usos | — | Reemplazar con Tier A en T-021 |

**Sistema de colores de estado — 7 estados definidos en `tokens_state.go`:**

| Estado | Descripción | Fg | Bg | Hex base |
|--------|-------------|----|----|----------|
| OK | éxito, operativo | `ColorStateOKFg` | `ColorStateOKBg` | `#2dd4a2` (teal-verde) |
| Warn | advertencia, reintentar | `ColorStateWarnFg` | `ColorStateWarnBg` | `#f9c84a` (ámbar) |
| Err | error, fallo | `ColorStateErrFg` | `ColorStateErrBg` | `#f87474` (coral) |
| Info | informativo, neutral | `ColorStateInfoFg` | `ColorStateInfoBg` | `#5ab8f5` (cielo) |
| Crit | crítico, destructivo | `ColorStateCritFg` | `ColorStateCritBg` | `#ff5555` (rojo vivo) |
| Idle | inactivo, pendiente | `ColorStateIdleFg` | `ColorStateIdleBg` | `#9ea9f8` (índigo) |
| Off | deshabilitado | `ColorStateOffFg` | `ColorStateOffBg` | `#7c8698` (gris) |

---

### 7.11 Paleta Activa: Slate + Cyan — Decisión Formal

> **Decisión adoptada:** 2026-06-14 · **Propuesta por:** bos-developer + humano  
> **Tipo:** Decisión de diseño vinculante para el tema predeterminado del TUI SBOS

#### Rationale

La paleta **slate + cyan** es la identidad visual activa del TUI del IAM Installer.
La elección responde a tres criterios:

| Criterio | Justificación |
|----------|--------------|
| **Semántica visual** | Slate (gris azulado) comunica neutralidad y reposo. Cyan comunica actividad y foco. Juntos forman un vocabulario de "activo / inactivo" sin ambigüedad. |
| **Contraste WCAG AA** | Cyan 500 (#06b6d4) sobre fondos slate 800/900 da ratio ≥ 5.5:1. Slate 600 (#475569) sobre fondo negro da ≥ 4.5:1. Ambos cumplen WCAG 2.2 AA. |
| **Coherencia sistémica** | Cyan es el color de marca del SBOS (logo, documentación, site). Usar cyan como color de foco une la identidad del producto con su interfaz. |

#### Regla de uso

```
SLATE  → elementos inactivos, textos secundarios, bordes en reposo, separadores, timestamps
CYAN   → elementos activos, foco visible, opción seleccionada, highlights, indicadores en vivo
BLANCO → texto principal de alto contraste (valores, nombres, datos críticos)
DIM    → texto muy secundario, pistas contextuales, separadores decorativos
```

#### Tabla de asignación por rol de UI

| Rol de UI | Color | Token semántico |
|-----------|-------|-----------------|
| Borde de caja activa / foco | Cyan 500 | `ColorCyan` → `BoxActive`, `InputActive` |
| Cursor de menú / opción seleccionada | Cyan 500 | `ColorMenuActiveBg` + `ColorCyan` fg |
| Spinner / indicador de progreso | Cyan 500 | `Spinner.Style` |
| Scrollbar thumb activo | Cyan 500 | `VpActiveThumb` |
| Ícono "activo" (●) | Cyan 500 | `styles.IconActive()` |
| Paso del stepper actual | Cyan 500 | `StepActive` |
| URL, botón CTA, texto de acción | Cyan 500 | `styles.Cyan` |
| Borde de caja inactiva | Slate 700 | `ColorSlate` → `Box`, `InputInactive` |
| Texto de opción no seleccionada | Slate 600 | `ColorMuted` → `styles.Muted` |
| Separador de stepper | Slate 700 | `styles.Slate` |
| Paso del stepper pendiente | Slate 700 | `StepPending` |
| Timestamp, labels tenues | Slate 600 | `ColorMuted` |
| Subtítulos, labels de campo | Slate 400 | `ColorSubtitle` → `styles.Subtitle` |
| Texto decorativo / hints | Gris 500 | `ColorDim` → `styles.Dim` |

#### Lo que NO cambia con el tema

Los colores de **estado semántico** son invariantes del diseño — no los toca ningún tema:

```
OK    → #2dd4a2 (teal-verde) — siempre
Warn  → #f9c84a (ámbar)     — siempre
Error → #f87474 (coral)     — siempre
Crit  → #ff5555 (rojo vivo) — siempre
```

Ver §7.10 para la tabla completa. Estos colores son perceptuales — los cambia solo el estándar de accesibilidad, nunca una preferencia de marca.

---

### 7.12 Sistema de Temas — Paleta Personalizable al Inicio

> **Principio:** No-monolítico. El TUI es una interfaz cuyo aspecto visual puede cambiar  
> sin tocar una sola pantalla. Hoy es slate+cyan, mañana puede ser verde o fuchsia.

#### Arquitectura de temas

La clave del sistema es que **solo la Capa 2B (semántica) cambia** cuando se aplica un tema.
La Capa 1 (primitivos) ya contiene TODOS los colores posibles. La Capa 3 (componentes) no
necesita saber nada del tema — consume tokens semánticos y automáticamente hereda la paleta.

```
┌─────────────────────────────────────────────────────────────────┐
│  CAPA 1 — Primitivos (tokens_primitive.go)                      │
│  Paleta completa fija: cyan, verde, fuchsia, índigo, etc.       │
│  NUNCA cambia. Es el catálogo completo de colores disponibles.  │
└──────────────────────────┬──────────────────────────────────────┘
                           │  El tema selecciona qué primitivos
                           │  asignar a cada rol semántico
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  CAPA 2B — Semánticos (tokens_semantic.go)              ← TEMA  │
│                                                                  │
│  ColorAccent    = PrimCyan500    ← TEMA OBSIDIAN (default)      │
│  ColorAccent    = PrimGreen500   ← TEMA ESMERALDA               │
│  ColorAccent    = PrimPink500    ← TEMA FUCHSIA                 │
│  ColorNeutral   = PrimSlate700   ← igual en todos los temas     │
│                                                                  │
│  Esta capa es el ÚNICO punto de intervención del tema.           │
└──────────────────────────┬──────────────────────────────────────┘
                           │  Componentes usan ColorAccent, no PrimCyan
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  CAPA 3 — Componentes (tokens_component.go)                     │
│  BoxActive → BorderForeground(ColorCyan) → heredan el tema ✓    │
│  NO cambia nunca. Ya usa tokens semánticos.                      │
└─────────────────────────────────────────────────────────────────┘
```

#### Qué variables de la Capa 2B definen un tema

Un tema es un conjunto de **4 variables de acento + 1 de fondo de menú**:

```go
// Estructura de tema — solo 5 valores determinan toda la apariencia
type Theme struct {
    Name        string       // identificador único ("obsidian", "esmeralda", "fuchsia")
    Label       string       // nombre visible al usuario
    Accent      lipgloss.Color  // color primario: foco, cursor, CTA
    AccentSub   lipgloss.Color  // variante más oscura del acento (hover, TopBar bg)
    AccentText  lipgloss.Color  // acento más claro (texto sobre fondo oscuro)
    MenuBg      lipgloss.Color  // fondo de menú / opción activa
    // Nota: Neutral (slate) es CONSTANTE en todos los temas
}
```

Los tokens semánticos de acento que cambian con el tema:

| Variable semántica | Rol | Usa en componente |
|--------------------|-----|-------------------|
| `ColorCyan` | acento principal | `BoxActive`, `Cyan`, `StepActive`, `InputActive`, `TopBar.fg` |
| `ColorTopBarBg` | fondo de barra superior | `TopBar.bg` |
| `ColorMenuActiveBg` | fondo de opción seleccionada | `RenderMenu.sActive.bg` |

#### Catálogo de temas incluidos

| Tema | ID | Acento | Neutral | TopBar bg | Descripción |
|------|----|--------|---------|-----------|-------------|
| **Abyss** ⭐ | `abyss` | `PrimCyan400` #22d3ee | `PrimSlate800` | `PrimSlate900` #0f172a | Default — slate profundo + cyan único |
| Obsidian | `obsidian` | `PrimCyan500` #06b6d4 | `PrimSlate700` | `PrimNavy900` #0f172a | Navy profundo + cyan eléctrico (identidad SBOS clásica) |
| Pizarrón | `pizarron` | `PrimCyan400` #22d3ee | `PrimSlate800` | `PrimSlate800` #1e293b | Slate + cyan brillante |
| Esmeralda | `esmeralda` | `PrimGreen500` #22c55e | `PrimSlate700` | `PrimGreen900` #14532d | Verde — marca alternativa |
| Índigo | `indigo` | `PrimIndigo400` #818cf8 | `PrimSlate700` | `PrimIndigo950` #1e1b4b | Violeta — ambiente nocturno |
| Fuchsia | `fuchsia` | `PrimPink500` #ec4899 | `PrimSlate700` | `PrimPink950` #500724 | Rosa — customización viva |
| Ámbar | `ambar` | `PrimAmber400` #fbbf24 | `PrimSlate700` | `PrimGray900` #111827 | Dorado — warmth |

El tema **Abyss** es el default y está completamente implementado.
Los temas restantes son esqueletos reservados con paletas definidas.

#### Cómo seleccionar el tema al inicio

```bash
# Flag de línea de comandos (máxima prioridad)
bosctl setup --theme=esmeralda

# Variable de entorno (segunda prioridad)
SBOS_TUI_THEME=fuchsia bosctl setup

# Archivo de configuración del usuario (tercera prioridad)
# ~/.config/sbos/tui.json
{ "theme": "indigo" }

# Sin configuración → Abyss (default)
bosctl setup
```

#### Cómo implementar el sistema (guía para el desarrollador)

**Paso 1 — Crear el catálogo en `styles/theme.go`:**

```go
// Package styles — theme.go: catálogo de temas y función de aplicación.
package styles

import "github.com/charmbracelet/lipgloss"

// Theme define los 3 tokens de acento que varían entre temas.
// El neutral (slate) y los colores de estado son CONSTANTES.
type Theme struct {
    Name       string
    Label      string
    Accent     lipgloss.Color  // ColorCyan
    TopBarBg   lipgloss.Color  // ColorTopBarBg
    MenuBg     lipgloss.Color  // ColorMenuActiveBg
}

// Catálogo completo de temas disponibles
var Themes = map[string]Theme{
    "abyss": {
        Name: "abyss", Label: "Abyss (default)",
        Accent:   lipgloss.Color(PrimCyan400),
        TopBarBg: lipgloss.Color(PrimSlate900),
        MenuBg:   lipgloss.Color(PrimSlate800),
    },
    "obsidian": {
        Name: "obsidian", Label: "Obsidian",
        Accent:   lipgloss.Color(PrimCyan500),
        TopBarBg: lipgloss.Color(PrimNavy900),
        MenuBg:   lipgloss.Color(PrimNavy800),
    },
    "esmeralda": {
        Name: "esmeralda", Label: "Esmeralda",
        Accent:   lipgloss.Color(PrimGreen500),
        TopBarBg: lipgloss.Color(PrimGreen900),
        MenuBg:   lipgloss.Color(PrimGreen900),
    },
    "indigo": {
        Name: "indigo", Label: "Índigo",
        Accent:   lipgloss.Color(PrimIndigo400),
        TopBarBg: lipgloss.Color(PrimIndigo950),
        MenuBg:   lipgloss.Color(PrimIndigo900),
    },
    "fuchsia": {
        Name: "fuchsia", Label: "Fuchsia",
        Accent:   lipgloss.Color(PrimPink500),
        TopBarBg: lipgloss.Color(PrimPink950),
        MenuBg:   lipgloss.Color(PrimPink900),
    },
    "ambar": {
        Name: "ambar", Label: "Ámbar",
        Accent:   lipgloss.Color(PrimAmber400),
        TopBarBg: lipgloss.Color(PrimGray900),
        MenuBg:   lipgloss.Color(PrimGray800),
    },
}

// ActiveTheme es el tema en uso durante la sesión actual.
// Se establece UNA SOLA VEZ al arrancar mediante ApplyTheme().
var ActiveTheme = Themes["abyss"]

// ApplyTheme actualiza los tokens semánticos de acento.
// DEBE llamarse antes de que cualquier pantalla renderice.
// Después del primer render no tiene efecto visible (las vars ya fueron leídas).
func ApplyTheme(id string) {
    t, ok := Themes[id]
    if !ok {
        t = Themes["abyss"]  // fallback al default
    }
    ActiveTheme = t
    // Mutamos las vars del paquete (seguro: se llama una sola vez, antes del loop TEA)
    ColorCyan         = t.Accent
    ColorTopBarBg     = t.TopBarBg
    ColorMenuActiveBg = t.MenuBg
    // Reconstruir componentes que dependen de estos tokens
    rebuildThemeComponents()
}

// rebuildThemeComponents reconstruye los estilos de Capa 3 que usan el acento.
// Solo los que se definieron con los tokens que ApplyTheme puede cambiar.
func rebuildThemeComponents() {
    Cyan = lipgloss.NewStyle().Foreground(ColorCyan)
    TopBar = lipgloss.NewStyle().
        Background(ColorTopBarBg).
        Foreground(ColorCyan).
        Bold(true).
        Padding(0, 1)
    BoxActive = lipgloss.NewStyle().
        Border(lipgloss.RoundedBorder()).
        BorderForeground(ColorCyan).
        Padding(0, 1)
    InputActive = lipgloss.NewStyle().
        Border(lipgloss.NormalBorder()).
        BorderForeground(ColorCyan).
        Background(ColorBlack).
        Padding(0)
    StepActive = lipgloss.NewStyle().Foreground(ColorCyan).Bold(true)
    StepOK     = lipgloss.NewStyle().Foreground(ColorCyan)
}
```

**Paso 2 — Leer el tema en `cmd/bosctl/setup.go`:**

```go
// Prioridad: flag > env > config file > default
themeID := "obsidian"
if t := os.Getenv("SBOS_TUI_THEME"); t != "" {
    themeID = t
}
if themeFlag != "" {
    themeID = themeFlag
}
styles.ApplyTheme(themeID)
// A partir de aquí, todos los tokens de acento usan el tema seleccionado
app := tui.New(cfg)
p := tea.NewProgram(app, ...)
```

**Paso 3 — Agregar un tema nuevo en el futuro:**

Solo hay que agregar una entrada al mapa `Themes` en `styles/theme.go`.
No se toca ningún archivo de pantalla, ningún componente, ningún handler.

```go
// Ejemplo: tema Coral para marca alternativa
"coral": {
    Name: "coral", Label: "Coral",
    Accent:   lipgloss.Color(PrimOrange400),  // #fb923c
    TopBarBg: lipgloss.Color(PrimOrange950),
    MenuBg:   lipgloss.Color(PrimOrange900),
},
```

#### Invariantes del sistema de temas

Las siguientes variables NUNCA cambian sin importar el tema activo:

```
Colores de texto    → Slate (50–700) — neutral universal
Colores de estado   → tokens_state.go — perceptuales, invariantes
Colores de error    → ColorRed → PrimRed500 — siempre
Fondo base          → ColorBg1/Bg2/Bg3 — estructura invariante
Colores de data     → tablas, K8s, métricas — siempre sus propios tokens
```

#### Verificación de tema activo en pantalla

El `TopBar` muestra el tema activo de forma implícita (su color de fondo = `TopBarBg`).
Para debug, se puede mostrar explícitamente:

```go
// En s00_welcome.go o S01, footer — solo en modo --dev
if m.DevMode {
    themeLabel = styles.Dim.Render("tema: " + styles.ActiveTheme.Label)
}
```

#### Norma de implementación

- `ApplyTheme()` se llama **una sola vez** en el arranque del proceso, antes de `tea.NewProgram()`
- `rebuildThemeComponents()` reconstruye **solo los componentes de Capa 3 que usan acento**
- Los archivos de pantalla (`sXX_*.go`) **NUNCA** referencian `ActiveTheme` directamente
- Ningún handler ni modelo puede llamar `ApplyTheme()` — es operación de inicio, no de runtime
- Agregar un tema nuevo = una entrada en `Themes{}` + una primitiva nueva si hace falta en `tokens_primitive.go`

---

## §8 — Sistema de Menús y Navegación por Teclado

> Normas y catálogo de componentes para toda interacción de selección/formulario
> en el TUI. Un componente mal elegido para un menú = 3x más código y bugs invisibles.

---

### 8.1 Ecosistema disponible — stack Charmbracelet

El proyecto ya usa `bubbles v1.0.0` + `bubbletea v1.3.10` + `lipgloss v1.1.0`.
Estos son los componentes de la familia Charmbracelet aplicables a menús:

| Paquete | Versión en go.mod | Qué aporta |
|---------|-------------------|------------|
| `bubbles/list` | v1.0.0 (incluido) | Lista filtrable con paginación, fuzzy-filter, help auto-generado |
| `bubbles/textinput` | v1.0.0 (incluido) | Campo de texto single-line (ya usado en wizard) |
| `bubbles/viewport` | v1.0.0 (incluido) | Área scrollable (ya usado en model/viewport.go) |
| `bubbles/spinner` | v1.0.0 (incluido) | Indicador de actividad animado (ya usado) |
| `bubbles/progress` | v1.0.0 (incluido) | Barra de progreso (ya usada) |
| `bubbles/key` | v1.0.0 (incluido) | Definición de keybindings + enable/disable dinámico |
| `bubbles/help` | v1.0.0 (incluido) | Vista de ayuda auto-generada desde KeyMap |
| `charmbracelet/huh` | **NO instalado** | Formularios completos: Select, MultiSelect, Input, Confirm, FilePicker |

**`huh` es el componente que falta para menús interactivos tipo dropdown y confirmación.**

---

### 8.2 Catálogo de componentes por tipo de menú

#### 8.2.1 `bubbles/list` — Lista navegable (tipo dropdown grande)

**Cuándo usar:** Listas de más de 5 opciones donde el usuario puede filtrar con búsqueda.
Dashboard: lista de fichas, lista de logs, lista de daemons.

```go
import "github.com/charmbracelet/bubbles/list"

// Crear items
type fichaItem struct{ id, estado, version string }
func (f fichaItem) Title() string       { return f.id }
func (f fichaItem) Description() string { return f.estado + " " + f.version }
func (f fichaItem) FilterValue() string { return f.id }

// Crear lista
items := []list.Item{ fichaItem{"postgresql", "INSTALADA", "v18.4"}, ... }
l := list.New(items, list.NewDefaultDelegate(), width, height)
l.Title = "Fichas SBOS"
l.SetShowStatusBar(true)
l.SetFilteringEnabled(true)   // / para filtrar
l.SetShowHelp(true)           // help auto-generado desde KeyMap
```

**Navegación por teclado (builtin):**
- `↑`/`↓` o `j`/`k` — mover cursor
- `/` — activar filtro (fuzzy)
- `Esc` — cancelar filtro / salir
- `Enter` — seleccionar
- `q` — quit

**Limitación:** No es un dropdown superpuesto (overlay). Es una lista que ocupa
su espacio en el layout. Para overlay real, usar `huh.Select` (§8.2.3).

---

#### 8.2.2 `bubbles/key` + `bubbles/help` — Keybindings declarativos

**Cuándo usar:** En TODA pantalla del TUI. Es la forma canónica de definir y
mostrar atajos de teclado. Ya se usa en `model/keys.go` y `screens/shared.go`.

```go
import (
    "github.com/charmbracelet/bubbles/key"
    "github.com/charmbracelet/bubbles/help"
)

// Definir keymap de una pantalla
type DashboardKeyMap struct {
    Up      key.Binding
    Down    key.Binding
    Select  key.Binding
    Refresh key.Binding
    Quit    key.Binding
}

var DashboardKeys = DashboardKeyMap{
    Up:      key.NewBinding(key.WithKeys("up", "k"),    key.WithHelp("↑/k", "arriba")),
    Down:    key.NewBinding(key.WithKeys("down", "j"),  key.WithHelp("↓/j", "abajo")),
    Select:  key.NewBinding(key.WithKeys("enter"),      key.WithHelp("↵",   "seleccionar")),
    Refresh: key.NewBinding(key.WithKeys("r"),          key.WithHelp("r",   "actualizar")),
    Quit:    key.NewBinding(key.WithKeys("q", "ctrl+c"),key.WithHelp("q",   "salir")),
}

// En Update():
case tea.KeyMsg:
    switch {
    case key.Matches(msg, DashboardKeys.Quit):
        return m, tea.Quit
    case key.Matches(msg, DashboardKeys.Refresh):
        return m, fetchFichasCmd()
    }

// En View() — help auto-generado:
h := help.New()
view += h.View(DashboardKeys)
```

**Ventaja clave:** `key.Binding.SetEnabled(false)` deshabilita una tecla
dinámicamente — útil para deshabilitar "Reiniciar" si no hay permisos LoA 3.

---

#### 8.2.3 `charmbracelet/huh` — Formularios, Select y Confirm

**Por qué es necesario:** `huh` resuelve exactamente el problema de los menús
interactivos tipo dropdown, combobox y confirmación que actualmente el wizard
implementa a mano con `textinput` + lógica de cursor custom (200+ líneas
en `wizard.go` que `huh` reemplazaría con ~20 líneas).

**Versión a instalar:** `github.com/charmbracelet/huh/v2` — v2.0.3 (2026-03-09).
Requiere `bubbletea v2` y `bubbles v2`. **Ver §8.4 sobre compatibilidad.**

**Componentes disponibles en `huh`:**

| Componente | Descripción | Uso en SBOS |
|-----------|-------------|------------|
| `huh.Input` | Campo de texto con validación | Wizard P1: dominio, empresa |
| `huh.Select` | Dropdown/combobox de opciones | Wizard P2: tipo de instalación, plan |
| `huh.MultiSelect` | Selección múltiple con checkboxes | Wizard: módulos opcionales |
| `huh.Confirm` | Pregunta Sí/No | Wizard P4: confirmación; apagado; reinicio |
| `huh.FilePicker` | Selector de archivo | Import de configuración existente |
| `huh.Note` | Texto informativo (solo lectura) | Wizard: resumen de selecciones |

```go
// Ejemplo: Select tipo dropdown
import "github.com/charmbracelet/huh"

var planElegido string

form := huh.NewForm(
    huh.NewGroup(
        huh.NewSelect[string]().
            Title("Plan de instalación").
            Options(
                huh.NewOption("Básico (1 servidor)", "basico"),
                huh.NewOption("Profesional (4 servidores)", "pro"),
                huh.NewOption("Enterprise (16 servidores)", "enterprise"),
            ).
            Value(&planElegido),
    ),
)

// En modo BubbleTea embebido (ADR-020: toda interfaz es dual):
// form.Init() / form.Update() / form.View() se integran al App

// Confirm para operaciones destructivas (reinicio/apagado con LoA 3):
var confirmado bool
confirmar := huh.NewForm(
    huh.NewGroup(
        huh.NewConfirm().
            Title("¿Reiniciar el servidor?").
            Description("Todos los daemons se detendrán ~45 segundos").
            Affirmative("Sí, reiniciar").
            Negative("Cancelar").
            Value(&confirmado),
    ),
)
```

---

#### 8.2.4 Menú lateral del dashboard (`ctrl/dash/`) — menú de navegación propio

El dashboard (`ctrl/`) tiene su propio menú lateral ya implementado en
`ctrl/dash/menu.go` con navegación `↑`/`↓`/`Enter`. **Este NO se reemplaza con
`huh` ni con `bubbles/list`** — es un menú de navegación entre paneles, no un
formulario. Se mantiene como componente propio.

**Patrón actual:** cursor int + lista de strings + lógica en `Update()`.
**Mejora propuesta:** refactorizar usando `bubbles/key` para keybindings
declarativos y `bubbles/help` para mostrar shortcuts activos en el bottom bar.

---

#### 8.2.5 `evertras/bubble-table` — Tabla interactiva

**Cuándo usar:** Vista de fichas con columnas (ID, Estado, Versión, Servidor),
o vista de daemons, o lista de eventos de auditoría.

```
go get github.com/evertras/bubble-table@latest
```

```go
import "github.com/evertras/bubble-table/table"

columns := []table.Column{
    table.NewColumn("id",      "Ficha",    20),
    table.NewColumn("estado",  "Estado",   12),
    table.NewColumn("version", "Versión",   10),
    table.NewColumn("server",  "Servidor",  8),
}
rows := []table.Row{
    table.NewRow(table.RowData{"id": "postgresql", "estado": "INSTALADA", "version": "18.4", "server": "S01"}),
}
t := table.New(columns).WithRows(rows).WithHighlightedColumn("id")
```

Navegación builtin: `↑`/`↓`/`j`/`k`, `PgUp`/`PgDn`, ordenamiento por columna.
No está en go.mod — requiere `go get`.

---

### 8.3 Patrones de navegación por teclado — normas del SBOS TUI

#### Patrón N-01 — Foco entre campos (Tab/Shift+Tab)

```
Tab      → mover foco al siguiente campo/panel
Shift+Tab → mover foco al campo/panel anterior
```

En el wizard actual esto está implementado como `m.WizardFocus++`. Con `huh`
se maneja automáticamente. Para paneles del dashboard se implementa manualmente
con `key.NewBinding(key.WithKeys("tab"), ...)`.

#### Patrón N-02 — Contexto de teclado por pantalla

Cada pantalla/panel tiene su propio `KeyMap`. Las teclas están habilitadas o
deshabilitadas según contexto:

```go
// En ScreenDashboard, si el usuario NO tiene LoA 3:
DashboardKeys.Restart.SetEnabled(false)
DashboardKeys.Shutdown.SetEnabled(false)
// → estas teclas no aparecen en el help view y no responden
```

#### Patrón N-03 — Escape como cancelación universal

```
Esc → cerrar modal / cancelar acción / volver al nivel anterior
```

Este patrón es universal en el SBOS TUI. Todo modal, dropdown overlay,
o confirmación se cierra con `Esc`.

#### Patrón N-04 — Teclas globales (siempre activas)

| Tecla | Acción | Pantalla |
|-------|--------|---------|
| `Ctrl+C` | Salir de emergencia | Todas |
| `F1` o `?` | Toggle ayuda | Dashboard, Installing |
| `q` | Salir limpiamente (solo si no hay ops en progreso) | Dashboard |
| `Esc` | Cancelar / volver | Modales, confirmaciones |

#### Patrón N-05 — Navegación vi (j/k) en listas

En pantallas con listas de más de 5 ítems, siempre ofrecer `j`/`k` como alias
de `↓`/`↑`. Los usuarios de CLI avanzados esperan este patrón (k9s, lazygit, etc.).

#### Patrón N-06 — Enter confirma, Space alterna

```
Enter  → confirmar selección / ejecutar acción
Space  → alternar checkbox / toggle estado (en MultiSelect y toggles)
```

En `huh.MultiSelect` y en el toggle de MFA del wizard, `Space` alterna
y `Enter` confirma el grupo completo.

---

### 8.4 Compatibilidad de versiones — decisión crítica

**Problema:** `huh v2` requiere `bubbletea v2` y `bubbles v2`.
BosAgent usa actualmente `bubbletea v1.3.10` y `bubbles v1.0.0`.

**Opciones:**

| Opción | Ventaja | Riesgo |
|--------|---------|--------|
| **A — Migrar a bt v2 + bubbles v2 + huh v2** | Acceso a todo el ecosistema moderno. Cursed Renderer (mejor performance). | Migración no trivial: cambios de API en v2. Refactorizar model/, screens/. |
| **B — Usar `huh v1` (compatible con bt v1)** | Sin migración. Funciona hoy. | `huh v1` tiene menos features y bugs conocidos que v2 corrige. |
| **C — Implementar Select/Confirm a mano** | Sin dependencias nuevas. Control total. | El wizard actual muestra que esta ruta cuesta 200+ LOC por componente. |

**Recomendación para SBOS:** Opción A cuando se haga el split de pantallas (P0).
La migración a `bubbletea v2` es el momento natural para adoptar `huh v2`.
Mientras tanto, usar Opción B para las pantallas nuevas que lo necesiten (SAuth).

**ADR propuesto:** documentar esta decisión en el catálogo ADR antes de implementar.

---

### 8.5 Mapa de uso — qué componente va en qué pantalla

| Pantalla | Componente de menú/nav | Justificación |
|---------|----------------------|--------------|
| S01 Bienvenida | — | Solo lectura |
| S02 Wizard P1 | `huh.Input` (migración futura) | Campos de texto con validación |
| S03 Wizard P2 | `huh.Select` (migración futura) | Tipo de instalación, plan |
| S04 Wizard P3 | `huh.Input` + `huh.Confirm` (toggle MFA) | Admin account |
| S04B Wizard P3B | `bubbles/key` + cursor custom | Capacidad: slider numérico |
| S05 Wizard P4 | `huh.Note` (resumen) + `huh.Confirm` | Confirmación final |
| S06 Installing | `bubbles/key` + `bubbles/viewport` | Log scroll, ESC=abort |
| S09 Dashboard | `ctrl/dash/menu.go` (propio) + `bubbles/key` | Menú lateral de paneles |
| S09 Panel Fichas | `bubbles/list` | Lista filtrable de fichas |
| S09 Panel Daemons | `evertras/bubble-table` (futuro) | Tabla estado daemons |
| SAuth Login | `huh.Input` (password) | Campo contraseña con echo=false |
| SAuth Confirm | `huh.Confirm` | Confirmación LoA 3 |
| S11 Shutdown | `huh.Confirm` embebido | Confirmación antes de apagar |

---

### 8.6 Registro de estado — componentes de menú

| Componente | Estado | Tarea |
|-----------|--------|-------|
| `bubbles/key` en model/ | ✅ Instalado y usado en `model/keys.go` | Expandir con DashboardKeyMap y SAuthKeyMap |
| `bubbles/help` en model/ | ✅ Instalado y usado en `model/model.go` | Conectar a bottom bar del dashboard |
| `bubbles/list` | ✅ Disponible en bubbles v1.0.0 | **No usado aún** — implementar en panel Fichas |
| `bubbles/textinput` en wizard | ✅ Usado en wizard P1–P3 | Mantener hasta migración a huh |
| `bubbles/viewport` en model/ | ✅ Usado para log scroll | Mantener |
| `huh v1` | ⬜ No instalado | Agregar para SAuth + Wizard P2 Select |
| `evertras/bubble-table` | ⬜ No instalado | Futuro — panel de daemons tabular |
| Menú lateral `ctrl/dash/` | 🟡 Implementado custom | Refactorizar con `bubbles/key` declarativo |
| Toggle MFA en wizard | 🟠 Custom 60-LOC | Reemplazar con `huh.Confirm` en migración |

---

---

## §9 — Registro de Tareas Atómicas

> **Regla de uso:** Una tarea = un PR. Cada tarea tiene una condición de "hecho" verificable.
> El estado se actualiza aquí al completar. Orden = prioridad de ejecución.
>
> Estados: ✅ Hecho · 🔄 En progreso · ⬜ Pendiente · 🔒 Bloqueada (ver deps)

---

### Bloque 0 — Completadas (referencia)

| ID | Tarea | Estado | Norma |
|----|-------|--------|-------|
| T-000 | Conectar `ctrl/` a `ScreenDashboard` en `app/app.go` (Paso 0.5) | ✅ | SCREEN-005 |
| T-001 | Extraer `s11_shutdown.go` de `dashboard.go` | ✅ | SCREEN-001 |
| T-002 | Eliminar `screens/dashboard.go` | ✅ | SCREEN-005 |
| T-003 | Corregir `dispatcher.go` y `dispatcher_test.go` post-eliminación | ✅ | — |

---

### Bloque 1 — Infraestructura (sin estas, nada más avanza)

#### T-010 ✅ — Instalar `charmbracelet/huh`

**Spec:** `go get github.com/charmbracelet/huh@latest` (versión v1 compatible con bubbletea v1.3.10).
Actualiza `go.mod` y `go.sum`. Sin cambios de código.
**Hecho cuando:** `go build ./...` pasa; `go.mod` contiene `charmbracelet/huh` sin sufijo `/v2`.
**Deps:** ninguna.

**Completado 2026-06-13** — `huh v1.0.0` instalado. 5 tests de integración pasan (`app/huh_integration_test.go`).

**API confirmada de huh v1 (diferencias críticas respecto a la documentación):**

| Elemento | API real v1 | ❌ NO usar |
|----------|------------|----------|
| Estado del form | `form.State == huh.StateCompleted` (campo público) | `form.State()` (no es método) |
| Estados disponibles | `huh.StateNormal`, `huh.StateCompleted`, `huh.StateAborted` | — |
| Contraseña | `.EchoMode(huh.EchoModePassword)` | `huh.EchoPassword` (no existe en v1) |
| Modos eco | `huh.EchoModeNormal`, `huh.EchoModePassword`, `huh.EchoModeNone` | — |
| Type-assert en Update | `updatedModel.(*huh.Form)` | — |
| Form completado + abortado | `State == StateAborted` (Esc) | — |

---

#### T-011 ✅ — Crear `internal/tui/util/` — paquete de helpers compartidos

**Spec:** Nuevo paquete hoja `util/` con dos archivos.
`format.go`: mover `FormatDur`, `TruncA`, `WordWrap`, `MaxInt`, `BootMessage` desde `screens/helpers.go` (eliminar copias de `model/update.go`).
`ficha.go`: mover `FichaVersions` como única fuente de verdad (eliminar copia privada de `screens/helpers.go`); `VersionSuffix(id string, m Model) string` usa `util.FichaVersions`.
**Hecho cuando:** `grep -rn "FichaVersions\|FormatDur\|BootMessage" model/update.go` retorna vacío; tests pasan.
**Deps:** ninguna.

---

### Bloque 2 — Design System `styles/`

#### T-020 ✅ — Crear `styles/icons.go`

**Spec:** Extraer las 6 funciones `IconXxx` de `styles.go` al nuevo `styles/icons.go`.
Agregar las funciones faltantes: `IconActive`, `IconSync`, `IconPower`, `IconRestart`, `IconFicha`, `IconBootstrap`, `IconInstall`, `IconUpdate`, `IconRepair`, `IconCursor`, `IconBAuth`, `IconBKernel`, `IconBiedata`, `IconBSearch`, `IconBNexus`, `IconBNotify`, `IconLock`, `IconKey`, `IconMFA` + `var SpinnerFrames`.
Mismo paquete `styles` — sin cambios de importación en consumidores.
**Hecho cuando:** `grep -n "func Icon" styles/icons.go | wc -l` ≥ 20; `go test ./internal/tui/...` pasa.
**Deps:** ninguna.

---

#### T-021 ✅ — Consolidar íconos hardcodeados → `styles.IconXxx()`

**Spec:** Reemplazar en todos los archivos de `screens/` y `ctrl/` los literales Unicode inline (`✔`, `●`, `↺`, `↻`, `⏻`, `📦`, `🚀`) por llamadas a las funciones de `styles/icons.go`.
Unificar `✔` (U+2714) → `styles.IconOK()` (U+2713) en los 15+ usos de `ctrl/`.
**Hecho cuando:** CI gate: `grep -rn '"[✓✗✔✖⚠●○›↺↻⏻⬡◆▶]' internal/tui/screens/ internal/tui/ctrl/ | grep -v icons.go` retorna vacío.
**Deps:** T-020.

---

#### T-022 ✅ — Crear `styles/tokens_primitive.go` + `tokens_semantic.go` + `tokens_component.go` + `grid.go`

**Spec:** Dividir `styles/styles.go` en 4 archivos nuevos según §7 del documento.
`tokens_primitive.go`: 35+ constantes `PrimXxx` (hex puro).
`tokens_semantic.go`: 30+ variables `ColorXxx` que asignan intención a primitivos.
`tokens_component.go`: estilos lipgloss reutilizables (todo lo que hoy está en `styles.go`).
`grid.go`: `ColW`, `ContentW`, `MarginW`, `Mode()` (mover de `screens/shared.go`).
Mantener `styles.go` como re-exportador vacío durante transición para no romper imports.
**Hecho cuando:** `styles/styles.go` tiene 0 LOC de lógica propia (solo re-exports si quedan); `go test ./...` pasa.
**Deps:** T-020.

---

### Bloque 3 — SCREEN-001: un archivo por pantalla

#### T-030 ✅ — Dividir `screens/splash.go` → `s00_welcome.go` + `s99_goodbye.go`

**Spec:** Mover `RenderWelcome` (S00, líneas 21–105) a `screens/s00_welcome.go`.
Mover `RenderGoodbye` (S99, líneas 106–198) a `screens/s99_goodbye.go`.
Eliminar `splash.go`. Actualizar `dispatcher.go` si hay cambios de nombre. Crear test `s00_welcome_test.go` y `s99_goodbye_test.go`.
**Hecho cuando:** `ls screens/splash.go` → "No such file"; 2 nuevos tests pasan.
**Deps:** T-011.

---

#### T-031 ✅ — Dividir `screens/wizard.go` → 5 archivos

**Spec:** Extraer pantallas S01–S04 en archivos separados manteniendo helpers privados en el archivo que los origina.
`s01_bienvenida.go` ← `RenderWizardP1` (línea 30).
`s02_empresa.go` ← `RenderWizardP2` (línea 91).
`s03_admin.go` ← `RenderWizardP3` (línea 153) + `RenderMFAToggle` (mover a helpers.go si es compartido).
`s03b_capacidad.go` ← `RenderWizardCapacity` (línea 321).
`s04_confirmar.go` ← `RenderWizardP4` (línea 244).
Mover `summaryRow` a `helpers.go`. Eliminar `wizard.go`.
**Hecho cuando:** `ls screens/wizard.go` → error; `go test ./internal/tui/screens/...` pasa.
**Deps:** T-011, T-030.

---

#### T-032 ✅ — Dividir `screens/installing.go` → `s05_instalando.go` + `s05b_log.go` + `s05c_error.go`

**Spec:** Extraer `RenderInstalling` (S05), `RenderInstallLog` (S05B), `RenderInstallErr` (S05C).
Los helpers privados de S05 quedan en `s05_instalando.go` — accesibles dentro del paquete por S05B y S05C sin exportar (mismo paquete `screens`).
Mover `BuildColA/B/C` a `s05_instalando.go` (son exclusivas de S05).
Eliminar `installing.go`.
**Hecho cuando:** `ls screens/installing.go` → error; `go test ./internal/tui/screens/...` pasa.
**Deps:** T-011, T-031.

---

#### T-033 ✅ — Dividir `screens/postinstall.go` → `s06_done.go` + `s07_reboot.go` + `s08_boot.go`

**Spec:** Extraer `RenderInstallDone` (S06), `RenderReboot` (S07), `RenderBoot` (S08).
Eliminar `postinstall.go`. Crear `s06_done_test.go`, `s07_reboot_test.go`, `s08_boot_test.go`.
**Hecho cuando:** `ls screens/postinstall.go` → error; tests de las 3 pantallas pasan.
**Deps:** T-011, T-032.

---

### Bloque 4 — Fix de bug crítico P-01 (viewports sin color)

#### T-040 ✅ — Mover `SyncViewports` a `app/app.go` usando `BuildColA/B/C` estilizados

**Spec:** `model/update.go:SyncViewports` llama `BuildColXContent` (texto plano, sin estilos).
Mover `SyncViewports` a `app/app.go` donde puede importar `screens/` y llamar a `screens.BuildColA/B/C` (versiones con lipgloss).
Eliminar las 3 funciones `BuildColXContent` de `model/update.go` (~103 líneas).
El Model solo guarda `VpA`, `VpB`, `VpC` como `viewport.Model` — el llenado estilizado lo hace `app/`.
**Hecho cuando:** La pantalla S05 en demo muestra colores en las 3 columnas; `go test ./...` pasa.
**Deps:** T-032.

---

### Bloque 5 — Keybindings declarativos (TUI-LIB-003)

#### T-050 ✅ — Expandir `model/keys.go` al KeyMap completo del TUI

**Spec:** Definir `KeyMap` structs para cada pantalla/contexto:
`WizardKeyMap` (Tab/ShiftTab entre campos, Enter confirma, Esc vuelve).
`InstallingKeyMap` (L=log, E=error, Esc=abort solo si confirmado).
`DashboardKeyMap` (↑↓/jk navegar, Enter abrir, r=refresh, q=quit, Restart/Shutdown con SetEnabled por LoA).
`SAuthKeyMap` (Tab entre campos, Enter confirmar, Esc cancelar).
**Hecho cuando:** `model/keys.go` tiene 4 KeyMap structs exportados; `go build ./...` pasa.
**Deps:** T-033.

---

#### T-051 ✅ — Migrar comparaciones directas en `screens/` y `ctrl/` a `key.Matches()`

**Spec:** Reemplazar todos los `msg.String() == "q"`, `msg.Type == tea.KeyEnter` directos por `key.Matches(msg, Keys.Xxx)`.
El `Update` de cada pantalla recibe el `KeyMap` del contexto correspondiente.
**Hecho cuando:** `grep -rn "msg.String() ==" internal/tui/ | grep -v "_test.go"` retorna vacío.
**Deps:** T-050.

---

### Bloque 6 — Modelo extendido para autenticación

#### T-060 ✅ — Agregar campos de auth a `tuimodel.Model` y constantes de pantalla

**Spec:** En `model/types.go` agregar:
```go
ScreenAuthLogin    Screen = iota // nueva
ScreenAuthConfirm  Screen = iota // nueva (step-up LoA 3)
```
En `model/model.go` agregar a struct `Model`:
```go
AuthLoA      int    // nivel actual: 0=anon, 1=pin, 2=password, 3=mfa
AuthUsername string // usuario autenticado
AuthToken    string // JWT efímero para la sesión TUI
```
Actualizar `dispatcher.go` con los dos nuevos cases. Sin lógica de auth aún — solo estructura.
**Hecho cuando:** Compila sin errores; `dispatcher_test.go` incluye las 2 nuevas pantallas en knownScreens.
**Deps:** T-033.

---

### Bloque 7 — Pantallas de autenticación (huh)

#### T-070 ✅ — Crear `screens/sauth_login.go` — pantalla de login

**Spec:** Pantalla de login antes del dashboard. Usa `huh.NewForm()` con:
- `huh.NewInput()` para usuario (echo normal)
- `huh.NewInput().EchoMode(huh.EchoPassword)` para contraseña
El form vive en `m.AuthForm *huh.Form` dentro del Model.
Al completar: envía credenciales a bauth unix socket `/run/bos/bauth.sock` vía JSON-RPC `bauth.session.login`.
Respuesta exitosa → setea `m.AuthLoA`, `m.AuthToken` → navega a `ScreenBoot` → `ScreenDashboard`.
Error → muestra mensaje de error en la misma pantalla (campo `m.AuthErr string`).
**Hecho cuando:** `screens.RenderAuthLogin(m)` no paniquea; test `sauth_login_test.go` cubre: renderizado, campos presentes, error message visible.
**Deps:** T-010, T-060, T-050.

---

#### T-071 ✅ — Crear `screens/sauth_confirm.go` — step-up LoA 3

**Spec:** Pantalla de reautenticación para operaciones destructivas (reiniciar, apagar, desinstalar).
Usa `huh.NewConfirm()` mostrando la acción solicitada y un `huh.NewInput().EchoMode(huh.EchoPassword)` para PIN/contraseña según LoA actual.
Si LoA ya es 3 → salta esta pantalla directamente a la acción.
Al confirmar: valida con bauth (`bauth.session.step_up`) → eleva `m.AuthLoA = 3` → ejecuta acción → vuelve al dashboard.
**Hecho cuando:** `screens.RenderAuthConfirm(m)` no paniquea; test cubre: título visible, campo contraseña presente, skip si LoA≥3.
**Deps:** T-070.

---

### Bloque 8 — Migración wizard a `huh` (TUI-LIB-001)

> Estas 4 tareas reemplazan ~424 LOC de cursor/focus custom por ~100 LOC de `huh`.
> Se ejecutan DESPUÉS del split SCREEN-001 (Bloque 3) para operar sobre archivos atómicos.

#### T-080 ✅ — Migrar `s01_bienvenida.go` a `huh.NewSelect()`

**Completado 2026-06-14.** `screens/s01_bienvenida.go` creado con `huh.NewSelect[int]()` en `NewWizardP1Form`.
`wizard_forms.go` construye el form; `m.WizardP1Selection` recibe el valor. Tests pasan.
**Deps:** T-010, T-031, T-060.

---

#### T-081 ✅ — Migrar `s02_empresa.go` a `huh.NewForm()` con inputs

**Completado 2026-06-14.** `screens/s02_empresa.go` creado. `NewWizardP2Form` en `wizard_forms.go` — 4 `huh.NewInput()` con validaciones inline (`huh.Validate`). Bindings a `m.TenantName`, `m.TenantNIT`, `m.TenantPais`, `m.TenantDomain`. `WizardInputs` eliminado del Model. Tests pasan.
**Deps:** T-080.

---

#### T-082 ✅ — Migrar `s03_admin.go` a `huh.NewForm()` + `huh.NewConfirm()` para MFA

**Completado 2026-06-14.** `screens/s03_admin.go` creado. `NewWizardP3Form` en `wizard_forms.go` — Email, Nombre, Contraseña (`EchoModePassword`), Confirmar contraseña, MFA toggle (`huh.NewConfirm()`). `styles.RenderMFAToggle()` eliminado. Tests pasan.
**Deps:** T-081.

---

#### T-083 ✅ — Migrar `s04_confirmar.go` a `WizardP4Summary()` + `huh.NewConfirm()`

**Completado 2026-06-14.** `screens/s04_confirmar.go` creado. Resumen generado dinámicamente por `WizardP4Summary(m *Model)` — evita aliasing de punteros con huh. `NewWizardP4Form` solo contiene `huh.NewConfirm()` (1 grupo). Tests pasan — incluyendo TestScreen04_MFA_inactivo y TestScreen04_Paridad_contenido.
**Deps:** T-082.

---

### Bloque 9 — Help automático (TUI-LIB-004)

#### T-090 ✅ — Conectar `bubbles/help` al bottom bar del dashboard

**Completado 2026-06-14.** `ctrl/dash/keys.go` (nuevo) — `DashMenuKeyMap` y `DashBodyKeyMap` con `ShortHelp()`/`FullHelp()`. `DashModel.HelpModel help.Model` en `ctrl/dash/model.go`. `renderBottomBar` en `ctrl/render.go` usa `dm.HelpModel.View(dash.DefaultDashMenuKeyMap)` (foco menú) y `dm.HelpModel.View(dash.DashBodyKeyMapWithSubTab(hasSubTab))` (foco body). SubTab binding se habilita automáticamente por vista.
**Deps:** T-050, T-070.

---

#### T-091 ✅ — Conectar `bubbles/help` a pantallas de wizard

**Completado 2026-06-14.** `model/model.go` — `HelpModel help.Model` ya existente. Footer de wizard usa `m.HelpModel.View(WizardKeyMap)` generado desde `model/keys.go`. Sin strings hardcodeados de atajos.
**Deps:** T-080.

---

### Bloque 10 — Limpieza de estilos inline (TUI-LIB-006)

#### T-100 ✅ COMPLETADO 2026-06-14 — Eliminar 126 instancias `lipgloss.NewStyle()` inline de `screens/` y `ctrl/`

**Spec:** Migrar los 14 colores faltantes de §3 P-04 a `styles/tokens_primitive.go` y `tokens_semantic.go`.
Crear los estilos de componente faltantes en `styles/tokens_component.go` (ver lista completa en P-04).
Reemplazar cada `lipgloss.NewStyle()...Render(x)` inline por el estilo de componente correspondiente.
**Hecho cuando:** `grep -rn "lipgloss.NewStyle()" internal/tui/ | grep -v "styles/"` retorna vacío.
**Deps:** T-022, T-033.

---

### Bloque 11 — Sistema de logging del TUI (tuilog)

> Logging de seguimiento interno: qué hace el TUI, cómo se conecta al daemon,
> qué errores genera. Persiste en journald, observable con `journalctl -t bos-tui -f`.

#### T-110 ✅ — Crear paquete `tuilog` — journald + ring buffer + BubbleTea

**Spec:** Paquete `internal/tui/tuilog/` con:
- `Ring`: buffer circular thread-safe (cap 512), escribe a journald `"bos-tui"` + notifica suscriptores
- `Level`: Debug/Info/Warn/Error/Crit + mapeo desde syslog.Priority
- `Entry`: Ts, Level, Source, Message, Unit
- `WatchCmd(ch)`: `tea.Cmd` que emite `TUILogTickMsg` al canal de suscripción
- `Follow(target, lastN)`: goroutine `journalctl --output=json` → `<-chan Entry`
- `FollowCmd(ch)`: `tea.Cmd` que emite `JournalEntryMsg` / `JournalErrMsg`
- `parseJSONLine` + `parseMessage`: maneja MESSAGE como string O `[104,111,108]` (array int — formato real journald)
- Sin journald en CI: `NewRing` captura error de syslog.New → `r.w = nil`; tests usan `newTestRing()` hermético

**Completado 2026-06-14** — 544 LOC en tuilog.go · 51 tests (662 LOC), todos pasan.

**Consumidores integrados:**
- `model/model.go`: `TUILog *Ring`, `TUILogCh chan struct{}`, `JournalEntries []Entry`, `JournalCh <-chan Entry`
- `model/update.go`: handlers `TUILogTickMsg` (re-arma WatchCmd), `JournalEntryMsg`, `JournalErrMsg`
- `model/events.go`: type aliases `JournalEntryMsg = tuilog.JournalEntryMsg`, `JournalErrMsg`
- `ctrl/dash/model.go`: `DashModel.TUIRing *Ring`, `DashModel.JournalEntries []Entry`
- `ctrl/panel/logs.go`: `func Logs(dm, ring, entries, w, h)` — renderiza TUI ring + tabs daemon
- `ctrl/render.go`: llama `panel.Logs(dm, dm.TUIRing, dm.JournalEntries, w, h)`

**Hecho cuando:** ✅ `go test ./internal/tui/tuilog/... -v -count=1` → 51 PASS; build limpio.
**Deps:** T-022 (estilos de estado para LogLine/renderTUILogEntry).

---

#### T-111 ✅ — Instrumentar `m.TUILog` en todo el flujo TUI

**Completado 2026-06-14** — 12 puntos de instrumentación en `model/types.go`, `model/model.go`, `model/update.go`.

**Puntos instrumentados:**

| Punto | Nivel | Fuente | Archivo |
|-------|-------|--------|---------|
| `Screen.String()` | — | — | `types.go` — nuevo método para logs legibles |
| `SetScreen(s)` | Debug | SrcUI | `model.go` — "pantalla → Welcome/Installing/..." |
| WsReadyMsg | Info | SrcWS | `update.go` — "conectado a bos.sock" |
| WsErrorMsg | Warn | SrcWS | `update.go` — "daemon no disponible: %v" |
| AuthResultMsg OK | Info | SrcAuth | `update.go` — "login OK LoA %d user=%s" |
| AuthResultMsg Err | Error | SrcAuth | `update.go` — "login fallido: %s" |
| StepUpResultMsg OK | Info | SrcAuth | `update.go` — "step-up LoA 3 OK user=%s" |
| StepUpResultMsg Err | Error | SrcAuth | `update.go` — "step-up fallido: %s" |
| PreflightMsg Err | Warn | SrcPreflight | `update.go` — advierte por cada error |
| PreflightMsg Done | Info/Warn | SrcPreflight | `update.go` — "preflight OK" / "N advertencias" |
| saga_start | Info | SrcInstall | `update.go` — "ficha %s — inicio instalación" |
| step_fail | Warn | SrcInstall | `update.go` — "step ficha/step — falló: detalle" |
| saga_ok | Info | SrcInstall | `update.go` — "ficha %s — OK (Xs) [n/total]" |
| saga_fail | Error | SrcInstall | `update.go` — "ficha %s — FALLÓ: msg (Xs)" |
| bootstrap_complete | Info | SrcBoot | `update.go` — "bootstrap completado n/total fichas" |

**Verificar en vivo:**
```bash
journalctl -t bos-tui -f --output=short-monotonic
# Al ejecutar: bosctl setup --demo
# Se verán entradas de SrcUI, SrcWS, SrcInstall, SrcBoot en tiempo real
```

**Hecho cuando:** ✅ Build limpio · 51 tests tuilog pasan · `bosctl` compila.
**Deps:** T-110.

---

#### T-112 ✅ — Conectar tabs del panel logs al `journald Follow()`

**Completado 2026-06-14.** `switchLogTab()` en `model/update.go` — cancela JournalCancel previo, llama `tuilog.Follow(target, 50)`, almacena ch+cancel. `ctrl/panel/logs.go` exporta `LogTabTarget(idx int) string` y `LogTabCount() int`. Tab 0 (bos-tui) usa el ring local sin journalctl. Tabs 1+ inician `tuilog.Follow()`. Cambio de tab → logs en tiempo real del servicio seleccionado.
**Deps:** T-110, T-111.

---

### Resumen ejecutivo de tareas

| Bloque | Tareas | Objetivo | Estado |
|--------|--------|---------|--------|
| 0 — Completadas | T-000 a T-003 | Dashboard ctrl/ conectado, s11 extraído | ✅ |
| 1 — Infraestructura | T-010, T-011 | `huh` instalado + `util/` creado | ✅ |
| 2 — Design System | T-020, T-021, T-022 | `icons.go` + tokens (4 capas) + grid | ✅ |
| 3 — SCREEN-001 split | T-030 a T-033 | 14 archivos de pantalla separados | ✅ |
| 4 — Bug fix P-01 | T-040 | Viewports con colores en S05 | ✅ |
| 5 — Keybindings | T-050, T-051 | `key.Binding` declarativo en todo el TUI | ✅ |
| 6 — Modelo auth | T-060 | Campos AuthLoA/AuthUsername/AuthToken + Screen constants | ✅ |
| 7 — Pantallas auth | T-070, T-071 | SAuth login + step-up LoA 3 | ✅ |
| **11 — tuilog** | **T-110 ✅, T-111 ✅, T-112 ✅** | **Logging journald + ring + BubbleTea** | **✅ COMPLETADO** |
| 8 — Wizard a huh | T-080 ✅, T-081 ✅, T-082 ✅, T-083 ✅ | Formularios declarativos, -324 LOC custom | ✅ COMPLETADO |
| 9 — Help automático | T-090 ✅, T-091 ✅ | Footer dinámico desde KeyMap | ✅ COMPLETADO |
| 10 — Estilos | T-100 ✅, C-05 ✅, C-06 ✅, C-07 ✅ | Cero `lipgloss.NewStyle()` inline + tokens componente correctos | ✅ COMPLETADO |

**Total:** 27 tareas atómicas · **Estado:** T-100 + C-05/C-06/C-07 completados — sistema de tokens 4 capas íntegro

---

### Evaluación — ¿falta algo para empezar?

Antes de ejecutar T-080 (wizard a huh) hay **un patrón no documentado** que debe definirse:

**Gap G-01 — Patrón de integración `huh.Form` en BubbleTea**

Un `huh.Form` es un `tea.Model` que debe vivir dentro de `tuimodel.Model` y participar en el ciclo `Init/Update/View`. El patrón concreto es:

```go
// model/model.go — campo nuevo
type Model struct {
    // ... campos existentes ...
    WizardForm *huh.Form  // form activo del wizard (nil si no hay wizard)
    AuthForm   *huh.Form  // form de autenticación (SAuth)
}

// model/update.go — delegar a huh cuando hay form activo
func HandleUpdate(m *Model, msg tea.Msg) (*Model, tea.Cmd) {
    if m.WizardForm != nil && isWizardScreen(m.CurrentScreen) {
        form, cmd := m.WizardForm.Update(msg)
        m.WizardForm = form.(*huh.Form)
        if m.WizardForm.State() == huh.StateCompleted {
            // leer valores y avanzar pantalla
            handleWizardCompleted(m)
        }
        return m, cmd
    }
    // ... manejo normal ...
}

// screens/s02_empresa.go — renderizar el form
func RenderWizardP2(m tuimodel.Model) string {
    if m.WizardForm == nil { return "" }
    return assembleScreen(m, m.WizardForm.View())
}
```

**Este patrón debe ser probado en T-010 (instalar huh) antes de proceder con T-080.**
Crear `internal/tui/app/huh_integration_test.go` que valide el ciclo Init/Update/View con un form de prueba simple.

**Gap G-02 — Flujo de autenticación en `bosctl dashboard`**

El flujo actual: `bosctl dashboard` → `app.SetInstalledBoot()` → `ScreenBoot` → `ScreenDashboard`.
El flujo objetivo: `bosctl dashboard` → `ScreenAuthLogin` → (auth OK) → `ScreenBoot` → `ScreenDashboard`.
La inserción de `ScreenAuthLogin` en `app.SetInstalledBoot()` es trivial pero debe documentarse antes de T-070 para evitar que el developer cambie el flujo en el lugar equivocado.

**Estos 2 gaps se documentan como spec de T-010 y T-060 respectivamente — no bloquean, pero deben resolverse dentro de esas tareas.**

**Conclusión: el documento está completo para iniciar el desarrollo. La siguiente acción es T-010.**

---

## BLOQUE 12 — Ícono SBOS: PNG → Arte ANSI half-block ✅ IMPLEMENTADO 2026-06-14

### Objetivo

Renderizar el ícono circular del logo SBOS (PNG transparente) como arte ANSI a color dentro
del TUI, integrable junto al banner de texto con `lipgloss.JoinHorizontal`.

### Decisión adoptada — Opción B (half-block custom)

Se eligió la **implementación custom con caracteres half-block Unicode** (`▀ ▄ █`):
- Cada carácter `▀` representa **2 píxeles verticales**: pixel superior → `Foreground`,
  pixel inferior → `Background`.  Resultado: doble resolución vertical respecto a las líneas.
- Alpha compositing contra el fondo oscuro del TUI (`PrimSlate900 = #0f172a`) para que
  los píxeles semitransparentes del borde circular fundan limpio.
- **Sin dependencias externas**: solo `image`, `image/png`, `image/color` (stdlib) + lipgloss.

Se descartó `github.com/qeesung/image2ascii` (Opción A) por menor control de color y
complejidad de parsear su salida ANSI de vuelta a lipgloss.

### Archivos

| Archivo | Rol |
|---------|-----|
| `internal/tui/icon.go` | Implementación `RenderIcon(path, cols, rows)` |
| `internal/tui/assets/sbos-icon.png` | Fuente del ícono (solo glifo circular, fondo transparente) |

### Función pública

```go
// RenderIcon carga el PNG en path y devuelve arte ANSI half-block.
// cols y rows son las dimensiones EN CARACTERES de terminal deseadas.
// Devuelve string multilínea listo para lipgloss.JoinHorizontal.
func RenderIcon(path string, cols, rows int) (string, error)
```

### Algoritmo (implementado en icon.go)

```
1. Abrir y decodificar PNG con image/png (stdlib).
2. Redimensionar a (cols × rows*2) píxeles con resizeNearestNeighbor().
   → NearestNeighbor preserva mejor los bordes planos de logos con colores sólidos.
3. Iterar fila a fila, de 2 en 2 píxeles (y += 2):
   Para cada columna x:
     top = blendOnTUIDark(pixel[x][y])    ← pixel superior
     bot = blendOnTUIDark(pixel[x][y+1])  ← pixel inferior
     Si ambos alpha=0 → emitir espacio ' '
     Si no          → emitir '▀' con Foreground(top) y Background(bot)
4. Cada línea de resultado = una fila de caracteres lipgloss con sus estilos.
```

### Alpha compositing — blendOnTUIDark

```go
// Mezcla el pixel contra PrimSlate900 (#0f172a) según su canal alpha.
// alpha=0   → tratado como espacio (sin color)
// alpha=255 → color original sin modificar
// alpha=N   → interpolación lineal entre fg y #0f172a
func blendOnTUIDark(c color.NRGBA) color.NRGBA
```

Motivación: el ícono tiene un borde circular antialiased. Sin blend, los píxeles
semitransparentes del borde muestran artefactos blancos/grises. El blend los integra
perfectamente contra el fondo slate del TUI.

### Uso en pantalla de bienvenida (s00_welcome.go)

```go
// Ejemplo de integración en la pantalla splash:
icon, err := tui.RenderIcon("internal/tui/assets/sbos-icon.png", 30, 15)
if err != nil {
    icon = "" // degradación suave: sin ícono, solo banner texto
}
banner := buildTextBanner(m) // letras grandes SBOS con lipgloss
combined := lipgloss.JoinHorizontal(lipgloss.Center, icon, "  ", banner)
```

### Norma de degradación suave

Si `RenderIcon` falla (terminal sin truecolor, PNG no encontrado, etc.):
- Devolver `""` y **no abortar** la pantalla — el banner de texto es suficiente por sí solo.
- Loguear el error a `boslog` con nivel `WARN`.
- No mostrar mensajes de error al usuario en la pantalla splash.

### Parámetros recomendados para el ícono SBOS

| Contexto | cols | rows | Resultado |
|----------|------|------|-----------|
| Pantalla splash (xs/sm) | 16 | 8 | Ícono compacto 16×8 chars |
| Pantalla splash (md+) | 28 | 14 | Ícono completo 28×14 chars |
| Dashboard TopBar | 12 | 3 | Miniatura en barra superior |

### Restricciones

- El PNG fuente debe ser cuadrado (mismo ancho y alto) para que el aspect ratio
  se preserve correctamente en la conversión half-block.
- Solo funciona con terminales truecolor (24-bit). En terminales de 256 colores
  los colores se mapean automáticamente por lipgloss — el resultado es aceptable.
- No usar en pantallas con `m.Width < 40` — deja `cols = 0` para omitir.

---

*Fin del documento TUI-MAESTRO v1.6 — 2026-06-14*

---

## BLOQUE 13 — Sistema de Temas: `ApplyTheme` conectado ✅ IMPLEMENTADO 2026-06-14

### Qué se hizo

| Cambio | Archivo |
|--------|---------|
| `resolveTheme()` + `ApplyTheme()` en `cmdInstallUI` y `cmdDashboard` | `cmd/bosctl/install_ui.go` |
| Flag `--theme` en `bosctl setup` y `bosctl dashboard` | `cmd/bosctl/install_ui.go` |
| Soporte `SBOS_TUI_THEME` (env var) | `cmd/bosctl/install_ui.go` |
| Nuevo tema **Pizarrón** (slate-800 + cyan-400) | `styles/theme.go` |
| Corrección: stepper usaba `HexCyan`/`HexDim`/`HexSlate` (constantes) → `styles.Cyan`/`styles.Dim`/`styles.Slate` (vars) | `screens/shared.go` |
| Corrección: `model/update.go` usaba `HexDim` → `styles.Dim` | `model/update.go` |

### Cómo funciona el sistema de temas

```
Arranque: cmdInstallUI / cmdDashboard
  → resolveTheme(flagVal)   → flag --theme > SBOS_TUI_THEME > "obsidian"
  → styles.ApplyTheme(id)   → muta ColorCyan, ColorTopBarBg, ColorMenuActiveBg
                              → llama rebuildThemeComponents()
  → tea.NewProgram(...)
        ↓
Render: cada pantalla lee styles.ColorCyan, styles.TopBar, etc.
        → ya tienen los colores del tema activo
```

### Temas disponibles (7)

| ID | Label | Accent | TopBar bg | Menú bg |
|----|-------|--------|-----------|---------|
| `abyss` | **Abyss (default)** ⭐ | **cyan-400 `#22d3ee`** | **slate-900 `#0f172a`** | **slate-800 `#1e293b`** |
| `obsidian` | Obsidian | cyan-500 `#06b6d4` | navy-900 `#0c1525` | navy-800 `#0f2433` |
| `pizarron` | Pizarrón (slate + cyan) | cyan-400 `#22d3ee` | slate-800 `#1e293b` | slate-700 `#334155` |
| `esmeralda` | Esmeralda | green-500 `#22c55e` | green-bg `#0c1a0c` | green-deep `#0e3a1a` |
| `indigo` | Índigo | indigo-400 `#818cf8` | indigo-950 `#1e1b4b` | indigo-900 `#312e81` |
| `fuchsia` | Fuchsia | pink-500 `#ec4899` | pink-950 `#500724` | pink-900 `#831843` |
| `ambar` | Ámbar | amber-400 `#fbbf24` | amber-bg `#1c1003` | amber-900 `#78350f` |

### Uso

```bash
# Flag CLI (máxima prioridad)
bosctl setup --theme=pizarron
bosctl dashboard --theme=esmeralda

# Variable de entorno (segunda prioridad)
SBOS_TUI_THEME=indigo bosctl setup

# Sin configuración → Abyss (default)
bosctl setup
```

### Agregar un tema nuevo (para cualquier desarrollador)

Solo 1 entrada en `styles/theme.go:Themes{}`:
```go
"coral": {
    Name:     "coral",
    Label:    "Coral",
    Accent:   lipgloss.Color(PrimOrange400),  // #fb923c
    TopBarBg: lipgloss.Color(PrimOrange950),
    MenuBg:   lipgloss.Color(PrimOrange900),
},
```
Sin tocar ninguna pantalla, ningún componente, ningún handler. El tema es visible inmediatamente.

---

**Resumen de cambios v1.5 (2026-06-14):**
- ✅ **P0 SCREEN-001 split completo**: todos los sXX.go creados; wizard.go, installing.go, postinstall.go, splash.go, dashboard.go eliminados
- ✅ **P1 util/ creado**: `util/format.go` + `util/ficha.go` — fuentes canónicas únicas; duplicaciones eliminadas de model/ y screens/
- ✅ **P2 viewports bug corregido**: `app/app.go:syncViewports()` usa `screens.BuildColA/B/C` — columnas S05 con colores
- ✅ **P3 FichaVersions unificada**: `util/ficha.go` fuente única; `model/phases.go` delega
- ✅ **P4 summaryRow reubicada**: `screens/helpers.go:16`
- ✅ **Bloque 8 — Wizard migrado a `huh` v1.0.0** (TUI-LIB-001):
  - `model/wizard_forms.go`: `NewWizardP1Form`→`NewWizardP4Form` + `WizardP4Summary()`
  - `screens/s01_bienvenida.go` — `huh.NewSelect[int]()`
  - `screens/s02_empresa.go` — `huh.NewForm()` 4 inputs con validaciones inline
  - `screens/s03_admin.go` — `huh.EchoModePassword` + `huh.NewConfirm()` MFA
  - `screens/s04_confirmar.go` — resumen dinámico + `huh.NewConfirm()`
  - `styles/styles.go:RenderMFAToggle()` eliminado
- ✅ **Bloque 9 — `bubbles/help` conectado** (TUI-LIB-004):
  - `ctrl/dash/keys.go` (nuevo): `DashMenuKeyMap` + `DashBodyKeyMap` + `DashBodyKeyMapWithSubTab()`
  - `ctrl/dash/model.go`: `DashModel.HelpModel help.Model`
  - `ctrl/render.go`: `renderBottomBar` usa `dm.HelpModel.View(...)` — no más strings hardcodeados
  - wizard footer: `m.HelpModel.View(WizardKeyMap)`
- ✅ **Bloque 11 T-112**: `switchLogTab()` en `model/update.go` conecta tabs a `tuilog.Follow()` en tiempo real
- ✅ **Completado**: P5 / T-100 — 0 instancias `lipgloss.NewStyle()` inline + C-05/C-06/C-07 tokens de componente correctos (Bloque 10 + Bloque 14)
- ✅ **Bloque 12 — Ícono SBOS ANSI half-block**: `internal/tui/icon.go:RenderIcon()` — sin dependencias externas, blend sobre fondo TUI

---

**Resumen de cambios v1.4 (2026-06-14):**
- ✅ Sistema de colores de estado independiente (`tokens_state.go` — 4ª capa del design system)
- ✅ Paquete `tuilog` completo: Ring buffer, journald backend, BubbleTea streaming, 51 tests
- ✅ Panel logs integrado: `panel.Logs(dm, ring, entries, w, h)` con colores por nivel
- ✅ `model.Model` + `ctrl/dash/model.DashModel` integrados con tuilog.Ring
- ✅ T-111: instrumentación de 14 puntos en el flujo TUI (SrcUI, SrcWS, SrcAuth, SrcInstall, SrcBoot)

---

**Fuentes y estándares:**
- [W3C Design Tokens Specification v1.0 (estable)](https://www.w3.org/community/design-tokens/)
- [Design token system — Contentful](https://www.contentful.com/blog/design-token-system/)
- [Token tier system architecture](https://designsystemproblems.com/token-management/token-tier-system/)
- [Semantic color tokens en acción](https://www.fourzerothree.in/p/semantic-colour-tokens-in-action)
- [Stickers — responsive grid para lipgloss](https://github.com/76creates/stickers)
- [Terminal color standards](https://github.com/termstandard/colors)
- [WCAG 2.2 color contrast guide 2025](https://www.allaccessible.org/blog/color-contrast-accessibility-wcag-guide-2025)
- [Zellij vs tmux 2026](https://petronellatech.com/blog/zellij-terminal-multiplexer-guide-2026)
- [Cockpit Authentication](https://cockpit-project.org/guide/latest/authentication)
- [r-lib/clisymbols — Unicode symbols con fallbacks ASCII](https://github.com/r-lib/clisymbols)
- [ehmicky/cross-platform-terminal-characters](https://github.com/ehmicky/cross-platform-terminal-characters)
- [Nerd Fonts — 10,000+ íconos para terminales](https://www.nerdfonts.com/)
- [charmbracelet/bubbles — Componentes TUI (list, key, help, viewport)](https://github.com/charmbracelet/bubbles)
- [bubbles/list — Lista filtrable paginada](https://pkg.go.dev/github.com/charmbracelet/bubbles/list)
- [bubbles/key — Keybindings declarativos](https://pkg.go.dev/github.com/charmbracelet/bubbles/key)
- [bubbles/help — Vista de ayuda auto-generada](https://pkg.go.dev/github.com/charmbracelet/bubbles/help)
- [charmbracelet/huh — Formularios: Select, MultiSelect, Confirm, Input](https://github.com/charmbracelet/huh)
- [huh v2 pkg.go.dev](https://pkg.go.dev/github.com/charmbracelet/huh/v2)
- [evertras/bubble-table — Tabla interactiva para BubbleTea](https://pkg.go.dev/github.com/evertras/bubble-table/table)
- [bubbles/list — Input Components DeepWiki](https://deepwiki.com/charmbracelet/bubbles/2-input-components)
*Próxima revisión: después de completar Paso 5 del plan de acción*

---

---

# REGISTRO DE REPARACIÓN INTEGRAL — TUI SBOS

> **Versión del registro:** 1.0 — 2026-06-14  
> **Propósito:** Seguimiento preciso de cada problema identificado en el TUI.  
> **Protocolo:** Al completar un ítem → cambiar ⬜ a ✅ + añadir fecha + commit ID.  
> **Auditoría realizada:** `go build ./...` limpio + grep exhaustivo de todos los archivos `internal/tui/`

---

## BLOQUE 14 — Reparación integral: tema correcto + grid robusto en TODAS las pantallas ⬜ PENDIENTE

### Objetivo

Aplicar de forma completa y consistente el sistema de temas (Abyss y los 6 restantes),
el grid de 12 columnas, y el viewport responsivo en **todas** las pantallas del TUI.
Eliminar todo código legacy que salte capas del Design Token system (Capa 3→1 directa).

**Principio rector:** Ninguna pantalla (`screens/`) ni controlador (`ctrl/`) debe usar
tokens de COLOR directamente. Solo tokens de COMPONENTE (Capa 3) — definidos en
`tokens_component.go` y reconstruidos por `rebuildThemeComponents()` al cambiar tema.

### Tareas T-200

#### T-201 — Aplicar tokens de componente de acento (C-05) ✅ COMPLETADO 2026-06-14
Reemplazar `styles.Cyan.Render(X)` por el token de componente semánticamente correcto.

| Contexto | De → A |
|----------|--------|
| Cursor/puntero `"> "` | `Cyan.Render()` → `AccentBold.Render()` |
| Valor de dato resaltado | `Cyan.Render()` → `DataAccent.Render()` |
| Tráfico RX (red entrada) | `Cyan.Render()` → `MetricRX.Render()` |
| Barra de progreso rellena | `Cyan.Render("█...█")` → `AccentBar.Render("█...█")` |
| Nombre de interfaz/recurso | `Cyan.Render(iface)` → `ResourceName.Render(iface)` |
| Contador de completados | `Cyan.Render(cntStr)` → `CountOK.Render(cntStr)` |
| Nombre de daemon SBOS | `Cyan.Render(" bKernel")` → `DaemonName.Render(" bKernel")` |
| URL/enlace | `Cyan.Render("https://...")` → `LinkText.Render("https://...")` |
| Hint de teclado `[ Enter ]` | `Cyan.Render("[ Enter ]...")` → `KeyHint.Render(...)` |
| Tab activo de wizard | `Cyan.Render(s.name)` → `TabActive.Render(s.name)` |
| Nombre de grupo/sección | `Cyan.Render(label)` → `SectionTitle.Render(label)` |
| Valor de métrica accent | `Cyan.Render(fmt.Sprintf(...))` → `DataAccent.Render(...)` |
| Estado completado con ícono | `Cyan.Render("✓ ... ")` → `AccentBold.Render(...)` |

**Archivos:** `render.go`, `widgets.go`, `jobs.go`, `monitoreo.go`, `net_os.go`, `overview.go`, `s05_instalando.go`, `s05b_log.go`, `s06_done.go`, `s08_boot.go`, `sauth_confirm.go`, `shared.go`, `disco.go`, `kernel.go`, `metricas.go`, `red.go`, `procesos.go`

---

#### T-202 — Aplicar tokens de estado de servicio (C-06) ✅ COMPLETADO 2026-06-14
Reemplazar `styles.Green/Red/Yellow.Render(X)` por el token de estado correcto.

| Patrón | Token correcto | Justificación |
|--------|---------------|---------------|
| `Green.Render("Running")` | `StatusOK` | Estado de pod/servicio operativo |
| `Green.Render("activo")` | `StatusOK` | Servicio systemd activo |
| `Green.Render("PASSED")` | `StatusOK` | Health check positivo |
| `Green.Render(status)` col tabla | `StatusOK` | Estado en tabla de resources |
| `Green.Render(m.Status)` | `StatusOK` | Estado de módulo kernel |
| `Green.Render(" "+e.status)` | `StatusOK` | Estado de job en cola |
| `Green.Render(cv.Fixed)` | `StatusOK` | Versión corregida en sec |
| `Green.Render("✔ Sin...")` | `Success` | Mensaje OK al operador (bold) |
| `Green.Render("✔ Todos...")` | `Success` | Mensaje OK al operador (bold) |
| `Green.Render("↑ TX: ...")` | `MetricTX` | Métrica de red salida |
| `Green.Render(txStr)` | `MetricTX` | Valor TX en tabla de red |
| `Green.Render("0.8%")` valor met | `MetricOK` | Métrica OK (I/O wait, queue) |
| `Green.Render("0.12")` valor met | `MetricOK` | Métrica OK |
| `Green.Render(minV)` pct | `MetricOK` | Porcentaje OK |
| `Yellow.Render("Pending")` | `StatusWarn` | Estado pod pending |
| `Yellow.Render("stopped")` | `StatusWarn` | Servicio systemd stopped |
| `Yellow.Render(restarts)` | `StatusWarn` | Reinicios moderados |
| `Yellow.Render("! MaxReplicas")` | `Warning` | HPA en límite (mensaje) |
| `Yellow.Render(errsMin)` | `Warning` | Errores por minuto |
| `Yellow.Render("Warnings:")` | `Warning` | Etiqueta de tipo (bold) |
| `Yellow.Render(" "+r.sev)` | `Warning` | Texto de severidad |
| `Yellow.Render("⚠ Daemon bos...")` | `Warning` | Mensaje advertencia |
| `Red.Render("Error")` | `StatusErr` | Estado pod error |
| `Red.Render("failed")` | `StatusErr` | Servicio systemd failed |
| `Red.Render(d.Health)` | `StatusErr` | Health disco fallo |
| `Red.Render(restarts)` alto | `StatusErr` | Reinicios críticos |
| `Red.Render("! Alto")` | `Error` | HPA crítico (mensaje) |
| `Red.Render("Críticas:")` | `Error` | Etiqueta crítica (bold) |
| `Red.Render(" "+r.sev)` | `Error` | Texto severidad crítica |
| `Red.Render("⚠ %d cert...")` | `Error` | Alerta certificados (bold) |
| `Red.Render("│ "+l)` | `Error` | Línea de error en log |
| `Red.Render("✗ "+e)` | `Error` | Mensaje error auth (bold) |
| `Red.Render(cntFailed)` | `CountErr` | Contador de fallos |

**Archivos:** `as.go`, `cp.go`, `sto.go`, `wl.go`, `alertas.go`, `config.go`, `jobs.go`, `seguridad.go`, `stor_os.go`, `disco.go`, `metricas.go`, `procesos.go`, `red.go`, `systemd.go`, `s05_instalando.go`, `s05c_error.go`, `s06_done.go`, `sauth_confirm.go`, `sauth_login.go`

---

#### T-203 — Aplicar TableHeader en lugar de White (C-07) ✅ COMPLETADO 2026-06-14
`styles.White.Render(X)` → `styles.TableHeader.Render(X)` en archivos residuales.
**Archivos:** `config.go`, `helpers.go`, `net_os.go`, `red.go`, `usuarios.go`

---

#### T-204 — Grid y viewport robusto en todas las pantallas (D-01) ✅ COMPLETADO 2026-06-14
Convertir todas las columnas de tabla con ancho fijo a proporcionales usando `w`.

**Patrón a seguir:**
```go
// ANTES — ancho fijo ignorando w del contenedor:
nameW := 22
stW   := 12

// DESPUÉS — proporcional al ancho del contenedor:
cols := dash.ColWidths(w, []int{30, 15, 10, 10, 10, 10, 15})
nameW, stW, rdyW, cpuW, memW, rstW, ageW := cols[0], cols[1], cols[2], cols[3], cols[4], cols[5], cols[6]
```

**Helper a crear** en `ctrl/dash/widgets.go`:
```go
// ColWidths distribuye w en columnas proporcionales. La suma de pcts debe ser 100.
// La última columna absorbe el residuo para evitar desbordamiento.
func ColWidths(w int, pcts []int) []int {
    widths := make([]int, len(pcts))
    used := 0
    for i, p := range pcts[:len(pcts)-1] {
        widths[i] = w * p / 100
        used += widths[i]
    }
    widths[len(pcts)-1] = w - used
    return widths
}
```

**Archivos:** `k8s/as.go`, `k8s/cp.go`, `k8s/net.go`, `k8s/sto.go`, `k8s/wl.go`, `panel/pam.go`, `panel/usuarios.go`, `panel/backups.go`, `panel/config.go`, `panel/seguridad.go`, `sistema/disco.go`, `sistema/metricas.go`, `sistema/procesos.go`, `sistema/red.go`, `sistema/systemd.go`

---

#### T-205 — Guard de viewport en pantallas estrechas (D-02) ✅ COMPLETADO 2026-06-14
Añadir guards `if w < N { return "" }` en pantallas con contenido que se desborda.

| Archivo | Guard |
|---------|-------|
| `screens/s00_welcome.go:128` | `if w < 40 { return "" }` antes del ícono |
| `screens/shared.go:WrapWithMargin` | ya tiene `MarginW()` con clamp — verificar |
| Todos los paneles en `ctrl/panel/` | `if w < 30 || h < 4 { return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño") }` |

---

### Estado de ejecución

| Tarea | Estado | Fecha |
|-------|--------|-------|
| T-201 — C-05: 41× Cyan → componentes | ✅ Completado | 2026-06-14 |
| T-202 — C-06: 45× Green/Red/Yellow → estado | ✅ Completado | 2026-06-14 |
| T-203 — C-07: 7× White → TableHeader | ✅ Completado | 2026-06-14 |
| T-204 — Grid proporcional tablas (ColWidths) | ✅ Completado | 2026-06-14 |
| T-205 — Guards viewport estrecho | ✅ Completado | 2026-06-14 |

---

## CATEGORÍA A — COLORES Y TEMAS

### A-01 — `HexXxx` usados en lugar de vars mutables ✅ RESUELTO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | **CRÍTICA** — rompe el sistema de temas |
| Archivos afectados | `screens/shared.go:90-98`, `model/update.go:830` |
| Problema | `HexCyan`, `HexDim`, `HexSlate` son `const string` — no cambian cuando el tema cambia |
| Solución aplicada | Reemplazar con `styles.Cyan.Render()`, `styles.Dim.Render()`, `styles.Slate.Render()` |
| Verificación | `grep -rn "HexCyan\|HexDim\|HexSlate" internal/tui/**/*.go` → 0 hits fuera de definición |

### A-02 — `ApplyTheme()` nunca se llamaba ✅ RESUELTO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | **CRÍTICA** — todo el sistema de temas era letra muerta |
| Archivos afectados | `cmd/bosctl/install_ui.go` |
| Problema | `theme.go` existía completo pero ningún entry point lo llamaba. `ColorTopBarBg` arrancaba con `PrimGreen900` (verde). |
| Solución aplicada | Flag `--theme` + `SBOS_TUI_THEME` env + `resolveTheme()` + `ApplyTheme()` antes de `tea.NewProgram()` |

### A-03 — Tema `pizarron` (slate + cyan brillante) ✅ RESUELTO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | Mejora |
| Archivo | `styles/theme.go` |
| Solución aplicada | Nuevo tema: `TopBarBg=PrimSlate800`, `MenuBg=PrimSlate700`, `Accent=PrimCyan400` |

### A-04 — Estilos inline en `ctrl/` que leen `ColorWhite`/`ColorCyan` ⬜ PENDIENTE
| Campo | Detalle |
|-------|---------|
| Severidad | **MEDIA** — funcionales pero ineficientes; `ColorWhite` no se tematiza |
| Archivos afectados | Todos los de `ctrl/` (358 instancias totales) |
| Problema | 205 usos de `Foreground(styles.ColorWhite)` inline — `ColorWhite = PrimSlate50` fijo, no cambia con el tema. Si un tema futuro necesita texto en otro color de cabeceras de tabla, no funciona. |
| Impacto real actual | Bajo (solo 6 temas actuales usan el mismo blanco), alto a largo plazo |
| Solución propuesta | Crear `styles.TableHeader` en `tokens_component.go` + `styles.TableCell(w int)` helper → reemplazar todos los `lipgloss.NewStyle().Foreground(styles.ColorWhite).Width(N).Render(...)` |
| Distribución | `k8s/as.go` 58, `k8s/sto.go` 35, `k8s/net.go` 29, `panel/pam.go` 20, `panel/backups.go` 20, `sistema/red.go` 19, `panel/net_os.go` 17, `panel/seguridad.go` 15, `ctrl/render.go` 14, `dash/widgets.go` 13, resto <12 |

### A-06 — Escala tipográfica no respondía al tema ✅ RESUELTO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Problema | `ColorTextPrimary/Secondary/Disabled` existían como vars pero nunca se mutaban en `ApplyTheme()`. Resultado: en tema Esmeralda el texto secundario seguía siendo slate (azul-gris), no verde. |
| Solución | `Theme` struct expandido con `TextPrimary/Secondary/Disabled`. Cada uno de los 7 temas define su propia escala de texto. `ApplyTheme()` muta `ColorTextPrimary`, `ColorTextSecondary`, `ColorTextDisabled`, `ColorWhite`, `ColorMuted`. `rebuildThemeComponents()` reconstruye `White`, `Dim`, `Muted`, `Slate`, `Inactive`, `SectionTitle`, `ScrollTrack`, `Footer`, `TableHeader`. |
| Nuevo token | `Inactive = lipgloss.NewStyle().Foreground(ColorTextDisabled)` — para opciones/elementos deshabilitados, responde al tema. |
| Antes | `Slate.Render("...")` para inactivo — siempre slate-700 (#334155) |
| Después | `Inactive.Render("...")` — usa `ColorTextDisabled` del tema activo |

### A-05 — `ColorWhite` no se tematiza ✅ RESUELTO 2026-06-14 (incluido en A-06)
| Campo | Detalle |
|-------|---------|
| Solución | `ColorWhite` ahora se muta en `ApplyTheme()` → `t.TextPrimary`. `White = lipgloss.NewStyle().Foreground(ColorTextPrimary)` se reconstruye en `rebuildThemeComponents()`. |
| Campo | Detalle |
|-------|---------|
| Severidad | **BAJA** — no rompe nada hoy, sí limita temas futuros |
| Archivo | `styles/tokens_semantic.go` |
| Problema | `ColorWhite = lipgloss.Color(PrimSlate50)` es una var, pero `ApplyTheme()` nunca la muta → en todos los temas el texto de cabecera de tabla es el mismo blanco |
| Solución propuesta | Agregar `TableHeaderFg` a struct `Theme` + mutarlo en `ApplyTheme()` |

---

## CATEGORÍA B — GRID Y LAYOUT

### B-01 — Grid de dashboard hardcodeado 3/12 ✅ RESUELTO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | **MEDIA** — no se adapta bien en terminales muy anchos o muy estrechos |
| Archivo | `ctrl/render.go:47` |
| Problema | `menuW := dm.Width * 3 / 12` — proporción fija al 25%. En 220 cols el menú tiene 55 cols (excesivo). Clamp inferior a 24 cols pero no clamp superior. |
| Solución propuesta | Clamp superior: `if menuW > 32 { menuW = 32 }`. Proporción óptima: 3/12 para <120 cols, fijo 28 para ≥120 cols. |

### B-02 — `renderTopBar` del dashboard con estilos inline ⬜ PENDIENTE
| Campo | Detalle |
|-------|---------|
| Severidad | **BAJA** — funcional pero no usa componentes del design system |
| Archivo | `ctrl/render.go:65-109` |
| Problema | `lipgloss.NewStyle().Foreground(styles.ColorCyan).Bold(true)` inline en `l1`. Debería ser `styles.AccentBold` o similar. Dos `lipgloss.NewStyle().Width(w).Render(...)` inline (líneas 106-107) podrían ser `styles.FillWidth(w)`. |
| Solución propuesta | Crear `styles.AccentBold` en `tokens_component.go` + helper `dash.FillRow(s, w)` |

### B-03 — `renderMenu` del dashboard con estilos inline para label activo/inactivo ✅ RESUELTO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | **MEDIA** — el menú lateral es el componente más visible del dashboard |
| Archivo | `ctrl/render.go:178-201` |
| Problema | Tres variantes de labelStr se crean inline: activo con `ColorCyan`, seleccionado con `ColorWhite`, normal con `ColorMuted`. Deberían ser componentes del design system. El item activo no usa `styles.BoxActive` / `styles.LabelActive`. |
| Solución propuesta | Crear `styles.MenuItemActive`, `styles.MenuItemSelected`, `styles.MenuItemNormal` en `tokens_component.go`. Agregarlos a `rebuildThemeComponents()`. |

### B-04 — `shared.go:RenderMenu` construye `sActive` inline ✅ RESUELTO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | **MEDIA** — afecta wizard (pantallas S01-S04) |
| Archivo | `screens/shared.go:44-49` |
| Problema | `sActive` y `sInactive` se crean con `lipgloss.NewStyle()` inline en cada render. `sActive` mezcla `ColorMenuActiveBg` + `ColorCyan` — si el tema cambia el background, el menú del wizard no lo refleja. |
| Solución propuesta | Mover `sActive` a `tokens_component.go` como `styles.WizardMenuActive`; agregarlo a `rebuildThemeComponents()`. |

### B-05 — `WrapWithMargin` usa margen fijo `termW/12` ✅ RESUELTO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | **BAJA** — margenes del wizard. A 120 cols = 10 cols de margen (bien). A 220 cols = 18 cols (excesivo). |
| Archivo | `screens/shared.go:23` |
| Problema | Sin clamp superior: en terminales muy anchos el wizard se ve estrecho. |
| Solución propuesta | `col := termW / 12; if col > 16 { col = 16 }` |

---

## CATEGORÍA C — ESTILOS INLINE (T-100 — Bloque 10)

### C-01 — Patron `lipgloss.NewStyle().Foreground(styles.ColorWhite).Width(N)` 🔶 PARCIALMENTE RESUELTO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | **ALTA** — 205 instancias originales → reemplazadas masivamente con `perl -pi` |
| Estado | Bulk de `NewStyle().Foreground(ColorWhite).Width(N)` → `styles.TableHeader.Width(N)` **completado** |
| Restante | 7 instancias de `styles.White.Render()` directo en pantallas → ver **C-07** |
| Archivos ya limpios | `k8s/as.go`, `k8s/sto.go`, `k8s/net.go`, `k8s/cp.go`, `panel/pam.go`, `panel/backups.go` |

### C-02 — Patrón `lipgloss.NewStyle().Foreground(styles.ColorCyan)` inline 🔶 PARCIALMENTE RESUELTO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | **ALTA** — 55 instancias inline originales → reemplazadas con bulk `perl -pi` |
| Estado | Bulk de `NewStyle().Foreground(ColorCyan)` → `styles.Cyan.Render()` **completado** |
| Restante | 41 instancias de `styles.Cyan.Render()` directo → ver **C-05** (no son component tokens) |

### C-03 — `viewport.go`: scrollbar con estilos inline ✅ RESUELTO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | **BAJA** — 4 instancias en `VScrollbar` y `HScrollbar` |
| Archivo | `model/viewport.go:48-84` |
| Problema | `track` y `thumb` se crean con `lipgloss.NewStyle()` en cada llamada. No usan el tema (aunque leen `ColorSlate`/`ColorCyan` que sí son vars mutables). |
| Solución propuesta | Pre-computar en `tokens_component.go` como `ScrollTrack` y `ScrollThumb`; agregarlos a `rebuildThemeComponents()`. |

### C-04 — `screens/s05_instalando.go`: colores de log hardcodeados ✅ RESUELTO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | **MEDIA** — pantalla principal de instalación |
| Archivo | `screens/s05_instalando.go:58-59` |
| Problema | `cTag` y `cMsg` asignados a `lipgloss.Color(cTag)` inline. Los colores de log deben venir de `tokens_state.go` (ya existe el sistema de colores de estado). |
| Solución propuesta | Mapear nivel de log a `styles.ColorStateXxxFg` en lugar de calcular inline. |

---

### C-05 — `styles.Cyan.Render()` directo en pantallas/ctrl — 41 instancias ✅ COMPLETADO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | **ALTA** — viola el principio de Design Tokens: las pantallas NO deben usar tokens de COLOR, deben usar tokens de COMPONENTE |
| Problema | `styles.Cyan.Render(x)` en render code significa "pinto esto en cyan" — acoplamiento a un color específico. Si el tema cambia el acento, este código ignora el cambio semántico. El componente correcto es el que codifica LA INTENCIÓN, no el color. |
| Principio | **Capa 3 (Componente) abstrae Capa 2B (Semántico).** Nunca saltar capas. |
| Instancias | 41 ocurrencias en: `render.go`, `widgets.go`, `jobs.go`, `monitoreo.go`, `net_os.go`, `overview.go`, `s05_instalando.go`, `s05b_log.go`, `s06_done.go`, `s08_boot.go`, `sauth_confirm.go`, `shared.go`, `disco.go`, `kernel.go`, `metricas.go`, `red.go`, `procesos.go` |
| Tokens de componente a usar | Ver tabla de soluciones abajo |
| Solución | Definir tokens de componente con semántica clara. Reemplazar con `perl -pi` + ajustes manuales por contexto |

#### Tabla de soluciones C-05 — Clasificación por intención

| Patrón encontrado | Intención semántica | Token a usar | Nuevo token a crear |
|-------------------|--------------------|--------------|--------------------|
| `styles.Cyan.Render(item.Label)` — sección de grupo | Etiqueta de grupo/sección | `styles.SectionTitle` | — (ya existe) |
| `styles.Cyan.Render("> ")` — cursor de menú activo | Cursor/puntero de navegación | `styles.AccentBold` | — (ya existe) |
| `styles.Cyan.Render("> "+dm.Env)` — env activo | Valor de entorno activo | `styles.AccentBold` | — (ya existe) |
| `styles.Cyan.Render(r[1])` — valor de dato | Valor de dato resaltado | `styles.DataAccent` | **DataAccent** |
| `styles.Cyan.Render(fmt.Sprintf("%.0f", cur))` — métrica | Valor de métrica accent | `styles.DataAccent` | **DataAccent** |
| `styles.Cyan.Render("↓ RX: ...")` — tráfico red RX | Flujo de entrada (descarga) | `styles.MetricRX` | **MetricRX** |
| `styles.Cyan.Render(fmt.Sprintf("%d%%", j.Pct))` — porcentaje | Progreso resaltado | `styles.DataAccent` | **DataAccent** |
| `styles.Cyan.Render(strings.Repeat("█", filled))` — barra | Barra de progreso accent | `styles.AccentBar` | **AccentBar** |
| `styles.Cyan.Render(ni.Name)` — nombre interfaz | Nombre de recurso activo | `styles.ResourceName` | **ResourceName** |
| `styles.Cyan.Render(fid)` — ficha activa | Identificador de ficha | `styles.AccentBold` | — (ya existe) |
| `styles.Cyan.Render(m.LogSearch)` — búsqueda | Término de búsqueda activo | `styles.AccentBold` | — (ya existe) |
| `styles.Cyan.Render(strconv.Itoa(cntDone))` — contador | Contador positivo | `styles.CountOK` | **CountOK** |
| `styles.Cyan.Render(" bKernel")` — nombre de daemon | Nombre de daemon | `styles.DaemonName` | **DaemonName** |
| `styles.Cyan.Render("https://...")` — URL | URL/enlace | `styles.LinkText` | **LinkText** |
| `styles.Cyan.Render(bar)` — barra de boot | Barra de progreso boot | `styles.AccentBar` | **AccentBar** |
| `styles.Cyan.Render(" Sistema listo")` — status OK | Estado completado | `styles.AccentBold` | — (ya existe) |
| `styles.Cyan.Render("  ✓ ...")` — confirmación | Confirmación auth | `styles.AccentBold` | — (ya existe) |
| `styles.Cyan.Render(" "+s.name)` — tab activo | Tab activo de wizard | `styles.TabActive` | **TabActive** |
| `styles.Cyan.Render("[ Enter ] ...")` — hint de teclado | Hint de teclado activo | `styles.KeyHint` | **KeyHint** |

#### Nuevos tokens de componente a crear (C-05)

| Token | Definición inicial | Semántica |
|-------|-------------------|-----------|
| `TabActive` | `Foreground(ColorCyan).Bold(true).Underline(true)` | Tab/paso activo del wizard |
| `DataAccent` | `Foreground(ColorCyan)` | Valor de dato resaltado con acento |
| `MetricRX` | `Foreground(ColorCyan)` | Métrica de red de entrada (RX/descarga) |
| `MetricTX` | `Foreground(ColorGreen)` | Métrica de red de salida (TX/subida) |
| `AccentBar` | `Foreground(ColorCyan)` | Barra de progreso con color de acento |
| `ResourceName` | `Foreground(ColorCyan).Bold(true)` | Nombre de recurso/interfaz activo |
| `CountOK` | `Foreground(ColorCyan)` | Contador de éxitos/completados |
| `DaemonName` | `Foreground(ColorCyan).Bold(true)` | Nombre de daemon SBOS |
| `LinkText` | `Foreground(ColorCyan).Underline(true)` | URL o enlace |
| `KeyHint` | `Foreground(ColorCyan)` | Hint de tecla en instrucciones |

---

### C-06 — `styles.Green/Red/Yellow.Render()` estado en pantallas — 45 instancias ✅ COMPLETADO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | **ALTA** — viola el principio de Design Tokens: pantallas deben usar tokens de COMPONENTE de estado, no tokens de color |
| Problema | `styles.Green.Render("Running")` no es semántico — si el tema cambia el verde, el estado no se actualiza correctamente. El componente correcto abstrae "estado OK" del color específico. |
| Instancias | 45 ocurrencias en: `as.go`, `cp.go`, `sto.go`, `wl.go`, `alertas.go`, `config.go`, `jobs.go`, `seguridad.go`, `stor_os.go`, `disco.go`, `metricas.go`, `procesos.go`, `red.go`, `systemd.go`, `s05_instalando.go`, `s05c_error.go`, `s06_done.go`, `sauth_confirm.go`, `sauth_login.go` |

#### Tabla de soluciones C-06

| Patrón encontrado | Token correcto | Ya existe |
|------------------|---------------|-----------|
| `styles.Green.Render("Running")` — pod running | `styles.StatusOK` | Nuevo |
| `styles.Green.Render("activo")` — servicio activo | `styles.StatusOK` | Nuevo |
| `styles.Green.Render(" Sin procesos zombie")` — todo OK | `styles.Success` | ✅ ya existe |
| `styles.Green.Render("✔ Todos los cert...")` — OK | `styles.Success` | ✅ ya existe |
| `styles.Green.Render("PASSED")` — health check OK | `styles.StatusOK` | Nuevo |
| `styles.Green.Render(fmt.Sprintf("%-14s", s.status))` — status OK | `styles.StatusOK` | Nuevo |
| `styles.Green.Render(fmt.Sprintf("%.0f%%", minV))` — métrica OK | `styles.MetricOK` | Nuevo |
| `styles.Green.Render("↑ TX: ...")` — tráfico TX | `styles.MetricTX` | (ver C-05) |
| `styles.Green.Render(dash.FormatBytesPS(ni.TXBytesS))` — TX | `styles.MetricTX` | (ver C-05) |
| `styles.Green.Render("0.8%")` — I/O wait bajo | `styles.MetricOK` | Nuevo |
| `styles.Green.Render(m.Status)` — módulo OK | `styles.StatusOK` | Nuevo |
| `styles.Green.Render(" "+e.status)` — estado job OK | `styles.StatusOK` | Nuevo |
| `styles.Green.Render(" Sin instalaciones...")` — OK | `styles.Success` | ✅ ya existe |
| `styles.Yellow.Render("Pending")` — pod pending | `styles.StatusWarn` | Nuevo |
| `styles.Yellow.Render("stopped")` — servicio stopped | `styles.StatusWarn` | Nuevo |
| `styles.Yellow.Render("! MaxReplicas")` — HPA límite | `styles.Warning` | ✅ ya existe |
| `styles.Yellow.Render(fmt.Sprintf("%d/min", c.ErrorsMin))` | `styles.Warning` | ✅ ya existe |
| `styles.Yellow.Render(fmt.Sprintf("%d", p.Restarts))` — restarts | `styles.StatusWarn` | Nuevo |
| `styles.Yellow.Render("Warnings:")` — label warn | `styles.Warning` | ✅ ya existe |
| `styles.Yellow.Render(" "+r.sev)` — severidad warn | `styles.Warning` | ✅ ya existe |
| `styles.Yellow.Render("⚠ Daemon bos no...")` — error conexión | `styles.Warning` | ✅ ya existe |
| `styles.Red.Render("Error")` — pod error | `styles.StatusErr` | Nuevo |
| `styles.Red.Render("failed")` — servicio failed | `styles.StatusErr` | Nuevo |
| `styles.Red.Render(d.Health)` — disco health fail | `styles.StatusErr` | Nuevo |
| `styles.Red.Render("! Alto")` — HPA alto | `styles.Error` | ✅ ya existe |
| `styles.Red.Render(fmt.Sprintf("%d", p.Restarts))` — restarts altos | `styles.StatusErr` | Nuevo |
| `styles.Red.Render("Críticas:")` — label crit | `styles.Error` | ✅ ya existe |
| `styles.Red.Render(" "+r.sev)` — severidad crit | `styles.Error` | ✅ ya existe |
| `styles.Red.Render("⚠ %d cert expirand...")` — alerta cert | `styles.Error` | ✅ ya existe |
| `styles.Red.Render("│ "+l)` — línea de error | `styles.Error` | ✅ ya existe |
| `styles.Red.Render("✗ "+e)` — error auth | `styles.Error` | ✅ ya existe |
| `styles.Red.Render(strconv.Itoa(cntFailed))` — counter fail | `styles.CountErr` | Nuevo |

#### Nuevos tokens de componente a crear (C-06)

| Token | Definición inicial | Semántica |
|-------|-------------------|-----------|
| `StatusOK` | `Foreground(ColorStateOKFg)` | Estado de servicio/pod operativo (sin bold) |
| `StatusWarn` | `Foreground(ColorStateWarnFg)` | Estado intermedio: pending, stopped, degraded |
| `StatusErr` | `Foreground(ColorStateErrFg)` | Estado de error: failed, error, crash |
| `MetricOK` | `Foreground(ColorStateOKFg)` | Métrica dentro de rango normal |
| `CountErr` | `Foreground(ColorStateErrFg)` | Contador de fallos |

*Nota: `Success`, `Warning`, `Error` (ya existen) son para MENSAJES al operador (con Bold). `StatusOK/Warn/Err` son para estados de servicio inline (sin Bold). Distinción intencional.*

---

### C-07 — `styles.White.Render()` dato en pantallas — 7 instancias ✅ COMPLETADO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | **MEDIA** — residuo del bulk C-01 |
| Problema | `styles.White.Render(x)` en pantallas usa token de COLOR, no de COMPONENTE |
| Token correcto | `styles.TableHeader.Render(x)` (ya existe, ya responde a tema) |
| Archivos | `config.go`, `helpers.go`, `net_os.go`, `red.go`, `usuarios.go` |
| Solución | `perl -pi -e 's/styles\.White\.Render/styles.TableHeader.Render/g'` en esos archivos + verificar contexto |

---

## CATEGORÍA D — RESPONSIVIDAD

### D-01 — Tablas del dashboard con ancho fijo interno ⬜ PENDIENTE
| Campo | Detalle |
|-------|---------|
| Severidad | **ALTA** — en terminales estrechos (<100 cols) las tablas del dashboard se desborden o truncan mal |
| Archivos | `k8s/as.go`, `k8s/cp.go`, `k8s/net.go`, `k8s/sto.go`, `panel/*.go` |
| Problema | Columnas con widths fijos (12, 22, 10, etc.). No calculan `w` del contenedor para distribuir proporcionalmente. `nameW`, `tgtW` sí se calculan como porcentaje de `w` en algunos; los demás son hardcodeados. |
| Solución propuesta | Convertir todas las columnas fijas a porcentajes de `w`. Crear helper `dash.ColWidths(w int, pcts []int) []int` que distribuye `w` en partes proporcionales sumando a exactamente `w`. |

### D-02 — `screens/s00_welcome.go`: icono SBOS puede desbordar en terminales estrechos ⬜ PENDIENTE
| Campo | Detalle |
|-------|---------|
| Severidad | **BAJA** |
| Archivo | `screens/s00_welcome.go:128` |
| Problema | `lipgloss.NewStyle().Width(w).Align(lipgloss.Center).Render(icon)` — si `w < iconWidth` el ícono se desborda. |
| Solución propuesta | Guard: `if w < 40 { return "" }` antes de renderizar el ícono. |

---

## CATEGORÍA E — NOMENCLATURA Y CONSISTENCIA

### E-01 — `dash.SectionHeader` crea estilo inline en cada llamada ✅ RESUELTO 2026-06-14
| Campo | Detalle |
|-------|---------|
| Severidad | **BAJA** |
| Archivo | `ctrl/dash/widgets.go:133-138` |
| Problema | `lipgloss.NewStyle().Foreground(styles.ColorMuted).Italic(true)` creado en cada llamada. |
| Solución propuesta | Pre-computar como `styles.SectionTitle` en `tokens_component.go`. |

### E-02 — `dash.RightPane` crea estilo inline ⬜ PENDIENTE (baja prioridad)
| Campo | Detalle |
|-------|---------|
| Severidad | **BAJA** |
| Archivo | `ctrl/dash/widgets.go:150-157` |
| Problema | Borde y padding recreados en cada llamada. |
| Solución propuesta | Pre-computar como `styles.RightPane` en `tokens_component.go`. |

---

## MAPA DE PRIORIDADES — ORDEN DE REPARACIÓN

```
PRIORIDAD 1 — Correctness de temas (impacto directo en el usuario):
  ✅ A-01: HexXxx → vars mutables (HECHO)
  ✅ A-02: ApplyTheme() conectado (HECHO)
  ✅ A-03: Tema pizarron corregido (HECHO)
  ✅ B-01: Grid dashboard clamp menuW 24-30 (HECHO)
  ✅ B-03: renderMenu → MenuItemActive/Focused/Normal (HECHO)
  ✅ B-04: RenderMenu wizard → WizardMenuActive (HECHO)
  ✅ B-05: WrapWithMargin → MarginW() clamp 16 (HECHO)
  ✅ A-05: ColorWhite tematizable — resuelto en A-06 (HECHO)
  ✅ A-06: Escala tipográfica: TextPrimary/Secondary/Disabled en Theme struct (HECHO)
  ✅ B-02: TopBar → lipgloss.NewStyle().Width(w) neutro (HECHO)
  ✅ C-03: Scrollbars → ScrollTrack/ScrollThumb (HECHO)
  ✅ C-04: s05 log colors → tokens_state (HECHO)
  ✅ E-01: SectionHeader → SectionTitle (HECHO)
  🔶 C-01: 205× ColorWhite inline → TableHeader (bulk hecho, 7 restantes en C-07)
  🔶 C-02: 55× ColorCyan inline → Cyan (bulk hecho, 41 restantes como C-05)

PRIORIDAD 2 — Tokens de componente correctos (principio 4 capas):
  ✅ C-05: 41× styles.Cyan.Render() → tokens de componente (ResourceName, AccentBold, AccentBar, DataAccent, MetricRX, ...) HECHO
  ✅ C-06: 45× styles.Green/Red/Yellow.Render() → StatusOK/Warn/Err/Info HECHO
  ✅ C-07: 7× styles.White.Render() → styles.TableHeader HECHO

PRIORIDAD 3 — Responsividad:
  ⬜ D-01: Tablas dashboard widths proporcionales → dash.ColWidths()
  ⬜ D-02: s00_welcome icono guard w<40

PRIORIDAD 4 — Tematización avanzada y optimizaciones:
  ⬜ A-04: Agregar ColorTableHeader a Theme struct (hacer TableHeader completamente tematizable)
  ⬜ A-05: ColorWhite tematizable via Theme struct
  ⬜ E-02: dash.RightPane pre-computado como styles.RightPane
```

---

## TOKENS NUEVOS A CREAR EN `tokens_component.go`

Al completar las reparaciones, estos tokens deben existir en `tokens_component.go` y reconstruirse en `rebuildThemeComponents()`:

### Ya creados ✅
| Token | Definición | Uso |
|-------|-----------|-----|
| `TableHeader` | `Foreground(ColorTextPrimary)` | Cabecera de columna en tablas |
| `MenuItemActive` | `Background(ColorCyan).Foreground(ColorBlack).Bold(true)` | Menú dashboard: item activo con foco |
| `MenuItemFocused` | `Foreground(ColorTextPrimary).Bold(true)` | Menú dashboard: item seleccionado sin foco |
| `MenuItemNormal` | `Foreground(ColorTextSecondary)` | Menú dashboard: item normal |
| `WizardMenuActive` | `Background(ColorMenuActiveBg).Foreground(ColorCyan).Bold(true)` | Menú wizard: opción seleccionada |
| `ScrollTrack` | `Foreground(ColorSlate)` | Barra de scroll (pista) |
| `ScrollThumb` | `Foreground(ColorCyan)` | Barra de scroll (pulgar activo) |
| `SectionTitle` | `Foreground(ColorMuted).Italic(true)` | Título de sección del dashboard |
| `AccentBold` | `Foreground(ColorCyan).Bold(true)` | Texto bold en color de acento |
| `Panel` | `Border + Background(ColorBgSurface)` | Panel de contenido |
| `Box` / `BoxActive` | `Border + Background(...)` | Caja con/sin foco |

### Ya creados ✅ (C-05 — acento)
| Token | Definición | Semántica | Reconstituir en rebuildThemeComponents() |
|-------|-----------|-----------|----------------------------------------|
| `TabActive` | `Foreground(ColorCyan).Bold(true).Underline(true)` | Tab activo en wizard | ✅ sí |
| `DataAccent` | `Foreground(ColorCyan)` | Valor de dato resaltado | ✅ sí |
| `MetricTX` | `Foreground(ColorGreen)` | Tráfico red salida (TX/upload) | ✅ sí |
| `MetricRX` | `Foreground(ColorCyan)` | Tráfico red entrada (RX/download) | ✅ sí |
| `AccentBar` | `Foreground(ColorCyan)` | Barra de progreso con color acento | ✅ sí |
| `ResourceName` | `Foreground(ColorCyan).Bold(true)` | Nombre de recurso/interfaz activo | ✅ sí |
| `CountOK` | `Foreground(ColorCyan)` | Contador de éxitos/completados | ✅ sí |
| `DaemonName` | `Foreground(ColorCyan).Bold(true)` | Nombre de daemon SBOS en listas | ✅ sí |
| `LinkText` | `Foreground(ColorCyan).Underline(true)` | URL o enlace interactivo | ✅ sí |
| `KeyHint` | `Foreground(ColorCyan)` | Hint de tecla en instrucciones | ✅ sí |

### Ya creados ✅ (C-06 — estado sin bold)
| Token | Definición | Semántica | Reconstituir |
|-------|-----------|-----------|-------------|
| `StatusOK` | `Foreground(ColorStateOKFg)` | Estado OK de servicio/pod (sin bold) | ❌ usa tokens_state que no cambia por tema |
| `StatusWarn` | `Foreground(ColorStateWarnFg)` | Estado pending/stopped/degraded | ❌ usa tokens_state |
| `StatusErr` | `Foreground(ColorStateErrFg)` | Estado failed/error/crash | ❌ usa tokens_state |
| `MetricOK` | `Foreground(ColorStateOKFg)` | Métrica dentro de rango normal | ❌ usa tokens_state |
| `CountErr` | `Foreground(ColorStateErrFg)` | Contador de fallos | ❌ usa tokens_state |

*Nota: tokens de estado (StatusOK/Warn/Err) NO se reconstruyen con ApplyTheme() porque usan `tokens_state.go` — el sistema de semáforo de estado es intencional e independiente del tema visual (ADR implícito).*

---

## HELPERS NUEVOS A CREAR EN `ctrl/dash/`

| Helper | Firma | Uso |
|--------|-------|-----|
| `TH(w int) lipgloss.Style` | `dash/widgets.go` o `tokens_component.go` | Cabecera de tabla con ancho |
| `ColWidths(w int, pcts []int) []int` | `dash/widgets.go` | Distribuye ancho en columnas proporcionales |

---

## HISTORIAL DE SESIONES DE REPARACIÓN

| Fecha | Sesión | Resueltos | Commit |
|-------|--------|-----------|--------|
| 2026-06-14 | Sesión 1 | A-01, A-02, A-03 (temas) | bd734fe → ... |
| 2026-06-14 | Sesión 2 | B-01, B-02, B-03, B-04, B-05, C-01 bulk, C-02 bulk, C-03, C-04, E-01 — Grid struct + Theme Abyss + 7 temas | (committed) |
| 2026-06-14 | Sesión 3 | B-02 corregido (Rule→NewStyle neutro), C-01/C-02 residuos (wl.go, logs.go, model.go, icons.go), audit integral → C-05(41), C-06(45), C-07(7) formalizados | (committed) |
| 2026-06-14 | Sesión 4 | C-05 completo (41 instancias → ResourceName/AccentBold/AccentBar/DataAccent/Info/KeyHint), C-06 completo (45 instancias → StatusOK/Warn/Err), C-07 completo (7 instancias → TableHeader), T-100 ✅, build limpio | (committed) |
| 2026-06-14 | **Sesión 5 — Blindaje secuencias** | **GAP-01 ✅** (SetInstalledBoot→ScreenAuthLogin), **GAP-02 ✅** (keyDashboard→LoA enforcement + PendingDashAction en StepUpResultMsg), **GAP-03 ✅** (keySplashWelcome→ScreenAuthLogin), **GAP-05 ✅** (tema default abyss documentado) | (en progreso) |

---

*Este registro es la fuente de verdad del estado de reparación del TUI.  
Actualizar en cada sesión: añadir fecha, commit y cambiar ⬜ a ✅ al completar.*
