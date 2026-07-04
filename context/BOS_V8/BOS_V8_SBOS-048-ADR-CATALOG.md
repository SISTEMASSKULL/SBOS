# SBOS-048-ADR-CATALOG
## Catalogo de Decisiones Arquitectonicas — Estandar HUMAN-DOC
### SKULL · SBOS · V8 Enriquecido · Mayo 2026

---

## 1. Proceso ADR

ADR requerido cuando afecta: Principios Inquebrantables (KC, PG, licencias), protocolo WAL/slots, dependencias daemons soberanos, canal Ed25519/Release Plane, S01/S03, cambio de modelo de licenciamiento/distribucion de un componente del stack, o **cambio en la politica de puertos, rangos ClusterIP o subdominios DNS**.

Proceso: RFC como GitHub Issue → 5 dias comentarios → ARB mensual → Arquitecto Lead formaliza en 48h.

---

## 2. Indice

| ID | Titulo | Fecha | Estado |
|---|---|---|---|
| ADR-001 | WAL PostgreSQL como EventBus nativo | 2026-01 | ✅ Aceptada |
| ADR-002 | Daemons soberanos como systemd fuera K8s | 2026-01 | ✅ Aceptada |
| ADR-003 | IAM Installer como daemon residente | 2026-01 | ✅ Aceptada |
| ADR-004 | Keycloak como unico IdP | 2025-09 | ✅ Aceptada |
| ADR-005 | PostgreSQL como unica BD relacional | 2025-09 | ✅ Aceptada |
| ADR-006 | Veto n8n — bCompass como reemplazo | 2025-11 | ✅ Aceptada |
| ADR-007 | Firma Ed25519 todos los artefactos | 2026-01 | ✅ Aceptada |
| ADR-008 | Fichas como unidad atomica de despliegue | 2025-09 | ✅ Aceptada |
| ADR-009 | Rust para CPU-bound, Go para I/O-bound | 2026-03 | ✅ Aceptada |
| ADR-010 | Estrategia API Gateway — Mantener Kong OSS 3.9.x LTS | 2026-04 | ✅ Aceptada |
| ADR-011 | bos IAM Installer como dueño del Context Plane | 2026-05 | ✅ Aceptada |
| ADR-012 | HTTP vetado entre daemons soberanos y aplicaciones Smart* | 2026-05 | ✅ Aceptada |
| ADR-013 | Politica de Puertos SBOS — rangos ClusterIP, SKULL Custom y subdominios | 2026-05 | ✅ Aceptada |
| RFC-004 | Evaluacion ampliacion rango ClusterIP 8100-8999 | 2026-05 | 🔄 Abierto — pendiente ARB |

### Enriquecimiento V8: ADR Smart* subproyectos

| ID | Titulo | Fecha | Estado |
|---|---|---|---|
| ADR-S001 | SmartTax: PostgreSQL 18 como BD exclusiva (uuidv7, io_uring) | 2026-03 | ✅ Aceptada |
| ADR-S002 | SmartTax: Laravel 12 + PHP 8.4 como backend (ext-soap nativo) | 2026-03 | ✅ Aceptada |
| ADR-S003 | SmartTax: Auth switch Passport/Keycloak via AUTH_MODE | 2026-03 | ✅ Aceptada |
| ADR-S004 | SmartReports: microservicio independiente (JasperStarter + Lumen) | 2026-03 | ✅ Aceptada |
| ADR-S005 | SmartTax: endroid/qr-code v5 para QR normativo SIN | 2026-03 | ✅ Aceptada |
| ADR-S006 | SmartTax: luecano/numero-a-letras v2 para literales | 2026-03 | ✅ Aceptada |
| ADR-S007 | SmartTax: Schema APP en PostgreSQL para soporte Flutter | 2026-03 | ✅ Aceptada |
| ADR-S008 | SmartTax: 52 sectores fiscales desde el dia 1 | 2026-03 | ✅ Aceptada |
| ADR-R001 | SmartRates: servicio global con ajustes por empresa | 2026-05 | ✅ Aceptada |
| ADR-R002 | SmartRates: ajuste diario por empresa, nivel global (no por sucursal) | 2026-05 | ✅ Aceptada |
| ADR-R003 | SmartRates: USDT/USDC con politica 'national' mismo flujo que USD | 2026-05 | ✅ Aceptada |
| ADR-R004 | SmartRates: black rate unificado para USD y stablecoins | 2026-05 | ✅ Aceptada |

---

## 3. ADR-001 — WAL como EventBus

**Contexto:** 110+ apps sobre PG compartido necesitan propagacion de cambios SIN modificar ninguna app (cero invasion).

**Decision:** WAL con replicacion logica (pgoutput) es el bus principal. bKernel se suscribe via slots. Sin Kafka, RabbitMQ ni Redis Streams como bus principal.

**Rechazadas:** Kafka+Debezium (complejidad + viola stack minimo), MuleSoft/Boomi (SaaS, viola soberania), Redis Streams (apps no publican), RabbitMQ (sin orden causal), Polling (latencia > SLO 500ms).

**Consecuencias +:** Cero invasion, ordering causal LSN, sin infra adicional, event sourcing nativo.
**Trade-offs:** Dependencia unica PG (Patroni HA), slots no migran en restore (SBOS-033 RK-012), max_slot_wal_keep_size.

---

## 4. ADR-002 — Daemons Soberanos fuera K8s

**Contexto:** bKernel necesita acceso baja latencia a WAL via socket Unix + independencia del ciclo K8s.

**Decision:** Procesos systemd en el host, no pods K8s. Rango de puertos reservado: 9400-9499 (ver SBOS-050 §7.2).

**Rechazadas:** Pod K8s regular (latencia red CNI), DaemonSet (sin acceso socket Unix PG), Sidecar (mismo problema).

**Consecuencias +:** Latencia <100ms, independencia K8s, sin puertos abiertos al exterior.
**Trade-offs:** Punto ciego observabilidad (OTEL Collector), actualizacion fuera de fichas, sin horizontal scaling (vertical + Thread Pool Adaptativo).

---

## 5. ADR-003 — IAM Installer como Daemon

**Contexto:** ¿Script una pasada o proceso permanente para gestionar ciclo de vida fichas?

**Decision:** Daemon residente systemd. Bash (4 archivos OS) + Python (16 modulos orquestacion).

**Rechazadas:** Script Bash largo (sin estado, sin API, sin concurrencia), Cron (no reactivo), ArgoCD (no gestiona systemd), Ansible/Puppet (no reconciliacion continua).

**Consecuencias +:** Reconciliacion cada 15 min, rollback <30s, API REST+WebSocket para Core UI, gestion de flota.
**Trade-offs:** Bootstrapping complejo, 2 lenguajes, estado en JSON.

---

## 6. ADR-004 — Keycloak Unico IdP (Principio 1)

**Contexto:** 110+ apps multi-tenant necesitan identidad centralizada para revocacion inmediata y auditoria.

**Decision:** KC unico IdP. Sin excepciones. Principio 1 del SBOS.

**Rechazadas:** Auth0/Okta (SaaS, viola soberania), LDAP directo (sin OIDC), Authentik (SPIs menos maduros), Auth nativa por app (imposible revocar, imposible H-RBAC).

**Consecuencias +:** Revocacion inmediata (JWT 5min), H-RBAC unificado, multi-tenancy por realm, SPIs extensibles.
**Trade-offs:** SPOF identidad (Patroni HA + SLO 99.99%), curva de aprendizaje.

---

## 7. ADR-005 — PostgreSQL Unica BD Relacional

**Contexto:** ADR-001 creo restriccion tecnica: bus = WAL PG → PG es obligatorio.

**Decision:** PG es la unica BD relacional. Apps con solo MySQL se sincronizan via SymmetricDS.

**Rechazadas:** MySQL como co-primaria (dos buses WAL incompatibles), CockroachDB (licencia BSL), SQLite (sin WAL logico).

**Consecuencias +:** Un solo bus CDC, Patroni HA unificado, un solo backup (pgBackRest), un solo equipo DBA.
**Trade-offs:** 3 apps MySQL legacy requieren SymmetricDS (OrangeHRM, FreePBX, Easy!Appointments).

---

## 8. ADR-006 — Veto n8n, bCompass como Reemplazo

**Decision:** n8n vetado por licencia Sustainable Use (no libre). bCompass soberano: Route Engine + Langfuse + HITL.

---

## 9. ADR-007 — Firma Ed25519 Artefactos

**Decision:** Todo artefacto distribuido por Release Plane firmado con Ed25519. IAM Installer verifica antes de ejecutar. Clave privada solo en HSM/Vault del CI/CD de SKULL.

---

## 10. ADR-008 — Fichas como Unidad Atomica

**Decision:** Cada aplicacion = 1 ficha con manifest.yml + yaml_engine.yml. El daemon bos lee fichas, resuelve DAG de dependencias, ejecuta en orden. Idempotente.

---

## 11. ADR-009 — Rust CPU-bound, Go I/O-bound

**Decision:** bKernel + biedata en Rust (WAL parsing, rule engine, rendimiento critico). bCompass + bSearch + bAuth + bhnexus + banexus en Go (WebSocket, HTTP, alta concurrencia I/O, no latencia critica de CDC).

---

## 12. ADR-010 — Estrategia API Gateway — Mantener Kong OSS 3.9.x LTS

| Campo | Valor |
|---|---|
| **Estado** | ✅ Aceptada — Opcion A: Mantener Kong OSS 3.9.x (LTS activo hasta 2027) |
| **Fecha** | Abril 2026 |
| **Decisor** | Super Usuario (ARB unipersonal) |
| **Revision obligatoria** | Q1 2027 — abrir RFC-002 antes de que expire el LTS de Kong 3.9.x |

**Contexto:** Kong Gateway OSS era el API Gateway del SBOS (S02 gatewayserver, ficha `kong`), distribuido bajo Apache 2.0. En marzo 2025 Kong Inc. realizo dos cambios no anunciados prominentemente con la version 3.10: (1) dejo de publicar imagenes OCI precompiladas para Kong OSS; (2) elimino el "free mode" de Kong Enterprise. La ultima version con imagen OCI oficial disponible sin restricciones es Kong OSS 3.9.x (LTS con soporte hasta 2027).

**Decision:** Mantener Kong OSS 3.9.x (LTS activo hasta 2027). No actualizar mas alla de 3.9.x hasta el horizonte v2.0 (Q2-Q3 2027).

**Alternativas rechazadas:**

| Opcion | Descripcion | Razón del rechazo |
|---|---|---|
| B — Envoy Gateway (CNCF, Apache 2.0) | Migrar el API Gateway a Envoy | Costo de migracion alto en este momento. Re-evaluar en Q1 2027 |
| C — Imagenes comunitarias Kong 3.10+ | Usar builds de Tetrate u otros partners | Dependencia de tercero no auditado — viola cadena de confianza Ed25519 |

---

## 13. ADR-011 — bos IAM Installer como Dueño del Context Plane

| Campo | Valor |
|---|---|
| **Estado** | ✅ Aceptada |
| **Fecha** | Mayo 2026 |
| **Decisor** | Ivan Villanueva (Arquitecto Lider) |
| **Documento de referencia** | SBOS-049-CONTEXT-PLANE v3.0 |

**Contexto:** SBOS requiere un Plano de Contexto Distribuido que mantenga el estado operativo de cada usuario en cada tenant — incluyendo la sesion pre-autenticacion (dctx_id), la sesion autenticada (ctx_id), el arbol de contextos permitidos, y la vinculacion logico-fisico (POS logico ↔ dispositivo fisico).

---

## 14. ADR-012 — HTTP Vetado entre Daemons Soberanos y Aplicaciones Smart*

| Campo | Valor |
|---|---|
| **Estado** | ✅ Aceptada |
| **Fecha** | Mayo 2026 |
| **Decisor** | Ivan Villanueva (Arquitecto Lider) |

**Decision:** HTTP entre los 8 daemons soberanos y entre daemons y aplicaciones propias SKULL (Smart*) esta **vetado**. Toda comunicacion usa exclusivamente WebSocket o Unix socket.

---

## 15. ADR-013 — Politica de Puertos SBOS

| Campo | Valor |
|---|---|
| **Estado** | ✅ Aceptada |
| **Fecha** | Mayo 2026 |
| **Decisor** | Ivan Villanueva (Arquitecto Lider) |

**Decision:** Adoptar el esquema de tres capas (containerPort canonico / ClusterIP SBOS derivable / exposicion externa) con rangos formalizados: 8100-8999 ClusterIP, 9400-9499 daemons, 28100-28999 SKULL Custom Apps.

---

## 16. RFC-004 — Evaluacion Ampliacion Rango ClusterIP SBOS

| Campo | Valor |
|---|---|
| **Estado** | 🔄 Abierto — pendiente evaluacion ARB |
| **Apertura** | Mayo 2026 |
| **Origen** | SBOS-050-PORT-CATALOG §12.4 DEBT-001 |

---

## 17. ADR Smart* — Catalogo Extendido

### ADR-S001: SmartTax PostgreSQL 18 con CloudNativePG

| Campo | Valor |
|---|---|
| **Estado** | ✅ Aceptada |
| **Fecha** | Marzo 2026 |
| **Contexto** | Necesitamos una BD robusta, con PKs cronologicas nativas, maximo rendimiento I/O, y operacion en K8s sin downtime. |
| **Decision** | PostgreSQL 18 con imagen `ghcr.io/cloudnative-pg/postgresql:18` (CloudNativePG). uuidv7() nativo, io_uring para async I/O, SCRAM-SHA-256, TLS 1.3. |
| **Alternativas descartadas** | PostgreSQL 16 (sin uuidv7 nativo), MySQL (sin RLS nativo), MongoDB (sin transacciones ACID completas) |

### ADR-S002: SmartTax Laravel 12 + PHP 8.4

| Campo | Valor |
|---|---|
| **Estado** | ✅ Aceptada |
| **Contexto** | Stack del equipo. `ext-soap` nativo en PHP para integracion WSDL SIN. Codigo PHP existente de referencia. |
| **Decision** | Laravel 12 + PHP 8.4-FPM + Ubuntu 24.04 LTS |
| **Alternativas descartadas** | Python/FastAPI (sin codigo de referencia), Node.js (ecosistema SOAP deficiente) |

### ADR-S003: Auth switch Passport/Keycloak

| Campo | Valor |
|---|---|
| **Estado** | ✅ Aceptada |
| **Decision** | Laravel Passport por defecto. Keycloak 24 OIDC como opcion enterprise. Switch via `AUTH_MODE` en `.env`. |

### ADR-S004: SmartReports como microservicio independiente

| Campo | Valor |
|---|---|
| **Estado** | ✅ Aceptada |
| **Decision** | JasperStarter 3.6.2 + Java 17 Temurin + Lumen 11 en container `sbos-smartreports`. API REST: `POST /generate`. |
| **Razón** | Escala independientemente. Java necesario para Jasper. Desacoplado del core PHP. |

### ADR-R001: SmartRates servicio global con ajustes por empresa

| Campo | Valor |
|---|---|
| **Estado** | ✅ Aceptada |
| **Fecha** | Mayo 2026 |
| **Decision** | SmartRates es un servicio general del ecosistema SBOS. Las cotizaciones oficiales (BCB, referencial BCB, USDT P2P, USDC P2P) son globales. Los ajustes (black rate, diferencial) son por empresa. |
| **Impacto** | GET /api/v1/rates/today → cotizaciones globales. GET con ?include_company_adjustments=true → agrega ajustes de empresa. Separacion de schemas: `rates.*` (global) y `company.*` (ajustes por empresa). |

### ADR-R002: Ajuste diario por empresa, nivel global

| Campo | Valor |
|---|---|
| **Estado** | ✅ Aceptada |
| **Decision** | El ajuste es a nivel global del SBOS por empresa. Todas las sucursales de una empresa usan el mismo ajuste. `X-SBOS-Sucursal` no afecta al ajuste. |
| **Clave unica** | `UNIQUE (company_id, currency_code, rate_date)` — NO incluye sucursal_id |

### ADR-R003: USDT/USDC con politica 'national' mismo flujo que USD

| Campo | Valor |
|---|---|
| **Estado** | ✅ Aceptada |
| **Decision** | USDT y USDC siguen exactamente la misma logica que el black rate de USD. Los bancos bolivianos estan usando el dolar paralelo oficial para aplicar el cambio USDT/USDC. |
| **Politica extendida** | `use_black_rate` cubre tambien stablecoins: disabled (oficial BCB), reference (muestra black rate y P2P), national (aplica black rate tanto para USD como para USDT/USDC). |

### ADR-R004: Black rate unificado para USD y stablecoins

| Campo | Valor |
|---|---|
| **Estado** | ✅ Aceptada |
| **Decision** | El black rate de USDT = black rate USD (misma referencia de mercado paralelo). No existe un black rate independiente para cada stablecoin — el mercado boliviano equipara ambas. |

---

## Trazabilidad

| Seccion | Extraida de | Notas |
|---|---|---|
| §1 Proceso | SBOS-025 v1.0 + Sesion Mayo 2026 | Criterio de ADR ampliado para incluir cambios en politica de puertos |
| §2 Indice | SBOS-048 v1.3 + Sesion Mayo 2026 | ADR-012, ADR-013, RFC-004 añadidos |
| §3–11 ADR-001 a 009 | SBOS-025 v1.0 | ADR-002 actualizado con referencia a rango 9400-9499 |
| §12 ADR-010 | SBOS-048 v1.3 | Añadida referencia a SBOS-050 §17 R2 (Kong Admin nunca externo) |
| §13 ADR-011 | SBOS-048 v1.3 | Añadida referencia a puerto 9443 Context API |
| §14 ADR-012 | Sesion Mayo 2026 — nuevo | HTTP vetado entre daemons y Smart*. Referencia SBOS-050 |
| §15 ADR-013 | Sesion Mayo 2026 — nuevo | Politica de Puertos SBOS |
| §16 RFC-004 | Sesion Mayo 2026 — nuevo | Rango ClusterIP insuficiente |

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Aportacion |
|---|---|---|
| V5 | /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-025-ADR-Catalog-v1_0.md | Catalogo ADR base V5 |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_DECISIONS.md | 8 ADRs SmartTax (S001-S008): PostgreSQL 18, Laravel 12, auth Passport/Keycloak, SmartReports microservicio, QR normativo, literales, schema APP, 52 sectores fiscales |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_E2_DECISIONES_RAMA_LOGICA.md | Decisiones de rama logica fiscal: revision manual, calculo secuencial, redondeo HALF-UP, validacion de cliente |
| Smart Rates | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Rates/context/SBOS-Rates-020-DECISIONES-CONSOLIDADAS.md | 4 ADRs SmartRates (R001-R004): servicio global con ajustes por empresa, ajuste diario no por sucursal, USDT/USDC mismo flujo que USD, black rate unificado |
| Correlacion V8 | Consolidacion ADRs Smart* | Catalogo extendido con ADR-S001 a ADR-R004 |

---

_SKULL · SBOS · SBOS-048-ADR-CATALOG · V8 Enriquecido · Mayo 2026_
