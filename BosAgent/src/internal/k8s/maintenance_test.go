// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Tests para CleanOrphanPods y RunMaintenance usando kubectl fake.
package k8s

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// fakeKubectlOrphan instala un kubectl fake que:
//   - "get pods --field-selector=status.phase=Failed" → devuelve 2 pods huérfanos
//   - "get pods --field-selector=status.phase=Unknown" → devuelve 0 pods
//   - "get pods --field-selector=status.phase=Succeeded" → devuelve 0 pods
//   - "delete pod" → exit 0 siempre
func fakeKubectlOrphan(t *testing.T) (logPath string) {
	t.Helper()
	dir := t.TempDir()
	logPath = filepath.Join(dir, "args.log")
	script := `#!/bin/bash
echo "$@" >> "` + logPath + `"
if [[ "$*" == *"status.phase=Failed"* ]]; then
  printf 'sbos-system pod-evicted-1\ndefault pod-oom-2\n'
  exit 0
fi
if [[ "$*" == *"status.phase=Unknown"* ]]; then
  exit 0
fi
if [[ "$*" == *"status.phase=Succeeded"* ]]; then
  exit 0
fi
if [[ "$1" == "delete" ]]; then
  exit 0
fi
exit 0
`
	kubectlPath := filepath.Join(dir, "kubectl")
	if err := os.WriteFile(kubectlPath, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+string(os.PathListSeparator)+os.Getenv("PATH"))
	return logPath
}

// fakeKubectlKubeconfigOrphan igual a fakeKubectlOrphan pero el kubeconfig
// se especifica explícitamente para Core.
func newCoreOrphan(t *testing.T) (*Core, string) {
	t.Helper()
	logPath := fakeKubectlOrphan(t)

	// kubeconfig apunta a un archivo vacío (solo necesita existir para KUBECONFIG)
	kc := filepath.Join(t.TempDir(), "admin.conf")
	if err := os.WriteFile(kc, []byte("# fake"), 0600); err != nil {
		t.Fatal(err)
	}
	c := NewCore(kc, 10*time.Second)
	return c, logPath
}

// ── CleanOrphanPods ───────────────────────────────────────────────────────────

func TestCleanOrphanPods_EliminaPodsFailedYRetornaCuenta(t *testing.T) {
	c, logPath := newCoreOrphan(t)

	n, err := c.CleanOrphanPods()
	if err != nil {
		t.Fatalf("CleanOrphanPods() error: %v", err)
	}
	if n != 2 {
		t.Errorf("CleanOrphanPods() = %d, quería 2 (2 pods Failed)", n)
	}

	// Verificar que se invocó delete para ambos pods
	data, _ := os.ReadFile(logPath)
	log := string(data)
	if !strings.Contains(log, "pod-evicted-1") {
		t.Error("esperaba delete de pod-evicted-1 en args.log")
	}
	if !strings.Contains(log, "pod-oom-2") {
		t.Error("esperaba delete de pod-oom-2 en args.log")
	}
	if !strings.Contains(log, "--force") {
		t.Error("esperaba --force en args de delete")
	}
	if !strings.Contains(log, "--grace-period=0") {
		t.Error("esperaba --grace-period=0 en args de delete")
	}
}

func TestCleanOrphanPods_SinPodsHuerfanos(t *testing.T) {
	dir := t.TempDir()
	script := "#!/bin/bash\nexit 0\n"
	kp := filepath.Join(dir, "kubectl")
	if err := os.WriteFile(kp, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+string(os.PathListSeparator)+os.Getenv("PATH"))

	kc := filepath.Join(t.TempDir(), "admin.conf")
	_ = os.WriteFile(kc, []byte("# fake"), 0600)
	c := NewCore(kc, 5*time.Second)

	n, err := c.CleanOrphanPods()
	if err != nil {
		t.Fatalf("CleanOrphanPods() error: %v", err)
	}
	if n != 0 {
		t.Errorf("CleanOrphanPods() = %d, quería 0 (sin pods huérfanos)", n)
	}
}

func TestCleanOrphanPods_KubectlNoDisponible(t *testing.T) {
	// kubectl no en PATH → retorna (0, nil) silenciosamente
	t.Setenv("PATH", t.TempDir()) // directorio vacío
	kc := filepath.Join(t.TempDir(), "admin.conf")
	_ = os.WriteFile(kc, []byte("# fake"), 0600)
	c := NewCore(kc, 5*time.Second)

	n, _ := c.CleanOrphanPods()
	if n != 0 {
		t.Errorf("esperaba 0 pods sin kubectl, got %d", n)
	}
}

// ── RunMaintenance ────────────────────────────────────────────────────────────

func TestRunMaintenance_ImplementaInterfaz(t *testing.T) {
	c, _ := newCoreOrphan(t)
	n := c.RunMaintenance()
	// Debe retornar >= 0 (número de recursos liberados)
	if n < 0 {
		t.Errorf("RunMaintenance() = %d, debe ser >= 0", n)
	}
}

func TestRunMaintenance_RetornaConteoCorrect(t *testing.T) {
	c, _ := newCoreOrphan(t)
	// El fake devuelve 2 pods Failed
	n := c.RunMaintenance()
	if n != 2 {
		t.Errorf("RunMaintenance() = %d, quería 2", n)
	}
}

// ── splitOutput ───────────────────────────────────────────────────────────────

func TestSplitOutput_LineasVacias(t *testing.T) {
	result := splitOutput("\n\n  \n")
	if len(result) != 0 {
		t.Errorf("splitOutput(solo espacios) = %v, quería []", result)
	}
}

func TestSplitOutput_MultiLinea(t *testing.T) {
	result := splitOutput("ns1/pod1\n  ns2/pod2  \n\nns3/pod3\n")
	if len(result) != 3 {
		t.Errorf("splitOutput = %v, quería 3 elementos", result)
	}
	if result[0] != "ns1/pod1" {
		t.Errorf("result[0] = %q, quería 'ns1/pod1'", result[0])
	}
}
