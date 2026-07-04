// Package context — service.go: lógica de negocio del Context Plane (SBOS-049).
// F5.2 — BOS-REPAIR Plan Maestro v3.
package context

import (
	"errors"
	"context"
	"fmt"
	"sync"
	"time"

	"bos/internal/domain"
)

// Store es la interfaz de persistencia del Context Plane.
// Implementada por store.go (PostgreSQL + Redis) en F5.3.
// En tests se usa un store en memoria.
type Store interface {
	SaveDevice(d *DeviceContext) error
	GetDevice(dctxID string) (*DeviceContext, error)
	SaveSession(s *SessionContext) error
	GetSession(ctxID string) (*SessionContext, error)
	ListSessionsByTenant(tenantID string) ([]*SessionContext, error)
	UpdateDeviceState(dctxID string, state ContextState) error
	UpdateSessionState(ctxID string, state ContextState) error
	AutoMigrate(ctx context.Context) error // F10.B.12: DDL auto-apply
}

// Service implementa las operaciones del Context Plane.
// Todos los métodos son thread-safe; no lanza goroutines — cumple TEA P3.
type Service struct {
	store     Store
	ctxDomain *domain.CtxService // Create/Validate W3C traceparent (M-14)
}

// NewService crea un Service con el Store dado.
func NewService(s Store) *Service {
	if s == nil {
		panic("context: NewService requiere un Store no nulo")
	}
	return &Service{store: s, ctxDomain: domain.NewCtxService()}
}

// AutoMigrate ejecuta el DDL del Context Plane si el store lo soporta (F10.B.12).
// memStore es no-op; PGRedisStore ejecuta CREATE TABLE IF NOT EXISTS.
func (svc *Service) AutoMigrate(ctx context.Context) error {
	return svc.store.AutoMigrate(ctx)
}

// NewServiceWithMemStore crea un Service con store en memoria (útil en tests
// y como fallback cuando PostgreSQL/Redis no están disponibles aún).
func NewServiceWithMemStore() *Service {
	return NewService(newMemStore())
}

// NewServiceWithPGRedis crea un Service con PostgreSQL + Redis reales.
// pgDSN: "postgres://user:pass@host:port/db?sslmode=disable"
// redisAddr: "host:port" (ej: "192.168.144.135:6379"), redisDB: índice Redis (0-15).
// Retorna error si la conexión PG falla; Redis degradado si falla (no bloquea).
func NewServiceWithPGRedis(pgDSN, redisAddr string, redisDB int) (*Service, error) {
	db, err := openPostgres(pgDSN)
	if err != nil {
		return nil, fmt.Errorf("context: PG connect: %w", err)
	}
	var redisCli RedisClient
	if redisAddr != "" {
		redisCli = NewSimpleRedisClient(redisAddr, redisDB, 3*time.Second)
	}
	store := NewPGRedisStore(db, redisCli)
	return NewService(store), nil
}

// RegisterDevice registra un nuevo DeviceContext (fase pre-auth).
// Es idempotente: si ya existe un device con el mismo dctxID retorna el existente.
func (svc *Service) RegisterDevice(hostname, tenantID, nodeK8s, ip string) (*DeviceContext, error) {
	dctx, err := NewDeviceContext(hostname, tenantID, nodeK8s, ip)
	if err != nil {
		return nil, fmt.Errorf("context.RegisterDevice: %w", err)
	}
	if err := svc.store.SaveDevice(dctx); err != nil {
		return nil, fmt.Errorf("context.RegisterDevice: persistir: %w", err)
	}
	return dctx, nil
}

// GetDevice recupera un DeviceContext por su dctx_id.
// Retorna ErrNotFound si no existe.
func (svc *Service) GetDevice(dctxID string) (*DeviceContext, error) {
	if dctxID == "" {
		return nil, errors.New("context.GetDevice: dctxID vacío")
	}
	return svc.store.GetDevice(dctxID)
}

// Promote convierte un DeviceContext en SessionContext (evento context.promoted).
// El DeviceContext pasa a StateInvalidado — ya no puede ser promovido de nuevo.
// bitMask debe ser > 0 (post-auth, calculado por bAuth).
func (svc *Service) Promote(dctxID, empresaID, sucursalID, posLogico, userID string,
	bitMask BitMask, loA int, traceparent string) (*SessionContext, error) {
	dctx, err := svc.store.GetDevice(dctxID)
	if err != nil {
		return nil, fmt.Errorf("context.Promote: recuperar DeviceContext: %w", err)
	}
	if dctx.State.IsTerminal() {
		return nil, fmt.Errorf("context.Promote: DeviceContext %s en estado terminal %s", dctxID, dctx.State)
	}
	sctx, err := NewSessionContext(dctxID, dctx.TenantID, empresaID, sucursalID,
		posLogico, userID, bitMask, loA, traceparent)
	if err != nil {
		return nil, fmt.Errorf("context.Promote: crear SessionContext: %w", err)
	}
	if err := svc.store.SaveSession(sctx); err != nil {
		return nil, fmt.Errorf("context.Promote: persistir sesión: %w", err)
	}
	// marcar dispositivo como invalidado post-promoción
	if err := svc.store.UpdateDeviceState(dctxID, StateInvalidado); err != nil {
		return nil, fmt.Errorf("context.Promote: invalidar DeviceContext: %w", err)
	}
	return sctx, nil
}

// Switch crea una nueva SessionContext reemplazando la anterior (cambio de empresa/sucursal).
// La sesión anterior pasa a StateInvalidado con marca "switched".
// El ctx_id es inmutable — se crea uno nuevo; el anterior se archiva.
func (svc *Service) Switch(prevCtxID, empresaID, sucursalID, posLogico string,
	traceparent string) (*SessionContext, error) {
	prev, err := svc.store.GetSession(prevCtxID)
	if err != nil {
		return nil, fmt.Errorf("context.Switch: recuperar sesión previa: %w", err)
	}
	if prev.State.IsTerminal() {
		return nil, fmt.Errorf("context.Switch: sesión %s ya en estado terminal %s", prevCtxID, prev.State)
	}
	sctx, err := NewSessionContext(prev.DctxID, prev.TenantID, empresaID, sucursalID,
		posLogico, prev.UserID, prev.BitMask, prev.LoA, traceparent)
	if err != nil {
		return nil, fmt.Errorf("context.Switch: crear nueva sesión: %w", err)
	}
	if err := svc.store.SaveSession(sctx); err != nil {
		return nil, fmt.Errorf("context.Switch: persistir nueva sesión: %w", err)
	}
	if err := svc.store.UpdateSessionState(prevCtxID, StateInvalidado); err != nil {
		return nil, fmt.Errorf("context.Switch: invalidar sesión previa: %w", err)
	}
	return sctx, nil
}

// Invalidate invalida explícitamente un ctx_id (logout, revocación por bAuth).
// Idempotente: si ya está en estado terminal no retorna error.
func (svc *Service) Invalidate(ctxID string) error {
	if ctxID == "" {
		return errors.New("context.Invalidate: ctxID vacío")
	}
	sctx, err := svc.store.GetSession(ctxID)
	if err != nil {
		return fmt.Errorf("context.Invalidate: %w", err)
	}
	if sctx.State.IsTerminal() {
		return nil // idempotente
	}
	return svc.store.UpdateSessionState(ctxID, StateInvalidado)
}

// InvalidateAllByTenant invalida masivamente todos los ctx_id activos de un tenant.
// Usado en: bosctl tenant suspend/remove (SBOS-049 §5.1).
func (svc *Service) InvalidateAllByTenant(tenantID string) (int, error) {
	if tenantID == "" {
		return 0, errors.New("context.InvalidateAllByTenant: tenantID vacío")
	}
	sessions, err := svc.store.ListSessionsByTenant(tenantID)
	if err != nil {
		return 0, fmt.Errorf("context.InvalidateAllByTenant: listar sesiones: %w", err)
	}
	count := 0
	var errs []error
	for _, s := range sessions {
		if s.State.IsTerminal() {
			continue
		}
		if err := svc.store.UpdateSessionState(s.CtxID, StateInvalidado); err != nil {
			errs = append(errs, err)
			continue
		}
		count++
	}
	if len(errs) > 0 {
		return count, fmt.Errorf("context.InvalidateAllByTenant: %d errores al invalidar", len(errs))
	}
	return count, nil
}

// Get recupera una SessionContext por ctx_id.
func (svc *Service) Get(ctxID string) (*SessionContext, error) {
	if ctxID == "" {
		return nil, errors.New("context.Get: ctxID vacío")
	}
	return svc.store.GetSession(ctxID)
}

// ListAllByTenant retorna TODAS las SessionContext de un tenant sin filtrar
// por estado ni TTL. Uso exclusivo de diagnóstico (bos.query.context F6.11):
// la distribución de estados y la detección de expirados-no-invalidados
// requieren ver también las sesiones terminales. Para operación usar
// ListByTenant (solo activas vigentes).
func (svc *Service) ListAllByTenant(tenantID string) ([]*SessionContext, error) {
	if tenantID == "" {
		return nil, errors.New("context.ListAllByTenant: tenantID vacío")
	}
	all, err := svc.store.ListSessionsByTenant(tenantID)
	if err != nil {
		return nil, fmt.Errorf("context.ListAllByTenant: %w", err)
	}
	return all, nil
}

// ListByTenant retorna todas las SessionContext activas de un tenant.
func (svc *Service) ListByTenant(tenantID string) ([]*SessionContext, error) {
	if tenantID == "" {
		return nil, errors.New("context.ListByTenant: tenantID vacío")
	}
	all, err := svc.store.ListSessionsByTenant(tenantID)
	if err != nil {
		return nil, fmt.Errorf("context.ListByTenant: %w", err)
	}
	// filtrar expiradas en memoria (el store puede retornar todas)
	active := all[:0]
	for _, s := range all {
		if s.State == StateActivo && !s.IsExpired() {
			active = append(active, s)
		}
	}
	return active, nil
}

// ─── Context Plane — Create / Validate (M-14, unificado desde domain) ────────

// Create genera un nuevo ctx_id con traceparent W3C (SBOS-049, RFC 7519).
// Delega en domain.CtxService — lógica pura, sin I/O.
func (svc *Service) Create(p domain.CreateParams) (*domain.CtxID, error) {
	return svc.ctxDomain.Create(p)
}

// Validate verifica la sintaxis de un traceparent W3C Trace Context.
// Delega en domain.CtxService — lógica pura, sin I/O.
func (svc *Service) Validate(traceParent, tenantID string) (*domain.ValidateResult, error) {
	return svc.ctxDomain.Validate(traceParent, tenantID)
}

// ─── Store en memoria para tests ─────────────────────────────────────────────

// memStore es una implementación en memoria de Store para tests.
// No usar en producción.
type memStore struct {
	mu       sync.RWMutex
	devices  map[string]*DeviceContext
	sessions map[string]*SessionContext
}

// newMemStore crea un Store en memoria vacío.
func newMemStore() Store {
	return &memStore{
		devices:  make(map[string]*DeviceContext),
		sessions: make(map[string]*SessionContext),
	}
}

var errNotFound = errors.New("context: no encontrado")

func (m *memStore) SaveDevice(d *DeviceContext) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	// idempotente: no sobreescribir si ya existe
	if _, ok := m.devices[d.DctxID]; !ok {
		cp := *d
		m.devices[d.DctxID] = &cp
	}
	return nil
}

func (m *memStore) GetDevice(id string) (*DeviceContext, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	d, ok := m.devices[id]
	if !ok {
		return nil, fmt.Errorf("%w: dctx_id=%s", errNotFound, id)
	}
	cp := *d
	return &cp, nil
}

func (m *memStore) SaveSession(s *SessionContext) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	cp := *s
	m.sessions[s.CtxID] = &cp
	return nil
}

func (m *memStore) GetSession(id string) (*SessionContext, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	s, ok := m.sessions[id]
	if !ok {
		return nil, fmt.Errorf("%w: ctx_id=%s", errNotFound, id)
	}
	cp := *s
	return &cp, nil
}

func (m *memStore) ListSessionsByTenant(tenantID string) ([]*SessionContext, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	var out []*SessionContext
	for _, s := range m.sessions {
		if s.TenantID == tenantID {
			cp := *s
			out = append(out, &cp)
		}
	}
	return out, nil
}

func (m *memStore) UpdateDeviceState(dctxID string, state ContextState) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	d, ok := m.devices[dctxID]
	if !ok {
		return fmt.Errorf("%w: dctx_id=%s", errNotFound, dctxID)
	}
	d.State = state
	d.UpdatedAt = time.Now().UTC()
	return nil
}

func (m *memStore) UpdateSessionState(ctxID string, state ContextState) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	s, ok := m.sessions[ctxID]
	if !ok {
		return fmt.Errorf("%w: ctx_id=%s", errNotFound, ctxID)
	}
	s.State = state
	return nil
}

	// AutoMigrate es no-op en memStore — el DDL solo aplica con PG real.
	func (m *memStore) AutoMigrate(ctx context.Context) error { return nil }
