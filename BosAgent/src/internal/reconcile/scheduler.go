// Package reconcile compares declared state (manifests + task catalogs)
// against the hashed state stored in STATE_MANAGER and triggers drift
// detection when SHA-256 hashes diverge. Runs every 300s by default.
//
// Principle R16 (docs-first): manifest.yml, task_catalog.sh, and
// yaml_engine.yml are the source of truth. Their hashes are the
// signal for drift.
//
// M2.2: cada ciclo de reconciliación comienza con un K8sDiscovery que
// actualiza el state manager con la realidad de K8s (solo lectura).
// Esto permite reconocer fichas instaladas fuera del Ficha Engine.
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

// DeclaredFiles lista los archivos que definen el estado declarado de una ficha.
// Se hashean y comparan para detectar drift.
var DeclaredFiles = []string{"manifest.yml", "task_catalog.sh", "yaml_engine.yml"}

// Installer es la interfaz para disparar operaciones de reparación.
type Installer interface {
	Repair(fichaID string) (*installer.SagaResult, error)
}

// Scheduler periodically compares declared vs actual state.
//
// Thread safety: Run() y Stop() son seguros para llamar desde goroutines distintas.
// inFlight garantiza que Repair() no se llame dos veces en paralelo para la misma
// ficha (race P6/P14 — BOS-REPAIR-03).
type Scheduler struct {
	mu           sync.Mutex
	inFlight     sync.Map // map[string]bool — fichas con reparación en curso
	stateMgr     *state.Manager
	installer    Installer
	interval     time.Duration
	logger       *slog.Logger
	serversPath  string
	autoRepair   bool
	stopCh       chan struct{}
	running      bool
	k8sDiscovery *K8sDiscovery // nil si K8s no está disponible
}

// NewScheduler crea un planificador de reconciliación.
//
// Recibe:
//   - stateMgr: *state.Manager — STATE_MANAGER para leer y actualizar hashes.
//   - installer: Installer — proveedor de Repair() para auto-reparación.
//   - interval: time.Duration — frecuencia del ciclo de reconciliación (≥30s).
//   - serversPath: string — directorio servers/ (paths.ServersPath).
//   - autoRepair: bool — si true, dispara Repair() automáticamente al detectar drift.
//   - logger: *slog.Logger — logger estructurado.
//
// Callers conocidos:
//   - cmd/bos/main.go:runNormal — paso 6.
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

// WithK8sDiscovery añade el componente de descubrimiento K8s al planificador.
// Si no se llama, el planificador opera sin probe K8s (útil en modo bootstrap o test).
func (s *Scheduler) WithK8sDiscovery(d *K8sDiscovery) *Scheduler {
	s.k8sDiscovery = d
	return s
}

// Run inicia el loop periódico de reconciliación. Bloquea hasta que Stop() sea llamado.
//
// Efectos secundarios:
//   - Dispara un ciclo inmediato al arrancar (para sincronizar estado K8s real sin esperar interval).
//   - Cada interval llama reconcile() que puede transicionar fichas a ACTUALIZACION_DISPONIBLE.
//   - Si autoRepair=true, dispara goroutines de Repair() (controladas por inFlight sync.Map).
func (s *Scheduler) Run() {
	s.mu.Lock()
	s.running = true
	s.mu.Unlock()

	ticker := time.NewTicker(s.interval)
	defer ticker.Stop()

	s.logger.Info("reconcile scheduler started", "interval", s.interval)

	// Ciclo inmediato al arrancar: sincroniza estado K8s real (M2.2).
	// Evita que las fichas queden como PENDIENTE durante el primer interval.
	s.reconcile()

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

// Stop señaliza al planificador para que detenga el loop.
//
// Efectos secundarios: cierra stopCh (una sola vez bajo mu).
func (s *Scheduler) Stop() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.running {
		close(s.stopCh)
		s.running = false
	}
}

// ReconcileNow ejecuta un ciclo único de reconciliación y retorna los resultados de drift.
//
// Retorna: []DriftResult — fichas con hashes divergentes. Vacío si no hay drift.
//
// Callers conocidos:
//   - internal/server/api.go — handler "bos.reconcile.now".
//
// Efectos secundarios: actualiza hashes en STATE_MANAGER y puede disparar Repair().
func (s *Scheduler) ReconcileNow() []DriftResult {
	return s.reconcile()
}

// DriftResult describes a detected drift for a single ficha.
type DriftResult struct {
	Ficha       string
	Drift       bool
	File        string
	StoredHash  string
	CurrentHash string
}

func (s *Scheduler) reconcile() []DriftResult {
	// M2.2: sincronizar estado real de K8s ANTES del hash-diff.
	// Solo actualiza fichas con runtime=kubernetes cuyo estado en K8s es conocido.
	// No toca fichas con runtime=host ni fichas no encontradas en K8s.
	if s.k8sDiscovery != nil {
		discovered := s.k8sDiscovery.DiscoverK8sStates()
		for fichaID, fichaState := range discovered.States {
			if err := s.stateMgr.SetK8sDiscoveredState(fichaID, fichaState); err != nil {
				s.logger.Warn("reconcile: k8s_discovery: no se pudo actualizar estado",
					"ficha", fichaID, "state", fichaState, "err", err)
			}
		}
	}

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

			// Auto-repair: inFlight evita dos reparaciones paralelas del mismo ficha (P6/P14).
			if s.autoRepair && s.installer != nil {
				s.logger.Info("auto-repair triggered", "ficha", name)
				go func(fichaName string) {
					if _, loaded := s.inFlight.LoadOrStore(fichaName, true); loaded {
						s.logger.Debug("auto-repair omitido — ya hay una reparación en curso", "ficha", fichaName)
						return
					}
					defer s.inFlight.Delete(fichaName)
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

	// Reparación por salud (camino legacy para DEGRADED/ALERTA).
	// inFlight evita reparación doble si hash-based ya inició goroutine para el mismo ficha.
	for name, ficha := range st.Fichas {
		if ficha.HealthStatus == "DEGRADED" || ficha.State == state.StateDegraded {
			if s.installer != nil && s.autoRepair {
				go func(fichaName string) {
					if _, loaded := s.inFlight.LoadOrStore(fichaName, true); loaded {
						s.logger.Debug("health-repair omitido — ya hay una reparación en curso", "ficha", fichaName)
						return
					}
					defer s.inFlight.Delete(fichaName)
					if _, err := s.installer.Repair(fichaName); err != nil {
						s.logger.Error("health-based auto-repair failed", "err", err, "ficha", fichaName)
					}
				}(name)
			}
		}
	}

	return results
}

// ComputeHashes retorna hashes SHA-256 de los archivos declarativos de una ficha.
// Solo incluye los archivos que existen en disco.
//
// Efectos secundarios: ninguno — solo lectura de disco.
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

// DriftSummary retorna un reporte de drift legible para humanos.
func DriftSummary(results []DriftResult) string {
	if len(results) == 0 {
		return "no drift detected"
	}
	return fmt.Sprintf("%d fichas with drift", len(results))
}
