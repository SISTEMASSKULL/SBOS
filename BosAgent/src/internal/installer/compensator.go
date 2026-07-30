package installer

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"time"

	"log/slog"
)

// CompensationChain define la secuencia de acciones compensadoras a ejecutar
// cuando una saga falla. Las acciones se ejecutan en el orden definido
// (el caller debe definirlas en orden inverso a los pasos de la saga).
//
// Thread safety: inmutable tras construcción — seguro para uso concurrente.
type CompensationChain struct {
	Actions []CompensationAction
}

// CompensationAction is a single undo step.
type CompensationAction struct {
	Name    string
	Handler string // bash function name
	Timeout time.Duration
}

// Compensator ejecuta cadenas de compensación tras fallos de sagas.
//
// Thread safety: seguro para uso concurrente — cada llamada a Compensate es independiente.
// Campo masterScript: solo lectura tras construcción.
//
// Restricciones:
//   - masterScript NUNCA debe ser vacío — se valida en NewCompensator.
//   - Las acciones de compensación son best-effort: los errores se logean pero no se propagan.
//
// Principios: P6 (toda saga tiene compensación), P12 (cada paso tiene rollback).
type Compensator struct {
	masterScript string
	logger       *slog.Logger
}

// NewCompensator crea un ejecutor de compensación ligado al master script.
//
// Recibe:
//   - masterScript: string — ruta absoluta a 00_MASTER_INSTALL_SBOS.sh. P16.
//   - logger: *slog.Logger — logger del orchestrator padre.
//
// Retorna: *Compensator listo para uso.
//
// Callers conocidos:
//   - internal/installer/saga.go — NewOrchestrator().
func NewCompensator(masterScript string, logger *slog.Logger) *Compensator {
	return &Compensator{
		masterScript: masterScript,
		logger:       logger,
	}
}

// Cadenas de compensación predefinidas por operación.
//
// P15 — reglas de compensación:
//   - InstallCompensation: llama "remove" para limpiar una instalación fallida.
//     "remove" es el único comando del master script que desmonta una ficha (check
//     de gobernanza incluido). Antes usaba "uninstall" que el master script rechaza.
//   - UpdateCompensation: vacía — el bash cmd_update() ya llama restore_ficha_resources()
//     antes de retornar exit 3. Compensación Go adicional sería redundante y peligrosa.
//   - RepairCompensation: vacía — el bash cmd_repair() gestiona su propio fallo;
//     la ficha queda FALLA_INSTALACION y el operador decide.
var (
	InstallCompensation = CompensationChain{
		Actions: []CompensationAction{
			{Name: "remove", Handler: "remove", Timeout: 10 * time.Minute},
		},
	}

	// UpdateCompensation sin acciones: el bash script maneja su propio rollback
	// mediante restore_ficha_resources() — no destruir fichas instaladas (P15).
	UpdateCompensation = CompensationChain{
		Actions: []CompensationAction{},
	}

	// RepairCompensation sin acciones: el bash gestiona repair failure;
	// la ficha queda en FALLA_INSTALACION para decisión del operador.
	RepairCompensation = CompensationChain{
		Actions: []CompensationAction{},
	}
)

// Compensate ejecuta la cadena de compensación de una saga fallida.
//
// Recibe:
//   - chain: CompensationChain — acciones a ejecutar (en el orden definido).
//   - fichaID: string — identificador de la ficha para logging.
//   - fichaDir: string — directorio de la ficha (no usado directamente; el master script lo resuelve).
//
// Retorna: siempre nil — errores individuales se logean pero no se propagan (best-effort).
//
// Callers conocidos:
//   - internal/installer/saga.go:Orchestrator.Install — en el bloque de compensación del saga.
//
// Efectos secundarios:
//   - Ejecuta bash con el master script y el comando de compensación.
//   - NUNCA registrar contraseñas ni tokens en logs.
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

// SelectChain retorna la cadena de compensación predefinida para un comando saga.
//
// Recibe:
//   - cmd: Command — CmdInstall | CmdUpdate | CmdRepair. Otros retornan cadena vacía.
//
// Retorna: CompensationChain con las acciones de compensación correspondientes.
//
// Callers conocidos:
//   - ChainForSaga — wrapper público para el mismo propósito.
//   - internal/installer/saga.go:Orchestrator — selecciona la cadena antes de ejecutar el saga.
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

// ChainForSaga construye la cadena de compensación del ciclo de vida para el comando dado.
// Delegado de SelectChain — punto de entrada preferido para el orchestrator.
//
// Retorna: CompensationChain para el comando, o cadena vacía si el comando no tiene compensación.
func ChainForSaga(cmd Command) CompensationChain {
	return SelectChain(cmd)
}
