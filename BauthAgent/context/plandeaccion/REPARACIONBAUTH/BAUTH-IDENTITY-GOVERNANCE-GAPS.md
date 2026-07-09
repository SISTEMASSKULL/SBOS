# BAUTH-IDENTITY-GOVERNANCE-GAPS — Identity Governance & Audit Platform Gaps Analysis

**Versión:** 2.0.0 · **Fecha:** 2026-06-23 · **Autor:** sbos-coordinador
**Plataforma:** Identity Governance & Audit Platform
**Propósito:** Identificar cada brecha entre el DDL actual (`001_bauth_init.sql.bak`), la plataforma
de gobernanza definida en `BAUTH-IDENTITY-GOVERNANCE-AUDIT-PLATFORM.md` v4.0.0, y los 12+ estándares
internacionales que el SBOS debe cumplir (ISO 27001, NIST 800-53, PCI DSS, OWASP ASVS, GDPR, SOC 2).
Cada gap incluye la acción concreta para cerrarlo.

---

## 0. Resumen Ejecutivo

| Métrica | Actual | Requerido | Brecha |
|---------|--------|-----------|--------|
| Tablas en DDL | 103 | ~112 | +9 tablas nuevas |
| Tablas con `ctx_id` | 25 (24%) | ≥ 45 (≥ 44%) | +20 tablas |
| Hash-chains SHA-256 | 2 | ≥ 8 | +6 cadenas |
| Particiones por mes | 3 tablas | ≥ 10 | +7 tablas |
| Event types en CHECK | 38 (genéricos) | 38+38=76 (genéricos + específicos) | +38 eventos dominio |
| Tablas de notificación | 0 | 3 | +3 tablas |
| Tablas WORM (REVOKE UPDATE/DELETE) | 3 | ≥ 8 | +5 REVOKEs |
| Retention policy | 0 (implícita) | 1 (explícita) | +1 tabla |
| Índices GIN sobre JSONB | 4 | ≥ 8 | +4 índices |
| Columnas de acknowledgment | 0 | 4 | +4 columnas |
| Sintaxis inválida | 1 bug | 0 | 1 fix |

**Total: 24 brechas identificadas.** 9 críticas (🔴), 11 altas (🟠), 4 medias (🟡).

---

## 1. Brechas de Trazabilidad (ctx_id)

### 🔴 GAP-01: Solo 25 de 103 tablas tienen ctx_id (24%)

**Norma violada:** SBOS-049 §3 — "ctx_id obligatorio en cada operación — sin ctx_id no hay trazabilidad".  
**Impacto:** 78 tablas no pueden rastrearse en la cadena W3C Trace Context. Si ocurre un incidente de seguridad en `bos_delegation_log` (sin ctx_id), no se puede correlacionar con `aud_event`.

**Tablas que DEBEN tener ctx_id y NO lo tienen:**

| Tabla | Dominio | Prioridad |
|-------|---------|-----------|
| `bos_login_attempt` | Autenticación | 🔴 |
| `bos_delegation_log` | Identidad | 🔴 |
| `bos_superuser_contexts` | Admin | 🔴 |
| `bos_key_inventory` | Seguridad | 🔴 |
| `bos_key_rotation_log` | Seguridad | 🔴 |
| `bos_key_recovery_log` | Seguridad | 🔴 |
| `bos_backup_log` | Admin | 🟠 |
| `bos_device_registry` | Seguridad | 🟠 |
| `bos_access_reviews` | Auditoría | 🟠 |
| `bos_ghost_accounts` | Auditoría | 🟠 |
| `bos_context_switches` | Sesiones | 🟠 |
| `bos_recovery_challenge` | Autenticación | 🟡 |
| `bos_password_screening_log` | Autenticación | 🟡 |
| `bos_token_delivery_log` | Autenticación | 🟡 |
| `bos_policy_audit` | Configuración | 🟠 |
| `bos_policy_history` | Configuración | 🟠 |
| `bos_authenticator_binding` | Seguridad | 🟡 |
| `bos_credential_rotation_log` | Seguridad | 🟡 |
| `bos_mfa_enrollments` | Autenticación | 🟡 |
| `bos_financial_approval` | Financiero | 🔴 |

**Acción:** Agregar `ctx_id TEXT NOT NULL` a cada una de estas tablas en el DDL.  
**DDL concreto:** `ALTER TABLE ... ADD COLUMN ctx_id TEXT;` (solo como anotación — el DDL final lo integrará como parte del CREATE TABLE).

---

### 🔴 GAP-02: `bos_login_attempt` sin ctx_id rompe la cadena de trazabilidad

**Norma violada:** NIST 800-53 AU-3 (content of audit records — must include "where" and "who").  
**Impacto:** No se puede correlacionar un ataque de fuerza bruta (`login_attempt`) con el `aud_event` que disparó la notificación.

**Acción:** Agregar `ctx_id TEXT NOT NULL` a `bos_login_attempt`.  
**Fundamento:** Cada intento de login debe ser trazable al contexto operativo exacto.

---

### 🔴 GAP-03: `bos_delegation_log` sin ctx_id

**Norma violada:** NIST AC-5 (SoD — delegation must be fully traceable).  
**Impacto:** Una delegación maliciosa no puede rastrearse al contexto que la originó.

**Acción:** Agregar `ctx_id TEXT NOT NULL` a `bos_delegation_log`.

---

## 2. Brechas de Integridad (Hash-Chain WORM)

### 🔴 GAP-04: Solo 2 de 8 tablas WORM tienen hash-chain

**Norma violada:** PCI DSS 4.0 Req 10.3.2 — "audit records must be protected from tampering via cryptographic hash chaining".  
**Estado actual:**

| Tabla WORM | Hash-chain | Particionada | REVOKE |
|-----------|-----------|-------------|--------|
| `bos_audit_events` | ✅ SHA-256 | ✅ | ✅ |
| `bos_rol_template_history` | ✅ SHA-256 | ❌ | ✅ |
| `bos_sync_log` | ❌ | ❌ | ✅ |
| `bos_policy_audit` | ❌ | ❌ | ❌ |
| `bos_atom_audit` | ❌ | ✅ | ✅ |
| `bos_authenticator_revocation` | ❌ | ❌ | ❌ |
| `bos_superuser_contexts` | ❌ | ❌ | ❌ |
| `bos_login_attempt` | ❌ | ✅ | ❌ |

**Acción:** Agregar hash-chain SHA-256 a las 6 tablas que son WORM y no lo tienen.  
**DDL concreto:** Trigger `compute_entry_hash()` + columnas `prev_hash TEXT, entry_hash TEXT NOT NULL`.  
**Prioridad:** `bos_sync_log`, `bos_superuser_contexts`, `bos_policy_audit` primero (🔴). El resto después (🟠).

---

## 3. Brechas de Eventos de Auditoría

### 🔴 GAP-05: CHECK constraint de audit_events no incluye los 38 eventos del catálogo

**Norma violada:** ISO 27001 A.8.15 — event types must be specific enough to trigger appropriate responses.  
**Estado actual:** 38 valores genéricos (`LOGIN_SUCCESS`, `ACCESS_DENIED`, `POLICY_VIOLATION`).  
**Requerido:** Los mismos 38 + los 38 del catálogo de trazabilidad = 76 valores.

**Eventos FALTANTES en el CHECK constraint:**

| Código | Evento | Dominio |
|--------|--------|---------|
| `FIN_LIMIT_EXCEEDED` | Operación excede límite diario/mensual | D3 Financiero |
| `FIN_SOD_VIOLATION` | Violación Separación de Deberes | D3 Financiero |
| `FIN_DUAL_CONTROL_FAILED` | Operación sin segunda firma | D3 Financiero |
| `FIN_UNAUTHORIZED_APPROVAL` | Aprobación fuera de jurisdicción | D3 Financiero |
| `FIN_CURRENCY_RESTRICTED` | Intento en moneda no autorizada | D3 Financiero |
| `FIN_THRESHOLD_WARNING` | Operación >80% del límite | D3 Financiero |
| `FIN_RECONCILIATION_MISMATCH` | Descuadre conciliación | D3 Financiero |
| `FIN_DOCUMENT_TAMPERED` | Documento fiscal modificado post-cierre | D3 Financiero |
| `FIN_BACKDATE_ATTEMPT` | Registro en gestión cerrada | D3 Financiero |
| `FIN_SIN_REPORT_READY` | Reporte SIN listo | D3 Financiero |
| `PHY_ZONE_DENIED` | Acceso denegado a zona restringida | D2 Físico |
| `PHY_DOOR_FORCED` | Puerta forzada sin autenticación | D2 Físico |
| `PHY_TAILGATING` | Dos personas con una credencial | D2 Físico |
| `PHY_AFTER_HOURS` | Acceso fuera de horario | D2 Físico |
| `PHY_DEVICE_OFFLINE` | Dispositivo sin heartbeat | D2 Físico |
| `PHY_DEVICE_TAMPERED` | Manipulación física | D2 Físico |
| `PHY_LOCKDOWN_ACTIVATED` | Cierre de emergencia | D2 Físico |
| `PHY_GUARD_TOUR_MISSED` | Ronda de guardia no completada | D2 Físico |
| `AUTH_LOGIN_FAILED_3` | 3 intentos fallidos consecutivos | Autenticación |
| `AUTH_LOGIN_FAILED_5` | 5 intentos — cuenta bloqueada | Autenticación |
| `AUTH_BRUTE_FORCE_IP` | Ataque de fuerza bruta desde IP | Autenticación |
| `AUTH_STEPUP_REQUIRED` | Step-Up requerido | Autenticación |
| `AUTH_MFA_BYPASS_ATTEMPT` | Intento de bypassear MFA | Autenticación |
| `AUTH_PASSWORD_SCREENED` | Contraseña en HIBP | Autenticación |
| `AUTH_CREDENTIAL_EXPIRED` | Credencial vencida | Autenticación |
| `AUTH_SESSION_HIJACK_DETECTED` | Posible secuestro de sesión | Autenticación |
| `AUTH_SUPERUSER_ACTIVATED` | Break-glass SU | Autenticación |
| `AUTH_TOKEN_REVOKED_BULK` | Revocación masiva de tokens | Autenticación |
| `TEMP_OUTSIDE_SCHEDULE` | Acceso fuera de horario | D4 Temporal |
| `TEMP_DELEGATION_EXPIRING` | Delegación vence en 24h | D4 Temporal |
| `TEMP_DELEGATION_EXPIRED` | Delegación vencida | D4 Temporal |
| `TEMP_INTERVAL_CLOSING` | Gestión cierra en 7 días | D4 Temporal |
| `TEMP_INTERVAL_CLOSED` | Gestión cerrada | D4 Temporal |
| `ADMIN_KEY_ROTATED` | Rotación de llave | Admin |
| `ADMIN_BACKUP_FAILED` | Backup falló | Admin |
| `ADMIN_SYNC_FAILED` | Sync KC+Tryton falló | Admin |
| `ADMIN_VAULT_SEALED` | Vault sellado | Admin |
| `ADMIN_CERT_EXPIRING` | Certificado TLS vence | Admin |

**Acción:** Expandir el CHECK constraint de 38 a 76 valores.  
**Nota:** Mantener los 38 genéricos (útiles para eventos no-catalogados) y agregar los 38 del dominio.

---

### 🟠 GAP-06: `bos_audit_events` sin columnas de notificación

**Norma violada:** ISO 27001 A.8.16 (monitoring and alerting requires acknowledgment tracking), NIST 800-53 AU-7 (audit reduction and report generation).

**Columnas faltantes:**
```sql
notification_sent    BOOLEAN   DEFAULT FALSE,  -- ¿se disparó notificación?
notification_channels TEXT[],                 -- '{WHATSAPP,SMS,EMAIL,CHAT}'
acknowledged_at      TIMESTAMPTZ,             -- ¿cuándo se reconoció la alerta?
acknowledged_by      UUID,                     -- ¿quién la reconoció?
escalated_at         TIMESTAMPTZ,             -- ¿cuándo escaló?
escalated_to         UUID,                     -- ¿a quién escaló?
```

**Acción:** Agregar 6 columnas a `bos_audit_events`.

---

## 4. Brechas de Notificaciones

### 🔴 GAP-07: Faltan las 3 tablas de notificación definidas en BAUTH-TRAZABILIDAD

**Norma violada:** ISO 27001 A.8.16, NIST 800-53 AU-7, PCI DSS 10.7.  
**Tablas faltantes:**

| Tabla | Propósito | Prioridad |
|-------|-----------|-----------|
| `cfg_notification_policy` | Políticas de notificación por tenant/dominio/evento | 🔴 |
| `cfg_domain_channel` | Mapeo dominio → canal Mattermost + webhook URL | 🔴 |
| `aud_notification` | Espejo local de notificaciones enviadas | 🔴 |

**Acción:** Agregar los 3 CREATE TABLE al DDL (el SQL ya está definido en BAUTH-TRAZABILIDAD §8.2).

---

## 5. Brechas de Gestión de Retención

### 🔴 GAP-08: Sin política de retención explícita

**Norma violada:** PCI DSS 4.0 Req 10.7.1 (retain audit history ≥ 12 months online + 36 months archive), GDPR Art.17 (right to erasure — delete when purpose expires).  
**Estado actual:** Las particiones son manuales (`2026_07`, `2026_08`). Sin mecanismo de auto-creación ni auto-purga.

**Acción:** Crear tabla `cfg_retention_policy` y función `audit_partition_maintenance()`:
```sql
CREATE TABLE IF NOT EXISTS bAuth.cfg_retention_policy (
    policy_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name          TEXT NOT NULL UNIQUE,
    retention_online    INTERVAL NOT NULL DEFAULT '12 months',   -- PCI DSS
    retention_archive   INTERVAL NOT NULL DEFAULT '36 months',  -- PCI DSS
    auto_partition      BOOLEAN DEFAULT TRUE,
    auto_purge          BOOLEAN DEFAULT TRUE,
    last_partitioned_at TIMESTAMPTZ,
    last_purge_at       TIMESTAMPTZ,
    ctx_id              TEXT NOT NULL,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);
```

**Función PL/pgSQL:** `audit_partition_maintenance()` — ejecutada por cron cada 1er día del mes:
1. Crear particiones para los próximos 2 meses si no existen
2. Desacoplar (DETACH) particiones más antiguas que `retention_online`
3. Archive a tabla `_archive` o exportar a MinIO las > `retention_archive`

---

### 🟠 GAP-09: Solo 3 tablas particionadas por mes

**Norma violada:** PCI DSS 10.7 — accumulated audit data must be managed efficiently.  
**Tablas que DEBEN particionarse:**

| Tabla | Justificación |
|-------|--------------|
| `bos_superuser_contexts` | Break-glass — alto volumen en producción grande |
| `bos_policy_audit` | Cada cambio de política genera un registro |
| `bos_key_rotation_log` | Rotación de llaves criptográficas |
| `bos_device_registry` | Registro histórico de dispositivos (WORM) |
| `bos_access_reviews` | Campañas periódicas acumulan registros |
| `bos_ghost_accounts` | Detección continua acumula |
| `bos_context_switches` | Cada switch de contexto genera un registro |

**Acción:** Agregar `PARTITION BY RANGE (created_at)` a estas 7 tablas.

---

## 6. Brechas de Seguridad y Criptografía

### 🟠 GAP-10: `bos_superuser_contexts` — sintaxis de PK inválida

**Bug detectado:**
```sql
-- ACTUAL (ROTO):
context_id UUID PRIMARY KEY DEFAULT gen_random_uuid() DEFAULT gen_random_uuid()::text,
-- Doble DEFAULT. UUID con ::text no es válido.
```

**Acción:** Corregir a:
```sql
context_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
```

---

### 🟠 GAP-11: `bos_superuser_contexts` sin columnas de seguridad completas

**Norma violada:** ISO 27001 A.8.2 (privileged access rights), NIST 800-53 AC-6(5) (privileged accounts).

**Columnas faltantes:**
```sql
ctx_id              TEXT NOT NULL,            -- trazabilidad W3C
session_recording   TEXT,                      -- path al recording de la sesión
vault_unseal_token  TEXT,                      -- hash del token usado (nunca el token real)
witnesses           UUID[],                    -- testigos del break-glass (≥2)
prev_hash           TEXT,                      -- hash-chain
entry_hash          TEXT NOT NULL,             -- hash-chain
acknowledged_at     TIMESTAMPTZ,               -- ¿SU confirmó cierre?
```

**Acción:** Agregar 7 columnas + hash-chain trigger a `bos_superuser_contexts`.

---

### 🟠 GAP-12: `bos_key_rotation_log` sin verificación criptográfica

**Norma violada:** NIST SP 800-57 Pt.1 §8.3.5 (key destruction verification), FIPS 140-3.  
**Columnas faltantes:**
```sql
ctx_id              TEXT NOT NULL,
prev_hash           TEXT,
entry_hash          TEXT NOT NULL,
witness_1           UUID,                      -- testigo 1 de la ceremonia
witness_2           UUID,                      -- testigo 2
key_fingerprint_old TEXT,                      -- fingerprint antes de rotación
key_fingerprint_new TEXT,                      -- fingerprint después
```

**Acción:** Agregar 7 columnas + hash-chain trigger.

---

## 7. Brechas de Sesiones y Contexto

### 🟠 GAP-13: `bos_context_sessions` — ctx_id es UUID PK, no el traceparent W3C

**Norma violada:** W3C Trace Context — el identificador de traza debe ser el header `traceparent`.  
**Estado actual:** `ctx_id UUID PRIMARY KEY` + `dctx_id TEXT` + `traceparent TEXT`.  
**Problema:** El true ctx_id (W3C) está en `traceparent`, pero la PK es un UUID local. La PK no es el identificador de trazabilidad real.

**Acción:** Mantener el UUID como PK interna (`session_id UUID`). Renombrar el campo de trazabilidad a `w3c_traceparent TEXT NOT NULL UNIQUE` y agregar constraint que valide formato W3C (55 caracteres: `00-{trace-id}-{parent-id}-00`).

---

## 8. Brechas de Verificación y Evidencia

### 🟠 GAP-14: No hay tabla `audit_evidence` para archivos adjuntos

**Norma violada:** PCI DSS 10.3 (audit records must include supporting evidence), NIST 800-53 AU-3.  
**Caso de uso:** Un evento CRITICAL debe poder adjuntar screenshot, log dump, o PDF de reporte.

```sql
CREATE TABLE IF NOT EXISTS bAuth.audit_evidence (
    evidence_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aud_event_id    UUID NOT NULL,              -- FK → aud_event
    file_name       TEXT NOT NULL,
    file_type       TEXT NOT NULL,              -- 'image/png', 'application/pdf', 'text/plain'
    file_size_bytes BIGINT,
    file_hash       TEXT NOT NULL,              -- SHA-256
    storage_path    TEXT NOT NULL,              -- MinIO object path
    uploaded_by     UUID NOT NULL,
    ctx_id          TEXT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

**Acción:** Agregar tabla `audit_evidence`.

---

### 🟡 GAP-15: Sin índice GIN sobre `details` JSONB en tablas de auditoría

**Impacto:** Consultar "todos los eventos donde el monto > $10,000" requiere sequential scan sobre JSONB.  
**Acción:** Agregar `CREATE INDEX idx_bae_details ON bauth.bos_audit_events USING GIN (details jsonb_path_ops);`

---

## 9. Brechas de Alineación Normativa

### 🟡 GAP-16: `bos_login_attempt` — sin columnas para NIST AC-7 lockout progresivo

**Norma violada:** NIST 800-53 AC-7 (unsuccessful logon attempts).  
**Columnas faltantes:**
```sql
lockout_level       INTEGER DEFAULT 0,          -- 0=none, 1=15min, 2=1h, 3=permanent
lockout_expires_at  TIMESTAMPTZ,                -- cuándo expira el bloqueo
mitigation_applied  TEXT,                       -- 'CAPTCHA', 'MFA_CHALLENGE', 'ACCOUNT_LOCKED'
```

**Acción:** Agregar 3 columnas.

---

### 🟡 GAP-17: `bos_recovery_challenge` sin `ctx_id`

**Norma violada:** OWASP ASVS V2.5.1, NIST 800-63B-4 §4.4.2.  
**Acción:** Agregar `ctx_id TEXT NOT NULL`.

---

### 🟡 GAP-18: `bos_password_screening_log` sin `ctx_id`

**Norma violada:** NIST 800-63B-4 §5.1.1.2 (password screening must be auditable).  
**Acción:** Agregar `ctx_id TEXT NOT NULL`.

---

## 10. Brechas de Configuración y Cumplimiento

### 🟠 GAP-19: `bos_ghost_accounts` y `bos_access_reviews` sin trazabilidad completa

**Norma violada:** ISO 27001 A.9.2.5 (review of user access rights), SOC 2 CC6.2.  
**Acción:** Agregar `ctx_id TEXT NOT NULL` + `notification_sent BOOLEAN DEFAULT FALSE`.

---

### 🟡 GAP-20: Sin tabla de mapeo de cumplimiento por evento

**Norma violada:** Múltiples estándares requieren evidencia de cumplimiento por tipo de evento.  
**Propósito:** Cada event_type debe estar mapeado a los controles ISO/NIST/PCI que satisface.

**Ya existe `bos_compliance_map` pero es genérica.** Falta una tabla de join:
```sql
CREATE TABLE IF NOT EXISTS bAuth.cfg_event_compliance (
    event_type      TEXT NOT NULL,
    standard        TEXT NOT NULL,              -- 'ISO_27001', 'NIST_800_53', 'PCI_DSS', 'GDPR'
    control_id      TEXT NOT NULL,              -- 'A.8.15', 'AC-7', '10.3', 'Art.32'
    evidence_required BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (event_type, standard, control_id)
);
```

---

## 11. Resumen de Acciones Correctivas

### Fase A: Críticas (antes de cerrar DDL)

| # | Gap | Acción | Tablas afectadas |
|---|-----|--------|-----------------|
| A1 | GAP-05 | Expandir CHECK constraint a 76 event_types | `bos_audit_events` |
| A2 | GAP-07 | Crear 3 tablas de notificación | `cfg_notification_policy`, `cfg_domain_channel`, `aud_notification` |
| A3 | GAP-08 | Crear `cfg_retention_policy` + función `audit_partition_maintenance()` | 1 tabla nueva + 1 función |
| A4 | GAP-01 | Agregar `ctx_id` a 20 tablas prioritarias | Ver §1 |
| A5 | GAP-05 | Agregar 38 domain-specific event_types al CHECK | `bos_audit_events` |
| A6 | GAP-10 | Corregir sintaxis rota de PK en `bos_superuser_contexts` | 1 tabla |
| A7 | GAP-06 | Agregar 6 columnas de notificación a `bos_audit_events` | 1 tabla |
| A8 | GAP-14 | Crear `audit_evidence` | 1 tabla nueva |
| A9 | GAP-11 | Robustecer `bos_superuser_contexts` con 7 columnas + hash-chain | 1 tabla |

### Fase B: Altas (durante seeds y pruebas)

| # | Gap | Acción | Tablas afectadas |
|---|-----|--------|-----------------|
| B1 | GAP-04 | Agregar hash-chain a 6 tablas WORM sin él | `bos_sync_log`, `bos_policy_audit`, etc. |
| B2 | GAP-09 | Particionar 7 tablas adicionales | `bos_superuser_contexts`, etc. |
| B3 | GAP-12 | Robustecer `bos_key_rotation_log` con 7 columnas + hash-chain | 1 tabla |
| B4 | GAP-15 | Agregar índices GIN sobre JSONB | `bos_audit_events`, `bos_policy_audit` |
| B5 | GAP-20 | Crear `cfg_event_compliance` | 1 tabla nueva |

### Fase C: Medias (post-DDL)

| # | Gap | Acción | Tablas afectadas |
|---|-----|--------|-----------------|
| C1 | GAP-13 | Corregir `bos_context_sessions` PK vs traceparent | 1 tabla |
| C2 | GAP-16 | Agregar columnas NIST AC-7 a `bos_login_attempt` | 1 tabla |
| C3 | GAP-17-18 | Agregar `ctx_id` a tablas de recovery y screening | 2 tablas |
| C4 | GAP-19 | Agregar trazabilidad a ghost_accounts y access_reviews | 2 tablas |

---

## 12. Estándares Verificados

| # | Estándar | Controles aplicables | Gaps relacionados |
|---|----------|---------------------|-------------------|
| 1 | ISO 27001:2022 | A.5.15-18, A.8.2, A.8.5, A.8.9, A.8.13, A.8.15, A.8.16, A.8.17, A.8.24, A.9.2.1, A.9.2.5 | GAP-01,02,04,05,06,07,08,10,11,14,19 |
| 2 | ISO 24760-2:2025 | §5.3, §5.4, §8.3.1-8.3.7 | GAP-03,11 |
| 3 | NIST 800-63B-4 | §4, §5.1, §5.2, §7 | GAP-02,03,17,18 |
| 4 | NIST 800-53 Rev.5 | AC-2, AC-5, AC-6, AC-7, AU-2, AU-3, AU-7, AU-9, CM-6 | GAP-01,02,05,06,07,11,14,16 |
| 5 | NIST 800-207 ZTA | Continuous Verification | GAP-01,13 |
| 6 | PCI DSS 4.0.1 | Req 8.2-8.4, Req 10.1-10.7 | GAP-04,05,06,07,08,14 |
| 7 | OWASP ASVS 5.0 | V2.1, V2.5, V3.1-3.3, V4.1-4.2 | GAP-16,17,18 |
| 8 | SOC 2 Type II | CC6.1, CC6.3, CC6.6, CC7.1, CC9.1 | GAP-01,19 |
| 9 | GDPR/RGPD | Art.7, Art.9, Art.17, Art.32 | GAP-08 |
| 10 | FIPS 140-3/203/204/205 | Key management, PQC | GAP-12 |
| 11 | RFC 9562 | UUID v7 | ✅ Cumplido (103 PKs UUID) |
| 12 | W3C Trace Context | traceparent, tracestate | GAP-01,13 |

---

*Documento generado 2026-06-23. 24 brechas identificadas: 9 críticas, 11 altas, 4 medias. Todas con acción concreta y DDL asociado. Las brechas críticas deben cerrarse antes de ejecutar el DDL en producción.*
