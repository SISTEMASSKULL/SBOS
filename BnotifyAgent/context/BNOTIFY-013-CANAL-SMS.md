---
codigo: BNOTIFY-013
version: 1.0.0
estado: BORRADOR
gate: G1
depende_de: [BNOTIFY-010]
doctrina_que_ejerce: [D4, D5, D14]
criterio_implementado: >
  El adaptador SMS entrega un mensaje OTP de prueba (evento mfa.challenge, clase A)
  a un número E.164 real del sistema. El número recibe el SMS. El log del adaptador
  registra el provider_message_id retornado por Jasmin/Kannel. Verificado con
  verificar_afirmacion.sh en VPS.
---

# BNOTIFY-013 — Canal SMS
## Adaptador SMS: Jasmin/Kannel vía SMPP — solo salida

**Versión:** 1.0.0 · **Gate:** G1 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §4.2 · BNOTIFY-000 Anexo B (UnifiedPush para push soberano vs SMS)

---

## 1. Propósito y alcance

El canal SMS es **solo salida** — bNotify envía SMS, no los recibe. Los casos de uso son:
- OTP por SMS (evento `mfa.challenge`, clase A) — cuando el usuario no tiene app
- Alertas de seguridad cuando no hay otro canal disponible (failover clase A)
- Verificación de teléfono en el registro `D9.bauth.method.PHONE_OTP`

El SMS es el **último eslabón del failover** (chat → push → email → SMS) por ser el más
costoso y de menor capacidad de carga.

---

## 2. Stack SMPP del ecosistema

| Componente | Versión | Rol |
|-----------|:-------:|-----|
| **Jasmin SMS Gateway** | 0.10.x | Gateway SMPP self-hosted — gestión de smsc, colas, throttling |
| **Kannel** | 1.5.x | Alternativa a Jasmin (decidir según disponibilidad en Bolivia) |
| **SMSC externo** | — | Operador boliviano (Tigo, Entel, Viva) — conexión SMPP hacia Jasmin |

**Decisión de stack:** Jasmin es preferido por tener API HTTP de administración y soporte
de múltiples SMSCs. Kannel es la alternativa si Jasmin no está disponible para el mercado boliviano.
Esta decisión se formaliza en un ADR antes de la implementación.

---

## 3. Flujo de entrega

```
bNotify núcleo → DeliverRequest { channel_recipient: "+591XXXXXXXX", body: "Código: 123456" }
    │
    ▼
AdapterSms
    │
    ├── Valida número E.164 (debe empezar con +591 para Bolivia)
    ├── Trunca body si > 160 chars GSM-7 (SMS de parte única)
    │   (si > 160 chars: enviar SMS concatenado — manejar encoding correcto)
    │
    ▼
Jasmin HTTP API (POST /send)
    {
      "to": "+591XXXXXXXX",
      "content": "Código: 123456",
      "from": "SBOS"
    }
    │
    ▼
Jasmin → SMPP → SMSC operador boliviano → teléfono destino
```

---

## 4. Configuración

```toml
# /etc/bnotify/adapters/sms.toml
[jasmin]
base_url = "http://jasmin.infra.svc.cluster.local:8080"
# username y password inyectados desde Vault: sbos/bnotify/adapters/sms/jasmin
sender_id = "SBOS"
timeout_secs = 20

[limits]
max_chars_per_sms = 160      # GSM-7 parte única
max_sms_per_recipient_per_day = 10  # Anti-abuso
```

---

## 5. Manejo de errores

| Respuesta Jasmin | Significado | DeliveryResult |
|:----------------:|-------------|:-------------:|
| `Success: {message_id}` | Entregado al SMSC | `DELIVERED` (provider_message_id = message_id) |
| `Error: SystemError` | Error interno Jasmin | `FAILED_TEMPORARY` |
| `Error: InvalidParams` | Número inválido o sender_id rechazado | `FAILED_PERMANENT` |
| Timeout (>20s) | Jasmin no responde | `CHANNEL_UNAVAILABLE` |

⚠️ `DELIVERED` en SMS significa que el SMSC lo aceptó — **no** que llegó al teléfono.
Las confirmaciones de entrega al teléfono (delivery receipts) son opcionales y dependen
del operador. Si el operador las soporta, Jasmin puede recibirlas y el adaptador puede
actualizar el estado — se implementa como mejora futura.

---

## 6. Código Rust — estructura del adaptador

```
src/channel/sms/
├── mod.rs          # Implementación del trait AdapterChannel para SMS
├── config.rs       # JasminConfig: base_url, sender_id, timeout
├── jasmin.rs       # Cliente HTTP para Jasmin API (reqwest)
└── validator.rs    # Validación E.164 + encoding GSM-7
```

---

*BNOTIFY-013 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*SMS = el canal más costoso y lento. Se usa como último recurso. El OTP por SMS es obligatorio para usuarios sin app.*
