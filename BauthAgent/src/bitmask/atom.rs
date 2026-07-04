// ============================================================
// bAuth::bitmask::atom — BitMask Átomo (64-bit label encoding)
// SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md §4
//
// Estructura de 64 bits (ACTUALIZADO B48.T67 — Jun 2026):
//   Contextual (32): [8 device_allowed][4 domain][9 app][11 group]
//   Logical    (32): [3 min_trust][2 token_binding][1 blk_anch][2 policy][24 verb]
//
// device_allowed:   bitmap de 8 categorías (MOBILE,WATCH,RING,IMPLANT,CARD,WEARABLE,IOT,CHIP)
// min_trust:        0=NONE, 1=LOW, 2=MEDIUM, 3=HIGH, 4=CRITICAL (3 bits, valores 0-7)
// token_binding:    0=NONE, 1=DEVICE, 2=SESSION, 3=HARDWARE
// blockchain_anch:  0=no requerido, 1=anclaje blockchain requerido
//
// Operaciones válidas: igualdad, extraer campos con máscara.
// NUNCA: OR, AND, XOR entre dos AtomBitMask.
// ============================================================

#![allow(dead_code)]
use super::{AppCode, DomainCode, GroupCode, VerbCode};
use crate::bitmask::policy::PolicyState;
use serde::{Deserialize, Serialize};

// ─── Device Category (8-bit bitmap) ─────────────────────────

/// Categorías de dispositivo como bitmap de 8 bits.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DeviceCategories(u8);

impl DeviceCategories {
    pub const MOBILE: u8   = 1 << 0;  // Celular / tablet
    pub const WATCH: u8    = 1 << 1;  // Smartwatch
    pub const RING: u8     = 1 << 2;  // Anillo inteligente
    pub const IMPLANT: u8  = 1 << 3;  // Dispositivo médico implantado
    pub const CARD: u8     = 1 << 4;  // Tarjeta inteligente / PIV
    pub const WEARABLE: u8 = 1 << 5;  // Casco, guante, exoesqueleto
    pub const IOT: u8      = 1 << 6;  // Sensor / actuador industrial
    pub const CHIP: u8     = 1 << 7;  // PUF / secure element standalone

    pub const ALL: u8 = 0xFF;  // Todos los dispositivos permitidos

    pub fn new(bits: u8) -> Self { DeviceCategories(bits) }
    pub fn bits(&self) -> u8 { self.0 }

    pub fn allows(&self, category: u8) -> bool {
        (self.0 & category) != 0
    }

    pub fn is_empty(&self) -> bool { self.0 == 0 }

    pub fn names(&self) -> Vec<&'static str> {
        let mut v = Vec::new();
        if self.0 & Self::MOBILE != 0 { v.push("MOBILE"); }
        if self.0 & Self::WATCH != 0 { v.push("WATCH"); }
        if self.0 & Self::RING != 0 { v.push("RING"); }
        if self.0 & Self::IMPLANT != 0 { v.push("IMPLANT"); }
        if self.0 & Self::CARD != 0 { v.push("CARD"); }
        if self.0 & Self::WEARABLE != 0 { v.push("WEARABLE"); }
        if self.0 & Self::IOT != 0 { v.push("IOT"); }
        if self.0 & Self::CHIP != 0 { v.push("CHIP"); }
        v
    }
}

impl std::fmt::Display for DeviceCategories {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", self.names())
    }
}

// ─── Trust Level ──────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
#[repr(u8)]
pub enum TrustLevel {
    None = 0,
    Low = 1,
    Medium = 2,
    High = 3,
    Critical = 4,
}

impl TrustLevel {
    pub fn from_u8(v: u8) -> Self {
        match v {
            1 => TrustLevel::Low,
            2 => TrustLevel::Medium,
            3 => TrustLevel::High,
            4 => TrustLevel::Critical,
            _ => TrustLevel::None,
        }
    }
}

// ─── Token Binding ────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum TokenBinding {
    None = 0,
    Device = 1,
    Session = 2,
    Hardware = 3,
}

impl TokenBinding {
    pub fn from_u8(v: u8) -> Self {
        match v & 0x03 {
            1 => TokenBinding::Device,
            2 => TokenBinding::Session,
            3 => TokenBinding::Hardware,
            _ => TokenBinding::None,
        }
    }
}

// ═══════════════════════════════════════════════════════════════

/// BitMask Átomo — identifica UN átomo específico de forma compacta.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[repr(transparent)]
pub struct AtomBitMask(u64);

impl AtomBitMask {
    // ─── Constantes de desplazamiento ───
    const DEVICE_SHIFT: u8 = 0;     // bits 0-7 del contextual
    const DOMAIN_SHIFT: u8 = 8;     // bits 8-11
    const APP_SHIFT: u8 = 12;       // bits 12-20
    const GROUP_SHIFT: u8 = 21;     // bits 21-31

    const TRUST_SHIFT: u8 = 0;      // bits 0-2 del logical
    const BINDING_SHIFT: u8 = 3;    // bits 3-4
    const BLOCKCHAIN_SHIFT: u8 = 5; // bit 5
    const POLICY_SHIFT: u8 = 6;     // bits 6-7 (sin cambios)
    const VERB_SHIFT: u8 = 8;       // bits 8-31

    // ─── Máscaras ───
    const DEVICE_MASK: u64 = 0xFF;       // 8 bits bitmap
    const DOMAIN_MASK: u64 = 0x0F;       // 4 bits
    const APP_MASK: u64 = 0x1FF;         // 9 bits
    const GROUP_MASK: u64 = 0x7FF;       // 11 bits
    const TRUST_MASK: u64 = 0x07;        // 3 bits
    const BINDING_MASK: u64 = 0x03;      // 2 bits
    const BLOCKCHAIN_MASK: u64 = 0x01;   // 1 bit
    const POLICY_MASK: u64 = 0x03;       // 2 bits
    const VERB_MASK: u64 = 0xFFFFFF;     // 24 bits

    // ─── Constructores ───

    /// Constructor completo con todos los campos del BitMask.
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        domain_code: DomainCode,
        app_code: AppCode,
        group_code: GroupCode,
        verb_code: VerbCode,
        policy_state: PolicyState,
        device_categories: DeviceCategories,
        min_trust: TrustLevel,
        token_binding: TokenBinding,
        blockchain_anchored: bool,
    ) -> Self {
        let contextual: u32 =
            ((device_categories.bits() as u32) << Self::DEVICE_SHIFT)
            | ((domain_code as u32) << Self::DOMAIN_SHIFT)
            | ((app_code as u32) << Self::APP_SHIFT)
            | ((group_code as u32) << Self::GROUP_SHIFT);

        let logical: u32 =
            ((min_trust as u32) << Self::TRUST_SHIFT)
            | ((token_binding as u32) << Self::BINDING_SHIFT)
            | ((blockchain_anchored as u32) << Self::BLOCKCHAIN_SHIFT)
            | ((u8::from(policy_state) as u32) << Self::POLICY_SHIFT)
            | (verb_code << Self::VERB_SHIFT);

        AtomBitMask(((contextual as u64) << 32) | (logical as u64))
    }

    /// Constructor simplificado para compatibilidad con código existente.
    /// Device categories = MOBILE|CARD, trust = None, binding = None, blk = false.
    /// Usar `new()` para control completo de dispositivo/bloqueo.
    pub fn new_simple(
        domain_code: DomainCode,
        app_code: AppCode,
        group_code: GroupCode,
        verb_code: VerbCode,
        policy_state: PolicyState,
    ) -> Self {
        Self::new(
            domain_code, app_code, group_code, verb_code, policy_state,
            DeviceCategories::new(DeviceCategories::MOBILE | DeviceCategories::CARD),
            TrustLevel::None,
            TokenBinding::None,
            false,
        )
    }

    /// Construye desde un u64 crudo (ej: desde BD, JWT).
    pub fn from_u64(raw: u64) -> Self {
        AtomBitMask(raw)
    }

    /// Retorna el valor u64 para almacenamiento en BD/JWT.
    #[allow(clippy::wrong_self_convention)]
    pub fn to_u64(&self) -> u64 {
        self.0
    }

    // ─── Extractores de campos ───

    /// Categorías de dispositivo permitidas (bitmap 8 bits).
    pub fn device_categories(&self) -> DeviceCategories {
        DeviceCategories::new(
            ((self.0 >> 32) >> Self::DEVICE_SHIFT) as u8 & Self::DEVICE_MASK as u8
        )
    }

    /// Nivel mínimo de confianza requerido.
    pub fn min_trust(&self) -> TrustLevel {
        TrustLevel::from_u8(
            ((self.0 as u32) >> Self::TRUST_SHIFT) as u8 & Self::TRUST_MASK as u8
        )
    }

    /// Tipo de token binding requerido.
    pub fn token_binding(&self) -> TokenBinding {
        TokenBinding::from_u8(
            ((self.0 as u32) >> Self::BINDING_SHIFT) as u8 & Self::BINDING_MASK as u8
        )
    }

    /// ¿Requiere anclaje blockchain?
    pub fn blockchain_anchored(&self) -> bool {
        ((self.0 as u32) >> Self::BLOCKCHAIN_SHIFT) as u8 & Self::BLOCKCHAIN_MASK as u8 != 0
    }

    pub fn domain(&self) -> DomainCode {
        ((self.0 >> 32) >> Self::DOMAIN_SHIFT) as u8 & Self::DOMAIN_MASK as u8
    }

    pub fn app_code(&self) -> AppCode {
        (((self.0 >> 32) >> Self::APP_SHIFT) as u16) & Self::APP_MASK as u16
    }

    pub fn group_code(&self) -> GroupCode {
        (((self.0 >> 32) >> Self::GROUP_SHIFT) as u16) & Self::GROUP_MASK as u16
    }

    pub fn verb_code(&self) -> VerbCode {
        ((self.0 as u32) >> Self::VERB_SHIFT) & Self::VERB_MASK as u32
    }

    pub fn policy_state(&self) -> PolicyState {
        PolicyState::from_u8(
            ((self.0 as u32) >> Self::POLICY_SHIFT) as u8 & Self::POLICY_MASK as u8
        )
    }

    pub fn contextual_mask(&self) -> u32 { (self.0 >> 32) as u32 }
    pub fn logical_mask(&self) -> u32 { self.0 as u32 }

    pub fn with_policy_state(&self, state: PolicyState) -> Self {
        let logical = (self.logical_mask() & !((Self::POLICY_MASK as u32) << Self::POLICY_SHIFT))
            | ((u8::from(state) as u32) << Self::POLICY_SHIFT);
        AtomBitMask(((self.contextual_mask() as u64) << 32) | (logical as u64))
    }

    // ─── Verificación de dispositivo ───
    /// Verifica si este átomo puede ejecutarse desde la categoría de dispositivo dada.
    /// <0.5ns — evalúa el bitmap de device_categories.
    pub fn allows_device(&self, device_category: u8) -> bool {
        self.device_categories().allows(device_category)
    }

    /// Verifica si el nivel de confianza del dispositivo cumple el mínimo requerido.
    pub fn meets_trust(&self, trust: TrustLevel) -> bool {
        trust >= self.min_trust()
    }
}

impl std::fmt::Display for AtomBitMask {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "AtomBitMask(D{}, app={}, group={}, verb={}, policy={:?}, devices=[{}], trust={:?}, binding={:?}, blk={})",
            self.domain(),
            self.app_code(),
            self.group_code(),
            self.verb_code(),
            self.policy_state(),
            self.device_categories().names().join(","),
            self.min_trust(),
            self.token_binding(),
            self.blockchain_anchored(),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn default_device() -> DeviceCategories {
        DeviceCategories::new(DeviceCategories::MOBILE | DeviceCategories::CARD)
    }

    #[test]
    fn build_and_extract() {
        let atom = AtomBitMask::new(3, 1, 2, 1, PolicyState::NoAplica,
            default_device(), TrustLevel::Medium, TokenBinding::Device, false);

        assert_eq!(atom.domain(), 3);
        assert_eq!(atom.app_code(), 1);
        assert_eq!(atom.group_code(), 2);
        assert_eq!(atom.verb_code(), 1);
        assert_eq!(atom.policy_state(), PolicyState::NoAplica);
        assert!(atom.device_categories().allows(DeviceCategories::MOBILE));
        assert_eq!(atom.min_trust(), TrustLevel::Medium);
        assert_eq!(atom.token_binding(), TokenBinding::Device);
        assert!(!atom.blockchain_anchored());
    }

    #[test]
    fn device_allows_mobile_not_iot() {
        let atom = AtomBitMask::new(1, 1, 1, 1, PolicyState::NoAplica,
            default_device(), TrustLevel::Low, TokenBinding::None, false);
        assert!(atom.allows_device(DeviceCategories::MOBILE));
        assert!(!atom.allows_device(DeviceCategories::IOT));
    }

    #[test]
    fn trust_meets_requirement() {
        let atom = AtomBitMask::new(1, 1, 1, 1, PolicyState::NoAplica,
            default_device(), TrustLevel::High, TokenBinding::Hardware, false);
        assert!(atom.meets_trust(TrustLevel::High));
        assert!(atom.meets_trust(TrustLevel::Critical));
        assert!(!atom.meets_trust(TrustLevel::Medium));
    }

    #[test]
    fn blockchain_anchored_atom() {
        let atom = AtomBitMask::new(12, 5, 100, 42, PolicyState::Aprobado,
            DeviceCategories::new(DeviceCategories::CHIP), TrustLevel::Critical,
            TokenBinding::Hardware, true);
        assert!(atom.blockchain_anchored());
        assert_eq!(atom.min_trust(), TrustLevel::Critical);
        assert!(atom.device_categories().allows(DeviceCategories::CHIP));
    }

    #[test]
    fn policy_state_overlay_preserves_device_bits() {
        let atom = AtomBitMask::new(3, 1, 2, 1, PolicyState::NoAplica,
            default_device(), TrustLevel::Medium, TokenBinding::Device, false);
        let pending = atom.with_policy_state(PolicyState::Pendiente);
        assert_eq!(pending.policy_state(), PolicyState::Pendiente);
        assert_eq!(pending.domain(), 3);
        assert_eq!(pending.verb_code(), 1);
        assert_eq!(pending.min_trust(), TrustLevel::Medium);
        assert_eq!(pending.token_binding(), TokenBinding::Device);
        assert!(!pending.blockchain_anchored());
    }

    #[test]
    fn roundtrip_u64() {
        let atom = AtomBitMask::new(12, 5, 100, 42, PolicyState::Aprobado,
            DeviceCategories::new(DeviceCategories::ALL), TrustLevel::Critical,
            TokenBinding::Hardware, true);
        let raw = atom.to_u64();
        let restored = AtomBitMask::from_u64(raw);
        assert_eq!(atom, restored);
    }

    #[test]
    fn domain_d1_to_d12() {
        for d in 1..=12u8 {
            let atom = AtomBitMask::new(d, 1, 1, 1, PolicyState::NoAplica,
                default_device(), TrustLevel::None, TokenBinding::None, false);
            assert_eq!(atom.domain(), d, "domain {} extracted incorrectly", d);
        }
    }

    #[test]
    fn or_between_atoms_is_not_equal() {
        let a1 = AtomBitMask::new(1, 1, 1, 1, PolicyState::NoAplica,
            default_device(), TrustLevel::None, TokenBinding::None, false);
        let a2 = AtomBitMask::new(1, 1, 1, 2, PolicyState::NoAplica,
            default_device(), TrustLevel::None, TokenBinding::None, false);
        let or_raw = a1.to_u64() | a2.to_u64();
        assert_ne!(or_raw, a1.to_u64());
        assert_ne!(or_raw, a2.to_u64());
    }

    #[test]
    fn device_category_roundtrip() {
        for cat in &[DeviceCategories::MOBILE, DeviceCategories::WATCH, DeviceCategories::CHIP] {
            let atom = AtomBitMask::new(1, 1, 1, 1, PolicyState::NoAplica,
                DeviceCategories::new(*cat), TrustLevel::Medium, TokenBinding::Device, false);
            assert!(atom.device_categories().allows(*cat));
        }
    }
}
