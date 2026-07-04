package system

import (
	"net"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/rs/zerolog/log"
)

// SDNotify envía una cadena de estado al socket de notificación de systemd.
// No-op cuando NOTIFY_SOCKET no está configurado (fuera de systemd).
// Soporta sockets abstractos (prefijo @).
//
// Recibe:
//   - state: string — ej. "READY=1", "WATCHDOG=1", "STOPPING=1".
//
// Efectos secundarios: escribe un datagrama unixgram a NOTIFY_SOCKET.
func SDNotify(state string) {
	socketPath := os.Getenv("NOTIFY_SOCKET")
	if socketPath == "" {
		return
	}
	if strings.HasPrefix(socketPath, "@") {
		socketPath = "\x00" + socketPath[1:]
	}
	addr := &net.UnixAddr{Name: socketPath, Net: "unixgram"}
	conn, err := net.DialUnix("unixgram", nil, addr)
	if err != nil {
		log.Warn().Err(err).Msg("sd_notify: no se pudo conectar")
		return
	}
	defer conn.Close()
	if _, err := conn.Write([]byte(state)); err != nil {
		log.Warn().Err(err).Msg("sd_notify: error al escribir")
	}
}

// StartWatchdog envía WATCHDOG=1 a systemd al 50% del intervalo WatchdogSec.
// No-op cuando WATCHDOG_USEC no está definido (fuera de systemd).
// Bloquea hasta que stopCh sea cerrado.
//
// Recibe:
//   - stopCh: <-chan struct{} — cierra la goroutine al cerrarse el canal.
//
// Efectos secundarios: llama a SDNotify("WATCHDOG=1") en cada tick.
//
// Callers conocidos:
//   - cmd/bos/main.go — runNormal() lanza go StartWatchdog(stopCh).
func StartWatchdog(stopCh <-chan struct{}) {
	usecStr := os.Getenv("WATCHDOG_USEC")
	if usecStr == "" {
		return
	}
	usec, err := strconv.ParseInt(usecStr, 10, 64)
	if err != nil || usec <= 0 {
		return
	}
	interval := time.Duration(usec/2) * time.Microsecond
	log.Info().Interface("interval", interval).Msg("watchdog habilitado — supervisión systemd activa")

	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-stopCh:
			return
		case <-ticker.C:
			SDNotify("WATCHDOG=1")
		}
	}
}
