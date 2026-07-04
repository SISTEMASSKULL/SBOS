# SBOS-017-DEVLOG
## Log de Desarrollo — Estándar HUMAN-DOC
### SKULL · SBOS · V8 · Mayo 2026

---

## 1. Archivos Generados

### Archivos Base (000–017) — Migración HUMAN-DOC

| Archivo | Descripción | Sesión | Fecha |
|---|---|---|---|
| SBOS-000-INDEX.md | Índice maestro HUMAN-DOC | Migración HUMAN-DOC | Abr 2026 |
| SBOS-001-VISION.md | Visión y propósito | Migración HUMAN-DOC | Abr 2026 |
| SBOS-002-ARCH.md | Arquitectura general | Migración HUMAN-DOC | Abr 2026 |
| SBOS-003-DOMAIN.md | Modelo de dominio | Migración HUMAN-DOC | Abr 2026 |
| SBOS-004-RULES.md | Reglas de negocio | Migración HUMAN-DOC | Abr 2026 |
| SBOS-005-STACK.md | Stack tecnológico | Migración HUMAN-DOC | Abr 2026 |
| SBOS-006-ADR.md | Decisiones de arquitectura (v1.1 — ADR-010 añadido) | Migración HUMAN-DOC + Completitud | Abr 2026 |
| SBOS-007-DEPLOY.md | Topología de despliegue | Migración HUMAN-DOC | Abr 2026 |
| SBOS-008-INTEGRATION.md | Mapa de integraciones | Migración HUMAN-DOC | Abr 2026 |
| SBOS-009-REPOS.md | Repositorios (§3 ramas POR DECIDIR) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-010-GOVERNANCE.md | Gobernanza | Migración HUMAN-DOC | Abr 2026 |
| SBOS-011-DEV-ENV.md | Entorno desarrollo | Migración HUMAN-DOC | Abr 2026 |
| SBOS-012-MCP.md | Servidores MCP (10 servidores completos) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-013-TESTING.md | Testing (filosofía POR DECIDIR) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-014-ROADMAP.md | Hoja de ruta | Migración HUMAN-DOC | Abr 2026 |
| SBOS-015-SESSION-LOG.md | Log de sesiones (v1.1) | Completitud | Abr 2026 |
| SBOS-016-NOTES.md | Notas (v1.1) | Completitud | Abr 2026 |
| SBOS-017-DEVLOG.md | Este archivo (v1.1) | Completitud | Abr 2026 |

### Archivos de Dominio (018–048) — Migración HUMAN-DOC

| Archivo | Descripción | Sesión | Fecha |
|---|---|---|---|
| SBOS-018-DAEMON-BOS.md | SBOS IAM Installer: Infrastructure Provisioning & Lifecycle Orchestrator | Migración HUMAN-DOC | Abr 2026 |
| SBOS-019-FICHAS.md | Sistema de Fichas — unidad atómica de despliegue | Migración HUMAN-DOC | Abr 2026 |
| SBOS-020-COREUI.md | Core UI — Frontend Flutter del IAM Installer | Migración HUMAN-DOC | Abr 2026 |
| SBOS-021-DAEMON-BAUTH.md | SBOS Auth Enforce: Unified Identity & Permissions Orchestrator | Migración HUMAN-DOC | Abr 2026 |
| SBOS-022-IDENTITY-CONTRACTS.md | Contratos de Identidad: RolTemplate + UserTemplate | Migración HUMAN-DOC | Abr 2026 |
| SBOS-023-DAEMON-BKERNEL.md | SBOS Data Kernel: Active Orchestration Engine (Rust) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-024-DAEMON-BIEDATA.md | SBOS Data Integration: Federated Batch Exchange (Rust) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-025-VDI.md | SBOS VDI: Sovereign Desktop Infrastructure | Migración HUMAN-DOC | Abr 2026 |
| SBOS-026-DAEMON-BSEARCH.md | bSearch: Motor de Búsqueda Federada (RAG) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-027-DAEMON-BCOMPASS.md | SBOS AI Tools: Collaborative & Federated Intelligence | Migración HUMAN-DOC | Abr 2026 |
| SBOS-028-AISERVER.md | aiserver: Servidor de Inteligencia Artificial Soberana | Migración HUMAN-DOC | Abr 2026 |
| SBOS-029-KEYCLOAK.md | Keycloak: Configuración de Identidad Soberana | Migración HUMAN-DOC | Abr 2026 |
| SBOS-030-BOUNDED-CONTEXTS.md | Bounded Contexts, Mensajería y Casos de Uso (DDD) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-031-SECURITY.md | Arquitectura de Seguridad Zero Trust End-to-End | Migración HUMAN-DOC | Abr 2026 |
| SBOS-032-OPERATIONS.md | Libro de Operaciones: SLOs, Alertas y Runbooks | Migración HUMAN-DOC | Abr 2026 |
| SBOS-033-BACKUP-DR.md | Backup, Restore y Disaster Recovery | Migración HUMAN-DOC | Abr 2026 |
| SBOS-034-PORTABILIDAD.md | Portabilidad y Multi-Entorno | Migración HUMAN-DOC | Abr 2026 |
| SBOS-035-INSTALL-ROUTINE.md | Rutina Profesional de Instalación del IAM Installer (16 fichas) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-036-PRODUCTS.md | Especificación de Productos: Manifiestos de Soluciones (8 productos) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-037-DEPLOY-SEED.md | Seed File y Configuración Inicial del Cliente | Migración HUMAN-DOC | Abr 2026 |
| SBOS-038-IDENTITY-VISUAL.md | Generador de Identidad Visual (27 assets) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-039-DAEMON-NEXUS.md | SBOS Nexus: Host (bhnexus) + Agent (banexus) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-040-CENTRIFUGO.md | Bus WebSocket en Tiempo Real (Centrifugo OSS v6) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-041-RELEASE-PLANE.md | Sistema de Distribución Soberana (Ed25519 + canales) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-042-BUSINESS-FLOWS.md | Flujos de Negocio End-to-End (7 flujos) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-043-DATABASE-CATALOG.md | Catálogo de Bases de Datos (DDL 5 BDs daemons + 40 apps) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-044-FISCAL-CONTABLE-LATAM.md | Contabilidad y Facturación Electrónica LATAM (BO/AR/MX/CO) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-045-FINOPS.md | Modelo FinOps y Gestión de Costos On-Premise | Migración HUMAN-DOC | Abr 2026 |
| SBOS-046-ONBOARDING.md | Incorporación + Anti-Bus-Factor (placeholder — Tarea 4.1 pendiente) | Migración HUMAN-DOC | Abr 2026 |
| SBOS-047-ISMS-ISO27001.md | SGSI: Sistema de Gestión de Seguridad ISO 27001:2022 | Migración HUMAN-DOC | Abr 2026 |
| SBOS-048-ADR-CATALOG.md | Catálogo de Decisiones Arquitectónicas (v1.1 — ADR-010 añadido) | Migración HUMAN-DOC + Completitud | Abr 2026 |

### Documentos de Soporte

| Documento | Estado | Nota |
|---|---|---|
| SBOS-PLAN-COMPLETITUD-100.md | Activo | Plan de completitud al 100% del corpus |
| HUMAN-DOC-STANDARD.md | Referencia | Estándar de documentación — no parte del corpus SBOS |

---

## 2. Stack Definitivo

```
SO: Ubuntu Server 26.04 LTS
K8s: kubeadm + CRI-O + Calico + MetalLB
BD: PostgreSQL 17 (Patroni HA 3 nodos)
IAM: Keycloak 26.5.3
Gateway: Kong OSS 3.9.x (LTS — no actualizar a 3.10+ sin ARB) + NGINX
Secrets: Vault (HashiCorp BSL — autoalojamiento libre)
Observabilidad: Prometheus + Grafana + Loki + Tempo + Zabbix + Wazuh
IA: Ollama + Qdrant + Open WebUI + Langfuse
Daemons Rust: bkernel + biedata
Daemons Go: bcompass + bsearch + bauth + bhnexus + banexus
Core: Go (bos/bosctl) + Python 3.11+ (16 módulos IAM) + Bash 5.x (Core SP-01)
UI: Flutter/Dart (Core UI)
Contenedores: Podman (Docker VETADO)
Releases: Ed25519 firma + canary/early/stable
```

---

## 3. Contadores del Corpus

| Tipo | Cantidad |
|---|---|
| Archivos base (000–017) | 18 |
| Archivos de dominio (018–048) | 31 |
| Documentos de soporte | 2 |
| **Total corpus** | **51** |

---

## 4. Subproyectos Smart* Vinculados

| Subproyecto | Prefijo | Documentos | Contexto |
|---|---|---|---|
| SBOS CMS | BOSCMS | 53 docs | E-commerce, Medusa, Tryton, bkernel, context-plane |
| SBOS Smart ORC | BOSORC | 25 docs | Correspondencia, chat, vault flow, retención |
| SBOS Smart Pay | SBOS-PAY | 12 docs | Pagos, cobros, integración financiera |
| SBOS Smart Portfolio | SBOS-Portfolio | 21 docs | Pipeline ingesta IA, productos, aprendizaje |
| SBOS Smart Rates | SBOS-Rates | 23 docs | Motores de tasa, forex, crypto, ticker |
| SBOS Smart Report | SBOS-REPORT | 16 docs | Reporting, JasperReports, interfaces usuario |
| SBOS Smart Tax | SBOS_TAX | 32 docs | Facturación electrónica, SIAT, SIN, impuestos |
| SBOS Smart Vault Flow | SBOS-VAULT | 18 docs | Flujo documental, custodia, firma, auditoría |
| SBOS Tryton | SBOSTRY | 57 docs | Módulos contables, inventario, facturación |
| SBOS-IAM-Style | brand-system | 30 docs | Sistema de marca, logo generator, theming |

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1 Archivos base | Sesión de migración HUMAN-DOC | Generación Abril 2026 |
| §1 Archivos dominio | Sesión de migración HUMAN-DOC | SBOS-000-INDEX §2 tabla de dominio |
| §2 Stack | SBOS-003-STACK v4.0, SBOS-018 v1.0 | Consolidación de versiones |
| §4 Subproyectos | Inventario subproyectos SBOS | Subproyectos Smart* en /desarrollo/sbos/subproyectos/ |

---

## Fuentes de Enriquecimiento V8

| Fuente | Ruta | Tipo | Detalle |
|---|---|---|---|
| BOS_V6_SBOS-017-DEVLOG.md | Procesar/ | V6 Base | Contenido completo preservado |
| subproyectos/ | sbos/subproyectos/ | Smart* | Lista completa de 10 subproyectos Smart* con conteo documental |

---

_SKULL · SBOS · SBOS-017-DEVLOG · V8 · Mayo 2026_
