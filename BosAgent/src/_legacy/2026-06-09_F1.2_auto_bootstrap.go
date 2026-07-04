// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// SOLO REFERENCIA DE LÓGICA — NO IMPORTAR, NO COPIAR COMO ESTÁ.
//
// Origen: cmd/bos/main.go (extraído en átomo F1.2)
// Destino: internal/bootstrap/setup.go
// Razón: autoBootstrap() viola SRP — setup del entorno debe vivir en un paquete
//         aislado, testeable y sin os.Exit(), conforme a BOS-REPAIR-01 §F1.
//
// Funciones incluidas:
//   - autoBootstrap(): configura directorios, despliega binarios/scripts, valida deps,
//     inicializa cgroups, contraseña root y registra en audit.
//   - copyDir(): copia recursiva de árbol de directorios (helper de autoBootstrap).
//   - detectContainerMapping(): lee /proc/self/uid_map para ownership de cgroups.
//
// Nota: paso 8 (cgroup delegation via verifyCgroupDelegation/isBareMetal/
//       configureSystemdDelegate) queda en main.go hasta F1.3 (internal/cgroup/).
//       Paso 8.5 (ensureBridgeNetwork) queda en main.go hasta F1.4 (internal/network/).
//       Paso 6.5 (RBAC init) queda en main.go hasta F4.4 (migración a bAuth).

package legacy

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

// autoBootstrap prepara el entorno para la operación del daemon bos.
// ADR-001: BOS es la capa SO — crea todos los directorios, configura cgroups,
// corrige permisos y asegura que el sistema está listo para la instalación de K8s.
// Zero intervención humana más allá de colocar archivos en /tmp/ y ejecutar BOS.
//
// MIGRADO a: internal/bootstrap.Setup()
func autoBootstrap(benv *bootstrapEnv) {
	// 1. Crear estructura de directorios canónica
	dirs := []string{
		"/opt/bos/bin",
		"/opt/bos/core",
		"/etc/bos/blibs/servers",
		"/etc/bos/.kube",
		"/var/log/bos",
		"/run/bos",
	}
	for _, d := range dirs {
		os.MkdirAll(d, 0755)
	}

	// 2. Self-deploy: si corremos desde /tmp/, copiarnos al path canónico
	ownPath, _ := os.Executable()
	canonicalBin := "/opt/bos/bin/bos"
	if ownPath != "" && ownPath != canonicalBin {
		if data, err := os.ReadFile(ownPath); err == nil {
			os.WriteFile(canonicalBin, data, 0755)
		}
	}
	os.Chmod(canonicalBin, 0755)

	// 3. Desplegar configs desde /tmp/ a paths canónicos (no sobreescribe si existe)
	deployFile := func(src, dst string, mode os.FileMode) {
		if _, err := os.Stat(dst); os.IsNotExist(err) {
			if data, err := os.ReadFile(src); err == nil {
				os.WriteFile(dst, data, mode)
			}
		}
	}
	deployFile("/tmp/bos.toml", "/etc/bos/bos.toml", 0644)
	deployFile("/tmp/bos-install.toml", "/etc/bos/bos-install.toml", 0644)
	deployFile("/tmp/bos-bootstrap.env", "/etc/bos/bos-bootstrap.env", 0600)

	coreScripts := []string{
		"00_MASTER_INSTALL_SBOS.sh",
		"00_TASK_CATALOG_SBOS.sh",
		"00_YAML_ENGINE_SBOS.sh",
		"00_CLEANUP_SBOS.sh",
		"host-setup.sh",
	}
	for _, s := range coreScripts {
		deployFile("/tmp/"+s, "/opt/bos/core/"+s, 0755)
	}
	deployFile("/tmp/bosctl", "/opt/bos/bin/bosctl", 0755)

	// 4. Desplegar fichas desde /tmp/servers/ si el path canónico está vacío
	serversPath := "/etc/bos/blibs/servers"
	if entries, _ := os.ReadDir(serversPath); len(entries) == 0 {
		if _, err := os.Stat("/tmp/servers"); err == nil {
			copyDir("/tmp/servers", serversPath)
		}
	}

	// 5. Validar dependencias críticas antes de continuar
	critical := []string{
		"/opt/bos/bin/bos",
		"/opt/bos/core/00_MASTER_INSTALL_SBOS.sh",
		"/opt/bos/core/00_TASK_CATALOG_SBOS.sh",
		"/opt/bos/core/00_YAML_ENGINE_SBOS.sh",
		"/opt/bos/core/host-setup.sh",
	}
	for _, p := range critical {
		if _, err := os.Stat(p); os.IsNotExist(err) {
			// En bootstrap.Setup() esto retorna error en lugar de os.Exit(1)
			os.Exit(1)
		}
	}

	// Asegurar que los scripts son ejecutables
	for _, s := range coreScripts {
		if p := "/opt/bos/core/" + s; func() bool { _, e := os.Stat(p); return e == nil }() {
			os.Chmod(p, 0755)
		}
	}
	if _, err := os.Stat("/opt/bos/bin/bosctl"); err == nil {
		os.Chmod("/opt/bos/bin/bosctl", 0755)
	}

	// 6. Escribir PID file
	os.WriteFile("/run/bos/bos.pid", []byte(fmt.Sprintf("%d\n", os.Getpid())), 0644)

	// 6.5. Inicializar RBAC (permanece en main.go hasta F4.4)
	// ...

	// audit.Log bootstrap_start
	// ...

	// 7. Crear cgroup k8s.io
	cgPath := benv.CGroupPath
	if _, err := os.Stat(cgPath); os.IsNotExist(err) {
		if err := os.MkdirAll(cgPath, 0755); err == nil {
			if controllers, err := os.ReadFile(filepath.Join(cgPath, "cgroup.controllers")); err == nil {
				for _, ctrl := range strings.Fields(string(controllers)) {
					os.WriteFile(filepath.Join(cgPath, "cgroup.subtree_control"), []byte("+"+ctrl), 0)
				}
			}
		}
	}

	// 7.5. Configurar contraseña root desde bootstrap env
	if benv.RootPassword != "" {
		cmd := exec.Command("chpasswd")
		cmd.Stdin = strings.NewReader(fmt.Sprintf("root:%s", benv.RootPassword))
		cmd.Run()
	}

	// 8. Verificación de delegación de cgroup (permanece en main.go hasta F1.3)
	// verifyCgroupDelegation, isBareMetal, configureSystemdDelegate — ver F1.3

	// 8.5. Configuración de red bridge (permanece en main.go hasta F1.4)
	// ensureBridgeNetwork() — ver F1.4

	// 9. Registrar en audit log que el bootstrap completó
	hostname, _ := os.Hostname()
	_ = hostname
	// audit.Log(...)
}

// copyDir copia recursivamente el árbol de directorios de src a dst.
//
// MIGRADO a: internal/bootstrap.copyDir() (función privada del paquete)
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

// detectContainerMapping lee /proc/self/uid_map y /proc/self/gid_map para
// determinar el UID/GID correcto de ownership de cgroups en contenedores anidados.
//
// Permanece en main.go: usada en el paso 8 (cgroup delegation) que va a F1.3.
func detectContainerMapping() (uid, gid int) {
	uid = 0
	gid = 0
	if data, err := os.ReadFile("/proc/self/uid_map"); err == nil {
		fields := strings.Fields(string(data))
		if len(fields) >= 2 {
			if v, err := strconv.Atoi(fields[1]); err == nil {
				uid = v
			}
		}
	}
	if data, err := os.ReadFile("/proc/self/gid_map"); err == nil {
		fields := strings.Fields(string(data))
		if len(fields) >= 2 {
			if v, err := strconv.Atoi(fields[1]); err == nil {
				gid = v
			}
		}
	}
	return
}
