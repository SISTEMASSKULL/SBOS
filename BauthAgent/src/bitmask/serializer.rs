// ============================================================
// bAuth::bitmask::serializer — Serialización para JWT Claims
// B1.T04 — Adaptación BitMask ↔ JWT
//
// Modelo viejo (ELIMINADO):
//   "bos_bitmask": "0x00000000_0000FFFF"  ← un solo u64 hex
//
// Modelo nuevo (BitMask Dual):
//   "bos_rol_bitmask":  "AAECBAUG..."     ← RolBitMask en base64 (N bits)
//   "bos_atom_bitmask": "0x0000000C00080002" ← AtomBitMask 64-bit hex
//
// La verificación opera sobre bos_rol_bitmask.
// NUNCA sobre bos_atom_bitmask (eso reintroduce el error de escalamiento).
// ============================================================

#![allow(dead_code)]
use crate::bitmask::{AtomBitMask, RolBitMask};
use serde::{Deserialize, Serialize};

/// Claims JWT que bAuth inyecta en el token emitido por Keycloak.
///
/// Estructura que los SPIs Java (B23) inyectan en el JWT
/// durante el login, y que los PEPs (Kong, bhnexus) validan
/// en cada request.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BosJwtClaims {
    /// Rol BitMask en base64 — ONE-HOT encoding.
    /// Contiene todas las posiciones de átomo activas para este usuario.
    /// La verificación Fast-Path opera sobre este campo.
    #[serde(rename = "bos_rol_bitmask")]
    pub rol_bitmask: String,

    /// BitMask Átomo del botón/operación actual en hex — LABEL encoding.
    /// Identifica QUÉ átomo específico se está solicitando.
    /// SOLO para identificación — nunca para combinación.
    #[serde(rename = "bos_atom_bitmask")]
    pub atom_bitmask: String,

    /// Tenant ID del usuario.
    #[serde(rename = "bos_tenant_id")]
    pub tenant_id: String,

    /// ctx_id de la sesión activa (D8).
    #[serde(rename = "bos_ctx_id")]
    pub ctx_id: String,

    /// Level of Assurance alcanzado en esta sesión (1-3).
    #[serde(rename = "bos_loa")]
    pub loa: u8,
}

impl BosJwtClaims {
    /// Construye los claims JWT desde las estructuras internas.
    pub fn new(
        rol: &RolBitMask,
        atom: &AtomBitMask,
        tenant_id: &str,
        ctx_id: &str,
        loa: u8,
    ) -> Self {
        BosJwtClaims {
            rol_bitmask: rol.to_base64(),
            atom_bitmask: format!("0x{:016X}", atom.to_u64()),
            tenant_id: tenant_id.to_string(),
            ctx_id: ctx_id.to_string(),
            loa,
        }
    }

    /// Extrae el Rol BitMask desde el claim base64.
    /// `total_atoms` debe coincidir con el tamaño del catálogo global.
    pub fn rol_bitmask(&self, total_atoms: usize) -> Result<RolBitMask, String> {
        RolBitMask::from_base64(&self.rol_bitmask, total_atoms)
    }

    /// Extrae el AtomBitMask desde el claim hex.
    pub fn atom_bitmask(&self) -> AtomBitMask {
        let hex_str = self.atom_bitmask.trim_start_matches("0x").trim_start_matches("0X");
        let raw = u64::from_str_radix(hex_str, 16).unwrap_or(0);
        AtomBitMask::from_u64(raw)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::bitmask::PolicyState;

    #[test]
    fn test_jwt_claims_roundtrip() {
        let rol = RolBitMask::from_positions(&[0, 1, 3, 4, 14, 42, 100, 255], 500);
        let atom = AtomBitMask::new_simple(3, 1, 2, 1, PolicyState::Pendiente); // Tryton.Comprobantes.nuevo D3

        let claims = BosJwtClaims::new(&rol, &atom, "skull", "ctx_abc123", 2);

        // Verificar que los claims se serializan correctamente
        let json = serde_json::to_string(&claims).unwrap();
        assert!(json.contains("bos_rol_bitmask"));
        assert!(json.contains("bos_atom_bitmask"));
        assert!(json.contains("bos_tenant_id"));
        assert!(json.contains("bos_ctx_id"));
        assert!(json.contains("bos_loa"));

        // Verificar roundtrip
        let deserialized: BosJwtClaims = serde_json::from_str(&json).unwrap();
        assert_eq!(claims.rol_bitmask, deserialized.rol_bitmask);
        assert_eq!(claims.atom_bitmask, deserialized.atom_bitmask);
        assert_eq!(claims.tenant_id, deserialized.tenant_id);
        assert_eq!(claims.ctx_id, deserialized.ctx_id);
        assert_eq!(claims.loa, deserialized.loa);

        // Verificar que el RolBitMask reconstruido es funcional
        let restored_rol = deserialized.rol_bitmask(500).unwrap();
        assert!(restored_rol.check(0));
        assert!(restored_rol.check(14));
        assert_eq!(restored_rol.count_active(), rol.count_active());

        // Verificar que el AtomBitMask preserva los campos
        let restored_atom = deserialized.atom_bitmask();
        assert_eq!(restored_atom.domain(), 3);
        assert_eq!(restored_atom.app_code(), 1);
        assert_eq!(restored_atom.group_code(), 2);
        assert_eq!(restored_atom.verb_code(), 1);
        assert_eq!(restored_atom.policy_state(), PolicyState::Pendiente);
    }

    #[test]
    fn test_old_model_is_replaced() {
        // Verificar que el viejo campo "bos_bitmask" YA NO EXISTE
        let claims = BosJwtClaims {
            rol_bitmask: "AAEC".to_string(),
            atom_bitmask: "0x0000000000000001".to_string(),
            tenant_id: "skull".to_string(),
            ctx_id: "ctx_001".to_string(),
            loa: 2,
        };
        let json = serde_json::to_string(&claims).unwrap();
        assert!(!json.contains("bos_bitmask"), "El viejo campo bos_bitmask NO debe aparecer");
        assert!(json.contains("bos_rol_bitmask"), "El nuevo campo bos_rol_bitmask DEBE aparecer");
    }

    #[test]
    fn test_verification_uses_rol_not_atom() {
        // Propósito: demostrar que la verificación opera sobre el RolBitMask,
        // NUNCA sobre el AtomBitMask.
        let rol = RolBitMask::from_positions(&[5], 64); // solo posición 5 activa
        let atom = AtomBitMask::new_simple(1, 1, 1, 3, PolicyState::NoAplica); // verb_code=3 = eliminar

        let claims = BosJwtClaims::new(&rol, &atom, "skull", "ctx_test", 1);
        let restored_rol = claims.rol_bitmask(64).unwrap();

        // La verificación opera sobre el RolBitMask:
        assert!(restored_rol.check(5), "RolBitMask: permiso en pos 5 → autorizado");

        // NUNCA se debe hacer: atom.to_u64() & (1 << atom.verb_code())
        // Eso era el error del modelo viejo.
    }
}
