package domain

import (
	"fmt"
	"time"

	"bos/internal/state"
)

// certCheck define un criterio de certificación con su ficha asociada.
type certCheck struct {
	id      string
	nombre  string
	fichaID string
}

// certificationChecks son los 8 criterios de certificación C-01..C-08
// que el Operador verifica antes de considerar el bootstrap completo.
// Definidos en el dominio — no en el handler RPC ni en la UI.
var certificationChecks = []certCheck{
	{"C-01", "sbos-bootstrap-os HEALTHY (kernel, /data/)", "sbos-bootstrap-os"},
	{"C-02", "sbos-bootstrap-k8s HEALTHY (kubeadm, Calico)", "sbos-bootstrap-k8s"},
	{"C-03", "Calico CNI operativo (NetworkPolicy activa)", "sbos-bootstrap-cni"},
	{"C-04", "PostgreSQL HEALTHY + WAL lógico + bkernel_slot", "postgresql"},
	{"C-05", "Redis HEALTHY (PONG DB0/1/2)", "redis"},
	{"C-06", "Vault unsealed + AppRole sbos-pods creado", "vault"},
	{"C-07", "Keycloak HEALTHY (realm master, health/ready 200)", "keycloak"},
	{"C-08", "Kong HEALTHY (migrations OK, admin API restringida)", "kong"},
}

// BootstrapService contiene la lógica de negocio del proceso de bootstrap SBOS.
// No conoce JSON-RPC, HTTP ni formatos de transporte — solo usa StatePort.
//
// Thread safety: seguro para uso concurrente — state es el único campo mutable y tiene su propia sincronización.
type BootstrapService struct {
	state StatePort
}

// NewBootstrapService crea el servicio con sus dependencias inyectadas.
func NewBootstrapService(st StatePort) *BootstrapService {
	return &BootstrapService{state: st}
}

// Start activa el motor bootstrap. El observer loop en main.go gestiona
// la instalación efectiva — este método reporta el estado de activación.
func (svc *BootstrapService) Start(mode string) (*BootstrapStartResult, error) {
	if mode == "" {
		mode = "unattended"
	}

	st, err := svc.state.Read()
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrStateUnavailable, err.Error())
	}

	if countByState(st, state.StateInstalling) > 0 {
		return nil, ErrBootstrapInProgress
	}

	return &BootstrapStartResult{
		BootstrapID: fmt.Sprintf("bs-%d", time.Now().Unix()),
		Mode:        mode,
		Total:       len(st.Fichas),
		Completados: countByState(st, state.StateInstalled),
	}, nil
}

// Verify evalúa los 8 criterios de certificación del Operador contra el state file.
// Una ficha certifica si está en estado INSTALADA — DEGRADADA y otros estados no certifican.
func (svc *BootstrapService) Verify() (*VerifyResult, error) {
	st, err := svc.state.Read()
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrStateUnavailable, err.Error())
	}

	criterios := make([]CertCriterion, len(certificationChecks))
	passed := 0

	for i, c := range certificationChecks {
		criterios[i].ID = c.id
		criterios[i].Nombre = c.nombre

		ficha, ok := st.Fichas[c.fichaID]
		if !ok {
			criterios[i].Detalle = c.fichaID + " no registrada en state file"
			continue
		}
		switch ficha.State {
		case state.StateInstalled:
			criterios[i].OK = true
			criterios[i].Detalle = c.fichaID + " INSTALLED"
			passed++
		case state.StateDegraded:
			criterios[i].Detalle = c.fichaID + " DEGRADED — funcionalidad reducida"
		default:
			criterios[i].Detalle = fmt.Sprintf("%s en estado %s — requiere completar bootstrap", c.fichaID, ficha.State)
		}
	}

	return &VerifyResult{
		Criterios: criterios,
		Passed:    passed,
		Total:     len(certificationChecks),
		Certified: passed == len(certificationChecks),
		Timestamp: time.Now(),
	}, nil
}

// Resume devuelve el estado actual para reanudar el bootstrap.
// El observer loop reacciona automáticamente al leer el estado.
func (svc *BootstrapService) Resume() (*BootstrapStatus, error) {
	return svc.Status()
}

// Status devuelve el estado completo del proceso de bootstrap.
func (svc *BootstrapService) Status() (*BootstrapStatus, error) {
	st, err := svc.state.Read()
	if err != nil {
		return nil, fmt.Errorf("%w: %s", ErrStateUnavailable, err.Error())
	}

	total := len(st.Fichas)
	completados := countByState(st, state.StateInstalled)

	var progress float64
	if total > 0 {
		progress = float64(completados) / float64(total)
	}

	return &BootstrapStatus{
		Progress:    progress,
		Total:       total,
		Completados: completados,
		Instalando:  countByState(st, state.StateInstalling),
		Alerta:      countByState(st, state.StateDegraded),
		Pendientes:  countByState(st, state.StateReady),
		Bloqueadas:  countByState(st, state.StatePending),
	}, nil
}

// countByState cuenta fichas en un estado dado — función interna del dominio.
func countByState(st *state.SBOSState, target state.FichaState) int {
	n := 0
	for _, f := range st.Fichas {
		if f.State == target {
			n++
		}
	}
	return n
}
