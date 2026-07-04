package state

// mutations.go — Mutaciones complejas del Manager (M-11, F6).
// SetBackend, SetVersion, Register, SetK8sDiscoveredState, SetLista, Unblock.

import (
	"fmt"
	"time"
)

// SetBackend actualiza el campo backend de una ficha (apt/pip/helm).
// Usado por el package manager al instalar fichas generadas automáticamente.
func (m *Manager) SetBackend(name, backend string) error {
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

	ficha.Backend = backend
	ficha.UpdatedAt = time.Now()
	st.UpdatedAt = time.Now()

	return m.writeState(st)
}

// SetVersion actualiza el campo version de una ficha.
// Usado por el saga orchestrator al completar un install o update.
func (m *Manager) SetVersion(name, version string) error {
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

	ficha.Version = version
	ficha.UpdatedAt = time.Now()
	st.UpdatedAt = time.Now()

	return m.writeState(st)
}

// Register inicializa una ficha nueva en el archivo de estado.
// A diferencia de Transition, no valida contra ValidTransitions — solo para
// descubrimiento inicial por el plugin loader. Si la ficha ya existe, no la modifica.
//
// Estándares: SBOS-019 §2 — registro inicial de fichas en PENDIENTE.
func (m *Manager) Register(name string, initialState FichaState, version string, criticality bool, server string, category int, backend string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	st, err := m.readLocked()
	if err != nil {
		return err
	}

	if _, ok := st.Fichas[name]; ok {
		return nil // ya registrada
	}

	st.Fichas[name] = &Ficha{
		Name:        name,
		Version:     version,
		State:       initialState,
		Server:      server,
		Category:    category,
		Criticality: criticality,
		InstalledAt: time.Time{},
		UpdatedAt:   time.Now(),
		Hashes:      make(map[string]string),
		Backend:     backend,
	}
	st.UpdatedAt = time.Now()

	return m.writeState(st)
}

// SetK8sDiscoveredState actualiza el estado de una ficha según lo que K8s reporta.
//
// Bypassa ValidTransitions porque el cluster K8s es la fuente de verdad para fichas
// con runtime=kubernetes. No pisa estados transitorios ni administrativos.
//
// Callers conocidos: internal/reconcile/k8s_discovery.go:DiscoverK8sStates.
func (m *Manager) SetK8sDiscoveredState(name string, discovered FichaState) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	st, err := m.readLocked()
	if err != nil {
		return err
	}

	ficha, ok := st.Fichas[name]
	if !ok {
		return nil // ficha no registrada — ignorar silenciosamente
	}

	// No pisar estados transitorios ni administrativos
	switch ficha.State {
	case StateInstalando, StateActualizando, StateReparando, StateRollback, StateLimpieza,
		StatePausada, StateDesinstalada:
		return nil
	}

	if ficha.State == discovered {
		return nil
	}

	ficha.State = discovered
	ficha.UpdatedAt = time.Now()
	st.UpdatedAt = time.Now()
	st.Fichas[name] = ficha

	return m.writeState(st)
}

// SetLista transiciona una ficha de PENDIENTE a LISTA (dependencias satisfechas).
// Retorna error si la ficha no está en estado PENDIENTE.
//
// Callers conocidos: internal/observer/ — DEPENDENCY_RESOLVER desbloquea fichas.
func (m *Manager) SetLista(name string) error {
	st, err := m.Read()
	if err != nil {
		return err
	}
	ficha, ok := st.Fichas[name]
	if !ok || ficha.State != StatePendiente {
		return fmt.Errorf("state: ficha %s no está en PENDIENTE", name)
	}
	return m.Transition(name, StateLista)
}

// Unblock es un alias de SetLista para compatibilidad con código existente.
func (m *Manager) Unblock(name string) error { return m.SetLista(name) }
