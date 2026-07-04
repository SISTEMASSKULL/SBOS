package security

// CISCheck represents a single CIS Kubernetes Benchmark check.
type CISCheck struct {
	ID          string // e.g. "§1.1.11"
	Title       string // short description
	Severity    string // "CRITICAL", "HIGH", "MEDIUM", "LOW"
	Category    string // "ubuntu", "kubernetes", "bosctl"
	Remediation string // how to fix if the check fails
}

// CISBenchmarks returns the checks applicable to BOS Fase A.
// Sources: CIS Kubernetes Benchmark v1.9+, NIST SP 800-190, IEC 62443-4-2.
func CISBenchmarks() []CISCheck {
	return []CISCheck{
		// ── Ubuntu host hardening ──────────────────────────────────────
		{
			ID: "CIS-UB-001", Title: "/var/lib/etcd permissions 700",
			Severity: "CRITICAL", Category: "ubuntu",
			Remediation: "chmod 700 /var/lib/etcd",
		},
		{
			ID: "CIS-UB-002", Title: "/etc/bos/secrets permissions 700",
			Severity: "CRITICAL", Category: "ubuntu",
			Remediation: "chmod 700 /etc/bos/secrets",
		},
		{
			ID: "CIS-UB-003", Title: "ANTHROPIC_API_KEY not in journal or audit log",
			Severity: "CRITICAL", Category: "ubuntu",
			Remediation: "grep -r ANTHROPIC_API_KEY /var/log/ must return empty",
		},
		{
			ID: "CIS-UB-004", Title: "/etc/bos/rbac directory exists",
			Severity: "HIGH", Category: "ubuntu",
			Remediation: "mkdir -p /etc/bos/rbac",
		},

		// ── Kubernetes hardening ───────────────────────────────────────
		{
			ID: "CIS-K8S-001", Title: "kubelet anonymous-auth disabled",
			Severity: "CRITICAL", Category: "kubernetes",
			Remediation: "set anonymousAuth: false in /var/lib/kubelet/config.yaml",
		},
		{
			ID: "CIS-K8S-002", Title: "kubelet authorization mode Webhook",
			Severity: "CRITICAL", Category: "kubernetes",
			Remediation: "set authorization.mode: Webhook in /var/lib/kubelet/config.yaml",
		},
		{
			ID: "CIS-K8S-003", Title: "kubelet protect-kernel-defaults enabled",
			Severity: "HIGH", Category: "kubernetes",
			Remediation: "set protectKernelDefaults: true in /var/lib/kubelet/config.yaml",
		},
		{
			ID: "CIS-K8S-004", Title: "kubelet read-only port disabled",
			Severity: "HIGH", Category: "kubernetes",
			Remediation: "set readOnlyPort: 0 in /var/lib/kubelet/config.yaml",
		},
		{
			ID: "CIS-K8S-005", Title: "kube-apiserver anonymous-auth disabled",
			Severity: "CRITICAL", Category: "kubernetes",
			Remediation: "set --anonymous-auth=false on kube-apiserver",
		},
		{
			ID: "CIS-K8S-006", Title: "kube-apiserver audit-log-path configured",
			Severity: "HIGH", Category: "kubernetes",
			Remediation: "set --audit-log-path on kube-apiserver",
		},
		{
			ID: "CIS-K8S-007", Title: "CNI pods Running (kindnet or equivalent)",
			Severity: "HIGH", Category: "kubernetes",
			Remediation: "kubectl get pods -n kube-system | grep kindnet must show Running",
		},
		{
			ID: "CIS-K8S-008", Title: "K8s RBAC baseline: default serviceaccount cannot delete pods",
			Severity: "MEDIUM", Category: "kubernetes",
			Remediation: "kubectl auth can-i delete pods --as=default must return 'no'",
		},

		// ── bosctl RBAC ────────────────────────────────────────────────
		{
			ID: "BOS-RBAC-001", Title: "bosctl RBAC roles configured",
			Severity: "CRITICAL", Category: "bosctl",
			Remediation: "/etc/bos/rbac/roles.json must exist with admin/operator/readonly roles",
		},
		{
			ID: "BOS-RBAC-002", Title: "readonly role cannot execute repair",
			Severity: "HIGH", Category: "bosctl",
			Remediation: "bosctl --user readonly repair must return 'insufficient permissions'",
		},
	}
}
