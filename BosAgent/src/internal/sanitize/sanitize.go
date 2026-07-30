// Package sanitize — validación y sanitización de entradas (SAN-01..SAN-08).
//
// Centraliza las defensas contra injection, path traversal y fuga de datos en logs.
// Cero dependencias externas. Todas las funciones son puras y thread-safe.
//
// Reglas implementadas:
//   SAN-01  UUID(s)         — valida UUIDv4 canónico
//   SAN-02  Slug(s)         — slug alfanumérico lowercase seguro
//   SAN-03  IPAddr(s)       — IP v4 o v6 válida
//   SAN-04  FilePath(s)     — ruta sin path traversal
//   SAN-07  LogCtxID(s)     — ctx_id seguro para logs (8 chars + hash)
//   SAN-08  TruncateField   — truncar campo a longitud máxima
//   SAN-09  CtxIDParam(s)   — ctx_id válido como parámetro RPC
//
// Referencia: 1.04_MANUAL-IAM-INSTALLER-SEGURIDAD.md §SAN
package sanitize

import (
	"crypto/sha256"
	"fmt"
	"net"
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
