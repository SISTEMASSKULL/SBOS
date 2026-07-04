package reconcile

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"bos/internal/installer"
	"log/slog"
	"sync"

	"bos/internal/state"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func testLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelDebug}))
}

func writeFichaFiles(t *testing.T, serversDir, server, name string, files map[string]string) {
	t.Helper()
	dir := filepath.Join(serversDir, server, name)
	require.NoError(t, os.MkdirAll(dir, 0755))
	for fname, content := range files {
		require.NoError(t, os.WriteFile(filepath.Join(dir, fname), []byte(content), 0644))
	}
}

// newTestManagerWithFichas creates a state manager with fichas pre-populated
// including Server fields (which Transition doesn't set).
func newTestManagerWithFichas(t *testing.T, fichas map[string]*state.Ficha) (*state.Manager, string) {
	t.Helper()
	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")

	initial := state.SBOSState{
		Version:  "1.0.0",
		Hostname: "test-host",
		Fichas:   fichas,
		Meta:     map[string]string{},
	}

	raw, err := json.MarshalIndent(initial, "", "  ")
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(statePath, raw, 0600))

	mgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	t.Cleanup(func() { mgr.Close() })
	return mgr, statePath
}

// ── ComputeHashes ────────────────────────────────────────────

func TestComputeHashes_AllFiles(t *testing.T) {
	dir := t.TempDir()
	writeFichaFiles(t, dir, "svr", "app", map[string]string{
		"manifest.yml":    "id: app\nhealth:\n  check_command: /bin/true",
		"task_catalog.sh": "#!/bin/bash\necho install",
		"yaml_engine.yml": "resources: []",
	})

	hashes, err := ComputeHashes(dir, "svr", "app")
	require.NoError(t, err)
	assert.Len(t, hashes, 3)
	assert.NotEmpty(t, hashes["manifest.yml"])
	assert.NotEmpty(t, hashes["task_catalog.sh"])
	assert.NotEmpty(t, hashes["yaml_engine.yml"])
}

func TestComputeHashes_PartialFiles(t *testing.T) {
	dir := t.TempDir()
	writeFichaFiles(t, dir, "svr", "app", map[string]string{
		"manifest.yml": "id: app",
	})

	hashes, err := ComputeHashes(dir, "svr", "app")
	require.NoError(t, err)
	assert.Len(t, hashes, 1)
	assert.NotEmpty(t, hashes["manifest.yml"])
	_, hasTask := hashes["task_catalog.sh"]
	assert.False(t, hasTask)
}

func TestComputeHashes_NoDirectory(t *testing.T) {
	dir := t.TempDir()
	hashes, err := ComputeHashes(dir, "ghost", "nonexistent")
	require.NoError(t, err)
	assert.Empty(t, hashes)
}

func TestComputeHashes_DifferentContentDifferentHash(t *testing.T) {
	dir := t.TempDir()
	writeFichaFiles(t, dir, "svr", "app-a", map[string]string{
		"manifest.yml": "id: app-a\nversion: 1.0",
	})
	writeFichaFiles(t, dir, "svr", "app-b", map[string]string{
		"manifest.yml": "id: app-b\nversion: 2.0",
	})

	ha, _ := ComputeHashes(dir, "svr", "app-a")
	hb, _ := ComputeHashes(dir, "svr", "app-b")
	assert.NotEqual(t, ha["manifest.yml"], hb["manifest.yml"])
}

func TestComputeHashes_SameContentSameHash(t *testing.T) {
	dir := t.TempDir()
	content := "id: same\nversion: 1.0"
	writeFichaFiles(t, dir, "svr", "app-a", map[string]string{"manifest.yml": content})
	writeFichaFiles(t, dir, "svr", "app-b", map[string]string{"manifest.yml": content})

	ha, _ := ComputeHashes(dir, "svr", "app-a")
	hb, _ := ComputeHashes(dir, "svr", "app-b")
	assert.Equal(t, ha["manifest.yml"], hb["manifest.yml"])
}

// ── sha256File ───────────────────────────────────────────────

func TestSHA256File_KnownValue(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.txt")
	require.NoError(t, os.WriteFile(path, []byte("hello\n"), 0644))

	h, err := sha256File(path)
	require.NoError(t, err)
	assert.Equal(t, "5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03", h)
}

// ── DriftSummary ─────────────────────────────────────────────

func TestDriftSummary_NoDrift(t *testing.T) {
	assert.Equal(t, "no drift detected", DriftSummary(nil))
	assert.Equal(t, "no drift detected", DriftSummary([]DriftResult{}))
}

func TestDriftSummary_WithDrift(t *testing.T) {
	results := []DriftResult{
		{Ficha: "a", Drift: true, File: "manifest.yml"},
		{Ficha: "b", Drift: true, File: "task_catalog.sh"},
	}
	assert.Contains(t, DriftSummary(results), "2 fichas")
}

// ── reconcile (drift detection) ──────────────────────────────

func TestReconcile_NoDriftWhenHashesMatch(t *testing.T) {
	serversDir := t.TempDir()
	writeFichaFiles(t, serversDir, "svr", "app", map[string]string{
		"manifest.yml":    "id: app",
		"task_catalog.sh": "#!/bin/bash\necho ok",
		"yaml_engine.yml": "resources: []",
	})

	freshHashes, err := ComputeHashes(serversDir, "svr", "app")
	require.NoError(t, err)

	mgr, _ := newTestManagerWithFichas(t, map[string]*state.Ficha{
		"app": {
			Name:    "app",
			Version: "1.0",
			State:   state.StateInstalada,
			Server:  "svr",
			Hashes:  freshHashes,
		},
	})

	s := NewScheduler(mgr, nil, 10*time.Second, serversDir, false, testLogger())
	results := s.ReconcileNow()
	assert.Empty(t, results)
}

func TestReconcile_DetectsDriftWhenHashChanges(t *testing.T) {
	serversDir := t.TempDir()
	writeFichaFiles(t, serversDir, "svr", "app", map[string]string{
		"manifest.yml":    "id: app\nversion: 2.0",
		"task_catalog.sh": "#!/bin/bash\necho new version",
	})

	oldHashes := map[string]string{
		"manifest.yml":    "sha256:0000000000000000000000000000000000000000000000000000000000000000",
		"task_catalog.sh": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
	}

	mgr, _ := newTestManagerWithFichas(t, map[string]*state.Ficha{
		"app": {
			Name:    "app",
			Version: "1.0",
			State:   state.StateInstalada,
			Server:  "svr",
			Hashes:  oldHashes,
		},
	})

	s := NewScheduler(mgr, nil, 10*time.Second, serversDir, false, testLogger())
	results := s.ReconcileNow()

	require.Len(t, results, 2)
	assert.Equal(t, "app", results[0].Ficha)
	assert.True(t, results[0].Drift)

	// State should transition to ACTUALIZACION_DISPONIBLE
	st, _ := mgr.Read()
	assert.Equal(t, state.StateActualizacionDisp, st.Fichas["app"].State)
}

func TestReconcile_SkipsFichaWithoutServer(t *testing.T) {
	serversDir := t.TempDir()

	mgr, _ := newTestManagerWithFichas(t, map[string]*state.Ficha{
		"noserver": {
			Name:    "noserver",
			Version: "1.0",
			State:   state.StateInstalada,
			Server:  "",
			Hashes:  map[string]string{},
		},
	})

	s := NewScheduler(mgr, nil, 10*time.Second, serversDir, false, testLogger())
	results := s.ReconcileNow()
	assert.Empty(t, results)
}

func TestReconcile_AutoRepairEnabled(t *testing.T) {
	serversDir := t.TempDir()
	writeFichaFiles(t, serversDir, "svr", "app", map[string]string{
		"manifest.yml": "id: app\nversion: 2.0",
	})

	oldHashes := map[string]string{
		"manifest.yml": "sha256:badbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadb",
	}

	mgr, _ := newTestManagerWithFichas(t, map[string]*state.Ficha{
		"app": {
			Name:    "app",
			Version: "1.0",
			State:   state.StateInstalada,
			Server:  "svr",
			Hashes:  oldHashes,
		},
	})

	mockInst := &mockInstaller{}
	s := NewScheduler(mgr, mockInst, 10*time.Second, serversDir, true, testLogger())
	results := s.ReconcileNow()
	assert.Len(t, results, 1)

	time.Sleep(50 * time.Millisecond)
	assert.Equal(t, 1, mockInst.getRepairCalls())
}

func TestReconcile_AutoRepairDisabled(t *testing.T) {
	serversDir := t.TempDir()
	writeFichaFiles(t, serversDir, "svr", "app", map[string]string{
		"manifest.yml": "id: app\nversion: 2.0",
	})

	oldHashes := map[string]string{
		"manifest.yml": "sha256:badbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadb",
	}

	mgr, _ := newTestManagerWithFichas(t, map[string]*state.Ficha{
		"app": {
			Name:    "app",
			Version: "1.0",
			State:   state.StateInstalada,
			Server:  "svr",
			Hashes:  oldHashes,
		},
	})

	mockInst := &mockInstaller{}
	s := NewScheduler(mgr, mockInst, 10*time.Second, serversDir, false, testLogger())
	results := s.ReconcileNow()
	assert.Len(t, results, 1)

	time.Sleep(50 * time.Millisecond)
	assert.Equal(t, 0, mockInst.getRepairCalls())
}

func TestReconcile_UpdatesStoredHashes(t *testing.T) {
	serversDir := t.TempDir()
	writeFichaFiles(t, serversDir, "svr", "app", map[string]string{
		"manifest.yml": "id: app",
	})

	oldHashes := map[string]string{
		"manifest.yml": "sha256:differenthashdifferenthashdifferenthashdifferentha",
	}

	mgr, _ := newTestManagerWithFichas(t, map[string]*state.Ficha{
		"app": {
			Name:    "app",
			Version: "1.0",
			State:   state.StateInstalada,
			Server:  "svr",
			Hashes:  oldHashes,
		},
	})

	s := NewScheduler(mgr, nil, 10*time.Second, serversDir, false, testLogger())
	s.ReconcileNow()

	st, _ := mgr.Read()
	assert.NotEqual(t, oldHashes["manifest.yml"], st.Fichas["app"].Hashes["manifest.yml"],
		"hashes should update to current after reconcile")
	assert.Len(t, st.Fichas["app"].Hashes["manifest.yml"], 64) // SHA-256 hex is 64 chars
}

func TestReconcile_EmptyStateNoop(t *testing.T) {
	serversDir := t.TempDir()

	mgr, _ := newTestManagerWithFichas(t, map[string]*state.Ficha{})

	s := NewScheduler(mgr, nil, 10*time.Second, serversDir, false, testLogger())
	results := s.ReconcileNow()
	assert.Nil(t, results)
}

// ── Helper: mock installer ────────────────────────────────────

type mockInstaller struct {
	mu          sync.Mutex
	repairCalls int
}

func (m *mockInstaller) Repair(fichaID string) (*installer.SagaResult, error) {
	m.mu.Lock()
	m.repairCalls++
	m.mu.Unlock()
	return &installer.SagaResult{Success: true}, nil
}

func (m *mockInstaller) getRepairCalls() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.repairCalls
}
