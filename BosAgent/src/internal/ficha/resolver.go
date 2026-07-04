// Package ficha — Dependency Resolver: grafo, detección de ciclos, orden topológico.
// F11.A.3 (M2.1) — BOS-REPAIR Plan Maestro v3.
//
// Referencias: Kahn's algorithm (topological sort), ADR-021 (18 estados).
package ficha

import (
	"fmt"
	"sort"
	"strings"

	"bos/internal/plugin"
)

// Graph representa el grafo de dependencias entre fichas.
// Nodes: nombres de ficha (string).
// Edges: ficha → sus dependencias (ficha DEPENDE de X).
type Graph struct {
	nodes map[string]*Node
}

// Node representa una ficha en el grafo de dependencias.
type Node struct {
	Name         string
	Dependencies []string       // fichas de las que depende
	Dependents   []string       // fichas que dependen de esta
}

// NewGraph crea un grafo vacío.
func NewGraph() *Graph {
	return &Graph{nodes: make(map[string]*Node)}
}

// AddNode agrega una ficha y sus dependencias al grafo.
func (g *Graph) AddNode(name string, deps []string) {
	n, ok := g.nodes[name]
	if !ok {
		n = &Node{Name: name}
		g.nodes[name] = n
	}
	n.Dependencies = deps
	// Registrar relación inversa (dependents)
	for _, dep := range deps {
		dn, ok := g.nodes[dep]
		if !ok {
			dn = &Node{Name: dep}
			g.nodes[dep] = dn
		}
		dn.Dependents = appendUnique(dn.Dependents, name)
	}
}

// BuildGraph construye el grafo de dependencias desde una lista de fichas.
func BuildGraph(fichas []*plugin.FichaManifest) *Graph {
	g := NewGraph()
	for _, f := range fichas {
		g.AddNode(f.ID, f.Dependencies)
	}
	return g
}

// TopologicalSort retorna el orden topológico de instalación usando Kahn.
// Retorna error si detecta un ciclo.
func (g *Graph) TopologicalSort() ([]string, error) {
	// Calcular in-degree de cada nodo
	inDegree := make(map[string]int)
	for name := range g.nodes {
		inDegree[name] = 0
	}
	for _, n := range g.nodes {
		for range n.Dependencies {
			inDegree[n.Name]++ // n depende de dep → n tiene arista entrante desde dep
		}
	}

	// Cola de nodos con in-degree 0 (sin dependencias)
	queue := make([]string, 0)
	for name, deg := range inDegree {
		if deg == 0 {
			queue = append(queue, name)
		}
	}
	sort.Strings(queue) // orden determinístico

	var result []string
	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]
		result = append(result, current)

		// Reducir in-degree de todos los que dependen de current
		node := g.nodes[current]
		if node == nil {
			continue
		}
		for _, dependent := range node.Dependents {
			inDegree[dependent]--
			if inDegree[dependent] == 0 {
				queue = append(queue, dependent)
				sort.Strings(queue)
			}
		}
	}

	// Si no procesamos todos los nodos → hay ciclo
	if len(result) != len(g.nodes) {
		cycle := g.findCycle(inDegree)
		return nil, fmt.Errorf("ciclo de dependencias detectado: %s", cycle)
	}

	return result, nil
}

// ExecutionOrder retorna el orden de instalación agrupado por oleadas (olas).
// Las fichas en la misma ola pueden instalarse en paralelo.
func (g *Graph) ExecutionOrder() ([][]string, error) {
	sorted, err := g.TopologicalSort()
	if err != nil {
		return nil, err
	}

	// Agrupar por nivel de profundidad
	depths := make(map[string]int)
	for _, name := range sorted {
		node := g.nodes[name]
		if node == nil {
			depths[name] = 0
			continue
		}
		maxDep := 0
		for _, dep := range node.Dependencies {
			if d, ok := depths[dep]; ok && d >= maxDep {
				maxDep = d + 1
			}
		}
		depths[name] = maxDep
	}

	// Encontrar profundidad máxima
	maxDepth := 0
	for _, d := range depths {
		if d > maxDepth {
			maxDepth = d
		}
	}

	waves := make([][]string, maxDepth+1)
	for _, name := range sorted {
		d := depths[name]
		waves[d] = append(waves[d], name)
	}

	return waves, nil
}

// findCycle intenta identificar los nodos involucrados en un ciclo.
func (g *Graph) findCycle(inDegree map[string]int) string {
	// Nodos con in-degree > 0 después de Kahn → están en un ciclo
	cycleNodes := make([]string, 0)
	for name, deg := range inDegree {
		if deg > 0 {
			cycleNodes = append(cycleNodes, name)
		}
	}
	sort.Strings(cycleNodes)
	return strings.Join(cycleNodes, " → ")
}

// ValidateDependencies verifica que todas las dependencias declaradas existan.
// Retorna una lista de errores (dependencias no encontradas).
func (g *Graph) ValidateDependencies() []error {
	var errs []error
	for _, n := range g.nodes {
		for _, dep := range n.Dependencies {
			if _, ok := g.nodes[dep]; !ok {
				errs = append(errs, fmt.Errorf("ficha %q depende de %q, pero %q no existe en el catálogo", n.Name, dep, dep))
			}
		}
	}
	return errs
}

// Plan representa el plan de instalación completo.
type Plan struct {
	Order    []string   // Orden topológico total
	Waves    [][]string // Oleadas paralelizables
	Total    int        // Total de fichas
	Cycles   bool       // true si hay ciclos
}

// Resolver calcula el plan de instalación para un conjunto de fichas.
// Retorna el orden topológico, agrupado por oleadas.
func Resolver(fichas []*plugin.FichaManifest) (*Plan, error) {
	g := BuildGraph(fichas)

	// Validar dependencias
	errs := g.ValidateDependencies()
	if len(errs) > 0 {
		msgs := make([]string, len(errs))
		for i, e := range errs {
			msgs[i] = e.Error()
		}
		return nil, fmt.Errorf("dependencias inválidas:\n  - %s", strings.Join(msgs, "\n  - "))
	}

	order, err := g.TopologicalSort()
	if err != nil {
		return &Plan{
			Order:  nil,
			Waves:  nil,
			Total:  len(fichas),
			Cycles: true,
		}, fmt.Errorf("resolver: %w", err)
	}

	waves, _ := g.ExecutionOrder()

	return &Plan{
		Order:  order,
		Waves:  waves,
		Total:  len(fichas),
		Cycles: false,
	}, nil
}

func appendUnique(slice []string, item string) []string {
	for _, s := range slice {
		if s == item {
			return slice
		}
	}
	return append(slice, item)
}
