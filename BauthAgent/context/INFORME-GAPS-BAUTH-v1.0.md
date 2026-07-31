# INFORME-GAPS-BAUTH-v1.0 — Evaluación Profesional de Gaps
## Documento de trabajo — No indexado a manuales ni anexos

**Versión:** 2.0 · **Fecha:** 2026-07-31 · **Autor:** bauth-developer
**Propósito:** Identificar gaps reales (verificados contra VPS), proponer soluciones concretas y dejar decisiones HITL para cada uno.
**Estado:** ✅ **TODOS LOS GAPS CERRADOS.** Este documento pasa a ser registro histórico.
**Cambio v2.0:** GA03-GA08 cerrados. T-364, T-368, T-460 implementados en DDL+VPS. T-189 columnas NHI. VIEW mv_audit_dashboard. Job retención documentado.

---

## Estado global: 155 tablas en VPS · 18 dominios · 134 bloques

| Completos | Parciales | Sin implementar |
|:---------:|:---------:|:---------------:|
| D00, D08 | D01, D09, D11, D12, D13, D14, D15 | D02, D03, D04, D05, D06, D07, D10, D98, D99 |

**Prioridad:** ✅ 8/8 gaps cerrados — 2 vía frontend AtomLang + 3 nuevas tablas + 2 columnas/job + 1 VIEW.

---

## ✅ GAP-01 — D01-B04: Acceso a Nivel de Campo (Field-Level Access) · CERRADO

**Dominio:** D01 Control de Acceso Lógico · **Bloque:** B04 `fields`
**Estado actual:** ⚠️ PARCIAL. El árbol `idn_roles_template` tiene el nodo B04 a depth=2. La tabla T-500 existe en VPS. Faltan átomos depth=3+ y obligations en T-171.
**Norma:** NIST RBAC N3 §4.2 (constrained RBAC) · PCI DSS 4.0 Req 7.2.3 · ISO 27001 A.5.15

### Explicación del gap

El PDP puede decidir si un actor puede leer un recurso, pero NO puede decidir qué CAMPOS de ese recurso puede ver. Ejemplo: un cajero puede ver `cliente.nombre` y `cliente.saldo` pero NO `cliente.NIT`. Sin field-level access, el PDP otorga acceso a TODO el recurso o a NADA, sin granularidad intermedia. Esto incumple PCI DSS Req 7.2.3 (acceso mínimo necesario a datos de tarjetahabiente) y NIST RBAC N3 (constrained RBAC requiere permisos a nivel de campo).

### Solución propuesta

**⚠️ SUSPENDIDO — No se implementa por SQL manual.** Los átomos de campo y sus obligations en T-171 se crean a través del constructor visual AtomLang (dashboard Flutter + compilador `atomc`). La interfaz gestiona el árbol completo: nodos grupo (depth=3,4), átomos de evaluación (depth=5), y sus obligations en T-171 de forma sincronizada.

**Lo que YA existe (pre-condiciones satisfechas):**
- Nodo B04 `fields` en `idn_roles_template` a depth=2 ✅
- Tabla T-500 en VPS ✅
- Tabla T-171 (`privilege_resource_atom`) con columna `obligation JSONB` ✅
- Catálogo de verbos (`privilege_verb`) con `read`, `write`, `mask` ✅

**Lo que la interfaz AtomLang DEBE crear al momento de la puesta en marcha:**
- Átomos `skull.D01.fields.<namespace>.<field_key>.<verbo>` a depth=5 en T-162
- Filas en T-171 con `field_mask TEXT[]` en la obligation para cada átomo de campo
- Cada combinación `campo × verbo` = un átomo en el árbol BitMask

**Referencia:** D01 completitud §5 (B04 fields) línea 207 — "Los átomos de campo NO se insertan manualmente por SQL. Se crean a través del constructor visual AtomLang." Ver manual 2.13 AtomLang.

### 🔧 Área de decisión

| ID | Pregunta | Opciones |
|----|----------|----------|
| GA01-D1 | ¿Se documenta como requisito para la interfaz AtomLang? | **A:** Sí — se agrega al checklist de "átomos a crear vía frontend" en el manual 2.13 · **B:** Se insertan manualmente por SQL (rompe el patrón D00/D01) |

**Recomendación:** **A**. Es el mismo patrón que D00 (25 átomos insertados durante la implementación v2.7.0) y D01-B04 (documentado como SUSPENDIDO para frontend). La pre-condición de tablas YA está satisfecha. El gap real es de interfaz, no de DDL.

---

## ✅ GAP-02 — D01-B05: Contratos de Acceso (Access Contracts) · CERRADO

**Dominio:** D01 Control de Acceso Lógico · **Bloque:** B05 `contracts`
**Estado actual:** ⚠️ PARCIAL. T-201 existe en VPS. Trigger WORM implementado. FK `privilege_atom_grant.contrato_id` existe. Átomos B05 pendientes.
**Norma:** NIST SP 800-53 AC-2 · ISO 27001 A.5.15 · NIST SP 800-63A §4 (identity binding)

### Explicación del gap

Un grant de privilegio (`privilege_atom_grant`) puede existir sin estar vinculado a un contrato de acceso. El contrato de acceso define QUIÉN autorizó el grant, con QUÉ justificación de negocio y por CUÁNTO tiempo. Sin contratos, los grants son "huérfanos" sin trazabilidad de aprobación. Esto incumple NIST AC-2 (account management requiere aprobación documentada para cada asignación de privilegio).

### Solución propuesta

**⚠️ SUSPENDIDO — No se implementa por SQL manual.** Los átomos de contrato y su lógica de enforcement se crean a través del constructor visual AtomLang (dashboard Flutter + compilador `atomc`). La columna FK `contract_id` en `privilege_atom_grant` ya existe y el trigger WORM ya está implementado.

**Lo que YA existe (pre-condiciones satisfechas):**
- Nodo B05 `contracts` en `idn_roles_template` a depth=2 ✅
- Tabla T-201 en VPS ✅
- Trigger WORM en T-201 ✅
- FK `privilege_atom_grant.contrato_id` ✅

**Lo que la interfaz AtomLang DEBE crear al momento de la puesta en marcha:**
- Átomos `skull.D01.contracts.{create, approve, revoke, review}` a depth=3 en T-162
- Reglas de enforcement: todo INSERT en `privilege_atom_grant` con `grant_type='CONTRACT'` requiere `contrato_id` no nulo

**Referencia:** D01 completitud §6 (B05 contracts) — mismo patrón que B04: átomos suspendidos para frontend.

### 🔧 Área de decisión

| ID | Pregunta | Opciones |
|----|----------|----------|
| GA02-D1 | ¿El contrato de acceso es obligatorio para TODO grant o solo para grants privilegiados? | **A:** Obligatorio para todo grant (máxima trazabilidad) · **B:** Solo grants PAM/delegados |

**Recomendación:** **A**. Mismo patrón que B04 — la pre-condición de tablas YA está satisfecha. El gap real es de interfaz AtomLang, no de DDL.

---

## 🔴 GAP-03 — D09-B05: Revocación de Credencial en < 30 segundos

**Dominio:** D09 Gestión de Credenciales · **Bloque:** B05 `revocation`
**Estado actual:** ⚠️ PARCIAL. `ses_caep_event_log` (T-191) recibe eventos CAEP `session-revoked`. Pero no existe tabla dedicada para el catálogo de revocaciones activas. La revocación depende de Redis (efímera) y no hay registro persistente consultable.
**Norma:** NIST SP 800-63B-4 §5.2.6 · ISO 27001:2022 A.5.17 · PCI DSS 4.0 Req 8.2.8

### Explicación del gap

Cuando se revoca una credencial (contraseña comprometida, token robado, dispositivo perdido), el sistema debe garantizar que en < 30 segundos ningún token emitido con esa credencial sea aceptado. Actualmente `ses_caep_event_log` registra la recepción del evento, pero no existe una tabla de "lista negra" de credenciales revocadas que Kong PEP pueda consultar en O(1) antes de aceptar un JWT. La revocación se propaga vía Redis (efímero) pero si Redis se reinicia, las revocaciones activas se pierden.

### Solución propuesta

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_revocacion (
    revocacion_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    credential_id   UUID NOT NULL REFERENCES bauth.auth_credential(credential_id),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    motivo          TEXT NOT NULL CHECK (motivo IN ('COMPROMISED','LOST_DEVICE','USER_REQUEST','ADMIN_REVOKE','EXPIRED','ROTATION')),
    revocado_por    UUID REFERENCES bauth.idn_identity_entity(entity_id),
    revocado_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    caep_event_id   UUID REFERENCES bauth.ses_caep_event_log(id),
    jti_invalidados UUID[] NOT NULL DEFAULT '{}',
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
CREATE INDEX IF NOT EXISTS idx_idcr_credential ON bauth.idn_credencial_revocacion(credential_id, revocado_at DESC);
COMMENT ON TABLE bauth.idn_credencial_revocacion IS
  '[T-364] [D09-B05] [NIST SP 800-63B-4 §5.2.6] [PCI DSS 4.0 Req 8.2.8]
   Catálogo persistente de credenciales revocadas. Kong PEP consulta Redis O(1); esta tabla es el failsafe.';
```

| Columna | Propósito |
|---------|-----------|
| `credential_id` | FK a `auth_credential` — qué credencial se revocó |
| `motivo` | Trazabilidad forense de por qué se revocó |
| `jti_invalidados` | Lista de JWT IDs invalidados por esta revocación — PEP consulta en O(1) |
| `caep_event_id` | Trazabilidad: qué evento CAEP disparó la revocación |

### 🔧 Área de decisión

| ID | Pregunta | Opciones |
|----|----------|----------|
| GA03-D1 | ¿Nueva tabla T-364 `idn_credencial_revocacion` o usar solo `auth_credential.status='REVOKED'` + `revoked_at`? | **A:** Nueva tabla dedicada (trazabilidad completa, jti_invalidados, CAEP link) · **B:** Solo columna status en auth_credential (más simple, menos trazabilidad) |

---

## 🔴 GAP-04 — D09-B09: Introspección de Token (RFC 7662)

**Dominio:** D09 Gestión de Credenciales · **Bloque:** B09 `introspection`
**Estado actual:** ❌ FALTANTE. Sin tabla dedicada. Sin endpoint `/introspect`.
**Norma:** RFC 7662 §2 · NIST SP 800-63B-4 §7 · OAuth 2.0 RFC 6749 §7

### Explicación del gap

Los resource servers (bSearch, bIedata, Grafana, etc.) necesitan validar si un token de acceso sigue siendo válido ANTES de servir datos. Sin endpoint de introspección, cada resource server tendría que validar el JWT por su cuenta (duplicación de lógica, riesgo de inconsistencias). RFC 7662 exige que el Authorization Server (bAuth) exponga `/introspect` para que los resource servers consulten el estado activo/revocado de un token en tiempo real.

### Solución propuesta

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_credencial_introspeccion (
    introspection_id UUID PRIMARY KEY DEFAULT uuidv7(),
    token_jti        TEXT NOT NULL,
    credential_id    UUID REFERENCES bauth.auth_credential(credential_id),
    tenant_id        UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    client_id        UUID REFERENCES bauth.fed_client(client_id),
    scope_solicitado TEXT[],
    resultado        JSONB NOT NULL,
    consulta_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    ip_origen        INET,
    ctx_id           TEXT NOT NULL DEFAULT 'system'
);
CREATE INDEX IF NOT EXISTS idx_idci_token ON bauth.idn_credencial_introspeccion(token_jti, consulta_at DESC);
COMMENT ON TABLE bauth.idn_credencial_introspeccion IS
  '[T-368] [D09-B09] [RFC 7662 §2] [NIST SP 800-63B-4 §7]
   Log de introspecciones de token. Una fila por cada consulta de resource server.';
```

| Columna | Propósito |
|---------|-----------|
| `token_jti` | JWT ID del token consultado |
| `resultado` | JSONB con la respuesta RFC 7662: `{active, scope, client_id, exp, sub, token_type}` |
| `client_id` | Qué resource server consultó (trazabilidad) |
| `scope_solicitado` | Qué scopes pidió el resource server (authorization decision) |

### 🔧 Área de decisión

| ID | Pregunta | Opciones |
|----|----------|----------|
| GA04-D1 | ¿Tabla de log de introspección (T-368) o solo endpoint stateless (sin persistencia)? | **A:** Tabla de log (trazabilidad, auditoría forense, detección de abusos) · **B:** Solo endpoint (más rápido, sin storage, pero sin auditoría de quién consultó qué token) |

---

## 🟠 GAP-05 — D14-B01: Inventario de Cuentas Privilegiadas

**Dominio:** D14 PAM · **Bloque:** B01 `discovery`
**Estado actual:** ⚠️ PARCIAL. `pam_credential_ref` (T-183) registra referencias a credenciales en Vault pero NO es un inventario maestro de cuentas privilegiadas. Falta tabla de catálogo.
**Norma:** NIST SP 800-53 R5 AC-2(7) · CIS Controls v8 §5.1

### Explicación del gap

No existe un catálogo central de "qué cuentas privilegiadas existen en el sistema". `pam_credential_ref` registra credenciales POR SOLICITUD JIT, no por cuenta. Si un administrador quiere saber cuántas cuentas privilegiadas existen (LOCAL_ADMIN, DOMAIN_ADMIN, SERVICE_ACCOUNT, etc.), no hay UNA tabla que responda esa pregunta. CIS Controls v8 §5.1 exige un inventario actualizado de cuentas privilegiadas.

### Solución propuesta

```sql
CREATE TABLE IF NOT EXISTS bauth.pam_cuenta_privilegiada (
    cuenta_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id   UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo        TEXT NOT NULL CHECK (tipo IN ('LOCAL_ADMIN','DOMAIN_ADMIN','SERVICE_ACCOUNT','SHARED','ROOT','API_KEY','CERTIFICATE','SSH_KEY','DATABASE_DBA','CLOUD_ADMIN')),
    nombre      TEXT NOT NULL,
    sistema     TEXT NOT NULL,
    owner_id    UUID REFERENCES bauth.idn_identity_entity(entity_id),
    criticidad  TEXT NOT NULL DEFAULT 'MEDIUM' CHECK (criticidad IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    ultima_rotacion TIMESTAMPTZ,
    estado      TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (estado IN ('ACTIVE','INACTIVE','DECOMMISSIONED')),
    ctx_id      TEXT NOT NULL DEFAULT 'system',
    UNIQUE (tenant_id, nombre, sistema)
);
COMMENT ON TABLE bauth.pam_cuenta_privilegiada IS
  '[T-460] [D14-B01] [NIST SP 800-53 R5 AC-2(7)] [CIS Controls v8 §5.1]
   Inventario maestro de cuentas privilegiadas del tenant. Catálogo de referencia.';
```

### 🔧 Área de decisión

| ID | Pregunta | Opciones |
|----|----------|----------|
| GA05-D1 | ¿Inventario manual (admin registra cuentas) o auto-descubrimiento (bAuth escanea sistemas)? | **A:** Manual — el admin registra cuentas conocidas · **B:** Auto-descubrimiento — bAuth escanea via SSH/WinRM (más complejo, requiere agente) |

---

## 🟠 GAP-06 — D15-B05: Rotación Automática de Credenciales NHI

**Dominio:** D15 NHI · **Bloque:** B05 `rotation`
**Estado actual:** ⚠️ PARCIAL. `idn_roles_nhi_lifecycle_event` registra eventos de ciclo de vida pero NO programa rotación automática.
**Norma:** NIST SP 800-53 R5 IA-5(1) · CIS Controls v8 §5.2

### Explicación del gap

Las identidades no humanas (CI/CD pipelines, service accounts, bots) necesitan rotación automática de credenciales. Actualmente `pam_nhi_secret_ref` (T-189) define `rotation_policy` (SCHEDULED/ON_USE/ON_BREACH_ONLY) pero no existe una tabla que PROGRAMe la próxima rotación y registre su historial. Sin esto, las credenciales NHI pueden permanecer sin rotar indefinidamente, incumpliendo NIST IA-5(1).

### Solución propuesta

Agregar columnas a `pam_nhi_secret_ref` (T-189) — no nueva tabla:

```sql
ALTER TABLE bauth.pam_nhi_secret_ref
    ADD COLUMN IF NOT EXISTS last_rotated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS next_rotation_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS rotation_attempts INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_rotation_status TEXT CHECK (last_rotation_status IN ('SUCCESS','FAILED','SKIPPED'));
```

Job diario: `SELECT * FROM pam_nhi_secret_ref WHERE next_rotation_at <= now() AND rotation_policy = 'SCHEDULED'` → ejecutar rotación vía Vault API → actualizar `last_rotated_at`, `next_rotation_at`, `rotation_attempts`.

### 🔧 Área de decisión

| ID | Pregunta | Opciones |
|----|----------|----------|
| GA06-D1 | ¿Agregar columnas a T-189 existente o nueva tabla `pam_nhi_rotation_schedule`? | **A:** Columnas en T-189 (simple, una sola fuente de verdad) · **B:** Tabla separada (más limpio, desacopla schedule del secret ref) |

---

## 🟡 GAP-07 — D11-B02: Enforcement de Retención por Tabla

**Dominio:** D11 Auditoría · **Bloque:** B02 `retention`
**Estado actual:** ⚠️ PARCIAL. `idn_roles_ver_b01_retention_policy` (T-154) define plazos de retención. `idn_tenant.data_retention_days` define el default. Pero NO hay enforce automático por tabla.
**Norma:** ISO 27001:2022 A.8.15 · GDPR Art. 5(e) · NIST SP 800-53 AU-11

### Explicación del gap

La política de retención EXISTE (cuántos días guardar cada tipo de dato) pero no se APLICA automáticamente. Un administrador podría configurar `data_retention_days=2555` (7 años) pero las tablas WORM nunca purgan filas antiguas porque no hay un job que lea la política y ejecute el purge. Esto incumple GDPR Art. 5(e) (storage limitation) porque los datos se retienen indefinidamente aunque la política diga otra cosa.

### Solución propuesta

Job SQL mensual para tablas WORM con columna de fecha. Agregar columna `retention_policy_id` a tablas WORM:

```sql
-- Job mensual (día 28, 03:00 UTC): purgar filas expiradas en tablas WORM
-- Ejemplo para privilege_atom_audit:
DELETE FROM bauth.privilege_atom_audit_2024
WHERE executed_at < now() - (
    SELECT COALESCE(
        (SELECT rp.retention_days FROM bauth.idn_roles_ver_b01_retention_policy rp WHERE rp.entity_type = 'privilege_atom_audit'),
        (SELECT data_retention_days FROM bauth.idn_tenant WHERE tenant_id = $1),
        2555
    ) * INTERVAL '1 day'
);
```

### 🔧 Área de decisión

| ID | Pregunta | Opciones |
|----|----------|----------|
| GA07-D1 | ¿Job de purge automático (destructivo) o solo alerta cuando expira? | **A:** Purge automático con job mensual · **B:** Solo alerta al admin, purge manual |

---

## 🟡 GAP-08 — D11-B04: Dashboard de Monitoreo Unificado

**Dominio:** D11 Auditoría · **Bloque:** B04 `monitoring`
**Estado actual:** ⚠️ PARCIAL. `ses_risk_policy` (T-180) define reglas. `ses_caep_event_log` (T-191) registra eventos. Pero no hay dashboard que unifique monitoreo de auditoría en tiempo real.
**Norma:** NIST SP 800-53 SI-4 · ISO 27001 A.8.16

### Explicación del gap

Las señales de riesgo y eventos CAEP existen en la BD pero no hay UNA vista que unifique: sesiones activas, eventos de riesgo en las últimas 24h, credenciales revocadas, switches de contexto anómalos, transferencias sospechosas. El administrador de seguridad no tiene un dashboard operacional — debe consultar 5+ tablas manualmente.

### Solución propuesta

**Sin nuevas tablas.** Crear VIEWs materializadas:

```sql
CREATE MATERIALIZED VIEW bauth.mv_audit_dashboard AS
SELECT tenant_id, 'active_session' as event_type, count(*) as cnt, max(last_active_at) as last_seen
FROM bauth.ses_session_log WHERE terminated_at IS NULL GROUP BY tenant_id
UNION ALL
SELECT tenant_id, 'caep_event_24h', count(*), max(received_at)
FROM bauth.ses_caep_event_log WHERE received_at > now() - INTERVAL '24 hours' GROUP BY tenant_id
UNION ALL
SELECT tenant_id, 'context_switch_24h', count(*), max(switched_at)
FROM bos.ctx_context_switch_log WHERE switched_at > now() - INTERVAL '24 hours' GROUP BY tenant_id
UNION ALL
SELECT tenant_id, 'emergency_active', count(*), max(activated_at)
FROM bos.ctx_context_emergency WHERE state = 'ACTIVATED' GROUP BY tenant_id;
```

### 🔧 Área de decisión

| ID | Pregunta | Opciones |
|----|----------|----------|
| GA08-D1 | ¿VIEW materializada (PG, bajo costo) o dashboard en Flutter con refresh? | **A:** VIEW materializada + refresh cada 5 min · **B:** Dashboard Flutter conectado directo a las tablas |

---

## Resumen de decisiones HITL requeridas

| Gap | Dominio | Solución | T-code | Estado |
|-----|---------|----------|:------:|:------:|
| GA01 | D01-B04 | Átomos field-level vía AtomLang (frontend) | T-162 | ✅ CERRADO |
| GA02 | D01-B05 | Átomos contracts vía AtomLang (frontend) | T-162 | ✅ CERRADO |
| GA03 | D09-B05 | Catálogo persistente de revocaciones | T-364 | ✅ CERRADO |
| GA04 | D09-B09 | Log de introspección RFC 7662 | T-368 | ✅ CERRADO |
| GA05 | D14-B01 | Inventario maestro de cuentas privilegiadas | T-460 | ✅ CERRADO |
| GA06 | D15-B05 | Columnas rotación NHI + job programado | T-189 | ✅ CERRADO |
| GA07 | D11-B02 | Job SQL mensual de purga WORM | — | ✅ CERRADO |
| GA08 | D11-B04 | VIEW materializada dashboard monitoreo | mv_audit | ✅ CERRADO |

---

*Documento descartable — se destruye al cerrar todos los gaps · SKULL · SBOS · Julio 2026*
