package security

import (
	"fmt"
	"strings"
)

// ScanReport es el resultado de un escaneo de seguridad completo de todas las capas.
//
// Thread safety: inmutable tras RunFullScan(); seguro para lectura concurrente.
type ScanReport struct {
	Ubuntu  []CheckResult
	K8s     []CheckResult
	RBAC    *RBACStatus
	Summary ScanSummary
}

// RBACStatus captures the state of bosctl RBAC configuration.
type RBACStatus struct {
	Configured      bool
	Roles           []string
	Users           int
	ReadonlyBlocked bool // true = readonly role correctly blocked from repair
}

// ScanSummary contiene los puntajes agregados del escaneo CIS (Ubuntu + K8s + RBAC).
type ScanSummary struct {
	UbuntuPass   int
	UbuntuTotal  int
	K8sPass      int
	K8sTotal     int
	RBACOK       bool
	OverallPass  int
	OverallTotal int
	ScorePercent int
}

// RunFullScan ejecuta todos los controles de seguridad y retorna un informe unificado.
//
// Recibe:
//   - rbac: RBACProvider — proveedor de estado RBAC de bosctl.
//
// Retorna: *ScanReport con resultados Ubuntu, K8s, RBAC y resumen agregado.
//
// Callers conocidos:
//   - internal/server/api.go — handler "bos.security.scan".
//   - cmd/bosctl/app.go — subcomando "bosctl security".
//
// Efectos secundarios:
//   - Ejecuta comandos del host: stat, sshd -T, auditctl, kubectl.
//   - Solo lectura — no modifica configuración del sistema.
//
// Estándares: SBOS-047 ISMS-ISO27001, CIS Ubuntu/K8s Benchmarks.
func RunFullScan(rbac RBACProvider) *ScanReport {
	report := &ScanReport{}

	report.Ubuntu = RunUbuntuChecks()
	report.K8s = RunK8sChecks()
	report.RBAC = assessRBAC(rbac)

	// Compute summary
	up, ut := Score(report.Ubuntu)
	kp, kt := Score(report.K8s)
	report.Summary.UbuntuPass = up
	report.Summary.UbuntuTotal = ut
	report.Summary.K8sPass = kp
	report.Summary.K8sTotal = kt
	report.Summary.RBACOK = report.RBAC.Configured && report.RBAC.ReadonlyBlocked

	rbacScore := 0
	rbacTotal := 0
	if report.RBAC.Configured {
		rbacTotal += 2
		if report.RBAC.ReadonlyBlocked {
			rbacScore += 2
		} else {
			rbacScore += 1
		}
	}
	report.Summary.OverallPass = up + kp + rbacScore
	report.Summary.OverallTotal = ut + kt + rbacTotal

	if report.Summary.OverallTotal > 0 {
		report.Summary.ScorePercent = report.Summary.OverallPass * 100 / report.Summary.OverallTotal
	}

	return report
}

// assessRBAC checks RBAC provider health.
func assessRBAC(rbac RBACProvider) *RBACStatus {
	status := &RBACStatus{}
	if rbac == nil {
		status.Configured = false
		return status
	}
	status.Configured = true
	status.Roles = []string{RoleAdmin, RoleOperator, RoleReadonly}

	// Count users (best-effort: check known roles)
	if rbac.GetRole("skull") != "" {
		status.Users++
	}

	// Verify readonly is blocked from repair
	err := rbac.CanExecute("readonly-test", "repair --target=os")
	status.ReadonlyBlocked = (err != nil)
	return status
}

// FormatReport retorna el informe del escaneo de seguridad en formato legible para consola.
func FormatReport(report *ScanReport) string {
	var b strings.Builder

	b.WriteString("BOS SECURITY SCAN")
	if report.Summary.ScorePercent == 100 {
		b.WriteString(" — sbos-greenfield")
	} else {
		b.WriteString(" — sbos-greenfield [ISSUES FOUND]")
	}
	b.WriteString("\n")
	b.WriteString(strings.Repeat("═", 54))
	b.WriteString("\n")

	// Ubuntu section
	b.WriteString("\nUBUNTU HARDENING\n")
	for _, r := range report.Ubuntu {
		icon := "PASS"
		if !r.Pass {
			icon = "FAIL"
		}
		fmt.Fprintf(&b, "  [%s] %-50s %s\n", icon, r.Title, r.ID)
	}

	// K8s section
	b.WriteString("\nKUBERNETES HARDENING\n")
	for _, r := range report.K8s {
		icon := "PASS"
		if !r.Pass {
			icon = "FAIL"
		}
		fmt.Fprintf(&b, "  [%s] %-46s %s\n", icon, r.Title, r.ID)
	}

	// RBAC section
	b.WriteString("\nBOS RBAC\n")
	if report.RBAC.Configured {
		b.WriteString(fmt.Sprintf("  [PASS] bosctl RBAC roles configured (%d roles, %d user(s))    IEC 62443-4-2\n",
			len(report.RBAC.Roles), report.RBAC.Users))
	} else {
		b.WriteString("  [FAIL] bosctl RBAC not configured                              IEC 62443-4-2\n")
	}
	if report.RBAC.ReadonlyBlocked {
		b.WriteString("  [PASS] readonly role cannot execute repair                      IEC 62443-4-2\n")
	} else {
		b.WriteString("  [FAIL] readonly role NOT blocked from repair                   IEC 62443-4-2\n")
	}

	// Score
	b.WriteString("\n")
	b.WriteString(strings.Repeat("═", 54))
	b.WriteString("\n")
	fmt.Fprintf(&b, "SCORE: %d/%d", report.Summary.OverallPass, report.Summary.OverallTotal)

	if report.Summary.ScorePercent == 100 {
		b.WriteString(" — 100% ✅\n")
	} else {
		fmt.Fprintf(&b, " — %d%%\n", report.Summary.ScorePercent)
		// List failures
		b.WriteString("\nFAILURES:\n")
		for _, r := range report.Ubuntu {
			if !r.Pass {
				fmt.Fprintf(&b, "  %s — %s\n  → %s\n", r.ID, r.Title, r.Remediation())
			}
		}
		for _, r := range report.K8s {
			if !r.Pass {
				fmt.Fprintf(&b, "  %s — %s\n  → %s\n", r.ID, r.Title, r.Remediation())
			}
		}
	}
	b.WriteString(strings.Repeat("═", 54))
	b.WriteString("\n")
	return b.String()
}

// Remediation retorna el texto de remediación CIS para este CheckResult.
func (r CheckResult) Remediation() string {
	for _, cis := range CISBenchmarks() {
		if cis.ID == r.ID {
			return cis.Remediation
		}
	}
	return ""
}
