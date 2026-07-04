// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package network

import (
	"net"
	"os/exec"
	"strings"

	"bos/internal/audit"
	"bos/internal/paths"
	"github.com/rs/zerolog/log"
)

// DetectSubnet devuelve la primera subred IPv4 no-loopback activa del host en
// notación CIDR (p.ej. "192.168.1.0/24").
//
// Itera sobre todas las interfaces de red del sistema, omite loopback e
// interfaces inactivas, y retorna el primer CIDR IPv4 encontrado. Este valor
// es el que kubelet/K8s usa para rutar el tráfico de salida de los pods.
//
// Recibe: ninguno — lee las interfaces del sistema operativo directamente.
//
// Retorna:
//   - string: CIDR de la primera subred IPv4 activa (p.ej. "10.0.0.1/24").
//   - "" si no hay interfaces activas o solo hay loopback (p.ej. en sandbox).
//
// Callers conocidos:
//   - internal/network.EnsureBridgeNetwork — paso previo a EnsureNftablesForwardRule.
//   - cmd/bos/main.go:autoBootstrap — indirectamente, vía EnsureBridgeNetwork.
//
// Efectos secundarios: ninguno — solo lecturas de syscall (net.Interfaces).
//
// Estándares: SBOS-018 §4.3 (prerrequisitos de red). Mirrors install.sh §0.1.
func DetectSubnet() string {
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
			return ipnet.String()
		}
	}
	return ""
}

// EnsureNftablesForwardRule inserta una regla FORWARD en nftables que permite
// el tráfico de salida de pods K8s con origen en subnet.
//
// Mirrors install.sh §0.2. La operación es idempotente: si la regla ya existe
// (detectada con `nft list chain ip filter FORWARD`), no se re-inserta.
// Si nft no está instalado o no hay permisos NET_ADMIN, la función registra
// un aviso y retorna sin error — el tráfico de pods puede quedar limitado.
//
// Recibe:
//   - subnet: string — CIDR de la subred a permitir (p.ej. "192.168.1.0/24").
//     Si vacío, retorna inmediatamente sin acción.
//
// Retorna: nada. Errores de permisos o ausencia de nft se registran en log.
//
// Callers conocidos:
//   - internal/network.EnsureBridgeNetwork — llamado con el resultado de DetectSubnet.
//
// Efectos secundarios:
//   - Ejecuta `nft list chain ip filter FORWARD` para verificar existencia.
//   - Ejecuta `nft insert rule ip filter FORWARD ip saddr <subnet> accept` si no existe.
//   - Escribe entrada en audit log si la regla se inserta correctamente.
//
// Estándares: SBOS-018 §4.3, ISO 27001:2022 A.8.15. Mirrors install.sh §0.2.
func EnsureNftablesForwardRule(subnet string) {
	if subnet == "" {
		return
	}
	if _, err := exec.LookPath("nft"); err != nil {
		log.Debug().Msg("network: nft no encontrado — omitiendo regla FORWARD (tráfico de pods K8s puede quedar limitado)")
		return
	}
	checkCmd := exec.Command("nft", "list", "chain", "ip", "filter", "FORWARD")
	output, err := checkCmd.Output()
	if err != nil {
		log.Debug().Err(err).Msg("network: no se puede listar cadena FORWARD de nftables — omitiendo (requiere NET_ADMIN)")
		return
	}
	if strings.Contains(string(output), "ip saddr "+subnet) {
		log.Debug().Str("subnet", subnet).Msg("network: regla FORWARD nftables ya existe")
		return
	}
	cmd := exec.Command("nft", "insert", "rule", "ip", "filter", "FORWARD", "ip", "saddr", subnet, "accept")
	if err := cmd.Run(); err != nil {
		log.Warn().Err(err).Str("subnet", subnet).
			Msgf("network: no se pudo insertar regla FORWARD — tráfico de pods K8s puede bloquearse; ejecutar en el HOST: sudo nft insert rule ip filter FORWARD ip saddr %s accept", subnet)
		return
	}
	log.Info().Str("subnet", subnet).Msg("network: regla FORWARD nftables insertada")
	audit.Log(paths.AuditLog, "NETWORK", "subnet="+subnet, "rule=nft_FORWARD_accept")
}

// EnsureBridgeNetwork orquesta la configuración de red de arranque:
// detecta la subred del host e inserta la regla FORWARD en nftables.
//
// Es el único punto de entrada que autoBootstrap llama directamente.
// Mirrors install.sh pasos 0.1 y 0.2 combinados. En bare metal configura
// el host directamente; en contenedor intenta lo mismo (requiere NET_ADMIN).
//
// Recibe: ninguno.
//
// Retorna: nada. Ausencia de subred o permisos insuficientes se registran
// en el log como advertencia; bos continúa el arranque sin bloquear.
//
// Callers conocidos:
//   - cmd/bos/main.go:autoBootstrap — paso 8.5, red bridge antes de K8s (kubeadm).
//
// Efectos secundarios:
//   - Llama DetectSubnet() (solo lecturas).
//   - Llama EnsureNftablesForwardRule() si hay subred (puede escribir en nftables y audit log).
//
// Estándares: SBOS-018 §4.3, ISO 27001:2022 A.8.15. Mirrors install.sh §0.1–0.2.
func EnsureBridgeNetwork() {
	subnet := DetectSubnet()
	if subnet != "" {
		log.Info().Str("subnet", subnet).Msg("network: subred del host detectada")
		EnsureNftablesForwardRule(subnet)
	} else {
		log.Warn().Msg("network: no se detectó subred IPv4 — omitiendo regla FORWARD nftables")
	}
}
