// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package cgroup

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// ProcRoot es el prefijo del sistema de archivos para las lecturas de /proc y /.
//
// En producción permanece "/" y no debe modificarse.
// En tests, asignar t.TempDir() para evitar depender del sistema de archivos real.
//
// IMPORTANTE — no es thread-safe: los tests que modifiquen ProcRoot no deben
// ejecutarse en paralelo entre sí.
var ProcRoot = "/"

// SystemdDir es el directorio raíz de las unidades de systemd.
//
// En producción permanece "/etc/systemd/system" y no debe modificarse.
// En tests, asignar t.TempDir() para escribir drop-ins sin permisos root.
//
// IMPORTANTE — no es thread-safe: los tests que modifiquen SystemdDir no deben
// ejecutarse en paralelo entre sí.
var SystemdDir = "/etc/systemd/system"

// Probe verifica activamente si la delegación de cgroup v2 está operativa bajo cgPath.
//
// Crea un cgroup hijo de prueba llamado ".bos-delegate-probe-<PID>" e intenta
// escribir el PID del proceso en cgroup.procs. Esta operación requiere que systemd
// haya otorgado delegación del subárbol (Delegate=yes) — un mkdir simple no es
// suficiente para confirmar que runc puede crear sus propios cgroups bajo cgPath.
// El cgroup de prueba se elimina siempre, independientemente del resultado.
//
// Recibe:
//   - cgPath: string — path del cgroup a verificar (p.ej. /sys/fs/cgroup/k8s.io).
//
// Retorna:
//   - true si el cgroup hijo se creó y cgroup.procs aceptó escritura (delegación OK).
//   - false si mkdir o escritura en cgroup.procs fallaron (delegación no activa).
//
// Callers conocidos:
//   - cmd/bos/main.go:autoBootstrap — paso 8, verifica delegación tras Setup().
//
// Efectos secundarios:
//   - Crea y elimina /sys/fs/cgroup/k8s.io/.bos-delegate-probe-<PID> (temporal).
//
// Estándares: BOS-REPAIR-01 §Criterio-C-02, SBOS-018 §4.2.
func Probe(cgPath string) bool {
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

// IsBareMetal retorna true si el proceso NO corre dentro de un contenedor.
//
// Comprueba en orden de prioridad:
//  1. ProcRoot+"/.containerenv" existe → es contenedor (Podman/nspawn).
//  2. ProcRoot+"/run/.containerenv" existe → es contenedor.
//  3. ProcRoot+"/proc/self/cgroup" contiene "/docker/", "/libpod-", "/kubepods"
//     o "0::/" → es contenedor Docker, Podman o K8s.
//
// Si ninguna condición se cumple, se asume bare metal.
//
// Recibe: ninguno — usa ProcRoot para construir los paths de detección.
//
// Retorna:
//   - true si el proceso corre en bare metal (ninguna señal de contenedor).
//   - false si se detecta al menos una señal de contenedor.
//
// Callers conocidos:
//   - cmd/bos/main.go:autoBootstrap — determina la estrategia de delegación cgroup.
//
// Efectos secundarios: ninguno — solo lecturas de sistema de archivos.
//
// Estándares: SBOS-018 §4.2 (detección de entorno de despliegue).
func IsBareMetal() bool {
	pr := ProcRoot
	if pr == "" {
		pr = "/"
	}
	if _, err := os.Stat(filepath.Join(pr, ".containerenv")); err == nil {
		return false
	}
	if _, err := os.Stat(filepath.Join(pr, "run/.containerenv")); err == nil {
		return false
	}
	data, err := os.ReadFile(filepath.Join(pr, "proc/self/cgroup"))
	if err == nil {
		cgroup := string(data)
		if strings.Contains(cgroup, "/docker/") || strings.Contains(cgroup, "/libpod-") ||
			strings.Contains(cgroup, "/kubepods") || strings.Contains(cgroup, "0::/") {
			return false
		}
	}
	return true
}

// DetectContainerMapping lee /proc/self/uid_map y /proc/self/gid_map para
// determinar el UID/GID real del proceso en contenedores anidados con user namespaces.
//
// En contenedores con user namespace, UID 0 dentro del contenedor corresponde
// a un UID distinto en el host. El directorio del cgroup en el host tiene ese
// UID real como owner — este método lo detecta para que Chown corrija el ownership.
//
// Recibe: ninguno — lee /proc/self/uid_map y /proc/self/gid_map directamente.
//
// Retorna:
//   - (uid, gid int): UID y GID del proceso en el espacio de nombres del host.
//     Si no hay mapeo (bare metal o sin user namespace), retorna (0, 0).
//     Si el archivo no existe o el formato es inesperado, retorna (0, 0).
//
// Callers conocidos:
//   - cmd/bos/main.go:autoBootstrap — paso 8, corrección de ownership del cgroup.
//
// Efectos secundarios: ninguno — solo lecturas de /proc/self/*.
//
// Estándares: Linux kernel — /proc/[pid]/uid_map, namespace(7).
func DetectContainerMapping() (uid, gid int) {
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

// ConfigureSystemdDelegate crea un drop-in en SystemdDir/<serviceName>.d/delegate.conf
// con la directiva Delegate=yes, habilitando la delegación del subárbol cgroup para
// que kubelet y runc puedan crear sus propios cgroups bajo la unidad del servicio.
//
// El drop-in se crea aunque ya exista el directorio; si el archivo delegate.conf
// ya existe es sobreescrito (los valores son idempotentes).
//
// Recibe:
//   - serviceName: string — nombre de la unidad systemd sin extensión .service
//     (p.ej. "bos.service" o "bos").
//
// Retorna:
//   - nil si el directorio y archivo se crearon correctamente.
//   - error con contexto si MkdirAll o WriteFile fallan.
//
// Callers conocidos:
//   - cmd/bos/main.go:autoBootstrap — solo si IsBareMetal() y Probe() falla.
//
// Efectos secundarios:
//   - Crea SystemdDir/<serviceName>.d/ (0755) si no existe.
//   - Escribe SystemdDir/<serviceName>.d/delegate.conf con "[Service]\nDelegate=yes\n".
//   - El caller debe ejecutar systemctl daemon-reload después de esta llamada.
//
// Estándares: systemd.resource-control(5) — Delegate=yes, SBOS-018 §4.2.
func ConfigureSystemdDelegate(serviceName string) error {
	sd := SystemdDir
	if sd == "" {
		sd = "/etc/systemd/system"
	}
	dir := filepath.Join(sd, serviceName+".d")
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("cgroup: crear directorio drop-in %s: %w", dir, err)
	}
	conf := filepath.Join(dir, "delegate.conf")
	if err := os.WriteFile(conf, []byte("[Service]\nDelegate=yes\n"), 0644); err != nil {
		return fmt.Errorf("cgroup: escribir delegate.conf en %s: %w", conf, err)
	}
	return nil
}
