// Package context — store.go: persistencia del Context Plane (SBOS-049).
// F5.3 — BOS-REPAIR Plan Maestro v3.
//
// Arquitectura: PGRedisStore implementa Store usando dos interfaces desacopladas:
//   - SQLExecutor: PostgreSQL (bkernel_db, tablas registered_devices + context_sessions)
//   - RedisClient:  cache en Redis DB1 con TTL sincronizado con Keycloak
//
// En producción se inyectan los drivers reales (pgx, go-redis).
// En tests unitarios se inyectan stubs (ver store_test.go).
// Tests de integración real: //go:build integration
package context

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

// ─── Interfaces de bajo nivel ──────────────────────────────────────────────

// SQLRow abstrae sql.Row para testabilidad.
type SQLRow interface {
	Scan(dest ...any) error
}

// SQLRows abstrae sql.Rows para testabilidad.
type SQLRows interface {
	Next() bool
	Scan(dest ...any) error
	Close() error
	Err() error
}

// SQLExecutor abstrae *sql.DB y *sql.Tx para las queries del Context Plane.
// Implementado por *database/sql.DB en producción, por stub en tests.
type SQLExecutor interface {
	QueryRow(query string, args ...any) *sql.Row
	Exec(query string, args ...any) (sql.Result, error)
	Query(query string, args ...any) (*sql.Rows, error)
}

// RedisClient abstrae las operaciones Redis necesarias para el Context Plane.
// Implementado por go-redis Client en producción, por stub en tests.
type RedisClient interface {
	Set(key string, value []byte, ttl time.Duration) error
	Get(key string) ([]byte, error)
	Del(key string) error
	Exists(key string) (bool, error)
}

// ─── PGRedisStore ─────────────────────────────────────────────────────────

// PGRedisStore implementa Store usando PostgreSQL como fuente de verdad
// y Redis DB1 como cache de O(1) lookup (SBOS-049 §9).
type PGRedisStore struct {
	db    SQLExecutor
	cache RedisClient
}

// NewPGRedisStore crea un PGRedisStore. db y cache pueden ser nil — en ese caso
// las operaciones correspondientes se omiten gracefully (degraded mode).
func NewPGRedisStore(db SQLExecutor, cache RedisClient) Store {
	return &PGRedisStore{db: db, cache: cache}
}

// ─── DDL referencia ───────────────────────────────────────────────────────
// Las tablas canónicas están en DDL_bos_schema.sql (schema bos, sbos_db):
//   bos.registered_device  — DeviceContext pre-auth (SBOS-049)
//   bos.context_session    — SessionContext post-auth (SBOS-049)
// Estado almacenado como ENUM bos_context_state_enum (texto).

// AutoMigrate verifica que las tablas del Context Plane existen en sbos_db.
// Las tablas formales viven en DDL_bos_schema.sql (schema bos).
// Esta función solo verifica presencia — no crea (el DDL formal lo hace).
func (s *PGRedisStore) AutoMigrate(ctx context.Context) error {
	if s.db == nil {
		return errors.New("context.store: SQLExecutor no configurado")
	}
	var exists bool
	err := s.db.QueryRow(
		`SELECT EXISTS (
			SELECT 1 FROM information_schema.tables
			WHERE table_schema = 'bos' AND table_name = 'registered_device'
		)`,
	).Scan(&exists)
	if err != nil {
		return fmt.Errorf("context.AutoMigrate: %w", err)
	}
	if !exists {
		return errors.New("context.AutoMigrate: bos.registered_device no existe — aplicar DDL_bos_schema.sql")
	}
	return nil
}

// contextStateStr convierte ContextState al string del ENUM bos_context_state_enum.
func contextStateStr(s ContextState) string {
	switch s {
	case StatePending:
		return "PENDING"
	case StateActivo:
		return "ACTIVO"
	case StateSuspendido:
		return "SUSPENDIDO"
	case StateBloqueado:
		return "BLOQUEADO"
	case StateInvalidado:
		return "INVALIDADO"
	case StateExpirado:
		return "EXPIRADO"
	case StateArchivado:
		return "ARCHIVADO"
	default:
		return "PENDING"
	}
}

// contextStateFromStr convierte el string del ENUM bos_context_state_enum a ContextState.
func contextStateFromStr(s string) ContextState {
	switch s {
	case "PENDING":
		return StatePending
	case "ACTIVO":
		return StateActivo
	case "SUSPENDIDO":
		return StateSuspendido
	case "BLOQUEADO":
		return StateBloqueado
	case "INVALIDADO":
		return StateInvalidado
	case "EXPIRADO":
		return StateExpirado
	case "ARCHIVADO":
		return StateArchivado
	default:
		return StatePending
	}
}

// SaveDevice persiste un DeviceContext en PG y lo invalida del cache si existía.
func (s *PGRedisStore) SaveDevice(d *DeviceContext) error {
	if s.db == nil {
		return errors.New("context.store: SQLExecutor no configurado")
	}
	_, err := s.db.Exec(`
		INSERT INTO bos.registered_device
			(dctx_id, hostname, tenant_id, node_k8s, ip, state, created_at, updated_at, expires_at)
		VALUES ($1,$2,$3,$4,$5::INET,$6::bos_context_state_enum,$7,$8,$9)
		ON CONFLICT (dctx_id) DO NOTHING`,
		d.DctxID, d.Hostname, d.TenantID, d.NodeK8s, d.IP,
		contextStateStr(d.State), d.CreatedAt, d.UpdatedAt, d.ExpiresAt,
	)
	return err
}

// GetDevice recupera un DeviceContext: primero Redis cache, luego PG.
func (s *PGRedisStore) GetDevice(dctxID string) (*DeviceContext, error) {
	// intento cache primero (incluso si db es nil)
	if s.cache != nil {
		if raw, err := s.cache.Get("dctx:" + dctxID); err == nil {
			var d DeviceContext
			if err := json.Unmarshal(raw, &d); err == nil {
				return &d, nil
			}
		}
	}
	// fallback PG
	if s.db == nil {
		return nil, fmt.Errorf("context.store: %w: dctx_id=%s", errNotFound, dctxID)
	}
	row := s.db.QueryRow(`
		SELECT dctx_id, hostname, tenant_id, node_k8s, ip::TEXT, state::TEXT,
		       created_at, updated_at, expires_at
		FROM bos.registered_device WHERE dctx_id = $1`, dctxID)
	var d DeviceContext
	var stateStr string
	err := row.Scan(&d.DctxID, &d.Hostname, &d.TenantID, &d.NodeK8s, &d.IP,
		&stateStr, &d.CreatedAt, &d.UpdatedAt, &d.ExpiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, fmt.Errorf("%w: dctx_id=%s", errNotFound, dctxID)
	}
	if err != nil {
		return nil, fmt.Errorf("context.store.GetDevice: %w", err)
	}
	d.State = contextStateFromStr(stateStr)
	// poblar cache
	if s.cache != nil {
		if raw, err := json.Marshal(&d); err == nil {
			ttl := time.Until(d.ExpiresAt)
			if ttl > 0 {
				_ = s.cache.Set("dctx:"+dctxID, raw, ttl)
			}
		}
	}
	return &d, nil
}

// SaveSession persiste una SessionContext en PG y rellena el cache Redis.
// El traceparent W3C se almacena directamente en la columna (SBOS-049 §5.3).
func (s *PGRedisStore) SaveSession(sess *SessionContext) error {
	if s.db == nil {
		return errors.New("context.store: SQLExecutor no configurado")
	}
	_, err := s.db.Exec(`
		INSERT INTO bos.context_session
			(ctx_id, dctx_id, tenant_id, empresa_id, sucursal_id, pos_logico, user_id,
			 bitmask, loa, state, traceparent, created_at, expires_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::bos_context_state_enum,$11,$12,$13)
		ON CONFLICT (ctx_id) DO NOTHING`,
		sess.CtxID, sess.DctxID, sess.TenantID, sess.EmpresaID, sess.SucursalID,
		sess.PosLogico, sess.UserID, uint64(sess.BitMask), sess.LoA,
		contextStateStr(sess.State), sess.Traceparent, sess.CreatedAt, sess.ExpiresAt,
	)
	if err != nil {
		return fmt.Errorf("context.store.SaveSession: %w", err)
	}
	// rellenar cache
	if s.cache != nil {
		if raw, err := json.Marshal(sess); err == nil {
			ttl := time.Until(sess.ExpiresAt)
			if ttl > 0 {
				_ = s.cache.Set("ctx:"+sess.CtxID, raw, ttl)
			}
		}
	}
	return nil
}

// GetSession recupera una SessionContext: Redis O(1) primero, PG como fallback.
func (s *PGRedisStore) GetSession(ctxID string) (*SessionContext, error) {
	// intento cache primero (incluso si db es nil)
	if s.cache != nil {
		if raw, err := s.cache.Get("ctx:" + ctxID); err == nil {
			var sess SessionContext
			if err := json.Unmarshal(raw, &sess); err == nil {
				return &sess, nil
			}
		}
	}
	// fallback PG
	if s.db == nil {
		return nil, fmt.Errorf("context.store: %w: ctx_id=%s", errNotFound, ctxID)
	}
	row := s.db.QueryRow(`
		SELECT ctx_id, dctx_id, tenant_id, empresa_id, sucursal_id, pos_logico, user_id,
		       bitmask, loa, state::TEXT, traceparent, created_at, expires_at
		FROM bos.context_session WHERE ctx_id = $1`, ctxID)
	var sess SessionContext
	var maskUint uint64
	var stateStr string
	err := row.Scan(&sess.CtxID, &sess.DctxID, &sess.TenantID, &sess.EmpresaID,
		&sess.SucursalID, &sess.PosLogico, &sess.UserID,
		&maskUint, &sess.LoA, &stateStr, &sess.Traceparent,
		&sess.CreatedAt, &sess.ExpiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, fmt.Errorf("%w: ctx_id=%s", errNotFound, ctxID)
	}
	if err != nil {
		return nil, fmt.Errorf("context.store.GetSession: %w", err)
	}
	sess.BitMask = BitMask(maskUint)
	sess.State = contextStateFromStr(stateStr)
	// poblar cache
	if s.cache != nil {
		if raw, err := json.Marshal(&sess); err == nil {
			ttl := time.Until(sess.ExpiresAt)
			if ttl > 0 {
				_ = s.cache.Set("ctx:"+ctxID, raw, ttl)
			}
		}
	}
	return &sess, nil
}

// ListSessionsByTenant lista todas las sesiones de un tenant (activas + terminales).
func (s *PGRedisStore) ListSessionsByTenant(tenantID string) ([]*SessionContext, error) {
	if s.db == nil {
		return nil, nil
	}
	rows, err := s.db.Query(`
		SELECT ctx_id, dctx_id, tenant_id, empresa_id, sucursal_id, pos_logico, user_id,
		       bitmask, loa, state::TEXT, traceparent, created_at, expires_at
		FROM bos.context_session WHERE tenant_id = $1
		ORDER BY created_at DESC`, tenantID)
	if err != nil {
		return nil, fmt.Errorf("context.store.ListSessionsByTenant: %w", err)
	}
	defer rows.Close()
	var out []*SessionContext
	for rows.Next() {
		var sess SessionContext
		var maskUint uint64
		var stateStr string
		if err := rows.Scan(&sess.CtxID, &sess.DctxID, &sess.TenantID, &sess.EmpresaID,
			&sess.SucursalID, &sess.PosLogico, &sess.UserID,
			&maskUint, &sess.LoA, &stateStr, &sess.Traceparent,
			&sess.CreatedAt, &sess.ExpiresAt); err != nil {
			return nil, fmt.Errorf("context.store.ListSessionsByTenant: scan: %w", err)
		}
		sess.BitMask = BitMask(maskUint)
		sess.State = contextStateFromStr(stateStr)
		out = append(out, &sess)
	}
	return out, rows.Err()
}

// UpdateDeviceState actualiza el estado de un DeviceContext en PG e invalida cache.
func (s *PGRedisStore) UpdateDeviceState(dctxID string, state ContextState) error {
	if s.db == nil {
		return errors.New("context.store: SQLExecutor no configurado")
	}
	res, err := s.db.Exec(`
		UPDATE bos.registered_device SET state=$1::bos_context_state_enum, updated_at=NOW() WHERE dctx_id=$2`,
		contextStateStr(state), dctxID)
	if err != nil {
		return fmt.Errorf("context.store.UpdateDeviceState: %w", err)
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return fmt.Errorf("%w: dctx_id=%s", errNotFound, dctxID)
	}
	if s.cache != nil {
		_ = s.cache.Del("dctx:" + dctxID)
	}
	return nil
}

// UpdateSessionState actualiza el estado de una SessionContext en PG e invalida cache.
// Si el estado es terminal (INVALIDADO/EXPIRADO/ARCHIVADO), elimina del cache Redis
// para que Kong deje de aceptar el ctx_id inmediatamente (SBOS-049 §8).
func (s *PGRedisStore) UpdateSessionState(ctxID string, state ContextState) error {
	if s.db == nil {
		return errors.New("context.store: SQLExecutor no configurado")
	}
	res, err := s.db.Exec(`
		UPDATE bos.context_session SET state=$1::bos_context_state_enum WHERE ctx_id=$2`,
		contextStateStr(state), ctxID)
	if err != nil {
		return fmt.Errorf("context.store.UpdateSessionState: %w", err)
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return fmt.Errorf("%w: ctx_id=%s", errNotFound, ctxID)
	}
	if s.cache != nil {
		_ = s.cache.Del("ctx:" + ctxID) // invalidar siempre (terminal o no) para forzar re-read
	}
	return nil
}
