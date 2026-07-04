// Package model — tests T8.2 (F8): pureza TEA del modelo del TUI.
// DoD: go test -race -count=50 ./internal/tui/model/
// Política: internal/tui/POLICY.md — Update/Init sin efectos secundarios (P3),
// campo único CurrentScreen (P11), recálculo de viewports (P10).
package model

import (
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

func newTestModel() *Model {
	m := New(Config{SocketPath: "/tmp/test.sock"}, SeedData{})
	m.Width, m.Height = 120, 40
	m.recalcBodyHeight()
	return m
}

// TestNew_ValoresPorDefecto fija el contrato del constructor: pantalla
// inicial Welcome, semillas con defaults (país BO, MFA activo) y canal
// WebSocket buffereado listo.
func TestNew_ValoresPorDefecto(t *testing.T) {
	m := New(Config{SocketPath: "/tmp/x.sock", DemoMode: true}, SeedData{})

	if m.CurrentScreen != ScreenWelcome {
		t.Errorf("pantalla inicial: want ScreenWelcome, got %d", m.CurrentScreen)
	}
	if m.TenantPais != "BO" {
		t.Errorf("país por defecto: want BO, got %q", m.TenantPais)
	}
	if !m.MFAEnabled {
		t.Error("MFA debe estar activo por defecto (seed.MFA=false → true)")
	}
	if m.FichasTotal != 22 {
		t.Errorf("FichasTotal: want 22, got %d", m.FichasTotal)
	}
	if m.WsCh == nil || cap(m.WsCh) != 128 {
		t.Errorf("WsCh debe ser canal con buffer 128, got cap %d", cap(m.WsCh))
	}
	if !m.VpAutoScroll {
		t.Error("VpAutoScroll debe iniciar en true")
	}
	if m.ViewMode != "normal" {
		t.Errorf("ViewMode: want normal, got %q", m.ViewMode)
	}

	// la semilla se respeta cuando viene con datos
	m2 := New(Config{}, SeedData{Pais: "AR", RazonSocial: "ACME"})
	if m2.TenantPais != "AR" || m2.TenantName != "ACME" {
		t.Errorf("la semilla del .env debe pre-rellenar los campos: pais=%q nombre=%q", m2.TenantPais, m2.TenantName)
	}
}

// TestInit_PuroYSinEfectos: Init devuelve comandos (no nil) y NO muta el
// modelo — invariante TEA P3 (los efectos van en Cmd, nunca en Init/Update).
func TestInit_PuroYSinEfectos(t *testing.T) {
	m := newTestModel()
	antes := m.CurrentScreen
	logsAntes := len(m.Logs)

	cmd := m.Init()

	if cmd == nil {
		t.Error("Init debe devolver los comandos iniciales (blink+spinner)")
	}
	if m.CurrentScreen != antes || len(m.Logs) != logsAntes {
		t.Error("Init no debe mutar el modelo (invariante TEA P3)")
	}
}

// TestSetScreen_StepperYNavHint fija el contrato de navegación P11:
// stepper visible solo en P1–P5, nav hint solo en P1–P4.
func TestSetScreen_StepperYNavHint(t *testing.T) {
	cases := []struct {
		screen      Screen
		wantStepper bool
		wantNavHint bool
	}{
		{ScreenWelcome, false, false},
		{ScreenWizardP1, true, true},
		{ScreenWizardP2, true, true},
		{ScreenWizardP3, true, true},
		{ScreenWizardP4, true, true},
		{ScreenInstalling, true, false},
		{ScreenInstallDone, false, false},
		{ScreenDashboard, false, false},
		{ScreenGoodbye, false, false},
	}
	m := newTestModel()
	for _, c := range cases {
		m.SetScreen(c.screen)
		if m.CurrentScreen != c.screen {
			t.Errorf("pantalla %d: CurrentScreen no actualizado", c.screen)
		}
		if m.ShowStepper != c.wantStepper {
			t.Errorf("pantalla %d: ShowStepper want %v got %v", c.screen, c.wantStepper, m.ShowStepper)
		}
		if m.ShowNavHint != c.wantNavHint {
			t.Errorf("pantalla %d: ShowNavHint want %v got %v", c.screen, c.wantNavHint, m.ShowNavHint)
		}
		if m.BodyVP.Height != m.BodyHeight {
			t.Errorf("pantalla %d: BodyVP.Height debe seguir a BodyHeight (P10)", c.screen)
		}
	}
}

// TestSetScreen_NoTocaEstadoAjeno: cambiar de pantalla solo ajusta layout —
// no debe tocar logs, fichas ni la conexión (campo único P11 sin efectos
// colaterales).
func TestSetScreen_NoTocaEstadoAjeno(t *testing.T) {
	m := newTestModel()
	m.Logs = []LogEntry{{Msg: "línea"}}
	m.Fichas = map[string]*FichaDetail{"redis": {ID: "redis"}}
	m.FichasOK = 5

	m.SetScreen(ScreenDashboard)

	if len(m.Logs) != 1 || m.Fichas["redis"] == nil || m.FichasOK != 5 {
		t.Error("SetScreen no debe mutar estado fuera del layout")
	}
}

// TestRecalcBodyHeight_LimiteInferior: con terminal diminuta BodyHeight
// nunca baja de 1 (P10 — sin panics de viewport negativo).
func TestRecalcBodyHeight_LimiteInferior(t *testing.T) {
	m := newTestModel()
	m.Height = 2
	m.SetScreen(ScreenWizardP2) // stepper+navhint = máximo de líneas fijas
	if m.BodyHeight < 1 {
		t.Errorf("BodyHeight debe ser ≥1, got %d", m.BodyHeight)
	}

	m.Height = 40
	m.SetScreen(ScreenWizardP2)
	// top=3+1(stepper), bottom=1+1(navhint) → 40-4-2 = 34
	if m.BodyHeight != 34 {
		t.Errorf("BodyHeight con stepper+navhint: want 34, got %d", m.BodyHeight)
	}
}

// TestIsInstallingScreen: solo P5/P5B/P5C tienen viewports de instalación.
func TestIsInstallingScreen(t *testing.T) {
	m := newTestModel()
	for _, s := range []Screen{ScreenInstalling, ScreenInstallLog, ScreenInstallErr} {
		m.SetScreen(s)
		if !m.IsInstallingScreen() {
			t.Errorf("pantalla %d debe ser installing", s)
		}
	}
	for _, s := range []Screen{ScreenWelcome, ScreenWizardP4, ScreenInstallDone, ScreenDashboard} {
		m.SetScreen(s)
		if m.IsInstallingScreen() {
			t.Errorf("pantalla %d no es installing", s)
		}
	}
}

// TestFichaDetail_Helpers: ActiveStep y CountDone son funciones puras.
func TestFichaDetail_Helpers(t *testing.T) {
	f := &FichaDetail{Steps: []StepDetail{
		{Name: "a", Status: StepDone},
		{Name: "b", Status: StepActive},
		{Name: "c", Status: StepPending},
		{Name: "d", Status: StepDone},
	}}
	if got := f.ActiveStep(); got == nil || got.Name != "b" {
		t.Errorf("ActiveStep: want b, got %+v", got)
	}
	if got := f.CountDone(); got != 2 {
		t.Errorf("CountDone: want 2, got %d", got)
	}

	vacia := &FichaDetail{}
	if vacia.ActiveStep() != nil || vacia.CountDone() != 0 {
		t.Error("ficha sin pasos: ActiveStep nil y CountDone 0")
	}
}

// TestKeysFor_TodasLasPantallas: cada una de las 15 pantallas tiene keymap
// no vacío y cumple help.KeyMap (ShortHelp/FullHelp coherentes).
func TestKeysFor_TodasLasPantallas(t *testing.T) {
	for s := ScreenWelcome; s <= ScreenGoodbye; s++ {
		km := KeysFor(s)
		if len(km) == 0 {
			t.Errorf("pantalla %d: keymap vacío", s)
		}
		if len(km.ShortHelp()) != len(km) {
			t.Errorf("pantalla %d: ShortHelp debe exponer todas las teclas", s)
		}
		if len(km.FullHelp()) != 1 || len(km.FullHelp()[0]) != len(km) {
			t.Errorf("pantalla %d: FullHelp debe envolver ShortHelp", s)
		}
	}
}

// TestIsNavKey: navegación reconocida vs teclas de texto.
func TestIsNavKey(t *testing.T) {
	nav := []tea.KeyType{tea.KeyEnter, tea.KeyEsc, tea.KeyTab, tea.KeyShiftTab,
		tea.KeyUp, tea.KeyDown, tea.KeyCtrlC, tea.KeyCtrlD}
	for _, kt := range nav {
		if !IsNavKey(tea.KeyMsg{Type: kt}) {
			t.Errorf("tipo %v debe ser tecla de navegación", kt)
		}
	}
	if IsNavKey(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'a'}}) {
		t.Error("una runa de texto no es tecla de navegación")
	}
}

// TestVpDims_Invariantes: los 3 paneles respetan mínimos y el alto nunca
// baja de 4 (P10 — responsividad sin panics).
func TestVpDims_Invariantes(t *testing.T) {
	// terminal normal
	wA, wB, wC, h := VpDims(120, 30)
	if wA < 10 || wB < 10 || wC < 18 {
		t.Errorf("anchos mínimos violados: %d/%d/%d", wA, wB, wC)
	}
	if h != 20 {
		t.Errorf("alto: want 20 (30-10), got %d", h)
	}
	// suma de paneles + frames = ancho total (3 paneles × frame 2)
	if total := (wA + 2) + (wB + 2) + (wC + 2); total != 120 {
		t.Errorf("los paneles deben repartir el ancho completo: %d ≠ 120", total)
	}

	// terminal diminuta — fallback fijo y alto mínimo
	wA, wB, wC, h = VpDims(40, 5)
	if wA != 14 || wB != 12 || wC != 14 {
		t.Errorf("fallback <50 cols: want 14/12/14, got %d/%d/%d", wA, wB, wC)
	}
	if h != 4 {
		t.Errorf("alto mínimo: want 4, got %d", h)
	}
}

// TestScrollbars_NoPanic: con dimensiones extremas los scrollbars no
// entran en pánico y respetan el tamaño pedido.
func TestScrollbars_NoPanic(t *testing.T) {
	m := newTestModel()

	if got := VScrollbar(m.BodyVP, 0); got != "" {
		t.Errorf("h=0 debe retornar vacío, got %q", got)
	}
	if got := HScrollbar(m.BodyVP, 0); got != "" {
		t.Errorf("w=0 debe retornar vacío, got %q", got)
	}

	v := VScrollbar(m.BodyVP, 5)
	if n := len(splitLines(v)); n != 5 {
		t.Errorf("VScrollbar de 5: want 5 líneas, got %d", n)
	}
}

func splitLines(s string) []string {
	if s == "" {
		return nil
	}
	out := []string{}
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' {
			out = append(out, s[start:i])
			start = i + 1
		}
	}
	return append(out, s[start:])
}
