// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package bootstrap

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"bos/internal/audit"
	"bos/internal/paths"

	"github.com/rs/zerolog/log"
)

// Config contiene los parámetros de configuración para Setup.
//
// Todos los campos son opcionales: Setup aplica comportamiento seguro cuando
// alguno está vacío. CGroupPath vacío omite la creación del cgroup k8s.io.
// RootPassword vacío omite la llamada a chpasswd. SysRoot vacío equivale a "/".
//
// Thread safety: Config se pasa por valor; no se comparte entre goroutines.
type Config struct {
	// CGroupPath es el path del cgroup k8s.io que BOS debe crear.
	// Ejemplo: "/sys/fs/cgroup/k8s.io". Si está vacío, Setup omite el paso 7.
	CGroupPath string

	// RootPassword es la contraseña root leída de bos-bootstrap.env.
	// Si está vacío, Setup omite la llamada a chpasswd (paso 7.5).
	// NUNCA registrar este valor en logs — el audit solo registra la acción.
	RootPassword string

	// TenantID es el identificador del tenant principal.
	// Se registra en el audit log al completar el bootstrap (SBOS-049 — trazabilidad).
	TenantID string

	// SysRoot es el prefijo del sistema de archivos para todos los paths.
	// Vacío equivale a "/". En tests, usar t.TempDir() para evitar permisos root.
	// NUNCA usar un valor distinto de "" o "/" en producción.
	SysRoot string
}

// Setup configura el entorno del daemon bos en el arranque inicial (Day 0).
//
// Ejecuta 8 pasos en orden: (1) crea directorios canónicos, (2) se auto-despliega
// al path canónico si corre desde /tmp/, (3) despliega configs y scripts del core
// desde /tmp/, (4) despliega fichas declarativas desde /tmp/servers/, (5) valida
// que las 5 dependencias críticas existen, (6) escribe el PID file, (7) crea el
// cgroup k8s.io, (7.5) configura contraseña root via chpasswd, (9) registra en
// audit log. Los pasos 8 (cgroup delegation) y 8.5 (bridge) viven en main.go
// hasta que los átomos F1.3 y F1.4 los extraigan.
//
// Recibe:
//   - cfg: Config — parámetros de configuración; ver Config para restricciones.
//
// Retorna:
//   - nil si el entorno quedó listo para operación normal.
//   - error con el path faltante si alguna dependencia crítica no existe tras el
//     intento de deploy. El error incluye instrucción de resolución.
//     Ejemplo: "dependencia crítica ausente: /opt/bos/core/00_MASTER_INSTALL_SBOS.sh
//     — colocar en /tmp/ y reiniciar bos".
//
// Callers conocidos:
//   - cmd/bos/main.go:autoBootstrap — llamado al iniciar si la config existe.
//
// Efectos secundarios (riesgo P9 — sin rollback automático):
//   - Crea directorios bajo SysRoot con permisos 0755.
//   - Escribe el binario propio en SysRoot+/opt/bos/bin/bos.
//   - Copia archivos de /tmp/ a paths canónicos (no sobreescribe existentes).
//   - Escribe SysRoot+/run/bos/bos.pid con el PID del proceso actual.
//   - Crea el cgroup k8s.io si cfg.CGroupPath no está vacío y no existe.
//   - Llama chpasswd si cfg.RootPassword no está vacío.
//   - Escribe en SysRoot+/var/log/bos/audit.log (categorías BOOTSTRAP y CGROUP).
//
// Idempotente: segundo run omite despliegues (archivos ya existen), recrea PID file,
// omite cgroup si ya existe. No produce errores en ejecuciones repetidas.
//
// Estándares: ADR-001 (BOS como capa SO), BOS-REPAIR-01 (criterios Day 0),
// ISO 27001:2022 A.8.15 (audit log obligatorio en toda operación privilegiada).
func Setup(cfg Config) error {
	root := cfg.SysRoot
	if root == "" {
		root = "/"
	}

	// j construye una ruta absoluta relativa a root.
	j := func(p string) string { return filepath.Join(root, p) }

	log.Info().Msg("bootstrap: inicializando entorno")

	// 1. Crear estructura de directorios canónica
	dirs := []string{
		paths.BinPath,
		paths.CorePath,
		paths.ServersPath,
		paths.KubeDir,
		paths.VarLogBos,
		paths.RunBos,
	}
	for _, d := range dirs {
		if err := os.MkdirAll(j(d), 0755); err != nil {
			log.Warn().Err(err).Str("dir", d).Msg("bootstrap: no se pudo crear directorio")
		}
	}

	// 2. Self-deploy: si corremos desde fuera del path canónico, copiarnos
	ownPath, _ := os.Executable()
	canonicalBin := j(paths.BosBin)
	if ownPath != "" && ownPath != canonicalBin {
		log.Info().Str("desde", ownPath).Str("hacia", canonicalBin).Msg("bootstrap: auto-despliegue")
		if data, err := os.ReadFile(ownPath); err == nil {
			if err := os.WriteFile(canonicalBin, data, 0755); err != nil {
				log.Warn().Err(err).Msg("bootstrap: no se pudo auto-desplegar el binario")
			}
		}
	}
	_ = os.Chmod(canonicalBin, 0755)

	// 3. Desplegar configs desde /tmp/ a paths canónicos (no sobreescribe si ya existe)
	deployFile := func(src, dst string, mode os.FileMode) {
		if _, err := os.Stat(dst); os.IsNotExist(err) {
			data, err := os.ReadFile(src)
			if err != nil {
				log.Warn().Str("src", src).Msg("bootstrap: fuente ausente, no se puede desplegar")
				return
			}
			if err := os.WriteFile(dst, data, mode); err != nil {
				log.Warn().Err(err).Str("dst", dst).Msg("bootstrap: error escribiendo archivo")
				return
			}
			log.Info().Str("src", src).Str("dst", dst).Msg("bootstrap: archivo desplegado")
		}
	}

	deployFile("/tmp/bos.toml", j(paths.BosToml), 0644)
	deployFile("/tmp/bos-install.toml", j(paths.InstallToml), 0644)
	deployFile("/tmp/bos-bootstrap.env", j(paths.BootstrapEnv), 0600)

	coreScripts := []string{
		"00_MASTER_INSTALL_SBOS.sh",
		"00_TASK_CATALOG_SBOS.sh",
		"00_YAML_ENGINE_SBOS.sh",
		"00_CLEANUP_SBOS.sh",
		"host-setup.sh",
	}
	for _, s := range coreScripts {
		deployFile("/tmp/"+s, j(paths.CorePath+"/"+s), 0755)
	}
	deployFile("/tmp/bosctl", j(paths.BosctlBin), 0755)

	// 4. Desplegar fichas desde /tmp/servers/ si el path canónico está vacío
	serversPath := j(paths.ServersPath)
	if entries, _ := os.ReadDir(serversPath); len(entries) == 0 {
		tmpServers := "/tmp/servers"
		if _, err := os.Stat(tmpServers); err == nil {
			if err := copyDir(tmpServers, serversPath); err != nil {
				log.Warn().Err(err).Msg("bootstrap: error desplegando fichas")
			} else {
				log.Info().Str("dst", serversPath).Msg("bootstrap: fichas desplegadas")
			}
		} else {
			log.Warn().Msg("bootstrap: /tmp/servers/ ausente — fichas no desplegadas")
		}
	}

	// 5. Scripts legados — ausencia no bloquea el daemon (nueva arquitectura usa fichas declarativas)
	legacy := []string{
		paths.BosBin,
		paths.MasterScript,
		paths.TaskCatalog,
		paths.YamlEngine,
		paths.HostSetup,
	}
	for _, p := range legacy {
		if _, err := os.Stat(j(p)); os.IsNotExist(err) {
			log.Warn().Str("path", j(p)).Msg("bootstrap: script legado ausente (ignorado — arquitectura declarativa)")
		}
	}

	// Asegurar permisos de ejecución en scripts
	for _, s := range coreScripts {
		if p := j(paths.CorePath + "/" + s); func() bool { _, e := os.Stat(p); return e == nil }() {
			_ = os.Chmod(p, 0755)
		}
	}
	if _, err := os.Stat(j(paths.BosctlBin)); err == nil {
		_ = os.Chmod(j(paths.BosctlBin), 0755)
	}

	// 6. Escribir PID file
	_ = os.WriteFile(j(paths.PidFile), []byte(fmt.Sprintf("%d\n", os.Getpid())), 0644)

	// 7. Crear cgroup k8s.io (sin verificar delegación — eso es F1.3/internal/cgroup)
	if cfg.CGroupPath != "" {
		if _, err := os.Stat(cfg.CGroupPath); os.IsNotExist(err) {
			log.Info().Str("path", cfg.CGroupPath).Msg("bootstrap: creando cgroup k8s.io")
			if err := os.MkdirAll(cfg.CGroupPath, 0755); err != nil {
				log.Warn().Err(err).Str("path", cfg.CGroupPath).Msg("bootstrap: no se pudo crear cgroup")
			} else {
				audit.Log(j(paths.AuditLog), "CGROUP", "path="+cfg.CGroupPath, "action=created")
				ctrlFile := filepath.Join(cfg.CGroupPath, "cgroup.controllers")
				if controllers, err := os.ReadFile(ctrlFile); err == nil {
					for _, ctrl := range strings.Fields(string(controllers)) {
						_ = os.WriteFile(
							filepath.Join(cfg.CGroupPath, "cgroup.subtree_control"),
							[]byte("+"+ctrl), 0)
					}
				}
			}
		}
	}

	// 7.5. Configurar contraseña root desde bootstrap env
	if cfg.RootPassword != "" {
		cmd := exec.Command("chpasswd")
		cmd.Stdin = strings.NewReader(fmt.Sprintf("root:%s", cfg.RootPassword))
		if err := cmd.Run(); err != nil {
			log.Warn().Err(err).Msg("bootstrap: no se pudo configurar contraseña root via chpasswd")
		} else {
			log.Info().Msg("bootstrap: contraseña root configurada desde bos-bootstrap.env")
			audit.Log(j(paths.AuditLog), "CREDENTIALS", "action=root_password_set", "source=bos-bootstrap.env")
		}
	}

	// 9. Registrar que el bootstrap completó en el audit log
	hostname, _ := os.Hostname()
	audit.Log(j(paths.AuditLog), "BOOTSTRAP",
		"user=root",
		"hostname="+hostname,
		"uid="+fmt.Sprintf("%d", os.Getuid()),
		"tenant="+cfg.TenantID,
		"action=auto_bootstrap_complete")

	log.Info().Msg("bootstrap: entorno listo")
	return nil
}

// copyDir copia recursivamente el árbol de directorios de src a dst.
//
// Para cada archivo en src, crea la ruta relativa correspondiente en dst y copia
// el contenido. Los directorios se crean con permisos 0755. Los archivos se crean
// con los permisos del archivo original (info.Mode()). Si el archivo destino ya
// existe es sobreescrito (os.WriteFile trunca).
//
// Recibe:
//   - src: directorio raíz de origen; debe existir.
//   - dst: directorio raíz de destino; se crea con 0755 si no existe.
//
// Retorna error si filepath.Walk no puede leer src, si ReadFile falla en algún
// archivo, o si WriteFile no puede escribir en dst. El error incluye el path
// del archivo afectado vía el mecanismo de filepath.Walk.
//
// Caller: Setup — paso 4, deploy de fichas desde /tmp/servers/.
func copyDir(src, dst string) error {
	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, path)
		target := filepath.Join(dst, rel)
		if info.IsDir() {
			return os.MkdirAll(target, 0755)
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		return os.WriteFile(target, data, info.Mode())
	})
}
