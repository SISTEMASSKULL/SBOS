// Package server — Helpers compartidos para handlers JSON-RPC 2.0.
//
// Funciones utilitarias usadas por todos los handlers RPC:
//   parseParams  — decodificar JSON params a struct tipada
//   writeJSON    — escribir respuesta JSON al writer HTTP
//   injectEnv    — inyectar variables de entorno para una saga
//   restoreEnv   — restaurar entorno a su estado original
//
// La propagación de variables de entorno (TENANT_ID, TENANT_NAME, DOMAIN_ID, etc.)
// viaja en el campo "env" del JSON-RPC y se inyecta antes de ejecutar la saga.
// El Orchestrator serializa con mutex — sin riesgo de condición de carrera.
package server

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
)

// ── Decodificación ──────────────────────────────────────────────────────

// parseParams decodifica los parámetros JSON-RPC (raw JSON) a la struct destino.
// Si raw es nil (notificación sin params), retorna nil sin error.
func parseParams(raw json.RawMessage, dst interface{}) error {
	if raw == nil {
		return nil
	}
	return json.Unmarshal(raw, dst)
}

// ── Escritura ───────────────────────────────────────────────────────────

// mustMarshal serializa v a JSON. Si falla, loggea el error y retorna un JSON-RPC error
// interno mínimo válido para que el cliente siempre reciba una respuesta parseable.
func mustMarshal(v interface{}) []byte {
	b, err := json.Marshal(v)
	if err != nil {
		slog.Error("mustMarshal: error de serialización JSON", "error", err)
		return []byte(`{"jsonrpc":"2.0","error":{"code":-32603,"message":"internal serialization error"},"id":null}`)
	}
	return b
}

// writeJSON escribe la respuesta JSON al ResponseWriter con Content-Type application/json.
// EscapeHTML se desactiva para preservar caracteres especiales en mensajes de error.
func writeJSON(w http.ResponseWriter, v interface{}) {
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(false)
	// A-03: loggear error de serialización (no se puede cambiar status code aquí)
	if err := enc.Encode(v); err != nil {
		slog.Error("writeJSON: error al escribir respuesta", "error", err)
	}
}

// ── Propagación de variables de entorno a sagas ─────────────────────────
//
// Las variables de entorno viajan en el campo "env" del JSON-RPC y se inyectan
// en el proceso antes de ejecutar la saga. El Orchestrator serializa con mutex,
// por lo que no hay riesgo de condición de carrera entre sagas concurrentes.
//
// injectEnv guarda los valores anteriores y establece los nuevos.
// restoreEnv devuelve el entorno a su estado original, eliminando variables
// que no existían previamente (valor previo = "").

// injectEnv establece variables de entorno para una saga.
// Retorna un mapa con los valores anteriores para que restoreEnv los restaure.
func injectEnv(env map[string]string) map[string]string {
	prev := make(map[string]string, len(env))
	for k, v := range env {
		prev[k] = os.Getenv(k)
		os.Setenv(k, v)
	}
	return prev
}

// restoreEnv restaura las variables de entorno a sus valores anteriores.
// Si el valor anterior es vacío, la variable no existía previamente y se elimina.
func restoreEnv(prev, current map[string]string) {
	for k := range current {
		if oldVal, existed := prev[k]; existed && oldVal != "" {
			os.Setenv(k, oldVal)
		} else {
			os.Unsetenv(k)
		}
	}
}
