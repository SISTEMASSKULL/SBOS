# bAuthDEV — Makefile
# Compilar, testear, empaquetar y publicar

.PHONY: build test clean

build:
	flutter build windows --release

test:
	flutter test

analyze:
	flutter analyze lib/

clean:
	flutter clean
	rm -rf build/

release: test analyze build
	@echo "Build completado. Artefacto en build/windows/x64/runner/Release/"
