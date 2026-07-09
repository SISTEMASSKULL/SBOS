# BAUTH-B10-PROCESO-ROL-CRUD — Documento de Aprobación

**Versión:** 2.0.0 · **Fecha:** 2026-06-22 · **Autor:** sbos-coordinador  
**Propósito:** Definir el proceso completo para implementar el CRUD de RolTemplates.
**MODELO FINAL:** Plantillas base (aceleran) → clonar → roles oficiales (producen).

---

## 0. Modelo Conceptual

### Los dos tipos de RolTemplate

```
┌──────────────────────────────────────────────────────────────────┐
│   CATÁLOGO DE PLANTILLAS BASE (66 predefinidas)                  │
│                                                                   │
│  is_template = TRUE  ·  owner_tenant = NULL  (multitenant)        │
│                                                                   │
│  Propósito: ACELERAR la creación de roles.                        │
│  El usuario busca la plantilla más cercana → "Usar como base"    │
│                                                                   │
│  Ej: "ROL-CAJERO-GENERICO", "ROL-GERENTE-GENERICO",              │
│      "ROL-AUDITOR-GENERICO", "ROL-VENDEDOR-GENERICO"             │
│                                                                   │
│  NO se sincronizan a Keycloak ni Tryton. Solo existen en BD.     │
└──────────────────────────────────────────────────────────────────┘
                    │
                    │ CLONAR + MODIFICAR
                    ▼
┌──────────────────────────────────────────────────────────────────┐
│   ROL OFICIAL (creado desde plantilla o clonado de otro oficial) │
│                                                                   │
│  is_template = FALSE  ·  owner_tenant = tenant-empresa-sucursal   │
│                                                                   │
│  El usuario ajusta solo lo que necesita cambiar.                  │
│                                                                   │
│  Ej: "Cajero Sucursal Centro" (clonado de ROL-CAJERO-GENERICO)  │
│      → max_transaction: 2000 (vs 5000 del template)              │
│      → horario: 08:00-16:00                                       │
│      → tenant_id: banco-union-sucursal-centro                    │
│                                                                   │
│  SÍ se sincroniza a Keycloak + Tryton.                            │
│  Puede clonarse a su vez para crear otro rol similar.             │
└──────────────────────────────────────────────────────────────────┘
                    │
                    │ ¿Rol similar? → CLONAR oficial
                    ▼
┌──────────────────────────────────────────────────────────────────┐
│   CLONAR ROL OFICIAL → NUEVO ROL OFICIAL                          │
│                                                                   │
│  "Cajero Sucursal Centro" → clonar → "Cajero Sucursal Norte"     │
│                                                                   │
│  is_template = FALSE · owner_tenant cambia                        │
│  Solo se modifican: sucursal_id, horario, límites específicos    │
│                                                                   │
│  Opcional: guardar como nueva PLANTILLA si el usuario quiere     │
│  que otros lo usen de base (is_template = TRUE)                   │
└──────────────────────────────────────────────────────────────────┘

No, los roles oficiales no se vuelven plantilla el usurio puede tomar los roles de ese ctx_is para clonar como referencias de plantilla a los roles oficiales, pero no esta disponible para otra empresa o tenat, ya qeu los roles son privados del ctx_id.
```
Se deben desarrollar todas las plantillas de los roles de : opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bauth/plandeaccion/bauth/BAUTH-CATALOGO-ROLES-EMPRESARIALES.md : cion eso ya tendremos una buena base para qeu ekl usurio agregue sin problemas roles.

### Mecanismo de clonación

```json
{
  "method": "bauth.template.clone",
  "params": {
    "source_id": "uuid",
    "role_name": "Cajero Sucursal Centro",
    "modifications": {
      "max_transaction": 2000.00,
      "shift_start": "08:00",
      "shift_end": "16:00",
      "owner_tenant": "uuid-tenant"
    },
    "save_as_template": false
    // false → crea rol oficial  (is_template=false)
    // true  → crea plantilla base (is_template=true)
  }
}
```

---

## 1. Cadena de Dependencias

### 1.1 Lo que YA existe (✅)

```
NIVEL 1: Catálogo Base
  bos_domain (12 dominios) ────┐ (no necsita crud datos finitos)
  bos_verb (4 verbos) ─────────┤ (desarrollar crud)
  bos_group (34 grupos) ───────┤ (desarrollar crud)
                                ▼
NIVEL 2: Átomos                bos_atom_catalog (1044 átomos) (desarrollar crud)
                                │
                                ▼
NIVEL 3: Políticas             bos_atom_policy (5000+ políticas) (desarrollar crud)
                                │
                                ▼
NIVEL 4: Roles                 bos_role (10 roles) (desarrrollar crud)
                                │
                                ▼
NIVEL 5: Asignaciones          bos_role_atom (212 role↔atom) (desarrollar crud)
                                │
                                ▼
NIVEL 6: Herencia              rol_closure (9 relaciones DAG)
```

Aui tambien se necesita los metodos a disponibilidad, las politicas, y demas requerimientos que hagan de ekl rokl una estructura fuertes para eso consultar : opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bauth/plandeaccion/bauth/BAUTH-AUTHENTICATION-FRAMEWORK-completitud.md
opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bauth/plandeaccion/bauth/BAUTH-AUTHENTICATION-FRAMEWORK.md


**Conclusión:** Los 6 niveles base están poblados. B10 puede empezar.

### 1.2 Lo que B10 construye

```
NIVEL 7: Templates             bos_rol_template (0 registros → DDL CREADO ✅)
NIVEL 8: Historial WORM       bos_rol_template_history (DDL CREADO ✅)
NIVEL 9: Seed 66 plantillas   plantillas base predefinidas (POR POBLAR)
NIVEL 10: Handlers CRUD       9 métodos JSON-RPC (POR CONSTRUIR)
NIVEL 11: Sync engines         Keycloak + Tryton (POR CONSTRUIR)
```

---

## 2. Estructura del RolTemplate — 14 Bloques

Se deeb verificar la estructura e invetigar sobre las normas y estandares para el mantenimiento de roles y precautelar la trazabilidad y la seguridad, ademas de la robustes estructural.

Investiga en internet si estan completas las partes o secciones de la estructura del rol, si no es asi hay qeu competarlas.

Bloques definidos en `bos_rol_template` (DDL ya creado en `db/seeds/`).

### Bloque 1: Identificación

| Campo | Tipo | Validación | Estándar |
|-------|------|-----------|---------|
| `role_code` | INTEGER | Único, > 0, autoincremental | — |
| `role_name` | TEXT | No vacío, max 100 chars | ISO 24760-2 §5.3 |
| `role_slug` | TEXT | Único, automático | — |
| `tier` | ENUM | SU/SYS/BIZ_N3_N5/BIZ_N1_N2/EXT_N0/M2M/VISITANTE | NIST 800-63B AAL |
| `parent_id` | UUID FK | No self, sin ciclo DAG | ANSI INCITS 359 §2 |
| `description` | TEXT | Opcional, max 500 chars | — |
| `issuer` | TEXT | Default: 'bAuth' | ISO 24760-2 §5.4 |
| `template_version` | INTEGER | Auto-increment en UPDATE | — |
| `is_template` | BOOLEAN | true=plantilla base · false=rol oficial | — |
| `owner_tenant` | UUID FK | NULL para plantillas base, obligatorio para oficiales | — |

**Política CRUD:** Solo ROL-SYS-ADMIN-PROYECTO puede CREATE/DELETE plantillas base.  
El rol oficial puede crearlo el admin del tenant.

### Bloque 2: Vigencia

`start_time`, `expiry_time`, `loa_required`, `mfa_required`, `mfa_methods`, `step_up_enabled`

**Reglas:**
- SU → LoA ≥ 3, MFA obligatorio (NIST AAL3)
- SYS → LoA ≥ 2, MFA obligatorio (NIST AAL2)
- BIZ_N3_N5 → MFA obligatorio
- Al expirar → sync_status=EXPIRED, KC desactiva el rol

### Bloque 3: Permisos (BitMask Dual)

| Concepto | Implementación |
|----------|---------------|
| Átomos asignados | `bos_role_atom` (template_id, atom_position) |
| Herencia | `mask_eff = mask_own OR mask_parent(s)` vía closure table |
| Validación | Todo átomo debe existir en `bos_atom_catalog` |

### Bloques 4-7: Restricciones

| Bloque | Campos | Estándar |
|--------|--------|---------|
| **4. Financiero** | max_transaction, max_daily, max_monthly, currency, requires_dual_approval, dual_approval_threshold | ISO 20022, FATF Rec.16, SOX §404 |
| **5. Temporal** | shift_start, shift_end, max_session_hours, inactivity_timeout_min | NIST 800-63B §7 |
| **6. Geográfico** | allowed_countries (ISO 3166-1), geo_fence (lat,lon,radius) | — |
| **7. Red** | allowed_cidrs (RFC 4632), vpn_required, device_posture_required | — |

Aqui deebs hacer uso del motro del validaro de politicas, justamente para vaklidar la definicion correcta, o complememntar l validador para que el crud del rol sea robusto.

### Bloque 8: Delegación (D10)

`delegable`, `max_delegation_depth` (0-3), `delegation_ttl_hours`

**Regla:** SU nunca delegable por defecto.

### Bloque 9: SoD (D3 estático)

`sod_group`, `sod_conflicts_with[]`

**Regla:** Dos roles en mismo grupo o conflictivos → no asignables al mismo usuario (NIST AC-5).

### Bloques 10-11: Auditoría y Cumplimiento

`audit_level` (none/basic/full), `session_recording`, `compliance_tags[]`, `risk_level`

### Bloque 12: Sync

`sync_status` (PENDING→SYNCING→SYNCED|FAILED), `kc_realm_role`, `tryton_group_id`, `last_synced_at`

**Regla:** Si `is_template=true` → no se sincroniza. Si `is_template=false` → sync obligatorio tras aprobación.

### Bloque 13: Encriptación

`encrypted_fields[]`, `encryption_key_ref` — AES-256-GCM con clave desde Vault Transit.

### Bloque 14: Metadatos

`is_active`, `created_at`, `updated_at`, `created_by`, `updated_by`

---

## 3. Validaciones — 22 Reglas

### 3.1 Al CREATE

| # | Regla | Fuente |
|---|-------|--------|
| V1 | role_name no vacío | ISO 24760-2 §5.3 |
| V2 | role_code único | — |
| V3 | tier→LoA: SU≥3, SYS≥2 | NIST 800-63B |
| V4 | MFA obligatorio para SU/SYS/BIZ_N3_N5 | NIST 800-63B |
| V5 | Sin ciclo herencia (DFS desde parent_id) | ANSI INCITS 359 |
| V6 | Átomos existen en bos_atom_catalog | — |
| V7 | max_transaction ≤ max_daily ≤ max_monthly | ISO 20022 |
| V8 | dual_approval_threshold solo si requires_dual_approval | SOX §404 |
| V9 | geo_fence_radius requiere center lat/lon | — |
| V10 | allowed_countries existen en bos_pais (ISO 3166-1) | ISO 3166-1 |
| V11 | allowed_cidrs formato válido | RFC 4632 |
| V12 | parent_id existe y no genera ciclo | — |

### 3.2 Al CLONAR

| # | Regla |
|---|-------|
| V13 | Se copian TODOS los bloques del template/oficial origen |
| V14 | Se sobreescriben solo los campos en `modifications` |
| V15 | role_code se auto-asigna (no copia del origen) |
| V16 | Si origen es template (is_template=true), el clon puede ser oficial o template |
| V17 | Si origen es oficial (is_template=false), el clon puede ser oficial o template |
| V18 | owner_tenant debe asignarse si is_template=false |

### 3.3 Al UPDATE

| # | Regla |
|---|-------|
| V19 | template_version++ automático |
| V20 | Historial WORM obligatorio (bos_rol_template_history) |
| V21 | Si cambian átomos → recalcular RolBitMask |
| V22 | Si cambian límites financieros → requiere aprobación |

### 3.4 Al DELETE (soft)

| # | Regla |
|---|-------|
| V23 | Soft delete: is_active=false. NO DELETE físico |
| V24 | Si tiene hijos → advertir, no bloquear |
| V25 | Si oficial (is_template=false) y sync_status=SYNCED → desactivar en KC |

---

## 4. CRUD Handlers JSON-RPC — 9 Métodos

| # | Método | Propósito |
|---|--------|-----------|
| 1 | `bauth.template.create` | Crear plantilla (is_template=true) |
| 2 | `bauth.template.read` | Leer template completo |
| 3 | `bauth.template.update` | Actualizar + versionar + historial WORM |
| 4 | `bauth.template.clone` | **Clonar** template→oficial u oficial→oficial/template |
| 5 | `bauth.template.validate` | Dry-run: 12 validaciones sin guardar |
| 6 | `bauth.template.approve` | Aprobar + disparar sync a KC+Tryton |
| 7 | `bauth.template.revoke` | Desactivar (soft delete) + sync |
| 8 | `bauth.template.list` | Listar con filtros (?tier, ?active, ?is_template) |
| 9 | `bauth.template.tree` | Árbol jerárquico (herederos de cada rol) |

---

## 5. Plan de Implementación — 5 Fases

| Fase | Átomos | Entregable | Horas |
|------|--------|-----------|-------|
| **F1** | T01-T05 | DDL (✅) + CRUD handlers create/read/update/validate + clone | 16h |
| **F2** | T06-T10 | approve/revoke/list + tree + seed 66 plantillas base | 12h |
| **F3** | T11-T13 | Sync Template→Keycloak (Admin REST API) | 8h |
| **F4** | T14-T16 | Sync Template→Tryton (5 capas enforcement) | 8h |
| **F5** | T17-T19 | Encriptación AES-256-GCM + Vault + tests integrales | 8h |

Tambien se debe sincronizar con la propia vbasd de datos del bauth
---

## 6. Referencias

| Documento / Estándar | Rol |
|----------------------|-----|
| ISO 24760-2:2025 §5.3 | Atributos de rol (mandatory/recommended) |
| ANSI INCITS 359-2004 | RBAC Level 3: herencia + SoD |
| NIST SP 800-63B Rev.4 | LoA, AAL, MFA, session, passkeys |
| ISO 20022 / FATF Rec.16 / SOX §404 | Límites financieros, dual-approval |
| ISO 3166-1 / ISO 4217 / RFC 4632 | Países, monedas, CIDRs |
| SBOS-008-ROLFRAMEWORK-v1_0.md | Arquitectura PAP/PIP/PDP/PEP, sync maestro |
| SBOS-ROLTEMPLATE-v5_0.md | Contrato v6.0: 14 bloques JSONB |
| BAUTH-CATALOGO-ROLES-EMPRESARIALES.md | 66 plantillas base predefinidas |
| BAUTH-CADENAS-JERARQUIA.md | 186 aristas DAG de herencia |
| SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md | BitMask Dual + DDL bos_privilege |
| BAUTH-CONTRATO-SYMBIOSIS.md | Relación bAuth↔Keycloak↔Tryton |

---

*Documento aprobado para implementación. Próximo paso: Fase 1 (9 handlers CRUD + clone).*
