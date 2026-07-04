// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package config carga y valida la configuración de bos desde bos.toml y
// bos-install.toml (parámetros específicos del cliente).
//
// # Responsabilidades
//
//   - Leer bos.toml (valores de tiempo de ejecución) y bos-install.toml
//     (valores de instalación del cliente: org, dominio, IP servidor).
//   - Aplicar el orden de resolución: env var > bos-install.toml > bos.toml > defaults.
//   - Exponer SagaTimeout() para que el orquestador use timeouts correctos por operación.
//   - Exponer DNSConfig.Subdomain() para construir FQDNs sin hardcoding.
//
// # Fuera de alcance
//
//   - Recarga en caliente de configuración — bos.service requiere reinicio.
//   - Validación de conectividad (puertos, IPs) — responsabilidad del bootstrap.
//   - Cifrado de valores sensibles — los secretos van en Vault, no en bos.toml.
//
// # Dependencias
//
//   - internal/toml — decodificador TOML mínimo sin dependencias externas.
//   - internal/paths — rutas de los archivos de configuración (P16).
//
// # Callers principales
//
//   - cmd/bos/main.go — carga Config al inicio del daemon.
//   - internal/installer/saga.go — consulta SagaTimeout por tipo de saga.
//
// # Estándares y referencias
//
//   - P16 Zero Hardcoding — todo path/subdomain vía config, nunca literal.
//   - SBOS-035 §1.1 — schema de bos-install.toml.
//   - SBOS-050 §DNS — política de subdominios y puertos.
//
// # Ejemplo de uso
//
//	cfg, err := config.Load(paths.BosToml, paths.BosInstallToml)
//	if err != nil {
//	    log.Fatal(err)
//	}
//	timeout := cfg.SagaTimeout("install") // 30 min
package config
