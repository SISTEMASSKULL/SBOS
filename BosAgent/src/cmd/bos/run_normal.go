// run_normal.go — modo de operación normal del daemon bos.
// Extraído de cmd/bos/main.go en F1.9 — SRP: main.go solo orquesta.
package main

import (
	"context"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"bos/internal/audit"
	"bos/internal/biaos"
	"bos/internal/config"
	bosctx "bos/internal/context"
	"bos/internal/domain"
	"bos/internal/health"
	"bos/internal/installer"
	"bos/internal/k8s"
	"bos/internal/maintenance"
	"bos/internal/metrics"
	"bos/internal/observer"
	"bos/internal/paths"
	"bos/internal/plugin"
	"bos/internal/query"
	"bos/internal/reconcile"
	"bos/internal/release"
	"bos/internal/repair"
	"bos/internal/security"
	"bos/internal/server"
	"bos/internal/state"
	"bos/internal/system"
	"bos/internal/watchdog"

	"github.com/rs/zerolog/log"
)

// ── Funciones de inicialización de subsistemas (A-09) ────────────────────────

// initStateManager inicializa el STATE_MANAGER. Llama a os.Exit(1) si el
// state file no puede abrirse — sin estado el daemon no puede operar.
func initStateManager(stateFile string) *state.Manager {
	mgr, err := state.NewManager(stateFile)
	if err != nil {
		log.Error().Err(err).Interface("path", stateFile).Msg("failed to init state manager")
		os.Exit(1)
	}
	switch mgr.Recovery {
	case state.RecoveryBackup:
		log.Warn().Interface("path", stateFile).Msg("state file loaded from backup — primary was corrupt")
	case state.RecoveryRebuilt:
		log.Warn().Interface("path", stateFile).Msg("state file rebuilt from empty — both primary and backup were lost")
	}
	log.Info().Interface("path", stateFile).Msg("state manager initialized")
	return mgr
}

// initPluginLoader inicializa el plugin loader y ejecuta el scan inicial de fichas.
func initPluginLoader(serversPath string) *plugin.Loader {
	loader := plugin.NewLoader(serversPath, newSlogLogger("plugin"))
	fichas, err := loader.Scan()
	if err != nil {
		log.Warn().Err(err).Msg("plugin scan had errors")
	}
	count := len(fichas)
	log.Info().Int("count", count).Msg("plugins loaded")
	audit.Log(paths.AuditLog, "PLUGINS",
		"count="+strconv.Itoa(count),
		"path="+serversPath)
	return loader
}

// initK8sCore inicializa el núcleo K8s y el servicio PG Auxiliar Anti-Pérdida.
func initK8sCore(kubeconfigPath string, installTimeout time.Duration) (*k8s.Core, *domain.PgAuxiliarService) {
	core := k8s.NewCore(kubeconfigPath, installTimeout)
	log.Info().Interface("kubeconfig", kubeconfigPath).Msg("k8s core initialized")
	pgAux := domain.NewPgAuxiliarService(core)
	log.Info().Msg("pg_auxiliar service initialized")
	return core, pgAux
}

// initContextService inicializa el Context Plane con PG+Redis si están disponibles,
// degradando a nil (memStore) si la DSN no está configurada o la conexión falla.
func initContextService(pgDSN, redisAddr string, redisDB int) *bosctx.Service {
	if pgDSN == "" {
		log.Info().Msg("Context Plane: BOS_PG_DSN no configurado — modo memStore")
		return nil
	}
	svc, err := bosctx.NewServiceWithPGRedis(pgDSN, redisAddr, redisDB)
	if err != nil {
		log.Warn().Err(err).Msg("Context Plane: PG/Redis no disponibles — modo memStore (degradado)")
		return nil
	}
	log.Info().
		Str("pg", maskDSN(pgDSN)).
		Str("redis", redisAddr).
		Int("redis_db", redisDB).
		Msg("Context Plane: PGRedisStore inicializado")
	return svc
}

// maskDSN oculta el password de una DSN postgres://user:pass@host/db para logs.
func maskDSN(dsn string) string {
	// Busca el patrón ://user:password@ y lo reemplaza con ://user:***@
	const marker = "://"
	i := len(marker)
	if j := len(dsn); j > i {
		if at := strings.Index(dsn[i:], "@"); at >= 0 {
			if colon := strings.Index(dsn[i:i+at], ":"); colon >= 0 {
				return dsn[:i+colon+1] + "***" + dsn[i+at:]
			}
		}
	}
	return dsn
}

// runNormal inicia todos los subsistemas y entra en el event loop principal.
// Inicializa en orden: STATE_MANAGER → plugins → K8s → release → saga → observer → health
// → reconcile → repair → watchdog → RBAC → API server → señales.
//
// Efectos secundarios:
//   - Abre /etc/bos/.sbos_state.json con flock exclusivo.
//   - Inicia goroutines para observer, health, reconcile, watchdog, API server.
//   - Registra eventos en /var/log/bos/audit.log.
func runNormal(cfg *config.Config, benv *bootstrapEnv) {
	// stopCh cierra todas las goroutinas que lo usan (StartWatchdog) al retornar.
	stopCh := make(chan struct{})
	defer close(stopCh)

	install := cfg.Install

	log.Info().
		Str("channel", install.Channel).
		Int("port", install.HTTPPort).
		Str("org", install.OrgName).
		Str("tenant", benv.TenantID).
		Msg("config loaded — normal startup")

	audit.Log(paths.AuditLog, "STARTUP",
		"user=root",
		"tenant="+benv.TenantID,
		"channel="+install.Channel)

	// 1. Inicializar STATE_MANAGER
	stateMgr := initStateManager(install.StateFile)
	defer stateMgr.Close()

	// 2. Inicializar plugin loader
	pluginLoader := initPluginLoader(install.ServersPath)

	// 3. Inicializar K8s core + PG Auxiliar
	k8sCore, pgAuxSvc := initK8sCore(install.KubeconfigPath, cfg.SagaTimeout("install"))

	// 4. Inicializar release manager
	releaseMgr := release.NewManager(install.ReleaseServerURL, install.Channel,
		newSlogLogger("release"))
	log.Info().Interface("server", install.ReleaseServerURL).Interface("channel", install.Channel).Msg("release manager initialized")

	// 4b. Adapter: release.Manager → server.ReleaseInfo
	releaseAdapter := release.NewAdapter(releaseMgr)

	// 5. Inicializar saga orchestrator + compensator
	masterScript := filepath.Join(install.CorePath, "00_MASTER_INSTALL_SBOS.sh")
	orchestrator := installer.NewOrchestrator(masterScript, install.CorePath,
		cfg.SagaTimeout("install"),
		newSlogLogger("installer"))
	compensator := installer.NewCompensator(masterScript,
		newSlogLogger("compensator"))

	// Wire compensator into orchestrator
	orchestrator.SetCompensator(compensator)
	log.Info().Interface("core_dir", install.CorePath).Msg("installer ready")

	// 5.25 Crear K8s discovery — necesario para P15-A2 y para el reconcile scheduler (M2.2).
	// Se crea aquí (antes del observer) para poder proteger fichas existentes al arrancar.
	k8sDiscovery := reconcile.NewK8sDiscovery(install.ServersPath, k8sCore, newSlogLogger("k8s-discovery"))

	// 5.5 Inicializar estados de fichas y arrancar observer loop
	observer.InitializeFichaStates(pluginLoader, stateMgr)

	// P15-A2: Si el state.json fue reconstruido desde cero, proteger fichas ya
	// instaladas en K8s antes de arrancar el observer — evita reinstalación destructiva.
	observer.P15ReconcileAfterRebuild(stateMgr, func() map[string]state.FichaState {
		result := k8sDiscovery.DiscoverK8sStates()
		return result.States
	})

	observerLoop := observer.New(observer.Config{
		Orchestrator: orchestrator,
		Loader:       pluginLoader,
		StateMgr:     stateMgr,
	})
	defer observerLoop.Stop()
	go observerLoop.Run()

	// 6. Inicializar health checker
	healthInterval := cfg.HealthCheckInterval()
	healthChecker := health.NewChecker(stateMgr, healthInterval, install.ServersPath,
		newSlogLogger("health"))

	// 7. Inicializar reconcile scheduler con K8s discovery (M2.2)
	reconcileInterval := cfg.ReconcileInterval()
	reconcileScheduler := reconcile.NewScheduler(stateMgr, orchestrator, reconcileInterval,
		install.ServersPath, cfg.DriftCheck,
		newSlogLogger("reconcile")).
		WithK8sDiscovery(k8sDiscovery)

	// 7.4 Inicializar repair manager (auto-repair del watchdog, desactivado por defecto)
	repairMgr := repair.NewRepairManager(stateMgr, nil,
		cfg.SagaTimeout("repair"), false, newSlogLogger("repair"))

	// 7.45 Inicializar unified watchdog (Ubuntu + K8s + BOS, ciclo 30s)
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

	// 7.5a Context Plane — PG + Redis reales (M3.1, SBOS-049)
	ctxService := initContextService(install.PostgresDSN, install.RedisAddr, install.RedisDB)

	// 7.5 Wire RBAC: BauthRBAC bridge si configurado, sino FileRBAC.
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

	// 8. Inicializar API server
	apiServer := server.NewServer(
		server.Config{
			HTTPPort:   install.HTTPPort,
			UnixSocket: install.UnixSocket,
			Version:    version,
		},
		stateMgr,
		pluginLoader,
		healthChecker,
		orchestrator,
		rbacProvider,
		identityProvider,
		newSlogLogger("api"),
		pgAuxSvc,
		ctxService, // nil → memStore (degradado); no-nil → PGRedisStore real
	)
	apiServer.SetReleaseManager(releaseAdapter)
	// M-15: K8sQuerier — despacha kubectl vía k8s.Core (Principio P1)
	apiServer.SetK8sQuerier(query.NewK8sQuerier(k8sCore))
	// F9.5/F9.6 — Operator Soberano: k8sCore como operador del cluster y
	// saga de mantenimiento con uncordon garantizado sobre el mismo Core
	apiServer.SetK8sOperator(k8sCore)
	apiServer.SetMaintenanceService(maintenance.NewService(k8sCore))
	// K8sScanner: bos.ficha.rescan dispara descubrimiento K8s bajo demanda
	// sin esperar el próximo ciclo de reconciliación (300s).
	apiServer.SetK8sScanner(reconcile.NewK8sScanAdapter(k8sDiscovery, stateMgr))

	// F10 — agente biaos: catálogo ICAP + ReAct + HITL; sus herramientas son
	// el propio dispatcher RPC (ToolExecutor). Degrada sin catálogo sin
	// tumbar el daemon (biaos es opcional; el resto del bos funciona).
	if biaosGW, err := biaos.New(biaos.Config{
		CatalogPath:  "/etc/bos/ai/action_catalog.yml",
		AuditLogPath: paths.AIAuditLog,
		OllamaURL:    os.Getenv("BOS_AI_LOCAL_ENDPOINT"),
		OllamaModel:  os.Getenv("BOS_AI_EMBED_MODEL"),
		RBAC:         rbacProvider,
		Exec:         apiServer.ToolExecutor,
	}); err != nil {
		log.Warn().Err(err).Msg("biaos no disponible (catálogo ausente) — bos.ai.* degradado")
	} else {
		apiServer.SetAIAgent(biaosGW.Agente())
		log.Info().Msg("biaos: agente OS inicializado (bos.ai.* activo)")
	}

	// F6.14 — el watchdog diagnostica (bos.query.repair) ANTES de auto-reparar
	unifiedWatchdog.SetDiagnosticador(func(fichaID string) (string, int, error) {
		out, err := apiServer.ToolExecutor("bos.query.repair",
			map[string]interface{}{"ficha_id": fichaID})
		if err != nil {
			return "", 0, err
		}
		causa, usuarios := "", 0
		if m, ok := out.(map[string]interface{}); ok {
			if d, ok := m["diagnostico"].(map[string]interface{}); ok {
				causa, _ = d["causa_probable"].(string)
			}
			if imp, ok := m["impacto"].(map[string]interface{}); ok {
				switch v := imp["usuarios_afectados"].(type) {
				case int:
					usuarios = v
				case float64:
					usuarios = int(v)
				}
			}
		}
		return causa, usuarios, nil
	})

	// F9.7 — métricas Prometheus en 127.0.0.1:9090 (solo loopback)
	metricsReg := metrics.NewRegistry()
	metricsReg.RegisterCollector(func(set func(string, int64)) {
		st, err := stateMgr.Read()
		if err != nil {
			return
		}
		var inst, deg, errN, pend int64
		for _, f := range st.Fichas {
			switch f.State {
			case state.StateInstalada:
				inst++
			case state.StateDegradada:
				deg++
			case state.StateErrorFisico, state.StateErrorLogico, state.StateErrorNoCorregible:
				errN++
			case state.StatePendiente, state.StateLista:
				pend++
			}
		}
		set("bos_fichas_total", int64(len(st.Fichas)))
		set("bos_fichas_instaladas", inst)
		set("bos_fichas_degradadas", deg)
		set("bos_fichas_en_error", errN)
		set("bos_fichas_pendientes", pend)

		// nodos Ready vía el Operator Soberano (F9.5)
		if nodes, err := k8sCore.GetNodes(); err == nil {
			var ready int64
			for _, n := range nodes {
				if n.Ready {
					ready++
				}
			}
			set("bos_k8s_nodes_ready", ready)
		}
	})
	apiServer.SetMetrics(metricsReg)
	go func() {
		if err := metricsReg.Serve("127.0.0.1:9090"); err != nil {
			log.Warn().Err(err).Msg("metrics: listener 9090 no disponible")
		}
	}()

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

	// 9.5 AutoMigrate Context Plane DDL (F10.B.12, M1.5)
	// Verifica bos.registered_device + bos.context_session en sbos_db.
	// Con memStore (dev) es no-op. Con PGRedisStore verifica existencia (DDL_bos_schema.sql).
	ctxMigrate, cancelMigrate := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancelMigrate()
	if err := apiServer.AutoMigrateContextPlane(ctxMigrate); err != nil {
		log.Warn().Err(err).Msg("AutoMigrate Context Plane DDL falló — el daemon continúa. Las tablas se crearán cuando PostgreSQL esté disponible")
	} else {
		log.Info().Msg("Context Plane DDL verificado (AutoMigrate OK)")
	}

	// 10. Arrancar subsistemas
	go healthChecker.Run()
	go reconcileScheduler.Run()

	errCh := make(chan error, 1)
	go func() {
		errCh <- apiServer.ListenAndServe()
	}()

	log.Info().Msg("bos daemon running — all subsystems started")
	audit.Log(paths.AuditLog, "RUNNING", "user=root", "state=all_subsystems_started")

	// 10.5 Reconciliación de arranque: verificar estado K8s antes de entrar al event loop.
	// Si K8s estaba corriendo antes de que BOS se detuviera (o crasheara), restaurarlo inmediatamente.
	observer.StartupReconcile(stateMgr, healthChecker, system.SystemctlCmd)

	// Notificar a systemd que BOS está listo.
	system.SDNotify("READY=1\nSTATUS=BOS daemon running — K8s state verified")

	// 10.6 Keep-alive systemd: WATCHDOG=1 al 50% del intervalo WatchdogSec (P12).
	go system.StartWatchdog(stopCh)
	// 10.7 Watchdog unificado (Ubuntu + K8s + BOS, ciclo cada 30s).
	go unifiedWatchdog.Run()

	// 11. Event loop principal
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
				// SIGTERM/SIGINT = restart o stop del SERVICIO — el cluster
				// no se toca (F9.0: un redeploy del binario derribaba el nodo)
				log.Info().Msg("shutting down gracefully (solo daemon — cluster intacto)")
				audit.Log(paths.AuditLog, "SHUTDOWN", "user=root", "signal="+sig.String())
				shutdown(apiServer, healthChecker, reconcileScheduler, orchestrator, unifiedWatchdog, false)
				return
			}

		case err := <-errCh:
			if err != nil {
				log.Error().Err(err).Msg("api server fatal error")
				os.Exit(1)
			}

		case <-apiServer.ShutdownCh:
			// Orden explícita del operador (WS "shutdown" del dashboard P11):
			// apagado completo del nodo — drain → kubelet → containerd
			log.Info().Msg("shutdown requested via API (apagado completo del stack)")
			audit.Log(paths.AuditLog, "SHUTDOWN", "user=root", "signal=api_request")
			shutdown(apiServer, healthChecker, reconcileScheduler, orchestrator, unifiedWatchdog, true)
			return

		case <-time.After(10 * time.Second):
			pluginCount := pluginLoader.Count()
			if pluginCount > 0 {
				log.Debug().Interface("fichas", pluginCount).Msg("heartbeat")
			}
		}
	}
}
