// Package screens — s07_reboot.go: countdown de reinicio con barra de progreso (S07).
// m.CountdownSec va de 10 a 0; los logs progresivos aparecen según el contador baja.
package screens

import (
	"fmt"
	"strings"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
)

// RenderReboot renderiza S07: countdown de reinicio con barra de progreso.
func RenderReboot(m tuimodel.Model) string {
	return assembleScreen(m, buildRebootBody(m))
}

func buildRebootBody(m tuimodel.Model) string {
	w := m.Width
	if w == 0 {
		w = 80
	}

	cntStr := styles.AccentBold.Width(w).Align(styles.PosCenter).
		Render(fmt.Sprintf("\n\n  %s  Reiniciando en  %d  segundos\n\n", styles.Tint(styles.IconRestart, styles.ColorStateWarnFg), m.CountdownSec))

	barW := w - 20
	if barW < 20 {
		barW = 20
	}
	filled := int(float64(barW) * float64(10-m.CountdownSec) / 10.0)
	if filled < 0 {
		filled = 0
	}
	if filled > barW {
		filled = barW
	}
	bar := styles.ProgressFill.Width(w).Align(styles.PosCenter).
		Render("[" + strings.Repeat("█", filled) + strings.Repeat("░", barW-filled) + "]")

	// Logs progresivos: aparecen según el countdown actual
	logPad := styles.Muted.PaddingLeft(4)
	var logs []string
	cs := m.CountdownSec
	if cs <= 9 {
		logs = append(logs, styles.Tint(styles.IconOK, styles.ColorStateOKFg)+" Guardando configuración en /etc/sbos/tenant.conf")
	}
	if cs <= 8 {
		logs = append(logs, styles.Tint(styles.IconOK, styles.ColorStateOKFg)+" Escribiendo /etc/systemd/system/bos.service")
	}
	if cs <= 7 {
		logs = append(logs, styles.Tint(styles.IconOK, styles.ColorStateOKFg)+" Habilitando bos.service — levanta después de k8s.target")
	}
	if cs <= 6 {
		logs = append(logs, styles.Dim.Render("  Registrando ctx_id de instalación"))
	}
	if cs <= 5 {
		logs = append(logs, styles.Tint(styles.IconOK, styles.ColorStateOKFg)+" Log guardado en /var/log/sbos/install.log")
	}
	if cs <= 4 {
		logs = append(logs, styles.Dim.Render("  Sincronizando filesystem..."))
	}
	if cs <= 2 {
		logs = append(logs, styles.Tint(styles.IconOK, styles.ColorStateOKFg)+" Sistema listo para reinicio")
	}
	if cs <= 1 {
		logs = append(logs, styles.Dim.Render("  systemctl reboot — iniciando secuencia..."))
	}
	logsBlock := logPad.Render(strings.Join(logs, "\n"))

	hint := styles.Dim.Width(w).Align(styles.PosCenter).
		Render("\n  [Enter] reiniciar ahora  [Esc] cancelar")

	return styles.JoinV(styles.PosLeft, cntStr, bar, "\n", logsBlock, hint)
}
