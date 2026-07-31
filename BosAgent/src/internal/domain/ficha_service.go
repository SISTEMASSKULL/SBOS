package domain

import (
	"fmt"
	"os"
	"path/filepath"

	"bos/internal/ficha"
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
	Transition(fichaID string, to state.FichaState) error
}

// CatalogPort es el puerto al catálogo de fichas (plugin loader).
type CatalogPort interface {
	List() []*plugin.FichaManifest
	Get(id string) (*plugin.FichaManifest, bool)
	Count() int
	Reload() int
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

// List devuelve todas las fichas del catálogo con metadatos de manifest Y estado real
// del state manager (actualizado por K8sDiscovery en cada ciclo de reconciliación).
func (svc *FichaService) List() []FichaDetail {
	manifests := svc.catalog.List()

	// Leer estado del state manager; ignorar error — puede estar vacío en bootstrap.
	st, _ := svc.state.Read()

	result := make([]FichaDetail, 0, len(manifests))
	for _, m := range manifests {
		detail := FichaDetail{
			FichaInfo: FichaInfo{
				ID:      m.ID,
				Version: m.Version,
				Server:  m.Server,
			},
			AutoInstall:    m.AutoInstall,
			ExecutionOrder: m.ExecutionOrder,
			Dependencies:   m.Dependencies,
		}
		// Enriquecer con estado real si el state manager lo conoce.
		if st != nil {
			if f, ok := st.Fichas[m.ID]; ok {
				detail.State       = string(f.State)
				detail.Health      = f.HealthStatus
				detail.InstalledAt = f.InstalledAt
				detail.UpdatedAt   = f.UpdatedAt
			}
		}
		result = append(result, detail)
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

// ── F11 — Métodos nuevos del Ficha Engine v2 ────────────────────────

// K8sPort es el puerto que FichaService necesita para operaciones K8s (scale).
type K8sPort interface {
	ScaleDeployment(fichaID string, replicas int32) (int32, error)
	GetReplicas(fichaID string) (int32, error)
}

// LogPort es el puerto para leer logs de ficha desde disco.
type LogPort interface {
	ReadLog(fichaID string, tailLines int32) ([]LogEntry, error)
	FollowLog(fichaID string) (<-chan LogEntry, error)
}

// Plan retorna el plan topológico de instalación para las fichas del catálogo.
func (svc *FichaService) Plan() (*PlanResult, error) {
	if svc.catalog == nil {
		return nil, ErrStateUnavailable
	}

	// F11.A.3: usar el resolver real (Kahn + oleadas)
	manifests := svc.catalog.List()
	if len(manifests) == 0 {
		return &PlanResult{Order: nil, Waves: nil, Total: 0, HasCycles: false}, nil
	}

	plan, err := ficha.Resolver(manifests)
	if err != nil {
		// Si hay ciclos, retornar el plan con HasCycles=true
		if plan != nil && plan.Cycles {
			return &PlanResult{
				Order:     nil,
				Waves:     nil,
				Total:     plan.Total,
				HasCycles: true,
			}, fmt.Errorf("%w: %w", ErrFichaPlanFailed, err)
		}
		return nil, fmt.Errorf("%w: %w", ErrFichaPlanFailed, err)
	}

	waves := make([][]string, len(plan.Waves))
	for i, w := range plan.Waves {
		waves[i] = w
	}

	return &PlanResult{
		Order:     plan.Order,
		Waves:     waves,
		Total:     plan.Total,
		HasCycles: false,
	}, nil
}

// Diff compara el estado declarado (hashes de manifest scan) con el estado real en disco (F11.D.2).
// Retorna (resultado individual, nil, nil) o (nil, resumen, nil) según fichaID.
func (svc *FichaService) Diff(fichaID string) (*DiffResult, *DiffSummary, error) {
	if fichaID == "" {
		manifests := svc.catalog.List()
		summary := &DiffSummary{
			TotalFichas: len(manifests),
			Drifts:      make([]DiffResult, 0, len(manifests)),
		}
		for _, mf := range manifests {
			items := diffFichaFiles(mf)
			dr := DiffResult{
				FichaID:  mf.ID,
				HasDrift: len(items) > 0,
				Items:    items,
			}
			summary.Drifts = append(summary.Drifts, dr)
			if dr.HasDrift {
				summary.DriftedFichas++
			} else {
				summary.OkFichas++
			}
		}
		return nil, summary, nil
	}

	mf, ok := svc.catalog.Get(fichaID)
	if !ok {
		return nil, nil, fmt.Errorf("%w: %s", ErrFichaNotFound, fichaID)
	}

	items := diffFichaFiles(mf)
	return &DiffResult{
		FichaID:  fichaID,
		HasDrift: len(items) > 0,
		Items:    items,
	}, nil, nil
}

// diffFichaFiles compara los hashes conocidos de mf.Files contra el estado actual en disco.
// Si mf.Path == "" o Files está vacío (stubs de test), retorna nil (sin drift detectable).
func diffFichaFiles(mf *plugin.FichaManifest) []DriftItem {
	if mf.Path == "" || len(mf.Files) == 0 {
		return nil
	}
	detector := ficha.NewDriftDetector(mf.Path, nil)
	report, err := detector.Detect(mf.ID, mf.Path, mf.Files)
	if err != nil || report == nil {
		return nil
	}
	items := make([]DriftItem, 0)
	for _, item := range report.Items {
		if item.Status == ficha.DriftOK {
			continue
		}
		items = append(items, DriftItem{
			Path:     item.Path,
			Declared: item.Declared,
			Actual:   item.Actual,
		})
	}
	return items
}

// Validate ejecuta validación estricta del manifest de una ficha (o todas).
func (svc *FichaService) Validate(fichaID string) ([]ValidationResult, error) {
	if fichaID != "" {
		mf, ok := svc.catalog.Get(fichaID)
		if !ok {
			return nil, fmt.Errorf("%w: %s", ErrFichaNotFound, fichaID)
		}

		errors := validateManifestStrict(mf)
		return []ValidationResult{{
			FichaID: fichaID,
			Valid:   len(errors) == 0,
			Errors:  errors,
		}}, nil
	}

	// Validar todas las fichas del catálogo
	manifests := svc.catalog.List()
	results := make([]ValidationResult, 0, len(manifests))
	for _, mf := range manifests {
		errs := validateManifestStrict(mf)
		results = append(results, ValidationResult{
			FichaID: mf.ID,
			Valid:   len(errs) == 0,
			Errors:  errs,
		})
	}
	return results, nil
}

// validateManifestStrict aplica las reglas de validación SOV y SAN-10 al manifest (F11.A.2).
//
// Si la ficha tiene ruta en disco (Path != ""), lee manifest.yml y aplica
// ficha.ParseManifestStrict (YAML + allowlist SAN-10 + dashboard.json + licencia).
// Si la ruta no está disponible (stubs de test, fichas en memoria), valida los campos
// básicos del struct directamente.
func validateManifestStrict(mf interface{}) []ValidationErrorItem {
	fm, ok := mf.(*plugin.FichaManifest)
	if !ok || fm == nil {
		return nil
	}

	if fm.Path != "" {
		manifestPath := filepath.Join(fm.Path, "manifest.yml")
		if content, err := os.ReadFile(manifestPath); err == nil {
			return parseResultToItems(ficha.ParseManifestStrict(string(content), fm.Path))
		}
	}

	// Fallback: validación estructural desde los campos ya parseados.
	return validateManifestStruct(fm)
}

// validateManifestStruct valida los campos básicos del FichaManifest cuando no hay
// YAML en disco (fichas en memoria o stubs de test).
func validateManifestStruct(fm *plugin.FichaManifest) []ValidationErrorItem {
	var items []ValidationErrorItem
	if fm.ID == "" {
		items = append(items, ValidationErrorItem{
			Field: "identity.id", Message: "id requerido (identity.id vacío)",
		})
	}
	if fm.Version == "" {
		items = append(items, ValidationErrorItem{
			Field: "identity.version", Message: "version requerida (identity.version vacío)",
		})
	}
	return items
}

// parseResultToItems convierte el resultado de ficha.ParseManifestStrict al tipo de dominio.
func parseResultToItems(result *ficha.ParseResult) []ValidationErrorItem {
	if result == nil || result.Valid {
		return nil
	}
	items := make([]ValidationErrorItem, 0, len(result.Errors))
	for _, e := range result.Errors {
		items = append(items, ValidationErrorItem{
			Field:   e.Section + "." + e.Field,
			Message: e.Message,
			Value:   e.Value,
		})
	}
	return items
}

// Pause pausa una ficha (mantenimiento). Sin alertas, sin reconciliación.
func (svc *FichaService) Pause(fichaID string) (*SagaOutcome, error) {
	if fichaID == "" {
		return nil, ErrFichaIDRequired
	}

	st, err := svc.state.Read()
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrStateUnavailable, err.Error())
	}
	f, ok := st.Fichas[fichaID]
	if !ok {
		return nil, fmt.Errorf("%w: %s", ErrFichaNotFound, fichaID)
	}
	prevState := string(f.State)

	if err := svc.state.Transition(fichaID, state.StatePaused); err != nil {
		return nil, fmt.Errorf("%w: pause %s: %s", ErrSagaFailed, fichaID, err.Error())
	}
	return &SagaOutcome{
		FichaID:   fichaID,
		Command:   "pause",
		Success:   true,
		PrevState: prevState,
		NewState:  string(state.StatePaused),
	}, nil
}

// Resume reanuda una ficha pausada, restaurando estado INSTALADA.
func (svc *FichaService) Resume(fichaID string) (*SagaOutcome, error) {
	if fichaID == "" {
		return nil, ErrFichaIDRequired
	}

	st, err := svc.state.Read()
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrStateUnavailable, err.Error())
	}
	f, ok := st.Fichas[fichaID]
	if !ok {
		return nil, fmt.Errorf("%w: %s", ErrFichaNotFound, fichaID)
	}
	prevState := string(f.State)

	if err := svc.state.Transition(fichaID, state.StateInstalled); err != nil {
		return nil, fmt.Errorf("%w: resume %s: %s", ErrSagaFailed, fichaID, err.Error())
	}
	return &SagaOutcome{
		FichaID:   fichaID,
		Command:   "resume",
		Success:   true,
		PrevState: prevState,
		NewState:  string(state.StateInstalled),
	}, nil
}

// Scale escala una ficha K8s (Deployment/StatefulSet) al número de réplicas dado.
func (svc *FichaService) Scale(fichaID string, replicas int32, k8s K8sPort) (*ScaleResult, error) {
	if fichaID == "" {
		return nil, ErrFichaIDRequired
	}
	if replicas < 0 {
		return nil, ErrReplicasInvalidas
	}
	if k8s == nil {
		return nil, ErrInstallerUnavailable
	}

	prev, err := k8s.GetReplicas(fichaID)
	if err != nil {
		return nil, fmt.Errorf("scale: obtener réplicas actuales de %s: %w", fichaID, err)
	}

	_, err = k8s.ScaleDeployment(fichaID, replicas)
	if err != nil {
		return nil, fmt.Errorf("scale: escalar %s de %d a %d: %w", fichaID, prev, replicas, err)
	}

	return &ScaleResult{
		FichaID:      fichaID,
		PrevReplicas: prev,
		NewReplicas:  replicas,
		Success:      true,
	}, nil
}

// Rescan re-descubre todas las fichas en servers/ y retorna el delta.
func (svc *FichaService) Rescan() (*RescanResult, error) {
	if svc.catalog == nil {
		return nil, ErrStateUnavailable
	}
	prevCount := svc.catalog.Count()
	newCount := svc.catalog.Reload()
	discovered := newCount - prevCount
	if discovered < 0 {
		discovered = 0
	}
	return &RescanResult{
		Discovered: discovered,
		Total:      newCount,
		Added:      nil,
	}, nil
}

// ResetState fuerza una transición de estado para compensación de sagas.
// La validez de la transición es verificada por state.Manager.
func (svc *FichaService) ResetState(fichaID, targetState string) (*SagaOutcome, error) {
	if fichaID == "" {
		return nil, ErrFichaIDRequired
	}
	if targetState == "" {
		return nil, ErrCommandInvalid
	}

	st, err := svc.state.Read()
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrStateUnavailable, err.Error())
	}
	var prevState string
	if f, ok := st.Fichas[fichaID]; ok {
		prevState = string(f.State)
	}

	target := state.FichaState(targetState)
	if err := svc.state.Transition(fichaID, target); err != nil {
		return nil, fmt.Errorf("%w: reset_state %s → %s: %s", ErrSagaFailed, fichaID, targetState, err.Error())
	}
	return &SagaOutcome{
		FichaID:   fichaID,
		Command:   "reset_state",
		Success:   true,
		PrevState: prevState,
		NewState:  targetState,
	}, nil
}

// ReadLog lee las últimas N líneas del log de una ficha desde disco.
func (svc *FichaService) ReadLog(fichaID string, tailLines int32, logReader LogPort) ([]LogEntry, error) {
	if fichaID == "" {
		return nil, ErrFichaIDRequired
	}
	if logReader == nil {
		return nil, ErrInstallerUnavailable
	}
	return logReader.ReadLog(fichaID, tailLines)
}

// FollowLog retorna un canal con líneas de log en tiempo real (tail -f).
func (svc *FichaService) FollowLog(fichaID string, logReader LogPort) (<-chan LogEntry, error) {
	if fichaID == "" {
		return nil, ErrFichaIDRequired
	}
	if logReader == nil {
		return nil, ErrInstallerUnavailable
	}
	return logReader.FollowLog(fichaID)
}
