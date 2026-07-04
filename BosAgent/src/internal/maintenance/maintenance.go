// Package maintenance implementa la saga de mantenimiento de nodos del
// Operator Soberano (F9.4 — BOS-REPAIR-02, ADR-004).
//
// Saga: cordon → drain → operación → uncordon, con LA garantía central:
// el uncordon se ejecuta SIEMPRE — falle el drain, falle la operación o
// entre en pánico — vía defer + recover. Un nodo que queda cordonado tras
// un mantenimiento fallido es el incidente real de staging del 2026-06-10
// (cordon huérfano + kubelet caído): esta saga existe para que no se repita.
//
// El puerto K8sPort lo implementa internal/k8s.Core; en tests, un fake.
package maintenance

import (
	"errors"
	"fmt"
	"sync"
	"time"
)

// K8sPort son las operaciones de nodo que la saga necesita (hexagonal —
// el dominio define el puerto, internal/k8s lo implementa).
type K8sPort interface {
	Cordon(node string) error
	Drain(node string, timeout time.Duration, dryRun bool) (string, error)
	Uncordon(node string) error
}

// Resultado de una saga de mantenimiento.
type Resultado struct {
	Node       string        `json:"node"`
	Exito      bool          `json:"exito"`
	Pasos      []string      `json:"pasos"`
	Error      string        `json:"error,omitempty"`
	Uncordoned bool          `json:"uncordoned"` // la garantía — siempre true al cerrar
	Duracion   time.Duration `json:"duracion"`
}

// Estado de la saga en curso (bos.maintenance.status).
type Estado struct {
	Activa    bool      `json:"activa"`
	Node      string    `json:"node"`
	Paso      string    `json:"paso"`
	Inicio    time.Time `json:"inicio,omitempty"`
	Cancelada bool      `json:"cancelada"`
}

// Service ejecuta sagas de mantenimiento. Una a la vez (mutex): dos
// mantenimientos simultáneos en el mismo cluster es una operación sin
// sentido y peligrosa en single-node.
type Service struct {
	k8s K8sPort

	mu     sync.Mutex
	estado Estado
}

// ErrEnCurso: ya hay una saga de mantenimiento activa.
var ErrEnCurso = errors.New("maintenance: ya hay una saga de mantenimiento en curso")

// NewService crea el servicio de mantenimiento sobre el puerto K8s dado.
func NewService(k8s K8sPort) *Service {
	return &Service{k8s: k8s}
}

// Estado retorna una copia del estado actual de la saga.
func (s *Service) Estado() Estado {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.estado
}

// Cancelar marca la saga activa como cancelada (best-effort: la saga revisa
// la marca entre pasos; el paso en ejecución termina y se uncordona igual).
func (s *Service) Cancelar() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.estado.Activa {
		return false
	}
	s.estado.Cancelada = true
	return true
}

func (s *Service) setPaso(paso string) {
	s.mu.Lock()
	s.estado.Paso = paso
	s.mu.Unlock()
}

func (s *Service) cancelada() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.estado.Cancelada
}

// Ejecutar corre la saga completa sobre el nodo:
//
//	cordon → drain (con dryRun si se pide) → op() → uncordon (GARANTIZADO)
//
// op es la operación de mantenimiento (parche del SO, upgrade de kubelet…);
// puede ser nil para un ciclo de verificación cordon/drain/uncordon.
func (s *Service) Ejecutar(node string, drainTimeout time.Duration, dryRunDrain bool, op func() error) (res *Resultado, err error) {
	if node == "" {
		return nil, errors.New("maintenance: nodo requerido")
	}
	s.mu.Lock()
	if s.estado.Activa {
		s.mu.Unlock()
		return nil, ErrEnCurso
	}
	s.estado = Estado{Activa: true, Node: node, Paso: "cordon", Inicio: time.Now()}
	s.mu.Unlock()

	inicio := time.Now()
	res = &Resultado{Node: node, Pasos: []string{}}

	defer func() {
		// LA GARANTÍA: uncordon pase lo que pase — error, cancelación o
		// pánico de la operación. recover captura el pánico, se uncordona,
		// y el pánico se reporta como error de la saga (no se re-lanza:
		// el daemon no debe morir por una operación de mantenimiento).
		if r := recover(); r != nil {
			res.Exito = false
			res.Error = fmt.Sprintf("pánico en la operación: %v", r)
			err = fmt.Errorf("maintenance: %s", res.Error)
		}
		if uerr := s.k8s.Uncordon(node); uerr != nil {
			res.Pasos = append(res.Pasos, "uncordon FALLÓ: "+uerr.Error())
			if err == nil {
				err = fmt.Errorf("maintenance: uncordon falló: %w", uerr)
			}
		} else {
			res.Uncordoned = true
			res.Pasos = append(res.Pasos, "uncordon OK")
		}
		res.Duracion = time.Since(inicio)

		s.mu.Lock()
		s.estado = Estado{}
		s.mu.Unlock()
	}()

	// Paso 1 — cordon
	if cerr := s.k8s.Cordon(node); cerr != nil {
		res.Error = "cordon falló: " + cerr.Error()
		return res, fmt.Errorf("maintenance: %s", res.Error)
	}
	res.Pasos = append(res.Pasos, "cordon OK")

	if s.cancelada() {
		res.Error = "cancelada por el operador"
		return res, errors.New("maintenance: cancelada")
	}

	// Paso 2 — drain
	s.setPaso("drain")
	if _, derr := s.k8s.Drain(node, drainTimeout, dryRunDrain); derr != nil {
		res.Error = "drain falló: " + derr.Error()
		return res, fmt.Errorf("maintenance: %s", res.Error)
	}
	modo := "drain OK"
	if dryRunDrain {
		modo = "drain (dry-run) OK"
	}
	res.Pasos = append(res.Pasos, modo)

	if s.cancelada() {
		res.Error = "cancelada por el operador"
		return res, errors.New("maintenance: cancelada")
	}

	// Paso 3 — operación de mantenimiento
	if op != nil {
		s.setPaso("operacion")
		if oerr := op(); oerr != nil {
			res.Error = "operación falló: " + oerr.Error()
			return res, fmt.Errorf("maintenance: %s", res.Error)
		}
		res.Pasos = append(res.Pasos, "operacion OK")
	}

	s.setPaso("uncordon")
	res.Exito = true
	return res, nil
}
