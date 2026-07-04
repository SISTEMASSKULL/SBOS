// Package state implements STATE_MANAGER — the sole writer of .sbos_state.json.
// Principle P8: No other component may write to the state file.
// Uses fcntl(F_WRLCK) for exclusive file locking across processes.
//
// Máquina de 18 estados (ADR-021):
//   Estables: PENDIENTE, LISTA, INSTALADA, ACTUALIZACION_DISPONIBLE,
//             ACTUALIZACION_APROBADA, DEGRADADA, ERROR_FISICO, ERROR_LOGICO,
//             ERROR_NO_CORREGIBLE, FALLA_INSTALACION, FALLA_ACTUALIZACION,
//             PAUSADA, DESINSTALADA
//   Transicionales: INSTALANDO, ACTUALIZANDO, REPARANDO, ROLLBACK, LIMPIEZA
package state

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"sync"
	"syscall"
	"time"
)

// FichaState represents the operational state of a single ficha.
// Máquina de 18 estados — ADR-021.
type FichaState string

const (
	// ── Estados estables (visibles en UI y monitoreados por BOS) ────────

	// StatePendiente: ficha declarada, dependencias verificándose. (#1)
	StatePendiente FichaState = "PENDIENTE"
	// StateLista: dependencias OK, esperando turno en DAG topológico. (#2)
	StateLista FichaState = "LISTA"
	// StateInstalada: pod Running + health OK + hashes registrados. (#4)
	StateInstalada FichaState = "INSTALADA"
	// StateActualizacionDisp: nueva versión detectada, no evaluada aún. (#5)
	StateActualizacionDisp FichaState = "ACTUALIZACION_DISPONIBLE"
	// StateActualizacionAprobada: BOS evaluó → tests OK → sin degradación. (#6)
	StateActualizacionAprobada FichaState = "ACTUALIZACION_APROBADA"
	// StateDegradada: funciona con capacidad reducida, intenta auto-reparar. (#8)
	StateDegradada FichaState = "DEGRADADA"
	// StateErrorFisico: causa externa — disco, red, CPU, memoria. (#9)
	StateErrorFisico FichaState = "ERROR_FISICO"
	// StateErrorLogico: causa interna — config, deps, schema drift. (#10)
	StateErrorLogico FichaState = "ERROR_LOGICO"
	// StateErrorNoCorregible: reintentos agotados, requiere HITL. (#12)
	StateErrorNoCorregible FichaState = "ERROR_NO_CORREGIBLE"
	// StateFallaInstalacion: saga install falló, evaluar rollback. (#13)
	StateFallaInstalacion FichaState = "FALLA_INSTALACION"
	// StateFallaActualizacion: saga update falló, evaluar rollback. (#14)
	StateFallaActualizacion FichaState = "FALLA_ACTUALIZACION"
	// StatePausada: admin suspendió (mantenimiento), no genera alertas. (#17)
	StatePausada FichaState = "PAUSADA"
	// StateDesinstalada: removida del sistema. PV puede persistir (Retain). (#18)
	StateDesinstalada FichaState = "DESINSTALADA"

	// ── Estados transicionales (BOS está activamente ejecutando) ────────

	// StateInstalando: saga install en progreso (timeout 30min). (#3)
	StateInstalando FichaState = "INSTALANDO"
	// StateActualizando: saga update en progreso (timeout 15min). (#7)
	StateActualizando FichaState = "ACTUALIZANDO"
	// StateReparando: diagnóstico + repair en progreso (timeout 10min). (#11)
	StateReparando FichaState = "REPARANDO"
	// StateRollback: restaurando versión anterior estable. (#15)
	StateRollback FichaState = "ROLLBACK"
	// StateLimpieza: eliminando artefactos de operación fallida. (#16)
	StateLimpieza FichaState = "LIMPIEZA"
)

// StableStates retorna los 13 estados estables (visibles en UI y API).
func StableStates() []FichaState {
	return []FichaState{
		StatePendiente, StateLista, StateInstalada,
		StateActualizacionDisp, StateActualizacionAprobada,
		StateDegradada, StateErrorFisico, StateErrorLogico,
		StateErrorNoCorregible, StateFallaInstalacion, StateFallaActualizacion,
		StatePausada, StateDesinstalada,
	}
}

// TransitionalStates retorna los 5 estados transicionales.
func TransitionalStates() []FichaState {
	return []FichaState{
		StateInstalando, StateActualizando, StateReparando,
		StateRollback, StateLimpieza,
	}
}

// IsStable retorna true si el estado es estable (no transitorio).
func (s FichaState) IsStable() bool {
	switch s {
	case StatePendiente, StateLista, StateInstalada,
		StateActualizacionDisp, StateActualizacionAprobada,
		StateDegradada, StateErrorFisico, StateErrorLogico,
		StateErrorNoCorregible, StateFallaInstalacion, StateFallaActualizacion,
		StatePausada, StateDesinstalada:
		return true
	}
	return false
}

// IsTransitional retorna true si BOS está activamente trabajando en este estado.
func (s FichaState) IsTransitional() bool {
	switch s {
	case StateInstalando, StateActualizando, StateReparando,
		StateRollback, StateLimpieza:
		return true
	}
	return false
}

// IsError retorna true si el estado representa un error que requiere atención.
func (s FichaState) IsError() bool {
	switch s {
	case StateErrorFisico, StateErrorLogico, StateErrorNoCorregible,
		StateFallaInstalacion, StateFallaActualizacion:
		return true
	}
	return false
}

// IsHealthy retorna true si la ficha está operativa sin alertas.
func (s FichaState) IsHealthy() bool { return s == StateInstalada }

// ValidTransitions define las transiciones permitidas entre los 18 estados.
// Toda transición no listada aquí es rechazada por Transition().
var ValidTransitions = map[FichaState][]FichaState{
	// ── Pre-install ─────────────────────────────────────────────────────
	StatePendiente: {StateLista},                          // deps satisfechas
	StateLista:     {StateInstalando},                     // DAG otorga slot

	// ── Flujo de instalación ─────────────────────────────────────────────
	StateInstalando:       {StateInstalada, StateFallaInstalacion},
	StateFallaInstalacion: {StateLimpieza, StateInstalando},    // limpiar o reintentar
	StateLimpieza:         {StateLista, StatePendiente},        // listo o re-evaluar

	// ── Instalada estable → ramas ────────────────────────────────────────
	StateInstalada: {
		StateActualizacionDisp, StateActualizando,
		StateDegradada, StateReparando,
		StatePausada, StateDesinstalada,
	},

	// ── Flujo de actualización ────────────────────────────────────────────
	StateActualizacionDisp:     {StateActualizacionAprobada, StateInstalada},
	StateActualizacionAprobada: {StateActualizando},
	StateActualizando:          {StateInstalada, StateFallaActualizacion, StateRollback},
	StateFallaActualizacion:    {StateRollback, StateInstalada},
	StateRollback:              {StateInstalada, StateErrorNoCorregible},

	// ── Degradada y reparación ────────────────────────────────────────────
	StateDegradada:  {StateReparando, StateErrorFisico, StateErrorLogico},
	StateErrorFisico: {StateReparando},
	StateErrorLogico: {StateReparando},
	StateReparando:  {StateInstalada, StateDegradada, StateErrorNoCorregible},

	// ── Error fatal (requiere HITL) ───────────────────────────────────────
	StateErrorNoCorregible: {StateReparando, StateDesinstalada, StateLimpieza},

	// ── Administración ────────────────────────────────────────────────────
	StatePausada:      {StateInstalada, StateDesinstalada},
	StateDesinstalada: {},
}

// Ficha represents a single installed component in the state file.
type Ficha struct {
	Name         string            `json:"name"`
	Version      string            `json:"version"`
	State        FichaState        `json:"state"`
	Server       string            `json:"server"`
	Category     int               `json:"category"`
	Criticality  bool              `json:"criticality"`
	Hashes       map[string]string `json:"hashes"`
	InstalledAt  time.Time         `json:"installed_at"`
	UpdatedAt    time.Time         `json:"updated_at"`
	HealthStatus string            `json:"health_status"`
	Backend      string            `json:"backend"`
}

// SBOSState is the root structure of .sbos_state.json.
type SBOSState struct {
	Version     string           `json:"version"`
	Hostname    string           `json:"hostname"`
	ClusterName string           `json:"cluster_name"`
	UpdatedAt   time.Time        `json:"updated_at"`
	Fichas      map[string]*Ficha `json:"fichas"`
	Meta        map[string]string `json:"meta"`
}

// Manager is the sole writer of .sbos_state.json (Principle P8).
type Manager struct {
	mu       sync.Mutex
	path     string
	file     *os.File
	Recovery RecoveryLevel // set by NewManager: normal, backup, or rebuilt
}

// RecoveryLevel indicates which source was used to load the state file.
type RecoveryLevel int

const (
	RecoveryNormal  RecoveryLevel = 0 // loaded from primary state file
	RecoveryBackup  RecoveryLevel = 1 // loaded from backup (.bak)
	RecoveryRebuilt RecoveryLevel = 2 // rebuilt from empty (manifests will repopulate)
)

// NewManager opens (or creates) the state file and acquires an exclusive lock.
// On success, Recovery is set to the source used (normal, backup, or rebuilt).
func NewManager(path string) (*Manager, error) {
	f, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE, 0600)
	if err != nil {
		return nil, fmt.Errorf("state: open %s: %w", path, err)
	}

	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		f.Close()
		return nil, fmt.Errorf("state: flock %s: %w", path, err)
	}

	m := &Manager{path: path, file: f, Recovery: RecoveryNormal}

	info, _ := f.Stat()
	if info.Size() == 0 {
		if err := m.initEmpty(); err != nil {
			f.Close()
			return nil, err
		}
		return m, nil
	}

	// Validate: the file is non-empty, but is the JSON well-formed?
	if err := m.validate(); err != nil {
		// Level 1 failed. Close and try Level 2: backup.
		m.file.Close()
		bakPath := path + ".bak"
		if bakData, bakErr := os.ReadFile(bakPath); bakErr == nil {
			f2, err := os.OpenFile(path, os.O_RDWR|os.O_TRUNC, 0600)
			if err != nil {
				return nil, fmt.Errorf("state: reopen for backup restore: %w", err)
			}
			if _, err := f2.Write(bakData); err != nil {
				f2.Close()
				return nil, fmt.Errorf("state: write backup: %w", err)
			}
			if err := f2.Sync(); err != nil {
				f2.Close()
				return nil, fmt.Errorf("state: sync backup: %w", err)
			}
			if err := syscall.Flock(int(f2.Fd()), syscall.LOCK_EX); err != nil {
				f2.Close()
				return nil, fmt.Errorf("state: flock after backup restore: %w", err)
			}
			m.file = f2
			m.Recovery = RecoveryBackup
		} else {
			// Level 2 also failed. Level 3: rebuild from empty.
			f2, err := os.OpenFile(path, os.O_RDWR|os.O_TRUNC, 0600)
			if err != nil {
				return nil, fmt.Errorf("state: reopen for rebuild: %w", err)
			}
			if err := syscall.Flock(int(f2.Fd()), syscall.LOCK_EX); err != nil {
				f2.Close()
				return nil, fmt.Errorf("state: flock for rebuild: %w", err)
			}
			m.file = f2
			if err := m.initEmpty(); err != nil {
				f2.Close()
				return nil, fmt.Errorf("state: rebuild empty: %w", err)
			}
			m.Recovery = RecoveryRebuilt
		}
	}

	return m, nil
}

func (m *Manager) initEmpty() error {
	hostname, _ := os.Hostname()
	state := SBOSState{
		Version:   "1.0.0",
		Hostname:  hostname,
		UpdatedAt: time.Now(),
		Fichas:    make(map[string]*Ficha),
		Meta:      make(map[string]string),
	}
	return m.writeState(&state)
}

// validate attempts to decode the state file and returns an error if
// the JSON is malformed or doesn't match the expected schema.
// Does NOT update state — used only for integrity checking at open time.
func (m *Manager) validate() error {
	if _, err := m.file.Seek(0, 0); err != nil {
		return err
	}
	var state SBOSState
	if err := json.NewDecoder(m.file).Decode(&state); err != nil {
		return fmt.Errorf("state: corrupt: %w", err)
	}
	return nil
}

// Read returns the current state (for read-only consumers).
func (m *Manager) Read() (*SBOSState, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, err := m.file.Seek(0, 0); err != nil {
		return nil, err
	}

	var state SBOSState
	if err := json.NewDecoder(m.file).Decode(&state); err != nil {
		return nil, fmt.Errorf("state: decode: %w", err)
	}
	return &state, nil
}

// Transition atomically moves a ficha to a new state.
// Returns error if the transition is not allowed.
func (m *Manager) Transition(name string, to FichaState) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	st, err := m.readLocked()
	if err != nil {
		return err
	}

	ficha, ok := st.Fichas[name]
	if !ok {
		// Auto-create vía INSTALANDO: la ficha se registra como LISTA (deps ya OK)
		// y se valida la transición LISTA→INSTALANDO. Usado principalmente en tests.
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

// RegisterHashes stores SHA-256 hashes for a ficha's resources.
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

// SetHealth updates the health_status of a ficha.
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

// SetDriftDetected transitions a ficha to ACTUALIZACION_DISPONIBLE
// when drift is detected in resources/ or a new version is available.
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

// SetBackend updates the backend field of a ficha (apt/pip/helm).
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

// SetVersion updates the version field of a ficha.
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

// Register initializes a ficha in the state file with the given state.
// Unlike Transition, this does not validate against ValidTransitions — it is
// used only for initial discovery of fichas by the plugin loader.
// If the ficha already exists, its state is not modified.
func (m *Manager) Register(name string, initialState FichaState, version string, criticality bool, server string, category int, backend string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	st, err := m.readLocked()
	if err != nil {
		return err
	}

	if _, ok := st.Fichas[name]; ok {
		return nil // already registered
	}

	st.Fichas[name] = &Ficha{
		Name:          name,
		Version:       version,
		State:         initialState,
		Server:        server,
		Category:      category,
		Criticality:   criticality,

		InstalledAt:   time.Time{},
		UpdatedAt:     time.Now(),
		Hashes:        make(map[string]string),
		Backend:       backend,
	}
	st.UpdatedAt = time.Now()

	return m.writeState(st)
}

// SetLista transiciona una ficha de PENDIENTE a LISTA (dependencias satisfechas).
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

func (m *Manager) readLocked() (*SBOSState, error) {
	if _, err := m.file.Seek(0, 0); err != nil {
		return nil, err
	}
	var state SBOSState
	if err := json.NewDecoder(m.file).Decode(&state); err != nil {
		return nil, fmt.Errorf("state: decode: %w", err)
	}
	return &state, nil
}

func (m *Manager) writeState(state *SBOSState) error {
	tmpPath := m.path + ".tmp"
	bakPath := m.path + ".bak"

	// 1. Write to temporary file
	tmpFile, err := os.OpenFile(tmpPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		return fmt.Errorf("state: open tmp: %w", err)
	}
	enc := json.NewEncoder(tmpFile)
	enc.SetIndent("", "  ")
	if err := enc.Encode(state); err != nil {
		tmpFile.Close()
		return fmt.Errorf("state: encode: %w", err)
	}
	// 2. Sync before rename (guarantees durability of .tmp)
	if err := tmpFile.Sync(); err != nil {
		tmpFile.Close()
		return fmt.Errorf("state: sync tmp: %w", err)
	}
	tmpFile.Close()

	// 3. Atomic rename over the real state file (POSIX guarantee)
	if err := os.Rename(tmpPath, m.path); err != nil {
		return fmt.Errorf("state: rename: %w", err)
	}

	// 4. Copy to backup (best-effort, non-fatal)
	if src, err := os.Open(m.path); err == nil {
		defer src.Close()
		if dst, err := os.OpenFile(bakPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600); err == nil {
			defer dst.Close()
			io.Copy(dst, src)
		}
	}

	// 5. Update m.file fd — the old fd points to the unlinked inode.
	//    Reopen + re-lock to keep m.file consistent with the new file.
	m.file.Close()
	f, err := os.OpenFile(m.path, os.O_RDWR, 0600)
	if err != nil {
		return fmt.Errorf("state: reopen after rename: %w", err)
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		f.Close()
		return fmt.Errorf("state: flock after rename: %w", err)
	}
	m.file = f
	return nil
}

// Close releases the lock and closes the state file.
func (m *Manager) Close() error {
	syscall.Flock(int(m.file.Fd()), syscall.LOCK_UN)
	return m.file.Close()
}
