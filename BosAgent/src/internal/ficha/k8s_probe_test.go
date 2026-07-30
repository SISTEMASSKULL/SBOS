package ficha

import (
	"os"
	"path/filepath"
	"testing"
)

func writeFile(t *testing.T, dir, name, content string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(dir, name), []byte(content), 0o644); err != nil {
		t.Fatalf("escribir %s: %v", name, err)
	}
}

func TestParseWorkloadInfo_Kubernetes(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "manifest.yml", `
identity:
  id: postgresql
workload:
  type: StatefulSet
  runtime: kubernetes
`)
	writeFile(t, dir, "yaml_engine.yml", `
namespace: sbos-data
`)

	info, err := ParseWorkloadInfo(dir)
	if err != nil {
		t.Fatalf("ParseWorkloadInfo: %v", err)
	}
	if info.FichaID != "postgresql" {
		t.Errorf("FichaID: %q", info.FichaID)
	}
	if info.Kind != "StatefulSet" {
		t.Errorf("Kind: %q", info.Kind)
	}
	if info.Runtime != "kubernetes" {
		t.Errorf("Runtime: %q", info.Runtime)
	}
	if info.Namespace != "sbos-data" {
		t.Errorf("Namespace: %q", info.Namespace)
	}
}

func TestParseWorkloadInfo_SinYamlEngine(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "manifest.yml", `
identity:
  id: bos-preflight
workload:
  type: host
  runtime: host
`)
	// Sin yaml_engine.yml → namespace vacío, no error

	info, err := ParseWorkloadInfo(dir)
	if err != nil {
		t.Fatalf("ParseWorkloadInfo sin yaml_engine: %v", err)
	}
	if info.FichaID != "bos-preflight" {
		t.Errorf("FichaID: %q", info.FichaID)
	}
	if info.Namespace != "" {
		t.Errorf("Namespace debe ser vacío sin yaml_engine: %q", info.Namespace)
	}
}

func TestParseWorkloadInfo_SinManifest(t *testing.T) {
	dir := t.TempDir()
	// Sin manifest.yml → error

	_, err := ParseWorkloadInfo(dir)
	if err == nil {
		t.Error("ParseWorkloadInfo sin manifest.yml debe retornar error")
	}
}

func TestWorkloadInfo_IsKubernetes(t *testing.T) {
	casos := []struct {
		runtime  string
		esperado bool
	}{
		{"kubernetes", true},
		{"Kubernetes", true},
		{"KUBERNETES", true},
		{"host", false},
		{"bare-metal", false},
		{"", false},
	}
	for _, c := range casos {
		w := &WorkloadInfo{Runtime: c.runtime}
		if w.IsKubernetes() != c.esperado {
			t.Errorf("IsKubernetes(%q): esperado %v", c.runtime, c.esperado)
		}
	}
}

func TestWorkloadInfo_CanProbe(t *testing.T) {
	// Completo → CanProbe=true
	w := &WorkloadInfo{
		FichaID:   "postgresql",
		Kind:      "StatefulSet",
		Runtime:   "kubernetes",
		Namespace: "sbos-data",
	}
	if !w.CanProbe() {
		t.Error("workload completo debe poder hacer probe")
	}

	// Sin namespace → false
	w2 := &WorkloadInfo{FichaID: "postgresql", Kind: "StatefulSet", Runtime: "kubernetes"}
	if w2.CanProbe() {
		t.Error("sin namespace no debe poder hacer probe")
	}

	// Sin Kind → false
	w3 := &WorkloadInfo{FichaID: "postgresql", Runtime: "kubernetes", Namespace: "sbos-data"}
	if w3.CanProbe() {
		t.Error("sin Kind no debe poder hacer probe")
	}

	// Runtime host → false (no es kubernetes)
	w4 := &WorkloadInfo{FichaID: "bos", Kind: "host", Runtime: "host", Namespace: "default"}
	if w4.CanProbe() {
		t.Error("runtime host no puede hacer probe K8s")
	}
}

func TestExtractYAMLField_Variantes(t *testing.T) {
	content := `
metadata:
  name: "mi-ficha"
  namespace: 'sbos-ns'
workload:
  type: StatefulSet
  runtime: kubernetes
`
	casos := []struct{ field, esperado string }{
		{"name", "mi-ficha"},
		{"namespace", "sbos-ns"},
		{"type", "StatefulSet"},
		{"runtime", "kubernetes"},
		{"ausente", ""},
	}
	for _, c := range casos {
		got := extractYAMLField(content, c.field)
		if got != c.esperado {
			t.Errorf("extractYAMLField(%q): esperado %q, obtenido %q", c.field, c.esperado, got)
		}
	}
}
