// Package main — install_validate.go: validación del bos-install.toml antes de instalar.
// El instalador nunca arranca sin que todos los campos obligatorios sean válidos y
// distintos de los valores del template. Sin esta compuerta, una instalación de ~48 min
// puede fallar al final por un campo vacío que era detectable desde el inicio.
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

	bostoml "bos/internal/toml"
)

// installCfg refleja la estructura de bos-install.toml.
// Solo los campos obligatorios para la validación de pre-vuelo.
type installCfg struct {
	General  installCfgGeneral  `toml:"general"`
	Security installCfgSecurity `toml:"security"`
}

type installCfgGeneral struct {
	ClientDomain string `toml:"client_domain"`
	OrgName      string `toml:"org_name"`
	OrgShort     string `toml:"org_short"`
	ServerIP     string `toml:"server_ip"`
	Timezone     string `toml:"timezone"`
	Country      string `toml:"country"`
	Language     string `toml:"language"`
}

type installCfgSecurity struct {
	AdminPassword string `toml:"admin_password"`
}

// valores conocidos del template — cualquier campo que coincida exactamente es rechazo inmediato.
var templateValues = map[string]string{
	"client_domain":  "skull.sbos.local",
	"org_name":       "SKULL SISTEMAS SRL",
	"org_short":      "skull",
	"server_ip":      "0.0.0.0",
	"admin_password": "cambiar-esto",
}

var reOrgShort = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{0,18}[a-z0-9]$|^[a-z0-9]$`)
var reFQDN = regexp.MustCompile(`^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+$`)

// resolveInstallTomlPath busca bos-install.toml en orden de precedencia:
// 1. CWD (directorio de trabajo — donde se clonó el repositorio)
// 2. Junto al ejecutable bosctl
// 3. core/ junto al ejecutable
// 4. /etc/bos/ (si ya fue instalado antes)
func resolveInstallTomlPath() string {
	// Primero el CWD — el operador clona el repo y ejecuta desde allí
	if cwd, err := os.Getwd(); err == nil {
		p := filepath.Join(cwd, "bos-install.toml")
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	// Junto al ejecutable
	if self, err := os.Executable(); err == nil {
		selfDir := filepath.Dir(self)
		for _, rel := range []string{"bos-install.toml", "core/bos-install.toml"} {
			p := filepath.Join(selfDir, rel)
			if _, err := os.Stat(p); err == nil {
				return p
			}
		}
	}
	// Instalación previa
	if _, err := os.Stat("/etc/bos/bos-install.toml"); err == nil {
		return "/etc/bos/bos-install.toml"
	}
	return ""
}

// validateInstallToml verifica que bos-install.toml exista, sea TOML válido,
// tenga todos los campos obligatorios y que ninguno sea un valor del template.
// Imprime todos los errores encontrados (no se detiene en el primero) para que
// el operador corrija todo de una sola vez.
// Retorna el path del archivo si es válido, o "" y un error descriptivo.
func validateInstallToml() (string, error) {
	fmt.Println("bosctl setup — validando configuración...")
	fmt.Println()

	path := resolveInstallTomlPath()
	if path == "" {
		return "", fmt.Errorf(
			"bos-install.toml no encontrado\n" +
				"  Ejecutar bosctl setup desde el directorio del repositorio clonado:\n" +
				"    git clone https://github.com/SISTEMASSKULL/bos-install.git\n" +
				"    cd bos-install && nano bos-install.toml && sudo ./bosctl setup",
		)
	}

	var cfg installCfg
	if _, err := bostoml.DecodeFile(path, &cfg); err != nil {
		return "", fmt.Errorf("bos-install.toml tiene error de sintaxis: %v", err)
	}

	var errs []string

	// ── [general] ──────────────────────────────────────────────────────────────
	errs = append(errs, checkField("client_domain", cfg.General.ClientDomain,
		func(v string) string {
			if v == "" {
				return "vacío"
			}
			if !reFQDN.MatchString(v) {
				return "no es un nombre de dominio válido (FQDN). Ejemplo: empresa.sbos.local"
			}
			return ""
		})...)

	errs = append(errs, checkField("org_name", cfg.General.OrgName,
		func(v string) string {
			if v == "" {
				return "vacío"
			}
			if utf8.RuneCountInString(v) < 3 {
				return "demasiado corto (mínimo 3 caracteres)"
			}
			return ""
		})...)

	errs = append(errs, checkField("org_short", cfg.General.OrgShort,
		func(v string) string {
			if v == "" {
				return "vacío"
			}
			if !reOrgShort.MatchString(v) {
				return "solo se permiten letras minúsculas, números y guiones. Ejemplo: empresa-sa"
			}
			return ""
		})...)

	errs = append(errs, checkField("server_ip", cfg.General.ServerIP,
		func(v string) string {
			if v == "" {
				return "vacío"
			}
			ip := net.ParseIP(v)
			if ip == nil {
				return "no es una IPv4 válida"
			}
			if ip.IsLoopback() {
				return "no puede ser una dirección de loopback (127.x.x.x)"
			}
			if v == "0.0.0.0" {
				return "no puede ser 0.0.0.0 — indicar la IP real del servidor"
			}
			return ""
		})...)

	errs = append(errs, checkField("timezone", cfg.General.Timezone,
		func(v string) string {
			if v == "" {
				return "vacío"
			}
			if _, err := time.LoadLocation(v); err != nil {
				return fmt.Sprintf("zona horaria IANA inválida. Ejemplos válidos: America/La_Paz, UTC, America/Bogota")
			}
			return ""
		})...)

	errs = append(errs, checkField("country", cfg.General.Country,
		func(v string) string {
			if v == "" {
				return "vacío"
			}
			if len(v) != 2 || strings.ToUpper(v) != strings.ToUpper(v) {
				return "debe ser un código ISO 3166-1 alpha-2 de 2 letras. Ejemplos: BO, CO, MX, PE, AR"
			}
			return ""
		})...)

	errs = append(errs, checkField("language", cfg.General.Language,
		func(v string) string {
			if v == "" {
				return "vacío"
			}
			if len(v) < 2 {
				return "debe ser un código BCP-47. Ejemplos: es, en, pt"
			}
			return ""
		})...)

	// ── [security] ─────────────────────────────────────────────────────────────
	errs = append(errs, checkField("admin_password", cfg.Security.AdminPassword,
		func(v string) string {
			if v == "" {
				return "vacío"
			}
			if utf8.RuneCountInString(v) < 12 {
				return fmt.Sprintf("demasiado corta (%d caracteres). Mínimo 12", utf8.RuneCountInString(v))
			}
			return ""
		})...)

	// Filtrar entradas vacías y mostrar resultado
	var realErrs []string
	for _, e := range errs {
		if e != "" {
			realErrs = append(realErrs, e)
		}
	}

	if len(realErrs) > 0 {
		fmt.Println("  Se encontraron errores en bos-install.toml:")
		for _, e := range realErrs {
			fmt.Printf("  ✗ %s\n", e)
		}
		fmt.Println()
		fmt.Println("  Corregir bos-install.toml y volver a ejecutar: sudo ./bosctl setup")
		return "", fmt.Errorf("configuración inválida (%d error(es))", len(realErrs))
	}

	// Todo OK — mostrar resumen de la configuración confirmada
	fmt.Println("  ✓ bos-install.toml válido")
	fmt.Printf("      Organización : %s (%s)\n", cfg.General.OrgName, cfg.General.OrgShort)
	fmt.Printf("      Dominio      : %s\n", cfg.General.ClientDomain)
	fmt.Printf("      Servidor     : %s\n", cfg.General.ServerIP)
	fmt.Printf("      Zona horaria : %s\n", cfg.General.Timezone)
	fmt.Printf("      País / idioma: %s / %s\n", strings.ToUpper(cfg.General.Country), cfg.General.Language)
	fmt.Println()

	return path, nil
}

// checkField aplica la regla de validación al valor v e incluye la comprobación
// de valor-del-template. Retorna una lista de mensajes de error (vacía si OK).
func checkField(name, v string, rule func(string) string) []string {
	// Primero verificar si es valor del template
	if tmpl, isTemplate := templateValues[name]; isTemplate && v == tmpl {
		return []string{fmt.Sprintf(
			"[general/security].%s contiene el valor del template (%q) — reemplazar con datos reales del cliente",
			name, tmpl,
		)}
	}
	if msg := rule(v); msg != "" {
		return []string{fmt.Sprintf("[general/security].%s: %s (valor actual: %q)", name, msg, v)}
	}
	return nil
}
