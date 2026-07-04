# SBOS-017 — Subproyectos y Hoja de Ruta de Desarrollo
## SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-017
**Versión:** 1.0
**Estado:** ⚠ SUPERSEDED
**Reemplazado por:** SBOS-017-Roadmap-v2_0.md
**Reemplaza a:** SBOS-012-ROADMAP v2.0 (SUPERSEDED)
**Clasificación:** Planificación — Mapa de Desarrollo del Stack

---

> ⚠ **AVISO:** Este documento ha sido reemplazado por **SBOS-017-Roadmap-v2_0.md**. La versión activa y canónica es la v2.0. Este archivo se mantiene solo como referencia histórica. No utilizar para planificación ni toma de decisiones.

---

## Tabla de Contenidos

1. [Mapa de Subproyectos](#1-mapa-de-subproyectos)
2. [Detalle de Cada Subproyecto](#2-detalle-de-cada-subproyecto)
3. [Fases de Desarrollo](#3-fases-de-desarrollo)
4. [Orden de Generación de Código del Core (SP-01)](#4-orden-de-generación-de-código-del-core-sp-01)

---

## 1. Mapa de Subproyectos

```
SP-01 · CORE ← Motor de ejecución. NO es una ficha. Se desarrolla primero.
  │
  ├──► SP-02 · sbos-bootstrap     ← Ficha de sistema. Ubuntu → K8s.
  │     ├──► SP-03 · iam-dev      ← Ambiente Flutter dev. Temporal.
  │     ├──► SP-04 · iam-prod     ← Instalador UI web. Permanente.
  │     ├──► SP-08 · nginx-web    ← Web institucional. Opcional.
  │     └──► SP-09 · worker       ← Crecimiento horizontal.
  │
  ├──► SP-05 · SDK cliente        ← Librería Dart. Protocolo core ↔ UI.
  ├──► SP-06 · Core UI             ← Frontend del IAM Installer.
  ├──► SP-07 · Centrifugo         ← Bus WebSocket del stack.
  │
  ├──► SP-10 · bKernel            ← Daemon de consolidación de datos.
  ├──► SP-11 · SBOS VDI              ← SO booteable USB para endpoints.
  ├──► SP-12 · biedata           ← Daemon de integración soberana.
  ├──► SP-13 · bSearch            ← Motor de búsqueda federada.
  ├──► SP-14 · bCompass           ← Motor de inteligencia y asistencia.
  ├──► SP-15 · aiserver           ← Servidor de IA soberana (opcional).
  └──► SP-16 · SKULL Release Plane ← Gestión de versiones del stack.
```

---

## 2. Detalle de Cada Subproyecto

| SP | Nombre | Qué es | Necesita | Entrega |
|---|---|---|---|---|
| SP-01 | Core | Motor Bash/Python que ejecuta fichas | Nada | 4 archivos maestros + 15 módulos Python |
| SP-02 | Bootstrap | Ficha de sistema: Ubuntu → K8s | SP-01 | Cluster K8s operativo + Pod UI |
| SP-03 | iam-dev | Ambiente Flutter hot-reload | SP-01 + SP-02 | Dev environment temporal |
| SP-04 | iam-prod | Backend FastAPI del instalador | SP-01 + SP-02 | API REST + WebSocket |
| SP-05 | SDK Dart | Protocolo core ↔ clientes | SP-01 | Librería reutilizable |
| SP-06 | Core UI | Frontend del IAM Installer | SP-04 + SP-05 | App multi-dispositivo (Flutter) |
| SP-07 | Centrifugo | Bus WebSocket para 96 apps | PG + KC + Redis + Kong | Mensajería tiempo real |
| SP-08 | nginx-web | Web institucional (opcional) | SP-02 | Web pública + proxies |
| SP-09 | worker | Crecimiento horizontal | SP-02 | Nuevos nodos en 3 params |
| SP-10 | bKernel | Daemon consolidación datos | PostgreSQL + Tryton | Sincronización bidireccional en tiempo real. Ver SBOS-010. |
| SP-11 | SBOS VDI | SO booteable USB / escritorio soberano | Kasm + Keycloak + Fedora | Escritorio empresarial soberano. Ver SBOS-012. |
| SP-12 | biedata | Daemon de integración soberana | PostgreSQL + Redis + bKernel | Integraciones declarativas con sistemas externos. Ver SBOS-011. |
| SP-13 | bSearch | Motor de búsqueda federada | Elasticsearch + bKernel + Redis | Búsqueda contextual sobre todas las apps del stack. Ver SBOS-013. |
| SP-14 | bCompass | Motor de inteligencia y asistencia | PostgreSQL + Redis + Ollama | Análisis, sugerencias, agentes, flows. Ver SBOS-014. |
| SP-15 | aiserver | Servidor de IA soberana (opcional) | PostgreSQL + Redis | Ollama + Qdrant + Embedding Worker + Langfuse. Ver SBOS-015. |
| SP-16 | SKULL Release Plane | Gestión de versiones del stack | Todos los SP | Versionado semántico, changelogs, upgrade paths, rollback. |

---

## 3. Fases de Desarrollo

### Fase A — El Alma (Bloqueante)
**SP-01 Core + SP-02 Bootstrap**

Sin estos dos no hay nada que probar ni donde trabajar. El primer `bash 00_MASTER_INSTALL_SBOS.sh install sbos-bootstrap` que funcione marca el nacimiento operativo del stack.

### Fase B — El Instalador (En Paralelo con Fase A)
**SP-03 iam-dev + SP-04 iam-prod + SP-05 SDK + SP-06 Core UI**

SP-01 y SP-05 pueden arrancar juntos (definen contratos). SP-06 puede usar mocks mientras SP-04 no esté listo.

### Fase C — El Cerebro de Datos
**SP-10 bKernel + SP-12 biedata**

SP-10 requiere que PostgreSQL y Tryton estén instalados como fichas. Es el producto más diferenciador — el motor de sincronización en tiempo real. SP-12 se desarrolla en paralelo: consume el mismo bus Redis que SP-10 y extiende el patrón hacia el mundo exterior.

### Fase D — Comunicación e Infraestructura
**SP-07 Centrifugo + SP-08 nginx-web + SP-09 worker**

SP-07 requiere fichas de fundación instaladas. SP-08 es opcional. SP-09 cuando el negocio escale.

### Fase E — El Escritorio Soberano
**SP-11 SBOS VDI**

Requiere Kasm + Keycloak + la personalización por empresa. Protocolo `sbos://` de deeplinks internos.

### Fase F — Búsqueda e Inteligencia
**SP-13 bSearch + SP-14 bCompass**

SP-13 requiere Elasticsearch y el bus Redis del bKernel. SP-14 requiere PostgreSQL, Redis, y opcionalmente Ollama del SP-15. bCompass puede operar en modo degradado sin aiserver (sin rutas LLM).

### Fase G — IA Soberana (Opcional)
**SP-15 aiserver**

Completamente opcional. Puede instalarse en cualquier momento después de la Fase A. Habilita: inferencia LLM local (Ollama), memoria semántica (Qdrant + Embedding Worker), prototipado de agentes (Flowise), observabilidad LLM (Langfuse). Ver SBOS-015.

### Fase H — Madurez de Versiones
**SP-16 SKULL Release Plane**

Mecanismo de versionado semántico del stack completo. Changelogs automatizados. Upgrade paths entre versiones. Rollback coordinado de fichas. Política de soporte de versiones.

---

## 4. Orden de Generación de Código del Core (SP-01)

```
CAPA 0 — Sin dependencias
  LOGGER.py

CAPA 1 — Depende de LOGGER
  PROCESS_MANAGER.py · STATE_MANAGER.py

CAPA 2 — Depende de Capa 0-1
  PROGRESS_EMITTER.py · PLUGIN_LOADER.py · HEALTH_CHECKER.py

CAPA 3 — Depende de Capa 0-2
  DEPENDENCY_RESOLVER.py · INSTALL_RUNNER.py · RECONCILE_SCHEDULER.py
  FICHA_LINTER.py · FICHA_PROBE.py

CAPA 4 — Orquestadores
  YAML_ENGINE.py · MENU_ENGINE.py · INFRA_CONFIGURATOR.py · GROWTH_DETECTOR.py

BASH — En este orden
  00_TASK_CATALOG_SBOS.sh → 00_ARCHITECTURE_SBOS.yml →
  00_YAML_ENGINE_SBOS.sh → 00_MASTER_INSTALL_SBOS.sh
```

---

*SKULL · SBOS · SBOS-017-ROADMAP · v1.0 · Marzo 2026*
*Reemplaza: SBOS-012-ROADMAP v2.0 — SUPERSEDED*
