// ============================================================
// bauth::bitmask::resolver — Serialización y cómputo de BitMasks
//
// B1.T17 — RolBitMaskSerializer (formatos base64/bytes/positions)
// B1.T18 — AtomPositionResolver (HashMap cache inmutable)
// B1.T07 — ComputeRolBitMask (REAL — privilege_atom_grant modelo G-12)
// B1.T09 — InheritFromParent (REAL — closure canónica + G-12 OR-herencia)
//
// Tablas canónicas usadas:
//   bauth.idn_roles_template    → count_atoms() (nodos tipo 'atom')
//   bauth.privilege_atom_grant  → load_role_atom_positions() (G-12 5 cols)
//   bauth.idn_roles_rol_closure → load_role_ancestors()
//
// Eliminado: consultas a privilege_role_atom y privilege_atom (phantoms).
//
// DOC-SBOS-001 N3
// ============================================================

#![allow(dead_code)]
use crate::bitmask::{AtomPosition, RolBitMask};
use sqlx::PgPool;
use std::collections::HashMap;
use tracing::debug;

// ─── B1.T17: Serialización extendida ─────────────────────────

/// Formatos de serialización del RolBitMask soportados.
pub enum RolBitMaskFormat {
    /// Base64 URL-safe sin padding (para JWT claims).
    Base64Url,
    /// Bytes crudos (para Redis SET/GET).
    Bytes,
    /// Array de posiciones activas (para debug/logs).
    Positions,
}

/// Serializa un RolBitMask en el formato especificado.
pub fn serialize_rol(rol: &RolBitMask, format: RolBitMaskFormat) -> Vec<u8> {
    match format {
        RolBitMaskFormat::Base64Url  => rol.to_base64().into_bytes(),
        RolBitMaskFormat::Bytes      => rol.to_bytes(),
        RolBitMaskFormat::Positions  => {
            rol.active_positions()
                .flat_map(|p| p.to_le_bytes())
                .collect()
        }
    }
}

/// Deserializa un RolBitMask desde bytes + formato + total_atoms.
pub fn deserialize_rol(
    data: &[u8],
    format: RolBitMaskFormat,
    total_atoms: usize,
) -> Result<RolBitMask, String> {
    match format {
        RolBitMaskFormat::Base64Url => {
            let b64 = std::str::from_utf8(data).map_err(|e| format!("utf8: {e}"))?;
            RolBitMask::from_base64(b64, total_atoms)
        }
        RolBitMaskFormat::Bytes => Ok(RolBitMask::from_bytes(data, total_atoms)),
        RolBitMaskFormat::Positions => {
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

// ─── B1.T18: AtomPositionResolver ────────────────────────────

/// Cache inmutable de atom_slug → atom_position.
///
/// Se llena una vez al cargar el catálogo desde la BD y nunca se invalida
/// (las posiciones son inmutables por diseño del BitMask engine).
pub struct AtomPositionResolver {
    cache: HashMap<String, AtomPosition>,
}

impl AtomPositionResolver {
    /// Crea un resolver vacío.
    pub fn new() -> Self {
        AtomPositionResolver { cache: HashMap::new() }
    }

    /// Crea un resolver desde pares (slug, position).
    pub fn from_entries(entries: impl Iterator<Item = (String, AtomPosition)>) -> Self {
        AtomPositionResolver { cache: entries.collect() }
    }

    /// Registra slug → posición. Solo durante carga inicial del catálogo.
    pub fn register(&mut self, slug: &str, position: AtomPosition) {
        self.cache.insert(slug.to_string(), position);
    }

    /// Resuelve un slug a su posición. `None` si no está en el catálogo.
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

    /// Número total de átomos registrados.
    pub fn total_atoms(&self) -> usize {
        self.cache.len()
    }
}

// ─── B1.T07: ComputeRolBitMask ───────────────────────────────

/// Error al computar el RolBitMask con mensajes en español.
#[derive(Debug, thiserror::Error)]
pub enum ComputeError {
    #[error("error de base de datos: {0}")]
    Database(String),
    #[error("rol no encontrado o sin átomos asignados")]
    EmptyRole,
}

/// Computa el RolBitMask propio de un rol desde la base de datos.
///
/// Consulta `bauth.privilege_atom_grant` con el modelo G-12 5 columnas:
///   `general=TRUE` → árbol manda → evalúa `effect`
///   `general=FALSE` → grant manda → evalúa `access`
/// Cada posición activa se activa en el BitMask resultante.
///
/// Retorna máscara vacía (no error) si el rol no tiene grants activos.
pub async fn compute_rol_bitmask(
    pg: &PgPool,
    role_id: uuid::Uuid,
) -> Result<RolBitMask, ComputeError> {
    let total_atoms = crate::db::count_atoms(pg)
        .await
        .map_err(|e| ComputeError::Database(e.to_string()))? as usize;

    let positions = crate::db::load_role_atom_positions(pg, role_id)
        .await
        .map_err(|e| ComputeError::Database(e.to_string()))?;

    let u_positions: Vec<AtomPosition> = positions.iter().map(|p| *p as AtomPosition).collect();

    debug!(
        role_id = %role_id,
        atomos_activos = u_positions.len(),
        total_atoms,
        "RolBitMask computado desde privilege_atom_grant (G-12)"
    );

    Ok(RolBitMask::from_positions(&u_positions, total_atoms))
}

// ─── B1.T09: InheritFromParent ────────────────────────────────

/// Computa la máscara efectiva de un rol con herencia DAG (OR-herencia).
///
/// `mask_eff(rol) = mask_own(rol) | mask_own(ancestro_1) | ...`
///
/// Pasos:
///   1. Obtiene ancestros desde `bauth.idn_roles_rol_closure` (canónico)
///   2. Incluye el rol propio en la lista
///   3. Consulta `privilege_atom_grant` para todos con modelo G-12
///   4. Aplica OR implícito via DISTINCT en la query
pub async fn inherit_from_parents(
    pg: &PgPool,
    role_id: uuid::Uuid,
) -> Result<RolBitMask, ComputeError> {
    let ancestors = crate::db::load_role_ancestors(pg, role_id)
        .await
        .map_err(|e| ComputeError::Database(e.to_string()))?;

    let total_atoms = crate::db::count_atoms(pg)
        .await
        .map_err(|e| ComputeError::Database(e.to_string()))? as usize;

    // Combinar rol propio + todos sus ancestros
    let mut all_ids = Vec::with_capacity(ancestors.len() + 1);
    all_ids.push(role_id);
    all_ids.extend_from_slice(&ancestors);

    let positions = crate::db::load_atom_positions_for_roles(pg, &all_ids)
        .await
        .map_err(|e| ComputeError::Database(e.to_string()))?;

    let u_positions: Vec<AtomPosition> = positions.iter().map(|p| *p as AtomPosition).collect();

    debug!(
        role_id   = %role_id,
        ancestros = ancestors.len(),
        atomos    = u_positions.len(),
        total_atoms,
        "herencia DAG: OR de {} roles desde closure canónica + G-12", all_ids.len()
    );

    Ok(RolBitMask::from_positions(&u_positions, total_atoms))
}

#[cfg(test)]
mod tests {
    use super::*;

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
        resolver.register("original", 99);
        assert_eq!(resolver.resolve("original"), Some(99), "último registro gana");
    }
}
