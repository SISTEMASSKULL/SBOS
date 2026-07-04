// Package sagas — tests del loader de sagas declarativas (F10.4).
package sagas

import (
	"os"
	"path/filepath"
	"testing"
)

// TestCargarDefiniciones_DelRepo: las sagas de ejemplo del repo parsean con
// pasos, dependencias y compensaciones correctas.
func TestCargarDefiniciones_DelRepo(t *testing.T) {
	defs, err := CargarDefiniciones("../../../docs/biaos/sagas")
	if err != nil {
		t.Fatal(err)
	}
	if len(defs) != 2 {
		t.Fatalf("want 2 sagas (node-maintain, repair-ficha), got %d", len(defs))
	}

	nm, ok := defs["node-maintain"]
	if !ok {
		t.Fatal("node-maintain ausente")
	}
	if len(nm.Pasos) != 4 {
		t.Fatalf("node-maintain: want 4 pasos, got %d", len(nm.Pasos))
	}
	if nm.Pasos[0].ID != "cordon" || nm.Pasos[0].Compensacion != "bos.k8s.node.uncordon" {
		t.Errorf("paso cordon: %+v", nm.Pasos[0])
	}
	if len(nm.Pasos[1].DependeDe) != 1 || nm.Pasos[1].DependeDe[0] != "cordon" {
		t.Errorf("drain debe depender de cordon: %+v", nm.Pasos[1])
	}

	rf := defs["repair-ficha"]
	if len(rf.Pasos) != 3 || rf.Pasos[1].Metodo != "bos.ficha.repair" {
		t.Errorf("repair-ficha: %+v", rf.Pasos)
	}
}

// TestCargarDefiniciones_IgnoraInvalidas: archivos sin nombre o ilegibles
// no rompen la carga del resto.
func TestCargarDefiniciones_IgnoraInvalidas(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "valida.yml"),
		[]byte("nombre: ok\npasos:\n  - id: p1\n    metodo: bos.health.check\n"), 0644)
	os.WriteFile(filepath.Join(dir, "sin-nombre.yml"),
		[]byte("pasos:\n  - id: x\n    metodo: y\n"), 0644)
	os.WriteFile(filepath.Join(dir, "no-yaml.txt"), []byte("hola"), 0644)

	defs, err := CargarDefiniciones(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(defs) != 1 || defs["ok"].Pasos[0].ID != "p1" {
		t.Errorf("solo la válida debe cargar: %+v", defs)
	}
}

// TestSagaDelRepo_EjecutaConElEngine: la saga node-maintain del repo corre
// end-to-end en el motor con un ejecutor stub (integración loader→engine).
func TestSagaDelRepo_EjecutaConElEngine(t *testing.T) {
	defs, err := CargarDefiniciones("../../../docs/biaos/sagas")
	if err != nil {
		t.Fatal(err)
	}
	stub := &ejecutorStub{}
	e, _ := NewEngine(t.TempDir(), stub.fn)
	ej, err := e.Ejecutar(defs["node-maintain"])
	if err != nil || !ej.Exito {
		t.Fatalf("saga del repo: err=%v %+v", err, ej)
	}
	reg := stub.registro()
	if len(reg) != 4 || reg[0] != "bos.k8s.node.cordon" || reg[3] != "bos.k8s.node.uncordon" {
		t.Errorf("orden DAG de la saga real: %v", reg)
	}
}
