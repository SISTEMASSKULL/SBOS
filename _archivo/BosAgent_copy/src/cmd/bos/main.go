// opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/cmd/bos/main.go
// bos — SBOS IAM Installer daemon
// PID 1 of the Sovereign Business Operating System control plane.
// BOS is the OS layer: it replaces sudo, acts with full root privileges,
// and is the sole interface for privileged system operations.
//
// Startup modes:
//   - Normal: bos.toml + bos-install.toml present → full operation + auto-bootstrap
//   - Config-pending (staged): bos-install.toml missing → API read-only,
//     waiting for operator to provide install config via POST /api/install/config
//     or SIGHUP after placing bos-install.toml on disk.
//
// ADR-001: BOS runs as root and acts as OS layer.
// All privileged operations are audited to /var/log/bos/audit.log.
package main

import (
	"flag"
	"fmt"
	"io"
	"math/rand"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"

	"bos/internal/config"
	"bos/internal/domain"
	"bos/internal/health"
	"bos/internal/installer"
	"bos/internal/k8s"
	"bos/internal/plugin"
	"bos/internal/reconcile"
	"bos/internal/release"
	"bos/internal/repair"
	"bos/internal/watchdog"
	"bos/internal/security"
	"bos/internal/server"
	"bos/internal/state"

	"github.com/joho/godotenv"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"log/slog"
)

var (
	configPath = flag.String("config", "/etc/bos/bos.toml", "path to bos.toml")
	version    = "0.1.0"
	bosRBAC    *security.FileRBAC // initialized in autoBootstrap, used by server and bosctl
)

// bootstrapEnv holds values loaded from bos-bootstrap.env.
type bootstrapEnv struct {
	RootUser     string
	RootPassword string
	TenantID     string
	TenantName   string
	TenantDomain string
	HostIP       string
	CGroupPath   string
}

// slogWriter is the shared io.Writer for subsystem slog loggers.
// Updated when the log file is opened so slog loggers write to both stderr and file.
var slogWriter io.Writer = os.Stderr

// newSlogLogger creates an *slog.Logger for a subsystem.
// Uses the shared slogWriter so log file output is captured when available.
func newSlogLogger(subsystem string) *slog.Logger {
	return slog.New(slog.NewTextHandler(slogWriter, nil)).With("subsystem", subsystem, "component", "bos")
}

func main() {
	flag.Parse()

	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix

	// Phase 1: stderr-only logging until autoBootstrap creates /var/log/bos.
	log.Logger = zerolog.New(os.Stderr).With().Timestamp().Str("component", "bos").Logger()

	log.Info().Interface("version", version).Msg("bos daemon starting")

	// ADR-001: BOS must run as root — it IS the OS layer.
	// BOS_DEV_SKIP_ROOT=1 permite correr sin root solo en entornos de desarrollo.
	devMode := os.Getenv("BOS_DEV_SKIP_ROOT") == "1"
	if os.Getuid() != 0 && !devMode {
		log.Error().Msg("BOS debe correr como root (ADR-001). Desarrollo: BOS_DEV_SKIP_ROOT=1")
		os.Exit(1)
	}

	// Load bootstrap env for auto-bootstrap parameters.
	benv := loadBootstrapEnv()

	// Execute auto-bootstrap: creates directories, self-deploys, cgroup setup.
	// En modo dev (BOS_DEV_SKIP_ROOT=1) se omite el autoBootstrap completo.
	if devMode {
		log.Warn().Msg("BOS_DEV_SKIP_ROOT=1 — modo desarrollo: autoBootstrap omitido")
		devRunPath := os.Getenv("BOS_DEV_RUN_PATH")
		if devRunPath == "" {
			devRunPath = "/tmp/bos-dev-run"
		}
		os.MkdirAll(devRunPath, 0755)
		os.MkdirAll("/var/log/bos", 0755)
	} else {
		autoBootstrap(benv)
	}

	// Phase 2: add file writer. Create log dir if missing (any mode).
	logPath := "/var/log/bos"
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

	// If config specifies a different log path, reopen there.
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

// loadBootstrapEnv reads bos-bootstrap.env from the first available location.
// Search order mirrors install.sh: /etc/bos/, /etc/bos/core/, /opt/bos/, /tmp/, ./
func loadBootstrapEnv() *bootstrapEnv {
	paths := []string{
		"/etc/bos/bos-bootstrap.env",
		"/etc/bos/core/bos-bootstrap.env",
		"/opt/bos/bos-bootstrap.env",
		"/opt/bos/core/bos-bootstrap.env",
		"/tmp/bos-bootstrap.env",
		"./bos-bootstrap.env",
	}

	var loaded string
	for _, p := range paths {
		if _, err := os.Stat(p); err == nil {
			if err := godotenv.Load(p); err == nil {
				loaded = p
				break
			}
		}
	}

	benv := &bootstrapEnv{
		RootUser:   os.Getenv("BOS_ROOT_USER"),
		TenantID:   os.Getenv("BOS_TENANT_ID"),
		TenantName: os.Getenv("BOS_TENANT_NAME"),
		TenantDomain: os.Getenv("BOS_TENANT_DOMAIN"),
		HostIP:     os.Getenv("BOS_HOST_IP"),
		CGroupPath: os.Getenv("BOS_CGROUP_PATH"),
	}

	// Read password once and clear from environment immediately (security).
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
		benv.CGroupPath = "/sys/fs/cgroup/k8s.io"
	}

	return benv
}

// autoBootstrap prepares the environment for BOS operation.
// ADR-001: BOS is the OS layer — it creates all directories, sets up cgroups,
// fixes permissions, and ensures the system is ready for K8s installation.
// Zero human intervention required beyond placing files in /tmp/ and executing BOS.
func autoBootstrap(benv *bootstrapEnv) {
	log.Info().Msg("auto-bootstrap: initializing environment")

	// 1. Create canonical directory structure.
	dirs := []string{
		"/opt/bos/bin",
		"/opt/bos/core",
		"/etc/bos/blibs/servers",
		"/etc/bos/.kube",
		"/var/log/bos",
		"/run/bos",
	}
	for _, d := range dirs {
		if err := os.MkdirAll(d, 0755); err != nil {
			log.Warn().Err(err).Interface("dir", d).Msg("auto-bootstrap: cannot create directory")
		}
	}

	// 2. Self-deploy: if running from /tmp/, copy to canonical location.
	ownPath, _ := os.Executable()
	canonicalBin := "/opt/bos/bin/bos"
	if ownPath != "" && ownPath != canonicalBin {
		log.Info().Interface("from", ownPath).Interface("to", canonicalBin).Msg("auto-bootstrap: self-deploying to canonical path")
		if data, err := os.ReadFile(ownPath); err == nil {
			if err := os.WriteFile(canonicalBin, data, 0755); err != nil {
				log.Warn().Err(err).Msg("auto-bootstrap: cannot self-deploy binary")
			}
		}
	}
	os.Chmod(canonicalBin, 0755)

	// 3. Deploy configs and core scripts from /tmp/ to canonical paths.
	// deployFile copies src→dst. If dst already exists, it's a no-op.
	// If src is missing, it warns — validation at step 5 catches missing critical files.
	deployFile := func(src, dst string, mode os.FileMode) {
		if _, err := os.Stat(dst); os.IsNotExist(err) {
			if _, err := os.Stat(src); err == nil {
				data, err := os.ReadFile(src)
				if err == nil {
					os.WriteFile(dst, data, mode)
					log.Info().Interface("src", src).Interface("dst", dst).Msg("auto-bootstrap: deployed")
				}
			} else {
				log.Warn().Interface("src", src).Interface("dst", dst).Msg("auto-bootstrap: source missing, cannot deploy")
			}
		}
	}

	// Config files
	deployFile("/tmp/bos.toml", "/etc/bos/bos.toml", 0644)
	deployFile("/tmp/bos-install.toml", "/etc/bos/bos-install.toml", 0644)
	deployFile("/tmp/bos-bootstrap.env", "/etc/bos/bos-bootstrap.env", 0600)

	// Core scripts — the orchestrator depends on ALL of these.
	coreScripts := []string{
		"00_MASTER_INSTALL_SBOS.sh",
		"00_TASK_CATALOG_SBOS.sh",
		"00_YAML_ENGINE_SBOS.sh",
		"00_CLEANUP_SBOS.sh",
		"host-setup.sh",
	}
	for _, s := range coreScripts {
		deployFile("/tmp/"+s, "/opt/bos/core/"+s, 0755)
	}

	// bosctl
	deployFile("/tmp/bosctl", "/opt/bos/bin/bosctl", 0755)

	// 4. Deploy servers/ (fichas) from /tmp/servers/ if canonical path empty.
	serversPath := "/etc/bos/blibs/servers"
	if entries, _ := os.ReadDir(serversPath); len(entries) == 0 {
		tmpServers := "/tmp/servers"
		if _, err := os.Stat(tmpServers); err == nil {
			copyDir(tmpServers, serversPath)
			log.Info().Interface("src", tmpServers).Interface("dst", serversPath).Msg("auto-bootstrap: deployed fichas")
		} else {
			log.Warn().Interface("src", tmpServers).Msg("auto-bootstrap: no fichas found in /tmp/servers/")
		}
	}

	// 5. Validate critical dependencies exist before proceeding.
	critical := []string{
		"/opt/bos/bin/bos",
		"/opt/bos/core/00_MASTER_INSTALL_SBOS.sh",
		"/opt/bos/core/00_TASK_CATALOG_SBOS.sh",
		"/opt/bos/core/00_YAML_ENGINE_SBOS.sh",
		"/opt/bos/core/host-setup.sh",
	}
	for _, p := range critical {
		if _, err := os.Stat(p); os.IsNotExist(err) {
			log.Error().Interface("path", p).Msg("auto-bootstrap: critical dependency missing — place it in /tmp/ and restart BOS")
			os.Exit(1)
		}
	}

	// Ensure core scripts are executable.
	for _, s := range coreScripts {
		p := "/opt/bos/core/" + s
		if _, err := os.Stat(p); err == nil {
			os.Chmod(p, 0755)
		}
	}
	if _, err := os.Stat("/opt/bos/bin/bosctl"); err == nil {
		os.Chmod("/opt/bos/bin/bosctl", 0755)
	}

	// 6. Write PID file.
	os.WriteFile("/run/bos/bos.pid", []byte(fmt.Sprintf("%d\n", os.Getpid())), 0644)

	// 6.5 Initialize RBAC (Fase A — D6 Security).
	// Creates /etc/bos/rbac/roles.json with admin/operator/readonly roles if missing.
	if rbac, err := security.NewFileRBAC("/etc/bos/rbac/roles.json"); err != nil {
		log.Warn().Err(err).Msg("auto-bootstrap: cannot initialize RBAC")
	} else {
		bosRBAC = rbac
		log.Info().Msg("auto-bootstrap: RBAC initialized")
	}

	auditLog("/var/log/bos/audit.log", "BOOTSTRAP", "user=root", "action=auto_bootstrap_start")

	// 7. Cgroup setup for K8s — mirrors install.sh §0 (Delegate=yes / cgroupns=host).
	// On bare metal: BOS writes directly to /sys/fs/cgroup/k8s.io.
	// In container WITHOUT cgroupns=host: the cgroup root is read-only even for root
	// because the user namespace maps UID 0 → host UID 1000. BOS works around this by
	// creating k8s.io inside the container's own writable cgroup subtree and bind-mounting
	// it to the canonical path. This gives runc/kubelet the same view they'd have with
	// cgroupns=host, without requiring the container to be recreated.
	cgPath := benv.CGroupPath
	// Create k8s.io cgroup directly. install.sh already configured root subtree_control
	// delegation (cpu memory pids), so children inherit those controllers natively.
	// Bind-mount from child subtrees (init.scope, user.slice) is avoided because their
	// cgroup.controllers snapshot predates delegation — they'd miss controllers like cpu.
	if _, err := os.Stat(cgPath); os.IsNotExist(err) {
		log.Info().Interface("path", cgPath).Msg("auto-bootstrap: creating cgroup k8s.io")
		if err := os.MkdirAll(cgPath, 0755); err != nil {
			log.Error().Err(err).Interface("path", cgPath).Msg("auto-bootstrap: cannot create cgroup directory")
		} else {
			auditLog("/var/log/bos/audit.log", "CGROUP", "path="+cgPath, "action=created")
			if controllers, err := os.ReadFile(filepath.Join(cgPath, "cgroup.controllers")); err == nil {
				for _, ctrl := range strings.Fields(string(controllers)) {
					_ = os.WriteFile(filepath.Join(cgPath, "cgroup.subtree_control"), []byte("+"+ctrl), 0)
				}
			}
		}
	}

	// 7.5. Configure root password from bootstrap env — mirrors install.sh:
	//   echo 'root:$ROOT_PASS' | chpasswd
	// BOS is the OS layer (ADR-001). It inherits root credentials from the
	// environment and ensures the system root account is properly set.
	if benv.RootPassword != "" {
		cmd := exec.Command("chpasswd")
		cmd.Stdin = strings.NewReader(fmt.Sprintf("root:%s", benv.RootPassword))
		if err := cmd.Run(); err != nil {
			log.Warn().Err(err).Msg("auto-bootstrap: cannot set root password via chpasswd")
		} else {
			log.Info().Msg("auto-bootstrap: root password configured from bootstrap env")
			auditLog("/var/log/bos/audit.log", "CREDENTIALS", "action=root_password_set", "source=bos-bootstrap.env")
		}
	}

	// 8. Cgroup delegation verification — mirrors install.sh host Delegate=yes check.
	if _, err := os.Stat(cgPath); err == nil {
		cgUID, cgGID := detectContainerMapping()
		if cgUID != 0 || cgGID != 0 {
			log.Info().Interface("uid", cgUID).Interface("gid", cgGID).Msg("auto-bootstrap: correcting cgroup ownership")
			os.Chown(cgPath, cgUID, cgGID)
		}

		if !verifyCgroupDelegation(cgPath) {
			if isBareMetal() {
				log.Warn().Interface("path", cgPath).Msg("auto-bootstrap: cgroup delegation failed — configuring systemd")
				if err := configureSystemdDelegate("bos.service"); err != nil {
					log.Error().Err(err).Msg("auto-bootstrap: cannot configure systemd Delegate=yes")
				}
				exec.Command("systemctl", "daemon-reload").Run()
				if !verifyCgroupDelegation(cgPath) {
					log.Fatal().Str("path", cgPath).
						Msg("auto-bootstrap: cgroup delegation STILL failing after Delegate=yes — reboot required")
				}
				log.Info().Msg("auto-bootstrap: cgroup delegation verified after Delegate=yes")
				auditLog("/var/log/bos/audit.log", "CGROUP", "path="+cgPath, "action=delegate_configured")
			} else {
				// Container: delegation still failing even with bind-mount.
				// Fall back to host-setup.sh and clear instructions.
				hostSetup := "/opt/bos/core/host-setup.sh"
				if _, err := os.Stat(hostSetup); err == nil {
					log.Info().Interface("script", hostSetup).Msg("auto-bootstrap: executing host-setup.sh for cgroup delegation")
					cmd := exec.Command("bash", hostSetup)
					cmd.Stdout = os.Stderr
					cmd.Stderr = os.Stderr
					cmd.Run()
					exec.Command("systemctl", "daemon-reload").Run()
				}
				if verifyCgroupDelegation(cgPath) {
					log.Info().Msg("auto-bootstrap: cgroup delegation verified")
				} else {
					log.Warn().Str("path", cgPath).
						Msg("auto-bootstrap: cgroup delegation still failing — " +
							"recreate container with --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:rw " +
							"or ensure host podman has Delegate=yes")
				}
			}
		} else {
			log.Info().Interface("path", cgPath).Msg("auto-bootstrap: cgroup writable (delegation verified)")
		}
	}

	// 8.5. Network setup — mirrors install.sh §0.2 (nftables FORWARD for bridge).
	// On bare metal, BOS ensures K8s pod traffic can traverse the bridge.
	// In a container, this needs NET_ADMIN (included in --privileged).
	ensureBridgeNetwork()

	// 9. Log system info.
	hostname, _ := os.Hostname()
	auditLog("/var/log/bos/audit.log", "BOOTSTRAP",
		"user=root",
		"hostname="+hostname,
		"uid="+strconv.Itoa(os.Getuid()),
		"action=auto_bootstrap_complete")

	log.Info().Msg("auto-bootstrap: environment ready")
}

// copyDir recursively copies a directory tree.
func copyDir(src, dst string) error {
	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, path)
		target := filepath.Join(dst, rel)
		if info.IsDir() {
			return os.MkdirAll(target, 0755)
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		return os.WriteFile(target, data, info.Mode())
	})
}

// detectContainerMapping reads /proc/self/uid_map and /proc/self/gid_map
// to determine the correct ownership for cgroup directories in nested containers.
func detectContainerMapping() (uid, gid int) {
	uid = 0
	gid = 0

	if data, err := os.ReadFile("/proc/self/uid_map"); err == nil {
		fields := strings.Fields(string(data))
		if len(fields) >= 2 {
			if v, err := strconv.Atoi(fields[1]); err == nil {
				uid = v
			}
		}
	}

	if data, err := os.ReadFile("/proc/self/gid_map"); err == nil {
		fields := strings.Fields(string(data))
		if len(fields) >= 2 {
			if v, err := strconv.Atoi(fields[1]); err == nil {
				gid = v
			}
		}
	}

	return
}

// auditLog appends a structured entry to the audit log.
// Format: [ISO-8601] CATEGORY key=value key=value ...
// The password is NEVER logged.
func auditLog(path string, category string, kvs ...string) {
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	defer f.Close()

	ts := time.Now().UTC().Format("2006-01-02 15:04:05")
	line := fmt.Sprintf("[%s] %s %s\n", ts, category, strings.Join(kvs, " "))
	f.WriteString(line)
}

// ── Normal Operation ────────────────────────────────────────────────

// runNormal starts all subsystems and enters the main event loop.
func runNormal(cfg *config.Config, benv *bootstrapEnv) {
	install := cfg.Install

	log.Info().
		Str("channel", install.Channel).
		Int("port", install.HTTPPort).
		Str("org", install.OrgName).
		Str("tenant", benv.TenantID).
		Msg("config loaded — normal startup")

	auditLog("/var/log/bos/audit.log", "STARTUP",
		"user=root",
		"tenant="+benv.TenantID,
		"channel="+install.Channel)

	// 1. Initialize STATE_MANAGER
	stateMgr, err := state.NewManager(install.StateFile)
	if err != nil {
		log.Error().Err(err).Interface("path", install.StateFile).Msg("failed to init state manager")
		os.Exit(1)
	}
	defer stateMgr.Close()
	switch stateMgr.Recovery {
	case state.RecoveryBackup:
		log.Warn().Interface("path", install.StateFile).Msg("state file loaded from backup — primary was corrupt")
	case state.RecoveryRebuilt:
		log.Warn().Interface("path", install.StateFile).Msg("state file rebuilt from empty — both primary and backup were lost")
	}
	log.Info().Interface("path", install.StateFile).Msg("state manager initialized")

	// 2. Initialize plugin loader
	pluginLoader := plugin.NewLoader(install.ServersPath, newSlogLogger("plugin"))
	fichas, err := pluginLoader.Scan()
	if err != nil {
		log.Warn().Err(err).Msg("plugin scan had errors")
	}
	log.Info().Int("count", len(fichas)).Msg("plugins loaded")


	auditLog("/var/log/bos/audit.log", "PLUGINS",
		"count="+strconv.Itoa(len(fichas)),
		"path="+install.ServersPath)

	// 3. Initialize K8s core
	k8sCore := k8s.NewCore(install.KubeconfigPath, cfg.SagaTimeout("install"))
	log.Info().Interface("kubeconfig", install.KubeconfigPath).Msg("k8s core initialized")

	// 3b. PG Auxiliar Anti-Pérdida (Parte V-B)
	pgAuxSvc := domain.NewPgAuxiliarService(k8sCore)
	log.Info().Msg("pg_auxiliar service initialized")

	// 4. Initialize release manager
	releaseMgr := release.NewManager(install.ReleaseServerURL, install.Channel,
		newSlogLogger("release"))
	log.Info().Interface("server", install.ReleaseServerURL).Interface("channel", install.Channel).Msg("release manager initialized")

	// 4b. Adapter: release.Manager → server.ReleaseInfo
	releaseAdapter := &releaseAdapter{mgr: releaseMgr}

	// 5. Initialize saga orchestrator + compensator
	masterScript := filepath.Join(install.CorePath, "00_MASTER_INSTALL_SBOS.sh")
	orchestrator := installer.NewOrchestrator(masterScript, install.CorePath,
		cfg.SagaTimeout("install"),
		newSlogLogger("installer"))
	compensator := installer.NewCompensator(masterScript,
		newSlogLogger("compensator"))

	// Wire compensator into orchestrator
	orchestrator.SetCompensator(compensator)
	log.Info().Interface("core_dir", install.CorePath).Msg("installer ready")

	// 5.5 Initialize ficha states from manifest declarations, then start
	// the observer loop: watches state changes and reacts (install, repair, update).
	initializeFichaStates(pluginLoader, stateMgr)
	go runObserverLoop(orchestrator, pluginLoader, stateMgr)

	// 6. Initialize health checker
	healthInterval := cfg.HealthCheckInterval()
	healthChecker := health.NewChecker(stateMgr, healthInterval, install.ServersPath,
		newSlogLogger("health"))

	// 7. Initialize reconcile scheduler
	reconcileInterval := cfg.ReconcileInterval()
	reconcileScheduler := reconcile.NewScheduler(stateMgr, orchestrator, reconcileInterval,
		install.ServersPath, cfg.DriftCheck,
		newSlogLogger("reconcile"))

	// 7.4 Initialize repair manager (for watchdog auto-repair, disabled by default)
	repairMgr := repair.NewRepairManager(stateMgr, nil,
		cfg.SagaTimeout("repair"), false, newSlogLogger("repair"))

	// 7.45 Initialize unified watchdog (Ubuntu + K8s + BOS, 30s cycle)
	watchdogInterval := cfg.WatchdogInterval()
	unifiedWatchdog := watchdog.NewUnifiedWatchdog(
		stateMgr,
		watchdogInterval,
		cfg.WatchdogDiskThresholdPct,
		cfg.WatchdogMemoryThresholdPct,
		cfg.WatchdogK8sNodeCheck,
		cfg.WatchdogK8sPodCheck,
		cfg.WatchdogBOSFichaCheck,
		cfg.WatchdogAutoRepair,
		repairMgr,
		newSlogLogger("watchdog"),
	)

	// 7.5 Wire RBAC: BauthRBAC bridge if configured, else FileRBAC.
	identityProvider := security.IdentityProvider(bosRBAC)
	rbacProvider := security.RBACProvider(bosRBAC)
	if cfg.BauthEnabled && cfg.BauthSocket != "" {
		bauthCfg := security.BauthRBACConfig{
			Enabled:    true,
			SocketPath: cfg.BauthSocket,
			Timeout:    time.Duration(cfg.BauthTimeoutMs) * time.Millisecond,
			Fallback:   bosRBAC,
		}
		bauthBridge := security.NewBauthRBAC(bauthCfg)
		rbacProvider = bauthBridge
		identityProvider = bauthBridge
		log.Info().Interface("socket", cfg.BauthSocket).Msg("bauth bridge enabled — RBAC delegated to BauthAgent")
	}

	// 8. Initialize API server
	apiServer := server.NewServer(
		server.Config{
			HTTPPort:   install.HTTPPort,
			UnixSocket: install.UnixSocket,
		},
		stateMgr,
		pluginLoader,
		healthChecker,
		orchestrator,
		rbacProvider,
		identityProvider,
		newSlogLogger("api"),
		pgAuxSvc,
	)
	apiServer.SetReleaseManager(releaseAdapter)

	// 8.5 Wire observers: log crudo + pasos del saga → WebSocket → TUI
	orchestrator.SetLogObserver(func(fichaID, line string) {
		apiServer.BroadcastFichaLog(fichaID, line)
	})
	orchestrator.SetObserver(func(step installer.Step) {
		switch step.Status {
		case "running":
			apiServer.BroadcastStepEvent(server.EventStepStart, step.FichaID, step.Name, "")
		case "ok":
			apiServer.BroadcastStepEvent(server.EventStepOK, step.FichaID, step.Name, "")
		case "fail":
			apiServer.BroadcastStepEvent(server.EventStepFail, step.FichaID, step.Name, step.Error)
		}
	})

	// 9. Signal handling
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM, syscall.SIGHUP)

	// 10. Start subsystems
	go healthChecker.Run()
	go reconcileScheduler.Run()

	errCh := make(chan error, 1)
	go func() {
		errCh <- apiServer.ListenAndServe()
	}()

	log.Info().Msg("bos daemon running — all subsystems started")
	auditLog("/var/log/bos/audit.log", "RUNNING", "user=root", "state=all_subsystems_started")

	// 10.5 Startup reconciliation: verify K8s state before entering event loop.
	// If K8s was running before BOS stopped (or crashed), restore it immediately
	// instead of waiting for the periodic reconcile ticker (up to 300s).
	startupReconcile(stateMgr, orchestrator, healthChecker)

	// Notify systemd that BOS is ready for operation.
	sdNotify("READY=1\nSTATUS=BOS daemon running — K8s state verified")

	// 10.6 Start watchdog goroutine (WATCHDOG=1 at half interval)
	go unifiedWatchdog.Run()

	// 11. Main event loop
	for {
		select {
		case sig := <-sigCh:
			log.Info().Str("signal", sig.String()).Msg("received signal")
			switch sig {
			case syscall.SIGHUP:
				pluginLoader.Reload()
				releaseMgr.InvalidateCache()
				log.Info().Msg("config reloaded (SIGHUP)")
			default:
				log.Info().Msg("shutting down gracefully")
				auditLog("/var/log/bos/audit.log", "SHUTDOWN", "user=root", "signal="+sig.String())
				shutdown(apiServer, healthChecker, reconcileScheduler, orchestrator, unifiedWatchdog)
				return
			}

		case err := <-errCh:
			if err != nil {
				log.Error().Err(err).Msg("api server fatal error")
				os.Exit(1)
			}

		case <-apiServer.ShutdownCh:
			log.Info().Msg("shutdown requested via API")
			auditLog("/var/log/bos/audit.log", "SHUTDOWN", "user=root", "signal=api_request")
			shutdown(apiServer, healthChecker, reconcileScheduler, orchestrator, unifiedWatchdog)
			return

		case <-time.After(10 * time.Second):
			pluginCount := pluginLoader.Count()
			if pluginCount > 0 {
				log.Debug().Interface("fichas", pluginCount).Msg("heartbeat")
			}
		}
	}
}

// ── OS Layer: Privileged Command Execution ──────────────────────────

// ExecAsRoot runs a command with full root privileges.
// BOS is the OS layer (ADR-001) — it replaces sudo.
// All executions are audited.
func ExecAsRoot(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("exec: no command provided")
	}

	auditLog("/var/log/bos/audit.log", "EXEC",
		"user=root",
		"cmd="+strings.Join(args, " "))

	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

// SystemctlCmd executes a systemctl command via BOS (replaces sudo systemctl).
func SystemctlCmd(action, service string) error {
	auditLog("/var/log/bos/audit.log", "SYSCMD",
		"user=root",
		"action=systemctl "+action+" "+service)

	cmd := exec.Command("systemctl", action, service)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// ── Systemd sd_notify ─────────────────────────────────────────────

// sdNotify sends a state string to the systemd notify socket.
// No-op when NOTIFY_SOCKET is unset (running outside systemd).
// Supports abstract sockets (@socket prefix).
func sdNotify(state string) {
	socketPath := os.Getenv("NOTIFY_SOCKET")
	if socketPath == "" {
		return
	}
	if strings.HasPrefix(socketPath, "@") {
		socketPath = "\x00" + socketPath[1:]
	}
	addr := &net.UnixAddr{Name: socketPath, Net: "unixgram"}
	conn, err := net.DialUnix("unixgram", nil, addr)
	if err != nil {
		log.Warn().Err(err).Msg("sd_notify: failed to connect")
		return
	}
	defer conn.Close()
	if _, err := conn.Write([]byte(state)); err != nil {
		log.Warn().Err(err).Msg("sd_notify: failed to write")
	}
}

// ── Ficha State Initialization & Observer Loop ─────────────────────
//
// BOS is a reactive observer daemon (SBOS-018 §10). It watches ficha states
// in .sbos_state.json and reacts to each state transition:
//
//   NO_INSTALADA + auto_install + deps OK  →  INSTALANDO → install saga
//   INSTALADA -- ALERTA                    →  REPARANDO  → repair saga
//   ACTUALIZACION DISPONIBLE               →  ACTUALIZANDO → update saga
//   BLOQUEADA                              →  wait for deps, then unblock
//
// Only fichas with auto_install: true (bootstrap product) are installed
// automatically. The rest require explicit admin action via bosctl or Core UI.

// initializeFichaStates registers all discovered fichas in STATE_MANAGER
// with initial states derived from their manifest.yml.
func initializeFichaStates(loader *plugin.Loader, stateMgr *state.Manager) {
	fichas := loader.List()
	if len(fichas) == 0 {
		return
	}

	for _, f := range fichas {
		// Default: BLOQUEADA. Only auto_install (bootstrap) fichas
		// start as NO_INSTALADA. Type 3 optional fichas always start
		// BLOQUEADA — admin must activate via Core UI.
		initialState := state.StatePendiente

		if f.AutoInstall {
			if len(f.Dependencies) > 0 {
				initialState = state.StatePendiente
			} else {
				initialState = state.StateLista
			}
		}

		if err := stateMgr.Register(f.ID, initialState, f.Version, f.Criticality, f.Server, f.Category, f.Backend); err != nil {
			log.Warn().Err(err).Interface("ficha", f.ID).Msg("state registration failed")
		} else {
			log.Debug().Str("ficha", f.ID).Str("state", string(initialState)).Msg("state initialized")
		}
	}

	log.Info().Int("count", len(fichas)).Msg("ficha states initialized")
}

// startupReconcile checks whether K8s was running before BOS stopped and,
// if so, triggers immediate reconciliation to avoid the 300s ticker window.
// Applies random jitter (0-30s) when K8s is already UP to prevent thundering
// herd if multiple BOS nodes boot simultaneously after a power outage.
func startupReconcile(stateMgr *state.Manager, orchestrator *installer.Orchestrator, healthChecker *health.Checker) {
	st, err := stateMgr.Read()
	if err != nil {
		log.Warn().Err(err).Msg("startup reconcile: cannot read state — skipping")
		return
	}

	// Check if K8s bootstrap ficha was previously installed
	k8sFicha, ok := st.Fichas["sbos-bootstrap-k8s"]
	if !ok || (k8sFicha.State != state.StateInstalada && k8sFicha.State != state.StateDegradada) {
		log.Info().Msg("startup reconcile: K8s not previously installed — observer loop will handle")
		return
	}

	kubeletActive := SystemctlCmd("is-active", "kubelet") == nil

	if !kubeletActive {
		log.Warn().Msg("startup reconcile: kubelet NOT active — triggering immediate repair")
	} else {
		// K8s is up. Apply jitter to avoid thundering herd.
		jitter := time.Duration(rand.Intn(30)) * time.Second
		log.Info().Interface("jitter", jitter).Msg("startup reconcile: K8s was running — applying jitter before reconcile")
		time.Sleep(jitter)
	}

	log.Info().Msg("startup reconcile: running initial health check")
	healthChecker.CheckNow()
	log.Info().Msg("startup reconcile: complete")
}

// startWatchdog sends WATCHDOG=1 to systemd at half the WatchdogSec interval.
// No-op when running outside systemd (WATCHDOG_USEC not set).
func startWatchdog(stopCh <-chan struct{}) {
	usecStr := os.Getenv("WATCHDOG_USEC")
	if usecStr == "" {
		return
	}
	usec, err := strconv.ParseInt(usecStr, 10, 64)
	if err != nil || usec <= 0 {
		return
	}
	interval := time.Duration(usec/2) * time.Microsecond
	log.Info().Interface("interval", interval).Msg("watchdog enabled — systemd supervision active")

	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-stopCh:
			return
		case <-ticker.C:
			sdNotify("WATCHDOG=1")
		}
	}
}

// runObserverLoop continuously observes ficha states and reacts.
// It runs as a goroutine so the API server starts immediately.
func runObserverLoop(orchestrator *installer.Orchestrator, loader *plugin.Loader, stateMgr *state.Manager) {
	// Build a lookup index for quick manifest access
	fichaIndex := make(map[string]*plugin.FichaManifest)
	rebuildIndex := func() {
		for _, f := range loader.List() {
			fichaIndex[f.ID] = f
		}
	}
	rebuildIndex()

	log.Info().Int("count", len(fichaIndex)).Msg("observer: watching ficha states")

	// Observer tick: every 5 seconds, scan for actionable states
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		// Reload index periodically (new fichas may appear on disk)
		if len(fichaIndex) != loader.Count() {
			rebuildIndex()
		}

		st, err := stateMgr.Read()
		if err != nil {
			log.Warn().Err(err).Msg("observer: cannot read state")
			continue
		}

		// Phase 1: Unblock fichas whose dependencies are now satisfied
		for name, ficha := range st.Fichas {
			if ficha.State != state.StatePendiente {
				continue
			}

			mf, ok := fichaIndex[name]
			if !ok || !mf.AutoInstall {
				continue
			}

			if depsSatisfied(mf.Dependencies, st) {
				if err := stateMgr.Unblock(name); err != nil {
					log.Warn().Err(err).Interface("ficha", name).Msg("observer: unblock failed")
				} else {
					log.Info().Interface("ficha", name).Msg("observer: unblocked (dependencies satisfied)")
				}
			}
		}

		// Phase 2: Find next NO_INSTALADA ficha eligible for auto-install.
		// Only install ONE ficha at a time (sequential, deterministic).
		// Use topological ordering to respect dependencies.
		next := findNextAutoInstall(st, fichaIndex)
		if next != nil {
			log.Info().Interface("ficha", next.ID).Interface("version", next.Version).Msg("observer: auto-install triggering")
			auditLog("/var/log/bos/audit.log", "OBSERVER_INSTALL",
				"user=root",
				"ficha="+next.ID,
				"version="+next.Version)

			// Transition: LISTA → INSTALANDO (ADR-021 #2→#3)
			if err := stateMgr.Transition(next.ID, state.StateInstalando); err != nil {
				log.Warn().Err(err).Interface("ficha", next.ID).Msg("observer: transition to INSTALANDO failed")
				continue
			}

			result, err := orchestrator.Install(next.ID, next.Version)
			if err != nil || !result.Success {
				log.Error().Err(err).Interface("ficha", next.ID).Interface("exit", result.ExitCode).Msg("observer: install failed")
				// Transition: INSTALANDO → FALLA_INSTALACION (ADR-021 #3→#13)
				_ = stateMgr.Transition(next.ID, state.StateFallaInstalacion)
				continue
			}

			// Transition: INSTALANDO → INSTALADA (ADR-021 #3→#4)
			if err := stateMgr.Transition(next.ID, state.StateInstalada); err != nil {
				log.Warn().Err(err).Interface("ficha", next.ID).Msg("observer: transition to INSTALADA failed")
			}

			log.Info().Interface("ficha", next.ID).Dur("duration", result.Duration).Msg("observer: installed successfully")
			auditLog("/var/log/bos/audit.log", "OBSERVER_INSTALL_OK",
				"user=root",
				"ficha="+next.ID)

			// Register hashes for drift detection
			if err := stateMgr.RegisterHashes(next.ID, next.Hashes()); err != nil {
				log.Warn().Err(err).Interface("ficha", next.ID).Msg("observer: hash registration failed")
			}
			continue
		}

		// Phase 3: Reaccionar a DEGRADADA/REPARANDO → auto-repair (solo fichas auto_install)
		for name, ficha := range st.Fichas {
			if ficha.State == state.StateDegradada || ficha.State == state.StateReparando {
				mf, ok := fichaIndex[name]
				if !ok || !mf.AutoInstall {
					continue
				}

				log.Info().Interface("ficha", name).Msg("observer: auto-repair triggering")
				// Transición a REPARANDO solo si aún no está en ese estado
				if ficha.State != state.StateReparando {
					if err := stateMgr.Transition(name, state.StateReparando); err != nil {
						log.Warn().Err(err).Interface("ficha", name).Msg("observer: transition to REPARANDO failed")
						continue
					}
				}

				result, err := orchestrator.Repair(name)
				if err != nil || !result.Success {
					// Repair fallido → volver a DEGRADADA para reintentar en siguiente tick
					log.Error().Err(err).Interface("ficha", name).Msg("observer: repair failed — reverting to DEGRADADA")
					_ = stateMgr.Transition(name, state.StateDegradada)
					continue
				}

				// REPARANDO → INSTALADA (ADR-021 #11→#4)
				_ = stateMgr.Transition(name, state.StateInstalada)
				log.Info().Interface("ficha", name).Msg("observer: repair successful")
			}
		}
	}
}

// findNextAutoInstall returns the next ficha eligible for auto-install.
// Uses topological ordering: picks the lowest execution_order among
// NO_INSTALADA + auto_install fichas whose dependencies are all INSTALADA_OK.
// Returns nil if no ficha is ready to install.
func findNextAutoInstall(st *state.SBOSState, index map[string]*plugin.FichaManifest) *plugin.FichaManifest {
	var candidates []*plugin.FichaManifest

	for _, mf := range index {
		// Only auto_install fichas
		if !mf.AutoInstall {
			continue
		}

		ficha, ok := st.Fichas[mf.ID]
		if !ok {
			// Not yet registered — skip; initializeFichaStates handles registration
			continue
		}

		// Solo procesar fichas LISTA (deps OK, esperando slot en DAG)
		if ficha.State != state.StateLista {
			continue
		}

		// Verify all dependencies are satisfied
		if !depsSatisfied(mf.Dependencies, st) {
			continue
		}

		candidates = append(candidates, mf)
	}

	if len(candidates) == 0 {
		return nil
	}

	// Sort by execution_order (Kahn precedence)
	sort.Slice(candidates, func(i, j int) bool {
		return candidates[i].ExecutionOrder < candidates[j].ExecutionOrder
	})

	return candidates[0]
}

// depsSatisfied returns true if all dependencies are in INSTALADA state (ADR-021 #4).
func depsSatisfied(deps []string, st *state.SBOSState) bool {
	for _, dep := range deps {
		ficha, ok := st.Fichas[dep]
		if !ok {
			return false // dependency not even registered
		}
		if ficha.State != state.StateInstalada {
			return false
		}
	}
	return true
}

// topologicalSort orders fichas so that dependencies come before dependents.
// Uses Kahn's algorithm for deterministic ordering.
func topologicalSort(fichas []*plugin.FichaManifest) []*plugin.FichaManifest {
	byID := make(map[string]*plugin.FichaManifest, len(fichas))
	inDegree := make(map[string]int, len(fichas))
	for _, f := range fichas {
		byID[f.ID] = f
		if _, ok := inDegree[f.ID]; !ok {
			inDegree[f.ID] = 0
		}
	}

	for _, f := range fichas {
		for _, dep := range f.Dependencies {
			if _, ok := byID[dep]; ok {
				inDegree[f.ID]++
			}
		}
	}

	// Sort by ExecutionOrder helper
	sortByOrder := func(slice []*plugin.FichaManifest) {
		sort.Slice(slice, func(i, j int) bool {
			return slice[i].ExecutionOrder < slice[j].ExecutionOrder
		})
	}

	var result []*plugin.FichaManifest

	// Initial queue: nodes with no dependencies, sorted by ExecutionOrder.
	var queue []*plugin.FichaManifest
	for _, f := range fichas {
		if inDegree[f.ID] == 0 {
			queue = append(queue, f)
		}
	}
	sortByOrder(queue)

	for len(queue) > 0 {
		// Re-sort queue since newly added nodes may have lower execution_order
		sortByOrder(queue)
		f := queue[0]
		queue = queue[1:]
		result = append(result, f)

		for _, other := range fichas {
			for _, dep := range other.Dependencies {
				if dep == f.ID {
					inDegree[other.ID]--
					if inDegree[other.ID] == 0 {
						queue = append(queue, other)
					}
				}
			}
		}
	}

	// Append any remaining (circular deps or unresolved) sorted by order.
	var remaining []*plugin.FichaManifest
	for _, f := range fichas {
		seen := false
		for _, r := range result {
			if r.ID == f.ID {
				seen = true
				break
			}
		}
		if !seen {
			remaining = append(remaining, f)
		}
	}
	sortByOrder(remaining)
	result = append(result, remaining...)

	return result
}

// ── Config-Pending Mode ─────────────────────────────────────────────

// runConfigPending starts the daemon in staged mode.
func runConfigPending(cfg *config.Config) {
	install := cfg.Install

	if install.HTTPPort == 0 {
		install.HTTPPort = 9443
	}

	log.Warn().
		Int("port", install.HTTPPort).
		Msg("bos daemon started in config-pending mode (staged)")
	log.Warn().Msg("Provide bos-install.toml via POST /api/install/config or place on disk + SIGHUP")

	auditLog("/var/log/bos/audit.log", "STARTUP", "user=root", "mode=config-pending")

	apiServer := server.NewConfigPendingServer(
		server.Config{
			HTTPPort:   install.HTTPPort,
			UnixSocket: install.UnixSocket,
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

func shutdown(apiServer *server.Server, healthChecker *health.Checker, reconcileScheduler *reconcile.Scheduler, orchestrator *installer.Orchestrator, wd *watchdog.UnifiedWatchdog) {
	// 1. Signal systemd that we are stopping
	sdNotify("STOPPING=1")

	// 2. Execute graceful K8s shutdown (best-effort with per-phase timeouts)
	nodeName, _ := os.Hostname()
	phases := orchestrator.Shutdown(nodeName)
	auditLog("/var/log/bos/audit.log", "SHUTDOWN",
		"user=root",
		"phases="+strconv.Itoa(len(phases)),
		"action=saga_shutdown_complete")

	// 3. Stop internal subsystems
	wd.Stop()
	apiServer.Shutdown()
	healthChecker.Stop()
	reconcileScheduler.Stop()

	// 4. Final audit log
	auditLog("/var/log/bos/audit.log", "SHUTDOWN", "user=root", "state=stopped")
	log.Info().Msg("bos daemon stopped — all subsystems shut down")
}

// verifyCgroupDelegation tests whether runc can create child cgroups under
// cgPath by creating a test child cgroup and writing to its cgroup.procs.
// A plain mkdir is not sufficient — this requires Delegate=yes on the
// parent systemd unit (host podman service or bos.service on bare metal).
func verifyCgroupDelegation(cgPath string) bool {
	testChild := filepath.Join(cgPath, ".bos-delegate-probe-"+strconv.Itoa(os.Getpid()))
	if err := os.Mkdir(testChild, 0755); err != nil {
		return false
	}
	procsFile := filepath.Join(testChild, "cgroup.procs")
	f, err := os.OpenFile(procsFile, os.O_WRONLY, 0)
	if err != nil {
		os.Remove(testChild)
		return false
	}
	_, err = fmt.Fprintf(f, "%d", os.Getpid())
	f.Close()
	os.Remove(testChild)
	return err == nil
}

// isBareMetal returns true if the process is NOT running inside a container.
func isBareMetal() bool {
	if _, err := os.Stat("/.containerenv"); err == nil {
		return false
	}
	if _, err := os.Stat("/run/.containerenv"); err == nil {
		return false
	}
	data, err := os.ReadFile("/proc/self/cgroup")
	if err == nil {
		cgroup := string(data)
		if strings.Contains(cgroup, "/docker/") || strings.Contains(cgroup, "/libpod-") ||
			strings.Contains(cgroup, "/kubepods") || strings.Contains(cgroup, "0::/") {
			return false
		}
	}
	return true
}

// configureSystemdDelegate creates a drop-in for the given systemd service
// with Delegate=yes, enabling cgroup subtree delegation for kubelet/runc.
func configureSystemdDelegate(serviceName string) error {
	dir := "/etc/systemd/system/" + serviceName + ".d"
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	conf := filepath.Join(dir, "delegate.conf")
	return os.WriteFile(conf, []byte("[Service]\nDelegate=yes\n"), 0644)
}

// ── Network Setup (install.sh §0.1–0.2) ─────────────────────────────

// detectNetworkSubnet returns the primary IPv4 subnet (CIDR) for this host/container.
// Used to configure nftables FORWARD rules so K8s pod traffic can egress the bridge.
func detectNetworkSubnet() string {
	ifaces, _ := net.Interfaces()
	for _, iface := range ifaces {
		if iface.Flags&net.FlagLoopback != 0 {
			continue
		}
		if iface.Flags&net.FlagUp == 0 {
			continue
		}
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, addr := range addrs {
			ipnet, ok := addr.(*net.IPNet)
			if !ok || ipnet.IP.To4() == nil {
				continue
			}
			// Return first non-loopback IPv4 subnet found.
			return ipnet.String()
		}
	}
	return ""
}

// ensureNftablesForwardRule inserts an nftables FORWARD rule for the given subnet.
// Mirrors install.sh step 0.2: ensures K8s pod traffic can traverse the bridge.
func ensureNftablesForwardRule(subnet string) {
	if subnet == "" {
		return
	}
	// Check if nft is available.
	if _, err := exec.LookPath("nft"); err != nil {
		log.Debug().Msg("auto-bootstrap: nft not found — skipping FORWARD rule (K8s pod egress may be limited)")
		return
	}
	// Check if rule already exists.
	checkCmd := exec.Command("nft", "list", "chain", "ip", "filter", "FORWARD")
	output, err := checkCmd.Output()
	if err != nil {
		log.Debug().Err(err).Msg("auto-bootstrap: cannot list nft FORWARD chain — skipping (requires NET_ADMIN)")
		return
	}
	if strings.Contains(string(output), "ip saddr "+subnet) {
		log.Debug().Interface("subnet", subnet).Msg("auto-bootstrap: nftables FORWARD rule already exists")
		return
	}
	// Insert the rule.
	cmd := exec.Command("nft", "insert", "rule", "ip", "filter", "FORWARD", "ip", "saddr", subnet, "accept")
	if err := cmd.Run(); err != nil {
		log.Warn().Err(err).Str("subnet", subnet).
			Msg("auto-bootstrap: cannot insert nftables FORWARD rule — K8s pod egress may be blocked; run on HOST: sudo nft insert rule ip filter FORWARD ip saddr " + subnet + " accept")
		return
	}
	log.Info().Interface("subnet", subnet).Msg("auto-bootstrap: nftables FORWARD rule inserted")
	auditLog("/var/log/bos/audit.log", "NETWORK", "subnet="+subnet, "rule=nft_FORWARD_accept")
}

// ensureBridgeNetwork orchestrates network setup: subnet detection + nftables FORWARD rule.
// Mirrors install.sh steps 0.1–0.2. On bare metal, this configures the host.
// In a container, it attempts the same (needs NET_ADMIN / --privileged).
func ensureBridgeNetwork() {
	subnet := detectNetworkSubnet()
	if subnet != "" {
		log.Info().Interface("subnet", subnet).Msg("auto-bootstrap: detected network subnet")
		ensureNftablesForwardRule(subnet)
	} else {
		log.Warn().Msg("auto-bootstrap: cannot detect network subnet — skipping nftables FORWARD rule")
	}
}

// ── Release Adapter: release.Manager → server.ReleaseChecker ──────────

type releaseAdapter struct {
	mgr *release.Manager
}

func (a *releaseAdapter) CheckAvailable(ficha, version string) ([]server.ReleaseInfo, error) {
	rels, err := a.mgr.CheckAvailable(ficha, version)
	if err != nil {
		return nil, err
	}
	return convertReleaseInfoList(rels), nil
}

func (a *releaseAdapter) GetLatest(ficha string) (*server.ReleaseInfo, error) {
	rel, err := a.mgr.GetLatest(ficha)
	if err != nil || rel == nil {
		return nil, err
	}
	return &server.ReleaseInfo{
		Ficha:       rel.Ficha,
		Version:     rel.Version,
		Channel:     rel.Channel,
		ReleaseDate: rel.ReleaseDate.Format("2006-01-02"),
		MinBosVer:   rel.MinBosVer,
		Checksum:    rel.Checksum,
		Breaking:    rel.Breaking,
		Notes:       rel.Notes,
	}, nil
}

func (a *releaseAdapter) ListAll() ([]server.ReleaseInfo, error) {
	relMap, err := a.mgr.ListAll()
	if err != nil {
		return nil, err
	}
	var all []release.ReleaseInfo
	for _, rels := range relMap {
		all = append(all, rels...)
	}
	return convertReleaseInfoList(all), nil
}

func convertReleaseInfoList(rels []release.ReleaseInfo) []server.ReleaseInfo {
	out := make([]server.ReleaseInfo, len(rels))
	for i, r := range rels {
		out[i] = server.ReleaseInfo{
			Ficha:       r.Ficha,
			Version:     r.Version,
			Channel:     r.Channel,
			ReleaseDate: r.ReleaseDate.Format("2006-01-02"),
			MinBosVer:   r.MinBosVer,
			Checksum:    r.Checksum,
			Breaking:    r.Breaking,
			Notes:       r.Notes,
		}
	}
	return out
}
