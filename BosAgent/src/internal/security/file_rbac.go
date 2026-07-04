package security

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

// FileRBAC implementa RBACProvider e IdentityProvider respaldado por /etc/bos/rbac/roles.json.
// Implementación Fase A — certificable sin dependencias externas.
//
// Thread safety: mu serializa todos los accesos a roles y users — seguro para goroutines concurrentes.
// Las operaciones de escritura (SetRole, RemoveUser) persisten atómicamente via tmp+rename.
type FileRBAC struct {
	mu    sync.RWMutex
	path  string
	roles map[string][]string // role → allowed commands
	users map[string]string   // user → role
}

// NewFileRBAC carga roles.json desde path. Si el archivo no existe, crea la configuración
// por defecto (admin/operator/readonly con comandos predefinidos) y la persiste.
//
// Recibe:
//   - path: string — ruta absoluta a roles.json. P16.
//
// Retorna: (*FileRBAC, error). Error si el archivo existe pero es inválido.
//
// Callers conocidos:
//   - cmd/bos/main.go — inicializa FileRBAC en runNormal().
//   - internal/security/bauth_rbac.go — crea fallback si Fallback no es *FileRBAC.
func NewFileRBAC(path string) (*FileRBAC, error) {
	f := &FileRBAC{path: path}
	if _, err := os.Stat(path); os.IsNotExist(err) {
		f.roles = DefaultCommandsByRole
		f.users = map[string]string{}
		if err := f.save(); err != nil {
			return nil, fmt.Errorf("file_rbac: create default %s: %w", path, err)
		}
		return f, nil
	}
	if err := f.load(); err != nil {
		return nil, err
	}
	return f, nil
}

// load reads and validates roles.json from disk.
func (f *FileRBAC) load() error {
	data, err := os.ReadFile(f.path)
	if err != nil {
		return fmt.Errorf("file_rbac: read %s: %w", f.path, err)
	}
	var cfg struct {
		Roles map[string][]string `json:"roles"`
		Users map[string]string   `json:"users"`
	}
	if err := json.Unmarshal(data, &cfg); err != nil {
		return fmt.Errorf("file_rbac: parse %s: %w", f.path, err)
	}
	f.roles = cfg.Roles
	if f.roles == nil {
		f.roles = DefaultCommandsByRole
	}
	f.users = cfg.Users
	if f.users == nil {
		f.users = make(map[string]string)
	}
	return nil
}

// save writes the current RBAC config atomically (tmp → rename).
func (f *FileRBAC) save() error {
	cfg := struct {
		Roles map[string][]string `json:"roles"`
		Users map[string]string   `json:"users"`
	}{Roles: f.roles, Users: f.users}

	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	tmp := f.path + ".tmp"
	if err := os.MkdirAll(filepath.Dir(f.path), 0755); err != nil {
		return err
	}
	if err := os.WriteFile(tmp, data, 0600); err != nil {
		return err
	}
	return os.Rename(tmp, f.path)
}

// CanExecute retorna nil si el rol del usuario permite ejecutar el comando.
// Verifica prefijos de comando — "repair" permite "repair --target=os".
//
// Efectos secundarios: ninguno — solo lectura en memoria.
func (f *FileRBAC) CanExecute(user, cmd string) error {
	f.mu.RLock()
	defer f.mu.RUnlock()
	roleName, ok := f.users[user]
	if !ok {
		return fmt.Errorf("rbac: user %q has no assigned role", user)
	}
	cmds, ok := f.roles[roleName]
	if !ok {
		return fmt.Errorf("rbac: role %q not defined for user %q", roleName, user)
	}
	if len(cmds) == 1 && cmds[0] == "*" {
		return nil
	}
	for _, prefix := range cmds {
		if strings.HasPrefix(cmd, prefix) {
			return nil
		}
	}
	return fmt.Errorf("rbac: insufficient permissions (user=%s role=%s cmd=%s)", user, roleName, cmd)
}

// GetRole retorna el rol asignado al usuario, o "" si no tiene rol.
func (f *FileRBAC) GetRole(user string) string {
	f.mu.RLock()
	defer f.mu.RUnlock()
	return f.users[user]
}

// SetRole asigna un rol a un usuario y persiste el cambio.
// Retorna error si el rol no es uno de los tres roles canónicos (admin/operator/readonly).
//
// Efectos secundarios: escribe roles.json atómicamente (tmp+rename).
func (f *FileRBAC) SetRole(user, role string) error {
	if !ValidRole(role) {
		return fmt.Errorf("file_rbac: unknown role %q (valid: admin, operator, readonly)", role)
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.users[user] = role
	return f.save()
}

// RemoveUser elimina un usuario del RBAC. No-op si el usuario no existe.
// Efectos secundarios: escribe roles.json atómicamente.
func (f *FileRBAC) RemoveUser(user string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	delete(f.users, user)
	return f.save()
}

// ListUsers retorna una copia del mapeo usuario → rol.
// Retorna copia — modificarla no afecta el FileRBAC.
func (f *FileRBAC) ListUsers() (map[string]string, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()
	result := make(map[string]string, len(f.users))
	for k, v := range f.users {
		result[k] = v
	}
	return result, nil
}

// ListRoles retorna los nombres de todos los roles definidos en el RBAC.
func (f *FileRBAC) ListRoles() ([]string, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()
	roles := make([]string, 0, len(f.roles))
	for r := range f.roles {
		roles = append(roles, r)
	}
	return roles, nil
}

// ValidateUser retorna nil si el usuario existe en el RBAC, error descriptivo si no.
func (f *FileRBAC) ValidateUser(user string) error {
	f.mu.RLock()
	defer f.mu.RUnlock()
	if _, ok := f.users[user]; !ok {
		return fmt.Errorf("user %q not found", user)
	}
	return nil
}
