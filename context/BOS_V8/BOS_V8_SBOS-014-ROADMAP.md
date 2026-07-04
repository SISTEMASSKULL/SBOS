# SBOS-014-ROADMAP
## Hoja de Ruta — Estándar HUMAN-DOC
### SKULL · SBOS · V8 · Mayo 2026

---

## 1. Estado Global

| Fase | Nombre | Estado | Período |
|---|---|---|---|
| A | El Alma (Core + Bootstrap) | 🔄 En progreso | Ene 2026 → May 2026 |
| B | El Instalador (Backend + SDK + Core UI) | 🔄 En paralelo | Mar 2026 → Jun 2026 |
| C | Stack Completo (S01–S15) | ⏳ Pendiente | Jun 2026 → Ago 2026 |
| D | Madurez y Certificación | ⏳ Pendiente | Sep 2026 → Dic 2026 |

---

## 2. Fases Detalladas

### Fase A — El Alma (Bloqueante)
SP-01 Core + SP-02 Bootstrap → Mayo 2026

Hitos: Marzo (6 módulos dominio), Abril (8 módulos orquestación + sagas), Mayo (primer cluster staging).
Gate: `bash 00_MASTER_INSTALL_SBOS.sh install sbos-bootstrap` ≥ 3 ejecuciones sin errores.

### Fase B — El Instalador
SP-04 Backend + SP-05 SDK + SP-06 Core UI → Junio 2026

Hitos: Abril (API REST v1.0), Mayo (SDK Dart estable), Junio (Core UI con WebSocket).
Gate: administrador instala fichas desde Core UI sin CLI.

### Fase C — Stack Completo
Fases 0–8 de instalación → Agosto 2026

| Fase inst. | Servidores | Fecha |
|---|---|---|
| 0 Bootstrap | S-HOST | Sem 1, Jun 2026 |
| 1 PostgreSQL | S01 dataserver | Sem 2, Jun 2026 |
| 2 Storage | S01 (MinIO) | Sem 3, Jun 2026 |
| 3 Secretos | S02 (Vault) | Sem 3, Jun 2026 |
| 4 Identidad | S03 (Keycloak + Wazuh) | Sem 4, Jun 2026 |
| 5 Observabilidad | S12 (LGTM) | Sem 1, Jul 2026 |
| 6 Gateway | S02 (Kong + NGINX) | Sem 2, Jul 2026 |
| 7 Apps + Daemons | S04–S11, S13–S15 | Jul 2026 |
| 8 Ops | S14 (GitLab + backup) | Ago 2026 |

Gate: 15 servidores operativos + backup + SLOs medidos.

### Fase D — Madurez
Sep–Dic 2026: OTEL, pruebas de carga, cobertura tests, Bus Factor ≥ 2, ISO 27001 SoA, FinOps.
Gate: Framework Enterprise ≥ 137/150.

---

## 3. Versiones Planificadas

| Versión | Fecha | Canal | Criterio clave |
|---|---|---|---|
| v0.9 Beta | Jul 2026 | canary | Core+Bootstrap+bKernel operativos, 1 cliente interno |
| v1.0 GA | Sep 2026 | stable | Stack completo, backup, SLOs verificados, biedata Bolivia |
| v1.5 Enterprise | Dic 2026 | early→stable | biedata BO+AR+MX, ISO 27001 iniciado, Framework ≥137/150 |
| v2.0 Certificada | Q2-Q3 2027 | stable | ISO 27001 completada, ARM64, VDI estándar, 10+ clientes |

---

## 4. Subproyectos

| SP | Nombre | Estado (May 2026) | Completion |
|---|---|---|---|
| SP-01 | Core | 🔄 60% | May 2026 |
| SP-02 | Bootstrap | 🔄 parcial | May 2026 |
| SP-03 | iam-dev | 🔄 | Abr 2026 |
| SP-04 | iam-prod | 🔄 40% | Jun 2026 |
| SP-05 | SDK Dart | 🔄 | May 2026 |
| SP-06 | Core UI | ⏳ mocks | Jun 2026 |
| SP-10 | bKernel | ✅ operativo | En producción |
| SP-11 | VDI | ⏳ post v1.0 | Q1 2027 |
| SP-12 | biedata | 🔄 sandbox BO | v1.0: BO / v1.5: AR+MX |
| SP-13 | bSearch | 🔄 | Ago 2026 |
| SP-14 | bCompass | 🔄 rutas base | Ago 2026 |
| SP-15 | aiserver | ✅ opcional | Disponible v0.9 |
| SP-16 | Release Plane | 🔄 canales básicos | v1.0 |

---

## 5. Subproyectos Smart* — Alineación con Roadmap

Los 10 subproyectos Smart* del ecosistema SBOS se alinean con las fases del roadmap:

| Subproyecto | Fase objetivo | Dependencia | Documentos |
|---|---|---|---|
| SBOS CMS (BOSCMS) | Fase C (Jul 2026) | bKernel, bSearch | 53 docs |
| SBOS Smart ORC (BOSORC) | Fase C (Jul 2026) | bAuth, Vault | 25 docs |
| SBOS Smart Pay (SBOS-PAY) | Fase C (Jul 2026) | bKernel, Tryton | 12 docs |
| SBOS Smart Portfolio | Fase D (Sep 2026) | bSearch, bCompass | 21 docs |
| SBOS Smart Rates (SBOS-Rates) | Fase D (Sep 2026) | bKernel, biedata | 23 docs |
| SBOS Smart Report (SBOS-REPORT) | Fase D (Sep 2026) | Core UI, bCompass | 16 docs |
| SBOS Smart Tax (SBOS_TAX) | Fase C (Ago 2026) | biedata, Tryton | 32 docs |
| SBOS Smart Vault Flow (SBOS-VAULT) | Fase D (Sep 2026) | Vault, bAuth | 18 docs |
| SBOS Tryton (SBOSTRY) | Fase C (Jul 2026) | bKernel, biedata | 57 docs |
| SBOS-IAM-Style (brand-system) | Fase B (Jun 2026) | Core UI, Flutter | 30 docs |

**Total corpus Smart*:** 287+ documentos, 10 subproyectos, integración progresiva desde
Fase B hasta Fase D del roadmap principal.

---

## 6. Criterios Go/No-Go para v1.0 GA

### Técnicos (todos bloqueantes)
T-01: IAM Installer Fases 0–8 sin errores (3 runs). T-02: bKernel >1000 ev/min. T-03: PG >99.9% (30 días). T-04: Backup pgBackRest restore <15min. T-05: Simulacro DR RTO ≤15min. T-06: Kong P95 <100ms. T-07: biedata Bolivia SIAT producción. T-08: Cobertura Dominio IAM ≥85%. T-09: Docs SBOS-001 a 026 completos.

### Organizacionales (todos bloqueantes)
O-01: Bus Factor ≥2 IAM Installer. O-02: Bus Factor ≥2 Slots PG. O-03: ADR ≥8. O-04: OKRs definidos. O-05: SLAs firmados.

Decisión: CTO + Arquitecto Lead. Todos PASS → stable. Cualquier FAIL → próxima ventana quincenal.

---

## 7. Riesgos y Mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Retraso en Fase C (Stack Completo) | Media | Alto | Fases en paralelo, priorización de servidores críticos (S01-S03 primero) |
| Dependencia de Smart* subproyectos | Media | Medio | Integración progresiva, API contracts first |
| biedata Bolivia fuera de timeline v1.0 | Baja | Alto | Sandbox BO activo, contingencia: SIAT manual en v1.0 |
| Adopción cliente interno retrasada | Media | Medio | Cliente fantasma en staging desde Fase B |
| Disponibilidad del equipo (BF) | Baja | Alto | Juan Pérez incorporación progresiva (BOS→AUTH→KERNEL→...) |

---

## 8. ENRIQUECIMIENTO SBOS (Primera Versión)

### SBOS-017-8-1: Arbol de Dependencias de Subproyectos (desde SBOS-017-Roadmap-v2_0.md)

```
SP-01 CORE (Motor de ejecucion. NO es ficha. Se desarrolla primero.)
  |
  +---> SP-02 sbos-bootstrap (Ficha sistema. Ubuntu -> K8s.)
  |      +---> SP-03 iam-dev (Ambiente Flutter dev. Temporal.)
  |      +---> SP-04 iam-prod (Instalador UI web. Permanente.)
  |      +---> SP-08 nginx-web (Web institucional. Opcional.)
  |      +---> SP-09 worker (Crecimiento horizontal.)
  |
  +---> SP-05 SDK cliente (Libreria Dart. Protocolo core <-> UI.)
  +---> SP-06 Core UI (Frontend del IAM Installer.)
  +---> SP-07 Centrifugo (Bus WebSocket del stack.)
  |
  +---> SP-10 SBOS Data Kernel (Data Kernel.)
  +---> SP-11 SBOS VDI (SO booteable USB para endpoints.)
  +---> SP-12 SBOS Data Integration (Daemon de integracion soberana.)
  +---> SP-13 SBOS Data RAG (Motor de busqueda federada.)
  +---> SP-14 SBOS AI Tools (Motor de inteligencia y asistencia.)
  +---> SP-15 aiserver (Servidor de IA soberana - opcional.)
  +---> SP-16 SKULL Release Plane (Gestion de versiones del stack.)
```

**Regla de dependencia:** SP-01 es BLOQUEANTE para todo el arbol. Ningun subproyecto puede estar en produccion sin SP-01 Core completo.

### SBOS-017-8-2: Detalle Completo de Cada Subproyecto (desde SBOS-017-Roadmap-v2_0.md)

| SP | Nombre | Que es | Necesita | Entrega |
|----|--------|--------|----------|---------|
| SP-01 | Core | Motor Bash/Python que ejecuta fichas | Nada | 4 archivos maestros + 16 modulos Python |
| SP-02 | Bootstrap | Ficha de sistema: Ubuntu -> K8s | SP-01 | Cluster K8s operativo + Pod UI |
| SP-03 | iam-dev | Ambiente Flutter hot-reload | SP-01 + SP-02 | Dev environment temporal |
| SP-04 | iam-prod | Backend FastAPI del instalador | SP-01 + SP-02 | API REST + WebSocket |
| SP-05 | SDK Dart | Protocolo core <-> clientes | SP-01 | Libreria reutilizable |
| SP-06 | Core UI | Frontend del IAM Installer | SP-04 + SP-05 | App multi-dispositivo (Flutter) |
| SP-07 | Centrifugo | Bus WebSocket para el stack | PG + KC + Redis + Kong | Mensajeria tiempo real |
| SP-08 | nginx-web | Web institucional (opcional) | SP-02 | Web publica + proxies |
| SP-09 | worker | Crecimiento horizontal | SP-02 | Nuevos nodos en 3 parametros |
| SP-10 | SBOS Data Kernel | Data Kernel (bkernel) | PostgreSQL + Tryton | Sincronizacion WAL tiempo real |
| SP-11 | SBOS VDI | SO booteable / escritorio soberano | Kasm + Keycloak + Fedora | Escritorio empresarial soberano |
| SP-12 | SBOS Data Integration | Daemon de integracion soberana (biedata) | PostgreSQL + Redis + bKernel | Integraciones tributarias declarativas |
| SP-13 | SBOS Data RAG | Motor de busqueda federada (bsearch) | Typesense + bKernel + Redis | Busqueda contextual sobre todas las apps |
| SP-14 | SBOS AI Tools | Motor de inteligencia (bcompass) | PostgreSQL + Redis + Ollama | Analisis, agentes, flows |
| SP-15 | aiserver | Servidor IA soberana (opcional) | PostgreSQL + Redis | Ollama + Qdrant + Embedding Worker + Langfuse |
| SP-16 | Release Plane | Gestion de versiones del stack | Todos los SP | Versionado semantico, changelogs, upgrade paths, canales |

### SBOS-017-8-3: Orden de Generacion del Core SP-01 (desde SBOS-017-Roadmap-v2_0.md)

```
CAPA 0 - Sin dependencias (generar primero)
  STATE_MANAGER.py           <- Arbitro del estado .sbos_state.json
  DEPENDENCY_RESOLVER.py     <- Grafo de dependencias entre fichas

CAPA 1 - Depende de Capa 0
  HEALTH_CHECKER.py          <- Verificacion de salud de pods y servicios
  FICHA_LINTER.py            <- Validacion de contratos de fichas (cobertura >= 90%)
  FICHA_PROBE.py             <- Sondeo activo de fichas en ejecucion
  GROWTH_DETECTOR.py         <- Deteccion de crecimiento de recursos

CAPA 2 - Orquestacion con Sagas (depende de Capas 0 y 1)
  [8 modulos de Orquestacion]
  Sagas de instalacion con pasos y compensacion

CAPA 3 - Archivos maestros Bash (dependen de todo lo anterior)
  00_MASTER_INSTALL_SBOS.sh  <- Punto de entrada unificado
  01_INSTALL_FICHA.sh
  02_REMOVE_FICHA.sh
  03_ROLLBACK_FICHA.sh
```

### SBOS-017-8-4: Criterios Detallados de Versiones Planificadas (desde SBOS-017-Roadmap-v2_0.md)

**v0.9 - Beta Controlada (Julio 2026, canal canary):**
- SP-01, SP-02, SP-04, SP-05, SP-06 completos
- Servidores instalables: S-HOST, S01, S02, S03, S04
- bKernel operativo (slots WAL para Tryton y OrangeHRM)
- biedata Bolivia SIAT en sandbox
- Backup automatizado: NO (Fase 8 no completa)
- 1 instalacion interna SKULL

**v1.0 - General Availability (Septiembre 2026, canal stable):**
- Stack completo Fases 0-8 (15 servidores instalables)
- bKernel + biedata + bCompass en produccion
- Backup automatizado (pgBackRest + MinIO, RK-011 operativo)
- SLOs verificados con evidencia (pruebas de carga documentadas)
- biedata Bolivia SIAT en modo produccion
- Documentacion SBOS-001 a SBOS-026 completa

**v1.5 - Enterprise (Diciembre 2026, canal early -> stable):**
- biedata Bolivia SIAT + Argentina AFIP + Mexico SAT en produccion
- ISO 27001:2022 iniciado (SoA firmada, gap analysis completo)
- Canal canary activo (3 clientes externos en produccion)
- Portabilidad Debian 12 Tier 2 validado
- Bus Factor >= 2 en todos los daemons soberanos
- Framework Enterprise >= 137/150 (91.3%)

**v2.0 - Certificada (Q2-Q3 2027, canal stable):**
- Certificacion ISO 27001:2022 completada
- Soporte ARM64 para daemons soberanos
- SBOS VDI (SP-11) como componente estandar del stack
- 10+ clientes en produccion verificados

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1-2 Fases | SBOS-017-Roadmap v2.0 | §3 Fases A–D con fechas |
| §3 Versiones | SBOS-017-Roadmap v2.0 | §4 Versiones planificadas |
| §4 SPs | SBOS-017-Roadmap v2.0 | §5 Mapa de Estado |
| §5 Smart* | Subproyectos Smart* inventory | Alineación de 10 subproyectos con roadmap |
| §6 Go/No-Go | SBOS-017-Roadmap v2.0 | §6 Criterios completos |
| §7 Riesgos | Estado actual del proyecto | Matriz de riesgos para v1.0 GA |
| §8 SBOS-017-8-1 a SBOS-017-8-4 | SBOS-017-Roadmap-v2_0.md | Arbol de dependencias de SPs, detalle completo de subproyectos (Necesita/Entrega), orden de generacion Core SP-01 (CAPAS 0-3), criterios detallados de versiones v0.9/v1.0/v1.5/v2.0 |

---

## Fuentes de Enriquecimiento V8

| Fuente | Ruta | Tipo | Detalle |
|---|---|---|---|
| BOS_V6_SBOS-014-ROADMAP.md | Procesar/ | V6 Base | Contenido completo preservado |
| SBOS-017-DEVLOG §4 | consolidado/ | V8 Smart* | Tabla de 10 subproyectos Smart* vinculados |
| SBOS-016-NOTES §3 | consolidado/ | V8 | Contexto próxima sesión, RFC-004, RFC-003 |
| SBOS-017-Roadmap-v2_0.md | Procesar/ | SBOS (V8) | Arbol de dependencias de subproyectos, detalle completo con necesidades y entregas, orden de generacion Core SP-01, criterios detallados de versiones planificadas |

---

_SKULL · SBOS · SBOS-014-ROADMAP · V8 · Mayo 2026_
