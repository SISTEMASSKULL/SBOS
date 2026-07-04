// Package plugin — test F11.2: comentarios YAML inline en manifest.yml.
package plugin

import (
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"testing"
)

func TestStripInlineComment(t *testing.T) {
	cases := map[string]string{
		"postgresql # guacamole_db":    "postgresql",
		"359   # tras nextcloud":       "359",
		`"1.5.5"`:                      `"1.5.5"`,
		"sin-comentario":               "sin-comentario",
		"valor#pegado":                 "valor#pegado", // '#' sin espacio: no es comentario
		"  espacios  ":                 "espacios",
		"vdi.{tenant}.com # ruta kong": "vdi.{tenant}.com",
	}
	for in, want := range cases {
		if got := stripInlineComment(in); got != want {
			t.Errorf("stripInlineComment(%q) = %q, want %q", in, got, want)
		}
	}
}

// TestManifest_DepsConComentarioInline: una ficha cuyo manifest usa
// comentarios inline en las dependencias se parsea correctamente.
func TestManifest_DepsConComentarioInline(t *testing.T) {
	dir := t.TempDir()
	ficha := filepath.Join(dir, "srv", "guaca")
	os.MkdirAll(ficha, 0755)
	os.WriteFile(filepath.Join(ficha, "task_catalog.sh"), []byte("#!/bin/bash\n"), 0755)
	os.WriteFile(filepath.Join(ficha, "manifest.yml"), []byte(
		"identity:\n  version: \"1.5.5\"\norder:\n  execution_order: 359   # tras nextcloud\n"+
			"requirements:\n  dependencies:\n    - postgresql # guacamole_db\n    - keycloak # OIDC\n    - kong\n"), 0644)

	l := NewLoader(dir, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if _, err := l.Scan(); err != nil {
		t.Fatal(err)
	}
	m, _ := l.Get("guaca")
	if m == nil {
		t.Fatal("ficha no cargada")
	}
	want := []string{"postgresql", "keycloak", "kong"}
	if len(m.Dependencies) != 3 {
		t.Fatalf("deps: want 3 limpias, got %v", m.Dependencies)
	}
	for i, d := range m.Dependencies {
		if d != want[i] {
			t.Errorf("dep %d: want %q, got %q", i, want[i], d)
		}
	}
	if m.ExecutionOrder != 359 {
		t.Errorf("order con comentario inline: want 359, got %d", m.ExecutionOrder)
	}
	if m.Version != "1.5.5" {
		t.Errorf("version: %q", m.Version)
	}
}
