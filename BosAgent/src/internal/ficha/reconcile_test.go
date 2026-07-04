package ficha

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestReconcilePolicy_Defaults(t *testing.T) {
	if DefaultPolicy(true) != PolicyBlockAndAlert {
		t.Error("fichas críticas deben ser block_and_alert")
	}
	if DefaultPolicy(false) != PolicyRecommend {
		t.Error("fichas no críticas deben ser recommend")
	}
}

func TestReconciler_SetAndGetPolicy(t *testing.T) {
	r := NewReconciler(nil, nil, nil, time.Minute, nil)

	// Default policy
	if r.GetPolicy("test") != PolicyRecommend {
		t.Error("default debe ser recommend")
	}

	// Set custom policy
	r.SetPolicy("postgresql", PolicyBlockAndAlert)
	if r.GetPolicy("postgresql") != PolicyBlockAndAlert {
		t.Error("postgresql debe ser block_and_alert")
	}

	r.SetPolicy("nginx", PolicyAutonomous)
	if r.GetPolicy("nginx") != PolicyAutonomous {
		t.Error("nginx debe ser autonomous")
	}
}

func TestReconciler_DecideAction_Autonomous(t *testing.T) {
	r := NewReconciler(nil, nil, nil, time.Minute, nil)

	report := &DriftReport{
		FichaID:  "nginx",
		HasDrift: true,
		Items:    []DriftItem{{Path: "manifest.yml", Status: DriftChanged}},
	}

	action := r.decideAction("nginx", PolicyAutonomous, "drift", report)

	if action.Action != "repair" {
		t.Errorf("autonomous debe ser repair, obtenido %s", action.Action)
	}
	if !action.AutoRepair {
		t.Error("autonomous debe tener AutoRepair=true")
	}
}

func TestReconciler_DecideAction_Recommend(t *testing.T) {
	r := NewReconciler(nil, nil, nil, time.Minute, nil)

	report := &DriftReport{
		FichaID:  "app",
		HasDrift: true,
		Items:    []DriftItem{{Path: "manifest.yml", Status: DriftChanged}},
	}

	action := r.decideAction("app", PolicyRecommend, "drift", report)

	if action.Action != "notify" {
		t.Errorf("recommend debe ser notify, obtenido %s", action.Action)
	}
	if action.AutoRepair {
		t.Error("recommend NO debe tener AutoRepair=true")
	}
}

func TestReconciler_DecideAction_BlockAndAlert(t *testing.T) {
	r := NewReconciler(nil, nil, nil, time.Minute, nil)

	report := &DriftReport{
		FichaID:  "postgresql",
		HasDrift: true,
		Items:    []DriftItem{{Path: "manifest.yml", Status: DriftChanged}},
	}

	action := r.decideAction("postgresql", PolicyBlockAndAlert, "drift", report)

	if action.Action != "block" {
		t.Errorf("block_and_alert debe ser block, obtenido %s", action.Action)
	}
	if action.AutoRepair {
		t.Error("block_and_alert NO debe tener AutoRepair=true")
	}
	if action.Reason == "" {
		t.Error("block debe tener razón")
	}
}

func TestReconciler_ReconcileNow_Integration(t *testing.T) {
	dir := t.TempDir()

	// Crear ficha de prueba
	fichaDir := filepath.Join(dir, "S01", "test-ficha")
	os.MkdirAll(fichaDir, 0755)
	os.WriteFile(filepath.Join(fichaDir, "task_catalog.sh"), []byte("#!/bin/bash\necho ok"), 0755)
	manifest := "version: 1.0.0\nserver: S01\n"
	os.WriteFile(filepath.Join(fichaDir, "manifest.yml"), []byte(manifest), 0644)

	// Calcular hashes
	knownHashes := make(map[string]string)
	h, _ := fileSHA256(filepath.Join(fichaDir, "manifest.yml"))
	knownHashes["manifest.yml"] = h
	h2, _ := fileSHA256(filepath.Join(fichaDir, "task_catalog.sh"))
	knownHashes["task_catalog.sh"] = h2

	// Crear componentes
	drift := NewDriftDetector(dir, nil)
	health := NewHealthChecker(nil, nil)
	r := NewReconciler(drift, health, nil, time.Minute, nil)
	r.SetPolicy("test-ficha", PolicyRecommend)

	fichas := map[string]DriftInput{
		"test-ficha": {FichaID: "test-ficha", FichaPath: fichaDir, KnownHashes: knownHashes},
	}
	healthDefs := map[string]HealthDef{
		"test-ficha": {Type: HealthNone, TimeoutSeconds: 5, FailureThreshold: 3},
	}

	result := r.ReconcileNow(fichas, healthDefs)

	if result.TotalFichas != 1 {
		t.Errorf("esperado 1 ficha, obtenido %d", result.TotalFichas)
	}
	if result.Drifted != 0 {
		t.Errorf("sin drift esperado 0, obtenido %d", result.Drifted)
	}
}

func TestReconciler_DriftTriggersAction(t *testing.T) {
	dir := t.TempDir()

	fichaDir := filepath.Join(dir, "S01", "drift-test")
	os.MkdirAll(fichaDir, 0755)
	os.WriteFile(filepath.Join(fichaDir, "task_catalog.sh"), []byte("#!/bin/bash\necho ok"), 0755)
	os.WriteFile(filepath.Join(fichaDir, "manifest.yml"), []byte("version: 1.0.0"), 0644)

	// Hashes que NO coinciden → drift
	knownHashes := map[string]string{
		"manifest.yml":    "deadbeef0001",
		"task_catalog.sh": "deadbeef0002",
	}

	drift := NewDriftDetector(dir, nil)
	r := NewReconciler(drift, nil, nil, time.Minute, nil)
	r.SetPolicy("drift-test", PolicyAutonomous)

	var capturedAction ReconcileAction
	r.SetObserver(func(a ReconcileAction) {
		capturedAction = a
	})

	fichas := map[string]DriftInput{
		"drift-test": {FichaID: "drift-test", FichaPath: fichaDir, KnownHashes: knownHashes},
	}
	healthDefs := map[string]HealthDef{
		"drift-test": {Type: HealthNone, TimeoutSeconds: 5, FailureThreshold: 3},
	}

	result := r.ReconcileNow(fichas, healthDefs)

	if result.Drifted != 1 {
		t.Errorf("esperado 1 con drift, obtenido %d", result.Drifted)
	}
	if len(result.Actions) != 1 {
		t.Fatalf("esperado 1 acción, obtenido %d", len(result.Actions))
	}
	if result.Actions[0].Action != "repair" {
		t.Errorf("autonomous debe ser repair, obtenido %s", result.Actions[0].Action)
	}
	if capturedAction.FichaID != "drift-test" {
		t.Errorf("observer debe recibir drift-test, recibió %s", capturedAction.FichaID)
	}
}

func TestReconcileResult_Summary(t *testing.T) {
	result := &ReconcileResult{
		CycleID:     "rec-test",
		TotalFichas: 5,
		Drifted:     2,
		Unhealthy:   1,
		Actions: []ReconcileAction{
			{FichaID: "pg", Action: "block", Reason: "drift crítico"},
			{FichaID: "nginx", Action: "repair", Reason: "auto-repair"},
		},
		Duration: 150 * time.Millisecond,
	}

	summary := result.Summary()
	if summary == "" {
		t.Error("summary no debe estar vacío")
	}
}

func TestCountDrifted(t *testing.T) {
	report := &DriftReport{
		Items: []DriftItem{
			{Path: "a", Status: DriftOK},
			{Path: "b", Status: DriftChanged},
			{Path: "c", Status: DriftMissing},
			{Path: "d", Status: DriftOK},
			{Path: "e", Status: DriftNew},
		},
	}

	if n := countDrifted(report); n != 3 {
		t.Errorf("esperado 3 con drift, obtenido %d", n)
	}

	if n := countDrifted(nil); n != 0 {
		t.Errorf("nil debe retornar 0, obtenido %d", n)
	}
}
