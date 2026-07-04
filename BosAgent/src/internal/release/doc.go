// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package release gestiona la verificación pull-only de versiones contra el
// SKULL Release Plane. El daemon bos NUNCA recibe pushes — solo consulta.
//
// # Responsabilidades
//
//   - Consultar el Release Plane vía HTTP para obtener versiones disponibles
//     por ficha y canal (canary, early, stable).
//   - Cachear resultados con TTL para evitar sobrecarga del Release Server.
//   - Implementar backoff exponencial cuando el Release Server no está disponible.
//   - Verificar la firma Ed25519 + SHA-256 de cada release (P5).
//
// # Fuera de alcance
//
//   - Instalar o actualizar fichas — responsabilidad del installer/observer.
//   - Almacenar artefactos de releases — responsabilidad del Release Plane.
//   - Gestionar canales de release — configurado en bos-install.toml.
//
// # Dependencias
//
//   - net/http — cliente HTTP con timeout 30s.
//   - log/slog — logging de consultas y errores de conectividad.
//
// # Callers principales
//
//   - internal/server/api.go — handler "bos.ficha.status" incluye versión disponible.
//   - cmd/bosctl/app.go — subcomando "bosctl release check".
//
// # Estándares y referencias
//
//   - P5 — pull-only, nunca recibe pushes del Release Plane.
//   - SBOS-041 RELEASE-PLANE — firma Ed25519, canales canary/early/stable.
//   - ADR-017 — versiones canónicas del stack SBOS.
//
// # Ejemplo de uso
//
//	mgr := release.NewManager(cfg.Install.ReleaseServerURL, cfg.Install.Channel, logger)
//	available, err := mgr.CheckAvailable("postgresql", "18.4")
package release
