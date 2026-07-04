package audit

// export.go — F10.9: exportar el audit JSONL como dataset de entrenamiento
// (BOS-REPAIR-10 §6 Fase 2 — SFT desde el audit real). Agrupa los eventos
// de una misma intención (intent→propuesta→ejecucion→final) en ejemplos
// {intención → acción tomada}, el formato que consume el fine-tuning.

import (
	"bufio"
	"encoding/json"
	"os"
)

// EjemploEntrenamiento es una trayectoria intención→acción lista para SFT.
type EjemploEntrenamiento struct {
	Intencion string `json:"intencion"`
	AccionID  string `json:"accion_id"`
	Metodo    string `json:"metodo"`
	Resultado string `json:"resultado"` // ejecucion|hitl|denegado|sin_coincidencia
	User      string `json:"user"`
}

// LeerEventos carga todos los eventos del audit JSONL (líneas inválidas se
// omiten — el log puede tener escrituras parciales del último evento).
func LeerEventos(path string) ([]Evento, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var out []Evento
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		var ev Evento
		if json.Unmarshal(sc.Bytes(), &ev) == nil {
			out = append(out, ev)
		}
	}
	return out, sc.Err()
}

// ExportarDataset transforma el audit JSONL en ejemplos de entrenamiento.
// Cada intención produce un ejemplo con el desenlace real (la acción que se
// ejecutó, quedó en HITL, se denegó, o no tuvo coincidencia).
func ExportarDataset(eventos []Evento) []EjemploEntrenamiento {
	var ejemplos []EjemploEntrenamiento
	var actual *EjemploEntrenamiento

	cerrar := func() {
		if actual != nil && actual.Intencion != "" {
			ejemplos = append(ejemplos, *actual)
		}
		actual = nil
	}

	for _, ev := range eventos {
		switch ev.Tipo {
		case "intent":
			cerrar()
			actual = &EjemploEntrenamiento{Intencion: ev.Intencion, User: ev.User, Resultado: "sin_coincidencia"}
		case "propuesta":
			if actual != nil {
				actual.AccionID = ev.AccionID
				actual.Metodo = ev.Metodo
			}
		case "ejecucion":
			if actual != nil {
				actual.AccionID = ev.AccionID
				actual.Metodo = ev.Metodo
				actual.Resultado = "ejecucion"
			}
		case "hitl":
			if actual != nil {
				actual.Resultado = "hitl"
			}
		case "denegado":
			if actual != nil {
				actual.Resultado = "denegado"
			}
		}
	}
	cerrar()
	return ejemplos
}

// EscribirDataset serializa los ejemplos como JSONL en w (un objeto por línea).
func EscribirDataset(ejemplos []EjemploEntrenamiento, path string) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	enc := json.NewEncoder(f)
	for _, e := range ejemplos {
		if err := enc.Encode(e); err != nil {
			return err
		}
	}
	return nil
}
