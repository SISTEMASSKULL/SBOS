package security

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"sync"
	"time"
)

// BauthRBACConfig controls the bridge to BauthAgent.
type BauthRBACConfig struct {
	Enabled    bool
	SocketPath string
	Timeout    time.Duration
	Fallback   RBACProvider // FileRBAC instance used when bauth is disabled or unreachable
}

// BauthRBAC implements RBACProvider and IdentityProvider with BauthAgent bridge.
// When Enabled and BauthAgent is reachable, authorization queries go through
// the Unix socket. When disabled or unreachable, all operations fall back to FileRBAC.
// Identity management (SetRole, RemoveUser, etc.) always delegates to FileRBAC
// until BauthAgent exposes user management endpoints.
type BauthRBAC struct {
	cfg      BauthRBACConfig
	fallback *FileRBAC
	mu       sync.Mutex
}

// NewBauthRBAC creates a new bridge. The Fallback must not be nil.
func NewBauthRBAC(cfg BauthRBACConfig) *BauthRBAC {
	fb, ok := cfg.Fallback.(*FileRBAC)
	if !ok {
		// If Fallback is not a FileRBAC, create a fresh one as ultimate fallback.
		fb, _ = NewFileRBAC("/etc/bos/rbac/roles.json")
	}
	return &BauthRBAC{cfg: cfg, fallback: fb}
}

// CanExecute checks authorization via BauthAgent or falls back to FileRBAC.
func (b *BauthRBAC) CanExecute(user, cmd string) error {
	if !b.cfg.Enabled {
		return b.fallback.CanExecute(user, cmd)
	}
	resp, err := b.queryBauth(user, cmd)
	if err != nil {
		return b.fallback.CanExecute(user, cmd)
	}
	if resp.Granted {
		return nil
	}
	if resp.Reason != "" {
		return fmt.Errorf("bauth: %s", resp.Reason)
	}
	return fmt.Errorf("bauth: denied (%s)", resp.ErrorCode)
}

// GetRole returns the role for user. Always delegates to FileRBAC for now.
func (b *BauthRBAC) GetRole(user string) string {
	return b.fallback.GetRole(user)
}

// SetRole assigns a role. Delegates to FileRBAC.
func (b *BauthRBAC) SetRole(user, role string) error {
	return b.fallback.SetRole(user, role)
}

// RemoveUser deletes a user. Delegates to FileRBAC.
func (b *BauthRBAC) RemoveUser(user string) error {
	return b.fallback.RemoveUser(user)
}

// ListUsers returns all users. Delegates to FileRBAC.
func (b *BauthRBAC) ListUsers() (map[string]string, error) {
	return b.fallback.ListUsers()
}

// ListRoles returns all roles. Delegates to FileRBAC.
func (b *BauthRBAC) ListRoles() ([]string, error) {
	return b.fallback.ListRoles()
}

// ValidateUser checks if user exists. Delegates to FileRBAC.
func (b *BauthRBAC) ValidateUser(user string) error {
	return b.fallback.ValidateUser(user)
}

// ── BauthAgent Unix Socket Protocol ──────────────────────────────────────
// Wire format: 4-byte big-endian length prefix + JSON payload.
// Compatible with BauthAgent server/socket.go and server/authquery.go.

const maxBauthFrameSize = 65536

// bauthQuery matches BauthAgent server/authquery.go AuthQuery.
type bauthQuery struct {
	UserID    string `json:"user_id"`
	NodeID    string `json:"node_id"`
	QueryType string `json:"query_type"`
	Zone      string `json:"zone,omitempty"`
	Verb      string `json:"verb,omitempty"`
	RequestID string `json:"request_id"`
}

// bauthResponse matches BauthAgent server/authquery.go AuthResponse.
type bauthResponse struct {
	RequestID  string `json:"request_id"`
	Granted    bool   `json:"granted"`
	Reason     string `json:"reason,omitempty"`
	ErrorCode  string `json:"error_code,omitempty"`
	TTLSeconds int    `json:"ttl_seconds"`
}

// queryBauth sends an authorization query to BauthAgent via Unix socket.
func (b *BauthRBAC) queryBauth(userID, verb string) (*bauthResponse, error) {
	b.mu.Lock()
	defer b.mu.Unlock()

	socketPath := b.cfg.SocketPath
	if socketPath == "" {
		socketPath = "/run/bos/bauth.sock"
	}
	timeout := b.cfg.Timeout
	if timeout == 0 {
		timeout = 2 * time.Second
	}

	conn, err := net.DialTimeout("unix", socketPath, timeout)
	if err != nil {
		return nil, fmt.Errorf("bauth socket dial %s: %w", socketPath, err)
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(timeout))

	q := bauthQuery{
		UserID:    userID,
		NodeID:    "bos",
		QueryType: "zone_verb",
		Verb:      verb,
		RequestID: fmt.Sprintf("bos-%d", time.Now().UnixNano()),
	}

	payload, err := json.Marshal(q)
	if err != nil {
		return nil, fmt.Errorf("bauth marshal query: %w", err)
	}
	if len(payload) > maxBauthFrameSize {
		return nil, fmt.Errorf("bauth query too large: %d bytes", len(payload))
	}

	// Write frame: 4-byte big-endian length + payload
	header := make([]byte, 4)
	binary.BigEndian.PutUint32(header, uint32(len(payload)))
	if _, err := conn.Write(header); err != nil {
		return nil, fmt.Errorf("bauth write header: %w", err)
	}
	if _, err := conn.Write(payload); err != nil {
		return nil, fmt.Errorf("bauth write payload: %w", err)
	}

	// Read response frame
	var respHeader [4]byte
	if _, err := io.ReadFull(conn, respHeader[:]); err != nil {
		return nil, fmt.Errorf("bauth read header: %w", err)
	}
	length := binary.BigEndian.Uint32(respHeader[:])
	if length > maxBauthFrameSize {
		return nil, fmt.Errorf("bauth response too large: %d bytes", length)
	}
	data := make([]byte, length)
	if _, err := io.ReadFull(conn, data); err != nil {
		return nil, fmt.Errorf("bauth read payload: %w", err)
	}

	var resp bauthResponse
	if err := json.Unmarshal(data, &resp); err != nil {
		return nil, fmt.Errorf("bauth unmarshal response: %w", err)
	}

	return &resp, nil
}
