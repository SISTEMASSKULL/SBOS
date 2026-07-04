package installer

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"time"

	"log/slog"
)

// CompensationChain defines a sequence of compensating actions
// to execute in reverse order when a saga fails.
type CompensationChain struct {
	Actions []CompensationAction
}

// CompensationAction is a single undo step.
type CompensationAction struct {
	Name    string
	Handler string // bash function name
	Timeout time.Duration
}

// Compensator executes compensation chains after saga failures.
// Principle P6: every saga has a compensation chain.
// Principle P12: each step has a rollback defined.
type Compensator struct {
	masterScript string
	logger       *slog.Logger
}

// NewCompensator creates a compensator.
func NewCompensator(masterScript string, logger *slog.Logger) *Compensator {
	return &Compensator{
		masterScript: masterScript,
		logger:       logger,
	}
}

// Predefined compensation chains for each operation.
var (
	InstallCompensation = CompensationChain{
		Actions: []CompensationAction{
			{Name: "uninstall", Handler: "uninstall", Timeout: 10 * time.Minute},
		},
	}

	UpdateCompensation = CompensationChain{
		Actions: []CompensationAction{
			{Name: "restore_backup", Handler: "uninstall", Timeout: 10 * time.Minute},
		},
	}

	RepairCompensation = CompensationChain{
		Actions: []CompensationAction{
			{Name: "rollback_repair", Handler: "uninstall", Timeout: 10 * time.Minute},
		},
	}
)

// Compensate executes a compensation chain for a failed saga.
// Compensation actions always run to completion (best-effort) — errors are logged but not escalated.
func (c *Compensator) Compensate(chain CompensationChain, fichaID, fichaDir string) error {
	c.logger.Warn("compensation starting", "ficha", fichaID, "actions", len(chain.Actions))

	// Execute in order (the chain is already defined in reverse-saga order)
	for _, action := range chain.Actions {
		c.logger.Info("compensation action", "action", action.Name, "ficha", fichaID)

		if err := c.executeCompensation(action, fichaID, fichaDir); err != nil {
			// Log but continue — compensation is best-effort
			c.logger.Error("compensation action failed (continuing)", "err", err, "action", action.Name, "ficha", fichaID)
		}
	}

	c.logger.Info("compensation complete", "ficha", fichaID)
	return nil
}

func (c *Compensator) executeCompensation(action CompensationAction, fichaID, fichaDir string) error {
	timeout := action.Timeout
	if timeout == 0 {
		timeout = 10 * time.Minute
	}

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	// Usar el mismo mecanismo que el saga orchestrator: invocar el
	// master script con el comando de compensación, igual que se hace
	// con install/update/repair/uninstall. El master script buscará
	// task_catalog.sh de la ficha y ejecutará ficha_uninstall().
	args := []string{c.masterScript, action.Handler, fichaID}

	cmd := exec.CommandContext(ctx, "bash", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("compensator: %s: %w", action.Name, err)
	}
	return nil
}

// SelectChain returns the appropriate compensation chain for a command.
func SelectChain(cmd Command) CompensationChain {
	switch cmd {
	case CmdInstall:
		return InstallCompensation
	case CmdUpdate:
		return UpdateCompensation
	case CmdRepair:
		return RepairCompensation
	default:
		return CompensationChain{}
	}
}

// ChainForSaga builds a custom compensation chain by reading the
// architecture registry for the lifecycle compensacion definition.
func ChainForSaga(cmd Command) CompensationChain {
	return SelectChain(cmd)
}
