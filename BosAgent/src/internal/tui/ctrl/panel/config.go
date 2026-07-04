package panel

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"

)

// Config renderiza la vista Configuración BosAgent.
func Config(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"General", "K8s", "Daemons", "Alertas"}
	tabIdx := dm.SubTab["config"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	kw := 22

	switch tabIdx {
	case 0: // General
		lines = append(lines, dash.SectionHeader("CONFIGURACION BOS AGENT"), "")
		cfg := dm.BosConf
		rows := [][2]string{
			{"Version", cfg.Version},
			{"Socket", cfg.Socket},
			{"StateFile", cfg.StateFile},
			{"LogLevel", cfg.LogLevel},
			{"ReconcileInterval", fmt.Sprintf("%ds", cfg.ReconcileS)},
			{"MaxRetries", fmt.Sprintf("%d", cfg.MaxRetries)},
			{"Entorno activo", cfg.Env},
		}
		lines = append(lines, "")
		for _, r := range rows {
			lines = append(lines, fmt.Sprintf("  %s  %s",
				styles.Dim.Render(fmt.Sprintf("%-*s", kw, r[0])),
				styles.TableHeader.Render(r[1]),
			))
		}
		lines = append(lines, "",
			dash.ColSep(w),
			"  "+styles.Dim.Render("Binario:  ")+styles.TableHeader.Render("/usr/local/bin/bosctl"),
			"  "+styles.Dim.Render("Servicio: ")+styles.StatusOK.Render("bos.service  ")+styles.Tint(styles.IconOK, styles.ColorStateOKFg)+styles.StatusOK.Render(" activo"),
			"  "+styles.Dim.Render("PID:      ")+styles.TableHeader.Render("2100"),
		)
	case 1: // K8s
		lines = append(lines, dash.SectionHeader("CONFIGURACION KUBERNETES"), "")
		cfg := dm.BosConf
		lines = append(lines, "")
		for _, r := range [][2]string{
			{"K8s Context", cfg.K8sContext},
			{"Namespace", cfg.Namespace},
			{"API Server", "https://127.0.0.1:6443"},
			{"Kubeconfig", "/var/lib/bos/.kube/config"},
			{"Auth mode", "ServiceAccount (bos-daemon-impersonator)"},
			{"Calico CNI", "v3.32.0"},
			{"Linkerd mTLS", "enabled"},
		} {
			lines = append(lines, fmt.Sprintf("  %s  %s",
				styles.Dim.Render(fmt.Sprintf("%-*s", kw, r[0])),
				styles.TableHeader.Render(r[1]),
			))
		}
	case 2: // Daemons
		lines = append(lines, dash.SectionHeader("ESTADO DE DAEMONS SBOS"), "")
		daemons := []struct {
			name, socket, status string
			ok                   bool
		}{
			{"bos", "/run/bos/bos.sock", "activo  v2.0.0-dev", true},
			{"biedata", "/run/bos/biedata.sock", "no instalado", false},
			{"bkernel", "/run/bos/bkernel.sock", "no instalado", false},
			{"bauth", "/run/bos/bauth.sock", "no instalado", false},
			{"bsearch", "/run/bos/bsearch.sock", "no instalado", false},
			{"bhnexus", "/run/bos/bhnexus.sock", "no instalado", false},
		}
		lines = append(lines, "")
		nW := 12
		sW := w - nW - 36
		if sW < 20 {
			sW = 20
		}
		for _, d := range daemons {
			st := styles.Tint(styles.IconDotDim, styles.ColorTextDisabled) + styles.Dim.Render(" "+d.status)
			if d.ok {
				st = styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.StatusOK.Render(" "+d.status)
			}
			lines = append(lines, fmt.Sprintf("  %s  %s  %s",
				styles.White.Width(nW).Render(d.name),
				styles.Dim.Render(fmt.Sprintf("%-*s", sW, dash.Truncate(d.socket, sW-1))),
				st,
			))
		}
	default: // Alertas
		lines = append(lines, dash.SectionHeader("REGLAS DE ALERTAS"), "")
		rules := []struct {
			name, cond, sev string
		}{
			{"PodCrashLoop", "restarts > 5", "CRITICA"},
			{"NodeHighCPU", "cpu > 85%", "WARNING"},
			{"HPAAtMax", "replicas = maxReplicas", "WARNING"},
			{"DiskHigh", "uso > 85%", "WARNING"},
			{"EtcdDBLarge", "DB > 6GB", "WARNING"},
			{"NoPodSchedulable", "pending > 0 (5min)", "CRITICA"},
		}
		lines = append(lines, "")
		for _, r := range rules {
			sev := styles.Tint(styles.IconWarn, styles.ColorStateWarnFg) + styles.Warning.Render(" "+r.sev)
			if r.sev == "CRITICA" {
				sev = styles.Tint(styles.IconErr, styles.ColorStateErrFg) + styles.Error.Render(" "+r.sev)
			}
			lines = append(lines, fmt.Sprintf("  %-28s  %-24s  %s",
				styles.TableHeader.Render(r.name),
				styles.Dim.Render(r.cond),
				sev,
			))
		}
	}
	return strings.Join(lines, "\n")
}
