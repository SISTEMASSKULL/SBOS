# SBOS-022-IDENTITY-CONTRACTS
## Contratos de Identidad: RolTemplate + UserTemplate — Estándar HUMAN-DOC
### SKULL · SBOS · v1.3 · Abril 2026
### ENRIQUECIDO V8 — con V5 + V7 + Smart* Enrichment

---

## 1. Propósito

Los sistemas empresariales tradicionales definen privilegios de forma fragmentada: permisos en ERP, métodos auth en IdP, accesos físicos en control de acceso, horarios en RRHH. Cuatro sistemas sin relación formal. Cuando un empleado cambia de rol, el admin actúa en cuatro lugares. Inevitablemente, algunos quedan desactualizados.

El RolTemplate elimina esto: **la especificación completa de un rol empresarial existe en un solo lugar, un solo formato, y es fuente de verdad única para todos los sistemas del SBOS.**

### Garantías del sistema de contratos

- **Un cambio, propagación total:** modificar un campo → sincronización automática en todos los sistemas. Sin pasos manuales.
- **Auditoría completa:** cada versión en bkernel_db.audit_events. "¿Qué permisos tenía este rol en febrero?" → respuesta exacta.
- **Enforcement estructural:** permisos = configuraciones estructurales de KC y Tryton. Sin bypass por error de código.
- **Onboarding predecible:** empleado nuevo + RolTemplate asignado → entorno completo definido antes de que llegue.

---

## 2. RolTemplate vs UserTemplate — Separación de Responsabilidades

> **RolTemplate → ¿Qué PUEDE HACER un tipo de rol?**
> **UserTemplate → ¿Quién ES y qué TIENE un usuario concreto?**

| Dimensión | RolTemplate | UserTemplate |
|---|---|---|
| Granularidad | Categoría de persona | Persona concreta |
| Multiplicidad | 1 → muchos usuarios | 1 → 1 usuario |
| Quién modifica | Admin TI / RRHH | bauth (auto) + admin con aprobación |
| Cuándo se modifica | Cuando cambia política del rol | Cuando cambia el empleado |
| Sincroniza en KC | Auth Flows, Session Settings, User Attributes del rol | User record, credenciales, rol asignado |
| Sincroniza en Tryton | Grupos, ir.model.access, ir.action.groups, ir.model.button | res.user, company.employee, idioma |

### Lo que UserTemplate NO duplica

No contiene permisos, políticas MFA, horarios, ni restricciones geográficas (exclusivos del RolTemplate). Sí contiene: métodos registrados del usuario, rol asignado, datos personales/profesionales, estado sync, estado compliance.

### Regla de separación

```
RolTemplate define:
  availableMethods, requiredMethods, transaction_limits,
  temporal_control, geospatial_control, model_access,
  visible_actions, field_restrictions, button_rules, record_rules

UserTemplate define:
  keycloak_credentials (qué tiene registrado),
  roles_assignments, personal_info, professional_info,
  tryton_binding, credentials_compliance, sync_state
```

---

## 3. Ciclo de Vida del RolTemplate

### Estados

```
DRAFT → REVIEW → ACTIVE → DEPRECATED → ARCHIVED
         │                    │
         └── REJECTED         └── puede reactivarse como nueva versión
```

| Estado | Descripción | Editable |
|---|---|---|
| DRAFT | En diseño. No sincronizado. | Admin TI |
| REVIEW | En aprobación formal. Bloqueado. | Solo aprobadores |
| ACTIVE | Sincronizado en KC y Tryton. | Solo vía flujo de cambio |
| DEPRECATED | Reemplazado. Usuarios migrados. | Solo lectura |
| ARCHIVED | Solo auditoría histórica. | Solo lectura |

Modificación de ACTIVE: nunca directa. Se crea nueva versión DRAFT → al aprobar, anterior pasa a DEPRECATED. Historial completo en audit_events.

Detección vía bKernel: regla ROLF-001 activa plugin rolframework_sync al INSERT/UPDATE en bos_rol_template. Sync < 5 segundos.

---

## 4. Ciclo de Vida del UserTemplate

### Estados

| Estado | KC | Tryton | Descripción |
|---|---|---|---|
| ACTIVE | Habilitado | Habilitado | Operacional |
| INACTIVE | Deshabilitado | Deshabilitado | Ausencia temporal |
| SUSPENDED | Deshabilitado | Deshabilitado | Investigación seguridad |
| TERMINATED | Eliminado del realm | Deshabilitado (historial) | Fin relación laboral |

### Flujo de Onboarding de Usuario Nuevo

Cuando el admin crea un UserTemplate en Core UI y le asigna un RolTemplate, el sistema ejecuta el siguiente flujo de onboarding automático:

```
PASO 1 — Admin crea UserTemplate en Core UI con rol asignado
  → Core UI → POST /api/identity/usertemplates { username, email, role_id, ... }

PASO 2 — bAuth sincroniza en KC
  → Crea usuario en KC con atributos del RolTemplate asignado
    (allowed_days, shift_start, shift_end, allowed_networks, role_valid_until)
  → Asigna al Composite Role del rol en el realm del tenant
  → Estado inicial: email_verified = false, credentials_compliance = PENDING

PASO 3 — KC envía magic link al email del usuario
  → Token único de uso único con TTL de 24 horas
  → El link contiene: token + realm + acción = SET_CREDENTIALS

PASO 4 — Usuario accede al magic link → KC presenta formulario de activación:
  a. Cambio de contraseña obligatorio (forced: true en primer acceso)
  b. Registro del segundo factor según requiredMethods del RolTemplate:
     - Si requiredMethods incluye "2fa_app" → flujo OTP (QR + validación TOTP)
     - Si requiredMethods incluye "biometric_login" → WebAuthn enrollment
     - Si requiredMethods incluye "smart_card_logical" → X.509 registration
  c. Verificación de datos personales (nombre, teléfono, foto si aplica)

PASO 5 — KC marca email_verified = true al completar paso 4
  → KC emite evento user.first_login

PASO 6 — bAuth detecta email_verified = true vía WAL → recalcula credentials_compliance
  → Si el usuario cubrió todos los requiredMethods del rol:
       credentials_compliance = COVERED → acceso habilitado
  → Si el usuario NO registró algún método requerido:
       credentials_compliance = GAP → RolUserConfiguredCondition SPI bloquea acceso
       → KC muestra pantalla: "Debes registrar [método faltante] para continuar"

PASO 7 — Primer acceso exitoso → bKernel procesa evento keycloak.user.first_login
  → Provisiona buzón Postfix + Dovecot (email corporativo)
  → Crea canales en Rocket.Chat (canal del departamento)
  → bSearch indexa el usuario en el índice de empleados del realm
```

**Comportamiento del magic link:**
- TTL: 24 horas desde emisión
- Uso único: expira tras el primer click (no reutilizable)
- Si expira sin usar: admin puede regenerar desde Core UI (`bosctl bauth resend-invite {user_id}`)
- Si el usuario pierde el link: admin regenera, el link anterior se invalida automáticamente

**Casos especiales:**
- Usuario que ya tiene cuenta KC en otro realm del mismo servidor → se vincula via external provider mapping, sin nuevo magic link
- Usuario con smart_card ya registrada (empresa con PKI corporativa) → se omite el paso de registro de factor, se valida el certificado directamente
- Onboarding masivo (migración): se puede usar `bosctl bauth bulk-invite --file=usuarios.csv` para disparar el flujo para múltiples usuarios simultáneamente

**Comportamiento ante errores en el magic link:**

| Situación | Comportamiento del sistema |
|---|---|
| Usuario no recibe el email | Admin puede regenerar desde Core UI — el link anterior se invalida automáticamente al generar uno nuevo |
| Link TTL expirado (>24h) | Link inválido. Admin regenera con `bosctl bauth resend-invite {user_id}`. El usuario recibe un nuevo link; el anterior queda inutilizable. |
| Usuario hace click en link ya usado | KC retorna error `expired_code`. Usuario debe contactar al admin para reenvío. |
| Usuario completa contraseña pero no el factor MFA | KC mantiene `email_verified=false` hasta que complete el flujo completo. El acceso permanece bloqueado. |
| `requiredMethods` incluye método no disponible en el dispositivo | KC muestra la opción alternativa si existe en `alternativeMethods` del RolTemplate. Si no hay alternativa y la empresa no aprueba excepción, el acceso queda bloqueado hasta resolver. |
| Link usado desde IP no autorizada (RolGeoAuthenticator activo) | SPI bloquea el flujo antes de permitir el registro. Admin debe verificar si el usuario está en la red correcta antes de regenerar. |

**Relación con `credentials_compliance`:**

El campo `credentials_compliance` en el UserTemplate no es solo un indicador de estado — es la condición de acceso evaluada en cada login por el SPI `RolUserConfiguredCondition`:

| Valor | Condición | Efecto en acceso |
|---|---|---|
| `COVERED` | El usuario tiene registrados todos los factores que `requiredMethods` del RolTemplate exige | Acceso habilitado — el SPI permite el flujo de autenticación |
| `PENDING` | El usuario no ha completado el onboarding (magic link no usado o flujo incompleto) | SPI bloquea el login — KC muestra pantalla de "completa tu registro" |
| `GAP` | El usuario completó el onboarding pero un método requerido fue revocado, expiró, o el RolTemplate fue modificado añadiendo un nuevo `requiredMethod` | SPI bloquea el login — KC muestra pantalla indicando qué método falta registrar |

bAuth recalcula `credentials_compliance` automáticamente en cada ciclo de drift detection (cada 60 segundos). No es un campo que el admin edite manualmente — es consecuencia directa de comparar `keycloak_credentials` del UserTemplate con `requiredMethods` del RolTemplate asignado.

**Transición `PENDING` → `COVERED`:** ocurre cuando KC emite el evento `user.first_login` y bAuth verifica que todos los `requiredMethods` están cubiertos en `keycloak_credentials`.

**Transición `COVERED` → `GAP`:** ocurre cuando el admin modifica el RolTemplate añadiendo un nuevo `requiredMethod` que el usuario aún no tiene registrado. El usuario puede seguir usando el sistema con los factores actuales durante un período de gracia configurable (`gap_grace_period_hours` en el RolTemplate), tras el cual el SPI empieza a bloquear.

### Cambio de Rol

1. Admin actualiza active_roles en Core UI
2. bauth calcula diferencia entre rol anterior y nuevo
3. KC: mueve usuario al nuevo grupo, actualiza atributos
4. Tryton: actualiza grupos del res.user
5. Rol anterior → history con fecha remoción y motivo
6. Si nuevo rol requiere métodos no cubiertos → alerta admin + flujo de enrollment

### Drift Detection

Verificación periódica (default diaria) que KC y Tryton coinciden con UserTemplate. Drift con permisos de más → CRÍTICA + re-sync automática inmediata.

---

## 5. Proceso de Creación de RolTemplate Nuevo (6 pasos)

**Paso 1 — Definición organizacional (con RRHH/cliente):** funciones, módulos ERP, operaciones solas vs aprobación, horarios, ubicaciones, transacciones financieras.

**Paso 2 — Identificar jerarquía:** ¿hereda de padre? OR (hereda todo) o AND NOT (hereda menos explícitos). Hijo siempre ≤ padre.

**Paso 3 — Crear en Core UI:** id canónico, parent_id, logical_access (MFA, temporal, geo, session), tryton_privileges (5 capas), financial_transactions, validity_period, approval_workflow.

**Paso 4 — Prueba en staging:** usuario de prueba → verificar Auth Flow KC → verificar grupos/menús/accesos Tryton → probar operaciones críticas.

**Paso 5 — Aprobación formal:** DRAFT → REVIEW → aprobador confirma → bauth activa en producción.

**Paso 6 — Asignación a usuarios:** rol ACTIVE aparece en selector Core UI.

---

## 6. Catálogo Inicial de RolTemplates por Sector

### 6.1 Contabilidad

| Rol | LoA | Horario | Límite financiero |
|---|---|---|---|
| CON-JUN-001 Contador Junior | LoA 2 | L-V 08-18 | Sin aprobación pagos |
| CON-SEN-001 Contador Senior | LoA 3 | L-V 08-20 | Hasta USD 5,000 |
| CON-GER-001 Gerente Contabilidad | LoA 4 | L-V 07-22 | Hasta USD 50,000 |

### 6.2 Recursos Humanos

| Rol | LoA | Restricción clave |
|---|---|---|
| RRHH-REC-001 Reclutador | LoA 2 | Solo candidatos, sin nómina |
| RRHH-ANA-001 Analista | LoA 2 | Sin ver salarios (field_restriction) |
| RRHH-JEF-001 Jefe RRHH | LoA 3 | Step-up para nómina |

### 6.3 Ventas

| Rol | LoA | Geolocalización |
|---|---|---|
| VEN-VEN-001 Vendedor | LoA 2 | Oficina + VPN + clientes |
| VEN-SUP-001 Supervisor | LoA 2 (3 para descuento >20%) | Oficina + VPN |
| VEN-GER-001 Gerente Comercial | Ver Anexo A completo | Oficina + VPN + home |

### 6.4 TI y Auditoría

| Rol | LoA | SoD |
|---|---|---|
| TI-ADM-001 Admin TI | LoA 4 24/7 | No puede auto-aprobar cambios |
| AUD-RO-001 Auditor | LoA 3 | Read-only global, vigencia obligatoria |

### 6.5 Manufactura, Servicios, Retail

Tablas completas por sector con roles, módulos, nivel acceso y SPI relevante para: Gerente Producción, Operario Planta, Jefe Almacén, Director Operaciones, Gestor Clientes, Técnico Campo, Gerente Tienda, Vendedor, Cajero, E-Commerce Manager.

---

## 7. RolTemplate-SBOS-v2.json — Especificación Completa (10 bloques)

### Bloque 1 — Identificación
```json
"id": "RGV-001",
"name": "Gerente Regional de Ventas — Norte",
"parent_id": "VENTAS-BASE",
"version_number": 7,
"status": "ACTIVE",
"audit": { "created_by": "ADMIN.SISTEMA", "approved_by": "CFO" }
```

### Bloque 2 — Vigencia
```json
"validity_period": {
  "start_date": "2024-01-15T00:00:00Z",
  "end_date": "2025-12-31T23:59:59Z",
  "review_date": "2025-07-01T00:00:00Z"
}
```

### Bloque 3 — Flujo de Aprobación
```json
"approval_workflow": {
  "required_approvers": 2,
  "approver_roles": ["DIRECTOR_VENTAS", "CFO"],
  "notification_channel": "bcompass_SBOS VDI"
}
```

### Bloque 4 — Acceso Lógico (Dominio 1)

```json
"logical_access": {
  "availableMethods": ["username_password", "2fa_app", "biometric_login", "smart_card_logical", "hardware_token"],
  "requiredMethods": {
    "standard_login": [{"method": "username_password", "order": 1}, {"method": "2fa_app", "order": 2}],
    "elevated_login": [{"method": "username_password", "order": 1}, {"method": "biometric_login", "order": 2}]
  },
  "alternativeMethods": [
    {"replaces": "biometric_login", "with": "hardware_token", "requires_approval": false},
    {"replaces": "2fa_app", "with": "email_otp", "requires_approval": true, "approver_roles": ["ADMIN_SISTEMA"]}
  ],
  "geospatial_control": {
    "allowed_locations": [
      {"type": "office", "name": "Oficina Regional Norte", "network_ranges": ["192.168.10.0/24"], "coordinates": {"lat": 43.26, "lon": -2.92, "radius_m": 150}},
      {"type": "home_office", "network_ranges": ["81.44.200.0/24"]},
      {"type": "vpn", "network_ranges": ["10.10.0.0/16"]}
    ],
    "validation_rules": {"require_vpn": true}
  },
  "temporal_control": {
    "schedule_type": "SPECIFIC_DAYS",
    "allowed_days": [
      {"day": "MONDAY", "shifts": [{"start": "08:00", "end": "18:00"}]},
      {"day": "FRIDAY", "shifts": [{"start": "08:00", "end": "15:00"}]}
    ],
    "timezone": "Europe/Madrid",
    "exceptions": {"holidays": "BLOCKED"},
    "session_management": {
      "max_session_duration": 28800,
      "inactivity_timeout": 900,
      "force_logout_at_end_shift": true,
      "concurrent_sessions_allowed": false
    }
  }
}
```

### Bloque 5 — Acceso Físico (Dominio 2)
```json
"physical_access": {
  "zones": [
    {"zone_id": "ZONE-NORTE-01", "schedule": "business_hours", "access_level": "FULL"},
    {"zone_id": "ZONE-SERVER-01", "schedule": "never", "access_level": "DENIED"}
  ]
}
```

### Bloque 6 — Privilegios Tryton (5 niveles)

```json
"tryton_privileges": {
  "sequence_access": [
    {"sequence_type": "sale.order", "can_edit": false}
  ],
  "model_access": [
    {"model": "sale.order", "read": true, "write": true, "create": true, "delete": false},
    {"model": "account.invoice", "read": true, "write": false, "create": false, "delete": false},
    {"model": "account.payment", "read": true, "write": true, "create": true, "delete": false},
    {"model": "party.party", "read": true, "write": true, "create": true, "delete": false}
  ],
  "visible_actions": [
    "menu_sale_orders", "menu_sale_opportunities", "menu_sale_reports_regional",
    "menu_party_customers", "report_sales_regional_monthly", "wizard_sale_order_confirm"
  ],
  "field_restrictions": [
    {"model": "account.invoice", "field": "margin", "read": false},
    {"model": "account.invoice", "field": "cost_center", "read": false},
    {"model": "party.party", "field": "credit_limit_amount", "read": true, "write": false}
  ],
  "button_rules": [
    {"model": "sale.order", "button": "confirm", "users_required": 1, "condition_pyson": "Eval('amount_total', 0) <= 10000"},
    {"model": "sale.order", "button": "confirm", "users_required": 2, "condition_pyson": "Eval('amount_total', 0) > 10000", "step_up_loa": 3},
    {"model": "account.payment", "button": "approve", "users_required": 2, "condition_pyson": "Eval('amount', 0) > 5000", "step_up_loa": 3}
  ],
  "record_rules": [
    {"model": "sale.order", "domain_pyson": "[('team.territory', '=', 'NORTH')]"},
    {"model": "party.party", "domain_pyson": "[('category', 'in', ['CUSTOMER', 'PROSPECT'])]"}
  ]
}
```

### Bloque 7 — Transacciones Financieras (Dominio 3)

```json
"financial_transactions": {
  "requiredMethods": {
    "standard_transactions": [{"method": "smart_card_pin"}, {"method": "mobile_token"}],
    "high_value_transactions": [{"method": "smart_card_pin"}, {"method": "mobile_token"}, {"method": "biometric_validation"}]
  },
  "transaction_schedule": {
    "schedules": [{"name": "Pagos Quincenales", "periods": [{"days_of_month": [13,14,15], "hours": {"start": "09:00", "end": "16:00"}}]}],
    "emergency_override": {"allowed": true, "requires_approval": true, "approver_roles": ["FINANCE_DIRECTOR", "CEO"]}
  },
  "transaction_limits": {
    "single_transaction_limit": 10000,
    "daily_limit": 50000,
    "monthly_limit": 200000
  }
}
```

### Bloque 8 — Delegación
```json
"delegation_config": {
  "can_delegate": true,
  "max_duration_days": 21,
  "delegable_to_roles": ["SUPERVISOR-NORTE-001"],
  "requires_approval": true,
  "approver_roles": ["DIRECTOR_VENTAS"]
}
```

### Bloque 9 — Compliance y Auditoría
```json
"compliance_audit": {
  "compliance_reviews": {"review_frequency": "SEMIANNUAL"},
  "change_tracking": [{"change_id": "CHG-2025-003", "element_type": "PERMISSION", "old_value": {"limit": 8000}, "new_value": {"limit": 10000}, "approved_by": "CFO"}]
}
```

### Bloque 10 — Estado de Sincronización
```json
"sync_state": {
  "sync_status": "SYNCED",
  "sync_targets": {
    "keycloak": {"status": "SYNCED", "composite_role": "RGV_001", "group_path": "/Empresa-ACME/Ventas/Norte"},
    "tryton": {"status": "SYNCED", "group_id": 847, "group_name": "RGV_001"}
  }
}
```

---

## 8. UserTemplate-SBOS-v1.json — Especificación Completa (13 bloques)

### Bloque 1 — Identificación
```json
"id": 1001, "uuid": "550e8400-...", "username": "maria.garcia",
"external_id": "EMP789456", "status": "ACTIVE"
```

### Bloque 2 — Datos Personales
```json
"personal_info": {
  "given_name": "María", "family_name": "García López",
  "email": "maria.garcia@acme.com", "phone_number": "+34 600 123 456",
  "locale": "es-ES", "zoneinfo": "Europe/Madrid",
  "addresses": [{"type": "work", "city": "Bilbao"}, {"type": "home", "city": "Getxo"}],
  "emergency_contacts": [{"name": "Carlos García", "relationship": "spouse"}]
}
```

### Bloque 3 — Información Profesional
```json
"professional_info": {
  "employee_id": "EMP-ACME-2024-156", "position": "Gerente Regional Norte",
  "department": "Ventas", "cost_center": "VEN-NORTE-001", "territory": "NORTH",
  "company_id": "ACME-001", "supervisor_id": "DGV-CARLOS.RUIZ",
  "employment": {"start_date": "2024-01-15", "type": "full-time", "status": "active"}
}
```

### Bloque 4 — Firma Digital
```json
"digital_signature": {
  "algorithm": "SHA512withRSA",
  "quantum_resistant": {"enabled": true, "algorithm": "CRYSTALS-Dilithium", "key_size": 4096}
}
```

### Bloque 5 — Credenciales KC Registradas
```json
"keycloak_credentials": {
  "totp": {"registered": true, "algorithm": "SHA1", "digits": 6, "period": 30},
  "webauthn": {"credentials": [{"type": "platform", "description": "Touch ID MacBook"}]},
  "password": {"last_changed": "2025-01-15", "expires_at": "2025-07-15"},
  "backup_codes": {"remaining": 6},
  "smart_card": {"card_id": "SC-ACME-2024-0156", "expiry": "2027-01-15"}
}
```

### Bloque 6 — Compliance de Credenciales
```json
"credentials_compliance": {
  "covers_required_methods": true,
  "gaps": [],
  "details": {"username_password": "COVERED", "2fa_app": "COVERED", "biometric_login": "COVERED", "smart_card_logical": "COVERED"}
}
```

### Bloque 7 — Dispositivos y Redes de Confianza
```json
"devices": [
  {"device_id": "DEV-001", "type": "laptop", "os": "macOS 14.3", "trusted": true, "mdm_enrolled": true},
  {"device_id": "DEV-002", "type": "mobile", "os": "iOS 17.4", "trusted": true}
],
"trusted_networks": [{"name": "VPN ACME", "range": "10.10.0.0/16"}, {"name": "Oficina", "range": "192.168.10.0/24"}]
```

### Bloque 8 — Asignaciones de Rol
```json
"roles_assignments": {
  "active_roles": [{"role_id": "RGV-001", "kc_group_path": "/Empresa-ACME/Ventas/Norte", "tryton_group": "RGV_001"}],
  "temporary_assignments": [{"role_id": "BUDGET_APPROVER_NORTE", "start_date": "2025-04-01", "end_date": "2025-04-30"}],
  "history": [{"role_id": "VENDEDOR-NORTE-001", "removed_date": "2024-01-14", "reason": "PROMOTION"}]
}
```

### Bloque 9 — Tryton Binding
```json
"tryton_binding": {"employee_id": 1203, "company_id": 1, "active_company": "ACME S.A.", "language": "es"}
```

### Bloque 10 — Preferencias VDI
```json
"sbos_vdi_preferences": {
  "desktop_environment": "GNOME", "theme": "dark",
  "notifications": {"email": true, "push": true, "quiet_hours": {"start": "18:30", "end": "08:00"}}
}
```

### Bloque 11 — Compliance y Certificaciones
```json
"compliance_control": {
  "certifications": [{"id": "CERT-ISO27001-2024", "status": "current", "expiry": "2026-01-24"}],
  "training_status": {"required_courses": [{"id": "SEC-2025-001", "deadline": "2025-06-30", "status": "pending"}]},
  "territorial_compliance": {"primary_jurisdiction": "ES", "applicable_regulations": ["GDPR", "LOPDGDD", "PSD2"]}
}
```

### Bloque 12 — Estado Operacional
```json
"operational_state": {
  "last_access": {"logical": "2025-03-07T09:15:00Z", "physical": "2025-03-07T08:55:00Z"},
  "security_incidents": {"count": 1, "last_type": "LOGIN_OUTSIDE_SCHEDULE", "resolved": true},
  "physical_logical_correlation": {"enabled": true, "last_event": {"type": "NORMAL_ENTRY", "anomaly": false}}
}
```

### Bloque 13 — Estado de Sincronización
```json
"sync_state": {
  "sync_status": "SYNCED",
  "sync_targets": {
    "keycloak": {"status": "SYNCED", "user_id": "550e8400-..."},
    "tryton": {"status": "SYNCED", "user_id": 847, "employee_id": 1203}
  }
}
```

---

## §9 — ENRIQUECIMIENTO V5: Contratos de Identidad Original (SBOS-009 v1.0)

### V5-1: Propósito Extendido — Relación con otros documentos

Los contratos de identidad mantienen relación formal con:
- **SBOS-008** (RolFramework): es el motor que procesa estos contratos. Este documento es el contrato; SBOS-008 es el motor.
- **SBOS-019** (KC Auth Methods): especificación de métodos de autenticación Keycloak referenciados en availableMethods/requiredMethods.
- **SBOS-020** (KC Data Responses): datos y respuestas de Keycloak que el UserTemplate refleja.

### V5-2: Catálogo de Roles por Sector Industrial (desde SBOS-MP01 PARTE B)

**Sector Manufactura:**
- Gerente Producción: Tryton (Manufacturing), OrangeHRM (Read), SBOS AI Tools (analyst). Full en manufactura.
- Operario Planta: Tryton Manufacturing (solo su área), OrangeHRM (portal empleado). Restricted.
- Jefe Almacén: Tryton (Inventory, Purchase), OrangeHRM (Read). Full en inventario.
- Auditor Interno: Tryton (Read All), OrangeHRM (Read), SBOS AI Tools (report). Read-only global.

**Sector Servicios:**
- Director Operaciones: Tryton (All), OrangeHRM (Read), SBOS AI Tools. Full en operaciones.
- Gestor Clientes: Tryton (Party, Sale, Contract), EspoCRM (Full). Full en CRM.
- Técnico Campo: Tryton (Service Orders — asignadas), SBOS VDI (móvil). Restricted por asignación.

**Sector Comercial / Retail:**
- Gerente Tienda: Saleor (Full), Tryton (Inventory, Accounting — Read), OrangeHRM (Read).
- Vendedor: Saleor (Orders, Customers), Tryton (Inventory — Read). Restricted a área/turno.
- Cajero: Saleor (Checkout, Payments). Muy restringido.
- E-Commerce Manager: Saleor (Full), SBOS AI Tools (analyst).

### V5-3: BitMask 64-bit Original (8 primeros bits de la tabla maestra SBOS-008)

```
Bit 0: SESSION_VALID          — sesión activa y autenticada
Bit 1: SHELL_UNLOCK           — desbloquear shell de Fedora
Bit 2: APP_TRYTON             — acceso a Tryton
Bit 3: APP_ORANGEHRM          — acceso a OrangeHRM
Bit 4: APP_SALEOR             — acceso a Saleor
Bit 5: DRAWER_OPEN            — activar relé cajón de dinero
Bit 6: DOOR_ZONE_A            — abrir puertas Zona A
Bit 7: DOOR_ZONE_B            — abrir puertas Zona B
```

---

## §10 — ENRIQUECIMIENTO V7: Reconceptualización de Dominios y BitmaskBundle v3

### V7-1: BitmaskBundle v3 — Modelo de 3 Dominios Abstractos (desde DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION)

El modelo V6 de `VDIMask + ERPMask` se reconceptualiza a dominios abstractos:

```go
type BitmaskBundle struct {
    PhysicalDomainMask uint64 `json:"bos_physical_mask"`     // banexus — hardware, zonas, actuadores
    LogicalDomainMask  uint64 `json:"bos_logical_mask"`      // evaluador lógico unificado — zonas de negocio
    FinancialDomainMask uint64 `json:"bos_financial_mask,omitempty"` // bAuth financial evaluator
}
```

**Cambios respecto a V6:**
- `VDIMask` → `PhysicalDomainMask` (no asume Fedora KDE)
- `ERPMask` → `LogicalDomainMask` (no asume Tryton, codifica zonas de negocio)
- Nueva: `FinancialDomainMask` (dominio financiero con máscara propia)

### V7-2: LogicalDomainMask — Zonas de Negocio × Verbo Universal

La LogicalDomainMask codifica **zonas de negocio** (no aplicaciones):

```
Zona CONTABILIDAD:
  Bit 0: CONTABILIDAD_READ     — leer registros contables (Tryton + Superset + Paperless)
  Bit 1: CONTABILIDAD_WRITE    — crear/editar registros contables (Tryton)
  Bit 2: CONTABILIDAD_APPROVE  — aprobar asientos/pagos (SoD: no puede tener WRITE)
  Bit 3: CONTABILIDAD_AUDIT    — acceso a logs de auditoría contable

Zona RRHH:
  Bit 4: RRHH_READ             — leer datos de empleados (OrangeHRM + Tryton Payroll)
  Bit 5: RRHH_WRITE            — modificar datos de empleados
  Bit 6: RRHH_APPROVE          — aprobar vacaciones, solicitudes
  Bit 7: RRHH_AUDIT            — acceso a logs de RRHH

Zona VENTAS:
  Bit 8: VENTAS_READ           — leer pedidos/clientes (Saleor + EspoCRM + Tryton)
  Bit 9: VENTAS_WRITE          — crear/modificar pedidos y clientes
  Bit 10: VENTAS_APPROVE       — aprobar descuentos especiales
  Bit 11: VENTAS_AUDIT         — acceso a reportes de ventas

Zona ADMINISTRACION:
  Bit 20: ADMIN_SYSTEM         — administración de sistema (bAuth, Keycloak)
  Bit 21: ADMIN_USERS          — gestión de usuarios y roles
  Bit 22: ADMIN_AUDIT          — acceso completo a todos los logs

Bit 63: SUPERZONE              — reservado para AssumeTenantContext
```

### V7-3: FinancialDomainMask — Zona Financiera × Verbo

```
Bit 0: CAJA_APERTURA           — abrir caja (SoD: no puede tener CAJA_AUDITORIA)
Bit 1: CAJA_CIERRE             — cerrar caja
Bit 2: CAJA_ARQUEO             — realizar arqueo
Bit 3: CAJA_AUDITORIA          — auditar caja (SoD: no puede tener CAJA_APERTURA)
Bit 4: PAGO_CREATE             — crear órdenes de pago (SoD: no puede tener PAGO_APPROVE)
Bit 5: PAGO_APPROVE_L1        — aprobar pagos hasta límite L1
Bit 6: PAGO_APPROVE_L2        — aprobar pagos hasta límite L2
Bit 7: PAGO_AUDIT             — auditar pagos
Bit 8: NOMINA_INPUT           — ingresar datos de nómina (SoD: no puede tener NOMINA_APPROVE)
Bit 9: NOMINA_APPROVE         — aprobar nómina (SoD: no puede tener NOMINA_INPUT)
Bit 10: NOMINA_AUDIT          — auditar nómina
Bit 11: COMPRA_SOLICITUD      — solicitar compra
Bit 12: COMPRA_APROBACION     — aprobar compra
Bit 13: COMPRA_RECEPCION      — recibir mercadería
```

### V7-4: Verbos Universales con Contexto de Dominio

```
READ      — Consultar/visualizar información en una zona
WRITE     — Crear/modificar información en una zona
DELETE    — Eliminar información en una zona (requiere justificación)
APPROVE   — Aprobar una acción iniciada por otro actor (SoD obligatorio)
EXECUTE   — Activar un actuador físico o disparar un proceso automatizado
CONFIGURE — Modificar la configuración de una zona o sistema
AUDIT     — Acceso de solo lectura a logs y registros de auditoría
```

Mapping de verbos legados → universales:
```go
SESSION_VALID     = READ   | zona=PHYSICAL_ACCESS
DRAWER_OPEN       = EXECUTE | zona=ZONE_CAJA
PERM_VIEW         = READ   | zona=<zona de negocio>
PERM_EDIT         = WRITE  | zona=<zona de negocio>
PERM_APPROVE      = APPROVE | zona=FINANCIAL
```

### V7-5: Zone Application Map — Resolución Zona → Aplicaciones

```yaml
# zone_application_map.yaml — fuente de verdad del evaluador lógico
zones:
  ZONE_CONTABILIDAD:
    applications:
      - tryton: [modules: [account, account_invoice, account_payment]]
      - superset: [dashboards: [contabilidad_*]]
      - paperless: [tags: [factura, comprobante, fiscal]]
    required_verb_for_access: READ

  ZONE_RRHH:
    applications:
      - orangehrm: [all_modules: true]
      - tryton: [modules: [payroll, leave]]
      - paperless: [tags: [contrato, personal]]
    required_verb_for_access: READ

  ZONE_VENTAS:
    applications:
      - saleor: [all_modules: true]
      - espocrm: [all_modules: true]
      - tryton: [modules: [sale, invoice]]
    required_verb_for_access: READ
```

### V7-6: LogicalDomainEvaluator — Interfaz del PDP faltante

```go
type LogicalDomainEvaluator interface {
    CanAccessZone(jwt *BosJWT, zone BusinessZone, verb UniversalVerb) (bool, error)
    GetZoneApplications(zone BusinessZone) ([]ApplicationEndpoint, error)
    GetActiveZones(jwt *BosJWT) ([]BusinessZone, error)
}
```

### V7-7: RolTemplate v5.0 — 14 Bloques (desde ROLTEMPLATE-v5_0)

La especificación V7 expande de 10 a 14 bloques:

**Bloque 11 — Zonas con Verbos:** `zones` define accesos lógicos/físicos/financieros con verbos universales (READ, WRITE, APPROVE, EXECUTE, CONFIGURE, AUDIT).

**Bloque 12 — Conflict Management (SoD):**
```json
"conflict_management": {
  "segregation_of_duties": [
    {"action": "approve_payment", "cannot_also": "create_payment"},
    {"action": "post_invoice", "cannot_also": "receive_payment"},
    {"action": "payroll_input", "cannot_also": "payroll_approve"}
  ]
}
```

**Bloque 13 — Group Management:** define grupos KC y Tryton con herencia.

**Bloque 14 — GovernanceMask:** bitmask de gobernanza que controla qué puede hacer el admin del tenant sobre el propio sistema.

### V7-8: UserTemplate v5.0 — 16 Bloques (desde USERTEMPLATE-v5_0)

La especificación V7 expande de 13 a 16 bloques:

**Bloque 14 — Contextual Access:** `contextual_access.session_context` define overrides por sesión, incluyendo IP, dispositivo y geolocalización.

**Bloque 15 — System Integrations:** bindings con sistemas externos (SCIM 2.0, LDAP).

**Bloque 16 — Risk Score:** `risk_score` con `component_scores` que alimenta SkbosBehavioralScoreAuthenticator.

**Bloque 4 expandido — Firma Digital:** CRYSTALS-Dilithium como algoritmo post-cuántico obligatorio para firma del UserTemplate.

**Bloque 7 expandido — Dispositivos:** se agrega `compliance_status` por dispositivo (COMPLIANT/NON_COMPLIANT/UNKNOWN).

### V7-9: Decisiones de Diseño que Cambian (desde TEMPLATES-DECISIONES-v1_0)

| Decisión | V6 (anterior) | V7 (reconceptualizado) |
|---|---|---|
| D1 | UserTemplate tenía permisos propios | UserTemplate NUNCA define permisos propios |
| D2 | 4-5 métodos de autenticación | 15 métodos canónicos en 5 categorías |
| D3 | Zonas = aplicaciones concretas | Zonas de negocio abstractas (no apps) |
| D4 | SAM-128 como uint128 monolítico | BitmaskBundle v3 (3×uint64 independientes) |
| D5 | Sin política biométrica formal | Política en RolTemplate, Hash PBKDF2-SHA256 en UserTemplate |
| D6 | Sin máscara financiera dedicada | FinancialDomainMask como bloque de primer nivel |
| D7 | Sin excepciones individuales | ContextOverrides con approved_by + reason + valid_until |
| D8 | Certificaciones sin efecto bloqueante | blocking=true como prerequisito para ACTIVE |

### V7-10: Mapeo con Documentos de Referencia

| Fuente | Campo en Template | Implementación |
|---|---|---|
| Authentication_Framework.json §sanctumEnhanced.tokenManagement.security.keyRotation | logical_access.session_management.reauthentication_interval_s | KC token rotation policy |
| Authentication_Framework.json §contextualAuthentication.riskEvaluationEngine | logical_access.geospatial_control.validation_rules.geo_velocity_check | SPI SkbosGeoContextAuthenticator |
| Authentication_Framework.json §quantumResistantSecurity.postQuantumCrypto | digital_signature.algorithm = "CRYSTALS-Dilithium" | Firma post-cuántica |
| Policies_Authentication_Framework.json §webauthn_fido2 | availableMethods: ["webauthn_platform", "webauthn_roaming", "passkey"] | Auth Flow KC |
| Policies_Authentication_Framework.json §physical_logical_authentication.physical_access.entry_points | physical_access.requiredMethods.critical_areas | 3 factores para zonas críticas |
| SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION §3.3 | zones.zone_logical/* | Zonas × Verbos abstractos |
| SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO §2.4 | conflict_management.segregation_of_duties | Conflict Matrix con AND NOT |

### V7-11: SAM-128 Correcciones — Operadores Correctos

**XOR → Conflict Matrix para SoD:**
La operación XOR puede producir elevación de privilegios. Se reemplaza por una Conflict Matrix evaluada en asignación:

```yaml
sod_rules:
  - action: "approve_payment"
    cannot_also: "create_payment"
  - action: "post_invoice"
    cannot_also: "receive_payment"
  - action: "payroll_input"
    cannot_also: "payroll_approve"
```

**NAND → AND NOT para KillSwitch:**
NAND puede dar ALL_PERMISSIONS al aplicarse sobre bits no presentes. Se usa AND NOT (`&^` en Go):

```go
func RevokeEmergency(current, toRevoke BitmaskBundle) BitmaskBundle {
    return BitmaskBundle{
        VDIMask: current.VDIMask &^ toRevoke.VDIMask,
        ERPMask: current.ERPMask &^ toRevoke.ERPMask,
    }
}
```

### V7-12: AssumeTenantContext — Superusuario Zero Standing Privileges

```go
func (b *BAuth) AssumeTenantContext(adminUserID string, realmID string, reason string, durationMinutes int) (*TenantContext, error) {
    if !b.isGlobalAdmin(adminUserID) {
        return nil, ErrNotAuthorized
    }
    masterMask := BitmaskBundle{
        PhysicalDomainMask: ^uint64(0),
        LogicalDomainMask:  ^uint64(0),
        FinancialDomainMask: ^uint64(0),
    }
    ctx := &TenantContext{
        AdminID:   adminUserID,
        RealmID:   realmID,
        Mask:      masterMask,
        Reason:    reason,
        ExpiresAt: time.Now().Add(time.Duration(durationMinutes) * time.Minute),
        ContextID: uuid.New().String(),
    }
    b.auditLog.Write(AuditEvent{
        EventType: "superuser_context_assumed",
        AdminID:   adminUserID,
        RealmID:   realmID,
        Reason:    reason,
        Severity:  "HIGH",
    })
    return ctx, nil
}
```

### V7-13: Plan de Migración Faseado

| Fase | Versión SBOS | Acción | Entregable |
|---|---|---|---|
| Fase 0 — Ahora | Pre-v0.9 | Separar VDI y ERP en máscaras independientes | bitmask_constants.go v2 |
| Fase 1 — v0.9 Beta | Jul 2026 | Renombrar VDIMask→PhysicalDomainMask, ERPMask→LogicalDomainMask | Migración JWT claims |
| Fase 2 — v0.9 GA | Sep 2026 | Reconceptualizar bits de LogicalDomainMask de apps → zonas de negocio | zone_application_map.yaml |
| Fase 3 — v1.0 | Nov 2026 | Implementar LogicalDomainEvaluator | 6 integraciones nuevas |
| Fase 4 — v1.0 | Nov 2026 | Añadir FinancialDomainMask + FinancialDomainEvaluator | Evaluador financiero |
| Fase 5 — v1.5 | Mar 2027 | Verbos específicos → verbos universales | Refactor constants |
| Fase 6 — v2.0 | 2027 | Evaluar dominio Operacional | ADR nuevo |

---

## ENRIQUECIMIENTO Smart* (V8)

### Smart*-1: OAIS Model (ISO 14721:2012) aplicado a Identidad (desde BVAULT-003 §3.1)

El modelo OAIS define cómo la identidad de un usuario atraviesa las tres fases del ciclo de vida documental. Para los contratos de identidad, esto se traduce en:

```
SIP (Submission Information Package) — origen ORC:
  └── UserTemplate recién creado + credenciales registradas + datos biométricos
  └── Contexto: ctx_id, dispositivo, geolocalización, timestamp

AIP (Archival Information Package) — bVault:
  └── Estado sincronizado del UserTemplate a través del tiempo
  └── Hash SHA-256 de cada versión del template (cadena de integridad)
  └── PREMIS provenance metadata: quién, cuándo, por qué cambió

DIP (Dissemination Information Package) — destinatario:
  └── RolTemplate compilado + UserTemplate + evidencia de sync
  └── Verificable por auditor externo: hash encadena versiones
```

**Implicaciones para Contratos de Identidad:**
- El RolTemplate en estado ACTIVE es un AIP — tiene una versión, un hash, un historial inmutable
- La transición de estados (DRAFT→REVIEW→ACTIVE→DEPRECATED→ARCHIVED) sigue la cadena de procedencia PREMIS
- Cada cambio en un template debe generar un evento en `bos_rol_template_history` con `entry_hash = SHA-256(entry_hash_prev + template_snap)`

### Smart*-2: Arquitectura de Identidad Dual — HR ID + Vault ID (desde BVAULT-003 §4.2)

El sistema SBOS reconoce dos identificadores raíz para cada persona, y su relación es gestionada por los contratos de identidad:

| Identificador | Sistema de origen | Campo en UserTemplate | Propósito |
|---|---|---|---|
| HR ID | OrangeHRM | `employee_id` (Bloque 3) | Identidad laboral: salario, puesto, estructura organizacional |
| Vault ID | Keycloak / bVault | `uuid` (Bloque 1) | Identidad documental: autenticación, firmas, procedencia |

**Regla de binding:**
```
HR ID (OrangeHRM) ↔ UserTemplate.uuid (Keycloak) ↔ Vault ID (bVault)
         │                    │                             │
    entity_crossref     bos_user_template             vault_assets.signed_by
    (bkernel)           (bauth/bkernel)               (bvault)
```

### Smart*-3: PREMIS v3.0 — Procedencia de Contratos de Identidad (desde BVAULT-003 §4.3)

Cada versión de un RolTemplate o UserTemplate debe cumplir con los siguientes elementos PREMIS:

| Elemento PREMIS | Implementación en Contratos de Identidad |
|---|---|
| objectIdentifier | `id + version_number` en cada template |
| objectCharacteristics | `entry_hash` = SHA-256 del JSON completo |
| originalName | Nombre canónico del rol/usuario |
| preservationLevel | `DEPRECATED` → archivado, `ACTIVE` → preservación activa |
| **eventDetail** | `change_reason` + `changed_by` + `changed_at` en history |
| eventType | `CREATE` / `UPDATE` / `STATUS_CHANGE` / `VERSION_BUMP` |
| eventDateTime | `changed_at` del history |
| **linkingAgentIdentifier** | `approved_by` del RolTemplate (quórum humano) |
| **linkingObjectIdentifier** | `parent_id` del RolTemplate (hereda de...) |

### Smart*-4: Las 4 Propiedades ISO 15489-1:2016 en Contratos (desde BVAULT-003 §4.4)

| Propiedad ISO 15489 | Cómo la garantiza el sistema de contratos |
|---|---|
| **Autenticidad** | Cadena de firmas SHA-256 en `bos_rol_template_history.entry_hash`. Cada versión prueba que no fue modificada retroactivamente. |
| **Fiabilidad** | `sync_state.sync_status = SYNCED` prueba que el estado declarado coincide con el estado real en KC y Tryton. |
| **Integridad** | RolTemplate bloqueado en REVIEW/ACTIVE. Solo cambios vía nueva versión. UserTemplate con `credentials_compliance` auto-calculado. |
| **Usabilidad** | `zone_application_map.yaml` resuelve zonas → aplicaciones concretas. Catálogo de roles por sector (§6) proporciona contexto de negocio. |

### Smart*-5: 8 Perfiles de Usuario del Vault — Mapeo a UserTemplate (desde SBOS-VAULT-003)

Los 8 perfiles definidos por SBOS-VAULT-003 se mapean directamente a UserTemplates con roles predefinidos:

| Perfil bVault | RolTemplate Asignado | Bits Vault | audit_scope |
|---|---|---|---|
| Gestor Documental | VAULT-DOC-MGR-001 | VAULT_READ, VAULT_WRITE | null (todos los documentos) |
| Firmante/Aprobador | VAULT-SIGNER-001 | VAULT_READ, VAULT_APPROVE | null |
| Consultante/Lector | VAULT-READER-001 | VAULT_READ | null |
| Admin bvault | VAULT-ADMIN-001 | VAULT_ADMIN + todos | null |
| Auditor Interno | VAULT-AUDITOR-001 | VAULT_AUDIT | null |
| Destinatario Externo | VAULT-EXT-READER-001 | VAULT_READ | `["documentos_contrato-*"]` |
| SmartORC (servicio) | VAULT-ORC-SVC-001 | VAULT_READ, VAULT_WRITE | service account |
| Auditor Externo | VAULT-EXT-AUDITOR-001 | VAULT_AUDIT | `["facturas_2025", "contratos_socios"]` |

**Implementación de audit_scope (para auditores externos):**
```json
{
  "audit_scope": {
    "document_types": ["facturas", "contratos", "nomina"],
    "date_range": {"from": "2025-01-01", "to": "2026-12-31"},
    "departments": ["contabilidad", "ventas"],
    "max_documents": 10000,
    "requires_approval": true,
    "approver": "admin_bvault"
  }
}
```

### Smart*-6: Firma de Ámbito Cerrado vs Estatal (desde BOSORC-013 §2.4)

El UserTemplate debe incluir el campo `firma_ambito` que determina el alcance legal de las firmas del usuario:

```json
"firma_ambito": {
  "tipo": "cerrado",           // "cerrado" | "estatal"
  "empresa_id": "ACME-001",
  "nit": "1234567890123",
  "requires_external_audit": false,
  "valido_hasta": "2026-12-31"
}
```

| Tipo | Ámbito | Requisitos de firma | Auditoría |
|---|---|---|---|
| Cerrado | Intra-empresa | WebAuthn + LoA 2 | Interna |
| Estatal | Inter-empresa / regulatorio | WebAuthn + quórum + acr=critical | Externa (ASFI/SIAT) |

### Smart*-7: Atomicidad del Timestamp en Eventos de Identidad (desde BOSORC-013 §3)

Todo evento de identidad (cambio de rol, asignación de template, firma de contrato) debe registrar el timestamp con `NOW()` de PostgreSQL — nunca timestamp del cliente. Esto garantiza:

- **Orden legal verificable:** la secuencia de eventos no puede ser impugnada
- **Consistencia forense:** todos los sistemas SBOS usan la misma fuente temporal
- **Auditoría externa:** un perito puede verificar que evento A ocurrió antes que evento B sin depender de relojes locales

---

## Trazabilidad V8

| Sección | Fuente |
|---|---|
| §1-8 (V6 completo) | BOS_V6_SBOS-022-IDENTITY-CONTRACTS.md |
| §9 V5-1 a V5-3 | BOS_V5_SBOS-009-IDENTITY-CONTRACTS-v1_0.md |
| §10 V7-1 a V7-13 | BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md, BOS_V7_SBOS-ROLTEMPLATE-v5_0.md, BOS_V7_SBOS-USERTEMPLATE-v5_0.md, BOS_V7_SBOS-TEMPLATES-DECISIONES-v1_0.md, BOS_V7_SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md |
| Smart*-1 a Smart*-4 | Enriquecimiento Smart* V8 | BVAULT-003-IDENTIDAD-AUTENTICACION.md |
| Smart*-5 | Enriquecimiento Smart* V8 | SBOS-VAULT-003-USUARIOS.md |
| Smart*-6 a Smart*-7 | Enriquecimiento Smart* V8 | BOSORC-013-TRYTON-KEYCLOAK.md |

---

_SKULL · SBOS · SBOS-022-IDENTITY-CONTRACTS · HUMAN-DOC V8 ENRIQUECIDO · Mayo 2026_
