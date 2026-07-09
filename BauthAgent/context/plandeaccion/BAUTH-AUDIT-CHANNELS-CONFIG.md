# BAUTH-AUDIT-CHANNELS-CONFIG.md — Configuración Inicial de Canales de Auditoría

**Versión:** 1.0 · **Fecha:** 2026-06-23 · **Autor:** sbos-coordinador
**Fichas de referencia:** `servers/S06/mattermost/manifest.yml` · `servers/S06/novu/manifest.yml` · `servers/S06/calcom/manifest.yml`
**DDL relacionada:** `DDL_skSBOS_db.sql` · Tablas: `cfg_domain_channel`, `cfg_notification_policy`, `idn_tenant_domain`, `cal_notification_log`

---

## 1. PROPÓSITO

Documentar la configuración inicial de canales de auditoría del SBOS tal como están definidos
en las fichas de despliegue y su correspondencia con las tablas de la base de datos.

**Principio:** Los canales de notificación NO se crean manualmente. Vienen predefinidos en la ficha
de Mattermost y se materializan en la BD como seeds idempotentes. Toda notificación de auditoría
viaja por estos canales con ctx_id obligatorio para trazabilidad completa.

---

## 2. CANALES DEFINIDOS EN LA FICHA MATTERMOST

Fuente: `BosAgent/src/servers/S06/mattermost/manifest.yml` (líneas 74-94)

| # | Canal | Dominio bAuth | Propósito | Webhook Vault Path |
|---|-------|--------------|-----------|-------------------|
| 1 | `#compliance` | `FINANCIAL` (D3) | Límites excedidos, SoD violado, tx rechazadas, reportes SIN | `secret/bauth/collab/mattermost/{tenant}/compliance_hook_url` |
| 2 | `#seguridad` | `PHYSICAL` (D2) | Accesos denegados, puertas forzadas, alarmas OSDP, CCTV | `secret/bauth/collab/mattermost/{tenant}/seguridad_hook_url` |
| 3 | `#auth-alerts` | `AUTH` | Bloqueos de cuenta, step-up MFA, brute force, resets | `secret/bauth/collab/mattermost/{tenant}/auth_hook_url` |
| 4 | `#operaciones` | `TEMPORAL` (D4) | Fuera de horario, delegaciones expiradas, cierres de gestión | `secret/bauth/collab/mattermost/{tenant}/operaciones_hook_url` |
| 5 | `#admin` | `ADMIN` | SU break-glass, rotación de llaves, backups fallidos, sync errors | `secret/bauth/collab/mattermost/{tenant}/admin_hook_url` |

### Idempotencia

La ficha Mattermost verifica que los 5 canales existen antes de reportar éxito:

```yaml
idempotency_checks:
  - check: audit_channels_exist
    value: "5 canales de auditoría creados"
    description: "Verifica que #compliance, #seguridad, #auth-alerts, #operaciones, #admin existen."
```

---

## 3. CORRESPONDENCIA CON TABLAS DDL

### 3.1 — `cfg_domain_channel` (ITDR — Identity Threat Detection & Response)

Mapea cada dominio bAuth a su canal Mattermost. Tabla definida en el plan de reconstrucción
(PLAN-RECONSTRUCCION-DDL.md, GAP-07).

```sql
CREATE TABLE bauth.cfg_domain_channel (
    channel_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID NOT NULL REFERENCES idn_tenant(tenant_id),
    domain           TEXT NOT NULL,        -- FINANCIAL, PHYSICAL, AUTH, TEMPORAL, ADMIN
    channel_name     TEXT NOT NULL,        -- #compliance, #seguridad, #auth-alerts, #operaciones, #admin
    webhook_url      TEXT NOT NULL,        -- Vault path o URL directa
    is_active        BOOLEAN DEFAULT true,
    ctx_id           TEXT NOT NULL,
    UNIQUE (tenant_id, domain)
);
```

### 3.2 — `cfg_notification_policy` (ITDR)

Define qué eventos disparan notificación por qué canales y con qué severidad.

```sql
CREATE TABLE bauth.cfg_notification_policy (
    policy_id        UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id        UUID NOT NULL REFERENCES idn_tenant(tenant_id),
    event_type       TEXT NOT NULL,        -- FIN_LIMIT_EXCEEDED, AUTH_BRUTE_FORCE_IP, PHY_DOOR_FORCED...
    severity         TEXT NOT NULL DEFAULT 'WARNING',
    channels         TEXT[] NOT NULL,      -- {EMAIL, CHAT, SMS, WHATSAPP}
    cooldown_minutes INTEGER DEFAULT 15,
    is_active        BOOLEAN DEFAULT true,
    ctx_id           TEXT NOT NULL,
    UNIQUE (tenant_id, event_type)
);
```

### 3.3 — Trazabilidad completa con ctx_id

Cada notificación viaja con ctx_id desde el evento hasta el log WORM:

```
Evento detectado (bauth)
    │ ctx_id: 019ef51f-...
    ├─▶ cfg_notification_policy ──▶ ¿qué canales para este event_type?
    ├─▶ cfg_domain_channel ──▶ ¿qué webhook para este dominio?
    ├─▶ Novu trigger ──▶ workflow 5 pasos
    ├─▶ Mattermost incoming webhook ──▶ mensaje en #compliance
    └─▶ cal_notification_log ──▶ WORM: channel, recipient, outcome, ctx_id
```

---

## 4. CADENA DE NOTIFICACIÓN POR DOMINIO

### Ejemplo D3 Financiero: Límite excedido

```
1. Evento: FIN_LIMIT_EXCEEDED
   ctx_id: 019ef51f-fc83-71a1-ae77-b997bb3b4987

2. cfg_notification_policy lookup:
   event_type = FIN_LIMIT_EXCEEDED → channels = {EMAIL, CHAT}, severity = WARNING

3. cfg_domain_channel lookup:
   domain = FINANCIAL → channel = #compliance, webhook = mattermost.sbos-collab:8065/hooks/xxx

4. bauth → Novu (JSON-RPC 2.0, Unix socket /run/bos/bos.sock):
   {
     "method": "bnotify.trigger",
     "params": {
       "workflow_id": "audit_alert_financiero",
       "subscriber_id": "<compliance_officer_uuid>",
       "payload": {
         "event_type": "FIN_LIMIT_EXCEEDED",
         "severity": "WARNING",
         "details": "Operación Bs. 50,000 excede límite diario Bs. 25,000",
         "ctx_id": "019ef51f-fc83-71a1-ae77-b997bb3b4987"
       }
     }
   }

5. Novu workflow (5 pasos):
   Step 1: EMAIL → compliance@skull.bo (vía SMTP config en idn_tenant_domain.email_config)
   Step 2: CHAT → Mattermost #compliance (vía incoming webhook)

6. Mattermost #compliance:
   🔔 [WARNING] FIN_LIMIT_EXCEEDED
   Operación Bs. 50,000 excede límite diario Bs. 25,000
   Usuario: Juan Pérez · Sucursal: La Paz · POS: CAJA-01
   ctx_id: 019ef51f-fc83-71a1-ae77-b997bb3b4987

7. cal_notification_log (WORM, solo INSERT):
   INSERT INTO cal_notification_log (alarm_id, event_id, channel, recipient_id, outcome, ctx_id)
   VALUES (...)
```

---

## 5. FLUJO COMPLETO DE TRAZABILIDAD

```
┌──────────────────────────────────────────────────────────────────────┐
│                      TRAZABILIDAD END-TO-END                         │
│                                                                      │
│  ctx_id = 019ef51f-fc83-71a1-ae77-b997bb3b4987                      │
│       │                                                              │
│       ├── bauth.audit_event        (evento original)                 │
│       ├── bauth.cfg_notification_policy (política aplicada)          │
│       ├── bauth.cfg_domain_channel      (canal seleccionado)         │
│       ├── bcalendar.cal_alarm           (disparador programado)      │
│       ├── bcalendar.cal_notification_log (WORM — envío registrado)  │
│       ├── Mattermost #compliance         (mensaje en chat)           │
│       └── bcalendar.cal_audit_log        (bi-temporal ISO SQL:2011) │
│                                                                      │
│  RECONSTRUCCIÓN:                                                     │
│  SELECT * FROM cal_audit_log WHERE ctx_id = '019ef51f-...'          │
│  → Trazabilidad completa del evento en 6 tablas, 3 sistemas.        │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 6. EXPERIENCIAS SIMILARES — INDUSTRIA

### 6.1 — SOC 2 Type II / ISO 27001

| Sistema | Canales predefinidos | Trazabilidad |
|---------|---------------------|--------------|
| **AWS CloudTrail** | SNS topics por tipo de evento (management, data, insight) | `requestId` en cada API call |
| **GCP Audit Logs** | Pub/Sub topics + Cloud Logging sinks | `trace_id` vía OpenTelemetry |
| **Datadog Security** | Monitors → Slack/OpsGenie/PagerDuty | `@trace_id` en cada alerta |
| **Splunk SOAR** | Playbooks por severidad → Slack/Teams/Email | `incident_id` correlaciona |
| **GitLab Audit Events** | Streaming a destino externo (HTTP endpoint) | `correlation_id` en cada request |

**Patrón común:** Canales predefinidos por dominio/severidad + ID único de trazabilidad que viaja por toda la cadena. SBOS aplica este patrón con ctx_id (W3C Trace Context).

### 6.2 — Autenticación y Cumplimiento

| Sistema | Canales de alerta | Norma |
|---------|-------------------|-------|
| **Keycloak 26** | Event listener SPI → syslog/email/webhook | OWASP ASVS V7.1 |
| **Okta** | System Log → Splunk/SumoLogic/Slack | SOC 2 CC7.1 |
| **Auth0** | Log Streams → Datadog/Splunk/Azure | PCI DSS 10.3 |
| **Ping Identity** | Alert Policies → SIEM/PagerDuty | NIST 800-53 AU-7 |

**Conclusión:** Los 5 canales de Mattermost + Novu + cal_notification_log WORM + ctx_id
colocan al SBOS al mismo nivel de trazabilidad que los sistemas enterprise, con la ventaja
de ser soberano (sin dependencia de servicios externos).

---

## 7. SEED INICIAL REQUERIDO

Al crear un tenant, se deben poblar automáticamente:

### 7.1 — `cfg_domain_channel` (5 registros por tenant)

| domain | channel_name | webhook_vault_path |
|--------|-------------|-------------------|
| FINANCIAL | compliance | secret/bauth/collab/mattermost/{tenant}/compliance_hook_url |
| PHYSICAL | seguridad | secret/bauth/collab/mattermost/{tenant}/seguridad_hook_url |
| AUTH | auth-alerts | secret/bauth/collab/mattermost/{tenant}/auth_hook_url |
| TEMPORAL | operaciones | secret/bauth/collab/mattermost/{tenant}/operaciones_hook_url |
| ADMIN | admin | secret/bauth/collab/mattermost/{tenant}/admin_hook_url |

### 7.2 — `cfg_notification_policy` (38+ registros por tenant)

Los 38 eventos domain-specific definidos en BAUTH-IDENTITY-GOVERNANCE-GAPS.md GAP-05:

| event_type | severity | channels | cooldown |
|-----------|----------|----------|----------|
| FIN_LIMIT_EXCEEDED | WARNING | {EMAIL, CHAT} | 15 min |
| FIN_SOD_VIOLATION | CRITICAL | {EMAIL, SMS, CHAT, WHATSAPP} | 5 min |
| AUTH_BRUTE_FORCE_IP | CRITICAL | {SMS, CHAT} | 5 min |
| AUTH_SUPERUSER_ACTIVATED | CRITICAL | {EMAIL, SMS, CHAT, WHATSAPP} | 1 min |
| PHY_DOOR_FORCED | CRITICAL | {SMS, CHAT, WHATSAPP} | 1 min |
| ... | ... | ... | ... |

### 7.3 — `bcalendar.cal_calendar` (6 registros por tenant)

| name | calendar_type | is_system |
|------|-------------|-----------|
| Work | WORK | true |
| Fiscal | FISCAL | true |
| Process | PROCESS | true |
| Compliance | COMPLIANCE | true |
| Holidays | HOLIDAY | true |
| Maintenance | MAINTENANCE | true |

---

## 8. VERIFICACIÓN DE IDEMPOTENCIA

La ficha Mattermost verifica idempotencia con:

```yaml
idempotency_checks:
  - check: audit_channels_exist
    value: "5 canales de auditoría creados"
```

Las tablas DDL equivalentes:

```sql
-- Verificar canales creados para un tenant
SELECT count(*) = 5 FROM cfg_domain_channel WHERE tenant_id = $1 AND is_active = true;

-- Verificar políticas cargadas
SELECT count(*) >= 38 FROM cfg_notification_policy WHERE tenant_id = $1 AND is_active = true;

-- Verificar calendarios del sistema creados
SELECT count(*) = 6 FROM bcalendar.cal_calendar WHERE tenant_id = $1 AND is_system = true;
```

---

*Documento generado 2026-06-23. Las 5 fichas (mattermost, novu, calcom) + las tablas DDL + ctx_id
forman el sistema de trazabilidad y auditoría del SBOS. Sin esta configuración inicial,
un tenant no puede recibir notificaciones de auditoría.*
