# BAUTH-B10 — Especificación Profesional de CRUD para Sistema de Roles

**Versión:** 4.0.0 · **Fecha:** 2026-06-22 · **Autor:** sbos-coordinador  
**Clasificación:** CONFIDENCIAL · **Alcance:** SBOS Identity Core v3.0  
**Propósito:** Especificación completa, nivel producción, del CRUD de Roles del SBOS
cubriendo las 3 bases de datos (bAuth PostgreSQL, Keycloak, Tryton) con
trazabilidad, validación, sincronización en tiempo real, y componente UI de árbol jerárquico.

---

## 0. RESUMEN EJECUTIVO

### 0.1 Alcance

Este documento especifica **TODAS** las operaciones CRUD necesarias para administrar
el sistema de identidad del SBOS, desde los datos fundacionales (verbos, grupos, átomos)
hasta los roles de negocio y su sincronización con Keycloak y Tryton.

**Incluye:**
- CRUD de 9 tablas en 3 schemas
- 9 handlers JSON-RPC para RolTemplate
- Componente UI de árbol jerárquico (dependencias + herencia DAG)
- Auditoría de BD real (VPS 13.140.128.230)
- Correcciones de integridad referencial

### 0.2 Las 3 Bases de Datos

```
┌──────────────────────────────────────────────────────────────────┐
│                    BAUTH — ORQUESTADOR CENTRAL                     │
│                                                                   │
│  ┌──────────────────┐   ┌──────────────────┐   ┌──────────────┐ │
│  │  bAuth PostgreSQL │   │    Keycloak      │   │    Tryton     │ │
│  │  (fuente verdad)  │   │  (motor auth)    │   │  (motor neg)  │ │
│  │                   │   │                  │   │               │ │
│  │ • bos_privilege.* │   │ • Realms         │   │ • res.user    │ │
│  │ • bauth.*         │   │ • Roles          │   │ • res.group   │ │
│  │ • bauth.bos_rol_* │   │ • Groups         │   │ • ir.model    │ │
│  │                   │   │ • Auth Flows     │   │ • ir.rule     │ │
│  └──────┬────────────┘   └────────┬─────────┘   └──────┬────────┘ │
│         │                         │                      │         │
│         └─────────────────────────┴──────────────────────┘         │
│                           ▲                                         │
│                    Sincronización en < 5s                           │
└──────────────────────────────────────────────────────────────────┘
```

### 0.3 Principios Rectores

| # | Principio | Fuente |
|---|-----------|--------|
| P1 | **Fuente única de verdad:** bAuth PostgreSQL. KC y Tryton son réplicas. | ISO 24760-2 §8.3.1 |
| P2 | **Nunca DELETE físico.** Todo borrado es lógico (active=false / RETIRADO). | ISO 27001 A.8.15 |
| P3 | **Idempotencia obligatoria.** Toda operación puede repetirse sin daño. | ON CONFLICT DO NOTHING |
| P4 | **Trazabilidad completa.** Cada cambio: who, when, why, prev_hash (SHA-256). | ISO 27001 A.8.15 |
| P5 | **Sincronización atómica.** KC + Tryton juntos o no se actualizan. | Saga con compensación |
| P6 | **Validación pre-guardado.** 30+ reglas antes de tocar BD. | NIST AC-5, ISO 20022 |
| P7 | **ctx_id obligatorio.** Toda operación lleva contexto trazable. | SBOS-049, W3C Trace Context |
| P8 | **Interface Dual.** JSON-RPC 2.0 para daemons + WebSocket para CLI. | ADR-020 |
| P9 | **UI jerárquica obligatoria.** Componente de árbol para dependencias y herencia. | ANSI INCITS 359 |

---

## 1. AUDITORÍA DE BASE DE DATOS REAL

**Fuente:** VPS 13.140.128.230 · PostgreSQL 18.4 · Schema `bauth` + `bos_privilege`  
**Fecha de auditoría:** 2026-06-22 · **Total tablas:** 88 (entre ambos schemas)

### 1.1 Estado de Población — Tablas Clave

| Tabla | Schema | Registros | Estado |
|-------|--------|-----------|--------|
| `bos_domain` | bos_privilege | 12 | ✅ Poblado — 12 dominios fijos |
| `bos_verb` | bos_privilege | 4 | ✅ Poblado — CREATE, READ, UPDATE, DELETE |
| `bos_application` | bos_privilege | 6 | ✅ Poblado |
| `bos_group` | bos_privilege | 34 | ✅ Poblado |
| `bos_atom_catalog` | bos_privilege | 1059 | ✅ Poblado — catálogo completo |
| `bos_atom_policy` | bos_privilege | 6782 | ✅ Poblado — políticas por átomo |
| `bos_role` | bos_privilege | 10 | ✅ Poblado — roles base |
| `bos_role_atom` | bos_privilege | 212 | ✅ Poblado — asignaciones rol↔átomo |
| `rol_closure` | bauth | 9 | ✅ Poblado — 9 relaciones DAG |
| `auth_method` | bauth | 23 | ✅ Poblado — framework auth |
| `auth_policy` | bauth | 31 | ✅ Poblado — 31 políticas por tier |
| `compliance_map` | bauth | 34 | ✅ Poblado — 34 mapeos normativos |
| `crypto_algorithm` | bauth | 16 | ✅ Poblado — algoritmos criptográficos |
| `federation_protocol` | bauth | 16 | ✅ Poblado — protocolos federación |
| `saga_catalog` | bauth | 12 | ✅ Poblado — sagas de autenticación |
| **`bos_rol_template`** | **bauth** | **0** | ❌ **VACÍA — hay que poblar** |
| **`bos_rol_template_history`** | **bauth** | **0** | ❌ **VACÍA — se llena con CRUD** |

### 1.2 Estructura REAL de `bos_rol_template` (12 columnas)

La tabla en producción tiene una estructura **simplificada** respecto al DDL de diseño
de 47 columnas. Los 14 bloques del RolTemplate se almacenan dentro de la columna
JSONB `plantilla_json`, no como columnas separadas.

```
bauth.bos_rol_template — ESTRUCTURA REAL (12 columnas)
┌──────────────────┬──────────┬───────────┬──────────────────────────────┐
│ Columna          │ Tipo     │ Nullable  │ Descripción                  │
├──────────────────┼──────────┼───────────┼──────────────────────────────┤
│ id               │ TEXT     │ NOT NULL  │ PK. Formato: ROL-{SLUG}      │
│ tenant_id        │ TEXT     │ NOT NULL  │ '*' = global, UUID = tenant  │
│ nombre           │ TEXT     │ NOT NULL  │ Nombre descriptivo en español │
│ slug             │ TEXT     │ UNIQUE    │ Slug único para búsqueda      │
│ descripcion      │ TEXT     │ YES       │ Descripción larga             │
│ tier             │ TEXT     │ YES       │ CHECK: SU/SYS/BIZ_N5...       │
│ parent_id        │ TEXT     │ YES       │ FK lógico a bos_rol_template │
│ plantilla_json   │ JSONB    │ NOT NULL  │ ⭐ LOS 14 BLOQUES COMPLETOS   │
│ version          │ INTEGER  │ YES       │ Version number (1, 2, 3...)   │
│ active           │ BOOLEAN  │ YES       │ Soft-delete                   │
│ created_at       │ TIMESTAMPTZ│ YES     │ DEFAULT NOW()                 │
│ updated_at       │ TIMESTAMPTZ│ YES     │ Auto-actualizado              │
└──────────────────┴──────────┴───────────┴──────────────────────────────┘

Constraints:
  PK: bos_rol_template_pkey ON (id)
  UNIQUE: bos_rol_template_slug_key ON (slug)
  CHECK: chk_rt_tier ON (tier IN ('SU','SYS','BIZ_N5','BIZ_N4','BIZ_N3',
                                   'BIZ_N2','BIZ_N1','EXT_N0','M2M','VISITANTE'))
```

**IMPORTANTE:** Toda la complejidad (máscaras, LoA, MFA, restricciones financieras,
geográficas, SoD, delegación, etc.) vive dentro de `plantilla_json` como documento
JSONB estructurado. Ver §2 para el esquema JSONB completo.

### 1.3 Estructura de `bos_rol_template_history` (8 columnas)

```
bauth.bos_rol_template_history — ESTRUCTURA REAL
┌──────────────────┬──────────┬───────────┬──────────────────────────────┐
│ Columna          │ Tipo     │ Nullable  │ Descripción                  │
├──────────────────┼──────────┼───────────┼──────────────────────────────┤
│ history_id       │ BIGSERIAL│ NOT NULL  │ PK auto-incremental          │
│ template_id      │ TEXT     │ NOT NULL  │ FK → bos_rol_template(id)    │
│ version          │ INTEGER  │ NOT NULL  │ Número de versión            │
│ plantilla_json   │ JSONB    │ NOT NULL  │ Snapshot completo            │
│ changed_at       │ TIMESTAMPTZ│ —      │ DEFAULT NOW()                │
│ changed_by       │ TEXT     │ YES       │ Quién cambió                 │
│ change_reason    │ TEXT     │ YES       │ Motivo del cambio            │
│ change_type      │ TEXT     │ YES       │ CREATE/UPDATE/CLONE/REVOKE   │
└──────────────────┴──────────┴───────────┴──────────────────────────────┘

FK: bos_rol_template_history_template_id_fkey → bos_rol_template(id)
```

### 1.4 Problemas de Integridad Referencial Detectados

| # | Problema | Severidad | Detalle | Acción |
|---|----------|-----------|---------|--------|
| **I1** | `rol_closure` sin FK | 🔴 ALTA | `ancestro_id` y `descendiente_id` no referencian `bos_rol_template(id)`. Pueden insertarse IDs huérfanos. | Agregar FK: `ALTER TABLE bauth.rol_closure ADD CONSTRAINT fk_closure_ancestro FOREIGN KEY (ancestro_id) REFERENCES bauth.bos_rol_template(id)` |
| **I2** | `bos_rol_template.parent_id` sin FK | 🟡 MEDIA | parent_id no tiene FK formal. Riesgo de referencias rotas. | Agregar FK: `ALTER TABLE bauth.bos_rol_template ADD CONSTRAINT fk_rt_parent FOREIGN KEY (parent_id) REFERENCES bauth.bos_rol_template(id)` |
| **I3** | Tabla duplicada `bauth.bos_verbo` | 🟡 MEDIA | Tabla huérfana con 0 registros. La tabla activa es `bos_privilege.bos_verb` con 4 registros y FKs desde `bos_atom_catalog`. | Eliminar `bauth.bos_verbo`: `DROP TABLE IF EXISTS bauth.bos_verbo` |

### 1.5 Verificación de No-Duplicados en Tablas de Políticas

Las siguientes tablas relacionadas con políticas existen en la BD. Se verificó que
**NO hay duplicación**: cada tabla tiene un propósito distinto.

| Tabla | Schema | Propósito | ¿Duplicada? |
|-------|--------|-----------|-------------|
| `auth_policy` | bauth | Políticas de autenticación por tier (password, MFA, session) | ❌ Única |
| `bos_credential_policy` | bauth | Políticas de credenciales (longitud, rotación) | ❌ Única — distinto concern |
| `bos_atom_policy` | bos_privilege | Políticas por átomo (6782 registros con JSONB) | ❌ Única |
| `bos_policy_audit` | bauth | Auditoría de cambios de políticas | ❌ Única |
| `bos_policy_history` | bauth | Historial de versiones de políticas | ❌ Única |

**Conclusión:** No hay tablas duplicadas. Cada tabla modela un concern distinto
del framework. La tabla `bauth.bos_verbo` es la única redundante (está vacía,
nadie la referencia, y `bos_privilege.bos_verb` cumple su función).

---

## 2. ESQUEMA JSONB DEL ROL TEMPLATE — 14 Bloques en `plantilla_json`

### 2.1 Principio de Diseño

> La tabla tiene 12 columnas. La columna `plantilla_json` (JSONB) contiene
> **TODA la definición del rol** estructurada en 14 bloques.
> Esto permite evolución del esquema sin ALTER TABLE.

### 2.2 Estructura Completa

```json
{
  "$schema": "https://sbos.skull.bo/schemas/rol-template-v6.schema.json",
  "template_version": "6.0",

  "bloque_1_identidad": {
    "role_code": 1001,
    "role_name": { "es": "Cajero", "en": "Cashier" },
    "role_slug": "ROL-CAJERO-GENERICO",
    "tier": "BIZ_N1",
    "hierarchy_level": 5,
    "parent_id": null,
    "type_id": "TYPE-OPERATIVO",
    "path_ids": [],
    "is_template": true,
    "owner_tenant": null,
    "issuer": "bAuth",
    "created_by": "ADMIN.SISTEMA",
    "template_id": null
  },

  "bloque_2_vigencia": {
    "validity_period": {
      "type": "INDEFINITE",
      "start_time": "2026-06-22T00:00:00Z",
      "expiry_time": null,
      "review_date": "2027-06-22T00:00:00Z"
    },
    "loa_required": 1,
    "mfa_required": false,
    "mfa_methods": ["TOTP"],
    "step_up_enabled": false,
    "session_timeout_secs": 28800,
    "max_sessions": 1,
    "inactivity_timeout_secs": 900
  },

  "bloque_3_bitmask": {
    "mask_own_hex": "0x0000000000000000",
    "sam128_physical": null,
    "sam128_logical": null,
    "sam128_financial": null,
    "sam128_governance": null,
    "atom_positions": []
  },

  "bloque_4_financiero": {
    "max_transaction": 5000.00,
    "max_daily": 25000.00,
    "max_monthly": 500000.00,
    "currency": "BOB",
    "requires_dual_approval": false,
    "dual_approval_threshold": null
  },

  "bloque_5_temporal": {
    "shift_start": "08:00",
    "shift_end": "16:00",
    "max_session_hours": 8,
    "inactivity_timeout_min": 15
  },

  "bloque_6_geografico": {
    "allowed_countries": ["BO"],
    "geo_fence_center_lat": null,
    "geo_fence_center_lon": null,
    "geo_fence_radius_km": null
  },

  "bloque_7_red": {
    "allowed_cidrs": [],
    "vpn_required": false,
    "device_posture_required": false
  },

  "bloque_8_delegacion": {
    "delegable": false,
    "max_delegation_depth": 0,
    "delegation_ttl_hours": null
  },

  "bloque_9_sod": {
    "sod_group": "OPERATIVO",
    "sod_conflicts_with": ["AUDITOR_INVENTARIO"]
  },

  "bloque_10_auditoria": {
    "audit_level": "basic",
    "session_recording": false,
    "compliance_tags": ["FISCAL", "LATAM"],
    "risk_level": "LOW"
  },

  "bloque_11_sync": {
    "sync_status": "PENDING",
    "sync_error": null,
    "last_sync_at": null,
    "kc_realm_role": null,
    "tryton_group_id": null
  },

  "bloque_12_encriptacion": {
    "encrypted_fields": [],
    "encryption_key_ref": null,
    "encryption_algorithm": "AES-256-GCM"
  },

  "bloque_13_firma": {
    "digital_signature": {
      "signature": null,
      "algorithm": "EdDSA_Ed25519",
      "certificate_thumbprint": null,
      "timestamp": null
    }
  },

  "bloque_14_metadatos": {
    "created_at": "2026-06-22T00:00:00Z",
    "updated_at": "2026-06-22T00:00:00Z",
    "updated_by": "ADMIN.SISTEMA",
    "version_number": 1,
    "change_history": []
  }
}
```

### 2.3 Mapeo Columna SQL ↔ Bloque JSONB

| Columna SQL | Bloque(s) JSONB | Justificación |
|-------------|-----------------|---------------|
| `id` | `role_slug` en bloque_1 | ID canónico inmutable |
| `tenant_id` | Columna SQL — indexada | Para filtrado rápido multi-tenant |
| `nombre` | `role_name.es` en bloque_1 | Display name en español |
| `slug` | Derivado de `role_slug` | Para búsquedas URL-safe |
| `tier` | `tier` en bloque_1 | Indexado para filtros |
| `parent_id` | `parent_id` en bloque_1 | Para árbol jerárquico |
| `plantilla_json` | **TODO** (bloques 1-14) | Documento completo |
| `version` | `version_number` en bloque_14 | Versionado numérico |
| `active` | Columna SQL — indexada | Soft-delete rápido |

**Regla:** Lo que se necesita para queries SQL frecuentes (filtros, ordenamiento)
va en columnas. Lo que es contenido semántico del rol va en `plantilla_json`.

---

## 3. COMPONENTE UI — ÁRBOL JERÁRQUICO DE ROLES

### 3.1 Justificación

El sistema de roles del SBOS es **intrínsecamente jerárquico** por tres razones:

| # | Dimensión jerárquica | Por qué necesita árbol |
|---|---------------------|----------------------|
| 1 | **Herencia H-RBAC** | `parent_id` → DAG de herencia. Un rol hereda bits del padre (AND NOT). Visualizar la cadena es esencial para auditar. |
| 2 | **Dependencias de políticas** | Las políticas en `bos_atom_policy` se encadenan por `priority`. Visualizar el orden de evaluación evita conflictos. |
| 3 | **Jerarquía organizacional** | `hierarchy_level` (1-5) + `path_ids[]`. El organigrama completo de roles por tenant. |

### 3.2 Especificación del Componente

```
┌──────────────────────────────────────────────────────────────────┐
│                    ÁRBOL DE ROLES — TENANT SKULL                   │
│                                                                   │
│  🔍 Buscar rol: [________________] [Filtrar por tier ▼]          │
│                                                                   │
│  ┌─▼ ROL-SUPERUSUARIO (SU) · 0xFFFFFFFF · 0 hijos               │
│  ├───▼ ROL-SYS-ADMIN-PROYECTO (SYS) · 2 hijos                   │
│  │   ├─── ROL-SYS-ADMIN-BAUTH (SYS) · 🟢 SYNCED                  │
│  │   └─── ROL-SYS-ADMIN-BIEDATA (SYS) · 🟡 PENDING               │
│  ├───▼ ROL-SYS-ADMIN-SEGURIDAD (SYS) · 1 hijo                    │
│  │   └─── ROL-AUDITOR-INTERNO (BIZ_N3) · 🟢 SYNCED               │
│  ├───▼ ROL-GERENTE-GENERICO (BIZ_N5) · 3 hijos · 📋 Plantilla    │
│  │   ├───▼ ROL-GERENTE-REGIONAL (BIZ_N4) · 2 hijos               │
│  │   │   ├─── ROL-SUPERVISOR-TIENDA (BIZ_N3) · 🟢 SYNCED         │
│  │   │   └─── ROL-SUPERVISOR-ALMACEN (BIZ_N3) · 🔴 ERROR         │
│  │   └─── ROL-JEFE-LOCAL (BIZ_N4) · 0 hijos                      │
│  ├───▼ ROL-CAJERO-GENERICO (BIZ_N1) · 3 hijos · 📋 Plantilla     │
│  │   ├─── ROL-CAJERO-SUC-CENTRO (BIZ_N1) · 🟢 SYNCED             │
│  │   ├─── ROL-CAJERO-SUC-NORTE (BIZ_N1) · 🟢 SYNCED              │
│  │   └─── ROL-CAJERO-BANCO (BIZ_N1) · 🟡 PENDING                 │
│  └─── ROL-CLIENTE-MINORISTA (EXT_N0) · 0 hijos · 📋 Plantilla    │
│                                                                   │
│  ─────────────────────────────────────────────────────────────── │
│  [＋ Nuevo Rol]  [📋 Clonar]  [✏️ Editar]  [✅ Aprobar]  [🗑️ Revocar] │
│  [🔄 Sincronizar]  [📊 Ver Máscara]  [📜 Historial]               │
└──────────────────────────────────────────────────────────────────┘
```

### 3.3 Datos del Nodo

Cada nodo del árbol debe mostrar:

| Campo | Fuente | Formato |
|-------|--------|---------|
| `id` | `bos_rol_template.id` | Texto principal |
| `tier` | `bos_rol_template.tier` | Badge de color (SU=rojo, SYS=naranja, BIZ_N5-N1=azul, EXT_N0=verde) |
| `sync_status` | `plantilla_json.bloque_11.sync_status` | Icono: 🟢 SYNCED, 🟡 PENDING, 🔴 ERROR, ⚪ no sync (template) |
| `mask_summary` | `plantilla_json.bloque_3.mask_own_hex` | Tooltip con bits activos |
| `children_count` | Count de `parent_id = este.id` | Número de hijos (cargado async) |
| `is_template` | `plantilla_json.bloque_1.is_template` | Badge "📋 Plantilla" |
| `active` | `bos_rol_template.active` | Nodo atenuado si false |

### 3.4 Comportamiento del Árbol

| Acción | Comportamiento |
|--------|---------------|
| **Expandir nodo** | Carga asíncrona de hijos vía `bauth.template.tree` con `root_id=<node.id>&depth=1` |
| **Click en nodo** | Muestra panel lateral derecho con detalles completos (14 bloques) |
| **Doble click** | Abre editor inline si el usuario tiene permiso |
| **Arrastrar** | Permite cambiar `parent_id` (con validación anti-ciclo en tiempo real) |
| **Botón derecho** | Menú contextual: Clonar, Editar, Aprobar, Revocar, Ver Máscara, Historial |
| **Filtro** | Por tier, status, sync_status, is_template |
| **Búsqueda** | Por id, nombre, slug — resalta nodos coincidentes y expande ancestros |

### 3.5 Tecnología Recomendada

| Capa | Tecnología | Justificación |
|------|-----------|---------------|
| **Frontend** | React 19 + TypeScript | Core UI SBOS stack |
| **Componente** | `react-arborist` o `react-complex-tree` | Soporte nativo para drag-drop, lazy loading, virtualización |
| **Backend** | JSON-RPC `bauth.template.tree` + `bauth.template.list` | Datos vía API existente |
| **WebSocket** | `bauth.template.watch` (futuro) | Actualizaciones en tiempo real |

---

## 4. CATÁLOGO COMPLETO DE CRUD — 9 Tablas + 1 Componente UI

### 4.1 Matriz Consolidada de Operaciones CRUD

| # | Tabla | Schema | Registros | list | get | create | update | delete/revoke | validate | tree |
|---|-------|--------|-----------|------|-----|--------|--------|---------------|----------|------|
| N0 | `bos_domain` | bos_privilege | 12 | ✅ | ✅ | — | — | — | — | — |
| N1 | `bos_verb` | bos_privilege | 4 | ✅ | — | ✅ | — | — | — | — |
| N2a | `bos_application` | bos_privilege | 6 | ✅ | ✅ | ✅ | ✅ | ✅ | — | — |
| N2b | `bos_group` | bos_privilege | 34 | ✅ | ✅ | ✅ | ✅ | — | — | — |
| N3 | `bos_atom_catalog` | bos_privilege | 1059 | ✅ | ✅ | ✅ | ✅ | — | ✅ | — |
| N4 | `bos_atom_policy` | bos_privilege | 6782 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| N5 | `bos_role` | bos_privilege | 10 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — |
| N6 | `bos_role_atom` | bos_privilege | 212 | ✅ | — | ✅ | — | ✅ | ✅ | — |
| N7 | `rol_closure` | bauth | 9 | ✅ | — | ✅ | — | ✅ | ✅ | ✅ |
| N8 | `bos_rol_template` | bauth | 0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**Leyenda:** ✅ requerido · — no aplica (datos finitos o gestionados por otra vía)

### 4.2 Especificación Detallada por Tabla

#### N1 — bos_privilege.bos_verb (Vocabulario de Verbos)

| Columna | Tipo | Restricción |
|---------|------|------------|
| `verb_code` | SMALLINT | PK, 1-255 |
| `verb_name` | VARCHAR(32) | UNIQUE, NOT NULL |
| `verb_slug` | VARCHAR(32) | NOT NULL |

**Handlers:**
| Método | Parámetros | Respuesta | Validación |
|--------|-----------|-----------|-----------|
| `bauth.verb.list` | — | `{ verbs: [...], count: 4 }` | — |
| `bauth.verb.create` | `{ verb_code, verb_name, verb_slug }` | `{ verb_code, verb_name }` | verb_code único, 1-255, verb_name único |

**Estado actual:** 4 verbos (CREATE/READ/UPDATE/DELETE). Suficiente. Solo se agregan nuevos bajo revisión del ARB.

---

#### N2a — bos_privilege.bos_application (Aplicaciones)

| Columna | Tipo | Restricción |
|---------|------|------------|
| `app_code` | SMALLINT | PK, 1-511 |
| `app_name` | VARCHAR(64) | NOT NULL |
| `app_slug` | VARCHAR(32) | NOT NULL |
| `tenant_id` | UUID | NOT NULL |
| `active` | BOOLEAN | DEFAULT TRUE |
| `registered_at` | TIMESTAMPTZ | DEFAULT NOW() |

**Handlers:** `bauth.app.list`, `bauth.app.get`, `bauth.app.create`, `bauth.app.update`, `bauth.app.deactivate`

---

#### N2b — bos_privilege.bos_group (Grupos Funcionales)

| Columna | Tipo | Restricción |
|---------|------|------------|
| `group_code` | SMALLINT | PK (con app_code), 1-2047 |
| `app_code` | SMALLINT | PK, FK → bos_application |
| `group_name` | VARCHAR(128) | NOT NULL |

**Handlers:** `bauth.group.list` (filtro por app_code), `bauth.group.get`, `bauth.group.create`, `bauth.group.update`

---

#### N3 — bos_privilege.bos_atom_catalog (Catálogo de Átomos)

| Columna | Tipo | Restricción |
|---------|------|------------|
| `atom_code` | INTEGER | PK (3-col), 1-16,777,215 |
| `app_code`, `group_code` | SMALLINT | PK, FK → bos_group |
| `domain_code` | SMALLINT | FK → bos_domain |
| `verb_code` | SMALLINT | FK → bos_verb |
| `atom_name` | VARCHAR(255) | NOT NULL |
| `atom_slug` | VARCHAR(255) | UNIQUE(app_code) |
| `atom_position` | INTEGER | UNIQUE, INMUTABLE, ≥0 |
| `contextual_mask` | INTEGER | NOT NULL |
| `logical_mask` | INTEGER | NOT NULL |

**Handlers:** `bauth.atom.list` (filtros: app_code, group_code, domain_code, verb_code, search), `bauth.atom.get`, `bauth.atom.create`, `bauth.atom.update` (atom_position es INMUTABLE).

---

#### N4 — bos_privilege.bos_atom_policy (Políticas por Átomo)

| Columna | Tipo | Restricción |
|---------|------|------------|
| `policy_id` | UUID | PK, DEFAULT gen_random_uuid() |
| `app_code`, `group_code`, `atom_code` | — | FK → bos_atom_catalog |
| `policy_domain` | SMALLINT | FK → bos_domain |
| `policy_slug` | VARCHAR(64) | UNIQUE (4-col) |
| `policy_data` | JSONB | NOT NULL, CHECK estructural |
| `active` | BOOLEAN | DEFAULT TRUE |

**CHECK estructural de `policy_data`:**
```json
{
  "$schema": "obligatorio",
  "priority": "obligatorio — integer, orden de evaluación",
  "action": "obligatorio — 'allow' | 'deny' | 'escalate' | 'log'",
  "evaluate": "obligatorio — objeto con conditions",
  "params": "obligatorio — objeto con parámetros"
}
```

**Handlers:** `bauth.policy.list`, `bauth.policy.get`, `bauth.policy.create`, `bauth.policy.update`, `bauth.policy.validate` (dry-run), `bauth.policy.deactivate`

---

#### N5 — bos_privilege.bos_role (Roles Base por Tenant)

| Columna | Tipo | Restricción |
|---------|------|------------|
| `role_id` | UUID | PK |
| `tenant_id` | UUID | NOT NULL |
| `role_code` | INTEGER | UNIQUE(tenant_id), >0 |
| `role_name` | VARCHAR(128) | NOT NULL |
| `role_slug` | VARCHAR(64) | UNIQUE(tenant_id) |
| `active` | BOOLEAN | DEFAULT TRUE |
| `created_at`, `updated_at` | TIMESTAMPTZ | — |

**Handlers:** `bauth.role.list`, `bauth.role.get`, `bauth.role.create`, `bauth.role.update`, `bauth.role.deactivate`

---

#### N6 — bos_privilege.bos_role_atom (Asignación Rol↔Átomo)

| Columna | Tipo | Restricción |
|---------|------|------------|
| `role_id` | UUID | PK, FK → bos_role |
| `app_code`, `group_code`, `atom_code` | — | PK, FK → bos_atom_catalog |
| `atom_position` | INTEGER | NOT NULL (desnormalizado) |
| `allowed` | BOOLEAN | DEFAULT FALSE |
| `granted_by` | UUID | — |
| `granted_at` | TIMESTAMPTZ | DEFAULT NOW() |

**Handlers:** `bauth.role_atom.list` (por role_id), `bauth.role_atom.grant` (allowed=true), `bauth.role_atom.revoke` (allowed=false), `bauth.role_atom.bulk_grant`, `bauth.role_atom.bulk_revoke`

---

#### N7 — bauth.rol_closure (Cierre Transitivo de Herencia)

| Columna | Tipo | Restricción |
|---------|------|------------|
| `ancestro_id` | TEXT | PK |
| `descendiente_id` | TEXT | PK |
| `profundidad` | INTEGER | NOT NULL, ≥0 |

**⚠️ Pendiente:** Agregar FK a `bos_rol_template(id)` para ambas columnas.

**Handlers:** `bauth.closure.tree` (desde un rol), `bauth.closure.add_parent`, `bauth.closure.remove_parent`, `bauth.closure.validate` (anti-ciclo).

---

#### N8 — bauth.bos_rol_template (Plantillas de Rol)

12 columnas (ver §1.2). **9 handlers JSON-RPC** (ver §5).

---

## 5. CATÁLOGO DE HANDLERS JSON-RPC — 9 Métodos para RolTemplate

### 5.1 `bauth.template.create`

**Propósito:** Crear plantilla base (is_template=true) o rol oficial (is_template=false).

**Parámetros:**
| Campo | Tipo | Obligatorio |
|-------|------|------------|
| `nombre` | string | ✅ |
| `slug` | string | ✅ (único) |
| `tenant_id` | string | ✅ |
| `tier` | string | ✅ |
| `descripcion` | string | ❌ |
| `parent_id` | string | ❌ |
| `plantilla_json` | object | ✅ — esquema de 14 bloques |
| `ctx_id` | string | ✅ |

**Validaciones:** V01-V20 (ver §6).
**Efectos:** INSERT en bos_rol_template + INSERT en history.
**Respuesta:** `{ "id": "ROL-CAJERO-SUC-CENTRO", "slug": "...", "version": 1, "sync_status": "PENDING" }`

---

### 5.2 `bauth.template.read`

**Propósito:** Leer template completo por id o slug.

**Parámetros:** `{ "id": "..." | "slug": "...", "ctx_id": "..." }`

**Respuesta:** Registro completo con `plantilla_json` expandido + campos calculados:
- `effective_mask` — máscara con herencia (desde closure table)
- `atom_count` — número de átomos asignados
- `children` — lista de hijos directos (solo ids y nombres)

---

### 5.3 `bauth.template.update`

**Propósito:** Modificar template + versionado automático + historial.

**Parámetros:**
| Campo | Tipo | Obligatorio |
|-------|------|------------|
| `id` | string | ✅ |
| `changes` | object | ✅ — campos modificados (merge parcial en plantilla_json) |
| `change_reason` | string | ✅ |
| `ctx_id` | string | ✅ |

**Flujo:** Leer → merge changes → validar V01-V20 → version++ → INSERT history → UPDATE → si is_template=false → dispatcar sync.

---

### 5.4 `bauth.template.clone`

**Propósito:** Clonar template/oficial → nuevo registro. **EL MÁS IMPORTANTE.**

```json
{
  "method": "bauth.template.clone",
  "params": {
    "source_id": "ROL-CAJERO-GENERICO",
    "target": {
      "nombre": "Cajero Sucursal Centro",
      "slug": "ROL-CAJERO-SUC-CENTRO",
      "tenant_id": "uuid",
      "is_template": false
    },
    "modifications": {
      "bloque_4_financiero.max_transaction": 2000.00,
      "bloque_5_temporal.shift_start": "08:00",
      "bloque_6_geografico.geo_fence_radius_km": 50
    },
    "save_as_template": false,
    "ctx_id": "..."
  }
}
```

**Lógica:**
```rust
fn clone_template(source: &RolTemplate, target: &Target, modifications: &Value) -> RolTemplate {
    let mut nuevo = source.deep_clone();
    // NO se copian: id, slug, created_at, updated_at, version
    nuevo.id = generate_id();
    nuevo.slug = target.slug;
    nuevo.version = 1;
    nuevo.parent_id = Some(source.id.clone());
    nuevo.template_id = Some(source.id.clone());
    nuevo.activo = true;
    // Merge de modifications en plantilla_json (deep merge)
    deep_merge(&mut nuevo.plantilla_json, modifications);
    nuevo
}
```

---

### 5.5 `bauth.template.validate`

**Propósito:** Dry-run de validación sin guardar.

**Parámetros:** `{ "template": {...}, "mode": "create"|"update"|"clone", "ctx_id": "..." }`

**Respuesta:**
```json
{
  "valid": false,
  "errors": [
    {"code": "V09", "rule": "Tier→LoA", "field": "bloque_2_vigencia.loa_required", "message": "SU requiere LoA ≥ 3", "severity": "ERROR"}
  ],
  "warnings": [
    {"code": "W01", "message": "session_timeout > 8h excede recomendación NIST", "severity": "WARNING"}
  ],
  "checked_rules": 30,
  "duration_us": 420
}
```

---

### 5.6 `bauth.template.approve`

**Propósito:** Transición a status=AUTORIZADO + dispatch sync saga.

**Parámetros:** `{ "id": "...", "approved_by": "...", "ctx_id": "..." }`

**Pre-condiciones:** Status ∈ {REVISADO, DESARROLLADO} · usuario con permiso de approve para ese tier.

**Efectos:** UPDATE status → AUTORIZADO · INSERT history · DISPATCH saga sync_to_kc_tryton (async).

---

### 5.7 `bauth.template.revoke`

**Propósito:** Soft-delete. Status → RETIRADO. Desactivar en KC+Tryton.

**Parámetros:** `{ "id": "...", "reason": "...", "ctx_id": "..." }`

---

### 5.8 `bauth.template.list`

**Filtros:** `tier`, `status`, `is_template`, `tenant_id`, `parent_id`, `search` (nombre/slug), `limit`, `offset`, `order_by`.

**Control de acceso multi-tenant:**
```sql
WHERE (is_template = TRUE AND tenant_id = '*')
   OR (tenant_id = $ctx_tenant_id)
```

---

### 5.9 `bauth.template.tree`

**Propósito:** Árbol jerárquico completo. Soporta UI de árbol.

**Parámetros:** `{ "root_id": "..." | null, "depth": 5, "include_counts": true, "ctx_id": "..." }`

**Respuesta:** Estructura anidada con `children` arrays + `total_nodes` + `max_depth`.

---

## 6. MOTOR DE VALIDACIÓN — 30 Reglas

### 6.1 Validaciones Estructurales (Schema)

| # | Regla | Capa |
|---|-------|------|
| V01 | `slug` único en bos_rol_template | SQL UNIQUE |
| V02 | `tier` dentro del ENUM (10 valores) | SQL CHECK |
| V03 | `plantilla_json` válido contra JSON Schema 2020-12 | Rust |
| V04 | `bloque_2_vigencia.loa_required` entre 1 y 4 | Rust |
| V05 | `bloque_10_auditoria.audit_level` en (none/basic/full) | Rust |
| V06 | `bloque_11_sync.sync_status` en (PENDING/SYNCING/SYNCED/ERROR/DRIFT) | Rust |
| V07 | `template_version` = '6.0' | Rust |
| V08 | `nombre` no vacío, max 128 chars | Rust |

### 6.2 Validaciones de Negocio (Semántica)

| # | Regla | Fuente |
|---|-------|--------|
| V09 | Tier→LoA: SU≥3, SYS≥2, BIZ_N1_N2≥1 | NIST 800-63B-4 |
| V10 | MFA obligatorio: SU/SYS/BIZ_N3_N5 → mfa_required=true | NIST 800-63B-4 §5.1 |
| V11 | Sin ciclo de herencia: DFS desde parent_id no alcanza self | ANSI INCITS 359 §2 |
| V12 | Átomos en atom_positions existen en bos_atom_catalog | Rust FK |
| V13 | max_transaction ≤ max_daily ≤ max_monthly | ISO 20022 |
| V14 | dual_approval_threshold solo si requires_dual_approval=true | SOX §404 |
| V15 | geo_fence_radius requiere center (lat Y lon) | — |
| V16 | allowed_countries existen en bos_pais | ISO 3166-1 |
| V17 | allowed_cidrs formato RFC 4632 válido cada elemento | RFC 4632 |
| V18 | start_time ≤ expiry_time (si expiry_time presente) | ISO 24760-2 |
| V19 | parent_id existe en bos_rol_template | Rust |
| V20 | session_timeout_secs ≤ 43200 (12h), inactivity ≤ session | NIST 800-63B-4 §7 |

### 6.3 Validaciones de Clonación

| # | Regla |
|---|-------|
| V21 | Se copian TODOS los bloques del origen |
| V22 | Solo se sobreescriben campos en `modifications` |
| V23 | id y slug auto-asignados (NO copia del origen) |
| V24 | version se reinicia a 1 |
| V25 | Si is_template=true → owner_tenant=NULL. Si false → owner_tenant obligatorio |
| V26 | Clon entre tenants solo desde plantillas base (tenant_id='*') |
| V27 | template_id apunta al origen |

### 6.4 Validaciones de Update

| # | Regla |
|---|-------|
| V28 | version++ automático |
| V29 | INSERT en bos_rol_template_history obligatorio |
| V30 | Si cambian atom_positions → recalcular mask_own_hex + SAM-128 |

---

## 7. MODELO DE CLONACIÓN

### 7.1 Taxonomía

```
┌──────────────────────────────────────────────────────────────────┐
│                    TIPOS DE ROL TEMPLATE                          │
│                                                                   │
│  ┌─────────────────────┐          ┌─────────────────────┐        │
│  │  PLANTILLA BASE      │          │  ROL OFICIAL         │        │
│  │  (is_template=true)  │          │  (is_template=false) │        │
│  │                      │  CLONAR  │                      │        │
│  │  • 66 predefinidas   │────────→ │  • Asignable a users │        │
│  │  • tenant_id='*'     │          │  • tenant_id fijo    │        │
│  │  • owner_tenant=NULL │          │  • SÍ se sincroniza  │        │
│  │  • NO se sincroniza  │          │  • Admin Tenant crea │        │
│  │  • Solo Admin Sistema│          │                      │        │
│  └─────────────────────┘          └─────────┬────────────┘        │
│                                              │                     │
│                                CLONAR (desde oficial)              │
│                                              ▼                     │
│                                   ┌─────────────────────┐        │
│                                   │  NUEVO ROL OFICIAL   │        │
│                                   │  (is_template=false) │        │
│                                   │  • Mismo tenant      │        │
│                                   │  • Ajustes mínimos   │        │
│                                   └─────────────────────┘        │
└──────────────────────────────────────────────────────────────────┘
```

### 7.2 Reglas de Privacidad Multi-Tenant

- **Plantillas base:** Visibles para todos los tenants. Solo Admin Sistema modifica.
- **Roles oficiales:** Privados del tenant_id. No visibles para otros tenants.
- **Clonación cross-tenant:** PROHIBIDA excepto desde plantillas base.
- **Visibilidad en queries:** `WHERE tenant_id = $ctx.tenant_id OR (is_template = TRUE AND tenant_id = '*')`.

---

## 8. SINCRONIZACIÓN — bAuth → Keycloak + Tryton

### 8.1 Máquina de Estados

```
PENDING ──→ SYNCING ──→ SYNCED
  ▲                       │
  │                       ├──→ DRIFT (detectado en reconcile)
  └─────── ERROR ◂────────┘
```

### 8.2 Mapeo RolTemplate → Keycloak

| RolTemplate | Keycloak | Operación API |
|-------------|----------|---------------|
| `id` | Composite Role `name` | `POST /admin/realms/{realm}/roles` |
| `bloque_3.mask_own_hex` (bits) | N× Realm Roles | `POST /roles` por bit |
| `parent_id` | Composite hierarchy | `POST /roles/{parent}/composites` |
| `bloque_2.loa_required` | Auth Flow | `POST /authentication/flows` |
| `bloque_2.mfa_required` | Required action | `PUT /authentication/flows/{id}/executions` |

### 8.3 Mapeo RolTemplate → Tryton (5 Capas)

| Capa | RolTemplate → | Tryton | API |
|------|--------------|--------|-----|
| 1. Grupo | `id` → `res.group` name | `model.res.group.create` | JSON-RPC |
| 2. Acceso modelos | `mask` bits → `ir.model.access` | `model.ir.model.access.create` | JSON-RPC |
| 3. Reglas registro | `bloque_4` → `ir.rule` domain | `model.ir.rule.create` | JSON-RPC |
| 4. Restricciones campo | `bloque_7` → `ir.model.field.access` | `model.ir.model.field.access.create` | JSON-RPC |
| 5. Acciones | `bloque_10` → actions | `model.res.group.write` | JSON-RPC |

### 8.4 Saga de Sincronización

```
PASO 1: Verificar KC (5s) ──→ FAIL: rollback
PASO 2: Verificar Tryton (5s) ──→ FAIL: rollback
PASO 3: sync_role_to_kc() (15s) ──→ FAIL: rollback KC
PASO 4: sync_role_to_tryton() (15s) ──→ FAIL: rollback KC
PASO 5: Verificar consistencia (5s) ──→ SYNCED o DRIFT

COMPENSACIÓN:
  paso_3: DELETE roles KC creados
  paso_4: DELETE grupos Tryton + rollback KC
```

---

## 9. PLAN DE IMPLEMENTACIÓN — 8 Fases

### FASE 0: Correcciones de Integridad (2h)

**⚠️ Pre-requisito para todo lo demás.**

| # | Tarea | SQL / Acción |
|---|-------|-------------|
| F0.T1 | Agregar FK a `rol_closure` | `ALTER TABLE bauth.rol_closure ADD CONSTRAINT fk_closure_ancestro FOREIGN KEY (ancestro_id) REFERENCES bauth.bos_rol_template(id)` |
| F0.T2 | Agregar FK a `rol_closure` (descendiente) | `ALTER TABLE bauth.rol_closure ADD CONSTRAINT fk_closure_descendiente FOREIGN KEY (descendiente_id) REFERENCES bauth.bos_rol_template(id)` |
| F0.T3 | Agregar FK a `parent_id` | `ALTER TABLE bauth.bos_rol_template ADD CONSTRAINT fk_rt_parent FOREIGN KEY (parent_id) REFERENCES bauth.bos_rol_template(id)` |
| F0.T4 | Limpiar tabla huérfana | `DROP TABLE IF EXISTS bauth.bos_verbo` |

---

### FASE 1: CRUD Tablas Base (10h)

| # | Tarea | Handler(s) | Archivo |
|---|-------|-----------|---------|
| F1.T1 | `bauth.verb.list` + `bauth.verb.create` | 2 | `foundation_crud.rs` |
| F1.T2 | `bauth.app.list/get/create/update/deactivate` | 5 | `foundation_crud.rs` |
| F1.T3 | `bauth.group.list/get/create/update` | 4 | `foundation_crud.rs` |
| F1.T4 | `bauth.atom.list/get/create/update` | 4 | `foundation_crud.rs` |
| F1.T5 | `bauth.policy.list/get/create/update/validate/deactivate` | 6 | `foundation_crud.rs` |

**Total F1:** 21 handlers · 10 horas

---

### FASE 2: Roles Base + Role Atom + Closure (8h)

| # | Tarea | Handler(s) | Archivo |
|---|-------|-----------|---------|
| F2.T1 | `bauth.role.list/get/create/update/deactivate` | 5 | `role_crud.rs` |
| F2.T2 | `bauth.role_atom.list/grant/revoke/bulk_grant/bulk_revoke` | 5 | `role_crud.rs` |
| F2.T3 | `bauth.closure.tree/add_parent/remove_parent/validate` | 4 | `closure_crud.rs` |

**Total F2:** 14 handlers · 8 horas

---

### FASE 3: RolTemplate — Core CRUD (12h)

| # | Método | Complejidad | Horas |
|---|--------|------------|-------|
| F3.T1 | `bauth.template.create` | Alta (validación + history + JSONB) | 3h |
| F3.T2 | `bauth.template.read` | Baja (SELECT + computed fields) | 1h |
| F3.T3 | `bauth.template.update` | Alta (merge + version + history + sync) | 2h |
| F3.T4 | `bauth.template.clone` | **Muy Alta** (deep clone + merge + auto-assign) | 3h |
| F3.T5 | `bauth.template.validate` | Media (30 reglas dry-run) | 1.5h |
| F3.T6 | `bauth.template.approve` | Media (transición + dispatch saga) | 1.5h |

---

### FASE 4: RolTemplate — Consultas (4h)

| # | Método | Complejidad | Horas |
|---|--------|------------|-------|
| F4.T1 | `bauth.template.revoke` | Media (soft-delete + desactivar KC+Tryton) | 1.5h |
| F4.T2 | `bauth.template.list` | Media (8 filtros + paginación + multi-tenant) | 1.5h |
| F4.T3 | `bauth.template.tree` | Alta (recursivo + closure table + conteos) | 1h |

---

### FASE 5: Seed 66 Plantillas Base (8h)

| # | Grupo | Cantidad | Ejemplos |
|---|-------|----------|----------|
| F5.T1 | Sistémicas (S001–S048) | 9 | SU, Plataforma, Módulo, Tenant, Bootstrap |
| F5.T2 | Internas prioritarias | 11 | Gerente, Supervisor, Cajero, Facturación, Contable |
| F5.T3 | Internas secundarias | 13 | Operario, Hotel, Construcción, Rural |
| F5.T4 | Externas (N0) | 23 | Cliente, Proveedor, Alumno, Paciente, Ciudadano |
| F5.T5 | Doble dominio + Visitante | 10 | Contratista, Visitante VIP |

---

### FASE 6: Sincronización KC + Tryton (16h)

| # | Tarea | Horas |
|---|-------|-------|
| F6.T1 | `KeycloakSyncEngine` — Admin REST API client | 4h |
| F6.T2 | `sync_role_to_kc()` — Composite Role + Realm Roles + Auth Flows | 3h |
| F6.T3 | `TrytonSyncEngine` — JSON-RPC client | 4h |
| F6.T4 | `sync_role_to_tryton()` — 5 capas | 3h |
| F6.T5 | Saga `sync_rol_template` con compensación | 2h |

---

### FASE 7: Encriptación + Vault + UI Árbol (10h)

| # | Tarea | Horas |
|---|-------|-------|
| F7.T1 | AES-256-GCM para campos sensibles en plantilla_json | 3h |
| F7.T2 | Vault Transit integración | 2h |
| F7.T3 | **Componente UI Árbol Jerárquico** (React + `react-arborist`) | 5h |
| F7.T4 | Tests integrales: create→validate→approve→sync→reconcile→revoke | Extra |

---

### FASE 8: Tests de Regresión (4h)

| # | Tarea |
|---|-------|
| F8.T1 | 100 combinaciones de validación (V01-V30) |
| F8.T2 | 50 escenarios de clonación |
| F8.T3 | 30 escenarios de herencia DAG |
| F8.T4 | 20 escenarios de sync KC+Tryton |

---

## 10. ESTRUCTURA DE ARCHIVOS

```
BauthAgent/src/
├── server/
│   └── handlers/
│       ├── foundation_crud.rs    ← F1: 21 handlers (verb, app, group, atom, policy)
│       ├── role_crud.rs          ← F2: 10 handlers (role + role_atom)
│       ├── closure_crud.rs       ← F2: 4 handlers (closure tree)
│       └── rol_template.rs       ← F3+F4: 9 handlers RolTemplate
├── db/
│   └── mod.rs                    ← Extender con queries para 9 tablas
├── sync/
│   ├── mod.rs
│   ├── keycloak_engine.rs        ← F6: KC Admin REST API
│   └── tryton_engine.rs          ← F6: Tryton JSON-RPC client
├── validation/
│   └── mod.rs                    ← Motor de 30 validaciones
├── crypto/
│   └── vault_transit.rs          ← F7: AES-256-GCM + Vault
└── main.rs                       ← Registrar ~54 handlers

UI/
├── src/
│   └── components/
│       └── RoleTree/
│           ├── RoleTree.tsx          ← Componente principal
│           ├── RoleNode.tsx          ← Nodo individual
│           ├── RoleDetailPanel.tsx    ← Panel lateral con 14 bloques
│           ├── RoleContextMenu.tsx    ← Menú contextual
│           └── roleTree.hooks.ts     ← useRoleTree hook (datos + filtros)
```

---

## 11. CORRECCIONES SQL INMEDIATAS (Fase 0)

```sql
-- Ejecutar en VPS antes de empezar Fase 1:

-- 1. FK en rol_closure (ancestro)
ALTER TABLE bauth.rol_closure 
  ADD CONSTRAINT fk_closure_ancestro 
  FOREIGN KEY (ancestro_id) REFERENCES bauth.bos_rol_template(id)
  ON DELETE CASCADE;

-- 2. FK en rol_closure (descendiente)
ALTER TABLE bauth.rol_closure 
  ADD CONSTRAINT fk_closure_descendiente 
  FOREIGN KEY (descendiente_id) REFERENCES bauth.bos_rol_template(id)
  ON DELETE CASCADE;

-- 3. FK en parent_id de bos_rol_template
ALTER TABLE bauth.bos_rol_template 
  ADD CONSTRAINT fk_rt_parent 
  FOREIGN KEY (parent_id) REFERENCES bauth.bos_rol_template(id)
  ON DELETE SET NULL;

-- 4. Limpiar tabla huérfana
DROP TABLE IF EXISTS bauth.bos_verbo;

-- 5. Verificar integridad post-corrección
SELECT 'FKs corregidas' as status,
       count(*) as total_fks
FROM information_schema.table_constraints 
WHERE constraint_type = 'FOREIGN KEY' 
  AND table_name IN ('rol_closure', 'bos_rol_template');
```

---

## 12. REFERENCIAS NORMATIVAS

| # | Estándar | Versión | Aplicación |
|---|----------|---------|-----------|
| 1 | ISO/IEC 24760-2 | 2025 | Atributos de rol, lifecycle, reference identifier |
| 2 | ISO/IEC 27001 | 2022 | A.8.15 logging, A.8.2 privileged access |
| 3 | ANSI INCITS 359 | 2004 | RBAC Level 3: DAG, SoD |
| 4 | NIST SP 800-63B-4 | 2025 | AAL, MFA, session, step-up |
| 5 | NIST SP 800-53 Rev.5 | 2020 | AC-2, AC-5 (SoD), AC-6 (least privilege) |
| 6 | NIST SP 800-207 | 2020 | Zero Trust Architecture |
| 7 | ISO 20022 | 2013 | Límites financieros |
| 8 | FATF Rec.16 | 2012 | Dual approval thresholds |
| 9 | SOX §404 | 2002 | Internal controls |
| 10 | ISO 3166-1 | 2020 | Country codes |
| 11 | ISO 4217 | 2015 | Currency codes |
| 12 | RFC 4632 | 2006 | CIDR notation |
| 13 | RFC 9470 | 2023 | Step-Up Authentication |
| 14 | OWASP ASVS 5.0 | 2025 | V2 Auth, V4 Access Control |
| 15 | W3C Trace Context | 2020 | ctx_id propagation |
| 16 | ADR-020 | 2026 | Interface Dual |
| 17 | SBOS-049 | 2026 | Context Plane |
| 18 | SBOS-050 | 2026 | Port Catalog |

---

## 13. HISTORIAL DE CAMBIOS

| Versión | Fecha | Autor | Cambios |
|---------|-------|-------|---------|
| 3.0.0 | 2026-06-22 | sbos-coordinador | Especificación inicial: 9 tablas, 30 validaciones, 9 handlers, 68h |
| 4.0.0 | 2026-06-22 | sbos-coordinador | **Actualización mayor:** + auditoría BD real (VPS), + componente UI árbol jerárquico, + CRUD detallado de 9 tablas base, + correcciones integridad referencial, + estructura real 12 columnas, + plan 8 fases, ~54 handlers |

---

*Documento aprobado para implementación. Próximo paso: Fase 0 — Correcciones de Integridad.*
