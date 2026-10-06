// Package eventbus — bus de eventos inter-componente para BOS.
//
// Publica eventos de ciclo de vida de fichas y del Context Plane.
// La implementación por defecto es en memoria (in-process).
// Diseñado para escalar a Redis Streams DB0 en versiones futuras (manual 3.09).
package eventbus

import "time"

// Tipos de evento — prefijo refleja el módulo emisor.
const (
	EvFichaInstalled = "ficha.installed"
	EvFichaRemoved   = "ficha.removed"
	EvFichaRepaired  = "ficha.repaired"
	EvFichaDegraded  = "ficha.degraded"
	EvCtxCreated     = "ctx.created"
	EvCtxInvalidated = "ctx.invalidated"
	EvCtxPromoted    = "ctx.promoted"
)

// Event es el sobre estándar de todos los eventos del bus.
type Event struct {
	Type    string    `json:"type"`
	FichaID string    `json:"ficha_id,omitempty"`
	Server  string    `json:"server,omitempty"`
	Version string    `json:"version,omitempty"`
	CtxID   string    `json:"ctx_id,omitempty"`
	Detail  string    `json:"detail,omitempty"`
	At      time.Time `json:"at"`
}

// Publisher es la interfaz mínima para emitir eventos.
// Implementaciones: MemBus (in-process), RedisBus (futuro, manual 3.09).
type Publisher interface {
	Publish(e Event)
}

// Subscriber puede recibir eventos de un bus.
type Subscriber interface {
	Subscribe(handler func(Event))
}

// Bus combina Publisher y Subscriber.
type Bus interface {
	Publisher
	Subscriber
}

// NoopBus descarta todos los eventos. Útil en tests y modo bootstrap.
type NoopBus struct{}

func (NoopBus) Publish(_ Event)         {}
func (NoopBus) Subscribe(_ func(Event)) {}
