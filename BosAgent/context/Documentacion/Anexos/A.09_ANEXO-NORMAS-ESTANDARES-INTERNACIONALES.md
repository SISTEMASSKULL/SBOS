# Anexo A.09 — Matriz de Cumplimiento con Normas y Estándares Internacionales
## Cada decisión del BOS respaldada por el estándar que la exige

**Versión:** 1.0.0 · **Fecha:** 2026-07-17 · **Autor:** bos-developer — SBOS
**Fortalece a:** TODOS los motores

---

## 1. Estándares de Infraestructura y Control

### 1.1 NIST SP 800-207 — Zero Trust Architecture

Define tres componentes obligatorios. El BOS implementa los tres:

| Componente NIST | Definición | Implementación BOS |
|----------------|-----------|-------------------|
| **Policy Engine (PE)** | Evalúa cada request contra políticas dinámicas | bAuth — evalúa 12 dominios (D1-D12) contra RolTemplate, calcula BitMask |
| **Policy Administrator (PA)** | Establece/termina sesiones, emite tokens | **BOS** — `bos.ctx.promote`, `bos.ctx.invalidate`, `bos.ctx.invalidate_all_by_tenant` |
| **Policy Enforcement Point (PEP)** | Intercepta requests, aplica decisiones | Kong + plugin SBOS-Context — valida ctx_id en CADA request |

Alineación con los 7 principios de Zero Trust:
1. Todo recurso es accesible solo vía PEP → Kong como API Gateway único
2. Comunicación independiente de ubicación → ctx_id propagado vía W3C Trace Context
3. Acceso por sesión (least privilege) → BitMask por ctx_id, TTL limitado
4. Política dinámica basada en señales → bAuth evalúa 12 dominios en tiempo real
5. Monitoreo continuo de integridad → Watchdog cada 30s, Reconciler cada 15min
6. Autenticación y autorización dinámicas → LoA 1-4 (RFC 9470), step-up
7. Recolección de datos para mejora continua → bos.cap_snapshot, auditoría

### 1.2 ISA-95 / IEC 62264 — Enterprise-Control System Integration

SBOS implementa los Niveles 3 y 4 de forma nativa:
- **Nivel 3 (Manufacturing Operations):** BOS + bAuth +— contexto, identidad, eventos
- **Nivel 4 (Business Logistics):** Tryton ERP, SmartTax, apps de negocio

### 1.3 ITIL 4 — Infrastructure and Platform Management

Práctica central de ITIL 4. El BOS la implementa:
- **Incident Management:** Watchdog detecta → `bos.query.repair` diagnostica → Saga repara
- **Problem Management:** 3 reintentos → ERROR_NO_CORREGIBLE → causa raíz documentada
- **Change Enablement:** Saga con compensación = plan de rollback validado
- **Service Configuration Management:** `bos.ficha_state` + `bos.ficha_event` (append-only)

---

## 2. Estándares de Seguridad de la Información

### 2.1 ISO/IEC 27001:2022 — Controles técnicos implementados

| Control | Requisito | Implementación BOS | Evidencia |
|---------|-----------|-------------------|-----------|
| **A.5.23** | Seguridad en uso de cloud services | Todo corre en servidor del cliente (soberanía) | SBOS-001-VISION |
| **A.8.2** | Privileged Access Rights | RBAC vía FileRBAC + token compartido para métodos destructivos | `internal/security/` |
| **A.8.5** | Secure Authentication | mTLS entre daemons, TLS 1.3 en :9443 | NRS-01, NRS-03 |
| **A.8.9** | Configuration Management | Fichas declarativas (manifest.yml) = estado deseado. Drift detection SHA-256 cada 15min | `internal/ficha/drift.go` |
| **A.8.15** | Logging | audit_event con ctx_id, timestamp, traceparent. `bos.ficha_event` inmutable append-only | `internal/audit/` |
| **A.8.16** | Monitoring Activities | Watchdog 3-capas cada 30s + Prometheus 18 gauges en :9090 | `internal/watchdog/` |
| **A.8.32** | Change Management | Saga con compensación. 18 estados con transiciones validadas. | ADR-021 |

### 2.2 CIS Kubernetes Benchmark v8

- **4.1.1** — RBAC mínimo: ClusterRole bosagent con least-privilege verificado (`can-i: NO secrets/delete-nodes`)
- **5.x** — NetworkPolicy deny-all default + allowlist explícita por namespace
- **1.x** — Control Plane: TLS 1.3, cipher ECDHE+AES-256-GCM+SHA384

### 2.3 NSA/CISA K8s Hardening Guide

- NetworkPolicy en todos los namespaces (NRS-04)
- Imágenes firmadas con cosign + digest (Kyverno, NRS-10)
- Pod Security Standards: no-root, seccomp, readOnlyRootFilesystem

---

## 3. Estándares de Identidad y Contexto

### 3.1 NIST SP 800-63B — Digital Identity Guidelines

- **IAL2:** identidad verificada con documento oficial (banexus captura via NFC)
- **AAL2:** MFA con passkey o TOTP (ath_method)
- **AAL3:** hardware key FIDO2 (step-up RFC 9470)
- **FAL2:** token federado con firma asimétrica

### 3.2 W3C Trace Context + OpenTelemetry Baggage

El ctx_id se propaga como `traceparent` en headers HTTP y como atributo OTel en spans/logs.
Baggage keys: `tenant.id`, `empresa.id`, `sucursal.id`, `pos.id`, `user.id`, `ctx.id`.

### 3.3 RFC 9562 — UUIDv7 (PKs ordenables por tiempo)

Todas las tablas del schema `bos` usan UUIDv7 como PK, con `DEFAULT uuidv7()` en PostgreSQL 18.

### 3.4 RFC 9470 — OAuth 2.0 Step-up Authentication

LoA 1-4 implementado en `bos.context_session.loa`:
- LoA 1: password
- LoA 2: MFA (TOTP/passkey)
- LoA 3: biométrico (WebAuthn, banexus NFC/huella)
- LoA 4: hardware key (FIDO2)

---

## 4. Estándares de Operación y Calidad

### 4.1 ISO/IEC 20000 — Service Management

| Requisito | Implementación BOS |
|-----------|-------------------|
| Capacity Management | Motor Proyección 7/30/90 días (M5.2) |
| Availability Management | Watchdog 30s + Health Checker + reconciliación |
| Incident Management | Saga repair con diagnóstico pre-repair + 3 reintentos |
| Configuration Management | `bos.ficha_state` + `bos.ficha_event` inmutable |
| Change Management | Saga con compensación + governance dual-control |

### 4.2 Google SRE — Service Reliability Engineering

- **Error Budget:** SLOs verificables con k6 (SBOS-PERF-001)
- **Eliminate Toil:** operaciones manuales → fichas declarativas (SBOS-055)
- **Blameless Postmortems:** `bos.ficha_event` + `bos.bootstrap_event` = trail inmutable

---

## 5. Estándares de Desarrollo

### 5.1 CNCF Operator White Paper

El BOS implementa el Operator Pattern: CRD (manifest.yml) + Controller (observer/reconciler) + Reconcile Loop (15min). Level-based, no edge-based.

### 5.2 GitOps Principles (OpenGitOps)

- **Declarative:** manifest.yml describe estado deseado
- **Versioned & Immutable:** Git es fuente de verdad (servers.yml, ddls.yml)
- **Pulled Automatically:** BOS reconcilia cada 15min
- **Continuously Reconciled:** drift detection + auto-corrección

### 5.3 OWASP API Security Top 10 (2023)

- **API1:2023 — Broken Object Level Authorization:** Cross-tenant validation en ctx_id
- **API2:2023 — Broken Authentication:** Token compartido + mTLS
- **API3:2023 — Broken Object Property Level Authorization:** DTOs separados, omitempty
- **API4:2023 — Unrestricted Resource Consumption:** Rate limiting 100 req/s

---

## 6. Tabla de alineación completa

Cada decisión de arquitectura del BOS está respaldada por al menos un estándar:

| Decisión BOS | Estándar que la exige |
|-------------|----------------------|
| Context API :9443 con TLS 1.3 | NIST 800-207 Tenet 1 · ISO 27001 A.8.5 |
| ctx_id con TTL 8h/12h | NIST 800-207 Tenet 3 · ISO 27001 A.9.4.2 |
| Kong como PEP único | NIST 800-207 §3.2 · OWASP API4:2023 |
| BOS como Policy Administrator | NIST 800-207 §3.2 · ITIL 4 §Infrastructure Mgmt |
| Watchdog 30s | ISO 27001 A.8.16 · NIST 800-137 |
| Fichas declarativas | ISO 27001 A.8.9 · GitOps Principles |
| Sagas con compensación | ITIL 4 §Change Enablement · ISO 20000 |
| Drift detection SHA-256 | ISO 27001 A.8.9 · CIS Benchmark §4 |
| audit_event con ctx_id | ISO 27001 A.8.15 · W3C Trace Context |
| UUIDv7 PKs | RFC 9562 |
| LoA 1-4 | RFC 9470 · NIST 800-63B |
| Operator Pattern level-based | CNCF Operator White Paper · controller-runtime |

---

## 7. Referencias

- [NIST SP 800-207 Zero Trust Architecture](https://csrc.nist.gov/publications/detail/sp/800-207/final)
- [ISO/IEC 27001:2022](https://www.iso.org/standard/27001)
- [CIS Kubernetes Benchmark v8](https://www.cisecurity.org/benchmark/kubernetes)
- [NSA/CISA Kubernetes Hardening Guide](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF)
- [CNCF Operator White Paper](https://www.cncf.io/reports/operator-white-paper/)
- [OpenGitOps Principles](https://opengitops.dev/)
- [OWASP API Security Top 10 (2023)](https://owasp.org/www-project-api-security/)
- [W3C Trace Context](https://www.w3.org/TR/trace-context/)
- [RFC 9562 — UUIDv7](https://www.rfc-editor.org/rfc/rfc9562.html)
- [RFC 9470 — OAuth Step-up](https://www.rfc-editor.org/rfc/rfc9470.html)

---

*SKULL · SBOS · BosAgent · Julio 2026*
