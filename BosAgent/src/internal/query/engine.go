package query

// engine.go — motor genérico de ejecución paralela de fuentes (F6.6).
// Patrón de BOS-REPAIR-04 §Implementación: una goroutine por fuente,
// recolección con deadline, errores por clave sin abortar la saga.

import (
	"context"
	"time"
)

// SagaDeadline es el plazo interno de toda saga de consulta (SLO < 4s).
// Inferior al timeout de lectura del dispatcher (5s, F6.2) para que la
// respuesta agregada siempre llegue antes de que el dispatcher expire.
const SagaDeadline = 4 * time.Second

// Source es una fuente de datos de la saga. Debe respetar ctx.Done() en
// operaciones largas (exec, red); las lecturas de memoria pueden ignorarlo.
type Source func(ctx context.Context) (interface{}, error)

// Run ejecuta todas las fuentes en paralelo y agrega los resultados.
//
// Garantías:
//   - Cada fuente corre en su propia goroutine — sin orden definido.
//   - Una fuente que falla aporta {"error": msg} en su clave; la saga continúa.
//   - Al vencer el deadline, las fuentes pendientes aportan
//     {"error": "deadline excedido"} y Run retorna de inmediato.
//   - El resultado incluye siempre "timestamp" (RFC3339) y "duration_ms".
//
// Las goroutines rezagadas escriben en un canal con buffer == len(sources)
// y terminan solas — nunca quedan bloqueadas.
func Run(parent context.Context, sources map[string]Source) map[string]interface{} {
	start := time.Now()
	ctx, cancel := context.WithTimeout(parent, SagaDeadline)
	defer cancel()

	type item struct {
		key  string
		data interface{}
		err  error
	}
	ch := make(chan item, len(sources))
	for key, src := range sources {
		go func(key string, src Source) {
			data, err := src(ctx)
			ch <- item{key, data, err}
		}(key, src)
	}

	out := make(map[string]interface{}, len(sources)+2)
	pending := make(map[string]bool, len(sources))
	for key := range sources {
		pending[key] = true
	}

collect:
	for range sources {
		select {
		case it := <-ch:
			delete(pending, it.key)
			if it.err != nil {
				out[it.key] = map[string]string{"error": it.err.Error()}
			} else {
				out[it.key] = it.data
			}
		case <-ctx.Done():
			break collect
		}
	}
	for key := range pending {
		out[key] = map[string]string{"error": "deadline excedido (" + SagaDeadline.String() + ")"}
	}

	out["timestamp"] = time.Now().UTC().Format(time.RFC3339)
	out["duration_ms"] = time.Since(start).Milliseconds()
	return out
}
