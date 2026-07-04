// Package packages implements the unified package manager for SBOS (D2).
//
// Backends: apt (system), pip (python), helm (kubernetes).
// Auto-generates a ficha after every successful install.
package packages

import (
	"fmt"
	"os/exec"
	"strings"
)

// AptAdapter wraps apt-get for system package management.
type AptAdapter struct{}

// NewAptAdapter creates an apt backend adapter.
func NewAptAdapter() *AptAdapter {
	return &AptAdapter{}
}

// Install runs apt-get install -y <pkg>.
func (a *AptAdapter) Install(pkg string) (string, error) {
	cmd := exec.Command("apt-get", "install", "-y", "-q", pkg)
	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))
	if err != nil {
		return output, fmt.Errorf("apt install %s: %w", pkg, err)
	}
	return output, nil
}

// Remove runs apt-get remove -y <pkg>.
func (a *AptAdapter) Remove(pkg string) (string, error) {
	cmd := exec.Command("apt-get", "remove", "-y", "-q", pkg)
	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))
	if err != nil {
		return output, fmt.Errorf("apt remove %s: %w", pkg, err)
	}
	return output, nil
}

// Upgrade runs apt-get install --only-upgrade -y <pkg>.
func (a *AptAdapter) Upgrade(pkg, version string) (string, error) {
	if version != "" {
		pkg = fmt.Sprintf("%s=%s", pkg, version)
	}
	cmd := exec.Command("apt-get", "install", "--only-upgrade", "-y", "-q", pkg)
	out, err := cmd.CombinedOutput()
	output := strings.TrimSpace(string(out))
	if err != nil {
		return output, fmt.Errorf("apt upgrade %s: %w", pkg, err)
	}
	return output, nil
}

// IsInstalled checks whether a package is installed via dpkg-query.
func (a *AptAdapter) IsInstalled(pkg string) bool {
	cmd := exec.Command("dpkg-query", "-W", "-f=${Status}", pkg)
	out, err := cmd.Output()
	if err != nil {
		return false
	}
	return strings.Contains(string(out), "install ok installed")
}

// InstalledVersion returns the installed version of a package.
func (a *AptAdapter) InstalledVersion(pkg string) string {
	cmd := exec.Command("dpkg-query", "-W", "-f=${Version}", pkg)
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

// Name returns the backend identifier.
func (a *AptAdapter) Name() string { return "apt" }
