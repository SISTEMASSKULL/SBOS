package packages

import (
	"fmt"
	"strings"

	"bos/internal/state"
)

// Backend defines the contract for a package manager backend.
type Backend interface {
	Install(pkg string) (string, error)
	Remove(pkg string) (string, error)
	Upgrade(pkg, version string) (string, error)
	IsInstalled(pkg string) bool
	InstalledVersion(pkg string) string
	Name() string
}

// Manager orchestrates package operations across backends.
// Detects the backend based on explicit flags or package name heuristics.
type Manager struct {
	apt      *AptAdapter
	pip      *PipAdapter
	helm     *HelmAdapter
	fichas   *FichaGenerator
}

// NewManager creates a package manager with all backends.
func NewManager(blibsDir string) *Manager {
	return &Manager{
		apt:      NewAptAdapter(),
		pip:      NewPipAdapter(),
		helm:     NewHelmAdapter("default"),
		fichas:   NewFichaGenerator(blibsDir),
	}
}

// DetectBackend selects the backend based on an explicit flag or heuristic.
// Heuristic: packages containing "/" → helm, packages with "python-" prefix
// or containing "pip" → pip, everything else → apt.
func (m *Manager) DetectBackend(pkg, explicit string) Backend {
	switch strings.ToLower(explicit) {
	case "apt":
		return m.apt
	case "pip":
		return m.pip
	case "helm":
		return m.helm
	}

	if strings.Contains(pkg, "/") {
		return m.helm
	}
	if strings.HasPrefix(pkg, "python-") || strings.HasPrefix(pkg, "python3-") {
		return m.pip
	}

	return m.apt
}

// InstallResult holds the outcome of a package install operation.
type InstallResult struct {
	Package  string `json:"package"`
	Backend  string `json:"backend"`
	Version  string `json:"version"`
	FichaID  string `json:"ficha_id"`
	Output   string `json:"output"`
	Success  bool   `json:"success"`
	Error    string `json:"error,omitempty"`
}

// Install runs the install operation on the appropriate backend and generates a ficha.
func (m *Manager) Install(pkg, backendFlag string) *InstallResult {
	result := &InstallResult{Package: pkg}
	be := m.DetectBackend(pkg, backendFlag)
	result.Backend = be.Name()

	output, err := be.Install(pkg)
	result.Output = output
	if err != nil {
		result.Success = false
		result.Error = err.Error()
		return result
	}

	version := be.InstalledVersion(pkg)
	result.Version = version

	fichaID, _, fichaErr := m.fichas.Generate(pkg, version, be.Name())
	if fichaErr != nil {
		result.Success = false
		result.Error = fmt.Sprintf("package installed but ficha generation failed: %v", fichaErr)
		return result
	}

	result.FichaID = fichaID
	result.Success = true

	// Persist backend to state file for immediate availability (reload-safe via meta.backend in manifest).
	if sm, err := state.NewManager("/etc/bos/.sbos_state.json"); err == nil {
		_ = sm.Register(fichaID, state.StateLista, version, false, "hostserver", 4, be.Name())
		sm.Close()
	}

	return result
}

// RemoveResult holds the outcome of a package remove operation.
type RemoveResult struct {
	Package  string `json:"package"`
	Backend  string `json:"backend"`
	Output   string `json:"output"`
	Success  bool   `json:"success"`
	Error    string `json:"error,omitempty"`
}

// Remove runs the remove operation and deletes the auto-generated ficha.
func (m *Manager) Remove(pkg, backendFlag string) *RemoveResult {
	result := &RemoveResult{Package: pkg}
	be := m.DetectBackend(pkg, backendFlag)
	result.Backend = be.Name()

	output, err := be.Remove(pkg)
	result.Output = output
	if err != nil {
		result.Success = false
		result.Error = err.Error()
		return result
	}

	fichaID := fmt.Sprintf("sbos-app-%s", sanitizeFichaName(pkg))
	if rmErr := m.fichas.RemoveFicha(fichaID); rmErr != nil {
		result.Output += "\n" + rmErr.Error()
	}

	result.Success = true
	return result
}

// UpgradeResult holds the outcome of a package upgrade operation.
type UpgradeResult struct {
	Package    string `json:"package"`
	Backend    string `json:"backend"`
	OldVersion string `json:"old_version"`
	NewVersion string `json:"new_version"`
	Output     string `json:"output"`
	Success    bool   `json:"success"`
	Error      string `json:"error,omitempty"`
}

// Upgrade runs the upgrade operation and updates the ficha version.
func (m *Manager) Upgrade(pkg, version, backendFlag string) *UpgradeResult {
	result := &UpgradeResult{Package: pkg}
	be := m.DetectBackend(pkg, backendFlag)
	result.Backend = be.Name()
	result.OldVersion = be.InstalledVersion(pkg)

	output, err := be.Upgrade(pkg, version)
	result.Output = output
	if err != nil {
		result.Success = false
		result.Error = err.Error()
		return result
	}

	result.NewVersion = be.InstalledVersion(pkg)
	result.Success = true
	return result
}

// BackendNames returns the available backend identifiers.
func (m *Manager) BackendNames() []string {
	return []string{"apt", "pip", "helm"}
}
