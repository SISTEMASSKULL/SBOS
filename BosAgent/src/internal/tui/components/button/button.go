// Package button — botones con estados Blurred/Focused/Hovered/Pressed/Toggled
// (§5.11.1 + §4.7 compact + §13 auditoría completa).
// Todos comparten RoundedBorder + Padding(0,0) + Background+BorderBackground.
// Solo cambian BorderForeground y Foreground/Bold entre estados (blurred/
// focused/hovered); el estado Pressed se superpone visualmente con
// Reverse() sobre cualquiera de los otros.
//
// Ciclo de vida de un press (mouse o teclado):
//
//	BeforePress  →  (confirmación)  →  Press  →  flash ~120ms  →  AfterPress
//
// OnBeforePress puede cancelar el ciclo devolviendo prevent=true (ej. validación,
// rate-limit). Si no se cancela, OnPress se ejecuta y se emite PressedMsg.
// Mientras el flash está activo (Pressed()==true), una nueva activación
// (mouse o teclado) se ignora — evita doble-disparo accidental en botones
// críticos como "Eliminar"/"Confirmar pago" (§13.2 Gap 4).
//
// Foco vs. habilitación (§13.2 Gap 1, patrón ARIA Button — APG "determining
// when to make disabled interactive elements focusable"): un botón Disabled
// SIGUE pudiendo recibir foco visual (para que el usuario sepa que existe y
// está apagado, y un FocusManager pueda incluirlo en la navegación), pero
// nunca procesa press ni dispara hooks. Esto coincide con la dirección
// actual del W3C ARIA Authoring Practices Task Force (PR #3387, "Clarify
// guidance for Focusability of disabled controls", 2026) y con frameworks
// como Angular Material, que ya cambiaron su default a "disabled but
// focusable" por las mismas razones de accesibilidad.
//
// Toggle buttons (§13.2 Gap 7, patrón ARIA "toggle button"): si IsToggle es
// true, cada activación invierte Toggled() de forma persistente — el label
// NUNCA cambia entre estados, solo el estilo visual (ver styles.BtnXxxToggled
// si tu paquete styles distingue esa variante; si no, Toggled() + Reverse()
// es suficiente feedback).
//
// Atajos de teclado (§13.2 Gap 3): Shortcut activa el botón SIN necesidad de
// foco previo (mnemonic, ej. "ctrl+s"). El WindowManager/FocusManager que
// registre varios botones visibles simultáneamente debe validar que no haya
// dos Shortcut iguales activos a la vez — ver ValidateShortcuts más abajo.
//
// REQUIERE wiring externo a este archivo (ver comentarios al final del paquete):
//  1. zone.NewGlobal() antes de tea.NewProgram(...) en main().
//  2. tea.NewProgram(m, tea.WithMouseAllMotion()) — habilitar mouse CON
//     reporte de movimiento sin botón presionado. Esto es OBLIGATORIO para
//     que Hovered() funcione: tea.WithMouseCellMotion() (la opción "básica")
//     solo entrega eventos de movimiento mientras un botón del mouse está
//     PRESIONADO (i.e. eventos de drag) — confirmado en la documentación
//     oficial de bubbletea (pkg.go.dev/github.com/charmbracelet/bubbletea,
//     EnableMouseCellMotion vs EnableMouseAllMotion). Si usas
//     WithMouseCellMotion, tea.MouseActionMotion NUNCA llega sin click, y
//     Hovered() se queda permanentemente en false sin importar qué tan
//     correcto sea el código de este paquete — este fue el bug real
//     reportado ("el hover no se ve"), no un problema de este archivo.
//  3. El View() del modelo raíz debe envolver el output final en zone.Scan(...).
//
// Nota de compatibilidad: WithMouseAllMotion no es soportado por TODOS los
// emuladores de terminal (la documentación oficial lo advierte: "many
// modern terminals support this, but not all"). Si tu app corre sobre SSH,
// revisa también que el multiplexor/terminal intermedio no esté
// bloqueando estos reportes antes de asumir que el problema está en Go.
package button

import (
	"fmt"
	"strings"
	"sync/atomic"
	"time"

	"bos/internal/tui/styles"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	zone "github.com/lrstanley/bubblezone"
)

// Variant identifica el tipo de botón.
type Variant int

const (
	Primary Variant = iota
	Secondary
	Danger
	Ghost
	Disabled
	Success
	Warning
	Info
	Link
	Icon
)

// pressFlashDuration es cuánto se mantiene visible el estado Pressed luego
// de confirmarse el press (da feedback visual incluso con Enter/Espacio,
// donde no existe un evento de "soltar" separado). Mientras dura, nuevas
// activaciones se ignoran (guard de doble-press, §13.2 Gap 4).
const pressFlashDuration = 120 * time.Millisecond

// PressedMsg se emite cada vez que un botón se activa (click completo de
// mouse, Enter/Espacio con foco, o Shortcut). El screen que lo recibe en su
// Update() puede filtrar por ID (instancia específica) o por Variant.
type PressedMsg struct {
	ID      string
	Variant Variant
	// Toggled refleja el nuevo estado SOLO si IsToggle==true; para botones
	// momentáneos normales queda en false y debe ignorarse.
	Toggled bool
}

// pressFlashDoneMsg es interno: marca el fin del flash visual de un botón.
type pressFlashDoneMsg struct{ id string }

var idSeq int64

func nextID() string {
	n := atomic.AddInt64(&idSeq, 1)
	return fmt.Sprintf("btn-%d", n)
}

// Model implementa un botón con Focus/Blur/Hover/Pressed/Toggled (mismo
// patrón general que textinput.Model en cuanto a Focus()/Blur()).
type Model struct {
	ID       string
	Label    string
	Variant  Variant
	Shortcut string // ej. "ctrl+s" — vacío si el botón no tiene mnemonic
	IsToggle bool   // si true, Pressed() persiste como Toggled() tras el flash

	// AccessibleName es el nombre semántico del botón cuando Label es un
	// glyph/icono sin texto legible (ej. Label="✕", AccessibleName="Cerrar").
	// Equivalente conceptual a aria-label: un sistema de ayuda contextual,
	// status bar, o lector de pantalla externo debe preferir este campo
	// sobre Label cuando no está vacío. render() sigue usando Label tal
	// cual para el dibujo visual — este campo es puramente semántico.
	AccessibleName string

	focused  bool
	hovered  bool
	pressed  bool
	toggled  bool
	maxWidth int // 0 = sin truncado forzado; >0 = truncar Label a este ancho

	blurred  lipgloss.Style
	focused_ lipgloss.Style
	hovered_ lipgloss.Style // estilo de hover; si está vacío, se cae a blurred

	// OnBeforePress se ejecuta al iniciar un press (mouse down, o Enter/
	// Espacio, o Shortcut). El segundo valor de retorno, si es true, cancela
	// el ciclo: no se marca Pressed ni se llega a disparar OnPress.
	OnBeforePress func() (tea.Cmd, bool)

	// OnPress se ejecuta al confirmarse la activación. PressedMsg se emite
	// siempre (con o sin este hook); usalo para lógica puntual al botón.
	OnPress func() tea.Cmd

	// OnAfterPress se ejecuta cuando termina el flash visual de Pressed.
	OnAfterPress func() tea.Cmd

	// OnFocus/OnBlur dan paridad con los hooks de press (§13.2 Gap 6) —
	// útiles para mostrar ayuda contextual en una status bar cuando el
	// foco entra/sale de un botón específico.
	OnFocus func() tea.Cmd
	OnBlur  func() tea.Cmd

	// OnContextMenu se ejecuta con click derecho (tea.MouseButtonRight)
	// dentro del botón. No forma parte del patrón ARIA Button base, pero
	// es convención común en TUIs con mouse (k9s, lazygit) para menús
	// contextuales. Si es nil, el click derecho no tiene efecto.
	OnContextMenu func() tea.Cmd
}

// New crea un botón con el label y variante dados.
func New(label string, v Variant) *Model {
	b := &Model{ID: nextID(), Label: label, Variant: v}
	switch v {
	case Primary:
		b.blurred = styles.BtnPrimary
		b.focused_ = styles.BtnPrimaryFocused
	case Secondary:
		b.blurred = styles.BtnSecondary
		b.focused_ = styles.BtnSecondaryFocused
	case Danger:
		b.blurred = styles.BtnDanger
		b.focused_ = styles.BtnDangerFocused
	case Ghost:
		b.blurred = styles.BtnGhost
		b.focused_ = styles.BtnGhostFocused
	case Disabled:
		b.blurred = styles.BtnDisabled
		b.focused_ = styles.BtnDisabled
		b.hovered_ = styles.BtnDisabled
	case Success:
		b.blurred = styles.BtnSuccess
		b.focused_ = styles.BtnSuccessFocused
	case Warning:
		b.blurred = styles.BtnWarning
		b.focused_ = styles.BtnWarningFocused
	case Info:
		b.blurred = styles.BtnInfo
		b.focused_ = styles.BtnInfoFocused
	case Link:
		b.blurred = styles.BtnLink
		b.focused_ = styles.BtnLinkFocused
	case Icon:
		b.blurred = styles.BtnIcon
		b.focused_ = styles.BtnIconFocused
	}
	return b
}

// SetID asigna un ID custom (útil para tests, o IDs estables entre renders
// si el slice de botones se reconstruye cada frame).
func (b *Model) SetID(id string) *Model {
	b.ID = id
	return b
}

// SetShortcut asigna un mnemonic de teclado (ej. "ctrl+s") que activa el
// botón sin necesidad de foco previo. Ver ValidateShortcuts para detectar
// colisiones entre varios botones visibles simultáneamente.
func (b *Model) SetShortcut(key string) *Model {
	b.Shortcut = key
	return b
}

// SetToggle convierte el botón en un toggle button persistente
// (patrón ARIA "toggle button", §13.2 Gap 7).
func (b *Model) SetToggle(initial bool) *Model {
	b.IsToggle = true
	b.toggled = initial
	return b
}

func (b *Model) Init() tea.Cmd { return nil }

// Update maneja mouse (vía bubblezone, incluyendo hover — requiere
// tea.WithMouseAllMotion(), ver comentario de cabecera del paquete),
// teclado (Enter/Espacio con foco, Esc para cancelar, y Shortcut sin foco
// previo), y el flash de Pressed. Botones Disabled ignoran toda
// activación, pero SÍ procesan hover/foco visual (§13.2 Gap 1).
func (b *Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {

	case tea.MouseMsg:
		inBounds := zone.Get(b.ID).InBounds(msg)
		b.hovered = inBounds // siempre actualizado, incluso en Disabled

		if b.Variant == Disabled {
			return b, nil
		}

		if !inBounds {
			// Soltar o mover el mouse afuera del botón cancela el press
			// sin disparar OnPress.
			b.pressed = false
			return b, nil
		}

		switch msg.Action {
		case tea.MouseActionMotion:
			return b, nil // hovered ya se actualizó arriba; sin más efecto

		case tea.MouseActionPress:
			switch msg.Button {
			case tea.MouseButtonLeft:
				if b.pressed {
					return b, nil // guard: ya hay un press en curso (§13.2 Gap 4)
				}
				return b, b.beforePress()
			case tea.MouseButtonRight:
				if b.OnContextMenu != nil {
					return b, b.OnContextMenu()
				}
				return b, nil
			}
			return b, nil

		case tea.MouseActionRelease:
			if !b.pressed {
				return b, nil // no hubo press previo registrado en este botón
			}
			return b, b.confirmPress()
		}

	case tea.KeyMsg:
		// El Shortcut funciona SIN requerir foco previo (mnemonic).
		// Disabled bloquea también la activación por shortcut.
		if b.Variant != Disabled && b.Shortcut != "" && msg.String() == b.Shortcut {
			if b.pressed {
				return b, nil // guard de doble-activación también aplica aquí
			}
			before := b.beforePress()
			if !b.pressed {
				return b, before // OnBeforePress canceló el ciclo
			}
			return b, tea.Batch(before, b.confirmPress())
		}

		if b.Variant == Disabled || !b.focused {
			return b, nil
		}
		switch msg.String() {
		case "enter", " ":
			if b.pressed {
				return b, nil // guard: ya hay un press en curso (§13.2 Gap 4)
			}
			before := b.beforePress()
			if !b.pressed {
				return b, before // OnBeforePress canceló el ciclo
			}
			return b, tea.Batch(before, b.confirmPress())

		case "esc":
			// Cancela un press en curso sin disparar OnPress/PressedMsg —
			// convención estándar en TUIs (igual que soltar el mouse fuera
			// del botón cancela). Si no hay press en curso, no hace nada
			// (no le quita el foco al botón; eso es responsabilidad del
			// FocusManager/WindowManager si Esc también cierra un diálogo).
			if b.pressed {
				b.pressed = false
			}
			return b, nil
		}

	case pressFlashDoneMsg:
		if msg.id == b.ID {
			b.pressed = false
			if b.OnAfterPress != nil {
				return b, b.OnAfterPress()
			}
		}
	}

	return b, nil
}

// beforePress dispara OnBeforePress (si existe) y marca pressed=true salvo
// que el hook cancele el ciclo.
func (b *Model) beforePress() tea.Cmd {
	var cmd tea.Cmd
	if b.OnBeforePress != nil {
		var prevent bool
		cmd, prevent = b.OnBeforePress()
		if prevent {
			return cmd
		}
	}
	b.pressed = true
	return cmd
}

// confirmPress emite PressedMsg, ejecuta OnPress, y programa el fin del
// flash visual (que a su vez dispara OnAfterPress). Si IsToggle, invierte
// el estado persistente Toggled() — el flash visual NO revierte ese
// estado, solo da feedback de que el click se registró (§13.2 Gap 7).
func (b *Model) confirmPress() tea.Cmd {
	if b.IsToggle {
		b.toggled = !b.toggled
	}

	id, variant, toggled := b.ID, b.Variant, b.toggled
	cmds := []tea.Cmd{
		func() tea.Msg { return PressedMsg{ID: id, Variant: variant, Toggled: toggled} },
		tea.Tick(pressFlashDuration, func(time.Time) tea.Msg {
			return pressFlashDoneMsg{id: id}
		}),
	}
	if b.OnPress != nil {
		cmds = append(cmds, b.OnPress())
	}
	return tea.Batch(cmds...)
}

// Focus otorga foco visual al botón. Funciona incluso si Variant==Disabled
// (§13.2 Gap 1, patrón APG): un botón deshabilitado debe poder mostrarse
// "enfocado" para que el usuario sepa que existe en la navegación, aunque
// Update() sigue bloqueando toda activación para Disabled.
func (b *Model) Focus() tea.Cmd {
	b.focused = true
	if b.OnFocus != nil {
		return b.OnFocus()
	}
	return nil
}

// Blur retira el foco y cancela cualquier press en curso. Devuelve tea.Cmd
// para dar paridad con OnBeforePress/OnPress/OnAfterPress (§13.2 Gap 6).
//
// NOTA DE COMPATIBILIDAD: esta firma (func() tea.Cmd) difiere de la
// interfaz ui.Component de la sección 3.1 del manual, que define
// Blur() sin retorno. Si este Model se usa detrás de esa interfaz,
// envolver con un adaptador:
//
//	func (b *Model) BlurComponent() { _ = b.Blur() }
//
// o actualizar ui.Component/BaseComponent y FocusManager.move() (sección
// 3.3) para propagar el tea.Cmd de Blur() en su tea.Batch.
func (b *Model) Blur() tea.Cmd {
	b.focused = false
	b.pressed = false
	if b.OnBlur != nil {
		return b.OnBlur()
	}
	return nil
}

func (b Model) Focused() bool { return b.focused }
func (b Model) Hovered() bool { return b.hovered }
func (b Model) Pressed() bool { return b.pressed }
func (b Model) Toggled() bool { return b.toggled }

// Name devuelve el nombre semántico del botón para consumo externo
// (status bar de ayuda, tooltips, logs) — AccessibleName si fue definido,
// o Label como fallback. Usar esto en vez de leer b.Label directamente
// cuando el consumidor necesita el "nombre" del botón y no su render visual.
func (b Model) Name() string {
	if b.AccessibleName != "" {
		return b.AccessibleName
	}
	return b.Label
}

// SetWidth fuerza ancho uniforme en los tres estilos (blurred/focused/
// hovered). Ignora w<=0 para evitar el Width(0) ambiguo entre versiones de
// lipgloss (§13.2 Gap 5) — usar SetMaxLabelWidth si el objetivo es acotar
// el ancho del LABEL (con truncado), no forzar un ancho de caja fijo.
//
// lipgloss.Style es un value type inmutable: NO requiere .Copy() en
// versiones recientes (donde Copy() fue removido) — encadenar .Width(w)
// ya devuelve una copia nueva sin mutar el estilo original.
//
// IMPORTANTE: llamar SOLO al construir los botones (una vez), nunca dentro
// de Update()/View() — hacerlo en cada frame produce un ciclo de feedback
// de ancho creciente (bug confirmado y corregido previamente). MaxWidth
// (más abajo) mide contenido crudo precisamente para evitar este ciclo.
func (b *Model) SetWidth(w int) {
	if w <= 0 {
		return
	}
	b.blurred = b.blurred.Width(w)
	b.focused_ = b.focused_.Width(w)
	b.hovered_ = b.hovered_.Width(w)
}

// SetMaxLabelWidth acota el ancho visual del Label, truncando con elipsis
// por runas (seguro para UTF-8/emoji) si excede el límite, en vez de dejar
// que lipgloss haga wrap y rompa la altura fija de 3 líneas del botón
// (§13.3.4 del manual).
func (b *Model) SetMaxLabelWidth(w int) *Model {
	b.maxWidth = w
	return b
}

// truncateLabel recorta por runas (no por bytes) para no partir caracteres
// UTF-8/emoji a la mitad, y reserva espacio para el "…" final.
func truncateLabel(label string, maxWidth int) string {
	if maxWidth <= 0 || lipgloss.Width(label) <= maxWidth {
		return label
	}
	runes := []rune(label)
	for len(runes) > 0 && lipgloss.Width(string(runes)+"…") > maxWidth {
		runes = runes[:len(runes)-1]
	}
	return string(runes) + "…"
}

// styleFor resuelve el estilo según precedencia:
// Disabled > Pressed > Toggled > Focused > Hovered > Blurred.
//
// Toggled usa un fondo de acento PERMANENTE (tomado del color de borde de
// focused_, sin inventar ningún hex nuevo) en vez de Reverse() — si
// reusara Reverse() como Pressed, Reverse(Reverse(x)) puede ser un no-op
// visual en lipgloss, dejando un botón "toggled" indistinguible de uno
// normal mientras está en flash de press (bug detectado y corregido en
// revisión previa). Pressed se sigue superponiendo con Reverse() sobre
// cualquier estado de debajo, incluido Toggled.
func (b Model) styleFor() lipgloss.Style {
	s := b.blurred
	if b.hovered && !b.focused {
		s = b.focused_ // hover = mismo estilo visual que foco
	}
	if b.focused {
		s = b.focused_
	}
	if b.IsToggle && b.toggled {
		s = s.Background(b.focused_.GetBorderTopForeground()).Bold(true)
	}
	if b.pressed {
		s = s.Reverse(true)
	}
	return s
}

// shortcutHint formatea un Shortcut interno ("ctrl+s") a un hint corto
// para mostrar junto al label (ej. "^S"). Ajustar según convención de tu
// paquete styles si usas otro formato (ej. "[Ctrl+S]").
func shortcutHint(shortcut string) string {
	s := strings.ReplaceAll(shortcut, "ctrl+", "^")
	s = strings.ReplaceAll(s, "alt+", "⌥")
	if len(s) > 0 {
		return strings.ToUpper(s[:1]) + s[1:]
	}
	return s
}

// render genera el contenido visual SIN marcar la zona de mouse — lo usan
// View() y funciones de medición (MaxWidth) que no deben verse afectadas
// por los marcadores invisibles que agrega zone.Mark.
func (b Model) render() string {
	label := b.Label
	if b.maxWidth > 0 {
		label = truncateLabel(label, b.maxWidth)
	}

	switch b.Variant {
	case Icon:
		// Solo icono centrado, ignora texto inyectado, sin cursor.
		return b.styleFor().Render(" " + label + " ")

	case Link:
		// Sin padding extra — HiddenBorder ya reserva 3 líneas.
		s := b.styleFor()
		cursor := "  "
		if b.focused {
			cursor = styles.IconCursor + " "
		}
		if b.Shortcut != "" {
			label = label + " " + styles.Muted.Render("["+shortcutHint(b.Shortcut)+"]")
		}
		return s.Render(cursor + label)

	default:
		// Regular: cursor + label + shortcut hint + padding dinámico.
		s := b.styleFor()
		c := "  "
		if b.focused {
			c = styles.IconCursor + " "
		}
		if b.Shortcut != "" {
			label = label + " " + styles.Muted.Render("["+shortcutHint(b.Shortcut)+"]")
		}
		return s.Render(c + label + strings.Repeat(" ", len(c)+1))
	}
}

// View renderiza el botón y lo marca como zona de mouse para hit-testing.
// IMPORTANTE: el View() del modelo raíz de la app debe envolver el output
// final compuesto en zone.Scan(...) — sin eso, las zonas marcadas aquí
// nunca actualizan sus coordenadas y el mouse no va a funcionar.
func (b Model) View() string {
	return zone.Mark(b.ID, b.render())
}

// Views retorna los Views de un slice de botones.
func Views(buttons []*Model) []string {
	out := make([]string, 0, len(buttons))
	for _, b := range buttons {
		out = append(out, b.View())
	}
	return out
}

// MaxWidth calcula el ancho máximo necesario para un slice de botones.
// Mide el contenido CRUDO (sin estilos) y añade el frame del borde/padding
// para obtener el ancho real. No usa b.focused_.Render() porque podría
// tener .Width() ya aplicado de una llamada anterior → ciclo de feedback.
// Debe llamarse UNA sola vez tras construir los botones, nunca en View()
// ni Update().
func MaxWidth(buttons []*Model) int {
	maxW := 0
	for _, b := range buttons {
		var raw string
		switch b.Variant {
		case Icon:
			raw = " " + b.Label + " "
		case Link:
			raw = styles.IconCursor + " " + b.Label
		default:
			raw = styles.IconCursor + " " + b.Label
		}
		// El frame = border (2) + padding (0) = 2 columnas extra
		w := lipgloss.Width(raw) + 2
		if w > maxW {
			maxW = w
		}
	}
	return maxW
}

// SetUniformWidth aplica el mismo ancho a todos los botones del slice.
// Mismo aviso que SetWidth: llamar UNA sola vez al construir los botones.
func SetUniformWidth(buttons []*Model, w int) {
	for _, b := range buttons {
		b.SetWidth(w)
	}
}

// ValidateShortcuts detecta colisiones de mnemonics entre botones visibles
// simultáneamente (§13.2 Gap 3) — llamar al registrar un conjunto de
// botones en un FocusManager/WindowManager. Devuelve un slice de errores
// legibles, vacío si no hay colisiones.
func ValidateShortcuts(buttons []*Model) []error {
	seen := make(map[string]*Model)
	var errs []error
	for _, b := range buttons {
		if b.Shortcut == "" {
			continue
		}
		if existing, ok := seen[b.Shortcut]; ok {
			errs = append(errs, fmt.Errorf(
				"shortcut %q duplicado entre botones %q (%s) y %q (%s)",
				b.Shortcut, existing.Label, existing.ID, b.Label, b.ID,
			))
			continue
		}
		seen[b.Shortcut] = b
	}
	return errs
}

// ButtonGroup organiza una fila de botones con wrap automático: si la suma
// de anchos excede AvailableWidth, los botones que no entran pasan a la
// siguiente fila — tratando cada botón como una unidad atómica (nunca se
// parte su contenido interno, a diferencia de dejar que JoinHorizontal
// desborde sin control).
type ButtonGroup struct {
	Buttons        []*Model
	Gap            int // espacio horizontal entre botones en la misma fila
	AvailableWidth int // ancho del contenedor padre (viene de tea.WindowSizeMsg)
}

// View calcula las filas necesarias y renderiza el grupo completo.
// SOLO LEE el ancho de cada botón vía lipgloss.Width(b.View()) para decidir
// la fila — NUNCA llama a SetWidth/SetUniformWidth/MaxWidth, por lo que no
// reintroduce el ciclo de feedback de ancho creciente.
func (g ButtonGroup) View() string {
	if len(g.Buttons) == 0 {
		return ""
	}

	var rows [][]string
	var currentRow []string
	currentWidth := 0

	for _, b := range g.Buttons {
		rendered := b.View()
		w := lipgloss.Width(rendered)

		needed := w
		if len(currentRow) > 0 {
			needed += g.Gap
		}

		if len(currentRow) > 0 && currentWidth+needed > g.AvailableWidth {
			rows = append(rows, currentRow)
			currentRow = nil
			currentWidth = 0
			needed = w
		}

		currentRow = append(currentRow, rendered)
		currentWidth += needed
	}
	if len(currentRow) > 0 {
		rows = append(rows, currentRow)
	}
	// gapSpacer: 3 lineas de alto con Background(ColorBgSurface) para que
	// JoinHorizontal no deje huecos sin fondo en las lineas 2 y 3 de los
	// botones con RoundedBorder (mismo bug de "sombras negras" ya corregido
	// antes en los separadores horizontales individuales).
	gapSpacer := hSpacer(g.Gap)

	var renderedRows []string
	for _, row := range rows {
		// Calcular ancho total de esta fila para saber si sobra espacio
		rowWidth := 0
		for i, cell := range row {
			if i > 0 { rowWidth += g.Gap }
			rowWidth += lipgloss.Width(cell)
		}

		var withGaps []string
		for i, cell := range row {
			if i > 0 { withGaps = append(withGaps, gapSpacer) }
			withGaps = append(withGaps, cell)
		}
		// Rellenar el hueco sobrante al final de la fila con fondo del panel.
		// Si la fila no llena todo el ancho (ultima fila con menos botones),
		// sin esto el espacio vacio muestra el negro de la terminal.
		if rowWidth < g.AvailableWidth {
			withGaps = append(withGaps, hSpacer(g.AvailableWidth-rowWidth))
		}
		renderedRows = append(renderedRows, lipgloss.JoinHorizontal(lipgloss.Top, withGaps...))
	}

	return lipgloss.JoinVertical(lipgloss.Left, renderedRows...)
}

// hSpacerCache evita recrear el Render() de lipgloss para cada llamada.
var hSpacerCache = map[int]string{}

// hSpacer retorna un string de 3 lineas de alto (misma altura que un boton
// con RoundedBorder) y del ancho dado, con Background(ColorBgSurface).
// Necesita 3 lineas para que JoinHorizontal no deje huecos sin fondo en las
// lineas 2 y 3 de los botones adyacentes.
func hSpacer(width int) string {
	if width <= 0 { return "" }
	if s, ok := hSpacerCache[width]; ok { return s }
	buf := make([]byte, width)
	for i := range buf { buf[i] = ' ' }
	line := string(buf)
	s := styles.BtnSpacer.Render(line + "\n" + line + "\n" + line)
	hSpacerCache[width] = s
	return s
}
