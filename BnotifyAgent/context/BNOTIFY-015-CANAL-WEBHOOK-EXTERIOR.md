---
codigo: BNOTIFY-015
version: 1.0.0
estado: BORRADOR
gate: G1
depende_de: [BNOTIFY-010]
doctrina_que_ejerce: [D4, D5, D14]
criterio_implementado: >
  El adaptador webhook entrega un evento de prueba (evento invoice.issued, clase B)
  a un endpoint HTTPS externo de prueba (webhook.site o similar). El endpoint recibe
  el payload CloudEvents con los headers de firma correctos. La verificación de firma
  en el receptor con la clave pública del ecosistema retorna válido. Verificado con
  verificar_afirmacion.sh en VPS.
---

# BNOTIFY-015 — Canal Webhook Exterior
## Adaptador de frontera con terceros: CloudEvents sobre HTTP firmado

**Versión:** 1.0.0 · **Gate:** G1 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §B.1 · ADR-001 ("el mundo exterior habla HTTP porque no le queda otra")

**El único HTTP legítimo del núcleo:**
> Este adaptador es la frontera entre el ecosistema SBOS y el mundo exterior.
> Los terceros (sistemas del cliente, integraciones externas) no hablan gRPC —
> hablan HTTP. Aquí vive ese HTTP, encapsulado, firmado, con reintentos y auditoría.
> Nada más del núcleo usa HTTP salvo este adaptador y el adaptador de chat (BNOTIFY-011).

---

## 1. Propósito y casos de uso

El canal webhook es para **integraciones salientes hacia sistemas externos** del cliente:
- ERP del cliente recibe evento cuando se emite una factura
- Sistema CRM del cliente recibe evento cuando un usuario actualiza su perfil
- Plataforma de pagos recibe evento cuando se completa una transacción

El receptor del webhook es **externo al ecosistema SBOS** — puede ser cualquier
servicio HTTP que el cliente configure. Por eso la seguridad es crítica:
firma Ed25519 en cada entrega para que el receptor pueda verificar la autenticidad.

---

## 2. Formato CloudEvents (CE 1.0)

Todos los webhooks siguen el estándar **CloudEvents 1.0** (CNCF):

```json
{
  "specversion": "1.0",
  "type": "sbos.{event_type}",
  "source": "https://bnotify.{tenant_id}.sbos.app",
  "id": "{delivery_id}",
  "time": "2026-07-06T12:00:00Z",
  "datacontenttype": "application/json",
  "sbosctxid": "{ctx_id}",
  "sbostenat": "{tenant_id}",
  "data": {
    "event_type": "{event_type}",
    "template_data": { ...datos del intent... }
  }
}
```

### 2.1 Headers HTTP obligatorios

```
Content-Type: application/cloudevents+json; charset=UTF-8
X-SBOS-Delivery-Id: {delivery_id}
X-SBOS-Timestamp: {unix_timestamp}
X-SBOS-Signature: ed25519={base64(sign(body))}
```

La firma es Ed25519 sobre el body completo (bytes UTF-8) usando la clave privada del
ecosistema (gestionada por Vault). El receptor puede verificar la firma con la clave
pública publicada en `GET /.well-known/sbos-webhooks.json` del tenant.

---

## 3. Configuración del endpoint de webhook

Los endpoints de webhook se registran por tenant en `bnotify.webhook_endpoint`:

```sql
-- Tabla en schema bnotify (agregar a BNOTIFY-008 §3 en la próxima versión)
CREATE TABLE bnotify.webhook_endpoint (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       TEXT        NOT NULL,
    name            TEXT        NOT NULL,               -- Nombre descriptivo
    url             TEXT        NOT NULL,               -- URL HTTPS del receptor
    event_types     TEXT[]      NOT NULL DEFAULT '{}',  -- [] = todos los eventos
    active          BOOLEAN     NOT NULL DEFAULT TRUE,
    timeout_secs    SMALLINT    NOT NULL DEFAULT 30,
    max_retries     SMALLINT    NOT NULL DEFAULT 3,
    ctx_id          UUID        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## 4. Política de reintentos y DLQ

El webhook hereda la política de reintentos del núcleo (BNOTIFY-010 §4):

| Clase | Reintentos | Backoff | DLQ |
|-------|:----------:|---------|:---:|
| A | 5 | 30s, 60s, 120s, 300s, 600s | Sí + alarma |
| B | 3 | 60s, 300s, 900s | Sí + alarma |
| C | 1 | — | No (descarta) |

Casos de `FAILED_PERMANENT` (sin reintento):
- HTTP 4xx del receptor (excepto 429 — ese es FAILED_TEMPORARY)
- SSL/TLS error por certificado inválido del receptor (el receptor tiene la culpa)
- URL inválida o dominio inexistente

---

## 5. Seguridad del endpoint

### 5.1 Solo HTTPS

El adaptador rechaza URLs HTTP (sin TLS). Toda entrega es HTTPS.
Si el cliente quiere HTTP por alguna razón interna, es su responsabilidad — bNotify
no lo soporta para proteger la confidencialidad del payload.

### 5.2 Verificación de la firma (responsabilidad del receptor)

El receptor puede verificar:
```
1. Obtener clave pública de: GET https://bauth.sbos.internal/auth/oidc/jwks (misma CA)
   o de: GET https://bnotify.{tenant_id}.sbos.app/.well-known/sbos-webhooks.json
2. Verificar: ed25519_verify(body_bytes, base64_decode(header_X_SBOS_Signature), public_key)
3. Verificar que X-SBOS-Timestamp es reciente (tolerancia ±5 minutos) — previene replay
```

### 5.3 Allowlist de IPs

Si el cliente quiere restringir qué IPs pueden llamar a su webhook, bNotify publica
sus IPs de egreso en `GET https://bnotify.{tenant_id}.sbos.app/.well-known/egress-ips.json`.

---

## 6. Código Rust — estructura del adaptador

```
src/channel/webhook/
├── mod.rs              # Implementación del trait AdapterChannel para webhook
├── config.rs           # WebhookConfig: url_registry, signing_key_path
├── http_client.rs      # Cliente HTTP (reqwest + rustls) con timeout + retry wrapper
├── signer.rs           # Firma Ed25519 del payload (clave desde Vault)
└── endpoint_registry.rs # Lee bnotify.webhook_endpoint desde PostgreSQL
```

---

*BNOTIFY-015 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*El mundo exterior habla HTTP porque no le queda otra. Aquí lo recibimos y lo firmamos. Afuera de aquí, todo es gRPC.*
