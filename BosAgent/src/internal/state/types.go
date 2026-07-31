package state

// types.go — FichaState (18 estados ADR-021), ValidTransitions, Ficha, SBOSState, Manager (M-11).

import (
	"os"
	"sync"
	"time"
)

// FichaState representa el estado operativo de una ficha.
// Máquina de 18 estados — ADR-021.
type FichaState string

const (
	// ── Estados estables (visibles en UI y monitoreados por BOS) ────────

	// StatePending: ficha declarada, dependencias verificándose. (#1)
	StatePending FichaState = "PENDING"
	// StateReady: dependencias OK, esperando turno en DAG topológico. (#2)
	StateReady FichaState = "READY"
	// StateInstalled: pod Running + health OK + hashes registrados. (#4)
	StateInstalled FichaState = "INSTALLED"
	// StateUpdateAvailable: nueva versión detectada, no evaluada aún. (#5)
	StateUpdateAvailable FichaState = "UPDATE_AVAILABLE"
	// StateUpdateApproved: BOS evaluó → tests OK → sin degradación. (#6)
	StateUpdateApproved FichaState = "UPDATE_APPROVED"
	// StateDegraded: funciona con capacidad reducida, intenta auto-reparar. (#8)
	StateDegraded FichaState = "DEGRADED"
	// StatePhysicalError: causa externa — disco, red, CPU, memoria. (#9)
	StatePhysicalError FichaState = "PHYSICAL_ERROR"
	// StateLogicalError: causa interna — config, deps, schema drift. (#10)
	StateLogicalError FichaState = "LOGICAL_ERROR"
	// StateUnrecoverable: reintentos agotados, requiere HITL. (#12)
	StateUnrecoverable FichaState = "UNRECOVERABLE"
	// StateInstallFailed: saga install falló, evaluar rollback. (#13)
	StateInstallFailed FichaState = "INSTALL_FAILED"
	// StateUpdateFailed: saga update falló, evaluar rollback. (#14)
	StateUpdateFailed FichaState = "UPDATE_FAILED"
	// StatePaused: admin suspendió (mantenimiento), no genera alertas. (#17)
	StatePaused FichaState = "PAUSED"
	// StateUninstalled: removida del sistema. PV puede persistir (Retain). (#18)
	StateUninstalled FichaState = "UNINSTALLED"

	// ── Estados transicionales (BOS está activamente ejecutando) ────────

	// StateInstalling: saga install en progreso (timeout 30min). (#3)
	StateInstalling FichaState = "INSTALLING"
	// StateUpdating: saga update en progreso (timeout 15min). (#7)
	StateUpdating FichaState = "UPDATING"
	// StateRepairing: diagnóstico + repair en progreso (timeout 10min). (#11)
	StateRepairing FichaState = "REPAIRING"
	// StateRollback: restaurando versión anterior estable. (#15)
	StateRollback FichaState = "ROLLBACK"
	// StateCleanup: eliminando artefactos de operación fallida. (#16)
	StateCleanup FichaState = "CLEANUP"
)

// StableStates retorna los 13 estados estables (visibles en UI y API).
func StableStates() []FichaState {
	return []FichaState{
		StatePending, StateReady, StateInstalled,
		StateUpdateAvailable, StateUpdateApproved,
		StateDegraded, StatePhysicalError, StateLogicalError,
		StateUnrecoverable, StateInstallFailed, StateUpdateFailed,
		StatePaused, StateUninstalled,
	}
}

// TransitionalStates retorna los 5 estados transicionales.
func TransitionalStates() []FichaState {
	return []FichaState{
		StateInstalling, StateUpdating, StateRepairing,
		StateRollback, StateCleanup,
	}
}

// IsStable retorna true si el estado es estable (no transitorio).
func (s FichaState) IsStable() bool {
	switch s {
	case StatePending, StateReady, StateInstalled,
		StateUpdateAvailable, StateUpdateApproved,
		StateDegraded, StatePhysicalError, StateLogicalError,
		StateUnrecoverable, StateInstallFailed, StateUpdateFailed,
		StatePaused, StateUninstalled:
		return true
	}
	return false
}

// IsTransitional retorna true si BOS está activamente trabajando en este estado.
func (s FichaState) IsTransitional() bool {
	switch s {
	case StateInstalling, StateUpdating, StateRepairing,
		StateRollback, StateCleanup:
		return true
	}
	return false
}

// IsError retorna true si el estado representa un error que requiere atención.
func (s FichaState) IsError() bool {
	switch s {
	case StatePhysicalError, StateLogicalError, StateUnrecoverable,
		StateInstallFailed, StateUpdateFailed:
		return true
	}
	return false
}

// IsHealthy retorna true si la ficha está operativa sin alertas.
func (s FichaState) IsHealthy() bool { return s == StateInstalled }

// ValidTransitions define las transiciones permitidas entre los 18 estados.
// Toda transición no listada aquí es rechazada por Transition().
var ValidTransitions = map[FichaState][]FichaState{
	// ── Pre-install ─────────────────────────────────────────────────────
	StatePending: {StateReady},      // deps satisfechas
	StateReady:     {StateInstalling}, // DAG otorga slot

	// ── Flujo de instalación ─────────────────────────────────────────────
	StateInstalling:       {StateInstalled, StateInstallFailed},
	StateInstallFailed: {StateCleanup, StateInstalling}, // limpiar o reintentar
	StateCleanup:         {StateReady, StatePending},     // listo o re-evaluar

	// ── Instalada estable → ramas ────────────────────────────────────────
	StateInstalled: {
		StateUpdateAvailable, StateUpdating,
		StateDegraded, StateRepairing,
		StatePaused, StateUninstalled,
	},

	// ── Flujo de actualización ────────────────────────────────────────────
	StateUpdateAvailable:     {StateUpdateApproved, StateInstalled},
	StateUpdateApproved: {StateUpdating},
	StateUpdating:          {StateInstalled, StateUpdateFailed, StateRollback},
	StateUpdateFailed:    {StateRollback, StateInstalled},
	StateRollback:              {StateInstalled, StateUnrecoverable},

	// ── Degradada y reparación ────────────────────────────────────────────
	StateDegraded:   {StateRepairing, StatePhysicalError, StateLogicalError},
	StatePhysicalError: {StateRepairing},
	StateLogicalError: {StateRepairing},
	StateRepairing:   {StateInstalled, StateDegraded, StateUnrecoverable},

	// ── Error fatal (requiere HITL) ───────────────────────────────────────
	StateUnrecoverable: {StateRepairing, StateUninstalled, StateCleanup},

	// ── Administración ────────────────────────────────────────────────────
	StatePaused:      {StateInstalled, StateUninstalled},
	StateUninstalled: {},
}

// Ficha representa un componente instalado en el archivo de estado.
//
// Thread safety: solo el Manager puede escribir instancias Ficha.
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

// SBOSState es la estructura raíz de .sbos_state.json.
//
// Thread safety: inmutable tras ser retornada por Read(); no modificar fuera del Manager.
type SBOSState struct {
	Version     string            `json:"version"`
	Hostname    string            `json:"hostname"`
	ClusterName string            `json:"cluster_name"`
	UpdatedAt   time.Time         `json:"updated_at"`
	Fichas      map[string]*Ficha `json:"fichas"`
	Meta        map[string]string `json:"meta"`
}

// Manager es el único escritor de .sbos_state.json (P8).
// Thread safety: mu serializa escrituras, flock garantiza exclusividad entre procesos.
type Manager struct {
	mu       sync.Mutex
	path     string
	file     *os.File
	Recovery RecoveryLevel // set by NewManager: normal, backup, or rebuilt
}

// RecoveryLevel indica la fuente usada para cargar el estado al abrir.
type RecoveryLevel int

const (
	RecoveryNormal  RecoveryLevel = 0 // loaded from primary state file
	RecoveryBackup  RecoveryLevel = 1 // loaded from backup (.bak)
	RecoveryRebuilt RecoveryLevel = 2 // rebuilt from empty (manifests will repopulate)
)
