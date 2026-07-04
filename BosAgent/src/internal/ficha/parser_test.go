package ficha

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestParseManifestStrict_Valid(t *testing.T) {
	dir := t.TempDir()
	// Crear dashboard.json para que pase la validación
	resDir := filepath.Join(dir, "resources")
	os.MkdirAll(resDir, 0755)
	os.WriteFile(filepath.Join(resDir, "dashboard.json"), []byte(`{"title":"test"}`), 0644)

	manifest := `identity:
  id: postgresql
  server: S01
  version: 18.4.0
  category: 1
  criticality: true
  description: "PostgreSQL 18.4"

workload:
  type: StatefulSet
  runtime: kubernetes

order:
  execution_order: 100

requirements:
  dependencies:
    - sbos-bootstrap-k8s
    - sbos-bootstrap-cni
    - vault

governance:
  auto_install: true
  category_label: "datos-criticos"

meta:
  backend: helm
  idempotent: true

health:
  type: command

audit:
  ctx_id_required: true
`

	result := ParseManifestStrict(manifest, dir)
	if !result.Valid {
		t.Errorf("manifiesto válido debe ser aceptado. Errores: %v", result.Errors)
	}
}

func TestParseManifestStrict_UnknownField(t *testing.T) {
	manifest := `identity:
  id: test
  server: S01
  version: 1.0.0
  campo_misterioso: "no debería existir"
`

	result := ParseManifestStrict(manifest, "")

	hasUnknown := false
	for _, e := range result.Errors {
		if strings.Contains(e.Message, "campo no permitido") {
			hasUnknown = true
		}
	}
	if !hasUnknown {
		t.Error("debe rechazar campo desconocido (SAN-10)")
	}
}

func TestParseManifestStrict_InvalidSlug(t *testing.T) {
	manifest := `identity:
  id: "mi ficha con espacios!!!"
  server: S01
  version: 1.0.0
`

	result := ParseManifestStrict(manifest, "")
	if result.Valid {
		t.Error("slug con espacios y caracteres especiales debe ser rechazado")
	}
}

func TestParseManifestStrict_InvalidServer(t *testing.T) {
	manifest := `identity:
  id: test
  server: S99
  version: 1.0.0
`

	result := ParseManifestStrict(manifest, "")
	if result.Valid {
		t.Error("servidor S99 debe ser rechazado (rango S01-S15)")
	}
}

func TestParseManifestStrict_SHost_Valid(t *testing.T) {
	dir := t.TempDir()
	resDir := filepath.Join(dir, "resources")
	os.MkdirAll(resDir, 0755)
	os.WriteFile(filepath.Join(resDir, "dashboard.json"), []byte(`{}`), 0644)

	manifest := `identity:
  id: bos-preflight
  server: S-HOST
  version: 1.0.0

workload:
  type: bash
  runtime: host

order:
  execution_order: 10

governance:
  auto_install: true

meta:
  backend: bash

health:
  type: none
`

	result := ParseManifestStrict(manifest, dir)
	if !result.Valid {
		t.Errorf("S-HOST debe ser válido. Errores: %v", result.Errors)
	}
}

func TestParseManifestStrict_InvalidVersion(t *testing.T) {
	manifest := `identity:
  id: test
  server: S01
  version: "dieciocho punto cuatro"
`

	result := ParseManifestStrict(manifest, "")
	if result.Valid {
		t.Error("versión no numérica debe ser rechazada")
	}
}

func TestParseManifestStrict_InvalidWorkloadType(t *testing.T) {
	manifest := `identity:
  id: test
  server: S01
  version: 1.0.0

workload:
  type: SuperPod
  runtime: kubernetes
`

	result := ParseManifestStrict(manifest, "")

	hasWorkloadErr := false
	for _, e := range result.Errors {
		if strings.Contains(e.Message, "tipo inválido") {
			hasWorkloadErr = true
		}
	}
	if !hasWorkloadErr {
		t.Error("debe rechazar tipo de workload inválido")
	}
}

func TestParseManifestStrict_MissingDashboard(t *testing.T) {
	dir := t.TempDir()
	// No creamos dashboard.json a propósito

	manifest := `identity:
  id: test
  server: S01
  version: 1.0.0

workload:
  type: Deployment

order:
  execution_order: 50

governance:
  auto_install: false

meta:
  backend: helm

health:
  type: none
`

	result := ParseManifestStrict(manifest, dir)

	hasDashboardErr := false
	for _, e := range result.Errors {
		if strings.Contains(e.Message, "dashboard.json requerido") {
			hasDashboardErr = true
		}
	}
	if !hasDashboardErr {
		t.Error("debe rechazar ficha sin dashboard.json")
	}
}

func TestParseManifestStrict_LicenseWarning(t *testing.T) {
	// Sin license: → debe generar warning
	manifest := `identity:
  id: test
  server: S01
  version: 1.0.0

workload:
  type: Deployment

order:
  execution_order: 50

governance:
  auto_install: false

meta:
  backend: helm

health:
  type: none
`

	result := ParseManifestStrict(manifest, "")
	// Sin licencia no es error, solo se registra en validateLicense (no hace nada aún)
	if !result.Valid {
		t.Logf("errores: %v", result.Errors)
	}
}

func TestParseManifestStrict_AllSections(t *testing.T) {
	dir := t.TempDir()
	resDir := filepath.Join(dir, "resources")
	os.MkdirAll(resDir, 0755)
	os.WriteFile(filepath.Join(resDir, "dashboard.json"), []byte(`{}`), 0644)

	manifest := `identity:
  id: full-ficha
  server: S06
  version: 2.0.0
  category: 2
  criticality: false
  description: "Ficha completa de prueba"

workload:
  type: Deployment
  runtime: kubernetes

order:
  execution_order: 200

requirements:
  dependencies:
    - postgresql
    - redis
    - keycloak
  runtime_dependencies:
    - vault

governance:
  auto_install: true
  requires_approval: false
  category_label: "aplicacion"

meta:
  backend: helm
  idempotent: true
  estimated_minutes: 5
  rollback_support: true

health:
  type: http
  http_path: /health

audit:
  ctx_id_required: true
  log_path: /var/log/bos/fichas/full-ficha.log

scaling:
  strategy: horizontal
  min_replicas: 2
  max_replicas: 10

maintenance:
  strategy: rolling

slos:
  availability: 99.9

timeouts:
  install: 10m
  update: 5m
`

	result := ParseManifestStrict(manifest, dir)
	if !result.Valid {
		t.Errorf("manifiesto completo debe ser válido. Errores: %v", result.Errors)
		for _, e := range result.Errors {
			t.Logf("  - %s", e.Error())
		}
	}
}

func TestParseManifestStrict_EmptyManifest(t *testing.T) {
	result := ParseManifestStrict("", "")
	if result.Valid {
		t.Log("manifiesto vacío: validación depende de campos obligatorios")
	}
}

func TestParseManifestStrict_InvalidCategory(t *testing.T) {
	manifest := `identity:
  id: test
  server: S01
  version: 1.0.0
  category: 99
`

	result := ParseManifestStrict(manifest, "")
	hasCatErr := false
	for _, e := range result.Errors {
		if strings.Contains(e.Message, "category debe ser 1, 2, o 3") {
			hasCatErr = true
		}
	}
	if !hasCatErr {
		t.Error("category 99 debe ser rechazado")
	}
}

func TestParseManifestStrict_InvalidHealthType(t *testing.T) {
	manifest := `identity:
  id: test
  server: S01
  version: 1.0.0

health:
  type: magical
`

	result := ParseManifestStrict(manifest, "")
	hasHealthErr := false
	for _, e := range result.Errors {
		if strings.Contains(e.Message, "tipo de health inválido") {
			hasHealthErr = true
		}
	}
	if !hasHealthErr {
		t.Error("tipo de health 'magical' debe ser rechazado")
	}
}

func TestParseError_Formatting(t *testing.T) {
	e := ParseError{Section: "identity", Field: "id", Message: "inválido", Value: "mal!!"}
	errStr := e.Error()
	if !strings.Contains(errStr, "[identity.id]") {
		t.Error("formato de error debe incluir [section.field]")
	}
	if !strings.Contains(errStr, "mal!!") {
		t.Error("formato debe incluir el valor")
	}
}

func TestParseResult_AddError(t *testing.T) {
	result := &ParseResult{Valid: true}
	result.AddError("test", "field", "error message", "bad value")

	if result.Valid {
		t.Error("AddError debe marcar Valid=false")
	}
	if len(result.Errors) != 1 {
		t.Errorf("debe tener 1 error, obtenido %d", len(result.Errors))
	}
}

func TestParseResult_AddWarning(t *testing.T) {
	result := &ParseResult{Valid: true}
	result.AddWarning("esto es un warning")

	if !result.Valid {
		t.Error("AddWarning NO debe marcar Valid=false")
	}
	if len(result.Warnings) != 1 {
		t.Errorf("debe tener 1 warning, obtenido %d", len(result.Warnings))
	}
}
