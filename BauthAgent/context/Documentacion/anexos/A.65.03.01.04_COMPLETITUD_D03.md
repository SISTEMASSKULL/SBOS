# A.65.03.01.04 — Informe de Completitud: D03 Controles Financieros

**Versión:** 1.0.0 · **Fecha:** 2026-07-28
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D03.*`)
**SSOT DDL:** `SBOS_db_V2_DDL.sql` v2.0.0 + `SBOS_db_V2_DDL_MANUAL.md` v2.7.0
**Estado de D03:** ❌ SIN IMPLEMENTAR — 0/9 bloques con tablas propias · 8 tablas propuestas (T-240..T-247)

> **T-code range:** T-240..T-259 (prefijo `idn_financiero_*`)

---

## 1. Estado global de D03

**Dominio:** Controles Financieros de IAM | **Pipeline:** IAM FinOps (SoD financiero + aprobación dual + facturación electrónica)
**Total bloques:** 9 | **Tablas propias:** 0 | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | T-code propuesto |
|--------|------|--------|--------|-----------------|
| B01 | `limits` | Límites Transaccionales | ❌ FALTANTE | T-240 |
| B02 | `approvals` | Aprobación Dual / Quórum | ❌ FALTANTE | T-241 |
| B03 | `segregation` | Segregación de Funciones Financieras | ❌ FALTANTE | T-242 |
| B04 | `billing` | Facturación Electrónica | ❌ FALTANTE | T-243 |
| B05 | `reporting` | Reportes Regulatorios | ❌ FALTANTE | T-244 |
| B06 | `fraud` | Detección de Fraude | ❌ FALTANTE | T-245 |
| B07 | `reconciliation` | Conciliación Automática | ❌ FALTANTE | T-246 |
| B08 | `open_banking` | Banca Abierta / FAPI 2.0 | ❌ FALTANTE | T-247 |
| B09 | `business_zone` | Registro de Zona de Negocio (Financiero) | árbol ✅ | — |

---

## 2. Análisis de bloques

### B01 — `limits` · Límites Transaccionales

**Normas:** PCI DSS 4.0 Req 8.2 · NIST SP 800-53 R5 AC-2(6) · SOX §302

**Propósito:** Define los límites de monto y frecuencia para operaciones financieras por rol, tier y tipo de transacción. El PDP consulta estos límites antes de autorizar una transacción. Implementa el principio de mínimo privilegio financiero.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_limite (
    limite_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    role_id         UUID NULL REFERENCES bauth.idn_roles_rol_hierarchical(id),
    tipo_transaccion TEXT NOT NULL,          -- PAGO, TRANSFERENCIA, COMPRA, APROBACION
    monto_maximo    NUMERIC(20,4) NULL,      -- NULL = sin límite
    moneda          TEXT NOT NULL DEFAULT 'BOB',
    max_diario      NUMERIC(20,4) NULL,      -- límite diario acumulado
    max_mensual     NUMERIC(20,4) NULL,
    max_por_transaccion INTEGER NULL,        -- número máximo de transacciones/día
    requiere_aprobacion_sobre NUMERIC(20,4) NULL,   -- monto que dispara aprobación dual
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, role_id, tipo_transaccion, moneda)
);
COMMENT ON TABLE bauth.idn_financiero_limite IS
  '[T-240] [D03-B01] [PCI DSS 4.0 Req 8.2] [NIST SP 800-53 R5 AC-2(6)]
   Límites transaccionales por rol y tipo de operación. El PDP los aplica en tiempo real.';
```

### B02 — `approvals` · Aprobación Dual / Quórum

**Normas:** COSO 2013 CC6.3 · ISO 27001 A.5.3 · SOX §302

**Propósito:** Flujo de aprobación dual o quórum para transacciones de alto valor. Cuando el monto supera el umbral de B01, se crea una solicitud de aprobación que requiere N aprobadores de M disponibles.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_aprobacion (
    aprobacion_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    solicitud_ref   TEXT NOT NULL,           -- referencia a la transacción externa
    tipo            TEXT NOT NULL CONSTRAINT chk_idfa_tipo CHECK (tipo IN ('DUAL','QUORUM','SINGULAR')),
    quorum_requerido INTEGER NOT NULL DEFAULT 2,
    solicitante_id  UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    monto           NUMERIC(20,4) NOT NULL,
    moneda          TEXT NOT NULL DEFAULT 'BOB',
    descripcion     TEXT NOT NULL,
    estado          TEXT NOT NULL DEFAULT 'PENDIENTE'
        CONSTRAINT chk_idfa_estado CHECK (estado IN ('PENDIENTE','APROBADO','RECHAZADO','EXPIRADO','CANCELADO')),
    aprobaciones_obtenidas INTEGER NOT NULL DEFAULT 0,
    expira_at       TIMESTAMPTZ NOT NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_aprobacion_voto (
    voto_id         UUID PRIMARY KEY DEFAULT uuidv7(),
    aprobacion_id   UUID NOT NULL REFERENCES bauth.idn_financiero_aprobacion(aprobacion_id),
    aprobador_id    UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    decision        TEXT NOT NULL CONSTRAINT chk_idfav_dec CHECK (decision IN ('APROBADO','RECHAZADO')),
    justificacion   TEXT NULL,
    votado_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    UNIQUE (aprobacion_id, aprobador_id)
);
COMMENT ON TABLE bauth.idn_financiero_aprobacion IS
  '[T-241] [D03-B02] [COSO 2013 CC6.3] [SOX §302]
   Flujo de aprobación dual o quórum para transacciones sobre el umbral.';
```

### B03 — `segregation` · Segregación de Funciones Financieras

**Normas:** NIST SP 800-53 R5 AC-5 · SOX §404 · COSO CC6.3

**Propósito:** Matriz de SoD financiero — define qué pares de funciones no pueden ser ejercidas por el mismo actor (ej: quien aprueba pagos no puede ejecutarlos). Específica del dominio financiero, complementa `privilege_verb_conflict` (D01) con reglas de negocio financiero.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_sod_regla (
    regla_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    funcion_a       TEXT NOT NULL,           -- ej: 'APROBAR_PAGO'
    funcion_b       TEXT NOT NULL,           -- ej: 'EJECUTAR_PAGO'
    tipo_conflicto  TEXT NOT NULL DEFAULT 'ESTATICO'
        CONSTRAINT chk_idfsr_tipo CHECK (tipo_conflicto IN ('ESTATICO','DINAMICO')),
    descripcion     TEXT NOT NULL,
    excepciones_permitidas BOOLEAN NOT NULL DEFAULT FALSE,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, funcion_a, funcion_b)
);
COMMENT ON TABLE bauth.idn_financiero_sod_regla IS
  '[T-242] [D03-B03] [NIST SP 800-53 R5 AC-5] [SOX §404] [COSO CC6.3]
   Matriz SoD financiero — pares de funciones incompatibles por el mismo actor.';
```

### B04 — `billing` · Facturación Electrónica

**Normas:** SIN RND 102100000011 · ISO 20022 · UBL 2.1 · Ley 164 Bolivia

**Propósito:** Registro del ciclo de vida de facturas electrónicas emitidas bajo credenciales del sistema de facturación boliviano (SIN). bAuth controla quién puede emitir facturas en nombre del tenant y registra la evidencia de autorización.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_factura_autorizacion (
    auth_id         UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    emisor_id       UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    sin_nit         TEXT NOT NULL,           -- NIT del emisor
    sin_cuf         TEXT NULL,               -- Código Único de Factura SIN
    monto           NUMERIC(20,4) NOT NULL,
    moneda          TEXT NOT NULL DEFAULT 'BOB',
    tipo_factura    TEXT NOT NULL DEFAULT 'COMPRA_VENTA'
        CONSTRAINT chk_idffa_tipo CHECK (tipo_factura IN ('COMPRA_VENTA','EXPORTACION','IMPORTACION','SERVICIO')),
    estado_sin      TEXT NOT NULL DEFAULT 'PENDIENTE'
        CONSTRAINT chk_idffa_sin CHECK (estado_sin IN ('PENDIENTE','ENVIADO','ACEPTADO','OBSERVADO','ANULADO')),
    loa_requerida   TEXT NOT NULL DEFAULT 'AAL2'
        CONSTRAINT chk_idffa_loa CHECK (loa_requerida IN ('AAL1','AAL2','AAL3')),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    emitido_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_financiero_factura_autorizacion IS
  '[T-243] [D03-B04] [SIN RND 102100000011] [ISO 20022] [Ley 164 Bolivia]
   Autorizaciones de emisión de facturas electrónicas con control de identidad bAuth.';
```

### B05 — `reporting` · Reportes Regulatorios

**Normas:** SOX §302/§404 · IFRS 7 · ISO 20022 MX

**Propósito:** Catálogo de reportes regulatorios generados y el actor que los autorizó. bAuth registra la cadena de autorización de cada reporte (quién lo aprobó para envío al regulador).

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_reporte (
    reporte_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo            TEXT NOT NULL,           -- SOX_302, SOX_404, IFRS7, ASFI, OTROS
    periodo         TEXT NOT NULL,           -- '2025-Q4', '2025-12'
    aprobado_por    UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    aprobado_at     TIMESTAMPTZ NOT NULL,
    enviado_at      TIMESTAMPTZ NULL,
    destinatario    TEXT NOT NULL,           -- ASFI, SIN, BOLSA, OTROS
    hash_contenido  TEXT NULL,               -- SHA-256 del contenido del reporte
    estado          TEXT NOT NULL DEFAULT 'BORRADOR'
        CONSTRAINT chk_idfr_estado CHECK (estado IN ('BORRADOR','APROBADO','ENVIADO','ACEPTADO','OBSERVADO')),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_financiero_reporte IS
  '[T-244] [D03-B05] [SOX §302/§404] [IFRS 7] [ISO 20022]
   Registro de reportes regulatorios con cadena de autorización bAuth.';
```

### B06 — `fraud` · Detección de Fraude

**Normas:** PCI DSS 4.0 Req 10.7 · ISO 37001 §8.6 · NIST SP 800-53 R5 SI-4

**Propósito:** Eventos de fraude detectados o sospechados. El motor de fraude (externo o interno) notifica a bAuth, que puede revocar grants, elevar LoA o bloquear al actor.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_alerta_fraude (
    alerta_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    actor_id        UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    tipo_alerta     TEXT NOT NULL CONSTRAINT chk_idfaf_tipo CHECK (tipo_alerta IN
        ('PATRON_INUSUAL','VELOCIDAD','MONTO_EXCESIVO','DUPLICADO','LISTA_NEGRA','SUPLANTACION')),
    severidad       TEXT NOT NULL CONSTRAINT chk_idfaf_sev CHECK (severidad IN ('BAJA','MEDIA','ALTA','CRITICA')),
    descripcion     TEXT NOT NULL,
    evidencia       JSONB NULL,              -- datos que sustentan la alerta
    accion_tomada   TEXT NULL CONSTRAINT chk_idfaf_acc CHECK (accion_tomada IS NULL OR accion_tomada IN
        ('BLOQUEO_TEMP','STEP_UP','REVOCACION_GRANT','ALERTA_SIEM','NINGUNA')),
    estado          TEXT NOT NULL DEFAULT 'NUEVA'
        CONSTRAINT chk_idfaf_estado CHECK (estado IN ('NUEVA','EN_REVISION','CONFIRMADA','FALSO_POSITIVO','RESUELTA')),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    detectado_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_financiero_alerta_fraude IS
  '[T-245] [D03-B06] [PCI DSS 4.0 Req 10.7] [ISO 37001 §8.6]
   Alertas de fraude financiero con acción automática bAuth (bloqueo, step-up, revocación).';
```

### B07 — `reconciliation` · Conciliación Automática

**Normas:** ISO 20022 §5 · COSO 2013 CC6.6

**Propósito:** Registro de procesos de conciliación automática y las discrepancias detectadas. bAuth autentica al proceso que ejecuta la conciliación y registra su resultado.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_conciliacion (
    conciliacion_id UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo            TEXT NOT NULL CONSTRAINT chk_idfc_tipo CHECK (tipo IN ('BANCARIA','INTERNA','TRIBUTARIA','INTEREMPRESA')),
    periodo         TEXT NOT NULL,
    ejecutado_por   UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    estado          TEXT NOT NULL DEFAULT 'EN_PROCESO'
        CONSTRAINT chk_idfc_estado CHECK (estado IN ('EN_PROCESO','COMPLETADO','CON_DIFERENCIAS','REQUIERE_REVISION')),
    total_registros INTEGER NULL,
    registros_ok    INTEGER NULL,
    diferencias     INTEGER NULL,
    diferencias_detalle JSONB NULL,          -- array de discrepancias
    ejecutado_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    completado_at   TIMESTAMPTZ NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE bauth.idn_financiero_conciliacion IS
  '[T-246] [D03-B07] [ISO 20022 §5] [COSO 2013 CC6.6]
   Registro de conciliaciones automáticas con discrepancias y actor bAuth ejecutor.';
```

### B08 — `open_banking` · Banca Abierta / FAPI 2.0

**Normas:** FAPI 2.0 Security Profile · RFC 9449 DPoP · PSD2 Art. 98 · RFC 7636 PKCE

**Propósito:** Registro de aplicaciones de terceros (TPP) autorizadas para acceder a datos financieros vía Open Banking. bAuth actúa como Authorization Server FAPI 2.0 — registra los consentimientos otorgados y los tokens DPoP emitidos.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_financiero_tpp_consentimiento (
    consentimiento_id UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    tpp_id          TEXT NOT NULL,           -- client_id del TPP registrado
    tpp_nombre      TEXT NOT NULL,
    scopes          TEXT[] NOT NULL,         -- scopes FAPI autorizados
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idftp_estado CHECK (estado IN ('ACTIVO','REVOCADO','EXPIRADO')),
    valid_from      TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until     TIMESTAMPTZ NOT NULL,
    dpop_jkt        TEXT NULL,               -- JWK Thumbprint del DPoP public key
    redirect_uri    TEXT NOT NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_financiero_tpp_consentimiento IS
  '[T-247] [D03-B08] [FAPI 2.0] [RFC 9449 DPoP] [PSD2 Art. 98]
   Consentimientos Open Banking / FAPI 2.0 otorgados a TPPs por actores del tenant.';
```

### B09 — `business_zone` · Registro de Zona de Negocio (Financiero)

Satisfecho por el árbol `idn_roles_template` — nodo `skull.D03.business_zone` ya existe (B09, depth=2). No requiere tabla adicional.

---

## 3. Checklist de completitud

### 3.1 DDL

- [ ] `idn_financiero_limite` (T-240) ❌ PENDIENTE
- [ ] `idn_financiero_aprobacion` + `idn_financiero_aprobacion_voto` (T-241) ❌ PENDIENTE
- [ ] `idn_financiero_sod_regla` (T-242) ❌ PENDIENTE
- [ ] `idn_financiero_factura_autorizacion` (T-243) ❌ PENDIENTE
- [ ] `idn_financiero_reporte` (T-244) ❌ PENDIENTE
- [ ] `idn_financiero_alerta_fraude` (T-245) ❌ PENDIENTE
- [ ] `idn_financiero_conciliacion` (T-246) ❌ PENDIENTE
- [ ] `idn_financiero_tpp_consentimiento` (T-247) ❌ PENDIENTE

### 3.2 Triggers

- [ ] Trigger: al insertar voto en `idn_financiero_aprobacion_voto`, actualizar `aprobaciones_obtenidas` y estado de la solicitud
- [ ] Trigger: al detectar fraude CRITICA, auto-crear CAEP `credential-change` en `ses_caep_event_log`

### 3.3 Jobs

- [ ] Job: expirar aprobaciones pendientes vencidas (`expira_at < now()`)
- [ ] Job: expirar consentimientos TPP vencidos
- [ ] Job: generar alerta de conciliaciones sin ejecutar en período vencido

### 3.4 Átomos D03

- [ ] `skull.D03.limits.*` — átomos (read, configure, override)
- [ ] `skull.D03.approvals.*` — átomos (request, approve, reject, view)
- [ ] `skull.D03.segregation.*` — átomos (configure, read)
- [ ] `skull.D03.billing.*` — átomos (emit, authorize, cancel, read)
- [ ] `skull.D03.reporting.*` — átomos (create, approve, send)
- [ ] `skull.D03.fraud.*` — átomos (review, escalate, resolve)
- [ ] `skull.D03.reconciliation.*` — átomos (execute, review)
- [ ] `skull.D03.open_banking.*` — átomos (authorize, revoke, read)
- [ ] `skull.D03.business_zone.*` — átomos de zona

---

## 4. Análisis IAM Enterprise — D03

### 4.1 Cobertura de pilares

D03 cubre **Pilar II — IGA** (SoD financiero, certificación de accesos financieros) y **Pilar VI — Standards** (PCI DSS 4.0, SOX, FAPI 2.0):

| Pilar IAM Enterprise | Criterio D03 | Estado |
|---|---|:---:|
| **I AuthEngine** | PDP aplica límites transaccionales | ❌ L0 |
| **II IGA** | SoD financiero con matriz de conflictos | ❌ L0 |
| **II IGA** | Flujo de aprobación dual/quórum | ❌ L0 |
| **VI Standards** | PCI DSS 4.0 / SOX / FAPI 2.0 | ❌ L0 |
| **VI Standards** | Facturación electrónica SIN Bolivia | ❌ L0 |
| **VII Advanced** | Detección de fraude integrada con IAM | ❌ L0 |

### 4.2 Gaps IAM Enterprise D03

| Gap | Prioridad | Acción |
|-----|-----------|--------|
| GAP-D03-01 — Límites transaccionales en PDP | 🔴 P1 | CREATE T-240 |
| GAP-D03-02 — Flujo aprobación dual | 🔴 P1 | CREATE T-241 |
| GAP-D03-03 — SoD financiero | 🟠 P2 | CREATE T-242 |
| GAP-D03-04 — Facturación electrónica SIN | 🟠 P2 | CREATE T-243 |
| GAP-D03-05 — Fraude integrado con IAM | 🟠 P2 | CREATE T-245 |
| GAP-D03-06 — Open Banking FAPI 2.0 | 🟠 P2 | CREATE T-247 |
| GAP-D03-07 — Átomos D03 | 🟡 P3 | INSERT ~35 átomos |

### 4.3 Veredicto IAM Enterprise

**D03: L0 global** — dominio no implementado. Prioridad: T-240 (límites) y T-241 (aprobación dual) son bloqueantes para cumplimiento PCI DSS 4.0.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-28 | Versión inicial. 8/9 bloques sin implementación (B09 en árbol). DDL propuesto T-240..T-247. 7 gaps IAM Enterprise. Madurez D03: L0. |
