package main

// SBOS Install TUI v2 — Instalador detallado nivel OS (BubbleTea + Lipgloss)
//
// Layout principal durante la instalación (modo md ≥80 cols):
//
//  ┌─ SBOS ──────────────────────────────────────────────────────────────────┐
//  │ Fases y Fichas          │ Pasos del componente    │ Log en vivo          │
//  │─────────────────────────│─────────────────────────│──────────────────────│
//  │ ✓ N0 — OS Base          │ 📦 redis 8.6.2          │[14:32:01] Iniciando  │
//  │   ✓ sbos-bootstrap-os   │ Paso 3/5                │[14:32:15] Pulling... │
//  │ ✓ N1 — K8s + Calico     │ ✓ verify_pv      0:03s  │[14:32:16] Image OK   │
//  │ › N2 — Almacenamiento   │ ✓ deploy_sts     0:12s  │[14:32:47] WAL activo │
//  │   ✓ postgresql  4:21    │ › wait_ready ⟳  0:45s  │[14:32:49] ✅ pg OK   │
//  │   › redis        0:52   │ ○ configure              │[14:32:50] redis...   │
//  │   ○ minio               │ ○ verify_health           │                      │
//  │─────────────────────────│─────────────────────────│──────────────────────│
//  │ ████████████░░░  45%  ·  4/22 fichas  ·  8:23 transcurridos              │
//  └─────────────────────────────────────────────────────────────────────────┘
//
// Licencias (todas gratuitas MIT/BSD):
//   BubbleTea, Lipgloss, Bubbles — Charmbracelet MIT
//   gorilla/websocket — BSD-2-Clause

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/charmbracelet/bubbles/help"
	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/gorilla/websocket"
	"github.com/mattn/go-runewidth"
)

// ── Colores y Estilos ──────────────────────────────────────────────────────

const (
	cGreenS  = "#22c55e"
	cCyanS   = "#06b6d4"
	cYellowS = "#f59e0b"
	cRedS    = "#ef4444"
	cDimS    = "#6b7280"
	cBlackS  = "#0f172a"
	cWhiteS  = "#f1f5f9"
	cSlateS  = "#334155"
	cMutedS  = "#475569"
	cBg2S    = "#0c1525"
	cBg3S    = "#1e293b"
)

var (
	cGreen  = lipgloss.Color(cGreenS)
	cCyan   = lipgloss.Color(cCyanS)
	cYellow = lipgloss.Color(cYellowS)
	cRed    = lipgloss.Color(cRedS)
	cDim    = lipgloss.Color(cDimS)
	cBlack  = lipgloss.Color(cBlackS)
	cWhite  = lipgloss.Color(cWhiteS)
	cSlate  = lipgloss.Color(cSlateS)
	cMuted  = lipgloss.Color(cMutedS)
	cBg2    = lipgloss.Color(cBg2S)
	cBg3    = lipgloss.Color(cBg3S)
)

var (
	sBold   = lipgloss.NewStyle().Bold(true)
	sDim    = lipgloss.NewStyle().Foreground(cDim)
	sGreen  = lipgloss.NewStyle().Foreground(cGreen)
	sCyan   = lipgloss.NewStyle().Foreground(cCyan)
	sRed    = lipgloss.NewStyle().Foreground(cRed).Bold(true)
	sYellow = lipgloss.NewStyle().Foreground(cYellow)
	sMuted  = lipgloss.NewStyle().Foreground(cMuted)
	sWhite  = lipgloss.NewStyle().Foreground(cWhite)

	sTopBar = lipgloss.NewStyle().
		Background(lipgloss.Color("#134e23")).
		Foreground(cGreen).
		Bold(true).
		Padding(0, 1)

	sTitle = lipgloss.NewStyle().
		Foreground(lipgloss.Color("#94a3b8")).
		Align(lipgloss.Center)

	sFooter = lipgloss.NewStyle().
		Background(cBg2).
		Foreground(cMuted).
		Padding(0, 1)

	sBox = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(cSlate).
		Padding(0, 1)

	sBoxActive = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(cCyan).
		Padding(0, 1)

	sPanelDiv = lipgloss.NewStyle().
		BorderLeft(true).
		BorderStyle(lipgloss.NormalBorder()).
		BorderForeground(cSlate).
		PaddingLeft(2)

	sHelpBox = lipgloss.NewStyle().
		BorderLeft(true).
		BorderStyle(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("#1e3a5f")).
		PaddingLeft(2).
		Foreground(cMuted)

	sErrBox = lipgloss.NewStyle().
		Border(lipgloss.ThickBorder()).
		BorderForeground(cRed).
		Padding(0, 1).
		Margin(1)

	sInputInactive = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(cSlate).
		Background(cBlack).
		Padding(0)

	sInputActive = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(cCyan).
		Background(cBlack).
		Padding(0)

	sStepOK      = lipgloss.NewStyle().Foreground(cGreen)
	sStepActive  = lipgloss.NewStyle().Foreground(cYellow)
	sStepPending = lipgloss.NewStyle().Foreground(cDim)
	sStepFail    = lipgloss.NewStyle().Foreground(cRed).Bold(true)

	sLabel  = lipgloss.NewStyle().Foreground(cDim).Width(22)
	sLabelA = lipgloss.NewStyle().Foreground(cCyan).Bold(true).Width(22)
)

// ── Iconos con colores explícitos ──────────────────────────────────────────

func icOk() string   { return lipgloss.NewStyle().Foreground(cGreen).Render("✓") }
func icRun() string  { return lipgloss.NewStyle().Foreground(cCyan).Render("›") }
func icPend() string { return lipgloss.NewStyle().Foreground(cSlate).Render("○") }
func icErr() string  { return lipgloss.NewStyle().Foreground(cRed).Render("✗") }
func icWarn() string { return lipgloss.NewStyle().Foreground(cYellow).Render("⚠") }
func icBos() string  { return lipgloss.NewStyle().Foreground(cCyan).Render("⬡") }

// badge renderiza un chip coloreado para el resumen de instalación (P1).
func badge(text string, fg, bg lipgloss.Color) string {
	return lipgloss.NewStyle().
		Foreground(fg).
		Background(bg).
		Padding(0, 1).
		MarginRight(1).
		Render(text)
}

// renderMFARow renderiza la fila toggle de MFA como una sola línea, igual que los textinputs.
func renderMFARow(enabled bool, focused bool) string {
	prompt := lipgloss.NewStyle().Foreground(cCyan).Render("> ")
	var state string
	if enabled {
		state = lipgloss.NewStyle().Foreground(cGreen).Render("✓  Sí — Push MFA (sbos-notifier)")
	} else {
		state = lipgloss.NewStyle().Foreground(cSlate).Render("○  No — sin segundo factor")
	}
	return prompt + state
}

// ── Tipos de estado ────────────────────────────────────────────────────────

type stepStatus int

const (
	sPending stepStatus = iota
	sActive
	sDone
	sFailed
	sSkipped
)

type fichaStatus int

const (
	fPending fichaStatus = iota
	fActive
	fDone
	fFailed
)

// ── Datos por componente (ficha) ───────────────────────────────────────────

type stepDetail struct {
	name      string
	status    stepStatus
	startTime time.Time
	duration  time.Duration
	msg       string
	errMsg    string
}

type fichaDetail struct {
	id        string
	status    fichaStatus
	steps     []stepDetail
	startTime time.Time
	duration  time.Duration
	errMsg    string
}

func (f *fichaDetail) activeStep() *stepDetail {
	for i := range f.steps {
		if f.steps[i].status == sActive {
			return &f.steps[i]
		}
	}
	return nil
}

func (f *fichaDetail) countDone() int {
	n := 0
	for _, s := range f.steps {
		if s.status == sDone {
			n++
		}
	}
	return n
}

// ── Fases del DAG (manual SBOS-BOOTSTRAP-MANUAL.md Parte III) ─────────────

type installPhase struct {
	nombre string
	fichas []string
}

func defaultPhases() []installPhase {
	return []installPhase{
		{"N0 — Sistema Operativo", []string{"sbos-bootstrap-os"}},
		{"N1 — Kubernetes + Calico", []string{"sbos-bootstrap-k8s", "sbos-bootstrap-cni"}},
		{"N2 — Almacenamiento", []string{"postgresql", "redis", "minio", "sbos-bootstrap-storage"}},
		{"N3 — Seguridad Base", []string{"vault", "keycloak"}},
		{"N4 — Gateway + Mesh", []string{"oauth2-proxy", "kong", "nginx", "kyverno", "linkerd"}},
		{"N5 — Observabilidad", []string{"sbos-notifier", "prometheus", "grafana", "alertmanager", "alloy", "sbos-bootstrap-monitoring"}},
		{"N6 — Hardening Final", []string{"sbos-bootstrap-hard", "certbot"}},
	}
}

var fichaPhaseMap = map[string]int{
	"sbos-bootstrap-os": 0,
	"sbos-bootstrap-k8s": 1, "sbos-bootstrap-cni": 1,
	"postgresql": 2, "redis": 2, "minio": 2, "sbos-bootstrap-storage": 2,
	"vault": 3, "keycloak": 3,
	"oauth2-proxy": 4, "kong": 4, "nginx": 4, "kyverno": 4, "linkerd": 4,
	"sbos-notifier": 5, "prometheus": 5, "grafana": 5, "alertmanager": 5,
	"alloy": 5, "sbos-bootstrap-monitoring": 5,
	"sbos-bootstrap-hard": 6, "certbot": 6,
}

// versiones de visualización de cada componente
var fichaVersions = map[string]string{
	"postgresql": "18.4", "redis": "8.6.2", "minio": "RELEASE.2025-05-24",
	"vault": "2.0.1", "keycloak": "26.6.2", "kong": "3.9.0",
	"nginx": "1.27", "certbot": "2.11", "linkerd": "2.16.0",
	"kyverno": "1.13.0", "prometheus": "3.4.0", "grafana": "12.0.1",
	"alertmanager": "0.28.1", "alloy": "1.8.3",
}

// ── Log con timestamp ──────────────────────────────────────────────────────

type logLevel int

const (
	logInfo logLevel = iota
	logOK
	logStep
	logError
	logWarn
)

type logEntry struct {
	ts    time.Time
	level logLevel
	ficha string
	step  string // paso activo cuando se emitió la línea
	msg   string
}

// scriptTag detecta prefijos de nivel bash "[INFO]", "[WARN]", etc. en el mensaje.
// Retorna (tag, resto, colorTag, colorMsg) si encuentra coincidencia.
// Usado por colorMsg para colorear la salida cruda de los task_catalog.sh.
func scriptTag(msg string) (tag, rest, cTag, cMsg string, found bool) {
	type entry struct{ tag, cTag, cMsg string }
	levels := []entry{
		{"[OK]",      "#22c55e", "#22c55e"},
		{"[SUCCESS]", "#22c55e", "#22c55e"},
		{"[INFO]",    "#38bdf8", "#94a3b8"},
		{"[DEBUG]",   "#475569", "#64748b"},
		{"[STEP]",    "#94a3b8", "#94a3b8"},
		{"[WARN]",    "#f59e0b", "#f59e0b"},
		{"[WARNING]", "#f59e0b", "#f59e0b"},
		{"[ERROR]",   "#ef4444", "#ef4444"},
		{"[ERR]",     "#ef4444", "#ef4444"},
		{"[FAIL]",    "#ef4444", "#ef4444"},
	}
	for _, lv := range levels {
		if strings.HasPrefix(msg, lv.tag) {
			rest = strings.TrimPrefix(msg, lv.tag)
			if len(rest) > 0 && rest[0] == ' ' {
				rest = rest[1:]
			}
			return lv.tag, rest, lv.cTag, lv.cMsg, true
		}
	}
	return "", msg, "", "", false
}

// colorMsg aplica color según nivel del logEntry.
// Para logStep (salida de scripts bash): detecta [INFO]/[WARN]/[ERROR] y los colorea.
func (e logEntry) colorMsg() string {
	sOK   := lipgloss.NewStyle().Foreground(lipgloss.Color("#22c55e"))
	sErr  := lipgloss.NewStyle().Foreground(lipgloss.Color("#ef4444"))
	sWarn := lipgloss.NewStyle().Foreground(lipgloss.Color("#f59e0b"))
	sDim  := lipgloss.NewStyle().Foreground(lipgloss.Color("#64748b"))
	sMut  := lipgloss.NewStyle().Foreground(lipgloss.Color("#94a3b8"))

	switch e.level {
	case logOK:
		return sOK.Render(e.msg)
	case logError:
		return sErr.Render(e.msg)
	case logWarn:
		return sWarn.Render(e.msg)
	case logStep:
		// Salida cruda de bash: detectar [LEVEL] y colorear tag + resto
		if tag, rest, cTag, cMsg, ok := scriptTag(e.msg); ok {
			tagS := lipgloss.NewStyle().Foreground(lipgloss.Color(cTag)).Bold(true).Render(tag)
			msgS := lipgloss.NewStyle().Foreground(lipgloss.Color(cMsg)).Render(" " + rest)
			return tagS + msgS
		}
		return sMut.Render(e.msg)
	default: // logInfo
		return sDim.Render(e.msg)
	}
}

// truncByWidth recorta s hasta que su ancho de display (runas anchas = 2 cols) <= maxW.
// Necesario para emoji SMP (📦, 🚀, ✅) que tienen runewidth=2.
func truncByWidth(s string, maxW int) string {
	w := 0
	for i, r := range s {
		rw := runewidth.RuneWidth(r)
		if w+rw > maxW {
			return s[:i]
		}
		w += rw
	}
	return s
}

// render devuelve la línea con timestamp [HH:MM:SS] + prefijo de nivel + mensaje.
// Trunca por ancho de display (respeta emoji de 2 cols) para evitar corte al borde del viewport.
func (e logEntry) render(width int) string {
	const tsW = 11 // "[HH:MM:SS] " = 11 columnas de display
	const pfxW = 2 // prefijo de nivel siempre 2 chars (pfxOK, pfxErr, etc.)
	ts := lipgloss.NewStyle().Foreground(lipgloss.Color("#334155")).Render("[" + e.ts.Format("15:04:05") + "] ")
	if width > 0 {
		maxMsgW := width - tsW - pfxW - 1 // -1 para "…"
		if maxMsgW > 0 && runewidth.StringWidth(e.msg) > maxMsgW {
			e.msg = truncByWidth(e.msg, maxMsgW) + "…"
		}
	}
	return ts + e.colorMsg()
}

// renderNoTS devuelve la línea sin timestamp — usado cuando m.showTimestamp=false en panel C.
// Trunca por ancho de display cuando se especifica width > 0.
func (e logEntry) renderNoTS(width ...int) string {
	const pfxW = 2
	if len(width) > 0 && width[0] > 0 {
		maxMsgW := width[0] - pfxW - 1 // -1 para "…"
		if maxMsgW > 0 && runewidth.StringWidth(e.msg) > maxMsgW {
			e.msg = truncByWidth(e.msg, maxMsgW) + "…"
		}
	}
	return e.colorMsg()
}

// ── Pantallas ──────────────────────────────────────────────────────────────

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

// Alias para compatibilidad con código existente
type stepID = Screen

const (
	stepWelcome    = ScreenWizardP1
	stepTenant     = ScreenWizardP2
	stepAdmin      = ScreenWizardP3
	stepConfirm    = ScreenWizardP4
	stepInstalling = ScreenInstalling
	stepComplete   = ScreenInstallDone
)

// ── Mensajes tea ──────────────────────────────────────────────────────────

type wsEventMsg struct {
	evType    string
	ficha     string
	step      string
	msg       string
	total     int
	errDetail string
	data      map[string]interface{}
}
type wsReadyMsg struct{ conn *websocket.Conn }
type wsErrorMsg struct{ err error }
type sysInfoMsg struct{ info sysInfo }

// ── Modelo ─────────────────────────────────────────────────────────────────

type model struct {
	width, height int    // ancho/alto efectivos del contenido (sin márgenes)
	termW         int    // ancho real del terminal (para calcular MarginLeft)
	step          Screen // pantalla actual

	// Pantallas nuevas
	screen       Screen
	// Layout responsivo
	bodyHeight  int            // líneas disponibles para el body (excluye top/bottom fijos)
	bodyVP      viewport.Model // viewport global para P1–P4, P6–P8, P11
	sectionVP   viewport.Model // viewport para las 4 secciones de P6
	showStepper bool           // true en P1–P5 (stepper del wizard)
	showNavHint bool           // true en P1–P4 (navHint en footer)
	installed    bool
	showTimestamp bool
	bootPct      float64
	bootMsg      string
	bootLines    []string
	countdownSec int
	dashUptime   time.Duration
	dashLogs     []logEntry
	vpDash       viewport.Model
	logFilter    logLevel
	logSource    string // "" = Todos; "bos","bkernel","bauth","bsearch","biedata","nexus"
	logSearch    string
	vpLog        viewport.Model
	shutdownMode string
	shutdownPct  float64
	shutdownStep int
	helpModel    help.Model
	completeFocus int // 0=Tenant 1=Ubuntu 2=K8s 3=SBOS/bos

	// Datos del sistema
	sys sysInfo

	// Formularios
	tenantInputs [4]textinput.Model
	tenantFocus  int
	adminInputs  [4]textinput.Model
	adminFocus   int
	mfaEnabled   bool

	// Navegación de pantallas con botones (Welcome y Confirm)
	welcomeFocus int // 0=Comenzar, 1=Salir
	confirmFocus int // 0=Instalar, 1=Automático, 2=Volver

	// Estado de instalación
	spinner    spinner.Model
	progBar    progress.Model
	phases     []installPhase
	fichas     map[string]*fichaDetail // estado de cada ficha
	logs       []logEntry
	fichasOK   int
	fichasTotal int
	startTime  time.Time

	// Vista actual de la pantalla de instalación
	viewMode   string // "normal" | "fulllog" | "error"
	errPanel   *fichaDetail
	errFocus   int // foco en menú lateral de P5C (0=Reintentar 1=Saltar 2=Log 3=Cancelar)

	// Viewports de las 3 columnas en modo MD (instalación)
	// ColA = árbol fases/fichas, ColB = pasos del activo, ColC = log en vivo
	vpA, vpB, vpC   viewport.Model
	vpReady         bool
	installingFocus int  // 0=colA 1=colB 2=colC
	vpAutoScroll    bool // si true, colB y colC siguen el tail automáticamente

	// WS
	wsConn *websocket.Conn
	wsCh            chan wsEventMsg
	needStatusSync  bool
	pendingLogTail  string // fichaID cuyo log histórico hay que pedir al daemon

	// Errores de formulario
	errMsg string
}

// ── Helpers de form ────────────────────────────────────────────────────────

func mkInput(placeholder, value string, pw, focus bool) textinput.Model {
	ti := textinput.New()
	ti.Placeholder = placeholder
	ti.SetValue(value)
	ti.CharLimit = 256
	ti.PromptStyle = lipgloss.NewStyle().Foreground(cCyan)
	ti.TextStyle = lipgloss.NewStyle().Foreground(cWhite)
	ti.PlaceholderStyle = lipgloss.NewStyle().Foreground(cDim)
	ti.Cursor.Style = lipgloss.NewStyle().Foreground(cCyan)
	if pw {
		ti.EchoMode = textinput.EchoPassword
		ti.EchoCharacter = '•'
	}
	if focus {
		ti.Focus()
	}
	return ti
}

// ── Layout responsivo ─────────────────────────────────────────────────────

// recalcBodyHeight calcula m.bodyHeight según las líneas fijas de top/bottom.
// topH: topbar(1)+stepper?(1)+title(1)+sep(1) → 4 con stepper, 3 sin
// botH: footer(1) + navHint?(1)
func (m *model) recalcBodyHeight() {
	topH := 3 // base: topbar + title + sep (sin stepper)
	if m.showStepper {
		topH++ // +1 para el stepper del wizard
	}
	botH := 1 // footer — 1 línea
	if m.showNavHint {
		botH++ // navHint — opcional, solo en P1–P4
	}
	m.bodyHeight = m.height - topH - botH
	if m.bodyHeight < 1 {
		m.bodyHeight = 1
	}
}

// isInstallingScreen retorna true para P5/P5B/P5C que tienen sus propios viewports.
func (m model) isInstallingScreen() bool {
	return m.screen == ScreenInstalling ||
		m.screen == ScreenInstallLog ||
		m.screen == ScreenInstallErr
}

// setScreen cambia de pantalla actualizando showStepper, showNavHint, bodyHeight
// y el contenido del viewport con el centrado vertical correcto.
func (m *model) setScreen(s Screen) {
	m.screen = s
	m.showStepper = (s >= ScreenWizardP1 && s <= ScreenInstalling)
	m.showNavHint = (s >= ScreenWizardP1 && s <= ScreenWizardP4)
	m.recalcBodyHeight()
	m.bodyVP.Height = m.bodyHeight
	m.bodyVP.SetContent(m.bodyContent())
	m.bodyVP.GotoTop()
}

// ── Pre-carga desde bos-bootstrap.env ─────────────────────────────────────

type seedData struct {
	RazonSocial string `json:"razon_social"`
	NIT         string `json:"nit"`
	Pais        string `json:"pais"`
	Dominio     string `json:"dominio"`
	Email       string `json:"email"`
	Nombre      string `json:"nombre"`
	Password    string `json:"password"`
	MFA         bool   `json:"mfa"`
}

func loadEnvSeed() seedData {
	s := seedData{Pais: "BO", MFA: true}
	for _, p := range []string{
		"/etc/bos/bos-bootstrap.env", "/etc/bos/core/bos-bootstrap.env",
		"/opt/bos/bos-bootstrap.env", "/tmp/bos-bootstrap.env", "./bos-bootstrap.env",
	} {
		data, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		for _, line := range strings.Split(string(data), "\n") {
			line = strings.TrimSpace(line)
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			kv := strings.SplitN(line, "=", 2)
			if len(kv) != 2 {
				continue
			}
			k := strings.TrimSpace(kv[0])
			v := strings.Trim(strings.TrimSpace(kv[1]), "\"'")
			switch k {
			case "BOS_TENANT_NAME":
				s.RazonSocial = v
			case "BOS_TENANT_NIT":
				s.NIT = v
			case "BOS_TENANT_PAIS":
				s.Pais = v
			case "BOS_TENANT_DOMAIN":
				s.Dominio = v
			case "BOS_ROOT_USER":
				if strings.Contains(v, "@") {
					s.Email = v
				}
			case "BOS_ADMIN_NOMBRE":
				s.Nombre = v
			case "BOS_ROOT_PASSWORD":
				s.Password = v
			case "BOS_MFA_ENABLED":
				s.MFA = v == "true" || v == "1"
			}
		}
		break
	}
	return s
}

func buildSlug(s string) string {
	s = strings.ToLower(s)
	rep := map[rune]rune{
		'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
		'ñ': 'n', 'ü': 'u', ' ': '-',
	}
	var b strings.Builder
	for _, r := range s {
		if rr, ok := rep[r]; ok {
			b.WriteRune(rr)
		} else if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' {
			b.WriteRune(r)
		}
	}
	return strings.Trim(b.String(), "-")
}

// ── Tick y animaciones ─────────────────────────────────────────────────────

type tickMsg time.Time

func tickCmd() tea.Cmd {
	return tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func bootMessage(pct float64) string {
	msgs := []struct {
		threshold float64
		msg       string
	}{
		{0.12, "Verificando integridad de componentes..."},
		{0.25, "Cargando configuración del tenant..."},
		{0.38, "Verificando Ubuntu — kernel OK"},
		{0.52, "Verificando Kubernetes — cluster OK"},
		{0.65, "Iniciando daemons SBOS..."},
		{0.78, "Activando Context Plane..."},
		{0.90, "Registrando ctx_id de sesión..."},
		{1.01, "Sistema listo ✓"},
	}
	for _, m := range msgs {
		if pct < m.threshold {
			return m.msg
		}
	}
	return "Sistema listo ✓"
}

func isInstalled() bool {
	_, err := os.Stat("/etc/sbos/tenant.conf")
	return err == nil
}

// ── Inicialización ─────────────────────────────────────────────────────────

func initialModel() model {
	seed := loadEnvSeed()

	sp := spinner.New()
	sp.Spinner = spinner.Spinner{
		Frames: []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"},
		FPS:    time.Second / 10,
	}
	sp.Style = lipgloss.NewStyle().Foreground(cYellow)

	pb := progress.New(
		progress.WithGradient("#22c55e", "#06b6d4"),
		progress.WithoutPercentage(),
	)

	// Inicializar mapa de fichas
	fichasMap := make(map[string]*fichaDetail)
	for _, ph := range defaultPhases() {
		for _, fid := range ph.fichas {
			fichasMap[fid] = &fichaDetail{id: fid, status: fPending}
		}
	}

	m := model{
		step:         ScreenWelcome,
		screen:       ScreenWelcome,
		showStepper:  false, // WELCOME es splash, sin stepper
		showNavHint:  false,
		installed:    isInstalled(),
		countdownSec: 10,
		bootMsg:      "Iniciando sistema...",
		helpModel:    help.New(),
		shutdownMode: "shutdown",
		// Placeholder muestra SOLO lo que se espera, no datos de ejemplo.
		// Si seed tiene valor real (del .env), SetValue lo muestra en blanco.
		tenantInputs: [4]textinput.Model{
			mkInput("(requerido)", seed.RazonSocial, false, true),
			mkInput("(requerido)", seed.NIT, false, false),
			mkInput("BO  AR  MX  (requerido)", seed.Pais, false, false),
			mkInput("(se genera automáticamente si lo deja vacío)", seed.Dominio, false, false),
		},
		adminInputs: [4]textinput.Model{
			mkInput("usuario@dominio.com  (requerido)", seed.Email, false, false),
			mkInput("(requerido)", seed.Nombre, false, false),
			mkInput("mínimo 8 caracteres", seed.Password, true, false),
			mkInput("repetir contraseña", seed.Password, true, false),
		},
		mfaEnabled:  seed.MFA,
		spinner:     sp,
		progBar:     pb,
		phases:      defaultPhases(),
		fichas:      fichasMap,
		fichasTotal:  22,
		viewMode:     "normal",
		wsCh:         make(chan wsEventMsg, 128),
		vpAutoScroll: true,
	}
	m.bodyVP    = viewport.New(0, 0)
	m.sectionVP = viewport.New(0, 0)
	m.vpDash    = viewport.New(0, 0)
	m.vpLog     = viewport.New(0, 0)
	m.recalcBodyHeight()
	return m
}

// ── Init ───────────────────────────────────────────────────────────────────

func (m model) Init() tea.Cmd {
	return tea.Batch(
		textinput.Blink,
		m.spinner.Tick,
		tickCmd(),
		func() tea.Msg { return sysInfoMsg{info: detectSystemInfo()} },
		connectWS(m.wsCh),
	)
}

// stopCh es el canal de parada de la goroutine WS. Se cierra cuando BubbleTea termina.
var stopCh = make(chan struct{})

// demoMode activa la simulación de instalación sin daemon ni comandos reales.
var demoMode bool

// ensureDaemonRunning arranca el daemon bos si el socket no existe todavía.
// Busca el binario en: mismo directorio que bosctl, rutas canónicas, PATH.
// El daemon usa /etc/bos/bos.toml y rutas por defecto (/run/bos/bos.sock, etc.).
// Espera hasta 15s a que el socket aparezca tras el arranque.
func ensureDaemonRunning(socketPath string) error {
	// Si el socket ya existe, el daemon está corriendo
	if _, err := os.Stat(socketPath); err == nil {
		return nil
	}

	// Buscar el binario del daemon en orden de preferencia
	candidates := []string{}
	if exe, err := os.Executable(); err == nil {
		candidates = append(candidates, filepath.Join(filepath.Dir(exe), "bos"))
	}
	candidates = append(candidates,
		"/opt/bos/bin/bos",
		"/usr/local/bin/bos",
		"/usr/bin/bos",
	)
	if p, err := exec.LookPath("bos"); err == nil {
		candidates = append(candidates, p)
	}

	var daemonBin string
	for _, c := range candidates {
		if info, err := os.Stat(c); err == nil && !info.IsDir() {
			daemonBin = c
			break
		}
	}
	if daemonBin == "" {
		return fmt.Errorf("daemon 'bos' no encontrado\n" +
			"  Instalar en /usr/local/bin/bos antes de ejecutar bosctl setup\n" +
			"  Rutas buscadas: " + strings.Join(candidates, ", "))
	}

	// Si el puerto 9443 (BOS API) está ocupado, hay un daemon anterior — matarlo.
	if out, err := exec.Command("sh", "-c",
		"ss -tlnp 2>/dev/null | grep ':9443 ' | awk '{print $NF}' | grep -oP 'pid=\\K[0-9]+'").Output(); err == nil {
		if pid := strings.TrimSpace(string(out)); pid != "" {
			if kCmd := exec.Command("kill", "-9", pid); kCmd.Run() == nil {
				time.Sleep(500 * time.Millisecond)
			}
		}
	}

	// Crear directorios canónicos (normalmente los crea autoBootstrap, pero lo saltamos)
	for _, d := range []string{
		filepath.Dir(socketPath),
		"/var/log/bos",
		"/etc/bos",
		"/etc/bos/blibs",
		"/etc/bos/.kube",
		"/opt/bos/core",
		"/opt/bos/bin",
		"/run/bos",
	} {
		_ = os.MkdirAll(d, 0755)
	}

	// Si bos-install.toml no existe, crearlo con los campos mínimos requeridos.
	// org_name y client_domain son obligatorios por la validación del daemon.
	// El TUI actualizará estos valores cuando el usuario llene el formulario.
	installToml := "/etc/bos/bos-install.toml"
	if _, err := os.Stat(installToml); os.IsNotExist(err) {
		const minimalToml = "# bos-install.toml — generado por bosctl setup (completar con datos reales)\n" +
			"org_name        = \"SBOS-Setup\"\n" +
			"client_domain   = \"setup.local\"\n" +
			"channel         = \"stable\"\n" +
			"servers_path    = \"/etc/bos/blibs/servers\"\n" +
			"core_path       = \"/opt/bos/core\"\n" +
			"state_file      = \"/etc/bos/.sbos_state.json\"\n" +
			"unix_socket     = \"/run/bos/bos.sock\"\n" +
			"kubeconfig_path = \"/etc/bos/.kube/config\"\n"
		_ = os.WriteFile(installToml, []byte(minimalToml), 0644)
	}

	// Arrancar el daemon con BOS_DEV_SKIP_ROOT=1 para evitar que autoBootstrap
	// cambie la contraseña root u opere como root antes de la instalación real.
	// El autoBootstrap completo corre durante el bootstrap real (bosctl bootstrap start).
	cmd := exec.Command(daemonBin)
	cmd.Stdin = nil
	cmd.Stdout = nil
	cmd.Stderr = nil
	cmd.Env = append(os.Environ(), "BOS_DEV_SKIP_ROOT=1")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("no se pudo arrancar el daemon bos (%s): %w", daemonBin, err)
	}

	// Esperar a que el socket aparezca (máx 15s, polling cada 500ms)
	for i := 0; i < 30; i++ {
		time.Sleep(500 * time.Millisecond)
		if _, err := os.Stat(socketPath); err == nil {
			return nil
		}
	}
	return fmt.Errorf("daemon bos arrancó (pid %d) pero socket %s no apareció en 15s",
		cmd.Process.Pid, socketPath)
}

func connectWS(ch chan wsEventMsg) tea.Cmd {
	return func() tea.Msg {
		socketPath := os.Getenv("BOS_SOCKET")
		if socketPath == "" {
			socketPath = defaultSocket
		}

		// Auto-arrancar el daemon si no está corriendo
		if err := ensureDaemonRunning(socketPath); err != nil {
			return wsErrorMsg{err: err}
		}

		dialer := websocket.Dialer{
			NetDialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
				var d net.Dialer
				return d.DialContext(ctx, "unix", socketPath)
			},
			HandshakeTimeout: 3 * time.Second,
		}
		conn, _, err := dialer.DialContext(context.Background(), "ws://unix/ws", nil)
		if err != nil {
			return wsErrorMsg{err: err}
		}

		// Cuando el TUI termina (stopCh se cierra), cerrar la conexión para
		// desbloquear ReadMessage. Goroutine de limpieza independiente.
		go func() {
			<-stopCh
			conn.Close()
		}()

		// Goroutine lectora de eventos WS.
		// Regla crítica de gorilla/websocket: tras cualquier error en ReadMessage
		// NO se puede volver a llamar ReadMessage — la conexión queda inválida
		// y gorilla panea con "repeated read on failed websocket connection".
		// Por eso: un solo error → return inmediato, sin reintentos.
		go func() {
			defer func() {
				// recover() atrapa panics residuales de gorilla si la conexión
				// ya estaba en estado fallido antes de que pudiéramos salir.
				recover() //nolint:errcheck
			}()

			for {
				_, raw, err := conn.ReadMessage()
				if err != nil {
					// Cualquier error — incluyendo EOF, close frame, net error —
					// significa que la conexión ya no es usable. Salir sin reintentar.
					return
				}

				var ev map[string]interface{}
				if json.Unmarshal(raw, &ev) != nil {
					continue
				}
				evType, _ := ev["type"].(string)
				ficha, _ := ev["ficha"].(string)
				step, _ := ev["step"].(string)
				msg, _ := ev["message"].(string)
				errDetail, _ := ev["error"].(string)
				var total int
				var evData map[string]interface{}
				if d, ok := ev["data"].(map[string]interface{}); ok {
					evData = d
					if t, ok := d["fichas_total"].(float64); ok {
						total = int(t)
					}
				}
				// bootstrap_status: la respuesta llega como type="response" con data.fichas (array)
				if evType == "response" {
					if d, ok := ev["data"].(map[string]interface{}); ok {
						if _, hasFichas := d["fichas"]; hasFichas {
							evType = "bootstrap_status"
							evData = d
						}
					}
				}
				select {
				case ch <- wsEventMsg{
					evType: evType, ficha: ficha, step: step,
					msg: msg, total: total, errDetail: errDetail, data: evData,
				}:
				case <-stopCh:
					return
				}
			}
		}()

		return wsReadyMsg{conn: conn}
	}
}

func awaitWS(ch chan wsEventMsg) tea.Cmd {
	// Bloquea hasta el próximo evento WS o hasta que stopCh se cierre.
	return func() tea.Msg {
		select {
		case msg := <-ch:
			return msg
		case <-stopCh:
			return nil // TUI terminó — no hacer nada
		}
	}
}

func sendWS(conn *websocket.Conn, action string, params map[string]interface{}) tea.Cmd {
	return func() tea.Msg {
		if conn == nil {
			return nil
		}
		_ = conn.WriteJSON(map[string]interface{}{
			"type": "request", "id": fmt.Sprintf("tui-%d", time.Now().UnixNano()),
			"action": action, "params": params,
		})
		return nil
	}
}

// ── Update ─────────────────────────────────────────────────────────────────

// navKey devuelve true para teclas de navegación que NO deben ir al textinput.
// Tab/Enter/Esc/Flechas son navegación; letras, números y símbolos son escritura.
func navKey(msg tea.KeyMsg) bool {
	switch msg.Type {
	case tea.KeyEnter, tea.KeyEsc, tea.KeyTab, tea.KeyShiftTab,
		tea.KeyUp, tea.KeyDown, tea.KeyCtrlC, tea.KeyCtrlD:
		return true
	}
	return false
}

// updateFocused envía un mensaje SOLO al input con foco activo.
// Receptor por puntero para que los cambios persistan en el modelo.
func (m *model) updateFocused(msg tea.Msg) tea.Cmd {
	switch m.screen {
	case ScreenWizardP2:
		var c tea.Cmd
		m.tenantInputs[m.tenantFocus], c = m.tenantInputs[m.tenantFocus].Update(msg)
		return c
	case ScreenWizardP3:
		if m.adminFocus < 4 { // foco 4 = fila MFA, no es un textinput
			var c tea.Cmd
			m.adminInputs[m.adminFocus], c = m.adminInputs[m.adminFocus].Update(msg)
			return c
		}
	}
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {

	case tickMsg:
		// P7: cuenta regresiva
		if m.screen == ScreenReboot {
			if m.countdownSec > 0 {
				m.countdownSec--
			}
			if m.countdownSec == 0 {
				m.setScreen(ScreenBoot)
				m.step = ScreenBoot
				m.bootPct = 0
				m.bootMsg = "Iniciando sistema..."
			}
			return m, tickCmd()
		}
		// P8: progreso de arranque
		if m.screen == ScreenBoot {
			if m.bootPct < 1.0 {
				m.bootPct += 0.025
				m.bootMsg = bootMessage(m.bootPct)
			}
			if m.bootPct >= 1.0 {
				m.bootPct = 1.0
				m.setScreen(ScreenDashboard)
				m.step = ScreenDashboard
			}
			return m, tickCmd()
		}
		// P11: progreso de apagado
		if m.screen == ScreenShutdown {
			if m.shutdownPct < 1.0 {
				m.shutdownPct += 0.02
			}
			if m.shutdownPct >= 1.0 {
				m.shutdownPct = 1.0
				if m.shutdownMode == "restart" {
					m.setScreen(ScreenBoot)
					m.step = ScreenBoot
					m.bootPct = 0
					m.bootMsg = "Reiniciando sistema..."
				} else {
					m.setScreen(ScreenGoodbye)
					m.step = ScreenGoodbye
				}
			}
			return m, tickCmd()
		}
		// WELCOME: progreso de splash inicial
		if m.screen == ScreenWelcome {
			if m.bootPct < 1.0 {
				m.bootPct += 0.05
				m.bootMsg = bootMessage(m.bootPct)
			}
			if m.bootPct >= 1.0 {
				m.bootPct = 1.0
				if m.installed {
					m.setScreen(ScreenBoot)
					m.step = ScreenBoot
				} else {
					m.setScreen(ScreenWizardP1)
					m.step = ScreenWizardP1
				}
			}
			return m, tickCmd()
		}
		return m, nil

	case tea.WindowSizeMsg:
		m.termW = msg.Width
		m.height = msg.Height - 4 // -4 por 2 líneas de margen arriba + 2 abajo
		col := msg.Width / 12
		m.width = msg.Width - 2*col // contenido usa 10 columnas de 12
		// bw debe dejar espacio para "  100%  ·  999/999 fichas  ·  99m59s transcurridos" (~52 chars)
		bw := m.width - 56
		if bw < 10 {
			bw = 10
		}
		m.progBar.Width = bw
		// (Re)calcular viewports de la pantalla de instalación
		wA, wB, wC, vpH := m.vpDims()
		// Todos usan vpH (mismo alto) — sin hScrollbar, igual altura garantizada
		if !m.vpReady {
			m.vpA = viewport.New(wA-3, vpH)
			m.vpB = viewport.New(wB-3, vpH)
			m.vpC = viewport.New(wC-3, vpH)
			m.vpA.Style = lipgloss.NewStyle()
			m.vpB.Style = lipgloss.NewStyle()
			m.vpC.Style = lipgloss.NewStyle()
			m.vpReady = true
		} else {
			m.vpA.Width, m.vpA.Height = wA-3, vpH
			m.vpB.Width, m.vpB.Height = wB-3, vpH
			m.vpC.Width, m.vpC.Height = wC-3, vpH
		}
		// También pasar el resize a los viewports para que recalculen scrollbar
		var ca, cb, cc tea.Cmd
		m.vpA, ca = m.vpA.Update(msg)
		m.vpB, cb = m.vpB.Update(msg)
		m.vpC, cc = m.vpC.Update(msg)
		// Viewports globales: recalcular para todas las pantallas no-P5
		m.recalcBodyHeight()
		m.bodyVP.Width  = m.width
		m.bodyVP.Height = m.bodyHeight
		m.sectionVP.Width  = m.width
		m.sectionVP.Height = m.bodyHeight - 1 // -1 por barra de tabs de P6
		if m.sectionVP.Height < 1 {
			m.sectionVP.Height = 1
		}
		m.vpDash.Width  = m.width - 4
		m.vpDash.Height = m.bodyHeight
		m.vpLog.Width   = m.width - 4
		m.vpLog.Height  = m.bodyHeight
		if !m.isInstallingScreen() {
			m.bodyVP.SetContent(m.bodyContent())
			if m.screen == ScreenInstallDone {
				m.sectionVP.SetContent(m.viewCompleteBody())
			}
		}
		return m, tea.Batch(ca, cb, cc)

	case sysInfoMsg:
		m.sys = msg.info
		return m, nil

	case wsReadyMsg:
		m.wsConn = msg.conn
		return m, awaitWS(m.wsCh)

	case wsErrorMsg:
		// daemon no disponible — UI continúa offline
		return m, nil

	case wsEventMsg:
		if pc := m.handleWS(msg); pc != nil {
			cmds = append(cmds, pc)
		}
		// Sincronizar viewports con el nuevo estado
		m.syncViewports()
		if !m.isInstallingScreen() && m.screen != ScreenWelcome && m.screen != ScreenGoodbye &&
			m.screen != ScreenDashboard && m.screen != ScreenLogs {
			m.bodyVP.SetContent(m.bodyContent())
			if m.screen == ScreenInstallDone {
				m.sectionVP.SetContent(m.viewCompleteBody())
			}
		}
		if m.needStatusSync && m.wsConn != nil {
			m.needStatusSync = false
			cmds = append(cmds, awaitWS(m.wsCh), sendWS(m.wsConn, "bootstrap_status", nil))
			return m, tea.Batch(cmds...)
		}
		if m.pendingLogTail != "" && m.wsConn != nil {
			fichaID := m.pendingLogTail
			m.pendingLogTail = ""
			cmds = append(cmds, awaitWS(m.wsCh),
				sendWS(m.wsConn, "ficha_log_tail", map[string]interface{}{
					"ficha": fichaID, "lines": 120,
				}))
			return m, tea.Batch(cmds...)
		}
		cmds = append(cmds, awaitWS(m.wsCh))
		return m, tea.Batch(cmds...)

	case progress.FrameMsg:
		newBar, pc := m.progBar.Update(msg)
		m.progBar = newBar.(progress.Model)
		return m, pc

	case spinner.TickMsg:
		var c tea.Cmd
		m.spinner, c = m.spinner.Update(msg)
		cmds = append(cmds, c)
		// Cursor blink: solo al input con foco
		if bc := m.updateFocused(msg); bc != nil {
			cmds = append(cmds, bc)
		}
		// Refrescar viewports en cada tick para que el spinner animado se vea actualizado
		if m.screen == ScreenInstalling && m.viewMode == "normal" {
			m.syncViewports()
		}
		// Actualizar bodyVP para pantallas con contenido animado (spinner, countdown, progress)
		if !m.isInstallingScreen() && m.screen != ScreenWelcome && m.screen != ScreenGoodbye &&
			m.screen != ScreenDashboard && m.screen != ScreenLogs {
			m.bodyVP.SetContent(m.bodyContent())
			if m.screen == ScreenInstallDone {
				m.sectionVP.SetContent(m.viewCompleteBody())
			}
		}
		return m, tea.Batch(cmds...)

	case tea.KeyMsg:
		if navKey(msg) {
			// Teclas de navegación: SOLO van al manejador de navegación, NUNCA al textinput.
			// Evita que Enter/Tab/Esc sean procesados por el textinput y cancelen la acción.
			if c := m.handleKey(msg); c != nil {
				return m, c
			}
			return m, nil
		}
		// Teclas de escritura: van primero al input con foco, luego al manejador.
		if c := m.updateFocused(msg); c != nil {
			cmds = append(cmds, c)
		}
		if c := m.handleKey(msg); c != nil {
			cmds = append(cmds, c)
		}
		return m, tea.Batch(cmds...)
	}

	return m, nil
}

func (m *model) handleWS(ev wsEventMsg) tea.Cmd {
	now := time.Now()
	var progCmd tea.Cmd

	switch ev.evType {
	case "response":
		if ev.total > 0 {
			m.fichasTotal = ev.total
		}
		// Sincronizar estado actual al conectar: fichas instaladas antes de que
		// el TUI conectara no envían eventos retroactivos. Al recibir la respuesta
		// de bootstrap_start, marcamos que hay que pedir el estado completo.
		m.needStatusSync = true

	case "bootstrap_status":
		// Sincronizar fichas del estado actual al UI.
		// fichas es un []interface{} donde cada elemento es map{id,state,server,version}
		if ev.data == nil {
			return progCmd
		}
		if total, ok := ev.data["total_fichas"].(float64); ok && int(total) > m.fichasTotal {
			m.fichasTotal = int(total)
		}
		fichasArr, _ := ev.data["fichas"].([]interface{})
		for _, raw := range fichasArr {
			fdata, ok := raw.(map[string]interface{})
			if !ok {
				continue
			}
			fichaID, _ := fdata["id"].(string)
			st, _ := fdata["state"].(string)
			if fichaID == "" {
				continue
			}
			fd := m.fichaOrCreate(fichaID)
			switch st {
			case "INSTALADA":
				if fd.status != fDone {
					fd.status = fDone
					m.fichasOK++
					m.addLog(logEntry{ts: now, level: logOK, ficha: fichaID,
						msg: fichaID + " — ya instalada (sincronizado)"})
				}
			case "FALLA_INSTALACION":
				if fd.status != fFailed {
					fd.status = fFailed
				}
			case "INSTALANDO":
				if fd.status != fActive {
					fd.status = fActive
					fd.startTime = now
					// TUI conectó tarde — pedir log histórico del disco
					m.pendingLogTail = fichaID
				}
			}
		}
		pct := float64(m.fichasOK) / float64(maxInt(m.fichasTotal, 1))
		progCmd = m.progBar.SetPercent(pct)

	case "saga_start":
		if ev.ficha == "" {
			return progCmd
		}
		fd := m.fichaOrCreate(ev.ficha)
		fd.status = fActive
		fd.startTime = now
		m.addLog(logEntry{ts: now, level: logInfo, ficha: ev.ficha,
			msg: "📦 " + ev.ficha + versionSuffix(ev.ficha) + " — iniciando instalación"})

	case "step_start":
		if ev.ficha == "" || ev.step == "" {
			return progCmd
		}
		fd := m.fichaOrCreate(ev.ficha)
		// Marcar paso previo como done si sigue en active
		for i := range fd.steps {
			if fd.steps[i].status == sActive {
				fd.steps[i].status = sDone
				fd.steps[i].duration = now.Sub(fd.steps[i].startTime)
			}
		}
		fd.steps = append(fd.steps, stepDetail{
			name:      ev.step,
			status:    sActive,
			startTime: now,
			msg:       ev.msg,
		})
		m.addLog(logEntry{ts: now, level: logStep, ficha: ev.ficha,
			msg: ev.step + stepMsgSuffix(ev.msg)})

	case "step_ok":
		fd := m.fichaOrCreate(ev.ficha)
		// Buscar el paso activo o el último con este nombre
		found := false
		for i := len(fd.steps) - 1; i >= 0; i-- {
			if fd.steps[i].name == ev.step || fd.steps[i].status == sActive {
				fd.steps[i].status = sDone
				fd.steps[i].duration = now.Sub(fd.steps[i].startTime)
				if ev.msg != "" {
					fd.steps[i].msg = ev.msg
				}
				found = true
				break
			}
		}
		if !found {
			// El step no fue anunciado como start: crearlo y marcarlo done
			fd.steps = append(fd.steps, stepDetail{
				name: ev.step, status: sDone,
				startTime: now, duration: 0, msg: ev.msg,
			})
		}
		if ev.msg != "" {
			m.addLog(logEntry{ts: now, level: logStep, ficha: ev.ficha,
				msg: "  ✓ " + ev.step + stepMsgSuffix(ev.msg)})
		}

	case "step_fail":
		fd := m.fichaOrCreate(ev.ficha)
		for i := len(fd.steps) - 1; i >= 0; i-- {
			if fd.steps[i].status == sActive {
				fd.steps[i].status = sFailed
				fd.steps[i].duration = now.Sub(fd.steps[i].startTime)
				fd.steps[i].errMsg = ev.errDetail
				break
			}
		}
		m.addLog(logEntry{ts: now, level: logError, ficha: ev.ficha,
			msg: "  ✗ " + ev.step + ": " + ev.errDetail})

	case "saga_ok":
		if ev.ficha == "" {
			return progCmd
		}
		fd := m.fichaOrCreate(ev.ficha)
		// Cerrar cualquier paso activo
		for i := range fd.steps {
			if fd.steps[i].status == sActive {
				fd.steps[i].status = sDone
				fd.steps[i].duration = now.Sub(fd.steps[i].startTime)
			}
		}
		fd.status = fDone
		fd.duration = now.Sub(fd.startTime)
		m.fichasOK++
		pct := float64(m.fichasOK) / float64(m.fichasTotal)
		progCmd = m.progBar.SetPercent(pct)
		m.addLog(logEntry{ts: now, level: logOK, ficha: ev.ficha,
			msg: ev.ficha + versionSuffix(ev.ficha) + " — instalada (" + formatDur(fd.duration) + ")"})

	case "ficha_log":
		// Línea cruda del script bash — taggeada con el paso activo para filtrar en columna C
		if ev.ficha != "" && ev.msg != "" {
			stepName := ""
			if fd, ok := m.fichas[ev.ficha]; ok {
				if as := fd.activeStep(); as != nil {
					stepName = as.name
				}
			}
			m.addLog(logEntry{ts: now, level: logStep, ficha: ev.ficha, step: stepName, msg: ev.msg})
		}
		return progCmd

	case "saga_fail":
		if ev.ficha == "" {
			return progCmd
		}
		fd := m.fichaOrCreate(ev.ficha)
		for i := range fd.steps {
			if fd.steps[i].status == sActive {
				fd.steps[i].status = sFailed
				fd.steps[i].duration = now.Sub(fd.steps[i].startTime)
				fd.steps[i].errMsg = ev.errDetail
			}
		}
		fd.status = fFailed
		fd.duration = now.Sub(fd.startTime)
		fd.errMsg = ev.errDetail
		if fd.errMsg == "" && ev.msg != "" {
			fd.errMsg = ev.msg
		}
		m.errPanel = fd
		m.viewMode = "error"
		m.addLog(logEntry{ts: now, level: logError, ficha: ev.ficha,
			msg: ev.ficha + " — FALLÓ: " + fd.errMsg})

	case "bootstrap_complete":
		m.step = ScreenInstallDone
		m.addLog(logEntry{ts: now, level: logStep,
			msg: "✅ Instalación completada — revisa los logs y presiona Enter para continuar"})
		m.vpAutoScroll = true
		// No se cambia de pantalla automáticamente — el usuario decide cuándo continuar
	}
	return progCmd
}

func (m *model) fichaOrCreate(id string) *fichaDetail {
	if fd, ok := m.fichas[id]; ok {
		return fd
	}
	fd := &fichaDetail{id: id, status: fPending}
	m.fichas[id] = fd
	return fd
}

func (m *model) addLog(e logEntry) {
	m.logs = append(m.logs, e)
	// Actualizar viewports B y C inmediatamente — historial acumulativo sin borrar
	if m.vpReady {
		_, wB, wC, _ := m.vpDims()
		m.vpB.SetContent(m.buildColBContent(wB - 1))
		m.vpC.SetContent(m.buildColCContent(wC - 3))
		if m.vpAutoScroll {
			m.vpB.GotoBottom()
			m.vpC.GotoBottom()
		}
	}
}


func (m *model) handleKey(msg tea.KeyMsg) tea.Cmd {
	m.errMsg = ""

	// Atajos globales durante la instalación
	if m.screen == ScreenInstalling && m.viewMode == "normal" {
		switch msg.String() {
		case "enter", " ":
			// Avanzar manualmente solo si la instalación ya completó
			if m.step == ScreenInstallDone {
				m.setScreen(ScreenInstallDone)
				return nil
			}
		case "r", "R":
			return sendWS(m.wsConn, "bootstrap_resume", nil)
		case "l", "L":
			m.viewMode = "fulllog"
			m.setScreen(ScreenInstallLog)
			m.step = ScreenInstallLog
			return nil
		case "e", "E":
			if m.errPanel != nil {
				m.viewMode = "error"
				m.setScreen(ScreenInstallErr)
				m.step = ScreenInstallErr
			}
			return nil
		case "t", "T":
			m.showTimestamp = !m.showTimestamp
			return nil
		case "ctrl+c":
			return tea.Quit
		case "tab":
			m.installingFocus = (m.installingFocus + 1) % 3
			return nil
		case "shift+tab":
			m.installingFocus = (m.installingFocus + 2) % 3
			return nil
		case "up", "k", "pgup":
			m.vpAutoScroll = false
			var cmd tea.Cmd
			switch m.installingFocus {
			case 0:
				m.vpA, cmd = m.vpA.Update(msg)
			case 1:
				m.vpB, cmd = m.vpB.Update(msg)
			case 2:
				m.vpC, cmd = m.vpC.Update(msg)
			}
			return cmd
		case "down", "j", "pgdown":
			var cmd tea.Cmd
			switch m.installingFocus {
			case 0:
				m.vpA, cmd = m.vpA.Update(msg)
			case 1:
				m.vpB, cmd = m.vpB.Update(msg)
			case 2:
				m.vpC, cmd = m.vpC.Update(msg)
			}
			switch m.installingFocus {
			case 1:
				if m.vpB.AtBottom() {
					m.vpAutoScroll = true
				}
			case 2:
				if m.vpC.AtBottom() {
					m.vpAutoScroll = true
				}
			}
			return cmd
		case "end", "G":
			m.vpAutoScroll = true
			m.vpB.GotoBottom()
			m.vpC.GotoBottom()
			return nil
		case "home", "g":
			m.vpAutoScroll = false
			switch m.installingFocus {
			case 0:
				m.vpA.GotoTop()
			case 1:
				m.vpB.GotoTop()
			case 2:
				m.vpC.GotoTop()
			}
			return nil
		case "left":
			// Scroll horizontal solo en columnas B y C
			switch m.installingFocus {
			case 1:
				m.vpB.ScrollLeft(4)
			case 2:
				m.vpC.ScrollLeft(4)
			}
			return nil
		case "right":
			switch m.installingFocus {
			case 1:
				m.vpB.ScrollRight(4)
			case 2:
				m.vpC.ScrollRight(4)
			}
			return nil
		}
		return nil
	}
	if m.screen == ScreenInstalling {
		// fulllog/error: L/E para volver, ctrl+c para salir
		switch msg.String() {
		case "l", "L":
			m.viewMode = "normal"
			m.setScreen(ScreenInstalling)
			m.step = ScreenInstalling
		case "e", "E":
			m.viewMode = "normal"
			m.setScreen(ScreenInstalling)
			m.step = ScreenInstalling
		case "ctrl+c":
			return tea.Quit
		}
		return nil
	}
	if m.screen == ScreenInstallLog || m.screen == ScreenInstallErr {
		switch msg.String() {
		case "l", "L", "e", "E":
			m.viewMode = "normal"
			m.setScreen(ScreenInstalling)
			m.step = ScreenInstalling
		case "ctrl+c":
			return tea.Quit
		}
		return nil
	}

	switch m.screen {
	case ScreenWelcome:
		return m.keySplashWelcome(msg)
	case ScreenWizardP1:
		return m.keyWelcome(msg)
	case ScreenWizardP2:
		return m.keyTenant(msg)
	case ScreenWizardP3:
		return m.keyAdmin(msg)
	case ScreenWizardP4:
		return m.keyConfirm(msg)
	case ScreenInstallDone:
		switch msg.String() {
		case "tab", "right":
			m.completeFocus = (m.completeFocus + 1) % 4
		case "shift+tab", "left":
			m.completeFocus = (m.completeFocus + 3) % 4
		}
		switch msg.Type {
		case tea.KeyEnter:
			m.setScreen(ScreenReboot)
			m.step = ScreenReboot
			m.countdownSec = 10
		case tea.KeyEsc:
			return tea.Quit
		}
	case ScreenReboot:
		switch msg.Type {
		case tea.KeyEnter:
			m.countdownSec = 0
			m.setScreen(ScreenBoot)
			m.step = ScreenBoot
			m.bootPct = 0
			m.bootMsg = "Iniciando sistema..."
		case tea.KeyEsc:
			m.setScreen(ScreenInstallDone)
			m.step = ScreenInstallDone
		}
	case ScreenDashboard:
		return m.keyDashboard(msg)
	case ScreenLogs:
		return m.keyLogs(msg)
	case ScreenShutdown:
		return m.keyShutdown(msg)
	case ScreenBoot:
		if msg.Type == tea.KeyCtrlC {
			return tea.Quit
		}
	case ScreenGoodbye:
		if msg.Type == tea.KeyCtrlC || msg.Type == tea.KeyEnter {
			return tea.Quit
		}
	}
	return nil
}

func (m *model) keySplashWelcome(msg tea.KeyMsg) tea.Cmd {
	switch msg.Type {
	case tea.KeyEnter, tea.KeyEsc:
		if m.installed {
			m.setScreen(ScreenBoot)
			m.step = ScreenBoot
			m.bootPct = 0
		} else {
			m.setScreen(ScreenWizardP1)
			m.step = ScreenWizardP1
		}
		m.bootPct = 1.0
	case tea.KeyCtrlC:
		return tea.Quit
	}
	return nil
}

func (m *model) keyDashboard(msg tea.KeyMsg) tea.Cmd {
	switch msg.String() {
	case "l", "L":
		m.setScreen(ScreenLogs)
		m.step = ScreenLogs
	case "r", "R":
		m.shutdownMode = "restart"
		m.shutdownPct = 0
		m.setScreen(ScreenShutdown)
		m.step = ScreenShutdown
	case "s", "S":
		m.shutdownMode = "shutdown"
		m.shutdownPct = 0
		m.setScreen(ScreenShutdown)
		m.step = ScreenShutdown
	case "ctrl+c":
		return tea.Quit
	}
	return nil
}

func (m *model) keyLogs(msg tea.KeyMsg) tea.Cmd {
	switch msg.String() {
	case "q", "Q":
		m.setScreen(ScreenDashboard)
		m.step = ScreenDashboard
	case "ctrl+c":
		return tea.Quit
	}
	return nil
}

func (m *model) keyShutdown(msg tea.KeyMsg) tea.Cmd {
	switch msg.String() {
	case "ctrl+c":
		return tea.Quit
	}
	return nil
}

func (m *model) keyWelcome(msg tea.KeyMsg) tea.Cmd {
	switch msg.Type {
	case tea.KeyUp, tea.KeyShiftTab:
		m.welcomeFocus = (m.welcomeFocus + 1) % 2
	case tea.KeyDown, tea.KeyTab:
		m.welcomeFocus = (m.welcomeFocus + 1) % 2
	case tea.KeyEnter:
		if m.welcomeFocus == 1 {
			return tea.Quit
		}
		m.step = ScreenWizardP2
		m.setScreen(ScreenWizardP2)
		m.tenantInputs[0].Focus()
	case tea.KeyEsc, tea.KeyCtrlC:
		return tea.Quit
	}
	return nil
}

func (m *model) keyTenant(msg tea.KeyMsg) tea.Cmd {
	switch msg.Type {
	case tea.KeyTab, tea.KeyDown:
		m.tenantInputs[m.tenantFocus].Blur()
		m.tenantFocus = (m.tenantFocus + 1) % 4
		m.tenantInputs[m.tenantFocus].Focus()
	case tea.KeyShiftTab, tea.KeyUp:
		m.tenantInputs[m.tenantFocus].Blur()
		m.tenantFocus = (m.tenantFocus + 3) % 4
		m.tenantInputs[m.tenantFocus].Focus()
	case tea.KeyEnter:
		if err := m.validateTenant(); err != "" {
			m.errMsg = err
			return nil
		}
		m.step = ScreenWizardP3
		m.setScreen(ScreenWizardP3)
		m.adminFocus = 0
		m.adminInputs[0].Focus()
	case tea.KeyEsc:
		m.step = ScreenWizardP1
		m.setScreen(ScreenWizardP1)
	}
	return nil
}

func (m *model) validateTenant() string {
	if strings.TrimSpace(m.tenantInputs[0].Value()) == "" {
		m.tenantFocus = 0; m.tenantInputs[0].Focus()
		return "La razón social es obligatoria"
	}
	if strings.TrimSpace(m.tenantInputs[1].Value()) == "" {
		m.tenantFocus = 1; m.tenantInputs[1].Focus()
		return "El NIT/CUIT/RFC es obligatorio"
	}
	pais := strings.ToUpper(strings.TrimSpace(m.tenantInputs[2].Value()))
	if pais != "BO" && pais != "AR" && pais != "MX" {
		m.tenantFocus = 2; m.tenantInputs[2].Focus()
		return "País inválido — use BO, AR o MX"
	}
	m.tenantInputs[2].SetValue(pais)
	if strings.TrimSpace(m.tenantInputs[3].Value()) == "" {
		m.tenantInputs[3].SetValue(buildSlug(m.tenantInputs[0].Value()) + ".sksistemas.com")
	}
	return ""
}

func (m *model) keyAdmin(msg tea.KeyMsg) tea.Cmd {
	switch msg.String() {
	case "m", "M":
		m.mfaEnabled = !m.mfaEnabled
		return nil
	}
	switch msg.Type {
	case tea.KeyTab, tea.KeyDown:
		if m.adminFocus < 4 {
			m.adminInputs[m.adminFocus].Blur()
		}
		m.adminFocus = (m.adminFocus + 1) % 5 // 5 posiciones: 0–3 inputs, 4=MFA
		if m.adminFocus < 4 {
			m.adminInputs[m.adminFocus].Focus()
		}
	case tea.KeyShiftTab, tea.KeyUp:
		if m.adminFocus < 4 {
			m.adminInputs[m.adminFocus].Blur()
		}
		m.adminFocus = (m.adminFocus + 4) % 5
		if m.adminFocus < 4 {
			m.adminInputs[m.adminFocus].Focus()
		}
	case tea.KeyEnter:
		if err := m.validateAdmin(); err != "" {
			m.errMsg = err
			return nil
		}
		m.step = ScreenWizardP4
		m.setScreen(ScreenWizardP4)
	case tea.KeyEsc:
		m.step = ScreenWizardP2
		m.setScreen(ScreenWizardP2)
		m.adminFocus = 0
	}
	return nil
}

func (m *model) validateAdmin() string {
	email := m.adminInputs[0].Value()
	if email == "" || !strings.Contains(email, "@") {
		m.adminFocus = 0; m.adminInputs[0].Focus()
		return "Email inválido — debe contener @"
	}
	if len(m.adminInputs[2].Value()) < 8 {
		m.adminFocus = 2; m.adminInputs[2].Focus()
		return "La contraseña debe tener al menos 8 caracteres"
	}
	if m.adminInputs[2].Value() != m.adminInputs[3].Value() {
		m.adminFocus = 3; m.adminInputs[3].Focus()
		return "Las contraseñas no coinciden"
	}
	return ""
}

func (m *model) keyConfirm(msg tea.KeyMsg) tea.Cmd {
	switch msg.Type {
	case tea.KeyUp, tea.KeyShiftTab:
		m.confirmFocus = (m.confirmFocus + 2) % 3
	case tea.KeyDown, tea.KeyTab:
		m.confirmFocus = (m.confirmFocus + 1) % 3
	case tea.KeyEnter:
		switch m.confirmFocus {
		case 0:
			return m.startBootstrap()
		case 1:
			return m.startBootstrap()
		case 2:
			m.step = ScreenWizardP3
			m.setScreen(ScreenWizardP3)
			m.confirmFocus = 0
		}
	case tea.KeyEsc:
		m.step = ScreenWizardP3
		m.setScreen(ScreenWizardP3)
		m.confirmFocus = 0
	}
	switch msg.String() {
	case "a", "A":
		return m.startBootstrap()
	}
	return nil
}

func (m *model) startBootstrap() tea.Cmd {
	m.step = ScreenInstalling
	m.setScreen(ScreenInstalling)
	m.startTime = time.Now()
	m.addLog(logEntry{ts: time.Now(), level: logInfo, msg: "🚀 SBOS Bootstrap iniciado"})
	m.addLog(logEntry{ts: time.Now(), level: logInfo,
		msg: "   Empresa: " + m.tenantInputs[0].Value() +
			"  ·  Dominio: " + m.tenantInputs[3].Value()})
	m.addLog(logEntry{ts: time.Now(), level: logInfo, msg: "   22 fichas  ·  7 niveles del DAG"})

	if demoMode {
		go runDemo(m.wsCh)
		return awaitWS(m.wsCh) // iniciar lector del canal para que los eventos demo lleguen al modelo
	}

	return sendWS(m.wsConn, "bootstrap_start", map[string]interface{}{
		"razon_social": m.tenantInputs[0].Value(),
		"nit":          m.tenantInputs[1].Value(),
		"pais":         m.tenantInputs[2].Value(),
		"dominio":      m.tenantInputs[3].Value(),
		"email":        m.adminInputs[0].Value(),
		"nombre":       m.adminInputs[1].Value(),
		"password":     m.adminInputs[2].Value(),
		"mfa":          m.mfaEnabled,
	})
}

// ── View ───────────────────────────────────────────────────────────────────

// wrapWithMargin aplica margen izquierdo (1/12 del ancho real) y 2 líneas vacías arriba/abajo.
func (m model) wrapWithMargin(content string) string {
	if m.termW == 0 {
		return content
	}
	col := m.termW / 12
	if col == 0 {
		return content
	}
	pad := strings.Repeat(" ", col)
	lines := strings.Split(content, "\n")
	for i, line := range lines {
		lines[i] = pad + line
	}
	return "\n\n" + strings.Join(lines, "\n") + "\n\n"
}

func (m model) View() string {
	if m.width == 0 {
		return "Iniciando SBOS..."
	}
	wrap := func(s string) string { return m.wrapWithMargin(s) }
	// Grupo A: splashes ocupan pantalla completa, sin header/footer
	if m.screen == ScreenWelcome {
		return wrap(m.viewSplashWelcome())
	}
	if m.screen == ScreenGoodbye {
		return wrap(m.viewSplashGoodbye())
	}
	top    := m.viewHeader()
	sep    := sDim.Render(strings.Repeat("─", m.width))
	bottom := lipgloss.JoinVertical(lipgloss.Left, sep, m.viewFooter())
	// Grupo C: P5 tiene vpA/vpB/vpC propios
	if m.screen == ScreenInstalling {
		// Separadores alineados exactamente con los paneles (outer_real = wX+2)
		wA, wB, wC, _ := m.vpDims()
		panelsW := (wA + 2) + (wB + 2) + (wC + 2)
		sepP    := sDim.Render(strings.Repeat("─", panelsW))
		bottomP := lipgloss.JoinVertical(lipgloss.Left, sepP, m.viewFooter())
		return wrap(lipgloss.JoinVertical(lipgloss.Left, top, m.viewInstalling(), bottomP))
	}
	// Grupo D: P5B/P5C usan vpLog propio con toolbar fija
	if m.screen == ScreenInstallLog || m.screen == ScreenInstallErr {
		return wrap(lipgloss.JoinVertical(lipgloss.Left, top, m.viewFullLog(), bottom))
	}
	// P9: viewDashboard renderiza directamente (vpDash no usa SetContent aún)
	if m.screen == ScreenDashboard {
		return wrap(lipgloss.JoinVertical(lipgloss.Left, top, m.viewDashboard(), bottom))
	}
	// P10: viewLogs con toolbar dual + vpLog
	if m.screen == ScreenLogs {
		return wrap(lipgloss.JoinVertical(lipgloss.Left, top, m.viewLogs(), bottom))
	}
	// Grupos B y E: bodyVP global controla el alto exacto
	return wrap(lipgloss.JoinVertical(lipgloss.Left, top, m.bodyVP.View(), bottom))
}

func (m model) renderStepper() string {
	if m.screen < ScreenWizardP1 || m.screen > ScreenInstalling {
		return ""
	}
	steps := []struct {
		name string
		sc   Screen
	}{
		{"Bienvenida", ScreenWizardP1},
		{"Empresa", ScreenWizardP2},
		{"Admin", ScreenWizardP3},
		{"Confirmar", ScreenWizardP4},
		{"Instalando", ScreenInstalling},
	}
	parts := make([]string, len(steps))
	for i, s := range steps {
		var icon, textColor string
		switch {
		case m.screen > s.sc:
			icon = lipgloss.NewStyle().Foreground(cGreen).Render("✓")
			textColor = cDimS
		case m.screen == s.sc:
			icon = m.spinner.View()
			textColor = cCyanS
		default:
			icon = lipgloss.NewStyle().Foreground(cSlate).Render("·")
			textColor = cSlateS
		}
		tx := lipgloss.NewStyle().Foreground(lipgloss.Color(textColor)).Render(" " + s.name)
		parts[i] = icon + tx
	}
	sep := lipgloss.NewStyle().Foreground(cBg3).Render(" — ")
	return lipgloss.NewStyle().Align(lipgloss.Center).Width(m.width).
		Render(strings.Join(parts, sep))
}

func (m model) viewHeader() string {
	titles := map[Screen]string{
		ScreenWelcome:    "",
		ScreenWizardP1:   "Bienvenida",
		ScreenWizardP2:   "Datos de la Empresa",
		ScreenWizardP3:   "Cuenta de Administrador",
		ScreenWizardP4:   "Confirmar instalación",
		ScreenInstalling: "Instalando SBOS...",
		ScreenInstallLog: "Log completo",
		ScreenInstallErr: "Error de instalación",
		ScreenInstallDone: "Instalación completada ✓",
		ScreenReboot:     "Reiniciando sistema...",
		ScreenBoot:       "Iniciando SBOS",
		ScreenDashboard:  "Dashboard bos",
		ScreenLogs:       "Logs del sistema",
		ScreenShutdown:   "Apagando SBOS",
		ScreenGoodbye:    "",
	}
	brand := "SBOS — Sistema Operativo Empresarial Soberano"
	if m.width < 60 {
		brand = "SBOS"
	} else if m.width < 80 {
		brand = "SBOS Instalador"
	}

	topBarStyle := sTopBar.Width(m.width - 2) // Padding(0,1) = 2 chars overhead
	if m.screen == ScreenShutdown {
		if m.shutdownMode == "restart" {
			topBarStyle = topBarStyle.Background(lipgloss.Color("#1c1003")).Foreground(lipgloss.Color("#fde68a"))
		} else {
			topBarStyle = topBarStyle.Background(lipgloss.Color("#1a0808")).Foreground(lipgloss.Color("#fca5a5"))
		}
	} else if m.screen == ScreenGoodbye {
		topBarStyle = topBarStyle.Background(lipgloss.Color("#0c1a0c")).Foreground(lipgloss.Color("#166534"))
	}

	var bar string
	if m.screen == ScreenDashboard {
		// doc §P9: topbar con reloj en vivo + punto verde pulsante a la derecha
		clock := time.Now().Format("15:04:05")
		right := lipgloss.NewStyle().Foreground(lipgloss.Color("#22c55e")).Bold(true).
			Render("●") + " " +
			lipgloss.NewStyle().Foreground(lipgloss.Color("#86efac")).Render("bos activo") +
			"  " + lipgloss.NewStyle().Foreground(lipgloss.Color("#475569")).Render(clock)
		leftW := m.width - lipgloss.Width(right) - 2
		if leftW < 0 {
			leftW = 0
		}
		barContent := lipgloss.NewStyle().Width(leftW).Render(brand) + right
		bar = topBarStyle.Render(barContent)
	} else {
		bar = topBarStyle.Render(brand)
	}
	stepper := m.renderStepper()
	title := sTitle.Width(m.width).Render(titles[m.screen])
	sep := sDim.Render(strings.Repeat("─", m.width))

	parts := []string{bar}
	if stepper != "" {
		parts = append(parts, stepper)
	}
	if titles[m.screen] != "" {
		parts = append(parts, title)
	}
	parts = append(parts, sep)
	return lipgloss.JoinVertical(lipgloss.Left, parts...)
}

// bodyContent genera el string que se pasa a bodyVP.SetContent().
// No llamar para P5/P5B/P5C/P9/P10/WELCOME/GOODBYE — esos usan View() directo.
func (m model) bodyContent() string {
	var content string
	switch m.screen {
	case ScreenWizardP1:
		content = m.viewWelcome()
	case ScreenWizardP2:
		content = m.viewForm("Datos del tenant",
			[4]string{"Razón social", "NIT / CUIT / RFC", "País [BO/AR/MX]", "Dominio"},
			m.tenantInputs, m.tenantFocus,
			[4]string{
				"Nombre legal completo de su empresa tal como aparece en documentos fiscales oficiales.",
				"Identificador fiscal único. En Bolivia: NIT. En Argentina: CUIT. En México: RFC.",
				"País donde opera la empresa. Determina el módulo fiscal y las reglas de cumplimiento.",
				"Dominio base para los servicios SBOS. Se usará en certificados TLS y subdominios.",
			},
			[4]string{
				"Sistemas SKULL S.A. · ACME Consultores Ltda.",
				"1025463029 · 20-12345678-9 · AAA010101AAA",
				"BO · AR · MX · CL · PE · CO",
				"sksistemas.com · miempresa.bo · consultech.com.ar",
			},
		)
	case ScreenWizardP3:
		content = m.viewAdmin()
	case ScreenWizardP4:
		content = m.viewConfirm()
	case ScreenInstallDone:
		content = m.viewCompleteTabBar() + "\n" + m.sectionVP.View()
	case ScreenReboot:
		content = m.viewReboot()
	case ScreenBoot:
		content = m.viewBoot()
	case ScreenShutdown:
		content = m.viewShutdown()
	}
	// viewErr() integrado al final del body para no interferir con el footer
	if m.errMsg != "" {
		content += "\n" + sRed.Render("  ✗ "+m.errMsg)
	}
	// Centrado vertical automático (doc §0) — responsivo: usa lipgloss.Place()
	// que recalcula en cada llamada con los valores actuales de m.width/m.bodyHeight.
	// Solo se activa cuando el contenido es más corto que el body (sin scroll).
	if m.bodyHeight > 0 && m.width > 0 {
		h := lipgloss.Height(content)
		if h < m.bodyHeight {
			content = lipgloss.Place(m.width, m.bodyHeight,
				lipgloss.Center, lipgloss.Center, content)
		}
	}
	return content
}

func (m model) viewErr() string {
	if m.errMsg == "" {
		return ""
	}
	return "\n" + sRed.Render("  ✗ "+m.errMsg) + "\n"
}

// screenKeyMap implementa help.KeyMap para un conjunto variable de teclas por pantalla.
type screenKeyMap []key.Binding

func (km screenKeyMap) ShortHelp() []key.Binding    { return km }
func (km screenKeyMap) FullHelp() [][]key.Binding   { return [][]key.Binding{km} }

// viewFooter retorna el footer de 1 línea con help.Model + key.Binding (doc §12 regla 6).
// El separador ─── se añade en View() para mantener botH = 1 sin el sep.
func (m model) viewFooter() string {
	var keys screenKeyMap
	switch m.screen {
	case ScreenWizardP1:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("up", "down"), key.WithHelp("↑↓", "navegar")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "seleccionar")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "salir")),
		}
	case ScreenWizardP2:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("tab", "up", "down"), key.WithHelp("tab/↑↓", "campo sig")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "continuar")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "volver")),
		}
	case ScreenWizardP3:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("tab", "up", "down"), key.WithHelp("tab/↑↓", "campo sig")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "continuar")),
			key.NewBinding(key.WithKeys("m"), key.WithHelp("M", "toggle MFA")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "volver")),
		}
	case ScreenWizardP4:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("up", "down"), key.WithHelp("↑↓", "navegar")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "seleccionar")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "volver")),
		}
	case ScreenInstalling:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("tab"), key.WithHelp("tab", "panel")),
			key.NewBinding(key.WithKeys("up", "down"), key.WithHelp("↑↓", "scroll")),
			key.NewBinding(key.WithKeys("l"), key.WithHelp("L", "log")),
			key.NewBinding(key.WithKeys("e"), key.WithHelp("E", "error")),
			key.NewBinding(key.WithKeys("t"), key.WithHelp("T", "timestamp")),
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "cancelar")),
		}
	case ScreenInstallLog:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("up", "down"), key.WithHelp("↑↓", "scroll")),
			key.NewBinding(key.WithKeys("g"), key.WithHelp("G", "final")),
			key.NewBinding(key.WithKeys("l"), key.WithHelp("L", "volver")),
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "cancelar")),
		}
	case ScreenInstallErr:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("e"), key.WithHelp("E", "volver")),
			key.NewBinding(key.WithKeys("l"), key.WithHelp("L", "log")),
			key.NewBinding(key.WithKeys("r"), key.WithHelp("R", "reintentar")),
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "cancelar")),
		}
	case ScreenInstallDone:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("left", "right"), key.WithHelp("←→", "sección")),
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "continuar")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "salir")),
		}
	case ScreenReboot:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "reiniciar ahora")),
			key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "cancelar")),
		}
	case ScreenDashboard:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("l"), key.WithHelp("L", "logs")),
			key.NewBinding(key.WithKeys("r"), key.WithHelp("R", "restart")),
			key.NewBinding(key.WithKeys("s"), key.WithHelp("S", "shutdown")),
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "salir")),
		}
	case ScreenLogs:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("/"), key.WithHelp("/", "buscar")),
			key.NewBinding(key.WithKeys("g"), key.WithHelp("G", "final")),
			key.NewBinding(key.WithKeys("t"), key.WithHelp("T", "timestamp")),
			key.NewBinding(key.WithKeys("q"), key.WithHelp("Q", "volver")),
		}
	case ScreenShutdown:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "forzar (peligroso)")),
		}
	default:
		keys = screenKeyMap{
			key.NewBinding(key.WithKeys("ctrl+c"), key.WithHelp("ctrl+c", "salir")),
		}
	}
	return sFooter.Width(m.width - 2).Render(m.helpModel.View(keys)) // Padding(0,1) = 2 chars overhead
}

// ── Menú navegable ────────────────────────────────────────────────────────────

// menuItem representa una opción de menú con su etiqueta y descripción.
type menuItem struct {
	label string
	desc  string
}

// renderMenu renderiza un menú vertical navegable con cursor visible.
// El cursor (›) apunta a la opción activa, que se muestra con fondo verde.
// Las opciones inactivas se muestran en gris con indentación.
func renderMenu(items []menuItem, focus int, width int) string {
	sActive := lipgloss.NewStyle().
		Background(lipgloss.Color("#0f2433")).
		Foreground(cCyan).
		Bold(true).
		PaddingLeft(1).PaddingRight(2)
	sActiveIcon := lipgloss.NewStyle().Foreground(cCyan)
	sInactive := lipgloss.NewStyle().
		Foreground(cMuted).PaddingLeft(4)
	sDesc := lipgloss.NewStyle().Foreground(cMuted).PaddingLeft(6)

	var rows []string
	for i, item := range items {
		if i == focus {
			rows = append(rows, sActiveIcon.Render("› ")+sActive.Render(item.label))
			if item.desc != "" {
				rows = append(rows, sDesc.Render(item.desc))
			}
		} else {
			rows = append(rows, sInactive.Render("   "+item.label))
		}
		rows = append(rows, "")
	}
	hint := lipgloss.NewStyle().Foreground(cDim).Render("  ↑↓ · Tab  navegar    Enter  seleccionar")
	rows = append(rows, hint)
	return strings.Join(rows, "\n")
}

// ── Pantalla 1 — Bienvenida ─────────────────────────────────────────────────

func (m model) viewWelcome() string {
	mode := m.mode()

	info := []struct{ label, val string }{
		{"Sistema Operativo", m.sys.OS},
		{"Kernel", m.sys.Kernel},
		{"RAM disponible", m.sys.RAM},
		{"Disco disponible", m.sys.Disk},
		{"Núcleos CPU", m.sys.CPU},
	}

	var rows []string
	for _, r := range info {
		v := r.val
		if v == "" {
			v = sDim.Render("detectando...")
		}
		rows = append(rows, fmt.Sprintf("  %s %s",
			sDim.Render(fmt.Sprintf("%-20s", r.label+":")),
			sBold.Render(v),
		))
	}
	sysBlock := strings.Join(rows, "\n")

	// Badges de instalación con colores explícitos (doc §P1 L800-L804)
	badges := lipgloss.JoinHorizontal(lipgloss.Top,
		badge("22 fichas", cGreen, lipgloss.Color("#0a1f12")),
		badge("7 niveles del DAG", lipgloss.Color("#3b82f6"), lipgloss.Color("#0c1a2e")),
		badge("~48 minutos", cYellow, lipgloss.Color("#1c0f03")),
	)

	opciones := []menuItem{
		{"Comenzar instalación", "Inicia el asistente paso a paso"},
		{"Salir", "Cerrar el instalador"},
	}
	menu := renderMenu(opciones, m.welcomeFocus, m.width)

	if mode == "xs" {
		// xs: columna única sin caja, sin centrado horizontal
		// El centrado vertical lo aplica bodyContent() universalmente
		return lipgloss.JoinVertical(lipgloss.Left, sysBlock, "\n", badges, "\n", menu)
	}

	// sm/md: caja + centrado horizontal en m.width
	var box string
	if mode == "sm" {
		box = sBox.Width(m.width - 4).Render(sysBlock)
	} else {
		box = sBox.Render(sysBlock)
	}

	inner := lipgloss.JoinVertical(lipgloss.Center, box, "\n", badges, "\n", menu)
	// El centrado vertical lo aplica bodyContent() universalmente
	return lipgloss.NewStyle().Align(lipgloss.Center).Width(m.width).Render(inner)
}

// ── Formularios ─────────────────────────────────────────────────────────────

// viewForm renderiza un formulario de 4 campos con panel de ayuda de 3 zonas (doc §P2).
// helpTexts: texto explicativo por campo (zona 2 del helpPanel).
// helpExamples: ejemplos por campo (zona 3 del helpPanel, color cGreen).
func (m model) viewForm(helpTitle string, labels [4]string, inputs [4]textinput.Model, focus int, helpTexts [4]string, helpExamples [4]string) string {
	mode := m.mode()

	cursor := lipgloss.NewStyle().Foreground(cGreen).Bold(true)
	var fields []string
	for i, lbl := range labels {
		var prefix, labelRendered string
		if i == focus {
			prefix = cursor.Render("› ")
			labelRendered = sLabelA.Render(lbl + ":")
		} else {
			prefix = "  "
			labelRendered = sLabel.Render(lbl + ":")
		}
		fields = append(fields, prefix+labelRendered+inputs[i].View())
	}
	hint := sDim.Render("  Tab / ↑↓ para navegar entre campos  ·  Enter para continuar")
	formContent := strings.Join(fields, "\n\n") + "\n\n" + hint

	if mode == "xs" || mode == "sm" {
		return sBox.Width(m.width - 4).Render(formContent)
	}

	// md: formulario ancho completo + ayuda debajo (sin columna lateral)
	// sBoxActive tiene Padding(0,1)+RoundedBorder → overhead total 4 chars → inner = m.width-4
	formPanel := sBoxActive.Width(m.width - 4).Render(formContent)

	helpBody := lipgloss.JoinVertical(lipgloss.Left,
		lipgloss.NewStyle().Foreground(lipgloss.Color("#3b82f6")).Bold(true).
			Render(strings.ToUpper(helpTitle+" — "+labels[focus])),
		"",
		lipgloss.NewStyle().Foreground(cMuted).
			Render(wordWrap(helpTexts[focus], m.width-4)),
		"",
		lipgloss.NewStyle().Foreground(cGreen).
			Render(helpExamples[focus]),
	)
	// sHelpBox tiene BorderLeft(1)+PaddingLeft(2) → overhead 3 chars → inner = m.width-3
	helpSection := sHelpBox.Width(m.width - 3).Render(helpBody)
	return lipgloss.JoinVertical(lipgloss.Left, formPanel, helpSection)
}

func (m model) viewAdmin() string {
	labels := [4]string{"Email", "Nombre completo", "Contraseña", "Confirmar contraseña"}
	mode := m.mode()

	cursor := lipgloss.NewStyle().Foreground(cGreen).Bold(true)
	var fields []string
	for i, lbl := range labels {
		var prefix, labelRendered string
		if i == m.adminFocus {
			prefix = cursor.Render("› ")
			labelRendered = sLabelA.Render(lbl + ":")
		} else {
			prefix = "  "
			labelRendered = sLabel.Render(lbl + ":")
		}
		fields = append(fields, prefix+labelRendered+m.adminInputs[i].View())
	}
	// Fila MFA usando renderMFARow() (doc §P3 L1076-L1094)
	// foco 4 = fila MFA (5 posiciones: 0=email, 1=nombre, 2=pass, 3=confirm, 4=MFA)
	mfaFocused := m.adminFocus == 4
	mfaPrefix := "  "
	if mfaFocused {
		mfaPrefix = cursor.Render("› ")
	}
	mfaLabel := sLabel.Render("MFA:")
	if mfaFocused {
		mfaLabel = sLabelA.Render("MFA:")
	}
	fields = append(fields, mfaPrefix+mfaLabel+renderMFARow(m.mfaEnabled, mfaFocused))
	hint := sDim.Render("  Tab / ↑↓ navegar  ·  M alternar MFA  ·  Enter continuar")
	formContent := strings.Join(fields, "\n\n") + "\n\n" + hint

	if mode == "xs" || mode == "sm" {
		return sBox.Width(m.width - 4).Render(formContent)
	}

	// md: formulario ancho completo + ayuda debajo (sin columna lateral)
	adminHelpTexts := [4]string{
		"Correo electrónico del administrador principal del SBOS.",
		"Nombre completo para identificación en logs y auditoría.",
		"Contraseña mínima 12 caracteres. Use mayúsculas, números y símbolos.",
		"Repita la contraseña para confirmar que no haya errores tipográficos.",
	}
	adminHelpExamples := [4]string{
		"admin@sksistemas.com · it@empresa.bo",
		"Juan Pérez · María González",
		"Mín. 12 chars · Ej: Secure@2026!",
		"Debe coincidir exactamente con el campo anterior.",
	}
	var helpText, helpExample string
	if m.adminFocus < 4 {
		helpText = adminHelpTexts[m.adminFocus]
		helpExample = adminHelpExamples[m.adminFocus]
	} else {
		helpText = "Activa autenticación push de dos factores vía sbos-notifier. Recomendado para todos los administradores."
		helpExample = "Push MFA requiere sbos-notifier instalado y configurado."
	}
	activeLabelName := "MFA"
	if m.adminFocus < 4 {
		activeLabelName = labels[m.adminFocus]
	}

	helpBody := lipgloss.JoinVertical(lipgloss.Left,
		lipgloss.NewStyle().Foreground(lipgloss.Color("#3b82f6")).Bold(true).
			Render(strings.ToUpper("Admin — "+activeLabelName)),
		"",
		lipgloss.NewStyle().Foreground(cMuted).
			Render(wordWrap(helpText, m.width-4)),
		"",
		lipgloss.NewStyle().Foreground(cGreen).
			Render(helpExample),
	)
	formPanel := sBoxActive.Width(m.width - 4).Render(formContent)
	helpSection := sHelpBox.Width(m.width - 3).Render(helpBody)
	return lipgloss.JoinVertical(lipgloss.Left, formPanel, helpSection)
}

// summaryRow renderiza una fila de resumen con label de ancho fijo 10 chars (doc §P4 L1181).
func summaryRow(label, value string) string {
	l := lipgloss.NewStyle().Foreground(cDim).Width(10).Render(label)
	v := lipgloss.NewStyle().Foreground(cWhite).Render(value)
	return l + " " + v
}

// ── Pantalla 4 — Confirmación ───────────────────────────────────────────────

func (m model) viewConfirm() string {
	mode := m.mode()

	mfaStr := lipgloss.NewStyle().Foreground(cDim).Render("✗ Desactivado")
	if m.mfaEnabled {
		mfaStr = sGreen.Render("✓ Push MFA")
	}
	summaryLines := []string{
		sBold.Render("Resumen de instalación"), "",
		summaryRow("Empresa", m.tenantInputs[0].Value()),
		summaryRow("NIT", m.tenantInputs[1].Value()),
		summaryRow("País", m.tenantInputs[2].Value()),
		summaryRow("Dominio", m.tenantInputs[3].Value()),
		summaryRow("Admin", m.adminInputs[0].Value()),
		"MFA       " + mfaStr,
	}
	summary := strings.Join(summaryLines, "\n")
	acciones := []menuItem{
		{"Iniciar instalación", "Comienza el bootstrap con los datos confirmados"},
		{"Modo automático", "Instala sin pausas ni confirmaciones adicionales"},
		{"Volver a corregir datos", "Regresa a la pantalla de administrador"},
	}
	cta := "\n" + renderMenu(acciones, m.confirmFocus, m.width)

	if mode == "xs" || mode == "sm" {
		return sBox.Width(m.width - 4).Render(summary) + cta
	}

	// md: izquierda(flex1 resumen+menu) | derecha(34 chars fases) — doc §P4 L1126
	phW := 34
	if m.width < 80 {
		phW = 28
	}
	leftW := m.width - phW - 4

	var phLines []string
	phLines = append(phLines,
		lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Fases a instalar"), "",
	)
	for _, ph := range m.phases {
		phLines = append(phLines,
			lipgloss.NewStyle().Foreground(lipgloss.Color("#94a3b8")).Render("○ "+ph.nombre),
		)
		for _, f := range ph.fichas {
			v := fichaVersions[f]
			suffix := ""
			if v != "" {
				suffix = " " + v
			}
			phLines = append(phLines,
				lipgloss.NewStyle().Foreground(cMuted).PaddingLeft(2).Render("• "+f+suffix),
			)
		}
	}

	leftCol := lipgloss.JoinVertical(lipgloss.Left,
		sBox.Width(leftW).Render(summary),
		cta,
	)
	phPanel := sBox.Width(phW).Render(strings.Join(phLines, "\n"))
	return lipgloss.JoinHorizontal(lipgloss.Top, leftCol, phPanel)
}

// ── Pantalla 5 — Instalación en progreso ────────────────────────────────────

// vScrollbar renderiza un scrollbar vertical de h líneas para el viewport dado.
// Usa █ para el thumb (cyan) y │ para el track (slate). Si el contenido cabe, muestra un track tenue.
func vScrollbar(vp viewport.Model, h int) string {
	track := lipgloss.NewStyle().Foreground(lipgloss.Color("#334155")).Render("┆")
	thumb := lipgloss.NewStyle().Foreground(lipgloss.Color("#22c55e")).Render("▋")
	if h <= 0 {
		return ""
	}
	if vp.TotalLineCount() <= vp.Height {
		// Todo el contenido cabe: scrollbar tenue sin thumb
		lines := make([]string, h)
		for i := range lines {
			lines[i] = track
		}
		return strings.Join(lines, "\n")
	}
	pct := vp.ScrollPercent()
	thumbPos := int(pct * float64(h-1))
	if thumbPos >= h {
		thumbPos = h - 1
	}
	lines := make([]string, h)
	for i := range lines {
		if i == thumbPos {
			lines[i] = thumb
		} else {
			lines[i] = track
		}
	}
	return strings.Join(lines, "\n")
}

// hScrollbar renderiza un scrollbar horizontal de w chars para el viewport dado.
// Usa █ para el thumb (cyan) y ─ para el track. Si no hay scroll horizontal, muestra track tenue.
func hScrollbar(vp viewport.Model, w int) string {
	if w <= 0 {
		return ""
	}
	trackCh := lipgloss.NewStyle().Foreground(lipgloss.Color("#334155")).Render("╌")
	thumbCh := lipgloss.NewStyle().Foreground(lipgloss.Color("#22c55e")).Render("▬")
	pct := vp.HorizontalScrollPercent()
	if pct <= 0 {
		// No hay contenido extra horizontalmente
		out := make([]string, w)
		for i := range out {
			out[i] = trackCh
		}
		return strings.Join(out, "")
	}
	thumbPos := int(pct * float64(w-1))
	if thumbPos >= w {
		thumbPos = w - 1
	}
	out := make([]string, w)
	for i := range out {
		if i == thumbPos {
			out[i] = thumbCh
		} else {
			out[i] = trackCh
		}
	}
	return strings.Join(out, "")
}

// vpDims devuelve (wA, wB, wC, height) para los 3 viewports de la pantalla MD.
// Trabaja en anchos EXTERIORES para garantizar que los 3 paneles sumen exactamente m.width
// (alineados con la línea separadora). Ancho interior = ancho exterior - 4 (border+padding).
// Col A pierde una columna (m.width/10) respecto al 36% original; C recibe esa columna.
func (m model) vpDims() (wA, wB, wC, h int) {
	h = m.height - 10
	if h < 4  { h = 4  }
	if m.width < 50 {
		return 14, 12, 14, h
	}
	// Width(w) en lipgloss incluye el padding; el border suma 2 más al exterior.
	// frame = 2 (solo border): outer_real = Width + 2 = outerX.
	frame  := 2
	outerA := m.width / 3
	outerB := m.width / 3
	outerC := m.width - outerA - outerB // absorbe el resto; suma = m.width ✓
	wA = outerA - frame
	wB = outerB - frame
	wC = outerC - frame
	if wA < 10 { wA = 10 }
	if wB < 10 { wB = 10 }
	if wC < 18 { wC = 18 }
	return
}

// syncViewports actualiza el contenido de los 3 viewports con el estado actual.
// Debe llamarse cada vez que cambia el estado de fichas o logs.
// Con vpAutoScroll=true, colB y colC saltan al final después de actualizar.
func (m *model) syncViewports() {
	if !m.vpReady {
		return
	}
	wA, wB, wC, _ := m.vpDims()

	// ColA: wrap exacto al viewport (wA-1, 1 char para vscroll)
	m.vpA.SetContent(m.buildColAContent(wA - 1))

	// ColB: wrap al viewport (wB-1)
	m.vpB.SetContent(m.buildColBContent(wB - 1))

	// ColC: ancho real del viewport — evita que emoji de 2 cols queden cortados al borde
	m.vpC.SetContent(m.buildColCContent(wC - 3))

	// Auto-scroll: solo si el usuario no ha subido manualmente
	if m.vpAutoScroll {
		// ColA: centrar en la fase activa
		targetLine := m.activePhaseLineIdx()
		half := m.vpA.Height / 2
		if targetLine > half {
			m.vpA.SetYOffset(targetLine - half)
		}
		m.vpB.GotoBottom()
		m.vpC.GotoBottom()
	}
}

// buildColAContent genera el árbol de fases y fichas con iconos y colores explícitos del diseño.
// Colores: done=✓#22c55e + texto#94a3b8 · active=spinner#f59e0b + texto#e2e8f0 · pend=○#334155 + texto#334155 · err=✗#ef4444
func (m model) buildColAContent(w int) string {
	sTextDone := lipgloss.NewStyle().Foreground(lipgloss.Color("#94a3b8"))
	sTextActive := lipgloss.NewStyle().Foreground(lipgloss.Color("#e2e8f0")).Bold(true)
	sTextPend := lipgloss.NewStyle().Foreground(lipgloss.Color("#334155"))
	sTextErr := lipgloss.NewStyle().Foreground(lipgloss.Color("#ef4444"))
	sTime := lipgloss.NewStyle().Foreground(lipgloss.Color("#475569"))

	var sb strings.Builder
	sb.WriteString(lipgloss.NewStyle().Foreground(cMuted).Render("Fases de instalación"))
	sb.WriteString("\n\n")
	for _, ph := range m.phases {
		st := m.phaseStatus(ph)
		var phIcon, phLine string
		switch st {
		case fDone:
			phIcon = icOk()
			phLine = phIcon + " " + sTextDone.Render(ph.nombre)
		case fActive:
			phIcon = icRun()
			phLine = phIcon + " " + sTextActive.Render(ph.nombre)
		case fFailed:
			phIcon = icErr()
			phLine = phIcon + " " + sTextErr.Render(ph.nombre)
		default:
			phIcon = icPend()
			phLine = phIcon + " " + sTextPend.Render(ph.nombre)
		}
		sb.WriteString(phLine)
		sb.WriteByte('\n')
		for _, fid := range ph.fichas {
			fd := m.fichas[fid]
			fname := truncA(fid, w-8)
			if fd == nil {
				sb.WriteString("  " + icPend() + " " + sTextPend.Render(fname))
				sb.WriteByte('\n')
				continue
			}
			switch fd.status {
			case fDone:
				dur := sTime.Render(" " + formatDur(fd.duration))
				sb.WriteString("  " + icOk() + " " + sTextDone.Render(fname) + dur)
			case fActive:
				// spinner amarillo para la ficha ejecutándose ahora
				sb.WriteString("  " + m.spinner.View() + " " + sTextActive.Render(fname))
			case fFailed:
				sb.WriteString("  " + icErr() + " " + sTextErr.Render(fname))
			default:
				sb.WriteString("  " + icPend() + " " + sTextPend.Render(fname))
			}
			sb.WriteByte('\n')
		}
		sb.WriteByte('\n')
	}
	return sb.String()
}

// buildColBContent genera el panel B: ficha activa con header 📦, subheader spinner + paso/total, lista de pasos.
// Colores: header #e2e8f0 · subheader #475569 · pasos según estado (mismos iconos/colores que panel A)
func (m model) buildColBContent(w int) string {
	spin := m.spinner.View()

	sHeader := lipgloss.NewStyle().Foreground(lipgloss.Color("#e2e8f0")).Bold(true)
	sSubhdr := lipgloss.NewStyle().Foreground(lipgloss.Color("#475569"))
	sDivider := lipgloss.NewStyle().Foreground(lipgloss.Color("#1e293b")).Render(strings.Repeat("─", w-2))

	var sb strings.Builder
	hasContent := false

	// Historial completo: todas las fichas en orden de fases, no solo la activa
	for _, ph := range m.phases {
		for _, fid := range ph.fichas {
			fd := m.fichas[fid]
			if fd == nil || fd.status == fPending {
				continue // no mostrar fichas que aún no han iniciado
			}
			if hasContent {
				sb.WriteString(sDivider)
				sb.WriteByte('\n')
			}
			hasContent = true

			// Header: nombre + versión
			v := fichaVersions[fd.id]
			hdr := sHeader.Render("📦 " + fd.id)
			if v != "" {
				hdr += " " + sDim.Render(v)
			}
			sb.WriteString(hdr)
			sb.WriteByte('\n')

			// Subheader: estado
			done := fd.countDone()
			total := len(fd.steps)
			switch fd.status {
			case fActive:
				if total == 0 {
					sb.WriteString(spin + " " + sSubhdr.Render("iniciando…"))
				} else if as := fd.activeStep(); as != nil {
					el := formatDur(time.Since(as.startTime).Round(time.Second))
					sb.WriteString(spin + " " + sSubhdr.Render(fmt.Sprintf("%d/%d pasos · %s", done, total, el)))
				} else {
					sb.WriteString(spin + " " + sSubhdr.Render(fmt.Sprintf("%d/%d pasos", done, total)))
				}
			case fDone:
				sb.WriteString(icOk() + " " + sSubhdr.Render(fmt.Sprintf("%d/%d completados", done, total)))
			case fFailed:
				sb.WriteString(icErr() + " " + lipgloss.NewStyle().Foreground(lipgloss.Color("#ef4444")).
					Render(fmt.Sprintf("falló en paso %d/%d", done, total)))
			}
			sb.WriteString("\n\n")

			for _, s := range fd.steps {
				sb.WriteString(renderSubComponent(s, w-2))
				sb.WriteByte('\n')
			}
		}
	}

	if !hasContent {
		return spin + " " + sDim.Render("Esperando primera ficha…")
	}
	return sb.String()
}

// buildColCContent genera el log en vivo con colores del documento y toggle de timestamp.
// Colores: info=#64748b · ok=#22c55e · warn=#f59e0b · err=#ef4444 · step=#475569
// Timestamp [HH:MM:SS] en #334155 — visible solo cuando m.showTimestamp=true
func (m model) buildColCContent(w int) string {
	spin := m.spinner.View()

	// Historial completo — todos los logs sin filtrar por ficha activa
	var logLines []string
	for _, e := range m.logs {
		if m.showTimestamp {
			logLines = append(logLines, e.render(w-2))
		} else {
			logLines = append(logLines, e.renderNoTS(w-2))
		}
	}

	if len(logLines) == 0 {
		activeFD := m.activeficha()
		if activeFD != nil && activeFD.status == fActive {
			logLines = []string{spin + " " + sDim.Render("ejecutando script, esperando output…")}
		} else {
			logLines = []string{sDim.Render("Sin actividad aún…")}
		}
	}

	return strings.Join(logLines, "\n")
}

func (m model) viewInstalling() string {
	switch m.screen {
	case ScreenInstallLog:
		return m.viewFullLog()
	case ScreenInstallErr:
		return m.viewErrorPanel()
	}
	switch m.viewMode {
	case "fulllog":
		return m.viewFullLog()
	case "error":
		return m.viewErrorPanel()
	}
	return m.viewInstallingNormal()
}

func (m model) viewInstallingNormal() string {
	mode := m.mode()
	elapsed := time.Since(m.startTime).Round(time.Second)
	pct := 0
	if m.fichasTotal > 0 {
		pct = m.fichasOK * 100 / m.fichasTotal
		if pct > 100 {
			pct = 100
		}
	}

	// Línea 1: barra de progreso + resumen (ancho bw deja espacio para el texto)
	progLine := m.progBar.View() + sDim.Render(fmt.Sprintf("  %d%%  ·  %d/%d fichas  ·  %s",
		pct, m.fichasOK, m.fichasTotal, elapsed))

	// Línea 2 (solo MD): contadores expandidos con iconos explícitos del documento
	done, running, pending, errored := m.fichaCounters()
	statsLine := fmt.Sprintf("  %s %d completadas   %s %d en curso   %s %d pendientes   %s %d error",
		icOk(), done,
		m.spinner.View(), running,
		icPend(), pending,
		icErr(), errored,
	)

	switch mode {
	case "xs":
		return m.viewInstallingXS(progLine, statsLine)
	case "sm":
		return m.viewInstallingSM(progLine, statsLine)
	default:
		return m.viewInstallingMD(progLine, statsLine)
	}
}

// fichaCounters devuelve contadores de fichas por estado.
func (m model) fichaCounters() (done, running, pending, errored int) {
	for _, ph := range m.phases {
		for _, fid := range ph.fichas {
			fd := m.fichas[fid]
			if fd == nil {
				pending++
				continue
			}
			switch fd.status {
			case fDone:
				done++
			case fActive:
				running++
			case fFailed:
				errored++
			default:
				pending++
			}
		}
	}
	return
}

// XS: todo en una columna compacta
func (m model) viewInstallingXS(progLine, statsLine string) string {
	var lines []string
	lines = append(lines, "\n"+progLine, statsLine, "")

	// Fase actual
	for _, ph := range m.phases {
		st := m.phaseStatus(ph)
		icon := phaseIcon(st)
		active := st == fActive
		line := icon + " " + ph.nombre
		if active {
			lines = append(lines, line)
			// Ficha activa
			for _, fid := range ph.fichas {
				if fd := m.fichas[fid]; fd != nil && fd.status == fActive {
					lines = append(lines, "  " + sCyan.Render("› "+fid))
					if as := fd.activeStep(); as != nil {
						lines = append(lines, "    " + sDim.Render("↳ "+as.name))
					}
				}
			}
		} else {
			lines = append(lines, sDim.Render(line))
		}
	}
	return strings.Join(lines, "\n")
}

// SM: fases + log alternado
func (m model) viewInstallingSM(progLine, statsLine string) string {
	sw := m.safeW()
	var phLines []string
	for _, ph := range m.phases {
		st := m.phaseStatus(ph)
		icon := phaseIcon(st)
		phLines = append(phLines, icon+" "+ph.nombre)
		if st == fActive || st == fDone {
			for _, fid := range ph.fichas {
				if fd := m.fichas[fid]; fd != nil && fd.status != fPending {
					dur := ""
					if fd.status == fDone {
						dur = " " + sDim.Render(formatDur(fd.duration))
					}
					phLines = append(phLines, "  "+fichaIcon(fd.status)+" "+fid+dur)
					if fd.status == fActive {
						if as := fd.activeStep(); as != nil {
							el := time.Since(as.startTime).Round(time.Second)
							phLines = append(phLines,
								"    "+sStepActive.Render("› "+as.name)+" "+sDim.Render(formatDur(el)))
						}
					}
				}
			}
		}
	}

	phasesBlock := sBox.Width(sw).Render(strings.Join(phLines, "\n"))

	// Últimas 6 entradas del log
	logLines := m.lastLogLines(6, sw-4)
	logBlock := sBox.Width(sw).Render(strings.Join(logLines, "\n"))

	return "\n" + progLine + "\n" + statsLine + "\n\n" +
		lipgloss.JoinVertical(lipgloss.Left, phasesBlock, logBlock)
}

// MD: tres columnas con viewport.Model — fases | pasos del activo | log en vivo.
// El scroll lo maneja cada viewport; Tab cambia el foco activo.
// Layout: progLine + statsLine + [panelA|panelB|panelC] + nav
// Total vertical = 14 overhead (ver vpDims) + vpH del viewport.
func (m model) viewInstallingMD(progLine, statsLine string) string {
	if !m.vpReady {
		return progLine + "\n" + statsLine + "\n" + sDim.Render("  Iniciando paneles…")
	}

	wA, wB, wC, vpH := m.vpDims()

	// Título: texto blanco en negrita, sin fondo
	sColTitle := lipgloss.NewStyle().Foreground(lipgloss.Color("#ffffff")).Bold(true)
	sTitleDim  := lipgloss.NewStyle().Foreground(lipgloss.Color("#94a3b8"))

	makeTitle := func(i int, vp viewport.Model, label string) string {
		text := label
		if vp.TotalLineCount() > vp.Height {
			pct := int(vp.ScrollPercent() * 100)
			text += fmt.Sprintf(" %d%%", pct)
		}
		if m.installingFocus == i {
			return sColTitle.Render(text)
		}
		return sTitleDim.Render(text)
	}

	titleA := makeTitle(0, m.vpA, " Fases y Fichas")
	titleB := makeTitle(1, m.vpB, " Componentes instalados")
	// Extras del título C como string plano en un solo Render (evita ANSI ambiguous-width)
	titleCBase := " Log en vivo"
	titleCExtras := ""
	if m.vpAutoScroll {
		titleCExtras += " auto"
	}
	if m.showTimestamp {
		titleCExtras += " [T]"
	}
	titleC := makeTitle(2, m.vpC, titleCBase)
	if titleCExtras != "" {
		titleC += sDim.Render(titleCExtras)
	}

	// Borde: verde (#22c55e) sin foco, cyan (#06b6d4) con foco
	colBorderNormal := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(cGreen).
		Padding(0, 1)
	colBorderFocus := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(cCyan).
		Padding(0, 1)

	borderOf := func(i int) lipgloss.Style {
		if m.installingFocus == i {
			return colBorderFocus
		}
		return colBorderNormal
	}

	// ColA — viewport(wA-1) + scrollbar vertical(1) = wA total
	scrollA := vScrollbar(m.vpA, vpH)
	viewA := lipgloss.JoinHorizontal(lipgloss.Top, m.vpA.View(), scrollA)
	// Todos usan vpH — sin hScrollbar, altura natural idéntica en los 3 paneles
	panelA := borderOf(0).Width(wA).Render(titleA + "\n" + viewA)

	// ColB
	colBContent := m.vpB.View()
	if m.wsConn == nil && !demoMode && m.fichasOK == 0 {
		colBContent = sYellow.Render("  ⚠  Daemon bos no conectado") + "\n\n" +
			sDim.Render("  Verifique:\n\n    systemctl status bos\n    systemctl start bos")
	}
	scrollBV := vScrollbar(m.vpB, vpH)
	viewB := lipgloss.JoinHorizontal(lipgloss.Top, colBContent, scrollBV)
	panelB := borderOf(1).Width(wB).Render(titleB + "\n" + viewB)

	// ColC
	scrollCV := vScrollbar(m.vpC, vpH)
	viewC := lipgloss.JoinHorizontal(lipgloss.Top, m.vpC.View(), scrollCV)
	panelC := borderOf(2).Width(wC).Render(titleC + "\n" + viewC)

	cols := lipgloss.JoinHorizontal(lipgloss.Top, panelA, panelB, panelC)

	return progLine + "\n" + statsLine + "\n" + cols
}

// activePhaseLineIdx devuelve el índice aproximado de la fase activa en columna A.
func (m model) activePhaseLineIdx() int {
	line := 2 // encabezado "Fases de instalación:" + blank
	for _, ph := range m.phases {
		st := m.phaseStatus(ph)
		if st == fActive {
			return line
		}
		line++ // línea de la fase
		for range ph.fichas {
			line++
		}
		line++ // blank entre fases
	}
	return 0
}

// clipColumnCenter recorta lines a maxH centrado alrededor de focusLine (scroll en A).
func clipColumnCenter(lines []string, maxH, focusLine int) []string {
	total := len(lines)
	if total <= maxH {
		return padLines(lines, maxH)
	}
	// Intentar centrar focusLine con contexto arriba/abajo
	half := maxH / 2
	start := focusLine - half
	if start < 0 {
		start = 0
	}
	if start+maxH > total {
		start = total - maxH
	}
	return lines[start : start+maxH]
}

// clipColumnTail recorta lines a maxH mostrando siempre el final.
// Si withScrollbar=true, agrega indicador de scroll en la última línea visible.
func clipColumnTail(lines []string, maxH int, withScrollbar bool) []string {
	total := len(lines)
	var visible []string
	if total <= maxH {
		visible = padLines(lines, maxH)
	} else {
		visible = make([]string, maxH)
		copy(visible, lines[total-maxH:])
	}
	if withScrollbar && total > maxH {
		thumbH := maxInt(1, maxH*maxH/total)
		thumbStart := maxH - thumbH
		for i := range visible {
			var bar string
			if i >= thumbStart {
				bar = lipgloss.NewStyle().Foreground(cCyan).Render("▐")
			} else {
				bar = lipgloss.NewStyle().Foreground(cDim).Render("╎")
			}
			visible[i] = visible[i] + bar
		}
	}
	return visible
}

// padLines rellena un slice hasta maxH con líneas vacías.
func padLines(lines []string, maxH int) []string {
	result := make([]string, maxH)
	copy(result, lines)
	return result
}

// filteredLogs retorna las entradas filtradas por nivel, source y búsqueda (doc §P5B, §P10).
func (m model) filteredLogs() []logEntry {
	var out []logEntry
	for _, e := range m.logs {
		if m.logFilter != logInfo && e.level != m.logFilter {
			continue
		}
		if m.logSource != "" &&
			!strings.EqualFold(e.ficha, m.logSource) {
			continue
		}
		if m.logSearch != "" &&
			!strings.Contains(strings.ToLower(e.msg), strings.ToLower(m.logSearch)) &&
			!strings.Contains(strings.ToLower(e.ficha), strings.ToLower(m.logSearch)) {
			continue
		}
		out = append(out, e)
	}
	return out
}

// highlightMatch resalta la primera ocurrencia de needle en line con fondo #0e3a1a (doc §P5B).
func highlightMatch(line, needle string) string {
	if needle == "" {
		return line
	}
	lower := strings.ToLower(line)
	idx := strings.Index(lower, strings.ToLower(needle))
	if idx < 0 {
		return line
	}
	matchStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#bbf7d0")).
		Background(lipgloss.Color("#0e3a1a"))
	return line[:idx] + matchStyle.Render(line[idx:idx+len(needle)]) + line[idx+len(needle):]
}

// Panel de log completo (tecla L) — P5B (doc §P5B L1612-L1663)
func (m model) viewFullLog() string {
	// P5C: panel de error detallado (tecla E)
	if m.screen == ScreenInstallErr {
		return m.viewErrorPanel()
	}

	// ── Toolbar (1 línea fija) ─────────────────────────────────────────────
	type filterBtn struct {
		label  string
		level  logLevel
		active lipgloss.Color
	}
	btns := []filterBtn{
		{"Todos", logInfo, lipgloss.Color("#38bdf8")},
		{"✓ OK", logOK, lipgloss.Color("#22c55e")},
		{"⚠ Warn", logWarn, lipgloss.Color("#f59e0b")},
		{"✗ Error", logError, lipgloss.Color("#ef4444")},
	}
	var btnParts []string
	for _, b := range btns {
		active := m.logFilter == b.level || (b.level == logInfo && m.logFilter == logInfo)
		if active {
			btnParts = append(btnParts, lipgloss.NewStyle().
				Foreground(b.active).Bold(true).
				Underline(true).Render(b.label))
		} else {
			btnParts = append(btnParts, sDim.Render(b.label))
		}
	}
	filterRow := strings.Join(btnParts, "  ")

	// Contador de líneas visibles (doc §P5B L1628)
	filtered := m.filteredLogs()
	counter := lipgloss.NewStyle().Foreground(cMuted).
		Render(strconv.Itoa(len(filtered)) + " líneas")

	// Búsqueda integrada en toolbar
	searchPart := ""
	if m.logSearch != "" {
		searchPart = "  " + sDim.Render("/") + " " +
			lipgloss.NewStyle().Foreground(cCyan).Render(m.logSearch)
	}

	// Toolbar en 1 línea: filtros | búsqueda [    ...    ] contador
	toolbarInner := filterRow + searchPart
	padLen := m.width - lipgloss.Width(toolbarInner) - lipgloss.Width(counter) - 2
	if padLen < 1 {
		padLen = 1
	}
	toolbar := toolbarInner + strings.Repeat(" ", padLen) + counter

	// ── Viewport de log (el resto del body) ───────────────────────────────
	vp := m.vpLog
	vp.Height = m.bodyHeight - 1
	if vp.Height < 2 {
		vp.Height = 2
	}
	var logLines []string
	for _, e := range filtered {
		var line string
		if m.showTimestamp {
			line = e.render(m.width - 2)
		} else {
			line = e.renderNoTS()
		}
		if m.logSearch != "" {
			line = highlightMatch(line, m.logSearch)
		}
		logLines = append(logLines, line)
	}
	if len(logLines) == 0 {
		logLines = []string{sDim.Render("Sin logs disponibles")}
	}
	vp.SetContent(strings.Join(logLines, "\n"))
	return lipgloss.JoinVertical(lipgloss.Left, toolbar, vp.View())
}

// Panel de error detallado — P5C (doc §P5C L1667-L1721).
// Layout: columna principal(flex1) + panel lateral(32 chars).
func (m model) viewErrorPanel() string {
	if m.errPanel == nil {
		return ""
	}
	fd := m.errPanel

	// ── Contadores del panel lateral ───────────────────────────────────────
	var cntDone, cntPending, cntFailed int
	for _, f := range m.fichas {
		switch f.status {
		case fDone:
			cntDone++
		case fPending:
			cntPending++
		case fFailed:
			cntFailed++
		}
	}
	cntWarn := 0 // advertencias: no hay tipo diferenciado aún
	_ = cntWarn

	// ── Menú lateral con foco `›` ─────────────────────────────────────────
	errOpts := []string{
		"Reintentar ficha",
		"Saltar ficha",
		"Ver log completo",
		"Cancelar instalación",
	}
	errColors := []lipgloss.Color{
		cCyan,
		lipgloss.Color("#f59e0b"),
		cDim,
		lipgloss.Color("#ef4444"),
	}
	var menuLines []string
	for i, opt := range errOpts {
		if i == m.errFocus {
			menuLines = append(menuLines,
				lipgloss.NewStyle().Foreground(errColors[i]).Bold(true).
					Render("› "+opt),
			)
		} else {
			menuLines = append(menuLines, sDim.Render("  "+opt))
		}
	}

	mode := m.mode()
	sideW := 32
	if mode == "xs" {
		sideW = 0
	} else if mode == "sm" {
		sideW = 22
	}
	leftW := m.width - sideW - 1
	if sideW == 0 {
		leftW = m.width
	}

	// ── Causa del error ───────────────────────────────────────────────────
	causeStyle := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("#7f1d1d")).
		Background(lipgloss.Color("#1a0808")).
		Width(leftW - 2).Padding(0, 1)
	var causeLines []string
	if fd.errMsg != "" {
		for _, l := range strings.Split(wordWrap(fd.errMsg, leftW-6), "\n") {
			causeLines = append(causeLines,
				lipgloss.NewStyle().Foreground(lipgloss.Color("#fca5a5")).Render(l),
			)
		}
	} else {
		causeLines = []string{sDim.Render("Sin información de causa")}
	}
	causeBox := causeStyle.Render(
		lipgloss.NewStyle().Foreground(lipgloss.Color("#ef4444")).Bold(true).Render("✗ Causa") + "\n" +
			strings.Join(causeLines, "\n"),
	)

	// ── Pasos ejecutados ──────────────────────────────────────────────────
	var stepsLines []string
	stepsLines = append(stepsLines,
		lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Pasos ejecutados"),
	)
	for _, s := range fd.steps {
		stepsLines = append(stepsLines, renderStep(s, leftW-4))
	}
	stepsBlock := strings.Join(stepsLines, "\n")

	// ── Log reciente (últimas entradas de la ficha en error) ──────────────
	var recentLines []string
	for _, e := range m.logs {
		if strings.EqualFold(e.ficha, fd.id) {
			recentLines = append(recentLines, e.renderNoTS())
		}
	}
	if len(recentLines) > 12 {
		recentLines = recentLines[len(recentLines)-12:]
	}
	recentStyle := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(cBg3).Width(leftW - 2)
	recentBox := ""
	if len(recentLines) > 0 {
		recentBox = recentStyle.Render(strings.Join(recentLines, "\n"))
	}

	// ── Columna principal ─────────────────────────────────────────────────
	mainParts := []string{causeBox, "", stepsBlock}
	if recentBox != "" {
		mainParts = append(mainParts, "", recentBox)
	}
	mainCol := strings.Join(mainParts, "\n")

	if sideW == 0 {
		return mainCol
	}

	// ── Panel lateral ─────────────────────────────────────────────────────
	sideLines := []string{
		lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Estado"),
		"",
		summaryRow("✅ Listas", strconv.Itoa(cntDone)),
		summaryRow("⏳ Pend.", strconv.Itoa(cntPending)),
		summaryRow("✗ Error", strconv.Itoa(cntFailed+1)), // +1 la actual
		"",
		sDim.Render("───"),
		"",
		lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Acciones"),
		"",
	}
	sideLines = append(sideLines, menuLines...)
	sideContent := strings.Join(sideLines, "\n")
	sidePanel := sBox.Width(sideW).Render(sideContent)

	return lipgloss.JoinHorizontal(lipgloss.Top, mainCol, " ", sidePanel)
}

// ── Pantalla 6 — Completado ─────────────────────────────────────────────────

func (m model) viewComplete() string {
	return m.viewCompleteTabBar() + "\n\n" + m.viewCompleteBody()
}

func (m model) viewCompleteTabBar() string {
	tabs := []string{"Tenant", "Ubuntu", "Kubernetes", "SBOS / bos"}
	var tabParts []string
	for i, t := range tabs {
		if i == m.completeFocus {
			tabParts = append(tabParts, lipgloss.NewStyle().Foreground(cCyan).Bold(true).
				Background(lipgloss.Color("#0f2433")).Padding(0, 1).Render("› "+t))
		} else {
			tabParts = append(tabParts, lipgloss.NewStyle().Foreground(cSlate).Padding(0, 1).Render(t))
		}
	}
	return lipgloss.JoinHorizontal(lipgloss.Top, tabParts...)
}

func (m model) viewCompleteBody() string {
	mode := m.mode()
	dom := m.tenantInputs[3].Value()
	email := m.adminInputs[0].Value()
	elapsed := time.Since(m.startTime).Round(time.Second)
	cta := "\n" + sGreen.Render("  [ Enter ] Salir al terminal   [ ←→ ] Cambiar sección")

	sideW := 28
	if mode == "xs" || mode == "sm" {
		sideW = 0
	}
	mainW := m.width - sideW - 2
	if sideW == 0 {
		mainW = m.width
	}

	// buildCols ensambla las 2 columnas y añade el cta
	buildCols := func(mainLines, sideLines []string) string {
		main := strings.Join(mainLines, "\n")
		if sideW == 0 {
			return main + cta
		}
		side := sBox.Width(sideW).Render(strings.Join(sideLines, "\n"))
		return lipgloss.JoinHorizontal(lipgloss.Top,
			lipgloss.NewStyle().Width(mainW).Render(main), side,
		) + cta
	}

	switch m.completeFocus {
	// ── Sección 0: Tenant ─────────────────────────────────────────────────
	case 0:
		var cntDone, cntFailed int
		for _, f := range m.fichas {
			if f.status == fDone {
				cntDone++
			} else if f.status == fFailed {
				cntFailed++
			}
		}
		main := []string{
			sGreen.Bold(true).Render("✓ SBOS instalado — " + dom),
			"",
			summaryRow("Email", email),
			summaryRow("Duración", elapsed.String()),
			summaryRow("Fichas", fmt.Sprintf("%d/%d", m.fichasOK, m.fichasTotal)),
			"",
			lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Acceso"),
			"",
			sDim.Render("Panel:    ") + sGreen.Render("https://"+dom),
			sDim.Render("Grafana:  ") + sGreen.Render("https://"+dom+"/monitor"),
			sDim.Render("IAM:      ") + sGreen.Render("https://"+dom+"/auth"),
			"",
			lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Próximos pasos"),
			"",
			sDim.Render("• Configure impuestos en SmartTax"),
			sDim.Render("• Agregue empleados en OrangeHRM"),
			sDim.Render("• Active backup automático en MinIO"),
			sDim.Render("• Configure SPIs de autenticación en Keycloak"),
		}
		side := []string{
			lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Resumen"),
			"",
			sGreen.Render(strconv.Itoa(cntDone)) + sDim.Render(" completadas"),
			sRed.Render(strconv.Itoa(cntFailed)) + sDim.Render(" fallidas"),
			"",
			sDim.Render("Realm KC: " + dom),
			sDim.Render("NS K8s:   sbos-" + dom),
			"",
			lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Log"),
			"",
			sDim.Render("/var/log/bos/bootstrap.log"),
		}
		return buildCols(main, side)

	// ── Sección 1: Ubuntu ─────────────────────────────────────────────────
	case 1:
		main := []string{
			sBold.Render("Sistema Operativo"),
			"",
			summaryRow("SO", "Ubuntu Server 26.04 LTS"),
			summaryRow("Kernel", "7.0.0-22-generic"),
			summaryRow("Arch", "x86_64"),
			"",
			lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Servicios"),
			"",
			sGreen.Render("✓") + sDim.Render(" containerd 2.1.x"),
			sGreen.Render("✓") + sDim.Render(" systemd 257"),
			sGreen.Render("✓") + sDim.Render(" sysctl hardening (ISO 27001 A.8.8)"),
			sGreen.Render("✓") + sDim.Render(" ufw activo — puertos 22/80/443 only"),
			sGreen.Render("✓") + sDim.Render(" fail2ban activo"),
			sGreen.Render("✓") + sDim.Render(" unattended-upgrades habilitado"),
			"",
			lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("bos.service (systemd)"),
			"",
			sGreen.Render("✓") + sDim.Render(" active (running) — user=bosagent"),
			sDim.Render("  Socket: /run/bos/bos.sock (0660)"),
			sDim.Render("  TCP:    0.0.0.0:9443 (HTTPS)"),
		}
		side := []string{
			lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Estándares"),
			"",
			sDim.Render("ISA-95 L0–L4"),
			sDim.Render("NIST 800-207"),
			sDim.Render("ISO 27001:2022"),
			sDim.Render("CIS Ubuntu Benchmark"),
			sDim.Render("NSA/CISA K8s Hardening"),
		}
		return buildCols(main, side)

	// ── Sección 2: Kubernetes ─────────────────────────────────────────────
	case 2:
		main := []string{
			sBold.Render("Kubernetes"),
			"",
			summaryRow("k3s", "v1.32+"),
			summaryRow("CNI", "Calico 3.32.0"),
			summaryRow("CRI", "containerd 2.1.x"),
			summaryRow("DNS", "CoreDNS 1.11+"),
			"",
			lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Control Plane"),
			"",
			sGreen.Render("✓") + sDim.Render(" Linkerd 2.x mTLS — service mesh"),
			sGreen.Render("✓") + sDim.Render(" Kyverno — políticas de seguridad"),
			sGreen.Render("✓") + sDim.Render(" MetalLB — LoadBalancer L2"),
			sGreen.Render("✓") + sDim.Render(" Kong 3.9.x LTS — API Gateway"),
			sGreen.Render("✓") + sDim.Render(" Vault 2.0.1 — secretos"),
			sGreen.Render("✓") + sDim.Render(" Keycloak 26.6.2 — IAM"),
			sGreen.Render("✓") + sDim.Render(" PostgreSQL 18.4 HA"),
			sGreen.Render("✓") + sDim.Render(" Redis 8.6.2"),
		}
		side := []string{
			lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Context Plane"),
			"",
			sDim.Render("tenant:  " + dom),
			sDim.Render("cluster: cluster-sbos"),
			sDim.Render("node:    node-01"),
			sDim.Render("ns:      sbos-" + dom),
			"",
			lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Red"),
			"",
			sDim.Render("ClusterIP: 10.43.0.0/16"),
			sDim.Render("Pod CIDR:  10.42.0.0/16"),
		}
		return buildCols(main, side)

	// ── Sección 3: SBOS / bos ─────────────────────────────────────────────
	default:
		main := []string{
			sBold.Render("Daemons soberanos"),
			"",
			sGreen.Render("✓ bKernel") + sDim.Render(" — WAL listener · Fanout Redis Streams · MDM"),
			sGreen.Render("✓ bAuth  ") + sDim.Render(" — BitMask 64-bit · 5 SPIs Java · ~5ms"),
			sGreen.Render("✓ bSearch") + sDim.Render(" — PostgreSQL 18+ GIN · WebSocket wss://"),
			sGreen.Render("✓ biedata") + sDim.Render(" — JSON-RPC 2.0 · fichas declarativas"),
			sGreen.Render("✓ bhnexus") + sDim.Render(" — WebSocket mTLS · OSDP/MQTT · ~2ms"),
			sGreen.Render("✓ banexus") + sDim.Render(" — udev intercept · actuadores · ~15ms"),
			sDim.Render("○ bnotify") + lipgloss.NewStyle().Foreground(cYellow).Render(" — pendiente (sbos-notifier)"),
			"",
			lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Observabilidad"),
			"",
			sGreen.Render("✓") + sDim.Render(" Grafana · Prometheus · Loki · Alloy"),
			"",
			lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Context Plane (SBOS-049)"),
			"",
			sDim.Render("ctx_id:  activo — W3C TraceContext + OTel Baggage"),
			sDim.Render("owner:   bos (IAM Installer)"),
			sDim.Render("socket:  /run/bos/bos.sock"),
		}
		side := []string{
			lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("Estándares"),
			"",
			sDim.Render("W3C Trace Context"),
			sDim.Render("OpenTelemetry Baggage"),
			sDim.Render("NIST 800-207 ZeroTrust"),
			sDim.Render("ISO 27001:2022"),
			sDim.Render("IANA RFC 6335/7605"),
			"",
			lipgloss.NewStyle().Foreground(cDim).Italic(true).Render("ctx_id (parcial)"),
			"",
			sDim.Render("tenant: " + dom),
			sDim.Render("realm:  " + dom),
			sDim.Render("pod:    bos-0"),
		}
		return buildCols(main, side)
	}
}

// ── Pantallas nuevas ───────────────────────────────────────────────────────

func (m model) viewSplashWelcome() string {
	w := m.width
	if w == 0 {
		w = 80
	}

	skull := lipgloss.NewStyle().Bold(true).Foreground(cWhite).
		Width(w).Align(lipgloss.Center).
		Render("S K U L L")

	sub1 := lipgloss.NewStyle().Foreground(cSlate).
		Width(w).Align(lipgloss.Center).
		Render("SOVEREIGN KERNEL & UNIFIED LOGIC LAYER")

	sub2 := lipgloss.NewStyle().Foreground(lipgloss.Color("#1e3a5f")).Italic(true).
		Width(w).Align(lipgloss.Center).
		Render("\"Certificamos mejora continua\"")

	sep := lipgloss.NewStyle().Foreground(cBg3).Width(w).Align(lipgloss.Center).
		Render(strings.Repeat("─", w/2))

	product := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#4ade80")).
		Width(w).Align(lipgloss.Center).
		Render("SBOS v1.0 GA")

	productSub := lipgloss.NewStyle().Foreground(cSlate).
		Width(w).Align(lipgloss.Center).
		Render("SISTEMA OPERATIVO EMPRESARIAL SOBERANO")

	tenantName := m.tenantInputs[0].Value()
	if tenantName == "" {
		tenantName = "skull-sksistemas"
	}
	contextLine := lipgloss.NewStyle().Foreground(cMuted).Width(w).Align(lipgloss.Center).
		Render(fmt.Sprintf("Tenant %s · Node node-01 · Cluster cluster-sbos", tenantName))

	pct := int(m.bootPct * 100)
	barWidth := w - 20
	if barWidth < 20 {
		barWidth = 20
	}
	filled := int(float64(barWidth) * m.bootPct)
	empty := barWidth - filled
	progressBar := "[" + strings.Repeat("█", filled) + strings.Repeat("░", empty) + "]"

	bootLine := lipgloss.NewStyle().Foreground(cGreen).Width(w).Align(lipgloss.Center).
		Render(fmt.Sprintf("%s %3d%%  %s", progressBar, pct, m.bootMsg))

	legal1 := lipgloss.NewStyle().Foreground(cGreen).Faint(true).Width(w).Align(lipgloss.Center).
		Render("© 2026 SKULL — Sovereign Kernel & Unified Logic Layer")
	legal2 := lipgloss.NewStyle().Foreground(cBg3).Width(w).Align(lipgloss.Center).
		Render("Powered by SKULL · SBOS v1.0 GA · Sep 2026 · ISA-95 · NIST 800-207 · ISO 27001")
	legal3 := lipgloss.NewStyle().Foreground(lipgloss.Color("#0f2433")).Width(w).Align(lipgloss.Center).
		Render("ALL COMPONENTS SIGNED WITH Ed25519 · SOVEREIGN · NO DATA LEAVES THIS NODE")

	body := lipgloss.JoinVertical(lipgloss.Center,
		skull, sub1, sub2,
		"\n", sep, "\n",
		product, productSub,
		"\n",
		contextLine,
		"\n",
		bootLine,
	)
	footer := lipgloss.JoinVertical(lipgloss.Center, legal1, legal2, legal3)

	bodyLines := strings.Count(body, "\n") + 1
	footerLines := strings.Count(footer, "\n") + 1
	total := bodyLines + 2 + footerLines // 2 = separación body-footer
	pad := (m.height - total) / 2
	if pad < 1 {
		pad = 1
	}

	return lipgloss.JoinVertical(lipgloss.Center,
		strings.Repeat("\n", pad),
		body,
		"\n",
		footer,
	)
}

func (m model) viewSplashGoodbye() string {
	w := m.width
	if w == 0 {
		w = 80
	}

	goodbye := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#1e3a5f")).
		Width(w).Align(lipgloss.Center).
		Render("G O O D  B Y E")

	skull := lipgloss.NewStyle().Bold(true).Foreground(cSlate).
		Width(w).Align(lipgloss.Center).
		Render("\nS K U L L")

	sub1 := lipgloss.NewStyle().Foreground(cBg3).
		Width(w).Align(lipgloss.Center).
		Render("SOVEREIGN KERNEL & UNIFIED LOGIC LAYER")

	sub2 := lipgloss.NewStyle().Foreground(lipgloss.Color("#1e3a5f")).Italic(true).
		Width(w).Align(lipgloss.Center).
		Render("\"Certificamos mejora continua\"")

	sep := lipgloss.NewStyle().Foreground(cBg3).Width(w).Align(lipgloss.Center).
		Render(strings.Repeat("─", w/2))

	now := time.Now()
	sessionStart := m.startTime
	if sessionStart.IsZero() {
		sessionStart = now.Add(-time.Minute * 5)
	}
	fichasStr := fmt.Sprintf("%d / %d OK", m.fichasOK, m.fichasTotal)
	if m.fichasTotal == 0 {
		fichasStr = "22 / 22 OK"
	}
	sessionInfo := lipgloss.JoinVertical(lipgloss.Left,
		sLabel.Render("Tenant")+"        skull-sksistemas",
		sLabel.Render("Sesión")+"        ctx-"+now.Format("05040302"),
		sLabel.Render("Inicio")+"        "+sessionStart.Format("2006-01-02  15:04:05"),
		sLabel.Render("Fin")+"          "+now.Format("2006-01-02  15:04:05"),
		sLabel.Render("Duración")+"     "+formatDur(now.Sub(sessionStart)),
		sLabel.Render("Fichas activas")+" "+fichasStr,
		sLabel.Render("Apagado")+"      ordenado — sin errores",
	)

	boxW := w * 55 / 100
	if boxW < 48 {
		boxW = 48
	}
	if boxW > 70 {
		boxW = 70
	}
	summaryBox := sBox.Width(boxW).Render(sessionInfo)
	summaryC := lipgloss.NewStyle().Width(w).Align(lipgloss.Center).Render(summaryBox)

	savedMsg := lipgloss.NewStyle().Foreground(cBg3).Width(w).Align(lipgloss.Center).
		Render("Todos los datos han sido guardados y los secretos sellados")

	legal1 := lipgloss.NewStyle().Foreground(cGreen).Faint(true).Width(w).Align(lipgloss.Center).
		Render("© 2026 SKULL — Sovereign Kernel & Unified Logic Layer")
	legal2 := lipgloss.NewStyle().Foreground(cBg3).Width(w).Align(lipgloss.Center).
		Render("Powered by SKULL · SBOS v1.0 GA · ISA-95 · NIST 800-207 · ISO 27001")
	legal3 := lipgloss.NewStyle().Foreground(lipgloss.Color("#0f2433")).Width(w).Align(lipgloss.Center).
		Render("ALL COMPONENTS SIGNED WITH Ed25519 · SOVEREIGN · NO DATA LEAVES THIS NODE")

	body := lipgloss.JoinVertical(lipgloss.Center,
		goodbye,
		skull, sub1, sub2,
		"\n", sep, "\n",
		summaryC,
		"\n",
		savedMsg,
	)
	footer := lipgloss.JoinVertical(lipgloss.Center, legal1, legal2, legal3)

	bodyLines := strings.Count(body, "\n") + 1
	footerLines := strings.Count(footer, "\n") + 1
	total := bodyLines + 2 + footerLines
	pad := (m.height - total) / 2
	if pad < 1 {
		pad = 1
	}

	return lipgloss.JoinVertical(lipgloss.Center,
		strings.Repeat("\n", pad),
		body,
		"\n",
		footer,
	)
}

func (m model) viewReboot() string {
	w := m.width
	if w == 0 {
		w = 80
	}

	cntStyle := lipgloss.NewStyle().Bold(true).Foreground(cCyan).
		Width(w).Align(lipgloss.Center)
	cntStr := cntStyle.Render(fmt.Sprintf("\n\n  ↺  Reiniciando en  %d  segundos\n\n", m.countdownSec))

	barW := w - 20
	if barW < 20 {
		barW = 20
	}
	filled := int(float64(barW) * float64(10-m.countdownSec) / 10.0)
	if filled < 0 {
		filled = 0
	}
	if filled > barW {
		filled = barW
	}
	empty := barW - filled
	bar := lipgloss.NewStyle().Foreground(cCyan).Width(w).Align(lipgloss.Center).
		Render("[" + strings.Repeat("█", filled) + strings.Repeat("░", empty) + "]")

	logLines := lipgloss.NewStyle().Foreground(cMuted).
		Width(w).Align(lipgloss.Left).
		PaddingLeft(4)
	var logs []string
	if m.countdownSec <= 9 {
		logs = append(logs, icOk()+" Guardando configuración en /etc/sbos/tenant.conf")
	}
	if m.countdownSec <= 8 {
		logs = append(logs, icOk()+" Escribiendo /etc/systemd/system/bos.service")
	}
	if m.countdownSec <= 7 {
		logs = append(logs, icOk()+" Habilitando bos.service — levanta después de k8s.target")
	}
	if m.countdownSec <= 6 {
		logs = append(logs, sDim.Render("  Registrando ctx_id de instalación"))
	}
	if m.countdownSec <= 5 {
		logs = append(logs, icOk()+" Log guardado en /var/log/sbos/install.log")
	}
	if m.countdownSec <= 4 {
		logs = append(logs, sDim.Render("  Sincronizando filesystem..."))
	}
	if m.countdownSec <= 2 {
		logs = append(logs, icOk()+" Sistema listo para reinicio")
	}
	if m.countdownSec <= 1 {
		logs = append(logs, sDim.Render("  systemctl reboot — iniciando secuencia..."))
	}

	logsBlock := logLines.Render(strings.Join(logs, "\n"))

	hint := sDim.Render(fmt.Sprintf("\n  [Enter] reiniciar ahora  [Esc] cancelar"))
	hintC := lipgloss.NewStyle().Width(w).Align(lipgloss.Center).Render(hint)

	return lipgloss.JoinVertical(lipgloss.Left, cntStr, bar, "\n", logsBlock, hintC)
}

func (m model) viewBoot() string {
	bootSeq := []struct{ group, items string }{
		{"Ubuntu", "kernel · containerd · systemd · red"},
		{"Kubernetes", "etcd → apiserver → scheduler → controller → kubelet → Calico → Linkerd"},
		{"Stack de datos", "postgresql (Patroni) → redis → minio"},
		{"Seguridad", "vault → keycloak → kong"},
		{"Daemons SBOS", "bKernel → bAuth → bSearch → bCompass → biedata → bhnexus → banexus"},
		{"Context Plane", "Context Registry → JSON-RPC socket → ctx_id"},
	}

	// doc §P8: panel derecho 210px fijo (≈28 chars), izquierdo flex1
	sideW := 28
	if m.width < 70 {
		sideW = 0
	}
	mainW := m.width - sideW - 2
	if sideW == 0 {
		mainW = m.width
	}

	// ── Panel izquierdo: secuencia de arranque ────────────────────────────
	var seqLines []string
	for i, seq := range bootSeq {
		stepPct := float64(i) / float64(len(bootSeq))
		var icon string
		if m.bootPct >= (float64(i+1) / float64(len(bootSeq))) {
			icon = icOk()
		} else if m.bootPct >= stepPct {
			icon = m.spinner.View()
		} else {
			icon = icPend()
		}
		groupStyle := lipgloss.NewStyle().Foreground(cWhite).Bold(true)
		itemStyle := lipgloss.NewStyle().Foreground(cMuted)
		seqLines = append(seqLines,
			icon+" "+groupStyle.Render(seq.group),
			"   "+itemStyle.Render(seq.items),
			"",
		)
	}
	mainPanel := sBox.Width(mainW).Render(strings.Join(seqLines, "\n"))

	if sideW == 0 {
		return mainPanel
	}

	// ── Panel derecho: progreso + info (doc §P8 L1907-L1910) ─────────────
	barW := sideW - 4
	if barW < 8 {
		barW = 8
	}
	filled := int(float64(barW) * m.bootPct)
	if filled > barW {
		filled = barW
	}
	pct := int(m.bootPct * 100)
	bar := sGreen.Render(strings.Repeat("█", filled)) +
		sDim.Render(strings.Repeat("░", barW-filled))
	barLine := fmt.Sprintf("[%s] %3d%%", bar, pct)

	msg := m.bootMsg
	if msg == "" {
		msg = "Iniciando..."
	}
	elapsed := ""
	if !m.startTime.IsZero() {
		elapsed = formatDur(time.Since(m.startTime).Round(time.Second))
	}
	tenantName := m.tenantInputs[0].Value()
	if tenantName == "" {
		tenantName = "sbos"
	}

	// Estado actual: qué servicio está levantando
	currentStep := sDim.Render(msg)
	if pct >= 100 {
		currentStep = sGreen.Render("✓ Sistema listo")
	}

	sideContent := lipgloss.JoinVertical(lipgloss.Left,
		lipgloss.NewStyle().Foreground(cCyan).Bold(true).Render("Arranque SBOS"),
		"",
		barLine,
		"",
		summaryRow("Tenant", tenantName),
		summaryRow("Node", "node-01"),
		summaryRow("Cluster", "cluster-sbos"),
		"",
		sDim.Render("Elapsed: "+elapsed),
		"",
		currentStep,
	)
	sidePanel := sBox.Width(sideW).Render(sideContent)

	return lipgloss.JoinHorizontal(lipgloss.Top, mainPanel, sidePanel)
}

func (m model) viewDashboard() string {
	// doc §P9: columna derecha 220px fija (≈30 chars), columna central flex1
	sideW := 30
	if m.width < 70 {
		sideW = 0
	}
	mainW := m.width - sideW - 1
	if sideW == 0 {
		mainW = m.width
	}

	// ── Columna central ───────────────────────────────────────────────────
	headerLine := icBos() + " " +
		lipgloss.NewStyle().Bold(true).Foreground(cWhite).Render("bos") + "  " +
		sDim.Render("daemon activo  ·  uptime "+formatDur(m.dashUptime))

	statusLine := icOk() + " " + sGreen.Render("Todos los servicios operativos")

	// Grid daemons: 2 columnas, 7 daemons (doc §P9)
	daemons := []struct{ name, port string }{
		{"bKernel", ":9460"}, {"bAuth", ":9450"},
		{"bSearch", ":9493"}, {"biedata", ":9470"},
		{"bhnexus", ":9444"}, {"banexus", "local"},
		{"bnotify", ":28200"},
	}
	colW := (mainW - 4) / 2
	var daemonLines []string
	for i := 0; i < len(daemons); i += 2 {
		left := icOk() + " " + lipgloss.NewStyle().Foreground(cWhite).Width(10).
			Render(daemons[i].name) + sDim.Render(daemons[i].port)
		if i+1 < len(daemons) {
			right := icOk() + " " + lipgloss.NewStyle().Foreground(cWhite).Width(10).
				Render(daemons[i+1].name) + sDim.Render(daemons[i+1].port)
			daemonLines = append(daemonLines,
				lipgloss.JoinHorizontal(lipgloss.Top,
					lipgloss.NewStyle().Width(colW).Render(left), right,
				),
			)
		} else {
			daemonLines = append(daemonLines, left)
		}
	}

	tenantName := m.tenantInputs[0].Value()
	if tenantName == "" {
		tenantName = "sbos"
	}
	ctxBox := sBox.Width(mainW - 2).Render(lipgloss.JoinVertical(lipgloss.Left,
		sDim.Render("ctx_id: activo — W3C TraceContext + OTel Baggage"),
		summaryRow("Tenant", tenantName),
		sDim.Render("Context Plane ✓  ·  JSON-RPC ✓"),
	))

	mainContent := lipgloss.JoinVertical(lipgloss.Left,
		headerLine, "",
		statusLine, "",
		strings.Join(daemonLines, "\n"), "",
		ctxBox,
	)

	if sideW == 0 {
		return mainContent
	}

	// ── Columna derecha: log en vivo + 3 botones (doc §P9 L1940-L1946) ───
	liveLabel := lipgloss.NewStyle().Foreground(cGreen).Bold(true).Render("● LIVE") + " " +
		sDim.Render("Log en vivo")

	var sideLogLines []string
	for i := len(m.dashLogs) - 1; i >= 0 && len(sideLogLines) < 10; i-- {
		sideLogLines = append([]string{m.dashLogs[i].render(sideW - 4)}, sideLogLines...)
	}
	if len(sideLogLines) == 0 {
		sideLogLines = []string{sDim.Render("Sin actividad reciente...")}
	}

	btnLogs := lipgloss.NewStyle().Foreground(cCyan).
		Border(lipgloss.RoundedBorder()).BorderForeground(cCyan).
		Width(sideW - 4).Padding(0, 1).Render("📋 Logs    L")
	btnRestart := lipgloss.NewStyle().Foreground(cYellow).
		Border(lipgloss.RoundedBorder()).BorderForeground(cYellow).
		Width(sideW - 4).Padding(0, 1).Render("↺  Restart  R")
	btnShutdown := lipgloss.NewStyle().Foreground(cRed).
		Border(lipgloss.RoundedBorder()).BorderForeground(cRed).
		Width(sideW - 4).Padding(0, 1).Render("⏻  Shutdown S")

	sideContent := lipgloss.JoinVertical(lipgloss.Left,
		liveLabel, "",
		strings.Join(sideLogLines, "\n"), "",
		btnLogs, btnRestart, btnShutdown,
	)
	sidePanel := sBox.Width(sideW).Render(sideContent)

	return lipgloss.JoinHorizontal(lipgloss.Top,
		lipgloss.NewStyle().Width(mainW).Render(mainContent), sidePanel,
	)
}

// viewLogs — P10: toolbar dual (Nivel + Source) + viewport sin sBox (doc §P10 L1950-L2001).
func (m model) viewLogs() string {
	// ── Toolbar Nivel (fila 1) ─────────────────────────────────────────────
	type lvlBtn struct {
		label string
		level logLevel
		color lipgloss.Color
	}
	lvlBtns := []lvlBtn{
		{"Todos", logInfo, "#38bdf8"},
		{"✓ OK", logOK, "#22c55e"},
		{"⚠ Warn", logWarn, "#f59e0b"},
		{"✗ Error", logError, "#ef4444"},
	}
	var lvlParts []string
	for _, b := range lvlBtns {
		active := m.logFilter == b.level || (b.level == logInfo && m.logFilter == logInfo)
		if active {
			lvlParts = append(lvlParts,
				lipgloss.NewStyle().Foreground(b.color).Bold(true).Underline(true).Render(b.label),
			)
		} else {
			lvlParts = append(lvlParts, sDim.Render(b.label))
		}
	}
	toolbarNivel := sDim.Render("Nivel: ") + strings.Join(lvlParts, "  ")

	// ── Toolbar Source (fila 2) ───────────────────────────────────────────
	sources := []string{"Todos", "bos", "bkernel", "bauth", "bsearch", "biedata", "nexus"}
	var srcParts []string
	for _, s := range sources {
		active := (s == "Todos" && m.logSource == "") || strings.EqualFold(m.logSource, s)
		if active {
			srcParts = append(srcParts,
				lipgloss.NewStyle().Foreground(cCyan).Bold(true).Underline(true).Render(s),
			)
		} else {
			srcParts = append(srcParts, sDim.Render(s))
		}
	}
	toolbarSource := sDim.Render("Source:") + " " + strings.Join(srcParts, "  ")

	// ── Viewport de log (bodyHeight - 2 para las 2 filas de toolbar) ──────
	vp := m.vpLog
	vp.Height = m.bodyHeight - 2
	if vp.Height < 2 {
		vp.Height = 2
	}

	filtered := m.filteredLogs()
	var logLines []string
	for _, e := range filtered {
		line := e.render(m.width - 1)
		if m.logSearch != "" {
			line = highlightMatch(line, m.logSearch)
		}
		logLines = append(logLines, line)
	}
	if len(logLines) == 0 {
		logLines = []string{sDim.Render("Sin logs disponibles")}
	}
	vp.SetContent(strings.Join(logLines, "\n"))

	return lipgloss.JoinVertical(lipgloss.Left,
		toolbarNivel,
		toolbarSource,
		vp.View(),
	)
}

func (m model) viewShutdown() string {
	// doc §P11: panel izquierdo(flex1) + panel derecho 210px (≈28 chars)
	sideW := 28
	if m.width < 70 {
		sideW = 0
	}
	mainW := m.width - sideW - 1
	if sideW == 0 {
		mainW = m.width
	}

	// Colores según modo (topbar ya está coloreada en viewHeader)
	barColor := cRed
	titleColor := lipgloss.Color("#fca5a5")
	if m.shutdownMode == "restart" {
		barColor = cYellow
		titleColor = lipgloss.Color("#fde68a")
	}

	shutdownSeq := []struct{ group, action string }{
		{"Daemons SBOS", "banexus → bhnexus → bCompass → biedata → bSearch → bAuth → bKernel"},
		{"Context Plane", "context.expired → Redis DB1 vaciado → JSON-RPC cerrado"},
		{"Seguridad", "kong → keycloak → vault (secrets sellados)"},
		{"Stack de datos", "redis (RDB snapshot) → minio → postgresql (checkpoint final)"},
		{"Kubernetes", "drain pods → Linkerd → kubelet cordoned → apiserver → etcd snapshot"},
		{"Ubuntu", "containerd → systemd sync filesystem → kernel apagado"},
	}

	// ── Panel izquierdo: secuencia de apagado ─────────────────────────────
	var seqLines []string
	for i, seq := range shutdownSeq {
		stepFrac := float64(i) / float64(len(shutdownSeq))
		nextFrac := float64(i+1) / float64(len(shutdownSeq))
		var icon string
		if m.shutdownPct >= nextFrac {
			icon = icOk()
		} else if m.shutdownPct >= stepFrac {
			icon = m.spinner.View()
		} else {
			icon = icPend()
		}
		seqLines = append(seqLines,
			icon+" "+lipgloss.NewStyle().Foreground(cWhite).Bold(true).Render(seq.group),
			"   "+sDim.Render(seq.action),
			"",
		)
	}
	mainPanel := sBox.Width(mainW).Render(strings.Join(seqLines, "\n"))

	if sideW == 0 {
		return mainPanel
	}

	// ── Panel derecho: barra + estado + aviso ─────────────────────────────
	barW := sideW - 4
	if barW < 8 {
		barW = 8
	}
	filled := int(float64(barW) * m.shutdownPct)
	if filled > barW {
		filled = barW
	}
	pct := int(m.shutdownPct * 100)
	bar := lipgloss.NewStyle().Foreground(barColor).Render(strings.Repeat("█", filled)) +
		sDim.Render(strings.Repeat("░", barW-filled))

	var action string
	if m.shutdownMode == "restart" {
		action = "↺ Reiniciando"
	} else {
		action = "⏻ Apagando"
	}

	warnStyle := lipgloss.NewStyle().Foreground(barColor).Italic(true)
	sideContent := lipgloss.JoinVertical(lipgloss.Left,
		lipgloss.NewStyle().Foreground(titleColor).Bold(true).Render(action),
		"",
		fmt.Sprintf("[%s] %3d%%", bar, pct),
		"",
		sDim.Render("No interrumpir"),
		"",
		warnStyle.Render("Ctrl+C — solo"),
		warnStyle.Render("para forzar"),
		warnStyle.Render("(peligroso)"),
	)
	sidePanel := sBox.Width(sideW).Render(sideContent)

	return lipgloss.JoinHorizontal(lipgloss.Top, mainPanel, sidePanel)
}

// ── Helpers de render ──────────────────────────────────────────────────────

// renderSubComponent muestra un sub-componente de instalación con descripción.
// Columna B: nombre técnico + descripción legible + tiempo.
func renderSubComponent(s stepDetail, width int) string {
	var icon string
	switch s.status {
	case sDone:
		icon = sStepOK.Render("✓")
	case sActive:
		icon = sStepActive.Render("›")
	case sFailed:
		icon = sStepFail.Render("✗")
	case sSkipped:
		icon = sDim.Render("─")
	default:
		icon = sStepPending.Render("○")
	}

	name := truncA(s.name, width-12)
	var dur string
	switch s.status {
	case sDone, sFailed:
		if fd := formatDur(s.duration); fd != "" {
			dur = sDim.Render("  " + fd)
		}
	case sActive:
		if !s.startTime.IsZero() {
			if fd := formatDur(time.Since(s.startTime).Round(time.Second)); fd != "" {
				dur = sDim.Render("  " + fd)
			}
		}
	}

	var lines []string
	switch s.status {
	case sDone:
		lines = append(lines, sStepOK.Render(icon+" "+name)+dur)
	case sActive:
		lines = append(lines, sStepActive.Render(icon+" "+name)+dur)
		// Mostrar descripción: preferir msg del step_start, si no formatear el nombre técnico
		desc := s.msg
		if desc == "" {
			desc = stepNameToDesc(s.name)
		}
		if desc != "" {
			lines = append(lines, sDim.Render("   └ "+truncA(desc, width-6)))
		}
	case sFailed:
		lines = append(lines, sStepFail.Render(icon+" "+name)+dur)
		if s.errMsg != "" {
			for _, l := range strings.Split(wordWrap(s.errMsg, width-6), "\n") {
				lines = append(lines, sRed.Render("   │ "+l))
			}
		}
	default:
		lines = append(lines, sDim.Render(icon+" "+name))
	}
	return strings.Join(lines, "\n")
}

// stepNameToDesc convierte un nombre técnico de paso (snake_case) a descripción legible.
// Ej: "instalar_containerd" → "Instalar containerd"
func stepNameToDesc(name string) string {
	if name == "" {
		return ""
	}
	words := strings.Split(name, "_")
	if len(words) == 0 {
		return name
	}
	// Capitalizar primera palabra
	if len(words[0]) > 0 {
		words[0] = strings.ToUpper(words[0][:1]) + words[0][1:]
	}
	return strings.Join(words, " ")
}

func renderStep(s stepDetail, width int) string {
	var icon string
	switch s.status {
	case sDone:
		icon = sStepOK.Render("✓")
	case sActive:
		icon = sStepActive.Render("›")
	case sFailed:
		icon = sStepFail.Render("✗")
	case sSkipped:
		icon = sDim.Render("─")
	default:
		icon = sStepPending.Render("○")
	}
	name := truncA(s.name, width-14)
	var dur string
	if s.status == sDone || s.status == sFailed {
		if fd := formatDur(s.duration); fd != "" {
			dur = sDim.Render(" " + fd)
		}
	} else if s.status == sActive && !s.startTime.IsZero() {
		if fd := formatDur(time.Since(s.startTime).Round(time.Second)); fd != "" {
			dur = sDim.Render(" " + fd)
		}
	}
	line := icon + " " + name + dur
	if s.status == sFailed && s.errMsg != "" {
		wrapped := wordWrap(s.errMsg, width-4)
		for _, l := range strings.Split(wrapped, "\n") {
			line += "\n" + sRed.Render("  │ " + l)
		}
	}
	return line
}

func (m model) phaseStatus(ph installPhase) fichaStatus {
	anyActive := false
	allDone := true
	anyFailed := false
	anyStarted := false
	for _, fid := range ph.fichas {
		fd := m.fichas[fid]
		if fd == nil {
			allDone = false
			continue
		}
		switch fd.status {
		case fActive:
			anyActive = true
			anyStarted = true
			allDone = false
		case fDone:
			anyStarted = true
		case fFailed:
			anyFailed = true
			anyStarted = true
			allDone = false
		case fPending:
			allDone = false
		}
	}
	if anyFailed {
		return fFailed
	}
	if anyActive {
		return fActive
	}
	if allDone && anyStarted {
		return fDone
	}
	return fPending
}

func (m model) activeficha() *fichaDetail {
	// Primero buscar una ficha actualmente en proceso
	for _, ph := range m.phases {
		for _, fid := range ph.fichas {
			if fd := m.fichas[fid]; fd != nil && fd.status == fActive {
				return fd
			}
		}
	}
	// Fallback: mostrar la última ficha que tuvo pasos (la más reciente del DAG)
	for i := len(m.phases) - 1; i >= 0; i-- {
		ph := m.phases[i]
		for j := len(ph.fichas) - 1; j >= 0; j-- {
			fid := ph.fichas[j]
			if fd := m.fichas[fid]; fd != nil && (fd.status == fDone || fd.status == fFailed) && len(fd.steps) > 0 {
				return fd
			}
		}
	}
	return nil
}

func (m model) lastLogLines(n, width int) []string {
	start := 0
	if len(m.logs) > n {
		start = len(m.logs) - n
	}
	var lines []string
	for _, e := range m.logs[start:] {
		lines = append(lines, e.render(width))
	}
	return lines
}

// lastLogLinesFor devuelve las últimas n líneas del log filtradas por ficha y paso.
// fichaID vacío = todos. stepName vacío = todos los pasos de la ficha.
func (m model) lastLogLinesFor(n, width int, fichaID, stepName string) []string {
	var filtered []logEntry
	for _, e := range m.logs {
		matchFicha := fichaID == "" || e.ficha == fichaID || e.ficha == ""
		matchStep := stepName == "" || e.step == stepName || e.step == ""
		if matchFicha && matchStep {
			filtered = append(filtered, e)
		}
	}
	start := 0
	if len(filtered) > n {
		start = len(filtered) - n
	}
	var lines []string
	for _, e := range filtered[start:] {
		lines = append(lines, e.render(width))
	}
	return lines
}

// renderScrollbar renderiza una barra de scroll vertical a la derecha del contenido.
// Devuelve las líneas del contenido con la barra pegada a la derecha.

func phaseIcon(st fichaStatus) string {
	switch st {
	case fDone:
		return sGreen.Render("✓")
	case fActive:
		return sYellow.Render("›")
	case fFailed:
		return sRed.Render("✗")
	}
	return sDim.Render("○")
}

func fichaIcon(st fichaStatus) string {
	switch st {
	case fDone:
		return sGreen.Render("✓")
	case fActive:
		return sYellow.Render("›")
	case fFailed:
		return sRed.Render("✗")
	}
	return sDim.Render("○")
}

func versionSuffix(id string) string {
	if v, ok := fichaVersions[id]; ok {
		return " " + sDim.Render(v)
	}
	return ""
}

func stepMsgSuffix(msg string) string {
	if msg != "" {
		return ": " + msg
	}
	return ""
}

func (m model) safeW() int {
	if m.width < 40 {
		return 40
	}
	return m.width
}

func (m model) mode() string {
	if m.width < 60 {
		return "xs"
	}
	if m.width < 80 {
		return "sm"
	}
	return "md"
}

// ── Helpers de formato ─────────────────────────────────────────────────────

func formatDur(d time.Duration) string {
	if d < time.Second {
		return ""
	}
	d = d.Round(time.Second)
	m := int(d.Minutes())
	s := int(d.Seconds()) % 60
	if m > 0 {
		return fmt.Sprintf("%d:%02d", m, s)
	}
	return fmt.Sprintf("%ds", s)
}

func truncA(s string, max int) string {
	if max <= 1 {
		return s
	}
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	return string(r[:max-1]) + "…"
}

func wordWrap(text string, maxW int) string {
	if maxW <= 0 {
		return text
	}
	words := strings.Fields(text)
	var lines []string
	var cur strings.Builder
	for _, w := range words {
		if cur.Len()+len(w)+1 > maxW {
			lines = append(lines, cur.String())
			cur.Reset()
		}
		if cur.Len() > 0 {
			cur.WriteByte(' ')
		}
		cur.WriteString(w)
	}
	if cur.Len() > 0 {
		lines = append(lines, cur.String())
	}
	return strings.Join(lines, "\n")
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// ── Info del sistema ────────────────────────────────────────────────────────

type sysInfo struct {
	OS, Kernel, RAM, Disk, CPU string
}

func detectSystemInfo() sysInfo {
	info := sysInfo{}

	// OS — leer /etc/os-release directamente (no requiere lsb_release)
	if data, err := os.ReadFile("/etc/os-release"); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			if strings.HasPrefix(line, "PRETTY_NAME=") {
				info.OS = strings.Trim(strings.TrimPrefix(line, "PRETTY_NAME="), "\"")
				break
			}
		}
	}
	if info.OS == "" {
		if out, err := runCmd("uname", "-o"); err == nil {
			info.OS = strings.TrimSpace(out)
		}
	}

	// Kernel
	if out, err := runCmd("uname", "-r"); err == nil {
		info.Kernel = strings.TrimSpace(out)
	}

	// RAM — leer /proc/meminfo directamente (sin awk)
	if data, err := os.ReadFile("/proc/meminfo"); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			if strings.HasPrefix(line, "MemTotal:") {
				if fields := strings.Fields(line); len(fields) >= 2 {
					if kb, err := strconv.ParseInt(fields[1], 10, 64); err == nil {
						gb := float64(kb) / 1024 / 1024
						info.RAM = fmt.Sprintf("%.1f GB", gb)
					}
				}
				break
			}
		}
	}

	// Disco
	if out, err := runCmd("df", "-BG", "/"); err == nil {
		lines := strings.Split(out, "\n")
		if len(lines) >= 2 {
			if fields := strings.Fields(lines[1]); len(fields) >= 4 {
				info.Disk = strings.TrimSuffix(fields[3], "G") + " GB disponibles"
			}
		}
	}

	// CPU — leer /proc/cpuinfo directamente (sin nproc)
	if data, err := os.ReadFile("/proc/cpuinfo"); err == nil {
		count := 0
		for _, line := range strings.Split(string(data), "\n") {
			if strings.HasPrefix(line, "processor") {
				count++
			}
		}
		if count > 0 {
			info.CPU = fmt.Sprintf("%d cores", count)
		}
	}
	if info.CPU == "" {
		if out, err := runCmd("nproc"); err == nil {
			info.CPU = strings.TrimSpace(out) + " cores"
		}
	}

	return info
}

func runCmd(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	var stdout bytes.Buffer
	cmd.Stdout = &stdout
	err := cmd.Run() // ejecutar primero
	return stdout.String(), err // leer stdout después de que el proceso terminó
}

// ── Entry Points ────────────────────────────────────────────────────────────

// ── Modo Demo / Simulación ───────────────────────────────────────────────────

// demoSubComponents define sub-componentes realistas por ficha para la simulación.
var demoSubComponents = map[string][]struct{ name, desc string }{
	"sbos-bootstrap-os": {
		{"instalar_dependencias", "apt: curl, wget, gnupg, ca-certificates, apt-transport-https"},
		{"configurar_kernel", "sysctl: net.ipv4.ip_forward, bridge-nf-call-iptables"},
		{"deshabilitar_swap", "swapoff -a, comentar /etc/fstab"},
		{"configurar_firewall", "ufw: puertos 6443/tcp, 10250/tcp, 2379-2380/tcp"},
		{"verificar_sistema", "Comprobando kernel ≥ 5.15, cgroups v2, containerd"},
	},
	"sbos-bootstrap-k8s": {
		{"instalar_k3s", "Descargando k3s v1.32 binary (78MB)"},
		{"configurar_kubeconfig", "Configurando ~/.kube/config y KUBECONFIG"},
		{"esperar_nodos", "kubectl wait node --for=condition=Ready"},
		{"instalar_helm", "Descargando helm v3.17 (15MB)"},
		{"verificar_cluster", "kubectl cluster-info, get nodes -o wide"},
	},
	"sbos-bootstrap-cni": {
		{"aplicar_calico_operator", "kubectl apply -f tigera-operator.yaml (Calico 3.32.0)"},
		{"configurar_ippool", "CalicoNetwork: CIDR 10.244.0.0/16, IPIP disabled"},
		{"esperar_calico_pods", "kubectl wait pod -n calico-system --for=condition=Ready"},
		{"verificar_cni", "Comprobando interfaces tunl0, cali*, eth0"},
	},
	"postgresql": {
		{"crear_namespace", "kubectl create namespace postgresql"},
		{"crear_pvc", "PersistentVolumeClaim: 50Gi, StorageClass: local-path"},
		{"desplegar_statefulset", "StatefulSet postgresql-0 — imagen bitnami/postgresql:18.4"},
		{"inicializar_bd", "initdb: locale=es_BO.UTF-8, encoding=UTF8"},
		{"configurar_replicacion", "postgresql.conf: wal_level=logical, max_wal_senders=10"},
		{"instalar_extensiones", "CREATE EXTENSION: pg_trgm, uuid-ossp, pgcrypto, unaccent"},
		{"verificar_salud", "pg_isready -h localhost -p 5432"},
	},
	"redis": {
		{"crear_namespace", "kubectl create namespace redis"},
		{"crear_pvc", "PersistentVolumeClaim: 10Gi, StorageClass: local-path"},
		{"desplegar_statefulset", "StatefulSet redis-0 — imagen bitnami/redis:8.6.2"},
		{"configurar_streams", "redis.conf: maxmemory-policy=noeviction, AOF enabled"},
		{"verificar_ping", "redis-cli PING → PONG"},
	},
	"vault": {
		{"desplegar_vault", "StatefulSet vault-0 — imagen hashicorp/vault:2.0.1"},
		{"inicializar_vault", "vault operator init -key-shares=5 -key-threshold=3"},
		{"unseal_vault", "vault operator unseal (3 de 5 llaves)"},
		{"configurar_pki", "vault secrets enable pki, generar CA raíz del SBOS"},
		{"configurar_kv", "vault secrets enable -path=sbos kv-v2"},
	},
	"keycloak": {
		{"crear_bd_keycloak", "CREATE DATABASE keycloak OWNER keycloak"},
		{"desplegar_keycloak", "Deployment keycloak — imagen quay.io/keycloak/keycloak:26.6.2"},
		{"configurar_realm", "POST /admin/realms: sbos-realm, BO locale"},
		{"configurar_clientes", "Registrar clientes: bosctl, core-ui, kong"},
		{"instalar_spis", "Deploy bAuth Java SPIs (5 SPIs): PrivilegeEngine, BitMask64"},
		{"verificar_oidc", "GET /.well-known/openid-configuration"},
	},
}

// demoLogLines define líneas de log realistas por paso para la simulación.
func demoLogLine(ficha, step string) []string {
	key := ficha + "." + step
	switch key {
	case "sbos-bootstrap-k8s.instalar_k3s":
		return []string{
			"[INFO] Descargando k3s desde releases.k3s.io...",
			"[INFO] 25% — 19.5 MB / 78 MB",
			"[INFO] 50% — 39.0 MB / 78 MB",
			"[INFO] 75% — 58.5 MB / 78 MB",
			"[INFO] 100% — Descarga completa",
			"[INFO] Instalando k3s en /usr/local/bin/k3s",
			"[INFO] systemctl enable k3s && systemctl start k3s",
		}
	case "postgresql.desplegar_statefulset":
		return []string{
			"[INFO] kubectl apply -f postgresql-statefulset.yaml",
			"[INFO] statefulset.apps/postgresql created",
			"[INFO] service/postgresql created",
			"[INFO] Esperando pod postgresql-0 Running...",
			"[INFO] pod/postgresql-0 0/1 ContainerCreating",
			"[INFO] pod/postgresql-0 1/1 Running",
		}
	case "postgresql.instalar_extensiones":
		return []string{
			"[INFO] CREATE EXTENSION pg_trgm",
			"[INFO] CREATE EXTENSION uuid-ossp",
			"[INFO] CREATE EXTENSION pgcrypto",
			"[INFO] CREATE EXTENSION unaccent",
			"[INFO] Extensiones instaladas: 4",
		}
	case "redis.desplegar_statefulset":
		return []string{
			"[INFO] kubectl apply -f redis-statefulset.yaml",
			"[INFO] statefulset.apps/redis created",
			"[INFO] Esperando pod redis-0 Running...",
			"[INFO] pod/redis-0 1/1 Running",
		}
	}
	return []string{"[INFO] " + ficha + ": ejecutando " + step + "..."}
}

// runDemo envía eventos falsos al canal wsCh simulando una instalación completa.
// Usa los mismos tipos de evento que el daemon bos real para probar toda la UI.
func runDemo(ch chan wsEventMsg) {
	pasosFallback := []struct{ name, desc string }{
		{"check_prerequisites", "Verificando requisitos del sistema"},
		{"pull_image", "Descargando imagen del contenedor"},
		{"deploy_manifest", "Aplicando manifiestos Kubernetes"},
		{"wait_ready", "Esperando que el pod esté listo"},
		{"verify_health", "Verificando health check"},
	}
	phases := defaultPhases()

	total := 0
	for _, ph := range phases {
		total += len(ph.fichas)
	}
	ch <- wsEventMsg{evType: "response", total: total}
	time.Sleep(400 * time.Millisecond)

	for _, ph := range phases {
		for _, ficha := range ph.fichas {
			ch <- wsEventMsg{evType: "saga_start", ficha: ficha}
			time.Sleep(250 * time.Millisecond)

			pasos, ok := demoSubComponents[ficha]
			if !ok {
				pasos = pasosFallback
			}

			for _, paso := range pasos {
				ch <- wsEventMsg{evType: "step_start", ficha: ficha, step: paso.name, msg: paso.desc}
				// Enviar líneas de log del paso como ficha_log
				for _, logLine := range demoLogLine(ficha, paso.name) {
					time.Sleep(120 * time.Millisecond)
					ch <- wsEventMsg{evType: "ficha_log", ficha: ficha, msg: logLine}
				}
				time.Sleep(200 * time.Millisecond)
				ch <- wsEventMsg{evType: "step_ok", ficha: ficha, step: paso.name}
				time.Sleep(100 * time.Millisecond)
			}

			ch <- wsEventMsg{evType: "saga_ok", ficha: ficha}
			time.Sleep(200 * time.Millisecond)
		}
	}

	time.Sleep(600 * time.Millisecond)
	ch <- wsEventMsg{evType: "bootstrap_complete"}
}

func cmdInstallUI(args []string) int {
	fs := flag.NewFlagSet("setup", flag.ContinueOnError)
	unattended := fs.Bool("unattended", false, "instalación automática sin interacción")
	seedFile := fs.String("seed-file", "", "archivo JSON/YAML con datos del tenant")
	demo := fs.Bool("demo", false, "modo simulación — muestra la UI completa sin instalar nada")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if *unattended && *seedFile != "" {
		return runUnattended(*seedFile)
	}
	demoMode = *demo
	return runInteractiveTUI()
}

func runInteractiveTUI() int {
	// Reinicializar stopCh para esta sesión (por si se llama múltiples veces)
	stopCh = make(chan struct{})

	m := initialModel()

	// Si stdin es un terminal real (PTY de SSH o terminal local), usarlo directamente.
	// Si no (pipe, redirección), abrir /dev/tty para conseguir el terminal de control.
	var tty *os.File
	var err error
	if st, sterr := os.Stdin.Stat(); sterr == nil && (st.Mode()&os.ModeCharDevice) != 0 {
		tty = os.Stdin
	} else {
		tty, err = os.OpenFile("/dev/tty", os.O_RDWR, 0)
		if err != nil {
			tty = os.Stdin
		} else {
			defer tty.Close()
		}
	}

	p := tea.NewProgram(m,
		tea.WithInput(tty),        // input desde /dev/tty (tmux-safe)
		tea.WithOutput(os.Stdout), // output al pane
		tea.WithAltScreen(),       // pantalla alternativa — sin contaminar scrollback
	)
	if _, err := p.Run(); err != nil {
		close(stopCh) // detener goroutines WS aunque haya error
		fmt.Fprintf(os.Stderr, "bosctl setup: %v\n", err)
		return 1
	}
	// Señalizar a todas las goroutines (WS, awaitWS) que el TUI terminó.
	// Esto detiene el lector WS, el awaitWS bloqueado y cierra la conexión.
	close(stopCh)
	return 0
}

// ── Modo Unattended ─────────────────────────────────────────────────────────

func runUnattended(seedFile string) int {
	data, err := os.ReadFile(seedFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl setup: no se pudo leer seed file: %v\n", err)
		return 1
	}
	seed := loadEnvSeed()
	if err := json.Unmarshal(data, &seed); err != nil {
		if p := parseSimpleSeed(string(data)); p.RazonSocial != "" {
			seed = p
		}
	}

	fmt.Println("\033[1mSBOS — Instalación Automática\033[0m")
	fmt.Printf("Empresa: %s  ·  Admin: %s  ·  Dominio: %s\n\n",
		seed.RazonSocial, seed.Email, seed.Dominio)

	socketPath := os.Getenv("BOS_SOCKET")
	if socketPath == "" {
		socketPath = defaultSocket
	}
	dialer := websocket.Dialer{
		NetDialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
			var d net.Dialer
			return d.DialContext(ctx, "unix", socketPath)
		},
		HandshakeTimeout: 5 * time.Second,
	}
	conn, _, err := dialer.DialContext(context.Background(), "ws://unix/ws", nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl setup: daemon no disponible: %v\n", err)
		return 6
	}
	defer conn.Close()

	_ = conn.WriteJSON(map[string]interface{}{
		"type": "request", "id": fmt.Sprintf("ua-%d", time.Now().UnixNano()),
		"action": "bootstrap_start",
		"params": map[string]interface{}{
			"razon_social": seed.RazonSocial, "nit": seed.NIT,
			"pais": seed.Pais, "dominio": seed.Dominio,
			"email": seed.Email, "nombre": seed.Nombre,
			"password": seed.Password, "mfa": seed.MFA,
		},
	})

	phases := defaultPhases()
	fichasOK, fichasTotal := 0, 22
	curPhase := -1

	for {
		_, raw, err := conn.ReadMessage()
		if err != nil {
			break
		}
		var ev map[string]interface{}
		if json.Unmarshal(raw, &ev) != nil {
			continue
		}
		evType, _ := ev["type"].(string)
		ficha, _ := ev["ficha"].(string)
		step, _ := ev["step"].(string)
		msg, _ := ev["message"].(string)

		switch evType {
		case "response":
			if d, ok := ev["data"].(map[string]interface{}); ok {
				if t, ok := d["fichas_total"].(float64); ok && t > 0 {
					fichasTotal = int(t)
				}
			}
		case "saga_start":
			if lvl, ok := fichaPhaseMap[ficha]; ok && lvl != curPhase {
				curPhase = lvl
				if lvl < len(phases) {
					fmt.Printf("\n\033[1m› %s\033[0m\n", phases[lvl].nombre)
				}
			}
			fmt.Printf("  \033[36m📦 %s%s\033[0m\n", ficha, versionSuffixPlain(ficha))
		case "step_start":
			fmt.Printf("  \033[2m  ↳ %s\033[0m\n", step)
		case "step_ok":
			fmt.Printf("  \033[32m  ✓ %s%s\033[0m\n", step, fmtMsg(msg))
		case "step_fail":
			errDetail, _ := ev["error"].(string)
			fmt.Printf("  \033[31m  ✗ %s: %s\033[0m\n", step, errDetail)
		case "saga_ok":
			fichasOK++
			fmt.Printf("  \033[32m✅ [%d/%d] %s\033[0m\n", fichasOK, fichasTotal, ficha)
		case "saga_fail":
			fmt.Printf("  \033[31m❌ %s: %s\033[0m\n", ficha, msg)
			return 1
		case "bootstrap_complete":
			fmt.Printf("\n\033[1;32m✅ Bootstrap completado: %d/%d componentes\033[0m\n",
				fichasOK, fichasTotal)
			return 0
		}
	}
	return 1
}

func versionSuffixPlain(id string) string {
	if v, ok := fichaVersions[id]; ok {
		return " " + v
	}
	return ""
}

func fmtMsg(msg string) string {
	if msg != "" {
		return ": " + msg
	}
	return ""
}

func parseSimpleSeed(raw string) seedData {
	s := seedData{Pais: "BO"}
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		var k, v string
		if idx := strings.Index(line, "="); idx > 0 {
			k, v = strings.TrimSpace(line[:idx]), strings.TrimSpace(line[idx+1:])
		} else if idx := strings.Index(line, ":"); idx > 0 {
			k, v = strings.TrimSpace(line[:idx]), strings.Trim(strings.TrimSpace(line[idx+1:]), "\"'")
		} else {
			continue
		}
		switch k {
		case "razon_social":
			s.RazonSocial = v
		case "nit":
			s.NIT = v
		case "pais":
			s.Pais = v
		case "dominio":
			s.Dominio = v
		case "email":
			s.Email = v
		case "nombre":
			s.Nombre = v
		case "password":
			s.Password = v
		case "mfa":
			s.MFA = v == "true" || v == "1"
		}
	}
	return s
}
