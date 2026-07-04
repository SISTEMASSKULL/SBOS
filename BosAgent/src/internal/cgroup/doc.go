// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package cgroup gestiona la delegación de cgroup v2 para K8s en el daemon bos.
//
// # Responsabilidades
//
// Cuatro responsabilidades relacionadas, todas necesarias en el arranque (Day 0):
//   - Probe(): verificar activamente si la delegación de cgroup está operativa
//     creando un cgroup hijo de prueba y escribiendo en cgroup.procs.
//   - IsBareMetal(): detectar si el proceso corre en bare metal o en un contenedor
//     (docker, podman, nspawn). Determina qué estrategia de delegación aplicar.
//   - ConfigureSystemdDelegate(): escribir el drop-in Delegate=yes cuando bos corre
//     en bare metal y la delegación falla. Habilita la subtree_control para K8s.
//   - DetectContainerMapping(): leer /proc/self/uid_map para determinar el UID/GID
//     correcto de ownership del directorio cgroup en contenedores anidados.
//
// # Fuera de alcance
//
// No crea el cgroup k8s.io — eso es bootstrap.Setup() paso 7.
// No gestiona cgroup en tiempo de ejecución — eso es kubelet.
// No verifica controladores del kernel (cpu, memory, pids) — solo la delegación.
// No interactúa con pods directamente.
//
// # Dependencias
//
// Ninguna dependencia de otros paquetes internos.
// Lee /proc/self/uid_map, /proc/self/gid_map, /proc/self/cgroup del kernel.
// Escribe en /etc/systemd/system/<servicio>.d/delegate.conf (override via SystemdDir).
//
// # Callers principales
//
// cmd/bos/main.go:autoBootstrap — paso 8, verificación y corrección de delegación.
// No hay otros callers — son operaciones de arranque únicas.
//
// # Estándares y referencias
//
// SBOS-018 §4.2 — Prerrequisitos del sistema operativo para K8s.
// BOS-REPAIR-01 §Criterio-C-02 — cgroup v2 delegado antes de instalar K8s.
// Kernel docs: cgroup v2 delegation, /sys/fs/cgroup/cgroup.controllers.
// systemd docs: Delegate=yes en unidades de servicio.
//
// # Ejemplo de uso
//
//	// Verificar delegación y corregir si falla
//	if !cgroup.Probe(cgPath) {
//	    if cgroup.IsBareMetal() {
//	        if err := cgroup.ConfigureSystemdDelegate("bos.service"); err != nil {
//	            log.Fatal().Err(err).Msg("no se pudo configurar Delegate=yes")
//	        }
//	    }
//	}
//
//	// Corregir ownership en contenedores anidados
//	uid, gid := cgroup.DetectContainerMapping()
//	if uid != 0 || gid != 0 {
//	    os.Chown(cgPath, uid, gid)
//	}
package cgroup
