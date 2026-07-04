package ficha

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDiscover_EmptyDir(t *testing.T) {
	dir := t.TempDir()
	d := NewDiscoverer(dir, nil)

	result, err := d.Discover()
	if err != nil {
		t.Fatalf("Discover no debería fallar en dir vacío: %v", err)
	}
	if result.Total != 0 {
		t.Errorf("esperado 0 fichas, obtenido %d", result.Total)
	}
}

func TestDiscover_SingleValidFicha(t *testing.T) {
	dir := t.TempDir()

	// Crear estructura: servers/S01/postgresql/
	fichaDir := filepath.Join(dir, "S01", "postgresql")
	os.MkdirAll(fichaDir, 0755)

	// Crear task_catalog.sh (obligatorio)
	os.WriteFile(filepath.Join(fichaDir, "task_catalog.sh"), []byte("#!/bin/bash\necho ok"), 0755)

	// Crear manifest.yml (recomendado)
	manifest := `identity:
  id: postgresql
  server: S01
  version: 18.4.0
`
	os.WriteFile(filepath.Join(fichaDir, "manifest.yml"), []byte(manifest), 0644)

	// Crear resources/
	os.MkdirAll(filepath.Join(fichaDir, "resources"), 0755)
	os.WriteFile(filepath.Join(fichaDir, "resources", "dashboard.json"), []byte("{}"), 0644)

	d := NewDiscoverer(dir, nil)
	result, err := d.Discover()
	if err != nil {
		t.Fatalf("Discover falló: %v", err)
	}

	if result.Total != 1 {
		t.Fatalf("esperado 1 ficha, obtenido %d", result.Total)
	}
	if result.New != 1 {
		t.Errorf("esperado 1 nueva, obtenido %d", result.New)
	}

	f := result.Fichas[0]
	if f.ID != "postgresql" {
		t.Errorf("esperado ID postgresql, obtenido %s", f.ID)
	}
	if f.Version != "18.4.0" {
		t.Errorf("esperado version 18.4.0, obtenido %s", f.Version)
	}
	if f.Server != "S01" {
		t.Errorf("esperado server S01, obtenido %s", f.Server)
	}
	if !f.Valid {
		t.Error("ficha debería ser válida")
	}
}

func TestDiscover_MissingManifest_Warning(t *testing.T) {
	dir := t.TempDir()

	fichaDir := filepath.Join(dir, "S01", "redis")
	os.MkdirAll(fichaDir, 0755)
	os.WriteFile(filepath.Join(fichaDir, "task_catalog.sh"), []byte("#!/bin/bash\necho ok"), 0755)
	// No creamos manifest.yml — WARNING esperado

	d := NewDiscoverer(dir, nil)
	result, _ := d.Discover()

	if result.Total != 1 {
		t.Fatalf("esperado 1 ficha, obtenido %d", result.Total)
	}
	f := result.Fichas[0]
	if f.Valid != true {
		t.Error("ficha sin manifest.yml debería ser válida (solo WARNING)")
	}
	if result.Warnings < 1 {
		t.Error("debería haber al menos 1 warning por manifest.yml faltante")
	}
}

func TestDiscover_MissingResources_Warning(t *testing.T) {
	dir := t.TempDir()

	fichaDir := filepath.Join(dir, "S01", "vault")
	os.MkdirAll(fichaDir, 0755)
	os.WriteFile(filepath.Join(fichaDir, "task_catalog.sh"), []byte("#!/bin/bash\necho ok"), 0755)
	os.WriteFile(filepath.Join(fichaDir, "manifest.yml"), []byte("version: 2.0.1"), 0644)
	// No creamos resources/ — WARNING esperado

	d := NewDiscoverer(dir, nil)
	result, _ := d.Discover()

	if result.Total != 1 {
		t.Fatalf("esperado 1 ficha, obtenido %d", result.Total)
	}
	// Debería haber warning por resources/ faltante
	if result.Warnings < 1 {
		t.Error("debería haber warning por resources/ faltante")
	}
}

func TestDiscover_NoTaskCatalog_Skipped(t *testing.T) {
	dir := t.TempDir()

	notAFicha := filepath.Join(dir, "S01", "not-a-ficha")
	os.MkdirAll(notAFicha, 0755)
	os.WriteFile(filepath.Join(notAFicha, "manifest.yml"), []byte("version: 1.0"), 0644)
	// Sin task_catalog.sh — no debe ser detectada como ficha

	d := NewDiscoverer(dir, nil)
	result, _ := d.Discover()

	if result.Total != 0 {
		t.Fatalf("esperado 0 fichas (sin task_catalog.sh no es ficha), obtenido %d", result.Total)
	}
}

func TestDiscover_MultipleServers(t *testing.T) {
	dir := t.TempDir()

	// S01/postgresql
	pg := filepath.Join(dir, "S01", "postgresql")
	os.MkdirAll(pg, 0755)
	os.WriteFile(filepath.Join(pg, "task_catalog.sh"), []byte("echo pg"), 0755)
	os.WriteFile(filepath.Join(pg, "manifest.yml"), []byte("version: 18.4.0\nserver: S01"), 0644)
	os.MkdirAll(filepath.Join(pg, "resources"), 0755)

	// S03/keycloak
	kc := filepath.Join(dir, "S03", "keycloak")
	os.MkdirAll(kc, 0755)
	os.WriteFile(filepath.Join(kc, "task_catalog.sh"), []byte("echo kc"), 0755)
	os.WriteFile(filepath.Join(kc, "manifest.yml"), []byte("version: 26.6.2\nserver: S03"), 0644)
	os.MkdirAll(filepath.Join(kc, "resources"), 0755)

	d := NewDiscoverer(dir, nil)
	result, _ := d.Discover()

	if result.Total != 2 {
		t.Fatalf("esperado 2 fichas, obtenido %d", result.Total)
	}
	if result.Valid != 2 {
		t.Errorf("esperado 2 válidas, obtenido %d", result.Valid)
	}
}

func TestDiscover_IsNewTracking(t *testing.T) {
	dir := t.TempDir()

	fichaDir := filepath.Join(dir, "S01", "postgresql")
	os.MkdirAll(fichaDir, 0755)
	os.WriteFile(filepath.Join(fichaDir, "task_catalog.sh"), []byte("echo ok"), 0755)

	d := NewDiscoverer(dir, nil)

	// Primer scan — todas son nuevas
	result1, _ := d.Discover()
	if result1.Total != 1 || result1.Fichas[0].IsNew != true {
		t.Error("primer scan: la ficha debería ser nueva")
	}

	// Segundo scan — ya no es nueva
	result2, _ := d.Discover()
	if result2.Total != 1 {
		t.Fatalf("segundo scan: esperado 1 ficha, obtenido %d", result2.Total)
	}
	if result2.Fichas[0].IsNew != false {
		t.Error("segundo scan: la ficha NO debería ser nueva")
	}
}

func TestDiscover_ContractStatuses(t *testing.T) {
	dir := t.TempDir()

	fichaDir := filepath.Join(dir, "test-ficha")
	os.MkdirAll(fichaDir, 0755)
	os.WriteFile(filepath.Join(fichaDir, "task_catalog.sh"), []byte("echo ok"), 0755)
	os.WriteFile(filepath.Join(fichaDir, "manifest.yml"), []byte("version: 1.0.0"), 0644)
	os.MkdirAll(filepath.Join(fichaDir, "resources"), 0755)

	d := NewDiscoverer(dir, nil)
	result, _ := d.Discover()

	f := result.Fichas[0]
	// Debe tener 3 contratos: manifest.yml, task_catalog.sh, resources/
	if len(f.Contracts) != 3 {
		t.Fatalf("esperado 3 contratos, obtenido %d", len(f.Contracts))
	}
	for _, c := range f.Contracts {
		if c.Status != ContractOK {
			t.Errorf("contrato %s debería estar OK, está %s", c.Contract, c.Status)
		}
	}
}

func TestGetKnownPaths(t *testing.T) {
	dir := t.TempDir()
	fichaDir := filepath.Join(dir, "S01", "test")
	os.MkdirAll(fichaDir, 0755)
	os.WriteFile(filepath.Join(fichaDir, "task_catalog.sh"), []byte("echo ok"), 0755)

	d := NewDiscoverer(dir, nil)
	d.Discover()

	paths := d.GetKnownPaths()
	if len(paths) != 1 {
		t.Fatalf("esperado 1 path conocido, obtenido %d", len(paths))
	}
	if _, ok := paths["test"]; !ok {
		t.Error("paths debería contener 'test'")
	}
}
