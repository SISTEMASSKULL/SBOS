package state

// transitions.go — Métodos de transición de estado (M-11, F6).
// Mutation methods del Manager: Transition, RegisterHashes, SetHealth,
// SetDriftDetected, SetPendiente, SetBlocked.

import (
	"fmt"
	"time"
)

// Transition mueve atómicamente una ficha a un nuevo estado.
// Valida que la transición esté en ValidTransitions antes de escribir.
//
// Retorna: error si la transición no está permitida o si la ficha no existe.
// Estándares: ADR-021 — solo transiciones de ValidTransitions son aceptadas.
func (m *Manager) Transition(name string, to FichaState) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	st, err := m.readLocked()
	if err != nil {
		return err
	}

	ficha, ok := st.Fichas[name]
	if !ok {
		// Auto-create vía INSTALANDO: registra la ficha como LISTA y valida
		// la transición LISTA→INSTALANDO. Usado principalmente en tests.
		if to != StateInstalando {
			return fmt.Errorf("state: ficha %s not found for transition to %s", name, to)
		}
		ficha = &Ficha{Name: name, State: StateLista}
		st.Fichas[name] = ficha
	}

	allowed := false
	for _, valid := range ValidTransitions[ficha.State] {
		if valid == to {
			allowed = true
			break
		}
	}
	if !allowed {
		return fmt.Errorf("state: invalid transition %s -> %s for ficha %s",
			ficha.State, to, name)
	}

	ficha.State = to
	ficha.UpdatedAt = time.Now()
	st.UpdatedAt = time.Now()

	return m.writeState(st)
}

// RegisterHashes almacena los hashes SHA-256 de los recursos de una ficha.
// Usado por el reconcile scheduler para detectar drift de configuración.
func (m *Manager) RegisterHashes(name string, hashes map[string]string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	st, err := m.readLocked()
	if err != nil {
		return err
	}

	ficha, ok := st.Fichas[name]
	if !ok {
		return fmt.Errorf("state: ficha %s not found", name)
	}

	ficha.Hashes = hashes
	ficha.UpdatedAt = time.Now()
	st.UpdatedAt = time.Now()

	return m.writeState(st)
}

// SetHealth actualiza el health_status de una ficha.
// Usado por el health checker para reflejar el estado de salud tras las probes.
func (m *Manager) SetHealth(name string, status string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	st, err := m.readLocked()
	if err != nil {
		return err
	}

	ficha, ok := st.Fichas[name]
	if !ok {
		return fmt.Errorf("state: ficha %s not found", name)
	}

	ficha.HealthStatus = status
	ficha.UpdatedAt = time.Now()
	st.UpdatedAt = time.Now()

	return m.writeState(st)
}

// SetDriftDetected transiciona una ficha a ACTUALIZACION_DISPONIBLE
// cuando se detecta drift en resources/ o hay una nueva versión disponible.
func (m *Manager) SetDriftDetected(name string) error {
	return m.Transition(name, StateActualizacionDisp)
}

// SetPendiente fuerza una ficha a PENDIENTE independientemente del estado actual.
// Evita la validación de Transition porque el bloqueo de dependencias es un evento
// externo (DEPENDENCY_RESOLVER), no un flujo normal de estados.
func (m *Manager) SetPendiente(name string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	st, err := m.readLocked()
	if err != nil {
		return err
	}

	ficha, ok := st.Fichas[name]
	if !ok {
		return fmt.Errorf("state: ficha %s not found", name)
	}

	ficha.State = StatePendiente
	ficha.UpdatedAt = time.Now()
	st.UpdatedAt = time.Now()

	return m.writeState(st)
}

// SetBlocked es un alias de SetPendiente para compatibilidad con código existente.
func (m *Manager) SetBlocked(name string) error { return m.SetPendiente(name) }
