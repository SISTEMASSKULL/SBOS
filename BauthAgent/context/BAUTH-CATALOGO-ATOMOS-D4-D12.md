# BAUTH-CATALOGO-ATOMOS-D4-D12 — Catálogos CRUD Dominios D4 a D12
## bAuth Identity Core v3.0 · Diseño — NO IMPLEMENTADO, pendiente aprobación DDL

**Versión:** 1.0.0 · **Fecha:** 2026-07-01 · **Estado:** DISEÑO — DDL PENDIENTE

**Decisión:** CRUD completo por campo (C=CREATE, R=READ, U=UPDATE, D=DELETE) en todos los dominios.

**Posiciones:** Cada dominio tiene asignados hasta 484 átomos en `privilege_atom`.
Los átomos aquí definidos ocupan los primeros slots de cada rango de dominio.
Posiciones globales: D4(1453-1936), D5(1937-2420), D6(2421-2904), D7(2905-3388),
D8(3389-3872), D9(3873-4356), D10(4357-4840), D11(4841-5324), D12(5325-5808).

**Nomenclatura:** `DXX.{app}.{modulo}_{campo}.{VERBO}` — idéntica a D00.

---

## D4 — ACCESO FÍSICO (Physical Access)

**Bloque RolTemplate:** BLOQUE 4 — physical_access
**Tabla de política:** `ath_policy_d4`
**Estándares base:** ANSI/SIA AC-01-2010 · IEC 60839-11 · OSDP 2.2 (SIA) · ONVIF Profile A · ISO 22341:2021 (seguridad física) · NIST SP 800-116 Rev.1 (PACS)

### Aplicación: pacs (Physical Access Control System)

#### Campo: zone_access (acceso a zona física)

| Átomo | CRUD | Posición D4 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D4.pacs.zone_access.C` | CREATE | D4.001 | Crear regla de acceso a zona para el rol | ANSI/SIA AC-01 §4 |
| `D4.pacs.zone_access.R` | READ   | D4.002 | Ver qué zonas tiene acceso el rol | ANSI/SIA AC-01 §4 |
| `D4.pacs.zone_access.U` | UPDATE | D4.003 | Modificar nivel de acceso a zona | ANSI/SIA AC-01 §4 |
| `D4.pacs.zone_access.D` | DELETE | D4.004 | Revocar acceso a zona | ANSI/SIA AC-01 §4 |

> Valores: `zona_id` (UUID de zona) + `nivel` (1=lectores, 2=puertas, 3=ascensores, 4=salas seguras)

#### Campo: door_unlock (control de apertura de puertas)

| Átomo | CRUD | Posición D4 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D4.pacs.door_unlock.C` | CREATE | D4.005 | Asignar permiso de apertura de puerta | OSDP 2.2 §6.3 |
| `D4.pacs.door_unlock.R` | READ   | D4.006 | Ver permisos de apertura | OSDP 2.2 §6.3 |
| `D4.pacs.door_unlock.U` | UPDATE | D4.007 | Cambiar nivel de acceso a puerta | OSDP 2.2 §6.3 |
| `D4.pacs.door_unlock.D` | DELETE | D4.008 | Revocar permiso de puerta | OSDP 2.2 §6.3 |

#### Campo: floor_access (acceso por piso — ascensores)

| Átomo | CRUD | Posición D4 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D4.pacs.floor_access.C` | CREATE | D4.009 | Asignar pisos accesibles | IEC 60839-11 §8 |
| `D4.pacs.floor_access.R` | READ   | D4.010 | Ver pisos accesibles | IEC 60839-11 §8 |
| `D4.pacs.floor_access.U` | UPDATE | D4.011 | Cambiar pisos | IEC 60839-11 §8 |
| `D4.pacs.floor_access.D` | DELETE | D4.012 | Revocar acceso a piso | IEC 60839-11 §8 |

#### Campo: schedule_override (sobrescribir horario de acceso físico)

| Átomo | CRUD | Posición D4 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D4.pacs.schedule_override.C` | CREATE | D4.013 | Crear excepción de horario físico | NIST SP 800-116 Rev.1 §4.3 |
| `D4.pacs.schedule_override.R` | READ   | D4.014 | Ver excepciones de horario | NIST SP 800-116 Rev.1 §4.3 |
| `D4.pacs.schedule_override.U` | UPDATE | D4.015 | Modificar excepción | NIST SP 800-116 Rev.1 §4.3 |
| `D4.pacs.schedule_override.D` | DELETE | D4.016 | Eliminar excepción | NIST SP 800-116 Rev.1 §4.3 |

#### Campo: visitor_escort (acompañamiento de visitantes)

| Átomo | CRUD | Posición D4 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D4.pacs.visitor_escort.C` | CREATE | D4.017 | Habilitar escolta de visitantes para el rol | ISO 22341:2021 §6.4 |
| `D4.pacs.visitor_escort.R` | READ   | D4.018 | Ver capacidad de escolta | ISO 22341:2021 §6.4 |
| `D4.pacs.visitor_escort.U` | UPDATE | D4.019 | Modificar permisos de escolta | ISO 22341:2021 §6.4 |
| `D4.pacs.visitor_escort.D` | DELETE | D4.020 | Deshabilitar escolta | ISO 22341:2021 §6.4 |

#### Campo: anti_passback_exempt (exención de anti-passback)

| Átomo | CRUD | Posición D4 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D4.pacs.anti_passback_exempt.C` | CREATE | D4.021 | Otorgar exención de anti-passback | ANSI/SIA AC-01 §7.2 |
| `D4.pacs.anti_passback_exempt.R` | READ   | D4.022 | Ver si el rol tiene exención | ANSI/SIA AC-01 §7.2 |
| `D4.pacs.anti_passback_exempt.U` | UPDATE | D4.023 | Modificar exención | ANSI/SIA AC-01 §7.2 |
| `D4.pacs.anti_passback_exempt.D` | DELETE | D4.024 | Revocar exención | ANSI/SIA AC-01 §7.2 |

#### Campo: camera_view (ver cámaras ONVIF)

| Átomo | CRUD | Posición D4 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D4.pacs.camera_view.C` | CREATE | D4.025 | Asignar acceso a cámara | ONVIF Profile A §5 |
| `D4.pacs.camera_view.R` | READ   | D4.026 | Ver video en tiempo real | ONVIF Profile A §5 |
| `D4.pacs.camera_view.U` | UPDATE | D4.027 | Cambiar asignación de cámaras | ONVIF Profile A §5 |
| `D4.pacs.camera_view.D` | DELETE | D4.028 | Revocar acceso a cámara | ONVIF Profile A §5 |

**Total D4: 7 campos × 4 = 28 átomos (D4.001–D4.028)**

---

## D5 — DISPOSITIVOS (Devices)

**Bloque RolTemplate:** BLOQUE 7 — biometric / devices (compartido)
**Bloque UserTemplate:** BLOQUE 5 — devices
**Tabla de política:** `ath_device_registration` + `ath_policy_d5`
**Estándares base:** FIDO2 W3C (2021) · CTAP 2.2 · IEEE 802.1X-2020 · NIST SP 800-124 Rev.2 (MDM) · NIST SP 800-63B §6.1 · ISO/IEC 27001:2022 A.8.1

### Aplicación: device (gestión de dispositivos)

#### Campo: device_register (registro de dispositivos)

| Átomo | CRUD | Posición D5 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D5.device.device_register.C` | CREATE | D5.001 | Registrar nuevo dispositivo al rol/usuario | FIDO2 W3C §4 · NIST SP 800-63B §6.1.3 |
| `D5.device.device_register.R` | READ   | D5.002 | Ver dispositivos registrados | FIDO2 W3C §4 |
| `D5.device.device_register.U` | UPDATE | D5.003 | Actualizar metadatos de dispositivo | FIDO2 W3C §4 |
| `D5.device.device_register.D` | DELETE | D5.004 | Desregistrar / revocar dispositivo | FIDO2 W3C §5 |

#### Campo: device_trust_level (nivel de confianza del dispositivo)

| Átomo | CRUD | Posición D5 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D5.device.device_trust_level.C` | CREATE | D5.005 | Asignar nivel de confianza | NIST SP 800-124 Rev.2 §4.1 |
| `D5.device.device_trust_level.R` | READ   | D5.006 | Ver nivel de confianza | NIST SP 800-124 Rev.2 §4.1 |
| `D5.device.device_trust_level.U` | UPDATE | D5.007 | Cambiar nivel (0=desconocido/1=gestionado/2=corporativo) | NIST SP 800-124 Rev.2 §4.1 |
| `D5.device.device_trust_level.D` | DELETE | D5.008 | Reset a nivel 0 (desconocido) | NIST SP 800-124 Rev.2 §4.1 |

#### Campo: device_remote_wipe (borrado remoto)

| Átomo | CRUD | Posición D5 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D5.device.device_remote_wipe.C` | CREATE | D5.009 | Crear orden de borrado remoto | NIST SP 800-124 Rev.2 §5.4 |
| `D5.device.device_remote_wipe.R` | READ   | D5.010 | Ver estado de orden de borrado | NIST SP 800-124 Rev.2 §5.4 |
| `D5.device.device_remote_wipe.U` | UPDATE | D5.011 | Modificar parámetros de borrado | NIST SP 800-124 Rev.2 §5.4 |
| `D5.device.device_remote_wipe.D` | DELETE | D5.012 | Cancelar orden de borrado | NIST SP 800-124 Rev.2 §5.4 |

#### Campo: device_policy (políticas de dispositivo — MDM)

| Átomo | CRUD | Posición D5 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D5.device.device_policy.C` | CREATE | D5.013 | Asignar política MDM a dispositivo | IEEE 802.1X-2020 §8 |
| `D5.device.device_policy.R` | READ   | D5.014 | Ver política MDM asignada | IEEE 802.1X-2020 §8 |
| `D5.device.device_policy.U` | UPDATE | D5.015 | Cambiar política MDM | IEEE 802.1X-2020 §8 |
| `D5.device.device_policy.D` | DELETE | D5.016 | Revocar política MDM | IEEE 802.1X-2020 §8 |

#### Campo: jailbreak_block (bloqueo de dispositivos comprometidos)

| Átomo | CRUD | Posición D5 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D5.device.jailbreak_block.C` | CREATE | D5.017 | Activar bloqueo por jailbreak/root | NIST SP 800-124 Rev.2 §4.3 |
| `D5.device.jailbreak_block.R` | READ   | D5.018 | Ver estado de bloqueo | NIST SP 800-124 Rev.2 §4.3 |
| `D5.device.jailbreak_block.U` | UPDATE | D5.019 | Modificar umbral de detección | NIST SP 800-124 Rev.2 §4.3 |
| `D5.device.jailbreak_block.D` | DELETE | D5.020 | Deshabilitar bloqueo (excepción justificada) | NIST SP 800-124 Rev.2 §4.3 |

**Total D5: 5 campos × 4 = 20 átomos (D5.001–D5.020)**

---

## D6 — GEOESPACIAL (Geospatial)

**Bloque RolTemplate:** BLOQUE 8 — geospatial
**Bloque UserTemplate:** BLOQUE 7 — location
**Tabla de política:** `ath_policy_d6`
**Estándares base:** ISO 6709:2022 (posiciones geográficas) · WGS84 (EPSG:4326) · GDPR Art. 9 §1 (datos de localización) · OGC GeoJSON (RFC 7946) · NIST SP 800-207 §3.2 (Zero Trust geolocalización)

### Aplicación: geo (control geoespacial)

#### Campo: location_required (ubicación obligatoria para el rol)

| Átomo | CRUD | Posición D6 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D6.geo.location_required.C` | CREATE | D6.001 | Requerir ubicación para acceso del rol | NIST SP 800-207 §3.2 |
| `D6.geo.location_required.R` | READ   | D6.002 | Ver si el rol requiere ubicación | NIST SP 800-207 §3.2 |
| `D6.geo.location_required.U` | UPDATE | D6.003 | Cambiar requisito de ubicación | NIST SP 800-207 §3.2 |
| `D6.geo.location_required.D` | DELETE | D6.004 | Deshabilitar requisito de ubicación | NIST SP 800-207 §3.2 |

#### Campo: geofence_zone (zona geográfica permitida)

| Átomo | CRUD | Posición D6 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D6.geo.geofence_zone.C` | CREATE | D6.005 | Definir geofence (polígono WGS84 GeoJSON) | ISO 6709:2022 · RFC 7946 |
| `D6.geo.geofence_zone.R` | READ   | D6.006 | Ver geofences asignadas al rol | ISO 6709:2022 |
| `D6.geo.geofence_zone.U` | UPDATE | D6.007 | Modificar perímetro geográfico | ISO 6709:2022 |
| `D6.geo.geofence_zone.D` | DELETE | D6.008 | Eliminar geofence | ISO 6709:2022 |

#### Campo: country_restrict (restricción por país)

| Átomo | CRUD | Posición D6 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D6.geo.country_restrict.C` | CREATE | D6.009 | Definir países permitidos (ISO 3166-1 alpha-2) | GDPR Art. 44 · ISO 3166-1 |
| `D6.geo.country_restrict.R` | READ   | D6.010 | Ver restricciones de país | GDPR Art. 44 |
| `D6.geo.country_restrict.U` | UPDATE | D6.011 | Cambiar lista de países permitidos | GDPR Art. 44 |
| `D6.geo.country_restrict.D` | DELETE | D6.012 | Quitar restricción de país | GDPR Art. 44 |

#### Campo: location_precision (precisión mínima de GPS)

| Átomo | CRUD | Posición D6 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D6.geo.location_precision.C` | CREATE | D6.013 | Definir precisión mínima en metros | ISO 6709:2022 §5 |
| `D6.geo.location_precision.R` | READ   | D6.014 | Ver precisión requerida | ISO 6709:2022 §5 |
| `D6.geo.location_precision.U` | UPDATE | D6.015 | Cambiar precisión mínima | ISO 6709:2022 §5 |
| `D6.geo.location_precision.D` | DELETE | D6.016 | Eliminar restricción de precisión | ISO 6709:2022 §5 |

**Total D6: 4 campos × 4 = 16 átomos (D6.001–D6.016)**

---

## D7 — FINANCIERO (Financial)

**Bloque RolTemplate:** BLOQUE 5 — financial
**Tabla de política:** `ath_policy_d7`
**Estándares base:** PCI DSS 4.0 Req.7/8 · ISO 20022:2023 (mensajería financiera) · SIN Bolivia RND 10-0025-15 (facturación electrónica) · NIST SP 800-53 AU-9 (control de transacciones) · ISO 27001:2022 A.5.15 · Ley 393 Bolivia (servicios financieros)

### Aplicación: fin (control financiero)

#### Campo: amount_max_daily (límite diario de monto)

| Átomo | CRUD | Posición D7 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D7.fin.amount_max_daily.C` | CREATE | D7.001 | Definir límite diario acumulado | PCI DSS 4.0 Req.7.2 · Ley 393 Art.59 |
| `D7.fin.amount_max_daily.R` | READ   | D7.002 | Ver límite diario del rol | PCI DSS 4.0 Req.7.2 |
| `D7.fin.amount_max_daily.U` | UPDATE | D7.003 | Cambiar límite diario | PCI DSS 4.0 Req.7.2 |
| `D7.fin.amount_max_daily.D` | DELETE | D7.004 | Eliminar límite (sin restricción) | PCI DSS 4.0 Req.7.2 |

> Valor en moneda base del tenant (ISO 4217). Ej: BOB 50000, USD 10000.

#### Campo: amount_max_single (límite por transacción única)

| Átomo | CRUD | Posición D7 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D7.fin.amount_max_single.C` | CREATE | D7.005 | Definir límite por transacción única | PCI DSS 4.0 Req.8.6 |
| `D7.fin.amount_max_single.R` | READ   | D7.006 | Ver límite por transacción | PCI DSS 4.0 Req.8.6 |
| `D7.fin.amount_max_single.U` | UPDATE | D7.007 | Cambiar límite por transacción | PCI DSS 4.0 Req.8.6 |
| `D7.fin.amount_max_single.D` | DELETE | D7.008 | Eliminar límite por transacción | PCI DSS 4.0 Req.8.6 |

#### Campo: currency_allowed (monedas permitidas)

| Átomo | CRUD | Posición D7 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D7.fin.currency_allowed.C` | CREATE | D7.009 | Definir monedas autorizadas (ISO 4217) | ISO 4217:2015 · ISO 20022 |
| `D7.fin.currency_allowed.R` | READ   | D7.010 | Ver monedas autorizadas | ISO 4217:2015 |
| `D7.fin.currency_allowed.U` | UPDATE | D7.011 | Cambiar lista de monedas | ISO 4217:2015 |
| `D7.fin.currency_allowed.D` | DELETE | D7.012 | Revocar moneda de la lista | ISO 4217:2015 |

#### Campo: approval_required (aprobación requerida sobre monto umbral)

| Átomo | CRUD | Posición D7 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D7.fin.approval_required.C` | CREATE | D7.013 | Definir umbral que requiere aprobación | ISO 20022 · PCI DSS 4.0 Req.7 |
| `D7.fin.approval_required.R` | READ   | D7.014 | Ver umbral de aprobación | ISO 20022 |
| `D7.fin.approval_required.U` | UPDATE | D7.015 | Cambiar umbral | ISO 20022 |
| `D7.fin.approval_required.D` | DELETE | D7.016 | Deshabilitar aprobación obligatoria | ISO 20022 |

#### Campo: invoice_emit (emitir facturas SIN)

| Átomo | CRUD | Posición D7 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D7.fin.invoice_emit.C` | CREATE | D7.017 | Habilitar emisión de facturas electrónicas | SIN Bolivia RND 10-0025-15 |
| `D7.fin.invoice_emit.R` | READ   | D7.018 | Ver facturas emitidas | SIN Bolivia RND 10-0025-15 |
| `D7.fin.invoice_emit.U` | UPDATE | D7.019 | Anular/modificar factura (dentro de ventana) | SIN Bolivia RND 10-0025-15 |
| `D7.fin.invoice_emit.D` | DELETE | D7.020 | Revocar capacidad de emisión | SIN Bolivia RND 10-0025-15 |

#### Campo: cashout_limit (límite de retiro de efectivo)

| Átomo | CRUD | Posición D7 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D7.fin.cashout_limit.C` | CREATE | D7.021 | Definir límite de retiro | Ley 393 Bolivia Art.61 · PCI DSS |
| `D7.fin.cashout_limit.R` | READ   | D7.022 | Ver límite de retiro | Ley 393 Bolivia |
| `D7.fin.cashout_limit.U` | UPDATE | D7.023 | Cambiar límite de retiro | Ley 393 Bolivia |
| `D7.fin.cashout_limit.D` | DELETE | D7.024 | Eliminar límite de retiro | Ley 393 Bolivia |

**Total D7: 6 campos × 4 = 24 átomos (D7.001–D7.024)**

---

## D8 — TEMPORAL (Temporal / Schedules)

**Bloque RolTemplate:** BLOQUE 6 — temporal
**Bloque UserTemplate:** BLOQUE 8 — temporal
**Tabla de política:** `ath_policy_d8` + `bcalendar.cal_schedule`
**Estándares base:** RFC 5545 (iCalendar) · ISO 8601:2019 (fechas y duraciones) · NIST SP 800-63B §4.3 (tiempo de sesión) · ISO 27001:2022 A.8.3 (acceso temporal limitado)

### Aplicación: cal (control temporal)

#### Campo: schedule_hours (horario diario de acceso)

| Átomo | CRUD | Posición D8 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D8.cal.schedule_hours.C` | CREATE | D8.001 | Definir ventanas horarias de acceso (HH:MM–HH:MM) | RFC 5545 DTSTART/DTEND |
| `D8.cal.schedule_hours.R` | READ   | D8.002 | Ver horarios de acceso del rol | RFC 5545 |
| `D8.cal.schedule_hours.U` | UPDATE | D8.003 | Modificar ventanas horarias | RFC 5545 |
| `D8.cal.schedule_hours.D` | DELETE | D8.004 | Eliminar restricción horaria (24/7) | RFC 5545 |

> Formato: `{ "start": "08:00", "end": "18:00", "tz": "America/La_Paz" }`

#### Campo: schedule_days (días de la semana permitidos)

| Átomo | CRUD | Posición D8 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D8.cal.schedule_days.C` | CREATE | D8.005 | Definir días de acceso (BYDAY iCalendar) | RFC 5545 BYDAY |
| `D8.cal.schedule_days.R` | READ   | D8.006 | Ver días permitidos | RFC 5545 BYDAY |
| `D8.cal.schedule_days.U` | UPDATE | D8.007 | Cambiar días permitidos | RFC 5545 BYDAY |
| `D8.cal.schedule_days.D` | DELETE | D8.008 | Eliminar restricción de días | RFC 5545 BYDAY |

> Valores: MO/TU/WE/TH/FR/SA/SU (RFC 5545 BYDAY). Ej: `["MO","TU","WE","TH","FR"]`

#### Campo: valid_from (fecha de inicio de vigencia del rol)

| Átomo | CRUD | Posición D8 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D8.cal.valid_from.C` | CREATE | D8.009 | Definir fecha de inicio de vigencia | ISO 8601:2019 |
| `D8.cal.valid_from.R` | READ   | D8.010 | Ver fecha de inicio | ISO 8601:2019 |
| `D8.cal.valid_from.U` | UPDATE | D8.011 | Modificar fecha de inicio | ISO 8601:2019 |
| `D8.cal.valid_from.D` | DELETE | D8.012 | Quitar restricción de fecha inicio | ISO 8601:2019 |

#### Campo: valid_until (fecha de expiración del rol)

| Átomo | CRUD | Posición D8 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D8.cal.valid_until.C` | CREATE | D8.013 | Definir fecha de expiración del rol | ISO 8601:2019 · ISO 27001 A.8.3 |
| `D8.cal.valid_until.R` | READ   | D8.014 | Ver fecha de expiración | ISO 8601:2019 |
| `D8.cal.valid_until.U` | UPDATE | D8.015 | Cambiar fecha de expiración | ISO 8601:2019 |
| `D8.cal.valid_until.D` | DELETE | D8.016 | Quitar expiración (rol permanente) | ISO 8601:2019 |

#### Campo: session_max_duration (duración máxima de sesión)

| Átomo | CRUD | Posición D8 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D8.cal.session_max_duration.C` | CREATE | D8.017 | Definir duración máxima de sesión (ISO 8601 PT) | NIST SP 800-63B §4.3.3 |
| `D8.cal.session_max_duration.R` | READ   | D8.018 | Ver duración máxima de sesión | NIST SP 800-63B §4.3.3 |
| `D8.cal.session_max_duration.U` | UPDATE | D8.019 | Cambiar duración máxima | NIST SP 800-63B §4.3.3 |
| `D8.cal.session_max_duration.D` | DELETE | D8.020 | Usar duración por defecto del sistema | NIST SP 800-63B §4.3.3 |

> Formato ISO 8601 duración: `PT8H` (8 horas), `PT30M` (30 minutos)

#### Campo: holiday_access (acceso en días festivos)

| Átomo | CRUD | Posición D8 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D8.cal.holiday_access.C` | CREATE | D8.021 | Definir política de acceso en festivos | bcalendar.cal_schedule · RFC 5545 EXDATE |
| `D8.cal.holiday_access.R` | READ   | D8.022 | Ver política de festivos | bcalendar.cal_schedule |
| `D8.cal.holiday_access.U` | UPDATE | D8.023 | Cambiar política de festivos | bcalendar.cal_schedule |
| `D8.cal.holiday_access.D` | DELETE | D8.024 | Usar política por defecto del sistema | bcalendar.cal_schedule |

**Total D8: 6 campos × 4 = 24 átomos (D8.001–D8.024)**

---

## D9 — RED / NETWORK (Network Security)

**Bloque RolTemplate:** BLOQUE 10 — network
**Bloque UserTemplate:** BLOQUE 9 — network
**Tabla de política:** `ath_policy_d9`
**Estándares base:** RFC 4632 (CIDR) · RFC 6890 (rangos especiales) · IANA Protocol Numbers · NIST SP 800-41 Rev.1 (firewalls) · NIST SP 800-207 §2.1 (Zero Trust redes) · CIS Benchmark Ubuntu 22.04 §3

### Aplicación: net (control de red)

#### Campo: ip_whitelist (IPs permitidas)

| Átomo | CRUD | Posición D9 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D9.net.ip_whitelist.C` | CREATE | D9.001 | Agregar IP/CIDR a lista blanca del rol | RFC 4632 · NIST SP 800-207 §2.1 |
| `D9.net.ip_whitelist.R` | READ   | D9.002 | Ver IPs permitidas | RFC 4632 |
| `D9.net.ip_whitelist.U` | UPDATE | D9.003 | Modificar rangos permitidos | RFC 4632 |
| `D9.net.ip_whitelist.D` | DELETE | D9.004 | Eliminar entrada de whitelist | RFC 4632 |

> Formato: CIDR notation. Ej: `["192.168.1.0/24", "10.0.0.1/32"]`. IPv4 e IPv6.

#### Campo: country_ip_allow (países permitidos por GeoIP)

| Átomo | CRUD | Posición D9 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D9.net.country_ip_allow.C` | CREATE | D9.005 | Definir países permitidos por IP (ISO 3166-1) | NIST SP 800-207 §3 |
| `D9.net.country_ip_allow.R` | READ   | D9.006 | Ver países permitidos | NIST SP 800-207 |
| `D9.net.country_ip_allow.U` | UPDATE | D9.007 | Cambiar lista de países | NIST SP 800-207 |
| `D9.net.country_ip_allow.D` | DELETE | D9.008 | Deshabilitar restricción geográfica de IP | NIST SP 800-207 |

#### Campo: vpn_required (VPN obligatoria)

| Átomo | CRUD | Posición D9 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D9.net.vpn_required.C` | CREATE | D9.009 | Requerir conexión VPN para el rol | NIST SP 800-77 Rev.1 (IPsec VPN) |
| `D9.net.vpn_required.R` | READ   | D9.010 | Ver si VPN es requerida | NIST SP 800-77 |
| `D9.net.vpn_required.U` | UPDATE | D9.011 | Cambiar requisito de VPN | NIST SP 800-77 |
| `D9.net.vpn_required.D` | DELETE | D9.012 | Deshabilitar requisito de VPN | NIST SP 800-77 |

#### Campo: tls_min_version (versión mínima TLS)

| Átomo | CRUD | Posición D9 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D9.net.tls_min_version.C` | CREATE | D9.013 | Definir versión TLS mínima para el rol | NIST SP 800-52 Rev.2 · RFC 8446 (TLS 1.3) |
| `D9.net.tls_min_version.R` | READ   | D9.014 | Ver versión TLS mínima | NIST SP 800-52 |
| `D9.net.tls_min_version.U` | UPDATE | D9.015 | Cambiar versión TLS mínima | NIST SP 800-52 |
| `D9.net.tls_min_version.D` | DELETE | D9.016 | Usar versión por defecto del sistema (TLS 1.3) | NIST SP 800-52 |

> Valores válidos: `TLS_1_2` / `TLS_1_3`. El sistema usa TLS 1.3 por defecto.

#### Campo: mtls_required (mTLS obligatorio)

| Átomo | CRUD | Posición D9 | Descripción | Estándar |
|-------|:----:|:-----------:|-------------|---------|
| `D9.net.mtls_required.C` | CREATE | D9.017 | Requerir mTLS (certificado cliente) | RFC 8705 (OAuth 2.0 mTLS) · NIST SP 800-207 |
| `D9.net.mtls_required.R` | READ   | D9.018 | Ver si mTLS es requerido | RFC 8705 |
| `D9.net.mtls_required.U` | UPDATE | D9.019 | Cambiar requisito mTLS | RFC 8705 |
| `D9.net.mtls_required.D` | DELETE | D9.020 | Deshabilitar mTLS obligatorio | RFC 8705 |

**Total D9: 5 campos × 4 = 20 átomos (D9.001–D9.020)**

---

## D10 — AUDITORÍA (Audit)

**Bloque RolTemplate:** BLOQUE 11 — audit
**Bloque UserTemplate:** BLOQUE 10 — audit
**Tabla:** `audit_event` (append-only, inmutable)
**Estándares base:** ISO 27001:2022 A.8.15 · NIST SP 800-53 AU-2/AU-9 · PCI DSS 4.0 Req.10 · SOC 2 CC7.2

> **Principio D10:** Los registros de auditoría son INMUTABLES (append-only).
> Los átomos D10 controlan QUIÉN PUEDE VER registros de auditoría, no modificarlos.
> El atom DELETE en D10 = capacidad de archivar/exportar, NUNCA borrar registros.

### Aplicación: audit (acceso a registros de auditoría)

#### Campo: audit_view_own (ver propios registros de auditoría)

| Átomo | CRUD | Posición D10 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D10.audit.audit_view_own.C` | CREATE | D10.001 | N/A — insert es automático del sistema | ISO 27001 A.8.15 |
| `D10.audit.audit_view_own.R` | READ   | D10.002 | Ver los propios registros de auditoría | ISO 27001 A.8.15 · GDPR Art. 15 |
| `D10.audit.audit_view_own.U` | UPDATE | D10.003 | N/A — inmutable | ISO 27001 A.8.15 |
| `D10.audit.audit_view_own.D` | DELETE | D10.004 | Exportar propios registros (GDPR portabilidad) | GDPR Art. 20 |

#### Campo: audit_view_tenant (ver auditoría del tenant completo)

| Átomo | CRUD | Posición D10 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D10.audit.audit_view_tenant.C` | CREATE | D10.005 | N/A | ISO 27001 A.8.15 |
| `D10.audit.audit_view_tenant.R` | READ   | D10.006 | Ver auditoría completa del tenant | PCI DSS 4.0 Req.10.1 · SOC 2 CC7.2 |
| `D10.audit.audit_view_tenant.U` | UPDATE | D10.007 | N/A — inmutable | — |
| `D10.audit.audit_view_tenant.D` | DELETE | D10.008 | Exportar/archivar auditoría del tenant | ISO 27001 A.8.15 |

#### Campo: audit_export (exportar registros para SIEM/compliance)

| Átomo | CRUD | Posición D10 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D10.audit.audit_export.C` | CREATE | D10.009 | Crear job de exportación | NIST SP 800-53 AU-9 |
| `D10.audit.audit_export.R` | READ   | D10.010 | Ver estado de exportaciones | NIST SP 800-53 AU-9 |
| `D10.audit.audit_export.U` | UPDATE | D10.011 | Modificar parámetros de exportación | NIST SP 800-53 AU-9 |
| `D10.audit.audit_export.D` | DELETE | D10.012 | Cancelar job de exportación | NIST SP 800-53 AU-9 |

**Total D10: 3 campos × 4 = 12 átomos (D10.001–D10.012)**

---

## D11 — BIOMÉTRICO (Biometric)

**Bloque RolTemplate:** BLOQUE 7 — biometric
**Tabla de política:** `ath_policy_d11`
**Estándares base:** ISO/IEC 19794-1:2011 (formatos biométricos) · ISO/IEC 30107-3:2023 (liveness detection PAD) · NIST SP 800-76-2 (biometría HSPD-12) · NIST SP 800-63B §5.1 (biometría como factor) · IEEE 2410-2021 (biometría en sistemas de autenticación)

### Aplicación: bio (control biométrico)

#### Campo: biometric_required (biometría obligatoria)

| Átomo | CRUD | Posición D11 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D11.bio.biometric_required.C` | CREATE | D11.001 | Requerir biometría para el rol | NIST SP 800-63B §5.1.7 |
| `D11.bio.biometric_required.R` | READ   | D11.002 | Ver si biometría es requerida | NIST SP 800-63B §5.1.7 |
| `D11.bio.biometric_required.U` | UPDATE | D11.003 | Cambiar requisito | NIST SP 800-63B §5.1.7 |
| `D11.bio.biometric_required.D` | DELETE | D11.004 | Deshabilitar requisito biométrico | NIST SP 800-63B §5.1.7 |

#### Campo: biometric_type (tipo de biometría aceptada)

| Átomo | CRUD | Posición D11 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D11.bio.biometric_type.C` | CREATE | D11.005 | Definir tipos biométricos aceptados | ISO/IEC 19794-1 · ISO/IEC 7816-11 |
| `D11.bio.biometric_type.R` | READ   | D11.006 | Ver tipos biométricos del rol | ISO/IEC 19794-1 |
| `D11.bio.biometric_type.U` | UPDATE | D11.007 | Cambiar tipos aceptados | ISO/IEC 19794-1 |
| `D11.bio.biometric_type.D` | DELETE | D11.008 | Revocar tipo biométrico | ISO/IEC 19794-1 |

> Valores: `FINGERPRINT` / `FACE` / `IRIS` / `VOICE` / `PALM_VEIN` / `RETINA`

#### Campo: liveness_required (detección de vida obligatoria)

| Átomo | CRUD | Posición D11 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D11.bio.liveness_required.C` | CREATE | D11.009 | Requerir liveness detection (anti-spoofing) | ISO/IEC 30107-3:2023 (PAD Level 2) |
| `D11.bio.liveness_required.R` | READ   | D11.010 | Ver si liveness es requerido | ISO/IEC 30107-3:2023 |
| `D11.bio.liveness_required.U` | UPDATE | D11.011 | Cambiar nivel de liveness (PAD Level 1/2/3) | ISO/IEC 30107-3:2023 |
| `D11.bio.liveness_required.D` | DELETE | D11.012 | Deshabilitar requisito de liveness | ISO/IEC 30107-3:2023 |

#### Campo: match_threshold (umbral de coincidencia biométrica)

| Átomo | CRUD | Posición D11 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D11.bio.match_threshold.C` | CREATE | D11.013 | Definir FMR/FNMR umbrales de aceptación | NIST SP 800-76-2 §3.3 |
| `D11.bio.match_threshold.R` | READ   | D11.014 | Ver umbrales configurados | NIST SP 800-76-2 §3.3 |
| `D11.bio.match_threshold.U` | UPDATE | D11.015 | Cambiar umbrales de precisión | NIST SP 800-76-2 §3.3 |
| `D11.bio.match_threshold.D` | DELETE | D11.016 | Usar umbrales por defecto del sistema | NIST SP 800-76-2 §3.3 |

> FMR = False Match Rate (tasa de falsos positivos). FNMR = False Non-Match Rate (falsos negativos).

**Total D11: 4 campos × 4 = 16 átomos (D11.001–D11.016)**

---

## D12 — DELEGACIÓN Y CUMPLIMIENTO (Delegation & Compliance)

**Bloque RolTemplate:** BLOQUE 12 blockchain / BLOQUE 13 security / BLOQUE 14 compliance (D12 cubre los 3)
**Bloque UserTemplate:** BLOQUE 12 — compliance
**Tabla de política:** `ath_policy_d12`
**Estándares base:** OAuth 2.0 Token Exchange RFC 8693 (delegación) · GDPR Arts. 6/7/17/20 · ISO 27001:2022 A.5.19-23 · SOC 2 CC1.1-CC9 · NIST SP 800-53 Rev.5 SA-9/PM-12 · ISO 29101:2018 (privacy framework)

### Aplicación: delegate (control de delegación)

#### Campo: delegate_permission (delegar permisos a otro rol)

| Átomo | CRUD | Posición D12 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D12.delegate.delegate_permission.C` | CREATE | D12.001 | Crear delegación de permisos (RFC 8693 token exchange) | OAuth 2.0 RFC 8693 §2.1 |
| `D12.delegate.delegate_permission.R` | READ   | D12.002 | Ver delegaciones activas | OAuth 2.0 RFC 8693 |
| `D12.delegate.delegate_permission.U` | UPDATE | D12.003 | Modificar alcance de delegación | OAuth 2.0 RFC 8693 |
| `D12.delegate.delegate_permission.D` | DELETE | D12.004 | Revocar delegación | OAuth 2.0 RFC 8693 §2.2 |

#### Campo: delegate_max_depth (profundidad máxima de delegación)

| Átomo | CRUD | Posición D12 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D12.delegate.delegate_max_depth.C` | CREATE | D12.005 | Definir máxima profundidad de re-delegación | ISO 27001 A.5.19 |
| `D12.delegate.delegate_max_depth.R` | READ   | D12.006 | Ver profundidad máxima | ISO 27001 A.5.19 |
| `D12.delegate.delegate_max_depth.U` | UPDATE | D12.007 | Cambiar profundidad máxima | ISO 27001 A.5.19 |
| `D12.delegate.delegate_max_depth.D` | DELETE | D12.008 | Deshabilitar re-delegación (depth=0) | ISO 27001 A.5.19 |

### Aplicación: gdpr (control de cumplimiento GDPR)

#### Campo: consent_manage (gestión de consentimientos)

| Átomo | CRUD | Posición D12 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D12.gdpr.consent_manage.C` | CREATE | D12.009 | Registrar nuevo consentimiento | GDPR Art. 6/7 · ISO 29101:2018 |
| `D12.gdpr.consent_manage.R` | READ   | D12.010 | Ver consentimientos activos del usuario | GDPR Art. 15 |
| `D12.gdpr.consent_manage.U` | UPDATE | D12.011 | Actualizar/renovar consentimiento | GDPR Art. 7 §3 |
| `D12.gdpr.consent_manage.D` | DELETE | D12.012 | Revocar consentimiento (right to withdraw) | GDPR Art. 7 §3 |

#### Campo: data_portability (portabilidad de datos)

| Átomo | CRUD | Posición D12 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D12.gdpr.data_portability.C` | CREATE | D12.013 | Crear solicitud de exportación de datos | GDPR Art. 20 |
| `D12.gdpr.data_portability.R` | READ   | D12.014 | Ver estado de solicitudes de portabilidad | GDPR Art. 20 |
| `D12.gdpr.data_portability.U` | UPDATE | D12.015 | Actualizar formato de exportación | GDPR Art. 20 |
| `D12.gdpr.data_portability.D` | DELETE | D12.016 | Cancelar solicitud de exportación | GDPR Art. 20 |

#### Campo: right_to_forget (derecho al olvido)

| Átomo | CRUD | Posición D12 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D12.gdpr.right_to_forget.C` | CREATE | D12.017 | Crear solicitud de eliminación de datos | GDPR Art. 17 |
| `D12.gdpr.right_to_forget.R` | READ   | D12.018 | Ver solicitudes de eliminación | GDPR Art. 17 |
| `D12.gdpr.right_to_forget.U` | UPDATE | D12.019 | Actualizar alcance de la solicitud | GDPR Art. 17 |
| `D12.gdpr.right_to_forget.D` | DELETE | D12.020 | Revocar solicitud (usuario cambia de opinión) | GDPR Art. 17 |

#### Campo: data_retention_override (override de retención de datos)

| Átomo | CRUD | Posición D12 | Descripción | Estándar |
|-------|:----:|:------------:|-------------|---------|
| `D12.gdpr.data_retention_override.C` | CREATE | D12.021 | Definir retención personalizada (días ISO 8601) | ISO 27001 A.8.10 · GDPR Art. 5e |
| `D12.gdpr.data_retention_override.R` | READ   | D12.022 | Ver política de retención | ISO 27001 A.8.10 |
| `D12.gdpr.data_retention_override.U` | UPDATE | D12.023 | Cambiar período de retención | ISO 27001 A.8.10 |
| `D12.gdpr.data_retention_override.D` | DELETE | D12.024 | Usar retención por defecto del sistema | ISO 27001 A.8.10 |

**Total D12: 5 campos × 4 = 20 + delegación (2×4=8) = 28 átomos (D12.001–D12.028)**

---

## Resumen del catálogo D4-D12

| Dominio | App | Campos | Átomos | Bloque RolTemplate | Bloque UserTemplate |
|---------|:---:|:------:|:------:|-------------------|-------------------|
| D4 — Físico | pacs | 7 | 28 | BLOQUE 4 physical_access | — (bhnexus) |
| D5 — Dispositivos | device | 5 | 20 | — | BLOQUE 5 devices |
| D6 — Geoespacial | geo | 4 | 16 | BLOQUE 8 geospatial | BLOQUE 7 location |
| D7 — Financiero | fin | 6 | 24 | BLOQUE 5 financial | — |
| D8 — Temporal | cal | 6 | 24 | BLOQUE 6 temporal | BLOQUE 8 temporal |
| D9 — Red | net | 5 | 20 | BLOQUE 10 network | BLOQUE 9 network |
| D10 — Auditoría | audit | 3 | 12 | BLOQUE 11 audit | BLOQUE 10 audit |
| D11 — Biométrico | bio | 4 | 16 | BLOQUE 7 biometric | — (D5 devices) |
| D12 — Delegación/Cumplimiento | delegate+gdpr | 7 | 28 | BLOQUE 12/13/14 | BLOQUE 12 compliance |
| **TOTAL D4-D12** | | **47** | **188** | | |

---

*Documento de diseño — pendiente aprobación DDL antes de implementar.*
*Ver: `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md` · `BAUTH-CATALOGO-ATOMOS-D00-CRUD.md`*
