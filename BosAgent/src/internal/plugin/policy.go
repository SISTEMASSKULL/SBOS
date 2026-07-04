package plugin

// policy.go — F9.1: políticas de escalado, mantenimiento y SLOs del
// manifest.yml (BOS-REPAIR-02 §schema). El bos es el Operator Soberano:
// reconcilia réplicas y resources como UNA decisión coordinada (evita la
// death spiral HPA+VPA documentada por Kubernetes upstream).

import "time"

// ScalingPolicy declara cómo puede escalar una ficha.
type ScalingPolicy struct {
	Strategy string // "coordinated" | "horizontal-only" | "vertical-only" | "none"

	// Horizontal (réplicas)
	MinReplicas      int
	MaxReplicas      int
	TargetCPUPercent int
	TargetMemPercent int
	ScaleUpCooldown  time.Duration
	ScaleDownCool    time.Duration

	// Vertical (resources por pod)
	VerticalMode string // "off" | "recommendation" | "auto"
	MinCPU       string
	MaxCPU       string
	MinMemory    string
	MaxMemory    string
	UpdatePolicy string // "on-maintenance" | "rolling" | "immediate"

	// Context-aware (SBOS-049): mínimos de réplicas según ctx_id activos
	ContextAware bool
	PeakContexts []PeakRule
}

// PeakRule eleva el mínimo de réplicas cuando los contextos activos superan
// el umbral (escalado con semántica empresarial — BOS-REPAIR-02).
type PeakRule struct {
	ContextsGt  int
	MinReplicas int
}

// MaintenancePolicy declara cómo se mantiene una ficha.
type MaintenancePolicy struct {
	Strategy       string // "cordon-drain" | "rolling" | "blue-green"
	MaxUnavailable int
	DrainTimeout   time.Duration
	PreChecks      []string
	PostChecks     []string
}

// SLOPolicy declara los objetivos que el bos debe preservar (error budgets).
type SLOPolicy struct {
	Availability float64 // p.ej. 0.999
	LatencyP99Ms int
	ErrorRateMax float64
}
