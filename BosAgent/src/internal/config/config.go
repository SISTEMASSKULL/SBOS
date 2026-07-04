// Package config loads and validates bos.toml + bos-install.toml configuration.
// R16 Zero Hardcoding: no paths or install-specific values in Defaults().
// Resolution order: env var > bos-install.toml > bos.toml > built-in defaults.
package config

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"bos/internal/toml"
)

// InstallConfig contiene los parámetros de instalación específicos del cliente.
// Cargados desde bos-install.toml (SBOS-035 §1.1 + SBOS-018 §23a + SBOS-050 §DNS).
//
// Thread safety: inmutable tras Load(); no modificar en tiempo de ejecución.
type InstallConfig struct {
	OrgName          string    `toml:"org_name"`
	ClientDomain     string    `toml:"client_domain"`
	ServerIP         string    `toml:"server_ip"`
	ReleaseServerURL string    `toml:"release_server_url"`
	Channel          string    `toml:"channel"`
	HTTPPort         int       `toml:"http_port"`
	BosPath          string    `toml:"bos_path"`
	CorePath         string    `toml:"core_path"`
	EtcPath          string    `toml:"etc_path"`
	RunPath          string    `toml:"run_path"`
	LogPath          string    `toml:"log_path"`
	StateFile        string    `toml:"state_file"`
	ServersPath      string    `toml:"servers_path"`
	KubeconfigPath   string    `toml:"kubeconfig_path"`
	UnixSocket       string    `toml:"unix_socket"`
	BosUser          string    `toml:"bos_user"`
	BosGroup         string    `toml:"bos_group"`
	MemoryMax        string    `toml:"memory_max"`
	CPUQuota         int       `toml:"cpu_quota"`
	CPUPeriod        int       `toml:"cpu_period"`
	IOWeight         int       `toml:"io_weight"`
	DNS              DNSConfig `toml:"dns"`

	// Context Plane — conexiones reales PG + Redis (SBOS-049, M3.1)
	// Env vars: BOS_PG_DSN, BOS_REDIS_ADDR, BOS_REDIS_DB
	PostgresDSN string `toml:"postgres_dsn"`
	RedisAddr   string `toml:"redis_addr"`
	RedisDB     int    `toml:"redis_db"`
}

// DNSConfig holds subdomain-to-service mapping. R16: no subdomain hardcoded in code.
// Schema: SBOS-050.
type DNSConfig struct {
	BaseDomain string            `toml:"base_domain"`
	Subdomains map[string]string `toml:"subdomains"`
}

// Subdomain retorna el FQDN para un servicio nombrado (subdomain + "." + baseDomain).
func (d *DNSConfig) Subdomain(name string) string {
	sub, ok := d.Subdomains[name]
	if !ok {
		sub = name
	}
	return sub + "." + d.BaseDomain
}

// Config contiene toda la configuración del daemon bos.
// Los valores de instalación vienen de InstallConfig (bos-install.toml).
// Los valores de tiempo de ejecución vienen de bos.toml o de defaults arquitectónicos.
//
// Thread safety: inmutable tras Load(); no modificar en tiempo de ejecución.
type Config struct {
	Install InstallConfig

	// Runtime — from bos.toml
	LogLevel string `toml:"log_level"`

	// State — from bos.toml [state]
	LockTimeoutSeconds int `toml:"lock_timeout_seconds"`

	// Health — from bos.toml [health]
	HealthCheckIntervalSeconds   int `toml:"health_check_interval_seconds"`
	ConsecutiveFailuresThreshold int `toml:"consecutive_failures_threshold"`

	// Reconcile — from bos.toml [reconcile]
	ReconcileIntervalSeconds int  `toml:"reconcile_interval_seconds"`
	DriftCheck               bool `toml:"drift_check"`

	// Sagas — from bos.toml [sagas]
	InstallTimeoutMinutes   int `toml:"install_timeout_minutes"`
	UpdateTimeoutMinutes    int `toml:"update_timeout_minutes"`
	RepairTimeoutMinutes    int `toml:"repair_timeout_minutes"`
	UninstallTimeoutMinutes int `toml:"uninstall_timeout_minutes"`
	DeployTimeoutMinutes    int `toml:"deploy_timeout_minutes"`

	// Bauth — from bos.toml [bauth]
	BauthEnabled   bool   `toml:"bauth_enabled"`
	BauthSocket    string `toml:"bauth_socket"`
	BauthTimeoutMs int    `toml:"bauth_timeout_ms"`

	// Growth — from bos.toml [growth]
	CPUThresholdPercent     int `toml:"cpu_threshold_percent"`
	RAMThresholdPercent     int `toml:"ram_threshold_percent"`
	DiskThresholdPercent    int `toml:"disk_threshold_percent"`
	EvaluationWindowMinutes int `toml:"evaluation_window_minutes"`

	// Watchdog — from bos.toml [watchdog]
	WatchdogIntervalSeconds    int  `toml:"watchdog_interval_seconds"`
	WatchdogDiskThresholdPct   int  `toml:"watchdog_disk_threshold_percent"`
	WatchdogMemoryThresholdPct int  `toml:"watchdog_memory_threshold_percent"`
	WatchdogK8sNodeCheck       bool `toml:"watchdog_k8s_node_check"`
	WatchdogK8sPodCheck        bool `toml:"watchdog_k8s_pod_check"`
	WatchdogBOSFichaCheck      bool `toml:"watchdog_bos_ficha_check"`
	WatchdogAutoRepair         bool `toml:"watchdog_auto_repair"`
}

// archDefaults returns Config with architectural defaults only.
// R16: no paths, no URLs, no client-specific values hardcoded here.
func archDefaults() *Config {
	return &Config{
		LogLevel:                     "info",
		LockTimeoutSeconds:           5,
		HealthCheckIntervalSeconds:   30,
		ConsecutiveFailuresThreshold: 3,
		ReconcileIntervalSeconds:     300,
		DriftCheck:                   true,
		InstallTimeoutMinutes:        30,
		UpdateTimeoutMinutes:         15,
		RepairTimeoutMinutes:         10,
		UninstallTimeoutMinutes:      10,
		DeployTimeoutMinutes:         120,
		BauthEnabled:                 false,
		BauthTimeoutMs:               2000,
		CPUThresholdPercent:          80,
		RAMThresholdPercent:          85,
		DiskThresholdPercent:         75,
		EvaluationWindowMinutes:      30,
		WatchdogIntervalSeconds:      30,
		WatchdogDiskThresholdPct:     85,
		WatchdogMemoryThresholdPct:   90,
		WatchdogK8sNodeCheck:         true,
		WatchdogK8sPodCheck:          true,
		WatchdogBOSFichaCheck:        true,
		WatchdogAutoRepair:           false,
	}
}

// installDefaults returns InstallConfig with safe defaults.
// R16: these are fallback values used only when neither env var
// nor bos-install.toml provides them. They are architectural
// defaults, not client-specific. Production deployments MUST
// provide bos-install.toml.
func installDefaults() InstallConfig {
	return InstallConfig{
		Channel:        "stable",
		HTTPPort:       9443,
		BosPath:        "/opt/bos",
		CorePath:       "/opt/bos/core",
		EtcPath:        "/etc/bos",
		RunPath:        "/run/bos",
		LogPath:        "/var/log/bos",
		StateFile:      "/etc/bos/.sbos_state.json",
		ServersPath:    "/etc/bos/blibs/servers",
		KubeconfigPath: "/etc/bos/.kube/config",
		UnixSocket:     "/run/bos/bos.sock",
		BosUser:        "bosagent",
		BosGroup:       "bosagent",
		MemoryMax:      "4G",
		CPUQuota:       200000,
		CPUPeriod:      100000,
		IOWeight:       500,
		DNS: DNSConfig{
			BaseDomain: "",
			Subdomains: defaultSubdomains(),
		},
	}
}

// defaultSubdomains returns the canonical SBOS-050 subdomain catalog.
func defaultSubdomains() map[string]string {
	return map[string]string{
		"auth": "auth", "api": "api", "gateway": "gateway",
		"core": "core", "web": "web", "b2b": "b2b",
		"vault": "vault", "secrets": "secrets", "security": "security",
		"data": "data", "bus": "bus", "queues": "queues",
		"pipeline": "pipeline", "devops": "devops",
		"sync": "sync", "connect": "connect",
		"reports": "reports", "documents": "documents",
		"insights": "insights", "find": "find", "flows": "flows",
		"projects": "projects", "track": "track", "fleet": "fleet",
		"cards": "cards", "screens": "screens", "desktop": "desktop",
		"mail": "mail", "sign": "sign", "status": "status", "support": "support",
	}
}

// Load lee bos.toml y bos-install.toml, aplica overrides de env vars,
// y retorna un Config fusionado.
//
// Recibe:
//   - configPath: string — ruta a bos.toml (paths.BosToml).
//
// Retorna:
//   - *Config con valores finales (defaults < toml < env).
//   - ErrInstallConfigMissing si bos-install.toml no existe y no hay BOS_INSTALL_TOML.
//
// Callers conocidos:
//   - cmd/bos/main.go — main().
//
// Efectos secundarios: lee dos archivos de disco. No modifica el sistema.
//
// Estándares: P16 Zero Hardcoding, SBOS-035 §1.1.
func Load(configPath string) (*Config, error) {
	cfg := archDefaults()
	cfg.Install = installDefaults()

	// 1. Load bos.toml (runtime config) — optional
	if _, err := os.Stat(configPath); err == nil {
		if _, err := toml.DecodeFile(configPath, cfg); err != nil {
			return nil, fmt.Errorf("config: parse %s: %w", configPath, err)
		}
	}

	// 2. Resolve bos-install.toml path
	installPath := os.Getenv("BOS_INSTALL_TOML")
	if installPath == "" {
		dir := filepath.Dir(configPath)
		installPath = filepath.Join(dir, "bos-install.toml")
	}

	// 3. Load bos-install.toml — overlay install parameters
	if _, err := os.Stat(installPath); err == nil {
		if _, err := toml.DecodeFile(installPath, &cfg.Install); err != nil {
			return nil, fmt.Errorf("config: parse %s: %w", installPath, err)
		}
	} else if os.Getenv("BOS_INSTALL_TOML") == "" && os.IsNotExist(err) {
		// bos-install.toml missing and no env override → config-pending
		// Return config with defaults but signal caller via sentinel
		return cfg, ErrInstallConfigMissing
	}

	// 4. Env var overrides (highest priority)
	applyEnvOverrides(cfg)

	// 5. Validate
	if err := cfg.validate(); err != nil {
		return nil, err
	}

	return cfg, nil
}

// ErrInstallConfigMissing signals that bos-install.toml was not found.
// El daemon debe entrar en modo config-pending (staged).
var ErrInstallConfigMissing = fmt.Errorf("config: bos-install.toml not found — config-pending mode")

// IsConfigPending retorna true si el error indica que falta bos-install.toml (modo staged).
func IsConfigPending(err error) bool {
	return err == ErrInstallConfigMissing
}

func applyEnvOverrides(cfg *Config) {
	if v := os.Getenv("BOS_ORG_NAME"); v != "" {
		cfg.Install.OrgName = v
	}
	if v := os.Getenv("BOS_CLIENT_DOMAIN"); v != "" {
		cfg.Install.ClientDomain = v
	}
	if v := os.Getenv("BOS_SERVER_IP"); v != "" {
		cfg.Install.ServerIP = v
	}
	if v := os.Getenv("BOS_RELEASE_URL"); v != "" {
		cfg.Install.ReleaseServerURL = v
	}
	if v := os.Getenv("BOS_CHANNEL"); v != "" {
		cfg.Install.Channel = v
	}
	if v := os.Getenv("BOS_HTTP_PORT"); v != "" {
		fmt.Sscanf(v, "%d", &cfg.Install.HTTPPort)
	}
	if v := os.Getenv("BOS_LOG_LEVEL"); v != "" {
		cfg.LogLevel = v
	}
	if v := os.Getenv("BOS_STATE_FILE"); v != "" {
		cfg.Install.StateFile = v
	}
	if v := os.Getenv("BOS_KUBECONFIG"); v != "" {
		cfg.Install.KubeconfigPath = v
	}
	if v := os.Getenv("BOS_SOCKET"); v != "" {
		cfg.Install.UnixSocket = v
	}
	if v := os.Getenv("BOS_BAUTH_ENABLED"); v != "" {
		cfg.BauthEnabled = v == "true" || v == "1"
	}
	if v := os.Getenv("BOS_BAUTH_SOCKET"); v != "" {
		cfg.BauthSocket = v
	}
	if v := os.Getenv("BOS_BAUTH_TIMEOUT_MS"); v != "" {
		fmt.Sscanf(v, "%d", &cfg.BauthTimeoutMs)
	}
	// Context Plane — PG + Redis (M3.1, SBOS-049)
	if v := os.Getenv("BOS_PG_DSN"); v != "" {
		cfg.Install.PostgresDSN = v
	}
	if v := os.Getenv("BOS_REDIS_ADDR"); v != "" {
		cfg.Install.RedisAddr = v
	}
	if v := os.Getenv("BOS_REDIS_DB"); v != "" {
		fmt.Sscanf(v, "%d", &cfg.Install.RedisDB)
	}
}

func (c *Config) validate() error {
	if c.Install.HTTPPort < 1 || c.Install.HTTPPort > 65535 {
		return fmt.Errorf("config: http_port must be 1-65535, got %d", c.Install.HTTPPort)
	}
	if c.HealthCheckIntervalSeconds < 5 {
		return fmt.Errorf("config: health_check_interval_seconds must be >= 5")
	}
	if c.ReconcileIntervalSeconds < 30 {
		return fmt.Errorf("config: reconcile_interval_seconds must be >= 30")
	}
	switch c.Install.Channel {
	case "stable", "testing", "unstable":
	default:
		return fmt.Errorf("config: channel must be stable/testing/unstable, got %s", c.Install.Channel)
	}
	switch c.LogLevel {
	case "debug", "info", "warn", "error":
	default:
		return fmt.Errorf("config: log_level must be debug/info/warn/error, got %s", c.LogLevel)
	}
	if c.WatchdogIntervalSeconds < 5 {
		return fmt.Errorf("config: watchdog_interval_seconds must be >= 5")
	}
	if c.Install.OrgName == "" {
		return fmt.Errorf("config: org_name is required (set in bos-install.toml or BOS_ORG_NAME)")
	}
	if c.Install.ClientDomain == "" {
		return fmt.Errorf("config: client_domain is required (set in bos-install.toml or BOS_CLIENT_DOMAIN)")
	}
	return nil
}

// HealthCheckInterval retorna el intervalo de health check como time.Duration.
func (c *Config) HealthCheckInterval() time.Duration {
	return time.Duration(c.HealthCheckIntervalSeconds) * time.Second
}

// ReconcileInterval retorna el intervalo de reconciliación como time.Duration.
func (c *Config) ReconcileInterval() time.Duration {
	return time.Duration(c.ReconcileIntervalSeconds) * time.Second
}

// WatchdogInterval retorna el intervalo del ciclo del watchdog como time.Duration.
func (c *Config) WatchdogInterval() time.Duration {
	return time.Duration(c.WatchdogIntervalSeconds) * time.Second
}

// SagaTimeout retorna el timeout configurado para un tipo de saga.
//
// Recibe:
//   - cmd: string — "install" | "update" | "repair" | "remove" | "deploy".
//
// Retorna: time.Duration del campo correspondiente en bos.toml [sagas].
// Si cmd no es reconocido, retorna el timeout de install.
//
// Callers conocidos:
//   - internal/installer/saga.go — TimeoutForCommand.
func (c *Config) SagaTimeout(cmd string) time.Duration {
	switch cmd {
	case "install":
		return time.Duration(c.InstallTimeoutMinutes) * time.Minute
	case "update":
		return time.Duration(c.UpdateTimeoutMinutes) * time.Minute
	case "repair":
		return time.Duration(c.RepairTimeoutMinutes) * time.Minute
	case "remove", "uninstall":
		return time.Duration(c.UninstallTimeoutMinutes) * time.Minute
	case "deploy":
		return time.Duration(c.DeployTimeoutMinutes) * time.Minute
	default:
		return time.Duration(c.InstallTimeoutMinutes) * time.Minute
	}
}
