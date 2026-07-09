---
codigo: BNOTIFY-060
version: 1.0.0
estado: BORRADOR
gate: G5
depende_de: [BNOTIFY-030, BNOTIFY-032]
doctrina_que_ejerce: [D2, D12, D14]
criterio_implementado: >
  Dos clientes Flutter pueden establecer una sala MLS con E2EE activo.
  Un mensaje enviado en la sala cifrada llega al receptor descifrado correctamente.
  Un tercero con acceso a la base de datos NO puede leer el contenido del mensaje.
  La adición de un nuevo miembro a la sala cifrada no expone mensajes anteriores.
  Verificado con verificar_afirmacion.sh en VPS (análisis de contenido en BD).
---

# BNOTIFY-060 — E2EE MLS
## MLS/RFC 9420 con OpenMLS o mls-rs: delivery service propio, multi-dispositivo, auditoría

**Versión:** 1.0.0 · **Gate:** G5 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §A.0.5 (ADR-005: MLS/RFC 9420) · BNOTIFY-030 §4.6 (E2EE en protocolo)

---

## 1. Por qué MLS/RFC 9420 (ADR-005)

MLS (Messaging Layer Security, RFC 9420) es el estándar moderno de E2EE para mensajería de grupo:

- **Seguridad hacia adelante y hacia atrás:** cada mensaje usa una clave derivada de un epoch distinto. Comprometer una clave no expone mensajes anteriores ni futuros.
- **Multi-dispositivo nativo:** el protocolo está diseñado para múltiples dispositivos por usuario sin duplicar mensajes no cifrados.
- **Aritmética de grupos:** añadir o retirar un miembro genera un nuevo epoch — las claves del epoch anterior quedan inutilizables.
- **Auditoría externa posible:** el Delivery Service (DS) puede auditarse sin acceder a las claves de los miembros.
- **Implementaciones existentes y auditadas:** OpenMLS (Rust, MIT) y mls-rs (Rust, Apache) — ninguna criptografía propia (D12).

La alternativa (Signal Double Ratchet) fue descartada porque MLS es más eficiente para grupos grandes y tiene respaldo de IETF.

---

## 2. Arquitectura MLS en bChat

```
Cliente Flutter                          Servidor bChat (DS)
│                                        │
│  Key Package (identidad + clave pública) publicado al DS
│──────────────────────────────────────► │ bnotify.mls_key_package
│                                        │
│  Crear sala E2EE:                      │
│  bchat.mls.group.create                │
│  { room_id, initial_members }          │
│──────────────────────────────────────► │
│                                        │ Welcome message generado
│                                        │ (cifrado con clave pública de cada miembro)
│◄────────────────────────────── Welcome │
│                                        │
│  Enviar mensaje cifrado:               │
│  MLS Ciphertext → bchat.message.send   │
│  { room_id, mls_ciphertext: "..." }    │
│──────────────────────────────────────► │ Almacena en bchat.message.text = NULL
│                                        │ bchat.message.mls_ciphertext = "..."
│  Receptor descifra localmente          │
│◄─────────────────── MLS Ciphertext ───│
│  con la clave del epoch actual         │
```

**El servidor bChat NUNCA ve el contenido en claro.** `bchat.message.text` es `NULL` para mensajes E2EE. El servidor solo almacena el ciphertext.

---

## 3. Delivery Service (DS)

bChat actúa como Delivery Service de MLS — el rol del DS es:

1. **Almacenar Key Packages:** paquetes de claves públicas de cada dispositivo de cada usuario
2. **Distribuir Welcome messages:** cuando se crea un grupo o se añade un miembro
3. **Ordenar y distribuir MLS Commits:** cuando se actualiza el epoch del grupo
4. **No acceder al contenido:** el DS en MLS no puede descifrar nada

### 3.1 Tablas del DS

```sql
-- Key packages por dispositivo
CREATE TABLE bchat.mls_key_package (
    id              UUID    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       TEXT    NOT NULL,
    bauth_user_id   UUID    NOT NULL,
    device_id       TEXT    NOT NULL,

    key_package_data BYTEA  NOT NULL,  -- Binario serializdo del KeyPackage MLS
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ NOT NULL,  -- Típicamente 30 días

    consumed        BOOLEAN NOT NULL DEFAULT FALSE  -- TRUE cuando se usó en un Welcome
);

-- Estado del grupo MLS (epoch actual, miembros)
CREATE TABLE bchat.mls_group_state (
    room_id         UUID    NOT NULL PRIMARY KEY REFERENCES bchat.room(id),
    tenant_id       TEXT    NOT NULL,
    epoch           BIGINT  NOT NULL DEFAULT 0,
    group_state_data BYTEA  NOT NULL,  -- Estado serializado del grupo MLS (opaco)
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## 4. Librería: OpenMLS o mls-rs

La decisión entre OpenMLS y mls-rs se hace al comenzar la implementación de Gate G5, según el estado de madurez y auditoría de ambas librerías en ese momento. Ambas son válidas según ADR-005.

**Criterios de selección (a evaluar en G5):**
- Cobertura de RFC 9420 (todos los ciphers? TreeKEM completo?)
- Última auditoría de seguridad externa
- Actividad de mantenimiento en los 6 meses previos a G5
- Compatibilidad con compilación a MUSL

La librería elegida se documenta en un nuevo ADR (ADR-010) al inicio de G5.

---

## 5. Activación gradual de E2EE

E2EE en G5 no activa para todas las salas — el usuario/admin elige:

| Tipo de sala | E2EE por defecto | Puede activarse |
|---|:---:|:---:|
| Direct (DM) | No (G5 inicial) | Sí (por acuerdo de ambas partes) |
| Grupo | No | Sí (admin activa) |
| Canal | No | No (los canales son de broadcast — no E2EE) |
| Broadcast | No | No |

La UI muestra el estado E2EE claramente: ícono de candado cuando la sala está cifrada.

---

## 6. Limitaciones con E2EE activo

- **Búsqueda de texto completo:** deshabilitada para mensajes E2EE (el servidor no tiene el texto en claro)
- **Moderación de contenido:** limitada a análisis de metadatos (quién envió, cuántos mensajes) — el contenido no puede analizarse (D11 reforzado)
- **Copia de seguridad del historial:** la responsabilidad de respaldar las claves es del usuario — el servidor solo guarda el ciphertext
- **Bots y módulos:** no pueden leer mensajes E2EE (el servidor no puede inyectarlos en el grupo sin consent explícito de todos los miembros)

---

*BNOTIFY-060 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*El servidor entrega. El cliente cifra y descifra. Nunca al revés. Esta es la garantía de E2EE.*
