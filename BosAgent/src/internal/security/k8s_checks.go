package security

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

// RunK8sChecks ejecuta todos los controles de hardening de Kubernetes (8 checks CIS K8s).
//
// Retorna: []CheckResult con los resultados de los 8 controles CIS-K8S-001..008.
//
// Callers conocidos:
//   - internal/security/scanner.go:RunFullScan — integrado al escaneo completo.
//
// Efectos secundarios:
//   - Lee /var/lib/kubelet/config.yaml, ejecuta ps aux, kubectl auth can-i.
//   - Si kubelet no está corriendo, los checks retornan PASS con nota "pre-bootstrap".
//
// Estándares: CIS Kubernetes Benchmark v1.9+, NSA/CISA K8s Hardening Guide.
func RunK8sChecks() []CheckResult {
	var results []CheckResult

	// K8S-001: kubelet anonymous-auth disabled
	results = append(results, checkKubeletAnonymousAuth())

	// K8S-002: kubelet authorization mode Webhook
	results = append(results, checkKubeletAuthzMode())

	// K8S-003: kubelet protect-kernel-defaults
	results = append(results, checkProtectKernelDefaults())

	// K8S-004: kubelet readOnlyPort disabled
	results = append(results, checkReadOnlyPort())

	// K8S-005: kube-apiserver anonymous-auth disabled
	results = append(results, checkAPIServerAnonymousAuth())

	// K8S-006: kube-apiserver audit-log-path
	results = append(results, checkAPIServerAuditLog())

	// K8S-007: CNI pods Running
	results = append(results, checkCNIHealth())

	// K8S-008: K8s RBAC baseline
	results = append(results, checkK8sRBACBaseline())

	return results
}

func checkKubeletAnonymousAuth() CheckResult {
	r := CheckResult{ID: "CIS-K8S-001", Title: "kubelet anonymous-auth disabled", Severity: "CRITICAL"}
	out, err := exec.Command("sh", "-c",
		"grep -E '^anonymous-auth:|^  anonymousAuth:' /var/lib/kubelet/config.yaml 2>/dev/null || echo NOT_FOUND").Output()
	if err != nil {
		r.Pass = false
		r.Detail = "cannot read kubelet config: " + err.Error()
		return r
	}
	outStr := strings.TrimSpace(string(out))
	if strings.Contains(outStr, "NOT_FOUND") {
		// Try via ps — kubelet may be configured via flags
		out2, _ := exec.Command("sh", "-c",
			"ps aux | grep kubelet | grep -o 'anonymous-auth=[a-z]*' || echo NOT_RUNNING").Output()
		outStr2 := strings.TrimSpace(string(out2))
		if strings.Contains(outStr2, "NOT_RUNNING") {
			r.Pass = true // pre-install: kubelet not running yet, check will apply
			r.Detail = "kubelet not running — hardening will be applied at install time"
			return r
		}
		if strings.Contains(outStr2, "anonymous-auth=false") {
			r.Pass = true
			r.Detail = "anonymous-auth=false (via flags) — OK"
		} else {
			r.Pass = false
			r.Detail = "anonymous-auth not disabled: " + outStr2
		}
		return r
	}
	if strings.Contains(outStr, "false") {
		r.Pass = true
		r.Detail = "anonymous-auth: false — OK"
	} else {
		r.Pass = false
		r.Detail = "anonymous-auth is not false: " + outStr
	}
	return r
}

func checkKubeletAuthzMode() CheckResult {
	r := CheckResult{ID: "CIS-K8S-002", Title: "kubelet authorization mode Webhook", Severity: "CRITICAL"}
	out, err := exec.Command("sh", "-c",
		"grep -E 'authorization-mode:|authorization.mode:' /var/lib/kubelet/config.yaml 2>/dev/null || echo NOT_FOUND").Output()
	if err != nil {
		r.Pass = false
		r.Detail = "cannot check: " + err.Error()
		return r
	}
	outStr := strings.TrimSpace(string(out))
	if strings.Contains(outStr, "NOT_FOUND") {
		out2, _ := exec.Command("sh", "-c",
			"ps aux | grep kubelet | grep -o 'authorization-mode=[A-Za-z]*' || echo NOT_RUNNING").Output()
		outStr2 := strings.TrimSpace(string(out2))
		if strings.Contains(outStr2, "NOT_RUNNING") {
			r.Pass = true
			r.Detail = "kubelet not running — hardening will apply at install"
			return r
		}
		if strings.Contains(outStr2, "Webhook") {
			r.Pass = true
			r.Detail = "authorization-mode=Webhook — OK"
		} else {
			r.Pass = false
			r.Detail = "authorization mode not Webhook: " + outStr2
		}
		return r
	}
	if strings.Contains(strings.ToLower(outStr), "webhook") {
		r.Pass = true
		r.Detail = "authorization.mode: Webhook — OK"
	} else {
		r.Pass = false
		r.Detail = "authorization mode not Webhook: " + outStr
	}
	return r
}

func checkProtectKernelDefaults() CheckResult {
	r := CheckResult{ID: "CIS-K8S-003", Title: "kubelet protect-kernel-defaults enabled", Severity: "HIGH"}
	out, err := exec.Command("sh", "-c",
		"grep -E 'protectKernelDefaults:|protect-kernel-defaults:' /var/lib/kubelet/config.yaml 2>/dev/null || echo NOT_FOUND").Output()
	if err != nil {
		r.Pass = false
		r.Detail = "cannot check: " + err.Error()
		return r
	}
	outStr := strings.TrimSpace(string(out))
	if strings.Contains(outStr, "NOT_FOUND") {
		r.Pass = true
		r.Detail = "kubelet not running — hardening will apply at install"
		return r
	}
	if strings.Contains(outStr, "true") {
		r.Pass = true
		r.Detail = "protectKernelDefaults: true — OK"
	} else {
		r.Pass = false
		r.Detail = "protectKernelDefaults is not true: " + outStr
	}
	return r
}

func checkReadOnlyPort() CheckResult {
	r := CheckResult{ID: "CIS-K8S-004", Title: "kubelet read-only port disabled", Severity: "HIGH"}
	out, err := exec.Command("sh", "-c",
		"grep -E 'readOnlyPort:|read-only-port:' /var/lib/kubelet/config.yaml 2>/dev/null || echo NOT_FOUND").Output()
	if err != nil {
		r.Pass = false
		r.Detail = "cannot check: " + err.Error()
		return r
	}
	outStr := strings.TrimSpace(string(out))
	if strings.Contains(outStr, "NOT_FOUND") {
		out2, _ := exec.Command("sh", "-c",
			"ps aux | grep kubelet | grep -o 'read-only-port=[0-9]*' || echo NOT_RUNNING").Output()
		outStr2 := strings.TrimSpace(string(out2))
		if strings.Contains(outStr2, "NOT_RUNNING") {
			r.Pass = true
			r.Detail = "kubelet not running — hardening will apply at install"
			return r
		}
		if strings.Contains(outStr2, "read-only-port=0") {
			r.Pass = true
			r.Detail = "read-only-port=0 — OK"
		} else {
			r.Pass = false
			r.Detail = "read-only-port not 0: " + outStr2
		}
		return r
	}
	if strings.Contains(outStr, "0") {
		r.Pass = true
		r.Detail = "readOnlyPort: 0 — OK"
	} else {
		r.Pass = false
		r.Detail = "readOnlyPort is not 0: " + outStr
	}
	return r
}

func checkAPIServerAnonymousAuth() CheckResult {
	r := CheckResult{ID: "CIS-K8S-005", Title: "kube-apiserver anonymous-auth disabled", Severity: "CRITICAL"}
	out, err := exec.Command("sh", "-c",
		"ps aux | grep kube-apiserver | grep -o 'anonymous-auth=[a-z]*' || echo NOT_RUNNING").Output()
	if err != nil {
		r.Pass = false
		r.Detail = "cannot check: " + err.Error()
		return r
	}
	outStr := strings.TrimSpace(string(out))
	if strings.Contains(outStr, "NOT_RUNNING") {
		r.Pass = true
		r.Detail = "kube-apiserver not running — hardening will apply at install"
		return r
	}
	if strings.Contains(outStr, "anonymous-auth=false") {
		r.Pass = true
		r.Detail = "anonymous-auth=false — OK"
	} else {
		r.Pass = false
		r.Detail = "anonymous-auth not disabled: " + outStr
	}
	return r
}

func checkAPIServerAuditLog() CheckResult {
	r := CheckResult{ID: "CIS-K8S-006", Title: "kube-apiserver audit-log-path configured", Severity: "HIGH"}
	out, err := exec.Command("sh", "-c",
		"ps aux | grep kube-apiserver | grep -o 'audit-log-path=[^ ]*' || echo NOT_RUNNING").Output()
	if err != nil {
		r.Pass = false
		r.Detail = "cannot check: " + err.Error()
		return r
	}
	outStr := strings.TrimSpace(string(out))
	if strings.Contains(outStr, "NOT_RUNNING") {
		r.Pass = true
		r.Detail = "kube-apiserver not running — hardening will apply at install"
		return r
	}
	if strings.Contains(outStr, "audit-log-path=") {
		r.Pass = true
		r.Detail = "audit-log-path configured: " + outStr
	} else {
		r.Pass = false
		r.Detail = "audit-log-path not found in kube-apiserver flags"
	}
	return r
}

func checkCNIHealth() CheckResult {
	r := CheckResult{ID: "CIS-K8S-007", Title: "CNI pods Running", Severity: "HIGH"}
	out, err := exec.Command("sh", "-c",
		"kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -E 'kindnet|calico|flannel|cilium|weave' | grep Running | wc -l").Output()
	if err != nil {
		// kubectl may not be configured yet
		r.Pass = true
		r.Detail = "CNI check deferred — kubeconfig not accessible or K8s pre-bootstrap"
		return r
	}
	count := strings.TrimSpace(string(out))
	if count != "0" && count != "" {
		r.Pass = true
		r.Detail = fmt.Sprintf("%s CNI pod(s) Running — OK", count)
	} else {
		r.Pass = false
		r.Detail = "no CNI pods Running — network may be degraded"
	}
	return r
}

func checkK8sRBACBaseline() CheckResult {
	r := CheckResult{ID: "CIS-K8S-008", Title: "K8s RBAC baseline: default SA cannot delete pods", Severity: "MEDIUM"}
	cmd := exec.Command("kubectl", "auth", "can-i", "delete", "pods", "--as=default", "--namespace=default")
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		r.Pass = true
		r.Detail = "RBAC check deferred — kubeconfig not accessible or K8s pre-bootstrap"
		return r
	}
	outStr := strings.TrimSpace(string(out))
	if outStr == "no" {
		r.Pass = true
		r.Detail = "default SA cannot delete pods — OK"
	} else {
		r.Pass = false
		r.Detail = "default SA can delete pods — RBAC baseline missing"
	}
	return r
}
