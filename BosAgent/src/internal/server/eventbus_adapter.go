// Package server — adaptador que conecta domain.EventPublisherPort con eventbus.Publisher.
// Creado aquí (capa server) para mantener domain/ libre de dependencias de infraestructura.
package server

import (
	"time"

	"bos/internal/eventbus"
)

// fichaEventAdapter adapta eventbus.Publisher a domain.EventPublisherPort.
type fichaEventAdapter struct {
	pub eventbus.Publisher
}

// NewFichaEventAdapter crea el adaptador. pub no debe ser nil.
func NewFichaEventAdapter(pub eventbus.Publisher) *fichaEventAdapter {
	return &fichaEventAdapter{pub: pub}
}

// PublishFichaEvent emite un evento de ciclo de vida de ficha al bus.
func (a *fichaEventAdapter) PublishFichaEvent(eventType, fichaID, srv, version, ctxID string) {
	a.pub.Publish(eventbus.Event{
		Type:    eventType,
		FichaID: fichaID,
		Server:  srv,
		Version: version,
		CtxID:   ctxID,
		At:      time.Now(),
	})
}
