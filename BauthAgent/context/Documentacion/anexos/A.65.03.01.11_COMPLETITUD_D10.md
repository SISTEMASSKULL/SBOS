# A.65.03.01.11 — Informe de Completitud: D10 Delegación e Impersonación

**Versión:** 1.0.0 · **Fecha:** 2026-07-28
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D10.*`)
**Estado de D10:** ❌ SIN IMPLEMENTAR — 0/7 bloques con tablas propias · 6 tablas propuestas (T-380..T-385)

> **Nota:** `privilege_delegation` (T-172, D01) cubre delegaciones básicas de grants. D10 añade: delegación de identidad completa (Token Exchange RFC 8693), cadena de delegación, restricciones SoD de delegación y RAR.
> **T-code range:** T-380..T-399 (prefijo `idn_delegacion_*`)

---

## 1. Estado global de D10

**Dominio:** Delegación e Impersonación (RFC 8693 Token Exchange · RAR RFC 9396 · Cadena de delegación)
**Total bloques:** 7 | **Tablas propias:** 0 directas | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | T-code propuesto |
|--------|------|--------|--------|-----------------|
| B01 | `delegation` | Gestión de Delegaciones | ⚠️ PARCIAL | `privilege_delegation` (D01) + T-380 |
| B02 | `renewal` | Renovación de Delegación | ❌ FALTANTE | T-381 |
| B03 | `restrictions` | Validación SoD en Delegación | ❌ FALTANTE | T-382 |
| B04 | `chain` | Delegación en Cadena | ❌ FALTANTE | T-383 |
| B05 | `audit` | Auditabilidad de Delegación | ❌ FALTANTE | T-384 |
| B06 | `rich_authorization` | Autorización Granular API (RAR) | ❌ FALTANTE | T-385 |
| B07 | `business_zone` | Registro de Zona de Negocio (Delegación) | árbol ✅ | — |

---

## 2. Análisis de bloques

### B01 — `delegation` · Gestión de Delegaciones (⚠️ PARCIAL)

**Normas:** RFC 8693 §3 · NIST SP 800-53 R5 AC-2(5)

`privilege_delegation` (T-172) cubre delegaciones de grants atomizados. Sin embargo, falta la delegación de **identidad completa** (impersonación controlada via Token Exchange):

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_identidad (
    delegacion_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    -- Quien delega
    delegante_id    UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    -- Quien recibe la delegación
    delegado_id     UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    -- Tipo de delegación (RFC 8693)
    tipo            TEXT NOT NULL DEFAULT 'DELEGACION'
        CONSTRAINT chk_iddi_tipo CHECK (tipo IN ('DELEGACION','IMPERSONACION','ACT_AS','MAY_ACT')),
    -- Scope restringido de la delegación
    scope_restringido TEXT[] NULL,           -- NULL = todos los scopes del delegante
    atoms_restringidos UUID[] NULL,          -- átomos permitidos (NULL = todos)
    -- Profundidad máxima de re-delegación
    max_hop         INTEGER NOT NULL DEFAULT 1
        CONSTRAINT chk_iddi_hop CHECK (max_hop BETWEEN 1 AND 5),
    -- Vigencia
    valid_from      TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until     TIMESTAMPTZ NOT NULL,
    -- Token Exchange
    token_exchange_ref TEXT NULL,            -- referencia al subject_token usado (RFC 8693 §2.1)
    -- Estado
    estado          TEXT NOT NULL DEFAULT 'ACTIVA'
        CONSTRAINT chk_iddi_est CHECK (estado IN ('ACTIVA','SUSPENDIDA','REVOCADA','EXPIRADA')),
    aprobado_por    UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_iddi_rango CHECK (valid_until > valid_from),
    CONSTRAINT chk_iddi_self CHECK (delegante_id <> delegado_id)
);
COMMENT ON TABLE bauth.idn_delegacion_identidad IS
  '[T-380] [D10-B01] [RFC 8693 §3] [NIST SP 800-53 R5 AC-2(5)]
   Delegación de identidad completa via Token Exchange. Complementa privilege_delegation (grants atomizados).';
```

### B02 — `renewal` · Renovación de Delegación

**Normas:** RFC 8693 §4.2 · ISO 27001 A.5.18

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_renovacion (
    renovacion_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    delegacion_id   UUID NOT NULL REFERENCES bauth.idn_delegacion_identidad(delegacion_id),
    renovado_por    UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    nueva_vigencia_hasta TIMESTAMPTZ NOT NULL,
    motivo          TEXT NOT NULL,
    aprobado_por    UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    renovado_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE bauth.idn_delegacion_renovacion IS
  '[T-381] [D10-B02] [RFC 8693 §4.2] [ISO 27001 A.5.18]
   Historial de renovaciones de delegaciones. Cada renovación extiende valid_until del delegación padre.';
```

### B03 — `restrictions` · Validación SoD en Delegación

**Normas:** NIST SP 800-53 R5 AC-5 · ISO 27001 A.5.3

**Propósito:** Define restricciones SoD específicas de delegación — qué roles/atoms no pueden delegarse, quiénes no pueden recibir delegaciones, y restricciones de re-delegación.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_restriccion (
    restriccion_id  UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo            TEXT NOT NULL CONSTRAINT chk_iddr_tipo CHECK (tipo IN (
        'NO_DELEGABLE',           -- este rol/atom no puede delegarse
        'NO_PUEDE_RECIBIR',       -- este rol no puede recibir delegaciones
        'NO_REDELEGABLE',         -- este grant no puede re-delegarse
        'REQUIERE_APROBACION',    -- la delegación requiere aprobación explícita
        'LIMITE_RECEPTORES'       -- máximo N actores pueden recibir esta delegación
    )),
    rol_ref         TEXT NULL,               -- role_code al que aplica
    atom_ref        UUID NULL REFERENCES bauth.idn_roles_template(id),
    valor           TEXT NULL,               -- valor asociado (ej: '3' para LIMITE_RECEPTORES)
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_delegacion_restriccion IS
  '[T-382] [D10-B03] [NIST SP 800-53 R5 AC-5] [ISO 27001 A.5.3]
   Restricciones SoD aplicadas al motor de delegación. El PDP las evalúa antes de autorizar.';
```

### B04 — `chain` · Delegación en Cadena

**Normas:** RFC 8693 §2 · ANSI INCITS 359-2004 §4.5

**Propósito:** Registra la cadena de delegación (A delegó a B, B delegó a C). Permite auditar el origen de una impersonación y aplicar restricciones de profundidad.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_cadena (
    cadena_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    delegacion_raiz UUID NOT NULL REFERENCES bauth.idn_delegacion_identidad(delegacion_id),
    delegacion_hop  UUID NOT NULL REFERENCES bauth.idn_delegacion_identidad(delegacion_id),
    hop_numero      INTEGER NOT NULL,        -- 1 = delegación directa, 2 = re-delegación, etc.
    creado_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    UNIQUE (delegacion_raiz, delegacion_hop)
);
COMMENT ON TABLE bauth.idn_delegacion_cadena IS
  '[T-383] [D10-B04] [RFC 8693 §2] [ANSI INCITS 359-2004 §4.5]
   Closure table de cadenas de delegación. Permite auditar la ruta A→B→C con profundidad controlada.';
```

### B05 — `audit` · Auditabilidad de Delegación

**Normas:** ISO 27001 A.8.15 · NIST SP 800-53 R5 AU-2

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_uso_log (
    uso_id          UUID PRIMARY KEY DEFAULT uuidv7(),
    delegacion_id   UUID NOT NULL REFERENCES bauth.idn_delegacion_identidad(delegacion_id),
    delegado_id     UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    operacion       TEXT NOT NULL,           -- qué operación realizó bajo delegación
    atom_usado      UUID NULL REFERENCES bauth.idn_roles_template(id),
    resultado       TEXT NOT NULL CONSTRAINT chk_iddul_res CHECK (resultado IN ('PERMITIDO','DENEGADO','ERROR')),
    ip_origen       INET NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    usado_at        TIMESTAMPTZ NOT NULL DEFAULT now()
) PARTITION BY RANGE (usado_at);
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_uso_log_2026
    PARTITION OF bauth.idn_delegacion_uso_log
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
COMMENT ON TABLE bauth.idn_delegacion_uso_log IS
  '[T-384] [D10-B05] [ISO 27001 A.8.15] [NIST SP 800-53 R5 AU-2]
   Log particionado de usos de delegación — auditoría WORM de qué hizo el delegado.';
```

### B06 — `rich_authorization` · Autorización Granular de API (RAR)

**Normas:** RFC 9396 §3 · OAuth 2.0 RFC 6749

**Propósito:** Rich Authorization Requests — permite que un cliente solicite autorización para una acción específica con parámetros detallados (ej: "transferir $500 a cuenta XXXX"). El token resultante lleva el authorization_detail, que bAuth valida en el PEP.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_delegacion_rar_request (
    rar_id          UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    session_id      UUID NULL REFERENCES bauth.ses_session_log(session_id),
    -- authorization_details (RFC 9396 §2)
    authorization_details JSONB NOT NULL,
    tipo_accion     TEXT NOT NULL,           -- ej: 'payment', 'file_access', 'device_registration'
    estado          TEXT NOT NULL DEFAULT 'PENDIENTE'
        CONSTRAINT chk_iddrar_est CHECK (estado IN ('PENDIENTE','APROBADO','RECHAZADO','EXPIRADO','USADO')),
    aprobado_at     TIMESTAMPTZ NULL,
    token_jti       TEXT NULL,               -- JTI del token que lleva el authorization_detail
    expira_at       TIMESTAMPTZ NOT NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_delegacion_rar_request IS
  '[T-385] [D10-B06] [RFC 9396 §3] [OAuth 2.0 RFC 6749]
   Rich Authorization Requests — permisos granulares por operación específica.
   El token resultante lleva authorization_details verificable por el PEP Kong.';
```

---

## 3. Checklist de completitud

- [ ] `idn_delegacion_identidad` (T-380) ❌ PENDIENTE
- [ ] `idn_delegacion_renovacion` (T-381) ❌ PENDIENTE
- [ ] `idn_delegacion_restriccion` (T-382) ❌ PENDIENTE
- [ ] `idn_delegacion_cadena` (T-383) ❌ PENDIENTE
- [ ] `idn_delegacion_uso_log` (T-384) particionada ❌ PENDIENTE
- [ ] `idn_delegacion_rar_request` (T-385) ❌ PENDIENTE
- [ ] Trigger: al crear delegación, validar restricciones SoD (T-382) — rechazar si viola
- [ ] Trigger: al usar delegación, registrar en T-384
- [ ] Trigger: al expirar delegación → marcar tokens delegados en T-363 como EXPIRADOS
- [ ] Job: expirar delegaciones vencidas y sus renovaciones
- [ ] Átomos D10: `skull.D10.{delegation,renewal,restrictions,chain,audit,rich_authorization}.*`

---

## 4. Análisis IAM Enterprise — D10

| Pilar IAM Enterprise | Criterio D10 | Estado |
|---|---|:---:|
| **I AuthEngine** | Token Exchange RFC 8693 | ❌ L0 |
| **I AuthEngine** | RAR RFC 9396 para APIs financieras | ❌ L0 |
| **II IGA** | Auditoría de delegaciones | ❌ L0 |
| **VI Standards** | RFC 8693 / RFC 9396 / ANSI INCITS 359 | ❌ L0 |

**Gaps:**

| Gap | Prioridad | Acción |
|-----|-----------|--------|
| GAP-D10-01 — Token Exchange sin tabla | 🔴 P1 | CREATE T-380 |
| GAP-D10-02 — RAR sin implementar | 🟠 P2 | CREATE T-385 |
| GAP-D10-03 — Cadena de delegación sin trazabilidad | 🟠 P2 | CREATE T-383 + T-384 |
| GAP-D10-04 — SoD de delegación sin reglas | 🟠 P2 | CREATE T-382 |
| GAP-D10-05 — Átomos D10 | 🟡 P3 | INSERT ~25 átomos |

**Veredicto: D10 L0** — T-380 (Token Exchange) es la base de impersonación controlada. Sin ella, bAuth no puede implementar RFC 8693 correctamente.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-28 | Versión inicial. 0/7 bloques con tablas propias (B07 árbol). DDL propuesto T-380..T-385. 5 gaps IAM Enterprise. Madurez D10: L0. |
