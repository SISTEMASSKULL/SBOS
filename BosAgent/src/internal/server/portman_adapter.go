// Package server — adaptador que conecta domain.PortAssignerPort con portman.Manager.
// Creado aquí (capa server) para mantener domain/ libre de dependencias de infraestructura.
package server

import (
	"fmt"

	"bos/internal/portman"
)

// fichaPortAdapter adapta portman.Manager a domain.PortAssignerPort.
// Asigna un puerto HOST_PHYSICAL por ficha con el algoritmo A de SBOS-050.
type fichaPortAdapter struct {
	mgr PortManager
}

// NewFichaPortAdapter crea el adaptador. mgr no debe ser nil.
func NewFichaPortAdapter(mgr PortManager) *fichaPortAdapter {
	return &fichaPortAdapter{mgr: mgr}
}

// AssignFicha asigna un puerto HOST_PHYSICAL a la ficha recién instalada.
func (a *fichaPortAdapter) AssignFicha(fichaID, logicalServer string, fichaIndex int, ctxID string) error {
	req := portman.PortRequest{
		FichaID:       fichaID,
		FichaIndex:    fichaIndex,
		LogicalServer: normalizeServer(logicalServer),
		PortTypes:     []portman.PortType{portman.PortTypeHostPhysical},
		AssignedBy:    "bos-lifecycle",
		CtxID:         ctxID,
	}
	result, err := a.mgr.Assign(req)
	if err != nil {
		return fmt.Errorf("fichaPortAdapter.Assign %s: %w", fichaID, err)
	}
	if result.NeedsHITL {
		return fmt.Errorf("fichaPortAdapter.Assign %s: HITL requerido — %s", fichaID, result.HITLReason)
	}
	return nil
}

// ReleaseFicha marca los puertos de la ficha como liberados en el Kardex.
func (a *fichaPortAdapter) ReleaseFicha(fichaID, ctxID string) error {
	_, err := a.mgr.Release(fichaID, ctxID)
	return err
}

// normalizeServer convierte nombres de directorio de servidor (ej: "coreserver")
// al código S-XX de SBOS-050. Si ya es código S-XX, lo devuelve sin cambios.
func normalizeServer(s string) string {
	mapping := map[string]string{
		"dataserver":       "S00",
		"idserver":         "S01",
		"apiserver":        "S02",
		"appserver01":      "S03",
		"appserver02":      "S04",
		"appserver03":      "S05",
		"searchserver":     "S06",
		"notifyserver":     "S07",
		"edgeserver":       "S08",
		"vdiserver":        "S09",
		"backupserver":     "S10",
		"monitorserver":    "S11",
		"despliegueserver": "S12",
		"emailserver":      "S13",
		"aiserver":         "S14",
		"coreserver":       "S15",
		"webserver":        "S16",
		"devserver":        "S16",
		"testserver":       "S17",
		"hostserver":       "S18",
	}
	if code, ok := mapping[s]; ok {
		return code
	}
	if len(s) >= 3 && s[0] == 'S' {
		return s // ya es código S-XX
	}
	return "S15" // coreserver — default seguro
}
