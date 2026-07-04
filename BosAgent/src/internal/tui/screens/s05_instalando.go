// Package screens — s05_instalando.go: pantalla principal de instalación activa (S05).
// Contiene RenderInstalling, BuildColA/B/C y todos los helpers compartidos
// con S05B (log) y S05C (error) — accesibles en el mismo paquete sin exportar.
package screens

import (
	"fmt"
	"strings"
	"time"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
	"bos/internal/tui/util"
)

// ── Log rendering ─────────────────────────────────────────────────────────────

// scriptTag detecta prefijos de nivel bash "[OK]", "[INFO]", "[WARN]", etc.
// Computa estilos en el momento de la llamada para respetar el tema activo.
func scriptTag(msg string) (tag, rest string, tagSty, msgSty styles.Style, found bool) {
	type entry struct {
		prefix string
		sty    func() (styles.Style, styles.Style)
	}
	entries := []entry{
		{"[OK]",      func() (styles.Style, styles.Style) { return styles.Success.Bold(true), styles.Success }},
		{"[SUCCESS]", func() (styles.Style, styles.Style) { return styles.Success.Bold(true), styles.Success }},
		{"[INFO]",    func() (styles.Style, styles.Style) { return styles.TableHeader.Bold(true), styles.Muted }},
		{"[DEBUG]",   func() (styles.Style, styles.Style) { return styles.DebugText, styles.DebugText }},
		{"[STEP]",    func() (styles.Style, styles.Style) { return styles.Dim.Bold(true), styles.Dim }},
		{"[WARN]",    func() (styles.Style, styles.Style) { return styles.Warning.Bold(true), styles.Warning }},
		{"[WARNING]", func() (styles.Style, styles.Style) { return styles.Warning.Bold(true), styles.Warning }},
		{"[ERROR]",   func() (styles.Style, styles.Style) { return styles.Error.Bold(true), styles.Error }},
		{"[ERR]",     func() (styles.Style, styles.Style) { return styles.Error.Bold(true), styles.Error }},
		{"[FAIL]",    func() (styles.Style, styles.Style) { return styles.Error.Bold(true), styles.Error }},
	}
	for _, e := range entries {
		if strings.HasPrefix(msg, e.prefix) {
			rest = strings.TrimPrefix(msg, e.prefix)
			if len(rest) > 0 && rest[0] == ' ' {
				rest = rest[1:]
			}
			t, m := e.sty()
			return e.prefix, rest, t, m, true
		}
	}
	return "", msg, styles.Style{}, styles.Style{}, false
}

// colorLogMsg colorea el mensaje de un LogEntry según nivel.
// LogInfo intenta detectar tags de bash antes de aplicar color base.
func colorLogMsg(e tuimodel.LogEntry) string {
	switch e.Level {
	case tuimodel.LogError:
		return styles.RedText.Render(e.Msg)
	case tuimodel.LogWarn:
		return styles.Muted.Render(e.Msg)
	default: // LogInfo — detectar [TAG] de bash
		if tag, rest, tagSty, msgSty, ok := scriptTag(e.Msg); ok {
			return tagSty.Render(tag) + msgSty.Render(" "+rest)
		}
		return styles.DebugText.Render(e.Msg)
	}
}

// renderLogEntry renderiza e con timestamp "[HH:MM:SS] ".
func renderLogEntry(e tuimodel.LogEntry, width int) string {
	const tsW = 11 // "[HH:MM:SS] " = 11 cols de display
	ts := styles.Dim.Render("[" + e.Ts.Format("15:04:05") + "] ")
	if width > 0 {
		maxW := width - tsW - 1
		if maxW > 1 {
			if trunc := TruncByWidth(e.Msg, maxW); trunc != e.Msg {
				e.Msg = TruncByWidth(e.Msg, maxW-1) + "…"
			}
		}
	}
	return ts + colorLogMsg(e)
}

// renderLogEntryNoTS renderiza e sin timestamp.
func renderLogEntryNoTS(e tuimodel.LogEntry) string { return colorLogMsg(e) }

// ── Fichas y fases ────────────────────────────────────────────────────────────

// phaseStatusOf calcula el estado agregado de una fase según sus fichas.
func phaseStatusOf(ph tuimodel.InstallPhase, fichas map[string]*tuimodel.FichaDetail) tuimodel.FichaStatus {
	anyActive, allDone, anyFailed, anyStarted := false, true, false, false
	for _, fid := range ph.Fichas {
		fd := fichas[fid]
		if fd == nil {
			allDone = false
			continue
		}
		switch fd.Status {
		case tuimodel.FichaActive:
			anyActive, anyStarted, allDone = true, true, false
		case tuimodel.FichaDone:
			anyStarted = true
		case tuimodel.FichaFailed:
			anyFailed, anyStarted, allDone = true, true, false
		case tuimodel.FichaPending:
			allDone = false
		}
	}
	switch {
	case anyFailed:
		return tuimodel.FichaFailed
	case anyActive:
		return tuimodel.FichaActive
	case allDone && anyStarted:
		return tuimodel.FichaDone
	}
	return tuimodel.FichaPending
}

func phaseIconStr(st tuimodel.FichaStatus) string {
	switch st {
	case tuimodel.FichaDone:
		return styles.Tint(styles.IconOK, styles.ColorStateOKFg)
	case tuimodel.FichaActive:
		return styles.Tint(styles.IconStepRun, styles.ColorStateWarnFg)
	case tuimodel.FichaFailed:
		return styles.Tint(styles.IconErr, styles.ColorStateErrFg)
	}
	return styles.Dim.Render(styles.IconCircleOpen)
}

func fichaIconStr(st tuimodel.FichaStatus) string { return phaseIconStr(st) }

// stepNameToDesc convierte snake_case a descripción legible. "instalar_kubeadm" → "Instalar kubeadm".
func stepNameToDesc(name string) string {
	if name == "" {
		return ""
	}
	words := strings.Split(name, "_")
	if len(words[0]) > 0 {
		words[0] = strings.ToUpper(words[0][:1]) + words[0][1:]
	}
	return strings.Join(words, " ")
}

// renderSubComp renderiza un step en el panel B (historial de fichas instaladas).
func renderSubComp(s tuimodel.StepDetail, width int) string {
	var icon string
	switch s.Status {
	case tuimodel.StepDone:
		icon = styles.StepOK.Render(styles.IconOK)
	case tuimodel.StepActive:
		icon = styles.StepActive.Render(styles.IconCursor)
	case tuimodel.StepFailed:
		icon = styles.StepFail.Render(styles.IconErr)
	case tuimodel.StepSkipped:
		icon = styles.Dim.Render("─")
	default:
		icon = styles.StepPending.Render(styles.IconCircleOpen)
	}

	name := util.TruncA(s.Name, width-12)
	var dur string
	switch s.Status {
	case tuimodel.StepDone, tuimodel.StepFailed:
		if fd := util.FormatDur(s.Duration); fd != "" {
			dur = styles.Dim.Render("  " + fd)
		}
	case tuimodel.StepActive:
		if !s.StartTime.IsZero() {
			if fd := util.FormatDur(time.Since(s.StartTime).Round(time.Second)); fd != "" {
				dur = styles.Dim.Render("  " + fd)
			}
		}
	}

	var lines []string
	switch s.Status {
	case tuimodel.StepDone:
		lines = append(lines, styles.StepOK.Render(icon+" "+name)+dur)
	case tuimodel.StepActive:
		lines = append(lines, styles.StepActive.Render(icon+" "+name)+dur)
		desc := s.Msg
		if desc == "" {
			desc = stepNameToDesc(s.Name)
		}
		if desc != "" {
			lines = append(lines, styles.Dim.Render("   └ "+util.TruncA(desc, width-6)))
		}
	case tuimodel.StepFailed:
		lines = append(lines, styles.StepFail.Render(icon+" "+name)+dur)
		if s.ErrMsg != "" {
			for _, l := range strings.Split(util.WordWrap(s.ErrMsg, width-6), "\n") {
				lines = append(lines, styles.Error.Render("   │ "+l))
			}
		}
	default:
		lines = append(lines, styles.Dim.Render(icon+" "+name))
	}
	return strings.Join(lines, "\n")
}

// renderStepRow renderiza un step en el panel de error S05C (compacto).
func renderStepRow(s tuimodel.StepDetail, width int) string {
	var icon string
	switch s.Status {
	case tuimodel.StepDone:
		icon = styles.StepOK.Render(styles.IconOK)
	case tuimodel.StepActive:
		icon = styles.StepActive.Render(styles.IconCursor)
	case tuimodel.StepFailed:
		icon = styles.StepFail.Render(styles.IconErr)
	case tuimodel.StepSkipped:
		icon = styles.Dim.Render("─")
	default:
		icon = styles.StepPending.Render(styles.IconCircleOpen)
	}
	name := util.TruncA(s.Name, width-14)
	var dur string
	if s.Status == tuimodel.StepDone || s.Status == tuimodel.StepFailed {
		if fd := util.FormatDur(s.Duration); fd != "" {
			dur = styles.Dim.Render(" " + fd)
		}
	} else if s.Status == tuimodel.StepActive && !s.StartTime.IsZero() {
		if fd := util.FormatDur(time.Since(s.StartTime).Round(time.Second)); fd != "" {
			dur = styles.Dim.Render(" " + fd)
		}
	}
	line := icon + " " + name + dur
	if s.Status == tuimodel.StepFailed && s.ErrMsg != "" {
		for _, l := range strings.Split(util.WordWrap(s.ErrMsg, width-4), "\n") {
			line += "\n" + styles.Error.Render("  │ "+l)
		}
	}
	return line
}

// activeFicha retorna la ficha activa o la más reciente (fallback).
func activeFicha(m tuimodel.Model) *tuimodel.FichaDetail {
	for _, ph := range m.Phases {
		for _, fid := range ph.Fichas {
			if fd := m.Fichas[fid]; fd != nil && fd.Status == tuimodel.FichaActive {
				return fd
			}
		}
	}
	for i := len(m.Phases) - 1; i >= 0; i-- {
		ph := m.Phases[i]
		for j := len(ph.Fichas) - 1; j >= 0; j-- {
			if fd := m.Fichas[ph.Fichas[j]]; fd != nil &&
				(fd.Status == tuimodel.FichaDone || fd.Status == tuimodel.FichaFailed) &&
				len(fd.Steps) > 0 {
				return fd
			}
		}
	}
	return nil
}

// fichaCountersOf cuenta fichas por estado recorriendo todas las fases.
func fichaCountersOf(m tuimodel.Model) (done, running, pending, errored int) {
	for _, ph := range m.Phases {
		for _, fid := range ph.Fichas {
			fd := m.Fichas[fid]
			if fd == nil {
				pending++
				continue
			}
			switch fd.Status {
			case tuimodel.FichaDone:
				done++
			case tuimodel.FichaActive:
				running++
			case tuimodel.FichaFailed:
				errored++
			default:
				pending++
			}
		}
	}
	return
}

// filteredLogs aplica filtros de nivel, source y búsqueda a m.Logs.
func filteredLogs(m tuimodel.Model) []tuimodel.LogEntry {
	var out []tuimodel.LogEntry
	for _, e := range m.Logs {
		if m.LogFilter != tuimodel.LogInfo && e.Level != m.LogFilter {
			continue
		}
		if m.LogSource != "" && !strings.EqualFold(e.Ficha, m.LogSource) {
			continue
		}
		if m.LogSearch != "" &&
			!strings.Contains(strings.ToLower(e.Msg), strings.ToLower(m.LogSearch)) &&
			!strings.Contains(strings.ToLower(e.Ficha), strings.ToLower(m.LogSearch)) {
			continue
		}
		out = append(out, e)
	}
	return out
}

// highlightMatch resalta la primera ocurrencia de needle en line.
func highlightMatch(line, needle string) string {
	if needle == "" {
		return line
	}
	idx := strings.Index(strings.ToLower(line), strings.ToLower(needle))
	if idx < 0 {
		return line
	}
	hi := styles.Success.Copy().Background(styles.ColorStateOKBg)
	return line[:idx] + hi.Render(line[idx:idx+len(needle)]) + line[idx+len(needle):]
}

// lastLogLines retorna las últimas n líneas del log formateadas.
func lastLogLines(m tuimodel.Model, n, width int) []string {
	start := 0
	if len(m.Logs) > n {
		start = len(m.Logs) - n
	}
	var lines []string
	for _, e := range m.Logs[start:] {
		lines = append(lines, renderLogEntry(e, width))
	}
	return lines
}

// safeWidth retorna max(m.Width, 4).
func safeWidth(m tuimodel.Model) int {
	if m.Width < 4 {
		return 4
	}
	return m.Width
}

// ── Builders de columnas — exportados para Update() ──────────────────────────

// BuildColA genera el contenido del viewport A: árbol de fases y fichas.
// Llamado desde Update() para refrescar m.VpA.SetContent(BuildColA(m, w)).
func BuildColA(m tuimodel.Model, w int) string {
	sTextDone := styles.Muted
	sTextActive := styles.AccentBold
	sTextPend := styles.Slate
	sTextErr := styles.RedText
	sTime := styles.Muted

	var sb strings.Builder
	sb.WriteString(styles.Muted.Render("Fases de instalación"))
	sb.WriteString("\n\n")

	for _, ph := range m.Phases {
		st := phaseStatusOf(ph, m.Fichas)
		icon := phaseIconStr(st)
		var phLine string
		switch st {
		case tuimodel.FichaDone:
			phLine = icon + " " + sTextDone.Render(ph.Nombre)
		case tuimodel.FichaActive:
			phLine = icon + " " + sTextActive.Render(ph.Nombre)
		case tuimodel.FichaFailed:
			phLine = icon + " " + sTextErr.Render(ph.Nombre)
		default:
			phLine = icon + " " + sTextPend.Render(ph.Nombre)
		}
		sb.WriteString(phLine)
		sb.WriteByte('\n')

		for _, fid := range ph.Fichas {
			fd := m.Fichas[fid]
			fname := util.TruncA(fid, w-8)
			if fd == nil {
				sb.WriteString("  " + fichaIconStr(tuimodel.FichaPending) + " " + sTextPend.Render(fname))
				sb.WriteByte('\n')
				continue
			}
			switch fd.Status {
			case tuimodel.FichaDone:
				dur := sTime.Render(" " + util.FormatDur(fd.Duration))
				sb.WriteString("  " + fichaIconStr(tuimodel.FichaDone) + " " + sTextDone.Render(fname) + dur)
			case tuimodel.FichaActive:
				sb.WriteString("  " + m.Spinner.View() + " " + sTextActive.Render(fname))
			case tuimodel.FichaFailed:
				sb.WriteString("  " + fichaIconStr(tuimodel.FichaFailed) + " " + sTextErr.Render(fname))
			default:
				sb.WriteString("  " + fichaIconStr(tuimodel.FichaPending) + " " + sTextPend.Render(fname))
			}
			sb.WriteByte('\n')
		}
		sb.WriteByte('\n')
	}
	return sb.String()
}

// BuildColB genera el contenido del viewport B: historial de fichas instaladas.
func BuildColB(m tuimodel.Model, w int) string {
	spin := m.Spinner.View()
	sHeader := styles.AccentBold
	sSubhdr := styles.Muted
	divider := styles.Rule.Render(strings.Repeat("─", w-2))

	var sb strings.Builder
	hasContent := false

	for _, ph := range m.Phases {
		for _, fid := range ph.Fichas {
			fd := m.Fichas[fid]
			if fd == nil || fd.Status == tuimodel.FichaPending {
				continue
			}
			if hasContent {
				sb.WriteString(divider)
				sb.WriteByte('\n')
			}
			hasContent = true

			v := util.FichaVersions[fd.ID]
			hdr := sHeader.Render(styles.Tint(styles.IconFicha, styles.ColorAccent) + " " + fd.ID)
			if v != "" {
				hdr += " " + styles.Dim.Render(v)
			}
			sb.WriteString(hdr)
			sb.WriteByte('\n')

			done := fd.CountDone()
			total := len(fd.Steps)
			switch fd.Status {
			case tuimodel.FichaActive:
				if total == 0 {
					sb.WriteString(spin + " " + sSubhdr.Render("iniciando…"))
				} else if as := fd.ActiveStep(); as != nil {
					el := util.FormatDur(time.Since(as.StartTime).Round(time.Second))
					sb.WriteString(spin + " " + sSubhdr.Render(fmt.Sprintf("%d/%d pasos · %s", done, total, el)))
				} else {
					sb.WriteString(spin + " " + sSubhdr.Render(fmt.Sprintf("%d/%d pasos", done, total)))
				}
			case tuimodel.FichaDone:
				sb.WriteString(fichaIconStr(tuimodel.FichaDone) + " " +
					sSubhdr.Render(fmt.Sprintf("%d/%d completados", done, total)))
			case tuimodel.FichaFailed:
				sb.WriteString(fichaIconStr(tuimodel.FichaFailed) + " " +
					styles.RedText.
						Render(fmt.Sprintf("falló en paso %d/%d", done, total)))
			}
			sb.WriteString("\n\n")

			for _, s := range fd.Steps {
				sb.WriteString(renderSubComp(s, w-2))
				sb.WriteByte('\n')
			}
		}
	}

	if !hasContent {
		return spin + " " + styles.Dim.Render("Esperando primera ficha…")
	}
	return sb.String()
}

// BuildColC genera el contenido del viewport C: log en vivo con colores.
func BuildColC(m tuimodel.Model, w int) string {
	spin := m.Spinner.View()
	var logLines []string
	for _, e := range m.Logs {
		if m.ShowTimestamp {
			logLines = append(logLines, renderLogEntry(e, w-2))
		} else {
			logLines = append(logLines, renderLogEntryNoTS(e))
		}
	}
	if len(logLines) == 0 {
		if afd := activeFicha(m); afd != nil && afd.Status == tuimodel.FichaActive {
			logLines = []string{spin + " " + styles.Dim.Render("ejecutando script, esperando output…")}
		} else {
			logLines = []string{styles.Dim.Render("Sin actividad aún…")}
		}
	}
	return strings.Join(logLines, "\n")
}

// ── Ensamblado sin centrado vertical ─────────────────────────────────────────

// renderInstallFull ensambla header + body + footer sin centrado vertical.
// La pantalla de instalación tiene viewports que llenan el espacio disponible.
func renderInstallFull(m tuimodel.Model, body string) string {
	header := RenderHeader(m)
	sep := styles.Dim.Render(strings.Repeat("─", m.Width))
	footer := RenderFooter(m)
	bottom := styles.JoinV(styles.PosLeft, sep, footer)
	return styles.JoinV(styles.PosLeft, header, body, bottom)
}

// ── Layouts responsivos ───────────────────────────────────────────────────────

func viewInstallingXS(m tuimodel.Model, progLine, statsLine string) string {
	var lines []string
	lines = append(lines, "\n"+progLine, statsLine, "")
	for _, ph := range m.Phases {
		st := phaseStatusOf(ph, m.Fichas)
		icon := phaseIconStr(st)
		line := icon + " " + ph.Nombre
		if st == tuimodel.FichaActive {
			lines = append(lines, line)
			for _, fid := range ph.Fichas {
				if fd := m.Fichas[fid]; fd != nil && fd.Status == tuimodel.FichaActive {
					lines = append(lines, "  "+styles.AccentBold.Render(styles.IconCursor+" "+fid))
					if as := fd.ActiveStep(); as != nil {
						lines = append(lines, "    "+styles.Dim.Render("↳ "+as.Name))
					}
				}
			}
		} else {
			lines = append(lines, styles.Dim.Render(line))
		}
	}
	return strings.Join(lines, "\n")
}

func viewInstallingSM(m tuimodel.Model, progLine, statsLine string) string {
	sw := safeWidth(m)
	var phLines []string
	for _, ph := range m.Phases {
		st := phaseStatusOf(ph, m.Fichas)
		icon := phaseIconStr(st)
		phLines = append(phLines, icon+" "+ph.Nombre)
		if st == tuimodel.FichaActive || st == tuimodel.FichaDone {
			for _, fid := range ph.Fichas {
				fd := m.Fichas[fid]
				if fd == nil || fd.Status == tuimodel.FichaPending {
					continue
				}
				dur := ""
				if fd.Status == tuimodel.FichaDone {
					dur = " " + styles.Dim.Render(util.FormatDur(fd.Duration))
				}
				phLines = append(phLines, "  "+fichaIconStr(fd.Status)+" "+fid+dur)
				if fd.Status == tuimodel.FichaActive {
					if as := fd.ActiveStep(); as != nil {
						el := time.Since(as.StartTime).Round(time.Second)
						phLines = append(phLines,
							"    "+styles.StepActive.Render(styles.IconCursor+" "+as.Name)+" "+styles.Dim.Render(util.FormatDur(el)))
					}
				}
			}
		}
	}
	phasesBlock := styles.Box.Width(sw).Render(strings.Join(phLines, "\n"))
	logEntries := lastLogLines(m, 6, sw-4)
	logBlock := styles.Box.Width(sw).Render(strings.Join(logEntries, "\n"))
	return "\n" + progLine + "\n" + statsLine + "\n\n" +
		styles.JoinV(styles.PosLeft, phasesBlock, logBlock)
}

func viewInstallingMD(m tuimodel.Model, progLine, statsLine string) string {
	if !m.VpReady {
		return progLine + "\n" + statsLine + "\n" + styles.Dim.Render("  Iniciando paneles…")
	}

	wA, wB, wC, vpH := tuimodel.VpDims(m.Width, m.Height)

	sColTitle := styles.TableHeader.Bold(true)
	sTitleDim := styles.Muted

	colTitle := func(i, totalLines, vpHeight int, scrollPct float64, label string) string {
		text := label
		if totalLines > vpHeight {
			text += fmt.Sprintf(" %d%%", int(scrollPct*100))
		}
		if m.InstallingFocus == i {
			return sColTitle.Render(text)
		}
		return sTitleDim.Render(text)
	}

	titleA := colTitle(0, m.VpA.TotalLineCount(), m.VpA.Height, m.VpA.ScrollPercent(), " Fases y Fichas")
	titleB := colTitle(1, m.VpB.TotalLineCount(), m.VpB.Height, m.VpB.ScrollPercent(), " Componentes instalados")
	titleCBase := colTitle(2, m.VpC.TotalLineCount(), m.VpC.Height, m.VpC.ScrollPercent(), " Log en vivo")
	titleC := titleCBase
	if m.VpAutoScroll {
		titleC += styles.Dim.Render(" auto")
	}
	if m.ShowTimestamp {
		titleC += styles.Dim.Render(" [T]")
	}

	borderNormal := styles.Box
	borderFocus := styles.BoxActive

	border := func(i int) styles.Style {
		if m.InstallingFocus == i {
			return borderFocus
		}
		return borderNormal
	}

	scrollA := tuimodel.VScrollbar(m.VpA, vpH)
	viewA := styles.JoinH(styles.PosTop, m.VpA.View(), scrollA)
	panelA := border(0).Width(wA).Render(titleA + "\n" + viewA)

	colBContent := m.VpB.View()
	if m.WsConn == nil && !m.Config.DemoMode && m.FichasOK == 0 {
		colBContent = styles.Warning.Render("  ⚠  Daemon bos no conectado") + "\n\n" +
			styles.Dim.Render("  Verifique:\n\n    systemctl status bos\n    systemctl start bos")
	}
	scrollB := tuimodel.VScrollbar(m.VpB, vpH)
	viewB := styles.JoinH(styles.PosTop, colBContent, scrollB)
	panelB := border(1).Width(wB).Render(titleB + "\n" + viewB)

	scrollC := tuimodel.VScrollbar(m.VpC, vpH)
	viewC := styles.JoinH(styles.PosTop, m.VpC.View(), scrollC)
	panelC := border(2).Width(wC).Render(titleC + "\n" + viewC)

	cols := styles.JoinH(styles.PosTop, panelA, panelB, panelC)
	return progLine + "\n" + statsLine + "\n" + cols
}

func viewInstallingNormal(m tuimodel.Model) string {
	elapsed := time.Since(m.StartTime).Round(time.Second)
	pct := 0
	if m.FichasTotal > 0 {
		pct = m.FichasOK * 100 / m.FichasTotal
		if pct > 100 {
			pct = 100
		}
	}

	done, running, pending, errored := fichaCountersOf(m)
	progLine := m.ProgBar.View() + styles.Dim.Render(fmt.Sprintf("  %d%%  ·  %d/%d fichas  ·  %s",
		pct, m.FichasOK, m.FichasTotal, elapsed))
	statsLine := fmt.Sprintf("  %s %d completadas   %s %d en curso   %s %d pendientes   %s %d error",
		fichaIconStr(tuimodel.FichaDone), done,
		m.Spinner.View(), running,
		styles.Tint(styles.IconCircleOpen, styles.ColorTextDisabled), pending,
		fichaIconStr(tuimodel.FichaFailed), errored,
	)

	switch styles.Mode(m.Width) {
	case "xs":
		return viewInstallingXS(m, progLine, statsLine)
	case "sm":
		return viewInstallingSM(m, progLine, statsLine)
	default:
		return viewInstallingMD(m, progLine, statsLine)
	}
}

// ── Función pública ───────────────────────────────────────────────────────────

// RenderInstalling renderiza S05: pantalla principal durante la instalación.
// Despacha a RenderInstallLog o RenderInstallErr según m.ViewMode/CurrentScreen.
func RenderInstalling(m tuimodel.Model) string {
	switch {
	case m.CurrentScreen == tuimodel.ScreenInstallLog, m.ViewMode == "fulllog":
		return RenderInstallLog(m)
	case m.CurrentScreen == tuimodel.ScreenInstallErr, m.ViewMode == "error":
		return RenderInstallErr(m)
	}
	return renderInstallFull(m, viewInstallingNormal(m))
}
