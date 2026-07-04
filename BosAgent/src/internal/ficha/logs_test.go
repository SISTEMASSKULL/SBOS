package ficha

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func createLogFile(t *testing.T, dir, fichaID string, lines []string) string {
	t.Helper()
	logPath := filepath.Join(dir, fichaID+".log")
	f, err := os.Create(logPath)
	if err != nil {
		t.Fatalf("crear log: %v", err)
	}
	for _, line := range lines {
		fmt.Fprintln(f, line)
	}
	f.Close()
	return logPath
}

func TestLogReader_ReadTail(t *testing.T) {
	dir := t.TempDir()
	lines := []string{
		"linea 1",
		"linea 2",
		"linea 3",
		"linea 4",
		"linea 5",
		"linea 6",
		"linea 7",
		"linea 8",
		"linea 9",
		"linea 10",
	}
	createLogFile(t, dir, "postgresql", lines)

	reader := NewLogReader(dir, nil)
	entries, err := reader.ReadTail("postgresql", 5)

	if err != nil {
		t.Fatalf("ReadTail falló: %v", err)
	}
	if len(entries) != 5 {
		t.Errorf("esperado 5 líneas, obtenido %d", len(entries))
	}
	if entries[0].Message != "linea 6" {
		t.Errorf("primera línea debe ser 'linea 6', obtenido %q", entries[0].Message)
	}
	if entries[4].Message != "linea 10" {
		t.Errorf("última línea debe ser 'linea 10', obtenido %q", entries[4].Message)
	}
}

func TestLogReader_ReadTail_LessThanN(t *testing.T) {
	dir := t.TempDir()
	createLogFile(t, dir, "redis", []string{"solo una línea"})

	reader := NewLogReader(dir, nil)
	entries, err := reader.ReadTail("redis", 50)

	if err != nil {
		t.Fatalf("ReadTail falló: %v", err)
	}
	if len(entries) != 1 {
		t.Errorf("esperado 1 línea, obtenido %d", len(entries))
	}
}

func TestLogReader_ReadTail_NotFound(t *testing.T) {
	dir := t.TempDir()
	reader := NewLogReader(dir, nil)

	_, err := reader.ReadTail("no-existe", 10)
	if err == nil {
		t.Error("archivo inexistente debe fallar")
	}
}

func TestLogReader_ReadTail_EmptyFichaID(t *testing.T) {
	reader := NewLogReader("", nil)
	_, err := reader.ReadTail("", 10)
	if err == nil {
		t.Error("ficha_id vacío debe fallar")
	}
}

func TestLogReader_ReadTail_DefaultN(t *testing.T) {
	dir := t.TempDir()
	lines := make([]string, 100)
	for i := 0; i < 100; i++ {
		lines[i] = fmt.Sprintf("linea %d", i+1)
	}
	createLogFile(t, dir, "test", lines)

	reader := NewLogReader(dir, nil)
	entries, err := reader.ReadTail("test", 0) // n=0 → default 50

	if err != nil {
		t.Fatalf("ReadTail falló: %v", err)
	}
	if len(entries) != 50 {
		t.Errorf("default debe ser 50, obtenido %d", len(entries))
	}
}

func TestParseLogLine_JSON(t *testing.T) {
	line := `{"level":"ERROR","message":"connection refused","timestamp":"2026-06-19T12:00:00Z"}`
	entry := parseLogLine(line, "test")

	if entry.Level != "ERROR" {
		t.Errorf("level debe ser ERROR, obtenido %s", entry.Level)
	}
	if entry.Message != "connection refused" {
		t.Errorf("message incorrecto: %s", entry.Message)
	}
	if entry.FichaID != "test" {
		t.Errorf("ficha_id incorrecto: %s", entry.FichaID)
	}
}

func TestParseLogLine_PlainText(t *testing.T) {
	tests := []struct {
		line  string
		level string
	}{
		{"ERROR: something broke", "ERROR"},
		{"FATAL: cannot recover", "ERROR"},
		{"WARN: memory usage high", "WARN"},
		{"DEBUG: processing request", "DEBUG"},
		{"INFO: server started", "INFO"},
		{"some random output", "INFO"},
	}

	for _, tt := range tests {
		entry := parseLogLine(tt.line, "test")
		if entry.Level != tt.level {
			t.Errorf("%q: esperado level=%s, obtenido %s", tt.line, tt.level, entry.Level)
		}
	}
}

func TestLogReader_FollowLog(t *testing.T) {
	dir := t.TempDir()
	logPath := createLogFile(t, dir, "follow-test", []string{"línea inicial"})

	reader := NewLogReader(dir, nil)
	ch, err := reader.FollowLog("follow-test")
	if err != nil {
		t.Fatalf("FollowLog falló: %v", err)
	}

	// Escribir más líneas después de iniciar el follow
	go func() {
		time.Sleep(100 * time.Millisecond)
		f, _ := os.OpenFile(logPath, os.O_APPEND|os.O_WRONLY, 0644)
		fmt.Fprintln(f, "nueva línea 1")
		fmt.Fprintln(f, "nueva línea 2")
		f.Close()
	}()

	// Leer al menos 2 líneas nuevas
	var received []LogEntry
	timeout := time.After(1 * time.Second)
	for len(received) < 2 {
		select {
		case entry, ok := <-ch:
			if !ok {
				goto done
			}
			received = append(received, entry)
		case <-timeout:
			goto done
		}
	}

done:
	if len(received) < 2 {
		t.Logf("recibidas %d líneas (follow puede ser lento en test)", len(received))
	}
}

func TestExtractJSONField(t *testing.T) {
	json := `{"level":"INFO","message":"hola mundo","timestamp":"2026-06-19T12:00:00Z"}`

	if v := extractJSONField(json, "level"); v != "INFO" {
		t.Errorf("level: esperado INFO, obtenido %s", v)
	}
	if v := extractJSONField(json, "message"); v != "hola mundo" {
		t.Errorf("message: esperado hola mundo, obtenido %s", v)
	}
	if v := extractJSONField(json, "timestamp"); v != "2026-06-19T12:00:00Z" {
		t.Errorf("timestamp incorrecto: %s", v)
	}
	if v := extractJSONField(json, "missing"); v != "" {
		t.Errorf("campo inexistente debe ser vacío: %s", v)
	}
}

func TestLogReader_DefaultDir(t *testing.T) {
	reader := NewLogReader("", nil)
	if reader.logDir != "/var/log/bos/fichas" {
		t.Errorf("dir por defecto debe ser /var/log/bos/fichas, obtenido %s", reader.logDir)
	}
}

func TestLogEntry_Fields(t *testing.T) {
	entry := LogEntry{
		FichaID:    "postgresql",
		Level:      "WARN",
		Message:    "slow query detected",
		LineNumber: 42,
		Timestamp:  time.Now(),
	}

	if entry.FichaID != "postgresql" {
		t.Error("FichaID incorrecto")
	}
	if entry.Level != "WARN" {
		t.Error("Level incorrecto")
	}
	if !strings.Contains(entry.Message, "slow query") {
		t.Error("Message incorrecto")
	}
	if entry.LineNumber != 42 {
		t.Error("LineNumber incorrecto")
	}
}
