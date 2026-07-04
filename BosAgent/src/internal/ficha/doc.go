// Package ficha — Ficha Engine completo del BOS (FASE 11).
// BOS-REPAIR Plan Maestro v3 · ADR-021 (18 estados) · SBOS-019.
//
// Este paquete implementa la lógica de dominio pura del administrador de fichas.
// Es independiente de protocolos de transporte (sin HTTP, sin JSON-RPC, sin gRPC).
// La persistencia se delega en state.Manager; la ejecución en installer.Orchestrator.
//
// Arquitectura del paquete (20 archivos, ~5,600 líneas, 142 tests):
//
//	Núcleo:
//	  resolver.go       — DEPENDENCY_RESOLVER: grafo + Kahn + oleadas
//	  statemachine.go   — Máquina de 18 estados ADR-021 (lógica pura)
//	  lifecycle.go      — Orquestador de ciclo de vida (install/update/repair/remove)
//	  version.go        — Versionado semántico MAJOR.MINOR.PATCH + UpdateStrategy
//
//	Operaciones:
//	  executor.go       — Pipeline de 5 fases + señales __SBOS__STEP__
//	  discovery.go      — Descubrimiento automático de servidores/
//	  health.go         — Health checker declarativo (command/http/tcp/none)
//	  drift.go          — Drift detector por hashes SHA-256
//	  reconcile.go      — Reconciliador automático (3 políticas)
//	  status.go         — Recolector de estado integral multi-fuente
//	  dashboard.go      — Dashboard Grafana mínimo (4 paneles requeridos)
//
//	Transporte (fuera de este paquete):
//	  proto/bos/ficha/v1/         — Contrato gRPC (18 RPCs + 2 streaming)
//	  internal/ficha/grpc/        — Servidor gRPC en Unix socket
//	  internal/server/jsonrpc.go  — Handlers JSON-RPC bos.ficha.*
//	  cmd/bosctl/ficha.go         — CLI WebSocket (11 subcomandos)
//
// Relación con state.Manager:
//
//	state.FichaState es el tipo de persistencia (fcntl flock, .sbos_state.json).
//	ficha.FichaState es el tipo de dominio (mismos 18 valores string, lógica pura).
//	Usar FichaStateFromString() / ToState() para convertir entre ambos.
//	state.Manager es la ÚNICA fuente de verdad de escritura (Principio P8).
//
// Estándares: ADR-019/020 (Interface Dual), ADR-021 (18 estados),
// SBOS-050 P9 (sin TCP entre daemons), SBOS-053 (headless-first),
// SBOS-055 (soberanía de fichas), SemVer 2.0.0, ISO 27001 A.8.15.
package ficha
