//! bauth::catalog — Inicialización y gestión del Catálogo de Átomos.
//!
//! Propósito: Cargar el catálogo completo desde BD al arranque del daemon.
//! Átomos del plan: H-04 (ComputeRolBitMask), H-05 (AtomCatalog CRUD),
//! H-06 (SeedCatalog), H-09 (AtomPositionResolver).
//! Dependencias: bitmask::catalog, bitmask::resolver, db::PgPool.
//! Estado actual: IMPLEMENTADO — Fase 1 completa.

pub mod startup;
