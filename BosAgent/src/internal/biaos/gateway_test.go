// Package biaos — tests F10.1: singleton y circuit breaker del Gateway.
package biaos

import (
	"errors"
	"testing"
	"time"
)

// TestGetGateway_Singleton: dos llamadas retornan la misma instancia (o el
// mismo error memorizado) — sync.Once.
func TestGetGateway_Singleton(t *testing.T) {
	g1, e1 := GetGateway()
	g2, e2 := GetGateway()
	if g1 != g2 {
		t.Error("GetGateway debe retornar siempre la misma instancia")
	}
	if (e1 == nil) != (e2 == nil) {
		t.Error("el error de construcción debe memorizarse")
	}
}

// TestBreaker_AbreYRecupera: 3 fallos seguidos abren el circuito; las
// llamadas fallan rápido con ErrCircuitoAbierto; pasado el cooldown vuelve
// a permitir; un éxito resetea el contador.
func TestBreaker_AbreYRecupera(t *testing.T) {
	origMax, origCool := breakerMaxFallos, breakerCooldown
	defer func() { breakerMaxFallos, breakerCooldown = origMax, origCool }()
	breakerMaxFallos = 3
	breakerCooldown = 80 * time.Millisecond

	g := newGatewayParaTest(nil) // client no se usa: probamos permitir/registrar
	fallo := errors.New("backend caído")

	for i := 0; i < 3; i++ {
		if err := g.permitir(); err != nil {
			t.Fatalf("fallo %d: el circuito aún debe permitir: %v", i, err)
		}
		g.registrar(fallo)
	}

	if err := g.permitir(); !errors.Is(err, ErrCircuitoAbierto) {
		t.Fatalf("tras 3 fallos el circuito debe estar abierto, got %v", err)
	}

	time.Sleep(100 * time.Millisecond)
	if err := g.permitir(); err != nil {
		t.Fatalf("pasado el cooldown debe permitir: %v", err)
	}

	// éxito resetea — dos fallos posteriores no abren
	g.registrar(nil)
	g.registrar(fallo)
	g.registrar(fallo)
	if err := g.permitir(); err != nil {
		t.Errorf("2 fallos tras un éxito no abren el circuito: %v", err)
	}
}
