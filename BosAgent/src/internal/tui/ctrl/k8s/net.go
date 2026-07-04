package k8s

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Network renderiza la vista K8s — Network.
func Network(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"Services", "Ingress", "NetPolicies", "Endpoints"}
	tabIdx := dm.SubTab["k8s-net"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	switch tabIdx {
	case 0: // Services
		lines = append(lines, dash.SectionHeader("K8s SERVICES"), "")
		cols := dash.ColWidths(w, []int{22, 16, 14, 16, 25, 7})
		nameW, nsW, typeW, ipW, portW, _ :=
			cols[0], cols[1], cols[2], cols[3], cols[4], cols[5]
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nameW).Render("NOMBRE"),
				styles.TableHeader.Width(nsW).Render("NAMESPACE"),
				styles.TableHeader.Width(typeW).Render("TIPO"),
				styles.TableHeader.Width(ipW).Render("CLUSTER-IP"),
				styles.TableHeader.Width(portW).Render("PUERTO"),
				styles.TableHeader.Render("AGE"),
			),
			dash.ColSep(w),
		)
		for _, s := range dm.K8sServices {
			typeColor := styles.Dim
			if s.SvcType == "LoadBalancer" {
				typeColor = styles.AccentBold
			} else if s.SvcType == "NodePort" {
				typeColor = styles.StatusWarn
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nameW).Render(dash.Truncate(s.Name, nameW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", nsW, dash.Truncate(s.Namespace, nsW-1))),
				typeColor.Render(fmt.Sprintf("%-*s", typeW, s.SvcType)),
				styles.AccentBold.Width(ipW).Render(s.ClusterIP),
				styles.Dim.Render(fmt.Sprintf("%-*s", portW, dash.Truncate(s.Port, portW-1))),
				styles.Dim.Render(s.Age),
			))
		}
	case 1: // Ingress
		lines = append(lines, dash.SectionHeader("INGRESS"), "")
		cols := dash.ColWidths(w, []int{18, 13, 23, 9, 29, 8})
		nameW, nsW, hostW, pathW, backW, _ :=
			cols[0], cols[1], cols[2], cols[3], cols[4], cols[5]
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nameW).Render("NOMBRE"),
				styles.TableHeader.Width(nsW).Render("NS"),
				styles.TableHeader.Width(hostW).Render("HOST"),
				styles.TableHeader.Width(pathW).Render("PATH"),
				styles.TableHeader.Width(backW).Render("BACKEND"),
				styles.TableHeader.Render("TLS/AGE"),
			),
			dash.ColSep(w),
		)
		for _, ing := range dm.Ingresses {
			tls := styles.Dim.Render("—")
			if ing.TLS {
				tls = styles.Tint(styles.IconOK, styles.ColorStateOKFg) + " TLS"
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nameW).Render(dash.Truncate(ing.Name, nameW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", nsW, dash.Truncate(ing.Namespace, nsW-1))),
				styles.Cyan.Width(hostW).Render(dash.Truncate(ing.Host, hostW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", pathW, ing.Path)),
				styles.Dim.Width(backW).Render(dash.Truncate(ing.Backend, backW-1)),
				tls,
			))
		}
	case 2: // NetworkPolicies
		lines = append(lines, dash.SectionHeader("NETWORK POLICIES"), "")
		cols := dash.ColWidths(w, []int{22, 16, 46, 8, 8})
		nameW, nsW, selW, ingW, egW :=
			cols[0], cols[1], cols[2], cols[3], cols[4]
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nameW).Render("NOMBRE"),
				styles.TableHeader.Width(nsW).Render("NAMESPACE"),
				styles.TableHeader.Width(selW).Render("POD SELECTOR"),
				styles.TableHeader.Width(ingW).Render("INGRESS"),
				styles.TableHeader.Width(egW).Render("EGRESS"),
			),
			dash.ColSep(w),
		)
		for _, np := range dm.NetPolicies {
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(nameW).Render(dash.Truncate(np.Name, nameW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", nsW, dash.Truncate(np.Namespace, nsW-1))),
				styles.Dim.Width(selW).Render(dash.Truncate(np.PodSelector, selW-1)),
				styles.AccentBold.Width(ingW).Render(fmt.Sprintf("%d rules", np.IngressRules)),
				styles.AccentBold.Width(egW).Render(fmt.Sprintf("%d rules", np.EgressRules)),
			))
		}
	default: // Endpoints
		lines = append(lines, dash.SectionHeader("ENDPOINTS"), "")
		cols := dash.ColWidths(w, []int{30, 18, 52})
		nameW, nsW, _ := cols[0], cols[1], cols[2]
		for _, s := range dm.K8sServices {
			lines = append(lines, fmt.Sprintf("  %-*s  %-*s  %s",
				nameW, s.Name, nsW, s.Namespace, styles.Dim.Render(s.ClusterIP+":"+s.Port)))
		}
	}
	return strings.Join(lines, "\n")
}
