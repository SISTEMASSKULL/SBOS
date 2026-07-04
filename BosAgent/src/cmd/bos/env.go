// env.go — carga de variables de entorno de bootstrap.
// Extraído de cmd/bos/main.go en F1.9 — SRP: main.go solo orquesta.
package main

import (
	"os"

	"github.com/joho/godotenv"

	"bos/internal/paths"
	"github.com/rs/zerolog/log"
)

// bootstrapEnv contiene los valores cargados de bos-bootstrap.env.
type bootstrapEnv struct {
	RootUser     string
	RootPassword string
	TenantID     string
	TenantName   string
	TenantDomain string
	HostIP       string
	CGroupPath   string
}

// loadBootstrapEnv lee bos-bootstrap.env desde la primera ubicación disponible.
// Orden de búsqueda: /etc/bos/, /etc/bos/core/, /opt/bos/, /tmp/, ./ (espejo de install.sh).
//
// Efectos secundarios:
//   - Lee BOS_ROOT_PASSWORD del entorno y lo elimina con os.Unsetenv (seguridad).
//   - NUNCA registrar contraseñas ni tokens en logs.
func loadBootstrapEnv() *bootstrapEnv {
	searchPaths := []string{
		paths.BootstrapEnv,
		"/etc/bos/core/bos-bootstrap.env",
		"/opt/bos/bos-bootstrap.env",
		"/opt/bos/core/bos-bootstrap.env",
		"/tmp/bos-bootstrap.env",
		"./bos-bootstrap.env",
	}

	var loaded string
	for _, p := range searchPaths {
		if _, err := os.Stat(p); err == nil {
			if err := godotenv.Load(p); err == nil {
				loaded = p
				break
			}
		}
	}

	benv := &bootstrapEnv{
		RootUser:     os.Getenv("BOS_ROOT_USER"),
		TenantID:     os.Getenv("BOS_TENANT_ID"),
		TenantName:   os.Getenv("BOS_TENANT_NAME"),
		TenantDomain: os.Getenv("BOS_TENANT_DOMAIN"),
		HostIP:       os.Getenv("BOS_HOST_IP"),
		CGroupPath:   os.Getenv("BOS_CGROUP_PATH"),
	}

	// Leer contraseña una vez y eliminar del entorno inmediatamente (seguridad).
	benv.RootPassword = os.Getenv("BOS_ROOT_PASSWORD")
	os.Unsetenv("BOS_ROOT_PASSWORD")

	if loaded != "" {
		log.Info().Interface("path", loaded).Interface("tenant", benv.TenantID).Msg("bootstrap env loaded")
	} else if os.Getenv("BOS_DEV_SKIP_ROOT") == "1" {
		log.Debug().Msg("bos-bootstrap.env not found — expected in dev mode")
	} else {
		log.Warn().Msg("bos-bootstrap.env not found — auto-bootstrap may be incomplete")
	}

	if benv.CGroupPath == "" {
		benv.CGroupPath = paths.CGroupPath
	}

	return benv
}
