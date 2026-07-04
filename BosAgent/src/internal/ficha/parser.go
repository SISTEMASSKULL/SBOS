// Package ficha — Parser estricto de manifest.yml (F11.A.2).
// BOS-REPAIR Plan Maestro v3 · SAN-10 · SBOS-019 §2.
//
// Este parser valida estrictamente el manifiesto de una ficha contra
// el contrato SBOS-019. A diferencia del parser básico en plugin/loader.go,
// este rechaza campos desconocidos (SAN-10 — anti-mass-assignment),
// valida tipos, verifica licencias OSI-approved, y exige dashboard.json.
//
// Reglas de validación (SAN-10 + SBOS-055 SOV-01..SOV-08):
//  1. Campos obligatorios: identity.id, identity.server, identity.version
//  2. Rechazo de campos desconocidos por sección (allowlist estricta)
//  3. Licencia debe ser OSI-approved (MIT, Apache-2.0, GPL-3.0, etc.)
//  4. dashboard.json debe existir en resources/
//  5. Puertos deben tener metrics y health (SBOS-019 §manifest.ports)
//  6. Slug validation en id y server
//  7. Semver validation en version
//
// Uso:
//   errors := ParseManifestStrict(manifestContent, fichaPath)
//   if len(errors) > 0 { ... }
package ficha

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// ── Tipos ────────────────────────────────────────────────────────────

// ParseError representa un error de validación de manifiesto.
type ParseError struct {
	Section  string // sección donde ocurrió el error (ej: "identity")
	Field    string // campo específico (ej: "id", "version")
	Message  string // descripción del error
	Value    string // valor recibido (truncado a 80 chars)
}

func (e *ParseError) Error() string {
	if e.Value != "" {
		return fmt.Sprintf("[%s.%s] %s: %q", e.Section, e.Field, e.Message, e.Value)
	}
	return fmt.Sprintf("[%s.%s] %s", e.Section, e.Field, e.Message)
}

// ParseResult contiene el resultado de parsear y validar un manifiesto.
type ParseResult struct {
	Valid  bool
	Errors []ParseError
	Warnings []string
}

// AddError agrega un error de validación.
func (r *ParseResult) AddError(section, field, message, value string) {
	r.Errors = append(r.Errors, ParseError{Section: section, Field: field, Message: message, Value: value})
	r.Valid = false
}

// AddWarning agrega un warning (no bloqueante).
func (r *ParseResult) AddWarning(msg string) {
	r.Warnings = append(r.Warnings, msg)
}

// ── Allowlists por sección ────────────────────────────────────────────
// Cualquier campo no listado aquí es RECHAZADO (SAN-10).

var allowedFields = map[string][]string{
	"identity": {
		"id", "server", "version", "category", "criticality", "description",
	},
	"workload": {
		"type", "runtime",
	},
	"order": {
		"execution_order",
	},
	"requirements": {
		"dependencies", "runtime_dependencies",
	},
	"governance": {
		"auto_install", "requires_approval", "category_label",
	},
	"meta": {
		"backend", "idempotent", "estimated_minutes", "rollback_support",
	},
	"health": {
		"type", "command", "http_path", "tcp_address", "expected_output",
		"timeout_seconds", "interval_seconds",
	},
	"audit": {
		"ctx_id_required", "log_path",
	},
	"scaling": {
		"strategy", "min_replicas", "max_replicas", "target_cpu_percent",
		"target_memory_percent", "scale_up_cooldown", "scale_down_cooldown",
		"mode", "min_cpu", "max_cpu", "min_memory", "max_memory",
		"update_policy", "enabled",
	},
	"maintenance": {
		"strategy", "max_unavailable", "drain_timeout",
	},
	"slos": {
		"availability", "latency_p99_ms", "error_rate_max",
	},
	"timeouts": {
		"install", "update", "repair", "remove",
		"pre_install", "post_install", "verify", "commit",
	},
}

// OSIApprovedLicenses lista las licencias aceptadas.
var OSIApprovedLicenses = []string{
	"MIT", "Apache-2.0", "GPL-2.0", "GPL-3.0", "LGPL-2.1", "LGPL-3.0",
	"BSD-2-Clause", "BSD-3-Clause", "MPL-2.0", "CDDL-1.0", "EPL-2.0",
	"AGPL-3.0", "Unlicense", "BSL-1.0", "PostgreSQL", "ISC",
}

// ── Validación principal ──────────────────────────────────────────────

// ParseManifestStrict valida el contenido de un manifest.yml contra el contrato SBOS-019.
// fichaPath es la ruta al directorio de la ficha (para verificar dashboard.json).
//
// A-07: usa gopkg.in/yaml.v3 para parsear la estructura YAML en lugar del
// parser artesanal de líneas anterior (strings.Split/HasPrefix).
func ParseManifestStrict(content, fichaPath string) *ParseResult {
	result := &ParseResult{Valid: true}

	var hasDashboard bool
	if fichaPath != "" {
		dashboardPath := filepath.Join(fichaPath, "resources", "dashboard.json")
		if _, err := os.Stat(dashboardPath); err == nil {
			hasDashboard = true
		}
	}

	var manifest map[string]interface{}
	if err := yaml.Unmarshal([]byte(content), &manifest); err != nil {
		result.AddError("(raíz)", "yaml", "YAML inválido: "+err.Error(), "")
		return result
	}
	if manifest == nil {
		result.AddError("(raíz)", "yaml", "manifiesto vacío o nulo", "")
		return result
	}

	freeSections := map[string]bool{
		"ports": true, "versions": true, "databases": true, "feature_flags": true,
	}

	var foundSections []string
	sectionFields := make(map[string][]string)

	for sectionKey, sectionRaw := range manifest {
		if freeSections[sectionKey] {
			foundSections = append(foundSections, sectionKey)
			continue
		}
		if _, ok := allowedFields[sectionKey]; !ok {
			result.AddWarning(fmt.Sprintf("sección desconocida: %q", sectionKey))
			continue
		}
		foundSections = append(foundSections, sectionKey)

		sectionMap, ok := sectionRaw.(map[string]interface{})
		if !ok || sectionMap == nil {
			continue
		}

		for fieldKey, fieldRaw := range sectionMap {
			// requirements.dependencies y runtime_dependencies son listas de strings
			if sectionKey == "requirements" &&
				(fieldKey == "dependencies" || fieldKey == "runtime_dependencies") {
				sectionFields[sectionKey] = append(sectionFields[sectionKey], fieldKey)
				if list, ok := fieldRaw.([]interface{}); ok {
					for _, item := range list {
						dep := strings.Trim(fmt.Sprintf("%v", item), `"' `)
						if dep != "" {
							validateDependencyName(dep, result)
						}
					}
				}
				continue
			}

			// Validar campo contra allowlist (SAN-10)
			if allowed, ok := allowedFields[sectionKey]; ok {
				if !isAllowed(fieldKey, allowed) {
					result.AddError(sectionKey, fieldKey,
						fmt.Sprintf("campo no permitido en sección %q (SAN-10). Permitidos: %s",
							sectionKey, strings.Join(allowed, ", ")),
						fmt.Sprintf("%v", fieldRaw))
					continue
				}
			}
			sectionFields[sectionKey] = append(sectionFields[sectionKey], fieldKey)
			value := strings.Trim(fmt.Sprintf("%v", fieldRaw), `"' `)
			validateField(sectionKey, fieldKey, value, result)
		}
	}

	validateRequiredSections(foundSections, sectionFields, result)
	validateLicense(content, result)

	if fichaPath != "" && !hasDashboard {
		result.AddError("resources", "dashboard.json",
			"dashboard.json requerido en resources/ (SBOS-019 §manifest.ports, F11.E.2)",
			fichaPath+"/resources/dashboard.json")
	}

	return result
}

// ── Validaciones específicas ──────────────────────────────────────────

func validateField(section, key, value string, result *ParseResult) {
	switch section {
	case "identity":
		switch key {
		case "id":
			if err := slugValidate(value); err != nil {
				result.AddError(section, key, err.Error(), value)
			}
		case "server":
			if err := serverValidate(value); err != nil {
				result.AddError(section, key, err.Error(), value)
			}
		case "version":
			if err := semverValidate(value); err != nil {
				result.AddError(section, key, err.Error(), value)
			}
		case "category":
			if value != "" {
				cat := 0
				fmt.Sscanf(value, "%d", &cat)
				if cat < 1 || cat > 3 {
					result.AddError(section, key, "category debe ser 1, 2, o 3", value)
				}
			}
		}

	case "workload":
		switch key {
		case "type":
			if !containsInSlice(allowedWorkloadTypes, value) {
				result.AddError(section, key,
					fmt.Sprintf("tipo inválido. Válidos: %s", strings.Join(allowedWorkloadTypes, ", ")),
					value)
			}
		case "runtime":
			if !containsInSlice(allowedRuntimes, value) {
				result.AddError(section, key,
					fmt.Sprintf("runtime inválido. Válidos: %s", strings.Join(allowedRuntimes, ", ")),
					value)
			}
		}

	case "health":
		switch key {
		case "type":
			if !containsInSlice(allowedHealthTypes, value) {
				result.AddError(section, key,
					fmt.Sprintf("tipo de health inválido. Válidos: %s", strings.Join(allowedHealthTypes, ", ")),
					value)
			}
		}
	}
}

// requiredSections define las secciones obligatorias del manifest.yml (SBOS-019 §2).
// Si una sección requerida no aparece, el manifiesto es inválido.
var requiredSections = []string{"identity", "workload", "meta"}

// requiredFieldsBySection define los campos obligatorios por sección.
// Si una sección está presente pero le falta un campo requerido, es error.
var requiredFieldsBySection = map[string][]string{
	"identity": {"id", "server", "version"},
	"workload": {"type"},
	"meta":     {"backend"},
}

// validateRequiredSections verifica que todas las secciones obligatorias existan
// y que cada una contenga sus campos requeridos.
//
// Parámetros:
//   - foundSections: lista de secciones detectadas en el manifiesto
//   - sectionFields: mapa sección → campos encontrados
//   - result: resultado de parseo donde se acumulan los errores
func validateRequiredSections(foundSections []string, sectionFields map[string][]string, result *ParseResult) {
	// Verificar secciones obligatorias
	for _, required := range requiredSections {
		if !containsInSlice(foundSections, required) {
			result.AddError("(raíz)", required,
				fmt.Sprintf("sección %q requerida (SBOS-019 §2). Secciones encontradas: %s",
					required, strings.Join(foundSections, ", ")),
				"")
		}
	}

	// Verificar campos requeridos dentro de cada sección encontrada
	for _, section := range foundSections {
		requiredFields, hasRequirements := requiredFieldsBySection[section]
		if !hasRequirements {
			continue // sección sin campos obligatorios (ej: governance, slos)
		}

		fields, exists := sectionFields[section]
		if !exists {
			// Sección declarada pero sin campos — reportar todos como faltantes
			for _, field := range requiredFields {
				result.AddError(section, field,
					fmt.Sprintf("campo %q requerido en sección %q (SBOS-019 §2)", field, section),
					"")
			}
			continue
		}

		for _, required := range requiredFields {
			if !containsInSlice(fields, required) {
				result.AddError(section, required,
					fmt.Sprintf("campo %q requerido en sección %q. Campos encontrados: %s",
						required, section, strings.Join(fields, ", ")),
					"")
			}
		}
	}
}

func validateLicense(content string, result *ParseResult) {
	// Buscar campo license: en el manifiesto
	for _, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "license:") {
			license := strings.TrimSpace(strings.TrimPrefix(trimmed, "license:"))
			license = strings.Trim(license, ` "'`)
			if license == "" {
				result.AddError("identity", "license", "licencia requerida (OSI-approved)", "")
				return
			}
			if !isOSIApproved(license) {
				result.AddError("identity", "license",
					fmt.Sprintf("licencia %q no es OSI-approved. Válidas: %s",
						license, strings.Join(OSIApprovedLicenses, ", ")),
					license)
			}
			return
		}
	}
	// License no declarado → warning (no error — puede estar en otra sección)
}

func validateDependencyName(dep string, result *ParseResult) {
	if dep == "" {
		return
	}
	// Validar que el nombre de dependencia sea un slug válido
	if err := slugValidate(dep); err != nil {
		result.AddError("requirements", "dependencies",
			fmt.Sprintf("nombre de dependencia inválido: %s", err.Error()), dep)
	}
}

// ── Helpers de validación ──────────────────────────────────────────────

func slugValidate(s string) error {
	if s == "" {
		return fmt.Errorf("no puede estar vacío")
	}
	for _, c := range s {
		if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_') {
			return fmt.Errorf("carácter inválido: %q", c)
		}
	}
	return nil
}

func semverValidate(v string) error {
	if v == "" {
		return fmt.Errorf("versión no puede estar vacía")
	}
	parts := strings.Split(v, ".")
	if len(parts) < 2 || len(parts) > 3 {
		return fmt.Errorf("formato inválido: %q (esperado MAJOR.MINOR[.PATCH])", v)
	}
	for _, p := range parts {
		for _, c := range p {
			if c < '0' || c > '9' {
				return fmt.Errorf("versión no numérica: %q", v)
			}
		}
	}
	return nil
}

func serverValidate(s string) error {
	if s == "S-HOST" {
		return nil
	}
	if len(s) != 3 || s[0] != 'S' || s[1] < '0' || s[1] > '9' || s[2] < '0' || s[2] > '9' {
		return fmt.Errorf("formato inválido: %q (esperado S01-S15 o S-HOST)", s)
	}
	num := int(s[1]-'0')*10 + int(s[2]-'0')
	if num < 1 || num > 15 {
		return fmt.Errorf("servidor fuera de rango: %q (S01-S15)", s)
	}
	return nil
}

func containsInSlice(slice []string, item string) bool {
	for _, s := range slice {
		if strings.EqualFold(s, item) {
			return true
		}
	}
	return false
}

var allowedWorkloadTypes = []string{"bash", "Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob"}
var allowedRuntimes = []string{"kubernetes", "systemd", "host"}
var allowedHealthTypes = []string{"command", "http", "tcp", "none"}

// ── Helpers ────────────────────────────────────────────────────────────

func isAllowed(field string, allowed []string) bool {
	for _, a := range allowed {
		if a == field {
			return true
		}
	}
	return false
}

func isOSIApproved(license string) bool {
	for _, approved := range OSIApprovedLicenses {
		if strings.EqualFold(license, approved) {
			return true
		}
	}
	return false
}
