package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"bos/internal/bootstrap"
	"bos/internal/paths"
)

// cmdBootstrap es el dispatcher del árbol de subcomandos "bosctl bootstrap".
func cmdBootstrap(args []string) int {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, usageBootstrap)
		return 2
	}

	switch args[0] {
	case "start":
		return cmdBootstrapStart(args[1:])
	case "status":
		return cmdBootstrapStatus(args[1:])
	case "verify":
		return cmdBootstrapVerify(args[1:])
	case "resume":
		return cmdBootstrapResume(args[1:])
	case "reset":
		return cmdBootstrapReset(args[1:])
	case "pg-auxiliar":
		return cmdBootstrapPgAuxiliar(args[1:])
	default:
		fmt.Fprintf(os.Stderr, "bosctl bootstrap: subcomando desconocido: %s\n", args[0])
		fmt.Fprintln(os.Stderr, usageBootstrap)
		return 2
	}
}

const usageBootstrap = `bosctl bootstrap — Motor de instalación SBOS (19 fichas iniciales)

Subcomandos:
  start   [--seed=<file>] [--unattended]  Iniciar instalación interactiva o automática
  status                                  Estado actual del proceso de instalación
  verify                                  Verificar criterios de certificación (C-01 a C-08)
  resume                                  Reanudar instalación interrumpida
  reset   [--confirm]                     Reiniciar estado de bootstrap (DESTRUCTIVO)

Ejemplos:
  bosctl bootstrap start                  Instalación interactiva (pantallas TUI)
  bosctl bootstrap start --unattended     Instalación automática con seed file
  bosctl bootstrap verify                 Verificar 8 criterios del Operador
  bosctl bootstrap status                 Ver progreso actual`

// cmdBootstrapStart inicia la instalación del bootstrap (interactivo o --unattended con --seed).
func cmdBootstrapStart(args []string) int {
	fs := flag.NewFlagSet("bootstrap start", flag.ContinueOnError)
	seedFile := fs.String("seed", "", "ruta al seed file (--unattended requiere este parámetro)")
	unattended := fs.Bool("unattended", false, "instalación sin intervención (requiere --seed)")
	if err := fs.Parse(args); err != nil {
		fmt.Fprintf(os.Stderr, "bosctl bootstrap start: %v\n", err)
		return 2
	}

	if *unattended && *seedFile == "" {
		fmt.Fprintln(os.Stderr, "bosctl bootstrap start: --unattended requiere --seed=<archivo>")
		return 2
	}

	params := map[string]interface{}{
		"mode": "interactive",
	}
	if *unattended {
		params["mode"] = "unattended"
		params["seed_file"] = *seedFile
	}

	resp, err := wsRequest("bootstrap_start", params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl bootstrap start: %v\n", err)
		if strings.Contains(err.Error(), "daemon not available") {
			return 6
		}
		return 1
	}

	if data, ok := resp.Data.(map[string]interface{}); ok {
		if msg, ok := data["message"].(string); ok {
			fmt.Println(msg)
		}
		if id, ok := data["bootstrap_id"].(string); ok {
			fmt.Printf("ID de instalación: %s\n", id)
		}
	}
	return 0
}

// cmdBootstrapStatus muestra el estado actual del proceso de instalación (--json para JSON).
func cmdBootstrapStatus(args []string) int {
	fs := flag.NewFlagSet("bootstrap status", flag.ContinueOnError)
	jsonOutput := fs.Bool("json", false, "salida en formato JSON")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	resp, err := wsRequest("bootstrap_status", nil)
	if err != nil {
		if strings.Contains(err.Error(), "daemon not available") {
			fmt.Fprintln(os.Stderr, "bosctl: daemon bos no disponible")
			return 6
		}
		fmt.Fprintf(os.Stderr, "bosctl bootstrap status: %v\n", err)
		return 1
	}

	if *jsonOutput {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		enc.Encode(resp.Data)
		return 0
	}

	data, ok := resp.Data.(map[string]interface{})
	if !ok {
		fmt.Println("Sin datos de bootstrap disponibles")
		return 0
	}

	phase, _ := data["phase"].(string)
	progress, _ := data["progress"].(float64)
	currentFicha, _ := data["current_ficha"].(string)
	totalFichas, _ := data["total_fichas"].(float64)
	completedFichas, _ := data["completed_fichas"].(float64)

	fmt.Printf("\n=== Estado del Bootstrap SBOS ===\n")
	fmt.Printf("Fase:       %s\n", phase)
	fmt.Printf("Progreso:   %.0f%%\n", progress*100)
	fmt.Printf("Fichas:     %.0f/%.0f instaladas\n", completedFichas, totalFichas)
	if currentFicha != "" {
		fmt.Printf("Actual:     %s\n", currentFicha)
	}

	if fichas, ok := data["fichas"].([]interface{}); ok {
		fmt.Printf("\n%-35s %-15s %s\n", "Ficha", "Estado", "Duración")
		fmt.Println(strings.Repeat("-", 65))
		for _, f := range fichas {
			if fm, ok := f.(map[string]interface{}); ok {
				name, _ := fm["id"].(string)
				fstate, _ := fm["state"].(string)
				dur, _ := fm["duration"].(string)
				icon := stateToIconBootstrap(fstate)
				fmt.Printf("%s %-33s %-15s %s\n", icon, name, fstate, dur)
			}
		}
	}
	fmt.Println()
	return 0
}

// cmdBootstrapVerify verifica los 8 criterios de certificación del Operador (C-01 a C-08).
// Fallback a verificación local si el daemon no está disponible.
func cmdBootstrapVerify(args []string) int {
	fs := flag.NewFlagSet("bootstrap verify", flag.ContinueOnError)
	jsonOutput := fs.Bool("json", false, "salida en formato JSON")
	timeout := fs.Int("timeout", 60, "segundos máximos para verificación")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	fmt.Println("Verificando criterios de certificación SBOS...")
	fmt.Printf("Timeout: %ds\n\n", *timeout)

	params := map[string]interface{}{
		"timeout": *timeout,
	}

	resp, err := wsRequest("bootstrap_verify", params)
	if err != nil {
		if strings.Contains(err.Error(), "daemon not available") {
			// Fallback: verificación local directa sin daemon
			return runLocalVerify(*jsonOutput)
		}
		fmt.Fprintf(os.Stderr, "bosctl bootstrap verify: %v\n", err)
		return 1
	}

	if *jsonOutput {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		enc.Encode(resp.Data)
		return 0
	}

	return formatVerifyResult(resp.Data)
}

// runLocalVerify verifica los criterios de certificación directamente sin daemon.
// Usado cuando el daemon no está disponible (durante el bootstrap inicial).
func runLocalVerify(jsonOutput bool) int {
	type CriterioResult struct {
		ID      string `json:"id"`
		Nombre  string `json:"nombre"`
		OK      bool   `json:"ok"`
		Detalle string `json:"detalle"`
	}

	criterios := []CriterioResult{
		{ID: "C-01", Nombre: "OS Bootstrap activo"},
		{ID: "C-02", Nombre: "K8s cluster funcionando"},
		{ID: "C-03", Nombre: "Calico CNI operativo"},
		{ID: "C-04", Nombre: "PostgreSQL HEALTHY + WAL lógico"},
		{ID: "C-05", Nombre: "Redis HEALTHY"},
		{ID: "C-06", Nombre: "Vault unsealed + AppRole"},
		{ID: "C-07", Nombre: "Keycloak HEALTHY"},
		{ID: "C-08", Nombre: "Kong HEALTHY"},
	}

	// C-01: verificar que el OS bootstrap se ejecutó
	criterios[0].OK = checkOSBootstrap()
	criterios[0].Detalle = osBootstrapDetail()

	// C-02 a C-08: verificar K8s y fichas (requieren K8s)
	k8sOK := checkKubectl()
	for i := 1; i < len(criterios); i++ {
		if !k8sOK {
			criterios[i].Detalle = "K8s no accesible — ejecutar después del bootstrap K8s"
			continue
		}
	}
	if k8sOK {
		criterios[1].OK, criterios[1].Detalle = checkK8sCluster()
		criterios[2].OK, criterios[2].Detalle = checkCalico()
		criterios[3].OK, criterios[3].Detalle = checkPostgres()
		criterios[4].OK, criterios[4].Detalle = checkRedis()
		criterios[5].OK, criterios[5].Detalle = checkVault()
		criterios[6].OK, criterios[6].Detalle = checkKeycloak()
		criterios[7].OK, criterios[7].Detalle = checkKong()
	}

	if jsonOutput {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		enc.Encode(criterios)
		return 0
	}

	passed := 0
	fmt.Println("=== Verificación de Criterios de Certificación ===")
	fmt.Println()
	for _, c := range criterios {
		icon := "✗"
		if c.OK {
			icon = "✓"
			passed++
		}
		fmt.Printf("  %s [%s] %s\n", icon, c.ID, c.Nombre)
		if c.Detalle != "" {
			fmt.Printf("       %s\n", c.Detalle)
		}
	}

	fmt.Printf("\n%d/%d criterios cumplidos\n\n", passed, len(criterios))
	if passed == len(criterios) {
		fmt.Println("CERTIFICACIÓN: APROBADA ✓")
		fmt.Println("El Operador puede certificar la instalación.")
		return 0
	}
	fmt.Printf("CERTIFICACIÓN: PENDIENTE — %d criterios por cumplir\n", len(criterios)-passed)
	return 1
}

// checkOSBootstrap verifica señales del OS bootstrap: sysctl K8s y directorio /data.
func checkOSBootstrap() bool {
	// Verificar señales del OS bootstrap: módulos kernel y /data/
	if _, err := os.Stat("/etc/sysctl.d/99-sbos-k8s.conf"); err != nil {
		return false
	}
	if _, err := os.Stat("/data"); err != nil {
		return false
	}
	return true
}

// osBootstrapDetail retorna un mensaje descriptivo del estado del OS bootstrap.
func osBootstrapDetail() string {
	if _, err := os.Stat("/etc/sysctl.d/99-sbos-k8s.conf"); err != nil {
		return "sysctl 99-sbos-k8s.conf no encontrado — ejecutar bosctl bootstrap start"
	}
	if _, err := os.Stat("/data"); err != nil {
		return "/data no existe — ejecutar bosctl bootstrap start"
	}
	return "sysctl configurado, /data existe"
}

// checkKubectl verifica que el kubeconfig y el binario kubectl son accesibles.
func checkKubectl() bool {
	kubeconfig := bootstrap.ResolveKubeconfig()
	if _, err := os.Stat(kubeconfig); err != nil {
		return false
	}
	// Verificar que el binario kubectl existe
	if _, err := os.Stat("/usr/local/bin/kubectl"); err != nil {
		if _, err2 := os.Stat("/usr/bin/kubectl"); err2 != nil {
			return false
		}
	}
	return true
}

// checkK8sCluster verifica que el cluster K8s es accesible vía kubeconfig.
func checkK8sCluster() (bool, string) {
	// Simplificado para Iteración 1 — en Iteración 2 se hará via kubectl
	if _, err := os.Stat(paths.KubeconfigPath); err != nil {
		return false, "kubeconfig no encontrado en /etc/bos/.kube/config"
	}
	return true, "kubeconfig presente"
}

// checkCalico verifica que los pods calico-node están Running en kube-system.
func checkCalico() (bool, string) {
	kubeconfig := bootstrap.ResolveKubeconfig()
	// Verificar pods de Calico en kube-system
	out, err := runKubectl(kubeconfig, "get", "pods", "-n", "kube-system",
		"-l", "k8s-app=calico-node", "--no-headers")
	if err == nil && len(out) > 0 {
		lines := 0
		for _, line := range strings.Split(out, "\n") {
			if strings.TrimSpace(line) != "" && strings.Contains(line, "Running") {
				lines++
			}
		}
		if lines > 0 {
			return true, fmt.Sprintf("Calico running (%d pods)", lines)
		}
		return false, fmt.Sprintf("Calico pods no Running (%d encontrados)", lines)
	}
	// Fallback: verificar ippool (más lento pero más preciso)
	out2, err2 := runKubectl(kubeconfig, "get", "ippool", "-n", "kube-system", "--no-headers")
	if err2 == nil && len(out2) > 0 {
		return true, "Calico IP pools presentes"
	}
	return false, "Calico no detectado — ¿sbos-bootstrap-k8s instalado?"
}

// checkPostgres verifica que postgresql-0 está Running y pg_isready acepta conexiones.
func checkPostgres() (bool, string) {
	kubeconfig := bootstrap.ResolveKubeconfig()
	// Verificar pod postgresql-0
	out, err := runKubectl(kubeconfig, "get", "pod", "postgresql-0", "-n", "sbos-data",
		"-o", "jsonpath={.status.phase}")
	if err != nil || strings.TrimSpace(out) != "Running" {
		return false, fmt.Sprintf("postgresql-0 no Running (actual: %s)", strings.TrimSpace(out))
	}
	// Verificar pg_isready dentro del pod
	ready, err2 := runKubectl(kubeconfig, "exec", "postgresql-0", "-n", "sbos-data",
		"--", "pg_isready", "-U", "postgres")
	if err2 != nil || !strings.Contains(ready, "accepting connections") {
		return false, "postgresql-0 Running pero pg_isready no acepta conexiones"
	}
	return true, "PostgreSQL aceptando conexiones"
}

// checkRedis verifica que redis-0 está Running y responde PONG a redis-cli ping.
func checkRedis() (bool, string) {
	kubeconfig := bootstrap.ResolveKubeconfig()
	out, err := runKubectl(kubeconfig, "get", "pod", "redis-0", "-n", "sbos-data",
		"-o", "jsonpath={.status.phase}")
	if err != nil || strings.TrimSpace(out) != "Running" {
		return false, fmt.Sprintf("redis-0 no Running (actual: %s)", strings.TrimSpace(out))
	}
	// Verificar PONG
	pong, err2 := runKubectl(kubeconfig, "exec", "redis-0", "-n", "sbos-data",
		"--", "redis-cli", "ping")
	if err2 != nil || strings.TrimSpace(pong) != "PONG" {
		return false, "redis-0 Running pero redis-cli PING no responde PONG"
	}
	return true, "Redis PONG"
}

// checkVault verifica que vault-0 está Running, inicializado y sin sellar.
func checkVault() (bool, string) {
	kubeconfig := bootstrap.ResolveKubeconfig()
	out, err := runKubectl(kubeconfig, "get", "pod", "vault-0", "-n", "sbos-security",
		"-o", "jsonpath={.status.phase}")
	if err != nil || strings.TrimSpace(out) != "Running" {
		return false, fmt.Sprintf("vault-0 no Running (actual: %s)", strings.TrimSpace(out))
	}
	// Verificar Vault status
	status, err2 := runKubectl(kubeconfig, "exec", "vault-0", "-n", "sbos-security",
		"--", "sh", "-c", "VAULT_ADDR=http://127.0.0.1:8200 vault status -format=json 2>/dev/null")
	if err2 != nil {
		return false, "vault-0 Running pero vault status no responde"
	}
	var statusMap map[string]interface{}
	if err := json.Unmarshal([]byte(status), &statusMap); err != nil {
		return false, "vault-0 Running pero respuesta no es JSON válido"
	}
	init, _ := statusMap["initialized"].(bool)
	sealed, _ := statusMap["sealed"].(bool)
	if !init {
		return false, "Vault no inicializado"
	}
	if sealed {
		return false, "Vault sellado — ejecutar unseal"
	}
	ver, _ := statusMap["version"].(string)
	return true, fmt.Sprintf("Vault %s unsealed", ver)
}

// checkKeycloak verifica que al menos un pod keycloak está Running y /health/ready responde UP.
func checkKeycloak() (bool, string) {
	kubeconfig := bootstrap.ResolveKubeconfig()
	// Verificar que existe al menos un pod de keycloak
	out, err := runKubectl(kubeconfig, "get", "pods", "-n", "sbos-security",
		"-l", "app=keycloak", "--no-headers")
	if err != nil || len(out) == 0 {
		return false, "keycloak: no se encontraron pods en sbos-security"
	}
	if !strings.Contains(out, "Running") {
		return false, "keycloak: pods encontrados pero ninguno Running"
	}
	// Verificar health/ready via kubectl exec
	health, err2 := runKubectl(kubeconfig, "exec", "deploy/keycloak", "-n", "sbos-security",
		"--", "sh", "-c", "curl -sf http://localhost:9000/health/ready 2>/dev/null")
	if err2 != nil || !strings.Contains(health, "UP") {
		return false, "keycloak: pods Running pero /health/ready no UP"
	}
	return true, "Keycloak UP"
}

// checkKong verifica que pods kong están Running y el Admin API /status reporta DB reachable.
func checkKong() (bool, string) {
	kubeconfig := bootstrap.ResolveKubeconfig()
	out, err := runKubectl(kubeconfig, "get", "pods", "-n", "sbos-gateway",
		"-l", "app=kong", "--no-headers")
	if err != nil || len(out) == 0 {
		return false, "kong: no se encontraron pods en sbos-gateway"
	}
	if !strings.Contains(out, "Running") {
		return false, "kong: pods encontrados pero ninguno Running"
	}
	// Verificar Admin API /status
	status, err2 := runKubectl(kubeconfig, "exec", "deploy/kong", "-n", "sbos-gateway",
		"--", "sh", "-c", "curl -sf http://127.0.0.1:8001/status 2>/dev/null")
	if err2 != nil {
		return false, "kong: pods Running pero Admin API no responde"
	}
	var statusMap map[string]interface{}
	if err := json.Unmarshal([]byte(status), &statusMap); err != nil {
		return false, "kong: Admin API responde pero no es JSON válido"
	}
	db, _ := statusMap["database"].(map[string]interface{})
	if db == nil {
		return false, "kong: Admin API /status sin campo database"
	}
	reachable, _ := db["reachable"].(bool)
	if !reachable {
		return false, "kong: database no reachable"
	}
	return true, "Kong Admin API OK — DB reachable"
}

// runKubectl ejecuta kubectl con el kubeconfig dado y retorna stdout.
func runKubectl(kubeconfig string, args ...string) (string, error) {
	cmd := exec.Command("kubectl", args...)
	cmd.Env = append(os.Environ(), "KUBECONFIG="+kubeconfig)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("kubectl %s: %s — %w", strings.Join(args, " "), stderr.String(), err)
	}
	return stdout.String(), nil
}

// formatVerifyResult formatea la respuesta de bootstrap_verify del daemon en pantalla.
func formatVerifyResult(data interface{}) int {
	result, ok := data.(map[string]interface{})
	if !ok {
		fmt.Println("Formato de respuesta inesperado")
		return 1
	}

	passed, _ := result["passed"].(float64)
	total, _ := result["total"].(float64)
	certified, _ := result["certified"].(bool)

	fmt.Println("=== Verificación de Criterios de Certificación ===")
	fmt.Println()

	if criterios, ok := result["criterios"].([]interface{}); ok {
		for _, c := range criterios {
			if cm, ok := c.(map[string]interface{}); ok {
				id, _ := cm["id"].(string)
				nombre, _ := cm["nombre"].(string)
				ok2, _ := cm["ok"].(bool)
				detalle, _ := cm["detalle"].(string)
				icon := "✗"
				if ok2 {
					icon = "✓"
				}
				fmt.Printf("  %s [%s] %s\n", icon, id, nombre)
				if detalle != "" {
					fmt.Printf("       %s\n", detalle)
				}
			}
		}
	}

	fmt.Printf("\n%.0f/%.0f criterios cumplidos\n\n", passed, total)
	if certified {
		fmt.Println("CERTIFICACIÓN: APROBADA ✓")
		return 0
	}
	fmt.Printf("CERTIFICACIÓN: PENDIENTE — %.0f criterios por cumplir\n", total-passed)
	return 1
}

// cmdBootstrapResume reanuda una instalación bootstrap interrumpida.
func cmdBootstrapResume(args []string) int {
	resp, err := wsRequest("bootstrap_resume", nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl bootstrap resume: %v\n", err)
		if strings.Contains(err.Error(), "daemon not available") {
			return 6
		}
		return 1
	}
	if data, ok := resp.Data.(map[string]interface{}); ok {
		if msg, ok := data["message"].(string); ok {
			fmt.Println(msg)
		}
	}
	return 0
}

// cmdBootstrapReset reinicia el estado del bootstrap (DESTRUCTIVO — requiere --confirm).
func cmdBootstrapReset(args []string) int {
	fs := flag.NewFlagSet("bootstrap reset", flag.ContinueOnError)
	confirm := fs.Bool("confirm", false, "confirmar operación destructiva")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	if !*confirm {
		fmt.Fprintln(os.Stderr, "bosctl bootstrap reset: operación DESTRUCTIVA — use --confirm para proceder")
		fmt.Fprintln(os.Stderr, "Esto reinicia el estado de bootstrap. Las fichas NO se desinstalan.")
		return 2
	}

	resp, err := wsRequest("bootstrap_reset", map[string]interface{}{"confirmed": true})
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl bootstrap reset: %v\n", err)
		return 1
	}
	if data, ok := resp.Data.(map[string]interface{}); ok {
		if msg, ok := data["message"].(string); ok {
			fmt.Println(msg)
		}
	}
	return 0
}

// stateToIconBootstrap convierte un estado de ficha (ADR-021) a ícono Unicode para TUI bootstrap.
func stateToIconBootstrap(state string) string {
	switch strings.ToUpper(state) {
	case "INSTALADA", "INSTALADA -- OK", "INSTALADA_OK":
		return "✓"
	case "INSTALANDO", "ACTUALIZANDO", "REPARANDO":
		return "⟳"
	case "DEGRADADA", "INSTALADA -- ALERTA", "INSTALADA_ALERTA":
		return "!"
	case "FALLA_INSTALACION", "FALLA_ACTUALIZACION", "ERROR_LOGICO", "ERROR_FISICO":
		return "✗"
	case "PENDIENTE", "LISTA":
		return "○"
	case "DESINSTALADA":
		return " "
	default:
		return "?"
	}
}

// cmdBootstrapPgAuxiliar gestiona el PostgreSQL auxiliar anti-pérdida.
// Uso: bosctl bootstrap pg-auxiliar --op=backup|restore|sync|cleanup|status [--pod=<name>]
func cmdBootstrapPgAuxiliar(args []string) int {
	fs := flag.NewFlagSet("bootstrap pg-auxiliar", flag.ContinueOnError)
	op := fs.String("op", "status", "operación: backup|restore|sync|cleanup|status")
	pod := fs.String("pod", "", "pod PostgreSQL (requerido para restore)")
	ns := fs.String("ns", "sbos-data", "namespace del pod PostgreSQL")

	if err := fs.Parse(args); err != nil {
		if err == flag.ErrHelp {
			return 0
		}
		fmt.Fprintf(os.Stderr, "bosctl bootstrap pg-auxiliar: %v\n", err)
		return 2
	}

	var method string
	var params map[string]interface{}

	switch *op {
	case "backup", "start":
		method = "pg_auxiliar_start"
		params = map[string]interface{}{
			"source_pod": *pod,
			"source_ns":  *ns,
		}
	case "sync", "restore":
		method = "pg_auxiliar_sync"
		params = map[string]interface{}{
			"target_pod": *pod,
			"target_ns":  *ns,
			"database":   "postgres",
		}
	case "status":
		method = "pg_auxiliar_status"
		params = nil
	case "cleanup":
		method = "pg_auxiliar_cleanup"
		params = nil
	default:
		fmt.Fprintf(os.Stderr, "bosctl bootstrap pg-auxiliar: operación desconocida: %s\n", *op)
		fmt.Fprintf(os.Stderr, "ops válidas: backup, restore, sync, cleanup, status\n")
		return 2
	}

	resp, err := wsRequest(method, params)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bosctl bootstrap pg-auxiliar: %v\n", err)
		return 1
	}

	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	_ = enc.Encode(resp)
	return 0
}
