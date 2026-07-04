// Package model — model.go: struct Model exportado del TUI del instalador bos.
// Extraído de cmd/bosctl/install_ui.go en F3.3 (BOS-REPAIR).
// Corrige P11: un único campo CurrentScreen (elimina step + screen duplicados).
package model

import (
	"time"

	"bos/internal/boslog"
	"github.com/charmbracelet/bubbles/spinner"
	"bos/internal/tui/ctrl"
	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
	"bos/internal/tui/tuilog"
	"bos/internal/wslib"

	"github.com/charmbracelet/bubbles/help"
	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/huh"
)

// ── Tipos de datos auxiliares ──────────────────────────────────────────────

// LogEntry es una línea del log del TUI con timestamp y nivel.
type LogEntry struct {
	Ts    time.Time
	Level LogLevel
	Ficha string
	Step  string
	Msg   string
}

// StepDetail mantiene el estado de un paso dentro de una ficha.
type StepDetail struct {
	Name      string
	Status    StepStatus
	StartTime time.Time
	Duration  time.Duration
	Msg       string
	ErrMsg    string
}

// FichaDetail mantiene el estado de instalación de una ficha.
type FichaDetail struct {
	ID        string
	Status    FichaStatus
	Steps     []StepDetail
	StartTime time.Time
	Duration  time.Duration
	ErrMsg    string
}

// ActiveStep retorna el primer paso activo de la ficha, o nil.
func (f *FichaDetail) ActiveStep() *StepDetail {
	for i := range f.Steps {
		if f.Steps[i].Status == StepActive {
			return &f.Steps[i]
		}
	}
	return nil
}

// CountDone retorna el número de pasos completados.
func (f *FichaDetail) CountDone() int {
	n := 0
	for _, s := range f.Steps {
		if s.Status == StepDone {
			n++
		}
	}
	return n
}

// InstallPhase agrupa fichas en una fase lógica del DAG de instalación.
type InstallPhase struct {
	Nombre string
	Fichas []string
}

// SysInfo contiene información básica del sistema operativo del host.
type SysInfo struct {
	OS, Kernel, RAM, Disk, CPU string
}

// ── Constantes de tipos de evento WebSocket ──────────────────────────
// Valores canónicos que el daemon bos emite en Event.Type (JSON: "type").
// Deben coincidir con las constantes EventType en internal/server/ws.go.

const (
	EvSagaStart  = "saga_start"
	EvSagaOK     = "saga_ok"
	EvSagaFail   = "saga_fail"
	EvStepStart  = "step_start"
	EvStepOK     = "step_ok"
	EvStepFail   = "step_fail"
	EvHealth     = "health_update"
	EvReload     = "reload"
	EvReconcile  = "reconcile"
	EvFichaLog   = "ficha_log"
)

// WsEventMsg es un mensaje recibido del daemon bos vía WebSocket.
// Pure data: no contiene tipos de wslib.
type WsEventMsg struct {
	EvType    string
	Ficha     string
	Step      string
	Msg       string
	Total     int
	ErrDetail string
	Data      map[string]interface{}
	Ts        time.Time // capturado al consumir del canal, fuera de Update (corrige P3)
}

// ── Config ─────────────────────────────────────────────────────────────────

// Config contiene los parámetros de construcción del Model.
type Config struct {
	SocketPath  string
	DemoMode    bool
	InstallMode string // "prod" | "dev"
}

// SeedData mantiene compatibilidad con llamadas existentes a New().
// Internamente el wizard usa LoadEnvSeed() + TenantSchema/AdminSchema.
// Deprecated: usar LoadEnvSeed() directamente; SeedData se eliminará en F3.18.
type SeedData struct {
	RazonSocial string
	NIT         string
	Pais        string
	Dominio     string
	Email       string
	Nombre      string
	Password    string
	MFA         bool
}

// ── Model ──────────────────────────────────────────────────────────────────

// Model es el modelo TEA del instalador bos.
// Fuente única del estado del TUI — un único CurrentScreen elimina P11.
//
// INVARIANTE TEA (corrige P3):
// Update() NUNCA tiene efectos secundarios. Solo devuelve (Model, tea.Cmd).
type Model struct {
	Config Config

	// ── Layout ────────────────────────────────────────────────────────────
	Width, Height int
	TermW         int
	BodyHeight    int
	CurrentScreen Screen // P11 — campo único para la pantalla activa
	ShowStepper   bool   // true en P1–P5
	ShowNavHint   bool   // true en P1–P4

	// ── Viewports ─────────────────────────────────────────────────────────
	BodyVP       viewport.Model // P1–P4, P6–P8, P11
	SectionVP    viewport.Model // P6 — 4 secciones
	VpDash       viewport.Model // P9 dashboard
	VpLog        viewport.Model // P10 logs
	VpA          viewport.Model // P5 colA — árbol fases
	VpB          viewport.Model // P5 colB — pasos del activo
	VpC          viewport.Model // P5 colC — log en vivo
	VpReady      bool
	VpAutoScroll bool // si true: colB+colC siguen el tail automáticamente

	// ── Wizard ────────────────────────────────────────────────────────────
	CompleteFocus int // 0=Tenant 1=Ubuntu 2=K8s 3=SBOS/bos

	// Valores de los formularios wizard huh (vinculados por puntero en wizard_forms.go)
	WizardP1Selection     int    // 0=Comenzar 1=Salir
	WizardP4Confirm       bool   // true=iniciar instalación, false=volver
	TenantName            string // BOS_TENANT_NAME
	TenantNIT             string // BOS_TENANT_NIT
	TenantPais            string // BOS_TENANT_PAIS
	TenantDomain          string // BOS_TENANT_DOMAIN
	AdminEmail            string // BOS_ROOT_USER
	AdminNombre           string // BOS_ADMIN_NOMBRE
	AdminPassword         string // BOS_ROOT_PASSWORD
	AdminPasswordConfirm  string // BOS_ROOT_PASSWORD_CONFIRM

	// Forms wizard huh v1.0.0 — inicializados en HandleUpdate al entrar a cada pantalla
	WizardP1Form *huh.Form
	WizardP2Form *huh.Form
	WizardP3Form *huh.Form
	WizardP4Form *huh.Form

	// Capacidad (P3B) — mantiene textinput (no migrado en Bloque 8)
	CapacityInputs []textinput.Model
	CapacityFields []EnvField
	CapacityFocus  int

	MFAEnabled bool
	ErrMsg     string

	// ── Boot / Shutdown ───────────────────────────────────────────────────
	BootPct      float64
	BootMsg      string
	BootLines    []string
	CountdownSec int
	ShutdownMode string
	ShutdownPct  float64
	ShutdownStep int

	// ── Dashboard / Logs ──────────────────────────────────────────────────
	DashUptime time.Duration
	DashLogs   []LogEntry
	LogFilter  LogLevel
	LogSource  string // "" = Todos; "bos","bkernel","bauth","bsearch","biedata","nexus"
	LogSearch  string

	// ── Estado de instalación ─────────────────────────────────────────────
	Spinner         spinner.Model
	ProgBar         progress.Model
	Phases          []InstallPhase
	Fichas          map[string]*FichaDetail
	Logs            []LogEntry
	FichasOK        int
	FichasTotal     int
	StartTime       time.Time
	SpinnerFrame int
	ViewMode        string // "normal" | "fulllog" | "error"
	ErrPanel        *FichaDetail
	ErrFocus        int // 0=Reintentar 1=Saltar 2=Log 3=Cancelar
	InstallingFocus int // 0=colA 1=colB 2=colC

	// ── Sistema ───────────────────────────────────────────────────────────
	Sys           SysInfo
	Installed     bool
	ShowTimestamp bool
	HelpModel     help.Model

	// ── WebSocket ─────────────────────────────────────────────────────────
	WsConn         *wslib.Conn
	WsCh           chan WsEventMsg
	NeedStatusSync bool
	PendingLogTail string // fichaID cuyo log histórico hay que pedir al daemon

	// Preflight
	PreflightCh       chan PreflightMsg
	PreflightWarnings []string

	// Dashboard ctrl
	Ctrl dash.DashModel

	// Autenticación — nivel de acceso del operador de la sesión TUI
	AuthLoA      int    // 0=anon, 1=pin, 2=password, 3=mfa (RFC 9470 LoA)
	AuthUsername string // usuario autenticado (vacío si anon)
	AuthToken    string // JWT efímero para la sesión TUI (emitido por bauth)
	AuthForm     *huh.Form // formulario activo en ScreenAuthLogin; nil hasta primera entrada
	AuthUser     string    // campo usuario vinculado a AuthForm (Value pointer)
	AuthPass     string    // campo contraseña vinculado a AuthForm (Value pointer)
	AuthErr      string    // mensaje de error de la última autenticación fallida

	// Step-up LoA 3 (ScreenAuthConfirm)
	AuthConfirmForm   *huh.Form    // formulario activo en ScreenAuthConfirm
	AuthConfirmOK     bool         // resultado del huh.NewConfirm() — true = confirmar
	AuthStepUpPass    string       // contraseña/PIN vinculado a AuthConfirmForm
	AuthConfirmAction string       // texto de la acción que requiere elevación LoA 3
	PendingDashAction dash.DashAction // acción del dashboard pendiente de confirmación LoA 3 (reboot/shutdown)

	// ── TUILog — logging de seguimiento interno del TUI ─────────────────────
	// Ring escribe en journald (bos-tui) y mantiene buffer circular en memoria.
	// Usar: m.TUILog.Info(tuilog.SrcWS, "conectado a bos.sock")
	// Ver:  journalctl -t bos-tui -f
	TUILog    *tuilog.Ring  // logger + buffer circular; inicializado en New()
	TUILogCh  chan struct{}  // canal de suscripción al Ring (para WatchCmd)

	// Entries recibidas del viewer de journalctl (daemons externos)
	// Poblado en Update() por tuilog.JournalEntryMsg
	JournalEntries []tuilog.Entry
	JournalCh      <-chan tuilog.Entry // canal del Follow() activo; nil si no hay viewer
	JournalCancel  func()             // cancela el Follow() activo

	// Ciclo de vida
	StopCh     chan struct{}
	DemoRunner func(ch chan WsEventMsg) // inyectado por app.New() en modo demo
}

// ── Constructores ──────────────────────────────────────────────────────────

// ti construye un textinput.Model con los estilos estándar del TUI.
func ti(ph, val string, pw, focus bool) textinput.Model {
	t := textinput.New()
	t.Placeholder = ph
	t.SetValue(val)
	t.CharLimit = 256
	t.PromptStyle = styles.Cyan
	t.TextStyle = styles.TableHeader
	t.PlaceholderStyle = styles.Dim
	t.Cursor.Style = styles.Cyan
	if pw {
		t.EchoMode = textinput.EchoPassword
		t.EchoCharacter = '•'
	}
	if focus {
		t.Focus()
	}
	return t
}

// New construye un Model con valores por defecto según cfg y seed.
// seed puede ser cero-value; si viene con datos del .env los pre-rellena.
func New(cfg Config, seed SeedData) *Model {
	if seed.Pais == "" {
		seed.Pais = "BO"
	}
	if !seed.MFA {
		seed.MFA = true
	}

	sp := spinner.New()
	sp.Spinner = spinner.Spinner{
		Frames: styles.SpinnerFrames,
		FPS:    time.Second / 3,
	}
	sp.Style = styles.Cyan

	pb := progress.New(
		progress.WithGradient(string(styles.ColorProgressFill), string(styles.ColorProgressTrack)),
		progress.WithoutPercentage(),
	)

	pais := seed.Pais
	if pais == "" {
		pais = "BO"
	}
	m := &Model{
		Config:        cfg,
		CurrentScreen: ScreenWelcome,
		ShowStepper:   false,
		ShowNavHint:   false,
		CountdownSec:  10,
		BootMsg:       "Iniciando sistema...",
		HelpModel:     newHelpModel(),
		ShutdownMode:  "shutdown",
		// Valores wizard (huh forms) pre-rellenados desde seed
		TenantName:           seed.RazonSocial,
		TenantNIT:            seed.NIT,
		TenantPais:           pais,
		TenantDomain:         seed.Dominio,
		AdminEmail:           seed.Email,
		AdminNombre:          seed.Nombre,
		AdminPassword:        seed.Password,
		AdminPasswordConfirm: seed.Password,
		MFAEnabled:           seed.MFA,
		// Capacidad (P3B) — sigue usando textinput
		CapacityInputs: buildInputs(CapacitySchema, nil),
		CapacityFields: CapacitySchema,
		Spinner:        sp,
		ProgBar:        pb,
		FichasTotal:    22,
		ViewMode:       "normal",
		WsCh:           make(chan WsEventMsg, 128),
		VpAutoScroll:   true,
		PreflightCh:    make(chan PreflightMsg, 4),
		StopCh:         make(chan struct{}),
		Ctrl:           ctrl.New(0, 0),
	}
	// MFA activo por defecto si no vino del seed
	if !seed.MFA {
		m.MFAEnabled = true
	}

	// Wizard forms — se crean lazily en HandleUpdate cuando m.Width ya es conocido.

	// TUILog: logger de seguimiento del TUI → journald (bos-tui) + buffer circular
	m.TUILog = tuilog.NewRing(512)
	m.TUILogCh = m.TUILog.Sub()
	m.TUILog.Info(tuilog.SrcTUI, "TUI iniciado — logging activo (journalctl -t bos-tui -f)")
	m.BodyVP = viewport.New(0, 0)
	m.SectionVP = viewport.New(0, 0)
	m.VpDash = viewport.New(0, 0)
	m.VpLog = viewport.New(0, 0)
	m.recalcBodyHeight()
	return m
}

// newHelpModel construye un help.Model con los estilos del tema SBOS activo.
func newHelpModel() help.Model {
	h := help.New()
	h.Styles = styles.HuhHelpStyles()
	return h
}

// ── TEA interface ──────────────────────────────────────────────────────────

// Init devuelve los comandos iniciales del TUI.
func (m *Model) Init() tea.Cmd {
	boslog.Init("bosctl")
	boslog.Info("bosctl setup iniciado", "installed", m.Installed, "preflight_needed", PreflightNeeded())
	m.TUILog.Info(tuilog.SrcTUI, "Init() — arrancando comandos iniciales")
	cmds := []tea.Cmd{
		m.Spinner.Tick,
		textinput.Blink,
		func() tea.Msg { return SysInfoMsg{Info: DetectSystemInfo()} },
		ConnectWS(m.WsCh, m.StopCh),
		tuilog.WatchCmd(m.TUILogCh), // observa nuevas entradas del Ring
	}
	if !m.Installed && PreflightNeeded() {
		cmds = append(cmds, StartPreflightCmd(m.PreflightCh))
	} else {
		cmds = append(cmds, TickCmd())
	}
	return tea.Batch(cmds...)
}

// ── Navegación ─────────────────────────────────────────────────────────────

// SetScreen cambia de pantalla actualizando showStepper, showNavHint y bodyHeight.
func (m *Model) SetScreen(s Screen) {
	if m.TUILog != nil {
		m.TUILog.Debug(tuilog.SrcUI, "pantalla → %s", s)
	}
	m.CurrentScreen = s
	m.ShowStepper = s >= ScreenWizardP1 && s <= ScreenInstalling
	m.ShowNavHint = s >= ScreenWizardP1 && s <= ScreenWizardP4
	m.recalcBodyHeight()
	m.BodyVP.Height = m.BodyHeight
}

// IsInstallingScreen retorna true para P5/P5B/P5C que tienen viewports propios.
func (m *Model) IsInstallingScreen() bool {
	return m.CurrentScreen == ScreenInstalling ||
		m.CurrentScreen == ScreenInstallLog ||
		m.CurrentScreen == ScreenInstallErr
}

// ── Acceso semántico a inputs ──────────────────────────────────────────────

// TenantValue retorna el valor del campo tenant identificado por envKey.
func (m *Model) TenantValue(envKey string) string {
	switch envKey {
	case "BOS_TENANT_NAME":
		return m.TenantName
	case "BOS_TENANT_NIT":
		return m.TenantNIT
	case "BOS_TENANT_PAIS":
		return m.TenantPais
	case "BOS_TENANT_DOMAIN":
		return m.TenantDomain
	}
	return ""
}

// AdminValue retorna el valor del campo admin identificado por envKey.
func (m *Model) AdminValue(envKey string) string {
	switch envKey {
	case "BOS_ROOT_USER":
		return m.AdminEmail
	case "BOS_ADMIN_NOMBRE":
		return m.AdminNombre
	case "BOS_ROOT_PASSWORD":
		return m.AdminPassword
	case "BOS_ROOT_PASSWORD_CONFIRM":
		return m.AdminPasswordConfirm
	}
	return ""
}

// ── Helpers de construcción ────────────────────────────────────────────────

// buildInputs construye un slice de textinput.Model desde un schema y un mapa de seed.
// Usado solo para CapacityInputs (P3B) — los inputs de tenant/admin migrados a huh en Bloque 8.
func buildInputs(schema []EnvField, seed map[string]string) []textinput.Model {
	inputs := make([]textinput.Model, len(schema))
	for i, f := range schema {
		inputs[i] = ti(f.Placeholder, SeedValue(seed, f.EnvKey), f.Secret, i == 0)
	}
	return inputs
}

// recalcBodyHeight calcula BodyHeight según las líneas fijas de top/bottom.
func (m *Model) recalcBodyHeight() {
	topH := 3
	if m.ShowStepper {
		topH++
	}
	botH := 1
	if m.ShowNavHint {
		botH++
	}
	m.BodyHeight = m.Height - topH - botH
	if m.BodyHeight < 1 {
		m.BodyHeight = 1
	}
}


func (m *Model) SpinnerView() string {
	f := styles.SpinnerFrames
	if len(f) == 0 { return "" }
	return styles.Cyan.Render(f[m.SpinnerFrame%len(f)])
}
