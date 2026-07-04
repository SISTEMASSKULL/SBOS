// config_pending.go — modo staged del daemon bos.
// Extraído de cmd/bos/main.go en F1.8 — SRP: main.go solo orquesta.
package main

import (
	"os"
	"os/signal"
	"syscall"

	"bos/internal/audit"
	"bos/internal/config"
	"bos/internal/server"
	"bos/internal/paths"

	"github.com/rs/zerolog/log"
)

// runConfigPending inicia el daemon en modo staged (config-pending).
// Expone solo la API mínima para recibir bos-install.toml.
// En SIGHUP reintenta cargar la config — si está completa, transiciona a runNormal.
func runConfigPending(cfg *config.Config) {
	install := cfg.Install

	const defaultHTTPPort = 9443
	if install.HTTPPort == 0 {
		install.HTTPPort = defaultHTTPPort
		log.Warn().Int("port", defaultHTTPPort).Msg("http_port no configurado — usando puerto por defecto")
	}

	log.Warn().
		Int("port", install.HTTPPort).
		Msg("bos daemon started in config-pending mode (staged)")
	log.Warn().Msg("Provide bos-install.toml via POST /api/install/config or place on disk + SIGHUP")

	audit.Log(paths.AuditLog, "STARTUP", "user=root", "mode=config-pending")

	apiServer := server.NewConfigPendingServer(
		server.Config{
			HTTPPort:   install.HTTPPort,
			UnixSocket: install.UnixSocket,
			Version:    version,
		},
		*configPath,
		newSlogLogger("api"),
	)

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM, syscall.SIGHUP)

	errCh := make(chan error, 1)
	go func() {
		errCh <- apiServer.ListenAndServe()
	}()

	for {
		select {
		case sig := <-sigCh:
			log.Info().Str("signal", sig.String()).Msg("received signal in config-pending mode")
			switch sig {
			case syscall.SIGHUP:
				newCfg, err := config.Load(*configPath)
				if config.IsConfigPending(err) {
					log.Warn().Msg("SIGHUP received but bos-install.toml still missing — staying in config-pending mode")
					continue
				}
				if err != nil {
					log.Error().Err(err).Msg("SIGHUP config reload failed — staying in config-pending mode")
					continue
				}
				log.Info().Msg("SIGHUP: bos-install.toml detected — transitioning to normal mode")
				apiServer.Shutdown()
				benv := loadBootstrapEnv()
				runNormal(newCfg, benv)
				return

			default:
				log.Info().Msg("shutting down config-pending daemon")
				apiServer.Shutdown()
				return
			}

		case err := <-errCh:
			if err != nil {
				log.Error().Err(err).Msg("config-pending api server fatal error")
				os.Exit(1)
			}
		}
	}
}
