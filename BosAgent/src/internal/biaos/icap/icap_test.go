// Package icap — tests F10.3.
// DoD ancla de BOS-REPAIR-10: TestICAPEngine_NeverGeneratesCommands —
// toda propuesta sale del catálogo declarativo, jamás texto libre.
package icap

import (
	"os"
	"path/filepath"
	"testing"
)

const catalogoTest = `version: "1.0"
acciones:
  - id: query_system_status
    descripcion: "Estado completo del servidor: Ubuntu, K8s, fichas"
    metodo_rpc: bos.query.system
    parametros: []
    riesgo: bajo
    confirmacion_requerida: false
    contextos_relevantes: [diagnostico, salud, estado]

  - id: restart_pod
    descripcion: "Reinicio controlado de un pod"
    metodo_rpc: bos.k8s.pod.restart
    parametros: [namespace, pod]
    riesgo: medio
    confirmacion_requerida: true
    contextos_relevantes: [CrashLoopBackOff, reiniciar, pod]

  - id: drain_nodo
    descripcion: "Evacuar pods de un nodo"
    metodo_rpc: bos.k8s.node.drain
    parametros: [node, dry_run]
    riesgo: alto
    confirmacion_requerida: true
    contextos_relevantes: [evacuar, drain, mantenimiento]
    compensacion: bos.k8s.node.uncordon
    advertencia: "En single-node un drain real deja el cluster sin capacidad"
`

func catalogoDePrueba(t *testing.T) *Catalogo {
	t.Helper()
	path := filepath.Join(t.TempDir(), "catalog.yml")
	if err := os.WriteFile(path, []byte(catalogoTest), 0644); err != nil {
		t.Fatal(err)
	}
	c, err := CargarCatalogo(path, nil) // sin embeddings → términos
	if err != nil {
		t.Fatal(err)
	}
	return c
}

// TestCargarCatalogo_ParseoCompleto: campos, listas inline y compensación.
func TestCargarCatalogo_ParseoCompleto(t *testing.T) {
	c := catalogoDePrueba(t)
	if len(c.Acciones) != 3 {
		t.Fatalf("want 3 acciones, got %d", len(c.Acciones))
	}
	drain, ok := c.Get("drain_nodo")
	if !ok {
		t.Fatal("drain_nodo ausente")
	}
	if drain.MetodoRPC != "bos.k8s.node.drain" || drain.Riesgo != "alto" || !drain.Confirmacion {
		t.Errorf("drain: %+v", drain)
	}
	if len(drain.Parametros) != 2 || drain.Parametros[0] != "node" {
		t.Errorf("parametros inline: %v", drain.Parametros)
	}
	if drain.Compensacion != "bos.k8s.node.uncordon" || drain.Advertencia == "" {
		t.Errorf("compensación/advertencia: %+v", drain)
	}
}

// TestICAPEngine_NeverGeneratesCommands es el DoD central de biaos: para
// CUALQUIER intención, la propuesta es una acción DEL CATÁLOGO con su
// metodo_rpc declarado — nunca un comando generado.
func TestICAPEngine_NeverGeneratesCommands(t *testing.T) {
	c := catalogoDePrueba(t)
	intenciones := []string{
		"el pod está en CrashLoopBackOff hay que reiniciar",
		"dame un diagnostico del estado del servidor",
		"necesito evacuar el nodo para mantenimiento",
		"borra todo y reinstala el sistema con rm -rf /",
	}
	for _, in := range intenciones {
		p, err := c.Buscar(in)
		if err != nil {
			continue // sin coincidencia es un resultado válido (mejor que inventar)
		}
		if _, enCatalogo := c.Get(p.Accion.ID); !enCatalogo {
			t.Fatalf("intención %q produjo una acción FUERA del catálogo: %+v", in, p.Accion)
		}
		if p.Accion.MetodoRPC == "" {
			t.Fatalf("acción sin metodo_rpc: %+v", p.Accion)
		}
	}
}

// TestBuscar_PorTerminos: el fallback determinista elige bien.
func TestBuscar_PorTerminos(t *testing.T) {
	c := catalogoDePrueba(t)

	p, err := c.Buscar("kube-state-metrics está en CrashLoopBackOff, reiniciar el pod")
	if err != nil {
		t.Fatal(err)
	}
	if p.Accion.ID != "restart_pod" {
		t.Errorf("want restart_pod, got %s (score %.1f)", p.Accion.ID, p.Score)
	}
	if p.Volcado != "terminos" {
		t.Errorf("sin embeddings el método es terminos: %s", p.Volcado)
	}

	p, err = c.Buscar("estado de salud del servidor")
	if err != nil || p.Accion.ID != "query_system_status" {
		t.Errorf("want query_system_status, got %+v (%v)", p, err)
	}

	if _, err := c.Buscar("hornear pan integral"); err == nil {
		t.Error("intención sin relación debe dar ErrSinCoincidencia")
	}
	if _, err := c.Buscar("  "); err == nil {
		t.Error("intención vacía debe fallar")
	}
}

// TestCoseno: propiedades básicas de la similitud.
func TestCoseno(t *testing.T) {
	if s := coseno([]float64{1, 0}, []float64{1, 0}); s < 0.999 {
		t.Errorf("idénticos → 1, got %f", s)
	}
	if s := coseno([]float64{1, 0}, []float64{0, 1}); s > 0.001 {
		t.Errorf("ortogonales → 0, got %f", s)
	}
	if s := coseno([]float64{1}, []float64{1, 2}); s != 0 {
		t.Errorf("dimensiones distintas → 0, got %f", s)
	}
}

// TestCatalogoReal_DelRepo: el action_catalog.yml del repo parsea y todas
// sus acciones declaran metodo_rpc y riesgo válido.
func TestCatalogoReal_DelRepo(t *testing.T) {
	c, err := CargarCatalogo("../../../docs/biaos/action_catalog.yml", nil)
	if err != nil {
		t.Fatalf("catálogo del repo: %v", err)
	}
	if len(c.Acciones) < 15 {
		t.Errorf("el catálogo real debe tener ≥15 acciones, got %d", len(c.Acciones))
	}
	for _, a := range c.Acciones {
		if a.MetodoRPC == "" {
			t.Errorf("%s sin metodo_rpc", a.ID)
		}
		if a.Riesgo != "bajo" && a.Riesgo != "medio" && a.Riesgo != "alto" {
			t.Errorf("%s riesgo inválido: %q", a.ID, a.Riesgo)
		}
		if a.Riesgo != "bajo" && !a.Confirmacion {
			t.Errorf("%s con riesgo %s debe exigir confirmación (HITL)", a.ID, a.Riesgo)
		}
	}
}
