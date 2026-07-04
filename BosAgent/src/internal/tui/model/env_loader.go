// Package model — env_loader.go: carga de valores por defecto desde bos-bootstrap.env.
// LoadEnvSeed lee el primer archivo .env encontrado en las rutas estándar y retorna
// un mapa EnvKey → valor. Si no hay archivo, usa variables de entorno del sistema.
package model

import (
	"os"
	"strings"
)

// envPaths son las rutas donde se busca bos-bootstrap.env, en orden de prioridad.
var envPaths = []string{
	"/etc/bos/bos-bootstrap.env",
	"/etc/bos/core/bos-bootstrap.env",
	"/etc/bos/.env",
	"/opt/bos/bos-bootstrap.env",
	"/tmp/bos-bootstrap.env",
	"./bos-bootstrap.env",
	"./.env",
}

// envKeys son todas las claves que el wizard necesita.
var envKeys = []string{
	"BOS_TENANT_NAME",
	"BOS_TENANT_NIT",
	"BOS_TENANT_PAIS",
	"BOS_TENANT_DOMAIN",
	"BOS_ROOT_USER",
	"BOS_ADMIN_NOMBRE",
	"BOS_ROOT_PASSWORD",
	"BOS_MFA_ENABLED",
}

// LoadEnvSeed lee el primer .env disponible y retorna un mapa EnvKey → valor.
// Orden de prioridad:
//  1. Primer archivo .env encontrado en envPaths
//  2. Variables de entorno del sistema (os.Getenv)
//  3. Valores por defecto hardcodeados (país=BO, mfa=true)
func LoadEnvSeed() map[string]string {
	result := map[string]string{
		"BOS_TENANT_PAIS": "BO",
		"BOS_MFA_ENABLED": "true",
	}

	// 1. Buscar archivo .env
	fileFound := false
	for _, p := range envPaths {
		data, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		for _, line := range strings.Split(string(data), "\n") {
			line = strings.TrimSpace(line)
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			kv := strings.SplitN(line, "=", 2)
			if len(kv) != 2 {
				continue
			}
			k := strings.TrimSpace(kv[0])
			v := strings.Trim(strings.TrimSpace(kv[1]), "\"'")
			if v != "" {
				result[k] = v
			}
		}
		fileFound = true
		break
	}

	// 2. Variables de entorno del sistema como fallback (si el archivo no tenía el valor)
	for _, k := range envKeys {
		if result[k] == "" {
			if v := os.Getenv(k); v != "" {
				result[k] = v
			}
		}
	}

	_ = fileFound
	return result
}

// SeedMFA extrae el flag BOS_MFA_ENABLED del mapa de seed (default true).
func SeedMFA(seed map[string]string) bool {
	v := seed["BOS_MFA_ENABLED"]
	return v == "" || v == "true" || v == "1"
}

// SeedValue retorna el valor de una clave del mapa de seed, o "" si no existe.
func SeedValue(seed map[string]string, envKey string) string {
	v := seed[envKey]
	if envKey == "BOS_ROOT_USER" && !strings.Contains(v, "@") {
		return ""
	}
	if envKey == "BOS_ROOT_PASSWORD_CONFIRM" {
		return seed["BOS_ROOT_PASSWORD"]
	}
	return v
}
