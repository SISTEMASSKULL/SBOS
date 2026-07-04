package bootstrap

// k8s_verify.go — Verificaciones de criterios C-01..C-08 contra el cluster K8s real.
//
// Cada Check* consulta pods y servicios via kubectl exec/get usando el kubeconfig
// canónico del SBOS. Son la fuente de verdad — no dependen del state file de BOS.

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// K8sResult es el resultado de verificar un criterio contra el cluster K8s.
type K8sResult struct {
	OK     bool
	Detail string
}

// CheckOSBootstrap — C-01: sysctl K8s activos + /data/ presente.
// Verifica los parámetros del kernel directamente vía /proc/sys, no el archivo de config
// (el archivo puede no existir si los parámetros se aplicaron manualmente o por otro proceso).
func CheckOSBootstrap() K8sResult {
	if _, err := os.Stat("/data"); err != nil {
		return K8sResult{false, "/data/ ausente — ejecutar bootstrap start"}
	}
	// ip_forward es el sysctl mínimo para que K8s enrute tráfico de pods
	fwd, err := os.ReadFile("/proc/sys/net/ipv4/ip_forward")
	if err != nil || strings.TrimSpace(string(fwd)) != "1" {
		return K8sResult{false, "net.ipv4.ip_forward no activo — cluster K8s puede no funcionar"}
	}
	return K8sResult{true, "sysctl K8s activos (ip_forward=1), /data/ presente"}
}

// CheckK8sCluster — C-02: kubeconfig presente y API server accesible.
func CheckK8sCluster() K8sResult {
	kc := ResolveKubeconfig()
	if _, err := os.Stat(kc); err != nil {
		return K8sResult{false, "kubeconfig no encontrado: " + kc}
	}
	out, err := runKubectl(kc, "cluster-info", "--request-timeout=5s")
	if err != nil || !strings.Contains(out, "is running") {
		// Fallback: verificar que el binario kubectl puede listar nodos
		out2, err2 := runKubectl(kc, "get", "nodes", "--no-headers", "--request-timeout=5s")
		if err2 != nil || strings.TrimSpace(out2) == "" {
			return K8sResult{false, "API server no accesible con kubeconfig en " + kc}
		}
	}
	return K8sResult{true, "kubeconfig presente y API server accesible"}
}

// CheckCalico — C-03: pods calico-node Running en kube-system.
func CheckCalico() K8sResult {
	kc := ResolveKubeconfig()
	out, err := runKubectl(kc, "get", "pods", "-n", "kube-system",
		"-l", "k8s-app=calico-node", "--no-headers", "--request-timeout=10s")
	if err != nil {
		return K8sResult{false, "error consultando pods calico: " + err.Error()}
	}
	running := 0
	for _, line := range strings.Split(out, "\n") {
		if strings.TrimSpace(line) != "" && strings.Contains(line, "Running") {
			running++
		}
	}
	if running == 0 {
		return K8sResult{false, "calico-node: ningún pod Running en kube-system"}
	}
	return K8sResult{true, fmt.Sprintf("Calico CNI operativo (%d pods Running)", running)}
}

// CheckPostgres — C-04: postgresql-0 Running + acepta conexiones.
func CheckPostgres() K8sResult {
	kc := ResolveKubeconfig()
	phase, err := runKubectl(kc, "get", "pod", "postgresql-0", "-n", "sbos-data",
		"-o", "jsonpath={.status.phase}", "--request-timeout=10s")
	if err != nil || strings.TrimSpace(phase) != "Running" {
		return K8sResult{false, fmt.Sprintf("postgresql-0 no Running (fase: %s)", strings.TrimSpace(phase))}
	}
	ready, err2 := runKubectl(kc, "exec", "postgresql-0", "-n", "sbos-data",
		"--", "pg_isready", "-U", "postgres")
	if err2 != nil || !strings.Contains(ready, "accepting connections") {
		return K8sResult{false, "postgresql-0 Running pero pg_isready falla"}
	}
	return K8sResult{true, "PostgreSQL aceptando conexiones en sbos-data"}
}

// CheckRedis — C-05: redis-0 Running + PONG.
func CheckRedis() K8sResult {
	kc := ResolveKubeconfig()
	phase, err := runKubectl(kc, "get", "pod", "redis-0", "-n", "sbos-data",
		"-o", "jsonpath={.status.phase}", "--request-timeout=10s")
	if err != nil || strings.TrimSpace(phase) != "Running" {
		return K8sResult{false, fmt.Sprintf("redis-0 no Running (fase: %s)", strings.TrimSpace(phase))}
	}
	pong, err2 := runKubectl(kc, "exec", "redis-0", "-n", "sbos-data",
		"--", "redis-cli", "ping")
	if err2 != nil || strings.TrimSpace(pong) != "PONG" {
		return K8sResult{false, "redis-0 Running pero PING no retorna PONG"}
	}
	return K8sResult{true, "Redis PONG en sbos-data"}
}

// CheckVault — C-06: vault-0 Running + initialized + unsealed.
func CheckVault() K8sResult {
	kc := ResolveKubeconfig()
	phase, err := runKubectl(kc, "get", "pod", "vault-0", "-n", "sbos-security",
		"-o", "jsonpath={.status.phase}", "--request-timeout=10s")
	if err != nil || strings.TrimSpace(phase) != "Running" {
		return K8sResult{false, fmt.Sprintf("vault-0 no Running (fase: %s)", strings.TrimSpace(phase))}
	}
	status, err2 := runKubectl(kc, "exec", "vault-0", "-n", "sbos-security",
		"--", "sh", "-c", "VAULT_ADDR=http://127.0.0.1:8200 vault status -format=json 2>/dev/null")
	if err2 != nil {
		return K8sResult{false, "vault-0 Running pero vault status no responde"}
	}
	var m map[string]interface{}
	if err := json.Unmarshal([]byte(status), &m); err != nil {
		return K8sResult{false, "vault-0: respuesta status no es JSON válido"}
	}
	if init, _ := m["initialized"].(bool); !init {
		return K8sResult{false, "Vault no inicializado"}
	}
	if sealed, _ := m["sealed"].(bool); sealed {
		return K8sResult{false, "Vault sellado — ejecutar unseal"}
	}
	ver, _ := m["version"].(string)
	return K8sResult{true, fmt.Sprintf("Vault %s unsealed en sbos-security", ver)}
}

// CheckKeycloak — C-07: pod keycloak Running + Ready condition True.
// Usa la readinessProbe de K8s como fuente de verdad en lugar de curl dentro del pod
// (los contenedores de Keycloak típicamente no incluyen curl).
func CheckKeycloak() K8sResult {
	kc := ResolveKubeconfig()
	// Verificar que al menos un pod esté Running
	out, err := runKubectl(kc, "get", "pods", "-n", "sbos-security",
		"-l", "app=keycloak", "--no-headers", "--request-timeout=10s")
	if err != nil || !strings.Contains(out, "Running") {
		return K8sResult{false, "keycloak: ningún pod Running en sbos-security"}
	}
	// Verificar condición Ready=True del pod (readinessProbe de K8s)
	ready, err2 := runKubectl(kc, "get", "pods", "-n", "sbos-security",
		"-l", "app=keycloak",
		"-o", `jsonpath={.items[0].status.conditions[?(@.type=="Ready")].status}`,
		"--request-timeout=10s")
	if err2 != nil || strings.TrimSpace(ready) != "True" {
		return K8sResult{false, fmt.Sprintf("keycloak: pod Running pero Ready=%s", strings.TrimSpace(ready))}
	}
	return K8sResult{true, "Keycloak Running y Ready en sbos-security"}
}

// CheckKong — C-08: pod kong Running + Ready condition True.
// Usa readinessProbe de K8s como fuente de verdad. Los contenedores Kong
// distroless/minimal típicamente no incluyen curl para exec.
func CheckKong() K8sResult {
	kc := ResolveKubeconfig()
	out, err := runKubectl(kc, "get", "pods", "-n", "sbos-gateway",
		"-l", "app=kong", "--no-headers", "--request-timeout=10s")
	if err != nil || !strings.Contains(out, "Running") {
		return K8sResult{false, "kong: ningún pod Running en sbos-gateway"}
	}
	ready, err2 := runKubectl(kc, "get", "pods", "-n", "sbos-gateway",
		"-l", "app=kong",
		"-o", `jsonpath={.items[0].status.conditions[?(@.type=="Ready")].status}`,
		"--request-timeout=10s")
	if err2 != nil || strings.TrimSpace(ready) != "True" {
		return K8sResult{false, fmt.Sprintf("kong: pod Running pero Ready=%s", strings.TrimSpace(ready))}
	}
	return K8sResult{true, "Kong Running y Ready en sbos-gateway"}
}

// VerifyAllK8s ejecuta los 8 checks C-01..C-08 contra el cluster K8s real.
// Es la fuente de verdad — no depende del state file de BOS.
func VerifyAllK8s() []K8sResult {
	checks := []func() K8sResult{
		CheckOSBootstrap,
		CheckK8sCluster,
		CheckCalico,
		CheckPostgres,
		CheckRedis,
		CheckVault,
		CheckKeycloak,
		CheckKong,
	}
	results := make([]K8sResult, len(checks))
	for i, fn := range checks {
		results[i] = fn()
	}
	return results
}

// runKubectl ejecuta kubectl con KUBECONFIG dado y retorna stdout.
func runKubectl(kubeconfig string, args ...string) (string, error) {
	cmd := exec.Command("kubectl", args...)
	cmd.Env = append(os.Environ(), "KUBECONFIG="+kubeconfig)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("kubectl %s: %s — %w",
			strings.Join(args, " "), strings.TrimSpace(stderr.String()), err)
	}
	return stdout.String(), nil
}
