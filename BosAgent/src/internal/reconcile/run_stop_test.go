// Package reconcile — tests T8.6 (F8): ciclo Run/Stop del Scheduler.
// Complementa los tests de drift existentes; el fix de la race P6/P14
// (inFlight sync.Map) se ejercita bajo -race.
package reconcile

import (
	"io"
	"log/slog"
	"path/filepath"
	"testing"
	"time"

	"bos/internal/state"
)

// TestScheduler_RunYStop: el loop ejecuta ticks de reconciliación con un
// estado vacío y se detiene limpiamente; Stop es idempotente.
func TestScheduler_RunYStop(t *testing.T) {
	dir := t.TempDir()
	stateMgr, err := state.NewManager(filepath.Join(dir, "state.json"))
	if err != nil {
		t.Fatal(err)
	}
	defer stateMgr.Close()

	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	s := NewScheduler(stateMgr, nil, 20*time.Millisecond,
		filepath.Join(dir, "servers"), false, logger)

	done := make(chan struct{})
	go func() { s.Run(); close(done) }()

	// dejar correr al menos 2 ticks de reconcile() con estado vacío
	time.Sleep(60 * time.Millisecond)

	s.Stop()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("Run() no retornó tras Stop()")
	}
	s.Stop() // idempotente — no debe cerrar el canal dos veces
}
