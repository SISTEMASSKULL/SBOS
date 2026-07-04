# Plan de Documentación de Código Desarrollado — Trazabilidad Completa
## CODEX.md: qué hace cada módulo, función, variable · Parámetros · Dependencias · Efectos · v3.0 · Junio 2026
### SKULL · SBOS · Propuesta del Bibliotecario

---

## Prefacio

Este plan define el formato **CODEX.md** — un documento de trazabilidad completa que
documenta el código YA DESARROLLADO. No es una guía de estilo ni un manual de desarrollo
(eso lo hace biblio-dev). Es la documentación del código que existe en disco.

**Objetivo:** Un desarrollador nuevo (o agente IA) debe poder entender el 100% del
funcionamiento de un módulo leyendo su CODEX.md, sin tocar el código fuente.

---

## Parte I — Ejemplo Real: `domain/ficha_service.go` (código de bos YA desarrollado)

### CODEX — bos::domain::ficha_service

**Daemon:** bos (IAM Installer) | **Lenguaje:** Go 1.22+ | **Archivo:** `internal/domain/ficha_service.go` (98 líneas)
**Doc fuente:** SBOS-018-DAEMON-BOS v1.2 | **ADR:** ADR-020 (Interface Dual)

### Resumen

`FichaService` contiene la lógica de negocio de las operaciones sobre fichas SBOS.
Implementa el patrón de **inversión de dependencias**: el dominio define las interfaces
(`InstallerPort`, `StatePort`, `CatalogPort`) y la infraestructura las implementa.
No conoce JSON-RPC, HTTP ni tipos de servidor — es lógica pura.

### Variables y Estructuras

| Nombre | Tipo | Propósito | Inicializado en | Leído por |
|--------|------|----------|----------------|-----------|
| `FichaService.installer` | `InstallerPort` (interface) | Ejecuta sagas de install/update/repair/remove/probe | `NewFichaService()` | `Install()`, `Update()`, `Repair()`, `Remove()`, `Probe()` |
| `FichaService.state` | `StatePort` (interface) | Lee `.sbos_state.json` | `NewFichaService()` | `Status()`, `List()` |
| `FichaService.catalog` | `CatalogPort` (interface) | Lista fichas disponibles en `servers/` | `NewFichaService()` | `List()`, `Status()` |

### Tipos definidos

| Nombre | Tipo | Campos | Propósito | Archivo |
|--------|------|--------|----------|---------|
| `InstallerPort` | interface | `Install()`, `Update()`, `Repair()`, `Remove()`, `Probe()` | Contrato que el instalador debe cumplir. Definido por el dominio. | `ficha_service.go:14` |
| `StatePort` | interface | `Read()` | Contrato para leer el estado persistente | `ficha_service.go:23` |
| `CatalogPort` | interface | `List()`, `Get()` | Contrato para acceder al catálogo de fichas | `ficha_service.go:28` |
| `FichaService` | struct | `installer`, `state`, `catalog` | Servicio de dominio para operaciones sobre fichas | `ficha_service.go:35` |

### Funciones

#### `NewFichaService(ins InstallerPort, st StatePort, cat CatalogPort) *FichaService`
| Propiedad | Valor |
|-----------|-------|
| **Propósito** | Constructor. Inyecta las dependencias (inversión de dependencias). |
| **Parámetros** | `ins`: implementación concreta del instalador (sagas). `st`: lector del estado. `cat`: catálogo de fichas. |
| **Retorna** | Puntero a FichaService inicializado |
| **Procesamiento** | Asigna los 3 parámetros a los campos del struct. Sin lógica adicional. |
| **Llama a** | (ninguna) |
| **Es llamada por** | `server/api.go:45` (inyección de dependencias al crear el servidor) |
| **Efectos** | Ninguno — solo inicializa memoria |

#### `(svc *FichaService) Install(fichaID, version string) (*SagaOutcome, error)`
| Propiedad | Valor |
|-----------|-------|
| **Propósito** | Ejecuta la saga de instalación de una ficha. |
| **Parámetros** | `fichaID`: identificador de la ficha (ej: "postgresql"). `version`: versión a instalar ("" = latest). |
| **Retorna** | `*SagaOutcome`: resultado con FichaID, Command, Success, Duration, StepCount. `error`: si fichaID vacío, instalador no disponible, o saga falla. |
| **Procesamiento** | 1. Valida que fichaID no esté vacío → `ErrFichaIDRequired`. 2. Si version es "", asigna "latest". 3. Verifica que el installer esté disponible → `ErrInstallerUnavailable`. 4. Delega en `svc.installer.Install(fichaID, version)`. 5. Si falla → envuelve error con `ErrSagaFailed`. 6. Si `result.Success == false` → retorna `SagaError` con detalles. 7. Si OK → retorna `SagaOutcome`. |
| **Llama a** | `installer.Install()` → `BosAgent/src/internal/installer/saga.go:89` |
| **Es llamada por** | `server/jsonrpc.go:bos.ficha.install` (handler JSON-RPC), `server/ws.go:handleInstall` (WebSocket CLI) |
| **Efectos** | Cambia el estado de la ficha en `.sbos_state.json` (vía STATE_MANAGER dentro del installer). Crea recursos K8s. |
| **Errores** | `ErrFichaIDRequired` (fichaID vacío), `ErrInstallerUnavailable` (installer nil), `ErrSagaFailed` (fallo en ejecución), `SagaError` (pasos fallidos con detalle) |

#### `(svc *FichaService) Update(fichaID, version string) (*SagaOutcome, error)`
| Propiedad | Valor |
|-----------|-------|
| **Propósito** | Ejecuta la saga de actualización de una ficha. |
| **Parámetros** | `fichaID`: identificador. `version`: versión destino (obligatoria, no acepta ""). |
| **Retorna** | `*SagaOutcome` o error |
| **Procesamiento** | Igual que Install pero: exige versión no vacía → `ErrVersionRequired`. Delega en `svc.installer.Update()`. |
| **Llama a** | `installer.Update()` → `installer/saga.go:145` |
| **Es llamada por** | `server/jsonrpc.go:bos.ficha.update`, `server/ws.go:handleUpdate` |
| **Efectos** | Cambia versión de la ficha en `.sbos_state.json`. Rolling update de pods K8s. |
| **Errores** | `ErrFichaIDRequired`, `ErrVersionRequired`, `ErrInstallerUnavailable`, `ErrSagaFailed` |

---

### CODEX — bos::domain::types

**Archivo:** `internal/domain/types.go` (121 líneas) | **Doc fuente:** SBOS-018 + ADR-021 (18 estados)

### Tipos definidos

| Tipo | Campos | Propósito | Usado por |
|------|--------|----------|-----------|
| `SagaOutcome` | FichaID, Command, Success, ExitCode, Duration, StepCount, FailedSteps | Resultado genérico de cualquier operación saga | `ficha_service.go` (todas las operaciones) |
| `FichaInfo` | ID, State, Version, Health, Server, InstalledAt, UpdatedAt | Estado actual de una ficha en el sistema | `ficha_service.go:Status()`, `server/jsonrpc.go:bos.ficha.status` |
| `FichaDetail` | Embebe FichaInfo + AutoInstall, ExecutionOrder, Dependencies | Estado extendido con metadata del catálogo | `ficha_service.go:List()` |
| `BootstrapStatus` | Progress, Total, Completados, Instalando, Alerta, Pendientes, Bloqueadas | Progreso del bootstrap (18 estados ADR-021) | `bootstrap_service.go` |
| `CertCriterion` | ID, Nombre, OK, Detalle | Un criterio de certificación C-01 a C-13 | `bootstrap_service.go:Verify()` |
| `VerifyResult` | Criterios, Passed, Total, Certified, Timestamp | Resultado de verificación de certificación | `bootstrap_service.go:Verify()` |
| `CtxID` | TenantID, EmpresaID, SucursalID, PosLogico, UserID, TraceParent, SpanID, CreatedAt, ExpiresAt, Source | Contexto operativo (SBOS-049, W3C Trace Context) | `ctx_service.go` |
| `ValidateResult` | Valid, TraceParent, TenantID | Resultado de validar un traceparent W3C | `ctx_service.go` |
| `BootstrapStartResult` | BootstrapID, Mode, Total, Completados | Resultado de iniciar el bootstrap | `bootstrap_service.go` |
| `PgAuxiliarStatus` | Phase, Progress, CurrentStep, BytesCopied, BytesTotal, StartedAt, Duration, PodName, Error, WALOffset | Estado en tiempo real del PG auxiliar anti-pérdida | `pg_auxiliar_service.go` |
| `PgAuxiliarResult` | Success, Operation, PodName, Duration, BytesTotal, WALOffset, Error | Resultado final de operación pg_auxiliar | `pg_auxiliar_service.go` |

---

## Parte II — Formato CODEX.md (Plantilla Oficial)

```markdown
# CODEX — <daemon>::<módulo>
**Daemon:** <nombre> | **Lenguaje:** <Rust|Go> | **Archivos:** <N> (<lista de nombres>)
**Doc fuente:** <BOS_V8 o DAEMON-* de referencia> | **ADR:** <ADR aplicables>

## Resumen
[2-3 frases explicando qué hace este módulo en el ecosistema SBOS. Sin detalles de implementación.]

## Variables y Estructuras
| Nombre | Tipo | Propósito | Inicializado en | Leído por |
|--------|------|----------|----------------|-----------|
| <campo> | <tipo> | <para qué sirve> | <función que lo crea> | <funciones que lo usan> |

## Tipos definidos
| Tipo | Campos | Propósito | Archivo |
|------|--------|----------|---------|
| <NombreStruct> | <lista de campos> | <qué representa> | <archivo:línea> |

## Funciones
### `<NombreCompleto(params) -> retorno>`
| Propiedad | Valor |
|-----------|-------|
| **Propósito** | <qué hace, en una frase> |
| **Parámetros** | <cada param: tipo, qué representa, valores válidos> |
| **Retorna** | <tipo de retorno, qué significa cada caso> |
| **Procesamiento** | <paso a paso, transformaciones, decisiones> |
| **Llama a** | <lista de funciones con archivo y número de línea> |
| **Es llamada por** | <lista de funciones con archivo y número de línea> |
| **Efectos** | <qué cambia: BD, archivos, memoria, estado, red> |
| **Errores** | <qué errores retorna y bajo qué condiciones> |

## Dependencias
### Este módulo USA:
| Módulo/Archivo | Qué usa | Para qué |
|---------------|---------|----------|

### Este módulo ES USADO por:
| Módulo/Archivo | Qué función usa | Cuándo |
|---------------|----------------|--------|

## Flujo de Ejecución
[ASCII o pasos numerados del flujo principal del módulo]
```

---

## Parte III — Cómo generar un CODEX.md

### Paso 1 — Identificar el módulo
```bash
# Listar los archivos .go o .rs del módulo
find internal/<modulo>/ -name "*.go" ! -name "*_test.go"
```

### Paso 2 — Extraer funciones públicas
```bash
# Go
grep -n "^func \|^func (.*) " internal/<modulo>/*.go

# Rust
grep -n "^pub fn \|^pub async fn " src/<modulo>/*.rs
```

### Paso 3 — Extraer tipos y structs
```bash
# Go
grep -n "^type " internal/<modulo>/*.go

# Rust
grep -n "^pub struct \|^pub enum " src/<modulo>/*.rs
```

### Paso 4 — Completar la plantilla
Usar la plantilla de Parte II. Para cada función, responder: qué hace, params, retorna, procesamiento, a quién llama, quién la llama, efectos, errores.

---

## Parte IV — Responsabilidades

| Quién | Qué hace |
|-------|---------|
| **Desarrollador** | Completa el CODEX.md del módulo que acaba de desarrollar. Es parte del "definition of done". |
| **Bibliotecario** | Audita que existen CODEX.md para todos los módulos. Actualiza la plantilla si es necesario. |
| **sbos-coordinador** | Verifica que el CODEX.md referencia los ADRs y docs fuente correctos. |

---

_SKULL · SBOS · Plan de Documentación de Código Desarrollado · v3.0 · Junio 2026_
_Basado en código real de bos (domain/ficha_service.go, domain/types.go)_
