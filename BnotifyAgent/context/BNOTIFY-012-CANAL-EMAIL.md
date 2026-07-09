---
codigo: BNOTIFY-012
version: 1.0.0
estado: BORRADOR
gate: G1
depende_de: [BNOTIFY-010]
doctrina_que_ejerce: [D4, D5, D14]
criterio_implementado: >
  El adaptador email entrega un correo de prueba a una dirección real del sistema
  (evento invoice.issued, clase B). El correo llega con subject y body renderizados
  correctamente desde la plantilla. El DKIM del correo es válido (verificado con
  un checker externo o con el log de Postfix). Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-012 — Canal Email
## Adaptador de email: Postfix/Dovecot + plantillas HTML/texto

**Versión:** 1.0.0 · **Gate:** G1 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §4.2, ADR-001 (gRPC entre daemons — email es adaptador de frontera)

---

## 1. Stack de email del ecosistema

| Componente | Versión | Rol |
|-----------|:-------:|-----|
| **Postfix** | 3.9.x | MTA — envío SMTP saliente |
| **Dovecot** | 2.3.x | IMAP/POP3 — buzones de usuarios |
| **SPF, DKIM, DMARC** | — | Reputación del dominio |
| **Roundcube** (futuro C4) | — | Webmail. Módulo `bnotify.correo` (BNOTIFY-044) |

El adaptador de bNotify solo usa **Postfix** para envío. Dovecot es para los buzones
de los usuarios — lo gestionará el módulo de correo (BNOTIFY-044) en G4.

---

## 2. Configuración del adaptador

```toml
# /etc/bnotify/adapters/email.toml
[smtp]
host = "postfix.infra.svc.cluster.local"
port = 587
starttls = true
# usuario y password SMTP inyectados desde Vault: sbos/bnotify/adapters/email/smtp
from_address = "notificaciones@{tenant_id}.sbos.app"
from_name = "SBOS Notificaciones"
timeout_secs = 30

[limits]
max_subject_bytes = 998  # RFC 5321
max_body_bytes = 10485760  # 10 MB
```

---

## 3. Formato de los mensajes

### 3.1 Plantillas multipart

Los emails se envían en formato **multipart/alternative** (texto plano + HTML):
- El texto plano es el `body` del `DeliverRequest` (ya renderizado por el núcleo)
- El HTML se genera desde una plantilla HTML separada en `bnotify.template`
  (channel='email_html', mismo event_type + locale)

Si no existe plantilla HTML, se envía solo texto plano (siempre funciona).

### 3.2 Subject

El `subject` viene del campo `subject` del `DeliverRequest`, ya renderizado por el núcleo
(template engine). Si está vacío, se usa el `event_type` como fallback.

### 3.3 Headers obligatorios

```
Message-ID: <{delivery_id}@{tenant_id}.sbos.app>
X-SBOS-Ctx-Id: {ctx_id}
X-SBOS-Delivery-Id: {delivery_id}
X-SBOS-Event-Type: {event_type}
```

El `Message-ID` basado en `delivery_id` permite correlacionar el correo con el registro
de entrega en `bnotify.notification_event`.

---

## 4. Manejo de errores SMTP

| Código SMTP | Significado | DeliveryResult |
|:-----------:|-------------|:-------------:|
| 2xx | Aceptado por el MTA | `DELIVERED` |
| 421, 450, 451, 452 | Error temporal (MTA sobrecargado, buzón lleno temporal) | `FAILED_TEMPORARY` |
| 500, 501, 550, 551, 553 | Error permanente (dirección inexistente, rechazado) | `FAILED_PERMANENT` |
| Timeout (>30s) | Postfix no responde | `CHANNEL_UNAVAILABLE` |
| TLS handshake fail | Error de conexión segura | `CHANNEL_UNAVAILABLE` |

---

## 5. Código Rust — estructura del adaptador

```
src/channel/email/
├── mod.rs          # Implementación del trait AdapterChannel para email
├── config.rs       # SmtpConfig: host, port, starttls, from, timeout
└── smtp_client.rs  # Cliente SMTP con lettre — encapsulado aquí
```

```toml
# Cargo.toml — crate email
lettre = { version = "0.11", features = ["tokio1", "smtp-transport", "rustls-tls"] }
```

**Nota:** `lettre` usa `rustls` — nunca `native-tls` ni OpenSSL en el núcleo (BNOTIFY-006 §2.5).

---

## 6. Decisión futura: Roundcube vs cliente nativo (BNOTIFY-044)

El módulo de correo integrado (C4) se decide en BNOTIFY-044 según datos de uso:
- **Etapa 1:** Roundcube CE embebido con SSO bAuth (rápido, cero desarrollo)
- **Etapa 2:** Cliente nativo IMAP/JMAP en Flutter (si los datos justifican la inversión)

Este adaptador (BNOTIFY-012) no se ve afectado por esa decisión — solo gestiona
el envío de notificaciones por email, no el cliente webmail.

---

*BNOTIFY-012 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*El email es el canal de mayor alcance y menor urgencia. DKIM y SPF son obligatorios — sin ellos el correo llega a spam.*
