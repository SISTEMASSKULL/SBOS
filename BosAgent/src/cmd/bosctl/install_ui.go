// Package main — setup.go: punto de entrada de "bosctl setup".
// Solo CLI. Sin TUI, sin dashboard visual. El BOS es un daemon silencioso.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
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

		// Detener el daemon si está corriendo antes de limpiar.
		exec.Command("systemctl", "stop", "bos-console.service").Run()
		exec.Command("systemctl", "stop", "bos.service").Run()
		time.Sleep(2 * time.Second)

		// Eliminar socket residual si quedó (daemon puede haber crasheado).
		os.Remove(paths.SocketPath)

		// Limpiar el state file — el deploy del seed restablece los estados correctos.
		if err := os.Remove(paths.StatePath); err != nil && !os.IsNotExist(err) {
			fmt.Fprintf(os.Stderr, "advertencia: no se pudo limpiar state file: %v\n", err)
		}
		fmt.Println("   Estado limpiado — procediendo con instalación limpia.\n")
	}

	// Si el daemon no está corriendo (primera instalación o fue detenido arriba), ejecutar system-install.
	if _, err := os.Stat(paths.SocketPath); os.IsNotExist(err) {
		fmt.Println("Daemon no detectado — ejecutando system-install...")
		if code := cmdSystemInstall([]string{"--mode", *modeFlag}); code != 0 {
			return code
		}
		exec.Command("systemctl", "start", "bos.service").Run()
		for i := 0; i < 30; i++ {
			if _, err := os.Stat(paths.SocketPath); err == nil {
				break
			}
			time.Sleep(1 * time.Second)
		}
	}

	fmt.Printf("bosctl setup — modo declarativo\n")
	fmt.Printf("  seed: %s\n", *seedFile)
	fmt.Printf("  mode: %s\n\n", *modeFlag)
	return cmdDeploy([]string{*seedFile})
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

// cmdDashboard — no implementado. El dashboard del BOS se integra en el proyecto bAuth.
func cmdDashboard(args []string) int {
	fmt.Println("bosctl: dashboard no implementado — el dashboard del BOS se integra en bAuth")
	fmt.Println("Use 'bosctl health' para verificar el estado del daemon.")
	fmt.Println("Use 'bosctl health-report' para un reporte completo.")
	return 0
}
