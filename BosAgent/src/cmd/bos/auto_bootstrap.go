// auto_bootstrap.go — bootstrap automático del host en arranque.
// Extraído de cmd/bos/main.go en F1.9 — SRP: main.go solo orquesta.
package main

import (
	"os"
	"os/exec"

	"bos/internal/audit"
	"bos/internal/bootstrap"
	"bos/internal/cgroup"
	"bos/internal/network"
	"bos/internal/security"
	"bos/internal/paths"

	"github.com/rs/zerolog/log"
)

// autoBootstrap — stub F1.3. Pasos 1-7.5 y 9 en internal/bootstrap.Setup().
// Paso 8 (cgroup delegation) migrado a internal/cgroup.
// Paso 8.5 (bridge) permanece aquí hasta F1.4.
// Paso 6.5 (RBAC) permanece aquí hasta F4.4.
func autoBootstrap(benv *bootstrapEnv) {
	cfg := bootstrap.Config{
		CGroupPath:   benv.CGroupPath,
		RootPassword: benv.RootPassword,
		TenantID:     benv.TenantID,
	}
	if err := bootstrap.Setup(cfg); err != nil {
		log.Fatal().Err(err).Msg("auto-bootstrap: setup falló")
	}

	// Paso 6.5 — RBAC (permanece hasta F4.4)
	if rbac, err := security.NewFileRBAC(paths.RBACRoles); err != nil {
		log.Warn().Err(err).Msg("auto-bootstrap: no se pudo inicializar RBAC")
	} else {
		bosRBAC = rbac
		log.Info().Msg("auto-bootstrap: RBAC inicializado")
	}

	audit.Log(paths.AuditLog, "BOOTSTRAP", "user=root", "action=auto_bootstrap_start")

	// Paso 8 — verificación y corrección de delegación de cgroup (internal/cgroup)
	cgPath := benv.CGroupPath
	if _, err := os.Stat(cgPath); err == nil {
		cgUID, cgGID := cgroup.DetectContainerMapping()
		if cgUID != 0 || cgGID != 0 {
			log.Info().Int("uid", cgUID).Int("gid", cgGID).Msg("auto-bootstrap: corrigiendo ownership de cgroup")
			os.Chown(cgPath, cgUID, cgGID)
		}

		if !cgroup.Probe(cgPath) {
			if cgroup.IsBareMetal() {
				log.Warn().Str("path", cgPath).Msg("auto-bootstrap: delegación de cgroup fallida — configurando systemd")
				if err := cgroup.ConfigureSystemdDelegate(paths.BosServiceName); err != nil {
					log.Error().Err(err).Msg("auto-bootstrap: no se pudo configurar Delegate=yes en systemd")
				}
				exec.Command("systemctl", "daemon-reload").Run()
				if !cgroup.Probe(cgPath) {
					log.Fatal().Str("path", cgPath).
						Msg("auto-bootstrap: delegación de cgroup SIGUE fallando tras Delegate=yes — reiniciar requerido")
				}
				log.Info().Msg("auto-bootstrap: delegación de cgroup verificada tras Delegate=yes")
				audit.Log(paths.AuditLog, "CGROUP", "path="+cgPath, "action=delegate_configured")
			} else {
				hostSetup := paths.HostSetup
				if _, err := os.Stat(hostSetup); err == nil {
					log.Info().Str("script", hostSetup).Msg("auto-bootstrap: ejecutando host-setup.sh para delegación de cgroup")
					cmd := exec.Command("bash", hostSetup)
					cmd.Stdout = os.Stderr
					cmd.Stderr = os.Stderr
					cmd.Run()
					exec.Command("systemctl", "daemon-reload").Run()
				}
				if cgroup.Probe(cgPath) {
					log.Info().Msg("auto-bootstrap: delegación de cgroup verificada")
				} else {
					log.Warn().Str("path", cgPath).
						Msg("auto-bootstrap: delegación de cgroup aún fallando — recrear contenedor con --cgroupns=host")
				}
			}
		} else {
			log.Info().Str("path", cgPath).Msg("auto-bootstrap: cgroup escribible (delegación verificada)")
		}
	}

	// Paso 8.5 — configuración de red bridge (F1.4)
	network.EnsureBridgeNetwork()
}
