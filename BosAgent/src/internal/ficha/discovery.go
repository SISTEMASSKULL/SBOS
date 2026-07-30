// Package ficha — Descubrimiento automático de fichas (F11.A.5 / F11.9).
// BOS-REPAIR Plan Maestro v3.
//
// El descubridor escanea el directorio servers/ en busca de fichas válidas.
// Una ficha es un subdirectorio que contiene los 3 contratos mínimos:
//
//	manifest.yml      — identidad, dependencias, puertos, health
//	task_catalog.sh   — tareas operativas (install, repair, migrate, backup)
//	resources/        — dashboards, netpolicies, configs
//
// Regla: sin task_catalog.sh → no es una ficha, se omite.
// Sin manifest.yml → WARNING, se incluye con defaults.
// Sin resources/ → WARNING, se incluye sin recursos.
//
// "Agregar la app 97 es crear una carpeta" — §16 del Proyecto Master.
// El descubrimiento automático permite que nuevas fichas aparezcan sin
// recompilar el Core. bosctl ficha rescan dispara un re-descubrimiento.
package ficha

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"log/slog"
)

// ── Tipos ────────────────────────────────────────────────────────────

// ContractStatus indica el estado de un contrato mínimo de ficha.
type ContractStatus string

const (
	ContractOK      ContractStatus = "ok"      // presente y válido
	ContractMissing ContractStatus = "missing"  // ausente (WARNING)
	ContractInvalid ContractStatus = "invalid"  // presente pero malformado (ERROR)
)

// ContractCheck representa la verificación de un contrato de ficha.
type ContractCheck struct {
	Contract string         `json:"contract"` // "manifest.yml", "task_catalog.sh", "resources/"
	Status   ContractStatus `json:"status"`
	Detail   string         `json:"detail,omitempty"`
}

// DiscoveredFicha representa una ficha encontrada durante el descubrimiento.
type DiscoveredFicha struct {
	ID          string          `json:"id"`
	Path        string          `json:"path"`
	Server      string          `json:"server"`
	Version     string          `json:"version"`
	Contracts   []ContractCheck `json:"contracts"`
	Valid       bool            `json:"valid"`       // todos los contratos OK o solo warnings
	IsNew       bool            `json:"is_new"`       // no estaba en el catálogo anterior
	DiscoveredAt time.Time      `json:"discovered_at"`
}

// DiscoveryResult contiene el resultado completo de un escaneo.
type DiscoveryResult struct {
	Path        string             `json:"path"`         // directorio escaneado
	Total       int                `json:"total"`        // total de fichas encontradas
	New         int                `json:"new"`          // fichas nuevas desde último scan
	Valid       int                `json:"valid"`        // fichas sin errores
	Warnings    int                `json:"warnings"`     // fichas con warnings (contrato faltante)
	Errors      int                `json:"errors"`       // fichas con errores (manifiesto inválido)
	Fichas      []DiscoveredFicha  `json:"fichas"`
	ScannedAt   time.Time          `json:"scanned_at"`
	Duration    time.Duration      `json:"duration"`
}

// ── Descubridor ───────────────────────────────────────────────────────

// Discoverer escanea servers/ en busca de fichas y valida sus contratos.
// Envuelve el plugin.Loader existente, agregando validación de contratos
// y tracking de fichas nuevas.
type Discoverer struct {
	mu        sync.RWMutex
	path      string
	known     map[string]string // ficha_id → path (catálogo conocido)
	logger    *slog.Logger
}

// NewDiscoverer crea un descubridor para el directorio dado.
func NewDiscoverer(serversPath string, logger *slog.Logger) *Discoverer {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(os.Stderr, nil))
	}
	return &Discoverer{
		path:   serversPath,
		known:  make(map[string]string),
		logger: logger,
	}
}

// Discover escanea el directorio servers/ y valida los contratos de cada ficha.
// Retorna el resultado completo con todas las fichas encontradas y su estado.
func (d *Discoverer) Discover() (*DiscoveryResult, error) {
	d.mu.Lock()
	defer d.mu.Unlock()

	start := time.Now()
	result := &DiscoveryResult{
		Path:      d.path,
		ScannedAt: start,
		Fichas:    make([]DiscoveredFicha, 0),
	}

	// Verificar que el directorio existe
	info, err := os.Stat(d.path)
	if os.IsNotExist(err) {
		return nil, fmt.Errorf("discovery: directorio servers/ no existe: %s", d.path)
	}
	if err != nil {
		return nil, fmt.Errorf("discovery: error al acceder a %s: %w", d.path, err)
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("discovery: %s no es un directorio", d.path)
	}

	// Escanear recursivamente
	entries, err := os.ReadDir(d.path)
	if err != nil {
		return nil, fmt.Errorf("discovery: readdir %s: %w", d.path, err)
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		serverPath := filepath.Join(d.path, entry.Name())

		// Caso 1: El directorio mismo es una ficha (tiene task_catalog.sh)
		if d.hasTaskCatalog(serverPath) {
			ficha := d.examineFicha(entry.Name(), serverPath)
			d.register(&ficha)
			result.Fichas = append(result.Fichas, ficha)
			continue
		}

		// Caso 2: Es un directorio de servidor (S01, S02, ...) — escanear un nivel más
		subEntries, subErr := os.ReadDir(serverPath)
		if subErr != nil {
			d.logger.Debug("discovery: no se pudo leer subdirectorio", "path", serverPath, "err", subErr)
			continue
		}

		for _, sub := range subEntries {
			if !sub.IsDir() {
				continue
			}
			fichaPath := filepath.Join(serverPath, sub.Name())
			if d.hasTaskCatalog(fichaPath) {
				ficha := d.examineFicha(sub.Name(), fichaPath)
				d.register(&ficha)
				result.Fichas = append(result.Fichas, ficha)
			}
		}
	}

	// Ordenar alfabéticamente
	sort.Slice(result.Fichas, func(i, j int) bool {
		return result.Fichas[i].ID < result.Fichas[j].ID
	})

	// Calcular conteos: valid = sin warnings ni errors; warnings = contrato faltante;
	// errors = f.Valid == false (ContractInvalid en examineFicha).
	for _, f := range result.Fichas {
		result.Total++
		if f.IsNew {
			result.New++
		}
		if !f.Valid {
			result.Errors++
			continue
		}
		hasWarnings := false
		for _, c := range f.Contracts {
			if c.Status == ContractMissing {
				hasWarnings = true
				break
			}
		}
		if hasWarnings {
			result.Warnings++
		} else {
			result.Valid++
		}
	}

	result.Duration = time.Since(start)
	d.logger.Info("discovery completado",
		"total", result.Total,
		"new", result.New,
		"valid", result.Valid,
		"warnings", result.Warnings,
		"errors", result.Errors,
		"duration", result.Duration,
	)

	return result, nil
}

// examineFicha verifica los 3 contratos mínimos de una ficha.
func (d *Discoverer) examineFicha(id, path string) DiscoveredFicha {
	ficha := DiscoveredFicha{
		ID:          id,
		Path:        path,
		Version:     "0.1.0",
		Contracts:   make([]ContractCheck, 0, 3),
		DiscoveredAt: time.Now(),
	}

	// Contrato 1: manifest.yml (recomendado — WARNING si falta)
	manifestPath := filepath.Join(path, "manifest.yml")
	if info, err := os.Stat(manifestPath); err == nil && !info.IsDir() {
		check := ContractCheck{Contract: "manifest.yml", Status: ContractOK}
		// Intentar parseo básico para extraer version
		if data, err := os.ReadFile(manifestPath); err == nil {
			ficha.Version = extractVersion(string(data))
			ficha.Server = extractServer(string(data))
		}
		ficha.Contracts = append(ficha.Contracts, check)
	} else {
		ficha.Contracts = append(ficha.Contracts, ContractCheck{
			Contract: "manifest.yml",
			Status:   ContractMissing,
			Detail:   "manifest.yml no encontrado — se usarán defaults",
		})
		d.logger.Warn("discovery: manifest.yml ausente", "ficha", id, "path", path)
	}

	// Contrato 2: task_catalog.sh (obligatorio — ya verificado por hasTaskCatalog)
	ficha.Contracts = append(ficha.Contracts, ContractCheck{
		Contract: "task_catalog.sh",
		Status:   ContractOK,
	})

	// Contrato 3: resources/ (recomendado — WARNING si falta)
	resourcesPath := filepath.Join(path, "resources")
	if info, err := os.Stat(resourcesPath); err == nil && info.IsDir() {
		ficha.Contracts = append(ficha.Contracts, ContractCheck{
			Contract: "resources/",
			Status:   ContractOK,
		})
	} else {
		ficha.Contracts = append(ficha.Contracts, ContractCheck{
			Contract: "resources/",
			Status:   ContractMissing,
			Detail:   "directorio resources/ no encontrado — sin dashboards ni netpolicies",
		})
	}

	// Determinar validez: válido si no hay contratos Invalid
	ficha.Valid = true
	for _, c := range ficha.Contracts {
		if c.Status == ContractInvalid {
			ficha.Valid = false
			break
		}
	}

	return ficha
}

// register registra la ficha en el catálogo conocido y determina si es nueva.
func (d *Discoverer) register(ficha *DiscoveredFicha) {
	if _, exists := d.known[ficha.ID]; !exists {
		ficha.IsNew = true
		d.logger.Info("discovery: nueva ficha encontrada", "id", ficha.ID, "path", ficha.Path)
	}
	d.known[ficha.ID] = ficha.Path
}

// hasTaskCatalog verifica si el directorio contiene task_catalog.sh.
func (d *Discoverer) hasTaskCatalog(dir string) bool {
	tcPath := filepath.Join(dir, "task_catalog.sh")
	info, err := os.Stat(tcPath)
	return err == nil && !info.IsDir()
}

// GetKnownPaths retorna una copia del mapa de fichas conocidas.
func (d *Discoverer) GetKnownPaths() map[string]string {
	d.mu.RLock()
	defer d.mu.RUnlock()
	result := make(map[string]string, len(d.known))
	for k, v := range d.known {
		result[k] = v
	}
	return result
}

// ResetKnown limpia el catálogo conocido (útil para pruebas).
func (d *Discoverer) ResetKnown() {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.known = make(map[string]string)
}

// ── Helpers de parseo rápido ──────────────────────────────────────────

// extractVersion extrae el campo version de un manifest.yml.
// Parseo mínimo — no reemplaza al parser completo (F11.A.2).
func extractVersion(content string) string {
	for _, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "version:") {
			return strings.Trim(strings.TrimPrefix(trimmed, "version:"), ` "'`)
		}
	}
	return "0.1.0"
}

// extractServer extrae el campo server de un manifest.yml.
func extractServer(content string) string {
	for _, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "server:") {
			return strings.Trim(strings.TrimPrefix(trimmed, "server:"), ` "'`)
		}
	}
	return ""
}
