# A.65.03.01.07 — Informe de Completitud: D06 Acceso Geoespacial

**Versión:** 1.0.0 · **Fecha:** 2026-07-28
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D06.*`)
**Estado de D06:** ❌ SIN IMPLEMENTAR — 0/6 bloques con tablas propias · 5 tablas propuestas (T-300..T-304)

> **T-code range:** T-300..T-319 (prefijo `idn_geoespacial_*`)

---

## 1. Estado global de D06

**Dominio:** Acceso Geoespacial (geocercas, soberanía de datos, viaje imposible)
**Total bloques:** 6 | **Tablas propias:** 0 | **Átomos:** 0

| Bloque | Slug | Nombre | Estado | T-code propuesto |
|--------|------|--------|--------|-----------------|
| B01 | `geofencing` | Geocercas | ❌ FALTANTE | T-300 |
| B02 | `location` | Validación de Ubicación | ❌ FALTANTE | T-301 |
| B03 | `velocity` | Detección de Viaje Imposible | ❌ FALTANTE | T-302 |
| B04 | `residency` | Soberanía de Datos y Residencia | ❌ FALTANTE | T-303 |
| B05 | `fleet` | Acceso Basado en Flota | ❌ FALTANTE | T-304 |
| B06 | `business_zone` | Registro de Zona de Negocio (Geoespacial) | árbol ✅ | — |

---

## 2. Análisis de bloques

### B01 — `geofencing` · Geocercas

**Normas:** RFC 7946 GeoJSON §3.1 · OGC GeoSPARQL 1.1 · ISO 6709:2022

**Propósito:** Define geocercas (zonas geográficas) dentro de las cuales un actor puede o no puede acceder. El PDP consulta si la ubicación del request está dentro de la geocerca antes de autorizar.

> **Nota:** PostgreSQL 18 soporta tipos geométricos via `PostGIS` — la extensión debe estar activa en SBOSDB.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_geocerca (
    geocerca_id     UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    nombre          JSONB NOT NULL,          -- {"es":"Zona Andina Bolivia","en":"Andean Zone Bolivia"}
    tipo            TEXT NOT NULL DEFAULT 'CIRCULO'
        CONSTRAINT chk_idgg_tipo CHECK (tipo IN ('CIRCULO','POLIGONO','BBOX','PAIS','REGION')),
    -- Para CIRCULO: centro + radio
    centro_lat      NUMERIC(10,7) NULL,
    centro_lon      NUMERIC(10,7) NULL,
    radio_metros    INTEGER NULL,
    -- Para POLIGONO/BBOX: GeoJSON
    geojson         JSONB NULL,
    -- Para PAIS/REGION: código ISO
    pais_code        TEXT NULL,               -- ISO 3166-1 alpha-2
    region_codigo   TEXT NULL,               -- ISO 3166-2
    efecto          TEXT NOT NULL DEFAULT 'PERMITIR'
        CONSTRAINT chk_idgg_efecto CHECK (efecto IN ('PERMITIR','DENEGAR')),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE bauth.idn_geoespacial_geocerca IS
  '[T-300] [D06-B01] [RFC 7946 GeoJSON §3.1] [OGC GeoSPARQL 1.1]
   Geocercas geográficas para restricción o habilitación de acceso según ubicación.';
```

### B02 — `location` · Validación de Ubicación

**Normas:** RFC 7946 §3 · NIST SP 800-53 R5 AC-3(11)

**Propósito:** Log de validaciones de ubicación en tiempo real. Cuando un request incluye coordenadas GPS o IP-geolocation, el PDP evalúa si está dentro de las geocercas del actor y registra el resultado.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_ubicacion_log (
    log_id          UUID PRIMARY KEY DEFAULT uuidv7(),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    lat             NUMERIC(10,7) NULL,
    lon             NUMERIC(10,7) NULL,
    precision_m     INTEGER NULL,            -- precisión GPS en metros
    fuente          TEXT NOT NULL DEFAULT 'GPS'
        CONSTRAINT chk_idgul_fuente CHECK (fuente IN ('GPS','IP_GEOLOCALIZACION','WIFI','BLE_BEACON','DECLARADA')),
    ip_origen       INET NULL,
    pais_detectado  TEXT NULL,               -- ISO 3166-1
    geocercas_match UUID[] NULL,             -- geocerca_ids que aplican
    resultado_pdp   TEXT NOT NULL CONSTRAINT chk_idgul_res CHECK (resultado_pdp IN ('PERMITIDO','DENEGADO','STEP_UP')),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    evaluado_at     TIMESTAMPTZ NOT NULL DEFAULT now()
) PARTITION BY RANGE (evaluado_at);
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_ubicacion_log_2026
    PARTITION OF bauth.idn_geoespacial_ubicacion_log
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
COMMENT ON TABLE bauth.idn_geoespacial_ubicacion_log IS
  '[T-301] [D06-B02] [RFC 7946 §3] [NIST SP 800-53 R5 AC-3(11)]
   Log de validaciones geoespaciales en tiempo real con resultado del PDP.';
```

### B03 — `velocity` · Detección de Viaje Imposible

**Normas:** NIST SP 800-53 R5 SI-4(13) · ISO 27001 A.8.16

**Propósito:** Si un actor inicia sesión desde Madrid y 5 minutos después desde La Paz, el motor de velocidad detecta la imposibilidad física y dispara una alerta o bloqueo. Compara las últimas ubicaciones con la velocidad máxima de viaje físicamente posible.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_velocidad_policy (
    policy_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    velocidad_max_kmh NUMERIC(8,2) NOT NULL DEFAULT 900.0,  -- 900 km/h = avión comercial
    ventana_analisis INTERVAL NOT NULL DEFAULT '1 hour',
    accion          TEXT NOT NULL DEFAULT 'STEP_UP'
        CONSTRAINT chk_idgvp_acc CHECK (accion IN ('STEP_UP','BLOQUEO_TEMP','ALERTA_SIEM','CAEP_EVENT')),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    UNIQUE (tenant_id)
);
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_velocidad_evento (
    evento_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    ubicacion_anterior_id UUID NULL,
    ubicacion_actual_id   UUID NULL,
    distancia_km    NUMERIC(10,2) NULL,
    tiempo_min      NUMERIC(10,2) NULL,
    velocidad_kmh   NUMERIC(10,2) NULL,
    umbral_kmh      NUMERIC(10,2) NOT NULL,
    accion_tomada   TEXT NULL,
    detectado_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    ctx_id          TEXT NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE bauth.idn_geoespacial_velocidad_policy IS
  '[T-302] [D06-B03] [NIST SP 800-53 R5 SI-4(13)] [ISO 27001 A.8.16]
   Política de detección de viaje imposible con umbral de velocidad física.';
```

### B04 — `residency` · Soberanía de Datos y Residencia

**Normas:** GDPR Art. 44-49 · ISO 3166-1 · Ley 1174 Bolivia · Ley 164 Bolivia

**Propósito:** Define en qué países pueden residir los datos del tenant. El PDP rechaza requests desde jurisdicciones no autorizadas para datos de cierta clasificación. Implementa data residency para cumplimiento GDPR y Ley 1174.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_residencia (
    residencia_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    clasificacion   TEXT NOT NULL CONSTRAINT chk_idgr_clas CHECK (clasificacion IN
        ('PUBLIC','INTERNAL','CONFIDENTIAL','PII','SENSITIVE_PII')),
    paises_permitidos TEXT[] NOT NULL,       -- ISO 3166-1 alpha-2
    paises_prohibidos TEXT[] NOT NULL DEFAULT '{}',
    marco_legal     TEXT NOT NULL,           -- GDPR, LEY_164_BO, HIPAA, etc.
    accion_violacion TEXT NOT NULL DEFAULT 'DENEGAR'
        CONSTRAINT chk_idgr_acc CHECK (accion_violacion IN ('DENEGAR','REGISTRAR','STEP_UP')),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, clasificacion)
);
COMMENT ON TABLE bauth.idn_geoespacial_residencia IS
  '[T-303] [D06-B04] [GDPR Art. 44-49] [Ley 1174 Bolivia]
   Políticas de soberanía de datos: en qué países pueden residir datos por clasificación.';
```

### B05 — `fleet` · Acceso Basado en Flota

**Normas:** ISO 6709:2022 · NIST SP 800-53 R5 AC-3(11)

**Propósito:** Registro de dispositivos móviles corporativos con ubicación conocida (flota). El PDP puede autorizar acceso solo desde dispositivos registrados en la flota corporativa dentro de las geocercas.

```sql
CREATE TABLE IF NOT EXISTS bauth.idn_geoespacial_dispositivo_flota (
    dispositivo_id  UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id),
    actor_id        UUID NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    device_fingerprint TEXT NOT NULL,        -- hash del fingerprint del dispositivo
    nombre          TEXT NULL,
    modelo          TEXT NULL,
    ultima_lat      NUMERIC(10,7) NULL,
    ultima_lon      NUMERIC(10,7) NULL,
    ultima_ubicacion_at TIMESTAMPTZ NULL,
    confianza       TEXT NOT NULL DEFAULT 'CORPORATIVO'
        CONSTRAINT chk_idgdf_conf CHECK (confianza IN ('CORPORATIVO','BYOD_REGISTRADO','BYOD_NO_REGISTRADO')),
    estado          TEXT NOT NULL DEFAULT 'ACTIVO'
        CONSTRAINT chk_idgdf_est CHECK (estado IN ('ACTIVO','SUSPENDIDO','REVOCADO')),
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, device_fingerprint)
);
COMMENT ON TABLE bauth.idn_geoespacial_dispositivo_flota IS
  '[T-304] [D06-B05] [ISO 6709:2022] [NIST SP 800-53 R5 AC-3(11)]
   Registro de dispositivos de flota corporativa con ubicación y nivel de confianza.';
```

---

## 3. Checklist de completitud

- [ ] `idn_geoespacial_geocerca` (T-300) ❌ PENDIENTE
- [ ] `idn_geoespacial_ubicacion_log` (T-301) particionada ❌ PENDIENTE
- [ ] `idn_geoespacial_velocidad_policy` + evento (T-302) ❌ PENDIENTE
- [ ] `idn_geoespacial_residencia` (T-303) ❌ PENDIENTE
- [ ] `idn_geoespacial_dispositivo_flota` (T-304) ❌ PENDIENTE
- [ ] Seeds: geocercas Bolivia por defecto + política residencia Bolivia
- [ ] Seeds: política de velocidad por defecto (900 km/h)
- [ ] Job: limpiar logs de ubicación > 90 días (GDPR minimización)
- [ ] Átomos D06 en árbol: `skull.D06.{geofencing,location,velocity,residency,fleet}.*`

---

## 4. Análisis IAM Enterprise — D06

| Pilar IAM Enterprise | Criterio D06 | Estado |
|---|---|:---:|
| **I AuthEngine** | Geofencing en PDP (context-aware) | ❌ L0 |
| **I AuthEngine** | Viaje imposible → CAEP event | ❌ L0 |
| **VI Standards** | GDPR Art. 44-49 data residency | ❌ L0 |
| **VI Standards** | Ley 1174 soberanía de datos Bolivia | ❌ L0 |
| **VII Advanced** | ZTA context-based location | ❌ L0 |

**Gaps:**

| Gap | Prioridad | Acción |
|-----|-----------|--------|
| GAP-D06-01 — Geocercas sin datos | 🔴 P1 | CREATE T-300 + seeds Bolivia |
| GAP-D06-02 — Viaje imposible sin detector | 🟠 P2 | CREATE T-302 |
| GAP-D06-03 — Soberanía de datos sin política | 🟠 P2 | CREATE T-303 |
| GAP-D06-04 — Flota sin inventario | 🟡 P3 | CREATE T-304 |
| GAP-D06-05 — Átomos D06 | 🟡 P3 | INSERT ~20 átomos |

**Veredicto: D06 L0 global** — sin implementación. T-300 + T-303 son críticos para soberanía de datos SBOS.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-28 | Versión inicial. 5/6 bloques sin implementación. DDL propuesto T-300..T-304. 5 gaps IAM Enterprise. Madurez D06: L0. |
