# BAUTH-FRONTEND-HERRAMIENTAS-POR-DOMINIO.md — Auditoría de Captura de Datos

**Versión:** 1.0 · **Fecha:** 2026-06-24
**Propósito:** Identificar CADA campo en la base de datos que requiere una herramienta de frontend
para capturar sus datos. Sin esta capa, la DDL tiene columnas que nadie puede poblar.

**Principio:** Si un humano no puede escribir el dato a mano, la DDL debe declarar qué widget usar.
El puente DDL↔UI es `menu_context.entity_type` + `widget_type`.

---

## METODOLOGÍA

Para cada tipo de dato especial, se identifica:
1. **Columnas afectadas** — en qué tablas aparece
2. **Widget requerido** — qué componente de UI necesita
3. **Herramienta** — librería/paquete concreto
4. **menu_context** — entrada que declarará el widget al Core UI

---

## 1. DATOS GEOESPACIALES

### 1.1 Punto (lat, lon)

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bglobal.geo_timezone` | `coordinates` | `POINT` | Ubicación principal de la zona horaria |
| `bauth.fis_location` | `coordinates` | `POINT` | Ubicación de sitio/edificio/puerta |
| `bauth.geo_location_log` 🆕 | `point` | `POINT` | Ubicación de login |
| `bauth.org_sucursal` | — | (falta columna) | Sucursal necesita coordenadas |

**Widget:** `MAP_POINT_PICKER` — El admin toca un punto en el mapa o busca una dirección.
**Herramienta:** `flutter_map` + OpenStreetMap tiles + Nominatim search
**Licencia:** BSD/MIT · **Costo:** $0 · **Sin API key**

```
menu_context: entity_type='fis_location', context_key='geo.point.picker', widget='MAP_POINT_PICKER'
```

### 1.2 Polígono / Geo-fence

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bauth.geo_fence` 🆕 | `polygon` | `POLYGON` | Geo-cerca de sucursal |
| `bauth.geo_fence` 🆕 | `radius_m` | `INTEGER` | Radio alternativo al polígono |

**Widget:** `MAP_POLYGON_DRAWER` — El admin dibuja el perímetro en el mapa.
**Herramienta:** `flutter_map` + `PolygonLayer` + `Draw` plugin
**Licencia:** BSD/MIT · **Costo:** $0

```
menu_context: entity_type='geo_fence', context_key='geo.polygon.drawer', widget='MAP_POLYGON_DRAWER'
```

### 1.3 Dirección → coordenadas (geocoding)

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bauth.org_sucursal` | `direccion` | `TEXT` | "Av. Camacho 1234, La Paz" |
| `bauth.org_empresa` | — | — | Dirección fiscal |
| `bauth.fis_location` | `address` | `TEXT` | Dirección física |

**Widget:** `MAP_ADDRESS_SEARCH` — El admin escribe la dirección, el mapa sugiere y muestra el punto.
**Herramienta:** Nominatim (OpenStreetMap) — geocoding gratuito
**Licencia:** ODbL · **Costo:** $0 · **Rate limit:** 1 req/s

---

## 2. DATOS TEMPORALES (D4)

### 2.1 Fecha

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bcalendar.cal_holiday` | `holiday_date` | `DATE` | Fecha del feriado |
| `bcalendar.cal_fiscal_year` | `start_date`, `end_date` | `DATE` | Período fiscal |
| `bauth.aud_review` | `due_date` | `DATE` | Fecha límite de revisión |
| `bauth.idn_user_template` | `termination_date` | `DATE` | Fecha de baja |
| `bauth.org_pos_logico` | `fecha_limite_emision` | `DATE` | Límite dosificación SIN |
| `bauth.dlg_delegation` | `valid_from`, `valid_until` | `TIMESTAMPTZ` | Vigencia delegación |

**Widget:** `DATE_PICKER` — Selector de fecha con calendario visual.
**Herramienta:** Flutter `showDatePicker` (nativo, $0)
**Nota:** Para `TIMESTAMPTZ` se necesita `DATE_TIME_PICKER` (fecha + hora + zona horaria).

### 2.2 Hora / Horario

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bcalendar.cal_schedule` | `start_time`, `end_time` | `TIME` | Horario laboral |
| `bcalendar.cal_break_policy` 🆕 | `lunch_window_start`, `lunch_window_end` | `TIME` | Ventana de almuerzo |
| `bauth.org_sucursal` | `horario_apertura`, `horario_cierre` | `TIME` | Horario de sucursal |

**Widget:** `TIME_PICKER` — Selector de hora (HH:MM).
**Herramienta:** Flutter `showTimePicker` (nativo, $0)

### 2.3 Fecha + Hora + Zona horaria

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bcalendar.cal_event` | `dtstart`, `dtend` | `TIMESTAMPTZ` | Inicio/fin de evento |
| `bauth.idn_role_template` | `start_time`, `expiry_time` | `TIMESTAMPTZ` | Vigencia de rol |
| `bauth.ses_context` | `expires_at` | `TIMESTAMPTZ` | Expiración de sesión |
| `bauth.ses_superuser_context` | `expires_at` | `TIMESTAMPTZ` | Expiración break-glass |

**Widget:** `DATE_TIME_ZONE_PICKER` — Fecha + hora + selector de zona horaria IANA.
**Herramienta:** `flutter_native_timezone` + `showDatePicker` + `showTimePicker`
**Licencia:** MIT · **Costo:** $0

### 2.4 Recurrencia (RFC 5545)

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bcalendar.cal_event` | `rrule` | `TEXT` | Regla de recurrencia: `FREQ=WEEKLY;BYDAY=MO,WE,FR` |
| `bcalendar.cal_event` | `exdate` | `TIMESTAMPTZ[]` | Fechas excluidas |

**Widget:** `RECURRENCE_PICKER` — "Se repite cada... lunes, miércoles y viernes".
**Herramienta:** `rrule` Dart package — genera/parsea RFC 5545
**Licencia:** BSD · **Costo:** $0

```
menu_context: entity_type='cal_event', context_key='cal.recurrence.picker', widget='RECURRENCE_PICKER'
```

---

## 3. DATOS DE RED (D7)

### 3.1 IP / CIDR

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bauth.idn_tenant_network` | `network_cidr` | `TEXT` | CIDR autorizado |
| `bauth.idn_tenant_network` | `gateway` | `INET` | Gateway de red |
| `bauth.net_device` | `ip_address` | `INET` | IP del dispositivo |
| `bauth.net_device` | `mac_address` | `MACADDR` | MAC del dispositivo |
| `bauth.ses_context` | `device_ip` | `INET` | IP de la sesión |

**Widget:** `IP_CIDR_INPUT` — Campo con validación de formato IP/CIDR.
**Herramienta:** Flutter `TextFormField` + `validator` RegExp (nativo, $0)

---

## 4. DATOS BIOMÉTRICOS (D5)

### 4.1 Captura de huella / rostro / iris

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bauth.ath_mfa_enrollment` | `credential_id`, `public_key` | `TEXT` | WebAuthn credential |
| `bauth.ath_binding` | `authenticator_id` | `TEXT` | ID del authenticator |

**Widget:** `BIOMETRIC_ENROLLMENT` — Flujo de captura: escaneo → liveness → hash → storage.
**Herramienta:** `local_auth` Flutter (huella, Face ID nativo) + WebAuthn para Passkeys
**Licencia:** BSD · **Costo:** $0

**Nota:** El hash de la plantilla biométrica NUNCA pasa por el frontend. El sensor captura,
el hash se calcula en el dispositivo, y solo el hash viaja al backend. GDPR Art.9.

---

## 5. DATOS CRIPTOGRÁFICOS Y SEGURIDAD (SEC)

### 5.1 Certificados X.509

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bauth.net_device` | `certificate_serial` | `TEXT` | Serial del certificado del dispositivo |
| `bauth.org_pos_logico` | `cuis` | `TEXT` | CUIS SIN Bolivia |

**Widget:** `CERTIFICATE_UPLOAD` — Carga de archivo .pem/.crt con validación.
**Herramienta:** `file_picker` Flutter + `x509` Dart package
**Licencia:** MIT · **Costo:** $0

### 5.2 Firma digital

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bauth.idn_role_template` | `digital_signature` | (en JSONB template) | Firma EdDSA del RolTemplate |

**Widget:** `SIGNATURE_PAD` — El admin firma con trazo en pantalla o con smart card.
**Herramienta:** `signature` Flutter package
**Licencia:** MIT · **Costo:** $0

---

## 6. DATOS FINANCIEROS (D3)

### 6.1 Montos y monedas

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bauth.fin_limit` | `limits_config` | `JSONB` | Límites por período |
| `bauth.fin_decision_matrix` | `nivel_*_monto_max` | `NUMERIC(16,2)` | Montos máximos por nivel |
| `bauth.fin_transaction_type` | `controls` | `JSONB` | Controles por tipo |

**Widget:** `CURRENCY_INPUT` — Campo numérico con símbolo de moneda y formato local.
**Herramienta:** `intl` Flutter (NumberFormat) — nativo, $0

### 6.2 Dosificación SIN (Bolivia)

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bauth.org_pos_logico` | `rango_inicio`, `rango_fin` | `BIGINT` | Rango facturas autorizado |
| `bauth.org_pos_logico` | `numero_actual` | `BIGINT` | Contador actual |
| `bauth.org_pos_logico` | `numero_autorizacion` | `TEXT` | Autorización SIN |

**Widget:** `SIN_DOSIFICACION_FORM` — Formulario específico para datos de dosificación fiscal.
**Herramienta:** Flutter `Form` + validación de rangos (nativo, $0)
**Nota:** Este widget es específico de Bolivia. Debe ser un componente condicional basado en `tenant.country`.

---

## 7. DATOS DE IDENTIDAD (D9/USER)

### 7.1 Foto de perfil / Avatar

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bauth.idn_user_template` | — | (falta columna) | Foto del empleado |

**Widget:** `IMAGE_PICKER` — Cámara o galería, con recorte.
**Herramienta:** `image_picker` Flutter
**Licencia:** BSD · **Costo:** $0

### 7.2 Documento de identidad (escaneo)

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bauth.idn_user_template` | — | (falta columna) | Imagen del documento |

**Widget:** `DOCUMENT_SCANNER` — Escaneo de cédula/pasaporte con OCR.
**Herramienta:** `google_mlkit_document_scanner` Flutter
**Licencia:** Apache 2.0 · **Costo:** $0 (on-device)

---

## 8. DATOS DE CONFIGURACIÓN Y POLÍTICAS

### 8.1 Editor de JSONB

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| ~40 tablas | `config`, `template`, `metadata`, `controls`, `policy_data`, `limits_config`, `params`, `details` | `JSONB` | Políticas, configuraciones, templates |

**Widget:** `JSONB_EDITOR` — Editor visual de políticas con schema validation.
**Herramienta:** Flutter `JsonEditor` widget + JSON Schema validator
**Licencia:** MIT · **Costo:** $0

**Nota:** Este es el widget más transversal. Cada dominio tiene políticas en JSONB.
El editor debe validar contra el schema declarado en el `COMMENT ON` de la columna.

### 8.2 Editor de plantillas (JSONB estructurado)

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bauth.idn_role_template` | `template` | `JSONB` | Template de rol (14 secciones) |
| `bauth.idn_user_template` | `template` | `JSONB` | Template de usuario |

**Widget:** `TEMPLATE_BUILDER` — Construye el template sección por sección, dominio por dominio.
El admin selecciona políticas de cada `ath_policy_d*` y el sistema mergea.
**Herramienta:** Flutter `Form` dinámico + `menu_context` para opciones
**Licencia:** N/A (componente propio)

---

## 9. DATOS DE MENÚ Y NAVEGACIÓN

### 9.1 Jerarquía de menú

| Tabla | Columna | Tipo SQL | Uso |
|-------|---------|----------|-----|
| `bglobal.menu_item` | `parent_id`, `label`, `route`, `icon`, `sort_order` | Varios | Árbol de menú |

**Widget:** `MENU_TREE_EDITOR` — Drag & drop de ítems de menú, anidar, reordenar.
**Herramienta:** `flutter_treeview` o `ReorderableListView`
**Licencia:** MIT · **Costo:** $0

---

## 10. RESUMEN: HERRAMIENTAS REQUERIDAS

| # | Herramienta | Tipo | Paquete/Librería | Licencia | Costo | Dominios |
|---|-----------|------|-----------------|----------|:---:|------|
| 1 | **PostGIS** | Backend | Extensión PostgreSQL | GPL v2.0 | $0 | D6, D2 |
| 2 | **Flutter Map** | Frontend | `flutter_map` + OSM tiles | BSD/MIT | $0 | D6, D2, ORG |
| 3 | **Nominatim** | Backend | OpenStreetMap geocoding | ODbL | $0 | D6, ORG |
| 4 | **Date/Time Pickers** | Frontend | Flutter nativo `showDatePicker` | BSD | $0 | D4, D11, USER |
| 5 | **Recurrence Picker** | Frontend | `rrule` Dart | BSD | $0 | D4 |
| 6 | **Time Zone Picker** | Frontend | `flutter_native_timezone` | MIT | $0 | D4, D8, ORG |
| 7 | **Biometric Auth** | Frontend | `local_auth` Flutter | BSD | $0 | D5, D9 |
| 8 | **File/Cert Picker** | Frontend | `file_picker` Flutter | MIT | $0 | SEC, D7 |
| 9 | **Signature Pad** | Frontend | `signature` Flutter | MIT | $0 | D1, D3 |
| 10 | **Image/Document Scanner** | Frontend | `google_mlkit_document_scanner` | Apache 2.0 | $0 | USER |
| 11 | **JSONB Editor** | Frontend | Componente propio | N/A | $0 | TODOS |
| 12 | **Menu Tree Editor** | Frontend | `ReorderableListView` | MIT | $0 | GLOBAL |
| 13 | **IP/CIDR Validator** | Frontend | Flutter `TextFormField` regex | BSD | $0 | D7 |

**Costo total de herramientas externas: $0.**
**Todas son open source con licencias compatibles con SBOS.**
**Ninguna requiere API key de pago.**

---

## 11. ENFOQUE SISTÉMICO: menu_context COMO REGISTRO DE WIDGETS

Cada campo especial se registra en `bglobal.menu_context` con el widget que necesita:

```sql
-- Ejemplos de entradas menu_context para widgets de captura
INSERT INTO bglobal.menu_context (tenant_id, context_key, entity_type, widget_type, description) VALUES
('*', 'geo.point.picker',       'fis_location',      'MAP_POINT_PICKER',       'Selector de punto en mapa'),
('*', 'geo.polygon.drawer',     'geo_fence',          'MAP_POLYGON_DRAWER',     'Dibujar polígono de geo-cerca'),
('*', 'geo.address.search',     'org_sucursal',       'MAP_ADDRESS_SEARCH',     'Búsqueda de dirección → coordenadas'),
('*', 'cal.recurrence.picker',  'cal_event',          'RECURRENCE_PICKER',      'Selector de recurrencia RFC 5545'),
('*', 'cal.datetime.picker',    'cal_event',          'DATE_TIME_ZONE_PICKER',  'Selector fecha/hora/zona'),
('*', 'net.cidr.input',         'idn_tenant_network', 'IP_CIDR_INPUT',          'Input validado de IP/CIDR'),
('*', 'sec.cert.upload',        'net_device',         'CERTIFICATE_UPLOAD',     'Carga de certificado X.509'),
('*', 'fin.currency.input',     'fin_limit',          'CURRENCY_INPUT',         'Input de monto con formato de moneda'),
('*', 'user.photo.capture',     'idn_user_template',  'IMAGE_PICKER',           'Captura de foto de perfil'),
('*', 'user.document.scan',     'idn_user_template',  'DOCUMENT_SCANNER',       'Escaneo de documento de identidad'),
('*', 'jsonb.policy.editor',    'ath_policy_*',       'JSONB_EDITOR',           'Editor visual de políticas JSONB'),
('*', 'menu.tree.editor',       'menu_item',          'MENU_TREE_EDITOR',       'Editor drag-drop de árbol de menú');
```

**El Core UI consulta:** `SELECT widget_type FROM menu_context WHERE entity_type = '<tabla>'`.
**Resultado:** Sabe exactamente qué widget renderizar sin lógica hardcodeada.

---

*Documento generado 2026-06-24. 13 herramientas identificadas. $0 costo total. 12 widgets de captura.*
*Enfoque sistémico: menu_context como puente DDL ↔ UI para TODOS los tipos de dato especiales.*
