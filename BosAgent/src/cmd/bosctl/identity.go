package main

import (
	"fmt"
	"os"

	"bos/internal/security"
)

// cmdIdentity es el dispatcher del subcomando "bosctl identity".
// Fase B — Gestión de identidad (FileRBAC-backed, BauthRBAC-ready).
func cmdIdentity(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "bosctl: identity requires a subcommand: whoami, users, roles, set-role, revoke")
		return 2
	}

	switch args[0] {
	case "whoami":
		return cmdIdentityWhoami(args[1:])
	case "users":
		return cmdIdentityUsers(args[1:])
	case "roles":
		return cmdIdentityRoles(args[1:])
	case "set-role":
		return cmdIdentitySetRole(args[1:])
	case "revoke":
		return cmdIdentityRevoke(args[1:])
	default:
		fmt.Fprintf(os.Stderr, "bosctl: unknown identity subcommand: %s\n", args[0])
		return 2
	}
}

// cmdIdentityWhoami muestra el BOS_USER actual y el rol resuelto por RBAC.
func cmdIdentityWhoami(args []string) int {
	user := rbacUser()
	if user == "" {
		fmt.Println("identity: unauthenticated (BOS_USER not set)")
		fmt.Println("running as trusted/root caller — no RBAC restrictions")
		return 0
	}

	rbac := getRBAC()
	if rbac == nil {
		fmt.Printf("user: %s\nrole: unknown (RBAC not available)\n", user)
		return 1
	}

	role := rbac.GetRole(user)
	if role == "" {
		fmt.Printf("user: %s\nrole: none (user not found in RBAC)\n", user)
	} else {
		fmt.Printf("user: %s\nrole: %s\n", user, role)
	}
	return 0
}

// cmdIdentityUsers lista todos los usuarios y sus roles registrados en el RBAC.
func cmdIdentityUsers(args []string) int {
	idp := getIdentityProvider()
	if idp == nil {
		fmt.Fprintln(os.Stderr, "bosctl: identity provider not available")
		return 10
	}

	users, err := idp.ListUsers()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: cannot list users: %v\n", err)
		return 1
	}

	if len(users) == 0 {
		fmt.Println("no users registered in RBAC")
		return 0
	}

	fmt.Println("user\trole")
	fmt.Println("----\t----")
	for user, role := range users {
		fmt.Printf("%s\t%s\n", user, role)
	}
	return 0
}

// cmdIdentityRoles lista todos los roles definidos en el proveedor RBAC.
func cmdIdentityRoles(args []string) int {
	idp := getIdentityProvider()
	if idp == nil {
		fmt.Fprintln(os.Stderr, "bosctl: identity provider not available")
		return 10
	}

	roles, err := idp.ListRoles()
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: cannot list roles: %v\n", err)
		return 1
	}

	for _, role := range roles {
		fmt.Printf("%s\n", role)
	}
	return 0
}

// cmdIdentitySetRole asigna un rol a un usuario. Requiere privilegio RBAC "admin".
func cmdIdentitySetRole(args []string) int {
	if len(args) < 2 {
		fmt.Fprintln(os.Stderr, "bosctl: identity set-role requires <user> <role>")
		return 2
	}
	user, role := args[0], args[1]

	if code := rbacGuard("identity set-role"); code != 0 {
		return code
	}

	if !security.ValidRole(role) {
		fmt.Fprintf(os.Stderr, "bosctl: invalid role %q (valid: admin, operator, readonly)\n", role)
		return 2
	}

	idp := getIdentityProvider()
	if idp == nil {
		fmt.Fprintln(os.Stderr, "bosctl: identity provider not available")
		return 10
	}

	if err := idp.SetRole(user, role); err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: cannot set role: %v\n", err)
		return 1
	}

	fmt.Printf("role %s assigned to user %s\n", role, user)
	return 0
}

// cmdIdentityRevoke elimina un usuario del RBAC (revoca todo acceso). Requiere privilegio "admin".
func cmdIdentityRevoke(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "bosctl: identity revoke requires <user>")
		return 2
	}
	user := args[0]

	if code := rbacGuard("identity revoke"); code != 0 {
		return code
	}

	idp := getIdentityProvider()
	if idp == nil {
		fmt.Fprintln(os.Stderr, "bosctl: identity provider not available")
		return 10
	}

	if err := idp.RemoveUser(user); err != nil {
		fmt.Fprintf(os.Stderr, "bosctl: cannot revoke user: %v\n", err)
		return 1
	}

	fmt.Printf("user %s revoked\n", user)
	return 0
}

// getIdentityProvider retorna el IdentityProvider del RBAC activo (FileRBAC o BauthRBAC bridge).
func getIdentityProvider() security.IdentityProvider {
	rbac := getRBAC()
	if rbac == nil {
		return nil
	}
	idp, ok := rbac.(security.IdentityProvider)
	if !ok {
		return nil
	}
	return idp
}
