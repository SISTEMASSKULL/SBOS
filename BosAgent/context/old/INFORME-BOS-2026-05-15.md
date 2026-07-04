# Informe de Desarrollo BOS — 2026-05-15

## Resumen Ejecutivo

El SBOS IAM Installer (bos-agent) está al **~65% global**. El Bash engine (Core SP-01) está al 95%, el daemon Go al 75% estructural, la CLI al 50%, y la UI Flutter al 0%. El subproyecto **SBOS IAM Style** (Gobernador de Identidad Visual) está especificado al 100% (v3.3.3, 30 documentos) pero no implementado.

---

## 1. Estado Actual por Componente

### C1 — bos daemon (Go 1.22+)

**Estado: 75% estructural — 3,344 líneas en 13 archivos**

| Package | Archivo | Líneas | Estado |
|---|---|---|---|
| cmd/bos | main.go | 257 | Completo — entrypoint, señales, heartbeat, 2 modos |
| internal/config | config.go | 302 | Completo — TOML + env overrides + validate |
| internal/state | manager.go | 310 | Completo — flock, transiciones, hashes |
| internal/server | api.go | 506 | Completo — REST + Unix socket + WebSocket hub |
| internal/server | ws.go | 181 | Completo — WebSocket broadcast |
| internal/installer | saga.go | 325 | Completo — Saga orchestrator |
| internal/installer | compensator.go | 134 | Completo — Rollback compensation |
| internal/k8s | core.go | 220 | Completo — Wrapper kubectl con dry-run |
| internal/plugin | loader.go | 220 | Completo — Escanea servers/, hashes SHA-256 |
| internal/health | checker.go | 182 | Parcial — no ejecuta health probes |
| internal/reconcile | scheduler.go | 155 | Parcial — no compara SHA-256 real vs declarado |
| internal/release | manager.go | 234 | Parcial — falta verificación Ed25519 |
| cmd/bosctl | main.go | 318 | Parcial — 5 de 15+ comandos |

**Gaps:** 0 tests, health checker sin probes reales, reconcile sin drift detection, sin DEPENDENCY_RESOLVER.

### C2 — bosctl CLI (Go 1.22+)

**Estado: 50% — 318 líneas.** Implementados: status, install, health, logs, reload, help.  
Faltantes: update, repair, remove, probe, lint, version, fichas, product (list/install), tenant, deploy, update-daemon, rollback.

### C3 — Core SP-01 (Bash 5.x)

**Estado: 95% — 5 archivos master + 456 archivos de fichas (114 × 4).**
112/112 fichas corregidas con patrones P20-P22. 18/18 fichas certificadas HEALTHY en sbos-k8s.

### C4 — Core UI (Flutter/Dart)

**Estado: 0% — no iniciado.** Bloqueado por VDI server + SBOS IAM Style.

### SBOS IAM Style (bstyle) — Gobernador de Identidad Visual

**Estado: 100% especificado, 0% implementado. 30 documentos en v3.3.3.**

Subproyecto alojado en `subproyectos/SBOS-IAM-Style/`. NO es un Smart Module — es un **Gobernador de Core**, al mismo nivel arquitectónico que Keycloak (autenticación) y PostgreSQL (datos).

| Campo | Valor |
|---|---|
| Nombre comercial | SBOS IAM Style |
| Marca interna | `bstyle` |
| Categoría | **Gobernador de Core** — no Smart[X] ni Daemon |
| Color de capa | Sky `#0EA5E9` (sky-500) |
| Protocolo | **WebSocket** (no HTTP) |
| Modo standalone | Sí — independiente del ecosistema SBOS |
| Modo integrado | Sí — Design Governor del ecosistema SBOS |
| Eslogan | "Imprime tu marca. Gobierna tu estilo." |

**Arquitectura interna (K8s pod en namespace core):**

| Componente | Función |
|---|---|
| brand-worker | Orquestador reactivo, escucha eventos del bKernel vía WAL |
| brand-api | Servidor WebSocket, distribuye tokens visuales a suscriptores |
| brand-engine | Motor generador Python (familia 06_*), 79 destinos, 12 composiciones |
| brand-db | Schema propio en PostgreSQL (9 tablas): empresas, paletas, colores, formatos, composiciones, productos, históricos |

**Stack técnico:**
- Python 3.12+ (generador: resvg-py, lxml hardening, ruamel.yaml, Pillow+FreeType)
- PostgreSQL 18 (brand-db)
- MinIO (4 buckets: svg-sources, assets, yamls, fonts)
- Flutter Desktop (Brand Composer v2.1 — editor visual de composiciones)
- Style Dictionary + ForUI (SSOT) → PrimeVue / SCSS / GTK

**Documentos del subproyecto (30 archivos):**

| Bloque | Archivos | Contenido |
|---|---|---|
| Brand System (01-09) | 9 | Visión, identity book, color reference (22 familias × 5 formatos), design system (ForUI SSOT), theming governance, dev environment |
| Logo Generator (06-*) | 14 | Composition engine, color/modes, runtime text, Python API (9 endpoints), validations (43 ERR + 44 WARN), SVG preparation, YAML templates, destinations catalog (79), SVG vocabulary, Brand Composer Flutter, formats/rendering, DB schema |
| Gestión (20-24) | 5 | README, CHANGELOG v3.2→v3.3.3, migración, auditoría, obsolescencia |
| Históricos (99-*) | 3 | Documentos reemplazados (no activos) |

---

## 2. Arquitectura de 3 Planos + Gobernadores

```
SKULL ©
└── SBOS
    ├── GOBERNADORES (namespace: core)
    │   ├── Keycloak     → Identidad y Autenticación
    │   ├── PostgreSQL   → Datos y Bus de Eventos
    │   └── IAM Style    → Identidad Visual Corporativa · Sky #0EA5E9
    │
    ├── Capa 1 — Smart[X]  · Cyan #06B6D4
    └── Capa 2 — Daemons   · Red #DC2626
```

IAM Style opera como **K8s pod en namespace core**, junto a Keycloak. No como daemon systemd — consume eventos publicados por bKernel, no necesita acceso directo al WAL.

---

## 3. Gaps Críticos

| # | Gap | Componente | Severidad | ¿Bloqueante? |
|---|---|---|---|---|
| 1 | 0 tests unitarios en Go | C1 | CRÍTICO | Sí |
| 2 | Health checker no ejecuta probes | C1 | ALTO | Sí |
| 3 | Reconcile no detecta drift por hash | C1 | ALTO | Sí |
| 4 | bosctl faltan 10+ comandos | C2 | ALTO | Sí |
| 5 | SBOS IAM Style sin implementar | bstyle | CRÍTICO | Sí — bloquea Core UI |
| 6 | VDI server incompleto | Infra | CRÍTICO | Sí — bloquea Core UI |
| 7 | Core UI Flutter no existe | C4 | MEDIO | No hasta resolver #5 y #6 |

---

## 4. Gobernanza Dual: Keycloak + IAM Style

**Toda aplicación del ecosistema SBOS se desarrolla bajo dos Gobernadores transversales:**

| Gobernador | Dominio | Protocolo | Color |
|---|---|---|---|
| **Keycloak** | Autenticación e identidad | OIDC + JWT | — |
| **IAM Style** | Identidad visual corporativa | WebSocket | Sky `#0EA5E9` |

**Principio SSOT:** Keycloak es la fuente de verdad de QUIÉN eres y qué puedes hacer.
IAM Style es la fuente de verdad de CÓMO se ve todo. Ninguna aplicación tiene su propio
auth ni sus propios colores — consumen ambos Gobernadores.

---

## 5. Plan para Terminar (9 Ciclos)

### Ciclo 1 — Completar bos daemon Go (75% → 95%)
- PGE-1.1: Tests de state y config (testify)
- PGE-1.2: Health checker con ejecución de probes
- PGE-1.3: Reconcile scheduler con SHA-256 drift detection
- PGE-1.4: DEPENDENCY_RESOLVER (DAG, Kahn)

### Ciclo 2 — Completar bosctl CLI (50% → 100%)
- PGE-2.1: update, repair, remove, probe, lint + internal/client + internal/output
- PGE-2.2: version, fichas, product, tenant (skeleton)

### Ciclo 3 — Pulir Bash engine + CI gates (95% → 100%)
- PGE-3.1: Shellcheck + validate_sp01.py + validate_sp02.py
- PGE-3.2: Stubs P14-P18 en Bash

### Ciclo 4 — SBOS IAM Style: Implementar desde spec v3.3.3 (0% → 100%)
- PGE-4.1: Sprint 0 — Infraestructura (Containerfile Podman, compose.yaml, PostgreSQL 18 + MinIO, seed)
- PGE-4.2: Sprint 1 — Design tokens (Style Dictionary, project_theme, tokens Dart/SCSS/CSS)
- PGE-4.3: Sprint 2 — Motor generador Python (CLI, pipeline render, datasets, imagen runtime)
- PGE-4.4: Sprint 3 — API REST FastAPI (12 endpoints, OpenAPI 3.1, auth switcheable, caché SHA-256)
- PGE-4.5: Sprint 4 — CI/CD + MCP server + Manifests K8s + backups
- PGE-4.6: Sprint 5 — Brand Composer Flutter Desktop v2.1 + WebSocket server (brand-api)

### Ciclo 5 — Keycloak + Tryton + OrangeHRM: Gobernadores Core + fuente de usuarios
- PGE-5.1: Desplegar Keycloak 26.1 + realm SBOS + 5 SPIs Bauth
- PGE-5.2: Desplegar Tryton 7.4 + trytond-auth-keycloak
- PGE-5.3: Desplegar OrangeHRM 6.0 + estructura organizacional seed
- PGE-5.4: Prueba de integración OIDC entre los 3 Gobernadores

### Ciclo 6 — bKernel: CDC WAL + Rule Engine + Identity Events (~60% → 95%)
- PGE-6.1: Completar WAL reader — decodificación pgoutput (column names + values)
- PGE-6.2: Completar condition matcher — jq completo sobre JSONB
- PGE-6.3: Completar writer executor — UPDATE + DELETE
- PGE-6.4: Reglas OHRM-001/002/003 + ROLF-001/002 (5 archivos YAML)
- PGE-6.5: Tests de integración con PostgreSQL real
- PGE-6.6: Systemd + ficha K8s para bKernel

### Ciclo 7 — BauthAgent: Gobernanza de Identidad y Permisos (80% → 100%)
- PGE-7.1: Completar API handlers (6 endpoints que retornan 501)
- PGE-7.2: Completar Tryton sync capas 3-5 (field_access, button_rules, record_rules)
- PGE-7.3: Unix socket bhnexus + BitMask engine (64 bits, 3 dominios)
- PGE-7.4: Desplegar como daemon + ficha K8s

### Ciclo 8 — VDI Server: Escritorios Virtuales Soberanos (15% → 100%)
- PGE-8.1: Containerfile Fedora KDE SBOS (7 capas: KDE + bAuth Client + sbos-vdi-run + PAM + iptables + Squid helper)
- PGE-8.2: Completar health checks reales en 3 fichas
- PGE-8.3: NFS + Squid + red VDI
- PGE-8.4: Integración VDI ↔ bos daemon

### Ciclo 9 — Core UI Flutter + Brand Composer: PAP de Roles + Pruebas
- PGE-9.1: Core UI skeleton + API client (conexión al daemon)
- PGE-9.2: Pantallas de identidad (PAP): RolTemplate editor, UserTemplate assignment
- PGE-9.3: Pantallas de operaciones: catálogo de fichas, detalle, log
- PGE-9.4: Brand Composer — pruebas de integración sobre VDI
- PGE-9.5: Manifiestos de producto (core-ui + brand-composer)

---

## 6. Cadena de Dependencias (Completa)

```
╔══════════════════════════════════════════════════╗
║     GOBERNANZA DUAL (transversal a todo)         ║
║  Keycloak (auth) + IAM Style (visual)            ║
╚══════════════════════════════════════════════════╝

C1 (daemon Go) ──► C2 (bosctl CLI) ──► C3 (Bash polish)
                                           │
                                           ▼
                                   C4 (SBOS IAM Style)
                                   Gobernador de Identidad Visual
                                           │
                                           ▼
                                   C5 (Keycloak + Tryton + OrangeHRM)
                                   Gobernadores Core + fuente usuarios
                                           │
                                           ▼
                                   C6 (bKernel)
                                   CDC WAL + Rule Engine
                                   Puente OrangeHRM→Tryton→Keycloak
                                           │
                                           ▼
                                   C7 (BauthAgent)
                                   Orquestador identidad + permisos
                                           │
                                           ▼
                                   C8 (VDI Server)
                                   Escritorios soberanos
                                           │
                                           ▼
                                   C9 (Core UI Flutter + Brand Composer)
                                   PAP de roles + editor de marca
```

**Cada ciclo posterior depende de que el anterior esté completo.** La Gobernanza Dual
(Keycloak + IAM Style) es transversal: todas las aplicaciones desde C5 en adelante
deben integrar OIDC contra Keycloak y consumir tokens visuales desde IAM Style.

---

## 6. Historial de Sesiones

| Sesión | Fecha | Commit | Resumen |
|---|---|---|---|
| S-22 | 2026-05-14 | `8ee24a2` | 9 fichas corregidas (3 patrones + image + probe) |
| S-23 | 2026-05-14 | `fda2745` | Certificación BOS — 18/18 fichas HEALTHY |
| S-24 | 2026-05-15 | `32d03dd` | 101 fichas corregidas (112/112 patrones correctos) |
| S-25 | (en curso) | — | Planificación con SBOS IAM Style integrado |

---

## 7. Repositorios

- **SBOS repo:** `github.com:SISTEMASSKULL/skproject-sbos.git` — branch `main`
- **Fábrica repo:** `github.com:SISTEMASSKULL/skproject-factory.git` — branch `main`
- **SBOS IAM Style:** `subproyectos/SBOS-IAM-Style/` (30 documentos, spec v3.3.3)
- **Contenedor staging:** `sbos-k8s` (Podman rootful)

---

*Generado por Claude Opus 4.7 — 2026-05-15 · Sesión S-25*
