// stub-daemon — placeholder mínimo para daemons soberanos SBOS en desarrollo.
// El daemon real se implementará en su propio repositorio (BkernelAgent, BiedataAgent, etc.).
// Este stub permite que BOS instale la ficha, cree el servicio systemd y marque INSTALLED,
// sin bloquear el instalador mientras el daemon real está en desarrollo.
//
// Configuración vía variables de entorno (inyectadas por el servicio systemd):
//   DAEMON_NAME    — nombre legible (bkernel, biedata, bnotify, bsearch, banexus)
//   DAEMON_SOCKET  — ruta del socket Unix a crear (vacío = sin socket)
//   DAEMON_VERSION — versión del stub (default: 0.0.1-stub)
package main

import (
	"fmt"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	name := getenv("DAEMON_NAME", "daemon-stub")
	socketPath := getenv("DAEMON_SOCKET", "")
	version := getenv("DAEMON_VERSION", "0.0.1-stub")

	logf(name, "iniciando — versión %s (STUB — pendiente de implementación)", version)
	logf(name, "el daemon real será implementado en su repositorio dedicado")

	if socketPath != "" {
		if err := os.Remove(socketPath); err != nil && !os.IsNotExist(err) {
			logf(name, "advertencia: no se pudo eliminar socket previo: %v", err)
		}
		l, err := net.Listen("unix", socketPath)
		if err != nil {
			logf(name, "advertencia: no se pudo crear socket %s: %v", socketPath, err)
		} else {
			logf(name, "socket Unix listo: %s", socketPath)
			if err := os.Chmod(socketPath, 0660); err != nil {
				logf(name, "advertencia: chmod socket: %v", err)
			}
			defer l.Close()
			go func() {
				for {
					conn, err := l.Accept()
					if err != nil {
						return
					}
					// Responde vacío y cierra — suficiente para health checks de socket
					conn.Close()
				}
			}()
		}
	}

	// Notificar a systemd que estamos listos (sd_notify READY=1 via env)
	if notifySocket := os.Getenv("NOTIFY_SOCKET"); notifySocket != "" {
		conn, err := net.Dial("unixgram", notifySocket)
		if err == nil {
			fmt.Fprintf(conn, "READY=1\n")
			conn.Close()
		}
	}

	logf(name, "en espera (heartbeat cada 60s) — enviar SIGTERM para detener")

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)

	ticker := time.NewTicker(60 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case sig := <-sigCh:
			logf(name, "señal %v recibida — apagando ordenadamente", sig)
			if socketPath != "" {
				os.Remove(socketPath)
			}
			os.Exit(0)
		case <-ticker.C:
			logf(name, "heartbeat (stub activo — daemon real en desarrollo)")
		}
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func logf(name, format string, args ...any) {
	msg := fmt.Sprintf(format, args...)
	fmt.Printf("[%s %s] %s\n",
		time.Now().UTC().Format("2006-01-02T15:04:05Z"),
		name, msg)
}
