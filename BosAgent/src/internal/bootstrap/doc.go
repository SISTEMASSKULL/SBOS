// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package bootstrap implementa el setup inicial y la verificación del entorno
// del daemon bos, conforme a SBOS-018 §6 (Criterios de Certificación C-01..C-08).
//
// # Responsabilidades
//
// Dos responsabilidades separadas en dos archivos:
//   - setup.go: configura el entorno en el arranque del daemon (directorios,
//     archivos de configuración, permisos, dependencias del sistema).
//   - verify.go: verifica que los criterios C-01..C-08 estén satisfechos
//     antes de entrar al modo de operación normal.
//
// # Fuera de alcance
//
// No gestiona el ciclo de vida de fichas — eso es installer.Orchestrator.
// No detecta drift de configuración en tiempo real — eso es reconcile.Scheduler.
// No expone API externa — es un paquete de uso interno en el arranque.
//
// # Dependencias
//
// internal/paths: para rutas canónicas del sistema.
// internal/audit: para registrar cada criterio verificado.
//
// # Callers principales
//
// cmd/bos/main.go: invoca bootstrap.Setup() y bootstrap.Verify() al arrancar.
// No hay otros callers — es exclusivo del arranque del daemon.
//
// # Estándares y referencias
//
// SBOS-018 §6 — Criterios de certificación C-01..C-08.
// BOS-REPAIR-01 — Efectividad y verificación del bootstrap.
// ADR-003 — Estándares de documentación.
//
// # Ejemplo de uso
//
//	if err := bootstrap.Setup(cfg); err != nil {
//	    log.Fatalf("bootstrap setup: %v", err)
//	}
//	if err := bootstrap.Verify(); err != nil {
//	    log.Fatalf("criterios de certificación no satisfechos: %v", err)
//	}
package bootstrap
