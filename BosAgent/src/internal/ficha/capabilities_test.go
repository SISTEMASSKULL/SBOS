package ficha

import (
	"strings"
	"testing"
)

func TestCoreCapabilities_Count(t *testing.T) {
	caps := CoreCapabilities()
	if len(caps) != 5 {
		t.Fatalf("esperado 5 capacidades core, obtenido %d", len(caps))
	}
}

func TestCoreCapabilities_AllRequired(t *testing.T) {
	caps := CoreCapabilities()
	for _, cap := range caps {
		if !cap.Required {
			t.Errorf("capacidad %s debe ser obligatoria", cap.ID)
		}
		if !cap.AutoConfig {
			t.Errorf("capacidad %s debe ser auto-configurable", cap.ID)
		}
	}
}

func TestCoreCapabilities_UniqueIDs(t *testing.T) {
	caps := CoreCapabilities()
	seen := make(map[string]bool)
	for _, cap := range caps {
		if seen[cap.ID] {
			t.Errorf("ID duplicado: %s", cap.ID)
		}
		seen[cap.ID] = true
	}
}

func TestCoreCapabilities_ExpectedIDs(t *testing.T) {
	caps := CoreCapabilities()
	expectedIDs := []string{"sso", "ctx_id", "mtls", "metrics", "secrets"}

	for _, expected := range expectedIDs {
		found := false
		for _, cap := range caps {
			if cap.ID == expected {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("falta capacidad esperada: %s", expected)
		}
	}
}

func TestCapabilityGenerator_GenerateAll(t *testing.T) {
	gen := NewCapabilityGenerator("skull")
	caps := gen.GenerateAll("postgresql")

	if caps.FichaID != "postgresql" {
		t.Errorf("ficha_id debe ser postgresql, obtenido %s", caps.FichaID)
	}
	if len(caps.Capabilities) != 5 {
		t.Fatalf("esperado 5 capacidades, obtenido %d", len(caps.Capabilities))
	}

	// Verificar cada capacidad tiene config
	for _, cap := range caps.Capabilities {
		if !cap.Enabled {
			t.Errorf("capacidad %s debe estar enabled", cap.CapabilityID)
		}
		if len(cap.Config) == 0 {
			t.Errorf("capacidad %s debe tener config no vacía", cap.CapabilityID)
		}
	}
}

func TestCapabilityGenerator_SSO(t *testing.T) {
	gen := NewCapabilityGenerator("skull")
	caps := gen.GenerateAll("redis")

	sso := caps.Capabilities[0]
	if sso.CapabilityID != "sso" {
		t.Errorf("primera capacidad debe ser sso, obtenido %s", sso.CapabilityID)
	}
	if sso.Config["client_id"] != "redis-client" {
		t.Errorf("client_id debe ser redis-client, obtenido %s", sso.Config["client_id"])
	}
	if sso.Config["realm"] != "skull" {
		t.Errorf("realm debe ser skull, obtenido %s", sso.Config["realm"])
	}
	if !strings.Contains(sso.Config["vault_path"], "redis") {
		t.Error("vault_path debe contener el ficha_id")
	}
}

func TestCapabilityGenerator_CtxID(t *testing.T) {
	gen := NewCapabilityGenerator("maya")
	caps := gen.GenerateAll("keycloak")

	ctx := caps.Capabilities[1]
	if ctx.CapabilityID != "ctx_id" {
		t.Errorf("segunda capacidad debe ser ctx_id, obtenido %s", ctx.CapabilityID)
	}
	if ctx.Config["ctx_id_header"] != "X-SBOS-CtxId" {
		t.Errorf("header ctx_id incorrecto: %s", ctx.Config["ctx_id_header"])
	}
	if ctx.Config["w3c_trace_context"] != "true" {
		t.Error("w3c_trace_context debe ser true")
	}
}

func TestCapabilityGenerator_MTLS(t *testing.T) {
	gen := NewCapabilityGenerator("skull")
	caps := gen.GenerateAll("kong")

	mtls := caps.Capabilities[2]
	if mtls.CapabilityID != "mtls" {
		t.Errorf("tercera capacidad debe ser mtls, obtenido %s", mtls.CapabilityID)
	}
	if !strings.Contains(mtls.Config["linkerd_annotation"], "linkerd.io/inject: enabled") {
		t.Error("linkerd annotation debe contener inject: enabled")
	}
}

func TestCapabilityGenerator_Metrics(t *testing.T) {
	gen := NewCapabilityGenerator("skull")
	caps := gen.GenerateAll("vault")

	metrics := caps.Capabilities[3]
	if metrics.CapabilityID != "metrics" {
		t.Errorf("cuarta capacidad debe ser metrics, obtenido %s", metrics.CapabilityID)
	}
	if metrics.Config["scrape_interval"] != "30s" {
		t.Errorf("scrape_interval debe ser 30s, obtenido %s", metrics.Config["scrape_interval"])
	}
}

func TestCapabilityGenerator_Secrets(t *testing.T) {
	gen := NewCapabilityGenerator("skull")
	caps := gen.GenerateAll("nginx")

	secrets := caps.Capabilities[4]
	if secrets.CapabilityID != "secrets" {
		t.Errorf("quinta capacidad debe ser secrets, obtenido %s", secrets.CapabilityID)
	}
	if secrets.Config["vault_approle"] != "sbos-nginx" {
		t.Errorf("approle debe ser sbos-nginx, obtenido %s", secrets.Config["vault_approle"])
	}
	if secrets.Config["approle_ttl"] != "24h" {
		t.Errorf("approle_ttl debe ser 24h, obtenido %s", secrets.Config["approle_ttl"])
	}
}

func TestRequiredCapabilities(t *testing.T) {
	required := RequiredCapabilities()
	if len(required) != 5 {
		t.Errorf("las 5 capacidades deben ser requeridas, obtenido %d", len(required))
	}
}

func TestMissingCapabilities(t *testing.T) {
	// Solo tiene 3 de 5
	have := []string{"sso", "ctx_id", "mtls"}
	missing := MissingCapabilities(have)

	if len(missing) != 2 {
		t.Fatalf("esperado 2 faltantes, obtenido %d", len(missing))
	}
	if missing[0].ID != "metrics" {
		t.Errorf("primera faltante debe ser metrics, obtenido %s", missing[0].ID)
	}
	if missing[1].ID != "secrets" {
		t.Errorf("segunda faltante debe ser secrets, obtenido %s", missing[1].ID)
	}
}

func TestMissingCapabilities_None(t *testing.T) {
	have := []string{"sso", "ctx_id", "mtls", "metrics", "secrets"}
	missing := MissingCapabilities(have)

	if len(missing) != 0 {
		t.Errorf("no deben faltar capacidades, faltan: %v", missing)
	}
}

func TestCapabilitySummary(t *testing.T) {
	gen := NewCapabilityGenerator("skull")
	caps := gen.GenerateAll("test-ficha")

	summary := caps.CapabilitySummary()
	if summary == "" {
		t.Error("summary no debe estar vacío")
	}
	if !strings.Contains(summary, "test-ficha") {
		t.Error("summary debe contener el ficha_id")
	}
	if !strings.Contains(summary, "✅") {
		t.Error("summary debe mostrar ✅ para capacidades enabled")
	}
}

func TestListCapabilityIDs(t *testing.T) {
	ids := ListCapabilityIDs()
	if len(ids) != 5 {
		t.Fatalf("esperado 5 IDs, obtenido %d", len(ids))
	}
	expected := []string{"sso", "ctx_id", "mtls", "metrics", "secrets"}
	for i, expected := range expected {
		if ids[i] != expected {
			t.Errorf("ID[%d]: esperado %s, obtenido %s", i, expected, ids[i])
		}
	}
}
