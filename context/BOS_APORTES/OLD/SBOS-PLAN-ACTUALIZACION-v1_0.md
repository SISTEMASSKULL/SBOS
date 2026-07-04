# SBOS — Plan de Acción: Actualización Arquitectónica del Sistema de Autenticación
## SKULL · SBOS — Sovereign Business Operating System
## Versión 1.0 · Abril 2026 · CONFIDENCIAL

---

| Campo | Valor |
|---|---|
| **Documento** | SBOS-PLAN-ACTUALIZACION-v1_0 |
| **Basado en** | sbos-auth-templates-audit-v1.0 (Informe Técnico Arquitectónico) |
| **Custodio** | Principal Systems Architect — SKULL |
| **Fecha** | 2026-04-16 |
| **Estado** | LISTO PARA REVISIÓN ARB |
| **Prioridad** | CRÍTICA — Bloquea LogicalDomainEvaluator y 6 integraciones v1.0 |

---

## Tabla de Contenidos

1. [Resumen del Problema](#1-resumen-del-problema)
2. [Diagnóstico: Brechas Identificadas](#2-diagnóstico-brechas-identificadas)
3. [Principios Rectores del Plan](#3-principios-rectores-del-plan)
4. [Fases del Plan de Acción](#4-fases-del-plan-de-acción)
5. [Fase 0 — Refactorización Base (Pre-v0.9)](#5-fase-0--refactorización-base-pre-v09)
6. [Fase 1 — Dominios Faltantes (v0.9 Beta)](#6-fase-1--dominios-faltantes-v09-beta)
7. [Fase 2 — Federación y Dominio Organizacional (v0.9 GA)](#7-fase-2--federación-y-dominio-organizacional-v09-ga)
8. [Fase 3 — Evaluadores de Dominio e Integraciones (v1.0)](#8-fase-3--evaluadores-de-dominio-e-integraciones-v10)
9. [Fase 4 — Extensiones Normativas y Passkeys (v1.5)](#9-fase-4--extensiones-normativas-y-passkeys-v15)
10. [Matriz de Archivos a Modificar](#10-matriz-de-archivos-a-modificar)
11. [Especificaciones Técnicas por Archivo](#11-especificaciones-técnicas-por-archivo)
12. [Decision Log Extendido](#12-decision-log-extendido)
13. [Criterios de Aceptación por Fase](#13-criterios-de-aceptación-por-fase)
14. [Dependencias Críticas y Orden de Ejecución](#14-dependencias-críticas-y-orden-de-ejecución)
15. [Estimación de Esfuerzo](#15-estimación-de-esfuerzo)

---

## 1. Resumen del Problema

El sistema de autenticación del SBOS tiene una arquitectura conceptualmente sólida en sus **dominios Lógico y Físico**, pero presenta **brechas críticas** que bloquean el desarrollo del `LogicalDomainEvaluator` (REQ-3 de SBOS-bAuth-Evaluacion) y la integración de 6 aplicaciones del ecosistema en v1.0.

### Estado actual vs. estado objetivo

```
ESTADO ACTUAL                          ESTADO OBJETIVO
─────────────────────────────────      ────────────────────────────────────
✅ Dominio Lógico (parcial)            ✅ Dominio Lógico (completo)
✅ Dominio Físico (completo)           ✅ Dominio Físico (sin cambios)
⚠️  Dominio Financiero (sin máscara)   ✅ Dominio Financiero (con FinancialDomainMask)
❌ Dominio de Red (ausente)            ✅ Dominio de Red (network_domain)
❌ Dominio de Aplicación (ausente)     ✅ Dominio de Aplicación (application_domain)
⚠️  Dominio Biométrico (mezclado)      ✅ Dominio Biométrico (separado política/datos)
❌ Dominio Federado (ausente)          ✅ Dominio Federado (federation_domain)
⚠️  Dominio Organizacional (disperso)  ✅ Dominio Organizacional (unificado)
⚠️  Dominio Normativo (parcial)        ✅ Dominio Normativo (activación automática)

JSON obsoletos con 2 fuentes de       JSON reducidos a catálogos de
verdad para las mismas configs         capacidades (única fuente: RolTemplate)

bos_bitmask 64-bit legacy             BitmaskBundle: Physical + Logical + Financial
```

---

## 2. Diagnóstico: Brechas Identificadas

### 2.1 Dominios completamente ausentes (CRÍTICO)

**Dominio de Red (IEEE 802.1X)** — Actualmente subsumido incorrectamente dentro de `logical_access.geospatial_control`. Mezcla dos conceptos distintos: ubicación geográfica (desde dónde autentica) y segmentación de red (qué infraestructura usa post-autenticación). Sin este dominio, no es posible asignar dinámicamente VLANs desde el SAM-128.

**Dominio de Aplicación (OASIS XACML 3.0)** — Las aplicaciones solo existen como `hints` no estructurados en `zones.*.applications`. Sin este bloque formalizado, el `LogicalDomainEvaluator` no tiene contrato para resolver la cadena zona-de-negocio → aplicaciones → scopes OIDC. **Este es el bloqueante más crítico para v1.0.**

**Dominio Federado (NIST SP 800-63C-4)** — Los niveles FAL (Federation Assurance Level) no están declarados en el RolTemplate. Keycloak no puede aplicar controles distintos según el nivel de confianza requerido por el recurso.

### 2.2 Dominios incompletos o fragmentados

**Dominio Financiero** — El `RolTemplate.financial_transactions` es completo, pero el UserTemplate no tiene un bloque `financial_limits` para excepciones individuales aprobadas. El `FinancialDomainMask` (SAM-128 Q3) no está materializado como campo calculado en el template.

**Dominio Biométrico** — La política de enrolamiento (qué se acepta, FMR, algoritmo) y los datos individuales (hashes PBKDF2-SHA256) conviven en `physical_credentials.biometric_templates`, violando la separación exigida por NIST SP 800-63B-4 §5.2.3 y RGPD Art. 9.

**Dominio Organizacional** — Los controles están fragmentados en tres campos distintos del RolTemplate (`compliance_audit`, `group_management`, `conflict_management`) sin unidad conceptual. No existe modelado del ciclo de vida completo del actor (onboarding → just-in-time → access review → offboarding).

**Dominio Normativo** — Declara PCI-DSS y GDPR pero no tiene mecanismo de activación automática por jurisdicción desde el seed file del tenant. Los bits `GOV_NORMATIVE_AR` y `GOV_NORMATIVE_MX` del SAM-128 Q4 no están asignados.

### 2.3 Archivos JSON obsoletos (URGENTE)

`Authentication_Framework.json` y `Policies_Authentication_Framework.json` contienen configuraciones de rol que violan el principio de **única fuente de verdad** del RolTemplate:

- Mezclan `requiredMethods` por rol con configuraciones de infraestructura (TLS, pools, timeouts, ML).
- Referencian `bos_bitmask` 64-bit (legacy) en lugar del `BitmaskBundle` (Physical + Logical + Financial).
- No contemplan los 9 dominios de autenticación del marco de referencia.

Mientras estos archivos permanezcan con su estructura actual, existe riesgo de que un administrador actualice configuraciones en los JSON creyendo que afecta al sistema, cuando el sistema real usa el RolTemplate.

---

## 3. Principios Rectores del Plan

Los siguientes principios deben guiar todas las decisiones de implementación:

1. **Única fuente de verdad:** El RolTemplate es el único contrato de autenticación. Los JSON reducidos son catálogos de referencia, no fuentes de configuración activa.

2. **Separación de concerns:** Infraestructura → `bauth.toml`. Políticas de rol → RolTemplate. Datos individuales → UserTemplate.

3. **Compatibilidad hacia atrás:** Toda migración es aditiva en v0.9 (nuevo bloque + bloque legacy). El bloque legacy se elimina en v1.0 tras período de transición documentado.

4. **Sin breaking changes en JWT:** El JWT mantiene los claims legacy (`bos_bitmask`) hasta v1.0. A partir de v0.9 Beta se emiten ambos: legacy + nuevos (`bos_physical_mask`, `bos_logical_mask`, `bos_financial_mask`).

5. **AND NOT nunca NAND:** Toda revocación de bits usa `&^` (Go). Toda herencia jerárquica usa `AND NOT`. Toda agregación de roles usa `OR`. La Conflict Matrix implementa SoD, nunca XOR.

6. **RGPD primero:** Los datos biométricos (categoría especial Art. 9) deben separarse de la política antes de cualquier otro cambio en el UserTemplate.

---

## 4. Fases del Plan de Acción

```
Pre-v0.9           v0.9 Beta          v0.9 GA            v1.0               v1.5
(2-3 días)         (1 semana)         (1 semana)          (3-4 semanas)      (2 semanas)
    │                  │                   │                   │                  │
    ▼                  ▼                   ▼                   ▼                  ▼
FASE 0             FASE 1             FASE 2             FASE 3             FASE 4
Refactorizar       Dominios           Federación         Evaluadores        Normativo
JSON + Schema      Faltantes          y Org Domain       e Integraciones    AR/MX + Passkeys
    │                  │                   │                   │                  │
    │         network_domain    federation_domain    LogicalDomain           SAM-128 Q4
    │         application_domain organizacional       Evaluator            GOV_NORMATIVE_AR
    │         financial_limits   jurisdicción        FinancialDomain       GOV_NORMATIVE_MX
    │         biometric_domain   automática           Evaluator            W3C VC (prep)
    ▼                  ▼                   ▼                   ▼                  ▼
JSON Schema        bAuth sync         JWT FAL claim      6 apps              Passkeys AAL2
actualizado        network_domain     activo             integradas           NIST 800-63B-4
```

---

## 5. Fase 0 — Refactorización Base (Pre-v0.9)

**Duración estimada:** 2-3 días  
**Prioridad:** CRÍTICA — Bloquea todas las fases siguientes  
**Criterio de inicio:** Aprobación ARB del plan

### 5.1 Refactorizar Authentication_Framework.json

**Objetivo:** Reducir de 35 grupos a 5 secciones. Eliminar todo lo que es configuración de infraestructura o política de rol.

**Secciones a mantener:**

| Sección | Contenido | Justificación |
|---|---|---|
| `metadata` | version, environment, classification, schemaVersion | Metadato del framework |
| `cryptographic_catalog` | Algoritmos PQC soportados, TLS versions, cipher suites, key sizes mínimos | Catálogo de referencia — no configuración activa |
| `loa_definitions` | Definición normativa de LoA 1-4 con sus características (NIST SP 800-63B-4) | Glosario de LoAs del realm |
| `authentication_methods_catalog` | Los 15 métodos canónicos con su LoA asignado y protocolo base | Biblioteca de referencia |
| `global_minimums` | LoA mínima del realm, TTL máximo absoluto de sesión | 'Piso' global no configurable por rol |

**Contenido a migrar:**

```
Grupos 1-35 del JSON actual → destino:
  authenticationCore.sanctumEnhanced (requiredMethods por rol)  → RolTemplate
  quantumResistantSecurity (configuración activa de algoritmos) → bauth.toml [security.post_quantum]
  advancedBiometrics (thresholds, liveness)                     → RolTemplate.physical_access
  behavioralAuthentication (ML models, sampling rates)          → bauth.toml [ai_security]
  contextualAuthentication (geospatial, location)               → RolTemplate.logical_access
  webSocketAccessControl (endpoints, methods)                   → RolTemplate.zones / application_domain
  aiSecurityEngine (neural architecture, training)              → bauth.toml [ai_security]
  advancedSessionManagement (JWT properties, lifecycle)         → bauth.toml [session]
  dataProtection (data classification, DLP)                     → runbooks 032-OPERATIONS
  accessControl (policies, decision engine)                     → RolTemplate.tryton_privileges
  auditingSystem (log levels, retention)                        → bauth.toml [audit]
  incidentResponse (automated response)                         → runbooks 032-OPERATIONS
```

### 5.2 Refactorizar Policies_Authentication_Framework.json

**Objetivo:** Reducir a 3 secciones. Todo lo específico de rol migra al RolTemplate.

**Secciones a mantener:**

| Sección | Contenido |
|---|---|
| `global_auth_policy` | LoA mínima, TTL sesión máximo, política contraseñas base del realm |
| `realm_session_policy` | maxSessionCount global, concurrent_sessions_default |
| `compliance_floor` | Estándares mínimos que todo rol debe cumplir (no configurable por rol) |

**Contenido a migrar:**

```
modern_authentication_policies.webauthn_fido2
  (authenticator_policies, requirements específicos por rol)    → RolTemplate.physical_access.biometric_enrollment_policy

quantum_resistant_authentication.post_quantum_cryptography
  (primary_algorithm CRYSTALS-Kyber, fallback NTRU)            → bauth.toml [security.post_quantum]

physical_logical_authentication.physical_access.entry_points
  (required_factors=3 para high_security_areas)                 → RolTemplate.physical_access.requiredMethods.critical_areas

compliance_regulation (Sección 14 completa)
  (GDPR breach notification, incident management)               → runbooks en 032-OPERATIONS

adaptive_learning.system_learning (Grupos 10, 11)
  (ML model config, hyperparameters, training)                  → bauth.toml [ai_security]

continuous_auth.contextual_auth
  (device_health checks ROOTED, MALWARE, OS_VERSION)           → bAuth SPI SkbosGuardAuthenticator
```

### 5.3 Actualizar JSON Schema (REQ-2 de SBOS-bAuth-Evaluacion)

Actualizar `roltemplate_schema.json` para validar los nuevos bloques a agregar en Fase 1 y 2. Las validaciones deben ser aditivas y no romper templates v5.0 existentes.

**Nuevas reglas de validación a agregar:**

```json
{
  "properties": {
    "network_domain": {
      "$ref": "#/definitions/network_domain",
      "description": "IEEE 802.1X network segmentation control"
    },
    "application_domain": {
      "$ref": "#/definitions/application_domain",
      "description": "OASIS XACML 3.0 zone-to-application mapping"
    },
    "federation_domain": {
      "$ref": "#/definitions/federation_domain",
      "description": "NIST SP 800-63C-4 FAL declarations"
    }
  }
}
```

**Regla adicional para NIST SP 800-63B-4:**
- `email_otp` como único segundo factor → rechazar con error `EMAIL_OTP_SOLE_FACTOR_PROHIBITED`
- `sms_otp` en flujos con LoA ≥ 2 → advertencia `SMS_OTP_HIGH_RISK_WARNING`
- `passkey` → válido como AAL2 según NIST SP 800-63B-4 (julio 2025)

### 5.4 Crear bauth.toml con secciones migradas

Crear `bauth.toml` completo incorporando el contenido migrado desde los JSON:

```toml
# Secciones a agregar desde los JSON refactorizados:

[security.post_quantum]
primary_algorithm = "CRYSTALS-Kyber-1024"
fallback_algorithm = "NTRU-HPS-4096-821"
hybrid_mode_enabled = true
classical_fallback = "ECDH-P521"

[ai_security.anomaly_detection]
model_type = "ensemble"
components = ["random_forest", "neural_network", "gradient_boosting"]
confidence_threshold = 0.90
false_positive_rate = 0.01
retraining_frequency = "continuous"

[ai_security.behavioral]
keyboard_dynamics_enabled = true
mouse_dynamics_enabled = true
min_samples = 1000
update_frequency = "continuous"

[biometric]
hash_algorithm = "PBKDF2-SHA256"
iterations = 310000
fmr_threshold_loa2 = "1:10000"
fmr_threshold_loa3 = "1:100000"
liveness_required = true
```

### 5.5 Crear migrations/003_add_domains.sql

```sql
-- Agregar índices GIN para los nuevos bloques de dominio
CREATE INDEX idx_brt_network_domain
  ON bos_rol_template USING GIN((template->'network_domain') jsonb_path_ops)
  WHERE template ? 'network_domain';

CREATE INDEX idx_brt_application_domain
  ON bos_rol_template USING GIN((template->'application_domain') jsonb_path_ops)
  WHERE template ? 'application_domain';

CREATE INDEX idx_brt_federation_domain
  ON bos_rol_template USING GIN((template->'federation_domain') jsonb_path_ops)
  WHERE template ? 'federation_domain';

-- Columna para FinancialDomainMask en el SAM-128
ALTER TABLE bos_rol_template
  ADD COLUMN IF NOT EXISTS sam128_financial BIGINT;

-- Tabla de mapeo zona → aplicaciones (respaldo de zone_application_map.yaml)
CREATE TABLE IF NOT EXISTS bos_zone_application_map (
    zone_id        TEXT NOT NULL,
    app_id         TEXT NOT NULL,
    app_scopes     TEXT[],
    client_id      TEXT,
    modules        TEXT[],
    active         BOOLEAN DEFAULT true,
    last_updated   TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (zone_id, app_id)
);

CREATE INDEX idx_zam_zone ON bos_zone_application_map(zone_id);
```

---

## 6. Fase 1 — Dominios Faltantes (v0.9 Beta)

**Duración estimada:** 1 semana  
**Prerequisito:** Fase 0 completada y aprobada  
**Criterio de éxito:** bAuth sincroniza `network_domain` → bhnexus VLAN assignment. `LogicalDomainEvaluator` responde usando `application_domain`.

### 6.1 Agregar network_domain al RolTemplate

**Bloque JSONB a incorporar en SBOS-ROLTEMPLATE-v5_1.md:**

```json
"network_domain": {
  "ieee8021x": {
    "required": true,
    "eap_method": "EAP-TLS",
    "certificate_required": true,
    "radius_server_group": "RADIUS-PRIMARY"
  },
  "allowed_vlans": ["VLAN-VENTAS", "VLAN-INTERNET-FILTERED"],
  "denied_vlans": ["VLAN-SERVIDORES", "VLAN-DIRECCION"],
  "dynamic_vlan_assignment": {
    "enabled": true,
    "attribute": "Tunnel-Private-Group-ID",
    "default_vlan": "VLAN-QUARANTINE"
  },
  "blocked_protocols": ["P2P", "TOR", "SSH_REVERSE", "TELNET"],
  "bandwidth_profile": "HIGH_PERFORMANCE",
  "bandwidth_limits": {
    "download_mbps": 100,
    "upload_mbps": 50,
    "burst_multiplier": 1.5
  },
  "monitoring_level": "METADATA_ONLY",
  "sam128_bits": {
    "NETWORK_EXTERNAL": true,
    "VPN_ACCESS": false,
    "VLAN_VENTAS_ACCESS": true
  }
}
```

**Cambio en bAuth sincronización:** El `KeycloakSynchronizer.sync_role()` debe leer `network_domain.allowed_vlans` y escribir el User Attribute `bos_vlan_assignment` en KC. El SPI `SkbosGeoContextAuthenticator` debe extenderse para verificar la VLAN activa del cliente.

**Cambio en bhnexus:** El `Hardware Bridge` debe leer el claim `bos_vlan_assignment` del JWT y enviar el atributo RADIUS `Tunnel-Private-Group-ID` al switch durante el proceso de autenticación 802.1X.

### 6.2 Agregar application_domain al RolTemplate

**Bloque JSONB a incorporar:**

```json
"application_domain": {
  "zone_mappings": [
    {
      "zone_id": "zone_logical/ventas",
      "verbs": ["READ", "WRITE", "APPROVE"],
      "required_loa": 2,
      "applications": [
        {
          "app": "tryton",
          "scope": "sale.sale:read,write",
          "client_id": "tryton-sbos"
        },
        {
          "app": "saleor",
          "scope": "orders:read,write",
          "client_id": "saleor-storefront"
        },
        {
          "app": "espocrm",
          "scope": "accounts:read,write",
          "client_id": "espocrm-api"
        }
      ]
    },
    {
      "zone_id": "zone_logical/contabilidad",
      "verbs": ["READ", "WRITE", "APPROVE", "AUDIT"],
      "required_loa": 2,
      "applications": [
        {"app": "tryton", "scope": "account:read,write", "client_id": "tryton-sbos"},
        {"app": "superset", "scope": "dashboard:read", "client_id": "superset-sbos"},
        {"app": "paperless", "scope": "document:read", "client_id": "paperless-sbos"}
      ]
    }
  ],
  "access_control_model": "ABAC",
  "evaluation_mode": "deny_override",
  "audit_level": "detailed"
}
```

**Crear zone_application_map.yaml** como fuente canónica de resolución para el `LogicalDomainEvaluator`:

```yaml
# /etc/bos/blibs/bauth/zone_application_map.yaml
# Fuente canónica: zona de negocio → aplicaciones del ecosistema SBOS
# Custodio: bAuth — Principal Systems Architect
# Actualizar con cada nueva integración de aplicación

zones:
  zone_logical/ventas:
    description: "Operaciones comerciales y gestión de clientes"
    applications:
      - app: tryton
        modules: [sale, sale.opportunity, party]
        client_id: tryton-sbos
      - app: saleor
        client_id: saleor-storefront
      - app: espocrm
        client_id: espocrm-api

  zone_logical/contabilidad:
    description: "Registros contables, facturación y pagos"
    applications:
      - app: tryton
        modules: [account, account_invoice, account_payment]
        client_id: tryton-sbos
      - app: superset
        dashboards: [contabilidad_regional, facturacion_mensual]
        client_id: superset-sbos
      - app: paperless
        tags: [factura, comprobante, fiscal]
        client_id: paperless-sbos

  zone_logical/rrhh:
    description: "Gestión de personal, nómina y contratos"
    applications:
      - app: orangehrm
        client_id: orangehrm-sbos
      - app: tryton
        modules: [payroll, leave]
        client_id: tryton-sbos
      - app: paperless
        tags: [contrato, personal]
        client_id: paperless-sbos

  zone_logical/soporte:
    description: "Gestión de tickets y atención al cliente"
    applications:
      - app: zammad
        client_id: zammad-sbos

  zone_logical/reportes:
    description: "Business Intelligence y reportes"
    applications:
      - app: superset
        client_id: superset-sbos
      - app: tryton
        modules: [account_statement]
        client_id: tryton-sbos
```

### 6.3 Agregar financial_limits al UserTemplate

```json
"financial_limits": {
  "_note": "Overrides individuales del RolTemplate.financial_transactions. Todos requieren aprobación.",
  "limit_overrides": [
    {
      "override_id": "FO-2026-001",
      "type": "single_transaction_limit",
      "original_limit": 10000,
      "override_limit": 25000,
      "currency": "BOB",
      "reason": "Cierre contrato especial",
      "approved_by": "CFO",
      "approved_at": "2026-03-15T10:00:00Z",
      "valid_until": "2026-06-30T23:59:59Z",
      "single_use": false,
      "requires_dual_approval": true
    }
  ],
  "sod_exceptions": [],
  "last_reconciliation": null
}
```

### 6.4 Separar biometric_domain (RGPD compliance)

**En RolTemplate:** Renombrar `physical_access.biometric_enrollment_policy` → crear bloque `biometric_domain.policy` de primer nivel:

```json
"biometric_domain": {
  "policy": {
    "mode": "hybrid",
    "risk_level": "high",
    "liveness_required": true,
    "liveness_method": "passive",
    "fallback_method": "qr_dynamic",
    "max_failed_attempts": 3,
    "hash_algorithm": "PBKDF2-SHA256",
    "iterations": 310000,
    "fmr_threshold": "1:10000",
    "consent_required": true,
    "consent_mechanism": "electronic_signature"
  }
}
```

**En UserTemplate:** Mover `physical_credentials.biometric_templates` → `biometric_domain.enrolled_templates`:

```json
"biometric_domain": {
  "_gdpr_note": "Categoría especial RGPD Art. 9. Consentimiento explícito obligatorio.",
  "enrolled_templates": [
    {
      "id": "BIO-001",
      "biometric_type": "fingerprint",
      "finger": 1,
      "template_hash": "pbkdf2$sha256$310000$salt$hash_base64",
      "liveness_verified": true,
      "admin_verified": true,
      "consent_given": true,
      "consent_date": "2026-01-15T10:45:00Z",
      "enrolled_at": "2026-01-15T11:00:00Z",
      "revoked_at": null
    }
  ],
  "consent_record": {
    "given": true,
    "date": "2026-01-15T10:45:00Z",
    "version": "BIOMETRIC_CONSENT_v1.0",
    "withdrawal_date": null
  }
}
```

> **Nota de migración (compatibilidad hacia atrás):** Durante v0.9, el bloque `physical_credentials.biometric_templates` permanece activo pero marcado como `"_deprecated": "Migrar a biometric_domain.enrolled_templates en v1.0"`. La eliminación definitiva ocurre en la migración `004_remove_legacy_biometric.sql` en v1.0.

---

## 7. Fase 2 — Federación y Dominio Organizacional (v0.9 GA)

**Duración estimada:** 1 semana  
**Prerequisito:** Fase 1 completada  
**Criterio de éxito:** JWT incluye claim `bos_federation_level`. Seed file `jurisdiction: "BO"` activa `GOV_NORMATIVE_BO` automáticamente.

### 7.1 Agregar federation_domain al RolTemplate

**Bloque JSONB:**

```json
"federation_domain": {
  "fal_level": 2,
  "assertion_format": "JWT",
  "token_binding": {
    "enabled": true,
    "method": "DPoP",
    "dpop_required_for_fal3": true
  },
  "trusted_identity_providers": [
    {
      "issuer": "https://auth.empresa.com/realms/empresa",
      "protocol": "OIDC",
      "fal_level": 2,
      "pkce_required": true,
      "response_types": ["code"]
    }
  ],
  "cross_tenant_access": {
    "allowed": false,
    "requires_approval": true,
    "max_duration_hours": 8
  },
  "verifiable_credentials": {
    "enabled": false,
    "accepted_types": ["EmployeeCredential", "AccessCredential"],
    "trust_registry": "https://trust.sbos.internal/registry"
  }
}
```

**Cambio en KC sync:** Agregar el claim `bos_federation_level` al JWT según `fal_level` del RolTemplate.

**Cambio en JWT final:**

```json
{
  "bos_federation_level": 2,
  "bos_token_binding": "DPoP",
  "bos_fal_method": "OIDC-PKCE"
}
```

### 7.2 Unificar organizational_domain en RolTemplate

Crear bloque unificado `organizational_domain` que reemplaza los campos fragmentados:

```json
"organizational_domain": {
  "lifecycle": {
    "onboarding": {
      "automated": true,
      "provisioning_steps": [
        "identity_verification",
        "credential_setup",
        "biometric_enrollment",
        "compliance_training"
      ],
      "just_in_time_provisioning": {
        "enabled": false,
        "max_duration_hours": 24
      }
    },
    "access_review": {
      "frequency": "QUARTERLY",
      "automated_reminder": true,
      "reminder_days_before": 14,
      "auto_revoke_on_no_response": false,
      "sla_days": 14
    },
    "offboarding": {
      "checklist": [
        "revoke_all_sessions",
        "disable_physical_credentials",
        "archive_user_data",
        "notify_manager"
      ],
      "max_duration_hours": 4,
      "emergency_offboarding_minutes": 15
    }
  },
  "segregation_of_duties": {
    "incompatible_roles": [],
    "incompatible_functions": [],
    "conflict_validation": {
      "check_frequency": "REAL_TIME",
      "validation_scope": ["DIRECT_CONFLICTS", "INHERITED_CONFLICTS", "DELEGATION_CONFLICTS"]
    }
  }
}
```

**Los campos existentes** `compliance_audit`, `group_management` y `conflict_management` se mantienen en v0.9 GA (compatibilidad hacia atrás) y se marcan como deprecados con referencia a `organizational_domain`.

### 7.3 Activación automática jurisdiccional

**Actualizar `compliance_audit.regulatory_frameworks`:**

```json
"regulatory_frameworks": {
  "auto_activate_from_seed": true,
  "jurisdiction_triggers": {
    "BO": {
      "bits": ["GOV_NORMATIVE_BO"],
      "connectors": ["SIAT"],
      "log_retention_years": 10,
      "regulations": ["LEY_843", "LEY_PROTECCION_DATOS_BO"]
    },
    "AR": {
      "bits": ["GOV_NORMATIVE_AR"],
      "connectors": ["AFIP"],
      "log_retention_years": 10,
      "regulations": ["CODIGO_COMERCIAL_AR", "LEY_25506"]
    },
    "MX": {
      "bits": ["GOV_NORMATIVE_MX"],
      "connectors": ["SAT"],
      "log_retention_years": 5,
      "regulations": ["CFF_MX", "LFPDPPP"]
    }
  }
}
```

**Mecanismo de activación en bAuth (seed file → SAM-128):**

```go
// En PrivilegeEngine.calculate() — nuevo paso de activación jurisdiccional
func (e *PrivilegeEngine) applyJurisdiction(sam SAM128, tenant TenantConfig) SAM128 {
    switch tenant.Jurisdiction {
    case "BO":
        sam = sam.Grant(GOV_NORMATIVE_BO) // bit 110 Q4
    case "AR":
        // Usar JWT claim bos_governance.jurisdiction_codes hasta SAM-128 v1.5
        // sam = sam.Grant(GOV_NORMATIVE_AR) // bit 112 — pendiente v1.5
    case "MX":
        // sam = sam.Grant(GOV_NORMATIVE_MX) // bit 113 — pendiente v1.5
    }
    return sam
}
```

---

## 8. Fase 3 — Evaluadores de Dominio e Integraciones (v1.0)

**Duración estimada:** 3-4 semanas  
**Prerequisito:** Fases 0, 1 y 2 completadas  
**Criterio de éxito:** Los 9 dominios son evaluables en tiempo real vía Unix socket `/run/bos/bauth.sock`. 6 nuevas aplicaciones integradas.

### 8.1 Implementar LogicalDomainEvaluator

Implementar el componente que falta como endpoint REST en bAuth y consulta vía Unix socket:

```go
// Interfaz Go — LogicalDomainEvaluator
// STATUS: PENDIENTE IMPLEMENTACIÓN v1.0
type LogicalDomainEvaluator interface {
    // ¿Puede este usuario operar en esta zona con este verbo?
    CanAccessZone(userID, nodeID string, zone BusinessZone, verb UniversalVerb) (bool, string, error)

    // ¿Qué zonas activas tiene este usuario?
    GetActiveZones(userID, nodeID string) ([]BusinessZone, error)

    // ¿Qué aplicaciones implementan esta zona?
    GetZoneApplications(zone BusinessZone) ([]ApplicationEndpoint, error)
}

// Endpoint REST expuesto por bAuth:
// POST /api/v1/authorize/logical
// Body: {"user_id":"...", "node_id":"...", "zone":"zone_logical/ventas", "verb":"READ"}
// Response: {"granted":true, "applications":["tryton","saleor","espocrm"]}
```

### 8.2 Implementar FinancialDomainEvaluator

```go
// Interfaz Go — FinancialDomainEvaluator
type FinancialDomainEvaluator interface {
    // ¿Puede ejecutar esta operación financiera?
    CanExecuteTransaction(userID string, amount float64, currency string, operationType string) (bool, string, error)

    // ¿Quién debe aprobar esta transacción?
    GetRequiredApprovers(userID string, amount float64, operationType string) ([]string, error)

    // Verificar SoD para esta operación
    CheckSoDConstraints(userID string, operation string) (bool, []SoDViolation, error)
}

// Endpoint REST expuesto por bAuth:
// POST /api/v1/authorize/financial
// Body: {"user_id":"...", "amount":15000, "currency":"BOB", "operation":"create_payment"}
```

### 8.3 Integrar 6 aplicaciones nuevas

Implementar adaptadores `AppSynchronizer` para cada aplicación usando `application_domain` del RolTemplate:

| Aplicación | Protocolo de integración | Datos sincronizados desde RolTemplate |
|---|---|---|
| **Saleor** | OIDC + GraphQL API | `zones.zone_logical/ventas` → roles Saleor |
| **EspoCRM** | OIDC + REST API | `zones.zone_logical/ventas, clientes` → teams EspoCRM |
| **Zammad** | SAML 2.0 + REST API | `zones.zone_logical/soporte` → roles Zammad |
| **OrangeHRM** | OIDC + SCIM 2.0 | `zones.zone_logical/rrhh` → grupos OrangeHRM |
| **Superset** | OIDC + FAB roles | `zones.zone_logical/reportes, contabilidad` → roles Superset |
| **Paperless-ngx** | OIDC + REST API | Todas las zonas con READ → etiquetas Paperless |

### 8.4 Eliminar legacy bos_bitmask (migración JWT final)

En v1.0 el JWT deja de emitir `bos_bitmask` (legacy). Emite exclusivamente:

```json
{
  "bos_physical_mask":   "0x000000000003E627",
  "bos_logical_mask":    "0x0000010900030052",
  "bos_financial_mask":  "0x0000020900010000",
  "bos_governance_mask": "0x0000021200010052",
  "bos_federation_level": 2,
  "bos_sam128": "0x00000209000300520001001700010052"
}
```

**Migración del módulo trytond-auth-keycloak:** Actualizar `_login_keycloak()` para leer `bos_logical_mask` en lugar de `bos_bitmask`.

**Migración de banexus:** Actualizar `HasPermission()` para leer `bos_physical_mask` en lugar de `bos_bitmask`.

---

## 9. Fase 4 — Extensiones Normativas y Passkeys (v1.5)

**Duración estimada:** 2 semanas  
**Prerequisito:** Fase 3 completada  
**Criterio de éxito:** AR y MX con bits SAM-128 dedicados. Passkeys funcionando como AAL2 según NIST SP 800-63B-4.

### 9.1 SAM-128 Q4 — Bits AR y MX

Reorganizar Q4 del SAM-128 para incluir bits de jurisdicción dedicados. Esto requiere actualizar `bitmask_constants.go`:

```go
// Q4 Soberanía y Auditoría — bits 96-127
// ACTUALIZACIÓN v1.5: añadir bits AR y MX, reordenar CUSTOM

const (
    // Normativa por jurisdicción (bits 110-113)
    GOV_NORMATIVE_BO  = uint64(1 << 14) // en hi (bit 110 total) — Bolivia/SIAT
    GOV_NORMATIVE_PCI = uint64(1 << 15) // en hi (bit 111 total) — PCI-DSS
    GOV_NORMATIVE_AR  = uint64(1 << 16) // en hi (bit 112 total) — Argentina/AFIP ← NUEVO v1.5
    GOV_NORMATIVE_MX  = uint64(1 << 17) // en hi (bit 113 total) — México/SAT ← NUEVO v1.5

    // Identidad especial (bits 112-127) → desplazadas a 114-127
    GOV_IS_SUPERUSER   = uint64(1 << 18) // en hi (bit 114 total) ← desplazado desde 112
    GOV_CONTEXT_ACTIVE = uint64(1 << 19) // en hi (bit 115 total)
    // ...
)
```

**Migración de datos:** Script `migrations/005_sam128_v15_q4_reorg.sql` para recalcular `sam128_hi` en todos los RolTemplates activos.

### 9.2 Passkeys como AAL2 (NIST SP 800-63B-4)

Actualizar `Authentication_Framework.json` (sección `authentication_methods_catalog`):

```json
{
  "method": "passkey",
  "loa": 2,
  "nist_status": "AAL2_VALID",
  "standard_ref": "NIST SP 800-63B-4 §5.1.8",
  "notes": "Syncable authenticators válidos como AAL2 desde julio 2025. KC 26.4+ requerido."
}
```

Actualizar los RolTemplates que tienen `passkey` en `availableMethods` para permitirlo explícitamente en `requiredMethods.standard_login` como alternativa a TOTP.

### 9.3 Preparación W3C Verifiable Credentials

Activar `federation_domain.verifiable_credentials.enabled = true` en entorno staging para pruebas. Registrar trust registry interno en `https://trust.sbos.internal/registry`.

---

## 10. Matriz de Archivos a Modificar

| Archivo | Tipo de cambio | Fase | Prioridad | Compatibilidad hacia atrás |
|---|---|---|---|---|
| `Authentication_Framework.json` | REDUCIR (35 grupos → 5 secciones) | 0 | CRÍTICO | ⚠️ Migrar contenido a bauth.toml y RolTemplate ANTES de reducir |
| `Policies_Authentication_Framework.json` | REDUCIR (múltiples secciones → 3) | 0 | CRÍTICO | ⚠️ Mismo patrón |
| `SBOS-ROLTEMPLATE-v5_1.md` | CREAR (nuevo documento) | 0-2 | CRÍTICO | ✅ Aditivo — v5.0 sigue válido |
| `SBOS-USERTEMPLATE-v5_1.md` | CREAR (nuevo documento) | 0-1 | CRÍTICO | ✅ Aditivo — v5.0 sigue válido |
| `bauth.toml` (nuevo) | CREAR | 0 | ALTO | N/A |
| `zone_application_map.yaml` (nuevo) | CREAR | 1 | ALTO | N/A |
| `migrations/003_add_domains.sql` | CREAR | 0 | ALTO | ✅ Solo ADD COLUMN e índices |
| `migrations/004_remove_legacy_biometric.sql` | CREAR | 3 | MEDIO | ⚠️ Requiere migración de datos biométricos completada |
| `migrations/005_sam128_v15_q4_reorg.sql` | CREAR | 4 | BAJO | ⚠️ Requiere recalcular SAM-128 hi en todos los roles |
| `SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md` | ACTUALIZAR | 1-3 | ALTO | ✅ Versión nueva |
| `SBOS-008-ROLFRAMEWORK-v2_0.md` (actualizar) | ACTUALIZAR §8 y §11 | 1 | ALTO | ✅ Versión nueva |
| `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md` | ACTUALIZAR (Q4 reorg) | 4 | BAJO | ✅ Versión nueva |
| `SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md` | ACTUALIZAR §1.10 tabla | 2 | MEDIO | ✅ Versión nueva |
| `bitmask_constants.go` | ACTUALIZAR (añadir AR/MX) | 4 | BAJO | ✅ Solo nuevas constantes |
| `roltemplate_schema.json` (JSON Schema) | ACTUALIZAR | 0 | CRÍTICO | ✅ Aditivo — no rompe v5.0 |

---

## 11. Especificaciones Técnicas por Archivo

### 11.1 SBOS-ROLTEMPLATE-v5_1.md

**Bloques nuevos a agregar (respecto a v5.0):**

- `network_domain` — Bloque de primer nivel (después de `physical_access`)
- `application_domain` — Bloque de primer nivel (después de `zones`)
- `federation_domain` — Bloque de primer nivel (después de `financial_transactions`)
- `biometric_domain` — Bloque de primer nivel que reemplaza `physical_access.biometric_enrollment_policy`
- `organizational_domain` — Bloque de primer nivel que unifica `compliance_audit`, `group_management`, `conflict_management`

**Cambios en bloques existentes:**

- `compliance_audit.regulatory_frameworks` → agregar `auto_activate_from_seed` y `jurisdiction_triggers`
- `sam128` → agregar campo `financial_domain_mask_hex`
- `physical_access.biometric_enrollment_policy` → marcar como `_deprecated`, referencia a `biometric_domain.policy`

### 11.2 SBOS-USERTEMPLATE-v5_1.md

**Bloques nuevos a agregar (respecto a v5.0):**

- `financial_limits` — Bloque de primer nivel para overrides individuales de límites financieros
- `biometric_domain` — Bloque de primer nivel (separado de `physical_credentials`)
- `federation_context` — Bloque de primer nivel con contexto federado del usuario específico

**Cambios en bloques existentes:**

- `physical_credentials.biometric_templates` → marcar como `_deprecated`, datos migrados a `biometric_domain.enrolled_templates`

### 11.3 Authentication_Framework.json (versión reducida)

**Estructura objetivo:**

```json
{
  "authenticationFramework": {
    "metadata": { ... },
    "cryptographic_catalog": {
      "post_quantum": { ... },
      "symmetric": { ... },
      "asymmetric": { ... },
      "tls_versions": [ ... ]
    },
    "loa_definitions": {
      "loa1": { "description": "...", "methods": [...], "standard_ref": "NIST 800-63B-4 AAL1" },
      "loa2": { "description": "...", "methods": [...], "standard_ref": "NIST 800-63B-4 AAL2" },
      "loa3": { "description": "...", "methods": [...], "standard_ref": "NIST 800-63B-4 AAL3" },
      "loa4": { "description": "...", "methods": [...], "standard_ref": "SBOS extension" }
    },
    "authentication_methods_catalog": {
      "methods": [ /* Los 15 métodos canónicos con su LoA y protocolo */ ]
    },
    "global_minimums": {
      "min_loa_realm": 1,
      "max_session_ttl_seconds": 86400,
      "password_min_length": 12,
      "mfa_required_above_loa": 1
    }
  }
}
```

### 11.4 Policies_Authentication_Framework.json (versión reducida)

**Estructura objetivo:**

```json
{
  "PoliciesAuthenticationFramework": {
    "global_auth_policy": {
      "min_loa": 1,
      "max_concurrent_sessions": 3,
      "session_ttl_max_seconds": 28800,
      "mfa_grace_period_seconds": 0
    },
    "realm_session_policy": {
      "force_logout_on_idle_seconds": 900,
      "concurrent_sessions_default": false,
      "token_refresh_strategy": "sliding"
    },
    "compliance_floor": {
      "require_mfa_for_financial": true,
      "require_audit_log": true,
      "min_password_complexity_score": 80,
      "prohibited_methods_as_sole_factor": ["email_otp", "sms_otp"]
    }
  }
}
```

---

## 12. Decision Log Extendido

Las siguientes decisiones complementan las A1–G5 del documento `SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1_0.md`.

| # | Pregunta | Decisión | Razonamiento | Impacto | Estado |
|---|---|---|---|---|---|
| **H1** | ¿`network_domain` va en RolTemplate o en bauth.toml? | En el **RolTemplate**. bauth.toml recibe la infraestructura RADIUS. El RolTemplate declara qué VLANs puede usar el rol. | Separación de concerns: infraestructura vs. política. Diferentes roles pueden tener diferentes VLANs sin tocar infraestructura. | ALTO | ✅ Cerrado |
| **H2** | ¿`zone_application_map.yaml` es la fuente canónica o debe estar en el RolTemplate? | `zone_application_map.yaml` es la fuente de **resolución**. El RolTemplate declara qué **zonas** tiene el rol. | El RolTemplate no debe conocer las apps concretas — eso lo acoplaría a la topología de aplicaciones. | ALTO | ✅ Cerrado |
| **H3** | ¿Los JSON deben expandirse o reducirse? | **Reducirse.** No expandir. Principio de única fuente de verdad. | Expandir crearía una tercera fuente de verdad para las mismas configuraciones. | CRÍTICO | ✅ Cerrado |
| **H4** | ¿FAL va en el RolTemplate o solo en KC? | En el **RolTemplate** como bloque `federation_domain`. KC implementa el FAL según el Auth Flow configurado por bAuth. | NIST 800-63C-4 define FAL como característica del assertion, no del IdP. El contrato declarativo debe estar en el template para auditoría. | ALTO | ✅ Cerrado |
| **H5** | ¿Separar `biometric_domain` rompe compatibilidad hacia atrás con v5.0? | No, si se implementa como **migración aditiva** en v0.9 (nuevo bloque + bloque legacy marcado deprecated). El bloque legacy se elimina en v1.0. | Migración en 2 fases garantiza zero downtime. | MEDIO | ✅ Cerrado |
| **H6** | ¿Passkeys como AAL2 requiere cambios en los RolTemplates existentes? | Solo requiere actualizar `authentication_methods_catalog` en el JSON reducido. Los RolTemplates que ya tienen `passkey` en `availableMethods` funcionan sin cambios. | NIST SP 800-63B-4 valida la decisión tomada en v5.0. No hay breaking changes. | BAJO | ✅ Cerrado |
| **H7** | ¿`email_otp` debe bloquearse en el JSON Schema o solo advertirse? | **Bloquearse** cuando es el único segundo factor. Advertirse cuando es factor adicional en flujos multi-método. | NIST SP 800-63B-4 depreca explícitamente email OTP como factor único. El JSON Schema debe reflejar el estándar. | MEDIO | ✅ Cerrado |
| **H8** | ¿`organizational_domain` reemplaza inmediatamente los 3 campos fragmentados? | No inmediatamente. En v0.9 GA se **agrega** `organizational_domain` y los campos existentes se marcan deprecated. En v1.0 se eliminan. | Compatibilidad hacia atrás. Los RolTemplates existentes siguen funcionando. | MEDIO | ✅ Cerrado |

---

## 13. Criterios de Aceptación por Fase

### Fase 0 (Pre-v0.9)

- [ ] `Authentication_Framework.json` tiene exactamente 5 secciones. Ningún campo de política de rol.
- [ ] `Policies_Authentication_Framework.json` tiene exactamente 3 secciones.
- [ ] `bauth.toml` contiene todas las configuraciones de infraestructura migradas desde los JSON.
- [ ] `roltemplate_schema.json` acepta bloques `network_domain`, `application_domain`, `federation_domain` (sin requerirlos).
- [ ] `roltemplate_schema.json` rechaza `email_otp` como único segundo factor.
- [ ] `migrations/003_add_domains.sql` ejecuta sin errores en staging.
- [ ] Todos los RolTemplates v5.0 existentes pasan validación con el nuevo JSON Schema.

### Fase 1 (v0.9 Beta)

- [ ] SBOS-ROLTEMPLATE-v5_1.md publicado con los 3 bloques nuevos + biometric_domain separado.
- [ ] SBOS-USERTEMPLATE-v5_1.md publicado con financial_limits y biometric_domain.
- [ ] `zone_application_map.yaml` creado y versionado.
- [ ] bAuth sync lee `network_domain.allowed_vlans` y escribe User Attribute en KC.
- [ ] SPI `SkbosGeoContextAuthenticator` verifica VLAN activa del cliente.
- [ ] `LogicalDomainEvaluator` responde a consultas usando `application_domain` + `zone_application_map.yaml`.
- [ ] Test: `evaluator.CanAccessZone(jwt, "zone_logical/ventas", "READ")` → `true` para RGV-001.
- [ ] Test: `evaluator.GetZoneApplications("zone_logical/ventas")` → `["tryton", "saleor", "espocrm"]`.

### Fase 2 (v0.9 GA)

- [ ] JWT incluye claim `bos_federation_level` con valor FAL del RolTemplate.
- [ ] Seed file `jurisdiction: "BO"` activa automáticamente `GOV_NORMATIVE_BO` (bit 110) en todos los roles del tenant.
- [ ] `organizational_domain` agregado al RolTemplate v5.1 con ciclo de vida completo.
- [ ] Los campos legacy `compliance_audit`, `group_management`, `conflict_management` marcados como deprecated en la documentación.
- [ ] Conector SIAT activo automáticamente en tenants con jurisdicción BO.
- [ ] Retención de logs configurada a 10 años para tenants BO.

### Fase 3 (v1.0)

- [ ] Los 9 dominios evaluables en tiempo real vía `/run/bos/bauth.sock` y `/api/v1/authorize/*`.
- [ ] 6 aplicaciones integradas: Saleor, EspoCRM, Zammad, OrangeHRM, Superset, Paperless-ngx.
- [ ] JWT emite únicamente `bos_physical_mask`, `bos_logical_mask`, `bos_financial_mask` (no `bos_bitmask` legacy).
- [ ] `trytond-auth-keycloak` actualizado para leer `bos_logical_mask`.
- [ ] `banexus` actualizado para leer `bos_physical_mask`.
- [ ] `physical_credentials.biometric_templates` eliminado (migración `004` ejecutada).
- [ ] Tests de regresión completos pasan para los 5 SPIs de KC.

### Fase 4 (v1.5)

- [ ] `GOV_NORMATIVE_AR` (bit 112) y `GOV_NORMATIVE_MX` (bit 113) activos en `bitmask_constants.go`.
- [ ] Seed files con `jurisdiction: "AR"` y `jurisdiction: "MX"` activan bits correctamente.
- [ ] `migrations/005_sam128_v15_q4_reorg.sql` ejecuta sin errores. Todos los SAM-128 recalculados.
- [ ] Passkeys configuradas como AAL2 válido en al menos 1 realm de prueba.
- [ ] `authentication_methods_catalog` actualizado con `passkey` marcado como `AAL2_VALID`.
- [ ] `federation_domain.verifiable_credentials.enabled = true` en staging.

---

## 14. Dependencias Críticas y Orden de Ejecución

```
DEPENDENCIAS ESTRICTAS (no se puede avanzar sin completar el prerrequisito):

Fase 0
  ├─► [PREREQUISITO] Aprobación ARB de decisiones H1–H8
  └─► [PARALELO] JSON Schema + bauth.toml + migrations/003 (pueden hacerse en paralelo)

Fase 1
  ├─► Requiere: Fase 0 COMPLETA
  ├─► [PARALELO] network_domain + application_domain + financial_limits + biometric_domain
  └─► zone_application_map.yaml DEBE crearse ANTES de implementar LogicalDomainEvaluator

Fase 2
  ├─► Requiere: Fase 1 COMPLETA
  └─► [PARALELO] federation_domain + organizational_domain + activación jurisdiccional

Fase 3
  ├─► Requiere: Fase 2 COMPLETA
  ├─► LogicalDomainEvaluator DEBE estar funcional ANTES de integrar las 6 apps
  ├─► FinancialDomainEvaluator puede implementarse en paralelo con las integraciones
  └─► Eliminación legacy bos_bitmask DEBE ser el ÚLTIMO paso de la fase

Fase 4
  └─► Requiere: Fase 3 COMPLETA + KC 26.4+ desplegado en producción

BLOQUEANTES EXTERNOS:
  - KC 26.4+: requerido para Passkeys (Fase 4). Verificar versión actual del deployment.
  - SIAT API Bolivia: requerido para conector SIAT (Fase 2). Verificar disponibilidad del API.
  - AFIP API Argentina: requerido para conector AFIP (Fase 4). Verificar credenciales.
```

---

## 15. Estimación de Esfuerzo

| Fase | Duración | Desarrolladores | Entregables clave |
|---|---|---|---|
| **Fase 0** — Refactorización Base | 2-3 días | 1 arquitecto + 1 developer | JSON reducidos, JSON Schema actualizado, bauth.toml, migrations/003 |
| **Fase 1** — Dominios Faltantes | 1 semana | 1 Go dev + 1 Java dev | RolTemplate v5.1, UserTemplate v5.1, zone_application_map.yaml, LogicalDomainEvaluator básico |
| **Fase 2** — Federación y Org Domain | 1 semana | 1 Go dev | federation_domain, organizational_domain, activación jurisdiccional, JWT FAL claim |
| **Fase 3** — Evaluadores e Integraciones | 3-4 semanas | 2 Go devs + integraciones por app | Todos los evaluadores, 6 apps integradas, migración JWT legacy |
| **Fase 4** — Normativo y Passkeys | 2 semanas | 1 Go dev + 1 Java dev | SAM-128 Q4 reorg, bits AR/MX, Passkeys AAL2, W3C VC prep |
| **TOTAL** | **~8-9 semanas** | | **9 dominios completos, 6 nuevas integraciones, JSON reducidos** |

---

## Apéndice A: Resumen de Estándares Aplicados

| Bloque / Dominio | Estándares | Versión |
|---|---|---|
| `network_domain` | IEEE 802.1X-2020, RFC 3748 (EAP), NIST SP 800-171 §3.5.2 | 2020 |
| `application_domain` | OASIS XACML 3.0, ISO/IEC 29146:2016, OIDC Core 1.0 | Actuales |
| `federation_domain` | NIST SP 800-63C-4, W3C VC 2.0, RFC 9449 (DPoP) | **Julio 2025** |
| `biometric_domain` | NIST SP 800-63B-4 §5.2.3, ISO/IEC 30107-3, RGPD Art. 9 | **Julio 2025** |
| `organizational_domain` | ISO/IEC 27001:2022 A.6.1/A.6.5, SCIM 2.0 RFC 7644 | 2022 |
| `SAM-128 BitmaskBundle` | ANSI/INCITS 359-2004 H-RBAC, NIST SP 800-53 AC-5, ISACA COBIT 2019 | Actuales |
| Passkeys como AAL2 | **NIST SP 800-63B-4** (publicado julio 2025) | **2025** |
| SoD — Conflict Matrix | ISO 27001:2022 A.5.3, NIST SP 800-53 AC-5 | 2022 |
| Federación FAL | **NIST SP 800-63C-4** (publicado agosto 2024, final julio 2025) | **2025** |
| Jurisdicción BO | Ley 843 Bolivia, Código Tributario Bolivia | Vigente |
| Jurisdicción AR | Código Comercial Argentina, Ley 25.506 (firma digital) | Vigente |
| Jurisdicción MX | CFF México, LFPDPPP | Vigente |

---

## Apéndice B: Nota de Revisión Arquitectónica

> **⚠️ REQUIERE APROBACIÓN ARB**
>
> Este plan de acción debe ser revisado y aprobado por el Architecture Review Board (ARB) de SKULL antes de proceder con cualquier implementación. Las decisiones H1–H8 están cerradas conceptualmente en este documento pero requieren ratificación formal del ARB.
>
> El impacto en el cronograma de v0.9 Beta depende directamente de la velocidad de aprobación del JSON Schema actualizado (Fase 0). Se recomienda priorizar la aprobación de la Fase 0 para no bloquear el trabajo en paralelo de los desarrolladores.
>
> **Custodio del documento:** Principal Systems Architect — SKULL · SBOS  
> **Fecha de revisión recomendada:** Dentro de los próximos 3 días hábiles  
> **Canal de aprobación:** Architecture Review Board (sesión extraordinaria solicitada)

---

*SKULL · SBOS · SBOS-PLAN-ACTUALIZACION-v1_0 · Abril 2026*  
*Basado en: sbos-auth-templates-audit-v1.0 · SBOS-BAUTH-CONCEPTUALIZACION-v4_0 · SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1_0 · SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION · SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO*  
*Estándares: NIST SP 800-63B-4/C-4 · IEEE 802.1X-2020 · OASIS XACML 3.0 · ISO/IEC 27001:2022 · ANSI/INCITS 359-2004 · RGPD Art.9 · RFC 9449 DPoP · W3C VC 2.0*
