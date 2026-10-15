# bos-agent Makefile — SBOS IAM Installer build system
# Components: bos (Go daemon), bosctl (Go CLI), Core SP-01 (Bash)

GO       ?= go
GOFLAGS  ?= -ldflags='-s -w'
CGO      ?= CGO_ENABLED=0
VERSION  ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "0.1.0-dev")
BUILDDIR ?= bin/

.PHONY: all build test lint clean package release check

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
	@rm -rf $(PKGDIR) && mkdir -p $(PKGDIR)
	cp $(BUILDDIR)bos    $(PKGDIR)bos
	cp $(BUILDDIR)bosctl $(PKGDIR)bosctl
	@mkdir -p $(PKGDIR)core
	cp core/00_MASTER_INSTALL_SBOS.sh  $(PKGDIR)core/
	cp core/00_TASK_CATALOG_SBOS.sh    $(PKGDIR)core/
	cp core/00_YAML_ENGINE_SBOS.sh     $(PKGDIR)core/
	cp core/00_CLEANUP_SBOS.sh         $(PKGDIR)core/
	cp core/host-setup.sh              $(PKGDIR)core/
	@cp -r servers $(PKGDIR)servers
	@if [ -d "../../DDLs" ]; then \
		mkdir -p $(PKGDIR)ddls && \
		cp -r ../../DDLs/seeds $(PKGDIR)ddls/ 2>/dev/null || true && \
		cp ../../DDLs/SBOS_db_V2_DDL.sql $(PKGDIR)ddls/ 2>/dev/null || true && \
		cp ../../DDLs/bos_01__control_plane.sql $(PKGDIR)ddls/ 2>/dev/null || true && \
		echo "DDLs incluidos en el paquete"; \
	fi
	@echo "Paquete generado en $(PKGDIR)"
	@ls -lh $(PKGDIR)

clean:
	rm -rf $(BUILDDIR) $(PKGDIR) $(RELEASEFILE)

RELEASEFILE ?= bos-release.tar.gz

release: package
	@tar -czf $(RELEASEFILE) -C $(PKGDIR) .
	@ls -lh $(RELEASEFILE)
	@echo "Desplegar con:"
	@echo "  scp $(RELEASEFILE) root@<PROD_IP>:/tmp/"
	@echo "  ssh root@<PROD_IP> 'mkdir -p /opt/bos && tar -xzf /tmp/$(RELEASEFILE) -C /opt/bos && cp /opt/bos/bos /usr/local/bin/bos && cp /opt/bos/bosctl /usr/local/bin/bosctl && cp -r /opt/bos/servers/* /etc/bos/blibs/servers/ && mkdir -p /etc/bos/blibs/DDLs && cp -r /opt/bos/ddls/* /etc/bos/blibs/DDLs/ && systemctl restart bos.service'"

# ── CI Gate ──────────────────────────────────────────────────

check: lint test build
	@echo "CI GATE: PASS"
