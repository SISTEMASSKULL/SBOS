// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package paths centraliza todas las rutas canónicas del daemon bos.
//
// # Responsabilidades
//
// Proveer constantes y funciones para todas las rutas del sistema que usa bos:
//   - /etc/bos/: configuración estática del daemon.
//   - /run/bos/: artefactos en tiempo de ejecución (bos.sock, PID, locks).
//   - /opt/bos/: binarios y assets del sistema.
//   - /var/log/bos/: logs de auditoría y operación.
//   - /var/lib/bos/: estado persistente (.sbos_state.json, fichas).
//
// Toda ruta que aparezca literalmente en otro paquete es un defecto.
// La única fuente de verdad para rutas es este paquete.
//
// # Fuera de alcance
//
// No verifica si las rutas existen — eso es bootstrap.Setup().
// No crea directorios — solo declara las rutas.
// No gestiona permisos — eso es bootstrap.Setup() + systemd.
//
// # Dependencias
//
// Ninguna dependencia de otros paquetes internos.
// Sin imports — solo constantes y funciones de la biblioteca estándar.
//
// # Callers principales
//
// Prácticamente todos los paquetes de internal/ y cmd/ usan este paquete.
// Es el único con dependencia universal — no genera ciclos porque no importa nada.
//
// # Estándares y referencias
//
// SBOS-050 §2 — Estructura de directorios del host.
// FHS (Filesystem Hierarchy Standard) — convenciones de rutas Linux.
// BOS-REPAIR-02 — Centralización de paths (P2 × 4 archivos).
//
// # Ejemplo de uso
//
//	socketPath := paths.SocketPath         // "/run/bos/bos.sock"
//	statePath  := paths.StatePath          // "/etc/bos/.sbos_state.json"
//	auditLog   := paths.AuditLog           // "/var/log/bos/audit.log"
//	configDir  := paths.ConfigDir("certs") // "/etc/bos/certs"
package paths
