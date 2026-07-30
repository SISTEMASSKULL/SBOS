package grpc

// logport.go — LogReader: implementa domain.LogPort leyendo /var/log/bos/fichas/<id>.log

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"bos/internal/domain"
)

const logBaseDir = "/var/log/bos/fichas"

// LogReader lee logs de ficha desde disco.
// Formato de línea esperado: "2006-01-02T15:04:05Z LEVEL mensaje..."
// Si la línea no cumple el formato, todo el contenido va a Message.
type LogReader struct{}

// NewLogReader crea un LogReader con la ruta base canónica.
func NewLogReader() *LogReader { return &LogReader{} }

func logFilePath(fichaID string) string {
	return filepath.Join(logBaseDir, fichaID+".log")
}

// ReadLog retorna las últimas tailLines líneas del log de la ficha.
// Si tailLines <= 0 usa 50 como default. Si el archivo no existe, retorna slice vacío.
func (r *LogReader) ReadLog(fichaID string, tailLines int32) ([]domain.LogEntry, error) {
	if fichaID == "" {
		return nil, fmt.Errorf("logport: fichaID obligatorio")
	}
	if tailLines <= 0 {
		tailLines = 50
	}

	f, err := os.Open(logFilePath(fichaID))
	if err != nil {
		if os.IsNotExist(err) {
			return []domain.LogEntry{}, nil
		}
		return nil, fmt.Errorf("logport: abrir log %s: %w", fichaID, err)
	}
	defer f.Close()

	var lines []string
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("logport: leer log %s: %w", fichaID, err)
	}

	start := len(lines) - int(tailLines)
	if start < 0 {
		start = 0
	}
	tail := lines[start:]

	entries := make([]domain.LogEntry, 0, len(tail))
	for i, line := range tail {
		entries = append(entries, parseLogLine(fichaID, int64(start+i+1), line))
	}
	return entries, nil
}

// FollowLog retorna un canal con nuevas líneas del log a partir del final del archivo.
// El canal se cierra cuando el goroutine llega al EOF del scan (sin inotify).
func (r *LogReader) FollowLog(fichaID string) (<-chan domain.LogEntry, error) {
	if fichaID == "" {
		return nil, fmt.Errorf("logport: fichaID obligatorio")
	}

	ch := make(chan domain.LogEntry, 64)

	go func() {
		defer close(ch)

		f, err := os.Open(logFilePath(fichaID))
		if err != nil {
			return
		}
		defer f.Close()

		// Seek al EOF: solo emitir líneas nuevas.
		if _, err := f.Seek(0, io.SeekEnd); err != nil {
			return
		}

		var lineNum int64
		scanner := bufio.NewScanner(f)
		for scanner.Scan() {
			lineNum++
			ch <- parseLogLine(fichaID, lineNum, scanner.Text())
		}
	}()

	return ch, nil
}

// parseLogLine extrae timestamp y nivel de una línea de log.
// Formato esperado: "2006-01-02T15:04:05Z LEVEL mensaje..."
func parseLogLine(fichaID string, lineNum int64, line string) domain.LogEntry {
	entry := domain.LogEntry{
		FichaID:    fichaID,
		Level:      "INFO",
		Message:    line,
		Timestamp:  time.Now(),
		LineNumber: lineNum,
	}

	parts := strings.SplitN(line, " ", 3)
	if len(parts) < 3 {
		return entry
	}

	if t, err := time.Parse(time.RFC3339, parts[0]); err == nil {
		lvl := strings.ToUpper(parts[1])
		switch lvl {
		case "DEBUG", "INFO", "WARN", "ERROR":
			entry.Timestamp = t
			entry.Level = lvl
			entry.Message = parts[2]
		}
	}

	return entry
}
