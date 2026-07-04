# SBOS-000-INDEX
## Índice Maestro y Glosario del Proyecto SBOS

### SKULL · SBOS — Sovereign Business Operating System
### Documentación de Arquitectura y Desarrollo · v6.0 · Marzo 2026

---

## 1. Propósito de esta Documentación

Este conjunto de documentos es la **fuente de verdad** del proyecto SBOS. No es material comercial ni de marketing — es el mapa de construcción desde el cual se desarrollan todas las herramientas, fichas, skills y productos del sistema operativo empresarial SBOS.

Sirve para:

1. Que el equipo SKULL entienda con precisión qué estamos construyendo y por qué cada decisión fue tomada
2. Que cualquier persona que se sume al proyecto comprenda la arquitectura completa sin necesidad de consultar al equipo original
3. Ser la base desde la cual se construye cada componente — código, fichas, skills, documentación
4. Ser la referencia obligatoria antes de escribir código, crear fichas, o tomar decisiones arquitectónicas

**Principio de esta documentación:** cada documento debe ser autocontenido y justificar sus decisiones técnicas con referencia a patrones de la industria. Un desarrollador que lea SBOS-006 debe entender no solo qué es una ficha sino por qué ese diseño es la elección correcta frente a las alternativas.

---

## 2. Los 8 Daemons Soberanos del SBOS

Una de las decisiones arquitectónicas más importantes del SBOS es la existencia de ocho daemons soberanos — seis corren como servicios **systemd en el host Ubuntu** (fuera de Kubernetes) y uno en cada cliente Fedora como systemd --user. Esta distinción es crítica y debe comprenderse antes de leer cualquier otro documento.

```
HOST UBUNTU (systemd)
├── bos.service         → SBOS IAM Installer: instala, observa y repara el stack.
├── bkernel.service     → SBOS Data Kernel: consolida datos entre apps vía WAL.
├── biedata.service     → SBOS Data Integration: integra el stack con sistemas externos.
├── bcompass.service    → SBOS AI Tools: genera inteligencia y asistencia operacional.
├── bsearch.service     → SBOS Data RAG: búsqueda federada soberana.
├── bauth.service       → SBOS Auth Enforce: orquestador de autenticación e identidad.
└── bhnexus.service     → SBOS Nexus Host: árbitro de privilegios de escritorio.

CLIENTE FEDORA (systemd --user)
└── banexus.service     → SBOS Nexus Agent: agente en cliente Fedora.

KUBERNETES CLUSTER (pods)
├── sbos-identity/keycloak
├── sbos-data/postgresql
├── sbos-installer/core-ui
└── ... (110+ apps del stack)
```

**¿Por qué fuera de Kubernetes?**
Los daemons del host necesitan acceso directo al Write-Ahead Log (WAL) de PostgreSQL. El WAL es el bus de eventos nativo del sistema — la fuente de toda sincronización y toda inteligencia. Un pod K8s con acceso al WAL introduciría latencia de red y dependencia de la red del cluster para una operación que es por naturaleza local y de baja latencia. Los daemons del host eliminan esa capa.

| Daemon | Documento | Función central |
|---|---|---|
| **SBOS Data Kernel** | SBOS-010 | Escucha el WAL → sincroniza apps internas → consolida datos en Tryton |
| **SBOS Data Integration** | SBOS-011 | Escucha eventos → conecta el stack con el mundo exterior (Import/Export) |
| **SBOS AI Tools** | SBOS-014 | Escucha eventos → ejecuta rutas de inteligencia → orienta al negocio |
| **SBOS Data RAG** | SBOS-013 | Índice federado → búsqueda soberana entre todas las apps del stack |
| **SBOS Auth Enforce** | SBOS-008 | Orquesta identidad KC + Tryton → BitMask 64 bits → objeto de identidad |
| **SBOS Nexus Host** | SBOS-012 | Evalúa privilegios → gobierna el escritorio corporativo Fedora |

Estos daemons soberanos son **la razón por la que el SBOS no necesita Kafka, n8n, ni ningún middleware externo de mensajería**. El WAL de PostgreSQL es su bus de eventos. Los daemons son sus consumidores soberanos.

---

## 3. Mapa de Documentos

| Código | Documento | Contenido | Versión | Estado |
|---|---|---|---|---|
| `SBOS-000` | Índice Maestro y Glosario | Navegación, rutas de lectura, glosario, convenciones | v5.0 | ✓ ACTIVO |
| `SBOS-001` | Visión y Alcance del Proyecto | SKULL, SBOS, soberanía digital 2026, 6 pilares, mercado, OKRs estratégicos | v4.0 + OKR | ✓ ACTIVO — Complementos en archivos separados |
| `SBOS-002` | Arquitectura General del Sistema | SBOS como SO, 5 capas, flujos, WAL como Event Bus, fronteras | v4.0 | ✓ ACTIVO |
| `SBOS-003` | Catálogo del Stack Tecnológico | 110+ apps, 15 servidores, criterios de selección, auditoría de licencias | v4.0 | ✓ ACTIVO |
| `SBOS-004` | Infraestructura Kubernetes | K8s, Bootstrap, hardening CIS, zero trust, crecimiento | v4.0 | ✓ ACTIVO |
| `SBOS-005` | SBOS IAM Installer — Control Plane Soberano | Core SP-01, 16 módulos Python, Core UI Flutter, Release Plane | v5.0 | ✓ ACTIVO |
| `SBOS-006` | Sistema de Fichas | 3 tipos, 5 estados, execution_order, depends_on, 3 contratos | v4.0 | ✓ ACTIVO |
| `SBOS-007` | Core UI — Frontend del SBOS IAM Installer | Flutter multi-dispositivo, BLoC+Riverpod, API REST Core↔UI, versionado /api/v{N}/, sunset policy | v4.0 | ✓ ACTIVO — Complementos en archivos separados |
| `SBOS-008` | Gobierno de Identidad | SBOS Auth Enforce + Keycloak, SPIs, ciclo de vida realm completo (Alta/Modificación/Baja) | v1.0 | ✓ ACTIVO — Complementos en archivos separados |
| `SBOS-009` | Contratos de Identidad | RolTemplate, UserTemplate, catálogo de roles por sector (Manufactura, Servicios, Retail) | v1.0 | ✓ ACTIVO — Complementos en archivos separados |
| `SBOS-010` | SBOS Data Kernel: Active Orchestration Engine | WAL CDC, Rule Engine, Task Catalog, Tryton hub, at-least-once, replay WAL (§18) | v7.0 | ✓ ACTIVO — Complementos en archivos separados |
| `SBOS-011` | SBOS Data Integration — Motor de Integración Soberano | Cajas declarativas, Box API, Import/Export, Bolivia SIAT, Argentina AFIP, México SAT | v3.0 | ✓ ACTIVO — Complementos en archivos separados |
| `SBOS-012` | SBOS VDI — Escritorio Soberano | Kasm+Fedora KDE, 3 capas de políticas, ciclo de vida usuario | v4.0 | ✓ ACTIVO |
| `SBOS-013` | SBOS Data RAG — SBOS Data RAG: Sovereign Federated Intelligent Search | 7 capas de relevancia, Schema Discoverer, patrones YAML, widget | v4.0 | ✓ ACTIVO |
| `SBOS-014` | SBOS AI Tools — Motor de Inteligencia Soberano | Rutas declarativas, 4 tipos de ruta, Route API, Ollama, gestión de prompts LLM, Langfuse | v4.0 | ✓ ACTIVO — Complementos en archivos separados |
| `SBOS-015` | aiserver — Infraestructura de IA Soberana | Ollama, Qdrant, Open WebUI, Embedding Worker, Langfuse, integración SBOS AI Tools | v2.0 | ✓ ACTIVO |
| `SBOS-016` | Mapa de Servidores Lógicos | 15 servidores S00-S15, daemons del host, fases de instalación | v1.0 | ✓ ACTIVO |
| `SBOS-017` | Subproyectos y Hoja de Ruta (v1.0) | SP-01 a SP-16, árbol de dependencias, fases A-F | v1.0 | ⚠ SUPERSEDED — reemplazado por v2.0 |
| `SBOS-017` | Subproyectos y Hoja de Ruta (v2.0) | SP-01 a SP-16, árbol de dependencias, fases A-D con fechas absolutas, versiones v0.9/v1.0/v1.5/v2.0, criterios go/no-go | v2.0 | ✓ ACTIVO |
| `SBOS-018` | Estándares de Calidad y Principios | 14+1 principios, estándares Bash/Python/YAML/Rust, CI/CD, umbrales cobertura, SonarQube, feature flags, blue/green | v1.0 | ✓ ACTIVO — Complementos en archivos separados |
| `SBOS-019` | Keycloak — Métodos de Autenticación | 15 métodos KC 26.x, 5 SPIs a construir, especificación Java | v2.0 | ✓ ACTIVO |
| `SBOS-020` | Keycloak — Datos Internos y JWT | Tablas internas KC, estructura JWT, claims bos_*, escenarios de error | v2.0 | ✓ ACTIVO |
| `SBOS-021` | Guía de Incorporación al Equipo | Onboarding técnico, entorno dev, primeros pasos, Plan Anti-Bus-Factor, sesiones de transferencia | v1.0 | ✓ ACTIVO — Complementos en archivos separados |
| `SBOS-022` | Bounded Contexts y Modelo de Mensajería | Mapa de dominios, WAL como Event Bus, CQRS, Sagas, versionado API entre BCs, migración PostgreSQL mayor | v1.0 | ✓ ACTIVO — Complementos en archivos separados |
| `SBOS-023` | Arquitectura de Seguridad Zero Trust | Vista unificada seguridad, Zero Trust end-to-end, notificación de brechas GDPR/iberoamérica | v1.0 | ✓ ACTIVO — Complementos en archivos separados |
| `SBOS-024` | Libro de Operaciones | SLOs, SLAs, runbooks RK-001 a RK-014, feature flags, blue/green daemons, pruebas de carga | v1.0 | ✓ ACTIVO — Complementos en archivos separados |
| `SBOS-025` | Catálogo de Decisiones Arquitectónicas (ADR) | ADR-001 a ADR-008 formalizados, proceso ARB formal, template RFC, composición del board | v1.0 | ✓ NUEVO |
| `SBOS-026` | Backup, Restore y Disaster Recovery | pgBackRest + MinIO, RK-011/012/013, slots WAL en restore, RTO/RPO por escenario, alertas backup | v1.0 | ✓ NUEVO |
| `SBOS-026-SIM` | Plan de Simulacro DR | Checklist 14 pasos, template registro PARTE 2, historial de simulacros | v1.0 | ✓ NUEVO |
| `SBOS-027` | Observabilidad OTEL — Daemons Soberanos | OTEL Collector systemd, métricas SBOS Data Kernel/SBOS Data Integration/SBOS AI Tools, trazas distribuidas, 9 alertas, dashboard Grafana | v1.0 | ✓ NUEVO |
| `SBOS-028` | Modelo FinOps y Gestión de Costos | Modelo on-premise, dashboard Grafana FinOps, alertas, VPA, hardware mínimo recomendado | v1.0 | ✓ NUEVO |
| `SBOS-029` | Portabilidad y Multi-Entorno | Matriz OS (Ubuntu/Debian/Fedora), diferencias Ubuntu-Debian, entornos dev/staging/prod, ARM64 | v1.0 | ✓ NUEVO |
| `SBOS-030` | SGSI — ISO 27001:2022 | Alcance SGSI, SoA 20 controles, registro de riesgos, plan de implementación hacia certificación | v1.0 | ✓ NUEVO |
| `SBOS-031` | Rutina Profesional de Instalación | 16 fichas desde Ubuntu virgen hasta sistema base, grafo DAG, timeline, validación técnica | v1.0 | ✓ NUEVO |
| `SBOS-032` | Especificación de Productos | Manifiestos de solución: bootstrap, mail, erp, documents, monitoring, vdi, ai, devops. Requirements + fichas + verificaciones | v1.0 | ✓ NUEVO |
| `SBOS-033` | Especificación de Despliegue y Seed File | Manifiesto del cliente: identidad empresa, red, admin, productos. Generación automática de llaves. Cuenta de emergencia | v1.0 | ✓ NUEVO |
| `SBOS-034` | Generador de Identidad Visual | Herramienta que genera favicons, iconos PWA, logos variantes, OG images, Keycloak theme, firma de correo desde logo fuente | v1.0 | ✓ NUEVO |
| `SBOS-035` | SBOS Nexus Host — Connectivity Broker | WebSocket, BitMask packaging, mTLS, hardware bridge (OSDP/MQTT/ONVIF), device fichas, flujo soberano completo | v1.0 | ✓ NUEVO |
| `SBOS-036` | SBOS Nexus Agent — Edge Sentinel | Interceptor USB/shell en Fedora, PAM module, actuadores, policy cache efímero, comunicación monogámica | v1.0 | ✓ NUEVO |
| `SBOS-037` | Centrifugo — Bus WebSocket | Canales por daemon, autenticación JWT KC, diferenciación con bhnexus, productores/consumidores | v1.0 | ✓ NUEVO |
| `SBOS-038` | SKULL Release Plane — Distribución Soberana | Arquitectura release server, protocolo Ed25519, canales canary/early/stable, catálogo de fichas, upgrade con rollback | v1.0 | ✓ NUEVO |
| `SBOS-039` | Flujos de Negocio End-to-End | 7 flujos que demuestran el SBOS como SO: alta empleado, factura SIAT, punto de venta QR, offboarding, consulta IA, búsqueda federada, instalación producto | v1.0 | ✓ NUEVO |
| | | | | |
| **Anexos de especificación interna (nivel de código)** | | | | |
| `SBOS-005-001` | Daemon bos — Internals | Schema .sbos_state.json, protocolo bosctl, Sagas, módulos dominio, señales, ficha referencia, bos.toml | v1.0 | ✓ Anexo de SBOS-005 |
| `SBOS-008-001` | Dominios, BitMask y Realm | 3 dominios soberanía, BitMask 64 bits, plugin KC, sync KC↔Tryton, delegación temporal, QR/NFC/biométrico | v1.0 | ✓ Anexo de SBOS-008 |
| `SBOS-010-001` | DLQ, Reglas y Protocolo bkernel | 16 reglas por app, DLQ PostgreSQL, protocolo con Tryton, prevención loop WAL, Redis bus, métricas | v1.0 | ✓ Anexo de SBOS-010 |
| `SBOS-011-001` | Box Engine y Protocolo Externos | Box Engine 6 fases, circuit breaker, protocolo SIAT/AFIP/SAT detallado | v1.0 | ✓ Anexo de SBOS-011 |
| `SBOS-013-001` | Indexación, Fuzzy y Routing | Motor indexación incremental, pipeline fuzzy 5 capas, smart routing con permisos | v1.0 | ✓ Anexo de SBOS-013 |
| `SBOS-014-001` | Contrato LLM y Agentes | Contrato ruta→LLM→respuesta, aprendizaje federado, agentes por manifiesto, fallback sin GPU | v1.0 | ✓ Anexo de SBOS-014 |
| `SBOS-019-001` | Catálogo KC + Kong por App | Configuración Keycloak (clients, roles) y Kong (rutas, plugins) para 12 apps base del stack | v1.0 | ✓ Anexo de SBOS-019 |
| `SBOS-VAL-01` | Auditoría Sprint 0 | Verificación de criterios de aceptación S0-01 a S0-05, +11 puntos confirmados | v1.0 | ✓ COMPLETADO |
| `SBOS-VAL-02` | Re-Evaluación Framework Enterprise 2026 | Análisis por eje, 133/150 actual, brechas residuales, plan cierre Dic 2026 | v1.0 | ✓ ACTIVO |

---

## 4. Estado de la Documentación

```
SBOS-000  ████████████████████  v5.0  ✓ Activo — Índice Maestro actualizado (auditoría Marzo 2026)
SBOS-001  ████████████████████  v4.0  ✓ Activo — Complementos en archivos separados (SBOS-001-OKR)
SBOS-002  ████████████████████  v4.0  ✓ Activo
SBOS-003  ████████████████████  v4.0  ✓ Activo
SBOS-004  ████████████████████  v4.0  ✓ Activo
SBOS-005  ████████████████████  v5.0  ✓ Activo
SBOS-006  ████████████████████  v4.0  ✓ Activo
SBOS-007  ████████████████████  v4.0  ✓ Activo — Complementos en archivos separados (SBOS-018-API)
SBOS-008  ████████████████████  v1.0  ✓ Activo — Complementos en archivos separados (SBOS-MP01 PARTE A)
SBOS-009  ████████████████████  v1.0  ✓ Activo — Complementos en archivos separados (SBOS-MP01 PARTE B)
SBOS-010  ████████████████████  v7.0  ✓ Activo — Complementos en archivos separados (SBOS-010-WAL §18)
SBOS-011  ████████████████████  v3.0  ✓ Activo — Complementos en archivos separados (SBOS-011-EXT-TRIBUTARIO)
SBOS-012  ████████████████████  v4.0  ✓ Activo
SBOS-013  ████████████████████  v4.0  ✓ Activo
SBOS-014  ████████████████████  v4.0  ✓ Activo — Complementos en archivos separados (SBOS-014-EXT-LLM)
SBOS-015  ████████████████████  v2.0  ✓ Activo
SBOS-016  ████████████████████  v1.0  ✓ Activo
SBOS-017  ░░░░░░░░░░░░░░░░░░░░  v1.0  ⚠ SUPERSEDED — reemplazado por SBOS-017-Roadmap-v2_0.md
SBOS-017  ████████████████████  v2.0  ✓ Activo — fechas absolutas, criterios go/no-go
SBOS-018  ████████████████████  v1.0  ✓ Activo — Complementos en archivos separados (SBOS-018-DEPLOY §7)
SBOS-019  ████████████████████  v2.0  ✓ Activo
SBOS-020  ████████████████████  v2.0  ✓ Activo
SBOS-021  ████████████████████  v1.0  ✓ Activo — Complementos en archivos separados (SBOS-021-ABF, SBOS-MP01 PARTE C)
SBOS-022  ████████████████████  v1.0  ✓ Activo — Complementos en archivos separados (SBOS-022-CQRS, SBOS-022-PGMIG)
SBOS-023  ████████████████████  v1.0  ✓ Activo — Complementos en archivos separados (SBOS-023-EXT-BREACH)
SBOS-024  ████████████████████  v1.0  ✓ Activo — Complementos en archivos separados (SBOS-018-DEPLOY §7.3/§12)
SBOS-025  ████████████████████  v1.0  ✓ Nuevo — ADR Catalog + proceso ARB
SBOS-026  ████████████████████  v1.0  ✓ Nuevo — Backup, Restore y DR
SBOS-027  ████████████████████  v1.0  ✓ Nuevo — Observabilidad OTEL
SBOS-028  ████████████████████  v1.0  ✓ Nuevo — FinOps
SBOS-029  ████████████████████  v1.0  ✓ Nuevo — Portabilidad multi-entorno
SBOS-030  ████████████████████  v1.0  ✓ Nuevo — SGSI ISO 27001:2022
SBOS-031  ████████████████████  v1.0  ✓ Nuevo — Rutina Profesional de Instalación
SBOS-032  ████████████████████  v1.0  ✓ Nuevo — Especificación de Productos
SBOS-033  ████████████████████  v1.0  ✓ Nuevo — Despliegue y Seed File
SBOS-034  ████████████████████  v1.0  ✓ Nuevo — Generador de Identidad Visual
SBOS-035  ████████████████████  v1.0  ✓ Nuevo — SBOS Nexus Host
SBOS-036  ████████████████████  v1.0  ✓ Nuevo — SBOS Nexus Agent
SBOS-037  ████████████████████  v1.0  ✓ Nuevo — Centrifugo WebSocket Bus
SBOS-038  ████████████████████  v1.0  ✓ Nuevo — SKULL Release Plane
SBOS-039  ████████████████████  v1.0  ✓ Nuevo — Flujos de Negocio End-to-End
SBOS-VAL-01  ████████████████████  v1.0  ✓ Completado — Auditoría Sprint 0
SBOS-VAL-02  ████████████████████  v1.0  ✓ Activo — Re-Evaluación Framework Enterprise 2026
```

**Documentos históricos (referencia — no modificar):**
Los archivos de la etapa anterior (SBOS-000-INDEX-v3.md, SBOS-007-BKERNEL-v6.md, etc.) se conservan en el repositorio como referencia histórica con estado `SUPERSEDED`. La numeración y los títulos activos son los de la tabla de esta sección.

---

## 5. Rutas de Lectura por Perfil

**Para entender el proyecto completo** _(lectura obligatoria antes de cualquier trabajo)_:
```
001 → 002 → 039 → 003 → 006
```

**Para entender el SBOS como Sistema Operativo** _(la visión ejecutiva)_:
```
001 → 002 → 039 → 012
```

**Para construir el SBOS IAM Installer** _(SP-01 y SP-02)_:
```
005 → 005-001 → 006 → 004 → 031 → 032 → 033 → 018
```

**Para entender el proceso de instalación y despliegue**:
```
031 → 032 → 033 → 034 → 005 → 004
```

**Para construir el SBOS Data Kernel**:
```
010 → 010-001 → 010-WAL → 002 → 022 → 022-CQRS
```

**Para construir SBOS Data Integration**:
```
011 → 011-001 → 011-TRIBUTARIO → 010 → 006
```

**Para construir SBOS AI Tools**:
```
014 → 014-001 → 014-LLM → 010 → 015 → 022
```

**Para construir SBOS Data RAG**:
```
013 → 013-001 → 014 → 010 → 015
```

**Para construir el SBOS VDI + Nexus**:
```
012 → 035 → 036 → 008 → 008-001 → 019 → 020
```

**Para construir el Core UI**:
```
007 → 005 → 005-001 → 037 → 006 → 018-API
```

**Para entender el dominio de identidad y seguridad completo**:
```
008 → 008-001 → 009 → 019 → 019-001 → 020 → 023
```

**Para crear una ficha nueva**:
```
006 → 005-001(§6 ficha referencia) → 016 → 018
```

**Para configurar identidad y gateway de apps base**:
```
019-001 → 019 → 020 → 008 → 032
```

**Para operar el sistema en producción**:
```
024 → 016 → 017 → 018 → 026
```

**Para entender el modelo de mensajería y eventos**:
```
022 → 022-CQRS → 010 → 010-WAL → 037 → 011
```

**Para hacer una auditoría de seguridad**:
```
023 → 023-BREACH → 030 → 008 → 008-001 → 020
```

**Para incorporarse como desarrollador nuevo**:
```
021 → 001 → 002 → 039 → 006 → 018 → 025
```

**Para Backup, Restore y DR**:
```
026 → 026-SIM → 024 → 028
```

**Para el Release Plane y distribución soberana**:
```
038 → 005(§12) → 018-DEPLOY → 017
```

**Para gobierno arquitectónico**:
```
025 → 025-ARB → 001-OKR → 017 → VAL-02
```

**Para compliance (ISO 27001 / GDPR)**:
```
030 → 023 → 023-BREACH → 022
```

**Para FinOps y portabilidad**:
```
028 → 029 → 016 → 024
```

---

## 6. Glosario de Términos

Este glosario define los términos técnicos del SBOS con precisión. Cuando un término de este glosario aparece en cualquier documento del proyecto, tiene exactamente la definición aquí establecida.

| Término | Definición |
|---|---|
| **ADR** | Architecture Decision Record. Registro formal de una decisión arquitectónica importante, incluyendo el contexto, la decisión tomada, las alternativas rechazadas con justificación, y las consecuencias positivas y negativas. Gobernado por el proceso ARB. Ver SBOS-025. |
| **ARB** | Architecture Review Board. Comité formal que evalúa y aprueba las decisiones arquitectónicas que afectan los principios inquebrantables del SBOS. Reunión mensual. Quórum: 3 miembros (CTO + Arquitecto Lead + 1 representante técnico de dominio). Ver SBOS-025-EXT-ARB. |
| **Absorber → Ejecutar → Liberar** | El ciclo de ejecución de fichas. Absorber: cargar task_catalog.sh en memoria. Ejecutar: correr las fases del yaml_engine.yml. Liberar: eliminar las funciones de memoria para evitar contaminación entre fichas. |
| **Blue/Green (daemons soberanos)** | Estrategia de actualización de binarios systemd (SBOS Data Kernel, SBOS Data Integration, SBOS AI Tools) que lanza el nuevo binario en modo dry-run durante un período de observación antes de hacer el swap atómico. Garantiza < 30 segundos de interrupción y rollback inmediato con el binario previo (.prev). Ver SBOS-018-DEPLOY §7.3. |
| **Bounded Context** | Dominio de negocio con fuente de verdad propia, contratos de integración bien definidos, y responsabilidades claras. El SBOS Data Kernel es el único actor autorizado a cruzar los límites entre bounded contexts. |
| **Bus Factor** | Métrica de riesgo organizacional. Número mínimo de personas cuya salida simultánea dejaría un componente sin mantenimiento. Bus Factor = 1 indica riesgo crítico. Objetivo de SBOS: Bus Factor ≥ 2 en todos los daemons soberanos antes de Q3 2026. Ver SBOS-021-ABF. |
| **Caja (SBOS Data Integration)** | Unidad declarativa de SBOS Data Integration. Equivalente a la ficha del SBOS IAM Installer pero para integración de datos. Contiene: manifest.yml + box_engine.yml + box_catalog.so + resources/. |
| **Core (SP-01)** | Motor Bash del SBOS IAM Installer. 4 archivos maestros: MASTER_INSTALL, TASK_CATALOG, YAML_ENGINE, ARCHITECTURE. |
| **Core UI** | Frontend Flutter del SBOS IAM Installer. Pod K8s en namespace sbos-installer. Multi-dispositivo: web, móvil, tablet, desktop. |
| **CQRS** | Command Query Responsibility Segregation. Patrón de diseño que separa las operaciones de escritura (comandos) de las de lectura (queries). En SBOS, el SBOS Data Kernel implementa CQRS implícitamente: las apps del stack escriben en sus BDs propias (command side) y el SBOS Data Kernel crea proyecciones materializadas para consultas cruzadas (query side). Ver SBOS-022-CQRS. |
| **Daemon Soberano** | Servicio systemd del host Ubuntu que corre fuera de Kubernetes. Tiene acceso directo al WAL de PostgreSQL. Los daemons soberanos son: SBOS IAM Installer, SBOS Data Kernel, SBOS Data Integration, SBOS AI Tools, SBOS Data RAG, SBOS Auth Enforce y SBOS Nexus Host. |
| **DEPENDENCY_RESOLVER** | Módulo Python del SBOS IAM Installer. Construye el DAG de dependencias y calcula el orden de instalación. |
| **depends_on** | Campo en requirements del manifest.yml. Dependencias absolutas. Una ficha no puede instalarse hasta que sus dependencias estén en `INSTALADA — OK`. |
| **diagnosis_first** | Flag en la fase repair del yaml_engine.yml. Obligatorio para fichas con `criticality: true`. Garantiza diagnóstico antes de cualquier acción correctiva. |
| **Embedding Worker** | Pipeline de vectorización que procesa la cola `ai:embed_queue` de Redis. Genera embeddings con modelos locales (Ollama) y los almacena en Qdrant por realm. Permite búsqueda semántica soberana sin APIs externas. |
| **execution_order** | Campo numérico en manifest.yml. Orden de preferencia para la instalación. Prioridad baja — `depends_on` tiene prioridad total. |
| **Feature Flag** | Campo opcional en manifest.yml de una ficha que controla su disponibilidad por tenant. Estados: experimental → beta → ga. El SBOS IAM Installer consulta el atributo del realm en Keycloak para decidir si desplegar la ficha en ese tenant. Ver SBOS-018-DEPLOY §7.2. |
| **Ficha SBOS** | Unidad atómica de despliegue del SBOS. Contrato autocontenido con manifest.yml + yaml_engine.yml + task_catalog.sh + resources/. |
| **Ficha Tipo 1** | Ficha de Sistema. `workload.type: bash`. Corre en el host Ubuntu antes de que K8s exista. Gestionada automáticamente por el SBOS IAM Installer. |
| **Ficha Tipo 2** | Ficha de Aplicación. `workload.type: kubernetes`. Aparece en el menú del Core UI. Tiene dependencias dinámicas. |
| **Ficha Tipo 3** | Ficha Opcional Pura. `criticality: false`. Sin dependencias críticas. Sin impacto si no se instala. |
| **FinOps** | Disciplina de gestión financiera de infraestructura (Financial Operations). En SBOS on-premise, se implementa mediante un modelo de costo por namespace K8s, dashboard Grafana FinOps, alertas de consumo y VPA en modo recomendación. Ver SBOS-028. |
| **hostserver** | Servidor lógico S00. Sus fichas son todas Tipo 1. Responsable únicamente de Ubuntu + Kubernetes. No instala software de negocio. |
| **SBOS IAM Installer** | Control plane soberano del SBOS. Servicio systemd en el host. Instala, vigila, repara y actualiza todo el stack. |
| **SBOS Data Integration** | Integration Exchange Data. Daemon soberano desarrollado por SKULL. Conecta el stack con sistemas externos mediante Cajas declarativas. Toda integración Import/Export pasa por SBOS Data Integration. |
| **SBOS AI Tools** | Business Compass. Daemon soberano desarrollado por SKULL. Observa el stack continuamente y ejecuta Rutas declarativas de inteligencia, análisis, agentes conversacionales y reportes automatizados. No decide por el negocio — orienta. |
| **SBOS Data Kernel** | Business Kernel. Daemon soberano desarrollado por SKULL. Consolida datos entre apps via PostgreSQL WAL. Principio de cero invasión. |
| **OTEL / OpenTelemetry** | Estándar de observabilidad de la CNCF para instrumentar, generar, recopilar y exportar datos de telemetría (métricas, trazas, logs). En SBOS, el OTEL Collector actúa como servicio systemd intermediario entre los daemons soberanos del host y el stack LGTM en K8s. Ver SBOS-027. |
| **Patrón de Búsqueda (SBOS Data RAG)** | Unidad declarativa de SBOS Data RAG. Define cómo indexar y buscar en una app del stack. Contiene: manifest.yml + entities/*.yml + forms/*.yml + routing.yml. |
| **Realm** | Unidad de aislamiento en Keycloak. Cada cliente de SKULL tiene su realm. Multi-tenant por diseño. |
| **RFC (Architecture)** | Request for Comments. Documento de propuesta de decisión arquitectónica, creado como GitHub Issue con label 'architecture-decision'. Inicia el proceso de 5 días de revisión antes de la reunión ARB mensual. Ver SBOS-025-EXT-ARB §4. |
| **RolTemplate** | Esquema declarativo JSON que define qué puede hacer un tipo de rol: privilegios en Tryton, roles en Keycloak, políticas VDI, condiciones de autenticación, jerarquía de herencia. |
| **Route Engine** | Motor declarativo de SBOS AI Tools que interpreta route_engine.yml y ejecuta las fases de una Ruta. Equivalente al YAML Engine del SBOS IAM Installer, pero para procesos de inteligencia. |
| **Ruta (SBOS AI Tools)** | Unidad declarativa de SBOS AI Tools. Define un proceso completo de inteligencia o asistencia. Contiene: manifest.yml + route_engine.yml + route_catalog.so + resources/. |
| **Saga cross-bounded-context** | Patrón de coordinación de transacciones distribuidas entre bounded contexts sin Two-Phase Commit. Cada paso tiene una operación de compensación que revierte si un paso posterior falla. En SBOS, el SBOS Data Kernel actúa como orquestador de Sagas via reglas YAML. Ver SBOS-022-CQRS §4. |
| **sbos-bootstrap** | Conjunto de 3 fichas de sistema (sbos-bootstrap-os, sbos-bootstrap-k8s, sbos-bootstrap-platform) que construyen la plataforma desde Ubuntu virgen hasta K8s operativo. Se intercalan con fichas de aplicación en el grafo DAG. Ver SBOS-031. |
| **sbos_k8s_core()** | Única función que ejecuta `kubectl apply` en todo el sistema. Principio P1 de arquitectura. |
| **Seed File** | Archivo YAML que contiene los datos del cliente (nombre, NIT, dominio, colores, admin, productos) necesarios para un despliegue completo. Se llena antes de la instalación. Ver SBOS-033. |
| **SGSI** | Sistema de Gestión de Seguridad de la Información. Marco organizativo y técnico basado en ISO 27001:2022 que define políticas, controles, y procesos para proteger la confidencialidad, integridad y disponibilidad de la información. Ver SBOS-030. |
| **SBOS** | Sovereign Business Operating System. El producto completo: sistema operativo empresarial soberano. Única marca para todo el proyecto — se usa como prefijo de componentes (SBOS IAM Installer, SBOS Data Kernel) y de documentos (SBOS-005, SBOS-010). |
| **Producto SBOS** | Manifiesto de solución que agrupa fichas + configuraciones para entregar una capacidad completa de negocio (mail, erp, documents, etc.). El instalador evalúa qué existe, amplía lo que falta, e instala lo nuevo. Ver SBOS-032. |
| **Deploy** | Nivel más alto de operación del instalador. Manifiesto que combina datos del cliente (seed file) + lista de productos a instalar. Un solo comando instala todo. Ver SBOS-033. |
| **SKULL** | Systems for Continuous Improvement. La empresa que construye y comercializa SBOS. |
| **SKULL Release Plane** | Infraestructura SKULL que compila, firma y distribuye versiones del SBOS IAM Installer y el catálogo de fichas a todos los clientes. Opera bajo el principio pull-only: el cliente tira, SKULL nunca empuja. |
| **SLO** | Service Level Objective. Umbral de calidad operacional medible y verificable. Define el nivel de servicio esperado por el sistema. |
| **SoA** | Statement of Applicability. Declaración de Aplicabilidad. Documento requerido por ISO 27001 que lista todos los controles del Anexo A, indica cuáles aplican al SGSI de SKULL, justifica las exclusiones y referencia la implementación actual de cada control. Ver SBOS-030 §SoA. |
| **UserTemplate** | Esquema declarativo JSON que define quién es y qué tiene un usuario concreto: identidad, dispositivos, certificaciones, estado operacional, compliance. |
| **WAL** | Write-Ahead Log. Registro de escrituras anticipadas de PostgreSQL. El SBOS Data Kernel lo escucha como bus de eventos nativo. |
| **WAL Event Bus** | Uso del Write-Ahead Log de PostgreSQL como bus de eventos nativo del sistema. Elimina la necesidad de Kafka, RabbitMQ u otros brokers para la comunicación entre daemons soberanos. Provee ordenamiento estricto, durabilidad y Event Sourcing sin infraestructura adicional. |
| **aiserver** | Servidor lógico S15. IA soberana opcional. Todas sus fichas tienen `criticality: false`. Ollama + Qdrant + Open WebUI + Embedding Worker + Langfuse. |
| **Box Engine** | Motor declarativo de SBOS Data Integration que interpreta box_engine.yml y ejecuta las fases de una Caja. Equivalente al YAML Engine del SBOS IAM Installer, pero para integración de datos. |
| **Core UI** | Frontend Flutter del SBOS IAM Installer. Pod K8s en namespace sbos-installer. Multi-dispositivo: web, móvil, tablet, desktop. |

---

## 7. Convenciones de los Documentos

**Nomenclatura:** todos los documentos usan el prefijo `SBOS-0XX`. Los documentos de fichas individuales usan el prefijo `FICHA-<servidor>-<app>`.

**Versiones:** cada documento tiene su propia versión semántica independiente. Un documento en v4.0 no implica que todos los documentos estén en v4.0. Los documentos de la nueva etapa inician en v1.0. Ver tabla de estado arriba.

**Diagramas:** se usan ASCII art para máxima portabilidad — los diagramas deben ser legibles en cualquier editor de texto plano, terminal, y sistema de control de versiones.

**Ejemplos de código:** son extractos reales del proyecto, no pseudocódigo. Si un ejemplo de YAML o Bash aparece en un documento, es el YAML o Bash que se usa en producción.

**Versiones de aplicaciones:** las versiones listadas en SBOS-003 son las vigentes al momento de redacción. Se actualizan cuando una ficha cambia de versión, no cuando el documento se revisa.

**Referencias:** cada documento incluye referencias a los estándares de la industria que fundamentan sus decisiones arquitectónicas. Las decisiones sin referencia son decisiones de diseño propias de SKULL y se documentan explícitamente como tales.

**Documentos históricos:** los archivos de la etapa anterior al v4.0 se conservan en el repositorio con estado `SUPERSEDED`. No se modifican. Son la memoria histórica del proyecto.

### Documentos Complementarios y Extensiones

El repositorio SBOS utiliza un sistema de documentos complementarios para organizar contenido que amplía un documento base sin reemplazarlo. La nomenclatura sigue el patrón: `SBOS-NNN-SUFIJO` donde el sufijo indica el tipo de complemento.

| Sufijo | Descripción | Ejemplo |
|---|---|---|
| **EXT** | Extensión significativa del dominio. Archivo separado permanente. | SBOS-011-EXT-TRIBUTARIO |
| **PGMIG** | Plan de migración de base de datos mayor. | SBOS-022-PGMIG |
| **WAL** | Estrategia WAL/replay específica de un componente. | SBOS-010-WAL |
| **ABF** | Plan Anti-Bus-Factor organizacional. | SBOS-021-ABF |
| **SIM** | Simulacro operativo de un procedimiento. | SBOS-026-SIM |
| **API** | Especificación de API REST y políticas de versionado. | SBOS-018-API |
| **DEPLOY** | Procedimiento de despliegue y estrategia de actualización. | SBOS-018-DEPLOY |

**Tipos de relación entre documento base y complementario:**
- **Integrar:** contenido < 250 líneas, pertenece conceptualmente al doc base. Se fusionará en la próxima versión del doc base.
- **Mantener separado:** contenido > 400 líneas o cubre un dominio específico que merece documento propio. Referencia bidireccional desde el doc base.
- **Referenciar:** posición intermedia — el archivo se mantiene pero ambos documentos tienen referencias explícitas entre sí en sus encabezados.

---

## 8. Marcas y Nomenclatura

| Nombre | Qué es | Contexto de uso |
|---|---|---|
| **SKULL** | La empresa | "SKULL diseñó el sistema de fichas" |
| **SBOS** | El producto completo | "El cliente instala SBOS" |
| **SBOS Data Kernel** | El daemon soberano de consolidación de datos | "El SBOS Data Kernel escucha el WAL" |
| **SBOS Data Integration** | El daemon soberano de integración con externos | "SBOS Data Integration ejecuta la caja de exportación SIAT" |
| **SBOS AI Tools** | El daemon soberano de inteligencia y asistencia | "SBOS AI Tools detectó una anomalía en las ventas del Norte" |
| **SBOS IAM Installer** | La herramienta de instalación y vigilancia | "El SBOS IAM Installer ejecuta la Ficha Bootstrap" |
| **Core (SP-01)** | El motor Bash del SBOS IAM Installer | "SP-01 contiene los 4 archivos maestros" |
| **SBOS VDI** | El SO booteable para endpoints | "El usuario arranca SBOS VDI desde USB" |
| **Core UI** | El frontend Flutter del SBOS IAM Installer | "El administrador instala fichas desde el Core UI" |
| **SKULL Release Plane** | La infraestructura de distribución de SKULL | "El SKULL Release Plane distribuyó v2.1 a 40 clientes" |
| **aiserver** | El servidor lógico de IA soberana (S15) | "El aiserver corre Ollama con qwen3:8b en Perfil A" |
| **OTEL Collector** | Daemon systemd de observabilidad intermediario | "El OTEL Collector recopila métricas de los daemons soberanos" |
| **pgBackRest** | Herramienta de backup incremental de PostgreSQL | "pgBackRest ejecuta el backup WAL archiving hacia MinIO" |
| **Langfuse** | Plataforma de gestión y observabilidad de prompts LLM | "Langfuse registra cada invocación del modelo con su versión de prompt" |

---

## 9. Registro de Cambios

### v6.0 — Marzo 2026

**Actualización derivada de Auditoría SBOS-AUDIT-002.** Esta versión integra los 65 documentos del proyecto, incluyendo los nuevos documentos de conceptualización (035-039), los 7 anexos de especificación interna (-001), y la reorganización de rutas de lectura.

**Cambios en v6.0:**
- **§3 Mapa de Documentos:** ampliado de 35 a 52 entradas. Incluye SBOS-035 (Nexus Host), SBOS-036 (Nexus Agent), SBOS-037 (Centrifugo), SBOS-038 (Release Plane), SBOS-039 (Flujos de Negocio). Añadida sección de Anexos -001 con 7 entradas.
- **§4 Estado de la Documentación:** añadidos SBOS-035 a SBOS-039 con estado.
- **§5 Rutas de Lectura:** reorganizadas de 21 a 24 rutas. Nuevas: "SBOS como Sistema Operativo", "Construir Nexus", "Configurar identidad y gateway", "Release Plane". Actualizadas todas las rutas existentes para incluir anexos -001 en la secuencia de lectura.
- **Nota importante:** SBOS-039 (Flujos de Negocio End-to-End) se agrega a la ruta obligatoria de lectura. Es el documento que demuestra cómo el SBOS funciona como SO desde la perspectiva del usuario — debe leerse ANTES que los documentos técnicos de componentes.

### v5.0 — Marzo 2026

**Actualización derivada de Auditoría Documental SBOS-AUDIT-001-v1.0.** Esta versión expande la cobertura del índice maestro de 25 a 48 documentos e incorpora todas las correcciones identificadas en la auditoría.

**Cambios en v5.0:**
- **§3 Mapa de Documentos:** tabla ampliada de 25 a 35 entradas. Incluye SBOS-025 a SBOS-030, SBOS-026-SIM, SBOS-VAL-01, SBOS-VAL-02. Descripciones de contenido actualizadas en SBOS-007, SBOS-010, SBOS-011, SBOS-014, SBOS-018, SBOS-022, SBOS-024. SBOS-017 ahora muestra v1.0 SUPERSEDED y v2.0 ACTIVO. SBOS-005 corregido a v5.0.
- **§4 Estado de la Documentación:** 6 documentos corregidos de '⏳ En construcción' a '✓ Activo — Complementos en archivos separados' (SBOS-008, 009, 021, 022, 023, 024). Añadidos SBOS-025 a SBOS-030, VAL-01, VAL-02.
- **§5 Rutas de Lectura:** ampliadas de 14 a 21 rutas. 5 rutas nuevas: DR/Backup, Gobierno arquitectónico, Compliance normativo, FinOps, Portabilidad. 4 rutas actualizadas para incluir documentos complementarios.
- **§6 Glosario:** ampliado de 23 a 35 términos. Añadidos: ADR, ARB, RFC, Bus Factor, OTEL/OpenTelemetry, CQRS, Saga cross-bounded-context, Feature Flag, Blue/Green, FinOps, SGSI, SoA.
- **§7 Convenciones:** añadida subsección sobre nomenclatura de documentos complementarios y extensiones (sufijos EXT, PGMIG, WAL, ABF, SIM, API, DEPLOY).
- **§8 Marcas y Nomenclatura:** añadidas entradas para OTEL Collector, pgBackRest y Langfuse.

### v4.0 — Marzo 2026

**Nueva etapa documental.** Este documento reemplazó SBOS-000-INDEX-v3.0 como índice maestro activo del proyecto. El archivo anterior se conserva con estado SUPERSEDED.

**Secciones nuevas en v4.0:**
- §2 Los 8 Daemons Soberanos del SBOS — distinción arquitectónica crítica entre servicios systemd del host y pods K8s.
- §5 Rutas de Lectura expandidas con 6 rutas nuevas.

**Actualizaciones en v4.0:**
- §3 Mapa de Documentos reemplazado con la tabla definitiva SBOS-000 a SBOS-024.
- §4 Estado de la Documentación actualizado para reflejar la nueva etapa.
- §6 Glosario expandido con 11 términos nuevos.

---

_SKULL · SBOS · SBOS-000-INDEX · v6.0 · Índice Maestro y Glosario · Marzo 2026_
_Clasificación: USO INTERNO — Arquitectura y Gobierno_
