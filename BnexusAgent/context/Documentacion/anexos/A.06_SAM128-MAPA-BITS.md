# A.06 — SAM-128: Mapa Completo de Bits
## WORD-A (privilegios físicos) + WORD-B (contexto, TTL, flags) — bit a bit

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Fuente:** SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md §12 + `1.05_MANUAL-SAM128.md`  

---

## 1. Concepto general

El SAM-128 (Security Authorization Mask de 128 bits) es la representación binaria compacta de la autorización de un usuario para un nodo específico. Es calculado por bAuth y evaluado en O(1) por bhnexus.

```
SAM-128 = WORD-A (64 bits) | WORD-B (64 bits)

WORD-A: "¿qué puede hacer físicamente?"
  → Bits de zonas, roles de puerta, capacidades de actuador

WORD-B: "¿bajo qué condiciones?"
  → TTL, LoA alcanzado, flags de auditoría, nivel de seguridad
```

---

## 2. WORD-A — Mapa de bits completo (64 bits)

```
Bit  63    RESERVADO — siempre 0 (reservado para expansión)
Bit  62    RESERVADO
Bit  61    RESERVADO
Bit  60    RESERVADO

───── Zona de flags de capacidades globales (bits 56-59) ─────
Bit  59    can_override_security_level — el usuario puede operar fuera de su LoA normal
            (solo para ROL_SUPER_ADMIN, ROL_SECURITY_OFFICER en emergencias)
Bit  58    can_unlock_all_zones — acceso a todas las zonas sin verificar bits individuales
            (ROL_MASTER_KEY — solo para uso en evacuación forzada)
Bit  57    is_first_factor_verified — el primer factor de un MFA ha sido verificado
            (banexus usa este flag para mostrar el prompt del segundo factor)
Bit  56    step_up_pending — hay un step_up en curso (banexus espera el segundo factor)

───── Zona de permisos por tipo de actuador (bits 48-55) ─────
Bit  55    can_open_barrier   — puede abrir torniquetes o barreras vehiculares
Bit  54    can_open_gate      — puede abrir portones o rejas perimetrales
Bit  53    can_open_vault     — puede abrir bóveda (requiere habitualmente LoA=3+MFA)
Bit  52    can_open_elevator  — puede activar ascensor o llamar piso restringido
Bit  51    can_open_drawer    — puede abrir cajón de dinero (POS)
Bit  50    can_trigger_alarm  — puede activar o silenciar alarma
Bit  49    can_control_relay  — puede controlar un relé GPIO genérico
Bit  48    can_lock_manual    — puede bloquear manualmente un acceso desde su terminal

───── Zona de permisos por nivel de seguridad de zona (bits 40-47) ─────
Bit  47    access_sl4         — puede acceder a zonas security_level=4 (crítico)
Bit  46    access_sl3         — puede acceder a zonas security_level=3 (restringido)
Bit  45    access_sl2         — puede acceder a zonas security_level=2 (operacional)
Bit  44    access_sl1         — puede acceder a zonas security_level=1 (empleados)
Bit  43    access_sl0         — puede acceder a zonas security_level=0 (público)
Bit  42    RESERVADO
Bit  41    RESERVADO
Bit  40    RESERVADO

───── Zona de permisos por zona física específica (bits 8-39) ─────
Bits 8-39  = 32 bits = hasta 32 zonas específicas configurables por tenant

Los IDs de zona (zona_0 a zona_31) se configuran en bAuth por el administrador.
La asignación bit ↔ zona es fija por tenant y no cambia sin política del administrador.

Ejemplo de asignación típica:
  bit 8  → zona_0: PHY_ZONE_VENTAS        (security_level=2)
  bit 9  → zona_1: PHY_ZONE_ADMIN         (security_level=2)
  bit 10 → zona_2: PHY_ZONE_ALMACEN       (security_level=2)
  bit 11 → zona_3: PHY_ZONE_IT            (security_level=3)
  bit 12 → zona_4: PHY_ROOM_SERVIDOR      (security_level=4)
  bit 13 → zona_5: PHY_ZONE_DIRECTIVOS    (security_level=3)
  bit 14 → zona_6: PHY_BLDG_ALMACEN_NORTE (security_level=2)
  bit 15 → zona_7: PHY_GATE_PRINCIPAL     (security_level=1)
  ...
  bit 39 → zona_31: <configuración del tenant>

───── Zona reservada (bits 0-7) ─────
Bits 0-7   RESERVADOS — siempre 0 (expansión futura)
```

### 2.1 Ejemplos de WORD-A

```
ROL_CAJERO en zona VENTAS:
  Acceso a zona_0 (VENTAS) + can_open_drawer + access_sl2

  WORD-A = 0x0000000000010900
             │               │
             bit 8 (zona_0)  bit 51 (can_open_drawer) + bit 45 (access_sl2)

  Binario:
  00000000 00000000 00000000 00000000 00000000 00000001 00001001 00000000

ROL_SYSADMIN en zona SERVIDOR:
  Acceso a zona_4 (SERVIDOR) + access_sl3 + access_sl4

  WORD-A = 0x0000000000101000
                              │
                              bits 12 (zona_4) + 46 (sl3) + 47 (sl4)

ROL_SUPER_ADMIN (evacuación de emergencia):
  can_unlock_all_zones + can_open_barrier + can_open_gate

  WORD-A = 0x04C0000000000000
```

---

## 3. WORD-B — Mapa de bits completo (64 bits)

```
───── TTL (Time to Live) de la decisión — bits 48-63 ─────
Bits 48-63  = 16 bits unsigned = TTL en segundos
              Rango: 0 - 65535 segundos
              Valor típico: 30 (= 0x001E) para el Auth Cache de bhnexus
              Valor 0: decisión expirada → re-consultar bAuth

───── LoA alcanzado en la autenticación — bits 44-47 ─────
Bits 44-47  = 4 bits = Level of Assurance del método de autenticación usado
              0000 = LoA 0 (anónimo)
              0001 = LoA 1 (contraseña o RFID)
              0010 = LoA 2 (contraseña + MFA, o QR con HMAC)
              0011 = LoA 3 (hardware key, biométrico, smartcard, mTLS)
              0100-1111 = RESERVADOS

───── Nivel de seguridad requerido por la zona — bits 40-43 ─────
Bits 40-43  = 4 bits = security_level de la zona del nodo
              El evaluador verifica: LoA_alcanzado ≥ security_level
              Si no: DENY inmediato por LoA insuficiente

───── Flags de auditoría ISO 27001 — bits 32-39 ─────
Bit  39    iso27001_privileged_access   — acceso a zona crítica (A.8.15, A.8.2)
Bit  38    iso27001_after_hours         — acceso fuera del horario habitual
Bit  37    iso27001_new_credential      — primera vez con esta credencial
Bit  36    iso27001_step_up_completed   — MFA completado con éxito
Bit  35    iso27001_emergency_access    — acceso durante incidente de seguridad
Bit  34    iso27001_override_active     — can_override_security_level fue usado
Bit  33    RESERVADO
Bit  32    RESERVADO

───── Flags de comportamiento del sistema — bits 24-31 ─────
Bit  31    offline_mode                 — decisión tomada desde cache offline
Bit  30    shell_sentinel_active        — sesión SSH/shell auditada activamente
Bit  29    step_up_required             — MFA pendiente de segundo factor
Bit  28    biometric_local_cache        — biométrico verificado desde cache local del lector
Bit  27    first_startup                — primer acceso tras arranque del nodo
Bit  26    revocation_check_pending     — hay una verificación de revocación en cola
Bit  25    RESERVADO
Bit  24    RESERVADO

───── Hash del RolTemplate (versión de política) — bits 0-23 ─────
Bits 0-23  = 24 bits = parte del roltemplate_hash de 32 bits
             Los 8 bits superiores del hash se almacenan separados
             (los 24 bits aquí son los bits 0-23 del hash completo)

             Uso: bhnexus compara el hash almacenado en el Auth Cache con el hash
             del bitmask_response. Si difieren → la política cambió → invalidar cache.
```

### 3.1 Ejemplos de WORD-B

```
Sesión normal — María cajera, LoA=2, sl=2, TTL=30s:
  TTL = 30 = 0x001E (bits 48-63)
  LoA = 2 = 0b0010 (bits 44-47)
  SL  = 2 = 0b0010 (bits 40-43)
  Sin flags especiales
  roltemplate_hash (24 bits) = 0xA3F2B1

  WORD-B = 0x001E22000000A3F2B1

Acceso privilegiado — Carlos sysadmin, LoA=3, sl=4, ISO27001 privileged, TTL=15s:
  TTL = 15 = 0x000F
  LoA = 3 = 0b0011
  SL  = 4 = 0b0100
  iso27001_privileged_access = 1 (bit 39)
  roltemplate_hash = 0xC2D4E5

  WORD-B = 0x000F348000C2D4E5

Acceso offline — banexus en modo cache, LoA=2, sl=2:
  offline_mode = 1 (bit 31)
  TTL = 3600 (4h = 14400s, pero en el SAM se almacenan los segundos restantes)

  WORD-B = 0x0E1022008000A3F2B1
                  ↑
                  bit 31 activo (offline_mode)
```

---

## 4. Correspondencia con el BitMask de 64 bits de bAuth

El BitMask de bAuth (el motor de privilegios de identidad) y el SAM-128 de bNexus son dos estructuras distintas pero relacionadas:

| Aspecto | BitMask bAuth (64 bits) | WORD-A SAM-128 (64 bits) | WORD-B SAM-128 (64 bits) |
|---------|:----------------------:|:------------------------:|:------------------------:|
| Propósito | Privilegios de identidad (D00-D15) | Privilegios físicos (zonas, actuadores) | Contexto, TTL, auditoría |
| Evaluado por | bAuth PDP | bhnexus (O(1)) | bhnexus (verificación de LoA) |
| Persistencia | SBOSDB + Redis | Auth Cache bhnexus (30s) | Auth Cache bhnexus (30s) |
| Generado por | bAuth (función bos_build_atom_bitmask) | bAuth (convierte BitMask → SAM-128 físico) | bAuth (calcula en base a sesión) |

El proceso de conversión:

```
bAuth.BitMask (D14, dominio acceso físico):
  bit 0: access.physical.zona_ventas     → SAM-128 WORD-A bit 8
  bit 1: access.physical.zona_admin      → SAM-128 WORD-A bit 9
  bit 2: access.physical.zona_servidores → SAM-128 WORD-A bit 12
  bit 3: pos.drawer.open                 → SAM-128 WORD-A bit 51
  ...

bAuth calcula el WORD-A directamente desde el BitMask D14.
WORD-B se calcula desde los metadatos de sesión (LoA, schedule, timestamp).
```

---

## 5. Evaluación en bhnexus — código de referencia

```rust
/// Evalúa si un acceso es permitido en O(1) usando el SAM-128
/// Retorna true si el acceso está autorizado
fn evaluate_access(sam128: Sam128, required_zone_bit: u64, required_sl: u8) -> bool {
    // 1. Verificar que la zona está autorizada
    let zone_bit = 1u64 << required_zone_bit;
    if (sam128.word_a & zone_bit) == 0 {
        return false;  // zona no autorizada
    }

    // 2. Verificar LoA alcanzado vs security_level requerido
    let loa_achieved = ((sam128.word_b >> 44) & 0xF) as u8;
    let sl_required  = ((sam128.word_b >> 40) & 0xF) as u8;
    if loa_achieved < sl_required {
        return false;  // LoA insuficiente
    }

    // 3. Verificar TTL (no expirado)
    let ttl = ((sam128.word_b >> 48) & 0xFFFF) as u64;
    if ttl == 0 {
        return false;  // TTL expirado
    }

    // 4. Verificar override de step_up
    let step_up_pending = (sam128.word_a >> 56) & 1;
    if step_up_pending != 0 {
        return false;  // MFA pendiente — no autorizar hasta completarlo
    }

    true
}
```

---

## 6. Tabla de constantes de referencia

```rust
// WORD-A — bits de actuador
pub const BIT_CAN_OPEN_BARRIER:   u64 = 1 << 55;
pub const BIT_CAN_OPEN_GATE:      u64 = 1 << 54;
pub const BIT_CAN_OPEN_VAULT:     u64 = 1 << 53;
pub const BIT_CAN_OPEN_ELEVATOR:  u64 = 1 << 52;
pub const BIT_CAN_OPEN_DRAWER:    u64 = 1 << 51;
pub const BIT_CAN_TRIGGER_ALARM:  u64 = 1 << 50;
pub const BIT_CAN_CONTROL_RELAY:  u64 = 1 << 49;

// WORD-A — bits de access_sl
pub const BIT_ACCESS_SL4:         u64 = 1 << 47;
pub const BIT_ACCESS_SL3:         u64 = 1 << 46;
pub const BIT_ACCESS_SL2:         u64 = 1 << 45;
pub const BIT_ACCESS_SL1:         u64 = 1 << 44;

// WORD-B — flags de auditoría
pub const BIT_ISO27001_PRIVILEGED: u64 = 1 << 39;
pub const BIT_ISO27001_AFTER_HOURS: u64 = 1 << 38;
pub const BIT_OFFLINE_MODE:        u64 = 1 << 31;
pub const BIT_SHELL_SENTINEL:      u64 = 1 << 30;
pub const BIT_STEP_UP_REQUIRED:    u64 = 1 << 29;

// Máscaras para campos multi-bit
pub const MASK_TTL:   u64 = 0xFFFF_0000_0000_0000;
pub const MASK_LOA:   u64 = 0x0000_F000_0000_0000;
pub const MASK_SL:    u64 = 0x0000_0F00_0000_0000;
pub const MASK_RTHASH: u64 = 0x0000_0000_00FF_FFFF;

// Offsets de campos
pub const OFFSET_TTL:    u32 = 48;
pub const OFFSET_LOA:    u32 = 44;
pub const OFFSET_SL:     u32 = 40;
pub const OFFSET_RTHASH: u32 = 0;
```

---

*SKULL · SBOS · bNexus · A.06_SAM128-MAPA-BITS · v1.0.0 · Agosto 2026*
