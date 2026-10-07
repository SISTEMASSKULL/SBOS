// Package main — setup.go: punto de entrada de "bosctl setup".
// Solo CLI. Sin TUI, sin dashboard visual. El BOS es un daemon silencioso.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"bos/internal/paths"
)

// cmdSetup es el punto de entrada de "bosctl setup" / "bos install".
// Flujo: system-install → start daemon → deploy seed.
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

	// Si el daemon no está corriendo, ejecutar system-install
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
