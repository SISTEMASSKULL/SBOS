// Package health implements periodic health checking of all installed fichas.
// Each ficha's manifest.yml defines health.check_command, which is executed
// via exec with configurable timeouts. Results are classified and written to
// STATE_MANAGER via SetHealth.
//
// Classification:
//   HEALTHY  — check command exit 0
//   DEGRADED — check command non-zero exit
//   DOWN     — consecutive failures >= threshold
//   UNKNOWN  — no check_command defined, or state read error
package health

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"

	"bos/internal/state"
	"log/slog"
	"gopkg.in/yaml.v3"
)

// Status represents the health classification of a ficha.
type Status string

const (
	StatusHealthy  Status = "HEALTHY"
	StatusDegraded Status = "DEGRADED"
	StatusDown     Status = "DOWN"
	StatusUnknown  Status = "UNKNOWN"
)

// ProbeConfig is extracted from a ficha's manifest.yml health section.
type ProbeConfig struct {
	Command                   string `yaml:"check_command"`
	IntervalSeconds           int    `yaml:"check_interval_seconds"`
	TimeoutSeconds            int    `yaml:"check_timeout_seconds"`
	ConsecutiveFailuresThresh int    `yaml:"consecutive_failures_threshold"`
	InitialDelaySeconds       int    `yaml:"initial_delay_seconds"`
}

// CommandRunner executes a shell command with a context.
// In production this is exec.CommandContext; tests inject a mock.
type CommandRunner interface {
	Run(ctx context.Context, command string) (exitCode int, err error)
}

// execRunner is the real implementation using os/exec.
type execRunner struct{}

func (r *execRunner) Run(ctx context.Context, command string) (int, error) {
	cmd := exec.CommandContext(ctx, "sh", "-c", command)
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return exitErr.ExitCode(), nil
		}
		return -1, err
	}
	return 0, nil
}

// Checker polls all installed fichas and updates their health status.
type Checker struct {
	mu         sync.Mutex
	stateMgr   *state.Manager
	interval   time.Duration
	logger     *slog.Logger
	runner     CommandRunner
	serversPath string

	stopCh        chan struct{}
	running       bool
	failureCounts map[string]int
}

// NewChecker creates a health checker with the real exec runner.
func NewChecker(stateMgr *state.Manager, interval time.Duration, serversPath string, logger *slog.Logger) *Checker {
	return &Checker{
		stateMgr:     stateMgr,
		interval:     interval,
		logger:       logger,
		runner:       &execRunner{},
		serversPath:  serversPath,
		stopCh:       make(chan struct{}),
		failureCounts: make(map[string]int),
	}
}

// newCheckerWithRunner is the internal constructor for test injection.
func newCheckerWithRunner(stateMgr *state.Manager, interval time.Duration, serversPath string, logger *slog.Logger, runner CommandRunner) *Checker {
	return &Checker{
		stateMgr:     stateMgr,
		interval:     interval,
		logger:       logger,
		runner:       runner,
		serversPath:  serversPath,
		stopCh:       make(chan struct{}),
		failureCounts: make(map[string]int),
	}
}

// Run starts the periodic health check loop. Blocks until Stop() is called.
func (c *Checker) Run() {
	c.mu.Lock()
	c.running = true
	c.mu.Unlock()

	ticker := time.NewTicker(c.interval)
	defer ticker.Stop()

	c.logger.Info("health checker started", "interval", c.interval)

	c.checkAll()

	for {
		select {
		case <-ticker.C:
			c.checkAll()
		case <-c.stopCh:
			c.logger.Info("health checker stopped")
			return
		}
	}
}

// Stop signals the health checker to stop.
func (c *Checker) Stop() {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.running {
		close(c.stopCh)
		c.running = false
	}
}

// CheckNow runs a single health check sweep and returns results.
func (c *Checker) CheckNow() map[string]Status {
	return c.checkAll()
}

func (c *Checker) checkAll() map[string]Status {
	results := make(map[string]Status)

	st, err := c.stateMgr.Read()
	if err != nil {
		c.logger.Error("health check: failed to read state", "err", err)
		return results
	}

	for name, ficha := range st.Fichas {
		// Skip blocked fichas — they are not installed and have no
		// meaningful health probes to run.
		if ficha.State == state.StatePendiente {
			continue
		}
		status := c.checkOne(name, st)
		results[name] = status
		if err := c.stateMgr.SetHealth(name, string(status)); err != nil {
			c.logger.Warn("health check: update failed", "err", err, "ficha", name)
		}
	}
	return results
}

func (c *Checker) probeConfig(name string, st *state.SBOSState) *ProbeConfig {
	ficha, ok := st.Fichas[name]
	if !ok {
		return nil
	}

	// Resolve server path for this ficha.
	// If server is set, use it directly. If empty (legacy state files),
	// scan serversPath subdirectories to find the manifest.
	server := ficha.Server
	manifestPath := ""
	if server != "" {
		manifestPath = filepath.Join(c.serversPath, server, name, "manifest.yml")
	} else {
		// Legacy state — scan serversPath for the manifest
		entries, err := os.ReadDir(c.serversPath)
		if err == nil {
			for _, entry := range entries {
				if !entry.IsDir() {
					continue
				}
				candidate := filepath.Join(c.serversPath, entry.Name(), name, "manifest.yml")
				if _, err := os.Stat(candidate); err == nil {
					manifestPath = candidate
					break
				}
			}
		}
	}

	if manifestPath == "" {
		return nil
	}

	data, err := os.ReadFile(manifestPath)
	if err != nil {
		return nil
	}

	var raw struct {
		Health ProbeConfig `yaml:"health"`
	}
	if err := yaml.Unmarshal(data, &raw); err != nil {
		return nil
	}
	if raw.Health.Command == "" {
		return nil
	}
	return &raw.Health
}

func (c *Checker) checkOne(name string, st *state.SBOSState) Status {
	probe := c.probeConfig(name, st)
	if probe == nil {
		return StatusUnknown
	}

	timeout := time.Duration(probe.TimeoutSeconds) * time.Second
	if timeout <= 0 {
		timeout = 10 * time.Second
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	exitCode, runErr := c.runner.Run(ctx, probe.Command)

	if runErr != nil {
		c.logger.Warn("health probe execution error", "err", runErr, "ficha", name)
		return StatusUnknown
	}

	if exitCode == 0 {
		c.mu.Lock()
		c.failureCounts[name] = 0
		c.mu.Unlock()
		return StatusHealthy
	}

	// Non-zero exit: track consecutive failures
	c.mu.Lock()
	c.failureCounts[name]++
	count := c.failureCounts[name]
	defer c.mu.Unlock()

	threshold := probe.ConsecutiveFailuresThresh
	if threshold <= 0 {
		threshold = 3
	}

	if count >= threshold {
		c.logger.Warn("consecutive health failures — DOWN", "ficha", name, "failures", count, "exit", exitCode)
		return StatusDown
	}

	c.logger.Debug("health probe degraded", "ficha", name, "failures", count, "exit", exitCode)
	return StatusDegraded
}

// Classify determines the health status from raw signals.
func Classify(podReady bool, endpointResponds bool, stateCoherent bool) Status {
	if !stateCoherent {
		return StatusUnknown
	}
	if podReady && endpointResponds {
		return StatusHealthy
	}
	if podReady && !endpointResponds {
		return StatusDegraded
	}
	return StatusDown
}

// Summary returns a human-readable summary of health statuses.
func Summary(healthStatuses map[string]string) string {
	var healthy, degraded, down, unknown int
	for _, s := range healthStatuses {
		switch Status(s) {
		case StatusHealthy:
			healthy++
		case StatusDegraded:
			degraded++
		case StatusDown:
			down++
		default:
			unknown++
		}
	}
	return fmt.Sprintf("%d healthy, %d degraded, %d down, %d unknown", healthy, degraded, down, unknown)
}

// ResetCounters clears failure counts (used when a ficha is reinstalled).
func (c *Checker) ResetCounters(name string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	delete(c.failureCounts, name)
}
