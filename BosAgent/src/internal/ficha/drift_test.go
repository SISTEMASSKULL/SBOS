package ficha

import (
	"os"
	"path/filepath"
	"testing"
)

func createTestFichaDir(t *testing.T, base string) (string, map[string]string) {
	t.Helper()
	fichaDir := filepath.Join(base, "test-ficha")
	os.MkdirAll(fichaDir, 0755)

	// Crear archivos declarativos
	manifest := "version: 1.0.0\nserver: S01\n"
	os.WriteFile(filepath.Join(fichaDir, "manifest.yml"), []byte(manifest), 0644)
	os.WriteFile(filepath.Join(fichaDir, "task_catalog.sh"), []byte("#!/bin/bash\necho ok"), 0755)

	// Crear resources/
	resDir := filepath.Join(fichaDir, "resources")
	os.MkdirAll(resDir, 0755)
	os.WriteFile(filepath.Join(resDir, "dashboard.json"), []byte(`{"title":"test"}`), 0644)

	// Calcular hashes esperados
	knownHashes := make(map[string]string)
	for _, f := range []string{"manifest.yml", "task_catalog.sh"} {
		h, _ := fileSHA256(filepath.Join(fichaDir, f))
		knownHashes[f] = h
	}
	h, _ := fileSHA256(filepath.Join(resDir, "dashboard.json"))
	knownHashes["resources/dashboard.json"] = h

	return fichaDir, knownHashes
}

func TestDriftDetector_NoDrift(t *testing.T) {
	dir := t.TempDir()
	fichaDir, knownHashes := createTestFichaDir(t, dir)

	detector := NewDriftDetector(dir, nil)
	report, err := detector.Detect("test-ficha", fichaDir, knownHashes)

	if err != nil {
		t.Fatalf("Detect no debería fallar: %v", err)
	}
	if report.HasDrift {
		t.Error("sin cambios → no debería haber drift")
	}
}

func TestDriftDetector_ChangedFile(t *testing.T) {
	dir := t.TempDir()
	fichaDir, knownHashes := createTestFichaDir(t, dir)

	// Modificar manifest.yml para crear drift
	os.WriteFile(filepath.Join(fichaDir, "manifest.yml"), []byte("version: 2.0.0\nserver: S01\n"), 0644)

	detector := NewDriftDetector(dir, nil)
	report, err := detector.Detect("test-ficha", fichaDir, knownHashes)

	if err != nil {
		t.Fatalf("Detect falló: %v", err)
	}
	if !report.HasDrift {
		t.Error("archivo modificado → DEBE haber drift")
	}

	// Debe haber al menos un item con status "changed"
	found := false
	for _, item := range report.Items {
		if item.Status == DriftChanged && item.Path == "manifest.yml" {
			found = true
			break
		}
	}
	if !found {
		t.Error("manifest.yml debería estar 'changed'")
	}
}

func TestDriftDetector_MissingFile(t *testing.T) {
	dir := t.TempDir()
	fichaDir, knownHashes := createTestFichaDir(t, dir)

	// Eliminar un archivo
	os.Remove(filepath.Join(fichaDir, "manifest.yml"))

	detector := NewDriftDetector(dir, nil)
	report, err := detector.Detect("test-ficha", fichaDir, knownHashes)

	if err != nil {
		t.Fatalf("Detect falló: %v", err)
	}
	if !report.HasDrift {
		t.Error("archivo eliminado → DEBE haber drift")
	}

	found := false
	for _, item := range report.Items {
		if item.Status == DriftMissing && item.Path == "manifest.yml" {
			found = true
			break
		}
	}
	if !found {
		t.Error("manifest.yml debería estar 'missing'")
	}
}

func TestDriftDetector_NewFile(t *testing.T) {
	dir := t.TempDir()
	fichaDir, knownHashes := createTestFichaDir(t, dir)

	// Crear un archivo nuevo no declarado
	os.WriteFile(filepath.Join(fichaDir, "new-config.yml"), []byte("key: value"), 0644)

	detector := NewDriftDetector(dir, nil)
	report, err := detector.Detect("test-ficha", fichaDir, knownHashes)

	if err != nil {
		t.Fatalf("Detect falló: %v", err)
	}
	if !report.HasDrift {
		t.Error("archivo nuevo → DEBE haber drift")
	}

	found := false
	for _, item := range report.Items {
		if item.Status == DriftNew && item.Path == "new-config.yml" {
			found = true
			break
		}
	}
	if !found {
		t.Error("new-config.yml debería estar 'new'")
	}
}

func TestDriftDetector_MissingDirectory(t *testing.T) {
	dir := t.TempDir()
	knownHashes := map[string]string{
		"manifest.yml": "abc123def456",
	}

	detector := NewDriftDetector(dir, nil)
	report, err := detector.Detect("ghost", filepath.Join(dir, "does-not-exist"), knownHashes)

	if err != nil {
		t.Fatalf("Detect falló: %v", err)
	}
	if !report.HasDrift {
		t.Error("directorio inexistente → DEBE haber drift (todo missing)")
	}
	if len(report.Items) != 1 {
		t.Errorf("esperado 1 item missing, obtenido %d", len(report.Items))
	}
	if report.Items[0].Status != DriftMissing {
		t.Errorf("esperado missing, obtenido %s", report.Items[0].Status)
	}
}

func TestDriftDetector_DetectAll(t *testing.T) {
	dir := t.TempDir()

	// Crear 2 fichas
	ficha1Dir, known1 := createTestFichaDir(t, filepath.Join(dir, "ficha1"))
	ficha2Dir, known2 := createTestFichaDir(t, filepath.Join(dir, "ficha2"))

	// Modificar ficha1 para crear drift
	os.WriteFile(filepath.Join(ficha1Dir, "manifest.yml"), []byte("version: 99.0\n"), 0644)

	detector := NewDriftDetector(dir, nil)
	fichas := map[string]DriftInput{
		"ficha1": {FichaID: "ficha1", FichaPath: ficha1Dir, KnownHashes: known1},
		"ficha2": {FichaID: "ficha2", FichaPath: ficha2Dir, KnownHashes: known2},
	}

	summary := detector.DetectAll(fichas)

	if summary.TotalFichas != 2 {
		t.Errorf("esperado 2 fichas, obtenido %d", summary.TotalFichas)
	}
	if summary.DriftedFichas != 1 {
		t.Errorf("esperado 1 con drift, obtenido %d", summary.DriftedFichas)
	}
	if summary.OkFichas != 1 {
		t.Errorf("esperado 1 sin drift, obtenido %d", summary.OkFichas)
	}
}

func TestDriftReport_Summary(t *testing.T) {
	report := &DriftReport{
		FichaID:  "test",
		HasDrift: true,
		Items: []DriftItem{
			{Path: "manifest.yml", Status: DriftChanged, Declared: "aaa", Actual: "bbb"},
			{Path: "task_catalog.sh", Status: DriftOK, Declared: "ccc", Actual: "ccc"},
			{Path: "old.json", Status: DriftMissing, Declared: "ddd", Actual: ""},
		},
	}

	summary := report.DriftSummary()
	if summary == "" {
		t.Error("summary no debe estar vacío")
	}
}

func TestDriftSummaryReport_Text(t *testing.T) {
	// Sin drift
	s := &DriftSummaryReport{TotalFichas: 5, OkFichas: 5, DriftedFichas: 0}
	if s.DriftSummaryText() == "" {
		t.Error("texto no debe estar vacío")
	}

	// Con drift
	s2 := &DriftSummaryReport{TotalFichas: 5, OkFichas: 2, DriftedFichas: 3}
	if s2.DriftSummaryText() == "" {
		t.Error("texto no debe estar vacío")
	}
}
