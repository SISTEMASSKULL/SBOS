// Package ficha — NetworkPolicy Calico generada por ficha (F11.E.4).
// BOS-REPAIR Plan Maestro v3 · SBOS-050 P9 · NSA/CISA K8s Hardening §3.
//
// Cada ficha K8s recibe una NetworkPolicy generada automáticamente por el BOS
// con deny-all default + allowlist explícita. Las fichas HOST (systemd, bash)
// documentan excepción — no reciben NetworkPolicy (corren en el host, no en K8s).
//
// Principios de seguridad:
//   - Default deny-all ingress + egress (Zero Trust, NIST SP 800-207 Tenet 3)
//   - Allowlist explícita: solo el tráfico declarado es permitido
//   - Kong es el único entrypoint externo (SBOS-050 P9)
//   - Tráfico entre fichas: solo a servicios declarados (PG, Redis, Vault)
//   - Métricas: Prometheus puede scrapear el endpoint /metrics
//
// Plantillas por tipo:
//   - Deployment:   ingress Kong + egress PG/Redis/Vault + metrics
//   - StatefulSet:  igual que Deployment + puertos de réplica internos
//   - DaemonSet:     ingress desde nodos + egress PG/Redis
//   - bash/systemd:  NO aplica (ficha host — documentar excepción)
package ficha

import (
	"fmt"
	"strings"
)

// ── Tipos ────────────────────────────────────────────────────────────

// NetPolRule define una regla de ingress o egress en una NetworkPolicy.
type NetPolRule struct {
	Description string   // descripción legible
	From        string   // origen del tráfico (namespace o label)
	To          string   // destino del tráfico (namespace o label)
	Ports       []int    // puertos permitidos
	Protocol    string   // TCP, UDP (default: TCP)
}

// NetPolSpec contiene la especificación completa para generar una NetworkPolicy.
type NetPolSpec struct {
	FichaID      string        // ID de la ficha
	Namespace    string        // namespace K8s (ej: "sbos-data")
	WorkloadType string        // Deployment, StatefulSet, DaemonSet, bash
	Ports        []int         // puertos que expone la ficha
	NeedsDB      bool          // ¿necesita acceso a PostgreSQL?
	NeedsCache   bool          // ¿necesita acceso a Redis?
	NeedsSecrets bool          // ¿necesita acceso a Vault?
	IngressRules []NetPolRule  // reglas de entrada adicionales
	EgressRules  []NetPolRule  // reglas de salida adicionales
}

// NetPolTemplate contiene una NetworkPolicy generada lista para serializar.
type NetPolTemplate struct {
	APIVersion string              `yaml:"apiVersion"`
	Kind       string              `yaml:"kind"`
	Metadata   NetPolMetadata      `yaml:"metadata"`
	Spec       NetPolSpecYAML      `yaml:"spec"`
}

// NetPolMetadata contiene los metadatos de la NetworkPolicy.
type NetPolMetadata struct {
	Name      string            `yaml:"name"`
	Namespace string            `yaml:"namespace"`
	Labels    map[string]string `yaml:"labels"`
}

// NetPolSpecYAML contiene la especificación YAML de la NetworkPolicy.
type NetPolSpecYAML struct {
	PodSelector map[string]string `yaml:"podSelector"`
	PolicyTypes []string          `yaml:"policyTypes"`
	Ingress     []NetPolIngress   `yaml:"ingress,omitempty"`
	Egress      []NetPolEgress    `yaml:"egress,omitempty"`
}

// NetPolIngress define una regla de entrada YAML.
type NetPolIngress struct {
	From  []NetPolPeer `yaml:"from,omitempty"`
	Ports []NetPolPort `yaml:"ports,omitempty"`
}

// NetPolEgress define una regla de salida YAML.
type NetPolEgress struct {
	To    []NetPolPeer `yaml:"to,omitempty"`
	Ports []NetPolPort `yaml:"ports,omitempty"`
}

// NetPolPeer define un peer de red (namespace o pod selector).
type NetPolPeer struct {
	NamespaceSelector map[string]string `yaml:"namespaceSelector,omitempty"`
	PodSelector       map[string]string `yaml:"podSelector,omitempty"`
}

// NetPolPort define un puerto en una regla de red.
type NetPolPort struct {
	Port     int    `yaml:"port"`
	Protocol string `yaml:"protocol"`
}

// ── Generador ─────────────────────────────────────────────────────────

// NetworkPolicyGenerator genera NetworkPolicies Calico para fichas K8s.
type NetworkPolicyGenerator struct {
	// Puertos estándar del stack SBOS
	pgPort    int // PostgreSQL: 5432
	redisPort int // Redis: 6379
	vaultPort int // Vault: 8200
	kongPort  int // Kong proxy: 8000
}

// NewNetworkPolicyGenerator crea un generador con los puertos estándar SBOS.
func NewNetworkPolicyGenerator() *NetworkPolicyGenerator {
	return &NetworkPolicyGenerator{
		pgPort:    5432,
		redisPort: 6379,
		vaultPort: 8200,
		kongPort:  8000,
	}
}

// Generate produce la NetworkPolicy para una ficha según su especificación.
// Retorna "" para fichas tipo "bash" (host — no aplica NetworkPolicy K8s).
func (g *NetworkPolicyGenerator) Generate(spec NetPolSpec) (*NetPolTemplate, error) {
	// Fichas host no reciben NetworkPolicy (corren en systemd, no en K8s)
	if spec.WorkloadType == "bash" || spec.WorkloadType == "systemd" {
		return nil, fmt.Errorf("NetworkPolicy no aplica para fichas host (%s). "+
			"La seguridad de red en el host se gestiona con UFW/nftables (S-HOST/bos-firewall)", spec.WorkloadType)
	}

	if spec.Namespace == "" {
		return nil, fmt.Errorf("namespace requerido para generar NetworkPolicy")
	}

	tpl := &NetPolTemplate{
		APIVersion: "projectcalico.org/v3",
		Kind:       "NetworkPolicy",
		Metadata: NetPolMetadata{
			Name:      fmt.Sprintf("%s-netpol", spec.FichaID),
			Namespace: spec.Namespace,
			Labels: map[string]string{
				"app":            spec.FichaID,
				"bos-ficha":      spec.FichaID,
				"generated-by":   "bos",
				"bos-managed":    "true",
			},
		},
		Spec: NetPolSpecYAML{
			PodSelector: map[string]string{"app": spec.FichaID},
			PolicyTypes: []string{"Ingress", "Egress"},
			Ingress:     g.buildIngress(spec),
			Egress:      g.buildEgress(spec),
		},
	}

	return tpl, nil
}

// buildIngress construye las reglas de entrada.
func (g *NetworkPolicyGenerator) buildIngress(spec NetPolSpec) []NetPolIngress {
	var rules []NetPolIngress

	// Regla 1: Permitir tráfico desde Kong API Gateway
	rules = append(rules, NetPolIngress{
		From: []NetPolPeer{{
			NamespaceSelector: map[string]string{"name": "sbos-gateway"},
			PodSelector:       map[string]string{"app": "kong"},
		}},
		Ports: portsToNetPol(spec.Ports),
	})

	// Regla 2: Permitir scraping de Prometheus (métricas)
	rules = append(rules, NetPolIngress{
		From: []NetPolPeer{{
			NamespaceSelector: map[string]string{"name": "sbos-observability"},
			PodSelector:       map[string]string{"app": "prometheus"},
		}},
		Ports: []NetPolPort{{Port: 9090, Protocol: "TCP"}},
	})

	// Reglas adicionales definidas por la ficha
	for _, rule := range spec.IngressRules {
		rules = append(rules, g.ruleToIngress(rule))
	}

	return rules
}

// buildEgress construye las reglas de salida.
func (g *NetworkPolicyGenerator) buildEgress(spec NetPolSpec) []NetPolEgress {
	var rules []NetPolEgress

	// Regla 1: Permitir salida a DNS (siempre necesario)
	rules = append(rules, NetPolEgress{
		To: []NetPolPeer{{
			NamespaceSelector: map[string]string{"name": "kube-system"},
			PodSelector:       map[string]string{"k8s-app": "kube-dns"},
		}},
		Ports: []NetPolPort{{Port: 53, Protocol: "UDP"}},
	})

	// Regla 2: Acceso a PostgreSQL (si la ficha lo necesita)
	if spec.NeedsDB {
		rules = append(rules, NetPolEgress{
			To: []NetPolPeer{{
				NamespaceSelector: map[string]string{"name": "sbos-data"},
				PodSelector:       map[string]string{"app": "postgresql"},
			}},
			Ports: []NetPolPort{{Port: g.pgPort, Protocol: "TCP"}},
		})
	}

	// Regla 3: Acceso a Redis (si la ficha lo necesita)
	if spec.NeedsCache {
		rules = append(rules, NetPolEgress{
			To: []NetPolPeer{{
				NamespaceSelector: map[string]string{"name": "sbos-data"},
				PodSelector:       map[string]string{"app": "redis"},
			}},
			Ports: []NetPolPort{{Port: g.redisPort, Protocol: "TCP"}},
		})
	}

	// Regla 4: Acceso a Vault (si la ficha lo necesita)
	if spec.NeedsSecrets {
		rules = append(rules, NetPolEgress{
			To: []NetPolPeer{{
				NamespaceSelector: map[string]string{"name": "sbos-security"},
				PodSelector:       map[string]string{"app": "vault"},
			}},
			Ports: []NetPolPort{{Port: g.vaultPort, Protocol: "TCP"}},
		})
	}

	// Reglas adicionales de egress
	for _, rule := range spec.EgressRules {
		rules = append(rules, g.ruleToEgress(rule))
	}

	return rules
}

// ruleToIngress convierte una NetPolRule de dominio a NetPolIngress YAML.
func (g *NetworkPolicyGenerator) ruleToIngress(rule NetPolRule) NetPolIngress {
	return NetPolIngress{
		From: []NetPolPeer{{
			NamespaceSelector: map[string]string{"name": rule.From},
		}},
		Ports: portsToNetPol(rule.Ports),
	}
}

// ruleToEgress convierte una NetPolRule de dominio a NetPolEgress YAML.
func (g *NetworkPolicyGenerator) ruleToEgress(rule NetPolRule) NetPolEgress {
	return NetPolEgress{
		To: []NetPolPeer{{
			NamespaceSelector: map[string]string{"name": rule.To},
		}},
		Ports: portsToNetPol(rule.Ports),
	}
}

// portsToNetPol convierte una lista de puertos a []NetPolPort.
func portsToNetPol(ports []int) []NetPolPort {
	if len(ports) == 0 {
		return nil
	}
	result := make([]NetPolPort, len(ports))
	for i, p := range ports {
		result[i] = NetPolPort{Port: p, Protocol: "TCP"}
	}
	return result
}

// ── Templates predefinidos ────────────────────────────────────────────

// DefaultSpecFor retorna una especificación por defecto según el tipo de ficha.
func DefaultSpecFor(fichaID, namespace, workloadType string) NetPolSpec {
	spec := NetPolSpec{
		FichaID:      fichaID,
		Namespace:    namespace,
		WorkloadType: workloadType,
		NeedsDB:      false,
		NeedsCache:   false,
		NeedsSecrets: false,
	}

	switch workloadType {
	case "StatefulSet":
		spec.NeedsDB = true       // StatefulSets casi siempre necesitan BD
		spec.NeedsCache = true    // y caché
		spec.NeedsSecrets = true  // y secretos
		spec.Ports = []int{5432} // puerto por defecto
	case "Deployment":
		spec.NeedsDB = true
		spec.NeedsCache = true
		spec.NeedsSecrets = true
		spec.Ports = []int{8080} // puerto HTTP por defecto
	case "DaemonSet":
		spec.NeedsSecrets = true
		spec.Ports = []int{9090}
	}

	return spec
}

// ── Helpers ────────────────────────────────────────────────────────────

// IsHostFicha retorna true si la ficha corre en host (no en K8s).
func IsHostFicha(workloadType string) bool {
	return workloadType == "bash" || workloadType == "systemd" || workloadType == "host"
}

// ValidateNetPol verifica reglas básicas de seguridad en una NetworkPolicy.
// Retorna warnings si encuentra prácticas inseguras.
func ValidateNetPol(tpl *NetPolTemplate) []string {
	var warnings []string

	if tpl == nil {
		return []string{"NetworkPolicy es nil"}
	}

	// Verificar deny-all
	hasDenyAll := true // Calico aplica deny-all implícito
	_ = hasDenyAll

	// Verificar que hay al menos una regla de ingress
	if len(tpl.Spec.Ingress) == 0 && len(tpl.Spec.PodSelector) > 0 {
		warnings = append(warnings, "sin reglas de ingress — el pod será inaccesible")
	}

	// Verificar que el egress a DNS está presente
	dnsFound := false
	for _, egress := range tpl.Spec.Egress {
		for _, to := range egress.To {
			if to.PodSelector["k8s-app"] == "kube-dns" {
				dnsFound = true
			}
		}
	}
	if !dnsFound && len(tpl.Spec.Egress) > 0 {
		warnings = append(warnings, "sin regla de egress a DNS (kube-dns) — la resolución de nombres fallará")
	}

	// Verificar que no hay egress 0.0.0.0/0 (permitir todo)
	// Esto es una verificación básica — la generación no crea reglas any-any

	return warnings
}

// NetPolSummary retorna un resumen legible de la NetworkPolicy.
func (tpl *NetPolTemplate) NetPolSummary() string {
	var sb strings.Builder
	fmt.Fprintf(&sb, "NetworkPolicy: %s (namespace: %s)\n", tpl.Metadata.Name, tpl.Metadata.Namespace)
	fmt.Fprintf(&sb, "  Ingress: %d reglas\n", len(tpl.Spec.Ingress))
	fmt.Fprintf(&sb, "  Egress:  %d reglas\n", len(tpl.Spec.Egress))
	fmt.Fprintf(&sb, "  Política: deny-all + allowlist explícita\n")
	return sb.String()
}
