// ============================================================
// bAuth::bitmask::policy — Estado de Política (2 bits)
// SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md §4.3, §7.2
//
// Bits 6-7 del Dominio Lógico.
// Se SUPERIMPONE en tiempo de ejecución — NO se almacena en catálogo.
// ============================================================

use serde::{Deserialize, Serialize};

/// Estado de política de dominio después de la evaluación.
///
/// Se superpone sobre los bits 6-7 del Dominio Lógico del
/// BitMask Átomo en tiempo de ejecución.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[repr(u8)]
pub enum PolicyState {
    /// 00 — No aplica. D1, D2 (sin política adicional).
    NoAplica = 0,
    /// 01 — Pendiente. Requiere step-up, segunda firma, etc.
    Pendiente = 1,
    /// 10 — Aprobado. Política evaluada favorablemente.
    Aprobado = 2,
    /// 11 — Rechazado. Política evaluada desfavorablemente.
    Rechazado = 3,
}

impl PolicyState {
    /// Convierte desde los 2 bits crudos.
    pub fn from_u8(v: u8) -> Self {
        match v & 0x03 {
            0 => PolicyState::NoAplica,
            1 => PolicyState::Pendiente,
            2 => PolicyState::Aprobado,
            _ => PolicyState::Rechazado,
        }
    }

    /// ¿Requiere acción adicional?
    pub fn is_pending(&self) -> bool {
        matches!(self, PolicyState::Pendiente)
    }

    /// ¿La política fue satisfactoria?
    pub fn is_approved(&self) -> bool {
        matches!(self, PolicyState::Aprobado)
    }

    /// ¿La política fue rechazada?
    pub fn is_rejected(&self) -> bool {
        matches!(self, PolicyState::Rechazado)
    }
}

impl From<PolicyState> for u8 {
    fn from(s: PolicyState) -> u8 {
        s as u8
    }
}
