# bos-agent Makefile — SBOS IAM Installer build system
# Components: bos (Go daemon), bosctl (Go CLI), Core SP-01 (Bash)

GO       ?= go
GOFLAGS  ?= -ldflags='-s -w'
CGO      ?= CGO_ENABLED=0
VERSION  ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "0.1.0-dev")
BUILDDIR ?= bin/

.PHONY: all build test lint clean check

all: build

# ── Build ────────────────────────────────────────────────────

build: build-bos build-bosctl

build-bos:
	$(CGO) $(GO) build $(GOFLAGS) -o $(BUILDDIR)bos ./cmd/bos/

build-bosctl:
	$(CGO) $(GO) build $(GOFLAGS) -o $(BUILDDIR)bosctl ./cmd/bosctl/

# ── Test ─────────────────────────────────────────────────────

test:
	$(GO) test -race -count=1 -coverprofile=coverage.out ./...
	$(GO) tool cover -func=coverage.out | grep total

# ── Lint ─────────────────────────────────────────────────────

lint:
	gofmt -l . | tee /dev/stderr | test ! -s -
	golangci-lint run ./...
	$(GO) vet ./...

# ── Package ──────────────────────────────────────────────────
# Empaqueta binarios + scripts core + fichas para distribución.
# El auto-bootstrap del daemon copia desde /tmp/ → rutas canónicas.

PKGDIR ?= dist/

package: build
	@mkdir -p $(PKGDIR)
	cp $(BUILDDIR)bos    $(PKGDIR)bos
	cp $(BUILDDIR)bosctl $(PKGDIR)bosctl
	cp core/00_MASTER_INSTALL_SBOS.sh  $(PKGDIR)
	cp core/00_TASK_CATALOG_SBOS.sh    $(PKGDIR)
	cp core/00_YAML_ENGINE_SBOS.sh     $(PKGDIR)
	cp core/00_CLEANUP_SBOS.sh         $(PKGDIR)
	cp core/host-setup.sh              $(PKGDIR)
	@mkdir -p $(PKGDIR)servers
	@cp -r servers/ $(PKGDIR)servers/
	@echo "Paquete generado en $(PKGDIR)"
	@ls -lh $(PKGDIR)

# ── CI Gate ──────────────────────────────────────────────────

check: lint test build
	@echo "CI GATE: PASS"
