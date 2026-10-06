// Package capacity — recolector de métricas reales de nodos K8s.
// Implementa la capa 1 de los 4 motores de capacidad (manual 2.02).
//
// Esta es una implementación funcional mínima:
//   - Lee CPU y RAM de cada nodo vía `kubectl top nodes`
//   - Calcula porcentaje de uso promedio del clúster
//   - Emite AdmissionResult (pass/fail) basado en umbrales configurables
//
// Motores pendientes de implementar (manual 2.02 §3-§6):
//   - Forecaster (predicción de tendencia lineal con ventana deslizante)
//   - PolicyEngine (reglas compuestas de umbral con hysteresis)
//   - ActionEngine (escalar/alertar automáticamente vía k8s.Core)
package capacity

import (
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

// NodeMetrics son las métricas en tiempo real de un nodo K8s.
type NodeMetrics struct {
	Name        string
	CPUPct      float64   // porcentaje de uso CPU (0-100)
	RAMPct      float64   // porcentaje de uso RAM (0-100)
	CollectedAt time.Time
}

// ClusterMetrics agrega métricas de todos los nodos del clúster.
type ClusterMetrics struct {
	Nodes       []NodeMetrics
	AvgCPUPct   float64   // promedio CPU de todos los nodos
	AvgRAMPct   float64   // promedio RAM de todos los nodos
	CollectedAt time.Time
}

// Collector recolecta métricas reales de K8s vía kubectl top nodes.
type Collector struct {
	cpuThresholdPct float64 // umbral de alerta CPU (default: 80%)
	ramThresholdPct float64 // umbral de alerta RAM (default: 85%)
}

// NewCollector crea un colector con umbrales conservadores por defecto.
func NewCollector() *Collector {
	return &Collector{cpuThresholdPct: 80.0, ramThresholdPct: 85.0}
}

// WithThresholds configura umbrales personalizados (porcentajes 0-100).
func (c *Collector) WithThresholds(cpuPct, ramPct float64) *Collector {
	c.cpuThresholdPct = cpuPct
	c.ramThresholdPct = ramPct
	return c
}

// Collect ejecuta `kubectl top nodes` y parsea los resultados.
// Retorna error si kubectl no está disponible o si metrics-server no está activo.
func (c *Collector) Collect() (*ClusterMetrics, error) {
	out, err := exec.Command("kubectl", "top", "nodes", "--no-headers").Output()
	if err != nil {
		return nil, fmt.Errorf("capacity.Collect: kubectl top nodes: %w", err)
	}
	return parseKubectlTop(out)
}

// CheckCapacity retorna un AdmissionResult basado en métricas reales del clúster.
// Si metrics es nil (kubectl no disponible), admite con aviso en el motivo.
func (c *Collector) CheckCapacity(metrics *ClusterMetrics) AdmissionResult {
	if metrics == nil || len(metrics.Nodes) == 0 {
		return AdmissionResult{
			Allowed: true,
			Reason:  "métricas K8s no disponibles — admitiendo sin verificación de capacidad",
		}
	}
	if metrics.AvgCPUPct > c.cpuThresholdPct {
		return AdmissionResult{
			Allowed: false,
			Reason: fmt.Sprintf("CPU del clúster en %.1f%% — supera el umbral de %.1f%%",
				metrics.AvgCPUPct, c.cpuThresholdPct),
			Detail: fmt.Sprintf("nodos=%d avg_cpu=%.1f%% umbral=%.1f%%",
				len(metrics.Nodes), metrics.AvgCPUPct, c.cpuThresholdPct),
		}
	}
	if metrics.AvgRAMPct > c.ramThresholdPct {
		return AdmissionResult{
			Allowed: false,
			Reason: fmt.Sprintf("RAM del clúster en %.1f%% — supera el umbral de %.1f%%",
				metrics.AvgRAMPct, c.ramThresholdPct),
			Detail: fmt.Sprintf("nodos=%d avg_ram=%.1f%% umbral=%.1f%%",
				len(metrics.Nodes), metrics.AvgRAMPct, c.ramThresholdPct),
		}
	}
	return AdmissionResult{
		Allowed: true,
		Reason: fmt.Sprintf("capacidad OK — CPU %.1f%% RAM %.1f%% (umbrales: CPU %.1f%% RAM %.1f%%)",
			metrics.AvgCPUPct, metrics.AvgRAMPct, c.cpuThresholdPct, c.ramThresholdPct),
	}
}

// parseKubectlTop parsea la salida de `kubectl top nodes --no-headers`.
// Formato esperado: NAME   CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
func parseKubectlTop(data []byte) (*ClusterMetrics, error) {
	raw := strings.TrimSpace(string(data))
	if raw == "" {
		return &ClusterMetrics{CollectedAt: time.Now()}, nil
	}

	var nodes []NodeMetrics
	for _, line := range strings.Split(raw, "\n") {
		fields := strings.Fields(line)
		if len(fields) < 5 {
			continue
		}
		node := NodeMetrics{Name: fields[0], CollectedAt: time.Now()}

		// Posición 2: CPU% (ej: "12%")
		if v, err := strconv.ParseFloat(strings.TrimSuffix(fields[2], "%"), 64); err == nil {
			node.CPUPct = v
		}
		// Posición 4: MEMORY% (ej: "45%")
		if v, err := strconv.ParseFloat(strings.TrimSuffix(fields[4], "%"), 64); err == nil {
			node.RAMPct = v
		}
		nodes = append(nodes, node)
	}

	metrics := &ClusterMetrics{Nodes: nodes, CollectedAt: time.Now()}
	if len(nodes) > 0 {
		var sumCPU, sumRAM float64
		for _, n := range nodes {
			sumCPU += n.CPUPct
			sumRAM += n.RAMPct
		}
		n := float64(len(nodes))
		metrics.AvgCPUPct = sumCPU / n
		metrics.AvgRAMPct = sumRAM / n
	}
	return metrics, nil
}
