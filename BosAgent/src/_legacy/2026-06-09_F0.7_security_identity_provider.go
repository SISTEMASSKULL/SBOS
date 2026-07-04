// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// SOLO REFERENCIA DE LÓGICA — NO IMPORTAR, NO COPIAR COMO ESTÁ.
//
// Origen: internal/security/identity_provider.go (archivado en F0.7)
// Destino: bAuth asume identidad (F4.4)
// Razón: IdentityProvider propio viola ADR-006 — bAuth es el proveedor canónico.

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
