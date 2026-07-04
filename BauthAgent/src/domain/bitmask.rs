// ================================================================
// ⚠️ DEPRECADO — Junio 2026
// Este archivo ha sido REEMPLAZADO por crate::bitmask (modelo dual).
//
// El modelo viejo (SAM-128, constantes u8 por bit, OR directo sobre
// códigos de átomo) producía escalamiento silencioso de privilegios:
//   nuevo(1) OR editar(2) = 3 = "eliminar" 🚨
//
// El nuevo modelo (AtomBitMask 64-bit label + RolBitMask N-bit one-hot)
// separa identificación de combinación y elimina el error de raíz.
//
// Ver: SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md §4-6
//      SBOS-BAUTH-EVALUACION-INTEGRAL-v2.2.md
// ================================================================

// Re-export para backward compatibility durante la migración
pub use crate::bitmask::*;

// El tipo `BitMask` ya no existe. Usar:
//   - AtomBitMask para identificar un átomo
//   - RolBitMask  para combinar permisos entre roles
#[deprecated(since = "3.0.0", note = "Usar crate::bitmask::AtomBitMask + crate::bitmask::RolBitMask")]
pub type BitMask = u64;
