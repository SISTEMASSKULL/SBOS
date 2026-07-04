// Subcomandos del catálogo de fichas (bosctl app list|history|rollback).
package main

import (
	"fmt"
	"os"
	"strings"

	"bos/internal/catalog"
	"bos/internal/state"
	"bos/internal/paths"
)

const statePath = paths.StatePath

// cmdApp es el dispatcher del subcomando "bosctl app" (list | history | rollback).
func cmdApp(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Usage: bosctl app <list|history|rollback> [args...]")
		return 1
	}

	switch args[0] {
	case "list":
		return cmdAppList(args[1:])
	case "history":
		return cmdAppHistory(args[1:])
	case "rollback":
		return cmdAppRollback(args[1:])
	default:
		fmt.Fprintf(os.Stderr, "bosctl app: unknown subcommand: %s\n", args[0])
		fmt.Fprintln(os.Stderr, "  Available: list, history, rollback")
		return 1
	}
}

// cmdAppList lista todas las fichas instaladas agrupadas por categoría con ícono de estado.
func cmdAppList(args []string) int {
	mgr, err := state.NewManager(statePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl app list: open state: %v\n", err)
		return 1
	}
	defer mgr.Close()

	cat := catalog.New(mgr)
	groups, err := cat.List()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl app list: %v\n", err)
		return 1
	}

	if len(groups) == 0 {
		fmt.Println("(no fichas registered)")
		return 0
	}

	for _, g := range groups {
		fmt.Printf("\n%s [%s]\n", headerSep(g.CategoryName), categoryBar)
		for _, f := range g.Fichas {
			icon := stateToIcon(f.State)
			backend := f.Backend
			if backend == "" {
				backend = "-"
			}
			fmt.Printf("  %s %-45s %-12s %-8s  backend=%-5s\n",
				icon, f.Name, f.Version, f.State, backend)
		}
	}
	fmt.Println()
	return 0
}

// cmdAppHistory muestra el historial de snapshots de una ficha (timestamp, versión, ID).
func cmdAppHistory(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Usage: bosctl app history <ficha-id>")
		return 1
	}
	fichaID := args[0]

	snapshots, err := catalog.ListSnapshots(fichaID)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl app history: %v\n", err)
		return 1
	}

	if len(snapshots) == 0 {
		fmt.Printf("(no snapshots for %s)\n", fichaID)
		return 0
	}

	fmt.Printf("\nSnapshots for %s:\n", fichaID)
	fmt.Println(strings.Repeat("-", 70))
	for _, s := range snapshots {
		fmt.Printf("  %s  %-8s  %s\n",
			s.Timestamp.Format("2006-01-02 15:04:05"), s.Version, s.ID)
	}
	fmt.Println()
	return 0
}

// cmdAppRollback hace rollback de una ficha a una versión anterior (--to=<ver>).
// Crea un snapshot previo antes de ejecutar el rollback.
func cmdAppRollback(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Usage: bosctl app rollback <ficha-id> --to=<version>")
		return 1
	}
	fichaID := args[0]
	targetVersion := ""
	for _, a := range args[1:] {
		if strings.HasPrefix(a, "--to=") {
			targetVersion = strings.TrimPrefix(a, "--to=")
		}
	}

	mgr, err := state.NewManager(statePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl app rollback: open state: %v\n", err)
		return 1
	}
	defer mgr.Close()

	// Create pre-rollback snapshot
	snap, err := catalog.CreateSnapshot(mgr, fichaID)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl app rollback: snapshot: %v\n", err)
		return 1
	}
	fmt.Printf("Pre-rollback snapshot: %s\n", snap.ID)

	if err := catalog.Rollback(mgr, fichaID, targetVersion); err != nil {
		fmt.Fprintf(os.Stderr, "bosctl app rollback: %v\n", err)
		return 1
	}

	fmt.Printf("Rollback of %s completed.\n", fichaID)
	return 0
}

const categoryBar = "========================================"

var headerSep = func(s string) string { return s }

// stateToIcon convierte un estado de ficha (ADR-021) a un ícono ASCII de 4 caracteres para la TUI.
func stateToIcon(state string) string {
	switch state {
	case "INSTALADA", "INSTALADA -- OK":
		return "[OK]"
	case "DEGRADADA", "INSTALADA -- ALERTA":
		return "[!!]"
	case "INSTALANDO", "ACTUALIZANDO", "REPARANDO":
		return "[>>]"
	case "ACTUALIZACION_DISPONIBLE":
		return "[UP]"
	case "PENDIENTE", "LISTA":
		return "[--]"
	case "FALLA_INSTALACION", "FALLA_ACTUALIZACION", "ERROR_LOGICO", "ERROR_FISICO":
		return "[ER]"
	case "DESINSTALADA":
		return "[  ]"
	default:
		return "[??]"
	}
}
