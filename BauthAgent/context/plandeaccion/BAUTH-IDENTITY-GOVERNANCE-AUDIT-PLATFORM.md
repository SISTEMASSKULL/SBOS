# BAUTH-IDENTITY-GOVERNANCE-AUDIT-PLATFORM — Identity Governance & Audit Platform

**Versión:** 4.0.0 · **Fecha:** 2026-06-23 · **Autor:** sbos-coordinador
**Plataforma:** Identity Governance & Audit Platform — Plataforma de Gobernanza y Auditoría de Identidades
**Propósito:** Documento único que define la plataforma integral IAM del SBOS con 5 pilares:
- **Identity Governance**: políticas de acceso H-RBAC, recertificación periódica, cumplimiento normativo (SOX, GDPR, ISO 27001, PCI DSS)
- **Identity Audit**: registro inmutable de eventos de identidad — User Activity Logging, Identity Lineage, Secure Audit Logs (WORM + hash-chain SHA-256)
- **Access Alerting**: notificación multi-canal en tiempo real — ITDR (Identity Threat Detection & Response)
- **Access Certification**: campañas de recertificación de accesos cada 90 días (ISO 27001 A.9.2.5, SOC 2 CC6.2)
- **Integration**: esquemas de Cal.com, Novu y Mattermost como canales de colaboración y alerta

---

## 0. Identity Governance & Audit Platform — Arquitectura

```
┌──────────────────────────────────────────────────────────────────────────┐
│              IDENTITY GOVERNANCE & AUDIT PLATFORM (bAuth)                  │
│              Keycloak 26.6.2 + bAuth (S03) · OIDC · JWT                   │
│              BitMask 64-bit · Reconciliation Loop 60s · ctx_id W3C        │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │                    IDENTITY GOVERNANCE                            │    │
│  │  ┌─────────────────────┐  ┌─────────────────────────────────┐   │    │
│  │  │ Access Policies     │  │ Access Certification            │   │    │
│  │  │ H-RBAC · SoD · D2-4│  │ Recertificación 90 días         │   │    │
│  │  │ cfg_notification    │  │ cal_review_campaign             │   │    │
│  │  │ _policy             │  │ ISO 27001 A.9.2.5               │   │    │
│  │  └─────────────────────┘  └─────────────────────────────────┘   │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │                     IDENTITY AUDIT                                │    │
│  │  ┌─────────────────────┐  ┌─────────────────────────────────┐   │    │
│  │  │ User Activity Logging│  │ Identity Lineage               │   │    │
│  │  │ aud_event (WORM)    │  │ ctx_id trace → ¿quién dio      │   │    │
│  │  │ Hash-chain SHA-256  │  │ acceso a este usuario?         │   │    │
│  │  │ ISO 27001 A.8.15    │  │ idn_delegation · idn_user_role │   │    │
│  │  └─────────────────────┘  └─────────────────────────────────┘   │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │              IDENTITY THREAT DETECTION & RESPONSE (ITDR)          │    │
│  │                                                                   │    │
│  │  bAuth detecta identity event ──► evalúa cfg_notification_policy  │    │
│  │    (violación D2/D3/D4, auth fail, SoD, anomalía)                │    │
│  │         │                                                          │    │
│  │         ▼                                                          │    │
│  │  ┌──────────────────────────────────────────────────────────┐    │    │
│  │  │              Novu (Access Alerting Engine)                │    │    │
│  │  │               S06:28200 · MongoDB/FerretDB                │    │    │
│  │  │                                                           │    │    │
│  │  │   Workflow: "auth_breach_financial"                       │    │    │
│  │  │     Step 1 ──► WHATSAPP ──► Twilio ──► supervisor         │    │    │
│  │  │     Step 2 ──► SMS      ──► Twilio ──► compliance officer │    │    │
│  │  │     Step 3 ──► EMAIL    ──► SendGrid ──► compliance@sbos  │    │    │
│  │  │     Step 4 ──► PUSH     ──► FCM/APNS ──► dispositivo      │    │    │
│  │  │     Step 5 ──► CHAT     ──► Mattermost incoming webhook    │    │    │
│  │  └──────────────────────────────────────────────────────────┘    │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │    Mattermost (Chat + Access Alerting Channel)                    │    │
│  │    S06:9064 · PostgreSQL · Go                                    │    │
│  │    Governance channels: #compliance #seguridad #auth-alerts      │    │
│  │                        #operaciones #admin                       │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │    Cal.com (Calendar)          Dovecot+Postfix (Email Transport)  │    │
│  │    S06:9060 · PostgreSQL        S06:25,465,587,143,993            │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
```

**5 pilares de la plataforma:** Identity Governance · Identity Audit · Access Alerting (ITDR) · Access Certification · Integration

**bAuth NO escribe en las bases de datos de Cal.com/Novu/Mattermost.**
La integración es por **3 vías**:
1. **Identidad compartida**: Keycloak OIDC — mismo usuario en los 4 sistemas
2. **JSON-RPC / Webhook**: bAuth → Novu (trigger), Novu → Mattermost (incoming webhook)
3. **ctx_id**: W3C Trace Context = transactionId en Novu → Identity Lineage universal

---

## 1. Bases de Datos de las Aplicaciones Colaborativas

### 1.1 Cal.com — PostgreSQL (Prisma ORM)

| Modelo Prisma | Tabla PostgreSQL | Propósito | ~Columnas |
|--------------|-----------------|-----------|-----------|
| **User** | `users` | Cuenta de usuario (nombre, email, timezone, locale) | 25+ |
| **EventType** | `event_types` | Tipo de evento agendable (duración, ubicación, scheduling) | 35+ |
| **Booking** | `bookings` | Reunión agendada (startTime, endTime, status, attendees) | 25+ |
| **Attendee** | `attendees` | Participante de una reunión (email, timeZone, rsvp) | 15+ |
| **Team** | `teams` | Equipo u organización (slug, logo, branding, parentId) | 20+ |
| **Membership** | `memberships` | Usuario ↔ Team con rol (MEMBER, ADMIN, OWNER) | 5+ |
| **Schedule** | `schedules` | Horario de disponibilidad (userId, name, timeZone) | 8+ |
| **Availability** | `availability` | Franja horaria dentro de un Schedule (days, startTime, endTime) | 8+ |
| **Host** | `hosts` | Junction User ↔ EventType con priority, weight (Round Robin) | 5+ |
| **Credential** | `credentials` | Credenciales OAuth/apps (Zoom, Google Meet, Outlook) | 10+ |
| **Webhook** | `webhooks` | Webhooks de eventos (BOOKING_CREATED, MEETING_ENDED, etc.) | 8+ |
| **Workflow** | `workflows` | Automatizaciones (EMAIL_HOST, SMS_ATTENDEE) | 10+ |

**Relación con bAuth:**

| Concepto Cal.com | Concepto bAuth | Integración |
|-----------------|----------------|-------------|
| `User.id` (Int) | `idn_usuario.usuario_id` (UUID) | Vinculados por claim `sub` del JWT Keycloak. Sin FK directa. |
| `Team` (Organization) | `idn_tenant` + `idn_empresa` | 1 tenant SBOS = 1 Organization en Cal.com. Creado al alta del tenant. |
| `Schedule` / `Availability` | `cal_schedule` (bCalendar) | Los turnos definidos en `cal_schedule` se reflejan vía API de Cal.com. |
| `Booking` (reunión) | `cal_event` + `cal_instance` | Un Booking puede disparar un `cal_event` en bAuth para trazabilidad fiscal. |

### 1.2 Novu — MongoDB (via FerretDB → PostgreSQL)

| Colección MongoDB | Propósito | Campos Clave |
|------------------|-----------|-------------|
| **organizations** | Tenant multi-organización | `name`, `createdAt` |
| **environments** | Ambiente dev/prod por organización | `name`, `organizationId`, `apiKeys` |
| **subscribers** | Destinatario de notificaciones | `subscriberId`, `email`, `phone`, `locale`, `channels[]` |
| **notificationtemplates** | Definición de workflow (triggers + steps) | `name`, `triggers[]`, `steps[]`, `preferenceSettings` |
| **notifications** | Grupo de mensajes de una ejecución | `templateId`, `subscriberId`, `transactionId` |
| **messages** | Mensaje individual por canal | `channel`, `status`, `transactionId`, `seen`, `read` |
| **jobs** | Ejecución de cada step del workflow | `status`, `type`, `payload`, `stepId` |
| **integrations** | Credenciales de proveedores por canal | `channel`, `providerId`, `credentials`, `active` |

**Relación con bAuth:**

| Concepto Novu | Concepto bAuth | Integración |
|--------------|----------------|-------------|
| `subscribers.subscriberId` | `idn_usuario.usuario_id` | bAuth registra al usuario como subscriber en Novu al crearlo. |
| `organizations` | `idn_tenant` | 1 tenant = 1 organization en Novu. |
| `notificationtemplates[]` | `cfg_saga` (12 sagas) | bAuth define QUÉ notificar. Novu define CÓMO (canal, texto, timing). |
| `messages.transactionId` | `ctx_id` (SBOS-049) | **IDÉNTICOS.** Trazabilidad end-to-end + idempotencia. |

### 1.3 Mattermost — PostgreSQL (Go Migrations) + 5º Canal de Notificación

Mattermost tiene **doble rol** en el SBOS: chat empresarial (soberano, bAuth no interfiere) y **5º canal de notificación** vía incoming webhooks.

| Tabla | Propósito | Columnas Clave |
|-------|-----------|---------------|
| **Users** | Cuenta de usuario | `Id` (VARCHAR 26), `Username`, `Email`, `Roles`, `Props` (JSONB) |
| **Teams** | Espacio de trabajo | `Id`, `DisplayName`, `Name`, `Type` |
| **Channels** | Canal de comunicación | `Id`, `TeamId`, `Type` (D/G/P/O), `DisplayName` |
| **ChannelMembers** | Miembro de canal | `ChannelId` + `UserId` (PK compuesta) |
| **Posts** | Mensaje (incluye posts de webhook) | `Id`, `ChannelId`, `Message`, `Props` (JSONB) |
| **IncomingWebhooks** | Webhooks entrantes | `Id`, `ChannelId`, `UserId`, `DisplayName` |

**5 canales de auditoría pre-creados por tenant:**

| Canal Mattermost | Dominio bAuth | Propósito |
|-----------------|--------------|-----------|
| `#compliance` | D3 Financiero | Límites excedidos, SoD violado, tx rechazadas, reportes SIN |
| `#seguridad` | D2 Físico | Accesos denegados, puertas forzadas, alarmas OSDP, CCTV events |
| `#auth-alerts` | Autenticación | Bloqueos de cuenta, step-up requerido, MFA resets, brute force |
| `#operaciones` | D4 Temporal | Accesos fuera de horario, delegaciones expiradas, cierres de gestión |
| `#admin` | Admin/SysAdmin | SU break-glass, rotación de llaves, backups, sync fallido |

**Asignación de miembros por rol bAuth:**

| Canal | Roles automáticos |
|-------|------------------|
| `#compliance` | `ROL-JEFE-*`, `ROL-CONTADOR-*`, `ROL-AUDITOR-*` |
| `#seguridad` | `ROL-JEFE-SEGURIDAD`, `ROL-PORTERO`, `ROL-OPERADOR-CCTV` |
| `#auth-alerts` | `SYS-*`, `ROL-ADMIN-*` |
| `#operaciones` | `ROL-GERENTE-*`, `ROL-JEFE-*`, `ROL-SUPERVISOR-*` |
| `#admin` | `SYS-SUPERUSUARIO`, `SYS-PLATAFORMA-SEGURIDAD`, `SYS-PLATAFORMA-SRE` |

**Lo que bAuth SÍ gestiona en Mattermost:**
- ✅ Crea el Team al alta del tenant
- ✅ Crea los 5 canales de auditoría y 5 incoming webhooks
- ✅ Asigna/remueve miembros de canales de auditoría según cambios de rol (reconcile loop 60s)
- ✅ Suspende al usuario en Mattermost cuando bAuth lo desactiva

**Lo que bAuth NO toca:**
- ❌ Canales de equipo, sesiones, mensajes de canales no-auditoría

---

## 2. Identity Audit Chain (Cadena de Gobernanza de Identidad)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     IDENTITY AUDIT CHAIN                                     │
│                                                                              │
│  [1] USER ACTIVITY        [2] POLICY           [3] ACCESS ALERTING           │
│      LOGGING                  EVALUATION           (ITDR)                    │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────────────────┐   │
│  │ bAuth detecta │      │ cfg_notif    │      │ Novu workflow             │   │
│  │ identity      │ ───► │ _policy      │ ───► │ 5 canales en paralelo     │   │
│  │ event         │      │              │      │                           │   │
│  │              │      │ ¿severidad?  │      │ transactionId = ctx_id    │   │
│  │ INSERT        │      │ ¿canales?    │      │                           │   │
│  │ aud_event     │      │ ¿template?   │      │ ┌─ WHATSAPP              │   │
│  │ (WORM)        │      └──────────────┘      │ ├─ SMS                   │   │
│  └──────────────┘                             │ ├─ EMAIL                 │   │
│                                               │ ├─ PUSH                  │   │
│  ctx_id: ─────────────────────────────────────│ └─ CHAT → Mattermost     │   │
│  skull.empresa.sucursal.pos.user.trace        └──────────────────────────┘   │
│                                                        │                     │
│  [4] ACCESS ALERT            [5] IDENTITY AUDIT         ▼                     │
│      DELIVERY                     (Secure Audit Logs)                        │
│  ┌──────────────┐      ┌──────────────────────────────────────────────┐     │
│  │ Provider     │      │ aud_notification (espejo local)                │     │
│  │ Twilio/Meta/ │ ───► │                                              │     │
│  │ SendGrid/FCM │      │ notification_id ──► aud_event_id              │     │
│  │ Mattermost   │      │ transaction_id  ──► ctx_id                   │     │
│  └──────────────┘      │ channel         ──► WHATSAPP/SMS/EMAIL/...   │     │
│                         │ status          ──► PENDING→SENT→DELIVERED   │     │
│                         │ provider_msg_id ──► Twilio SID / Post ID     │     │
│                         └──────────────────────────────────────────────┘     │
│                                                                              │
│  🔗 ctx_id: Identity Lineage universal — atraviesa los 5 eslabones          │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Principio:** Un solo `ctx_id` (W3C Trace Context) atraviesa los 5 eslabones de la Identity Audit Chain.
Desde la detección en bAuth hasta el Post en Mattermost, el mismo identificador permite reconstruir
la trazabilidad completa de cualquier identity event — respondiendo preguntas como
"¿quién accedió, desde dónde, con qué rol, quién se lo asignó, y quién fue alertado?".

---

## 3. Catálogo de Identity Events por Dominio de Acceso

### 3.1 D3 — Dominio Financiero (10 eventos)

| # | Código | Evento | Disparador | Severidad | Canales |
|---|--------|--------|-----------|-----------|---------|
| F01 | `FIN_LIMIT_EXCEEDED` | Operación excede límite diario/mensual | `amount > fin_limit.max_daily` | 🔴 CRITICAL | WHATSAPP + SMS + EMAIL + CHAT |
| F02 | `FIN_SOD_VIOLATION` | Violación Separación de Deberes | Mismo usuario crea Y aprueba | 🔴 CRITICAL | WHATSAPP + CHAT |
| F03 | `FIN_DUAL_CONTROL_FAILED` | Operación sin segunda firma | `fin_approval.dual_control` requerido y ausente | 🔴 CRITICAL | WHATSAPP + EMAIL + CHAT |
| F04 | `FIN_UNAUTHORIZED_APPROVAL` | Aprobación fuera de jurisdicción | `ctx_id.sucursal` ≠ `fin_permission.sucursal_id` | 🟠 HIGH | SMS + CHAT |
| F05 | `FIN_CURRENCY_RESTRICTED` | Intento en moneda no autorizada | `currency_code` ∉ `global_tenant_currency` | 🟠 HIGH | EMAIL + CHAT |
| F06 | `FIN_THRESHOLD_WARNING` | Operación >80% del límite (pre-alerta) | `amount > 0.8 * max_daily` | 🟡 MEDIUM | EMAIL |
| F07 | `FIN_RECONCILIATION_MISMATCH` | Descuadre en conciliación diaria | `SUM(debe) ≠ SUM(haber)` en cierre | 🔴 CRITICAL | WHATSAPP + EMAIL + CHAT |
| F08 | `FIN_DOCUMENT_TAMPERED` | Documento fiscal modificado post-cierre | `fin_operation.updated_at > interval.closed_at` | 🔴 CRITICAL | WHATSAPP + SMS + CHAT |
| F09 | `FIN_BACKDATE_ATTEMPT` | Intento de registro en gestión cerrada | `operation_date < interval.closed_at` | 🟠 HIGH | EMAIL + CHAT |
| F10 | `FIN_SIN_REPORT_READY` | Reporte SIN listo para enviar | `cal_compliance_deadline.due_date = TODAY()` | 🟡 MEDIUM | EMAIL + CHAT |

### 3.2 D2 — Dominio Físico (8 eventos)

| # | Código | Evento | Disparador | Severidad | Canales |
|---|--------|--------|-----------|-----------|---------|
| P01 | `PHY_ZONE_DENIED` | Acceso denegado a zona restringida | `bitmask.physical & zona_mask = 0` | 🟠 HIGH | PUSH + CHAT |
| P02 | `PHY_DOOR_FORCED` | Puerta forzada sin autenticación | Sensor magnético + sin evento OSDP | 🔴 CRITICAL | SMS + WHATSAPP + PUSH + CHAT |
| P03 | `PHY_TAILGATING` | Dos personas con una credencial | Sensor IR + 1 evento OSDP | 🟠 HIGH | PUSH + CHAT |
| P04 | `PHY_AFTER_HOURS` | Acceso fuera del horario del edificio | `NOW() ∉ cal_schedule.work_hours` | 🟡 MEDIUM | EMAIL + CHAT |
| P05 | `PHY_DEVICE_OFFLINE` | Dispositivo físico sin heartbeat | `sec_hardware_device.last_seen > 60s` | 🟠 HIGH | PUSH + CHAT |
| P06 | `PHY_DEVICE_TAMPERED` | Manipulación física del dispositivo | Sensor tamper activado | 🔴 CRITICAL | SMS + WHATSAPP + PUSH + CHAT |
| P07 | `PHY_LOCKDOWN_ACTIVATED` | Cierre de emergencia activado | Botón de pánico o comando administrativo | 🔴 CRITICAL | WHATSAPP + SMS + PUSH + CHAT |
| P08 | `PHY_GUARD_TOUR_MISSED` | Ronda de guardia no completada | `guard_tour.checkpoint_time` expirado sin registro | 🟡 MEDIUM | PUSH + CHAT |

### 3.3 Dominio de Autenticación (10 eventos)

| # | Código | Evento | Disparador | Severidad | Canales |
|---|--------|--------|-----------|-----------|---------|
| A01 | `AUTH_LOGIN_FAILED_3` | 3 intentos fallidos consecutivos | `ath_password.failed_attempts = 3` | 🟠 HIGH | SMS + CHAT |
| A02 | `AUTH_LOGIN_FAILED_5` | 5 intentos fallidos — cuenta bloqueada | `ath_password.failed_attempts = 5` | 🔴 CRITICAL | SMS + EMAIL + CHAT |
| A03 | `AUTH_BRUTE_FORCE_IP` | Ataque de fuerza bruta desde IP | 10+ fallos desde misma IP en 60s | 🔴 CRITICAL | WHATSAPP + CHAT |
| A04 | `AUTH_STEPUP_REQUIRED` | Step-Up requerido (RFC 9470) | Operación requiere AAL3, sesión actual AAL2 | 🟠 HIGH | PUSH + SMS |
| A05 | `AUTH_MFA_BYPASS_ATTEMPT` | Intento de bypassear MFA | `ath_mfa.enrolled = false` pero política requiere MFA | 🔴 CRITICAL | WHATSAPP + CHAT |
| A06 | `AUTH_PASSWORD_SCREENED` | Contraseña aparece en HIBP | `ath_password_screening.found_in_breach = true` | 🟠 HIGH | EMAIL |
| A07 | `AUTH_CREDENTIAL_EXPIRED` | Credencial vencida sin rotación | `ath_credential_rotation.next_rotation < NOW()` | 🟡 MEDIUM | EMAIL + CHAT |
| A08 | `AUTH_SESSION_HIJACK_DETECTED` | Posible secuestro de sesión | `ses_session.ip` cambió sin nuevo login | 🔴 CRITICAL | WHATSAPP + SMS + CHAT |
| A09 | `AUTH_SUPERUSER_ACTIVATED` | Break-glass SU activado | `aud_superuser.activated_at IS NOT NULL` | 🔴 CRITICAL | WHATSAPP + SMS + EMAIL + CHAT |
| A10 | `AUTH_TOKEN_REVOKED_BULK` | Revocación masiva de tokens | `ath_revocation.count > 10` en < 60s | 🟠 HIGH | CHAT |

### 3.4 D4 — Dominio Temporal (5 eventos)

| # | Código | Evento | Disparador | Severidad | Canales |
|---|--------|--------|-----------|-----------|---------|
| T01 | `TEMP_OUTSIDE_SCHEDULE` | Acceso fuera del horario laboral | `NOW().day_of_week ∉ cal_schedule.work_days` | 🟡 MEDIUM | EMAIL |
| T02 | `TEMP_DELEGATION_EXPIRING` | Delegación vence en 24h | `valid_until - NOW() < 24h` | 🟡 MEDIUM | EMAIL + UI + CHAT |
| T03 | `TEMP_DELEGATION_EXPIRED` | Delegación vencida — auto-revocada | `NOW() > cal_delegation_window.valid_until` | 🟡 MEDIUM | EMAIL + CHAT |
| T04 | `TEMP_INTERVAL_CLOSING` | Gestión contable cierra en 7 días | `cal_interval.end_date - TODAY() = 7` | 🟡 MEDIUM | EMAIL + CHAT |
| T05 | `TEMP_INTERVAL_CLOSED` | Gestión contable cerrada | `cal_interval.status = HARD_CLOSED` | 🟠 HIGH | EMAIL + CHAT |

### 3.5 Dominio Admin/SysAdmin (5 eventos)

| # | Código | Evento | Disparador | Severidad | Canales |
|---|--------|--------|-----------|-----------|---------|
| X01 | `ADMIN_KEY_ROTATED` | Rotación de llave criptográfica | `sec_key_rotation.rotated_at IS NOT NULL` | 🟡 MEDIUM | EMAIL + CHAT |
| X02 | `ADMIN_BACKUP_FAILED` | Backup falló | `aud_backup.status = 'FAILED'` | 🟠 HIGH | CHAT |
| X03 | `ADMIN_SYNC_FAILED` | Sync KC+Tryton falló | `aud_sync.status = 'ERROR'` en reconcile loop | 🟠 HIGH | CHAT |
| X04 | `ADMIN_VAULT_SEALED` | Vault sellado — secretos inaccesibles | Vault health check: `sealed = true` | 🔴 CRITICAL | WHATSAPP + SMS + PUSH + CHAT |
| X05 | `ADMIN_CERT_EXPIRING` | Certificado TLS vence en 30 días | `tls_cert.not_after - NOW() < 30d` | 🟡 MEDIUM | EMAIL + CHAT |

**Total: 38 eventos catalogados.**

---

## 4. Access Risk Matrix & Escalation Policy

### 4.1 Definición de Niveles

| Nivel | Significado | Tiempo de Respuesta | Escalamiento |
|-------|------------|-------------------|-------------|
| 🔴 **CRITICAL** | Amenaza activa — acción inmediata | < 5 minutos | Sin ACK en 5min → WHATSAPP al admin + SMS al SU |
| 🟠 **HIGH** | Incidente de seguridad — investigar | < 30 minutos | Sin resolver en 30min → notificar al admin |
| 🟡 **MEDIUM** | Advertencia — atención requerida | < 4 horas | Digest diario a las 08:00 al supervisor |
| 🟢 **LOW** | Informativo — sin acción requerida | < 24 horas | Solo registro en aud_event, sin notificación |

### 4.2 Distribución por Severidad

| Severidad | D3 Financiero | D2 Físico | Autenticación | D4 Temporal | Admin | **Total** |
|-----------|-------------|-----------|--------------|------------|-------|----------|
| 🔴 CRITICAL | 3 | 3 | 4 | 0 | 1 | **11** |
| 🟠 HIGH | 2 | 3 | 3 | 1 | 2 | **11** |
| 🟡 MEDIUM | 3 | 2 | 1 | 4 | 2 | **12** |
| 🟢 LOW | 2 | 0 | 2 | 0 | 0 | **4** |

### 4.3 Matriz Canal × Dominio

| Dominio | WhatsApp | SMS | Email | Push | Chat (Mattermost) |
|---------|----------|-----|-------|------|-------------------|
| **D3 Financiero** | ✅ Supervisor | ✅ Compliance | ✅ Compliance | — | ✅ `#compliance` |
| **D2 Físico** | ✅ Jefe Seguridad | ✅ Jefe Seguridad | — | ✅ Guardias | ✅ `#seguridad` |
| **D4 Temporal** | — | — | ✅ Supervisor | — | ✅ `#operaciones` |
| **Autenticación** | — | ✅ Usuario | ✅ Usuario + Admin | ✅ Usuario | ✅ `#auth-alerts` |
| **Admin/SysAdmin** | — | — | ✅ Admin | — | ✅ `#admin` |

---

## 5. Identity Event Response Flows (Flujos ITDR)

### 5.1 Ejemplo Completo: Violación Financiera (5 canales)

```
CONTEXTO: Cajero intenta aprobar transacción de $50,000 (límite diario: $10,000)

1. bAuth.privilege_policy evalúa: ¿monto ≤ fin_limit? → NO
2. bAuth.fin_approval: INSERT con status='REJECTED', reason='LIMIT_EXCEEDED'
3. bAuth.aud_event: INSERT con ctx_id, event_type='FIN_LIMIT_EXCEEDED', severity='CRITICAL'
4. bAuth evalúa cfg_notification_policy: domain=FINANCIAL, event=LIMIT_EXCEEDED
   → canales: [WHATSAPP, SMS, EMAIL, CHAT]
5. bAuth → Novu JSON-RPC: { name: "auth_breach_financial", payload: {...}, transactionId: ctx_id }
6. Novu workflow — 4 steps en paralelo:
   Step 1 (WHATSAPP): "🚨 Alerta: Cajero María López intentó aprobar $50,000. Límite: $10,000."
   Step 2 (SMS): "SBOS ALERTA: Violación límite $50K/10K — María López — Suc Norte"
   Step 3 (EMAIL): Reporte detallado con tabla, IP, timestamp, ctx_id
   Step 4 (CHAT): POST a Mattermost #compliance
7. Mattermost #compliance:
   ┌─────────────────────────────────────────────────────────┐
   │ 🤖 SBOS Security Bot                                   │
   │ 🚨 VIOLACIÓN DE LÍMITE FINANCIERO                      │
   │                                                        │
   │ Usuario: María López    Sucursal: Norte                 │
   │ Monto intentado: $50,000    Límite diario: $10,000      │
   │ ctx_id: `skull.empresa_a.suc_norte.pos_3.admin.trace`  │
   │                                                        │
   │ ┌─────────────┬──────────────────┐                     │
   │ │ Dominio      │ D3 Financiero    │                     │
   │ │ Severidad    │ CRITICAL         │                     │
   │ │ IP           │ 192.168.1.100    │                     │
   │ │ Timestamp    │ 2026-06-23 14:32 │                     │
   │ └─────────────┴──────────────────┘                     │
   └─────────────────────────────────────────────────────────┘
8. Todos los miembros de #compliance reciben notificación
9. bAuth registra aud_notification (×4, uno por canal), status='SENT'
```

### 5.2 Ejemplo: Acceso Físico Denegado

```
CONTEXTO: Empleado sin permiso ZONA_B intenta acceder a bóveda

1. bhnexus recibe evento OSDP: tarjeta presentada en lector bóveda
2. bhnexus → bAuth JSON-RPC: bauth.physical.validate(ctx_id, zona='ZONA_B')
3. bAuth.DomainEvaluator D2: ¿idn_usuario tiene bit PHY_SEC_LEVEL_3? → NO
4. bAuth responde: { authorized: false, reason: "ZONE_RESTRICTED" }
5. bhnexus deniega apertura + activa alarma silenciosa
6. bAuth dispara Novu: template "auth_physical_denied"
7. Novu workflow — 2 steps:
   Step 1 (PUSH): "🚨 Acceso denegado: Bóveda — Juan Pérez — Suc Norte" → todos los guardias
   Step 2 (CHAT): POST a Mattermost #seguridad con attachments del evento
8. Guardias reciben PUSH + mención en #seguridad
```

---

## 6. Audit Integrity & Idempotency Guarantees

### 6.1 Cadena de Responsabilidades

| Eslabón | Responsable | Garantía | Degradación si falla |
|---------|-----------|----------|---------------------|
| **Detección** | bAuth DomainEvaluator | Síncrono, < 1ms | Sin evento = sin notificación |
| **Registro** | bAuth `aud_event` | WORM, INSERT atómico, ctx_id único | Si falla el INSERT, la operación se rechaza |
| **Evaluación** | bAuth `cfg_notification_policy` | Lookup por (tenant, domain, event_type), cache 30s | Sin policy → default: EMAIL al admin |
| **Dispatcher** | bAuth → Novu JSON-RPC | Timeout 5s, retry 3× (1s, 2s, 4s) | Si agota → `aud_notification.status='FAILED'` → reencola cada 60s |
| **Workflow** | Novu | At-least-once, retry ×3 por step, dead letter queue | Si step falla → `jobs.status='failed'` |
| **Entrega** | Proveedor (Twilio, Meta, SendGrid, FCM, Mattermost) | Best-effort, callback de delivery | Sin callback → `status='SENT'` (no confirmado) |
| **Confirmación** | Novu → bAuth webhook | POST a `/bauth/notifications/callback` con transactionId | Sin callback → reconciliación cada 15min consulta a Novu |
| **Auditoría** | bAuth `aud_notification` | INSERT idempotente (transactionId UNIQUE) | ON CONFLICT DO NOTHING |

### 6.2 Idempotencia

```
bAuth envía notificación con transactionId = ctx_id
     │
     ▼
Novu: ON DUPLICATE transactionId → SKIP (ya procesado)
     │
     ▼
Twilio: ON CONFLICT Twilio SID → DO NOTHING
     │
     ▼
Mattermost: ctx_id en payload → si el Post ya existe, no duplicar
     │
     ▼
bAuth.aud_notification: UNIQUE(transaction_id) → SKIP
```

### 6.3 Reconciliación Periódica (cada 15min)

```sql
SELECT n.transaction_id, n.channel, n.status, n.sent_at
FROM bAuth.aud_notification n
WHERE n.status IN ('PENDING', 'SENT')
  AND n.sent_at < NOW() - INTERVAL '15 minutes';

-- Para cada una: consultar Novu GET /v1/notifications?transactionId={id}
-- Si delivered → UPDATE status='DELIVERED'
-- Si failed → reenviar
-- Si no responde → reintentar en 15min
```

---

## 7. Identity Governance Triad (Tríada de Gobernanza)

```
┌──────────────────────────────────────────────────────────────┐
│                   TRÍADA DE AUDITORÍA                         │
│                                                               │
│  aud_event                    aud_notification               │
│  ┌──────────────────┐        ┌──────────────────────────┐   │
│  │ event_id (PK)    │◄──────│ aud_event_id (FK)         │   │
│  │ event_type       │       │ transaction_id (UNIQUE)    │   │
│  │ domain           │       │ channel                   │   │
│  │ severity         │       │ status                    │   │
│  │ actor_id         │       │ provider_msg_id           │   │
│  │ tenant_id        │       │ sent_at / delivered_at    │   │
│  │ payload (JSONB)  │       │ error_message             │   │
│  │ ctx_id (UNIQUE)  │       │ ctx_id                    │   │
│  │ created_at       │       └──────────────────────────┘   │
│  └──────────────────┘                                        │
│           │                                                  │
│           │ 1 evento ──► N notificaciones (1:N)              │
│           │                                                  │
│  ┌──────────────────────────────────────────┐               │
│  │ cfg_notification_policy                   │               │
│  │ ┌──────────────────────────────────────┐ │               │
│  │ │ tenant_id + domain + event_type      │ │               │
│  │ │ channels[]  (qué canales)            │ │               │
│  │ │ severity    (umbral mínimo)          │ │               │
│  │ │ novu_template (qué workflow Novu)     │ │               │
│  │ └──────────────────────────────────────┘ │               │
│  └──────────────────────────────────────────┘               │
│                                                               │
│  🔗 aud_event.ctx_id = aud_notification.transaction_id        │
│  🔗 1 ctx_id → evento → N notificaciones                     │
└──────────────────────────────────────────────────────────────┘
```

### Consulta de Trazabilidad Completa

```sql
SELECT
    e.event_type, e.domain, e.severity,
    e.created_at AS detected_at,
    n.channel, n.status AS delivery_status,
    n.provider_msg_id, n.sent_at, n.delivered_at,
    CASE WHEN n.channel = 'CHAT' THEN n.mattermost_channel_id END AS mattermost_channel
FROM bAuth.aud_event e
LEFT JOIN bAuth.aud_notification n ON e.event_id = n.aud_event_id
WHERE e.ctx_id = 'skull.empresa_a.suc_norte.pos_3.admin.trace_def456'
ORDER BY n.channel;
```

### Dashboard Grafana (6 paneles)

| Panel | Fuente | Métrica |
|-------|--------|---------|
| Eventos por dominio (24h) | `aud_event` | `COUNT(*) GROUP BY domain` |
| Tasa de entrega por canal | `aud_notification` | `COUNT(*) FILTER (status='DELIVERED') / COUNT(*)` |
| Latencia detección→entrega | `aud_event` JOIN `aud_notification` | `AVG(n.delivered_at - e.created_at)` |
| Top 10 eventos más frecuentes | `aud_event` | `COUNT(*) GROUP BY event_type` |
| Notificaciones fallidas | `aud_notification` | `COUNT(*) FILTER (status='FAILED') GROUP BY channel` |
| Heatmap severidad × tenant | `aud_event` | `COUNT(*) FILTER (severity='CRITICAL') GROUP BY tenant_id, hour` |

---

## 8. Identity Governance Schema — Tablas Requeridas en bAuth

### 8.1 Tablas existentes de Identity Audit (sin cambios)

| Tabla | Rol en Identity Governance |
|-------|----------------------|
| `bAuth.aud_event` | Registro WORM de cada evento que dispara notificación |
| `bAuth.ath_method` / `bAuth.ath_policy` | Definen los eventos de autenticación notificables |
| `bAuth.fin_limit` / `bAuth.fin_approval` | Definen umbrales que disparan alertas financieras |
| `bAuth.sec_site` / `bAuth.sec_area` | Definen zonas físicas cuyas violaciones se notifican |
| `bAuth.ses_session` | Transporta ctx_id que se usa como transactionId en Novu |

### 8.2 Tablas NUEVAS de Identity Governance

```sql
-- ============================================================
-- 1. Access Alerting Policy — Políticas de alerta por tenant/dominio/evento
--    Define QUÉ identity event notificar, a QUIÉN, por QUÉ CANALES
-- ============================================================
CREATE TABLE IF NOT EXISTS bAuth.cfg_notification_policy (
    policy_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL,
    domain          TEXT NOT NULL,
    event_type      TEXT NOT NULL,
    severity        TEXT NOT NULL,
    channels        TEXT[] NOT NULL,     -- '{WHATSAPP,SMS,EMAIL,PUSH,CHAT}'
    notify_roles    UUID[],              -- roles a notificar
    novu_template   TEXT NOT NULL,       -- ID del template en Novu
    enabled         BOOLEAN DEFAULT TRUE,
    ctx_id          TEXT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (tenant_id, domain, event_type),
    CONSTRAINT chk_cfg_notif_domain  CHECK (domain IN ('AUTH','FINANCIAL','PHYSICAL','TEMPORAL','ADMIN')),
    CONSTRAINT chk_cfg_notif_sev     CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    CONSTRAINT chk_cfg_notif_channel CHECK (channels <@ ARRAY['WHATSAPP','SMS','EMAIL','PUSH','CHAT']::TEXT[])
);

-- ============================================================
-- 2. Mapeo dominio → canal Mattermost
-- ============================================================
CREATE TABLE IF NOT EXISTS bAuth.cfg_domain_channel (
    mapping_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL,
    domain                  TEXT NOT NULL,
    mattermost_team_id      VARCHAR(26) NOT NULL,
    mattermost_channel_id   VARCHAR(26) NOT NULL,
    mattermost_channel_name TEXT NOT NULL,   -- 'compliance', 'seguridad', etc.
    webhook_id              VARCHAR(26) NOT NULL,
    webhook_url             TEXT NOT NULL,
    vault_path              TEXT NOT NULL,
    enabled                 BOOLEAN DEFAULT TRUE,
    ctx_id                  TEXT NOT NULL,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (tenant_id, domain),
    CONSTRAINT chk_cfg_dc_domain CHECK (domain IN ('FINANCIAL','PHYSICAL','AUTH','TEMPORAL','ADMIN'))
);

-- ============================================================
-- 3. Registro de notificaciones enviadas (espejo local)
-- ============================================================
CREATE TABLE IF NOT EXISTS bAuth.aud_notification (
    notification_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aud_event_id            UUID NOT NULL,
    novu_template           TEXT NOT NULL,
    transaction_id          TEXT NOT NULL UNIQUE,  -- = ctx_id
    channel                 TEXT NOT NULL,
    recipient_id            UUID NOT NULL,
    mattermost_channel_id   VARCHAR(26),
    mattermost_post_id      VARCHAR(26),
    status                  TEXT DEFAULT 'PENDING',
    provider_msg_id         TEXT,
    sent_at                 TIMESTAMPTZ,
    delivered_at            TIMESTAMPTZ,
    error_message           TEXT,
    ctx_id                  TEXT NOT NULL,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_aud_notif_channel CHECK (channel IN ('WHATSAPP','SMS','EMAIL','PUSH','CHAT')),
    CONSTRAINT chk_aud_notif_status  CHECK (status IN ('PENDING','SENT','DELIVERED','READ','FAILED'))
);

CREATE INDEX IF NOT EXISTS idx_aud_notif_event   ON bAuth.aud_notification(aud_event_id);
CREATE INDEX IF NOT EXISTS idx_aud_notif_txn     ON bAuth.aud_notification(transaction_id);
CREATE INDEX IF NOT EXISTS idx_aud_notif_channel ON bAuth.aud_notification(channel, status);
```

---

## 9. Secretos en Vault

```
secret/bauth/collab/
├── novu/
│   ├── api-key
│   └── webhook-signing-secret
├── twilio/
│   ├── account-sid
│   ├── auth-token
│   └── phone-numbers/{whatsapp, sms}
├── sendgrid/
│   └── api-key
├── mattermost/
│   └── {tenant_id}/
│       ├── admin-token
│       ├── compliance_hook_url
│       ├── seguridad_hook_url
│       ├── auth_hook_url
│       ├── operaciones_hook_url
│       └── admin_hook_url
├── fcm/
│   └── service-account-key
└── apns/
    ├── key-id
    ├── team-id
    └── private-key
```

---

## 10. Governance Platform Implementation Roadmap (Post-bAuth)

### Fase 1: Fundación — DDL + Esquema (Semana 1-2)

| # | Tarea | Depende de |
|---|-------|-----------|
| 1.1 | Completar reconstrucción DDL bAuth (0 errores, idempotente) | PLAN-RECONSTRUCCION-DDL.md FASE 2 |
| 1.2 | Crear 3 tablas de notificación + 7 tablas bCalendar | 1.1 |
| 1.3 | Ejecutar DDL en `bauth_test` (VPS) → 0 ERRORES | 1.2 |
| 1.4 | Seeds: 38 políticas de notificación + 11 templates Novu | 1.3 |
| 1.5 | Seeds: feriados Bolivia 2025-2030, gestiones base | 1.3 |

### Fase 2: Motor de Notificaciones (Semana 3-4)

| # | Tarea | Depende de |
|---|-------|-----------|
| 2.1 | `NotificationDispatcher` en Rust (`domain/notification.rs`) | 1.4 |
| 2.2 | Cliente JSON-RPC para Novu (`server/novu_client.rs`) | 2.1 |
| 2.3 | Hooks de notificación en cada DomainEvaluator (D2, D3, D4) | 2.1 |
| 2.4 | Reconcile loop de notificaciones (cada 15min) | 2.2 |
| 2.5 | Webhook receiver `POST /bauth/notifications/callback` | 2.2 |
| 2.6 | Instalar Novu (ficha `novu`) + FerretDB (ficha `ferretdb`) en VPS | — |
| 2.7 | Crear 11 templates en Novu vía API | 2.6 |

### Fase 3: Canales de Notificación (Semana 5-6)

| # | Tarea | Depende de |
|---|-------|-----------|
| 3.1 | Configurar Twilio (WhatsApp + SMS) | 2.6 |
| 3.2 | Configurar SendGrid → Postfix (Email) | 2.6 |
| 3.3 | Configurar FCM/APNS (Push) | 2.6 |
| 3.4 | Instalar Mattermost (ficha `mattermost`) en VPS | — |
| 3.5 | Crear 5 canales de auditoría + 5 webhooks por tenant vía API | 3.4 |
| 3.6 | Configurar OIDC Mattermost ↔ Keycloak | 3.4 |
| 3.7 | Probar los 5 canales end-to-end | 3.1-3.6 |

### Fase 4: Calendario y Compliance (Semana 7-8)

| # | Tarea | Depende de |
|---|-------|-----------|
| 4.1 | Instalar Cal.com (ficha `calcom`) + Nager.Date (ficha `nager-date`) | — |
| 4.2 | Configurar OIDC Cal.com ↔ Keycloak | 4.1 |
| 4.3 | Seeds de feriados Bolivia + LATAM | 4.1 |
| 4.4 | `resolve_interval_status()` — herencia de cierre fiscal | 1.2 |
| 4.5 | Cron de vencimientos (cada 60min) + auto-revocación delegaciones | 1.2, 2.2 |
| 4.6 | Instalar PostgREST sobre schema `bCalendar` | 1.2 |

### Fase 5: Dashboard y Monitoreo (Semana 9)

| # | Tarea | Depende de |
|---|-------|-----------|
| 5.1 | Dashboard Grafana: eventos por dominio + tasa de entrega | 2.1 |
| 5.2 | Alertas Prometheus: notificaciones fallidas > 5%, servicios down | 2.6, 3.4 |
| 5.3 | Pruebas de estrés: 1000 notificaciones simultáneas | 3.7 |

---

## 11. Identity Event Test Scenarios (Pruebas End-to-End)

| # | Escenario | Dominio | Evento Esperado | Canales a Verificar |
|---|----------|---------|----------------|-------------------|
| T01 | Cajero excede límite diario $10K | D3 | `FIN_LIMIT_EXCEEDED` | WHATSAPP + SMS + EMAIL + CHAT |
| T02 | Mismo usuario crea y aprueba factura | D3 | `FIN_SOD_VIOLATION` | WHATSAPP + CHAT |
| T03 | Acceso denegado a bóveda | D2 | `PHY_ZONE_DENIED` | PUSH + CHAT |
| T04 | Puerta forzada sin credencial | D2 | `PHY_DOOR_FORCED` | WHATSAPP + SMS + PUSH + CHAT |
| T05 | 5 intentos fallidos — cuenta bloqueada | Auth | `AUTH_LOGIN_FAILED_5` | SMS + EMAIL + CHAT |
| T06 | Ataque de fuerza bruta (10 IPs en 60s) | Auth | `AUTH_BRUTE_FORCE_IP` | WHATSAPP + CHAT |
| T07 | Acceso domingo 03:00 | D4 | `TEMP_OUTSIDE_SCHEDULE` | EMAIL |
| T08 | Delegación expira en 24h | D4 | `TEMP_DELEGATION_EXPIRING` | EMAIL + CHAT |
| T09 | SU activa break-glass | Admin | `AUTH_SUPERUSER_ACTIVATED` | WHATSAPP + SMS + EMAIL + CHAT |
| T10 | Vault sellado | Admin | `ADMIN_VAULT_SEALED` | WHATSAPP + SMS + PUSH + CHAT |

### Criterios de Aceptación

| Criterio | Umbral |
|---------|--------|
| Latencia detección → disparo Novu | < 100ms |
| Latencia disparo → entrega WhatsApp | < 5s |
| Latencia disparo → Post en Mattermost | < 2s |
| Tasa de entrega exitosa | ≥ 99.5% |
| Idempotencia (reenvío no duplica) | 0 duplicados en 1000 reenvíos |
| Reconciliación recupera notificaciones perdidas | 100% en < 15min |

---

## 12. Resumen de Artefactos

| Artefacto | Tipo | Ubicación | Estado |
|-----------|------|-----------|--------|
| `BAUTH-TRAZABILIDAD-EVENTOS-AUDITORIA.md` | Este documento | `plandeaccion/bauth/` | ✅ v3.0.0 |
| `PLAN-RECONSTRUCCION-DDL.md` | Plan de reconstrucción DDL | `plandeaccion/bauth/` | ✅ v2.0.0 |
| `001_bauth_init.sql` | DDL bAuth | `BauthAgent/db/migrations/` | 🔴 En reparación (38 errores) |
| `002_bauth_reconstruccion.sql` | DDL reconstrucción | `BauthAgent/db/migrations/` | 🟡 Creado, pendiente depurar |
| `cfg_notification_policy` | Tabla SQL | Parte de `001_bauth_init.sql` | ⚪ No creada |
| `cfg_domain_channel` | Tabla SQL | Parte de `001_bauth_init.sql` | ⚪ No creada |
| `aud_notification` | Tabla SQL | Parte de `001_bauth_init.sql` | ⚪ No creada |
| `seeds/060_notification_policies.sql` | Seeds | `BauthAgent/db/seeds/` | ⚪ No creado |
| `seeds/061_calendar_holidays.sql` | Seeds | `BauthAgent/db/seeds/` | ⚪ No creado |
| `domain/notification.rs` | Código Rust | `BauthAgent/src/domain/` | ⚪ No creado |
| `server/novu_client.rs` | Código Rust | `BauthAgent/src/server/` | ⚪ No creado |
| Ficha `novu` | Ficha BOS | `servers/S06/novu/` | ✅ Creada |
| Ficha `calcom` | Ficha BOS | `servers/S06/calcom/` | ✅ Creada |
| Ficha `mattermost` | Ficha BOS | `servers/S06/mattermost/` | ✅ Creada |
| Ficha `ferretdb` | Ficha BOS | `servers/S06/ferretdb/` | ✅ Creada |

---

## 13. Decisiones de Diseño

| # | Decisión | Fundamento |
|---|---------|-----------|
| D1 | **bAuth no escribe en DBs externas** | Soberanía de datos. bAuth orquesta vía API/JSON-RPC/webhook. |
| D2 | **ctx_id = transactionId en Novu** | Trazabilidad end-to-end sin FKs cross-database. W3C Trace Context + idempotencia. |
| D3 | **`aud_notification` como espejo local** | No depende de Novu para auditoría. Si Novu cae, bAuth sabe qué está pendiente. |
| D4 | **Mattermost es el 5º canal de notificación** | Incoming webhooks nativos. 5 canales de auditoría pre-creados. |
| D5 | **Webhook URLs en Vault, no en bAuth DDL** | Las URLs son secretos. Vault las rota. |
| D6 | **Cal.com + Mattermost comparten OIDC** | Usuario unificado. Baja en bAuth = baja simultánea en los 3 sistemas. |
| D7 | **11 templates Novu definidos por bAuth** | Catálogo cerrado de notificaciones de seguridad. |
| D8 | **FerretDB como puente MongoDB→PostgreSQL** | Novu espera MongoDB, SBOS estandariza PostgreSQL. |
| D9 | **Reconciliación cada 15min** | Recupera notificaciones perdidas si Novu/red falla. |
| D10 | **Escalamiento automático por severidad** | CRITICAL sin ACK en 5min → WhatsApp admin + SMS SU. |

---

*Documento v3.0.0 — 2026-06-23. Unifica BAUTH-INTEGRACION-COLLAB-DB.md (v2.0.0) y BAUTH-TRAZABILIDAD-EVENTOS-AUDITORIA.md (v1.0.0) en un solo documento.*
*38 eventos catalogados · 5 dominios · 5 canales de notificación · 3 tablas DDL nuevas · 5 fases de implementación · 10 escenarios de prueba.*
