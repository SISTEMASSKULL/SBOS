// bosctl — CLI control tool for the bos daemon.
// Communicates via Unix socket (default /run/bos/bos.sock).
// Override with BOS_SOCKET env var.
//
// ADR-001: bosctl is the OS-layer CLI — it replaces sudo.
// All privileged operations go through bosctl, never through sudo directly.
//
// Exit codes per SBOS-018 §12:
//
//	0  success
//	1  general error
//	2  validation error
//	3  ficha not found
//	4  operation in progress
//	5  dependency not satisfied
//	6  daemon not available
//	7  timeout
//	8  governance denied
//	10 internal error
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"time"

	"bos/internal/security"

	"github.com/gorilla/websocket"
	"github.com/joho/godotenv"
)

const defaultSocket = "/run/bos/bos.sock"

// wsResponse matches the server Response envelope over WebSocket.
type wsResponse struct {
	Type  string      `json:"type"`
	ID    string      `json:"id"`
	OK    bool        `json:"ok"`
	Data  interface{} `json:"data,omitempty"`
	Error string      `json:"error,omitempty"`
	Time  time.Time   `json:"time"`
}

func main() {
	// Load API keys from /etc/bos/.env if present (silent if missing).
	_ = godotenv.Load("/etc/bos/.env")

	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}

	cmd := os.Args[1]
	args := os.Args[2:]

	switch cmd {
	// Daemon control commands (via Unix socket)
	case "status":
		os.Exit(cmdStatus(args))
	case "install":
		os.Exit(cmdPkgInstall(args))
	case "setup":
		os.Exit(cmdInstallUI(args))
	case "release":
		os.Exit(cmdRelease(args))
	case "remove":
		os.Exit(cmdRemove(args))
	case "upgrade":
		os.Exit(cmdUpgrade(args))
	case "repair":
		os.Exit(cmdRepair(args))
	case "shutdown":
		os.Exit(cmdShutdown(args))
	case "logs":
		os.Exit(cmdLogs(args))
	case "reload":
		os.Exit(cmdReload(args))
	case "health":
		os.Exit(cmdHealth(args))

	// Observability (D3 — Fase C)
	case "top":
		os.Exit(cmdTop(args))
	case "health-report":
		os.Exit(cmdHealthReport(args))

	// Identity (Fase B) — gestión de usuarios y roles
	case "identity":
		os.Exit(cmdIdentity(args))

	// Security (D6 — Fase A) — soberano, opera sobre archivos y binarios locales
	case "security":
		os.Exit(cmdSecurity(args))

	// Catalog (D5 — Fase D) — app list, history, rollback
	case "app":
		os.Exit(cmdApp(args))

	// AI Agent (D4 — Fase D) — model router (bCompass is the real AI orchestrator)
	case "ask", "ia":
		os.Exit(cmdAsk(args))

	// Configuration (Fase D) — API keys, model prefs
	case "set":
		os.Exit(cmdSet(args))

	// OS-layer privileged commands (ADR-001 — replace sudo)
	case "exec":
		if code := rbacGuard("exec"); code != 0 {
			os.Exit(code)
		}
		os.Exit(cmdExec(args))
	case "ls":
		if code := rbacGuard("ls"); code != 0 {
			os.Exit(code)
		}
		os.Exit(cmdLS(args))
	case "cat":
		if code := rbacGuard("cat"); code != 0 {
			os.Exit(code)
		}
		os.Exit(cmdCat(args))
	case "tail":
		if code := rbacGuard("tail"); code != 0 {
			os.Exit(code)
		}
		os.Exit(cmdTail(args))
	case "systemctl":
		if code := rbacGuard("systemctl"); code != 0 {
			os.Exit(code)
		}
		os.Exit(cmdSystemctl(args))
	case "journalctl":
		if code := rbacGuard("journalctl"); code != 0 {
			os.Exit(code)
		}
		os.Exit(cmdJournalctl(args))

	// Bootstrap (Iteración 1 — motor de instalación 19 fichas)
	case "bootstrap":
		os.Exit(cmdBootstrap(args))

	// JSON-RPC 2.0 directo — ADR-019
	case "rpc":
		os.Exit(cmdRPC(args))

	case "help", "-h", "--help":
		usage()
		os.Exit(0)
	default:
		fmt.Fprintf(os.Stderr, "bosctl: unknown command: %s\n", cmd)
		usage()
		os.Exit(2)
	}
}

// rbacUser returns the user identity from BOS_USER env var.
// Empty string means "trusted caller" (root context, no RBAC check).
func rbacUser() string {
	return os.Getenv("BOS_USER")
}

// globalRBAC caches the RBAC provider (FileRBAC or BauthRBAC bridge).
var globalRBAC security.RBACProvider

// getRBAC returns the shared RBAC provider, initialized on first call.
// Uses BauthRBAC bridge if BOS_BAUTH_ENABLED=true, otherwise FileRBAC.
func getRBAC() security.RBACProvider {
	if globalRBAC != nil {
		return globalRBAC
	}
	fileRBAC, err := security.NewFileRBAC("/etc/bos/rbac/roles.json")
	if err != nil {
		return nil
	}
	if os.Getenv("BOS_BAUTH_ENABLED") == "true" || os.Getenv("BOS_BAUTH_ENABLED") == "1" {
		socketPath := os.Getenv("BOS_BAUTH_SOCKET")
		if socketPath == "" {
			socketPath = "/run/bos/bauth.sock"
		}
		bauthCfg := security.BauthRBACConfig{
			Enabled:    true,
			SocketPath: socketPath,
			Timeout:    2000 * time.Millisecond,
			Fallback:   fileRBAC,
		}
		globalRBAC = security.NewBauthRBAC(bauthCfg)
	} else {
		globalRBAC = fileRBAC
	}
	return globalRBAC
}

// rbacGuard checks whether the current user is authorized to execute cmd.
// Returns 0 if authorized, 8 (governance denied) if blocked.
// When BOS_USER is empty, the check is skipped (trusted/root caller).
func rbacGuard(cmd string) int {
	user := rbacUser()
	if user == "" {
		return 0
	}
	rbac := getRBAC()
	if rbac == nil {
		fmt.Fprintf(os.Stderr, "bosctl: RBAC not available\n")
		return 0
	}
	if err := rbac.CanExecute(user, cmd); err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: access denied: %v\n", err)
		return 8
	}
	return 0
}

func usage() {
	fmt.Fprint(os.Stderr, `bosctl — SBOS daemon control tool (OS layer CLI)

Bootstrap (Instalación inicial — 22 fichas, 7 niveles del DAG):
  bosctl bootstrap start                  Instalación interactiva (pantallas TUI)
  bosctl bootstrap start --unattended     Instalación automática con seed file
  bosctl bootstrap status                 Ver progreso actual de la instalación
  bosctl bootstrap verify                 Verificar criterios de certificación (C-01 a C-08)
  bosctl bootstrap resume                 Reanudar instalación interrumpida
  bosctl bootstrap reset --confirm        Reiniciar estado bootstrap (DESTRUCTIVO)

JSON-RPC 2.0 (ADR-019 — invocación directa desde terminal o scripts):
  bosctl rpc bos.ficha.list
  bosctl rpc bos.ficha.status     '{"ficha_id":"postgresql"}'
  bosctl rpc bos.saga.execute     '{"ficha_id":"redis","command":"repair"}'
  bosctl rpc bos.bootstrap.verify
  bosctl rpc bos.health.check
  bosctl rpc bos.ctx.create       '{"tenant_id":"acme","empresa_id":"e1"}'
  bosctl rpc --help               Ver catálogo completo de métodos

Daemon control:
  bosctl status              Show daemon and ficha status
  bosctl health              Show daemon health
  bosctl install <ficha>     Trigger ficha installation
  bosctl setup               Instalación interactiva (TUI 6 pantallas)
  bosctl setup --unattended --seed-file=tenant.yml
  bosctl shutdown            Gracefully stop the bos daemon
  bosctl logs                Tail bos daemon logs (journalctl)
  bosctl reload              Reload configuration (SIGHUP)

  Repair (Fase B - D1):
    bosctl repair --target=all         Full repair: Ubuntu + K8s + BOS fichas
    bosctl repair --target=os          Ubuntu-only repair (dpkg, apt, systemd)
    bosctl repair --target=k8s         K8s node repair (cordon->drain->restart->uncordon)
    bosctl repair --target=bos         BOS ficha reconciliation
    bosctl repair --dry-run            Simulate without executing
    bosctl repair --timeout=600        Max seconds for repair (default: 600)

  Package Manager (Fase B - D2):
    bosctl install <pkg> --backend=apt  Install system package + auto-generate ficha
    bosctl install <pkg> --backend=pip  Install Python package + auto-generate ficha
    bosctl install <pkg> --backend=helm Install Helm chart + auto-generate ficha
    bosctl remove <pkg>                 Uninstall package + remove auto-generated ficha
    bosctl upgrade <pkg> --to=<ver>     Upgrade package to version

  Security (Fase A - D6):
    bosctl security scan       Full CIS scan: Ubuntu + K8s + bosctl RBAC
    bosctl security audit [n]  Show last n lines of audit log (default 50)

  Observability (Fase C - D3):
    bosctl top                  Unified metrics: CPU/mem/disk + K8s + fichas
    bosctl health-report        Full health report (Ubuntu + K8s + BOS layers)
    bosctl health-report --json Structured JSON health report
    bosctl logs <target>        Logs for systemd service or K8s pod
    bosctl logs --follow        Stream logs in real time
    bosctl logs <pod> --namespace=<ns>  K8s pod logs with namespace

Catalog (Fase D — D5):
    bosctl app list              List all fichas grouped by category
    bosctl app history <ficha>   Show version history and snapshots
    bosctl app rollback <ficha> --to=<ver>  Rollback ficha to version

AI Agent (Fase D — D4):
    bosctl ia <pregunta>          Preguntar al modelo IA (usa /etc/bos/.env para API keys)
    bosctl ia diagnose            Diagnostico autonomo del sistema
    bosctl ia explain <ficha>     Explicar una ficha y su configuracion
    bosctl ia plan <objetivo>     Proponer plan de accion paso a paso
    bosctl ia --model=<m> <...>   Forzar modelo: deepseek-v4-pro, claude-sonnet-4-6, local
    Sin conexion/tokens:          "sin conexion o sin tokens disponibles"

Configuration:
    bosctl set apikey <m>=<key>   Configurar API key para un modelo
      modelos: claude deepseek openai ollama
      ej: bosctl set apikey claude=sk-ant-...
      ej: bosctl set apikey deepseek=sk-...

Identity (Fase B):
    bosctl identity whoami         Show current user and role
    bosctl identity users          List all users and their roles
    bosctl identity roles          List all defined roles
    bosctl identity set-role <user> <role>  Assign role to user (requires admin)
    bosctl identity revoke <user>       Revoke user access (requires admin)

OS-layer privileged commands (ADR-001 — replace sudo):
  bosctl exec -- <comando>     Execute command as root via BOS
  bosctl ls <path>             List directory with root privileges
  bosctl cat <path>            Read file with root privileges
  bosctl tail <path>           Tail file with root privileges
  bosctl systemctl <accion>    systemctl passthrough (restart, status, etc.)
  bosctl journalctl <flags>    journalctl passthrough

Environment:
  BOS_SOCKET    Path to bos Unix socket (default: /run/bos/bos.sock)
  BOS_USER      User identity for RBAC enforcement (empty = trusted/root, no check)

Exit codes:
  0  success
  1  general error
  2  validation
  3  ficha not found
  4  operation in progress
  5  dependency not satisfied
  6  daemon not available
  7  timeout
  8  governance denied
  10 internal error
`)
}

// ── OS-Layer Privileged Commands (ADR-001) ─────────────────────────

// cmdExec runs a command with full root privileges via BOS.
// Usage: bosctl exec -- <command> [args...]
// The -- separator is required to disambiguate flags.
func cmdExec(args []string) int {
	// Handle -- separator
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

// ── WebSocket Helpers ──────────────────────────────────────────────

func socketPath() string {
	if s := os.Getenv("BOS_SOCKET"); s != "" {
		return s
	}
	return defaultSocket
}

// wsRequest sends a request to the bos daemon via WebSocket over Unix socket
// and returns the parsed response. Action and params form the request envelope.
func wsRequest(action string, params map[string]interface{}) (*wsResponse, error) {
	socket := socketPath()
	dialer := websocket.Dialer{
		NetDialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
			var d net.Dialer
			return d.DialContext(ctx, "unix", socket)
		},
		HandshakeTimeout: 10 * time.Second,
	}

	conn, _, err := dialer.DialContext(context.Background(), "ws://unix/ws", nil)
	if err != nil {
		return nil, fmt.Errorf("daemon not available at %s: %w", socket, err)
	}
	defer conn.Close()

	req := map[string]interface{}{
		"type":   "request",
		"id":     fmt.Sprintf("bosctl-%d", time.Now().UnixNano()),
		"action": action,
		"params": params,
	}

	conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
	if err := conn.WriteJSON(req); err != nil {
		return nil, fmt.Errorf("send request: %w", err)
	}

	conn.SetReadDeadline(time.Now().Add(30 * time.Second))
	var resp wsResponse
	if err := conn.ReadJSON(&resp); err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if !resp.OK {
		return &resp, fmt.Errorf("%s", resp.Error)
	}
	return &resp, nil
}

// ── Daemon Commands ─────────────────────────────────────────────────

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

	// Poll until daemon socket disappears or timeout
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


func cmdReload(args []string) int {
	pidBytes, err := os.ReadFile("/run/bos/bos.pid")
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
