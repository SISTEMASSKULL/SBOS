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

// cmdSetup es el punto de entrada de "bosctl setup".
// Flujo: system-install → start daemon → deploy seed.
func cmdSetup(args []string) int {
	fs := flag.NewFlagSet("setup", flag.ContinueOnError)
	defaultSeed := "seed-skull.yml"
	if self, err := os.Executable(); err == nil {
		defaultSeed = filepath.Join(filepath.Dir(self), "seed-skull.yml")
	}
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

// cmdDashboard — no implementado. El dashboard del BOS se integra en el proyecto bAuth.
func cmdDashboard(args []string) int {
	fmt.Println("bosctl: dashboard no implementado — el dashboard del BOS se integra en bAuth")
	fmt.Println("Use 'bosctl health' para verificar el estado del daemon.")
	fmt.Println("Use 'bosctl health-report' para un reporte completo.")
	return 0
}
