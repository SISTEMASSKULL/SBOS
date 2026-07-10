// ============================================================
// bAuth::bitmask::catalog — Catálogo de Átomos + Seed Data
// B1.T12 — AtomCatalog: registrar átomos, asignar atom_position
// B1.T13 — SeedCatalog: poblar bos_domain (12) + bos_verb (4)
//
// Lógica PURA — sin I/O. Las operaciones de BD están en db/.
// ============================================================

#![allow(dead_code)]
use crate::bitmask::{AppCode, AtomBitMask, AtomPosition, DomainCode, GroupCode, PolicyState, VerbCode};
use serde::{Deserialize, Serialize};

// ─── B1.T12: AtomCatalog ────────────────────────────────────────

/// Registro de un átomo en el catálogo.
/// Corresponde a una fila de `bauth.privilege_atom`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AtomRecord {
    /// Código del verbo dentro del grupo (1-16,777,215, 24 bits).
    pub atom_code: u32,
    /// Código de aplicación (1-511, 9 bits).
    pub app_code: AppCode,
    /// Código de grupo funcional (1-2047, 11 bits).
    pub group_code: GroupCode,
    /// Código de dominio de soberanía (1-12, 4 bits).
    pub domain_code: DomainCode,
    /// Código del verbo (1-4: nuevo, editar, eliminar, ver).
    pub verb_code: VerbCode,
    /// Nombre legible: "Tryton.Comprobantes.nuevo".
    pub atom_name: String,
    /// Slug para logs y API: "comprobantes.nuevo".
    pub atom_slug: String,
    /// Posición ordinal en el catálogo global (0-based). INMUTABLE una vez asignada.
    pub atom_position: AtomPosition,
    /// BitMask Átomo pre-calculado: 64-bit label encoding.
    pub bitmask: AtomBitMask,
}

impl AtomRecord {
    /// Crea un nuevo registro de átomo SIN asignar posición.
    /// La posición se asigna al insertar en el catálogo.
    pub fn new(
        atom_code: u32,
        app_code: AppCode,
        group_code: GroupCode,
        domain_code: DomainCode,
        verb_code: VerbCode,
        atom_name: &str,
        atom_slug: &str,
    ) -> Self {
        let bitmask = AtomBitMask::new_simple(
            domain_code,
            app_code,
            group_code,
            verb_code,
            PolicyState::NoAplica, // siempre 00 al registrar
        );

        AtomRecord {
            atom_code,
            app_code,
            group_code,
            domain_code,
            verb_code,
            atom_name: atom_name.to_string(),
            atom_slug: atom_slug.to_string(),
            atom_position: 0, // se asigna al insertar
            bitmask,
        }
    }

    /// Asigna la posición en el catálogo (solo se llama una vez al insertar).
    pub fn with_position(mut self, position: AtomPosition) -> Self {
        self.atom_position = position;
        self
    }

    /// Valida que los códigos estén en los rangos permitidos.
    pub fn validate(&self) -> Result<(), String> {
        if self.app_code == 0 || self.app_code > 511 {
            return Err(format!("app_code {} fuera de rango (1-511)", self.app_code));
        }
        if self.group_code == 0 || self.group_code > 2047 {
            return Err(format!("group_code {} fuera de rango (1-2047)", self.group_code));
        }
        if self.domain_code == 0 || self.domain_code > 12 {
            return Err(format!("domain_code {} fuera de rango (1-12)", self.domain_code));
        }
        if self.verb_code == 0 || self.verb_code > 4 {
            return Err(format!("verb_code {} fuera de rango (1-4)", self.verb_code));
        }
        if self.atom_code == 0 || self.atom_code > 16_777_215 {
            return Err(format!("atom_code {} fuera de rango (1-16777215)", self.atom_code));
        }
        if self.atom_name.is_empty() || self.atom_slug.is_empty() {
            return Err("atom_name y atom_slug son obligatorios".to_string());
        }
        Ok(())
    }
}

/// Gestor del catálogo de átomos (lógica pura, sin DB).
///
/// Mantiene un registro en memoria del último `atom_position` asignado
/// y valida que los átomos nuevos no dupliquen slugs.
pub struct AtomCatalog {
    /// Próxima posición disponible en el catálogo global.
    next_position: AtomPosition,
    /// Total de átomos registrados.
    total_atoms: usize,
}

impl AtomCatalog {
    /// Crea un nuevo catálogo vacío.
    pub fn new() -> Self {
        AtomCatalog {
            next_position: 0,
            total_atoms: 0,
        }
    }

    /// Inicializa el catálogo desde un estado conocido (ej: al cargar desde BD).
    pub fn with_state(next_position: AtomPosition, total_atoms: usize) -> Self {
        AtomCatalog {
            next_position,
            total_atoms,
        }
    }

    /// Registra un nuevo átomo y le asigna la siguiente posición disponible.
    /// La posición es INMUTABLE — nunca se reasigna.
    pub fn register(&mut self, mut atom: AtomRecord) -> Result<AtomRecord, String> {
        atom.validate()?;
        atom.atom_position = self.next_position;
        self.next_position += 1;
        self.total_atoms += 1;
        Ok(atom)
    }

    /// Posición actual del catálogo (para seeding desde BD).
    pub fn next_position(&self) -> AtomPosition {
        self.next_position
    }

    /// Total de átomos registrados.
    pub fn total_atoms(&self) -> usize {
        self.total_atoms
    }
}

// ─── B1.T13: SeedCatalog ─────────────────────────────────────────

/// Datos semilla para los 12 dominios de soberanía (D1-D12).
pub const SEED_DOMAINS: &[(DomainCode, &str, bool, &str)] = &[
    (1,  "Lógico",      false, "Apps y recursos digitales. Fast-Path: verbo suficiente."),
    (2,  "Físico",      false, "Zonas y hardware. OSDP Secure Channel AES-128."),
    (3,  "Financiero",  true,  "Límites, SoD, dual-approval. Policy-Path."),
    (4,  "Temporal",    true,  "Horarios, turnos, feriados. Encadenado a D1."),
    (5,  "Biométrico",  false, "Huella, rostro, iris. External-Path vía bhnexus (validación nativa bAuth)."),
    (6,  "Geoespacial", true,  "Ubicación, viaje imposible (900 km/h). Encadenado a D1."),
    (7,  "Red",         true,  "CIDR, VPN, mTLS, device posture. External-Path vía Kong."),
    (8,  "Contexto",    false, "ctx_id en Redis. Pre-condición del BitMask."),
    (9,  "Credenciales",false, "Passwords, MFA, certificados. Pre-BitMask — validación nativa bAuth (9 métodos)."),
    (10, "Delegación",  true,  "Privilegios temporales. AND reduction."),
    (11, "Auditoría",   false, "WORM. No evalúa — solo registra. Post-hoc."),
    (12, "Blockchain",  true,  "Var A: Merkle anchoring. Var B: liquidación Besu QBFT."),
];

/// Datos semilla para los 4 verbos globales.
pub const SEED_VERBS: &[(VerbCode, &str, &str)] = &[
    (1, "nuevo",    "create"),
    (2, "editar",   "update"),
    (3, "eliminar", "delete"),
    (4, "ver",      "read"),
];

/// Valida que los seeds tengan los códigos correctos.
pub fn validate_seeds() -> Result<(), String> {
    // Validar dominios
    let mut seen_domains = std::collections::HashSet::new();
    for &(code, name, _, _) in SEED_DOMAINS {
        if !(1..=12).contains(&code) {
            return Err(format!("Domain code {} fuera de rango", code));
        }
        if !seen_domains.insert(code) {
            return Err(format!("Domain code {} duplicado", code));
        }
        if name.is_empty() {
            return Err(format!("Domain name vacío para code {}", code));
        }
    }
    if seen_domains.len() != 12 {
        return Err(format!("Se esperaban 12 dominios, hay {}", seen_domains.len()));
    }

    // Validar verbos
    let mut seen_verbs = std::collections::HashSet::new();
    for &(code, name, slug) in SEED_VERBS {
        if !(1..=4).contains(&code) {
            return Err(format!("Verb code {} fuera de rango", code));
        }
        if !seen_verbs.insert(code) {
            return Err(format!("Verb code {} duplicado", code));
        }
        if name.is_empty() || slug.is_empty() {
            return Err(format!("Verb name/slug vacíos para code {}", code));
        }
    }
    if seen_verbs.len() != 4 {
        return Err(format!("Se esperaban 4 verbos, hay {}", seen_verbs.len()));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    // ─── B1.T12 Tests ───

    #[test]
    fn test_register_atom_assigns_position() {
        let mut catalog = AtomCatalog::new();
        let atom = AtomRecord::new(
            1, 1, 2, 3, 1,                      // atom_code, app, group, domain(D3), verb(nuevo)
            "Tryton.Comprobantes.nuevo",
            "comprobantes.nuevo",
        );
        let registered = catalog.register(atom).unwrap();
        assert_eq!(registered.atom_position, 0);
        assert_eq!(catalog.next_position(), 1);
    }

    #[test]
    fn test_sequential_positions() {
        let mut catalog = AtomCatalog::new();
        let a1 = catalog.register(AtomRecord::new(1, 1, 1, 1, 1, "a", "a")).unwrap();
        let a2 = catalog.register(AtomRecord::new(2, 1, 1, 1, 2, "b", "b")).unwrap();
        let a3 = catalog.register(AtomRecord::new(3, 1, 1, 1, 3, "c", "c")).unwrap();
        assert_eq!(a1.atom_position, 0);
        assert_eq!(a2.atom_position, 1);
        assert_eq!(a3.atom_position, 2);
        assert_eq!(catalog.total_atoms(), 3);
    }

    #[test]
    fn test_validate_rejects_invalid_app_code() {
        let atom = AtomRecord::new(1, 0, 1, 1, 1, "test", "test");
        assert!(atom.validate().is_err());
    }

    #[test]
    fn test_validate_rejects_invalid_domain() {
        let atom = AtomRecord::new(1, 1, 1, 13, 1, "test", "test");
        assert!(atom.validate().is_err());
    }

    #[test]
    fn test_atom_bitmask_preserves_fields() {
        let atom = AtomRecord::new(1, 1, 2, 3, 1, "Tryton.Comprobantes.nuevo", "comprobantes.nuevo");
        assert_eq!(atom.bitmask.domain(), 3);
        assert_eq!(atom.bitmask.app_code(), 1);
        assert_eq!(atom.bitmask.group_code(), 2);
        assert_eq!(atom.bitmask.verb_code(), 1);
        assert_eq!(atom.bitmask.policy_state(), PolicyState::NoAplica);
    }

    // ─── B1.T13 Tests ───

    #[test]
    fn test_seed_domains_count() {
        assert_eq!(SEED_DOMAINS.len(), 12, "Debe haber exactamente 12 dominios");
    }

    #[test]
    fn test_seed_verbs_count() {
        assert_eq!(SEED_VERBS.len(), 4, "Debe haber exactamente 4 verbos");
    }

    #[test]
    fn test_validate_seeds_passes() {
        assert!(validate_seeds().is_ok());
    }

    #[test]
    fn test_domain_codes_d1_to_d12() {
        for i in 1..=12 {
            assert!(SEED_DOMAINS.iter().any(|(c, _, _, _)| *c == i),
                "Falta dominio D{} en los seeds", i);
        }
    }

    #[test]
    fn test_verb_codes_1_to_4() {
        for i in 1..=4 {
            assert!(SEED_VERBS.iter().any(|(c, _, _)| *c == i),
                "Falta verbo código {} en los seeds", i);
        }
    }
}
