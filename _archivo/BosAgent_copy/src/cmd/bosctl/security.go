package main

import (
	"fmt"
	"os"
	"os/exec"

	"bos/internal/security"
)

func cmdSecurity(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "bosctl: security requires a subcommand: scan, audit")
		return 2
	}

	switch args[0] {
	case "scan":
		return cmdSecurityScan(args[1:])
	case "audit":
		return cmdSecurityAudit(args[1:])
	default:
		fmt.Fprintf(os.Stderr, "bosctl: unknown security subcommand: %s\n", args[0])
		return 2
	}
}

func cmdSecurityScan(args []string) int {
	// Load RBAC provider for RBAC checks
	rbac, err := security.NewFileRBAC("/etc/bos/rbac/roles.json")
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: RBAC config not accessible: %v\n", err)
		rbac = nil // interface holds typed nil; force untyped nil for safety
	}

	report := security.RunFullScan(rbac)
	fmt.Print(security.FormatReport(report))

	// Exit 0 if 100%, exit 1 if any check failed
	if report.Summary.ScorePercent == 100 {
		return 0
	}
	return 1
}

func cmdSecurityAudit(args []string) int {
	logPath := "/var/log/bos/audit.log"
	n := "50"
	if len(args) > 0 {
		n = args[0]
	}

	cmd := exec.Command("tail", "-n", n, logPath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		// Fallback to journalctl
		journalCmd := exec.Command("journalctl", "-u", "bos", "--no-pager", "-n", n)
		journalCmd.Stdout = os.Stdout
		journalCmd.Stderr = os.Stderr
		if err := journalCmd.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "bosctl: cannot read audit log: %v\n", err)
			return 1
		}
	}
	return 0
}
