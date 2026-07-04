# BAUTH-DDL-DOMINIO-FISICO.md — Dominio Físico (D2)

**Versión:** 1.0 · **Fecha:** 2026-06-23 · **Autor:** sbos-coordinador
**Schema:** `bauth` (prefijo `fis_`) · **Dominio bAuth:** D2 — Físico
**Tablas heredadas:** `bos_sitio_fisico`, `bos_edificio`, `bos_piso`, `bos_area_fisica`, `bos_dispositivo_fisico`
**DDL destino:** `DDL_skSBOS_db.sql`
**Referencias:** `BAUTH-CALENDAR-SUBSYSTEM.md` · `BAUTH-AUDIT-CHANNELS-CONFIG.md` · `PLAN-RECONSTRUCCION-DDL.md`

---

## 1. VISIÓN DEL DOMINIO

El Dominio Físico (D2) del SBOS controla **todo lo que ocurre en el mundo real**: quién entra a qué
edificio, por qué puerta, en qué horario, con qué credencial, y qué dispositivos (cámaras, sensores,
chapas, lectores) ejecutan las decisiones de acceso.

**No es un sistema de control de acceso tradicional — es el brazo físico del motor de identidad.**
bauth decide QUIÉN puede acceder a QUÉ, CUÁNDO y CÓMO. NEXUS (bhnexus/banexus) ejecuta la decisión
sobre el hardware físico.

```
┌──────────────────────────────────────────────────────────────────┐
│                    DOMINIO FÍSICO — D2                           │
│                                                                  │
│  bauth (identidad)          NEXUS (ejecución)                    │
│  ┌────────────────┐        ┌────────────────────┐               │
│  │ ¿Quién?        │───────▶│ OSDP → Chapa       │               │
│  │ idn_usuario    │        │ ONVIF → Cámara     │               │
│  │ ¿Qué acceso?   │        │ MQTT → Sensor      │               │
│  │ BitMask D2     │        │ Modbus → Actuador  │               │
│  │ ¿Cuándo?       │        │ Wiegand → Lector   │               │
│  │ cal_schedule   │        │ dry contact → REX  │               │
│  │ ¿Dónde?        │        └────────────────────┘               │
│  │ geo_* jerarquía│                                              │
│  └────────────────┘                                              │
│                                                                  │
│  JERARQUÍA FÍSICA ESTÁNDAR INTERNACIONAL (PACS)                  │
│  Site → Building → Floor → Area → Door → Reader/Device          │
└──────────────────────────────────────────────────────────────────┘
```

### 1.1 — Principios del dominio físico SBOS

| # | Principio | Fundamento |
|---|-----------|------------|
| P1 | **bauth decide, NEXUS ejecuta** | Separación de responsabilidades: la lógica de acceso está en bauth, el hardware en NEXUS. Como un PDP/PEP físico |
| P2 | **Jerarquía heredable** | Un permiso sobre un Sitio se hereda a todos sus Edificios, Pisos, Áreas y Puertas. Igual que la herencia tenant→empresa→sucursal |
| P3 | **Zonas de seguridad BS 5979** | Zone 0 (pública) a Zone 5 (máxima). La zona define el nivel de autenticación requerido |
| P4 | **Todo dispositivo tiene protocolo** | OSDP para puertas/lectores, ONVIF para cámaras, MQTT para sensores, Modbus/BACnet para actuadores industriales |
| P5 | **ctx_id en cada evento físico** | Una puerta forzada genera un audit_event con ctx_id. Trazabilidad completa mundo físico→mundo digital |
| P6 | **Anti-tailgating, mantrap, escolta** | Reglas de acceso físico avanzadas: dos personas para bóveda, escolta para visitantes, mantrap para data center |

---

## 2. ESTÁNDARES INTERNACIONALES APLICADOS

### 2.1 — Control de Acceso Físico

| Estándar | Título | Aplicación en SBOS |
|----------|--------|-------------------|
| **IEC 60839-11-5** | OSDP v2.2.2 (Open Supervised Device Protocol) | Protocolo principal para lectores, chapas, controladores. Reemplaza Wiegand |
| **IEC 60839-11-1** | Electronic Access Control Systems — System and Components Requirements | Requisitos generales del sistema |
| **ISO 16484-5** | BACnet — Building Automation and Control Systems | Actuadores industriales, HVAC, iluminación |
| **ONVIF Profile S/G/T** | Open Network Video Interface Forum | Cámaras CCTV, grabación, analítica de video |
| **ISO 14443** | Contactless Smart Cards (RFID/NFC) | Tarjetas de proximidad para acceso físico |

### 2.2 — Seguridad Física

| Estándar | Título | Aplicación en SBOS |
|----------|--------|-------------------|
| **BS 5979:2007** | Remote Centres for Intruder Alarm Systems | Zonas de seguridad Zone 0 a Zone 5. Clasificación de áreas físicas |
| **ISO 27001:2022 A.7** | Physical and Environmental Security | Perímetro físico, control de entrada, protección contra amenazas externas |
| **NIST SP 800-53 PE** | Physical and Environmental Protection (PE-1 a PE-20) | Control de acceso físico, vigilancia, respuesta a intrusiones |
| **PCI DSS 4.0 Req 9** | Physical Access to Cardholder Data | Acceso físico a sistemas con datos de tarjetas |
| **NFPA 730/731** | Security for premises / Electronic premises security | Seguridad contra incendios integrada con control de acceso |

### 2.3 — Dispositivos y Comunicaciones

| Estándar | Propósito |
|----------|-----------|
| **MQTT 5.0** | Sensores IoT (temperatura, humo, movimiento) — lightweight pub/sub |
| **Modbus TCP/RTU** | Actuadores industriales, PLCs, relés de alta potencia |
| **SIP (RFC 3261)** | Intercomunicadores, audio/video en puertas |
| **Wiegand (legacy)** | Lectores antiguos — solo recepción de ID de tarjeta. Migrando a OSDP |
| **Zigbee 3.0 / Z-Wave** | Sensores inalámbricos de corto alcance (oficinas inteligentes) |

---

## 3. JERARQUÍA FÍSICA — 7 NIVELES

Inspirado en el paper de Sathishkumar et al. (2016) para instalaciones nucleares y adaptado
al modelo multi-tenant del SBOS:

```
NIVEL 1: SITIO (fis_site)
│   Propiedad, terreno, campus, sucursal física
│   Ej: "Sucursal La Paz — Edificio Central", "Planta Industrial Santa Cruz"
│   Zona BS 5979: Zone 0-1 (perímetro)
│
├── NIVEL 2: EDIFICIO (geo_building)
│   │   Construcción dentro del sitio. Clase estructural A-D
│   │   Ej: "Torre Administrativa", "Almacén Principal", "Data Center"
│   │   Zona BS 5979: Zone 2-3 (acceso controlado)
│   │
│   ├── NIVEL 3: PISO (geo_floor)
│   │   │   Nivel/piso del edificio. Control vertical
│   │   │   Ej: "Piso 3 — Finanzas", "Sótano — Estacionamiento"
│   │   │
│   │   ├── NIVEL 4: ÁREA (geo_area)
│   │   │   │   Zona lógica de seguridad con reglas de acceso
│   │   │   │   Ej: "Bóveda Principal", "Sala de Servidores", "Oficinas Generales"
│   │   │   │   Zona BS 5979: Zone 3-5 (restringido a máxima)
│   │   │   │   Reglas: escolta, anti-tailgating, mantrap, 2 personas
│   │   │   │
│   │   │   ├── NIVEL 5: PUNTO DE ACCESO (geo_door)
│   │   │   │   │   Puerta, portón, torniquete, esclusa
│   │   │   │   │   Asociada a uno o más dispositivos de control
│   │   │   │   │
│   │   │   │   └── NIVEL 6: DISPOSITIVO FÍSICO (fis_device)
│   │   │   │           Lector, chapa, cámara, sensor, botón REX, biométrico
│   │   │   │           Protocolo: OSDP / ONVIF / MQTT / Modbus
│   │   │   │
│   │   │   └── NIVEL 7: CONTROLADOR (fis_controller) — puente lógico↔físico
│   │   │           Hardware que ejecuta comandos sobre los dispositivos
│   │   │           1 controlador : N puertas (típico 1:4 en OSDP)
│   │   │           IP, firmware, heartbeat, last_seen
```

### 3.1 — Ejemplo concreto: Sucursal La Paz — Edificio Central

```
SITIO: skull-lapaz-central
├── Zona BS 5979: Zone 1 (perímetro con CCTV)
├── Coordenadas: (-16.500, -68.150)
├── Dirección: Av. Arce #1234, La Paz, Bolivia
│
├── EDIFICIO: torre-administrativa
│   ├── Clase: CLASE_A (reforzado antisísmico)
│   ├── Pisos: 5
│   │
│   ├── PISO 3: piso-finanzas
│   │   │
│   │   ├── ÁREA: boveda-principal
│   │   │   ├── Zona BS 5979: Zone 5 (máxima)
│   │   │   ├── Reglas: anti-tailgating=true, mantrap=true, min_persons=2
│   │   │   │
│   │   │   ├── PUERTA: boveda-puerta-01
│   │   │   │   ├── Tipo: vault_door
│   │   │   │   ├── Dirección: entrada
│   │   │   │   │
│   │   │   │   ├── DISPOSITIVO: lector-biometrico-01
│   │   │   │   │   ├── Tipo: biometric_reader
│   │   │   │   │   ├── Protocolo: OSDP (Secure Channel)
│   │   │   │   │   └── Auth requerida: huella + PIN
│   │   │   │   │
│   │   │   │   ├── DISPOSITIVO: chapa-magnetica-01
│   │   │   │   │   ├── Tipo: magnetic_lock
│   │   │   │   │   └── Protocolo: OSDP (relay output)
│   │   │   │   │
│   │   │   │   ├── DISPOSITIVO: camara-boveda-01
│   │   │   │   │   ├── Tipo: ip_camera
│   │   │   │   │   ├── Protocolo: ONVIF Profile S
│   │   │   │   │   └── Resolución: 1080p, 30fps, grabación 24/7
│   │   │   │   │
│   │   │   │   └── DISPOSITIVO: sensor-puerta-01
│   │   │   │       ├── Tipo: door_contact
│   │   │   │       ├── Protocolo: OSDP (supervised input)
│   │   │   │       └── Alarma: puerta forzada/abierta >30s sin autenticación
│   │   │   │
│   │   │   └── CONTROLADOR: controller-boveda-01
│   │   │       ├── IP: 10.0.3.100
│   │   │       ├── Puertos: 4 (OSDP multi-drop)
│   │   │       └── Heartbeat: cada 30s → bhnexus
```

---

## 4. TABLAS DEL DOMINIO FÍSICO — PATRÓN CLOSURE TABLE

### 4.0 — ¿Por qué Closure Table y no 7 tablas separadas?

El diseño original (7 tablas con FK fijas: site→building→floor→area→door→device→controller)
es **plano pero rígido**. Problemas:

| Operación | 7 tablas | Closure Table |
|-----------|----------|---------------|
| Todas las puertas de un sitio | 4-5 JOINs | 1 JOIN sobre closure |
| Camino completo de un dispositivo | 6 JOINs recursivos | 1 consulta con ORDER BY depth |
| Mover edificio a otro sitio | UPDATE + validar constraints | UPDATE parent_id + rebuild subtree |
| Agregar nuevo nivel (ala/sección) | Crear tabla + migrar datos | Agregar valor ENUM + insertar filas |
| Contar dispositivos por sitio | GROUP BY + múltiples JOINs | 1 consulta con closure |
| Herencia de permisos | Manual por FK anidadas | `WHERE ancestor_id IN (SELECT FROM closure)` |

**Patrón Closure Table:** Una tabla principal con `parent_id` (adjacency list) + una tabla
de cierre que almacena **todos** los pares ancestro→descendiente con su profundidad.
PostgreSQL 18 con GIST indexes resuelve cada consulta jerárquica en ~0.1ms.

### 4.1 — Mapa de tablas

| # | Schema | Tabla | Origen | Propósito |
|---|--------|-------|--------|-----------|
| 1 | bauth | `fis_location` | bos_sitio_fisico + bos_edificio + bos_piso + bos_area_fisica | Tabla ÚNICA de jerarquía física (adjacency list) |
| 2 | bauth | `fis_location_closure` | NUEVA | Closure table: todos los pares ancestro→descendiente |
| 3 | bauth | `fis_area_config` | bos_area_fisica (reglas) | Configuración de seguridad por área |
| 4 | bauth | `fis_device` | bos_dispositivo_fisico | Dispositivos: lectores, chapas, cámaras, sensores |
| 5 | bauth | `fis_controller` | NUEVA | Controladores hardware (ACU) |
| 6 | bauth | `fis_access_zone` | NUEVA | Zona de acceso lógica (EG↔AZ del paper) |
| 7 | bauth | `fis_zone_member` | NUEVA | Puerta↔Zona mapping |

**5 tablas heredadas colapsan en 1 tabla jerárquica + 5 tablas satélite. Total: 7 tablas.**

### 4.2 — Estructura jerárquica con closure

```
fis_location (adjacency list: parent_id)
│
├── SITE          ← root de un tenant
│   ├── BUILDING  ← hijo de SITE
│   │   ├── FLOOR ← hijo de BUILDING
│   │   │   ├── WING    ← NUEVO nivel (sin crear tabla)
│   │   │   │   ├── AREA ← hijo de WING o FLOOR
│   │   │   │   │   ├── DOOR ← hijo de AREA
│   │   │   │   │   │   └── DEVICE ← hijo de DOOR (opcional)
│   │   │   │   │   └── DEVICE ← puede colgar de AREA (cámara, sensor)
│   │   │   │   └── DOOR ← puede colgar de WING
│   │   │   └── AREA
│   │   └── AREA ← puede colgar de BUILDING (edificio sin pisos)
│   └── DEVICE ← cámara perimetral cuelga de SITE
│
fis_location_closure (precomputa todos los caminos)
│
│  ancestor_id=SITE, descendant_id=DOOR, depth=4
│  ancestor_id=SITE, descendant_id=DEVICE, depth=5
│  ancestor_id=BUILDING, descendant_id=DOOR, depth=2
│  ...
```

### 4.3 — fis_location (Tabla ÚNICA de jerarquía · Adjacency List)

**Reemplaza 5 tablas heredadas:** `bos_sitio_fisico`, `bos_edificio`, `bos_piso`, `bos_area_fisica`, y parcialmente `bos_dispositivo_fisico`.

```sql
CREATE TABLE bauth.fis_location (
    location_id      UUID PRIMARY KEY DEFAULT uuidv7(),
    parent_id        UUID REFERENCES fis_location(location_id) ON DELETE RESTRICT,
    tenant_id        UUID NOT NULL REFERENCES idn_tenant(tenant_id),
    location_type    fis_location_type_enum NOT NULL,
    name             TEXT NOT NULL,
    code             TEXT NOT NULL,
    coordinates      POINT,
    address          TEXT,
    security_zone    INTEGER NOT NULL DEFAULT 1,
    is_active        BOOLEAN NOT NULL DEFAULT true,
    properties       JSONB DEFAULT '{}',
    ctx_id           TEXT NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, code)
);

CREATE INDEX IF NOT EXISTS idx_gloc_parent   ON bauth.fis_location(parent_id);
CREATE INDEX IF NOT EXISTS idx_gloc_type     ON bauth.fis_location(location_type, tenant_id);
CREATE INDEX IF NOT EXISTS idx_gloc_tenant   ON bauth.fis_location(tenant_id, location_type);
CREATE INDEX IF NOT EXISTS idx_gloc_coords   ON bauth.fis_location USING GIST (coordinates) WHERE coordinates IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_gloc_props    ON bauth.fis_location USING GIN (properties jsonb_path_ops);

COMMENT ON TABLE bauth.fis_location IS
  'Tabla ÚNICA de jerarquía física (adjacency list). Reemplaza bos_sitio_fisico+bos_edificio+bos_piso+bos_area_fisica.
   parent_id self-referencing. location_type define el nivel: SITE, BUILDING, FLOOR, WING, AREA, DOOR, DEVICE.
   properties JSONB almacena campos específicos del nivel (building_class, floor_number, door_type, etc.).';

COMMENT ON COLUMN bauth.fis_location.parent_id IS 'FK self-referencing. NULL = nodo raíz del tenant (SITE). ON DELETE RESTRICT.';
COMMENT ON COLUMN bauth.fis_location.location_type IS '[ENUM] SITE, BUILDING, FLOOR, WING, AREA, DOOR, DEVICE. Define el nivel jerárquico.';
COMMENT ON COLUMN bauth.fis_location.security_zone IS '[BS 5979] Zone 0 (pública) a Zone 5 (máxima). Heredable: un hijo hereda la zona del padre si no la define.';
COMMENT ON COLUMN bauth.fis_location.properties IS '[JSONB] Campos específicos del nivel: building_class, floor_number, door_type, direction, device_type, etc. Extensible sin ALTER TABLE.';
```

### 4.4 — fis_location_closure (Closure Table)

**Almacena TODOS los pares ancestro→descendiente precomputados.**

```sql
CREATE TABLE bauth.fis_location_closure (
    ancestor_id      UUID NOT NULL REFERENCES fis_location(location_id) ON DELETE CASCADE,
    descendant_id    UUID NOT NULL REFERENCES fis_location(location_id) ON DELETE CASCADE,
    depth            INTEGER NOT NULL CHECK (depth >= 0),
    PRIMARY KEY (ancestor_id, descendant_id)
);

CREATE INDEX IF NOT EXISTS idx_glc_ancestor ON bauth.fis_location_closure(ancestor_id, depth);
CREATE INDEX IF NOT EXISTS idx_glc_descendant ON bauth.fis_location_closure(descendant_id, depth);

COMMENT ON TABLE bauth.fis_location_closure IS
  'Closure table: todos los pares ancestro→descendiente precomputados. depth=0 → self.
   Se actualiza automáticamente por trigger al INSERT/UPDATE/DELETE en fis_location.
   Permite consultar "todas las puertas de un sitio" en 1 JOIN.';
COMMENT ON COLUMN bauth.fis_location_closure.ancestor_id IS 'Ancestro en el camino. FK → fis_location.';
COMMENT ON COLUMN bauth.fis_location_closure.descendant_id IS 'Descendiente en el camino. FK → fis_location.';
COMMENT ON COLUMN bauth.fis_location_closure.depth IS '0=self, 1=hijo directo, 2=nieto, 3=bisnieto...';
```

### 4.5 — Estructura de properties JSONB por location_type

| location_type | Campos en properties JSONB |
|---------------|---------------------------|
| `SITE` | `{"address":"...","city":"La Paz","country_code":"BO","area_m2":5000}` |
| `BUILDING` | `{"building_class":"CLASS_A","floors_count":5,"area_m2":1200}` |
| `FLOOR` | `{"floor_number":3,"area_m2":400}` |
| `WING` | `{"wing_name":"Ala Norte","area_m2":200}` |
| `AREA` | `{"requires_escort":true,"requires_two_person":true,"requires_mantrap":false,"requires_anti_tailgating":true,"max_occupancy":10,"camera_required":true}` |
| `DOOR` | `{"door_type":"VAULT","direction":"ENTRY","schedule_id":"<uuid>"}` |
| `DEVICE` | `{"device_type":"biometric_reader","protocol":"OSDP","ip_address":"10.0.3.50","mac_address":"aa:bb:cc:dd:ee:ff","serial_number":"SN-12345","firmware_version":"2.2.2","auth_level":3}` |

### 4.6 — fis_area_config (Configuración de seguridad por área)

```sql
CREATE TABLE bauth.fis_area_config (
    config_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    location_id      UUID NOT NULL REFERENCES fis_location(location_id) ON DELETE CASCADE UNIQUE,
    requires_escort     BOOLEAN NOT NULL DEFAULT false,
    requires_two_person BOOLEAN NOT NULL DEFAULT false,
    requires_mantrap    BOOLEAN NOT NULL DEFAULT false,
    requires_anti_tailgating BOOLEAN NOT NULL DEFAULT false,
    max_occupancy    INTEGER,
    camera_required  BOOLEAN NOT NULL DEFAULT false,
    allowed_schedules UUID[] DEFAULT '{}',
    metadata         JSONB DEFAULT '{}',
    ctx_id           TEXT NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.fis_area_config IS
  'Reglas de seguridad por área. Separado de fis_location.properties para consultas indexadas.
   Solo aplica a location_type=AREA. UNIQUE por location_id (1:1).';
```

### 4.7 — fis_device (Dispositivos físicos · campos técnicos)

```sql
CREATE TABLE bauth.fis_device (
    device_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    location_id      UUID NOT NULL REFERENCES fis_location(location_id) ON DELETE CASCADE UNIQUE,
    tenant_id        UUID NOT NULL REFERENCES idn_tenant(tenant_id),
    device_type      fis_device_type_enum NOT NULL,
    protocol         fis_device_protocol_enum NOT NULL DEFAULT 'OSDP',
    ip_address       INET,
    mac_address      MACADDR,
    serial_number    TEXT,
    firmware_version TEXT,
    auth_level       INTEGER NOT NULL DEFAULT 1,
    is_online        BOOLEAN NOT NULL DEFAULT false,
    last_seen_at     TIMESTAMPTZ,
    pos_logical_id   UUID,
    status           fis_device_status_enum NOT NULL DEFAULT 'ACTIVE',
    metadata         JSONB DEFAULT '{}',
    ctx_id           TEXT NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gdev_location ON bauth.fis_device(location_id);
CREATE INDEX IF NOT EXISTS idx_gdev_type     ON bauth.fis_device(device_type, tenant_id);
CREATE INDEX IF NOT EXISTS idx_gdev_online   ON bauth.fis_device(is_online, last_seen_at) WHERE is_online = true;
CREATE INDEX IF NOT EXISTS idx_gdev_pos      ON bauth.fis_device(pos_logical_id) WHERE pos_logical_id IS NOT NULL;

COMMENT ON TABLE bauth.fis_device IS
  'Dispositivos físicos. Datos técnicos (IP, MAC, firmware) separados de fis_location para optimizar consultas.
   Relación 1:1 con fis_location para DEVICEs. auth_level define qué métodos de autenticación requiere.';
```

### 4.8 — Catálogo de tipos de dispositivo (ENUM)

| device_type | Protocolo | auth_level | Ejemplo real | Fabricante |
|-------------|-----------|------------|-------------|------------|
| `CARD_READER` | OSDP / Wiegand | 1 (solo tarjeta) | HID Signo 40 | HID Global / Mercury |
| `PIN_KEYPAD` | OSDP | 2 (tarjeta+PIN) | Bosch ACD-IC2 | Bosch Security |
| `BIOMETRIC_READER` | OSDP Biometric | 3 (biométrico) | Suprema BioStation 3 | Suprema |
| `MAGNETIC_LOCK` | OSDP (relay) | — | Assa Abloy EL460 | Assa Abloy |
| `ELECTRIC_STRIKE` | OSDP (relay) | — | HES 9600 | ASSA ABLOY |
| `DOOR_CONTACT` | OSDP (supervised input) | — | Bosch ISN-SM-50 | Bosch |
| `MOTION_SENSOR` | MQTT / Modbus | — | Bosch Blue Line | Bosch |
| `IP_CAMERA` | ONVIF Profile S | — | Axis P3268-LVE | Axis Communications |
| `PTZ_CAMERA` | ONVIF Profile S | — | Hikvision DS-2DE7A | Hikvision |
| `INTERCOM` | SIP / ONVIF | — | Aiphone IX | Aiphone |
| `REX_BUTTON` | OSDP (input) | — | Bosch D223A | Bosch |
| `ALARM_SIREN` | OSDP (output) | — | Bosch LP1 | Bosch |
| `GLASS_BREAK` | OSDP (supervised input) | — | Bosch ISN-GM | Bosch |
| `SMOKE_DETECTOR` | MQTT / Modbus | — | Bosch FAP-425 | Bosch |
| `POS_TERMINAL` | TCP/IP | — | Verifone P400 / Ingenico | Verifone / Ingenico |

### 4.9 — fis_controller (Controlador hardware · ACU)

```sql
CREATE TABLE bauth.fis_controller (
    controller_id    UUID PRIMARY KEY DEFAULT uuidv7(),
    site_location_id UUID NOT NULL REFERENCES fis_location(location_id),
    tenant_id        UUID NOT NULL REFERENCES idn_tenant(tenant_id),
    name             TEXT NOT NULL,
    model            TEXT,
    ip_address       INET,
    firmware_version TEXT,
    ports_count      INTEGER NOT NULL DEFAULT 4,
    is_online        BOOLEAN NOT NULL DEFAULT false,
    last_heartbeat   TIMESTAMPTZ,
    metadata         JSONB DEFAULT '{}',
    ctx_id           TEXT NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.fis_controller IS
  'Controlador hardware (ACU — Access Control Unit). Gestiona N dispositivos vía OSDP multi-drop.
   1 controlador : hasta 4 puertas (OSDP) o hasta 132 lectores (Suprema).';
```

### 4.10 — fis_access_zone (Agrupación lógica · EG↔AZ del paper)

```sql
CREATE TABLE bauth.fis_access_zone (
    zone_id          UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID NOT NULL REFERENCES idn_tenant(tenant_id),
    name             TEXT NOT NULL,
    description      TEXT,
    schedule_id      UUID REFERENCES bcalendar.cal_schedule(schedule_id),
    ctx_id           TEXT NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, name)
);

CREATE TABLE bauth.fis_zone_member (
    zone_member_id   UUID PRIMARY KEY DEFAULT uuidv7(),
    zone_id          UUID NOT NULL REFERENCES fis_access_zone(zone_id) ON DELETE CASCADE,
    location_id      UUID NOT NULL REFERENCES fis_location(location_id) ON DELETE CASCADE,
    UNIQUE (zone_id, location_id)
);

COMMENT ON TABLE bauth.fis_access_zone IS
  'Zona de acceso lógica (Access Zone del paper Sathishkumar et al. 2016).
   Agrupa puertas con reglas comunes. Los Employee Groups se mapean a Access Zones.';
```

### 4.11 — Consultas con Closure Table

```sql
-- 1. TODAS LAS PUERTAS DE UN SITIO (1 JOIN)
SELECT d.*
FROM fis_location d
JOIN fis_location_closure c ON c.descendant_id = d.location_id
WHERE c.ancestor_id = 'site-uuid'
  AND d.location_type = 'DOOR'
  AND d.is_active = true;

-- 2. CAMINO COMPLETO DE UN DISPOSITIVO (ruta jerárquica)
SELECT l.name, l.location_type, c.depth
FROM fis_location l
JOIN fis_location_closure c ON c.ancestor_id = l.location_id
WHERE c.descendant_id = 'device-uuid'
ORDER BY c.depth DESC;
-- Resultado:
-- Sucursal La Paz (SITE, depth=5)
--   Torre Administrativa (BUILDING, depth=4)
--     Piso 3 — Finanzas (FLOOR, depth=3)
--       Bóveda Principal (AREA, depth=2)
--         Puerta Bóveda 01 (DOOR, depth=1)
--           Lector Biométrico 01 (DEVICE, depth=0)

-- 3. TODOS LOS DISPOSITIVOS DE UN TIPO EN UN SITIO
SELECT d.*, dev.device_type, dev.ip_address
FROM fis_location d
JOIN fis_location_closure c ON c.descendant_id = d.location_id
JOIN fis_device dev ON dev.location_id = d.location_id
WHERE c.ancestor_id = 'site-uuid'
  AND dev.device_type = 'IP_CAMERA'
  AND dev.is_online = true;

-- 4. HERENCIA DE PERMISOS: ¿Juan puede acceder a la puerta X?
-- Juan tiene permiso sobre el SITIO → hereda a todas las puertas del sitio
SELECT 1
FROM fis_location_closure c
WHERE c.ancestor_id = (SELECT location_id FROM fis_location WHERE code = 'skull-lapaz')
  AND c.descendant_id = 'door-uuid'
LIMIT 1;

-- 5. CONTAR DISPOSITIVOS POR SITIO
SELECT s.name, count(*) AS device_count
FROM fis_location s
JOIN fis_location_closure c ON c.ancestor_id = s.location_id
JOIN fis_device dev ON dev.location_id = c.descendant_id
WHERE s.location_type = 'SITE'
GROUP BY s.name;
```

### 4.12 — Trigger para mantener la closure table

```sql
-- Función que reconstruye los caminos del closure table
-- al insertar, mover o eliminar un nodo en fis_location
CREATE OR REPLACE FUNCTION bauth.maintain_fis_location_closure()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Self-row: cada nodo es ancestro de sí mismo con depth=0
        INSERT INTO fis_location_closure (ancestor_id, descendant_id, depth)
        VALUES (NEW.location_id, NEW.location_id, 0);
        
        -- Heredar ancestros del padre + 1 nivel de profundidad
        IF NEW.parent_id IS NOT NULL THEN
            INSERT INTO fis_location_closure (ancestor_id, descendant_id, depth)
            SELECT c.ancestor_id, NEW.location_id, c.depth + 1
            FROM fis_location_closure c
            WHERE c.descendant_id = NEW.parent_id;
        END IF;
        
    ELSIF TG_OP = 'UPDATE' AND OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
        -- Mover nodo: eliminar caminos antiguos del subtree, insertar nuevos
        DELETE FROM fis_location_closure
        WHERE descendant_id IN (
            SELECT descendant_id FROM fis_location_closure WHERE ancestor_id = NEW.location_id
        )
        AND ancestor_id NOT IN (
            SELECT descendant_id FROM fis_location_closure WHERE ancestor_id = NEW.location_id
        );
        
        -- Reconstruir caminos desde el nuevo padre
        INSERT INTO fis_location_closure (ancestor_id, descendant_id, depth)
        SELECT p.ancestor_id, c.descendant_id, p.depth + c.depth + 1
        FROM fis_location_closure p
        CROSS JOIN fis_location_closure c
        WHERE p.descendant_id = NEW.parent_id
          AND c.ancestor_id = NEW.location_id;
        
    ELSIF TG_OP = 'DELETE' THEN
        DELETE FROM fis_location_closure
        WHERE descendant_id IN (
            SELECT descendant_id FROM fis_location_closure WHERE ancestor_id = OLD.location_id
        );
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_fis_location_closure
AFTER INSERT OR UPDATE OF parent_id OR DELETE ON bauth.fis_location
FOR EACH ROW EXECUTE FUNCTION bauth.maintain_fis_location_closure();
```
```

---

## 5. FLUJO DE ACCESO FÍSICO — EJEMPLO COMPLETO

### 5.1 — Empleado accede a la bóveda

```
1. USUARIO: Juan Pérez (idn_usuario)
   - Rol: Cajero Principal (S018) → BitMask D2: bóveda (Z5)
   - Credencial: tarjeta HID (OSDP) + huella registrada
   - Horario: Lunes a Viernes 08:00-18:00 (cal_schedule)

2. DISPOSITIVO: lector-biometrico-01 (OSDP Secure Channel)
   - Juan presenta tarjeta → OSDP envía ID al controlador
   - Controlador → bhnexus → bauth: "¿Juan puede entrar a boveda-puerta-01?"

3. BAUTH — DECISIÓN DE ACCESO:
   a) ¿Credencial válida? → Sí, no expirada, no revocada
   b) ¿Juan tiene acceso a geo_area 'boveda-principal'? → Sí, BitMask D2
   c) ¿Horario permitido? → Sí, 09:30 está dentro de 08:00-18:00
   d) ¿Zona requiere 2 personas? → Sí, bóveda es Zone 5
      → Segundo empleado María Pérez también presente (misma puerta, <30s)
   e) ¿Zona requiere mantrap? → Sí, esclusa cerrada detrás de Juan
   f) ¿Zona anti-tailgating? → Sí, sensor confirma solo 1 persona pasó

4. BAUTH → NEXUS → DISPOSITIVO:
   { "decision": "GRANT", "door": "boveda-puerta-01", "duration": 10s }
   → OSDP relay output: chapa-magnetica-01 se abre 10 segundos

5. AUDITORÍA:
   INSERT INTO audit_event (event_type='PHY_ACCESS_GRANTED', ctx_id=..., device_id=...)
   INSERT INTO cal_notification_log (channel='CHAT', ctx_id=...)  → #seguridad (Mattermost)
```

### 5.2 — Intruso fuerza puerta fuera de horario

```
1. DISPOSITIVO: sensor-puerta-01 detecta apertura sin autenticación
   → OSDP supervised input: estado cambia de SECURE a ALARM

2. bhnexus → bauth:
   { "event": "PHY_DOOR_FORCED", "device": "sensor-puerta-01", "timestamp": "..." }

3. BAUTH — RESPUESTA INMEDIATA:
   a) Audit event: PHY_DOOR_FORCED, severity=CRITICAL
   b) Notificación multicanal (cfg_notification_policy: CRITICAL → todos los canales):
      - EMAIL → seguridad@skull.bo
      - SMS → +591 7XX XXXXX (jefe de seguridad)
      - WHATSAPP → grupo de respuesta rápida
      - CHAT → Mattermost #seguridad
      - PUSH → app móvil del guardia de turno
   c) Acción física:
      - Activar alarma sonora (alarm_siren → OSDP output ON)
      - Cámara PTZ apunta a boveda-puerta-01
      - Grabar CCTV 30s antes y 5min después del evento

4. TRAZABILIDAD:
   ctx_id único viaja por todo el sistema:
   sensor → bhnexus → bauth → Novu → Mattermost → cal_notification_log → cal_audit_log

5. RECONSTRUCCIÓN POST-INCIDENTE:
   SELECT * FROM audit_event WHERE ctx_id = '019ef51f-...'
   → Hora exacta, dispositivo, decisión, notificaciones enviadas, quién respondió
```

---

## 6. INTEGRACIÓN CON OTROS DOMINIOS

| Dominio | Integración con D2 Físico |
|---------|--------------------------|
| **D1 Lógico** | BitMask combina permisos lógicos + físicos. Un usuario puede ver un reporte (D1) Y acceder a la bóveda (D2) |
| **D3 Financiero** | POS/Caja es un dispositivo físico. La apertura de caja requiere auth física + lógica |
| **D4 Temporal** | Horarios de acceso físico vía `cal_schedule`. Fuera de horario → requiere step-up |
| **D8 Sesiones** | Una sesión de acceso físico comienza al entrar a un sitio y termina al salir. Tracking de presencia |
| **D12 Blockchain** | Eventos físicos críticos (bóveda abierta, puerta forzada) se anclan en blockchain vía Merkle tree |

---

## 7. PLAN DE IMPLEMENTACIÓN

| Fase | Qué | Horas | Dependencia |
|------|-----|-------|-------------|
| **F0** | Limpiar 5 tablas heredadas del DDL antiguo (marcadores) | 0.5h | — |
| **F1** | ENUM types: `fis_location_type_enum` (7 valores), `fis_device_type_enum` (15), `fis_device_protocol_enum` (6), `fis_device_status_enum` (5) | 0.5h | — |
| **F2** | `fis_location` — tabla única jerárquica + índices GIST/GIN | 1h | F1 |
| **F3** | `fis_location_closure` + trigger PL/pgSQL | 1h | F2 |
| **F4** | `fis_area_config` + `fis_device` + `fis_controller` (satélites) | 1h | F2 |
| **F5** | `fis_access_zone` + `fis_zone_member` | 0.5h | F2 |
| **F6** | COMMENT ON en todas las columnas | 1h | F2-F5 |
| **F7** | Seed: demo jerárquico con 1 sitio + 2 edificios + 3 pisos + 5 áreas + 10 puertas + 15 dispositivos | 1h | F6 |
| **F8** | VPS: prueba de idempotencia DDL + seed | 0.5h | Todo |
| **Total** | | **6h** | |

---

*Documento generado 2026-06-23. Basado en Sathishkumar et al. (2016), IEC 60839-11-5 (OSDP v2.2.2),
BS 5979:2007, NIST SP 800-53 PE, ONVIF Profile S/G, y patentes US 11,410,478 y US 8,941,465.*
