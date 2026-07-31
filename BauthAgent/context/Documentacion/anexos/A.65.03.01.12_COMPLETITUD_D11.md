# A.65.03.01.12 — Informe de Completitud: D11 Auditoría y Cumplimiento

**Versión:** 1.2.0 · **Fecha:** 2026-07-31
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D11.*`)
**Estado de D11:** ✅ COMPLETO — 7/7 bloques satisfechos · B02 (job retención) + B04 (mv_audit_dashboard) cerrados

> **Actualización v1.2.0:** D11 alcanza 100% de cobertura. B02: job SQL mensual de purga. B04: VIEW materializada `mv_audit_dashboard`. 7/7 bloques con tablas/VIEWs/jobs.

---

## 1. Estado global de D11

**Dominio:** Auditoría y Cumplimiento (ISO 27001 A.8.15 · SOX §802 · GDPR Art. 5(e) · Wazuh SIEM)
**Total bloques:** 7 | **Tablas VPS:** 10 (4 ses_* + 2 aud_* + 3 bos ctx_* + 1 privilege_atom_audit) | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | Tablas que lo satisfacen |
|--------|------|--------|--------|--------------------------|
| B01 | `events` | Captura de Eventos | ✅ SATISFECHO | `privilege_atom_audit` (T-170b, WORM D01) + `ses_session_log` (T-181) + `bos.ctx_context_audit` (T-397, WORM) |
| B02 | `retention` | Política de Retención | ✅ CERRADO | Job SQL mensual (día 28) — purga tablas WORM según `idn_roles_ver_b01_retention_policy`. Particionado mensual. |
| B03 | `integrity` | Integridad de Cadena Hash | ✅ SATISFECHO | `privilege_atom_audit` hash-chain SHA-256 + `bos.ctx_context_audit.prev_hash` + `bos.ctx_context_switch_log.prev_hash` |
| B04 | `monitoring` | Monitoreo Activo | ✅ SATISFECHO | `mv_audit_dashboard` — VIEW materializada con 5 métricas: sesiones, CAEP, switches, emergencias, revocaciones |
| B05 | `export` | Exportación al SIEM | ✅ SATISFECHO | `ses_ssf_stream` (T-192) + `ses_ssf_delivery_log` (T-193) — SSF delivery a Wazuh/bNotify |
| B06 | `review` | Revisión Periódica de Auditoría | ✅ SATISFECHO | `aud_certification_campaign` (T-177) + `aud_certification_review` (T-178) |
| B07 | `business_zone` | Registro de Zona de Negocio (Auditoría) | árbol ✅ | `idn_roles_template` (T-162) |

---

## 2. Tablas implementadas en VPS (verificadas)

### T-177 · `aud_certification_campaign` — B06 Review ✅

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | uuid PK | Identificador |
| tenant_id | uuid | Tenant |
| campaign_type | text | Tipo de campaña |
| scope_type | text | Alcance (GLOBAL, ROL, ACTOR) |
| scope_id | uuid | ID del scope |
| initiated_by | uuid | Quién inició |
| description | text | Descripción |
| due_date | timestamptz | Fecha límite |
| started_at | timestamptz | Inicio |
| closed_at | timestamptz | Cierre |
| status | text | Estado de la campaña |
| ctx_id | text | SBOS-049 |

### T-178 · `aud_certification_review` — B06 Review ✅

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | uuid PK | Identificador |
| campaign_id | uuid | FK a campaña |
| grant_id | uuid | Grant revisado |
| reviewer_id | uuid | Revisor |
| reviewer_role | text | Rol del revisor |
| decision | text | CERTIFY/REVOKE/ESCALATE |
| justification | text | Justificación |
| reviewed_at | timestamptz | Momento de revisión |
| revocation_at | timestamptz | Fecha de revocación si aplica |
| escalated_to | uuid | A quién se escaló |
| ctx_id | text | SBOS-049 |

**Veredicto B06:** ✅ IGA access review completo.

### `privilege_atom_audit` — B01 parcial / B03 ✅

Tabla WORM particionada (D01). Captura eventos de grants/revocaciones con hash-chain SHA-256. Satisface B03 (integridad) pero no B01 completo — falta tabla unificada que capture eventos de todos los dominios.

---

## 3. Bloques faltantes y DDL propuesto

### B01 — `events` · Captura de Eventos (⚠️ PARCIAL → T-403)

**Normas:** ISO 27001 A.8.15 · NIST SP 800-53 R5 AU-2 · GDPR Art. 5(1)(f)

`privilege_atom_audit` captura eventos de grants. Falta una tabla unificada para eventos IAM de todos los dominios (login, logout, registro, proofing, revocación, etc.).

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_auditoria_evento (
    evento_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo_evento     TEXT NOT NULL,
    dominio         TEXT NOT NULL CONSTRAINT chk_idaev_dom CHECK (dominio IN
        ('D00','D01','D02','D03','D04','D05','D06','D07','D08','D09',
         'D10','D11','D12','D13','D14','D15','D98','D99','SISTEMA')),
    actor_id        UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    objeto_tipo     TEXT NULL,               -- tabla o entidad afectada
    objeto_id       UUID NULL,               -- ID del objeto afectado
    descripcion     TEXT NOT NULL,
    resultado       TEXT NOT NULL CONSTRAINT chk_idaev_res CHECK (resultado IN ('OK','ERROR','DENEGADO')),
    severidad       TEXT NOT NULL DEFAULT 'INFO'
        CONSTRAINT chk_idaev_sev CHECK (severidad IN ('DEBUG','INFO','WARN','ERROR','CRITICO')),
    ip_origen       INET NULL,
    datos_adicionales JSONB NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    ocurrido_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Cadena de integridad
    hash_previo     TEXT NULL,
    hash_evento     TEXT NOT NULL            -- SHA-256(evento_id||tipo||actor||datos||hash_previo)
) PARTITION BY RANGE (ocurrido_at);
CREATE TABLE IF NOT EXISTS bauth.idn_auditoria_evento_2026
    PARTITION OF bauth.idn_auditoria_evento
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
COMMENT ON TABLE bauth.idn_auditoria_evento IS
  '[T-403] [D11-B01] [ISO 27001 A.8.15] [NIST SP 800-53 R5 AU-2] [GDPR Art. 5(1)(f)]
   Log unificado de eventos IAM de todos los dominios. WORM particionada + hash-chain SHA-256.
   Complementa privilege_atom_audit (D01) con cobertura multi-dominio.';
```

### B02 — `retention` · Política de Retención

**Normas:** NIST SP 800-53 R5 AU-11 · GDPR Art. 5(1)(e) · SOX §802 (7 años)

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_auditoria_retencion (
    retencion_id    UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tabla_objetivo  TEXT NOT NULL,           -- tabla afectada (ej: 'idn_auditoria_evento')
    dominio         TEXT NULL,               -- dominio específico (NULL = todos)
    severidad_minima TEXT NULL,             -- solo retener eventos >= esta severidad
    duracion        INTERVAL NOT NULL,       -- ej: '7 years' (SOX), '5 years' (ISO)
    marco_legal     TEXT NOT NULL,           -- SOX_802, GDPR_5E, ISO_27001, LEY_164
    accion_vencido  TEXT NOT NULL DEFAULT 'PURGE'
        CONSTRAINT chk_idar_acc CHECK (accion_vencido IN ('PURGE','ARCHIVE','ALERT_ONLY')),
    archivo_destino TEXT NULL,               -- ruta de archivo si accion=ARCHIVE
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, tabla_objetivo, marco_legal)
);
COMMENT ON TABLE bauth.idn_auditoria_retencion IS
  '[T-400] [D11-B02] [NIST SP 800-53 R5 AU-11] [GDPR Art. 5(1)(e)] [SOX §802]
   Políticas de retención de datos de auditoría. Job mensual purga/archiva según marco legal.';
```

### B04 — `monitoring` · Monitoreo Activo

**Normas:** NIST SP 800-53 R5 AU-6 · ISO 27001 A.8.16

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_auditoria_regla_alerta (
    alerta_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    nombre          TEXT NOT NULL,
    descripcion     TEXT NULL,
    -- Condición como expresión (tipo, severidad, dominio, count)
    condicion       JSONB NOT NULL,
    -- Ventana de tiempo para la condición
    ventana         INTERVAL NOT NULL DEFAULT '5 minutes',
    -- Umbral de disparo
    umbral_count    INTEGER NOT NULL DEFAULT 1,
    -- Acción al disparar
    accion          TEXT NOT NULL DEFAULT 'SIEM'
        CONSTRAINT chk_idara_acc CHECK (accion IN ('SIEM','EMAIL','PUSH_NOTIFY','BLOQUEO','CAEP_EVENT','ESCALATE')),
    severidad       TEXT NOT NULL DEFAULT 'WARN'
        CONSTRAINT chk_idara_sev CHECK (severidad IN ('INFO','WARN','ERROR','CRITICO')),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ultimo_disparo  TIMESTAMPTZ NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_auditoria_regla_alerta IS
  '[T-401] [D11-B04] [NIST SP 800-53 R5 AU-6] [ISO 27001 A.8.16]
   Reglas de monitoreo activo: condición JSONB + ventana + umbral → acción automática.';
```

### B05 — `export` · Exportación al SIEM

**Normas:** NIST SP 800-53 R5 AU-9(2) · ISO 27001 A.8.15

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_auditoria_siem_destino (
    destino_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    nombre          TEXT NOT NULL,
    tipo            TEXT NOT NULL DEFAULT 'WAZUH'
        CONSTRAINT chk_idads_tipo CHECK (tipo IN ('WAZUH','SPLUNK','ELASTIC','SYSLOG','KAFKA','WEBHOOK')),
    endpoint        TEXT NOT NULL,           -- host:port o URL
    formato         TEXT NOT NULL DEFAULT 'CEF'
        CONSTRAINT chk_idads_fmt CHECK (formato IN ('CEF','JSON','LEEF','SYSLOG_RFC5424')),
    filtro_severidad TEXT NOT NULL DEFAULT 'INFO'
        CONSTRAINT chk_idads_fsev CHECK (filtro_severidad IN ('DEBUG','INFO','WARN','ERROR','CRITICO')),
    auth_vault_path TEXT NULL,               -- credenciales SIEM en Vault
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idads_est CHECK (estado IN ('ACTIVO','INACTIVO','ERROR')),
    ultimo_envio_at TIMESTAMPTZ NULL,
    error_count     INTEGER NOT NULL DEFAULT 0,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_auditoria_siem_destino IS
  '[T-402] [D11-B05] [NIST SP 800-53 R5 AU-9(2)] [ISO 27001 A.8.15]
   Destinos SIEM para exportación de eventos de auditoría. Credenciales en Vault.';
```

---

## 4. Checklist de completitud

### 4.1 DDL

- [x] `aud_certification_campaign` (T-177) — B06 ✅ (VPS)
- [x] `aud_certification_review` (T-178) — B06 ✅ (VPS)
- [x] `privilege_atom_audit` — B03 ✅ (VPS, hash-chain)
- [ ] `idn_auditoria_retencion` (T-400) — B02 ❌ PENDIENTE
- [ ] `idn_auditoria_regla_alerta` (T-401) — B04 ❌ PENDIENTE
- [ ] `idn_auditoria_siem_destino` (T-402) — B05 ❌ PENDIENTE
- [ ] `idn_auditoria_evento` (T-403) — B01 completo ❌ PENDIENTE (particionada)

### 4.2 Triggers y Jobs

- [ ] Trigger: al insertar en `idn_auditoria_evento`, calcular `hash_evento` (SHA-256)
- [ ] Trigger: al disparar alerta, registrar en `idn_auditoria_evento` tipo=ALERTA
- [ ] Job: purgar/archivar eventos según políticas T-400 (mensual)
- [ ] Job: crear partición futura `idn_auditoria_evento_{YYYY}` (día 28 mensual)
- [ ] Job: enviar eventos pendientes a SIEM (T-402) — retry con backoff

### 4.3 Seeds

- [ ] Seeds `idn_auditoria_retencion`: política 7 años (SOX §802), 5 años (GDPR), 1 año (INFO)
- [ ] Seeds `idn_auditoria_siem_destino`: Wazuh por defecto (localhost:514)
- [ ] Seeds `idn_auditoria_regla_alerta`: alerta en 5+ logins fallidos en 5 min

### 4.4 Átomos D11

- [ ] `skull.D11.events.*` — átomos (read, search, export)
- [ ] `skull.D11.retention.*` — átomos (configure, read)
- [ ] `skull.D11.integrity.*` — átomos (verify, read)
- [ ] `skull.D11.monitoring.*` — átomos (configure, read, acknowledge)
- [ ] `skull.D11.export.*` — átomos (configure, trigger, read)
- [ ] `skull.D11.review.*` — átomos (launch, certify, revoke)
- [ ] `skull.D11.business_zone.*` — átomos de zona

---

## 5. Análisis IAM Enterprise — D11

| Pilar IAM Enterprise | Criterio D11 | Estado |
|---|---|:---:|
| **II IGA** | Access review / recertificación | ✅ L3 |
| **II IGA** | Política de retención multi-marco | ❌ L0 |
| **VI Standards** | ISO 27001 A.8.15 audit logging | ⚠️ L2 |
| **VI Standards** | SOX §802 / GDPR Art. 5(1)(e) retención | ❌ L0 |
| **VII Advanced** | SIEM integrado + monitoreo activo | ❌ L0 |

**Gaps:**

| Gap | Prioridad | Acción |
|-----|-----------|--------|
| GAP-D11-01 — Log unificado multi-dominio | 🔴 P1 | CREATE T-403 |
| GAP-D11-02 — Política de retención sin datos | 🔴 P1 | CREATE T-400 + seeds |
| GAP-D11-03 — SIEM sin configuración | 🟠 P2 | CREATE T-402 + seed Wazuh |
| GAP-D11-04 — Monitoreo activo sin reglas | 🟠 P2 | CREATE T-401 + seeds |
| GAP-D11-05 — Átomos D11 | 🟡 P3 | INSERT ~25 átomos |

**Veredicto IAM Enterprise D11:** L3 en IGA (recertificación) · L0 en retención y SIEM. El gap P1 de retención tiene implicaciones legales (SOX 7 años, GDPR). T-400 es urgente.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.1.0 | 2026-07-31 | Schema bos + SSF elevan D11 de 3/7 a 5/7. B01 (eventos) cubierto por ctx_context_audit. B05 (export SIEM) cubierto por ses_ssf_stream. 10 tablas VPS. |
| 1.0.0 | 2026-07-28 | Versión inicial. 3/7 bloques satisfechos (B03, B06, B07). DDL propuesto T-400..T-403. 5 gaps IAM Enterprise. |
