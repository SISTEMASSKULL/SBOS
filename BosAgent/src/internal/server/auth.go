package server

// auth.go — F6.1: autenticación de métodos JSON-RPC destructivos.
//
// Esquema (Manual JSON-RPC Parte 2 §3 — norma del plan BOS-REPAIR):
//
//	Authorization: Basic base64(user:user_id:session_token)
//
// Política deny-by-default (Zero Trust — SBOS-031, NIST 800-207):
//   - Método destructivo sin credencial válida → -32600 Unauthorized.
//   - Credencial válida pero RBAC niega el método → -32005 GovernanceDeny.
//   - Métodos de lectura no requieren credencial (el Unix socket 0660
//     grupo bosagent ya es la barrera de transporte — ADR-019).
//
// Validación del token en Fase A (ADR-015): si existe el archivo
// /etc/bos/rpc-token (0600), el token DEBE coincidir (comparación en tiempo
// constante). Sin archivo, basta credencial completa + autorización RBAC.
// En Fase B la validación delega en bAuth (BauthRBAC.ValidateToken).

import (
	"crypto/subtle"
	"encoding/base64"
	"net/http"
	"os"
	"strings"

	"bos/internal/paths"
)

// rpcTokenPath es el archivo del token compartido del plano JSON-RPC.
// Sobreescribible vía BOS_RPC_TOKEN_FILE (tests y staging).
const rpcTokenPath = paths.RpcTokenFile

// rpcAuth transporta las credenciales extraídas del header Authorization.
// Inmutable tras parseRPCAuth — segura para uso concurrente en batch (F6.3).
type rpcAuth struct {
	User  string // nombre de usuario o daemon llamador (biedata, bauth, …)
	ID    string // user_id según el esquema del manual (informativo en Fase A)
	Token string // token de sesión
}

// destructiveMethods es el conjunto de métodos que mutan estado del sistema
// y por tanto exigen credencial (F6.1).
var destructiveMethods = map[string]bool{
	"bos.ficha.install":                 true,
	"bos.ficha.update":                  true,
	"bos.ficha.repair":                  true,
	"bos.ficha.remove":                  true,
	"bos.bootstrap.start":               true,
	"bos.bootstrap.resume":              true,
	"bos.saga.execute":                  true,
	"bos.ctx.invalidate":                true,
	"bos.ctx.tenant.suspend":            true,
	"bos.bootstrap.pg_auxiliar_start":   true,
	"bos.bootstrap.pg_auxiliar_sync":    true,
	"bos.bootstrap.pg_auxiliar_cleanup": true,
	// bos.k8s.* — Operator Soberano (F9.5): todo mutador del cluster
	"bos.k8s.node.cordon":   true,
	"bos.k8s.node.uncordon": true,
	"bos.k8s.node.drain":    true,
	"bos.k8s.pod.evict":     true,
	"bos.k8s.pod.restart":   true,
	"bos.k8s.scale":         true,
	"bos.k8s.rollout.undo":  true,
	"bos.k8s.resources.set": true,
	// bos.maintenance.* (F9.6)
	"bos.maintenance.start":  true,
	"bos.maintenance.cancel": true,
	// bos.ai.* (F10.8): run/confirm pueden disparar escrituras vía el agente
	"bos.ai.run":     true,
	"bos.ai.confirm": true,
}

// parseRPCAuth extrae las credenciales del header Authorization.
// Formato: "Basic base64(user:user_id:token)". Retorna rpcAuth vacío si el
// header falta o no es parseable — la decisión de rechazo es de authorizeRPC.
func parseRPCAuth(r *http.Request) rpcAuth {
	h := r.Header.Get("Authorization")
	if h == "" {
		return rpcAuth{}
	}
	const prefix = "Basic "
	if !strings.HasPrefix(h, prefix) {
		return rpcAuth{}
	}
	raw, err := base64.StdEncoding.DecodeString(strings.TrimPrefix(h, prefix))
	if err != nil {
		return rpcAuth{}
	}
	parts := strings.SplitN(string(raw), ":", 3)
	if len(parts) != 3 {
		return rpcAuth{}
	}
	return rpcAuth{User: parts[0], ID: parts[1], Token: parts[2]}
}

// authorizeRPC decide si la llamada puede ejecutarse (F6.1).
// ADR-006 / F4.4: sin RBAC propio. La autorización se hereda de:
//   - Ubuntu: permisos del Unix socket (solo root/bosagent)
//   - Kubernetes: RBAC del cluster (kubectl via kubeconfig)
//   - Token compartido: /etc/bos/rpc-token para métodos destructivos
func (s *Server) authorizeRPC(method string, auth rpcAuth) *RPCError {
	if !destructiveMethods[method] {
		return nil
	}
	// Validar token compartido si está configurado. Sin token → acceso abierto
	// (la seguridad real está en los permisos del Unix socket 0660 root:bosagent).
	if !validSharedToken(auth.Token) {
		return rpcError(ErrInvalidRequest, "Unauthorized: token inválido")
	}
	return nil
}

// validSharedToken compara el token contra /etc/bos/rpc-token si el archivo
// existe. Comparación en tiempo constante (crypto/subtle) para no filtrar
// longitud ni prefijos por timing.
//
// A-06: fail-close — archivo ausente o ilegible = sin autorización.
// Para desarrollo sin token: BOS_NO_RPC_TOKEN=true.
func validSharedToken(token string) bool {
	// Modo desarrollo explícito: permite acceso sin token cuando se declara sin ambigüedad
	if os.Getenv("BOS_NO_RPC_TOKEN") == "true" {
		return true
	}
	path := os.Getenv("BOS_RPC_TOKEN_FILE")
	if path == "" {
		path = rpcTokenPath
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return false // A-06: fail-close — archivo ausente = sin autorización
	}
	want := strings.TrimSpace(string(data))
	if want == "" {
		return false // A-06: archivo vacío = token no configurado = denegar
	}
	return subtle.ConstantTimeCompare([]byte(want), []byte(token)) == 1
}
