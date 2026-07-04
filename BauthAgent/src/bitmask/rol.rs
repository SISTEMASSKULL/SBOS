// ============================================================
// bAuth::bitmask::rol — Rol BitMask (N-bit one-hot encoding)
// SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md §5
//
// Cada átomo del catálogo ocupa una posición de bit fija e independiente.
// Un rol se representa marcando con 1 las posiciones de los átomos que otorga.
//
// Operaciones válidas:
//   OR (|)     — unión de roles
//   AND (&)    — mínimo privilegio (delegación hacia abajo)
//   AND NOT    — remover átomo específico
//   XOR (^)    — delta entre DOS estados (máximo 2 operandos)
//
// NUNCA: combinar AtomBitMask con estas operaciones.
// ============================================================

#![allow(dead_code)]
use super::AtomPosition;
use bitvec::prelude::*;
use serde::{Deserialize, Serialize};

/// Rol BitMask — vector de N bits donde cada bit representa un átomo.
///
/// `N` = número de átomos en el catálogo global.
/// Cada bit = 1 significa que el rol OTORGA ese átomo.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RolBitMask {
    bits: BitVec<u64, Lsb0>,
}

impl RolBitMask {
    // ─── Constructores ───

    pub fn with_capacity(n: usize) -> Self {
        RolBitMask { bits: bitvec![u64, Lsb0; 0; n] }
    }

    pub fn from_positions(positions: &[AtomPosition], total_atoms: usize) -> Self {
        let mut mask = Self::with_capacity(total_atoms);
        for &pos in positions {
            if pos < total_atoms {
                mask.bits.set(pos, true);
            }
        }
        mask
    }

    pub fn from_bytes(bytes: &[u8], total_atoms: usize) -> Self {
        let mut bits: BitVec<u64, Lsb0> = bitvec![u64, Lsb0; 0; total_atoms];
        for (byte_idx, &byte) in bytes.iter().enumerate() {
            for bit_offset in 0..8 {
                let pos = byte_idx * 8 + bit_offset;
                if pos >= total_atoms { break; }
                if (byte >> bit_offset) & 1 == 1 {
                    bits.set(pos, true);
                }
            }
        }
        RolBitMask { bits }
    }

    // ─── Operaciones bitwise ───

    /// OR — unión de conjuntos de átomos (herencia, merge de roles).
    pub fn union(&self, other: &RolBitMask) -> Self {
        RolBitMask { bits: self.bits.clone() | other.bits.clone() }
    }

    /// AND — mínimo privilegio (delegación hacia abajo).
    pub fn intersection(&self, other: &RolBitMask) -> Self {
        RolBitMask { bits: self.bits.clone() & other.bits.clone() }
    }

    /// AND NOT — remover átomo específico sin tocar el resto.
    pub fn without(&self, other: &RolBitMask) -> Self {
        RolBitMask { bits: self.bits.clone() & !other.bits.clone() }
    }

    /// XOR — delta entre DOS estados (máximo 2 operandos).
    pub fn delta(&self, other: &RolBitMask) -> Self {
        RolBitMask { bits: self.bits.clone() ^ other.bits.clone() }
    }

    // ─── B1.T08: MergeRoles ─────────────────────────────

    /// Fusiona múltiples roles aplicando OR a sus RolBitMasks.
    ///
    /// El resultado es la unión de todos los átomos otorgados por
    /// cualquiera de los roles. Sin pérdida de información —
    /// cada átomo mantiene su posición original.
    ///
    /// # Ejemplo
    /// Cajero [0,1,4] + Supervisor [0,1,2,4,5] = [0,1,2,4,5]
    pub fn merge(masks: &[&RolBitMask]) -> Option<RolBitMask> {
        if masks.is_empty() {
            return None;
        }
        let mut result = masks[0].clone();
        for m in &masks[1..] {
            result = result.union(m);
        }
        Some(result)
    }

    /// Delega un subconjunto de átomos desde un rol superior.
    /// `senior.intersection(junior)` — solo átomos presentes en AMBOS.
    pub fn delegate(senior: &RolBitMask, junior: &RolBitMask) -> RolBitMask {
        senior.intersection(junior)
    }

    /// Revoca átomos específicos de un rol.
    /// `mask.without(revoke)` — átomos en `revoke` se desactivan.
    pub fn revoke(mask: &RolBitMask, revoke: &RolBitMask) -> RolBitMask {
        mask.without(revoke)
    }

    // ─── Acceso ───

    pub fn set(&mut self, position: AtomPosition, value: bool) {
        if position < self.bits.len() {
            self.bits.set(position, value);
        }
    }

    /// Fast-Path check: verifica si el bit en position está activo (<0.5ns).
    #[inline(always)]
    pub fn check(&self, position: AtomPosition) -> bool {
        if position >= self.bits.len() { return false; }
        // SAFETY: bounds check en la línea anterior garantiza position < self.bits.len().
        // get_unchecked evita la segunda verificación del index operator [] (<0.5ns hot path).
        *unsafe { self.bits.get_unchecked(position) }
    }

    pub fn len(&self) -> usize { self.bits.len() }
    pub fn is_empty(&self) -> bool { self.bits.not_any() }
    pub fn count_active(&self) -> usize { self.bits.count_ones() }

    pub fn active_positions(&self) -> impl Iterator<Item = AtomPosition> + '_ {
        self.bits.iter_ones()
    }

    // ─── Serialización ───

    pub fn to_bytes(&self) -> Vec<u8> {
        let mut bytes = vec![0u8; self.bits.len().div_ceil(8)];
        for pos in self.bits.iter_ones() {
            bytes[pos / 8] |= 1 << (pos % 8);
        }
        bytes
    }

    pub fn to_base64(&self) -> String {
        use base64::Engine;
        base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(self.to_bytes())
    }

    pub fn from_base64(encoded: &str, total_atoms: usize) -> Result<Self, String> {
        use base64::Engine;
        let bytes = base64::engine::general_purpose::URL_SAFE_NO_PAD
            .decode(encoded).map_err(|e| format!("base64: {}", e))?;
        Ok(Self::from_bytes(&bytes, total_atoms))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_union() {
        let a = RolBitMask::from_positions(&[0, 1, 3, 4], 8);
        let b = RolBitMask::from_positions(&[1, 5, 6, 7], 8);
        let u = a.union(&b);
        for p in [0, 1, 3, 4, 5, 6, 7] { assert!(u.check(p)); }
        assert!(!u.check(2));
    }

    #[test]
    fn test_delegation_and() {
        let senior = RolBitMask::from_positions(&[0, 1, 2, 3, 4, 5, 6, 7], 8);
        let junior = RolBitMask::from_positions(&[0, 1, 3, 4], 8);
        let delegated = senior.intersection(&junior);
        assert!(delegated.check(0));
        assert!(delegated.check(1));
        assert!(!delegated.check(2)); // senior lo tiene, junior no
    }

    #[test]
    fn test_without() {
        let mask = RolBitMask::from_positions(&[0, 1, 3, 4, 14], 64);
        let remove = RolBitMask::from_positions(&[14], 64);
        let result = mask.without(&remove);
        assert!(result.check(0));
        assert!(!result.check(14));
    }

    #[test]
    fn test_delta() {
        let before = RolBitMask::from_positions(&[0, 1, 3], 8);
        let after = RolBitMask::from_positions(&[0, 1, 4], 8);
        let d = before.delta(&after);
        assert!(d.check(3)); // estaba, ya no
        assert!(d.check(4)); // no estaba, ahora sí
        assert!(!d.check(0)); // sin cambio
    }

    #[test]
    fn test_fast_path() {
        let mask = RolBitMask::from_positions(&[42, 100, 255], 256);
        assert!(mask.check(42));
        assert!(!mask.check(0));
    }

    #[test]
    fn test_base64_roundtrip() {
        let positions = vec![0, 1, 3, 4, 14, 42, 100, 255];
        let mask = RolBitMask::from_positions(&positions, 500);
        let b64 = mask.to_base64();
        assert!(!b64.is_empty(), "base64 no debe estar vacío");
        let restored = RolBitMask::from_base64(&b64, 500).expect("from_base64 debe funcionar");
        // Verificar que las posiciones activas sobreviven el roundtrip
        assert_eq!(mask.count_active(), restored.count_active());
        for pos in &positions {
            assert!(restored.check(*pos), "pos {} debe estar activa", pos);
        }
    }

    #[test]
    fn test_or_does_not_invent_permissions() {
        let a = RolBitMask::from_positions(&[0], 8);
        let b = RolBitMask::from_positions(&[1], 8);
        let combined = a.union(&b);
        assert!(!combined.check(2), "OR no debe inventar bits");
    }

    // ─── B1.T08: MergeRoles tests ─────────────────────

    #[test]
    fn test_merge_multiple_roles() {
        let cajero = RolBitMask::from_positions(&[0, 1, 4, 6, 8], 180);
        let supervisor = RolBitMask::from_positions(&[0, 1, 2, 4, 5, 6, 7, 8, 9], 180);
        let merged = RolBitMask::merge(&[&cajero, &supervisor]).unwrap();

        // La unión debe contener todos los átomos de ambos
        for pos in [0, 1, 2, 4, 5, 6, 7, 8, 9] {
            assert!(merged.check(pos), "falta posición {}", pos);
        }
        assert!(!merged.check(3), "no debe tener posición 3");
        assert_eq!(merged.count_active(), 9);
    }

    #[test]
    fn test_merge_empty_returns_none() {
        assert!(RolBitMask::merge(&[]).is_none());
    }

    #[test]
    fn test_delegate_and_reduction() {
        let senior = RolBitMask::from_positions(&[0, 1, 2, 3, 4, 5, 6, 7, 8, 9], 180);
        let junior = RolBitMask::from_positions(&[0, 1, 4, 6, 8], 180);
        let delegated = RolBitMask::delegate(&senior, &junior);
        // delegado = senior AND junior = junior (mínimo privilegio)
        assert_eq!(delegated.count_active(), 5);
        assert!(delegated.check(0));
        assert!(!delegated.check(2)); // senior lo tiene, junior no → fuera
    }

    #[test]
    fn test_revoke_specific_atom() {
        let mask = RolBitMask::from_positions(&[0, 1, 2, 3, 4], 180);
        let revoke = RolBitMask::from_positions(&[2], 180);
        let result = RolBitMask::revoke(&mask, &revoke);
        assert!(result.check(0));
        assert!(result.check(1));
        assert!(!result.check(2), "átomo 2 debe estar revocado");
        assert!(result.check(3));
        assert_eq!(result.count_active(), 4);
    }

    #[test]
    fn test_merge_preserves_independent_positions() {
        // Verifica que OR no corrompe posiciones independientes (one-hot encoding)
        let a = RolBitMask::from_positions(&[0, 50, 100, 150], 180);
        let b = RolBitMask::from_positions(&[25, 75, 125, 175], 180);
        let merged = RolBitMask::merge(&[&a, &b]).unwrap();
        assert_eq!(merged.count_active(), 8);
        for pos in [0, 25, 50, 75, 100, 125, 150, 175] {
            assert!(merged.check(pos));
        }
    }
}
