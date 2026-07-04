package security

// RBACProvider defines the contract for role-based access control in BOS.
// FileRBAC implements it today (Fase A, uses /etc/bos/rbac/roles.json).
// BauthRBAC will implement it tomorrow (via WebSocket to BauthAgent).
// All clients (bosctl, bos main, server/api.go) depend only on this interface.
type RBACProvider interface {
	// CanExecute returns nil if the user is authorized to run the command.
	CanExecute(user string, cmd string) error
	// GetRole returns the role name assigned to a user, or "" if none.
	GetRole(user string) string
}

// The three canonical roles defined by BOS RBAC.
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

// ValidRole returns true if role is one of the three canonical roles.
func ValidRole(role string) bool {
	switch role {
	case RoleAdmin, RoleOperator, RoleReadonly:
		return true
	}
	return false
}
