package domain

import (
	"fmt"

	"bos/internal/installer"
	"bos/internal/plugin"
	"bos/internal/state"
)

// InstallerPort es el puerto que FichaService necesita del instalador.
// Definirlo aquí mantiene la capa de dominio en control de sus dependencias
// (inversión de dependencias — el dominio define la interfaz, la infraestructura la implementa).
type InstallerPort interface {
	Install(fichaID, version string) (*installer.SagaResult, error)
	Update(fichaID, version string) (*installer.SagaResult, error)
	Repair(fichaID string) (*installer.SagaResult, error)
	Remove(fichaID string) (*installer.SagaResult, error)
	Probe(fichaID string) (*installer.SagaResult, error)
}

// StatePort es el puerto al gestor de estado que necesita FichaService.
type StatePort interface {
	Read() (*state.SBOSState, error)
}

// CatalogPort es el puerto al catálogo de fichas (plugin loader).
type CatalogPort interface {
	List() []*plugin.FichaManifest
	Get(id string) (*plugin.FichaManifest, bool)
}

// FichaService contiene la lógica de negocio de las operaciones sobre fichas.
// No importa tipos JSON-RPC, net/http ni encoding/json.
type FichaService struct {
	installer InstallerPort
	state     StatePort
	catalog   CatalogPort
}

// NewFichaService crea el servicio con sus dependencias inyectadas.
func NewFichaService(ins InstallerPort, st StatePort, cat CatalogPort) *FichaService {
	return &FichaService{installer: ins, state: st, catalog: cat}
}

// Install ejecuta la saga de instalación de una ficha.
func (svc *FichaService) Install(fichaID, version string) (*SagaOutcome, error) {
	if fichaID == "" {
		return nil, ErrFichaIDRequired
	}
	if version == "" {
		version = "latest"
	}
	if svc.installer == nil {
		return nil, ErrInstallerUnavailable
	}

	result, err := svc.installer.Install(fichaID, version)
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrSagaFailed, err.Error())
	}
	if !result.Success {
		return nil, &SagaError{
			Command:     "install",
			ExitCode:    result.ExitCode,
			FailedSteps: result.FailedSteps(),
		}
	}
	return &SagaOutcome{
		FichaID:   fichaID,
		Command:   "install",
		Success:   true,
		Duration:  result.Duration,
		StepCount: len(result.Steps),
	}, nil
}

// Update ejecuta la saga de actualización de una ficha.
func (svc *FichaService) Update(fichaID, version string) (*SagaOutcome, error) {
	if fichaID == "" {
		return nil, ErrFichaIDRequired
	}
	if version == "" {
		return nil, ErrVersionRequired
	}
	if svc.installer == nil {
		return nil, ErrInstallerUnavailable
	}

	result, err := svc.installer.Update(fichaID, version)
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrSagaFailed, err.Error())
	}
	if !result.Success {
		return nil, &SagaError{Command: "update", ExitCode: result.ExitCode, FailedSteps: result.FailedSteps()}
	}
	return &SagaOutcome{FichaID: fichaID, Command: "update", Success: true, Duration: result.Duration}, nil
}

// Repair ejecuta la saga de reparación de una ficha.
func (svc *FichaService) Repair(fichaID string) (*SagaOutcome, error) {
	if fichaID == "" {
		return nil, ErrFichaIDRequired
	}
	if svc.installer == nil {
		return nil, ErrInstallerUnavailable
	}

	result, err := svc.installer.Repair(fichaID)
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrSagaFailed, err.Error())
	}
	return &SagaOutcome{FichaID: fichaID, Command: "repair", Success: result.Success, Duration: result.Duration}, nil
}

// Remove ejecuta la saga de desinstalación de una ficha.
func (svc *FichaService) Remove(fichaID string) (*SagaOutcome, error) {
	if fichaID == "" {
		return nil, ErrFichaIDRequired
	}
	if svc.installer == nil {
		return nil, ErrInstallerUnavailable
	}

	result, err := svc.installer.Remove(fichaID)
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrSagaFailed, err.Error())
	}
	return &SagaOutcome{FichaID: fichaID, Command: "remove", Success: result.Success, Duration: result.Duration}, nil
}

// Probe ejecuta un dry-run de la saga de instalación.
func (svc *FichaService) Probe(fichaID string) (*SagaOutcome, error) {
	if fichaID == "" {
		return nil, ErrFichaIDRequired
	}
	if svc.installer == nil {
		return nil, ErrInstallerUnavailable
	}

	result, err := svc.installer.Probe(fichaID)
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrSagaFailed, err.Error())
	}
	return &SagaOutcome{
		FichaID:     fichaID,
		Command:     "probe",
		Success:     result.Success,
		Duration:    result.Duration,
		StepCount:   len(result.Steps),
		FailedSteps: result.FailedSteps(),
	}, nil
}

// Status devuelve el estado de una ficha específica o de todas.
// Si fichaID es vacío, devuelve el mapa completo de fichas.
func (svc *FichaService) Status(fichaID string) (*FichaInfo, map[string]*FichaInfo, error) {
	st, err := svc.state.Read()
	if err != nil {
		return nil, nil, fmt.Errorf("%w: %s", ErrStateUnavailable, err.Error())
	}

	if fichaID != "" {
		f, ok := st.Fichas[fichaID]
		if !ok {
			return nil, nil, fmt.Errorf("%w: %s", ErrFichaNotFound, fichaID)
		}
		return &FichaInfo{
			ID:          fichaID,
			State:       string(f.State),
			Version:     f.Version,
			Health:      f.HealthStatus,
			Server:      f.Server,
			InstalledAt: f.InstalledAt,
			UpdatedAt:   f.UpdatedAt,
		}, nil, nil
	}

	all := make(map[string]*FichaInfo, len(st.Fichas))
	for id, f := range st.Fichas {
		all[id] = &FichaInfo{
			ID:      id,
			State:   string(f.State),
			Version: f.Version,
			Health:  f.HealthStatus,
			Server:  f.Server,
		}
	}
	return nil, all, nil
}

// List devuelve todas las fichas del catálogo con sus metadatos.
func (svc *FichaService) List() []FichaDetail {
	manifests := svc.catalog.List()
	result := make([]FichaDetail, 0, len(manifests))
	for _, m := range manifests {
		result = append(result, FichaDetail{
			FichaInfo: FichaInfo{
				ID:      m.ID,
				Version: m.Version,
				Server:  m.Server,
			},
			AutoInstall:    m.AutoInstall,
			ExecutionOrder: m.ExecutionOrder,
			Dependencies:   m.Dependencies,
		})
	}
	return result
}

// ExecuteSaga despacha cualquier comando saga para una ficha.
// Permite que biedata u otros daemons invoquen operaciones sin conocer cada método.
func (svc *FichaService) ExecuteSaga(fichaID, command, version string) (*SagaOutcome, error) {
	if fichaID == "" {
		return nil, ErrFichaIDRequired
	}
	if command == "" {
		return nil, ErrCommandRequired
	}
	if svc.installer == nil {
		return nil, ErrInstallerUnavailable
	}

	switch command {
	case "install":
		return svc.Install(fichaID, version)
	case "update":
		return svc.Update(fichaID, version)
	case "repair":
		return svc.Repair(fichaID)
	case "remove":
		return svc.Remove(fichaID)
	case "probe":
		return svc.Probe(fichaID)
	default:
		return nil, fmt.Errorf("%w: %s", ErrCommandInvalid, command)
	}
}
