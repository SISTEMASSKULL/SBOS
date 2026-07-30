# Anexo A.65.01 — Guía de Desarrollo: Tablas del Esquema bAuth
## Qué tabla tocar, cuándo, cómo y por qué — manual práctico para el desarrollador

**Tipo:** ANEXO — guía de desarrollo práctico
**Versión:** 2.9.0 · **Fecha:** 2026-07-19
**Respalda a:** MANUAL-AUDITORIA-TRAZABILIDAD (5.01) · MANUAL-MOTOR-VERSIONADO (1.13) · A.65 (Inventario DDL)
**Audiencia:** desarrolladores bAuth que escriben código que toca datos de identidad, roles o políticas
**Normas base:** ISO 27001:2022 A.8.15/A.5.33/A.8.9/A.8.32 · NIST AU-3/AU-11/CM-3/AC-5 · PCI DSS 10.x · SOX §404 · SemVer 2.0.0
**Fuentes de diseño:** 5.01 §2/§3/§7 · 1.13 §5/§6/§7/§8/§9/§10 · A.65 (todas las secciones)

---

## Tabla de contenidos

**PARTE I — Fundamentos de trazabilidad y versionado**

1. [El axioma — leer esto antes de tocar cualquier tabla](#1-el-axioma)
2. [Las dos mitades de la trazabilidad](#2-las-dos-mitades-de-la-trazabilidad)
3. [Las 4 clases de información — a cuál pertenece cada tabla](#3-las-4-clases-de-información)
4. [Cuándo escribir en cada clase](#4-cuándo-escribir-en-cada-clase)
5. [La historia del árbol RolTemplate — flujo completo](#5-la-historia-del-árbol-roltemplate)
6. [La historia de las identidades UserTemplate — flujo completo](#6-la-historia-del-usertemplate)
7. [Emitir un evento de auditoría — el patrón correcto](#7-emitir-un-evento-de-auditoría)
8. [El cambio de una definición gobernada — la transición atómica](#8-el-cambio-de-una-definición-gobernada)
9. [Cambios MAJOR — el flujo de propuesta y quórum](#9-cambios-major)
10. [Reglas de retención — qué se guarda cuánto tiempo](#10-reglas-de-retención)
11. [Tablas que NO existen más — las 48 ELIMINADAS](#11-tablas-eliminadas)
12. [Errores comunes del desarrollador](#12-errores-comunes)
13. [Mapa de relaciones entre tablas de trazabilidad](#13-mapa-de-relaciones)
14. [Referencias](#14-referencias)

**PARTE II — Guía por grupo de tablas del A.62**

15. [El principio rector — árbol vs. tabla relacional](#15-el-principio-rector)
16. [GLOBAL — Catálogos ISO](#16-global)
17. [IDENTIDAD — Tenant y sus satélites](#17-identidad)
18. [ROLES — Árbol jerárquico y tablas satélite](#18-roles)
19. [USUARIOS — UserTemplate y delegaciones](#19-usuarios)
20. [PRIVILEGIOS — Átomos, BitMask y evaluaciones](#20-privilegios)
21. [SOD — Por qué estas tablas no existen](#21-sod)
22. [AUTENTICACIÓN — Config, catálogo y logs operacionales](#22-autenticación)
23. [SESIÓN — Contextos activos y CAEP](#23-sesión)
24. [IDENTIDAD D00 — Catálogo universal de entidades](#24-identidad-d00--catálogo-universal)
25. [FINANCIERO — Instancias de aprobación y operaciones](#25-financiero)
26. [FÍSICO — Dispositivos, zonas y controladores](#26-físico)
27. [GEOLOCALIZACIÓN — Logs de ubicación y evaluación](#27-geolocalización)
28. [RED/ZTNA — Dispositivos de red](#28-redztna)
29. [AUDITORÍA — C3 (referencia a §§1-14)](#29-auditoría)
30. [BLOCKCHAIN — Anclas Merkle y reconciliación](#30-blockchain)
31. [SEGURIDAD — Inventario y rotación de claves](#31-seguridad)
32. [DISPOSITIVOS — FIDO2, QR, heartbeat, push](#32-dispositivos)
33. [ZONAS-UI — Por qué estas tablas no existen](#33-zonas-ui)
34. [CALENDARIO — Infraestructura bcalendar](#34-calendario)
35. [OIDC/IDP — Clientes OAuth2](#35-oidcidp)
36. [VERSIONADO — MVU (referencia a §§5-10)](#36-versionado)
37. [Misceláneos — SYNC, CONFIG, EMERGENCIA, VISITANTES, LEGADO, VARIOS](#37-misceláneos)
38. [Historial](#38-historial)

---

# PARTE I — Fundamentos de trazabilidad y versionado

## 1. El axioma

> **La trazabilidad y la auditoría son el componente principal del sistema — todos los demás
> conceptos giran alrededor de ellas. Ninguna decisión de implementación puede debilitarlas.**
> — Doctrina del proyecto, 2026-07-11 (5.01 §2.1)

Antes de escribir código que toque un dato de identidad, rol o política, el desarrollador responde DOS preguntas:

| Pregunta | Si la respuesta es SÍ |
|----------|----------------------|
| ¿Esto define comportamiento de acceso o cambia por decisión humana gobernada? | → Está en **clase C1** → su cambio pasa por el **Motor de Versionado Universal** |
| ¿Esto es un evento que ocurrió en el sistema? | → Está en **clase C3** → se escribe en **`aud_event`** (o `privilege_atom_audit`) |

**Regla de oro:** nunca modificar una entidad C1 directamente con `UPDATE`. Siempre a través del motor de versionado (`bauth.version.propose`). Nunca omitir el evento `aud_event` después de una operación relevante.

---

## 2. Las dos mitades de la trazabilidad

El libro mayor de la identidad tiene dos granos. **Ambos son obligatorios:**

```
PRIMERA MITAD — Auditoría de eventos (C3)          SEGUNDA MITAD — Versionado de definiciones (C2)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Pregunta: «¿QUÉ OCURRIÓ?»                          Pregunta: «¿CÓMO ERA Y CÓMO QUEDÓ?»
Manual: 5.01 Auditoría                              Manual: 1.13 Motor de Versionado Universal
Tabla: bauth.aud_event (24 col, 30 tipos)           Tabla: bauth.ver_history (delta + snapshot)
       + privilege_atom_audit                                + ver_proposal (MAJOR pendiente)

Ej: «alguien cambió el rol X el martes»             Ej: «¿qué decía el rol X el lunes?»
    → aud_event EVENT_TYPE=ROLE_MODIFY                   → ver_history as-of '2026-07-14'

Sin C3 no hay responsables.                         Sin C2 no hay estados históricos.
Juntas: el auditor puede reconstruir TODO.
```

**Consecuencia en código:** toda operación de escritura que modifica un dato normado produce DOS inserciones: una en `ver_history` (el estado que se cierra) y una en `aud_event` (el evento). El paso 7 de la transición atómica del MVU (1.13 §9.3) las hace en la misma transacción.

---

## 3. Las 4 clases de información

Toda tabla del esquema `bauth` pertenece a exactamente una clase. El tratamiento depende de la clase:

| Clase | ¿Qué es? | Tratamiento | Tablas clave |
|-------|----------|-------------|--------------|
| **C1** Definiciones gobernadas | Define quién accede a qué; cambia por decisión humana aprobada | Motor de Versionado: toda escritura pasa por `bauth.version.propose` | `idn_roles_rol_hierarchical`, `idn_user_template`, `idn_tenant`, `privilege_atom`, `ath_method`, `idn_roles_rol_tier` |
| **C2** Historia de versiones | El pasado de C1; generado exclusivamente por el MVU, nunca por código directo | WORM + hash-chain; REVOKE UPDATE/DELETE | `ver_history`, `ver_proposal`, `ver_retention_schedule`, `ver_template_changelog` |
| **C3** Evidencia de auditoría | Eventos inmutables de lo que ocurrió en el sistema | Append-only; hash-chain propia; REVOKE UPDATE/DELETE | `aud_event`, `privilege_atom_audit`, `ath_login_attempt` |
| **C4** Estado efímero | Runtime sin valor histórico propio; su rastro relevante ya está en C3 | TTL parametrizado; puede reemplazarse sin versionar | `ses_context`, `ath_recovery_challenge`, `qr_challenge_registry` |

**Criterio de clasificación (tres preguntas):**
1. ¿Define comportamiento de acceso? → sí = C1
2. ¿Cambia por decisión humana gobernada? → sí = C1
3. ¿El auditor preguntará «¿cómo era en la fecha X?»? → sí = C1

Tres sí = C1. La historia de C1 va a C2. Los eventos de C1/C2 van a C3. El runtime sin historia propia es C4.

---

## 4. Cuándo escribir en cada clase

### 4.1 C1 — Modificar una definición gobernada

**NUNCA así:**
```sql
-- ❌ PROHIBIDO — viola el MVU, rompe la trazabilidad
UPDATE bauth.idn_roles_rol_hierarchical
SET template_data = '...'
WHERE id = :rol_id;
```

**SIEMPRE así — a través del motor:**
```
// En Rust — el handler llama al motor, nunca al SQL directo
bauth.version.propose {
    entity: "idn_roles_rol_hierarchical",
    id: rol_id,
    changes: { "d3.limits.max_single": 50000 },
    change_type: "MINOR",   // el motor puede exigir MAJOR si toca B4/B6/B8
    reason: "ajuste de límite financiero aprobado en reunión 2026-07-15"
}
```

El motor:
1. Clasifica el cambio → determina el bump SemVer real (no el declarado si es menor al exigido)
2. Si MAJOR → bloquea, crea `ver_proposal`, notifica al quórum del B3
3. Si MINOR/PATCH → aplica la transición atómica (9 pasos — 1.13 §9.3)
4. En ambos casos emite `aud_event` con `iso_control[]` según los bloques tocados

### 4.2 C2 — Leer historia de una definición

```sql
-- ¿Cómo era el rol VENT-01 el 14 de julio?
SELECT entity_id, version, fields_changed, blocks_touched, standard_ref,
       changed_by, approved_by, change_reason, security_impact
FROM bauth.ver_history
WHERE entity_name = 'idn_roles_rol_hierarchical'
  AND entity_id = :rol_id
  AND sys_period @> '2026-07-14 10:00:00+00'::timestamptz
ORDER BY lower(sys_period) DESC
LIMIT 1;

-- ¿Todos los cambios que tocaron PCI en los últimos 90 días?
SELECT entity_name, entity_id, version, blocks_touched,
       fields_changed, changed_by, lower(sys_period) AS changed_at
FROM bauth.ver_history
WHERE standard_ref @> ARRAY['PCI 7.3.1']
  AND lower(sys_period) >= now() - interval '90 days'
ORDER BY lower(sys_period) DESC;
```

**Regla:** C2 es solo lectura para todo código que no sea el MVU. Escribir en `ver_history` directamente = bug crítico.

### 4.3 C3 — Emitir un evento de auditoría

Ver §7 para el patrón completo. Regla rápida:

```sql
-- El módulo audit/audit_event.rs construye y encadena; los handlers NO escriben directo
INSERT INTO bauth.aud_event (
    ctx_id, event_type, severity, iso_control,
    user_uuid, role_id, tenant_id, empresa_id,
    action, resource_type, resource_id, outcome,
    details, prev_hash, entry_hash, created_at
) VALUES (
    :ctx_id, 'ROLE_MODIFY', 'INFO',
    ARRAY['A.8.15','A.8.9','CM-3'],
    :user_uuid, :role_id, :tenant_id, :empresa_id,
    'UPDATE', 'idn_roles_rol_hierarchical', :rol_id, 'SUCCESS',
    :details_jsonb,
    (SELECT entry_hash FROM bauth.aud_event ORDER BY created_at DESC LIMIT 1 FOR UPDATE),
    sha256(...),
    now()
);
```

**Regla:** nunca omitir `ctx_id` (SBOS-049, NOT NULL). Nunca omitir `iso_control[]`. Nunca escribir desde handlers directamente — siempre a través del constructor central `audit/audit_event.rs`.

### 4.4 C4 — Estado efímero

```sql
-- C4 se puede INSERT/UPDATE/DELETE libremente — no hay historia que proteger
-- Su rastro relevante ya está en C3 (aud_event)
INSERT INTO bauth.ses_context (ctx_id, tenant_id, user_uuid, ...) VALUES (...);
UPDATE bauth.ses_context SET last_seen = now() WHERE ctx_id = :ctx;
DELETE FROM bauth.ses_context WHERE expires_at < now();
```

---

## 5. La historia del árbol RolTemplate

El árbol RolTemplate es **clase C1**. Su historia completa vive en `ver_history`. La tabla `bos_rol_template_history` (T-043) está marcada para eliminar — es la deuda anterior que el MVU reemplaza.

### 5.1 Qué cambia cuándo

| Tipo de cambio en el árbol | Bloques del contrato | Bump SemVer | Flujo |
|----------------------------|----------------------|-------------|-------|
| Cambiar límites financieros (`transaction_limits`) | B8 | **MAJOR** | Propuesta → quórum B3 → transición atómica |
| Cambiar permisos de acceso (`model_access`, `visible_actions`) | B4/B6/B7 | **MAJOR** | Propuesta → quórum B3 |
| Añadir/quitar métodos de autenticación requeridos | B4 | **MAJOR** | Propuesta → quórum B3 |
| Cambiar SoD / roles incompatibles | B12 | **MAJOR** | Propuesta → quórum B3 |
| Cambiar alcance (`scope`), periodo de revisión | B2/B3 | MINOR | Auto-aprobado, aplica directo |
| Cambiar nombre o descripción del rol | B1 descriptivos | PATCH | Auto-aprobado, aplica directo |
| Cambiar `status` del ciclo de vida | — | **SIN VERSIÓN** | Sus propias reglas (1.09 §10) |
| B9/B14 — SAM-128, sync_status (calculados) | — | **SIN VERSIÓN** | Los escribe el motor, no el humano |

### 5.2 La fotografía del árbol — cuándo y dónde

El contrato B1 define `audit.change_history[]` con entradas de delta semántico. La materialización es:

```
DELTA (cada versión):      ver_history.fields_changed   → {"d3.limits.max": {"from":40000,"to":50000}}
FOTOGRAFÍA (anclas MAJOR): ver_history.snapshot          → JSONB completo del árbol en ese momento
                           ver_history.is_anchor = true
```

**Regla:** no almacenar el árbol completo en cada cambio. Solo deltas. La fotografía solo en anclas (cambios MAJOR y hitos anuales). Esta es la decisión D5 del MVU.

### 5.3 Consultas que el desarrollador necesita frecuentemente

```sql
-- 1. Historia completa de un rol
SELECT lower(sys_period) AS desde, upper(sys_period) AS hasta,
       version, blocks_touched, fields_changed, changed_by, change_reason
FROM bauth.ver_history
WHERE entity_name = 'idn_roles_rol_hierarchical' AND entity_id = :rol_id
ORDER BY lower(sys_period) DESC;

-- 2. Reconstruir el rol como estaba el 15 de marzo (as-of)
-- → bauth.version.as_of vía JSON-RPC (el motor aplica ancla + deltas)

-- 3. ¿Qué roles cambiaron sus límites financieros este trimestre? (B8)
SELECT DISTINCT entity_id, version, lower(sys_period) AS changed_at, changed_by
FROM bauth.ver_history
WHERE entity_name = 'idn_roles_rol_hierarchical'
  AND 'B8' = ANY(blocks_touched)
  AND lower(sys_period) >= date_trunc('quarter', now())
ORDER BY lower(sys_period) DESC;

-- 4. Cambios pendientes de aprobación (quórum MAJOR)
SELECT entity_id, proposed_state, blocks_touched, change_reason,
       proposed_by, required_approvers, cardinality(approvals::jsonb) AS aprobados,
       sla_deadline, escalated
FROM bauth.ver_proposal
WHERE entity_name = 'idn_roles_rol_hierarchical' AND status = 'PENDING'
ORDER BY sla_deadline;
```

---

## 6. La historia del UserTemplate

El UserTemplate (`idn_user_template`) es también **clase C1** y recibirá el mismo tratamiento en la **fase F5 del MVU**. Las reglas son simétricas al RolTemplate con dos consideraciones adicionales:

### 6.1 RGPD Art. 17 — Derecho al olvido sobre versiones históricas

Cuando un usuario ejerce el derecho al olvido, el sujeto se **anonimiza** — pero el asiento de `ver_history` persiste (la existencia del cambio, sin el sujeto identificable):

```sql
-- Anonimización controlada (solo el módulo de retención ejecuta esto):
UPDATE bauth.ver_history
SET changed_by = 'ANONIMIZADO-' || substring(entry_hash, 1, 8),
    fields_changed = jsonb_set(fields_changed, '{subject}', '"[RGPD-Art17]"')
WHERE entity_name = 'idn_user_template'
  AND entity_id = :user_id;
-- + INSERT aud_event tipo IDENTITY_DELETE con details.rgpd_art17 = true
```

**Regla:** nunca DELETE en `ver_history`. Siempre anonimizar el sujeto, preservar el asiento.

### 6.2 Campos del UserTemplate que NO generan versión

- `sync_status` y estado de sincronización (calculado por el motor)
- `status` del ciclo de vida del usuario (sus propias reglas de transición)

---

## 7. Emitir un evento de auditoría

### 7.1 Los 30 tipos de evento — elegir el correcto

| Familia | Tipos disponibles | Cuándo usarlos |
|---------|------------------|----|
| Sesión | `LOGIN_SUCCESS`, `LOGIN_FAILED`, `LOGOUT` | En los handlers de autenticación |
| Acceso | `ACCESS_GRANTED`, `ACCESS_DENIED` | En el PDP, después de cada evaluación |
| Privilegio | `PRIVILEGE_ESCALATION`, `PRIVILEGE_USE`, `SUPERUSER_ACTIVATE` | En el BitMask engine y step-up |
| Identidad | `IDENTITY_CREATE`, `IDENTITY_MODIFY`, `IDENTITY_DELETE`, `IDENTITY_ARCHIVE` | En operaciones sobre UserTemplate |
| Roles | `ROLE_ASSIGN`, `ROLE_REVOKE`, `ROLE_CREATE`, `ROLE_MODIFY` | En operaciones sobre RolTemplate y asignaciones |
| Delegación | `DELEGATION_CREATE`, `DELEGATION_REVOKE`, `DELEGATION_USE` | En D10 delegaciones |
| Configuración | `CONFIG_CHANGE`, `POLICY_CHANGE`, `MAINTENANCE` | En cambios de configuración y política |
| Archivos | `FILE_ACCESS`, `FILE_DELETE`, `FILE_MIGRATION` | En accesos a documentos firmados |
| Seguridad física | `SECURITY_ALARM`, `SECURITY_SYSTEM_TOGGLE` | En D5 acceso físico |
| Cumplimiento | `COMPLIANCE_REVIEW`, `ACCESS_REVIEW` | En IGA reviews |
| Contexto | `CONTEXT_SWITCH`, `CONTEXT_INVALIDATE` | En el ciclo del ctx_id |
| Sincronización | `SYNC_START`, `SYNC_COMPLETE`, `SYNC_ERROR`, `DRIFT_DETECTED` | En el reconcile loop |

### 7.2 El `iso_control[]` correcto por tipo de evento

```rust
// src/audit/audit_event.rs — el constructor central
fn iso_controls_for(event_type: &EventType) -> Vec<&'static str> {
    match event_type {
        EventType::LoginFailed       => vec!["A.8.15", "AU-2", "AU-3"],
        EventType::AccessDenied      => vec!["A.8.15", "AU-3", "AC-3"],
        EventType::RoleModify        => vec!["A.8.15", "A.8.9", "A.8.32", "CM-3"],
        EventType::IdentityCreate    => vec!["A.8.15", "A.5.15", "AC-2"],
        EventType::IdentityDelete    => vec!["A.8.15", "AC-2", "AU-3"],
        EventType::PolicyChange      => vec!["A.8.9", "A.8.32", "CM-3", "AU-3"],
        EventType::SyncError         => vec!["A.8.15", "AU-3"],
        EventType::DriftDetected     => vec!["A.8.15", "AU-3", "CM-3"],
        EventType::ComplianceReview  => vec!["A.9.2.5", "AU-11", "AC-2"],
        // ...
    }
}
```

**Regla:** NUNCA emitir un evento sin `iso_control[]`. El reporte de cumplimiento es un `GROUP BY iso_control` — si falta el control en origen, el reporte miente.

### 7.3 La hash-chain — por qué no saltarse

```rust
// El constructor obtiene el hash previo en la MISMA transacción
fn build_event(conn: &mut PgConn, ...) -> Result<AudEvent> {
    let prev_hash = conn.query_one(
        "SELECT entry_hash FROM bauth.aud_event
         ORDER BY created_at DESC LIMIT 1 FOR UPDATE",
        &[]
    )?.get::<_, Option<String>>(0);

    let entry_hash = sha256(format!("{}{}{}", prev_hash.unwrap_or_default(), event_type, created_at));
    // ...
}
```

---

## 8. El cambio de una definición gobernada — la transición atómica

Flujo que ejecuta `db/version_store.rs` para un cambio MINOR o PATCH (1.13 §9.3):

```
BEGIN TRANSACTION
│
├─ 1. SELECT ... FOR UPDATE (la fila vigente — bloquea carreras)
│
├─ 2. classify(diff) → bloques_tocados → standard_ref → bump mínimo
│      Si bump_declarado < bump_mínimo → ERROR "bump insuficiente"
│
├─ 3. Si MAJOR → no continuar aquí (ver §9)
│
├─ 4. Si MINOR/PATCH:
│   ├─ 5. INSERT ver_history (la versión que se CIERRA):
│   │       sys_period = [sys_since_vigente, now()),
│   │       WITHOUT OVERLAPS garantiza no-solape; WORM sella entry_hash
│   │
│   ├─ 6. UPDATE tabla_vigente:
│   │       SET campos_nuevos, version = version_bumpeada, sys_since = now()
│   │
│   └─ 7. INSERT aud_event:
│           event_type apropiado, iso_control = controles por bloques
│
COMMIT
│
└─ POST-COMMIT (fuera de la transacción):
    Si blocks_touched ∩ {B4,B6,B7,B8,B12} ≠ ∅:
    ├─ Invalidar BitmaskBundle en Redis
    ├─ Emitir señal CAEP (bNotify)
    └─ Resetear sync_status (reconcile resincroniza)
```

**El post-commit no es opcional.** Un cache de autorización que sobrevive a un cambio de definición convierte el versionado en teatro.

---

## 9. Cambios MAJOR

```
bauth.version.propose { entity, id, changes, change_type: "MAJOR", reason }
│
├─ Motor crea ver_proposal:
│   ├─ required_approvers leídos del B3 del artefacto (no hardcodeados)
│   ├─ sla_deadline = now() + B3.sla_hours (default: 48h)
│   └─ status = 'PENDING'
│
├─ La vigente SIGUE RIGIENDO hasta aprobación
│
└─ Notificación a approver_roles vía bNotify

Cada aprobador: bauth.version.approve { proposal_id, note }
├─ Validar: aprobador ≠ proponente (AC-5 CHECK en DDL)
└─ Si cardinality(approvals) >= required_approvers:
    → TRANSICIÓN ATÓMICA (is_anchor = true, snapshot obligatorio)
    → Invalidar cache + CAEP + sync reset
```

**P5 del MVU:** el rollback NUNCA revive una versión antigua directamente. Siempre se propone el estado anterior como nueva versión. Si restaura permisos más amplios → toca B4/B6/B8 → MAJOR con quórum.

---

## 10. Reglas de retención

| Entidad | Ventana caliente | Compactación | Retención total | Base legal |
|---------|-----------------|--------------|-----------------|------------|
| `idn_roles_rol_hierarchical` | 2 años | KEEP_ANCHORS | **10 años** | Ley 843 Bolivia · A.5.33 · AU-11 |
| `idn_user_template` | 2 años | KEEP_ANCHORS | **10 años** | Ley 843 · RGPD 5(1)(e)/17 |
| Catálogos (`privilege_*`, `ath_*`) | 2 años | KEEP_ANCHORS | 10 años | Sustrato del acceso |
| Cambios B8 (financieros) | Ventana fiscal | **KEEP_ALL** | 7-8 años mínimo | Ley 2492 · CC Art. 44 |
| `aud_event` | Online (PCI: 3 meses) | No se compacta | ≥ 12 meses PCI / ≥ 2 años objetivo | PCI DSS 10.5 · ISO A.5.33 |

**KEEP_ANCHORS fuera del hot_window:** conservar todas las anclas MAJOR + sus deltas MAJOR; purgar MINOR/PATCH intermedios. El estado de cualquier fecha sigue siendo reconstruible (ancla más cercana + deltas MAJOR posteriores).

```sql
SELECT hot_window, compaction_policy, retention_total, legal_basis, legal_hold
FROM bauth.ver_retention_schedule
WHERE entity_name = 'idn_roles_rol_hierarchical';
```

---

## 11. Tablas eliminadas — las 48 ELIMINADAS del DDL

Estas tablas existen en el DDL antiguo o fueron propuestas como nuevas `[N]` pero **NO deben usarse en código nuevo**: el árbol jerárquico `idn_roles_rol_hierarchical` o las tablas de historia/auditoría universales (`ver_history`, `aud_event`) las hace redundantes.

| Código | Tabla | Por qué no usar | Reemplazo |
|--------|-------|-----------------|-----------|
| **T-020** | `fis_location` | Jerarquía territorial cubierta por D0 `metadata.region`/`territory_code` (dart:249-250) + `parent_id`/`path_ids` (dart:246) del árbol | árbol D0 B1 |
| **T-021** | `fis_location_closure` | Cierre transitivo derivable de `parent_id`/`path_ids` en D0 — no requiere tabla de cierre independiente | árbol D0 B1 |
| **T-022** | `fis_area_config` | El nivel de seguridad por área es atributo de cada nodo de zona en D2 `zones_access_rules` (dart:1431-1458) — embedded en el árbol | árbol D2 B5 |
| **T-025** | `fis_access_zone` | Catálogo de zonas = nodos `_ev(zone.id == 'PHY_ZONE_*')` en D2 `zones_access_rules` (dart:1431-1458). Los IDs de zona viven en el árbol | árbol D2 B5 |
| **T-026** | `fis_zone_member` | Membresía rol→zona = decisiones PERMIT/DENY de `zones_access_rules` en D2 (dart:1431-1458). El árbol ES la tabla de membresía | árbol D2 B5 |
| **T-107** | `org_empresa` | **`idn_identity_entity` con `nivel='bdomain', tipo='empresa'` ES el catálogo de empresas** (1.06 §4). El ctx_id capa 2 = `bdomain_id` (SBOS-049 §3.1). NIT y atributos fiscales → `idn_identity_attribute` | `idn_identity_entity` |
| **T-108** | `org_sucursal` | **`idn_identity_entity` con `nivel='bsubdomain', tipo='sucursal'` ES el catálogo de sucursales** (1.06 §4). El ctx_id capa 3 = `bsubdomain_id`. La tabla duplica el árbol D00 | `idn_identity_entity` |
| **T-109** | `org_pos_logico` | **`idn_identity_entity` con `nivel='pos'` ES el POS lógico** (1.06 §4). El ctx_id capa 4 = `pos_logico`. Código SIN → `idn_identity_attribute` con `category='tributario'` | `idn_identity_entity` |
| T-043 | `bos_rol_template_history` | Reemplazada por `ver_history` — es LA historia del RolTemplate | T-152 `ver_history` |
| T-028 | `fin_limit` | D3/B8 `transaction_limits` en el árbol | árbol + `@bauth_config_param` |
| T-029 | `fin_approval_chain` | D0/B3 `approval_workflow` en el árbol | árbol + `ver_proposal` |
| T-030 | `fin_approval_level` | D3/B8 niveles en el árbol | árbol |
| T-033 | `fin_role_permission` | D1/B7 CAPA 1 `model_access` en el árbol | árbol |
| T-036 | `cfg_validation_rule` | Nodo `evaluacion` AtomLang cubre todo | árbol |
| T-037 | `cfg_validation_log` | Duplica `privilege_atom_audit` + `aud_event` | T-056 + T-091 |
| T-038 | `ath_policy` | D1/B4 del árbol | árbol |
| T-044 | `log_zone` | Propósito indefinido; `aud_event` cubre logs de zona | T-091 |
| T-049 | `bos_permiso_logico` | Árbol usa slug directo | árbol |
| **T-064** | `idn_rolestpl_atom_config` | **[N] propuesta redundante** — la extensibilidad de átomos es nativa al árbol (nodos `atributo`; A.01 §B2). TTL/deprecación en B2. Per-tenant = variantes en el árbol del tenant | árbol (nodos `atributo` en `idn_roles_template`) |
| **T-065** | `idn_rolestpl_atom_history` | **[N] propuesta redundante** — A.01 §B1 `audit.change_history[]` materializa en `ver_history`. El árbol es LA historia. Una tabla de historial de átomos viola el principio de UN motor de historia | T-152 `ver_history` (F5) + T-091 `aud_event` |
| **T-066** | `idn_rolestpl_atom_history_2026_07` | Partición de T-065 (ELIMINAR) | — |
| **T-067** | `idn_rolestpl_atom_history_2026_08` | Partición de T-065 (ELIMINAR) | — |
| **T-068** | `idn_rolestpl_requisito` | **[N] propuesta redundante** — requisitos de completitud son implícitos en la estructura del árbol: la presencia de átomos por dominio ES el requisito. El compilador AtomLang los deriva del árbol | árbol (estructura de átomos por dominio) |
| T-069 | `fin_sod_rule` | D10/B12 `incompatible_roles` en el árbol | árbol |
| T-070 | `fin_decision_matrix` | D3/B8 `sod_rules` en el árbol | árbol |
| T-074 | `ath_credential_policy` | D9/B18 `password_policy` en el árbol | árbol |
| T-096 | `aud_policy_change` | Delta ya en `ver_history.fields_changed` + `aud_event(POLICY_CHANGE).details` | T-091 + T-152 |
| T-097 | `aud_policy_version` | `ver_history` la subsume en F5 — retener hasta que F5 esté en VPS | T-152 `ver_history` (F5) |
| T-099 | `sync_log` | Duplica D99/B14 + `aud_event` | T-091 |
| T-115–117 | `ath_auth_flow*` | D1/D2 del árbol | árbol |
| T-118–121 | `zone_*` | D1/B7 capas 3-5 en el árbol | árbol |
| T-122–123 | `fis_zone_method/emergency` | D2/B5 en el árbol | árbol |
| T-126 | `net_ztna_policy` | D7/B16 en el árbol | árbol |
| T-127 | `ses_risk_policy` | D8/B17 en el árbol | árbol |
| T-129–130 | `sod_validation_config`, `conflict_interest_policy` | D10/B12 en el árbol | árbol |
| T-131 | `tryton_action_visibility` | ADR-010 — Tryton eliminado | — |
| T-132–134 | `geo_trust_tier`, `geo_velocity_policy`, `geo_fence` | D6/B15 en el árbol | árbol |
| T-144 | `emergency_override_policy` | D8 + D2 en el árbol | árbol |
| T-145 | `visitor_access_policy` | D2/B5 en el árbol | árbol |

---

## 12. Errores comunes del desarrollador

| Error | Consecuencia | Corrección |
|-------|-------------|------------|
| `UPDATE idn_roles_rol_hierarchical` directo | Rompe historia C2 | Usar `bauth.version.propose` |
| `aud_event` sin `ctx_id` | NOT NULL falla, SBOS-049 violado | Propagar siempre el ctx_id del request |
| `aud_event` sin `iso_control[]` | Reportes de cumplimiento mienten | Usar el mapa de controles §7.2 |
| Escribir en `ver_history` desde código | Viola garantía WORM | Solo el MVU escribe en C2 |
| Usar `bos_rol_template_history` | Dato obsoleto, no mantenido | Usar `ver_history` |
| Usar tablas eliminadas (T-028 a T-145) | El árbol tiene el dato correcto | Leer nodo del árbol vía `privilege_atom_policy` |
| Declarar MINOR para cambio B8 | Motor falla: "bump insuficiente" | El motor determina el mínimo; el autor puede declarar mayor |
| Aprobar cambio MAJOR propio | CHECK AC-5 rechaza | Necesita otro aprobador del quórum |
| Invalidar cache ANTES del COMMIT | Si el COMMIT falla, cache sucio | Post-commit siempre DESPUÉS del COMMIT |
| DELETE en `aud_event` para "limpiar" | Rompe hash-chain; viola A.5.33 | Nunca borrar; anonimizar si RGPD Art. 17 |
| INSERT en tabla ELIMINAR por "compatibilidad" | Dato duplicado e inconsistente | Migrar la referencia al árbol |
| Leer `idn_tenant_config` desde código de dominio | Módulo de dominio no debe tener I/O | Inyectar la config desde la capa de infraestructura |

---

## 13. Mapa de relaciones entre tablas de trazabilidad

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    DEFINICIÓN GOBERNADA (C1)                            │
│  bauth.idn_roles_rol_hierarchical  ·  bauth.idn_user_template  ·  ...  │
│  sys_since · change_channel · changed_by · change_reason               │
│  version (SemVer) · template_version (contrato que lo interpreta)      │
└─────────────────┬───────────────────────────────────────────────────────┘
                  │ Cada cambio cierra la versión vigente
                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    HISTORIA DE VERSIONES (C2)                           │
│  ver_history  (entity_name / entity_id / sys_period WITHOUT OVERLAPS)  │
│  ver_proposal (cambios MAJOR pendientes de quórum)                      │
│  ver_retention_schedule (plazos legales como dato)                      │
│  ver_template_changelog (transiciones de contrato v5→v6)               │
└─────────────────┬───────────────────────────────────────────────────────┘
                  │ Cada transición emite un evento
                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    EVIDENCIA DE AUDITORÍA (C3)                          │
│  aud_event (ctx_id · event_type · iso_control[] · hash-chain)          │
│  privilege_atom_audit (evaluaciones PDP WORM)                          │
│  ✗ aud_policy_change → ELIMINAR: delta ya en ver_history+aud_event     │
└─────────────────────────────────────────────────────────────────────────┘

DOS CONSULTAS, DOS PERSPECTIVAS:
  «¿Qué ocurrió con el rol VENT-01 el 14 de julio?»
    → SELECT * FROM aud_event WHERE resource_id = :rol_id AND created_at::date = '2026-07-14'
  «¿Cómo era el rol VENT-01 el 14 de julio?»
    → SELECT * FROM ver_history WHERE entity_id = :rol_id AND sys_period @> '2026-07-14'::timestamptz
```

---

## 14. Referencias

| Documento | Sección relevante | Qué aporta |
|-----------|------------------|------------|
| 5.01 MANUAL-AUDITORIA-TRAZABILIDAD | §2/§3/§5/§7 | El paradigma dimensional, WORM, las tres cadenas |
| 1.13 MANUAL-MOTOR-VERSIONADO | §5-§10 | Los tres planos, decisiones D1-D7, transición atómica, retención |
| A.65 INVENTARIO-TABLAS-DDL | Todas las secciones | Las 155 tablas con clase C1-C4 y recomendaciones |
| A.01 CONTRATO-ROLTEMPLATE | §B1 · §B3 | Historial del contrato; gobernanza que el MVU implementa |
| A.02 CONTRATO-USERTEMPLATE | §U1-§U15 | Secciones normadas del usuario para F5 del MVU |
| 2.06 MANUAL-D99 | §3 | Piso irrenunciable de retención (≥365 días) |

---

# PARTE II — Guía por grupo de tablas del A.62

## 15. El principio rector

Antes de decidir si una tabla existe o debe eliminarse, el desarrollador aplica la **regla del árbol**:

> **Si una política, regla o parámetro puede expresarse como un nodo del árbol `idn_roles_template`
> o como un campo normado del contrato (B1-B18), la tabla relacional que modele lo mismo es
> redundante y se elimina. El árbol es la fuente de verdad de la política.**

La consecuencia directa: las tablas que **sobreviven** son aquellas que almacenan uno de estos cuatro tipos de dato:
1. **Catálogos externos** — listas ISO/IANA/ADSIB que el árbol referencia pero no repite
2. **Estado dinámico operacional** — instancias en vuelo (sesiones activas, aprobaciones en curso, intentos de login, heartbeats) que el árbol describe como política pero no puede almacenar como estado
3. **Infraestructura real** — dispositivos físicos, organizaciones, calendarios: cosas que existen en el mundo real y que el árbol menciona pero no crea
4. **Evidencia de auditoría** — lo que ocurrió (C3): eventos WORM que el árbol no puede contener

Las tablas que **se eliminan** son las que intentan almacenar como filas relacionales lo que ya es un nodo o campo del árbol.

---

## 16. GLOBAL

**Tablas:** T-001 `global_language` · T-002 `global_country` · T-003 `global_currency` · T-004 `geo_timezone` · T-059 `menu_item` · T-060 `menu_context` · T-061 `menu_item_atom` · T-114 `global_config`

**Qué son:** catálogos de referencia externos. No son propiedad de ningún rol ni tenant. Son el vocabulario compartido del que todo el sistema habla.

**Por qué existen:** el árbol referencia estos catálogos por ID/código (ej: `B1.name` tiene `{"es": "Vendedor", "en": "Sales Rep"}` con FK a `global_language.code`). Sin estas tablas, el FK cuelga en el vacío. Son la infraestructura de i18n y configuración global.

**Cuándo se usa en código:**

| Operación | Cuándo | Qué tabla |
|-----------|--------|-----------|
| Validar que un `lang_code` existe | Al registrar un tenant o usuario | `global_language` |
| Obtener símbolo de una moneda | Al formatear montos | `global_currency` |
| Calcular offset de zona horaria | En evaluaciones temporales (D4/B2) | `geo_timezone` |
| Listar ítems de menú de una app | Al construir la UI del usuario | `menu_item` + `menu_item_atom` |
| Leer un parámetro global | En el arranque del daemon | `global_config` |

```sql
-- Leer el parámetro global de retención por defecto
SELECT value FROM bglobal.global_config WHERE key = 'default_retention_days';

-- Obtener menú filtrado por átomo habilitado para el rol
SELECT mi.id, mi.label, mi.icon, mi.route
FROM bglobal.menu_item mi
JOIN bglobal.menu_item_atom mia ON mia.menu_item_id = mi.id
JOIN bauth.privilege_role_atom pra ON pra.atom_id = mia.atom_id
WHERE pra.role_id = :role_id AND pra.mask & :user_bitmask > 0;
```

**Qué NO hacer:**
- No insertar idiomas o países arbitrarios — son catálogos ISO y se actualizan solo con nuevas versiones del estándar
- No modificar `global_config` desde handlers en runtime — usa `idn_tenant_config` para configuración específica del tenant
- `menu_item_atom` es el puente entre el menú y el BitMask: no duplicar esta lógica en código de UI

---

## 17. IDENTIDAD

**Tablas:** T-005 `idn_tenant` · T-006 `idn_tenant_currencies` · T-007 `idn_tenant_languages` · T-008 `idn_tenant_verification` · T-009 `idn_tenant_config` · T-010 `idn_tenant_domain` · T-011 `idn_tenant_network` · T-013 `idn_tenant_calendar_assignment`

**Qué son:** el tenant (`idn_tenant`) es el ancla referencial de toda la DDL — casi todas las FK de bAuth terminan en `tenant_id`. Sus satélites (T-006 a T-013) son la configuración real de ese tenant.

**Por qué existen:** el árbol describe la *política* de un rol dentro de un tenant. El tenant en sí — cuáles monedas acepta, qué dominios DNS le pertenecen, qué CIDRs están autorizados, qué calendario laboral usa — es **infraestructura real** que no puede ser un nodo del árbol porque existe independientemente de cualquier rol.

**Cuándo se usa en código:**

| Tabla | Quién escribe | Cuándo leer |
|-------|--------------|-------------|
| `idn_tenant` | Motor de Identidad (provisioning) | En cada operación — es la FK raíz |
| `idn_tenant_config` | Motor de Identidad | Al resolver `@bauth_config_param` en el árbol |
| `idn_tenant_domain` | Motor de Identidad | Al construir el prefijo del `ctx_id` |
| `idn_tenant_network` | Motor de Identidad | En evaluaciones de red/ZTNA (D7/B16) |
| `idn_tenant_currencies` | Motor de Identidad | Al validar monedas en operaciones financieras (D3/B8) |
| `idn_tenant_languages` | Motor de Identidad | Al servir i18n al cliente |
| `idn_tenant_verification` | Motor de Identidad | Al determinar IAL del tenant |
| `idn_tenant_calendar_assignment` | Motor de Identidad | Al resolver D4/B2 validity_period |

```sql
-- Resolver @bauth_config_param.max_velocity_km_h para un tenant
SELECT value::float
FROM bauth.idn_tenant_config
WHERE tenant_id = :tenant_id AND key = 'max_velocity_km_h';

-- Verificar que un CIDR pertenece al tenant (evaluación ZTNA)
SELECT EXISTS(
    SELECT 1 FROM bauth.idn_tenant_network
    WHERE tenant_id = :tenant_id
      AND :client_ip::inet <<= network_cidr
);
```

**Notas de implementación:**
- `idn_tenant` tiene columnas `[DEL]` marcadas: `realm_kc`, `realm_kc_ext`, `domain`, `session_ttl_max`, `token_ttl_seconds`, `rate_limit_rps` — son residuo Keycloak (ADR-010). No leer ni escribir estas columnas
- La columna `[N]` `is_internal` no tiene DDL aún — no usar hasta que el DDL esté aplicado
- La columna `purge_after` no tiene default — el trigger de purga debe implementarse en F4 del MVU

**Clase C1 aquí:** `idn_tenant` es C1. Todo cambio en la definición del tenant pasa por `bauth.version.propose`.

---

## 18. ROLES

**Tablas CONSERVAR:** T-040 `idn_roles_rol_type` · T-041 `idn_roles_rol_hierarchical` · T-042 `idn_roles_rol_tier` · T-063 `idn_roles_rol_closure` · T-162 `idn_roles_template`

**Tablas ELIMINAR:** T-043 `bos_rol_template_history` · T-064 `idn_rolestpl_atom_config` · T-065/066/067 `idn_rolestpl_atom_history*` · T-068 `idn_rolestpl_requisito`

---

### 18.1 La distinción fundamental — registro de roles vs. árbol de políticas

> **El error más costoso de este grupo es confundir `idn_roles_rol_hierarchical` con el contrato
> completo del rol. Son dos cosas distintas que viven en dos tablas distintas.**

El contrato RolTemplate v6.0 tiene **dos partes físicas separadas**:

| Parte | Pregunta que responde | Tabla | Clase |
|-------|----------------------|-------|-------|
| **Registro de identidad** (B1) | ¿QUÉ ES este rol? nombre, tier, jerarquía, estado, versión | T-041 `idn_roles_rol_hierarchical` | C1 |
| **Árbol de políticas** (B2-B14 / D0-D13) | ¿QUÉ PUEDE HACER este rol? reglas, efectos, dominios, átomos | T-162 `idn_roles_template` | C1 |

Un rol sin T-162 es una identidad sin autoridad — existe en el catálogo pero el PDP no puede evaluarlo.
Un árbol T-162 sin T-041 es política sin identidad — no tiene nombre, tier ni jerarquía.

---

### 18.2 T-041 `idn_roles_rol_hierarchical` — registro de identidad de roles (C1)

**DDL:** `bauth_48__idn_roles_rol_hierarchical.sql` · **Referencia:** A.01 §B1 · A.61 §2

**Qué almacena:** el catálogo de los 548 roles del sistema. Cada fila ES un rol con sus campos de identidad del bloque B1 del contrato v6.0. Es una tabla jerárquica (adjacency list via `parent_id`) que modela la jerarquía DAG de roles.

**Lo que contiene — campos B1:**

| Campo | Qué almacena | Regla |
|-------|-------------|-------|
| `id` | UUID v7 — identificador inmutable del rol | Nunca reutilizar. Formato lógico `{DEPT}-{NN}` en `slug` |
| `parent_id` | FK al rol padre (herencia DAG). `null` = raíz de tier | Nunca circular — CHECK en DB |
| `type_id` | FK a T-040 `idn_roles_rol_type` (INDIVIDUAL, M2M, SYSTEM…) | Uno de los 10 tipos NIST |
| `tier` | Nivel de privilegio: SU / SYS / BIZ_N1…N5 / EXT_N0 / M2M | Inmutable post-creación |
| `hierarchy_level` | Profundidad real en el DAG (calculada por closure) | Solo lectura — recalculada por bauth_62 |
| `status` | `DRAFT → REVIEW → ACTIVE → DEPRECATED → ARCHIVED` | Motor de versionado gobierna transiciones |
| `version` | SemVer del contrato de este rol (`major.minor.patch`) | MAJOR = breaking en permisos |
| `name` | Nombre multilenguaje `{es, en, pt}` | i18n obligatorio |
| `metadata` | department, cost_center, region, territory_code, job_family, job_level, classification | `classification` ISO A.5.12 |
| `audit` | created_by/at, updated_by/at, version_number | Trazabilidad del artefacto |

**LO QUE NO CONTIENE — y donde muchos cometen el error:**
- ❌ No contiene átomos de privilegio — esos están en `privilege_role_atom`
- ❌ No contiene reglas de autenticación (D1/B4), acceso físico (D2/B5), financiero (D3/B8)
- ❌ No contiene `combining_algorithm`, `effects`, `obligations`
- ❌ No contiene los dominios D0-D13 con sus políticas
- **Todo lo anterior está en T-162 `idn_roles_template`**

**Cuándo leer:**
```sql
-- Catálogo de roles activos de un tenant
SELECT id, slug, tier, name->>'es' AS nombre, status, version, hierarchy_level
FROM bauth.idn_roles_rol_hierarchical
WHERE tenant_id = :tenant_id AND status = 'ACTIVE'
ORDER BY tier, hierarchy_level, slug;

-- Árbol jerárquico de roles (CTE recursiva)
WITH RECURSIVE jerarquia AS (
  SELECT id, parent_id, slug, tier, 0 AS depth
  FROM bauth.idn_roles_rol_hierarchical
  WHERE parent_id IS NULL AND tenant_id = :tenant_id

  UNION ALL

  SELECT r.id, r.parent_id, r.slug, r.tier, j.depth + 1
  FROM bauth.idn_roles_rol_hierarchical r
  JOIN jerarquia j ON r.parent_id = j.id
  WHERE r.tenant_id = :tenant_id
)
SELECT * FROM jerarquia ORDER BY depth, tier, slug;

-- Metadata organizacional de un rol (B1)
SELECT
  metadata->>'department'      AS department,
  metadata->>'territory_code'  AS territory_code,
  metadata->>'job_level'       AS job_level,
  metadata->>'classification'  AS classification
FROM bauth.idn_roles_rol_hierarchical
WHERE id = :role_id;
```

**Quién escribe:** solo el MVU vía `bauth.version.propose`. Nunca `UPDATE` directo desde handlers.

---

### 18.3 T-162 `idn_roles_template` — árbol jerárquico de políticas compartido (C1) ⭐ NUEVA

**DDL:** `bauth_65__idn_roles_template.sql` (pendiente de creación) · **Referencia:** A.64 §7 · dart `rol_template_datos.dart` · A.01 §2-§17

---

#### Por qué UN árbol compartido y no uno por rol

Almacenar un árbol de políticas completo (D0-D13, ~200 nodos) por cada uno de los 1500+ roles significaría 300.000+ filas o JSONB blobs repetidos. La arquitectura definida en A.64 §7 resuelve esto con **un único árbol compartido**:

- Cada nodo del árbol declara en su campo `subject` a **qué roles aplica** mediante un SET nombrado (`SET(cajeros)`, `SET(gerentes)`) o un rol específico (`ROL(uuid)`)
- El campo `unset` excluye roles explícitamente aunque estén en el SET
- El PDP **filtra el árbol por rol** en runtime → obtiene la política efectiva del rol sin duplicar datos

```
UN solo árbol idn_roles_template (todos los dominios D0-D13)
        │
        ├── nodo: D1 combining_algorithm=deny-overrides
        │     subject: ALL
        │
        ├── nodo: D1 → regla lockout_5_intentos
        │     subject: SET(cajeros) → {ROL-CAJERO, ROL-ASISTENTE-CAJA}
        │
        ├── nodo: D1 → regla lockout_3_intentos
        │     subject: SET(privilegiados) → {ROL-GERENTE, ROL-AUDITOR}
        │     unset: [ROL-AUDITOR-EXTERNO]
        │
        └── nodo: D3 → límite transacción 5000 BOB
              subject: ROL(uuid-cajero)
```

---

#### Estructura de cada nodo

Cada fila representa UN nodo del árbol del dart. La tabla es una **adjacency list jerárquica** con path ltree para consultas de subárbol:

```sql
CREATE TABLE bauth.idn_roles_template (
    id               UUID         NOT NULL DEFAULT uuidv7(),

    -- Posición en el árbol
    parent_id        UUID         REFERENCES bauth.idn_roles_template(id) ON DELETE CASCADE,
    path             LTREE        NOT NULL,        -- ej: D1.lockout.max_attempts
    order_index      SMALLINT     NOT NULL DEFAULT 0,

    -- Tipo y semántica del nodo
    node_type        TEXT         NOT NULL,        -- DOMAIN | POLICY_SET | POLICY | RULE
                                                   -- CONDITION | EFFECT | ATOM | OBLIGATION | PROPERTY
    domain_code      TEXT,                         -- D0..D13, D98, D99 (NULL si es raíz global)
    node_key         TEXT         NOT NULL,        -- nombre del nodo: 'combining_algorithm',
                                                   -- 'effect', 'condition', 'verb_id', 'max_attempts'
    node_value       JSONB,                        -- valor del nodo (string, número, objeto, array)

    -- Semántica XACML
    combining_algorithm TEXT,                      -- deny-overrides | permit-overrides |
                                                   -- only-one-applicable | first-applicable
    effect           TEXT,                         -- PERMIT | DENY | INDETERMINATE | NOT_APPLICABLE

    -- Membresía de roles — el mecanismo SET/UNSET (A.64 §7)
    subject          JSONB        NOT NULL DEFAULT '{"kind":"ALL"}',
    -- Ejemplos válidos:
    --   {"kind":"ALL"}                           → aplica a todos los roles
    --   {"kind":"SET","name":"cajeros","roles":["uuid1","uuid2"]}
    --   {"kind":"ROL","role_id":"uuid-gerente"}
    unset            UUID[]       NOT NULL DEFAULT '{}',
    -- UUIDs de idn_roles_rol_hierarchical excluidos aunque estén en el SET

    -- Trazabilidad
    version          TEXT         NOT NULL DEFAULT '1.0.0',
    is_active        BOOLEAN      NOT NULL DEFAULT true,
    ctx_id           TEXT         NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),

    PRIMARY KEY (id),
    CONSTRAINT chk_node_type CHECK (node_type IN (
        'DOMAIN','POLICY_SET','POLICY','RULE',
        'CONDITION','EFFECT','ATOM','OBLIGATION','PROPERTY'
    )),
    CONSTRAINT chk_combining CHECK (
        combining_algorithm IS NULL OR combining_algorithm IN (
            'deny-overrides','permit-overrides',
            'only-one-applicable','first-applicable'
        )
    ),
    CONSTRAINT chk_effect CHECK (
        effect IS NULL OR effect IN ('PERMIT','DENY','INDETERMINATE','NOT_APPLICABLE')
    )
);

-- Índice para consultas de subárbol por dominio (la consulta más frecuente del PDP)
CREATE INDEX ix_rt_path ON bauth.idn_roles_template USING GIST (path);

-- Índice para filtrar por rol: ¿qué nodos aplican a ROL-X?
CREATE INDEX ix_rt_subject ON bauth.idn_roles_template USING GIN (subject);

-- Índice para excluidos: ¿qué nodos excluyen a ROL-X?
CREATE INDEX ix_rt_unset ON bauth.idn_roles_template USING GIN (unset);

-- Índice de orden dentro de cada padre
CREATE INDEX ix_rt_parent_order ON bauth.idn_roles_template (parent_id, order_index)
    WHERE is_active = true;
```

---

#### Tipos de nodo y qué campos usan

| node_type | node_key | node_value | combining_algorithm | effect | subject |
|-----------|----------|-----------|---------------------|--------|---------|
| `DOMAIN` | `"D1"` | NULL | `"deny-overrides"` | NULL | `{"kind":"ALL"}` |
| `POLICY_SET` | `"acceso_logico"` | NULL | `"deny-overrides"` | NULL | SET o ALL |
| `POLICY` | `"lockout_policy"` | NULL | `"deny-overrides"` | NULL | SET o ALL |
| `RULE` | `"lockout_5_intentos"` | NULL | NULL | `"DENY"` | SET o ROL |
| `CONDITION` | `"max_attempts"` | `5` | NULL | NULL | heredado del RULE padre |
| `ATOM` | `"verb_id"` | `"auth.login"` | NULL | `"PERMIT"` | SET |
| `OBLIGATION` | `"notify_admin"` | `{"channel":"email"}` | NULL | NULL | SET |
| `PROPERTY` | `"territory_code"` | `"BO"` | NULL | NULL | SET o ROL |

---

#### Consultas clave

```sql
-- Política efectiva de un rol en D1 (lo que el PDP evalúa)
-- Un nodo aplica si: (subject.kind=ALL) OR (subject incluye el role_id) AND (unset no incluye role_id)
SELECT id, path, node_type, node_key, node_value, combining_algorithm, effect
FROM bauth.idn_roles_template
WHERE path <@ 'D1'                       -- subárbol de D1
  AND is_active = true
  AND (
    subject->>'kind' = 'ALL'
    OR subject @> jsonb_build_object('roles', jsonb_build_array(:role_id::text))
    OR subject @> jsonb_build_object('role_id', :role_id::text)
  )
  AND NOT (:role_id = ANY(unset))
ORDER BY path, order_index;

-- Todos los roles que tienen DENY en zona PHY_ROOM_SERVIDOR
SELECT DISTINCT r.role_name, r.tier
FROM bauth.idn_roles_template n
JOIN bauth.idn_roles_rol_hierarchical r
     ON r.id = ANY(
         COALESCE(
             ARRAY(SELECT jsonb_array_elements_text(n.subject->'roles'))::UUID[],
             ARRAY[]::UUID[]
         )
     )
WHERE n.path <@ 'D2'
  AND n.node_key = 'zone_id'
  AND n.node_value = '"PHY_ROOM_SERVIDOR"'
  AND n.effect = 'DENY'
  AND n.is_active = true;

-- Subárbol completo de D3 (financiero) para depuración
SELECT path, node_type, node_key, node_value, effect, subject
FROM bauth.idn_roles_template
WHERE path <@ 'D3' AND is_active = true
ORDER BY path, order_index;
```

---

#### Quién escribe aquí

| Quién | Operación | Cuándo |
|-------|-----------|--------|
| Seed inicial `bauth_65` | INSERT masivo | Bootstrap — carga el árbol completo del dart |
| Compilador AtomLang (atomc) | INSERT nodos nuevos + UPDATE `is_active=false` en nodos reemplazados | Al compilar un `.atm.yaml` editado desde el dashboard |
| MVU `bauth.version.propose` | Gobernanza de versión — coordina compilación + aprobación + activación | Cualquier cambio MAJOR en el árbol |
| PDP | SELECT únicamente | En cada evaluación de acceso |
| Redis cache | Copia de subárboles activos por dominio | Invalidada por el compilador al publicar |

---

#### NO hacer

- `UPDATE node_value` directamente en un nodo activo — usar el compilador: editar fuente `.atm.yaml` → atomc recompila → nuevo nodo + `is_active=false` en el antiguo
- `DELETE` de nodos — `is_active = false` es el mecanismo de desactivación; los nodos son historial C1
- Escribir `subject = {"kind":"ALL"}` en nodos de RULE de seguridad alta — esos nodos deben tener SET explícito; ALL es solo para dominios raíz y policies base
- Confundir `idn_roles_template` con `idn_roles_rol_hierarchical` — son la dupla QUÉ PUEDE / QUIÉN ES

---

### 18.4 T-040 `idn_roles_rol_type` — catálogo de 10 tipos de cuenta (C1)

**DDL:** `bauth_47a__idn_roles_rol_type.sql` · **Referencia:** A.01 §B1 · NIST AC-2(a)

Los 10 tipos de rol del NIST: `INDIVIDUAL`, `EXTERNAL`, `GUEST`, `GROUP`, `SYSTEM`, `SERVICE`, `M2M`, `EMERGENCY`, `TEMPORARY`, `DEVELOPER`. El campo `type_id` de T-041 referencia esta tabla. Es seed — no cambia en runtime.

```sql
-- Los 10 tipos disponibles
SELECT type_code, description, max_session_hours, requires_mfa
FROM bauth.idn_roles_rol_type
ORDER BY type_code;
```

---

### 18.5 T-042 `idn_roles_rol_tier` — métodos de autenticación y parámetros de sesión por tier (C1)

**DDL:** `bauth_11__idn_roles_rol_tier.sql` · **Referencia:** NIST SP 800-63B §4 · A.64 §7

Define los parámetros de autenticación que aplican a cada tier (SU, SYS, BIZ_N1..N5, EXT_N0, M2M, VISITANTE). **No son políticas de gobernanza** — son los parámetros de sesión y los métodos MFA disponibles para cada nivel de privilegio.

| Campo | Qué define |
|-------|-----------|
| `loa_default` | Nivel de aseguramiento por defecto (1-3) |
| `mfa_default` | Si MFA es obligatorio para este tier |
| `mfa_methods` | Array de métodos disponibles: `{FIDO2,WebAuthn,TOTP,Password...}` |
| `session_timeout_secs` | Tiempo máximo de sesión inactiva |
| `max_sessions` | Sesiones simultáneas permitidas (0 = ilimitado) |
| `step_up_allowed` | Si el tier puede elevar su LoA temporalmente (RFC 9470) |
| `delegation_allowed` | Si puede delegar permisos a otro usuario |
| `nist_aal_ref` | Referencia NIST: AAL1 / AAL2 / AAL3 / M2M |

El árbol `idn_roles_template` consulta esta tabla (vía PIP) al evaluar nodos de dominio D1 (acceso lógico) y D9 (credenciales) para obtener los parámetros del tier del rol evaluado.

---

### 18.6 T-063 `idn_roles_rol_closure` — DAG de herencia BitMask (infraestructura)

**DDL:** `bauth_62__idn_roles_rol_closure.sql` · **Referencia:** A.01 §B11 · A.61 §2

La closure table materializa el DAG de herencia de roles. Cada fila `(ancestor_id, descendant_id, depth)` permite calcular la máscara BitMask acumulada de un rol con todos sus ancestros en O(1) via JOIN.

```sql
-- Átomos efectivos de GERENTE incluyendo herencia de VENDEDOR
SELECT DISTINCT ra.atom_code, a.atom_slug
FROM bauth.idn_roles_rol_closure c
JOIN bauth.privilege_role_atom ra ON ra.role_id = c.ancestor_id
JOIN bauth.privilege_atom a ON a.atom_code = ra.atom_code
WHERE c.descendant_id = :gerente_id AND ra.allowed = true;
```

**Nunca escribir directamente.** El MVU recalcula la closure automáticamente en post-commit cuando cambia `parent_id` en T-041.

---

### 18.7 Por qué se eliminan T-043, T-064, T-065, T-066, T-067, T-068

| Tabla | Por qué ELIMINAR | Reemplazo |
|-------|-----------------|-----------|
| T-043 `bos_rol_template_history` | Pre-MVU — sin hash-chain, sin WITHOUT OVERLAPS PG18, sin MAJOR/MINOR/PATCH | T-152 `ver_history` |
| T-064 `idn_rolestpl_atom_config` | EAV duplica los nodos `atributo` nativos del árbol T-162 | T-162 `idn_roles_template` (nodos atributo) |
| T-065/066/067 `idn_rolestpl_atom_history*` | Una tabla de historia de átomos viola el principio de UN motor de historia | T-152 `ver_history` + T-091 `aud_event` |
| T-068 `idn_rolestpl_requisito` | Completitud derivable de la gramática AtomLang aplicada al árbol T-162 | Compilador AtomLang (A.46) |

```
❌ SELECT * FROM bauth.bos_rol_template_history WHERE role_id = :id
✅ SELECT * FROM bauth.ver_history
   WHERE entity_name = 'idn_roles_rol_hierarchical' AND entity_id = :id::text
   ORDER BY sys_period DESC;
```

---

## 19. USUARIOS

**Tablas:** T-090 `dlg_delegation` · T-105 `idn_user_template` · T-106 `idn_user_role`

### 19.1 `idn_user_template` — la identidad del usuario (C1 simétrico al rol)

Almacena la identidad SCIM 2.0 del usuario. Es **clase C1** — exactamente el mismo tratamiento que el árbol del rol. Todo cambio pasa por `bauth.version.propose`. La historia completa está en `ver_history` (fase F5 del MVU).

Los datos que contiene son los 16 bloques (U1-U16) del contrato de usuario v6.0: identificadores, contacto, credenciales (referencias, no secretos), enrolamientos MFA, ciclo de vida, etc.

```sql
-- Leer la identidad actual de un usuario
SELECT id, tenant_id, username, display_name, status,
       contact_info, lifecycle, enrollment_state
FROM bauth.idn_user_template
WHERE id = :user_id AND tenant_id = :tenant_id;
```

**NRS-10:** ningún campo secreto (contraseña, clave privada, OTP seed) puede estar en esta tabla. Solo referencias (hash Argon2id, key_id de Vault).

### 19.2 `idn_user_role` — asignaciones activas usuario↔rol

Estado dinámico: las asignaciones vigentes con sus fechas de inicio/fin. El árbol define el rol; esta tabla dice "el usuario X tiene el rol Y desde el lunes hasta diciembre".

```sql
-- Roles activos de un usuario ahora mismo
SELECT role_id, valid_from, valid_until, assignment_reason
FROM bauth.idn_user_role
WHERE user_id = :user_id
  AND valid_from <= now()
  AND (valid_until IS NULL OR valid_until > now());
```

Todo cambio de asignación emite `aud_event` tipo `ROLE_ASSIGN` o `ROLE_REVOKE`.

### 19.3 `dlg_delegation` — instancias de delegación en vuelo

El árbol D10/B10 define la *política* de delegación (qué roles pueden delegar, a quién, por cuánto tiempo, con qué restricciones). Esta tabla almacena las **instancias activas** de delegación — las que están en vuelo ahora mismo.

```sql
-- Delegaciones activas que afectan a un usuario
SELECT d.id, d.from_user_id, d.to_user_id, d.role_id,
       d.scope_restriction, d.expires_at
FROM bauth.dlg_delegation d
WHERE d.to_user_id = :user_id
  AND d.status = 'ACTIVE'
  AND d.expires_at > now();
```

---

## 20. PRIVILEGIOS

**Tablas CONSERVAR:** T-045 `privilege_domain` · T-046 `privilege_application` · T-047 `privilege_group` · T-048 `privilege_verb` · T-050 `privilege_atom` · T-051 `privilege_role` · T-052 `privilege_role_atom` · T-053 `privilege_user_atom` · T-054 `privilege_atom_compiled` · T-055 `privilege_atom_policy` · T-056/057/058 `privilege_atom_audit*` · T-062 `zone_application_map`

**Tabla ELIMINAR:** T-049 `bos_permiso_logico`

### 20.1 Los catálogos de vocabulario

`privilege_domain` (D00-D13+D98+D99), `privilege_application` (crm, hrms, bnotify...), `privilege_group` (SAM-128 Q1-Q4), `privilege_verb` (read/write/approve/emit...) son el vocabulario que el árbol usa. Solo lectura en runtime.

### 20.2 `privilege_atom` — cada `_ev()` del árbol compila a un átomo

Cada vez que el compilador AtomLang procesa un nodo `_ev()` del árbol (`crm.lead.write`, `hrms.employee.approve`), crea una fila aquí con el ID de 24 bits que identifica el átomo unívocamente.

```sql
-- ¿Existe el átomo crm.lead.write?
SELECT id, domain_id, app_id, verb_id, slug, bit_position
FROM bauth.privilege_atom
WHERE slug = 'crm.lead.write';
```

### 20.3 `privilege_role` + `privilege_role_atom` — el BitMask 64-bit

`privilege_role` vincula un rol con su máscara de 64 bits. `privilege_role_atom` materializa la asignación individual átomo→rol con su bit position. Juntas, el motor puede evaluar un permiso en < 0.5ns:

```sql
-- Evaluar si el rol tiene el permiso crm.lead.write
SELECT (pra.mask >> pa.bit_position) & 1 AS tiene_permiso
FROM bauth.privilege_role_atom pra
JOIN bauth.privilege_atom pa ON pa.id = pra.atom_id
WHERE pra.role_id = :role_id
  AND pa.slug = 'crm.lead.write';
```

**Quién escribe:** solo el compilador AtomLang al recompilar el árbol. No escribir desde handlers.

### 20.4 `privilege_user_atom` — sobrescrituras individuales

Overrides de átomo para un usuario específico (fuera del rol). Por ejemplo, el usuario Juan tiene acceso a `hrms.salary.read` aunque su rol VENDEDOR no lo tiene. Estas excepciones son C1 y pasan por el MVU.

### 20.5 `privilege_atom_compiled` — el output del compilador (fast-path PDP)

El IR compilado del árbol para evaluación rápida. El compilador AtomLang escribe aquí; el PDP lee de aquí. No escribir desde código de negocio.

### 20.6 `privilege_atom_policy` — el JSONB del árbol por átomo

El árbol completo de cada átomo en JSONB (la política XACML/ABAC). Esta es la fuente de verdad del PDP para condiciones complejas (geolocalización, temporal, SoD, etc.).

```sql
-- Obtener la política completa del átomo para evaluación PDP
SELECT policy_jsonb, combining_algorithm
FROM bauth.privilege_atom_policy
WHERE atom_id = :atom_id AND role_id = :role_id;
```

### 20.7 `privilege_atom_audit` — C3 de evaluaciones PDP (particionada)

Log WORM de cada evaluación del PDP. D11/B13 lo exige. El auditor puede reconstruir por qué el sistema dijo PERMIT o DENY en cualquier fecha.

```sql
-- ¿Por qué se denegó acceso al usuario X ayer?
SELECT atom_slug, decision, deny_reasons, ctx_id, evaluated_at
FROM bauth.privilege_atom_audit
WHERE user_id = :user_id
  AND decision = 'DENY'
  AND evaluated_at::date = '2026-07-18'
ORDER BY evaluated_at DESC;
```

### 20.8 Por qué se elimina T-049 `bos_permiso_logico`

Esta tabla intentaba ser una capa de alias entre el slug del árbol y un nombre de permiso "amigable". El árbol actual usa slugs directos y descriptivos (`app.crm/crm.lead.write`) — la capa de alias no añade valor y duplica el vocabulario sin fuente de verdad clara.

---

## 21. SOD

**Tablas ELIMINAR:** T-069 `fin_sod_rule` · T-070 `fin_decision_matrix` · T-129 `sod_validation_config` · T-130 `conflict_interest_policy`

**Por qué no existen:** el árbol D10/B12 contiene toda la lógica de Separación de Deberes:

| Lo que pretendía la tabla | Dónde vive en el árbol | Nodo/campo |
|--------------------------|------------------------|------------|
| Reglas SoD (roles incompatibles) | D10/B12 `incompatible_roles[]` | Átomos DENY con INTERSECT |
| Matriz de decisiones financieras | D3/B8 `sod_rules` + `transaction_limits` | Por rol, por monto |
| Configuración de validación SoD | D10/B12 `conflict_validation` | `evaluation_timing=REAL_TIME`, `check_scope=[DIRECT,INHERITED,DELEGATED]` |
| Política de conflicto de interés | D10/B12 `interest_conflicts` | Parentesco grado ≤2, declaración anual SOX §302 |

**Cómo leer las reglas SoD en código:**

```sql
-- Obtener roles incompatibles con el rol GERENTE_FINANZAS
SELECT node_value->>'incompatible_roles' AS incompatibles
FROM bauth.idn_roles_template
WHERE root_id = :gerente_fin_root_id
  AND domain_code = 'D10'
  AND node_key = 'incompatible_roles';
```

El compilador AtomLang genera los átomos DENY correspondientes en `privilege_atom_compiled` — el PDP evalúa SoD sin consultar ninguna tabla relacional.

---

## 22. AUTENTICACIÓN

**Tablas CONSERVAR:** T-034 `ath_config` · T-039 `ath_method` · T-075-089 (logs operacionales) · T-128 `ses_caep_config`

**Tablas ELIMINAR:** T-038 `ath_policy` · T-074 `ath_credential_policy` · T-115/116/117 `ath_auth_flow*`

### 22.1 `ath_config` — parámetros de infraestructura de auth (CONSERVAR)

Parámetros globales del motor de autenticación que no son política de rol: timeouts de TCP, tamaño de pool de conexiones, límites de concurrencia, configuración de WebAuthn RP. No es política de acceso — es configuración operacional del daemon.

```sql
-- Leer parámetro de infraestructura
SELECT value FROM bauth.ath_config WHERE key = 'webauthn_rp_id';
```

### 22.2 `ath_method` — catálogo de los 18 métodos (CONSERVAR)

Registro canónico de los 18 métodos de autenticación disponibles. D1/D2 `available_methods[]` del árbol los referencia por `method_id`. Sin esta tabla, el FK del árbol cuelga.

```sql
-- ¿El método TOTP está habilitado?
SELECT is_active, display_name, aal_level
FROM bauth.ath_method
WHERE slug = 'TOTP';
```

### 22.3 Los logs operacionales — estado dinámico (todos CONSERVAR)

Estas tablas no son política: son el **rastro operacional** de lo que ocurrió con credenciales reales:

| Tabla | Para qué | Cuándo INSERT |
|-------|----------|---------------|
| `ath_password_history` | No-repetición NIST 800-63B | Al cambiar contraseña (guarda hash Argon2id, no la contraseña) |
| `ath_password_screening` | Breach check | Al validar contraseña contra HaveIBeenPwned |
| `ath_mfa_enrollment` | Factores MFA activos por usuario | Al enrolar TOTP/WebAuthn/etc. |
| `ath_recovery_method` | Métodos de recuperación activos | Al configurar recuperación |
| `ath_recovery_challenge` | Desafíos activos (C4, TTL corto) | Al iniciar flujo de recuperación |
| `ath_binding` | Vínculos DPoP/mTLS activos | Al vincular token a dispositivo |
| `ath_revocation` | Revocaciones activas (SLA ≤30s) | Al revocar token o credencial |
| `ath_login_attempt` | Intentos de login (particionada) | En cada intento — lockout lo necesita |
| `ath_consent` | Consentimientos OAuth2 activos | Al otorgar consentimiento |
| `ath_rotation_log` | Rotaciones ejecutadas | Al rotar credencial |
| `ath_token_delivery` | Entregas de token por canal | Al entregar token por SMS/email/push |
| `ath_enrollment_log` | Log de enrolamientos | Al completar enrolamiento de método |
| `ath_federation_protocol` | Protocolos de federación (SAML/OIDC) | Al configurar proveedor de identidad externo |

**Patrón importante — `ath_login_attempt`:**

```sql
-- Contar intentos fallidos en los últimos 15 minutos (para lockout D1/B4)
SELECT COUNT(*) AS intentos_fallidos
FROM bauth.ath_login_attempt
WHERE user_id = :user_id
  AND outcome = 'FAILED'
  AND attempted_at >= now() - interval '15 minutes';
-- Si > threshold → lockout (el threshold viene de idn_tenant_config, no hardcodeado)
```

### 22.4 Por qué se eliminan T-038, T-074, T-115/116/117

| Tabla eliminada | Lo que pretendía | Dónde vive en el árbol |
|-----------------|-----------------|------------------------|
| `ath_policy` | Política de auth por contexto | D1/B4 — métodos, lockout, session, DPoP, scopes |
| `ath_credential_policy` | NIST 800-63B password policy | D9/B18 — `password_policy` + `enrollment_policy` + `rotation_policy` |
| `ath_auth_flow` | Flujos de auth (AAL) | D1/D2 `required_methods{}` con 4 subgrupos |
| `ath_auth_flow_method` | Métodos dentro del flujo | D1/D2 `available_methods[]` |
| `ath_step_up_rule` | Reglas RFC 9470 | D1/D2 `step_up_triggers` con `aggregate-strictest` |

```
❌ SELECT threshold FROM bauth.ath_policy WHERE context = 'login'
✅ SELECT node_value->>'lockout_threshold' FROM bauth.idn_roles_template
   WHERE root_id = :rol_root AND domain_code = 'D1' AND node_key = 'account_lockout_threshold'
```

---

## 23. SESIÓN

**Tablas CONSERVAR:** T-071 `ses_context` · T-072 `ses_context_switch` · T-073 `ses_superuser_context` · T-128 `ses_caep_config`

**Tabla ELIMINAR:** T-127 `ses_risk_policy`

### 23.1 `ses_context` — los ctx_id activos en tiempo real (C4)

El ctx_id es el identificador de contexto obligatorio en toda operación (SBOS-049). Esta tabla almacena los contextos activos. Es **clase C4** — estado efímero. Cuando expira, se elimina.

```sql
-- Verificar que un ctx_id es válido
SELECT user_id, tenant_id, role_id, risk_score, expires_at
FROM bauth.ses_context
WHERE ctx_id = :ctx_id AND expires_at > now();

-- Purgar contextos expirados (proceso periódico)
DELETE FROM bauth.ses_context WHERE expires_at < now();
-- + INSERT aud_event tipo CONTEXT_INVALIDATE por cada uno
```

### 23.2 `ses_context_switch` — trazabilidad de cambios de contexto

Log de cada vez que un usuario cambia de contexto (eleva privilegios, cambia de empresa, etc.). Es C4 con retención corta (el rastro relevante ya está en `aud_event` tipo `CONTEXT_SWITCH`).

### 23.3 `ses_superuser_context` — contextos SU activos

Subconjunto especial de `ses_context` para contextos de superusuario. Auditoría extra obligatoria en cada acceso con SU activo.

### 23.4 `ses_caep_config` — infraestructura CAEP (CONSERVAR)

Configuración real del servidor CAEP (RFC 9396): endpoints de suscriptores, secrets HMAC, formatos de evento. No es política de rol — es la infraestructura del bus de eventos de seguridad. El compilador emite señales CAEP en el post-commit (§8).

### 23.5 Por qué se elimina T-127 `ses_risk_policy`

D8/B17 `adaptive_policies` en el árbol tiene los tres umbrales de riesgo (0.50/0.70/0.90) con sus efectos y obligaciones. La política de riesgo es atributo del rol, no del sistema global.

```
❌ SELECT threshold FROM bauth.ses_risk_policy WHERE level = 'high'
✅ SELECT node_value->>'risk_threshold_high' FROM bauth.idn_roles_template
   WHERE root_id = :rol_root AND domain_code = 'D8' AND node_key = 'risk_threshold'
```

---

## 24. IDENTIDAD D00 — Catálogo Universal

**Tablas ELIMINAR:** T-107 `org_empresa` · T-108 `org_sucursal` · T-109 `org_pos_logico`

**Tablas CONSERVAR (nuevas [N]):** T-156 `idn_identity_entity` · T-157 `idn_identity_attribute` · T-158 `idn_identity_attribute_history` · T-159 `idn_identity_requirement` · T-160 `idn_identity_synonym` · T-161 `idn_identity_synonym_sync`

### 24.1 Por qué las tres tablas legacy ELIMINAN — el motor de identidad D00 las subsume

El manual 1.06 MANUAL-D00-IDENTIDAD v2.0 §4 define el **árbol de 5 niveles** de `idn_identity_entity`:

| Nivel | Tipo relevante | Qué reemplaza |
|-------|---------------|---------------|
| `bdomain` | `tipo='empresa'` | T-107 `org_empresa` — empresa del tenant |
| `bsubdomain` | `tipo='sucursal'` | T-108 `org_sucursal` — sucursal de empresa |
| `pos` | `tipo='caja'`, `tipo='punto_virtual'` | T-109 `org_pos_logico` — POS lógico SIN |

**La confirmación está en el ctx_id (SBOS-049 §3.1):**

```
tenant_id : empresa_id : sucursal_id : pos_logico : user_id : traceparent
    │           │             │             │
  tenant      bdomain_id  bsubdomain_id  pos_id
               ← entity_id de idn_identity_entity ─────────────────────→
```

Las capas 2, 3 y 4 del ctx_id son exactamente los `entity_id` de `idn_identity_entity`. No existe una tabla `org_empresa` separada — la empresa ES un nodo `bdomain` del catálogo universal.

**Los atributos fiscales (NIT, código SIN RND, actividad económica) no requieren tabla propia** — van en `idn_identity_attribute`:

```sql
-- Empresa (bdomain, tipo='empresa') en el catálogo universal
SELECT entity_id, nombre, slug
FROM bauth.idn_identity_entity
WHERE tenant_id = :tenant_id AND nivel = 'bdomain' AND tipo = 'empresa';

-- NIT de la empresa — en idn_identity_attribute
SELECT value_text AS nit
FROM bauth.idn_identity_attribute
WHERE entity_id = :bdomain_id
  AND category = 'tributario' AND attr_key = 'NIT';

-- Código SIN del POS — en idn_identity_attribute
SELECT value_text AS sin_codigo
FROM bauth.idn_identity_attribute
WHERE entity_id = :pos_id
  AND category = 'tributario' AND attr_key = 'codigo_sin';

-- Contexto completo para construir el ctx_id
SELECT e.entity_id, e.nivel, e.tipo, e.name, e.parent_id
FROM bauth.idn_identity_entity e
WHERE e.tenant_id = :tenant_id
  AND e.nivel IN ('bdomain', 'bsubdomain', 'pos')
ORDER BY e.nivel;
```

### 24.2 Tabla de comparación — legacy vs. nuevo

| Tabla eliminada | Lo que pretendía modelar | Reemplazo correcto |
|-----------------|-------------------------|--------------------|
| `org_empresa` (T-107) | Catálogo de empresas | T-156 `idn_identity_entity` (`nivel='bdomain', tipo='empresa'`) |
| `org_sucursal` (T-108) | Catálogo de sucursales | T-156 `idn_identity_entity` (`nivel='bsubdomain', tipo='sucursal'`) |
| `org_pos_logico` (T-109) | Puntos de operación SIN | T-156 `idn_identity_entity` (`nivel='pos', tipo='caja'`) + T-157 `idn_identity_attribute` (`category='tributario'`) |

### 24.3 T-156 `idn_identity_entity` — el árbol universal de entidades (C1)

**DDL:** `bauth_47__idn_identity_entity.sql` · **Referencia:** 1.06 §3/§4 · A.56 §2

**Qué almacena:** cada fila es UNA entidad del tenant — empresa, sucursal, POS, persona, vehículo, servidor, puerta, producto. El `nivel` fija la capa jerárquica; el `tipo` dice qué clase de entidad es. La combinación `nivel+tipo` reemplaza toda tabla especializada anterior.

| Campo clave | Qué contiene | Regla |
|-------------|-------------|-------|
| `entity_id` | UUID v7 — PK y referencia en ctx_id | INMUTABLE post-creación |
| `parent_id` | FK al nodo padre (adjacency list) | `null` solo para `nivel='tenant'` |
| `nivel` | `tenant/bdomain/bsubdomain/pos/actor` | Solo 5 valores — CHECK constraint |
| `tipo` | `empresa`, `sucursal`, `HUMAN`, `caja`, `servidor`... | Validado por D93 (T-159) |
| `slug` | Identificador único legible por humano | Único por `tenant_id + nivel` |

**Cuándo leer:**
```sql
-- Árbol completo del tenant (CTE recursiva — sin closure table)
WITH RECURSIVE arbol AS (
  SELECT entity_id, parent_id, nivel, tipo, nombre, 0 AS depth
  FROM bauth.idn_identity_entity
  WHERE tenant_id = :tenant_id AND parent_id IS NULL

  UNION ALL

  SELECT e.entity_id, e.parent_id, e.nivel, e.tipo, e.name, a.depth + 1
  FROM bauth.idn_identity_entity e
  JOIN arbol a ON a.entity_id = e.parent_id
  WHERE e.tenant_id = :tenant_id
)
SELECT * FROM arbol ORDER BY depth, nombre;

-- Obtener bdomain_id/bsubdomain_id/pos_id para construir el ctx_id
SELECT
  (SELECT entity_id FROM bauth.idn_identity_entity
   WHERE tenant_id=:tid AND nivel='bdomain'    AND slug=:empresa_slug)  AS empresa_id,
  (SELECT entity_id FROM bauth.idn_identity_entity
   WHERE tenant_id=:tid AND nivel='bsubdomain' AND slug=:sucursal_slug) AS sucursal_id,
  (SELECT entity_id FROM bauth.idn_identity_entity
   WHERE tenant_id=:tid AND nivel='pos'        AND slug=:pos_slug)      AS pos_id;
```

**Cuándo escribir:** nunca con `INSERT` directo. Solo vía `bauth.entidad.create()` / `bauth.entidad.update()` — el Motor de Identidad valida el `tipo` contra T-159 antes de persistir.

**NO hacer:**
- `INSERT INTO idn_identity_entity` desde handlers — viola el pipeline de validación D93
- `UPDATE entity_id` — es INMUTABLE; si cambió, crear nueva entidad y deprecar la anterior
- Crear nodos `nivel='actor'` para entidades no-humanas sin validar T-159 — el tipo debe estar en el catálogo D93

---

### 24.4 T-157 `idn_identity_attribute` — atributos EAV (C1)

**DDL:** `bauth_47__idn_identity_entity.sql` · **Referencia:** 1.07 §3 · A.56 §3

**Qué almacena:** cualquier atributo de cualquier entidad — NIT, email, teléfono, dirección, código SIN, placa, IP, certificación, medida antropométrica. Sin ALTER TABLE para nuevos atributos. Particionado HASH por `tenant_id`.

| Campo clave | Qué contiene | Regla |
|-------------|-------------|-------|
| `entity_id` | FK lógica a T-156 | Obligatorio |
| `category` | Categoría del atributo: `contacto`, `identificacion`, `tributario`, `laboral`, `comercial`... | Define el grupo de atributos |
| `attr_key` | Nombre del atributo: `email`, `NIT`, `telefono`, `placa`, `codigo_sin`... | Libre dentro de la categoría |
| `type` | Subtipo explícito: `work`, `home`, `fiscal`, `mobile`, `emergency`... | Permite múltiples del mismo `attr_key` |
| `atom_code` | `NULL` = libre · `NOT NULL` = controlado por BitMask | Si `NOT NULL`, el BitMask gobierna quién lee/edita |
| `ctx_id` | Contexto de la operación (SBOS-049) | NOT NULL — rechaza sin ctx_id |
| `value_normalized` | GENERATED: `lower(unaccent(value_text))` | Búsqueda fuzzy pg_trgm GIN <100ms |
| `value_search` | GENERATED: `to_tsvector('spanish', ...)` | Full-text GIN <50ms |

**Pipeline de escritura — NUNCA omitir:**
```
bauth.identidad.atributo.set(entity_id, category, attr_key, type, value, ctx_id)
  ├── 1. format   → normaliza a formato canónico (E.164, ISO 8601, etc.)
  ├── 2. validate → valida contra reglas AtomLang (regex, rango, enum)
  ├── 3. verify   → verifica contra fuente externa si aplica (SIN, SEGIP, ADSIB)
  └── 4. INSERT/UPDATE en T-157 + INSERT automático en T-158
```

**Cuándo leer:**
```sql
-- Todos los atributos de una entidad (empresa)
SELECT category, attr_key, type, value_text, value_data, is_verified, verified_by
FROM bauth.idn_identity_attribute
WHERE entity_id = :entity_id
ORDER BY category, attr_key, type;

-- NIT fiscal de una empresa (búsqueda exacta)
SELECT value_text AS nit, is_verified, verified_by
FROM bauth.idn_identity_attribute
WHERE entity_id = :empresa_id
  AND category = 'tributario' AND attr_key = 'NIT' AND type = 'fiscal';

-- Búsqueda fuzzy: "tolota" encuentra TOYOTA
SELECT e.name, a.value_text
FROM bauth.idn_identity_attribute a
JOIN bauth.idn_identity_entity e ON e.entity_id = a.entity_id
WHERE a.attr_key = 'marca'
  AND a.value_normalized % lower(unaccent(:query))   -- pg_trgm similarity
ORDER BY similarity(a.value_normalized, lower(unaccent(:query))) DESC
LIMIT 10;

-- Búsqueda full-text: "foco del izquierdo"
SELECT e.name, a.value_text
FROM bauth.idn_identity_attribute a
JOIN bauth.idn_identity_entity e ON e.entity_id = a.entity_id
WHERE a.value_search @@ to_tsquery('spanish', :query)
LIMIT 10;
```

**NO hacer:**
- `INSERT INTO idn_identity_attribute` directo — viola el pipeline validate→verify
- Guardar secretos (`password`, `token`, `private_key`) — NRS-10: secrets nunca en C1/C2
- Dejar `ctx_id = NULL` o `ctx_id = ''` — viola SBOS-049; el constraint lo rechaza
- Usar `type = NULL` cuando hay subtipos relevantes — dificulta búsquedas y duplica filas

---

### 24.5 T-158 `idn_identity_attribute_history` — trazabilidad WORM (C3)

**DDL:** `bauth_47__idn_identity_entity.sql` · **Referencia:** A.56 §3.5 · 5.01 §3

**Qué almacena:** cada INSERT/UPDATE/DELETE en T-157 genera automáticamente una fila en esta tabla vía trigger. Registra: `entity_id`, `attr_key`, `type`, `old_value`, `new_value`, `changed_by`, `changed_at`, `ctx_id`, `operation` (INSERT/UPDATE/DELETE). Particionado RANGE mensual.

**Reglas absolutas:**
- **NUNCA** `DELETE` ni `UPDATE` en esta tabla — es WORM (Write Once Read Many)
- GDPR Art. 17 (derecho al olvido): anonimizar `value_text = '[ANONIMIZADO]'`, NO borrar la fila
- El trigger es el único escritor — ningún handler debe INSERT aquí directamente

**Cuándo leer:**
```sql
-- Historial completo de cambios de una entidad
SELECT attr_key, type, old_value, new_value, changed_by, changed_at, operation
FROM bauth.idn_identity_attribute_history
WHERE entity_id = :entity_id
ORDER BY changed_at DESC;

-- ¿Quién cambió el NIT de esta empresa y cuándo?
SELECT old_value, new_value, changed_by, changed_at, ctx_id
FROM bauth.idn_identity_attribute_history
WHERE entity_id = :empresa_id
  AND attr_key = 'NIT'
ORDER BY changed_at DESC;

-- Anonimizar atributo PII (GDPR Art. 17) — nunca DELETE
UPDATE bauth.idn_identity_attribute_history
SET new_value = '[ANONIMIZADO-GDPR-ART17]',
    old_value = '[ANONIMIZADO-GDPR-ART17]'
WHERE entity_id = :entity_id
  AND attr_key IN ('email', 'telefono', 'CI');
```

---

### 24.6 T-159 `idn_identity_requirement` — completitud mínima IAL (C1)

**DDL:** `bauth_47__idn_identity_entity.sql` · **Referencia:** A.56 §3.6 · 1.06 §6

**Qué almacena:** qué atributos son obligatorios para cada combinación `nivel + tipo` según el nivel IAL (1=funcional, 2=verificado, 3=completo). El Motor de Identidad consulta esta tabla ANTES de crear cualquier entidad — si faltan atributos requeridos, la creación falla.

**Cuándo leer (solo el Motor de Identidad lo hace directamente):**
```sql
-- ¿Qué atributos necesita una empresa (bdomain) en IAL2?
SELECT attr_key, type, required, ial_level, description
FROM bauth.idn_identity_requirement
WHERE nivel = 'bdomain' AND tipo = 'empresa' AND ial_level <= 2
ORDER BY ial_level, attr_key;

-- Verificar completitud de una entidad antes de activarla
SELECT
  r.attr_key,
  r.type,
  r.ial_level,
  (a.entity_id IS NOT NULL) AS tiene_atributo,
  a.is_verified
FROM bauth.idn_identity_requirement r
LEFT JOIN bauth.idn_identity_attribute a
  ON a.entity_id = :entity_id
 AND a.attr_key   = r.attr_key
 AND (r.type IS NULL OR a.type = r.type)
WHERE r.nivel = :nivel AND r.tipo = :tipo AND r.ial_level <= :ial_requerido
ORDER BY r.ial_level, r.attr_key;
```

**Quién escribe:** solo D93 (catálogo de tipos, administrable desde el dashboard). Ningún handler de bAuth inserta aquí directamente.

---

### 24.7 T-160 `idn_identity_synonym` + T-161 `idn_identity_synonym_sync` — búsqueda semántica (C1/C4)

**DDL:** `bauth_47__idn_identity_entity.sql` · **Referencia:** A.56 §3.9

**T-160 qué almacena:** sinónimos y abreviaturas por `(tenant_id, pais, industria, tipo, palabra)`. Ejemplo: `palabra='foco del izq'` → `terminos=['Farol Delantero Izquierdo', 'Faro Frontal Izquierdo']`. Es la fuente de verdad de los archivos `.syn` que PostgreSQL usa para full-text.

**T-161 qué almacena:** una única fila con `last_sync_at`. Un trigger en T-160 detecta cambios (`updated_at > last_sync_at`) y regenera los archivos `.syn` desde los datos — los archivos nunca se editan a mano.

**Cuándo leer T-160:**
```sql
-- Sinónimos activos de autopartes para Bolivia
SELECT palabra, terminos
FROM bauth.idn_identity_synonym
WHERE tenant_id = :tenant_id
  AND pais = 'BO'
  AND industria = 'autopartes'
  AND is_active = true
ORDER BY palabra;
```

**Cuándo escribir T-160:** solo desde el dashboard D93 (panel de sinónimos). El trigger actualiza T-161 automáticamente y programa la regeneración de `.syn`.

**NO hacer:**
- Editar archivos `.syn` de PostgreSQL a mano — T-160 es la fuente de verdad; los archivos se regeneran desde ella
- `DELETE` en T-160 — marcar `is_active = false` en su lugar para mantener historial
- Escribir en T-161 directamente — es exclusivo del trigger de T-160

---

### 24.8 Errores comunes del grupo IDENTIDAD D00

| Error | Consecuencia | Corrección |
|-------|-------------|------------|
| `INSERT` directo en T-156 sin pasar por `bauth.entidad.create()` | Nodo sin validación D93 — tipo inválido, niveles inconsistentes | Siempre via API del Motor de Identidad |
| `INSERT` directo en T-157 sin pipeline validate→verify | Atributo sin normalizar, sin verificación SIN/SEGIP, sin evento en T-158 | Usar `bauth.identidad.atributo.set()` |
| Guardar secreto en `value_text` de T-157 | Violación NRS-10 — secreto en tabla C1 | Secretos van a Vault; solo el hash o referencia en T-157 |
| `DELETE` en T-158 para "limpiar" datos PII | Rompe trazabilidad WORM; viola ISO 27001 A.8.15 y GDPR Art. 30 | Anonimizar con `UPDATE … SET value = '[ANONIMIZADO]'` |
| Omitir `ctx_id` al escribir en T-157 | NOT NULL constraint falla; SBOS-049 violado | Propagar el ctx_id del request entrante |
| Crear entidad con `tipo` no registrado en T-159 | El Motor de Identidad rechaza con `tipo_invalido` | Registrar el tipo en D93 primero |
| Leer T-157 sin pasar por el BitMask | Atributos protegidos (`atom_code NOT NULL`) devueltos sin control de acceso | Usar `bauth.identidad.atributo.get()` — el Motor aplica BitMask automáticamente |

---

## 25. FINANCIERO

**Tablas CONSERVAR:** T-027 `fin_transaction_type` · T-031 `fin_approval` · T-032 `fin_document_operation`

**Tablas ELIMINAR:** T-028 `fin_limit` · T-029 `fin_approval_chain` · T-030 `fin_approval_level` · T-033 `fin_role_permission`

### 25.1 Qué se conserva y por qué

| Tabla | Razón | Cuándo usar |
|-------|-------|-------------|
| `fin_transaction_type` | Catálogo de tipos de transacción — D3/B8 lo referencia por ID | Al validar el tipo de operación |
| `fin_approval` | **Instancias activas** de aprobación en vuelo — el árbol define la política, esta tabla almacena las instancias reales | Al ejecutar `ver_proposal.approve` financiero |
| `fin_document_operation` | Log operacional de operaciones ejecutadas sobre documentos financieros | Al registrar una operación completada |

```sql
-- Aprobaciones pendientes de una operación financiera
SELECT id, operation_id, approver_role, approved_by, approved_at, notes
FROM bauth.fin_approval
WHERE operation_id = :op_id AND status = 'PENDING'
ORDER BY approval_level;
```

### 25.2 Por qué se eliminan T-028, T-029, T-030, T-033

| Tabla | Qué pretendía | Dónde vive ahora |
|-------|--------------|-----------------|
| `fin_limit` | Límites financieros por rol | D3/B8 `transaction_limits` en el árbol: `single`, `daily`, `monthly`, `dual_approval` vía `@bauth_config_param` |
| `fin_approval_chain` | Cadenas de aprobación | D0/B3 `approval_workflow` en el árbol: quórum, SLA, escalación, canal bNotify |
| `fin_approval_level` | Niveles de aprobación por monto | D3/B8 `requiredMethods_financial`: 3 niveles por monto con step-up |
| `fin_role_permission` | Permisos financieros por rol | D1/B7 CAPA 1 `model_access` en el árbol: CRUD por modelo por app |

---

## 26. FÍSICO

**Tablas CONSERVAR:** T-023 `fis_device` · T-024 `fis_controller`

**Tablas ELIMINAR:** T-020 `fis_location` · T-021 `fis_location_closure` · T-022 `fis_area_config` · T-025 `fis_access_zone` · T-026 `fis_zone_member` · T-122 `fis_zone_method_requirement` · T-123 `fis_emergency_config`

### 26.1 Solo el hardware real sobrevive (CONSERVAR)

El árbol D2 (`zones_access_rules`, dart:1431-1458) define la **política** de acceso físico: qué zonas existen, qué decisión PERMIT/DENY aplica a cada una, qué nivel de seguridad tienen, qué métodos MFA se exigen. D0 (`metadata.region`/`territory_code`, dart:249-250) define la **jerarquía territorial**. Por tanto, las únicas tablas que sobreviven en el grupo FÍSICO son aquellas que registran **inventario de hardware** que el árbol referencia como PIP pero no puede instanciar:

| Tabla | Qué registra | Por qué sobrevive |
|-------|-------------|-------------------|
| `fis_device` | Lectores OSDP, torniquetes, cámaras — serial, firmware, IP | El árbol referencia `device.has_nfc_reader` (dart:1332) como PIP; el valor viene de este catálogo. No es política: es el inventario físico real |
| `fis_controller` | Controladores OSDP 2.2 — IP, puerto, certificado, firmware | Infraestructura de hardware que el árbol no puede expresar; el PDP la consulta para validar la fuente del evento de acceso |

```sql
-- El PDP consulta si el dispositivo tiene lector NFC antes de evaluar D2
SELECT d.has_nfc_reader, d.firmware_version, d.osdp_version
FROM bauth.fis_device d
WHERE d.device_id = :device_id AND d.active = true;
```

### 26.2 Por qué se eliminan T-020, T-021, T-022, T-025, T-026

El árbol D0+D2 ya provee todo lo que estas tablas modelaban:

| Tabla eliminada | Qué pretendía modelar | Dónde vive en el árbol |
|-----------------|----------------------|------------------------|
| `fis_location` (T-020) | Jerarquía de ubicaciones (edificio/piso/sala) | D0 `metadata.region`/`territory_code` (dart:249-250) + `parent_id`/`path_ids` (dart:246) — la jerarquía organizacional-territorial ya está en el árbol |
| `fis_location_closure` (T-021) | Cierre transitivo de la jerarquía de ubicaciones | `path_ids[]` en D0 B1 (dart:246) ya materializa el camino completo — el cierre es una consulta de array, no una tabla separada |
| `fis_area_config` (T-022) | Nivel de seguridad física por área | Atributo del nodo de zona en D2 `zones_access_rules` (dart:1431-1458): cada nodo zona tiene su `physical_security_level` embebido; `physical_security_controls` (dart:1460-1481) cubre reglas por área |
| `fis_access_zone` (T-025) | Catálogo de zonas: `PHY_ZONE_VENTAS`, `PHY_ROOM_SERVIDOR`, etc. | Los nodos `_ev(zone.id == 'PHY_ZONE_VENTAS')` en D2 `zones_access_rules` (dart:1431-1458) **son** el catálogo. El compilador AtomLang los extrae |
| `fis_zone_member` (T-026) | Membresía rol→zona (qué roles acceden a qué zona) | Las decisiones PERMIT/DENY de `zones_access_rules` (dart:1431-1458) **son** la membresía. `PHY_ZONE_VENTAS → PERMIT`, `PHY_ROOM_SERVIDOR → DENY` ya definen quién entra y quién no |

### 26.3 Por qué se eliminan T-122 y T-123

| Tabla eliminada | Qué pretendía | Dónde vive en el árbol |
|-----------------|--------------|------------------------|
| `fis_zone_method_requirement` (T-122) | Requerimientos de MFA por zona física | D2 `mfa_auth{}` (dart:1340-1365): `required_if=zone.physical_security_level >= 3`, `methods=[BIOMETRIC, HARDWARE_TOKEN]` |
| `fis_emergency_config` (T-123) | Config de emergencia física | D2 `alternative_methods[emergency_override]` (dart:1396-1428): doble autorización + auditoría CISO obligatoria |

### 26.4 Cómo leer una política de acceso físico

```sql
-- El árbol ES la política: leer el nodo D2 del rol
SELECT
  (tree_data -> 'domains' -> 'D2' -> 'zones_access_rules') AS zonas,
  (tree_data -> 'domains' -> 'D2' -> 'physical_security_controls') AS controles,
  (tree_data -> 'domains' -> 'D2' -> 'mfa_auth') AS mfa
FROM bauth.idn_roles_template
WHERE role_code = :role_code AND active = true;
```

---

## 27. GEOLOCALIZACIÓN

**Tablas CONSERVAR:** T-135 `geo_location_log` · T-136 `geo_evaluation_log`

**Tablas ELIMINAR:** T-132 `geo_trust_tier` · T-133 `geo_velocity_policy` · T-134 `geo_fence`

### 27.1 Los logs geográficos son estado dinámico (CONSERVAR)

`geo_location_log` registra las ubicaciones reales registradas en tiempo real (GPS/IP). `geo_evaluation_log` registra las evaluaciones geográficas ejecutadas por el PDP. Son C3 — WORM, append-only.

```sql
-- Última ubicación conocida de un usuario (para impossible travel)
SELECT latitude, longitude, source_ip, accuracy_meters, recorded_at
FROM bauth.geo_location_log
WHERE user_id = :user_id
ORDER BY recorded_at DESC
LIMIT 1;

-- Evaluación geográfica que rechazó un acceso
SELECT evaluation_result, deny_reason, distance_km, velocity_km_h
FROM bauth.geo_evaluation_log
WHERE ctx_id = :ctx_id AND evaluation_result = 'DENY';
```

### 27.2 Por qué se eliminan T-132, T-133, T-134

| Tabla | Qué pretendía | Dónde vive |
|-------|--------------|-----------|
| `geo_trust_tier` | Niveles de confianza por tipo de ubicación | D6/B15 `allowed_locations[]`: `office=2`, `vpn=2`, `home=1` |
| `geo_velocity_policy` | Impossible travel | D6 `velocidad imposible` con `@bauth_config_param.max_velocity_km_h` |
| `geo_fence` | Geocercas de acceso | D6/B15 `allowed_locations[]` con CIDRs y reglas de validación |

---

## 28. RED/ZTNA

**Tabla CONSERVAR:** T-113 `net_device`

**Tabla ELIMINAR:** T-126 `net_ztna_policy`

### 28.1 `net_device` — el registro real de dispositivos de red (CONSERVAR)

Dispositivos de red registrados: routers, switches, firewalls, VPN concentrators. D7/B16 `compliance_checks` los evalúa. Sin esta tabla, el árbol no tiene sobre qué evaluar el cumplimiento de red.

```sql
-- Verificar cumplimiento del dispositivo en el checklist ZTNA
SELECT device_type, os_version, patch_level, last_seen,
       mdm_enrolled, disk_encrypted, firewall_enabled
FROM bauth.net_device
WHERE device_fingerprint = :fp AND tenant_id = :tenant_id;
```

### 28.2 Por qué se elimina T-126 `net_ztna_policy`

D7/B16 en el árbol tiene política ZTNA completa: `device_compliance_checks` (5 controles: MDM, cifrado, firewall, parche, antivirus) + `api_gateway_rules` (rate_limit, CIDR allowlist, mTLS). La política es del rol, no un parámetro global de red.

---

## 29. AUDITORÍA

**Tablas:** T-091–T-098

El grupo AUDITORÍA tiene dos tipos de tablas: las que sobreviven (estado operacional / evidencia real) y las que se eliminan (política que ya vive en el árbol). La distinción clave es: **el árbol define la POLÍTICA de auditoría; las tablas de este grupo almacenan las INSTANCIAS y EVIDENCIAS**.

### 29.1 Dónde vive la política de auditoría en el árbol

Dos secciones del árbol `rol_template_datos.dart` definen TODO lo relativo a auditoría del rol:

**B1 `audit` — líneas 259-270** — trazabilidad del ARTEFACTO del rol:
```dart
NodoTemplate('audit', TipoNodo.objeto, hijos: [
  _a('version_number', '7'),
  NodoTemplate('change_history[]', TipoNodo.lista,
      help: '{version, date, changed_by, approved_by, changes[], reason, security_impact}.',
      hijos: [...]),
])
```
Este contrato semántico materializa en `ver_history` (C2). El evento C3 va a `aud_event` tipo `POLICY_CHANGE`. No hace falta una tercera tabla.

**D11 · B13 `change_tracking` — líneas 2237-2286** — política de auditoría del ROL:
```dart
NodoTemplate('D11 · AUDITORÍA', TipoNodo.dominio, hijos: [
  NodoTemplate('B13 · Cumplimiento y auditoría', TipoNodo.bloque, hijos: [
    _en('review_frequency', 'QUARTERLY', ...),  // ← política, no instancia
    NodoTemplate('review_scope[]', ...),          // ← qué auditar
    NodoTemplate('reviewers[]', ...),             // ← quiénes auditan
    NodoTemplate('regulatory_frameworks', ...),   // ← PCI/RGPD/SOX/ISO por ROL
    NodoTemplate('change_tracking', TipoNodo.politica, hijos: [
      _ev('retención mínima 7 años', [...]),
      _ev('WORM obligatorio', [...]),
      _ev('integridad hash-chain', [...]),
    ]),
  ]),
])
```

### 29.2 Decisión por tabla

| Tabla | Decisión | Razón |
|-------|----------|-------|
| **T-091** `aud_event` (+ T-092/093 particiones) | **CONSERVAR** | C3 — almacena los EVENTOS reales ocurridos ("¿qué pasó?"). El árbol D11/B13 define la POLÍTICA de auditar; `aud_event` guarda los hechos concretos. Son capas distintas e irreemplazables. Ver §2 y §7. |
| **T-094** `aud_review` | **CONSERVAR** | Estado dinámico — instancias REALES de la revisión trimestral ejecutada (ISO A.9.2.5/AC-2). D11/B13 `review_frequency=QUARTERLY` define cuándo revisar (árbol/política); esta tabla registra CUÁNDO se ejecutó, quién revisó y el resultado (instancia operacional). |
| **T-095** `aud_ghost_account` | **CONSERVAR** | Estado dinámico — resultados operacionales del proceso de privilege_creep detection. No es política del rol sino evidencia de corridas ejecutadas en tiempo real. |
| **T-096** `aud_policy_change` | **ELIMINAR** | El árbol B1 `change_history[]` (dart:264) define el contrato semántico completo `{version, changed_by, approved_by, changes[], reason, security_impact}`. Ese contrato materializa en `ver_history.fields_changed` (C2 — "¿cómo era?") y el evento va a `aud_event` tipo `POLICY_CHANGE` (C3 — "¿qué pasó?"). Una tercera tabla para el mismo dato es duplicación. Reemplazo: T-152 `ver_history` + T-091 `aud_event`. |
| **T-097** `aud_policy_version` | **ELIMINAR (F5)** | El árbol B1 `version_number` (dart:263) + `change_history[]` (dart:264) definen el historial de versiones del contrato. `ver_history` (T-152) lo materializa con `WITHOUT OVERLAPS` PG18, hash-chain WORM y `standard_ref`. En F5 del MVU `ver_history` se extiende a `cfg_policy_library` subsumiendo completamente esta tabla. Retener hasta que F5 esté aplicado en VPS. |
| **T-098** `aud_compliance_map` | **CONSERVAR** | Infraestructura a nivel SISTEMA — mapea qué controles cubre bAuth en conjunto (AU-3, A.8.15, PCI Req 10…). Distinto de D11/B13 `regulatory_frameworks` (dart:2258-2264) que opera a nivel ROL ("el VENDEDOR debe cumplir PCI Req 7/8/10"). Son dimensiones ortogonales: árbol = por rol / esta tabla = cobertura sistémica. |

### 29.3 Regla de uso

Toda operación que modifique una definición C1 produce dos inserciones en la misma transacción (paso 7 de la transición atómica, §8):
1. `ver_history` — el estado que se cierra (C2)
2. `aud_event` — el evento que ocurrió (C3)

Los handlers no emiten `aud_event` manualmente si usan el motor MVU — el motor lo emite. Solo emitir manualmente en operaciones fuera del MVU (evaluaciones PDP, accesos físicos, intentos de login).

---

## 30. BLOCKCHAIN

**Tablas:** T-100 `blk_anchor` · T-101 `blk_merkle_batch` · T-102 `blk_merkle_leaf` · T-103 `blk_account` · T-104 `blk_reconciliation`

**Todas CONSERVAR.** Son la capa de verificación de integridad sobre Besu QBFT.

### 30.1 Para qué sirven

| Tabla | Para qué | Quién escribe |
|-------|----------|--------------|
| `blk_anchor` | Anclas reales en Besu — hash del lote Merkle anclado on-chain | bAuth reconcile loop |
| `blk_merkle_batch` | Lotes Merkle generados: N eventos de auditoría → 1 raíz Merkle | Motor de blockchain |
| `blk_merkle_leaf` | Hojas individuales: 1 evento de auditoría = 1 hoja | Motor de blockchain |
| `blk_account` | Wallets Besu por rol (D12 `wallet_policy`) | Motor de identidad |
| `blk_reconciliation` | Registro de reconciliaciones ejecutadas: ¿el on-chain coincide con el local? | Motor de reconciliación |

### 30.2 Flujo: de `aud_event` a la cadena

```
aud_event (C3)
    ↓ Motor de blockchain acumula N eventos
blk_merkle_leaf (1 hoja por evento)
    ↓ Calcula raíz Merkle del lote
blk_merkle_batch (el lote con su raíz)
    ↓ Ancla la raíz en Besu QBFT
blk_anchor (transacción on-chain + tx_hash)
    ↓ Reconcile loop verifica periódicamente
blk_reconciliation (resultado: OK o DRIFT_DETECTED → aud_event)
```

**Cuándo usar:**

```sql
-- Verificar que un evento de auditoría está anclado en blockchain
SELECT ba.tx_hash, ba.block_number, ba.anchored_at
FROM bauth.blk_anchor ba
JOIN bauth.blk_merkle_batch mb ON mb.id = ba.batch_id
JOIN bauth.blk_merkle_leaf ml ON ml.batch_id = mb.id
WHERE ml.aud_event_id = :event_id;
```

---

## 31. SEGURIDAD

**Tablas:** T-035 `bos_crypto_algorithm` · T-110 `sec_key_inventory` · T-111 `sec_key_rotation` · T-112 `sec_key_recovery`

**Todas CONSERVAR.** Son la infraestructura criptográfica real.

| Tabla | Para qué | Cuándo usar |
|-------|----------|-------------|
| `bos_crypto_algorithm` | Catálogo de algoritmos: EdDSA/Ed25519, RSA-SHA256, Dilithium — B1 digital_signature los referencia | Al validar que el algoritmo requerido existe |
| `sec_key_inventory` | Inventario de claves en Vault: key_id, tipo, rotación programada | Al obtener el key_id para firmar un JWT |
| `sec_key_rotation` | Log de rotaciones ejecutadas: cuándo se rotó, quién aprobó | Al auditar el ciclo de vida de claves |
| `sec_key_recovery` | Procedimiento de recuperación de claves (D12 `rotate_in_vault`) | En escenarios de disaster recovery |

**NRS-10 CRÍTICO:** ninguna clave real (material privado) puede estar en estas tablas. Solo key_ids de Vault, referencias y metadatos.

```sql
-- Obtener el key_id activo para firmar JWTs (Ed25519 interno)
SELECT key_id, algorithm_id, valid_until
FROM bauth.sec_key_inventory
WHERE key_type = 'JWT_SIGNING' AND status = 'ACTIVE'
  AND (valid_until IS NULL OR valid_until > now())
ORDER BY created_at DESC
LIMIT 1;
```

---

## 32. DISPOSITIVOS

**Tablas:** T-137 `user_client_device` · T-138 `ctx_transfer_log` · T-139 `qr_challenge_registry` · T-140 `mobile_heartbeat_log` · T-147 `mobile_app_config` · T-148 `device_attestation_log` · T-149 `push_token_registry` · T-150 `certificate_pin_config` · T-151 `token_refresh_log`

**Todas CONSERVAR.** Son el registro del mundo real de dispositivos cliente.

### 32.1 El catálogo de dispositivos conocidos

`user_client_device` registra los dispositivos conocidos (FIDO2) por usuario. D8 `new_device` evalúa si el dispositivo actual está en este registro. Sin esta tabla, el árbol no puede distinguir "dispositivo conocido" de "dispositivo nuevo".

```sql
-- ¿El dispositivo es conocido por el usuario?
SELECT is_trusted, last_seen, device_name
FROM bauth.user_client_device
WHERE user_id = :user_id AND device_fingerprint = :fp;
```

### 32.2 El registro QR (C4)

`qr_challenge_registry` almacena desafíos QR activos con TTL de 30 segundos. Es C4 — se purga automáticamente.

```sql
-- Verificar un desafío QR (debe existir y no estar expirado)
SELECT user_id, scope, created_at
FROM bauth.qr_challenge_registry
WHERE challenge_token = :token AND expires_at > now();
-- Inmediatamente después: DELETE el desafío (uso único)
DELETE FROM bauth.qr_challenge_registry WHERE challenge_token = :token;
```

### 32.3 Los logs de dispositivos — estado dinámico

| Tabla | Para qué |
|-------|----------|
| `ctx_transfer_log` | Transferencias de ctx_id entre dispositivos — trazabilidad de sesión multidevice |
| `mobile_heartbeat_log` | Heartbeat real de apps — D8 `device_posture` evalúa frecuencia |
| `device_attestation_log` | Atestaciones ejecutadas (FIDO2/MDM) — D7 MDM enrolled |
| `push_token_registry` | Tokens FCM/APNs por dispositivo — bNotify los necesita para MFA push |
| `certificate_pin_config` | Config de pinning por app — NRS-08 certificate pinning |
| `token_refresh_log` | Renovaciones de sesión — trazabilidad de cuándo se renovó un refresh_token |

---

## 33. ZONAS-UI

**Tablas ELIMINAR:** T-118 `zone_field_restriction` · T-119 `zone_button_rule` · T-120 `zone_record_rule` · T-121 `zone_data_policy`

**Por qué no existen:** el árbol D1/B7 tiene las 5 capas de control de UI completas:

| Tabla eliminada | Lo que pretendía | Dónde vive en el árbol |
|-----------------|-----------------|------------------------|
| `zone_field_restriction` | Campos ocultos/readonly por zona | B7 CAPA 3 `field_restrictions`: `margin` oculto, `credit_limit` readonly |
| `zone_button_rule` | Botones/acciones por zona | B7 CAPA 4 `button_rules`: tiers con PYSON, SoD en pagos, first-applicable |
| `zone_record_rule` | Registros visibles por zona | B7 CAPA 5 `record_rules`: filtros SQL `territory_code/owner_id/team_id` |
| `zone_data_policy` | Políticas de datos por zona | D1/B6: masking PII clientes, anti-exfiltración ventas, SoD financiero |

**Cómo lee el código estas reglas:**

```sql
-- Obtener las field_restrictions del rol VENDEDOR para el frontend
SELECT node_value->'field_restrictions' AS restricciones
FROM bauth.idn_roles_template
WHERE root_id = (SELECT id FROM bauth.idn_roles_template WHERE role_code = 'VENDEDOR' AND node_type = 'ROOT')
  AND domain_code = 'D1'
  AND node_key = 'field_restrictions';
-- El frontend aplica la restricción; no la busca en tabla relacional
```

---

## 34. CALENDARIO

**Tablas:** T-012 `cal_fiscal_year` · T-014 `cal_calendar` · T-015 `cal_event` · T-016 `cal_alarm` · T-017 `cal_notification_log` · T-018 `cal_holiday` · T-019 `cal_schedule` · T-124 `cal_overtime_policy` · T-125 `cal_break_policy`

**Todas CONSERVAR.** Son la infraestructura del servicio bcalendar.

**Por qué existen:** el árbol D4/B2 `validity_period` define cuándo un rol es válido ("lunes a viernes 09:00-18:00, no festivos"). Para evaluar esa condición, el PDP necesita saber si hoy es festivo, si estamos en horario laboral, si es el año fiscal activo. El árbol no almacena el calendario real — lo referencia.

| Tabla | Para qué el PDP la necesita | Cuándo leer |
|-------|---------------------------|-------------|
| `cal_fiscal_year` | ¿Estamos en el año fiscal activo? | Evaluaciones de autorización B8 |
| `cal_calendar` | ¿Qué calendario laboral usa este tenant/rol? | Resolución D4/B2 |
| `cal_event` | Eventos del calendario (reuniones, cierres) | bcalendar UI |
| `cal_alarm` | Alertas: review_date del rol vence en 30 días | Motor de revisión trimestral |
| `cal_holiday` | ¿Hoy es festivo? | D3 `transaction_schedule` — sin operaciones en festivos |
| `cal_schedule` | ¿Estamos en horario 09:00-16:00? | D3/B2 ventana horaria |
| `cal_overtime_policy` | Override de emergencia fuera de horario | D3/B2 excepción de emergencia |
| `cal_break_policy` | Ventanas de descanso | D4 sesión máxima sin descanso |
| `cal_notification_log` | Log de alertas enviadas | Trazabilidad de notificaciones bcalendar |

```sql
-- ¿Está el día de hoy dentro del horario laboral del tenant?
SELECT EXISTS(
    SELECT 1
    FROM bcalendar.cal_schedule s
    JOIN bauth.idn_tenant_calendar_assignment ca ON ca.calendar_id = s.calendar_id
    WHERE ca.tenant_id = :tenant_id
      AND EXTRACT(DOW FROM now()) = ANY(s.work_days)
      AND now()::time BETWEEN s.work_start AND s.work_end
) AND NOT EXISTS(
    SELECT 1
    FROM bcalendar.cal_holiday h
    WHERE h.calendar_id = (SELECT calendar_id FROM bauth.idn_tenant_calendar_assignment WHERE tenant_id = :tenant_id)
      AND h.holiday_date = CURRENT_DATE
) AS es_horario_laboral;
```

---

## 35. OIDC/IDP

**Tablas:** T-141 `idp_client` · T-142 `idp_client_policy` · T-143 `idp_token_config`

**Todas CONSERVAR.** Son la dimensión CLIENTE del servidor OIDC propio de bAuth.

### 35.1 El eje ROL vs. el eje CLIENTE — por qué no son redundantes

El árbol `idn_roles_template` es la **dimensión ROL**: qué scopes puede tener un rol, qué métodos de auth requiere, qué TTL de sesión tiene. Las tablas OIDC son la **dimensión CLIENTE**: qué aplicación OIDC es el cliente OAuth2, qué redirect_uris tiene registradas, qué grant_types puede usar.

El servidor OIDC de bAuth **intersecta ambas dimensiones** al emitir un token: el access_token tiene los scopes que son la intersección de `{scopes que puede pedir el cliente}` ∩ `{scopes que el rol del usuario tiene}`.

```
idp_client.allowed_scopes  ∩  idn_roles_template.D1.oauth_scopes  =  scopes en el token
```

### 35.2 Cuándo se usa en código

```sql
-- Registrar un nuevo cliente OIDC (aplicación que integrará con bAuth)
INSERT INTO bauth.idp_client (
    tenant_id, client_id, client_secret_hash,
    redirect_uris, grant_types, allowed_scopes,
    token_endpoint_auth_method
) VALUES (
    :tenant_id, 'mi-app-erp',
    argon2id(:secret),
    ARRAY['https://erp.empresa.com/callback'],
    ARRAY['authorization_code', 'refresh_token'],
    ARRAY['openid', 'profile', 'bauth.roles'],
    'client_secret_post'
);

-- Al validar un authorization_request: ¿el client_id puede pedir estos scopes?
SELECT 1
FROM bauth.idp_client c
JOIN bauth.idp_client_policy p ON p.client_id = c.id
WHERE c.client_id = :client_id
  AND :requested_scope = ANY(c.allowed_scopes)
  AND p.require_pkce = true; -- si es true, verificar code_challenge
```

### 35.3 `idp_token_config` — parámetros del servidor, no del rol

El árbol D1 `re_auth_policy` define la política de re-autenticación del ROL (ej: sesión máxima de 480 min). `idp_token_config` define los TTL de los tokens por CLIENTE (ej: access_token 15 min, refresh_token 7 días). Son capas ortogonales del protocolo OAuth2 — no se duplican.

```sql
SELECT access_token_ttl, refresh_token_ttl, id_token_ttl
FROM bauth.idp_token_config
WHERE client_id = :client_id;
```

---

## 36. VERSIONADO (Motor de Versionado Universal — MVU 1.13)

Las 4 tablas del MVU ya están documentadas en profundidad en la **Parte I** (§5-§10). Esta sección es el mapa de referencia rápida.

| Tabla | Clase | Sección de referencia |
|-------|-------|-----------------------|
| `ver_history` (T-152) | C2 | §2, §4.2, §5, §6, §8, §10 — La segunda mitad de la trazabilidad |
| `ver_proposal` (T-153) | C2/Dinámica | §9 — Cambios MAJOR pendientes de quórum |
| `ver_retention_schedule` (T-154) | Infraestructura | §10 — Plazos legales como dato consultable |
| `ver_template_changelog` (T-155) | Infraestructura | §5.2 — Transiciones de versión del contrato (v5→v6) |

**Estado DDL:** estas 4 tablas son `[N]` — diseñadas en el MVU (1.13 §8.2-8.3), sin DDL aplicado aún en la VPS (madurez L1). Las migraciones son `bauth_45__version_engine_core.sql` + `bauth_46__ver_history.sql`. La implementación Rust está en `src/domain/versioning/` (ver A.33).

---

## 37. Misceláneos

### 37.1 SINCRONIZACIÓN — T-099 `sync_log` (ELIMINAR)

Pretendía ser un log de sincronización. D99/B14 `sync_status` y `drift_details` en el árbol capturan el estado de sincronización del rol. Los eventos de sincronización van a `aud_event` tipo `SYNC_START/SYNC_COMPLETE/SYNC_ERROR/DRIFT_DETECTED`. Duplicar esto en `sync_log` no añade valor.

```
❌ INSERT INTO bauth.sync_log (entity, status, ...) VALUES (...)
✅ INSERT INTO bauth.aud_event (event_type='SYNC_COMPLETE', ...) VALUES (...)
   + UPDATE idn_roles_template SET sync_status = 'OK' WHERE ...  -- campo B14
```

### 37.2 CONFIG — T-036 `cfg_validation_rule` + T-037 `cfg_validation_log` (ELIMINAR)

`cfg_validation_rule` intentaba ser un catálogo de reglas de validación (IS_SET, BETWEEN, IN, NOT_IN, INCLUDES_ALL...). El nodo `evaluacion` de AtomLang cubre exactamente estos operadores como parte del árbol. `cfg_validation_log` duplicaría entonces `privilege_atom_audit` (las evaluaciones del PDP) y `aud_event`.

```
❌ SELECT rule FROM bauth.cfg_validation_rule WHERE field = 'monto'
✅ SELECT node_value FROM bauth.idn_roles_template
   WHERE node_type = 'evaluacion' AND domain_code = :dominio AND node_key = 'monto'
```

### 37.3 EMERGENCIA — T-144 `emergency_override_policy` (ELIMINAR)

La política de acceso de emergencia está completa en el árbol:
- D8 `emergency_access`: break-glass con doble aprobación, duración 4h, notificación CISO
- D2 `emergency_override`: autenticación de emergencia con override y auditoría WORM crítica

No hay nada que esta tabla aportaría que no esté ya en el árbol.

### 37.4 VISITANTES — T-145 `visitor_access_policy` (ELIMINAR) + T-146 `external_session_registry` (CONSERVAR)

`visitor_access_policy` intentaba definir la política de acceso de visitantes. D2/B5 `re_auth_policy` en el árbol tiene: re-verificación cada 4h para visitantes/proveedores, max_session=480min. La política es del rol, no una tabla global.

`external_session_registry` CONSERVAR: es el estado dinámico de sesiones activas de usuarios externos (EXT_N0). El árbol define la política; esta tabla almacena las sesiones reales en vuelo.

```sql
-- Sesiones externas activas de visitantes (EXT_N0)
SELECT session_id, external_user_id, access_scope, expires_at
FROM bauth.external_session_registry
WHERE status = 'ACTIVE' AND expires_at > now()
ORDER BY created_at DESC;
```

### 37.5 LEGADO — T-131 `tryton_action_visibility` (ELIMINAR)

ADR-010: Tryton eliminado. Esta tabla era parte del sistema de visibilidad de acciones de Tryton. No tiene reemplazo en el árbol porque la funcionalidad que cubría (visibilidad de acciones de UI del ERP Tryton) ya no es relevante. Si hubiera necesidad de controlar visibilidad de acciones de un ERP soberano futuro, el árbol D1/B7 CAPA 4 `button_rules` es el mecanismo correcto.

### 37.6 VARIOS — T-044 `log_zone` (ELIMINAR)

Propósito indefinido — no referenciado en ningún dominio del árbol ni en ningún manual. Los logs de zona de acceso van a `aud_event` con `event_type = 'ACCESS_GRANTED'` o `'ACCESS_DENIED'` y `resource_type = 'fis_access_zone'`.

---

## 38. Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-19 | Versión inicial — cubre el axioma de trazabilidad, las dos mitades (C3 eventos + C2 versionado), las 4 clases de información, los patrones de escritura por clase, el flujo del árbol RolTemplate, UserTemplate con RGPD Art. 17, patrón de emisión de eventos con iso_control[], la transición atómica de 9 pasos, flujo MAJOR con quórum, reglas de retención con KEEP_ANCHORS, las 33 tablas eliminadas, errores comunes, y mapa de relaciones. |
| 2.0.0 | 2026-07-19 | Expansión mayor — se añade la Parte II con la guía completa de uso por grupo de tablas del A.62. Cubre los 26 grupos: GLOBAL, IDENTIDAD, ROLES, USUARIOS, PRIVILEGIOS, SOD, AUTENTICACIÓN, SESIÓN, ORGANIZACIÓN, FINANCIERO, FÍSICO, GEOLOCALIZACIÓN, RED/ZTNA, AUDITORÍA, BLOCKCHAIN, SEGURIDAD, DISPOSITIVOS, ZONAS-UI, CALENDARIO, OIDC/IDP, VERSIONADO, SINCRONIZACIÓN, CONFIG, EMERGENCIA, VISITANTES, LEGADO, VARIOS. Para cada grupo: qué es, por qué existe, cuándo usar en código, qué no tocar y por qué (la alternativa en el árbol). |
| 2.1.0 | 2026-07-19 | Corrección cruzada ROLES/AUDITORÍA — §11: 33→40 ELIMINADAS; se añaden T-044, T-064, T-065, T-066, T-067, T-068 con justificaciones del árbol; §3: se retira `aud_policy_change` de C3; §13: diagrama actualiza aud_policy_change como ELIMINAR; §14: referencia corregida A.62→A.65; §29 AUDITORÍA: reescritura completa con referencias al árbol (B1 dart:259-270 → ver_history; D11/B13 dart:2237-2286 → política; T-096/T-097 ELIMINAR justificado). |
| 2.2.0 | 2026-07-19 | Reevaluación cruzada FÍSICO — §11: 40→45 ELIMINADAS; se añaden T-020, T-021, T-022, T-025, T-026 con justificaciones del árbol D0+D2; §26 FÍSICO: reescritura completa — T-020/T-021/T-022/T-025/T-026 cambian de CONSERVAR a ELIMINAR porque D0 `metadata.region`/`territory_code` (dart:249-250) cubre la jerarquía territorial y D2 `zones_access_rules` (dart:1431-1458) cubre catálogo de zonas, membresía y nivel de seguridad; T-023/T-024 CONSERVAR como inventario de hardware OSDP (PIP del árbol); se añade §26.3 y §26.4 con SQL de consulta. |
| 2.3.0 | 2026-07-19 | Corrección ORGANIZACIÓN — §11: 45→48 ELIMINADAS; T-107/T-108/T-109 cambian de CONSERVAR a ELIMINAR; §24 ORGANIZACIÓN: reescritura completa — `org_empresa`/`org_sucursal`/`org_pos_logico` son redundantes porque `idn_identity_entity` (1.06 §4) con `nivel={bdomain/bsubdomain/pos}` ya ES el catálogo universal; confirmado por SBOS-049 §3.1: las capas 2/3/4 del ctx_id son exactamente los `entity_id` de `idn_identity_entity`; atributos fiscales (NIT, código SIN) van en `idn_identity_attribute`. |
| 2.4.0 | 2026-07-19 | ORGANIZACIÓN renombrada a IDENTIDAD D00 — se añaden 6 tablas nuevas [N] que reemplazan el grupo: T-156 `idn_identity_entity` · T-157 `idn_identity_attribute` · T-158 `idn_identity_attribute_history` · T-159 `idn_identity_requirement` · T-160 `idn_identity_synonym` · T-161 `idn_identity_synonym_sync`. DDL: bauth_47 (A.56). §24 añade §24.3 con guía de uso por tabla + SQL. CONSERVAR 107→113. |
| 2.5.0 | 2026-07-19 | §24 IDENTIDAD D00 — documentación completa de las 6 tablas nuevas. §24.3 T-156: árbol CTE recursiva, campos clave, cuándo leer/escribir, errores. §24.4 T-157: EAV pipeline validate→verify→persist, búsqueda fuzzy + full-text, NRS-10 secrets. §24.5 T-158: WORM, trigger, GDPR Art.17 anonimizar vs DELETE. §24.6 T-159: completitud IAL1/2/3, validación pre-creación. §24.7 T-160/T-161: sinónimos, archivos .syn, fuente de verdad. §24.8 errores comunes del grupo. TOC actualizado. |
| 2.6.0 | 2026-07-19 | §18 ROLES — reescritura completa. Distinción fundamental documentada: T-041 `idn_roles_rol_hierarchical` es REGISTRO de identidad de roles (B1: id, parent_id, tier, status, name, metadata, version, audit) — NO el árbol de políticas. T-162 `idn_roles_template` [N] es la tabla nueva que almacena el árbol B2-B14/D0-D13 compilado por AtomLang como JSONB. DDL propuesto: `bauth_65__idn_roles_template.sql`. Eliminaciones documentadas con justificaciones: T-043 (pre-MVU sin WORM), T-064 (EAV duplica nodos árbol T-162), T-065/066/067 (viola principio UN motor de historia), T-068 (completitud derivable por compilador). SQL de uso en §18.2 y §18.6. CONSERVAR 114 (T-162 sumada). |
| 2.7.0 | 2026-07-19 | §18 corrección arquitectónica — T-162 renombrada de `idn_roles_template` (JSONB por-rol, desechado) a `idn_roles_template` (árbol jerárquico compartido UN solo árbol para todos los roles). Principio A.64 §7: subject=SET/UNSET filtra el árbol por rol en runtime — no hay duplicación por rol. DDL completo propuesto: adjacency list + path LTREE + GIN sobre subject + GIN sobre unset. Tipos de nodo documentados (DOMAIN/POLICY_SET/POLICY/RULE/CONDITION/EFFECT/ATOM/OBLIGATION/PROPERTY), tabla de campos por tipo, 3 consultas SQL incluyendo política efectiva por rol. T-042 `idn_roles_rol_tier` corregida: no son "políticas de gobernanza" sino parámetros de autenticación por tier (mfa_methods[], session_timeout, step_up_allowed, nist_aal_ref). T-041 descripción corregida: solo QUIÉN ES, no QUÉ PUEDE. |
| 2.9.0 | 2026-07-19 | Reubicación de sección VERSIONADO — las 4 tablas MVU (T-152/153/154/155) se mantienen como sección propia pero se mueven en A.65 para quedar inmediatamente después de ROLES (no al final del documento). §36 VERSIONADO restaurada con su contenido original. §18.8 eliminada (era fusión incorrecta). El orden en A.65 ahora es: ROLES → VERSIONADO → USUARIOS → resto. |
| 2.10.0 | 2026-07-22 | §7.1 CORRECCIÓN SISTÉMICA DE NOMBRES — todo el documento actualizado para coincidir con los nombres canónicos del DDL V2: `idn_role_template` (T-041 context) → `idn_roles_rol_hierarchical`; `idn_roles_templates`/`idn_rolestpl_contrato` (T-162 context) → `idn_roles_template`; `idn_role_type` → `idn_roles_rol_type` (T-040); `idn_tier_policy` → `idn_roles_rol_tier` (T-042); `idn_role_closure` → `idn_roles_rol_closure` (T-063); columna `e.nombre` → `e.name` (JSONB en `idn_identity_entity`). Fuente de verdad: DDL V2 canónico. |
