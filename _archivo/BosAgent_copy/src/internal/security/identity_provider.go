package security

// IdentityProvider defines the contract for user and role management in BOS.
// FileRBAC implements it today (reads/writes /etc/bos/rbac/roles.json).
// BauthRBAC will implement it tomorrow when BauthAgent exposes user management endpoints.
// For now, BauthRBAC delegates identity operations to its FileRBAC fallback.
type IdentityProvider interface {
	SetRole(user, role string) error
	RemoveUser(user string) error
	ListUsers() (map[string]string, error)
	ListRoles() ([]string, error)
	ValidateUser(user string) error
}
