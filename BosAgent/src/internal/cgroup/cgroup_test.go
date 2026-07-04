// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package cgroup

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestCgroup_IsBareMetal verifica que IsBareMetal retorna true cuando no hay
// ninguna señal de contenedor en ProcRoot (directorio temporal vacío).
func TestCgroup_IsBareMetal(t *testing.T) {
	// No paralelo: modifica ProcRoot
	tmp := t.TempDir()
	orig := ProcRoot
	ProcRoot = tmp
	defer func() { ProcRoot = orig }()

	// ProcRoot vacío: sin .containerenv, sin /run/.containerenv, sin /proc/self/cgroup
	if !IsBareMetal() {
		t.Error("IsBareMetal debería retornar true con ProcRoot vacío (sin señales de contenedor)")
	}
}

// TestCgroup_IsContainer verifica que IsBareMetal retorna false cuando existe
// el archivo .containerenv en ProcRoot (señal canónica de Podman/nspawn).
func TestCgroup_IsContainer(t *testing.T) {
	// No paralelo: modifica ProcRoot
	tmp := t.TempDir()
	orig := ProcRoot
	ProcRoot = tmp
	defer func() { ProcRoot = orig }()

	// Crear .containerenv — señal canónica de contenedor Podman/nspawn
	if err := os.WriteFile(filepath.Join(tmp, ".containerenv"), []byte(""), 0644); err != nil {
		t.Fatal("no se pudo crear .containerenv:", err)
	}

	if IsBareMetal() {
		t.Error("IsBareMetal debería retornar false cuando .containerenv existe")
	}
}

// TestCgroup_IsContainer_RunContainerenv verifica que IsBareMetal retorna false
// cuando existe /run/.containerenv (ruta alternativa usada por algunos runtimes).
func TestCgroup_IsContainer_RunContainerenv(t *testing.T) {
	// No paralelo: modifica ProcRoot
	tmp := t.TempDir()
	orig := ProcRoot
	ProcRoot = tmp
	defer func() { ProcRoot = orig }()

	// Crear /run/.containerenv
	runDir := filepath.Join(tmp, "run")
	if err := os.MkdirAll(runDir, 0755); err != nil {
		t.Fatal("no se pudo crear directorio run:", err)
	}
	if err := os.WriteFile(filepath.Join(runDir, ".containerenv"), []byte(""), 0644); err != nil {
		t.Fatal("no se pudo crear run/.containerenv:", err)
	}

	if IsBareMetal() {
		t.Error("IsBareMetal debería retornar false cuando run/.containerenv existe")
	}
}

// TestCgroup_IsContainer_CgroupDocker verifica que IsBareMetal retorna false
// cuando /proc/self/cgroup contiene la señal "/docker/".
func TestCgroup_IsContainer_CgroupDocker(t *testing.T) {
	// No paralelo: modifica ProcRoot
	tmp := t.TempDir()
	orig := ProcRoot
	ProcRoot = tmp
	defer func() { ProcRoot = orig }()

	// Crear /proc/self/cgroup con señal de Docker
	procDir := filepath.Join(tmp, "proc/self")
	if err := os.MkdirAll(procDir, 0755); err != nil {
		t.Fatal("no se pudo crear proc/self:", err)
	}
	cgroupContent := "12:memory:/docker/abc123\n11:cpu:/docker/abc123\n"
	if err := os.WriteFile(filepath.Join(procDir, "cgroup"), []byte(cgroupContent), 0444); err != nil {
		t.Fatal("no se pudo crear proc/self/cgroup:", err)
	}

	if IsBareMetal() {
		t.Error("IsBareMetal debería retornar false cuando /proc/self/cgroup contiene /docker/")
	}
}

// TestCgroupDelegate_ConfiguraSystemd verifica que ConfigureSystemdDelegate crea
// el drop-in delegate.conf con el contenido correcto ([Service]\nDelegate=yes).
func TestCgroupDelegate_ConfiguraSystemd(t *testing.T) {
	// No paralelo: modifica SystemdDir
	tmp := t.TempDir()
	orig := SystemdDir
	SystemdDir = tmp
	defer func() { SystemdDir = orig }()

	if err := ConfigureSystemdDelegate("bos.service"); err != nil {
		t.Fatalf("ConfigureSystemdDelegate falló: %v", err)
	}

	// Verificar que el archivo existe en la ruta correcta
	dropinPath := filepath.Join(tmp, "bos.service.d", "delegate.conf")
	data, err := os.ReadFile(dropinPath)
	if err != nil {
		t.Fatalf("delegate.conf no fue creado en %s: %v", dropinPath, err)
	}

	// Verificar contenido
	content := string(data)
	if !strings.Contains(content, "[Service]") {
		t.Errorf("delegate.conf no contiene [Service]: %q", content)
	}
	if !strings.Contains(content, "Delegate=yes") {
		t.Errorf("delegate.conf no contiene Delegate=yes: %q", content)
	}
}

// TestCgroupDelegate_ConfiguraSystemd_Idempotente verifica que llamar dos veces
// a ConfigureSystemdDelegate no produce error (es idempotente).
func TestCgroupDelegate_ConfiguraSystemd_Idempotente(t *testing.T) {
	// No paralelo: modifica SystemdDir
	tmp := t.TempDir()
	orig := SystemdDir
	SystemdDir = tmp
	defer func() { SystemdDir = orig }()

	if err := ConfigureSystemdDelegate("bos.service"); err != nil {
		t.Fatalf("primera llamada falló: %v", err)
	}
	if err := ConfigureSystemdDelegate("bos.service"); err != nil {
		t.Fatalf("segunda llamada falló (no idempotente): %v", err)
	}
}

// TestCgroupProbe_RetornaFalseEnDirectorioNormal verifica que Probe retorna false
// cuando se le pasa un directorio temporal (no un cgroup real del kernel).
// Esto documenta el comportamiento esperado en entornos sin cgroup v2 real.
func TestCgroupProbe_RetornaFalseEnDirectorioNormal(t *testing.T) {
	t.Parallel()
	tmp := t.TempDir()

	// Un directorio temporal no es un cgroup real — cgroup.procs no existe
	// y no puede crearse como archivo kernel, por lo que Probe retorna false.
	result := Probe(tmp)
	if result {
		t.Error("Probe debería retornar false con un directorio temporal (no es cgroup real)")
	}
}

// TestDetectContainerMapping_RetornaValoresConsistentes verifica que
// DetectContainerMapping no entra en pánico y retorna valores >= 0.
func TestDetectContainerMapping_RetornaValoresConsistentes(t *testing.T) {
	t.Parallel()
	uid, gid := DetectContainerMapping()
	if uid < 0 {
		t.Errorf("uid no puede ser negativo: %d", uid)
	}
	if gid < 0 {
		t.Errorf("gid no puede ser negativo: %d", gid)
	}
}
