// Package model — ws.go: conexión WebSocket al daemon bos y tick del dashboard.
// Migrado de cmd/bosctl/install_ui_impl.go en BOS-REPAIR F3.MIGRATE.
package model

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"bos/internal/tui/ctrl/dash"
	tuiobs "bos/internal/tui/observer"
	"bos/internal/wslib"

	tea "github.com/charmbracelet/bubbletea"
)

const DefaultSocket = "/run/bos/bos.sock"

// ConnectWS conecta al daemon bos vía Unix socket WebSocket.
// Auto-arranca el daemon si el socket no existe.
func ConnectWS(ch chan WsEventMsg, stopCh chan struct{}) tea.Cmd {
	return func() tea.Msg {
		socketPath := os.Getenv("BOS_SOCKET")
		if socketPath == "" {
			socketPath = DefaultSocket
		}

		if err := EnsureDaemonRunning(socketPath); err != nil {
			return WsErrorMsg{Err: err}
		}

		conn, err := wslib.DialUnix(socketPath, 3*time.Second)
		if err != nil {
			return WsErrorMsg{Err: err}
		}

		// Al cerrar el TUI, cerrar la conexión para desbloquear ReadMessage.
		go func() {
			<-stopCh
			conn.Close()
		}()

		// Goroutine lectora de eventos WS.
		go func() {
			for {
				_, raw, err := conn.ReadMessage()
				if err != nil {
					return
				}

				var ev map[string]interface{}
				if json.Unmarshal(raw, &ev) != nil {
					continue
				}
				evType, _ := ev["type"].(string)
				ficha, _ := ev["ficha"].(string)
				step, _ := ev["step"].(string)
				msg, _ := ev["message"].(string)
				errDetail, _ := ev["error"].(string)
				var total int
				var evData map[string]interface{}
				if d, ok := ev["data"].(map[string]interface{}); ok {
					evData = d
					if t, ok := d["fichas_total"].(float64); ok {
						total = int(t)
					}
				}
				// bootstrap_status llega como type="response" con data.fichas
				if evType == "response" {
					if d, ok := ev["data"].(map[string]interface{}); ok {
						if _, hasFichas := d["fichas"]; hasFichas {
							evType = "bootstrap_status"
							evData = d
						}
					}
				}
				select {
				case ch <- WsEventMsg{
					EvType: evType, Ficha: ficha, Step: step,
					Msg: msg, Total: total, ErrDetail: errDetail, Data: evData,
				}:
				case <-stopCh:
					return
				}
			}
		}()

		return WsReadyMsg{Conn: conn}
	}
}

// AwaitWS bloquea hasta el próximo evento WS o hasta que stopCh se cierre.
// Captura el timestamp aquí (fuera de Update) — cumple invariante P3.
func AwaitWS(ch chan WsEventMsg, stopCh chan struct{}) tea.Cmd {
	return func() tea.Msg {
		select {
		case msg := <-ch:
			if msg.Ts.IsZero() {
				msg.Ts = time.Now()
			}
			return msg
		case <-stopCh:
			return nil
		}
	}
}

// SendWS envía un request JSON-RPC al daemon bos.
func SendWS(conn *wslib.Conn, action string, params map[string]interface{}) tea.Cmd {
	return func() tea.Msg {
		if conn == nil {
			return nil
		}
		_ = conn.WriteJSON(map[string]interface{}{
			"type": "request", "id": fmt.Sprintf("tui-%d", time.Now().UnixNano()),
			"action": action, "params": params,
		})
		return nil
	}
}

// DashTickCmd lee métricas reales del SO y devuelve un DashTickMsg.
// Se programa cada 3 segundos mientras el dashboard está activo.
func DashTickCmd() tea.Cmd {
	return func() tea.Msg {
		snap := tuiobs.Read()
		return dash.DashTickMsg{Snap: snap, Time: time.Now()}
	}
}

// EnsureDaemonRunning asegura que el daemon bos esté corriendo en socketPath.
// Busca el binario en rutas canónicas y lo arranca si no está.
func EnsureDaemonRunning(socketPath string) error {
	if _, err := os.Stat(socketPath); err == nil {
		return nil
	}

	candidates := []string{}
	if exe, err := os.Executable(); err == nil {
		candidates = append(candidates, filepath.Join(filepath.Dir(exe), "bos"))
	}
	candidates = append(candidates,
		"/opt/bos/bin/bos",
		"/usr/local/bin/bos",
		"/usr/bin/bos",
	)
	if p, err := exec.LookPath("bos"); err == nil {
		candidates = append(candidates, p)
	}

	var daemonBin string
	for _, c := range candidates {
		if info, err := os.Stat(c); err == nil && !info.IsDir() {
			daemonBin = c
			break
		}
	}
	if daemonBin == "" {
		return fmt.Errorf("daemon 'bos' no encontrado\n  Instalar en /usr/local/bin/bos antes de ejecutar bosctl setup\n  Rutas buscadas: %s",
			strings.Join(candidates, ", "))
	}

	// Matar proceso en :9443 SOLO si es el binario "bos".
	if out, err := exec.Command("sh", "-c",
		"ss -tlnp 2>/dev/null | grep ':9443 ' | awk '{print $NF}' | grep -oP 'pid=\\K[0-9]+'").Output(); err == nil {
		if pid := strings.TrimSpace(string(out)); pid != "" {
			if cmdLine, err2 := os.ReadFile("/proc/" + pid + "/comm"); err2 == nil {
				if strings.TrimSpace(string(cmdLine)) == "bos" {
					if kCmd := exec.Command("kill", "-9", pid); kCmd.Run() == nil {
						time.Sleep(500 * time.Millisecond)
					}
				}
			}
		}
	}

	// Crear directorios necesarios (con rollback si falla el arranque).
	dirsToCreate := []string{
		filepath.Dir(socketPath),
		"/var/log/bos",
		"/etc/bos",
		"/etc/bos/blibs",
		"/etc/bos/.kube",
		"/opt/bos/core",
		"/opt/bos/bin",
		"/run/bos",
	}
	var createdDirs []string
	for _, d := range dirsToCreate {
		if _, err := os.Stat(d); os.IsNotExist(err) {
			if err2 := os.MkdirAll(d, 0755); err2 == nil {
				createdDirs = append(createdDirs, d)
			}
		}
	}
	rollback := func() {
		for i := len(createdDirs) - 1; i >= 0; i-- {
			_ = os.Remove(createdDirs[i])
		}
	}

	// Crear bos-install.toml solo si no existe (NUNCA sobreescribir datos de producción).
	installToml := "/etc/bos/bos-install.toml"
	tomlCreated := false
	if _, err := os.Stat(installToml); os.IsNotExist(err) {
		const minimalToml = "# bos-install.toml — generado por bosctl setup\n" +
			"org_name        = \"SBOS-Setup\"\n" +
			"client_domain   = \"setup.local\"\n" +
			"channel         = \"stable\"\n" +
			"servers_path    = \"/etc/bos/blibs/servers\"\n" +
			"core_path       = \"/opt/bos/core\"\n" +
			"state_file      = \"/etc/bos/.sbos_state.json\"\n" +
			"unix_socket     = \"/run/bos/bos.sock\"\n" +
			"kubeconfig_path = \"/etc/bos/.kube/config\"\n"
		if err2 := os.WriteFile(installToml, []byte(minimalToml), 0644); err2 == nil {
			tomlCreated = true
		}
	}

	cmd := exec.Command(daemonBin)
	cmd.Stdin = nil
	cmd.Stdout = nil
	cmd.Stderr = nil
	cmd.Env = append(os.Environ(), "BOS_DEV_SKIP_ROOT=1")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		if tomlCreated {
			_ = os.Remove(installToml)
		}
		rollback()
		return fmt.Errorf("no se pudo arrancar el daemon bos (%s): %w", daemonBin, err)
	}

	// Esperar a que el socket aparezca (máx 15s, polling cada 500ms).
	for i := 0; i < 30; i++ {
		time.Sleep(500 * time.Millisecond)
		if _, err := os.Stat(socketPath); err == nil {
			return nil
		}
	}
	if tomlCreated {
		_ = os.Remove(installToml)
	}
	rollback()
	return fmt.Errorf("daemon bos arrancó (pid %d) pero socket %s no apareció en 15s",
		cmd.Process.Pid, socketPath)
}
