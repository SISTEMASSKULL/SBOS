// Package domain implementa la capa de negocio del IAM Installer BOS.
// ORQUESTA-043 §2 — Capa de Dominio: completamente independiente de HTTP,
// JSON-RPC y cualquier protocolo de transporte.
//
// # Responsabilidades
//
//   - Definir errores de dominio canónicos (ErrFichaIDRequired, ErrSagaFailed, etc.).
//   - Implementar FichaService: orquesta sagas de fichas usando STATE_MANAGER y
//     el Orchestrator de sagas.
//   - Implementar BootstrapService: inicia el flujo bootstrap de 6 capas.
//   - Exponer helpers de tipo (IsFichaNotFound, IsSagaFailed) para mapeo a RPC.
//
// # Fuera de alcance
//
//   - Codificación/decodificación JSON-RPC — responsabilidad de internal/server/.
//   - Ejecución de comandos Bash — responsabilidad de internal/installer/.
//   - Gestión de estado en disco — responsabilidad de internal/state/.
//
// # Dependencias
//
//   - internal/installer — Orchestrator (Install/Update/Repair/Remove/Probe).
//   - internal/state — STATE_MANAGER (Transition, Register, Read).
//   - internal/plugin — FichaManifest para validación de IDs.
//
// # Callers principales
//
//   - internal/server/ws.go — handlers JSON-RPC llaman FichaService.Install, etc.
//   - internal/server/bootstrap.go — handlers bootstrap llaman BootstrapService.
//
// # Estándares y referencias
//
//   - ORQUESTA-043 §2 — separación Domain/RPC/Transport.
//   - ADR-021 — máquina de 18 estados de fichas.
//   - SBOS-049 — ctx_id obligatorio en toda operación (ErrTraceparentRequired).
//
// # Ejemplo de uso
//
//	svc := domain.NewFichaService(orchestrator, stateMgr, pluginLoader)
//	result, err := svc.Install(ctx, "postgresql", "18.4")
package domain
