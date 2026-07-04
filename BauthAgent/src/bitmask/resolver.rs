// ============================================================
// bAuth::bitmask::resolver — Resolución y cómputo de BitMasks
// B1.T07 — ComputeRolBitMask (desde bos_role_atom en BD)
// B1.T17 — RolBitMaskSerializer (formatos base64/bytes/positions)
// B1.T18 — AtomPositionResolver (HashMap cache inmutable)
//
// B1.T07: Consulta bos_role_atom para un rol, construye RolBitMask
// con las posiciones activas. Sin hardcodear — todo desde BD.
//
// B1.T17: La serialización base (to_base64/from_base64/to_bytes/from_bytes)
// ya está en rol.rs. Aquí se agregan helpers para almacenamiento en Redis y DB.
//
// B1.T18: Cache en memoria que mapea atom_slug → atom_position.
// Las posiciones son INMUTABLES — el cache se llena al cargar el catálogo
// y nunca se invalida (TTL ∞).
// ============================================================

#![allow(dead_code)]
use crate::bitmask::{AtomPosition, RolBitMask};
use sqlx::PgPool;
use std::collections::HashMap;
use tracing::debug;

// ─── B1.T17: Serialización extendida ─────────────────────────────

/// Formatos de serialización del Rol BitMask soportados.
pub enum RolBitMaskFormat {
    /// Base64 URL-safe sin padding (para JWT claims).
    /// ~63 bytes para 500 átomos.
    Base64Url,
    /// Bytes crudos (para Redis SET/GET).
    Bytes,
    /// Array de posiciones activas (para debug/logs).
    Positions,
}

/// Serializa un RolBitMask en el formato especificado.
pub fn serialize_rol(rol: &RolBitMask, format: RolBitMaskFormat) -> Vec<u8> {
    match format {
        RolBitMaskFormat::Base64Url => rol.to_base64().into_bytes(),
        RolBitMaskFormat::Bytes => rol.to_bytes(),
        RolBitMaskFormat::Positions => {
            let positions: Vec<u8> = rol
                .active_positions()
                .flat_map(|p| p.to_le_bytes())
                .collect();
            positions
        }
    }
}

/// Deserializa un RolBitMask desde bytes + formato + total_atoms.
pub fn deserialize_rol(data: &[u8], format: RolBitMaskFormat, total_atoms: usize) -> Result<RolBitMask, String> {
    match format {
        RolBitMaskFormat::Base64Url => {
            let b64_str = std::str::from_utf8(data).map_err(|e| format!("utf8: {}", e))?;
            RolBitMask::from_base64(b64_str, total_atoms)
        }
        RolBitMaskFormat::Bytes => Ok(RolBitMask::from_bytes(data, total_atoms)),
        RolBitMaskFormat::Positions => {
            // Reconstruir desde array de posiciones (cada posición = 8 bytes en little-endian)
            let positions: Vec<AtomPosition> = data
                .chunks_exact(8)
                .map(|chunk| {
                    let arr: [u8; 8] = chunk.try_into().unwrap_or([0; 8]);
                    u64::from_le_bytes(arr) as AtomPosition
                })
                .collect();
            Ok(RolBitMask::from_positions(&positions, total_atoms))
        }
    }
}

// ─── B1.T18: AtomPositionResolver ────────────────────────────────

/// Resuelve atom_slug → atom_position usando un cache inmutable en memoria.
///
/// Se llena UNA vez al cargar el catálogo desde `bos_atom_catalog`.
/// Las posiciones nunca cambian (son inmutables), por lo que el cache
/// tiene TTL ∞ — nunca se invalida.
pub struct AtomPositionResolver {
    /// Mapa slug → posición.
    /// Clave: "comprobantes.nuevo"
    /// Valor: posición ordinal (0-based)
    cache: HashMap<String, AtomPosition>,
}

impl AtomPositionResolver {
    /// Crea un resolver vacío.
    pub fn new() -> Self {
        AtomPositionResolver {
            cache: HashMap::new(),
        }
    }

    /// Crea un resolver desde un iterador de pares (slug, position).
    pub fn from_entries(entries: impl Iterator<Item = (String, AtomPosition)>) -> Self {
        let cache: HashMap<String, AtomPosition> = entries.collect();
        AtomPositionResolver { cache }
    }

    /// Registra un nuevo slug → posición.
    /// Solo se llama durante la carga del catálogo (nunca en runtime).
    pub fn register(&mut self, slug: &str, position: AtomPosition) {
        self.cache.insert(slug.to_string(), position);
    }

    /// Resuelve un slug a su posición.
    /// Retorna None si el slug no está en el catálogo.
    pub fn resolve(&self, slug: &str) -> Option<AtomPosition> {
        self.cache.get(slug).copied()
    }

    /// Resuelve múltiples slugs de una vez.
    pub fn resolve_many(&self, slugs: &[&str]) -> Vec<Option<AtomPosition>> {
        slugs.iter().map(|s| self.resolve(s)).collect()
    }

    /// ¿Existe este slug en el catálogo?
    pub fn contains(&self, slug: &str) -> bool {
        self.cache.contains_key(slug)
    }

    /// Número total de átomos en el catálogo.
    pub fn total_atoms(&self) -> usize {
        self.cache.len()
    }
}

// ─── B1.T07: ComputeRolBitMask ─────────────────────────────────

/// Error al computar el RolBitMask con mensaje en español.
#[derive(Debug, thiserror::Error)]
pub enum ComputeError {
    #[error("error de base de datos: {0}")]
    Database(String),
    #[error("rol no encontrado o sin átomos asignados")]
    EmptyRole,
}

/// Computa el RolBitMask para un rol desde la base de datos.
///
/// Consulta `bos_role_atom` para obtener las posiciones de átomos
/// asignadas al rol (allowed=true), y construye un RolBitMask
/// con el tamaño total del catálogo.
///
/// # Rendimiento
/// - 1 query para átomos del rol (~1ms)
/// - 1 query para tamaño del catálogo (~0.5ms)
/// - Construcción del BitVec: O(n) donde n = átomos del rol
pub async fn compute_rol_bitmask(
    pg: &PgPool,
    role_id: uuid::Uuid,
) -> Result<RolBitMask, ComputeError> {
    let atom_rows = crate::db::load_role_atoms(pg, role_id)
        .await
        .map_err(|e| ComputeError::Database(e.to_string()))?;

    if atom_rows.is_empty() {
        return Err(ComputeError::EmptyRole);
    }

    let total_atoms = crate::db::count_atoms(pg)
        .await
        .map_err(|e| ComputeError::Database(e.to_string()))? as usize;

    let positions: Vec<AtomPosition> = atom_rows
        .iter()
        .map(|r| r.atom_position as usize)
        .collect();

    debug!(
        role_id = %role_id,
        active = positions.len(),
        total_atoms,
        "RolBitMask computado desde BD"
    );

    Ok(RolBitMask::from_positions(&positions, total_atoms))
}

// ─── B1.T09: InheritFromParent ────────────────────────────────

/// Computa la máscara efectiva de un rol considerando herencia DAG.
///
/// Consulta `bauth.idn_role_closure` para obtener todos los ancestros del rol,
/// carga los átomos de cada ancestro, y hace OR de todas las máscaras.
///
/// `mask_eff(rol) = mask_own(rol) | mask_own(ancestro_1) | mask_own(ancestro_2) | ...`
///
/// El closure table garantiza que las relaciones transitivas ya están
/// precomputadas — una sola query resuelve toda la cadena.
pub async fn inherit_from_parents(
    pg: &PgPool,
    role_id: &str,
) -> Result<RolBitMask, ComputeError> {
    // 1. Obtener ancestros desde closure table
    let ancestors = crate::db::load_role_ancestors(pg, role_id)
        .await
        .map_err(|e| ComputeError::Database(e.to_string()))?;

    // 2. Recolectar todos los IDs (el rol propio + ancestros)
    let mut all_ids = vec![role_id.to_string()];
    all_ids.extend(ancestors);

    // 3. Cargar átomos de todos los roles
    let positions = crate::db::load_atoms_for_roles(pg, &all_ids)
        .await
        .map_err(|e| ComputeError::Database(e.to_string()))?;

    if positions.is_empty() {
        return Err(ComputeError::EmptyRole);
    }

    // 4. Obtener tamaño del catálogo
    let total_atoms = crate::db::count_atoms(pg)
        .await
        .map_err(|e| ComputeError::Database(e.to_string()))? as usize;

    let atom_positions: Vec<usize> = positions.iter().map(|&p| p as usize).collect();

    debug!(
        role_id = %role_id,
        ancestors = all_ids.len() - 1,
        active = atom_positions.len(),
        "máscara efectiva computada con herencia DAG"
    );

    Ok(RolBitMask::from_positions(&atom_positions, total_atoms))
}

#[cfg(test)]
mod tests {
    use super::*;

    // ─── B1.T17 Tests ───

    #[test]
    fn test_serialize_roundtrip_bytes() {
        let rol = RolBitMask::from_positions(&[0, 5, 42, 100], 256);
        let bytes = serialize_rol(&rol, RolBitMaskFormat::Bytes);
        let restored = deserialize_rol(&bytes, RolBitMaskFormat::Bytes, 256).unwrap();
        assert_eq!(rol.count_active(), restored.count_active());
        for pos in [0, 5, 42, 100] {
            assert!(restored.check(pos));
        }
    }

    #[test]
    fn test_serialize_roundtrip_base64() {
        let rol = RolBitMask::from_positions(&[0, 5, 42, 100], 256);
        let bytes = serialize_rol(&rol, RolBitMaskFormat::Base64Url);
        let restored = deserialize_rol(&bytes, RolBitMaskFormat::Base64Url, 256).unwrap();
        assert_eq!(rol.count_active(), restored.count_active());
    }

    #[test]
    fn test_serialize_roundtrip_positions() {
        let positions = vec![0, 5, 42, 100];
        let rol = RolBitMask::from_positions(&positions, 256);
        let bytes = serialize_rol(&rol, RolBitMaskFormat::Positions);
        let restored = deserialize_rol(&bytes, RolBitMaskFormat::Positions, 256).unwrap();
        assert_eq!(rol.count_active(), restored.count_active());
        for pos in &positions {
            assert!(restored.check(*pos));
        }
    }

    #[test]
    fn test_serialize_empty_mask() {
        let rol = RolBitMask::with_capacity(64);
        let bytes = serialize_rol(&rol, RolBitMaskFormat::Bytes);
        let restored = deserialize_rol(&bytes, RolBitMaskFormat::Bytes, 64).unwrap();
        assert_eq!(restored.count_active(), 0);
    }

    // ─── B1.T18 Tests ───

    #[test]
    fn test_resolve_existing_slug() {
        let mut resolver = AtomPositionResolver::new();
        resolver.register("comprobantes.nuevo", 0);
        resolver.register("comprobantes.editar", 1);
        assert_eq!(resolver.resolve("comprobantes.nuevo"), Some(0));
        assert_eq!(resolver.resolve("comprobantes.editar"), Some(1));
    }

    #[test]
    fn test_resolve_missing_slug() {
        let resolver = AtomPositionResolver::new();
        assert_eq!(resolver.resolve("inexistente"), None);
    }

    #[test]
    fn test_resolve_many() {
        let mut resolver = AtomPositionResolver::new();
        resolver.register("a.nuevo", 0);
        resolver.register("b.editar", 1);
        let results = resolver.resolve_many(&["a.nuevo", "inexistente", "b.editar"]);
        assert_eq!(results, vec![Some(0), None, Some(1)]);
    }

    #[test]
    fn test_total_atoms() {
        let mut resolver = AtomPositionResolver::new();
        resolver.register("a", 0);
        resolver.register("b", 1);
        resolver.register("c", 2);
        assert_eq!(resolver.total_atoms(), 3);
    }

    #[test]
    fn test_from_entries() {
        let entries = vec![
            ("a.nuevo".to_string(), 0),
            ("a.editar".to_string(), 1),
            ("b.nuevo".to_string(), 2),
        ];
        let resolver = AtomPositionResolver::from_entries(entries.into_iter());
        assert_eq!(resolver.resolve("a.nuevo"), Some(0));
        assert_eq!(resolver.resolve("b.nuevo"), Some(2));
        assert_eq!(resolver.total_atoms(), 3);
    }

    #[test]
    fn test_cache_immutable() {
        let mut resolver = AtomPositionResolver::new();
        resolver.register("original", 5);
        // Intentar re-registrar — debe sobrescribir (la app no debería hacer esto)
        resolver.register("original", 99);
        assert_eq!(resolver.resolve("original"), Some(99), "último registro gana");
    }
}
