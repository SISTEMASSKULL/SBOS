// Package icap implementa el Intent→Catalog→Action→Proposal Engine de biaos
// (F10.3 — BOS-REPAIR-10 §4). El insight central: el agente NUNCA genera
// comandos libres — mapea la intención del operador a una acción del
// catálogo declarativo (action_catalog.yml) por similitud, y la acción
// referencia un método JSON-RPC que existe en el rpcRegistry del bos.
//
// Búsqueda: embeddings vía Ollama + similitud coseno cuando hay endpoint
// local; sin Ollama degrada a coincidencia por términos (contextos_relevantes
// + descripción) — determinista y suficiente para el catálogo actual.
package icap

import (
	"fmt"
	"os"
	"strings"
)

// Accion es una entrada del catálogo ICAP.
type Accion struct {
	ID           string   `json:"id"`
	Descripcion  string   `json:"descripcion"`
	MetodoRPC    string   `json:"metodo_rpc"`
	Parametros   []string `json:"parametros"`
	Riesgo       string   `json:"riesgo"` // bajo | medio | alto
	Confirmacion bool     `json:"confirmacion_requerida"`
	Contextos    []string `json:"contextos_relevantes"`
	Compensacion string   `json:"compensacion,omitempty"`
	Advertencia  string   `json:"advertencia,omitempty"`
	vectorIntent []float64
}

// Catalogo es el conjunto de acciones cargadas con sus vectores.
type Catalogo struct {
	Acciones []Accion
	embed    EmbedFn // nil → fallback por términos
}

// CargarCatalogo lee y parsea action_catalog.yml (parser plano — mismo
// estilo que plugin.parseManifest: el formato es nuestro y estable).
// Si embedFn no es nil, pre-calcula el vector de cada acción.
func CargarCatalogo(path string, embedFn EmbedFn) (*Catalogo, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("icap: leer catálogo: %w", err)
	}
	acciones, err := parsearAcciones(string(data))
	if err != nil {
		return nil, err
	}
	if len(acciones) == 0 {
		return nil, fmt.Errorf("icap: catálogo vacío en %s", path)
	}
	cat := &Catalogo{Acciones: acciones, embed: embedFn}
	if embedFn != nil {
		for i := range cat.Acciones {
			texto := cat.Acciones[i].Descripcion + " " + strings.Join(cat.Acciones[i].Contextos, " ")
			if v, err := embedFn(texto); err == nil {
				cat.Acciones[i].vectorIntent = v
			}
		}
	}
	return cat, nil
}

// parsearAcciones extrae la lista de acciones del YAML plano.
func parsearAcciones(content string) ([]Accion, error) {
	var acciones []Accion
	var actual *Accion
	enLista := "" // "parametros" | "contextos_relevantes" | ""

	flush := func() {
		if actual != nil && actual.ID != "" {
			acciones = append(acciones, *actual)
		}
		actual = nil
	}

	for _, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}

		// nueva acción: "- id: xxx"
		if strings.HasPrefix(trimmed, "- id:") {
			flush()
			actual = &Accion{ID: strings.TrimSpace(strings.TrimPrefix(trimmed, "- id:"))}
			enLista = ""
			continue
		}
		if actual == nil {
			continue
		}

		// elementos de listas inline-block "- valor" (parametros/contextos)
		if strings.HasPrefix(trimmed, "- ") && enLista != "" {
			v := strings.TrimSpace(strings.TrimPrefix(trimmed, "- "))
			if enLista == "parametros" {
				actual.Parametros = append(actual.Parametros, v)
			} else {
				actual.Contextos = append(actual.Contextos, v)
			}
			continue
		}

		parts := strings.SplitN(trimmed, ":", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		value := strings.Trim(strings.TrimSpace(parts[1]), `"'`)

		switch key {
		case "descripcion":
			actual.Descripcion = value
			enLista = ""
		case "metodo_rpc":
			actual.MetodoRPC = value
			enLista = ""
		case "riesgo":
			actual.Riesgo = value
			enLista = ""
		case "confirmacion_requerida":
			actual.Confirmacion = value == "true"
			enLista = ""
		case "compensacion":
			if value != "null" {
				actual.Compensacion = value
			}
			enLista = ""
		case "advertencia":
			actual.Advertencia = value
			enLista = ""
		case "parametros":
			enLista = "parametros"
			// forma inline "[a, b]"
			if strings.HasPrefix(value, "[") {
				actual.Parametros = parsearListaInline(value)
				enLista = ""
			}
		case "contextos_relevantes":
			enLista = "contextos_relevantes"
			if strings.HasPrefix(value, "[") {
				actual.Contextos = parsearListaInline(value)
				enLista = ""
			}
		}
	}
	flush()
	return acciones, nil
}

func parsearListaInline(v string) []string {
	v = strings.Trim(v, "[]")
	if v == "" {
		return nil
	}
	parts := strings.Split(v, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if s := strings.TrimSpace(p); s != "" {
			out = append(out, s)
		}
	}
	return out
}

// Get retorna la acción por id.
func (c *Catalogo) Get(id string) (*Accion, bool) {
	for i := range c.Acciones {
		if c.Acciones[i].ID == id {
			return &c.Acciones[i], true
		}
	}
	return nil, false
}
