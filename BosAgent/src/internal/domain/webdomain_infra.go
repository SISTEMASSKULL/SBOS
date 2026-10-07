// Package domain — implementaciones de infraestructura para WebDomainService.
//
// MemWebDomain: store en memoria (tests, modo dev sin BD)
// PgWebDomain:  store persistente sobre bos.net_web_domain (T-430)
// NoopNginx:    stub sin efectos (tests)
// NginxManager: implementación real de producción (nginx + certbot + openssl)
package domain

import (
	"database/sql"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	_ "github.com/lib/pq"
)

// ── MemWebDomain ─────────────────────────────────────────────────────────────

// MemWebDomain es un store en memoria para WebDomainPort.
// Thread-safe mediante RWMutex. Solo para tests y modo dev.
type MemWebDomain struct {
	mu      sync.RWMutex
	records map[string]WebDomainRecord
}

// NewMemWebDomain crea un MemWebDomain vacío.
func NewMemWebDomain() *MemWebDomain {
	return &MemWebDomain{records: make(map[string]WebDomainRecord)}
}

func (m *MemWebDomain) Save(rec WebDomainRecord) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.records[rec.Domain] = rec
	return nil
}

func (m *MemWebDomain) Delete(domain string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.records, domain)
	return nil
}

func (m *MemWebDomain) Get(domain string) (WebDomainRecord, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	rec, ok := m.records[domain]
	return rec, ok
}

func (m *MemWebDomain) List() []WebDomainRecord {
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]WebDomainRecord, 0, len(m.records))
	for _, r := range m.records {
		out = append(out, r)
	}
	return out
}

// ── PgWebDomain ──────────────────────────────────────────────────────────────

// PgWebDomain implementa WebDomainPort sobre bos.net_web_domain (T-430).
// Usa soft-delete (is_active=false) para Delete; List y Get filtran is_active=true.
type PgWebDomain struct {
	db *sql.DB
}

// NewPgWebDomain abre la conexión a PostgreSQL y retorna el store.
// DSN desde env BOS_PG_DSN (mismo que portman y context plane).
func NewPgWebDomain(dsn string) (*PgWebDomain, error) {
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("webdomain: abrir conexión: %w", err)
	}
	db.SetMaxOpenConns(4)
	db.SetMaxIdleConns(2)
	if err := db.Ping(); err != nil {
		db.Close()
		return nil, fmt.Errorf("webdomain: ping falló: %w", err)
	}
	return &PgWebDomain{db: db}, nil
}

// Close cierra el pool de conexiones.
func (p *PgWebDomain) Close() error { return p.db.Close() }

// Save inserta o actualiza (UPSERT) el registro del dominio.
// Si el dominio ya existe, actualiza target y ssl_auto.
func (p *PgWebDomain) Save(rec WebDomainRecord) error {
	const q = `
		INSERT INTO bos.net_web_domain
			(domain, target, ssl_auto, tenant_id, is_active, ctx_id, created_at)
		VALUES ($1, $2, $3, 'default', true, 'system', $4)
		ON CONFLICT (domain) DO UPDATE SET
			target    = EXCLUDED.target,
			ssl_auto  = EXCLUDED.ssl_auto,
			is_active = true`
	_, err := p.db.Exec(q, rec.Domain, rec.Target, rec.SSLAuto, rec.CreatedAt)
	if err != nil {
		return fmt.Errorf("webdomain save %s: %w", rec.Domain, err)
	}
	return nil
}

// Delete marca el dominio como inactivo (soft-delete).
func (p *PgWebDomain) Delete(domain string) error {
	const q = `UPDATE bos.net_web_domain SET is_active = false WHERE domain = $1`
	_, err := p.db.Exec(q, domain)
	if err != nil {
		return fmt.Errorf("webdomain delete %s: %w", domain, err)
	}
	return nil
}

// Get retorna el registro activo de un dominio, o (zero, false) si no existe.
func (p *PgWebDomain) Get(domain string) (WebDomainRecord, bool) {
	const q = `
		SELECT domain, target, ssl_auto, created_at
		FROM bos.net_web_domain
		WHERE domain = $1 AND is_active = true`
	var rec WebDomainRecord
	err := p.db.QueryRow(q, domain).Scan(&rec.Domain, &rec.Target, &rec.SSLAuto, &rec.CreatedAt)
	if err != nil {
		return WebDomainRecord{}, false
	}
	return rec, true
}

// List retorna todos los dominios activos ordenados por created_at.
func (p *PgWebDomain) List() []WebDomainRecord {
	const q = `
		SELECT domain, target, ssl_auto, created_at
		FROM bos.net_web_domain
		WHERE is_active = true
		ORDER BY created_at`
	rows, err := p.db.Query(q)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []WebDomainRecord
	for rows.Next() {
		var rec WebDomainRecord
		if err := rows.Scan(&rec.Domain, &rec.Target, &rec.SSLAuto, &rec.CreatedAt); err == nil {
			out = append(out, rec)
		}
	}
	return out
}

// ── NoopNginx ────────────────────────────────────────────────────────────────

// NoopNginx implementa WebNginxPort sin efectos secundarios. Úsalo en tests.
type NoopNginx struct{}

func (NoopNginx) Reload() error                                     { return nil }
func (NoopNginx) ProvisionSSL(_ string) error                       { return nil }
func (NoopNginx) SSLExpiresAt(_ string) (time.Time, string, error)  { return time.Time{}, "", fmt.Errorf("sin certificado (noop)") }
func (NoopNginx) WriteVhost(_, _ string) error                      { return nil }
func (NoopNginx) RemoveVhost(_ string) error                        { return nil }

// ── NginxManager ─────────────────────────────────────────────────────────────

// NginxManager implementa WebNginxPort sobre nginx + certbot + openssl del sistema.
// Diseñado para Ubuntu 24.04/26.04 con nginx instalado en /etc/nginx/.
type NginxManager struct {
	sitesDir string // /etc/nginx/sites-enabled por defecto
}

// NewNginxManager crea un NginxManager apuntando al directorio de sites de nginx.
// sitesDir debe ser /etc/nginx/sites-enabled en producción.
func NewNginxManager(sitesDir string) *NginxManager {
	if sitesDir == "" {
		sitesDir = "/etc/nginx/sites-enabled"
	}
	return &NginxManager{sitesDir: sitesDir}
}

// Reload ejecuta `nginx -s reload` para aplicar la nueva configuración.
func (n *NginxManager) Reload() error {
	out, err := exec.Command("nginx", "-s", "reload").CombinedOutput()
	if err != nil {
		return fmt.Errorf("nginx reload: %w — %s", err, strings.TrimSpace(string(out)))
	}
	return nil
}

// ProvisionSSL solicita un certificado Let's Encrypt vía certbot standalone.
// Requiere que el puerto 80 esté libre o que nginx ya tenga configurado el dominio.
func (n *NginxManager) ProvisionSSL(domain string) error {
	out, err := exec.Command(
		"certbot", "certonly",
		"--nginx",
		"--non-interactive",
		"--agree-tos",
		"--email", "admin@"+domain,
		"-d", domain,
	).CombinedOutput()
	if err != nil {
		return fmt.Errorf("certbot %s: %w — %s", domain, err, strings.TrimSpace(string(out)))
	}
	return nil
}

// SSLExpiresAt consulta la fecha de vencimiento del certificado con openssl.
func (n *NginxManager) SSLExpiresAt(domain string) (time.Time, string, error) {
	certPath := filepath.Join("/etc/letsencrypt/live", domain, "fullchain.pem")
	if _, err := os.Stat(certPath); err != nil {
		return time.Time{}, "", fmt.Errorf("certificado no encontrado para %s", domain)
	}

	out, err := exec.Command(
		"openssl", "x509",
		"-in", certPath,
		"-noout", "-enddate", "-issuer",
	).CombinedOutput()
	if err != nil {
		return time.Time{}, "", fmt.Errorf("openssl: %w", err)
	}

	var expStr, issuer string
	for _, line := range strings.Split(string(out), "\n") {
		if strings.HasPrefix(line, "notAfter=") {
			expStr = strings.TrimPrefix(line, "notAfter=")
		}
		if strings.HasPrefix(line, "issuer=") {
			issuer = strings.TrimPrefix(line, "issuer=")
		}
	}

	if expStr == "" {
		return time.Time{}, "", fmt.Errorf("openssl: no se pudo leer notAfter")
	}

	// openssl usa formato: "Jan 15 12:00:00 2026 GMT"
	t, err := time.Parse("Jan  2 15:04:05 2006 GMT", expStr)
	if err != nil {
		t, err = time.Parse("Jan 2 15:04:05 2006 GMT", expStr)
		if err != nil {
			return time.Time{}, "", fmt.Errorf("parsear fecha: %w", err)
		}
	}
	return t, strings.TrimSpace(issuer), nil
}

// WriteVhost escribe el archivo de configuración nginx para el dominio.
func (n *NginxManager) WriteVhost(domain, target string) error {
	path := filepath.Join(n.sitesDir, domain+".conf")
	return os.WriteFile(path, []byte(nginxVhostTemplate(domain, target)), 0o644)
}

// RemoveVhost elimina el archivo de configuración nginx del dominio.
func (n *NginxManager) RemoveVhost(domain string) error {
	path := filepath.Join(n.sitesDir, domain+".conf")
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("eliminar vhost %s: %w", domain, err)
	}
	return nil
}

// nginxVhostTemplate genera una configuración nginx básica de reverse proxy.
func nginxVhostTemplate(domain, target string) string {
	return fmt.Sprintf(`# Generado por BOS — no editar manualmente
server {
    listen 80;
    server_name %s;

    location / {
        proxy_pass http://%s;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
`, domain, target)
}
