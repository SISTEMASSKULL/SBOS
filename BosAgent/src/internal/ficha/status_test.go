package ficha

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestStatusCollector_Collect(t *testing.T) {
	healthTracker := NewHealthTracker()
	collector := NewStatusCollector(healthTracker, nil, nil)

	input := StatusInput{
		ID:             "postgresql",
		Server:         "S01",
		Version:        "18.4.0",
		Category:       1,
		Criticality:    true,
		State:          "INSTALADA",
		WorkloadType:   "StatefulSet",
		ExecutionOrder: 100,
		Dependencies:   []string{"sbos-bootstrap-k8s"},
		AutoInstall:    true,
		Backend:        "helm",
		Description:    "PostgreSQL 18.4",
		HealthType:     "command",
		InstalledAt:    time.Now(),
		UpdatedAt:      time.Now(),
	}

	detail := collector.Collect(input)

	if detail.ID != "postgresql" {
		t.Errorf("esperado postgresql, obtenido %s", detail.ID)
	}
	if detail.State != "INSTALADA" {
		t.Errorf("esperado INSTALADA, obtenido %s", detail.State)
	}
	if detail.HealthStatus != "healthy" {
		t.Errorf("sin fallos debe ser healthy, obtenido %s", detail.HealthStatus)
	}
	if detail.ConsecutiveFailures != 0 {
		t.Errorf("esperado 0 fallos, obtenido %d", detail.ConsecutiveFailures)
	}
	if detail.Policy != "block_and_alert" {
		t.Errorf("crítica debe ser block_and_alert, obtenido %s", detail.Policy)
	}
}

func TestStatusCollector_DegradedHealth(t *testing.T) {
	healthTracker := NewHealthTracker()
	// Simular 3 fallos
	healthTracker.Record("redis", false, 3)
	healthTracker.Record("redis", false, 3)
	healthTracker.Record("redis", false, 3)

	collector := NewStatusCollector(healthTracker, nil, nil)

	input := StatusInput{
		ID:             "redis",
		State:          "INSTALADA",
		Criticality:    true,
		HealthType:     "command",
	}

	detail := collector.Collect(input)

	if detail.HealthStatus != "down" {
		t.Errorf("3 fallos debe ser down, obtenido %s", detail.HealthStatus)
	}
	if detail.ConsecutiveFailures != 3 {
		t.Errorf("esperado 3 fallos, obtenido %d", detail.ConsecutiveFailures)
	}
}

func TestStatusCollector_OneFailureDegraded(t *testing.T) {
	healthTracker := NewHealthTracker()
	healthTracker.Record("app", false, 3) // 1 fallo

	collector := NewStatusCollector(healthTracker, nil, nil)

	input := StatusInput{
		ID:          "app",
		State:       "INSTALADA",
		Criticality: false,
	}

	detail := collector.Collect(input)

	if detail.HealthStatus != "degraded" {
		t.Errorf("1 fallo debe ser degraded, obtenido %s", detail.HealthStatus)
	}
}

func TestStatusCollector_WithDrift(t *testing.T) {
	dir := t.TempDir()
	fichaDir := filepath.Join(dir, "S01", "drift-test")
	os.MkdirAll(fichaDir, 0755)
	manifest := "version: 2.0.0\nserver: S01\n"
	os.WriteFile(filepath.Join(fichaDir, "manifest.yml"), []byte(manifest), 0644)

	// Known hashes diferentes → drift
	knownHashes := map[string]string{
		"manifest.yml": "abcdef123456",
	}

	driftDetector := NewDriftDetector(dir, nil)
	collector := NewStatusCollector(nil, driftDetector, nil)

	input := StatusInput{
		ID:          "drift-test",
		State:       "INSTALADA",
		FichaPath:   fichaDir,
		KnownHashes: knownHashes,
	}

	detail := collector.Collect(input)

	if !detail.HasDrift {
		t.Error("con drift debe tener HasDrift=true")
	}
	if detail.DriftItems == 0 {
		t.Error("debe tener items de drift")
	}
}

func TestStatusCollector_CollectAll(t *testing.T) {
	collector := NewStatusCollector(nil, nil, nil)

	inputs := []StatusInput{
		{ID: "pg", State: "INSTALADA", Criticality: true},
		{ID: "rd", State: "INSTALADA", Criticality: true},
		{ID: "kc", State: "DEGRADADA", Criticality: true},
		{ID: "ng", State: "INSTALADA", Criticality: false},
		{ID: "vl", State: "PENDIENTE", Criticality: true},
		{ID: "mn", State: "PAUSADA", Criticality: false},
		{ID: "err", State: "ERROR_FISICO", Criticality: true},
	}

	summary := collector.CollectAll(inputs)

	if summary.Total != 7 {
		t.Errorf("esperado 7, obtenido %d", summary.Total)
	}
	if summary.Installed < 2 {
		t.Errorf("esperado ≥2 instaladas, obtenido %d", summary.Installed)
	}
	if summary.Degraded < 1 {
		t.Errorf("esperado ≥1 degradada, obtenido %d", summary.Degraded)
	}
	if summary.Error < 1 {
		t.Errorf("esperado ≥1 error, obtenido %d", summary.Error)
	}
	if summary.Paused < 1 {
		t.Errorf("esperado ≥1 pausada, obtenido %d", summary.Paused)
	}
	if summary.Pending < 1 {
		t.Errorf("esperado ≥1 pendiente, obtenido %d", summary.Pending)
	}
}

func TestFichaStatusDetail_TableRow(t *testing.T) {
	detail := FichaStatusDetail{
		ID:            "postgresql",
		State:         "INSTALADA",
		Version:       "18.4.0",
		HealthStatus:  "healthy",
		HasDrift:      false,
		Policy:        "block_and_alert",
	}

	row := detail.TableRow()
	if len(row) != 7 {
		t.Errorf("esperado 7 columnas, obtenido %d", len(row))
	}
	if row[0] != "postgresql" {
		t.Errorf("col 0 debe ser postgresql, obtenido %s", row[0])
	}
}

func TestFichaStatusDetail_DetailText(t *testing.T) {
	detail := FichaStatusDetail{
		ID:             "postgresql",
		State:          "INSTALADA",
		Version:        "18.4.0",
		Server:         "S01",
		WorkloadType:   "StatefulSet",
		ExecutionOrder: 100,
		Dependencies:   []string{"sbos-bootstrap-k8s"},
		Description:    "PostgreSQL 18.4",
		HealthStatus:   "healthy",
		HealthType:     "command",
		Policy:         "block_and_alert",
		AutoInstall:    true,
		InstalledAt:    time.Now(),
		UpdatedAt:      time.Now(),
	}

	text := detail.DetailText()
	if text == "" {
		t.Error("DetailText no debe estar vacío")
	}
	// Debe contener secciones clave
	if !containsStr(text, "Salud") {
		t.Error("debe tener sección Salud")
	}
	if !containsStr(text, "Drift") {
		t.Error("debe tener sección Drift")
	}
	if !containsStr(text, "Política") {
		t.Error("debe tener sección Política")
	}
}

func TestFichaStatusSummary_SummaryText(t *testing.T) {
	summary := &FichaStatusSummary{
		Total:       10,
		Installed:   5,
		Degraded:    2,
		Error:       1,
		Paused:      0,
		Pending:     2,
		WithDrift:   1,
		Unhealthy:   2,
		GeneratedAt: time.Now(),
	}

	text := summary.SummaryText()
	if text == "" {
		t.Error("SummaryText no debe estar vacío")
	}
}

func containsStr(s, sub string) bool {
	for i := 0; i <= len(s)-len(sub); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
