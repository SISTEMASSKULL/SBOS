// Package server — Handlers JSON-RPC 2.0 para bos.web.domain.*.
//
// BC-06: Domain Manager S16-webserver
// Métodos:
//   bos.web.domain.add        — registrar dominio + vhost nginx
//   bos.web.domain.remove     — eliminar dominio + vhost nginx
//   bos.web.domain.list       — listar todos los dominios registrados
//   bos.web.domain.resolve    — resolver un dominio a su destino
//   bos.web.domain.ssl_status — consultar estado SSL del dominio
//
// Principio P3: los handlers son adaptadores delgados — toda la lógica
// vive en domain.WebDomainService.
package server

import (
	"bos/internal/domain"
)

// webDomainSvc retorna el servicio de dominios web.
// Si no fue inyectado, inicializa un servicio en memoria con nginx noop.
// Nil-safe: nunca retorna nil.
func (s *Server) webDomainSvc() *domain.WebDomainService {
	if s.webDomain == nil {
		s.webDomain = domain.NewWebDomainService(
			domain.NewMemWebDomain(),
			domain.NoopNginx{},
		)
	}
	return s.webDomain
}

// ── bos.web.domain.add ───────────────────────────────────────────────────────

// rpcWebDomainAdd registra un nuevo dominio web en nginx.
//
// Params:
//   domain   string — hostname RFC 1123 (ej: api.empresa.com)
//   target   string — IP o host:puerto de destino (ej: 10.0.0.5:8080)
//   ssl_auto bool   — si true, solicita certificado Let's Encrypt automáticamente
//   ctx_id   string — contexto de auditoría (SBOS-049)
//
// Returns: WebDomainRecord { domain, target, ssl_auto, created_at }
func (s *Server) rpcWebDomainAdd(req *RPCRequest) RPCResponse {
	var p struct {
		Domain  string `json:"domain"`
		Target  string `json:"target"`
		SSLAuto bool   `json:"ssl_auto"`
		CtxID   string `json:"ctx_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "parámetros inválidos"))
	}

	rec, err := s.webDomainSvc().Add(p.Domain, p.Target, p.SSLAuto, p.CtxID)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, rec)
}

// ── bos.web.domain.remove ────────────────────────────────────────────────────

// rpcWebDomainRemove elimina un dominio web y su vhost nginx.
//
// Params:
//   domain string — hostname a eliminar
//   ctx_id string — contexto de auditoría (SBOS-049)
//
// Returns: { ok: true }
func (s *Server) rpcWebDomainRemove(req *RPCRequest) RPCResponse {
	var p struct {
		Domain string `json:"domain"`
		CtxID  string `json:"ctx_id"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "parámetros inválidos"))
	}

	if err := s.webDomainSvc().Remove(p.Domain, p.CtxID); err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, map[string]bool{"ok": true})
}

// ── bos.web.domain.list ──────────────────────────────────────────────────────

// rpcWebDomainList lista todos los dominios web registrados.
//
// Params: ninguno
//
// Returns: { domains: [WebDomainRecord], total: int }
func (s *Server) rpcWebDomainList(_ *RPCRequest) RPCResponse {
	req := &RPCRequest{}
	list := s.webDomainSvc().List()
	return rpcOK(req.ID, map[string]interface{}{
		"domains": list,
		"total":   len(list),
	})
}

// ── bos.web.domain.resolve ───────────────────────────────────────────────────

// rpcWebDomainResolve retorna el registro completo de un dominio.
//
// Params:
//   domain string — hostname a resolver
//
// Returns: WebDomainRecord
func (s *Server) rpcWebDomainResolve(req *RPCRequest) RPCResponse {
	var p struct {
		Domain string `json:"domain"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "parámetros inválidos"))
	}

	rec, err := s.webDomainSvc().Resolve(p.Domain)
	if err != nil {
		return rpcFail(req.ID, rpcError(ErrInternal, err.Error()))
	}
	return rpcOK(req.ID, rec)
}

// ── bos.web.domain.ssl_status ────────────────────────────────────────────────

// rpcWebDomainSSLStatus retorna el estado del certificado TLS del dominio.
//
// Params:
//   domain string — hostname a consultar
//
// Returns: SSLStatus { provisioned, expires_at, issuer, error }
func (s *Server) rpcWebDomainSSLStatus(req *RPCRequest) RPCResponse {
	var p struct {
		Domain string `json:"domain"`
	}
	if err := parseParams(req.Params, &p); err != nil {
		return rpcFail(req.ID, rpcError(ErrInvalidParams, "parámetros inválidos"))
	}

	status := s.webDomainSvc().SSLStatus(p.Domain)
	return rpcOK(req.ID, status)
}
