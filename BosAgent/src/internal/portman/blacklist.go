// Capa 1 de verificación — lista negra de puertos reservados.
//
// Fuentes combinadas:
//   - IANA well-known ports (0-1023)
//   - Puertos K8s core (que nunca deben solaparse con fichas)
//   - Puertos Linkerd service mesh
//   - Catálogo SBOS-050 (daemons SBOS propios)
package portman

// PortType es el tipo de puerto según su alcance de red.
type PortType string

const (
	PortTypeHostPhysical    PortType = "HOST_PHYSICAL"
	PortTypeHostLogical     PortType = "HOST_LOGICAL"
	PortTypeK8sNodePort     PortType = "K8S_NODE_PORT"
	PortTypeK8sClusterIP    PortType = "K8S_CLUSTER_IP"
	PortTypeK8sLoadBalancer PortType = "K8S_LOAD_BALANCER"
)

// Transport es el protocolo de transporte.
type Transport string

const (
	TransportTCP  Transport = "TCP"
	TransportUDP  Transport = "UDP"
	TransportSCTP Transport = "SCTP"
	TransportDCCP Transport = "DCCP"
)

// reservedRanges define rangos completos de puertos bloqueados por capa.
// Fuente: IANA, K8s docs, SBOS-050.
var reservedRanges = [][2]int{
	{0, 1023},     // IANA well-known — nunca asignar
	{2379, 2380},  // etcd — K8s core
	{6443, 6443},  // kube-apiserver
	{10250, 10252}, // kubelet, kube-controller-manager, kube-scheduler
	{10255, 10255}, // kubelet read-only
	{10257, 10259}, // K8s control plane adicional
}

// reservedPorts define puertos individuales bloqueados.
// Incluye: K8s NodePort range bloqueado por SBOS, Linkerd, SBOS-050 daemons.
var reservedPorts = map[int]string{
	// Linkerd service mesh
	4143: "linkerd-proxy",
	4190: "linkerd-tap",
	4191: "linkerd-admin",

	// Kubernetes NodePort range de K8s core (30000-32767)
	// SBOS reserva el rango 30000-31999 para K8s interno;
	// fichas usan 32000-49151 (Algoritmo B) y 9400-9499 (Algoritmo A daemon range).

	// SBOS-050: puertos fijos de los daemons SBOS
	9400: "bos-daemon-rpc",
	9443: "bos-daemon-https",
	9401: "bauth-daemon",
	9402: "bkernel-daemon",
	9403: "biedata-daemon",
	9404: "bsearch-daemon",
	9405: "bnexus-daemon",
	9406: "bnotify-daemon",

	// PostgreSQL en K8s (ClusterIP interno) — solo acceso desde pods
	5432: "postgresql-standard",
	15432: "postgresql-sbos-aux",

	// Redis
	6379: "redis-standard",
	16379: "redis-sbos",

	// Kong Gateway
	8000: "kong-http",
	8001: "kong-admin",
	8443: "kong-https",
	8444: "kong-admin-https",

	// Keycloak (mantenido por compatibilidad aunque ADR-010 lo marcó legacy)
	8080: "keycloak-http",
	8180: "keycloak-http-alt",

	// Vault
	8200: "vault-api",
	8201: "vault-cluster",
}

// IsReserved verifica si el puerto está en la lista negra local (Capa 1).
func IsReserved(port int) (bool, string) {
	// Rango IANA y K8s core
	for _, r := range reservedRanges {
		if port >= r[0] && port <= r[1] {
			return true, "rango reservado IANA/K8s"
		}
	}
	// Puertos individuales bloqueados
	if reason, ok := reservedPorts[port]; ok {
		return true, reason
	}
	// K8s NodePort range reservado para K8s core
	if port >= 30000 && port <= 31999 {
		return true, "rango K8s NodePort reservado"
	}
	return false, ""
}

// sbos050Catalog es el catálogo de puertos SBOS-050 (Capa 2).
// Mapea (daemon, servicio) → puerto para verificar colisiones con otros daemons.
var sbos050Catalog = map[string]int{
	"bos:api":    9443,
	"bos:rpc":    9400,
	"bauth:rpc":  9401,
	"bkernel:rpc": 9402,
	"biedata:rpc": 9403,
	"bsearch:rpc": 9404,
	"bnexus:rpc":  9405,
	"bnotify:rpc": 9406,
}

// IsInSBOS050 verifica si el puerto está en el catálogo SBOS-050 (Capa 2).
func IsInSBOS050(port int) (bool, string) {
	for svc, p := range sbos050Catalog {
		if p == port {
			return true, "sbos-050:" + svc
		}
	}
	return false, ""
}
