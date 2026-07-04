// ============================================================
// bauth::catalog::startup — Inicialización del Catálogo (Fase 1)
//
// Al arrancar el daemon:
//   1. Validar seeds (dominios + verbos) contra constantes y BD
//   2. Cargar AtomCatalog desde BD (total átomos, next_position)
//   3. Poblar AtomPositionResolver cache (slug → position)
//
// H-04 (ComputeRolBitMask) → bitmask::resolver
// H-05 (AtomCatalog CRUD)    → bitmask::catalog
// H-06 (SeedCatalog)        → bitmask::catalog::SEED_DOMAINS/VERBS
// H-09 (AtomPositionResolver) → bitmask::resolver::AtomPositionResolver
// ============================================================

#![allow(dead_code)]
use crate::bitmask::catalog::{AtomCatalog, validate_seeds};
use crate::bitmask::resolver::AtomPositionResolver;
use sqlx::PgPool;
use tracing::info;

/// Contexto del catálogo cargado en memoria al arranque.
/// Todas las consultas de autorización usan estas estructuras.
pub struct CatalogContext {
    pub catalog: AtomCatalog,
    pub resolver: AtomPositionResolver,
    pub total_atoms: usize,
}

impl CatalogContext {
    /// Inicializa el catálogo completo desde la base de datos.
    /// Orden: validar seeds → cargar átomos → poblar caché.
    pub async fn init(pg: &PgPool) -> Result<Self, String> {
        // ── Fase 1: Validar seeds contra constantes ──────────
        validate_seeds().map_err(|e| format!("seeds inválidos en código: {}", e))?;
        info!("H-06: seeds validados — 12 dominios + 4 verbos OK");

        // ── Fase 2: Verificar seeds en BD ────────────────────
        Self::verify_domains_in_db(pg).await?;
        Self::verify_verbs_in_db(pg).await?;
        info!("H-06: seeds verificados en BD — dominios y verbos presentes");

        // ── Fase 3: Cargar catálogo desde BD ─────────────────
        let (total_atoms, max_position) = Self::load_catalog_state(pg).await?;
        let catalog = AtomCatalog::with_state(max_position + 1, total_atoms);
        info!(total_atoms, next_position = max_position + 1, "H-05: AtomCatalog cargado desde BD");

        // ── Fase 4: Poblar caché slug→position ───────────────
        let resolver = Self::populate_resolver(pg).await?;
        info!(entries = resolver.total_atoms(), "H-09: AtomPositionResolver poblado");

        Ok(CatalogContext { catalog, resolver, total_atoms })
    }

    /// Verifica que los 12 dominios existan en la BD.
    async fn verify_domains_in_db(pg: &PgPool) -> Result<(), String> {
        let row: (i64,) = sqlx::query_as(
            "SELECT count(*) FROM bauth.privilege_domain"
        ).fetch_one(pg).await.map_err(|e| e.to_string())?;

        if row.0 < 12 {
            return Err(format!("BD tiene {} dominios, se requieren 12 (D1-D12). Ejecute 019_auth_framework_complete.sql", row.0));
        }
        Ok(())
    }

    /// Verifica que los 4 verbos existan en la BD.
    async fn verify_verbs_in_db(pg: &PgPool) -> Result<(), String> {
        let row: (i64,) = sqlx::query_as(
            "SELECT count(*) FROM bauth.privilege_verb"
        ).fetch_one(pg).await.map_err(|e| e.to_string())?;

        if row.0 < 4 {
            return Err(format!("BD tiene {} verbos, se requieren 4 (nuevo,editar,eliminar,ver). Ejecute seeds.", row.0));
        }
        Ok(())
    }

    /// Carga el estado del catálogo: total de átomos y última posición.
    async fn load_catalog_state(pg: &PgPool) -> Result<(usize, usize), String> {
        let row: (i64, i32) = sqlx::query_as(
            "SELECT count(*), COALESCE(max(atom_position), -1) FROM bauth.privilege_atom"
        ).fetch_one(pg).await.map_err(|e| e.to_string())?;

        Ok((row.0 as usize, row.1 as usize))
    }

    /// Puebla el resolver con todos los slugs del catálogo.
    async fn populate_resolver(pg: &PgPool) -> Result<AtomPositionResolver, String> {
        #[derive(sqlx::FromRow)]
        struct SlugRow {
            atom_slug: String,
            atom_position: i32,
        }

        let rows: Vec<SlugRow> = sqlx::query_as(
            "SELECT atom_slug, atom_position FROM bauth.privilege_atom ORDER BY atom_position"
        ).fetch_all(pg).await.map_err(|e| e.to_string())?;

        let mut resolver = AtomPositionResolver::new();
        for row in &rows {
            resolver.register(&row.atom_slug, row.atom_position as usize);
        }

        Ok(resolver)
    }
}
