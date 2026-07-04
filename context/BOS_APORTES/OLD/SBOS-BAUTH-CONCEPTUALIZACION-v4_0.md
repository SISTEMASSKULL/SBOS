# SBOS-008 · bAuth — Unified Identity & Permissions Orchestrator
## Conceptualización Definitiva: El Daemon Soberano de Identidad
### SKULL · SBOS — Sovereign Business Operating System
### v4.0 · Abril 2026

---

| Campo | Valor |
|---|---|
| **Código** | SBOS-BAUTH-CONCEPTUALIZACION |
| **Versión** | 4.0 — definitiva, reemplaza v1.0, v2.0, v3.0 |
| **Estado** | ACTIVO |
| **Daemon** | `bauth.service` — Go 1.22+ |
| **Reemplaza** | SBOS-008 §7 y §8 completos |
| **Integra** | SBOS-009, SBOS-019, SBOS-020, SBOS-008-001, SAM-128, todas las decisiones de sesión Febrero–Abril 2026 |

---

## 1. EL PROBLEMA QUE BAUTH RESUELVE

Los sistemas empresariales fallan por tres causas sistémicas:

**Desincronización:** el IdP (Keycloak) y el ERP (Tryton) divergen. Un administrador configura un rol en uno y lo olvida en el otro.

**Herencia manual:** un rol "Contador Senior" debería heredar de "Contador Júnior" pero con herencia manual un error humano introduce accesos incorrectos.

**Enforcement inconsistente:** si la seguridad depende de cada app individual, una sola app con un bug de autorización expone todo el sistema.

**bAuth elimina los tres:** calcula herencia automáticamente con aritmética binaria (H-RBAC, ANSI/INCITS 359-2004), sincroniza KC y Tryton proactivamente en menos de 5 segundos, y el enforcement es estructural — vive en los sistemas nativos, no en código adicional.

---

## 2. DEFINICIÓN CANÓNICA

> **bAuth es el sistema de identidad del SBOS.**
> Keycloak y Tryton son sus brazos de ejecución.
> El SBOS no consulta KC directamente. No consulta Tryton directamente.
> El SBOS consulta bAuth.

bAuth opera con **6 responsabilidades simultáneas:**

```
1. SINCRONIZADOR MAESTRO
   Traduce RolTemplate → objetos nativos KC + Tryton + adaptadores de app
   Garantía: < 5 segundos desde guardar hasta SYNCED

2. MOTOR DE PRIVILEGIOS (PrivilegeEngine)
   H-RBAC con AND NOT — herencia automática, sin errores humanos
   Produce SAM-128 por rol + bos_context para el JWT

3. EVALUADOR EN TIEMPO REAL
   bhnexus consulta via Unix socket /run/bos/bauth.sock
   Latencia < 5ms con cache Redis TTL 5 min

4. INTERFAZ DE ADMINISTRACIÓN (PAP)
   API REST para Core UI — CRUD de RolTemplates y UserTemplates
   Única puerta de entrada autorizada para modificar identidad

5. GESTOR DE IDENTIDAD FÍSICA
   QR dinámicos (HMAC-SHA256, TTL 30s configurable)
   Hashes biométricos en bauth_biometric_templates
   Validación NFC/RFID via bhnexus

6. GUARDIÁN DE SOD Y CUMPLIMIENTO
   Conflict Matrix evaluada ANTES de guardar cualquier RolTemplate
   Audit log inmutable en bkernel_db.audit_events (ISO 27001 A.8.15)
   Alertas Wazuh SIEM HIGH/CRITICAL en tiempo real
```

### Lo que NO existe en el SBOS

```
✗  KC → Tryton         (comunicación directa — NUNCA)
✗  Tryton → KC         (comunicación directa — NUNCA)
✗  App → KC            (todo pasa por bAuth)
✗  App → Tryton        (todo pasa por bAuth)
✗  banexus → bAuth     (SIEMPRE: banexus → bhnexus → bAuth)
✗  bos_bitmask 64 bits (reemplazado por bos_sam128 128 bits desde v1.0)
```

---

## 3. EL TRIÁNGULO KC — BAUTH — TRYTON: UNA SOLA FUENTE DE VERDAD

La comprensión correcta de este triángulo es el fundamento de todo el sistema de identidad del SBOS.

```
┌─────────────────────────────────────────────────────────────────┐
│                          bAuth                                   │
│                    (Coordinador Central)                         │
│                                                                  │
│  "A quien el SBOS pregunta y actualiza en materia de identidad" │
│                                                                  │
│  ¿Tiene este usuario este permiso?      → bAuth                 │
│  ¿Cuál es el rol de este usuario?       → bAuth                 │
│  ¿Puede ejecutar esta operación?        → bAuth                 │
│  ¿Cómo configuro un rol nuevo?         → bAuth (via Core UI)    │
└────────────┬───────────────────────────┬────────────────────────┘
             │                           │
             │ Keycloak Admin API REST   │ Tryton XML-RPC API
             │                           │
   ┌─────────▼──────────┐     ┌──────────▼─────────┐
   │     Keycloak        │     │      Tryton         │
   │   (Brazo de IdP)    │     │   (Brazo de ERP)   │
   │                     │     │                     │
   │ ¿Qué hace KC?       │     │ ¿Qué hace Tryton?   │
   │ • Autentica al user │     │ • Aplica 5 capas de │
   │ • Emite el JWT      │     │   enforcement nativo│
   │ • Gestiona sesiones │     │ • ir.model.access   │
   │ • MFA, WebAuthn     │     │ • ir.rule (SQL)     │
   │ • OIDC/SAML         │     │ • ir.model.button   │
   │ • SPIs personalizados│    │ • ir.model.field    │
   │                     │     │ • ir.action.groups  │
   │ KC NO decide quién  │     │ Tryton NO decide    │
   │ puede hacer qué.    │     │ quién puede entrar. │
   │ KC solo pregunta    │     │ Tryton solo ejecuta │
   │ a bAuth y emite.    │     │ lo que bAuth define.│
   └─────────────────────┘     └─────────────────────┘
```

### La Separación más Importante: Sincronización vs Login Time

> **KC no consulta el RolTemplate en tiempo de login.**
> bAuth TRADUCE el RolTemplate a objetos nativos de KC ANTES de que llegue ningún usuario.
> En login time, KC solo lee su propia base de datos interna — sin depender de bAuth.

```
TIEMPO DE SINCRONIZACIÓN (admin guarda un RolTemplate):
  ┌──────────────────────────────────────────────────────┐
  │ bAuth → KC Admin API:                                │
  │   Composite Role (nombre canónico del rol)           │
  │   Realm roles atómicos (1 por bit activo del SAM)    │
  │   Authentication Flow (métodos requeridos)           │
  │   User Attributes (redes, horario, vigencia)         │
  │   Session Settings (duración, concurrencia, LoA)     │
  │                                                      │
  │ bAuth → Tryton XML-RPC:                              │
  │   ir.model.access (CRUD por modelo)                  │
  │   ir.rule.group (Record Rules — filtros SQL)         │
  │   ir.model.button (Button Rules + SoD)               │
  │   ir.action.groups (menús visibles)                  │
  │   ir.model.field.access (campos individuales)        │
  └──────────────────────────────────────────────────────┘

TIEMPO DE LOGIN (usuario se autentica, bAuth no interviene):
  Browser → KC (lee su propia BD sincronizada por bAuth)
  JWT emitido con bos_context ya calculado y embebido
  Apps validan JWT localmente con JWKS — sin llamadas a bAuth

TIEMPO DE OPERACIÓN (usuario ejecuta acción):
  banexus → bhnexus → bAuth (Unix socket, < 5ms)
  bAuth: SAM-128 en Redis → respuesta O(1)
```

### El Patrón PAP / PIP / PDP / PEP

| Punto | Función | Implementación SBOS |
|---|---|---|
| **PAP** — Policy Administration Point | Donde se administran las políticas | Core UI → formulario de RolTemplate/UserTemplate |
| **PIP** — Policy Information Point | Donde viven los datos | PostgreSQL → tabla `bos_bauth_template` (JSONB) |
| **bAuth** | El traductor PIP → PDP + PEP en < 5s | `bauth.service` — sincronizador idempotente |
| **PDP** — Policy Decision Point | Quién decide si se permite | KC (login) + bAuth (operación) + Tryton (enforcement) |
| **PEP** — Policy Enforcement Point | Quién bloquea o permite | Tryton (5 capas) + KC (SPIs) + OAuth2-Proxy + banexus |

---

## 4. ROLTEMPLATE Y USERTEMPLATE: EL ÚNICO CONTRATO

### Principio Absoluto

RolTemplate y UserTemplate son el **único contrato** de comunicación y configuración entre el SBOS y todos los sistemas de autenticación. No hay otro documento. No hay otro canal. No hay otra forma de modificar el sistema de identidad.

```
TODO lo que bAuth sincroniza en KC, Tryton, y apps
proviene exclusivamente del RolTemplate y UserTemplate.
```

### Separación de Responsabilidades

| Dimensión | RolTemplate | UserTemplate |
|---|---|---|
| **Pregunta** | ¿Qué PUEDE HACER un tipo de rol? | ¿Quién ES y qué TIENE este usuario concreto? |
| **Granularidad** | Define una categoría organizacional | Define una persona concreta |
| **Multiplicidad** | Un RolTemplate → muchos usuarios | Un UserTemplate → un usuario |
| **Sincroniza en KC** | Auth Flows, Session Settings, User Attributes del rol | User record, credenciales registradas, rol asignado |
| **Sincroniza en Tryton** | Grupos, ir.model.access, ir.action.groups, ir.model.button | res.user, company.employee, idioma, empresa activa |

### RolTemplate — Estructura JSONB Completa (todos los campos)

El RolTemplate se almacena en PostgreSQL tabla `bos_bauth_template` en un campo `JSONB`. Las columnas normalizadas (`id`, `status`, `sam128_lo`, `sam128_hi`) permiten indexación y WAL detection. El cuerpo completo vive en `template JSONB`.

```json
{
  "role": {
    // ── BLOQUE 1 — IDENTIFICACIÓN ─────────────────────────────────
    "id":             "RGV-001",
    "name":           "Gerente Regional de Ventas — Norte",
    "description":    "Responsable territorio Norte. Gestión de equipo, aprobaciones.",
    "department":     "Ventas",
    "parent_id":      "VEN-BASE-001",   // herencia H-RBAC: AND NOT con bits removidos
    "version_number": 7,
    "status":         "ACTIVE",         // DRAFT|REVIEW|ACTIVE|DEPRECATED|ARCHIVED
    "audit": {
      "created_by":  "ADMIN.SISTEMA",
      "created_at":  "2024-01-01T00:00:00Z",
      "updated_by":  "DGV-CARLOS.RUIZ",
      "updated_at":  "2025-03-01T10:30:00Z",
      "approved_by": "CFO",
      "approved_at": "2025-03-01T10:31:00Z"
    },

    // ── BLOQUE 2 — VIGENCIA ───────────────────────────────────────
    "validity_period": {
      "start_date":  "2024-01-15T00:00:00Z",
      "end_date":    "2027-12-31T23:59:59Z",   // null = indefinido
      "review_date": "2026-07-01T00:00:00Z"
    },

    // ── BLOQUE 3 — FLUJO DE APROBACIÓN ───────────────────────────
    "approval_workflow": {
      "required_approvers": 2,
      "approver_roles": ["DIRECTOR_VENTAS", "CFO"],
      "notification_channel": "rocket_chat"
    },

    // ── BLOQUE 4 — ACCESO LÓGICO (DOMINIO 1) ─────────────────────
    // Lo que KC controla: métodos, horario, red, sesión
    // bAuth traduce este bloque a: Authentication Flow KC + User Attributes
    "logical_access": {
      "availableMethods": [
        "username_password", "2fa_app", "biometric_login",
        "smart_card_logical", "hardware_token"
      ],
      "requiredMethods": {
        "standard_login": [
          {"method": "username_password", "order": 1},
          {"method": "2fa_app",           "order": 2}
        ],
        "elevated_login": [
          {"method": "username_password", "order": 1},
          {"method": "biometric_login",   "order": 2}
        ]
      },
      "alternativeMethods": [
        {
          "replaces": "biometric_login",
          "with":     "hardware_token",
          "requires_approval": false
        }
      ],
      "level_of_assurance": 2,
      "geospatial_control": {
        "allowed_locations": [
          {
            "type": "office",
            "name": "Sucursal La Paz — Av. Camacho 1234",
            "network_ranges": ["192.168.10.0/24", "10.0.1.0/24"]
          },
          {
            "type": "vpn",
            "name": "VPN Corporativa",
            "network_ranges": ["10.10.0.0/16"]
          }
        ],
        "validation_rules": {
          "require_vpn": false,
          "allow_roaming": false
        }
      },
      "temporal_control": {
        "schedule_type": "SPECIFIC_DAYS",
        "allowed_days": [
          {"day": "MONDAY",    "shifts": [{"start": "08:00", "end": "18:00"}]},
          {"day": "TUESDAY",   "shifts": [{"start": "08:00", "end": "18:00"}]},
          {"day": "WEDNESDAY", "shifts": [{"start": "08:00", "end": "18:00"}]},
          {"day": "THURSDAY",  "shifts": [{"start": "08:00", "end": "18:00"}]},
          {"day": "FRIDAY",    "shifts": [{"start": "08:00", "end": "15:00"}]}
        ],
        "timezone": "America/La_Paz",
        "session_management": {
          "max_session_duration":       28800,
          "inactivity_timeout":           900,
          "force_logout_at_end_shift":   true,
          "concurrent_sessions_allowed": false
        }
      }
    },

    // ── BLOQUE 5 — ACCESO FÍSICO (DOMINIO 2) ─────────────────────
    // bAuth materializa en SAM-128 Q2 + device fichas bhnexus
    "physical_access": {
      "zones": [
        {
          "zone_id":      "PHY_ZONE_VENTAS",
          "name":         "Zona de Ventas — Planta Baja",
          "security_level": 2,
          "schedule":     "business_hours",
          "access_level": "FULL"
        },
        {
          "zone_id":      "PHY_ROOM_SERVIDOR",
          "name":         "Sala de Servidores",
          "security_level": 4,
          "schedule":     "never",
          "access_level": "DENIED"
        }
      ],
      "biometric_enrollment_policy": {
        "mode":              "hybrid",
        "risk_level":        "high",
        "liveness_required": true,
        "fallback_method":   "qr_dynamic",
        "hash_algorithm":    "PBKDF2-SHA256",
        "fmr_threshold":     "1:10000"
      }
    },

    // ── BLOQUE 6 — ZONAS LÓGICAS Y APLICACIONES (DOMINIO 1 + 5) ──
    // Cada zona declara qué aplicaciones la implementan
    // v1.0: motor valida solo nombre de "app". Módulos son capacidad latente.
    "zones": {
      "zone_logical/ventas": {
        "verbs": ["READ", "WRITE", "APPROVE", "EXECUTE"],
        "applications": [
          {"app": "tryton",   "modules": ["sale", "sale.opportunity"]},
          {"app": "saleor"},
          {"app": "espocrm"}
        ]
      },
      "zone_logical/facturacion": {
        "verbs": ["READ", "WRITE", "EMIT"],
        "applications": [
          {"app": "tryton",   "modules": ["account", "account_invoice"]},
          {"app": "superset", "dashboards": ["facturacion_mensual"]},
          {"app": "paperless","tags": ["factura", "fiscal"]}
        ]
      },
      "zone_logical/reportes": {
        "verbs": ["READ", "EXECUTE"],
        "applications": [
          {"app": "superset"},
          {"app": "tryton", "modules": ["account_statement"]}
        ]
      },
      "zone_financial/ventas": {
        "verbs": ["CREATE", "APPROVE"],
        "limit_tier": 2,
        "sod_cannot_also": "zone_financial/ventas:AUDIT"
      }
    },

    // ── BLOQUE 7 — PRIVILEGIOS TRYTON (5 NIVELES) ─────────────────
    // bAuth genera todos estos objetos en Tryton al sincronizar
    "tryton_privileges": {
      "model_access": [
        {"model": "sale.order",        "read": true, "write": true,  "create": true,  "delete": false},
        {"model": "sale.opportunity",  "read": true, "write": true,  "create": true,  "delete": false},
        {"model": "account.invoice",   "read": true, "write": false, "create": false, "delete": false},
        {"model": "account.payment",   "read": true, "write": true,  "create": true,  "delete": false},
        {"model": "party.party",       "read": true, "write": true,  "create": true,  "delete": false},
        {"model": "stock.shipment.out","read": true, "write": false, "create": false, "delete": false}
      ],
      "visible_actions": [
        "menu_sale_orders", "menu_sale_opportunities",
        "menu_sale_reports_regional", "menu_party_customers",
        "menu_account_payment_view", "menu_dashboard_ventas"
      ],
      "field_restrictions": [
        {"model": "account.invoice", "field": "margin",      "read": false, "write": false},
        {"model": "sale.order",      "field": "cost_price",  "read": false, "write": false}
      ],
      "button_rules": [
        {
          "model":           "sale.order",
          "button":          "confirm",
          "users_required":  1,
          "condition_pyson": "Eval('amount_total', 0) <= 10000",
          "sod_cannot_also": null,
          "step_up_loa":     null
        },
        {
          "model":           "sale.order",
          "button":          "confirm",
          "users_required":  2,
          "condition_pyson": "Eval('amount_total', 0) > 10000",
          "sod_cannot_also": null,
          "step_up_loa":     3
        },
        {
          "model":           "account.payment",
          "button":          "approve",
          "users_required":  2,
          "condition_pyson": "Eval('amount', 0) > 5000",
          "sod_cannot_also": "account.payment:create",
          "step_up_loa":     3
        }
      ],
      "record_rules": [
        {
          "model":       "sale.order",
          "domain_pyson":"[('team.territory', '=', 'NORTH')]",
          "description": "Solo ve pedidos de su territorio"
        },
        {
          "model":       "party.party",
          "domain_pyson":"[('category', 'in', ['CUSTOMER', 'PROSPECT'])]",
          "description": "Solo ve clientes y prospectos"
        }
      ]
    },

    // ── BLOQUE 8 — TRANSACCIONES FINANCIERAS (DOMINIO 3) ──────────
    "financial_transactions": {
      "availableMethods": ["smart_card_pin", "mobile_token", "biometric_validation"],
      "requiredMethods": {
        "standard_transactions": [
          {"method": "smart_card_pin", "order": 1},
          {"method": "mobile_token",   "order": 2}
        ],
        "high_value_transactions": [
          {"method": "smart_card_pin",      "order": 1},
          {"method": "mobile_token",         "order": 2},
          {"method": "biometric_validation", "order": 3}
        ]
      },
      "transaction_schedule": {
        "type": "SCHEDULED",
        "schedules": [
          {
            "name": "Pagos Quincenales",
            "periods": [
              {"days_of_month": [13, 14, 15], "hours": {"start": "09:00", "end": "16:00"}},
              {"days_of_month": [28, 29, 30, 31], "hours": {"start": "09:00", "end": "16:00"}}
            ]
          }
        ],
        "emergency_override": {
          "allowed": true,
          "requires_approval": true,
          "approver_roles": ["FINANCE_DIRECTOR", "CEO"]
        }
      },
      "transaction_limits": {
        "single_transaction_limit": 10000,
        "daily_limit":              50000,
        "monthly_limit":           200000,
        "currency":                "BOB"
      }
    },

    // ── BLOQUE 9 — DELEGACIÓN ─────────────────────────────────────
    "delegation_config": {
      "can_delegate":       true,
      "max_duration_days":  21,
      "delegable_to_roles": ["SUP-NORTE-001", "GER-VENTAS-SUR"],
      "requires_approval":  true,
      "approver_roles":     ["DIRECTOR_VENTAS"]
    },

    // ── BLOQUE 10 — COMPLIANCE Y ACCESS REVIEW ────────────────────
    "compliance_audit": {
      "review_frequency":  "QUARTERLY",   // MONTHLY|QUARTERLY|SEMIANNUAL|ANNUAL
      "last_review":       "2026-01-01T00:00:00Z",
      "next_review":       "2026-07-01T00:00:00Z"
    },

    // ── BLOQUE 11 — ESTADO DE SINCRONIZACIÓN (gestionado por bAuth)
    "sync_state": {
      "sync_status":   "SYNCED",           // PENDING|SYNCING|SYNCED|ERROR|DRIFT
      "last_sync_at":  "2025-03-01T10:35:00Z",
      "sync_targets": {
        "keycloak": {
          "status":         "SYNCED",
          "composite_role": "RGV_001",
          "group_path":     "/Empresa-ACME/Ventas/Norte"
        },
        "tryton": {
          "status":    "SYNCED",
          "group_id":  847,
          "group_name":"RGV_001"
        }
      }
    }
  }
}
```

### UserTemplate — Estructura Completa

```json
{
  "user": {
    // ── BLOQUE 1 — IDENTIFICACIÓN ─────────────────────────────────
    // uuid → KC sub claim. Identificador inmutable en todo el SBOS.
    "id":          1001,
    "uuid":        "550e8400-e29b-41d4-a716-446655440000",
    "username":    "maria.garcia",
    "external_id": "EMP789456",
    "status":      "ACTIVE",          // ACTIVE|INACTIVE|SUSPENDED|TERMINATED
    "version":     "1.1.0",

    // ── BLOQUE 2 — DATOS PERSONALES ──────────────────────────────
    // KC user profile attributes → OIDC claims estándar
    "personal_info": {
      "given_name":     "María",
      "family_name":    "García López",
      "email":          "maria.garcia@acme.com",
      "email_verified": true,
      "phone_number":   "+591 70012345",
      "locale":         "es-BO",
      "zoneinfo":       "America/La_Paz"
    },

    // ── BLOQUE 3 — DATOS PROFESIONALES ───────────────────────────
    // Tryton: company.employee + party.party
    "professional_info": {
      "employee_code": "EMP789456",
      "job_title":     "Gerente Regional de Ventas Norte",
      "department":    "Ventas",
      "cost_center":   "VENTAS-NORTE",
      "supervisor_uuid":"uuid-del-supervisor",
      "hire_date":     "2024-01-15"
    },

    // ── BLOQUE 4 — ROL ASIGNADO ───────────────────────────────────
    // El RolTemplate al que está asignado este usuario
    "roles_assignments": {
      "active_roles": [
        {
          "role_id":    "RGV-001",
          "assigned_at":"2024-01-15T08:00:00Z",
          "assigned_by":"ADMIN.SISTEMA",
          "valid_until": null
        }
      ],
      "history": [
        {
          "role_id":    "VEN-VEN-001",
          "assigned_at":"2023-01-01T00:00:00Z",
          "removed_at": "2024-01-14T00:00:00Z",
          "reason":     "Promovida a Gerente Regional"
        }
      ]
    },

    // ── BLOQUE 5 — CREDENCIALES REGISTRADAS EN KC ─────────────────
    // Qué métodos TIENE registrados (no qué requiere su rol — eso es RolTemplate)
    "keycloak_credentials": {
      "has_password":          true,
      "has_totp":              true,
      "has_webauthn":          true,
      "has_x509":              false,
      "registered_devices": [
        {
          "type":          "webauthn",
          "device_name":   "YubiKey 5 NFC",
          "registered_at": "2024-02-01T10:00:00Z"
        },
        {
          "type":          "totp",
          "device_name":   "Google Authenticator — iPhone",
          "registered_at": "2024-01-15T08:30:00Z"
        }
      ],
      "credentials_compliance": {
        "covers_required_methods": true,
        "missing_methods": []
      }
    },

    // ── BLOQUE 6 — BINDING CON TRYTON ────────────────────────────
    "tryton_binding": {
      "user_id":    1547,
      "employee_id":2341,
      "company_id": 1,
      "language":   "es",
      "active":     true
    },

    // ── BLOQUE 7 — ESTADO DE SINCRONIZACIÓN ──────────────────────
    "sync_state": {
      "sync_status": "SYNCED",
      "keycloak":    {"status": "SYNCED", "kc_user_id": "uuid-kc"},
      "tryton":      {"status": "SYNCED", "tryton_user_id": 1547}
    }
  }
}
```

---

## 5. ESQUEMA DE ALMACENAMIENTO POSTGRESQL

Patrón híbrido: columnas normalizadas para indexación y WAL detection + campo `JSONB` para el cuerpo completo del contrato.

```sql
-- Tabla principal de RolTemplates
CREATE TABLE bos_rol_template (
    id              TEXT PRIMARY KEY,       -- "ROL_CAJERO_001"
    tenant_id       TEXT NOT NULL,
    empresa_id      TEXT NOT NULL,
    parent_id       TEXT REFERENCES bos_rol_template(id),
    status          TEXT NOT NULL,          -- DRAFT|REVIEW|ACTIVE|DEPRECATED|ARCHIVED
    version         TEXT NOT NULL,          -- "2.1.0"
    sam128_lo       BIGINT,                 -- Q1+Q2 calculados por PrivilegeEngine
    sam128_hi       BIGINT,                 -- Q3+Q4 calculados por PrivilegeEngine
    sync_status     TEXT NOT NULL DEFAULT 'PENDING',
    last_sync_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now(),
    template        JSONB NOT NULL,         -- cuerpo completo del RolTemplate
    CONSTRAINT chk_status CHECK (status IN ('DRAFT','REVIEW','ACTIVE','DEPRECATED','ARCHIVED'))
);

CREATE INDEX idx_brt_tenant   ON bos_rol_template(tenant_id, empresa_id);
CREATE INDEX idx_brt_status   ON bos_rol_template(status);
CREATE INDEX idx_brt_template ON bos_rol_template USING GIN(template);
CREATE INDEX idx_brt_zones    ON bos_rol_template USING GIN((template->'zones') jsonb_path_ops);

-- Historial inmutable para auditoría ISO 27001
CREATE TABLE bos_rol_template_history (
    history_id    BIGSERIAL PRIMARY KEY,
    rol_id        TEXT NOT NULL,
    version       TEXT NOT NULL,
    template_snap JSONB NOT NULL,
    changed_by    TEXT NOT NULL,
    changed_at    TIMESTAMPTZ DEFAULT now(),
    change_reason TEXT
);

-- UserTemplates
CREATE TABLE bos_user_template (
    uuid        TEXT PRIMARY KEY,
    username    TEXT NOT NULL UNIQUE,
    email       TEXT NOT NULL,
    tenant_id   TEXT NOT NULL,
    empresa_id  TEXT NOT NULL,
    rol_id      TEXT REFERENCES bos_rol_template(id),
    status      TEXT NOT NULL DEFAULT 'ACTIVE',
    sync_status TEXT NOT NULL DEFAULT 'PENDING',
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now(),
    template    JSONB NOT NULL
);

-- Hashes biométricos — NUNCA raw biometric
CREATE TABLE bauth_biometric_templates (
    id                BIGSERIAL PRIMARY KEY,
    user_uuid         TEXT NOT NULL REFERENCES bos_user_template(uuid),
    biometric_type    TEXT NOT NULL,    -- fingerprint|face|iris|palm_vein
    finger            SMALLINT,         -- 1-10 para huella, null otros
    template_hash     BYTEA NOT NULL,   -- PBKDF2-SHA256 del template local del lector
    salt              BYTEA NOT NULL,
    enrollment_policy TEXT NOT NULL,    -- admin_only|self_service|hybrid
    liveness_verified BOOLEAN DEFAULT false,
    admin_verified    BOOLEAN DEFAULT false,
    enrolled_at       TIMESTAMPTZ,
    enrolled_by       TEXT,             -- uuid del admin o 'SELF'
    UNIQUE (user_uuid, biometric_type, COALESCE(finger, 0))
);
```

---

## 6. LOS MÉTODOS DE AUTENTICACIÓN EN EL SBOS

Todos los métodos están declarados en el RolTemplate (`availableMethods`, `requiredMethods`). bAuth los traduce a Authentication Flows de Keycloak al sincronizar.

### 6.1 El Principio que Organiza Todo

> **Keycloak verifica la prueba criptográfica de identidad. Lo que está antes de esa prueba — el hardware, el sensor, el PIN, el dedo — es responsabilidad del dispositivo, no de Keycloak.**

La frontera de KC es el mundo digital. Para el mundo físico (QR, NFC, huella en lector), el SBOS usa el bridge banexus→bhnexus→bAuth.

### 6.2 Los 15 Métodos — Categorías y Responsabilidad KC

```
CATEGORÍA 1 — BASADOS EN CONOCIMIENTO
  1. Username + Password      → KC nativo: hash + brute-force + políticas
  2. TOTP                     → KC nativo: secreto compartido + ventana temporal
  3. HOTP                     → KC nativo: contador incremental
  4. Recovery Codes           → KC nativo: códigos de un solo uso
  5. Security Questions       → Solo vía SPI — no recomendado (débil)

CATEGORÍA 2 — BASADOS EN POSESIÓN
  6. WebAuthn / FIDO2 (HW)   → KC nativo: clave pública + challenge + signature counter
  7. Passkeys                 → KC 26.4+: WebAuthn sincronizadas (iCloud/Google/Windows)
  8. X.509 / Smart Card       → KC nativo: validación cert + CRL/OCSP + mapeo DN
  9. Magic Link               → KC nativo: token de un uso + email + TTL
  10. SMS OTP                 → Requiere SPI: BOS-SMS-SPI + proveedor externo
  11. Email OTP               → KC 26 nativo: código por email + TTL

CATEGORÍA 3 — BASADOS EN INHERENCIA
  12. WebAuthn Biométrico     → KC nativo: firma del enclave + userVerification=REQUIRED
                                (sensor verifica localmente; KC nunca toca la biometría)

CATEGORÍA 4 — BASADOS EN CONTEXTO
  13. Kerberos / SPNEGO       → KC nativo: ticket Kerberos + keytab
  14. Social Login / OIDC     → KC nativo: OAuth2/SAML broker
  15. LDAP / AD               → KC nativo: bind + sync + mapeo de atributos

CATEGORÍA 5 — FÍSICO (fuera del scope de KC — gestionado por NEXUS)
  QR dinámico                 → bAuth genera, banexus captura, bhnexus valida HMAC
  NFC/RFID                    → bhnexus descifra, bAuth valida user_id
  Biométrico en lector físico → lector genera hash local, bAuth verifica vs DB
```

### 6.3 Mapa Métodos del RolTemplate → Implementación KC

```
username_password     → Username Password Form (nativo)
2fa_app               → OTP Form / TOTP (nativo)
biometric_login       → WebAuthn Passwordless Authenticator (nativo)
security_key          → WebAuthn Authenticator (nativo)
hardware_token        → WebAuthn Authenticator modo hardware (nativo)
email_verification    → Email OTP (nativo KC 26)
mobile_app_token      → TOTP (nativo) o SMS OTP (BOS-SMS-SPI)
smart_card_logical    → WebAuthn + YubiKey PIV / X.509 (nativo)
fingerprint (digital) → WebAuthn biométrico con userVerification=REQUIRED
smart_card_pin        → X.509 nativo + BOS-SmartCardPIN-SPI
biometric_validation  → WebAuthn con userVerification=REQUIRED (LoA 3)
digital_signature     → X.509 con KeyUsage=digitalSignature (nativo)
proximity_card        → Sistema físico → bridge bhnexus (fuera de KC)
qr_code_access        → Sistema físico → bridge bhnexus (fuera de KC)
facial_recognition    → Sistema físico → bridge bhnexus (fuera de KC)
```

---

## 7. LOS 5 SPIS QUE BAUTH CONSTRUYE PARA KEYCLOAK

KC nativo resuelve completamente: Username+Password, TOTP, WebAuthn, Passkeys, X.509, Magic Link, Email OTP, Kerberos, LDAP. bAuth debe construir 5 SPIs adicionales (`org.keycloak.authentication.Authenticator`):

### SPI-1: BOS-Guard — `SkbosGuardAuthenticator`

```java
// Se ejecuta PRIMERO en cada Authentication Flow
// Lee availableMethods del RolTemplate (via User Attributes del grupo KC)
// Bloquea cualquier método que no esté autorizado para el rol
// Sin esto, un usuario podría saltar a un método no autorizado

void authenticate(AuthenticationFlowContext context) {
    String requestedMethod = context.getAuthenticationSession()
                                    .getClientNote("requested_method");
    Set<String> allowedMethods = getUserAllowedMethods(context.getUser());
    if (!allowedMethods.contains(requestedMethod)) {
        context.failure(AuthenticationFlowError.ACCESS_DENIED,
            Response.status(403).entity("Método no autorizado para este rol").build());
    }
}
```

### SPI-2: BOS-GeoContext — `SkbosGeoContextAuthenticator`

```java
// Lee allowed_networks del User Attribute (sincronizado desde RolTemplate)
// Evalúa la IP de origen del login
// Deniega si la red no está en la lista autorizada

void authenticate(AuthenticationFlowContext context) {
    String clientIP = context.getConnection().getRemoteAddr();
    List<String> allowedNetworks = getUserAllowedNetworks(context.getUser());
    if (!isIPInAnyRange(clientIP, allowedNetworks)) {
        context.failure(AuthenticationFlowError.ACCESS_DENIED,
            Response.status(403).entity("Red no autorizada: " + clientIP).build());
    }
}
```

### SPI-3: BOS-FinancialPeriod — `SkbosFinancialPeriodAuthenticator`

```java
// Verifica transaction_schedule del RolTemplate
// Si el usuario tiene roles financieros, valida la ventana de operación
// Deniega operaciones financieras fuera de la ventana declarada en el RolTemplate

void authenticate(AuthenticationFlowContext context) {
    FinancialSchedule schedule = getFinancialSchedule(context.getUser());
    if (!schedule.isCurrentTimeAllowed(ZonedDateTime.now())) {
        String nextWindow = schedule.getNextAllowedWindow();
        context.failure(AuthenticationFlowError.ACCESS_DENIED,
            Response.status(403)
                    .entity("Ventana financiera cerrada. Próxima: " + nextWindow).build());
    }
}
```

### SPI-4: BOS-RoleValidity — `SkbosRoleValidityAuthenticator`

```java
// Verifica validity_period del RolTemplate asignado al usuario
// Si el rol venció → deniega el login con mensaje descriptivo
// bAuth también detecta esto en el reconcile loop y auto-revoca

void authenticate(AuthenticationFlowContext context) {
    LocalDate validUntil = getRoleValidUntil(context.getUser());
    if (validUntil != null && LocalDate.now().isAfter(validUntil)) {
        context.failure(AuthenticationFlowError.ACCESS_DENIED,
            Response.status(403)
                    .entity("Rol vencido el " + validUntil + ". Contacte al administrador.").build());
    }
}
```

### SPI-5: BOS-SmartCardPIN — `SkbosSmartCardPINAuthenticator`

```java
// Gestiona flujo X.509 + PIN para tarjetas inteligentes corporativas
// Complementa el X.509 nativo de KC con validación del PIN del chip
// Permite autenticación sin contraseña de sistema para roles con smart_card_logical

void authenticate(AuthenticationFlowContext context) {
    X509Certificate cert = extractCertFromHeader(context);
    String pinHash = context.getHttpRequest().getDecodedFormParameters()
                            .getFirst("card_pin_hash");
    if (!validateCardPIN(cert.getSerialNumber(), pinHash)) {
        context.failure(AuthenticationFlowError.INVALID_CREDENTIALS);
    }
    // Si OK → continúa al siguiente step del Auth Flow
}
```

Los 5 SPIs se distribuyen como JARs en `/opt/keycloak/providers/`. bAuth los configura en el Authentication Flow de cada realm al provisionar.

---

## 8. EL SAM-128 — SOVEREIGN AUTHORITY MATRIX

### 8.1 Justificación de 128 bits (decisión CERRADA — P1)

**64 bits no son suficientes:** con 3 dominios de soberanía y un cuadrante de auditoría, cada dominio tendría ~16 bits. Con 10+ verbos básicos + zonas + bits de estado, 16 bits es insuficiente para un sistema empresarial real con 100+ apps.

**128 bits sin dependencias externas:** el stdlib de Go implementa `uint128` exactamente como `struct{ hi, lo uint64 }` en `net/netip/uint128.go`. Operaciones AND, OR, NOT: ~0.45 ns/op, zero allocations. Idéntico rendimiento al uint64 nativo.

**Serialización JWT compacta:** 128 bits en hex = 32 caracteres. `"bos_sam128": "0x00000109000003000001001700010052"` = ~50 bytes. El JWT completo del SBOS permanece < 2KB — dentro del límite de cookie de 4KB.

### 8.2 Estructura: 4 Cuadrantes de 32 bits

```
SAM-128 (struct{ lo, hi uint64 })
  lo = bits 0–63  (Q1 Lógico + Q2 Físico)
  hi = bits 64–127 (Q3 Financiero + Q4 Soberanía)

══════════════════════════════════════════════════════════════════════
Q1: DOMINIO LÓGICO (bits 0–31) — lo mitad baja
    "¿Qué puede hacer digitalmente este actor en este nodo?"
══════════════════════════════════════════════════════════════════════
Zona 1 — Verbos de Aplicación (bits 0–15):
  Bit 0:  LOG_READ           — leer registros en zonas lógicas autorizadas
  Bit 1:  LOG_WRITE          — crear y modificar registros
  Bit 2:  LOG_DELETE         — eliminar registros (requiere LoA elevado)
  Bit 3:  LOG_APPROVE        — aprobar solicitudes o documentos (SoD)
  Bit 4:  LOG_EXECUTE        — ejecutar procesos automatizados
  Bit 5:  LOG_CONFIGURE      — modificar parámetros del sistema
  Bit 6:  LOG_AUDIT          — acceso a logs de auditoría (aislado de LOG_READ)
  Bit 7:  LOG_ENABLE         — habilitar entidades o funciones
  Bit 8:  LOG_DISABLE        — deshabilitar entidades o funciones
  Bit 9:  LOG_EXPORT         — exportar datos (CSV, PDF, Excel)
  Bit 10: LOG_IMPORT         — importar datos desde fuente externa
  Bit 11: LOG_PRINT          — imprimir documentos
  Bit 12: LOG_SHARE          — compartir registros con otros usuarios
  Bit 13: LOG_DELEGATE       — delegar permisos temporalmente
  Bit 14: LOG_RECOVER        — recuperar acceso o credencial
  Bit 15: LOG_EMIT           — emitir documentos con efecto legal/fiscal

Zona 2 — Control de Sesión Digital (bits 16–23):
  Bit 16: LOG_SESSION_ACTIVE — sesión digital válida y activa en este nodo
  Bit 17: LOG_SHELL_UNLOCK   — shell de Fedora desbloqueado
  Bit 18: LOG_MFA_ACTIVE     — MFA verificado en esta sesión
  Bit 19: LOG_CONCURRENT     — múltiples sesiones simultáneas permitidas
  Bit 20: LOG_OFFLINE_MODE   — operación offline autorizada
  Bit 21: LOG_VPN_REQUIRED   — requiere VPN para acceder
  Bit 22: LOG_INTERNET_EXT   — internet externo autorizado
  Bit 23: LOG_USB_STORAGE    — USB de almacenamiento autorizado

Zona 3 — Soberanía Lógica (bits 24–31):
  Bits 24–31: LOG_CUSTOM     — definibles por el admin del tenant

══════════════════════════════════════════════════════════════════════
Q2: DOMINIO FÍSICO (bits 32–63) — lo mitad alta
    "¿Dónde puede estar y qué puede activar este actor?"
══════════════════════════════════════════════════════════════════════
Zona 1 — Nivel de Seguridad de Zona (bits 32–35):
  Bit 32: PHY_SECURITY_LEVEL_1 — zonas públicas (lobby, cafetería)
  Bit 33: PHY_SECURITY_LEVEL_2 — zonas de empleados (ventas, admin)
  Bit 34: PHY_SECURITY_LEVEL_3 — zonas restringidas (sala servidores)
  Bit 35: PHY_SECURITY_LEVEL_4 — zonas críticas (bóveda, data center)

Zona 2 — Zonas Físicas Específicas (bits 36–47):
  Bits 36–47: PHY_ZONE_CUSTOM — definibles por el admin (árbol de ubicaciones)
              Cada bit = una zona física en el árbol jerárquico de 11 niveles
              La location ficha YAML resuelve zone_id → bit asignado

Zona 3 — Actuadores y Dispositivos (bits 48–55):
  Bit 48: PHY_DRAWER_OPEN    — activar relé cajón de dinero
  Bit 49: PHY_TERMINAL_POS   — habilitar terminal punto de venta
  Bit 50: PHY_PRINT_PHYSICAL — imprimir documentos físicos
  Bit 51: PHY_CAMERA_VIEW    — visualizar feeds de cámaras
  Bit 52: PHY_ALARM_MANAGE   — gestionar alarmas físicas
  Bit 53: PHY_KIOSK_MODE     — activar modo kiosko en terminal
  Bit 54: PHY_REMOTE_OPEN    — abrir puertas remotamente
  Bit 55: PHY_RESERVED       — reservado

Zona 4 — Control de Presencia (bits 56–63):
  Bit 56: PHY_CHECKIN           — registrar entrada al local
  Bit 57: PHY_CHECKOUT          — registrar salida del local
  Bit 58: PHY_SCHEDULE_EXT      — presencia fuera de horario habitual
  Bit 59: PHY_BIOMETRIC_VALID   — biométrico verificado en este acceso
  Bits 60–63: PHY_CUSTOM_PRES   — definibles por el tenant

══════════════════════════════════════════════════════════════════════
Q3: DOMINIO FINANCIERO (bits 64–95) — hi mitad baja
    "¿Qué operaciones transaccionales puede ejecutar este actor?"
══════════════════════════════════════════════════════════════════════
Zona 1 — Verbos Financieros (bits 64–79):
  Bit 64: FIN_SALE_CREATE       — crear venta / cobro
  Bit 65: FIN_SALE_APPROVE      — aprobar venta (SoD: ≠ FIN_SALE_CREATE)
  Bit 66: FIN_PAYMENT_CREATE    — crear pago / egreso
  Bit 67: FIN_PAYMENT_APPROVE   — aprobar pago (SoD: ≠ FIN_PAYMENT_CREATE)
  Bit 68: FIN_INVOICE_EMIT      — emitir factura electrónica (SIAT/AFIP/SAT)
  Bit 69: FIN_INVOICE_VOID      — anular factura (SoD: ≠ quien emitió)
  Bit 70: FIN_REFUND_CREATE     — crear devolución / nota de crédito
  Bit 71: FIN_REFUND_APPROVE    — aprobar devolución
  Bit 72: FIN_TRANSFER_LOCAL    — transferencia interna entre cuentas
  Bit 73: FIN_TRANSFER_EXTERNAL — transferencia bancaria externa
  Bit 74: FIN_PAYROLL_INPUT     — ingresar datos de nómina
  Bit 75: FIN_PAYROLL_APPROVE   — aprobar nómina (SoD: ≠ FIN_PAYROLL_INPUT)
  Bit 76: FIN_PERIOD_CLOSE      — cerrar período contable (LoA 4 requerido)
  Bit 77: FIN_REPORT_FISCAL     — generar reporte fiscal
  Bit 78: FIN_CAJA_OPEN         — apertura de caja
  Bit 79: FIN_CAJA_AUDIT        — auditoría de caja (SoD: ≠ FIN_CAJA_OPEN)

Zona 2 — Límites y Umbrales (bits 80–87):
  Bits 80–83: FIN_LIMIT_TIER    — nivel de límite transaccional
    0000 = Tier 0 (sin operaciones financieras)
    0001 = Tier 1 (hasta 1.000 BOB/ARS/MXN)
    0010 = Tier 2 (hasta 10.000)
    0100 = Tier 3 (hasta 50.000)
    1000 = Tier 4 (hasta 200.000)
    1111 = Tier 5 (sin límite — solo dirección y admin financiero)
  Bits 84–87: FIN_APPROVAL_LEVEL — nivel de aprobación que puede otorgar

Zona 3 — Auditoría Financiera (bits 88–95):
  Bit 88: FIN_SOD_ACTIVE     — usuario opera bajo restricciones SoD
  Bit 89: FIN_DUAL_CONTROL   — operaciones requieren segundo aprobador
  Bit 90: FIN_TIMESTAMP_SEAL — cada transacción genera sello inmutable
  Bit 91: FIN_PO_CREATE      — solicitar órdenes de compra
  Bit 92: FIN_PO_APPROVE     — aprobar órdenes de compra (SoD: ≠ FIN_PO_CREATE)
  Bits 93–95: FIN_CUSTOM     — definibles por el tenant / sector

══════════════════════════════════════════════════════════════════════
Q4: SOBERANÍA Y AUDITORÍA (bits 96–127) — hi mitad alta
    "¿Quién es este actor, qué LoA tiene, qué rastro deja?"
══════════════════════════════════════════════════════════════════════
Zona 1 — Nivel de Autoridad del Rol (bits 96–103):
  Bits 96–99:  GOV_LOA_LEVEL  — Level of Assurance de la sesión
    0000 = LoA 0 (sin autenticación)
    0001 = LoA 1 (contraseña simple)
    0010 = LoA 2 (contraseña + OTP / MFA)
    0100 = LoA 3 (contraseña + WebAuthn / biométrico digital)
    1000 = LoA 4 (WebAuthn + quórum de aprobadores)
  Bits 100–103: GOV_ROLE_TIER — jerarquía del rol en la organización
    0001 = Operativo (cajero, vendedor, operador)
    0010 = Supervisor (jefe de área)
    0100 = Gerencia media (director de área)
    1000 = Dirección / C-Level (CEO, CFO, CTO)

Zona 2 — Auditoría Forzada (bits 104–111):
  Bit 104: GOV_AUDIT_ALL      — TODAS las acciones de este actor auditadas
  Bit 105: GOV_AUDIT_FINANCE  — acciones financieras auditadas (nivel extra)
  Bit 106: GOV_AUDIT_ACCESS   — accesos físicos auditados
  Bit 107: GOV_AUDIT_CONFIG   — cambios de configuración auditados
  Bit 108: GOV_IMMUTABLE_LOG  — logs de este actor son inmutables
  Bit 109: GOV_ALERT_HIGH     — acciones generan alertas Wazuh HIGH
  Bit 110: GOV_NORMATIVE_BO   — cumplimiento normativa Bolivia (SIAT)
  Bit 111: GOV_NORMATIVE_PCI  — cumplimiento PCI-DSS activo

Zona 3 — Identidad Especial (bits 112–127):
  Bit 112: GOV_IS_SUPERUSER   — Superusuario (Q1-Q3 en 0 por defecto)
  Bit 113: GOV_CONTEXT_ACTIVE — Asunción de contexto activa
  Bit 114: GOV_IS_MACHINE     — Service account (no humano)
  Bit 115: GOV_EMERGENCY      — Acceso de emergencia activo (rompe SoD)
  Bit 116: GOV_DELEGATE_ACTIVE— Delegación temporal activa
  Bit 117: GOV_BIOMETRIC_REQ  — Este rol requiere biométrico obligatorio
  Bit 118: GOV_STEP_UP_PENDING— Step-up de LoA pendiente en esta sesión
  Bits 119–127: GOV_CUSTOM    — reservados / definibles por tenant
```

### 8.3 Implementación Go — Motor Algebraico Completo

```go
// sam128.go — SKULL · SBOS · bAuth
// Sovereign Authority Matrix de 128 bits
// Compatible con net/netip/uint128.go del stdlib de Go
package sam128

// SAM128 — struct{ lo, hi uint64 }
// lo = bits 0-63:  Q1 (Lógico 0-31) + Q2 (Físico 32-63)
// hi = bits 64-127: Q3 (Financiero 64-95) + Q4 (Soberanía 96-127)
type SAM128 struct {
    lo uint64
    hi uint64
}

// HasPermission — O(1), ~0.45 ns/op, zero allocations
func (s SAM128) HasPermission(bit int) bool {
    if bit < 64 { return s.lo & (1<<uint(bit)) != 0 }
    return s.hi & (1<<uint(bit-64)) != 0
}

// Grant — inmutable, devuelve nueva instancia
func (s SAM128) Grant(bit int) SAM128 {
    if bit < 64 { return SAM128{lo: s.lo | (1<<uint(bit)), hi: s.hi} }
    return SAM128{lo: s.lo, hi: s.hi | (1<<uint(bit-64))}
}

// Revoke — AND NOT (operador correcto para revocación — NUNCA NAND)
func (s SAM128) Revoke(bit int) SAM128 {
    if bit < 64 { return SAM128{lo: s.lo &^ (1<<uint(bit)), hi: s.hi} }
    return SAM128{lo: s.lo, hi: s.hi &^ (1<<uint(bit-64))}
}

// IsZero — optimización del compilador Go
func (s SAM128) IsZero() bool { return s.hi|s.lo == 0 }

// HexString — serialización para JWT (32 chars, ~50 bytes en JSON)
func (s SAM128) HexString() string {
    return fmt.Sprintf("0x%016X%016X", s.hi, s.lo)
}

// ─── OPERACIONES SOBRE ROLES ──────────────────────────────────────────────

// MergeRoles — OR — Unión de roles (pre-condición: Conflict Matrix verificada ANTES)
// Uso: usuario asume dos roles simultáneamente
func MergeRoles(a, b SAM128) SAM128 {
    return SAM128{lo: a.lo | b.lo, hi: a.hi | b.hi}
}

// InheritFromParent — AND NOT — H-RBAC: hijo hereda MENOS que el padre
// Uso: RolTemplate hijo hereda del padre menos los bits explícitamente removidos
// NUNCA usar XOR — XOR puede otorgar permisos involuntariamente
func InheritFromParent(parent, bitsToRemove SAM128) SAM128 {
    return SAM128{lo: parent.lo &^ bitsToRemove.lo, hi: parent.hi &^ bitsToRemove.hi}
}

// DelegateWithMinPrivilege — AND — Delegación con mínimo privilegio
// Uso: Gerente delega a Cajero → resultado es la INTERSECCIÓN de sus permisos
func DelegateWithMinPrivilege(grantor, delegatee SAM128) SAM128 {
    return SAM128{lo: grantor.lo & delegatee.lo, hi: grantor.hi & delegatee.hi}
}

// RevokeEmergency — AND NOT — KillSwitch en emergencia
// Uso: brecha de seguridad → revocar bits específicos en todos los usuarios
// NUNCA usar NAND — NAND puede otorgar permisos involuntariamente
func RevokeEmergency(current, toRevoke SAM128) SAM128 {
    return SAM128{lo: current.lo &^ toRevoke.lo, hi: current.hi &^ toRevoke.hi}
}

// ─── EJEMPLO: ROL_CAJERO en nodo "Ventas-01" ─────────────────────────────
var ROL_CAJERO = SAM128{
    lo: (1<<1)  | // LOG_WRITE (crear ventas)
        (1<<4)  | // LOG_EXECUTE (ejecutar proceso)
        (1<<11) | // LOG_PRINT (imprimir tickets)
        (1<<17) | // LOG_SHELL_UNLOCK (shell desbloqueado)
        (1<<33) | // PHY_SECURITY_LEVEL_2 (zona empleados)
        (1<<48) | // PHY_DRAWER_OPEN (cajón de dinero)
        (1<<49),  // PHY_TERMINAL_POS (terminal POS)
    hi: (1<<(64-64)) | // FIN_SALE_CREATE (crear ventas)
        (1<<(68-64)) | // FIN_INVOICE_EMIT (emitir facturas)
        (1<<(78-64)) | // FIN_CAJA_OPEN (abrir caja)
        (2<<(80-64)) | // FIN_LIMIT_TIER = 0010 → Tier 2 (10.000 BOB)
        (1<<(88-64)) | // FIN_SOD_ACTIVE
        (2<<(96-64)) | // GOV_LOA_LEVEL = 0010 → LoA 2
        (1<<(100-64))| // GOV_ROLE_TIER = 0001 → Operativo
        (1<<(105-64)), // GOV_AUDIT_FINANCE (acciones financieras auditadas)
}
```

### 8.4 Serialización en JWT

```json
{
  "sub": "uuid-cajero",
  "preferred_username": "ivan.cajero",
  "realm_access": {"roles": ["ROL_CAJERO"]},

  "bos_sam128": "0x0000020900010052 0001001700010052",

  "bos_context": {
    "zone_logical": {
      "ventas":     ["READ", "WRITE", "EXECUTE"],
      "facturacion":["READ", "WRITE", "EMIT"],
      "vdi":        ["READ", "EXECUTE"]
    },
    "zone_physical": {
      "pos_caja":    ["EXECUTE", "OPEN"],
      "zone_ventas": ["ACCESS"]
    },
    "zone_financial": {
      "ventas":    ["CREATE"],
      "caja":      ["OPEN", "CLOSE"],
      "factura":   ["EMIT"],
      "limit_tier": 2,
      "daily_limit": 10000,
      "currency":   "BOB",
      "sod_active": true
    },
    "zone_network": {
      "allowed_networks": ["10.0.1.0/24"],
      "internet": "DENY"
    },
    "zone_compliance": {
      "jurisdiction": "BO",
      "siat_active":  true,
      "audit_log":    true
    }
  },

  "bos_governance": {
    "loa_level":        2,
    "role_tier":        "operativo",
    "role_valid_until": "2027-01-01",
    "sod_active":       true,
    "is_superuser":     false,
    "audit_finance":    true
  },

  "bos_node_id":          "Ventas-01",
  "bos_template_version": "2.1.0",
  "acr": "2",
  "amr": ["pwd", "otp"]
}
```

---

## 9. LAS 6 CAPAS DE RESOLUCIÓN DE CONTEXTO

Las 6 capas no son capas dentro del entero de bits — son niveles de resolución de contexto. Cada capa externa limita el espacio de posibilidades de la capa más interna.

```
CAPA 1 — TENANT (Soberanía de Infraestructura)
  Implementación: Servidor Ubuntu + IAM Installer (bos)
  Control: sbos-admin (Ivan Villanueva)
  Garantía: un tenant no puede ver módulos de otro tenant
  Pregunta: "¿Existe este módulo en este servidor SBOS?"

CAPA 2 — EMPRESA (Soberanía de Datos)
  Implementación: Realm Keycloak — un realm por empresa (NIT)
  Control: admin-cliente del realm (via Core UI)
  Garantía: datos de Empresa A son inaccesibles para Empresa B,
            aunque compartan el mismo servidor (Capa 1)
  Pregunta: "¿A qué empresa pertenece este usuario?"

CAPA 3 — ROL (Soberanía Operativa)
  Implementación: RolTemplate en bos_bauth_template → bAuth → KC Composite Role
  Control: Admin TI de la empresa (via Core UI + bAuth)
  Pregunta: "¿Qué puede hacer un Contador vs un Gerente?"

CAPA 4 — APLICACIÓN (Soberanía de Contexto)
  Implementación: client_id KC + zones.applications del RolTemplate
  Control: bAuth configura qué apps tiene el rol habilitadas
  Garantía: permisos de zone_logical/ventas no se filtran a zone_logical/rrhh
  Nota: NO es "VDI" o "ERP" — es cualquiera de las 100+ apps del SBOS.
        Cada app tiene su propio client_id en KC.
  Pregunta: "¿En qué aplicación está operando y qué zonas tiene habilitadas?"

CAPA 5 — ZONA (Dimensión de Actuación)
  Implementación: bits Q1 (lógico) y Q2 (físico) del SAM-128
  Control: bAuth calcula desde el RolTemplate
  Pregunta: "¿En qué espacio o contexto puede actuar?"

CAPA 6 — SAM-128 (Vector de Ejecución)
  Implementación: registro de 128 bits calculado por PrivilegeEngine
  Control: motor algebraico de bAuth (inmutable para el actor)
  Es la materialización computacional de las 5 capas anteriores.
  banexus lo evalúa localmente O(1) sin consultar al servidor.
  Pregunta: "¿Tiene ESTE bit específico activo?"
```

---

## 10. EL FLUJO DE SINCRONIZACIÓN MAESTRO

```
PASO 1  Admin edita RolTemplate en Core UI (PAP) → Guardar

PASO 2  Core UI → bAuth REST API: PUT /api/v1/roltemplate/{id}
        bAuth valida: schema JSON, Conflict Matrix, SoD, herencia jerárquica
        Si FAIL → 422 con descripción exacta del error
        Todo se detiene aquí si hay error — nada se propaga

PASO 3  bAuth escribe en bos_bauth_template (PostgreSQL JSONB)
        Columnas normalizadas actualizadas: status, sam128_lo, sam128_hi
        PostgreSQL genera evento WAL

PASO 4  bkernel detecta WAL → regla ROLF-001 → activa bauth_sync
        Publica en Redis: bkernel:identity_events
        {type: "roltemplate_changed", role_id: "RGV-001"}

PASO 5  bauth.service consume Redis → PrivilegeEngine.calculate(role_id)
        Si hay parent_id: aplica InheritFromParent() con AND NOT
        Produce SAM-128 final + bos_context completo

PASO 6  KeycloakSynchronizer.sync_role() — KC Admin API REST:
        → Composite Role (nombre canónico del rol)
        → Realm roles atómicos (1 por bit activo del SAM)
        → Authentication Flow (métodos requeridos del RolTemplate)
        → User Attributes: allowed_networks, session_max, loa_required,
                           financial_limit_tier, role_valid_until
        → Session Settings: duración, concurrencia, LoA step-up

PASO 7  TrytonSynchronizer.sync_groups() — Tryton XML-RPC:
        → ir.model.access (CRUD por modelo — del campo model_access)
        → ir.rule.group (Record Rules generadas del campo record_rules)
        → ir.model.button (Button Rules generadas del campo button_rules)
        → ir.action.groups (menús del campo visible_actions)
        → ir.model.field.access (campos del campo field_restrictions)

PASO 8  AppSynchronizer.sync_apps() [cuando adaptador disponible]:
        Para cada app declarada en zones.*.applications con adaptador:
        → Sincroniza roles internos via API de la app específica

PASO 9  bkernel registra en bkernel_db.audit_events (inmutable, ISO 27001 A.8.15)
        {role_id, changed_by, old_version, new_version, timestamp}

PASO 10 bauth actualiza: sync_status = 'SYNCED', last_sync_at = now()

PASO 11 bAuth → bhnexus (Unix socket): policy_update push
        {type: "policy_update", affected_roles: ["RGV-001"],
         affected_users: ["user-uuid-1", "user-uuid-2"],
         action: "invalidate_cache"}
        bhnexus invalida SAM-128 en cache
        bhnexus → banexus en nodos afectados: invalida cache efímero

TIEMPO TOTAL PASO 2 → PASO 10: < 5 segundos
```

---

## 11. LA INTERFAZ DE BAUTH

### REST API (Core UI → PAP)

```
POST   /api/v1/roltemplate               Crear RolTemplate (valida + persiste)
PUT    /api/v1/roltemplate/{id}          Actualizar (crea nueva versión + trigger sync)
DELETE /api/v1/roltemplate/{id}          Deprecar RolTemplate
GET    /api/v1/roltemplate               Listar (filtros: tenant, empresa, status)
GET    /api/v1/roltemplate/{id}          Obtener + historial de versiones

POST   /api/v1/usertemplate              Onboarding de usuario
PUT    /api/v1/usertemplate/{id}         Actualizar (cambio de rol, datos)
DELETE /api/v1/usertemplate/{id}         Offboarding (status → TERMINATED)

POST   /api/v1/authorize/logical         Evaluar acceso lógico
POST   /api/v1/authorize/financial       Pre-validar operación financiera
GET    /api/v1/authorize/biometric/{id}  Verificar hash biométrico

POST   /api/v1/biometric/enroll          Iniciar enrolamiento biométrico
PUT    /api/v1/biometric/verify/{id}     Admin aprueba enrolamiento (policy hybrid)

GET    /api/v1/sync/status               Estado de sincronización global
GET    /api/v1/sync/drift                Roles con drift detectado
POST   /api/v1/sync/resync/{id}          Re-sincronizar un rol específico
POST   /api/v1/sync/resync-all           Re-sincronizar realm completo

GET    /api/v1/audit                     Historial de auditoría
GET    /api/v1/health                    Estado del daemon
```

### Unix Socket (bhnexus → evaluación en tiempo real)

```go
// /run/bos/bauth.sock — protocolo interno
// Latencia: < 5ms (cache Redis hit: < 1ms)

type AuthQuery struct {
    UserID    string `json:"user_id"`
    NodeID    string `json:"node_id"`       // "Ventas-01"
    QueryType string `json:"query_type"`    // bitmask|zone_verb|financial|biometric
    Zone      string `json:"zone,omitempty"`
    Verb      string `json:"verb,omitempty"`
}

type AuthResponse struct {
    Granted    bool   `json:"granted"`
    SAM128     string `json:"sam128,omitempty"`    // hex string
    BosContext string `json:"bos_context,omitempty"`
    Reason     string `json:"reason,omitempty"`
    TTL        int    `json:"ttl_seconds"`
}
```

---

## 12. LOS 3 NIVELES DE INTEGRACIÓN DE APLICACIONES

```
NIVEL A — OIDC/SAML NATIVO
  Tryton, Nextcloud, Rocket.Chat, Mattermost, Grafana, Superset,
  Paperless-ngx, OnlyOffice, GitLab CE, Zammad, EspoCRM, Saleor
  v1.0: KC gobierna acceso (¿puede entrar?). App gestiona roles internos.
  v1.x: bAuth sincroniza roles internos de la app via adaptador específico.

NIVEL B — OAUTH2-PROXY
  PgAdmin 4, FreePBX, Zabbix (parcial), Portainer CE
  OAuth2-Proxy actúa como capa de auth transparente delante de la app.
  La app no sabe de Keycloak — solo recibe el request autenticado.

NIVEL C — TRANSICIONAL (a estudiar post-instalación)
  OrangeHRM, Easy!Appointments, TastyIgniter, GNU Health, Xibo
  v1.0: KC via OAuth2 como mínimo. App autónoma en roles internos.
  v1.x: análisis post-instalación → adaptador específico → bAuth coordina.
```

**Principio absoluto:** KC gobierna el acceso a TODAS las apps desde el primer día.
OAuth2 es el estándar mínimo. La coordinación de roles internos se implementa por fases.

---

## 13. DRIFT DETECTION Y AUTO-CORRECCIÓN

bAuth ejecuta un reconcile loop cada 60 segundos sobre todos los RolTemplates ACTIVE:

```
1. Leer estado declarado en bos_bauth_template (PostgreSQL)
2. Leer estado real en KC (Admin API: GET /groups/{id})
3. Leer estado real en Tryton (SQL: SELECT * FROM ir_model_access WHERE group_id=...)

Si hay DRIFT:
  → sync_status = 'DRIFT'
  → Alerta Wazuh WARNING: "identity_drift_detected"
  → Re-sincronizar inmediatamente (idempotente: si ya está correcto → cero llamadas API)
  → Registrar en bkernel_db.audit_events

Si delegación vencida no revocada:
  → Wazuh CRITICAL: "DELEGACION_VENCIDA_NO_REVOCADA"
  → Auto-revocar delegación
  → Notificar admin del tenant
```

---

## 14. LA CONFLICT MATRIX — SEGREGACIÓN DE FUNCIONES

Evaluada por bAuth ANTES de guardar cualquier RolTemplate. Si viola → 422 Unprocessable Entity con descripción exacta.

```go
var SoDConflicts = []SoDRule{
  {ZoneA:"zone_financial/nomina",      VerbA:"INPUT",
   ZoneB:"zone_financial/nomina",      VerbB:"APPROVE",     Severity:"critical"},
  {ZoneA:"zone_financial/pago",        VerbA:"CREATE",
   ZoneB:"zone_financial/pago",        VerbB:"APPROVE",     Severity:"critical"},
  {ZoneA:"zone_financial/caja",        VerbA:"OPEN",
   ZoneB:"zone_financial/caja",        VerbB:"AUDIT",       Severity:"critical"},
  {ZoneA:"zone_financial/factura",     VerbA:"EMIT",
   ZoneB:"zone_financial/factura",     VerbB:"VOID",        Severity:"critical"},
  {ZoneA:"zone_logical/contabilidad",  VerbA:"WRITE",
   ZoneB:"zone_financial/auditoria",   VerbB:"AUDIT",       Severity:"critical"},
  {ZoneA:"zone_financial/compra",      VerbA:"CREATE",
   ZoneB:"zone_financial/compra",      VerbB:"APPROVE",     Severity:"critical"},
  {ZoneA:"zone_financial/payroll",     VerbA:"INPUT",
   ZoneB:"zone_financial/payroll",     VerbB:"APPROVE",     Severity:"critical"},
}
```

También se verifica en Tryton vía Button Rules generadas automáticamente por bAuth desde el campo `button_rules.sod_cannot_also` del RolTemplate.

---

## 15. PRESENTACIÓN DE IDENTIDAD FÍSICA

bAuth es el origen de verdad de la identidad física. bhnexus ejecuta la validación. banexus captura el evento.

### QR Dinámico

```
Generación (bAuth):
  URI: sbos://auth/{user_uuid}/{timestamp_unix}/{HMAC-SHA256(vault_key, user+ts)}
  TTL: 30 segundos (configurable en RolTemplate)
  Uso: Core UI genera → muestra en pantalla → usuario escanea

Validación (bhnexus):
  1. Extraer user_uuid, timestamp, hmac del URI
  2. Verificar: now() - timestamp < 30s (dentro del TTL)
  3. Recalcular HMAC con clave de Vault
  4. Comparar HMAC calculado vs HMAC recibido
  5. Si OK → consultar bAuth via Unix socket: user_uuid → SAM-128
```

### NFC / RFID

```
Tag NFC DESFire:
  Contenido: user_uuid cifrado con AES-128 (clave rotada cada 90 días en Vault)
  banexus lee tag → payload cifrado → bhnexus descifra → user_uuid
  bhnexus → bAuth (Unix socket): user_uuid → SAM-128

RFID 125kHz legacy:
  Solo card_number sin cifrado (Wiegand — seguridad baja)
  bhnexus busca card_number en tabla de mapeo → user_uuid
  bhnexus → bAuth: user_uuid → SAM-128
```

### Biométrico (hash — nunca raw biometric)

```
Lector OSDP Biometric Profile:
  1. Sensor captura imagen localmente
  2. Template extraído en el chip del lector (enclave seguro)
  3. Hash PBKDF2-SHA256 calculado LOCALMENTE en el chip
  4. Hash transmitido por OSDP Secure Channel (AES) a bhnexus
  5. bhnexus → bAuth: {query_type:"biometric", hash:"<hash>", device_id:"..."}
  6. bAuth: compara hash vs bauth_biometric_templates
  7. Match → user_uuid → SAM-128 con GOV_LOA_LEVEL = LoA 3

INVARIANTE: raw biometric NUNCA sale del chip del lector.
GDPR: cero datos biométricos en ningún servidor SBOS.
```

---

## 16. EL SUPERUSUARIO Y ASSUMERTENANTCONTEXT

**En reposo:** solo el bit `GOV_IS_SUPERUSER` (bit 112) activo. Q1+Q2+Q3 en cero — cero bits operativos. Mínimo privilegio en reposo.

**Asunción de contexto de tenant:**

```go
type TenantContext struct {
    ContextID string
    AdminID   string    // sbos-admin uuid
    RealmID   string    // empresa que se asume
    Reason    string    // obligatorio — justificación de negocio
    ExpiresAt time.Time // no puede ser permanente
}
```

Toda asunción genera:
- Alerta HIGH en Wazuh SIEM
- Entrada INMUTABLE en `bkernel_db.audit_events`
- Notificación al admin del tenant afectado
- TTL obligatorio — no puede ser permanente ni abierto

---

## 17. COORDINACIÓN CON NEXUS

```
TOPOLOGÍA INVARIABLE:
  banexus → bhnexus → bAuth
  NUNCA:  banexus → bAuth directamente

LATENCIAS:
  Cache hit bhnexus:    < 2ms  (sin consultar bAuth)
  Cache miss → bAuth:   < 8ms  (Unix socket)
  Evento físico total:  < 50ms (banexus → bhnexus → bAuth → actuador)
  Policy update push:   < 5s   (bAuth → bhnexus → banexus)

CUANDO ROLTEMPLATE CAMBIA:
  bAuth → bhnexus: policy_update push
  bhnexus: invalida SAM-128 en cache de usuarios afectados
  bhnexus → banexus: invalida cache efímero
  Tiempo total: < 5 segundos desde guardar hasta invalidación en nodo
```

---

## 18. LA JURISDICCIÓN REGIONAL (Dominio Normativo)

Declarada en el seed file al crear el tenant. Activa automáticamente los estándares regionales. Las excepciones son permitidas — sugerencia modificable, no regla bloqueada.

```yaml
# deploy.yml — seed file
tenant:
  jurisdiction: "BO"    # → currency: BOB, IVA: 13%, IT: 3%
                        # → SIAT conector activo
                        # → retención logs: 10 años
                        # → timezone: America/La_Paz

  # Excepciones válidas — no bloquean la config base
  jurisdiction_overrides:
    currency: "USD"     # empresa que opera en dólares internamente
```

**Jurisdicciones v1.0:** BO (Bolivia/SIAT), AR (Argentina/AFIP), MX (México/SAT).

Materialización en SAM-128: `GOV_NORMATIVE_BO` (bit 110) activo para todos los usuarios del tenant.

---

## 19. LO QUE BAUTH ES Y NO ES

| bAuth ES | bAuth NO ES |
|---|---|
| El sistema de identidad del SBOS | Un componente más del stack |
| El coordinador KC ↔ Tryton ↔ apps | Un plugin de Keycloak |
| La fuente de verdad sincronizada | Un reemplazo de Keycloak |
| El evaluador de privilegios en tiempo real | El PDP en login time (eso es KC) |
| El generador del SAM-128 y bos_context | El cifrador de datos en reposo |
| El guardián del SoD y cumplimiento | Una dependencia crítica en el login |
| El único punto de administración (PAP) | Un sistema que existe sin RolTemplate |
| El que genera Button Rules en Tryton | Quien decide las políticas (eso es el admin) |

---

## 20. GLOSARIO TÉCNICO

| Término | Definición |
|---|---|
| **ACR** | Authentication Context Reference. Valor que describe el nivel de autenticación. |
| **AMR** | Authentication Method Reference (RFC 8176). Array de métodos usados. |
| **AND NOT** | `A & ~B`. Operación para herencia jerárquica H-RBAC y revocación. Nunca usar NAND. |
| **bos_context** | Claim JWT con representación semántica completa de zonas × verbos del actor. |
| **bos_sam128** | Claim JWT con el registro SAM-128 en hex string (32 chars). |
| **Button Rule** | Regla en Tryton (`ir.model.button`) con condición PYSON. Generada por bAuth. |
| **Composite Role** | Rol en KC que contiene otros realm roles atómicos. Creado por bAuth. |
| **Drift** | Estado donde KC o Tryton divergen de lo que define `bos_bauth_template`. |
| **H-RBAC** | Hierarchical RBAC (ANSI/INCITS 359-2004). Herencia con AND NOT. |
| **Idempotencia** | Si el estado ya es correcto en KC/Tryton → cero llamadas API. |
| **JWT** | JSON Web Token. Firmado con RSA-256 por KC. Validado con JWKS sin llamadas a KC. |
| **LoA** | Level of Assurance. Nivel 1–4 de seguridad de la autenticación. |
| **Nombre Canónico** | Identificador único como Composite Role en KC y Grupo en Tryton. |
| **PAP** | Policy Administration Point. Core UI del SBOS. |
| **PDP** | Policy Decision Point. KC (login) + bAuth (operación) + Tryton (enforcement). |
| **PEP** | Policy Enforcement Point. Tryton (5 capas) + OAuth2-Proxy + banexus. |
| **PIP** | Policy Information Point. `bos_bauth_template` en PostgreSQL. |
| **PrivilegeEngine** | Motor algebraico de bAuth que calcula el SAM-128 desde el RolTemplate. |
| **PYSON** | Lenguaje de expresiones de Tryton. Evaluado en tiempo real en el servidor. |
| **Record Rule** | `ir.rule` en Tryton: filtros SQL automáticos por grupo. Generada por bAuth. |
| **Realm Role** | Rol atómico en KC. Cada bit activo del SAM = un realm role. |
| **RolTemplate** | Contrato técnico y organizacional de un rol empresarial. Fuente de verdad única. |
| **SAM-128** | Sovereign Authority Matrix. Registro de 128 bits evaluable en O(1). |
| **SoD** | Separation of Duties. Nadie ejecuta de punta a punta una operación crítica. |
| **SPI** | Service Provider Interface de KC. Extensión via JARs en `/opt/keycloak/providers/`. |
| **Step-up** | RFC 9470. El recurso requiere LoA superior sin interrumpir la sesión completa. |
| **UserTemplate** | Contrato de un usuario concreto: credenciales, rol asignado, datos personales. |

---

## 21. PENDIENTES — TODOS CERRADOS

| # | Pendiente | Decisión |
|---|---|---|
| P1 | Tamaño SAM | ✅ 128 bits — `struct{lo, hi uint64}` — sin dependencias externas |
| P2 | Namespacing de zonas | ✅ `zone_logical/facturacion` — jerárquico con prefijo de dominio |
| P3 | LogicalDomainEvaluator | ✅ Dentro de bAuth como endpoint REST `/api/v1/authorize/logical` |
| P4 | SoD financiero | ✅ Todo declarado en RolTemplate → bAuth genera Button Rules en Tryton |
| P5 | zone_application_map | ✅ Dentro del RolTemplate.zones. Motor valida solo `app` en v1.0 |
| P6 | Biométrico | ✅ HAL agnóstica + biometric_enrollment_policy (admin_only/self_service/hybrid) |
| P7 | bos_bitmask legacy | ✅ Corte limpio — `bos_sam128` desde v1.0 |
| P8 | Access Review cadencia | ✅ Configurable por tenant (MONTHLY/QUARTERLY/SEMIANNUAL/ANNUAL) |
| P9 | Jurisdicción | ✅ seed file → efecto dominó automático + excepciones modificables |

---

*SKULL · SBOS · SBOS-BAUTH-CONCEPTUALIZACION · v4.0 · Abril 2026*
*Reemplaza: v1.0, v2.0, v3.0, SBOS-008 §7 y §8 completos*
*Todos los pendientes P1–P9 cerrados. Modelo de dominios y SAM-128 definitivos.*
*Integra: SBOS-009 (RolTemplate/UserTemplate completos), SBOS-019 (15 métodos + 5 SPIs),*
*SBOS-020 (JWT estructura completa), SBOS-008-001 (dominios + operaciones SAM)*
*SAM-128 motor algebraico completo con 7 operaciones Go*
*Estándares: NIST SP 800-63B/C, ISO/IEC 27001:2022, ANSI/INCITS 359-2004 H-RBAC,*
*PCI-DSS v4.0, NIST SP 800-53 AC-5, FIDO2/WebAuthn W3C, eIDAS, RGPD, SOX §404,*
*SIA OSDP v2.2.2 IEC 60839-11-5, W3C BOT, RFC 6749 OAuth2, RFC 8176 AMR*
