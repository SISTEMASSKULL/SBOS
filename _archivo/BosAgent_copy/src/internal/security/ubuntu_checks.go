package security

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

// ── Ubuntu host hardening checks ────────────────────────────────────────────

// CheckResult is the outcome of a single CIS check.
type CheckResult struct {
	ID       string
	Title    string
	Pass     bool
	Detail   string
	Severity string
}

// RunUbuntuChecks executes all Ubuntu-host hardening checks.
func RunUbuntuChecks() []CheckResult {
	var results []CheckResult

	// UB-001: /var/lib/etcd permissions 700
	results = append(results, checkEtcdPerms())

	// UB-002: /etc/bos/secrets permissions 700
	results = append(results, checkSecretsPerms())

	// UB-003: ANTHROPIC_API_KEY not in logs
	results = append(results, checkAPIKeyNotInLogs())

	// UB-004: /etc/bos/rbac exists
	results = append(results, checkRbacDir())

	return results
}

func checkEtcdPerms() CheckResult {
	r := CheckResult{ID: "CIS-UB-001", Title: "/var/lib/etcd permissions 700", Severity: "CRITICAL"}
	info, err := os.Stat("/var/lib/etcd")
	if err != nil {
		r.Pass = false
		r.Detail = fmt.Sprintf("/var/lib/etcd: %v", err)
		return r
	}
	perm := info.Mode().Perm()
	if perm == 0700 {
		r.Pass = true
		r.Detail = "permissions 700 — OK"
	} else {
		r.Pass = false
		r.Detail = fmt.Sprintf("permissions %04o — expected 0700", perm)
	}
	return r
}

func checkSecretsPerms() CheckResult {
	r := CheckResult{ID: "CIS-UB-002", Title: "/etc/bos/secrets permissions 700", Severity: "CRITICAL"}
	info, err := os.Stat("/etc/bos/secrets")
	if err != nil {
		if os.IsNotExist(err) {
			r.Pass = false
			r.Detail = "/etc/bos/secrets does not exist"
		} else {
			r.Pass = false
			r.Detail = fmt.Sprintf("/etc/bos/secrets: %v", err)
		}
		return r
	}
	perm := info.Mode().Perm()
	if perm == 0700 {
		r.Pass = true
		r.Detail = "permissions 700 — OK"
	} else {
		r.Pass = false
		r.Detail = fmt.Sprintf("permissions %04o — expected 0700", perm)
	}
	return r
}

func checkAPIKeyNotInLogs() CheckResult {
	r := CheckResult{ID: "CIS-UB-003", Title: "ANTHROPIC_API_KEY not in logs", Severity: "CRITICAL"}
	cmd := exec.Command("sh", "-c",
		"grep -rl ANTHROPIC_API_KEY /var/log/ 2>/dev/null || true")
	out, err := cmd.Output()
	if err != nil {
		r.Pass = true // grep returns 1 = no matches, which is the desired state
		r.Detail = "no ANTHROPIC_API_KEY found in /var/log/"
		return r
	}
	files := strings.TrimSpace(string(out))
	if files == "" {
		r.Pass = true
		r.Detail = "no ANTHROPIC_API_KEY found in /var/log/"
	} else {
		r.Pass = false
		r.Detail = fmt.Sprintf("ANTHROPIC_API_KEY found in: %s", files)
	}
	return r
}

func checkRbacDir() CheckResult {
	r := CheckResult{ID: "CIS-UB-004", Title: "/etc/bos/rbac directory exists", Severity: "HIGH"}
	info, err := os.Stat("/etc/bos/rbac")
	if err != nil {
		r.Pass = false
		r.Detail = fmt.Sprintf("/etc/bos/rbac: %v", err)
		return r
	}
	if info.IsDir() {
		r.Pass = true
		r.Detail = "directory exists — OK"
	} else {
		r.Pass = false
		r.Detail = "/etc/bos/rbac is not a directory"
	}
	return r
}

// ── Helper: percentages ─────────────────────────────────────────────────────

// Score computes pass percentage from a slice of CheckResults.
func Score(results []CheckResult) (pass, total int) {
	total = len(results)
	pass = total // will be decremented for each failure
	for _, r := range results {
		if !r.Pass {
			pass--
		}
	}
	return
}

// FormatScore returns "8/10 — 80%" from pass/total.
func FormatScore(pass, total int) string {
	if total == 0 {
		return "0/0 — 0%"
	}
	pct := float64(pass) / float64(total) * 100
	return strconv.Itoa(pass) + "/" + strconv.Itoa(total) + " — " + strconv.Itoa(int(pct)) + "%"
}
