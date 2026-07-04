// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package toml provee un decodificador TOML mínimo para la configuración de bos.
// Soporta el subconjunto usado por bos.toml y bos-install.toml:
// key = value (string, int, bool), secciones [section], tablas inline.
//
// # Responsabilidades
//
//   - Decodificar archivos TOML en structs Go via reflección.
//   - Exponer DecodeFile() para carga desde disco y Unmarshal() para datos en memoria.
//   - No depender de librerías TOML externas (elimina dependencia de BurntSushi/toml).
//
// # Fuera de alcance
//
//   - TOML arrays de tablas ([[tabla]]) — no usados en bos.toml.
//   - Encoding/serialización de structs a TOML — solo decodificación.
//   - Validación de valores — responsabilidad de internal/config.
//
// # Dependencias
//
//   - Solo stdlib Go: reflect, strconv, strings, os.
//
// # Callers principales
//
//   - internal/config/config.go — Load() usa DecodeFile() para ambos archivos TOML.
//
// # Estándares y referencias
//
//   - TOML v1.0 spec (subconjunto usado por bos).
//
// # Ejemplo de uso
//
//	var cfg config.Config
//	_, err := toml.DecodeFile(paths.BosToml, &cfg)
package toml
