package grpc

// event_bus.go — EventBus pub-sub para server streaming Watch (FichaEvents).

import (
	"sync"
	"sync/atomic"

	pb "bos/proto/bos/ficha/v1"
)

const subBufSize = 32

// EventBus es un bus de eventos tipo pub-sub para FichaEvents.
// Thread-safe. Suscriptores lentos (buffer lleno) son desconectados sin bloquear.
type EventBus struct {
	mu   sync.RWMutex
	subs map[int64]chan *pb.FichaEvent
	seq  atomic.Int64
}

// NewEventBus crea un bus de eventos vacío.
func NewEventBus() *EventBus {
	return &EventBus{subs: make(map[int64]chan *pb.FichaEvent)}
}

// Subscribe registra un nuevo suscriptor.
// Retorna: id único del suscriptor y canal de recepción de eventos.
func (b *EventBus) Subscribe() (int64, <-chan *pb.FichaEvent) {
	id := b.seq.Add(1)
	ch := make(chan *pb.FichaEvent, subBufSize)
	b.mu.Lock()
	b.subs[id] = ch
	b.mu.Unlock()
	return id, ch
}

// Unsubscribe elimina al suscriptor y cierra su canal.
func (b *EventBus) Unsubscribe(id int64) {
	b.mu.Lock()
	if ch, ok := b.subs[id]; ok {
		delete(b.subs, id)
		close(ch)
	}
	b.mu.Unlock()
}

// Publish envía un evento a todos los suscriptores activos.
// Suscriptores con buffer lleno son desconectados para no bloquear al publicador.
func (b *EventBus) Publish(evt *pb.FichaEvent) {
	b.mu.RLock()
	var slow []int64
	for id, ch := range b.subs {
		select {
		case ch <- evt:
		default:
			slow = append(slow, id)
		}
	}
	b.mu.RUnlock()

	for _, id := range slow {
		b.Unsubscribe(id)
	}
}
