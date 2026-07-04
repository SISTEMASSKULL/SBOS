// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// SOLO REFERENCIA DE LÓGICA — NO IMPORTAR, NO COPIAR COMO ESTÁ.
//
// Origen: cmd/bos/main.go (extraído en átomo F1.4)
// Destino: internal/network/network.go
// Razón: las funciones de red violan SRP en main.go; el paquete network
//         las hace testeables y las agrupa bajo una abstracción coherente.
//
// Funciones incluidas:
//   - detectNetworkSubnet(): detecta la primera subred IPv4 no-loopback del host.
//   - ensureNftablesForwardRule(): inserta regla FORWARD en nftables para el tráfico K8s.
//   - ensureBridgeNetwork(): orquesta detección de subred + regla nftables.
//
// Cambios en la versión migrada:
//   - Renombradas: DetectSubnet / EnsureNftablesForwardRule / EnsureBridgeNetwork
//   - Comentarios en español y godoc ADR-003 completo
//   - audit.Log usa paths.AuditLog en vez de string literal

package legacy

import (
	"net"
	"os/exec"
	"strings"
)

// detectNetworkSubnet returns the primary IPv4 subnet (CIDR) for this host/container.
// Used to configure nftables FORWARD rules so K8s pod traffic can egress the bridge.
//
// MIGRADO a: internal/network.DetectSubnet()
func detectNetworkSubnet() string {
	ifaces, _ := net.Interfaces()
	for _, iface := range ifaces {
		if iface.Flags&net.FlagLoopback != 0 {
			continue
		}
		if iface.Flags&net.FlagUp == 0 {
			continue
		}
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, addr := range addrs {
			ipnet, ok := addr.(*net.IPNet)
			if !ok || ipnet.IP.To4() == nil {
				continue
			}
			// Return first non-loopback IPv4 subnet found.
			return ipnet.String()
		}
	}
	return ""
}

// ensureNftablesForwardRule inserts an nftables FORWARD rule for the given subnet.
// Mirrors install.sh step 0.2: ensures K8s pod traffic can traverse the bridge.
//
// MIGRADO a: internal/network.EnsureNftablesForwardRule()
func ensureNftablesForwardRule(subnet string) {
	if subnet == "" {
		return
	}
	if _, err := exec.LookPath("nft"); err != nil {
		return
	}
	checkCmd := exec.Command("nft", "list", "chain", "ip", "filter", "FORWARD")
	output, err := checkCmd.Output()
	if err != nil {
		return
	}
	if strings.Contains(string(output), "ip saddr "+subnet) {
		return
	}
	cmd := exec.Command("nft", "insert", "rule", "ip", "filter", "FORWARD", "ip", "saddr", subnet, "accept")
	cmd.Run()
}

// ensureBridgeNetwork orchestrates network setup: subnet detection + nftables FORWARD rule.
// Mirrors install.sh steps 0.1–0.2. On bare metal, this configures the host.
// In a container, it attempts the same (needs NET_ADMIN / --privileged).
//
// MIGRADO a: internal/network.EnsureBridgeNetwork()
func ensureBridgeNetwork() {
	subnet := detectNetworkSubnet()
	if subnet != "" {
		ensureNftablesForwardRule(subnet)
	}
}
