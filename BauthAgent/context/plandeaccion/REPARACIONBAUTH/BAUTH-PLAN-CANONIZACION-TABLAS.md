# BAUTH-PLAN-CANONIZACIÓN — Responsabilidades, Reorganización y Robustez
## Plan maestro de canonización de tablas de bAuth · 2026-06-30

**Propósito:** Definir con precisión quirúrgica el rol de CADA tabla, eliminar ambigüedades,
separar responsabilidades entre schemas, y establecer un plan de acción para tener políticas
robustas que resistan actualizaciones, configuraciones, y el crecimiento del Dashboard.

---

## PARTE 0 — LA PREGUNTA FUNDAMENTAL

> **"Si `cfg_policy_library` no se consulta en runtime, ¿para qué sirve después de la instalación?"**

Esta es la pregunta correcta. Hay DOS diseños posibles. Necesitamos elegir UNO.

---

### DISEÑO A — "Semilla de un solo uso" (lo que hay hoy)

```
framework_raw (16 JSON)
  └── CTE → cfg_policy_library (9,142 entradas)
        └── Seeds SQL (build time, UNA SOLA VEZ)
              └── ath_policy_d* + ath_config_d* + idn_role_d*
                    └── Runtime: SOLO estas tablas operativas
```

**Problema de este diseño:**
- `cfg_policy_library` queda como peso muerto después de la instalación
- Si actualizas un estándar en `framework_raw` o `cfg_policy_library`, **nada cambia en runtime**
- Hay que re-ejecutar seeds MANUALMENTE para propagar cambios
- El Dashboard consulta la biblioteca, pero muestra normas que pueden NO estar activas
- **Conclusión: `cfg_policy_library` es un elefante blanco de 9,142 filas**

### DISEÑO B — "Registro vivo + reconcile loop" (LO CORRECTO)

```
cfg_policy_library (fuente de verdad normativa, 9,142 entradas)
  │
  │  PROPAGACIÓN AUTOMÁTICA (reconcile loop 60s + triggers)
  │
  ├──▶ ath_policy_d*   (reglas operativas — las que evalúa runtime)
  ├──▶ ath_config_d*   (configs por dominio — las que consulta runtime)
  └──▶ idn_role_d*     (templates de rol — semilla para nuevos roles)
  │
  │  Cuando un admin (vía Dashboard) o un seed actualiza una política
  │  en cfg_policy_library, el reconcile loop detecta el cambio y
  │  actualiza automáticamente la tabla operativa correspondiente.
  │
  └──▶ Runtime: SOLO ath_policy_d* y prv_atom_policy. NUNCA cfg_policy_library.
```

**Ventaja de este diseño:**
- `cfg_policy_library` es la **fuente de verdad viva**, no un peso muerto
- Cambios en la biblioteca → propagación automática a tablas operativas
- El Dashboard muestra el estado REAL (biblioteca = operativo, o drift detectado)
- Las personalizaciones del admin sobreviven (columna `customized`)
- El reconcile loop ya existe (B45.D03) — solo hay que extenderlo

**RECOMENDACIÓN: Adoptar el Diseño B.** El reconcile loop actual (`sync/mod.rs`) ya verifica
drift entre `cfg_policy_library` y `ath_policy_d*`. Solo falta CERRAR el ciclo: que cuando
detecta drift, **actualice** automáticamente las tablas operativas, no solo registre el log.

---

## PARTE 0.1 — CÓMO FUNCIONA EL DISEÑO B (flujo completo)

### Paso 1 — Instalación inicial (build time)

```
1. Se cargan 16 JSON en framework_raw
2. CTE recursivo descompone en 9,142 filas en cfg_policy_library
3. Seeds SQL filtran cfg_policy_library → pueblan ath_policy_d* + ath_config_d*
4. Sistema operativo. Runtime evalúa con ath_policy_d*.
```

### Paso 2 — CRUD de políticas (flujo con revisión y autorización)

**El admin NUNCA escribe directamente en `ath_policy_d*`.** Esas tablas son READ-ONLY
para usuarios. Solo el mecanismo de propagación (reconcile loop / trigger) escribe en ellas.

El CRUD se hace SIEMPRE en `cfg_policy_library`, con un workflow de aprobación:

```
1. Admin de Dominio (Dashboard)
   "Necesito cambiar max_daily de $5,000 a $10,000"
   → UPDATE cfg_policy_library
     SET content = '{"max_daily": 10000, ...}',
         lifecycle = 'proposed',
         proposed_by = 'admin-jperez'
   → La política operativa (ath_policy_d3) NO cambia aún

2. Admin de Seguridad (Dashboard, bandeja de revisión)
   Ve políticas en estado 'proposed'
   Revisa: ¿cumple NIST? ¿respeta SoD? ¿no crea conflicto?
   → Aprueba: UPDATE lifecycle = 'active', approved_by = 'sec-admin'
   → Rechaza: UPDATE lifecycle = 'draft' + rejection_reason

3. Reconcile loop (60s) o Trigger
   Detecta: cfg_policy_library.lifecycle='active' ≠ ath_policy_d3.config
   → Propaga el cambio a ath_policy_d3
   → Registra en sync_log: quién propuso, quién aprobó

4. Runtime ya evalúa con la nueva política
   bauth.policy.domain.evaluate(D3, ctx) → max_daily=10000
   ath_policy_d3 quedó actualizada, trazable, auditable
```

### Protecciones del flujo

| Protección | Cómo se implementa |
|-----------|-------------------|
| **SoD** | Quien propone (admin de dominio) ≠ quien aprueba (admin de seguridad). Forzado por Dashboard. |
| **Trazabilidad** | `cfg_policy_library`: `proposed_by`, `approved_by`, `approved_at`. `sync_log`: registro de propagación. |
| **Rollback** | Revertir `lifecycle='active'` → `lifecycle='deprecated'` en biblioteca. Reconcile loop revierte en operativa. |
| **Anti-bypass** | `ath_policy_d*` es READ-ONLY para roles humanos. Sin GRANT INSERT/UPDATE/DELETE. Solo el sistema escribe. |
| **Auditoría** | Si una política causa incidente, el audit trail responde: ¿quién propuso? ¿quién aprobó? ¿cuándo se propagó? |

---

## PARTE 0.4 — RESPALDO NORMATIVO INTERNACIONAL

> **¿Qué exigen los estándares internacionales para proteger una base de datos**
> **de políticas de seguridad como `cfg_policy_library`?**

Investigación de 4 normas principales + mejores prácticas de la industria.

---

### ISO 27001:2022 — A.8.9 Configuration Management

**Fuente:** [ISO 27001:2022 Annex A Control 8.9](https://advisera.com/iso27001/control-8-9-configuration-management/)

> *"Establecer, documentar, implementar, monitorear y revisar configuraciones*
> *de hardware, software, servicios, redes e instalaciones."*

| Requisito | bAuth |
|-----------|-------|
| Línea base documentada | `framework_raw` (16 JSON fuente inmutables) |
| Control de cambios | Workflow draft→proposed→approved→active en `lifecycle` |
| Aprobación formal | `proposed_by` ≠ `approved_by` (SoD forzado) |
| Registro de cambios | `cfg_policy_library_audit` WORM + snapshot antes/después + hash SHA-256 |
| Verificación periódica | Reconcile loop (60s) verifica biblioteca = operativas |
| Anti-cambios no autorizados | `ath_policy_d*` READ-ONLY para humanos. Solo sistema propaga. |

---

### NIST SP 800-53 Rev 5 — CM-3 Configuration Change Control

**Fuente:** [NIST SP 800-53 Rev 5 — CM-3](https://csf.tools/controlset/nist800-53r5/)

> *"Determinar qué cambios son controlados, revisar y aprobar con análisis de*
> *impacto de seguridad, documentar decisiones, implementar cambios aprobados, retener registros."*

| Requisito | bAuth |
|-----------|-------|
| CM-3(a) Determinar cambios controlados | Toda política en `cfg_policy_library` (100%) |
| CM-3(b) Revisar y aprobar con impacto | `risk_level` + análisis antes de aprobar |
| CM-3(c) Documentar decisiones | `approved_by`, `approved_at`, `rejection_reason` |
| CM-3(d) Implementar aprobados | Reconcile loop propaga solo `lifecycle='active'` |
| CM-3(e) Retener registros | `cfg_policy_library_audit` WORM + hash-chain SHA-256 + Merkle D12 |
| CM-3(f) Auditar cambios | `sync_log` + reconcile loop detecta drift |
| CM-3(2) Test/Validate | `bauth.policy.simulate` antes de proponer |
| CM-3(5) Auto Security Response | Reconcile loop revierte cambios no autorizados |
| CM-3(6) Cryptography Mgmt | Hash SHA-256 encadenado + Merkle tree + blockchain |

---

### PCI DSS 4.0 — Requirement 6.5.1 Change Control

**Fuente:** [PCI DSS 4.0 Requirement 6.5.1](https://withpci.com/requirements/6/6.5/6.5.1)

> *"Cambios a componentes del sistema en producción siguen procedimientos que*
> *incluyen: razón, documentación, impacto de seguridad, aprobación, pruebas y rollback."*

| Requisito | bAuth |
|-----------|-------|
| Razón y descripción del cambio | `description` + `rejection_reason` |
| Impacto de seguridad documentado | `risk_level` (critical/high/medium/low) |
| Aprobación por autoridad designada | Solo Admin de Seguridad → `lifecycle='active'` |
| Pruebas sin impacto adverso | `bauth.policy.simulate` pre-propuesta |
| Procedimientos de fallback/rollback | Revertir lifecycle → reconcile loop revierte operativas |
| Registros de auditoría (10.5) | WORM inmutable + hash-chain + verificación externa |

---

### SOC 2 — CC8.1 Change Management

**Fuente:** [SOC 2 Trust Services Criteria — CC8.1](https://sprinto.com/blog/soc-2-change-management/)

> *"La entidad autoriza, diseña, configura, documenta, prueba, aprueba e implementa*
> *cambios a infraestructura, datos, software y procedimientos."*

| Punto de Control | bAuth |
|------------------|-------|
| Baseline Configuration | `framework_raw` + `cfg_policy_library` como línea base |
| Software Configuration | `ath_config_d*` parámetros rastreados a biblioteca |
| System Testing | `bauth.policy.simulate` antes de producción |
| Change Approval | Workflow con SoD: proponente ≠ aprobador |
| Emergency Changes | `lifecycle='draft'` → `active` con justificación |
| Patch Management | Actualizaciones de estándares → revisión → propagación |

---

### Policy as Code — Mejores prácticas 2024

**Fuentes:** [OPA Best Practices](https://www.wiz.io/academy/application-security/open-policy-agent-opa), [Policy as Code (O'Reilly 2024)](https://books.google.com/books?id=pNwREQAAQBAJ)

| Mejor práctica | bAuth |
|---------------|-------|
| Políticas en control de versiones | `framework_raw` Git-backed + `cfg_policy_library` SQL |
| Trazabilidad completa | `source` + `standard_ref` + `compliance_ref` |
| Advisory mode antes de bloqueo | `bauth.policy.simulate` |
| Inmutabilidad de logs | WORM + hash-chain + Merkle D12 |
| Separación staging/producción | `lifecycle` states: draft/proposed = staging, active = prod |
| Rollback automatizado | Revertir lifecycle → reconcile loop revierte |

---

### Tabla de cumplimiento consolidada

| Estándar | Control | bAuth |
|---------|---------|:---:|
| ISO 27001:2022 A.8.9 | Configuration Management | ✅ |
| ISO 27001:2022 A.8.2 | Privileged Access Rights | ✅ |
| ISO 27001:2022 A.8.15 | Logging | ✅ |
| NIST SP 800-53 CM-3 | Config Change Control | ✅ |
| NIST SP 800-53 CM-3(2) | Test/Validate/Document | ✅ |
| NIST SP 800-53 CM-3(5) | Auto Security Response | ✅ |
| NIST SP 800-53 CM-3(6) | Cryptography Mgmt | ✅ |
| PCI DSS 4.0 6.5.1 | Change Control Procedures | ✅ |
| PCI DSS 4.0 10.5 | Secure Audit Trails | ✅ |
| SOC 2 CC8.1 | Change Management | ✅ |
| OPA Best Practices | Policy as Code | ✅ |

### Conclusión normativa

Los 4 estándares internacionales coinciden en 7 requisitos para proteger una
biblioteca de políticas de seguridad. El diseño propuesto en este documento
cubre los 7:

| # | Requisito universal | Mecanismo bAuth |
|:--:|------|------|
| 1 | Workflow de aprobación con SoD | `lifecycle`: draft→proposed→approved |
| 2 | Trazabilidad completa | `proposed_by` + `approved_by` + `sync_log` |
| 3 | Inmutabilidad de auditoría | WORM + hash-chain SHA-256 + Merkle D12 |
| 4 | Separación staging/producción | `lifecycle` states |
| 5 | Rollback documentado | Revertir lifecycle → reconcile propaga |
| 6 | Verificación periódica | Reconcile loop 60s anti-drift |
| 7 | Protección anti-bypass | `ath_policy_d*` READ-ONLY, solo sistema escribe |

---

## PARTE 0.5 — LA FORTALEZA: Protección de `cfg_policy_library`

> **`cfg_policy_library` es la tabla más crítica de bAuth. Es la fuente de verdad**
> **de TODAS las políticas de seguridad. Si esta tabla se corrompe, bAuth miente.**
> **Si bAuth miente, el SBOS está completamente comprometido sin saberlo.**

Por eso `cfg_policy_library` requiere la **MÁXIMA** protección del ecosistema.
No es una tabla más. Es LA tabla.

### Nivel de protección requerido: FORTALEZA (máximo)

```
┌────────────────────────────────────────────────────────────────────┐
│                ANILLOS DE PROTECCIÓN DE cfg_policy_library          │
│                                                                    │
│  ANILLO 4 — AUDITORÍA WORM (todo acceso queda registrado)          │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ • Cada INSERT/UPDATE/DELETE → registrado en prv_atom_audit   │ │
│  │ • Cada SELECT → registrado en audit_log (lecturas sensibles) │ │
│  │ • Hash-chain SHA-256 encadenado entre versiones              │ │
│  │ • Merkle tree + anclaje blockchain D12 (inmutable externo)    │ │
│  │ • NADIE puede leer sin dejar huella. NADIE.                   │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  ANILLO 3 — AUTORIZACIÓN (solo roles de élite)                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ • ¿Quién PUEDE proponer?   → SU, SYS, Admin de Seguridad     │ │
│  │ • ¿Quién PUEDE aprobar?    → SU, Admin de Seguridad (≠ proponente) │
│  │ • ¿Quién PUEDE rechazar?   → SU, Admin de Seguridad           │ │
│  │ • ¿Quién PUEDE leer?       → Admins autenticados (todos los tiers) │
│  │ • ¿Quién PUEDE NUNCA?      → EXT_N0, VISITANTE, M2M           │ │
│  │ • SoD forzado: proponente ≠ aprobador (CHECK en aplicación)   │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  ANILLO 2 — AUTENTICACIÓN (múltiples factores obligatorios)        │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ • AAL3 obligatorio para MODIFICAR (escribir)                  │ │
│  │   → Passkey device-bound (FIDO2 HW) + verificación biométrica │ │
│  │ • AAL2 obligatorio para LEER (consultar)                       │ │
│  │   → Password + TOTP o WebAuthn                                 │ │
│  │ • Step-Up en cada operación de escritura                       │ │
│  │   → Reautenticación fresca (maxAgeSeconds=0) por operación    │ │
│  │ • Sin sesión persistente para escritura                        │ │
│  │   → Cada UPDATE requiere reautenticación < 60s de antigüedad  │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  ANILLO 1 — TRAZABILIDAD (quién, qué, cuándo, por qué, ctx_id)    │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ • Columnas de auditoría EN la misma tabla:                    │ │
│  │   proposed_by, approved_by, approved_at, rejection_reason    │ │
│  │ • Tabla hermana WORM: cfg_policy_library_audit                │ │
│  │   snapshot COMPLETO del registro antes del cambio             │ │
│  │ • ctx_id obligatorio en cada operación                        │ │
│  │ • Hash SHA-256 del previous_state encadenado                  │ │
│  │ • Merkle proof verificable por terceros (sin acceso a BD)     │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  ╔══════════════════════════════════════════════════════════════╗ │
│  ║  cfg_policy_library — si alguien la modifica sin permiso,   ║ │
│  ║  LO SABREMOS. Quién, cuándo, desde dónde, con qué token.    ║ │
│  ║  Inmutable externamente vía Merkle + Blockchain D12.         ║ │
│  ╚══════════════════════════════════════════════════════════════╝ │
└────────────────────────────────────────────────────────────────────┘
```

### Tabla de auditoría hermana (WORM)

```sql
CREATE TABLE bauth.cfg_policy_library_audit (
    audit_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    section_id      INTEGER NOT NULL,         -- FK a cfg_policy_library
    operation       TEXT NOT NULL,            -- INSERT, UPDATE, DELETE, APPROVE, REJECT
    previous_state  JSONB NOT NULL,           -- snapshot completo ANTES del cambio
    new_state       JSONB NOT NULL,           -- snapshot completo DESPUÉS del cambio
    changed_by      TEXT NOT NULL,            -- quién (user_uuid)
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL,            -- contexto de trazabilidad SBOS-049
    auth_method     TEXT NOT NULL,            -- cómo se autenticó (PASSKEY, TOTP...)
    loa_at_time     INTEGER NOT NULL,         -- nivel de aseguramiento al momento del cambio
    previous_hash   TEXT,                     -- SHA-256 del registro anterior (chain)
    current_hash    TEXT NOT NULL,            -- SHA-256 de este registro
    merkle_batch_id UUID,                     -- FK a blk_merkle_batch (anclaje D12)

    -- WORM: sin UPDATE, sin DELETE
    CONSTRAINT chk_audit_operation CHECK (operation IN (
        'INSERT','UPDATE','DELETE','APPROVE','REJECT','PROPAGATE'))
);

-- Permisos restrictivos
REVOKE ALL ON bauth.cfg_policy_library_audit FROM PUBLIC;
REVOKE INSERT, UPDATE, DELETE ON bauth.cfg_policy_library_audit FROM bauth_admin;
-- Solo el sistema (bauth daemon) puede INSERTAR en la auditoría
```

### Requisitos de autenticación por operación

| Operación | AAL mínimo | Step-Up | Reautenticación | ¿Quién? |
|-----------|:---:|:---:|:---:|------|
| **SELECT** (leer biblioteca) | AAL2 | No | No requerida | Cualquier admin autenticado |
| **INSERT** (nueva política) | AAL3 | Sí | < 60s | Admin de Dominio |
| **UPDATE** (modificar existente) | AAL3 | Sí | < 60s | Admin de Dominio |
| **DELETE** (soft-delete) | AAL3 | Sí | < 60s | Admin de Seguridad |
| **APPROVE** (cambiar lifecycle→active) | AAL3 | Sí | < 0s (fresca) | Admin de Seguridad |
| **REJECT** (cambiar lifecycle→draft) | AAL3 | Sí | < 60s | Admin de Seguridad |

### Columnas adicionales requeridas en cfg_policy_library

| Columna | Tipo | Propósito |
|--------|------|------|
| `proposed_by` | `text` | user_uuid de quien propuso |
| `proposed_at` | `timestamptz` | cuándo se propuso |
| `approved_by` | `text` | user_uuid de quien aprobó |
| `approved_at` | `timestamptz` | cuándo se aprobó |
| `rejection_reason` | `text` | motivo de rechazo |
| `previous_hash` | `text` | SHA-256 del estado anterior (chain integrity) |
| `current_hash` | `text` | SHA-256 del estado actual |

### Por qué esto es la base de la confianza

```
La seguridad de bAuth se basa en:
  cfg_policy_library → ath_policy_d* → evaluación en runtime → JWT emitido

Si cfg_policy_library NO es confiable:
  ❌ Las políticas operativas se basan en datos potencialmente corruptos
  ❌ La evaluación en runtime decide con reglas que NADIE aprobó
  ❌ El JWT emitido otorga permisos que NADIE autorizó
  ❌ La auditoría muestra decisiones basadas en políticas FALSIFICADAS
  ❌ bAuth viola ISO 27001, NIST 800-53, PCI DSS, GDPR, SOX

Si cfg_policy_library SÍ es confiable (FORTALEZA):
  ✅ Cada política tiene trazabilidad completa: propuesta → revisión → aprobación
  ✅ Cada cambio requiere AAL3 + Step-Up + SoD
  ✅ Cada acceso queda registrado en WORM + hash-chain + blockchain D12
  ✅ La confianza es VERIFICABLE por terceros sin acceso a la BD
  ✅ bAuth cumple TODOS los estándares de seguridad internacionales
```

```
1. Admin carga nuevo JSON en framework_raw (vía Dashboard o bosctl)
2. CTE se re-ejecuta → nuevas entradas en cfg_policy_library con lifecycle='draft'
3. Admin de Seguridad revisa las nuevas entradas → aprueba las que aplican
   → lifecycle='active' para las aprobadas
4. Reconcile loop (60s) detecta las nuevas active → INSERT en ath_policy_d9
5. Runtime ya está actualizado. Cero intervención manual en tablas operativas.
```

### Paso 4 — Admin personaliza una política existente (vía Dashboard)

```
1. Admin cambia max_daily de $5,000 a $10,000 en ath_policy_d3
2. Dashboard marca customized=true en esa fila
3. Si mañana se re-ejecuta el seed, el ON CONFLICT respeta customized=true
4. El reconcile loop muestra "DRIFT_OK" para políticas customizadas
```

### Paso 4 — Dashboard consulta el estado real

```
Panel 4 — Biblioteca de Políticas:
  ┌─────────────────────────────────────────────────────────┐
  │ Dominio D3 — Financiero                                 │
  │                                                         │
  │ 📚 Biblioteca (cfg_policy_library):  10 normas          │
  │ ⚙️  Operativas (ath_policy_d3):      10 activas         │
  │ ✅ Sincronizadas:                    8                  │
  │ 🟡 Customizadas (admin):             2                  │
  │ 🔴 Drift detectado:                  0                  │
  │                                                         │
  │ [Sincronizar ahora] [Ver drift] [Re-ejecutar seeds]    │
  └─────────────────────────────────────────────────────────┘
```

---

## PARTE 0.2 — ARQUITECTURA CORRECTA DE 3 CAPAS

```
┌──────────────────────────────────────────────────────────────────────┐
│  CAPA 0 — BIBLIOTECA NORMATIVA (cfg_policy_library)                   │
│                                                                      │
│  ROL: Fuente de verdad documental. Registro VIVO.                    │
│  ¿Runtime? NO directamente, pero el reconcile loop propaga cambios.  │
│  ¿Modificable? Sí — vía Dashboard (admin) o seeds (build time).      │
│  ¿Utilidad continua? Es el "source of truth" del que dependen        │
│  las tablas operativas. Sin él, no hay trazabilidad de "por qué      │
│  existe esta política".                                              │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
          ┌──────────────────┴──────────────────┐
          │  Reconcile loop (60s) + triggers    │
          │  propaga cambios a tablas operativas │
          └──────────────────┬──────────────────┘
                             │
         ┌───────────────────┴───────────────────┐
         ▼                                       ▼
┌────────────────────────────┐    ┌──────────────────────────────────┐
│  CAPA 1 — REGLAS OPERATIVAS│    │  CAPA 2 — POLÍTICAS POR ÁTOMO    │
│  POR DOMINIO               │    │                                  │
│  ath_policy_d1..d12        │    │  prv_atom_policy (6,782)         │
│  (~100 reglas activas)     │    │                                  │
│                            │    │  ROL: Decisión final por átomo   │
│  ROL: Evaluar PERMITIR/    │    │  Formato: XACML 3.0              │
│  DENEGAR en runtime.       │    │  (target + condition + effect)   │
│                            │    │                                  │
│  CONSULTADA por:           │    │  CONSULTADA por:                 │
│  bauth.policy.domain       │    │  bauth.policy.evaluate           │
│  .evaluate                 │    │  bauth.access.evaluate           │
│                            │    │  (policy-path post fast-path)    │
│  ACTUALIZADA por:          │    │                                  │
│  reconcile loop (drift),   │    │  ACTUALIZADA por:                │
│  Dashboard (admin)         │    │  Seeds + RoleManager             │
└────────────────────────────┘    └──────────────────────────────────┘
```

**Regla nemotécnica:**
- **cfg_policy_library** = "el diccionario" (qué dicen las normas)
- **ath_policy_d*** = "las reglas de la casa" (qué aplicamos de esas normas)
- **prv_atom_policy** = "el portero" (decisión final por operación)

## PARTE 0.3 — MECANISMO DE PROPAGACIÓN (cómo funciona el Diseño B)

### El reconcile loop como propagador

El reconcile loop actual ya detecta drift entre `cfg_policy_library` y `ath_policy_d*`.
Solo registra en `sync_log`. **Hay que extenderlo para que además ACTUALICE las tablas operativas.**

La lógica es:

```
Cada 60s, para cada dominio D1..D12:

1. NUEVAS políticas en la biblioteca que NO están en ath_policy_dN
   → INSERT en ath_policy_dN con is_active=true

2. Políticas EXISTENTES cuyo content cambió en la biblioteca
   → UPDATE solo si customized=false (no fueron personalizadas por el admin)

3. Políticas en ath_policy_dN que YA NO están en la biblioteca
   → Soft-delete (is_active=false) solo si customized=false
```

### La columna `customized` — protección de personalizaciones

Cada `ath_policy_d*` necesita una columna `customized BOOLEAN DEFAULT false`:

- `false` = esta política vino de la biblioteca. El reconcile loop PUEDE actualizarla.
- `true` = un admin la personalizó vía Dashboard. El reconcile loop NUNCA la toca.

Esto garantiza que las personalizaciones del admin sobreviven a:
- Re-ejecuciones de seeds
- Actualizaciones de estándares en la biblioteca
- Propagaciones automáticas del reconcile loop

### Flujo completo con el Dashboard

```
Admin abre Dashboard → Panel 4 (Biblioteca de Políticas)
  │
  ├── Ve política "max_daily = $5,000" (fuente: cfg_policy_library, NIST SP 800-63B)
  ├── La cambia a "$10,000" → Dashboard actualiza ath_policy_d3
  │     y marca customized=true
  │
  ├── 6 meses después: NIST actualiza el estándar → nuevo JSON en framework_raw
  ├── CTE regenera cfg_policy_library → "max_daily" ahora dice "$7,500"
  ├── Reconcile loop detecta el cambio en la biblioteca
  │     pero ve customized=true en ath_policy_d3 → NO la sobrescribe
  │
  └── Dashboard muestra: "⚠️ Política personalizada difiere de la biblioteca"
        El admin decide: ¿mantener $10,000 o adoptar $7,500?
```

### ¿Trigger o reconcile loop?

Dos opciones para propagar cambios:

| Mecanismo | Ventaja | Desventaja |
|-----------|---------|------------|
| **Trigger SQL** (ON INSERT/UPDATE en cfg_policy_library) | Instantáneo. Sin delay. | Acopla la biblioteca a las operativas. Si falla el trigger, falla el INSERT. |
| **Reconcile loop** (cada 60s, código Rust) | Desacoplado. Robusto. El loop ya existe. | Hasta 60s de delay entre cambio y propagación. |

**Recomendación:** Usar AMBOS. El trigger para el 95% de los casos (respuesta inmediata).
El reconcile loop como red de seguridad (detecta y corrige cualquier inconsistencia).

---

## PARTE 1 — CANONIZACIÓN DE NOMBRES

### 1.1 Prefijos de tabla por subsistema

Cada subsistema de bAuth debe tener un prefijo consistente de 3-4 letras.
Esto permite identificar instantáneamente a qué dominio pertenece una tabla.

| Prefijo | Dominio | Significado | Tablas actuales | Tablas canónicas |
|---------|---------|------------|---------|---------|
| **prv_** | Privilegios | PRiVilege engine | `privilege_domain`, `privilege_atom`, `privilege_role`, `privilege_role_atom`, `privilege_atom_policy`, `privilege_atom_audit`, `privilege_application`, `privilege_group`, `privilege_verb` | `prv_domain`, `prv_atom`, `prv_role`, `prv_role_atom`, `prv_atom_policy`, `prv_atom_audit`, `prv_application`, `prv_group`, `prv_verb` |
| **ath_** | Autenticación | AuTHentication | `ath_method`, `ath_policy_d*`, `ath_config_d*`, `ath_login_attempt`, `ath_mfa_enrollment`, `ath_binding`, `ath_revocation`, `ath_credential_policy`, `ath_federation_protocol`, etc. | Se mantiene |
| **fin_** | Financiero | FINancial | `fin_transaction_type`, `fin_sod_rule`, `fin_limit`, `fin_decision_matrix`, `fin_approval_chain`, etc. | Se mantiene |
| **fis_** | Físico | FISical | `fis_access_zone`, `fis_controller`, `fis_device`, `fis_location`, etc. | Se mantiene |
| **geo_** | Geoespacial | GEOspatial | `geo_fence`, `geo_trust_tier`, `geo_velocity_policy`, etc. | Se mantiene |
| **ses_** | Sesiones | SESsion | `ses_context`, `ses_context_switch`, `ses_ses_risk_policy`, `ses_caep_config`, `ses_superuser_context` | Se mantiene |
| **aud_** | Auditoría | AUDit | `aud_event`, `aud_review`, `aud_ghost_account`, `aud_policy_change`, `aud_compliance_map`, etc. | Se mantiene |
| **blk_** | Blockchain | BLocKchain | `blk_anchor`, `blk_merkle_batch`, `blk_merkle_leaf`, `blk_account`, `blk_reconciliation` | Se mantiene |
| **dlg_** | Delegación | DeLeGation | `dlg_delegation` | Se mantiene |
| **net_** | Red | NETwork | `net_device`, `net_ztna_policy` | Se mantiene |
| **idn_** | Identidad | IDentity | `idn_role_template`, `idn_user_template`, `idn_tenant`, `idn_role_closure`, `idn_user_role`, `idn_tier_policy`, etc. | Se mantiene |
| **org_** | Organización | ORGanization | `org_empresa`, `org_sucursal`, `org_pos_logico` | Se mantiene |
| **sec_** | Seguridad | SECurity | `sec_key_inventory`, `sec_key_rotation`, `sec_key_recovery` | Se mantiene |
| **cfg_** | Configuración | ConFiG | `cfg_policy_library`, `cfg_validation_rule`, `cfg_validation_log`, `cfg_key_translation` | Se mantiene |
| **log_** | Lógico | LOGical | `log_zone` | Se mantiene |
| **bglobal.*** | Global SBOS | Ecosistema completo | `global_config`, `global_country`, `global_language`, `global_currency`, `menu_item`, `menu_context`, `menu_item_atom` | Se mantiene |
| **bcalendar.*** | Calendario | Ecosistema completo | `cal_calendar`, `cal_event`, `cal_holiday`, `cal_alarm`, `cal_schedule`, etc. | Se mantiene |

### 1.2 Cambio `privilege_*` → `prv_*`

**Motivo:** `privilege_` es muy largo (9 caracteres). `prv_` son 3 letras como el resto de prefijos.
Consistencia con `ath_`, `fin_`, `fis_`, `geo_`, `ses_`, `aud_`, `blk_`, `dlg_`, `net_`, `idn_`, `org_`, `sec_`.

```sql
-- RENOMBRAR (en orden, por dependencias FK):
ALTER TABLE bauth.privilege_domain       RENAME TO prv_domain;
ALTER TABLE bauth.privilege_application  RENAME TO prv_application;
ALTER TABLE bauth.privilege_group        RENAME TO prv_group;
ALTER TABLE bauth.privilege_verb         RENAME TO prv_verb;
ALTER TABLE bauth.privilege_atom         RENAME TO prv_atom;
ALTER TABLE bauth.privilege_role         RENAME TO prv_role;
ALTER TABLE bauth.privilege_role_atom    RENAME TO prv_role_atom;
ALTER TABLE bauth.privilege_atom_policy  RENAME TO prv_atom_policy;
ALTER TABLE bauth.privilege_atom_audit   RENAME TO prv_atom_audit;
-- Actualizar FKs, índices, y código Rust que referencia estas tablas
```

---

## PARTE 2 — SEPARACIÓN DE CONFIGURACIONES

### 2.1 El problema actual

Actualmente hay **TRES lugares** donde se puede configurar un mismo parámetro:

```
"Quiero cambiar el session_timeout a 4 horas"
  → ¿Lo pongo en bglobal.global_config?
  → ¿O en bauth.ath_config?
  → ¿O en bauth.ath_config_d8?
  → NADIE SABE. No hay reglas.
```

### 2.2 La solución: Separación por ámbito

| Schema | Tabla | Ámbito | Quién la modifica | Ejemplos |
|--------|-------|--------|-------------------|---------|
| **bglobal** | `global_config` | Ecosistema SBOS completo | Solo BOS (IAM Installer) | `sbos_version`, `default_locale`, `kong_admin_url`, `vault_addr` |
| **bauth** | `ath_config_d*` | Dominio específico D1-D12 | Dashboard bAuth (admin) | `token_ttl` (D1), `door_relay_ms` (D2), `password_min_length` (D9) |
| **idn_tenant** | `idn_tenant_config` | Tenant específico | Admin del tenant | `locale`, `timezone`, `currency`, `theme`, `fiscal_year_start` |

**Regla absoluta:**
> `bglobal.global_config` SOLO para parámetros que aplican a TODO el ecosistema SBOS.
> bAuth NUNCA escribe en `bglobal`. Solo LEE.
> `ath_config_d*` es para parámetros que aplican a un dominio de control (D1-D12).
> `idn_tenant_config` es para parámetros regionales de un tenant.

### 2.3 Migración de `ath_config` → `ath_config_d*` o `bglobal`

`ath_config` actualmente tiene handler activo (`bauth.config.list` en `framework_crud.rs`).
Pero su formato `(config_key, config_value, tier)` se solapa con `ath_config_d*`.

**Plan:**
1. Migrar configs de `ath_config` que sean por dominio → `ath_config_d*` correspondiente
2. Migrar configs de `ath_config` que sean globales → `bglobal.global_config`
3. Eliminar `ath_config`
4. Actualizar `framework_crud.rs` para leer de `ath_config_d*` y `bglobal.global_config`

---

## PARTE 3 — RESPONSABILIDADES PRECISAS DE CADA TABLA

### 3.1 Tablas del Framework (cfg_*)

| Tabla | Responsabilidad | ¿Runtime? | ¿Modificable? |
|-------|---------------|:---:|:---:|
| `framework_raw` | Almacenar 16 documentos JSON fuente. Inmutable después de carga. | ❌ | Solo build time |
| `cfg_policy_library` | Ser el diccionario unificado de 9,142 normas. Fuente de verdad documental. | ❌ | Solo build time (seeds) |
| `cfg_key_translation` | Traducir 221+ claves JSON inglés→español. | ❌ | Solo build time |
| `cfg_validation_rule` | Definir reglas TYPE/RANGE/ENUM para validar campos de templates. | ✅ | Admin (Dashboard) |
| `cfg_validation_log` | Registrar validaciones fallidas. WORM inmutable. | ✅ | Solo INSERT automático |

### 3.2 Tablas de Políticas Operativas (ath_policy_d*)

| Tabla | Responsabilidad | ¿Runtime? | ¿Modificable? |
|-------|---------------|:---:|:---:|
| `ath_policy_d1..d12` | Evaluar PERMITIR/DENEGAR en runtime por dominio. | ✅ | Admin (Dashboard), seeds idempotentes |

**Regla de robustez:** Cada `ath_policy_d*` debe tener un seed SQL que:
1. Lee `cfg_policy_library` filtrando por `domain_map` y `enforcement IN ('mandatory','recommended')`
2. INSERTA con `ON CONFLICT (policy_code) DO UPDATE` para preservar personalizaciones del admin
3. NUNCA borra políticas que el admin creó manualmente

### 3.3 Tablas de Configuración por Dominio (ath_config_d*)

| Tabla | Responsabilidad | ¿Runtime? | ¿Modificable? |
|-------|---------------|:---:|:---:|
| `ath_config_d1..d12` | Almacenar parámetros operativos por dominio D1-D12. | ❌ (hoy) | Admin (Dashboard) |

**Importante:** Hoy `ath_config_d*` NO se consulta en runtime. El código Rust usa `bglobal.global_config`.
Hay que decidir: ¿activamos `ath_config_d*` en runtime o migramos todo a `bglobal`?

**Recomendación:** Activar `ath_config_d*` en runtime. Cada DomainEvaluator debe consultar
su `ath_config_dN` correspondiente al evaluar. Ej: `FinancialEvaluator` lee `ath_config_d3`
para obtener `currency_default`, `approval_timeout_h`, etc.

### 3.4 Tablas del Motor de Privilegios (prv_*)

| Tabla | Responsabilidad |
|-------|---------------|
| `prv_domain` | Catálogo de 12 dominios D1-D12. Metadatos: `domain_slug`, `requires_policy`, `evaluation_order`, `short_circuit`. |
| `prv_application` | Catálogo de aplicaciones del ecosistema (Tryton, Superset, Mattermost, etc.). |
| `prv_group` | Agrupación lógica de átomos (ventas, compras, admin, reportes...). |
| `prv_verb` | Verbos de operación: CREATE, READ, UPDATE, DELETE + extendidos. |
| `prv_atom` | Catálogo de 5,808 átomos indivisibles. `atom_position` = índice en RolBitMask. |
| `prv_role` | Roles definidos por tenant. |
| `prv_role_atom` | Asignación Rol↔Átomo. `allowed=true` = bit en 1. |
| `prv_atom_policy` | Políticas XACML por átomo. 6,782 registros. CAPA 2 de evaluación. |
| `prv_atom_audit` | Auditoría WORM de decisiones de acceso. Particionado por mes. |

---

## PARTE 4 — PLAN DE ACCIÓN (4 fases)

### FASE 1 — CANONIZAR (sprint actual, 0 riesgo)

**Objetivo:** Poner orden sin romper nada. Solo renombrar y documentar.

| Acción | Prioridad | Esfuerzo |
|--------|:---:|:---:|
| 1.1 Renombrar `privilege_*` → `prv_*` (9 tablas + actualizar FKs, índices, seeds, código Rust) | 🔴 | 4h |
| 1.2 Renombrar `bos_crypto_algorithm` → `sec_crypto_algorithm` | 🟡 | 0.5h |
| 1.3 Renombrar `bos_rol_template_history` → `idn_role_template_history` | 🟡 | 0.5h |
| 1.4 Agregar `COMMENT ON TABLE` a TODAS las tablas con su responsabilidad precisa | 🟠 | 2h |
| 1.5 Corregir referencias `bos_privilege` → `bauth` en código Rust | 🔴 | 0.5h |

### FASE 2 — SEPARAR (siguiente sprint, riesgo bajo)

**Objetivo:** Separar configuraciones globales de bAuth.

| Acción | Prioridad | Esfuerzo |
|--------|:---:|:---:|
| 2.1 Migrar `ath_config` → `ath_config_d*` + `bglobal.global_config` | 🟠 | 3h |
| 2.2 Eliminar tabla `ath_config` después de migración | 🟠 | 0.5h |
| 2.3 Actualizar `framework_crud.rs` para leer de nuevas tablas | 🟠 | 2h |
| 2.4 Documentar regla de precedencia: `ath_config_d*` > `bglobal.global_config` | 🟠 | 0.5h |

### FASE 3 — ACTIVAR (siguiente sprint, riesgo medio)

**Objetivo:** Hacer que `ath_config_d*` sea consultado en runtime.

| Acción | Prioridad | Esfuerzo |
|--------|:---:|:---:|
| 3.1 Cada DomainEvaluator consulta su `ath_config_dN` al evaluar | 🟠 | 4h |
| 3.2 Crear handler `bauth.config.domain.get(domain)` para el Dashboard | 🟠 | 1h |
| 3.3 Seeds idempotentes: `ON CONFLICT DO UPDATE` preservando personalizaciones | 🟠 | 2h |

### FASE 4 — LIMPIAR (planificado, riesgo medio)

**Objetivo:** Eliminar tablas legacy y código muerto.

| Acción | Prioridad | Esfuerzo |
|--------|:---:|:---:|
| 4.1 Marcar `ath_policy` como DEPRECADO → eliminar en siguiente release | 🟡 | 0.5h |
| 4.2 Marcar `bos_permiso_logico` como DEPRECADO → eliminar | 🟡 | 0.5h |
| 4.3 Migrar `ath_credential_policy` → `ath_policy_d9` (unificar formato JSONB) | 🟡 | 2h |
| 4.4 Eliminar `ath_credential_policy` después de migración | 🟡 | 0.5h |

---

## PARTE 5 — ROBUSTEZ ANTE ACTUALIZACIONES

### 5.1 Principio de seeds idempotentes

Cada seed SQL DEBE ser idempotente. Esto significa que puede ejecutarse N veces
y producir el mismo resultado sin errores:

```sql
-- ✅ CORRECTO: seed idempotente
INSERT INTO bauth.ath_policy_d3 (policy_code, policy_name, config, is_active)
SELECT section_name, section_name, content, true
FROM bauth.cfg_policy_library
WHERE semantic_type = 'policy'
  AND domain_map @> '{D3}'
  AND enforcement IN ('mandatory', 'recommended')
ON CONFLICT (policy_code) DO UPDATE SET
  policy_name = EXCLUDED.policy_name,
  config = COALESCE(ath_policy_d3.config, EXCLUDED.config)  -- preserva personalización
WHERE ath_policy_d3.config IS NULL;  -- solo actualiza si no fue personalizado
```

### 5.2 Principio de biblioteca → operativo

Cuando se actualiza un estándar (ej: NIST SP 800-63B Rev.5), el flujo es:

```
1. Actualizar framework_raw con el nuevo JSON
2. Re-ejecutar el CTE para regenerar cfg_policy_library
3. Re-ejecutar seeds SQL (idempotentes)
   → Las políticas operativas se actualizan SOLO si no fueron personalizadas
4. El reconcile loop detecta el cambio → emite alerta
5. El Dashboard muestra las políticas actualizadas para revisión del admin
```

### 5.3 Principio de personalización preservada

Cuando un admin personaliza una política (ej: cambia `max_daily` de $5,000 a $10,000),
esa personalización DEBE sobrevivir a futuras actualizaciones de seeds:

```sql
-- La columna 'customized' protege las personalizaciones
ALTER TABLE bauth.ath_policy_d3 ADD COLUMN IF NOT EXISTS customized BOOLEAN DEFAULT false;

-- El seed solo actualiza si NO fue personalizado
ON CONFLICT (policy_code) DO UPDATE SET
  config = CASE WHEN ath_policy_d3.customized = false
                THEN EXCLUDED.config
                ELSE ath_policy_d3.config END;
```

---

## PARTE 6 — DIAGRAMA CANÓNICO FINAL

```
┌──────────────────────────────────────────────────────────────────────┐
│                     ECOSISTEMA SBOS COMPLETO                          │
│                                                                      │
│  bglobal schema (compartido por TODOS los daemons)                    │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ global_config  global_country  global_language  global_currency│   │
│  │ menu_item      menu_context   menu_item_atom                  │   │
│  │ geo_timezone                                                  │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  bcalendar schema (subsistema de calendario, compartido)             │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ cal_calendar  cal_event  cal_holiday  cal_alarm              │   │
│  │ cal_schedule  cal_fiscal_year  cal_overtime_policy           │   │
│  │ cal_break_policy  cal_notification_log                       │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ╔══════════════════════════════════════════════════════════════╗   │
│  ║                BAUTH SCHEMA (daemon bAuth)                   ║   │
│  ╠══════════════════════════════════════════════════════════════╣   │
│  ║                                                              ║   │
│  ║  FRAMEWORK (cfg_*)       PRIVILEGIOS (prv_*)                 ║   │
│  ║  ┌──────────────────┐    ┌──────────────────────────────┐   ║   │
│  ║  │ cfg_policy_library│    │ prv_domain  prv_atom        │   ║   │
│  ║  │ framework_raw     │    │ prv_role    prv_role_atom   │   ║   │
│  ║  │ cfg_validation_*  │    │ prv_atom_policy             │   ║   │
│  ║  │ cfg_key_translation│   │ prv_atom_audit (WORM)       │   ║   │
│  ║  └──────────────────┘    └──────────────────────────────┘   ║   │
│  ║           │                         │                        ║   │
│  ║           │ alimenta                │ consulta               ║   │
│  ║           ▼                         ▼                        ║   │
│  ║  POLÍTICAS (ath_*)       DOMINIOS (D1-D12)                   ║   │
│  ║  ┌──────────────────┐    ┌──────────────────────────────┐   ║   │
│  ║  │ ath_policy_d1..12│    │ fin_*  fis_*  geo_*  ses_*  │   ║   │
│  ║  │ ath_config_d1..12│    │ aud_*  blk_*  dlg_*  net_*  │   ║   │
│  ║  │ ath_method       │    │ idn_*  org_*  sec_*  log_*  │   ║   │
│  ║  └──────────────────┘    └──────────────────────────────┘   ║   │
│  ║                                                              ║   │
│  ║  IDENTIDAD (idn_*)                                          ║   │
│  ║  ┌──────────────────────────────────────────────────────┐   ║   │
│  ║  │ idn_role_template    idn_user_template               │   ║   │
│  ║  │ idn_role_d1..d12     idn_role_closure                │   ║   │
│  ║  │ idn_tenant           idn_tier_policy                 │   ║   │
│  ║  │ idn_user_role        idn_tenant_config               │   ║   │
│  ║  └──────────────────────────────────────────────────────┘   ║   │
│  ╚══════════════════════════════════════════════════════════════╝   │
└──────────────────────────────────────────────────────────────────────┘
```

---

## RESUMEN EJECUTIVO

| Problema | Solución | Fase |
|---------|---------|:---:|
| `privilege_*` muy largo, inconsistente | Renombrar a `prv_*` | F1 |
| `bos_*` en schema bauth (confuso) | Renombrar a prefijo correcto | F1 |
| 3 tablas de config compitiendo | `bglobal`=SBOS, `ath_config_d*`=bAuth, `idn_tenant_config`=tenant | F2 |
| `cfg_policy_library` no entendido | Documentado como "diccionario de referencia, NO runtime" | F1 |
| `ath_policy` tabla vacía legacy | Marcar DEPRECADO → eliminar | F4 |
| `ath_credential_policy` duplicado con D9 | Migrar a `ath_policy_d9` (JSONB) | F4 |
| Seeds frágiles (no sobreviven updates) | Idempotentes con `ON CONFLICT DO UPDATE` + columna `customized` | F3 |
| `ath_config_d*` no consultado en runtime | Activar en DomainEvaluators | F3 |
| `bos_privilege` referenciado en código | Corregir a `bauth` (BUG) | F1 |

---

*BAUTH-PLAN-CANONIZACION-TABLAS.md v1.0 · 2026-06-30*
