// ============================================================
// bauth::catalog::startup — Inicialización del Catálogo (Fase 1)
//
// Al arrancar el daemon:
//   1. Validar seeds (verbos) contra constantes y BD
//   2. Cargar AtomCatalog desde idn_roles_template (DDL v2.12.0)
//   3. Poblar AtomPositionResolver cache (path → atom_position)
//
// Fuente canónica de átomos: bauth.idn_roles_template
//   node_type = 'atom' AND atom_position IS NOT NULL
//   atom_position BIGINT UNIQUE — asignado por trigger desde secuencia
//   path TEXT UNIQUE NOT NULL — slug único del átomo
//
// Eliminado: privilege_atom (phantom), privilege_domain (phantom)
//            privilege_resource_atom como fuente de átomos
// Canónico:  idn_roles_template (átomos), privilege_verb (verbos)
//
// DOC-SBOS-001 N3 · H-04 · H-05 · H-06 · H-09
// ============================================================

#![allow(dead_code)]
use crate::bitmask::catalog::{AtomCatalog, validate_seeds};
use crate::bitmask::resolver::AtomPositionResolver;
use sqlx::PgPool;
use tracing::info;

/// Contexto del catálogo cargado en memoria al arranque.
pub struct CatalogContext {
    pub catalog:     AtomCatalog,
    pub resolver:    AtomPositionResolver,
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
        info!("H-06: seeds verificados en BD — verbos presentes en privilege_verb");

        // ── Fase 3: Cargar catálogo desde BD ─────────────────
        let (total_atoms, max_position) = Self::load_catalog_state(pg).await?;
        let catalog = AtomCatalog::with_state(max_position + 1, total_atoms);
        info!(total_atoms, next_position = max_position + 1, "H-05: AtomCatalog cargado desde BD");

        // ── Fase 4: Poblar caché operation→position ──────────
        let resolver = Self::populate_resolver(pg).await?;
        info!(entries = resolver.total_atoms(), "H-09: AtomPositionResolver poblado");

        Ok(CatalogContext { catalog, resolver, total_atoms })
    }

    /// Verifica que existan dominios activos en el árbol canónico de átomos.
    /// Fuente: `bauth.idn_roles_template` — nodos tipo 'atom' con posición asignada.
    async fn verify_domains_in_db(pg: &PgPool) -> Result<(), String> {
        let (domain_count,): (i64,) = sqlx::query_as(
            r#"
            SELECT count(DISTINCT domain_number)
            FROM bauth.idn_roles_template
            WHERE node_type     = 'atom'
              AND atom_position IS NOT NULL
              AND is_active     = TRUE
              AND domain_number IS NOT NULL
            "#,
        )
        .fetch_one(pg)
        .await
        .map_err(|e| e.to_string())?;

        if domain_count == 0 {
            return Err(
                "idn_roles_template: sin átomos activos con dominio asignado. Ejecute seeds de átomos canónicos."
                    .into(),
            );
        }
        info!(dominios_activos = domain_count, "dominios activos detectados en idn_roles_template");
        Ok(())
    }

    /// Verifica que los verbos canónicos existan en la BD.
    /// Fuente: `bauth.privilege_verb` (DDL v2.12.0, 18 verbos canónicos).
    async fn verify_verbs_in_db(pg: &PgPool) -> Result<(), String> {
        let (count,): (i64,) = sqlx::query_as(
            "SELECT count(*) FROM bauth.privilege_verb WHERE is_active = TRUE"
        )
        .fetch_one(pg)
        .await
        .map_err(|e| e.to_string())?;

        if count < 4 {
            return Err(format!(
                "BD tiene {} verbos activos, se requieren al menos 4. Ejecute seed de verbos.",
                count
            ));
        }
        Ok(())
    }

    /// Carga el estado del catálogo: total de átomos activos y posición máxima.
    ///
    /// Fuente: `bauth.idn_roles_template` — nodos tipo 'atom' con atom_position asignado
    /// (BIGINT UNIQUE asignado por trigger desde secuencia roles_atom_position_sequential).
    /// La posición máxima es `max(atom_position)`, no `count - 1`, porque la secuencia
    /// puede tener gaps si se eliminaron átomos.
    async fn load_catalog_state(pg: &PgPool) -> Result<(usize, usize), String> {
        let (count, max_pos): (i64, Option<i64>) = sqlx::query_as(
            r#"
            SELECT count(*), max(atom_position)
            FROM bauth.idn_roles_template
            WHERE node_type     = 'atom'
              AND atom_position IS NOT NULL
              AND is_active     = TRUE
            "#,
        )
        .fetch_one(pg)
        .await
        .map_err(|e| e.to_string())?;

        let total  = count as usize;
        let max_p  = max_pos.unwrap_or(0) as usize;
        Ok((total, max_p))
    }

    /// Puebla el resolver con path → atom_position (posición real del bit).
    ///
    /// `path` es el slug canónico del átomo (UNIQUE NOT NULL en T-162).
    /// `atom_position` es BIGINT asignado por trigger desde la secuencia global
    /// `roles_atom_position_sequential` — inmutable una vez asignado.
    async fn populate_resolver(pg: &PgPool) -> Result<AtomPositionResolver, String> {
        #[derive(sqlx::FromRow)]
        struct SlugRow {
            atom_slug:     String,
            atom_position: i64,
        }

        let rows: Vec<SlugRow> = sqlx::query_as(
            r#"
            SELECT
                path           AS atom_slug,
                atom_position
            FROM bauth.idn_roles_template
            WHERE node_type     = 'atom'
              AND atom_position IS NOT NULL
              AND is_active     = TRUE
            ORDER BY atom_position
            "#,
        )
        .fetch_all(pg)
        .await
        .map_err(|e| e.to_string())?;

        let mut resolver = AtomPositionResolver::new();
        for row in &rows {
            resolver.register(&row.atom_slug, row.atom_position as usize);
        }

        Ok(resolver)
    }
}
