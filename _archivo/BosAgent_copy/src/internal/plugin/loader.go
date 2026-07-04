// Package plugin scans the servers/ directory for ficha definitions,
// validates their contracts, computes SHA-256 integrity hashes, and
// registers them with the STATE_MANAGER.
package plugin

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"

	"log/slog"
)

// FichaManifest describes a discovered ficha on disk.
type FichaManifest struct {
	ID             string
	Path           string
	Server         string            // server directory (e.g. "hostserver") — from manifest identity.server
	Category       int
	Version        string
	ExecutionOrder int
	Dependencies   []string
	Criticality    bool              // false = Type 3 optional, never auto-install
	AutoInstall    bool              // true = install automatically (bootstrap product)
	WorkloadType   string            // "bash", "Deployment", "StatefulSet", etc.
	Files          map[string]string // relative path → SHA-256
	Backend        string            // "apt", "pip", "helm" from meta.backend
}

// Loader scans servers/ for ficha definitions.
type Loader struct {
	mu      sync.RWMutex
	path    string
	fichas  map[string]*FichaManifest
	logger  *slog.Logger
}

// NewLoader creates a plugin loader that scans the given directory.
func NewLoader(path string, logger *slog.Logger) *Loader {
	return &Loader{
		path:   path,
		fichas: make(map[string]*FichaManifest),
		logger: logger,
	}
}

// Scan discovers all fichas in the servers directory.
// A valid ficha directory must contain task_catalog.sh.
func (l *Loader) Scan() ([]*FichaManifest, error) {
	l.mu.Lock()
	defer l.mu.Unlock()

	if _, err := os.Stat(l.path); os.IsNotExist(err) {
		return nil, fmt.Errorf("plugin: servers path does not exist: %s", l.path)
	}

	entries, err := os.ReadDir(l.path)
	if err != nil {
		return nil, fmt.Errorf("plugin: readdir %s: %w", l.path, err)
	}

	found := make([]*FichaManifest, 0)

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		serverPath := filepath.Join(l.path, entry.Name())

		// Check if this directory itself is a ficha (has task_catalog.sh)
		taskCatalog := filepath.Join(serverPath, "task_catalog.sh")
		if _, err := os.Stat(taskCatalog); err == nil {
			m, err := l.loadFicha(entry.Name(), serverPath)
			if err != nil {
				l.logger.Warn("failed to load ficha", "ficha", entry.Name(), "err", err)
				continue
			}
			l.fichas[entry.Name()] = m
			found = append(found, m)
			l.logger.Info("ficha loaded", "id", m.ID, "version", m.Version)
			continue
		}

		// Not a ficha — scan one level deeper for fichas inside server-type directory
		subEntries, subErr := os.ReadDir(serverPath)
		if subErr != nil {
			l.logger.Debug("skipping unreadable directory", "path", serverPath)
			continue
		}

		for _, sub := range subEntries {
			if !sub.IsDir() {
				continue
			}

			fichaPath := filepath.Join(serverPath, sub.Name())
			subTaskCatalog := filepath.Join(fichaPath, "task_catalog.sh")
			if _, err := os.Stat(subTaskCatalog); os.IsNotExist(err) {
				l.logger.Debug("skipping non-ficha directory", "path", fichaPath)
				continue
			}

			m, err := l.loadFicha(sub.Name(), fichaPath)
			if err != nil {
				l.logger.Warn("failed to load ficha", "ficha", sub.Name(), "err", err)
				continue
			}

			l.fichas[sub.Name()] = m
			found = append(found, m)
			l.logger.Info("ficha loaded", "id", m.ID, "version", m.Version)
		}
	}

	sort.Slice(found, func(i, j int) bool { return found[i].ID < found[j].ID })
	return found, nil
}

func (l *Loader) loadFicha(id, path string) (*FichaManifest, error) {
	m := &FichaManifest{
		ID:       id,
		Path:     path,
		Category: 1,
		Version:  "0.1.0",
		Files:    make(map[string]string),
	}

	// Parse manifest.yml if it exists
	manifestPath := filepath.Join(path, "manifest.yml")
	if info, err := os.Stat(manifestPath); err == nil && !info.IsDir() {
		if err := l.parseManifest(manifestPath, m); err != nil {
			l.logger.Warn("manifest parse warning", "err", err, "path", manifestPath)
		}
	}

	// Hash all relevant files
	patterns := []string{"*.sh", "*.yml", "*.yaml", "*.json", "*.toml"}
	for _, pattern := range patterns {
		matches, _ := filepath.Glob(filepath.Join(path, pattern))
		for _, f := range matches {
			rel, _ := filepath.Rel(path, f)
			hash, err := fileSHA256(f)
			if err != nil {
				l.logger.Warn("hash failed", "err", err, "file", f)
				continue
			}
			m.Files[rel] = hash
		}
	}

	// Always hash task_catalog.sh if present
	tcPath := filepath.Join(path, "task_catalog.sh")
	if _, err := os.Stat(tcPath); err == nil {
		hash, err := fileSHA256(tcPath)
		if err == nil {
			m.Files["task_catalog.sh"] = hash
		}
	}

	return m, nil
}

func (l *Loader) parseManifest(path string, m *FichaManifest) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	content := string(data)
	lines := strings.Split(content, "\n")

	// State-machine parser for real SBOS manifest.yml format.
	// Tracks: identity{}, workload{}, order{}, requirements{}, governance{} sections.
	var section string // "", "identity", "workload", "order", "requirements", "governance"
	var inDeps bool

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}

		// Detect section headers (top-level keys ending with :)
		sectionDetect := strings.TrimRight(trimmed, ":")
		switch sectionDetect {
		case "identity", "workload", "order", "requirements", "governance", "meta":
			if strings.HasSuffix(trimmed, ":") {
				section = sectionDetect
				inDeps = false
				continue
			}
		}

		// Within a section, parse key: value pairs
		parts := strings.SplitN(trimmed, ":", 2)
		if len(parts) < 2 {
			// Check for list item "- value" inside dependencies
			if inDeps && strings.HasPrefix(trimmed, "- ") {
				dep := strings.TrimSpace(strings.TrimPrefix(trimmed, "- "))
				dep = strings.Trim(dep, `"'`)
				if dep != "" {
					m.Dependencies = append(m.Dependencies, dep)
				}
			}
			// Check if this is "dependencies:" header
			if strings.TrimRight(trimmed, ":") == "dependencies" {
				inDeps = true
			}
			continue
		}

		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		value = strings.Trim(value, `"'`)

		switch section {
		case "identity":
			switch key {
			case "id":
				// ID comes from directory name, but use manifest if set
				if value != "" {
					m.ID = value
				}
			case "server":
				m.Server = value
			case "version":
				m.Version = value
			case "category":
				fmt.Sscanf(value, "%d", &m.Category)
			case "criticality":
				m.Criticality = value == "true"
			}

		case "workload":
			switch key {
			case "type":
				m.WorkloadType = value
			}

		case "order":
			switch key {
			case "execution_order":
				fmt.Sscanf(value, "%d", &m.ExecutionOrder)
			}

		case "requirements":
			switch key {
			case "dependencies":
				inDeps = true
			}

		case "governance":
			switch key {
			case "auto_install":
				m.AutoInstall = value == "true"
			}

		case "meta":
			switch key {
			case "backend":
				m.Backend = value
			}
		}
	}

	return nil
}

// Reload re-scans the servers directory.
func (l *Loader) Reload() {
	if _, err := l.Scan(); err != nil {
		l.logger.Error("plugin reload failed", "err", err)
	}
}

// Get returns a loaded ficha by ID.
func (l *Loader) Get(id string) (*FichaManifest, bool) {
	l.mu.RLock()
	defer l.mu.RUnlock()
	m, ok := l.fichas[id]
	return m, ok
}

// List returns all loaded fichas.
func (l *Loader) List() []*FichaManifest {
	l.mu.RLock()
	defer l.mu.RUnlock()

	result := make([]*FichaManifest, 0, len(l.fichas))
	for _, m := range l.fichas {
		result = append(result, m)
	}
	sort.Slice(result, func(i, j int) bool { return result[i].ID < result[j].ID })
	return result
}

// Count returns the number of loaded fichas.
func (l *Loader) Count() int {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return len(l.fichas)
}

// Hashes returns all file hashes for a ficha.
func (m *FichaManifest) Hashes() map[string]string {
	result := make(map[string]string, len(m.Files))
	for k, v := range m.Files {
		result[k] = v
	}
	return result
}

func fileSHA256(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
