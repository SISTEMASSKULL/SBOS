// Package catalog implements D5 — unified app catalog with category groups.
// Reads from the state manager and organizes fichas by category.
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

// Catalog reads and organizes fichas from the state manager.
type Catalog struct {
	mgr *state.Manager
}

// CategorizedFicha holds display-ready fields for a single ficha.
type CategorizedFicha struct {
	Name         string `json:"name"`
	Version      string `json:"version"`
	State        string `json:"state"`
	HealthStatus string `json:"health_status"`
	Backend      string `json:"backend"`
	Category     int    `json:"category"`
	Server       string `json:"server"`
}

// CategoryGroup groups fichas by category.
type CategoryGroup struct {
	CategoryID   int                `json:"category_id"`
	CategoryName string             `json:"category_name"`
	Fichas       []CategorizedFicha `json:"fichas"`
}

// New creates a catalog backed by the given state manager.
func New(mgr *state.Manager) *Catalog {
	return &Catalog{mgr: mgr}
}

// List returns all fichas grouped by category, ordered by category ID.
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

// GetFicha returns a single ficha by name or nil if not found.
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
