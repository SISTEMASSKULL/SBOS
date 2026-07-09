---
codigo: BNOTIFY-044
version: 1.0.0
estado: BORRADOR
gate: G4
depende_de: [BNOTIFY-040, BNOTIFY-012]
doctrina_que_ejerce: [D2, D6, D14, D15]
criterio_implementado: >
  Etapa 1: Roundcube 1.6.x desplegado en K8s con SSO via bAuth OIDC.
  Un usuario puede enviar y recibir email desde Roundcube autenticado con su JWT bAuth.
  Etapa 2 (decisión futura): el cliente nativo en bChat muestra el inbox IMAP/JMAP.
  Un email nuevo aparece como badge en bChat en < 60s.
  Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-044 — Módulo Correo
## Etapa 1: Roundcube SSO; etapa 2 (decisión por datos): cliente nativo IMAP/JMAP

**Versión:** 1.0.0 · **Gate:** G4 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-040 (módulos), BNOTIFY-012 (canal email saliente), ADR futura

---

## 1. Filosofía en dos etapas

El correo es una de las funcionalidades más complejas del ecosistema. Desarrollar un cliente de correo nativo completo antes de tener usuarios reales sería desperdiciar recursos en suposiciones. Se adopta una estrategia en dos etapas:

### Etapa 1 (Gate G4): Roundcube + SSO bAuth
- Roundcube 1.6.x como cliente web de correo
- SSO via bAuth OIDC — el usuario no tiene contraseña de correo separada
- Integrado como iframe/webview dentro de bChat (acceso desde el menú lateral)
- Notificación de correo nuevo vía bNotify → badge en bChat

### Etapa 2 (decisión por datos): Cliente nativo IMAP/JMAP
- Si los datos de uso muestran que los usuarios pasan >30% del tiempo en Roundcube desde bChat → desarrollar cliente nativo en Flutter con el motor Rust manejando IMAP4rev2 o JMAP
- Si los datos muestran que los usuarios prefieren abrir Roundcube directamente → mantener Etapa 1 y no invertir en el cliente nativo

**La decisión de Etapa 2 es HITL (Human In The Loop) — requiere aprobación del humano con datos reales.**

---

## 2. Despliegue Roundcube (Etapa 1)

```yaml
# K8s namespace: bns-messaging
# Deployment: roundcube

apiVersion: apps/v1
kind: Deployment
metadata:
  name: roundcube
  namespace: bns-messaging
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: roundcube
          image: roundcube/roundcubemail:1.6.x-apache
          env:
            - name: ROUNDCUBEMAIL_DB_TYPE
              value: pgsql
            - name: ROUNDCUBEMAIL_DB_HOST
              value: postgres.infra
            - name: ROUNDCUBEMAIL_DEFAULT_HOST
              value: postfix.infra   # Servidor Postfix SBOS
            - name: ROUNDCUBEMAIL_SMTP_SERVER
              value: postfix.infra
```

### 2.1 Plugin OIDC para Roundcube

Se utiliza el plugin `roundcube-oidc` (disponible en packagist) configurado contra bAuth:

```php
// config.inc.php — configuración del plugin OIDC
$config['oauth_provider'] = 'generic';
$config['oauth_provider_name'] = 'SBOS';
$config['oauth_client_id'] = 'roundcube-{tenant_id}';
$config['oauth_client_secret'] = getenv('ROUNDCUBE_OIDC_SECRET');
$config['oauth_auth_uri'] = 'https://bauth.sbos.internal/authorize';
$config['oauth_token_uri'] = 'https://bauth.sbos.internal/token';
$config['oauth_identity_uri'] = 'https://bauth.sbos.internal/userinfo';
$config['oauth_scope'] = 'openid profile email';
```

---

## 3. Notificación de correo nuevo → badge en bChat

bNotify actúa como puente entre el servidor de correo y el sistema de notificaciones:

```
Postfix (correo entrante)
│
│  Sieve filter: nuevo correo → evento → bNotify
│  (script Sieve con backend PostgreSQL de eventos)
▼
bNotify (evento: mail.INBOX_NEW)
│
│  → Dispatch al canal InApp (bChat)
│  → Tipo de mensaje: 'mail_notification'
│    { from: "remitente@ejemplo.com", subject: "Asunto...", count: N }
▼
Cliente Flutter
│  → Badge en el ícono de correo del menú lateral
│  → Tap → abre Roundcube/cliente nativo
```

### 3.1 Schema para estado del inbox

```sql
-- bnotify schema: contador de no leídos por usuario
CREATE TABLE bnotify.mail_inbox_state (
    tenant_id       TEXT    NOT NULL,
    bauth_user_id   UUID    NOT NULL,
    unread_count    INT     NOT NULL DEFAULT 0,
    last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (tenant_id, bauth_user_id)
);
```

---

## 4. Condiciones para activar Etapa 2

La decisión de desarrollar el cliente nativo se activa cuando **cualquiera** de estas condiciones se cumple durante 30 días consecutivos:

| Métrica | Umbral de activación |
|---------|---------------------|
| % de usuarios que abren correo desde bChat | > 40% del total de usuarios activos |
| Solicitudes de feature "cliente nativo" en buzón Bibliotecario | > 5 solicitudes distintas |
| Roundcube muestra latencia p95 > 3s | Más de 3 días en el mes |

Cuando se activa, el humano aprueba la etapa 2 y se abre una nueva tarea en el Coordinador.

---

## 5. Protocolo para Etapa 2 (si se activa)

Si se decide desarrollar el cliente nativo:

- **Protocolo:** JMAP (RFC 8620 + 8621) — más moderno que IMAP4rev2, tiene API JSON nativa
- **Servidor JMAP:** Stalwart Mail Server (Rust nativo, soporta JMAP + SMTP + IMAP) como reemplazo de Postfix/Dovecot
- **Schema:** nuevo schema `correo` en SBOS_db (D18 — dueño exclusivo)
- **Cliente Flutter:** nuevo módulo en bchat-flutter (`lib/mail/`)
- **E2EE:** el módulo de correo puede usar S/MIME (existente) o PGP (futura decisión) — la encriptación la maneja el cliente, el servidor solo almacena cifrado

---

*BNOTIFY-044 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*Roundcube hoy, cliente nativo si los datos lo justifican. No se construye lo que no se ha demostrado necesitar.*
