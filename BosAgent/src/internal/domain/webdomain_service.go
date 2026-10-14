// Package domain — WebDomainService: gestión de dominios web para S16-webserver.
//
// BC-06: Domain Manager S16
// Métodos JSON-RPC: bos.web.domain.add | remove | list | resolve | ssl_status
//
// Principio P3 (domain separation): este archivo no importa nada de server/.
// Principio P6 (sin credenciales hardcodeadas): rutas de certbot/nginx vienen
// del sistema operativo estándar — no se hardcodean tokens ni contraseñas.
package domain

import (
	"errors"
	"fmt"
	"regexp"
	"sync"
	"time"
)

// rfc1123Hostname valida que el nombre sea un hostname RFC 1123 válido.
// Acepta subdominios (ej: api.empresa.com) y dominios simples (empresa.com).
var rfc1123Hostname = regexp.MustCompile(`^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$`)

// SSLStatus describe el estado del certificado TLS de un dominio.
type SSLStatus struct {
	Provisioned bool      `json:"provisioned"`
	ExpiresAt   time.Time `json:"expires_at,omitempty"`
	Issuer      string    `json:"issuer,omitempty"`
	Error       string    `json:"error,omitempty"`
}

// WebDomainRecord representa un dominio web registrado en el sistema.
type WebDomainRecord struct {
	Domain    string    `json:"domain"`
	Target    string    `json:"target"`   // IP o CNAME de destino
	SSLAuto   bool      `json:"ssl_auto"` // provisionar SSL automáticamente (certbot)
	CreatedAt time.Time `json:"created_at"`
}

// WebDomainPort es el puerto de persistencia de dominios web.
// Implementado por MemWebDomain (tests) y futuras implementaciones con BD.
type WebDomainPort interface {
	Save(rec WebDomainRecord) error
	Delete(domain string) error
	Get(domain string) (WebDomainRecord, bool)
	List() []WebDomainRecord
}

// WebNginxPort es el puerto de operaciones nginx/certbot.
// Implementado por NoopNginx (tests) y NginxManager (producción).
type WebNginxPort interface {
	// Reload recarga la configuración de nginx sin reiniciar.
	Reload() error
	// ProvisionSSL solicita un certificado Let's Encrypt para el dominio.
	ProvisionSSL(domain string) error
	// SSLExpiresAt retorna la fecha de vencimiento del certificado activo.
	// Retorna error si no hay certificado.
	SSLExpiresAt(domain string) (time.Time, string, error)
	// WriteVhost escribe el archivo de vhost nginx para el dominio.
	WriteVhost(domain, target string) error
	// RemoveVhost elimina el archivo de vhost nginx del dominio.
	RemoveVhost(domain string) error
}

// WebDomainService gestiona el ciclo de vida de dominios web en S16-webserver.
//
// Thread safety: mu protege store y operaciones nginx secuenciales.
type WebDomainService struct {
	mu    sync.Mutex
	store WebDomainPort
	nginx WebNginxPort
}

// NewWebDomainService crea un nuevo servicio de dominios web.
func NewWebDomainService(store WebDomainPort, nginx WebNginxPort) *WebDomainService {
	return &WebDomainService{store: store, nginx: nginx}
}

// Add registra un nuevo dominio web y opcionalmente provisiona SSL.
//
// Retorna error si:
//   - el dominio no es un hostname RFC 1123 válido
//   - el dominio ya está registrado
//   - falla la escritura del vhost nginx
func (s *WebDomainService) Add(domain, target string, sslAuto bool, ctxID string) (WebDomainRecord, error) {
	if err := validateDomain(domain); err != nil {
		return WebDomainRecord{}, err
	}
	if target == "" {
		return WebDomainRecord{}, errors.New("target es requerido")
	}
	_ = ctxID // reservado para trazabilidad SBOS-049

	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.store.Get(domain); exists {
		return WebDomainRecord{}, fmt.Errorf("dominio ya registrado: %s", domain)
	}

	if err := s.nginx.WriteVhost(domain, target); err != nil {
		return WebDomainRecord{}, fmt.Errorf("escribir vhost nginx: %w", err)
	}

	rec := WebDomainRecord{
		Domain:    domain,
		Target:    target,
		SSLAuto:   sslAuto,
		CreatedAt: time.Now().UTC(),
	}
	if err := s.store.Save(rec); err != nil {
		// compensación: eliminar vhost si el guardado falla
		_ = s.nginx.RemoveVhost(domain)
		return WebDomainRecord{}, fmt.Errorf("guardar dominio: %w", err)
	}

	if err := s.nginx.Reload(); err != nil {
		return rec, fmt.Errorf("dominio guardado pero nginx no recargó: %w", err)
	}

	if sslAuto {
		// Provisionar SSL de forma asíncrona para no bloquear la respuesta RPC.
		// Fallo de SSL no revierte el registro del dominio.
		go func() { _ = s.nginx.ProvisionSSL(domain) }()
	}

	return rec, nil
}

// Remove elimina un dominio web y su vhost nginx.
func (s *WebDomainService) Remove(domain, ctxID string) error {
	if err := validateDomain(domain); err != nil {
		return err
	}
	_ = ctxID

	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.store.Get(domain); !exists {
		return fmt.Errorf("dominio no encontrado: %s", domain)
	}

	if err := s.nginx.RemoveVhost(domain); err != nil {
		return fmt.Errorf("eliminar vhost nginx: %w", err)
	}
	if err := s.store.Delete(domain); err != nil {
		return fmt.Errorf("eliminar registro: %w", err)
	}
	if err := s.nginx.Reload(); err != nil {
		return fmt.Errorf("dominio eliminado pero nginx no recargó: %w", err)
	}
	return nil
}

// List retorna todos los dominios registrados.
func (s *WebDomainService) List() []WebDomainRecord {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.store.List()
}

// Resolve retorna el registro de un dominio o error si no existe.
func (s *WebDomainService) Resolve(domain string) (WebDomainRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rec, ok := s.store.Get(domain)
	if !ok {
		return WebDomainRecord{}, fmt.Errorf("dominio no encontrado: %s", domain)
	}
	return rec, nil
}

// SSLStatus retorna el estado del certificado TLS del dominio.
func (s *WebDomainService) SSLStatus(domain string) SSLStatus {
	s.mu.Lock()
	defer s.mu.Unlock()

	exp, issuer, err := s.nginx.SSLExpiresAt(domain)
	if err != nil {
		return SSLStatus{Provisioned: false, Error: err.Error()}
	}
	return SSLStatus{
		Provisioned: true,
		ExpiresAt:   exp,
		Issuer:      issuer,
	}
}

// validateDomain verifica que el dominio sea un hostname RFC 1123 válido.
func validateDomain(domain string) error {
	if domain == "" {
		return errors.New("domain es requerido")
	}
	if !rfc1123Hostname.MatchString(domain) {
		return fmt.Errorf("dominio inválido (debe ser hostname RFC 1123): %q", domain)
	}
	return nil
}
