// Package metrics expone las métricas operativas del bos en formato de
// exposición Prometheus (F9.7 — BOS-REPAIR-02; OpenTelemetry/observabilidad
// BOS-REPAIR-12). Sin dependencias externas: el text exposition format es
// estable y trivial de emitir; client_golang llegará si hace falta histograma.
//
// Transporte: listener HTTP SOLO en 127.0.0.1:9090 (las métricas internas
// no se exponen fuera del host — SBOS-050; Prometheus las scrapea local o
// vía node-exporter relabel).
package metrics

import (
	"fmt"
	"net/http"
	"sort"
	"sync"
	"sync/atomic"
	"time"
)

// Counter es un contador monotónico thread-safe.
type Counter struct{ v atomic.Int64 }

// Inc incrementa el contador en 1.
func (c *Counter) Inc() { c.v.Add(1) }

// Add suma n al contador.
func (c *Counter) Add(n int64) { c.v.Add(n) }

// Value retorna el valor actual.
func (c *Counter) Value() int64 { return c.v.Load() }

// Gauge es un valor instantáneo thread-safe.
type Gauge struct{ v atomic.Int64 }

// Set fija el valor del gauge.
func (g *Gauge) Set(n int64) { g.v.Store(n) }

// Value retorna el valor actual.
func (g *Gauge) Value() int64 { return g.v.Load() }

// Registry agrupa las métricas del daemon y las sirve en /metrics.
//
// Thread safety: los contadores/gauges son atómicos; el mapa de métricas es
// inmutable tras NewRegistry; los collectors dinámicos se registran antes
// de Serve (sin mutación concurrente).
type Registry struct {
	inicio time.Time

	counters map[string]*Counter
	gauges   map[string]*Gauge

	mu         sync.RWMutex
	collectors []func(set func(name string, value int64))
}

// Métricas canónicas del daemon (≥15 — DoD F9.7).
var nombresCounters = []string{
	"bos_rpc_requests_total",
	"bos_rpc_errors_total",
	"bos_rpc_unauthorized_total",
	"bos_rpc_timeouts_total",
	"bos_saga_executions_total",
	"bos_saga_failures_total",
	"bos_watchdog_cycles_total",
	"bos_maintenance_sagas_total",
	"bos_k8s_operations_total",
}

var nombresGauges = []string{
	"bos_uptime_seconds",
	"bos_fichas_total",
	"bos_fichas_instaladas",
	"bos_fichas_degradadas",
	"bos_fichas_en_error",
	"bos_fichas_pendientes",
	"bos_ctx_sesiones_activas",
	"bos_k8s_nodes_ready",
	"bos_maintenance_activa",
}

// NewRegistry crea el registro con las métricas canónicas inicializadas.
func NewRegistry() *Registry {
	r := &Registry{
		inicio:   time.Now(),
		counters: make(map[string]*Counter, len(nombresCounters)),
		gauges:   make(map[string]*Gauge, len(nombresGauges)),
	}
	for _, n := range nombresCounters {
		r.counters[n] = &Counter{}
	}
	for _, n := range nombresGauges {
		r.gauges[n] = &Gauge{}
	}
	return r
}

// Counter retorna el contador por nombre (no-op si no existe — robustez).
func (r *Registry) Counter(name string) *Counter {
	if c, ok := r.counters[name]; ok {
		return c
	}
	return &Counter{}
}

// Gauge retorna el gauge por nombre (no-op si no existe).
func (r *Registry) Gauge(name string) *Gauge {
	if g, ok := r.gauges[name]; ok {
		return g
	}
	return &Gauge{}
}

// RegisterCollector añade una función que refresca gauges al momento del
// scrape (p.ej. conteo de fichas desde el STATE_MANAGER). Llamar antes
// de Serve.
func (r *Registry) RegisterCollector(fn func(set func(name string, value int64))) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.collectors = append(r.collectors, fn)
}

// Render produce el cuerpo /metrics en text exposition format.
func (r *Registry) Render() string {
	// refrescar gauges dinámicos
	r.mu.RLock()
	collectors := r.collectors
	r.mu.RUnlock()
	set := func(name string, value int64) { r.Gauge(name).Set(value) }
	for _, fn := range collectors {
		fn(set)
	}
	r.Gauge("bos_uptime_seconds").Set(int64(time.Since(r.inicio).Seconds()))

	out := ""
	cNames := make([]string, 0, len(r.counters))
	for n := range r.counters {
		cNames = append(cNames, n)
	}
	sort.Strings(cNames)
	for _, n := range cNames {
		out += fmt.Sprintf("# TYPE %s counter\n%s %d\n", n, n, r.counters[n].Value())
	}
	gNames := make([]string, 0, len(r.gauges))
	for n := range r.gauges {
		gNames = append(gNames, n)
	}
	sort.Strings(gNames)
	for _, n := range gNames {
		out += fmt.Sprintf("# TYPE %s gauge\n%s %d\n", n, n, r.gauges[n].Value())
	}
	return out
}

// Handler retorna el http.Handler de /metrics.
func (r *Registry) Handler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4")
		fmt.Fprint(w, r.Render())
	})
}

// Serve arranca el listener de métricas en addr (default 127.0.0.1:9090).
// Bloquea — ejecutar como goroutine.
func (r *Registry) Serve(addr string) error {
	if addr == "" {
		addr = "127.0.0.1:9090"
	}
	mux := http.NewServeMux()
	mux.Handle("/metrics", r.Handler())
	srv := &http.Server{Addr: addr, Handler: mux, ReadTimeout: 5 * time.Second}
	return srv.ListenAndServe()
}
