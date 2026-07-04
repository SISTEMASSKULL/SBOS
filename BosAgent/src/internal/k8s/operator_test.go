// Package k8s — tests F9.2: operaciones del Operator Soberano con kubectl
// fake (script en PATH que registra argumentos y responde JSON).
package k8s

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// fakeKubectl instala un kubectl falso en PATH que registra cada invocación
// en args.log y responde según el subcomando.
func fakeKubectl(t *testing.T) (logPath string) {
	t.Helper()
	dir := t.TempDir()
	logPath = filepath.Join(dir, "args.log")
	script := `#!/bin/bash
echo "$@" >> "` + logPath + `"
case "$1" in
  get)
    cat <<'EOF'
{"items":[{"metadata":{"name":"nodo-01"},"spec":{"unschedulable":false},
"status":{"conditions":[{"type":"Ready","status":"True"}],
"nodeInfo":{"kubeletVersion":"v1.32.13"},
"addresses":[{"type":"InternalIP","address":"10.0.0.1"}]}},
{"metadata":{"name":"nodo-02"},"spec":{"unschedulable":true},
"status":{"conditions":[{"type":"Ready","status":"False"}],
"nodeInfo":{"kubeletVersion":"v1.32.13"},
"addresses":[{"type":"InternalIP","address":"10.0.0.2"}]}}]}
EOF
    ;;
  drain) echo "evicting pod x" ;;
  *) echo ok ;;
esac
exit 0
`
	kubectlPath := filepath.Join(dir, "kubectl")
	if err := os.WriteFile(kubectlPath, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+string(os.PathListSeparator)+os.Getenv("PATH"))
	return logPath
}

func ultimaLinea(t *testing.T, logPath string) string {
	t.Helper()
	data, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatalf("kubectl fake no fue invocado: %v", err)
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	return lines[len(lines)-1]
}

// TestGetNodes_ParseaEstado: Ready/schedulable/IP por nodo.
func TestGetNodes_ParseaEstado(t *testing.T) {
	fakeKubectl(t)
	c := NewCore("/tmp/fake-kubeconfig", time.Minute)

	nodes, err := c.GetNodes()
	if err != nil {
		t.Fatal(err)
	}
	if len(nodes) != 2 {
		t.Fatalf("want 2 nodos, got %d", len(nodes))
	}
	if !nodes[0].Ready || !nodes[0].Schedulable || nodes[0].InternalIP != "10.0.0.1" {
		t.Errorf("nodo-01: %+v", nodes[0])
	}
	if nodes[1].Ready || nodes[1].Schedulable {
		t.Errorf("nodo-02 cordonado y NotReady: %+v", nodes[1])
	}
}

// TestCordonUncordon_ArgsExactos: las operaciones reversibles del gate.
func TestCordonUncordon_ArgsExactos(t *testing.T) {
	logPath := fakeKubectl(t)
	c := NewCore("/tmp/fake-kubeconfig", time.Minute)

	if err := c.Cordon("nodo-01"); err != nil {
		t.Fatal(err)
	}
	if got := ultimaLinea(t, logPath); got != "cordon nodo-01" {
		t.Errorf("cordon args: %q", got)
	}
	if err := c.Uncordon("nodo-01"); err != nil {
		t.Fatal(err)
	}
	if got := ultimaLinea(t, logPath); got != "uncordon nodo-01" {
		t.Errorf("uncordon args: %q", got)
	}
	if err := c.Cordon(""); err == nil {
		t.Error("cordon sin nodo debe fallar")
	}
}

// TestDrain_DryRunObligatorioEnArgs: dryRun añade --dry-run=server y las
// salvaguardas (--ignore-daemonsets, grace, timeout) van siempre.
func TestDrain_DryRunObligatorioEnArgs(t *testing.T) {
	logPath := fakeKubectl(t)
	c := NewCore("/tmp/fake-kubeconfig", time.Minute)

	out, err := c.Drain("nodo-01", 90*time.Second, true)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out, "evicting") {
		t.Errorf("drain debe retornar la salida: %q", out)
	}
	args := ultimaLinea(t, logPath)
	for _, frag := range []string{"drain nodo-01", "--ignore-daemonsets",
		"--delete-emptydir-data", "--grace-period=30", "--timeout=1m30s", "--dry-run=server"} {
		if !strings.Contains(args, frag) {
			t.Errorf("drain args sin %q: %q", frag, args)
		}
	}

	// sin dryRun no debe llevar el flag
	_, _ = c.Drain("nodo-01", 0, false)
	if args := ultimaLinea(t, logPath); strings.Contains(args, "dry-run") {
		t.Errorf("drain real no debe llevar dry-run: %q", args)
	}
}

// TestActuadores_ArgsExactos: evict, scale, rollout y resources.
func TestActuadores_ArgsExactos(t *testing.T) {
	logPath := fakeKubectl(t)
	c := NewCore("/tmp/fake-kubeconfig", time.Minute)

	if err := c.EvictPod("sbos-monitoring", "kube-state-metrics-x", 0); err != nil {
		t.Fatal(err)
	}
	if got := ultimaLinea(t, logPath); got != "delete pod kube-state-metrics-x -n sbos-monitoring --grace-period=30" {
		t.Errorf("evict args: %q", got)
	}

	if err := c.ScaleDeployment("sbos-data", "redis", 3); err != nil {
		t.Fatal(err)
	}
	if got := ultimaLinea(t, logPath); got != "scale deployment redis -n sbos-data --replicas=3" {
		t.Errorf("scale args: %q", got)
	}
	if err := c.ScaleDeployment("ns", "d", -1); err == nil {
		t.Error("réplicas negativas deben fallar")
	}

	if _, err := c.RolloutStatus("sbos-data", "redis"); err != nil {
		t.Fatal(err)
	}
	if err := c.RolloutUndo("sbos-data", "redis"); err != nil {
		t.Fatal(err)
	}
	if got := ultimaLinea(t, logPath); got != "rollout undo deployment/redis -n sbos-data" {
		t.Errorf("rollout undo args: %q", got)
	}

	if err := c.SetResources("sbos-data", "redis", "500m", "1Gi"); err != nil {
		t.Fatal(err)
	}
	if got := ultimaLinea(t, logPath); !strings.Contains(got, "--limits=cpu=500m,memory=1Gi") {
		t.Errorf("set resources args: %q", got)
	}
	if err := c.SetResources("ns", "d", "", ""); err == nil {
		t.Error("set resources sin cpu ni memoria debe fallar")
	}
}
