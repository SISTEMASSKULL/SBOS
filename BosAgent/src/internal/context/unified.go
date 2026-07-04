// Package context — unified.go: UnifiedContext 9 dimensiones (SBOS-049 §5).
// M7.5 — BOS-REPAIR Plan Maestro v3.
//
// UnifiedContext es el objeto de contexto unificado que BOS entrega a los callers.
// Combina datos del Context Plane (BOS) con datos de sesión y evaluación de dominios (bAuth).
package context

import "time"

// DomainEval es la proyección local del resultado de evaluación de un dominio.
// Domain es entero 1–12 (código numérico que retorna bAuth).
type DomainEval struct {
	Domain   int  `json:"domain"`
	Result   int  `json:"result"` // 0=DENY 1=ALLOW 2=STEPUP 3=UNKNOWN
	Approved bool `json:"approved"`
}

// UnifiedContext es el contexto unificado de 9 dimensiones del Context Plane (SBOS-049).
//
// Dimensiones:
//  1. Identificación del contexto (CtxID, DctxID)
//  2. Identidad del usuario (UserID, LoA, BitmaskHex)
//  3. Dispositivo (DeviceID, DeviceHostname, DeviceIP)
//  4. Ubicación organizacional (TenantID, EmpresaID, SucursalID, PosLogico)
//  5. Temporalidad (CreatedAt, ExpiresAt, TTLSecs)
//  6. Nivel de confianza (TrustLevel)
//  7. Trazabilidad (Traceparent)
//  8. Evaluación de dominios (Domains)
//  9. Estado de la sesión (State)
type UnifiedContext struct {
	// Dimensión 1 — Identificación
	CtxID  string `json:"ctx_id"`            // ctx_id post-promote (bAuth, formato compuesto)
	DctxID string `json:"dctx_id,omitempty"` // dctx_id pre-auth (BOS, formato corto)

	// Dimensión 2 — Identidad del usuario
	UserID     string `json:"user_id"`
	LoA        int    `json:"loa"`                   // Level of Assurance 1-4 (RFC 9470)
	BitmaskHex string `json:"bitmask_hex,omitempty"` // 5808 bits — fuente de verdad bAuth

	// Dimensión 3 — Dispositivo
	DeviceID       string `json:"device_id,omitempty"`
	DeviceHostname string `json:"device_hostname,omitempty"`
	DeviceIP       string `json:"device_ip,omitempty"`

	// Dimensión 4 — Ubicación organizacional
	TenantID   string `json:"tenant_id"`
	EmpresaID  string `json:"empresa_id"`
	SucursalID string `json:"sucursal_id,omitempty"`
	PosLogico  string `json:"pos_logico,omitempty"`

	// Dimensión 5 — Temporalidad
	CreatedAt time.Time `json:"created_at"`
	ExpiresAt time.Time `json:"expires_at"`
	TTLSecs   int       `json:"ttl_secs"` // segundos hasta expiración

	// Dimensión 6 — Nivel de confianza
	TrustLevel string `json:"trust_level"` // "password", "mfa", "biometric", "hardware_key"

	// Dimensión 7 — Trazabilidad W3C
	Traceparent string `json:"traceparent,omitempty"`

	// Dimensión 8 — Evaluación de dominios D1–D12
	Domains []DomainEval `json:"domains,omitempty"`

	// Dimensión 9 — Estado de la sesión
	State string `json:"state"` // "ACTIVE", "INVALIDATED", "EXPIRED"
}

// IsActive retorna true si el contexto está activo y no ha expirado.
func (u *UnifiedContext) IsActive() bool {
	return u.State == "ACTIVE" && time.Now().UTC().Before(u.ExpiresAt)
}

// TrustLevel mapea un LoA al nombre descriptivo del nivel de confianza.
func TrustLevelFromLoA(loa int) string {
	switch loa {
	case 1:
		return "password"
	case 2:
		return "mfa"
	case 3:
		return "biometric"
	case 4:
		return "hardware_key"
	default:
		return "unknown"
	}
}
