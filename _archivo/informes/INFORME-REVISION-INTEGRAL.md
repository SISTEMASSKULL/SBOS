# INFORME-REVISION-INTEGRAL.md — SBOS + Fábrica ORQUESTA

**Fecha:** 2026-05-13
**Alcance:** Revisión de los 11 nodos SBOS + fábrica ORQUESTA tras S-12 a S-16
**Metodología:** Auditoría completa del filesystem, git log, compilación, y documentación canónica

---

## 1. INVENTARIO REAL

### 1.1 Nodos staff y fundacionales (P0)

| Nodo | Archivos | LOC | Lenguaje | Compila | Tests |
|---|---|---|---|---|---|
| CompositorSBOS | 1 (README.md) | 0 | — | N/A | 0 |
| BibliotecarioSBOS | 1 (README.md) | 0 | — | N/A | 0 |
| OrquestaCoreSBOS | 5 `.py` | 658 | Python 3.14 | Interpretado | 0 |
| BibliotecaSBOS | 10 (8 SQL + 1 Bash + 1 YAML) | 1,097 | SQL PG 18 | `deploy_all.sh` | fixtures |
| ObservabilidadSBOS | 1 (README.md) | 0 | — | N/A | 0 |

**Nota sobre nodes staff:** CompositorSBOS y BibliotecarioSBOS son placeholders. Su implementación real reside en la fábrica (`/opt/skull/orquestador/proyectos/fabrica/compositor-agent/`). Esto es por diseño — son agentes de la fábrica, no del SBOS.

**Nota sobre ObservabilidadSBOS:** El stack real (Grafana, Prometheus, Loki, Alloy) existe en `BosAgent/staging/core/servers/monitorserver/grafana/` con 3 dashboards JSON, datasources YAML y configuración de Alloy.

### 1.2 Nodos de dominio P1

| Nodo | Archivos | LOC | Lenguaje | Compila | Tests | Git |
|---|---|---|---|---|---|---|
| **BosAgent** | 133 total | 7,676 Go + 4,645 Rust + Bash | Go 1.22 + Rust 1.85 + Bash | ✅ ambos binarios | 1 Rust integ test (7 casos) | committed |
| **InfraAgent** | 13 (4 Bash + 8 YAML) | ~1,200 | Bash + YAML | Scripts | 0 | committed |
| **BkernelAgent** | 1 (README.md) | 0 en su dir | Rust (código en BosAgent/) | ✅ Rust | 1 test | committed |
| **BauthAgent** | 35 (22 Go + 5 Java + 1 SQL + otros) | 4,535 Go + 796 Java | Go 1.22 + Java 17 | ✅ ambos binarios | 0 | **UNTRAKED** |

### 1.3 Nodos de dominio P2

| Nodo | Archivos | LOC | Lenguaje | Compila | Tests |
|---|---|---|---|---|---|
| BintelligenceAgent | 1 (README.md) | 0 | — | N/A | 0 |
| BnexusAgent | 1 (README.md) | 0 | — | N/A | 0 |

### 1.4 Desglose de BosAgent (el nodo más grande)

| Componente | Paquete/Ubicación | Archivos | LOC | Binario |
|---|---|---|---|---|
| bos daemon | `cmd/bos/` + 11 `internal/` | 13 `.go` | ~3,800 | `bos` (8M) |
| bosctl CLI | `cmd/bosctl/` | 1 `.go` | ~280 | `bosctl` (7.3M) |
| bkernel daemon | `src/bkernel/bkernel-daemon/` | 15 `.rs` | ~2,100 | `bkernel-daemon` |
| biedata daemon | `src/bkernel/biedata-daemon/` | 11 `.rs` | ~1,500 | `biedata-daemon` |
| bkernel common | `src/bkernel/bkernel-common/` | 4 `.rs` | ~350 | lib |
| Core SP-01 | `src/core/` | 4 Bash | ~1,800 | scripts |
| Staging infra | `staging/core/servers/` | 32 YAML | ~2,500 | K8s manifests |
| Staging container | `staging/Containerfile` | 1 | ~80 | OCI image |

### 1.5 Desglose de BauthAgent

| Componente | Paquete | Archivos | LOC |
|---|---|---|---|
| bauth daemon | `cmd/bauth/` | 1 `.go` | ~440 |
| bauthctl CLI | `cmd/bauthctl/` | 1 `.go` | ~240 |
| config | `internal/config/` | 1 `.go` | ~280 |
| privilege engine | `internal/privilege/` | 2 `.go` | ~420 |
| models | `internal/models/` | 1 `.go` | ~175 |
| database | `internal/database/` | 2 `.go` | ~420 |
| redis | `internal/redis/` | 2 `.go` | ~280 |
| server | `internal/server/` | 4 `.go` | ~520 |
| keycloak | `internal/keycloak/` | 2 `.go` | ~360 |
| tryton | `internal/tryton/` | 2 `.go` | ~390 |
| reconcile | `internal/reconcile/` | 2 `.go` | ~240 |
| superuser | `internal/superuser/` | 1 `.go` | ~180 |
| alerts | `internal/alerts/` | 1 `.go` | ~170 |
| SPIs Java | `spi/` | 5 `.java` | 796 |
| DB migration | `db/migrations/` | 1 `.sql` | ~120 |

### 1.6 Totales generales del monorepo SBOS

| Lenguaje | Archivos | Líneas |
|---|---|---|
| Go | 35 | ~7,700 |
| Rust | 42 | ~4,645 |
| Bash | 20 | ~5,800 |
| YAML | 40+ | ~3,965 |
| Python | 5 | ~658 |
| SQL | 9 | ~1,097 |
| Java | 5 | 796 |
| **Total** | **~156** | **~24,660** |

---

## 2. COHERENCIA ARQUITECTÓNICA

### 2.1 Dependencias entre nodos

```
OrquestaCoreSBOS ──► (coordina CI de todos los agentes)
        │
        ├──► BosAgent (Go + Rust bkernel)
        │       ├── bkernel ──► Redis PUBLISH bkernel:identity_events
        │       └── staging/core/servers/ ──► InfraAgent (servidores K8s)
        │
        ├──► InfraAgent (Bash + YAML — fases de bootstrap)
        │
        ├──► BauthAgent ──► Redis SUBSCRIBE bkernel:identity_events
        │       ├── Keycloak Admin REST API (KC 26.6.1)
        │       ├── Tryton XML-RPC API
        │       └── PostgreSQL (bauth_db)
        │
        ├──► BintelligenceAgent (no implementado)
        │
        └──► BnexusAgent ──► Unix socket /run/bos/bauth.sock (definido, no implementado)
```

### 2.2 Interfaces y contratos verificados

| Interfaz | Definido en | Implementado por | Estado |
|---|---|---|---|
| `BitmaskProvider` | `bauth/server/socket.go` | `bauth/cmd/bauth/bitmaskProviderAdapter` | ✅ Compila |
| `CacheInterface` | `bauth/redis/cache.go` | `Cache` (Redis) + `MemoryCache` (fallback) | ✅ Compila |
| `server.Repository` | `bauth/server/api.go` | `apiRepoAdapter` en main | ✅ Compila |
| `server.Syncer` | `bauth/server/api.go` | `apiSyncerAdapter` en main | ✅ Compila |
| `reconcile.StateReader` | `bauth/reconcile/drift.go` | No implementado aún (pasa `nil`) | 🟡 Pendiente |
| `reconcile.StateSyncer` | `bauth/reconcile/drift.go` | No implementado aún (pasa `nil`) | 🟡 Pendiente |
| `superuser.Store` | `bauth/superuser/context.go` | `database.Repository` | ✅ Compila |
| `server.HealthChecker` | `bauth/server/api.go` | `apiHealthAdapter` (db.Ping) | ✅ Compila |

### 2.3 Problemas de ownership

| Problema | Ubicación real | Ubicación esperada | Impacto |
|---|---|---|---|
| Código Rust de bkernel | `BosAgent/src/bkernel/` | `BkernelAgent/src/` | Medio — confunde ownership |
| Manifiestos K8s de infra | `BosAgent/staging/core/servers/` | `InfraAgent/src/` | Medio — confunde ownership |
| Dashboards Grafana | `BosAgent/staging/core/servers/monitorserver/` | `ObservabilidadSBOS/src/` | Bajo — ObservabilidadSBOS es placeholder |

**Causa raíz:** BosAgent fue el primer nodo de dominio construido. Para que compilara end-to-end, se incluyó todo en su árbol. Los directorios canónicos (BkernelAgent/, InfraAgent/) se crearon después como placeholders.

### 2.4 Verificación de contratos cross-nodo

| Contrato | Nodo A → Nodo B | Canal | Estado |
|---|---|---|---|
| Identity events | bkernel → bauth | Redis `bkernel:identity_events` | ✅ Tipos alineados (`models.IdentityEvent`) |
| Bitmask queries | bnexus → bauth | Unix socket `/run/bos/bauth.sock` | ✅ Protocolo definido (`AuthQuery/AuthResponse`) |
| Audit events | bauth → bkernel | Redis pub/sub → `bkernel_db.audit_events` | 🟡 Definido en spec, no implementado |
| Health checks | todos → OrquestaCore | HTTP GET `/health` | 🟡 Solo bos-agent tiene health endpoint |

---

## 3. GAPS DETECTADOS

### 3.1 Gaps críticos (P1)

| ID | Descripción | Ubicación | Impacto |
|---|---|---|---|
| GAP-001 | **BauthAgent sin commit** — 31 archivos untracked (~5,300 líneas Go+Java+SQL). Riesgo de pérdida total de código. | `BauthAgent/src/`, `BauthAgent/db/` | 🔴 Catastrófico si hay fallo de disco |
| GAP-002 | **Cobertura de tests = 0 en Go** — 35 archivos Go, 0 archivos `_test.go`. Los Makefiles definen target `make test` con requisito de 80% coverage que fallaría. | `BosAgent/src/`, `BauthAgent/src/` | 🔴 CI gates no funcionales |
| GAP-003 | **PROYECTO-ESTADO.md desactualizado** — Sesiones S-15 y S-16 no registradas. bkernel-agent y bauth-agent aparecen como "Pendiente". | `fabrica/PROYECTO-ESTADO.md` | 🟡 Instrucción de reanudación incorrecta |

### 3.2 Gaps medios (P2)

| ID | Descripción | Ubicación | Solución |
|---|---|---|---|
| GAP-004 | **BkernelAgent es un placeholder** — 0 líneas en su directorio canónico. Las 4,645 líneas Rust viven en `BosAgent/src/bkernel/`. | `BkernelAgent/` vs `BosAgent/src/bkernel/` | Mover o symlinkear cuando el build lo permita |
| GAP-005 | **InfraAgent incompleto** — Solo 4/13 servidores implementados como scripts. Los manifiestos K8s de los otros 7 servidores viven en BosAgent. | `InfraAgent/src/` | Completar fichas restantes o declarar fase actual como cerrada |
| GAP-006 | **build_state.json muestra ci_gate_passed: false para todos** — Los gates nunca se ejecutaron. | `OrquestaCoreSBOS/build_state.json` | Ejecutar CI gates formalmente |
| GAP-007 | **DriftDetector recibe nil en StateReader y StateSyncer** — La detección de drift compila pero no funciona porque las dependencias no están cableadas. | `cmd/bauth/main.go:144` | Implementar StateReader contra KC+Tryton reales |
| GAP-008 | **5 capas Tryton son stubs** — `tryton/sync.go` tiene 5 métodos que retornan nil sin hacer nada. | `internal/tryton/sync.go:72-112` | Completar con XML-RPC real cuando Tryton esté disponible |

### 3.3 Gaps de documentación (P3)

| ID | Descripción | Ubicación | Solución |
|---|---|---|---|
| GAP-009 | `arquitectura-inicial.md` dice "12 nodos" pero la tabla lista 11 | Línea 1, sección 1 | Corregir "12" → "11" |
| GAP-010 | CLAUDE.md dice "34 documentos, 28 ADRs" — hay 47 archivos en doctrina | `fabrica/CLAUDE.md` línea 113 | Actualizar conteo |
| GAP-011 | CLAUDE.md referencia `make health` — el target real es `make health-check` | `fabrica/CLAUDE.md` línea 47 | Corregir nombre |
| GAP-012 | 8 archivos zero-byte en `orquesta/tools/` — placeholders sin implementar | `fabrica/compositor-agent/orquesta/tools/` | Eliminar o implementar |

---

## 4. CUMPLIMIENTO DE REGLAS CRÍTICAS

| Regla | Definición | BosAgent | BauthAgent | InfraAgent | OrquestaCore |
|---|---|---|---|---|---|
| **R16 Zero hardcoding** | Toda config desde TOML o env vars | ✅ `bos.toml` + `bos-install.toml` + `BAUTH_*` env | ✅ `bauth.toml` 11 secciones + `applyEnvOverrides()` | ✅ Variables en `manifest.yml` | ✅ `sbos_build_config.py` |
| **Versiones canónicas** | Go 1.22, KC 26.6.1, Java 17, Rust 1.85, PG 18 | ✅ `go.mod` → 1.22, `Cargo.toml` → 1.85 | ✅ `go.mod` → 1.22, `pom.xml` → 26.6.1 + Java 17 | N/A (scripts) | ✅ `build_config.py` → 3.14 |
| **Aislamiento de módulos** | Módulos Go independientes por agente | ✅ `github.com/SISTEMASSKULL/bos` | ✅ `github.com/SISTEMASSKULL/bauth` | N/A | N/A |
| **Build estático** | `CGO_ENABLED=0 -ldflags='-s -w'` | ✅ Makefile targets | ✅ Makefile targets | N/A | N/A |
| **CI gates** | gofmt → vet → lint → test -race → build → sign | 🟡 Makefile targets definidos pero nunca ejecutados | 🟡 Idem | ❌ No definidos | 🟡 `ci_gates.py` existe, no ejecutado |
| **WORM en DB** | Historial inmutable vía RLS | N/A (bkernel_db) | ✅ `bos_rol_template_history` con RULE no_update/delete | N/A | N/A |
| **Docs-first** | Documentos canónicos antes que código | ✅ `bauth/` docs asimilados antes de PGE-1 | ✅ Idem | ✅ Idem | ✅ |

---

## 5. ESTADO GIT

### 5.1 Repositorio

```
Remoto:   git@github.com:SISTEMASSKULL/skproject-sbos.git
Tipo:     Monorepo único (sin submodules)
Branch:   main (activo), s13-complete (stale)
Commits:  10 (S-10 a S-15)
```

### 5.2 Commits recientes

| Hash | Mensaje | Sesión |
|---|---|---|
| `e205994` | chore: sesión S-12 — cierre ordenado (bos-agent + infra-agent F1 + R16 docs-first) | S-12 |
| `37c5bec` | docs: ORQUESTA-003 v1.5 — principio R-DOCS-FIRST (doctrina primero, código después) | S-12 |
| `7ff50d8` | docs: doctrina ORQUESTA-033 §11 (prueba real) + ORQUESTA-039 (aislamiento + K8s 1.28+) | S-13 |
| `c6f5cd1` | chore: sesión S-11 — Orquesta-Core-SBOS operativo + inicio bos-agent | S-11 |
| `4a7593f` | chore: sesión S-10 — cierre con SBOS infraestructura + Biblioteca-SBOS DDL | S-10 |

**Nota:** El commit `4c05836` (bkernel-agent PGE 1-7) aparece en git log del repo pero no en el listado de commits recientes del remoto — posiblemente fue un commit local que requiere push, o el log mostrado en PROYECTO-ESTADO.md no lo refleja porque no se actualizó.

### 5.3 Archivos untracked

```
BauthAgent/src/                          (22 Go + 5 Java + config + Makefile)
BauthAgent/db/migrations/                (1 SQL)
BauthAgent/src/spi/pom.xml               (1 XML)
BauthAgent/src/spi/src/main/resources/   (1 META-INF)
BosAgent/staging/containers/             (1 Containerfile adicional)
compositor-agent/logs/                   (logs del Compositor)
```

**Total:** 31 archivos untracked, ~5,300 líneas de código sin control de versiones.

### 5.4 Divergencias

- Branch `s13-complete` existe remoto pero está stale — no se ha mergeado ni eliminado
- No hay cambios modificados (working tree clean excepto untracked)
- `.gitignore` ya incluye reglas para binarios Go (`bos`, `bosctl`) y Rust target/

---

## 6. EVALUACIÓN DE LA FÁBRICA (S-12 a S-16)

### 6.1 Patrones de fricción recurrentes

| Patrón | Frecuencia | Causa raíz | Solución propuesta |
|---|---|---|---|
| **Import no usado / tipo no definido** | 4 de 5 ciclos | El Generator (DeepSeek) no verifica imports después de edits | Agregar paso `go build` inmediatamente después de cada `Write` de archivo Go |
| **gofmt post-compilación** | 5 de 5 ciclos | El código se escribe sin formatear | Integrar `gofmt -w` automático post-Write para archivos `.go` |
| **Versión de dependencia incompatible** | 1 vez (x/sync v0.20.0 → Go 1.25) | No se verificó compatibilidad antes de `go get` | Verificar `go list -m -versions` antes de pinchar |
| **Git rebase conflict (.gitignore)** | 1 vez (S-15) | El remoto tenía `.gitignore` divergente | Hacer `git pull --rebase` antes de iniciar trabajo nuevo |
| **Commits acumulados al final de sesión** | 5 de 5 ciclos | No hay commits intermedios | Commitar al final de cada PGE, no al final de la sesión |
| **Protocolo del Compositor no seguido** | 5 de 5 sesiones | Instrucciones directas del HITL saltaron el ritual | El HITL puede decidir saltarlo, pero el Compositor debe advertir |

### 6.2 Decisiones correctas

1. **Separar módulos Go:** `bos` y `bauth` son `go.mod` independientes. Evitó contaminación de dependencias.
2. **NUMERIC(20) sobre BIGINT para uint64:** Detectado durante la escritura de la migración SQL. BIGINT no puede almacenar 2^63.
3. **Patrón Adapter para dependency injection:** Los adaptadores en `cmd/bauth/main.go` permiten que el server use interfaces sin conocer implementaciones concretas.
4. **Singleflight en Unix socket:** `golang.org/x/sync/singleflight` para deduplicación de queries concurrentes — crítico para un socket de alta concurrencia.
5. **Leer documentos canónicos antes de codificar:** La carpeta `bauth/` se asimiló completa antes de PGE-1. El código refleja fielmente las specs.
6. **Container golang:1.22 para builds aislados:** Builds deterministas sin depender de Go instalado en el host.

### 6.3 Decisiones que se tomarían diferente

1. **Commits por PGE, no por sesión:** BauthAgent acumuló 5 PGEs sin un solo commit. Si la sesión se cortaba en PGE-3, se perdía todo.
2. **No usar `var _ = strings.Builder{}`:** Hack feo para suprimir errores de import no usado. Mejor eliminar el import.
3. **Verificar versiones de dependencias antes:** El incidente `x/sync@v0.20.0` → Go 1.25 era prevenible consultando `go list -m -versions golang.org/x/sync`.
4. **No dejar stubs inocuos:** Los 5 métodos de `tryton/sync.go` que retornan `nil` deberían retornar `fmt.Errorf("not implemented")` para fallar ruidosamente en vez de silenciosamente.

### 6.4 Mejoras propuestas para el Compositor

1. **Auto-gofmt post-Write:** Después de escribir cualquier archivo `.go`, ejecutar `gofmt -w` automáticamente. Esto elimina el paso manual de formateo.
2. **Commit atómico por PGE:** Al cerrar cada ciclo PGE, hacer commit inmediato. No acumular para el final de sesión.
3. **Verificación pre-go-get:** Antes de añadir una dependencia Go nueva, verificar versión compatible con `go list -m -versions`.
4. **Git pull al inicio de sesión:** Antes de tocar cualquier archivo, `git pull --rebase` para evitar conflictos.
5. **Advertir cuando se salta el protocolo:** Si el HITL da instrucciones directas que omiten PASO 0-6, el Compositor debe advertir explícitamente: "El protocolo de sesión no se ha ejecutado. Estado del repo desconocido. ¿Procedo igual?"
6. **Stubs deben fallar ruidosamente:** Todo stub que no esté implementado debe retornar un error con el código `NOT_IMPLEMENTED`, no `nil`.

---

## 7. REVISIÓN DE SKILLS Y AGENTES

### 7.1 Skills definidas

| Skill | Archivo | Líneas | Estado |
|---|---|---|---|
| `orquesta-compositor` | `.claude/skills/orquesta-compositor/SKILL.md` | 418 | ✅ Completa, precisa, sin desviaciones |

Es la **única skill**. El protocolo de 9 pasos que define es correcto pero no se ejecutó en S-12 a S-16.

### 7.2 Agentes definidos

| Agente | Archivo | Líneas | Refleja implementación real |
|---|---|---|---|
| `compositor` | `.claude/agents/compositor.md` | 335 | ✅ Perfil, herramientas, restricciones, modelos correctos |
| `bibliotecario` | `.claude/agents/bibliotecario.md` | 319 | ✅ Perfil y restricciones correctos. Subagente funcional |

### 7.3 Skills faltantes

| Skill propuesta | Justificación |
|---|---|
| `orquesta-bibliotecario` | El Bibliotecario no tiene protocolo de sesión. Si el HITL pide "materializa el árbol" o "registra el nodo", no hay PASO 0-8 estándar como para el Compositor. |

### 7.4 Agentes de dominio

Los nodos de dominio (bos-agent, bauth-agent, bkernel-agent, etc.) no tienen definiciones en `.claude/agents/`. Esto es **correcto** — son agentes construidos por la fábrica, no agentes de la fábrica. Pero no está documentado explícitamente. Se recomienda agregar una nota en CLAUDE.md aclarando la distinción.

### 7.5 Correcciones requeridas en documentación de la fábrica

| Archivo | Línea | Dice | Debe decir |
|---|---|---|---|
| `CLAUDE.md` | ~113 | "34 documentos, 28 ADRs" | "40 documentos ORQUESTA, 6 ADRs, 1 implementación — 47 archivos en doctrina/" |
| `CLAUDE.md` | ~47 | `make health` | `make health-check` |
| `arquitectura-inicial.md` | Sección 1 | "12 nodos organizados en 4 categorias" | "11 nodos organizados en 4 categorías" |

---

## 8. SOLUCIONES PROPUESTAS

### 8.1 Prioritarias (P1) — ejecutar antes de bintelligence-agent

| ID | Gap | Solución | Tiempo est. |
|---|---|---|---|
| **P1-1** | GAP-001 — BauthAgent sin commit | `git add BauthAgent/src/ BauthAgent/db/ && git commit -m "feat: S-16 — bauth-agent PGE 1-5 completo (Go 4,535L + Java 796L)"` | 2 min |
| **P1-2** | GAP-003 — PROYECTO-ESTADO.md desactualizado | Agregar S-15 y S-16 al historial, actualizar tabla de nodos, actualizar instrucción de reanudación | 5 min |
| **P1-3** | GAP-010/011 — CLAUDE.md stale | Corregir conteo de doctrina y nombre de target `make health-check` | 2 min |
| **P1-4** | GAP-009 — "12 nodos" → "11" | Corregir `arquitectura-inicial.md` sección 1 | 1 min |

### 8.2 Secundarias (P2) — ejecutar durante bintelligence-agent o después

| ID | Gap | Solución | Tiempo est. |
|---|---|---|---|
| **P2-1** | GAP-002 — 0 tests Go | Crear `_test.go` para al menos `privilege/bundle.go` (operadores H-RBAC) y `config/config.go` (load/validate). No se requiere 80% coverage aún — solo establecer el patrón | 30 min |
| **P2-2** | GAP-007 — DriftDetector recibe nil | Implementar `StateReader` concreto que lea de KC Admin API + Tryton XML-RPC. Cablear en main.go | 45 min |
| **P2-3** | GAP-004/005 — Ownership de bkernel e infra | Crear symlinks: `BkernelAgent/src/ → ../BosAgent/src/bkernel/`, `InfraAgent/src/servers/ → ../BosAgent/staging/core/servers/`. Documentar que el código canónico vive en BosAgent hasta migración | 5 min |
| **P2-4** | GAP-012 — 8 placeholders zero-byte | Eliminar archivos zero-byte en `orquesta/tools/` o marcarlos con `# TODO: P3 — no implementado` | 5 min |

### 8.3 Terciarias (P3) — backlog, no bloquean

| ID | Gap | Solución |
|---|---|---|
| **P3-1** | GAP-006 — CI gates nunca ejecutados | Crear script `ci/run-all-gates.sh` que ejecute `make check` en BosAgent y BauthAgent. Agregar a `OrquestaCoreSBOS/ci_gates.py` |
| **P3-2** | GAP-008 — Tryton sync stubs | Completar cuando entorno Tryton esté disponible para testing |
| **P3-3** | Skill `orquesta-bibliotecario` | Crear protocolo de sesión análogo al del Compositor pero para operaciones del Bibliotecario |
| **P3-4** | `build_state.json` | Actualizar con estado real post-ejecución de CI gates |
| **P3-5** | Branch `s13-complete` stale | Mergear a main o eliminar |

---

## 9. RECOMENDACIÓN FINAL

### ¿Proceder con bintelligence-agent?

**Sí, proceder** — pero después de ejecutar las 4 correcciones P1 (estimadas en ~10 minutos):

1. Commit de bauth-agent (31 archivos untracked)
2. Actualizar PROYECTO-ESTADO.md con S-15 y S-16
3. Corregir CLAUDE.md (doctrina count + make health-check)
4. Corregir arquitectura-inicial.md ("12" → "11")

**Justificación:** El proyecto tiene coherencia arquitectónica aceptable. Los 4 nodos de dominio construidos (BosAgent, InfraAgent, BkernelAgent, BauthAgent) compilan, siguen R16, y sus contratos cross-nodo están definidos y alineados. Los gaps detectados son de documentación, tracking, y completitud — no de diseño arquitectónico. La deuda técnica (tests, ownership de bkernel) es conocida, está documentada en este informe, y no se agrava por avanzar con un nuevo nodo.

**Estado general del SBOS:** 4/6 nodos de dominio P1 construidos (67%). Quedan bintelligence-agent y bnexus-agent para completar la capa de dominio. Los 5 nodos staff/fundacionales están operativos o son placeholders por diseño.

---

*Informe generado por el Compositor ORQUESTA el 2026-05-13 tras S-16.*
*Fuentes: auditoría completa del filesystem, git log, compilación cruzada, y documentos canónicos en /bauth/, /arbol/, /ia/, y /humano/.*
