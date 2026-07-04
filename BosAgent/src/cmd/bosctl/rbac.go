// Package main — rbac.go: helpers de RBAC para bosctl (F4.3/F4.5).
// getRBAC usa sync.Once para eliminar la race condition P15.
package main

import (
	"fmt"
	"os"
	"sync"
	"time"

	"bos/internal/security"
	"bos/internal/paths"
)

// rbacOnce + rbacInst: inicialización thread-safe del proveedor RBAC (P15 fix).
var (
	rbacOnce sync.Once
	rbacInst security.RBACProvider
)

// getRBAC retorna el proveedor RBAC compartido, inicializado una sola vez.
func getRBAC() security.RBACProvider {
	rbacOnce.Do(func() {
		fileRBAC, err := security.NewFileRBAC(paths.RBACRoles)
		if err != nil {
			return
		}
		if os.Getenv("BOS_BAUTH_ENABLED") == "true" || os.Getenv("BOS_BAUTH_ENABLED") == "1" {
			socketPath := os.Getenv("BOS_BAUTH_SOCKET")
			if socketPath == "" {
				socketPath = "/run/bos/bauth.sock"
			}
			rbacInst = security.NewBauthRBAC(security.BauthRBACConfig{
				Enabled:    true,
				SocketPath: socketPath,
				Timeout:    2000 * time.Millisecond,
				Fallback:   fileRBAC,
			})
		} else {
			rbacInst = fileRBAC
		}
	})
	return rbacInst
}

// rbacUser retorna la identidad desde BOS_USER (vacío = caller confiable).
func rbacUser() string { return os.Getenv("BOS_USER") }

// rbacGuard verifica si el usuario está autorizado para cmd. Retorna 8 si denegado.
func rbacGuard(cmd string) int {
	user := rbacUser()
	if user == "" {
		return 0
	}
	rbac := getRBAC()
	if rbac == nil {
		return 0
	}
	if err := rbac.CanExecute(user, cmd); err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: access denied: %v\n", err)
		return 8
	}
	return 0
}
