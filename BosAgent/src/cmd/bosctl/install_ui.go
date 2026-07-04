// Package main — install_ui.go: punto de entrada de "bosctl setup" y "bosctl dashboard".
// La lógica TUI vive en internal/tui/app/ y internal/tui/model/.
// Migrado de install_ui_impl.go en BOS-REPAIR F3.MIGRATE.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"bos/internal/tui/app"
	"bos/internal/paths"
	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/styles"

	tea "github.com/charmbracelet/bubbletea"
)

// cmdInstallUI es el punto de entrada de "bosctl setup".
func cmdInstallUI(args []string) int {
	fs := flag.NewFlagSet("setup", flag.ContinueOnError)
	tuiFlag := fs.Bool("tui", false, "modo interactivo TUI (wizard visual)")
	defaultSeed := "seed-skull.yml"
	if self, err := os.Executable(); err == nil {
		defaultSeed = filepath.Join(filepath.Dir(self), "seed-skull.yml")
	}
	seedFile := fs.String("seed", defaultSeed, "archivo seed.yml para instalación declarativa")
	modeFlag := fs.String("mode", "dev", "modo: dev (requisitos no bloquean) | prod (requisitos estrictos)")
	themeFlag := fs.String("theme", "", "tema visual TUI: abyss (default) | obsidian | pizarron | esmeralda")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if *modeFlag != "dev" && *modeFlag != "prod" {
		fmt.Fprintf(os.Stderr, "bosctl setup: --mode debe ser 'dev' o 'prod' (recibido: %q)\n", *modeFlag)
		return 2
	}

	// Modo TUI: wizard interactivo con Bubble Tea
	if *tuiFlag {
		styles.ApplyTheme(resolveTheme(*themeFlag))
		cfg := tuimodel.Config{
			SocketPath:  defaultSocket,
			DemoMode:    false,
			InstallMode: *modeFlag,
		}
		return runInteractiveTUI(cfg)
	}

		// Pre-flight: si el daemon no está corriendo, ejecutar system-install
		if _, err := os.Stat(paths.SocketPath); os.IsNotExist(err) {
			fmt.Println("🔧 Daemon no detectado — ejecutando system-install...")
			if code := cmdSystemInstall([]string{"--mode", *modeFlag}); code != 0 {
				return code
			}
			// Arrancar el daemon (system-install solo hace enable)
			exec.Command("systemctl", "start", "bos.service").Run()
			// Esperar a que el daemon cree el socket (máx 30s)
			for i := 0; i < 30; i++ {
				if _, err := os.Stat(paths.SocketPath); err == nil {
					break
				}
				time.Sleep(1 * time.Second)
			}
		}

	// Modo CLI (default): instalación declarativa vía seed.yml
	fmt.Printf("bosctl setup (CLI) — modo declarativo\n")
	fmt.Printf("  seed: %s\n", *seedFile)
	fmt.Printf("  mode: %s\n\n", *modeFlag)
	return cmdDeploy([]string{*seedFile})
}

// runInteractiveTUI inicializa el App BubbleTea y arranca la TUI de instalación.
// Abre /dev/tty si stdin no es un TTY (tmux-safe).
func runInteractiveTUI(cfg tuimodel.Config) int {
	a := app.New(cfg, tuimodel.SeedData{})

	tty, cleanup := openTTY()
	defer cleanup()

	p := tea.NewProgram(a,
		tea.WithInput(tty),
		tea.WithOutput(os.Stdout),
		tea.WithAltScreen(),
	)
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "bosctl setup: %v\n", err)
		return 1
	}
	return 0
}

// cmdDashboard abre el dashboard pasando por la secuencia de boot.
// ScreenBoot → ScreenDashboard garantiza el mismo flujo que después de un reinicio.
func cmdDashboard(args []string) int {
	fs := flag.NewFlagSet("dashboard", flag.ContinueOnError)
	themeFlag := fs.String("theme", "", "tema visual: abyss (default) | obsidian | pizarron | esmeralda | indigo | fuchsia | ambar")
	_ = fs.Parse(args)

	styles.ApplyTheme(resolveTheme(*themeFlag))

	cfg := tuimodel.Config{SocketPath: defaultSocket}
	a := app.New(cfg, tuimodel.SeedData{})
	// Forzar pantalla de boot (el sistema ya está instalado)
	a.SetInstalledBoot()

	tty, cleanup := openTTY()
	defer cleanup()

	p := tea.NewProgram(a,
		tea.WithInput(tty),
		tea.WithOutput(os.Stdout),
		tea.WithAltScreen(),
	)
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "bosctl dashboard: %v\n", err)
		return 1
	}
	return 0
}

// resolveTheme devuelve el ID de tema a aplicar según prioridad:
// flag CLI > variable de entorno SBOS_TUI_THEME > abyss (default).
func resolveTheme(flagVal string) string {
	if flagVal != "" {
		return flagVal
	}
	if env := os.Getenv("SBOS_TUI_THEME"); env != "" {
		return env
	}
	return "abyss"
}

// openTTY abre /dev/tty si stdin no es TTY; retorna el archivo y una función de cierre.
func openTTY() (*os.File, func()) {
	if st, err := os.Stdin.Stat(); err == nil && (st.Mode()&os.ModeCharDevice) != 0 {
		return os.Stdin, func() {}
	}
	tty, err := os.OpenFile("/dev/tty", os.O_RDWR, 0)
	if err != nil {
		return os.Stdin, func() {}
	}
	return tty, func() { tty.Close() }
}
