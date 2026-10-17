// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Tests de parseo de requirements: memory_request y cpu_request en manifests.
package plugin

import (
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"testing"
)

// crearManifestReq fabrica un manifest.yml con la sección requirements dada.
func crearManifestReq(t *testing.T, serversDir, id, requirements string) string {
	t.Helper()
	dir := filepath.Join(serversDir, "S01", id)
	if err := os.MkdirAll(dir, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "task_catalog.sh"), []byte("#!/bin/bash\n"), 0755); err != nil {
		t.Fatal(err)
	}
	manifest := "identity:\n  server: S01\n  version: 1.0.0\n" +
		"order:\n  execution_order: 100\n" +
		"governance:\n  auto_install: true\n" +
		requirements
	if err := os.WriteFile(filepath.Join(dir, "manifest.yml"), []byte(manifest), 0644); err != nil {
		t.Fatal(err)
	}
	return dir
}

func nuevoLoader(t *testing.T, serversDir string) *Loader {
	t.Helper()
	l := NewLoader(serversDir, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if _, err := l.Scan(); err != nil {
		t.Fatal(err)
	}
	return l
}

// ── memory_request ────────────────────────────────────────────────────────────

func TestLoader_ParseaMemoryRequest(t *testing.T) {
	dir := t.TempDir()
	crearManifestReq(t, dir, "postgresql",
		"requirements:\n  memory_request: \"512Mi\"\n  dependencies:\n    - sbos-bootstrap-platform\n")

	l := nuevoLoader(t, dir)
	mf, ok := l.Get("postgresql")
	if !ok {
		t.Fatal("ficha postgresql no encontrada")
	}
	if mf.MemoryRequest != "512Mi" {
		t.Errorf("MemoryRequest = %q, quería '512Mi'", mf.MemoryRequest)
	}
	// deps no deben verse afectados
	if len(mf.Dependencies) != 1 || mf.Dependencies[0] != "sbos-bootstrap-platform" {
		t.Errorf("Dependencies = %v, quería ['sbos-bootstrap-platform']", mf.Dependencies)
	}
}

func TestLoader_ParseaMemoryRequestGrande(t *testing.T) {
	dir := t.TempDir()
	crearManifestReq(t, dir, "gitlab",
		"requirements:\n  memory_request: \"2Gi\"\n")

	l := nuevoLoader(t, dir)
	mf, ok := l.Get("gitlab")
	if !ok {
		t.Fatal("ficha gitlab no encontrada")
	}
	if mf.MemoryRequest != "2Gi" {
		t.Errorf("MemoryRequest = %q, quería '2Gi'", mf.MemoryRequest)
	}
}

func TestLoader_ParseaCPURequest(t *testing.T) {
	dir := t.TempDir()
	crearManifestReq(t, dir, "ollama",
		"requirements:\n  memory_request: \"4Gi\"\n  cpu_request: \"2\"\n")

	l := nuevoLoader(t, dir)
	mf, ok := l.Get("ollama")
	if !ok {
		t.Fatal("ficha ollama no encontrada")
	}
	if mf.MemoryRequest != "4Gi" {
		t.Errorf("MemoryRequest = %q, quería '4Gi'", mf.MemoryRequest)
	}
	if mf.CPURequest != "2" {
		t.Errorf("CPURequest = %q, quería '2'", mf.CPURequest)
	}
}

func TestLoader_SinMemoryRequest_CampoVacio(t *testing.T) {
	dir := t.TempDir()
	crearManifestReq(t, dir, "nginx",
		"requirements:\n  dependencies:\n    - kong\n")

	l := nuevoLoader(t, dir)
	mf, ok := l.Get("nginx")
	if !ok {
		t.Fatal("ficha nginx no encontrada")
	}
	if mf.MemoryRequest != "" {
		t.Errorf("MemoryRequest sin declarar debe ser '', got %q", mf.MemoryRequest)
	}
	if mf.CPURequest != "" {
		t.Errorf("CPURequest sin declarar debe ser '', got %q", mf.CPURequest)
	}
}

func TestLoader_MemoryRequestAntesYDespuesDeps(t *testing.T) {
	// memory_request antes de dependencies (orden diferente en el YAML)
	dir := t.TempDir()
	crearManifestReq(t, dir, "keycloak",
		"requirements:\n  memory_request: \"768Mi\"\n  dependencies:\n    - postgresql\n    - redis\n")

	l := nuevoLoader(t, dir)
	mf, ok := l.Get("keycloak")
	if !ok {
		t.Fatal("ficha keycloak no encontrada")
	}
	if mf.MemoryRequest != "768Mi" {
		t.Errorf("MemoryRequest = %q, quería '768Mi'", mf.MemoryRequest)
	}
	if len(mf.Dependencies) != 2 {
		t.Errorf("Dependencies len = %d, quería 2", len(mf.Dependencies))
	}
}

// ── auto_install + MemoryRequest juntos ───────────────────────────────────────

func TestLoader_AutoInstallYMemoryRequestCoexisten(t *testing.T) {
	dir := t.TempDir()
	crearManifestReq(t, dir, "elasticsearch",
		"requirements:\n  memory_request: \"1Gi\"\n")

	l := nuevoLoader(t, dir)
	mf, ok := l.Get("elasticsearch")
	if !ok {
		t.Fatal("ficha elasticsearch no encontrada")
	}
	if !mf.AutoInstall {
		t.Error("AutoInstall debe ser true")
	}
	if mf.MemoryRequest != "1Gi" {
		t.Errorf("MemoryRequest = %q, quería '1Gi'", mf.MemoryRequest)
	}
}
