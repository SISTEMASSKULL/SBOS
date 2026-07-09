# BAUTH — Origen Normativo de Datos del RolTemplate v6.0

**Fecha:** 2026-07-08  
**Versión:** 2.0 — con códigos de gap  
**Propósito:** Documento de reparación. Cada fila tiene un código único `G-B{bloque}-{seq}`. Código por código vamos aclarando, verificando y resolviendo hasta cobertura completa del RolTemplate v6.0.

---

## Mapa de normas

| Código | Norma | Bloques |
|--------|-------|---------|
| NIST-63B4 | NIST SP 800-63B-4 (2024) | B4, B20 |
| NIST-53-AC2 | NIST SP 800-53 Rev.5 AC-2 Account Management | B1, B2, B3, B10, B15 |
| NIST-53-AC5 | NIST SP 800-53 Rev.5 AC-5 Separation of Duties | B3, B12 |
| NIST-53-AC6 | NIST SP 800-53 Rev.5 AC-6 Least Privilege | B7, B10 |
| NIST-53-AU | NIST SP 800-53 Rev.5 AU-2/AU-3/AU-12 Audit | B13 |
| NIST-207 | NIST SP 800-207 Zero Trust Architecture | B4, B18, B19 |
| NIST-162 | NIST SP 800-162 ABAC Guide | B6, B17 |
| NIST-116 | NIST SP 800-116 PACS | B5 |
| NIST-76 | NIST SP 800-76-2 Biometrics PIV | B16 |
| ISO-24760 | ISO/IEC 24760-2:2025 Identity Management | B1 |
| ISO-27001 | ISO 27001:2022 Annex A | B1–B3, B5, B6, B13 |
| ISO-30107 | ISO/IEC 30107-3:2023 Biometric PAD | B16 |
| INCITS-359 | ANSI INCITS 359-2012 (R2022) RBAC | B1, B4, B6, B11, B12 |
| RFC-9470 | RFC 9470 Step-Up Authentication | B4, B19 |
| RFC-8693 | RFC 8693 OAuth 2.0 Token Exchange | B10 |
| RFC-8705 | RFC 8705 mTLS Certificate-Bound Tokens | B18 |
| RFC-7519 | RFC 7519 JWT Claims exp/nbf/iat | B15 |
| CAEP-10 | OpenID CAEP 1.0 Continuous Access Evaluation | B19 |
| PCI-40 | PCI DSS 4.0 Requirements 7–8–10 | B3, B6, B8, B13 |
| LEY-164 | Ley 164 Bolivia — Firma Digital | B1, B8, B21 |
| ADSIB | ADSIB-FD-POLT-015 v2.3 | B1, B21 |
| SIN-RND | SIN RND 102100000011 — Facturación electrónica | B8, B21 |

---

## Leyenda de estado

| Símbolo | Significado |
|---------|-------------|
| ✅ | En demo con datos reales |
| ⚠ | Hardcoded / parcial / texto fijo |
| ✗ | Ausente — no existe en ningún catálogo |

---

## SECCIÓN 1 — Gobernanza del Contrato

### B1 — Identificación y Metadatos del Rol

**Normas:** ISO-24760 · NIST-53-AC2 · ISO-27001-A5.15 · INCITS-359

---

**G-B01-01** · campo `id` · norma ISO 24760-2:2025 §5.2 · estado **⚠ Hardcoded**
Identificador único, persistente, no reutilizable. Una vez asignado no cambia aunque cambie el nombre del rol.

> **✅ RESOLUCIÓN G-B01-01 — 2026-07-08**
> **DDL:** `id uuid NOT NULL DEFAULT uuidv7() PRIMARY KEY`
> **Generado por:** PostgreSQL 18 nativo — función `uuidv7()` sin extensiones. La aplicación Rust **nunca asigna el `id`** — solo lo lee con `RETURNING id` después del INSERT.
> **Estándar:** RFC 9562 (IETF, mayo 2024) + ISO/IEC 9834-8. UUIDv7 = timestamp 48 bits (ms) + 12 bits sub-ms + 62 bits aleatorios.
> **Por qué no SERIAL/BIGINT:** el `id` circula en JWTs, logs de auditoría, contratos inter-daemon y eventos CAEP — debe ser opaco (no enumerable). Un entero secuencial permite enumeración.
> **Por qué no UUIDv4:** aleatorio, fragmenta el B-tree index. UUIDv7 es time-ordered → inserciones secuenciales → 10× más rápido (50M filas: 2 min vs 20 min en benchmark PG18).
> **Por qué no ULID:** no es estándar IETF/ISO. UUIDv7 = RFC 9562 ratificado, alineado con ISO 24760-2:2025.
> **Cumple ISO 24760-2:2025 §5.2:** único (2¹²² valores) · persistente (inmutable desde INSERT) · no reutilizable (UUID retirado permanece en audit log, jamás reasignado).

---

**G-B01-02** · campo `parent_id` · norma ANSI INCITS 359-2012 §3.2 RBAC1 · estado **⚠ Hardcoded**
Herencia jerárquica modelada como partial order. `parent_id` señala el rol senior del que hereda permisos. `null` = rol raíz.

> **✅ RESOLUCIÓN G-B01-02 — 2026-07-08**
> **DDL:** `parent_id uuid REFERENCES bauth.idn_role_template(id) ON DELETE RESTRICT`
> **NULL = rol raíz** (SU, BIZ_N1 CEO, EXT_N0 — sin padre). Los demás apuntan al nivel inmediatamente superior.
> **ON DELETE RESTRICT:** no se puede eliminar un rol padre con hijos activos — la jerarquía no se rompe silenciosamente.
> **Tipo uuid:** mismo tipo que `id` — la FK es siempre un uuidv7, nunca un string ni entero.
> **Herencia transitiva:** `parent_id` modela solo el vínculo directo. La cadena completa (abuelo, bisabuelo…) vive en `bauth.idn_role_closure` (closure table), recalculada por trigger al insertar o mover un rol.
> **Estándar:** ANSI INCITS 359-2012 §3.2 RBAC1 define la jerarquía como partial order — transitiva, antisimétrica, reflexiva. El closure table implementa esa semántica exacta en SQL.

---

**G-B01-03** · campo `type_id` · norma NIST SP 800-53 AC-2(a) · estado **✅ RESUELTO** — 2026-07-10

AC-2 exige identificar tipos de cuenta: individual, compartida, de grupo, de sistema, de emergencia, de servicio. `type_id` implementa este campo.

**Motivo del gap:** `type_id` era `text` sin FK, sin catálogo, con valores arbitrarios de negocio (`'TYPE-GERENCIA-MEDIA'`, `'TYPE-SISTEMA'`, etc.) que no correspondían a ninguna taxonomía normativa. Ni la norma NIST AC-2 ni los estándares de la industria (Keycloak, Entra ID, SailPoint) usan etiquetas de nivel jerárquico como tipo de cuenta. El campo no era verificable ni auditable.

#### Investigación previa — estándares de la industria

| Fuente | Tipos canónicos |
|---|---|
| **NIST SP 800-53 Rev5 AC-2(a)** | individual, shared, group, system, guest/anonymous, emergency, developer, temporary, service |
| **ISO 24760-2:2025** | human entity, non-human entity, external party |
| **oneM2M TS 0001** | SYS, BIZ, EXT, M2M (ya usados en `role_type`) |
| **PAM NHI** (BeyondTrust/CyberArk 2025) | Non-Human Identity — ratio 80:1 vs humanos |
| **Microsoft Entra ID** | Member, Guest, Service Principal, Managed Identity |
| **Keycloak 26.6.2** | realm-user, service-account, bot |
| **SailPoint IdentityNow** | Standard, Service, Privileged, Bot |

**Conclusión:** los 10 tipos de NIST AC-2 Rev5 son el denominador común de todos los estándares. La industria PAM añade NHI como agrupación de M2M + SERVICE.

#### Diseño aprobado — arquitectura dual de campos

Se decidió **preservar ambos campos** con responsabilidades distintas:

| Campo | Tipo | Rol | Taxonomía |
|---|---|---|---|
| `role_type` | `text NOT NULL CHECK` | Operativo — clasificación legible por humanos y operadores | Negocio SBOS (13 valores: GERENCIAL, TECNICO_PROFESIONAL, OPERATIVO, EXTERNO, MAQUINA, SISTEMA…) |
| `type_id` | `uuid NOT NULL FK` | Normativo — alineado con auditoría AC-2 | NIST SP 800-53 Rev5 AC-2 · ISO 24760-2:2025 |

#### Solución — Bloque A: catálogo `bauth.idn_role_type`

Archivo: `DDLs/seeds/bauth_47a__idn_role_type.sql` (se ejecuta antes de bauth_48 por orden alfabético)

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_role_type (
    id                  uuid        NOT NULL DEFAULT uuidv7(),
    codigo              text        NOT NULL,   -- clave natural estable
    nombre_es           text        NOT NULL,
    nombre_en           text        NOT NULL,
    descripcion_es      text        NOT NULL,
    norma_ref           text        NOT NULL,   -- cita normativa exacta
    es_humano           boolean     NOT NULL,
    es_externo          boolean     NOT NULL DEFAULT false,
    riesgo_elevado      boolean     NOT NULL DEFAULT false,
    requiere_expiracion boolean     NOT NULL DEFAULT false,
    activo              boolean     NOT NULL DEFAULT true,
    ctx_id              text        NOT NULL DEFAULT 'bootstrap',
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_idn_role_type        PRIMARY KEY (id),
    CONSTRAINT uq_idn_role_type_codigo UNIQUE (codigo)
);
```

10 tipos insertados con `ON CONFLICT (codigo) DO UPDATE`:

| codigo | nombre_es | es_humano | riesgo_elevado | requiere_expiracion |
|---|---|---|---|---|
| INDIVIDUAL | Usuario Individual Interno | true | false | false |
| EXTERNAL | Identidad Externa | true | false | false |
| GUEST | Visitante / Acceso Limitado | true | true | true |
| GROUP | Cuenta Compartida / Grupal | false | true | false |
| SYSTEM | Proceso de Sistema / Daemon | false | false | false |
| SERVICE | Cuenta de Servicio / Integración | false | false | false |
| M2M | Máquina a Máquina / NHI | false | false | false |
| EMERGENCY | Break-Glass / Emergencia | true | true | true |
| TEMPORARY | Acceso Temporal con Expiración | true | true | true |
| DEVELOPER | Cuenta de Desarrollo / Debug | true | false | false |

#### Solución — Bloque B: migración `type_id` TEXT → UUID FK

```sql
-- 1. Columna temporal sin restricciones
ALTER TABLE bauth.idn_role_template ADD COLUMN type_id_new uuid;

-- 2. Mapeo de valores TEXT → UUID del catálogo
UPDATE bauth.idn_role_template t
SET type_id_new = rt.id
FROM (VALUES
    ('TYPE-OPERATIVO',        'INDIVIDUAL'),
    ('TYPE-PROFESIONAL',      'INDIVIDUAL'),
    ('TYPE-GERENCIA-MEDIA',   'INDIVIDUAL'),
    ('TYPE-TECNICO',          'INDIVIDUAL'),
    ('TYPE-SUPERVISION',      'INDIVIDUAL'),
    ('TYPE-GERENCIA',         'INDIVIDUAL'),
    ('TYPE-DIRECCION',        'INDIVIDUAL'),
    ('TYPE-EXTERNO-CLIENTE',  'EXTERNAL'),
    ('TYPE-EXTERNO-PROVEEDOR','EXTERNAL'),
    ('TYPE-EXTERNO-VISITANTE','GUEST'),
    ('TYPE-M2M',              'M2M'),
    ('TYPE-SISTEMA',          'SYSTEM')
) AS m(old_val, codigo)
JOIN bauth.idn_role_type rt ON rt.codigo = m.codigo
WHERE t.type_id = m.old_val;

-- 3. Verificar 0 NULLs antes de agregar NOT NULL
-- Resultado: 0 nulos → se procedió
SELECT COUNT(*) FROM bauth.idn_role_template WHERE type_id_new IS NULL;

-- 4. Agregar NOT NULL + FK
ALTER TABLE bauth.idn_role_template
    ALTER COLUMN type_id_new SET NOT NULL,
    ADD CONSTRAINT fk_idn_role_template_type_id
        FOREIGN KEY (type_id_new) REFERENCES bauth.idn_role_type(id) ON DELETE RESTRICT;

-- 5. Reemplazar columna
ALTER TABLE bauth.idn_role_template DROP COLUMN type_id;
ALTER TABLE bauth.idn_role_template RENAME COLUMN type_id_new TO type_id;
```

#### Solución — Bloque C: refuerzo de `role_type`

```sql
UPDATE bauth.idn_role_template SET role_type = 'OPERATIVO'  WHERE role_type IS NULL;
ALTER TABLE bauth.idn_role_template ALTER COLUMN role_type SET NOT NULL;
ALTER TABLE bauth.idn_role_template ADD CONSTRAINT chk_idn_role_template_role_type
    CHECK (role_type IN (
        'GERENCIAL','TECNICO_PROFESIONAL','OPERATIVO','SUPERVISOR',
        'EJECUTIVO','DIRECTIVO','EXTERNO','MAQUINA','SISTEMA',
        'VISITANTE','ESPECIAL','COLABORADOR','ADMINISTRADOR'
    ));
```

#### Solución — Bloque D: seed idempotente con subquery al catálogo

`bauth_48__idn_role_template.sql` — cada fila usa subquery en lugar de TEXT literal:

```sql
-- Antes (inválido con FK UUID):
(uuidv7(), 'ROL-ACTUARIO', 'TYPE-GERENCIA-MEDIA', 'BIZ_N3', ...)

-- Después (subquery resuelta en tiempo de ejecución):
(uuidv7(), 'ROL-ACTUARIO', (SELECT id FROM bauth.idn_role_type WHERE codigo = 'INDIVIDUAL'), 'BIZ_N3', ...)
```

Mapeo aplicado a los 548 roles (Python, reemplazo de `'TYPE-X'` con comilla simple — no toca JSONB con doble comilla):

| Valor TEXT anterior | codigo catálogo | Cantidad |
|---|---|---|
| `'TYPE-OPERATIVO'` | INDIVIDUAL | 104 |
| `'TYPE-PROFESIONAL'` | INDIVIDUAL | 86 |
| `'TYPE-GERENCIA-MEDIA'` | INDIVIDUAL | 66 |
| `'TYPE-TECNICO'` | INDIVIDUAL | 51 |
| `'TYPE-SUPERVISION'` | INDIVIDUAL | 15 |
| `'TYPE-GERENCIA'` | INDIVIDUAL | 11 |
| `'TYPE-DIRECCION'` | INDIVIDUAL | 1 |
| `'TYPE-EXTERNO-CLIENTE'` | EXTERNAL | 119 |
| `'TYPE-EXTERNO-PROVEEDOR'` | EXTERNAL | 43 |
| `'TYPE-EXTERNO-VISITANTE'` | GUEST | 4 |
| `'TYPE-M2M'` | M2M | 29 |
| `'TYPE-SISTEMA'` | SYSTEM | 19 |
| **Total** | | **548** |

#### Verificación en VPS (commit `412b4ab`)

```
tipos_en_catalogo = 10
tipo       | cantidad
-----------+---------
INDIVIDUAL |      334
EXTERNAL   |      162
M2M        |       29
SYSTEM     |       19
GUEST      |        4

nulls_type_id = 0
fk_rotas      = 0
```

**Idempotencia verificada:** segunda ejecución retorna `INSERT 0 548` (upsert) sin errores.

---

**G-B01-04** · campo `hierarchy_level` · norma ANSI INCITS 359-2012 §3.3 RBAC1 · estado **⚠ Hardcoded**
Nivel en el DAG de herencia. Nivel 1 = C-Level (senior), nivel 5 = operativo estándar (junior). Los roles senior heredan de los junior.

> ⏳ **PENDIENTE** — resolver en siguiente iteración

---

**G-B01-05** · campo `status` · norma NIST SP 800-53 AC-2(j) · estado **⚠ Hardcoded**
AC-2(j) exige deshabilitar cuentas cuando ya no son necesarias. Ciclo: DRAFT → REVIEW → ACTIVE → DEPRECATED → ARCHIVED.

> ⏳ **PENDIENTE** — resolver en siguiente iteración

---

**G-B01-06** · campo `version` · norma ISO 27001:2022 A.8.32 + SemVer · estado **⚠ Hardcoded**
Trazabilidad de cambios. MAJOR = cambio breaking en permisos, dispara re-aprobación. MINOR = ampliación. PATCH = corrección sin impacto en permisos.

> ⏳ **PENDIENTE** — resolver en siguiente iteración

---

**G-B01-07** · campo `metadata.classification` · norma ISO 27001:2022 A.5.12 · estado **✗ Ausente**
PUBLIC / INTERNAL / CONFIDENTIAL / RESTRICTED. Determina quién puede leer la definición del rol.

> ⏳ **PENDIENTE** — resolver en siguiente iteración

---

**G-B01-08** · campo `digital_signature.algorithm` · norma Ley 164 Bolivia Art. 78 + ADSIB-FD-POLT-015 v2.3 · estado **✗ Ausente**
Firma del contrato del rol para garantizar integridad y no repudio. Interno: EdDSA Ed25519 (Vault). Externo con validez jurídica: RSA-SHA256 ADSIB.

> ⏳ **PENDIENTE** — resolver en siguiente iteración

---

**Gaps de implementación pendientes B01:**
- El objeto `RT` en el demo solo tiene `d{}` — necesita subestructura `RT.meta = {id, status, version, classification, signature}`.
- ATTRS catalog: necesita entradas `rol_id`, `rol_type`, `rol_status`, `rol_classification`, `rol_version`.

---

### B2 — Vigencia y Ciclo de Vida

**Normas:** NIST-53-AC2(d) · ISO-27001-A5.18 · NIST-63B4-§5.4 · PCI-40-Req7.2.4

---

**G-B02-01** · campo `validity_period.type` · norma NIST SP 800-53 AC-2(d) · estado **⚠ Hardcoded**
AC-2 exige definir "expiry conditions" por tipo de cuenta. INDEFINITE solo para roles estructurales permanentes. PROJECT_BASED exige fecha de fin. FIXED exige fechas start y end.

> **✅ RESOLUCIÓN G-B02-01 — 2026-07-08**
> **DDL:** `validity_period_type bauth.role_validity_type NOT NULL DEFAULT 'INDEFINITE'`
>
> ```sql
> CREATE TYPE bauth.role_validity_type AS ENUM (
>     'INDEFINITE',     -- roles estructurales permanentes: SU, SYS, BIZ_N1-N5
>     'FIXED',          -- externos, contratistas: end_date = fecha fin contrato
>     'PROJECT_BASED',  -- roles de proyecto: end_date = milestone del proyecto
>     'TEMPORARY',      -- acceso temporal de corta duración (horas/días)
>     'EMERGENCY'       -- acceso de emergencia: máx 72h, NIST AC-2(2)
> );
> ```
>
> **Regla fundamental confirmada:** la fecha de fin NO es una decisión arbitraria — **depende del ENUM**. Cada valor del ENUM tiene una regla determinista:
>
> | ENUM value | end_date | Quién la determina | ¿Extensión posible? |
> |------------|----------|--------------------|---------------------|
> | `INDEFINITE` | NULL | Sistema (no hay fecha fin) | N/A — se gestiona por review_date |
> | `FIXED` | fecha contractual | Humano obligatorio en INSERT | Sí, con nuevo contrato |
> | `PROJECT_BASED` | milestone del proyecto | Humano + notificación al vencimiento | Sí, decisión humana |
> | `TEMPORARY` | `created_at + duration_interval` | Calculado automáticamente en INSERT | **NO — tiempo definitivo** |
> | `EMERGENCY` | `created_at + '72 hours'` | Calculado automáticamente en INSERT | **NO — tiempo definitivo** |
>
> **Comportamiento de usuarios asignados a TEMPORARY/EMERGENCY:** todos los usuarios asignados a ese rol comparten su tiempo de vida. Al llegar `end_date`, todos son de-asignados automáticamente en la misma transacción. El rol es el "contenedor" — su expiración es la expiración de todos sus asignados.
>
> **Motor de reconciliación (reconcile loop) — corre cada 60s en bAuth daemon:**
> ```
> Para cada rol activo:
>
>   INDEFINITE:
>     SI (review_date - now() ≤ 30 días) Y (usuarios_activos > 0)
>       → AUTO-EXTENDER: review_date += 1 year
>       → NOTIFICAR role_owner: "rol renovado automáticamente por usuarios activos"
>     SI (review_date - now() ≤ 30 días) Y (usuarios_activos = 0)
>       → NOTIFICAR role_owner: "rol sin usuarios activos, ¿marcar DEPRECATED?"
>       → ESPERAR decisión humana (sin acción automática)
>     SI review_date < now() Y sin acción del role_owner
>       → status = DEPRECATED; end_date = review_date (retroactivo)
>
>   PROJECT_BASED:
>     SI (end_date - now() ≤ 30 días)
>       → NOTIFICAR project_owner + role_owner: "rol de proyecto vence en X días"
>       → ESPERAR decisión humana: ¿extender end_date? ¿cerrar el rol?
>       → SIN acción automática — solo el humano decide
>     SI end_date < now() Y sin decisión humana
>       → status = DEPRECATED automáticamente
>
>   TEMPORARY / EMERGENCY:
>     SI now() ≥ end_date
>       → status = DEPRECATED INMEDIATO
>       → REVOCAR todas las asignaciones de usuario en la misma transacción
>       → REGISTRAR evento de auditoría (ISO 27001 A.8.15)
>       → PROHIBIDO extender — tiempo definitivo e irrevocable
> ```
> **Estándar:** NIST AC-2(d) "expiry conditions" + AC-2(2) "automatic removal" para EMERGENCY + ISO 27001 A.5.18 "temporary access automatically revoked".

---

**G-B02-02** · campo `start_date / end_date` · norma ISO 27001:2022 A.5.18 §c · estado **⚠ Hardcoded**
A.5.18 exige fecha de expiración para todo acceso temporal. `end_date = null` es válido para INDEFINITE pero debe ser decisión explícita y documentada.

> **✅ RESOLUCIÓN G-B02-02 — 2026-07-08**
> **DDL:**
> ```sql
> start_date  timestamptz NOT NULL DEFAULT now(),   -- creación del rol = inicio
> end_date    timestamptz,                           -- NULL válido solo para INDEFINITE
> duration_interval interval,                        -- para TEMPORARY: e.g. '7 days', '24 hours'
> ```
> **`start_date`** = `now()` automático en INSERT. La aplicación nunca lo asigna manualmente.
> **`end_date`** es calculado por trigger según el ENUM:
> ```sql
> -- Trigger que calcula end_date al INSERT según validity_period_type
> CASE NEW.validity_period_type
>   WHEN 'INDEFINITE'    THEN NULL                              -- sin fecha fin
>   WHEN 'FIXED'         THEN NEW.end_date                     -- humano lo provee
>   WHEN 'PROJECT_BASED' THEN NEW.end_date                     -- humano lo provee
>   WHEN 'TEMPORARY'     THEN now() + NEW.duration_interval    -- calculado
>   WHEN 'EMERGENCY'     THEN now() + interval '72 hours'      -- fijo NIST
> END
> ```
> **Constraint de integridad:**
> ```sql
> CHECK (
>   (validity_period_type = 'INDEFINITE' AND end_date IS NULL) OR
>   (validity_period_type IN ('FIXED', 'PROJECT_BASED') AND end_date IS NOT NULL) OR
>   (validity_period_type IN ('TEMPORARY', 'EMERGENCY'))  -- end_date calculado por trigger
> )
> ```

---

**G-B02-03** · campo `review_date` · norma ISO 27001:2022 A.5.18 + PCI DSS 4.0 Req 7.2.4 · estado **⚠ Hardcoded**
ISO: revisión al menos anual. PCI: trimestral para acceso privilegiado. bAuth alerta 30 días antes al `role_owner`. Si no se revisa, el rol pasa a DEPRECATED automáticamente.

> ⏳ **PENDIENTE** — resolver en siguiente iteración

---

**G-B02-04** · campo `renewal_settings.max_renewals` · norma NIST SP 800-63B-4 §5.4 · estado **✗ Ausente**
Limitar renovaciones sin re-proofing evita privilege creep acumulativo. Cada renovación debe validar que el rol sigue siendo necesario y apropiado.

> ⏳ **PENDIENTE** — resolver en siguiente iteración

---

**G-B02-05** · campo `early_termination.requires_approval` · norma NIST SP 800-53 AC-2(i) · estado **✗ Ausente**
AC-2(i): gestores de cuentas deben ser notificados cuando las cuentas ya no son necesarias. Terminar antes del plazo exige aprobación para prevenir sabotaje.

> ⏳ **PENDIENTE** — resolver en siguiente iteración

---

**Gaps de implementación pendientes B02:**
- CFG_POLICY_LIB D4: añadir `temporal.max_age_days`, `temporal.review_interval_days`, `temporal.renewal_limit`.
- RT.d[4] actualmente vacío.

---

### B3 — Flujo de Aprobación

**Normas:** NIST-53-AC5 · ISO-27001-A5.18-§a · PCI-40-Req7.2.5 · SOX-§302/404

| Código | Campo | Norma exacta | Qué exige la norma | Estado |
|--------|-------|--------------|--------------------|--------|
| G-B03-01 | `required_approvers` | NIST SP 800-53 AC-5 + ISO 27001 A.5.18 | AC-5 exige aprobación formal para asignación de roles. Roles críticos (financiero, SU, SYS): "dual control" — mínimo 2 aprobadores independientes. | ⚠ Hardcoded |
| G-B03-02 | `approver_roles[]` | PCI DSS 4.0 Req 7.2.5.1 | PCI exige que la aprobación sea realizada por "authorized personnel" — nivel jerárquico mayor al solicitante. Lista de roles que pueden aprobar este rol específico. | ⚠ Hardcoded |
| G-B03-03 | `sla_hours` | ISO 27001:2022 A.5.18 §b | A.5.18 exige procesos "in a timely manner". El SLA define el tiempo máximo de espera antes de que el acceso quede bloqueado indefinidamente. | ✗ Ausente |
| G-B03-04 | `escalation_after_hours` | NIST SP 800-53 AC-2(e) | AC-2(e): gestores deben ser notificados. Si el aprobador no responde en `sla_hours/2`, bAuth escala automáticamente al siguiente nivel. | ✗ Ausente |
| G-B03-05 | `escalation_to[]` | NIST SP 800-53 AC-2(e) | Lista de roles alternativos para escalar si el aprobador primario no responde. Al menos un aprobador de respaldo definido para roles críticos. | ✗ Ausente |

**Gaps de implementación:**
- Tabla `bauth_approval_workflow` en BD — actualmente no existe.
- Atoms D10: `bauth.g{governance}.d10.{approve_role}`, `bauth.g{governance}.d10.{escalate_approval}`.
- CFG_POLICY_LIB: `approval.required_count`, `approval.sla_hours`, `approval.escalation_trigger`.

---

## SECCIÓN 2 — Dominios con Bloque Dedicado

### B4 — D1 Dominio Lógico · Autenticación Digital

**Normas:** NIST-63B4 · RFC-9470 · RFC-6749 · FIDO2/WebAuthn · NIST-207 · ISO-27001-A8.2

| Código | Campo / Subcampo | Norma exacta | Qué exige la norma | Estado |
|--------|------------------|--------------|--------------------|--------|
| G-B04-01 | `availableMethods[]` (pool) | NIST SP 800-63B-4 §4 | Pool de authenticators válidos. 800-63B-4 categoriza: memorized secrets, OOB devices, OTP hardware, WebAuthn/FIDO2, PKI/X.509. El pool define qué puede usar el rol. | ✅ En demo |
| G-B04-02 | `meths.required / alternative` | NIST SP 800-63B-4 §4.2 — AAL | AAL1=1 factor. AAL2=2 factores obligatorios. AAL3=hardware-bound. `required` = factor obligatorio; `alternative` = opciones de mismo AAL. | ✅ En demo |
| G-B04-03 | `level_of_assurance` (LoA 1-4) | NIST SP 800-63B-4 AAL1/2/3 + RFC 9470 | El LoA del rol determina el AAL mínimo al autenticar. RFC 9470 permite step-up dinámico via `acr_values` cuando recurso exige mayor LoA. Actualmente inferido de métodos, no campo propio. | ⚠ Inferido |
| G-B04-04 | `step_up_rules[]` | RFC 9470 §3 — `acr_values` + `max_age` | Cuando recurso retorna `insufficient_user_authentication`, el cliente solicita re-auth con `acr_values`. El rol define cuándo aplicar step-up y hacia qué LoA. Necesita estructura: `{trigger, acr_target, max_age_s, resources[]}`. | ⚠ Sin estructura |
| G-B04-05 | `temporal_control` (embebido) | NIST SP 800-53 AC-2(d) | Restricciones horarias: días/horas en que el rol es activo lógicamente. Actualmente duplicado con B2 y B8 — debe migrar a B15 (D4 Temporal). | ⚠ Duplicado |
| G-B04-06 | `geospatial_control` (embebido) | NIST SP 800-207 §3.2 — subject attributes | Zero Trust: la ubicación es subject attribute evaluado por el PE. Duplicado en B8 — debe consolidarse en B17 (D6 Geoespacial). Dos fuentes de verdad = riesgo de contradicción. | ⚠ Duplicado |
| G-B04-07 | Políticas CFG_POLICY_LIB D1 | NIST SP 800-63B-4 §5 — Password policy | 800-63B-4 actualiza: sin rotación periódica forzada, screening contra HaveIBeenPwned, mínimo 15 chars, sin requisitos arbitrarios de complejidad. | ✅ En CFG_POLICY_LIB |
| G-B04-08 | Attrs D1 (email, phone, ci, country) | ISO 24760-1:2025 §6 — Identity attributes | Atributos de identidad (NO credenciales). ISO 24760-1 distingue claimed (no verificado) vs. verified (con IAL documentado). Passwords, TOTP seeds → credential store, NUNCA aquí. | ✅ En ATTRS |

---

### B5 — D2 Dominio Físico · Acceso Presencial

**Normas:** ISO-27001-A7.2 · ISO-30107-3:2023 · NIST-116 · NIST-76

| Código | Campo | Norma exacta | Qué exige la norma | Estado |
|--------|-------|--------------|--------------------|--------|
| G-B05-01 | `allowed_zones[]` | ISO 27001:2022 A.7.2 — Physical entry controls | A.7.2 exige controles de entrada por zona. Cada zona tiene nivel de seguridad y el rol necesita permiso explícito. Sin permiso = denegado por defecto. | ✅ En demo |
| G-B05-02 | `access_schedule` | NIST SP 800-116 §4.3 — PACS | Los Physical Access Control Systems deben soportar restricción horaria por zona. Un empleado de turno de día no puede acceder de noche aunque tenga tarjeta válida. | ⚠ Parcial |
| G-B05-03 | `biometric_enrollment_policy` (embebido) | ISO 30107-3:2023 + NIST SP 800-76-2 | ISO 30107-3 exige PAD certificado nivel 1 o 2. NIST 800-76-2 define calidad mínima de captura. Debe migrar a B16 (D5 Biométrico) — está embebido aquí incorrectamente. | ⚠ Mal ubicado |
| G-B05-04 | `device_types[]` | ISO 27001:2022 A.7.2 | Tipos de dispositivo autorizados: lector RF, lector biométrico, PIN+tarjeta, combinaciones. El rol define qué combinaciones son aceptables por nivel de zona. | ⚠ Parcial |
| G-B05-05 | `anti_passback` | NIST SP 800-116 §5 | Previene que una credencial sea usada para entrar dos veces sin salir. Obligatorio para zonas de alta seguridad (servidores, tesorería, archivo confidencial). | ✗ Ausente |

---

### B6 — Zonas de Negocio (mapa D1 → Aplicaciones)

**Normas:** INCITS-359-§4 · NIST-162 · ISO-27001-A5.15 · PCI-40-Req7 · GDPR-Art9

| Código | Campo | Norma exacta | Qué exige la norma | Estado |
|--------|-------|--------------|--------------------|--------|
| G-B06-01 | `zone_logical/{app}` | ANSI INCITS 359-2012 §3 — Permission=(operation,object) | INCITS 359 define Permission como el par (operación, objeto). Zone_logical es el "objeto" (módulo de negocio); las operaciones son READ/WRITE/APPROVE/EXECUTE. | ⚠ Hardcoded |
| G-B06-02 | `zone_financial/{area}` | PCI DSS 4.0 Req 7 + SIN RND 102100000011 | PCI exige separar acceso por función de negocio financiera. SIN RND añade restricciones específicas para emisión de comprobantes fiscales digitales (CUFD/CUF). | ⚠ Hardcoded |
| G-B06-03 | `scope` (REGIONAL / NACIONAL) | NIST SP 800-162 §4 — Environment attributes | En ABAC, el scope es un environment attribute. Un vendedor regional no puede ver datos de otras regiones aunque tenga el mismo rol funcional. | ✗ Ausente |
| G-B06-04 | `pii_access: true/false` | GDPR Art. 5(1)(b) + ISO 27701 | El acceso a PII requiere base legal explícita y propósito delimitado. El flag activa controles adicionales de privacidad: log obligatorio, exportación restringida, retención limitada. | ✗ Ausente |
| G-B06-05 | `limit_tier` | PCI DSS 4.0 Req 7.2.5 + SOX §302 | Tier de límite financiero por rol. Transacciones sobre el umbral del tier activan flujo de aprobación dual. PCI y SOX hacen esto obligatorio para ciertas funciones. | ✗ Ausente |

---

### B7 — Privilegios Tryton — 5 Capas ERP

**Normas:** NIST-53-AC3 · NIST-53-AC6 · ISO-27001-A8.2 · ISO-27001-A8.11 · PCI-40-Req7.3

| Código | Capa | Norma exacta | Qué exige la norma | Estado |
|--------|------|--------------|--------------------|--------|
| G-B07-01 | CAPA 1 `ir.model.access` (CRUD) | NIST SP 800-53 AC-3 — Access Enforcement | AC-3 exige que el sistema "enforce approved authorizations" a nivel OS y aplicación. CRUD por modelo Tryton es el enforcement de más alto nivel. Ya cubierto por los 5808 atoms de Tryton. | ✅ Atoms D1 |
| G-B07-02 | CAPA 2 `ir.action.groups` (menús) | NIST SP 800-53 AC-6(10) | AC-6(10): prohibir acceso a funciones que el rol no necesita. Ocultar menús implementa "least privilege" en la UI. Ya cubierto por los atoms de Tryton. | ✅ Atoms D1 |
| G-B07-03 | CAPA 3 `ir.model.field` (restricciones) | ISO 27001:2022 A.8.11 — Data masking | A.8.11: enmascarar datos según requisitos de acceso. Ocultar campos de margen/precio costo es data masking por rol. No tiene estructura JSONB propia en el template. | ⚠ Sin estructura |
| G-B07-04 | CAPA 4 `ir.model.button` (PYSON) | PCI DSS 4.0 Req 7.3.1 + SIN RND Bolivia | Aprobación dual para transacciones sobre límite. PYSON evalúa condiciones en tiempo real. SIN RND exige habilitación para emitir CUFD/CUF. Sin estructura JSONB en el template. | ⚠ Sin estructura |
| G-B07-05 | CAPA 5 `ir.rule` (filtros SQL) | NIST SP 800-162 ABAC — resource attributes | ABAC resource attribute: el registro solo es visible si pertenece a la región/punto de venta del usuario. Implementa least privilege a nivel de fila de BD. Sin estructura JSONB. | ⚠ Sin estructura |

---

### B8 — D3 Dominio Financiero · Transacciones

**Normas:** PCI-40-Req7/8 · SIN-RND · LEY-164 · NIST-53-AC5

| Código | Campo | Norma exacta | Qué exige la norma | Estado |
|--------|-------|--------------|--------------------|--------|
| G-B08-01 | `transaction_limits.max_amount` | PCI DSS 4.0 Req 7.3.1 | Límite máximo por transacción por rol. Superar el límite activa flujo de aprobación adicional (dual control). Obligatorio para roles con acceso a módulos financieros. | ✅ En demo |
| G-B08-02 | `approval_required_above` | PCI DSS 4.0 + SOX §302 | SOX y PCI exigen aprobación dual para transacciones financieras significativas. Umbral configurable por rol y tipo de transacción. | ✅ En demo |
| G-B08-03 | `currency` | ISO 4217 | Código de moneda en formato ISO 4217 (BOB, USD, EUR). Determina en qué moneda aplica el límite. Un límite de 10000 no es lo mismo en BOB que en USD. | ⚠ Parcial |
| G-B08-04 | `facturacion.rnnd_emisor` | SIN RND 102100000011 Bolivia §4 | La norma SIN define quién puede emitir comprobantes fiscales digitales (SIAT). El rol debe tener habilitación explícita como punto de emisión con su NIT y modalidad. | ⚠ Parcial |
| G-B08-05 | `facturacion.modalidad` | SIN RND 102100000011 §5 | Modalidades de emisión: EN_LINEA, FUERA_DE_LINEA, MASIVA. El rol define cuál(es) puede usar según su conectividad y volumen de operaciones. | ✗ Ausente |
| G-B08-06 | `firma_electronica_required` | Ley 164 Bolivia Art. 78 | Transacciones sobre umbral legal requieren firma digital con validez jurídica. EdDSA Ed25519 interno (velocidad) o RSA-SHA256 ADSIB externo (validez jurídica plena para terceros). | ⚠ Parcial |
| G-B08-07 | `transaction_schedule` | NIST SP 800-53 AC-2(d) | Restricción horaria de transacciones financieras (ej: solo días hábiles 08:00–18:00). Actualmente duplicado con B2 — debe consolidarse en B15 (D4 Temporal). | ⚠ Duplicado |

---

### B9 — SAM-128 + BitMask Dual 64-bit

**Normas:** INCITS-359-§4 · NIST-53-AC3(7) · Diseño propio SBOS · READONLY

| Código | Campo | Norma origen | Descripción | Estado |
|--------|-------|-------------|-------------|--------|
| G-B09-01 | `*_domain_mask_hex` (Q1–Q4) | Diseño propio SBOS | 128 bits en 4 quadrants de 32 bits. Codifica el set completo de permisos del rol como bits one-hot. Herencia: OR lógico. Eliminación: AND NOT. Evaluación < 0.5 ns. Motor: bAuth.PrivilegeEngine. | ✗ No calculado |
| G-B09-02 | `rol_bitmask` (64-bit) | ANSI INCITS 359 §4 — Permission sets | Un bit por rol activo del usuario. Evaluación de pertenencia en O(1) sin consulta a BD. Base del DAG de herencia con closure table en PostgreSQL. | ✗ No calculado |

---

### B10 — D10 Delegación · DSD / SoD Dinámico

**Normas:** NIST-53-AC6(3) · INCITS-359-§4-DSD · RFC-8693 · ISO-27001-A5.17

| Código | Campo | Norma exacta | Qué exige la norma | Estado |
|--------|-------|--------------|--------------------|--------|
| G-B10-01 | `can_delegate` | NIST SP 800-53 AC-6(3) | AC-6(3): autorizar a usuarios a delegar privilegios. Solo ciertos roles pueden delegar y solo hacia abajo en la jerarquía (nunca hacia arriba, nunca hacia roles de otro nivel). | ✅ En demo |
| G-B10-02 | `delegation_depth` | ANSI INCITS 359-2012 §4 — DSD | Dynamic SoD: limitar la cadena de delegaciones evita reconstruir un permiso prohibido por delegaciones sucesivas. Max depth recomendado: 2 niveles. | ⚠ Parcial |
| G-B10-03 | `allowed_delegate_roles[]` | NIST SP 800-53 AC-6(3) | El delegante solo puede delegar a roles de nivel igual o inferior. Lista blanca explícita de roles destino permitidos para esta delegación específica. | ⚠ Parcial |
| G-B10-04 | `max_duration_hours` | ISO 27001:2022 A.5.17 | A.5.17: los privilegios delegados no deben ser permanentes. Límite temporal obligatorio. Al vencer, el token delegado se invalida automáticamente. | ⚠ Parcial |
| G-B10-05 | `requires_supervisor_approval` | NIST SP 800-53 AC-5 | Para delegaciones que involucran funciones críticas, exigir aprobación del supervisor antes de activar. Aplica siempre que `can_delegate = true` en roles tier 1 y 2. | ✗ Ausente |
| G-B10-06 | `token_exchange_config` | RFC 8693 OAuth 2.0 Token Exchange | El token del delegante se intercambia por uno limitado del delegado, conservando claims del `actor` original para auditoría. `subject_token_type`, `requested_token_type`, `scope`. | ✗ Ausente |

---

### B11 — Grupos y Jerarquías H-RBAC

**Normas:** INCITS-359-§3.2-RBAC1 · NIST-53-AC2(g)

RBAC1 define herencia como partial order (≤). Un rol senior hereda todos los permisos de sus junior. bAuth implementa con DAG OR + closure table SQL.

| Código | Campo | Norma | Estado |
|--------|-------|-------|--------|
| G-B11-01 | `role_hierarchy.level` | INCITS 359 RBAC1 §3.2 | ⚠ Hardcoded |
| G-B11-02 | `role_hierarchy.parent_role` | INCITS 359 RBAC1 §3.2 | ⚠ Hardcoded |
| G-B11-03 | `role_hierarchy.child_roles[]` | INCITS 359 RBAC1 §3.2 | ⚠ Hardcoded |
| G-B11-04 | `role_groups[]` (grupos funcionales) | NIST SP 800-53 AC-2(g) | ✗ Ausente |
| G-B11-05 | `quorum_required` (aprobación k-de-n) | PCI DSS 4.0 Req 7.2.5 | ✗ Ausente |

---

### B12 — SoD — Separación de Funciones

**Normas:** NIST-53-AC5 · INCITS-359-§4-SSC/DSC · SOX-§302 · PCI-40-Req6.3.2

AC-5 exige documentar explícitamente qué tareas son incompatibles. ANSI INCITS 359 §4 formaliza como Static SoD Constraints (SSC): conjuntos de roles de los que ningún usuario puede tener más de `k` simultáneamente. Verificación: REAL_TIME en cada asignación de rol.

| Código | Campo | Norma | Estado |
|--------|-------|-------|--------|
| G-B12-01 | `incompatible_roles[]` | NIST AC-5 + INCITS 359 SSC | ⚠ Hardcoded |
| G-B12-02 | `incompatible_functions[]` | NIST AC-5 | ⚠ Hardcoded |
| G-B12-03 | `conflict_validation.check_frequency` | NIST AC-5 + PCI DSS | ⚠ Hardcoded |
| G-B12-04 | `max_concurrent_roles_per_user` (k) | INCITS 359 DSC §4.2 | ✗ Ausente |
| G-B12-05 | `sod_exception_process` | SOX §302 — excepción documentada | ✗ Ausente |

---

### B13 — D11 Cumplimiento y Auditoría

**Normas:** ISO-27001-A8.15 · NIST-53-AU2/AU3/AU12 · NIST-92 · PCI-40-Req10

| Código | Campo | Norma exacta | Qué exige la norma | Estado |
|--------|-------|--------------|--------------------|--------|
| G-B13-01 | `audit_events[]` | NIST SP 800-53 AU-2 | AU-2 exige definir qué eventos auditar. Para roles: login, logout, privilege use, access denied, role change, delegation, config change, credential change. | ✅ En demo |
| G-B13-02 | `audit_record_content` | NIST SP 800-53 AU-3 | AU-3: contenido mínimo = event type, timestamp, source location, outcome, identity del subject. El `ctx_id` de SBOS cumple esta función (6 capas W3C Trace Context). | ✅ En demo |
| G-B13-03 | `review_frequency` | ISO 27001:2022 A.8.15 + PCI DSS Req 10.7 | PCI: revisión diaria para sistemas CDE. ISO: frecuencia según clasificación. Campo ausente — actualmente no configurable por rol. | ⚠ Parcial |
| G-B13-04 | `retention_days` | PCI DSS 4.0 Req 10.7 + NIST SP 800-92 §3 | PCI exige retención mínima 12 meses (3 meses online inmediatamente disponible). Campo ausente — no configurable por rol, no diferenciado por clasificación. | ⚠ Parcial |
| G-B13-05 | `siem_output` (Wazuh) | NIST SP 800-92 §3 — Log management | 800-92: centralización en SIEM. El rol define qué nivel de alerta genera en Wazuh: INFO, WARNING, CRITICAL. | ✅ En demo |
| G-B13-06 | `privilege_creep_detection` | NIST SP 800-53 AC-2(j) + ISO 27001 A.5.18 | AC-2(j): deshabilitar cuentas cuando ya no son necesarias. Privilege creep detection revisa trimestralmente si el usuario sigue necesitando el rol. | ✗ Ausente |

---

### B14 — Estado de Sincronización (Sync State)

**Normas:** ISO-27001-A8.32 · Diseño propio bAuth reconcile loop · READONLY

| Código | Descripción | Estado |
|--------|-------------|--------|
| G-B14-01 | B14 completo: `sync_status`, `keycloak.*`, `tryton.group_id`, `drift_detected` — todos son calculados por el reconcile loop de 60 s (bAuth.ReconcileEngine). En el demo son valores estáticos inventados. No necesita catálogo: son siempre computados, nunca editados. | ✗ Decorativo |

---

## SECCIÓN 3 — Dominios Pendientes (Plan de Reparación PR-3)

### B15 — D4 Temporal · Vigencia y Schedules

**Actualmente:** disperso en B2+B4+B8 · **Normas:** NIST-53-AC2(d)/AC9 · ISO-27001-A5.18 · RFC-7519

| Código | Gap | Norma | Qué se necesita |
|--------|-----|-------|-----------------|
| G-B15-01 | Políticas CFG_POLICY_LIB D4 | NIST AC-2(d) + RFC 7519 | `temporal.access_schedule`, `temporal.token_max_age_s`, `temporal.session_idle_timeout_s`, `temporal.transaction_schedule` |
| G-B15-02 | Attrs D4 | NIST SP 800-53 AC-2 | `timezone` (IANA tz string), `work_schedule_id` (FK a tabla calendarios laborales) |
| G-B15-03 | Atoms D4 | Diseño SBOS | `bauth.g{lifecycle}.d4.{schedule_task}`, `bauth.g{lifecycle}.d4.{extend_validity}`, `bauth.g{lifecycle}.d4.{suspend_role}` |

---

### B16 — D5 Biométrico · Enrolamiento y Liveness

**Actualmente:** embebido en B5 · **Normas:** ISO-30107-3:2023 · NIST-76-2 · NIST-63B4-§5 · GDPR-Art9

| Código | Gap | Norma | Qué se necesita |
|--------|-----|-------|-----------------|
| G-B16-01 | Políticas CFG_POLICY_LIB D5 | ISO 30107-3 + NIST 800-76 | `biometric.liveness_level` (Level 1/2), `biometric.quality_threshold` (FNMR/FMR), `biometric.gdpr_legal_basis` (LEGITIMATE_INTEREST / EXPLICIT_CONSENT) |
| G-B16-02 | Attrs D5 | ISO 24760-1 + GDPR Art.9 | `biometric_enrolled_modalities[]` (fingerprint/face/iris), `biometric_last_verification`, `biometric_enrollment_date`, `biometric_gdpr_consent_date` |
| G-B16-03 | Conectar ath_config_d5 / ath_policy_d5 al demo | ISO 30107-3 | Las tablas ya existen en VPS con patrón JSONB correcto — mapear al catálogo del demo |

---

### B17 — D6 Geoespacial · Política Unificada

**Actualmente:** duplicado en B4 y B8 · **Normas:** NIST-207-§3.2 · NIST-162 · ISO-27001-A8.1

| Código | Gap | Norma | Qué se necesita |
|--------|-----|-------|-----------------|
| G-B17-01 | Políticas CFG_POLICY_LIB D6 | NIST SP 800-207 + NIST 800-162 | `geo.allowed_countries[]`, `geo.allowed_cities[]`, `geo.require_vpn_outside_office`, `geo.impossible_travel_detection`, `geo.block_tor_exit_nodes` |
| G-B17-02 | Attrs D6 | NIST SP 800-162 — subject attributes | `last_known_location` (lat/lon), `home_region`, `allowed_regions[]`, `current_country_code` |
| G-B17-03 | Atoms D6 | Diseño SBOS | `bauth.g{admin}.d6.{configure_geo_policy}`, `bauth.g{audit}.d6.{read_location_log}` |

---

### B18 — D7 Red · Network Access Control

**Actualmente:** completamente ausente · **Normas:** NIST-207-§3.3 · NIST-53-SC7 · PCI-40-Req1.3 · RFC-8705

| Código | Gap | Norma | Qué se necesita |
|--------|-----|-------|-----------------|
| G-B18-01 | Políticas CFG_POLICY_LIB D7 | NIST SP 800-207 + RFC 8705 | `network.zero_trust_mode`, `network.allowed_cidr[]`, `network.block_cidr[]`, `network.mtls_required`, `network.rate_limit_rpm`, `network.api_gateway_plugins[]` (Kong) |
| G-B18-02 | Attrs D7 | NIST SP 800-207 — device signals | `last_known_ip`, `device_compliance_status`, `registered_devices[]`, `vpn_required` |
| G-B18-03 | Atoms D7 | Diseño SBOS | `kong.g{monitor}.d7.{configure_rate_limit}`, `kong.g{admin}.d7.{block_ip}`, `kong.g{admin}.d7.{restrict_cidr}`, `kong.g{monitor}.d7.{read_traffic_log}` |

---

### B19 — D8 Contexto Adaptativo · Zero Trust

**Actualmente:** solo step_up_rules parcial en B4 · **Normas:** NIST-207-§4 · CAEP-10 · RFC-9470 · NIST-53-SI4

**Señales CAEP 1.0 que el rol debe manejar:**

| Código | Señal CAEP | Descripción | Acción del rol |
|--------|-----------|-------------|----------------|
| G-B19-01 | `session_revoked` | Sesión terminada por admin o anomalía detectada | Block inmediato — invalidar todos los tokens activos |
| G-B19-02 | `credential_change` | Credencial modificada por tercero (posible compromiso) | Step-up AAL3 obligatorio antes de continuar |
| G-B19-03 | `device_compliance_change` | Dispositivo dejó de cumplir postura de seguridad | Step-up o block según nivel del rol |
| G-B19-04 | `impossible_travel` | Login desde ubicación geográficamente imposible en el tiempo transcurrido | Block + alerta SIEM CRITICAL |
| G-B19-05 | `risk_level: HIGH` (score > 0.9) | Motor de riesgo evalúa score muy alto | Block inmediato + notificación supervisor |
| G-B19-06 | `risk_level: MEDIUM` (score 0.7–0.9) | Motor de riesgo evalúa score elevado | Step-up AAL2 obligatorio |

**Catálogos que se necesitan:**

| Código | Gap | Qué se necesita |
|--------|-----|-----------------|
| G-B19-07 | Políticas CFG_POLICY_LIB D8 | `context.risk_engine_provider`, `context.assessment_interval_s`, `context.revoke_on_anomaly`, `context.signals_enabled[]`, `context.emergency_access_allowed` |
| G-B19-08 | Attrs D8 | `current_risk_score`, `last_risk_assessment`, `session_context_flags[]`, `trust_score_history` |

---

### B20 — D9 Credenciales · Ciclo de Vida

**Actualmente:** investigación §9.4 pendiente · **Normas:** NIST-63B4-§5 · NIST-53-IA5 · ISO-27001-A5.17 · PCI-40-Req8.3

> **Regla fundamental:** Las credenciales (password hash, TOTP seed, WebAuthn public key, X.509 cert, biometric template) NUNCA van en `idn_tipo_atributo`. Van al credential store de Keycloak/Vault. Los atributos de identidad (email, CI, phone) SÍ van en `idn_tipo_atributo`.

**Lifecycle por tipo de credencial (NIST SP 800-63B-4 §5):**

| Código | Método | Tipo de credencial | Rotación | Revocación | Recuperación |
|--------|--------|--------------------|----------|------------|--------------|
| G-B20-01 | am1 Password | Memorized secret (hash Argon2id) | Trigger-on-breach únicamente — NO rotación periódica (800-63B-4 §5.1.1) | Inmediata Keycloak → todos los tokens invalidados | Email verificado + IAL1 re-proofing |
| G-B20-02 | am2 TOTP | Shared secret seed (HMAC-SHA1/256) | Al cambiar dispositivo o detección de compromiso | Inmediata Keycloak — seed eliminado | Supervisor approval + backup codes pre-generados |
| G-B20-03 | am4 WebAuthn Passwordless | Public key COSE (ES256/EdDSA) | Al revocar dispositivo físico — la clave está en el authenticator | Inmediata Keycloak — credential ID eliminado | Re-enrollment presencial IAL2 con supervisor |
| G-B20-04 | am5 WebAuthn 2FA | Public key COSE — segundo factor | Al revocar dispositivo o al detectar uso no autorizado | Inmediata Keycloak | Factor primario (am1) + re-enrollment del dispositivo |
| G-B20-05 | am7 X.509 mTLS | Certificate DER/PEM (RSA-2048 / P-256) | 365 días o antes si CA compromised. Vault PKI auto-renew 30 días antes | CRL + OCSP Vault — revocación < 60 s | Vault PKI re-issue con nueva clave, re-binding al usuario |
| G-B20-06 | am19 Biométrico | Template hash (nunca el raw biométrico) | Al detectar degradación de calidad o fallos PAD sistemáticos | Eliminar template de todos los lectores | Re-enrollment presencial obligatorio con supervisor testigo |
| G-B20-07 | am20 ECDSA (Besu) | Private key secp256k1 — Vault HSM managed | Al comprometer o policy rotation. Vault key disable + nueva clave | Vault key disable — transacciones antiguas siguen válidas (blockchain) | Vault re-keying ceremony con quórum de administradores |
| G-B20-08 | am21 EdDSA + Ley 164 | Key pair Ed25519 interno + Certificado RSA ADSIB | Interno: trigger-on-breach. ADSIB cert: 365 días (expiración física) | CRL ADSIB (publicación máx 24 h) + Vault disable | Renovación ADSIB presencial — requiere reaparición física ante notario |

**Catálogos que se necesitan:**

| Código | Gap | Qué se necesita |
|--------|-----|-----------------|
| G-B20-09 | Políticas CFG_POLICY_LIB D9 | `credential.{am_id}.rotation_trigger`, `credential.{am_id}.revocation_channels[]`, `credential.{am_id}.recovery_ial`, `credential.{am_id}.max_age_days`, `credential.{am_id}.binding_type` |
| G-B20-10 | Atoms D9 | `keycloak.g{admin}.d9.{revoke_credential}`, `vault.g{operator}.d9.{rotate_key}`, `vault.g{operator}.d9.{revoke_certificate}`, `keycloak.g{admin}.d9.{reset_totp}`, `keycloak.g{admin}.d9.{remove_webauthn}` |

---

### B21 — D12 Blockchain · Firma Digital DLT

**Actualmente:** solo `digital_signature.algorithm` en B1 · **Normas:** LEY-164 · ADSIB-FD-POLT-015 · SIN-RND · EIP-155

| Código | Gap | Norma | Qué se necesita |
|--------|-----|-------|-----------------|
| G-B21-01 | Políticas CFG_POLICY_LIB D12 | Ley 164 + ADSIB-FD-POLT-015 + SIN RND | `blockchain.enabled`, `blockchain.chain_id`, `blockchain.signing_algorithm`, `blockchain.ley164_compliance`, `blockchain.adsib_cert_required`, `blockchain.smart_contract_permissions[]` |
| G-B21-02 | Attrs D12 | Ley 164 Art. 78 + EIP-155 | `wallet_address` (Ethereum checksum format), `adsib_cert_serial`, `adsib_cert_expiry`, `blockchain_enabled_since` |
| G-B21-03 | Atoms D12 | Diseño SBOS — Besu QBFT | `besu.g{validator}.d12.{append_audit_entry}`, `keycloak.g{admin}.d12.{sign_document}`, `vault.g{operator}.d12.{manage_signing_key}` |

---

## Resumen de Cobertura

| Bloque | Nombre | Cobertura | Estado |
|--------|--------|-----------|--------|
| B1 | Identificación y Metadatos | 20% | ⚠ |
| B2 | Vigencia y Ciclo de Vida | 25% | ⚠ |
| B3 | Flujo de Aprobación | 15% | ⚠ |
| B4 | D1 Dominio Lógico | 65% | ✅ |
| B5 | D2 Dominio Físico | 50% | ✅ |
| B6 | Zonas de Negocio | 20% | ⚠ |
| B7 | Tryton 5 Capas | 40% | ⚠ |
| B8 | D3 Financiero | 55% | ✅ |
| B9 | SAM-128 + BitMask | 5% | ✗ |
| B10 | D10 Delegación | 45% | ✅ |
| B11 | Grupos H-RBAC | 15% | ⚠ |
| B12 | SoD Conflictos | 10% | ⚠ |
| B13 | D11 Auditoría | 60% | ✅ |
| B14 | Sync State | 5% | ✗ |
| B15–B21 | Dominios Pendientes | 8% | ✗ |
| **TOTAL** | | **~34%** | |

---

## Plan de Acción Priorizado

### P1 — CRÍTICO

| Código | Tarea | Norma | Impacto |
|--------|-------|-------|---------|
| G-P1-01 | Definir subestructura JSONB de B1 en objeto RT (meta: id, status, version, classification) | NIST AC-2 / ISO 24760-2 / INCITS 359 | B1 deja de ser hardcoded |
| G-P1-02 | Formalizar B12 SoD como tabla `bauth_sod_constraints` y conectar al RT | NIST AC-5 / INCITS 359 SSC | Verificación de conflictos en tiempo real |
| G-P1-03 | Agregar policies D7 (Red/NAC) a CFG_POLICY_LIB + atoms D7 al catálogo | NIST SP 800-207 / RFC 8705 | B18 D7 pasa de ausente a pendiente con datos |

### P2 — ALTA

| Código | Tarea | Norma | Impacto |
|--------|-------|-------|---------|
| G-P2-01 | Consolidar D4 Temporal en B15: policies + attrs timezone/schedule | NIST AC-2(d) / ISO 27001 A.5.18 | Eliminar duplicación B2+B4+B8 |
| G-P2-02 | Añadir attrs D3 SIN Bolivia (nit_emisor, modalidad_facturacion) + atoms firma | SIN RND 102100000011 / Ley 164 | B8 D3 con cobertura boliviana real |
| G-P2-03 | Completar B7 Tryton Capas 3-5: JSONB field_restrictions, button_rules, record_rules | NIST AC-6 / ISO A.8.11 / PCI Req 7.3 | Cobertura Tryton ~90% |
| G-P2-04 | Implementar policies D9 para los 18 métodos — ver tabla G-B20-01…G-B20-08 | NIST SP 800-63B-4 §5 / NIST IA-5 | B20 credenciales con lifecycle real |

### P3 — MEDIA

| Código | Tarea | Norma | Impacto |
|--------|-------|-------|---------|
| G-P3-01 | Implementar D8 Contexto: CAEP signals + adaptive_policies + risk_engine | OpenID CAEP 1.0 / NIST SP 800-207 §4 | B19 Zero Trust evaluación continua |
| G-P3-02 | Definir B3 Flujo Aprobación como tabla `bauth_approval_workflow` | NIST AC-5 / ISO 27001 A.5.18 / PCI 7.2.5 | B3 con workflow real |
| G-P3-03 | Conectar closure_role_hierarchy a B11 en objeto RT | ANSI INCITS 359 RBAC1 | B11 jerarquía real desde BD |
| G-P3-04 | Diseñar función `computeSAM128(RT)` en JS para demo / Rust para producción | BitMask Dual — diseño SBOS | B9 deja de ser decorativo |

---

## Referencias normativas

- NIST SP 800-63B-4 (2024): https://pages.nist.gov/800-63-4/
- NIST SP 800-53 Rev.5: https://csrc.nist.gov/publications/detail/sp/800/53/rev-5/final
- NIST SP 800-207 Zero Trust: https://csrc.nist.gov/pubs/sp/800/207/final
- NIST SP 800-162 ABAC: https://csrc.nist.gov/pubs/sp/800/162/upd2/final
- ISO/IEC 24760-2:2025: https://www.iso.org/standard/24760-2
- ISO/IEC 27001:2022: https://www.iso.org/standard/27001
- ISO/IEC 30107-3:2023: https://www.iso.org/standard/79520.html
- ANSI INCITS 359-2012 (R2022): https://webstore.ansi.org/standards/incits/incits3592012r2022
- RFC 9470 Step-Up: https://datatracker.ietf.org/doc/html/rfc9470
- RFC 8693 Token Exchange: https://datatracker.ietf.org/doc/html/rfc8693
- RFC 8705 mTLS: https://datatracker.ietf.org/doc/html/rfc8705
- OpenID CAEP 1.0: https://openid.net/specs/openid-caep-1_0-final.html
- PCI DSS 4.0: https://www.pcisecuritystandards.org/document_library/
- Ley 164 Bolivia / ADSIB: https://desarrollo.adsib.gob.bo/paginas-web/firma-digital/
- SIN RND 102100000011: https://www.impuestos.gob.bo/
