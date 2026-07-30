# A.65.03.01.03 — Informe de Completitud: D02 Control de Acceso Físico

**Versión:** 1.1.0 · **Fecha:** 2026-07-30
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D02.*`)
**SSOT DDL:** `SBOS_db_V2_DDL.sql` v2.0.0 + `SBOS_db_V2_DDL_MANUAL.md` v2.7.0
**Estado de D02:** ❌ SIN IMPLEMENTAR — 0/9 bloques con tablas propias · 9 tablas propuestas (T-220..T-228)

> **Metodología:** ver A.65.03.01.01 §1. Criterios C1–C7 aplicados a cada bloque.
> **T-code range:** T-220..T-239 (prefijo `idn_acceso_fisico_*`)

---

## 1. Estado global de D02

**Dominio:** Control de Acceso Físico | **Pipeline:** IAM Physical Gate (PIV / OSDP / PACS)
**Total bloques:** 8 | **Tablas propias:** 0 (ninguna implementada) | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | T-code propuesto |
|--------|------|--------|--------|-----------------|
| B01 | `facilities` | Instalaciones Físicas | ❌ FALTANTE | T-220 |
| B02 | `readers` | Lectores OSDP | ❌ FALTANTE | T-221 |
| B03 | `presence` | Presencia Dual / Exclusa | ❌ FALTANTE | T-222 |
| B04 | `antipassback` | Prevención de Re-entrada | ❌ FALTANTE | T-223 |
| B05 | `visitors` | Gestión de Acceso de Visitantes | ❌ FALTANTE | T-224 |
| B06 | `emergency` | Acceso de Emergencia Física | ❌ FALTANTE | T-225 |
| B07 | `mustering` | Evacuación y Conteo | ❌ FALTANTE | T-226 |
| B08 | `business_zone` | Registro de Zona de Negocio (Acceso Físico) | árbol ✅ | — |
| B09 | `credentials` | Credencial Física Canónica (PIV/badge) | ❌ FALTANTE | T-228 |

---

## 2. Análisis de bloques

### B01 — `facilities` · Instalaciones Físicas

**Normas:** ISO 27001 A.7.1 · IEC 60839-11-5:2020 · NIST SP 800-116 R2

**Propósito:** Catálogo de instalaciones físicas controladas (edificios, pisos, salas, racks). Cada instalación tiene su nivel de seguridad, responsable, y lista de acceso autorizado. El PDP D02 consulta este catálogo para validar si un actor puede ingresar a una instalación específica.

**Tablas existentes:** Ninguna.

**Tabla propuesta:**
```sql
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_instalacion (
    instalacion_id  UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    code             TEXT NOT NULL,            -- Código único: EDIFICIO-A-PISO3-SALA-01
    nombre          JSONB NOT NULL,           -- {"es":"Sala de Servidores","en":"Server Room"}
    tipo            TEXT NOT NULL             -- EDIFICIO, PISO, SALA, RACK, PERIMETRO
        CONSTRAINT chk_iafi_tipo CHECK (tipo IN ('EDIFICIO','PISO','SALA','RACK','PERIMETRO','ZONA_CRITICA')),
    nivel_seguridad INTEGER NOT NULL DEFAULT 1   -- 1=bajo, 2=medio, 3=alto, 4=crítico
        CONSTRAINT chk_iafi_nivel CHECK (nivel_seguridad BETWEEN 1 AND 4),
    parent_id       UUID NULL REFERENCES bauth.idn_acceso_fisico_instalacion(instalacion_id),
    responsable_id  UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    requiere_dual   BOOLEAN NOT NULL DEFAULT FALSE,   -- B03
    requiere_mfa    BOOLEAN NOT NULL DEFAULT FALSE,
    capacidad       INTEGER NULL,             -- personas simultáneas máximas
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, codigo)
);
COMMENT ON TABLE bauth.idn_acceso_fisico_instalacion IS
  '[T-220] [D02-B01] [ISO 27001 A.7.1] [IEC 60839-11-5:2020]
   Catálogo jerárquico de instalaciones físicas con nivel de seguridad y responsable.';
```

### B02 — `readers` · Lectores OSDP

**Normas:** SIA OSDP v2.2.2 · IEC 60839-11-5 §6 · NIST SP 800-116 R2

**Propósito:** Registro de lectores de control de acceso físico (OSDP, RFID, biométrico). Cada lector se vincula a una instalación y registra eventos de acceso. bAuth integra con el PACS externo mediante webhook o polling; esta tabla sincroniza el estado.

**Tabla propuesta:**
```sql
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_lector (
    lector_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    instalacion_id  UUID NOT NULL REFERENCES bauth.idn_acceso_fisico_instalacion(instalacion_id),
    code             TEXT NOT NULL,
    tipo_protocolo  TEXT NOT NULL DEFAULT 'OSDP_V2'
        CONSTRAINT chk_iafl_proto CHECK (tipo_protocolo IN ('OSDP_V2','WIEGAND','RS485','BLE','NFC')),
    tipo_autenticador TEXT NOT NULL DEFAULT 'CARD'
        CONSTRAINT chk_iafl_auth CHECK (tipo_autenticador IN ('CARD','PIN','BIOMETRIC','DUAL','MOBILE')),
    direccion_ip    INET NULL,
    firmware_version TEXT NULL,
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_iafl_estado CHECK (estado IN ('ACTIVO','INACTIVO','FALLA','MANTENIMIENTO')),
    ultimo_heartbeat TIMESTAMPTZ NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, codigo)
);
COMMENT ON TABLE bauth.idn_acceso_fisico_lector IS
  '[T-221] [D02-B02] [SIA OSDP v2.2.2] [IEC 60839-11-5 §6]
   Catálogo de lectores de control de acceso físico con protocolo y estado.';
```

### B03 — `presence` · Presencia Dual / Exclusa de Seguridad

**Normas:** NIST SP 800-116 R2 §4.2 · IEC 60839-11-3 · ISO 27001 A.7.2

**Propósito:** Reglas de presencia dual (two-person integrity) y exclusa (mantrap). Una sala puede requerir que dos personas autorizadas estén presentes simultáneamente, o que se cierre la puerta exterior antes de abrir la interior.

**Tabla propuesta:**
```sql
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_presencia (
    regla_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    instalacion_id  UUID NOT NULL REFERENCES bauth.idn_acceso_fisico_instalacion(instalacion_id),
    tipo_regla      TEXT NOT NULL
        CONSTRAINT chk_iafp_tipo CHECK (tipo_regla IN ('TWO_PERSON_INTEGRITY','MANTRAP','MAX_OCCUPANCY')),
    minimo_personas INTEGER NULL DEFAULT 2,
    roles_requeridos TEXT[] NULL,   -- roles que pueden satisfacer la regla
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_acceso_fisico_presencia IS
  '[T-222] [D02-B03] [NIST SP 800-116 R2 §4.2] [IEC 60839-11-3]
   Reglas de presencia dual (two-person integrity) y exclusa de seguridad.';
```

### B04 — `antipassback` · Prevención de Re-entrada

**Normas:** IEC 60839-11-1 §6.4 · ISO 27001 A.7.2 · NIST SP 800-116 R2

**Propósito:** Registro de entradas/salidas para evitar que una credencial sea compartida (re-entrada). Un actor que no ha registrado salida no puede volver a entrar.

**Tabla propuesta:**
```sql
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_presencia_log (
    log_id          UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    instalacion_id  UUID NOT NULL REFERENCES bauth.idn_acceso_fisico_instalacion(instalacion_id),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    lector_id       UUID NULL REFERENCES bauth.idn_acceso_fisico_lector(lector_id),
    tipo_evento     TEXT NOT NULL CONSTRAINT chk_iafpl_tipo CHECK (tipo_evento IN ('ENTRADA','SALIDA','DENEGADO')),
    motivo_denegado TEXT NULL,
    evento_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
CREATE INDEX IF NOT EXISTS idx_iafpl_actor_inst ON bauth.idn_acceso_fisico_presencia_log(actor_id, instalacion_id, evento_at DESC);
COMMENT ON TABLE bauth.idn_acceso_fisico_presencia_log IS
  '[T-223] [D02-B04] [IEC 60839-11-1 §6.4] [ISO 27001 A.7.2]
   Registro de entradas/salidas para prevención de re-entrada y anti-tailgating.';
```

### B05 — `visitors` · Gestión de Acceso de Visitantes

**Normas:** ISO 27001 A.7.2 · NIST SP 800-116 R2 §5 · GDPR Art. 5(1)(c)

**Propósito:** Registro de visitas — quién visitó, a quién, cuándo, con escolta asignada. Los visitantes tienen credenciales temporales (VC vinculada a visita) y acceso restringido a instalaciones específicas.

**Tabla propuesta:**
```sql
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_visita (
    visita_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    nombre_visitante TEXT NOT NULL,
    doc_identidad   TEXT NOT NULL,    -- CI / pasaporte
    empresa         TEXT NULL,
    visitado_id     UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    escolta_id      UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    instalaciones_permitidas UUID[] NOT NULL DEFAULT '{}',
    estado          TEXT NOT NULL DEFAULT 'ESPERADO'
        CONSTRAINT chk_iafv_estado CHECK (estado IN ('ESPERADO','REGISTRADO','EN_SITIO','FINALIZADO','CANCELADO')),
    valid_from      TIMESTAMPTZ NOT NULL,
    valid_until     TIMESTAMPTZ NOT NULL,
    credencial_temp TEXT NULL,        -- código de tarjeta temporal
    motivo          TEXT NOT NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_acceso_fisico_visita IS
  '[T-224] [D02-B05] [ISO 27001 A.7.2] [NIST SP 800-116 R2 §5]
   Gestión de acceso de visitantes con escolta, credencial temporal y restricción por instalación.';
```

### B06 — `emergency` · Acceso de Emergencia Física

**Normas:** NIST SP 800-116 R2 §5.4 · ISO 27001 A.7.3 · NFPA 101:2021

**Propósito:** Activación de acceso de emergencia física (fail-safe/fail-secure). Registro de eventos de emergencia con motivo, actor que activó y duración. Todas las activaciones requieren aprobación post-hoc.

**Tabla propuesta:**
```sql
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_emergencia (
    emergencia_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    instalacion_id  UUID NOT NULL REFERENCES bauth.idn_acceso_fisico_instalacion(instalacion_id),
    tipo            TEXT NOT NULL CONSTRAINT chk_iafe_tipo CHECK (tipo IN ('INCENDIO','SISMO','EVACUACION','FALLA_SISTEMA','FUERZA_MAYOR')),
    activado_por    UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    activado_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    cerrado_at      TIMESTAMPTZ NULL,
    modo_falla      TEXT NOT NULL DEFAULT 'FAIL_SAFE' CONSTRAINT chk_iafe_modo CHECK (modo_falla IN ('FAIL_SAFE','FAIL_SECURE')),
    aprobado_post   BOOLEAN NOT NULL DEFAULT FALSE,
    aprobador_id    UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    notas           TEXT NULL,
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE bauth.idn_acceso_fisico_emergencia IS
  '[T-225] [D02-B06] [NIST SP 800-116 R2 §5.4] [ISO 27001 A.7.3]
   Registro de activaciones de acceso de emergencia física con aprobación post-hoc.';
```

### B07 — `mustering` · Evacuación y Conteo

**Normas:** ISO 27001 A.7.4 · NFPA 101:2021 §7.7 · ISO 3864

**Propósito:** Gestión de evacuaciones — punto de muster (reunión), conteo de personas presentes vs. esperadas, y confirmación de evacuación completa. Integra con el log de presencia (B04) para conocer quién estaba en el edificio.

**Tabla propuesta:**
```sql
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_evacuacion (
    evacuacion_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    tipo            TEXT NOT NULL CONSTRAINT chk_iafev_tipo CHECK (tipo IN ('SIMULACRO','REAL','PARCIAL')),
    iniciado_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    completado_at   TIMESTAMPTZ NULL,
    punto_reunion   TEXT NOT NULL,       -- descripción del punto de muster
    esperados       INTEGER NULL,        -- personas que deberían estar en el edificio
    contados        INTEGER NULL,        -- personas confirmadas en punto de reunión
    faltantes       TEXT[] NULL,         -- actor_ids de personas no localizadas
    estado          TEXT NOT NULL DEFAULT 'EN_PROGRESO'
        CONSTRAINT chk_iafev_estado CHECK (estado IN ('EN_PROGRESO','COMPLETADO','CANCELADO')),
    iniciado_por    UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE bauth.idn_acceso_fisico_evacuacion IS
  '[T-226] [D02-B07] [ISO 27001 A.7.4] [NFPA 101:2021 §7.7]
   Gestión de evacuaciones con punto de muster, conteo y confirmación.';
```

### B08 — `business_zone` · Registro de Zona de Negocio (Acceso Físico)

**Normas:** IEC 60839-11-5 · ISO 27001 A.7.1

**Propósito:** Nodo raíz del árbol de zonas de negocio para D02. En `idn_roles_template` ya existe como `skull.D02.business_zone` (depth=2, B08). Las zonas concretas de negocio se registran como hijos (depth=3) de este nodo.

**Tabla propuesta:** ✅ Se satisface con el árbol `idn_roles_template` existente + átomos. No requiere tabla adicional.

### B09 — `credentials` · Credencial Física Canónica (PIV/badge)

**Normas:** NIST SP 800-116 R2 §3 · ISO 27001 A.7.2 · FIPS 201-3 (PIV)

**Propósito:** Convergencia física-digital — vincula formalmente una credencial física (badge, tarjeta PIV, token RFID, credencial móvil) con su `entity_id` digital en bAuth. Sin esta tabla no existe cumplimiento de SP 800-116 R2 §3, que exige la vinculación trazable credencial-física ↔ identidad-digital. El campo `credencial_temp TEXT` en T-224 (visitantes) no reemplaza esta tabla — es un código temporal sin estructura ni trazabilidad.

**Hallazgo (v1.1.0):** Esta tabla fue omitida en el análisis original. Es P1 porque sin ella D02 no puede saber qué credencial física pertenece a qué identidad digital, invalidando todo el modelo de control de acceso físico integrado con IAM.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_acceso_fisico_credencial (
    credencial_id     UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id         UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    entity_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE CASCADE,
    tipo              TEXT NOT NULL
        CONSTRAINT chk_iafc_tipo CHECK (tipo IN ('BADGE','PIV','RFID','NFC','MOBILE','BIOMETRIC_TOKEN')),
    card_number       TEXT NOT NULL,
    protocolos        TEXT[] NOT NULL DEFAULT '{}',  -- OSDP_V2, WIEGAND, BLE, NFC
    instalaciones     UUID[] NULL,  -- NULL = acceso a todas; lista = solo estas instalaciones
    estado            TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_iafc_est CHECK (estado IN ('ACTIVO','SUSPENDIDO','REVOCADO','EXPIRADO')),
    emitido_por       UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    valid_from        TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until       TIMESTAMPTZ NULL,
    revocado_at       TIMESTAMPTZ NULL,
    motivo_revocacion TEXT NULL,
    ctx_id            TEXT NOT NULL DEFAULT 'system',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, card_number)
);
CREATE INDEX IF NOT EXISTS idx_iafc_entidad ON bauth.idn_acceso_fisico_credencial(entity_id, estado);
COMMENT ON TABLE bauth.idn_acceso_fisico_credencial IS
  '[T-228] [D02-B09] [NIST SP 800-116 R2 §3] [ISO 27001 A.7.2] [FIPS 201-3]
   Convergencia física-digital: vincula credencial física (badge/PIV/RFID) con identidad digital (entity_id).
   Reemplaza el campo credencial_temp TEXT de T-224 para casos de credenciales permanentes.';
```

---

## 3. DDL consolidado — T-220 a T-228

Ver §2 — cada bloque tiene su DDL. Orden de aplicación:
1. T-220 (`idn_acceso_fisico_instalacion`) — sin dependencias de D02
2. T-221 (`idn_acceso_fisico_lector`) — depende T-220
3. T-222 (`idn_acceso_fisico_presencia`) — depende T-220 · **independiente de T-223**
4. T-223 (`idn_acceso_fisico_presencia_log`) — depende T-220, T-221 · **independiente de T-222**
5. T-224 (`idn_acceso_fisico_visita`) — depende T-220
6. T-225 (`idn_acceso_fisico_emergencia`) — depende T-220
7. T-226 (`idn_acceso_fisico_evacuacion`) — sin dependencias D02 extras
8. T-228 (`idn_acceso_fisico_credencial`) — depende T-220 (instalaciones[]) · FK a `idn_identity_entity`
9. B08 — árbol `idn_roles_template` (átomos, sin tabla nueva)

> **Nota corrección v1.1.0:** T-222 (presencia dual) y T-223 (anti-passback log) son independientes entre sí. El orden anterior los vinculaba incorrectamente. T-228 es nueva (credencial física — omitida en v1.0.0).

> **Nota de diseño — anti-passback (T-223):** T-223 es un log de eventos (QUÉ PASÓ). El enforcement real de anti-passback requiere conocer el **estado actual** de presencia (DENTRO/FUERA) por actor+instalación. Dos opciones válidas: (a) vista materializada sobre T-223 con el último evento por par, o (b) tabla de estado separada `idn_acceso_fisico_estado_presencia`. La decisión arquitectónica queda pendiente de análisis de performance en VPS.

---

## 4. Checklist de completitud

### 4.1 DDL (tablas)

- [ ] `idn_acceso_fisico_instalacion` (T-220) — B01 ❌ PENDIENTE
- [ ] `idn_acceso_fisico_lector` (T-221) — B02 ❌ PENDIENTE
- [ ] `idn_acceso_fisico_presencia` (T-222) — B03 ❌ PENDIENTE (two-person integrity / mantrap)
- [ ] `idn_acceso_fisico_presencia_log` (T-223) — B04 ❌ PENDIENTE (log anti-passback)
- [ ] `idn_acceso_fisico_visita` (T-224) — B05 ❌ PENDIENTE
- [ ] `idn_acceso_fisico_emergencia` (T-225) — B06 ❌ PENDIENTE
- [ ] `idn_acceso_fisico_evacuacion` (T-226) — B07 ❌ PENDIENTE
- [ ] `idn_acceso_fisico_credencial` (T-228) — B09 ❌ PENDIENTE · **agregada v1.1.0** (convergencia física-digital)

### 4.2 Triggers

- [ ] Trigger: al registrar ENTRADA en log de presencia, verificar anti-passback
- [ ] Trigger: al iniciar evacuación, calcular `esperados` desde log de presencia activa

### 4.3 Jobs

- [ ] Job: marcar visitas vencidas (`valid_until < now()` y estado `EN_SITIO` → `FINALIZADO`)
- [ ] Job: heartbeat check para lectores (`ultimo_heartbeat > 5 min` → estado `FALLA`)

### 4.4 Átomos (árbol de políticas)

Todos ⏸ SUSPENDIDO — creación exclusiva vía interfaz AtomLang / compilador `atomc`. PROHIBIDO INSERT manual.

- [ ] `skull.D02.facilities.*` — verbos: `register`, `configure`, `read`, `deactivate`
- [ ] `skull.D02.readers.*` — verbos: `register`, `configure`, `read`, `deactivate`
- [ ] `skull.D02.presence.*` — verbos: `create`, `configure`, `read` · `condition_expr`: AAL2 mínimo
- [ ] `skull.D02.antipassback.*` — verbos: `read`, `override` · `condition_expr`: `override` requiere AAL3
- [ ] `skull.D02.visitors.*` — verbos: `register`, `approve`, `extend`, `cancel`, `read`
- [ ] `skull.D02.emergency.*` — verbos: `activate`, `close`, `approve_post` · `condition_expr`: AAL3 + dual
- [ ] `skull.D02.mustering.*` — verbos: `launch`, `confirm`, `close`, `read`
- [ ] `skull.D02.credentials.*` — verbos: `issue`, `read`, `suspend`, `revoke` · **agregado v1.1.0**
- [ ] `skull.D02.business_zone.*` — verbos: `register`, `read`

---

## 5. Análisis IAM Enterprise — D02

### 5.1 Cobertura de pilares

D02 cubre **Pilar III — PAM** (en su variante física: acceso privilegiado a instalaciones) y **Pilar VI — Standards** (IEC 60839, NIST SP 800-116):

| Pilar IAM Enterprise | Criterio D02 | Estado |
|---|---|:---:|
| **I AuthEngine** | Integración PDP → control acceso físico | ❌ L0 |
| **III PAM** | Inventario de instalaciones críticas | ❌ L0 |
| **III PAM** | Two-person integrity (sala crítica) | ❌ L0 |
| **V Directory** | Directorio de visitantes | ❌ L0 |
| **VI Standards** | OSDP v2.2.2 / IEC 60839-11 | ❌ L0 |
| **VII Advanced** | Evacuación integrada con presencia digital | ❌ L0 |

### 5.2 Gaps IAM Enterprise D02

| Gap | Prioridad | Acción | Estado |
|-----|-----------|--------|--------|
| GAP-D02-01 — Catálogo de instalaciones | 🔴 P1 | CREATE T-220 `idn_acceso_fisico_instalacion` | ❌ PENDIENTE |
| GAP-D02-02 — Lectores OSDP sin inventario | 🔴 P1 | CREATE T-221 `idn_acceso_fisico_lector` | ❌ PENDIENTE |
| GAP-D02-03 — Reglas presencia dual sin tabla | 🟠 P2 | CREATE T-222 `idn_acceso_fisico_presencia` (two-person integrity / mantrap) · **omitido en v1.0.0** | ❌ PENDIENTE |
| GAP-D02-04 — Sin anti-passback (log) | 🟠 P2 | CREATE T-223 `idn_acceso_fisico_presencia_log` | ❌ PENDIENTE |
| GAP-D02-05 — Anti-passback: log sin estado actual | 🟠 P2 | Decisión pendiente: vista materializada vs tabla de estado sobre T-223 para enforcement en tiempo real | ❌ PENDIENTE DECISIÓN |
| GAP-D02-06 — Sin gestión de visitantes | 🟠 P2 | CREATE T-224 `idn_acceso_fisico_visita` | ❌ PENDIENTE |
| GAP-D02-07 — Emergencia física sin trazabilidad | 🟠 P2 | CREATE T-225 `idn_acceso_fisico_emergencia` | ❌ PENDIENTE |
| GAP-D02-08 — Evacuación sin integración digital | 🟡 P3 | CREATE T-226 `idn_acceso_fisico_evacuacion` | ❌ PENDIENTE |
| GAP-D02-09 — Sin credencial física canónica | 🔴 P1 | CREATE T-228 `idn_acceso_fisico_credencial` · convergencia física-digital · **agregado v1.1.0** | ❌ PENDIENTE |
| GAP-D02-10 — Eventos físicos no llegan a D11 | 🟠 P2 | Definir puente D02 → D11 auditoría: los eventos de acceso físico deben integrarse con `privilege_atom_audit` (D11) para cumplimiento ISO 27001 A.7.4 + NIST AU-2 · **agregado v1.1.0** | ❌ PENDIENTE DECISIÓN |
| GAP-D02-11 — Átomos D02 en árbol | 🟠 P2 | ~35 átomos via interfaz AtomLang (catálogo en §4.4) | ⏸ SUSPENDIDO — vía árbol |

### 5.3 Veredicto IAM Enterprise

**D02: L0 global** — dominio no implementado. La arquitectura propuesta es sólida y ninguna tabla viola D-07 (son catálogos de hardware, logs de eventos y configuración física — no autorización digital). Los gaps críticos son T-220 (instalaciones) + T-221 (lectores) + T-228 (credencial física) como fundamento mínimo, más la decisión de diseño sobre estado de anti-passback (GAP-D02-05) y el puente a D11 (GAP-D02-10).

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.1.0 | 2026-07-30 | Revisión IAM Enterprise. Hallazgos: (1) T-228 `idn_acceso_fisico_credencial` omitida — nueva B09 para convergencia física-digital NIST SP 800-116 R2 §3, ahora P1. (2) T-222 `idn_acceso_fisico_presencia` existía en §4.1 pero no tenía gap propio en §5.2 — corregido como GAP-D02-03. (3) Anti-passback T-223 es log puro, sin estado actual de presencia — gap de diseño documentado (GAP-D02-05). (4) Sin puente D02 → D11 auditoría — GAP-D02-10. (5) Orden de aplicación §3 corregido: T-222 y T-223 son independientes entre sí. Átomos §4.4 expandidos con verbos y `condition_expr` notable por bloque. Gaps: 7 → 11. |
| 1.0.0 | 2026-07-28 | Versión inicial. 8/8 bloques sin implementación. DDL propuesto T-220..T-226. 7 gaps IAM Enterprise. Madurez D02: L0. |
