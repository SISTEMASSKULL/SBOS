// Package release manages pull-only version checks against the SKULL Release Plane.
// Principle P5: bos pulls releases, never receives pushes.
package release

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"log/slog"
)

// ReleaseInfo describes an available release version.
type ReleaseInfo struct {
	Ficha       string    `json:"ficha"`
	Version     string    `json:"version"`
	Channel     string    `json:"channel"`
	ReleaseDate time.Time `json:"release_date"`
	MinBosVer   string    `json:"min_bos_version"`
	Checksum    string    `json:"checksum"`
	Breaking    bool      `json:"breaking"`
	Notes       string    `json:"notes"`
}

// OfflineBackoff defines retry intervals when release server is unreachable.
var OfflineBackoff = []time.Duration{
	5 * time.Minute,
	30 * time.Minute,
	2 * time.Hour,
	6 * time.Hour,
}

// Manager checks the SKULL Release Plane for new versions.
// P5: pull-only — never receives pushes.
type Manager struct {
	mu            sync.RWMutex
	baseURL       string
	channel       string
	client        *http.Client
	cache         map[string][]ReleaseInfo
	cacheTTL      time.Time
	logger        *slog.Logger
	offline       bool
	offlineSince  time.Time
	offlineRetryN int
	nextRetryAt   time.Time
}

// NewManager creates a release manager.
func NewManager(baseURL, channel string, logger *slog.Logger) *Manager {
	return &Manager{
		baseURL:  baseURL,
		channel:  channel,
		client:   &http.Client{Timeout: 30 * time.Second},
		cache:    make(map[string][]ReleaseInfo),
		cacheTTL: time.Time{},
		logger:   logger,
	}
}

// CheckAvailable checks if a new version is available for a ficha.
// Returns available versions newer than currentVersion.
func (m *Manager) CheckAvailable(ficha, currentVersion string) ([]ReleaseInfo, error) {
	releases, err := m.fetchReleases(ficha)
	if err != nil {
		return nil, err
	}

	var newer []ReleaseInfo
	for _, r := range releases {
		if r.Version != currentVersion {
			newer = append(newer, r)
		}
	}
	return newer, nil
}

// GetLatest returns the latest release for a ficha on the configured channel.
func (m *Manager) GetLatest(ficha string) (*ReleaseInfo, error) {
	releases, err := m.fetchReleases(ficha)
	if err != nil {
		return nil, err
	}
	if len(releases) == 0 {
		return nil, fmt.Errorf("release: no releases found for %s on channel %s", ficha, m.channel)
	}
	return &releases[0], nil
}

// ListAll returns all known releases from cache or fetches them.
func (m *Manager) ListAll() (map[string][]ReleaseInfo, error) {
	m.mu.RLock()
	if time.Now().Before(m.cacheTTL) {
		defer m.mu.RUnlock()
		// Return copy
		result := make(map[string][]ReleaseInfo, len(m.cache))
		for k, v := range m.cache {
			result[k] = v
		}
		return result, nil
	}
	m.mu.RUnlock()

	// Cache expired, re-fetch
	return m.refreshAll()
}

func (m *Manager) fetchReleases(ficha string) ([]ReleaseInfo, error) {
	// Si no hay URL configurada, modo offline directo
	if m.baseURL == "" {
		return nil, fmt.Errorf("release: ReleaseServerURL no configurada")
	}

	m.mu.RLock()
	if time.Now().Before(m.cacheTTL) {
		if cached, ok := m.cache[ficha]; ok {
			m.mu.RUnlock()
			return cached, nil
		}
	}
	m.mu.RUnlock()

	url := fmt.Sprintf("%s/api/v1/releases/%s?channel=%s", m.baseURL, ficha, m.channel)

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "bos-release-manager/1.0")

	resp, err := m.client.Do(req)
	if err != nil {
		m.enterOffline(err)
		// Return cached data if available (degraded mode)
		if cached, ok := m.cache[ficha]; ok {
			m.logger.Warn("offline mode — serving cached releases", "ficha", ficha)
			return cached, nil
		}
		return nil, fmt.Errorf("release: fetch %s: %w", url, err)
	}
	defer resp.Body.Close()

	// Successful request exits offline mode
	m.exitOffline()

	if resp.StatusCode == http.StatusNotFound {
		return nil, nil
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("release: unexpected status %d from %s", resp.StatusCode, url)
	}

	var releases []ReleaseInfo
	if err := json.NewDecoder(resp.Body).Decode(&releases); err != nil {
		return nil, fmt.Errorf("release: decode response: %w", err)
	}

	// Update cache
	m.mu.Lock()
	m.cache[ficha] = releases
	m.cacheTTL = time.Now().Add(5 * time.Minute)
	m.mu.Unlock()

	return releases, nil
}

func (m *Manager) enterOffline(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if !m.offline {
		m.offline = true
		m.offlineSince = time.Now()
		m.offlineRetryN = 0
		idx := 0
		if idx < len(OfflineBackoff) {
			m.nextRetryAt = time.Now().Add(OfflineBackoff[idx])
		}
		m.logger.Warn("entering offline degraded mode", "err", err)
	}
}

func (m *Manager) exitOffline() {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.offline {
		m.offline = false
		dur := time.Since(m.offlineSince)
		m.logger.Info("exited offline mode — release server reachable", "offline_duration", dur)
	}
}

// IsOffline returns whether the release manager is in degraded offline mode.
func (m *Manager) IsOffline() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.offline
}

func (m *Manager) refreshAll() (map[string][]ReleaseInfo, error) {
	if m.baseURL == "" {
		return nil, fmt.Errorf("release: ReleaseServerURL no configurada")
	}
	url := fmt.Sprintf("%s/api/v1/releases?channel=%s", m.baseURL, m.channel)

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")

	resp, err := m.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("release: status %d", resp.StatusCode)
	}

	var all map[string][]ReleaseInfo
	if err := json.NewDecoder(resp.Body).Decode(&all); err != nil {
		return nil, err
	}

	m.mu.Lock()
	m.cache = all
	m.cacheTTL = time.Now().Add(5 * time.Minute)
	m.mu.Unlock()

	return all, nil
}

// InvalidateCache forces a refresh on the next query.
func (m *Manager) InvalidateCache() {
	m.mu.Lock()
	m.cacheTTL = time.Time{}
	m.mu.Unlock()
}
