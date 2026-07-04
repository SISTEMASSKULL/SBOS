// Package main — daemon_commands.go: comandos de control del daemon bos.
// Extraídos de main.go en F4.5 (BOS-REPAIR).
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"time"

	"bos/internal/paths"
)

// cmdStatus muestra el estado del daemon y las fichas instaladas (JSON indentado).
func cmdStatus(args []string) int {
	resp, err := wsRequest("status", nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: %v\n", err)
		if strings.Contains(err.Error(), "daemon not available") {
			return 6
		}
		return 1
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	enc.Encode(resp.Data)
	return 0
}

// cmdHealth muestra el estado de salud del daemon. Retorna exit 4 si está en modo staged.
func cmdHealth(args []string) int {
	resp, err := wsRequest("health", nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: %v\n", err)
		if strings.Contains(err.Error(), "daemon not available") {
			return 6
		}
		return 1
	}
	data, _ := resp.Data.(map[string]interface{})
	status, _ := data["status"].(string)
	fmt.Printf("bos daemon: %s\n", status)
	if status == "config_pending" {
		msg, _ := data["message"].(string)
		fmt.Printf("mode: staged\nmessage: %s\n", msg)
		return 4
	}
	fichas, _ := data["fichas_loaded"].(float64)
	fmt.Printf("fichas loaded: %.0f\n", fichas)
	return 0
}

// cmdInstall dispara la instalación de una ficha en el daemon vía WebSocket.
func cmdInstall(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "bosctl: install requires a ficha name")
		return 2
	}
	ficha := args[0]
	resp, err := wsRequest("ficha_install", map[string]interface{}{
		"ficha":   ficha,
		"version": "latest",
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: %v\n", err)
		if strings.Contains(err.Error(), "daemon not available") {
			return 6
		}
		if strings.Contains(err.Error(), "ficha not found") {
			return 3
		}
		if strings.Contains(err.Error(), "config-pending") {
			return 6
		}
		return 1
	}
	fmt.Printf("install triggered for ficha %s\n", ficha)
	if data, ok := resp.Data.(map[string]interface{}); ok {
		if steps, ok := data["Steps"]; ok {
			enc := json.NewEncoder(os.Stdout)
			enc.SetIndent("", "  ")
			enc.Encode(steps)
		}
	}
	return 0
}

// cmdShutdown solicita al daemon un apagado graceful y espera hasta que el socket desaparezca.
// Retorna exit 7 si se agota el timeout.
func cmdShutdown(args []string) int {
	fs := flag.NewFlagSet("shutdown", flag.ExitOnError)
	timeout := fs.Int("timeout", 180, "max seconds to wait for daemon to stop")
	fs.Parse(args)
	socket := socketPath()
	resp, err := wsRequest("shutdown", nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: shutdown request failed: %v\n", err)
		if strings.Contains(err.Error(), "daemon not available") {
			return 6
		}
		return 1
	}
	data, _ := resp.Data.(map[string]interface{})
	msg, _ := data["message"].(string)
	fmt.Printf("shutdown: %s\n", msg)
	deadline := time.Now().Add(time.Duration(*timeout) * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(socket); os.IsNotExist(err) {
			fmt.Println("bos daemon stopped")
			return 0
		}
		time.Sleep(500 * time.Millisecond)
	}
	fmt.Fprintf(os.Stderr, "bosctl: timeout after %ds — daemon may still be stopping\n", *timeout)
	return 7
}

// cmdReload envía SIGHUP al daemon para recargar configuración (config hot-reload).
func cmdReload(args []string) int {
	pidBytes, err := os.ReadFile(paths.PidFile)
	if err != nil {
		out, err := exec.Command("pgrep", "-f", "bos.*--config").Output()
		if err != nil {
			fmt.Fprintln(os.Stderr, "bosctl: could not find bos process — is it running?")
			return 6
		}
		pidStr := strings.TrimSpace(strings.Split(string(out), "\n")[0])
		var pid int
		fmt.Sscanf(pidStr, "%d", &pid)
		if pid == 0 {
			return 6
		}
		return sendSIGHUP(pid)
	}
	pidStr := strings.TrimSpace(string(pidBytes))
	var pid int
	fmt.Sscanf(pidStr, "%d", &pid)
	if pid == 0 {
		fmt.Fprintln(os.Stderr, "bosctl: invalid PID in /run/bos/bos.pid")
		return 6
	}
	return sendSIGHUP(pid)
}

// sendSIGHUP envía la señal SIGHUP al proceso con el PID dado.
func sendSIGHUP(pid int) int {
	proc, err := os.FindProcess(pid)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: find process %d: %v\n", pid, err)
		return 6
	}
	if err := proc.Signal(syscall.SIGHUP); err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: signal SIGHUP to %d: %v\n", pid, err)
		return 1
	}
	fmt.Printf("SIGHUP sent to bos (pid %d)\n", pid)
	return 0
}
