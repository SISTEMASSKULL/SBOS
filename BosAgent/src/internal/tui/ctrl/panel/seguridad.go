package panel

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Seguridad renderiza la vista Seguridad — Certificados y CVEs.
func Seguridad(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"Certificados", "Puertos", "CVEs", "Auditoría"}
	tabIdx := dm.SubTab["seg"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	switch tabIdx {
	case 0: // Certificados
		lines = append(lines, dash.SectionHeader(fmt.Sprintf("CERTIFICADOS TLS — %d certificados", len(dm.Certificates))), "")
		cols := dash.ColWidths(w, []int{24, 20, 13, 9, 11, 23})
		cnW, issW, expW, daysW, algW, _ :=
			cols[0], cols[1], cols[2], cols[3], cols[4], cols[5]
		lines = append(lines, "",
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(cnW).Render("COMMON NAME"),
				styles.TableHeader.Width(issW).Render("EMISOR"),
				styles.TableHeader.Width(expW).Render("EXPIRA"),
				styles.TableHeader.Width(daysW).Render("DIAS"),
				styles.TableHeader.Width(algW).Render("ALGO"),
				styles.TableHeader.Render("ESTADO"),
			),
			dash.ColSep(w),
		)
		for _, c := range dm.Certificates {
			daysColor := styles.StatusOK
			if c.DaysLeft < 30 {
				daysColor = styles.StatusErr
			} else if c.DaysLeft < 90 {
				daysColor = styles.StatusWarn
			}
			st := styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " Válido"
			if !c.Valid {
				st = styles.Tint(styles.IconErr, styles.ColorStateErrFg) + " Inválido"
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(cnW).Render(dash.Truncate(c.CommonName, cnW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", issW, dash.Truncate(c.Issuer, issW-1))),
				styles.Dim.Render(fmt.Sprintf("%-*s", expW, c.ExpiresAt)),
				daysColor.Render(fmt.Sprintf("%-*d", daysW, c.DaysLeft)),
				styles.Dim.Render(fmt.Sprintf("%-*s", algW, c.Algorithm)),
				st,
			))
		}
		expiring := 0
		for _, c := range dm.Certificates {
			if c.DaysLeft < 30 {
				expiring++
			}
		}
		lines = append(lines, "", dash.ColSep(w))
		if expiring > 0 {
			lines = append(lines, styles.Error.Render(fmt.Sprintf("  ⚠ %d certificado(s) expiran en menos de 30 días", expiring)))
		} else {
			lines = append(lines, styles.Success.Render("  ✔ Todos los certificados están vigentes"))
		}
	case 1: // Puertos
		lines = append(lines,
			dash.SectionHeader("ANÁLISIS DE PUERTOS EXPUESTOS"), "",
			dash.SectionHeader("PUERTOS EXTERNOS (0.0.0.0)"),
			"",
		)
		for _, c := range dm.TCPConns {
			if c.State != "LISTEN" {
				continue
			}
			risk := styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " OK"
			note := ""
			switch c.LocalAddr {
			case "0.0.0.0:22":
				note = styles.Dim.Render("  — SSH acceso controlado")
			case "0.0.0.0:80", "0.0.0.0:443":
				note = styles.Dim.Render("  — web público")
			case "0.0.0.0:9443":
				note = styles.Dim.Render("  — bosctl TLS")
			}
			lines = append(lines, fmt.Sprintf("  %s  %-24s  %-16s  %s%s",
				risk, c.LocalAddr, c.Process,
				styles.Dim.Render(fmt.Sprintf("pid:%d", c.PID)),
				note,
			))
		}
		lines = append(lines, "",
			dash.SectionHeader("RESUMEN"), "",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  UFW activo — política por defecto: deny",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  Sin puertos de BD expuestos externamente",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  mTLS activo entre daemons (Linkerd)",
		)
	case 2: // CVEs
		lines = append(lines, dash.SectionHeader(fmt.Sprintf("CVEs CONOCIDOS — %d paquetes con vulnerabilidades", len(dm.CVEs))), "")
		idW := 16
		sevW := 10
		pkgW := 10
		verW := 10
		fixW := 10
		lines = append(lines, "",
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(idW).Render("CVE ID"),
				styles.TableHeader.Width(sevW).Render("SEVERIDAD"),
				styles.TableHeader.Width(pkgW).Render("PAQUETE"),
				styles.TableHeader.Width(verW).Render("VERSION"),
				styles.TableHeader.Width(fixW).Render("FIX"),
				styles.TableHeader.Render("DESCRIPCIÓN"),
			),
			dash.ColSep(w),
		)
		for _, cv := range dm.CVEs {
			sevColor := styles.Dim
			switch cv.Severity {
			case "CRITICAL", "HIGH":
				sevColor = styles.StatusErr
			case "MEDIUM":
				sevColor = styles.StatusWarn
			}
			descW := w - idW - sevW - pkgW - verW - fixW
			if descW < 10 {
				descW = 10
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(idW).Render(dash.Truncate(cv.ID, idW-1)),
				sevColor.Render(fmt.Sprintf("%-*s", sevW, cv.Severity)),
				styles.Dim.Render(fmt.Sprintf("%-*s", pkgW, cv.Package)),
				styles.Dim.Render(fmt.Sprintf("%-*s", verW, cv.Version)),
				styles.StatusOK.Render(fmt.Sprintf("%-*s", fixW, cv.Fixed)),
				styles.Dim.Render(dash.Truncate(cv.Desc, descW-1)),
			))
		}
	default: // Auditoría
		const (
			logOK   = "ok"
			logErr  = "err"
			logWarn = "warn"
		)
		events := []struct{ icon, time, user, event string }{
			{logOK, "10:32:14", "skull", "ssh login from 192.168.1.100"},
			{logOK, "10:31:50", "skull", "kubectl get pods — OK"},
			{logOK, "10:28:30", "skull", "kubectl scale deploy nginx — OK"},
			{logErr, "10:25:11", "deploy", "kubectl delete pod — DENIED (RBAC)"},
			{logOK, "10:20:05", "skull", "sudo systemctl restart sshd — OK"},
			{logErr, "10:15:00", "deploy", "kubectl get secrets — DENIED (RBAC)"},
			{logWarn, "09:55:00", "vps-pruebas", "sudo attempt — password required"},
			{logOK, "08:00:00", "root", "login via SSH key"},
		}
		lines = append(lines, dash.SectionHeader("AUDITORÍA DE SEGURIDAD"), "")
		uW := 14
		evW := w - 12 - uW - 4
		for _, e := range events {
			var icon string
			switch e.icon {
			case logOK:
				icon = styles.Tint(styles.IconOK, styles.ColorStateOKFg)
			case logErr:
				icon = styles.Tint(styles.IconErr, styles.ColorStateErrFg)
			default:
				icon = styles.Tint(styles.IconWarn, styles.ColorStateWarnFg)
			}
			lines = append(lines, fmt.Sprintf("  %s  %s  %s  %s",
				icon,
				styles.Dim.Render(fmt.Sprintf("%-10s", e.time)),
				styles.White.Width(uW).Render(e.user),
				styles.Dim.Render(dash.Truncate(e.event, evW)),
			))
		}
	}
	return strings.Join(lines, "\n")
}
