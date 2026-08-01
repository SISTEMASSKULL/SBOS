# A.18 — Gestión de Vulnerabilidades Técnicas: Rol de bos

| Metadato | Valor |
|----------|-------|
| **Versión** | 1.0.0 |
| **Fecha** | 2026-08-01 |
| **Control ISO** | ISO 27001:2022 A.8.8 — Management of Technical Vulnerabilities |
| **Clasificación** | INTERNO CRÍTICO |
| **Originado por** | Análisis de brecha A.71 bAuth — revisión colaborativa bos↔bAuth |
| **Contraparte** | `BauthAgent/context/Documentacion/anexos/BACKLOG-DDL-ISO27001.md` T-BACKLOG-009 |

---

## 1. Contexto — Por qué este anexo existe

Durante la revisión del informe de cumplimiento ISO 27001:2022 de bAuth (A.71), la discrepancia
A.8.8 (vulnerabilidades técnicas) reveló que su responsabilidad es **compartida entre bos y bAuth**,
pero que el **registro central de CVEs y el inventario de infraestructura pertenecen exclusivamente
a bos** como plano de control soberano del ecosistema SBOS.

Este documento define:
1. Por qué bos es el dueño de la capa de infraestructura en la gestión de vulnerabilidades
2. Qué tablas DDL debe implementar bos para cerrar su parte del gap
3. El protocolo de colaboración con bAuth via JSON-RPC

---

## 2. Fundamento — Por qué bos es el dueño de la infraestructura

### 2.1 Lo que bos ya es (evidencia del código)

bos es el **SBOS IAM Installer, Infrastructure Provisioning & Lifecycle Orchestrator** — el
plano de control soberano (día 0/1/2). Su código ya implementa los componentes que
naturalmente llevan a la propiedad de vulnerabilidades de infraestructura:

| Módulo bos | Función actual | Extensión natural a vulnerabilidades |
|-----------|---------------|-------------------------------------|
| `internal/observer/` | Loop DAG topológico — observa pods y eventos del sistema | Detectar componentes con CVEs activas en el inventario |
| `internal/reconcile/` | Drift detection — compara estado declarado vs real | Detectar versiones desplegadas que difieren del estado seguro esperado |
| `internal/watchdog/` | Watchdog daemon + release rollback | Disparar rollback automático cuando CVE crítica afecta un componente activo |
| `internal/k8s/` | Único dispatcher kubectl | Aplicar parches de K8s y actualizar imágenes de contenedores |
| `internal/repair/` | Repair manager | Ejecutar remediaciones programadas de CVEs |
| `internal/health/` | Health checker | Integrar estado de seguridad (CVEs pendientes) en el health check |

### 2.2 Lo que la industria establece

Investigación sobre el modelo de responsabilidad compartida en gestión de vulnerabilidades
(fuentes: AWS Shared Responsibility, Wiz Academy, ISO 27001:2022 A.8.8, NIST SP 800-40 Rev.4,
Open Security Architecture SP-038):

> *"En entornos IaaS/PaaS, el proveedor/plano de control es responsable de la seguridad
> de la infraestructura (OS, K8s, redes, hipervisor); el cliente/daemon es responsable
> de las vulnerabilidades en su propio código y dependencias."*

> *"Los programas de vulnerabilidades fallan cuando los hallazgos, la propiedad del activo
> y los plazos de remediación viven en herramientas separadas — la centralización es crítica."*

> *"Una vulnerabilidad en un workload con permisos IAM amplios tiene mayor impacto que
> en un servicio de bajo privilegio."* — bAuth, como IAM central de SBOS, tiene el mayor
> radio de impacto; bos como plano de control tiene la visión global.

### 2.3 División de responsabilidades bos ↔ bAuth

```
┌─────────────────────────────────────────────────────────────┐
│                    ECOSISTEMA SBOS                          │
│                                                             │
│  ┌──────────────────────────────┐                          │
│  │  bos (plano de control)      │                          │
│  │  ─────────────────────────   │                          │
│  │  Dueño de:                   │                          │
│  │  • OS patches (Ubuntu/Debian)│                          │
│  │  • Kubernetes (pods, images) │  ──→  bos.vul_cve_registry│
│  │  • PostgreSQL 18             │  ──→  bos.vul_infra_component
│  │  • Vault (PKI/secrets)       │                          │
│  │  • Redis                     │                          │
│  │  • Kong / Nginx              │                          │
│  │  • Wazuh (SIEM)              │                          │
│  └───────────────┬──────────────┘                          │
│                  │  JSON-RPC: bauth.vulnerability.notify   │
│                  ↓                                          │
│  ┌──────────────────────────────┐                          │
│  │  bAuth (plano de identidad)  │                          │
│  │  ─────────────────────────   │                          │
│  │  Dueño de:                   │                          │
│  │  • Rust crates (auth stack)  │  ──→  bauth.vul_component│
│  │  • Librerías OIDC/SAML/JWT   │  ──→  bauth.vul_auth_impact
│  │  • WebAuthn / FIDO2          │                          │
│  │  • Crypto libs (ring, openssl│                          │
│  │  • 18 métodos de auth        │                          │
│  └──────────────────────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Gap de bos — Tablas DDL que debe implementar

### 3.1 Tabla 1 — Registro central de CVEs del ecosistema

```sql
-- Schema: bos (Context Plane)
-- Registro único de CVEs que afectan a cualquier componente del ecosistema SBOS
CREATE TABLE IF NOT EXISTS bos.vul_cve_registry (
    cve_id          TEXT         PRIMARY KEY,           -- "CVE-2026-12345"
    title           TEXT         NOT NULL,
    description     TEXT         NOT NULL,
    cvss_score      NUMERIC(3,1) NOT NULL,              -- 0.0-10.0 CVSS v3.1
    severity        TEXT         NOT NULL               -- CRITICAL/HIGH/MEDIUM/LOW/INFO
        CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW','INFO')),
    affected_layer  TEXT         NOT NULL               -- INFRASTRUCTURE/AUTH_STACK/SHARED
        CHECK (affected_layer IN ('INFRASTRUCTURE','AUTH_STACK','SHARED')),
    published_at    TIMESTAMPTZ  NOT NULL,              -- fecha publicación NVD/CISA
    discovered_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),-- cuándo bos lo detectó
    source          TEXT         NOT NULL               -- NVD/CISA/CARGO_AUDIT/TRIVY/MANUAL
        CHECK (source IN ('NVD','CISA','CARGO_AUDIT','TRIVY','SNYK','MANUAL')),
    sla_deadline    TIMESTAMPTZ  NOT NULL,              -- calculado según severity
    status          TEXT         NOT NULL DEFAULT 'OPEN'
        CHECK (status IN ('OPEN','IN_PROGRESS','MITIGATED','PATCHED','ACCEPTED','WONT_FIX')),
    owner_daemon    TEXT         NOT NULL               -- 'bos'/'bauth'/'shared'
        CHECK (owner_daemon IN ('bos','bauth','bkernel','biedata','bsearch','bnexus','bnotify','shared')),
    cve_url         TEXT,                               -- https://nvd.nist.gov/vuln/detail/CVE-...
    ctx_id          TEXT         NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- SLA automático por severidad (trigger):
-- CRITICAL  → +1 día   (24 horas)
-- HIGH      → +7 días
-- MEDIUM    → +30 días
-- LOW       → +90 días
```

### 3.2 Tabla 2 — Inventario de componentes de infraestructura

```sql
-- Inventario de los componentes que bos gestiona directamente
CREATE TABLE IF NOT EXISTS bos.vul_infra_component (
    component_id    UUID         PRIMARY KEY DEFAULT uuidv7(),
    name            TEXT         NOT NULL,              -- "ubuntu", "kubernetes", "postgresql", "vault"
    component_type  TEXT         NOT NULL               -- OS/K8S/DATABASE/SECRET_STORE/PROXY/SIEM
        CHECK (component_type IN ('OS','K8S','DATABASE','SECRET_STORE','PROXY','SIEM','RUNTIME','LIB')),
    version         TEXT         NOT NULL,              -- versión desplegada actual
    server_ref      TEXT,                               -- referencia a la ficha de servidor (S00-S15)
    is_active       BOOLEAN      NOT NULL DEFAULT true,
    last_scanned    TIMESTAMPTZ,                        -- última ejecución del scanner
    scan_tool       TEXT,                               -- trivy/grype/apt-check/kube-bench
    ctx_id          TEXT         NOT NULL,
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_vul_infra UNIQUE (name, version, server_ref)
);
```

### 3.3 Tabla 3 — Remediaciones de infraestructura

```sql
-- Registro de acciones de remediación tomadas por bos
CREATE TABLE IF NOT EXISTS bos.vul_infra_remediation (
    remediation_id  UUID         PRIMARY KEY DEFAULT uuidv7(),
    cve_id          TEXT         NOT NULL REFERENCES bos.vul_cve_registry(cve_id),
    component_id    UUID         NOT NULL REFERENCES bos.vul_infra_component(component_id),
    action_taken    TEXT         NOT NULL
        CHECK (action_taken IN ('PATCHED','CONFIG_CHANGE','NETWORK_ISOLATE','ROLLBACK','ACCEPTED','WORKAROUND')),
    action_desc     TEXT         NOT NULL,
    executed_by     TEXT         NOT NULL,              -- 'bos.watchdog'/'bos.repair'/'MANUAL'
    executed_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    verified_at     TIMESTAMPTZ,                        -- cuándo se verificó que funcionó
    verified_by     TEXT,
    ctx_id          TEXT         NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);
```

---

## 4. Protocolo de colaboración bos → bAuth

Cuando bos detecta una CVE que afecta al stack de autenticación de bAuth, notifica via
JSON-RPC sobre el Unix socket `/run/bos/bauth.sock`:

### 4.1 Método JSON-RPC (bos invoca → bAuth responde)

```json
// bos → bAuth: notificación de CVE
{
  "jsonrpc": "2.0",
  "method": "bauth.vulnerability.notify",
  "params": {
    "cve_id": "CVE-2026-12345",
    "component_name": "jsonwebtoken",
    "component_version": "0.11.0",
    "severity": "HIGH",
    "cvss_score": 7.5,
    "description": "JWT verification bypass via algorithm confusion",
    "sla_deadline": "2026-08-08T00:00:00Z",
    "ctx_id": "/dist/sbos/emp/platform/suc/core/user/bos/pos/observer"
  },
  "id": "bos-vul-20260801-001"
}

// bAuth → bos: confirmación de evaluación de impacto
{
  "jsonrpc": "2.0",
  "result": {
    "impact_id": "uuid-...",
    "affected_methods": ["JWT", "OIDC", "TOKEN_EXCHANGE"],
    "action_taken": "DISABLED_METHOD",
    "disabled_methods": ["TOKEN_EXCHANGE"],
    "message": "Método TOKEN_EXCHANGE desactivado preventivamente. OIDC y JWT bajo monitoreo reforzado."
  },
  "id": "bos-vul-20260801-001"
}
```

### 4.2 Flujo completo del ciclo de vida de una CVE

```
Fase 1 — DESCUBRIMIENTO (bos)
  cargo-audit / trivy escanea dependencias
  → bos.observer ingesta resultado
  → INSERT bos.vul_cve_registry (status='OPEN')
  → INSERT bos.vul_infra_component (si es infraestructura)

Fase 2 — NOTIFICACIÓN (bos → bAuth si affected_layer='AUTH_STACK'/'SHARED')
  → JSON-RPC bauth.vulnerability.notify(...)
  → bAuth evalúa impacto en 18 métodos
  → INSERT bauth.vul_auth_impact (en schema bauth)
  → bAuth responde con acción tomada

Fase 3 — CONTENCIÓN (bAuth, si severity=CRITICAL/HIGH)
  → bAuth deshabilita método auth comprometido
  → disabled_methods[] actualizado
  → aud_event_log registra desactivación (trazabilidad WORM)
  → bos recibe confirmación, actualiza vul_cve_registry.status='IN_PROGRESS'

Fase 4 — REMEDIACIÓN (bos aplica el parche)
  → bos.repair actualiza el componente (new version)
  → INSERT bos.vul_infra_remediation (action_taken='PATCHED')
  → bos notifica a bAuth que el componente está parcheado
  → bAuth reactiva el método auth
  → bos.vul_cve_registry.status='PATCHED'

Fase 5 — VERIFICACIÓN (bos)
  → cargo-audit / trivy re-escanea
  → Sin CVE → vul_infra_remediation.verified_at = now()
  → bos.vul_cve_registry.status='PATCHED' (confirmado)

Fase 6 — CIERRE
  → Si reincidencia → vincular a inc_incident en bAuth (A.5.27)
  → Si nuevo patrón → registrar en bauth.thi_indicator (A.5.7)
```

---

## 5. SLAs de remediación — Estándar industria

| Severidad | CVSS v3.1 | SLA máximo | Acción automática bos | Acción automática bAuth |
|-----------|-----------|-----------|----------------------|------------------------|
| **CRITICAL** | 9.0–10.0 | **24 horas** | Rollback de componente o aislamiento de red | Deshabilitar método auth afectado inmediatamente |
| **HIGH** | 7.0–8.9 | **7 días** | Programar parche urgente + alerta HITL | Step-up forzado en método afectado |
| **MEDIUM** | 4.0–6.9 | **30 días** | Programar en próximo ciclo de mantenimiento | Monitoreo reforzado en aud_event_log |
| **LOW** | 0.1–3.9 | **90 días** | Registrar + planificar | Sin acción automática |
| **INFO** | 0.0 | Sin SLA | Documentar para referencia | Sin acción automática |

---

## 6. Integración con módulos bos existentes

| Módulo bos actual | Extensión para vulnerabilidades |
|------------------|--------------------------------|
| `internal/observer/` | Agregar ciclo de scan periódico (cargo-audit, trivy, apt-check) → INSERT vul_cve_registry |
| `internal/reconcile/` | Comparar versiones desplegadas vs versiones seguras conocidas → detectar drift |
| `internal/watchdog/` | SLA vencido sin remediación → alerta CRITICAL → escalar a HITL |
| `internal/repair/` | Ejecutar parches programados → INSERT vul_infra_remediation |
| `internal/health/` | CVEs CRITICAL/HIGH pendientes → health check degradado/unhealthy |
| `internal/bauth/` | Cliente JSON-RPC ya existe → agregar método `vulnerability.notify` |

---

## 7. Herramientas de escaneo recomendadas

| Herramienta | Qué escanea | Integración con bos |
|-------------|-------------|---------------------|
| `cargo-audit` | Rust crates de bAuth y otros daemons Rust | `bos.observer` ejecuta periódicamente; salida JSON → vul_cve_registry |
| `trivy` | Imágenes K8s, OS packages, configs | `bos.observer` en cada deploy + scan semanal |
| `kube-bench` | Configuración de seguridad de Kubernetes | `bos.observer` tras cada cambio de K8s |
| `apt-check` / `unattended-upgrades` | Paquetes del OS Ubuntu/Debian | Integrado en systemd — bos lee el resultado |
| CISA KEV feed | Known Exploited Vulnerabilities | `bos.observer` consulta feed diario (JSON sobre HTTPS → procesado por bos) |

---

## 8. Referencia de contratos a formalizar

El método `bauth.vulnerability.notify` debe formalizarse en el contrato bilateral:

**Archivo:** `/opt/skull/orquestador/proyectos/SBOS/context/contracts/BOS-BAUTH-CONTRATOS.md`

Abrir contrato `C-BOS-NNN` en sección "BOS → bAuth" con:
- Método JSON-RPC: `bauth.vulnerability.notify`
- Parámetros: `cve_id`, `component_name`, `component_version`, `severity`, `cvss_score`, `sla_deadline`, `ctx_id`
- Respuesta esperada: `impact_id`, `affected_methods`, `action_taken`, `disabled_methods`
- SLA de respuesta de bAuth: máximo 5 minutos para CRITICAL, 1 hora para HIGH

---

## 9. Estado del gap en bos

| Ítem | Estado |
|------|--------|
| `bos.vul_cve_registry` | PENDIENTE — diseñada en este anexo, no implementada en DDL |
| `bos.vul_infra_component` | PENDIENTE — diseñada en este anexo, no implementada en DDL |
| `bos.vul_infra_remediation` | PENDIENTE — diseñada en este anexo, no implementada en DDL |
| Ciclo scan en `observer/` | PENDIENTE — requiere implementación Go |
| Método `bauth.vulnerability.notify` | PENDIENTE — requiere contrato bilateral + implementación |
| Integración `watchdog/` con SLA vencido | PENDIENTE |

**Prioridad:** P2 (MEDIO) — alineada con T-BACKLOG-009 en bAuth.  
**Coordinación:** Este gap debe resolverse en el mismo sprint que T-BACKLOG-009 — ambos extremos del contrato deben desplegarse juntos.

---

*Generado durante revisión A.71 ISO 27001:2022 — sesión 2026-08-01.*  
*Fuentes: AWS Shared Responsibility Model · ISO 27001:2022 A.8.8 · NIST SP 800-40 Rev.4 · Open Security Architecture SP-038 · Konfirmity 2026 · Wiz Academy CVE.*
