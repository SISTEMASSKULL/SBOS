// Tests F9.0 — el apagado del daemon no toca el cluster.
// Hallazgo de staging real: la saga drain→kubelet→containerd se ejecutaba
// en cada SIGTERM (systemctl restart bos derribaba el nodo).
package main

import (
	"testing"
)

// TestShutdown_DaemonOnly_NoEjecutaSagaK8s: con fullStack=false y todos los
// subsistemas nil, shutdown retorna sin pánico Y sin invocar la saga del
// orchestrator (orchestrator nil — si la invocara, haría panic).
func TestShutdown_DaemonOnly_NoEjecutaSagaK8s(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("shutdown daemon-only no debe tocar el orchestrator ni entrar en pánico: %v", r)
		}
	}()
	shutdown(nil, nil, nil, nil, nil, false)
}

// TestShutdown_FullStack_GuardaNilOrchestrator: incluso bajo orden full,
// sin orchestrator disponible el apagado degrada sin pánico (arranques
// parciales / config-pending).
func TestShutdown_FullStack_GuardaNilOrchestrator(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("shutdown full con orchestrator nil no debe entrar en pánico: %v", r)
		}
	}()
	shutdown(nil, nil, nil, nil, nil, true)
}
