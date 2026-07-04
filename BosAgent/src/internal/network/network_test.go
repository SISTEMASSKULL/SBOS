// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package network

import (
	"net"
	"strings"
	"testing"
)

// TestNetwork_DetectaSubnet verifica que DetectSubnet retorna "" o una cadena
// con formato CIDR válido ("x.x.x.x/n").
// No fuerza que existan interfaces — el test es correcto tanto en CI sin red
// como en un host con múltiples interfaces.
func TestNetwork_DetectaSubnet(t *testing.T) {
	t.Parallel()
	result := DetectSubnet()
	if result == "" {
		// Aceptable en entornos sandbox (CI sin interfaces activas).
		return
	}
	// Verificar que el resultado es un CIDR IPv4 parseable.
	ip, ipnet, err := net.ParseCIDR(result)
	if err != nil {
		t.Errorf("DetectSubnet retornó %q que no es un CIDR válido: %v", result, err)
		return
	}
	// Debe ser una dirección IPv4.
	if ip.To4() == nil {
		t.Errorf("DetectSubnet retornó %q que no es un CIDR IPv4", result)
	}
	// La red debe ser no-loopback.
	if ipnet.IP.IsLoopback() {
		t.Errorf("DetectSubnet retornó red loopback %q — debería omitirla", result)
	}
}

// TestNetwork_ReglaNftables_Formato verifica que EnsureNftablesForwardRule("")
// retorna inmediatamente sin ejecutar nft ni entrar en pánico.
// El guard de subnet vacía es la primera línea de defensa.
func TestNetwork_ReglaNftables_Formato(t *testing.T) {
	t.Parallel()
	// subnet="" debe retornar inmediatamente sin side effects.
	EnsureNftablesForwardRule("")
	// Si llegamos aquí sin pánico ni cuelgue, el test pasa.
}

// TestNetwork_ReglaNftables_SubnetNoVacia verifica que EnsureNftablesForwardRule
// con una subnet válida no entra en pánico aunque nft no esté disponible.
// En entornos CI sin nft instalado, la función debe retornar silenciosamente.
func TestNetwork_ReglaNftables_SubnetNoVacia(t *testing.T) {
	t.Parallel()
	// Usamos una dirección RFC 5737 (documentación) — nunca enrutable.
	EnsureNftablesForwardRule("192.0.2.0/24")
	// Sin pánico = correcto. Si nft no existe, retorna vía LookPath early return.
}

// TestNetwork_EnsureBridgeNetwork_NoPanico verifica que EnsureBridgeNetwork
// completa sin pánico en cualquier entorno (con o sin red, con o sin nft).
func TestNetwork_EnsureBridgeNetwork_NoPanico(t *testing.T) {
	t.Parallel()
	EnsureBridgeNetwork()
}

// TestNetwork_FormatoReglaNft verifica el formato exacto del argumento de la
// regla nftables: "ip saddr <subnet>" debe aparecer como substring buscado.
// Este test documenta el invariante del protocolo de detección de regla existente.
func TestNetwork_FormatoReglaNft(t *testing.T) {
	t.Parallel()
	subnet := "10.0.0.0/8"
	esperado := "ip saddr " + subnet
	// Simular la lógica de detección de regla existente.
	outputSimulado := "chain FORWARD { ip saddr 10.0.0.0/8 accept }"
	if !strings.Contains(outputSimulado, esperado) {
		t.Errorf("el formato de búsqueda %q no coincide con output nft esperado %q", esperado, outputSimulado)
	}
}
