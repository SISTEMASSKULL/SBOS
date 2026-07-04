package server

// ws_consts.go — Constantes del protocolo WebSocket BOS (M-10, F6).

const (
	// DefaultBroadcastBuf es el buffer del canal de broadcast del Hub.
	DefaultBroadcastBuf = 256
	// DefaultClientSendBuf es el buffer del canal send de cada Client.
	DefaultClientSendBuf = 64
	// DefaultLogTailLines son las líneas por defecto para ficha_log tail.
	DefaultLogTailLines = 80
	// DefaultAuditTailLines son las líneas por defecto para audit log tail.
	DefaultAuditTailLines = 50
	// DaemonVersion es la versión del daemon bos expuesta en health/status.
	DaemonVersion = "0.1.0"
)

// ── Acciones del dispatcher WebSocket ────────────────────────────────

const (
	// Ficha lifecycle
	ActionFichaInstall = "ficha_install"
	ActionFichaUpdate  = "ficha_update"
	ActionFichaRepair  = "ficha_repair"
	ActionFichaRemove  = "ficha_remove"
	ActionFichaProbe   = "ficha_probe"
	ActionFichaList    = "ficha_list"
	ActionFichaDetail  = "ficha_detail"
	ActionFichaLogTail = "ficha_log_tail"

	// Bootstrap
	ActionBootstrapStart = "bootstrap_start"

	// Identity
	ActionIdentityWhoami    = "identity_whoami"
	ActionIdentityListUsers = "identity_list_users"
	ActionIdentityListRoles = "identity_list_roles"
	ActionIdentitySetRole   = "identity_set_role"
	ActionIdentityRevoke    = "identity_revoke"

	// Release
	ActionReleaseCheck = "release_check"
	ActionReleaseList  = "release_list"

	// PG Auxiliar
	ActionPgAuxStart   = "pg_auxiliar_start"
	ActionPgAuxSync    = "pg_auxiliar_sync"
	ActionPgAuxStatus  = "pg_auxiliar_status"
	ActionPgAuxCleanup = "pg_auxiliar_cleanup"

	// System
	ActionHealth        = "health"
	ActionStatus        = "status"
	ActionShutdown      = "shutdown"
	ActionSecurityScan  = "security_scan"
	ActionSecurityAudit = "security_audit"
)

// ── Tipos de eventos (broadcast) ─────────────────────────────────────

// EventType es el tipo de evento WebSocket emitido por el Hub.
type EventType string

const (
	EventSagaStart EventType = "saga_start"
	EventSagaOK    EventType = "saga_ok"
	EventSagaFail  EventType = "saga_fail"
	EventStepStart EventType = "step_start"
	EventStepOK    EventType = "step_ok"
	EventStepFail  EventType = "step_fail"
	EventHealth    EventType = "health_update"
	EventReload    EventType = "reload"
	EventReconcile EventType = "reconcile"

	// Fase B — Identity (eventos broadcast)
	EventIdentityConnected EventType = "identity_connected"
	EventIdentityChanged   EventType = "identity_changed"
	EventIdentityWhoami    EventType = "identity_whoami"
	EventIdentityListUsers EventType = "identity_list_users"
	EventIdentityListRoles EventType = "identity_list_roles"
	EventIdentitySetRole   EventType = "identity_set_role"
	EventIdentityRevoke    EventType = "identity_revoke"

	// PG Auxiliar Anti-Pérdida
	EventPgAuxiliarStart EventType = "pg_auxiliar_start"
	EventPgAuxiliarStep  EventType = "pg_auxiliar_step"
	EventPgAuxiliarOK    EventType = "pg_auxiliar_ok"
	EventPgAuxiliarFail  EventType = "pg_auxiliar_fail"
	EventPgAuxiliarSync  EventType = "pg_auxiliar_sync"

	// SKULL Release Plane
	EventReleaseCheck     EventType = "release_check"
	EventReleaseAvailable EventType = "release_available"
	EventReleaseApplied   EventType = "release_applied"

	// Log en tiempo real desde scripts bash
	EventFichaLog EventType = "ficha_log"
)
