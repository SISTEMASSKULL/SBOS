package eventbus

import "sync"

// MemBus es un bus pub-sub en memoria seguro para goroutines concurrentes.
// Publica a todos los handlers suscritos de forma síncrona.
//
// Límite: in-process — los daemons hermanos (bkernel, biedata, bsearch)
// NO reciben estos eventos. Migrar a RedisBus (manual 3.09) para cruzar procesos.
type MemBus struct {
	mu       sync.RWMutex
	handlers []func(Event)
}

// NewMemBus crea un bus en memoria listo para usar.
func NewMemBus() *MemBus {
	return &MemBus{}
}

// Publish emite el evento a todos los handlers suscritos.
// Estampa Event.At si está en cero.
func (b *MemBus) Publish(e Event) {
	if e.At.IsZero() {
		e.At = timeNow()
	}
	b.mu.RLock()
	handlers := make([]func(Event), len(b.handlers))
	copy(handlers, b.handlers)
	b.mu.RUnlock()

	for _, h := range handlers {
		h(e)
	}
}

// Subscribe registra un handler que recibe todos los eventos publicados.
func (b *MemBus) Subscribe(handler func(Event)) {
	b.mu.Lock()
	b.handlers = append(b.handlers, handler)
	b.mu.Unlock()
}
