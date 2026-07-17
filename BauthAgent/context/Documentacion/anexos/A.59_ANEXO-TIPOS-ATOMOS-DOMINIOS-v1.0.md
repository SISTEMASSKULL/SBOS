# A.59 — Tipos de Átomos y Dominios de Control
## Tipo A — Catálogo de átomos, BitMask 64-bit, dominios D1-D13 y operaciones de RolBitMask

**Versión:** 1.0.0
**Fecha:** 2026-07-15
**Tipo de anexo:** A (traslado de SSOT)
**Respalda a:** [2.17 Motor de Roles v1.1.0](../2.17_MANUAL-MOTOR-ROLES-v1.0.md) · [1.03 Átomos](../1.03_MANUAL-ATOMOS-v1.0.md) · [1.04 BitMask](../1.04_MANUAL-BITMASK-v1.0.md)
**Fuentes:** Manual 1.03 §2-§8 · Manual 1.04 §3-§10 · A.46 §2 (EBNF)

---

## §1 Propósito

Catálogo de los tipos de átomos y dominios de control del Motor de Roles. Datos extraídos
de los manuales 1.03 (Átomos), 1.04 (BitMask) y A.46 (Gramática atomc).

**Cómo citarlo:** `A.59 §N`

---

## §2 Catálogo de átomos por dominio

Fuente: Manual 1.03 §8.

| Dominio | Átomos diseñados | Posiciones | Estado |
|---|---|---|---|
| D1 (Lógico) | ~484 | 120-603 | ✅ Implementado |
| D2 (Físico) | ~484 | 604-1,087 | ✅ Implementado |
| D3 (Financiero) | ~484 | 1,088-1,571 | ✅ Implementado |
| D4 (Temporal) | 28+ | 1,572-1,955 | Diseño |
| D5 (Biométrico) | 28+ | 1,956-2,339 | Diseño |
| D6 (Geoespacial) | 28+ | 2,340-2,723 | Diseño |
| D7 (Red) | 28+ | 2,724-3,107 | Diseño |
| D10 (Delegación) | 28+ | 3,108-3,491 | Diseño |
| D11 (Auditoría) | 28+ | 3,492-3,875 | Diseño |
| D12 (Blockchain) | 484 | 5,325-5,808 | Diseño |
| D13 (Firma Digital) | 36 | 5,929-5,964 | Diseño |
| D00 (Identidad) | 20 | 5,809-5,828 | Pendiente ADR-016 |

**Total: ~6,000 átomos** en el catálogo completo. 1,059 sembrados hoy (D1, seed `bauth_06`).
Cada átomo ocupa una posición única e irrepetible. Las posiciones nunca se reutilizan.

---

## §3 AtomBitMask 64-bit — estructura exacta

Fuente: Manual 1.04 §3.

```
 63                              32 31                               0
 +----------------------------------+----------------------------------+
 |         PARTE CONTEXTUAL         |          PARTE LÓGICA            |
 | [8 device][4 domain][9 app][11 g]| [3 trust][2 bind][1 blk][2 pol][24 verb] |
 +----------------------------------+----------------------------------+
```

### Parte Contextual (bits 63-32)

| Campo | Bits | Rango | Shift |
|---|---|---|---|
| `device_allowed` | 8 | 0x01-0xFF | DEVICE_SHIFT = 0 |
| `domain` | 4 | 1-15 (D1-D15) | DOMAIN_SHIFT = 8 |
| `app` | 9 | 1-511 | APP_SHIFT = 12 |
| `group` | 11 | 1-2,047 | GROUP_SHIFT = 21 |

### Parte Lógica (bits 31-0)

| Campo | Bits | Rango | Shift |
|---|---|---|---|
| `min_trust` | 3 | 0-4 (None, Low, Medium, High, Critical) | TRUST_SHIFT = 0 |
| `token_binding` | 2 | 0-3 (None, Device, Session, Hardware) | BINDING_SHIFT = 3 |
| `blockchain_anchored` | 1 | 0-1 | BLOCKCHAIN_SHIFT = 5 |
| `policy_state` | 2 | 0-3 | POLICY_SHIFT = 6 |
| `verb` | 24 | 1-16,777,215 | VERB_SHIFT = 8 |

---

## §4 Operaciones de RolBitMask

Fuente: Manual 1.04 §10. El RolBitMask es un vector de N bits (N = total de átomos,
~6,000). Cada bit es una posición independiente. Se opera con 4 operaciones bitwise
sobre el RolBitMask completo, NUNCA sobre el AtomBitMask individual.

| Operación | Función Rust | Uso |
|---|---|---|
| **OR** | `merge()` / `union()` | Combinar permisos de múltiples roles. El OR nunca inventa bits — solo activa los que ya existían en algún operando. |
| **AND** | `intersection()` | Mínimo privilegio. Delegación (D10): el delegado recibe solo lo que comparten delegante y delegado. |
| **AND NOT** | `without()` | Revocación quirúrgica de átomos específicos sin tocar el resto del RolBitMask. |
| **XOR** | `delta()` | Detección de cambios entre dos estados del RolBitMask. Máximo 2 operandos. |

### Herencia DAG (OR implícito)

Fuente: Manual 1.04 §10.3, Manual 1.09 §9.

El RolBitMask de un rol se calcula como el OR de sus átomos propios + los átomos de
todos sus ancestros en la closure table. El OR es implícito: `from_positions()` activa
todas las posiciones en un solo vector.

```
Rol N3 propio:        [0, 1, 5, 8]
Heredado de N4:       [0, 1, 2, 3, 5]
Heredado de N5:       [0, 1, 2, 3, 4, 5, 6]
Máscara efectiva N3:  [0, 1, 2, 3, 4, 5, 6, 8]   (OR de los 3)
```

Closure table: **1,673 filas**, 547 aristas directas, 1,126 transitivas, profundidad
máxima 7 niveles. 548 roles en un solo árbol con raíz única `ROL-SYS-SUPERUSUARIO`.

---

## §5 Tablas del catálogo de átomos

Fuente: Manual 1.03 §2-§6.

### `privilege_atom` (11 columnas, existente)

PK compuesta: `(app_code, group_code, atom_code)`. Columnas: `atom_code`, `app_code`,
`group_code`, `domain_code`, `verb_code`, `atom_name`, `atom_slug`, `atom_position`
(UNIQUE), `contextual_mask`, `logical_mask`, `created_at`.

### `privilege_atom_compiled` (9 columnas, propuesto, L0)

IR compilado por atomc. Solo IDs enteros. WORM: solo INSERT y UPDATE de is_active,
nunca DELETE ni UPDATE de ir_json. Índice: `(policy_id, is_active) WHERE is_active = true`.

### `privilege_role_atom` (existente)

Asignación átomo→rol. El RolBitMask en forma relacional. Cada fila = un bit activado.

---

## §6 Reglas de validación de átomos (G-01 a G-10)

Fuente: A.46 §2.2. Catálogo completo verificado.

| # | Regla | Error |
|---|---|---|
| G-01 | Policy con 2+ Atoms → combining_algorithm obligatorio | ATOMC-E-031 |
| G-02 | Atom con app_id ≠ null dentro de Policy con combining_algorithm | ATOMC-E-032 |
| G-03 | condition nunca se omite → null explícito | ATOMC-W-011 |
| G-04 | property_id no duplicado (target.environment ∩ condition) | ATOMC-E-021 |
| G-05 | verb_id existe en privilege_verb | ATOMC-E-014 |
| G-06 | subject.set_id existe en D98 | ATOMC-E-014 |
| G-07 | effect.decision solo Permit o Deny | ATOMC-E-051 |
| G-08 | AMOUNT sin literal numérico | ATOMC-E-042 |
| G-09 | CURRENCY sin código literal | ATOMC-E-043 |
| G-10 | atom_id sin dígitos de monto/moneda | ATOMC-E-041 |

---

## §7 Mapa anexo → manuales

| Sección | Respalda a |
|---|---|
| §2 (catálogo por dominio) | 1.03 §8 · 2.17 §4 |
| §3 (AtomBitMask) | 1.04 §3 · 2.17 §2 |
| §4 (operaciones RolBitMask) | 1.04 §10 · 2.17 §7 |
| §5 (tablas) | 1.03 §2-§6 · 2.17 §4 |
| §6 (reglas G-01..G-10) | A.46 §2.2 · 2.17 §3.1 |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-15 | Primera edición. Datos extraídos de Manuales 1.03, 1.04 y A.46. 6,000 átomos, 64-bit BitMask, 4 operaciones, 10 reglas G-01..G-10. |
