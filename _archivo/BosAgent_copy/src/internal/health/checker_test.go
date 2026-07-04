package health

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"log/slog"

	"bos/internal/state"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// mockRunner simulates shell command execution with configurable responses.
type mockRunner struct {
	exitCodes map[string]int
	execErr   map[string]error
	history   []string
}

func newMockRunner() *mockRunner {
	return &mockRunner{
		exitCodes: make(map[string]int),
		execErr:   make(map[string]error),
	}
}

func (m *mockRunner) addPattern(substr string, exitCode int, err error) {
	m.exitCodes[substr] = exitCode
	m.execErr[substr] = err
}

func (m *mockRunner) Run(_ context.Context, command string) (int, error) {
	m.history = append(m.history, command)
	for substr, code := range m.exitCodes {
		if strings.Contains(command, substr) {
			return code, m.execErr[substr]
		}
	}
	return 0, nil
}

// ── Helpers ─────────────────────────────────────────────────

func tempServersDir(t *testing.T) string {
	t.Helper()
	return t.TempDir()
}

// writeManifestYAML writes a properly formatted YAML manifest.
// The health section is provided as raw string and will be indented automatically.
func writeManifestYAML(t *testing.T, serversDir, server, ficha, healthBlock string) {
	t.Helper()
	dir := filepath.Join(serversDir, server, ficha)
	require.NoError(t, os.MkdirAll(dir, 0755))

	content := "identity:\n  id: " + ficha + "\n  name: " + ficha + "\n\n"
	if healthBlock != "" {
		content += "health:\n" + healthBlock
	}
	require.NoError(t, os.WriteFile(filepath.Join(dir, "manifest.yml"), []byte(content), 0644))
}

// indented returns each line of s prefixed with 2 spaces.
func indented(s string) string {
	lines := strings.Split(strings.TrimSpace(s), "\n")
	for i, l := range lines {
		lines[i] = "  " + l
	}
	return strings.Join(lines, "\n")
}

func newTestChecker(t *testing.T, mgr *state.Manager, serversDir string, runner *mockRunner) *Checker {
	t.Helper()
	logger := slog.New(slog.NewTextHandler(os.Stderr, nil))
	c := newCheckerWithRunner(mgr, 5*time.Second, serversDir, logger, runner)
	t.Cleanup(func() { c.Stop() })
	return c
}

// ── Status constants ────────────────────────────────────────

func TestStatusValues(t *testing.T) {
	assert.Equal(t, Status("HEALTHY"), StatusHealthy)
	assert.Equal(t, Status("DEGRADED"), StatusDegraded)
	assert.Equal(t, Status("DOWN"), StatusDown)
	assert.Equal(t, Status("UNKNOWN"), StatusUnknown)
}

// ── ProbeConfig parsing from YAML manifest ──────────────────

func TestProbeConfig_FullManifest(t *testing.T) {
	serversDir := tempServersDir(t)
	writeManifestYAML(t, serversDir, "identityserver", "keycloak", indented(`
check_command: "curl -sf http://localhost:9000/health/live"
check_interval_seconds: 30
check_timeout_seconds: 10
consecutive_failures_threshold: 3
initial_delay_seconds: 60
`))

	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	require.NoError(t, stateMgr.Transition("keycloak", state.StateInstalando))
	require.NoError(t, stateMgr.Transition("keycloak", state.StateInstalada))

	st, err := stateMgr.Read()
	require.NoError(t, err)
	st.Fichas["keycloak"].Server = "identityserver"

	c := newTestChecker(t, stateMgr, serversDir, newMockRunner())
	probe := c.probeConfig("keycloak", st)
	require.NotNil(t, probe)
	assert.Equal(t, "curl -sf http://localhost:9000/health/live", probe.Command)
	assert.Equal(t, 30, probe.IntervalSeconds)
	assert.Equal(t, 10, probe.TimeoutSeconds)
	assert.Equal(t, 3, probe.ConsecutiveFailuresThresh)
	assert.Equal(t, 60, probe.InitialDelaySeconds)
}

func TestProbeConfig_MissingManifest(t *testing.T) {
	serversDir := tempServersDir(t)
	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	require.NoError(t, stateMgr.Transition("ghost", state.StateInstalando))
	st, _ := stateMgr.Read()
	st.Fichas["ghost"].Server = "identityserver"

	c := newTestChecker(t, stateMgr, serversDir, newMockRunner())
	probe := c.probeConfig("ghost", st)
	assert.Nil(t, probe)
}

func TestProbeConfig_NoHealthSection(t *testing.T) {
	serversDir := tempServersDir(t)
	writeManifestYAML(t, serversDir, "identityserver", "noprobe", "")

	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	require.NoError(t, stateMgr.Transition("noprobe", state.StateInstalando))
	st, _ := stateMgr.Read()
	st.Fichas["noprobe"].Server = "identityserver"

	c := newTestChecker(t, stateMgr, serversDir, newMockRunner())
	probe := c.probeConfig("noprobe", st)
	assert.Nil(t, probe)
}

// ── Health checks via mock ──────────────────────────────────

func TestCheckOne_Healthy(t *testing.T) {
	serversDir := tempServersDir(t)
	writeManifestYAML(t, serversDir, "hostserver", "nginx", indented(`
check_command: "curl -sf http://localhost:8080/health"
check_timeout_seconds: 5
`))

	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	require.NoError(t, stateMgr.Transition("nginx", state.StateInstalando))
	require.NoError(t, stateMgr.Transition("nginx", state.StateInstalada))
	st, _ := stateMgr.Read()
	st.Fichas["nginx"].Server = "hostserver"

	runner := newMockRunner()
	runner.addPattern("curl", 0, nil)

	c := newTestChecker(t, stateMgr, serversDir, runner)
	status := c.checkOne("nginx", st)
	assert.Equal(t, StatusHealthy, status)
}

func TestCheckOne_Degraded(t *testing.T) {
	serversDir := tempServersDir(t)
	writeManifestYAML(t, serversDir, "hostserver", "degraded-svc", indented(`
check_command: "curl -sf http://localhost:8080/health"
check_timeout_seconds: 5
consecutive_failures_threshold: 5
`))

	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	require.NoError(t, stateMgr.Transition("degraded-svc", state.StateInstalando))
	require.NoError(t, stateMgr.Transition("degraded-svc", state.StateInstalada))
	st, _ := stateMgr.Read()
	st.Fichas["degraded-svc"].Server = "hostserver"

	runner := newMockRunner()
	runner.addPattern("curl", 1, nil) // exit code 1 but below threshold (5)

	c := newTestChecker(t, stateMgr, serversDir, runner)
	status := c.checkOne("degraded-svc", st)
	assert.Equal(t, StatusDegraded, status)
	assert.Equal(t, 1, c.failureCounts["degraded-svc"])
}

func TestCheckOne_Down(t *testing.T) {
	serversDir := tempServersDir(t)
	writeManifestYAML(t, serversDir, "hostserver", "down-svc", indented(`
check_command: "curl -sf http://localhost:8080/health"
check_timeout_seconds: 5
consecutive_failures_threshold: 3
`))

	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	require.NoError(t, stateMgr.Transition("down-svc", state.StateInstalando))
	require.NoError(t, stateMgr.Transition("down-svc", state.StateInstalada))
	st, _ := stateMgr.Read()
	st.Fichas["down-svc"].Server = "hostserver"

	runner := newMockRunner()
	runner.addPattern("curl", 1, nil) // always fails

	c := newTestChecker(t, stateMgr, serversDir, runner)

	// 3 consecutive failures → DOWN
	for i := 0; i < 3; i++ {
		status := c.checkOne("down-svc", st)
		if i < 2 {
			assert.Equal(t, StatusDegraded, status, "attempt %d should be degraded", i+1)
		} else {
			assert.Equal(t, StatusDown, status, "attempt %d should be down", i+1)
			assert.Equal(t, 3, c.failureCounts["down-svc"])
		}
	}
}

func TestCheckOne_Recovery(t *testing.T) {
	serversDir := tempServersDir(t)
	writeManifestYAML(t, serversDir, "hostserver", "recover-svc", indented(`
check_command: "echo ok"
check_timeout_seconds: 5
consecutive_failures_threshold: 3
`))

	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	require.NoError(t, stateMgr.Transition("recover-svc", state.StateInstalando))
	require.NoError(t, stateMgr.Transition("recover-svc", state.StateInstalada))
	st, _ := stateMgr.Read()
	st.Fichas["recover-svc"].Server = "hostserver"

	runner := newMockRunner()
	runner.addPattern("echo", 1, nil) // first run fails
	c := newTestChecker(t, stateMgr, serversDir, runner)

	assert.Equal(t, StatusDegraded, c.checkOne("recover-svc", st))
	assert.Equal(t, 1, c.failureCounts["recover-svc"])

	// Second check: success resets counter
	runner.addPattern("echo", 0, nil)
	assert.Equal(t, StatusHealthy, c.checkOne("recover-svc", st))
	assert.Equal(t, 0, c.failureCounts["recover-svc"])
}

func TestCheckOne_UnknownWithoutProbe(t *testing.T) {
	serversDir := tempServersDir(t)
	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	require.NoError(t, stateMgr.Transition("orphan", state.StateInstalando))
	require.NoError(t, stateMgr.Transition("orphan", state.StateInstalada))
	st, _ := stateMgr.Read()
	st.Fichas["orphan"].Server = "unknown-server"

	runner := newMockRunner()
	c := newTestChecker(t, stateMgr, serversDir, runner)
	status := c.checkOne("orphan", st)
	assert.Equal(t, StatusUnknown, status)
}

// ── CheckNow (public sweep) ─────────────────────────────────

func TestCheckNow_SweepsAll(t *testing.T) {
	serversDir := tempServersDir(t)
	writeManifestYAML(t, serversDir, "hostserver", "a", indented(`
check_command: "true"
check_timeout_seconds: 5
`))
	writeManifestYAML(t, serversDir, "hostserver", "b", indented(`
check_command: "false"
check_timeout_seconds: 5
consecutive_failures_threshold: 10
`))

	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	for _, name := range []string{"a", "b"} {
		require.NoError(t, stateMgr.Transition(name, state.StateInstalando))
		require.NoError(t, stateMgr.Transition(name, state.StateInstalada))
	}

	runner := newMockRunner()
	runner.addPattern("true", 0, nil)  // a healthy
	runner.addPattern("false", 1, nil) // b degraded

	c := newTestChecker(t, stateMgr, serversDir, runner)

	// Set server on state — must be done per-checkOne since CheckNow re-reads from disk
	st, _ := stateMgr.Read()
	st.Fichas["a"].Server = "hostserver"
	st.Fichas["b"].Server = "hostserver"

	rA := c.checkOne("a", st)
	rB := c.checkOne("b", st)

	assert.Equal(t, StatusHealthy, rA)
	assert.Equal(t, StatusDegraded, rB)
}

func TestCheckNow_ReadsFreshState(t *testing.T) {
	serversDir := tempServersDir(t)
	writeManifestYAML(t, serversDir, "hostserver", "fresh", indented(`
check_command: "echo ok"
check_timeout_seconds: 5
`))

	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	require.NoError(t, stateMgr.Transition("fresh", state.StateInstalando))
	require.NoError(t, stateMgr.Transition("fresh", state.StateInstalada))

	// Server IS persisted to disk via state meta — but state.Ficha doesn't have Server
	// CheckNow reads from disk, which won't have Server. Verify it returns empty/results.
	runner := newMockRunner()
	runner.addPattern("echo", 0, nil)

	c := newTestChecker(t, stateMgr, serversDir, runner)
	results := c.CheckNow()
	// Fallback scan finds manifest even when Server="" (backward-compat with legacy state files)
	assert.Len(t, results, 1)
	assert.Equal(t, StatusHealthy, results["fresh"])
}

// ── ResetCounters ───────────────────────────────────────────

func TestResetCounters(t *testing.T) {
	serversDir := tempServersDir(t)
	writeManifestYAML(t, serversDir, "hostserver", "reset-me", indented(`
check_command: "curl localhost"
check_timeout_seconds: 5
consecutive_failures_threshold: 5
`))

	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	require.NoError(t, stateMgr.Transition("reset-me", state.StateInstalando))
	require.NoError(t, stateMgr.Transition("reset-me", state.StateInstalada))
	st, _ := stateMgr.Read()
	st.Fichas["reset-me"].Server = "hostserver"

	runner := newMockRunner()
	runner.addPattern("curl", 1, nil)
	c := newTestChecker(t, stateMgr, serversDir, runner)

	c.checkOne("reset-me", st)
	c.checkOne("reset-me", st)
	assert.Equal(t, 2, c.failureCounts["reset-me"])

	c.ResetCounters("reset-me")
	assert.Equal(t, 0, c.failureCounts["reset-me"])
}

// ── Classify helper ─────────────────────────────────────────

func TestClassify(t *testing.T) {
	tests := []struct {
		name             string
		podReady         bool
		endpointResponds bool
		stateCoherent    bool
		expected         Status
	}{
		{"healthy", true, true, true, StatusHealthy},
		{"degraded", true, false, true, StatusDegraded},
		{"down", false, false, true, StatusDown},
		{"pod_down_endpoint_responds", false, true, true, StatusDown},
		{"incoherent", true, true, false, StatusUnknown},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			s := Classify(tc.podReady, tc.endpointResponds, tc.stateCoherent)
			assert.Equal(t, tc.expected, s)
		})
	}
}

// ── Summary helper ──────────────────────────────────────────

func TestSummary(t *testing.T) {
	s := Summary(map[string]string{"a": "HEALTHY", "b": "HEALTHY", "c": "DEGRADED", "d": "DOWN"})
	assert.Contains(t, s, "2 healthy")
	assert.Contains(t, s, "1 degraded")
	assert.Contains(t, s, "1 down")
}

func TestSummary_Empty(t *testing.T) {
	s := Summary(map[string]string{})
	assert.Contains(t, s, "0 healthy")
	assert.Contains(t, s, "0 unknown")
}

// ── Stop / Run lifecycle ────────────────────────────────────

func TestChecker_Stop(t *testing.T) {
	serversDir := tempServersDir(t)
	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	runner := newMockRunner()
	c := newTestChecker(t, stateMgr, serversDir, runner)

	go c.Run()
	time.Sleep(50 * time.Millisecond)
	c.Stop()

	c.mu.Lock()
	assert.False(t, c.running)
	c.mu.Unlock()
}

// ── Command timeout ─────────────────────────────────────────

func TestCheckOne_Timeout(t *testing.T) {
	serversDir := tempServersDir(t)
	writeManifestYAML(t, serversDir, "hostserver", "slow-svc", indented(`
check_command: "sleep 60"
check_timeout_seconds: 1
`))

	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	require.NoError(t, stateMgr.Transition("slow-svc", state.StateInstalando))
	require.NoError(t, stateMgr.Transition("slow-svc", state.StateInstalada))
	st, _ := stateMgr.Read()
	st.Fichas["slow-svc"].Server = "hostserver"

	runner := newMockRunner()
	runner.addPattern("sleep", -1, context.DeadlineExceeded)

	c := newTestChecker(t, stateMgr, serversDir, runner)
	status := c.checkOne("slow-svc", st)
	assert.Equal(t, StatusUnknown, status)
}

// ── Default timeout (no config) ─────────────────────────────

func TestCheckOne_DefaultTimeout(t *testing.T) {
	serversDir := tempServersDir(t)
	writeManifestYAML(t, serversDir, "hostserver", "def-svc", indented(`
check_command: "echo ok"
`))

	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	require.NoError(t, stateMgr.Transition("def-svc", state.StateInstalando))
	require.NoError(t, stateMgr.Transition("def-svc", state.StateInstalada))
	st, _ := stateMgr.Read()
	st.Fichas["def-svc"].Server = "hostserver"

	runner := newMockRunner()
	runner.addPattern("echo", 0, nil)

	c := newTestChecker(t, stateMgr, serversDir, runner)
	status := c.checkOne("def-svc", st)
	assert.Equal(t, StatusHealthy, status)
}

// ── Default threshold (no config) ───────────────────────────

func TestCheckOne_DefaultThreshold(t *testing.T) {
	serversDir := tempServersDir(t)
	writeManifestYAML(t, serversDir, "hostserver", "def-thresh", indented(`
check_command: "false"
`))

	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)
	defer stateMgr.Close()

	require.NoError(t, stateMgr.Transition("def-thresh", state.StateInstalando))
	require.NoError(t, stateMgr.Transition("def-thresh", state.StateInstalada))
	st, _ := stateMgr.Read()
	st.Fichas["def-thresh"].Server = "hostserver"

	runner := newMockRunner()
	runner.addPattern("false", 1, nil)

	c := newTestChecker(t, stateMgr, serversDir, runner)

	// Default threshold is 3, so first 2 failures should be DEGRADED
	assert.Equal(t, StatusDegraded, c.checkOne("def-thresh", st))
	assert.Equal(t, StatusDegraded, c.checkOne("def-thresh", st))
	assert.Equal(t, StatusDown, c.checkOne("def-thresh", st))
}

// ── State read error in checkAll ────────────────────────────

func TestCheckAll_ReadErrorReturnsEmpty(t *testing.T) {
	serversDir := tempServersDir(t)
	statePath := filepath.Join(t.TempDir(), ".sbos_state.json")
	stateMgr, err := state.NewManager(statePath)
	require.NoError(t, err)

	runner := newMockRunner()
	c := newTestChecker(t, stateMgr, serversDir, runner)

	stateMgr.Close()

	results := c.CheckNow()
	assert.Empty(t, results)
}
