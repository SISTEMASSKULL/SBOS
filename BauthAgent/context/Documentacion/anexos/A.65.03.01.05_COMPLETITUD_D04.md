# A.65.03.01.05 — Informe de Completitud: D04 Acceso Temporal

**Versión:** 1.0.0 · **Fecha:** 2026-07-28
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D04.*`)
**Estado de D04:** ❌ SIN IMPLEMENTAR — 0/6 bloques con tablas propias · 5 tablas propuestas (T-260..T-264)

> **T-code range:** T-260..T-279 (prefijo `idn_temporal_*`)

---

## 1. Estado global de D04

**Dominio:** Acceso Temporal (TRBAC — Time-based Role-Based Access Control)
**Total bloques:** 6 | **Tablas propias:** 0 | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | T-code propuesto |
|--------|------|--------|--------|-----------------|
| B01 | `windows` | Ventanas de Tiempo | ❌ FALTANTE | T-260 |
| B02 | `periods` | Períodos de Asignación | ❌ FALTANTE | T-261 |
| B03 | `calendar` | Calendario y Feriados | ❌ FALTANTE | T-262 |
| B04 | `schedules` | Rotación de Turnos | ❌ FALTANTE | T-263 |
| B05 | `exceptions` | Excepciones de Horario | ❌ FALTANTE | T-264 |
| B06 | `business_zone` | Registro de Zona de Negocio (Temporal) | árbol ✅ | — |

---

## 2. Análisis de bloques

### B01 — `windows` · Ventanas de Tiempo

**Normas:** GTRBAC §3.2 · NIST SP 800-53 R5 AC-3(7) · PostgreSQL 18 PERIOD

**Propósito:** Define ventanas de tiempo recurrentes durante las cuales un grant es válido. Ej.: "acceso al módulo de producción solo de lunes a viernes de 08:00 a 18:00". Diferente de `valid_from/valid_until` en `privilege_atom_grant` (rangos absolutos) — las ventanas son recurrentes.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_ventana (
    ventana_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    nombre          JSONB NOT NULL,          -- {"es":"Horario laboral estándar","en":"Standard work hours"}
    tipo            TEXT NOT NULL DEFAULT 'SEMANAL'
        CONSTRAINT chk_idtv_tipo CHECK (tipo IN ('DIARIO','SEMANAL','MENSUAL','ANUAL','PERSONALIZADO')),
    -- Días de semana válidos (1=Lun, 7=Dom) — NULL = todos los días
    dias_semana     INTEGER[] NULL,
    -- Hora inicio y fin (UTC) — '08:00', '18:00'
    hora_inicio     TIME WITHOUT TIME ZONE NULL,
    hora_fin        TIME WITHOUT TIME ZONE NULL,
    -- Zona horaria del tenant
    zona_horaria    TEXT NOT NULL DEFAULT 'America/La_Paz',
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_temporal_ventana IS
  '[T-260] [D04-B01] [GTRBAC §3.2] [NIST SP 800-53 R5 AC-3(7)]
   Ventanas de tiempo recurrentes para grants temporales. El PDP evalúa si "ahora" cae en la ventana.';
```

### B02 — `periods` · Períodos de Asignación

**Normas:** GTRBAC §4 · PostgreSQL 18 PERIOD · ISO 8601:2019

**Propósito:** Asignación temporal de un rol o átomo a un actor por un período específico. Diferente de `privilege_atom_grant.valid_from/until` (que es parte del grant general) — este es un período de activación temporal que puede sobrescribir o restringir al grant base.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_periodo (
    periodo_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    grant_id        UUID NULL REFERENCES bauth.privilege_atom_grant(id),
    ventana_id      UUID NULL REFERENCES bauth.idn_temporal_ventana(ventana_id),
    tipo            TEXT NOT NULL DEFAULT 'ACTIVACION'
        CONSTRAINT chk_idtp_tipo CHECK (tipo IN ('ACTIVACION','RESTRICCION','SUSPENSION')),
    valid_from      TIMESTAMPTZ NOT NULL,
    valid_until     TIMESTAMPTZ NOT NULL,
    razon           TEXT NOT NULL,
    aprobado_por    UUID NULL REFERENCES bauth.idn_identity_entity(entity_id),
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idtp_estado CHECK (estado IN ('ACTIVO','EXPIRADO','CANCELADO')),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_idtp_rango CHECK (valid_until > valid_from)
);
COMMENT ON TABLE bauth.idn_temporal_periodo IS
  '[T-261] [D04-B02] [GTRBAC §4] [PostgreSQL 18 PERIOD]
   Períodos de asignación temporal que activan, restringen o suspenden grants.';
```

### B03 — `calendar` · Calendario y Feriados

**Normas:** RFC 5545 iCalendar §3 · ISO 8601:2019

**Propósito:** Catálogo de feriados y días especiales. El evaluador GTRBAC consulta este catálogo para determinar si un día específico es hábil o feriado, lo que puede bloquear o habilitar accesos temporales según la configuración de la ventana.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_calendario (
    entrada_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    pais            TEXT NOT NULL DEFAULT 'BO',       -- ISO 3166-1 alpha-2
    fecha           DATE NOT NULL,
    nombre          JSONB NOT NULL,                   -- {"es":"Día de la Independencia"}
    tipo            TEXT NOT NULL DEFAULT 'FERIADO_NACIONAL'
        CONSTRAINT chk_idtca_tipo CHECK (tipo IN
            ('FERIADO_NACIONAL','FERIADO_REGIONAL','DIA_LIBRE','MANTENIMIENTO','ESPECIAL')),
    -- Efecto en accesos temporales
    bloquea_acceso  BOOLEAN NOT NULL DEFAULT FALSE,   -- si true, ventanas de tiempo son ignoradas
    UNIQUE (tenant_id, pais, fecha)
);
COMMENT ON TABLE bauth.idn_temporal_calendario IS
  '[T-262] [D04-B03] [RFC 5545 iCalendar §3] [ISO 8601:2019]
   Catálogo de feriados y días especiales por país/tenant para evaluación GTRBAC.';
```

### B04 — `schedules` · Rotación de Turnos

**Normas:** NIST SP 800-53 R5 AC-2(2) · GTRBAC §5

**Propósito:** Define esquemas de rotación de turnos (mañana/tarde/noche) y los vincula a ventanas de tiempo. Un actor asignado al "turno de noche" hereda automáticamente la ventana de acceso nocturna.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_turno (
    turno_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    nombre          JSONB NOT NULL,                   -- {"es":"Turno Noche","en":"Night Shift"}
    ventana_id      UUID NOT NULL REFERENCES bauth.idn_temporal_ventana(ventana_id),
    duracion_dias   INTEGER NOT NULL DEFAULT 7,       -- duración del ciclo de rotación
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_turno_asignacion (
    asignacion_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    turno_id        UUID NOT NULL REFERENCES bauth.idn_temporal_turno(turno_id),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    valid_from      DATE NOT NULL,
    valid_until     DATE NULL,                        -- NULL = indefinido
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (turno_id, actor_id, valid_from)
);
COMMENT ON TABLE bauth.idn_temporal_turno IS
  '[T-263] [D04-B04] [NIST SP 800-53 R5 AC-2(2)] [GTRBAC §5]
   Esquemas de rotación de turnos vinculados a ventanas de tiempo.';
```

### B05 — `exceptions` · Excepciones de Horario

**Normas:** NIST SP 800-53 R5 AC-17(1) · ISO 27001 A.5.18

**Propósito:** Excepciones aprobadas a las restricciones de horario (ej.: un actor puede acceder fuera de su ventana habitual por una razón justificada). Requieren aprobación y tienen validez limitada.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_temporal_excepcion (
    excepcion_id    UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    ventana_exenta  UUID NULL REFERENCES bauth.idn_temporal_ventana(ventana_id),
    razon           TEXT NOT NULL,
    aprobado_por    UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    aprobado_at     TIMESTAMPTZ NOT NULL,
    valid_from      TIMESTAMPTZ NOT NULL,
    valid_until     TIMESTAMPTZ NOT NULL,
    estado          TEXT NOT NULL DEFAULT 'ACTIVA'
        CONSTRAINT chk_idle_estado CHECK (estado IN ('ACTIVA','EXPIRADA','CANCELADA')),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_idle_rango CHECK (valid_until > valid_from)
);
COMMENT ON TABLE bauth.idn_temporal_excepcion IS
  '[T-264] [D04-B05] [NIST SP 800-53 R5 AC-17(1)] [ISO 27001 A.5.18]
   Excepciones aprobadas a restricciones de horario — acceso fuera de ventana justificado.';
```

### B06 — `business_zone` · (árbol) ✅

Nodo `skull.D04.business_zone` ya existe en `idn_roles_template` (B06, depth=2). Sin tabla adicional.

---

## 3. Checklist de completitud

- [ ] `idn_temporal_ventana` (T-260) ❌ PENDIENTE
- [ ] `idn_temporal_periodo` (T-261) ❌ PENDIENTE
- [ ] `idn_temporal_calendario` (T-262) ❌ PENDIENTE
- [ ] `idn_temporal_turno` + `idn_temporal_turno_asignacion` (T-263) ❌ PENDIENTE
- [ ] `idn_temporal_excepcion` (T-264) ❌ PENDIENTE
- [ ] Trigger: expirar períodos (T-261) y excepciones (T-264) cuyo `valid_until < now()`
- [ ] Job: revisar turnos — al cambiar de día laboral, actualizar ventanas activas
- [ ] Seeds: feriados nacionales Bolivia 2026-2027 en `idn_temporal_calendario`
- [ ] Átomos D04 en árbol: `skull.D04.{windows,periods,calendar,schedules,exceptions}.*`

---

## 4. Análisis IAM Enterprise — D04

| Pilar IAM Enterprise | Criterio D04 | Estado |
|---|---|:---:|
| **I AuthEngine** | GTRBAC / TRBAC en PDP | ❌ L0 |
| **I AuthEngine** | Evaluación de ventana temporal en runtime | ❌ L0 |
| **II IGA** | Turnos y rotación con gobernanza | ❌ L0 |
| **VI Standards** | GTRBAC §3-5 / ISO 8601 / RFC 5545 | ❌ L0 |

**Gaps IAM Enterprise D04:**

| Gap | Prioridad | Acción |
|-----|-----------|--------|
| GAP-D04-01 — Motor GTRBAC sin tablas | 🔴 P1 | CREATE T-260 + T-261 |
| GAP-D04-02 — Calendario feriados sin datos | 🟠 P2 | CREATE T-262 + seeds Bolivia |
| GAP-D04-03 — Rotación de turnos | 🟠 P2 | CREATE T-263 |
| GAP-D04-04 — Excepciones de horario | 🟡 P3 | CREATE T-264 |
| GAP-D04-05 — Átomos D04 | 🟡 P3 | INSERT ~20 átomos |

**Veredicto: D04 L0 global** — sin implementación. T-260 y T-261 son bloqueantes para GTRBAC.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-28 | Versión inicial. 5/6 bloques sin implementación. DDL propuesto T-260..T-264. 5 gaps IAM Enterprise. Madurez D04: L0. |
