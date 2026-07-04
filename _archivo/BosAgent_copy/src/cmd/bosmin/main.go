// bosmin — minimal BOS daemon (health checker + reconcile scheduler only).
// Used for integration testing in sbos-k8s. No k8s, no installer, no API server.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"bos/internal/config"
	"bos/internal/health"
	"bos/internal/reconcile"
	"bos/internal/state"

	"log/slog"
)

var (
	configPath = flag.String("config", "/etc/bos/bos.toml", "path to bos.toml")
)

func main() {
	flag.Parse()

	slog.Info("bosmin daemon starting (health + reconcile only)")

	cfg, err := config.Load(*configPath)
	if err != nil {
		slog.Error("failed to load config", "err", err)
		os.Exit(1)
	}

	install := cfg.Install

	// 1. State manager
	stateMgr, err := state.NewManager(install.StateFile)
	if err != nil {
		slog.Error("failed to init state manager", "err", err, "path", install.StateFile)
		os.Exit(1)
	}
	defer stateMgr.Close()
	slog.Info("state manager initialized", "path", install.StateFile)

	// 2. Scan servers directory and register fichas found there
	registerFichasFromDisk(stateMgr, install.ServersPath)

	// 3. Health checker
	healthInterval := cfg.HealthCheckInterval()
	healthChecker := health.NewChecker(stateMgr, healthInterval, install.ServersPath,
		slog.New(slog.NewTextHandler(os.Stderr, nil)).With("component", "bosmin", "subsystem", "health"))

	// 4. Reconcile scheduler (no installer → no auto-repair)
	reconcileInterval := cfg.ReconcileInterval()
	reconcileScheduler := reconcile.NewScheduler(stateMgr, nil, reconcileInterval,
		install.ServersPath, cfg.DriftCheck,
		slog.New(slog.NewTextHandler(os.Stderr, nil)).With("component", "bosmin", "subsystem", "reconcile"))

	// 5. Signal handling
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	// 6. Start subsystems
	go healthChecker.Run()
	go reconcileScheduler.Run()

	slog.Info("bosmin daemon running", "health_interval", healthInterval, "reconcile_interval", reconcileInterval, "servers_path", install.ServersPath)

	// 7. Heartbeat loop
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case sig := <-sigCh:
			slog.Info("shutting down", "signal", sig.String())
			healthChecker.Stop()
			reconcileScheduler.Stop()
			fmt.Fprintln(os.Stderr, "bosmin daemon stopped")
			return

		case <-ticker.C:
			st, err := stateMgr.Read()
			if err != nil {
				slog.Warn("heartbeat: state read failed", "err", err)
				continue
			}
			n := len(st.Fichas)
			summary := health.Summary(healthStatuses(st))
			slog.Info("heartbeat", "fichas", n, "health", summary)
		}
	}
}

// registerFichasFromDisk scans the servers directory and ensures every ficha
// with a manifest.yml is present in the state file. Only adds, never removes.
func registerFichasFromDisk(mgr *state.Manager, serversPath string) {
	entries, err := os.ReadDir(serversPath)
	if err != nil {
		slog.Warn("cannot scan servers path", "err", err, "path", serversPath)
		return
	}

	count := 0
	for _, serverEntry := range entries {
		if !serverEntry.IsDir() {
			continue
		}
		serverName := serverEntry.Name()
		fichasDir := serversPath + "/" + serverName
		fichaEntries, err := os.ReadDir(fichasDir)
		if err != nil {
			continue
		}
		for _, fichaEntry := range fichaEntries {
			if !fichaEntry.IsDir() {
				continue
			}
			fichaName := fichaEntry.Name()

			// Check if manifest.yml exists
			manifestPath := fichasDir + "/" + fichaName + "/manifest.yml"
			if _, err := os.Stat(manifestPath); os.IsNotExist(err) {
				continue
			}

			// Check if already in state
			st, _ := mgr.Read()
			if _, exists := st.Fichas[fichaName]; exists {
				continue
			}

			// Register new ficha
			if err := mgr.Transition(fichaName, state.StateInstalando); err != nil {
				slog.Warn("register failed", "err", err, "ficha", fichaName)
				continue
			}
			if err := mgr.Transition(fichaName, state.StateInstalada); err != nil {
				slog.Warn("register OK transition failed", "err", err, "ficha", fichaName)
				continue
			}

			// Compute initial hashes
			hashes, err := reconcile.ComputeHashes(serversPath, serverName, fichaName)
			if err != nil {
				slog.Warn("hash compute failed", "err", err, "ficha", fichaName)
			}
			if err := mgr.RegisterHashes(fichaName, hashes); err != nil {
				slog.Warn("hash register failed", "err", err, "ficha", fichaName)
			}

			slog.Info("registered", "ficha", fichaName, "server", serverName)
			count++
		}
	}
	if count > 0 {
		slog.Info("new fichas registered from disk", "count", count)
	}
}

func healthStatuses(st *state.SBOSState) map[string]string {
	m := make(map[string]string)
	for name, f := range st.Fichas {
		m[name] = f.HealthStatus
	}
	return m
}
