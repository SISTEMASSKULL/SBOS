// Package audit registra la actividad del agente biaos en JSONL
// (F10.7 — ISO 27001 A.8.15; BOS-REPAIR-10 §audit). Asíncrono vía canal
// buffereado: el agente nunca se bloquea por I/O de auditoría, y el
// registro ocurre ANTES de ejecutar la herramienta (la goroutine del
// logger drena en orden FIFO).
//
// Cada línea es un JSON autocontenido — la fuente del dataset de
// entrenamiento Fase 2 (SFT desde el audit real) y del export F10.9.
package audit

import (
	"encoding/json"
	"os"
	"sync"
	"time"
)

// Evento es una entrada del audit JSONL del agente.
type Evento struct {
	Ts        time.Time              `json:"ts"`
	Tipo      string                 `json:"tipo"` // intent|propuesta|hitl|ejecucion|denegado|final
	User      string                 `json:"user"`
	SesionID  string                 `json:"sesion_id,omitempty"`
	Intencion string                 `json:"intencion,omitempty"`
	AccionID  string                 `json:"accion_id,omitempty"`
	Metodo    string                 `json:"metodo,omitempty"`
	Detalle   string                 `json:"detalle,omitempty"`
	Extra     map[string]interface{} `json:"extra,omitempty"`
}

// Logger escribe eventos en JSONL de forma asíncrona.
type Logger struct {
	ch   chan Evento
	done chan struct{}
	wg   sync.WaitGroup
}

// NewLogger abre (append) el archivo y arranca la goroutine de drenado.
// path producción: /var/log/bos/ai-audit.jsonl.
func NewLogger(path string) (*Logger, error) {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0640)
	if err != nil {
		return nil, err
	}
	l := &Logger{ch: make(chan Evento, 256), done: make(chan struct{})}
	l.wg.Add(1)
	go func() {
		defer l.wg.Done()
		defer f.Close()
		enc := json.NewEncoder(f)
		for {
			select {
			case ev := <-l.ch:
				_ = enc.Encode(ev)
			case <-l.done:
				// drenar lo pendiente antes de cerrar
				for {
					select {
					case ev := <-l.ch:
						_ = enc.Encode(ev)
					default:
						return
					}
				}
			}
		}
	}()
	return l, nil
}

// Log encola el evento de auditoría (bloqueante hasta encolar).
// No descarta — descartar auditoría viola ISO 27001 A.8.15.
// El buffer de 256 entradas garantiza que en la práctica nunca bloquea.
func (l *Logger) Log(ev Evento) {
	ev.Ts = time.Now().UTC()
	l.ch <- ev
}

// Close drena y cierra el archivo.
func (l *Logger) Close() {
	close(l.done)
	l.wg.Wait()
}
