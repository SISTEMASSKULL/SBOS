package packages

import (
	"fmt"
	"os/exec"
	"strings"
)

// PipAdapter wraps pip3 for Python package management.
type PipAdapter struct{}

// NewPipAdapter creates a pip backend adapter.
func NewPipAdapter() *PipAdapter {
	return &PipAdapter{}
}

// Install runs pip3 install <pkg>.
func (p *PipAdapter) Install(pkg string) (string, error) {
	cmd := exec.Command("pip3", "install", pkg)
	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))
	if err != nil {
		return output, fmt.Errorf("pip install %s: %w", pkg, err)
	}
	return output, nil
}

// Remove runs pip3 uninstall -y <pkg>.
func (p *PipAdapter) Remove(pkg string) (string, error) {
	cmd := exec.Command("pip3", "uninstall", "-y", pkg)
	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))
	if err != nil {
		return output, fmt.Errorf("pip uninstall %s: %w", pkg, err)
	}
	return output, nil
}

// Upgrade runs pip3 install --upgrade <pkg>.
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

// IsInstalled checks whether a Python package is installed.
func (p *PipAdapter) IsInstalled(pkg string) bool {
	cmd := exec.Command("pip3", "show", pkg)
	return cmd.Run() == nil
}

// InstalledVersion returns the installed version of a Python package.
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

// Name returns the backend identifier.
func (p *PipAdapter) Name() string { return "pip" }
