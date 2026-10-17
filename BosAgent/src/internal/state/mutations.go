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
// con runtime=kubernetes, pero respeta estados del ciclo de vida del instalador.
//
// Reglas de precedencia:
//   - Estados transitorios/admin (INSTALLING…UNINSTALLED): nunca se pisan.
//   - Estados del instalador (PENDING, READY, INSTALL_FAILED): el observer los gestiona,
//     el k8s_discovery no interfiere.
//   - Si discovered=PENDING (workload no encontrado en K8s): se eleva a PHYSICAL_ERROR,
//     porque "sin workload en K8s" después de una instalación no es "pendiente" sino un error.
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
	case StateInstalling, StateUpdating, StateRepairing, StateRollback, StateCleanup,
		StatePaused, StateUninstalled:
		return nil
	}

	// No pisar estados del ciclo de instalación — el observer los gestiona.
	// PENDING = esperando dependencias; READY = en cola para instalar;
	// INSTALL_FAILED = reintento con backoff. El k8s_discovery no debe interferir.
	switch ficha.State {
	case StatePending, StateReady, StateInstallFailed:
		return nil
	}

	// Workload no encontrado en K8s (StatePending del probe) tras instalación
	// = error físico, no "pendiente de instalación".
	if discovered == StatePending {
		discovered = StatePhysicalError
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
	if !ok || ficha.State != StatePending {
		return fmt.Errorf("state: ficha %s no está en PENDING", name)
	}
	return m.Transition(name, StateReady)
}

// Unblock es un alias de SetLista para compatibilidad con código existente.
func (m *Manager) Unblock(name string) error { return m.SetLista(name) }

// ForceState mueve una ficha a un estado arbitrario saltándose ValidTransitions.
// Reservado para recuperación de arranque (sagas huérfanas por reinicio del daemon).
// NO usar en flujos normales — para transiciones ordinarias usar Transition().
func (m *Manager) ForceState(name string, to FichaState) error {
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

	ficha.State = to
	ficha.UpdatedAt = time.Now()
	st.UpdatedAt = time.Now()

	return m.writeState(st)
}
