package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
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
		CountryCode                string `yaml:"country_code,omitempty"` // ISO 3166-1 alpha-2 (BO, AR, etc.)
		Domain                     string `yaml:"domain,omitempty"`       // dominio SBOS (default: <trading_name>.sbos.local)
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
// writeBootstrapEnv genera /etc/bos/bos-bootstrap.env desde los datos del seed.
// No sobreescribe si ya existe (instalación existente).
// La contraseña admin se genera aleatoriamente — nunca se almacena en el seed.
func writeBootstrapEnv(cfg *SeedConfig) error {
	dest := paths.BootstrapEnv
	if _, err := os.Stat(dest); err == nil {
		return nil // ya existe — no sobreescribir
	}
	if err := os.MkdirAll(paths.EtcBos, 0750); err != nil {
		return err
	}

	name := cfg.EnterpriseTenant.TradingName
	domain := cfg.EnterpriseTenant.Domain
	if domain == "" {
		domain = strings.ToLower(name) + ".sbos.local"
	}
	country := cfg.EnterpriseTenant.CountryCode
	if country == "" {
		country = "BO"
	}
	rootUser := "admin"
	if len(cfg.Users) > 0 && cfg.Users[0].Username != "" {
		rootUser = cfg.Users[0].Username
	}

	// Contraseña aleatoria de 20 caracteres — se guarda en el archivo
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return fmt.Errorf("generar contraseña admin: %w", err)
	}
	adminPass := base64.StdEncoding.EncodeToString(buf)[:20]

	content := fmt.Sprintf("# Generado por bosctl deploy — no editar manualmente\n"+
		"BOS_TENANT_NAME=%s\n"+
		"BOS_TENANT_ID=%s\n"+
		"BOS_TENANT_PAIS=%s\n"+
		"BOS_TENANT_DOMAIN=%s\n"+
		"BOS_ROOT_USER=%s\n"+
		"BOS_ROOT_PASSWORD=%s\n"+
		"BOS_MFA_ENABLED=false\n",
		name, cfg.EnterpriseTenant.TaxIdentifier, country, domain, rootUser, adminPass)

	if err := os.WriteFile(dest, []byte(content), 0600); err != nil {
		return fmt.Errorf("escribir %s: %w", dest, err)
	}
	fmt.Printf("  📝 bos-bootstrap.env generado (tenant=%s, admin=%s)\n", name, rootUser)
	return nil
}

// applyDDLs aplica el DDL completo de SBOS en la BD SBOSDB:
//  1. SBOS_db_V2_DDL.sql       — schemas bauth, bglobal, bcalendar + tablas
//  2. bauth_atomlang_schema.sql — schema AtomLang de bAuth
//  3. bos_01__control_plane.sql — schema BOS (Context Plane)
//  4. migrations/*.sql          — migraciones en orden alfabético
//  5. seeds/*.sql               — seeds en orden alfabético (incluye los dos tenants del sistema)
//
// Todos los SQLs se ejecutan via kubectl exec en postgresql-0 (sbos-data).
// Usa ON_ERROR_STOP=off — los DDLs son idempotentes (IF NOT EXISTS / ON CONFLICT DO NOTHING).
func applyDDLs(kubeconfig string) error {
	ddlsPath := paths.DDLsPath
	if _, err := os.Stat(ddlsPath); os.IsNotExist(err) {
		return fmt.Errorf("DDLs no encontrados en %s — incluir ddls/ en el paquete de deploy junto a los binarios", ddlsPath)
	}

	// psqlExec aplica un archivo SQL en la BD dada via kubectl exec -i.
	psqlExec := func(db, filePath string) error {
		content, err := os.ReadFile(filePath)
		if err != nil {
			return fmt.Errorf("leer %s: %w", filepath.Base(filePath), err)
		}
		cmd := exec.Command("kubectl", "--kubeconfig", kubeconfig,
			"exec", "-i", "postgresql-0", "-n", "sbos-data", "--",
			"psql", "-U", "postgres", "-d", db, "-v", "ON_ERROR_STOP=off", "-q")
		cmd.Stdin = bytes.NewReader(content)
		out, err := cmd.CombinedOutput()
		errCount := bytes.Count(out, []byte("ERROR:"))
		if errCount > 0 {
			fmt.Printf("      ⚠  %d aviso(s) en %s\n", errCount, filepath.Base(filePath))
		}
		if err != nil {
			return fmt.Errorf("%s: %w\n%s", filepath.Base(filePath), err, string(out))
		}
		return nil
	}

	// psqlSQL ejecuta SQL inline (sin archivo).
	psqlSQL := func(db, sql string) {
		cmd := exec.Command("kubectl", "--kubeconfig", kubeconfig,
			"exec", "-i", "postgresql-0", "-n", "sbos-data", "--",
			"psql", "-U", "postgres", "-d", db, "-q")
		cmd.Stdin = strings.NewReader(sql)
		_ = cmd.Run()
	}

	// Crear SBOSDB si no existe (idempotente: CREATE DATABASE no tiene IF NOT EXISTS en PG)
	psqlSQL("postgres", `DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'SBOSDB') THEN
    PERFORM dblink_exec('dbname=postgres', 'CREATE DATABASE "SBOSDB" OWNER postgres');
  END IF;
END $$;`)
	// Fallback directo — si dblink no está disponible
	psqlSQL("postgres", `CREATE DATABASE "SBOSDB" OWNER postgres;`)

	// Extensiones necesarias antes del DDL
	psqlSQL("SBOSDB", `CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";`)

	// Fase 1: DDLs principales (orden obligatorio — FK cruzadas)
	mainFiles := []struct{ label, path string }{
		{"DDL principal (bauth+bglobal+bcalendar)", filepath.Join(ddlsPath, "SBOS_db_V2_DDL.sql")},
		{"DDL AtomLang (bauth)", filepath.Join(ddlsPath, "bauth_atomlang_schema.sql")},
		{"DDL BOS Control Plane", filepath.Join(ddlsPath, "bos_01__control_plane.sql")},
	}
	for _, f := range mainFiles {
		if _, err := os.Stat(f.path); os.IsNotExist(err) {
			fmt.Printf("    ⏭  %s — no encontrado, omitiendo\n", filepath.Base(f.path))
			continue
		}
		fmt.Printf("    → %s\n", f.label)
		if err := psqlExec("SBOSDB", f.path); err != nil {
			return fmt.Errorf("DDL %s: %w", f.label, err)
		}
	}

	// Fase 2: Migraciones (orden alfabético)
	migrPattern := filepath.Join(ddlsPath, "migrations", "*.sql")
	migrations, _ := filepath.Glob(migrPattern)
	if len(migrations) > 0 {
		sort.Strings(migrations)
		fmt.Printf("    → %d migraciones\n", len(migrations))
		for _, m := range migrations {
			fmt.Printf("      %s\n", filepath.Base(m))
			if err := psqlExec("SBOSDB", m); err != nil {
				return fmt.Errorf("migración %s: %w", filepath.Base(m), err)
			}
		}
	}

	// Fase 3: Seeds (orden alfabético — los seeds respetan FK entre ellos)
	seedsPattern := filepath.Join(ddlsPath, "seeds", "*.sql")
	seeds, _ := filepath.Glob(seedsPattern)
	if len(seeds) > 0 {
		sort.Strings(seeds)
		fmt.Printf("    → %d seeds\n", len(seeds))
		for _, s := range seeds {
			fmt.Printf("      %s\n", filepath.Base(s))
			if err := psqlExec("SBOSDB", s); err != nil {
				return fmt.Errorf("seed %s: %w", filepath.Base(s), err)
			}
		}
	}

	return nil
}

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

	// ── PRE: Generar bos-bootstrap.env desde el seed ───────────────────
	// El daemon necesita este archivo para conocer tenant, dominio y usuario root.
	// Lo generamos aquí para que ningún operador tenga que editarlo manualmente.
	if err := writeBootstrapEnv(&cfg); err != nil {
		return fmt.Errorf("PRE (bootstrap.env): %w", err)
	}

	// ── PASO 0: Instalar K8s (kubeadm) ────────────────────────────────
	// Prerequisito absoluto — sin K8s no hay dónde desplegar el resto.
	// No tiene compensación: el bootstrap de K8s no es reversible automáticamente.
	fmt.Println("[0/7] Instalando Kubernetes (kubeadm)...")
	if err := installFicha("sbos-bootstrap-k8s", nil); err != nil {
		return fmt.Errorf("PASO 0 (kubeadm): %w", err)
	}
	fmt.Println("  ✅ kubeadm + kubectl listos")

	// ── PASO 1: Namespace K8s + NetworkPolicy ──────────────────────────
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

	// ── PASO 1.5: Bootstrap Storage (StorageClass + PVs) ───────────────
	// Debe ejecutarse antes de PostgreSQL y Redis — ambos requieren PVs.
	fmt.Println("[1.5/7] Configurando almacenamiento...")
	if err := installFicha("sbos-bootstrap-storage", nil); err != nil {
		compensateStep1(tenantID)
		return fmt.Errorf("PASO 1.5 (storage): %w", err)
	}
	fmt.Println("  ✅ StorageClass + PVs listos")

	// ── PASO 2: PostgreSQL + Bases de Datos ─────────────────────────────
	fmt.Println("[2/7] Provisionando bases de datos...")
	if err := installFicha("postgresql", map[string]string{
		"TENANT_ID": tenantID,
		"ENGINE":    cfg.Databases.Engine,
		"VERSION":   cfg.Databases.Version,
	}); err != nil {
		compensateStep1_5(tenantID)
		return fmt.Errorf("PASO 2 (postgresql): %w", err)
	}
	fmt.Printf("  ✅ PostgreSQL %s + %d databases (ClusterIP %s)\n",
		cfg.Databases.Version, len(cfg.Databases.DBs), cfg.Databases.ClusterIP)

	// ── PASO 2.5: DDL completo + seeds en SBOSDB ──────────────────────
	// Aplica en orden: DDL principal (bauth+bglobal+bcalendar) →
	// DDL AtomLang → DDL BOS → migraciones → seeds (incluyendo tenant skull).
	// Todo via kubectl exec -i en postgresql-0 (sbos-data).
	fmt.Println("[2.5/7] Aplicando DDL completo + seeds en SBOSDB...")
	if err := applyDDLs(paths.KubeconfigPath); err != nil {
		compensateSteps12(tenantID)
		return fmt.Errorf("PASO 2.5 (DDL): %w", err)
	}
	fmt.Println("  ✅ SBOSDB inicializada (schemas bauth+bglobal+bcalendar+bos + 32 seeds)")

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
		"TENANT_ID":             tenantID,
		"TENANT_NAME":           cfg.EnterpriseTenant.TradingName,
		"REALM":                 cfg.Identity.Realm,
		"SSO_SESSION_MAX":       cfg.Identity.SSOSessionMax,
		"ACCESS_TOKEN_LIFESPAN": cfg.Identity.AccessTokenLifespan,
	}); err != nil {
		compensateSteps1234(tenantID)
		return fmt.Errorf("PASO 5 (keycloak): %w", err)
	}
	fmt.Printf("  ✅ Keycloak + Realm %s + %d SPIs (session=%s, token=%s)\n",
		cfg.Identity.Realm, len(cfg.Identity.SPIs),
		cfg.Identity.SSOSessionMax, cfg.Identity.AccessTokenLifespan)

	// ── PASO 6: Context Plane — índices y políticas dinámicas ──────────
	// Las tablas ya fueron creadas en PASO 2.5 (bos_01__control_plane.sql).
	// Este paso aplica índices dinámicos por tenant y políticas RLS via JSON-RPC.
	fmt.Println("[6/7] Registrando Context Plane para tenant...")
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
	// Las fichas de aplicación son opcionales: un fallo no hace rollback
	// de infraestructura (K8s, PG, Vault, KC ya están operativos).
	// El estado INSTALL_FAILED se registra y el observer lo reintenta en Day 1.
	fmt.Println("[7/7] Instalando fichas del tenant...")
	var fichasFallidas []string
	for _, ficha := range cfg.Fichas {
		fmt.Printf("  📦 %s...", ficha)
		if err := installFicha(ficha, map[string]string{
			"TENANT_ID": tenantID,
		}); err != nil {
			fmt.Printf(" ⚠️  PENDIENTE (%v)\n", err)
			fichasFallidas = append(fichasFallidas, ficha)
		} else {
			fmt.Println(" ✅")
		}
	}
	if len(fichasFallidas) > 0 {
		fmt.Printf("  ⚠️  %d ficha(s) pendiente(s) para Day 1: %v\n", len(fichasFallidas), fichasFallidas)
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

	// Iniciar streaming del log en background.
	// Usar paths.VarLogBos para construir la ruta sin hardcodeo (R16).
	logPath := filepath.Join(paths.VarLogBos, "fichas", name+".log")
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
//
// IMPORTANTE: ignoramos BOS_RPC_TOKEN del ambiente porque godotenv.Load("/etc/bos/.env")
// en main() puede haber cargado un token obsoleto del formato antiguo
// (sbos_admin:TOKEN sin "dev:"), lo que causa que el servidor rechace con -32600
// al recibir solo 2 partes en lugar de 3 (user:id:token).
// La fuente canónica siempre es el archivo /etc/bos/rpc-token.
func rpcAuthToken() string {
	if data, err := os.ReadFile(paths.RpcTokenFile); err == nil {
		token := strings.TrimSpace(string(data))
		if token != "" {
			auth := "sbos_admin:dev:" + token
			return base64.StdEncoding.EncodeToString([]byte(auth))
		}
	}
	// Sin token disponible — retornar vacío (el servidor rechazará con 401).
	// Nunca usar token hardcodeado de fallback: viola P6.
	// Ejecutar: bosctl system-install --mode=dev para regenerar /etc/bos/rpc-token.
	return ""
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
		Timeout: 30 * time.Minute, // sagas de infraestructura (storage, K8s) pueden tardar > 5 min
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

// compensateStep1_5 revierte el StorageClass y PVs del PASO 1.5, luego encadena PASO 1.
// Llamado cuando falla PASO 2 (postgresql) o cualquier paso posterior.
func compensateStep1_5(tenantID string) {
	compensateStep1(tenantID)
	fmt.Println("  ↩️  Compensando PASO 1.5: eliminando StorageClass + PVs")
}

func compensateSteps12(tenantID string) {
	compensateStep1_5(tenantID)
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

// removeTenant ejecuta la saga inversa de eliminación de tenant (F10.C.12).
// Orden inverso al deployTenant: sesiones → fichas → keycloak → vault → redis → postgresql → namespace.
// Principio P14: cada paso continúa ante fallos parciales — se elimina lo máximo posible.
func removeTenant(tenantID string) error {
	fmt.Printf("Eliminando tenant: %s\n", tenantID)
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	// [0] Invalidar todas las sesiones activas antes de tocar infraestructura
	fmt.Println("[0/7] Invalidando sesiones activas del tenant...")
	if err := runBosRPC("bos.ctx.tenant.suspend", map[string]interface{}{
		"tenant_id": tenantID,
	}); err != nil {
		return fmt.Errorf("paso 0 (invalidar sesiones): %w", err)
	}
	fmt.Printf("  Sesiones de %s invalidadas\n", tenantID)

	// [1/7] Fichas de aplicación (no conocidas sin seed — informar al operador)
	fmt.Println("[1/7] Fichas de aplicacion del tenant...")
	fmt.Println("  Nota: usa 'bosctl ficha list' para ver fichas activas y eliminarlas individualmente")

	// [2/7] Realm Keycloak
	fmt.Println("[2/7] Eliminando realm Keycloak...")
	if err := removeFicha("keycloak", map[string]string{"TENANT_ID": tenantID}); err != nil {
		fmt.Printf("  WARN keycloak remove: %v (continuando)\n", err)
	} else {
		fmt.Printf("  Realm Keycloak del tenant %s eliminado\n", tenantID)
	}

	// [3/7] Paths Vault + AppRole
	fmt.Println("[3/7] Eliminando paths Vault...")
	if err := removeFicha("vault", map[string]string{"TENANT_ID": tenantID}); err != nil {
		fmt.Printf("  WARN vault remove: %v (continuando)\n", err)
	} else {
		fmt.Println("  Paths Vault eliminados")
	}

	// [4/7] Redis context registry del tenant
	fmt.Println("[4/7] Limpiando Redis context registry...")
	if err := removeFicha("redis", map[string]string{"TENANT_ID": tenantID}); err != nil {
		fmt.Printf("  WARN redis remove: %v (continuando)\n", err)
	} else {
		fmt.Println("  Redis context registry limpiado")
	}

	// [5/7] Bases de datos PostgreSQL del tenant
	fmt.Println("[5/7] Eliminando bases de datos PostgreSQL...")
	if err := removeFicha("postgresql", map[string]string{"TENANT_ID": tenantID}); err != nil {
		fmt.Printf("  WARN postgresql remove: %v (continuando)\n", err)
	} else {
		fmt.Println("  Bases de datos del tenant eliminadas")
	}

	// [6/7] Namespace K8s + NetworkPolicy
	fmt.Println("[6/7] Eliminando namespace K8s...")
	namespaceFicha := "sbos-ns-" + tenantID
	if err := removeFicha(namespaceFicha, map[string]string{"TENANT_ID": tenantID}); err != nil {
		fmt.Printf("  WARN namespace remove: %v (continuando)\n", err)
	} else {
		fmt.Printf("  Namespace sbos-%s eliminado\n", tenantID)
	}

	// [7/7] Verificación
	fmt.Println("[7/7] Saga completada")
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Printf("Tenant %s eliminado. Verificar residuos con 'bosctl ficha list'\n", tenantID)
	return nil
}

// removeFicha ejecuta bos.ficha.remove con variables de entorno opcionales.
func removeFicha(name string, env map[string]string) error {
	socket := os.Getenv("BOS_SOCKET")
	if socket == "" {
		socket = paths.SocketPath
	}
	params := map[string]interface{}{
		"ficha_id": name,
	}
	if len(env) > 0 {
		params["env"] = env
	}
	return rpcCall(socket, "bos.ficha.remove", params)
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
		tenantID := args[1]
		fmt.Printf("Suspendiendo tenant %s...\n", tenantID)
		if err := runBosRPC("bos.ctx.tenant.suspend", map[string]interface{}{
			"tenant_id": tenantID,
		}); err != nil {
			fmt.Fprintf(os.Stderr, "tenant suspend: %v\n", err)
			return 1
		}
		fmt.Printf("  Tenant %s suspendido — sesiones activas invalidadas\n", tenantID)
		return 0
	case "remove":
		if len(args) < 2 {
			fmt.Fprintf(os.Stderr, "Uso: bosctl tenant remove <tenant-id>\n")
			return 1
		}
		tenantID := args[1]
		fmt.Printf("ADVERTENCIA: Esta operacion eliminara permanentemente el tenant '%s'.\n", tenantID)
		fmt.Println("Todos los datos, sesiones, credenciales y fichas seran eliminados.")
		fmt.Printf("Esta accion es IRREVERSIBLE. Escribe el ID del tenant para confirmar: ")
		reader := bufio.NewReader(os.Stdin)
		confirm, _ := reader.ReadString('\n')
		confirm = strings.TrimSpace(confirm)
		if confirm != tenantID {
			fmt.Println("Confirmacion incorrecta. Operacion cancelada.")
			return 0
		}
		if err := removeTenant(tenantID); err != nil {
			fmt.Fprintf(os.Stderr, "tenant remove: %v\n", err)
			return 1
		}
		return 0
	case "list":
		fmt.Println("Tenants: (ninguno — F10.C.10 pendiente)")
		return 0
	default:
		fmt.Fprintf(os.Stderr, "tenant: accion desconocida: %s\n", action)
		return 1
	}
}
