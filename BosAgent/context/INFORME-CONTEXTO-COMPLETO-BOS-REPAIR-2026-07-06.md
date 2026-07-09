# INFORME DE CONTEXTO COMPLETO — BosAgent + BOS-REPAIR
## Análisis integral del proyecto, documentación y plan de reparación

**Generado:** 2026-07-06 17:30Z · **Agente:** bos-developer (DeepSeek v4-pro)
**Host:** vmi3288746 · **C12:** AA-1 evidencia verificada (4/4 afirmaciones)
**Propósito:** Contexto unificado para retoma de trabajo y orientación del agente

---

## ÍNDICE

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Estado Real Verificado (C12)](#2-estado-real-verificado-c12)
3. [Estructura del Proyecto BosAgent](#3-estructura-del-proyecto-bosagent)
4. [Arquitectura del Código Fuente](#4-arquitectura-del-código-fuente)
5. [Documentación de BOS-REPAIR](#5-documentación-de-bos-repair)
6. [El Plan Maestro v3 — Fases y Átomos](#6-el-plan-maestro-v3--fases-y-átomos)
7. [Estrategia M (Milestones) — Orden Real de Ejecución](#7-estrategia-m-milestones--orden-real-de-ejecución)
8. [Arquitectura del Daemon BOS](#8-arquitectura-del-daemon-bos)
9. [Skill bos-repair — Protocolo de Sesión](#9-skill-bos-repair--protocolo-de-sesión)
10. [Estado de Build y Deuda Técnica](#10-estado-de-build-y-deuda-técnica)
11. [Gaps y Riesgos Identificados](#11-gaps-y-riesgos-identificados)
12. [Mapa de Rutas y Recursos](#12-mapa-de-rutas-y-recursos)
13. [Próximos Pasos Recomendados](#13-próximos-pasos-recomendados)

---

## 1. Resumen Ejecutivo

**BosAgent** es el daemon `bos` del ecosistema SBOS — el **plano de control soberano** (IAM
Installer, Infrastructure Provisioning & Lifecycle Orchestrator). Su responsabilidad es transformar
Ubuntu 26.04 virgen en un cluster Kubernetes con el stack SBOS completo en ~48 minutos, y
luego operar como daemon residente permanente (systemd) administrando 112+ fichas en 16
servidores lógicos.

**El proyecto está bajo un plan de reparación masivo (BOS-REPAIR)** que cubre 11+ fases (F0-F17)
con ~449 átomos, de los cuales **184 están completos (✅) y 265 pendientes (🔴)**. Una
estrategia paralela de milestones (M1-M6) agrupa los átomos por capacidad entregable.

**Hallazgos clave:**
- Código: 528 archivos Go en 38 paquetes internos — arquitectura modular ya extraída de monolitos
- Build: estado desconocido (no verificado en esta sesión) — requiere `go build ./...`
- Sin retoma verificada del Bibliotecario (ORQUESTA-056)
- Documentación: 207 MDs en plandeaccion + 57 en BOS_V8 + 10+ en BosAgent/context/
- VPS staging activa: 13.140.128.230 (bajo vigilancia por incidente Contabo)
- BOS-REPAIR-PLAN-MAESTRO-v3.md: 2155 líneas — documento canónico del plan

---

## 2. Estado Real Verificado (C12)

Evidencia AA-1 firmada con `verificar_afirmacion.sh`:

| # | Afirmación | Valor | SHA256 (salida) | Veredicto |
|---|---|---|---|---|
| 1 | Archivos Go en `src/` | **528** | `c5b59df5…` | ✅ |
| 2 | Directorios en `servers/` | **8** | `aa67a169…` | ✅ |
| 3 | Commits en `main` | **2** | `53c234e5…` | ✅ |
| 4 | Retoma verificada Bibliotecario | **NO EXISTE** | `9a271f2a…` | ✅ Confirmado |

**Commits en main:**
```
646d9da docs(bnotify): inicializar BnotifyAgent con vision bChat multi-canal
08d3320 Unificacion del arbol canonico SBOS + memoria jerarquica
```

**CLAUDE.md:** 180 líneas, v2.0 (2026-05-31), identidad bos-developer confirmada.

---

## 3. Estructura del Proyecto BosAgent

```
BosAgent/                              ← raíz del daemon
├── CLAUDE.md                          (7,220 bytes) — instrucciones del agente
├── PROPOSITO.md                       (846 bytes) — contrato de consulta para hermanos
├── README.md                          (5,217 bytes) — arquitectura y comandos
├── AUTHORS.md                         (322 bytes)
├── TUI-COMPLETO.txt                   (876,369 bytes) — referencia de TUI
├── .gitignore
├── context/                           ← documentación interna del daemon
│   ├── BOS-LIFECYCLE-PLAN-v2.md       (31,948 bytes)
│   ├── BOS-OS-ELEVATION-PLAN-v3.md    (58,576 bytes)
│   ├── FASE-E-INSTALLER-SUSPENDIDO.md (3,815 bytes)
│   ├── MANUAL-SUPERVISOR-BOS-AGENT.md (21,218 bytes)
│   ├── PLAN-DESARROLLO-CONTEXT-PLANE.md (26,214 bytes)
│   ├── PLAN-DESARROLLO-LIFECYCLE.md   (17,283 bytes)
│   ├── SOLUCIONES-ROOTLESS-K8S.md     (8,271 bytes)
│   ├── VERIFICACION-COMPLETITUD-FICHAS.md (62,632 bytes)
│   ├── plan-desarrollo-bos-elevacion.md (20,916 bytes)
│   ├── old/                           ← documentos históricos
│   ├── project/                       ← documentación de proyecto
│   └── simulacion/                    ← escenarios de simulación
├── scripts/                           ← scripts operativos
├── retroalimentacion/                 ← feedback recibido
├── staging/                           ← configuraciones de staging
├── tests/                             ← pruebas
└── src/                               ← DIRECTORIO DE TRABAJO GO
    ├── go.mod                         (module bos · Go 1.25.0)
    ├── go.sum
    ├── cmd/
    │   ├── bos/main.go                ← daemon principal
    │   └── bosctl/                    ← CLI (27+ subcomandos)
    ├── internal/                      ← 38 paquetes (ver §4)
    ├── servers/                       ← 8 directorios de servidores
    ├── proto/                         ← definiciones protobuf
    └── scripts/                       ← scripts de build/test
```

---

## 4. Arquitectura del Código Fuente

### 4.1 Paquetes internos (38 paquetes, 528 archivos Go)

| Paquete | Archivos | Propósito | Estado |
|---------|----------|-----------|--------|
| `internal/` | 380 | Raíz de paquetes internos | — |
| `tui/` | 118 | Terminal UI (Bubble Tea) — 15 pantallas + modelos + ctrl | ✅ Modular (F3.1-F3.18) |
| `server/` | 46 | API WebSocket RPC + JSON-RPC 2.0 (Interface Dual ADR-020) | ✅ Base sólida |
| `ficha/` | 45 | Ficha Engine: parser, resolver, executor, health, drift, status | 🟡 En desarrollo (F11) |
| `biaos/` | 22 | Gateway IA: ICAP Engine + Agente ReAct + safety guardrails | ✅ Completo (F10) |
| `domain/` | 13 | Servicios de dominio puros (sin protocolo) | ✅ |
| `context/` | 11 | Context Plane: tipos, servicio, store, trace context | ✅ Base (F5.A) |
| `bootstrap/` | 9 | Verificación C-01..C-08, setup, auto-bootstrap | ✅ Completo (F1.2) |
| `security/` | 9 | RBAC, CIS scanner, hardening | ✅ (rbac_provider eliminado F4.4) |
| `query/` | 6 | Motor de consultas: system, repair, vdi, tenant, node, context | ✅ Completo (F6.6-F6.11) |
| `packages/` | 6 | apt + pip + helm unificados | ✅ |
| `reconcile/` | 6 | Drift detection + topological sort | ✅ (race corregida F1.5) |
| `installer/` | 5 | Sagas con compensación (install/update/repair/remove) | ✅ |
| `observer/` | 5 | Observer loop DAG topológico + mutex anti-race | ✅ (F1.5) |
| `k8s/` | 5 | Dispatch kubectl único (Principio P1) | ✅ Extendido (F9.2) |
| `repair/` | 5 | Repair manager multi-capa | ✅ |
| `plugin/` | 5 | Cargador de fichas YAML | ✅ |
| `state/` | 7 | State manager (fcntl.flock) — 18 estados ADR-021 | ✅ |
| `release/` | 4 | Release Plane: canales canary/early/stable | ✅ |
| `system/` | 4 | Syscall helpers | ✅ |
| `bauth/` | 4 | Cliente JSON-RPC hacia bAuth daemon | ✅ |
| `catalog/` | 4 | Catálogo de acciones biaos | ✅ |
| `config/` | 3 | Configuración + defaults | ✅ |
| `health/` | 3 | Health checker | ✅ |
| `cgroup/` | 3 | verifyCgroupDelegation | ✅ (F1.3) |
| `network/` | 3 | ensureBridgeNetwork | ✅ (F1.4) |
| `metrics/` | 3 | Prometheus metrics (18 métricas bos_*) | ✅ (F9.7) |
| `scaler/` | 3 | Escalado automático anti-death-spiral | ✅ (F9.3) |
| `maintenance/` | 3 | Saga de mantenimiento | ✅ (F9.4) |
| `capacity/` | 3 | Modelo de capacidad (M1.CAP) | 🟡 Pendiente prueba VPS |
| `watchdog/` | 3 | Watchdog daemon + release rollback | ✅ (F1.6) |
| `audit/` | 3 | audit.Log — /var/log/bos/audit.log | ✅ (F1.1) |
| `paths/` | 3 | 29 constantes de rutas + 3 helpers | ✅ (F0.4) |
| `wslib/` | 2 | WebSocket library (DialUnix) | ✅ (F2.1) |
| `toml/` | 2 | Config TOML | ✅ |
| `boslog/` | 1 | Logger del daemon | ✅ |
| `observability/` | 3 | top + health-report 3-capas | ✅ |
| `keycloak/` | 0 | (directorio vacío — pendiente) | — |

### 4.2 Servidores (8 directorios)

```
servers/
├── S-HOST/     ← host bootstrap (bos-preflight, sbos-bootstrap-os/k8s/cni/storage)
├── S01/        ← datos (postgresql, redis, minio)
├── S02/        ← seguridad (vault, kong)
├── S03/        ← identidad (keycloak)
├── S06/        ← notificaciones (sbos-notifier)
└── ...         ← otros servidores lógicos
```

### 4.3 Principios de Diseño (P1-P14)

| # | Principio | Estado |
|---|-----------|--------|
| P1 | K8s dispatch único (`internal/k8s.Core`) | ✅ |
| P2 | Interface Dual (ADR-020): WebSocket + JSON-RPC mismo socket | ✅ |
| P3 | Domain separation: domain/ nunca importa server/ | ✅ |
| P4 | Fail-close auth | ✅ |
| P5 | Zero Trust | ✅ |
| P6 | Sin credenciales hardcodeadas | ✅ |
| P7 | ctx_id obligatorio (SBOS-049) | 🟡 F5 en desarrollo |
| P8 | State manager único (fcntl.flock) | ✅ |
| P9 | Sin HTTP entre daemons (SBOS-050) | ✅ |
| P10 | Dry-run antes de Apply | ✅ |
| P11 | Ports catalog (SBOS-050) | ✅ |
| P12 | Fichas declarativas (manifest.yml) | ✅ |
| P13 | Sin intervención manual (ADR-022) | ✅ |
| P14 | Sagas con compensación | ✅ |

---

## 5. Documentación de BOS-REPAIR

### 5.1 Panorama General

La documentación del plan de reparación reside en:
```
/opt/skull/orquestador/proyectos/SBOS/_archivo/Procesar_raiz/humano/daemons/bos/plandeaccion/
```

**Estadísticas:**
- **229 archivos totales**, 207 Markdown (.md)
- ~4,646 líneas solo en los 4 documentos principales
- Cobertura: plan maestro, instrucciones por átomo, informes de cierre, runbooks, JSON-RPC docs, anexos

### 5.2 Documentos Principales del Plan

| Documento | Líneas | Propósito |
|-----------|--------|-----------|
| `plandeaccion/BOS-REPAIR-PLAN-MAESTRO-v3.md` | 2,155 | EL PLAN — arquitectura objetivo, 17 fases, políticas SFP |
| `plandeaccion/REGISTRO-ESTADO.md` | 1,398 | Estado actual de cada átomo (184✅/0🟡/265🔴) |
| `plandeaccion/BOS-REPAIR-EVALUACION-PLAN-MAESTRO.md` | 781 | Evaluación 3.5/10 → diagnóstico y gaps |
| `plandeaccion/MAPA-NAVEGACION.md` | 281 | Guía de lectura — qué leer según la tarea |
| `plandeaccion/PROTOCOLO-SESION-AGENTE.md` | 526 | Apertura/ejecución/cierre de sesión del agente |
| `plandeaccion/GESTION-RIESGOS-OPERATIVOS.md` | 312 | Gates de aprobación para átomos de riesgo |
| `plandeaccion/SESION-LOG.md` | — | Bitácora cronológica de sesiones |
| `plandeaccion/EVALUACION-AGENTE-IA-BOS-REPAIR.md` | — | Capacidades del agente IA |
| `plandeaccion/action_catalog.yml` | — | 26 acciones biaos en 3 categorías |

### 5.3 Documentos de Arquitectura (bos-repair/)

14 documentos en `plandeaccion/bos-repair/`:
- `BOS-REPAIR-INDEX.md` — índice de lectura
- `SBOS_Proyecto_Master.md` v2.1 — arquitectura completa del SBOS
- `BOS-CONTRATOS-SBOS.md` — 7 contratos que BOS debe cumplir
- `BOS_V8_SBOS-051-TENANT-SPEC.md` v2.0 — Modelo A/B de Tenant
- `CONCEPCION-BOS-Y-FASES-M.md` — qué es el BOS, rol de la TUI, escalera M
- `DATOS-TUI-INSTALACION.md` — documento vivo de instalación
- `SBOS-053-DAEMON-TUI-DECOUPLING.md` v1.2 — 13 reglas DTC + 10 casos DC
- `SBOS-054-NETWORK-SECURITY.md` v1.2 — 10 NRS + 12 SAN
- `SBOS-055-FICHA-SOVEREIGNTY.md` v1.0 — 8 reglas SOV
- `Dev_Control_Certification_Method.md` v1.0 — 4 reglas Beck + SOLID + 5 Gates
- `BOS-REPAIR-14-SBOS-CLIENT-SPEC.md` — sbos-client spec
- `BOS-REPAIR-15-ESTANDARES-INTERNACIONALES.md` — CIS/NIST/SLSA/ISO
- `BOS-REPAIR-16-ADR007-DAEMONS-STUB.md` — stubs de contrato
- Documentos de referencia SBOS (ADRs, specs)

### 5.4 Instrucciones por Átomo (instrucciones-agente/)

| Archivo | Átomos | Estado |
|---------|--------|--------|
| `EJECUCION-F0.5-INSTRUCCIONES-AGENTE.md` | Pipeline CI/CD | ✅ Completado |
| `EJECUCION-F0.6-INSTRUCCIONES-AGENTE.md` | Entornos + runner | ✅ Completado |
| `EJECUCION-F1.5-INSTRUCCIONES-AGENTE.md` | Mutex observer ⛔ CRÍTICO | ✅ Completado |
| `EJECUCION-F3.1-F3.5-INSTRUCCIONES-AGENTE.md` | Partir install_ui.go | ✅ Completado |
| `EJECUCION-F5.1-F5.3-INSTRUCCIONES-AGENTE.md` | Context Plane | ✅ Completado |
| `EJECUCION-F7.8-INSTRUCCIONES-AGENTE.md` | Runbooks | ✅ Completado |
| `EJECUCION-F9.1-F9.3-INSTRUCCIONES-AGENTE.md` | Operator Soberano | ✅ Completado |
| `EJECUCION-F10.1-F10.3-INSTRUCCIONES-AGENTE.md` | Gateway LLM + biaos | ✅ Completado |

### 5.5 Informes de Cierre (informes-cierre/)

4 informes existentes: F0.5, F0.6, F7.8, F10.0.

### 5.6 Runbooks Operacionales (docs/runbooks/)

- `INDEX.md` — índice de procedimientos
- `RB-01-FICHA-DEGRADADA.md` — ficha en estado DEGRADADA
- `RB-02-DATA-RACE-DETECTADA.md` — data race en logs
- `RB-03-CONTEXT-PLANE-DOWN.md` — Context Plane caído (5 casos)
- `INCIDENTES-LOG.md` — registro de incidentes

### 5.7 Documentación JSON-RPC (json-rpc/)

9 documentos cubriendo: fundamentos, autenticación, CRUD contexto, cadena eventos,
arquitectura servidor, errores producción, arquitectura híbrida, ecosistema, orquestación multi-motor.

### 5.8 Anexos (anexos/)

27 anexos con material de investigación: pipeline CI/CD, entornos, scripts biaos, etc.

---

## 6. El Plan Maestro v3 — Fases y Átomos

### 6.1 Resumen por Fase

| Fase | Nombre | Átomos | Estado |
|------|--------|--------|--------|
| **F0** | Fundación e Infraestructura | 8 | ✅ 8/8 COMPLETA |
| **F1** | Extraer `cmd/bos/main.go` | 9 | ✅ 9/9 COMPLETA |
| **F2** | Unificar WebSocket | 4 | ✅ 4/4 COMPLETA |
| **F3** | TUI: Partir install_ui.go | 18 + 43 (3.C) | ✅ 3.A/3.B completas, 3.C 🔴 |
| **F4** | Limpiar bosctl + eliminar RBAC propio | 5 | ✅ 5/5 COMPLETA |
| **F5** | Context Plane (SBOS-049) | 41+ átomos (A-I) | 🟡 5.A completo, 5.B-5.H 🔴, 5.I 🔴 |
| **F6** | JSON-RPC Robusto + Sagas | 12 | ✅ 11/12 (falta F6.12 catálogo) |
| **F7** | Documentación | 8 | ✅ 8/8 COMPLETA |
| **F8** | Tests y Cobertura | 7 | ✅ 7/7 COMPLETA |
| **F9** | Operator Soberano | 10 | ✅ 10/10 COMPLETA |
| **F10** | biaos: Agente OS + Gateway IA | 9 | ✅ 9/9 COMPLETA |
| **F10.B** | Instalador Funcional End-to-End | 12 | 🟡 10/12 (faltan B.9, B.11) |
| **F10.C** | Ciclo de Vida de Tenants | 14 | 🟡 12/14 (faltan C.11-C.14) |
| **F11** | Ficha Engine | 31+ | 🟡 ~12/31 completos |
| **F12** | Capa 3: Servicios de datos | 10 + 25 (B) | 🔴 Mayoría pendiente |
| **F13** | Capa 4: Identidad y gateway | 13 | 🔴 Pendiente |
| **F14** | Capa 5: Daemons stubs | 8 | 🔴 Pendiente |
| **F15** | Capa 6: Fichas de aplicación | 7 | 🔴 Pendiente |
| **F16** | Capa 7: VDI Layer | 14 | 🟡 1/14 (F16.2) |
| **F17** | Estándares + certificación | — | 🔴 Pendiente |

### 6.2 Datos Clave del REGISTRO-ESTADO

- **Total átomos:** ~449 (184✅ + 265🔴)
- **Progreso:** 41% completado
- **0 átomos en progreso (🟡)** — señal de que el trabajo está detenido
- **Última actualización:** 2026-06-22
- **Fase más avanzada:** F10 (biaos) y F9 (Operator) — completas
- **Cuello de botella:** F5 (Context Plane), F11 (Ficha Engine), F3.C (Contratos TUI)

---

## 7. Estrategia M (Milestones) — Orden Real de Ejecución

El sistema dual de tracking (Opción C, 2026-06-17) define **FASE M** como orden de ejecución
y **FASE 0-19** como granularidad de implementación. Un M completado → sus átomos F obtienen Rev ☑.

| Milestone | Meta | Estado | Átomos Clave |
|-----------|------|--------|--------------|
| **M1** | BOS Daemon Vivo: cimiento mínimo funcional | 🟡 5/6 | M1.1-M1.5 ✅, M1.CAP 🟡 |
| **M2** | Primer Tenant Real: `bosctl deploy` < 30s | 🟡 2/5 | M2.1 ✅, M2.3 🟡, M2.4 🟡, M2.5 ✅ |
| **M3** | Context Plane Real: ctx_id < 5ms P99 | 🔴 0/4 | Depende M2.2 (Stack Alpha) |
| **M4** | JSON-RPC Certificado + Dashboard Soberano | 🔴 0/4 | Depende M3 |
| **M5** | Autómata de Capacidad: 4 Motores | 🔴 0/5 | Depende M4 |
| **M6** | Certificación: SLOs + Compliance | 🔴 0/5 | Depende M5 |
| **M7** | Context Plane Vision: bAuth DDL + Templates | 🔴 0/8 | Depende M2 |

**DoD de cada M verificable en VPS real.**

---

## 8. Arquitectura del Daemon BOS

### 8.1 Los 3 Planos

```
SKULL Release Plane (pull-only)
        │
        ▼
IAM Installer (host) ←── BOS DAEMON (systemd, user=bosagent)
        │
        ▼
Kubernetes Cluster (ejecución) ←── fichas, pods, servicios
```

### 8.2 Interface Dual (ADR-019/020)

```
┌─────────────────────────────────────────────────────┐
│  /run/bos/bos.sock (Unix socket, 0660, bosagent)    │
│                                                     │
│  Vía 1: WebSocket RPC  → bosctl CLI, humanos        │
│  Vía 2: JSON-RPC 2.0   → daemons, scripts, IA       │
│                                                     │
│  Naming: bos.<modulo>.<operacion>                   │
│  Módulos: ficha, bootstrap, saga, state, health,    │
│           ctx, query, ai, k8s, maintenance           │
└─────────────────────────────────────────────────────┘
```

### 8.3 Stack Técnico

- **Lenguaje:** Go 1.25+ (binario estático, CGO_ENABLED=0, ~12 MB)
- **Shell:** Bash 5.x (task_catalog.sh de fichas)
- **Python:** 3.11+ + Cython (módulos de dominio)
- **Servicio:** systemd (`bos.service`, Type=simple, user=bosagent)
- **Socket:** `/run/bos/bos.sock` (Unix)
- **TCP:** `0.0.0.0:9443` (HTTPS/TLS 1.3 — Kong + readiness)
- **Métricas:** Prometheus en `127.0.0.1:9090` (18 métricas bos_*)

### 8.4 Dependencias del Stack (ADR-017 — versiones canónicas)

| Componente | Versión | Ficha |
|-----------|---------|-------|
| Kubernetes (kubeadm) | v1.32.13 | sbos-bootstrap-k8s |
| Calico | 3.32.0 | sbos-bootstrap-cni |
| PostgreSQL | 18.4 | postgresql |
| Redis | 8.6.2 | redis |
| Keycloak | 26.6.2 | keycloak |
| Vault | 2.0.1 | vault |
| Kong | 3.9.x LTS | kong |

### 8.5 Unidad Declarativa: La Ficha

```
servers/<servidor>/<nombre_ficha>/
├── manifest.yml          ← metadatos, dependencias, health, puertos
├── yaml_engine.yml       ← 5 fases: pre_install→install→post_install→verify→commit
├── task_catalog.sh       ← funciones: ficha_install, ficha_repair, ficha_remove
└── resources/
    ├── dashboard.json     ← paneles requeridos (obligatorio)
    └── netpolicies/       ← NetworkPolicy Calico
```

---

## 9. Skill bos-repair — Protocolo de Sesión

### 9.1 Las 3 Rutas Base (MEMORIZAR)

```
RUTA 1 — plandeaccion/
  /opt/skull/orquestador/proyectos/SBOS/_archivo/Procesar_raiz/humano/daemons/bos/plandeaccion/plandeaccion/

RUTA 2 — BOS_V8/
  /opt/skull/orquestador/proyectos/SBOS/context/BOS_V8/
  (NOTA: el skill dice BOS_V8 pero en disco también hay BOS_V5)

RUTA 3 — BosAgent/src/
  /opt/skull/orquestador/proyectos/SBOS/BosAgent/src/
```

### 9.2 Apertura de Sesión (5 min, obligatorio)

1. Leer `SESION-LOG.md` (últimas 80 líneas)
2. Verificar continuidad con `BOS-REPAIR-VERIFICAR-CONTINUIDAD.sh`
3. Ver dashboard con `BOS-REPAIR-DASHBOARD.sh`
4. Decidir átomo: 🟡 EN PROGRESO → retomar | 🔴 NO INICIADA → siguiente

**Regla crítica:** si `go build ./...` falla, NO ejecutar átomos. Restaurar build primero.

### 9.3 Política de Cero Errores Diferidos (INNEGOCIABLE)

- Build verde ANTES de cualquier átomo
- Error introducido → `git revert HEAD` inmediato
- Error preexistente → documentar, evaluar, nunca ignorar
- Herramientas rotas → corregir antes de usar

### 9.4 Cierre de Sesión (5 min, obligatorio)

DoD Universal antes de marcar ✅:
```bash
go build ./...                    # ✅ BUILD
go vet ./...                      # ✅ VET
gofmt -l . | wc -l | grep "^0$"  # ✅ FORMAT
go test -race -count=10 ./...    # ✅ TESTS
```

### 9.5 Políticas SFP (nunca violar)

```
SFP-01  NUNCA borrar código → archivar en _legacy/ con fecha y fase
SFP-02  Código nuevo compila y pasa tests ANTES de tocar original
SFP-03  Feature flags: BOS_OBSERVER_V2=true activa nuevo código en staging
SFP-04  Un átomo = un commit: [F1.5] fix: mutex anti-race en internal/observer/
SFP-05  go build ./... verde en CADA commit — si rompe: git revert inmediato
SFP-06  _legacy/README.md es la memoria del proyecto — actualizar siempre
```

### 9.6 Gates de Aprobación (STOP y presentar plan)

| Átomo | Riesgo | Razón |
|-------|--------|-------|
| F1.5 | ALTO | Mutex en loop de control central |
| F4.4 | ALTO | Eliminar rbac_provider.go |
| F9.2+ | MUY ALTO | Operaciones K8s reales |
| F9.7 | MUY ALTO | ClusterRole |
| F11.5 | ALTO | Governance Dual-Control |
| F12.3 | ALTO | Vault init + unseal |
| F13.2 | ALTO | FAPI 2.0 |
| F14.2 | ALTO | bhnexus stub |
| F16.12 | ALTO | ISO con clave privada |
| F17.1 | ALTO | Certificación final |
| `kubectl delete` | CRÍTICO | Irreversible |

---

## 10. Estado de Build y Deuda Técnica

### 10.1 Verificaciones Pendientes

| Verificación | Estado |
|---|---|
| `go build ./...` | ❓ No verificado en esta sesión |
| `go vet ./...` | ❓ No verificado |
| `gofmt -l .` | ❓ No verificado |
| `go test -race -count=10 ./...` | ❓ No verificado |

### 10.2 Señal de Retoma de Fases (según BOS-REPAIR-INDEX)

| Fase | Indicador | Estado esperado |
|------|-----------|-----------------|
| F0 | `internal/audit/doc.go` existe | ✅ |
| F1 | `auditLog` NO en main.go | ✅ |
| F2 | `gorilla/websocket` NO en cmd/ | ✅ |
| F3 | `install_ui.go` ≤ 500 líneas | ✅ (62 líneas) |
| F4 | `rbac_provider.go` NO existe | ✅ (eliminado) |
| F5 | `internal/context/service.go` existe | ✅ |
| F6 | `bos.query.system` en jsonrpc.go | ✅ |
| F7.8 | Runbooks en docs/runbooks/ | ✅ |
| F9 | `internal/scaler` existe | ✅ |
| F10 | `internal/biaos/gateway.go` existe | ✅ |
| F11 | `internal/fichaengine/resolver.go` | ✅ (M2.1) |
| F14 | BauthAgent src/ existe | ✅ |
| F16 | `cmd/sbos-client` existe | ❌ |

### 10.3 Archivos en `_legacy/`

14 paquetes/archivos archivados según SFP-01. Ver `_legacy/README.md` para inventario completo.

---

## 11. Gaps y Riesgos Identificados

### 11.1 Gaps de Documentación (del Plan Maestro §PARTE I)

4 gaps identificados en la evaluación inicial:
1. **Gap 1 — Pipeline CI/CD:** Sin integración continua (RESUELTO — F0.5)
2. **Gap 2 — Entornos:** Sin separación DEV/STAGING/PROD (RESUELTO — F0.6)
3. **Gap 3 — Observabilidad:** Sin monitoreo ni alertas (RESUELTO — F9.7)
4. **Gap 4 — Documentación:** Sin godoc ni runbooks (RESUELTO — F7.1-F7.8)

### 11.2 Riesgos Activos

| Riesgo | Severidad | Estado |
|--------|-----------|--------|
| VPS staging bajo vigilancia (incidente Contabo) | ALTO | Activo — usar skill sbos-staging-security-monitor |
| Sin retoma verificada del Bibliotecario | MEDIO | ORQUESTA-056: el auto-reporte no es confiable |
| Múltiples átomos F3.C (43 átomos) sin iniciar | BAJO | Bloquea certificación completa |
| F5.I (bAuth DDL integration) — 26 átomos nuevos | MEDIO | Depende de coordinación con bAuth |
| F11-F17 mayormente 🔴 | ALTO | ~265 átomos pendientes |

### 11.3 Discrepancias de Rutas

El skill `bos-repair` referencia rutas bajo `/opt/skull/orquestador/proyectos/desarrollo/`,
pero las rutas reales están bajo `/opt/skull/orquestador/proyectos/SBOS/`. Mapeo:

| Ruta en skill | Ruta real |
|---------------|-----------|
| `.../desarrollo/context/sbos/Procesar/humano/daemons/bos/plandeaccion/` | `.../SBOS/_archivo/Procesar_raiz/humano/daemons/bos/plandeaccion/` |
| `.../desarrollo/sbos/BosAgent/` | `.../SBOS/BosAgent/` |
| `.../desarrollo/context/sbos/Procesar/humano/BOS_V8/` | `.../SBOS/context/BOS_V8/` o `.../SBOS/context/BOS_V5/` |

---

## 12. Mapa de Rutas y Recursos

### 12.1 Recursos del Proyecto (Shared Kernel)

| Recurso | Ruta | Índice |
|---------|------|--------|
| Fichas de despliegue | `SBOS/servers/` | `servers.yml` |
| DDLs | `SBOS/DDLs/` | `ddls.yml` |
| Documentación conceptual | `SBOS/context/BOS_V5/`, `BOS_V8/` | `*-000-INDEX` |
| Contratos | `SBOS/context/contracts/` | `LEEME.md` |
| Buzón Bibliotecario | `SBOS/context/buzon-bibliotecario/` | `LEEME.md` |
| Fabrica scripts | `fabrica/scripts/` | `verificar_afirmacion.sh` |

### 12.2 Documentos Canónicos del Daemon BOS

| Documento | Ruta | 
|-----------|------|
| SBOS-018-DAEMON-BOS | `context/BOS_V8/BOS_V8_SBOS-018-DAEMON-BOS.md` |
| SBOS-049-CONTEXT-PLANE | `context/BOS_V8/BOS_V8_SBOS-049-CONTEXT-PLANE.md` |
| SBOS-050-PORT-CATALOG | `context/BOS_V8/BOS_V8_SBOS-050-PORT-CATALOG.md` |
| SBOS-BOOTSTRAP-MANUAL | `context/daemons/bos/SBOS-BOOTSTRAP-MANUAL.md` |

### 12.3 Personal de Fábrica

| Agente | Contacto |
|--------|----------|
| Bibliotecario | Buzón: `context/buzon-bibliotecario/` |
| Coordinador | JSON-RPC `orquesta.coordinador.*` en `localhost:8095` |
| Revisor | Invocado por Bibliotecario post-commit |
| Testeador | Invocado por Bibliotecario — verifica en VPS |
| Planificador | Registra en SKDATA al cierre |

---

## 13. Próximos Pasos Recomendados

### 13.1 Acciones Inmediatas (esta sesión)

1. ⚠️ **Verificar build:** ejecutar `go build ./...` desde `src/` — si falla, restaurar
2. 📋 **Señal de retoma completa:** ejecutar el script de señal de retoma del protocolo
3. 📝 **Solicitar retoma al Bibliotecario:** depositar reporte en el buzón para obtener `RETOMA-BOS-VERIFICADA`
4. 🔍 **Decidir próximo átomo:** según REGISTRO-ESTADO, primer 🔴 con fase previa ✅

### 13.2 Átomos Candidatos (orden sugerido)

| Prioridad | Átomo | Justificación |
|-----------|-------|---------------|
| 1 | Verificar build + restaurar si es necesario | Política de cero errores diferidos |
| 2 | M1.CAP (prueba VPS) | Único 🟡 en M1 — completar el milestone |
| 3 | F3.C.1 (WebSocket sobre Unix socket) | Inicia la fase 3.C completa (43 átomos) |
| 4 | F5.B-F5.H (Context Plane lifecycle) | Desbloquea M3 |
| 5 | F10.B.9 (TUI ScreenInstalling eventos) | Completa F10.B (solo faltan 2) |
| 6 | F6.12 (Catálogo RPC certificado) | Último átomo pendiente de F6 |

### 13.3 Lo que NO debe hacerse

- ❌ Ejecutar átomos sin build verde
- ❌ Trabajar sin retoma verificada del Bibliotecario (ORQUESTA-056)
- ❌ Tocar archivos en `servers/`, `DDLs/` o `context/` sin consulta HITL
- ❌ Ejecutar átomos con gate de aprobación sin confirmación explícita
- ❌ Conectar a la VPS de staging sin activar el protocolo de seguridad

---

## APÉNDICE A — Inventario de Documentación por Ubicación

### A.1 BosAgent/context/ (10 documentos)

| Documento | Líneas | Tema |
|-----------|--------|------|
| BOS-LIFECYCLE-PLAN-v2.md | ~800 | Ciclo de vida validado ISO/IEC 25010 |
| BOS-OS-ELEVATION-PLAN-v3.md | ~1,500 | Plan de elevación BOS = Ubuntu + K8s |
| FASE-E-INSTALLER-SUSPENDIDO.md | ~100 | Fase E suspendida |
| MANUAL-SUPERVISOR-BOS-AGENT.md | ~550 | Guía operativa del supervisor |
| PLAN-DESARROLLO-CONTEXT-PLANE.md | ~680 | Plan de desarrollo Context Plane |
| PLAN-DESARROLLO-LIFECYCLE.md | ~450 | Plan de desarrollo Lifecycle |
| SOLUCIONES-ROOTLESS-K8S.md | ~210 | Soluciones rootless K8s |
| VERIFICACION-COMPLETITUD-FICHAS.md | ~1,600 | Taxonomía 112 fichas |
| plan-desarrollo-bos-elevacion.md | ~540 | Plan por fases A-E |

### A.2 context/BOS_V8/ (57 documentos)

Documentación de referencia de todo el proyecto SBOS: visión, arquitectura,
stack, installer, daemons, seguridad, roadmap, etc.

### A.3 context/BOS_V5/ (60+ documentos)

Versión anterior de la documentación. Puede contener información histórica relevante.

---

## APÉNDICE B — Glosario de Siglas y Acrónimos

| Sigla | Significado |
|-------|-------------|
| ADR | Architecture Decision Record |
| biaos | BOS Intelligent Agent Operating System |
| C12 | Control 12 — AA-1 Evidencia obligatoria |
| CDC | Change Data Capture |
| DAG | Directed Acyclic Graph |
| DoD | Definition of Done |
| DTC | Daemon-TUI Decoupling (reglas SBOS-053) |
| HITL | Human In The Loop |
| ICAP | Intent Classification and Action Planning |
| LoA | Level of Assurance |
| NRS | Network Restriction Standards (SBOS-054) |
| OTel | OpenTelemetry |
| RB | Runbook |
| SAM | Secure Authentication Module |
| SAN | Security Access Norms (SBOS-054) |
| SFP | Security-First Policy |
| SLO | Service Level Objective |
| SOV | Sovereignty rules (SBOS-055) |
| TEA | The Elm Architecture (patrón TUI) |
| WAL | Write-Ahead Log |

---

*INFORME-CONTEXTO-COMPLETO-BOS-REPAIR-2026-07-06.md*
*Generado por bos-developer (DeepSeek v4-pro) · C12 AA-1 compliant*
*Basado en: REGISTRO-ESTADO.md v2.0 (1398 líneas), BOS-REPAIR-PLAN-MAESTRO-v3.md (2155 líneas),*
*MAP-NAVEGACION.md, PROTOCOLO-SESION-AGENTE.md, GESTION-RIESGOS-OPERATIVOS.md,*
*BosAgent/CLAUDE.md, BosAgent/context/*, skill bos-repair, estructura de 528 archivos Go*
