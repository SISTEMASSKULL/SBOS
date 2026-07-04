// Package sagas — tests F10.4.
// DoD: TestSagaEngine_CompensatesOnCrash — el estado persiste y la
// recuperación compensa los pasos completados.
package sagas

import (
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// ejecutorStub registra llamadas y falla los métodos marcados.
type ejecutorStub struct {
	mu       sync.Mutex
	llamadas []string
	fallan   map[string]bool
}

func (s *ejecutorStub) fn(metodo string, _ map[string]interface{}) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.llamadas = append(s.llamadas, metodo)
	if s.fallan[metodo] {
		return errors.New(metodo + " falló")
	}
	return nil
}

func (s *ejecutorStub) registro() []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]string{}, s.llamadas...)
}

func sagaPrueba() Definicion {
	return Definicion{
		Nombre: "node-maintain",
		Pasos: []Paso{
			{ID: "a-cordon", Metodo: "bos.k8s.node.cordon", Compensacion: "bos.k8s.node.uncordon"},
			{ID: "b-drain", Metodo: "bos.k8s.node.drain", DependeDe: []string{"a-cordon"},
				Compensacion: "bos.k8s.node.uncordon"},
			{ID: "c-op", Metodo: "bos.saga.execute", DependeDe: []string{"b-drain"}},
		},
	}
}

// TestSagaEngine_ExitoYOrden: DAG respetado, persistencia escrita.
func TestSagaEngine_ExitoYOrden(t *testing.T) {
	stub := &ejecutorStub{}
	e, err := NewEngine(t.TempDir(), stub.fn)
	if err != nil {
		t.Fatal(err)
	}
	ej, err := e.Ejecutar(sagaPrueba())
	if err != nil || !ej.Exito {
		t.Fatalf("saga: err=%v ej=%+v", err, ej)
	}
	reg := stub.registro()
	if len(reg) != 3 || reg[0] != "bos.k8s.node.cordon" || reg[2] != "bos.saga.execute" {
		t.Errorf("orden DAG: %v", reg)
	}
}

// TestSagaEngine_FalloCompensaInverso: el fallo del paso final compensa
// b y a en orden inverso.
func TestSagaEngine_FalloCompensaInverso(t *testing.T) {
	stub := &ejecutorStub{fallan: map[string]bool{"bos.saga.execute": true}}
	e, _ := NewEngine(t.TempDir(), stub.fn)

	ej, err := e.Ejecutar(sagaPrueba())
	if err == nil || ej.Exito {
		t.Fatal("la saga debe fallar")
	}
	reg := stub.registro()
	// cordon, drain, op(falla), luego compensaciones ×2 (inverso: b, a)
	if len(reg) != 5 || reg[3] != "bos.k8s.node.uncordon" || reg[4] != "bos.k8s.node.uncordon" {
		t.Errorf("compensación inversa: %v", reg)
	}
	if ej.Pasos["a-cordon"].Estado != "compensado" || ej.Pasos["b-drain"].Estado != "compensado" {
		t.Errorf("estados: %+v", ej.Pasos)
	}
}

// TestSagaEngine_OlaParalela: dos pasos sin dependencias corren a la vez.
func TestSagaEngine_OlaParalela(t *testing.T) {
	var simultaneos, max atomic.Int32
	lento := func(metodo string, _ map[string]interface{}) error {
		n := simultaneos.Add(1)
		if n > max.Load() {
			max.Store(n)
		}
		time.Sleep(60 * time.Millisecond)
		simultaneos.Add(-1)
		return nil
	}
	e, _ := NewEngine(t.TempDir(), lento)
	def := Definicion{Nombre: "paralela", Pasos: []Paso{
		{ID: "p1", Metodo: "bos.query.system"},
		{ID: "p2", Metodo: "bos.query.vdi"},
	}}
	if _, err := e.Ejecutar(def); err != nil {
		t.Fatal(err)
	}
	if max.Load() < 2 {
		t.Errorf("pasos independientes deben correr en paralelo: max=%d", max.Load())
	}
}

// TestSagaEngine_CompensatesOnCrash es el DoD de F10.4: una ejecución que
// quedó a medias en disco (el daemon murió tras completar a-cordon y
// b-drain — exactamente lo que persistir() deja al cerrar cada ola) se
// recupera al arrancar: Recuperar compensa los pasos OK en orden inverso.
func TestSagaEngine_CompensatesOnCrash(t *testing.T) {
	dir := t.TempDir()
	def := sagaPrueba()

	// fabricar el estado en disco tal como lo deja un daemon muerto a mitad
	// de saga: a y b en ok (con orden temporal), c pendiente, NO terminada
	t0 := time.Now().UTC()
	aMedias := &Ejecucion{
		ID: "node-maintain-crash-1", Saga: "node-maintain",
		Inicio: t0, Terminada: false,
		Pasos: map[string]*EstadoPaso{
			"a-cordon": {ID: "a-cordon", Estado: "ok", Terminado: t0.Add(time.Second)},
			"b-drain":  {ID: "b-drain", Estado: "ok", Terminado: t0.Add(2 * time.Second)},
			"c-op":     {ID: "c-op", Estado: "pendiente"},
		},
	}
	tmpEngine, _ := NewEngine(dir, func(string, map[string]interface{}) error { return nil })
	tmpEngine.persistir(aMedias)

	// 2ª vida del daemon: Recuperar encuentra la ejecución a medias
	stub2 := &ejecutorStub{}
	e2, _ := NewEngine(dir, stub2.fn)
	recuperadas, err := e2.Recuperar(map[string]Definicion{"node-maintain": def})
	if err != nil {
		t.Fatal(err)
	}
	if len(recuperadas) != 1 {
		t.Fatalf("debe recuperar 1 ejecución a medias, got %d", len(recuperadas))
	}
	reg := stub2.registro()
	if len(reg) != 2 || reg[0] != "bos.k8s.node.uncordon" || reg[1] != "bos.k8s.node.uncordon" {
		t.Errorf("la recuperación debe compensar b y a (inverso): %v", reg)
	}

	// idempotencia: una segunda recuperación no encuentra nada pendiente
	rec2, _ := e2.Recuperar(map[string]Definicion{"node-maintain": def})
	if len(rec2) != 0 {
		t.Errorf("segunda recuperación debe ser vacía: %v", rec2)
	}
}
