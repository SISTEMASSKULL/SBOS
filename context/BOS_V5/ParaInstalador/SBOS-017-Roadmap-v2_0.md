# SBOS-017 — Subproyectos y Hoja de Ruta de Desarrollo
## SKULL · SBOS — Sovereign Business Operating System
### v2.0 · Marzo 2026 — Con fechas absolutas y versiones planificadas

---

**Código:** SBOS-017
**Versión:** 2.0
**Estado:** ACTIVO
**Reemplaza a:** SBOS-017-Roadmap-v1_0.md
**Clasificación:** Planificación — Mapa de Desarrollo del Stack

---

## Tabla de Contenidos

1. [Mapa de Subproyectos](#1-mapa-de-subproyectos)
2. [Detalle de Cada Subproyecto](#2-detalle-de-cada-subproyecto)
3. [Fases de Desarrollo con Fechas Absolutas](#3-fases-de-desarrollo-con-fechas-absolutas)
4. [Versiones Planificadas del Sistema](#4-versiones-planificadas-del-sistema)
5. [Mapa de Estado SP-01 a SP-16](#5-mapa-de-estado-sp-01-a-sp-16)
6. [Criterios Go/No-Go para v1.0 GA](#6-criterios-gono-go-para-v10-ga)
7. [Orden de Generación del Core SP-01](#7-orden-de-generación-del-core-sp-01)
8. [Registro de Cambios v2.0](#8-registro-de-cambios-v20)

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
  │         (SP-07 Centrifugo es ficha de commsserver, no subproyecto independiente)
  │
  ├──► SP-10 · SBOS Data Kernel     ← Data Kernel.
  ├──► SP-11 · SBOS VDI              ← Escritorio soberano Fedora KDE + banexus.
  ├──► SP-12 · SBOS Data Integration           ← Daemon de integración soberana.
  ├──► SP-13 · SBOS Data RAG            ← Motor de búsqueda federada.
  ├──► SP-14 · SBOS AI Tools           ← Motor de inteligencia y asistencia.
  ├──► SP-15 · aiserver           ← Servidor de IA soberana (opcional).
  └──► SP-16 · SKULL Release Plane ← Gestión de versiones del stack.
```

**Regla de dependencia:** SP-01 es BLOQUEANTE para todo el árbol. Ningún subproyecto puede estar en producción sin SP-01 Core completo.

---

## 2. Detalle de Cada Subproyecto

| SP | Nombre | Qué es | Necesita | Entrega |
|---|---|---|---|---|
| SP-01 | Core | Motor Bash/Python que ejecuta fichas | Nada | 4 archivos maestros + 16 módulos Python |
| SP-02 | Bootstrap | Ficha de sistema: Ubuntu → K8s | SP-01 | Cluster K8s operativo + Pod UI |
| SP-03 | iam-dev | Ambiente Flutter hot-reload | SP-01 + SP-02 | Dev environment temporal |
| SP-04 | iam-prod | Backend FastAPI del instalador | SP-01 + SP-02 | API REST + WebSocket |
| SP-05 | SDK Dart | Protocolo core ↔ clientes | SP-01 | Librería reutilizable |
| SP-06 | Core UI | Frontend del IAM Installer | SP-04 + SP-05 | App multi-dispositivo (Flutter) |
| SP-07 | Centrifugo | Ficha de commsserver — bus WebSocket del stack. No es subproyecto independiente | PG + KC + Redis + Kong | Ficha en commsserver/ con manifest.yml propio |
| SP-08 | nginx-web | Web institucional (opcional) | SP-02 | Web pública + proxies |
| SP-09 | worker | Crecimiento horizontal | SP-02 | Nuevos nodos en 3 parámetros |
| SP-10 | SBOS Data Kernel | Data Kernel | PostgreSQL + Tryton | Sincronización WAL en tiempo real. Ver SBOS-010. |
| SP-11 | SBOS VDI | Escritorio soberano Fedora KDE + banexus | Keycloak + bAuth + banexus + Fedora | Escritorio empresarial soberano. Ver SBOS-012. |
| SP-12 | SBOS Data Integration | Daemon de integración soberana | PostgreSQL + Redis + bKernel | Integraciones tributarias declarativas. Ver SBOS-011. |
| SP-13 | SBOS Data RAG | Motor de búsqueda federada | Typesense + bKernel + Redis | Búsqueda contextual sobre todas las apps. Ver SBOS-013. |
| SP-14 | SBOS AI Tools | Motor de inteligencia y asistencia | PostgreSQL + Redis + Ollama | Análisis, agentes, flows. Ver SBOS-014. |
| SP-15 | aiserver | Servidor de IA soberana (opcional) | PostgreSQL + Redis | Ollama + Qdrant + Embedding Worker + Langfuse. Ver SBOS-015. |
| SP-16 | Release Plane | Gestión de versiones del stack | Todos los SP | Versionado semántico, changelogs, upgrade paths, canales. |

---

## 3. Fases de Desarrollo con Fechas Absolutas

> SBOS tiene dos cronogramas coordinados: (A) el desarrollo del software (SP-01 a SP-16) y (B) la instalación de los 15 servidores lógicos (Fases 0–8 de SBOS-016). Ambos se presentan con fechas alineadas.

---

### Fase A — El Alma (Bloqueante)
**SP-01 Core + SP-02 Bootstrap**
**Período: En progreso (Enero 2026) → Mayo 2026**

**Hitos:**
- **Marzo 2026:** SP-01 Core — 4 archivos maestros Bash + 6 módulos de Dominio operativos (STATE_MANAGER, DEPENDENCY_RESOLVER, HEALTH_CHECKER, FICHA_LINTER, FICHA_PROBE, GROWTH_DETECTOR).
- **Abril 2026:** SP-01 Core — 8 módulos de Orquestación + Sagas de compensación funcionales.
- **Mayo 2026:** SP-02 Bootstrap — primer cluster K8s en staging con Fase 0 (S-HOST) y Fase 1 (K8s) instalados exitosamente.

**Hito de cierre de Fase A:** `bash 00_MASTER_INSTALL_SBOS.sh install sbos-bootstrap` ejecuta sin errores manuales en staging en ≥ 3 ejecuciones consecutivas.

---

### Fase B — El Instalador
**SP-04 Backend + SP-05 SDK + SP-06 Core UI**
**Período: En paralelo con Fase A → Junio 2026**

SP-05 (SDK Dart) y SP-04 (Backend FastAPI) arrancan en paralelo con Fase A. SP-06 (Core UI Flutter) usa mocks mientras SP-04 no esté completo.

**Hitos:**
- **Abril 2026:** SP-04 Backend — API REST v1.0 funcional.
- **Mayo 2026:** SP-05 SDK Dart — protocolo core ↔ UI estabilizado.
- **Junio 2026:** SP-06 Core UI — interfaz de instalación con WebSocket en tiempo real operativa.

**Hito de cierre de Fase B:** un administrador puede instalar y gestionar fichas desde el Core UI sin usar la línea de comandos.

---

### Fase C — Stack Completo (Servidores S01–S15)
**Fases 0–8 de SBOS-016 / Período: Junio 2026 → Agosto 2026**

Sigue el orden técnicamente obligatorio de instalación. No se puede saltar ninguna fase.

| Fase de instalación | Servers | Estimación | Fecha estimada |
|---------------------|---------|-----------|----------------|
| Fase 0 — Bootstrap | S-HOST (Ubuntu 24.04 + CRI-O + kubeadm + Calico + MetalLB) | 1 semana | Semana 1, Junio 2026 |
| Fase 1 — PostgreSQL base | S01 dataserver (PostgreSQL + Patroni + PgBouncer) | 1 semana | Semana 2, Junio 2026 |
| Fase 2 — Storage | S01 dataserver storage (MinIO) | 0.5 semana | Semana 3, Junio 2026 |
| Fase 3 — Secretos | S02 gatewayserver parcial (Vault) | 0.5 semana | Semana 3, Junio 2026 |
| Fase 4 — Identidad | S03 identityserver (Keycloak + Wazuh + Linkerd) | 1 semana | Semana 4, Junio 2026 |
| Fase 5 — Observabilidad | S12 monitorserver (LGTM stack) | 1 semana | Semana 1, Julio 2026 |
| Fase 6 — Gateway | S02 gatewayserver completo (NGINX + Kong + ModSecurity) | 1 semana | Semana 2, Julio 2026 |
| Fase 7 — Apps + Daemons | S04–S11, S13–S15 (ERP, RRHH, e-commerce + bKernel, SBOS Data Integration, SBOS AI Tools) | 3 semanas | Julio 2026 |
| Fase 8 — Ops | S14 opsserver (GitLab + pgBackRest + Bareos + Velero) | 1 semana | **Agosto 2026** |

> **Restricción crítica:** S14 opsserver se instala **AL FINAL**. No hay backup automatizado hasta que Fase 8 esté completa. Este es el período de mayor riesgo operativo del proyecto — maximizar velocidad en la instalación.

**Hito de cierre de Fase C:** sistema completo operativo en staging con los 15 servidores, backup configurado y verificado, y SLOs de SBOS-024 medidos por primera vez con evidencia numérica.

---

### Fase D — Madurez y Certificación
**Período: Septiembre 2026 → Diciembre 2026**

El stack está operativo. El foco es calidad, observabilidad, y certificación.

**Hitos:**
- **Septiembre 2026:** OTEL Collector en daemons soberanos (SBOS-027) operativo. Pruebas de carga con evidencia numérica (SBOS-024 §evidencia). Cobertura de tests ≥ umbrales de SBOS-018.
- **Octubre 2026:** SonarQube + cargo-audit en pipeline GitLab CI. Bus Factor ≥ 2 en todos los daemons soberanos.
- **Noviembre 2026:** ISO 27001 — SoA firmada por dirección (SBOS-030). FinOps dashboard operativo (SBOS-028).
- **Diciembre 2026:** Re-evaluación Framework Enterprise 2026 → objetivo **≥ 137/150 (91.3%)**.

**Hito de cierre de Fase D:** calificación ≥ 137/150 en re-evaluación formal del Framework Enterprise 2026.

---

## 4. Versiones Planificadas del Sistema

### v0.9 — Beta Controlada
**Fecha objetivo:** Julio 2026 · **Canal:** canary

| Criterio | Estado en v0.9 |
|----------|---------------|
| SP-01, SP-02, SP-04, SP-05, SP-06 | ✅ Completos |
| Servidores instalables | S-HOST, S01, S02, S03, S04 (Bootstrap + dataserver + gateway + identity + ERP) |
| SBOS Data Kernel (bkernel) | ✅ Operativo — slots WAL para Tryton y OrangeHRM |
| SBOS Data Integration | 🔄 Bolivia SIAT en sandbox |
| Backup automatizado | ❌ No (Fase 8 no completa) |
| Cliente piloto | 1 instalación interna SKULL |

**Criterios de entrada a beta v0.9:**
- IAM Installer completa instalación en staging sin errores manuales (≥ 3 runs).
- bkernel.service corre 24 horas continuas sin DLQ.
- Al menos 1 cliente piloto (instalación SKULL interna) en producción.

---

### v1.0 — General Availability (GA)
**Fecha objetivo:** Septiembre 2026 · **Canal:** stable

| Criterio | Estado en v1.0 |
|----------|---------------|
| Stack completo Fases 0–8 | ✅ Los 15 servidores instalables |
| Daemons soberanos | ✅ SBOS Data Kernel (bkernel) + SBOS Data Integration (biedata) + SBOS AI Tools (bcompass) en producción |
| Backup automatizado | ✅ pgBackRest + MinIO (RK-011 operativo) |
| SLOs verificados con evidencia | ✅ Pruebas de carga documentadas |
| SBOS Data Integration tributario | ✅ Bolivia SIAT en modo producción |
| Certificaciones | ❌ Ninguna requerida para GA |
| Documentación | ✅ SBOS-001 a SBOS-026 completos |

---

### v1.5 — Enterprise
**Fecha objetivo:** Diciembre 2026 · **Canal:** early → stable (90 días)

| Criterio | Estado en v1.5 |
|----------|---------------|
| SBOS Data Integration tributario | ✅ Bolivia SIAT + Argentina AFIP + México SAT en producción |
| ISO 27001:2022 | 🔄 Proceso iniciado, SoA firmada, gap analysis completo |
| Canal canary activo | ✅ 3 clientes externos en producción |
| Portabilidad Debian 12 | ✅ Tier 2 validado (SBOS-029) |
| Bus Factor | ✅ ≥ 2 en todos los daemons soberanos |
| Framework Enterprise | ✅ ≥ 137/150 (91.3%) |

---

### v2.0 — Certificada (Proyección 2027)
**Fecha objetivo:** Q2–Q3 2027 · **Canal:** stable

- Certificación ISO 27001:2022 completada.
- Soporte ARM64 para daemons soberanos.
- SBOS VDI (SP-11) como componente estándar del stack.
- 10+ clientes en producción verificados.

---

## 5. Mapa de Estado SP-01 a SP-16

| SP | Nombre | Depende de | Estado (Marzo 2026) | Fecha estimada completion | Canal destino |
|----|--------|-----------|---------------------|--------------------------|---------------|
| SP-01 | Core | Nada | 🔄 En desarrollo — módulos Dominio al 60% | Mayo 2026 | — |
| SP-02 | Bootstrap | SP-01 | 🔄 En desarrollo — Fase 0 parcial | Mayo 2026 | — |
| SP-03 | iam-dev | SP-01, SP-02 | 🔄 En desarrollo | Abril 2026 | — |
| SP-04 | iam-prod | SP-01, SP-02 | 🔄 En desarrollo — FastAPI al 40% | Junio 2026 | — |
| SP-05 | SDK Dart | SP-01 | 🔄 En desarrollo — protocolo definido | Mayo 2026 | — |
| SP-06 | Core UI | SP-04, SP-05 | ⏳ Pendiente — mocks listos | Junio 2026 | canary → stable |
| SP-07 | Centrifugo (ficha) | Fase 4+ completa | ⏳ Pendiente — ficha de commsserver | Agosto 2026 | canary → stable |
| SP-08 | nginx-web | SP-02 | ⏳ Pendiente (opcional) | Septiembre 2026 | stable |
| SP-09 | worker | SP-02 | ⏳ Pendiente (bajo demanda) | Bajo demanda | stable |
| SP-10 | SBOS Data Kernel (bkernel) | PostgreSQL + Tryton | ✅ Operativo — en producción | En producción (v0.9+) | canary → stable |
| SP-11 | SBOS VDI | Keycloak + bAuth + banexus | ⏳ Pendiente — post v1.0 | Q1 2027 | early → stable |
| SP-12 | SBOS Data Integration | PostgreSQL + Redis + SP-10 | 🔄 Bolivia sandbox operativo | v1.0: BO prod · v1.5: AR + MX | canary → stable |
| SP-13 | SBOS Data RAG | Typesense + SP-10 | 🔄 En desarrollo | Agosto 2026 | canary → stable |
| SP-14 | SBOS AI Tools | PostgreSQL + Redis + Ollama | 🔄 Rutas base listas | Agosto 2026 | canary → stable |
| SP-15 | aiserver | PostgreSQL + Redis | ✅ Ollama + Qdrant operativos (opcional) | Disponible en v0.9 | early → stable |
| SP-16 | Release Plane | Todos los SP | 🔄 Canales básicos funcionando | v1.0 | — |

**Leyenda:** ✅ Operativo · 🔄 En desarrollo · ⏳ Pendiente

---

## 6. Criterios Go/No-Go para v1.0 GA

La decisión de declarar v1.0 GA la toman **CTO + Arquitecto Lead** en sesión formal. Todos los criterios deben estar en estado PASS.

### Criterios técnicos (todos bloqueantes)

| # | Criterio | Verificación objetiva | Responsable |
|---|----------|----------------------|-------------|
| T-01 | IAM Installer completa Fases 0–8 sin errores manuales | 3 ejecuciones consecutivas exitosas en staging | SRE Lead |
| T-02 | bKernel > 1000 eventos/min sostenido 10 min | `bkernel_events_processed_total` en Prometheus | SRE Lead |
| T-03 | PostgreSQL disponibilidad > 99.9% durante ≥ 30 días | Panel uptime en Grafana monitorserver | SRE Lead |
| T-04 | Backup pgBackRest verificado con restore exitoso | `pgbackrest check` + restore en staging < 15 min | SRE Lead |
| T-05 | Simulacro DR completado con RTO ≤ 15 min PostgreSQL | Registro SBOS-026-SIM firmado | SRE + DevOps |
| T-06 | Kong API Gateway P95 latencia overhead < 100ms | Evidencia prueba k6 (SBOS-024 §evidencia) | SRE Lead |
| T-07 | SBOS Data Integration Bolivia SIAT en modo producción | Factura con CAF real del SIN procesada | SBOS Data Integration Team |
| T-08 | Cobertura tests módulos Dominio IAM ≥ 85% | `make release` con coverage-check sin bloqueos | Dev Lead |
| T-09 | SBOS-001 a SBOS-026 completos y revisados | Revisión documental formal | Arquitecto Lead |

### Criterios organizacionales (todos bloqueantes)

| # | Criterio | Verificación objetiva | Responsable |
|---|----------|----------------------|-------------|
| O-01 | Bus Factor ≥ 2 en IAM Installer Core | Ejercicio de validación §ABF.2 ejecutado | CTO |
| O-02 | Bus Factor ≥ 2 en Slots PostgreSQL | Ejercicio de validación §ABF.2 ejecutado | CTO |
| O-03 | ADR Catalog ≥ 8 decisiones formalizadas | SBOS-025 con 8+ ADRs completos | Arquitecto Lead |
| O-04 | OKRs Q3-Q4 2026 definidos con KRs numéricos | SBOS-001 con OKRs aprobados | CEO/CTO |
| O-05 | SLAs contractuales firmados por dirección | SBOS-024 §3 con firma de CTO | CTO |

**Decisión:** todos los criterios en PASS → activar canal stable en Release Plane. Cualquier FAIL → postponer a la siguiente ventana quincenal de evaluación.

---

## 7. Orden de Generación del Core SP-01

```
CAPA 0 — Sin dependencias (generar primero)
  STATE_MANAGER.py         ← Árbitro del estado .sbos_state.json
  DEPENDENCY_RESOLVER.py   ← Grafo de dependencias entre fichas

CAPA 1 — Depende de Capa 0
  HEALTH_CHECKER.py        ← Verificación de salud de pods y servicios
  FICHA_LINTER.py          ← Validación de contratos de fichas (cobertura ≥ 90%)
  FICHA_PROBE.py           ← Sondeo activo de fichas en ejecución
  GROWTH_DETECTOR.py       ← Detección de crecimiento de recursos

CAPA 2 — Orquestación con Sagas (depende de Capas 0 y 1)
  [8 módulos de Orquestación]
  Sagas de instalación con pasos y compensación

CAPA 3 — Archivos maestros Bash (dependen de todo lo anterior)
  00_MASTER_INSTALL_SBOS.sh   ← Punto de entrada unificado
  01_INSTALL_FICHA.sh
  02_REMOVE_FICHA.sh
  03_ROLLBACK_FICHA.sh
```

---

## 8. Registro de Cambios v2.0

| Versión | Fecha | Autor | Descripción |
|---------|-------|-------|-------------|
| 1.0 | Enero 2026 | SKULL Team | Documento inicial — fases A-H sin fechas |
| 2.0 | Marzo 2026 | Arquitecto Lead | Fechas absolutas Fases A-D, versiones v0.9/v1.0/v1.5/v2.0, criterios go/no-go T-09 + O-05, mapa de estado SP-01 a SP-16 con canales Release Plane |

---

*SKULL · SBOS · SBOS-017-Roadmap · v2.0 · Marzo 2026*
*Complementa: SBOS-016 (orden de instalación Fases 0–8), SBOS-001 (OKRs), SBOS-024 (SLOs y evidencia de pruebas de carga)*
