// Package catalog implementa D5 — catálogo unificado de fichas agrupadas por categoría.
// Lee desde el STATE_MANAGER y organiza fichas por categoría.
package catalog

import (
	"sort"

	"bos/internal/state"
)

// CategoryNames maps category IDs to human-readable names.
var CategoryNames = map[int]string{
	1: "SO Base",
	2: "Orquestacion",
	3: "Observabilidad",
	4: "Aplicaciones",
	5: "Seguridad",
	6: "IA",
}

// Catalog lee y organiza fichas desde el STATE_MANAGER por categoría.
//
// Thread safety: seguro para uso concurrente — toda mutación pasa por el Manager subyacente.
type Catalog struct {
	mgr *state.Manager
}

// CategorizedFicha contiene los campos listos para mostrar de una sola ficha en el catálogo.
type CategorizedFicha struct {
	Name         string `json:"name"`
	Version      string `json:"version"`
	State        string `json:"state"`
	HealthStatus string `json:"health_status"`
	Backend      string `json:"backend"`
	Category     int    `json:"category"`
	Server       string `json:"server"`
}

// CategoryGroup agrupa fichas por categoría con su nombre y lista ordenada.
type CategoryGroup struct {
	CategoryID   int                `json:"category_id"`
	CategoryName string             `json:"category_name"`
	Fichas       []CategorizedFicha `json:"fichas"`
}

// New crea un catálogo respaldado por el STATE_MANAGER dado.
//
// Callers conocidos:
//   - internal/server/api.go — instanciado en New() del servidor.
func New(mgr *state.Manager) *Catalog {
	return &Catalog{mgr: mgr}
}

// List retorna todas las fichas agrupadas por categoría, ordenadas por ID de categoría.
//
// Retorna: []CategoryGroup con fichas ordenadas alfabéticamente dentro de cada grupo.
//
// Efectos secundarios: ninguno — solo lectura del STATE_MANAGER.
//
// Estándares: SBOS-019 §3 — categorías 1-6 del catálogo.
func (c *Catalog) List() ([]CategoryGroup, error) {
	st, err := c.mgr.Read()
	if err != nil {
		return nil, err
	}

	groups := make(map[int][]CategorizedFicha)
	for _, f := range st.Fichas {
		cf := CategorizedFicha{
			Name:         f.Name,
			Version:      f.Version,
			State:        string(f.State),
			HealthStatus: f.HealthStatus,
			Backend:      f.Backend,
			Category:     f.Category,
			Server:       f.Server,
		}
		groups[f.Category] = append(groups[f.Category], cf)
	}

	result := make([]CategoryGroup, 0, len(groups))
	for _, catID := range sortedCategoryIDs(groups) {
		fichas := groups[catID]
		sort.Slice(fichas, func(i, j int) bool { return fichas[i].Name < fichas[j].Name })
		catName, ok := CategoryNames[catID]
		if !ok {
			catName = "Desconocido"
		}
		result = append(result, CategoryGroup{
			CategoryID:   catID,
			CategoryName: catName,
			Fichas:       fichas,
		})
	}

	return result, nil
}

// GetFicha retorna una ficha individual por nombre, o nil si no existe.
//
// Efectos secundarios: ninguno — solo lectura del STATE_MANAGER.
func (c *Catalog) GetFicha(name string) (*CategorizedFicha, error) {
	st, err := c.mgr.Read()
	if err != nil {
		return nil, err
	}
	f, ok := st.Fichas[name]
	if !ok {
		return nil, nil
	}
	return &CategorizedFicha{
		Name:         f.Name,
		Version:      f.Version,
		State:        string(f.State),
		HealthStatus: f.HealthStatus,
		Backend:      f.Backend,
		Category:     f.Category,
		Server:       f.Server,
	}, nil
}

func sortedCategoryIDs(groups map[int][]CategorizedFicha) []int {
	ids := make([]int, 0, len(groups))
	for id := range groups {
		ids = append(ids, id)
	}
	sort.Ints(ids)
	return ids
}
