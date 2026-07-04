// Package reconcile compares declared state (manifests + task catalogs)
// against the hashed state stored in STATE_MANAGER and triggers drift
// detection when SHA-256 hashes diverge. Runs every 300s by default.
//
// Principle R16 (docs-first): manifest.yml, task_catalog.sh, and
// yaml_engine.yml are the source of truth. Their hashes are the
// signal for drift.
package reconcile

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"
	"time"

	"bos/internal/installer"
	"bos/internal/state"
	"log/slog"
)

// DeclaredFiles lists the files that define a ficha's declared state.
// These are hashed and compared to detect drift.
var DeclaredFiles = []string{"manifest.yml", "task_catalog.sh", "yaml_engine.yml"}

// Installer is the interface for triggering repair operations.
type Installer interface {
	Repair(fichaID string) (*installer.SagaResult, error)
}

// Scheduler periodically compares declared vs actual state.
type Scheduler struct {
	mu          sync.Mutex
	stateMgr    *state.Manager
	installer   Installer
	interval    time.Duration
	logger      *slog.Logger
	serversPath string
	autoRepair  bool
	stopCh      chan struct{}
	running     bool
}

// NewScheduler creates a reconcile scheduler.
func NewScheduler(stateMgr *state.Manager, installer Installer, interval time.Duration, serversPath string, autoRepair bool, logger *slog.Logger) *Scheduler {
	return &Scheduler{
		stateMgr:    stateMgr,
		installer:   installer,
		interval:    interval,
		logger:      logger,
		serversPath: serversPath,
		autoRepair:  autoRepair,
		stopCh:      make(chan struct{}),
	}
}

// Run starts the periodic reconciliation loop.
func (s *Scheduler) Run() {
	s.mu.Lock()
	s.running = true
	s.mu.Unlock()

	ticker := time.NewTicker(s.interval)
	defer ticker.Stop()

	s.logger.Info("reconcile scheduler started", "interval", s.interval)

	for {
		select {
		case <-ticker.C:
			s.reconcile()
		case <-s.stopCh:
			s.logger.Info("reconcile scheduler stopped")
			return
		}
	}
}

// Stop signals the scheduler to stop.
func (s *Scheduler) Stop() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.running {
		close(s.stopCh)
		s.running = false
	}
}

// ReconcileNow runs a single reconciliation sweep and returns drift results.
func (s *Scheduler) ReconcileNow() []DriftResult {
	return s.reconcile()
}

// DriftResult describes a detected drift for a single ficha.
type DriftResult struct {
	Ficha      string
	Drift      bool
	File       string
	StoredHash string
	CurrentHash string
}

func (s *Scheduler) reconcile() []DriftResult {
	st, err := s.stateMgr.Read()
	if err != nil {
		s.logger.Error("reconcile: failed to read state", "err", err)
		return nil
	}

	var results []DriftResult

	for name, ficha := range st.Fichas {
		if ficha.Server == "" {
			continue
		}

		// Compute current hashes of declared files
		current, err := ComputeHashes(s.serversPath, ficha.Server, name)
		if err != nil {
			s.logger.Warn("reconcile: hash compute failed", "err", err, "ficha", name)
			continue
		}

		// Compare against stored hashes
		stored := ficha.Hashes
		drifted := false
		for _, file := range DeclaredFiles {
			storedHash, hasStored := stored[file]
			currentHash, hasCurrent := current[file]

			if hasStored && hasCurrent && storedHash != currentHash {
				s.logger.Warn("drift detected", "ficha", name, "file", file, "stored", storedHash[:12], "current", currentHash[:12])
				drifted = true
				results = append(results, DriftResult{
					Ficha:       name,
					Drift:       true,
					File:        file,
					StoredHash:  storedHash,
					CurrentHash: currentHash,
				})
			}
		}

		if drifted {
			// Transition to ACTUALIZACION_DISPONIBLE
			if err := s.stateMgr.SetDriftDetected(name); err != nil {
				s.logger.Warn("reconcile: drift transition failed", "err", err, "ficha", name)
			}

			// Auto-repair if enabled and installer is available
			if s.autoRepair && s.installer != nil {
				s.logger.Info("auto-repair triggered", "ficha", name)
				go func(fichaName string) {
					if _, err := s.installer.Repair(fichaName); err != nil {
						s.logger.Error("auto-repair failed", "err", err, "ficha", fichaName)
					}
				}(name)
			}
		}

		// Update stored hashes to current (even if no drift, this is the new baseline)
		if err := s.stateMgr.RegisterHashes(name, current); err != nil {
			s.logger.Warn("reconcile: hash update failed", "err", err, "ficha", name)
		}
	}

	// Health-based reconciliation (legacy path for DEGRADED/ALERTA)
	for name, ficha := range st.Fichas {
		if ficha.HealthStatus == "DEGRADED" || ficha.State == state.StateDegradada {
			if s.installer != nil && s.autoRepair {
				go func(fichaName string) {
					if _, err := s.installer.Repair(fichaName); err != nil {
						s.logger.Error("health-based auto-repair failed", "err", err, "ficha", fichaName)
					}
				}(name)
			}
		}
	}

	return results
}

// ComputeHashes returns SHA-256 hashes for the declared files of a ficha.
// Only files that exist on disk are included in the result.
func ComputeHashes(serversPath, server, name string) (map[string]string, error) {
	hashes := make(map[string]string)
	base := filepath.Join(serversPath, server, name)

	for _, file := range DeclaredFiles {
		p := filepath.Join(base, file)
		h, err := sha256File(p)
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return nil, fmt.Errorf("hash %s: %w", file, err)
		}
		hashes[file] = h
	}
	return hashes, nil
}

func sha256File(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// DriftSummary returns a human-readable drift report.
func DriftSummary(results []DriftResult) string {
	if len(results) == 0 {
		return "no drift detected"
	}
	return fmt.Sprintf("%d fichas with drift", len(results))
}
