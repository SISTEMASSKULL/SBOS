// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// Package network gestiona la configuración de red del nodo host durante el
// arranque del daemon bos (Day 0): detección de subred y regla FORWARD en nftables.
//
// # Responsabilidades
//
// Tres responsabilidades relacionadas, todas necesarias antes de que K3s arranque:
//   - DetectSubnet(): detectar la primera subred IPv4 no-loopback activa del host.
//     Devuelve el CIDR (p.ej. "192.168.1.0/24") que K3s usará para rutar tráfico de pods.
//   - EnsureNftablesForwardRule(subnet): insertar una regla FORWARD en nftables que
//     permita al tráfico de pods con origen en subnet atravesar el bridge hacia el exterior.
//     Idempotente: no re-inserta si la regla ya existe.
//   - EnsureBridgeNetwork(): orquestador — llama DetectSubnet + EnsureNftablesForwardRule.
//     Es el único punto de entrada que usa autoBootstrap.
//
// # Fuera de alcance
//
// No crea interfaces de red — eso es K3s + CNI (Calico).
// No gestiona IPs de pods ni tablas de enrutamiento avanzadas.
// No expone ninguna API ni puerto — es un paquete de arranque interno.
// No configura firewall más allá de la regla FORWARD para pods.
//
// # Dependencias
//
// Llama a `nft` (nftables CLI) mediante os/exec — requiere que nft esté instalado.
// Usa bos/internal/audit para registrar la inserción de reglas (ISO 27001 A.8.15).
// Usa bos/internal/paths para paths canónicos de log (P16 Zero Hardcoding).
//
// # Callers principales
//
// cmd/bos/main.go:autoBootstrap — paso 8.5, configuración de red bridge.
// No hay otros callers — es una operación de arranque única.
//
// # Estándares y referencias
//
// SBOS-018 §4.3 — Prerrequisitos de red para K3s.
// SBOS-050 — P6 (bases de datos solo ClusterIP), P9 (HTTP vetado entre daemons).
// ISO 27001:2022 A.8.15 — registro de operaciones de red en audit log.
// Mirrors: install.sh pasos 0.1 (detección de subred) y 0.2 (regla FORWARD).
//
// # Ejemplo de uso
//
//	// Arranque Day 0 — configurar red antes de K3s
//	network.EnsureBridgeNetwork()
//
//	// Uso directo si se necesita la subred en otro contexto
//	subnet := network.DetectSubnet()
//	if subnet != "" {
//	    network.EnsureNftablesForwardRule(subnet)
//	}
package network
