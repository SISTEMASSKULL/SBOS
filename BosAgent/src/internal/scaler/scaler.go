// Package scaler implementa la decisión de escalado coordinado del Operator
// Soberano (F9.3 — BOS-REPAIR-02, ADR-004).
//
// HPA y VPA independientes sobre las mismas métricas producen la "death
// spiral" documentada por Kubernetes upstream: VPA reduce requests → HPA ve
// más utilización relativa → escala réplicas → VPA vuelve a tocar resources.
// Aquí réplicas y resources son UNA decisión única con tres garantías:
//
//  1. Una dimensión por decisión: jamás réplicas y resources a la vez.
//  2. Cooldowns del manifest (scale_up/scale_down) + histéresis: el scale-in
//     exige uso < target/2, no solo < target (sin oscilar en el umbral).
//  3. Mínimos con semántica empresarial: los contextos activos (SBOS-049)
//     elevan min_replicas según las PeakRules del manifest.
//
// El paquete decide; el actuador es internal/k8s (ScaleDeployment /
// SetResources). La auditoría la registra el llamador (A.8.15).
package scaler

import (
	"fmt"
	"time"

	"bos/internal/plugin"
)

// Estado es la observación actual de la ficha sobre la que se decide.
type Estado struct {
	Replicas   int
	CPUPercent int // uso promedio actual vs request
	MemPercent int
	CtxActivos int // sesiones activas del tenant (context-aware)

	UltimoScaleUp   time.Time
	UltimoScaleDown time.Time
}

// Decision es el resultado coordinado. Acción única: réplicas O resources.
type Decision struct {
	Accion         string // "scale-out" | "scale-in" | "none"
	TargetReplicas int
	Motivo         string
}

// Decide produce la decisión coordinada para el estado y la política dados.
// Función pura respecto a now — determinista y testeable.
func Decide(now time.Time, e Estado, p *plugin.ScalingPolicy) Decision {
	none := func(motivo string) Decision {
		return Decision{Accion: "none", TargetReplicas: e.Replicas, Motivo: motivo}
	}
	if p == nil || p.Strategy == "none" || p.Strategy == "" {
		return none("sin política de escalado declarada")
	}
	if p.Strategy == "vertical-only" {
		return none("vertical-only: resources se ajustan en mantenimiento (update_policy)")
	}

	minReplicas := p.MinReplicas
	if minReplicas < 1 {
		minReplicas = 1
	}
	// context-aware: los picos de sesiones elevan el mínimo (SBOS-049)
	if p.ContextAware {
		for _, regla := range p.PeakContexts {
			if e.CtxActivos > regla.ContextsGt && regla.MinReplicas > minReplicas {
				minReplicas = regla.MinReplicas
			}
		}
	}
	maxReplicas := p.MaxReplicas
	if maxReplicas < minReplicas {
		maxReplicas = minReplicas
	}

	// garantizar el mínimo siempre — incluso dentro del cooldown
	if e.Replicas < minReplicas {
		return Decision{Accion: "scale-out", TargetReplicas: minReplicas,
			Motivo: fmt.Sprintf("réplicas %d bajo el mínimo %d (context-aware: %d ctx activos)",
				e.Replicas, minReplicas, e.CtxActivos)}
	}

	targetCPU := p.TargetCPUPercent
	if targetCPU <= 0 {
		targetCPU = 70
	}
	targetMem := p.TargetMemPercent
	if targetMem <= 0 {
		targetMem = 80
	}

	sobreUmbral := e.CPUPercent > targetCPU || e.MemPercent > targetMem
	// histéresis: scale-in solo con uso claramente bajo (mitad del umbral)
	bajoUmbral := e.CPUPercent < targetCPU/2 && e.MemPercent < targetMem/2

	upCooldown := p.ScaleUpCooldown
	if upCooldown == 0 {
		upCooldown = 3 * time.Minute
	}
	downCooldown := p.ScaleDownCool
	if downCooldown == 0 {
		downCooldown = 10 * time.Minute
	}

	switch {
	case sobreUmbral && e.Replicas < maxReplicas:
		if now.Sub(e.UltimoScaleUp) < upCooldown {
			return none("scale-out en cooldown (" + upCooldown.String() + ")")
		}
		return Decision{Accion: "scale-out", TargetReplicas: e.Replicas + 1,
			Motivo: fmt.Sprintf("cpu=%d%% mem=%d%% sobre umbral %d/%d", e.CPUPercent, e.MemPercent, targetCPU, targetMem)}

	case bajoUmbral && e.Replicas > minReplicas:
		if now.Sub(e.UltimoScaleDown) < downCooldown {
			return none("scale-in en cooldown (" + downCooldown.String() + ")")
		}
		// anti-spiral: nunca scale-in inmediatamente después de un scale-out —
		// el nuevo reparto de carga aún no se estabilizó
		if now.Sub(e.UltimoScaleUp) < downCooldown {
			return none("scale-in bloqueado: scale-out reciente sin estabilizar")
		}
		return Decision{Accion: "scale-in", TargetReplicas: e.Replicas - 1,
			Motivo: fmt.Sprintf("cpu=%d%% mem=%d%% bajo histéresis %d/%d", e.CPUPercent, e.MemPercent, targetCPU/2, targetMem/2)}

	default:
		return none("dentro de banda operativa")
	}
}
