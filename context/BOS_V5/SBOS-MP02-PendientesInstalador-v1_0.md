# SBOS-MP02-PendientesInstalador
## Mapa de Pendientes: SBOS IAM Installer — Actualización 14 Marzo 2026

### SKULL · SBOS — Sovereign Business Operating System
### Estado: ✅ COMPLETADO

---

**Propósito:** Este documento captura todos los conceptos construidos y decisiones tomadas durante las sesiones del 13-14 de marzo de 2026. Todas las tareas han sido completadas.

---

## 1. Decisiones Tomadas (definitivas, no requieren más discusión)

### 1.0 Nomenclatura unificada — SBOS en todo el proyecto
- **Antes:** 4 variantes: skBOS (producto), SBOS (prefijo daemon), SKBOS (código doc), Ficha SKBOS
- **Ahora:** **SBOS** es la única marca
- **Ejecución:** ✅ COMPLETADA — 46 archivos renombrados, 1,929 cambios en texto

### 1.1 Nombre conceptual del Installer
- **Ahora:** **"Infrastructure Provisioning & Lifecycle Orchestrator"**

### 1.2 task_catalog.sh permanece en Bash
- **Frontera invariable:** binario soberano Go consume scripts declarativos Bash de fichas
- Roadmap Bash→Go aplica solo al Core (4 archivos maestros), NO a fichas

### 1.3 Todo es una ficha
- Bootstrap = fichas. PostgreSQL = ficha. Keycloak = ficha. Core UI = ficha.

### 1.4 Idempotente, opera por CLI y por UI
- `bosctl install`, `bosctl product install`, `bosctl deploy`

### 1.5 Core UI no se despliega en la instalación inicial
- Sistema base administrado 100% por CLI (bosctl)

---

## 2. Documentos Actualizados — Estado Final

### 2.1 SBOS-005-INSTALLER → v6.0 ✅ COMPLETADO (19/19 items)

| # | Cambio | Estado |
|---|--------|--------|
| 1 | Nombre conceptual → "Infrastructure Provisioning & Lifecycle Orchestrator" | ✅ |
| 2 | Eliminar discrepancia task_catalog.so | ✅ |
| 3 | Corregir task_catalog.go → task_catalog.sh | ✅ |
| 4 | Corregir "task_catalog.so módulos Python" → "task_catalog.sh scripts Bash" | ✅ |
| 5 | Corregir task_catalog.so → .sh en estructura de archivos | ✅ |
| 6 | §1 Definición Ejecutiva | ✅ |
| 7 | §20 Observación Integral de Salud | ✅ |
| 8 | §21 Operaciones Destructivas y Governance Dual-Control | ✅ |
| 9 | §22 Frontera Binario ↔ Script | ✅ |
| 10 | §23 Posicionamiento Ecosistema de la Industria | ✅ |
| 11 | `bosctl install <ficha>` en §15.4 | ✅ |
| 12 | `bosctl product install <producto>` en §15.4 | ✅ |
| 13 | `bosctl deploy <archivo>` en §15.4 | ✅ |
| 14 | §2 "El bootstrap como acto fundacional" | ✅ |
| 15 | HashiCorp ILM en genealogía del diseño | ✅ |
| 16 | Crossplane en tabla de patrones | ✅ |
| 17 | Roadmap Bash→Go "solo Core, no fichas" | ✅ |
| 18 | Concepto de Productos y Deploy integrado | ✅ |
| 19 | Rutina de primera instalación con referencia a SBOS-031 | ✅ |

### 2.1b SBOS-005-001 — Anexo: Especificación Técnica Interna del Daemon ✅ NUEVO

Documento anexo creado con 949 líneas que cubre:
- §1 Schema completo de `.sbos_state.json` con transiciones de estado
- §2 Protocolo bosctl↔daemon vía Unix socket con mapeo de 20 comandos
- §3 Cuatro Sagas de instalación con compensación (Install/Update/Repair/Uninstall)
- §4 Especificación de 6 módulos de Dominio con funciones públicas
- §5 Catálogo completo de señales `__SBOS__`
- §6 Ficha de referencia con TODOS los campos (manifest+yaml_engine+task_catalog)
- §7 Endpoints de Productos y Deploy
- §8 Formato de bos.toml

### 2.2 SBOS-004-K8S ✅ COMPLETADO (5/5 items)

| # | Cambio | Estado |
|---|--------|--------|
| 1 | Dividir Ficha Bootstrap en 3 fichas (os, k8s, platform) | ✅ |
| 2 | StorageClass con local-path-provisioner | ✅ |
| 3 | sbos-k8s-network-validator como ficha formal | ✅ |
| 4 | sbos-bootstrap-hardening como verificación final | ✅ |
| 5 | §6 Secuencia con etapas intercaladas | ✅ |

### 2.3 SBOS-006-FICHA ✅ COMPLETADO (2/2 items)

| # | Cambio | Estado |
|---|--------|--------|
| 1 | workload.type: `bash`, `kubernetes` confirmados | ✅ |
| 2 | Tipos de ficha actualizados con bootstrap dividido y referencia a productos | ✅ |

### 2.4 SBOS-016-Servers ✅ COMPLETADO (1/1 items)

| # | Cambio | Estado |
|---|--------|--------|
| 1 | §4 Fases de Instalación con fichas reales y productos | ✅ |

---

## 3. Documentos Nuevos Creados — Estado Final

| Documento | Estado | Líneas |
|-----------|--------|--------|
| **SBOS-031-INSTALL-ROUTINE** | ✅ Creado | 620 |
| **SBOS-032-PRODUCTS** | ✅ Creado | 802 |
| **SBOS-033-DEPLOY** | ✅ Creado | 498 |
| **SBOS-034-IDENTITY-GENERATOR** | ✅ Creado | 233 |
| **SBOS-005-001** (Daemon Internals) | ✅ Creado | 949 |
| **SBOS-MP03** (Plan de Conceptualización) | ✅ Creado | 299 |
| **SBOS-000-INDEX** actualizado | ✅ Con 031-034, glosario, rutas | 426 |

---

## 4. Conceptos Técnicos Validados

Todos los conceptos descubiertos en las sesiones fueron integrados en los documentos correspondientes:

| Concepto | Documento destino | Estado |
|----------|-------------------|--------|
| StorageClass obligatorio bare metal | SBOS-031 ficha 3, SBOS-004 §4 | ✅ |
| CNI antes de DNS | SBOS-031 ficha 2 | ✅ |
| Keycloak requiere PostgreSQL | SBOS-031 grafo DAG | ✅ |
| Patrón sync-wave (ArgoCD) | SBOS-005 §23 | ✅ |
| Observación integral SO→K8s→Fichas | SBOS-005 §20 | ✅ |
| Posicionamiento vs industria | SBOS-005 §23 | ✅ |

---

## 5. Trabajo Pendiente (fuera del alcance del IAM Installer)

Estas tareas pertenecen a otros daemons y están planificadas en **SBOS-MP03**:

| Tarea | Documento | Etapa MP03 |
|-------|-----------|------------|
| Integrar MP01 PARTE A (Ciclo de Vida Realm) en SBOS-008 | SBOS-008 v2.0 | Etapa 3 |
| Integrar MP01 PARTE B (Catálogo de Roles) en SBOS-009 | SBOS-009 v2.0 | Etapa 3 |
| Integrar MP01 PARTE C (Onboarding Funcional) en SBOS-021 | SBOS-021 v2.0 | Etapa 8 |

---

*SKULL · SBOS · SBOS-MP02-PendientesInstalador · v2.0 · 14 Marzo 2026*
*Clasificación: GESTIÓN DE PROYECTO — Completado*
