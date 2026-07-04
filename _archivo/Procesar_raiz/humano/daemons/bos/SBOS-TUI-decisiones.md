# SBOS Installer TUI — Diseño Final Aprobado
## Especificación de implementación para el agente

> ⚠️ **ATENCIÓN AGENTE**: Este documento NO es una propuesta de diseño.
> Es el diseño FINAL aprobado por el equipo. Cada pantalla, cada color,
> cada comportamiento fue revisado y confirmado.
> Tu trabajo es IMPLEMENTAR exactamente lo que está aquí documentado,
> no reinterpretarlo, no simplificarlo, no "mejorarlo".
> Si algo no está claro, pregunta. No asumas.

---

## 🤖 GUÍA PARA EL AGENTE DE IMPLEMENTACIÓN

> **Lee esta sección completa antes de escribir una sola línea de código.**
> Todo lo que necesitas saber sobre el stack, las técnicas y las reglas de diseño está aquí.
> Cada decisión visual fue tomada y aprobada — no improvises, implementa lo que dice este documento.

---

---

### 0. ARQUITECTURA DE LAYOUT — LEE ESTO PRIMERO

Esta es la regla más importante de toda la TUI. Si no la entiendes, el resto no funciona.

#### La pantalla tiene tres zonas fijas

```
┌─────────────────────────────────────────────────────────┐
│  ZONA TOP — altura FIJA, nunca crece                    │
│  ─ topbar        (1 línea siempre)                      │
│  ─ stepper       (1 línea, solo wizard P1–P5)           │
│  ─ screen-title  (1 línea siempre)                      │
│  ─ divider       (1 línea siempre)                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ZONA BODY — altura DINÁMICA                            │
│  flex: 1 — ocupa TODO el espacio que sobra              │
│  entre el TOP y el BOTTOM                               │
│  NUNCA desborda. Si el contenido es mayor               │
│  que el body, el body tiene scrollbar.                  │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  ZONA BOTTOM — altura FIJA, nunca crece                 │
│  ─ nav-hint      (1 línea opcional)                     │
│  ─ footer        (1 línea siempre)                      │
└─────────────────────────────────────────────────────────┘
```

#### Cálculo del body height — OBLIGATORIO en cada pantalla

```go
// Llamar en Init() y en cada tea.WindowSizeMsg
func (m *Model) recalcBodyHeight() {
    topH := 1 + 1 + 1 // topbar + screen-title + divider
    if m.showStepper  { topH++ } // stepper solo en wizard P1–P5

    botH := 1 // footer
    if m.showNavHint  { botH++ } // nav-hint opcional

    m.bodyHeight = m.height - topH - botH
    // Este valor es el que se pasa a TODOS los viewports del body
}
```

#### El body SIEMPRE usa viewport.Model — SIN EXCEPCIONES

Nunca renderices el body como un string suelto. El viewport es lo que:
1. Limita el contenido visible a exactamente `bodyHeight` líneas
2. Agrega scrollbar automático cuando el contenido excede el espacio
3. Responde a ↑↓ PgUp/PgDn del usuario

```go
// Inicializar
m.bodyVP = viewport.New(m.width, m.bodyHeight)
m.bodyVP.SetContent(m.renderBodyContent())

// En CADA tea.WindowSizeMsg — sin excepción
case tea.WindowSizeMsg:
    m.width  = msg.Width
    m.height = msg.Height
    m.recalcBodyHeight()
    m.bodyVP.Width  = m.width
    m.bodyVP.Height = m.bodyHeight
    m.bodyVP.SetContent(m.renderBodyContent())
```

#### Pantallas con múltiples paneles internos (P5, P9, P10)

Cuando el body tiene sub-paneles (logs + árbol de fases + componente activo), cada panel tiene su propio viewport. Las alturas deben sumar exactamente `bodyHeight`:

```go
// Ejemplo P5 — barra de progreso + 3 paneles + nav-hint
func (m *InstallingModel) recalcPanels(bodyH, width int) {
    progressH := 3 // barra (1) + pct/fichas/elapsed (1) + contadores (1)
    navHintH  := 1 // "[Tab] cambiar panel  [↑↓] scroll..."
    panelH    := bodyH - progressH - navHintH

    m.vpA.Height = panelH
    m.vpB.Height = panelH
    m.vpC.Height = panelH

    // Anchos proporcionales al terminal real — nunca hardcodeados
    m.vpA.Width = int(float64(width)*0.36) - 2
    m.vpB.Width = int(float64(width)*0.30) - 2
    m.vpC.Width = width - m.vpA.Width - m.vpB.Width - 6
}
```

#### View() — estructura obligatoria para TODAS las pantallas

```go
func (m Model) View() string {
    // TOP — altura fija y conocida
    top := lipgloss.JoinVertical(lipgloss.Left,
        renderTopBar(m.width),
        renderStepper(m.screen, m.width),   // "" si no aplica
        renderScreenTitle(m.title, m.width),
        strings.Repeat("─", m.width),
    )

    // BOTTOM — altura fija y conocida
    bottom := lipgloss.JoinVertical(lipgloss.Left,
        renderNavHint(m.width),             // "" si no aplica
        m.help.View(m.keys),                // footer con key.Binding
    )

    // BODY — viewport que ocupa exactamente lo que queda
    // El contenido interno puede ser infinito — solo bodyHeight líneas son visibles
    body := m.bodyVP.View()

    return lipgloss.JoinVertical(lipgloss.Left, top, body, bottom)
}
```

#### Errores comunes que el agente NO debe cometer

```
❌ Renderizar body como string suelto sin viewport
   → El contenido desborda la terminal sin control ni scrollbar

❌ Viewport con Height hardcodeado (Height: 20, Height: 30...)
   → Rompe en cualquier terminal que no sea exactamente ese tamaño

❌ No manejar tea.WindowSizeMsg
   → Los viewports no se recalculan al redimensionar la terminal

❌ Logs que crecen como strings concatenados fuera de viewport
   → P5/P8/P10/P11: logs SIEMPRE dentro de viewport.Model

❌ Sub-paneles con alturas que no suman bodyHeight
   → Desbordamiento o espacio en blanco al pie de la pantalla

❌ Usar lipgloss.Height() para medir contenido en caliente
   → Usa contadores enteros: topH, botH, bodyHeight = height - topH - botH
```

### 1. Qué estás construyendo

**bosctl** es la interfaz TUI (Text User Interface) del daemon `bos` del sistema SBOS.
Tiene dos modos de operación:

- **Primera ejecución**: detecta que no hay instalación → lanza el wizard (P1–P7)
- **Ejecuciones siguientes**: detecta instalación existente → arranca el runtime (P8–P11)

La TUI **no es decorativa**. Es la única interfaz de operación del bos. Debe ser robusta, clara y funcionar en terminales reales de servidores Ubuntu.

---

### 2. Stack técnico y para qué sirve cada librería

```
github.com/charmbracelet/bubbletea     — El runtime. Arquitectura Elm: Model/Update/View.
                                          Maneja el loop de eventos, mensajes async (Cmd),
                                          ticks de tiempo y composición de sub-modelos.
                                          REGLA: toda lógica va en Update(), nunca en View().

github.com/charmbracelet/lipgloss       — El sistema de estilos. CSS-like para terminal.
                                          Maneja bordes, colores, padding, width, align.
                                          REGLA: define todos los estilos como vars globales,
                                          nunca inline dentro de View().

github.com/charmbracelet/bubbles/textinput  — Campos de texto editables con cursor,
                                              máscara de contraseña (EchoPassword),
                                              placeholder y validación.

github.com/charmbracelet/bubbles/viewport   — Panel con scroll vertical y/u horizontal.
                                              Usado en P5 (paneles A/B/C), P10 logs,
                                              y cualquier contenido que desborde.

github.com/charmbracelet/bubbles/progress   — Barra de progreso animada con tea.Cmd.
                                              Usada en P5 (instalación) y P8 (arranque).

github.com/charmbracelet/bubbles/spinner    — Spinner animado ⠿ frames braille.
                                              REGLA: un solo spinner.Model global en el
                                              Model raíz — compártelo entre pantallas.

github.com/charmbracelet/bubbles/help       — Renderiza los key.Binding del footer
                                              automáticamente en una línea.

github.com/charmbracelet/bubbles/key        — Define atajos de teclado con descripción
                                              y los conecta con help.Model.
```

---

### 3. Arquitectura del Model principal

El programa tiene **un solo tea.Program** con un **Model raíz** que contiene un campo `screen` que determina qué pantalla renderizar. Cada pantalla es un sub-modelo.

```go
type Screen int
const (
    ScreenWelcome    Screen = iota // splash WELCOME BOS
    ScreenWizardP1                 // bienvenida instalador
    ScreenWizardP2                 // datos empresa
    ScreenWizardP3                 // cuenta admin
    ScreenWizardP4                 // confirmar instalación
    ScreenInstalling               // P5 instalación en progreso
    ScreenInstallLog               // P5B log completo
    ScreenInstallErr               // P5C panel de error
    ScreenInstallDone              // P6 instalación completada
    ScreenReboot                   // P7 reinicio post-instalación
    ScreenBoot                     // P8 arranque bos
    ScreenDashboard                // P9 dashboard permanente
    ScreenLogs                     // P10 logs puros
    ScreenShutdown                 // P11 apagado/reinicio
    ScreenGoodbye                  // splash GOODBYE BOS
)

type Model struct {
    screen   Screen
    width    int
    height   int
    spinner  spinner.Model   // compartido — un solo spinner global
    // sub-modelos por pantalla:
    welcome  WelcomeModel
    tenant   TenantModel
    admin    AdminModel
    confirm  ConfirmModel
    install  InstallingModel
    boot     BootModel
    dash     DashboardModel
    logs     LogsModel
    shutdown ShutdownModel
}
```

**Detección de primera ejecución:**
```go
func isInstalled() bool {
    _, err := os.Stat("/etc/sbos/tenant.conf")
    return err == nil
}

func initialScreen() Screen {
    if isInstalled() {
        return ScreenWelcome // → luego ScreenBoot
    }
    return ScreenWelcome // → luego ScreenWizardP1
}
```

---

### 4. El patrón Update() — cómo manejar eventos

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {

    // Redimensión de terminal — SIEMPRE manejar
    case tea.WindowSizeMsg:
        m.width = msg.Width
        m.height = msg.Height
        // propagar a viewports activos
        return m, nil

    // Tick del spinner — reenviar a spinner y redibujar
    case spinner.TickMsg:
        var cmd tea.Cmd
        m.spinner, cmd = m.spinner.Update(msg)
        return m, cmd

    // Tick de tiempo propio (elapsed, reloj, logs en vivo)
    case tickMsg:
        m.elapsed++
        return m, tickCmd() // re-armar el tick

    // Mensajes de progreso de instalación (vía WebSocket/goroutine)
    case stepOkMsg:
        m.install.markStepDone(msg.fichaID, msg.stepID, msg.elapsed)
        return m, nil

    case fichaErrMsg:
        m.screen = ScreenInstallErr
        m.install.errPanel = buildErrPanel(msg)
        return m, nil

    // Delegación al sub-modelo activo
    case tea.KeyMsg:
        return m.updateActiveScreen(msg)
    }
    return m, nil
}
```

---

### 5. El patrón View() — cómo renderizar

**Regla fundamental:** View() es una función pura que solo lee el Model y devuelve un string. Nunca modifica estado en View().

```go
func (m Model) View() string {
    // Frame global: topbar + stepper + título + divisor + cuerpo + footer
    return lipgloss.JoinVertical(lipgloss.Left,
        m.renderTopBar(),
        m.renderStepper(),   // solo en pantallas del wizard P1–P5
        m.renderTitle(),
        strings.Repeat("─", m.width),
        m.renderBody(),      // delega según m.screen
        strings.Repeat("─", m.width),
        m.renderFooter(),
    )
}

func (m Model) renderBody() string {
    switch m.screen {
    case ScreenWelcome:    return m.welcome.View()
    case ScreenWizardP1:   return m.wizard.p1View()
    case ScreenWizardP2:   return m.tenant.View()
    // ...
    case ScreenDashboard:  return m.dash.View()
    case ScreenLogs:       return m.logs.View()
    case ScreenGoodbye:    return m.renderGoodbye()
    }
    return ""
}
```

---

### 6. Responsive — modos de terminal

```go
const (
    modeXS = "xs" // < 60 cols  — columna única sin bordes
    modeSM = "sm" // 60–79 cols — columna única con caja
    modeMD = "md" // ≥ 80 cols  — layout en columnas (diseño principal
)

func termMode(w int) string {
    switch {
    case w < 60:  return modeXS
    case w < 80:  return modeSM
    default:      return modeMD
    }
}
```

Todas las pantallas deben adaptarse al ancho real de la terminal (`m.width`). Los viewports deben recalcular su tamaño en `tea.WindowSizeMsg`.

---

### 7. Reglas de los iconos de estado — NUNCA heredar color del padre

Cada icono tiene su propio color explícito. Esto es una regla crítica — los iconos aparecen en contextos de distinto color de texto y deben ser siempre reconocibles.

```go
// Definir UNA VEZ como funciones helpers — usar en todas las pantallas
func icOk()   string { return lipgloss.NewStyle().Foreground(lipgloss.Color("#22c55e")).Render("✓") }
func icRun()  string { return lipgloss.NewStyle().Foreground(lipgloss.Color("#06b6d4")).Render("▶") }
func icSpin(m Model) string { return m.spinner.View() } // amarillo #f59e0b
func icPend() string { return lipgloss.NewStyle().Foreground(lipgloss.Color("#334155")).Render("○") }
func icErr()  string { return lipgloss.NewStyle().Foreground(lipgloss.Color("#ef4444")).Render("✗") }
func icWarn() string { return lipgloss.NewStyle().Foreground(lipgloss.Color("#f59e0b")).Render("⚠") }
func icBos()  string { return lipgloss.NewStyle().Foreground(lipgloss.Color("#06b6d4")).Render("⬡") }
```

---

### 8. El spinner — un solo modelo, compartido

```go
// En Init():
s := spinner.New()
s.Spinner = spinner.Spinner{
    Frames: []string{"⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"},
    FPS:    time.Second / 10,
}
s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("#f59e0b"))
m.spinner = s

// En Update() siempre manejar spinner.TickMsg:
case spinner.TickMsg:
    var cmd tea.Cmd
    m.spinner, cmd = m.spinner.Update(msg)
    return m, cmd

// En View() usar m.spinner.View() — NUNCA crear otro spinner
```

---

### 9. Viewports — scroll en paneles

```go
// Inicializar con tamaño explícito
vp := viewport.New(width, height)
vp.SetContent(content) // string con todo el contenido

// En tea.WindowSizeMsg recalcular:
m.vpA.Width  = int(float64(m.width) * 0.36)
m.vpA.Height = m.height - headerHeight - footerHeight
m.vpA.SetContent(m.renderPanelA())

// Panel C — auto-scroll al final cuando vpAutoScroll = true
if m.vpAutoScroll {
    m.vpC.GotoBottom()
}

// Viewport solo vertical: usar viewport.Model normalmente
// Viewport vertical + horizontal: wrappear contenido con white-space equivalente
// usando strings.Repeat y lipgloss truncation desactivada
```

---

### 10. Comunicación async — goroutines → tea.Cmd

Los eventos de instalación llegan por WebSocket. Convertirlos a tea.Msg:

```go
// Escuchar el WebSocket del bootstrap en una goroutine
func listenWS(wsConn *websocket.Conn) tea.Cmd {
    return func() tea.Msg {
        var event WSEvent
        err := wsConn.ReadJSON(&event)
        if err != nil {
            return wsErrMsg{err}
        }
        switch event.Type {
        case "step_start": return stepStartMsg{event.FichaID, event.StepID}
        case "step_ok":    return stepOkMsg{event.FichaID, event.StepID, event.Elapsed}
        case "step_err":   return stepErrMsg{event.FichaID, event.StepID, event.Msg}
        case "ficha_ok":   return fichaOkMsg{event.FichaID, event.Elapsed}
        case "install_ok": return installDoneMsg{}
        }
        return nil
    }
}

// Re-armar el listener después de cada mensaje:
case stepOkMsg:
    m.install.markDone(msg)
    return m, listenWS(m.wsConn) // volver a escuchar
```

---

### 11. Teclas globales vs teclas de pantalla

```go
// Teclas globales — siempre activas, en el Update() raíz
var globalKeys = struct {
    Quit key.Binding
}{
    Quit: key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("Ctrl+C", "cancelar")),
}

// Teclas de pantalla — solo activas cuando esa pantalla está visible
// Definirlas en el sub-modelo correspondiente como struct con key.Binding
type InstallingKeys struct {
    Tab       key.Binding
    Up        key.Binding
    Down      key.Binding
    LogFull   key.Binding // L
    ErrPanel  key.Binding // E
    Resume    key.Binding // R
    Timestamp key.Binding // T
    GotoEnd   key.Binding // G/End
}
```

---

### 12. Reglas de diseño que NO se negocian

Estas reglas fueron establecidas durante el diseño y **no se cambian sin aprobación explícita**:

1. **Fondo de inputs**: `#0f172a` — exactamente igual al fondo general. Usar `-webkit-box-shadow` equivalente en terminal con `lipgloss.Background`.
2. **Padding de inputs**: mínimo. El borde va pegado al texto (`Padding(0, 1)` máximo).
3. **Iconos siempre con color explícito** — nunca heredan del padre.
4. **Stepper**: `✓` verde completado · spinner amarillo activo · `·` gris pendiente. Sin bordes, sin fondos.
5. **Scrollbars**: Panel A de P5 solo vertical. Paneles B y C de P5, y logs P10: vertical + horizontal.
6. **Footer**: siempre `help.Model` con `key.Binding` — nunca strings hardcodeados.
7. **Colores por nivel de log**: info `#64748b` · ok `#22c55e` · warn `#f59e0b` · err `#ef4444` · bos/heal `#06b6d4`.
8. **Panel C de P5 — timestamp**: oculto por defecto. Toggle con tecla `T`. Badge en header del panel.
9. **Topbar shutdown**: fondo `#1a0808` texto `#fca5a5` (rojo). Topbar restart: `#1c1003` texto `#fde68a` (amarillo).
10. **WELCOME/GOODBYE**: sin ASCII art. Solo tipografía. `G O O D  B Y E` centrado encima de la marca.
11. **GOODBYE**: pantalla completamente estática. Sin animaciones. El OS oscurece la pantalla al apagar.
12. **Footer legal** (WELCOME/GOODBYE/P9): tres líneas fijas — copyright SKULL · estándares · firma Ed25519.

---
---

### 13. RESPONSIVE — EL AGENTE NO DECIDE EL TAMAÑO, SE ADAPTA A ÉL

> Esta regla existe porque el agente tiene tendencia a detectar el tamaño del terminal
> y tomar decisiones visuales propias: arrinconar contenido, reducir paneles, omitir
> elementos, o cambiar el layout porque "el viewport es muy amplio" o "muy angosto".
> Eso está **terminantemente prohibido**.

#### La regla es simple

```
El terminal tiene un tamaño. Tú no lo eliges. Te lo da tea.WindowSizeMsg.
Tu trabajo es ocupar ESE tamaño completo — ni más, ni menos.
```

#### El contenido se adapta al espacio — el espacio no se adapta al contenido

```go
// ✅ CORRECTO — el panel ocupa el ancho que le toca
m.vpA.Width = int(float64(m.width) * 0.36) - 2
// Si m.width es 80, vpA.Width = 27
// Si m.width es 220, vpA.Width = 77
// Si m.width es 40, vpA.Width = 13
// En TODOS los casos el panel ocupa su 36% — el contenido dentro se trunca si no cabe

// ❌ INCORRECTO — el agente decide que "es muy ancho" y lo recorta
if m.width > 160 {
    m.vpA.Width = 60 // ← PROHIBIDO. Nunca limites el ancho por criterio estético.
}

// ❌ INCORRECTO — el agente centra con margen porque "se ve mejor"
leftMargin := (m.width - 80) / 2 // ← PROHIBIDO. No hay máximo de ancho.
```

#### Los paneles siempre ocupan el 100% del ancho disponible

```
P5 — 3 paneles:  A=36% + B=30% + C=resto = 100% del width
P9 — dashboard:  centro=flex1 + lateral=220px fijo = 100% del width
P10 — logs:      1 panel = 100% del width
Formularios:     form=flex1 + help=210px fijo = 100% del width
```

Si el terminal es de 40 columnas (xs), el contenido se trunca o se apila — pero **nunca
se deja espacio vacío a los lados por decisión del agente**.

#### Los tres modos responsive son los ÚNICOS cambios de layout permitidos

```go
// Este es el ÚNICO lugar donde el agente puede cambiar la disposición visual
switch termMode(m.width) {
case modeXS: // < 60 cols — columna única sin bordes
    // los paneles se apilan verticalmente, uno debajo del otro
case modeSM: // 60–79 cols — columna única con caja
    // los paneles se apilan verticalmente dentro de una caja
case modeMD: // ≥ 80 cols — layout en columnas (diseño principal aprobado)
    // layout de múltiples columnas como se diseñó
}
// Fuera de estos tres casos, NO hay más adaptaciones de layout.
```

#### Lo que el agente NO puede hacer bajo ninguna circunstancia

```
❌ Detectar que el terminal "es grande" y agregar márgenes laterales
❌ Limitar el ancho máximo de un panel con un número hardcodeado
❌ Centrar el contenido dejando espacios en blanco a los lados
❌ Decidir que "el viewport es muy amplio" y reducirlo
❌ Cambiar proporciones de paneles según el tamaño detectado
❌ Omitir elementos del diseño porque "no caben bien"
❌ Agregar padding o margin extra "para que se vea mejor" en terminales grandes
```

#### Lo que el agente SÍ debe hacer

```
✅ Leer m.width y m.height de tea.WindowSizeMsg
✅ Calcular TODOS los tamaños como función de m.width y m.height
✅ Pasar esos valores a viewport.New(ancho, alto)
✅ Dejar que lipgloss trunque el texto si no cabe (Width().MaxWidth())
✅ En xs/sm apilar verticalmente — en md layout en columnas
✅ Recalcular en CADA WindowSizeMsg sin asumir nada del tamaño anterior
```

---


## Stack técnico

```
github.com/charmbracelet/bubbletea   — runtime MVC, loop de eventos, Cmd async
github.com/charmbracelet/lipgloss    — estilos CSS-like: bordes, colores, padding, width
github.com/charmbracelet/bubbles/textinput   — campos de texto con cursor y máscara
github.com/charmbracelet/bubbles/viewport    — panel con scroll (pantalla 5)
github.com/charmbracelet/bubbles/progress    — barra de progreso animada (pantalla 5)
github.com/charmbracelet/bubbles/spinner     — spinner ⠿ animado (pantalla 5)
github.com/charmbracelet/bubbles/help        — footer de atajos de teclado automático
github.com/charmbracelet/bubbles/key         — definición de key.Binding
```

---

## Paleta de colores (global)

```go
const (
    cGreen  = "#22c55e"  // verde principal, éxito, topbar
    cCyan   = "#06b6d4"  // foco activo, cursor, borde activo
    cYellow = "#f59e0b"  // advertencias, en progreso, default
    cRed    = "#ef4444"  // errores
    cDim    = "#6b7280"  // texto secundario
    cBlack  = "#0f172a"  // fondo general
    cWhite  = "#f1f5f9"  // texto principal
    cSlate  = "#334155"  // bordes inactivos
    cMuted  = "#475569"  // hints, descripciones
    cBg2    = "#0c1525"  // fondo de inputs y footer
    cBg3    = "#1e293b"  // fondo de titlebar
)
```

---

## Estilos Lipgloss (globales)

```go
var (
    // Caja inactiva — borde redondeado gris
    sBox = lipgloss.NewStyle().
        Border(lipgloss.RoundedBorder()).
        BorderForeground(lipgloss.Color(cSlate)).
        Padding(0, 1)

    // Caja activa — borde redondeado cyan
    sBoxActive = lipgloss.NewStyle().
        Border(lipgloss.RoundedBorder()).
        BorderForeground(lipgloss.Color(cCyan)).
        Padding(0, 1)

    // Separador de columna derecha (solo borde izquierdo)
    sPanelDiv = lipgloss.NewStyle().
        BorderLeft(true).
        BorderStyle(lipgloss.NormalBorder()).
        BorderForeground(lipgloss.Color(cSlate)).
        PaddingLeft(2)

    // Panel de ayuda — borde izquierdo, texto gris
    sHelpBox = lipgloss.NewStyle().
        BorderLeft(true).
        BorderStyle(lipgloss.NormalBorder()).
        BorderForeground(lipgloss.Color("#1e3a5f")).
        PaddingLeft(2).
        Foreground(lipgloss.Color(cMuted))

    // Panel de error — borde grueso rojo
    sErrBox = lipgloss.NewStyle().
        Border(lipgloss.ThickBorder()).
        BorderForeground(lipgloss.Color(cRed)).
        Padding(0, 1)

    // TopBar
    sTopBar = lipgloss.NewStyle().
        Background(lipgloss.Color("#134e23")).
        Foreground(lipgloss.Color(cGreen)).
        Bold(true).
        Width(termWidth).
        Padding(0, 1)

    // Título de pantalla
    sTitle = lipgloss.NewStyle().
        Foreground(lipgloss.Color("#94a3b8")).
        Width(termWidth).
        Align(lipgloss.Center)

    // Footer
    sFooter = lipgloss.NewStyle().
        Background(lipgloss.Color(cBg2)).
        Foreground(lipgloss.Color(cMuted)).
        Width(termWidth).
        Padding(0, 1)
)
```

---

## Estructura global de pantallas

```go
func (m Model) View() string {
    return lipgloss.JoinVertical(lipgloss.Left,
        sTopBar.Render("SBOS — Sistema Operativo Empresarial Soberano"),
        sTitle.Render(m.screenTitle()),
        strings.Repeat("─", termWidth),
        m.renderBody(),   // dinámico según m.screen
        strings.Repeat("─", termWidth),
        m.renderFooter(), // help.Model o string fijo
    )
}
```

---

## Modos de terminal

```go
const (
    modeXS = "xs" // < 60 cols — columna única sin bordes
    modeSM = "sm" // 60–79 cols — columna única con caja
    modeMD = "md" // ≥ 80 cols — layout en columnas (diseño principal)
)

func termMode(w int) string {
    switch {
    case w < 60:  return modeXS
    case w < 80:  return modeSM
    default:      return modeMD
    }
}
```

---

## PANTALLA 1 — Bienvenida ✅ DISEÑO FINAL APROBADO

### Contexto de uso
- **Cuándo aparece**: primera pantalla del wizard, solo si `bosctl` detecta que NO hay instalación previa (`/etc/sbos/tenant.conf` no existe)
- **Cuándo termina**: usuario selecciona "Comenzar instalación" → P2 · "Salir" → exit
- **Teclas**: ↑↓/Tab navegar · Enter seleccionar · Esc salir

### Decisiones de diseño
- Contenido del cuerpo **centrado horizontalmente** (sysbox + badges + menú)
- Caja de sistema: borde redondeado gris, label/valor en dos columnas alineadas
- Badges para el resumen de instalación (fichas / niveles DAG / tiempo estimado)
- Menú de 2 opciones: `▶` cyan en opción activa, fondo sutil `#0f2433`
- Descripción debajo de cada opción en color `cMuted`

### Variables de entorno
Ninguna — datos leídos de `m.sys` (detección automática del sistema).

### Código Go

```go
// --- Model ---
type WelcomeModel struct {
    sys   SysInfo  // OS, Kernel, RAM, Disk, CPU
    focus int      // 0=Comenzar, 1=Salir
    keys  WelcomeKeys
    help  help.Model
}

type SysInfo struct {
    OS     string
    Kernel string
    RAM    string
    Disk   string
    CPU    int
}

type WelcomeKeys struct {
    Up     key.Binding
    Down   key.Binding
    Tab    key.Binding
    Enter  key.Binding
    Quit   key.Binding
}

// --- Update ---
func (m WelcomeModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch {
        case key.Matches(msg, m.keys.Up):
            m.focus = max(0, m.focus-1)
        case key.Matches(msg, m.keys.Down), key.Matches(msg, m.keys.Tab):
            m.focus = min(1, m.focus+1)
        case key.Matches(msg, m.keys.Enter):
            if m.focus == 0 { return m, goToTenant }
            return m, tea.Quit
        }
    }
    return m, nil
}

// --- View ---
func (m WelcomeModel) View() string {
    sysBox := sBox.Render(lipgloss.JoinVertical(lipgloss.Left,
        sysRow("Sistema Operativo", m.sys.OS),
        sysRow("Kernel",            m.sys.Kernel),
        sysRow("RAM disponible",    m.sys.RAM),
        sysRow("Disco disponible",  m.sys.Disk),
        sysRow("Núcleos CPU",       fmt.Sprintf("%d", m.sys.CPU)),
    ))

    badges := lipgloss.JoinHorizontal(lipgloss.Top,
        badge("22 fichas",         cGreen,  "#0a1f12"),
        badge("7 niveles del DAG", "#3b82f6","#0c1a2e"),
        badge("~48 minutos",       cYellow, "#1c0f03"),
    )

    menu := renderMenu([]menuItem{
        {label: "Comenzar instalación", desc: "Inicia el asistente paso a paso"},
        {label: "Salir",                desc: "Cerrar el instalador"},
    }, m.focus)

    body := lipgloss.NewStyle().Align(lipgloss.Center).Width(termWidth).
        Render(lipgloss.JoinVertical(lipgloss.Center, sysBox, badges, menu))

    return renderScreen("Bienvenida", body, m.help.View(m.keys))
}
```

---

## PANTALLA 2 — Datos de la Empresa (Tenant) ✅ DISEÑO FINAL APROBADO

### Contexto de uso
- **Cuándo aparece**: después de P1, usuario eligió "Comenzar instalación"
- **Cuándo termina**: Enter con datos válidos → P3 · Esc → P1
- **Pre-carga**: lee variables de entorno al Init(). Dominio default: `sksistemas.com`
- **Validación**: NIT solo números · País en lista BO/AR/MX/CL/PE/CO · Dominio formato válido

### Decisiones de diseño ✅ APROBADO
- Layout: formulario izquierda (flex: 1) + panel de ayuda derecha (210px, borde izquierdo `#1e3a5f`)
- Campo label: 12px, color `#64748b` inactivo / `#06b6d4` cyan activo
- Campo input: borde `1px solid #334155` inactivo / `#06b6d4` activo, **padding: 0** en el contenedor
- Fondo del input: `#0f172a` — exactamente el mismo que el fondo general, sin ningún contraste
- Texto del input: `#e2e8f0`, caret `#06b6d4`
- Fix browser: `-webkit-box-shadow: 0 0 0 1000px #0f172a inset` para anular fondo blanco nativo del browser
- Padding interno del `<input>`: `3px 6px` — mínimo, pegado al borde
- Hint debajo del campo: 11px, color `#475569`
- Panel de ayuda: título 12px bold `#3b82f6` uppercase, cuerpo 12px `#475569`, ejemplos `#22c55e`
- Footer: kbd con borde `#475569`, fondo `#1e293b`, texto `#e2e8f0`

### Pre-carga desde `.env`
Los 4 campos se pre-cargan desde variables de entorno al iniciar.
El campo dominio tiene valor por defecto `sksistemas.com` si `SBOS_TENANT_DOMAIN` no está definido.

```
SBOS_TENANT_NAME    → m.tenantInputs[0]  (Razón social)
SBOS_TENANT_NIT     → m.tenantInputs[1]  (NIT / CUIT / RFC)
SBOS_TENANT_COUNTRY → m.tenantInputs[2]  (País)
SBOS_TENANT_DOMAIN  → m.tenantInputs[3]  (Dominio — default: sksistemas.com)
```

### Código Go

```go
const defaultDomain = "sksistemas.com"

// --- Init de inputs desde .env ---
func initTenantInputs() []textinput.Model {
    fields := []struct{ placeholder, envKey, def string }{
        {"Nombre de la empresa",  "SBOS_TENANT_NAME",    ""},
        {"Identificador fiscal",  "SBOS_TENANT_NIT",     ""},
        {"BO / AR / MX",          "SBOS_TENANT_COUNTRY", "BO"},
        {"sksistemas.com",        "SBOS_TENANT_DOMAIN",  defaultDomain},
    }

    inputs := make([]textinput.Model, len(fields))
    for i, f := range fields {
        t := textinput.New()
        t.Placeholder = f.placeholder
        val := os.Getenv(f.envKey)
        if val == "" { val = f.def }
        t.SetValue(val)
        if i == 0 { t.Focus() }
        inputs[i] = t
    }
    return inputs
}

// --- Model ---
type TenantModel struct {
    inputs []textinput.Model
    focus  int   // 0–3
    errMsg string
    keys   TenantKeys
    help   help.Model
}

// --- Update ---
func (m TenantModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch {
        case key.Matches(msg, m.keys.Tab), key.Matches(msg, m.keys.Down):
            m.inputs[m.focus].Blur()
            m.focus = (m.focus + 1) % len(m.inputs)
            return m, m.inputs[m.focus].Focus()
        case key.Matches(msg, m.keys.Up):
            m.inputs[m.focus].Blur()
            m.focus = (m.focus - 1 + len(m.inputs)) % len(m.inputs)
            return m, m.inputs[m.focus].Focus()
        case key.Matches(msg, m.keys.Enter):
            if err := m.validate(); err != nil {
                m.errMsg = err.Error()
                return m, nil
            }
            return m, goToAdmin
        case key.Matches(msg, m.keys.Back):
            return m, goToWelcome
        }
    }
    // delegar evento al input activo
    var cmd tea.Cmd
    m.inputs[m.focus], cmd = m.inputs[m.focus].Update(msg)
    return m, cmd
}

// --- Estilos específicos pantalla 2 ---
var (
    // Input inactivo: borde slate, fondo igual al general, padding 0
    sInputInactive = lipgloss.NewStyle().
        Border(lipgloss.NormalBorder()).
        BorderForeground(lipgloss.Color(cSlate)).
        Background(lipgloss.Color(cBlack)).
        Padding(0)

    // Input activo: borde cyan, mismo fondo
    sInputActive = lipgloss.NewStyle().
        Border(lipgloss.NormalBorder()).
        BorderForeground(lipgloss.Color(cCyan)).
        Background(lipgloss.Color(cBlack)).
        Padding(0)
)

// textinput configurado para pantalla 2:
// t.PromptStyle    = lipgloss.NewStyle()           // sin prompt visible
// t.TextStyle      = lipgloss.NewStyle().Foreground(lipgloss.Color(cWhite))
// t.CursorStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color(cCyan))
// t.PlaceholderStyle = lipgloss.NewStyle().Foreground(lipgloss.Color(cMuted))
// NO usar t.Focused() para cambiar fondo — el fondo lo controla sInputActive/Inactive

// --- View ---
func (m TenantModel) View() string {
    hints := []string{"", "", "BO · AR · MX · CL · PE · CO", "Vacío = valor por defecto"}

    formRows := make([]string, len(m.inputs))
    for i, inp := range m.inputs {
        labelColor := lipgloss.Color(cDim)
        inputStyle := sInputInactive
        if i == m.focus {
            labelColor = lipgloss.Color(cCyan)
            inputStyle = sInputActive
        }
        label := lipgloss.NewStyle().Foreground(labelColor).Render(fieldNames[i])
        field := inputStyle.Width(42).Render(inp.View())
        hint  := lipgloss.NewStyle().Foreground(lipgloss.Color(cMuted)).
            Italic(true).Render(hints[i])
        formRows[i] = lipgloss.JoinVertical(lipgloss.Left, label, field, hint)
    }

    form := sBox.Width(46).Render(
        lipgloss.JoinVertical(lipgloss.Left, formRows...),
    )

    helpPanel := sHelpBox.Width(26).Render(lipgloss.JoinVertical(lipgloss.Left,
        lipgloss.NewStyle().Foreground(lipgloss.Color("#3b82f6")).Bold(true).
            Render(strings.ToUpper(fieldNames[m.focus])),
        lipgloss.NewStyle().Foreground(lipgloss.Color(cMuted)).
            Render(helpTexts[m.focus]),
        lipgloss.NewStyle().Foreground(lipgloss.Color(cGreen)).
            Render(helpExamples[m.focus]),
    ))

    body := lipgloss.JoinHorizontal(lipgloss.Top, form, helpPanel)
    return renderScreen("Datos de la Empresa", body, m.help.View(m.keys))
}
```

---

## PANTALLA 3 — Cuenta de Administrador ✅ DISEÑO FINAL APROBADO

### Contexto de uso
- **Cuándo aparece**: después de P2 con datos válidos
- **Cuándo termina**: Enter con datos válidos → P4 · Esc → P2
- **Validación**: email formato válido · contraseña mín 12 chars · confirmación debe coincidir
- **Tecla M**: toggle MFA desde cualquier campo (no requiere foco en el campo MFA)

### Decisiones de diseño ✅ APROBADO
- Mismo diseño exacto que pantalla 2: form panel izquierda + help panel derecha
- Mismos estilos de campo: label 12px, input borde `#334155`/`#06b6d4`, fondo `#0f172a`, padding `3px 6px`
- Campos contraseña y confirmación con `type="password"` (`EchoPassword` en textinput.Model)
- Campo MFA renderizado como fila toggle (no es un textinput) — borde igual al resto
- Toggle MFA: `✓` verde activo / `○` gris inactivo, tecla `M` desde cualquier campo sin foco de escritura
- Hint debajo del MFA: "Recomendado — autenticación push vía sbos-notifier"
- Footer agrega `[M] Toggle MFA` respecto a pantalla 2

### Pre-carga desde `.env`
```
SBOS_ADMIN_EMAIL → m.adminInputs[0]  (Email — default: admin@sksistemas.com)
SBOS_ADMIN_NAME  → m.adminInputs[1]  (Nombre completo)
```
Contraseña y confirmación nunca se pre-cargan desde `.env`.

### Código Go

```go
// --- Model ---
type AdminModel struct {
    inputs     []textinput.Model // 0=email, 1=nombre, 2=pass, 3=confirm
    focus      int               // 0–4 (4=MFA row)
    mfaEnabled bool
    errMsg     string
    keys       AdminKeys
    help       help.Model
}

// --- Init ---
func initAdminInputs() []textinput.Model {
    configs := []struct{ placeholder, envKey, def string; echo textinput.EchoMode }{
        {"admin@sksistemas.com", "SBOS_ADMIN_EMAIL", "admin@sksistemas.com", textinput.EchoNormal},
        {"Juan Pérez",           "SBOS_ADMIN_NAME",  "",                     textinput.EchoNormal},
        {"••••••••",             "",                 "",                     textinput.EchoPassword},
        {"••••••••",             "",                 "",                     textinput.EchoPassword},
    }
    inputs := make([]textinput.Model, len(configs))
    for i, c := range configs {
        t := textinput.New()
        t.Placeholder = c.placeholder
        t.EchoMode = c.echo
        if c.envKey != "" {
            val := os.Getenv(c.envKey)
            if val == "" { val = c.def }
            t.SetValue(val)
        }
        if i == 0 { t.Focus() }
        inputs[i] = t
    }
    return inputs
}

// --- Update ---
func (m AdminModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch {
        case key.Matches(msg, m.keys.Tab), key.Matches(msg, m.keys.Down):
            if m.focus < 3 { m.inputs[m.focus].Blur() }
            m.focus = (m.focus + 1) % 5
            if m.focus < 4 { return m, m.inputs[m.focus].Focus() }
            return m, nil
        case key.Matches(msg, m.keys.Up):
            if m.focus < 4 { m.inputs[m.focus].Blur() }
            m.focus = (m.focus - 1 + 5) % 5
            if m.focus < 4 { return m, m.inputs[m.focus].Focus() }
            return m, nil
        case key.Matches(msg, m.keys.ToggleMFA):
            m.mfaEnabled = !m.mfaEnabled
        case key.Matches(msg, m.keys.Enter):
            if err := m.validate(); err != nil {
                m.errMsg = err.Error()
                return m, nil
            }
            return m, goToConfirm
        case key.Matches(msg, m.keys.Back):
            return m, goToTenant
        }
    }
    if m.focus < 4 {
        var cmd tea.Cmd
        m.inputs[m.focus], cmd = m.inputs[m.focus].Update(msg)
        return m, cmd
    }
    return m, nil
}

// --- View (fila MFA) ---
func renderMFARow(enabled bool, focused bool) string {
    check := lipgloss.NewStyle().Foreground(lipgloss.Color(cGreen)).Render("✓")
    label := "Sí — Push MFA (sbos-notifier)"
    if !enabled {
        check = lipgloss.NewStyle().Foreground(lipgloss.Color(cSlate)).Render("○")
        label = "No — sin segundo factor"
    }
    key := lipgloss.NewStyle().
        Foreground(lipgloss.Color(cDim)).
        Background(lipgloss.Color(cBg3)).
        Border(lipgloss.NormalBorder()).
        BorderForeground(lipgloss.Color(cSlate)).
        Padding(0, 1).Render("M")

    row := lipgloss.JoinHorizontal(lipgloss.Center, check+" ", label, " ", key)
    style := sInputInactive
    if focused { style = sInputActive }
    return style.Width(42).Render(row)
}
```

---

## Pendiente

- [x] Pantalla 2 — Datos de la Empresa ✅
- [x] Pantalla 3 — Cuenta de Administrador ✅
- [x] Pantalla 4 — Confirmar instalación ✅
- [x] Pantalla 5 — Instalación en progreso ✅
- [x] Pantalla 5B — Log completo ✅
- [x] Pantalla 5C — Panel de error ✅
- [x] Pantalla 6 — Instalación completada ✅
- [x] WELCOME BOS ✅
- [x] GOODBYE BOS ✅
- [x] P7 — Reinicio post-instalación ✅
- [x] P8 — Arranque bos ✅
- [x] P9 — Dashboard bos ✅
- [x] P10 — Logs puros ✅
- [x] P11 — Apagado / Reinicio ✅
- [ ] Layouts XS y SM para pantallas 5/5B/5C

---

## PANTALLA 4 — Confirmar instalación ✅ DISEÑO FINAL APROBADO

### Contexto de uso
- **Cuándo aparece**: después de P3 con datos válidos
- **Cuándo termina**: "Iniciar instalación" → P5 normal · "Modo automático" → P5 auto · "Volver" → P3 · Esc → P3
- **Nota**: en modo automático P5 no hace pausas ni pide confirmaciones adicionales

### Decisiones de diseño ✅ APROBADO
- Layout dos columnas: izquierda (flex:1) con resumen + menú, derecha (240px) con fases del DAG
- Caja de resumen: borde `#334155`, label 80px min-width `#64748b`, valor `#e2e8f0`
- MFA confirmado en verde `#22c55e` con `✓`
- Menú de 3 opciones igual a pantalla 1: `▶` cyan + fondo `#0f2433` en activo
- Panel de fases: borde `#334155`, título uppercase `#64748b`, fases con icono `○` gris, fichas con `•` indentadas
- Sin panel de ayuda en esta pantalla

### Opciones del menú
```
0 = Iniciar instalación    → goToInstalling(modeNormal)
1 = Modo automático        → goToInstalling(modeAuto)
2 = Volver a corregir datos → goToAdmin
```

### Código Go

```go
// --- Model ---
type ConfirmModel struct {
    focus  int  // 0=Instalar, 1=Automático, 2=Volver
    tenant TenantData
    admin  AdminData
    phases []Phase
    keys   ConfirmKeys
    help   help.Model
}

// --- Update ---
func (m ConfirmModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch {
        case key.Matches(msg, m.keys.Up):
            m.focus = (m.focus - 1 + 3) % 3
        case key.Matches(msg, m.keys.Down), key.Matches(msg, m.keys.Tab):
            m.focus = (m.focus + 1) % 3
        case key.Matches(msg, m.keys.Enter):
            switch m.focus {
            case 0: return m, goToInstalling(false)
            case 1: return m, goToInstalling(true)
            case 2: return m, goToAdmin
            }
        case key.Matches(msg, m.keys.Back):
            return m, goToAdmin
        }
    }
    return m, nil
}

// --- View ---
func (m ConfirmModel) View() string {
    mfaStr := lipgloss.NewStyle().Foreground(lipgloss.Color(cGreen)).Render("✓ Push MFA")
    if !m.admin.MFA { mfaStr = lipgloss.NewStyle().Foreground(lipgloss.Color(cDim)).Render("✗ Desactivado") }

    summary := sBox.Width(38).Render(lipgloss.JoinVertical(lipgloss.Left,
        summaryRow("Empresa", m.tenant.Name),
        summaryRow("NIT",     m.tenant.NIT),
        summaryRow("País",    m.tenant.Country),
        summaryRow("Dominio", m.tenant.Domain),
        summaryRow("Admin",   m.admin.Email),
        "MFA     "+mfaStr,
    ))

    menu := renderMenu([]menuItem{
        {label: "Iniciar instalación",    desc: "Comienza el bootstrap con los datos confirmados"},
        {label: "Modo automático",        desc: "Instala sin pausas ni confirmaciones adicionales"},
        {label: "Volver a corregir datos",desc: "Regresar al formulario anterior"},
    }, m.focus)

    leftCol := lipgloss.JoinVertical(lipgloss.Left, summary, menu)

    // panel fases
    phaseLines := []string{
        lipgloss.NewStyle().Foreground(lipgloss.Color(cDim)).
            Italic(true).Render("Fases a instalar"),
    }
    for _, ph := range m.phases {
        phaseLines = append(phaseLines,
            lipgloss.NewStyle().Foreground(lipgloss.Color("#94a3b8")).
                Render("○ "+ph.Label),
        )
        for _, f := range ph.Fichas {
            phaseLines = append(phaseLines,
                lipgloss.NewStyle().Foreground(lipgloss.Color(cMuted)).
                    PaddingLeft(2).Render("• "+f),
            )
        }
    }
    phases := sBox.Width(28).Render(
        lipgloss.JoinVertical(lipgloss.Left, phaseLines...),
    )

    body := lipgloss.JoinHorizontal(lipgloss.Top, leftCol, phases)
    return renderScreen("Confirmar instalación", body, m.help.View(m.keys))
}
```

---

## PANTALLA 5 — Instalación en progreso ✅ DISEÑO FINAL APROBADO

> Esta pantalla fue diseñada, revisada y aprobada visualmente.
> Implementa EXACTAMENTE lo que se especifica aquí. No simplifiques los paneles,
> no omitas los scrollbars, no cambies las proporciones.

### Contexto de uso
- **Cuándo aparece**: después de que el usuario confirma en P4 (Iniciar instalación o Modo automático)
- **Cuándo termina**: cuando todos los eventos `install_ok` o `install_err` llegan por WebSocket
- **Transición exitosa**: → P6 Instalación completada
- **Transición con error bloqueante**: → P5C Panel de error (tecla E o automático si es bloqueante)
- **Tecla L**: → P5B Log completo (sin salir de la instalación, que sigue corriendo)

### Estructura de layout — 3 ZONAS

```
┌──────────────────────────────────────────────────────────────┐
│ TOP (fijo)                                                    │
│  topbar + stepper + "Instalando SBOS..." + divider           │
├──────────────────────────────────────────────────────────────┤
│ BODY (dinámico — bodyHeight = height - topH - botH)          │
│                                                              │
│  ┌─ progreso ──────────────────────────────────────────────┐ │
│  │ ████████░░  18%  ·  4/22 fichas  ·  8:23 transcurridos │ │  ← 1 línea
│  │ ✓ 4 completadas  ⠿ 1 en curso  ○ 17 pend  ✗ 0  ⚠ 2    │ │  ← 1 línea
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌─ Panel A ──┐ ┌─ Panel B ──┐ ┌─ Panel C ──────────────┐  │
│  │            │ │            │ │                          │  │
│  │  Fases y   │ │ Componente │ │     Log en vivo          │  │
│  │  Fichas    │ │  activo    │ │                          │  │
│  │            │ │            │ │                          │  │
│  │ ALTURA:    │ │ ALTURA:    │ │ ALTURA:                  │  │
│  │ panelH     │ │ panelH     │ │ panelH                   │  │
│  │            │ │            │ │                          │  │  ← los 3 IGUAL
│  └────────────┘ └────────────┘ └──────────────────────────┘  │
│                                                              │
│  [Tab] cambiar panel  [↑↓] scroll  [T] timestamp  [G] final │  ← nav-hint 1 línea
├──────────────────────────────────────────────────────────────┤
│ BOTTOM (fijo)                                                │
│  [L] Log  [E] Error  [R] Reanudar  [Ctrl+C] Cancelar        │
└──────────────────────────────────────────────────────────────┘
```

### Cálculo de alturas — OBLIGATORIO

```go
func (m *InstallingModel) recalcLayout(totalH, totalW int) {
    // Zona TOP de la pantalla global
    topH := 4 // topbar(1) + stepper(1) + title(1) + divider(1)

    // Zona BOTTOM de la pantalla global
    botH := 1 // footer

    // Body total disponible
    bodyH := totalH - topH - botH

    // Dentro del body:
    progressH := 2 // barra+pct (1) + contadores (1)
    navHintH  := 1 // "[Tab] cambiar panel..."
    panelH    := bodyH - progressH - navHintH
    // panelH es la altura IGUAL para los 3 paneles — sin excepción

    // Anchos proporcionales — nunca hardcodeados
    // -2 en cada panel por los bordes del box
    aW := int(float64(totalW)*0.36) - 2
    bW := int(float64(totalW)*0.30) - 2
    cW := totalW - aW - bW - 8 // 8 = gaps + bordes entre paneles

    m.vpA.Width  = aW;  m.vpA.Height = panelH
    m.vpB.Width  = bW;  m.vpB.Height = panelH
    m.vpC.Width  = cW;  m.vpC.Height = panelH
}

// Llamar SIEMPRE en:
// 1. Init() después de crear los viewports
// 2. tea.WindowSizeMsg cada vez que cambia el tamaño de la terminal
```

### Panel A — Fases y Fichas

**Ancho**: 36% del terminal · **Scrollbar**: SOLO VERTICAL

```go
m.vpA = viewport.New(aW, panelH)
// overflow-x: hidden — el contenido nunca excede el ancho
// overflow-y: auto   — scrollbar vertical cuando fases > panelH líneas
```

**Contenido**: árbol N0–N6, cada fase con sus fichas indentadas 16px (2 espacios en terminal)

**Estados — iconos con color EXPLÍCITO siempre:**
```
Fase completada:  icOk()  + texto #94a3b8
Fase en curso:    icRun() + texto #e2e8f0
Fase pendiente:   icPend()+ texto #475569
Fase con error:   icErr() + texto #ef4444
Ficha ejecutando: m.spinner.View() (amarillo #f59e0b) + texto #e2e8f0
Ficha con aviso:  icWarn()+ texto #f59e0b
Tiempo ficha:     #475569 10px alineado a la derecha con lipgloss.Width
```

### Panel B — Componente activo

**Ancho**: 30% del terminal · **Scrollbar**: VERTICAL Y HORIZONTAL

```go
m.vpB = viewport.New(bW, panelH)
// overflow-x: auto — algunas líneas de detalle pueden ser largas
// overflow-y: auto — scroll cuando pasos > panelH
```

**Contenido**:
- Header: `📦 {ficha} {version}` — color `#e2e8f0`
- Subheader: `⠿ {paso}/{total} pasos · {elapsed}s` — color `#475569`
- Lista de pasos con los mismos iconos globales
- Tiempo de cada paso alineado a la derecha
- Sección "Advertencias" al pie si hay warnings no bloqueantes

### Panel C — Log en vivo

**Ancho**: resto del terminal (flex 1) · **Scrollbar**: VERTICAL Y HORIZONTAL

```go
m.vpC = viewport.New(cW, panelH)
// overflow-x: auto — líneas de log pueden ser largas
// overflow-y: auto — scroll cuando líneas > panelH
// Auto-scroll: m.vpAutoScroll = true por defecto
//   → al recibir nueva línea: if m.vpAutoScroll { m.vpC.GotoBottom() }
//   → al hacer scroll manual hacia arriba: m.vpAutoScroll = false
//   → badge en header: "T hh:mm:ss" — toggle timestamp con tecla T
```

**Header del panel C** tiene dos elementos:
```
"Log en vivo"           [T hh:mm:ss]
                        ↑ badge: gris inactivo / cyan activo
```

**Timestamp**: oculto por defecto (`m.showTimestamp = false`).
Tecla `T` lo activa/desactiva desde cualquier panel.

**Colores de línea**:
```
info   → #64748b  — inicio de ficha (📦 nombre)
ok     → #22c55e  — completados (✅)
warn   → #f59e0b  — advertencias no bloqueantes (⚠)
err    → #ef4444  — errores bloqueantes (✗)
active → #94a3b8  — pasos intermedios (↳ nombre...)
```
- Implementar con `spinner.Model` de Bubbles + `tea.Tick` cada 100ms

#### Nav hint (entre paneles y footer)
```
[Tab] cambiar panel  [↑↓] scroll  [End/G] ir al final
```
Texto 10px `#334155`

#### Footer
```
[L] Log completo  [E] Panel de error  [R] Reanudar  [Ctrl+C] Cancelar
```

### Código Go (estructura)

```go
type InstallingModel struct {
    phases      []Phase
    fichas      map[string]*FichaState
    logs        []LogEntry
    fichasOK    int
    fichasTotal int
    progBar     progress.Model
    spinner     spinner.Model
    vpA         viewport.Model  // solo scroll vertical
    vpB         viewport.Model  // scroll vertical + horizontal
    vpC         viewport.Model  // scroll vertical + horizontal, auto-scroll
    vpAutoScroll bool
    installingFocus int         // 0=A, 1=B, 2=C
    elapsed     time.Duration
    tickCmd     tea.Cmd
}

// Iconos y colores por estado
func stateIcon(s FichaStatus) string {
    switch s {
    case StatusDone:    return lipgloss.NewStyle().Foreground(lipgloss.Color(cGreen)).Render("✓")
    case StatusRunning: return lipgloss.NewStyle().Foreground(lipgloss.Color(cCyan)).Render("▶")
    case StatusSpinner: return m.spinner.View() // amarillo #f59e0b
    case StatusPending: return lipgloss.NewStyle().Foreground(lipgloss.Color(cSlate)).Render("○")
    case StatusError:   return lipgloss.NewStyle().Foreground(lipgloss.Color(cRed)).Render("✗")
    }
    return " "
}

// Tick para spinner y elapsed
func tickCmd() tea.Cmd {
    return tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg {
        return tickMsg(t)
    })
}
```

---

## STEPPER GLOBAL (todas las pantallas 1–5)

### Decisiones de diseño ✅ APROBADO
- Una línea centrada bajo la topbar, sobre el título de pantalla
- Sin bordes, sin fondos, sin padding extra — solo iconos + texto en línea
- Separador entre pasos: ` — ` en color `#1e293b` (casi invisible)
- **Iconos y colores por estado:**
  - `✓` verde `#22c55e` + texto `#475569` → paso completado
  - `⠿` spinner amarillo `#f59e0b` animado (mismos frames del installer) + texto cyan `#06b6d4` → paso activo
  - `·` gris `#334155` + texto `#334155` → paso no alcanzado / pendiente
- El spinner del stepper comparte el mismo intervalo de animación (120ms) que los spinners de pantalla 5

### Código Go

```go
func (m Model) renderStepper() string {
    steps := []string{"Bienvenida","Empresa","Admin","Confirmar","Instalando"}
    parts := make([]string, len(steps))
    for i, label := range steps {
        var icon, iconColor, textColor string
        switch {
        case m.screen > Screen(i):  // completado
            icon      = "✓"
            iconColor = cGreen
            textColor = cDim
        case m.screen == Screen(i): // activo
            icon      = m.spinner.View() // frames ⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏ en #f59e0b
            iconColor = cYellow
            textColor = cCyan
        default:                    // pendiente
            icon      = "·"
            iconColor = cSlate
            textColor = cSlate
        }
        ic := lipgloss.NewStyle().Foreground(lipgloss.Color(iconColor)).Render(icon)
        tx := lipgloss.NewStyle().Foreground(lipgloss.Color(textColor)).Render(" "+label)
        parts[i] = ic + tx
    }
    sep := lipgloss.NewStyle().Foreground(lipgloss.Color(cBg3)).Render(" — ")
    return lipgloss.NewStyle().Width(termWidth).Align(lipgloss.Center).
        Render(strings.Join(parts, sep))
}
```

---

## PANTALLA 5 — Log en vivo (Panel C) — Toggle timestamp

### Decisión ✅ APROBADO
- La columna timestamp `[HH:MM:SS]` ocupa espacio valioso en el panel C
- Se agrega un toggle con tecla `T` para mostrar/ocultar el timestamp
- **Con timestamp visible:** `[14:45:16] ↳ wait_ready...`
- **Sin timestamp:** `↳ wait_ready...` — más espacio para el mensaje
- Indicador del estado del toggle en el header del panel C:
  - `Log en vivo` cuando timestamp oculto (default)
  - `Log en vivo [T]` o un indicador sutil cuando visible
- Tecla `T` funciona desde cualquier posición, no requiere foco en panel C
- Estado guardado en `m.showTimestamp bool`

### Código Go

```go
// en el footer o nav-hint:
// [T] Timestamp

// en renderPanelC:
func (m InstallingModel) renderLogLine(entry LogEntry) string {
    msg := entry.Msg
    if m.showTimestamp {
        ts := lipgloss.NewStyle().Foreground(lipgloss.Color(cSlate)).
            Render("["+entry.Ts+"] ")
        msg = ts + msg
    }
    color := logColor(entry.Level) // info=#64748b ok=#22c55e warn=#f59e0b active=#94a3b8
    return lipgloss.NewStyle().Foreground(lipgloss.Color(color)).Render(msg)
}

// en Update:
case key.Matches(msg, m.keys.ToggleTimestamp):
    m.showTimestamp = !m.showTimestamp
    m.vpC.SetContent(m.renderLogContent())
```

---

## PANTALLA 5 — Contadores y colores de iconos (actualización)

### Decisiones ✅ APROBADO

#### Contadores — segunda línea bajo la barra de progreso
```
✓ 4 completadas   ⠿ 1 en curso   ○ 17 pendientes   ✗ 1 error   ⚠ 2 advertencias
```
- Línea 1: `{pct}%  ·  {fichasOK}/{fichasTotal} fichas  ·  {elapsed}`
- Línea 2: contadores expandidos con icono + texto

#### Iconos — colores SIEMPRE explícitos (nunca heredados del padre)
Regla crítica: cada icono lleva su propio color sin importar el contexto.

```go
// Estilos de icono globales — usar SIEMPRE estos, nunca heredar color del padre
var (
    icOk   = lipgloss.NewStyle().Foreground(lipgloss.Color(cGreen)).Render("✓")
    icRun  = lipgloss.NewStyle().Foreground(lipgloss.Color(cCyan)).Render("▶")
    icSpin = m.spinner.View()  // amarillo #f59e0b
    icPend = lipgloss.NewStyle().Foreground(lipgloss.Color(cSlate)).Render("○")
    icErr  = lipgloss.NewStyle().Foreground(lipgloss.Color(cRed)).Render("✗")
    icWarn = lipgloss.NewStyle().Foreground(lipgloss.Color(cYellow)).Render("⚠")
)
```

#### Colores de texto por estado (separado del icono)
```
done → texto #64748b (gris apagado)
run  → texto #e2e8f0 (blanco)
pend → texto #334155 (gris oscuro)
err  → texto #ef4444 (rojo)
warn → texto #f59e0b (amarillo)
```

#### Advertencias no bloqueantes
- En panel A: ficha con `⚠` amarillo — instalada con advertencia
- En panel B: sección separada al pie "Advertencias" con líneas `⚠` amarillo
- En panel C: líneas `.warn` con texto `#f59e0b` + mensaje "— no bloqueante"
- En contadores: `⚠ N advertencias` siempre visible aunque sea 0

#### Toggle timestamp panel C
- Tecla `T` desde cualquier posición
- Badge `T hh:mm:ss` en header del panel C: gris inactivo / cyan activo
- Por defecto: **oculto** (más espacio para el mensaje)

---

## PANTALLA 6 — Instalación completada ✅ DISEÑO FINAL APROBADO

### Contexto de uso
- **Cuándo aparece**: cuando llega el evento `install_ok` con todas las fichas completadas
- **Cuándo termina**: Enter → P7 Reinicio post-instalación · L → log completo
- **Navegación**: ←→ cambia entre las 4 secciones (Tenant / Ubuntu / Kubernetes / SBOS)
- **Sección SBOS/bos**: scroll vertical Y horizontal — contenido extenso con min-width implícito
- **Stepper**: todos los pasos muestran `✓` verde — instalación completa

### Decisiones de diseño ✅ APROBADO
- Layout: 4 secciones navegables con `←→` en estilo TUI (sin tabs browser)
- Navegador de secciones: `▶ Tenant · Ubuntu · Kubernetes · SBOS / bos` en barra superior
- Sección activa: `▶` cyan + fondo `#0f2433`; inactivas: gris `#334155`
- Cada sección tiene columna principal (scroll-v) + columna lateral 210px (scroll-v)
- **Sección SBOS/bos**: scroll vertical Y horizontal — contenido extenso con `min-width: 520px`
- Terminal 100% de ancho, altura fija 620px, `flex` interno — nunca desborda
- Stepper: todos los pasos con `✓` verde (instalación completa)

### Secciones
```
Tenant     → datos empresa, realm KC, namespace K8s, fichas, URL, próximos pasos
             lateral: resumen contadores, ctx_id, log path
Ubuntu     → SO, kernel, hardware, containerd, systemd, sysctl
             lateral: estándares (ISA-95, NIST 800-207, ISO 27001)
Kubernetes → versión, cluster, CNI Calico, control plane completo, Linkerd, Kyverno
             lateral: ctx_id con namespace/cluster/node/pod
SBOS/bos   → ctx_id activo, Context Plane, JSON-RPC, 7 daemons, stack datos,
             seguridad, observabilidad LGTM, backup
             lateral: ctx_id completo, estándares W3C/OTel
```

### Daemons documentados en pantalla 6
```
bKernel  — WAL listener · Rule Engine · MDM · DLQ antiloop · audit_events
bAuth    — BitMask 64-bit · 3 dominios · Unix socket · ~5ms
bSearch  — Schema Discoverer · Search Learning Engine · Qdrant multi-tenant
bCompass — rutas IA 4 tipos · governance 1/2/3
biedata  — 6 fases · flujo fiscal SIAT · Redis Stream trigger
bhnexus  — WebSocket mTLS · Policy Admin Point · ~2ms
banexus  — udev intercept · actuadores físicos · ~15ms total
```

### ctx_id en pantalla 6
Muestra el ctx_id de instalación con estructura completa según SBOS-049:
tenant · empresa · realm KC · namespace · cluster · node · pod bos · geo · status · context.promoted

---

## PANTALLA 5B — Log completo ✅ DISEÑO FINAL APROBADO

### Contexto de uso
- **Cuándo aparece**: tecla `L` desde P5 mientras la instalación está en progreso
- **La instalación NO se pausa** — sigue corriendo en background mientras se ve el log
- **Cuándo termina**: tecla `L` vuelve a P5 · Ctrl+C cancela la instalación
- **Body**: un solo viewport de ancho y alto completo del body — scroll vertical Y horizontal
- **Toolbar** de filtros y búsqueda ocupa 1 línea fija en el TOP del body (no es parte del scroll)

### Decisiones de diseño ✅ APROBADO
- Acceso: tecla `L` desde pantalla 5
- Banner superior: `📋 Log completo` + hint `[L] volver a vista normal`
- **Toolbar de filtros**: Todos / ✓ OK / ⚠ Advertencias / ✗ Errores — botones TUI con color semántico al activarse
- **Búsqueda**: tecla `/` enfoca el campo de búsqueda; `Esc` limpia y cierra
- Columnas por línea: `[HH:MM:SS]` · `ficha (14 chars padded)` · `mensaje`
- Scroll vertical Y horizontal — líneas `white-space: nowrap`
- Contador de líneas visibles tras filtro: `N líneas` alineado a la derecha del toolbar
- Resaltado `match` (fondo `#0e3a1a`) en líneas que coinciden con búsqueda
- `G` va al final del log

### Colores de línea
```
info  → #64748b  — inicio de ficha
ok    → #22c55e  — ✅ completados
warn  → #f59e0b  — ⚠ advertencias
err   → #ef4444  — ✗ errores
act   → #94a3b8  — pasos intermedios
step  → #475569  — ↳ pasos en ejecución
```

### Código Go
```go
type LogFullModel struct {
    logs    []LogEntry
    vp      viewport.Model  // scroll vertical + horizontal
    filter  LogLevel        // all/ok/warn/err
    search  string
    keys    LogFullKeys
}

// filtrado en tiempo real
func (m LogFullModel) filteredLogs() []LogEntry {
    var out []LogEntry
    for _, l := range m.logs {
        if m.filter != LevelAll && l.Level != m.filter { continue }
        if m.search != "" && !strings.Contains(l.Msg, m.search) &&
           !strings.Contains(l.Ficha, m.search) { continue }
        out = append(out, l)
    }
    return out
}
```

---

## PANTALLA 5C — Panel de error ✅ DISEÑO FINAL APROBADO

### Contexto de uso
- **Cuándo aparece**: tecla `E` desde P5, o automáticamente si el error es bloqueante
- **La instalación SE PAUSA** esperando la decisión del usuario
- **Cuándo termina**: R reintentar → P5 · "Saltar" → P5 omitiendo ficha · L → P5B · Ctrl+C cancela
- **Layout**: columna principal izquierda (causa + pasos + log reciente) + columna lateral 210px (estado + opciones)
- **El log reciente del panel C** es un viewport propio con scroll vertical Y horizontal

### Decisiones de diseño ✅ APROBADO
- Acceso: tecla `E` cuando hay fallo activo
- Banner superior rojo: `✗ ERROR — {ficha} · {fase}` + hint `[E] volver`
- **Layout**: columna principal izquierda + panel lateral derecho 210px

#### Columna principal
1. **Caja causa del error**: borde `#7f1d1d`, fondo `#1a0808`, causas en `#fca5a5`
2. **Caja pasos ejecutados**: mismos iconos `✓/✗/○` con colores explícitos + tiempo + razón del fallo
3. **Caja log reciente**: scroll vertical Y horizontal, últimas líneas del log de la ficha fallida

#### Panel lateral
1. **Estado instalación**: contadores completadas/pendientes/advertencias/errores
2. **Posible causa + diagnóstico**: texto explicativo + comando `kubectl` sugerido
3. **Menú de opciones** (mismo estilo menú TUI con `▶`):
   - Reintentar ficha — vuelve a ejecutar desde el inicio
   - Saltar ficha — marca como omitida y continúa
   - Ver log completo — abre 5B filtrado
   - Cancelar instalación — aborta el bootstrap

### Teclas
```
↑↓ / Tab  → navegar opciones
R         → reintentar directamente
E         → volver a vista normal
L         → abrir log completo (5B)
Enter     → ejecutar opción seleccionada
Ctrl+C    → cancelar instalación
```

### Código Go
```go
type ErrorPanelModel struct {
    ficha   FichaDetail  // id, steps[], errMsg, logs[]
    focus   int          // 0=Reintentar, 1=Saltar, 2=LogCompleto, 3=Cancelar
    vpLog   viewport.Model
    keys    ErrorKeys
}

type FichaDetail struct {
    ID     string
    Phase  string
    Steps  []StepResult
    ErrMsg []string
    Logs   []LogEntry
}
```

---

## FLUJO DE EJECUCIÓN DEL bos

```
bosctl ejecutado
  ├── sin instalación previa   → WELCOME BOS → P1 wizard instalador
  └── instalación detectada   → WELCOME BOS → P8 arranque bos
```

### Ciclo de vida completo
```
WELCOME BOS (splash)
    ↓
P8  Arranque bos         (Ubuntu → K8s → datos → seguridad → daemons → ctx)
    ↓
P9  Dashboard bos        (pantalla estática permanente — daemon en ejecución)
    ├── L → P10 Logs puros
    ├── R → P11 Apagado (modo restart) → P7 reinicio → P8
    └── S → P11 Apagado (modo shutdown) → GOODBYE BOS
```

---

## PANTALLA WELCOME BOS ✅ DISEÑO FINAL APROBADO

### Contexto de uso
- **Cuándo aparece**: SIEMPRE al ejecutar `bosctl` — es la primera pantalla, sin excepción
- **Primera ejecución** (sin `/etc/sbos/tenant.conf`): barra avanza y transiciona a P1 wizard
- **Ejecuciones siguientes** (con instalación): barra avanza y transiciona a P8 arranque
- **No tiene teclas de usuario** — solo muestra el progreso de verificación interna
- **Body**: contenido centrado, NO necesita viewport (contenido fijo, nunca desborda)
- **Footer legal**: 3 líneas fijas debajo del contenido — forman parte del BOTTOM

### Decisiones de diseño ✅ APROBADO
- Pantalla de splash institucional — aparece siempre al ejecutar `bos`
- Sin ASCII art — solo tipografía
- Topbar verde normal de SBOS
- Contenido centrado vertical y horizontalmente

### Elementos
```
S K U L L                                   ← 28px bold #e2e8f0 tracking 0.3em
SOVEREIGN KERNEL & UNIFIED LOGIC LAYER      ← 11px #334155 tracking 0.15em
"Certificamos mejora continua"              ← 11px #1e3a5f italic

─────────────────────────────────────────   ← separador 1px #1e293b

SBOS v1.0 GA                                ← 15px #4ade80 bold
SISTEMA OPERATIVO EMPRESARIAL SOBERANO      ← 11px #334155

Tenant skull-sksistemas · Node node-01 · Cluster cluster-bolivia

[████████████░░░░░] Iniciando daemons SBOS... ← barra 2px #22c55e
```

### Barra de arranque — mensajes en secuencia
```
12%  Verificando integridad de componentes...
25%  Cargando configuración del tenant...
38%  Verificando Ubuntu — kernel OK
52%  Verificando Kubernetes — cluster OK
65%  Iniciando daemons SBOS...
78%  Activando Context Plane...
90%  Registrando ctx_id de sesión...
100% Sistema listo ✓   ← color cambia a #22c55e
```

### Footer legal (fijo, todas las pantallas bos runtime)
```
© 2026 SKULL — Sovereign Kernel & Unified Logic Layer
Powered by SKULL · SBOS v1.0 GA · Sep 2026 · ISA-95 · NIST 800-207 · ISO 27001
ALL COMPONENTS SIGNED WITH Ed25519 · SOVEREIGN · NO DATA LEAVES THIS NODE
```
Colores: línea 1 `#22c55e` opacity .6 · línea 2 `#1e293b` · línea 3 `#0f2433`

---

## PANTALLA GOODBYE BOS ✅ DISEÑO FINAL APROBADO

### Contexto de uso
- **Cuándo aparece**: cuando P11 (apagado ordenado) termina completamente — último paso
- **Es la última pantalla** que muestra bos antes de que el OS apague la terminal
- **Completamente estática** — sin animaciones, sin ticks, sin goroutines activas
- **El OS se encarga** de oscurecer/apagar la pantalla — bos no hace fade ni animación de salida
- **No tiene teclas** — el proceso bos ya terminó, la pantalla es solo un estado final
- **Body**: contenido centrado, NO necesita viewport

### Decisiones de diseño ✅ APROBADO
- Pantalla estática — sin animaciones, sin fade
- El OS se encarga de oscurecer la pantalla al cortar energía
- Topbar apagada: fondo `#0c1a0c`, texto `#166534` — sistema en proceso de cierre
- Contenido centrado, tonos oscuros — el sistema ya está silenciándose

### Elementos
```
G O O D  B Y E                              ← 22px bold #1e3a5f tracking 0.25em

S K U L L                                   ← 18px bold #334155
SOVEREIGN KERNEL & UNIFIED LOGIC LAYER      ← 10px #1e293b
"Certificamos mejora continua"              ← 10px #1e3a5f italic

─────────────────────────────────────────

┌─────────────────────────────────────────┐
│ Tenant        skull-sksistemas          │
│ Sesión        ctx-88291-a4f9            │
│ Inicio        2026-05-20  14:05:24      │
│ Fin           2026-05-20  16:38:01      │
│ Duración      2h 32m 37s               │
│ Fichas activas  22 / 22 OK   (#14532d) │
│ Apagado       ordenado — sin errores    │
└─────────────────────────────────────────┘

Todos los datos han sido guardados y los secretos sellados  ← #1e293b
```

### Footer legal (igual que WELCOME BOS pero más apagado)

---

## PANTALLA P7 — Reinicio post-instalación ✅ DISEÑO FINAL APROBADO

### Contexto de uso
- **Cuándo aparece**: usuario presiona Enter en P6 (Instalación completada) para finalizar
- **Cuándo termina**: countdown llega a 0 → `systemctl reboot` → WELCOME BOS → P8
- **Enter**: fuerza reinicio inmediato sin esperar el countdown
- **Esc**: cancela el reinicio (el sistema queda instalado pero sin reiniciar)
- **Body**: centrado, countdown + logs que van apareciendo — NO necesita viewport (contenido fijo)

### Decisiones de diseño ✅ APROBADO
- Aparece al finalizar el wizard de instalación al presionar "Finalizar"
- Topbar normal SBOS
- Contenido centrado: icono `↺`, título, subtítulo
- Cuenta regresiva 10s con número grande cyan `#06b6d4` 48px
- Barra de progreso 4px que avanza con el countdown
- Logs de systemd aparecen durante la cuenta: escribiendo unit file, habilitando bos.service, etc.
- `Enter` fuerza reinicio inmediato · `Esc` cancela

### Secuencia de logs durante countdown
```
T-9  ✓  Guardando configuración en /etc/sbos/tenant.conf
T-8  ✓  Escribiendo /etc/systemd/system/bos.service
T-7  ✓  Habilitando bos.service — levanta después de k8s.target
T-6     Registrando ctx_id de instalación
T-5  ✓  Log guardado en /var/log/sbos/install.log
T-4     Sincronizando filesystem...
T-2  ✓  Sistema listo para reinicio
T-1     systemctl reboot — iniciando secuencia...
```

---

## PANTALLA P8 — Arranque bos ✅ DISEÑO FINAL APROBADO

### Contexto de uso
- **Cuándo aparece**: después de WELCOME BOS cuando hay instalación existente, o después de P7
- **Cuándo termina**: todos los servicios verificados OK → P9 Dashboard
- **Si hay error en arranque**: mostrar el servicio fallido con `✗` y opciones (reintentar / omitir)
- **Tecla L**: → P10 logs en vivo del arranque sin interrumpirlo
- **Body layout**: panel izquierdo (secuencia) + panel derecho 210px (progreso + info)
- **Panel izquierdo**: viewport con scroll SOLO VERTICAL — la secuencia puede ser larga
- **Panel derecho**: contenido fijo, sin scroll

### Decisiones de diseño ✅ APROBADO
- Ejecutado en cada arranque del sistema (después del instalador o directamente)
- Layout: panel izquierdo (secuencia) + panel derecho 210px (progreso + info + estado actual)
- Orden de arranque **estricto** — cada grupo espera al anterior

### Orden de arranque (Ubuntu primero, bos al final)
```
1. Ubuntu          kernel · containerd · systemd · red
2. Kubernetes      etcd → apiserver → scheduler → controller → kubelet → Calico → Linkerd
3. Stack de datos  postgresql (Patroni) → redis → minio
4. Seguridad       vault → keycloak → kong
5. Daemons SBOS    bKernel → bAuth → bSearch → bCompass → biedata → bhnexus → banexus
6. Context Plane   Context Registry → JSON-RPC socket → dctx_id
```

### Estados por fila (mismos iconos globales)
- `✓` verde `#22c55e` + nombre gris `#64748b` + tiempo `#475569` → completado
- `⠿` spinner amarillo + nombre blanco `#e2e8f0` → ejecutando
- `○` gris `#334155` + nombre `#334155` → pendiente

### Panel derecho
- Barra de progreso 4px cyan con porcentaje
- Info: tenant · node · cluster · Ubuntu ✓ · K8s ✓ · elapsed en vivo
- Caja de estado actual: qué servicio se está levantando + qué sigue

---

## PANTALLA P9 — Dashboard bos ✅ DISEÑO FINAL APROBADO

### Contexto de uso
- **Cuándo aparece**: después de P8 cuando todos los servicios están OK
- **Permanece activa** mientras bos está corriendo — es la pantalla "idle" del daemon
- **El log en vivo** se actualiza cada ~3s con eventos de health check del bos
- **Tecla L**: → P10 logs puros (bos sigue corriendo)
- **Tecla R**: → P11 modo reinicio (confirma antes de ejecutar)
- **Tecla S**: → P11 modo apagado (confirma antes de ejecutar)
- **Body layout**: columna central (info bos) + columna derecha 220px (log vivo + botones)
- **Columna central**: viewport scroll SOLO VERTICAL — si hay muchos daemons/avisos
- **Log en vivo (columna derecha)**: viewport scroll SOLO VERTICAL con auto-scroll activado

### Decisiones de diseño ✅ APROBADO
- Pantalla estática que queda activa mientras bos está corriendo
- Topbar con reloj en vivo (derecha) y punto verde pulsante `● bos activo`
- Layout: columna central (info bos) + columna derecha 220px (log vivo + botones)

### Columna central
```
Header bos: icono ⬡ · nombre · tenant/node/cluster · uptime en vivo · estado "Todos los servicios operativos"
Stats row: Fichas activas · Daemons · Errores · Advertencias · Nodos K8s
Grid daemons: 2 columnas, 7 daemons con ✓ y uptime
ctx_id box: ctx_id · tenant · namespace · Context Plane ✓ · JSON-RPC ✓
```

### Columna derecha
- **Log en vivo**: panel con scroll, agrega líneas cada ~3s, badge `● LIVE` pulsante
  - Líneas: health checks, WAL sync, redis ping, pg lag, keycloak, ctx activo
- **3 botones TUI**:
  - `📋 Logs` — cyan · tecla `L` → P10
  - `↺  Restart` — amarillo `#f59e0b` · tecla `R` → P11 modo restart
  - `⏻  Shutdown` — rojo `#ef4444` · tecla `S` → P11 modo shutdown

---

## PANTALLA P10 — Logs puros ✅ DISEÑO FINAL APROBADO

### Contexto de uso
- **Cuándo aparece**: tecla `L` desde P9 dashboard o desde P8 arranque
- **bos sigue corriendo** — P10 solo muestra logs, no pausa nada
- **Cuándo termina**: tecla `Q` vuelve a P9 · Ctrl+C solo si se quiere cancelar el daemon
- **Body layout**: toolbar (1 línea fija en TOP del body, no scrollea) + log area (resto del body)
- **Log area**: UN SOLO viewport — scroll VERTICAL Y HORIZONTAL
- **Líneas en vivo**: se agregan al viewport en tiempo real via tea.Cmd ticker

### Decisiones de diseño ✅ APROBADO
- Pantalla de logs completa ocupando toda la terminal — sin paneles laterales
- Estilo journalctl/boot Ubuntu: texto crudo con colores semánticos
- Líneas en vivo agregándose cada ~4s mientras bos está activo

### Toolbar
```
Nivel:  [Todos] [✓ OK] [⚠ Warn] [✗ Error] [⬡ bos]
Fuente: [Todas] [bos] [k8s] [sistema]
/ buscar...                    N líneas  [↓ auto]
```

### Formato de línea
```
HH:MM:SS.mmm   fuente    ✓/⚠/✗/⬡   mensaje
```

### Colores por fuente
```
bos     → #4ade80   kernel  → #3b82f6
k8s     → #06b6d4   pg      → #a78bfa
redis   → #f87171   vault   → #fbbf24
keycloak→ #34d399   otros   → #475569
```

### Colores por nivel (igual que journalctl)
```
ok/notice → #22c55e    warn  → #f59e0b
err/crit  → #ef4444    info  → #475569
heal/bos  → #06b6d4    debug → #334155
```

### Teclas
```
/      → enfocar búsqueda
Esc    → limpiar búsqueda
G      → ir al final
T      → toggle timestamp
Q      → volver al dashboard P9
↓ auto → toggle auto-scroll
```

---

## PANTALLA P11 — Apagado / Reinicio ordenado ✅ DISEÑO FINAL APROBADO

### Contexto de uso
- **Cuándo aparece**: tecla `R` (restart) o `S` (shutdown) desde P9 dashboard
- **Modo shutdown**: al terminar → GOODBYE BOS → proceso termina
- **Modo restart**: al terminar → `systemctl reboot` → WELCOME BOS → P8
- **NO tiene teclas de navegación** durante el proceso — solo `Ctrl+C` para forzar (peligroso)
- **Body layout**: panel izquierdo (secuencia apagado) + panel derecho 210px (estado + avisos)
- **Panel izquierdo**: viewport scroll SOLO VERTICAL — la secuencia de apagado puede ser larga
- **Panel derecho**: contenido fijo, sin scroll
- **Topbar cambia de color**: rojo para shutdown · amarillo para restart

### Decisiones de diseño ✅ APROBADO
- Topbar roja para shutdown (`#1a0808` / `#fca5a5`) · amarilla para restart (`#1c1003` / `#fde68a`)
- Mismo layout que P8 pero en **orden inverso** — daemons primero, Ubuntu al final
- Footer advierte: "No interrumpir — apagado en progreso" · `Ctrl+C` solo para forzar (peligroso)

### Orden de apagado (inverso al arranque)
```
1. Daemons SBOS    banexus → bhnexus → bCompass → biedata → bSearch → bAuth → bKernel
2. Context Plane   context.expired → Redis DB1 vaciado → JSON-RPC cerrado
3. Seguridad       kong → keycloak → vault (secrets sellados)
4. Stack de datos  redis (RDB snapshot) → minio → postgresql (checkpoint final)
5. Kubernetes      drain pods → Linkerd → kubelet cordoned → apiserver → etcd snapshot
6. Ubuntu          containerd → systemd sync filesystem → kernel apagado
```

### Acciones críticas documentadas
```
banexus   → chapas y actuadores liberados (BitMask = 0 para todos)
bhnexus   → conexiones WebSocket cerradas gracefully
bKernel   → WAL flush completo — audit_events guardados
vault     → secrets sellados
redis     → RDB snapshot guardado
pg        → checkpoint final (puede tardar — no interrumpir)
etcd      → snapshot guardado antes de bajar
```

### Modo restart
- Misma secuencia P11 → al terminar Ubuntu vuelve a levantar → P7 (sin cuenta regresiva) → P8 → P9

---

## Resumen del conjunto completo de pantallas

### Flujo instalador (primera ejecución)
```
WELCOME BOS → P1 → P2 → P3 → P4 → P5 (→ P5B / P5C) → P6 → P7 → WELCOME BOS → P8 → P9
```

### Flujo runtime (ejecuciones siguientes)
```
WELCOME BOS → P8 → P9
                    ├─ L → P10 → Q → P9
                    ├─ R → P11 restart → WELCOME BOS → P8 → P9
                    └─ S → P11 shutdown → GOODBYE BOS
```

### Inventario completo
| ID | Pantalla | Contexto |
|---|---|---|
| WELCOME | Welcome bos | Splash — cada arranque |
| GOODBYE | Goodbye bos | Apagado completo |
| P1 | Bienvenida (wizard) | Primera instalación |
| P2 | Datos de la Empresa | Primera instalación |
| P3 | Cuenta de Administrador | Primera instalación |
| P4 | Confirmar instalación | Primera instalación |
| P5 | Instalación en progreso | Primera instalación |
| P5B | Log completo | Durante P5, tecla L |
| P5C | Panel de error | Durante P5, tecla E |
| P6 | Instalación completada | Primera instalación |
| P7 | Reinicio post-instalación | Tras P6 |
| P8 | Arranque bos | Cada arranque del sistema |
| P9 | Dashboard bos | Runtime permanente |
| P10 | Logs puros | Runtime, tecla L desde P9 |
| P11 | Apagado / Reinicio | Runtime, teclas R/S desde P9 |
