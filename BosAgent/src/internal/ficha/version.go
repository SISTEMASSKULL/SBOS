// Package ficha — Versionado semántico (F11.E.1).
// BOS-REPAIR Plan Maestro v3.
//
// Cada ficha tiene versión MAJOR.MINOR.PATCH según el estándar SemVer 2.0.0.
// El BOS garantiza compatibilidad N-1 MAJOR. La migración entre MAJOR requiere
// script SQL explícito y backup automático antes de ejecutar.
//
// Estrategias de actualización (UpdateStrategy):
//   - hot:     aplica sin downtime (rolling update nativo de K8s)
//   - cold:    drena el nodo, reemplaza, reincorpora
//   - canary:  despliega en 10%→50%→100% con health gate en cada paso
//
// Rollback: restaurar backup + versión N-1. Automático si el health check falla.
//
// Estándares: semver.org 2.0.0, ADR-021 #7 (ACTUALIZANDO), SBOS-019 §14.
package ficha

import (
	"fmt"
	"strconv"
	"strings"
)

// ── Version ────────────────────────────────────────────────────────────

// Version representa una versión semántica MAJOR.MINOR.PATCH.
// Cumple con semver.org 2.0.0.
type Version struct {
	Major int
	Minor int
	Patch int
}

// ParseVersion parsea un string "MAJOR.MINOR.PATCH" a Version.
// Acepta también "MAJOR.MINOR" (patch=0 implícito).
func ParseVersion(s string) (Version, error) {
	if s == "" || s == "latest" {
		return Version{}, fmt.Errorf("versión inválida: %q", s)
	}

	parts := strings.Split(s, ".")
	if len(parts) < 2 || len(parts) > 3 {
		return Version{}, fmt.Errorf("formato inválido: %q (esperado MAJOR.MINOR[.PATCH])", s)
	}

	major, err := strconv.Atoi(parts[0])
	if err != nil || major < 0 {
		return Version{}, fmt.Errorf("MAJOR inválido: %q", parts[0])
	}

	minor, err := strconv.Atoi(parts[1])
	if err != nil || minor < 0 {
		return Version{}, fmt.Errorf("MINOR inválido: %q", parts[1])
	}

	patch := 0
	if len(parts) == 3 {
		patch, err = strconv.Atoi(parts[2])
		if err != nil || patch < 0 {
			return Version{}, fmt.Errorf("PATCH inválido: %q", parts[2])
		}
	}

	return Version{Major: major, Minor: minor, Patch: patch}, nil
}

// String retorna la representación canónica "MAJOR.MINOR.PATCH".
func (v Version) String() string {
	return fmt.Sprintf("%d.%d.%d", v.Major, v.Minor, v.Patch)
}

// IsZero retorna true si la versión es 0.0.0 (no inicializada).
func (v Version) IsZero() bool {
	return v.Major == 0 && v.Minor == 0 && v.Patch == 0
}

// ── Comparación ───────────────────────────────────────────────────────

// Compare retorna:
//
//	-1 si v < other
//	 0 si v == other
//	+1 si v > other
func (v Version) Compare(other Version) int {
	if v.Major != other.Major {
		return sign(v.Major - other.Major)
	}
	if v.Minor != other.Minor {
		return sign(v.Minor - other.Minor)
	}
	return sign(v.Patch - other.Patch)
}

// LessThan retorna true si v es estrictamente menor que other.
func (v Version) LessThan(other Version) bool {
	return v.Compare(other) < 0
}

// GreaterThan retorna true si v es estrictamente mayor que other.
func (v Version) GreaterThan(other Version) bool {
	return v.Compare(other) > 0
}

// Equals retorna true si las versiones son idénticas.
func (v Version) Equals(other Version) bool {
	return v.Compare(other) == 0
}

// ── Compatibilidad ────────────────────────────────────────────────────

// IsCompatibleUpgrade verifica si la actualización de current a target es segura.
// Reglas:
//   - Mismo MAJOR: siempre compatible (MINOR/PATCH upgrade)
//   - +1 MAJOR: requiere script de migración explícito, backup obligatorio
//   - +2 MAJOR o más: BLOQUEADO — error explícito (F11.8)
//   - Downgrade: solo permitido como rollback a N-1 (no a N-2)
func IsCompatibleUpgrade(current, target Version) error {
	if target.LessThan(current) {
		// Downgrade — solo N-1
		if current.Major-target.Major > 1 {
			return fmt.Errorf("rollback bloqueado: de %s a %s (máximo N-1 MAJOR permitido)", current, target)
		}
		if current.Major == target.Major && current.Minor-target.Minor > 1 {
			return fmt.Errorf("rollback bloqueado: de %s a %s (máximo N-1 MINOR permitido)", current, target)
		}
		return nil // N-1 downgrade permitido (rollback)
	}

	// Upgrade
	majorDiff := target.Major - current.Major

	switch {
	case majorDiff == 0:
		return nil // MINOR/PATCH upgrade — siempre seguro
	case majorDiff == 1:
		return fmt.Errorf("migración MAJOR %d→%d requiere script SQL y backup obligatorio", current.Major, target.Major)
	default:
		return fmt.Errorf("actualización bloqueada: de %s a %s (máximo N-1 MAJOR). Migre secuencialmente", current, target)
	}
}

// NeedsMigration retorna true si el upgrade requiere script de migración (MAJOR bump).
func NeedsMigration(current, target Version) bool {
	return target.Major > current.Major
}

// NeedsBackup retorna true si el upgrade requiere backup (MAJOR bump o downgrade).
func NeedsBackup(current, target Version) bool {
	return target.Major != current.Major
}

// ── Bump helpers ──────────────────────────────────────────────────────

// BumpMajor retorna la versión con MAJOR incrementado (MINOR y PATCH a 0).
func (v Version) BumpMajor() Version {
	return Version{Major: v.Major + 1, Minor: 0, Patch: 0}
}

// BumpMinor retorna la versión con MINOR incrementado (PATCH a 0).
func (v Version) BumpMinor() Version {
	return Version{Major: v.Major, Minor: v.Minor + 1, Patch: 0}
}

// BumpPatch retorna la versión con PATCH incrementado.
func (v Version) BumpPatch() Version {
	return Version{Major: v.Major, Minor: v.Minor, Patch: v.Patch + 1}
}

// NMinusOne retorna la versión N-1 MAJOR (0.0.0 si ya es 0.x.x).
func (v Version) NMinusOne() Version {
	if v.Major == 0 {
		return Version{}
	}
	return Version{Major: v.Major - 1, Minor: 0, Patch: 0}
}

// ── Estrategia de actualización ───────────────────────────────────────

// UpdateStrategy define cómo se aplica una actualización a una ficha.
type UpdateStrategy string

const (
	// StrategyHot: rolling update sin downtime (K8s nativo).
	// El Deployment/StatefulSet se actualiza pod a pod.
	StrategyHot UpdateStrategy = "hot"

	// StrategyCold: drain del nodo, reemplazo total, reincorporación.
	// Para fichas que no soportan actualización en caliente.
	StrategyCold UpdateStrategy = "cold"

	// StrategyCanary: despliegue progresivo 10%→50%→100%.
	// Con health gate en cada paso. Si health falla → rollback automático.
	StrategyCanary UpdateStrategy = "canary"
)

// ValidStrategies lista las estrategias de actualización válidas.
func ValidStrategies() []UpdateStrategy {
	return []UpdateStrategy{StrategyHot, StrategyCold, StrategyCanary}
}

// IsValidStrategy verifica si la estrategia es válida.
func IsValidStrategy(s string) bool {
	switch UpdateStrategy(s) {
	case StrategyHot, StrategyCold, StrategyCanary:
		return true
	}
	return false
}

// DefaultUpdateStrategy retorna la estrategia por defecto según el tipo de workload.
func DefaultUpdateStrategy(workloadType string) UpdateStrategy {
	switch workloadType {
	case "StatefulSet":
		return StrategyCold // DBs requieren drain + reemplazo
	case "Deployment":
		return StrategyHot // stateless → rolling update seguro
	case "DaemonSet":
		return StrategyHot
	case "bash":
		return StrategyCold // scripts necesitan reemplazo completo
	default:
		return StrategyHot
	}
}

// CanarySteps retorna los porcentajes de tráfico para estrategia canary.
func CanarySteps() []int {
	return []int{10, 50, 100}
}

// ── Helpers ────────────────────────────────────────────────────────────

func sign(n int) int {
	if n < 0 {
		return -1
	}
	if n > 0 {
		return 1
	}
	return 0
}

// VersionRange representa un rango de versiones compatibles.
type VersionRange struct {
	Min Version
	Max Version
}

// Contains verifica si una versión está dentro del rango.
func (r VersionRange) Contains(v Version) bool {
	return !v.LessThan(r.Min) && !v.GreaterThan(r.Max)
}

// NMinusOneRange retorna el rango de versiones compatibles para N-1.
func NMinusOneRange(current Version) VersionRange {
	return VersionRange{
		Min: current.NMinusOne(),
		Max: current,
	}
}
