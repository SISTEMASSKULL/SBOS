package screens_test

import (
	"strings"
	"testing"
	"time"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/screens"
)

// ── Helpers ───────────────────────────────────────────────────────────────────

func newInstallingModel() tuimodel.Model {
	cfg := tuimodel.Config{DemoMode: true}
	m := tuimodel.New(cfg, tuimodel.SeedData{})
	m.Width = 120
	m.Height = 40
	m.TermW = 120
	m.CurrentScreen = tuimodel.ScreenInstalling
	m.FichasTotal = 7
	m.FichasOK = 2
	m.StartTime = time.Now().Add(-90 * time.Second)
	// Datos de demo: 2 fases con fichas
	m.Phases = []tuimodel.InstallPhase{
		{Nombre: "Infraestructura", Fichas: []string{"postgresql", "redis"}},
		{Nombre: "Seguridad", Fichas: []string{"keycloak", "vault"}},
	}
	m.Fichas = map[string]*tuimodel.FichaDetail{
		"postgresql": {ID: "postgresql", Status: tuimodel.FichaDone,
			Duration: 45 * time.Second, Steps: []tuimodel.StepDetail{
				{Name: "instalar_postgresql", Status: tuimodel.StepDone, Duration: 20 * time.Second},
				{Name: "init_schema", Status: tuimodel.StepDone, Duration: 25 * time.Second},
			}},
		"redis": {ID: "redis", Status: tuimodel.FichaActive, Steps: []tuimodel.StepDetail{
			{Name: "instalar_redis", Status: tuimodel.StepDone, Duration: 10 * time.Second},
			{Name: "configure_redis", Status: tuimodel.StepActive, StartTime: time.Now().Add(-5 * time.Second)},
		}},
	}
	m.Logs = []tuimodel.LogEntry{
		{Ts: time.Now().Add(-30 * time.Second), Level: tuimodel.LogInfo, Ficha: "postgresql", Msg: "[OK] PostgreSQL iniciado"},
		{Ts: time.Now().Add(-10 * time.Second), Level: tuimodel.LogInfo, Ficha: "redis", Msg: "[INFO] Configurando Redis"},
		{Ts: time.Now().Add(-2 * time.Second), Level: tuimodel.LogWarn, Ficha: "redis", Msg: "Advertencia de memoria"},
	}
	return *m
}

// ── S05 — RenderInstalling ────────────────────────────────────────────────────

func TestScreen05_SinPanic_80x24(t *testing.T) {
	m := newInstallingModel()
	m.Width = 80
	m.Height = 24
	if out := screens.RenderInstalling(m); out == "" {
		t.Fatal("RenderInstalling 80×24: retornó vacío")
	}
}

func TestScreen05_SinPanic_120x40(t *testing.T) {
	m := newInstallingModel()
	if out := screens.RenderInstalling(m); out == "" {
		t.Fatal("RenderInstalling 120×40: retornó vacío")
	}
}

func TestScreen05_SinPanic_xs(t *testing.T) {
	m := newInstallingModel()
	m.Width = 50
	m.Height = 20
	if out := screens.RenderInstalling(m); out == "" {
		t.Fatal("RenderInstalling XS (50×20): retornó vacío")
	}
}

func TestScreen05_Paridad_progreso(t *testing.T) {
	m := newInstallingModel()
	out := screens.RenderInstalling(m)
	for _, kw := range []string{"fichas", "completadas", "pendientes"} {
		if !strings.Contains(out, kw) {
			t.Errorf("RenderInstalling: falta %q en output", kw)
		}
	}
}

func TestScreen05_Paridad_fases(t *testing.T) {
	// SM (60-79) muestra fases directamente sin necesitar viewports inicializados
	m := newInstallingModel()
	m.Width = 72
	m.Height = 30
	out := screens.RenderInstalling(m)
	for _, kw := range []string{"Infraestructura", "Seguridad", "postgresql", "redis"} {
		if !strings.Contains(out, kw) {
			t.Errorf("RenderInstalling SM: falta fase/ficha %q", kw)
		}
	}
}

func TestScreen05_MD_vpNotReady(t *testing.T) {
	m := newInstallingModel()
	m.VpReady = false // default: sin viewports inicializados
	out := screens.RenderInstalling(m)
	if !strings.Contains(out, "Iniciando paneles") {
		t.Error("RenderInstalling MD vpNotReady: falta 'Iniciando paneles'")
	}
}

func TestScreen05_Dispatch_fulllog(t *testing.T) {
	m := newInstallingModel()
	m.ViewMode = "fulllog"
	out := screens.RenderInstalling(m)
	// Debe despachar a RenderInstallLog: tiene toolbar "Todos"
	if !strings.Contains(out, "Todos") {
		t.Error("RenderInstalling ViewMode=fulllog: debe despachar a RenderInstallLog")
	}
}

func TestScreen05_Dispatch_error(t *testing.T) {
	m := newInstallingModel()
	m.ViewMode = "error"
	m.ErrPanel = m.Fichas["redis"]
	out := screens.RenderInstalling(m)
	// Debe despachar a RenderInstallErr
	if !strings.Contains(out, "Pasos ejecutados") && !strings.Contains(out, "Reintentar") {
		t.Error("RenderInstalling ViewMode=error: debe despachar a RenderInstallErr")
	}
}

func TestScreen05_Dispatch_screenInstallLog(t *testing.T) {
	m := newInstallingModel()
	m.CurrentScreen = tuimodel.ScreenInstallLog
	out := screens.RenderInstalling(m)
	if !strings.Contains(out, "Todos") {
		t.Error("RenderInstalling ScreenInstallLog: debe despachar a RenderInstallLog")
	}
}

// ── S05B — RenderInstallLog ───────────────────────────────────────────────────

func TestScreen05B_SinPanic_80x24(t *testing.T) {
	m := newInstallingModel()
	m.Width = 80
	m.Height = 24
	m.CurrentScreen = tuimodel.ScreenInstallLog
	if out := screens.RenderInstallLog(m); out == "" {
		t.Fatal("RenderInstallLog 80×24: retornó vacío")
	}
}

func TestScreen05B_Paridad_toolbar(t *testing.T) {
	m := newInstallingModel()
	m.CurrentScreen = tuimodel.ScreenInstallLog
	out := screens.RenderInstallLog(m)
	for _, kw := range []string{"Todos", "Warn", "Error", "líneas"} {
		if !strings.Contains(out, kw) {
			t.Errorf("RenderInstallLog: falta %q en toolbar", kw)
		}
	}
}

func TestScreen05B_Paridad_logContent(t *testing.T) {
	m := newInstallingModel()
	m.CurrentScreen = tuimodel.ScreenInstallLog
	out := screens.RenderInstallLog(m)
	// Los logs de demo deben aparecer
	if !strings.Contains(out, "PostgreSQL") && !strings.Contains(out, "Redis") {
		t.Error("RenderInstallLog: contenido de log no aparece")
	}
}

func TestScreen05B_FiltroWarn(t *testing.T) {
	m := newInstallingModel()
	m.CurrentScreen = tuimodel.ScreenInstallLog
	m.LogFilter = tuimodel.LogWarn
	out := screens.RenderInstallLog(m)
	// Solo debería quedar la advertencia de memoria
	if !strings.Contains(out, "memoria") {
		t.Error("RenderInstallLog filtro Warn: no muestra la advertencia de memoria")
	}
}

func TestScreen05B_LogSearch(t *testing.T) {
	m := newInstallingModel()
	m.CurrentScreen = tuimodel.ScreenInstallLog
	m.LogSearch = "Redis"
	out := screens.RenderInstallLog(m)
	if !strings.Contains(out, "Redis") {
		t.Error("RenderInstallLog búsqueda 'Redis': no aparece en output")
	}
}

func TestScreen05B_SinLogs_placeholder(t *testing.T) {
	m := newInstallingModel()
	m.CurrentScreen = tuimodel.ScreenInstallLog
	m.Logs = nil
	out := screens.RenderInstallLog(m)
	if !strings.Contains(out, "Sin logs") {
		t.Error("RenderInstallLog sin logs: falta placeholder 'Sin logs'")
	}
}

// ── S05C — RenderInstallErr ───────────────────────────────────────────────────

func TestScreen05C_SinPanic_NilErrPanel(t *testing.T) {
	m := newInstallingModel()
	m.CurrentScreen = tuimodel.ScreenInstallErr
	m.ErrPanel = nil
	if out := screens.RenderInstallErr(m); out == "" {
		t.Fatal("RenderInstallErr ErrPanel=nil: retornó vacío")
	}
}

func TestScreen05C_Placeholder_NilErrPanel(t *testing.T) {
	m := newInstallingModel()
	m.ErrPanel = nil
	out := screens.RenderInstallErr(m)
	if !strings.Contains(out, "No hay error") {
		t.Error("RenderInstallErr ErrPanel=nil: falta placeholder 'No hay error'")
	}
}

func TestScreen05C_SinPanic_80x24(t *testing.T) {
	m := newInstallingModel()
	m.Width = 80
	m.Height = 24
	m.CurrentScreen = tuimodel.ScreenInstallErr
	m.ErrPanel = m.Fichas["redis"]
	m.ErrPanel.ErrMsg = "timeout al conectar con Redis"
	if out := screens.RenderInstallErr(m); out == "" {
		t.Fatal("RenderInstallErr 80×24: retornó vacío")
	}
}

func TestScreen05C_Paridad_contenido(t *testing.T) {
	m := newInstallingModel()
	m.CurrentScreen = tuimodel.ScreenInstallErr
	m.ErrPanel = m.Fichas["redis"]
	m.ErrPanel.ErrMsg = "timeout al conectar"
	out := screens.RenderInstallErr(m)
	for _, kw := range []string{"Causa", "Pasos ejecutados", "Reintentar", "Cancelar"} {
		if !strings.Contains(out, kw) {
			t.Errorf("RenderInstallErr: falta %q", kw)
		}
	}
}

func TestScreen05C_Paridad_xs(t *testing.T) {
	m := newInstallingModel()
	m.Width = 50
	m.Height = 20
	m.ErrPanel = m.Fichas["redis"]
	m.ErrPanel.ErrMsg = "error de red"
	out := screens.RenderInstallErr(m)
	// En XS no hay panel lateral, pero debe haber info de causa
	if !strings.Contains(out, "Causa") {
		t.Error("RenderInstallErr XS: falta 'Causa'")
	}
}

func TestScreen05C_ErrFocus_alternativo(t *testing.T) {
	m := newInstallingModel()
	m.ErrPanel = m.Fichas["redis"]
	m.ErrFocus = 3 // Cancelar instalación
	out := screens.RenderInstallErr(m)
	if !strings.Contains(out, "Cancelar") {
		t.Error("RenderInstallErr ErrFocus=3: falta 'Cancelar'")
	}
}

// ── Builders de columnas ──────────────────────────────────────────────────────

func TestBuildColA_contenido(t *testing.T) {
	m := newInstallingModel()
	out := screens.BuildColA(m, 30)
	for _, kw := range []string{"Fases", "postgresql", "redis", "Infraestructura"} {
		if !strings.Contains(out, kw) {
			t.Errorf("BuildColA: falta %q", kw)
		}
	}
}

func TestBuildColB_contenido(t *testing.T) {
	m := newInstallingModel()
	out := screens.BuildColB(m, 40)
	// postgresql está Done, redis está Active
	if !strings.Contains(out, "postgresql") {
		t.Error("BuildColB: falta 'postgresql' (ficha Done)")
	}
}

func TestBuildColB_sin_fichas(t *testing.T) {
	m := newInstallingModel()
	m.Fichas = map[string]*tuimodel.FichaDetail{}
	out := screens.BuildColB(m, 40)
	if !strings.Contains(out, "Esperando") {
		t.Error("BuildColB sin fichas activas: falta 'Esperando'")
	}
}

func TestBuildColC_contenido_log(t *testing.T) {
	m := newInstallingModel()
	out := screens.BuildColC(m, 40)
	// Alguno de los mensajes del log debe estar
	if !strings.Contains(out, "PostgreSQL") && !strings.Contains(out, "Redis") {
		t.Error("BuildColC: contenido del log no aparece")
	}
}

func TestBuildColC_sin_logs(t *testing.T) {
	m := newInstallingModel()
	m.Logs = nil
	out := screens.BuildColC(m, 40)
	if !strings.Contains(out, "Sin actividad") && !strings.Contains(out, "esperando") {
		t.Error("BuildColC sin logs: falta placeholder")
	}
}

// ── scriptTag ─────────────────────────────────────────────────────────────────

func TestScriptTag_detecta_OK(t *testing.T) {
	m := newInstallingModel()
	m.Logs = []tuimodel.LogEntry{
		{Level: tuimodel.LogInfo, Msg: "[OK] Servicio iniciado"},
	}
	out := screens.BuildColC(m, 80)
	// El output debe existir y no hacer panic
	if out == "" {
		t.Error("BuildColC con [OK] tag: retornó vacío")
	}
}

func TestScriptTag_detecta_ERROR(t *testing.T) {
	m := newInstallingModel()
	m.Logs = []tuimodel.LogEntry{
		{Level: tuimodel.LogInfo, Msg: "[ERROR] Fallo crítico"},
	}
	out := screens.BuildColC(m, 80)
	if !strings.Contains(out, "ERROR") {
		t.Error("BuildColC con [ERROR] tag: falta en output")
	}
}

// ── Race ──────────────────────────────────────────────────────────────────────

func TestInstalling_Race(t *testing.T) {
	renders := []struct {
		name string
		fn   func(tuimodel.Model) string
		sc   tuimodel.Screen
	}{
		{"S05", screens.RenderInstalling, tuimodel.ScreenInstalling},
		{"S05B", screens.RenderInstallLog, tuimodel.ScreenInstallLog},
		{"S05C", screens.RenderInstallErr, tuimodel.ScreenInstallErr},
	}
	for _, r := range renders {
		r := r
		t.Run(r.name, func(t *testing.T) {
			m := newInstallingModel()
			m.CurrentScreen = r.sc
			if r.sc == tuimodel.ScreenInstallErr {
				m.ErrPanel = m.Fichas["redis"]
			}
			for i := 0; i < 10; i++ {
				t.Run("", func(t *testing.T) {
					t.Parallel()
					if out := r.fn(m); out == "" {
						t.Error("output vacío")
					}
				})
			}
		})
	}
}
