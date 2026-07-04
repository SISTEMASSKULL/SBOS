package release

import (
	"bos/internal/server"
)

// Adapter adapta release.Manager a la interfaz server.ReleaseAdapter.
// Extraído de cmd/bos/main.go en F1.7 — SRP: main.go no debe contener adaptadores.
//
// Thread safety: delega a Manager que es thread-safe.
type Adapter struct {
	mgr *Manager
}

// NewAdapter crea un Adapter que envuelve el Manager dado.
//
// Callers conocidos:
//   - cmd/bos/main.go — runNormal().
func NewAdapter(mgr *Manager) *Adapter {
	return &Adapter{mgr: mgr}
}

// CheckAvailable retorna los releases disponibles para una ficha y versión.
func (a *Adapter) CheckAvailable(ficha, version string) ([]server.ReleaseInfo, error) {
	rels, err := a.mgr.CheckAvailable(ficha, version)
	if err != nil {
		return nil, err
	}
	return convertList(rels), nil
}

// GetLatest retorna el release más reciente de una ficha en el canal activo.
func (a *Adapter) GetLatest(ficha string) (*server.ReleaseInfo, error) {
	rel, err := a.mgr.GetLatest(ficha)
	if err != nil || rel == nil {
		return nil, err
	}
	info := convertOne(*rel)
	return &info, nil
}

// ListAll retorna todos los releases en caché del Manager.
func (a *Adapter) ListAll() ([]server.ReleaseInfo, error) {
	relMap, err := a.mgr.ListAll()
	if err != nil {
		return nil, err
	}
	var all []ReleaseInfo
	for _, rels := range relMap {
		all = append(all, rels...)
	}
	return convertList(all), nil
}

// convertOne convierte un ReleaseInfo interno al tipo que expone server.
func convertOne(r ReleaseInfo) server.ReleaseInfo {
	return server.ReleaseInfo{
		Ficha:       r.Ficha,
		Version:     r.Version,
		Channel:     r.Channel,
		ReleaseDate: r.ReleaseDate.Format("2006-01-02"),
		MinBosVer:   r.MinBosVer,
		Checksum:    r.Checksum,
		Breaking:    r.Breaking,
		Notes:       r.Notes,
	}
}

// convertList convierte un slice de ReleaseInfo internos al tipo server.
func convertList(rels []ReleaseInfo) []server.ReleaseInfo {
	out := make([]server.ReleaseInfo, len(rels))
	for i, r := range rels {
		out[i] = convertOne(r)
	}
	return out
}
