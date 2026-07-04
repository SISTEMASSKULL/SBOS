package panel

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// PAMRBAC renderiza la vista PAM / RBAC.
func PAMRBAC(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"PAM/Sudoers", "K8s RBAC", "Impersonation", "Audit Log"}
	tabIdx := dm.SubTab["pam"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	switch tabIdx {
	case 0: // PAM
		lines = append(lines, dash.SectionHeader("PAM — USUARIOS Y PERMISOS SUDO"), "")
		userW := 14
		grpW := w * 24 / 100
		sudoW := 12
		lastW := 10
		stW := w - userW - grpW - sudoW - lastW
		if stW < 8 {
			stW = 8
		}
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(userW).Render("USUARIO"),
				styles.TableHeader.Width(grpW).Render("GRUPOS"),
				styles.TableHeader.Width(sudoW).Render("SUDO"),
				styles.TableHeader.Width(lastW).Render("ULTIMO"),
				styles.TableHeader.Render("ESTADO"),
			),
			dash.ColSep(w),
		)
		for _, u := range dm.PAMUsers {
			stColor := styles.StatusOK
			if u.Status == "Root" {
				stColor = styles.StatusWarn
			} else if u.Status == "Daemon" {
				stColor = styles.Info
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(userW).Render(dash.Truncate(u.Name, userW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", grpW, dash.Truncate(u.Groups, grpW-1))),
				styles.Dim.Render(fmt.Sprintf("%-*s", sudoW, dash.Truncate(u.SudoRule, sudoW-1))),
				styles.Dim.Render(fmt.Sprintf("%-*s", lastW, u.LastSudo)),
				stColor.Render(u.Status),
			))
		}
	case 1: // K8s RBAC
		lines = append(lines, dash.SectionHeader("K8s RBAC — ROLES Y BINDINGS"), "")
		subjW := w * 18 / 100
		typeW := 16
		roleW := w * 26 / 100
		nsW := 12
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(subjW).Render("SUJETO"),
				styles.TableHeader.Width(typeW).Render("TIPO"),
				styles.TableHeader.Width(roleW).Render("ROL / CLUSTER ROL"),
				styles.TableHeader.Width(nsW).Render("NAMESPACE"),
				styles.TableHeader.Render("ST"),
			),
			dash.ColSep(w),
		)
		for _, rb := range dm.K8sRoleBindings {
			st := styles.Tint(styles.IconOK, styles.ColorStateOKFg)
			if !rb.Active {
				st = styles.Tint(styles.IconErr, styles.ColorStateErrFg)
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(subjW).Render(dash.Truncate(rb.Subject, subjW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", typeW, rb.SubjectType)),
				styles.AccentBold.Width(roleW).Render(dash.Truncate(rb.Role, roleW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", nsW, rb.Namespace)),
				st,
			))
		}
	case 2: // Impersonation
		lines = append(lines, dash.SectionHeader("IMPERSONATION — BOS PROXY (ADR-003)"), "")
		timeW := 10
		userW := 14
		opW := w - timeW - userW - 8
		if opW < 20 {
			opW = 20
		}
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(timeW).Render("HORA"),
				styles.TableHeader.Width(userW).Render("USUARIO"),
				styles.TableHeader.Width(opW).Render("OPERACION"),
				styles.TableHeader.Render("RESULTADO"),
			),
			dash.ColSep(w),
		)
		for _, ev := range dm.ImpersonEvents {
			res := styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " OK    "
			if !ev.Result {
				res = styles.Tint(styles.IconErr, styles.ColorStateErrFg) + " DENIED"
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.Dim.Render(fmt.Sprintf("%-*s", timeW, ev.EventTime)),
				styles.White.Width(userW).Render(dash.Truncate(ev.AsUser, userW-1)),
				styles.Dim.Width(opW).Render(dash.Truncate(ev.Operation, opW-1)),
				res,
			))
		}
	default: // Audit Log
		lines = append(lines,
			dash.SectionHeader("AUDIT LOG — ACCESOS Y OPERACIONES"), "",
			styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  10:32:14  skull         ssh login from 192.168.1.100",
			styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  10:31:50  skull         kubectl get pods — OK",
			styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  10:28:30  skull         kubectl scale deploy nginx — OK",
			styles.Tint(styles.IconErr, styles.ColorStateErrFg)+"  10:25:11  deploy        kubectl delete pod — DENIED",
			styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  10:20:05  skull         sudo systemctl restart sshd — OK",
			styles.Tint(styles.IconErr, styles.ColorStateErrFg)+"  10:15:00  deploy        kubectl get secrets — DENIED",
			styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  10:00:00  svc-bos       daemon heartbeat — OK",
			styles.Tint(styles.IconWarn, styles.ColorStateWarnFg)+"  09:55:00  vps-pruebas   sudo attempt — passwd required",
		)
	}
	return strings.Join(lines, "\n")
}
