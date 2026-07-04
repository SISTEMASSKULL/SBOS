// Package watchdog — tests F6.14: pre-diagnóstico antes del auto-repair.
// DoD BOS-REPAIR-12 §6.4: TestWatchdog_DiagnosesBeforeRepair.
package watchdog

import (
	"errors"
	"io"
	"log/slog"
	"testing"

	"bos/internal/repair"
)

func wdTest() *UnifiedWatchdog {
	return &UnifiedWatchdog{logger: slog.New(slog.NewTextHandler(io.Discard, nil))}
}

func snapConFallo(ficha string) Snapshot {
	return Snapshot{BOS: []repair.HealthCheck{
		{Name: ficha, Pass: false, Detail: "DEGRADADA"},
		{Name: "redis", Pass: true},
	}}
}

// TestWatchdog_DiagnosesBeforeRepair: el diagnosticador se consulta para
// cada ficha fallida ANTES de permitir el auto-repair.
func TestWatchdog_DiagnosesBeforeRepair(t *testing.T) {
	w := wdTest()
	var consultadas []string
	w.SetDiagnosticador(func(fichaID string) (string, int, error) {
		consultadas = append(consultadas, fichaID)
		return "probe fallando", 3, nil
	})

	if !w.preDiagnosticoPermite(snapConFallo("nextcloud")) {
		t.Fatal("impacto bajo (3 usuarios) debe permitir el auto-repair")
	}
	if len(consultadas) != 1 || consultadas[0] != "nextcloud" {
		t.Errorf("debe diagnosticar SOLO la fallida: %v", consultadas)
	}
}

// TestWatchdog_DefersOnHighImpact: usuarios > umbral → diferir a HITL.
func TestWatchdog_DefersOnHighImpact(t *testing.T) {
	w := wdTest()
	w.SetDiagnosticador(func(string) (string, int, error) {
		return "OOMKilled", UmbralUsuariosAfectados + 10, nil
	})
	if w.preDiagnosticoPermite(snapConFallo("nextcloud")) {
		t.Error("impacto alto debe DIFERIR el auto-repair (HITL)")
	}
}

// TestWatchdog_DiagnosticoFallidoNoBloquea: si el diagnóstico no responde,
// el auto-repair continúa (el diagnóstico es ayuda, no un single point of
// failure de la remediación).
func TestWatchdog_DiagnosticoFallidoNoBloquea(t *testing.T) {
	w := wdTest()
	w.SetDiagnosticador(func(string) (string, int, error) {
		return "", 0, errors.New("query.repair no disponible")
	})
	if !w.preDiagnosticoPermite(snapConFallo("nextcloud")) {
		t.Error("diagnóstico caído no debe bloquear la reparación")
	}
}

// TestWatchdog_SinDiagnosticador: compatibilidad — sin gate inyectado,
// el comportamiento es el histórico (permitir).
func TestWatchdog_SinDiagnosticador(t *testing.T) {
	w := wdTest()
	if !w.preDiagnosticoPermite(snapConFallo("x")) {
		t.Error("sin diagnosticador debe permitir")
	}
}
