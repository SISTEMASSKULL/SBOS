// Package main — os_commands.go: comandos OS-layer privilegiados (ADR-001).
// Extraídos de main.go en F4.5 (BOS-REPAIR) para que main.go quede ≤120 líneas.
// Estos comandos reemplazan sudo: exec, ls, cat, tail, systemctl, journalctl.
package main

import (
	"fmt"
	"os"
	"os/exec"
)

// cmdExec ejecuta un comando con privilegios root a través de BOS (ADR-001).
// Uso: bosctl exec -- <comando> [args...]
// El separador -- es obligatorio para desambiguar flags.
func cmdExec(args []string) int {
	if len(args) > 0 && args[0] == "--" {
		args = args[1:]
	}
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "bosctl: exec requires a command (use -- to separate flags)")
		return 2
	}
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return exitErr.ExitCode()
		}
		fmt.Fprintf(os.Stderr, "bosctl: exec: %v\n", err)
		return 1
	}
	return 0
}

// cmdLS lista un directorio con privilegios root (ls -la passthrough).
func cmdLS(args []string) int {
	path := "/"
	if len(args) > 0 {
		path = args[0]
	}
	cmd := exec.Command("ls", "-la", path)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return 1
	}
	return 0
}

// cmdCat lee un archivo con privilegios root (cat passthrough).
func cmdCat(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "bosctl: cat requires a path")
		return 2
	}
	cmd := exec.Command("cat", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return 1
	}
	return 0
}

// cmdTail sigue un archivo en tiempo real con privilegios root (tail -f passthrough).
func cmdTail(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "bosctl: tail requires a path")
		return 2
	}
	tailArgs := append([]string{"-f"}, args...)
	cmd := exec.Command("tail", tailArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return 1
	}
	return 0
}

// cmdSystemctl es un passthrough de systemctl con privilegios root (ADR-001).
func cmdSystemctl(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "bosctl: systemctl requires an action")
		return 2
	}
	cmd := exec.Command("systemctl", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return exitErr.ExitCode()
		}
		return 1
	}
	return 0
}

// cmdJournalctl es un passthrough de journalctl --no-pager con privilegios root.
func cmdJournalctl(args []string) int {
	cmdArgs := append([]string{"--no-pager"}, args...)
	cmd := exec.Command("journalctl", cmdArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return exitErr.ExitCode()
		}
		return 1
	}
	return 0
}
