# A.65.03.01.16 — Informe de Completitud: D15 Identidad No Humana (NHI)

**Versión:** 1.0.0 · **Fecha:** 2026-07-28
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D15.*`)
**Estado de D15:** ⚠️ PARCIAL — 6/8 bloques satisfechos · 2 tablas adicionales propuestas (T-480..T-481)

> **T-code range:** T-480..T-499

---

## 1. Estado global de D15

**Dominio:** Identidad No Humana (SPIFFE/SPIRE · AI Agents · Service Accounts · Workload Identity)
**Total bloques:** 8 | **Tablas propias:** 4 implementadas | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | Tablas que lo satisfacen |
|--------|------|--------|--------|--------------------------|
| B01 | `service_account` | Cuentas de Servicio | ✅ SATISFECHO | `idn_roles_nhi_identity` |
| B02 | `workload` | Identidad de Carga de Trabajo (SPIFFE) | ✅ SATISFECHO | `idn_roles_nhi_identity` |
| B03 | `agent` | Identidad de Agentes de IA | ✅ SATISFECHO | `idn_roles_nhi_agent_identity` |
| B04 | `secrets` | Secretos de Máquina | ✅ SATISFECHO | `pam_nhi_secret_ref` (D14) |
| B05 | `rotation` | Rotación Automática de Credenciales | ⚠️ PARCIAL | `idn_roles_nhi_lifecycle_event` (parcial) |
| B06 | `attestation` | Atestación SPIFFE / SPIRE | ⚠️ PARCIAL | `idn_roles_nhi_certification` (parcial) |
| B07 | `governance` | Gobierno de Identidades No Humanas | ✅ SATISFECHO | `idn_roles_nhi_certification` + `idn_roles_nhi_lifecycle_event` |
| B08 | `business_zone` | Registro de Zona de Negocio (NHI) | árbol ✅ | `idn_roles_template` |

---

## 2. Tablas implementadas en VPS (verificadas)

### `idn_roles_nhi_identity` — B01 + B02 ✅

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | uuid PK | Identificador |
| tenant_id | uuid | Tenant |
| nhi_type | text | Tipo (SERVICE_ACCOUNT, WORKLOAD, M2M, BOT, IOT, PIPELINE) |
| display_name | text | Nombre de la identidad |
| system_ref | text | Referencia al sistema (ej: 'k8s:default:my-service') |
| owner_id | uuid | Propietario humano responsable |
| backup_owner_id | uuid | Propietario de respaldo |
| description | text | Descripción |
| status | text | ACTIVE, SUSPENDED, DECOMMISSIONED |
| created_at, created_by | — | Auditoría de creación |
| last_used_at | timestamptz | Último uso |
| review_at | timestamptz | Próxima revisión |
| decommission_at | timestamptz | Fecha de decomisión programada |
| ctx_id | text | SBOS-049 |

**Veredicto B01+B02:** ✅ Registro completo de identidades NHI con propietario y ciclo de vida básico.

### `idn_roles_nhi_agent_identity` — B03 ✅

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | uuid PK | Identificador |
| nhi_id | uuid | FK a nhi_identity |
| agent_framework | text | Framework del agente (LANGCHAIN, CLAUDE_SDK, etc.) |
| orchestrator_id | uuid | Orquestador padre (para agentes jerárquicos) |
| max_permission_scope | text[] | Scopes máximos permitidos (least privilege) |
| session_type | text | Tipo de sesión de agente |
| can_spawn_agents | boolean | ¿Puede crear sub-agentes? |
| max_spawn_depth | integer | Profundidad máxima de spawning |

**Veredicto B03:** ✅ Cumple NIST AI RMF 1.0 — scope máximo, jerarquía de agentes, control de spawning.

### `idn_roles_nhi_certification` — B06 + B07 ⚠️/✅

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | uuid PK | Identificador |
| nhi_id | uuid | FK a nhi_identity |
| reviewer_id | uuid | Revisor |
| period_start/end | timestamptz | Período de certificación |
| last_used_at | timestamptz | Último uso en el período |
| access_count | integer | Accesos en el período |
| decision | text | CERTIFY/REVOKE/SUSPEND |
| justification | text | Justificación |
| reviewed_at | timestamptz | Momento de revisión |
| ctx_id | text | SBOS-049 |

**B06 Attestation:** ⚠️ Parcial — cubre revisión de certificación, pero falta el SVID (SPIFFE Verifiable Identity Document) como struct tipado.
**B07 Governance:** ✅ Cumple ciclo de revisión periódica.

### `idn_roles_nhi_lifecycle_event` — B05 + B07 ✅/⚠️

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | uuid PK | Identificador |
| nhi_id | uuid | FK a nhi_identity |
| event_type | text | Tipo de evento (CREATED, ACTIVATED, SUSPENDED, etc.) |
| actor_id | uuid | Quién ejecutó el evento |
| event_at | timestamptz | Momento |
| notes | text | Notas |
| metadata | jsonb | Datos adicionales |
| ctx_id | text | SBOS-049 |

**B05 Rotation:** ⚠️ Parcial — `event_type` puede registrar rotación de credenciales, pero falta la tabla que programe la rotación automática.
**B07 Governance:** ✅ WORM de eventos del ciclo de vida.

---

## 3. Bloques faltantes y DDL propuesto

### B05 — `rotation` · Rotación Automática (⚠️ PARCIAL → T-480)

**Normas:** NIST SP 800-57 Pt1 R5 §5.3 · CIS Controls v8 §4.4

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_nhi_rotacion_policy (
    policy_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    nhi_type        TEXT NULL,               -- NULL = aplica a todos los tipos NHI
    secret_tipo     TEXT NOT NULL CONSTRAINT chk_idnrp_tipo CHECK (secret_tipo IN
        ('API_KEY','TOKEN_JWT','CERTIFICADO','SSH_KEY','PASSWORD_SA','SPIFFE_SVID')),
    frecuencia      INTERVAL NOT NULL DEFAULT '90 days',
    pre_aviso       INTERVAL NOT NULL DEFAULT '7 days',  -- días antes de vencer para alertar
    rotar_automatico BOOLEAN NOT NULL DEFAULT FALSE,      -- si true, bAuth rota sin intervención
    accion_fallo    TEXT NOT NULL DEFAULT 'ALERTA'
        CONSTRAINT chk_idnrp_acc CHECK (accion_fallo IN ('ALERTA','SUSPENDER','ESCALAR')),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, nhi_type, secret_tipo)
);
COMMENT ON TABLE bauth.idn_nhi_rotacion_policy IS
  '[T-480] [D15-B05] [NIST SP 800-57 Pt1 R5 §5.3] [CIS Controls v8 §4.4]
   Políticas de rotación automática de credenciales NHI. El job de rotación consulta esta tabla.';
```

### B06 — `attestation` · Atestación SPIFFE (⚠️ PARCIAL → T-481)

**Normas:** SPIFFE Spec v1.0 §8 · NIST SP 800-204A §4

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_nhi_svid (
    svid_id         UUID PRIMARY KEY DEFAULT uuidv7(),
    nhi_id          UUID NOT NULL REFERENCES bauth.idn_roles_nhi_identity(id),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    -- SPIFFE ID
    spiffe_id       TEXT NOT NULL,           -- spiffe://sbos/{tenant}/{service}
    tipo_svid       TEXT NOT NULL DEFAULT 'X509'
        CONSTRAINT chk_idns_tipo CHECK (tipo_svid IN ('X509','JWT')),
    -- Para X.509 SVID
    cert_fingerprint TEXT NULL,              -- fingerprint del certificado
    subject_alt_name TEXT NULL,              -- SAN con el SPIFFE ID
    vault_path      TEXT NOT NULL,           -- cert/key en Vault
    -- Para JWT SVID
    jti             TEXT NULL,
    audience        TEXT[] NULL,
    -- Vigencia
    valid_from      TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until     TIMESTAMPTZ NOT NULL,
    -- Estado
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idns_est CHECK (estado IN ('ACTIVO','ROTADO','REVOCADO','EXPIRADO')),
    spire_node      TEXT NULL,               -- nodo SPIRE que emitió el SVID
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    emitido_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (nhi_id, spiffe_id, estado)
);
COMMENT ON TABLE bauth.idn_nhi_svid IS
  '[T-481] [D15-B06] [SPIFFE Spec v1.0 §8] [NIST SP 800-204A §4]
   SVIDs (SPIFFE Verifiable Identity Documents) emitidos por SPIRE para workloads.
   El cert/key vive en Vault; aquí el SPIFFE ID y metadatos para verificación rápida.';
```

---

## 4. Checklist de completitud

### 4.1 DDL

- [x] `idn_roles_nhi_identity` — B01+B02 ✅ (VPS)
- [x] `idn_roles_nhi_agent_identity` — B03 ✅ (VPS)
- [x] `idn_roles_nhi_certification` — B06+B07 ⚠️/✅ (VPS)
- [x] `idn_roles_nhi_lifecycle_event` — B05+B07 ⚠️/✅ (VPS)
- [x] `pam_nhi_secret_ref` — B04 ✅ (VPS, compartida con D14)
- [ ] `idn_nhi_rotacion_policy` (T-480) — B05 completo ❌ PENDIENTE
- [ ] `idn_nhi_svid` (T-481) — B06 completo ❌ PENDIENTE

### 4.2 Triggers

- [ ] Trigger: al revocar NHI (`idn_roles_nhi_identity.status = DECOMMISSIONED`), marcar todos sus SVIDs como REVOCADOS
- [ ] Trigger: al emitir SVID, registrar evento en `idn_roles_nhi_lifecycle_event`

### 4.3 Jobs

- [ ] Job: alertar SVIDs a vencer (según `pre_aviso` de T-480)
- [ ] Job: rotar automáticamente los SVIDs cuando `rotar_automatico=true` y `valid_until - pre_aviso < now()`
- [ ] Job: revisar NHIs sin rotación > `frecuencia` en `idn_nhi_rotacion_policy`
- [ ] Job: alertar NHIs con `review_at < now()` y sin certificación

### 4.4 Seeds

- [ ] Seeds `idn_nhi_rotacion_policy`: política por defecto (JWT=1d, X509=30d, API_KEY=90d, SSH_KEY=365d)

### 4.5 Átomos D15

- [ ] `skull.D15.service_account.*` — átomos (register, activate, suspend, decommission)
- [ ] `skull.D15.workload.*` — átomos (register, issue_svid, revoke)
- [ ] `skull.D15.agent.*` — átomos (register, configure, limit_scope)
- [ ] `skull.D15.secrets.*` — átomos (store, retrieve, rotate)
- [ ] `skull.D15.rotation.*` — átomos (configure, trigger, review)
- [ ] `skull.D15.attestation.*` — átomos (issue_svid, verify, revoke)
- [ ] `skull.D15.governance.*` — átomos (review, certify, decommission)
- [ ] `skull.D15.business_zone.*` — átomos de zona

---

## 5. Análisis IAM Enterprise — D15

### 5.1 Cobertura de pilares

| Pilar IAM Enterprise | Criterio D15 | Estado |
|---|---|:---:|
| **IV Machine Identity** | Service accounts con propietario | ✅ L3 |
| **IV Machine Identity** | Workload identity SPIFFE/SPIRE | ⚠️ L2 (falta SVID) |
| **IV Machine Identity** | AI Agent identity con scope máximo | ✅ L3 |
| **IV Machine Identity** | Secretos de máquina en Vault | ✅ L3 |
| **IV Machine Identity** | Rotación automática | ⚠️ L2 (falta policy) |
| **II IGA** | Certificación periódica de NHIs | ✅ L3 |
| **VI Standards** | SPIFFE Spec v1.0 / NIST SP 800-204A | ⚠️ L2 |
| **VII Advanced** | IA Agent governance | ✅ L3 |

### 5.2 Gaps IAM Enterprise D15

| Gap | Prioridad | Acción |
|-----|-----------|--------|
| GAP-D15-01 — SVID SPIFFE sin tabla | 🔴 P1 | CREATE T-481 |
| GAP-D15-02 — Rotación auto sin política | 🟠 P2 | CREATE T-480 + seeds |
| GAP-D15-03 — Átomos D15 | 🟠 P2 | INSERT ~30 átomos |

### 5.3 Veredicto IAM Enterprise

D15 tiene **la implementación NHI más avanzada de SBOS** — cuentas de servicio con propietario obligatorio (L3), AI Agent scope máximo controlable (L3), certificación periódica (L3), secretos en Vault (L3). Los gaps son: SVID SPIFFE tipado (T-481) y política de rotación automática (T-480).

**Madurez global D15: L2-L3** — casi completo. El SVID (T-481) es el gap más crítico para interoperabilidad SPIFFE.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-28 | Versión inicial. 6/8 bloques satisfechos. DDL propuesto T-480 + T-481. 3 gaps. Madurez D15: L2-L3 (la NHI más madura del ecosistema). |
