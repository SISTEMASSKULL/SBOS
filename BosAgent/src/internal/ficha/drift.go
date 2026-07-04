// Package ficha — Drift detector (F11.D.2).
// BOS-REPAIR Plan Maestro v3.
//
// El drift es la divergencia entre el estado declarado de una ficha (manifest.yml,
// resources/) y el estado real del sistema (archivos en disco, pods K8s, configmaps).
//
// El detector compara hashes SHA-256 almacenados (del último scan/install) contra
// los hashes actuales de los archivos en disco. Si difieren, hay drift.
//
// Tipos de drift detectados:
//   - changed: el archivo existe en ambos lados pero el hash difiere
//   - missing: el archivo estaba declarado pero ya no existe en disco
//   - new:     hay un archivo nuevo en disco que no estaba en el estado declarado
//
// El detector es independiente de K8s — la comparación de recursos K8s (imagen,
// réplicas, configmaps) se integra en F9 (Operator Soberano).
//
// Estándares: SBOS-019 §8, ADR-021 #5 (ACTUALIZACION_DISPONIBLE), CIS Benchmark v8 §4.1.
package ficha

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"log/slog"
)

// ── Tipos ────────────────────────────────────────────────────────────

// DriftStatus clasifica el resultado de comparar un recurso.
type DriftStatus string

const (
	DriftOK      DriftStatus = "ok"      // sin cambios
	DriftChanged DriftStatus = "changed"  // el hash difiere
	DriftMissing DriftStatus = "missing"  // el archivo ya no existe
	DriftNew     DriftStatus = "new"      // archivo nuevo no declarado
)

// DriftItem describe la divergencia de un recurso individual.
type DriftItem struct {
	Path     string      `json:"path"`     // ruta relativa del recurso
	Declared string      `json:"declared"` // hash declarado (estado conocido)
	Actual   string      `json:"actual"`   // hash actual (calculado ahora)
	Status   DriftStatus `json:"status"`
}

// DriftReport contiene el resultado de detectar drift en una ficha.
type DriftReport struct {
	FichaID    string        `json:"ficha_id"`
	FichaPath  string        `json:"ficha_path"`
	HasDrift   bool          `json:"has_drift"`
	Items      []DriftItem   `json:"items"`
	CheckedAt  time.Time     `json:"checked_at"`
	Duration   time.Duration `json:"duration"`
}

// DriftSummaryReport resume el drift de múltiples fichas.
type DriftSummaryReport struct {
	TotalFichas   int           `json:"total_fichas"`
	DriftedFichas int           `json:"drifted_fichas"`
	OkFichas      int           `json:"ok_fichas"`
	Reports       []DriftReport `json:"reports,omitempty"`
	CheckedAt     time.Time     `json:"checked_at"`
	Duration      time.Duration `json:"duration"`
}

// ── Detector ──────────────────────────────────────────────────────────

// DriftDetector compara el estado declarado vs el estado real del sistema.
type DriftDetector struct {
	serversPath string // ruta base de servers/ (ej: /etc/bos/blibs/servers)
	logger      *slog.Logger
}

// NewDriftDetector crea un detector de drift para el directorio servers/ dado.
func NewDriftDetector(serversPath string, logger *slog.Logger) *DriftDetector {
	if logger == nil {
		logger = slog.Default()
	}
	return &DriftDetector{serversPath: serversPath, logger: logger}
}

// Detect compara los hashes conocidos de una ficha contra el estado actual en disco.
// knownHashes: mapa path→hash del último estado conocido (desde plugin.Loader o state.Manager).
// fichaPath: ruta absoluta al directorio de la ficha.
func (d *DriftDetector) Detect(fichaID, fichaPath string, knownHashes map[string]string) (*DriftReport, error) {
	start := time.Now()
	report := &DriftReport{
		FichaID:   fichaID,
		FichaPath: fichaPath,
		CheckedAt: start,
		Items:     make([]DriftItem, 0),
	}

	// Verificar que el directorio existe
	if _, err := os.Stat(fichaPath); os.IsNotExist(err) {
		// El directorio no existe — todos los archivos conocidos están missing
		for path := range knownHashes {
			report.Items = append(report.Items, DriftItem{
				Path:     path,
				Declared: knownHashes[path],
				Actual:   "",
				Status:   DriftMissing,
			})
		}
		report.HasDrift = len(report.Items) > 0
		report.Duration = time.Since(start)
		return report, nil
	}

	// Conjunto de todos los paths a verificar
	allPaths := make(map[string]bool)
	for path := range knownHashes {
		allPaths[path] = true
	}

	// Escanear archivos en el directorio de la ficha
	currentFiles := d.scanFiles(fichaPath)
	for path := range currentFiles {
		allPaths[path] = true
	}

	// Comparar cada path
	for path := range allPaths {
		declaredHash := knownHashes[path]
		currentHash := currentFiles[path]

		item := DriftItem{Path: path, Declared: declaredHash, Actual: currentHash}

		switch {
		case declaredHash == "" && currentHash != "":
			item.Status = DriftNew
			report.HasDrift = true
		case declaredHash != "" && currentHash == "":
			item.Status = DriftMissing
			report.HasDrift = true
		case declaredHash != currentHash:
			item.Status = DriftChanged
			report.HasDrift = true
		default:
			item.Status = DriftOK
		}

		report.Items = append(report.Items, item)
	}

	report.Duration = time.Since(start)

	if report.HasDrift {
		changed := countByDriftStatus(report.Items, DriftChanged)
		missing := countByDriftStatus(report.Items, DriftMissing)
		newFiles := countByDriftStatus(report.Items, DriftNew)
		d.logger.Warn("drift detectado",
			"ficha", fichaID,
			"changed", changed,
			"missing", missing,
			"new", newFiles,
			"duration", report.Duration,
		)
	} else {
		d.logger.Debug("sin drift", "ficha", fichaID, "duration", report.Duration)
	}

	return report, nil
}

// DetectAll ejecuta detección de drift para múltiples fichas en paralelo.
func (d *DriftDetector) DetectAll(fichas map[string]DriftInput) *DriftSummaryReport {
	start := time.Now()
	summary := &DriftSummaryReport{
		TotalFichas: len(fichas),
		CheckedAt:   start,
		Reports:     make([]DriftReport, 0, len(fichas)),
	}

	var mu sync.Mutex
	var wg sync.WaitGroup

	for id, input := range fichas {
		wg.Add(1)
		go func(fichaID string, inp DriftInput) {
			defer wg.Done()
			report, err := d.Detect(fichaID, inp.FichaPath, inp.KnownHashes)
			if err != nil {
				d.logger.Error("drift detection falló", "ficha", fichaID, "err", err)
				return
			}
			mu.Lock()
			summary.Reports = append(summary.Reports, *report)
			if report.HasDrift {
				summary.DriftedFichas++
			} else {
				summary.OkFichas++
			}
			mu.Unlock()
		}(id, input)
	}

	wg.Wait()
	summary.Duration = time.Since(start)

	d.logger.Info("drift detection completada",
		"total", summary.TotalFichas,
		"drifted", summary.DriftedFichas,
		"ok", summary.OkFichas,
		"duration", summary.Duration,
	)

	return summary
}

// ── Input ─────────────────────────────────────────────────────────────

// DriftInput contiene los datos necesarios para detectar drift en una ficha.
type DriftInput struct {
	FichaID      string
	FichaPath    string            // ruta absoluta al directorio de la ficha
	KnownHashes  map[string]string // hashes conocidos (del último scan/install)
}

// ── Helpers ───────────────────────────────────────────────────────────

// scanFiles calcula hashes SHA-256 de todos los archivos relevantes en un directorio.
// Solo incluye archivos con extensiones declarativas: .sh, .yml, .yaml, .json, .toml.
func (d *DriftDetector) scanFiles(dir string) map[string]string {
	hashes := make(map[string]string)

	patterns := []string{"*.sh", "*.yml", "*.yaml", "*.json", "*.toml"}
	for _, pattern := range patterns {
		matches, err := filepath.Glob(filepath.Join(dir, pattern))
		if err != nil {
			continue
		}
		for _, match := range matches {
			hash, err := fileSHA256(match)
			if err != nil {
				d.logger.Debug("no se pudo hashear archivo", "path", match, "err", err)
				continue
			}
			rel, _ := filepath.Rel(dir, match)
			hashes[rel] = hash
		}
	}

	// También incluir resources/ si existe
	resourcesDir := filepath.Join(dir, "resources")
	if info, err := os.Stat(resourcesDir); err == nil && info.IsDir() {
		filepath.Walk(resourcesDir, func(path string, info os.FileInfo, err error) error {
			if err != nil || info.IsDir() {
				return nil
			}
			hash, hashErr := fileSHA256(path)
			if hashErr != nil {
				return nil
			}
			rel, _ := filepath.Rel(dir, path)
			hashes[rel] = hash
			return nil
		})
	}

	return hashes
}

// fileSHA256 calcula el hash SHA-256 de un archivo.
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

// countByDriftStatus cuenta los items con un estado de drift dado.
func countByDriftStatus(items []DriftItem, status DriftStatus) int {
	n := 0
	for _, item := range items {
		if item.Status == status {
			n++
		}
	}
	return n
}

// DriftSummary resumen legible del reporte de drift.
func (r *DriftReport) DriftSummary() string {
	if !r.HasDrift {
		return fmt.Sprintf("✅ %s: sin drift", r.FichaID)
	}
	var sb strings.Builder
	fmt.Fprintf(&sb, "⚠️  %s: drift detectado\n", r.FichaID)
	for _, item := range r.Items {
		if item.Status == DriftOK {
			continue
		}
		icon := "~"
		switch item.Status {
		case DriftChanged:
			icon = "✏️"
		case DriftMissing:
			icon = "🗑️"
		case DriftNew:
			icon = "➕"
		}
		decl := item.Declared
		if len(decl) > 12 {
			decl = decl[:12]
		}
		act := item.Actual
		if len(act) > 12 {
			act = act[:12]
		}
		fmt.Fprintf(&sb, "  %s %s: %s → %s\n", icon, item.Path, decl, act)
	}
	return sb.String()
}

// DriftSummaryText retorna el resumen de drift como texto.
func (s *DriftSummaryReport) DriftSummaryText() string {
	if s.TotalFichas == 0 {
		return "sin fichas para verificar"
	}
	if s.DriftedFichas == 0 {
		return fmt.Sprintf("✅ %d fichas sin drift (%v)", s.OkFichas, s.Duration.Round(time.Millisecond))
	}
	return fmt.Sprintf("⚠️  %d/%d fichas con drift (%v)",
		s.DriftedFichas, s.TotalFichas, s.Duration.Round(time.Millisecond))
}
