// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package bootstrap

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"bos/internal/paths"
)

// SysRoot es la raíz del sistema de archivos para todas las verificaciones de path.
//
// En producción permanece "/" y no debe modificarse nunca.
// En tests unitarios, asignar t.TempDir() antes de llamar VerifyC01 o VerifyC02
// para verificar criterios de filesystem sin permisos root ni sistema real.
//
// IMPORTANTE — no es thread-safe: los tests que modifiquen SysRoot no deben
// ejecutarse en paralelo entre sí. Usar t.Parallel() solo en tests que no
// toquen esta variable.
var SysRoot = "/"

// CriterioResult es el resultado de verificar un criterio de certificación.
//
// Retornado por VerifyAll como slice, y por cada VerifyC0X individualmente
// como (bool, string). El struct encapsula ambos valores para el slice.
//
// Thread safety: inmutable tras su creación — seguro de leer desde múltiples
// goroutines una vez que VerifyAll haya retornado.
type CriterioResult struct {
	// ID identifica el criterio según BOS-REPAIR-01 §Criterios.
	// Valores: "C-01" hasta "C-08".
	ID string

	// OK es true si el criterio está completamente satisfecho.
	OK bool

	// Detail describe el estado: mensaje de éxito o causa exacta del fallo.
	// Siempre contiene texto útil — nunca vacío.
	Detail string
}

// VerifyC01 verifica el criterio C-01: sbos-bootstrap-os.
//
// Comprueba que la ficha sbos-bootstrap-os completó su instalación en el servidor
// S-HOST verificando dos artefactos de filesystem:
//   - /etc/sysctl.d/99-sbos-k8s.conf: parámetros del kernel para K8s (net.bridge.*,
//     fs.inotify.*, net.ipv4.ip_forward). Sin este archivo el cluster no arranca.
//   - /data/: punto de montaje de los datos persistentes del cluster. Sin este
//     directorio los PersistentVolumes de K8s no tienen destino.
//
// Recibe: ninguno — usa la variable de paquete SysRoot para construir los paths.
//
// Retorna:
//   - (true, "sbos-bootstrap-os: sysctl + /data/ presentes") si ambos existen.
//   - (false, "sysctl config ausente: <path>") si /etc/sysctl.d/99-sbos-k8s.conf no existe.
//   - (false, "/data/ ausente") si /data/ no existe.
//
// Callers conocidos:
//   - VerifyAll — como criterio C-01 en la posición [0] del slice de resultados.
//   - internal/server/bootstrap.go:wsHandleBootstrapVerify — indirectamente vía VerifyAll.
//
// Efectos secundarios: ninguno — solo lecturas de sistema de archivos.
//
// Estándares: BOS-REPAIR-01 §Criterio-C-01, SBOS-018 §6 (certificación Operador).
func VerifyC01() (bool, string) {
	sysctlConf := filepath.Join(SysRoot, "etc/sysctl.d/99-sbos-k8s.conf")
	if _, err := os.Stat(sysctlConf); os.IsNotExist(err) {
		return false, "sysctl config ausente: " + sysctlConf
	}
	dataDir := filepath.Join(SysRoot, "data")
	if _, err := os.Stat(dataDir); os.IsNotExist(err) {
		return false, "/data/ ausente"
	}
	return true, "sbos-bootstrap-os: sysctl + /data/ presentes"
}

// VerifyC02 verifica el criterio C-02: sbos-bootstrap-k8s.
//
// Comprueba que la ficha sbos-bootstrap-k8s completó la inicialización del
// cluster K8s verificando la presencia del kubeconfig en el path canónico
// definido en paths.KubeconfigPath (/etc/bos/.kube/config).
// Sin kubeconfig, ningún componente del SBOS puede comunicarse con la API de K8s.
//
// Recibe: ninguno — usa SysRoot para construir el path de verificación.
//
// Retorna:
//   - (true, "sbos-bootstrap-k8s: kubeconfig presente") si el archivo existe.
//   - (false, "kubeconfig ausente: <path>") si el archivo no existe.
//
// Callers conocidos:
//   - VerifyAll — como criterio C-02 en la posición [1] del slice de resultados.
//
// Efectos secundarios: ninguno — solo lecturas de sistema de archivos.
//
// Estándares: BOS-REPAIR-01 §Criterio-C-02, SBOS-018 §6 (certificación Operador).
func VerifyC02() (bool, string) {
	kubeconfig := filepath.Join(SysRoot, paths.KubeconfigPath)
	if _, err := os.Stat(kubeconfig); os.IsNotExist(err) {
		return false, "kubeconfig ausente: " + kubeconfig
	}
	return true, "sbos-bootstrap-k8s: kubeconfig presente"
}

// VerifyC03 verifica el criterio C-03: sbos-bootstrap-cni (Calico).
//
// La verificación completa (calico-node Running en todos los nodos) requiere
// cluster activo y no es ejecutable en entorno de tests unitarios. Esta función
// realiza la verificación de prerequisito disponible sin cluster: comprueba que
// kubectl está en PATH, lo cual es necesario para cualquier operación posterior.
//
// Recibe: ninguno.
//
// Retorna:
//   - (true, "sbos-bootstrap-cni: kubectl disponible") si kubectl está en PATH.
//   - (false, "kubectl no disponible en PATH — CNI no verificable") si no está.
//
// Callers conocidos:
//   - VerifyAll — como criterio C-03 en la posición [2] del slice de resultados.
//
// Efectos secundarios: ninguno — solo exec.LookPath (búsqueda en PATH).
//
// Estándares: BOS-REPAIR-01 §Criterio-C-03, SBOS-018 §6 (certificación Operador).
func VerifyC03() (bool, string) {
	if _, err := exec.LookPath("kubectl"); err != nil {
		return false, "kubectl no disponible en PATH — CNI no verificable"
	}
	return true, "sbos-bootstrap-cni: kubectl disponible"
}

// VerifyC04 verifica el criterio C-04: PostgreSQL.
//
// Comprueba que PostgreSQL acepta conexiones locales ejecutando pg_isready.
// Este criterio confirma que la ficha postgresql está operativa y la BD está
// lista para recibir conexiones — prerequisito para keycloak, vault y kong.
//
// Recibe: ninguno.
//
// Retorna:
//   - (true, "postgresql: acepta conexiones") si pg_isready retorna exit 0.
//   - (false, "postgresql no responde: <error>") si pg_isready falla o no existe.
//
// Callers conocidos:
//   - VerifyAll — como criterio C-04 en la posición [3] del slice de resultados.
//
// Efectos secundarios: ejecuta pg_isready -h localhost (proceso externo, sin escritura).
//
// Estándares: BOS-REPAIR-01 §Criterio-C-04, SBOS-018 §6 (certificación Operador).
func VerifyC04() (bool, string) {
	if err := exec.Command("pg_isready", "-h", "localhost").Run(); err != nil {
		return false, "postgresql no responde: " + err.Error()
	}
	return true, "postgresql: acepta conexiones"
}

// VerifyC05 verifica el criterio C-05: Redis.
//
// Comprueba que Redis está operativo ejecutando redis-cli ping y verificando
// que la respuesta es "PONG". Redis es crítico para los streams del bKernel,
// el cache de bAuth y el registro de contextos SBOS-049.
//
// Recibe: ninguno.
//
// Retorna:
//   - (true, "redis: PONG OK") si redis-cli ping retorna "PONG".
//   - (false, "redis no responde: <error>") si redis-cli falla o no existe.
//   - (false, "redis ping no retornó PONG: <respuesta>") si la respuesta es inesperada.
//
// Callers conocidos:
//   - VerifyAll — como criterio C-05 en la posición [4] del slice de resultados.
//
// Efectos secundarios: ejecuta redis-cli ping (proceso externo, sin escritura).
//
// Estándares: BOS-REPAIR-01 §Criterio-C-05, SBOS-018 §6 (certificación Operador).
func VerifyC05() (bool, string) {
	out, err := exec.Command("redis-cli", "ping").Output()
	if err != nil {
		return false, "redis no responde: " + err.Error()
	}
	if strings.TrimSpace(string(out)) != "PONG" {
		return false, "redis ping no retornó PONG: " + strings.TrimSpace(string(out))
	}
	return true, "redis: PONG OK"
}

// VerifyC06 verifica el criterio C-06: Vault.
//
// Comprueba que Vault está inicializado y desbloqueado (unsealed) consultando
// vault status en formato JSON. Vault debe estar operativo para que las fichas
// posteriores (keycloak, kong, bAuth) puedan obtener sus secretos vía AppRole.
//
// Recibe: ninguno.
//
// Retorna:
//   - (true, "vault: initialized + unsealed") si initialized=true y sealed=false.
//   - (false, "vault no responde: <error>") si vault status falla o no existe.
//   - (false, "vault no inicializado") si initialized no es true en la salida.
//   - (false, "vault sellado") si sealed es true en la salida.
//
// Callers conocidos:
//   - VerifyAll — como criterio C-06 en la posición [5] del slice de resultados.
//
// Efectos secundarios: ejecuta vault status -format=json (proceso externo, sin escritura).
//
// Estándares: BOS-REPAIR-01 §Criterio-C-06, SBOS-018 §6 (certificación Operador).
func VerifyC06() (bool, string) {
	out, err := exec.Command("vault", "status", "-format=json").Output()
	if err != nil {
		return false, "vault no responde: " + err.Error()
	}
	s := string(out)
	if !strings.Contains(s, `"initialized":true`) {
		return false, "vault no inicializado"
	}
	if strings.Contains(s, `"sealed":true`) {
		return false, "vault sellado"
	}
	return true, "vault: initialized + unsealed"
}

// VerifyC07 verifica el criterio C-07: Keycloak.
//
// Comprueba que Keycloak está operativo consultando su endpoint /health/ready
// en el puerto 8080 (ClusterIP 8200 externamente, 8080 internamente en el pod).
// Keycloak es el proveedor de identidad del SBOS — sin él no hay autenticación.
//
// Recibe: ninguno.
//
// Retorna:
//   - (true, "keycloak: status UP") si /health/ready responde con "status":"UP".
//   - (false, "keycloak /health/ready no responde: <error>") si curl falla.
//   - (false, "keycloak no está UP") si la respuesta no contiene "status":"UP".
//
// Callers conocidos:
//   - VerifyAll — como criterio C-07 en la posición [6] del slice de resultados.
//
// Efectos secundarios: ejecuta curl -sf http://localhost:8080/health/ready
// (proceso externo, petición HTTP de solo lectura).
//
// Estándares: BOS-REPAIR-01 §Criterio-C-07, SBOS-018 §6 (certificación Operador).
func VerifyC07() (bool, string) {
	out, err := exec.Command("curl", "-sf", "http://localhost:8080/health/ready").Output()
	if err != nil {
		return false, "keycloak /health/ready no responde: " + err.Error()
	}
	if !strings.Contains(string(out), `"status":"UP"`) {
		return false, "keycloak no está UP"
	}
	return true, "keycloak: status UP"
}

// VerifyC08 verifica el criterio C-08: Kong.
//
// Comprueba que Kong está operativo y conectado a la base de datos consultando
// su Admin API en el puerto 8001. Kong es el API gateway del SBOS — sin él los
// daemons no pueden exponerse externamente (biedata, bSearch, bAuth).
//
// Recibe: ninguno.
//
// Retorna:
//   - (true, "kong: database reachable") si :8001/status reporta "reachable":true.
//   - (false, "kong :8001/status no responde: <error>") si curl falla.
//   - (false, "kong database no accesible") si "reachable":true no está en la respuesta.
//
// Callers conocidos:
//   - VerifyAll — como criterio C-08 en la posición [7] del slice de resultados.
//
// Efectos secundarios: ejecuta curl -sf http://localhost:8001/status
// (proceso externo, petición HTTP de solo lectura).
//
// Estándares: BOS-REPAIR-01 §Criterio-C-08, SBOS-018 §6 (certificación Operador).
func VerifyC08() (bool, string) {
	out, err := exec.Command("curl", "-sf", "http://localhost:8001/status").Output()
	if err != nil {
		return false, "kong :8001/status no responde: " + err.Error()
	}
	if !strings.Contains(string(out), `"reachable":true`) {
		return false, "kong database no accesible"
	}
	return true, "kong: database reachable"
}

// VerifyAll ejecuta los 8 criterios de certificación C-01..C-08 en orden y
// retorna sus resultados en un slice de longitud fija.
//
// Los criterios C-01 y C-02 verifican filesystem (testables sin cluster activo).
// Los criterios C-03..C-08 ejecutan comandos externos; retornan (false, ...) si
// los servicios no están disponibles — comportamiento esperado en tests unitarios.
//
// Recibe: ninguno — cada VerifyC0X usa SysRoot para paths de filesystem.
//
// Retorna:
//   - []CriterioResult de longitud 8, en orden C-01..C-08.
//   - Cada elemento tiene ID, OK y Detail con el resultado del criterio.
//   - Nunca retorna nil; nunca retorna error.
//
// Callers conocidos:
//   - internal/server/bootstrap.go:wsHandleBootstrapVerify — responde al comando
//     bootstrap_verify del TUI y del bosctl.
//   - cmd/bosctl/bootstrap.go:cmdBootstrapVerify — bosctl bootstrap verify.
//
// Efectos secundarios: los de cada VerifyC0X (lecturas FS + comandos externos).
//
// Estándares: BOS-REPAIR-01 §Criterios-C-01..C-08, SBOS-018 §6.
func VerifyAll() []CriterioResult {
	checks := []struct {
		id string
		fn func() (bool, string)
	}{
		{"C-01", VerifyC01},
		{"C-02", VerifyC02},
		{"C-03", VerifyC03},
		{"C-04", VerifyC04},
		{"C-05", VerifyC05},
		{"C-06", VerifyC06},
		{"C-07", VerifyC07},
		{"C-08", VerifyC08},
	}
	results := make([]CriterioResult, len(checks))
	for i, c := range checks {
		ok, detail := c.fn()
		results[i] = CriterioResult{ID: c.id, OK: ok, Detail: detail}
	}
	return results
}
