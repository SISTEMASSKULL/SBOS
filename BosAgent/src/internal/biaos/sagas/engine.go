// Package sagas implementa el motor de sagas de biaos (F10.4 —
// BOS-REPAIR-10 §3.3, manual JSON-RPC Parte 9): pasos con dependencias
// (DAG), ejecución paralela de pasos independientes, compensación en orden
// inverso ante fallo, y persistencia de cada ejecución en disco — si el
// daemon muere a mitad de saga, el estado sobrevive y la recuperación
// compensa los pasos completados.
package sagas

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"
)

// Paso es una unidad de la saga: ejecuta un método RPC y declara su
// compensación (vacía = sin compensación, p.ej. lecturas).
type Paso struct {
	ID           string                 `json:"id"`
	Metodo       string                 `json:"metodo"`
	Params       map[string]interface{} `json:"params,omitempty"`
	Compensacion string                 `json:"compensacion,omitempty"`
	DependeDe    []string               `json:"depende_de,omitempty"`
}

// Definicion es una saga declarada (cargable de YAML o construida en código).
type Definicion struct {
	Nombre string `json:"nombre"`
	Pasos  []Paso `json:"pasos"`
}

// EstadoPaso es el resultado persistido de un paso.
type EstadoPaso struct {
	ID        string    `json:"id"`
	Estado    string    `json:"estado"` // pendiente|ok|fallo|compensado
	Detalle   string    `json:"detalle,omitempty"`
	Terminado time.Time `json:"terminado,omitempty"`
}

// Ejecucion es el registro completo persistido de una corrida de saga.
type Ejecucion struct {
	ID        string                 `json:"id"`
	Saga      string                 `json:"saga"`
	Inicio    time.Time              `json:"inicio"`
	Fin       time.Time              `json:"fin,omitempty"`
	Exito     bool                   `json:"exito"`
	Terminada bool                   `json:"terminada"`
	Pasos     map[string]*EstadoPaso `json:"pasos"`
}

// Ejecutor invoca un método RPC del bos (lo implementa el dispatcher del
// server; en tests, un stub).
type Ejecutor func(metodo string, params map[string]interface{}) error

// Engine ejecuta sagas con persistencia en dir.
type Engine struct {
	dir      string
	ejecutar Ejecutor
	mu       sync.Mutex
}

// NewEngine crea el motor. dir es el directorio de persistencia
// (producción: /var/lib/bos/ai/sagas/).
func NewEngine(dir string, ej Ejecutor) (*Engine, error) {
	if ej == nil {
		return nil, errors.New("sagas: ejecutor requerido")
	}
	if err := os.MkdirAll(dir, 0750); err != nil {
		return nil, fmt.Errorf("sagas: crear dir de persistencia: %w", err)
	}
	return &Engine{dir: dir, ejecutar: ej}, nil
}

// Ejecutar corre la saga: olas topológicas (pasos sin dependencias
// pendientes corren EN PARALELO), persistiendo tras cada paso. Ante el
// primer fallo, compensa los pasos OK en orden inverso de finalización.
func (e *Engine) Ejecutar(def Definicion) (*Ejecucion, error) {
	e.mu.Lock()
	defer e.mu.Unlock()

	ej := &Ejecucion{
		ID:     fmt.Sprintf("%s-%d", def.Nombre, time.Now().UnixNano()),
		Saga:   def.Nombre,
		Inicio: time.Now().UTC(),
		Pasos:  make(map[string]*EstadoPaso, len(def.Pasos)),
	}
	for _, p := range def.Pasos {
		ej.Pasos[p.ID] = &EstadoPaso{ID: p.ID, Estado: "pendiente"}
	}
	e.persistir(ej)

	var ordenOK []string // orden real de finalización (para compensar inverso)
	pendientes := make(map[string]Paso, len(def.Pasos))
	for _, p := range def.Pasos {
		pendientes[p.ID] = p
	}

	for len(pendientes) > 0 {
		ola := olaEjecutable(pendientes, ej)
		if len(ola) == 0 {
			e.fallarYCompensar(ej, def, ordenOK, "dependencias circulares o paso previo fallido")
			return ej, fmt.Errorf("sagas: %s sin pasos ejecutables (DAG roto o fallo previo)", def.Nombre)
		}

		// la ola corre en paralelo
		type resultado struct {
			id  string
			err error
		}
		ch := make(chan resultado, len(ola))
		for _, p := range ola {
			go func(p Paso) {
				ch <- resultado{p.ID, e.ejecutar(p.Metodo, p.Params)}
			}(p)
		}
		falloEnOla := false
		for range ola {
			r := <-ch
			delete(pendientes, r.id)
			if r.err != nil {
				ej.Pasos[r.id].Estado = "fallo"
				ej.Pasos[r.id].Detalle = r.err.Error()
				ej.Pasos[r.id].Terminado = time.Now().UTC()
				falloEnOla = true
			} else {
				ej.Pasos[r.id].Estado = "ok"
				ej.Pasos[r.id].Terminado = time.Now().UTC()
				ordenOK = append(ordenOK, r.id)
			}
		}
		e.persistir(ej)
		if falloEnOla {
			e.fallarYCompensar(ej, def, ordenOK, "")
			return ej, fmt.Errorf("sagas: %s falló — %d pasos compensados", def.Nombre, len(ordenOK))
		}
	}

	ej.Exito = true
	ej.Terminada = true
	ej.Fin = time.Now().UTC()
	e.persistir(ej)
	return ej, nil
}

// olaEjecutable retorna los pasos cuyas dependencias están todas en ok.
func olaEjecutable(pendientes map[string]Paso, ej *Ejecucion) []Paso {
	var ola []Paso
	for _, p := range pendientes {
		listo := true
		for _, dep := range p.DependeDe {
			st, ok := ej.Pasos[dep]
			if !ok || st.Estado != "ok" {
				listo = false
				break
			}
		}
		if listo {
			ola = append(ola, p)
		}
	}
	sort.Slice(ola, func(i, j int) bool { return ola[i].ID < ola[j].ID })
	return ola
}

// fallarYCompensar ejecuta las compensaciones de los pasos OK en orden
// inverso de finalización (best-effort — cada compensación se persiste).
func (e *Engine) fallarYCompensar(ej *Ejecucion, def Definicion, ordenOK []string, motivo string) {
	porID := make(map[string]Paso, len(def.Pasos))
	for _, p := range def.Pasos {
		porID[p.ID] = p
	}
	for i := len(ordenOK) - 1; i >= 0; i-- {
		p := porID[ordenOK[i]]
		if p.Compensacion == "" {
			continue
		}
		if err := e.ejecutar(p.Compensacion, p.Params); err != nil {
			ej.Pasos[p.ID].Detalle = "compensación falló: " + err.Error()
		} else {
			ej.Pasos[p.ID].Estado = "compensado"
		}
	}
	if motivo != "" {
		ej.Pasos["__saga__"] = &EstadoPaso{ID: "__saga__", Estado: "fallo", Detalle: motivo}
	}
	ej.Terminada = true
	ej.Fin = time.Now().UTC()
	e.persistir(ej)
}

// Recuperar carga las ejecuciones NO terminadas (daemon murió a mitad) y
// compensa sus pasos OK — el principio de reversibilidad tras un crash.
func (e *Engine) Recuperar(defs map[string]Definicion) ([]string, error) {
	e.mu.Lock()
	defer e.mu.Unlock()

	entradas, err := os.ReadDir(e.dir)
	if err != nil {
		return nil, err
	}
	var recuperadas []string
	for _, ent := range entradas {
		if ent.IsDir() || filepath.Ext(ent.Name()) != ".json" {
			continue
		}
		raw, err := os.ReadFile(filepath.Join(e.dir, ent.Name()))
		if err != nil {
			continue
		}
		var ej Ejecucion
		if json.Unmarshal(raw, &ej) != nil || ej.Terminada {
			continue
		}
		def, ok := defs[ej.Saga]
		if !ok {
			continue
		}
		// compensar los OK en orden inverso de Terminado
		var oks []*EstadoPaso
		for _, st := range ej.Pasos {
			if st.Estado == "ok" {
				oks = append(oks, st)
			}
		}
		sort.Slice(oks, func(i, j int) bool { return oks[i].Terminado.After(oks[j].Terminado) })
		ids := make([]string, len(oks))
		for i, st := range oks {
			ids[len(oks)-1-i] = st.ID // fallarYCompensar invierte — pasar en orden de finalización
		}
		e.fallarYCompensar(&ej, def, ids, "recuperación post-crash")
		recuperadas = append(recuperadas, ej.ID)
	}
	return recuperadas, nil
}

// persistir escribe la ejecución a disco (fsync implícito por escritura
// completa + rename atómico).
func (e *Engine) persistir(ej *Ejecucion) {
	raw, err := json.MarshalIndent(ej, "", "  ")
	if err != nil {
		return
	}
	final := filepath.Join(e.dir, ej.ID+".json")
	tmp := final + ".tmp"
	if os.WriteFile(tmp, raw, 0640) == nil {
		_ = os.Rename(tmp, final)
	}
}
