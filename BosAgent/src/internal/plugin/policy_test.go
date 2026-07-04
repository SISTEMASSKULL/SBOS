// Package plugin — tests F9.1: parseo de scaling/maintenance/slos del
// manifest.yml (BOS-REPAIR-02 §schema).
package plugin

import (
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"testing"
	"time"
)

const manifestF91 = `identity:
  server: dataserver
  version: 18.4.0

governance:
  auto_install: true

scaling:
  strategy: coordinated
  horizontal:
    min_replicas: 1
    max_replicas: 5
    target_cpu_percent: 70
    target_memory_percent: 80
    scale_up_cooldown: 3m
    scale_down_cooldown: 10m
  vertical:
    mode: recommendation
    min_cpu: "100m"
    max_cpu: "2"
    min_memory: "128Mi"
    max_memory: "4Gi"
    update_policy: on-maintenance
  context_aware:
    enabled: true

maintenance:
  strategy: cordon-drain
  max_unavailable: 1
  drain_timeout: 300s

slos:
  availability: 0.999
  latency_p99_ms: 10
  error_rate_max: 0.001
`

// TestParseManifest_PoliticasF91: el DoD de F9.1 — las tres secciones del
// Operator Soberano se parsean con valores exactos.
func TestParseManifest_PoliticasF91(t *testing.T) {
	dir := t.TempDir()
	ficha := filepath.Join(dir, "srv", "postgresql")
	if err := os.MkdirAll(ficha, 0755); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(ficha, "task_catalog.sh"), []byte("#!/bin/bash\n"), 0755)
	os.WriteFile(filepath.Join(ficha, "manifest.yml"), []byte(manifestF91), 0644)

	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	l := NewLoader(dir, logger)
	if _, err := l.Scan(); err != nil {
		t.Fatal(err)
	}
	m, ok := l.Get("postgresql")
	if !ok {
		t.Fatal("ficha no cargada")
	}

	sc := m.Scaling
	if sc == nil {
		t.Fatal("scaling no parseado")
	}
	if sc.Strategy != "coordinated" || sc.MinReplicas != 1 || sc.MaxReplicas != 5 {
		t.Errorf("horizontal: %+v", sc)
	}
	if sc.TargetCPUPercent != 70 || sc.TargetMemPercent != 80 {
		t.Errorf("umbrales: %+v", sc)
	}
	if sc.ScaleUpCooldown != 3*time.Minute || sc.ScaleDownCool != 10*time.Minute {
		t.Errorf("cooldowns: up=%v down=%v", sc.ScaleUpCooldown, sc.ScaleDownCool)
	}
	if sc.VerticalMode != "recommendation" || sc.MaxMemory != "4Gi" || sc.UpdatePolicy != "on-maintenance" {
		t.Errorf("vertical: %+v", sc)
	}
	if !sc.ContextAware {
		t.Error("context_aware.enabled debe parsearse")
	}

	mt := m.Maintenance
	if mt == nil || mt.Strategy != "cordon-drain" || mt.MaxUnavailable != 1 || mt.DrainTimeout != 300*time.Second {
		t.Errorf("maintenance: %+v", mt)
	}

	slo := m.SLOs
	if slo == nil || slo.Availability != 0.999 || slo.LatencyP99Ms != 10 || slo.ErrorRateMax != 0.001 {
		t.Errorf("slos: %+v", slo)
	}
}

// TestParseManifest_SinPoliticas: un manifest clásico deja las políticas nil
// (compatibilidad con las 22 fichas existentes).
func TestParseManifest_SinPoliticas(t *testing.T) {
	dir := t.TempDir()
	ficha := filepath.Join(dir, "srv", "redis")
	os.MkdirAll(ficha, 0755)
	os.WriteFile(filepath.Join(ficha, "task_catalog.sh"), []byte("#!/bin/bash\n"), 0755)
	os.WriteFile(filepath.Join(ficha, "manifest.yml"),
		[]byte("identity:\n  version: 8.6.2\ngovernance:\n  auto_install: true\n"), 0644)

	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	l := NewLoader(dir, logger)
	l.Scan()
	m, _ := l.Get("redis")
	if m == nil {
		t.Fatal("ficha no cargada")
	}
	if m.Scaling != nil || m.Maintenance != nil || m.SLOs != nil {
		t.Error("sin secciones declaradas las políticas deben ser nil")
	}
	if m.Version != "8.6.2" || !m.AutoInstall {
		t.Error("el parseo clásico no debe romperse")
	}
}
