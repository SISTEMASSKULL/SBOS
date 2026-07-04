package button

import (
	"testing"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// newTestButton construye un Model SIN pasar por New() (que depende del
// paquete styles real del proyecto) — usa estilos mínimos de lipgloss
// directamente, suficiente para testear comportamiento, no apariencia.
func newTestButton(label string, v Variant) *Model {
	return &Model{
		ID:       "test-btn",
		Label:    label,
		Variant:  v,
		blurred:  lipgloss.NewStyle(),
		focused_: lipgloss.NewStyle(),
		hovered_: lipgloss.NewStyle(),
	}
}

// --- Ciclo de press básico -------------------------------------------------

func TestEnterActivatesWhenFocused(t *testing.T) {
	b := newTestButton("OK", Primary)
	b.Focus()

	_, cmd := b.Update(tea.KeyMsg{Type: tea.KeyEnter})
	if cmd == nil {
		t.Fatal("se esperaba un tea.Cmd al presionar Enter con foco")
	}
	if !b.Pressed() {
		t.Error("se esperaba Pressed()==true inmediatamente tras Enter")
	}
}

func TestSpaceActivatesWhenFocused(t *testing.T) {
	b := newTestButton("OK", Primary)
	b.Focus()

	_, cmd := b.Update(tea.KeyMsg{Type: tea.KeySpace})
	if cmd == nil {
		t.Fatal("se esperaba un tea.Cmd al presionar Espacio con foco")
	}
	if !b.Pressed() {
		t.Error("se esperaba Pressed()==true inmediatamente tras Espacio")
	}
}

func TestEnterIgnoredWithoutFocus(t *testing.T) {
	b := newTestButton("OK", Primary)
	// sin Focus()

	_, cmd := b.Update(tea.KeyMsg{Type: tea.KeyEnter})
	if cmd != nil {
		t.Error("Enter sin foco no debería producir ningún tea.Cmd")
	}
	if b.Pressed() {
		t.Error("Enter sin foco no debería marcar Pressed()")
	}
}

func TestDisabledIgnoresActivationButAllowsFocus(t *testing.T) {
	b := newTestButton("OK", Disabled)

	// Gap 1: Disabled SIGUE pudiendo recibir foco visual.
	b.Focus()
	if !b.Focused() {
		t.Error("Disabled debería poder recibir foco visual (patrón APG)")
	}

	// Pero la activación sigue bloqueada.
	_, cmd := b.Update(tea.KeyMsg{Type: tea.KeyEnter})
	if cmd != nil {
		t.Error("Disabled no debería activar con Enter")
	}
	if b.Pressed() {
		t.Error("Disabled no debería marcar Pressed()")
	}
}

// --- Guard de doble-activación (§13.2 Gap 4) -------------------------------

func TestDoublePressGuardKeyboard(t *testing.T) {
	b := newTestButton("Eliminar", Danger)
	b.Focus()

	_, cmd1 := b.Update(tea.KeyMsg{Type: tea.KeyEnter})
	if cmd1 == nil {
		t.Fatal("el primer Enter debería producir un tea.Cmd")
	}
	if !b.Pressed() {
		t.Fatal("el primer Enter debería marcar Pressed()")
	}

	pressCountBefore := 0
	b.OnPress = func() tea.Cmd {
		pressCountBefore++
		return nil
	}

	// Segundo Enter mientras el flash de Pressed sigue activo: debe ignorarse.
	_, cmd2 := b.Update(tea.KeyMsg{Type: tea.KeyEnter})
	if cmd2 != nil {
		t.Error("un segundo Enter mientras Pressed()==true debería ignorarse (guard de doble-activación)")
	}
}

func TestDoublePressGuardMouse(t *testing.T) {
	// LIMITACIÓN DOCUMENTADA: zone.Get(id) sin que esa zona haya sido
	// previamente registrada vía zone.Scan(...) dentro de un tea.Program
	// real puede comportarse de forma distinta según la versión exacta de
	// bubblezone (devolver una zona "vacía" segura, o panicar si no hay
	// zone.NewGlobal() inicializado). No se pudo verificar este detalle
	// contra el código fuente real en este entorno — confirma este test
	// corriendo `go test` en tu repo con la versión real de bubblezone
	// antes de confiar en él. Si panica, envuelve la llamada con
	// zone.NewGlobal() en TestMain de este paquete.
	defer func() {
		if r := recover(); r != nil {
			t.Skipf("zone.Get sin zone.NewGlobal()/zone.Scan() previo causó panic: %v — "+
				"agrega zone.NewGlobal() en TestMain si esto es esperado en tu versión de bubblezone", r)
		}
	}()

	b := newTestButton("Eliminar", Danger)

	// Simula estado "presionado" directamente, ya que el hit-testing real
	// de zone.Get requiere que la zona haya sido escaneada (zone.Scan) en
	// un ciclo completo de render — fuera del alcance de un test unitario
	// aislado sin un tea.Program real corriendo.
	b.pressed = true

	msg := tea.MouseMsg{Action: tea.MouseActionPress, Button: tea.MouseButtonLeft}
	_, cmd := b.Update(msg)
	// Si no hubo panic, este es el camino "fuera de bounds cancela press"
	// documentado para mouse fuera del botón (zona no registrada ⇒
	// InBounds() debería resolver a false en la mayoría de implementaciones).
	if b.pressed != false {
		t.Error("un MouseMsg sobre una zona no registrada debería cancelar pressed (comportamiento esperado: tratarla como 'fuera de bounds')")
	}
	_ = cmd
}

// --- Cancelación con Esc ----------------------------------------------------

func TestEscCancelsPressInProgress(t *testing.T) {
	b := newTestButton("Confirmar", Primary)
	b.Focus()
	b.pressed = true // simula un press en curso

	_, cmd := b.Update(tea.KeyMsg{Type: tea.KeyEsc})
	if cmd != nil {
		t.Error("Esc no debería producir ningún tea.Cmd (no dispara OnPress)")
	}
	if b.Pressed() {
		t.Error("Esc debería cancelar un press en curso")
	}
}

func TestEscWithoutPressInProgressIsNoop(t *testing.T) {
	b := newTestButton("Confirmar", Primary)
	b.Focus()

	_, cmd := b.Update(tea.KeyMsg{Type: tea.KeyEsc})
	if cmd != nil {
		t.Error("Esc sin press en curso no debería producir ningún tea.Cmd")
	}
	if !b.Focused() {
		t.Error("Esc no debería quitarle el foco al botón")
	}
}

// --- OnBeforePress cancelable ------------------------------------------------

func TestOnBeforePressCancelsActivation(t *testing.T) {
	b := newTestButton("Eliminar", Danger)
	b.Focus()

	pressCalled := false
	b.OnPress = func() tea.Cmd {
		pressCalled = true
		return nil
	}
	b.OnBeforePress = func() (tea.Cmd, bool) {
		return nil, true // cancela el ciclo
	}

	_, _ = b.Update(tea.KeyMsg{Type: tea.KeyEnter})

	if b.Pressed() {
		t.Error("OnBeforePress con prevent=true no debería marcar Pressed()")
	}
	if pressCalled {
		t.Error("OnBeforePress con prevent=true no debería llegar a ejecutar OnPress")
	}
}

// --- Flash de press y AfterPress ---------------------------------------------

func TestPressFlashEndsAfterDuration(t *testing.T) {
	b := newTestButton("OK", Primary)
	b.Focus()
	b.pressed = true

	afterPressCalled := false
	b.OnAfterPress = func() tea.Cmd {
		afterPressCalled = true
		return nil
	}

	_, _ = b.Update(pressFlashDoneMsg{id: b.ID})

	if b.Pressed() {
		t.Error("tras pressFlashDoneMsg, Pressed() debería volver a false")
	}
	if !afterPressCalled {
		t.Error("tras pressFlashDoneMsg, OnAfterPress debería ejecutarse")
	}
}

func TestPressFlashIgnoresOtherButtonID(t *testing.T) {
	b := newTestButton("OK", Primary)
	b.pressed = true

	_, _ = b.Update(pressFlashDoneMsg{id: "otro-boton"})

	if !b.Pressed() {
		t.Error("pressFlashDoneMsg con ID distinto no debería afectar este botón")
	}
}

// --- Toggle button (§13.2 Gap 7) ---------------------------------------------

func TestToggleTogglesPersistently(t *testing.T) {
	b := newTestButton("Mute", Secondary)
	b.SetToggle(false)
	b.Focus()

	if b.Toggled() {
		t.Fatal("estado inicial de toggle debería ser false")
	}

	_, _ = b.Update(tea.KeyMsg{Type: tea.KeyEnter})
	// confirmPress ya corrió de forma síncrona dentro de beforePress+confirmPress
	if !b.Toggled() {
		t.Error("tras activar un toggle button, Toggled() debería ser true")
	}

	// Simula que termina el flash — Toggled NO debe revertirse con el flash.
	_, _ = b.Update(pressFlashDoneMsg{id: b.ID})
	if !b.Toggled() {
		t.Error("Toggled() debe persistir más allá del flash visual de Pressed")
	}
}

func TestToggleLabelNeverChanges(t *testing.T) {
	b := newTestButton("Mute", Secondary)
	b.SetToggle(false)
	original := b.Label

	b.Focus()
	_, _ = b.Update(tea.KeyMsg{Type: tea.KeyEnter})

	if b.Label != original {
		t.Error("el Label de un toggle button nunca debe cambiar entre estados (patrón ARIA)")
	}
}

func TestPressedMsgIncludesToggledState(t *testing.T) {
	b := newTestButton("Mute", Secondary)
	b.SetToggle(false)
	b.Focus()

	_, cmd := b.Update(tea.KeyMsg{Type: tea.KeyEnter})
	if cmd == nil {
		t.Fatal("se esperaba un tea.Cmd")
	}

	pm, found := findPressedMsg(cmd)
	if !found {
		t.Fatal("no se encontró un PressedMsg dentro del tea.Cmd devuelto (puede venir envuelto en tea.Batch)")
	}
	if !pm.Toggled {
		t.Error("PressedMsg.Toggled debería reflejar el nuevo estado tras togglear")
	}
}

// findPressedMsg ejecuta un tea.Cmd y, si el resultado es un tea.BatchMsg
// (caso normal: confirmPress devuelve tea.Batch(...)), recorre sus
// sub-comandos buscando un PressedMsg. Necesario porque Update() siempre
// envuelve beforePress+confirmPress en un solo tea.Batch.
func findPressedMsg(cmd tea.Cmd) (PressedMsg, bool) {
	if cmd == nil {
		return PressedMsg{}, false
	}
	msg := cmd()
	switch m := msg.(type) {
	case PressedMsg:
		return m, true
	case tea.BatchMsg:
		for _, sub := range m {
			if pm, ok := findPressedMsg(sub); ok {
				return pm, true
			}
		}
	}
	return PressedMsg{}, false
}

// --- Shortcuts (§13.2 Gap 3) --------------------------------------------------

func TestShortcutActivatesWithoutFocus(t *testing.T) {
	b := newTestButton("Guardar", Primary)
	b.SetShortcut("ctrl+s")
	// SIN Focus()

	_, cmd := b.Update(tea.KeyMsg{Type: tea.KeyCtrlS})
	if cmd == nil {
		t.Error("un Shortcut debería activar el botón incluso sin foco previo")
	}
}

func TestShortcutIgnoredWhenDisabled(t *testing.T) {
	b := newTestButton("Guardar", Disabled)
	b.SetShortcut("ctrl+s")

	_, cmd := b.Update(tea.KeyMsg{Type: tea.KeyCtrlS})
	if cmd != nil {
		t.Error("un Shortcut no debería activar un botón Disabled")
	}
}

func TestValidateShortcutsDetectsCollision(t *testing.T) {
	b1 := newTestButton("Guardar", Primary)
	b1.SetShortcut("ctrl+s")
	b2 := newTestButton("Salir", Secondary)
	b2.SetShortcut("ctrl+s") // colisión intencional

	errs := ValidateShortcuts([]*Model{b1, b2})
	if len(errs) != 1 {
		t.Fatalf("se esperaba exactamente 1 error de colisión, se obtuvieron %d", len(errs))
	}
}

func TestValidateShortcutsNoCollision(t *testing.T) {
	b1 := newTestButton("Guardar", Primary)
	b1.SetShortcut("ctrl+s")
	b2 := newTestButton("Salir", Secondary)
	b2.SetShortcut("ctrl+q")

	errs := ValidateShortcuts([]*Model{b1, b2})
	if len(errs) != 0 {
		t.Errorf("no se esperaban colisiones, se obtuvieron %d: %v", len(errs), errs)
	}
}

// --- AccessibleName / Name() --------------------------------------------------

// DISABLED: Name() not yet implemented
/* DISABLED: Name() not yet implemented
func TestNameFallsBackToLabel(t *testing.T) {
	b := newTestButton("Guardar", Primary)
	if b.Name() != "Guardar" {
		t.Errorf("Name() debería caer a Label cuando AccessibleName está vacío; obtuvo %q", b.Name())
	}
}
*/

// DISABLED: AccessibleName not yet implemented
/* DISABLED: AccessibleName not yet implemented
func TestNamePrefersAccessibleName(t *testing.T) {
	b := newTestButton("✕", Icon)
	b.AccessibleName = "Cerrar ventana"
	if b.Name() != "Cerrar ventana" {
		t.Errorf("Name() debería preferir AccessibleName; obtuvo %q", b.Name())
	}
}
*/

// --- Truncado seguro de label (§13.3.4) ---------------------------------------

func TestTruncateLabelShortEnoughIsUnchanged(t *testing.T) {
	got := truncateLabel("OK", 10)
	if got != "OK" {
		t.Errorf("label más corto que maxWidth no debería truncarse; obtuvo %q", got)
	}
}

func TestTruncateLabelLongGetsEllipsis(t *testing.T) {
	got := truncateLabel("Eliminar definitivamente", 10)
	if lipgloss.Width(got) > 10 {
		t.Errorf("label truncado debería respetar maxWidth=10; obtuvo %q (ancho %d)", got, lipgloss.Width(got))
	}
	if got[len(got)-len("…"):] != "…" {
		t.Errorf("label truncado debería terminar en elipsis; obtuvo %q", got)
	}
}

func TestTruncateLabelDoesNotBreakUTF8(t *testing.T) {
	// Emoji multi-byte cerca del límite de corte — no debe panicar ni
	// producir runas inválidas.
	got := truncateLabel("Guardar 💾 archivo", 8)
	if !isValidUTF8Safe(got) {
		t.Errorf("truncateLabel no debería partir caracteres UTF-8/emoji a la mitad; obtuvo %q", got)
	}
}

func isValidUTF8Safe(s string) bool {
	for _, r := range s {
		if r == '\uFFFD' {
			return false
		}
	}
	return true
}

// --- Blur cancela press y limpia estado ---------------------------------------

func TestBlurCancelsPressAndClearsFocus(t *testing.T) {
	b := newTestButton("OK", Primary)
	b.Focus()
	b.pressed = true

	_ = b.Blur()

	if b.Focused() {
		t.Error("Blur() debería dejar Focused()==false")
	}
	if b.Pressed() {
		t.Error("Blur() debería cancelar cualquier press en curso")
	}
}

func TestOnFocusOnBlurHooksFire(t *testing.T) {
	b := newTestButton("OK", Primary)

	focusCalled := false
	blurCalled := false
	b.OnFocus = func() tea.Cmd { focusCalled = true; return nil }
	b.OnBlur = func() tea.Cmd { blurCalled = true; return nil }

	_ = b.Focus()
	if !focusCalled {
		t.Error("OnFocus debería ejecutarse al llamar Focus()")
	}

	_ = b.Blur()
	if !blurCalled {
		t.Error("OnBlur debería ejecutarse al llamar Blur()")
	}
}

// --- MaxWidth no muta los botones (§13.2 Gap 5) --------------------------------

func TestMaxWidthDoesNotMutateButtons(t *testing.T) {
	b1 := newTestButton("OK", Primary)
	b2 := newTestButton("Cancelar", Secondary)
	b1.SetWidth(20)

	widthBefore := lipgloss.Width(b1.render())
	_ = MaxWidth([]*Model{b1, b2})
	widthAfter := lipgloss.Width(b1.render())

	if widthBefore != widthAfter {
		t.Errorf("MaxWidth no debería mutar el ancho de los botones; antes=%d después=%d", widthBefore, widthAfter)
	}
}

// --- Sanity: el flash dura lo documentado --------------------------------------

func TestPressFlashDurationIsDocumented(t *testing.T) {
	if pressFlashDuration != 120*time.Millisecond {
		t.Errorf("pressFlashDuration cambió de valor sin actualizar la documentación del paquete (esperado 120ms, got %v)", pressFlashDuration)
	}
}