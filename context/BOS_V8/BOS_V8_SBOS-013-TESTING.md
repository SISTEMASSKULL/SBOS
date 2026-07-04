# SBOS-013-TESTING
## Estrategia de Testing — Estándar HUMAN-DOC
### SKULL · SBOS · V8 · Mayo 2026

---

## 1. Filosofía de Testing

**Filosofía adoptada: Integration-First Testing con pirámide de cobertura adaptada.** Decisión formal tomada en SBOS-COMPLETITUD-v2 §2 B2.3.

**Fundamento técnico:** La investigación de 2024-2026 sobre testing de microservicios y sistemas distribuidos (Atlassian, Martin Fowler, DORA, Signadot 2025) establece un consenso claro: los mocks de BD dan una falsa sensación de seguridad — tests pasan contra mocks pero fallan contra el servicio real. Para el SBOS, donde los daemons soberanos (bKernel, biedata) operan directamente sobre el WAL de PostgreSQL real, mockear la BD invalidaría completamente el valor de los tests.

### Pirámide de cobertura SBOS

```
┌─────────────────────────────────────────────────────────────┐
│  E2E / Smoke Tests         │  Pocos, lentos, crean confianza │
│  (K6 + Goss)               │  Ejecutan en staging/pre-release│
├─────────────────────────────────────────────────────────────┤
│  Integration Tests         │  Cantidad media, BD REAL siempre│
│  (pytest + go test)        │  Ejecutan pre-merge en CI       │
├─────────────────────────────────────────────────────────────┤
│  Unit Tests                │  Muchos, rápidos, lógica pura   │
│  (pytest/cargo/go/flutter) │  Ejecutan en cada push          │
└─────────────────────────────────────────────────────────────┘
```

### Reglas invariantes de testing

- BD real para tests de integración — **NUNCA mocks de BD**
- Mocks **solo para**: APIs externas de terceros (SIAT, AFIP, SAT), Keycloak Admin API en unit tests, sistemas de pago externos
- **TDD aplicado** en: Rule Engine bKernel, módulos dominio Python IAM Installer (STATE_MANAGER, DEPENDENCY_RESOLVER, HEALTH_CHECKER), operaciones BitMask 64-bit, algoritmo Kahn de DEPENDENCY_RESOLVER
- **Test-after** para: fichas SBOS (manifest.yml + yaml_engine.yml), scripts Bash Core SP-01, rutas bCompass, cajas biedata, configuraciones YAML
- Race detector **siempre activo** en Go: `go test -race -count=1 ./...`
- Memory leak test para Rust: 1000 ejecuciones sin leak (Valgrind/Miri)
- **FICHA_LINTER ≥90% cobertura** — bloquea release sin excepciones

---

## 2. Tipos de Test

| Tipo | Herramienta | Cobertura mínima | Cuándo se ejecuta |
|---|---|---|---|
| Unit tests (Python) | pytest | Dominio IAM ≥ 85% | CI/CD en cada push |
| Unit tests (Rust) | cargo test | bKernel Rule Engine ≥ 80%, biedata Box Engine ≥ 75% | CI/CD en cada push |
| Unit tests (Go) | go test -race | bos ≥80%, bCompass ≥75%, bSearch ≥75%, bAuth ≥85%, bhnexus ≥70%, banexus ≥70% | CI/CD en cada push |
| Unit tests (Dart/Flutter) | flutter test | Core UI ≥70% | CI/CD en cada push |
| Integration tests | pytest + go test -tags=integration | Módulos dominio IAM ≥85%, .so daemons 100% | Pre-merge en feature branches |
| FICHA_LINTER | Módulo de dominio | ≥ 90% contratos cubiertos | CI/CD + pre-release |
| Validación Core SP-01 | validate_sp01.py | 14 principios — EXIT 0 obligatorio | CI/CD + pre-release |
| Validación contratos fichas | validate_sp02.py | EXIT 0 — bloquea release | CI/CD + pre-release |
| Pruebas de carga | K6 | SLOs de SBOS-032 | Pre-release |
| Prueba memory leak | Valgrind / cargo test --release | 1000 ejecuciones sin leak | Pre-release Rust .so |
| CIS compliance | kube-bench | Level 1 PASS (42/42) | Semanal (automático) |
| Seguridad imágenes | Trivy | Zero critical | CI/CD |
| Seguridad deps Rust | cargo-audit | Zero known vulns | CI/CD |
| Seguridad deps Go | govulncheck | Zero known vulns | CI/CD |
| Análisis estático | SonarQube | Criterio formal definido — ver §4 Estado del Quality Gate | CI/CD |
| Lint Go | golangci-lint | Zero issues con .golangci.yml del daemon | CI/CD — bloquea merge |
| Lint Rust | clippy --deny warnings | Zero warnings | CI/CD — bloquea merge |

---

## 3. Reglas de Testing

- BD real para tests de integración — no mocks de BD
- Tests de integración obligatorios para todos los .so de daemons
- Prueba de carga con 1000 ejecuciones consecutivas sin memory leak (Rust .so)
- `clippy --deny warnings` obligatorio (Rust)
- `cargo fmt --check` obligatorio (Rust)
- `go test -race -count=1 ./...` — race detector siempre activo en CI (Go)
- `gofmt -l .` — zero archivos sin formatear (Go)
- `golangci-lint run` — zero issues antes de merge (Go)
- `flutter test --coverage` con umbral ≥70% (Dart/Flutter)
- validate_sp01.py EXIT 0 obligatorio antes de cualquier release (valida los 14 principios del Core)
- validate_sp02.py EXIT 0 obligatorio para cada ficha antes de publicar en Release Plane
- FICHA_LINTER cobertura ≥90% — sin excepciones

---

## 4. CI/CD Gates

| Gate | Qué debe pasar | Herramienta | Bloquea merge |
|---|---|---|---|
| Unit tests | 100% pass | pytest / cargo test / go test / flutter test | Sí |
| Cobertura | ≥ umbrales por daemon (ver §2) | lcov / cargo-tarpaulin / go test -cover / lcov | Sí |
| Race detector Go | 0 race conditions | go test -race | Sí |
| FICHA_LINTER | ≥90% pass | Módulo Python | Sí |
| validate_sp01.py | EXIT 0 | Python | Sí (pre-release) |
| validate_sp02.py | EXIT 0 por ficha | Python | Sí (pre-release) |
| Trivy scan | Zero critical CVEs | Trivy | Sí |
| cargo-audit | Zero known vulns | cargo-audit | Sí |
| govulncheck | Zero known vulns | govulncheck | Sí |
| golangci-lint | Zero issues | golangci-lint | Sí |
| clippy | Zero warnings | cargo clippy | Sí |
| SonarQube Quality Gate | **Criterio formal:** cobertura código nuevo ≥70%, blocker issues = 0, critical issues = 0, major issues ≤5 (con plan de remediación en SBOS-016-NOTES), security hotspots revisados 100%, duplicación código nuevo <3% | SonarQube | Sí — **activar antes de v0.9 Beta** |
| K6 load test | SLOs de SBOS-032 | K6 | Sí (pre-release) |
| kube-bench | Level 1 PASS | kube-bench | Semanal |

---

### Estado del SonarQube Quality Gate

🔴 **Pendiente de activar en el pipeline CI/CD.** Criterio formal aprobado (Super Usuario, Abril 2026). Fecha límite: **antes del primer PR de código de producción de cualquier daemon, y obligatoriamente antes del release v0.9 Beta**.

**Pasos de activación (ejecutar en orden):**

1. **Instalar SonarQube Community Edition** como ficha en S14 (opsserver) — o usar SonarCloud para repos públicos (gratuito, sin instalación)
2. **Crear el proyecto** en SonarQube con el nombre `sbos-monorepo` y asociar el token de autenticación
3. **Configurar sonar-project.properties** en la raíz del monorepo:
   ```properties
   sonar.projectKey=sbos-monorepo
   sonar.projectName=SBOS Monorepo
   sonar.sources=.
   sonar.exclusions=**/vendor/**,**/*.pb.go,**/migrations/**
   sonar.go.coverage.reportPaths=coverage.out
   sonar.rust.coverage.reportPaths=lcov.info
   ```
4. **Añadir el paso `sonar-scanner`** al pipeline CI/CD (GitHub Actions o GitLab CI) como paso posterior a los tests, para que el reporte de cobertura ya esté generado
5. **Configurar el Quality Gate** en SonarQube con los umbrales del criterio formal (ver tabla §4 arriba)
6. **Activar el webhook** de SonarQube apuntando al pipeline para que el build falle automáticamente si el Quality Gate no pasa — sin webhook, el gate no bloquea
7. **Ejecutar el primer análisis** para establecer el baseline del proyecto
8. **Actualizar este archivo:** cambiar 🔴 a ✅ en esta sección y actualizar la fila de la tabla §4 removiendo la nota "activar antes de v0.9 Beta"

**Nota de prioridad:** El Quality Gate de SonarQube no es opcional para v0.9 Beta (KR-3.2 en SBOS-001-VISION §10). Si el CI llega a la release sin este gate activo, la release no puede marcarse como Beta — incumple el criterio de "cobertura tests activa en CI/CD".

---

## 5. Entornos de Test

| Entorno | BD | K8s | Uso |
|---|---|---|---|
| Local (developer) | Contenedor Podman local | No | Unit tests + lint |
| CI/CD (GitHub Actions / GitLab) | BD real en contenedor | Minikube/kind | Integration tests + FICHA_LINTER |
| Staging (VPS) | PostgreSQL completo | Cluster real | K6 + kube-bench + validadores |

---

## 6. Patrones de Testing para Módulos Smart* (Tryton/ERP)

Los subproyectos Smart* del ecosistema SBOS adoptan la misma filosofía Integration-First
con una pirámide de tres capas adaptada para módulos Tryton:

```
┌──────────────────────┐
│  Integración         │  ← Simula bKernel completo (BKERNEL_MODE=mock)
│  (E2E mock)          │    Pocos, lentos, críticos
├──────────────────────┤
│  Contrato            │  ← Verifica que los métodos JSON-RPC
│  (JSON-RPC)          │    cumplen el contrato con bKernel/bpay
├──────────────────────┤
│  Unitarios           │  ← Lógica de negocio aislada
│  (por módulo)        │    Muchos, rápidos, exhaustivos
└──────────────────────┘
```

### Patrones de test para módulos Tryton (de SBOSTRY-014-TESTS)

Los tests de módulos Tryton (account_bo, party_bo, account_invoice_bo, sbos_context)
siguen estos patrones establecidos:

**Verificación de datos críticos:**
```python
def test_plan_cuentas_cuentas_criticas(self):
    """Las cuentas que bpay referencia deben existir."""
    Account = self.Account
    for codigo in ['1.1.1.01', '1.1.1.02', '4.1.1.01']:
        accounts = Account.search([('code', '=', codigo)])
        self.assertTrue(len(accounts) > 0, f'Cuenta {codigo} no encontrada')
```

**Validación de configuración regional:**
```python
def test_iva_price_includes_tax(self):
    """IVA boliviano debe tener price_includes_tax=True."""
    Tax = self.Tax
    taxes = Tax.search([('name', 'like', '%IVA%')])
    for tax in taxes:
        self.assertTrue(tax.price_includes_tax)
```

**Idempotencia y deduplicación:**
```python
def test_deduplicacion(self):
    """Misma transacción dos veces → mismo resultado."""
    r1 = Move.create_from_bpay(payload)
    r2 = Move.create_from_bpay(payload)
    self.assertEqual(r1['move_id'], r2['move_id'])
    self.assertTrue(r2.get('duplicate'))
```

**Validación de montos incoherentes:**
```python
def test_monto_incoherente_rechazado(self):
    """net_amount + retenciones ≠ amount → error."""
    result = Move.create_from_bpay(payload_incoherente)
    self.assertEqual(result['status'], 'error')
    self.assertEqual(result['code'], 'AMOUNT_INCOHERENCE')
```

### Makefile de tests para módulos Tryton

```makefile
test-all:
    python -m pytest src/modules/*/tests/ -v --tb=short

test-account-bo:
    python -m pytest src/modules/account_bo/tests/ -v

test-sbos-context:
    python -m pytest src/modules/sbos_context/tests/ -v

test-contract:
    python src/tests/contract/test_jsonrpc_contract.py

test-sla:
    python src/tests/performance/test_sla.py

test-upgrade-safe:
    @echo "Verificando XPath válidos..."
    python src/tests/upgrade/test_xpath_validity.py
```

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1 Filosofía | SBOS-COMPLETITUD-v2 §2 B2.3 + investigación web 2024-2026 | Integration-First Testing, pirámide, reglas invariantes — Martin Fowler, DORA 2024, Signadot 2025, Tricentis |
| §2 Tipos (Python/Rust) | SBOS-018 v1.0 | §9 Validadores, §4 Rust tests |
| §2 Tipos (Go) | SBOS-004-RULES v1.1 | §6 estándares Go — cobertura por daemon |
| §2 Tipos (Flutter) | SBOS-020-COREUI v1.0 | Stack técnico Flutter |
| §3 Reglas | SBOS-018 v1.0, SBOS-004-RULES v1.1 | §estándares Bash/Python/Rust/Go |
| §4 CI/CD Gates (tabla) | SBOS-018 v1.0, SBOS-001-OKR v1.0, SBOS-COMPLETITUD-v2 §2 B2.3 | §9 CI/CD, KR-3.2 |
| §4 SonarQube Quality Gate | SBOS-COMPLETITUD-v2 §2 B2.3 + SBOS-COMPLETITUD-v3 T-A8 | Criterio formal: cobertura ≥70%, 0 blocker, 0 critical, major ≤5, hotspots 100%, duplicación <3%. Estado 🔴 + 8 pasos de activación + fecha límite v0.9 Beta |
| §5 Entornos | SBOS-029-PORTABILIDAD v1.0 | §4 multi-entorno |
| §6 Patrones Smart* | SBOSTRY-014-TESTS v1.0 | Pirámide 3-capas, patrones de test para módulos Tryton, Makefile |

---

## Fuentes de Enriquecimiento V8

| Fuente | Ruta | Tipo | Detalle |
|---|---|---|---|
| BOS_V6_SBOS-013-TESTING.md | Procesar/ | V6 Base | Contenido completo preservado |
| SBOSTRY-014-TESTS.md | sbos/subproyectos/SBOS Tryton/context/ | Smart* | Pirámide 3-capas, patrones de test Tryton (account_bo, party_bo, sbos_context), Makefile |
| SBOS-COMPLETITUD-v2 §2 B2.3 | Procesar/ | V5 Referencia | Fundamentos Integration-First Testing |

---

_SKULL · SBOS · SBOS-013-TESTING · V8 · Mayo 2026_
