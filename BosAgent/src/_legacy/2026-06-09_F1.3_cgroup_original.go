// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// SOLO REFERENCIA DE LÓGICA — NO IMPORTAR, NO COPIAR COMO ESTÁ.
//
// Origen: cmd/bos/main.go (extraído en átomo F1.3)
// Destino: internal/cgroup/cgroup.go
// Razón: las funciones de cgroup violan SRP en main.go y son intestables
//         con sus paths hardcodeados; el paquete cgroup las hace testeables
//         vía ProcRoot y SystemdDir (variables de paquete override en tests).
//
// Funciones incluidas:
//   - verifyCgroupDelegation(): probe activo de delegación — crea cgroup hijo de prueba.
//   - isBareMetal(): detecta si el proceso corre en bare metal o contenedor.
//   - configureSystemdDelegate(): crea drop-in Delegate=yes para bos.service.
//   - detectContainerMapping(): lee /proc/self/uid_map para ownership de cgroups.
//
// Cambios en la versión migrada:
//   - Renombradas: Probe / IsBareMetal / ConfigureSystemdDelegate / DetectContainerMapping
//   - ProcRoot y SystemdDir como variables de paquete para override en tests
//   - Comentarios en español y godoc ADR-003 completo

package legacy

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// verifyCgroupDelegation verifica si runc puede crear cgroups hijo bajo cgPath
// creando un cgroup de prueba temporal y escribiendo en cgroup.procs.
// Un mkdir simple no es suficiente — requiere Delegate=yes en la unidad systemd.
//
// MIGRADO a: internal/cgroup.Probe()
func verifyCgroupDelegation(cgPath string) bool {
	testChild := filepath.Join(cgPath, ".bos-delegate-probe-"+strconv.Itoa(os.Getpid()))
	if err := os.Mkdir(testChild, 0755); err != nil {
		return false
	}
	procsFile := filepath.Join(testChild, "cgroup.procs")
	f, err := os.OpenFile(procsFile, os.O_WRONLY, 0)
	if err != nil {
		os.Remove(testChild)
		return false
	}
	_, err = fmt.Fprintf(f, "%d", os.Getpid())
	f.Close()
	os.Remove(testChild)
	return err == nil
}

// isBareMetal retorna true si el proceso NO corre dentro de un contenedor.
// Comprueba en orden: /.containerenv, /run/.containerenv, /proc/self/cgroup.
//
// MIGRADO a: internal/cgroup.IsBareMetal()
func isBareMetal() bool {
	if _, err := os.Stat("/.containerenv"); err == nil {
		return false
	}
	if _, err := os.Stat("/run/.containerenv"); err == nil {
		return false
	}
	data, err := os.ReadFile("/proc/self/cgroup")
	if err == nil {
		cgroup := string(data)
		if strings.Contains(cgroup, "/docker/") || strings.Contains(cgroup, "/libpod-") ||
			strings.Contains(cgroup, "/kubepods") || strings.Contains(cgroup, "0::/") {
			return false
		}
	}
	return true
}

// configureSystemdDelegate crea un drop-in en /etc/systemd/system/<servicio>.d/delegate.conf
// con Delegate=yes, habilitando la delegación de subárbol cgroup para kubelet/runc.
//
// MIGRADO a: internal/cgroup.ConfigureSystemdDelegate()
func configureSystemdDelegate(serviceName string) error {
	dir := "/etc/systemd/system/" + serviceName + ".d"
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	conf := filepath.Join(dir, "delegate.conf")
	return os.WriteFile(conf, []byte("[Service]\nDelegate=yes\n"), 0644)
}

// detectContainerMapping lee /proc/self/uid_map y /proc/self/gid_map para
// determinar el UID/GID correcto de ownership de cgroups en contenedores anidados.
//
// MIGRADO a: internal/cgroup.DetectContainerMapping()
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
