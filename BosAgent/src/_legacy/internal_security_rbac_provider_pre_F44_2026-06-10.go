//go:build ignore

// ELIMINADO F4.4: reemplazado por internal/security/interfaces.go (ADR-006).
// Ubuntu PAM + K8s RBAC delegarán la autorización externamente.
package security

// RBACProvider define el contrato para control de acceso basado en roles en BOS.
// FileRBAC lo implementa actualmente (Fase A, usa /etc/bos/rbac/roles.json).
// BauthRBAC lo implementará vía WebSocket a BauthAgent.
// Todos los clientes (bosctl, bos main, server/api.go) dependen solo de esta interfaz.
type RBACProvider interface {
	// CanExecute retorna nil si el usuario está autorizado a ejecutar el comando.
	CanExecute(user string, cmd string) error
	// GetRole retorna el nombre del rol asignado al usuario, o "" si no tiene.
	GetRole(user string) string
}

// Los tres roles canónicos del RBAC de BOS.
// RoleAdmin: acceso total a todos los comandos.
// RoleOperator: operaciones day-1/day-2 sin acceso a configuración de identidad.
// RoleReadonly: solo lectura y consulta — nunca puede ejecutar repair ni install.
const (
	RoleAdmin    = "admin"
	RoleOperator = "operator"
	RoleReadonly = "readonly"
)

// DefaultCommandsByRole maps each canonical role to its allowed command prefixes.
// RoleAdmin gets "*" (everything). Used by FileRBAC as fallback when roles.json
// doesn't define a role's commands explicitly.
var DefaultCommandsByRole = map[string][]string{
	RoleAdmin:    {"*"},
	RoleOperator: {"install", "remove", "repair", "top", "logs", "ask", "diagnose", "app", "security audit", "health", "identity whoami", "identity list"},
	RoleReadonly: {"status", "top", "logs", "health", "app list", "explain", "identity whoami", "identity list"},
}

// ValidRole retorna true si el rol es uno de los tres roles canónicos.
func ValidRole(role string) bool {
	switch role {
	case RoleAdmin, RoleOperator, RoleReadonly:
		return true
	}
	return false
}
