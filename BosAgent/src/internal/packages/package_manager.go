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

// Manager orquesta operaciones de paquetes a través de los tres backends: apt, pip, helm.
// Detecta el backend según flags explícitos o heurísticas del nombre del paquete.
//
// Thread safety: seguro para uso concurrente — los backends son stateless o thread-safe.
type Manager struct {
	apt    *AptAdapter
	pip    *PipAdapter
	helm   *HelmAdapter
	fichas *FichaGenerator
}

// NewManager crea un Manager con los tres backends y el generador de fichas.
//
// Recibe:
//   - blibsDir: string — directorio base para fichas auto-generadas. P16.
//
// Callers conocidos:
//   - cmd/bosctl/app.go — subcomando "bosctl app".
func NewManager(blibsDir string) *Manager {
	return &Manager{
		apt:    NewAptAdapter(),
		pip:    NewPipAdapter(),
		helm:   NewHelmAdapter("default"),
		fichas: NewFichaGenerator(blibsDir),
	}
}

// DetectBackend selecciona el backend según flag explícito o heurística del nombre del paquete.
//
// Recibe:
//   - pkg: string — nombre del paquete.
//   - explicit: string — "apt" | "pip" | "helm" | "" (auto-detect).
//
// Retorna: Backend seleccionado (nunca nil).
//
// Heurística: "/" en nombre → helm; prefijo "python-"/"python3-" → pip; resto → apt.
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

// InstallResult contiene el resultado de una operación de instalación de paquete.
type InstallResult struct {
	Package string `json:"package"`
	Backend string `json:"backend"`
	Version string `json:"version"`
	FichaID string `json:"ficha_id"`
	Output  string `json:"output"`
	Success bool   `json:"success"`
	Error   string `json:"error,omitempty"`
}

// Install instala el paquete, genera su ficha auto-gestionada y la registra en el STATE_MANAGER.
//
// Recibe:
//   - pkg: string — nombre del paquete.
//   - backendFlag: string — fuerza backend ("apt"/"pip"/"helm"). Vacío = auto-detect.
//
// Retorna: *InstallResult con Backend, Version, FichaID y detalles del output.
//
// Efectos secundarios:
//   - Invoca apt-get/pip3/helm install (requiere permisos).
//   - Crea ficha en blibsDir y registra en .sbos_state.json.
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

// RemoveResult contiene el resultado de una operación de desinstalación de paquete.
type RemoveResult struct {
	Package string `json:"package"`
	Backend string `json:"backend"`
	Output  string `json:"output"`
	Success bool   `json:"success"`
	Error   string `json:"error,omitempty"`
}

// Remove desinstala el paquete y elimina su ficha auto-generada.
//
// Efectos secundarios:
//   - Invoca apt-get remove / pip3 uninstall / helm uninstall.
//   - Elimina el directorio de ficha en blibsDir.
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

// UpgradeResult contiene el resultado de una operación de actualización de paquete.
type UpgradeResult struct {
	Package    string `json:"package"`
	Backend    string `json:"backend"`
	OldVersion string `json:"old_version"`
	NewVersion string `json:"new_version"`
	Output     string `json:"output"`
	Success    bool   `json:"success"`
	Error      string `json:"error,omitempty"`
}

// Upgrade actualiza el paquete a la versión especificada.
//
// Efectos secundarios: invoca apt-get install --only-upgrade / pip3 install --upgrade / helm upgrade.
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

// BackendNames retorna los identificadores de los tres backends disponibles.
func (m *Manager) BackendNames() []string {
	return []string{"apt", "pip", "helm"}
}
