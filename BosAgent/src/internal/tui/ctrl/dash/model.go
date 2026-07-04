package dash

import (
	"fmt"
	"time"

	"bos/internal/tui/styles"
	"bos/internal/tui/tuilog"

	"github.com/charmbracelet/bubbles/help"
	tea "github.com/charmbracelet/bubbletea"
)

// DashAction representa una acción de sistema solicitada desde el dashboard.
type DashAction int

const (
	DashActionNone     DashAction = iota
	DashActionReboot              // ctrl+r — reiniciar servidor
	DashActionShutdown            // ctrl+p — apagar servidor
)

// DashModel es el estado del dashboard de control.
// Autocontenido: tiene su propio Update() y se renderiza con ctrl.Render().
type DashModel struct {
	Width, Height int
	Focus         FocusZone
	MenuIdx       int            // índice en MenuDef del ítem seleccionado
	SubTab        map[string]int // sub-tab activo por viewKey
	LogDaemon     int            // índice del daemon activo en la vista logs
	BodyScrollY   int            // scroll del body (líneas)
	HelpModel     help.Model     // renderer de bubbles/help — misma instancia en todo el ciclo de vida

	// Datos del sistema
	CPU      CPUInfo
	Mem      MemInfo
	Disks    []Disk
	Net      NetStats
	Nodes    []NodeInfo
	Pods     []Pod
	CPComps  []CPComp
	HPAs     []HPA
	Services []Service
	Alerts   []Alert
	Logs     []LogEntry
	Jobs     []InstallJob
	Now      time.Time
	Env      string

	// Autoscaling
	VPAs        []VPA
	KEDAScalers []KEDAScaler
	ClusterAS   ClusterAutoscalerInfo
	Quotas      []ResourceQuota
	LimitRanges []LimitRangeItem
	PDBs        []PodDisruptionBudget

	// Network K8s
	K8sServices []K8sService
	Ingresses   []K8sIngress
	NetPolicies []K8sNetworkPolicy

	// Storage K8s
	PVs            []PersistentVolume
	PVCs           []PVC
	StorageClasses []StorageClass

	// OS
	Processes     []OSProcess
	NetInterfaces []NetworkInterface
	TCPConns      []TCPConn

	// Identidad
	UserSessions    []UserSession
	PAMUsers        []PAMUser
	K8sRoleBindings []K8sRoleBinding
	ImpersonEvents  []ImpersonationEvent

	// Config
	BosConf BosConfig

	// Kernel OS
	KernelInfo KernelInfo

	// Network OS
	UFWRules []UFWRule

	// Storage OS
	StorageDisks []StorageDisk

	// Seguridad
	Certificates []Certificate
	CVEs         []CVEEntry

	// Backups
	BackupJobs []BackupJob

	// Monitoreo sparklines (30 puntos)
	MonCPU  []float64
	MonRAM  []float64
	MonNet  []float64
	MonPods []int

	// TUILog — referencia al Ring de logging interno del TUI.
	// Puntero: se asigna una vez desde Model.TUILog y no se copia.
	// Accedido por panel.Logs() para renderizar el tab "TUI".
	TUIRing *tuilog.Ring

	// JournalEntries — entradas del viewer journalctl (daemons externos).
	// Poblado por Update() cuando llega tuilog.JournalEntryMsg.
	JournalEntries []tuilog.Entry

	// Acción de poder solicitada — el outer code debe leerla y ejecutarla
	PendingAction DashAction
}

// newDashHelp construye un help.Model con los estilos del tema SBOS activo.
func newDashHelp() help.Model {
	h := help.New()
	h.Styles = styles.HuhHelpStyles()
	return h
}

// New construye un DashModel con datos mock y dimensiones iniciales.
func New(w, h int) DashModel {
	dm := DashModel{
		Width:     w,
		Height:    h,
		Focus:     FocusMenu,
		MenuIdx:   0,
		SubTab:    make(map[string]int),
		Now:       time.Now(),
		Env:       "DEV",
		HelpModel: newDashHelp(),
	}
	dm.loadMock()
	return dm
}

// CurrentViewKey retorna el viewKey del ítem activo del menú.
func (dm DashModel) CurrentViewKey() string {
	if dm.MenuIdx >= 0 && dm.MenuIdx < len(MenuDef) {
		return MenuDef[dm.MenuIdx].ViewKey
	}
	return "overview"
}

// menuNext avanza al siguiente ítem navegable.
func (dm DashModel) menuNext() DashModel {
	sel := Selectables()
	for i, idx := range sel {
		if idx == dm.MenuIdx && i+1 < len(sel) {
			dm.MenuIdx = sel[i+1]
			dm.BodyScrollY = 0
			return dm
		}
	}
	return dm
}

// menuPrev retrocede al ítem navegable anterior.
func (dm DashModel) menuPrev() DashModel {
	sel := Selectables()
	for i, idx := range sel {
		if idx == dm.MenuIdx && i > 0 {
			dm.MenuIdx = sel[i-1]
			dm.BodyScrollY = 0
			return dm
		}
	}
	return dm
}

// subTabMove desplaza el sub-tab activo en delta (-1 o +1).
func (dm *DashModel) subTabMove(delta int) {
	vk := dm.CurrentViewKey()
	maxIdx := SubTabMax(vk)
	if maxIdx <= 0 {
		return
	}
	cur := dm.SubTab[vk]
	cur += delta
	if cur < 0 {
		cur = maxIdx
	}
	if cur > maxIdx {
		cur = 0
	}
	dm.SubTab[vk] = cur
}

// Update maneja mensajes de teclado para el dashboard.
func (dm DashModel) Update(msg tea.Msg) DashModel {
	dm.PendingAction = DashActionNone

	km, ok := msg.(tea.KeyMsg)
	if !ok {
		return dm
	}
	switch km.String() {
	case "tab":
		if dm.Focus == FocusMenu {
			dm.Focus = FocusBody
		} else {
			dm.Focus = FocusMenu
		}
	case "shift+tab":
		dm.Focus = FocusMenu
	case "up", "k":
		if dm.Focus == FocusMenu {
			dm = dm.menuPrev()
		} else {
			if dm.BodyScrollY > 0 {
				dm.BodyScrollY--
			}
		}
	case "down", "j":
		if dm.Focus == FocusMenu {
			dm = dm.menuNext()
		} else {
			dm.BodyScrollY++
		}
	case "left", "h":
		if dm.Focus == FocusBody {
			dm.subTabMove(-1)
		}
	case "right", "l":
		if dm.Focus == FocusBody {
			dm.subTabMove(1)
		}
	case "g":
		if dm.Focus == FocusBody {
			dm.BodyScrollY = 0
		}
	case "G":
		if dm.Focus == FocusBody {
			dm.BodyScrollY = 9999
		}
	case "enter":
		if dm.Focus == FocusMenu {
			dm.Focus = FocusBody
			dm.BodyScrollY = 0
		}
	case "ctrl+r":
		dm.PendingAction = DashActionReboot
	case "ctrl+p":
		dm.PendingAction = DashActionShutdown
	}
	return dm
}

// ── Mock data ───────────────────────────────────────────────────────────────

func (dm *DashModel) loadMock() {
	dm.CPU = CPUInfo{
		Cores:   []float64{78, 52, 71, 41, 62, 88, 34, 58},
		Load1:   1.2,
		Load5:   0.9,
		Load15:  0.7,
		Procs:   247,
		Threads: 892,
		Uptime:  time.Duration(12*24+4)*time.Hour + 32*time.Minute,
	}
	dm.Mem = MemInfo{
		TotalGB: 8.0, UsedGB: 5.2, FreeGB: 1.8, BuffGB: 1.0,
		SwapTotal: 2.0, SwapUsed: 0.0,
	}
	dm.Disks = []Disk{{"/", 48, 120}, {"/var", 12, 50}, {"/tmp", 1, 10}}
	dm.Net = NetStats{
		Iface: "ens3", TXBytesS: 1.2 * 1024 * 1024, RXBytesS: 0.4 * 1024 * 1024,
		TXTotalGB: 45.2, RXTotalGB: 12.1,
	}
	dm.Nodes = []NodeInfo{
		{"master", true, 45, 60, 8, 15},
		{"node-1", true, 70, 55, 5, 15},
		{"node-2", true, 30, 40, 2, 15},
	}
	dm.Pods = []Pod{
		{"nginx-7d4f9", "default", PodRunning, "2/2", 0, 45, 128, "5d"},
		{"postgres-5c2", "default", PodRunning, "1/1", 0, 120, 512, "5d"},
		{"redis-8b3a1", "default", PodRunning, "1/1", 2, 30, 256, "5d"},
		{"coredns-2xk9", "kube-system", PodPending, "0/1", 5, 0, 0, "1h"},
		{"metrics-srv", "kube-system", PodFailed, "0/1", 12, 0, 0, "2h"},
		{"calico-node", "kube-system", PodRunning, "3/3", 0, 80, 192, "5d"},
		{"bos-agent-xyz", "bos-system", PodRunning, "1/1", 0, 20, 64, "12d"},
	}
	dm.CPComps = []CPComp{
		{"API Server", true, false, 12, 0, "12d"},
		{"etcd", true, false, 3, 0, "12d"},
		{"Scheduler", true, false, 0, 0, "12d"},
		{"Controller Mgr", true, false, 0, 2, "12d"},
		{"kubelet/master", true, false, 0, 0, "12d"},
		{"kubelet/node-1", true, false, 0, 0, "12d"},
		{"kubelet/node-2", false, true, 0, 5, "12d"},
	}
	dm.HPAs = []HPA{
		{"nginx-hpa", "nginx-deploy", 2, 10, 5, 85, 85, HPAScaling},
		{"api-hpa", "api-deploy", 1, 20, 3, 50, 42, HPAStable},
		{"worker-hpa", "worker-deploy", 0, 50, 0, 50, 0, HPAStable},
	}
	dm.Services = []Service{
		{"bos-agent", true, false, "12d ago"},
		{"kubelet", true, false, "12d ago"},
		{"containerd", true, false, "12d ago"},
		{"docker", false, true, "2h ago"},
	}
	dm.Alerts = []Alert{
		{SevCritical, "PodCrashLooping", "metrics-srv", "exit 1, 12 restarts", "2h ago", false},
		{SevWarning, "NodeHighCPU", "node-1", "CPU core-5 > 85%", "5m ago", false},
		{SevWarning, "HPAScaleLimit", "nginx-hpa", "at maxReplicas=10", "12m ago", false},
		{SevInfo, "VPARecommendation", "worker-vpa", "mem rec: 512Mi→768Mi", "30m ago", false},
	}
	dm.Logs = buildMockLogs()
	dm.Jobs = []InstallJob{{"calico/setup.sh", true, 70, "3/5"}}
	dm.VPAs = []VPA{
		{"worker-vpa", "default", "worker-deploy", "Auto", "200m", "512Mi", VPAApplying},
		{"db-vpa", "default", "postgres-sts", "Recommend", "500m", "1Gi", VPARec},
		{"api-vpa", "default", "api-deploy", "Off", "—", "—", VPAStable},
	}
	dm.KEDAScalers = []KEDAScaler{
		{"queue-scaler", "default", "nginx-deploy", "kafka:topic-a", 1250, 1000, 5, KEDARunning},
		{"batch-scaler", "default", "worker-deploy", "rabbitmq:jobs", 0, 100, 0, KEDAZero},
	}
	dm.ClusterAS = ClusterAutoscalerInfo{
		NodesTotal: 3, NodesReady: 3, NodesMax: 5,
		LastScaleUp: "2h", LastScaleDown: "8h",
		CPUCluster: 62, MemCluster: 52, UnschedulablePods: 0,
	}
	dm.Quotas = []ResourceQuota{{
		Namespace: "default",
		Items: []ResourceQuotaItem{
			{"pods", "12", "20", 60},
			{"cpu requests", "4.2", "8.0", 53},
			{"mem requests", "2.8GB", "8.0GB", 35},
			{"cpu limits", "6.0", "12.0", 50},
			{"mem limits", "4.0GB", "16.0GB", 25},
		},
	}}
	dm.LimitRanges = []LimitRangeItem{
		{"Container", "cpu", "100m", "500m", "50m", "2"},
		{"Container", "memory", "128Mi", "512Mi", "64Mi", "4Gi"},
		{"Pod", "cpu", "—", "—", "200m", "4"},
	}
	dm.PDBs = []PodDisruptionBudget{
		{"nginx-pdb", "default", "app=nginx", 2, 2, true},
		{"api-pdb", "default", "app=api", 1, 3, true},
	}
	dm.K8sServices = []K8sService{
		{"kubernetes", "default", "ClusterIP", "10.96.0.1", "443/TCP", "12d"},
		{"nginx-svc", "default", "LoadBalancer", "10.96.0.10", "80:32080/TCP", "5d"},
		{"postgres-svc", "default", "ClusterIP", "10.96.0.20", "5432/TCP", "5d"},
		{"redis-svc", "default", "ClusterIP", "10.96.0.21", "6379/TCP", "5d"},
		{"bos-svc", "bos-system", "ClusterIP", "10.96.1.1", "9443/TCP", "12d"},
		{"coredns", "kube-system", "ClusterIP", "10.96.0.10", "53/UDP,53/TCP", "12d"},
	}
	dm.Ingresses = []K8sIngress{
		{"nginx-ingress", "default", "app.sbos.local", "/", "nginx-svc:80", true, "5d"},
		{"api-ingress", "default", "api.sbos.local", "/v1", "api-svc:8080", true, "5d"},
		{"admin-ingress", "bos-system", "admin.sbos.local", "/", "bos-svc:9443", true, "12d"},
	}
	dm.NetPolicies = []K8sNetworkPolicy{
		{"default-deny-all", "default", "<all>", 0, 0, "12d"},
		{"allow-nginx", "default", "app=nginx", 1, 0, "5d"},
		{"allow-postgres", "default", "app=postgres", 2, 1, "5d"},
		{"bos-policy", "bos-system", "app=bos", 1, 1, "12d"},
	}
	dm.PVs = []PersistentVolume{
		{"pv-postgres", "20Gi", "RWO", "Retain", "Bound", "local-path", "default/postgres-pvc", "5d"},
		{"pv-redis", "5Gi", "RWO", "Retain", "Bound", "local-path", "default/redis-pvc", "5d"},
		{"pv-bos-state", "1Gi", "RWO", "Retain", "Bound", "local-path", "bos-system/bos-pvc", "12d"},
		{"pv-etcd", "10Gi", "RWO", "Retain", "Bound", "local-path", "kube-system/etcd-pvc", "12d"},
	}
	dm.PVCs = []PVC{
		{"postgres-pvc", "default", "Bound", "pv-postgres", "20Gi", "RWO", "local-path", "5d"},
		{"redis-pvc", "default", "Bound", "pv-redis", "5Gi", "RWO", "local-path", "5d"},
		{"bos-pvc", "bos-system", "Bound", "pv-bos-state", "1Gi", "RWO", "local-path", "12d"},
		{"etcd-pvc", "kube-system", "Bound", "pv-etcd", "10Gi", "RWO", "local-path", "12d"},
	}
	dm.StorageClasses = []StorageClass{
		{"local-path", "rancher.io/local-path", "Delete", "WaitForFirstConsumer", true, "12d"},
		{"standard", "kubernetes.io/no-provisioner", "Retain", "Immediate", false, "12d"},
	}
	dm.Processes = []OSProcess{
		{1, "systemd", "root", 0.1, 0.2, "12M", "S", "12d"},
		{1234, "kubelet", "root", 2.1, 1.5, "180M", "S", "12d"},
		{1235, "containerd", "root", 1.8, 2.0, "240M", "S", "12d"},
		{1240, "etcd", "root", 0.8, 3.2, "380M", "S", "12d"},
		{1245, "kube-apiserver", "root", 1.2, 4.1, "480M", "S", "12d"},
		{1250, "kube-controller", "root", 0.5, 1.1, "130M", "S", "12d"},
		{1255, "kube-scheduler", "root", 0.2, 0.8, "90M", "S", "12d"},
		{2100, "bos-agent", "bosagent", 0.3, 0.5, "64M", "S", "12d"},
		{3010, "nginx", "www-data", 0.1, 0.3, "32M", "S", "5d"},
		{3020, "postgres", "postgres", 1.5, 6.2, "512M", "S", "5d"},
		{3030, "redis-server", "redis", 0.2, 3.1, "256M", "S", "5d"},
		{4000, "sshd", "root", 0.0, 0.1, "8M", "S", "12d"},
	}
	dm.NetInterfaces = []NetworkInterface{
		{"ens3", "13.140.128.230/24", "UP", 1.2 * 1024 * 1024, 0.4 * 1024 * 1024, "45.2 GB", "12.1 GB"},
		{"lo", "127.0.0.1/8", "UP", 0, 0, "—", "—"},
		{"cni0", "10.244.0.1/24", "UP", 0.5 * 1024 * 1024, 0.3 * 1024 * 1024, "2.1 GB", "1.8 GB"},
	}
	dm.TCPConns = []TCPConn{
		{"0.0.0.0:22", "0.0.0.0:*", "LISTEN", 4000, "sshd"},
		{"13.140.128.230:22", "192.168.1.100:51234", "ESTABLISHED", 4001, "sshd"},
		{"0.0.0.0:9443", "0.0.0.0:*", "LISTEN", 2100, "bos-agent"},
		{"127.0.0.1:6443", "0.0.0.0:*", "LISTEN", 1245, "kube-apiserver"},
		{"127.0.0.1:2379", "0.0.0.0:*", "LISTEN", 1240, "etcd"},
		{"0.0.0.0:80", "0.0.0.0:*", "LISTEN", 3010, "nginx"},
	}
	dm.UserSessions = []UserSession{
		{"skull", "pts/0", "192.168.1.100", "10:31:50", "0s", "bash"},
		{"skull", "pts/1", "192.168.1.100", "09:45:00", "46m", "vim"},
		{"deploy", "pts/2", "10.0.0.5", "08:00:00", "3h", "-bash"},
		{"vps-pruebas", "pts/3", "10.0.0.10", "07:55:00", "2m", "bosctl"},
	}
	dm.PAMUsers = []PAMUser{
		{"skull", "sudo,docker,k8s", "ALL=(ALL)", "10:31:50", "Activo"},
		{"deploy", "deploy,k8s", "NOPASSWD", "09:45:12", "Activo"},
		{"root", "root", "ALL=(ALL)", "—", "Root"},
		{"svc-bos", "bos", "NOPASSWD", "10:32:14", "Daemon"},
		{"vps-pruebas", "sudo", "ALL=(ALL)", "07:55:00", "Activo"},
	}
	dm.K8sRoleBindings = []K8sRoleBinding{
		{"skull", "User", "cluster-admin", "*", true},
		{"deploy", "User", "deploy-role", "default", true},
		{"svc-bos", "ServiceAccount", "bos-daemon-impersonator", "bos-system", true},
		{"bos-agent", "ServiceAccount", "view", "*", true},
		{"coredns", "ServiceAccount", "coredns", "kube-system", true},
	}
	dm.ImpersonEvents = []ImpersonationEvent{
		{"10:31:50", "skull", "kubectl get pods", true},
		{"10:28:30", "skull", "kubectl scale deploy nginx", true},
		{"10:25:11", "deploy", "kubectl delete pod xxx", false},
		{"10:20:05", "skull", "sudo systemctl restart sshd", true},
		{"10:15:00", "deploy", "kubectl get secrets", false},
	}
	dm.KernelInfo = KernelInfo{
		Version: "7.0.0-22-generic", Arch: "x86_64", BootTime: "2026-05-30 10:00:00",
		Modules: []KernelModule{
			{"overlay", "122880", 0, "Live"}, {"br_netfilter", "32768", 0, "Live"},
			{"ip_tables", "32768", 1, "Live"}, {"nf_conntrack", "204800", 5, "Live"},
			{"xt_conntrack", "16384", 3, "Live"}, {"veth", "32768", 4, "Live"},
			{"xt_MASQUERADE", "20480", 2, "Live"}, {"nf_nat", "57344", 3, "Live"},
		},
		Params: [][2]string{
			{"vm.swappiness", "10"}, {"net.ipv4.ip_forward", "1"},
			{"kernel.nmi_watchdog", "0"}, {"net.core.somaxconn", "65535"},
			{"vm.max_map_count", "262144"}, {"net.ipv4.conf.all.forwarding", "1"},
			{"kernel.panic", "10"}, {"net.bridge.bridge-nf-call-iptables", "1"},
		},
	}
	dm.UFWRules = []UFWRule{
		{1, "ALLOW", "Anywhere", "22/tcp", "tcp", "SSH"},
		{2, "ALLOW", "Anywhere", "80/tcp", "tcp", "HTTP"},
		{3, "ALLOW", "Anywhere", "443/tcp", "tcp", "HTTPS"},
		{4, "DENY", "Anywhere", "23/tcp", "tcp", "Telnet"},
		{5, "ALLOW", "10.0.0.0/8", "ANY", "any", "LAN interna"},
		{6, "DENY", "Anywhere", "3306/tcp", "tcp", "MySQL ext"},
		{7, "ALLOW", "10.244.0.0/16", "ANY", "any", "K8s pods"},
		{8, "DENY", "Anywhere", "ANY", "any", "Default deny"},
	}
	dm.StorageDisks = []StorageDisk{
		{"/dev/sda", "QEMU HARDDISK QM00001", 120, 35, "PASSED", 504, 0},
		{"/dev/sdb", "QEMU HARDDISK QM00002", 50, 34, "PASSED", 504, 0},
	}
	dm.Certificates = []Certificate{
		{"sbos.local", "Let's Encrypt", "2026-09-15", 95, "RSA-2048", true},
		{"api.sbos.local", "Let's Encrypt", "2026-09-15", 95, "RSA-2048", true},
		{"admin.sbos.local", "SBOS CA", "2027-06-11", 365, "ED25519", true},
		{"etcd-server", "SBOS CA", "2026-06-25", 13, "RSA-2048", true},
		{"kubelet-node-1", "K8s CA", "2027-06-11", 365, "RSA-2048", true},
	}
	dm.CVEs = []CVEEntry{
		{"CVE-2024-1234", "HIGH", "openssl", "3.0.1", "3.0.2", "Buffer overflow en SSL_read"},
		{"CVE-2024-5678", "MEDIUM", "curl", "7.81.0", "7.81.1", "HTTP/2 header injection"},
		{"CVE-2024-9012", "LOW", "bash", "5.1.16", "5.2.0", "Integer overflow en printf"},
	}
	dm.BackupJobs = []BackupJob{
		{"postgres-daily", "/var/lib/postgresql", "0 2 * * *", "2026-06-12 02:00", "4.2 GB", "OK", "2026-06-13 02:00"},
		{"redis-hourly", "/var/lib/redis", "0 * * * *", "2026-06-12 11:00", "128 MB", "OK", "2026-06-12 12:00"},
		{"bos-state", "/var/lib/bos", "*/30 * * * *", "2026-06-12 11:30", "2.1 MB", "OK", "2026-06-12 12:00"},
		{"etcd-snapshot", "/var/lib/etcd", "0 */6 * * *", "2026-06-12 06:00", "2.1 GB", "OK", "2026-06-12 12:00"},
	}
	dm.MonCPU = []float64{45, 48, 52, 55, 60, 58, 62, 65, 63, 67, 70, 68, 65, 62, 58, 55, 52, 56, 60, 63, 65, 62, 58, 55, 60, 63, 65, 68, 65, 62}
	dm.MonRAM = []float64{60, 61, 62, 62, 63, 63, 64, 65, 65, 65, 66, 66, 65, 65, 65, 64, 64, 63, 63, 64, 64, 65, 65, 65, 64, 64, 65, 65, 65, 65}
	dm.MonNet = []float64{0.5, 0.8, 1.2, 1.5, 1.8, 2.0, 1.8, 1.5, 1.2, 1.0, 0.8, 1.2, 1.5, 1.8, 2.2, 2.5, 2.0, 1.8, 1.5, 1.2, 1.0, 0.8, 1.2, 1.5, 1.8, 2.0, 1.8, 1.5, 1.2, 1.0}
	dm.MonPods = []int{12, 13, 13, 14, 15, 15, 15, 15, 14, 15, 15, 15, 15, 14, 14, 15, 15, 15, 14, 14, 15, 15, 15, 15, 14, 15, 15, 15, 15, 15}
	dm.BosConf = BosConfig{
		Version: "v2.0.0-dev", Socket: "/run/bos/bos.sock",
		StateFile: "/var/lib/bos/.sbos_state.json", LogLevel: "info",
		ReconcileS: 60, MaxRetries: 3, Env: "DEV",
		K8sContext: "sbos-dev", Namespace: "bos-system",
	}
}

func buildMockLogs() []LogEntry {
	now := time.Now()
	entries := []struct {
		lvl    LogLevel
		daemon string
		msg    string
		ago    time.Duration
	}{
		{LogInfo, "bos-agent", "heartbeat ok", 0},
		{LogInfo, "k8s", "pod nginx-7d4f9 healthy, replicas=5 (HPA scale-up)", 4 * time.Second},
		{LogWarn, "k8s", "coredns-2xk9 — ImagePullBackOff", 9 * time.Second},
		{LogError, "k8s", "metrics-srv crashloop — exit 1 (restart #12)", 16 * time.Second},
		{LogInfo, "bos-agent", "impersonate skull → kubectl get pods → OK", 24 * time.Second},
		{LogInfo, "hpa", "nginx scale 3→5 replicas (CPU: 85%)", 34 * time.Second},
		{LogWarn, "pam", "deploy sudo kubectl delete — DENIED (not in sudoers)", 44 * time.Second},
		{LogInfo, "keda", "queue-scaler trigger kafka 1250/1000 → scale 5→8", 64 * time.Second},
		{LogInfo, "vpa", "worker-vpa applying mem 256Mi→512Mi", 74 * time.Second},
		{LogInfo, "bos-agent", "heartbeat ok", 94 * time.Second},
		{LogInfo, "etcd", "snapshot ok, size: 2.1GB", 104 * time.Second},
		{LogWarn, "node-1", "core-5 CPU 88% (threshold: 85%)", 114 * time.Second},
	}
	logs := make([]LogEntry, len(entries))
	for i, e := range entries {
		t := now.Add(-e.ago)
		logs[i] = LogEntry{
			Level:   e.lvl,
			Time:    fmt.Sprintf("%02d:%02d:%02d", t.Hour(), t.Minute(), t.Second()),
			Daemon:  e.daemon,
			Message: e.msg,
		}
	}
	return logs
}
