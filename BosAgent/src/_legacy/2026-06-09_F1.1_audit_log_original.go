// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// SOLO REFERENCIA DE LÓGICA — NO IMPORTAR, NO COPIAR COMO ESTÁ.
//
// Origen: cmd/bos/main.go (extraído en átomo F1.1)
// Destino: internal/audit/log.go
//
// La función auditLog() fue extraída tal cual a internal/audit.Log().
// La firma es idéntica para migración drop-in.
// Este archivo documenta la lógica original antes de la refactorización.

package legacy

import (
	"fmt"
	"os"
	"strings"
	"time"
)

// auditLog agrega una entrada estructurada al log de auditoría.
// Formato: [ISO-8601] CATEGORÍA clave=valor clave=valor ...
// La contraseña NUNCA se registra en el log.
func auditLog(path string, category string, kvs ...string) {
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	defer f.Close()

	ts := time.Now().UTC().Format("2006-01-02 15:04:05")
	line := fmt.Sprintf("[%s] %s %s\n", ts, category, strings.Join(kvs, " "))
	f.WriteString(line)
}
