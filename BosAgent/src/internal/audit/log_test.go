// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package audit_test

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"testing"

	"bos/internal/audit"
)

func TestLog_EscribeEnArchivo(t *testing.T) {
	t.Parallel()
	path := filepath.Join(t.TempDir(), "audit.log")
	audit.Log(path, "TEST", "action=test_write")
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("no se pudo leer el archivo: %v", err)
	}
	if len(data) == 0 {
		t.Fatal("archivo vacío — Log() no escribió nada")
	}
}

func TestLog_FormatoISO27001(t *testing.T) {
	t.Parallel()
	path := filepath.Join(t.TempDir(), "audit.log")
	audit.Log(path, "STARTUP", "user=root", "action=daemon_start", "result=ok")

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("no se pudo leer el archivo: %v", err)
	}
	line := strings.TrimSpace(string(data))

	// Timestamp ISO-8601 al inicio: [YYYY-MM-DD HH:MM:SS]
	re := regexp.MustCompile(`^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]`)
	if !re.MatchString(line) {
		t.Errorf("timestamp no cumple ISO-8601 A.8.15: %q", line)
	}
	// Categoría presente
	if !strings.Contains(line, "] STARTUP ") {
		t.Errorf("categoría ausente en la línea: %q", line)
	}
	// Campos obligatorios ISO 27001 A.8.15: actor, acción, resultado
	for _, field := range []string{"user=root", "action=daemon_start", "result=ok"} {
		if !strings.Contains(line, field) {
			t.Errorf("campo %q ausente en la línea: %q", field, line)
		}
	}
}

func TestLog_CreaArchivoSiNoExiste(t *testing.T) {
	t.Parallel()
	path := filepath.Join(t.TempDir(), "audit.log")
	// Verificar que el archivo no existe antes de llamar
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("precondición fallida: el archivo ya existía")
	}
	audit.Log(path, "INIT", "action=create_test")
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("Log() no creó el archivo: %v", err)
	}
}

func TestLog_IdempotenteConcurrencia(t *testing.T) {
	t.Parallel()
	path := filepath.Join(t.TempDir(), "audit.log")

	const goroutines = 10
	const writesPerGoroutine = 50

	var wg sync.WaitGroup
	wg.Add(goroutines)
	for i := range goroutines {
		go func(id int) {
			defer wg.Done()
			for j := range writesPerGoroutine {
				audit.Log(path, "CONCURRENCY",
					fmt.Sprintf("goroutine=%d", id),
					fmt.Sprintf("iter=%d", j))
			}
		}(i)
	}
	wg.Wait()

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("no se pudo leer el archivo después de concurrencia: %v", err)
	}
	lines := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
	expected := goroutines * writesPerGoroutine
	if len(lines) != expected {
		t.Errorf("esperadas %d líneas, got %d — posible corrupción por race", expected, len(lines))
	}
	// Verificar que ninguna línea está vacía o corrupta
	for i, l := range lines {
		if !strings.HasPrefix(l, "[") {
			t.Errorf("línea %d corrupta (no empieza con timestamp): %q", i, l)
		}
	}
}
