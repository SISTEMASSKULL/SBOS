package domain

import (
	"fmt"
	"time"
)

// CtxService implementa el Context Plane de BOS (SBOS-049).
// BOS es el dueño del ctx_id — crea y valida todos los contextos del ecosistema.
// Sin dependencias externas: genera IDs deterministas a partir del tiempo y los parámetros.
type CtxService struct{}

// NewCtxService crea el servicio de contexto.
func NewCtxService() *CtxService { return &CtxService{} }

// CreateParams son los parámetros para crear un ctx_id.
type CreateParams struct {
	TenantID   string
	EmpresaID  string
	SucursalID string
	PosLogico  string
	UserID     string
	TTL        time.Duration
}

// Create genera un nuevo ctx_id con traceparent W3C (SBOS-049, RFC 7519).
func (svc *CtxService) Create(p CreateParams) (*CtxID, error) {
	if p.TenantID == "" {
		return nil, ErrTenantIDRequired
	}

	ttl := p.TTL
	if ttl <= 0 {
		ttl = 30 * time.Minute
	}

	now := time.Now().UTC()

	// TraceID W3C: 16 bytes = 32 hex chars.
	// Construido con nanosegundos + microsegundos para unicidad dentro de la misma instancia.
	traceID := fmt.Sprintf("%016x%016x", now.UnixNano(), now.UnixMicro())
	// SpanID W3C: 8 bytes = 16 hex chars.
	spanID := fmt.Sprintf("%016x", now.UnixNano()&0x7FFFFFFFFFFFFFFF)
	// Formato W3C Trace Context: version-traceId-spanId-flags
	traceParent := fmt.Sprintf("00-%s-%s-01", traceID, spanID)

	return &CtxID{
		TenantID:    p.TenantID,
		EmpresaID:   p.EmpresaID,
		SucursalID:  p.SucursalID,
		PosLogico:   p.PosLogico,
		UserID:      p.UserID,
		TraceParent: traceParent,
		SpanID:      spanID,
		CreatedAt:   now,
		ExpiresAt:   now.Add(ttl),
		Source:      "bos",
	}, nil
}

// Validate verifica la sintaxis de un traceparent W3C Trace Context.
// Regla: "00-<32 hex>-<16 hex>-<2 hex>"
// SBOS-049: toda operación del ecosistema debe incluir un traceparent válido.
func (svc *CtxService) Validate(traceParent, tenantID string) (*ValidateResult, error) {
	if traceParent == "" {
		return nil, ErrTraceparentRequired
	}

	valid := isValidTraceParent(traceParent)

	return &ValidateResult{
		Valid:       valid,
		TraceParent: traceParent,
		TenantID:    tenantID,
	}, nil
}

// isValidTraceParent verifica el formato W3C Trace Context spec.
// Formato: version(2)-traceId(32)-parentId(16)-flags(2) separados por '-'.
func isValidTraceParent(tp string) bool {
	// Longitud mínima: 2+1+32+1+16+1+2 = 55 caracteres
	if len(tp) < 55 {
		return false
	}
	// Versión: 2 hex chars
	if tp[0:2] != "00" {
		return false
	}
	// Separador tras versión
	if tp[2] != '-' {
		return false
	}
	// traceId: 32 hex chars
	traceID := tp[3:35]
	if !isHex(traceID) || allZero(traceID) {
		return false
	}
	// Separador tras traceId
	if tp[35] != '-' {
		return false
	}
	// parentId: 16 hex chars
	parentID := tp[36:52]
	if !isHex(parentID) || allZero(parentID) {
		return false
	}
	// Separador tras parentId
	if tp[52] != '-' {
		return false
	}
	// flags: 2 hex chars
	return isHex(tp[53:55])
}

func isHex(s string) bool {
	for _, c := range s {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
			return false
		}
	}
	return len(s) > 0
}

func allZero(s string) bool {
	if s == "" {
		return false
	}
	for _, c := range s {
		if c != '0' {
			return false
		}
	}
	return true
}
