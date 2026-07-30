package ficha

import (
	"testing"

	"bos/internal/plugin"
)

func mkManifest(id string, order int, deps ...string) *plugin.FichaManifest {
	return &plugin.FichaManifest{
		ID:             id,
		ExecutionOrder: order,
		Dependencies:   deps,
	}
}

func TestResolver_SinFichas(t *testing.T) {
	plan, err := Resolver(nil)
	if err != nil {
		t.Errorf("Resolver(nil) no debe dar error: %v", err)
	}
	if plan.Total != 0 {
		t.Errorf("Resolver(nil): Total debe ser 0, obtenido %d", plan.Total)
	}
	if plan.Cycles {
		t.Error("Resolver(nil): Cycles debe ser false")
	}
}

func TestResolver_SinDependencias(t *testing.T) {
	fichas := []*plugin.FichaManifest{
		mkManifest("postgresql", 1),
		mkManifest("redis", 2),
		mkManifest("keycloak", 3),
	}

	plan, err := Resolver(fichas)
	if err != nil {
		t.Fatalf("Resolver sin deps: %v", err)
	}
	if plan.Total != 3 {
		t.Errorf("Total: esperado 3, obtenido %d", plan.Total)
	}
	if plan.Cycles {
		t.Error("sin ciclos: Cycles debe ser false")
	}
	if len(plan.Order) != 3 {
		t.Errorf("Order: esperados 3 elementos, obtenidos %d", len(plan.Order))
	}
}

func TestResolver_ConDependencias_Orden(t *testing.T) {
	// keycloak depende de postgresql
	fichas := []*plugin.FichaManifest{
		mkManifest("keycloak", 2, "postgresql"),
		mkManifest("postgresql", 1),
	}

	plan, err := Resolver(fichas)
	if err != nil {
		t.Fatalf("Resolver con deps: %v", err)
	}

	// postgresql debe aparecer antes que keycloak en Order
	pgIdx, kcIdx := -1, -1
	for i, id := range plan.Order {
		switch id {
		case "postgresql":
			pgIdx = i
		case "keycloak":
			kcIdx = i
		}
	}
	if pgIdx < 0 || kcIdx < 0 {
		t.Fatal("postgresql o keycloak no están en el plan")
	}
	if pgIdx >= kcIdx {
		t.Errorf("postgresql (idx %d) debe estar antes que keycloak (idx %d)", pgIdx, kcIdx)
	}
}

func TestResolver_CicloDetectado(t *testing.T) {
	fichas := []*plugin.FichaManifest{
		mkManifest("a", 1, "b"),
		mkManifest("b", 2, "a"), // ciclo a→b→a
	}

	plan, err := Resolver(fichas)
	if err == nil {
		t.Error("Resolver debe retornar error con ciclo")
	}
	if plan == nil {
		t.Fatal("Resolver con ciclo debe retornar Plan no-nil")
	}
	if !plan.Cycles {
		t.Error("Plan.Cycles debe ser true cuando hay ciclo")
	}
}

func TestExecutionOrder_OlaParalela(t *testing.T) {
	// redis y postgresql no tienen deps entre sí → misma ola
	fichas := []*plugin.FichaManifest{
		mkManifest("postgresql", 1),
		mkManifest("redis", 2),
		mkManifest("keycloak", 3, "postgresql", "redis"),
	}

	plan, err := Resolver(fichas)
	if err != nil {
		t.Fatalf("Resolver: %v", err)
	}

	// Primera ola (Waves[0]) no debe contener keycloak
	if len(plan.Waves) < 2 {
		t.Fatalf("esperadas ≥2 olas, obtenidas %d", len(plan.Waves))
	}
	for _, id := range plan.Waves[0] {
		if id == "keycloak" {
			t.Error("keycloak no debe estar en la primera ola (depende de otros)")
		}
	}
}

func TestBuildGraph_ValidateDependencies_ImplicitoSilencioso(t *testing.T) {
	// AddNode crea nodos implícitos para dependencias no declaradas explícitamente.
	// ValidateDependencies no detecta deps faltantes del catálogo porque el nodo
	// implícito existe en g.nodes tras AddNode. Comportamiento documentado.
	fichas := []*plugin.FichaManifest{
		mkManifest("keycloak", 1, "postgresql"),
	}

	g := BuildGraph(fichas)
	errs := g.ValidateDependencies()
	// El nodo "postgresql" fue creado implícitamente por AddNode → 0 errores.
	if len(errs) != 0 {
		t.Errorf("nodo implícito no debe generar error de validación: %v", errs)
	}
}

func TestBuildGraph_ValidateDependencies_OK(t *testing.T) {
	fichas := []*plugin.FichaManifest{
		mkManifest("postgresql", 1),
		mkManifest("keycloak", 2, "postgresql"),
	}

	g := BuildGraph(fichas)
	errs := g.ValidateDependencies()
	if len(errs) != 0 {
		t.Errorf("ValidateDependencies no debe tener errores: %v", errs)
	}
}

func TestNewGraph_Vacio(t *testing.T) {
	g := NewGraph()
	if g == nil {
		t.Fatal("NewGraph no debe retornar nil")
	}
	errs := g.ValidateDependencies()
	if len(errs) != 0 {
		t.Errorf("grafo vacío sin errores: %v", errs)
	}
}
