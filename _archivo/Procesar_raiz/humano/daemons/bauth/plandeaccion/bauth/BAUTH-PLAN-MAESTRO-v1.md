# BAUTH-PLAN-MAESTRO-v1 — Plan de Desarrollo Atómico
## bAuth: Sistema de Identidad Soberano · SBOS

**Versión:** 1.0 · **Fecha:** 2026-06-19 · **Estado:** VIGENTE · BitMask Dual Jun 2026
**Ruta:** `context/sbos/Procesar/humano/daemons/bauth/plandeaccion/bauth/BAUTH-PLAN-MAESTRO-v1.md`
**Código fuente:** `/opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent/src/`
**Documentos canónicos:** `context/sbos/Procesar/humano/daemons/bauth/plandeaccion/bauth/`
**Tracking:** `REGISTRO-ESTADO.md`

---

> ⚠️ **CORRECCIÓN BITMASK — JUNIO 2026:** Las referencias al modelo BitMask (SAM-128, "2 capas", "BitmaskBundle", "7×64 bits") en este documento corresponden al diseño anterior. El modelo actual es el **BitMask Dual**: BitMask Átomo 64-bit (label encoding) + Rol BitMask N-bit (one-hot encoding). Para desarrollo, usar: `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`, `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7, `SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md` v2.1.

---

## PARTE I — VISIÓN Y ALCANCE

### 1. Qué es bAuth

bAuth es el **sistema de identidad del SBOS.** No es un simple sincronizador ni un wrapper
de Keycloak. Es el orquestador que unifica la identidad en todo el ecosistema:

- **Keycloak** es el IdP (brazo de autenticación)
- **Tryton** es el ERP (brazo de autoridad de negocio)
- **bAuth** es el cerebro que los sincroniza y gobierna

> El SBOS no consulta Keycloak directamente. No consulta Tryton directamente.
> El SBOS consulta bAuth.

### 2. Las 6 Responsabilidades

| # | Responsabilidad | Componente |
|---|---------------|------------|
| R1 | **Sincronizador Maestro** | Traduce RolTemplate → objetos nativos KC + Tryton. < 5s |
| R2 | **Motor de Privilegios** | BitMask Dual: BitMask Átomo 64-bit (label) + Rol BitMask N-bit (one-hot). DAG con OR sobre posiciones independientes |
| R3 | **Evaluador en Tiempo Real** | Unix socket `/run/bos/bauth.sock`. Fast-Path < 0.5ns, Policy-Path < 5ms |
| R4 | **Interfaz de Administración (PAP)** | CRUD de Roles y Usuarios. Única puerta de entrada |
| R5 | **Gestor de Identidad Física** | QR dinámicos, hashes biométricos, NFC/RFID |
| R6 | **Guardián de SoD y Cumplimiento** | Conflict Matrix estática + Auditoría WORM + D12 Blockchain verificable |

### 3. Stack tecnológico

| Componente | Tecnología | Propósito |
|-----------|-----------|-----------|
| **Daemon** | **Rust 1.85+** (MUSL, LTO, tokio) | Lógica de negocio, sync, API | Latencia determinista sin GC, memory safety, ecosistema unificado con bkernel |
| SPIs | Java 17 | 5 plugins para Keycloak |
| IdP | Keycloak 26.6.2 | Autenticación |
| ERP | Tryton 7.4 | Autoridad de negocio |
| Cache | Redis 8.6.2 | Rol BitMask cache TTL 30s + ctx_id session registry |
| BD | PostgreSQL 18.4 | bauth_db (roles, usuarios, conflictos) |
| Socket | Unix `/run/bos/bauth.sock` | API Dual (WebSocket + JSON-RPC) |
| Métricas | :9450 (Prometheus) | Solo ClusterIP |
| Health | :9451 (GET only) | Solo ClusterIP |

---

## PARTE II — POLÍTICAS GLOBALES DE DESARROLLO

### P1 — Atomicidad de tareas

Cada tarea en el REGISTRO-ESTADO es atómica: tiene un ID único, un entregable concreto
y un criterio de aceptación MEDIBLE.

### P2 — Testing first

- **Unit tests:** `go test ./...` — coverage ≥ 80% en privilege, sync, server
- **Integration tests:** Keycloak real + Tryton real en VPS
- **Load tests:** k6 para API Unix socket (10K RPS)

### P3 — Diseño (SOLID + Go idioms)

- **S** — cada paquete una responsabilidad (privilege, keycloak, tryton, server)
- **O** — nuevos métodos de auth = nueva implementación de interfaz, sin tocar core
- **L** — interfaces Go sustituibles: `Syncer`, `PrivilegeComputer`, `AuthValidator`
- **I** — interfaces pequeñas y enfocadas
- **D** — dependencia de interfaces, no de implementaciones concretas

### P4 — Documentación sincronizada

Cada átomo completado actualiza simultáneamente:
1. `REGISTRO-ESTADO.md` — fila del átomo → ✅ con commit SHA
2. `LOG-DE-SESIONES.md` — entrada con fecha, átomo, resumen
3. Documento canónico asociado si el átomo cambia la arquitectura

### P5 — Interface Dual obligatoria (ADR-020)

Todo feature expuesto por dos vías sobre el MISMO Unix socket:
- **Vía 1:** WebSocket RPC → CLI (`bauthctl`), Core UI
- **Vía 2:** JSON-RPC 2.0 → biedata, bkernel, agentes IA

### P6 — Puertos (SBOS-050)

| Puerto | Propósito | Exposición |
|--------|-----------|------------|
| 9450 | `/metrics` Prometheus | Solo ClusterIP |
| 9451 | `/health` GET only | Solo ClusterIP |
| — | Cualquier otro puerto | **PROHIBIDO** |

---

## PARTE III — PLAN ATÓMICO POR FASES

### B0 — ESQUELETO DEL BINARIO Y CI (8 átomos)

**B0.E1.T1** — Workspace Go + estructura de módulos
- Entregable: `go.mod`, `cmd/bauth/main.go`, `cmd/bauthctl/main.go`, 13 paquetes `internal/`
- Criterio: `go build ./...` OK; `go vet ./...` limpio
- SSOT: BAUTH-050

**B0.E1.T2** — Build estático + budget
- Entregable: `CGO_ENABLED=0 go build -ldflags="-s -w"`
- Criterio: `file bauth` reporta "statically linked"; < 25MB
- SSOT: C-08

**B0.E1.T3** — Config TOML + carga tipada
- Entregable: `bauth.toml` + structs Go con validación
- Criterio: boot con config inválida falla con error explícito
- SSOT: BAUTH-050

**B0.E1.T4** — Señales SIGTERM/SIGHUP
- Entregable: graceful shutdown + hot-reload de templates
- Criterio: SIGHUP no mata el proceso; SIGTERM sale ≤ 5s
- SSOT: BAUTH-010

**B0.E1.T5** — systemd unit + sd_notify
- Entregable: `bauth.service` Type=notify, WatchdogSec=30
- Criterio: `systemctl start/stop/status` OK
- SSOT: BAUTH-180

**B0.E1.T6** — Unix socket `/run/bos/bauth.sock`
- Entregable: socket 0660 grupo `bosagent`. Interface Dual (WebSocket + JSON-RPC)
- Criterio: `bosctl` puede consultar vía socket. Sin TCP
- SSOT: ADR-020, SBOS-050 P9

**B0.E1.T7** — CI pipeline
- Entregable: GitHub Actions: build + vet + test + lint
- Criterio: pipeline verde en commit vacío
- SSOT: ECO-007

**B0.E1.T8** — Métricas :9450 + health :9451
- Entregable: endpoints Prometheus + health check
- Criterio: solo ClusterIP, GET only, resto → 405
- SSOT: BAUTH-110

---

### B1 — PRIVILEGE ENGINE + SAM-128 (8 átomos)

**B1.E1.T1** — Tipos BitMask 64-bit
- 3 dominios: PhysicalDomainMask, LogicalDomainMask, FinancialDomainMask
- Operaciones bit a bit: Has, Add, Remove, IsZero
- SSOT: SAM-128

**B1.E1.T2** — PrivilegeEngine — cálculo H-RBAC
- Herencia automática vía AND NOT. Sin errores humanos
- `ComputeBundle(templates) → BitmaskBundle` en < 5ms
- SSOT: BAUTH-020

**B1.E1.T3** — Conflict Matrix — SoD
- 20+ conflictos predefinidos (ej: quien crea facturas NO puede aprobarlas)
- Evaluada ANTES de guardar cualquier RolTemplate
- SSOT: BAUTH-020

**B1.E1.T4** — RolTemplate CRUD
- CRUD completo con validación de herencia circular
- SSOT: BAUTH-040

**B1.E1.T5** — UserTemplate CRUD
- Asignar/revocar roles. Cálculo automático de BitmaskBundle
- SSOT: BAUTH-040

**B1.E1.T6** — DDL bauth_db
- Tablas: rol_templates, user_templates, conflict_matrix, bitmask_bundles
- SSOT: BAUTH-130

**B1.E1.T7** — JSON-RPC `bauth.roltemplate.*`
- CRUD vía Unix socket. Interface Dual ADR-020
- SSOT: ADR-020

**B1.E1.T8** — Tests unitarios PrivilegeEngine
- Cobertura ≥ 80%. Tests de herencia, conflicto, bitmask
- SSOT: BAUTH-050

---

### B2 — SINCRONIZACIÓN KC ↔ TRYTON (7 átomos)

**B2.E1.T1** — Keycloak Admin Client (Go)
- CRUD vía REST API: realms, roles, users, groups
- SSOT: BAUTH-060

**B2.E1.T2** — Tryton Sync Client
- CRUD vía XML-RPC: grupos y usuarios
- SSOT: BAUTH-060

**B2.E1.T3** — Sincronizador Maestro
- `RolTemplate → KC role + Tryton group` atómico con rollback en < 5s
- SSOT: BAUTH-060

**B2.E1.T4** — Reconcile Loop 60s
- Detecta drift entre KC/Tryton y bauth_db. Corrige automáticamente
- SSOT: BAUTH-060

**B2.E1.T5** — Cache Redis TTL 30s
- Cache de BitmaskBundle + roles. Lookup < 1ms P50
- SSOT: BAUTH-110

**B2.E1.T6** — SPIs Java 17 para Keycloak
- 5 interfaces: BosRolTemplate, FinancialDomain, PhysicalDomain, LogicalDomain, TemporalContext
- SSOT: BAUTH-070

**B2.E1.T7** — Tests integración KC + Tryton
- End-to-end: guardar RolTemplate → verificar KC + Tryton
- SSOT: BAUTH-050

---

### B3 — API UNIX SOCKET + EVALUADOR (6 átomos)

**B3.E1.T1** — Servidor Unix socket WebSocket RPC
- `/run/bos/bauth.sock` 0660. Handlers: authquery, validate, userinfo
- SSOT: ADR-020

**B3.E1.T2** — Servidor JSON-RPC 2.0
- Mismo socket. `bauth.auth.validate`, `bauth.user.info`, `bauth.ctx.create`
- SSOT: ADR-020

**B3.E1.T3** — Auth Query en tiempo real
- Valida JWT + bitmask + LoA + expiry. < 5ms P99 con cache
- SSOT: BAUTH-080

**B3.E1.T4** — Context API (SBOS-049)
- `bauth.ctx.create` + `bauth.ctx.validate`. ctx_id para trazabilidad
- SSOT: SBOS-049

**B3.E1.T5** — Kong Plugin SBOS-Context
- Plugin Lua para Kong. Valida ctx_id contra bAuth antes de enrutar
- SSOT: BAUTH-090

**B3.E1.T6** — Tests de carga 10K RPS
- k6: 50 VUs, 200 RPS/VU. P99 < 5ms con cache caliente
- SSOT: BAUTH-PERF

---

### B4 — IDENTIDAD FÍSICA + SEGURIDAD (5 átomos)

**B4.E1.T1** — QR dinámicos HMAC-SHA256
- TTL 30s configurable. Un solo uso. Validación vía bhnexus
- SSOT: BAUTH-100

**B4.E1.T2** — Hashes biométricos PBKDF2-SHA256
- Tabla `bauth_biometric_templates`. Nunca almacena datos crudos
- SSOT: BAUTH-100

**B4.E1.T3** — Validación NFC/RFID vía bhnexus
- Integración con bhnexus para hardware tokens
- SSOT: BAUTH-100

**B4.E1.T4** — SuperUser break-glass
- Acceso de emergencia con auditoría completa
- SSOT: BAUTH-100

**B4.E1.T5** — Audit events ISO 27001
- Todo evento → `bkernel_db.audit_events`. ctx_id obligatorio
- SSOT: ISO-27001

---

### B5 — FICHA DECLARACIÓN BOS (4 átomos)

**FICHA.T1** — manifest.yml
**FICHA.T2** — task_catalog.sh
**FICHA.T3** — DDL bauth_db
**FICHA.T4** — Integración en deploy.go + seed

---

## PARTE IV — CRITERIOS DE CERTIFICACIÓN (8)

| ID | Criterio | Condición |
|----|----------|-----------|
| C-01 | Build limpio | `go build ./...` + `go vet ./...` sin errores |
| C-02 | Tests verdes | `go test ./...` 100% pass |
| C-03 | PrivilegeEngine | `ComputeBundle()` < 5ms con 100+ roles |
| C-04 | Sync KC+Tryton | RolTemplate guardado → KC + Tryton en < 5s |
| C-05 | Reconcile loop | Detecta drift en ≤ 60s. Corrige automáticamente |
| C-06 | Unix socket API | Consulta auth → respuesta < 5ms P99 con cache caliente |
| C-07 | Conflict Matrix | Detecta conflicto SoD ANTES de guardar |
| C-08 | Audit events | ctx_id en todo evento de auditoría (ISO 27001) |

---
*BAUTH-PLAN-MAESTRO-v1 · 2026-06-19 · SKULL · 38 átomos · 5 gates*
