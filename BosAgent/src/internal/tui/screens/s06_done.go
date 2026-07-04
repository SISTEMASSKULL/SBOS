// Package screens — s06_done.go: instalación completada con 4 secciones en tabs (S06).
// RenderInstallDone muestra Tenant, Ubuntu, Kubernetes y SBOS con resumen detallado.
package screens

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"
)

// RenderInstallDone renderiza S06: instalación completada con 4 secciones en tabs.
func RenderInstallDone(m tuimodel.Model) string {
	return assembleScreen(m, buildInstallDoneBody(m))
}

func buildInstallDoneBody(m tuimodel.Model) string {
	return renderCompleteTabs(m) + "\n\n" + buildCompleteSection(m)
}

// renderCompleteTabs renderiza la barra de tabs: Tenant · Ubuntu · Kubernetes · SBOS/bos.
func renderCompleteTabs(m tuimodel.Model) string {
	tabs := []string{"Tenant", "Ubuntu", "Kubernetes", "SBOS / bos"}
	var parts []string
	for i, t := range tabs {
		if i == m.CompleteFocus {
			parts = append(parts, styles.MenuItemActive.Padding(0, 1).Render(styles.IconCursor+" "+t))
		} else {
			parts = append(parts, styles.Inactive.Padding(0, 1).Render(t))
		}
	}
	return styles.JoinH(styles.PosTop, parts...)
}

// buildCompleteSection renderiza el cuerpo de la sección activa (m.CompleteFocus).
func buildCompleteSection(m tuimodel.Model) string {
	mode := styles.Mode(m.Width)
	dom := m.TenantValue("BOS_TENANT_DOMAIN")
	email := m.AdminValue("BOS_ROOT_USER")
	elapsed := time.Since(m.StartTime).Round(time.Second)
	cta := "\n" + styles.Muted.Render("  [ Enter ] Continuar   [ ←→ ] Cambiar sección")

	sideW := 28
	if mode == "xs" || mode == "sm" {
		sideW = 0
	}
	mainW := m.Width - sideW - 2
	if sideW == 0 {
		mainW = m.Width
	}
	_ = mainW

	buildCols := func(mainLines, sideLines []string) string {
		main := strings.Join(mainLines, "\n")
		if sideW == 0 {
			return main + cta
		}
		side := styles.Box.Width(sideW).Render(strings.Join(sideLines, "\n"))
		return styles.JoinH(styles.PosTop,
			styles.Cell(mainW, main), side,
		) + cta
	}

	switch m.CompleteFocus {
	// ── Tenant ────────────────────────────────────────────────────────────────
	case 0:
		var cntDone, cntFailed int
		for _, f := range m.Fichas {
			switch f.Status {
			case tuimodel.FichaDone:
				cntDone++
			case tuimodel.FichaFailed:
				cntFailed++
			}
		}
		main := []string{
			styles.AccentBold.Render(styles.IconOK + " SBOS instalado — " + dom),
			"",
			summaryRow("Email", email),
			summaryRow("Duración", elapsed.String()),
			summaryRow("Fichas", fmt.Sprintf("%d/%d", m.FichasOK, m.FichasTotal)),
			"",
			styles.DimItalic.Render("Acceso"),
			"",
			styles.Dim.Render("Panel:    ") + styles.Cyan.Render("https://"+dom),
			styles.Dim.Render("Grafana:  ") + styles.Cyan.Render("https://"+dom+"/monitor"),
			styles.Dim.Render("IAM:      ") + styles.Cyan.Render("https://"+dom+"/auth"),
			"",
			styles.DimItalic.Render("Próximos pasos"),
			"",
			styles.Dim.Render("• Configure impuestos en SmartTax"),
			styles.Dim.Render("• Agregue empleados en OrangeHRM"),
			styles.Dim.Render("• Active backup automático en MinIO"),
			styles.Dim.Render("• Configure SPIs de autenticación en Keycloak"),
		}
		side := []string{
			styles.DimItalic.Render("Resumen"),
			"",
			styles.AccentBold.Render(strconv.Itoa(cntDone)) + styles.Dim.Render(" completadas"),
			styles.CountErr.Render(strconv.Itoa(cntFailed)) + styles.Dim.Render(" fallidas"),
			"",
			styles.Dim.Render("Realm KC: " + dom),
			styles.Dim.Render("NS K8s:   sbos-" + dom),
			"",
			styles.DimItalic.Render("Log"),
			"",
			styles.Dim.Render("/var/log/bos/bootstrap.log"),
		}
		return buildCols(main, side)

	// ── Ubuntu ────────────────────────────────────────────────────────────────
	case 1:
		main := []string{
			styles.Bold.Render("Sistema Operativo"),
			"",
			summaryRow("SO", "Ubuntu Server 26.04 LTS"),
			summaryRow("Kernel", "7.0.0-22-generic"),
			summaryRow("Arch", "x86_64"),
			"",
			styles.DimItalic.Render("Servicios"),
			"",
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" containerd 2.1.x"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" systemd 257"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" sysctl hardening (ISO 27001 A.8.8)"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" ufw activo — puertos 22/80/443 only"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" fail2ban activo"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" unattended-upgrades habilitado"),
			"",
			styles.DimItalic.Render("bos.service (systemd)"),
			"",
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" active (running) — user=bosagent"),
			styles.Dim.Render("  Socket: /run/bos/bos.sock (0660)"),
			styles.Dim.Render("  TCP:    0.0.0.0:9443 (HTTPS)"),
		}
		side := []string{
			styles.DimItalic.Render("Estándares"),
			"",
			styles.Dim.Render("ISA-95 L0–L4"),
			styles.Dim.Render("NIST 800-207"),
			styles.Dim.Render("ISO 27001:2022"),
			styles.Dim.Render("CIS Ubuntu Benchmark"),
			styles.Dim.Render("NSA/CISA K8s Hardening"),
		}
		return buildCols(main, side)

	// ── Kubernetes ────────────────────────────────────────────────────────────
	case 2:
		main := []string{
			styles.Bold.Render("Kubernetes"),
			"",
			summaryRow("kubeadm/K8s", "v1.32+"),
			summaryRow("CNI", "Calico 3.32.0"),
			summaryRow("CRI", "containerd 2.1.x"),
			summaryRow("DNS", "CoreDNS 1.11+"),
			"",
			styles.DimItalic.Render("Control Plane"),
			"",
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" Linkerd 2.x mTLS — service mesh"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" Kyverno — políticas de seguridad"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" MetalLB — LoadBalancer L2"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" Kong 3.9.x LTS — API Gateway"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" Vault 2.0.1 — secretos"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" Keycloak 26.6.2 — IAM"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" PostgreSQL 18.4 HA"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" Redis 8.6.2"),
		}
		side := []string{
			styles.DimItalic.Render("Context Plane"),
			"",
			styles.Dim.Render("tenant:  " + dom),
			styles.Dim.Render("cluster: cluster-sbos"),
			styles.Dim.Render("node:    node-01"),
			styles.Dim.Render("ns:      sbos-" + dom),
			"",
			styles.DimItalic.Render("Red"),
			"",
			styles.Dim.Render("ClusterIP: 10.43.0.0/16"),
			styles.Dim.Render("Pod CIDR:  10.42.0.0/16"),
		}
		return buildCols(main, side)

	// ── SBOS / bos ────────────────────────────────────────────────────────────
	default:
		main := []string{
			styles.Bold.Render("Daemons soberanos"),
			"",
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.White.Render(" bKernel") + styles.Dim.Render(" — WAL listener · Fanout Redis Streams · MDM"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.White.Render(" bAuth  ") + styles.Dim.Render(" — BitMask 64-bit · 5 SPIs Java · ~5ms"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.White.Render(" bSearch") + styles.Dim.Render(" — PostgreSQL 18+ GIN · WebSocket wss://"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.White.Render(" biedata") + styles.Dim.Render(" — JSON-RPC 2.0 · fichas declarativas"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.White.Render(" bhnexus") + styles.Dim.Render(" — WebSocket mTLS · OSDP/MQTT · ~2ms"),
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.White.Render(" banexus") + styles.Dim.Render(" — udev intercept · actuadores · ~15ms"),
			styles.Tint(styles.IconDotDim, styles.ColorTextDisabled) + styles.Dim.Render(" bnotify") + styles.Muted.Render(" — pendiente (sbos-notifier)"),
			"",
			styles.DimItalic.Render("Observabilidad"),
			"",
			styles.Tint(styles.IconOK, styles.ColorStateOKFg) + styles.Dim.Render(" Grafana · Prometheus · Loki · Alloy"),
			"",
			styles.DimItalic.Render("Context Plane (SBOS-049)"),
			"",
			styles.Dim.Render("ctx_id:  activo — W3C TraceContext + OTel Baggage"),
			styles.Dim.Render("owner:   bos (IAM Installer)"),
			styles.Dim.Render("socket:  /run/bos/bos.sock"),
		}
		side := []string{
			styles.DimItalic.Render("Estándares"),
			"",
			styles.Dim.Render("W3C Trace Context"),
			styles.Dim.Render("OpenTelemetry Baggage"),
			styles.Dim.Render("NIST 800-207 ZeroTrust"),
			styles.Dim.Render("ISO 27001:2022"),
			styles.Dim.Render("IANA RFC 6335/7605"),
			"",
			styles.DimItalic.Render("ctx_id (parcial)"),
			"",
			styles.Dim.Render("tenant: " + dom),
			styles.Dim.Render("realm:  " + dom),
			styles.Dim.Render("pod:    bos-0"),
		}
		return buildCols(main, side)
	}
}
