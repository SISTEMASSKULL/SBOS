// ============================================================
// bAuth::bitmask::conflict — Conflict Matrix (SoD Estático)
// B1.T16 — ConflictMatrix
//
// Verifica Separación de Funciones ANTES de asignar átomos a un rol.
// Pares de átomos incompatibles (ej: FINANCIAL_CREATE ⟂ FINANCIAL_APPROVE).
//
// Diferencia con SoD dinámico (B17.T20):
//   SoD ESTÁTICO: no se pueden ASIGNAR ambos al mismo rol.
//   SoD DINÁMICO: asignados pero no ACTIVADOS en la misma sesión.
// ============================================================

#![allow(dead_code)]
use crate::bitmask::AtomPosition;
use std::collections::{HashMap, HashSet};

/// Severidad de un conflicto SoD.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum SodSeverity {
    Bajo = 1,
    Medio = 2,
    Alto = 3,
    Critico = 4,
}

impl SodSeverity {
    pub fn from_str(s: &str) -> Self {
        match s.to_uppercase().as_str() {
            "LOW" | "BAJO" => SodSeverity::Bajo,
            "MEDIUM" | "MEDIO" => SodSeverity::Medio,
            "HIGH" | "ALTO" => SodSeverity::Alto,
            "CRITICAL" | "CRITICO" => SodSeverity::Critico,
            _ => SodSeverity::Alto,
        }
    }

    /// ¿El conflicto bloquea la asignación?
    pub fn is_blocking(&self) -> bool {
        matches!(self, SodSeverity::Alto | SodSeverity::Critico)
    }
}

/// Un par de átomos en conflicto.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct SodConflict {
    pub atom_a: AtomPosition,
    pub atom_b: AtomPosition,
    pub severity: SodSeverity,
    pub description: String,
}

impl SodConflict {
    pub fn new(a: AtomPosition, b: AtomPosition, severity: SodSeverity, desc: &str) -> Self {
        // Normalizar: el menor primero para comparación consistente
        let (atom_a, atom_b) = if a < b { (a, b) } else { (b, a) };
        SodConflict {
            atom_a,
            atom_b,
            severity,
            description: desc.to_string(),
        }
    }
}

/// Matriz de conflictos SoD.
///
/// Contiene pares de átomos que NO pueden coexistir en el mismo rol.
/// Se consulta ANTES de asignar átomos a un rol (B1.T16)
/// y ANTES de activar roles en sesión (B17.T20).
pub struct ConflictMatrix {
    /// Pares de átomos en conflicto, indexados por átomo para búsqueda rápida.
    conflicts: HashMap<AtomPosition, Vec<SodConflict>>,
}

impl ConflictMatrix {
    pub fn new() -> Self {
        ConflictMatrix {
            conflicts: HashMap::new(),
        }
    }

    /// Registra un conflicto entre dos átomos.
    pub fn add_conflict(&mut self, a: AtomPosition, b: AtomPosition, severity: SodSeverity, desc: &str) {
        let conflict = SodConflict::new(a, b, severity, desc);
        self.conflicts.entry(a).or_default().push(conflict.clone());
        self.conflicts.entry(b).or_default().push(conflict);
    }

    /// Verifica si añadir `new_atoms` al rol que ya tiene `existing_atoms`
    /// crearía algún conflicto SoD.
    ///
    /// Retorna la lista de conflictos detectados (vacío = sin conflicto).
    pub fn check(
        &self,
        existing_atoms: &[AtomPosition],
        new_atoms: &[AtomPosition],
    ) -> Vec<SodConflict> {
        let all_atoms: HashSet<AtomPosition> = existing_atoms
            .iter()
            .chain(new_atoms.iter())
            .copied()
            .collect();

        let mut found = Vec::new();

        for &atom in &all_atoms {
            if let Some(atom_conflicts) = self.conflicts.get(&atom) {
                for conflict in atom_conflicts {
                    let other = if conflict.atom_a == atom {
                        conflict.atom_b
                    } else {
                        conflict.atom_a
                    };
                    if all_atoms.contains(&other) && atom < other {
                        // Solo reportar una vez por par
                        found.push(conflict.clone());
                    }
                }
            }
        }

        found.dedup_by(|a, b| {
            (a.atom_a == b.atom_a && a.atom_b == b.atom_b)
                || (a.atom_a == b.atom_b && a.atom_b == b.atom_a)
        });

        found
    }

    /// ¿Algún conflicto es bloqueante (ALTO o CRÍTICO)?
    pub fn has_blocking_conflict(&self, existing: &[AtomPosition], new: &[AtomPosition]) -> bool {
        self.check(existing, new)
            .iter()
            .any(|c| c.severity.is_blocking())
    }

    /// Semilla de conflictos SoD desde datos reales (SBOS_db.fin_sod_rule).
    /// 6 pares de conflicto: 5 ALTO/BLOCK + 1 MEDIO/COMPENSATE.
    /// NIST AC-5: Separation of Duties · SOX §404 · COSO Control Activities.
    pub fn seed_defaults(&mut self) {
        // Pares ALTO/BLOCK — creador no puede ser aprobador
        self.add_conflict(14, 15, SodSeverity::Alto,
            "SOX §404: crear transacciones (pos=14) y aprobarlas (pos=15) no pueden coexistir");
        self.add_conflict(15, 14, SodSeverity::Alto,
            "SOX §404: aprobar (pos=15) y crear (pos=14) — dual control forzoso");
        self.add_conflict(101, 102, SodSeverity::Alto,
            "Programar tareas (pos=101) y notificarlas (pos=102) no pueden coexistir en D8");
        self.add_conflict(201, 202, SodSeverity::Alto,
            "Cerrar período (pos=201) y reabrir (pos=202) no pueden coexistir en D4");
        self.add_conflict(401, 101, SodSeverity::Alto,
            "Programar en D8 (pos=101) y bloquear en D2 (pos=401) — separación física/lógica");
        // Par MEDIO/COMPENSATE — requiere aprobación adicional, no bloquea
        self.add_conflict(301, 302, SodSeverity::Medio,
            "Archivar (pos=301) y enviar (pos=302) requieren segunda firma en D11");
    }

    /// Carga conflictos SoD desde `privilege_verb_conflict` en la BD (DDL v2.12.0).
    /// Reemplaza `fin_sod_rule` (phantom eliminado).
    ///
    /// Estrategia: obtiene pares de verbos en conflicto STATIC_SOD/DYNAMIC_SOD,
    /// luego resuelve las `atom_position` de cada verbo vía `idn_roles_template`.
    /// Solo incluye pares donde ambos verbos tienen átomos activos con posición asignada.
    pub async fn load_from_db(pg: &sqlx::PgPool) -> Result<Self, String> {
        let mut matrix = ConflictMatrix::new();

        #[derive(sqlx::FromRow)]
        struct SodRow {
            position_a: i64,
            position_b: i64,
            conflict_type: String,
            description: Option<String>,
        }

        // JOIN con idn_roles_template para resolver verb_id → atom_position.
        // Solo pares donde ambos verbos tienen átomos activos registrados.
        let rows: Vec<SodRow> = sqlx::query_as(
            "SELECT irt_a.atom_position AS position_a,
                    irt_b.atom_position AS position_b,
                    pvc.conflict_type,
                    pvc.description
             FROM bauth.privilege_verb_conflict pvc
             JOIN bauth.idn_roles_template irt_a
               ON irt_a.verb_id = pvc.verb_a
              AND irt_a.node_type = 'atom'
              AND irt_a.is_active = TRUE
              AND irt_a.atom_position IS NOT NULL
             JOIN bauth.idn_roles_template irt_b
               ON irt_b.verb_id = pvc.verb_b
              AND irt_b.node_type = 'atom'
              AND irt_b.is_active = TRUE
              AND irt_b.atom_position IS NOT NULL
             WHERE pvc.conflict_type IN ('STATIC_SOD', 'DYNAMIC_SOD')
             ORDER BY pvc.conflict_type DESC, irt_a.atom_position"
        )
        .fetch_all(pg)
        .await
        .map_err(|e| format!("error cargando reglas SoD: {}", e))?;

        for row in &rows {
            // STATIC_SOD → CRÍTICO (siempre bloqueante, ej: crear+aprobar)
            // DYNAMIC_SOD → ALTO (bloqueante en misma sesión)
            let severity = match row.conflict_type.as_str() {
                "STATIC_SOD"  => SodSeverity::Critico,
                "DYNAMIC_SOD" => SodSeverity::Alto,
                _             => SodSeverity::Medio,
            };
            let desc = row.description.as_deref().unwrap_or(&row.conflict_type);
            matrix.add_conflict(
                row.position_a as usize,
                row.position_b as usize,
                severity,
                desc,
            );
        }

        tracing::info!(reglas = rows.len(), "ConflictMatrix cargada desde privilege_verb_conflict");
        Ok(matrix)
    }
}

// ─── B1.T08: MergeRoles con validación SoD ──────────────────

/// Resultado del merge de roles.
#[derive(Debug)]
pub struct MergeResult {
    /// Máscara fusionada (OR de todos los roles).
    pub merged_mask: crate::bitmask::RolBitMask,
    /// Conflictos SoD detectados durante el merge.
    pub sod_conflicts: Vec<SodConflict>,
    /// ¿Se bloqueó el merge por conflicto ALTO/CRÍTICO?
    pub blocked: bool,
}

/// Fusiona múltiples roles con verificación SoD previa.
///
/// # Algoritmo
/// 1. Recolecta todas las posiciones activas de cada máscara
/// 2. Verifica Conflict Matrix contra los pares de átomos
/// 3. Si hay conflicto bloqueante → retorna `blocked=true`
/// 4. Si no hay bloqueo → OR de todas las máscaras
///
/// # NIST AC-5
/// Separation of Duties enforcement: pares de átomos incompatibles
/// no pueden coexistir en la máscara fusionada.
pub fn merge_roles_with_sod(
    masks: &[&crate::bitmask::RolBitMask],
    conflict_matrix: &ConflictMatrix,
) -> MergeResult {
    // Recolectar todas las posiciones activas
    let mut all_positions: Vec<usize> = Vec::new();
    for mask in masks {
        all_positions.extend(mask.active_positions());
    }
    all_positions.sort();
    all_positions.dedup();

    // Verificar SoD
    let conflicts = conflict_matrix.check(&all_positions, &[]);
    let blocked = conflicts.iter().any(|c| c.severity.is_blocking());

    // OR de todas las máscaras
    let merged = if blocked {
        // En caso de bloqueo, devolver la primera máscara sin cambios
        masks.first().map(|m| (*m).clone()).unwrap_or_else(|| {
            crate::bitmask::RolBitMask::with_capacity(0)
        })
    } else {
        crate::bitmask::RolBitMask::merge(masks).unwrap_or_else(|| {
            crate::bitmask::RolBitMask::with_capacity(0)
        })
    };

    MergeResult { merged_mask: merged, sod_conflicts: conflicts, blocked }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_no_conflict_empty() {
        let matrix = ConflictMatrix::new();
        let result = matrix.check(&[0, 1, 2], &[3, 4]);
        assert!(result.is_empty());
    }

    #[test]
    fn test_detect_conflict() {
        let mut matrix = ConflictMatrix::new();
        matrix.add_conflict(0, 1, SodSeverity::Alto, "test conflict");

        // existing=[0], new=[1] → conflicto detectado
        let result = matrix.check(&[0], &[1]);
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].severity, SodSeverity::Alto);
    }

    #[test]
    fn test_no_duplicate_conflict_reporting() {
        let mut matrix = ConflictMatrix::new();
        matrix.add_conflict(0, 1, SodSeverity::Alto, "test");

        // existing=[0,1], new=[] → un solo conflicto, no duplicado
        let result = matrix.check(&[0, 1], &[]);
        assert_eq!(result.len(), 1);
    }

    #[test]
    fn test_blocking_vs_warning() {
        let mut matrix = ConflictMatrix::new();
        matrix.add_conflict(0, 1, SodSeverity::Alto, "blocking");
        matrix.add_conflict(2, 3, SodSeverity::Medio, "warning only");

        assert!(matrix.has_blocking_conflict(&[0], &[1])); // ALTO → blocking
        assert!(!matrix.has_blocking_conflict(&[2], &[3])); // MEDIO → no blocking
    }

    #[test]
    fn test_normalized_pair_ordering() {
        let c1 = SodConflict::new(5, 3, SodSeverity::Alto, "test");
        // Debe normalizar: atom_a=3, atom_b=5
        assert_eq!(c1.atom_a, 3);
        assert_eq!(c1.atom_b, 5);
    }
}
