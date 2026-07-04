// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package catalog implementa D5 — catálogo unificado de aplicaciones con
// grupos de categorías para la Core UI y la CLI.
//
// # Responsabilidades
//
//   - Leer fichas desde STATE_MANAGER y organizarlas por categoría.
//   - Exponer CategoryGroup para renderizado en TUI y API WebSocket.
//   - Mapear IDs numéricos de categoría a nombres legibles.
//
// # Fuera de alcance
//
//   - Escribir en el estado — solo lectura.
//   - Filtrado por estado o salud — responsabilidad del caller.
//   - Paginación — la lista completa de fichas no supera los cientos de entradas.
//
// # Dependencias
//
//   - internal/state — STATE_MANAGER (solo lectura).
//
// # Callers principales
//
//   - internal/server/api.go — handler "bos.catalog.list".
//   - cmd/bosctl/app.go — subcomando "bosctl catalog".
//
// # Estándares y referencias
//
//   - SBOS-019 FICHAS §3 — definición de categorías 1–6.
//   - ADR-021 — estados de las 18 máquinas de estado.
//
// # Ejemplo de uso
//
//	cat := catalog.New(stateMgr)
//	groups, err := cat.List()
//	for _, g := range groups {
//	    fmt.Printf("[%d] %s: %d fichas\n", g.CategoryID, g.CategoryName, len(g.Fichas))
//	}
package catalog
