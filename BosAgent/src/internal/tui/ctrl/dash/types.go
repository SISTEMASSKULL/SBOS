package dash

import "time"

// FocusZone indica qué panel del dashboard tiene el foco de teclado.
type FocusZone int

const (
	FocusMenu FocusZone = iota
	FocusBody
)

// ── Tipos de sistema ─────────────────────────────────────────────────────────

type CPUInfo struct {
	Cores   []float64
	Load1   float64
	Load5   float64
	Load15  float64
	Procs   int
	Threads int
	Uptime  time.Duration
}

type MemInfo struct {
	TotalGB   float64
	UsedGB    float64
	FreeGB    float64
	BuffGB    float64
	SwapTotal float64
	SwapUsed  float64
}

type Disk struct {
	Mount   string
	UsedGB  float64
	TotalGB float64
}

type NetStats struct {
	Iface     string
	TXBytesS  float64
	RXBytesS  float64
	TXTotalGB float64
	RXTotalGB float64
}

type NodeInfo struct {
	Name    string
	Ready   bool
	CPUPct  float64
	MemPct  float64
	Pods    int
	MaxPods int
}

// ── Kubernetes ───────────────────────────────────────────────────────────────

type PodStatus int

const (
	PodRunning PodStatus = iota
	PodPending
	PodFailed
)

type Pod struct {
	Name      string
	Namespace string
	Status    PodStatus
	Ready     string
	Restarts  int
	CPUm      int
	MemMi     int
	Age       string
}

type CPComp struct {
	Name      string
	Healthy   bool
	Warning   bool
	LatencyMs float64
	ErrorsMin int
	Uptime    string
}

type HPAStatus int

const (
	HPAStable HPAStatus = iota
	HPAScaling
	HPAAtMax
)

type HPA struct {
	Name        string
	Target      string
	MinReplicas int
	MaxReplicas int
	Current     int
	CPUTarget   int
	CPUCurrent  int
	Status      HPAStatus
}

// ── Autoscaling K8s ──────────────────────────────────────────────────────────

type VPAStatus int

const (
	VPAApplying VPAStatus = iota
	VPAStable
	VPARec
)

type VPA struct {
	Name      string
	Namespace string
	Target    string
	Mode      string
	CPURec    string
	MemRec    string
	Status    VPAStatus
}

type KEDAStatus int

const (
	KEDARunning KEDAStatus = iota
	KEDAIdle
	KEDAZero
)

type KEDAScaler struct {
	Name        string
	Namespace   string
	Target      string
	TriggerType string
	CurrentVal  int
	Threshold   int
	Replicas    int
	Status      KEDAStatus
}

type ClusterAutoscalerInfo struct {
	NodesTotal        int
	NodesReady        int
	NodesMax          int
	LastScaleUp       string
	LastScaleDown     string
	CPUCluster        float64
	MemCluster        float64
	UnschedulablePods int
}

type ResourceQuotaItem struct {
	Resource string
	Used     string
	Hard     string
	Percent  float64
}

type ResourceQuota struct {
	Namespace string
	Items     []ResourceQuotaItem
}

type LimitRangeItem struct {
	LRType     string
	Resource   string
	DefaultReq string
	DefaultLim string
	Min        string
	Max        string
}

type PodDisruptionBudget struct {
	Name      string
	Namespace string
	Selector  string
	MinAvail  int
	Available int
	Healthy   bool
}

// ── Network K8s ──────────────────────────────────────────────────────────────

type K8sService struct {
	Name      string
	Namespace string
	SvcType   string
	ClusterIP string
	Port      string
	Age       string
}

type K8sIngress struct {
	Name      string
	Namespace string
	Host      string
	Path      string
	Backend   string
	TLS       bool
	Age       string
}

type K8sNetworkPolicy struct {
	Name         string
	Namespace    string
	PodSelector  string
	IngressRules int
	EgressRules  int
	Age          string
}

// ── Storage K8s ──────────────────────────────────────────────────────────────

type PersistentVolume struct {
	Name          string
	Capacity      string
	AccessMode    string
	ReclaimPolicy string
	PVStatus      string
	StorageClass  string
	Claim         string
	Age           string
}

type PVC struct {
	Name         string
	Namespace    string
	PVCStatus    string
	Volume       string
	Capacity     string
	AccessMode   string
	StorageClass string
	Age          string
}

type StorageClass struct {
	Name          string
	Provisioner   string
	ReclaimPolicy string
	VolumeBinding string
	IsDefault     bool
	Age           string
}

// ── Servicios systemd ────────────────────────────────────────────────────────

type Service struct {
	Name   string
	Active bool
	Failed bool
	Since  string
}

// ── Alertas ──────────────────────────────────────────────────────────────────

type AlertSeverity int

const (
	SevCritical AlertSeverity = iota
	SevWarning
	SevInfo
)

type Alert struct {
	Severity AlertSeverity
	Name     string
	Source   string
	Message  string
	Since    string
	Silenced bool
}

// ── Logs ─────────────────────────────────────────────────────────────────────

type LogLevel int

const (
	LogInfo LogLevel = iota
	LogWarn
	LogError
)

type LogEntry struct {
	Level   LogLevel
	Time    string
	Daemon  string
	Message string
}

// ── Jobs ─────────────────────────────────────────────────────────────────────

type InstallJob struct {
	Name   string
	Active bool
	Pct    int
	Items  string
}

// ── OS ───────────────────────────────────────────────────────────────────────

type OSProcess struct {
	PID    int
	Name   string
	User   string
	CPUPct float64
	MemPct float64
	RSS    string
	Status string
	PTime  string
}

type NetworkInterface struct {
	Name     string
	IPAddr   string
	State    string
	TXBytesS float64
	RXBytesS float64
	TXTotal  string
	RXTotal  string
}

type TCPConn struct {
	LocalAddr  string
	RemoteAddr string
	State      string
	PID        int
	Process    string
}

// ── Identidad ────────────────────────────────────────────────────────────────

type UserSession struct {
	User    string
	TTY     string
	From    string
	LoginAt string
	Idle    string
	What    string
}

type PAMUser struct {
	Name     string
	Groups   string
	SudoRule string
	LastSudo string
	Status   string
}

type K8sRoleBinding struct {
	Subject     string
	SubjectType string
	Role        string
	Namespace   string
	Active      bool
}

type ImpersonationEvent struct {
	EventTime string
	AsUser    string
	Operation string
	Result    bool
}

// ── Kernel OS ────────────────────────────────────────────────────────────────

type KernelModule struct {
	Name   string
	Size   string
	Used   int
	Status string
}

type KernelInfo struct {
	Version  string
	Arch     string
	BootTime string
	Modules  []KernelModule
	Params   [][2]string
}

// ── Network OS ───────────────────────────────────────────────────────────────

type UFWRule struct {
	Number  int
	Action  string
	From    string
	To      string
	Proto   string
	Comment string
}

// ── Storage OS ───────────────────────────────────────────────────────────────

type StorageDisk struct {
	Device      string
	Model       string
	SizeGB      float64
	TempC       int
	Health      string
	PowerOnH    int
	Reallocated int
}

// ── Seguridad ─────────────────────────────────────────────────────────────────

type Certificate struct {
	CommonName string
	Issuer     string
	ExpiresAt  string
	DaysLeft   int
	Algorithm  string
	Valid      bool
}

type CVEEntry struct {
	ID       string
	Severity string
	Package  string
	Version  string
	Fixed    string
	Desc     string
}

// ── Backups ───────────────────────────────────────────────────────────────────

type BackupJob struct {
	Name     string
	Target   string
	Schedule string
	LastRun  string
	LastSize string
	Status   string
	NextRun  string
}

// ── Config ───────────────────────────────────────────────────────────────────

type BosConfig struct {
	Version    string
	Socket     string
	StateFile  string
	LogLevel   string
	ReconcileS int
	MaxRetries int
	Env        string
	K8sContext string
	Namespace  string
}
