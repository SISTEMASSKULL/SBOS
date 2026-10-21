// Package main — install_wizard.go: asistente interactivo de configuración.
// Si bos-install.toml no existe, el instalador lanza este wizard que pide los datos
// campo por campo antes de arrancar. Sin nano, sin editar archivos manualmente.
package main

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/charmbracelet/huh"
)

// runInstallWizard lanza el asistente interactivo que recopila los datos del cliente
// y genera bos-install.toml en el directorio actual (junto a los binarios).
// Retorna el path del archivo generado o un error.
func runInstallWizard() (string, error) {
	fmt.Println()
	fmt.Println("┌─────────────────────────────────────────────────────────────┐")
	fmt.Println("│          SBOS — Asistente de Configuración                  │")
	fmt.Println("│  El sistema le pedirá los datos de su organización.         │")
	fmt.Println("│  Use Tab / Enter para navegar. Ctrl+C para cancelar.        │")
	fmt.Println("└─────────────────────────────────────────────────────────────┘")
	fmt.Println()

	var (
		clientDomain  string
		orgName       string
		orgShort      string
		serverIP      string
		adminName     string
		adminPassword string
		adminConfirm  string
		timezone      string
		country       string
		language      string
	)

	// ── Grupo 1: Datos de la organización ────────────────────────────────────
	g1 := huh.NewGroup(
		huh.NewNote().
			Title("Paso 1 de 3 — Datos de la organización").
			Description("Esta información identifica a su empresa en el sistema."),

		huh.NewInput().
			Title("Dominio principal de la empresa").
			Description("El dominio que ya tiene registrado (sin www ni https).\nEjemplo: miempresa.com  o  miempresa.com.bo").
			Placeholder("miempresa.com").
			Value(&clientDomain).
			Validate(func(v string) error {
				v = strings.TrimSpace(v)
				if v == "" {
					return fmt.Errorf("requerido")
				}
				re := regexp.MustCompile(`^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+$`)
				if !re.MatchString(v) {
					return fmt.Errorf("formato inválido — use solo letras, números y puntos")
				}
				return nil
			}),

		huh.NewInput().
			Title("Nombre completo de la organización").
			Description("Aparecerá en correos, documentos y pantallas del sistema.").
			Placeholder("Empresa Bolivia S.R.L.").
			Value(&orgName).
			Validate(func(v string) error {
				if strings.TrimSpace(v) == "" {
					return fmt.Errorf("requerido")
				}
				if utf8.RuneCountInString(strings.TrimSpace(v)) < 3 {
					return fmt.Errorf("demasiado corto")
				}
				return nil
			}),

		huh.NewInput().
			Title("Identificador corto").
			Description("Nombre técnico sin espacios ni mayúsculas (máximo 20 caracteres).\nEjemplo: miempresa  o  grupo-abc").
			Placeholder("miempresa").
			Value(&orgShort).
			Validate(func(v string) error {
				v = strings.TrimSpace(v)
				if v == "" {
					return fmt.Errorf("requerido")
				}
				re := regexp.MustCompile(`^[a-z0-9][a-z0-9-]{0,18}[a-z0-9]$|^[a-z0-9]$`)
				if !re.MatchString(v) {
					return fmt.Errorf("solo minúsculas, números y guiones. Sin espacios ni mayúsculas")
				}
				return nil
			}),

		huh.NewInput().
			Title("Dirección IP del servidor").
			Description("La IP pública o privada de este servidor.\nEjemplo: 192.168.1.100  o  203.0.113.10").
			Placeholder("0.0.0.0").
			Value(&serverIP).
			Validate(func(v string) error {
				v = strings.TrimSpace(v)
				if v == "" {
					return fmt.Errorf("requerido")
				}
				ip := net.ParseIP(v)
				if ip == nil {
					return fmt.Errorf("no es una IP válida")
				}
				if ip.IsLoopback() || v == "0.0.0.0" {
					return fmt.Errorf("ingrese la IP real del servidor")
				}
				return nil
			}),
	)

	// ── Grupo 2: Administrador ────────────────────────────────────────────────
	g2 := huh.NewGroup(
		huh.NewNote().
			Title("Paso 2 de 3 — Cuenta del administrador").
			Description("El administrador principal accede a todas las aplicaciones del sistema."),

		huh.NewInput().
			Title("Nombre completo del administrador").
			Description("Aparecerá en el perfil de administrador del sistema.").
			Placeholder("Juan Pérez").
			Value(&adminName).
			Validate(func(v string) error {
				if strings.TrimSpace(v) == "" {
					return fmt.Errorf("requerido")
				}
				return nil
			}),

		huh.NewInput().
			Title("Contraseña del administrador").
			Description("Mínimo 12 caracteres. Se usará para acceder a todas las aplicaciones.\n⚠  Guárdela en un lugar seguro — no se puede recuperar sin intervención técnica.").
			Password(true).
			Value(&adminPassword).
			Validate(func(v string) error {
				if v == "" {
					return fmt.Errorf("requerido")
				}
				if utf8.RuneCountInString(v) < 12 {
					return fmt.Errorf("mínimo 12 caracteres (tiene %d)", utf8.RuneCountInString(v))
				}
				return nil
			}),

		huh.NewInput().
			Title("Confirmar contraseña").
			Description("Escriba la contraseña nuevamente para confirmar.").
			Password(true).
			Value(&adminConfirm).
			Validate(func(v string) error {
				if v != adminPassword {
					return fmt.Errorf("las contraseñas no coinciden")
				}
				return nil
			}),
	)

	// ── Grupo 3: Localización ─────────────────────────────────────────────────
	g3 := huh.NewGroup(
		huh.NewNote().
			Title("Paso 3 de 3 — Localización").
			Description("Configure el idioma, zona horaria y país del sistema."),

		huh.NewSelect[string]().
			Title("País").
			Description("Determina la moneda, plan contable y días festivos del sistema.").
			Options(
				huh.NewOption("Bolivia (BO)", "BO"),
				huh.NewOption("Colombia (CO)", "CO"),
				huh.NewOption("México (MX)", "MX"),
				huh.NewOption("Perú (PE)", "PE"),
				huh.NewOption("Argentina (AR)", "AR"),
				huh.NewOption("Chile (CL)", "CL"),
				huh.NewOption("Ecuador (EC)", "EC"),
				huh.NewOption("Paraguay (PY)", "PY"),
				huh.NewOption("Uruguay (UY)", "UY"),
				huh.NewOption("Venezuela (VE)", "VE"),
				huh.NewOption("España (ES)", "ES"),
				huh.NewOption("Otro (US)", "US"),
			).
			Value(&country),

		huh.NewSelect[string]().
			Title("Idioma principal").
			Options(
				huh.NewOption("Español", "es"),
				huh.NewOption("Inglés", "en"),
				huh.NewOption("Portugués", "pt"),
				huh.NewOption("Francés", "fr"),
			).
			Value(&language),

		huh.NewInput().
			Title("Zona horaria").
			Description("Zona horaria IANA del servidor.\nEjemplos: America/La_Paz · America/Bogota · America/Mexico_City · UTC").
			Placeholder("America/La_Paz").
			Value(&timezone).
			Validate(func(v string) error {
				v = strings.TrimSpace(v)
				if v == "" {
					return fmt.Errorf("requerido")
				}
				if _, err := time.LoadLocation(v); err != nil {
					return fmt.Errorf("zona horaria inválida — ver https://en.wikipedia.org/wiki/List_of_tz_database_time_zones")
				}
				return nil
			}),
	)

	// Ejecutar el formulario
	form := huh.NewForm(g1, g2, g3).WithTheme(huh.ThemeBase())
	if err := form.Run(); err != nil {
		if err.Error() == "user aborted" {
			return "", fmt.Errorf("instalación cancelada por el usuario")
		}
		return "", fmt.Errorf("error en el asistente: %v", err)
	}

	// Normalizar entradas
	clientDomain = strings.TrimSpace(clientDomain)
	orgName = strings.TrimSpace(orgName)
	orgShort = strings.TrimSpace(strings.ToLower(orgShort))
	serverIP = strings.TrimSpace(serverIP)
	adminName = strings.TrimSpace(adminName)
	timezone = strings.TrimSpace(timezone)

	// ── Resumen de confirmación ───────────────────────────────────────────────
	fmt.Println()
	fmt.Println("┌─────────────────────────────────────────────────────────────┐")
	fmt.Println("│                  Resumen de configuración                   │")
	fmt.Println("├─────────────────────────────────────────────────────────────┤")
	fmt.Printf("│  Organización : %-43s│\n", truncate(orgName, 43))
	fmt.Printf("│  Identificador: %-43s│\n", truncate(orgShort, 43))
	fmt.Printf("│  Dominio      : %-43s│\n", truncate(clientDomain, 43))
	fmt.Printf("│  Servidor IP  : %-43s│\n", truncate(serverIP, 43))
	fmt.Printf("│  Administrador: %-43s│\n", truncate(adminName, 43))
	stars := utf8.RuneCountInString(adminPassword)
	if stars > 16 {
		stars = 16
	}
	fmt.Printf("│  Contraseña   : %-43s│\n", strings.Repeat("*", stars))
	fmt.Printf("│  País / Idioma: %s / %-39s│\n", country, language)
	fmt.Printf("│  Zona horaria : %-43s│\n", truncate(timezone, 43))
	fmt.Println("└─────────────────────────────────────────────────────────────┘")
	fmt.Println()

	var confirmar bool
	confirmForm := huh.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title("¿Los datos son correctos?").
				Description("Se generará la configuración y comenzará la instalación.").
				Affirmative("Sí, instalar").
				Negative("No, corregir").
				Value(&confirmar),
		),
	).WithTheme(huh.ThemeBase())

	if err := confirmForm.Run(); err != nil || !confirmar {
		return "", fmt.Errorf("instalación cancelada — vuelva a ejecutar bosctl setup para corregir los datos")
	}

	// ── Generar bos-install.toml ──────────────────────────────────────────────
	destPath := resolveWritableTomlPath()
	content := generateToml(clientDomain, orgName, orgShort, serverIP, adminName, adminPassword, timezone, country, language)
	if err := os.WriteFile(destPath, []byte(content), 0600); err != nil {
		return "", fmt.Errorf("no se pudo guardar bos-install.toml en %s: %v", destPath, err)
	}

	fmt.Printf("\n  ✓ Configuración guardada en: %s\n\n", destPath)
	return destPath, nil
}

// resolveWritableTomlPath elige dónde guardar bos-install.toml:
// primero intenta el CWD (directorio del repositorio clonado), luego /etc/bos/.
func resolveWritableTomlPath() string {
	if cwd, err := os.Getwd(); err == nil {
		return filepath.Join(cwd, "bos-install.toml")
	}
	return "/etc/bos/bos-install.toml"
}

// generateToml construye el contenido del bos-install.toml con los datos recopilados.
func generateToml(domain, orgName, orgShort, serverIP, adminName, adminPassword, timezone, country, language string) string {
	adminEmail := "admin@" + domain
	return fmt.Sprintf(`# bos-install.toml — generado por bosctl setup el %s
# Este archivo contiene credenciales. No lo comparta ni lo suba a repositorios.

client_domain   = %q
org_name        = %q
org_short       = %q
server_ip       = %q

admin_password  = %q
admin_name      = %q
admin_email     = %q

timezone        = %q
country         = %q
language        = %q

channel         = "stable"
`,
		time.Now().Format("2006-01-02 15:04:05"),
		domain, orgName, orgShort, serverIP,
		adminPassword, adminName, adminEmail,
		timezone, country, language,
	)
}

func truncate(s string, maxLen int) string {
	runes := []rune(s)
	if len(runes) <= maxLen {
		return s
	}
	return string(runes[:maxLen-1]) + "…"
}
