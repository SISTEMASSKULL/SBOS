// Package audit implementa el logger de auditoría ISO 27001 A.8.15.
package audit

import (
	"fmt"
	"os"
	"strings"
	"time"
)

// Log agrega una entrada estructurada de auditoría al archivo en path.
//
// Formato de cada línea: [YYYY-MM-DD HH:MM:SS] CATEGORÍA clave=valor ...
// El timestamp es UTC. Los pares clave=valor se separan por espacios.
// Las entradas son inmutables: nunca se modifican ni eliminan (solo append).
//
// Recibe:
//   - path: string — ruta absoluta del archivo de audit log (p.ej. paths.AuditLog).
//     El directorio debe existir; si no existe, el error se ignora silenciosamente.
//   - category: string — etiqueta en mayúsculas de la categoría del evento.
//     Valores usados en el proyecto: STARTUP, BOOTSTRAP, INSTALL, REPAIR,
//     CGROUP, CREDENTIALS, CONTEXT, SHUTDOWN.
//   - kvs: ...string — pares "clave=valor" con el contexto del evento.
//     ISO 27001:2022 A.8.15 requiere al menos: actor (user=), acción (action=)
//     y resultado (result=). NUNCA incluir contraseñas ni tokens.
//
// Retorna: nada. Los errores de apertura o escritura se silencian — la auditoría
// no debe interrumpir la operación del daemon.
//
// Callers conocidos:
//   - cmd/bos/main.go: STARTUP, SHUTDOWN del daemon.
//   - internal/bootstrap/setup.go: BOOTSTRAP, CGROUP, CREDENTIALS.
//   - internal/installer/saga.go: INSTALL, REPAIR, REMOVE por cada paso de saga.
//   - internal/server/jsonrpc.go: toda invocación RPC recibida.
//
// Efectos secundarios:
//   - Abre el archivo en modo O_APPEND|O_CREATE con permisos 0600.
//   - Thread-safe: O_APPEND es atómico en Linux para escrituras < PIPE_BUF (~4KB).
//
// Estándares: ISO 27001:2022 A.8.15 (Logging), NIST SP 800-92 (Log Management).
//
//	audit.Log(paths.AuditLog, "STARTUP", "user=root", "tenant=acme", "result=ok")
func Log(path string, category string, kvs ...string) {
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	defer f.Close()

	ts := time.Now().UTC().Format("2006-01-02 15:04:05")
	line := fmt.Sprintf("[%s] %s %s\n", ts, category, strings.Join(kvs, " "))
	// A-11: loggear a stderr si la escritura falla — no silenciar pérdida de audit (ISO 27001 A.8.15)
	if _, err := f.WriteString(line); err != nil {
		fmt.Fprintf(os.Stderr, "AUDIT FAIL path=%s category=%s error=%v\n", path, category, err)
	}
}
