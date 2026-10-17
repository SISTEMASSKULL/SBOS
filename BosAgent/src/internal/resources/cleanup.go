// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package resources

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"github.com/rs/zerolog/log"
)

// SignalZombieParents detecta procesos zombie en /proc y envía SIGCHLD al padre
// para que ejecute wait() y los recolecte del kernel.
//
// Los zombies no consumen CPU ni RAM pero sí entradas en la tabla de procesos.
// Si la tabla se llena ("too many processes"), el sistema rechaza nuevos procesos
// y la instalación falla. Esta función previene ese escenario.
//
// Retorna el número de zombies detectados.
func SignalZombieParents() int {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return 0
	}

	// Colección deduplicada de PPIDs de zombies
	parentPIDs := make(map[int]bool)
	zombieCount := 0

	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		if _, parseErr := strconv.Atoi(e.Name()); parseErr != nil {
			continue // no es un PID numérico
		}

		data, readErr := os.ReadFile(filepath.Join("/proc", e.Name(), "status"))
		if readErr != nil {
			continue
		}

		fields := parseKV(string(data))
		if !strings.HasPrefix(strings.TrimSpace(fields["State"]), "Z") {
			continue
		}

		ppid, _ := strconv.Atoi(strings.TrimSpace(fields["PPid"]))
		pid, _ := strconv.Atoi(e.Name())
		name := strings.TrimSpace(fields["Name"])

		log.Info().
			Int("zombie_pid", pid).
			Int("parent_pid", ppid).
			Str("nombre", name).
			Msg("resources: proceso zombie detectado")

		zombieCount++
		// PID 1 (init/systemd) recolecta zombies automáticamente — no señalizar
		if ppid > 1 {
			parentPIDs[ppid] = true
		}
	}

	for ppid := range parentPIDs {
		proc, findErr := os.FindProcess(ppid)
		if findErr != nil {
			continue
		}
		if sigErr := proc.Signal(syscall.SIGCHLD); sigErr != nil {
			log.Debug().Err(sigErr).Int("ppid", ppid).Msg("resources: SIGCHLD al padre falló")
		} else {
			log.Info().Int("ppid", ppid).Msg("resources: SIGCHLD enviado — padre debe recolectar zombie")
		}
	}

	return zombieCount
}
