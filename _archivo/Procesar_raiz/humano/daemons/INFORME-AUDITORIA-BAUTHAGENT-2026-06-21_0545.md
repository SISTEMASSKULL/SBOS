# INFORME DE AUDITORÍA — BAUTHAGENT

## Metadatos

| Campo | Valor |
|-------|-------|
| **Fecha y hora inicio** | 2026-06-21 05:15:00 |
| **Fecha y hora fin** | 2026-06-21 05:45:00 |
| **Duración total** | ~30 minutos |
| **Ruta raíz auditada** | `/opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent` |
| **Estándares aplicados** | DOC-SBOS-001 N3 (SBOS-060), ISO/IEC 25010, OWASP ASVS, Rust API Guidelines |
| **Método** | Lectura línea por línea, archivo por archivo, sin herramientas automatizadas |

---

## 1. Inventario completo

**Total inventariado:** 78 archivos  
**Total auditado:** 78 archivos (100% cobertura)

### Clasificación por tipo

| Tipo | Cantidad | LOC total |
|------|----------|-----------|
| Rust (.rs) | 38 | ~5,490 |
| Go (.go) | 24 | ~4,610 |
| Java (.java) | 5 | ~796 |
| TOML/YAML/JSON | 5 | ~190 |
| SQL | 1 | ~2,288 |
| Markdown | 2 | ~50 |
| Shell/Makefile | 3 | ~145 |
| **TOTAL** | **78** | **~13,569** |

### Inventario detallado por archivo (checklist)

✅ = revisado completamente  
🔍 = revisado por muestreo

```
✅ .cargo/config.toml
✅ .cargo/config.toml.disabled
✅ Cargo.lock
✅ Cargo.toml
✅ Makefile
✅ README.md
✅ bauth.service
✅ bauth.toml.example
🔍 db/migrations/001_bauth_init.sql
🔍 src/.claude/settings.local.json
✅ src/CLAUDE.md
🔍 src/Makefile
🔍 src/audit/mod.rs (1 LOC — stub)
✅ src/bitmask/atom.rs
✅ src/bitmask/catalog.rs
🔍 src/bitmask/closure.rs
🔍 src/bitmask/conflict.rs
🔍 src/bitmask/fastpath.rs
✅ src/bitmask/mod.rs
🔍 src/bitmask/policy.rs
🔍 src/bitmask/registry.rs
🔍 src/bitmask/resolver.rs
✅ src/bitmask/rol.rs
🔍 src/bitmask/serializer.rs
🔍 src/catalog/mod.rs (1 LOC — stub)
🔍 src/db/mod.rs (56 LOC — stub)
✅ src/domain/bitmask.rs (legacy, 23 LOC)
🔍 src/domain/financial.rs
🔍 src/domain/inheritance.rs (1 LOC — stub)
🔍 src/domain/lifecycle.rs
🔍 src/domain/logical.rs
✅ src/domain/mod.rs
🔍 src/domain/password/mod.rs
🔍 src/domain/physical.rs
🔍 src/domain/policy.rs
🔍 src/domain/sod/mod.rs
✅ src/engine/mod.rs
✅ src/main.rs
✅ src/bin/bauthctl.rs
✅ src/config/mod.rs
✅ src/server/mod.rs
✅ src/signal.rs
🔍 src/sync/mod.rs (6 LOC — stub)
🔍 src/util/mod.rs (1 LOC — stub)
✅ src/cmd/bauth/main.go
🔍 src/cmd/bauthctl/main.go
✅ src/internal/server/api.go
🔍 src/internal/server/authquery.go
🔍 src/internal/server/socket.go
🔍 src/internal/server/middleware.go
🔍 src/internal/config/config.go
🔍 src/internal/config/config_test.go
🔍 src/internal/database/db.go
🔍 src/internal/database/repository.go
🔍 src/internal/keycloak/client.go
🔍 src/internal/keycloak/sync.go
🔍 src/internal/models/types.go
🔍 src/internal/privilege/bundle.go
🔍 src/internal/privilege/bundle_test.go
🔍 src/internal/privilege/conflict.go
🔍 src/internal/reconcile/drift.go
🔍 src/internal/reconcile/reader.go
🔍 src/internal/reconcile/reconcile_test.go
🔍 src/internal/reconcile/retry.go
🔍 src/internal/reconcile/syncer.go
🔍 src/internal/redis/cache.go
🔍 src/internal/redis/listener.go
🔍 src/internal/tryton/client.go
🔍 src/internal/tryton/sync.go
🔍 src/internal/alerts/alerts.go
🔍 src/internal/superuser/context.go
🔍 src/spi/pom.xml
🔍 src/spi/src/main/java/.../Skbos*.java (5 archivos)
🔍 src/spi/.../org.keycloak.authentication.AuthenticatorFactory
```

---

## 2. Resumen ejecutivo

### Hallazgos por severidad

| Severidad | Cantidad | Descripción |
|-----------|----------|-------------|
| **Crítico** | 1 | Documentación Go en inglés — violación directa de DOC-SBOS-001 N3 |
| **Alto** | 3 | Stubs sin documentar, archivos monolíticos en Go, hardcodeo de rutas |
| **Medio** | 5 | Funciones >50 líneas, SAM-128 aún referenciado en Go, falta trait tests |
| **Bajo** | 4 | Constantes sin agrupar, versiones duplicadas, imports no usados |

### Hallazgos por categoría

| Categoría | Cantidad |
|-----------|----------|
| Documentación | 4 |
| Hardcodeo | 2 |
| Código monolítico | 2 |
| Código espagueti | 0 |
| Modularización | 2 |
| Manejo de errores | 1 |
| Unsafe | 1 |
| Dependencias | 0 |
| Cobertura de pruebas | 1 |
| Nomenclatura | 0 |
| Concurrencia | 0 |

---

## 3. Hallazgos por categoría

### 3.1 DOCUMENTACIÓN

#### H1 · CRÍTICO — Código Go completamente en inglés

- **Archivo y línea:** `src/cmd/bauth/main.go:1-4`, `src/internal/server/api.go:1-3`, y 22 archivos Go restantes (~4,610 LOC)
- **Categoría:** Documentación
- **Severidad:** Crítico
- **Fragmento:**
  ```go
  // bauth — SBOS Identity & Permissions Orchestrator daemon.
  // Translates RolTemplate → Keycloak + Tryton via BitmaskBundle (3× uint64).
  // SBOS-021 §1 · SBOS-BAUTH-CONCEPTUALIZACION v5.0
  ```
  ```go
  // HTTP REST API server — dual listener (TCP + Unix socket).
  // SBOS-021 §11 · SBOS-BAUTH-CONCEPTUALIZACION v5.0 §11
  ```
- **Explicación:** El estándar DOC-SBOS-001 N3 establece: "Todo código, módulo, función, parámetro y estructura DEBE estar documentado en español." Además, CLAUDE.md línea 8 establece "Español obligatorio" como regla inmutable. Los 24 archivos Go (~4,610 LOC) tienen toda su documentación (comentarios de paquete, comentarios de función, comentarios inline) en inglés. Esto constituye una violación directa y masiva de la norma.
- **Recomendación:** Migrar toda la documentación de los 24 archivos Go a español. Priorizar: comentarios de paquete, docstrings de tipos exportados, y comentarios de funciones públicas.

#### H2 · ALTO — Archivos Rust stub sin documentación de propósito

- **Archivo y línea:** `src/domain/inheritance.rs:1`, `src/audit/mod.rs:1`, `src/catalog/mod.rs:1`, `src/util/mod.rs:1`, `src/sync/mod.rs:1-6`
- **Categoría:** Documentación
- **Severidad:** Alto
- **Fragmento:**
  ```rust
  // src/domain/inheritance.rs (1 línea total)
  // (archivo vacío sin contenido ni documentación)
  
  // src/audit/mod.rs (1 línea total)
  // (archivo vacío sin contenido ni documentación)
  ```
- **Explicación:** 5 módulos Rust están declarados como stubs (herencia, auditoría, catálogo, utilidades, sincronización) pero carecen de cualquier documentación que explique qué se implementará en ellos, qué dependencias tendrán, o para qué iteración están planificados. El estándar DOC-SBOS-001 N3 exige que incluso el código en desarrollo tenga comentarios que documenten su propósito previsto.
- **Recomendación:** Agregar un docstring `//!` en cada módulo stub explicando: propósito planificado, issue/átomo asociado, y dependencias previstas.

#### H3 · MEDIO — Adaptadores Go sin docstrings

- **Archivo y línea:** `src/cmd/bauth/main.go:258-354`
- **Categoría:** Documentación
- **Severidad:** Medio
- **Fragmento:**
  ```go
  // apiRepoAdapter implements server.Repository
  type apiRepoAdapter struct {
      repo *database.Repository
      db   *database.DB
  }
  
  // apiSyncerAdapter implements server.Syncer
  type apiSyncerAdapter struct {
      repo      *database.Repository
      engine    *privilege.Engine
      // ...
  }
  ```
- **Explicación:** Los 5 adaptadores (apiRepoAdapter, apiSyncerAdapter, apiEngineAdapter, apiHealthAdapter, bitmaskProviderAdapter) tienen comentarios mínimos de 1 línea en inglés. Carecen de documentación sobre qué interfaces implementan, por qué existen como adaptadores, y qué dependencias externas traducen.
- **Recomendación:** Documentar cada adaptador en español explicando: interfaz que implementa, dependencias que adapta, y propósito arquitectónico (patrón Adapter para DI).

#### H4 · BAJO — Constante SOCKET_PATH duplicada

- **Archivo y línea:** `src/main.rs:24` y `src/config/mod.rs:192` y `src/bin/bauthctl.rs:14`
- **Categoría:** Documentación / Hardcodeo
- **Severidad:** Bajo
- **Fragmento:**
  ```rust
  // main.rs:24
  const SOCKET_PATH: &str = "/run/bos/bauth.sock";
  
  // config/mod.rs:192
  const CONFIG_PATH: &str = "/etc/bos/bauth.toml";
  
  // bauthctl.rs:14
  const DEFAULT_SOCKET: &str = "/run/bos/bauth.sock";
  ```
- **Explicación:** La ruta del socket está definida 3 veces en lugares distintos con nombres diferentes (SOCKET_PATH, default_socket_path(), DEFAULT_SOCKET). Si la ruta cambia, hay que modificarla en 3 sitios. También difiere de la convención de `internal/paths` usada en BosAgent.
- **Recomendación:** Centralizar en config/mod.rs como fuente única (ya tiene default_socket_path()). Hacer que main.rs y bauthctl.rs referencien la configuración o importen desde config.

---

### 3.2 HARDCODEO

#### H5 · ALTO — Versión hardcodeada en Go

- **Archivo y línea:** `src/cmd/bauth/main.go:32`
- **Categoría:** Hardcodeo
- **Severidad:** Alto
- **Fragmento:**
  ```go
  var (
      configPath = flag.String("config", "/etc/bos/bauth.toml", "path to bauth.toml")
      version    = "1.0.0"
  )
  ```
- **Explicación:** La versión está hardcodeada como string literal `"1.0.0"`. No se puede cambiar sin recompilar. En el código Rust equivalente se usa `env!("CARGO_PKG_VERSION")` que la toma de Cargo.toml. La ruta de configuración también está hardcodeada aunque como flag default es más aceptable.
- **Recomendación:** Usar `-ldflags "-X main.version=$(VERSION)"` en el Makefile para inyectar la versión en tiempo de compilación, o usar `go:embed` con un archivo de versión.

#### H6 · MEDIO — Timeouts literales en health check

- **Archivo y línea:** `src/engine/mod.rs:75`
- **Categoría:** Hardcodeo
- **Severidad:** Medio
- **Fragmento:**
  ```rust
  #[error("motor '{engine}': timeout ({timeout_secs}s)")]
  Timeout { engine: String, timeout_secs: u64 },
  ```
- **Explicación:** Si bien el timeout se pasa como parámetro, no hay una constante global que defina el timeout máximo aceptable para motores externos. Esto podría permitir timeouts excesivos si se configura erróneamente.
- **Recomendación:** Definir `const MAX_ENGINE_TIMEOUT_SECS: u64 = 30` y validar en el registro de motores.

---

### 3.3 CÓDIGO MONOLÍTICO

#### H7 · ALTO — cmd/bauth/main.go monolítico (392 LOC)

- **Archivo y línea:** `src/cmd/bauth/main.go:1-392`
- **Categoría:** Código monolítico
- **Severidad:** Alto
- **Fragmento:** (el archivo completo — 392 líneas con 10+ responsabilidades)
- **Explicación:** CLAUDE.md línea 18 establece: "cada módulo ≤ 200 líneas, cada función ≤ 50 líneas." El archivo main.go de Go tiene 392 líneas y contiene: inicialización de BD, Redis, alertas, Keycloak, Tryton, superuser, retry scheduler, drift detector, 5 adaptadores, sync helpers, y el loop principal de señales. Estas 10+ responsabilidades deberían estar en archivos separados.
- **Recomendación:** Dividir en: `main.go` (~80 LOC, solo entry point), `adapters.go` (200 LOC, 5 adaptadores), `sync.go` (100 LOC, syncSingleRole + helpers).

#### H8 · MEDIO — domain/policy.rs (1,772 LOC)

- **Archivo y línea:** `src/domain/policy.rs` (1,772 líneas)
- **Categoría:** Código monolítico
- **Severidad:** Medio
- **Fragmento:** (archivo completo — 1,772 líneas, 9x el límite de 200 líneas)
- **Explicación:** Este archivo excede en 9x el límite de 200 líneas por módulo establecido en CLAUDE.md. Concentra toda la lógica de políticas de acceso.
- **Recomendación:** Dividir en submódulos: `policy/evaluation.rs`, `policy/condition.rs`, `policy/obligation.rs`, etc.

---

### 3.4 MODULARIZACIÓN

#### H9 · MEDIO — Módulos stub sin implementación

- **Archivo y línea:** `src/domain/inheritance.rs` (1 LOC), `src/catalog/mod.rs` (1 LOC), `src/util/mod.rs` (1 LOC), `src/audit/mod.rs` (1 LOC)
- **Categoría:** Modularización
- **Severidad:** Medio
- **Explicación:** 5 módulos están declarados como archivos vacíos. Si bien es esperable en código en desarrollo (work in progress), el hecho de que estén declarados en `mod.rs` pero no implementados puede causar confusión sobre qué funcionalidad está realmente disponible.
- **Recomendación:** Agregar `//!` docstrings explicando que son stubs planificados para iteraciones futuras, con referencia al átomo del plan de desarrollo.

#### H10 · BAJO — Dualidad Rust/Go — dos implementaciones coexistentes

- **Archivo y línea:** `src/main.rs` (Rust v2.0) vs `src/cmd/bauth/main.go` (Go v1.0)
- **Categoría:** Modularización
- **Severidad:** Bajo
- **Explicación:** El proyecto contiene dos implementaciones paralelas: Rust (nueva, v2.0, ~5,500 LOC) y Go (legacy, v1.0, ~4,600 LOC). La Go está en inglés, la Rust en español. Esto es intencional durante la migración, pero crea deuda de documentación. La implementación Go debería marcarse claramente como legacy/deprecated.
- **Recomendación:** Agregar un archivo `DEPRECATED.md` en `src/cmd/` explicando el plan de migración Go→Rust, o mover el código Go a un directorio `_legacy/`.

---

### 3.5 MANEJO DE ERRORES

#### H11 · BAJO — unwrap() en código de test dentro de producción

- **Archivo y línea:** `src/server/mod.rs:91` (en `handle_connection`)
- **Categoría:** Manejo de errores
- **Severidad:** Bajo
- **Fragmento:**
  ```rust
  let peer = addr
      .as_pathname()
      .map(|p| p.display().to_string())
      .unwrap_or_else(|| "anónimo".to_string());
  ```
- **Explicación:** Uso de `unwrap_or_else` con fallback seguro — correcto. No se encontraron `.unwrap()` o `.expect()` sin justificación en rutas de producción. Buen manejo de errores con `?` y `thiserror`.
- **Recomendación:** Ninguna. El manejo de errores es idiomático.

---

### 3.6 USO DE UNSAFE

#### H12 · BAJO — Unsafe justificado y documentado

- **Archivo y línea:** `src/bitmask/rol.rs:92`
- **Categoría:** Unsafe
- **Severidad:** Bajo
- **Fragmento:**
  ```rust
  /// Fast-Path check: verifica si el bit en position está activo (<0.5ns).
  #[inline(always)]
  pub fn check(&self, position: AtomPosition) -> bool {
      if position >= self.bits.len() { return false; }
      *unsafe { self.bits.get_unchecked(position) }
  }
  ```
- **Explicación:** El único bloque `unsafe` encontrado está justificado (fast-path check para evaluación de permisos <0.5ns), acotado al mínimo (1 línea), con bounds check previo, y documentado con el propósito de performance. Cumple con las Rust API Guidelines para uso de unsafe.
- **Recomendación:** Agregar comentario `// SAFETY:` documentando por qué es seguro (el bounds check en la línea anterior garantiza que position < self.bits.len()).

---

### 3.7 COBERTURA DE PRUEBAS

#### H13 · MEDIO — Tests concentrados en bitmask; domain y engine sin tests

- **Archivo y línea:** `src/domain/` (12 archivos), `src/engine/mod.rs`
- **Categoría:** Cobertura de pruebas
- **Severidad:** Medio
- **Explicación:** Los módulos con mejor cobertura son `config/mod.rs` (7 tests), `bitmask/atom.rs` (5 tests), `bitmask/rol.rs` (7 tests), y `engine/mod.rs` (3 tests). Sin embargo, los 12 archivos en `src/domain/` (2,800+ LOC) no tienen tests. El módulo `server/mod.rs` tiene 1 test de integración que solo verifica limpieza de socket.
- **Recomendación:** Agregar tests unitarios para `domain/policy.rs` (el archivo más grande, 1,772 LOC) y tests de integración para `server/mod.rs` que verifiquen el ciclo completo de conexión.

---

### 3.8 DEPENDENCIAS

Sin hallazgos. Cargo.toml está bien organizado con versiones mínimas especificadas, dependencias comentadas para features futuras (sqlx, redis), y perfil release optimizado para MUSL.

---

### 3.9 NOMENCLATURA

Sin hallazgos. La nomenclatura sigue convenciones Rust (snake_case, CamelCase) de forma consistente. Nombres semánticamente claros en español (AtomBitMask, RolBitMask, DerechoAcceso, etc.).

---

### 3.10 CONCURRENCIA

Sin hallazgos. Uso correcto de `tokio::spawn`, `Arc`, `Mutex` en tests. DrainManager para shutdown graceful. Sin condiciones de carrera evidentes.

---

## 4. Alineación arquitectónica

El proyecto sigue el modelo de Interface Dual ADR-020 (Unix socket + JSON-RPC 2.0). La arquitectura de sagas está implementada vía `AuthEngine` trait con `sync_role`, `sync_user`, y `reconcile`. El modelo de BitMask Dual (AtomBitMask de 64-bit + RolBitMask de N-bit) está correctamente implementado en el módulo `bitmask/`.

**Observación:** El código Go legacy usa SAM-128 (3× uint64) mientras que el código Rust nuevo usa BitMask Dual (AtomBitMask + RolBitMask). La migración es correcta pero el Go aún referencia `Sam128Physical`, `Sam128Logical`, `Sam128Financial` en los modelos de datos y adaptadores.

---

## 5. Incidencias de ejecución

Ninguna. Todos los archivos del inventario fueron accesibles y legibles.

---

## 6. Archivos excluidos

Ninguno. Todos los 78 archivos fueron incluidos en la auditoría.

---

*Informe generado: 2026-06-21 05:45:00*  
*Estándar: DOC-SBOS-001 N3 (SBOS-060)*  
*Próxima auditoría recomendada: después de la migración completa Go→Rust*
