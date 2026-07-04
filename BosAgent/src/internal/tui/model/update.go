// Package model — update.go: lógica principal del loop TEA del instalador bos.
// Migrado de cmd/bosctl/install_ui_impl.go en BOS-REPAIR F3.MIGRATE.
package model

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"bos/internal/boslog"
	"bos/internal/capacity"
	"bos/internal/tui/ctrl"
	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/ctrl/panel"
	"bos/internal/tui/styles"
	"bos/internal/tui/tuilog"
	"bos/internal/tui/util"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/lipgloss"
)

// HandleUpdate procesa un mensaje TEA y retorna el nuevo modelo + comandos.
// Función libre (no método) para evitar dependencia circular con app/.
func HandleUpdate(m *Model, msg tea.Msg) (*Model, tea.Cmd) {
	var cmds []tea.Cmd

	// Inicializar forms wizard la primera vez que se entra a cada pantalla.
	// Se crean aquí (no en NewModel) para que m.Width ya sea conocido.
	// WithWidth(m.Width) asegura que el form usa el ancho de contenido (sin márgenes).
	w := m.Width
	if w <= 0 {
		w = 80
	}
	if m.CurrentScreen == ScreenWizardP1 && m.WizardP1Form == nil {
		m.WizardP1Form = NewWizardP1Form(m).WithWidth(w)
		cmds = append(cmds, m.WizardP1Form.Init())
	}
	if m.CurrentScreen == ScreenWizardP2 && m.WizardP2Form == nil {
		m.WizardP2Form = NewWizardP2Form(m).WithWidth(w)
		cmds = append(cmds, m.WizardP2Form.Init())
	}
	if m.CurrentScreen == ScreenWizardP3 && m.WizardP3Form == nil {
		m.WizardP3Form = NewWizardP3Form(m).WithWidth(w)
		cmds = append(cmds, m.WizardP3Form.Init())
	}
	if m.CurrentScreen == ScreenWizardP4 && m.WizardP4Form == nil {
		m.WizardP4Form = NewWizardP4Form(m).WithWidth(w)
		cmds = append(cmds, m.WizardP4Form.Init())
	}

	// Inicializar form de auth la primera vez que se entra a ScreenAuthLogin.
	if m.CurrentScreen == ScreenAuthLogin && m.AuthForm == nil {
		m.AuthForm = NewAuthLoginForm(m)
		cmds = append(cmds, m.AuthForm.Init())
	}

	// Inicializar form de step-up la primera vez que se entra a ScreenAuthConfirm.
	if m.CurrentScreen == ScreenAuthConfirm && m.AuthConfirmForm == nil && m.AuthLoA < 3 {
		m.AuthConfirmForm = NewAuthConfirmForm(m)
		cmds = append(cmds, m.AuthConfirmForm.Init())
	}

	// Delegar mensajes al form de step-up cuando está activo (LoA < 3).
	if m.CurrentScreen == ScreenAuthConfirm && m.AuthConfirmForm != nil && m.AuthLoA < 3 && m.AuthConfirmForm.State == huh.StateNormal {
		formModel, formCmd := m.AuthConfirmForm.Update(msg)
		if f, ok := formModel.(*huh.Form); ok {
			m.AuthConfirmForm = f
		}
		if formCmd != nil {
			cmds = append(cmds, formCmd)
		}
		switch m.AuthConfirmForm.State {
		case huh.StateCompleted:
			if !m.AuthConfirmOK {
				m.AuthConfirmForm = nil
				m.SetScreen(ScreenDashboard)
				return m, tea.Batch(cmds...)
			}
			m.AuthErr = ""
			cmds = append(cmds, StepUpCmd(m.AuthUsername, m.AuthStepUpPass))
			return m, tea.Batch(cmds...)
		case huh.StateAborted:
			m.AuthConfirmForm = nil
			m.SetScreen(ScreenDashboard)
			return m, tea.Batch(cmds...)
		}
		if _, ok := msg.(tea.KeyMsg); ok {
			return m, tea.Batch(cmds...)
		}
	}

	// Delegar todos los mensajes al form de auth mientras está activo.
	if m.CurrentScreen == ScreenAuthLogin && m.AuthForm != nil && m.AuthForm.State == huh.StateNormal {
		formModel, formCmd := m.AuthForm.Update(msg)
		if f, ok := formModel.(*huh.Form); ok {
			m.AuthForm = f
		}
		if formCmd != nil {
			cmds = append(cmds, formCmd)
		}
		switch m.AuthForm.State {
		case huh.StateCompleted:
			m.AuthErr = ""
			cmds = append(cmds, LoginCmd(m.AuthUser, m.AuthPass))
			return m, tea.Batch(cmds...)
		case huh.StateAborted:
			return m, tea.Quit
		}
		// KeyMsg consumido por el form — no procesar más.
		if _, ok := msg.(tea.KeyMsg); ok {
			return m, tea.Batch(cmds...)
		}
	}

	// ── Delegación a wizard forms ─────────────────────────────────────────────
	// WindowSizeMsg se filtra: las forms reciben m.Width (contenido) no m.TermW (terminal).
	// Esto evita que la form sobreescriba su ancho con el ancho bruto del terminal.
	formMsg := msg
	if wsMsg, ok := msg.(tea.WindowSizeMsg); ok {
		wsMsg.Width = m.Width
		formMsg = wsMsg
	}

	if m.CurrentScreen == ScreenWizardP1 && m.WizardP1Form != nil && m.WizardP1Form.State == huh.StateNormal {
		formModel, formCmd := m.WizardP1Form.Update(formMsg)
		if f, ok := formModel.(*huh.Form); ok {
			m.WizardP1Form = f
		}
		if formCmd != nil {
			cmds = append(cmds, formCmd)
		}
		switch m.WizardP1Form.State {
		case huh.StateCompleted:
			m.WizardP1Form = nil
			if m.WizardP1Selection == 1 {
				return m, tea.Quit
			}
			m.SetScreen(ScreenWizardP2)
			return m, tea.Batch(cmds...)
		case huh.StateAborted:
			return m, tea.Quit
		}
		if _, ok := msg.(tea.KeyMsg); ok {
			return m, tea.Batch(cmds...)
		}
	}

	if m.CurrentScreen == ScreenWizardP2 && m.WizardP2Form != nil && m.WizardP2Form.State == huh.StateNormal {
		formModel, formCmd := m.WizardP2Form.Update(formMsg)
		if f, ok := formModel.(*huh.Form); ok {
			m.WizardP2Form = f
		}
		if formCmd != nil {
			cmds = append(cmds, formCmd)
		}
		switch m.WizardP2Form.State {
		case huh.StateCompleted:
			// Normalizar país y auto-generar dominio si vacío
			m.TenantPais = strings.ToUpper(strings.TrimSpace(m.TenantPais))
			if strings.TrimSpace(m.TenantDomain) == "" {
				m.TenantDomain = BuildSlug(m.TenantName) + ".sksistemas.com"
			}
			m.WizardP2Form = nil
			m.SetScreen(ScreenWizardP3)
			return m, tea.Batch(cmds...)
		case huh.StateAborted:
			m.WizardP2Form = nil
			m.SetScreen(ScreenWizardP1)
			return m, tea.Batch(cmds...)
		}
		if _, ok := msg.(tea.KeyMsg); ok {
			return m, tea.Batch(cmds...)
		}
	}

	if m.CurrentScreen == ScreenWizardP3 && m.WizardP3Form != nil && m.WizardP3Form.State == huh.StateNormal {
		formModel, formCmd := m.WizardP3Form.Update(formMsg)
		if f, ok := formModel.(*huh.Form); ok {
			m.WizardP3Form = f
		}
		if formCmd != nil {
			cmds = append(cmds, formCmd)
		}
		switch m.WizardP3Form.State {
		case huh.StateCompleted:
			m.WizardP3Form = nil
			m.SetScreen(ScreenWizardCapacity)
			if len(m.CapacityInputs) > 0 {
				m.CapacityInputs[0].Focus()
			}
			return m, tea.Batch(cmds...)
		case huh.StateAborted:
			m.WizardP3Form = nil
			m.SetScreen(ScreenWizardP2)
			return m, tea.Batch(cmds...)
		}
		if _, ok := msg.(tea.KeyMsg); ok {
			return m, tea.Batch(cmds...)
		}
	}

	if m.CurrentScreen == ScreenWizardP4 && m.WizardP4Form != nil && m.WizardP4Form.State == huh.StateNormal {
		formModel, formCmd := m.WizardP4Form.Update(formMsg)
		if f, ok := formModel.(*huh.Form); ok {
			m.WizardP4Form = f
		}
		if formCmd != nil {
			cmds = append(cmds, formCmd)
		}
		switch m.WizardP4Form.State {
		case huh.StateCompleted:
			m.WizardP4Form = nil
			if !m.WizardP4Confirm {
				m.SetScreen(ScreenWizardCapacity)
				return m, tea.Batch(cmds...)
			}
			cmds = append(cmds, StartBootstrap(m))
			return m, tea.Batch(cmds...)
		case huh.StateAborted:
			m.WizardP4Form = nil
			m.SetScreen(ScreenWizardCapacity)
			return m, tea.Batch(cmds...)
		}
		if _, ok := msg.(tea.KeyMsg); ok {
			return m, tea.Batch(cmds...)
		}
	}

		// Los forms huh producen comandos internos (NextField, nextGroup)
		// que deben ejecutarse para que la máquina de estados avance.
	if len(cmds) > 0 {
		switch msg.(type) {
		case spinner.TickMsg, TickMsg:
			// ticks pasan al switch
		default:
			return m, tea.Batch(cmds...)
		}
	}


	switch msg := msg.(type) {

	case PreflightMsg:
		if m.CurrentScreen == ScreenWelcome {
			m.BootPct = msg.Pct
			m.BootMsg = msg.Msg
			if msg.Err != "" {
				boslog.Warn("preflight advertencia", "err", msg.Err)
				m.TUILog.Warn(tuilog.SrcPreflight, "%s", msg.Err)
				m.PreflightWarnings = append(m.PreflightWarnings, msg.Err)
				m.BootMsg = "⚠  " + Truncate(msg.Err, 60) + " — continuando..."
			}
			if msg.Done || msg.Pct >= 1.0 {
				m.BootPct = 1.0
				if len(msg.Warnings) > 0 {
					m.PreflightWarnings = msg.Warnings
				}
				boslog.Info("preflight done", "warnings", len(m.PreflightWarnings))
				if len(m.PreflightWarnings) > 0 {
					m.TUILog.Warn(tuilog.SrcPreflight, "%d advertencia(s) detectadas", len(m.PreflightWarnings))
				} else {
					m.TUILog.Info(tuilog.SrcPreflight, "preflight OK")
				}
				if len(m.PreflightWarnings) > 0 {
					m.BootMsg = fmt.Sprintf("⚠  %d advertencia(s) — presiona Enter para continuar",
						len(m.PreflightWarnings))
					return m, nil
				}
				if m.Installed {
					m.SetScreen(ScreenBoot)
				} else {
					m.SetScreen(ScreenWizardP1)
				}
				return m, nil
			}
			return m, AwaitPreflight(m.PreflightCh)
		}
		return m, nil

	default:
		m.Spinner, _ = m.Spinner.Update(m.Spinner.Tick())

		if m.CurrentScreen == ScreenReboot {
			if m.CountdownSec > 0 {
				m.CountdownSec--
			}
			if m.CountdownSec == 0 {
				m.SetScreen(ScreenBoot)
				m.BootPct = 0
				m.BootMsg = "Iniciando sistema..."
			}
			return m, TickCmd()
		}
		if m.CurrentScreen == ScreenBoot {
			if m.BootPct < 1.0 {
				m.BootPct += 0.025
				m.BootMsg = util.BootMessage(m.BootPct)
			}
			if m.BootPct >= 1.0 {
				m.BootPct = 1.0
				m.SetScreen(ScreenDashboard)
				return m, DashTickCmd()
			}
			return m, TickCmd()
		}
		if m.CurrentScreen == ScreenShutdown {
			if m.ShutdownPct < 1.0 {
				m.ShutdownPct += 0.02
			}
			if m.ShutdownPct >= 1.0 {
				m.ShutdownPct = 1.0
				if m.ShutdownMode == "restart" {
					exec.Command("sudo", "systemctl", "reboot").Run()
					return m, tea.Quit
				}
				exec.Command("sudo", "systemctl", "poweroff").Run()
				m.SetScreen(ScreenGoodbye)
			}
			return m, TickCmd()
		}
		if m.CurrentScreen == ScreenWelcome {
			if m.BootPct < 1.0 {
				m.BootPct += 0.05
				m.BootMsg = util.BootMessage(m.BootPct)
			}
			if m.BootPct >= 1.0 {
				m.BootPct = 1.0
				if m.Installed {
					m.SetScreen(ScreenBoot)
				} else {
					m.SetScreen(ScreenWizardP1)
				}
			}
			return m, TickCmd()
		}

		// TickCmd siempre sigue — necesario para spinners y animaciones en S05.
		return m, TickCmd()

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.Spinner, cmd = m.Spinner.Update(msg)
		cmds = append(cmds, cmd)
		return m, tea.Batch(cmds...)

	case TickMsg:
		if m.CurrentScreen == ScreenReboot {
			if m.CountdownSec > 0 { m.CountdownSec-- }
			if m.CountdownSec == 0 { m.SetScreen(ScreenBoot); m.BootPct = 0; m.BootMsg = "Iniciando sistema..." }
			return m, TickCmd()
		}
		if m.CurrentScreen == ScreenBoot {
			if m.BootPct < 1.0 { m.BootPct += 0.025; m.BootMsg = util.BootMessage(m.BootPct) }
			if m.BootPct >= 1.0 { m.BootPct = 1.0; m.SetScreen(ScreenDashboard); return m, DashTickCmd() }
			return m, TickCmd()
		}
		if m.CurrentScreen == ScreenShutdown {
			if m.ShutdownPct < 1.0 { m.ShutdownPct += 0.02 }
			if m.ShutdownPct >= 1.0 { exec.Command("sudo","systemctl","reboot").Run(); return m, tea.Quit }
			return m, TickCmd()
		}
		if m.CurrentScreen == ScreenWelcome {
			if m.BootPct < 1.0 { m.BootPct += 0.05; m.BootMsg = util.BootMessage(m.BootPct) }
			if m.BootPct >= 1.0 { m.SetScreen(ScreenWizardP1) }
			return m, TickCmd()
		}
		return m, TickCmd()

	case dash.DashTickMsg:
		if m.CurrentScreen == ScreenDashboard {
			m.Ctrl = m.Ctrl.ApplyTick(msg)
		}
		return m, tea.Tick(3*time.Second, func(t time.Time) tea.Msg {
			return DashTickCmd()()
		})

	case tea.WindowSizeMsg:
		m.TermW = msg.Width
		m.Height = msg.Height - 4
		col := styles.MarginW(msg.Width)
		m.Width = msg.Width - 2*col
		bw := m.Width - 56
		if bw < 10 {
			bw = 10
		}
		m.ProgBar.Width = bw
		wA, wB, wC, vpH := VpDims(m.Width, m.BodyHeight)
		if !m.VpReady {
			m.VpA = viewport.New(wA-3, vpH)
			m.VpB = viewport.New(wB-3, vpH)
			m.VpC = viewport.New(wC-3, vpH)
			m.VpA.Style = lipgloss.NewStyle()
			m.VpB.Style = lipgloss.NewStyle()
			m.VpC.Style = lipgloss.NewStyle()
			m.VpReady = true
		} else {
			m.VpA.Width, m.VpA.Height = wA-3, vpH
			m.VpB.Width, m.VpB.Height = wB-3, vpH
			m.VpC.Width, m.VpC.Height = wC-3, vpH
		}
		var ca, cb, cc tea.Cmd
		m.VpA, ca = m.VpA.Update(msg)
		m.VpB, cb = m.VpB.Update(msg)
		m.VpC, cc = m.VpC.Update(msg)
		m.recalcBodyHeight()
		m.BodyVP.Width = m.Width
		m.BodyVP.Height = m.BodyHeight
		m.SectionVP.Width = m.Width
		m.SectionVP.Height = m.BodyHeight - 1
		if m.SectionVP.Height < 1 {
			m.SectionVP.Height = 1
		}
		m.VpDash.Width = m.Width - 4
		m.VpDash.Height = m.BodyHeight
		m.VpLog.Width = m.Width - 4
		m.VpLog.Height = m.BodyHeight
		m.Ctrl.Width = msg.Width // dashboard usa ancho completo (no WrapWithMargin)
		m.Ctrl.Height = m.Height
		return m, tea.Batch(ca, cb, cc)

	case SysInfoMsg:
		m.Sys = msg.Info
		return m, nil

	case WsReadyMsg:
		boslog.Info("daemon BOS conectado via WS")
		m.TUILog.Info(tuilog.SrcWS, "conectado a bos.sock")
		m.WsConn = msg.Conn
		return m, AwaitWS(m.WsCh, m.StopCh)

	case WsErrorMsg:
		boslog.Warn("daemon BOS no disponible", "err", msg.Err)
		m.TUILog.Warn(tuilog.SrcWS, "daemon no disponible: %v", msg.Err)
		return m, nil

	case WsEventMsg:
		if pc := handleWS(m, msg); pc != nil {
			cmds = append(cmds, pc)
		}
		if m.NeedStatusSync && m.WsConn != nil {
			m.NeedStatusSync = false
			cmds = append(cmds, AwaitWS(m.WsCh, m.StopCh), SendWS(m.WsConn, "bootstrap_status", nil))
			return m, tea.Batch(cmds...)
		}
		if m.PendingLogTail != "" && m.WsConn != nil {
			fichaID := m.PendingLogTail
			m.PendingLogTail = ""
			cmds = append(cmds, AwaitWS(m.WsCh, m.StopCh),
				SendWS(m.WsConn, "ficha_log_tail", map[string]interface{}{
					"ficha": fichaID, "lines": 120,
				}))
			return m, tea.Batch(cmds...)
		}
		cmds = append(cmds, AwaitWS(m.WsCh, m.StopCh))
		return m, tea.Batch(cmds...)

	case StepUpResultMsg:
		if msg.Err != "" {
			m.TUILog.Error(tuilog.SrcAuth, "step-up fallido: %s", msg.Err)
			m.AuthErr = msg.Err
			m.AuthStepUpPass = ""
			m.AuthConfirmForm = NewAuthConfirmForm(m)
			return m, m.AuthConfirmForm.Init()
		}
		m.TUILog.Info(tuilog.SrcAuth, "step-up LoA 3 OK user=%s", m.AuthUsername)
		m.AuthLoA = 3
		m.AuthErr = ""
		m.AuthConfirmForm = nil
		// Si el step-up fue solicitado desde el dashboard para una acción destructiva,
		// ejecutar la acción pendiente en lugar de volver al dashboard.
		switch m.PendingDashAction {
		case ctrl.DashActionReboot:
			m.PendingDashAction = ctrl.DashActionNone
			m.ShutdownMode = "restart"
			m.ShutdownPct = 0
			m.SetScreen(ScreenShutdown)
			return m, TickCmd()
		case ctrl.DashActionShutdown:
			m.PendingDashAction = ctrl.DashActionNone
			m.ShutdownMode = "shutdown"
			m.ShutdownPct = 0
			m.SetScreen(ScreenShutdown)
			return m, TickCmd()
		}
		m.SetScreen(ScreenDashboard)
		return m, nil

	case AuthResultMsg:
		if msg.Err != "" {
			m.TUILog.Error(tuilog.SrcAuth, "login fallido: %s", msg.Err)
			m.AuthErr = msg.Err
			m.AuthPass = ""
			m.AuthForm = NewAuthLoginForm(m)
			return m, m.AuthForm.Init()
		}
		m.TUILog.Info(tuilog.SrcAuth, "login OK LoA %d user=%s", msg.LoA, m.AuthUsername)
		m.AuthLoA = msg.LoA
		m.AuthToken = msg.Token
		m.AuthErr = ""
		m.SetScreen(ScreenBoot)
		m.BootPct = 0
		m.BootMsg = "Iniciando sistema..."
		return m, TickCmd()

	case tuilog.TUILogTickMsg:
		// El Ring tiene nuevas entradas — sincronizar con el DashModel y re-armar el watcher
		m.Ctrl.TUIRing = m.TUILog // puntero, sin copia
		return m, tuilog.WatchCmd(m.TUILogCh)

	case tuilog.JournalEntryMsg:
		// Nueva entrada leída del viewer journalctl — acumular y re-armar el lector
		m.JournalEntries = append(m.JournalEntries, msg.Entry)
		if len(m.JournalEntries) > 1000 {
			m.JournalEntries = m.JournalEntries[len(m.JournalEntries)-1000:]
		}
		m.Ctrl.JournalEntries = m.JournalEntries
		if m.JournalCh != nil {
			return m, tuilog.FollowCmd(m.JournalCh)
		}
		return m, nil

	case tuilog.JournalErrMsg:
		m.TUILog.Warn(tuilog.SrcTUI, "viewer journalctl terminó: %s", msg.Err)
		m.JournalCh = nil
		m.JournalCancel = nil
		return m, nil

	case progress.FrameMsg:
		newBar, pc := m.ProgBar.Update(msg)
		m.ProgBar = newBar.(progress.Model)
		return m, pc


	case tea.KeyMsg:
		// Si hay un form huh activo en wizard o auth, las teclas de navegación
		// (↑↓ Enter Esc Tab) son consumidas por el form en el bloque de delegación
		// al inicio de HandleUpdate. Solo procesamos aquí cuando el form NO está activo.
		if IsNavKey(msg) {
			if c := HandleKey(m, msg); c != nil {
				return m, c
			}
			return m, nil
		}
		if c := UpdateFocused(m, msg); c != nil {
			cmds = append(cmds, c)
		}
		if c := HandleKey(m, msg); c != nil {
			cmds = append(cmds, c)
		}
		return m, tea.Batch(cmds...)
	}
}

// UpdateFocused envía un mensaje solo al input con foco activo.
// P2/P3 migrados a huh — solo P3B (capacidad) usa textinput.
func UpdateFocused(m *Model, msg tea.Msg) tea.Cmd {
	switch m.CurrentScreen {
	case ScreenWizardCapacity:
		if len(m.CapacityInputs) > 0 {
			var c tea.Cmd
			m.CapacityInputs[m.CapacityFocus], c = m.CapacityInputs[m.CapacityFocus].Update(msg)
			return c
		}
	}
	return nil
}

// HandleKey despacha teclas por pantalla activa.
func HandleKey(m *Model, msg tea.KeyMsg) tea.Cmd {
	m.ErrMsg = ""

	// Atajos globales durante la instalación (modo normal)
	if m.CurrentScreen == ScreenInstalling && m.ViewMode == "normal" {
		switch msg.String() {
		case "enter", " ":
			if m.CurrentScreen == ScreenInstallDone {
				m.SetScreen(ScreenInstallDone)
				return nil
			}
		case "r", "R":
			return SendWS(m.WsConn, "bootstrap_resume", nil)
		case "l", "L":
			m.ViewMode = "fulllog"
			m.SetScreen(ScreenInstallLog)
			return nil
		case "e", "E":
			if m.ErrPanel != nil {
				m.ViewMode = "error"
				m.SetScreen(ScreenInstallErr)
			}
			return nil
		case "t", "T":
			m.ShowTimestamp = !m.ShowTimestamp
			return nil
		case "ctrl+c":
			return tea.Quit
		case "tab":
			m.InstallingFocus = (m.InstallingFocus + 1) % 3
			return nil
		case "shift+tab":
			m.InstallingFocus = (m.InstallingFocus + 2) % 3
			return nil
		case "up", "k", "pgup":
			m.VpAutoScroll = false
			var cmd tea.Cmd
			switch m.InstallingFocus {
			case 0:
				m.VpA, cmd = m.VpA.Update(msg)
			case 1:
				m.VpB, cmd = m.VpB.Update(msg)
			case 2:
				m.VpC, cmd = m.VpC.Update(msg)
			}
			return cmd
		case "down", "j", "pgdown":
			var cmd tea.Cmd
			switch m.InstallingFocus {
			case 0:
				m.VpA, cmd = m.VpA.Update(msg)
			case 1:
				m.VpB, cmd = m.VpB.Update(msg)
			case 2:
				m.VpC, cmd = m.VpC.Update(msg)
			}
			switch m.InstallingFocus {
			case 1:
				if m.VpB.AtBottom() {
					m.VpAutoScroll = true
				}
			case 2:
				if m.VpC.AtBottom() {
					m.VpAutoScroll = true
				}
			}
			return cmd
		case "end", "G":
			m.VpAutoScroll = true
			m.VpB.GotoBottom()
			m.VpC.GotoBottom()
			return nil
		case "home", "g":
			m.VpAutoScroll = false
			switch m.InstallingFocus {
			case 0:
				m.VpA.GotoTop()
			case 1:
				m.VpB.GotoTop()
			case 2:
				m.VpC.GotoTop()
			}
			return nil
		case "left":
			switch m.InstallingFocus {
			case 1:
				m.VpB.ScrollLeft(4)
			case 2:
				m.VpC.ScrollLeft(4)
			}
			return nil
		case "right":
			switch m.InstallingFocus {
			case 1:
				m.VpB.ScrollRight(4)
			case 2:
				m.VpC.ScrollRight(4)
			}
			return nil
		}
		return nil
	}

	if m.CurrentScreen == ScreenInstalling {
		switch msg.String() {
		case "l", "L":
			m.ViewMode = "normal"
			m.SetScreen(ScreenInstalling)
		case "e", "E":
			m.ViewMode = "normal"
			m.SetScreen(ScreenInstalling)
		case "ctrl+c":
			return tea.Quit
		}
		return nil
	}
	if m.CurrentScreen == ScreenInstallLog || m.CurrentScreen == ScreenInstallErr {
		switch msg.String() {
		case "l", "L", "e", "E":
			m.ViewMode = "normal"
			m.SetScreen(ScreenInstalling)
		case "ctrl+c":
			return tea.Quit
		}
		return nil
	}

	switch m.CurrentScreen {
	case ScreenWelcome:
		return keySplashWelcome(m, msg)
	case ScreenWizardP1, ScreenWizardP2, ScreenWizardP3, ScreenWizardP4:
		// Delegación principal a huh en el bloque de HandleUpdate.
		// Solo interceptamos salida de emergencia.
		if key.Matches(msg, DefaultInstallingKeyMap.Abort) {
			return tea.Quit
		}
	case ScreenWizardCapacity:
		return keyCapacity(m, msg)
	case ScreenInstallDone:
		switch msg.String() {
		case "tab", "right":
			m.CompleteFocus = (m.CompleteFocus + 1) % 4
		case "shift+tab", "left":
			m.CompleteFocus = (m.CompleteFocus + 3) % 4
		}
		switch msg.Type {
		case tea.KeyEnter:
			m.SetScreen(ScreenReboot)
			m.CountdownSec = 10
		case tea.KeyEsc:
			return tea.Quit
		}
	case ScreenReboot:
		switch msg.Type {
		case tea.KeyEnter:
			m.CountdownSec = 0
			m.SetScreen(ScreenBoot)
			m.BootPct = 0
			m.BootMsg = "Iniciando sistema..."
		case tea.KeyEsc:
			m.SetScreen(ScreenInstallDone)
		}
	case ScreenDashboard:
		return keyDashboard(m, msg)
	case ScreenLogs:
		return keyLogs(m, msg)
	case ScreenShutdown:
		return keyShutdown(m, msg)
	case ScreenAuthConfirm:
		if key.Matches(msg, DefaultInstallingKeyMap.Abort) {
			m.AuthConfirmForm = nil
			m.SetScreen(ScreenDashboard)
			return nil
		}
	case ScreenAuthLogin:
		// La navegación dentro del form la maneja el bloque de delegación en HandleUpdate.
		// Solo interceptamos Ctrl+C como salida de emergencia.
		if key.Matches(msg, DefaultInstallingKeyMap.Abort) {
			return tea.Quit
		}
	case ScreenBoot:
		if key.Matches(msg, DefaultInstallingKeyMap.Abort) {
			return tea.Quit
		}
	case ScreenGoodbye:
		if key.Matches(msg, DefaultInstallingKeyMap.Abort) ||
			key.Matches(msg, key.NewBinding(key.WithKeys("enter"))) {
			return tea.Quit
		}
	}
	return nil
}

// ── Key handlers por pantalla ─────────────────────────────────────────────

func keySplashWelcome(m *Model, msg tea.KeyMsg) tea.Cmd {
	switch msg.Type {
	case tea.KeyEnter, tea.KeyEsc:
		if m.Installed {
			// Sistema ya instalado → pedir autenticación antes del dashboard.
			// Sin auth no hay acceso al centro de comandos (Proceso 2 del TUI-MAESTRO).
			m.SetScreen(ScreenAuthLogin)
		} else {
			m.SetScreen(ScreenWizardP1)
		}
		m.BootPct = 1.0
	case tea.KeyCtrlC:
		return tea.Quit
	}
	return nil
}


func keyCapacity(m *Model, msg tea.KeyMsg) tea.Cmd {
	inputs := make([]interface{}, 0) // solo para compatibilidad con slice
	_ = inputs
	action, errMsg := HandleCapacityKey(m.CapacityInputs, &m.CapacityFocus, msg)
	m.ErrMsg = errMsg
	switch action {
	case CapacityActionAdvance:
		if err := capacity.Save(CapacityEstimate(m.CapacityInputs), capacity.DefaultPath); err != nil {
			_ = err
		}
		m.SetScreen(ScreenWizardP4)
	case CapacityActionBack:
		m.SetScreen(ScreenWizardP3)
	}
	return nil
}

func keyDashboard(m *Model, msg tea.KeyMsg) tea.Cmd {
	m.Ctrl = m.Ctrl.Update(msg)
	switch m.Ctrl.PendingAction {
	case ctrl.DashActionReboot:
		m.Ctrl.PendingAction = ctrl.DashActionNone
		// LoA 3 requerido para reiniciar (Proceso 4 del TUI-MAESTRO).
		// Si LoA ≥ 3 → ejecutar directamente. Si no → step-up primero.
		if m.AuthLoA >= 3 {
			m.ShutdownMode = "restart"
			m.ShutdownPct = 0
			m.SetScreen(ScreenShutdown)
			return nil
		}
		m.PendingDashAction = ctrl.DashActionReboot
		m.AuthConfirmAction = "Reiniciar el servidor"
		m.SetScreen(ScreenAuthConfirm)
		return nil
	case ctrl.DashActionShutdown:
		m.Ctrl.PendingAction = ctrl.DashActionNone
		if m.AuthLoA >= 3 {
			m.ShutdownMode = "shutdown"
			m.ShutdownPct = 0
			m.SetScreen(ScreenShutdown)
			return nil
		}
		m.PendingDashAction = ctrl.DashActionShutdown
		m.AuthConfirmAction = "Apagar el servidor"
		m.SetScreen(ScreenAuthConfirm)
		return nil
	}
	if key.Matches(msg, DefaultDashboardKeyMap.Quit) {
		return tea.Quit
	}
	return nil
}

func keyLogs(m *Model, msg tea.KeyMsg) tea.Cmd {
	switch msg.String() {
	case "q", "Q":
		// Cancelar follow activo al salir de la pantalla de logs
		if m.JournalCancel != nil {
			m.JournalCancel()
			m.JournalCancel = nil
		}
		m.JournalCh = nil
		m.SetScreen(ScreenDashboard)
	case "ctrl+c":
		return tea.Quit
	case "left", "h":
		return switchLogTab(m, m.Ctrl.LogDaemon-1)
	case "right", "l":
		return switchLogTab(m, m.Ctrl.LogDaemon+1)
	}
	return nil
}

// switchLogTab cambia el tab activo del viewer de logs (T-112).
// Cancela el Follow() anterior e inicia uno nuevo con journalctl para el nuevo target.
// El tab "TUI" (índice 0) usa el ring local directamente — sin journalctl.
func switchLogTab(m *Model, newIdx int) tea.Cmd {
	n := panel.LogTabCount()
	if n == 0 {
		return nil
	}
	// wrap circular sin módulo negativo
	newIdx = ((newIdx % n) + n) % n
	m.Ctrl.LogDaemon = newIdx

	// Cancelar el follow anterior
	if m.JournalCancel != nil {
		m.JournalCancel()
		m.JournalCancel = nil
	}
	m.JournalCh = nil
	m.JournalEntries = nil
	m.Ctrl.JournalEntries = nil

	target := panel.LogTabTarget(newIdx)
	if target == tuilog.JournalID {
		// Tab "TUI" — usa ring local, no journalctl
		return nil
	}

	// Iniciar follow de journalctl para el nuevo target
	ch, cancel := tuilog.Follow(target, 50)
	m.JournalCh = ch
	m.JournalCancel = cancel
	if m.TUILog != nil {
		m.TUILog.Info(tuilog.SrcUI, "viewer → %s", target)
	}
	return tuilog.FollowCmd(m.JournalCh)
}

func keyShutdown(m *Model, msg tea.KeyMsg) tea.Cmd {
	if key.Matches(msg, DefaultInstallingKeyMap.Abort) {
		return tea.Quit
	}
	return nil
}

// ── Handlers de eventos WS ────────────────────────────────────────────────

func handleWS(m *Model, ev WsEventMsg) tea.Cmd {
	now := ev.Ts
	if now.IsZero() {
		now = time.Now()
	}
	var progCmd tea.Cmd
	sDim := styles.Dim

	switch ev.EvType {
	case "response":
		if ev.Total > 0 {
			m.FichasTotal = ev.Total
		}
		m.NeedStatusSync = true

	case "bootstrap_status":
		if ev.Data == nil {
			return progCmd
		}
		if total, ok := ev.Data["total_fichas"].(float64); ok && int(total) > m.FichasTotal {
			m.FichasTotal = int(total)
		}
		fichasArr, _ := ev.Data["fichas"].([]interface{})
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
			fd := FichaOrCreate(m, fichaID)
			switch st {
			case "INSTALADA":
				if fd.Status != FichaDone {
					fd.Status = FichaDone
					m.FichasOK++
					AddLog(m, LogEntry{Ts: now, Level: LogOK, Ficha: fichaID,
						Msg: fichaID + " — ya instalada (sincronizado)"})
				}
			case "FALLA_INSTALACION":
				if fd.Status != FichaFailed {
					fd.Status = FichaFailed
				}
			case "INSTALANDO":
				if fd.Status != FichaActive {
					fd.Status = FichaActive
					fd.StartTime = now
					m.PendingLogTail = fichaID
				}
			}
		}
		pct := float64(m.FichasOK) / float64(util.MaxInt(m.FichasTotal, 1))
		progCmd = m.ProgBar.SetPercent(pct)

	case EvSagaStart:
		if ev.Ficha == "" {
			return progCmd
		}
		fd := FichaOrCreate(m, ev.Ficha)
		fd.Status = FichaActive
		fd.StartTime = now
		boslog.Info("saga iniciada", "ficha", ev.Ficha)
		m.TUILog.Info(tuilog.SrcInstall, "ficha %s — inicio instalación", ev.Ficha)
		AddLog(m, LogEntry{Ts: now, Level: LogInfo, Ficha: ev.Ficha,
			Msg: "📦 " + ev.Ficha + versionSuffix(m, ev.Ficha, sDim) + " — iniciando instalación"})

	case EvStepStart:
		if ev.Ficha == "" || ev.Step == "" {
			return progCmd
		}
		fd := FichaOrCreate(m, ev.Ficha)
		for i := range fd.Steps {
			if fd.Steps[i].Status == StepActive {
				fd.Steps[i].Status = StepDone
				fd.Steps[i].Duration = now.Sub(fd.Steps[i].StartTime)
			}
		}
		fd.Steps = append(fd.Steps, StepDetail{
			Name:      ev.Step,
			Status:    StepActive,
			StartTime: now,
			Msg:       ev.Msg,
		})
		AddLog(m, LogEntry{Ts: now, Level: LogStep, Ficha: ev.Ficha,
			Msg: ev.Step + stepMsgSuffix(ev.Msg)})

	case EvStepOK:
		fd := FichaOrCreate(m, ev.Ficha)
		found := false
		for i := len(fd.Steps) - 1; i >= 0; i-- {
			if fd.Steps[i].Name == ev.Step || fd.Steps[i].Status == StepActive {
				fd.Steps[i].Status = StepDone
				fd.Steps[i].Duration = now.Sub(fd.Steps[i].StartTime)
				if ev.Msg != "" {
					fd.Steps[i].Msg = ev.Msg
				}
				found = true
				break
			}
		}
		if !found {
			fd.Steps = append(fd.Steps, StepDetail{
				Name: ev.Step, Status: StepDone,
				StartTime: now, Duration: 0, Msg: ev.Msg,
			})
		}
		if ev.Msg != "" {
			AddLog(m, LogEntry{Ts: now, Level: LogStep, Ficha: ev.Ficha,
				Msg: "  ✓ " + ev.Step + stepMsgSuffix(ev.Msg)})
		}

	case EvStepFail:
		fd := FichaOrCreate(m, ev.Ficha)
		for i := len(fd.Steps) - 1; i >= 0; i-- {
			if fd.Steps[i].Status == StepActive {
				fd.Steps[i].Status = StepFailed
				fd.Steps[i].Duration = now.Sub(fd.Steps[i].StartTime)
				fd.Steps[i].ErrMsg = ev.ErrDetail
				break
			}
		}
		boslog.Error("step FALLO", "ficha", ev.Ficha, "step", ev.Step, "err", ev.ErrDetail)
		m.TUILog.Warn(tuilog.SrcInstall, "step %s/%s — falló: %s", ev.Ficha, ev.Step, ev.ErrDetail)
		AddLog(m, LogEntry{Ts: now, Level: LogError, Ficha: ev.Ficha,
			Msg: "  ✗ " + ev.Step + ": " + ev.ErrDetail})

	case EvSagaOK:
		if ev.Ficha == "" {
			return progCmd
		}
		fd := FichaOrCreate(m, ev.Ficha)
		for i := range fd.Steps {
			if fd.Steps[i].Status == StepActive {
				fd.Steps[i].Status = StepDone
				fd.Steps[i].Duration = now.Sub(fd.Steps[i].StartTime)
			}
		}
		fd.Status = FichaDone
		fd.Duration = now.Sub(fd.StartTime)
		m.FichasOK++
		pct := float64(m.FichasOK) / float64(m.FichasTotal)
		progCmd = m.ProgBar.SetPercent(pct)
		boslog.Info("saga OK", "ficha", ev.Ficha,
			"duracion", fd.Duration.Round(time.Second).String(),
			"ok", m.FichasOK, "total", m.FichasTotal)
		m.TUILog.Info(tuilog.SrcInstall, "ficha %s — OK (%s) [%d/%d]",
			ev.Ficha, fd.Duration.Round(time.Second), m.FichasOK, m.FichasTotal)
		AddLog(m, LogEntry{Ts: now, Level: LogOK, Ficha: ev.Ficha,
			Msg: ev.Ficha + versionSuffix(m, ev.Ficha, sDim) + " — instalada (" + util.FormatDur(fd.Duration) + ")"})

	case EvFichaLog:
		if ev.Ficha != "" && ev.Msg != "" {
			stepName := ""
			if fd, ok := m.Fichas[ev.Ficha]; ok {
				if as := fd.ActiveStep(); as != nil {
					stepName = as.Name
				}
			}
			AddLog(m, LogEntry{Ts: now, Level: LogStep, Ficha: ev.Ficha, Step: stepName, Msg: ev.Msg})
		}
		return progCmd

	case EvSagaFail:
		if ev.Ficha == "" {
			return progCmd
		}
		fd := FichaOrCreate(m, ev.Ficha)
		for i := range fd.Steps {
			if fd.Steps[i].Status == StepActive {
				fd.Steps[i].Status = StepFailed
				fd.Steps[i].Duration = now.Sub(fd.Steps[i].StartTime)
				fd.Steps[i].ErrMsg = ev.ErrDetail
			}
		}
		fd.Status = FichaFailed
		fd.Duration = now.Sub(fd.StartTime)
		fd.ErrMsg = ev.ErrDetail
		if fd.ErrMsg == "" && ev.Msg != "" {
			fd.ErrMsg = ev.Msg
		}
		m.ErrPanel = fd
		m.ViewMode = "error"
		boslog.Error("saga FALLO", "ficha", ev.Ficha, "err", fd.ErrMsg,
			"duracion", fd.Duration.Round(time.Second).String())
		m.TUILog.Error(tuilog.SrcInstall, "ficha %s — FALLÓ: %s (%s)",
			ev.Ficha, fd.ErrMsg, fd.Duration.Round(time.Second))
		AddLog(m, LogEntry{Ts: now, Level: LogError, Ficha: ev.Ficha,
			Msg: ev.Ficha + " — FALLÓ: " + fd.ErrMsg})

	case "bootstrap_complete":
		// Instalación finalizada → directo al dashboard de control.
		// Los botones de reiniciar/apagar están en el ctrl dashboard.
		if err := WriteTenantConf(
			m.TenantName,
			m.TenantDomain,
		); err != nil {
			boslog.Error("tenant.conf no escrito", "err", err)
			AddLog(m, LogEntry{Ts: now, Level: LogError,
				Msg: "⚠ No se pudo escribir tenant.conf: " + err.Error()})
		}
		boslog.Info("bootstrap completado", "fichas_ok", m.FichasOK, "fichas_total", m.FichasTotal)
		m.TUILog.Info(tuilog.SrcBoot, "bootstrap completado %d/%d fichas", m.FichasOK, m.FichasTotal)
		m.SetScreen(ScreenDashboard)
		return DashTickCmd()
	}
	return progCmd
}

// FichaOrCreate devuelve la ficha por ID o la crea con estado Pending.
func FichaOrCreate(m *Model, id string) *FichaDetail {
	if m.Fichas == nil {
		m.Fichas = make(map[string]*FichaDetail)
	}
	if fd, ok := m.Fichas[id]; ok {
		return fd
	}
	fd := &FichaDetail{ID: id, Status: FichaPending}
	m.Fichas[id] = fd
	return fd
}

// AddLog agrega una entrada al log. La sincronización de viewports la hace app/ tras cada Update.
func AddLog(m *Model, e LogEntry) {
	m.Logs = append(m.Logs, e)
}

// StartBootstrap inicia el proceso de instalación.
func StartBootstrap(m *Model) tea.Cmd {
	m.SetScreen(ScreenInstalling)
	now := time.Now()
	m.StartTime = now
	AddLog(m, LogEntry{Ts: now, Level: LogInfo, Msg: "🚀 SBOS Bootstrap iniciado"})
	if m.TenantName != "" {
		AddLog(m, LogEntry{Ts: now, Level: LogInfo,
			Msg: "   Empresa: " + m.TenantName + "  ·  Dominio: " + m.TenantDomain})
	}
	AddLog(m, LogEntry{Ts: now, Level: LogInfo, Msg: "   22 fichas  ·  7 niveles del DAG"})

	if m.Config.DemoMode {
		if m.DemoRunner != nil {
			return tea.Batch(startDemoCmd(m), AwaitWS(m.WsCh, m.StopCh))
		}
		return AwaitWS(m.WsCh, m.StopCh)
	}

	est := CapacityEstimate(m.CapacityInputs)
	boslog.Info("bootstrap_start enviado",
		"tenant", m.TenantName,
		"dominio", m.TenantDomain,
		"admin", m.AdminEmail,
		"mfa", m.MFAEnabled,
	)
	return SendWS(m.WsConn, "bootstrap_start", map[string]interface{}{
		"razon_social":         m.TenantName,
		"nit":                  m.TenantNIT,
		"pais":                 m.TenantPais,
		"dominio":              m.TenantDomain,
		"email":                m.AdminEmail,
		"nombre":               m.AdminNombre,
		"password":             m.AdminPassword,
		"mfa":                  m.MFAEnabled,
		"cap_tenants":          est.Tenants,
		"cap_companies":        est.CompaniesPerTenant,
		"cap_branches":         est.BranchesPerCompany,
		"cap_users_per_branch": est.UsersPerBranch,
	})
}

// startDemoCmd lanza el DemoRunner en un goroutine dentro de un Cmd (no en Update).
func startDemoCmd(m *Model) tea.Cmd {
	runner := m.DemoRunner
	ch := m.WsCh
	return func() tea.Msg {
		go runner(ch)
		return nil
	}
}

// WriteTenantConf registra el servidor como instalado (ADR-022 — BOS escribe su propio estado).
func WriteTenantConf(razonSocial, dominio string) error {
	if err := os.MkdirAll("/etc/sbos", 0750); err != nil {
		return fmt.Errorf("crear /etc/sbos: %w", err)
	}
	content := fmt.Sprintf(
		"tenant_name = %q\ndominio     = %q\ninstalado   = true\nts          = %q\n",
		razonSocial, dominio, time.Now().UTC().Format(time.RFC3339),
	)
	return os.WriteFile("/etc/sbos/tenant.conf", []byte(content), 0640)
}

// ── Helpers de formato ────────────────────────────────────────────────────
// FormatDur, TruncA, WordWrap, MaxInt, BootMessage → util/format.go

// Truncate trunca s a max bytes con "…".
func Truncate(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max-1] + "…"
}

// BuildSlug convierte una razón social en slug para el dominio sugerido.
func BuildSlug(s string) string {
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

// versionSuffix retorna la versión de una ficha formateada con estilo dim.
func versionSuffix(m *Model, id string, sDim lipgloss.Style) string {
	_ = m // no usado actualmente — FichaVersions es la fuente
	if v, ok := FichaVersions[id]; ok {
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

// IsInstalled informa si el servidor ya fue instalado.
func IsInstalled() bool {
	_, err := os.Stat("/etc/sbos/tenant.conf")
	return err == nil
}

