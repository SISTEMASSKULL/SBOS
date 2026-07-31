// Package context — types.go: tipos fundamentales del Context Plane (SBOS-049).
// F5.1 — BOS-REPAIR Plan Maestro v3.
package context

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"
)

// TTL máximos según ISO 27001:2022 A.9.4.2.
const (
	MaxDeviceTTL  = 8 * time.Hour  // dispositivo pre-autenticado
	MaxSessionTTL = 12 * time.Hour // sesión post-autenticada
)

// ContextState representa el ciclo de vida de un contexto.
// 7 estados canónicos definidos en SBOS-049.
type ContextState int

const (
	StatePending  ContextState = iota // registrado, aún no validado
	StateActivo                         // validado, operativo
	StateSuspendido                     // suspendido por admin (tenant o usuario)
	StateBloqueado                      // bloqueado por política de seguridad
	StateInvalidado                     // invalidado explícitamente (logout, revocación)
	StateExpirado                       // TTL agotado
	StateArchivado                      // movido a histórico, inmutable
)

func (s ContextState) String() string {
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
		return fmt.Sprintf("UNKNOWN(%d)", int(s))
	}
}

// IsTerminal retorna true si el estado no admite más transiciones.
func (s ContextState) IsTerminal() bool {
	return s == StateInvalidado || s == StateExpirado || s == StateArchivado
}

// BitMask es la máscara de 64 bits que representa permisos/capacidades (bAuth).
// DeviceContext siempre tiene BitMask == 0 (pre-autenticado).
// SessionContext siempre tiene BitMask > 0 (post-autenticado).
type BitMask uint64

// Has retorna true si todos los bits de flag están presentes en b.
func (b BitMask) Has(flag BitMask) bool { return flag != 0 && b&flag == flag }

// Add retorna b con los bits de flag activados.
func (b BitMask) Add(flag BitMask) BitMask { return b | flag }

// Remove retorna b con los bits de flag desactivados.
func (b BitMask) Remove(flag BitMask) BitMask { return b &^ flag }

// IsZero retorna true si ningún bit está activado (estado pre-auth).
func (b BitMask) IsZero() bool { return b == 0 }

// DeviceContext es el contexto de dispositivo pre-autenticación (SBOS-049 §16.1).
// BitMask es siempre 0 — el dispositivo no tiene permisos hasta autenticar usuario.
// Se crea al registrar un dispositivo en BOS; se promueve a SessionContext en login.
type DeviceContext struct {
	DctxID    string       // UUID generado en RegisterDevice
	Hostname  string       // FQDN o hostname del dispositivo
	TenantID  string       // tenant al que pertenece el dispositivo
	NodeK8s   string       // nodo K8s donde corre el workload (vacío si es VDI)
	IP        string       // IP del dispositivo en el momento del registro
	BitMask   BitMask      // siempre 0 — invariante DeviceContext
	State     ContextState // ciclo de vida
	CreatedAt time.Time
	UpdatedAt time.Time
	ExpiresAt time.Time
}

// NewDeviceContext crea un DeviceContext con dctx_id generado, TTL = MaxDeviceTTL.
func NewDeviceContext(hostname, tenantID, nodeK8s, ip string) (*DeviceContext, error) {
	if hostname == "" || tenantID == "" {
		return nil, errors.New("context: hostname y tenantID son obligatorios en DeviceContext")
	}
	id, err := newContextID("dctx")
	if err != nil {
		return nil, fmt.Errorf("context: generar dctx_id: %w", err)
	}
	now := time.Now().UTC()
	return &DeviceContext{
		DctxID:    id,
		Hostname:  hostname,
		TenantID:  tenantID,
		NodeK8s:   nodeK8s,
		IP:        ip,
		BitMask:   0,
		State:     StatePending,
		CreatedAt: now,
		UpdatedAt: now,
		ExpiresAt: now.Add(MaxDeviceTTL),
	}, nil
}

// IsExpired retorna true si el contexto ha superado su ExpiresAt.
func (d *DeviceContext) IsExpired() bool {
	return time.Now().UTC().After(d.ExpiresAt)
}

// Validate verifica las invariantes del DeviceContext.
func (d *DeviceContext) Validate() error {
	if d.DctxID == "" {
		return errors.New("context: dctx_id vacío")
	}
	if d.Hostname == "" || d.TenantID == "" {
		return errors.New("context: hostname y tenantID obligatorios")
	}
	if d.BitMask != 0 {
		return errors.New("context: DeviceContext debe tener BitMask == 0 (pre-auth)")
	}
	return nil
}

// SessionContext es el contexto de sesión post-autenticación (SBOS-049 §5).
// BitMask > 0 — el usuario tiene permisos calculados por bAuth.
// Se crea al hacer login; se destruye al logout o por TTL.
// Vincula el dctx_id anterior para preservar la historia pre-auth.
type SessionContext struct {
	CtxID       string // ID compuesto: "ctx-{tenant}-{empresa}-{random}"
	DctxID      string // dctx_id del dispositivo origen (historia pre-auth)
	TenantID    string
	EmpresaID   string
	SucursalID  string
	PosLogico   string
	UserID      string
	BitMask     BitMask // > 0 post-auth — invariante SessionContext
	LoA         int     // Level of Assurance 1-4 (RFC 9470)
	State       ContextState
	Traceparent string // W3C traceparent al momento de creación
	CreatedAt   time.Time
	ExpiresAt   time.Time
}

// NewSessionContext crea un SessionContext con ctx_id generado, TTL = MaxSessionTTL.
// bitMask debe ser > 0 (invariante post-auth).
func NewSessionContext(dctxID, tenantID, empresaID, sucursalID, posLogico, userID string,
	bitMask BitMask, loA int, traceparent string) (*SessionContext, error) {
	if tenantID == "" || userID == "" {
		return nil, errors.New("context: tenantID y userID son obligatorios en SessionContext")
	}
	if bitMask == 0 {
		return nil, errors.New("context: SessionContext requiere BitMask > 0 (post-auth)")
	}
	if loA < 1 || loA > 4 {
		return nil, fmt.Errorf("context: LoA inválido %d — debe ser 1-4 (RFC 9470)", loA)
	}
	id, err := newContextID("ctx")
	if err != nil {
		return nil, fmt.Errorf("context: generar ctx_id: %w", err)
	}
	now := time.Now().UTC()
	return &SessionContext{
		CtxID:       id,
		DctxID:      dctxID,
		TenantID:    tenantID,
		EmpresaID:   empresaID,
		SucursalID:  sucursalID,
		PosLogico:   posLogico,
		UserID:      userID,
		BitMask:     bitMask,
		LoA:         loA,
		State:       StateActivo,
		Traceparent: traceparent,
		CreatedAt:   now,
		ExpiresAt:   now.Add(MaxSessionTTL),
	}, nil
}

// IsExpired retorna true si la sesión ha superado su ExpiresAt.
func (s *SessionContext) IsExpired() bool {
	return time.Now().UTC().After(s.ExpiresAt)
}

// Validate verifica las invariantes del SessionContext.
func (s *SessionContext) Validate() error {
	if s.CtxID == "" {
		return errors.New("context: ctx_id vacío")
	}
	if s.TenantID == "" || s.UserID == "" {
		return errors.New("context: tenantID y userID obligatorios")
	}
	if s.BitMask == 0 {
		return errors.New("context: SessionContext debe tener BitMask > 0 (post-auth)")
	}
	if s.LoA < 1 || s.LoA > 4 {
		return fmt.Errorf("context: LoA inválido %d", s.LoA)
	}
	return nil
}

// Label retorna la cadena de búsqueda compuesta para logs y auditoría.
// Formato: "tenant/empresa/sucursal/pos/user"
func (s *SessionContext) Label() string {
	parts := []string{s.TenantID, s.EmpresaID, s.SucursalID, s.PosLogico, s.UserID}
	return strings.Join(parts, "/")
}

// newContextID genera un ID con prefijo dado y 8 bytes aleatorios.
// Ejemplo: "ctx-4a2f9b1c" o "dctx-7e83ab2d".
func newContextID(prefix string) (string, error) {
	b := make([]byte, 8)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return prefix + "-" + hex.EncodeToString(b), nil
}
