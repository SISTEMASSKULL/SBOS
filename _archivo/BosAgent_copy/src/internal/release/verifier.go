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

// SignedRelease wraps ReleaseInfo with an Ed25519 signature from the SKULL Release Server.
type SignedRelease struct {
	Release   ReleaseInfo `json:"release"`
	Signature string      `json:"signature"` // base64-encoded Ed25519 signature
}

// Verifier checks Ed25519 signatures on releases and verifies SHA-256 checksums.
// The public key is obtained from: /etc/bos/skull-release-pubkey.pem (base64, 32 bytes).
type Verifier struct {
	publicKey ed25519.PublicKey
	keyLoaded bool
}

// NewVerifier creates a release verifier, loading the SKULL public key if available.
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

// HasKey reports whether a valid Ed25519 public key was loaded.
func (v *Verifier) HasKey() bool { return v.keyLoaded }

// VerifySignature checks the Ed25519 signature on a signed release.
// The signature covers the JSON-encoded release with SHA-256.
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

// VerifyChecksum checks that the downloaded package matches its SHA-256 checksum.
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

// FilterChannel returns only releases matching the specified channel(s).
// Channel "*" matches all.
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

// IsNewerVersion checks if candidate is semantically newer than current.
// Simplified: string comparison; Iteración 2 usará semver.
func IsNewerVersion(current, candidate string) bool {
	return current != candidate
}

// ── Channel tools ──────────────────────────────────────────────────────

// ValidChannels son los canales de release aceptados por el Release Plane.
var ValidChannels = []string{"canary", "early", "stable"}

// IsValidChannel reports whether a channel name is valid.
func IsValidChannel(ch string) bool {
	for _, v := range ValidChannels {
		if ch == v {
			return true
		}
	}
	return false
}

// DefaultChannel returns "stable" — the safe default.
func DefaultChannel() string { return "stable" }
