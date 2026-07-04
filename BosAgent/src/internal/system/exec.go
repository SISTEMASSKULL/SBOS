// Package system centraliza operaciones de bajo nivel del OS:
// ejecución de comandos raíz, control de systemd y notificaciones sd_notify.
// Extraído de cmd/bos/main.go en F1.7 — SRP: main.go solo orquesta.
//
// Thread safety: todas las funciones son stateless, seguras para uso concurrente.
//
// Estándares: ISO 27001 A.8.15 — auditoría de cada comando ejecutado.
package system

import (
	"fmt"
	"os/exec"
	"strings"

	"bos/internal/audit"
)

// ExecAsRoot ejecuta un comando externo con stdout/stderr/stdin del proceso actual.
// Registra el comando en audit.log antes de ejecutar (ISO 27001 A.8.15).
//
// Recibe:
//   - args: []string — comando y argumentos (args[0] es el ejecutable).
//
// Retorna: error del comando, nil si exitCode=0.
//
// Efectos secundarios: escribe en audit.log, hereda stdin/stdout/stderr.
// NUNCA registrar contraseñas ni tokens en logs.
func ExecAsRoot(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("exec: no command provided")
	}
	audit.Log("/var/log/bos/audit.log", "EXEC",
		"user=root",
		"cmd="+strings.Join(args, " "))

	cmd := exec.Command(args[0], args[1:]...)
	return cmd.Run()
}

// SystemctlCmd ejecuta `systemctl <action> <service>` y registra en audit.log.
//
// Recibe:
//   - action: string — start | stop | restart | enable | disable | status.
//   - service: string — nombre de la unidad systemd (ej. "bos.service").
//
// Retorna: error si systemctl retorna exit != 0.
//
// Efectos secundarios: registra en audit.log; ejecuta systemctl en el host.
func SystemctlCmd(action, service string) error {
	audit.Log("/var/log/bos/audit.log", "SYSCMD",
		"user=root",
		"action=systemctl "+action+" "+service)

	cmd := exec.Command("systemctl", action, service)
	return cmd.Run()
}
