# SBOS-000-INDEX
## Indice Maestro — Estandar HUMAN-DOC (Enriquecido V8)
### SKULL · SBOS — Sovereign Business Operating System
### v1.5-V8 · Mayo 2026

---

## 1. Identidad del Proyecto

| Campo | Valor |
|---|---|
| **Nombre** | Sovereign Business Operating System |
| **Abreviatura** | SBOS |
| **Empresa** | SKULL — Systems for Continuous Improvement |
| **Fase actual** | Sprint 0 completado, Sprint 1 en ejecucion |
| **Version del producto** | Pre-release (hacia v0.9) |
| **Repositorio** | github.com/SISTEMASSKULL/sbos |
| **Estandar documental** | HUMAN-DOC v1.0 |
| **Modelo de desarrollo** | Ingenieria Aumentada: Ivan Villanueva (Arquitecto Lider) + Juan Perez (Administrador de Dominios) + 6 Agentes de Dominio |

### V5 Enriquecimiento — Contexto Corporativo

SKULL — Systems for Continuous Improvement es una firma de ingenieria y consultoria estrategica que disena, construye y despliega infraestructura empresarial soberana para organizaciones de Iberoamerica. Su producto principal es SBOS — el primer sistema operativo empresarial soberano disenado especificamente para el contexto iberoamericano: sus regulaciones tributarias, su estructura de mercado PYME, su necesidad de independencia tecnologica, y su realidad de conectividad y hardware.

SKULL no vende software. Vende soberania operacional: la capacidad de una organizacion de controlar completamente su tecnologia, sus datos y sus procesos — sin dependencia de ningun proveedor externo.

**Principio fundacional de la documentacion:** cada documento debe ser autocontenido y justificar sus decisiones tecnicas con referencia a patrones de la industria. Un desarrollador que lea SBOS-006 debe entender no solo que es una ficha sino por que ese diseno es la eleccion correcta frente a las alternativas.

---

## 2. Mapa de Documentos

### Archivos Base (000–017)

| # | Archivo | Nombre | Proposito |
|---|---------|--------|-----------|
| 000 | INDEX | Indice Maestro | Navegacion, glosario, estado, rutas de lectura |
| 001 | VISION | Vision y Proposito | Definicion tecnica fundacional SBOS como OS empresarial, ISA-95, tres dominios, soberania, OKRs |
| 002 | ARCH | Arquitectura General | SBOS como SO, 5 capas, 8 daemons, WAL como Event Bus |
| 003 | DOMAIN | Modelo de Dominio | Entidades, relaciones, bounded contexts, fronteras |
| 004 | RULES | Reglas de Negocio | 14+1 principios inquebrantables, compliance, seguridad, estandares Go |
| 005 | STACK | Stack Tecnologico | 110+ apps, 16 servidores logicos, versiones, licencias |
| 006 | ADR | Decisiones de Arquitectura | ADR-001 a ADR-010, proceso ARB, template RFC |
| 007 | DEPLOY | Topologia de Despliegue | K8s, servidores logicos S00–S15, seed file, ambientes |
| 008 | INTEGRATION | Mapa de Integraciones | WAL como bus, contratos inter-daemon, APIs externas |
| 009 | REPOS | Repositorios | Monorepo, TBD, politica PR 1/2+ integrantes, CI/CD |
| 010 | GOVERNANCE | Gobernanza | Ivan Villanueva + Juan Perez HITL, ARB, ISO 27001, PDCA |
| 011 | DEV-ENV | Entorno de Desarrollo | Windows+SSH→Linux, Podman, VS Code, reglas del agente |
| 012 | MCP | Conexiones MCP | 10 servidores MCP, capacidades, restricciones, HITL por operacion |
| 013 | TESTING | Estrategia de Testing | Integration-First, herramientas, cobertura, CI gates, SonarQube |
| 014 | ROADMAP | Hoja de Ruta | SP-01 a SP-16, fases A–D, gates go/no-go |
| 015 | SESSION-LOG | Log de Sesiones | Estado actual, progreso, contexto para retomar |
| 016 | NOTES | Notas | Deuda tecnica, pendientes, decisiones de sesion |
| 017 | DEVLOG | Log de Desarrollo | Archivos generados, stack definitivo |

### Archivos de Dominio (018–050)

| # | Archivo | Nombre | Fuentes originales |
|---|---------|--------|--------------------|
| 018 | DAEMON-BOS | SBOS IAM Installer | SBOS-005, SBOS-005-001 |
| 019 | FICHAS | Sistema de Fichas | SBOS-006 |
| 020 | COREUI | Core UI Frontend | SBOS-007 |
| 021 | DAEMON-BAUTH | SBOS Auth Enforce | SBOS-008, SBOS-008-001 |
| 022 | IDENTITY-CONTRACTS | Contratos de Identidad | SBOS-009 |
| 023 | DAEMON-BKERNEL | SBOS Data Kernel | SBOS-010, SBOS-010-001, SBOS-010-WAL |
| 024 | DAEMON-BIEDATA | SBOS Data Integration | SBOS-011, SBOS-011-001 |
| 025 | VDI | Escritorio Soberano | SBOS-012 |
| 026 | DAEMON-BSEARCH | SBOS Data RAG | SBOS-013, SBOS-013-001 |
| 027 | DAEMON-BCOMPASS | SBOS AI Tools | SBOS-014, SBOS-014-001, SBOS-014-LLM |
| 028 | AISERVER | Infraestructura IA | SBOS-015 |
| 029 | KEYCLOAK | Keycloak Auth Methods + Data | SBOS-019, SBOS-019-001, SBOS-020 |
| 030 | BOUNDED-CONTEXTS | Bounded Contexts + CQRS | SBOS-022, SBOS-022-CQRS, SBOS-022-PGMIG |
| 031 | SECURITY | Arquitectura de Seguridad | SBOS-023, SBOS-023-Breach |
| 032 | OPERATIONS | Libro de Operaciones | SBOS-024 |
| 033 | BACKUP-DR | Backup, Restore y DR | SBOS-026, SBOS-026-SIM |
| 034 | PORTABILIDAD | Multi-Entorno | SBOS-029 |
| 035 | INSTALL-ROUTINE | Rutina de Instalacion | SBOS-031 |
| 036 | PRODUCTS | Productos SBOS | SBOS-032 |
| 037 | DEPLOY-SEED | Despliegue y Seed File | SBOS-033 |
| 038 | IDENTITY-VISUAL | Generador de Identidad | SBOS-034 |
| 039 | DAEMON-NEXUS | Par Nexus Soberano (bhnexus + banexus) | SBOS-035, SBOS-036 |
| 040 | CENTRIFUGO | Bus WebSocket | SBOS-037 |
| 041 | RELEASE-PLANE | Distribucion Soberana | SBOS-038 |
| 042 | BUSINESS-FLOWS | Flujos End-to-End | SBOS-039 |
| 043 | DATABASE-CATALOG | Catalogo de BDs y DDL | SBOS-040 |
| 044 | FISCAL-CONTABLE-LATAM | Contabilidad y Facturacion LATAM | SBOS-011-Tributario |
| 045 | FINOPS | Modelo FinOps | SBOS-028 |
| 046 | ONBOARDING | Incorporacion + ABF + Ingenieria Aumentada | SBOS-021, SBOS-021-ABF, SBOS-COMPLETITUD-v4 |
| 047 | ISMS-ISO27001 | SGSI ISO 27001:2022 + PHVA | SBOS-030 |
| 048 | ADR-CATALOG | Catalogo de ADRs | SBOS-025, investigacion Kong 3.10, Sesion Mayo 2026 |
| 049 | CONTEXT-PLANE | Plano de Contexto Distribuido | Sesion Mayo 2026 — nuevo |
| **050** | **PORT-CATALOG** | **Politica de Puertos, Subdominios y Segmentacion de Red** | **Sesion Mayo 2026 — nuevo. Fuente de verdad para toda asignacion de puertos TCP/UDP y subdominios DNS** |

### Documentos de Soporte (no migrados a HUMAN-DOC)

| Documento | Disposicion |
|---|---|
| SBOS-017-Roadmap-v1_0 | SUPERSEDED — reemplazado por v2.0 |
| SBOS-MP01 a MP06 | Planes maestros internos — archivo historico |
| SBOS-AUDIT-001 a 003 | Auditorias — archivo historico |
| SBOS-VAL-01, VAL-02 | Validaciones — referenciadas desde 010-GOVERNANCE |
| SBOS-AYUDA-MEMORIA | Reemplazado por 015-SESSION-LOG + 016-NOTES |
| SBOS-008-ROLFRAMEWORK | SUPERSEDED — contenido distribuido en 021, 022, 029, 018. Absorcion completa |
| SBOS-COMPLETITUD-v1/v2/v3/v4 | SUPERSEDED — plan ejecutado al 100%. Archivo historico |

### V5 Enriquecimiento — Mapa de Documentos Original

La version V5 del indice (v6.0, Marzo 2026) organizaba los documentos bajo una numeracion diferente centrada en componentes del sistema:

| Codigo V5 | Documento V5 | Version |
|---|---|---|
| SBOS-000 | Indice Maestro y Glosario | v5.0 |
| SBOS-001 | Vision y Alcance del Proyecto | v4.0 + OKR |
| SBOS-002 | Arquitectura General del Sistema | v4.0 |
| SBOS-003 | Catalogo del Stack Tecnologico | v4.0 |
| SBOS-004 | Infraestructura Kubernetes | v4.0 |
| SBOS-005 | SBOS IAM Installer — Control Plane Soberano | v5.0 |
| SBOS-006 | Sistema de Fichas | v4.0 |
| SBOS-007 | Core UI — Frontend del SBOS IAM Installer | v4.0 |
| SBOS-008 | Gobierno de Identidad | v1.0 |
| SBOS-009 | Contratos de Identidad | v1.0 |
| SBOS-010 | SBOS Data Kernel: Active Orchestration Engine | v7.0 |
| SBOS-011 | SBOS Data Integration — Motor de Integracion Soberano | v3.0 |
| SBOS-012 | SBOS VDI — Escritorio Soberano | v4.0 |
| SBOS-013 | SBOS Data RAG | v4.0 |
| SBOS-014 | SBOS AI Tools — Motor de Inteligencia Soberano | v4.0 |
| SBOS-015 | aiserver — Infraestructura de IA Soberana | v2.0 |
| SBOS-016 | Mapa de Servidores Logicos | v1.0 |
| SBOS-017 | Subproyectos y Hoja de Ruta | v2.0 |
| SBOS-018 | Estandares de Calidad y Principios | v1.0 |
| SBOS-019 | Keycloak — Metodos de Autenticacion | v2.0 |
| SBOS-020 | Keycloak — Datos Internos y JWT | v2.0 |
| SBOS-021 | Guia de Incorporacion al Equipo | v1.0 |
| SBOS-022 | Bounded Contexts y Modelo de Mensajeria | v1.0 |
| SBOS-023 | Arquitectura de Seguridad Zero Trust | v1.0 |
| SBOS-024 | Libro de Operaciones | v1.0 |
| SBOS-025 | Catalogo de Decisiones Arquitectonicas (ADR) | v1.0 |
| SBOS-026 | Backup, Restore y Disaster Recovery | v1.0 |
| SBOS-026-SIM | Plan de Simulacro DR | v1.0 |
| SBOS-027 | Observabilidad OTEL — Daemons Soberanos | v1.0 |
| SBOS-028 | Modelo FinOps y Gestion de Costos | v1.0 |
| SBOS-029 | Portabilidad y Multi-Entorno | v1.0 |
| SBOS-030 | SGSI — ISO 27001:2022 | v1.0 |
| SBOS-031 | Rutina de Instalacion | v1.0 |
| SBOS-032 | Productos SBOS | v1.0 |
| SBOS-033 | Despliegue y Seed File | v1.0 |
| SBOS-034 | Generador de Identidad Visual | v1.0 |
| SBOS-035 | SBOS Nexus Host | v1.0 |
| SBOS-036 | SBOS Nexus Agent | v1.0 |
| SBOS-037 | Centrifugo — Bus WebSocket | v1.0 |
| SBOS-038 | Release Plane — Distribucion Soberana | v1.0 |
| SBOS-039 | Flujos de Negocio End-to-End | v1.0 |
| SBOS-040 | Catalogo de Bases de Datos y DDL | v1.0 |

Los documentos SBOS-027, SBOS-031 a SBOS-040 fueron incorporados progresivamente del V5 al V6 como archivos de dominio 018-050, manteniendo la integridad del contenido y anadiendo las referencias HUMAN-DOC.

---

## 3. Estado de Documentacion

| # | Archivo | Estado | Cobertura | Notas |
|---|---------|--------|-----------|-------|
| 000 | INDEX | ✅ Completo | 100% | v1.5 — 050-PORT-CATALOG anadido. Rutas de lectura actualizadas. ADR-012/013 registrados |
| 001 | VISION | ✅ Completo | 100% | v2.0 Mayo 2026 — §2 Definicion Tecnica Fundacional: SBOS como OS empresarial, ISA-95, tres dominios |
| 002 | ARCH | ✅ Completo | 95% | WAL, 5 capas, 8 daemons, fronteras |
| 003 | DOMAIN | ✅ Completo | 92% | 9 BCs, entidades, relaciones |
| 004 | RULES | ✅ Completo | 95% | Principios, seguridad, licencias, estandares Go completos |
| 005 | STACK | ✅ Completo | 98% | 16 servidores, 110+ apps, licencias |
| 006 | ADR | ✅ Completo | 100% | v1.3 — ADR-010 ✅ Aceptada Kong OSS 3.9.x LTS |
| 007 | DEPLOY | ✅ Completo | 95% | v1.1 — §11 servicios por namespace completado |
| 008 | INTEGRATION | ✅ Completo | 95% | v1.1 — §7 catalogo eventos WAL por BC completado |
| 009 | REPOS | ✅ Completo | 95% | v1.2 — TBD + politica PR + Branch Protection Rules |
| 010 | GOVERNANCE | ✅ Completo | 97% | v1.3 — Ivan Villanueva + Juan Perez en tabla HITL |
| 011 | DEV-ENV | ✅ Completo | 95% | v1.1 — VS Code oficial, extensiones |
| 012 | MCP | ✅ Completo | 95% | 10 servidores MCP completos |
| 013 | TESTING | ✅ Completo | 97% | v1.4 — Integration-First + SonarQube Quality Gate |
| 014 | ROADMAP | ✅ Completo | 92% | Fases A–D, versiones, subproyectos, criterios Go/No-Go |
| 015 | SESSION-LOG | ✅ Completo | 100% | v1.3 Mayo 2026 — sesion Context Plane + SBOS como OS empresarial |
| 016 | NOTES | ✅ Completo | 100% | v1.4 Mayo 2026 — PORT-CATALOG, ADR-012/013, RFC-004, CONFLICT-001/002 resueltos |
| 017 | DEVLOG | ✅ Completo | 97% | v1.1 — 51 archivos listados |
| 018 | DAEMON-BOS | ✅ Completo | 100% | v1.2 — §18.1 ciclo vida multitenant. Responsable del Context Plane (049) |
| 019 | FICHAS | ✅ Completo | 98% | Definicion, contratos, estados, versionado |
| 020 | COREUI | ✅ Completo | 97% | 5 vistas, API, Flutter, multi-dispositivo |
| 021 | DAEMON-BAUTH | ✅ Completo | 100% | v1.2 — Tabla Maestra BitMask 64-bit. Alimenta el Context Plane |
| 022 | IDENTITY-CONTRACTS | ✅ Completo | 100% | v1.3 — flujo onboarding magic link |
| 023 | DAEMON-BKERNEL | ✅ Completo | 98% | Rust, CDC, Rule Engine, MDM, DLQ. Persiste context_sessions |
| 024 | DAEMON-BIEDATA | ✅ Completo | 98% | Rust, cajas, Box Engine, tributario. Aduana soberana: export fiscal SIAT/AFIP/SAT/DIAN |
| 025 | VDI | ✅ Completo | 97% | Fedora KDE, bAuth, BitMask escritorio, NFS. Nodo banexus |
| 026 | DAEMON-BSEARCH | ✅ Completo | 97% | Typesense + Qdrant, patrones, Schema Discoverer |
| 027 | DAEMON-BCOMPASS | ✅ Completo | 97% | Route Engine, Ollama, Approval Gates, HITL |
| 028 | AISERVER | ✅ Completo | 97% | Qwen3, Qdrant, Embedding Worker |
| 029 | KEYCLOAK | ✅ Completo | 96% | 16 metodos auth, 5 SPIs custom, multi-tenant. Fuente del Identity Context |
| 030 | BOUNDED-CONTEXTS | ✅ Completo | 97% | 9 BCs, canales mensajeria, casos de uso |
| 031 | SECURITY | ✅ Completo | 97% | Zero Trust, 6 vectores, ISO 27001 |
| 032 | OPERATIONS | ✅ Completo | 97% | SLOs, Alertmanager, runbooks |
| 033 | BACKUP-DR | ✅ Completo | 97% | pgBackRest, restore, simulacro DR |
| 034 | PORTABILIDAD | ✅ Completo | 96% | Ubuntu/Debian, multi-entorno, ARM64 |
| 035 | INSTALL-ROUTINE | ✅ Completo | 97% | 16 fichas, DAG, timeline 48 min |
| 036 | PRODUCTS | ✅ Completo | 97% | 8 productos, manifiestos, requirements |
| 037 | DEPLOY-SEED | ✅ Completo | 97% | Seed file, 6 secciones, 9 pasos |
| 038 | IDENTITY-VISUAL | ✅ Completo | 96% | 27 assets, pipeline sharp |
| 039 | DAEMON-NEXUS | ✅ Completo | 96% | Par Nexus Soberano: bhnexus :9444 WSS/mTLS + banexus edge. ~15ms auth fisica |
| 040 | CENTRIFUGO | ✅ Completo | 95% | Bus WebSocket, 8 canales, auth JWT |
| 041 | RELEASE-PLANE | ✅ Completo | 96% | Ed25519, canales rollout |
| 042 | BUSINESS-FLOWS | ✅ Completo | 97% | 7 flujos end-to-end |
| 043 | DATABASE-CATALOG | ✅ Completo | 97% | DDL 5 BDs daemons, 40 apps. Incluye context_sessions (049) |
| 044 | FISCAL-CONTABLE-LATAM | ✅ Completo | 96% | BO/AR/MX/CO, circuit breaker |
| 045 | FINOPS | ✅ Completo | 95% | PromQL, Grafana, VPA |
| 046 | ONBOARDING | ✅ Completo | 100% | v1.3 Mayo 2026 — corpus BOS-Agent y Auth-Agent actualizados con 049 |
| 047 | ISMS-ISO27001 | ✅ Completo | 96% | PHVA, SoA 20 controles |
| 048 | ADR-CATALOG | ✅ Completo | 100% | v1.4 Mayo 2026 — ADR-012 (HTTP vetado daemons), ADR-013 (politica puertos), RFC-004 abierto |
| 049 | CONTEXT-PLANE | ✅ Completo | 100% | v3.0 Mayo 2026 — Plano de Contexto Distribuido. bos como dueno. pre-auth → auth → operacion |
| **050** | **PORT-CATALOG** | **✅ Completo** | **100%** | **v3.1 Mayo 2026 — 1.844 lineas, 7 Partes. Politica de puertos, subdominios, NetworkPolicies. 110+ apps, 8 daemons. CONFLICT-001/002 resueltos. RFC-004 documentado** |

**Cobertura global estimada:** ~99.9%

**Elementos pendientes (no bloqueantes):**
- Sesiones de transferencia de conocimiento (SBOS-046 §3.2) — condicionadas a incorporacion de Juan Perez
- Exercises de validacion BF por equipo (SBOS-046 §2.3) — condicionados a Juan Perez activo
- RFC-002 API Gateway (SBOS-006 ADR-010) — programado Q1 2027
- RFC-003 Context Plane implementation — pendiente de Sprint B
- RFC-004 evaluacion ampliacion rango ClusterIP — pendiente ARB (pre-requisito: reubicar daemons 9400→9500)

---

## 4. Rutas de Lectura

### Obligatoria — Comprension del proyecto
```
001-VISION → 002-ARCH → 042-BUSINESS-FLOWS → 003-DOMAIN → 005-STACK
```

### SBOS como Sistema Operativo Empresarial ← Leer antes de cualquier otra ruta
```
001-VISION §2 → 049-CONTEXT-PLANE §2-§3 → 002-ARCH → 021-DAEMON-BAUTH §8 → 039-DAEMON-NEXUS §6
```
*Responde: que es SBOS en terminos tecnicos precisos, como unifica los tres dominios (logico/fisico/financiero), y como el ciclo de sesion completo (pre-auth → auth → operacion) funciona en la vida real.*

### Plano de Contexto Distribuido
```
049-CONTEXT-PLANE → 018-DAEMON-BOS §18.1 → 021-DAEMON-BAUTH §8 → 039-DAEMON-NEXUS → 023-DAEMON-BKERNEL §14
```
*Responde: que es el ctx_id, como se crea, como se propaga, que hace bos con el, como se vincula a audit_events.*

### Infraestructura y Redes ← NUEVA
```
050-PORT-CATALOG §1-§5 → 050-PORT-CATALOG §7 → 050-PORT-CATALOG §12 → 007-DEPLOY → 035-INSTALL-ROUTINE
```
*Responde: que puertos usa cada servicio, como se derivan los ClusterIPs, que esta prohibido, como esta configurado el firewall y los subdominios DNS.*

### Construir el SBOS IAM Installer (SP-01, SP-02)
```
018-DAEMON-BOS → 019-FICHAS → 007-DEPLOY → 035-INSTALL-ROUTINE → 036-PRODUCTS → 037-DEPLOY-SEED → 004-RULES → 049-CONTEXT-PLANE §10 → 050-PORT-CATALOG §7.2
```

### Construir el SBOS Data Kernel
```
023-DAEMON-BKERNEL → 002-ARCH → 030-BOUNDED-CONTEXTS → 043-DATABASE-CATALOG → 049-CONTEXT-PLANE §12
```

### Construir SBOS Data Integration
```
024-DAEMON-BIEDATA → 044-FISCAL-CONTABLE-LATAM → 023-DAEMON-BKERNEL → 019-FICHAS → 050-PORT-CATALOG §7.2 (biedata)
```

### Construir SBOS AI Tools
```
027-DAEMON-BCOMPASS → 028-AISERVER → 023-DAEMON-BKERNEL → 030-BOUNDED-CONTEXTS
```

### Construir SBOS Data RAG
```
026-DAEMON-BSEARCH → 027-DAEMON-BCOMPASS → 023-DAEMON-BKERNEL → 028-AISERVER
```

### Construir VDI + Par Nexus Soberano
```
025-VDI → 039-DAEMON-NEXUS → 021-DAEMON-BAUTH → 029-KEYCLOAK → 049-CONTEXT-PLANE §16 → 050-PORT-CATALOG §7.2 (bhnexus+banexus)
```
*049 §16 para entender el ciclo completo pre-auth → BitMask → chapas/cajones. 050 §7.2 para los puertos del Par Nexus.*

### Construir Core UI
```
020-COREUI → 018-DAEMON-BOS → 040-CENTRIFUGO → 019-FICHAS
```

### Dominio de identidad y seguridad
```
021-DAEMON-BAUTH → 022-IDENTITY-CONTRACTS → 029-KEYCLOAK → 031-SECURITY → 049-CONTEXT-PLANE §5 → 050-PORT-CATALOG §17
```

### Operacion en produccion
```
032-OPERATIONS → 007-DEPLOY → 014-ROADMAP → 033-BACKUP-DR → 050-PORT-CATALOG §10 (NodePorts mantenimiento)
```

### Asignacion de puertos y subdominios ← NUEVA
```
050-PORT-CATALOG §5 (NO DISPONIBLES) → §18 (proceso) → §12 (ClusterIP) → §13 (SKULL Custom) → §15 (subdominios)
```
*Consultar antes de cualquier trabajo que involucre puertos, manifiestos K8s, reglas UFW o subdominios DNS.*

### Onboarding de desarrollador (Juan Perez)
```
046-ONBOARDING §0 → 046-ONBOARDING §1 → 001-VISION → 002-ARCH → 049-CONTEXT-PLANE → 042-BUSINESS-FLOWS → 019-FICHAS → 004-RULES → 006-ADR → 050-PORT-CATALOG §1-§5
```

### Ruta de equipo (secuencia de Juan Perez)
```
Semana 1: 018-DAEMON-BOS → 019-FICHAS → 035-INSTALL-ROUTINE → 036-PRODUCTS → 004-RULES → 049-CONTEXT-PLANE → 050-PORT-CATALOG §3/§7.2/§12 [Equipo BOS]
Semana 2: 021-DAEMON-BAUTH → 022-IDENTITY-CONTRACTS → 029-KEYCLOAK → 025-VDI → 049-CONTEXT-PLANE §5-§6 [Equipo AUTH]
Semana 3: 023-DAEMON-BKERNEL → 043-DATABASE-CATALOG → 033-BACKUP-DR → 030-BOUNDED-CONTEXTS [Equipo KERNEL]
Semana 4: 027-DAEMON-BCOMPASS → 026-DAEMON-BSEARCH → 028-AISERVER [Equipo INTELLIGENCE]
Semana 5: 020-COREUI → 040-CENTRIFUGO → 019-FICHAS [Equipo FRONTEND]
Semana 6: 024-DAEMON-BIEDATA → 044-FISCAL-CONTABLE-LATAM → 008-INTEGRATION → 050-PORT-CATALOG §7.2 (biedata) [Equipo INTEGRATIONS]
```

### Backup y DR
```
033-BACKUP-DR → 032-OPERATIONS → 045-FINOPS
```

### Release Plane y distribucion
```
041-RELEASE-PLANE → 018-DAEMON-BOS → 007-DEPLOY → 014-ROADMAP
```

### Gobierno arquitectonico
```
006-ADR → 048-ADR-CATALOG → 010-GOVERNANCE → 001-VISION → 014-ROADMAP
```

### Compliance ISO 27001 / GDPR
```
047-ISMS-ISO27001 → 031-SECURITY → 030-BOUNDED-CONTEXTS → 049-CONTEXT-PLANE §14 → 050-PORT-CATALOG §2 (marco normativo)
```

### FinOps y portabilidad
```
045-FINOPS → 034-PORTABILIDAD → 007-DEPLOY → 032-OPERATIONS
```

### V7 Enriquecimiento — Ruta de dominio de identidad extendida (V7)

La reconceptualizacion V7 anade una ruta especifica para comprender la arquitectura de dominios de autenticacion y el modelo BitMask corregido:

```
021-DAEMON-BAUTH → BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION → BOS_V7_SBOS-BAUTH-DECISIONES-ARQUITECTURA → 022-IDENTITY-CONTRACTS → 029-KEYCLOAK → 031-SECURITY
```

*Responde: como se formalizan los 9 dominios de autenticacion, como se corrigio el modelo SAM-128 hacia BitmaskBundle, y cuales son las decisiones arquitectonicas detras de cada SPI de Keycloak.*

### Smart* Enriquecimiento — Rutas de subproyectos

Cada subproyecto Smart* tiene su propia ruta dentro del ecosistema SBOS:

```
SmartTax: 005-STACK §S05 → 024-DAEMON-BIEDATA → SBOS_TAX_00_PLAN_MAESTRO_INGENIERIA → SBOS_TAX_E1_INVARIANTES_FISCALES
SmartORC: 029-KEYCLOAK → 023-DAEMON-BKERNEL → BOSORC-001-VISION → BOSORC-002-DOMINIO → (handover) SmartVaultFlow
SmartVaultFlow: BOSORC-001-VISION (angulo 4) → SBOS-VAULT-001-VISION → SBOS-VAULT-002-DOMINIO → SBOS-VAULT-005-INTEGRACIONES
SmartRates: SBOS-Rates-001-VISION → SBOS-Rates-002-DOMINIO → SBOS-Rates-020-DECISIONES-CONSOLIDADAS
```

---

## 5. Glosario

| Termino | Definicion |
|---|---|
| **ADR** | Architecture Decision Record. Registro formal de decision arquitectonica con contexto, alternativas y consecuencias. Gobernado por ARB. |
| **Administrador de Dominios** | Rol de Juan Perez. Segundo titular del Bus Factor. Opera el sistema apoyado en Agentes de Dominio. Ver SBOS-046-ONBOARDING §0. |
| **Agente de Dominio** | Instancia de Claude configurada con el subcorpus HUMAN-DOC de un equipo. Asistente tecnico especializado bajo supervision del Administrador de Dominios. NO aprueba ADRs ni toma decisiones arquitectonicas. |
| **ARB** | Architecture Review Board. Comite mensual que evalua decisiones que afectan principios inquebrantables. Quorum: CTO + Arquitecto Lead + 1 representante de dominio. |
| **Absorber → Ejecutar → Liberar** | Ciclo de ejecucion de fichas: cargar task_catalog.sh → ejecutar yaml_engine.yml → eliminar funciones de memoria. |
| **BitMask 64-bit** | Entero de 64 bits calculado por bAuth que representa los privilegios exactos de un usuario en un contexto dado. Capa 1 (bits 0-9): permisos ERP. Capa 2 (bits 10-23): permisos VDI/fisico/hardware. Gobierna que apps, chapas, cajones y zonas puede usar el usuario. Ver SBOS-021 §8. |
| **BitmaskBundle (V7 corregido)** | Estructura de 3×uint64 que reemplaza el BitMask 64-bit monolotico en la arquitectura V7. Compuesto por: PhysicalDomainMask (hardware, zonas, actuadores), LogicalDomainMask (apps, modulos de negocio), FinancialDomainMask (SoD, limites, aprobaciones). Corrige el error conceptual de colapsar tecnologias (VDI=Fedora, ERP=Tryton) en dominios abstractos. Ver BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION. |
| **Blue/Green (daemons)** | Actualizacion de binarios systemd con dry-run, observacion y swap atomico. <30s interrupcion, rollback inmediato con .prev. |
| **Bounded Context** | Dominio de negocio con fuente de verdad propia y contratos de integracion definidos. El SBOS Data Kernel es el unico actor que cruza limites entre BCs. |
| **Bus Factor** | Metrica de riesgo organizacional. Objetivo: ≥2 en todos los equipos soberanos antes de Q3 2026. Se mide por equipo, no por daemon individual. |
| **Caja (biedata)** | Unidad declarativa de SBOS Data Integration: manifest.yml + box_engine.yml + box_catalog.so + resources/. Implementa los flujos de export (SIAT, AFIP, SAT, DIAN) e import (Excel, CSV, XML) a traves del SBOS. |
| **ClusterIP SBOS** | Puerto interno de K8s Service derivado por la formula `BASE_SERVIDOR + (FICHA×10) + TIPO`. Rango: 8100-8999. Ver SBOS-050 §12. |
| **Context Plane** | Capa transversal responsable del Contexto Operativo Distribuido. Dueno: bos IAM Installer. Componentes: Context Registry (Redis + bkernel_db), ctx_id, context_sessions, eventos contextuales. Ver SBOS-049. |
| **context.promoted** | Evento que marca el momento en que una sesion anonima (dctx_id) se eleva a sesion autenticada (ctx_id). Permite vincular retroactivamente la actividad pre-autenticacion al usuario identificado. |
| **Core (SP-01)** | Motor Bash del SBOS IAM Installer: MASTER_INSTALL, TASK_CATALOG, YAML_ENGINE, ARCHITECTURE. |
| **Core UI** | Frontend Flutter del SBOS IAM Installer. Pod K8s multi-dispositivo. |
| **CQRS** | Command Query Responsibility Segregation. Apps escriben en sus BDs (command), SBOS Data Kernel crea proyecciones (query). |
| **ctx_id** | Identificador unico de una Context Session activa. Propaga el contexto empresarial completo (tenant/empresa/sucursal/pos/usuario/pod/nodo) a traves de todos los servicios como OTel Baggage header. Ver SBOS-049 §5. |
| **dctx_id** | Device Context ID. Identificador de contexto pre-autenticacion. El bos lo crea cuando un dispositivo arranca. Se vincula al ctx_id en el evento context.promoted. |
| **Daemon Soberano** | Servicio systemd del host Ubuntu fuera de K8s con acceso directo al WAL de PostgreSQL. 8 daemons: bos, bkernel, biedata, bcompass, bsearch, bauth, bhnexus + banexus (cliente Fedora). Puertos: rango reservado 9400-9499. Ver SBOS-050 §7.2. |
| **depends_on** | Campo en manifest.yml. Dependencias absolutas — ficha no se instala hasta que dependencias esten en INSTALADA_OK. |
| **Dominio de autenticacion** | Categoria abstracta de control de acceso definida por estandar internacional. El SBOS V7 reconoce 9 dominios: Logico, Fisico, Financiero, Red, Aplicacion, Biometrico, Federado, Organizacional, Normativo. Los tres centrales (Logico-Fisico-Financiero) tienen representacion directa en el BitmaskBundle. Ver BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION. |
| **Dominios (bAuth)** | Los tres dominios de control simultaneo que bAuth evalua en cada solicitud: Logico (apps, red, LoA), Fisico (zonas, chapas, horario), Financiero (limites, SoD). Ver SBOS-021 §1. |
| **Embedding Worker** | Pipeline de vectorizacion: cola ai:embed_queue Redis → Ollama → Qdrant por realm. |
| **Equipo (BOS/AUTH/KERNEL/etc.)** | Unidad organizativa del modelo de Ingenieria Aumentada. Agrupa daemons y componentes por dominio tecnico. Un Agente de Dominio por equipo. BF se mide por equipo. |
| **execution_order** | Campo numerico en manifest.yml. Orden de preferencia, subordinado a depends_on. |
| **Feature Flag** | Control de disponibilidad por tenant en manifest.yml. Estados: experimental → beta → ga. |
| **Ficha SBOS** | Unidad atomica de despliegue: manifest.yml + yaml_engine.yml + task_catalog.sh + resources/. |
| **Ficha Tipo 1** | Ficha de Sistema. workload.type: bash. Corre en host antes de K8s. |
| **Ficha Tipo 2** | Ficha de Aplicacion. workload.type: kubernetes. Aparece en Core UI. |
| **Ficha Tipo 3** | Ficha Opcional Pura. criticality: false. Sin impacto si no se instala. |
| **FinOps** | Gestion financiera de infraestructura on-premise: costo por namespace, dashboard Grafana, alertas, VPA. |
| **HITL** | Human-In-The-Loop. Humano que toma decisiones finales y aprueba cambios criticos. |
| **Ingenieria Aumentada** | Modelo de desarrollo SBOS: 2 humanos reales (Ivan Villanueva + Juan Perez) + Agentes de Dominio especializados. Los agentes multiplican la capacidad operativa de Juan sin reemplazar el juicio humano. |
| **ISA-95 / IEC 62264** | Estandar internacional de integracion de sistemas empresariales y de control (Enterprise-Control System Integration). SBOS implementa este estandar de forma nativa y soberana. Ver SBOS-001-VISION §2.5. |
| **OTEL** | OpenTelemetry. Estandar CNCF de observabilidad. OTEL Baggage es el mecanismo de propagacion del ctx_id entre servicios (W3C Baggage header). |
| **Par Nexus Soberano** | Unidad compuesta de dos daemons: bhnexus (Sovereign Connectivity Broker, host Ubuntu) + banexus (Edge Sentinel, Fedora VDI). Opera como una sola entidad funcional para la autenticacion fisica en <50ms. Ver SBOS-039. |
| **Patron de Busqueda** | Unidad declarativa de SBOS Data RAG: manifest.yml + entities/*.yml + forms/*.yml + routing.yml. |
| **PDCA** | Plan-Do-Check-Act. Ciclo de mejora continua aplicado en gobernanza. |
| **PHVA** | Planear-Hacer-Verificar-Actuar. Columna vertebral del SGSI ISO 27001:2022 (ver 047-ISMS). |
| **PORT-CATALOG** | SBOS-050. Fuente de verdad para toda asignacion de puertos TCP/UDP y subdominios DNS. Prevalece sobre todos los demas documentos del corpus en materia de puertos. |
| **Realm** | Unidad de aislamiento en Keycloak. Un realm por cliente. Multi-tenant por diseno. |
| **RFC (Architecture)** | Request for Comments. GitHub Issue con label architecture-decision. Revision de 5 dias antes de ARB. |
| **RolTemplate** | Esquema JSON declarativo de privilegios: Tryton, Keycloak, VDI, autenticacion, herencia. |
| **Route Engine** | Motor declarativo de SBOS AI Tools que interpreta route_engine.yml. |
| **Ruta (bCompass)** | Unidad declarativa de SBOS AI Tools: manifest.yml + route_engine.yml + route_catalog.so + resources/. |
| **SBOS como OS Empresarial** | SBOS es un Sistema Operativo Empresarial Distribuido y Soberano con plano de control unificado sobre tres dominios simultaneos: logico, fisico y financiero. Definicion tecnica completa en SBOS-001-VISION §2. Verificable en v1.0 GA (Sep 2026). |
| **Saga** | Coordinacion de transacciones distribuidas entre BCs sin 2PC. SBOS Data Kernel como orquestador via reglas YAML. |
| **Seed File** | YAML con datos del cliente para despliegue: identidad, red, admin, productos, llaves. |
| **SKULL Custom Apps** | Rango de puertos 28100-28999 reservado para aplicaciones propias SKULL (Smart*). Ver SBOS-050 §13. |
| **Smart*** | Linea de productos propios SKULL en S05 devserver: SmartTax, SmartReport, SmartRates, SmartORC, SmartVaultFlow, SmartPortfolio, SmartPay, SBOS IAM Style, SBOS CMS. Puertos containerPort en rango 28100-28180. |
| **Super Usuario** | Alias de Ivan Villanueva en el corpus tecnico. Conservado por compatibilidad con toda la documentacion anterior. |
| **WAL** | Write-Ahead Log de PostgreSQL. Bus de eventos nativo del SBOS. Fuente de toda sincronizacion. |

---

## 6. Convenciones

### Nomenclatura de archivos
```
SBOS-[NNN]-[NOMBRE].md

000-017  = Archivos base (reservados, estructura HUMAN-DOC)
018+     = Archivos de dominio (especificos de SBOS)
```

### Marcas y nombres

| Nombre | Que es | Uso |
|---|---|---|
| **SKULL** | La empresa | "SKULL diseno el sistema de fichas" |
| **SBOS** | El producto | "El cliente instala SBOS" |
| **SBOS Data Kernel** | Daemon de consolidacion | "El SBOS Data Kernel escucha el WAL" |
| **SBOS Data Integration** | Daemon de integracion | "SBOS Data Integration ejecuta la caja SIAT" |
| **SBOS AI Tools** | Daemon de inteligencia | "SBOS AI Tools detecto anomalia" |
| **SBOS IAM Installer** | Control plane soberano + dueno del Context Plane | "El SBOS IAM Installer gestiona el ctx_id del tenant" |
| **Core UI** | Frontend Flutter | "El admin instala fichas desde Core UI" |
| **SBOS VDI** | SO booteable | "El usuario arranca SBOS VDI" |
| **SKULL Release Plane** | Distribucion soberana | "Release Plane distribuyo v2.1" |
| **Ivan Villanueva** | Arquitecto Lider (Super Usuario) | "Ivan aprueba el ADR" |
| **Juan Perez** | Administrador de Dominios | "Juan diagnostica con el Kernel-Agent" |
| **Par Nexus Soberano** | Unidad compuesta bhnexus+banexus | "El Par Nexus autentica la chapa en 15ms" |

### Jerarquia de fuentes (en caso de conflicto)

```
1 (maxima) → Archivos HUMAN-DOC (este corpus)
              NOTA: en materia de puertos TCP/UDP y subdominios DNS,
              SBOS-050-PORT-CATALOG prevalece sobre todos los demas documentos.
2          → Normativa legal / regulaciones oficiales
3          → Estandares tecnicos (ISO, IEEE, CNCF, W3C, ISA-95/IEC 62264, NIST)
4          → Documentacion oficial de APIs/software
5          → Documentos conceptuales originales SBOS
6 (menor)  → Ideas o asunciones no verificadas
```

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1 Identidad | SBOS-000 v1.4 | Sin cambios |
| §1 V5 Enriquecimiento | BOS_V5_SBOS-000-INDEX-v6_0.md | §1 Proposito de esta Documentacion, §2 La Empresa: SKULL |
| §2 Mapa de Documentos | SBOS-000 v1.4 + Sesion Mayo 2026 | 050-PORT-CATALOG anadido; 039 actualizado a Par Nexus Soberano; 048 actualizado a v1.4 |
| §2 V5 Mapa Original | BOS_V5_SBOS-000-INDEX-v6_0.md | §3 Mapa de Documentos tabla completa |
| §3 Estado | SBOS-000 v1.4 + Sesion Mayo 2026 | 050 nuevo (v3.1), 048 actualizado (v1.4), 016 actualizado (v1.4); RFC-004 en pendientes |
| §4 Rutas de Lectura | SBOS-000 v1.4 + Sesion Mayo 2026 | Dos rutas nuevas (Infraestructura/Redes, Asignacion puertos); 050 anadido en rutas BOS, VDI+Nexus, Operacion, IAM, KERNEL INTEGRATIONS, ISO 27001, Onboarding; §18 en ruta construir biedata |
| §4 V7 Ruta identidad | BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md | Ruta extendida para dominios de autenticacion |
| §4 Smart* Rutas | BOSORC-001-VISION, SBOS-VAULT-001-VISION, SBOS_TAX_00_PLAN_MAESTRO_INGENIERIA_v6.md, SBOS-Rates-001-VISION | Rutas de subproyectos |
| §5 Glosario | SBOS-000 v1.4 + Sesion Mayo 2026 | Nuevos: ClusterIP SBOS, Par Nexus Soberano, PORT-CATALOG, SKULL Custom Apps, Smart*, Caja (ampliado). Actualizados: Daemon Soberano (referencia 050 §7.2), Caja (flujos export/import) |
| §5 Glosario V7 | BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md | Nuevo: BitmaskBundle (V7 corregido), Dominio de autenticacion |
| §6 Convenciones | SBOS-000 v1.4 | Par Nexus Soberano anadido a marcas y nombres; nota prevalencia PORT-CATALOG en jerarquia de fuentes |

---

## Fuentas de Enriquecimiento V8

| Fuente | Tipo | Contenido aportado |
|---|---|---|
| BOS_V6_SBOS-000-INDEX.md | V6 (canonico) | Contenido base completo preservado |
| BOS_V5_SBOS-000-INDEX-v6_0.md | V5 | Contexto corporativo SKULL, principio fundacional documentacion, mapa de documentos V5 original, tabla V5 completa |
| BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md | V7 | BitmaskBundle, dominios de autenticacion, ruta extendida identidad |
| BOSORC-001-VISION.md (Smart ORC) | Smart* | Ruta de subproyecto SmartORC |
| SBOS-VAULT-001-VISION.md (Smart Vault Flow) | Smart* | Ruta de subproyecto SmartVaultFlow |
| SBOS_TAX_00_PLAN_MAESTRO_INGENIERIA_v6.md (Smart Tax) | Smart* | Ruta de subproyecto SmartTax |
| SBOS-Rates-001-VISION.md (Smart Rates) | Smart* | Ruta de subproyecto SmartRates |

---

_SKULL · SBOS · SBOS-000-INDEX · HUMAN-DOC v1.5-V8 · Mayo 2026_
_Reemplaza: v1.4 (Mayo 2026)_
_Cambios v1.5: 050-PORT-CATALOG incorporado al corpus (#050); 039 actualizado a Par Nexus Soberano; 048 actualizado a v1.4 (ADR-012/013/RFC-004); 016 actualizado a v1.4; rutas de lectura: dos nuevas (Infraestructura/Redes, Asignacion puertos), todas las rutas de equipo actualizadas con 050; glosario: 6 terminos nuevos + 2 actualizados; nota de prevalencia PORT-CATALOG en jerarquia de fuentes; RFC-004 en elementos pendientes_
_Enriquecimiento V8: V5 contexto corporativo + mapa V5 original + V7 BitmaskBundle + Smart* rutas de subproyectos + tabla de fuentes de enriquecimiento_
