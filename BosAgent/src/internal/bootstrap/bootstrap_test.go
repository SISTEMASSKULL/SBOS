// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package bootstrap

import (
	"os"
	"path/filepath"
	"testing"

	"bos/internal/paths"
)

// prepararRootTest crea en root la estructura mínima de archivos y directorios
// para que Setup() no falle por dependencias críticas ausentes.
func prepararRootTest(t *testing.T, root string) {
	t.Helper()
	dirs := []string{
		filepath.Join(root, paths.BinPath),
		filepath.Join(root, paths.CorePath),
		filepath.Join(root, paths.ServersPath),
		filepath.Join(root, paths.KubeDir),
		filepath.Join(root, paths.VarLogBos),
		filepath.Join(root, paths.RunBos),
	}
	for _, d := range dirs {
		if err := os.MkdirAll(d, 0755); err != nil {
			t.Fatal("prepararRootTest MkdirAll:", err)
		}
	}
	archivos := []string{
		filepath.Join(root, paths.BosBin),
		filepath.Join(root, paths.MasterScript),
		filepath.Join(root, paths.TaskCatalog),
		filepath.Join(root, paths.YamlEngine),
		filepath.Join(root, paths.HostSetup),
	}
	for _, f := range archivos {
		if err := os.WriteFile(f, []byte("#!/bin/bash\n# test\n"), 0755); err != nil {
			t.Fatal("prepararRootTest WriteFile:", err)
		}
	}
}

// TestSetup_IdempotentEnSegundaEjecucion verifica que Setup puede ejecutarse
// dos veces seguidas sin error (propiedad de idempotencia).
func TestSetup_IdempotentEnSegundaEjecucion(t *testing.T) {
	t.Parallel()
	root := t.TempDir()
	prepararRootTest(t, root)

	cfg := Config{SysRoot: root}

	if err := Setup(cfg); err != nil {
		t.Fatalf("primera ejecución falló: %v", err)
	}
	if err := Setup(cfg); err != nil {
		t.Fatalf("segunda ejecución falló (no idempotente): %v", err)
	}
}

// TestSetup_ScriptsLegadosNoBloquean verifica que Setup NO retorna error
// cuando los scripts legados están ausentes (F10.B.6 — arquitectura declarativa).
// Los scripts 00_MASTER_INSTALL_SBOS.sh, etc. son legados; su ausencia
// genera log.Warn pero el daemon continúa hacia runConfigPending.
func TestSetup_ScriptsLegadosNoBloquean(t *testing.T) {
	t.Parallel()
	root := t.TempDir()
	// Sin scripts legados — Setup debe continuar sin error
	cfg := Config{SysRoot: root}
	if err := Setup(cfg); err != nil {
		t.Fatalf("Setup no debe bloquearse por scripts legados ausentes: %v", err)
	}
}

// TestVerifyC01_SysctlPresente verifica que VerifyC01 retorna OK cuando
// /etc/sysctl.d/99-sbos-k8s.conf y /data/ existen en SysRoot.
func TestVerifyC01_SysctlPresente(t *testing.T) {
	// No paralelo: modifica la variable de paquete SysRoot
	tmp := t.TempDir()
	orig := SysRoot
	SysRoot = tmp
	defer func() { SysRoot = orig }()

	if err := os.MkdirAll(filepath.Join(tmp, "etc/sysctl.d"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tmp, "etc/sysctl.d/99-sbos-k8s.conf"), []byte(""), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(tmp, "data"), 0755); err != nil {
		t.Fatal(err)
	}

	ok, msg := VerifyC01()
	if !ok {
		t.Errorf("VerifyC01 debería ser OK pero falló: %s", msg)
	}
}

// TestVerifyC02_KubeconfigPresente verifica que VerifyC02 retorna OK cuando
// el kubeconfig está presente en la ruta canónica dentro de SysRoot.
func TestVerifyC02_KubeconfigPresente(t *testing.T) {
	// No paralelo: modifica la variable de paquete SysRoot
	tmp := t.TempDir()
	orig := SysRoot
	SysRoot = tmp
	defer func() { SysRoot = orig }()

	kubedir := filepath.Join(tmp, paths.KubeDir)
	if err := os.MkdirAll(kubedir, 0755); err != nil {
		t.Fatal(err)
	}
	kubeconfig := filepath.Join(tmp, paths.KubeconfigPath)
	if err := os.WriteFile(kubeconfig, []byte("apiVersion: v1\n"), 0600); err != nil {
		t.Fatal(err)
	}

	ok, msg := VerifyC02()
	if !ok {
		t.Errorf("VerifyC02 debería ser OK pero falló: %s", msg)
	}
}

// TestVerifyAll_C01aC08 verifica que VerifyAll retorna exactamente 8 criterios
// y que el criterio C-01 es OK cuando los archivos existen.
func TestVerifyAll_C01aC08(t *testing.T) {
	// No paralelo: modifica SysRoot
	tmp := t.TempDir()
	orig := SysRoot
	SysRoot = tmp
	defer func() { SysRoot = orig }()

	// Crear archivos de C-01
	os.MkdirAll(filepath.Join(tmp, "etc/sysctl.d"), 0755)
	os.WriteFile(filepath.Join(tmp, "etc/sysctl.d/99-sbos-k8s.conf"), []byte(""), 0644)
	os.MkdirAll(filepath.Join(tmp, "data"), 0755)

	results := VerifyAll()
	if len(results) != 8 {
		t.Fatalf("VerifyAll retornó %d resultados; se esperaban 8", len(results))
	}

	// C-01 debe estar OK con los archivos preparados
	if !results[0].OK {
		t.Errorf("C-01 debería ser OK: %s", results[0].Detail)
	}

	// Verificar que todos los criterios tienen ID correcto
	esperados := []string{"C-01", "C-02", "C-03", "C-04", "C-05", "C-06", "C-07", "C-08"}
	for i, r := range results {
		if r.ID != esperados[i] {
			t.Errorf("criterio[%d].ID = %q; se esperaba %q", i, r.ID, esperados[i])
		}
	}
}
