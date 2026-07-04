// Subcomandos de gestión de paquetes: bosctl install|remove|upgrade [--backend=apt|pip|helm].
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"

	"bos/internal/packages"
)

const defaultBlibsDir = "/etc/bos/blibs/servers/hostserver"

// cmdPkgInstall instala un paquete (--backend) o una ficha del daemon (sin --backend).
func cmdPkgInstall(args []string) int {
	fs := flag.NewFlagSet("install", flag.ExitOnError)
	backend := fs.String("backend", "", "package backend: apt, pip, helm")
	fs.Parse(args)

	// Scan remaining args for --backend= if flag wasn't parsed (it may appear after the positional pkg name)
	if *backend == "" {
		for _, a := range fs.Args() {
			if strings.HasPrefix(a, "--backend=") {
				*backend = strings.TrimPrefix(a, "--backend=")
				break
			}
		}
	}

	// Extract pkg name: first arg that doesn't look like a flag
	pkg := ""
	extraArgs := make([]string, 0)
	for _, a := range fs.Args() {
		if pkg == "" && !strings.HasPrefix(a, "--") {
			pkg = a
		} else if !strings.HasPrefix(a, "--backend=") {
			extraArgs = append(extraArgs, a)
		}
	}

	if pkg == "" {
		fmt.Fprintln(os.Stderr, "bosctl: install requires a package name (use --backend for packages, or omit for ficha install)")
		return 2
	}

	// Si --backend está presente, enrutar al package manager.
	// Sin --backend, enrutar al instalador de fichas del daemon.
	if *backend != "" {
		return runPkgInstall(pkg, *backend)
	}

	// Sin --backend, es una instalación de ficha vía daemon (comportamiento existente)
	return cmdInstall(extraArgs)
}

// runPkgInstall delega en packages.Manager para instalar pkg con el backend dado y genera ficha.
func runPkgInstall(pkg, backend string) int {
	mgr := packages.NewManager(defaultBlibsDir)

	valid := false
	for _, b := range mgr.BackendNames() {
		if strings.EqualFold(backend, b) {
			valid = true
			break
		}
	}
	if !valid {
		fmt.Fprintf(os.Stderr, "bosctl: install: invalid backend %q (valid: %s)\n",
			backend, strings.Join(mgr.BackendNames(), ", "))
		return 2
	}

	result := mgr.Install(pkg, backend)

	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	enc.Encode(result)

	if !result.Success {
		return 1
	}
	fmt.Printf("ficha auto-generated: %s\n", result.FichaID)
	return 0
}

// cmdRemove desinstala un paquete y elimina su ficha auto-generada.
func cmdRemove(args []string) int {
	fs := flag.NewFlagSet("remove", flag.ExitOnError)
	backend := fs.String("backend", "", "package backend: apt, pip, helm")
	fs.Parse(args)

	if *backend == "" {
		for _, a := range fs.Args() {
			if strings.HasPrefix(a, "--backend=") {
				*backend = strings.TrimPrefix(a, "--backend=")
				break
			}
		}
	}

	pkg := ""
	for _, a := range fs.Args() {
		if pkg == "" && !strings.HasPrefix(a, "--") {
			pkg = a
			break
		}
	}

	if pkg == "" {
		fmt.Fprintln(os.Stderr, "bosctl: remove requires a package name")
		return 2
	}

	mgr := packages.NewManager(defaultBlibsDir)
	be := backendFlag(*backend, pkg, mgr)
	result := mgr.Remove(pkg, be)

	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	enc.Encode(result)

	if !result.Success {
		return 1
	}
	return 0
}

// cmdUpgrade actualiza un paquete a la versión --to=<ver> usando el backend detectado.
func cmdUpgrade(args []string) int {
	fs := flag.NewFlagSet("upgrade", flag.ExitOnError)
	backend := fs.String("backend", "", "package backend: apt, pip, helm")
	toVersion := fs.String("to", "", "target version for upgrade")
	fs.Parse(args)

	if *backend == "" {
		for _, a := range fs.Args() {
			if strings.HasPrefix(a, "--backend=") {
				*backend = strings.TrimPrefix(a, "--backend=")
				break
			}
		}
	}
	if *toVersion == "" {
		for _, a := range fs.Args() {
			if strings.HasPrefix(a, "--to=") {
				*toVersion = strings.TrimPrefix(a, "--to=")
				break
			}
		}
	}

	pkg := ""
	for _, a := range fs.Args() {
		if pkg == "" && !strings.HasPrefix(a, "--") {
			pkg = a
			break
		}
	}

	if pkg == "" {
		fmt.Fprintln(os.Stderr, "bosctl: upgrade requires a package name")
		return 2
	}

	mgr := packages.NewManager(defaultBlibsDir)
	be := backendFlag(*backend, pkg, mgr)
	result := mgr.Upgrade(pkg, *toVersion, be)

	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	enc.Encode(result)

	if !result.Success {
		return 1
	}
	fmt.Printf("upgraded: %s → %s\n", result.OldVersion, result.NewVersion)
	return 0
}

// backendFlag retorna el backend explícito o detecta el correcto para el paquete dado.
func backendFlag(explicit, pkg string, mgr *packages.Manager) string {
	if explicit != "" {
		return explicit
	}
	return mgr.DetectBackend(pkg, "").Name()
}
