// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package metrics expone el endpoint Prometheus del daemon bos para
// monitoreo de SLOs, SLIs y métricas operacionales (SBOS-032).
//
// # Responsabilidades
//
// Registrar y exponer las métricas del daemon bos en formato Prometheus:
//   - bos_ficha_state: estado actual de cada ficha (gauge por estado).
//   - bos_saga_duration_seconds: duración de cada saga (histograma).
//   - bos_observer_tick_total: contador de ticks del loop de observación.
//   - bos_repair_total: contador de reparaciones por ficha y resultado.
//   - bos_health_status: estado global del daemon (0=degradado, 1=ok).
//
// El endpoint se expone en el puerto 9095 en la interfaz de loopback
// (127.0.0.1:9095/metrics) — nunca en interfaz externa (SBOS-050 P6).
//
// # Fuera de alcance
//
// No recopila métricas de pods K8s — eso es kube-state-metrics.
// No envía métricas por push — usa el modelo pull de Prometheus.
// No define dashboards de Grafana — eso es la ficha de Observabilidad.
//
// # Dependencias
//
// Ninguna dependencia de otros paquetes internos.
// Usa prometheus/client_golang (dependencia externa explícita en go.mod).
//
// # Callers principales
//
// cmd/bos/main.go: arranca el servidor /metrics en goroutine separada.
// internal/installer/saga.go: registra duración de sagas vía Observe().
// internal/observer/loop.go: incrementa bos_observer_tick_total.
//
// # Estándares y referencias
//
// SBOS-032 — SLOs/SLIs del daemon bos: disponibilidad, latencia, error rate.
// BOS-REPAIR-09 — Fase 9: métricas y dashboard Grafana.
// SBOS-050 P6 — Bases de datos y endpoints internos solo en loopback/ClusterIP.
// Prometheus exposition format — https://prometheus.io/docs/instrumenting/exposition_formats/
//
// # Ejemplo de uso
//
//	reg := metrics.NewRegistry()
//	srv := metrics.NewServer(reg, "127.0.0.1:9095")
//	go srv.ListenAndServe()
//	// Desde otro paquete:
//	reg.RecordSaga("ficha.install", "postgresql", duration, nil)
package metrics
