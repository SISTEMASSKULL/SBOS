// ============================================================
// bAuth::bitmask — Motor BitMask Dual v3.0
// SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md §4-6
//
// DOS estructuras separadas:
//   AtomBitMask (64-bit label encoding) — identifica UN átomo
//   RolBitMask  (N-bit one-hot encoding) — combina permisos entre roles
//
// NUNCA combinar AtomBitMask con OR/AND/XOR.
// Solo operar con OR/AND/XOR sobre RolBitMask.
// ============================================================

#![allow(dead_code)]
use serde::{Deserialize, Serialize};

pub mod atom;
pub mod rol;
pub mod policy;
pub mod serializer;
pub mod fastpath;
pub mod catalog;
pub mod closure;
pub mod conflict;
pub mod resolver;
pub mod registry;

pub use atom::AtomBitMask;
pub use rol::RolBitMask;
pub use policy::PolicyState;
  // B48.T67: device context bits

/// Posición de un átomo en el catálogo global (0-based, inmutable).
/// Es el índice del bit en el RolBitMask.
pub type AtomPosition = usize;

/// Código de dominio de soberanía (1-15, 4 bits).
/// D1=Lógico, D2=Físico, ..., D12=Blockchain.
pub type DomainCode = u8;

/// Código de aplicación (1-511, 9 bits).
pub type AppCode = u16;

/// Código de grupo funcional (1-2047, 11 bits).
pub type GroupCode = u16;

/// Código de verbo (1-255, label encoding).
/// 1=nuevo, 2=editar, 3=eliminar, 4=ver.
pub type VerbCode = u32;

/// Resultado de la evaluación de acceso.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AccessResult {
    Permitido,
    Denegado,
    Pendiente,
}

impl AccessResult {
    pub fn as_u8(&self) -> u8 {
        match self {
            AccessResult::Denegado => 0,
            AccessResult::Permitido => 1,
            AccessResult::Pendiente => 2,
        }
    }

    pub fn from_u8(v: u8) -> Option<Self> {
        match v {
            0 => Some(AccessResult::Denegado),
            1 => Some(AccessResult::Permitido),
            2 => Some(AccessResult::Pendiente),
            _ => None,
        }
    }
}
