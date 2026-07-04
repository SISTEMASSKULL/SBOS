// Package security — interfaces.go: contratos de RBAC e Identidad.
// RBACProvider se mantiene como interfaz para polimorfismo (FileRBAC / BauthRBAC).
// La implementación propia en roles.json se delega progresivamente a Ubuntu PAM +
// K8s RBAC según ADR-006 — ver _legacy/ para el rbac_provider.go original.
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
const (
	RoleAdmin    = "admin"
	RoleOperator = "operator"
	RoleReadonly = "readonly"
)

// DefaultCommandsByRole mapea cada rol canónico a sus prefijos de comandos permitidos.
// RoleAdmin recibe "*" (todo). Usado por FileRBAC como fallback cuando roles.json
// no define explícitamente los comandos de un rol.
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
