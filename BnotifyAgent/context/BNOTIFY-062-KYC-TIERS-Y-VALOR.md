---
codigo: BNOTIFY-062
version: 1.0.0
estado: BORRADOR
gate: G5
depende_de: [BNOTIFY-002]
doctrina_que_ejerce: [D3, D9, D14]
criterio_implementado: >
  Un usuario T0 (sin verificar) está limitado a 20 mensajes/minuto y no puede enviar archivos > 10MB.
  Un usuario T1 tiene los límites ampliados y puede usar llamadas de voz.
  Un usuario T2 puede usar E2EE y tiene almacenamiento de 50 GB.
  La verificación de tier retorna en < 50ms desde la caché bAuth.
  Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-062 — KYC Tiers y Valor
## Niveles T0/T1/T2, límites D3, capacidades por tier, integración bPay en conversación

**Versión:** 1.0.0 · **Gate:** G5 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §D.3 (límites por KYC) · BNOTIFY-002 (bAuth OIDC — claim `kyc_tier`) · doc. 07 increments

---

## 1. Tiers KYC en bChat

Los tiers KYC mapean directamente a los niveles IAL de NIST SP 800-63A. bAuth es quien determina y certifica el tier — bChat y bNotify solo lo consultan:

| Tier bChat | IAL NIST | Verificación | Acceso a bAuth |
|-----------|----------|--------------|----------------|
| **T0** | IAL1 | Sin verificar (solo email) | Solo bChat, funciones básicas |
| **T1** | IAL2 | Documento de identidad verificado | bChat completo, bPay básico |
| **T2** | IAL3 | Biométrico + presencia física (in-person) | Todas las funciones, bPay avanzado |

El tier llega al motor bChat como claim `kyc_tier` en el JWT bAuth — no requiere consulta separada.

---

## 2. Tabla de capacidades por tier

### 2.1 Mensajería

| Capacidad | T0 | T1 | T2 |
|-----------|:--:|:--:|:--:|
| Mensajes / minuto | 20 | 60 | 200 |
| Mensajes / hora | 100 | 500 | 2000 |
| Historial visible | 7 días | 1 año | Completo |
| Búsqueda en historial | No | Sí | Sí |
| Crear salas de grupo | No | Sí (max 50 miembros) | Sí (max 500) |
| Crear canales | No | Sí (max 5) | Sí (ilimitado) |
| Roles de sala (admin) | No | Sí | Sí |

### 2.2 Medios

| Capacidad | T0 | T1 | T2 |
|-----------|:--:|:--:|:--:|
| Tamaño máximo / archivo | 10 MB | 100 MB | 1 GB |
| Almacenamiento total | 500 MB | 5 GB | 50 GB |
| Tipos permitidos | Imagen, audio | + Video, docs | Todo |
| Miniaturas automáticas | Sí | Sí | Sí |

### 2.3 Comunicación en tiempo real

| Capacidad | T0 | T1 | T2 |
|-----------|:--:|:--:|:--:|
| Llamadas de voz 1:1 | No | Sí | Sí |
| Video 1:1 | No | Sí | Sí |
| Salas Meet (grupo) | No | Sí (max 16) | Sí (max 100) |
| Grabación de llamadas (G5+) | No | No | Sí (con consentimiento) |

### 2.4 Seguridad avanzada

| Capacidad | T0 | T1 | T2 |
|-----------|:--:|:--:|:--:|
| E2EE (MLS) | No | Opt-in en DMs | Sí (todas las salas) |
| Firma de mensajes Ed25519 | No | No | Opt-in |
| Dispositivos simultáneos | 2 | 5 | 10 |

---

## 3. Integración bPay en conversación (D3)

bPay es el daemon de pagos de SBOS. Los tiers T1 y T2 pueden usar funciones de pago dentro de bChat:

### 3.1 Pago entre usuarios (T1+)

Desde una sala DM, un usuario puede enviar dinero a otro con el módulo de formularios (BNOTIFY-043):

```
Usuario A (T1)
│
│  Botón "Enviar pago" en la sala DM con Usuario B
│  → Abre formulario bPay embebido
│  { to: user_b_id, amount: "Bs. 100", concept: "Almuerzo" }
│
▼
bPay (vía formulario BNOTIFY-043)
│  → Verifica que ambos son T1+
│  → Proceso de pago
│  → Publica evento bPay.transfer.COMPLETED
│
▼
bNotify
│  → Dispatch al canal chat (sala DM)
│  → Mensaje especial tipo 'payment_confirmation':
│    "✓ Pago de Bs. 100 enviado a Usuario B"
```

### 3.2 Solicitud de pago (T1+)

Un usuario puede solicitar un pago a otro — el receptor recibe un formulario de aprobación en la sala:

```json
{
  "form_id": "pago-request-{UUID}",
  "title": "Solicitud de Pago",
  "fields": [
    { "id": "monto", "type": "display", "value": "Bs. 50" },
    { "id": "concepto", "type": "display", "value": "Cuota de la reunión" }
  ],
  "actions": [
    { "id": "pagar", "label": "Pagar ahora", "style": "primary" },
    { "id": "rechazar", "label": "Rechazar" }
  ]
}
```

---

## 4. Consulta del tier en el motor

El tier se verifica en la capa de autenticación del motor bChat:

```rust
// services/auth.rs
pub struct AuthContext {
    pub bauth_user_id: Uuid,
    pub tenant_id:     String,
    pub ctx_id:        Uuid,
    pub sbos_roles:    Vec<String>,
    pub kyc_tier:      KycTier,  // T0 | T1 | T2 — del claim JWT
}

#[derive(Debug, Clone, PartialEq, PartialOrd)]
pub enum KycTier {
    T0 = 0,
    T1 = 1,
    T2 = 2,
}

impl KycTier {
    pub fn max_file_size_bytes(&self) -> u64 {
        match self {
            KycTier::T0 => 10 * 1024 * 1024,         // 10 MB
            KycTier::T1 => 100 * 1024 * 1024,        // 100 MB
            KycTier::T2 => 1024 * 1024 * 1024,       // 1 GB
        }
    }

    pub fn messages_per_minute(&self) -> u32 {
        match self { KycTier::T0 => 20, KycTier::T1 => 60, KycTier::T2 => 200 }
    }
}
```

El tier se extrae del JWT al conectar (`bchat.connect`) y no requiere consultas posteriores a bAuth para operaciones normales. Solo se re-verifica cuando el cliente renueva el JWT (cada hora).

---

## 5. Promoción de tier

Cuando un usuario sube de tier (T0→T1, T1→T2), los límites se actualizan al próximo JWT refresh. No hay estado en bChat que almacene el tier — siempre viene del JWT de bAuth.

El proceso de verificación de identidad para subir de tier ocurre en bAuth (BNOTIFY-002 §5.2) — bChat es solo el consumidor del resultado.

---

*BNOTIFY-062 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*El tier viene del JWT. bChat no decide quién es T0, T1 o T2 — bAuth lo decide. bChat solo actúa en consecuencia.*
