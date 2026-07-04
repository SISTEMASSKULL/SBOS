//! bauth::domain::inheritance — Herencia DAG de roles (B1.T09).
//!
//! Computa la máscara efectiva aplicando OR transitivo sobre el RolBitMask
//! a través del DAG de jerarquía de roles. Usa `bauth.idn_role_closure`
//! (closure table) para resolución en O(1) sin recursion.
//!
//! Implementado en: `bitmask/resolver.rs::inherit_from_parents()`.
//! Dependencias: bitmask::rol, db::load_role_ancestors, db::load_atoms_for_roles.
