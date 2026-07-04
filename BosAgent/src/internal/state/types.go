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
	StatePendiente: {StateLista},      // deps satisfechas
	StateLista:     {StateInstalando}, // DAG otorga slot

	// ── Flujo de instalación ─────────────────────────────────────────────
	StateInstalando:       {StateInstalada, StateFallaInstalacion},
	StateFallaInstalacion: {StateLimpieza, StateInstalando}, // limpiar o reintentar
	StateLimpieza:         {StateLista, StatePendiente},     // listo o re-evaluar

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
	StateDegradada:   {StateReparando, StateErrorFisico, StateErrorLogico},
	StateErrorFisico: {StateReparando},
	StateErrorLogico: {StateReparando},
	StateReparando:   {StateInstalada, StateDegradada, StateErrorNoCorregible},

	// ── Error fatal (requiere HITL) ───────────────────────────────────────
	StateErrorNoCorregible: {StateReparando, StateDesinstalada, StateLimpieza},

	// ── Administración ────────────────────────────────────────────────────
	StatePausada:      {StateInstalada, StateDesinstalada},
	StateDesinstalada: {},
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
