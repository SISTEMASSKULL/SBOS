// Package ficha — Orquestador del ciclo de vida (F11.B.2-B.6).
// BOS-REPAIR Plan Maestro v3.
//
// Cada operación del ciclo de vida (install, update, repair, remove) es una saga
// con transiciones de estado, timeout, y compensación automática según ADR-021.
//
// Instalación (F11.B.2):
//   LISTA → INSTALANDO (30min) → INSTALADA_vX.Y.Z
//                              → FALLA_INSTALACION → LIMPIEZA (sin backup)
//                                                   → ROLLBACK (si N-1 existe)
//
// Actualización (F11.B.3):
//   INSTALADA → ACTUALIZANDO (15min) → INSTALADA_vX.Y.Z+1
//                                    → FALLA_ACTUALIZACION → ROLLBACK
//
// Reparación (F11.B.4):
//   DEGRADADA → REPARANDO (10min) → INSTALADA
//                                 → ERROR_NO_CORREGIBLE (3 reintentos)
//
// Eliminación (F11.B.4):
//   INSTALADA → saga inversa → DESINSTALADA
//
// Cada operación registra audit_event con timestamp, duración y resultado.
// Timeouts: install=30min, update=15min, repair=10min, remove=10min (ADR-021).
//
// Archivos del subsistema:
//   diagnosis.go    — clasificación de errores y escalación HITL
//   rollback.go     — orquestador de rollback
//   cleanup.go      — orquestador de limpieza
//   repair.go       — orquestador de reparación con reintentos
//   degradation.go  — manejador de estado DEGRADADA
package ficha

import (
	"fmt"
	"strings"
	"time"

	"log/slog"
)

// ── Tipos de operación ──────────────────────────────────────────────────

// LifecycleOp identifica la operación del ciclo de vida.
// Las operaciones válidas son: install, update, repair, remove.
type LifecycleOp string

const (
	OpInstall LifecycleOp = "install" // instalación inicial de una ficha
	OpUpdate  LifecycleOp = "update"  // actualización a nueva versión
	OpRepair  LifecycleOp = "repair"  // reparación desde estado DEGRADADA
	OpRemove  LifecycleOp = "remove"  // eliminación completa de una ficha
)

// LifecycleResult contiene el resultado de una operación del ciclo de vida.
// Incluye el estado anterior, nuevo estado, versión, duración y flag de compensación.
type LifecycleResult struct {
	FichaID     string        `json:"ficha_id"`
	Operation   LifecycleOp   `json:"operation"`
	Version     string        `json:"version,omitempty"`
	Success     bool          `json:"success"`
	PrevState   FichaState    `json:"prev_state"`
	NewState    FichaState    `json:"new_state"`
	Duration    time.Duration `json:"duration"`
	ExitCode    int           `json:"exit_code"`
	Error       string        `json:"error,omitempty"`
	Compensated bool          `json:"compensated"` // true si se ejecutó compensación
	Timestamp   time.Time     `json:"timestamp"`
}

// InstallResult encapsula el resultado de evaluar una instalación/actualización/reparación.
// Usado por los métodos Evaluate* para indicar el nuevo estado y las acciones requeridas.
type InstallResult struct {
	NewState      FichaState // nuevo estado según ADR-021
	NeedsRollback bool       // true si se requiere rollback a versión N-1
	NeedsCleanup  bool       // true si se requiere limpieza de artefactos
}

// ── Orquestador ─────────────────────────────────────────────────────────

// TaskDirResolver resuelve el directorio de trabajo de una ficha a partir de su ID.
// Inyectado por el servidor gRPC o CLI. Retorna "" si no se encuentra.
type TaskDirResolver func(fichaID string) string

// Lifecycle orchestrator: state transitions + timeout + compensation.
// Orquesta las transiciones de la máquina de 18 estados (ADR-021) para cada ficha,
// aplicando timeouts por operación y determinando la compensación adecuada.
//
// Cuando exec no es nil, las operaciones de ejecución (rollback, cleanup, repair)
// delegan en el Executor real. Si es nil, usan simulación (tests y desarrollo).
// K8sLabelQuerier permite listar nombres de recursos K8s con un label dado.
// Pendiente: k8s.Core no tiene ListByLabel aún — se inyecta nil hasta que se agregue.
// En tests, usar un stub que implemente la interfaz.
type K8sLabelQuerier interface {
	ListByLabel(kind, namespace, label string) ([]string, error)
}

type Lifecycle struct {
	sm              *StateMachine
	logger          *slog.Logger
	timeouts        map[LifecycleOp]time.Duration
	exec            *Executor        // ejecutor de 5 fases (nil = simulación)
	resolveTaskDir  TaskDirResolver  // resuelve fichaID → taskDir (nil = sin catálogo)
	k8sLabels       K8sLabelQuerier  // nil-safe: si nil, verifyNoResidue omite la verificación K8s
}

// SetK8sLabelQuerier inyecta el cliente K8s para verificación de residuos.
func (l *Lifecycle) SetK8sLabelQuerier(q K8sLabelQuerier) { l.k8sLabels = q }

// NewLifecycle crea un orquestador de ciclo de vida con la máquina de estados
// y los timeouts por defecto definidos en ADR-021.
// Si logger es nil, usa slog.Default().
func NewLifecycle(logger *slog.Logger) *Lifecycle {
	if logger == nil {
		logger = slog.Default()
	}
	return &Lifecycle{
		sm:       NewStateMachine(),
		logger:   logger,
		timeouts: defaultLifecycleTimeouts(),
	}
}

// defaultLifecycleTimeouts retorna los timeouts canónicos por operación según ADR-021.
// Delega en GlobalTimeoutLimits() (timeouts.go) como fuente única de verdad.
//
//	install: 30 min (la instalación inicial es la más costosa)
//	update:  15 min (actualización con backup y health check)
//	repair:  10 min (reparación con diagnóstico)
//	remove:  10 min (eliminación limpia)
func defaultLifecycleTimeouts() map[LifecycleOp]time.Duration {
	limits := GlobalTimeoutLimits()
	return map[LifecycleOp]time.Duration{
		OpInstall: limits.Install,
		OpUpdate:  limits.Update,
		OpRepair:  limits.Repair,
		OpRemove:  limits.Remove,
	}
}

// ── Instalación ─────────────────────────────────────────────────────────

// BeginInstall valida e inicia la transición a INSTALANDO desde el estado actual.
// Retorna el nuevo estado (INSTALANDO) o error si la transición no es válida.
func (l *Lifecycle) BeginInstall(currentState FichaState) (FichaState, error) {
	next, err := l.sm.BeginInstall(currentState)
	if err != nil {
		return currentState, fmt.Errorf("begin install: %w", err)
	}
	l.logger.Info("instalación iniciada", "prev_state", currentState, "new_state", next)
	return next, nil
}

// CompleteInstall finaliza la instalación con el resultado de la saga.
// success=true → INSTALADA.
// success=false y hasPreviousVersion=true → ROLLBACK.
// success=false y hasPreviousVersion=false → LIMPIEZA (primera instalación).
func (l *Lifecycle) CompleteInstall(success bool, hasPreviousVersion bool) (FichaState, bool) {
	if success {
		return StateInstalled, false
	}

	if hasPreviousVersion {
		l.logger.Warn("instalación fallida — iniciando rollback a N-1")
		return StateRollback, false
	}

	l.logger.Warn("instalación fallida — iniciando limpieza (sin versión anterior)")
	return StateCleanup, false
}

// EvaluateInstall determina el estado resultante de una instalación.
// Encapsula la lógica de decisión install→INSTALADA|ROLLBACK|LIMPIEZA.
func (l *Lifecycle) EvaluateInstall(success bool, hasPreviousVersion bool) InstallResult {
	if success {
		return InstallResult{NewState: StateInstalled}
	}

	if hasPreviousVersion {
		return InstallResult{
			NewState:      StateRollback,
			NeedsRollback: true,
		}
	}

	return InstallResult{
		NewState:     StateCleanup,
		NeedsCleanup: true,
	}
}

// ── Actualización ───────────────────────────────────────────────────────

// BeginUpdate valida e inicia la transición a ACTUALIZANDO.
// Solo es válida desde INSTALADA o ACTUALIZACION_APROBADA.
func (l *Lifecycle) BeginUpdate(currentState FichaState) (FichaState, error) {
	next, err := l.sm.BeginUpdate(currentState)
	if err != nil {
		return currentState, fmt.Errorf("begin update: %w", err)
	}
	l.logger.Info("actualización iniciada", "prev_state", currentState, "new_state", next)
	return next, nil
}

// EvaluateUpdate determina el estado resultante de una actualización.
// success=true → INSTALADA (con nueva versión).
// success=false → ROLLBACK (siempre, porque update presupone versión anterior).
func (l *Lifecycle) EvaluateUpdate(success bool) InstallResult {
	if success {
		return InstallResult{NewState: StateInstalled}
	}
	return InstallResult{
		NewState:      StateRollback,
		NeedsRollback: true, // update siempre tiene versión anterior para rollback
	}
}

// ── Reparación ─────────────────────────────────────────────────────────

// BeginRepair valida e inicia la transición a REPARANDO.
// Solo es válida desde DEGRADADA, ERROR_FISICO o ERROR_LOGICO.
func (l *Lifecycle) BeginRepair(currentState FichaState) (FichaState, error) {
	next, err := l.sm.BeginRepair(currentState)
	if err != nil {
		return currentState, fmt.Errorf("begin repair: %w", err)
	}
	l.logger.Info("reparación iniciada", "prev_state", currentState, "new_state", next)
	return next, nil
}

// EvaluateRepair determina el estado resultante de una reparación.
// success=true → INSTALADA (recuperado).
// success=false y attempt >= maxAttempts → ERROR_NO_CORREGIBLE → HITL.
// success=false y attempt < maxAttempts → REPARANDO (reintentar).
func (l *Lifecycle) EvaluateRepair(success bool, attempt int, maxAttempts int) InstallResult {
	if success {
		return InstallResult{NewState: StateInstalled}
	}

	if attempt >= maxAttempts {
		l.logger.Error("reparación agotó reintentos",
			"attempts", attempt,
			"max_attempts", maxAttempts,
		)
		return InstallResult{NewState: StateUnrecoverable}
	}

	l.logger.Warn("reparación fallida — reintentando",
		"attempt", attempt,
		"max_attempts", maxAttempts,
	)
	return InstallResult{NewState: StateRepairing}
}

// ── Eliminación ────────────────────────────────────────────────────────

// BeginRemove valida e inicia la transición a DESINSTALADA.
// Solo es válida desde INSTALADA, DEGRADADA, ERROR_FISICO, ERROR_LOGICO o PAUSADA.
func (l *Lifecycle) BeginRemove(currentState FichaState) (FichaState, error) {
	next, err := l.sm.BeginRemove(currentState)
	if err != nil {
		return currentState, fmt.Errorf("begin remove: %w", err)
	}
	l.logger.Info("eliminación iniciada", "prev_state", currentState, "new_state", next)
	return next, nil
}

// ── Timeouts ────────────────────────────────────────────────────────────

// TimeoutFor retorna el timeout configurado para una operación del ciclo de vida.
// Si la operación no tiene timeout configurado, retorna el límite global de install
// (30 min) como default seguro según ADR-021.
func (l *Lifecycle) TimeoutFor(op LifecycleOp) time.Duration {
	if t, ok := l.timeouts[op]; ok {
		return t
	}
	return GlobalTimeoutLimits().Install // 30 min — default conservador
}

// SetTimeout configura el timeout para una operación específica del ciclo de vida.
// Usar para ajustar timeouts por tipo de ficha (StatefulSet puede necesitar más tiempo).
func (l *Lifecycle) SetTimeout(op LifecycleOp, d time.Duration) {
	l.timeouts[op] = d
}

// ── Flujo de actualización completo (F11.B.3) ───────────────────────────

// UpdateAvailability determina si hay una actualización disponible comparando versiones.
// Retorna true y ACTUALIZACION_DISP si target > current.
func (l *Lifecycle) UpdateAvailability(current, target Version) (bool, FichaState) {
	if target.GreaterThan(current) {
		l.logger.Info("nueva versión detectada",
			"current", current.String(),
			"target", target.String(),
		)
		return true, StateUpdateAvailable
	}
	return false, StateInstalled
}

// ApproveUpdate evalúa si la actualización puede aplicarse de forma segura.
// Verifica: compatibilidad semántica (IsCompatibleUpgrade) y health actual OK.
// Retorna ACTUALIZACION_APROBADA si es segura, o error con la razón del rechazo.
func (l *Lifecycle) ApproveUpdate(current, target Version, currentHealthOK bool) (FichaState, error) {
	if err := IsCompatibleUpgrade(current, target); err != nil {
		l.logger.Warn("actualización rechazada por compatibilidad",
			"current", current.String(),
			"target", target.String(),
			"reason", err.Error(),
		)
		return StateUpdateAvailable, fmt.Errorf("actualización no compatible: %w", err)
	}

	if !currentHealthOK {
		l.logger.Warn("actualización rechazada por health degradado")
		return StateUpdateAvailable, fmt.Errorf("health actual no es OK — repare antes de actualizar")
	}

	l.logger.Info("actualización aprobada",
		"from", current.String(),
		"to", target.String(),
		"needs_migration", NeedsMigration(current, target),
		"needs_backup", NeedsBackup(current, target),
	)
	return StateUpdateApproved, nil
}

// RejectUpdate revierte ACTUALIZACION_DISP a INSTALADA cuando el operador
// decide no aplicar la actualización.
func (l *Lifecycle) RejectUpdate() FichaState {
	l.logger.Info("actualización rechazada por el operador")
	return StateInstalled
}

// CompleteUpdate finaliza la actualización con el resultado de la saga.
// success=true → INSTALADA (con nueva versión).
// success=false → ROLLBACK a la versión anterior (prevVersion).
func (l *Lifecycle) CompleteUpdate(success bool, prevVersion Version) (FichaState, bool) {
	if success {
		l.logger.Info("actualización completada exitosamente")
		return StateInstalled, false
	}

	l.logger.Warn("actualización fallida — iniciando rollback",
		"rollback_to", prevVersion.String(),
	)
	return StateRollback, true
}

// ── Flujo de degradación ───────────────────────────────────────────────

// Degrade transiciona de INSTALADA a DEGRADADA cuando los health checks
// fallan consecutivamente por encima del umbral configurado.
func (l *Lifecycle) Degrade(consecutiveFailures int, threshold int) (FichaState, error) {
	if consecutiveFailures < threshold {
		return StateInstalled, fmt.Errorf("no se cumplen las condiciones para degradar (%d < %d fallos)",
			consecutiveFailures, threshold)
	}
	l.logger.Warn("ficha degradada por health failures",
		"consecutive_failures", consecutiveFailures,
		"threshold", threshold,
	)
	return StateDegraded, nil
}

// RecoverAfterRepair transiciona de REPARANDO a INSTALADA tras reparación exitosa.
func (l *Lifecycle) RecoverAfterRepair() FichaState {
	l.logger.Info("ficha recuperada tras reparación exitosa")
	return StateInstalled
}

// ── Flujo de limpieza y rollback ────────────────────────────────────────

// CleanupComplete finaliza la limpieza de artefactos y retorna la ficha a PENDIENTE,
// dejándola disponible para una nueva instalación.
func (l *Lifecycle) CleanupComplete() FichaState {
	l.logger.Info("limpieza completada — ficha vuelve a PENDIENTE")
	return StatePending
}

// RollbackComplete finaliza el rollback tras restaurar backup de la versión N-1.
// success=true → INSTALADA (versión anterior restaurada).
// success=false → ERROR_NO_CORREGIBLE (requiere HITL).
func (l *Lifecycle) RollbackComplete(success bool) FichaState {
	if success {
		l.logger.Info("rollback exitoso — versión anterior restaurada")
		return StateInstalled
	}
	l.logger.Error("rollback fallido — requiere intervención humana")
	return StateUnrecoverable
}

// ── Helpers ─────────────────────────────────────────────────────────────

// VersionLabel construye la etiqueta de versión para el estado INSTALADA_vX.Y.Z.
// Si version es vacía o "latest", retorna solo "INSTALLED".
func VersionLabel(version string) string {
	if version == "" || version == "latest" {
		return "INSTALLED"
	}
	return fmt.Sprintf("INSTALLED_v%s", version)
}

// SetExecutor inyecta el Ejecutor de 5 fases y el resolvedor de rutas en el orquestador.
// Cuando ambos son no-nil, ExecuteRollback/ExecuteCleanup/ExecuteRepair delegan en el
// Executor real en vez de simular. Usar nil para tests unitarios.
func (l *Lifecycle) SetExecutor(exec *Executor, resolver TaskDirResolver) {
	l.exec = exec
	l.resolveTaskDir = resolver
}

// HasExecutor retorna true si el orquestador tiene un Ejecutor real cableado.
func (l *Lifecycle) HasExecutor() bool {
	return l.exec != nil && l.resolveTaskDir != nil
}

// StateMachine retorna la máquina de estados subyacente del orquestador.
// Útil para consultar transiciones válidas y estados desde otros componentes.
func (l *Lifecycle) StateMachine() *StateMachine {
	return l.sm
}

// containsAny informa si s contiene al menos una de las subcadenas dadas (case-sensitive).
func containsAny(s string, substrs ...string) bool {
	for _, sub := range substrs {
		if strings.Contains(s, sub) {
			return true
		}
	}
	return false
}
