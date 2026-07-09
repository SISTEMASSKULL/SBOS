# PROYECTO: Subsistema de Calendario Soberano — bCalendar

**Versión:** 2.0 · **Fecha:** 2026-06-23 · **Autor:** sbos-coordinador
**Schema destino:** `bcalendar` · **Estándar raíz:** RFC 5545 (iCalendar)
**Referencias:** `BAUTH-IDENTITY-GOVERNANCE-AUDIT-PLATFORM.md` v4.0 · `PLAN-RECONSTRUCCION-DDL.md` v6.0
**Tablas heredadas reemplazadas:** `bos_gestion_calendario`, `bos_schedule`

---

## 1. VISIÓN DEL PROYECTO

El SBOS requiere un sistema de calendario **soberano, multi-tenant y auditado al extremo**.
No depende de Google Calendar, Outlook ni ningún proveedor externo. Cada tenant tiene sus
propios calendarios con eventos recurrentes (RFC 5545), notificaciones multicanal (EMAIL,
SMS, WhatsApp, Push, Chat vía Mattermost), y auditoría bi-temporal (ISO SQL:2011).

### ⚠️ PRINCIPIO FUNDAMENTAL

**El calendario NO es un feature — es el motor central de comunicaciones programadas del SBOS.
Toda notificación, por cualquier medio, se programa como un `cal_event` con su `cal_alarm`.**

```
═══════════════════════════════════════════════════════════════════
NO EXISTE notificación fuera del calendario.
Cualquier mensaje que el SBOS envíe — recordatorio, alerta,
MFA, factura, reporte, vencimiento — es un cal_event.
═══════════════════════════════════════════════════════════════════
```

| Si el SBOS necesita... | Se programa como... |
|------------------------|---------------------|
| Enviar recordatorio de reunión 15 min antes | `cal_alarm(TRIGGER:-PT15M, CHANNEL:CHAT)` |
| Notificar vencimiento de contrato | `cal_event(rrule:FREQ=YEARLY) + cal_alarm(CHANNEL:EMAIL)` |
| Enviar MFA push al usuario | `cal_event(one-shot) + cal_alarm(CHANNEL:PUSH)` |
| Alertar acceso no autorizado | `cal_event(inmediato) + cal_alarm(CHANNEL:SMS)` |
| Recordar cierre fiscal SIN | `cal_event(rrule:FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=31)` |
| Avisar expiración de certificado SSL | `cal_event(rrule:FREQ=YEARLY) + cal_alarm(TRIGGER:-P30D)` |
| Notificar factura emitida | `cal_event(one-shot) + cal_alarm(CHANNEL:WHATSAPP)` |
| Enviar reporte semanal de ventas | `cal_event(rrule:FREQ=WEEKLY;BYDAY=MO) + cal_alarm(CHANNEL:EMAIL)` |

**Las 3 herramientas trabajan juntas como UN solo motor:**
- `rrule_plpgsql` → **CUÁNDO** (cálculo de recurrencia, siguiente disparo)
- **Novu** → **CÓMO** (orquestación de los 5 canales de entrega)
- **Mattermost** → **DÓNDE** (destino final del canal CHAT, por dominio)

**Sin calendario no hay notificación. Sin notificación no hay comunicación. Sin comunicación no hay SBOS.**

---

## 2. STACK TECNOLÓGICO COMPLETO

| Capa | Componente | Versión | Licencia | Rol específico |
|------|-----------|---------|----------|----------------|
| **Motor recurrencia** | `rrule_plpgsql` | latest (PGXN) | MIT | RFC 5545 completo en PostgreSQL: `FREQ`, `BYMONTH`, `BYDAY`, `EXDATE`, `RECURRENCE-ID`. ~60h de algoritmo ya implementado |
| **Base de datos** | PostgreSQL | 18.4 | PostgreSQL | Tipos nativos: `DATE`, `TIMESTAMPTZ`, `TSTZRANGE`, `GIST`. `PARTITION BY RANGE` para auditoría |
| **API REST** | PostgREST | 12.x | MIT | Capa REST automática sobre PostgreSQL. Endpoints `GET/POST/PATCH /api/calendar` sin escribir handlers |
| **Frontend calendario** | FullCalendar | 6.x | MIT | UI interactiva: arrastrar eventos, resize, vistas mes/semana/día, timezone-aware |
| **Fechas/horas (Rust)** | `chrono` | 0.4 | MIT/Apache 2.0 | `DateTime<Utc>`, `NaiveDate`, `Duration` en el daemon bauth |
| **i18n (Rust)** | ICU4X | 2.0 | Unicode | `icu::datetime`, `icu::calendar` — formatos de fecha por locale, zonas horarias IANA |
| **Orquestador notificaciones** | Novu | latest | MIT | 5-step workflow engine: EMAIL → SMS → WHATSAPP → PUSH → CHAT. Triggers vía JSON-RPC desde bauth |
| **Chat colaboración** | Mattermost | 10.x | MIT | 5º canal de notificación vía incoming webhook. Canales: `#compliance`, `#security`, `#soporte` |
| **UI scheduling (referencia)** | Cal.com | 4.x | AGPLv3 | Arquitectura de referencia: multi-tenant, RBAC, SAML SSO, audit logs. **No se integra — se estudia su diseño** |

### Por qué rrule_plpgsql y no una librería Rust

- La recurrencia se ejecuta en consultas SQL sin sacar datos de la BD
- `SELECT * FROM cal_instance WHERE occurs_at BETWEEN $1 AND $2` — instantáneo con índice GIST
- La expansión de rrule genera cientos de filas; hacerlo en Rust requiere N+1 queries
- PostgreSQL + rrule_plpgsql = una sola consulta con CTE recursivo

---

## 3. ESTÁNDARES INTERNACIONALES APLICADOS

| RFC / ISO | Título | Uso en bcalendar |
|-----------|--------|------------------|
| **RFC 5545** | Internet Calendaring and Scheduling Core Object Specification (iCalendar) | `cal_event` (VEVENT, rrule), `cal_exception` (EXDATE, RECURRENCE-ID), `cal_alarm` (VALARM), `cal_attendee` (ATTENDEE) |
| **RFC 4791** | Calendaring Extensions to WebDAV (CalDAV) | `cal_calendar`: colecciones de calendario por tenant (work, fiscal, process, compliance) |
| **RFC 7953** | Calendar Availability (VAVAILABILITY) | `cal_schedule`: horarios de trabajo, turnos, disponibilidad |
| **RFC 5546** | iCalendar Transport-Independent Interoperability Protocol (iTIP) | `cal_attendee`: invitaciones con RSVP (ACCEPTED/DECLINED/TENTATIVE/NEEDS-ACTION) |
| **ISO SQL:2011** | System-Versioned Temporal Tables | `cal_audit_log`: bi-temporal — `valid_from/valid_to` (mundo real) + `recorded_at` (DB) |
| **ISO 27001:2022 A.8.15** | Logging | `cal_notification_log` WORM (solo INSERT, REVOKE UPDATE/DELETE), ctx_id obligatorio |
| **SBOS-049** | Context Plane | ctx_id en cada tabla del subsistema |

---

## 4. LAS 11 TABLAS DEL SUBSISTEMA

```
┌────────────────────────────────────────────────────────────┐
│                     bcalendar                              │
├──────────────┬─────────────────────────────────────────────┤
│ cal_calendar │ Colección de calendarios (RFC 4791)         │
│              │ Tipos: work, fiscal, process, compliance    │
│              │ Un tenant puede tener N colecciones         │
├──────────────┼─────────────────────────────────────────────┤
│ cal_event    │ VEVENT master (RFC 5545)                    │
│              │ Almacena rrule TEXT sin expandir            │
│              │ Una serie completa = 1 registro             │
│              │ Ej: FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=52    │
├──────────────┼─────────────────────────────────────────────┤
│ cal_instance │ Ocurrencias materializadas ±90 días         │
│              │ Google Hybrid Window: nearby se expande,    │
│              │ lejos se calcula on-demand                  │
│              │ Índice GIST sobre TSTZRANGE                 │
├──────────────┼─────────────────────────────────────────────┤
│ cal_exception│ Modificaciones de instancias (RFC 5545)     │
│              │ RECURRENCE-ID: qué ocurrencia se modifica   │
│              │ EXDATE: qué ocurrencias se cancelan         │
├──────────────┼─────────────────────────────────────────────┤
│ cal_attendee │ Participantes (RFC 5545 ATTENDEE)          │
│              │ RSVP: ACCEPTED/DECLINED/TENTATIVE/NEEDS-ACTION │
│              │ FK lógica a idn_usuario                     │
├──────────────┼─────────────────────────────────────────────┤
│ cal_holiday  │ Feriados fijos y móviles                    │
│              │ Fijos: Navidad (12-25), Año Nuevo (01-01)   │
│              │ Móviles: Pascua (fórmula de Gauss),         │
│              │ Corpus Christi (Pascua + 60 días)           │
│              │ Por país/región/tenant                      │
├──────────────┼─────────────────────────────────────────────┤
│ cal_alarm    │ VALARM (RFC 5545)                           │
│              │ TRIGGER:-PT15M (15 min antes)               │
│              │ ACTION:DISPLAY, EMAIL, SMS, CHAT            │
│              │ Canal: EMAIL/SMS/WHATSAPP/PUSH/CHAT         │
├──────────────┼─────────────────────────────────────────────┤
│ cal_notifi-  │ Registro WORM de cada notificación enviada  │
│ cation_log   │ Solo INSERT (REVOKE UPDATE/DELETE)          │
│              │ ctx_id obligatorio (ISO 27001 A.8.15)       │
│              │ channel, recipient, template, outcome        │
├──────────────┼─────────────────────────────────────────────┤
│ cal_user_    │ Preferencias de notificación por usuario    │
│ prefs        │ Canal preferido, horario de silencio        │
│              │ Por tenant/empresa/usuario                   │
├──────────────┼─────────────────────────────────────────────┤
│ cal_audit_   │ Log bi-temporal (ISO SQL:2011)              │
│ log          │ valid_from/valid_to: tiempo real            │
│              │ recorded_at: tiempo de base de datos        │
│              │ Particionado por mes                        │
├──────────────┼─────────────────────────────────────────────┤
│ cal_schedule │ Horarios de trabajo (RFC 7953)              │
│              │ Heredable: tenant → empresa → sucursal      │
│              │ Turnos, jornada, horas extra                │
│              │ Control de acceso fuera de horario           │
└──────────────┴─────────────────────────────────────────────┘
```

---

## 5. ACOPLAMIENTO CON BAUTH

### 5.1 — Relación con el resto del ecosistema

```
┌─────────────────────────────────────────────────────────────┐
│                      SBOS Ecosystem                         │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐  │
│  │  bauth   │───▶│ bcalendar│◀───│     bnotify (Novu)    │  │
│  │ identidad│    │ 11 tablas│    │ orquestador notif.    │  │
│  └────┬─────┘    └────┬─────┘    └──────────┬───────────┘  │
│       │               │                     │               │
│       │          ┌────▼─────┐          ┌────▼───────────┐  │
│       │          │PostgreSQL│          │   Mattermost    │  │
│       │          │rrule_plp │          │  #compliance    │  │
│       │          │  + GIST  │          │  #security      │  │
│       │          └──────────┘          │  #soporte       │  │
│       │                                └────────────────┘  │
│       │                                                     │
│  ┌────▼─────┐    ┌──────────┐                               │
│  │idn_tenant│───▶│idn_tenant│  ctx_id viaja por todo        │
│  │idn_user  │    │_domain   │  el sistema sin romperse      │
│  │idn_empresa│   │(email_cfg)│                              │
│  └──────────┘    └──────────┘                               │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 — Puntos de acoplamiento con bauth

| # | bauth provee | bcalendar consume | Cómo se acopla |
|---|-------------|-------------------|----------------|
| 1 | `idn_tenant.tenant_id` | FK en `cal_calendar`, `cal_event`, `cal_schedule` | UUID directo — cada tenant tiene sus propios calendarios |
| 2 | `idn_usuario` | FK lógica en `cal_attendee` | UUID del usuario que asiste al evento |
| 3 | `idn_tenant_domain.email_config` | Config SMTP para notificaciones EMAIL | `smtp_host`, `smtp_port`, `smtp_from_email` — bcalendar lee de ahí |
| 4 | `idn_tenant_config.timezone_default` | Zona horaria para calcular ocurrencias | `America/La_Paz` — las instancias se expanden en la TZ del tenant |
| 5 | `idn_tenant_config.locale_default` | Idioma de notificaciones | `es-BO` → template de WhatsApp/email en español |
| 6 | `ctx_id` (SBOS-049) | Cada registro en bcalendar | Trazabilidad end-to-end: evento → alarma → notificación → audit |
| 7 | `cfg_domain_channel` (ITDR) | Mapeo dominio→canal Mattermost | `domain=D3_FINANCIERO → channel=#compliance` |
| 8 | `cfg_notification_policy` (ITDR) | Políticas de alerta por tenant | `severity=CRITICAL → channels=[EMAIL,SMS,CHAT]` |

### 5.3 — Las 3 herramientas: UN solo motor de comunicaciones

```
┌──────────────────────────────────────────────────────────────┐
│              MOTOR DE COMUNICACIONES PROGRAMADAS              │
│                                                              │
│  rrule_plpgsql          Novu               Mattermost       │
│  ┌──────────┐      ┌──────────────┐      ┌──────────────┐  │
│  │ CUÁNDO   │─────▶│    CÓMO      │─────▶│   DÓNDE      │  │
│  │          │      │              │      │              │  │
│  │ Calcula  │      │ Orquesta los │      │ Canal CHAT   │  │
│  │ próxima  │      │ 5 pasos de  │      │ destino por  │  │
│  │ ocurrencia│     │ entrega:     │      │ dominio:     │  │
│  │          │      │              │      │              │  │
│  │ Rrule    │      │ 1.EMAIL     │      │ #compliance  │  │
│  │ EXDATE   │      │ 2.SMS       │      │ #security    │  │
│  │ COUNT    │      │ 3.WHATSAPP  │      │ #soporte     │  │
│  │ UNTIL    │      │ 4.PUSH      │      │ #financiero  │  │
│  │ BYMONTH  │      │ 5.CHAT ─────┼─────▶│ #operaciones │  │
│  └──────────┘      └──────────────┘      └──────────────┘  │
│       ↑                    ↑                    ↑           │
│  PostgreSQL           bauth ──▶                 destino     │
│  extensión           JSON-RPC 2.0              final del    │
│  nativa              Unix socket               canal CHAT   │
└──────────────────────────────────────────────────────────────┘
```

**Sin estas 3 herramientas, el SBOS no puede notificar nada a nadie.**

### 5.4 — Flujo de datos en tiempo real

```
1. USUARIO CREA EVENTO (vía FullCalendar → PostgREST → PostgreSQL)
   POST /api/calendar { title, start, rrule: "FREQ=WEEKLY;BYDAY=MO", alarm: "-PT15M" }
   → INSERT INTO cal_event
   → INSERT INTO cal_alarm (TRIGGER:-PT15M, CHANNEL:CHAT)

2. CRON JOB (cada 5 min, vía pg_cron o bKron)
   SELECT * FROM cal_alarm WHERE next_trigger_at <= NOW()
   → Para cada alarma disparada:

3. BAUTH → NOVU (JSON-RPC 2.0 sobre Unix socket /run/bos/bos.sock)
   {
     "method": "bnotify.trigger",
     "params": {
       "workflow_id": "calendar_reminder",
       "subscriber_id": "<user_uuid>",
       "payload": {
         "event_title": "Reunión semanal",
         "start_time": "2026-06-24T14:00:00-04:00",
         "channel": "CHAT",
         "ctx_id": "019ef51f-fc83-71a1-..."
       }
     }
   }

4. NOVU → MATTERMOST (incoming webhook)
   POST https://mattermost.sbos.bo/hooks/xxx
   { "text": "🔔 Recordatorio: Reunión semanal en 15 min", "channel": "#compliance" }

5. REGISTRO WORM
   INSERT INTO cal_notification_log (event_id, channel, recipient, outcome, ctx_id)
   VALUES (...) -- solo INSERT, sin UPDATE ni DELETE

6. AUDITORÍA BI-TEMPORAL
   INSERT INTO cal_audit_log (table_name, record_id, operation, valid_from, recorded_at, actor_id)
   VALUES ('cal_alarm', '<uuid>', 'INSERT', NOW(), NOW(), '<user_uuid>')
```

### 5.4 — Unix socket (SBOS-050 P9, ADR-020)

Toda comunicación entre daemons es vía Unix socket, nunca HTTP:

```
/run/bos/bauth.sock     ← bauth (identidad)
/run/bos/bcalendar.sock ← bcalendar (calendario) — futuro daemon bCal
/run/bos/bnotify.sock   ← bnotify (Novu wrapper)
```

---

## 6. ARQUITECTURA DE REFERENCIA: CAL.COM

Cal.com (AGPLv3, TypeScript, Next.js + Prisma + PostgreSQL) es la referencia de diseño
para el subsistema de calendario del SBOS. **No se integra — se estudia su arquitectura.**

### Lo que Cal.com hace bien (y bcalendar replica)

| Característica | Cal.com | bcalendar |
|---------------|---------|-----------|
| **Multi-tenant** | Organizations + sub-teams, RBAC, SAML SSO, SCIM | `cal_calendar.tenant_id` + `idn_tenant` + `ctx_id` |
| **Recurrencia** | rrule en Prisma/PostgreSQL | `rrule_plpgsql` nativo en PostgreSQL |
| **Disponibilidad** | Slot calculation por horario laboral | `cal_schedule` RFC 7953 con herencia jerárquica |
| **Notificaciones** | Webhooks HMAC-SHA256 (BOOKING_CREATED, etc.) | Novu 5-step + Mattermost incoming webhook |
| **Auditoría** | Audit logs por tenant | `cal_audit_log` ISO SQL:2011 bi-temporal |
| **Seguridad** | HIPAA, SOC 2, ISO 27001, GDPR | `cal_notification_log` WORM + ctx_id + REVOKE UPDATE/DELETE |

### Lo que bcalendar agrega sobre Cal.com

- **Auditoría bi-temporal ISO SQL:2011** — dos ejes de tiempo independientes
- **Canal Mattermost nativo** — notificaciones en canales por dominio (#compliance, #security)
- **ctx_id obligatorio** — trazabilidad W3C Trace Context en cada registro
- **Schema bcalendar dedicado** — 11 tablas, sin dependencia de servicios externos
- **Unix socket** — comunicación entre daemons sin HTTP (SBOS-050 P9)

---

## 7. TABLAS REEMPLAZADAS

| Tabla heredada | Schema original | Reemplazada por | Fundamento |
|----------------|-----------------|-----------------|------------|
| `bos_gestion_calendario` | bauth | `cal_event` + `cal_holiday` + `cal_alarm` | Eventos recurrentes RFC 5545, feriados fijos/móviles, alarmas multicanal |
| `bos_schedule` | bauth | `cal_schedule` + `cal_calendar` | Horarios RFC 7953, colecciones RFC 4791, herencia jerárquica |

**Decisión:** No se migran. Se marcan `❌ REEMPLAZADA` en el plan de reconstrucción.
El subsistema `bcalendar` se construye desde cero con las 11 tablas nuevas.

---

## 8. PLAN DE IMPLEMENTACIÓN

| Fase | Qué | Horas | Dependencia |
|------|-----|-------|-------------|
| **C0** | Instalar `rrule_plpgsql` en PostgreSQL 18.4 | 1h | — |
| **C1** | Crear schema `bcalendar` + 11 tablas en DDL | 4h | C0 |
| **C2** | PostgREST config: endpoint `/api/calendar` | 1h | C1 |
| **C3** | FullCalendar → PostgREST → PostgreSQL (CRUD) | 4h | C2 |
| **C4** | `cal_holiday` seed: feriados Bolivia + LATAM | 2h | C1 |
| **C5** | `cal_alarm` + Novu workflow: 5-step notification | 4h | C1, Novu |
| **C6** | Mattermost incoming webhook config | 1h | C5 |
| **C7** | `cal_audit_log`: triggers bi-temporales | 2h | C1 |
| **C8** | `cal_schedule` + herencia tenant→empresa→sucursal | 3h | C1, idn_empresa |
| **C9** | Tests de recurrencia: 50 casos RFC 5545 | 3h | C3 |
| **Total** | | **25h** | |

---

## 9. REFERENCIAS CRUZADAS

| Documento | Relación |
|-----------|----------|
| `BAUTH-IDENTITY-GOVERNANCE-AUDIT-PLATFORM.md` v4.0 | §1.3: Integración bAuth↔Novu↔Mattermost. §3.2: Cadena de notificación |
| `PLAN-RECONSTRUCCION-DDL.md` v6.0 | §8: 11 tablas bcalendar. ANEXO A: Índice completo |
| `BAUTH-IDENTITY-GOVERNANCE-GAPS.md` v2.0 | GAP-07: Tablas ITDR faltantes (cfg_domain_channel, cfg_notification_policy) |
| `RUTINA-REPARACION-TABLAS.md` | Protocolo de 7 pasos para cada tabla |
| `MANUAL_DB_DDL.md` | Documentación columna por columna |
| `SBOS-049-CONTEXT-PLANE.md` | ctx_id obligatorio en cada registro |
| `SBOS-050-PORT-CATALOG.md` | P9: Unix socket, sin HTTP entre daemons |
| `ADR-020` | Interface Dual: JSON-RPC 2.0 + WebSocket RPC |

---

*Proyecto documentado 2026-06-23. El subsistema bcalendar es soberano — no depende de
Google Calendar, Outlook, Cal.com ni ningún proveedor externo de calendario.*
