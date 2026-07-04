// Package ficha — Lector de logs de ficha (F11.F.2).
// BOS-REPAIR Plan Maestro v3 · DTC-08.
//
// Cada ficha escribe su log en /var/log/bos/fichas/<name>.log.
// El lector permite consultar las últimas N líneas (tail) o seguir
// el streaming en tiempo real (follow, equivalente a tail -f).
//
// DTC-08: el log debe ser legible sin TUI. Este lector es usado por:
//   - bosctl ficha logs <name> --tail=50 (CLI)
//   - bosctl ficha logs <name> --follow (CLI, streaming en terminal)
//   - gRPC GetLogs (server-streaming para observadores)
//   - WebSocket (streaming al TUI durante instalación)
//
// Formato del archivo de log: JSON Lines (un JSON por línea).
// Rotación: 10MB por archivo, 5 archivos (configurable en manifest.yml).
package ficha

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"log/slog"
)

// ── Tipos ────────────────────────────────────────────────────────────

// LogEntry representa una línea de log de ficha.
type LogEntry struct {
	FichaID    string    `json:"ficha_id"`
	Level      string    `json:"level"` // DEBUG, INFO, WARN, ERROR
	Message    string    `json:"message"`
	Timestamp  time.Time `json:"timestamp"`
	LineNumber int64     `json:"line_number"`
}

// LogReader lee archivos de log de fichas desde disco.
type LogReader struct {
	logDir  string // directorio base: /var/log/bos/fichas
	logger  *slog.Logger
}

// NewLogReader crea un lector de logs.
func NewLogReader(logDir string, logger *slog.Logger) *LogReader {
	if logDir == "" {
		logDir = "/var/log/bos/fichas"
	}
	if logger == nil {
		logger = slog.Default()
	}
	return &LogReader{logDir: logDir, logger: logger}
}

// ReadTail lee las últimas N líneas del log de una ficha.
func (r *LogReader) ReadTail(fichaID string, n int32) ([]LogEntry, error) {
	if fichaID == "" {
		return nil, fmt.Errorf("ficha_id requerido")
	}
	if n <= 0 {
		n = 50
	}

	logPath := r.logPath(fichaID)
	file, err := os.Open(logPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("archivo de log no encontrado: %s", logPath)
		}
		return nil, fmt.Errorf("abrir log: %w", err)
	}
	defer file.Close()

	// Leer todas las líneas
	var lines []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}

	// Tomar las últimas N
	start := 0
	if len(lines) > int(n) {
		start = len(lines) - int(n)
	}

	entries := make([]LogEntry, 0, len(lines)-start)
	for i := start; i < len(lines); i++ {
		entry := parseLogLine(lines[i], fichaID)
		entry.LineNumber = int64(i + 1)
		entries = append(entries, entry)
	}

	return entries, nil
}

// FollowLog retorna un canal que emite líneas de log en tiempo real.
// El caller debe cerrar el canal cuando termine.
func (r *LogReader) FollowLog(fichaID string) (<-chan LogEntry, error) {
	if fichaID == "" {
		return nil, fmt.Errorf("ficha_id requerido")
	}

	logPath := r.logPath(fichaID)
	file, err := os.Open(logPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("archivo de log no encontrado: %s", logPath)
		}
		return nil, fmt.Errorf("abrir log: %w", err)
	}

	ch := make(chan LogEntry, 100)

	go func() {
		defer file.Close()
		defer close(ch)

		// Ir al final del archivo
		file.Seek(0, io.SeekEnd)

		var lineNum int64 = 0
		reader := bufio.NewReader(file)

		for {
			line, err := reader.ReadString('\n')
			if err != nil {
				// Esperar si EOF (tail -f behavior)
				if err == io.EOF {
					time.Sleep(200 * time.Millisecond)
					continue
				}
				r.logger.Debug("follow log terminado", "ficha", fichaID, "err", err)
				return
			}

			lineNum++
			entry := parseLogLine(strings.TrimRight(line, "\n"), fichaID)
			entry.LineNumber = lineNum

			select {
			case ch <- entry:
			default:
				// Canal lleno — descartar (evita bloquear)
				r.logger.Debug("canal de log lleno, descartando línea", "ficha", fichaID)
			}
		}
	}()

	return ch, nil
}

// ── Helpers ────────────────────────────────────────────────────────────

func (r *LogReader) logPath(fichaID string) string {
	return filepath.Join(r.logDir, fichaID+".log")
}

// parseLogLine convierte una línea de texto a LogEntry.
// Soporta JSON Lines ({"level":"INFO","message":"..."}) y texto plano.
func parseLogLine(line, fichaID string) LogEntry {
	entry := LogEntry{
		FichaID:   fichaID,
		Timestamp: time.Now(),
		Level:     "INFO",
		Message:   line,
	}

	// Intentar parsear como JSON
	line = strings.TrimSpace(line)
	if len(line) > 0 && line[0] == '{' {
		// Parseo simple sin encoding/json para performance
		entry.Level = extractJSONField(line, "level")
		if msg := extractJSONField(line, "message"); msg != "" {
			entry.Message = msg
		}
		if ts := extractJSONField(line, "timestamp"); ts != "" {
			if t, err := time.Parse(time.RFC3339, ts); err == nil {
				entry.Timestamp = t
			}
		}
	} else if len(line) > 0 {
		// Texto plano — inferir nivel por prefijo
		switch {
		case strings.HasPrefix(line, "ERROR") || strings.HasPrefix(line, "FATAL"):
			entry.Level = "ERROR"
		case strings.HasPrefix(line, "WARN"):
			entry.Level = "WARN"
		case strings.HasPrefix(line, "DEBUG"):
			entry.Level = "DEBUG"
		}
	}

	return entry
}

// extractJSONField extrae un campo simple de un JSON plano.
// Solo funciona para strings, sin anidamiento.
func extractJSONField(jsonStr, field string) string {
	key := fmt.Sprintf(`"%s":`, field)
	idx := strings.Index(jsonStr, key)
	if idx < 0 {
		return ""
	}

	start := idx + len(key)
	// Saltar espacios
	for start < len(jsonStr) && jsonStr[start] == ' ' {
		start++
	}

	if start >= len(jsonStr) || jsonStr[start] != '"' {
		return ""
	}
	start++ // saltar comilla de apertura

	end := strings.Index(jsonStr[start:], `"`)
	if end < 0 {
		return ""
	}

	return jsonStr[start : start+end]
}
