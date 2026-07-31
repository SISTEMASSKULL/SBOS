package main

import (
	"encoding/json"
	"fmt"
	"os"
	"time"

	"bos/internal/health"
	"bos/internal/state"
	"bos/internal/paths"
	"log/slog"
)

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stderr, nil))

	statePath := "/etc/bos/.sbos_state_test.json"
	os.Remove(statePath)

	// 1. Write a proper state JSON with fichas that have Server set
	initialState := state.SBOSState{
		Version:  "1.0.0",
		Hostname: "sbos-k8s-test",
		Fichas: map[string]*state.Ficha{
			"test-healthy": {
				Name:    "test-healthy",
				Version: "1.0",
				State:   state.StateInstalled,
				Server:  "testserver",
			},
			"test-degraded": {
				Name:    "test-degraded",
				Version: "1.0",
				State:   state.StateInstalled,
				Server:  "testserver",
			},
			"test-nohealth": {
				Name:    "test-nohealth",
				Version: "1.0",
				State:   state.StateInstalled,
				Server:  "testserver",
			},
			"ollama": {
				Name:    "ollama",
				Version: "0.5",
				State:   state.StateInstalled,
				Server:  "testserver",
			},
			"nonexistent": {
				Name:    "nonexistent",
				Version: "1.0",
				State:   state.StateInstalled,
				Server:  "ghostserver",
			},
		},
		Meta: map[string]string{},
	}
	initialState.UpdatedAt = time.Now()

	raw, err := json.MarshalIndent(initialState, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "FATAL: marshal: %v\n", err)
		os.Exit(1)
	}
	if err := os.WriteFile(statePath, raw, 0600); err != nil {
		fmt.Fprintf(os.Stderr, "FATAL: write state: %v\n", err)
		os.Exit(1)
	}

	// 2. Open state manager
	mgr, err := state.NewManager(statePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "FATAL: open manager: %v\n", err)
		os.Exit(1)
	}
	defer mgr.Close()

	// 3. Create health checker
	serversPath := paths.ServersPath
	checker := health.NewChecker(mgr, 10*time.Second, serversPath, logger)

	// 4. Run 1 — initial health check
	fmt.Println("=== Run 1: First health check ===")
	results1 := checker.CheckNow()
	for name, status := range results1 {
		fmt.Printf("  %-25s → %s\n", name, status)
	}

	// 5. Run 2 — consecutive failures should escalate test-degraded to DOWN
	fmt.Println()
	fmt.Println("=== Run 2: Second health check (degraded→down escalation) ===")
	results2 := checker.CheckNow()

	pass := 0
	fail := 0

	check := func(name string, got, expected health.Status) {
		mark := "✓"
		if got != expected {
			mark = "✗"
			fail++
		} else {
			pass++
		}
		fmt.Printf("  %-25s → %-12s %s (expected %s)\n", name, got, mark, expected)
	}

	check("test-healthy", results2["test-healthy"], health.StatusHealthy)
	check("test-degraded", results2["test-degraded"], health.StatusDown) // 2nd consecutive failure → DOWN
	check("test-nohealth", results2["test-nohealth"], health.StatusUnknown)
	check("ollama", results2["ollama"], health.StatusDegraded) // threshold=3, only 2 failures
	check("nonexistent", results2["nonexistent"], health.StatusUnknown)

	// 6. Verify state updated
	st, _ := mgr.Read()
	fmt.Println()
	fmt.Println("=== Final State Health Statuses ===")
	for name, ficha := range st.Fichas {
		fmt.Printf("  %-25s → health_status=%s\n", name, ficha.HealthStatus)
	}

	// 7. Test ResetCounters
	fmt.Println()
	fmt.Println("=== After ResetCounters + CheckNow (ollama) ===")
	checker.ResetCounters("ollama")
	r3 := checker.CheckNow()
	fmt.Printf("  ollama → %s (counter reset, should be DEGRADED not DOWN)\n", r3["ollama"])

	fmt.Println()
	if fail > 0 {
		fmt.Printf("Pass: %d, Fail: %d — INTEGRATION TEST FAILED\n", pass, fail)
		os.Exit(1)
	}
	fmt.Printf("Pass: %d, Fail: %d — INTEGRATION TEST PASSED\n", pass, fail)
}
