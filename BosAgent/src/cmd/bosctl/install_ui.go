// Package main — setup.go: punto de entrada de "bosctl setup".
// Solo CLI. Sin TUI, sin dashboard visual. El BOS es un daemon silencioso.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"time"

	"bos/internal/paths"
)

// cmdSetup es el punto de entrada de "bosctl setup" / "bos install".
// Flujo: detectar estado previo → limpiar si hay fallos → system-install → start daemon → deploy seed.
func cmdSetup(args []string) int {
	fs := flag.NewFlagSet("setup", flag.ContinueOnError)
	// Buscar seed en orden: junto al binario → servers/ del paquete → CWD.
	// /proc/self/exe devuelve la ruta real aunque se invoque por symlink.
	defaultSeed := resolveSeedPath()
	seedFile := fs.String("seed", defaultSeed, "archivo seed.yml para instalación declarativa")
	modeFlag := fs.String("mode", "dev", "modo: dev (requisitos no bloquean) | prod (requisitos estrictos)")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if *modeFlag != "dev" && *modeFlag != "prod" {
		fmt.Fprintf(os.Stderr, "bosctl setup: --mode debe ser 'dev' o 'prod' (recibido: %q)\n", *modeFlag)
		return 2
	}

	// Detectar instalaciones fallidas o interrumpidas del intento anterior.
	failedFichas := detectFailedInstall(paths.StatePath)
	if len(failedFichas) > 0 {
		sort.Strings(failedFichas)
		fmt.Println("\n⚠  Instalación anterior incompleta detectada:")
		for _, f := range failedFichas {
			fmt.Printf("   • %s\n", f)
		}
		fmt.Println("   Limpiando estado para reinstalar desde cero...")

		// Detener AMBOS servicios y maskear para prevenir reinicios durante la instalación.
		// bos-console.service (Restart=always, After=bos.service) arranca automáticamente
		// cuando bos.service inicia. Si lo hace, detecta fichas en INSTALLING y borra el
		// token RPC, causando que todas las llamadas JSON-RPC fallen con -32600 Unauthorized.
		exec.Command("systemctl", "stop", "bos-console.service").Run()
		exec.Command("systemctl", "mask", "--runtime", "bos-console.service").Run() // previene arranque automático
		exec.Command("systemctl", "mask", "--runtime", "bos.service").Run()         // previene reinicio automático
		exec.Command("systemctl", "stop", "bos.service").Run()
		time.Sleep(3 * time.Second) // margen para que el daemon libere el socket

		// Eliminar socket residual si quedó (daemon puede haber crasheado).
		os.Remove(paths.SocketPath)

		// Eliminar el token RPC para forzar regeneración por el preflight.
		// Si el token no se regenera, el daemon reiniciado usa el token viejo
		// y el servidor rechaza las llamadas con -32600 Unauthorized.
		os.Remove(paths.RpcTokenFile)

		// Limpiar el state file — el deploy del seed restablece los estados correctos.
		if err := os.Remove(paths.StatePath); err != nil && !os.IsNotExist(err) {
			fmt.Fprintf(os.Stderr, "advertencia: no se pudo limpiar state file: %v\n", err)
		}
		fmt.Println("   Estado limpiado — procediendo con instalación limpia.")
	}

	// Verificar que el daemon RESPONDE, no solo que el socket existe como archivo.
	// Un socket zombie (archivo sin daemon) da "connection refused" en cmdDeploy.
	if !isDaemonAlive(paths.SocketPath) {
		// Limpiar socket fantasma si existe como archivo pero sin daemon.
		if _, err := os.Stat(paths.SocketPath); err == nil {
			fmt.Println("Socket residual detectado — limpiando...")
			os.Remove(paths.SocketPath)
		}
		// Maskear bos-console.service aquí también: puede que no hubo limpieza previa
		// (instalación nueva) pero el console igualmente arrancaría al inicio de bos.service.
		exec.Command("systemctl", "stop", "bos-console.service").Run()
		exec.Command("systemctl", "mask", "--runtime", "bos-console.service").Run()

		fmt.Println("Daemon no disponible — ejecutando system-install...")
		if code := cmdSystemInstall([]string{"--mode", *modeFlag}); code != 0 {
			exec.Command("systemctl", "unmask", "bos-console.service").Run()
			return code
		}
		// Desenmascar bos.service antes de arrancarlo (fue maskeado si hubo limpieza previa).
		exec.Command("systemctl", "unmask", "bos.service").Run()
		exec.Command("systemctl", "start", "bos.service").Run()
		// Esperar hasta que el daemon responda realmente (no solo que el archivo exista).
		fmt.Print("Esperando daemon")
		ready := false
		for i := 0; i < 30; i++ {
			if isDaemonAlive(paths.SocketPath) {
				ready = true
				break
			}
			fmt.Print(".")
			time.Sleep(1 * time.Second)
		}
		if ready {
			fmt.Println(" listo.")
		} else {
			fmt.Println("\nAdvertencia: daemon no respondió en 30s — continuando de todas formas.")
		}
	}

	fmt.Printf("bosctl setup — modo declarativo\n")
	fmt.Printf("  seed: %s\n", *seedFile)
	fmt.Printf("  mode: %s\n\n", *modeFlag)
	result := cmdDeploy([]string{*seedFile})
	// Desmaskear bos-console.service al finalizar el deploy (éxito o fallo).
	// Durante el deploy estuvo maskeado para evitar que destruyera el token RPC.
	exec.Command("systemctl", "unmask", "bos-console.service").Run()
	return result
}

// detectFailedInstall lee el state file y retorna las fichas con estados problemáticos:
// INSTALL_FAILED, UPDATE_FAILED, UNRECOVERABLE (fallos definitivos) e
// INSTALLING/UPDATING/REPAIRING zombie (proceso interrumpido sin completar).
// Retorna nil si no hay state file (instalación nueva) o si todo está OK.
func detectFailedInstall(statePath string) []string {
	data, err := os.ReadFile(statePath)
	if err != nil {
		return nil
	}

	var raw struct {
		Fichas map[string]struct {
			State string `json:"state"`
		} `json:"fichas"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		// State file corrupto — tratar como instalación fallida.
		return []string{"<state file corrupto>"}
	}

	badStates := map[string]bool{
		"INSTALL_FAILED": true,
		"UPDATE_FAILED":  true,
		"UNRECOVERABLE":  true,
		"INSTALLING":     true, // zombie: proceso fue interrumpido
		"UPDATING":       true, // zombie
		"REPAIRING":      true, // zombie
	}

	var failed []string
	for name, ficha := range raw.Fichas {
		if badStates[ficha.State] {
			failed = append(failed, fmt.Sprintf("%s (%s)", name, ficha.State))
		}
	}
	return failed
}

// resolveSeedPath busca seed-skull.yml en orden de precedencia:
// 1. Junto al binario (compatibilidad con paquetes planos)
// 2. En servers/ del mismo directorio (estructura canónica del paquete)
// 3. En /opt/bos-install/servers/ (ubicación canónica de instalación)
// 4. Fallback: "seed-skull.yml" (relativo al CWD)
func resolveSeedPath() string {
	selfDir := ""
	if self, err := os.Executable(); err == nil {
		selfDir = filepath.Dir(self)
	}
	candidates := []string{}
	if selfDir != "" {
		candidates = append(candidates,
			filepath.Join(selfDir, "seed-skull.yml"),
			filepath.Join(selfDir, "servers", "seed-skull.yml"),
		)
	}
	candidates = append(candidates,
		"/opt/bos-install/servers/seed-skull.yml",
		"seed-skull.yml",
	)
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return "seed-skull.yml"
}

// isDaemonAlive verifica que el daemon BOS está corriendo y aceptando conexiones
// intentando abrir el socket Unix. Un archivo de socket sin daemon da "connection refused".
func isDaemonAlive(socketPath string) bool {
	conn, err := net.DialTimeout("unix", socketPath, 2*time.Second)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

// cmdDashboard — no implementado. El dashboard del BOS se integra en el proyecto bAuth.
func cmdDashboard(args []string) int {
	fmt.Println("bosctl: dashboard no implementado — el dashboard del BOS se integra en bAuth")
	fmt.Println("Use 'bosctl health' para verificar el estado del daemon.")
	fmt.Println("Use 'bosctl health-report' para un reporte completo.")
	return 0
}
