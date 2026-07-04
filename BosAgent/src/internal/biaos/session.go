package biaos

// session.go — F10.6: estado HITL del agente (BOS-REPAIR-10 §2.4).
//
// Una acción con confirmacion_requerida no se ejecuta: queda PENDIENTE en
// una sesión con TTL. El operador la confirma (bos.ai.confirm) o expira.
// TestHITL_ExpiresAfterTimeout es el contrato del TTL.

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"sync"
	"time"

	"bos/internal/biaos/icap"
)

// SesionTTL: vida máxima de una confirmación pendiente.
// Variable para tests (producción: 5 minutos — una confirmación vieja es
// una confirmación sin contexto).
var SesionTTL = 5 * time.Minute

// ErrSesionNoEncontrada / ErrSesionExpirada — resultados de Confirmar.
var (
	ErrSesionNoEncontrada = errors.New("biaos: sesión HITL no encontrada")
	ErrSesionExpirada     = errors.New("biaos: sesión HITL expirada — repetir la intención")
)

// SesionHITL es una acción esperando confirmación humana.
type SesionHITL struct {
	ID        string                 `json:"sesion_id"`
	User      string                 `json:"user"`
	Intencion string                 `json:"intencion"`
	Accion    *icap.Accion           `json:"accion"`
	Params    map[string]interface{} `json:"params,omitempty"`
	Creada    time.Time              `json:"creada"`
	Expira    time.Time              `json:"expira"`
}

// sesionStore guarda las sesiones pendientes (map + RWMutex — §F10.12).
type sesionStore struct {
	mu       sync.RWMutex
	sesiones map[string]*SesionHITL
}

func newSesionStore() *sesionStore {
	return &sesionStore{sesiones: make(map[string]*SesionHITL)}
}

// Crear registra la acción pendiente y retorna su sesión.
func (s *sesionStore) Crear(user, intencion string, accion *icap.Accion, params map[string]interface{}) *SesionHITL {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	ses := &SesionHITL{
		ID:        "hitl-" + hex.EncodeToString(b),
		User:      user,
		Intencion: intencion,
		Accion:    accion,
		Params:    params,
		Creada:    time.Now().UTC(),
		Expira:    time.Now().UTC().Add(SesionTTL),
	}
	s.mu.Lock()
	s.sesiones[ses.ID] = ses
	s.mu.Unlock()
	return ses
}

// Reclamar retira la sesión para ejecutarla. Expirada → error y se purga.
func (s *sesionStore) Reclamar(id string) (*SesionHITL, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	ses, ok := s.sesiones[id]
	if !ok {
		return nil, ErrSesionNoEncontrada
	}
	delete(s.sesiones, id) // un solo uso — confirmada o expirada, sale del store
	if time.Now().UTC().After(ses.Expira) {
		return nil, ErrSesionExpirada
	}
	return ses, nil
}

// Pendientes purga expiradas y retorna las vivas (bos.ai.history).
func (s *sesionStore) Pendientes() []*SesionHITL {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now().UTC()
	out := make([]*SesionHITL, 0, len(s.sesiones))
	for id, ses := range s.sesiones {
		if now.After(ses.Expira) {
			delete(s.sesiones, id)
			continue
		}
		out = append(out, ses)
	}
	return out
}
