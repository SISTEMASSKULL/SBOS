package security

// IdentityProvider define el contrato para gestión de usuarios y roles en BOS.
// FileRBAC lo implementa actualmente (lee/escribe /etc/bos/rbac/roles.json).
// BauthRBAC lo implementará cuando BauthAgent exponga endpoints de gestión de usuarios.
// Por ahora, BauthRBAC delega operaciones de identidad a su FileRBAC fallback.
type IdentityProvider interface {
	SetRole(user, role string) error
	RemoveUser(user string) error
	ListUsers() (map[string]string, error)
	ListRoles() ([]string, error)
	ValidateUser(user string) error
}
