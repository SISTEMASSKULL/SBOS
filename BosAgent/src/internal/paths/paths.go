// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package paths

import "path/filepath"

// Paths canónicos del sistema bos — R16 Zero Hardcoding.
// NUNCA usar strings literales de paths en otros paquetes.
// Si falta un path, agregarlo aquí, no en el caller.

// ── Directorios raíz ──────────────────────────────────────────────────────

const (
	VarLibBos = "/var/lib/bos" // estado persistente del daemon
	VarLogBos = "/var/log/bos" // logs de auditoría y operación
	EtcBos    = "/etc/bos"     // configuración estática
	RunBos    = "/run/bos"     // artefactos en tiempo de ejecución (socket, PID)
	BosPath   = "/opt/bos"     // binarios y assets del sistema
)

// ── Tiempo de ejecución (/run/bos/) ───────────────────────────────────────

const (
	SocketPath = "/run/bos/bos.sock" // Unix socket del daemon (0660, grupo bosagent)
	PidFile    = "/run/bos/bos.pid"  // PID del proceso daemon
)

// ── Modo desarrollo ───────────────────────────────────────────────────────

const (
	// DevRunDir es el directorio temporal de desarrollo (override: BOS_DEV_RUN_PATH).
	DevRunDir = "/tmp/bos-dev-run"
	// CGroupPath es la ruta del cgroup de K8s en Ubuntu 26.04 LTS.
	CGroupPath = "/sys/fs/cgroup/k8s.io"
	// BosServiceName es el nombre del unit systemd del daemon bos.
	BosServiceName = "bos.service"
)

// ── Configuración (/etc/bos/) ─────────────────────────────────────────────

const (
	BosToml        = "/etc/bos/bos.toml"          // configuración del daemon
	InstallToml    = "/etc/bos/bos-install.toml"  // parámetros de instalación (Day 0)
	BootstrapEnv   = "/etc/bos/bos-bootstrap.env" // variables de arranque (tenant, admin)
	StatePath      = "/etc/bos/.sbos_state.json"  // estado centralizado de fichas
	KubeDir        = "/etc/bos/.kube"             // directorio kubeconfig
	KubeconfigPath = "/etc/bos/.kube/config"      // kubeconfig del cluster K8s
	BlibsDir       = "/etc/bos/blibs"             // biblioteca de fichas declarativas
	ServersPath    = "/etc/bos/blibs/servers"     // fichas organizadas por servidor
	RBACRoles      = "/etc/bos/rbac/roles.json"   // roles RBAC del daemon (eliminar en F4.4)

	// Certificados TLS
	CertsDir    = "/etc/bos/certs"            // directorio de certificados
	CertFile    = "/etc/bos/certs/bos.crt"    // certificado TLS del daemon
	KeyFile     = "/etc/bos/certs/bos.key"    // llave privada TLS del daemon
	RpcTokenFile = "/etc/bos/rpc-token"       // token compartido para JSON-RPC entre daemons
)

// ── Logs (/var/log/bos/) ──────────────────────────────────────────────────

const (
	AuditLog     = "/var/log/bos/audit.log"     // log de auditoría ISO 27001 A.8.15
	AIAuditLog   = "/var/log/bos/ai-audit.log"  // log de operaciones del agente IA
	BootstrapLog = "/var/log/bos/bootstrap.log" // log de la instalación Day 0
)

// ── Estado persistente (/var/lib/bos/) ────────────────────────────────────

const (
	SagasStore     = "/var/lib/bos/ai/sagas"               // persistencia de sagas biaos
	CatalogVectors = "/var/lib/bos/ai/catalog-vectors.bin" // embeddings del action_catalog
)

// ── Binarios (/opt/bos/bin/) ──────────────────────────────────────────────

const (
	BinPath   = "/opt/bos/bin"        // directorio de binarios del sistema bos
	BosBin    = "/opt/bos/bin/bos"    // daemon principal
	BosctlBin = "/opt/bos/bin/bosctl" // CLI de administración
)

// ── Scripts del core (/opt/bos/core/) ────────────────────────────────────

const (
	CorePath     = "/opt/bos/core"                           // directorio del core
	MasterScript = "/opt/bos/core/00_MASTER_INSTALL_SBOS.sh" // orquestador principal de instalación
	TaskCatalog  = "/opt/bos/core/00_TASK_CATALOG_SBOS.sh"   // catálogo de tareas bash
	YamlEngine   = "/opt/bos/core/00_YAML_ENGINE_SBOS.sh"    // motor de renderizado YAML
	HostSetup    = "/opt/bos/core/host-setup.sh"             // configuración inicial del host
)

// ── Helpers ───────────────────────────────────────────────────────────────

// ConfigDir devuelve la ruta canónica de un subdirectorio bajo /etc/bos/.
//
// Recibe:
//   - subdir: string — nombre del subdirectorio (sin slash inicial).
//
// Retorna: filepath.Join(EtcBos, subdir) — siempre una ruta absoluta.
//
// Callers conocidos: internal/security y cualquier paquete que gestione
// certificados, llaves o configuración específica de un subsistema.
//
// Efectos secundarios: ninguno — función pura, no crea el directorio.
//
//	paths.ConfigDir("certs") → "/etc/bos/certs"
func ConfigDir(subdir string) string {
	return filepath.Join(EtcBos, subdir)
}

// LogFile devuelve la ruta canónica de un archivo bajo /var/log/bos/.
//
// Recibe:
//   - name: string — nombre del archivo de log (con extensión, sin slash).
//
// Retorna: filepath.Join(VarLogBos, name) — siempre una ruta absoluta.
//
// Callers conocidos: cualquier paquete que genere logs de operación
// específicos de un subsistema (p.ej. saga-install.log, bootstrap.log).
//
// Efectos secundarios: ninguno — función pura, no crea el archivo.
//
//	paths.LogFile("saga-install.log") → "/var/log/bos/saga-install.log"
func LogFile(name string) string {
	return filepath.Join(VarLogBos, name)
}

// RuntimeFile devuelve la ruta canónica de un archivo bajo /run/bos/.
//
// Usar para construir paths de Unix sockets de daemons del SBOS,
// conforme a SBOS-050 P9 (comunicación entre daemons solo por socket Unix).
//
// Recibe:
//   - name: string — nombre del archivo de runtime (socket, lock, etc.).
//
// Retorna: filepath.Join(RunBos, name) — siempre una ruta absoluta.
//
// Callers conocidos: cualquier paquete que necesite el socket Unix de otro
// daemon (bAuth → "/run/bos/bauth.sock", bKernel → "/run/bos/bkernel.sock").
//
// Efectos secundarios: ninguno — función pura, no crea el socket.
//
//	paths.RuntimeFile("bauth.sock") → "/run/bos/bauth.sock"
func RuntimeFile(name string) string {
	return filepath.Join(RunBos, name)
}
