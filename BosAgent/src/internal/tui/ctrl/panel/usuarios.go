package panel

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Usuarios renderiza la vista de sesiones de usuario.
func Usuarios(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"Activos", "Last Login", "Grupos"}
	tabIdx := dm.SubTab["users"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	switch tabIdx {
	case 0: // Sesiones activas
		lines = append(lines, dash.SectionHeader(fmt.Sprintf("SESIONES ACTIVAS — %d usuarios", len(dm.UserSessions))), "")
		cols := dash.ColWidths(w, []int{14, 10, 24, 12, 10, 30})
		userW, ttyW, fromW, loginW, idleW, whatW :=
			cols[0], cols[1], cols[2], cols[3], cols[4], cols[5]
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(userW).Render("USUARIO"),
				styles.TableHeader.Width(ttyW).Render("TTY"),
				styles.TableHeader.Width(fromW).Render("ORIGEN"),
				styles.TableHeader.Width(loginW).Render("LOGIN"),
				styles.TableHeader.Width(idleW).Render("IDLE"),
				styles.TableHeader.Render("PROCESO"),
			),
			dash.ColSep(w),
		)
		for _, s := range dm.UserSessions {
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(userW).Render(dash.Truncate(s.User, userW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", ttyW, s.TTY)),
				styles.AccentBold.Width(fromW).Render(dash.Truncate(s.From, fromW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", loginW, s.LoginAt)),
				styles.Dim.Render(fmt.Sprintf("%-*s", idleW, s.Idle)),
				styles.TableHeader.Render(dash.Truncate(s.What, whatW)),
			))
		}
	case 1: // Last login
		lines = append(lines,
			dash.SectionHeader("ULTIMOS LOGINS (last)"), "",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  skull      pts/0    192.168.1.100   Thu Jun 12 10:31   still logged in",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  skull      pts/1    192.168.1.100   Thu Jun 12 09:45   still logged in",
			"  "+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+"  deploy     pts/2    10.0.0.5        Thu Jun 12 08:00   still logged in",
			"  "+styles.Tint(styles.IconDotDim, styles.ColorTextDisabled)+"  skull      pts/0    192.168.1.100   Wed Jun 11 22:14   23:58",
			"  "+styles.Tint(styles.IconDotDim, styles.ColorTextDisabled)+"  skull      pts/1    192.168.1.100   Wed Jun 11 18:02   04:13",
			"  "+styles.Tint(styles.IconDotDim, styles.ColorTextDisabled)+"  root       pts/0    13.140.128.230  Wed Jun 11 07:55   02:31",
			"",
			dash.SectionHeader("INTENTOS FALLIDOS (lastb)"),
			"",
			"  "+styles.Dim.Render("Sin intentos fallidos recientes"),
		)
	default: // Grupos
		lines = append(lines, dash.SectionHeader("GRUPOS DEL SISTEMA"), "")
		groups := []struct{ name, members string }{
			{"sudo", "skull, vps-pruebas"},
			{"docker", "skull, svc-bos"},
			{"k8s", "skull, deploy, svc-bos"},
			{"bos", "svc-bos, bos-agent"},
			{"deploy", "deploy"},
			{"www-data", "nginx"},
			{"postgres", "postgres"},
			{"redis", "redis"},
			{"root", "root"},
		}
		gcols := dash.ColWidths(w-4, []int{24, 76})
		nW, mW := gcols[0], gcols[1]
		lines = append(lines, "")
		for _, g := range groups {
			lines = append(lines, fmt.Sprintf("  %s  %s",
				styles.White.Width(nW).Render(g.name),
				styles.Dim.Render(dash.Truncate(g.members, mW)),
			))
		}
	}
	return strings.Join(lines, "\n")
}
