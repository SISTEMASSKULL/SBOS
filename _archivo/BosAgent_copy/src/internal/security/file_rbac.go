package security

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// FileRBAC implements RBACProvider backed by /etc/bos/rbac/roles.json.
// Fase A implementation. Certifiable without external dependencies.
type FileRBAC struct {
	path  string
	roles map[string][]string // role → allowed commands
	users map[string]string   // user → role
}

// NewFileRBAC loads roles.json from path. If the file doesn't exist, creates
// a default config with admin/operator/readonly and saves it.
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

// CanExecute returns nil if the user's role allows executing cmd.
func (f *FileRBAC) CanExecute(user, cmd string) error {
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

// GetRole returns the role assigned to user, or "" if none.
func (f *FileRBAC) GetRole(user string) string {
	return f.users[user]
}

// SetRole assigns a role to a user. Returns error if role is unknown.
func (f *FileRBAC) SetRole(user, role string) error {
	if !ValidRole(role) {
		return fmt.Errorf("file_rbac: unknown role %q (valid: admin, operator, readonly)", role)
	}
	f.users[user] = role
	return f.save()
}

// RemoveUser deletes a user from the RBAC config. No-op if user doesn't exist.
func (f *FileRBAC) RemoveUser(user string) error {
	delete(f.users, user)
	return f.save()
}

// ListUsers returns a copy of the user → role mapping.
func (f *FileRBAC) ListUsers() (map[string]string, error) {
	result := make(map[string]string, len(f.users))
	for k, v := range f.users {
		result[k] = v
	}
	return result, nil
}

// ListRoles returns the names of all defined roles.
func (f *FileRBAC) ListRoles() ([]string, error) {
	roles := make([]string, 0, len(f.roles))
	for r := range f.roles {
		roles = append(roles, r)
	}
	return roles, nil
}

// ValidateUser returns nil if the user exists in the RBAC config.
func (f *FileRBAC) ValidateUser(user string) error {
	if _, ok := f.users[user]; !ok {
		return fmt.Errorf("user %q not found", user)
	}
	return nil
}
