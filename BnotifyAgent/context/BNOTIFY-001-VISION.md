# BNOTIFY-001-VISION — bnotify: Orquestador Soberano de Notificaciones SBOS
## Sistema multi-canal con bChat como canal principal tipo WeChat · Documento de Visión

**Versión:** 3.0.0 · **Fecha:** 2026-07-05 · **Autor:** bauth-developer
**Clasificación:** Interno · **Estado:** Fundacional
**Corrección v3.0:** bnotify es el ORQUESTADOR. bChat es un CANAL (el principal, pero uno más).
La arquitectura de notificaciones sigue el patrón event-driven multi-channel de la industria.
**Referencia:** `BNOTIFY-000-INDEX.md` · `BNOTIFY-002-LAS-ETAPAS-RUMBO-A-WECHAT.md`

---

## 1. QUÉ ES bnotify

**bnotify es el orquestador central de notificaciones del ecosistema SBOS.** Recibe
eventos del sistema (factura emitida, alarma de calendario, desafío MFA, alerta de
seguridad), los enruta según preferencias del usuario, y los entrega por el canal
correcto.

**bChat NO es el producto. bChat es un canal de bnotify.** El más importante — porque
concentra mensajería, identidad, notificaciones y flujos de negocio en un solo punto
como WeChat — pero es un canal, no el todo.

### El modelo conceptual: Orquestador → Canales

```
                        ┌─────────────────────────────────┐
                        │         bnotify                  │
                        │   ORQUESTADOR DE NOTIFICACIONES  │
                        │                                  │
  Eventos del sistema   │  ┌───────────────────────────┐  │
  ─────────────────────►│  │ Dispatcher                │  │
                        │  │ - Preferencias de usuario │  │
  bKernel WAL           │  │ - Quiet hours             │  │
  bAuth role.changed    │  │ - Rate limiting           │  │
  bCalendar alarm       │  │ - Prioridad (A/B/C)      │  │
  Tryton invoice        │  │ - Templates + i18n        │  │
  Wazuh alert           │  └───────────┬───────────────┘  │
                        │              │                   │
                        │    ┌─────────┴──────────┐       │
                        │    │  Channel Adapters   │       │
                        │    ├────────────────────┤       │
                        │    │ bChat (RChat)      │◄── principal
                        │    │ Email (SMTP)       │       │
                        │    │ SMS (Twilio)       │       │
                        │    │ Push (FCM/APNs)    │       │
                        │    │ In-App (WebSocket)  │       │
                        │    │ Webhook (HTTP)      │       │
                        │    └────────────────────┘       │
                        └─────────────────────────────────┘
```

---

## 2. POR QUÉ bChat ES EL CANAL PRINCIPAL

bChat (Rocket.Chat 8.5.0 CE gobernado por bAuth) es el canal más importante de bnotify
porque es el ÚNICO canal bidireccional. Los demás canales son de salida (sistema → usuario).
bChat es entrada Y salida:

| Canal | Dirección | Tipo de mensaje | Interacción |
|-------|:---------:|-----------------|:-----------:|
| **bChat** | ↔ Bidireccional | Chat, notificaciones, MFA, workflows | El usuario responde, aprueba, firma |
| Email | → Salida | Facturas, reportes, resúmenes | Solo lectura |
| SMS | → Salida | Alertas críticas, MFA fallback | Solo lectura |
| Push | → Salida | MFA challenge, toast | Tap para abrir bChat |
| In-App | → Salida | Toast en desktop, badge | Click para abrir bChat |
| Webhook | → Salida | Integraciones externas | Solo lectura |

**bChat es el destino natural de toda notificación porque el usuario ya está ahí.**
Como WeChat en China — la gente no abre Gmail para ver facturas, abre WeChat.

---

## 3. ARQUITECTURA REAL — PATRÓN EVENT-DRIVEN MULTI-CHANNEL

### 3.1 Principios

1. **Siempre asíncrono.** Ningún daemon SBOS se bloquea esperando que una notificación
   se entregue. El evento se publica y se olvida. bnotify garantiza entrega.

2. **Unix socket + JSON-RPC entre daemons. REST solo hacia afuera.**
   bnotify habla JSON-RPC con bAuth, bKernel, bCalendar. Solo usa REST para hablar
   con bChat (que no es daemon) y con proveedores externos (Twilio, FCM).

3. **Preferencias de usuario gobiernan el enrutamiento.** Un usuario puede elegir
   recibir facturas por bChat, alertas de seguridad por SMS, y MFA por Push.
   bnotify consulta `idn_atributo` (category=notification_prefs) antes de enrutar.

4. **Prioridad A/B/C.** Eventos de seguridad y financieros (clase A) nunca comparten
   cola con notificaciones informativas (clase C). Canales separados por prioridad.

### 3.2 Flujo completo de una notificación

```
1. EVENTO
   Tryton emite factura → INSERT en tryton_db.account_invoice

2. DETECCIÓN (bKernel)
   WAL → bKernel → publica en Redis Stream "biedata:notify:{tenant}"
   payload: {event_type:"invoice.issued", invoice_id:1234, partner_id:567, amount:5000}

3. ENRUTAMIENTO (bnotify Dispatcher)
   ┌─ Consume Redis Stream
   ├─ Resuelve destinatario: partner_id=567 → user_uuid=abc123
   ├─ Consulta preferencias: user_uuid=abc123 → canal preferido=bChat
   ├─ Selecciona template: "invoice_issued_es" → "Factura #{{invoice_id}} por Bs {{amount}}"
   ├─ Verifica prioridad: evento clase B → cola normal
   └─ Enruta a Channel Adapter: bChat

4. ENTREGA (bnotify → bChat REST API)
   POST /api/v1/chat.postMessage
   { roomId: "@abc123", text: "Factura #1234 emitida por Bs 5,000" }

5. REGISTRO (bnotify → notifier_db)
   INSERT INTO notification_events (event_id, channel, recipient, status, ctx_id, delivered_at)
```

### 3.3 Diagrama de arquitectura

```
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ Tryton   │  │ bCalendar│  │ bAuth    │  │ Wazuh    │
│ (ERP)    │  │ (Alarmas)│  │ (MFA)    │  │ (SIEM)   │
└────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘
     │              │              │              │
     ▼              ▼              ▼              ▼
┌─────────────────────────────────────────────────────┐
│              bKernel (CDC + Fanout)                  │
│         WAL → Redis Streams por tenant               │
└───────────────────────┬─────────────────────────────┘
                        │ Redis Stream
                        ▼
┌─────────────────────────────────────────────────────┐
│              bnotify (Orquestador)                    │
│              /run/bos/bnotify.sock                    │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ Dispatcher                                    │   │
│  │  • Preferencias de usuario (idn_atributo)     │   │
│  │  • Resolución de templates (global_message)   │   │
│  │  • Rate limiting + dedup                     │   │
│  │  • Prioridad A/B/C (aud_class)               │   │
│  └──────────────────┬───────────────────────────┘   │
│                     │                                │
│  ┌──────────────────┴───────────────────────────┐   │
│  │ Channel Adapters (Strategy Pattern)           │   │
│  │                                               │   │
│  │  ┌─────────┐ ┌──────┐ ┌─────┐ ┌────┐ ┌────┐ │   │
│  │  │ bChat ▲ │ │Email │ │ SMS │ │Push│ │Web │ │   │
│  │  │(RChat) │ │ │SMTP  │ │Twilio│ │FCM │ │hook│ │   │
│  │  └────┬────┘ └──┬───┘ └──┬──┘ └──┬─┘ └──┬─┘ │   │
│  └───────┼─────────┼────────┼───────┼──────┼────┘   │
└──────────┼─────────┼────────┼───────┼──────┼────────┘
           ▼         ▼        ▼       ▼      ▼
     ┌─────────┐ ┌──────┐ ┌──────┐ ┌────┐ ┌──────────┐
     │ bChat   │ │Email │ │ SMS  │ │Push│ │Webhook   │
     │ Mongo   │ │Server│ │Gateway│ │Proxy│ │Endpoint  │
     └─────────┘ └──────┘ └──────┘ └────┘ └──────────┘
```

---

## 4. bChat — EL CANAL PRINCIPAL (TIPO WECHAT)

### 4.1 Qué hace especial a bChat frente a otros canales

| Capacidad | Email | SMS | Push | bChat |
|-----------|:-----:|:---:|:----:|:-----:|
| Recibir notificaciones | ✅ | ✅ | ✅ | ✅ |
| Responder / interactuar | ❌ | ❌ | ❌ | ✅ |
| Chatear con otros usuarios | ❌ | ❌ | ❌ | ✅ |
| Canales por rol | ❌ | ❌ | ❌ | ✅ |
| Aprobar facturas | ❌ | ❌ | ❌ | ✅ |
| Firmar documentos | ❌ | ❌ | ❌ | ✅ |
| Recibir MFA y responder | ❌ | ❌ | ❌ | ✅ |
| Mini-apps (Deno) | ❌ | ❌ | ❌ | ✅ |
| Historial completo | ❌ | ❌ | ❌ | ✅ |

bChat es el ÚNICO canal donde el usuario puede INTERACTUAR con el sistema, no solo
recibir mensajes. Por eso es el canal principal — pero sigue siendo un canal de bnotify.

### 4.2 Rocket.Chat como base: lo que se usa y lo que no

**Se usa de Rocket.Chat CE (gratis):**
- Motor de mensajería (WebSocket, rooms, DMs, threads)
- OIDC login (contra bAuth, no contra Keycloak)
- REST API completa (users, channels, groups, chat, roles)
- Apps marketplace (Deno) — para mini-apps
- Webhooks entrantes — para notificaciones automáticas
- Upload de archivos (S3/MinIO)

**NO se usa / se reemplaza con bAuth:**
- LDAP/SAML/External OAuth role mapping → bAuth OIDC + claim `sbos_roles`
- Enterprise auto-join → bAuth `context.evaluate` + bnotify
- Enterprise sync → bAuth reconcile loop 60s
- Cualquier función EE → bAuth + bnotify

---

## 5. LO QUE bAuth REEMPLAZA DE ROCKET.CHAT EE

| Función EE (pago) | Precio | Quién la da en SBOS | Transporte |
|-------------------|:------:|---------------------|-----------|
| LDAP Role Mapping | $$$/usuario | bAuth → claim `sbos_roles` en JWT | Unix socket |
| SAML Field Mapping | $$$/usuario | bAuth OIDC nativo (no usa SAML) | Unix socket |
| OAuth Role Assignment | $$$/usuario | bAuth → bnotify → bChat | Unix socket + REST |
| Auto-join Channels | $$$/usuario | bAuth `context.evaluate` átomo → bnotify | Unix socket |
| Background Sync | $$$/usuario | bAuth reconcile loop → bnotify | Unix socket |
| Custom Fields | $$$/usuario | `idn_atributo` EAV + display_format | Unix socket |

**bAuth ES el OIDC Provider nativo** (verificado en `oidc_provider.rs:4`: "Sin dependencia de Keycloak").
Keycloak queda como backup/redundancia. La dirección es eliminarlo.

---

## 6. EL CAMINO A WECHAT

WeChat no nació super-app. Su evolución:

```
2011: Mensajería (texto, voz, fotos)
2012: Momentos (red social) + Official Accounts
2013: WeChat Pay (billetera + pagos)
2017: Mini-Programs (apps dentro de WeChat)
```

bChat sigue el mismo camino pero SOBERANO (datos en servidor del cliente, cero nube):

```
ETAPA 0 — CIMIENTOS (AHORA)
  Documentación, ficha bChat v8.5.0, contrato BNOTIFY-BAUTH, esqueleto Rust bnotify.
  Producto: 0 líneas de mensajería. Todo planificación.

ETAPA 1 — CANALES BÁSICOS
  bnotify funcional. Dispatcher + Channel Adapters.
  bChat 8.5.0 corriendo con OIDC bAuth. Email/SMTP funcional.
  Producto: bnotify entrega notificaciones por bChat y email.

ETAPA 2 — IDENTIDAD GOBERNADA
  bAuth reemplaza EE completo. Átomos bchat.*. Reconcile loop.
  Canales automáticos por tenant/rol.
  Producto: cada acción en bChat gobernada por átomo bAuth.

ETAPA 3 — NEGOCIO INTEGRADO
  Notificaciones ERP + calendario + MFA + seguridad.
  bChat es el centro de notificaciones del SBOS.
  Producto: factura emitida → DM en bChat en < 5s.

ETAPA 4 — SUPER-APP
  bChat Apps (Deno). Wallet. Firma digital. Cuentas oficiales.
  Producto: aprobar factura sin salir del chat.

ETAPA 5 — ESCALA
  Multi-tenant 50K+. HA. ISO 27001.
```

---

## 7. PRINCIPIOS DE DISEÑO

1. **bnotify es el orquestador. bChat es un canal.** No al revés.
2. **Siempre asíncrono.** Productor publica y olvida. bnotify garantiza entrega.
3. **Unix socket + JSON-RPC entre daemons. REST solo hacia afuera.**
4. **bnotify es el ÚNICO que habla con bChat REST API.** Centralizar = auditar.
5. **bAuth ES el OIDC Provider.** Keycloak backup. Dirección: eliminar KC.
6. **CE + bAuth > EE.** Sin licencia. Soberanía total.
7. **Atomicidad.** Cada acción en bChat = átomo en privilege_atom. Fastpath < 0.5ns.
8. **ctx_id en cada notificación.** ISO 27001 A.8.15. Trazabilidad completa.

---

## 8. LO QUE bnotify/bChat NO ES

- **bChat no es el producto** — es el canal principal de bnotify
- **No es un fork** — Rocket.Chat vanilla CE. Personalización en bAuth + bnotify
- **No es solo chat** — es el canal interactivo del SBOS (ERP, wallet, firma)
- **No requiere licencia EE** — bAuth reemplaza todo
- **No usa REST entre daemons** — solo Unix socket + JSON-RPC

---

*Documento de Visión v3.0.0 · BnotifyAgent/context/ · 2026-07-05*
*Corrección: bnotify orquestador. bChat canal principal. Patrón event-driven multi-channel.*
