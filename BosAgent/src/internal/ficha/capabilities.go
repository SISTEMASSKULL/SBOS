// Package ficha — Capacidades automáticas inyectadas por BOS (F11.E.3).
// BOS-REPAIR Plan Maestro v3 · SBOS_Proyecto_Master.md §16.4.
//
// Toda ficha SBOS recibe 5 capacidades automáticamente al ser instalada,
// sin configuración adicional por parte del desarrollador de la ficha.
// El BOS crea y gestiona estas capacidades de forma transparente.
//
// Capacidades inyectadas:
//
//  1. SSO (Keycloak):        client_id automático, OAuth2-Proxy configurado
//  2. ctx_id (OTel):         OpenTelemetry Baggage + W3C Trace Context
//  3. mTLS (Linkerd):        sidecar Linkerd inyectado, anotaciones automáticas
//  4. Métricas (Prometheus): endpoint /metrics expuesto, scrape config generado
//  5. Secretos (Vault):      AppRole único por ficha, paths secret/tenants/{realm}/<ficha>/
//
// El desarrollador solo declara la ficha en manifest.yml; el BOS se encarga del resto.
// Principio: "la ficha no sabe que existe BOS — BOS sabe que existe la ficha."
package ficha

import (
	"fmt"
	"os"
	"strings"
)

// bosDomain retorna el dominio base del SBOS, configurable vía BOS_DOMAIN.
func bosDomain() string {
	if d := os.Getenv("BOS_DOMAIN"); d != "" {
		return d
	}
	return "sbos.app"
}

// ── Tipos ────────────────────────────────────────────────────────────

// AutoCapability representa una capacidad que BOS inyecta automáticamente.
type AutoCapability struct {
	ID          string   // identificador único: "sso", "ctx_id", "mtls", "metrics", "secrets"
	Name        string   // nombre legible: "SSO (Keycloak)"
	Description string   // qué hace esta capacidad por la ficha
	Provider    string   // sistema que provee la capacidad: "Keycloak", "OpenTelemetry", "Linkerd", "Prometheus", "Vault"
	Required    bool     // true = todas las fichas la reciben obligatoriamente
	AutoConfig  bool     // true = BOS genera la configuración sin intervención
}

// CapabilityConfig contiene la configuración generada para una capacidad específica.
type CapabilityConfig struct {
	CapabilityID string            `json:"capability"`
	Enabled      bool              `json:"enabled"`
	Config       map[string]string `json:"config,omitempty"`
	Manifest     string            `json:"manifest,omitempty"` // YAML/JSON de configuración generado
}

// FichaCapabilities agrupa todas las capacidades de una ficha.
type FichaCapabilities struct {
	FichaID      string             `json:"ficha_id"`
	Capabilities []CapabilityConfig `json:"capabilities"`
	GeneratedAt  string             `json:"generated_at,omitempty"`
}

// ── Catálogo de capacidades ──────────────────────────────────────────

// CoreCapabilities retorna las 5 capacidades automáticas obligatorias.
func CoreCapabilities() []AutoCapability {
	return []AutoCapability{
		{
			ID:          "sso",
			Name:        "SSO (Keycloak)",
			Description: "Autenticación single sign-on vía Keycloak OIDC. La ficha recibe client_id, client_secret (vía Vault), y OAuth2-Proxy configurado automáticamente.",
			Provider:    "Keycloak",
			Required:    true,
			AutoConfig:  true,
		},
		{
			ID:          "ctx_id",
			Name:        "ctx_id (OpenTelemetry)",
			Description: "Contexto distribuido con ctx_id en cada request. Kong inyecta header X-SBOS-CtxId; la ficha lo propaga a sus logs y spans OTel.",
			Provider:    "OpenTelemetry",
			Required:    true,
			AutoConfig:  true,
		},
		{
			ID:          "mtls",
			Name:        "mTLS (Linkerd)",
			Description: "Mutual TLS automático entre servicios. Linkerd sidecar inyectado transparentemente. La ficha no necesita configurar certificados.",
			Provider:    "Linkerd",
			Required:    true,
			AutoConfig:  true,
		},
		{
			ID:          "metrics",
			Name:        "Métricas (Prometheus)",
			Description: "Endpoint /metrics expuesto automáticamente. Prometheus scrape config generado. Dashboard Grafana base incluido.",
			Provider:    "Prometheus",
			Required:    true,
			AutoConfig:  true,
		},
		{
			ID:          "secrets",
			Name:        "Secretos (Vault)",
			Description: "AppRole único por ficha en Vault. Paths secret/tenants/{realm}/<ficha>/ creados automáticamente. La ficha lee secretos al arrancar vía Vault Agent sidecar.",
			Provider:    "Vault",
			Required:    true,
			AutoConfig:  true,
		},
	}
}

// ── Generador de configuraciones ──────────────────────────────────────

// CapabilityGenerator genera la configuración concreta para cada capacidad.
type CapabilityGenerator struct {
	tenantRealm string // ej: "skull"
}

// NewCapabilityGenerator crea un generador de capacidades para un tenant.
func NewCapabilityGenerator(tenantRealm string) *CapabilityGenerator {
	return &CapabilityGenerator{tenantRealm: tenantRealm}
}

// GenerateAll genera las 5 configuraciones de capacidad para una ficha.
func (g *CapabilityGenerator) GenerateAll(fichaID string) *FichaCapabilities {
	caps := CoreCapabilities()
	configs := make([]CapabilityConfig, 0, len(caps))

	for _, cap := range caps {
		configs = append(configs, g.generate(fichaID, cap))
	}

	return &FichaCapabilities{
		FichaID:      fichaID,
		Capabilities: configs,
	}
}

// generate produce la configuración concreta para una capacidad.
func (g *CapabilityGenerator) generate(fichaID string, cap AutoCapability) CapabilityConfig {
	cfg := CapabilityConfig{
		CapabilityID: cap.ID,
		Enabled:      true,
		Config:       make(map[string]string),
	}

	switch cap.ID {
	case "sso":
		cfg.Config = map[string]string{
			"client_id":              fmt.Sprintf("%s-client", fichaID),
			"realm":                  g.tenantRealm,
			"auth_endpoint":          fmt.Sprintf("https://keycloak.%s.%s/auth", g.tenantRealm, bosDomain()),
			"token_endpoint":         fmt.Sprintf("https://keycloak.%s.%s/token", g.tenantRealm, bosDomain()),
			"oauth2_proxy_enabled":   "true",
			"grant_type":             "authorization_code",
			"client_secret_source":   "vault",
			"vault_path":             fmt.Sprintf("secret/tenants/%s/%s/sso", g.tenantRealm, fichaID),
		}

	case "ctx_id":
		cfg.Config = map[string]string{
			"otel_baggage_enabled":    "true",
			"w3c_trace_context":       "true",
			"ctx_id_header":           "X-SBOS-CtxId",
			"tenant_id_header":        "X-SBOS-Tenant",
			"bitmask_header":          "X-SBOS-Bitmask",
			"propagation_injectors":   "baggage,tracecontext",
			"log_with_ctx_id":         "true",
		}

	case "mtls":
		cfg.Config = map[string]string{
			"linkerd_inject":          "enabled",
			"linkerd_annotation":      fmt.Sprintf("linkerd.io/inject: enabled\nconfig.linkerd.io/proxy-cpu-limit: 500m\nconfig.linkerd.io/proxy-memory-limit: 256Mi"),
			"ca_source":               "vault",
			"vault_pki_path":          fmt.Sprintf("pki/tenants/%s", g.tenantRealm),
			"tls_mode":                "strict",
			"auto_rotate":             "true",
		}

	case "metrics":
		cfg.Config = map[string]string{
			"metrics_port":            "9090",
			"metrics_path":            "/metrics",
			"prometheus_scrape":       "true",
			"scrape_interval":         "30s",
			"prometheus_job":          fmt.Sprintf("sbos-%s", fichaID),
			"grafana_dashboard":       "auto",
			"dashboard_uid":           fmt.Sprintf("sbos-%s", fichaID),
		}

	case "secrets":
		cfg.Config = map[string]string{
			"vault_approle":           fmt.Sprintf("sbos-%s", fichaID),
			"vault_policy":            fmt.Sprintf("sbos-%s-read", fichaID),
			"secret_paths":            fmt.Sprintf("secret/tenants/%s/%s/db,secret/tenants/%s/%s/api-key,secret/tenants/%s/%s/sso",
				g.tenantRealm, fichaID, g.tenantRealm, fichaID, g.tenantRealm, fichaID),
			"approle_ttl":             "24h",
			"renewal_enabled":         "true",
			"vault_agent_sidecar":     "true",
		}
	}

	return cfg
}

// ── Helpers ────────────────────────────────────────────────────────────

// RequiredCapabilities retorna las capacidades obligatorias (todas).
func RequiredCapabilities() []AutoCapability {
	var required []AutoCapability
	for _, cap := range CoreCapabilities() {
		if cap.Required {
			required = append(required, cap)
		}
	}
	return required
}

// MissingCapabilities verifica qué capacidades faltan en una lista dada.
func MissingCapabilities(have []string) []AutoCapability {
	haveMap := make(map[string]bool)
	for _, h := range have {
		haveMap[h] = true
	}

	var missing []AutoCapability
	for _, cap := range CoreCapabilities() {
		if !haveMap[cap.ID] {
			missing = append(missing, cap)
		}
	}
	return missing
}

// CapabilitySummary retorna un resumen legible de las capacidades de una ficha.
func (fc *FichaCapabilities) CapabilitySummary() string {
	var sb strings.Builder
	fmt.Fprintf(&sb, "Capacidades de %s:\n", fc.FichaID)
	for _, cap := range fc.Capabilities {
		icon := "✅"
		if !cap.Enabled {
			icon = "❌"
		}
		fmt.Fprintf(&sb, "  %s %s\n", icon, cap.CapabilityID)
	}
	return sb.String()
}

// ListCapabilityIDs retorna los IDs de todas las capacidades core.
func ListCapabilityIDs() []string {
	caps := CoreCapabilities()
	ids := make([]string, len(caps))
	for i, c := range caps {
		ids[i] = c.ID
	}
	return ids
}
