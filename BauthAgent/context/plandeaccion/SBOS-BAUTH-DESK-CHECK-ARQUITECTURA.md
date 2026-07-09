# SBOS — bAuth Desk Check & Arquitectura Definitiva v1.1
## Prueba de escritorio: coherencia entre DB, motores, Context Plane y persistencia
### SKULL · SBOS · Junio 2026 · Corregido: modelo multi-tenant correcto

---

## 1. OBJETIVO

Verificar que cada componente del ecosistema bAuth tiene su tabla correspondiente, su motor de sincronización, su persistence strategy, y su trazabilidad en el Context Plane conforme al modelo multi-tenant definido en SBOS-049.

---

## 2. MODELO MULTI-TENANT CORRECTO (SBOS-049 §4)

```
Tenant: SKULL (operador original — vende el sistema a otras empresas)
  ├── Empresa: SKULL (es_operador=true — opera su propio negocio)
  │     ├── Sucursal: La Paz
  │     │     ├── POS-01
  │     │     └── POS-02
  │     └── Sucursal: Santa Cruz
  │           └── POS-03
  ├── Empresa: ACME S.A. (cliente de SKULL — compró el sistema)
  │     ├── Sucursal: Central
  │     │     ├── POS-10
  │     │     └── POS-11
  │     └── Sucursal: Norte
  │           └── POS-12
  └── Empresa: MAYA Ltda. (cliente de SKULL — compró el sistema)
        └── Sucursal: Única
              └── POS-20

Tenant: ACME (cuando ACME escala a vendedor/distribuidor — NUEVO tenant)
  ├── Empresa: ACME (es_operador=true)
  ├── Empresa: Tiendita S.A. (cliente de ACME)
  └── Empresa: Bodega Ltda. (cliente de ACME)

Tenant: MAYA (cuando MAYA escala a vendedor/distribuidor — NUEVO tenant)
  ├── Empresa: MAYA (es_operador=true)
  └── Empresa: Ferretería XYZ (cliente de MAYA)
```

**Principio fundamental:** El tenant es un DOMINIO TÉCNICO (realm KC + namespace K8s + BD + Vault). La empresa es una ENTIDAD LEGAL (NIT, razón social) dentro de un tenant. Un tenant puede contener múltiples empresas. Una empresa que escala a vendedor obtiene su PROPIO tenant independiente.

---

## 3. JERARQUÍA DE TABLAS

```
bos_tenant (1)
  │
  ├── bos_empresa (N)  ← FK tenant_id
  │     │
  │     ├── bos_sucursal (N)  ← FK empresa_id, FK tenant_id
  │     │
  │     └── bos_user_template  ← FK empresa_id, FK sucursal_id, pos_logico
  │           │
  │           └── bos_rol_template ← tenant_id='*' (global) o tenant_id específico
  │
  ├── context_sessions  ← tenant_id + empresa_id + sucursal_id + pos_logico + user_uuid
  ├── bauth_audit_events ← tenant_id + empresa_id + sucursal_id + pos_logico
  └── bos_delegation_log ← tenant_id
```

---

## 4. MATRIZ DE PERSISTENCIA — Dónde vive cada dato

| Dato | PostgreSQL | Redis | Keycloak | Tryton | Retention |
|------|-----------|-------|----------|--------|-----------|
| Tenant | `bos_tenant` | — | Realm (tenant-{id}) | — | Permanente |
| Empresa | `bos_empresa` | — | — | res.company | Permanente |
| Sucursal | `bos_sucursal` | — | — | res.branch (custom) | Permanente |
| Rol | `bos_rol_template` | — | Composite Role, Realm Roles | Group, ir.model.access | Hasta RETIRADO |
| Historial rol | `bos_rol_template_history` | — | — | — | 10 años (WORM) |
| Usuario | `bos_user_template` | — | User, Groups, Attributes | res.user, groups | Hasta TERMINATED + retención |
| Herencia DAG | `rol_closure` | — | Role hierarchy | Group hierarchy | Recalculada |
| Delegación | `bos_delegation_log` | — | — | — | 90 días post-expiración |
| Biometría | `bauth_biometric_templates` | — | — | — | Hasta revocación + 90d |
| Contraseñas | `bauth_password_history` | — | KC password hash | — | Últimas 10 |
| MFA | `bauth_mfa_enrollments` | — | KC credentials | — | Hasta revocación |
| Sesiones | `context_sessions` | `ctx:{ctx_id}` | KC sessions | — | TTL sesión (max 24h) |
| Auditoría | `bauth_audit_events` | — | — | — | 10 años (WORM) |
| Sync log | `bauth_sync_log` | — | — | — | 90 días |
| SU break-glass | `bauth_superuser_contexts` | — | — | — | 10 años |
| Access reviews | `bauth_access_reviews` | — | — | — | 3 años |
| Ghost accounts | `bauth_ghost_accounts` | — | — | — | 1 año |
| Key rotation | `bauth_key_rotation_log` | — | — | — | 10 años |
| Zone→App | `bos_zone_application_map` | — | — | — | Permanente |
| BitMask cache | — | `bitmask:{uuid}` (TTL 30s) | User Attributes (JWT) | — | 30s cache |

---

## 5. TRAZABILIDAD POR MOTOR

### 5.1 KeycloakEngine (B12)

```
sync_role(): bos_rol_template → KC Composite Role + Realm Roles + Auth Flows
sync_user(): bos_user_template → KC User + Groups + Attributes (mask_eff_hex)
reconcile(): GET /roles+/users → comparar con bauth_db → corregir drift
```

### 5.2 TrytonEngine (B13)

```
sync_role(): bos_rol_template → res.group + ir.model.access (5 capas)
sync_user(): bos_user_template → res.user + groups (NUNCA DELETE, solo active=false)
reconcile(): search_read → comparar → create/write
```

### 5.3 BhnexusEngine (B15)

```
auth_query(): banexus → bhnexus → bAuth (gRPC). Cache hit < 1ms.
policy_update(): bAuth → bhnexus → invalidar cache → propagar a banexus
Cache: in-memory, TTL 30s, LRU 10K entradas
```

### 5.4 OAuth2ProxyEngine (B14)

```
sync_app(): bos_zone_application_map → oauth2-proxy.cfg (archivo) → SIGHUP reload
JWT keys: rotadas cada 24h via Vault, sin downtime (dual-signing)
```

---

## 6. CONTEXT PLANE — Flujo completo (SBOS-049)

```
CREACIÓN (dctx_id):
  Dispositivo arranca → bos crea dctx_id (pre-auth, mask=0x0)
  context_sessions + Redis DB1 (TTL 60s)

PROMOCIÓN (post-login):
  Usuario login KC → bAuth recibe evento
  Evalúa Physical+Logical+Financial → calcula mask
  UPDATE context_sessions SET user_uuid, empresa_id, sucursal_id, pos_logico, bitmask_hex, loa
  Redis: ctx:{ctx_id} TTL=12h, bitmask:{uuid} TTL=30s

VALIDACIÓN (Kong PEP cada request):
  Kong extrae X-SBOS-Context → GET bAuth :9443/context/{ctx_id}
  Redis lookup < 5ms → si miss → PostgreSQL
  Kong inyecta: X-SBOS-Tenant, X-SBOS-Empresa, X-SBOS-Bitmask
  Inválido → 401

INVALIDACIÓN (logout/revocación):
  UPDATE context_sessions SET state=INVALIDATED
  DEL Redis ctx:{ctx_id} (inmediato)
  Kong deja de aceptar el ctx_id
```

---

## 7. PRUEBA DE ESCRITORIO — Escenario real multi-tenant

**Escenario:** SKULL vende el sistema a ACME. ACME registra sus empleados. María (cajera de ACME, sucursal Central, POS-10) opera su turno.

```
Paso 1 — Alta de tenant (si ACME es solo cliente, no operador):
  -- ACME es empresa dentro del tenant SKULL
  INSERT INTO bos_empresa (empresa_id, tenant_id, razon_social, nit, es_operador)
  VALUES ('acme', 'skull', 'ACME S.A.', '1234567890', false);

Paso 2 — Alta de sucursal:
  INSERT INTO bos_sucursal (sucursal_id, empresa_id, tenant_id, nombre)
  VALUES ('acme-central', 'acme', 'skull', 'Central');

Paso 3 — Crear Admin Tenant de ACME (S016):
  INSERT INTO bos_user_template (username, email, tenant_id, empresa_id, rol_ids)
  VALUES ('admin-acme', 'admin@acme.com.bo', 'skull', 'acme', ARRAY['ROL-SYS-ADMIN-TENANT']);

Paso 4 — Admin ACME crea rol Cajero para su empresa:
  INSERT INTO bos_rol_template (id, tenant_id, empresa_id, tier, ...)
  VALUES ('ROL-CAJERO-ACME', 'skull', 'acme', 'BIZ_N1', ...);

Paso 5 — Admin ACME contrata a María:
  INSERT INTO bos_user_template (username, email, tenant_id, empresa_id, sucursal_id, pos_logico, rol_ids)
  VALUES ('maria.garcia', 'maria@acme.com.bo', 'skull', 'acme', 'acme-central', 'POS-10', ARRAY['ROL-CAJERO-ACME']);
  → ComputeBundle: mask_eff = mask_own(ROL-CAJERO-ACME) | mask_eff(junior roles)
  → UPDATE bos_user_template SET mask_eff_hex = '0x000000000000003F'

Paso 6 — María hace login:
  María → portal ACME → Keycloak (realm tenant-skull) → OIDC+PKCE → JWT
  bAuth: promote dctx_id → ctx_id
  INSERT INTO context_sessions (ctx_id, tenant_id='skull', empresa_id='acme',
         sucursal_id='acme-central', pos_logico='POS-10', user_uuid=..., bitmask_hex=...)

Paso 7 — María opera en Tryton:
  María abre Tryton → Kong valida ctx_id → OK
  Tryton aplica record rules: solo ve datos de empresa='acme', sucursal='acme-central'
  María cobra venta en POS-10 → factura SIN emitida a NIT de ACME
  Audit event: empresa_id='acme', sucursal_id='acme-central', pos_logico='POS-10'

Paso 8 — ACME escala: se vuelve vendedor/distribuidor:
  -- ACME obtiene su PROPIO tenant (multi-tenant real)
  INSERT INTO bos_tenant (tenant_id, nombre, realm_kc, namespace_k8s)
  VALUES ('acme', 'ACME Plataforma', 'tenant-acme', 'ns-acme');
  INSERT INTO bos_empresa (empresa_id, tenant_id, razon_social, nit, es_operador)
  VALUES ('acme', 'acme', 'ACME S.A.', '1234567890', true);
  -- ACME ahora puede crear sus propias empresas cliente dentro de su tenant
```

✅ **El escenario multi-tenant es coherente. Sin bloqueantes.**

---

## 8. VERIFICACIÓN DE COHERENCIA

| Verificación | Resultado |
|-------------|----------|
| ¿Cada dato tiene exactamente UN dueño? | ✅ `bos_rol_template` + `bos_user_template` son fuente de verdad |
| ¿Jerarquía tenant→empresa→sucursal→pos→user respetada? | ✅ FK constraints en cascada |
| ¿Aislamiento entre empresas del mismo tenant? | ✅ record rules en Tryton + realm roles en KC |
| ¿Aislamiento entre tenants? | ✅ realms KC independientes, namespaces K8s independientes, BD separadas por tenant |
| ¿Toda operación tiene audit trail? | ✅ `bauth_audit_events` con empresa_id, sucursal_id, pos_logico |
| ¿WORM implementado a nivel BD? | ✅ REVOKE UPDATE/DELETE en tablas WORM |
| ¿TTLs de cache coherentes? | ✅ Redis 30s-24h, PostgreSQL permanente |
| ¿Multi-tenant real soportado? | ✅ Empresa que escala → nuevo `bos_tenant` con infraestructura independiente |

---

## 9. GAPS IDENTIFICADOS

| # | Gap | Severidad | Acción |
|---|-----|----------|--------|
| 1 | Redis key space no documentado | Media | Documentar: `ctx:{id}`, `bitmask:{uuid}`, `kc_token` |
| 2 | Kong plugin Lua PEP sin código | Alta | B16.T07: implementar `sbos-context` |
| 3 | Vault policies HCL no documentadas | Media | Documentar políticas por motor |
| 4 | `bauthctl` CLI sin código | Alta | B10.T06-T18, B11.T05-T09 |
| 5 | gRPC proto files sin escribir | Alta | B18.T05-T07: `bauth.proto`, `nexus.proto` |
| 6 | Integration tests sin escribir | Crítica | B10.T15, B11.T14, B12.T07 |
| 7 | Load testing sin benchmarks | Alta | B29.T10: k6/artillery |
| 8 | Runbook operacional sin documentar | Media | Backup, restore, scale, troubleshoot |

---

## 10. DECISIÓN DE ALMACENAMIENTO — JSONB PostgreSQL vs Archivos Planos

### 10.1 Decisión

**PostgreSQL JSONB como fuente de verdad + Redis cache caliente + archivos YAML como input humano.**

| Capa | Tecnología | Propósito | Latencia |
|------|-----------|----------|----------|
| **Input** | YAML/JSON (archivos) | Edición humana, control de versiones (git) | — |
| **Fuente de verdad** | PostgreSQL JSONB (`bos_rol_template.template`, `bos_user_template.template`) | Almacenamiento ACID, GIN index, WORM history | < 0.5ms (PK lookup) |
| **Cache caliente** | Redis (`bitmask:{uuid}`, `ctx:{id}`) | 99% de decisiones de auth | < 1ms |
| **Historial** | PostgreSQL (`bos_rol_template_history`) | WORM inmutable SHA-256 chain, ISO 27001 A.8.15 | < 2ms (INSERT trigger) |

### 10.2 ¿Por qué PostgreSQL JSONB?

| Ventaja | Impacto en bAuth |
|---------|-----------------|
| **ACID + MVCC** | 4 engines concurrentes leyendo sin locks. Escrituras sin race conditions. |
| **GIN indexes** | `template @> '{"tier": "BIZ_N1"}'` → encontrar todos los roles N1 en < 2ms sobre 368 registros. Imposible con archivos planos (O(n) scan). |
| **WORM history automático** | Trigger `bauth_compute_entry_hash()` encadena SHA-256 en cada cambio. Sin construir storage inmutable desde cero. |
| **Replicación HA** | Patroni + streaming replication. Failover < 30s. Backups con pgBackRest + WAL. |
| **Cifrado en reposo** | pg_tde o LUKS a nivel filesystem. Transparente para la aplicación. |
| **JSONB pre-parseado** | PostgreSQL almacena JSONB en formato binario. Las lecturas NO requieren deserialización — a diferencia de `serde_json::from_str()` que parsea cada vez. |

### 10.3 ¿Por qué Redis como cache?

| Dato | Key Redis | TTL | Por qué |
|------|-----------|-----|---------|
| BitMaskBundle | `bitmask:{user_uuid}` | 30s | La decisión de auth más frecuente. < 1ms. |
| Context Session | `ctx:{ctx_id}` | = session TTL | Kong PEP consulta en cada request. |
| KC admin token | `kc_token` | 5 min | Evitar re-auth a Keycloak en cada sync. |

### 10.4 Flujo de lectura/escritura

```
ESCRITURA (rara — solo al crear/modificar rol):
  bauthctl role create template.yml
    → Rust: validar YAML (serde)
    → Rust: cifrar AES-256-GCM
    → PostgreSQL: INSERT INTO bos_rol_template (template JSONB)
    → PostgreSQL: trigger → INSERT INTO bos_rol_template_history (WORM)
    → Rust: invalidar Redis cache bitmask:* para usuarios afectados

LECTURA CALIENTE (99% de requests):
  bAuth recibe request de autorización
    → Redis GET bitmask:{user_uuid}
    → Cache hit → responder en < 1ms

LECTURA FRÍA (1% — cache miss, primer acceso, post-invalidación):
  Redis GET → miss
    → PostgreSQL: SELECT template FROM bos_rol_template WHERE id = ?
    → PostgreSQL retorna JSONB pre-parseado (< 0.5ms)
    → Rust: extraer mask_own_hex del JSONB
    → Redis: SET bitmask:{user_uuid} TTL 30s (poblar cache)
    → Responder en < 2ms total
```

---

## 11. DOMINIO FÍSICO — Jerarquía de ubicaciones y dispositivos

### 11.1 Modelo jerárquico (BS 5979:2007 + CPTED/ASIS)

```
País (ISO 3166-1) → Ciudad → Sitio → Edificio → Piso → Área → Dispositivo
```

Cada nivel hereda `zona_seguridad` (ZONA_0 a ZONA_5) del padre. Un dispositivo solo puede estar en UN área.

| Nivel | Tabla | Estándar | Zona típica |
|-------|-------|---------|------------|
| País | `bos_pais` | ISO 3166-1 | — |
| Ciudad | `bos_ciudad` | ISO 3166-2 | — |
| Sitio | `bos_sitio_fisico` | BS 5979 Zone 0-1 | ZONA_0–ZONA_5 |
| Edificio | `bos_edificio` | BS 5979 Zone 2-3 | ZONA_2–ZONA_5 (Clase A–D) |
| Piso | `bos_piso` | Acceso vertical | ZONA_2–ZONA_5 |
| Área | `bos_area_fisica` | BS 5979 Zone 3-5 | ZONA_3–ZONA_5 (mantrap, escolta, 2-personas) |
| Dispositivo | `bos_dispositivo_fisico` | IEC 60839-11-5 (OSDP), ONVIF | 4 niveles de autenticación física |

### 11.2 Tipos de dispositivos (30+)

Puerta, chapa electromagnética, cerrojo inteligente, torniquete, barrera vehicular, cámara IP/térmica/360, sensor movimiento/apertura/temperatura/humo/inundación, alarma incendio, sirena, panel control, teclado PIN, caja registradora, terminal POS, lector QR/NFC/barras/huella/facial/iris/voz, actuador, relé, controlador iluminación, termostato.

### 11.3 Protocolos (10)

OSDP (IEC 60839-11-5), Wiegand, ONVIF (cámaras), MQTT (sensores IoT), HTTP, Modbus, BACnet, Zigbee, Z-Wave, LoRaWAN.

### 11.4 POS Lógico — Cumplimiento SIN Bolivia

`bos_pos_logico` adaptado a normativa SIN (RND 10.0021.16, RND 102100000011):
- Dosificación por punto de venta (rango, fecha límite)
- CUIS, CUFD (24h), CAFC
- Modalidad: Electrónica en Línea / Computarizada en Línea / Portal Web
- Leyendas obligatorias SIN + Ley 453 (Derechos del Consumidor)
- Conexión WebService SIN (URL, token, certificado ADSIB, heartbeat)
- 27 tipos de documentos fiscales

---

## 12. i18n — Más allá de traducciones (ICU4X 2.0 + Fluent)

12 capacidades i18n integradas: formato fechas/horas, números/monedas, plurales (cardinal+ordinal), género/concordancia, ordenación alfabética, tiempo relativo, listas, unidades de medida, primer día semana, negociación de idioma, textos ricos con inline tags, asimetría de traducción. Stack: ICU4X 2.0 (Rust `#[no_std]`) + Fluent (Mozilla) + Unicode CLDR 46.

---

## 13. RESUMEN FINAL — Verificación pre-desarrollo

| Verificación | Estado |
|-------------|--------|
| ¿Jerarquía tenant→empresa→sucursal→pos→user completa? | ✅ 5 tablas con FK cascade |
| ¿Multi-tenant real soportado? | ✅ Empresa operadora obtiene su propio tenant |
| ¿Catálogos ISO normalizados? | ✅ 4 tablas (país, moneda, idioma, timezone) con seed data |
| ¿Dominio físico jerárquico? | ✅ 6 niveles + 30 tipos de dispositivos |
| ¿Cumplimiento SIN Bolivia? | ✅ POS lógico con dosificación, CUFD, CUIS, CAFC |
| ¿Multi-N config (idiomas, monedas, timezones)? | ✅ Arrays + tablas relacionadas |
| ¿Multigestión fiscal? | ✅ Gestiones con 12 períodos + calendario de eventos |
| ¿i18n completo? | ✅ 12 capacidades ICU4X + Fluent |
| ¿DDL ejecutable? | ✅ 42 tablas, 1,736 líneas SQL, seed data |
| ¿Sin hardcoding? | ✅ FK a catálogos ISO, TEXT[] para arrays |
| ¿Listo para desarrollo? | ✅ 435 átomos documentados, 18 SSOT, sin bloqueantes |

---

## 14. DOMINIO FINANCIERO — Control de transacciones, decisiones y aprobaciones

### 14.1 Tablas (SOX §302/§404, COSO, PCI DSS 4.0, ISO 27001)

| Tabla | Seed | Propósito |
|-------|------|-----------|
| `bos_financial_tipo_transaccion` | 17 | Catálogo de transacciones clasificadas por riesgo |
| `bos_financial_limit` | — | Límites por operación/día/semana/mes/año/gestión |
| `bos_financial_decision_matrix` | — | Cascada de aprobación de 3 niveles con montos máximos |
| `bos_financial_approval` | — | Registro de cada decisión (SOX §404 evidencia) |
| `bos_financial_document_operation` | 13 | Matriz documento × verbo |
| `bos_financial_role_permission` | — | Permisos granulares rol × operación |

### 14.2 Flujo de aprobación financiera

```
Operación → verificar permiso (bos_financial_role_permission)
  → verificar límite (bos_financial_limit)
  → si excede → cascada de aprobación (bos_financial_decision_matrix)
  → registro de decisión (bos_financial_approval)
  → actualizar acumulados (bos_financial_limit)
```

---

## 15. RESUMEN FINAL — Verificación pre-desarrollo

| Verificación | Estado |
|-------------|--------|
| ¿Jerarquía tenant→empresa→sucursal→pos→user completa? | ✅ |
| ¿Multi-tenant real soportado? | ✅ |
| ¿Catálogos ISO normalizados (país, moneda, idioma, timezone)? | ✅ 5 tablas con seed data |
| ¿Dominio físico jerárquico (6 niveles)? | ✅ BS 5979, CPTED, OSDP |
| ¿Cumplimiento SIN Bolivia? | ✅ POS con dosificación, CUFD, CUIS, CAFC |
| ¿Multi-N config (idiomas, monedas, timezones)? | ✅ Arrays + FK a catálogos |
| ¿Multigestión fiscal con calendario? | ✅ |
| ¿Dominio financiero (SOX/COSO/PCI DSS)? | ✅ 6 tablas, 3 niveles de aprobación |
| ¿i18n completo (ICU4X + Fluent)? | ✅ 12 capacidades |
| ¿DDL ejecutable con seed data? | ✅ 48 tablas, 1,995 líneas SQL |
| ¿Sin hardcoding? | ✅ FK a catálogos ISO |
| ¿Listo para desarrollo? | ✅ 435 átomos, 18 SSOT, sin bloqueantes |

---

*SKULL · SBOS · SBOS-BAUTH-DESK-CHECK-ARQUITECTURA v1.5 · Junio 2026 · DDL 53 tablas · 2,184 líneas SQL · Todos los dominios cubiertos · Listo para desarrollo*
