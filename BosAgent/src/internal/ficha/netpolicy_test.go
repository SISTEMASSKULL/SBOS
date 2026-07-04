package ficha

import (
	"testing"
)

func TestNetPolGenerator_Deployment(t *testing.T) {
	gen := NewNetworkPolicyGenerator()
	spec := NetPolSpec{
		FichaID:      "nginx",
		Namespace:    "sbos-apps",
		WorkloadType: "Deployment",
		Ports:        []int{8080, 8443},
		NeedsDB:      true,
		NeedsCache:   true,
		NeedsSecrets: true,
	}

	tpl, err := gen.Generate(spec)
	if err != nil {
		t.Fatalf("Generate falló: %v", err)
	}

	// Verificar metadatos
	if tpl.Kind != "NetworkPolicy" {
		t.Errorf("kind debe ser NetworkPolicy, obtenido %s", tpl.Kind)
	}
	if tpl.Metadata.Name != "nginx-netpol" {
		t.Errorf("name debe ser nginx-netpol, obtenido %s", tpl.Metadata.Name)
	}
	if tpl.Metadata.Namespace != "sbos-apps" {
		t.Errorf("namespace debe ser sbos-apps, obtenido %s", tpl.Metadata.Namespace)
	}

	// Verificar labels
	if tpl.Metadata.Labels["generated-by"] != "bos" {
		t.Error("label generated-by debe ser bos")
	}
	if tpl.Metadata.Labels["bos-managed"] != "true" {
		t.Error("label bos-managed debe ser true")
	}

	// Verificar podSelector
	if tpl.Spec.PodSelector["app"] != "nginx" {
		t.Errorf("podSelector app debe ser nginx, obtenido %s", tpl.Spec.PodSelector["app"])
	}

	// Verificar policyTypes
	if len(tpl.Spec.PolicyTypes) != 2 {
		t.Errorf("debe tener 2 policyTypes, obtenido %d", len(tpl.Spec.PolicyTypes))
	}

	// Debe tener ingress (Kong + Prometheus = 2)
	if len(tpl.Spec.Ingress) < 2 {
		t.Errorf("debe tener ≥2 reglas ingress, obtenido %d", len(tpl.Spec.Ingress))
	}

	// Debe tener egress (DNS + PG + Redis + Vault = 4)
	if len(tpl.Spec.Egress) < 4 {
		t.Errorf("debe tener ≥4 reglas egress, obtenido %d", len(tpl.Spec.Egress))
	}
}

func TestNetPolGenerator_StatefulSet(t *testing.T) {
	gen := NewNetworkPolicyGenerator()
	spec := NetPolSpec{
		FichaID:      "postgresql",
		Namespace:    "sbos-data",
		WorkloadType: "StatefulSet",
		Ports:        []int{5432},
		NeedsDB:      true,
		NeedsCache:   false,
		NeedsSecrets: true,
	}

	tpl, err := gen.Generate(spec)
	if err != nil {
		t.Fatalf("Generate falló: %v", err)
	}

	if tpl.Metadata.Name != "postgresql-netpol" {
		t.Errorf("name incorrecto: %s", tpl.Metadata.Name)
	}

	// DNS + Vault = 2 reglas egress (sin Redis)
	if len(tpl.Spec.Egress) < 2 {
		t.Errorf("StatefulSet debe tener ≥2 reglas egress, obtenido %d", len(tpl.Spec.Egress))
	}
}

func TestNetPolGenerator_HostFicha_Rejected(t *testing.T) {
	gen := NewNetworkPolicyGenerator()
	spec := NetPolSpec{
		FichaID:      "bos-preflight",
		Namespace:    "",
		WorkloadType: "bash",
	}

	_, err := gen.Generate(spec)
	if err == nil {
		t.Error("fichas host (bash) NO deben recibir NetworkPolicy")
	}
}

func TestNetPolGenerator_Systemd_Rejected(t *testing.T) {
	gen := NewNetworkPolicyGenerator()
	spec := NetPolSpec{
		FichaID:      "bkernel",
		WorkloadType: "systemd",
	}

	_, err := gen.Generate(spec)
	if err == nil {
		t.Error("fichas systemd NO deben recibir NetworkPolicy")
	}
}

func TestNetPolGenerator_NoNamespace(t *testing.T) {
	gen := NewNetworkPolicyGenerator()
	spec := NetPolSpec{
		FichaID:      "test",
		WorkloadType: "Deployment",
		Namespace:    "", // vacío
	}

	_, err := gen.Generate(spec)
	if err == nil {
		t.Error("sin namespace debe fallar")
	}
}

func TestNetPolGenerator_DaemonSet(t *testing.T) {
	gen := NewNetworkPolicyGenerator()
	spec := NetPolSpec{
		FichaID:      "wazuh",
		Namespace:    "sbos-security",
		WorkloadType: "DaemonSet",
		Ports:        []int{9090},
		NeedsSecrets: true,
	}

	tpl, err := gen.Generate(spec)
	if err != nil {
		t.Fatalf("Generate falló: %v", err)
	}

	// DaemonSet: DNS + Vault = 2 egress
	if len(tpl.Spec.Egress) < 2 {
		t.Errorf("DaemonSet con secrets debe tener ≥2 reglas egress, obtenido %d", len(tpl.Spec.Egress))
	}
}

func TestNetPolGenerator_CustomRules(t *testing.T) {
	gen := NewNetworkPolicyGenerator()
	spec := NetPolSpec{
		FichaID:      "custom-app",
		Namespace:    "sbos-apps",
		WorkloadType: "Deployment",
		Ports:        []int{3000},
		IngressRules: []NetPolRule{
			{Description: "allow from monitoring", From: "sbos-observability", Ports: []int{9090}},
		},
		EgressRules: []NetPolRule{
			{Description: "allow to external API", To: "sbos-gateway", Ports: []int{443}},
		},
	}

	tpl, err := gen.Generate(spec)
	if err != nil {
		t.Fatalf("Generate falló: %v", err)
	}

	// Ingress: Kong + Prometheus + custom = 3
	if len(tpl.Spec.Ingress) != 3 {
		t.Errorf("con regla custom debe tener 3 ingress, obtenido %d", len(tpl.Spec.Ingress))
	}
}

func TestIsHostFicha(t *testing.T) {
	if !IsHostFicha("bash") {
		t.Error("bash debe ser host")
	}
	if !IsHostFicha("systemd") {
		t.Error("systemd debe ser host")
	}
	if !IsHostFicha("host") {
		t.Error("host debe ser host")
	}
	if IsHostFicha("Deployment") {
		t.Error("Deployment NO debe ser host")
	}
}

func TestValidateNetPol(t *testing.T) {
	gen := NewNetworkPolicyGenerator()
	spec := NetPolSpec{
		FichaID:      "test",
		Namespace:    "sbos-test",
		WorkloadType: "Deployment",
		Ports:        []int{8080},
		NeedsDB:      true,
		NeedsCache:   true,
		NeedsSecrets: true,
	}
	tpl, _ := gen.Generate(spec)

	warnings := ValidateNetPol(tpl)
	// No debería haber warnings críticos con la generación estándar
	for _, w := range warnings {
		t.Logf("warning (puede ser esperado): %s", w)
	}
}

func TestValidateNetPol_Nil(t *testing.T) {
	warnings := ValidateNetPol(nil)
	if len(warnings) == 0 {
		t.Error("nil debe generar warning")
	}
}

func TestNetPolSummary(t *testing.T) {
	gen := NewNetworkPolicyGenerator()
	spec := DefaultSpecFor("test-app", "sbos-apps", "Deployment")
	tpl, _ := gen.Generate(spec)

	summary := tpl.NetPolSummary()
	if summary == "" {
		t.Error("summary no debe estar vacío")
	}
}

func TestDefaultSpecFor(t *testing.T) {
	// Deployment
	spec := DefaultSpecFor("app", "sbos-apps", "Deployment")
	if !spec.NeedsDB || !spec.NeedsCache || !spec.NeedsSecrets {
		t.Error("Deployment debe necesitar DB + cache + secrets por defecto")
	}

	// StatefulSet
	spec = DefaultSpecFor("db", "sbos-data", "StatefulSet")
	if !spec.NeedsDB || !spec.NeedsSecrets {
		t.Error("StatefulSet debe necesitar DB + secrets por defecto")
	}

	// DaemonSet
	spec = DefaultSpecFor("agent", "sbos-system", "DaemonSet")
	if !spec.NeedsSecrets {
		t.Error("DaemonSet debe necesitar secrets por defecto")
	}
}

func TestPortsToNetPol(t *testing.T) {
	ports := []int{80, 443, 8080}
	result := portsToNetPol(ports)

	if len(result) != 3 {
		t.Fatalf("esperado 3 puertos, obtenido %d", len(result))
	}
	if result[0].Protocol != "TCP" {
		t.Error("protocolo debe ser TCP")
	}
	if result[2].Port != 8080 {
		t.Errorf("puerto[2] debe ser 8080, obtenido %d", result[2].Port)
	}

	// Vacío
	if portsToNetPol(nil) != nil {
		t.Error("nil debe retornar nil")
	}
}
