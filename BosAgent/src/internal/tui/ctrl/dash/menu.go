package dash

// MenuItem es un ítem del menú lateral del dashboard.
type MenuItem struct {
	Label   string
	ViewKey string // "" = header o separador (no navegable)
	Indent  int
}

// MenuDef es la definición del árbol de navegación del dashboard.
var MenuDef = []MenuItem{
	{"Overview", "overview", 0},
	{"─────────────", "", 0},
	{"K8s", "", 0},
	{"  Control Pl.", "k8s-cp", 1},
	{"  Workloads", "k8s-wl", 1},
	{"  Autoscaling", "k8s-as", 1},
	{"  Network", "k8s-net", 1},
	{"  Storage", "k8s-sto", 1},
	{"─────────────", "", 0},
	{"Sistema OS", "", 0},
	{"  Métricas", "os-met", 1},
	{"  Procesos", "os-proc", 1},
	{"  Systemd", "os-svc", 1},
	{"  Red", "os-net", 1},
	{"  Disco", "os-disk", 1},
	{"  Kernel", "os-ker", 1},
	{"─────────────", "", 0},
	{"Jobs", "jobs", 0},
	{"Usuarios", "users", 0},
	{"PAM/RBAC", "pam", 0},
	{"Logs", "logs", 0},
	{"Alertas", "alertas", 0},
	{"Network", "net-os", 0},
	{"Storage", "stor-os", 0},
	{"Seguridad", "seg", 0},
	{"Backups", "bkp", 0},
	{"Monitoreo", "mon", 0},
	{"Config", "config", 0},
}

// Selectables retorna los índices navegables del menú.
func Selectables() []int {
	var idx []int
	for i, it := range MenuDef {
		if it.ViewKey != "" {
			idx = append(idx, i)
		}
	}
	return idx
}

// SubTabMax retorna el índice máximo de sub-tabs para un viewKey.
func SubTabMax(vk string) int {
	switch vk {
	case "k8s-cp":
		return 0
	case "k8s-wl":
		return 5 // Pods/Deployments/StatefulSets/DaemonSets/Jobs/CronJobs
	case "k8s-as":
		return 6 // HPA/VPA/KEDA/ClusterAS/Quotas/LimitRange/PDB
	case "k8s-net":
		return 3 // Services/Ingress/NetPolicies/Endpoints
	case "k8s-sto":
		return 3 // PVs/PVCs/StorageClasses/VolumeSnaps
	case "os-met":
		return 3 // CPU/RAM/Swap/I/O
	case "os-proc":
		return 2 // Top/Zombie/Threads
	case "os-svc":
		return 2 // Activos/Fallidos/Todos
	case "os-net":
		return 2 // Interfaces/Conexiones/DNS
	case "os-disk":
		return 2 // Particiones/I/O/Inodes
	case "os-ker":
		return 2 // Versión/Módulos/Sysctl
	case "jobs":
		return 2 // Activos/Historial/Pendientes
	case "users":
		return 2 // Activos/Last/Grupos
	case "pam":
		return 3 // PAM/K8s RBAC/Impersonation/Audit
	case "logs":
		return 6 // bos-agent/sshd/kubelet/kernel/ufw/etcd/containerd
	case "alertas":
		return 3 // Activas/Historial/Reglas/Silenciadas
	case "net-os":
		return 3 // UFW/DNS/Puertos/Túneles
	case "stor-os":
		return 2 // Discos/SMART/Backups
	case "seg":
		return 3 // Certificados/Puertos/CVEs/Auditoría
	case "bkp":
		return 2 // Estado/Schedule/Historial
	case "mon":
		return 3 // CPU/RAM/Red/K8s
	case "config":
		return 3 // General/K8s/Daemons/Alertas
	default:
		return 0
	}
}

// ViewTitle retorna el título legible de un viewKey.
func ViewTitle(vk string) string {
	titles := map[string]string{
		"overview": "Overview — Resumen del Sistema",
		"k8s-cp":   "K8s — Control Plane",
		"k8s-wl":   "K8s — Workloads",
		"k8s-as":   "K8s — Autoscaling",
		"k8s-net":  "K8s — Network",
		"k8s-sto":  "K8s — Storage",
		"os-met":   "Sistema OS — Métricas",
		"os-proc":  "Sistema OS — Procesos",
		"os-svc":   "Sistema OS — Systemd",
		"os-net":   "Sistema OS — Red",
		"os-disk":  "Sistema OS — Disco",
		"os-ker":   "Sistema OS — Kernel",
		"jobs":     "Jobs — Instalaciones",
		"users":    "Usuarios — Sesiones",
		"pam":      "PAM / RBAC",
		"logs":     "Logs del Sistema",
		"alertas":  "Alertas",
		"net-os":   "Network — Firewall y Red",
		"stor-os":  "Storage — Discos del Sistema",
		"seg":      "Seguridad — Certificados y CVEs",
		"bkp":      "Backups — Estado y Schedule",
		"mon":      "Monitoreo — Series Temporales",
		"config":   "Configuración BosAgent",
	}
	if t, ok := titles[vk]; ok {
		return t
	}
	return "Dashboard"
}
