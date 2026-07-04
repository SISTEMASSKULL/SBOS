// opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/cmd/bos/main.go
// bos — SBOS IAM Installer daemon
// PID 1 del plano de control soberano del SBOS.
// BOS es la capa OS: reemplaza sudo, actúa con privilegios root completos
// y es la única interfaz para operaciones privilegiadas del sistema.
//
// Modos de arranque:
//   - Normal: bos.toml + bos-install.toml presentes → operación completa + auto-bootstrap
//   - Config-pending (staged): bos-install.toml ausente → API read-only,
//     esperando que el operador envíe la config vía POST /api/install/config
//     o SIGHUP tras colocar bos-install.toml en disco.
//
// ADR-001: BOS corre como root y actúa como capa OS.
// Todas las operaciones privilegiadas se auditan en /var/log/bos/audit.log.
package main

import (
	"flag"
	"io"
	"os"
	"path/filepath"

	"bos/internal/boslog"
	"bos/internal/config"
	"bos/internal/security"
	"bos/internal/paths"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"log/slog"
)

var (
	configPath = flag.String("config", paths.BosToml, "path to bos.toml")
	version    = "0.1.0"
	bosRBAC    *security.FileRBAC // inicializado en autoBootstrap, usado por server y bosctl
)

// slogWriter escritor compartido para loggers slog de subsistemas.
// Se actualiza cuando se abre el archivo de log para capturar en archivo + stderr.
var slogWriter io.Writer = os.Stderr

// newSlogLogger crea un *slog.Logger para un subsistema.
// Usa slogWriter compartido para capturar en archivo de log cuando está disponible.
func newSlogLogger(subsystem string) *slog.Logger {
	return slog.New(slog.NewTextHandler(slogWriter, nil)).With("subsystem", subsystem, "component", "bos")
}

func main() {
	flag.Parse()
	boslog.Init("bos")

	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix

	// Fase 1: logging solo a stderr hasta que autoBootstrap cree /var/log/bos.
	log.Logger = zerolog.New(os.Stderr).With().Timestamp().Str("component", "bos").Logger()

	log.Info().Interface("version", version).Msg("bos daemon starting")

	// ADR-001: BOS debe correr como root — ES la capa OS.
	// BOS_DEV_SKIP_ROOT=1 permite correr sin root solo en entornos de desarrollo.
	devMode := os.Getenv("BOS_DEV_SKIP_ROOT") == "1"
	if os.Getuid() != 0 && !devMode {
		log.Error().Msg("BOS debe correr como root (ADR-001). Desarrollo: BOS_DEV_SKIP_ROOT=1")
		os.Exit(1)
	}

	benv := loadBootstrapEnv()

	if devMode {
		log.Warn().Msg("BOS_DEV_SKIP_ROOT=1 — modo desarrollo: autoBootstrap omitido")
		devRunPath := os.Getenv("BOS_DEV_RUN_PATH")
		if devRunPath == "" {
			devRunPath = paths.DevRunDir
		}
		os.MkdirAll(devRunPath, 0755)
		os.MkdirAll(paths.VarLogBos, 0755)
	} else {
		autoBootstrap(benv)
	}

	// Fase 2: agregar escritor a archivo. Crear directorio de log si falta.
	logPath := paths.VarLogBos
	os.MkdirAll(logPath, 0755)
	logFile, err := os.OpenFile(filepath.Join(logPath, "bos.log"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err == nil {
		multi := zerolog.MultiLevelWriter(os.Stderr, logFile)
		log.Logger = zerolog.New(multi).With().Timestamp().Str("component", "bos").Logger()
		slogWriter = multi
		log.Info().Str("path", filepath.Join(logPath, "bos.log")).Msg("log file opened")
	} else {
		log.Debug().Err(err).Str("path", filepath.Join(logPath, "bos.log")).Msg("cannot open log file — logging to stderr only")
	}

	cfg, err := config.Load(*configPath)
	if config.IsConfigPending(err) {
		log.Warn().Msg("bos-install.toml not found — entering config-pending mode (staged)")
		runConfigPending(cfg)
		return
	}
	if err != nil {
		log.Error().Err(err).Interface("path", *configPath).Msg("failed to load config")
		os.Exit(1)
	}

	// Si config especifica ruta de log distinta, reabre el archivo allí.
	if cfg.Install.LogPath != "" && cfg.Install.LogPath != logPath {
		newPath := filepath.Join(cfg.Install.LogPath, "bos.log")
		newFile, newErr := os.OpenFile(newPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if newErr == nil {
			multi := zerolog.MultiLevelWriter(os.Stderr, newFile)
			log.Logger = zerolog.New(multi).With().Timestamp().Str("component", "bos").Logger()
			slogWriter = multi
			logFile.Close()
			logFile = newFile
			log.Info().Interface("path", newPath).Msg("log file moved to config path")
		}
	}

	runNormal(cfg, benv)
}
