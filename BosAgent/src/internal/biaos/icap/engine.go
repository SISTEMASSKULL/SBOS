package icap

// engine.go — F10.3: búsqueda de la acción por intención (BOS-REPAIR-10 §4.3).
// Con embeddings: similitud coseno contra el vector de cada acción.
// Sin embeddings (Ollama ausente): puntuación por términos — cada palabra de
// la intención que aparece en contextos_relevantes (peso 3), id (2) o
// descripción (1) suma; gana la acción con mayor puntaje.

import (
	"errors"
	"fmt"
	"math"
	"net/http"
	"sort"
	"strings"
)

// EmbedFn produce el vector de un texto (Ollama /api/embeddings en prod).
type EmbedFn func(texto string) ([]float64, error)

// Propuesta es el resultado del ICAP: la acción + su afinidad con el intent.
type Propuesta struct {
	Accion  *Accion `json:"accion"`
	Score   float64 `json:"score"`
	Volcado string  `json:"como_se_busco"` // "coseno" | "terminos"
}

// umbralSimilitudMinimo: score coseno mínimo para aceptar una acción (0=nulo, 1=idéntico).
const umbralSimilitudMinimo = 0.45

// ErrSinCoincidencia: ninguna acción supera el umbral mínimo.
var ErrSinCoincidencia = errors.New("icap: ninguna acción del catálogo coincide con la intención")

// Buscar mapea la intención del operador a la mejor acción del catálogo.
func (c *Catalogo) Buscar(intencion string) (*Propuesta, error) {
	if strings.TrimSpace(intencion) == "" {
		return nil, errors.New("icap: intención vacía")
	}
	if c.embed != nil {
		if p, err := c.buscarCoseno(intencion); err == nil {
			return p, nil
		}
		// embeddings fallaron en runtime → degradar a términos
	}
	return c.buscarTerminos(intencion)
}

func (c *Catalogo) buscarCoseno(intencion string) (*Propuesta, error) {
	qv, err := c.embed(intencion)
	if err != nil {
		return nil, err
	}
	mejor := -1.0
	var elegida *Accion
	for i := range c.Acciones {
		if c.Acciones[i].vectorIntent == nil {
			continue
		}
		s := coseno(qv, c.Acciones[i].vectorIntent)
		if s > mejor {
			mejor = s
			elegida = &c.Acciones[i]
		}
	}
	if elegida == nil || mejor < umbralSimilitudMinimo {
		return nil, ErrSinCoincidencia
	}
	return &Propuesta{Accion: elegida, Score: mejor, Volcado: "coseno"}, nil
}

func (c *Catalogo) buscarTerminos(intencion string) (*Propuesta, error) {
	terminos := strings.Fields(strings.ToLower(intencion))
	type cand struct {
		idx   int
		score float64
	}
	var cands []cand
	for i := range c.Acciones {
		a := &c.Acciones[i]
		score := 0.0
		idLower := strings.ToLower(strings.ReplaceAll(a.ID, "_", " "))
		descLower := strings.ToLower(a.Descripcion)
		for _, t := range terminos {
			if len(t) < 3 {
				continue
			}
			for _, ctx := range a.Contextos {
				if strings.Contains(strings.ToLower(ctx), t) {
					score += 3
				}
			}
			if strings.Contains(idLower, t) {
				score += 2
			}
			if strings.Contains(descLower, t) {
				score++
			}
		}
		if score > 0 {
			cands = append(cands, cand{i, score})
		}
	}
	if len(cands) == 0 {
		return nil, ErrSinCoincidencia
	}
	sort.Slice(cands, func(i, j int) bool { return cands[i].score > cands[j].score })
	return &Propuesta{
		Accion:  &c.Acciones[cands[0].idx],
		Score:   cands[0].score,
		Volcado: "terminos",
	}, nil
}

// coseno calcula la similitud coseno entre dos vectores.
func coseno(a, b []float64) float64 {
	if len(a) != len(b) || len(a) == 0 {
		return 0
	}
	var dot, na, nb float64
	for i := range a {
		dot += a[i] * b[i]
		na += a[i] * a[i]
		nb += b[i] * b[i]
	}
	if na == 0 || nb == 0 {
		return 0
	}
	return dot / (math.Sqrt(na) * math.Sqrt(nb))
}

// OllamaEmbed construye un EmbedFn contra el endpoint local de Ollama.
// Retorna nil si el endpoint no responde — el catálogo degradará a términos.
func OllamaEmbed(endpoint, model string) EmbedFn {
	if endpoint == "" {
		endpoint = "http://localhost:11434"
	}
	// probe rápido: sin Ollama no hay embeddings
	resp, err := http.Get(endpoint + "/api/tags")
	if err != nil {
		return nil
	}
	resp.Body.Close()
	return func(texto string) ([]float64, error) {
		return ollamaEmbedCall(endpoint, model, texto)
	}
}

func ollamaEmbedCall(endpoint, model, texto string) ([]float64, error) {
	body := fmt.Sprintf(`{"model":%q,"prompt":%q}`, model, texto)
	resp, err := http.Post(endpoint+"/api/embeddings", "application/json", strings.NewReader(body))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var out struct {
		Embedding []float64 `json:"embedding"`
	}
	if err := jsonDecode(resp.Body, &out); err != nil {
		return nil, err
	}
	if len(out.Embedding) == 0 {
		return nil, errors.New("icap: embedding vacío")
	}
	return out.Embedding, nil
}
