// Package sanitize — validación y sanitización de entradas (SAN-01..SAN-12).
//
// Centraliza las defensas contra injection, path traversal y fuga de datos en logs.
// Cero dependencias externas. Todas las funciones son puras y thread-safe.
//
// Reglas implementadas:
//   SAN-01  UUID(s)              — valida UUIDv4 canónico
//   SAN-02  Slug(s)              — slug alfanumérico lowercase seguro
//   SAN-03  IPAddr(s)            — IP v4 o v6 válida
//   SAN-04  FilePath(s)          — ruta sin path traversal
//   SAN-05  Email(s)             — dirección RFC 5321 válida
//   SAN-06  JSONPayload(d, max)  — JSON válido dentro de límite de tamaño
//   SAN-07  LogCtxID(s)          — ctx_id seguro para logs (8 chars + hash)
//   SAN-08  TruncateField        — truncar campo a longitud máxima
//   SAN-09  CtxIDParam(s)        — ctx_id válido como parámetro RPC
//   SAN-10  HeaderValue(s)       — cabecera HTTP sin CRLF injection
//   SAN-11  CrossTenantSlug      — tenant_id recurso == tenant_id sesión
//   SAN-12  CrossTenantK8sName   — nombre K8s pertenece al tenant
//
// Referencia: 1.04_MANUAL-IAM-INSTALLER-SEGURIDAD.md §SAN
package sanitize

import (
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/mail"
	"path/filepath"
	"regexp"
	"strings"
)

var (
	// UUIDv4: 8-4-4-4-12 hex, versión 4, variante 8/9/a/b
	reUUID = regexp.MustCompile(`(?i)^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`)

	// Slug: lowercase alfanumérico + guión/guión bajo, 1-64 chars, empieza con alnum
	reSlug = regexp.MustCompile(`^[a-z0-9][a-z0-9\-_]{0,63}$`)
)

// UUID valida que s sea un UUIDv4 canónico (SAN-01).
// Acepta mayúsculas y minúsculas.
func UUID(s string) bool {
	return reUUID.MatchString(s)
}

// Slug valida que s sea un slug seguro (SAN-02).
// Solo lowercase alfanumérico, guión (-) y guión bajo (_). Máx 64 chars.
func Slug(s string) bool {
	return reSlug.MatchString(s)
}

// IPAddr valida que s sea una dirección IP v4 o v6 válida (SAN-03).
func IPAddr(s string) bool {
	return net.ParseIP(s) != nil
}

// FilePath valida y limpia una ruta de archivo previniendo path traversal (SAN-04).
// Rechaza rutas con byte nulo o con componentes ".." explícitos (antes de limpiar).
// Retorna la ruta canonicalizada vía filepath.Clean.
func FilePath(s string) (string, error) {
	if strings.Contains(s, "\x00") {
		return "", fmt.Errorf("sanitize.FilePath: ruta con byte nulo: %q", s)
	}
	// Detectar componentes ".." antes de que filepath.Clean los resuelva.
	// Se chequea la intención del caller, no el resultado final.
	for _, part := range strings.Split(filepath.ToSlash(s), "/") {
		if part == ".." {
			return "", fmt.Errorf("sanitize.FilePath: path traversal detectado: %q", s)
		}
	}
	return filepath.Clean(s), nil
}

// LogCtxID retorna una versión segura de ctx_id para logs (SAN-07).
// Expone solo los primeros 8 caracteres + 3 bytes del SHA256 — nunca el ID completo.
// Esto permite correlacionar logs sin exponer el token completo.
func LogCtxID(ctxID string) string {
	if ctxID == "" {
		return "(vacío)"
	}
	if len(ctxID) <= 8 {
		return ctxID
	}
	h := sha256.Sum256([]byte(ctxID))
	return ctxID[:8] + "…" + fmt.Sprintf("%x", h[:3])
}

// TruncateField trunca s a maxLen runes (SAN-08).
// Usa runes para manejar correctamente caracteres Unicode multibyte.
func TruncateField(s string, maxLen int) string {
	if maxLen <= 0 {
		return ""
	}
	runes := []rune(s)
	if len(runes) <= maxLen {
		return s
	}
	return string(runes[:maxLen])
}

// CtxIDParam valida que s sea un ctx_id aceptable como parámetro RPC (SAN-09).
// Un ctx_id válido es un UUIDv4 no vacío.
func CtxIDParam(s string) bool {
	return s != "" && UUID(s)
}

// TenantIDParam valida que s sea un tenant_id seguro como parámetro RPC.
// Los tenant_id siguen el formato slug para evitar injection en namespaces K8s.
func TenantIDParam(s string) bool {
	return s != "" && Slug(s)
}

// Email valida que s sea una dirección de email RFC 5321 válida (SAN-05).
// Máximo 254 caracteres (RFC 5321 §4.5.3.1.3).
func Email(s string) bool {
	if s == "" || len(s) > 254 {
		return false
	}
	_, err := mail.ParseAddress(s)
	return err == nil
}

// JSONPayload valida que data sea JSON canónico y no exceda maxBytes (SAN-06).
// Rechaza payloads vacíos, mal formados o que superen el límite.
func JSONPayload(data []byte, maxBytes int) error {
	if len(data) == 0 {
		return errors.New("sanitize.JSONPayload: payload vacío")
	}
	if len(data) > maxBytes {
		return fmt.Errorf("sanitize.JSONPayload: payload excede límite de %d bytes (tamaño: %d)", maxBytes, len(data))
	}
	if !json.Valid(data) {
		return errors.New("sanitize.JSONPayload: JSON inválido")
	}
	return nil
}

// HeaderValue sanitiza un valor de cabecera HTTP eliminando CRLF injection (SAN-10).
// Rechaza \r, \n y bytes nulos. Retorna el valor con espacios extremos recortados.
func HeaderValue(s string) (string, error) {
	for i, r := range s {
		if r == '\r' || r == '\n' || r == 0 {
			return "", fmt.Errorf("sanitize.HeaderValue: carácter de control en posición %d (U+%04X)", i, r)
		}
	}
	return strings.TrimSpace(s), nil
}

// CrossTenantSlug verifica que el tenant del recurso coincide con el de la sesión (SAN-11).
// Previene acceso cross-tenant cuando tenant_id de la sesión no coincide con el del recurso.
func CrossTenantSlug(tenantSesion, tenantRecurso string) error {
	if tenantSesion == "" || tenantRecurso == "" {
		return errors.New("sanitize.CrossTenantSlug: tenant_id vacío")
	}
	if tenantSesion != tenantRecurso {
		return fmt.Errorf("sanitize.CrossTenantSlug: tenant %q no tiene acceso a recurso de tenant %q", tenantSesion, tenantRecurso)
	}
	return nil
}

// CrossTenantK8sName verifica que un nombre de recurso K8s pertenece al tenant (SAN-12).
// Los recursos K8s de un tenant siguen el patrón: <tenantID> o <tenantID>-<sufijo>.
// Esto previene que un ctx_id de tenant A acceda a recursos K8s del tenant B.
func CrossTenantK8sName(tenantID, resourceName string) error {
	if tenantID == "" || resourceName == "" {
		return errors.New("sanitize.CrossTenantK8sName: tenantID o resourceName vacío")
	}
	if resourceName != tenantID && !strings.HasPrefix(resourceName, tenantID+"-") {
		return fmt.Errorf("sanitize.CrossTenantK8sName: recurso K8s %q no pertenece al tenant %q", resourceName, tenantID)
	}
	return nil
}
