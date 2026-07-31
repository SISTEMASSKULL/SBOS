package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"bos/internal/reconcile"
	"bos/internal/state"
	"log/slog"
)

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stderr, nil))

	// 1. Create a temporary servers directory with test fichas
	tmpServers, err := os.MkdirTemp("/tmp", "reconcile-test-*")
	if err != nil {
		fmt.Fprintf(os.Stderr, "FATAL: %v\n", err)
		os.Exit(1)
	}
	defer os.RemoveAll(tmpServers)

	// Create test ficha files
	createFicha := func(server, name, manifestContent string) {
		dir := filepath.Join(tmpServers, server, name)
		os.MkdirAll(dir, 0755)
		os.WriteFile(filepath.Join(dir, "manifest.yml"), []byte(manifestContent), 0644)
		os.WriteFile(filepath.Join(dir, "task_catalog.sh"), []byte("#!/bin/bash\necho 'task catalog v1'"), 0644)
		os.WriteFile(filepath.Join(dir, "yaml_engine.yml"), []byte("resources:\n  - name: test"), 0644)
	}

	createFicha("srv", "app-a", "id: app-a\nname: App A\nversion: 1.0.0")
	createFicha("srv", "app-b", "id: app-b\nname: App B\nversion: 1.0.0")

	// 2. Compute initial hashes
	hashesA, _ := reconcile.ComputeHashes(tmpServers, "srv", "app-a")
	hashesB, _ := reconcile.ComputeHashes(tmpServers, "srv", "app-b")

	// 3. Create state manager with both fichas
	statePath := "/tmp/.sbos_reconcile_test.json"
	os.Remove(statePath)

	initial := state.SBOSState{
		Version:  "1.0.0",
		Hostname: "sbos-k8s-test",
		Fichas: map[string]*state.Ficha{
			"app-a": {Name: "app-a", Version: "1.0", State: state.StateInstalled, Server: "srv", Hashes: hashesA},
			"app-b": {Name: "app-b", Version: "1.0", State: state.StateInstalled, Server: "srv", Hashes: hashesB},
		},
		Meta: map[string]string{},
	}
	raw, _ := json.MarshalIndent(initial, "", "  ")
	os.WriteFile(statePath, raw, 0600)

	mgr, err := state.NewManager(statePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "FATAL: %v\n", err)
		os.Exit(1)
	}
	defer mgr.Close()

	// 4. Run reconcile — no drift expected
	fmt.Println("=== Test 1: Sin drift (hashes coinciden) ===")
	s := reconcile.NewScheduler(mgr, nil, 10*time.Second, tmpServers, false, logger)
	results := s.ReconcileNow()
	if len(results) == 0 {
		fmt.Println("  ✓ Sin drift detectado")
	} else {
		fmt.Printf("  ✗ Se detectó drift inesperado: %v\n", results)
	}

	// 5. Modify app-a's manifest (simulate drift)
	fmt.Println()
	fmt.Println("=== Test 2: Drift detectado tras modificar manifest.yml ===")
	dirA := filepath.Join(tmpServers, "srv", "app-a")
	os.WriteFile(filepath.Join(dirA, "manifest.yml"), []byte("id: app-a\nname: App A\nversion: 2.0.0-UPDATED"), 0644)

	results2 := s.ReconcileNow()
	drifted := false
	for _, r := range results2 {
		if r.Ficha == "app-a" && r.Drift {
			fmt.Printf("  ✓ Drift detectado en app-a/%s\n", r.File)
			drifted = true
		}
	}
	if !drifted {
		fmt.Println("  ✗ No se detectó drift en app-a")
	}

	// 6. Verify state transition
	st, _ := mgr.Read()
	fmt.Println()
	fmt.Println("=== Estados post-reconciliación ===")
	for name, f := range st.Fichas {
		fmt.Printf("  %-10s → state=%s health=%s\n", name, f.State, f.HealthStatus)
	}

	if st.Fichas["app-a"].State == state.StateUpdateAvailable {
		fmt.Println("  ✓ app-a en ACTUALIZACION_DISPONIBLE")
	} else {
		fmt.Printf("  ✗ app-a debería estar ACTUALIZACION_DISPONIBLE, está %s\n", st.Fichas["app-a"].State)
	}

	// 7. Run again — no new drift (hashes already updated)
	fmt.Println()
	fmt.Println("=== Test 3: Sin drift tras actualizar hashes ===")
	results3 := s.ReconcileNow()
	if len(results3) == 0 {
		fmt.Println("  ✓ Sin nuevo drift (hashes ya actualizados)")
	} else {
		fmt.Printf("  ✗ Drift inesperado: %v\n", results3)
	}

	fmt.Println()
	fmt.Println("RECONCILE INTEGRATION TEST PASSED")
}
