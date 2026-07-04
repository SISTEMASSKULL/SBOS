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
	"time"

	"log/slog"
)

// FichaManifest describe una ficha descubierta en disco.
//
// Thread safety: inmutable tras Scan(); seguro para lectura concurrente.
type FichaManifest struct {
	ID             string
	Path           string
	Server         string // server directory (e.g. "hostserver") — from manifest identity.server
	Category       int
	Version        string
	ExecutionOrder int
	Dependencies   []string
	Criticality    bool              // false = Type 3 optional, never auto-install
	AutoInstall    bool              // true = install automatically (bootstrap product)
	WorkloadType   string            // "bash", "Deployment", "StatefulSet", etc.
	Files          map[string]string // relative path → SHA-256
	Backend        string            // "apt", "pip", "helm" from meta.backend

	// F9.1 — políticas del Operator Soberano (BOS-REPAIR-02). nil si el
	// manifest no declara la sección correspondiente.
	Scaling     *ScalingPolicy
	Maintenance *MaintenancePolicy
	SLOs        *SLOPolicy
}

// Loader escanea servers/ en busca de fichas válidas.
//
// Thread safety: Scan() y List() usan mu (RWMutex). Scan() usa Lock completo;
// List() y Get() usan RLock para lectura concurrente segura.
type Loader struct {
	mu     sync.RWMutex
	path   string
	fichas map[string]*FichaManifest
	logger *slog.Logger
}

// NewLoader crea un plugin loader que escanea el directorio dado.
//
// Recibe:
//   - path: string — ruta al directorio servers/ (paths.ServersPath).
//   - logger: *slog.Logger — logger estructurado.
//
// Retorna: *Loader listo para Scan(). Llamar Scan() para descubrir fichas.
//
// Callers conocidos:
//   - cmd/bos/main.go:runNormal — paso 2.
func NewLoader(path string, logger *slog.Logger) *Loader {
	return &Loader{
		path:   path,
		fichas: make(map[string]*FichaManifest),
		logger: logger,
	}
}

// Scan descubre todas las fichas en el directorio servers/.
// Un directorio válido de ficha debe contener task_catalog.sh.
//
// Retorna:
//   - []*FichaManifest ordenada alfabéticamente por ID.
//   - error si el directorio servers/ no existe o no es legible.
//
// Efectos secundarios:
//   - Actualiza el mapa interno fichas con los manifests encontrados.
//   - Lee manifest.yml y calcula hashes SHA-256 de cada ficha.
//
// Estándares: SBOS-019 §2 — estructura servers/<servidor>/<nombre>/.
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
		// Solo en columna 0 — los sub-bloques (horizontal:, vertical:,
		// context_aware:) van indentados y NO cambian la sección (F9.1).
		sectionDetect := strings.TrimRight(trimmed, ":")
		switch sectionDetect {
		case "identity", "workload", "order", "requirements", "governance", "meta",
			"scaling", "maintenance", "slos":
			if strings.HasSuffix(trimmed, ":") && !strings.HasPrefix(line, " ") && !strings.HasPrefix(line, "\t") {
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
				dep = stripInlineComment(dep)
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
		value := stripInlineComment(strings.TrimSpace(parts[1]))
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
			default:
				inDeps = false // runtime_dependencies u otra clave → cerrar lista de deps
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

		// F9.1 — políticas del Operator Soberano (BOS-REPAIR-02 §schema).
		// Las claves de los sub-bloques horizontal/vertical/context_aware se
		// aplanan: no colisionan entre sí. peak_contexts (lista anidada)
		// queda fuera del parser plano — se configura vía código (scaler).
		case "scaling":
			if m.Scaling == nil {
				m.Scaling = &ScalingPolicy{}
			}
			switch key {
			case "strategy":
				m.Scaling.Strategy = value
			case "min_replicas":
				fmt.Sscanf(value, "%d", &m.Scaling.MinReplicas)
			case "max_replicas":
				fmt.Sscanf(value, "%d", &m.Scaling.MaxReplicas)
			case "target_cpu_percent":
				fmt.Sscanf(value, "%d", &m.Scaling.TargetCPUPercent)
			case "target_memory_percent":
				fmt.Sscanf(value, "%d", &m.Scaling.TargetMemPercent)
			case "scale_up_cooldown":
				m.Scaling.ScaleUpCooldown, _ = time.ParseDuration(value)
			case "scale_down_cooldown":
				m.Scaling.ScaleDownCool, _ = time.ParseDuration(value)
			case "mode":
				m.Scaling.VerticalMode = value
			case "min_cpu":
				m.Scaling.MinCPU = value
			case "max_cpu":
				m.Scaling.MaxCPU = value
			case "min_memory":
				m.Scaling.MinMemory = value
			case "max_memory":
				m.Scaling.MaxMemory = value
			case "update_policy":
				m.Scaling.UpdatePolicy = value
			case "enabled":
				m.Scaling.ContextAware = value == "true"
			}

		case "maintenance":
			if m.Maintenance == nil {
				m.Maintenance = &MaintenancePolicy{}
			}
			switch key {
			case "strategy":
				m.Maintenance.Strategy = value
			case "max_unavailable":
				fmt.Sscanf(value, "%d", &m.Maintenance.MaxUnavailable)
			case "drain_timeout":
				m.Maintenance.DrainTimeout, _ = time.ParseDuration(value)
			}

		case "slos":
			if m.SLOs == nil {
				m.SLOs = &SLOPolicy{}
			}
			switch key {
			case "availability":
				fmt.Sscanf(value, "%g", &m.SLOs.Availability)
			case "latency_p99_ms":
				fmt.Sscanf(value, "%d", &m.SLOs.LatencyP99Ms)
			case "error_rate_max":
				fmt.Sscanf(value, "%g", &m.SLOs.ErrorRateMax)
			}
		}
	}

	return nil
}

// Reload re-escanea el directorio servers/. Loguea el error sin propagar.
//
// Efectos secundarios: actualiza el mapa interno fichas.
func (l *Loader) Reload() {
	if _, err := l.Scan(); err != nil {
		l.logger.Error("plugin reload failed", "err", err)
	}
}

// Get retorna una ficha cargada por ID.
//
// Retorna: (*FichaManifest, true) si existe; (nil, false) si no.
//
// Efectos secundarios: ninguno — solo lectura bajo RLock.
func (l *Loader) Get(id string) (*FichaManifest, bool) {
	l.mu.RLock()
	defer l.mu.RUnlock()
	m, ok := l.fichas[id]
	return m, ok
}

// List retorna todas las fichas cargadas, ordenadas alfabéticamente por ID.
//
// Efectos secundarios: ninguno — solo lectura bajo RLock.
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

// Count retorna el número de fichas cargadas.
//
// Efectos secundarios: ninguno — solo lectura bajo RLock.
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

// stripInlineComment elimina un comentario YAML inline (" #...") de un valor.
// Solo corta cuando el '#' va precedido de espacio (convención YAML) y fuera
// de comillas — un '#' dentro de "valor#con#hash" o pegado al texto se
// preserva. Hallazgo F11.2: las deps con comentario inline se parseaban
// enteras ("postgresql # db" como dependencia).
func stripInlineComment(s string) string {
	inQuote := byte(0)
	for i := 0; i < len(s); i++ {
		c := s[i]
		switch {
		case inQuote != 0:
			if c == inQuote {
				inQuote = 0
			}
		case c == '"' || c == '\'':
			inQuote = c
		case c == '#' && i > 0 && (s[i-1] == ' ' || s[i-1] == '\t'):
			return strings.TrimSpace(s[:i])
		}
	}
	return strings.TrimSpace(s)
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
