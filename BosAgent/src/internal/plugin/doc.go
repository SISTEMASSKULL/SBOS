// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package plugin escanea el directorio servers/ en busca de fichas válidas,
// valida sus contratos, calcula hashes SHA-256 de integridad y las registra
// en STATE_MANAGER.
//
// # Responsabilidades
//
//   - Descubrir fichas en servers/<servidor>/<nombre>/ buscando task_catalog.sh.
//   - Leer y parsear manifest.yml de cada ficha (ExecutionOrder, Dependencies,
//     AutoInstall, Criticality, WorkloadType, Backend).
//   - Calcular hashes SHA-256 de los archivos declarativos (P16 — integridad).
//   - Registrar fichas nuevas en STATE_MANAGER con estado inicial PENDIENTE.
//
// # Fuera de alcance
//
//   - Ejecutar fichas — responsabilidad del installer.
//   - Ordenar fichas para instalación — responsabilidad del observer.
//   - Validar el contenido de task_catalog.sh — solo verifica su existencia.
//
// # Dependencias
//
//   - internal/state — STATE_MANAGER (Register para fichas nuevas).
//   - gopkg.in/yaml.v3 — parseo de manifest.yml.
//   - log/slog — logging de escaneo.
//
// # Callers principales
//
//   - cmd/bos/main.go — Scan() al inicio del daemon y tras bootstrap.
//   - internal/observer/observer.go — Loader.List() en cada tick de observación.
//
// # Estándares y referencias
//
//   - SBOS-019 FICHAS §2 — estructura de directorios y campos de manifest.yml.
//   - P16 Zero Hardcoding — rutas vía paths.ServersPath, nunca literals.
//
// # Ejemplo de uso
//
//	loader := plugin.NewLoader(paths.ServersPath, logger)
//	fichas, err := loader.Scan()
//	for _, f := range fichas {
//	    fmt.Printf("%s v%s orden=%d\n", f.ID, f.Version, f.ExecutionOrder)
//	}
package plugin
