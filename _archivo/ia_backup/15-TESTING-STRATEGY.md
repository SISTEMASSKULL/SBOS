# Estrategia de Testing

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-013-TESTING (v6)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## Filosofia de testing
Integration-First Testing con BD real -- nunca mocks de BD. Los daemons soberanos (bKernel, biedata) operan directamente sobre el WAL de PostgreSQL real; mockear la BD invalidaria el valor de los tests.

## Piramide de cobertura SBOS

| Nivel | Herramienta | Cobertura minima | Cuando se ejecuta |
|---|---|---|---|
| Unit tests Python | pytest | Dominio IAM >= 85% | CI/CD en cada push |
| Unit tests Rust | cargo test | bKernel >= 80%, biedata >= 75% | CI/CD en cada push |
| Unit tests Go | go test -race | bos >= 80%, bAuth >= 85%, bCompass >= 75%, bhnexus >= 70%, banexus >= 70% | CI/CD en cada push |
| Unit tests Dart | flutter test | Core UI >= 70% | CI/CD en cada push |
| Integration tests | pytest + go test -tags=integration | Modulos dominio >= 85% | Pre-merge |
| FICHA_LINTER | Modulo de dominio | >= 90% contratos | CI/CD + pre-release |
| Validacion Core SP-01 | validate_sp01.py | 14 principios EXIT 0 | CI/CD + pre-release |
| Pruebas de carga | K6 | SLOs SBOS-032 | Pre-release |
| Memory leak Rust | Valgrind / cargo test --release | 1000 ejecuciones sin leak | Pre-release |
| CIS compliance | kube-bench | Level 1 PASS (42/42) | Semanal |
| Seguridad imagenes | Trivy | Zero critical | CI/CD |
| Seguridad deps Rust | cargo-audit | Zero known vulns | CI/CD |
| Seguridad deps Go | govulncheck | Zero known vulns | CI/CD |
| Analisis estatico | SonarQube | Quality Gate definido | CI/CD |
| Lint Go | golangci-lint | Zero issues | CI/CD -- bloquea merge |
| Lint Rust | clippy --deny warnings | Zero warnings | CI/CD -- bloquea merge |

## Reglas invariantes
- BD real para tests de integracion -- NUNCA mocks de BD
- Mocks solo para: APIs externas (SIAT, AFIP, SAT), Keycloak Admin API en unit tests
- TDD en: Rule Engine bKernel, STATE_MANAGER, DEPENDENCY_RESOLVER, operaciones BitMask
- Race detector siempre activo en Go: `go test -race -count=1 ./...`
- CGO_ENABLED=0 para binarios estaticos de produccion

## Eval Harness de la Fabrica (dimensiones D1-D6)
La fabrica ORQUESTA evalua su propio output con 6 dimensiones:
- D1: Cobertura AI-DOC-17 (>= 80%)
- D2: Clasificacion de nodos (>= 90%)
- D3: Deteccion de gaps (>= 80%)
- D4: Validez de manifests (= 100%)
- D5: Coherencia de sintesis (>= 3.5/5)
- D6: Eficiencia de tokens (<= 80k)
