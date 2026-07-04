// Package ficha — Timeouts configurables por tipo de ficha (F11.G.3).
// BOS-REPAIR Plan Maestro v3.
//
// Cada operación del ciclo de vida tiene un timeout configurable.
// Los timeouts pueden declararse en manifest.yml → sección timeouts:,
// o se usa el default según el tipo de workload (K8s, DB, daemon).
//
// Jerarquía de resolución:
//  1. Valor explícito en manifest.yml (timeouts.install, timeouts.update, etc.)
//  2. Default por tipo de workload (StatefulSet=10min, Deployment=5min, bash=2min)
//  3. Timeout global de seguridad (install=30min, update=15min, repair=10min, remove=10min)
//
// Los timeouts NUNCA pueden exceder el máximo global de seguridad.
// Valores negativos o cero usan el default del tipo.
//
// Estándares: ADR-021 (timeouts por estado), SBOS-019 §manifest.timeouts.
package ficha

import (
	"fmt"
	"strings"
	"time"
)

// ── Tipos ────────────────────────────────────────────────────────────

// TimeoutConfig define los timeouts por operación para una ficha.
// Puede ser poblado desde manifest.yml o generado con defaults.
type TimeoutConfig struct {
	Install time.Duration `json:"install" yaml:"install"` // timeout de instalación (5 fases)
	Update  time.Duration `json:"update" yaml:"update"`   // timeout de actualización
	Repair  time.Duration `json:"repair" yaml:"repair"`   // timeout de reparación
	Remove  time.Duration `json:"remove" yaml:"remove"`   // timeout de eliminación

	// Timeouts por fase individual (opcionales, sobreescriben el global de install)
	PreInstall  time.Duration `json:"pre_install,omitempty" yaml:"pre_install,omitempty"`
	PostInstall time.Duration `json:"post_install,omitempty" yaml:"post_install,omitempty"`
	Verify      time.Duration `json:"verify,omitempty" yaml:"verify,omitempty"`
	Commit      time.Duration `json:"commit,omitempty" yaml:"commit,omitempty"`
}

// ── Valores globales de seguridad ────────────────────────────────────

// GlobalTimeoutLimits define los límites máximos absolutos por operación.
// Ningún timeout declarado en manifest puede exceder estos valores.
func GlobalTimeoutLimits() TimeoutConfig {
	return TimeoutConfig{
		Install:      30 * time.Minute,
		Update:       15 * time.Minute,
		Repair:       10 * time.Minute,
		Remove:       10 * time.Minute,
		PreInstall:   5 * time.Minute,
		PostInstall:  5 * time.Minute,
		Verify:       5 * time.Minute,
		Commit:       2 * time.Minute,
	}
}

// ── Defaults por tipo de workload ────────────────────────────────────

// DefaultTimeoutFor retorna los timeouts por defecto según el tipo de workload.
func DefaultTimeoutFor(workloadType string) TimeoutConfig {
	switch workloadType {
	case "StatefulSet":
		// DB: más tiempo por migraciones, WAL, volumen persistente
		return TimeoutConfig{
			Install:      10 * time.Minute,
			Update:       5 * time.Minute,
			Repair:       10 * time.Minute,
			Remove:       5 * time.Minute,
			PreInstall:   3 * time.Minute,
			PostInstall:  3 * time.Minute,
			Verify:       2 * time.Minute,
			Commit:       1 * time.Minute,
		}
	case "Deployment", "DaemonSet":
		// K8s estándar
		return TimeoutConfig{
			Install:      5 * time.Minute,
			Update:       3 * time.Minute,
			Repair:       5 * time.Minute,
			Remove:       3 * time.Minute,
			PreInstall:   2 * time.Minute,
			PostInstall:  2 * time.Minute,
			Verify:       2 * time.Minute,
			Commit:       1 * time.Minute,
		}
	case "bash", "systemd":
		// Scripts y daemons de host
		return TimeoutConfig{
			Install:      2 * time.Minute,
			Update:       1 * time.Minute,
			Repair:       2 * time.Minute,
			Remove:       1 * time.Minute,
			PreInstall:   1 * time.Minute,
			PostInstall:  1 * time.Minute,
			Verify:       1 * time.Minute,
			Commit:       30 * time.Second,
		}
	default:
		// Desconocido: usar el límite más seguro (K8s estándar)
		return TimeoutConfig{
			Install:      5 * time.Minute,
			Update:       3 * time.Minute,
			Repair:       5 * time.Minute,
			Remove:       3 * time.Minute,
			PreInstall:   2 * time.Minute,
			PostInstall:  2 * time.Minute,
			Verify:       2 * time.Minute,
			Commit:       1 * time.Minute,
		}
	}
}

// ── Resolvedor ────────────────────────────────────────────────────────

// ResolveTimeout combina timeouts de manifiesto con defaults del tipo.
// Reglas:
//  1. Si el valor del manifiesto es > 0 y <= límite global → usar valor del manifiesto
//  2. Si es 0 o negativo → usar default del tipo
//  3. Si excede el límite global → usar el límite global (seguridad)
func ResolveTimeout(manifest TimeoutConfig, workloadType string) TimeoutConfig {
	defaults := DefaultTimeoutFor(workloadType)
	limits := GlobalTimeoutLimits()

	return TimeoutConfig{
		Install:      resolveField(manifest.Install, defaults.Install, limits.Install),
		Update:       resolveField(manifest.Update, defaults.Update, limits.Update),
		Repair:       resolveField(manifest.Repair, defaults.Repair, limits.Repair),
		Remove:       resolveField(manifest.Remove, defaults.Remove, limits.Remove),
		PreInstall:   resolveField(manifest.PreInstall, defaults.PreInstall, limits.PreInstall),
		PostInstall:  resolveField(manifest.PostInstall, defaults.PostInstall, limits.PostInstall),
		Verify:       resolveField(manifest.Verify, defaults.Verify, limits.Verify),
		Commit:       resolveField(manifest.Commit, defaults.Commit, limits.Commit),
	}
}

// resolveField aplica la regla de resolución para un campo individual.
func resolveField(manifestVal, defaultVal, limitVal time.Duration) time.Duration {
	switch {
	case manifestVal <= 0:
		return defaultVal // no declarado o inválido → default del tipo
	case manifestVal > limitVal:
		return limitVal // excede el máximo → limitar por seguridad
	default:
		return manifestVal // valor válido dentro de límites
	}
}

// ── Parseo desde manifiesto ──────────────────────────────────────────

// ParseTimeoutsFromManifest extrae la configuración de timeouts de un manifest.yml.
// Acepta el contenido crudo del manifiesto (sección timeouts:).
func ParseTimeoutsFromManifest(manifestContent string) TimeoutConfig {
	cfg := TimeoutConfig{}

	for _, line := range strings.Split(manifestContent, "\n") {
		trimmed := strings.TrimSpace(line)

		// Solo procesar líneas con key: value
		parts := strings.SplitN(trimmed, ":", 2)
		if len(parts) < 2 {
			continue
		}

		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		// Remover comillas y comentarios inline
		value = strings.Trim(value, ` "'`)
		if idx := strings.Index(value, "#"); idx >= 0 {
			value = strings.TrimSpace(value[:idx])
		}

		d, err := time.ParseDuration(value)
		if err != nil {
			// Intentar parsear como minutos (ej: "5m", "10m")
			if strings.HasSuffix(value, "m") {
				if minutes, err2 := parseMinutes(value); err2 == nil {
					d = time.Duration(minutes) * time.Minute
				} else {
					continue // no se pudo parsear
				}
			} else {
				continue
			}
		}

		switch key {
		case "install":
			cfg.Install = d
		case "update":
			cfg.Update = d
		case "repair":
			cfg.Repair = d
		case "remove":
			cfg.Remove = d
		case "pre_install":
			cfg.PreInstall = d
		case "post_install":
			cfg.PostInstall = d
		case "verify":
			cfg.Verify = d
		case "commit":
			cfg.Commit = d
		}
	}

	return cfg
}

// parseMinutes parsea un string como "5m", "30m" a minutos.
func parseMinutes(s string) (int, error) {
	s = strings.TrimSuffix(s, "m")
	var minutes int
	_, err := fmt.Sscanf(s, "%d", &minutes)
	return minutes, err
}

// ── Helpers ────────────────────────────────────────────────────────────

// IsEmpty retorna true si ningún timeout está configurado (todo cero).
func (tc TimeoutConfig) IsEmpty() bool {
	return tc.Install == 0 && tc.Update == 0 && tc.Repair == 0 && tc.Remove == 0 &&
		tc.PreInstall == 0 && tc.PostInstall == 0 && tc.Verify == 0 && tc.Commit == 0
}

// DefaultUnknownOpTimeout es el timeout por defecto para operaciones no reconocidas
// por TimeoutConfig.ForOp(). Es un valor conservador de 5 minutos — distinto del
// límite global de seguridad de 30 min que usa Lifecycle.TimeoutFor().
const DefaultUnknownOpTimeout = 5 * time.Minute

// ForOp retorna el timeout para una operación específica del ciclo de vida.
// Si la operación es desconocida, retorna DefaultUnknownOpTimeout (5 min).
func (tc TimeoutConfig) ForOp(op LifecycleOp) time.Duration {
	switch op {
	case OpInstall:
		return tc.Install
	case OpUpdate:
		return tc.Update
	case OpRepair:
		return tc.Repair
	case OpRemove:
		return tc.Remove
	default:
		return DefaultUnknownOpTimeout
	}
}

// Validate verifica que los timeouts estén dentro de los límites globales.
// Retorna una lista de warnings (no errores — los límites se aplican automáticamente).
func (tc TimeoutConfig) Validate() []string {
	limits := GlobalTimeoutLimits()
	var warnings []string

	check := func(name string, val, limit time.Duration) {
		if val > limit {
			warnings = append(warnings, fmt.Sprintf("%s: %v excede límite global %v — se usará %v",
				name, val, limit, limit))
		}
	}

	check("install", tc.Install, limits.Install)
	check("update", tc.Update, limits.Update)
	check("repair", tc.Repair, limits.Repair)
	check("remove", tc.Remove, limits.Remove)

	return warnings
}
