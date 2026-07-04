// Package boslog — logging del ecosistema BOS sobre journald de Ubuntu.
//
// No se inventa nada: Ubuntu ya tiene journald con rotación, retención,
// indexación y queries. Solo se inyecta SYSLOG_IDENTIFIER=bos-<componente>
// para poder filtrar por origen.
//
// Queries útiles:
//
//	journalctl -t bos                   # todos los componentes BOS
//	journalctl -t bos-bosctl            # solo el instalador
//	journalctl -t bos-bkernel           # solo bkernel
//	journalctl -t bos -p err            # solo errores de BOS
//	journalctl -t bos --since "1h ago"  # última hora
//	journalctl -u bos.service           # logs del daemon bos (systemd)
//
// Para daemons systemd (bos.service, bkernel.service, etc.):
// escribir a stdout/stderr es suficiente — systemd los captura en journald
// con UNIT= automáticamente. Llamar boslog.Init("bos") añade el tag extra.
//
// Fallback: si syslog no está disponible (entorno sin systemd, CI),
// escribe a stderr para no silenciar los logs.
package boslog

import (
	"fmt"
	"log/slog"
	"log/syslog"
	"os"
	"sync"
)

var (
	mu        sync.Mutex
	logger    *slog.Logger
	component string // ej: "bosctl", "bkernel", "biedata"
)

// Init configura el logger para el componente dado.
// Identificador journald: "bos-<comp>" (ej: "bos-bosctl").
// Idempotente: segunda llamada no hace nada.
func Init(comp string) {
	mu.Lock()
	defer mu.Unlock()
	if logger != nil {
		return
	}
	component = comp
	tag := "bos-" + comp

	w, err := syslog.New(syslog.LOG_INFO|syslog.LOG_DAEMON, tag)
	if err != nil {
		// Sin syslog (CI, contenedor sin systemd): stderr con prefijo identificador.
		h := slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelDebug})
		logger = slog.New(h).With("bos_comp", tag)
		return
	}
	// slog con syslog como destino. TextHandler formatea key=value inline
	// para que sea legible en journalctl sin herramientas extra.
	h := slog.NewTextHandler(w, &slog.HandlerOptions{Level: slog.LevelDebug})
	logger = slog.New(h).With("bos_comp", tag)
}

// LogPath devuelve la query journalctl equivalente para este componente.
// Útil para mostrar al usuario dónde buscar los logs.
func LogPath() string {
	mu.Lock()
	defer mu.Unlock()
	if component == "" {
		return "journalctl -t bos"
	}
	return fmt.Sprintf("journalctl -t bos-%s", component)
}

func get() *slog.Logger {
	mu.Lock()
	defer mu.Unlock()
	if logger == nil {
		// Sin Init(): fallback a stderr con identificador genérico.
		return slog.New(slog.NewTextHandler(os.Stderr, nil)).With("bos_comp", "bos-unknown")
	}
	return logger
}

func Info(msg string, args ...any)  { get().Info(msg, args...) }
func Warn(msg string, args ...any)  { get().Warn(msg, args...) }
func Error(msg string, args ...any) { get().Error(msg, args...) }
func Debug(msg string, args ...any) { get().Debug(msg, args...) }
