# A.65.03.01.06 — Informe de Completitud: D05 Autenticación Biométrica

**Versión:** 1.0.0 · **Fecha:** 2026-07-28
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D05.*`)
**Estado de D05:** ❌ SIN IMPLEMENTAR — 0/7 bloques con tablas propias · 6 tablas propuestas (T-280..T-285)

> **T-code range:** T-280..T-299 (prefijo `idn_biometrico_*`)

---

## 1. Estado global de D05

**Dominio:** Autenticación Biométrica (ISO/IEC 19794 + NIST SP 800-76-2 + FIDO2 PAD)
**Total bloques:** 7 | **Tablas propias:** 0 | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | T-code propuesto |
|--------|------|--------|--------|-----------------|
| B01 | `enrollment` | Enrolamiento Biométrico | ❌ FALTANTE | T-280 |
| B02 | `verification` | Verificación Biométrica 1:1 | ❌ FALTANTE | T-281 |
| B03 | `liveness` | Detección de Vivacidad (PAD) | ❌ FALTANTE | T-282 |
| B04 | `identification` | Identificación Biométrica 1:N | ❌ FALTANTE | T-283 |
| B05 | `quality` | Calidad de Muestra Biométrica | ❌ FALTANTE | T-284 |
| B06 | `revocation` | Revocación de Plantilla Biométrica | ❌ FALTANTE | T-285 |
| B07 | `business_zone` | Registro de Zona de Negocio (Biométrico) | árbol ✅ | — |

---

## 2. Análisis de bloques

### B01 — `enrollment` · Enrolamiento Biométrico

**Normas:** NIST SP 800-76-2 §4 · ISO/IEC 30107-1:2023 §5 · ISO/IEC 19794-2:2011

**Propósito:** Registro del ciclo de vida del enrolamiento biométrico de un actor. Almacena metadatos del enrolamiento (no la plantilla en sí — la plantilla va al HSM/Vault). Incluye: tipo de biométrico, sensor usado, score de calidad del enrolamiento, estado.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_enrolamiento (
    enrolamiento_id UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE CASCADE,
    tipo_biometrico TEXT NOT NULL
        CONSTRAINT chk_idbe_tipo CHECK (tipo_biometrico IN
            ('HUELLA_DIGITAL','IRIS','FACIAL','VOZ','VENA_PALMA','GEOMETRIA_MANO')),
    sensor_id       TEXT NOT NULL,           -- ID del sensor/cámara
    sensor_modelo   TEXT NULL,
    -- Referencia al template en Vault (no el template en sí)
    vault_path      TEXT NOT NULL,           -- ej: bauth/biometrico/{actor_id}/{tipo}
    calidad_score   NUMERIC(5,2) NOT NULL    -- 0.00 a 100.00 — ISO/IEC 29794-1
        CONSTRAINT chk_idbe_score CHECK (calidad_score BETWEEN 0 AND 100),
    algoritmo       TEXT NOT NULL,           -- ej: ISO_19794_2_2011, ISO_19794_6_2011
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idbe_estado CHECK (estado IN
            ('PENDIENTE','ACTIVO','DEGRADADO','REVOCADO','EXPIRADO')),
    enrolado_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    expira_at       TIMESTAMPTZ NULL,        -- algunos templates tienen vencimiento (FAR drift)
    enrolado_por    UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    UNIQUE (tenant_id, actor_id, tipo_biometrico, estado)
);
COMMENT ON TABLE bauth.idn_biometrico_enrolamiento IS
  '[T-280] [D05-B01] [NIST SP 800-76-2 §4] [ISO/IEC 30107-1:2023 §5]
   Metadatos de enrolamiento biométrico. El template vive en Vault; aquí solo la referencia y estado.';
```

### B02 — `verification` · Verificación Biométrica 1:1

**Normas:** ISO/IEC 19794-2:2011 §5 · NIST SP 800-63B-4 §5.2.3 · FIDO2 §5.4

**Propósito:** Log de verificaciones biométricas 1:1 (actor identifica → sistema compara con template del mismo actor). Registra: resultado, score, FAR/FRR del evento, dispositivo, detección de PAD.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_verificacion_log (
    log_id          UUID PRIMARY KEY DEFAULT uuidv7(),
    enrolamiento_id UUID NOT NULL REFERENCES bauth.idn_biometrico_enrolamiento(enrolamiento_id),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    tipo_biometrico TEXT NOT NULL,
    resultado       TEXT NOT NULL CONSTRAINT chk_idbvl_res CHECK (resultado IN ('MATCH','NO_MATCH','ERROR','SPOOFING_DETECTED')),
    match_score     NUMERIC(5,2) NULL,       -- score de similitud 0-100
    far_threshold   NUMERIC(8,6) NULL,       -- FAR en el momento de la verificación
    liveness_check  BOOLEAN NOT NULL DEFAULT FALSE,
    liveness_score  NUMERIC(5,2) NULL,
    dispositivo_id  TEXT NULL,
    verificado_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system'
)  PARTITION BY RANGE (verificado_at);
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_verificacion_log_2026
    PARTITION OF bauth.idn_biometrico_verificacion_log
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
COMMENT ON TABLE bauth.idn_biometrico_verificacion_log IS
  '[T-281] [D05-B02] [ISO/IEC 19794-2:2011 §5] [NIST SP 800-63B-4 §5.2.3]
   Log particionado de verificaciones biométricas 1:1 con score, FAR y resultado PAD.';
```

### B03 — `liveness` · Detección de Vivacidad (PAD)

**Normas:** ISO/IEC 30107-3:2023 §5 · FIDO2 §8.8 · NIST SP 800-76-2 §7

**Propósito:** Configuración de los parámetros del detector de ataques de presentación (PAD — Presentation Attack Detection). Define umbrales de liveness score, nivel de PAD requerido por tier, y acciones ante detección.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_pad_policy (
    policy_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo_biometrico TEXT NOT NULL,
    tier_id         TEXT NULL,               -- NULL = aplica a todos los tiers
    nivel_pad       TEXT NOT NULL DEFAULT 'PAD_1'
        CONSTRAINT chk_idbpp_nivel CHECK (nivel_pad IN ('PAD_1','PAD_2','PAD_3')),  -- ISO 30107-3
    liveness_threshold NUMERIC(5,2) NOT NULL DEFAULT 80.0
        CONSTRAINT chk_idbpp_lth CHECK (liveness_threshold BETWEEN 0 AND 100),
    accion_falla    TEXT NOT NULL DEFAULT 'BLOQUEO_TEMPORAL'
        CONSTRAINT chk_idbpp_acc CHECK (accion_falla IN
            ('BLOQUEO_TEMPORAL','ALERTA_SIEM','STEP_UP','BLOQUEO_PERMANENTE')),
    duracion_bloqueo INTERVAL NULL DEFAULT '15 minutes',
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, tipo_biometrico, tier_id)
);
COMMENT ON TABLE bauth.idn_biometrico_pad_policy IS
  '[T-282] [D05-B03] [ISO/IEC 30107-3:2023 §5] [FIDO2 §8.8]
   Políticas PAD (Presentation Attack Detection) por tipo biométrico y tier.';
```

### B04 — `identification` · Identificación Biométrica 1:N

**Normas:** ISO/IEC 19794-2:2011 §6 · NIST SP 800-76-2 §5

**Propósito:** Log de identificaciones biométricas 1:N (el sistema busca al actor en la base de templates sin que el actor declare su identidad). Caso de uso: control de acceso físico por huella sin tarjeta.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_identificacion_log (
    log_id          UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo_biometrico TEXT NOT NULL,
    actores_buscados INTEGER NULL,           -- tamaño del conjunto de búsqueda
    actor_identificado UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    match_score     NUMERIC(5,2) NULL,
    resultado       TEXT NOT NULL CONSTRAINT chk_idbil_res CHECK (resultado IN ('IDENTIFICADO','NO_IDENTIFICADO','MULTIPLES_MATCHES','ERROR')),
    dispositivo_id  TEXT NULL,
    identificado_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system'
) PARTITION BY RANGE (identificado_at);
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_identificacion_log_2026
    PARTITION OF bauth.idn_biometrico_identificacion_log
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
COMMENT ON TABLE bauth.idn_biometrico_identificacion_log IS
  '[T-283] [D05-B04] [ISO/IEC 19794-2:2011 §6] [NIST SP 800-76-2 §5]
   Log de identificaciones 1:N para control de acceso sin declaración de identidad.';
```

### B05 — `quality` · Calidad de Muestra Biométrica

**Normas:** ISO/IEC 29794-1:2024 §5 · NIST SP 800-76-2 §3

**Propósito:** Umbrales de calidad de muestra biométrica aceptable por tipo y caso de uso. Si una muestra en tiempo real no supera el umbral mínimo, se rechaza (solicitar nueva muestra).

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_calidad_policy (
    policy_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo_biometrico TEXT NOT NULL,
    caso_uso        TEXT NOT NULL DEFAULT 'VERIFICACION'
        CONSTRAINT chk_idbcpol_uso CHECK (caso_uso IN ('ENROLAMIENTO','VERIFICACION','IDENTIFICACION')),
    score_minimo    NUMERIC(5,2) NOT NULL
        CONSTRAINT chk_idbcpol_min CHECK (score_minimo BETWEEN 0 AND 100),
    intentos_maximos INTEGER NOT NULL DEFAULT 3,
    bloqueo_tras_fallo INTERVAL NOT NULL DEFAULT '5 minutes',
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    UNIQUE (tenant_id, tipo_biometrico, caso_uso)
);
COMMENT ON TABLE bauth.idn_biometrico_calidad_policy IS
  '[T-284] [D05-B05] [ISO/IEC 29794-1:2024 §5] [NIST SP 800-76-2 §3]
   Umbrales mínimos de calidad biométrica por caso de uso. Muestra bajo umbral = rechazo.';
```

### B06 — `revocation` · Revocación de Plantilla Biométrica

**Normas:** ISO/IEC 24745:2022 §6 · NIST SP 800-76-2 §6

**Propósito:** Registro de revocaciones de templates biométricos. Al revocar un template, se dispara la eliminación en Vault + registro de auditoría. Si el actor tiene otro factor, el acceso continúa; si era el único factor, se bloquea al actor.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_biometrico_revocacion (
    revocacion_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    enrolamiento_id UUID NOT NULL REFERENCES bauth.idn_biometrico_enrolamiento(enrolamiento_id),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    motivo          TEXT NOT NULL CONSTRAINT chk_idbr_mot CHECK (motivo IN
        ('COMPROMISO','CAMBIO_FISICO','ERROR_ENROLAMIENTO','SOLICITUD_ACTOR','POLITICA','EXPIRADO')),
    revocado_por    UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    vault_purge_confirmado BOOLEAN NOT NULL DEFAULT FALSE,
    acceso_bloqueado BOOLEAN NOT NULL DEFAULT FALSE,
    factor_alternativo TEXT NULL,            -- si existe otro factor activo
    revocado_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE bauth.idn_biometrico_revocacion IS
  '[T-285] [D05-B06] [ISO/IEC 24745:2022 §6] [NIST SP 800-76-2 §6]
   Registro de revocaciones de templates biométricos con confirmación de purga en Vault.';
```

---

## 3. Checklist de completitud

- [ ] `idn_biometrico_enrolamiento` (T-280) ❌ PENDIENTE
- [ ] `idn_biometrico_verificacion_log` (T-281) particionada ❌ PENDIENTE
- [ ] `idn_biometrico_pad_policy` (T-282) ❌ PENDIENTE
- [ ] `idn_biometrico_identificacion_log` (T-283) particionada ❌ PENDIENTE
- [ ] `idn_biometrico_calidad_policy` (T-284) ❌ PENDIENTE
- [ ] `idn_biometrico_revocacion` (T-285) ❌ PENDIENTE
- [ ] Trigger: al revocar enrolamiento → actualizar vault_purge_confirmado vía callback Vault
- [ ] Job: crear particiones futuras de logs (01 día 28 mensual)
- [ ] Seeds: policies PAD y calidad por defecto para huella digital + facial
- [ ] Átomos D05 en árbol: `skull.D05.{enrollment,verification,liveness,identification,quality,revocation}.*`

---

## 4. Análisis IAM Enterprise — D05

| Pilar IAM Enterprise | Criterio D05 | Estado |
|---|---|:---:|
| **I AuthEngine** | Biométrico como factor AAL3 | ❌ L0 |
| **I AuthEngine** | PAD/liveness en PDP | ❌ L0 |
| **II IGA** | Ciclo de vida de templates biométricos | ❌ L0 |
| **VI Standards** | ISO 19794 / ISO 30107-3 / NIST 800-76-2 | ❌ L0 |

**Gaps:**

| Gap | Prioridad | Acción |
|-----|-----------|--------|
| GAP-D05-01 — Enrolamiento sin trazabilidad | 🔴 P1 | CREATE T-280 |
| GAP-D05-02 — Sin log de verificaciones | 🔴 P1 | CREATE T-281 |
| GAP-D05-03 — Sin política PAD | 🟠 P2 | CREATE T-282 |
| GAP-D05-04 — Sin 1:N para PACS | 🟠 P2 | CREATE T-283 |
| GAP-D05-05 — Átomos D05 | 🟡 P3 | INSERT ~25 átomos |

**Veredicto: D05 L0 global** — el biométrico como AAL3 requiere T-280 + T-282 como mínimo.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-28 | Versión inicial. 6/7 bloques sin implementación. DDL propuesto T-280..T-285. 5 gaps IAM Enterprise. Madurez D05: L0. |
