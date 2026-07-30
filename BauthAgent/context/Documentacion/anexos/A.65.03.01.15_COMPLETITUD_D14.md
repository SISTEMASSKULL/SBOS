# A.65.03.01.15 — Informe de Completitud: D14 Gestión de Acceso Privilegiado (PAM)

**Versión:** 1.0.0 · **Fecha:** 2026-07-28
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D14.*`)
**Estado de D14:** ⚠️ PARCIAL — 5/7 bloques satisfechos · 2 tablas adicionales propuestas (T-460..T-461)

> **T-code range:** T-460..T-479 (tablas PAM existentes renumeradas en rango D14)

---

## 1. Estado global de D14

**Dominio:** Gestión de Acceso Privilegiado (PAM — JIT · PSS · Bóveda · Grabación · Breakglass)
**Total bloques:** 7 | **Tablas propias:** 6 implementadas | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | Tablas que lo satisfacen |
|--------|------|--------|--------|--------------------------|
| B01 | `discovery` | Inventario de Cuentas Privilegiadas | ⚠️ PARCIAL | `pam_credential_ref` (metadatos) · falta tabla de inventario completa |
| B02 | `vaulting` | Bóveda de Credenciales | ✅ SATISFECHO | `pam_credential_ref` + Vault PKI |
| B03 | `jit` | Acceso Justo a Tiempo (JIT) | ✅ SATISFECHO | `pam_jit_request` + `pam_jit_approval` |
| B04 | `brokering` | Mediación de Sesión Privilegiada | ✅ SATISFECHO | `pam_session_record` |
| B05 | `review` | Revisión de Privilegios | ✅ SATISFECHO | `aud_certification_campaign` + `aud_certification_review` |
| B06 | `session_recording` | Grabación de Sesión Privilegiada | ⚠️ PARCIAL | `pam_session_record` (metadatos) · falta ref a grabación |
| B07 | `business_zone` | Registro de Zona de Negocio (PAM) | árbol ✅ | `idn_roles_template` |

---

## 2. Tablas implementadas en VPS (verificadas)

### `pam_jit_request` — B03 JIT ✅

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | uuid PK | Identificador |
| tenant_id | uuid | Tenant |
| requester_id | uuid | Actor solicitante |
| target_role_id | uuid | Rol privilegiado solicitado |
| target_atoms | uuid[] | Átomos específicos (si aplica) |
| justification | text | Justificación de negocio |
| requested_duration | interval | Duración solicitada |
| max_duration | interval | Duración máxima permitida |
| niveles_requeridos | integer | Número de aprobadores requeridos |
| requested_at | timestamptz | Momento de solicitud |
| status | text | Estado (PENDIENTE/APROBADO/RECHAZADO/ACTIVO/EXPIRADO/REVOCADO) |
| rejection_reason | text | Motivo de rechazo |
| grant_id | uuid | Grant temporal creado |
| activated_at, valid_from, valid_until, expired_at, revoked_at, revoked_by | — | Ciclo de vida |
| ctx_id | text | SBOS-049 |

### `pam_jit_approval` — B03 JIT ✅

| Columna | Tipo | Descripción |
|---------|------|-------------|
| id | uuid PK | Identificador |
| request_id | uuid | FK a jit_request |
| nivel | integer | Nivel de aprobación (1, 2, ...) |
| required_role | text | Rol requerido del aprobador |
| approver_id | uuid | Aprobador real |
| decision | text | APROBADO/RECHAZADO |
| notified_at | timestamptz | Notificación enviada |
| decision_at | timestamptz | Decisión tomada |
| notes | text | Notas del aprobador |
| ctx_id | text | SBOS-049 |

### `pam_session_record` — B04 Brokering / B06 Recording ⚠️

Tabla de sesiones PAM (PSS). Tiene metadatos de la sesión privilegiada pero no referencia al archivo de grabación.

### `pam_credential_ref` — B01 Discovery / B02 Vaulting ✅/⚠️

Referencia a credenciales privilegiadas en Vault. Cubre bóveda, pero el inventario de cuentas privilegiadas requiere más estructura.

### `pam_breakglass_activation` — B03 emergencia ✅

Activaciones de acceso de emergencia PAM (breakglass). Complementa JIT para casos de fuerza mayor.

### `pam_nhi_secret_ref` — referencia cruzada D15

Referencias a secretos de identidades no humanas en Vault. Cubre D15/B04 y también aplica a D14.

---

## 3. Bloques faltantes y DDL propuesto

### B01 — `discovery` · Inventario de Cuentas Privilegiadas (⚠️ PARCIAL → T-460)

**Normas:** NIST SP 800-53 R5 AC-2(7) · CIS Controls v8 §5.1

`pam_credential_ref` registra referencias por solicitud. Falta un **inventario maestro** de cuentas privilegiadas que existan en el sistema, independientemente de si están siendo usadas actualmente.

```sql
CREATE TABLE IF NOT EXISTS bauth.pam_cuenta_privilegiada (
    cuenta_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo            TEXT NOT NULL CONSTRAINT chk_pdcp_tipo CHECK (tipo IN (
        'LOCAL_ADMIN','DOMAIN_ADMIN','SERVICE_ACCOUNT','SHARED','ROOT','API_KEY',
        'CERTIFICATE','SSH_KEY','DATABASE_DBA','CLOUD_ADMIN')),
    nombre          TEXT NOT NULL,           -- nombre de la cuenta (ej: 'root', 'sa_erp')
    sistema         TEXT NOT NULL,           -- sistema donde existe (ej: 'linux-prod-01', 'postgresql')
    propietario_id  UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    responsable_id  UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    estado          TEXT NOT NULL DEFAULT 'ACTIVA'
        CONSTRAINT chk_pdcp_est CHECK (estado IN ('ACTIVA','INACTIVA','COMPROMETIDA','EN_REVISION')),
    -- En Vault
    vault_path      TEXT NULL,
    ultimo_rotado   TIMESTAMPTZ NULL,
    proxima_rotacion TIMESTAMPTZ NULL,
    -- Criticidad
    nivel_criticidad TEXT NOT NULL DEFAULT 'ALTO'
        CONSTRAINT chk_pdcp_crit CHECK (nivel_criticidad IN ('BAJO','MEDIO','ALTO','CRITICO')),
    requiere_jit    BOOLEAN NOT NULL DEFAULT TRUE,
    requiere_grabacion BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, sistema, nombre)
);
COMMENT ON TABLE bauth.pam_cuenta_privilegiada IS
  '[T-460] [D14-B01] [NIST SP 800-53 R5 AC-2(7)] [CIS Controls v8 §5.1]
   Inventario maestro de cuentas privilegiadas. Toda cuenta privilegiada debe estar aquí antes de usarse.';
```

### B06 — `session_recording` · Grabación de Sesión Privilegiada (⚠️ PARCIAL → T-461)

**Normas:** NIST SP 800-53 R5 AU-14 · ISO 27001 A.8.20

`pam_session_record` tiene metadatos de sesión pero no la referencia al archivo de grabación (keystroke logging, screen recording). La grabación va a almacenamiento cifrado; esta tabla registra dónde está y con qué hash de integridad.

```sql
CREATE TABLE IF NOT EXISTS bauth.pam_grabacion_ref (
    grabacion_id    UUID PRIMARY KEY DEFAULT uuidv7(),
    session_id      UUID NOT NULL REFERENCES bauth.pam_session_record(id),
    tipo_grabacion  TEXT NOT NULL DEFAULT 'KEYSTROKE'
        CONSTRAINT chk_pdgr_tipo CHECK (tipo_grabacion IN ('KEYSTROKE','SCREEN','FULL','METADATA_ONLY')),
    -- Almacenamiento
    storage_path    TEXT NOT NULL,           -- ruta en almacenamiento cifrado (S3-like o NFS)
    tamaño_bytes    BIGINT NULL,
    duracion_seg    INTEGER NULL,
    hash_sha256     TEXT NOT NULL,           -- integridad del archivo
    cifrado_vault_key TEXT NOT NULL,         -- referencia a la clave de cifrado en Vault
    -- Retención
    retener_hasta   TIMESTAMPTZ NOT NULL,    -- según política D11 (normalmente 1-7 años)
    -- Estado
    completado_at   TIMESTAMPTZ NULL,
    estado          TEXT NOT NULL DEFAULT 'GRABANDO'
        CONSTRAINT chk_pdgr_est CHECK (estado IN ('GRABANDO','COMPLETADO','PURGADO','ERROR')),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.pam_grabacion_ref IS
  '[T-461] [D14-B06] [NIST SP 800-53 R5 AU-14] [ISO 27001 A.8.20]
   Referencias a grabaciones de sesiones privilegiadas. Archivo cifrado en storage; hash aquí para integridad.';
```

---

## 4. Checklist de completitud

### 4.1 DDL

- [x] `pam_jit_request` — B03 ✅ (VPS)
- [x] `pam_jit_approval` — B03 ✅ (VPS)
- [x] `pam_session_record` — B04/B06 ✅/⚠️ (VPS)
- [x] `pam_credential_ref` — B01/B02 ⚠️/✅ (VPS)
- [x] `pam_breakglass_activation` — B03 emergencia ✅ (VPS)
- [x] `pam_nhi_secret_ref` — D15 cross-ref ✅ (VPS)
- [ ] `pam_cuenta_privilegiada` (T-460) — B01 completo ❌ PENDIENTE
- [ ] `pam_grabacion_ref` (T-461) — B06 completo ❌ PENDIENTE

### 4.2 Triggers

- [ ] Trigger: al aprobar JIT, crear `privilege_atom_grant` temporal con `valid_until = now() + requested_duration`
- [ ] Trigger: al expirar JIT, revocar grant automáticamente + CAEP event
- [ ] Trigger: al cerrar `pam_session_record`, marcar `pam_grabacion_ref.estado = COMPLETADO`

### 4.3 Jobs

- [ ] Job: revocar JIT expirados (cada 30 segundos en horario activo)
- [ ] Job: rotar credenciales en `pam_cuenta_privilegiada` cuando `proxima_rotacion < now()`
- [ ] Job: purgar grabaciones vencidas (`retener_hasta < now()`)
- [ ] Job: alertar cuentas privilegiadas sin revisión > 90 días

### 4.4 Átomos D14

- [ ] `skull.D14.discovery.*` — átomos (read, register, update, decommission)
- [ ] `skull.D14.vaulting.*` — átomos (store, retrieve, rotate)
- [ ] `skull.D14.jit.*` — átomos (request, approve, reject, activate, revoke)
- [ ] `skull.D14.brokering.*` — átomos (connect, disconnect, monitor)
- [ ] `skull.D14.review.*` — átomos (launch, certify, revoke)
- [ ] `skull.D14.session_recording.*` — átomos (start, stop, review, export)
- [ ] `skull.D14.business_zone.*` — átomos de zona

---

## 5. Análisis IAM Enterprise — D14

### 5.1 Cobertura de pilares

| Pilar IAM Enterprise | Criterio D14 | Estado |
|---|---|:---:|
| **III PAM** | JIT access (zero standing privilege) | ✅ L3 |
| **III PAM** | Bóveda de credenciales (Vault) | ✅ L3 |
| **III PAM** | Mediación PSS (Session Brokering) | ✅ L3 |
| **III PAM** | Inventario maestro privilegiado | ❌ L0 |
| **III PAM** | Grabación de sesión con integridad | ⚠️ L2 |
| **II IGA** | Revisión periódica privilegios | ✅ L3 |
| **VI Standards** | NIST SP 800-53 R5 AC-2(7)/AC-6(9) | ⚠️ L2 |

### 5.2 Gaps IAM Enterprise D14

| Gap | Prioridad | Acción |
|-----|-----------|--------|
| GAP-D14-01 — Inventario privilegiado sin tabla maestra | 🔴 P1 | CREATE T-460 |
| GAP-D14-02 — Grabación sin ref a archivo + hash | 🟠 P2 | CREATE T-461 |
| GAP-D14-03 — Rotación automática sin job | 🟠 P2 | Job de rotación |
| GAP-D14-04 — Átomos D14 | 🟠 P2 | INSERT ~28 átomos |

### 5.3 Veredicto IAM Enterprise

D14 tiene la **base PAM más sólida del ecosistema** — JIT multi-nivel con quórum (L3), bóveda Vault (L3), mediación de sesión (L3). Los gaps son complementos de gobernanza (inventario maestro, grabación completa). Madurez global D14: **L3 en núcleo JIT/PSS/Vault**.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-28 | Versión inicial. 5/7 bloques satisfechos. DDL propuesto T-460 + T-461. 4 gaps. Madurez D14: L3 núcleo PAM. |
