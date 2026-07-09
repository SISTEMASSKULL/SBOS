# INSTRUCCIONES DE EJECUCIÓN — Átomos F5.1 a F5.3
## Context Plane — `internal/context/` (SBOS-049)
## Para: Agente ejecutor (Claude Code / desarrollador)

**Átomos:** F5.1 (types), F5.2 (service), F5.3 (store PostgreSQL + Redis)  
**Requiere previo:** F4.5 ✅ (`cmd/bosctl/main.go` ≤120 líneas)  
**Duración estimada:** F5.1: 30 min · F5.2: 90 min · F5.3: 90 min  
**Riesgo:** ALTO — afecta trazabilidad de sesiones y autenticación  
**Bases normativas:** SBOS-049, BOS-REPAIR-08, W3C Trace Context, NIST SP 800-207, ISO 27001 A.8.15

---

## CONTEXTO TÉCNICO

### Estado actual (30% implementado)

```bash
# Verificar lo que ya existe:
grep -n "bos.ctx\." internal/server/jsonrpc.go | head -10
# Solo debe mostrar 2 métodos: bos.ctx.create y bos.ctx.validate

cat internal/domain/types.go | grep -A 20 "type CtxID"
# CtxID struct existe pero sin: dctx_id, states, BitMask, TTL, Redis cache
```

### Objetivo — qué debe existir al final de F5.3

```
internal/context/
  doc.go      ← ya existe (F0.2) — verificar que tiene las 6 secciones ADR-003
  types.go    ← F5.1 — DeviceContext, SessionContext, estados, eventos
  service.go  ← F5.2 — Service con 8 métodos de negocio
  store.go    ← F5.3 — Store PostgreSQL + Redis con TTL y W3C Trace
```

### El modelo de datos completo (DDL de SBOS-049 §12)

Antes de escribir código Go, tener el DDL claro:

```sql
-- Tabla principal de sesiones de contexto (bkernel_db)
CREATE TABLE context_sessions (
    ctx_id          VARCHAR(64)  PRIMARY KEY,
    dctx_id_prev    VARCHAR(64),
    user_id         VARCHAR(128) NOT NULL,
    kc_session_id   VARCHAR(128) NOT NULL,

    tenant          VARCHAR(64)  NOT NULL,
    empresa         VARCHAR(64),
    sucursal        VARCHAR(64),
    pos_logico      VARCHAR(64),
    device_id       VARCHAR(128),

    hardware_type   VARCHAR(20)
                    CHECK (hardware_type IN ('physical','logical_pod','wsl','web_only')),

    pod             VARCHAR(128),
    namespace       VARCHAR(64),
    node            VARCHAR(64),
    cluster         VARCHAR(64),
    vps             VARCHAR(64),
    geo             VARCHAR(128),

    traceparent     VARCHAR(128),  -- W3C Trace Context
    bitmask         VARCHAR(20),   -- BitMask hex calculado por bAuth

    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ  NOT NULL,
    switched_at     TIMESTAMPTZ,
    invalidated_at  TIMESTAMPTZ,
    status          VARCHAR(20)  NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','switched','expired','invalid'))
) PARTITION BY RANGE (created_at);

CREATE INDEX idx_ctx_sessions_user   ON context_sessions (user_id, status);
CREATE INDEX idx_ctx_sessions_tenant ON context_sessions (tenant, empresa, status);
CREATE INDEX idx_ctx_sessions_active ON context_sessions (expires_at) WHERE status = 'active';

-- Tabla de dispositivos registrados
CREATE TABLE registered_devices (
    dctx_id         VARCHAR(64)  PRIMARY KEY,
    tenant          VARCHAR(64)  NOT NULL,
    hostname        VARCHAR(255) NOT NULL,
    device_uuid     VARCHAR(64),
    ip_address      INET,
    mac_address     VARCHAR(17),
    hardware_type   VARCHAR(20),
    registered_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_seen_at    TIMESTAMPTZ,
    status          VARCHAR(20)  NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','suspended','revoked'))
);

CREATE INDEX idx_reg_devices_tenant ON registered_devices (tenant, status);
CREATE UNIQUE INDEX idx_reg_devices_hostname ON registered_devices (tenant, hostname);
```

---

## PRE-CONDICIONES

```bash
cd /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/BOS_V8/

# 1. F4 completo
[ -f internal/context/doc.go ] && echo "✅ doc.go existe (F0.2)" || echo "❌ F0.2 primero"
go build ./... && echo "✅ build limpio" || echo "❌ resolver antes"

# 2. Verificar acceso a PostgreSQL (para F5.3)
kubectl exec -n sbos-data postgresql-0 -- pg_isready 2>/dev/null \
  && echo "✅ PostgreSQL accesible" \
  || echo "⚠️  PostgreSQL no accesible — F5.1 y F5.2 se pueden implementar offline"

# 3. Verificar que las tablas NO existen aún (para saber si hay que crearlas)
kubectl exec -n sbos-data postgresql-0 -- \
  psql -U bosagent -d bkernel_db -c "\dt context_sessions" 2>/dev/null \
  && echo "⚠️  context_sessions ya existe — verificar schema" \
  || echo "✅ tabla no existe — crear en F5.3"

# 4. Verificar go.mod tiene el driver PostgreSQL
grep "pgx\|pq\|postgres" go.mod && echo "✅ driver PG presente" \
  || echo "⚠️  agregar driver: go get github.com/jackc/pgx/v5"

# 5. Verificar cliente Redis
grep "redis\|go-redis" go.mod && echo "✅ cliente Redis presente" \
  || echo "⚠️  agregar cliente: go get github.com/redis/go-redis/v9"
```

---

## ÁTOMO F5.1 — `internal/context/types.go`

**Objetivo:** Definir todos los tipos Go del Context Plane.  
**Tiempo estimado:** 30 minutos

```go
// Package context implementa el Context Plane del daemon bos.
// [Verificar que doc.go ya tiene las 6 secciones de ADR-003]

package context

import "time"

// HardwareType identifica el tipo de dispositivo que origina un contexto.
type HardwareType string

const (
    HardwarePhysical   HardwareType = "physical"    // dispositivo físico Fedora
    HardwareLogicalPod HardwareType = "logical_pod" // pod Fedora en K8s (VDI)
    HardwareWSL        HardwareType = "wsl"         // Windows Subsystem for Linux
    HardwareWebOnly    HardwareType = "web_only"    // solo navegador, sin sbos-client
)

// ContextStatus es el estado del ciclo de vida de una sesión de contexto.
type ContextStatus string

const (
    StatusActive    ContextStatus = "active"    // sesión válida y activa
    StatusSwitched  ContextStatus = "switched"  // reemplazada por context switch
    StatusExpired   ContextStatus = "expired"   // TTL vencido
    StatusInvalid   ContextStatus = "invalid"   // invalidada manualmente
)

// DeviceContext representa un dispositivo registrado sin usuario autenticado.
// Creado cuando sbos-client se conecta al arranque del dispositivo.
// Identificado por dctx_id. Promovido a SessionContext al autenticarse el usuario.
//
// TTL: 8 horas (dispositivos) — ISO 27001 A.9.4.2.
type DeviceContext struct {
    DctxID       string       `db:"dctx_id" json:"dctx_id"`
    Tenant       string       `db:"tenant" json:"tenant"`
    Hostname     string       `db:"hostname" json:"hostname"`
    DeviceUUID   string       `db:"device_uuid" json:"device_uuid,omitempty"`
    IPAddress    string       `db:"ip_address" json:"ip_address,omitempty"`
    MACAddress   string       `db:"mac_address" json:"mac_address,omitempty"`
    HardwareType HardwareType `db:"hardware_type" json:"hardware_type"`
    RegisteredAt time.Time    `db:"registered_at" json:"registered_at"`
    LastSeenAt   time.Time    `db:"last_seen_at" json:"last_seen_at"`
    Status       string       `db:"status" json:"status"`
}

// SessionContext representa una sesión de usuario autenticado.
// Creado al promover un DeviceContext tras autenticación exitosa en Keycloak.
// Identificado por ctx_id. Propagado vía W3C Trace Context (traceparent).
//
// TTL: 12 horas (sesiones) — sincronizado con Keycloak session TTL.
// El ctx_id es inmutable una vez creado (P3 SBOS-049).
type SessionContext struct {
    CtxID        string        `db:"ctx_id" json:"ctx_id"`
    DctxIDPrev   string        `db:"dctx_id_prev" json:"dctx_id_prev,omitempty"`
    UserID       string        `db:"user_id" json:"user_id"`
    KCSessionID  string        `db:"kc_session_id" json:"kc_session_id"`

    // Jerarquía organizacional SBOS
    Tenant    string `db:"tenant" json:"tenant"`
    Empresa   string `db:"empresa" json:"empresa,omitempty"`
    Sucursal  string `db:"sucursal" json:"sucursal,omitempty"`
    PosLogico string `db:"pos_logico" json:"pos_logico,omitempty"`
    DeviceID  string `db:"device_id" json:"device_id,omitempty"`

    // Infraestructura K8s
    Pod       string       `db:"pod" json:"pod,omitempty"`
    Namespace string       `db:"namespace" json:"namespace,omitempty"`
    Node      string       `db:"node" json:"node,omitempty"`
    Cluster   string       `db:"cluster" json:"cluster,omitempty"`
    VPS       string       `db:"vps" json:"vps,omitempty"`
    Geo       string       `db:"geo" json:"geo,omitempty"`
    Hardware  HardwareType `db:"hardware_type" json:"hardware_type"`

    // Trazabilidad
    Traceparent string `db:"traceparent" json:"traceparent"` // W3C Trace Context
    BitMask     string `db:"bitmask" json:"bitmask"`         // hex calculado por bAuth

    // Ciclo de vida
    CreatedAt     time.Time     `db:"created_at" json:"created_at"`
    ExpiresAt     time.Time     `db:"expires_at" json:"expires_at"`
    SwitchedAt    *time.Time    `db:"switched_at" json:"switched_at,omitempty"`
    InvalidatedAt *time.Time    `db:"invalidated_at" json:"invalidated_at,omitempty"`
    Status        ContextStatus `db:"status" json:"status"`
}

// RegisterDeviceParams son los parámetros para registrar un dispositivo.
type RegisterDeviceParams struct {
    TenantID     string       `json:"tenant_id"`
    Hostname     string       `json:"hostname"`
    DeviceUUID   string       `json:"device_uuid,omitempty"`
    IPAddress    string       `json:"ip_address,omitempty"`
    MACAddress   string       `json:"mac_address,omitempty"`
    HardwareType HardwareType `json:"hardware_type,omitempty"`
}

// PromoteParams son los parámetros para promover un dispositivo a sesión.
type PromoteParams struct {
    DctxID      string `json:"dctx_id"`
    UserID      string `json:"user_id"`
    KCSessionID string `json:"kc_session_id"`
    Empresa     string `json:"empresa,omitempty"`
    Sucursal    string `json:"sucursal,omitempty"`
    PosLogico   string `json:"pos_logico,omitempty"`
    Traceparent string `json:"traceparent"` // W3C Trace Context del login
    BitMask     string `json:"bitmask"`     // calculado por bAuth
}

// SwitchParams son los parámetros para un cambio de contexto.
type SwitchParams struct {
    Empresa     string `json:"empresa,omitempty"`
    Sucursal    string `json:"sucursal,omitempty"`
    PosLogico   string `json:"pos_logico,omitempty"`
    Traceparent string `json:"traceparent"`
    BitMask     string `json:"bitmask"`
}

// ValidateResult es el resultado de validar un ctx_id.
type ValidateResult struct {
    Valid       bool          `json:"valid"`
    CtxID       string        `json:"ctx_id,omitempty"`
    UserID      string        `json:"user_id,omitempty"`
    Tenant      string        `json:"tenant,omitempty"`
    BitMask     string        `json:"bitmask,omitempty"`
    ExpiresAt   time.Time     `json:"expires_at,omitempty"`
    Reason      string        `json:"reason,omitempty"` // si no válido
}

// TTLDevice es el TTL para DeviceContexts (8 horas).
// ISO 27001 A.9.4.2 — máximo permitido para sesiones de dispositivo.
const TTLDevice = 8 * time.Hour

// TTLSession es el TTL para SessionContexts (12 horas).
// Sincronizado con Keycloak session TTL.
const TTLSession = 12 * time.Hour

// RedisDB1 es la base de datos Redis usada como Context Registry.
// Redis DB0 = caché general, DB1 = Context Plane, DB2 = sagas.
const RedisDB1 = 1
```

**Test F5.1:**
```go
func TestTTL_MinimoYMaximo(t *testing.T) {
    assert.Equal(t, 8*time.Hour,  TTLDevice,  "TTL dispositivo debe ser 8h")
    assert.Equal(t, 12*time.Hour, TTLSession, "TTL sesión debe ser 12h")
}

func TestHardwareTypes_Validos(t *testing.T) {
    tipos := []HardwareType{HardwarePhysical, HardwareLogicalPod, HardwareWSL, HardwareWebOnly}
    for _, t := range tipos {
        assert.NotEmpty(t, string(t))
    }
}
```

---

## ÁTOMO F5.2 — `internal/context/service.go`

**Objetivo:** Implementar la lógica de negocio del Context Plane con 8 métodos.  
**Tiempo estimado:** 90 minutos

```go
package context

import (
    "fmt"
    "sync"
    "time"
    // logger
)

// Service implementa la lógica de negocio del Context Plane.
//
// Thread safety: Service es seguro para uso concurrente.
// El campo mu protege los mapas en memoria durante operaciones de lectura/escritura.
//
// Arquitectura: Service usa Store como capa de persistencia (PostgreSQL + Redis).
// El Service NO conoce los detalles de SQL — esa es responsabilidad de Store.
type Service struct {
    mu      sync.RWMutex
    store   *Store
    logger  Logger
}

// NewService crea un Service con la store inyectada.
func NewService(store *Store, logger Logger) *Service {
    return &Service{store: store, logger: logger}
}

// RegisterDevice registra un dispositivo y retorna su dctx_id.
//
// Es idempotente: si el hostname ya está registrado para el tenant,
// retorna el dctx_id existente en lugar de crear uno nuevo.
//
// SLO: debe responder en < 2 segundos (criterio C-13 BOS-REPAIR-01).
//
// Retorna:
//   - *DeviceContext con el dctx_id asignado
//   - error si tenant o hostname están vacíos, o si falla la persistencia
func (s *Service) RegisterDevice(p RegisterDeviceParams) (*DeviceContext, error) {
    if p.TenantID == "" {
        return nil, fmt.Errorf("context.RegisterDevice: tenant_id requerido")
    }
    if p.Hostname == "" {
        return nil, fmt.Errorf("context.RegisterDevice: hostname requerido")
    }

    // Verificar idempotencia: mismo tenant+hostname → mismo dctx_id
    existing, err := s.store.FindDevice(p.TenantID, p.Hostname)
    if err == nil && existing != nil {
        s.logger.Info("context: device re-registrado (idempotente)",
            "dctx_id", existing.DctxID, "hostname", p.Hostname)
        return existing, nil
    }

    dc := &DeviceContext{
        DctxID:       generateID("dctx"),
        Tenant:       p.TenantID,
        Hostname:     p.Hostname,
        DeviceUUID:   p.DeviceUUID,
        IPAddress:    p.IPAddress,
        MACAddress:   p.MACAddress,
        HardwareType: p.HardwareType,
        RegisteredAt: time.Now().UTC(),
        LastSeenAt:   time.Now().UTC(),
        Status:       "active",
    }

    if err := s.store.SaveDevice(dc); err != nil {
        return nil, fmt.Errorf("context.RegisterDevice: %w", err)
    }

    s.logger.Info("context: dispositivo registrado", "dctx_id", dc.DctxID, "tenant", p.TenantID)
    return dc, nil
}

// Promote promueve un DeviceContext a SessionContext tras autenticación exitosa.
//
// Crea un ctx_id nuevo. El ctx_id es inmutable — no se puede reusar
// ni modificar una vez creado (P3 SBOS-049).
//
// Retorna error si el dctx_id no existe o si el dispositivo no está activo.
func (s *Service) Promote(p PromoteParams) (*SessionContext, error) {
    if p.DctxID == "" || p.UserID == "" || p.KCSessionID == "" {
        return nil, fmt.Errorf("context.Promote: dctx_id, user_id y kc_session_id requeridos")
    }

    dc, err := s.store.GetDevice(p.DctxID)
    if err != nil {
        return nil, fmt.Errorf("context.Promote: device %s: %w", p.DctxID, err)
    }
    if dc.Status != "active" {
        return nil, fmt.Errorf("context.Promote: dispositivo %s no activo (status: %s)", p.DctxID, dc.Status)
    }

    sc := &SessionContext{
        CtxID:       generateID("ctx"),
        DctxIDPrev:  p.DctxID,
        UserID:      p.UserID,
        KCSessionID: p.KCSessionID,
        Tenant:      dc.Tenant,
        Empresa:     p.Empresa,
        Sucursal:    p.Sucursal,
        PosLogico:   p.PosLogico,
        DeviceID:    dc.DeviceUUID,
        Hardware:    dc.HardwareType,
        Traceparent: p.Traceparent,
        BitMask:     p.BitMask,
        CreatedAt:   time.Now().UTC(),
        ExpiresAt:   time.Now().UTC().Add(TTLSession),
        Status:      StatusActive,
    }

    if err := s.store.SaveSession(sc); err != nil {
        return nil, fmt.Errorf("context.Promote: guardar sesión: %w", err)
    }

    s.logger.Info("context: sesión promovida",
        "ctx_id", sc.CtxID, "user", p.UserID, "tenant", dc.Tenant)
    return sc, nil
}

// Switch crea una nueva sesión de contexto cambiando empresa/sucursal/pos.
//
// La sesión anterior queda en status 'switched'. La nueva sesión hereda
// el usuario, tenant y device de la sesión previa.
func (s *Service) Switch(ctxID string, p SwitchParams) (*SessionContext, error) {
    old, err := s.Get(ctxID)
    if err != nil {
        return nil, fmt.Errorf("context.Switch: obtener sesión %s: %w", ctxID, err)
    }

    // Marcar sesión anterior como switched
    now := time.Now().UTC()
    old.Status = StatusSwitched
    old.SwitchedAt = &now
    if err := s.store.UpdateSession(old); err != nil {
        return nil, fmt.Errorf("context.Switch: actualizar sesión anterior: %w", err)
    }

    // Crear nueva sesión
    newSC := &SessionContext{
        CtxID:       generateID("ctx"),
        DctxIDPrev:  old.DctxIDPrev,
        UserID:      old.UserID,
        KCSessionID: old.KCSessionID,
        Tenant:      old.Tenant,
        Empresa:     p.Empresa,
        Sucursal:    p.Sucursal,
        PosLogico:   p.PosLogico,
        DeviceID:    old.DeviceID,
        Hardware:    old.Hardware,
        Traceparent: p.Traceparent,
        BitMask:     p.BitMask,
        CreatedAt:   time.Now().UTC(),
        ExpiresAt:   time.Now().UTC().Add(TTLSession),
        Status:      StatusActive,
    }

    if err := s.store.SaveSession(newSC); err != nil {
        return nil, fmt.Errorf("context.Switch: guardar nueva sesión: %w", err)
    }

    return newSC, nil
}

// Invalidate invalida una sesión de contexto inmediatamente.
// La sesión queda en status 'invalid'. Las auditorías la conservan.
func (s *Service) Invalidate(ctxID string) error {
    sc, err := s.Get(ctxID)
    if err != nil {
        return fmt.Errorf("context.Invalidate: %w", err)
    }
    now := time.Now().UTC()
    sc.Status = StatusInvalid
    sc.InvalidatedAt = &now
    if err := s.store.UpdateSession(sc); err != nil {
        return fmt.Errorf("context.Invalidate: %w", err)
    }
    // Eliminar del cache Redis
    s.store.DeleteFromCache(ctxID)
    return nil
}

// Get obtiene una sesión activa por ctx_id.
// Retorna error si la sesión no existe, está expirada o fue invalidada.
func (s *Service) Get(ctxID string) (*SessionContext, error) {
    // 1. Intentar desde Redis cache (O(1))
    if sc, err := s.store.GetFromCache(ctxID); err == nil && sc != nil {
        if sc.Status == StatusActive && time.Now().UTC().Before(sc.ExpiresAt) {
            return sc, nil
        }
    }
    // 2. Fallback a PostgreSQL (degradación elegante — P7 SBOS-049)
    sc, err := s.store.GetSession(ctxID)
    if err != nil {
        return nil, fmt.Errorf("context.Get: %w", err)
    }
    if sc.Status != StatusActive {
        return nil, fmt.Errorf("context.Get: ctx_id %s en estado %s", ctxID, sc.Status)
    }
    if time.Now().UTC().After(sc.ExpiresAt) {
        return nil, fmt.Errorf("context.Get: ctx_id %s expirado", ctxID)
    }
    return sc, nil
}

// ListByTenant lista todas las sesiones activas de un tenant.
func (s *Service) ListByTenant(tenantID string) ([]*SessionContext, error) {
    return s.store.ListSessions(tenantID, StatusActive)
}

// InvalidateAllByTenant invalida todas las sesiones activas de un tenant.
// Retorna el número de sesiones invalidadas.
func (s *Service) InvalidateAllByTenant(tenantID string) (int, error) {
    sessions, err := s.ListByTenant(tenantID)
    if err != nil {
        return 0, fmt.Errorf("context.InvalidateAllByTenant: %w", err)
    }
    count := 0
    for _, sc := range sessions {
        if err := s.Invalidate(sc.CtxID); err == nil {
            count++
        }
    }
    return count, nil
}

// Validate verifica que un traceparent+tenantID corresponde a una sesión activa.
// Usado por el Kong plugin SBOS-Context para validar cada request.
func (s *Service) Validate(traceparent, tenantID string) (*ValidateResult, error) {
    // Extraer ctx_id del traceparent (los últimos 16 chars del trace-id)
    // según W3C Trace Context spec: traceparent = "00-{trace-id}-{parent-id}-{flags}"
    ctxID, err := extractCtxFromTraceparent(traceparent)
    if err != nil {
        return &ValidateResult{Valid: false, Reason: "traceparent inválido"}, nil
    }

    sc, err := s.Get(ctxID)
    if err != nil {
        return &ValidateResult{Valid: false, Reason: err.Error()}, nil
    }
    if sc.Tenant != tenantID {
        return &ValidateResult{Valid: false, Reason: "tenant no coincide"}, nil
    }

    return &ValidateResult{
        Valid:     true,
        CtxID:    sc.CtxID,
        UserID:   sc.UserID,
        Tenant:   sc.Tenant,
        BitMask:  sc.BitMask,
        ExpiresAt: sc.ExpiresAt,
    }, nil
}

// generateID genera un identificador único con prefijo.
// Formato: "{prefix}-{uuid-sin-guiones[:16]}"
func generateID(prefix string) string {
    // Usar crypto/rand o uuid library según disponibilidad en go.mod
    // Formato: ctx-88291a4f9... o dctx-3bc72f1a9...
    // TODO: implementar según la librería disponible en go.mod
    return prefix + "-" + "implementar"
}

// extractCtxFromTraceparent extrae el ctx_id del header W3C traceparent.
func extractCtxFromTraceparent(traceparent string) (string, error) {
    // W3C Trace Context: "00-{32-hex trace-id}-{16-hex parent-id}-{2-hex flags}"
    // El ctx_id se embebe en el trace-id al momento de crear la sesión
    if len(traceparent) < 55 {
        return "", fmt.Errorf("traceparent inválido: longitud %d", len(traceparent))
    }
    // TODO: parsear según W3C spec
    return "", fmt.Errorf("context: extractCtxFromTraceparent: implementar")
}
```

**Tests F5.2:**
```go
func TestService_RegisterDevice_Idempotente(t *testing.T) {
    svc := newTestService(t)
    p := RegisterDeviceParams{TenantID: "skull", Hostname: "pos-01"}

    dc1, err1 := svc.RegisterDevice(p)
    dc2, err2 := svc.RegisterDevice(p) // segunda llamada

    require.NoError(t, err1)
    require.NoError(t, err2)
    assert.Equal(t, dc1.DctxID, dc2.DctxID, "mismo hostname → mismo dctx_id")
}

func TestService_Promote_CreaNuevoCtxID(t *testing.T) {
    svc := newTestService(t)
    dc, _ := svc.RegisterDevice(RegisterDeviceParams{TenantID: "skull", Hostname: "pos-01"})

    sc, err := svc.Promote(PromoteParams{
        DctxID: dc.DctxID, UserID: "user-123", KCSessionID: "kc-456",
        Traceparent: "00-abc123-def456-01", BitMask: "0x1F",
    })

    require.NoError(t, err)
    assert.NotEmpty(t, sc.CtxID)
    assert.True(t, sc.ExpiresAt.After(time.Now()))
}

func TestService_Invalidate_YaNoValido(t *testing.T) {
    svc := newTestService(t)
    // ... setup
    err := svc.Invalidate("ctx-test-123")
    require.NoError(t, err)

    _, err = svc.Get("ctx-test-123")
    assert.Error(t, err, "ctx invalidado no debe ser accesible")
}
```

---

## ÁTOMO F5.3 — `internal/context/store.go` — PostgreSQL + Redis

**Objetivo:** Persistencia en bkernel_db y cache en Redis DB1.  
**Tiempo estimado:** 90 minutos

### Aplicar el DDL en bkernel_db

```bash
# Crear el archivo de migración:
mkdir -p migrations/bkernel_db/
cat > migrations/bkernel_db/001_context_plane.sql << 'SQL'
-- Migration: 001_context_plane.sql
-- Context Plane — SBOS-049
-- Fecha: 2026-06-XX
-- Átomo: F5.3

BEGIN;

CREATE TABLE IF NOT EXISTS context_sessions (
    ctx_id          VARCHAR(64)  PRIMARY KEY,
    dctx_id_prev    VARCHAR(64),
    user_id         VARCHAR(128) NOT NULL,
    kc_session_id   VARCHAR(128) NOT NULL,
    tenant          VARCHAR(64)  NOT NULL,
    empresa         VARCHAR(64),
    sucursal        VARCHAR(64),
    pos_logico      VARCHAR(64),
    device_id       VARCHAR(128),
    hardware_type   VARCHAR(20) CHECK (hardware_type IN ('physical','logical_pod','wsl','web_only')),
    pod             VARCHAR(128),
    namespace       VARCHAR(64),
    node            VARCHAR(64),
    cluster         VARCHAR(64),
    vps             VARCHAR(64),
    geo             VARCHAR(128),
    traceparent     VARCHAR(128),
    bitmask         VARCHAR(20),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ NOT NULL,
    switched_at     TIMESTAMPTZ,
    invalidated_at  TIMESTAMPTZ,
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','switched','expired','invalid'))
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS registered_devices (
    dctx_id         VARCHAR(64)  PRIMARY KEY,
    tenant          VARCHAR(64)  NOT NULL,
    hostname        VARCHAR(255) NOT NULL,
    device_uuid     VARCHAR(64),
    ip_address      INET,
    mac_address     VARCHAR(17),
    hardware_type   VARCHAR(20),
    registered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at    TIMESTAMPTZ,
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','suspended','revoked'))
);

CREATE INDEX IF NOT EXISTS idx_ctx_sessions_user    ON context_sessions (user_id, status);
CREATE INDEX IF NOT EXISTS idx_ctx_sessions_tenant  ON context_sessions (tenant, empresa, status);
CREATE INDEX IF NOT EXISTS idx_ctx_sessions_active  ON context_sessions (expires_at) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_reg_devices_tenant   ON registered_devices (tenant, status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_reg_devices_hostname ON registered_devices (tenant, hostname);

COMMIT;
SQL

# Aplicar en bkernel_db:
kubectl exec -n sbos-data postgresql-0 -- \
  psql -U bosagent -d bkernel_db -f - < migrations/bkernel_db/001_context_plane.sql \
  && echo "✅ DDL aplicado"

# Verificar:
kubectl exec -n sbos-data postgresql-0 -- \
  psql -U bosagent -d bkernel_db -c "\dt context_sessions registered_devices"
```

### Crear `internal/context/store.go`

```go
package context

import (
    "context"
    "encoding/json"
    "fmt"
    "time"

    "github.com/jackc/pgx/v5/pgxpool"
    "github.com/redis/go-redis/v9"
)

// Store gestiona la persistencia del Context Plane.
//
// Arquitectura de dos capas:
//   - Redis DB1: cache O(1) con TTL sincronizado
//   - PostgreSQL bkernel_db: store persistente (fuente de verdad)
//
// Degradación elegante (P7 SBOS-049): si Redis no está disponible,
// todas las operaciones continúan usando solo PostgreSQL.
type Store struct {
    pg    *pgxpool.Pool
    redis *redis.Client
}

// NewStore crea un Store con conexiones inyectadas.
// redis puede ser nil — el Store funciona en modo degradado (solo PG).
func NewStore(pg *pgxpool.Pool, redisCli *redis.Client) *Store {
    return &Store{pg: pg, redis: redisCli}
}

// SaveSession persiste una SessionContext en PostgreSQL y la cachea en Redis.
func (st *Store) SaveSession(sc *SessionContext) error {
    ctx := context.Background()

    // 1. Persistir en PostgreSQL
    _, err := st.pg.Exec(ctx, `
        INSERT INTO context_sessions (
            ctx_id, dctx_id_prev, user_id, kc_session_id,
            tenant, empresa, sucursal, pos_logico, device_id, hardware_type,
            pod, namespace, node, cluster, vps, geo,
            traceparent, bitmask,
            created_at, expires_at, status
        ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
            $11, $12, $13, $14, $15, $16, $17, $18,
            $19, $20, $21
        )`,
        sc.CtxID, sc.DctxIDPrev, sc.UserID, sc.KCSessionID,
        sc.Tenant, sc.Empresa, sc.Sucursal, sc.PosLogico, sc.DeviceID, sc.Hardware,
        sc.Pod, sc.Namespace, sc.Node, sc.Cluster, sc.VPS, sc.Geo,
        sc.Traceparent, sc.BitMask,
        sc.CreatedAt, sc.ExpiresAt, sc.Status,
    )
    if err != nil {
        return fmt.Errorf("store.SaveSession: %w", err)
    }

    // 2. Cachear en Redis DB1 (degradación elegante: si falla Redis, no es error)
    st.cacheSession(sc)
    return nil
}

// GetSession obtiene una SessionContext desde PostgreSQL.
func (st *Store) GetSession(ctxID string) (*SessionContext, error) {
    ctx := context.Background()
    sc := &SessionContext{}
    err := st.pg.QueryRow(ctx, `
        SELECT ctx_id, dctx_id_prev, user_id, kc_session_id,
               tenant, empresa, sucursal, pos_logico, device_id, hardware_type,
               traceparent, bitmask, created_at, expires_at, status
        FROM context_sessions WHERE ctx_id = $1`, ctxID).
        Scan(
            &sc.CtxID, &sc.DctxIDPrev, &sc.UserID, &sc.KCSessionID,
            &sc.Tenant, &sc.Empresa, &sc.Sucursal, &sc.PosLogico, &sc.DeviceID, &sc.Hardware,
            &sc.Traceparent, &sc.BitMask, &sc.CreatedAt, &sc.ExpiresAt, &sc.Status,
        )
    if err != nil {
        return nil, fmt.Errorf("store.GetSession: ctx_id %s: %w", ctxID, err)
    }
    return sc, nil
}

// GetFromCache obtiene una SessionContext desde Redis DB1.
// Retorna nil, nil si no está en cache (no es error).
func (st *Store) GetFromCache(ctxID string) (*SessionContext, error) {
    if st.redis == nil {
        return nil, nil
    }
    ctx := context.Background()
    data, err := st.redis.Get(ctx, "ctx:"+ctxID).Bytes()
    if err != nil {
        return nil, nil // cache miss — no es error
    }
    sc := &SessionContext{}
    if err := json.Unmarshal(data, sc); err != nil {
        return nil, nil
    }
    return sc, nil
}

// cacheSession guarda una SessionContext en Redis con TTL.
// Silencia errores — Redis es cache, no fuente de verdad.
func (st *Store) cacheSession(sc *SessionContext) {
    if st.redis == nil {
        return
    }
    ctx := context.Background()
    data, err := json.Marshal(sc)
    if err != nil {
        return
    }
    ttl := time.Until(sc.ExpiresAt)
    if ttl <= 0 {
        return
    }
    _ = st.redis.SetEx(ctx, "ctx:"+sc.CtxID, data, ttl)
}

// DeleteFromCache elimina una SessionContext del cache Redis.
func (st *Store) DeleteFromCache(ctxID string) {
    if st.redis == nil {
        return
    }
    _ = st.redis.Del(context.Background(), "ctx:"+ctxID)
}

// UpdateSession actualiza el estado de una SessionContext en PostgreSQL y Redis.
func (st *Store) UpdateSession(sc *SessionContext) error {
    ctx := context.Background()
    _, err := st.pg.Exec(ctx, `
        UPDATE context_sessions
        SET status = $1, switched_at = $2, invalidated_at = $3
        WHERE ctx_id = $4`,
        sc.Status, sc.SwitchedAt, sc.InvalidatedAt, sc.CtxID,
    )
    if err != nil {
        return fmt.Errorf("store.UpdateSession: %w", err)
    }
    st.cacheSession(sc)
    return nil
}

// ListSessions lista sesiones por tenant y status.
func (st *Store) ListSessions(tenantID string, status ContextStatus) ([]*SessionContext, error) {
    ctx := context.Background()
    rows, err := st.pg.Query(ctx, `
        SELECT ctx_id, user_id, tenant, empresa, sucursal, pos_logico,
               bitmask, created_at, expires_at, status
        FROM context_sessions
        WHERE tenant = $1 AND status = $2
        ORDER BY created_at DESC`, tenantID, status)
    if err != nil {
        return nil, fmt.Errorf("store.ListSessions: %w", err)
    }
    defer rows.Close()

    var sessions []*SessionContext
    for rows.Next() {
        sc := &SessionContext{}
        if err := rows.Scan(&sc.CtxID, &sc.UserID, &sc.Tenant, &sc.Empresa,
            &sc.Sucursal, &sc.PosLogico, &sc.BitMask,
            &sc.CreatedAt, &sc.ExpiresAt, &sc.Status); err != nil {
            continue
        }
        sessions = append(sessions, sc)
    }
    return sessions, nil
}

// SaveDevice persiste un DeviceContext en PostgreSQL.
func (st *Store) SaveDevice(dc *DeviceContext) error {
    ctx := context.Background()
    _, err := st.pg.Exec(ctx, `
        INSERT INTO registered_devices (dctx_id, tenant, hostname, device_uuid, hardware_type, registered_at, last_seen_at, status)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        dc.DctxID, dc.Tenant, dc.Hostname, dc.DeviceUUID, dc.HardwareType,
        dc.RegisteredAt, dc.LastSeenAt, dc.Status,
    )
    if err != nil {
        return fmt.Errorf("store.SaveDevice: %w", err)
    }
    return nil
}

// GetDevice obtiene un DeviceContext por dctx_id.
func (st *Store) GetDevice(dctxID string) (*DeviceContext, error) {
    ctx := context.Background()
    dc := &DeviceContext{}
    err := st.pg.QueryRow(ctx, `
        SELECT dctx_id, tenant, hostname, device_uuid, hardware_type, registered_at, last_seen_at, status
        FROM registered_devices WHERE dctx_id = $1`, dctxID).
        Scan(&dc.DctxID, &dc.Tenant, &dc.Hostname, &dc.DeviceUUID,
            &dc.HardwareType, &dc.RegisteredAt, &dc.LastSeenAt, &dc.Status)
    if err != nil {
        return nil, fmt.Errorf("store.GetDevice: dctx_id %s: %w", dctxID, err)
    }
    return dc, nil
}

// FindDevice busca un dispositivo por tenant+hostname (para idempotencia).
func (st *Store) FindDevice(tenantID, hostname string) (*DeviceContext, error) {
    ctx := context.Background()
    dc := &DeviceContext{}
    err := st.pg.QueryRow(ctx, `
        SELECT dctx_id, tenant, hostname, hardware_type, status
        FROM registered_devices WHERE tenant = $1 AND hostname = $2`,
        tenantID, hostname).
        Scan(&dc.DctxID, &dc.Tenant, &dc.Hostname, &dc.HardwareType, &dc.Status)
    if err != nil {
        return nil, fmt.Errorf("store.FindDevice: %w", err)
    }
    return dc, nil
}
```

**Tests F5.3:**
```go
func TestStore_CacheRedis_HitDeSegundaLectura(t *testing.T) {
    // Primera lectura: va a PG (cache miss)
    // Segunda lectura: viene de Redis (< 5ms)
    // Verificar que el tiempo de la segunda lectura es << primera
}

func TestStore_TTLExpira(t *testing.T) {
    // Crear sesión con TTL de 1 segundo
    // Esperar 2 segundos
    // Verificar que Get() retorna error
}

func TestStore_DegradacionElegante_SinRedis(t *testing.T) {
    // Store con redis = nil
    // Todas las operaciones deben funcionar usando solo PG
    store := NewStore(testPG(t), nil)
    dc, err := store.SaveDevice(testDevice())
    assert.NoError(t, err) // debe funcionar sin Redis
}
```

---

## VERIFICACIÓN DE CIERRE F5.1-F5.3

```bash
echo "=== VERIFICACIÓN F5.1-F5.3 ==="
go build ./internal/context/ && echo "✅ BUILD"
go vet  ./internal/context/ && echo "✅ VET"
go test -race ./internal/context/... && echo "✅ TESTS"

# SLO C-13: RegisterDevice en < 2 segundos
time bosctl rpc bos.ctx.device.register \
  '{"tenant_id":"skull","hostname":"test-f5"}' \
  && echo "✅ SLO C-13 — tiempo medido arriba"

# Verificar tablas creadas:
kubectl exec -n sbos-data postgresql-0 -- \
  psql -U bosagent -d bkernel_db -c "\dt" | grep -E "context_sessions|registered_devices" \
  && echo "✅ DDL aplicado"
```

---

*EJECUCION-F5.1-F5.3-INSTRUCCIONES-AGENTE.md v1.0*  
*BOS-REPAIR · SKULL · SBOS · 08 de Junio 2026*  
*Fuentes: BOS-REPAIR-08, SBOS-049 §12 (DDL), W3C Trace Context, NIST SP 800-207, ISO 27001 A.8.15*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
