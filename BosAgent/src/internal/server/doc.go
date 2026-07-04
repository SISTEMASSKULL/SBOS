// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package server implementa la capa de transporte del daemon bos: WebSocket API
// sobre Unix socket y TCP, según la Interface Dual ADR-019/ADR-020.
//
// # Responsabilidades
//
//   - Escuchar en Unix socket /run/bos/bos.sock y en TCP :9443 (HTTPS).
//   - Despachar mensajes WebSocket RPC (Vía 1 — bosctl y Core UI).
//   - Despachar peticiones JSON-RPC 2.0 (Vía 2 — daemons y agentes IA).
//   - Autenticar conexiones mediante membership en el grupo "bosagent" del SO.
//   - Autenticar métodos JSON-RPC destructivos (F6.1 — auth.go: Basic
//     user:id:token + token compartido + RBAC; sin token → -32600).
//   - Acotar cada método a su plazo (F6.2 — timeout.go: 5s/30s/600s).
//   - Ejecutar batch JSON-RPC en paralelo (F6.3) y las sagas de consulta
//     bos.query.* multi-fuente (F6.6–F6.11 — query_handlers.go).
//   - Exponer /health HTTP para Kubernetes readiness/liveness probes.
//   - Modo config-pending: acciones limitadas hasta que bos-install.toml exista.
//
// # Fuera de alcance
//
//   - Lógica de negocio — responsabilidad de internal/domain/.
//   - Ejecución de sagas — responsabilidad de internal/installer/.
//   - Streaming de logs al TUI — responsabilidad de internal/server/ws.go.
//
// # Dependencias
//
//   - internal/domain/ — FichaService, BootstrapService.
//   - internal/installer/ — Orchestrator.
//   - internal/state/ — STATE_MANAGER.
//   - internal/plugin/ — Loader.
//   - internal/wslib/ — Conn, Upgrade (WebSocket sin dependencias externas).
//
// # Callers principales
//
//   - cmd/bos/main.go — startServer() en runNormal() y runConfigPending().
//
// # Estándares y referencias
//
//   - ADR-019 — Interface Dual: Vía 1 WebSocket RPC + Vía 2 JSON-RPC 2.0.
//   - ADR-020 — Unix socket obligatorio, sin HTTP/TCP entre daemons.
//   - SBOS-050 P9 — HTTP vetado entre daemons; solo WebSocket y Unix socket.
//
// # Ejemplo de uso
//
//	srv := server.New(server.Config{
//	    StateMgr:    stateMgr,
//	    Installer:   orchestrator,
//	    PluginLoader: pluginLoader,
//	})
//	srv.Listen(paths.UnixSocket, ":9443")
package server
