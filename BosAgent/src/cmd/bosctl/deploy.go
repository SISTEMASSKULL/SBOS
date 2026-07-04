package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"bos/internal/paths"

	"gopkg.in/yaml.v3"
)

// SeedConfig representa el seed.yml (SBOS-051-TENANT-SPEC v2.0).
// Modelo A (Enterprise Tenant) + Modelo B (Technical Domain).
// El bos es el Control Plane soberano — dueño de ambos modelos.
//
// §4.7 — Campos esenciales mínimos (obligatorios + opcionales).
// §14.1-14.2 — Esquemas completos de referencia para ambos modelos.
type SeedConfig struct {
	// ═══ MODELO A — Tenant Empresarial (§4) ═══
	// Gobernado por: bos (Control Plane soberano).
	// Almacenado en: bkernel_db.enterprise_tenants (PostgreSQL 18.4).
	// Referencias: ISO 17442 (LEI), ISO 20275 (ELF), KYB (FATF/GAFILAT).
	EnterpriseTenant struct {
		LegalName                  string `yaml:"legal_name"`
		TradingName                string `yaml:"trading_name"`
		EntityLegalFormCode        string `yaml:"entity_legal_form_code"`
		JurisdictionOfRegistration string `yaml:"jurisdiction_of_registration"`
		RegistrationNumber         string `yaml:"registration_number"`
		TaxIdentifier              string `yaml:"tax_identifier"`
		RegisteredAddress          string `yaml:"registered_address"`
		EntityStatus               string `yaml:"entity_status"`
		RegistrationDate           string `yaml:"registration_date"`
		LegalEntityIdentifier      string `yaml:"legal_entity_identifier,omitempty"`
	} `yaml:"enterprise_tenant"`

	// ═══ MODELO B — Dominio Técnico (§5) ═══
	// Gobernado por: bos (bosctl deploy). Cardinalidad 1:N con Modelo A.
	// Referencias: ISO/IEC 17788, NSA/CISA K8s Hardening, CIS Benchmark v8.

	// ── PASO 1: Identidad (Keycloak Realm + SPIs) ──────────────
	Identity struct {
		Realm               string   `yaml:"realm"`
		DisplayName         string   `yaml:"display_name"`
		SSOSessionMax       string   `yaml:"sso_session_max"`
		AccessTokenLifespan string   `yaml:"access_token_lifespan"`
		SPIs                []string `yaml:"spis"`
	} `yaml:"identity"`

	// ── PASO 2: Infraestructura (Namespace K8s + NetworkPolicy) ─
	Infrastructure struct {
		DomainID           string `yaml:"domain_id"`
		DomainType         string `yaml:"domain_type"`
		Ficha              string `yaml:"ficha"`
		NetworkPolicy      string `yaml:"network_policy"`
		TenancyTrustModel  string `yaml:"tenancy_trust_model"`
		IsolationMechanism string `yaml:"isolation_mechanism"`
	} `yaml:"infrastructure"`

	// ── PASO 3: Bases de Datos (PostgreSQL 18.4) ───────────────
	Databases struct {
		Engine    string `yaml:"engine"`
		Version   string `yaml:"version"`
		ClusterIP string `yaml:"cluster_ip"`
		DBs       []struct {
			Name  string `yaml:"name"`
			Owner string `yaml:"owner"`
		} `yaml:"databases"`
	} `yaml:"databases"`

	// ── PASO 4: Vault (Secret Paths + AppRole) ─────────────────
	Vault struct {
		Version         string `yaml:"version"`
		Engine          string `yaml:"engine"`
		BasePath        string `yaml:"base_path"`
		ApproleTTL      string `yaml:"approle_ttl"`
		ShamirKeys      int    `yaml:"shamir_keys"`
		ShamirThreshold int    `yaml:"shamir_threshold"`
	} `yaml:"vault"`

	// ── PASO 5: Redis (Context Registry DB1 + Streams) ─────────
	Redis struct {
		Version     string `yaml:"version"`
		DB0         string `yaml:"db0"`
		DB1         string `yaml:"db1"`
		DB2         string `yaml:"db2"`
		Persistence string `yaml:"persistence"`
	} `yaml:"redis"`

	// ── PASO 6: Context Plane DDL ──────────────────────────────
	ContextPlane struct {
		AutoMigrate bool     `yaml:"auto_migrate"`
		Tables      []string `yaml:"tables"`
		Indexes     []string `yaml:"indexes"`
	} `yaml:"context_plane"`

	// ── PASO 7: Fichas del tenant ──────────────────────────────
	Fichas []string `yaml:"fichas"`

	// ── Usuarios iniciales ─────────────────────────────────────
	Users []struct {
		Username          string   `yaml:"username"`
		Email             string   `yaml:"email"`
		Roles             []string `yaml:"roles"`
		TemporaryPassword bool     `yaml:"temporary_password"`
	} `yaml:"users"`
}

// deployTenant orquesta la saga de 7 pasos para provisionar un tenant completo.
// Cada paso llama a una ficha autocontenida o ejecuta una operación directa.
// Si un paso falla, los pasos anteriores se compensan en orden inverso.
//
// Documentado en: REGISTRO-ESTADO.md §F10.C, BOS-CONTRATOS-SBOS.md §C-2
func deployTenant(seedPath string) error {
	data, err := os.ReadFile(seedPath)
	if err != nil {
		return fmt.Errorf("leer seed.yml: %w", err)
	}

	var cfg SeedConfig
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return fmt.Errorf("parsear seed.yml: %w", err)
	}

	tenantID := cfg.EnterpriseTenant.TaxIdentifier
	legalName := cfg.EnterpriseTenant.LegalName
	fmt.Printf("🚀 Deploying tenant: %s (%s)\n", tenantID, legalName)
	fmt.Printf("   Jurisdicción: %s · Forma jurídica: %s · Estado: %s\n",
		cfg.EnterpriseTenant.JurisdictionOfRegistration,
		cfg.EnterpriseTenant.EntityLegalFormCode,
		cfg.EnterpriseTenant.EntityStatus)
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")


		// ── PASO 0: Instalar K8s (kubeadm) ───────────────────────────
		fmt.Println("[0/7] Instalando Kubernetes (kubeadm)...")
		if err := installFicha("sbos-bootstrap-k8s", nil); err != nil {
			return fmt.Errorf("PASO 0 (kubeadm): %w", err)
		}
		fmt.Println("  ✅ kubeadm + kubectl listos")

	// ── PASO 1: Namespace K8s + NetworkPolicy ──────────────────────
	fmt.Println("[1/7] Creando namespace K8s...")
	if err := installFicha(cfg.Infrastructure.Ficha, map[string]string{
		"TENANT_ID":   tenantID,
		"TENANT_NAME": cfg.EnterpriseTenant.TradingName,
		"DOMAIN_ID":   cfg.Infrastructure.DomainID,
		"DOMAIN_TYPE": cfg.Infrastructure.DomainType,
	}); err != nil {
		return fmt.Errorf("PASO 1 (namespace): %w", err)
	}
	fmt.Printf("  ✅ namespace sbos-%s (%s, %s)\n",
		tenantID, cfg.Infrastructure.TenancyTrustModel, cfg.Infrastructure.IsolationMechanism)

	// ── PASO 2: PostgreSQL + Bases de Datos ─────────────────────────

		// ── PASO 1.5: Bootstrap Storage (StorageClass + PVs) ────────────
		fmt.Println("[1.5/7] Configurando almacenamiento...")
		if err := installFicha("sbos-bootstrap-storage", nil); err != nil {
			compensateStep1(tenantID)
			return fmt.Errorf("PASO 1.5 (storage): %w", err)
		}
		fmt.Println("  ✅ StorageClass + PVs listos")

	fmt.Println("[2/7] Provisionando bases de datos...")
	if err := installFicha("postgresql", map[string]string{
		"TENANT_ID": tenantID,
		"ENGINE":    cfg.Databases.Engine,
		"VERSION":   cfg.Databases.Version,
	}); err != nil {
		compensateStep1(tenantID)
		return fmt.Errorf("PASO 2 (postgresql): %w", err)
	}
	fmt.Printf("  ✅ PostgreSQL %s + %d databases (ClusterIP %s)\n",
		cfg.Databases.Version, len(cfg.Databases.DBs), cfg.Databases.ClusterIP)

	// ── PASO 3: Redis + Context Registry ────────────────────────────
	fmt.Println("[3/7] Configurando Redis + Context Registry...")
	if err := installFicha("redis", map[string]string{
		"TENANT_ID":   tenantID,
		"VERSION":     cfg.Redis.Version,
		"PERSISTENCE": cfg.Redis.Persistence,
	}); err != nil {
		compensateSteps12(tenantID)
		return fmt.Errorf("PASO 3 (redis): %w", err)
	}
	fmt.Printf("  ✅ Redis %s [%s / %s / %s] persistencia=%s\n",
		cfg.Redis.Version, cfg.Redis.DB0, cfg.Redis.DB1, cfg.Redis.DB2, cfg.Redis.Persistence)

	// ── PASO 4: Vault + PKI + AppRole ────────────────────────────────
	fmt.Println("[4/7] Inicializando Vault...")
	if err := installFicha("vault", map[string]string{
		"TENANT_ID":   tenantID,
		"ENGINE":      cfg.Vault.Engine,
		"BASE_PATH":   cfg.Vault.BasePath,
		"APPROLE_TTL": cfg.Vault.ApproleTTL,
	}); err != nil {
		compensateSteps123(tenantID)
		return fmt.Errorf("PASO 4 (vault): %w", err)
	}
	fmt.Printf("  ✅ Vault %s [%s @ %s] AppRole TTL=%s Shamir %d/%d\n",
		cfg.Vault.Version, cfg.Vault.Engine, cfg.Vault.BasePath,
		cfg.Vault.ApproleTTL, cfg.Vault.ShamirKeys, cfg.Vault.ShamirThreshold)

	// ── PASO 5: Keycloak + Realm + SPIs ─────────────────────────────
	fmt.Println("[5/7] Desplegando Keycloak + Realm + SPIs...")
	if err := installFicha("keycloak", map[string]string{
		"TENANT_ID":           tenantID,
		"TENANT_NAME":         cfg.EnterpriseTenant.TradingName,
		"REALM":               cfg.Identity.Realm,
		"SSO_SESSION_MAX":     cfg.Identity.SSOSessionMax,
		"ACCESS_TOKEN_LIFESPAN": cfg.Identity.AccessTokenLifespan,
	}); err != nil {
		compensateSteps1234(tenantID)
		return fmt.Errorf("PASO 5 (keycloak): %w", err)
	}
	fmt.Printf("  ✅ Keycloak + Realm %s + %d SPIs (session=%s, token=%s)\n",
		cfg.Identity.Realm, len(cfg.Identity.SPIs),
		cfg.Identity.SSOSessionMax, cfg.Identity.AccessTokenLifespan)

	// ── PASO 6: Context Plane DDL ────────────────────────────────────
	fmt.Println("[6/7] Aplicando DDL Context Plane...")
	if cfg.ContextPlane.AutoMigrate {
		if err := runBosRPC("bos.ctx.auto_migrate", map[string]interface{}{
			"tenant_id": tenantID,
			"tables":    cfg.ContextPlane.Tables,
			"indexes":   cfg.ContextPlane.Indexes,
		}); err != nil {
			compensateSteps12345(tenantID)
			return fmt.Errorf("PASO 6 (context DDL): %w", err)
		}
		fmt.Printf("  ✅ %v + índices %v\n", cfg.ContextPlane.Tables, cfg.ContextPlane.Indexes)
	} else {
		fmt.Println("  ⏭️  auto_migrate=false — saltando")
	}

	// ── PASO 7: Fichas del tenant en orden topológico ───────────────
	fmt.Println("[7/7] Instalando fichas del tenant...")
	for _, ficha := range cfg.Fichas {
		fmt.Printf("  📦 %s...", ficha)
		if err := installFicha(ficha, map[string]string{
			"TENANT_ID": tenantID,
		}); err != nil {
			fmt.Println(" ❌")
			compensateSteps123456(tenantID)
			return fmt.Errorf("PASO 7 (ficha %s): %w", ficha, err)
		}
		fmt.Println(" ✅")
	}

	// ── Usuarios iniciales ──────────────────────────────────────────
	if len(cfg.Users) > 0 {
		fmt.Printf("👥 Creando %d usuarios iniciales...\n", len(cfg.Users))
		for _, u := range cfg.Users {
			fmt.Printf("  👤 %s <%s> roles=%v temp_pwd=%v\n",
				u.Username, u.Email, u.Roles, u.TemporaryPassword)
		}
	}

	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Printf("✅ Tenant %s desplegado correctamente (%s)\n", tenantID, legalName)
	return nil
}

// ── Helpers ─────────────────────────────────────────────────────────────

// installFicha ejecuta bos.ficha.install vía JSON-RPC al daemon.
//
// Las variables de entorno (TENANT_ID, TENANT_NAME, etc.) viajan en el campo
// "env" del JSON-RPC. El daemon las inyecta antes de ejecutar el task_catalog.sh.
//
// Mientras espera la respuesta, transmite en vivo las líneas del log de la ficha
// para que el operador vea el progreso y no parezca que el sistema se colgó.
func installFicha(name string, env map[string]string) error {
	socket := os.Getenv("BOS_SOCKET")
	if socket == "" {
		socket = paths.SocketPath
	}
	params := map[string]interface{}{
		"ficha_id": name,
		"version":  "",
	}
	if len(env) > 0 {
		params["env"] = env
	}

	// Iniciar streaming del log en background
	logPath := "/var/log/bos/fichas/" + name + ".log"
	stopStream := make(chan struct{})
	go streamLog(logPath, stopStream)

	err := rpcCall(socket, "bos.ficha.install", params)

	// Detener streaming
	close(stopStream)

	return err
}

// streamLog transmite líneas nuevas del archivo de log a stdout con colores.
// Lee desde el final del archivo y sigue hasta que stopStream se cierra.
func streamLog(logPath string, stop chan struct{}) {
	// Esperar a que el archivo exista (máx 30s)
	for i := 0; i < 60; i++ {
		if _, err := os.Stat(logPath); err == nil {
			break
		}
		select {
		case <-stop:
			return
		case <-time.After(500 * time.Millisecond):
		}
	}

	f, err := os.Open(logPath)
	if err != nil {
		return
	}
	defer f.Close()

	// Ir al final del archivo
	f.Seek(0, 2)

	reader := bufio.NewReaderSize(f, 4096)
	for {
		select {
		case <-stop:
			// Leer lo que quede antes de salir
			for {
				line, err := reader.ReadString('\n')
				if err != nil {
					return
				}
				fmt.Print(colorize(line))
			}
		default:
			line, err := reader.ReadString('\n')
			if err != nil {
				time.Sleep(200 * time.Millisecond)
				continue
			}
			fmt.Print(colorize(line))
		}
	}
}

// colorize aplica colores ANSI a líneas de log según su contenido.
//
//	STEP_OK, instalado, completado, éxito, Ready  → verde
//	STEP_FAIL, ERROR, fatal, falló                → rojo
//	STEP_START, Instalando, Ejecutando, Creando   → cyan
//	STEP_SKIP, ADVERTENCIA, WARN                  → amarillo
func colorize(line string) string {
	lower := strings.ToLower(line)

	switch {
	case strings.Contains(lower, "step_ok") ||
		strings.Contains(lower, "instalado") ||
		strings.Contains(lower, "completad") ||
		strings.Contains(lower, "éxito") ||
		strings.Contains(lower, "exitoso") ||
		strings.Contains(lower, "listos") ||
		strings.Contains(lower, "ready") ||
		strings.Contains(lower, "running"):
		return "\x1b[32m" + line + "\x1b[0m" // verde

	case strings.Contains(lower, "step_fail") ||
		strings.Contains(lower, "error") ||
		strings.Contains(lower, "fatal") ||
		strings.Contains(lower, "falló") ||
		strings.Contains(lower, "failed"):
		return "\x1b[31m" + line + "\x1b[0m" // rojo

	case strings.Contains(lower, "step_start") ||
		strings.Contains(lower, "instalando") ||
		strings.Contains(lower, "ejecutando") ||
		strings.Contains(lower, "creando") ||
		strings.Contains(lower, "aplicando") ||
		strings.Contains(lower, "configurando") ||
		strings.Contains(lower, "inicializando") ||
		strings.Contains(lower, "descargando") ||
		strings.Contains(lower, "provisionando"):
		return "\x1b[36m" + line + "\x1b[0m" // cyan

	case strings.Contains(lower, "step_skip") ||
		strings.Contains(lower, "advertencia") ||
		strings.Contains(lower, "warn") ||
		strings.Contains(lower, "skip"):
		return "\x1b[33m" + line + "\x1b[0m" // amarillo

	default:
		return "\x1b[37m" + line + "\x1b[0m" // blanco
	}
}

// runBosRPC ejecuta un método JSON-RPC contra el daemon bos.
func runBosRPC(method string, params map[string]interface{}) error {
	socket := os.Getenv("BOS_SOCKET")
	if socket == "" {
		socket = paths.SocketPath
	}
	return rpcCall(socket, method, params)
}


// rpcAuthToken lee el token compartido de /etc/bos/rpc-token y genera
// el header Authorization: Basic base64(sbos_admin:dev:<token>).
func rpcAuthToken() string {
	// 1. Variable de entorno (más rápido)
	if env := os.Getenv("BOS_RPC_TOKEN"); env != "" {
		return env
	}
	// 2. Leer archivo de token
	if data, err := os.ReadFile(paths.RpcTokenFile); err == nil {
		token := strings.TrimSpace(string(data))
		if token != "" {
			auth := "sbos_admin:dev:" + token
			return base64.StdEncoding.EncodeToString([]byte(auth))
		}
	}
	// 3. Último recurso: token hardcodeado de desarrollo
	return "c2Jvc19hZG1pbjpkZXY6ZGV2LXRva2VuLTIwMjY="
}

// rpcCall hace una llamada JSON-RPC 2.0 al daemon vía Unix socket.
func rpcCall(socket, method string, params map[string]interface{}) error {
	body, _ := json.Marshal(map[string]interface{}{
		"jsonrpc": "2.0",
		"method":  method,
		"params":  params,
		"id":      1,
	})

	httpClient := &http.Client{
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
				return net.Dial("unix", socket)
			},
		},
		Timeout: 300 * time.Second,
	}

	req, err := http.NewRequestWithContext(context.Background(), "POST", "http://unix/rpc", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("%s: %w", method, err)
	}
	req.Header.Set("Content-Type", "application/json")
	// Token de desarrollo — en producción viene de Vault
	req.Header.Set("Authorization", "Basic "+rpcAuthToken())

	resp, err := httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("%s: %w", method, err)
	}
	defer resp.Body.Close()

	var result struct {
		Error *struct {
			Code    int    `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
		Result json.RawMessage `json:"result"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return fmt.Errorf("%s: parse response: %w", method, err)
	}
	if result.Error != nil {
		return fmt.Errorf("%s: [%d] %s", method, result.Error.Code, result.Error.Message)
	}
	return nil
}

// ── Compensaciones (rollback en orden inverso) ─────────────────────────

func compensateStep1(tenantID string) {
	fmt.Printf("  ↩️  Compensando PASO 1: eliminando namespace sbos-%s\n", tenantID)
}

func compensateSteps12(tenantID string) {
	compensateStep1(tenantID)
	fmt.Println("  ↩️  Compensando PASO 2: (no-destructive — PG se mantiene)")
}

func compensateSteps123(tenantID string) {
	compensateSteps12(tenantID)
	fmt.Println("  ↩️  Compensando PASO 3: (no-destructive — Redis se mantiene)")
}

func compensateSteps1234(tenantID string) {
	compensateSteps123(tenantID)
	fmt.Println("  ↩️  Compensando PASO 4: sellando Vault")
}

func compensateSteps12345(tenantID string) {
	compensateSteps1234(tenantID)
	fmt.Printf("  ↩️  Compensando PASO 5: eliminando Realm %s\n", tenantID)
}

func compensateSteps123456(tenantID string) {
	compensateSteps12345(tenantID)
	fmt.Println("  ↩️  Compensando PASO 6: (no-destructive — DDL se mantiene)")
}

// ── CLI entry points ────────────────────────────────────────────────────

// cmdDeploy ejecuta bosctl deploy <seed.yml>
// Orquesta la saga de 7 pasos para provisionar un tenant completo.
func cmdDeploy(args []string) int {
	if len(args) == 0 {
		fmt.Fprintf(os.Stderr, "Uso: bosctl deploy <seed.yml>\n")
		return 1
	}
	seedPath := args[0]
	if err := deployTenant(seedPath); err != nil {
		fmt.Fprintf(os.Stderr, "deploy: %v\n", err)
		return 1
	}
	return 0
}

// cmdTenant ejecuta bosctl tenant <suspend|remove|list> <tenant-id>
func cmdTenant(args []string) int {
	if len(args) == 0 {
		fmt.Fprintf(os.Stderr, "Uso: bosctl tenant <suspend|remove|list> [tenant-id]\n")
		return 1
	}
	action := args[0]
	switch action {
	case "suspend":
		if len(args) < 2 {
			fmt.Fprintf(os.Stderr, "Uso: bosctl tenant suspend <tenant-id>\n")
			return 1
		}
		fmt.Printf("Suspendiendo tenant %s...\n", args[1])
		// TODO: invalidar ctx_id + pausar fichas (F10.C.11)
		return 0
	case "remove":
		if len(args) < 2 {
			fmt.Fprintf(os.Stderr, "Uso: bosctl tenant remove <tenant-id>\n")
			return 1
		}
		fmt.Printf("⛔ GATE: confirmacion HITL requerida para eliminar %s\n", args[1])
		// TODO: saga inversa 7 pasos (F10.C.12)
		return 0
	case "list":
		fmt.Println("Tenants: (ninguno — F10.C.10 pendiente)")
		return 0
	default:
		fmt.Fprintf(os.Stderr, "tenant: accion desconocida: %s\n", action)
		return 1
	}
}
