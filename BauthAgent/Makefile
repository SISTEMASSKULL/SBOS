# bauth — SBOS Identity Core v2.0
# Makefile para build, test, lint, y despliegue
#
# DOC-SBOS-001 N3: documentación en español

.PHONY: build build-musl check test lint clean install help

# ── Targets principales ─────────────────────────────────────

## Compilar en modo release (dinámico, glibc)
build:
	cargo build --release
	@echo "Binarios: target/release/bauth ($(shell du -sh target/release/bauth | cut -f1))"
	@echo "          target/release/bauthctl ($(shell du -sh target/release/bauthctl | cut -f1))"

## Compilar estático MUSL (requiere: sudo apt install musl-tools)
build-musl:
	rustup target add x86_64-unknown-linux-musl
	cargo build --release --target x86_64-unknown-linux-musl
	@echo "Binario estático: target/x86_64-unknown-linux-musl/release/bauth"
	@file target/x86_64-unknown-linux-musl/release/bauth

## Verificar compilación (rápido, sin optimizar)
check:
	cargo check

## Ejecutar tests unitarios
test:
	cargo test

## Ejecutar linter (clippy) con denegación de warnings
lint:
	cargo clippy -- -D warnings

## Formatear código (rustfmt)
fmt:
	cargo fmt -- --check

## Limpiar artefactos de build
clean:
	cargo clean

## Instalar en producción (requiere sudo)
install: build-musl
	sudo cp target/x86_64-unknown-linux-musl/release/bauth /usr/local/bin/bauth
	sudo cp target/x86_64-unknown-linux-musl/release/bauthctl /usr/local/bin/bauthctl
	sudo chmod 755 /usr/local/bin/bauth /usr/local/bin/bauthctl
	@echo "Binarios instalados en /usr/local/bin/"

## Mostrar esta ayuda
help:
	@echo "bauth v2.0 — Makefile de desarrollo"
	@echo ""
	@echo "USO: make [target]"
	@echo ""
	@grep '^## ' Makefile | sed 's/## //'
