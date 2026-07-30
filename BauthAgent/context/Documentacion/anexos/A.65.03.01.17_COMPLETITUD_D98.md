# A.65.03.01.17 — Informe de Completitud: D98 Registro Estructural

**Versión:** 1.0.0 · **Fecha:** 2026-07-28
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D98.*`)
**Estado de D98:** ❌ SIN IMPLEMENTAR — 0/4 bloques con tablas propias · 3 tablas propuestas (T-500..T-502)

> **Propósito de D98:** Dominio estructural que gestiona el árbol de políticas en sí mismo — catálogo de átomos, versiones del árbol, y esquema de atributos. Es el "meta-dominio" que permite que todos los demás dominios funcionen con coherencia. Sin D98 operativo, la evolución del árbol es manual y propensa a errores.
> **T-code range:** T-500..T-509

---

## 1. Estado global de D98

**Dominio:** Registro Estructural (Meta-IAM — árbol de políticas, catálogo de átomos, versionado)
**Total bloques:** 4 | **Tablas propias:** 0 | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | T-code propuesto |
|--------|------|--------|--------|-----------------|
| B01 | `schema` | Esquema de Atributos | ❌ FALTANTE | T-500 |
| B02 | `catalog` | Catálogo de Átomos | ❌ FALTANTE | T-501 |
| B03 | `versioning` | Control de Versiones del Árbol | ❌ FALTANTE | T-502 |
| B04 | `business_zone` | Registro de Zona de Negocio (Estructural) | árbol ✅ | — |

---

## 2. Análisis de bloques

### B01 — `schema` · Esquema de Atributos

**Normas:** SCIM 2.0 RFC 7643 §4 · ISO/IEC 24760-1:2019 §5

**Propósito:** Define el esquema canónico de atributos de identidad — cuáles atributos existen, de qué tipo, si son requeridos, y a qué estándar corresponden. Permite que `idn_identity_attribute` (T-157, D00) sea extensible sin hardcode.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_registro_atributo_schema (
    schema_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NULL REFERENCES bauth.idn_tenant(tenant_id),  -- NULL = esquema global
    -- Identificador del atributo
    attr_name       TEXT NOT NULL,           -- nombre canónico (ej: 'givenName', 'nit', 'ci')
    scim_urn        TEXT NULL,               -- URN SCIM si aplica (urn:ietf:params:scim:schemas:...)
    display_name    JSONB NOT NULL,          -- {"es":"Nombre","en":"First Name"}
    -- Tipo y validación
    tipo_dato       TEXT NOT NULL DEFAULT 'STRING'
        CONSTRAINT chk_idras_tipo CHECK (tipo_dato IN ('STRING','INTEGER','DECIMAL','BOOLEAN','DATE','DATETIME','UUID','JSON','BINARY')),
    requerido       BOOLEAN NOT NULL DEFAULT FALSE,
    multi_valor     BOOLEAN NOT NULL DEFAULT FALSE,
    longitud_max    INTEGER NULL,
    patron_regex    TEXT NULL,               -- validación por regex
    -- Clasificación
    clasificacion   TEXT NOT NULL DEFAULT 'INTERNAL'
        CONSTRAINT chk_idras_clas CHECK (clasificacion IN ('PUBLIC','INTERNAL','CONFIDENTIAL','PII','SENSITIVE_PII')),
    -- SCIM mutability
    mutabilidad     TEXT NOT NULL DEFAULT 'READ_WRITE'
        CONSTRAINT chk_idras_mut CHECK (mutabilidad IN ('READ_ONLY','READ_WRITE','WRITE_ONLY','IMMUTABLE')),
    returned        TEXT NOT NULL DEFAULT 'DEFAULT'
        CONSTRAINT chk_idras_ret CHECK (returned IN ('ALWAYS','NEVER','DEFAULT','REQUEST')),
    -- Estándar de referencia
    estandar_ref    TEXT NULL,               -- ej: 'NIST SP 800-63A §2.1', 'SCIM RFC 7643 §4.1.2'
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, attr_name)
);
COMMENT ON TABLE bauth.idn_registro_atributo_schema IS
  '[T-500] [D98-B01] [SCIM 2.0 RFC 7643 §4] [ISO/IEC 24760-1:2019 §5]
   Esquema canónico de atributos de identidad. Define los atributos válidos en idn_identity_attribute.
   Sin este catálogo, idn_identity_attribute acepta cualquier attr_name (inseguro).';
```

### B02 — `catalog` · Catálogo de Átomos

**Normas:** NIST SP 800-162 §4.2 · ISO/IEC 24760-2:2025 §7

**Propósito:** Catálogo normalizado de todos los átomos del árbol de políticas — descripción, pilar IAM, estándar que implementa, y estado. Complementa `idn_roles_template` (el árbol) con metadatos semánticos que permiten búsqueda y documentación automática.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_registro_atomo_catalogo (
    catalogo_id     UUID PRIMARY KEY DEFAULT uuidv7(),
    node_id         UUID NOT NULL REFERENCES bauth.idn_roles_template(id) ON DELETE CASCADE,
    -- Metadatos
    pilar_iam       TEXT NULL CONSTRAINT chk_idrac_pilar CHECK (pilar_iam IS NULL OR pilar_iam IN
        ('I_AUTH','II_IGA','III_PAM','IV_NHI','V_DIRECTORY','VI_STANDARDS','VII_ADVANCED')),
    estandar_ref    TEXT NULL,               -- ej: 'NIST SP 800-53 R5 AC-3'
    nivel_riesgo    TEXT NOT NULL DEFAULT 'MEDIO'
        CONSTRAINT chk_idrac_riesgo CHECK (nivel_riesgo IN ('BAJO','MEDIO','ALTO','CRITICO')),
    requiere_mfa    BOOLEAN NOT NULL DEFAULT FALSE,
    requiere_loa    TEXT NULL CONSTRAINT chk_idrac_loa CHECK (requiere_loa IS NULL OR requiere_loa IN ('AAL1','AAL2','AAL3')),
    -- Documentación
    descripcion     JSONB NOT NULL,          -- {"es":"Descripción del átomo","en":"..."}
    casos_uso       TEXT[] NULL,             -- casos de uso típicos
    -- Estado de implementación
    implementado    BOOLEAN NOT NULL DEFAULT FALSE,
    version_disponible TEXT NULL,
    notas_implementacion TEXT NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (node_id)
);
COMMENT ON TABLE bauth.idn_registro_atomo_catalogo IS
  '[T-501] [D98-B02] [NIST SP 800-162 §4.2] [ISO/IEC 24760-2:2025 §7]
   Catálogo semántico de átomos del árbol de políticas. Permite documentación y búsqueda IAM Enterprise.
   Cada átomo en idn_roles_template (depth=3) debe tener entrada aquí.';
```

### B03 — `versioning` · Control de Versiones del Árbol

**Normas:** ISO 9001:2015 §7.5 · ISO/IEC 24760-2:2025 §7

**Propósito:** Registro de versiones del árbol de políticas. Cada vez que se modifica `idn_roles_template` (agrega/elimina átomos, cambia permisos), se crea una versión snapshot. Permite auditar qué versión del árbol estaba vigente en un momento dado (para revisiones forenses).

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_registro_arbol_version (
    version_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    version_semver  TEXT NOT NULL,           -- ej: '2.7.0'
    descripcion     TEXT NOT NULL,
    -- Snapshot
    total_nodos     INTEGER NOT NULL,
    total_atomos    INTEGER NOT NULL,
    checksum_arbol  TEXT NOT NULL,           -- SHA-256 del árbol completo serializado
    -- Contexto del cambio
    autor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    motivo          TEXT NOT NULL CONSTRAINT chk_idrav_mot CHECK (motivo IN (
        'NUEVO_DOMINIO','NUEVO_ATOMO','DEPRECACION','CORRECCIÓN','MIGRACION','HOTFIX')),
    aprobado_por    UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    estado          TEXT NOT NULL DEFAULT 'VIGENTE'
        CONSTRAINT chk_idrav_est CHECK (estado IN ('BORRADOR','VIGENTE','DEPRECADO','ARCHIVADO')),
    creado_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    UNIQUE (tenant_id, version_semver)
);
COMMENT ON TABLE bauth.idn_registro_arbol_version IS
  '[T-502] [D98-B03] [ISO 9001:2015 §7.5] [ISO/IEC 24760-2:2025 §7]
   Versiones del árbol de políticas. Snapshot + checksum para auditoría forense.
   Permite responder: "¿qué árbol estaba vigente el 2026-03-15 a las 14:00?"';
```

---

## 3. Checklist de completitud

- [ ] `idn_registro_atributo_schema` (T-500) ❌ PENDIENTE
- [ ] `idn_registro_atomo_catalogo` (T-501) ❌ PENDIENTE
- [ ] `idn_registro_arbol_version` (T-502) ❌ PENDIENTE
- [ ] Seeds T-500: atributos SCIM estándar (givenName, familyName, email, phoneNumber, externalId) + atributos Bolivia (nit, ci, rda)
- [ ] Seeds T-501: entradas del catálogo para los ~400 átomos planeados
- [ ] Seeds T-502: versión inicial '2.7.0' del árbol (estado actual)
- [ ] Trigger: al INSERT en `idn_roles_template`, auto-crear entrada en T-501 con `implementado=false`
- [ ] Job: diario — snapshot del árbol y crear versión en T-502 si `checksum_arbol` cambió

### Átomos D98

- [ ] `skull.D98.schema.*` — átomos (create, read, deprecate)
- [ ] `skull.D98.catalog.*` — átomos (read, annotate, search)
- [ ] `skull.D98.versioning.*` — átomos (read, compare, snapshot)
- [ ] `skull.D98.business_zone.*` — átomos de zona

---

## 4. Análisis IAM Enterprise — D98

| Pilar IAM Enterprise | Criterio D98 | Estado |
|---|---|:---:|
| **VI Standards** | SCIM 2.0 schema management | ❌ L0 |
| **VI Standards** | ISO/IEC 24760-2 policy tree versioning | ❌ L0 |
| **VII Advanced** | Atom catalog para autoservicio IAM | ❌ L0 |

**Gaps:**

| Gap | Prioridad | Acción |
|-----|-----------|--------|
| GAP-D98-01 — Schema de atributos sin tabla | 🟠 P2 | CREATE T-500 + seeds |
| GAP-D98-02 — Catálogo de átomos sin tabla | 🟠 P2 | CREATE T-501 + trigger automático |
| GAP-D98-03 — Sin versionado del árbol | 🟠 P2 | CREATE T-502 + job diario |
| GAP-D98-04 — Átomos D98 | 🟡 P3 | INSERT ~12 átomos |

**Veredicto: D98 L0** — El meta-dominio está completamente pendiente. Es infraestructura de soporte para la gobernanza del árbol; no bloquea operaciones pero sí bloquea la auditoría forense del árbol y la gestión SCIM.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-28 | Versión inicial. 0/4 bloques con tablas propias. DDL propuesto T-500..T-502. 4 gaps. Madurez D98: L0. |
