# TUI PARIDAD — Auditoría de paridad visual
## F3.11 — Stub vs Legacy · BOS-REPAIR

**Fecha:** 2026-06-11  
**Fuente legacy:** `cmd/bosctl/install_ui_impl.go` (4,461 líneas)  
**Snapshot referencia:** `_snapshots/ORIGINAL_pre-reparacion_2026-06-09_01-29/cmd/bosctl/install_ui.go`  
**Target:** `internal/tui/screens/*.go` (actualmente 15 stubs vacíos)

---

## Tabla de paridad — 15 pantallas

| ID | Screen enum | Archivo target | Función nueva | Funciones legacy (impl.go) | Líneas | Complejidad | Estado |
|---|---|---|---|---|---|---|---|
| S00 | ScreenWelcome | splash.go | RenderWelcome | viewSplashWelcome | 3441–3522 (82L) | Media | **COMPLETO** ✅ F3.12 |
| S01 | ScreenWizardP1 | wizard.go | RenderWizardP1 | viewWelcome + renderMenu | 2231–2291 + 2201–2230 (91L) | Baja | **COMPLETO** ✅ F3.13 |
| S02 | ScreenWizardP2 | wizard.go | RenderWizardP2 | viewForm (labels tenant) | 2292–2333 (42L) | Baja | **COMPLETO** ✅ F3.13 |
| S03 | ScreenWizardP3 | wizard.go | RenderWizardP3 | viewAdmin + renderMFARow | 2334–2419 (86L) | Media | **COMPLETO** ✅ F3.13 |
| S03B | ScreenWizardCapacity | wizard.go | RenderWizardCapacity | viewCapacity + capacityEstimate | (140L) | Media | **COMPLETO** ✅ M1-CAP-FIX · Keybindings → model/update_wizard.go |
| S04 | ScreenWizardP4 | wizard.go | RenderWizardP4 | viewConfirm | 2420–2485 (66L) | Baja | **COMPLETO** ✅ F3.13 |
| S05 | ScreenInstalling | installing.go | RenderInstalling | viewInstalling + Normal/XS/SM/MD + buildColA/B/C | 2681–3014 + 2529–2680 (485L) | **Alta** | **COMPLETO** ✅ F3.14 |
| S05B | ScreenInstallLog | installing.go | RenderInstallLog | viewFullLog | 3015–3093 (79L) | Media | **COMPLETO** ✅ F3.14 |
| S05C | ScreenInstallErr | installing.go | RenderInstallErr | viewErrorPanel | 3094–3233 (140L) | Media | **COMPLETO** ✅ F3.14 |
| S06 | ScreenInstallDone | postinstall.go | RenderInstallDone | viewComplete + TabBar + Body | 3234–3440 (207L) | Media | **COMPLETO** ✅ F3.15 |
| S07 | ScreenReboot | postinstall.go | RenderReboot | viewReboot | 3613–3674 (62L) | Baja | **COMPLETO** ✅ F3.15 |
| S08 | ScreenBoot | postinstall.go | RenderBoot | viewBoot | 3675–3771 (97L) | Baja | **COMPLETO** ✅ F3.15 |
| S09 | ScreenDashboard | dashboard.go | RenderDashboard | viewDashboard | 3772–3870 (99L) | Media | **COMPLETO** ✅ F3.16 |
| S10 | ScreenLogs | dashboard.go | RenderLogs | viewLogs | 3871–3939 (69L) | Baja | **COMPLETO** ✅ F3.16 |
| S11 | ScreenShutdown | dashboard.go | RenderShutdown | viewShutdown | 3940–~4028 (89L) | Media | **COMPLETO** ✅ F3.16 |
| S14 | ScreenGoodbye | splash.go | RenderGoodbye | viewSplashGoodbye | 3523–3612 (90L) | Media | **COMPLETO** ✅ F3.12 |

---

## Componentes compartidos — necesitan `screens/shared.go`

Las pantallas S01–S14 (excepto splash S00/S14) componen su output con header+footer.
Estos helpers deben extraerse a `screens/shared.go` antes de F3.13 (Wizard).

| Helper legacy (impl.go) | Líneas | Función nueva en shared.go | Usada por |
|---|---|---|---|
| wrapWithMargin | 1873–1888 (16L) | WrapWithMargin(content, termW) | View() de impl.go (no screen) |
| renderStepper | 1929–1964 (36L) | RenderStepper(m) | S01–S05 (via header) |
| viewHeader | 1965–2086 (122L) | RenderHeader(m) | S01–S14 excl. splash |
| viewErr | 2087–2101 (15L) | RenderErrLine(msg) | S01–S04 (inline en body) |
| viewFooter | 2102–2200 (99L) | RenderFooter(m) | S01–S14 excl. splash |
| renderMenu | 2201–2230 (30L) | RenderMenu(items, focus, width) | S01 wizard P1 |

> **Nota de arquitectura:** `screens.RenderXxx` retorna solo el cuerpo de la pantalla.
> El View() de impl.go añade `RenderHeader` + sep + cuerpo + `RenderFooter`.
> Las pantallas splash S00/S14 son la excepción: retornan el contenido completo
> (sin header/footer) y View() solo aplica WrapWithMargin.

---

## Mapa de equivalencias de campos — modelo local → exportado

Necesario para reescribir cada función en screens/ con `tuimodel.Model`.

| Campo local (impl.go) | Campo exportado (internal/tui/model) | Tipo exportado |
|---|---|---|
| m.width | m.Width | int |
| m.height | m.Height | int |
| m.termW | m.TermW | int |
| m.screen | m.CurrentScreen | Screen |
| m.bodyHeight | m.BodyHeight | int |
| m.bodyVP | m.BodyVP | viewport.Model |
| m.sectionVP | m.SectionVP | viewport.Model |
| m.showStepper | m.ShowStepper | bool |
| m.showNavHint | m.ShowNavHint | bool |
| m.installed | m.Installed | bool |
| m.showTimestamp | m.ShowTimestamp | bool |
| m.bootPct | m.BootPct | float64 |
| m.bootMsg | m.BootMsg | string |
| m.bootLines | m.BootLines | []string |
| m.countdownSec | m.CountdownSec | int |
| m.dashUptime | m.DashUptime | time.Duration |
| m.dashLogs | m.DashLogs | []LogEntry |
| m.vpDash | m.VpDash | viewport.Model |
| m.logFilter | m.LogFilter | LogLevel |
| m.logSource | m.LogSource | string |
| m.logSearch | m.LogSearch | string |
| m.vpLog | m.VpLog | viewport.Model |
| m.shutdownMode | m.ShutdownMode | string |
| m.shutdownPct | m.ShutdownPct | float64 |
| m.shutdownStep | m.ShutdownStep | int |
| m.helpModel | m.HelpModel | help.Model |
| m.completeFocus | m.CompleteFocus | int |
| m.sys | m.Sys | SysInfo |
| m.tenantInputs | m.TenantInputs | [4]textinput.Model |
| m.tenantFocus | m.TenantFocus | int |
| m.adminInputs | m.AdminInputs | [4]textinput.Model |
| m.adminFocus | m.AdminFocus | int |
| m.mfaEnabled | m.MFAEnabled | bool |
| m.welcomeFocus | m.WelcomeFocus | int |
| m.confirmFocus | m.ConfirmFocus | int |
| m.spinner | m.Spinner | spinner.Model |
| m.progBar | m.ProgBar | progress.Model |
| m.phases | m.Phases | []InstallPhase |
| m.fichas | m.Fichas | map[string]*FichaDetail |
| m.logs | m.Logs | []LogEntry |
| m.fichasOK | m.FichasOK | int |
| m.fichasTotal | m.FichasTotal | int |
| m.startTime | m.StartTime | time.Time |
| m.viewMode | m.ViewMode | string |
| m.errPanel | m.ErrPanel | *FichaDetail |
| m.errFocus | m.ErrFocus | int |
| m.vpA, vpB, vpC | m.VpA, VpB, VpC | viewport.Model |
| m.vpReady | m.VpReady | bool |
| m.installingFocus | m.InstallingFocus | int |
| m.vpAutoScroll | m.VpAutoScroll | bool |
| m.errMsg | m.ErrMsg | string |

---

## Mapa de equivalencias de estilos — local → styles package

| Var local (impl.go) | Equivalente en `internal/tui/styles` |
|---|---|
| cGreen/cGreenS | styles.HexGreen |
| cCyan/cCyanS | styles.HexCyan |
| cYellow/cYellowS | styles.HexYellow |
| cRed/cRedS | styles.HexRed |
| cDim/cDimS | styles.HexDim |
| sBold | styles.Bold |
| sDim | styles.Dim |
| sGreen | styles.Green |
| sCyan | styles.Cyan |
| sRed | styles.Red |
| sYellow | styles.Yellow |
| sMuted | styles.Muted |
| sWhite | styles.White |
| sTopBar | styles.TopBar |
| sTitle | styles.Title |
| sFooter | styles.Footer |
| sBox | styles.Box |
| sBoxActive | styles.BoxActive |
| sPanelDiv | styles.PanelDiv |
| sHelpBox | styles.HelpBox |
| sErrBox | styles.ErrBox |
| sInputInactive | styles.InputInactive |
| sInputActive | styles.InputActive |
| sStepOK | styles.StepOK |
| sStepActive | styles.StepActive |
| sStepPending | styles.StepPending |
| sStepFail | styles.StepFail |
| sLabel | styles.Label |
| sLabelActive | styles.LabelActive |
| icOk() | styles.IconOK() |
| icRun() | styles.IconRun() |
| icPend() | styles.IconPending() |
| icErr() | styles.IconErr() |
| icWarn() | styles.IconWarn() |
| icBos() | styles.IconBos() |
| renderMFARow() | styles.RenderMFAToggle() |

---

## Mapa de equivalencias de helpers — local → helpers package

| Función local (impl.go) | Equivalente en `internal/tui/screens/helpers.go` |
|---|---|
| formatDur(d) | FormatDur(d) |
| truncA(s, max) | TruncA(s, max) |
| wordWrap(text, maxW) | WordWrap(text, maxW) |
| maxInt(a, b) | MaxInt(a, b) |
| truncByWidth(s, maxW) | TruncByWidth(s, maxW) |
| clipColumnCenter(...) | ClipColumnCenter(...) |
| clipColumnTail(...) | ClipColumnTail(...) |
| bootMessage(pct) | BootMessage(pct) |
| vScrollbar(vp, h) | tuimodel.VScrollbar(vp, h) |
| hScrollbar(vp, w) | tuimodel.HScrollbar(vp, w) |
| m.vpDims() | tuimodel.VpDims(m.Width, m.BodyHeight) |
| m.mode() | Mode(m.Width) → helper en shared.go |

---

## Plan de ejecución por grupo (F3.12–F3.17)

### F3.12 — Grupo Splash (S00, S14) — sin shared.go necesario
- RenderWelcome: impl.go 3441–3522 → splash.go
- RenderGoodbye: impl.go 3523–3612 → splash.go
- No usan header/footer; WrapWithMargin permanece en impl.go View()
- DoD: golden 80×24 y 120×40 · bosctl install --demo S00/S14

### F3.13 — Grupo Wizard (S01–S04) — necesita shared.go primero
- Crear screens/shared.go: RenderHeader + RenderFooter + RenderStepper + RenderMenu
- RenderWizardP1–P4 usan BodyVP.View() para su contenido interno
- RenderMFARow ya está en styles.RenderMFAToggle()
- DoD: 4 pantallas navegables con --demo, MFA toggle real en S03

### F3.14 — Grupo Install (S05/S05B/S05C) — el más complejo
- RenderInstalling: responsivo XS/SM/MD con 3 viewports (VpA/VpB/VpC)
- BuildColA/B/CContent: árbol de fases, pasos activos, log en vivo
- RenderInstallLog + RenderInstallErr: vistas alternativas de P5
- DoD: 3-columnas real en MD, degradación XS/SM

### F3.15 — Grupo Post (S06, S07, S08)
- RenderInstallDone: tabs con 4 secciones (Tenant/Ubuntu/K8s/SBOS)
- RenderReboot: countdown real (CountdownSec)
- RenderBoot: barra progreso + BootMessage
- DoD: countdown anima con TickMsg real

### F3.16 — Grupo Runtime (S09, S10, S11)
- RenderDashboard: columna derecha 30ch fija + flex izquierda
- RenderLogs: toolbar dual (filtro por level + source) + VpLog
- RenderShutdown: panel dual (izquierda flex + derecha 28ch)
- DoD: logs con filtros LogLevel/LogSource operativos

### F3.17 — Modularidad garantizada
- bosctl dev new-screen: plantilla en 5 pasos
- TestScreens_TodasRegistradas: verifica que dispatcher.go tenga los 15+N casos

---

## DoD de F3.11

- [x] 15 filas verificadas contra `_snapshots/` y `install_ui_impl.go`
- [x] Mapa de campos local → exportado completo (51 campos)
- [x] Mapa de estilos completo (28 vars + 6 iconos)
- [x] Mapa de helpers completo (12 funciones)
- [x] Componentes compartidos identificados (6 funciones → shared.go)
- [x] Plan de ejecución por grupo documentado
- [x] Ningún archivo de código modificado (solo documentación)

*BOS-REPAIR F3.11 — 2026-06-11 · Claude Sonnet 4.6*
