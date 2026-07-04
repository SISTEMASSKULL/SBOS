// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package scaler implementa el algoritmo anti-death-spiral para el escalado
// de pods en el cluster K8s del SBOS (ADR-004).
//
// # Responsabilidades
//
// Detectar y prevenir el "death spiral": condición donde un nodo degradado
// recibe más carga (porque los demás están ocupados), lo que aumenta su
// degradación hasta que cae por completo, propagando la carga a otros nodos.
//
// El algoritmo actúa en tres momentos:
//  1. Detección: monitorea CPU/memoria de pods y nodos cada 30s.
//  2. Intervención temprana: reduce la carga del nodo degradado ANTES
//     de que alcance el umbral crítico (configurable, por defecto 80%).
//  3. Distribución inteligente: redistribuye pods considerando la capacidad
//     real de los nodos destino (no solo su carga actual).
//
// Expone el método JSON-RPC bos.k8s.scale para invocación manual.
//
// # Fuera de alcance
//
// No implementa autoscaling horizontal de aplicaciones — eso es HPA de K8s.
// No gestiona nodos físicos — solo redistribuye pods entre nodos existentes.
// No modifica configuraciones de pods — solo los mueve.
//
// # Dependencias
//
// internal/paths: para la ruta del kubeconfig.
// internal/observer: recibe señales del loop de observación.
// internal/audit: para registrar cada decisión de scaling.
//
// # Callers principales
//
// internal/server/jsonrpc.go: método bos.k8s.scale.
// internal/observer/loop.go: invocado cuando se detecta nodo degradado.
//
// # Estándares y referencias
//
// BOS-REPAIR-09 — Fase 9: Operator Soberano + VDI.
// ADR-004 — Anti-death-spiral: umbrales, detección, redistribución.
// SBOS-032 — SLOs y SLIs: métricas que disparan el scaling.
//
// # Ejemplo de uso
//
//	sc := scaler.New(k8sClient, cfg)
//	if err := sc.Rebalance(ctx, "nodo-01"); err != nil {
//	    log.Printf("scaler: %v", err)
//	}
package scaler
