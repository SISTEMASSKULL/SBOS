# GAPS DDL II — IAM Enterprise: Brechas de gobernanza y control

**Versión:** 2.1.0 · **Fecha:** 2026-07-21
**Origen:** evaluación de madurez IAM Enterprise contra 4 pilares (IGA · AM · PAM · NHI) + CAEP.
Investigación respaldada por: Gartner IGA Market Guide 2025, NIST SP 800-53 Rev.5,
Cloud Security Alliance NHI 2025, CyberArk/BeyondTrust ZSP, OpenID CAEP 1.0 Final (Sep 2025).

**Numeración:** continuación de `GAPS-DDL-PRIVILEGIOS.md` (G-01..G-12).

## Convenciones aplicadas (alineadas con A.65.02)

| Convención | Regla |
|---|---|
| **PK** | `uuid NOT NULL DEFAULT uuidv7()` — orden temporal nativo PG18, sin secuencias |
| **Schema** | `bauth.*` — tablas propias del daemon; prefijo determina la sección A.65.02 |
| **Prefijo de sección** | `aud_*` Auditoría · `ses_*` Sesión · `pam_*` PAM · `risk_*` Riesgo/ITDR · `idn_*` Identidad · `privilege_*` Privilegios |
| **ctx_id** | Obligatorio en toda tabla con operaciones auditables (SBOS-049) |
| **WORM** | Tablas de auditoría: REVOKE UPDATE/DELETE en `bauth_app_role`; trigger hash-chain |
| **Sin valores** | Toda referencia a Vault almacena RUTA, nunca el secreto |

---

## Tabla de resolución

| # | Gap | Sección A.65.02 | Tabla canónica | Prioridad | Estado |
|---|-----|-----------------|----------------|-----------|--------|
| G-13 | Campañas de certificación de acceso | AUDITORÍA | `bauth.aud_certification_campaign` + `aud_certification_review` | 🔴 BLOQUEANTE | 🔵 PENDIENTE POST-DDL |
| G-14 | Excepciones de acceso documentadas | PRIVILEGIOS | `bauth.privilege_exception_record` | 🟠 ALTA | ✅ DISEÑO APROBADO |
| G-15 | Política de riesgo adaptativo | RIESGO/ITDR | `bauth.ses_risk_policy` | 🟠 ALTA | 🔵 PENDIENTE POST-DDL |
| G-16 | Sesión persistente en PostgreSQL | SESIÓN | `bauth.ses_session_log` | 🟠 ALTA | ✅ DISEÑO APROBADO |
| G-17 | Solicitud JIT — workflow multi-nivel | PAM | `bauth.pam_jit_request` + `pam_jit_approval` | 🔴 BLOQUEANTE | 🔵 PENDIENTE POST-DDL |
| G-18 | Referencias de credenciales privilegiadas | PAM | `bauth.pam_credential_ref` | 🟠 ALTA | ✅ DISEÑO APROBADO |
| G-19 | Metadatos de sesión privilegiada | PAM | `bauth.pam_session_record` | 🟠 ALTA | ✅ DISEÑO APROBADO |
| G-20 | Ciclo de vida Break-glass | PAM | `bauth.pam_breakglass_activation` | 🔴 BLOQUEANTE | 🔵 PENDIENTE POST-DDL |
| G-21 | Tabla de Identidad No-Humana (NHI) | IDENTIDAD | `bauth.idn_roles_nhi_identity` | 🔴 BLOQUEANTE | 🔵 PENDIENTE POST-DDL |
| G-22 | Ciclo de vida NHI + certificación | IDENTIDAD | `bauth.idn_roles_nhi_lifecycle_event` + `idn_roles_nhi_certification` | 🟠 ALTA | ✅ DISEÑO APROBADO |
| G-23 | Referencias de secretos NHI | PAM | `bauth.pam_nhi_secret_ref` | 🟠 ALTA | ✅ DISEÑO APROBADO |
| G-24 | Agentes IA como identidades gobernadas | IDENTIDAD | `bauth.idn_roles_nhi_agent_identity` | 🟡 MEDIA | ✅ DISEÑO APROBADO |
| G-25 | Log de eventos CAEP entrantes | SESIÓN | `bauth.ses_caep_event_log` | 🟠 ALTA | ✅ DISEÑO APROBADO |
| G-26 | Configuración SSF Transmitter | SESIÓN | `bauth.ses_ssf_stream` + `ses_ssf_delivery_log` | 🟡 MEDIA | ✅ DISEÑO APROBADO |

---

## G-13 · Campañas de certificación de acceso ⚠️ EN TRABAJO

**Pilar:** IGA · **Prioridad:** 🔴 BLOQUEANTE · **Sección A.65.02:** AUDITORÍA

**Normativa:** NIST SP 800-53 Rev.5 AC-2(4) · ISO 27001:2022 A.5.18 / A.8.2 · PCI DSS 4.0 Req 7.2

**Problema resuelto:** sin estas tablas no existe evidencia auditable de que los accesos fueron
revisados. Un auditor ISO 27001 rechaza el cumplimiento de A.8.2 si no hay registro de quién
revisó qué acceso, qué decidió y cuándo. Las campañas también disparan revocaciones en T-170
cuando el revisor decide `REVOKE`.

---

### DDL

```sql
-- T-177 bauth.aud_certification_campaign — cabecera de campaña de certificación
-- Sección A.65.02: AUDITORÍA
-- WORM: INSERT only en producción; prohibido UPDATE/DELETE en bauth_app_role.
CREATE TABLE bauth.aud_certification_campaign (
    id              uuid        NOT NULL DEFAULT uuidv7(),
    tenant_id       uuid        NOT NULL REFERENCES bauth.idn_tenant(id),
    campaign_type   text        NOT NULL,
    scope_type      text        NOT NULL,
    scope_id        uuid        NULL,
    initiated_by    uuid        NOT NULL,
    description     text        NULL,
    due_date        timestamptz NOT NULL,
    started_at      timestamptz NOT NULL DEFAULT now(),
    closed_at       timestamptz NULL,
    status          text        NOT NULL DEFAULT 'ACTIVE',
    ctx_id          text        NOT NULL,
    CONSTRAINT aud_certification_campaign_pkey PRIMARY KEY (id),
    CONSTRAINT chk_acc_type CHECK (
        campaign_type IN ('QUARTERLY','ANNUAL','OFFBOARDING','INCIDENT','SOD_REVIEW')
    ),
    CONSTRAINT chk_acc_scope CHECK (
        scope_type IN ('TENANT','USER','ROLE','ATOM')
    ),
    CONSTRAINT chk_acc_status CHECK (
        status IN ('ACTIVE','COMPLETED','CANCELLED','OVERDUE')
    ),
    CONSTRAINT chk_acc_dates CHECK (
        closed_at IS NULL OR closed_at > started_at
    )
);

CREATE INDEX idx_acc_tenant_active
    ON bauth.aud_certification_campaign (tenant_id, status)
    WHERE status = 'ACTIVE';

-- T-178 bauth.aud_certification_review — decisión individual por grant
-- ES la evidencia auditable. Una fila por (campaña, grant).
CREATE TABLE bauth.aud_certification_review (
    id              uuid        NOT NULL DEFAULT uuidv7(),
    campaign_id     uuid        NOT NULL REFERENCES bauth.aud_certification_campaign(id),
    grant_id        uuid        NOT NULL REFERENCES bauth.privilege_atom_grant(id),
    reviewer_id     uuid        NOT NULL,
    reviewer_role   text        NOT NULL,
    decision        text        NOT NULL,
    justification   text        NULL,
    reviewed_at     timestamptz NOT NULL DEFAULT now(),
    revocation_at   timestamptz NULL,
    escalated_to    uuid        NULL,
    ctx_id          text        NOT NULL,
    CONSTRAINT aud_certification_review_pkey PRIMARY KEY (id),
    CONSTRAINT chk_acr_decision CHECK (
        decision IN ('CERTIFY','REVOKE','ESCALATE','DEFER')
    ),
    CONSTRAINT chk_acr_justification CHECK (
        decision NOT IN ('REVOKE','ESCALATE') OR justification IS NOT NULL
    )
);

CREATE INDEX idx_acr_campaign ON bauth.aud_certification_review (campaign_id);
CREATE INDEX idx_acr_reviewer ON bauth.aud_certification_review (reviewer_id, reviewed_at DESC);
```

### Propósito

`aud_certification_campaign` es la **cabecera** de cada proceso de revisión periódica de
accesos. Define el alcance (todo el tenant, un usuario específico, un rol, o un átomo) y la
ventana de tiempo (started_at → due_date). Es inmutable: una vez creada no se edita, solo
se cierra (`status='COMPLETED'`).

`aud_certification_review` es la **evidencia real** — una fila por cada grant que entró en
la campaña. El revisor registra su decisión y, si decide `REVOKE`, el sistema dispara la
revocación del grant en T-170 y registra `revocation_at`. Estas filas son las que el auditor
lee para confirmar cumplimiento.

### Frontend — cómo se maneja

**Módulo IGA → Campañas de Certificación:**

1. **Pantalla de administración de campañas:** tabla paginada de campañas activas con columnas: tipo, alcance, responsable, fecha límite, progreso (N revisiones / total grants). Botón "Nueva Campaña": formulario con `campaign_type` (desplegable), `scope_type` + `scope_id` (selector), `due_date`. Al guardar → INSERT en T-177. Botón "Cerrar Campaña" disponible cuando progreso = 100%.

2. **Pantalla de revisión (vista del manager/revisor):** lista de grants asignados a su revisión. Por cada fila: usuario, átomo (slug `dominio.bloque.atomo`), fecha de asignación del grant, último uso. Acciones: **Certificar** · **Revocar** (campo obligatorio `justification`) · **Escalar** (selecciona siguiente revisor). Al guardar → INSERT en T-178 + si REVOKE: UPDATE en T-170 `status='REVOKED'`.

3. **Dashboard IGA:** gráfico de progreso. Campañas vencidas (`due_date < now() AND status='ACTIVE'`) resaltadas en rojo.

### Cuándo y cómo se alimenta

| Tabla | Evento que dispara el INSERT | Quién escribe |
|-------|------------------------------|---------------|
| `aud_certification_campaign` | Admin abre campaña manual, o job cron trimestral | Frontend · job programado |
| `aud_certification_review` | Revisor toma decisión sobre un grant | Frontend Desktop |

**Job automático:** cada trimestre crea campaña `QUARTERLY` con `scope_type='TENANT'` para todos los tenants activos. Pobla T-178 con una fila por grant activo en T-170, `reviewer_id` = manager del usuario.

### Quién consulta estas tablas

- **Frontend bAuth Desktop** — módulo IGA: lista de campañas, bandeja del revisor, historial de decisiones.
- **Motor de revocación (daemon bAuth)** — cuando `decision='REVOKE'`, actualiza T-170.
- **Exportador SIEM/auditoría** — extrae T-178 como evidencia para informes ISO 27001.
- **Motor de offboarding** — al detectar baja de usuario, abre campaña `OFFBOARDING` automáticamente.

---

### Uso desde el frontend — métodos JSON-RPC

**Namespace:** `bauth.iga.*`

#### `bauth.iga.campaña.crear` — admin abre una campaña de revisión

```json
// REQUEST
{
  "jsonrpc": "2.0", "method": "bauth.iga.campaña.crear",
  "params": {
    "ctx_id": "...",
    "campaign_type": "QUARTERLY",
    "scope_type": "TENANT",
    "scope_id": null,
    "due_date": "2026-10-01T23:59:59Z",
    "description": "Revisión trimestral Q3 2026"
  }
}
// RESPONSE
{ "result": { "campaign_id": "019x-uuid-v7", "grants_incluidos": 847, "revisores_asignados": 23 } }
```

**Qué hace el daemon:**
1. INSERT en T-177 `status='ACTIVE'`.
2. `SELECT id, user_id FROM privilege_atom_grant WHERE tenant_id=$1 AND status='ACTIVE'`.
3. Por cada grant: INSERT en T-178 `decision=NULL`, `reviewer_id = idn_users.manager_id`.
4. Retorna conteo de grants incluidos y revisores únicos asignados.

---

#### `bauth.iga.revision.listar_bandeja` — revisor consulta sus decisiones pendientes

```json
// REQUEST
{ "method": "bauth.iga.revision.listar_bandeja",
  "params": { "ctx_id": "...", "reviewer_id": "uuid", "limit": 50, "offset": 0 } }

// RESPONSE
{ "result": { "pendientes": [
    { "review_id": "uuid", "campaign_type": "QUARTERLY",
      "due_date": "2026-10-01T23:59:59Z",
      "usuario": { "id": "uuid", "nombre": "Carlos Quispe" },
      "atomo": { "slug": "D3.facturacion.emitir_factura" },
      "grant_activo_desde": "2025-01-15T09:00:00Z",
      "ultimo_uso": "2026-07-18T14:32:00Z" }
  ], "total": 124 } }
```

**Query SQL (usa `idx_acr_reviewer`):**

```sql
SELECT r.id AS review_id, c.campaign_type, c.due_date,
       g.user_id, g.created_at AS grant_activo_desde, r.grant_id
FROM   bauth.aud_certification_review  r
JOIN   bauth.aud_certification_campaign c ON c.id = r.campaign_id
JOIN   bauth.privilege_atom_grant       g ON g.id = r.grant_id
WHERE  r.reviewer_id = $1
  AND  r.decision    IS NULL
  AND  c.status      = 'ACTIVE'
ORDER BY c.due_date ASC, r.id ASC
LIMIT $2 OFFSET $3;
```

---

#### `bauth.iga.revision.decidir` — revisor toma una decisión

```json
// REQUEST
{ "method": "bauth.iga.revision.decidir",
  "params": { "ctx_id": "...", "review_id": "uuid", "decision": "REVOKE",
    "justification": "Usuario cambió de área en febrero, acceso financiero ya no corresponde" } }

// RESPONSE — REVOKE
{ "result": { "decision": "REVOKE", "grant_revocado": true, "revocado_en": "2026-07-21T10:15:30Z" } }
// RESPONSE — CERTIFY
{ "result": { "decision": "CERTIFY" } }
// RESPONSE — ESCALATE
{ "result": { "decision": "ESCALATE", "escalado_a": "uuid-nuevo-revisor" } }
```

**Lógica del daemon — transacción atómica:**
```
1. Verificar review.reviewer_id == caller (no puede decidir revisiones ajenas)
2. Si decision IN ('REVOKE','ESCALATE'): verificar justification.len() >= 50
3. UPDATE aud_certification_review SET decision=$1, reviewed_at=now(), justification=$2
4. Si decision == 'REVOKE':
     UPDATE privilege_atom_grant SET status='REVOKED', updated_at=now() WHERE id=grant_id
     UPDATE aud_certification_review SET revocation_at=now() WHERE id=review_id
     INSERT en T-170b (audit WORM) del cambio de estado
5. Si decision == 'ESCALATE':
     UPDATE aud_certification_review SET escalated_to=uuid_nuevo_revisor
     → push notificación al nuevo revisor vía bnotify.push.enviar
6. Verificar campaña completa:
     SELECT COUNT(*) FROM aud_certification_review WHERE campaign_id=$1 AND decision IS NULL
     Si 0 → UPDATE aud_certification_campaign SET status='COMPLETED', closed_at=now()
```

---

#### `bauth.iga.campaña.progreso` — dashboard en tiempo real

```json
// RESPONSE
{ "result": { "total_grants": 847, "decididos": 623, "certificados": 610,
              "revocados": 13, "pendientes": 224, "porcentaje": 73.6,
              "dias_restantes": 72 } }
```

**Query SQL (usa `idx_acr_campaign`):**

```sql
SELECT
    COUNT(*)                                         AS total,
    COUNT(*) FILTER (WHERE decision IS NOT NULL)     AS decididos,
    COUNT(*) FILTER (WHERE decision = 'CERTIFY')     AS certificados,
    COUNT(*) FILTER (WHERE decision = 'REVOKE')      AS revocados,
    COUNT(*) FILTER (WHERE decision IS NULL)          AS pendientes
FROM bauth.aud_certification_review WHERE campaign_id = $1;
```

---

### Uso desde el código Rust — módulo y funciones

```
src/domain/iga.rs          ← lógica pura: validación, cierre de campaña
src/server/iga_handler.rs  ← dispatcher JSON-RPC
src/sync/iga_cron.rs       ← job trimestral + alertas de vencimiento
```

**Funciones en `domain/iga.rs`:**
- `fn validar_decision(decision: &str, justification: Option<&str>) → Result<(), BauthError>`
- `fn campaña_completada(pendientes: i64) → bool`

**Trigger SQL alternativo a lógica Rust** — la revocación puede ser atómica en la BD:

```sql
CREATE OR REPLACE FUNCTION fn_iga_revoke_on_decision() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.decision = 'REVOKE' THEN
        UPDATE bauth.privilege_atom_grant SET status='REVOKED', updated_at=now()
         WHERE id = NEW.grant_id;
        NEW.revocation_at := now();
    END IF;
    RETURN NEW;
END; $$;

CREATE TRIGGER trg_iga_revoke
    BEFORE INSERT ON bauth.aud_certification_review
    FOR EACH ROW EXECUTE FUNCTION fn_iga_revoke_on_decision();
```

**Job cron trimestral en `sync/iga_cron.rs`** — ejecuta el 1° de enero, abril, julio y octubre:

```sql
-- Paso 1: crear campaña por tenant activo
INSERT INTO bauth.aud_certification_campaign
    (tenant_id, campaign_type, scope_type, initiated_by, due_date, ctx_id)
SELECT id, 'QUARTERLY', 'TENANT', $su_id, now() + interval '30 days', $ctx
  FROM bauth.idn_tenant WHERE status = 'ACTIVE';

-- Paso 2: poblar revisiones — reviewer = manager del usuario del grant
INSERT INTO bauth.aud_certification_review (campaign_id, grant_id, reviewer_id, reviewer_role, ctx_id)
SELECT $campaign_id, g.id, u.manager_id, 'MANAGER', $ctx
  FROM bauth.privilege_atom_grant g
  JOIN bauth.idn_users u ON u.id = g.user_id
 WHERE g.tenant_id = $tenant_id AND g.status = 'ACTIVE';
```

---

### Implementación pendiente — trabajo requerido

El diseño DDL está completo. Lo que falta es la **lógica de negocio que actúa sobre estas tablas**:

| Ítem | Descripción | Prioridad |
|------|-------------|-----------|
| **Trigger revocación** | Al INSERT en `aud_certification_review` con `decision='REVOKE'`: ejecutar `UPDATE bauth.privilege_atom_grant SET status='REVOKED', updated_at=now() WHERE id = NEW.grant_id` y poblar `revocation_at`. Sin este trigger el REVOKE es solo texto — el grant sigue activo. | 🔴 BLOQUEANTE |
| **Job cron trimestral** | Job en el daemon que el 1° de cada trimestre: consulta tenants activos y crea `aud_certification_campaign` con `type='QUARTERLY'`; puebla `aud_certification_review` con una fila por grant activo en T-170; asigna `reviewer_id = idn_user.manager_id`. | 🟠 ALTA |
| **Job offboarding** | Al detectar baja de usuario (`idn_users.status` pasa a `INACTIVE`): abrir campaña `OFFBOARDING` con `scope_type='USER'`, `scope_id=user_id` y asignarla al manager. | 🟠 ALTA |
| **DDL aplicado** | Ejecutar el DDL de T-177 y T-178 en `bauth_db`. Verificar que las FK a `bauth.idn_tenant` y `bauth.privilege_atom_grant` resuelven correctamente. | 🔴 BLOQUEANTE |

---

## G-14 · Excepciones de acceso documentadas ✅ DISEÑO APROBADO

**Pilar:** IGA · **Prioridad:** 🟠 ALTA · **Sección A.65.02:** PRIVILEGIOS

**Normativa:** NIST SP 800-53 AC-2(7) · ISO 27001:2022 A.5.16 · SOX Section 404

**Relación con tablas existentes:** T-173 `privilege_override` controla la decisión runtime
del PDP (DENY→PERMIT). Esta tabla documenta el CONTEXTO de gobernanza detrás de ese override:
por qué fue aprobado, quién lo aprobó, cuándo vence y cuándo debe revisarse.

---

### DDL

```sql
-- T-179 bauth.privilege_exception_record — gobernanza de excepciones a políticas
-- Sección A.65.02: PRIVILEGIOS
-- Documenta el contexto de aprobación detrás de un override en T-173.
CREATE TABLE bauth.privilege_exception_record (
    id              uuid        NOT NULL DEFAULT uuidv7(),
    tenant_id       uuid        NOT NULL REFERENCES bauth.idn_tenant(id),
    override_id     uuid        NULL REFERENCES bauth.privilege_override(id),
    grant_id        uuid        NULL REFERENCES bauth.privilege_atom_grant(id),
    policy_violated text        NOT NULL,
    exception_type  text        NOT NULL,
    business_reason text        NOT NULL,
    approved_by     uuid        NOT NULL,
    approved_at     timestamptz NOT NULL DEFAULT now(),
    valid_until     timestamptz NOT NULL,
    review_at       timestamptz NOT NULL,
    status          text        NOT NULL DEFAULT 'ACTIVE',
    revoked_at      timestamptz NULL,
    revoked_by      uuid        NULL,
    ctx_id          text        NOT NULL,
    CONSTRAINT privilege_exception_record_pkey PRIMARY KEY (id),
    CONSTRAINT chk_per_type   CHECK (
        exception_type IN ('SOD_EXCEPTION','TIER_EXCEPTION','SCOPE_EXCEPTION','OTHER')
    ),
    CONSTRAINT chk_per_status CHECK (status IN ('ACTIVE','EXPIRED','REVOKED')),
    CONSTRAINT chk_per_dates  CHECK (
        valid_until > approved_at AND review_at <= valid_until
    ),
    CONSTRAINT chk_per_reason CHECK (length(business_reason) >= 50)
);

CREATE INDEX idx_per_tenant_active
    ON bauth.privilege_exception_record (tenant_id, valid_until)
    WHERE status = 'ACTIVE';
```

### Propósito

Registra **por qué** existe un override de política. Si un conflicto SoD fue aprobado como
excepción ("el mismo usuario puede crear y aprobar facturas durante el cierre de año porque
no hay otro recurso disponible"), esta tabla guarda esa justificación con propietario, fecha
de vencimiento y fecha de revisión intermedia.

Sin esta tabla los overrides en T-173 son decisiones runtime sin contexto histórico. Los
auditores ISO 27001 / SOX exigen que toda excepción sea documentada, aprobada por una autoridad
y tenga fecha de expiración. El mínimo de 50 caracteres en `business_reason` garantiza que
la justificación es real, no un texto vacío.

### Frontend — cómo se maneja

**Módulo IGA → Excepciones de Acceso:**

1. **Pantalla de excepciones activas:** tabla con política violada, tipo, usuario afectado, aprobador, vence en, estado. Badge rojo en excepciones que vencen en ≤ 7 días.

2. **Formulario de nueva excepción:** se activa cuando el trigger SoD rechaza un grant y el admin opta por "Aprobar como excepción". Campos: `policy_violated` (autocompletado del error SoD), `exception_type` (desplegable), `business_reason` (textarea, contador de caracteres visible, mínimo 50), `valid_until` (date picker; máximo configurable en `idn_tenant_config`), `review_at`.

3. **Pantalla de revisión de excepciones:** lista de excepciones donde `review_at <= now() + 7 days`. El revisor puede extender, revocar, o dejar vencer.

### Cuándo y cómo se alimenta

| Evento | Operación |
|--------|-----------|
| Admin aprueba grant que viola SoD (trigger rechaza → admin escala a excepción) | INSERT |
| Job nocturno | UPDATE `status='EXPIRED'` en excepciones con `valid_until < now()` |
| Admin revoca manualmente | UPDATE `status='REVOKED'`, `revoked_at`, `revoked_by` |

### Quién consulta esta tabla

- **Trigger SoD en T-170** — antes de rechazar un INSERT por SoD, verifica si existe excepción activa para ese par (usuario, átomo). Si existe → permite el grant.
- **Frontend bAuth Desktop** — módulo IGA: lista de excepciones y alertas de vencimiento.
- **Job de expiración** — diario, marca `status='EXPIRED'` y revoca el override asociado en T-173.

---

## G-15 · Política de riesgo adaptativo ⚠️ EN TRABAJO

**Pilar:** AM · **Prioridad:** 🟠 ALTA · **Sección A.65.02:** RIESGO/ITDR

**Normativa:** NIST SP 800-207 §3.3 · NIST SP 800-53 AC-25 · CAEP 1.0 §5

---

### DDL

```sql
-- T-180 bauth.ses_risk_policy — reglas de política de riesgo adaptativo por tenant
-- Sección A.65.02: RIESGO/ITDR
-- El PDP consulta esta tabla al recibir un evento CAEP para decidir qué acción tomar.
CREATE TABLE bauth.ses_risk_policy (
    id              uuid        NOT NULL DEFAULT uuidv7(),
    tenant_id       uuid        NOT NULL REFERENCES bauth.idn_tenant(id),
    tier_id         text        NULL,
    trigger_event   text        NOT NULL,
    condition       jsonb       NOT NULL,
    action          text        NOT NULL,
    required_loa    text        NULL,
    priority        int         NOT NULL DEFAULT 100,
    is_active       boolean     NOT NULL DEFAULT true,
    created_by      uuid        NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    ctx_id          text        NOT NULL,
    CONSTRAINT ses_risk_policy_pkey PRIMARY KEY (id),
    CONSTRAINT chk_rp_event CHECK (
        trigger_event IN (
            'session-revoked','token-claims-change','credential-change',
            'assurance-level-change','device-compliance-change','risk-level-change'
        )
    ),
    CONSTRAINT chk_rp_action CHECK (
        action IN ('STEP_UP','REVOKE','SUSPEND','NOTIFY','REQUIRE_MFA')
    ),
    CONSTRAINT chk_rp_loa CHECK (
        (action = 'STEP_UP' AND required_loa IS NOT NULL)
        OR action <> 'STEP_UP'
    )
);

CREATE INDEX idx_rp_tenant_event
    ON bauth.ses_risk_policy (tenant_id, trigger_event, priority)
    WHERE is_active = true;
```

### Propósito

Define **qué hace el sistema** cuando llega un evento CAEP específico. Sin esta tabla, las
reglas de riesgo adaptativo viven hardcodeadas en el daemon o en archivos TOML no auditables.
Con esta tabla, un administrador de seguridad cambia la política sin recompilar el daemon.

El campo `condition` es un JSONB que el PDP evalúa contra el payload del evento CAEP. Ejemplo:
`{"risk_score": {"gte": 70}}`. El campo `priority` define el orden de evaluación (menor número
= mayor prioridad; se aplica la primera regla que coincide con la condición).

### Frontend — cómo se maneja

**Módulo Seguridad → Políticas de Riesgo:**

1. **Tabla de políticas:** columnas: evento, tier aplicable (vacío = todos), condición (resumen legible), acción, prioridad. Toggle para activar/desactivar sin eliminar.

2. **Formulario de política:** `trigger_event` (desplegable de 6 tipos), `tier_id` (selector opcional), `condition` (editor JSON con validación de schema — hints con ejemplos), `action` (desplegable), `required_loa` (visible solo si `action=STEP_UP`), `priority` (numérico).

3. **Simulador:** el admin pega un payload CAEP de ejemplo y ve qué política se dispararía y en qué orden.

### Cuándo y cómo se alimenta

| Evento | Operación |
|--------|-----------|
| Admin define o modifica una regla | INSERT / UPDATE |
| Bootstrap del tenant | INSERT de políticas por defecto según tier (seed) |

**Seed por defecto para tier BIZ_N1+:**
- `risk-level-change` + `risk_score >= 85` → REVOKE (priority 10)
- `risk-level-change` + `risk_score >= 70` → STEP_UP AAL2 (priority 20)
- `device-compliance-change` + `compliant=false` → SUSPEND (priority 10)

### Quién consulta esta tabla

- **PDP del daemon bAuth** — al procesar cada evento CAEP, evalúa esta tabla. Es el consumidor principal.
- **Frontend bAuth Desktop** — módulo de políticas de riesgo.

---

### Uso desde el frontend — métodos JSON-RPC

**Namespace:** `bauth.risk.*`

#### `bauth.risk.policy.listar` — admin consulta reglas del tenant

```json
// REQUEST
{ "method": "bauth.risk.policy.listar",
  "params": { "ctx_id": "...", "tenant_id": "uuid", "solo_activas": true } }

// RESPONSE
{ "result": { "policies": [
    { "id": "uuid", "trigger_event": "risk-level-change",
      "condition": { "risk_score": { "gte": 85 } },
      "action": "REVOKE", "priority": 10, "activo": true },
    { "id": "uuid", "trigger_event": "risk-level-change",
      "condition": { "risk_score": { "gte": 70 } },
      "action": "STEP_UP", "required_loa": "AAL2", "priority": 20, "activo": true },
    { "id": "uuid", "trigger_event": "device-compliance-change",
      "condition": { "compliant": false },
      "action": "SUSPEND", "priority": 10, "activo": true }
  ] } }
```

---

#### `bauth.risk.policy.crear` — admin define una nueva regla

```json
// REQUEST
{ "method": "bauth.risk.policy.crear",
  "params": {
    "ctx_id": "...",
    "trigger_event": "risk-level-change",
    "tier_id": "BIZ_N4",
    "condition": { "risk_score": { "gte": 60 } },
    "action": "REQUIRE_MFA",
    "required_loa": null,
    "priority": 30
  } }

// RESPONSE — éxito
{ "result": { "policy_id": "019x-uuid-v7" } }

// RESPONSE — error: tier_id inválido
{ "error": { "code": -32002, "message": "tier_id 'BIZ_N4' no existe en idn_roles_rol_tier" } }
```

---

#### `bauth.risk.policy.simular` — admin prueba qué política dispararía un evento

```json
// REQUEST — admin pega un payload CAEP de prueba y ve cuál regla ganaría
{ "method": "bauth.risk.policy.simular",
  "params": {
    "ctx_id": "...",
    "tenant_id": "uuid",
    "event_type": "risk-level-change",
    "payload": { "risk_score": 75, "reason": "unusual_location" }
  } }

// RESPONSE
{ "result": {
    "regla_aplicada": {
      "id": "uuid", "priority": 20, "action": "STEP_UP", "required_loa": "AAL2"
    },
    "reglas_evaluadas": 3,
    "reglas_que_no_coincidieron": [
      { "id": "uuid", "priority": 10, "motivo": "risk_score 75 < umbral 85" }
    ]
  } }
```

**Qué hace el daemon:** ejecuta el mismo evaluador interno `evaluar_riesgo_adaptativo`
pero en modo simulación — sin aplicar ninguna acción, solo retorna el resultado del match.

---

### Uso interno del PDP — no expuesto como RPC externo

El PDP llama a esta función internamente cada vez que llega un evento CAEP al receiver:

```
fn evaluar_riesgo_adaptativo(
    tenant_id: Uuid,
    event_type: &str,
    payload: &serde_json::Value
) → Result<RiskAction, BauthError>
```

**Query SQL que ejecuta el evaluador (usa `idx_rp_tenant_event`):**

```sql
SELECT id, action, condition, required_loa
FROM   bauth.ses_risk_policy
WHERE  tenant_id     = $1
  AND  trigger_event = $2
  AND  activo        = true
  AND  (tier_id IS NULL OR tier_id = $3)   -- $3 = tier del sujeto del evento
ORDER BY priority ASC;                      -- primera regla que coincide gana
```

**Evaluación de `condition` JSONB en Rust:**

```
Para cada política en orden de prioridad:
  ¿policy.condition coincide con payload?
    → evaluar_condicion_jsonb(&policy.condition, &payload)
    → Si coincide: retornar RiskAction { action, required_loa }
    → Si no: continuar con siguiente política
Si ninguna coincide: retornar RiskAction::Allow
```

**Semántica de `evaluar_condicion_jsonb`** — operadores soportados en `condition`:

| Operador | Ejemplo | Significado |
|----------|---------|-------------|
| `gte` | `{"risk_score": {"gte": 70}}` | campo ≥ valor |
| `lte` | `{"risk_score": {"lte": 30}}` | campo ≤ valor |
| `eq`  | `{"compliant": false}` | campo == valor |
| `in`  | `{"reason": {"in": ["stolen_creds","brute_force"]}}` | campo está en lista |

---

### Uso desde el código Rust — módulo y funciones

```
src/domain/risk.rs           ← lógica pura: evaluador de condición JSONB, match de políticas
src/server/risk_handler.rs   ← dispatcher JSON-RPC: CRUD + simulador
src/domain/pdp.rs            ← integración: llama a domain/risk.rs al procesar evento CAEP
```

**Flujo completo desde evento CAEP hasta acción:**

```
[Receptor CAEP recibe evento]
  → INSERT ses_caep_event_log (status='RECEIVED')
  → pdp.procesar_evento_caep(event_type, subject_id, payload)
      → risk::evaluar_riesgo_adaptativo(tenant_id, event_type, payload)
          → SQL: SELECT policies ORDER BY priority
          → evaluar_condicion_jsonb por cada policy
          → retorna RiskAction
      → match RiskAction:
          REVOKE       → UPDATE ses_session_log SET termination_reason='CAEP_REVOKE'
                         UPDATE privilege_atom_grant SET status='SUSPENDED' WHERE user_id=subject
          STEP_UP      → emitir desafío step-up RFC 9470 al cliente
          SUSPEND      → UPDATE ses_session_log SET terminated_at=now()
          REQUIRE_MFA  → flag en sesión Redis: requiere reautenticación
          NOTIFY       → bnotify.push.enviar al propietario del sujeto
          Allow        → no hacer nada
  → UPDATE ses_caep_event_log SET status='APPLIED', grants_affected=[...]
```

---

### Implementación pendiente — trabajo requerido

El diseño DDL está completo. Lo que falta es el **motor Rust en el PDP que evalúa estas reglas**:

| Ítem | Descripción | Prioridad |
|------|-------------|-----------|
| **Evaluador PDP en Rust** | Función `evaluate_ses_risk_policy(event_type, payload_json, tenant_id) → RiskAction` que: carga las reglas activas del tenant ordenadas por `priority ASC`; itera hasta encontrar la primera cuyo `condition` JSONB coincide con el payload del evento; retorna la acción (`STEP_UP`, `REVOKE`, `SUSPEND`, `NOTIFY`, `REQUIRE_MFA`). Si ninguna regla coincide: retorna `ALLOW`. | 🔴 BLOQUEANTE |
| **Evaluador JSONB de condiciones** | El campo `condition` es JSONB libre (ej. `{"risk_score": {"gte": 70}}`). Necesita un evaluador genérico de expresiones sobre un JSON payload. Opciones: (a) evaluar directamente en PG18 con JSONB operators; (b) mini-DSL en Rust. Decisión de diseño pendiente. | 🟠 ALTA |
| **Seed de políticas por defecto** | Al crear tenant, insertar las 3 reglas por defecto documentadas (REVOKE en score≥85, STEP_UP en score≥70, SUSPEND en device incompliant). Sin seed el tenant queda sin protección adaptativa desde el día 1. | 🟠 ALTA |
| **DDL aplicado** | Ejecutar DDL de T-180 en `bauth_db`. | 🔴 BLOQUEANTE |

---

## G-16 · Sesión persistente en PostgreSQL ✅ DISEÑO APROBADO

**Pilar:** AM · **Prioridad:** 🟠 ALTA · **Sección A.65.02:** SESIÓN

**Normativa:** NIST SP 800-53 AU-12 · ISO 27001:2022 A.8.15 · PCI DSS 4.0 Req 10.2.1

**Nota:** Redis es el store de sesión activa (sub-milisegundo). Esta tabla es el **esqueleto
mínimo persistente** en PostgreSQL para forensia. No duplica Redis — lo complementa con
persistencia histórica que sobrevive a reinicios y failovers.

---

### DDL

```sql
-- T-181 bauth.ses_session_log — esqueleto persistente de sesión
-- Sección A.65.02: SESIÓN
-- No almacena estado de sesión activa (eso es Redis). Almacena el historial mínimo
-- para forensia post-incidente y cumplimiento normativo.
-- Particionamiento por mes recomendado a mediano plazo (RANGE ON started_at).
CREATE TABLE bauth.ses_session_log (
    session_id          uuid        NOT NULL DEFAULT uuidv7(),
    tenant_id           uuid        NOT NULL REFERENCES bauth.idn_tenant(id),
    user_id             uuid        NOT NULL,
    auth_method         text        NOT NULL,
    loa_initial         text        NOT NULL,
    loa_peak            text        NOT NULL,
    ip_address          inet        NULL,
    user_agent          text        NULL,
    started_at          timestamptz NOT NULL DEFAULT now(),
    last_active_at      timestamptz NOT NULL DEFAULT now(),
    terminated_at       timestamptz NULL,
    termination_reason  text        NULL,
    ctx_id              text        NOT NULL,
    CONSTRAINT ses_session_log_pkey PRIMARY KEY (session_id),
    CONSTRAINT chk_ssl_loa_i  CHECK (loa_initial IN ('AAL1','AAL2','AAL3')),
    CONSTRAINT chk_ssl_loa_p  CHECK (loa_peak    IN ('AAL1','AAL2','AAL3')),
    CONSTRAINT chk_ssl_reason CHECK (
        termination_reason IS NULL
        OR termination_reason IN ('LOGOUT','TIMEOUT','CAEP_REVOKE','ADMIN_REVOKE','EXPIRY')
    )
);

CREATE INDEX idx_ssl_user_tenant ON bauth.ses_session_log (user_id, tenant_id, started_at DESC);
CREATE INDEX idx_ssl_active      ON bauth.ses_session_log (tenant_id, last_active_at)
    WHERE terminated_at IS NULL;
```

### Propósito

Responde preguntas de forensia que Redis no puede responder después de un reinicio: "¿El
usuario X tuvo sesión abierta el martes a las 03:00?", "¿cuántas sesiones AAL1 tuvo este
tenant el último mes?".

`loa_peak` captura el LoA máximo de la sesión: una sesión puede iniciar en AAL1 y escalar
a AAL2 por step-up — `loa_initial` = nivel de entrada, `loa_peak` = máximo visto.

`termination_reason='CAEP_REVOKE'` lo escribe el daemon cuando el CAEP receiver procesa un
evento `session-revoked` — conecta la forensia de sesión con el log CAEP de G-25.

### Frontend — cómo se maneja

**Módulo Auditoría → Sesiones:**

1. **Historial de sesiones:** filtros por usuario, tenant, período, LoA, método auth, motivo de cierre. Exportable a CSV.
2. **Detalle de sesión:** timeline de inicio, step-ups (consultando T-176), cierre y motivo. Enlace a sesión PAM asociada (T-184) si existió.
3. **Alertas:** sesiones con IP fuera del rango del tenant resaltadas. `termination_reason='CAEP_REVOKE'` marcadas para revisión.
4. **Solo lectura desde el frontend** — no hay formulario de creación.

### Cuándo y cómo se alimenta

| Evento | Operación | Actor |
|--------|-----------|-------|
| Usuario completa autenticación exitosa | INSERT | Daemon bAuth |
| Sesión escala LoA por step-up | UPDATE `loa_peak` | Daemon bAuth |
| Usuario hace logout | UPDATE `terminated_at`, `termination_reason='LOGOUT'` | Daemon bAuth |
| Sesión expira por TTL en Redis | UPDATE `termination_reason='TIMEOUT'` | Job de limpieza |
| CAEP receiver revoca sesión | UPDATE `termination_reason='CAEP_REVOKE'` | Daemon bAuth |

### Quién consulta esta tabla

- **Frontend bAuth Desktop** — módulo auditoría/sesiones.
- **Motor de forensia** — búsqueda post-incidente por tiempo, IP, usuario.
- **Exportador SIEM** — extrae sesiones revocadas por CAEP para Wazuh.
- **Job de retención** — archiva filas con `terminated_at < now() - interval '10 years'` (Ley 843).

---

## G-17 · Solicitud JIT — workflow completo ⚠️ EN TRABAJO

**Pilar:** PAM · **Prioridad:** 🔴 BLOQUEANTE · **Sección A.65.02:** PAM

**Normativa:** NIST SP 800-53 AC-6(9) · ISO 27001:2022 A.5.18 · PCI DSS 4.0 Req 7.2.6

**Por qué es funcional:** sin esta tabla el daemon no puede implementar Zero Standing Privilege.
Los administradores tienen privilegios permanentes porque no existe el workflow solicitud →
aprobación → activación temporal → expiración automática. Esta tabla es el motor del ZSP.

---

### DDL

```sql
-- T-182 bauth.pam_jit_request — solicitud de acceso temporal privilegiado
-- Sección A.65.02: PAM
-- WORM por diseño: INSERT only en producción.
-- Decisión 2026-07-21: aprobación multi-nivel secuencial vía T-182b (pam_jit_approval).
-- approver_id eliminado — la aprobación vive íntegramente en T-182b.
CREATE TABLE bauth.pam_jit_request (
    id                  uuid        NOT NULL DEFAULT uuidv7(),
    tenant_id           uuid        NOT NULL REFERENCES bauth.idn_tenant(id),
    requester_id        uuid        NOT NULL,
    target_role_id      uuid        NOT NULL,
    target_atoms        uuid[]      NULL,
    justification       text        NOT NULL,
    requested_duration  interval    NOT NULL,
    max_duration        interval    NOT NULL,
    niveles_requeridos  int         NOT NULL DEFAULT 1,
    requested_at        timestamptz NOT NULL DEFAULT now(),
    status              text        NOT NULL DEFAULT 'PENDING',
    rejection_reason    text        NULL,
    grant_id            uuid        NULL REFERENCES bauth.privilege_atom_grant(id),
    activated_at        timestamptz NULL,
    valid_from          timestamptz NULL,
    valid_until         timestamptz NULL,
    expired_at          timestamptz NULL,
    revoked_at          timestamptz NULL,
    revoked_by          uuid        NULL,
    ctx_id              text        NOT NULL,
    CONSTRAINT pam_jit_request_pkey  PRIMARY KEY (id),
    CONSTRAINT chk_pjr_status CHECK (
        status IN ('PENDING','APPROVED','REJECTED','ACTIVE','EXPIRED','REVOKED')
    ),
    CONSTRAINT chk_pjr_duration      CHECK (requested_duration <= max_duration),
    CONSTRAINT chk_pjr_justification CHECK (length(justification) >= 50),
    CONSTRAINT chk_pjr_niveles       CHECK (niveles_requeridos BETWEEN 1 AND 5)
);

CREATE INDEX idx_pjr_tenant_status
    ON bauth.pam_jit_request (tenant_id, status, requested_at DESC);
CREATE INDEX idx_pjr_active_expiry
    ON bauth.pam_jit_request (valid_until)
    WHERE status = 'ACTIVE';

-- T-182b bauth.pam_jit_approval — nivel de aprobación secuencial por solicitud JIT
-- Sección A.65.02: PAM
-- Una fila por nivel. El daemon notifica al Nivel N+1 solo cuando Nivel N aprueba.
-- Si cualquier nivel rechaza → la solicitud queda REJECTED; niveles superiores no son notificados.
-- Permite 1, 2 o N aprobaciones sin cambiar el DDL — solo se agrega una fila de nivel.
CREATE TABLE bauth.pam_jit_approval (
    id              uuid        NOT NULL DEFAULT uuidv7(),
    request_id      uuid        NOT NULL REFERENCES bauth.pam_jit_request(id),
    nivel           int         NOT NULL,
    required_role   text        NOT NULL,
    approver_id     uuid        NULL,
    decision        text        NULL,
    notified_at     timestamptz NULL,
    decision_at     timestamptz NULL,
    notes           text        NULL,
    ctx_id          text        NOT NULL,
    CONSTRAINT pam_jit_approval_pkey    PRIMARY KEY (id),
    CONSTRAINT uq_pja_request_nivel     UNIQUE (request_id, nivel),
    CONSTRAINT chk_pja_decision CHECK (
        decision IS NULL OR decision IN ('APPROVED','REJECTED')
    ),
    CONSTRAINT chk_pja_nivel CHECK (nivel BETWEEN 1 AND 5)
);

CREATE INDEX idx_pja_pending
    ON bauth.pam_jit_approval (request_id, nivel)
    WHERE decision IS NULL;
CREATE INDEX idx_pja_approver_pending
    ON bauth.pam_jit_approval (approver_id, notified_at)
    WHERE decision IS NULL AND notified_at IS NOT NULL;
```

### Estados del workflow con escalamiento

```
                    Nivel 1 aprueba
PENDING ──────────────────────────────► Nivel 2 notificado
                                              │
                    Nivel 2 aprueba           │
                    ─────────────────────────►│
                                              ▼
                                         APPROVED ──► ACTIVE ──► EXPIRED (job 60s)
                                                                      │
PENDING ──► Nivel 1 rechaza ──► REJECTED                         REVOKED (manual)
PENDING ──► Nivel 1 aprueba ──► Nivel 2 rechaza ──► REJECTED
ACTIVE  ──────────────────────────────────────────────────────► REVOKED (admin)
```

**Regla de activación:** `status='APPROVED'` solo cuando todos los niveles (1..N) tienen `decision='APPROVED'`.
**Regla de rechazo:** cualquier nivel con `decision='REJECTED'` → la solicitud pasa a `REJECTED` inmediatamente.

### Propósito

Implementa el principio **Zero Standing Privilege**: ningún administrador tiene acceso
privilegiado permanente. Para ejercer un privilegio elevado (tier SYS, átomos D10 admin,
acceso financiero D3), el usuario envía una solicitud JIT con justificación mínima de 50
chars, espera aprobación **de todos los niveles requeridos**, y accede solo durante la
ventana `valid_from → valid_until`. El grant en T-170 expira automáticamente.

**Aprobación secuencial multi-nivel (decisión 2026-07-21):** cada tier define cuántos
niveles de aprobación requiere y qué rol puede aprobar cada nivel. El aprobador del Nivel 2
solo es notificado cuando el Nivel 1 ya aprobó — ningún escalamiento innecesario al nivel
superior. Si cualquier nivel rechaza, la cadena se corta ahí.

| Tier del acceso solicitado | Niveles | Nivel 1 | Nivel 2 |
|---------------------------|---------|---------|---------|
| BIZ_N4/N5 en D3 (financiero) | 2 | Gerente directo | CFO |
| SYS (administración de servidor) | 2 | Gerente IT | CISO |
| SU (superusuario) | 2 | CISO | Director ejecutivo |
| Break-glass (EMERGENCY) | 1 | Cualquier senior | Revisión post-facto 24h |

`max_duration` viene del tier del rol solicitado (leído de `idn_roles_rol_tier`). El CHECK
constraint impide pedir más duración de la que permite el tier.

### Frontend — cómo se maneja

**Módulo PAM → Acceso JIT:**

1. **Formulario de solicitud (vista del usuario):** selector del rol privilegiado, selector
   opcional de átomos específicos (`target_atoms`), campo `justification` (contador de
   caracteres, mínimo 50), selector de duración con slider (techo = `max_duration` del tier).
   El sistema muestra quiénes deberán aprobar (niveles 1 y 2) antes de enviar.
   Al enviar → INSERT en T-182 `status='PENDING'` + INSERT en T-182b niveles según tier
   + notificación push al Nivel 1.

2. **Bandeja de aprobación (vista del aprobador de Nivel 1):** lista de solicitudes con su
   nivel activo. Muestra: solicitante, rol pedido, duración, justificación, tiempo en espera.
   Botones: **Aprobar** (campo `notes` opcional) · **Rechazar** (campo `rejection_reason`
   obligatorio). Al aprobar → UPDATE T-182b `decision='APPROVED'` + si hay Nivel 2:
   UPDATE T-182b Nivel 2 `notified_at=now()` + notificación push al Nivel 2.
   Al rechazar → UPDATE T-182b `decision='REJECTED'` + UPDATE T-182 `status='REJECTED'`.

3. **Bandeja Nivel 2 (CISO / CFO / Director):** idéntica a la del Nivel 1 pero solo recibe
   solicitudes que ya fueron aprobadas por el Nivel 1. Badge "Aprobado por [Nombre] (Nivel 1)"
   visible para contexto. Al aprobar en el último nivel → daemon activa el grant en T-170.

4. **Historial JIT del usuario:** lista de solicitudes históricas con estado, tiempos y
   cadena de aprobaciones (quién aprobó en cada nivel y cuándo).

5. **Dashboard PAM (admin):** solicitudes activas con cuenta regresiva hasta `valid_until`.
   Solicitudes PENDING por nivel con tiempo en espera — alertas si llevan > 30 min sin atender.

### Cuándo y cómo se alimenta

| Evento | Operación | Tabla | Actor |
|--------|-----------|-------|-------|
| Usuario envía solicitud | INSERT `status='PENDING'`, `niveles_requeridos=N` | T-182 | Frontend Desktop |
| Sistema crea niveles de aprobación | INSERT N filas (nivel 1..N), solo `notified_at` del nivel 1 | T-182b | Daemon bAuth |
| Aprobador Nivel 1 decide | UPDATE T-182b nivel 1 `decision`, `approver_id`, `decision_at` | T-182b | Frontend Desktop |
| Nivel 1 aprueba → notificar Nivel 2 | UPDATE T-182b nivel 2 `notified_at=now()` | T-182b | Daemon bAuth |
| Último nivel aprueba → activar | UPDATE T-182 `status='APPROVED'`; INSERT T-170 con TTL; UPDATE T-182 `status='ACTIVE'`, `grant_id`, `activated_at` | T-182 + T-170 | Daemon bAuth |
| Cualquier nivel rechaza | UPDATE T-182b `decision='REJECTED'`; UPDATE T-182 `status='REJECTED'` | T-182b + T-182 | Daemon bAuth |
| Job detecta `valid_until < now()` | UPDATE T-182 `status='EXPIRED'`; UPDATE T-170 `status='EXPIRED'` | T-182 + T-170 | Job del daemon |
| Admin revoca manualmente | UPDATE T-182 `status='REVOKED'`, `revoked_at`, `revoked_by` | T-182 | Frontend Desktop |

### Quién consulta estas tablas

- **Daemon bAuth** — motor de escalamiento: lee T-182b para saber si todos los niveles aprobaron y activa el grant en T-170.
- **Job de expiración** — revisa cada minuto los JIT `status='ACTIVE'` con `valid_until < now()`.
- **Frontend bAuth Desktop** — bandeja por nivel, historial del usuario, dashboard PAM.
- **PDP** — verifica que un grant de tier elevado tenga un JIT activo antes de evaluar PERMIT.

---

### Uso desde el frontend — métodos JSON-RPC

El frontend nunca toca PostgreSQL directamente. Todo pasa por el daemon vía JSON-RPC 2.0
sobre `/run/bos/bauth.sock`. Los métodos del namespace `bauth.jit.*`:

#### `bauth.jit.solicitar` — el usuario envía una solicitud

```json
// REQUEST
{
  "jsonrpc": "2.0",
  "method": "bauth.jit.solicitar",
  "params": {
    "ctx_id": "tenant.org.pos.actor.op.trace",
    "target_role_id": "uuid-del-rol-privilegiado",
    "target_atoms": ["uuid-atomo-1", "uuid-atomo-2"],  // opcional
    "justification": "Baja del empleado Pedro Mamani, ref. RR.HH. #847",
    "requested_duration_minutes": 120
  },
  "id": 1
}

// RESPONSE — éxito
{
  "result": {
    "request_id": "019x-uuid-v7",
    "status": "PENDING",
    "niveles_requeridos": 2,
    "aprobadores": [
      { "nivel": 1, "required_role": "GERENTE_IT", "notificado": true },
      { "nivel": 2, "required_role": "CISO",       "notificado": false }
    ],
    "max_duration_minutes": 240,
    "valid_until_estimado": "2026-07-21T14:00:00Z"
  }
}

// RESPONSE — error: duración excede el tier
{
  "error": {
    "code": -32001,
    "message": "Duración solicitada (480 min) excede el máximo permitido para tier SYS (240 min)"
  }
}
```

**Qué hace el daemon al recibir esta llamada:**
1. Lee `idn_roles_rol_tier` para obtener `max_duration` y `niveles_requeridos` del tier del rol.
2. Valida `requested_duration <= max_duration`.
3. INSERT en T-182 (`status='PENDING'`, `niveles_requeridos`).
4. INSERT en T-182b: una fila por nivel (1..N), solo nivel 1 con `notified_at=now()`.
5. Llama a `bnotify.push.enviar` con el UUID del aprobador de nivel 1.
6. Retorna la respuesta con el preview de aprobadores.

---

#### `bauth.jit.listar_bandeja` — aprobador consulta sus pendientes

```json
// REQUEST
{
  "jsonrpc": "2.0",
  "method": "bauth.jit.listar_bandeja",
  "params": {
    "ctx_id": "...",
    "approver_id": "uuid-del-aprobador"  // el daemon valida que coincide con el token
  },
  "id": 2
}

// RESPONSE
{
  "result": {
    "pendientes": [
      {
        "approval_id": "019x-uuid-v7-approval",
        "request_id": "019x-uuid-v7-request",
        "nivel": 1,
        "solicitante": { "id": "uuid", "nombre": "Carlos Quispe" },
        "rol_solicitado": { "id": "uuid", "nombre": "Administrador IT" },
        "justification": "Baja del empleado Pedro Mamani, ref. RR.HH. #847",
        "requested_duration_minutes": 120,
        "tiempo_en_espera_minutos": 12,
        "nivel_1_aprobado_por": null  // o { "nombre": "María López" } si es nivel 2
      }
    ]
  }
}
```

**Query SQL que ejecuta el daemon:**
```sql
SELECT
    a.id            AS approval_id,
    a.request_id,
    a.nivel,
    r.requester_id,
    r.target_role_id,
    r.justification,
    r.requested_duration,
    r.requested_at,
    EXTRACT(EPOCH FROM (now() - r.requested_at)) / 60  AS minutos_espera
FROM bauth.pam_jit_approval a
JOIN bauth.pam_jit_request  r ON r.id = a.request_id
WHERE a.approver_id    = $1          -- UUID del aprobador autenticado
  AND a.decision       IS NULL       -- aún sin decidir
  AND a.notified_at    IS NOT NULL   -- ya fue notificado (su turno)
  AND r.status         = 'PENDING'
ORDER BY r.requested_at ASC;         -- más antiguas primero
```

---

#### `bauth.jit.decidir` — aprobador toma su decisión

```json
// REQUEST — aprobación
{
  "jsonrpc": "2.0",
  "method": "bauth.jit.decidir",
  "params": {
    "ctx_id": "...",
    "approval_id": "uuid-de-la-fila-en-T-182b",
    "decision": "APPROVED",
    "notes": "Justificación válida, proceso RR.HH. verificado"
  },
  "id": 3
}

// REQUEST — rechazo
{
  "jsonrpc": "2.0",
  "method": "bauth.jit.decidir",
  "params": {
    "ctx_id": "...",
    "approval_id": "uuid-de-la-fila-en-T-182b",
    "decision": "REJECTED",
    "notes": "No existe proceso de baja registrado con ese número"
  },
  "id": 3
}

// RESPONSE — aprobado, hay nivel siguiente
{
  "result": {
    "decision": "APPROVED",
    "request_status": "PENDING",
    "siguiente_nivel": { "nivel": 2, "required_role": "CISO", "notificado": true }
  }
}

// RESPONSE — aprobado, era el último nivel → acceso activado
{
  "result": {
    "decision": "APPROVED",
    "request_status": "ACTIVE",
    "grant_id": "uuid-grant-creado-en-T-170",
    "valid_from": "2026-07-21T10:05:00Z",
    "valid_until": "2026-07-21T12:05:00Z"
  }
}

// RESPONSE — rechazado
{
  "result": {
    "decision": "REJECTED",
    "request_status": "REJECTED"
  }
}
```

**Lógica del daemon al recibir `bauth.jit.decidir`:**

```
1. Verificar que approval_id.approver_id == token del caller (no puede aprobar el de otro)
2. UPDATE pam_jit_approval SET decision=$1, approver_id=$2, decision_at=now(), notes=$3
   WHERE id = approval_id AND decision IS NULL

3. Si decision == 'REJECTED':
     UPDATE pam_jit_request SET status='REJECTED' WHERE id = request_id
     → FIN

4. Si decision == 'APPROVED':
     ¿Existe nivel+1 en pam_jit_approval WHERE request_id=? AND nivel = nivel_actual+1?
       SÍ → UPDATE pam_jit_approval SET notified_at=now() WHERE request_id=? AND nivel=nivel+1
            → llamar bnotify.push.enviar(aprobador_nivel_siguiente)
            → FIN (request sigue en PENDING)
       NO (era el último nivel) →
            INSERT privilege_atom_grant (effect=true, general=false, local=true,
                                         access=true, reassess=true,
                                         valid_from=now(), valid_until=now()+requested_duration)
            UPDATE pam_jit_request SET status='ACTIVE', grant_id=nuevo_grant_id,
                                       activated_at=now(), valid_from=..., valid_until=...
            → retornar grant_id y ventana de acceso
```

---

#### `bauth.jit.historial` — historial de solicitudes del usuario

```json
// REQUEST
{
  "jsonrpc": "2.0",
  "method": "bauth.jit.historial",
  "params": { "ctx_id": "...", "usuario_id": "uuid", "limit": 20, "offset": 0 }
}

// RESPONSE
{
  "result": {
    "solicitudes": [
      {
        "request_id": "uuid",
        "status": "ACTIVE",
        "rol": "Administrador IT",
        "justification": "Baja del empleado...",
        "valid_until": "2026-07-21T12:05:00Z",
        "aprobaciones": [
          { "nivel": 1, "aprobador": "María López", "decision": "APPROVED", "decision_at": "..." },
          { "nivel": 2, "aprobador": "Jorge Mamani", "decision": "APPROVED", "decision_at": "..." }
        ]
      }
    ]
  }
}
```

**Query SQL:**
```sql
SELECT
    r.id, r.status, r.justification, r.requested_duration,
    r.valid_from, r.valid_until, r.requested_at,
    json_agg(
        json_build_object(
            'nivel',       a.nivel,
            'approver_id', a.approver_id,
            'decision',    a.decision,
            'decision_at', a.decision_at
        ) ORDER BY a.nivel
    ) AS aprobaciones
FROM bauth.pam_jit_request  r
JOIN bauth.pam_jit_approval a ON a.request_id = r.id
WHERE r.requester_id = $1
  AND r.tenant_id    = $2
GROUP BY r.id
ORDER BY r.requested_at DESC
LIMIT $3 OFFSET $4;
```

---

### Uso desde el código Rust — módulo y funciones

**Ubicación en el árbol de módulos:**

```
src/
└── domain/
    └── jit.rs          ← lógica pura: validaciones, reglas de negocio
src/
└── server/
    └── jit_handler.rs  ← dispatcher JSON-RPC: deserializa params, llama domain/, retorna result
src/
└── sync/
    └── jit_expiry.rs   ← tokio background task: loop cada 60s
```

**Reglas para `domain/jit.rs` (lógica pura — sin I/O, sin DB):**
- `fn validar_solicitud(dur: Duration, max_dur: Duration) → Result<(), BauthError>`
- `fn determinar_niveles(tier: &str) → Vec<NivelAprobacion>` — lee de config, no hardcodeado
- `fn es_ultimo_nivel(nivel_actual: u8, niveles_requeridos: u8) → bool`

**Función PDP — verificación JIT obligatoria (en `domain/pdp.rs` o donde vive el PDP):**

```sql
-- Query que ejecuta el PDP al evaluar un grant de tier elevado:
SELECT EXISTS (
    SELECT 1
    FROM bauth.pam_jit_request
    WHERE grant_id = $1          -- UUID del grant bajo evaluación
      AND status   = 'ACTIVE'
      AND valid_until > now()
) AS jit_activo;

-- Si jit_is_active = false → DENY, sin importar el estado del grant en T-170
```

**Job de expiración en `sync/jit_expiry.rs`:**

```sql
-- Paso 1: encontrar JIT vencidos
SELECT id, grant_id
FROM bauth.pam_jit_request
WHERE status    = 'ACTIVE'
  AND valid_until < now();

-- Paso 2: por cada fila (en una transacción):
UPDATE bauth.privilege_atom_grant
   SET status = 'EXPIRED', updated_at = now()
 WHERE id = $1;  -- grant_id

UPDATE bauth.pam_jit_request
   SET status = 'EXPIRED', expired_at = now()
 WHERE id = $2;  -- jit_request_id
```

Los dos UPDATEs van en una **transacción atómica** — si uno falla, el otro se revierte.
El índice `idx_pjr_active_expiry` en `(valid_until) WHERE status='ACTIVE'` hace esta
consulta instantánea incluso con miles de solicitudes activas.

---

### Implementación pendiente — trabajo requerido

El diseño DDL está completo con el modelo de escalamiento. Lo que falta es el **workflow del daemon**:

| Ítem | Descripción | Prioridad |
|------|-------------|-----------|
| **Motor de escalamiento en Rust** | Al recibir `decision='APPROVED'` en T-182b nivel N: verificar si existe nivel N+1; si SÍ → UPDATE `notified_at` del nivel N+1 + push notificación; si NO (último nivel) → marcar T-182 `status='APPROVED'` y activar el grant en T-170. Al recibir `decision='REJECTED'`: marcar T-182 `status='REJECTED'` sin importar el nivel. | 🔴 BLOQUEANTE |
| **Flujo de activación del grant** | Al completar todos los niveles: INSERT en `privilege_atom_grant` con `valid_from=now()`, `valid_until=now()+requested_duration`, `effect=true`, `general=false`, `reassess=true`; UPDATE T-182 `status='ACTIVE'`, `grant_id`, `activated_at`, `valid_from`, `valid_until`. | 🔴 BLOQUEANTE |
| **Job de expiración (tokio task)** | Loop cada 60s: `SELECT * FROM pam_jit_request WHERE status='ACTIVE' AND valid_until < now()`. Por cada fila: expira T-170 y T-182. Sin este job los JIT aprobados duran para siempre. | 🔴 BLOQUEANTE |
| **Verificación PDP pre-PERMIT** | Al evaluar un grant de tier SYS o átomos D10/D11/D12: verificar que existe `pam_jit_request` con `status='ACTIVE'` y `grant_id = grant.id`. Si no → DENY aunque el grant esté ACTIVE en T-170. | 🔴 BLOQUEANTE |
| **Seed de niveles por tier** | Al crear una solicitud JIT, el daemon lee el tier del `target_role_id` desde `idn_roles_rol_tier` y determina cuántos niveles requiere y con qué `required_role`. Esto debe estar en configuración de tenant, no hardcodeado. | 🟠 ALTA |
| **DDL aplicado** | Ejecutar DDL de T-182 y T-182b en `bauth_db`. | 🔴 BLOQUEANTE |

---

## G-18 · Referencias de credenciales privilegiadas ✅ DISEÑO APROBADO

**Pilar:** PAM · **Prioridad:** 🟠 ALTA · **Sección A.65.02:** PAM

**Normativa:** NIST SP 800-53 IA-5(1) · CIS Benchmark § Credential Management · PCI DSS 4.0 Req 8.3

**Regla invariante:** esta tabla NUNCA almacena valores de credenciales. Solo metadatos y ruta en Vault.

---

### DDL

```sql
-- T-183 bauth.pam_credential_ref — referencia a credencial privilegiada en Vault
-- Sección A.65.02: PAM
-- Solo metadatos y ruta en Vault. NUNCA el valor de la credencial.
CREATE TABLE bauth.pam_credential_ref (
    id                  uuid        NOT NULL DEFAULT uuidv7(),
    tenant_id           uuid        NOT NULL REFERENCES bauth.idn_tenant(id),
    owner_id            uuid        NOT NULL,
    owner_type          text        NOT NULL,
    credential_type     text        NOT NULL,
    vault_path          text        NOT NULL,
    target_system       text        NOT NULL,
    rotation_policy     text        NOT NULL DEFAULT 'AUTO_90D',
    last_rotated_at     timestamptz NULL,
    next_rotation_at    timestamptz NULL,
    rotation_count      int         NOT NULL DEFAULT 0,
    status              text        NOT NULL DEFAULT 'ACTIVE',
    created_by          uuid        NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),
    ctx_id              text        NOT NULL,
    CONSTRAINT pam_credential_ref_pkey PRIMARY KEY (id),
    CONSTRAINT chk_pcref_type  CHECK (
        credential_type IN ('PASSWORD','SSH_KEY','API_KEY','CERT','TOKEN','OAUTH_CLIENT')
    ),
    CONSTRAINT chk_pcref_owner CHECK (owner_type IN ('HUMAN','NHI')),
    CONSTRAINT chk_pcref_rot   CHECK (
        rotation_policy IN ('MANUAL','AUTO_7D','AUTO_30D','AUTO_90D','AUTO_1Y')
    ),
    CONSTRAINT chk_pcref_status CHECK (
        status IN ('ACTIVE','ROTATING','REVOKED','EXPIRED')
    )
);

CREATE INDEX idx_pcref_rotation ON bauth.pam_credential_ref (next_rotation_at)
    WHERE status = 'ACTIVE' AND next_rotation_at IS NOT NULL;
CREATE INDEX idx_pcref_owner ON bauth.pam_credential_ref (owner_id, owner_type);
```

### Propósito

Controla el inventario de credenciales privilegiadas: qué existen, quién es propietario, a qué
sistema dan acceso, y cuándo deben rotarse. El valor real vive en Vault; esta tabla es el panel
de control de la rotación. Sin esta tabla, la rotación es manual e invisible: nadie sabe cuántas
credenciales hay ni cuáles llevan meses sin rotar.

`owner_type='NHI'` conecta con G-21 `idn_roles_nhi_identity` — los daemons SBOS también tienen
credenciales privilegiadas que deben rotarse.

### Frontend — cómo se maneja

**Módulo PAM → Credenciales:**

1. **Inventario:** tabla con propietario, tipo, sistema destino, política de rotación, próxima rotación, estado. Filas con `next_rotation_at <= now() + 7 days` en amarillo; vencidas en rojo.
2. **Formulario de registro:** propietario (usuario o NHI), tipo, `target_system`, `vault_path` (ruta en Vault), política de rotación. Al guardar → INSERT en T-183; daemon calcula `next_rotation_at`.
3. **Botón "Rotar ahora":** dispara rotación en Vault vía JSON-RPC del daemon → UPDATE `last_rotated_at`, `rotation_count`, `next_rotation_at`.
4. **El frontend nunca muestra ni recibe el valor de la credencial.**

### Cuándo y cómo se alimenta

| Evento | Operación |
|--------|-----------|
| Admin registra nueva credencial privilegiada | INSERT |
| Job de rotación completa rotación en Vault | UPDATE `last_rotated_at`, `next_rotation_at`, `rotation_count` |
| Credencial revocada por incidente | UPDATE `status='REVOKED'` |
| NHI dado de baja (G-22) | UPDATE `status='REVOKED'` en todas sus credenciales |

---

## G-19 · Metadatos de sesión privilegiada ✅ DISEÑO APROBADO

**Pilar:** PAM · **Prioridad:** 🟠 ALTA · **Sección A.65.02:** PAM

**Normativa:** NIST SP 800-53 AU-14 · ISO 27001:2022 A.8.15 · PCI DSS 4.0 Req 10.2.1.3

**Separación de responsabilidades:** T-170b (`privilege_atom_audit`) audita QUÉ se otorgó.
T-184 audita CÓMO se ejerció el privilegio otorgado. La grabación real vive en MinIO/S3;
esta tabla almacena los metadatos y la referencia a la grabación.

---

### DDL

```sql
-- T-184 bauth.pam_session_record — metadatos de sesión de acceso privilegiado
-- Sección A.65.02: PAM
CREATE TABLE bauth.pam_session_record (
    id                  uuid        NOT NULL DEFAULT uuidv7(),
    tenant_id           uuid        NOT NULL REFERENCES bauth.idn_tenant(id),
    session_id          uuid        NOT NULL REFERENCES bauth.ses_session_log(session_id),
    user_id             uuid        NOT NULL,
    grant_id            uuid        NULL REFERENCES bauth.privilege_atom_grant(id),
    jit_request_id      uuid        NULL REFERENCES bauth.pam_jit_request(id),
    target_resource     text        NOT NULL,
    access_type         text        NOT NULL,
    credential_ref_id   uuid        NULL REFERENCES bauth.pam_credential_ref(id),
    started_at          timestamptz NOT NULL DEFAULT now(),
    ended_at            timestamptz NULL,
    duration_seconds    int         NULL GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (ended_at - started_at))::int
    ) STORED,
    commands_count      int         NOT NULL DEFAULT 0,
    recording_ref       text        NULL,
    status              text        NOT NULL DEFAULT 'ACTIVE',
    ctx_id              text        NOT NULL,
    CONSTRAINT pam_session_record_pkey PRIMARY KEY (id),
    CONSTRAINT chk_psr_access_type CHECK (
        access_type IN ('SSH','RDP','API','CONSOLE','DB','CLI','VAULT')
    ),
    CONSTRAINT chk_psr_status CHECK (
        status IN ('ACTIVE','ENDED','TERMINATED','ERROR')
    )
);

CREATE INDEX idx_psr_session ON bauth.pam_session_record (session_id);
CREATE INDEX idx_psr_user    ON bauth.pam_session_record (user_id, tenant_id, started_at DESC);
CREATE INDEX idx_psr_active  ON bauth.pam_session_record (tenant_id) WHERE status = 'ACTIVE';
CREATE INDEX idx_psr_jit     ON bauth.pam_session_record (jit_request_id)
    WHERE jit_request_id IS NOT NULL;
```

### Propósito

Registra **cómo se ejerció** cada acceso privilegiado: a qué recurso, con qué tipo de acceso
(SSH, consola de BD, API), cuándo inició y terminó, cuántos comandos se ejecutaron, y dónde
está la grabación. Permite responder: "¿qué hizo el administrador durante su ventana JIT del
martes a las 02:00?".

`duration_seconds` es GENERATED ALWAYS — calculado automáticamente al escribirse `ended_at`.
Nunca se ingresa manualmente.

`jit_request_id` vincula la sesión con el request JIT que la habilitó (G-17), trazabilidad completa:
evento → justificación → aprobación → sesión → comandos ejecutados.

### Frontend — cómo se maneja

**Módulo PAM → Sesiones Privilegiadas:**

1. **Tabla de sesiones activas y recientes:** usuario, recurso, tipo de acceso, iniciada, duración, comandos, estado.
2. **Detalle de sesión:** request JIT asociado (si aplica), credencial usada, link a grabación en MinIO (si `recording_ref` no es null).
3. **Sesiones activas en tiempo real:** filas con `status='ACTIVE'` actualizadas vía WebSocket. Admin puede terminar una sesión → UPDATE `status='TERMINATED'`; daemon revoca el grant JIT.
4. **Solo escritura del daemon** — el frontend no puede crear registros en esta tabla.

### Cuándo y cómo se alimenta

| Evento | Operación | Actor |
|--------|-----------|-------|
| Usuario privilegiado inicia conexión SSH/DB/API | INSERT `status='ACTIVE'` | Daemon bAuth |
| Comando ejecutado dentro de la sesión | UPDATE `commands_count + 1` | Daemon bAuth |
| Sesión termina normalmente | UPDATE `ended_at`, `status='ENDED'`, `recording_ref` | Daemon bAuth |
| Admin termina sesión desde el dashboard | UPDATE `status='TERMINATED'` | Frontend Desktop → daemon |

---

## G-20 · Ciclo de vida Break-glass ⚠️ EN TRABAJO

**Pilar:** PAM · **Prioridad:** 🔴 BLOQUEANTE · **Sección A.65.02:** PAM

**Normativa:** NIST SP 800-53 AC-2(4) / AC-2(2) / AC-5 / AC-6(9) · ISO 27001:2022 A.5.18 ·
SOX §302 · NIST SP 800-63B Rev.4 §4.3 (AAL3)

**Por qué es funcional:** el sistema de grants (T-170) no distingue semánticamente entre un
grant ordinario y uno de emergencia. Sin esa distinción no se puede: (a) aplicar controles
AAL3 obligatorios únicamente al flujo break-glass, (b) registrar el ciclo de vida de cada
activación con trazabilidad forense, (c) ejecutar la revisión post-evento obligatoria en 24h
(NIST AC-2(4)), ni (d) limitar quién y cuántos grants de emergencia puede tener un tenant.

---

### Decisiones de diseño aprobadas — 2026-07-21

Las tres decisiones siguientes son **irrevocables** en esta versión. Cualquier modificación
futura requiere apertura de un nuevo gap con justificación normativa explícita.

---

#### D1 — Marcador semántico `grant_type` en T-170 (`privilege_atom_grant`)

**Decisión:** Se agrega la columna `grant_type text NOT NULL DEFAULT 'STANDARD'` con
`CHECK (grant_type IN ('STANDARD','JIT','BREAKGLASS'))` a la tabla T-170.

**Justificación técnica:**
Antes de esta decisión, la única señal que distinguía un grant break-glass era
`reassess = false` (inmunidad a señales CAEP). Ese campo tiene una semántica diferente:
gobierna si el grant puede ser revocado por eventos automáticos del sistema. No clasifica
el origen ni el propósito del grant.

El problema concreto: un daemon SBOS (NHI crítico) también tiene `reassess = false` porque
no puede ser interrumpido por una señal CAEP externa. Bajo el esquema anterior, el daemon
de validación de break-glass habría identificado ese grant como candidato de emergencia,
produciendo falsos positivos en `pam_breakglass_activation` y contaminando los registros
de auditoría con activaciones que no corresponden a ningún incidente real.

`grant_type = 'BREAKGLASS'` es un marcador explícito, inequívoco y consultable por índice
parcial. El campo `reassess` se mantiene como invariante de comportamiento CAEP — los dos
campos coexisten con responsabilidades ortogonales y no se reemplazan mutuamente:

| Campo | Pregunta que responde | Quién lo lee |
|-------|----------------------|-------------|
| `grant_type` | ¿Qué clase de grant es este? (origen / propósito) | Daemon bAuth, módulo breakglass |
| `reassess` | ¿Puede este grant ser revocado por CAEP? (comportamiento) | CAEP receiver, risk engine |

Un grant `BREAKGLASS` SIEMPRE tiene `reassess = false` (invariante impuesta por trigger —
ver DDL). No existe grant `BREAKGLASS` con `reassess = true`: el JWT de emergencia no puede
ser interrumpido mid-session por señales automáticas; el cierre es SIEMPRE manual o por TTL.

**DDL de cambio sobre T-170:**

```sql
-- Migración: agregar clasificador semántico de grant a privilege_atom_grant
ALTER TABLE bauth.privilege_atom_grant
    ADD COLUMN grant_type text NOT NULL DEFAULT 'STANDARD'
        CONSTRAINT chk_pag_grant_type
            CHECK (grant_type IN ('STANDARD', 'JIT', 'BREAKGLASS'));

COMMENT ON COLUMN bauth.privilege_atom_grant.grant_type IS
    'Clasificador semántico del grant. '
    'STANDARD = grant ordinario de acceso permanente o con vigencia fija. '
    'JIT = grant temporal creado por el flujo de aprobación JIT (T-182/T-182b, G-17). '
    'BREAKGLASS = grant de emergencia — requiere tier SU/T0 o tipo EMERGENCY, '
    'autenticación AAL3 obligatoria, aprobación dual (segundo SU), TTL máx. 4h. '
    'Este campo clasifica el origen del grant. '
    'El campo reassess gobierna si el grant es elegible para revocación CAEP (semántica distinta).';

-- Índice parcial: consultas de grants de emergencia por tenant (validación en activación)
CREATE INDEX idx_pag_grant_type_breakglass
    ON bauth.privilege_atom_grant (tenant_id, grant_type)
    WHERE grant_type = 'BREAKGLASS';
```

**Trigger de validación de grant BREAKGLASS (invariantes D1 + D2 + D3):**

```sql
-- Función: valida reglas D1/D2/D3 antes de INSERT/UPDATE en privilege_atom_grant
CREATE OR REPLACE FUNCTION bauth.fn_validate_breakglass_grant()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_role_tier     text;
    v_role_type     text;
    v_bg_count      int;
BEGIN
    -- Solo aplica a grants de tipo BREAKGLASS
    IF NEW.grant_type != 'BREAKGLASS' THEN
        RETURN NEW;
    END IF;

    -- D2: Solo tier SU (T0) o tipo de cuenta EMERGENCY pueden tener grants BREAKGLASS
    SELECT rt.tier, rty.code
      INTO v_role_tier, v_role_type
      FROM bauth.idn_role_template  rt
      JOIN bauth.idn_role_type      rty ON rty.id = rt.type_id
     WHERE rt.id = NEW.role_id;

    IF v_role_tier != 'SU' AND v_role_type != 'EMERGENCY' THEN
        RAISE EXCEPTION
            'BREAKGLASS_TIER_VIOLATION: grant BREAKGLASS solo permitido para tier SU o '
            'tipo de cuenta EMERGENCY. Rol actual — tier: %, tipo: %',
            v_role_tier, v_role_type;
    END IF;

    -- D3: Máximo 2 grants BREAKGLASS activos (status ACTIVE o INACTIVE) por tenant
    SELECT COUNT(*)
      INTO v_bg_count
      FROM bauth.privilege_atom_grant
     WHERE tenant_id  = NEW.tenant_id
       AND grant_type = 'BREAKGLASS'
       AND status     IN ('ACTIVE', 'INACTIVE')
       AND id         != COALESCE(OLD.id, '00000000-0000-0000-0000-000000000000'::uuid);

    IF v_bg_count >= 2 THEN
        RAISE EXCEPTION
            'BREAKGLASS_LIMIT_EXCEEDED: el tenant ya cuenta con 2 grants BREAKGLASS activos '
            '(1 primario + 1 de respaldo). Límite máximo por diseño D3. '
            'Revoque o archive un grant existente antes de crear uno nuevo.';
    END IF;

    -- D1 invariante: los grants BREAKGLASS son siempre inmunes a señales CAEP
    NEW.reassess := false;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_breakglass_grant
    BEFORE INSERT OR UPDATE OF grant_type, status
    ON bauth.privilege_atom_grant
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_validate_breakglass_grant();
```

---

#### D2 — Tiers elegibles para grants BREAKGLASS

**Decisión:** Solo pueden recibir un grant de tipo `BREAKGLASS` los usuarios cuyo rol
pertenece a los siguientes tiers:

| Tier | Código en `idn_role_type` | Justificación |
|------|---------------------------|---------------|
| `SU` / T0 | `INDIVIDUAL` con tier `SU` | Superusuarios con responsabilidad contractual explícita sobre el sistema |
| — | `EMERGENCY` | Cuentas de emergencia formales per NIST AC-2(2) — máx. 72h, inextensibles |

**Justificación normativa:**
NIST SP 800-53 AC-2(2) define las cuentas de emergencia como una categoría formal con
controles adicionales — no son una escalación ad hoc de cualquier cuenta privilegiada.
ISO 27001:2022 A.5.18 exige que los derechos de acceso de emergencia estén documentados
y sujetos a proceso de aprobación. Ampliar el break-glass a tiers intermedios (BIZ_N1,
BIZ_N2) erosionaría esos controles: el personal de mandos medios no tiene el nivel de
accountability contractual que justifica acceso irrestricto al sistema.

El tenant configura los SU y las cuentas EMERGENCY durante el onboarding. Su identidad es
conocida por el CISO y está respaldada por contrato. Ante un incidente, son las únicas
personas con la formación y la responsabilidad legal para operar sin controles de flujo
normales.

**Validación en el daemon (antes de crear el grant):**

```
bauth.breakglass.grant.crear (nuevo método JSON-RPC, distinto de bauth.pam.breakglass.activar):
1. Verificar que el caller tiene átomo d08.emergency.approve activo
2. Verificar que el user_id destino pertenece a tier SU o type EMERGENCY
3. Verificar que el tenant no supera los 2 grants BREAKGLASS activos (D3)
4. INSERT privilege_atom_grant con grant_type='BREAKGLASS', reassess=false,
   valid_until = now() + interval '72 hours' (inextensible NIST AC-2(2))
5. Registrar en T-170b (WORM audit)
```

---

#### D3 — Máximo 2 grants BREAKGLASS activos por tenant

**Decisión:** Un tenant puede tener como máximo **2 grants `BREAKGLASS`** en estado
`ACTIVE` o `INACTIVE` de forma simultánea. El límite cubre:

- **1 primario:** la cuenta que se activa en el incidente
- **1 de respaldo:** disponible si el titular del primario está incomunicado o comprometido

**Justificación operacional:**
Con un solo grant, si el titular está fuera de alcance durante el incidente, no existe
alternativa y el sistema queda sin acceso de emergencia. Con tres o más, los controles
post-evento se complican: el CISO debe revisar múltiples registros de activación, el
proceso de rotación periódica de credenciales EMERGENCY se multiplica, y la superficie de
ataque crece sin beneficio proporcional.

El patrón de 2 cuentas (primaria + respaldo) es la práctica estándar en plataformas PAM
tier-1 (CyberArk "Emergency Access" §3.2 · BeyondTrust "Break-Glass Design" §4.1 ·
Delinea "Privileged Account Policies" §2.3). Con 2 cuentas gobernadas, el CISO mantiene
visibilidad completa y el proceso de revisión post-evento es manejable.

**Enforcement:** el trigger `trg_validate_breakglass_grant` (ver D1) implementa este límite
a nivel de base de datos con `RAISE EXCEPTION` — no es una validación de aplicación que
pueda ser omitida por un bug en el daemon.

---

### DDL — T-185 `bauth.pam_breakglass_activation`

```sql
-- T-185 bauth.pam_breakglass_activation — ciclo de vida de activaciones break-glass
-- Sección A.65.02: PAM
--
-- Toda activación de un grant BREAKGLASS (grant_type='BREAKGLASS' en T-170) genera
-- una fila aquí. El ciclo de vida es:
--   PENDING_APPROVAL → ACTIVE → DEACTIVATED → REVIEWED
--
-- El activador DEBE haber completado AAL3 (mTLS X.509 o WebAuthn roaming) antes de
-- llamar al método bauth.pam.breakglass.activar. El campo auth_method registra cuál
-- de los métodos AAL3 fue usado, permitiendo detectar uso sistemático del método
-- alternativo (alerta de riesgo).
--
-- El estado PENDING_APPROVAL refleja el paso 5 del flujo S7 (auth.emergency.break_glass):
-- el activador solicita y un segundo SU aprueba. Solo con aprobación el grant se activa.
CREATE TABLE bauth.pam_breakglass_activation (
    id                  uuid        NOT NULL DEFAULT uuidv7(),
    tenant_id           uuid        NOT NULL REFERENCES bauth.idn_tenant(id),

    -- Quién activa y quién aprueba (dual control NIST AC-5)
    activated_by        uuid        NOT NULL,
    approver_id         uuid        NULL,
    approved_at         timestamptz NULL,

    -- Grant de emergencia referenciado
    grant_id            uuid        NOT NULL REFERENCES bauth.privilege_atom_grant(id),

    -- Contexto del incidente
    incident_ref        text        NULL,
    justification       text        NOT NULL,

    -- Evidencia del método AAL3 usado para activar
    auth_method         text        NOT NULL,
    auth_loa            int         NOT NULL DEFAULT 3,

    -- Ciclo de vida temporal
    activated_at        timestamptz NOT NULL DEFAULT now(),
    deactivated_at      timestamptz NULL,
    deactivated_by      uuid        NULL,

    -- Revisión post-evento obligatoria (NIST AC-2(4): máx. 24h)
    post_review_due_at  timestamptz NOT NULL,
    post_review_at      timestamptz NULL,
    post_reviewer_id    uuid        NULL,
    post_review_notes   text        NULL,

    status              text        NOT NULL DEFAULT 'PENDING_APPROVAL',
    ctx_id              text        NOT NULL,

    CONSTRAINT pam_breakglass_activation_pkey PRIMARY KEY (id),

    -- Estados válidos del ciclo de vida
    CONSTRAINT chk_pbga_status CHECK (
        status IN ('PENDING_APPROVAL', 'ACTIVE', 'DEACTIVATED', 'REVIEWED')
    ),

    -- El método AAL3 debe ser uno de los tres declarados en el RolTemplate EMERGENCY B4
    CONSTRAINT chk_pbga_auth_method CHECK (
        auth_method IN ('MTLS_X509', 'WEBAUTHN_ROAMING', 'WEBAUTHN_PLATFORM')
    ),

    -- Solo AAL3 puede activar break-glass (NIST SP 800-63B §4.3)
    CONSTRAINT chk_pbga_auth_loa CHECK (auth_loa = 3),

    -- La revisión siempre es posterior a la activación
    CONSTRAINT chk_pbga_review_due CHECK (post_review_due_at > activated_at),

    -- Si el status es DEACTIVATED o REVIEWED, deactivated_at debe estar registrado
    CONSTRAINT chk_pbga_deactivation CHECK (
        (status IN ('DEACTIVATED', 'REVIEWED') AND deactivated_at IS NOT NULL)
        OR status IN ('PENDING_APPROVAL', 'ACTIVE')
    ),

    -- Estado ACTIVE solo alcanzable con aprobador registrado (dual control)
    CONSTRAINT chk_pbga_dual_control CHECK (
        (status = 'ACTIVE' AND approver_id IS NOT NULL AND approved_at IS NOT NULL)
        OR status IN ('PENDING_APPROVAL', 'DEACTIVATED', 'REVIEWED')
    )
);

-- Un grant BREAKGLASS no puede tener dos activaciones simultáneas en curso (PENDING o ACTIVE)
CREATE UNIQUE INDEX uq_pbga_active_grant
    ON bauth.pam_breakglass_activation (tenant_id, grant_id)
    WHERE status IN ('PENDING_APPROVAL', 'ACTIVE');

-- Consulta de activaciones activas por tenant (panel PAM del dashboard)
CREATE INDEX idx_pbga_tenant_active
    ON bauth.pam_breakglass_activation (tenant_id, activated_at DESC)
    WHERE status = 'ACTIVE';

-- Job de alertas: revisiones pendientes próximas a vencer
CREATE INDEX idx_pbga_review_pending
    ON bauth.pam_breakglass_activation (post_review_due_at)
    WHERE post_review_at IS NULL;
```

---

### RolTemplate B4 — Declaración de métodos para rol EMERGENCY

Los roles con `type_id = 'EMERGENCY'` deben declarar la siguiente sección B4 en su
`idn_role_template.config JSONB`. Esta declaración es la fuente de verdad de qué métodos
AAL3 acepta el sistema para activar el break-glass y en qué orden de prioridad.

**Campos de `alternativeMethods[]` relevantes para break-glass:**
- `loa_change: "none"` → el método alternativo provee el mismo AAL3 que el primario
- `loa_change: "degraded"` → el método alternativo reduce el LoA (requiere aprobación dual reforzada)
- `requires_approval: true` → el uso del alternativo no es automático; requiere un segundo SU
- `max_uses: 1` → el alternativo solo puede usarse una vez por activación
- `alert_on_use: true` → cualquier uso del alternativo emite evento CAEP `Assurance Level Change`
  con `alert_level = 'CRITICAL'` y notificación inmediata al CISO

```json
"B4": {
  "level_of_assurance": 3,

  "availableMethods": [
    {
      "id": "MTLS_X509",
      "tipo": "posesion",
      "loa": 3,
      "estado": "activo",
      "amr_value": "mtls",
      "descripcion": "Certificado X.509 emitido por AGETIC (ex-ADSIB). Ley 164. AAL3 canónico."
    },
    {
      "id": "WEBAUTHN_ROAMING",
      "tipo": "posesion",
      "loa": 3,
      "estado": "activo",
      "amr_value": "hwk",
      "descripcion": "Llave de seguridad FIDO2 física (ej. Feitian ePass, Clave hardware). AAL3."
    },
    {
      "id": "WEBAUTHN_PLATFORM",
      "tipo": "inherencia+posesion",
      "loa": 2,
      "estado": "alternativo_degradado",
      "amr_value": "fpt",
      "descripcion": "Biométrico de plataforma (huella/rostro en dispositivo). AAL2 solo. Solo como último recurso con aprobación reforzada."
    }
  ],

  "requiredMethods": {
    "break_glass_activation": [
      {
        "method_id": "MTLS_X509",
        "order": 1,
        "min_loa": 3,
        "required": true,
        "comment": "Primera opción AAL3. Certificado PKI emitido por AGETIC. Si no disponible, usar alternativa declarada en alternativeMethods."
      }
    ]
  },

  "alternativeMethods": [
    {
      "replaces": "MTLS_X509",
      "with": "WEBAUTHN_ROAMING",
      "loa_change": "none",
      "requires_approval": true,
      "max_uses": 1,
      "alert_on_use": true,
      "reason": "Certificado PKI no disponible en el momento del incidente. La llave FIDO2 física mantiene AAL3."
    },
    {
      "replaces": "WEBAUTHN_ROAMING",
      "with": "WEBAUTHN_PLATFORM",
      "loa_change": "degraded",
      "requires_approval": true,
      "max_uses": 1,
      "alert_on_use": true,
      "reason": "Llave FIDO2 física no disponible. Biométrico de plataforma reduce LoA a AAL2. Solo válido si el segundo SU aprueba explícitamente el uso del método degradado. El campo auth_loa en T-185 registrará 2, no 3."
    }
  ],

  "session_management": {
    "max_session_duration_s": 14400,
    "inactivity_timeout_s": 900,
    "concurrent_sessions_allowed": 1,
    "force_logout_at_end_shift": false,
    "reauthentication_interval_s": 0,
    "comment": "TTL máx. 4h (14400s) per flujo S7. Sesión única — dos activaciones simultáneas bloqueadas por uq_pbga_active_grant. Sin reautenticación periódica: el TTL es el control de tiempo."
  }
}
```

> **Nota sobre WebAuthn Platform (alternativo degradado):**
> Cuando el activador usa `WEBAUTHN_PLATFORM` por no disponer de mTLS ni llave hardware,
> el campo `auth_loa` en T-185 se registra como `2` — no `3`. El constraint
> `chk_pbga_auth_loa CHECK (auth_loa = 3)` debe relajarse a `CHECK (auth_loa IN (2,3))`
> para este caso. El segundo SU que aprueba la activación queda registrado en `approver_id`
> como evidencia forense del control dual que compensó el LoA reducido.

**Actualización de constraint para caso alternativo degradado:**

```sql
ALTER TABLE bauth.pam_breakglass_activation
    DROP CONSTRAINT chk_pbga_auth_loa,
    ADD CONSTRAINT chk_pbga_auth_loa
        CHECK (auth_loa IN (2, 3));

COMMENT ON CONSTRAINT chk_pbga_auth_loa ON bauth.pam_breakglass_activation IS
    'auth_loa=3: método primario (MTLS_X509 o WEBAUTHN_ROAMING). '
    'auth_loa=2: método alternativo degradado (WEBAUTHN_PLATFORM) — solo válido si '
    'approver_id IS NOT NULL (segundo SU aprobó explícitamente el uso del alternativo).';
```

---

### Átomos requeridos — dominio D08 / D09 / D11

Estos átomos deben existir en el catálogo y asignarse al rol EMERGENCY en T-170 con
`grant_type='BREAKGLASS'` para que el PDP autorice las operaciones del flujo S7.

| Átomo | Verbo | Propósito en el flujo break-glass | Norma |
|-------|-------|----------------------------------|-------|
| `d08.emergency.approve` | `approve` | El segundo SU presiona "APROBAR" en el panel PAM — sin este átomo el PDP rechaza la aprobación | NIST AC-5 · AC-17(3) · ISO A.5.17 |
| `d08.session.delete` | `delete` | Revocación forzada del JWT de emergencia al desactivar el break-glass | CAEP `Session Revoked` |
| `d08.assurance.validate` | `validate` | Verificar que la sesión break-glass mantiene el LoA declarado durante toda su vigencia | CAEP `Assurance Level Change` |
| `d08.risk.audit` | `audit` | Investigación post-incidente: el CISO consulta el score de riesgo del período de emergencia | NIST SP 800-207 §3.4 |
| `d11.events.create` | `create` | Registrar activación, uso y cierre del break-glass en el log WORM de auditoría | NIST AU-2 · ISO A.8.15 |
| `d11.integrity.validate` | `validate` | Verificar la cadena de hash del log de auditoría del período de emergencia — evidencia forense válida | NIST AU-9 · PCI DSS 10.3.2 |
| `d09.tokens.emit` | `emit` | Emitir el JWT de break-glass (TTL 4h, scope `break_glass_only`) | RFC 9068 · RFC 6749 |
| `d09.tokens.delete` | `delete` | Revocar el JWT al desactivar o al expirar el TTL | RFC 9068 |
| `d09.revocation.execute` | `execute` | Propagar la revocación < 30s a Kong y todos los PEPs activos | NIST SP 800-63-4 §8 · RFC 5280 CRL |

---

### Propósito de T-185

Registra cada activación de una cuenta break-glass desde la solicitud inicial
(`PENDING_APPROVAL`) hasta la revisión post-evento (`REVIEWED`). Los campos clave:

- `approver_id` / `approved_at`: evidencia del dual control NIST AC-5. Sin ambos no hay estado `ACTIVE`.
- `auth_method`: qué método AAL3 usó el activador. Si se usa sistemáticamente el alternativo degradado (`WEBAUTHN_PLATFORM`) en lugar del primario, el CISO debe investigar por qué el certificado PKI no está disponible.
- `post_review_due_at`: límite de revisión obligatoria (24h). El job de alertas notifica al CISO cuando queda menos de 2h.
- `status='REVIEWED'`: estado terminal positivo — el CISO confirmó que la activación fue justificada. Si hubo problema, el CISO lo documenta en `post_review_notes` y escala a proceso disciplinario fuera del sistema.

---

### Frontend — cómo se maneja

**Módulo PAM → Break-Glass:**

1. **Solicitud de emergencia (activador — SU o EMERGENCY):** panel restringido "ACCESO DE EMERGENCIA". Antes de mostrar el formulario, bAuth verifica AAL3 activo de la sesión (`d08.assurance.validate`). Formulario: `justification` (mínimo 50 chars), `incident_ref`. El sistema muestra el `auth_method` detectado y advierte si es alternativo degradado. Al enviar → INSERT en T-185 con `status='PENDING_APPROVAL'` + notificación inmediata a todos los SU por bNotify.

2. **Aprobación del segundo SU (`d08.emergency.approve`):** el segundo SU recibe notificación push. Puede APROBAR o RECHAZAR con justificación. Al APROBAR → UPDATE T-185 `status='ACTIVE'`, `approver_id`, `approved_at`; UPDATE T-170 grant `status='ACTIVE'`, `effect=true`. Al RECHAZAR → UPDATE T-185 `status='DEACTIVATED'`, `deactivated_at`; la solicitud queda cerrada sin acceso.

3. **Panel de administración break-glass (CISO / SU):** tabla de activaciones activas con cuenta regresiva hasta `post_review_due_at`. Filas vencidas sin revisión resaltadas en rojo. Botón "Desactivar" disponible en cualquier momento → `status='DEACTIVATED'`, `deactivated_at`, `deactivated_by`; UPDATE T-170 `status='REVOKED'`.

4. **Revisión post-incidente (CISO):** formulario con `post_review_notes` (análisis del incidente, justificación de si la activación fue apropiada, recomendaciones). Al guardar → UPDATE `post_review_at`, `post_reviewer_id`, `status='REVIEWED'`.

### Cuándo y cómo se alimenta T-185

| Evento | Transición de estado | Operación |
|--------|---------------------|-----------|
| Activador solicita break-glass | → `PENDING_APPROVAL` | INSERT con `auth_method`, `justification`, `incident_ref` |
| Segundo SU aprueba | `PENDING_APPROVAL` → `ACTIVE` | UPDATE `approver_id`, `approved_at`, `status`; UPDATE T-170 grant |
| Segundo SU rechaza | `PENDING_APPROVAL` → `DEACTIVATED` | UPDATE `deactivated_at`, `status='DEACTIVATED'` |
| Admin/CISO desactiva | `ACTIVE` → `DEACTIVATED` | UPDATE `deactivated_at`, `deactivated_by`, `status`; REVOKE T-170 |
| TTL 4h expira (job) | `ACTIVE` → `DEACTIVATED` | UPDATE `deactivated_at='now()'`, `deactivated_by='system'`; REVOKE T-170 |
| CISO completa revisión | `DEACTIVATED` → `REVIEWED` | UPDATE `post_review_at`, `post_reviewer_id`, `post_review_notes`, `status` |
| Job de alertas detecta revisión vencida | sin cambio | bnotify.push.enviar al CISO (urgencia CRÍTICA) |

---

### Uso desde el frontend — métodos JSON-RPC

**Namespace:** `bauth.pam.breakglass.*`

#### `bauth.pam.breakglass.solicitar` — activador inicia acceso de emergencia

```json
// REQUEST
{ "method": "bauth.pam.breakglass.solicitar",
  "params": {
    "ctx_id": "...",
    "grant_id": "uuid-del-grant-breakglass-en-T170",
    "justification": "Servidor de producción S03 caído, acceso urgente para reinicio controlado. Sin acceso normal por falla de autenticación del operador de turno.",
    "incident_ref": "INC-2026-0721-003"
  } }

// RESPONSE — éxito: solicitud pendiente de aprobación del segundo SU
{ "result": {
    "activation_id": "019x-uuid-v7",
    "status": "PENDING_APPROVAL",
    "auth_method_detectado": "MTLS_X509",
    "auth_loa": 3,
    "post_review_due_at": "2026-07-22T10:15:00Z",
    "aviso": "Solicitud enviada a los SU del sistema. El acceso se activará cuando un segundo SU apruebe. Tiene 24h para completar la revisión post-evento."
  } }

// RESPONSE — error: grant no es de tipo BREAKGLASS
{ "error": { "code": -32010,
  "message": "El grant especificado no es de tipo BREAKGLASS. Solo grants grant_type='BREAKGLASS' pueden iniciar este flujo." } }

// RESPONSE — error: sesión sin AAL3
{ "error": { "code": -32012,
  "message": "La sesión activa no tiene nivel de garantía AAL3. Se requiere autenticación con MTLS_X509 o WEBAUTHN_ROAMING antes de activar el break-glass." } }

// RESPONSE — error: activación duplicada
{ "error": { "code": -32011,
  "message": "Ya existe una activación PENDING_APPROVAL o ACTIVE para este grant en este tenant." } }
```

**Lógica del daemon — transacción atómica:**
```
1. Leer la sesión activa del caller:
   → Verificar que ctx_id corresponde a una sesión con auth_loa >= 2
   → Verificar que el JWT incluye amr[] con 'mtls', 'hwk', o 'fpt' (AAL3 o alternativo)
   → Resolver auth_method: 'mtls'→MTLS_X509, 'hwk'→WEBAUTHN_ROAMING, 'fpt'→WEBAUTHN_PLATFORM
2. Verificar que grant.grant_type == 'BREAKGLASS' (distinto de reassess, D1)
3. Verificar que grant.user_id == caller_id (el grant es del activador)
4. Verificar que no exista activación en estado PENDING_APPROVAL o ACTIVE para (tenant_id, grant_id)
   → garantizado por uq_pbga_active_grant
5. Verificar justification.len() >= 50 chars
6. INSERT pam_breakglass_activation:
     activated_by=$caller_id,
     grant_id=$grant_id,
     incident_ref=$incident_ref,
     justification=$justification,
     auth_method=$auth_method_detectado,
     auth_loa=$loa_detectado,
     post_review_due_at = now() + interval '24 hours',
     status='PENDING_APPROVAL'
7. Notificación push inmediata a TODOS los SU del tenant via bnotify.push.enviar:
     urgencia=CRITICA,
     titulo="SOLICITUD DE ACCESO DE EMERGENCIA",
     cuerpo="$activador solicita break-glass. Ref: $incident_ref. Requiere aprobación."
8. Retornar activation_id y estado PENDING_APPROVAL
```

---

#### `bauth.pam.breakglass.aprobar` — segundo SU aprueba o rechaza

```json
// REQUEST — aprobar
{ "method": "bauth.pam.breakglass.aprobar",
  "params": {
    "ctx_id": "...",
    "activation_id": "uuid",
    "decision": "APPROVED",
    "notes": "Incidente verificado en el sistema de monitoreo. Autorizo acceso."
  } }

// REQUEST — rechazar
{ "method": "bauth.pam.breakglass.aprobar",
  "params": {
    "ctx_id": "...",
    "activation_id": "uuid",
    "decision": "REJECTED",
    "notes": "El incidente reportado no justifica break-glass. Usar el procedimiento ordinario de escalamiento."
  } }

// RESPONSE — aprobado
{ "result": { "status": "ACTIVE", "grant_activado": true,
              "activado_en": "2026-07-21T10:20:00Z" } }

// RESPONSE — rechazado
{ "result": { "status": "DEACTIVATED", "grant_activado": false } }

// RESPONSE — error: caller es el mismo activador (prohibido aprobarse a sí mismo)
{ "error": { "code": -32013,
  "message": "El aprobador no puede ser el mismo usuario que solicitó el break-glass. Principio de control dual." } }
```

**Lógica del daemon:**
```
1. Verificar que caller_id != activation.activated_by (no se puede auto-aprobar — NIST AC-5)
2. Verificar que caller tiene átomo d08.emergency.approve activo
3. Si decision == 'APPROVED':
   a. UPDATE pam_breakglass_activation SET
         status='ACTIVE', approver_id=$caller_id, approved_at=now()
      WHERE id=$activation_id AND status='PENDING_APPROVAL'
   b. UPDATE privilege_atom_grant SET
         status='ACTIVE', effect=true, updated_at=now()
      WHERE id = activation.grant_id
   c. Notificar al activador: "Su acceso de emergencia fue aprobado."
   d. INSERT en T-170b (WORM audit)
4. Si decision == 'REJECTED':
   a. UPDATE pam_breakglass_activation SET
         status='DEACTIVATED', deactivated_at=now(), deactivated_by=$caller_id
      WHERE id=$activation_id AND status='PENDING_APPROVAL'
   b. Notificar al activador: "Solicitud rechazada. Motivo: $notes"
```

---

#### `bauth.pam.breakglass.listar` — admin ve activaciones activas

```json
// RESPONSE
{ "result": { "activas": [
    { "activation_id": "uuid",
      "activated_by": { "nombre": "Diego Mamani", "tier": "SU" },
      "approver": { "nombre": "Ana Quispe", "tier": "SU" },
      "auth_method": "MTLS_X509",
      "auth_loa": 3,
      "incident_ref": "INC-2026-0721-003",
      "justification": "Servidor de producción S03 caído...",
      "activated_at": "2026-07-21T10:15:00Z",
      "approved_at": "2026-07-21T10:20:00Z",
      "post_review_due_at": "2026-07-22T10:15:00Z",
      "minutos_para_vencer_revision": 857,
      "revisada": false }
  ] } }
```

**Query SQL (usa `idx_pbga_tenant_active`):**

```sql
SELECT a.id, a.activated_by, a.approver_id, a.auth_method, a.auth_loa,
       a.incident_ref, a.justification,
       a.activated_at, a.approved_at, a.post_review_due_at,
       EXTRACT(EPOCH FROM (a.post_review_due_at - now())) / 60 AS minutos_restantes,
       (a.post_review_at IS NOT NULL) AS revisada
FROM   bauth.pam_breakglass_activation a
WHERE  a.tenant_id = $1
  AND  a.status    = 'ACTIVE'
ORDER BY a.activated_at DESC;
-- Usa: idx_pbga_tenant_active (tenant_id, activated_at DESC WHERE status='ACTIVE')
```

---

#### `bauth.pam.breakglass.desactivar` — admin cierra el acceso de emergencia

```json
// REQUEST
{ "method": "bauth.pam.breakglass.desactivar",
  "params": { "ctx_id": "...", "activation_id": "uuid" } }

// RESPONSE
{ "result": { "desactivado": true, "grant_revocado": true, "jwt_revocado": true } }
```

**Lógica del daemon:**
```
1. UPDATE pam_breakglass_activation
     SET status='DEACTIVATED', deactivated_at=now(), deactivated_by=$caller_id
   WHERE id=$activation_id AND status='ACTIVE'
2. UPDATE privilege_atom_grant SET status='REVOKED', updated_at=now()
   WHERE id = activation.grant_id
   → Disparar CAEP Session Revoked al CAEP transmitter (d09.tokens.delete, d09.revocation.execute)
3. INSERT en T-170b (WORM audit)
```

---

#### `bauth.pam.breakglass.revisar` — CISO completa la revisión post-incidente

```json
// REQUEST
{ "method": "bauth.pam.breakglass.revisar",
  "params": {
    "ctx_id": "...",
    "activation_id": "uuid",
    "post_review_notes": "Activación justificada. Servidor S03 reiniciado exitosamente a las 10:42. Sin acceso a datos de producción de usuarios. Auth_method=MTLS_X509 (correcto). Se recomienda revisar el proceso de monitoreo para evitar recurrencia. Sin acción disciplinaria requerida."
  } }

// RESPONSE
{ "result": { "status": "REVIEWED", "revisado_en": "2026-07-21T11:30:00Z" } }
```

---

### Uso desde el código Rust — módulos y funciones

```
src/domain/breakglass.rs           ← lógica pura: validaciones D1/D2/D3, reglas de ciclo de vida,
                                      detección de LoA degradado, regla anti-auto-aprobación
src/server/breakglass_handler.rs   ← dispatcher JSON-RPC: solicitar, aprobar, listar,
                                      desactivar, revisar
src/sync/breakglass_alert.rs       ← job cada 15 min: detecta revisiones vencidas + TTL expirado
src/sync/breakglass_expiry.rs      ← job cada 1 min: detecta activaciones ACTIVE cuyo
                                      TTL 4h expiró → auto-desactivar y revocar grant
```

**Job de expiración automática en `sync/breakglass_expiry.rs` — cada 1 minuto:**

```sql
-- Activaciones cuyo TTL de 4h ya venció (activated_at + 4h < now())
SELECT a.id, a.grant_id, a.tenant_id
FROM   bauth.pam_breakglass_activation a
WHERE  a.status     = 'ACTIVE'
  AND  a.activated_at + interval '4 hours' < now();
-- Por cada fila:
-- 1. UPDATE pam_breakglass_activation SET status='DEACTIVATED', deactivated_at=now(), deactivated_by='system'
-- 2. UPDATE privilege_atom_grant SET status='REVOKED' WHERE id=grant_id
-- 3. Propagar CAEP Session Revoked via d09.revocation.execute
-- Usa: idx_pbga_tenant_active (filtra ACTIVE, luego chequea activated_at)
```

**Job de alertas en `sync/breakglass_alert.rs` — cada 15 minutos:**

```sql
-- Activaciones sin revisión cuya deadline ya pasó o está a < 2h
SELECT a.id, a.activated_by, a.post_review_due_at, c.value AS ciso_user_id
FROM   bauth.pam_breakglass_activation a
JOIN   bauth.idn_tenant_config c
       ON c.tenant_id = a.tenant_id AND c.key = 'ciso_user_id'
WHERE  a.post_review_at IS NULL
  AND  a.post_review_due_at < now() + interval '2 hours'
  AND  a.status IN ('ACTIVE', 'DEACTIVATED');
-- Usa: idx_pbga_review_pending (post_review_due_at WHERE post_review_at IS NULL)
-- Por cada fila: bnotify.push.enviar(ciso_user_id, urgencia=CRITICA,
--   titulo="REVISIÓN POST-EMERGENCIA VENCIDA",
--   cuerpo="La activación $id debe ser revisada antes de $post_review_due_at.")
```

---

### Implementación pendiente — trabajo requerido

| Ítem | Descripción | Prioridad |
|------|-------------|-----------|
| **Migración T-170 (D1)** | Ejecutar `ALTER TABLE privilege_atom_grant ADD COLUMN grant_type...` y el trigger `trg_validate_breakglass_grant` en `bauth_db`. Sin esta migración los grants BREAKGLASS no existen como tipo formal. | 🔴 BLOQUEANTE |
| **DDL T-185 aplicado** | Ejecutar el DDL completo de `pam_breakglass_activation` en `bauth_db`. | 🔴 BLOQUEANTE |
| **Flujo de aprobación dual** | Implementar `bauth.pam.breakglass.aprobar` con la regla anti-auto-aprobación (caller != activador). Sin esto el dual control es solo declarativo. | 🔴 BLOQUEANTE |
| **Job de expiración TTL** | `sync/breakglass_expiry.rs`: detecta activaciones ACTIVE cuyo `activated_at + 4h < now()` y auto-desactiva. Sin esto el JWT de emergencia persiste indefinidamente. | 🔴 BLOQUEANTE |
| **Job de alerta por revisión vencida** | `sync/breakglass_alert.rs`: alertas al CISO cuando `post_review_due_at < now() + 2h`. NIST AC-2(4) — sin alerta automática el CISO no sabe. | 🔴 BLOQUEANTE |
| **Seed RolTemplate EMERGENCY** | Insertar en `idn_role_template` el rol EMERGENCY con la sección B4 declarada arriba (methods, alternatives, session_management). Sin el seed no hay grant BREAKGLASS posible. | 🟠 ALTA |
| **Atoms D8/D9/D11 en catálogo** | Verificar que los 9 átomos de la tabla anterior existen en T-162 y están asignados al rol EMERGENCY. Sin ellos el PDP rechaza las operaciones del flujo S7. | 🟠 ALTA |

---

## G-21 · Tabla de Identidad No-Humana (NHI) ⚠️ EN TRABAJO

**Pilar:** NHI · **Prioridad:** 🔴 BLOQUEANTE · **Sección A.65.02:** IDENTIDAD

**Normativa:** NIST SP 800-53 IA-2 / AC-2 · ISO 27001:2022 A.5.16 · Gartner IGA 2025

**Por qué es funcional:** los daemons SBOS son NHI que usan el sistema de autenticación pero
no tienen entidad gobernada. Sin esta tabla no se puede asignar propietario, auditar
accountability, ni implementar JIT o rotación de credenciales para daemons.

---

### DDL

```sql
-- T-186 bauth.idn_roles_nhi_identity — identidad no-humana gobernada
-- Sección A.65.02: IDENTIDAD
-- Toda identidad máquina del ecosistema SBOS tiene una fila aquí.
CREATE TABLE bauth.idn_roles_nhi_identity (
    id              uuid        NOT NULL DEFAULT uuidv7(),
    tenant_id       uuid        NOT NULL REFERENCES bauth.idn_tenant(id),
    nhi_type        text        NOT NULL,
    display_name    text        NOT NULL,
    system_ref      text        NOT NULL,
    owner_id        uuid        NOT NULL,
    backup_owner_id uuid        NULL,
    description     text        NULL,
    status          text        NOT NULL DEFAULT 'ACTIVE',
    created_at      timestamptz NOT NULL DEFAULT now(),
    created_by      uuid        NOT NULL,
    last_used_at    timestamptz NULL,
    review_at       timestamptz NOT NULL,
    decommission_at timestamptz NULL,
    ctx_id          text        NOT NULL,
    CONSTRAINT idn_roles_nhi_identity_pkey PRIMARY KEY (id),
    CONSTRAINT uq_nhi_system_ref UNIQUE (tenant_id, system_ref),
    CONSTRAINT chk_inhi_type CHECK (
        nhi_type IN ('SERVICE_ACCOUNT','WORKLOAD','AGENT','BOT','API_CLIENT','CI_CD_PIPELINE')
    ),
    CONSTRAINT chk_inhi_status CHECK (
        status IN ('ACTIVE','DORMANT','DECOMMISSIONED','SUSPENDED')
    )
);

CREATE INDEX idx_inhi_owner   ON bauth.idn_roles_nhi_identity (owner_id);
CREATE INDEX idx_inhi_review  ON bauth.idn_roles_nhi_identity (review_at) WHERE status = 'ACTIVE';
CREATE INDEX idx_inhi_dormant ON bauth.idn_roles_nhi_identity (last_used_at) WHERE status = 'ACTIVE';
```

### Propósito

Entidad raíz de toda identidad máquina en el sistema. `system_ref` es el identificador
único del NHI dentro del tenant (ej. `bauth:bkernel-daemon`, `ci:github-actions-deploy`).
`owner_id` es la persona humana responsable — si el NHI hace algo incorrecto, este humano
es accountable.

`last_used_at` se actualiza cada vez que el NHI se autentica. El índice `idx_inhi_dormant`
detecta NHI sin uso en más de 90 días — candidatos a desactivación. `review_at` define
cuándo debe revisarse este NHI (30 días para CI/CD pipelines; 90 días para service accounts).

**Vinculación con T-170:** `privilege_atom_grant.user_id` puede referenciar tanto un usuario
humano como un NHI. Pendiente decisión HITL: tabla puente `idn_identity` unificada o
referencia directa polimórfica.

### Frontend — cómo se maneja

**Módulo Identidad → Identidades No-Humanas:**

1. **Inventario de NHI:** tabla con nombre, tipo, propietario, último uso, próxima revisión, estado. NHI dormidos (> 90 días sin uso) con badge "INACTIVO". NHI con `review_at` próximo destacados.
2. **Formulario de registro:** `nhi_type` (desplegable), `display_name`, `system_ref` (identificador único), `owner_id` (selector de usuario humano), `backup_owner_id`, `description`, `review_at`.
3. **Detalle de NHI:** pestañas — Credenciales (T-183), Grants activos (T-170), Ciclo de vida (T-187), Secretos (T-189).
4. **Botón "Descomisionar":** marca `status='DECOMMISSIONED'`, `decommission_at=now()`, revoca todos los grants en T-170 y credenciales en T-183.

### Cuándo y cómo se alimenta

| Evento | Operación |
|--------|-----------|
| Admin registra nuevo daemon o pipeline | INSERT |
| NHI se autentica en el sistema | UPDATE `last_used_at = now()` |
| NHI lleva > 90 días sin uso | Job marca `status='DORMANT'` |
| Admin descomisiona el NHI | UPDATE `status='DECOMMISSIONED'`, `decommission_at` |

**Seeds para daemons SBOS:** al inicializar el tenant, el IAM Installer (BOS) siembra una fila
por daemon activo: bkernel, biedata, bnotify, bsearch, bnexus. Propietario inicial: usuario `SU`.

---

### Uso desde el frontend — métodos JSON-RPC

**Namespace:** `bauth.nhi.*`

#### `bauth.nhi.registrar` — admin registra un nuevo NHI

```json
// REQUEST
{ "method": "bauth.nhi.registrar",
  "params": {
    "ctx_id": "...",
    "nhi_type": "SERVICE_ACCOUNT",
    "display_name": "Worker de sincronización bKernel",
    "system_ref": "bkernel:sync-worker-01",
    "owner_id": "uuid-del-responsable-humano",
    "backup_owner_id": "uuid-del-backup",
    "description": "Cuenta de servicio del daemon bKernel para sincronización CDC",
    "review_at": "2026-10-21T00:00:00Z"
  } }

// RESPONSE — éxito
{ "result": { "nhi_id": "019x-uuid-v7", "system_ref": "bkernel:sync-worker-01" } }

// RESPONSE — system_ref duplicado en el tenant
{ "error": { "code": -32020,
  "message": "system_ref 'bkernel:sync-worker-01' ya existe en este tenant (uq_nhi_system_ref)" } }
```

**Qué hace el daemon:**
1. Verificar unicidad de `(tenant_id, system_ref)` — el UNIQUE constraint lo garantiza.
2. INSERT en T-186.
3. INSERT en T-187 `event_type='PROVISIONED'` (log WORM del ciclo de vida).
4. Retornar `nhi_id`.

---

#### `bauth.nhi.listar` — inventario con filtros

```json
// REQUEST
{ "method": "bauth.nhi.listar",
  "params": { "ctx_id": "...", "tenant_id": "uuid",
    "filtros": { "solo_dormidos": false, "revision_proxima_dias": 30,
                 "nhi_type": null },
    "limit": 50, "offset": 0 } }

// RESPONSE
{ "result": { "nhis": [
    { "id": "uuid", "nhi_type": "SERVICE_ACCOUNT",
      "display_name": "Worker bKernel", "system_ref": "bkernel:sync-worker-01",
      "owner": { "nombre": "Ana Condori" },
      "status": "ACTIVE", "last_used_at": "2026-07-21T09:00:00Z",
      "review_at": "2026-10-21T00:00:00Z",
      "dias_desde_ultimo_uso": 0,
      "alertas": [] },
    { "id": "uuid", "nhi_type": "CI_CD_PIPELINE",
      "display_name": "GitHub Actions Deploy",
      "status": "DORMANT", "last_used_at": "2026-04-10T14:00:00Z",
      "dias_desde_ultimo_uso": 102,
      "alertas": ["DORMIDO_MAS_90_DIAS"] }
  ], "total": 7 } }
```

**Query SQL (usa `idx_inhi_dormant` y `idx_inhi_review`):**

```sql
SELECT n.id, n.nhi_type, n.display_name, n.system_ref, n.owner_id,
       n.status, n.last_used_at, n.review_at,
       EXTRACT(DAY FROM now() - n.last_used_at)::int AS dias_sin_uso
FROM   bauth.idn_roles_nhi_identity n
WHERE  n.tenant_id = $1
  AND  ($2::text IS NULL OR n.nhi_type = $2)
  AND  ($3::bool IS FALSE OR n.last_used_at < now() - interval '90 days')
  AND  ($4::int  IS NULL  OR n.review_at  < now() + ($4 || ' days')::interval)
ORDER BY n.last_used_at ASC NULLS FIRST
LIMIT $5 OFFSET $6;
```

---

#### `bauth.nhi.descomisionar` — dar de baja un NHI y revocar todo

```json
// REQUEST
{ "method": "bauth.nhi.descomisionar",
  "params": { "ctx_id": "...", "nhi_id": "uuid",
    "motivo": "Pipeline de CI migrado a GitHub Actions Enterprise, este runner ya no se usa" } }

// RESPONSE
{ "result": {
    "nhi_id": "uuid",
    "status": "DECOMMISSIONED",
    "grants_revocados": 4,
    "credenciales_revocadas": 2,
    "secretos_revocados": 3
  } }
```

**Lógica del daemon — transacción atómica:**
```
1. UPDATE idn_roles_nhi_identity SET status='DECOMMISSIONED', decommission_at=now()
2. UPDATE privilege_atom_grant SET status='REVOKED', updated_at=now()
   WHERE user_id=$nhi_id AND status='ACTIVE'       → retorna COUNT como grants_revocados
   [NOTA: depende de decisión HITL sobre referencia polimórfica]
3. UPDATE pam_credential_ref SET status='REVOKED'
   WHERE owner_id=$nhi_id AND status='ACTIVE'      → retorna COUNT como credenciales_revocadas
4. UPDATE pam_nhi_secret_ref SET status='REVOKED'
   WHERE nhi_id=$nhi_id AND status='ACTIVE'        → retorna COUNT como secretos_revocados
5. INSERT idn_roles_nhi_lifecycle_event event_type='DECOMMISSIONED', notes=$motivo
```

---

### Uso interno del daemon — autenticación de un NHI

Cuando un NHI se autentica (mTLS, token de servicio), el handler de autenticación ejecuta:

```sql
-- Actualizar last_used_at — usa idx_inhi_dormant para detectar dormidos luego
UPDATE bauth.idn_roles_nhi_identity
   SET last_used_at = now()
 WHERE id = $nhi_id AND tenant_id = $tenant_id;
```

Esta query es la más ejecutada de toda la sección NHI — ocurre en cada autenticación de
cada daemon. El índice `idx_inhi_dormant` cubre `(last_used_at) WHERE status='ACTIVE'`
para que el job de dormancia sea instantáneo, no que esta query de UPDATE sea rápida —
el UPDATE necesita el índice `(id)` que es la PK.

---

### Uso desde el código Rust — módulo y funciones

```
src/domain/nhi.rs          ← lógica pura: validaciones, reglas de ciclo de vida NHI
src/server/nhi_handler.rs  ← dispatcher JSON-RPC
src/sync/nhi_dormancy.rs   ← job diario: dormidos + revisiones vencidas
```

**Funciones en `domain/nhi.rs`:**
- `fn validar_system_ref(system_ref: &str) → Result<(), BauthError>` — formato `prefijo:nombre`
- `fn calcular_review_at(nhi_type: &str) → Duration` — 30d CI/CD, 90d service account
- `fn descomisionar(nhi_id: Uuid, conn: &mut PgConn) → Result<DecomisionResult, BauthError>`

**Job de dormancia en `sync/nhi_dormancy.rs` — diario a las 02:00:**

```sql
-- Paso 1: marcar dormidos (sin uso en > 90 días)
UPDATE bauth.idn_roles_nhi_identity
   SET status = 'DORMANT'
 WHERE status      = 'ACTIVE'
   AND last_used_at < now() - interval '90 days'
RETURNING id, owner_id, tenant_id;
-- Por cada fila retornada: INSERT idn_roles_nhi_lifecycle_event (DORMANT) + notificación al owner

-- Paso 2: alertar revisiones vencidas
SELECT id, owner_id, review_at
FROM   bauth.idn_roles_nhi_identity
WHERE  status    = 'ACTIVE'
  AND  review_at < now()
ORDER BY review_at ASC;
-- Usa: idx_inhi_review (review_at WHERE status='ACTIVE')
-- Por cada fila: notificación al owner + al backup_owner vía bnotify.push.enviar
```

**Seed del IAM Installer** — ejecutado por BOS al crear un tenant:

```sql
INSERT INTO bauth.idn_roles_nhi_identity
    (tenant_id, nhi_type, display_name, system_ref, owner_id, review_at, ctx_id)
VALUES
    ($tid, 'SERVICE_ACCOUNT', 'bKernel CDC Worker',    'bkernel:cdc-worker',   $su, now()+interval'90d', $ctx),
    ($tid, 'SERVICE_ACCOUNT', 'bIeData RPC Gateway',   'biedata:rpc-gateway',  $su, now()+interval'90d', $ctx),
    ($tid, 'SERVICE_ACCOUNT', 'bNotify Push Worker',   'bnotify:push-worker',  $su, now()+interval'90d', $ctx),
    ($tid, 'SERVICE_ACCOUNT', 'bSearch Query Engine',  'bsearch:query-engine', $su, now()+interval'90d', $ctx),
    ($tid, 'SERVICE_ACCOUNT', 'bNexus Proxy',          'bnexus:proxy',         $su, now()+interval'90d', $ctx);
-- Este INSERT es responsabilidad del IAM Installer (BOS), no de bAuth.
-- El contrato de integración BOS↔bAuth define que BOS llama bauth.nhi.registrar
-- por cada daemon al completar el despliegue del tenant.
```

---

### Implementación pendiente — trabajo requerido

El diseño DDL está completo. Lo que falta es la **vinculación real de los daemons SBOS con el motor IAM**:

| Ítem | Descripción | Prioridad |
|------|-------------|-----------|
| **HITL — referencia polimórfica** | `privilege_atom_grant.user_id` hoy referencia solo `idn_users`. Un NHI también necesita grants. Opciones: (a) tabla puente `idn_identity` unificada que agrega humanos y NHI; (b) columna `identity_type` + FK polimórfica. **Esta decisión bloquea toda la gobernanza NHI** — sin ella un NHI no puede tener grants y no puede ser evaluado por el PDP. | 🔴 BLOQUEANTE — HITL |
| **Seed IAM Installer** | El IAM Installer (BOS) debe insertar una fila en `idn_roles_nhi_identity` por cada daemon SBOS al crear el tenant. IDs canónicos: `bkernel:worker`, `biedata:rpc`, `bnotify:push`, `bsearch:query`, `bnexus:proxy`. `owner_id = SU`. Sin este seed los daemons operan sin identidad gobernada. | 🔴 BLOQUEANTE |
| **Actualización de `last_used_at` en auth NHI** | Al autenticar un NHI (mutual TLS o service account token), el handler de autenticación debe hacer `UPDATE idn_roles_nhi_identity SET last_used_at = now() WHERE id = nhi_id`. Sin esto el campo siempre es NULL y los jobs de dormancia no detectan inactividad. | 🟠 ALTA |
| **Job de dormancia** | Job diario: `SELECT * FROM idn_roles_nhi_identity WHERE status='ACTIVE' AND last_used_at < now() - interval '90 days'`. Por cada fila: `UPDATE status='DORMANT'`; notificación al `owner_id`. | 🟠 ALTA |
| **DDL aplicado** | Ejecutar DDL de T-186 en `bauth_db`. FK a `idn_tenant` debe resolver. | 🔴 BLOQUEANTE |

---

## G-22 · Ciclo de vida NHI + certificación periódica ✅ DISEÑO APROBADO

**Pilar:** NHI · **Prioridad:** 🟠 ALTA · **Sección A.65.02:** IDENTIDAD

**Normativa:** NIST SP 800-53 IA-5(4) · ISO 27001:2022 A.8.2 · CIS Benchmark § Service Accounts

---

### DDL

```sql
-- T-187 bauth.idn_roles_nhi_lifecycle_event — eventos del ciclo de vida de un NHI
-- Sección A.65.02: IDENTIDAD · WORM: solo INSERT
CREATE TABLE bauth.idn_roles_nhi_lifecycle_event (
    id              uuid        NOT NULL DEFAULT uuidv7(),
    nhi_id          uuid        NOT NULL REFERENCES bauth.idn_roles_nhi_identity(id),
    event_type      text        NOT NULL,
    actor_id        uuid        NOT NULL,
    event_at        timestamptz NOT NULL DEFAULT now(),
    notes           text        NULL,
    metadata        jsonb       NULL,
    ctx_id          text        NOT NULL,
    CONSTRAINT idn_roles_nhi_lifecycle_event_pkey PRIMARY KEY (id),
    CONSTRAINT chk_inle_type CHECK (
        event_type IN (
            'PROVISIONED','CERTIFIED','ROTATED','SUSPENDED',
            'REACTIVATED','DECOMMISSIONED','OWNER_CHANGED','REVIEW_SCHEDULED'
        )
    )
);

CREATE INDEX idx_inle_nhi ON bauth.idn_roles_nhi_lifecycle_event (nhi_id, event_at DESC);

-- T-188 bauth.idn_roles_nhi_certification — certificación periódica del NHI
-- Cadencia mensual; revisor = propietario técnico.
CREATE TABLE bauth.idn_roles_nhi_certification (
    id              uuid        NOT NULL DEFAULT uuidv7(),
    nhi_id          uuid        NOT NULL REFERENCES bauth.idn_roles_nhi_identity(id),
    reviewer_id     uuid        NOT NULL,
    period_start    timestamptz NOT NULL,
    period_end      timestamptz NOT NULL,
    last_used_at    timestamptz NULL,
    access_count    int         NULL,
    decision        text        NOT NULL,
    justification   text        NULL,
    reviewed_at     timestamptz NOT NULL DEFAULT now(),
    ctx_id          text        NOT NULL,
    CONSTRAINT idn_roles_nhi_certification_pkey PRIMARY KEY (id),
    CONSTRAINT chk_inc_decision CHECK (
        decision IN ('CERTIFY','DECOMMISSION','REDUCE_SCOPE','ESCALATE')
    )
);

CREATE INDEX idx_inc_nhi ON bauth.idn_roles_nhi_certification (nhi_id, reviewed_at DESC);
```

### Propósito

`idn_roles_nhi_lifecycle_event` es el log WORM de todo lo que le ocurrió a un NHI desde que fue
creado: provisión, rotaciones de credencial, suspensión, reactivación. Es el historial
forense del NHI. Un trigger en T-186 puede insertar automáticamente aquí en cada cambio de estado.

`idn_roles_nhi_certification` es la evidencia de que alguien revisó el NHI mensualmente. A diferencia
de la certificación humana (trimestral), la NHI es mensual porque los NHI cambian más rápido.
`decision='DECOMMISSION'` dispara el proceso de baja en T-186. `access_count=0` en el período
es el indicador más fuerte para descomisionar.

### Frontend — cómo se maneja

**Módulo Identidad → Detalle de NHI:**

- **Pestaña "Ciclo de Vida":** timeline cronológico de `idn_roles_nhi_lifecycle_event`. Íconos por tipo (clave = ROTATED, candado = SUSPENDED, check = CERTIFIED).
- **Pestaña "Certificación":** tabla de certificaciones históricas (decisión, revisor, fecha, accesos en período). Formulario de certificación visible cuando `review_at <= now()` en T-186. El propietario técnico ve último uso, conteo de accesos, credenciales activas. Decide: Certificar / Descomisionar / Reducir scope / Escalar.

### Cuándo y cómo se alimenta

| Tabla | Evento | Actor |
|-------|--------|-------|
| `idn_roles_nhi_lifecycle_event` | Cualquier cambio de estado en T-186 | Trigger automático en T-186 |
| `idn_roles_nhi_lifecycle_event` | Rotación de credencial (G-18/G-23) | Job de rotación |
| `idn_roles_nhi_certification` | Propietario técnico completa revisión | Frontend Desktop |

---

## G-23 · Referencias de secretos NHI ✅ DISEÑO APROBADO

**Pilar:** NHI · **Prioridad:** 🟠 ALTA · **Sección A.65.02:** PAM

**Normativa:** NIST SP 800-53 IA-5(1) · CIS Benchmark § API Keys · OWASP API Security API8:2023

**Diferencia con T-183 `pam_credential_ref`:** T-183 cubre credenciales privilegiadas de bajo
volumen con revisión manual. Esta tabla cubre secretos NHI de alto volumen y rotación
automatizada de alta frecuencia (7-30 días vs 90 días).

---

### DDL

```sql
-- T-189 bauth.pam_nhi_secret_ref — referencias a secretos de NHI en Vault
-- Sección A.65.02: PAM · NUNCA almacena valores de secretos.
CREATE TABLE bauth.pam_nhi_secret_ref (
    id                  uuid        NOT NULL DEFAULT uuidv7(),
    nhi_id              uuid        NOT NULL REFERENCES bauth.idn_roles_nhi_identity(id),
    secret_type         text        NOT NULL,
    vault_path          text        NOT NULL,
    rotation_policy     text        NOT NULL DEFAULT 'AUTO_30D',
    last_rotated_at     timestamptz NULL,
    next_rotation_at    timestamptz NULL,
    rotation_count      int         NOT NULL DEFAULT 0,
    expires_at          timestamptz NULL,
    status              text        NOT NULL DEFAULT 'ACTIVE',
    created_by          uuid        NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),
    ctx_id              text        NOT NULL,
    CONSTRAINT pam_nhi_secret_ref_pkey PRIMARY KEY (id),
    CONSTRAINT chk_pnsr_type CHECK (
        secret_type IN ('API_KEY','OAUTH_CLIENT','CERT','TOKEN','SSH_KEY','PASSWORD')
    ),
    CONSTRAINT chk_pnsr_rotation CHECK (
        rotation_policy IN ('AUTO_7D','AUTO_30D','AUTO_90D','MANUAL','ON_USE')
    ),
    CONSTRAINT chk_pnsr_status CHECK (
        status IN ('ACTIVE','ROTATING','REVOKED','EXPIRED')
    )
);

CREATE INDEX idx_pnsr_nhi      ON bauth.pam_nhi_secret_ref (nhi_id) WHERE status = 'ACTIVE';
CREATE INDEX idx_pnsr_rotation ON bauth.pam_nhi_secret_ref (next_rotation_at)
    WHERE status = 'ACTIVE' AND next_rotation_at IS NOT NULL;
```

### Propósito

Los NHI usan secretos de alta frecuencia. `rotation_policy='ON_USE'` significa que el secreto
rota cada vez que se usa — patrón recomendado para pipelines CI/CD. `rotation_policy='AUTO_7D'`
es el más frecuente para service accounts internos.

### Frontend — cómo se maneja

**Módulo Identidad → Detalle de NHI → pestaña "Secretos":**
- Lista de secretos activos: tipo, ruta en Vault, política, última rotación, próxima rotación.
- Botón "Rotar ahora" (rotación manual inmediata vía Vault API).
- Botón "Revocar" → `status='REVOKED'`.
- Al descomisionar el NHI → todos sus secretos pasan a `status='REVOKED'` automáticamente.

### Cuándo y cómo se alimenta

| Evento | Operación |
|--------|-----------|
| Admin registra secreto para un NHI | INSERT |
| Job de rotación ejecuta rotación en Vault | UPDATE `last_rotated_at`, `next_rotation_at`, `rotation_count` |
| NHI descomisionado | UPDATE `status='REVOKED'` en todos sus secretos |

---

## G-24 · Agentes IA como identidades gobernadas ✅ DISEÑO APROBADO

**Pilar:** NHI · **Prioridad:** 🟡 MEDIA · **Sección A.65.02:** IDENTIDAD

**Normativa:** NIST AI RMF 1.0 · CSA NHI Governance 2025 · ISO 42001:2023

**⚠️ BLOQUEADO por decisión HITL pendiente:** ¿el agente hijo hereda permisos del padre o
tiene permisos propios? Esta decisión afecta `max_permission_scope`. No implementar hasta
resolver.

---

### DDL

```sql
-- T-190 bauth.idn_roles_nhi_agent_identity — especialización de NHI para agentes IA
-- Sección A.65.02: IDENTIDAD
-- Un agente IA es un NHI con capacidades adicionales: orquestador padre,
-- scope máximo de permisos, y capacidad de crear sub-agentes (con límite).
CREATE TABLE bauth.idn_roles_nhi_agent_identity (
    id                   uuid     NOT NULL DEFAULT uuidv7(),
    nhi_id               uuid     NOT NULL REFERENCES bauth.idn_roles_nhi_identity(id),
    agent_framework      text     NOT NULL,
    orchestrator_id      uuid     NULL REFERENCES bauth.idn_roles_nhi_agent_identity(id),
    max_permission_scope text[]   NOT NULL DEFAULT '{}',
    session_type         text     NOT NULL DEFAULT 'EPHEMERAL',
    can_spawn_agents     boolean  NOT NULL DEFAULT false,
    max_spawn_depth      int      NOT NULL DEFAULT 0,
    CONSTRAINT idn_roles_nhi_agent_identity_pkey PRIMARY KEY (id),
    CONSTRAINT uq_iai_nhi UNIQUE (nhi_id),
    CONSTRAINT chk_iai_session CHECK (session_type IN ('EPHEMERAL','PERSISTENT')),
    CONSTRAINT chk_iai_spawn CHECK (
        (can_spawn_agents = false AND max_spawn_depth = 0)
        OR (can_spawn_agents = true AND max_spawn_depth > 0)
    )
);
```

### Propósito

Especialización de `idn_roles_nhi_identity` para agentes IA autónomos. `max_permission_scope`
limita qué dominios puede usar el agente — incluso si su NHI padre tiene acceso a D03
(financiero), si `max_permission_scope` no incluye 'D03', el PDP lo deniega.

`can_spawn_agents=false` para la mayoría de agentes. Solo los orquestradores tienen
`can_spawn_agents=true` con `max_spawn_depth` limitado.

### Frontend

**Módulo Identidad → NHI → pestaña "Config. de Agente"** (solo visible si `nhi_type='AGENT'`):
árbol de orquestación padre → hijo, multi-select de dominios en `max_permission_scope`,
toggle `can_spawn_agents` + campo `max_spawn_depth`.

### Cuándo y cómo se alimenta

Solo INSERT manual desde el frontend por administrador de seguridad. No hay proceso automático.

---

## G-25 · Log de eventos CAEP entrantes ✅ DISEÑO APROBADO

**Pilar:** CAEP · **Prioridad:** 🟠 ALTA · **Sección A.65.02:** SESIÓN

**Normativa:** NIST SP 800-53 AU-12 · ISO 27001:2022 A.8.15 · CAEP 1.0 §6

---

### DDL

```sql
-- T-191 bauth.ses_caep_event_log — log de eventos CAEP entrantes
-- Sección A.65.02: SESIÓN · WORM: append-only.
-- Candidato a particionamiento por received_at en deployments con múltiples IdPs.
CREATE TABLE bauth.ses_caep_event_log (
    id                  uuid        NOT NULL DEFAULT uuidv7(),
    event_type          text        NOT NULL,
    subject_id          text        NOT NULL,
    subject_type        text        NOT NULL,
    transmitter_id      text        NOT NULL,
    received_at         timestamptz NOT NULL DEFAULT now(),
    processed_at        timestamptz NULL,
    processing_status   text        NOT NULL DEFAULT 'RECEIVED',
    event_payload       jsonb       NOT NULL,
    grants_affected     uuid[]      NULL,
    error_message       text        NULL,
    ctx_id              text        NOT NULL,
    CONSTRAINT ses_caep_event_log_pkey PRIMARY KEY (id),
    CONSTRAINT chk_scel_event_type CHECK (
        event_type IN (
            'session-revoked','token-claims-change','credential-change',
            'assurance-level-change','device-compliance-change','risk-level-change'
        )
    ),
    CONSTRAINT chk_scel_subject_type CHECK (
        subject_type IN ('session','user','device','token','oauth_client')
    ),
    CONSTRAINT chk_scel_status CHECK (
        processing_status IN ('RECEIVED','PROCESSING','APPLIED','FAILED','IGNORED')
    )
);

CREATE INDEX idx_scel_received ON bauth.ses_caep_event_log (received_at DESC);
CREATE INDEX idx_scel_pending  ON bauth.ses_caep_event_log (processing_status)
    WHERE processing_status IN ('RECEIVED','PROCESSING','FAILED');
CREATE INDEX idx_scel_subject  ON bauth.ses_caep_event_log (subject_id, event_type);
```

### Propósito

Registra **cada evento CAEP que llegó** al receptor de bAuth, su estado de procesamiento y
qué grants afectó. Sin esta tabla, si un evento CAEP revocó la sesión de un usuario, no hay
evidencia de qué señal disparó la revocación ni cuándo llegó.

`grants_affected` = array de UUIDs de T-170 suspendidos/revocados por el evento. Conecta
el evento CAEP con la acción concreta del PDP.

`processing_status='FAILED'` + `error_message` permite al admin ver qué eventos no pudieron
procesarse. El índice `idx_scel_pending` alimenta el job de reintento.

### Frontend — cómo se maneja

**Módulo Auditoría → Eventos CAEP:**

1. **Log en tiempo real:** tabla con últimas N filas, filtros por tipo, transmitter, estado, subject. Columna "Grants afectados" con conteo y enlace al detalle.
2. **Detalle de evento:** payload CAEP completo formateado, acción tomada por el PDP, lista de grants afectados con usuario y átomo.
3. **Tab "Eventos fallidos":** `processing_status='FAILED'`, botón "Reintentar" → daemon vuelve a procesar.
4. **Solo escritura del daemon** — el frontend no puede crear registros.

### Cuándo y cómo se alimenta

| Evento | Operación | Actor |
|--------|-----------|-------|
| Receptor CAEP recibe evento externo | INSERT `status='RECEIVED'` | Daemon bAuth |
| PDP procesa el evento | UPDATE `status='PROCESSING'` | Daemon bAuth |
| PDP aplica acción (suspende grants) | UPDATE `status='APPLIED'`, `grants_affected`, `processed_at` | Daemon bAuth |
| Error al procesar | UPDATE `status='FAILED'`, `error_message` | Daemon bAuth |
| Evento sin sujeto conocido | UPDATE `status='IGNORED'` | Daemon bAuth |

---

## G-26 · Configuración SSF Transmitter ✅ DISEÑO APROBADO

**Pilar:** CAEP · **Prioridad:** 🟡 MEDIA · **Sección A.65.02:** SESIÓN

**Normativa:** OpenID SSF 1.0 Final (Sep 2025) §4 · CAEP 1.0 §3

---

### DDL

```sql
-- T-192 bauth.ses_ssf_stream — streams SSF configurados para transmisión de eventos
-- Sección A.65.02: SESIÓN
-- bAuth actúa como SSF Transmitter emitiendo eventos CAEP hacia Kong y otros receivers.
-- La config de cada stream vive aquí — no en archivos TOML hardcodeados.
CREATE TABLE bauth.ses_ssf_stream (
    id                  uuid        NOT NULL DEFAULT uuidv7(),
    tenant_id           uuid        NOT NULL REFERENCES bauth.idn_tenant(id),
    receiver_name       text        NOT NULL,
    receiver_endpoint   text        NOT NULL,
    delivery_method     text        NOT NULL DEFAULT 'PUSH',
    event_types         text[]      NOT NULL,
    auth_vault_path     text        NOT NULL,
    status              text        NOT NULL DEFAULT 'ACTIVE',
    created_by          uuid        NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),
    last_delivered_at   timestamptz NULL,
    error_count         int         NOT NULL DEFAULT 0,
    ctx_id              text        NOT NULL,
    CONSTRAINT ses_ssf_stream_pkey PRIMARY KEY (id),
    CONSTRAINT chk_sss_delivery CHECK (delivery_method IN ('PUSH','POLL')),
    CONSTRAINT chk_sss_status   CHECK (status IN ('ACTIVE','PAUSED','TERMINATED','ERROR'))
);

-- T-193 bauth.ses_ssf_delivery_log — log de entrega por stream
-- WORM: append-only. Una fila por intento de entrega.
CREATE TABLE bauth.ses_ssf_delivery_log (
    id              uuid        NOT NULL DEFAULT uuidv7(),
    stream_id       uuid        NOT NULL REFERENCES bauth.ses_ssf_stream(id),
    caep_event_id   uuid        NULL,
    event_type      text        NOT NULL,
    delivered_at    timestamptz NOT NULL DEFAULT now(),
    delivery_status text        NOT NULL,
    http_status     int         NULL,
    retry_count     int         NOT NULL DEFAULT 0,
    error_message   text        NULL,
    CONSTRAINT ses_ssf_delivery_log_pkey PRIMARY KEY (id),
    CONSTRAINT chk_ssdl_status CHECK (
        delivery_status IN ('SUCCESS','FAILED','RETRYING','ABANDONED')
    )
);

CREATE INDEX idx_ssdl_stream
    ON bauth.ses_ssf_delivery_log (stream_id, delivery_status, delivered_at DESC);
CREATE INDEX idx_ssdl_failing
    ON bauth.ses_ssf_delivery_log (stream_id)
    WHERE delivery_status IN ('FAILED','RETRYING');
```

### Propósito

`ses_ssf_stream` define **qué receivers** reciben eventos CAEP de bAuth y qué tipos de eventos
les interesan. Hoy esta configuración vive en TOML/ENV: no es editable en runtime y no tiene
historial de cambios. Con esta tabla el admin agrega un nuevo receiver (ej. un SIEM nuevo) sin
recompilar ni reiniciar el daemon.

`auth_vault_path` = ruta en Vault del token de autenticación para ese receiver. El daemon lo
lee de Vault al establecer la conexión — el token nunca se almacena en esta tabla.

`ses_ssf_delivery_log` registra cada intento de entrega: si falló, cuántas veces se reintentó,
y el código HTTP. Permite al admin saber si un receiver está caído y cuántos eventos se
acumularon sin entregar.

### Frontend — cómo se maneja

**Módulo Administración → Streams SSF:**

1. **Lista de streams activos:** tabla con nombre del receiver, endpoint, método, tipos de eventos, estado, última entrega, conteo de errores. Badge rojo si `error_count > 10` en las últimas 24h.
2. **Formulario de nuevo stream:** `receiver_name`, `receiver_endpoint` (URL), `delivery_method` (radio PUSH/POLL), `event_types` (multi-select de 6 tipos), `auth_vault_path`. Al guardar → INSERT en T-192.
3. **Detalle de stream → Log de entregas:** tabla T-193 filtrada por stream, con timestamps, status, código HTTP, reintentos. Botón "Pausar stream" → UPDATE `status='PAUSED'`.

### Cuándo y cómo se alimenta

| Tabla | Evento | Actor |
|-------|--------|-------|
| `ses_ssf_stream` | Admin configura nuevo receiver | Frontend Desktop |
| `ses_ssf_stream` | Daemon detecta error sostenido | Daemon (UPDATE `status='ERROR'`, `error_count++`) |
| `ses_ssf_delivery_log` | Daemon intenta entregar evento CAEP | Daemon bAuth (INSERT por cada intento) |

---

## Orden de implementación recomendado

### Fase 1 — Motor funcional (sin esto no hay ZSP ni compliance básico)
```
G-21 idn_roles_nhi_identity     — entidad raíz; otras tablas dependen de esta
G-17 pam_jit_request            — workflow ZSP; bloquea todo el modelo PAM
G-20 pam_breakglass_activation  — completa el ciclo PAM de emergencia
G-13 aud_certification_*        — evidencia ISO 27001 A.8.2
```

### Fase 2 — Operación segura (eliminan puntos ciegos)
```
G-25 ses_caep_event_log         — forensia de revocaciones CAEP
G-16 ses_session_log            — forensia post-incidente
G-22 idn_nhi_lifecycle_*        — controla acumulación NHI
G-19 pam_session_record         — auditoría de ejercicio de privilegio
G-14 privilege_exception_record — gobernanza de bypasses SoD
```

### Fase 3 — Madurez L3→L4
```
G-15 ses_risk_policy                — política adaptativa editable en runtime
G-18 pam_credential_ref         — inventario de credenciales privilegiadas
G-23 pam_nhi_secret_ref         — rotación automática de secretos NHI
G-26 ses_ssf_stream + ses_ssf_delivery_log — gestión SSF en BD
G-24 idn_roles_nhi_agent_identity         — REQUIERE decisión HITL sobre herencia de permisos
```

---

---

## Historial de versiones

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 2.0.0 | 2026-07-21 | Creación — 14 gaps con DDL, nomenclatura A.65.02, uuidv7, documentación operacional |
| 2.1.0 | 2026-07-21 | Corregido estado de 5 gaps funcionales: G-13, G-15, G-17, G-20, G-21 revertidos de DISEÑO APROBADO a EN TRABAJO; agregadas secciones de implementación pendiente con ítems concretos por gap |
| 2.2.0 | 2026-07-21 | G-17 — decisión de escalamiento aprobada: aprobación secuencial multi-nivel. T-182 rediseñado (elimina `approver_id`, agrega `niveles_requeridos`). Nueva T-182b `pam_jit_approval`. Tabla A.65.02 actualizada (67 tablas). |
| 2.3.0 | 2026-07-21 | G-17 — documentación de uso completa: 4 métodos JSON-RPC con payloads, lógica del daemon paso a paso, queries SQL exactas, módulos Rust. |
| 2.4.0 | 2026-07-21 | G-13, G-15, G-20, G-21 — mismo nivel de documentación aplicado: métodos JSON-RPC con request/response/errores, lógica del daemon, queries SQL con índices usados, módulos Rust, jobs de fondo, seeds. |
| 2.6.0 | 2026-07-21 | G-13, G-15, G-17, G-20, G-21 — reclasificados de EN TRABAJO a PENDIENTE POST-DDL. Criterio: gobernanza enterprise que requiere DDL base completa y código operativo antes de ser implementada. No bloquean el desarrollo actual. |
| 2.5.0 | 2026-07-21 | G-20 — 3 decisiones de diseño aprobadas y documentadas: D1 (columna `grant_type` en T-170 + trigger de validación), D2 (tiers elegibles SU/EMERGENCY con justificación normativa NIST AC-2(2)), D3 (máx. 2 grants BREAKGLASS por tenant). DDL T-185 rediseñado con flujo PENDING_APPROVAL→ACTIVE (dual control NIST AC-5), campos `approver_id`/`approved_at`/`auth_method`/`auth_loa`, 4 constraints, 3 índices. Nuevos métodos JSON-RPC `bauth.pam.breakglass.solicitar` y `bauth.pam.breakglass.aprobar`. RolTemplate B4 completo para rol EMERGENCY (3 métodos, alternativeMethods con `loa_change`, `requires_approval`, `alert_on_use`). Tabla de 9 átomos D08/D09/D11 requeridos. 2 jobs de fondo (expiración TTL 4h + alerta revisión). |

**Versión actual:** 2.6.0 · **Fecha:** 2026-07-21
**Tablas propuestas:** T-177..T-193 + T-182b (18 tablas) · **PK:** `uuidv7()` en todas
**Estado:** 9 gaps DISEÑO APROBADO · 5 gaps PENDIENTE POST-DDL (G-13, G-15, G-17, G-20, G-21) · 0 gaps EN TRABAJO · 0 gaps BLOQUEADO-HITL activos

> **Criterio PENDIENTE POST-DDL:** estos gaps contienen gobernanza enterprise (IGA, PAM avanzado,
> NHI, CAEP) que requiere que la DDL base esté completa, el árbol de RolTemplate operativo y
> el código reparado antes de ser abordados. No bloquean el desarrollo actual. Se retoman
> cuando bAuth esté en marcha.
**Referencia:** `GAPS-DDL-PRIVILEGIOS.md` G-01..G-12 · grupos de tabla: A.65.02
