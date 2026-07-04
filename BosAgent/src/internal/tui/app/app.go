// Package app — app.go: bridge tea.Model que une model/ y screens/.
//
// Resuelve la dependencia circular entre tuimodel (no puede importar screens)
// y screens (importa tuimodel). App importa ambos y delega:
//
//	Init()   → model.Init()
//	Update() → model.HandleUpdate()
//	View()   → screens.Render(m)
//
// BOS-REPAIR F3.MIGRATE — sustituye initialModel() en cmd/bosctl/install_ui.go.
package app

import (
	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/screens"
	"bos/internal/tui/ctrl"
	"bos/internal/tui/demo"

	tea "github.com/charmbracelet/bubbletea"
)

// App implementa tea.Model.
type App struct {
	m *tuimodel.Model
}

// New construye el App con la configuración dada.
// Si cfg.DemoMode es true, inyecta el DemoRunner para evitar importar demo desde model.
func New(cfg tuimodel.Config, seed tuimodel.SeedData) *App {
	m := tuimodel.New(cfg, seed)
	if cfg.DemoMode {
		// Demo simula instalación desde cero — ignora estado real del sistema
		m.Installed = false
	} else {
		m.Installed = tuimodel.IsInstalled()
	}
	m.Phases = tuimodel.DefaultPhases()
	m.Fichas = tuimodel.InitFichas()

	if cfg.DemoMode {
		m.DemoRunner = func(ch chan tuimodel.WsEventMsg) {
			bridgeCh := make(chan tuimodel.WsEventMsg, 256)
			go demo.RunDemo(bridgeCh, m.Phases)
			for msg := range bridgeCh {
				ch <- msg
			}
		}
	}

	return &App{m: m}
}

// Init cumple tea.Model.
func (a *App) Init() tea.Cmd {
	return a.m.Init()
}

// Update cumple tea.Model.
func (a *App) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	newM, cmd := tuimodel.HandleUpdate(a.m, msg)
	a.m = newM
	syncViewports(a.m)
	return a, cmd
}

// syncViewports llena los 3 viewports de S05 con contenido estilizado (lipgloss).
// Vive en app/ para poder importar screens/ sin dependencia circular con model/.
func syncViewports(m *tuimodel.Model) {
	if !m.VpReady {
		return
	}
	wA, wB, wC, _ := tuimodel.VpDims(m.Width, m.BodyHeight)
	m.VpA.SetContent(screens.BuildColA(*m, wA-1))
	m.VpB.SetContent(screens.BuildColB(*m, wB-1))
	m.VpC.SetContent(screens.BuildColC(*m, wC-3))
	if m.VpAutoScroll {
		targetLine := activePhaseLineIdx(m)
		half := m.VpA.Height / 2
		if targetLine > half {
			m.VpA.SetYOffset(targetLine - half)
		}
		m.VpB.GotoBottom()
		m.VpC.GotoBottom()
	}
}

// activePhaseLineIdx calcula la línea de la fase activa en colA para centrar el viewport.
func activePhaseLineIdx(m *tuimodel.Model) int {
	line := 0
	for _, ph := range m.Phases {
		allDone := true
		anyActive := false
		for _, fid := range ph.Fichas {
			if fd, ok := m.Fichas[fid]; ok {
				if fd.Status == tuimodel.FichaActive {
					anyActive = true
				}
				if fd.Status != tuimodel.FichaDone {
					allDone = false
				}
			} else {
				allDone = false
			}
		}
		if anyActive {
			return line
		}
		if !allDone {
			return line
		}
		line += 1 + len(ph.Fichas) + 1
	}
	return line
}

// SetInstalledBoot configura el App para iniciar en ScreenAuthLogin —
// el guardián de autenticación antes del dashboard (Proceso 2 del TUI-MAESTRO).
// Flujo: SAuth → (login OK) → ScreenBoot → ScreenDashboard.
// Sin auth = sin dashboard. Sin excepción.
func (a *App) SetInstalledBoot() {
	a.m.Installed = true
	a.m.SetScreen(tuimodel.ScreenAuthLogin)
	a.m.BootPct = 0
	a.m.BootMsg = "Iniciando SBOS..."
}

// View cumple tea.Model. Llama al dispatcher de pantallas.
// ScreenDashboard se intercepta aquí — ctrl/ maneja su propio chrome (TopBar + BottomBar).
func (a *App) View() string {
	if a.m.Width == 0 {
		return "Iniciando SBOS..."
	}
	if a.m.CurrentScreen == tuimodel.ScreenDashboard {
		return ctrl.Render(a.m.Ctrl)
	}
	return screens.WrapWithMargin(screens.Render(*a.m), a.m.TermW)
}
