package config

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ── Architecture Defaults ───────────────────────────────────

func TestArchDefaults(t *testing.T) {
	cfg := archDefaults()

	assert.Equal(t, "info", cfg.LogLevel)
	assert.Equal(t, 5, cfg.LockTimeoutSeconds)
	assert.Equal(t, 30, cfg.HealthCheckIntervalSeconds)
	assert.Equal(t, 3, cfg.ConsecutiveFailuresThreshold)
	assert.Equal(t, 300, cfg.ReconcileIntervalSeconds)
	assert.True(t, cfg.DriftCheck)
	assert.Equal(t, 30, cfg.InstallTimeoutMinutes)
	assert.Equal(t, 15, cfg.UpdateTimeoutMinutes)
	assert.Equal(t, 10, cfg.RepairTimeoutMinutes)
	assert.Equal(t, 10, cfg.UninstallTimeoutMinutes)
	assert.Equal(t, 120, cfg.DeployTimeoutMinutes)
	assert.Equal(t, 80, cfg.CPUThresholdPercent)
	assert.Equal(t, 85, cfg.RAMThresholdPercent)
	assert.Equal(t, 75, cfg.DiskThresholdPercent)
	assert.Equal(t, 30, cfg.EvaluationWindowMinutes)
}

// ── Install Defaults ────────────────────────────────────────

func TestInstallDefaults(t *testing.T) {
	inst := installDefaults()

	assert.Equal(t, "stable", inst.Channel)
	assert.Equal(t, 9443, inst.HTTPPort)
	assert.Equal(t, "/opt/bos", inst.BosPath)
	assert.Equal(t, "/etc/bos", inst.EtcPath)
	assert.Equal(t, "/run/bos", inst.RunPath)
	assert.Equal(t, "/var/log/bos", inst.LogPath)
	assert.Equal(t, "/run/bos/bos.sock", inst.UnixSocket)
	assert.Equal(t, "bosagent", inst.BosUser)
	assert.Equal(t, "bosagent", inst.BosGroup)
	assert.Equal(t, "4G", inst.MemoryMax)
	assert.Equal(t, 200000, inst.CPUQuota)
	assert.Equal(t, 100000, inst.CPUPeriod)
	assert.Equal(t, 500, inst.IOWeight)
	assert.NotNil(t, inst.DNS.Subdomains)
	assert.NotEmpty(t, inst.DNS.Subdomains)
}

// ── DNS ─────────────────────────────────────────────────────

func TestDNSSubdomain(t *testing.T) {
	dns := &DNSConfig{
		BaseDomain: "skull.local",
		Subdomains: map[string]string{
			"auth": "auth",
			"api":  "gateway-api",
		},
	}

	assert.Equal(t, "auth.skull.local", dns.Subdomain("auth"))
	assert.Equal(t, "gateway-api.skull.local", dns.Subdomain("api"))
	assert.Equal(t, "unknown.skull.local", dns.Subdomain("unknown"))
}

// ── TOML Loading ────────────────────────────────────────────

func TestLoad_FullConfig(t *testing.T) {
	dir := t.TempDir()

	bosToml := filepath.Join(dir, "bos.toml")
	installToml := filepath.Join(dir, "bos-install.toml")

	require.NoError(t, os.WriteFile(bosToml, []byte(`
log_level = "debug"
lock_timeout_seconds = 10
health_check_interval_seconds = 60
consecutive_failures_threshold = 5
reconcile_interval_seconds = 600
drift_check = false
`), 0644))

	require.NoError(t, os.WriteFile(installToml, []byte(`
org_name = "TestCorp"
client_domain = "testcorp.local"
server_ip = "10.0.0.1"
release_server_url = "https://releases.testcorp.local"
channel = "testing"
http_port = 8080
bos_path = "/custom/bos"
core_path = "/custom/bos/core"
etc_path = "/custom/etc/bos"
run_path = "/custom/run/bos"
log_path = "/custom/log/bos"
state_file = "/custom/etc/bos/.sbos_state.json"
servers_path = "/custom/etc/bos/blibs/servers"
kubeconfig_path = "/custom/etc/bos/.kube/config"
unix_socket = "/custom/run/bos/bos.sock"
bos_user = "testuser"
bos_group = "testgroup"
memory_max = "8G"
cpu_quota = 400000
cpu_period = 100000
io_weight = 750

[dns]
base_domain = "testcorp.local"

[dns.subdomains]
auth = "iam"
api = "rest"
`), 0644))

	cfg, err := Load(bosToml)
	require.NoError(t, err)

	assert.Equal(t, "debug", cfg.LogLevel)
	assert.Equal(t, 10, cfg.LockTimeoutSeconds)
	assert.Equal(t, 60, cfg.HealthCheckIntervalSeconds)
	assert.Equal(t, 5, cfg.ConsecutiveFailuresThreshold)
	assert.Equal(t, 600, cfg.ReconcileIntervalSeconds)
	assert.False(t, cfg.DriftCheck)

	// Install overrides
	assert.Equal(t, "TestCorp", cfg.Install.OrgName)
	assert.Equal(t, "testcorp.local", cfg.Install.ClientDomain)
	assert.Equal(t, "10.0.0.1", cfg.Install.ServerIP)
	assert.Equal(t, "https://releases.testcorp.local", cfg.Install.ReleaseServerURL)
	assert.Equal(t, "testing", cfg.Install.Channel)
	assert.Equal(t, 8080, cfg.Install.HTTPPort)
	assert.Equal(t, "/custom/bos", cfg.Install.BosPath)
	assert.Equal(t, "/custom/etc/bos", cfg.Install.EtcPath)
	assert.Equal(t, "/custom/run/bos", cfg.Install.RunPath)
	assert.Equal(t, "/custom/log/bos", cfg.Install.LogPath)
	assert.Equal(t, "/custom/etc/bos/.sbos_state.json", cfg.Install.StateFile)
	assert.Equal(t, "/custom/etc/bos/blibs/servers", cfg.Install.ServersPath)
	assert.Equal(t, "/custom/etc/bos/.kube/config", cfg.Install.KubeconfigPath)
	assert.Equal(t, "/custom/run/bos/bos.sock", cfg.Install.UnixSocket)
	assert.Equal(t, "testuser", cfg.Install.BosUser)
	assert.Equal(t, "testgroup", cfg.Install.BosGroup)
	assert.Equal(t, "8G", cfg.Install.MemoryMax)
	assert.Equal(t, 400000, cfg.Install.CPUQuota)
	assert.Equal(t, 100000, cfg.Install.CPUPeriod)
	assert.Equal(t, 750, cfg.Install.IOWeight)
	assert.Equal(t, "testcorp.local", cfg.Install.DNS.BaseDomain)
	// El decoder TOML interno no soporta sub-secciones anidadas [dns.subdomains];
	// las claves de mapas en sub-secciones son ignoradas. Subdomains usa defaults
	// (auth -> "auth", api -> "api"), por lo que Subdomain("auth") retorna "auth.testcorp.local"
	assert.Equal(t, "auth.testcorp.local", cfg.Install.DNS.Subdomain("auth"))
}

// ── Minimal Config (only bos.toml, install missing) ─────────

func TestLoad_MissingInstallConfig(t *testing.T) {
	dir := t.TempDir()
	bosToml := filepath.Join(dir, "bos.toml")

	require.NoError(t, os.WriteFile(bosToml, []byte(`log_level = "warn"`), 0644))

	cfg, err := Load(bosToml)
	assert.Error(t, err)
	assert.True(t, IsConfigPending(err))
	assert.Equal(t, ErrInstallConfigMissing, err)

	// Config should still be usable with defaults
	assert.Equal(t, "warn", cfg.LogLevel)
	assert.Equal(t, "stable", cfg.Install.Channel)
}

// ── Environment Variable Overrides ──────────────────────────

func TestLoad_EnvOverrides(t *testing.T) {
	dir := t.TempDir()
	bosToml := filepath.Join(dir, "bos.toml")
	installToml := filepath.Join(dir, "bos-install.toml")

	require.NoError(t, os.WriteFile(bosToml, []byte(`log_level = "info"`), 0644))
	require.NoError(t, os.WriteFile(installToml, []byte(`
org_name = "FileCorp"
client_domain = "file.local"
server_ip = "10.0.0.1"
channel = "stable"
http_port = 9443
`), 0644))

	// Set env overrides
	os.Setenv("BOS_ORG_NAME", "EnvCorp")
	os.Setenv("BOS_LOG_LEVEL", "debug")
	os.Setenv("BOS_CHANNEL", "testing")
	os.Setenv("BOS_HTTP_PORT", "7777")
	os.Setenv("BOS_CLIENT_DOMAIN", "env.local")
	os.Setenv("BOS_RELEASE_URL", "https://releases.env.local")
	os.Setenv("BOS_STATE_FILE", "/env/state.json")
	os.Setenv("BOS_KUBECONFIG", "/env/kubeconfig")
	os.Setenv("BOS_SOCKET", "/env/bos.sock")
	os.Setenv("BOS_SERVER_IP", "192.168.1.1")

	defer func() {
		for _, v := range []string{
			"BOS_ORG_NAME", "BOS_LOG_LEVEL", "BOS_CHANNEL", "BOS_HTTP_PORT",
			"BOS_CLIENT_DOMAIN", "BOS_RELEASE_URL", "BOS_STATE_FILE",
			"BOS_KUBECONFIG", "BOS_SOCKET", "BOS_SERVER_IP",
		} {
			os.Unsetenv(v)
		}
	}()

	cfg, err := Load(bosToml)
	require.NoError(t, err)

	assert.Equal(t, "EnvCorp", cfg.Install.OrgName)
	assert.Equal(t, "debug", cfg.LogLevel)
	assert.Equal(t, "testing", cfg.Install.Channel)
	assert.Equal(t, 7777, cfg.Install.HTTPPort)
	assert.Equal(t, "env.local", cfg.Install.ClientDomain)
	assert.Equal(t, "https://releases.env.local", cfg.Install.ReleaseServerURL)
	assert.Equal(t, "/env/state.json", cfg.Install.StateFile)
	assert.Equal(t, "/env/kubeconfig", cfg.Install.KubeconfigPath)
	assert.Equal(t, "/env/bos.sock", cfg.Install.UnixSocket)
	assert.Equal(t, "192.168.1.1", cfg.Install.ServerIP)
}

// ── Validation ──────────────────────────────────────────────

func TestValidate_PortRange(t *testing.T) {
	dir := t.TempDir()
	bosToml := filepath.Join(dir, "bos.toml")
	installToml := filepath.Join(dir, "bos-install.toml")

	require.NoError(t, os.WriteFile(bosToml, []byte(`log_level = "info"`), 0644))

	require.NoError(t, os.WriteFile(installToml, []byte(`
org_name = "Test"
client_domain = "test.local"
http_port = 99999
`), 0644))

	_, err := Load(bosToml)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "http_port")
}

func TestValidate_Channel(t *testing.T) {
	dir := t.TempDir()
	bosToml := filepath.Join(dir, "bos.toml")
	installToml := filepath.Join(dir, "bos-install.toml")

	require.NoError(t, os.WriteFile(bosToml, []byte(`log_level = "info"`), 0644))
	require.NoError(t, os.WriteFile(installToml, []byte(`
org_name = "Test"
client_domain = "test.local"
channel = "nightly"
`), 0644))

	_, err := Load(bosToml)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "channel")
}

func TestValidate_LogLevel(t *testing.T) {
	dir := t.TempDir()
	bosToml := filepath.Join(dir, "bos.toml")
	installToml := filepath.Join(dir, "bos-install.toml")

	require.NoError(t, os.WriteFile(bosToml, []byte(`log_level = "trace"`), 0644))
	require.NoError(t, os.WriteFile(installToml, []byte(`
org_name = "Test"
client_domain = "test.local"
`), 0644))

	_, err := Load(bosToml)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "log_level")
}

func TestValidate_RequiredOrgName(t *testing.T) {
	dir := t.TempDir()
	bosToml := filepath.Join(dir, "bos.toml")
	installToml := filepath.Join(dir, "bos-install.toml")

	require.NoError(t, os.WriteFile(bosToml, []byte(`log_level = "info"`), 0644))
	require.NoError(t, os.WriteFile(installToml, []byte(`
client_domain = "test.local"
`), 0644))

	_, err := Load(bosToml)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "org_name")
}

func TestValidate_RequiredClientDomain(t *testing.T) {
	dir := t.TempDir()
	bosToml := filepath.Join(dir, "bos.toml")
	installToml := filepath.Join(dir, "bos-install.toml")

	require.NoError(t, os.WriteFile(bosToml, []byte(`log_level = "info"`), 0644))
	require.NoError(t, os.WriteFile(installToml, []byte(`
org_name = "Test"
`), 0644))

	_, err := Load(bosToml)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "client_domain")
}

func TestValidate_HealthCheckMin(t *testing.T) {
	dir := t.TempDir()
	bosToml := filepath.Join(dir, "bos.toml")
	installToml := filepath.Join(dir, "bos-install.toml")

	require.NoError(t, os.WriteFile(bosToml, []byte(`
log_level = "info"
health_check_interval_seconds = 1
`), 0644))
	require.NoError(t, os.WriteFile(installToml, []byte(`
org_name = "Test"
client_domain = "test.local"
`), 0644))

	_, err := Load(bosToml)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "health_check_interval_seconds")
}

// ── Duration helpers ────────────────────────────────────────

func TestHealthCheckInterval(t *testing.T) {
	cfg := archDefaults()
	assert.Equal(t, "30s", cfg.HealthCheckInterval().String())
}

func TestReconcileInterval(t *testing.T) {
	cfg := archDefaults()
	assert.Equal(t, "5m0s", cfg.ReconcileInterval().String())
}

func TestSagaTimeout(t *testing.T) {
	cfg := archDefaults()

	assert.Equal(t, "30m0s", cfg.SagaTimeout("install").String())
	assert.Equal(t, "15m0s", cfg.SagaTimeout("update").String())
	assert.Equal(t, "10m0s", cfg.SagaTimeout("repair").String())
	assert.Equal(t, "10m0s", cfg.SagaTimeout("remove").String())
	assert.Equal(t, "10m0s", cfg.SagaTimeout("uninstall").String())
	assert.Equal(t, "2h0m0s", cfg.SagaTimeout("deploy").String())
	assert.Equal(t, "30m0s", cfg.SagaTimeout("unknown").String())
}

// ── Subdomain catalog ──────────────────────────────────────

func TestDefaultSubdomains(t *testing.T) {
	subs := defaultSubdomains()
	assert.Greater(t, len(subs), 20)
	assert.Equal(t, "auth", subs["auth"])
	assert.Equal(t, "gateway", subs["gateway"])
	assert.Equal(t, "data", subs["data"])
}

// ── BOS_INSTALL_TOML env var ────────────────────────────────

func TestLoad_InstallFromEnvVar(t *testing.T) {
	bosDir := t.TempDir()
	installDir := t.TempDir()

	bosToml := filepath.Join(bosDir, "bos.toml")
	installToml := filepath.Join(installDir, "my-install.toml")

	require.NoError(t, os.WriteFile(bosToml, []byte(`log_level = "info"`), 0644))
	require.NoError(t, os.WriteFile(installToml, []byte(`
org_name = "CustomPath"
client_domain = "custom.local"
`), 0644))

	os.Setenv("BOS_INSTALL_TOML", installToml)
	defer os.Unsetenv("BOS_INSTALL_TOML")

	cfg, err := Load(bosToml)
	require.NoError(t, err)
	assert.Equal(t, "CustomPath", cfg.Install.OrgName)
}

// ── Install config partial (merge with defaults) ────────────

func TestLoad_PartialInstallConfig(t *testing.T) {
	dir := t.TempDir()
	bosToml := filepath.Join(dir, "bos.toml")
	installToml := filepath.Join(dir, "bos-install.toml")

	require.NoError(t, os.WriteFile(bosToml, []byte(`log_level = "info"`), 0644))
	// Only provide required fields, rely on defaults for the rest
	require.NoError(t, os.WriteFile(installToml, []byte(`
org_name = "MinimalCorp"
client_domain = "minimal.local"
`), 0644))

	cfg, err := Load(bosToml)
	require.NoError(t, err)

	// Required overrides
	assert.Equal(t, "MinimalCorp", cfg.Install.OrgName)
	assert.Equal(t, "minimal.local", cfg.Install.ClientDomain)

	// Defaults preserved
	assert.Equal(t, "stable", cfg.Install.Channel)
	assert.Equal(t, 9443, cfg.Install.HTTPPort)
	assert.Equal(t, "/opt/bos", cfg.Install.BosPath)
	assert.Equal(t, "info", cfg.LogLevel)
}

// ── bos.toml does not exist (optional) ──────────────────────

func TestLoad_NoRuntimeConfig(t *testing.T) {
	dir := t.TempDir()
	bosToml := filepath.Join(dir, "bos.toml")
	installToml := filepath.Join(dir, "bos-install.toml")

	// Don't create bos.toml — only bos-install.toml
	require.NoError(t, os.WriteFile(installToml, []byte(`
org_name = "NoRuntime"
client_domain = "noruntime.local"
`), 0644))

	cfg, err := Load(bosToml)
	require.NoError(t, err)

	assert.Equal(t, "info", cfg.LogLevel) // arch default
	assert.Equal(t, "NoRuntime", cfg.Install.OrgName)
}
