// Package metrics — tests F9.7.
// DoD: /metrics expone ≥15 métricas bos_* en text exposition format.
package metrics

import (
	"net/http/httptest"
	"strings"
	"testing"
)

// TestRender_Minimo15Metricas: el DoD de F9.7 — el registro canónico expone
// ≥15 métricas bos_* con sus líneas # TYPE.
func TestRender_Minimo15Metricas(t *testing.T) {
	r := NewRegistry()
	out := r.Render()

	n := 0
	for _, line := range strings.Split(out, "\n") {
		if strings.HasPrefix(line, "bos_") {
			n++
		}
	}
	if n < 15 {
		t.Errorf("DoD: ≥15 métricas bos_, got %d:\n%s", n, out)
	}
	if !strings.Contains(out, "# TYPE bos_rpc_requests_total counter") {
		t.Error("falta el TYPE del contador de requests")
	}
	if !strings.Contains(out, "# TYPE bos_uptime_seconds gauge") {
		t.Error("falta el TYPE del uptime")
	}
}

// TestCountersGaugesYCollector: incrementos atómicos, gauges y collector
// dinámico al momento del scrape.
func TestCountersGaugesYCollector(t *testing.T) {
	r := NewRegistry()
	r.Counter("bos_rpc_requests_total").Inc()
	r.Counter("bos_rpc_requests_total").Add(2)
	r.Gauge("bos_k8s_nodes_ready").Set(1)

	r.RegisterCollector(func(set func(string, int64)) {
		set("bos_fichas_total", 22)
	})

	out := r.Render()
	for _, want := range []string{
		"bos_rpc_requests_total 3",
		"bos_k8s_nodes_ready 1",
		"bos_fichas_total 22",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("falta %q en:\n%s", want, out)
		}
	}

	// métrica inexistente: no-op sin pánico
	r.Counter("no_existe").Inc()
	r.Gauge("no_existe").Set(9)
}

// TestHandler_HTTPOK: el handler sirve el formato con Content-Type correcto.
func TestHandler_HTTPOK(t *testing.T) {
	r := NewRegistry()
	w := httptest.NewRecorder()
	r.Handler().ServeHTTP(w, httptest.NewRequest("GET", "/metrics", nil))

	if w.Code != 200 {
		t.Fatalf("status: %d", w.Code)
	}
	if ct := w.Header().Get("Content-Type"); !strings.Contains(ct, "text/plain") {
		t.Errorf("content-type: %s", ct)
	}
	if !strings.Contains(w.Body.String(), "bos_uptime_seconds") {
		t.Error("cuerpo sin métricas")
	}
}
