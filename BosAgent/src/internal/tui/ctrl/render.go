// Package ctrl — render.go: compositor principal del dashboard de control.
// Render() ensambla TopBar + Menu + Container + BottomBar.
//
// REGLA LIPGLOSS (v1.1.0, empiricamente validada):
//
//	Box.Width(w)  → visual_width  = w + 2  (borde agrega 2, padding DENTRO de w)
//	Box.Height(h) → visual_height = h + 2  (borde agrega 2)
//	content_width = w - 2 (padding 0,1 consume 2 de w)
//
// Para box de ancho visual V: usar Width(V-2) → visual = V, content = V-4
// Para box de alto visual H: usar Height(H-2) → visual = H, content_lines = H-2
package ctrl

import (
	"fmt"
	"strings"
	"time"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/ctrl/k8s"
	"bos/internal/tui/ctrl/panel"
	"bos/internal/tui/ctrl/sistema"
	"bos/internal/tui/styles"

	"github.com/charmbracelet/lipgloss"
)

// Render devuelve el dashboard completo listo para mostrarse.
// dm.Width y dm.Height son las dimensiones del área de contenido
// (ya descontadas las 4 líneas de margen de wrapWithMargin y las 2 col de margen lateral).
func Render(dm DashModel) string {
	if dm.Width < 30 || dm.Height < 8 {
		return styles.Dim.Render("Terminal demasiado pequeño")
	}

	topBar := renderTopBar(dm)       // 3 líneas: título + contexto + ───
	bottomBar := renderBottomBar(dm) // 2 líneas: ─── + hints

	topH := lipgloss.Height(topBar)
	botH := lipgloss.Height(bottomBar)
	midH := dm.Height - topH - botH
	if midH < 4 {
		midH = 4
	}

	// Grid 12 cols: menú = 3 cols (max 30 chars), contenido = resto.
	// Clamp superior B-01: en terminales >120 cols el menú no crece indefinidamente.
	g := styles.NewGrid(dm.Width, dm.Height)
	menuW := g.Span(3)
	if menuW < 24 {
		menuW = 24
	}
	if menuW > 30 {
		menuW = 30
	}
	contW := dm.Width - menuW

	menu := renderMenu(dm, midH, menuW)
	container := renderContainer(dm, contW, midH)

	middle := lipgloss.JoinHorizontal(lipgloss.Top, menu, container)
	return "\n" + lipgloss.JoinVertical(lipgloss.Left, topBar, middle, bottomBar)
}

// ── TopBar — 3 líneas: título + contexto + separador ─────────────────────────

func renderTopBar(dm DashModel) string {
	w := dm.Width

	l1 := styles.AccentBold.Render("⚡ Sistema de Control IAM Installer SBOS") +
		"  " +
		styles.Dim.Render("— bos-daemon")

	envDot := styles.Tint(styles.IconDotActive, styles.ColorAccentText)
	nodesReady := 0
	for _, n := range dm.Nodes {
		if n.Ready {
			nodesReady++
		}
	}
	k8sStatus := styles.Tint(styles.IconOK, styles.ColorStateOKFg)
	if nodesReady < len(dm.Nodes) {
		k8sStatus = styles.Tint(styles.IconWarn, styles.ColorStateWarnFg)
	}
	alertCrit := 0
	for _, a := range dm.Alerts {
		if a.Severity == dash.SevCritical && !a.Silenced {
			alertCrit++
		}
	}
	alertStr := styles.Dim.Render("Alertas: 0")
	if alertCrit > 0 {
		alertStr = styles.Red.Render(fmt.Sprintf("Alertas: %d ✗", alertCrit))
	}
	now := dm.Now
	if now.IsZero() {
		now = time.Now()
	}
	l2 := fmt.Sprintf("   skull@sbos-vps  %s %s  │  K8s: %s  │  Nodos: %d/%d  │  %s  │  %s",
		envDot, dm.Env,
		k8sStatus,
		nodesReady, len(dm.Nodes),
		alertStr,
		styles.Dim.Render(now.Format("2006-01-02 15:04:05")),
	)

	sepLine := styles.Dim.Render(strings.Repeat("─", w))
	return lipgloss.JoinVertical(lipgloss.Left,
		styles.Rule.Width(w).Render(l1),
		styles.Rule.Width(w).Render(l2),
		sepLine,
	)
}

// ── BottomBar — 2 líneas: separador + hints + botones de poder ───────────────

func renderBottomBar(dm DashModel) string {
	w := dm.Width

	h := dm.HelpModel
	h.Width = w / 2

	var hints string
	if dm.Focus == dash.FocusMenu {
		hints = h.View(dash.DefaultDashMenuKeyMap)
	} else {
		vk := dm.CurrentViewKey()
		hints = h.View(dash.DashBodyKeyMapWithSubTab(dash.SubTabMax(vk) > 0))
	}

	// Botones de poder — siempre visibles en el extremo derecho
	rebootBtn := styles.BtnRestart.Render("~ Reiniciar")
	shutdownBtn := styles.BtnShutdown.Render("o Apagar")
	keyHint := styles.Dim.Render(" ^R") + "      " + styles.Dim.Render("^P ")
	powerBlock := rebootBtn + keyHint + shutdownBtn

	hintsW := lipgloss.Width(hints)
	powerW := lipgloss.Width(powerBlock)
	gap := w - hintsW - powerW
	if gap < 1 {
		gap = 1
	}

	hintLine := hints + strings.Repeat(" ", gap) + powerBlock
	sep := styles.Dim.Render(strings.Repeat("─", w))
	return lipgloss.JoinVertical(lipgloss.Left, sep,
		lipgloss.NewStyle().Width(w).Render(hintLine),
	)
}

// ── Menú lateral ─────────────────────────────────────────────────────────────

// renderMenu construye el panel lateral de navegación.
// outerW = ancho visual total del menú (incluyendo borde+padding).
// totalH = alto visual total del menú (incluyendo borde+padding).
func renderMenu(dm DashModel, totalH int, outerW int) string {
	widthArg := outerW - 2
	heightArg := totalH - 2
	contentW := outerW - 4
	contentH := totalH - 2
	labelW := contentW - 2
	if widthArg < 4 {
		widthArg = 4
	}
	if labelW < 4 {
		labelW = 4
	}
	if contentH < 1 {
		contentH = 1
	}

	var lines []string
	lines = append(lines, styles.AccentBold.Render("NAVEGACIÓN"), "")

	for i, item := range dash.MenuDef {
		if item.ViewKey == "" {
			if strings.HasPrefix(item.Label, "─") {
				lines = append(lines, styles.Dim.Render(item.Label))
			} else {
				lines = append(lines, styles.Cyan.Render(item.Label))
			}
			continue
		}
		selected := i == dm.MenuIdx
		var prefix, labelStr string
		if selected && dm.Focus == dash.FocusMenu {
			prefix = styles.Cyan.Render("> ")
			labelStr = styles.MenuItemActive.Width(labelW).Render(item.Label)
		} else if selected {
			prefix = styles.White.Render("> ")
			labelStr = styles.MenuItemFocused.Width(labelW).Render(item.Label)
		} else {
			prefix = "  "
			labelStr = styles.MenuItemNormal.Width(labelW).Render(item.Label)
		}
		lines = append(lines, prefix+labelStr)
	}

	lines = append(lines,
		"",
		styles.Dim.Render(strings.Repeat("─", contentW)),
		styles.Dim.Render("ENV"),
		styles.Cyan.Render("> "+dm.Env)+" "+styles.Tint(styles.IconOK, styles.ColorStateOKFg),
	)

	allLines := strings.Split(strings.Join(lines, "\n"), "\n")
	selLine := -1
	lineIdx := 2
	for i, item := range dash.MenuDef {
		if item.ViewKey == "" {
			lineIdx++
			continue
		}
		if i == dm.MenuIdx {
			selLine = lineIdx
			break
		}
		lineIdx++
	}
	start := 0
	if selLine >= 0 && selLine >= contentH {
		start = selLine - contentH + 3
		if start < 0 {
			start = 0
		}
	}
	end := start + contentH
	if end > len(allLines) {
		end = len(allLines)
	}
	content := strings.Join(allLines[start:end], "\n")

	boxStyle := styles.Box.Width(widthArg).Height(heightArg)
	if dm.Focus == dash.FocusMenu {
		boxStyle = styles.BoxActive.Width(widthArg).Height(heightArg)
	}
	return boxStyle.Render(content)
}

// ── Container ─────────────────────────────────────────────────────────────────

// renderContainer construye el panel principal con el contenido de la vista activa.
func renderContainer(dm DashModel, totalW, totalH int) string {
	widthArg := totalW - 2
	heightArg := totalH - 2
	innerW := totalW - 4
	innerH := totalH - 2
	if widthArg < 6 {
		widthArg = 6
	}
	if innerW < 4 {
		innerW = 4
	}
	if innerH < 4 {
		innerH = 4
	}

	title := renderContainerTitle(dm)
	sep := dash.ColSep(innerW)
	statusLine := renderContainerStatus(dm)

	bodyH := innerH - 4
	if bodyH < 1 {
		bodyH = 1
	}
	body := renderContainerBody(dm, innerW, bodyH)

	bodyLines := strings.Split(body, "\n")
	scroll := dm.BodyScrollY
	if scroll < 0 {
		scroll = 0
	}
	maxScroll := len(bodyLines) - bodyH
	if maxScroll < 0 {
		maxScroll = 0
	}
	if scroll > maxScroll {
		scroll = maxScroll
	}
	end := scroll + bodyH
	if end > len(bodyLines) {
		end = len(bodyLines)
	}
	visible := bodyLines[scroll:end]
	for len(visible) < bodyH {
		visible = append(visible, "")
	}
	for i, l := range visible {
		if lipgloss.Width(l) > innerW {
			visible[i] = lipgloss.NewStyle().MaxWidth(innerW).Render(l)
		}
	}
	bodyVisible := strings.Join(visible, "\n")

	content := lipgloss.JoinVertical(lipgloss.Left,
		title,
		sep,
		bodyVisible,
		dash.ColSep(innerW),
		statusLine,
	)

	boxStyle := styles.Box.Width(widthArg).Height(heightArg).BorderForeground(styles.ColorSlate)
	if dm.Focus == dash.FocusBody {
		boxStyle = styles.BoxActive.Width(widthArg).Height(heightArg).BorderForeground(styles.ColorAccent)
	}
	return boxStyle.Render(content)
}

func renderContainerTitle(dm DashModel) string {
	vk := dm.CurrentViewKey()
	return lipgloss.NewStyle().Foreground(styles.ColorWhite).Bold(true).Render(dash.ViewTitle(vk))
}

func renderContainerStatus(dm DashModel) string {
	for _, j := range dm.Jobs {
		if j.Active {
			return styles.Tint(styles.IconSync, styles.ColorStateWarnFg) + " " +
				styles.Dim.Render(fmt.Sprintf("Instalando: %s  %d%%  %s items", j.Name, j.Pct, j.Items))
		}
	}
	return styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " " + styles.Dim.Render("Todos los servicios operativos")
}

func renderContainerBody(dm DashModel, w, h int) string {
	vk := dm.CurrentViewKey()
	switch vk {
	case "overview":
		return panel.Overview(dm, w, h)
	case "k8s-cp":
		return k8s.ControlPlane(dm, w, h)
	case "k8s-wl":
		return k8s.Workloads(dm, w, h)
	case "k8s-as":
		return k8s.Autoscaling(dm, w, h)
	case "k8s-net":
		return k8s.Network(dm, w, h)
	case "k8s-sto":
		return k8s.Storage(dm, w, h)
	case "os-met":
		return sistema.Metricas(dm, w, h)
	case "os-proc":
		return sistema.Procesos(dm, w, h)
	case "os-svc":
		return sistema.Systemd(dm, w, h)
	case "os-net":
		return sistema.Red(dm, w, h)
	case "os-disk":
		return sistema.Disco(dm, w, h)
	case "os-ker":
		return sistema.Kernel(dm, w, h)
	case "jobs":
		return panel.Jobs(dm, w, h)
	case "users":
		return panel.Usuarios(dm, w, h)
	case "pam":
		return panel.PAMRBAC(dm, w, h)
	case "logs":
		return panel.Logs(dm, dm.TUIRing, dm.JournalEntries, w, h)
	case "alertas":
		return panel.Alertas(dm, w, h)
	case "net-os":
		return panel.NetworkOS(dm, w, h)
	case "stor-os":
		return panel.StorageOS(dm, w, h)
	case "seg":
		return panel.Seguridad(dm, w, h)
	case "bkp":
		return panel.Backups(dm, w, h)
	case "mon":
		return panel.Monitoreo(dm, w, h)
	case "config":
		return panel.Config(dm, w, h)
	default:
		return dash.Placeholder(dash.ViewTitle(vk), w, h)
	}
}
