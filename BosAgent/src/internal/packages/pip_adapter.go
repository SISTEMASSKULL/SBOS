package packages

import (
	"fmt"
	"os/exec"
	"strings"
)

// PipAdapter envuelve pip3 para gestión de paquetes Python.
//
// Thread safety: stateless — seguro para uso concurrente.
type PipAdapter struct{}

// NewPipAdapter crea un adaptador pip3.
func NewPipAdapter() *PipAdapter {
	return &PipAdapter{}
}

// Install ejecuta pip3 install <pkg> en el sistema.
// Efectos secundarios: instala el paquete Python en el entorno activo.
func (p *PipAdapter) Install(pkg string) (string, error) {
	cmd := exec.Command("pip3", "install", pkg)
	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))
	if err != nil {
		return output, fmt.Errorf("pip install %s: %w", pkg, err)
	}
	return output, nil
}

// Remove ejecuta pip3 uninstall -y <pkg>.
// Efectos secundarios: elimina el paquete Python del entorno activo.
func (p *PipAdapter) Remove(pkg string) (string, error) {
	cmd := exec.Command("pip3", "uninstall", "-y", pkg)
	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))
	if err != nil {
		return output, fmt.Errorf("pip uninstall %s: %w", pkg, err)
	}
	return output, nil
}

// Upgrade ejecuta pip3 install --upgrade (o ==version si se especifica).
func (p *PipAdapter) Upgrade(pkg, version string) (string, error) {
	target := pkg
	if version != "" {
		target = fmt.Sprintf("%s==%s", pkg, version)
	}
	cmd := exec.Command("pip3", "install", "--upgrade", target)
	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))
	if err != nil {
		return output, fmt.Errorf("pip upgrade %s: %w", pkg, err)
	}
	return output, nil
}

// IsInstalled verifica si el paquete Python está instalado via pip3 show.
func (p *PipAdapter) IsInstalled(pkg string) bool {
	cmd := exec.Command("pip3", "show", pkg)
	return cmd.Run() == nil
}

// InstalledVersion retorna la versión instalada del paquete, o "" si no está instalado.
func (p *PipAdapter) InstalledVersion(pkg string) string {
	cmd := exec.Command("pip3", "show", pkg)
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(out), "\n") {
		if strings.HasPrefix(line, "Version: ") {
			return strings.TrimPrefix(line, "Version: ")
		}
	}
	return ""
}

// Name retorna el identificador del backend pip.
func (p *PipAdapter) Name() string { return "pip" }
