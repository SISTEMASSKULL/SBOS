---
codigo: BNOTIFY-043
version: 1.0.0
estado: BORRADOR
gate: G3
depende_de: [BNOTIFY-040]
doctrina_que_ejerce: [D6, D14]
criterio_implementado: >
  Un formulario definido con el DSL JSON puede ser renderizado en el cliente Flutter.
  El usuario completa el formulario y envía la respuesta.
  La respuesta se almacena como evento bNotify en la tabla notification_event.
  Un formulario con un campo requerido vacío es rechazado con error de validación.
  Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-043 — Motor de Formularios
## Formularios/flujos declarativos (DSL JSON): definición, render Flutter, respuestas como eventos

**Versión:** 1.0.0 · **Gate:** G3 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-040 (módulos), BNOTIFY-004 (eventos y auditoría)

---

## 1. Propósito

El motor de formularios permite que cualquier daemon SBOS (bAuth, bPay, bHR, etc.) envíe **formularios estructurados** a usuarios dentro de bChat. El formulario aparece como un mensaje especial en la sala — el usuario lo completa y lo envía, y la respuesta se genera como un evento bNotify que puede ser procesado por el daemon emisor.

Casos de uso típicos:
- bAuth pide confirmación de datos antes de emitir un certificado
- bPay pide aprobación de una transacción antes de ejecutarla
- bHR solicita firma de un documento de política
- Un supervisor lanza una encuesta rápida al equipo

---

## 2. DSL JSON de formularios

Un formulario se define con un JSON que el cliente Flutter sabe renderizar:

```json
{
  "form_id": "aprobacion-pago-0042",
  "title": "Aprobación de Pago",
  "description": "El siguiente pago requiere tu aprobación.",
  "ctx_id": "{ctx_id_obligatorio}",
  "expires_at": "2026-07-07T10:00:00Z",
  "fields": [
    {
      "id": "monto",
      "type": "display",
      "label": "Monto",
      "value": "Bs. 1,500.00"
    },
    {
      "id": "beneficiario",
      "type": "display",
      "label": "Beneficiario",
      "value": "Proveedor XYZ"
    },
    {
      "id": "comentario",
      "type": "text",
      "label": "Comentario (opcional)",
      "required": false,
      "placeholder": "Agrega un comentario si lo deseas"
    },
    {
      "id": "pin_confirmacion",
      "type": "pin",
      "label": "PIN de confirmación",
      "required": true,
      "digits": 6
    }
  ],
  "actions": [
    { "id": "aprobar",   "label": "Aprobar",   "style": "primary",   "confirm": true },
    { "id": "rechazar",  "label": "Rechazar",  "style": "destructive" }
  ]
}
```

### 2.1 Tipos de campo soportados

| Tipo | Descripción | Renderizado Flutter |
|------|-------------|---------------------|
| `display` | Solo lectura, muestra un valor | `ListTile` con icono |
| `text` | Texto libre | `TextField` |
| `select` | Selección de una opción | `DropdownButton` |
| `multiselect` | Selección múltiple | `CheckboxListTile` |
| `date` | Fecha | `DatePicker` |
| `pin` | PIN numérico oculto | `TextField` obscureText |
| `file` | Adjuntar archivo | Usa pipeline de media (BNOTIFY-034) |

---

## 3. Flujo de envío y respuesta

```
Daemon SBOS (bPay, bAuth, etc.)
│
│  1. gRPC bNotify: Dispatch(DispatchRequest {
│       destination: { user_id: "UUID" },
│       channel: INAPP,
│       payload: { type: "form", form_json: "...", form_id: "aprobacion-0042" },
│       ctx_id: "...",
│       priority: CLASE_A,
│  })
│
▼
Motor bNotify
│  → Almacena en bnotify.notification_event (tipo: FORM_REQUEST)
│  → Envía al canal InApp → bChat
│
▼
Motor bChat (como mensaje especial tipo: 'form')
│  → Mensaje llega al cliente Flutter como JSON-RPC Notification:
│    bchat.notification { type: "form", form_json: "..." }
│
▼
Cliente Flutter
│  → Renderiza el formulario en la sala
│  → Usuario completa y toca "Aprobar"
│  → JSON-RPC: bchat.form.submit({ form_id, field_values, action_id })
│
▼
Motor bChat
│  → Valida campos requeridos
│  → Almacena respuesta en bnotify.form_response
│  → Publica evento NATS: bnotify.form.response.{tenant_id}.{form_id}
│
▼
Daemon SBOS (subscrito al NATS topic)
│  → Procesa la respuesta
```

---

## 4. Tabla de respuestas

```sql
-- Schema: bnotify
CREATE TABLE bnotify.form_response (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    form_id         TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
    ctx_id          UUID        NOT NULL,

    respondent_id   UUID        NOT NULL,   -- bauth_user_id
    action_id       TEXT        NOT NULL,   -- "aprobar" | "rechazar" | etc.

    -- Respuestas de los campos (JSONB para flexibilidad)
    field_values    JSONB       NOT NULL DEFAULT '{}',

    responded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Referencia al evento original
    notification_event_id UUID  NOT NULL
);

CREATE INDEX idx_form_response_form_id ON bnotify.form_response (form_id, tenant_id);
```

---

## 5. Seguridad de formularios

- **Expiración:** un formulario tiene `expires_at` — pasado ese tiempo, el motor rechaza cualquier respuesta con error `FORM_EXPIRED`
- **Un solo envío:** la combinación `(form_id, respondent_id)` es única — no se puede enviar el mismo formulario dos veces
- **Campos sensibles (PIN):** los valores de campos tipo `pin` no se almacenan en `field_values` — el daemon los recibe directamente por el evento NATS y los verifica contra bAuth; bNotify solo registra que el campo fue completado (true/false)
- **Auditoría clase A:** toda respuesta a un formulario de tipo `aprobacion` o `firma` se registra con clase de auditoría A (WORM, retención 7 años)

---

*BNOTIFY-043 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*El formulario es el mensaje. La respuesta es el evento. El daemon emisor es quien decide qué hacer con la respuesta.*
