# A.04 — Identidades bNexus en SBOSDB
## Ejemplos completos de registro — nodos, lectores, sensores, cámaras

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Respalda:** `1.03_MANUAL-IDENTIDADES-NEXUS.md`  
**BD:** SBOSDB · Schema: `bauth`  

---

> Todo SQL en este anexo es idempotente cuando se usa `ON CONFLICT DO NOTHING`.
> Ejecutar contra SBOSDB (`postgres://postgres:postgres@localhost:15432/SBOSDB`).

---

## 1. Registro de un nodo banexus (daemon en workstation POS)

```sql
-- 1. Entidad en el árbol universal
INSERT INTO bauth.idn_identity_entity (
    entity_id, tenant_id, parent_id,
    name, type_level, entity_type, is_active
) VALUES (
    '11111111-1111-1111-1111-111111111111',
    'skull-tenant-uuid',
    'rack-01-uuid',           -- parent: Rack-01 (pos, rack)
    'banexus-ventas-01',
    'actor',
    'SERVICE',
    true
) ON CONFLICT (entity_id) DO NOTHING;

-- 2. Atributos de seguridad
INSERT INTO bauth.idn_identity_attribute (entity_id, namespace, key, value)
VALUES
    ('11111111-1111-1111-1111-111111111111', 'security', 'node_id',   'Ventas-01'),
    ('11111111-1111-1111-1111-111111111111', 'security', 'spiffe_id', 'spiffe://sbos.skull/agent/banexus/Ventas-01'),
    ('11111111-1111-1111-1111-111111111111', 'security', 'protocol',  'WebSocket_mTLS'),
    ('11111111-1111-1111-1111-111111111111', 'security', 'form',      'daemon'),
    ('11111111-1111-1111-1111-111111111111', 'core',     'location',  'PHY_ZONE_VENTAS'),
    ('11111111-1111-1111-1111-111111111111', 'core',     'os',        'Fedora 40')
ON CONFLICT DO NOTHING;

-- 3. Subscriber Account (necesario porque banexus se autentica con mTLS)
INSERT INTO bauth.idn_user (
    user_id, entity_id, tenant_id,
    username, loa_min, ial_achieved, is_active
) VALUES (
    '22222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'skull-tenant-uuid',
    'banexus-ventas-01',
    'AAL3',     -- mTLS obligatorio
    'IAL1',
    true
) ON CONFLICT (entity_id, tenant_id) DO NOTHING;

-- 4. Credencial mTLS
INSERT INTO bauth.auth_credential (
    credential_id, user_id, method_code, is_active
) VALUES (
    '33333333-3333-3333-3333-333333333333',
    '22222222-2222-2222-2222-222222222222',
    'MTLS_X509',
    true
) ON CONFLICT DO NOTHING;

INSERT INTO bauth.auth_credential_x509 (
    credential_id, vault_path, cert_cn, cert_fingerprint
) VALUES (
    '33333333-3333-3333-3333-333333333333',
    'pki/bauth/banexus/ventas-01',
    'banexus-ventas-01',
    'sha256:a3f1c2d4e5f6...'   -- actualizar con fingerprint real tras emitir cert
) ON CONFLICT DO NOTHING;

-- 5. Gobernanza NHI
INSERT INTO bauth.idn_roles_nhi_identity (
    nhi_id, entity_id, owner_user_id,
    review_date, secret_ttl_h, rotation_policy
) VALUES (
    '44444444-4444-4444-4444-444444444444',
    '11111111-1111-1111-1111-111111111111',
    'admin-uuid',               -- UUID del administrador responsable
    '2027-02-04',
    8760,                       -- TTL del secreto: 1 año
    'rotate_30_days_before_expiry'
) ON CONFLICT DO NOTHING;
```

---

## 2. Registro de un lector OSDP (sin Subscriber Account)

```sql
-- 1. Entidad en el árbol (el lector vive bajo la Puerta que controla)
INSERT INTO bauth.idn_identity_entity (
    entity_id, tenant_id, parent_id,
    name, type_level, entity_type, is_active
) VALUES (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'skull-tenant-uuid',
    'puerta-principal-uuid',    -- parent: Puerta-Principal (pos, puerta)
    'Lector-OSDP-Principal-001',
    'actor',
    'DEVICE',
    true
) ON CONFLICT (entity_id) DO NOTHING;

-- 2. Atributos
INSERT INTO bauth.idn_identity_attribute (entity_id, namespace, key, value)
VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'security', 'serial',       'ZK-SB1000-4F2A'),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'security', 'osdp_address', '1'),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'security', 'firmware',     'v3.2.1'),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'security', 'protocol',     'OSDP_V2'),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'core',     'fabricante',   'ZKTeco'),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'core',     'modelo',       'SB1000')
ON CONFLICT DO NOTHING;

-- 3. Postura de hardware en auth_device
INSERT INTO bauth.auth_device (
    device_id, entity_id, device_type,
    trust_level, protocol, last_seen
) VALUES (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'osdp_reader',
    'HIGH',
    'OSDP_V2',
    NOW()
) ON CONFLICT DO NOTHING;

-- NOTA: Sin idn_user ni auth_credential — bhnexus HAL controla el lector directamente.
```

---

## 3. Registro de una cámara ONVIF

```sql
INSERT INTO bauth.idn_identity_entity (
    entity_id, tenant_id, parent_id,
    name, type_level, entity_type, is_active
) VALUES (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'skull-tenant-uuid',
    'acceso-principal-uuid',    -- parent: pos donde está la cámara
    'Camara-IP-Entrada-Principal',
    'actor',
    'DEVICE',
    true
) ON CONFLICT (entity_id) DO NOTHING;

INSERT INTO bauth.idn_identity_attribute (entity_id, namespace, key, value)
VALUES
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'contact',  'ip_address',  '192.168.1.101'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'security', 'protocol',    'ONVIF_Profile_C'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'security', 'rtsp_url',    'rtsp://cam-entrada/stream1'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'core',     'fabricante',  'Hikvision'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'core',     'modelo',      'DS-2CD2143G2-I')
ON CONFLICT DO NOTHING;

INSERT INTO bauth.auth_device (
    device_id, entity_id, device_type, trust_level, protocol, last_seen
) VALUES (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'ip_camera', 'MEDIUM', 'ONVIF', NOW()
) ON CONFLICT DO NOTHING;
```

---

## 4. Registro de un sensor IoT MQTT

```sql
INSERT INTO bauth.idn_identity_entity (
    entity_id, tenant_id, parent_id,
    name, type_level, entity_type, is_active
) VALUES (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    'skull-tenant-uuid',
    'deposito-uuid',
    'Sensor-Temperatura-Rack-01',
    'actor',
    'DEVICE',
    true
) ON CONFLICT (entity_id) DO NOTHING;

INSERT INTO bauth.idn_identity_attribute (entity_id, namespace, key, value)
VALUES
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'security', 'protocol',     'MQTT_v5'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'security', 'mqtt_topic',   'sbos/sensors/rack01/temp'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'core',     'fabricante',   'Raspberry Pi Foundation'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'core',     'modelo',       'Pi Zero 2W'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'core',     'sensor_type',  'temperature_humidity')
ON CONFLICT DO NOTHING;
```

---

## 5. Árbol completo de una sucursal con banexus-gateway

```sql
-- tenant: ya existe
-- bdomain: Sucursal-Lima (crear si no existe)
INSERT INTO bauth.idn_identity_entity (entity_id, tenant_id, parent_id, name, type_level, entity_type, is_active)
VALUES ('f1111111-0000-0000-0000-000000000000', 'skull-tenant-uuid', NULL, 'Sucursal Lima Norte', 'bdomain', 'sucursal', true)
ON CONFLICT DO NOTHING;

-- bsubdomain: Planta Baja
INSERT INTO bauth.idn_identity_entity (entity_id, tenant_id, parent_id, name, type_level, entity_type, is_active)
VALUES ('f2222222-0000-0000-0000-000000000000', 'skull-tenant-uuid', 'f1111111-0000-0000-0000-000000000000', 'Planta Baja', 'bsubdomain', 'piso', true)
ON CONFLICT DO NOTHING;

-- pos: Puerta de ingreso
INSERT INTO bauth.idn_identity_entity (entity_id, tenant_id, parent_id, name, type_level, entity_type, is_active)
VALUES ('f3333333-0000-0000-0000-000000000000', 'skull-tenant-uuid', 'f2222222-0000-0000-0000-000000000000', 'Puerta-Ingreso-Lima', 'pos', 'puerta', true)
ON CONFLICT DO NOTHING;

-- actor: banexus-gateway en Raspberry Pi (controla la puerta)
INSERT INTO bauth.idn_identity_entity (entity_id, tenant_id, parent_id, name, type_level, entity_type, is_active)
VALUES ('f4444444-0000-0000-0000-000000000000', 'skull-tenant-uuid', 'f3333333-0000-0000-0000-000000000000', 'banexus-gateway-lima-01', 'actor', 'SERVICE', true)
ON CONFLICT DO NOTHING;

-- actor: Lector OSDP controlado por el gateway
INSERT INTO bauth.idn_identity_entity (entity_id, tenant_id, parent_id, name, type_level, entity_type, is_active)
VALUES ('f5555555-0000-0000-0000-000000000000', 'skull-tenant-uuid', 'f3333333-0000-0000-0000-000000000000', 'Lector-OSDP-Lima-001', 'actor', 'DEVICE', true)
ON CONFLICT DO NOTHING;

-- Atributos del gateway
INSERT INTO bauth.idn_identity_attribute (entity_id, namespace, key, value) VALUES
    ('f4444444-0000-0000-0000-000000000000', 'security', 'node_id',   'Sucursal-Lima-01'),
    ('f4444444-0000-0000-0000-000000000000', 'security', 'form',      'gateway'),
    ('f4444444-0000-0000-0000-000000000000', 'security', 'spiffe_id', 'spiffe://sbos.skull/agent/banexus/Sucursal-Lima-01'),
    ('f4444444-0000-0000-0000-000000000000', 'core',     'hardware',  'Raspberry Pi 5'),
    ('f4444444-0000-0000-0000-000000000000', 'contact',  'ip_address','10.10.2.50')
ON CONFLICT DO NOTHING;
```

---

## 6. Consulta — listar todos los nodos banexus activos

```sql
SELECT
    e.entity_id,
    e.name,
    e.entity_type,
    a_node.value    AS node_id,
    a_form.value    AS form,
    a_spiffe.value  AS spiffe_id,
    u.loa_min,
    u.is_active     AS cuenta_activa
FROM bauth.idn_identity_entity e
LEFT JOIN bauth.idn_identity_attribute a_node
    ON a_node.entity_id = e.entity_id AND a_node.namespace = 'security' AND a_node.key = 'node_id'
LEFT JOIN bauth.idn_identity_attribute a_form
    ON a_form.entity_id = e.entity_id AND a_form.namespace = 'security' AND a_form.key = 'form'
LEFT JOIN bauth.idn_identity_attribute a_spiffe
    ON a_spiffe.entity_id = e.entity_id AND a_spiffe.namespace = 'security' AND a_spiffe.key = 'spiffe_id'
LEFT JOIN bauth.idn_user u
    ON u.entity_id = e.entity_id
WHERE e.entity_type = 'SERVICE'
  AND e.is_active = true
  AND a_node.value IS NOT NULL
ORDER BY e.name;
```

---

*SKULL · SBOS · bNexus · A.04_IDENTIDADES-BNEXUS-SBOSDB · v1.0.0 · Agosto 2026*
