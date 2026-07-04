package release

import (
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"strings"
)

// SignedRelease envuelve ReleaseInfo con la firma Ed25519 del SKULL Release Server.
//
// Thread safety: inmutable tras deserialización — seguro para lectura concurrente.
// Campo Signature: base64 de la firma Ed25519 sobre el JSON canónico de Release.
type SignedRelease struct {
	Release   ReleaseInfo `json:"release"`
	Signature string      `json:"signature"` // base64-encoded Ed25519 signature
}

// Verifier verifica firmas Ed25519 y checksums SHA-256 de releases del SKULL Release Plane.
//
// Thread safety: seguro para uso concurrente — la clave pública es inmutable tras carga.
// La clave pública se carga de /etc/bos/skull-release-pubkey.pem (base64, 32 bytes Ed25519).
// Si no existe, keyLoaded=false y VerifySignature retornará error — no panic.
type Verifier struct {
	publicKey ed25519.PublicKey
	keyLoaded bool
}

// NewVerifier crea un verificador de releases cargando la clave pública SKULL si está disponible.
//
// Callers conocidos:
//   - internal/release/manager.go:NewManager — instanciado en el constructor del Manager.
func NewVerifier() *Verifier {
	v := &Verifier{}
	v.loadPublicKey()
	return v
}

// loadPublicKey carga la clave pública Ed25519 de SKULL desde disco.
func (v *Verifier) loadPublicKey() {
	paths := []string{
		"/etc/bos/skull-release-pubkey.pem",
		"/etc/bos/skull-release-pubkey",
	}

	for _, p := range paths {
		data, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		// Limpiar whitespace y decodificar base64
		clean := strings.TrimSpace(string(data))
		key, err := base64.StdEncoding.DecodeString(clean)
		if err != nil {
			continue
		}
		if len(key) != ed25519.PublicKeySize {
			continue
		}
		v.publicKey = ed25519.PublicKey(key)
		v.keyLoaded = true
		return
	}
}

// HasKey reporta si se cargó correctamente una clave pública Ed25519 válida.
// Si retorna false, VerifySignature siempre fallará con error descriptivo.
func (v *Verifier) HasKey() bool { return v.keyLoaded }

// VerifySignature verifica la firma Ed25519 de un release firmado por el SKULL Release Server.
//
// Recibe:
//   - signed: *SignedRelease — release con firma base64.
//
// Retorna: nil si la firma es válida, error descriptivo si no lo es o si no hay clave cargada.
//
// Efectos secundarios: ninguno — solo lectura y criptografía.
//
// Estándares: P5 (Release Plane pull-only + Ed25519), SBOS-041 Release Plane.
func (v *Verifier) VerifySignature(signed *SignedRelease) error {
	if !v.keyLoaded {
		return fmt.Errorf("release: no SKULL public key loaded — cannot verify signature")
	}

	// Serializar release a JSON canónico
	payload, err := json.Marshal(signed.Release)
	if err != nil {
		return fmt.Errorf("release: cannot marshal release: %w", err)
	}

	// Calcular SHA-256 del payload
	hash := sha256.Sum256(payload)

	// Decodificar firma
	sig, err := base64.StdEncoding.DecodeString(signed.Signature)
	if err != nil {
		return fmt.Errorf("release: invalid signature encoding: %w", err)
	}

	// Verificar firma Ed25519
	if !ed25519.Verify(v.publicKey, hash[:], sig) {
		return fmt.Errorf("release: signature verification FAILED — release may be tampered")
	}

	return nil
}

// VerifyChecksum verifica que los datos descargados coincidan con el checksum SHA-256 esperado.
//
// Recibe:
//   - data: []byte — contenido del paquete descargado.
//   - expected: string — checksum esperado. Acepta "sha256:<hex>" o "<hex>" puro. Vacío = sin verificación.
//
// Retorna: nil si coincide, error con detalle del mismatch si no.
func (v *Verifier) VerifyChecksum(data []byte, expected string) error {
	if expected == "" {
		return nil // sin checksum → sin verificación
	}

	hash := sha256.Sum256(data)
	actual := fmt.Sprintf("sha256:%x", hash)

	if !strings.EqualFold(actual, expected) && !strings.EqualFold(fmt.Sprintf("%x", hash), expected) {
		return fmt.Errorf("release: checksum mismatch\n  expected: %s\n  actual:   sha256:%x", expected, hash)
	}

	return nil
}

// FilterChannel retorna solo los releases que coincidan con el canal especificado.
// Canal "*" retorna todos los releases sin filtrar.
func FilterChannel(releases []ReleaseInfo, channel string) []ReleaseInfo {
	if channel == "*" {
		return releases
	}
	var filtered []ReleaseInfo
	for _, r := range releases {
		if r.Channel == channel {
			filtered = append(filtered, r)
		}
	}
	return filtered
}

// IsNewerVersion verifica si candidate es semánticamente más nuevo que current.
// Implementación simplificada (comparación de strings). Iteración 2 usará semver.
func IsNewerVersion(current, candidate string) bool {
	return current != candidate
}

// ── Channel tools ──────────────────────────────────────────────────────

// ValidChannels son los canales de release aceptados por el Release Plane.
var ValidChannels = []string{"canary", "early", "stable"}

// IsValidChannel reporta si un nombre de canal es válido (canary|early|stable).
func IsValidChannel(ch string) bool {
	for _, v := range ValidChannels {
		if ch == v {
			return true
		}
	}
	return false
}

// DefaultChannel retorna "stable" — el canal seguro por defecto para instalaciones de producción.
func DefaultChannel() string { return "stable" }
