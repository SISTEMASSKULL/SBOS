// Package main — setup.go: punto de entrada de "bosctl setup".
// Solo CLI. Sin TUI, sin dashboard visual. El BOS es un daemon silencioso.
package main

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"time"

	"bos/internal/paths"
)

// cmdSetup es el punto de entrada de "bosctl setup".
// Flujo: validar bos-install.toml → detectar estado previo → limpiar si hay fallos →
//
//	system-install → start daemon → deploy seed.
func cmdSetup(args []string) int {
	// PASO 0: Validar bos-install.toml ANTES de tocar el sistema.
	// Si la configuración es inválida o incompleta, el instalador termina aquí con
	// mensajes descriptivos de qué corregir. Nunca arranca una instalación de ~48 min
	// con datos que sabemos que van a fallar al final.
	if _, err := validateInstallToml(); err != nil {
		fmt.Fprintf(os.Stderr, "\n%v\n", err)
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

		// Detener y maskear bos.service para prevenir reinicios durante la instalación.
		exec.Command("systemctl", "mask", "--runtime", "bos.service").Run()
		exec.Command("systemctl", "stop", "bos.service").Run()
		time.Sleep(3 * time.Second) // margen para que el daemon libere el socket

		// Eliminar socket residual si quedó (daemon puede haber crasheado).
		os.Remove(paths.SocketPath)

		// Eliminar el token RPC para forzar regeneración por el preflight.
		// Si el token no se regenera, el daemon reiniciado usa el token viejo
		// y el servidor rechaza las llamadas con -32600 Unauthorized.
		os.Remove(paths.RpcTokenFile)

		// P15 — idempotencia: resetear SOLO las fichas fallidas a PENDING.
		// Las fichas en estado INSTALLED se preservan — no se reinstalan si ya están operativas.
		// Borrar el state completo viola P15: fuerza reinstalación de vault/keycloak/postgresql
		// aunque sus pods estén Running 1/1 y saludables.
		if err := resetFailedFichas(paths.StatePath); err != nil {
			fmt.Fprintf(os.Stderr, "advertencia: no se pudo resetear fichas fallidas: %v\n", err)
		}
		fmt.Println("   Fichas fallidas reseteadas a PENDING — fichas INSTALLED preservadas (P15).")
	}

	// Verificar que el daemon RESPONDE, no solo que el socket existe como archivo.
	// Un socket zombie (archivo sin daemon) da "connection refused" en cmdDeploy.
	if !isDaemonAlive(paths.SocketPath) {
		// Limpiar socket fantasma si existe como archivo pero sin daemon.
		if _, err := os.Stat(paths.SocketPath); err == nil {
			fmt.Println("Socket residual detectado — limpiando...")
			os.Remove(paths.SocketPath)
		}
		fmt.Println("Daemon no disponible — ejecutando system-install...")
		if code := cmdSystemInstall(nil); code != 0 {
			return code
		}
		// Desenmascar bos.service antes de arrancarlo.
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

	seedFile := resolveSeedPath()
	fmt.Printf("bosctl setup — modo declarativo\n")
	fmt.Printf("  seed: %s\n\n", seedFile)
	return cmdDeploy([]string{seedFile})
}

// resetFailedFichas reescribe el state file reseteando SOLO las fichas con estados problemáticos
// a PENDING para reintentar. Las fichas en estado INSTALLED se preservan sin cambios (P15).
// Si el state file no existe o está corrupto, lo elimina completo para empezar limpio.
func resetFailedFichas(statePath string) error {
	data, err := os.ReadFile(statePath)
	if err != nil {
		return nil // no existe — ok, instalación nueva
	}

	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return os.Remove(statePath) // corrupto — eliminar
	}

	fichasRaw, ok := raw["fichas"]
	if !ok {
		return nil
	}

	var fichas map[string]json.RawMessage
	if err := json.Unmarshal(fichasRaw, &fichas); err != nil {
		return os.Remove(statePath)
	}

	// Estados problemáticos que se resetean a PENDING para reintentar.
	// INSTALLED y otros estados estables se preservan (P15: no tocar lo que funciona).
	resetStates := map[string]bool{
		"INSTALL_FAILED": true,
		"UPDATE_FAILED":  true,
		"UNRECOVERABLE":  true,
		"INSTALLING":     true, // zombie: daemon fue interrumpido
		"UPDATING":       true, // zombie
		"REPAIRING":      true, // zombie
		"ROLLBACK":       true, // zombie
		"CLEANUP":        true, // zombie
	}

	changed := false
	for name, fichaJSON := range fichas {
		var ficha struct {
			State string `json:"state"`
		}
		if err := json.Unmarshal(fichaJSON, &ficha); err != nil {
			continue
		}
		if !resetStates[ficha.State] {
			continue // INSTALLED, READY, PENDING, etc. — preservar sin cambios
		}
		var fichaMap map[string]interface{}
		if err := json.Unmarshal(fichaJSON, &fichaMap); err != nil {
			continue
		}
		fichaMap["state"] = "PENDING"
		newJSON, err := json.Marshal(fichaMap)
		if err != nil {
			continue
		}
		fichas[name] = newJSON
		fmt.Printf("   • %s: %s → PENDING\n", name, ficha.State)
		changed = true
	}

	if !changed {
		return nil
	}

	fichasJSON, err := json.Marshal(fichas)
	if err != nil {
		return err
	}
	raw["fichas"] = fichasJSON

	newData, err := json.MarshalIndent(raw, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(statePath, newData, 0600)
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
