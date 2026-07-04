// Package scaler — tests F9.3.
// DoD: TestScaleCoordinated_NoDeathSpiral (go test -race -count=50).
package scaler

import (
	"testing"
	"time"

	"bos/internal/plugin"
)

func politicaTest() *plugin.ScalingPolicy {
	return &plugin.ScalingPolicy{
		Strategy:         "coordinated",
		MinReplicas:      1,
		MaxReplicas:      5,
		TargetCPUPercent: 70,
		TargetMemPercent: 80,
		ScaleUpCooldown:  3 * time.Minute,
		ScaleDownCool:    10 * time.Minute,
	}
}

// TestScaleCoordinated_NoDeathSpiral simula 50 ciclos del escenario que
// produce la death spiral HPA+VPA (carga constante repartida entre las
// réplicas: tras cada scale-out la utilización por pod baja y un autoscaler
// ingenuo haría scale-in inmediato, oscilando para siempre). La decisión
// coordinada debe converger: sin alternancia out→in consecutiva y con un
// número finito de cambios.
func TestScaleCoordinated_NoDeathSpiral(t *testing.T) {
	p := politicaTest()
	now := time.Unix(1_700_000_000, 0)

	const cargaTotal = 300 // % de CPU agregado (constante)
	e := Estado{Replicas: 2}

	cambios := 0
	var ultimaAccion string
	for ciclo := 0; ciclo < 50; ciclo++ {
		now = now.Add(time.Minute)
		e.CPUPercent = cargaTotal / e.Replicas // reparto perfecto de la carga
		e.MemPercent = 50

		d := Decide(now, e, p)

		switch d.Accion {
		case "scale-out":
			if ultimaAccion == "scale-in" {
				t.Fatalf("ciclo %d: alternancia in→out — death spiral", ciclo)
			}
			e.Replicas = d.TargetReplicas
			e.UltimoScaleUp = now
			cambios++
			ultimaAccion = "scale-out"
		case "scale-in":
			if ultimaAccion == "scale-out" {
				t.Fatalf("ciclo %d: alternancia out→in — death spiral", ciclo)
			}
			e.Replicas = d.TargetReplicas
			e.UltimoScaleDown = now
			cambios++
			ultimaAccion = "scale-in"
		}

		if e.Replicas < 1 || e.Replicas > 5 {
			t.Fatalf("ciclo %d: réplicas fuera de límites: %d", ciclo, e.Replicas)
		}
	}

	// con carga total 300% y umbral 70%, el punto estable es 5 réplicas
	// (300/5=60% < 70). El sistema debe haber convergido sin rebotes.
	if e.Replicas != 5 {
		t.Errorf("debe converger a 5 réplicas (300%%/5=60%%<70%%), got %d", e.Replicas)
	}
	if cambios > 4 {
		t.Errorf("convergencia con cambios mínimos: want ≤4 (2→3→4→5), got %d", cambios)
	}
}

// TestDecide_CooldownsEHisteresis: el scale-in respeta histéresis (target/2),
// su cooldown, y nunca sigue inmediatamente a un scale-out.
func TestDecide_CooldownsEHisteresis(t *testing.T) {
	p := politicaTest()
	now := time.Unix(1_700_000_000, 0)

	// uso 50% con umbral 70: NO baja (histéresis pide <35)
	d := Decide(now, Estado{Replicas: 3, CPUPercent: 50, MemPercent: 40}, p)
	if d.Accion != "none" {
		t.Errorf("50%% con umbral 70 está en banda: %+v", d)
	}

	// uso 20% (bajo histéresis) pero scale-out hace 5min → bloqueado
	d = Decide(now, Estado{Replicas: 3, CPUPercent: 20, MemPercent: 20,
		UltimoScaleUp: now.Add(-5 * time.Minute)}, p)
	if d.Accion != "none" {
		t.Errorf("scale-in tras out reciente debe bloquearse: %+v", d)
	}

	// mismo caso con el out ya estabilizado (>10min) → scale-in procede
	d = Decide(now, Estado{Replicas: 3, CPUPercent: 20, MemPercent: 20,
		UltimoScaleUp: now.Add(-15 * time.Minute)}, p)
	if d.Accion != "scale-in" || d.TargetReplicas != 2 {
		t.Errorf("scale-in estabilizado: %+v", d)
	}

	// scale-up en cooldown
	d = Decide(now, Estado{Replicas: 2, CPUPercent: 90,
		UltimoScaleUp: now.Add(-time.Minute)}, p)
	if d.Accion != "none" {
		t.Errorf("scale-out en cooldown 3m: %+v", d)
	}
}

// TestDecide_ContextAware: los picos de sesiones elevan el mínimo aunque
// el uso de CPU sea bajo (semántica empresarial SBOS-049).
func TestDecide_ContextAware(t *testing.T) {
	p := politicaTest()
	p.ContextAware = true
	p.PeakContexts = []plugin.PeakRule{
		{ContextsGt: 100, MinReplicas: 2},
		{ContextsGt: 500, MinReplicas: 3},
	}
	now := time.Unix(1_700_000_000, 0)

	// 600 sesiones activas con 1 réplica y CPU baja → mínimo 3 inmediato
	d := Decide(now, Estado{Replicas: 1, CPUPercent: 10, CtxActivos: 600}, p)
	if d.Accion != "scale-out" || d.TargetReplicas != 3 {
		t.Errorf("peak 600 ctx exige mínimo 3: %+v", d)
	}

	// 50 sesiones: el mínimo base (1) aplica — sin acción
	d = Decide(now, Estado{Replicas: 1, CPUPercent: 10, CtxActivos: 50}, p)
	if d.Accion != "none" {
		t.Errorf("sin pico no se fuerza mínimo: %+v", d)
	}
}

// TestDecide_EstrategiasYLimites: none/vertical-only no actúan; max clamp.
func TestDecide_EstrategiasYLimites(t *testing.T) {
	now := time.Unix(1_700_000_000, 0)

	if d := Decide(now, Estado{Replicas: 1, CPUPercent: 99}, nil); d.Accion != "none" {
		t.Errorf("sin política: %+v", d)
	}
	if d := Decide(now, Estado{Replicas: 1, CPUPercent: 99},
		&plugin.ScalingPolicy{Strategy: "vertical-only"}); d.Accion != "none" {
		t.Errorf("vertical-only no escala réplicas: %+v", d)
	}

	p := politicaTest()
	d := Decide(now, Estado{Replicas: 5, CPUPercent: 99}, p)
	if d.Accion != "none" {
		t.Errorf("en max_replicas no hay scale-out: %+v", d)
	}
}
