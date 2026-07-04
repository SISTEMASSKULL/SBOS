// Package bauth implementa el cliente JSON-RPC 2.0 del BOS hacia BauthAgent.
// M7.8 — BOS-REPAIR Plan Maestro v3 · ADR-020 Interface Dual.
//
// El BOS se comunica con bAuth exclusivamente vía Unix socket /run/bos/bauth.sock.
// Protocolo: JSON-RPC 2.0 una línea terminada en \n (sin prefijo de longitud).
// SBOS-050 P9: HTTP vetado entre daemons.
package bauth

import "time"

// DomainResult es el resultado de evaluación de un solo dominio (D1–D12).
// Campo Domain es entero (1–12), no string — bAuth retorna el código numérico.
type DomainResult struct {
	Domain    int   `json:"domain"`
	Result    int   `json:"result"`       // 0=DENY 1=ALLOW 2=STEPUP 3=UNKNOWN
	Approved  bool  `json:"policy_state"` // true si result == ALLOW
	LatencyNs int64 `json:"latency_ns"`
}

// SessionData contiene los datos de sesión de bauth.ses_context.
// Se obtiene vía bauth.ctx.get_session o como bloque session en bauth.context.evaluate.
// Acordado en C-BOS-003 y C-BOS-006.
type SessionData struct {
	CtxID          string    `json:"ctx_id"`
	TenantID       string    `json:"tenant_id"`
	EmpresaID      string    `json:"empresa_id"`
	SucursalID     string    `json:"sucursal_id,omitempty"`
	PosLogico      string    `json:"pos_logico,omitempty"`
	UserUUID       string    `json:"user_uuid"`
	BitmaskHex     string    `json:"bitmask_hex"`
	LoaCurrent     int       `json:"loa_current"`
	State          string    `json:"state"` // "ACTIVE", "INVALIDATED", "EXPIRED"
	DeviceID       string    `json:"device_id,omitempty"`
	DeviceHostname string    `json:"device_hostname,omitempty"`
	DeviceIP       string    `json:"device_ip,omitempty"`
	SessionKC      string    `json:"session_kc,omitempty"`
	Traceparent    string    `json:"traceparent,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
	ExpiresAt      time.Time `json:"expires_at"`
}

// IsActive retorna true si la sesión está activa y no ha expirado.
func (s *SessionData) IsActive() bool {
	return s.State == "ACTIVE" && time.Now().UTC().Before(s.ExpiresAt)
}

// ContextEvaluateResult es la respuesta de bauth.context.evaluate — versión ampliada.
// Incluye bloque session con datos de ses_context (C-BOS-003 acordado).
// Campo Session puede ser nil si bAuth no lo soporta aún (compatibilidad hacia atrás).
type ContextEvaluateResult struct {
	CtxID            string         `json:"ctx_id"`
	AtomSlug         string         `json:"atom_slug"`
	Session          *SessionData   `json:"session,omitempty"`
	DomainsEvaluated int            `json:"domains_evaluated"`
	Domains          []DomainResult `json:"domains"`
	Latency          struct {
		ResolveNs  int64 `json:"resolve_ns"`
		EvaluateNs int64 `json:"evaluate_ns"`
		TotalNs    int64 `json:"total_ns"`
	} `json:"latency"`
}

// Allowed retorna true si TODOS los dominios evaluados aprobaron.
func (r *ContextEvaluateResult) Allowed() bool {
	for _, d := range r.Domains {
		if !d.Approved {
			return false
		}
	}
	return len(r.Domains) > 0
}

// CreateCtxRequest es el request para bauth.ctx.create.
// BOS incluye todos los datos organizacionales y de dispositivo (C-BAUTH-001 acordado).
type CreateCtxRequest struct {
	TenantID       string `json:"tenant_id"`
	EmpresaID      string `json:"empresa_id"`
	SucursalID     string `json:"sucursal_id,omitempty"`
	PosLogico      string `json:"pos_logico"`
	TTLSeconds     int    `json:"ttl_seconds,omitempty"`
	DeviceID       string `json:"device_id,omitempty"`
	DeviceHostname string `json:"device_hostname,omitempty"`
	DeviceIP       string `json:"device_ip,omitempty"`
}

// CreateCtxResponse es la respuesta de bauth.ctx.create.
type CreateCtxResponse struct {
	Created     bool   `json:"created"`
	CtxID       string `json:"ctx_id"` // dctx_id: formato "ctx-XXXXXXXX"
	State       string `json:"state"`  // "pending"
	Traceparent string `json:"traceparent,omitempty"`
}

// PromoteCtxRequest es el request para bauth.ctx.promote.
// Transforma un dctx_id pre-auth en ctx_id post-auth con bitmask calculado.
type PromoteCtxRequest struct {
	CtxID      string `json:"ctx_id"`  // dctx_id a promover
	UserID     string `json:"user_id"` // UUID del usuario autenticado
	SessionKC  string `json:"session_kc,omitempty"`
	LoACurrent int    `json:"loa_current,omitempty"`
}

// PromoteCtxResponse es la respuesta de bauth.ctx.promote.
// El bitmask_hex está disponible de forma sincrónica en la misma transacción (C-BOS-004).
// Nota: ctx_id post-promote incluye user_id real (reemplaza el UUID cero del create).
type PromoteCtxResponse struct {
	Promoted    bool   `json:"promoted"`
	CtxID       string `json:"ctx_id"`  // formato compuesto: tenant:empresa:sucursal:pos:user:traceparent
	UserID      string `json:"user_id"` // UUID del usuario autenticado
	TenantID    string `json:"tenant_id"`
	EmpresaID   string `json:"empresa_id"`
	SucursalID  string `json:"sucursal_id"`
	PosLogico   string `json:"pos_logico"`
	BitmaskHex  string `json:"bitmask_hex"`
	BitmaskLen  int    `json:"bitmask_len"`
	LoACurrent  int    `json:"loa_current"`
	State       string `json:"state"` // "Active"
	Traceparent string `json:"traceparent"`
	Reason      string `json:"reason,omitempty"`
}
