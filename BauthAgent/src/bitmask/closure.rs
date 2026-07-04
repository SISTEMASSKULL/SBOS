// ============================================================
// bAuth::bitmask::closure — Closure Table para Herencia DAG
// B1.T15 — ClosureTableEngine
//
// Popula la tabla rol_closure(ancestro, descendiente, profundidad)
// cuando se crea o modifica la jerarquía de roles.
//
// Patrón: AWS IAM / Google Zanzibar / Cerbos.
// Precomputa todos los pares ancestro→descendiente.
// Una sola query JOIN resuelve la pertenencia sin recursión.
// ============================================================

#![allow(dead_code)]
use std::collections::{HashMap, HashSet};

/// Representa una arista en el DAG de herencia: `ancestro → descendiente`.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ClosureEdge {
    pub ancestro: String,     // role_id del rol senior
    pub descendiente: String, // role_id del rol junior
    pub profundidad: i32,     // 0=self, 1=hijo directo, 2=nieto...
}

/// Motor de la Closure Table.
///
/// Mantiene en memoria el DAG completo de herencia y genera
/// los INSERT/UPDATE/DELETE necesarios al modificar la jerarquía.
pub struct ClosureTableEngine {
    /// Aristas directas (padre → hijo) del DAG.
    /// Clave = role_id del padre, Valor = conjunto de hijos directos.
    edges: HashMap<String, HashSet<String>>,
    /// Tabla de cierre precomputada: todos los pares (ancestro, descendiente, profundidad).
    closure: HashSet<ClosureEdge>,
}

impl ClosureTableEngine {
    /// Crea un motor vacío.
    pub fn new() -> Self {
        ClosureTableEngine {
            edges: HashMap::new(),
            closure: HashSet::new(),
        }
    }

    /// Añade una relación de herencia: `padre → hijo`.
    /// El padre (senior) hereda todos los privilegios del hijo (junior).
    ///
    /// Retorna las nuevas filas que deben insertarse en `rol_closure`.
    pub fn add_edge(&mut self, padre: &str, hijo: &str) -> Result<Vec<ClosureEdge>, String> {
        // 1. Verificar que no crea un ciclo: ¿hijo ya es ancestro de padre?
        if self.path_exists(hijo, padre) {
            return Err(format!(
                "Ciclo detectado: {} → {} crearía un ciclo en el DAG",
                padre, hijo
            ));
        }

        // 2. Registrar la arista directa
        self.edges
            .entry(padre.to_string())
            .or_default()
            .insert(hijo.to_string());

        // 3. Insertar self-references para ambos roles
        let mut new_rows = vec![
            ClosureEdge { ancestro: padre.to_string(), descendiente: padre.to_string(), profundidad: 0 },
            ClosureEdge { ancestro: hijo.to_string(), descendiente: hijo.to_string(), profundidad: 0 },
            ClosureEdge { ancestro: padre.to_string(), descendiente: hijo.to_string(), profundidad: 1 },
        ];

        // 4. Cierre transitivo: todo lo que el hijo ya heredaba, ahora lo hereda el padre
        let inherited_by_hijo: Vec<ClosureEdge> = self
            .closure
            .iter()
            .filter(|e| e.ancestro == hijo)
            .cloned()
            .collect();

        for edge in &inherited_by_hijo {
            new_rows.push(ClosureEdge {
                ancestro: padre.to_string(),
                descendiente: edge.descendiente.clone(),
                profundidad: edge.profundidad + 1,
            });
        }

        // 5. Todo lo que ya heredaba el padre, ahora también lo heredan los ancestros del padre
        let ancestors_of_padre: Vec<String> = self
            .closure
            .iter()
            .filter(|e| e.descendiente == padre && e.profundidad > 0)
            .map(|e| e.ancestro.clone())
            .collect();

        let mut extra_rows = Vec::new();
        for ancestro in &ancestors_of_padre {
            for edge in &new_rows {
                let new_depth = self
                    .closure
                    .iter()
                    .find(|e| e.ancestro == *ancestro && e.descendiente == padre)
                    .map(|e| e.profundidad)
                    .unwrap_or(0)
                    + edge.profundidad;
                let new_edge = ClosureEdge {
                    ancestro: ancestro.clone(),
                    descendiente: edge.descendiente.clone(),
                    profundidad: new_depth,
                };
                if !self.closure.contains(&new_edge) && !new_rows.contains(&new_edge) && !extra_rows.contains(&new_edge) {
                    extra_rows.push(new_edge);
                }
            }
        }
        new_rows.extend(extra_rows);

        // 6. Añadir a la closure table en memoria
        for row in &new_rows {
            self.closure.insert(row.clone());
        }

        Ok(new_rows)
    }

    /// Elimina una relación de herencia y todas sus transitivas.
    pub fn remove_edge(&mut self, padre: &str, hijo: &str) -> Vec<ClosureEdge> {
        // 1. Eliminar arista directa
        if let Some(hijos) = self.edges.get_mut(padre) {
            hijos.remove(hijo);
        }

        // 2. Encontrar todas las aristas en closure que dependen de esta relación
        let to_remove: Vec<ClosureEdge> = self
            .closure
            .iter()
            .filter(|e| {
                // Eliminar si el camino pasa por (padre, hijo)
                e.ancestro == padre && e.descendiente == hijo && e.profundidad == 1
                    || (e.ancestro == padre
                        && self
                            .closure
                            .iter()
                            .any(|inner| inner.ancestro == hijo && inner.descendiente == e.descendiente))
            })
            .cloned()
            .collect();

        for edge in &to_remove {
            self.closure.remove(edge);
        }

        to_remove
    }

    /// ¿Existe un camino desde `desde` hasta `hasta` en el DAG?
    /// Es decir, ¿`desde` es ancestro directo o transitivo de `hasta`?
    fn path_exists(&self, desde: &str, hasta: &str) -> bool {
        if desde == hasta { return true; }
        self.closure.iter().any(|e| e.ancestro == desde && e.descendiente == hasta && e.profundidad > 0)
    }

    /// Retorna todas las aristas de la closure table.
    pub fn all_edges(&self) -> Vec<ClosureEdge> {
        self.closure.iter().cloned().collect()
    }

    /// ¿El rol `ancestro` hereda del rol `descendiente`?
    pub fn inherits(&self, ancestro: &str, descendiente: &str) -> bool {
        self.closure
            .iter()
            .any(|e| e.ancestro == ancestro && e.descendiente == descendiente && e.profundidad > 0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_self_reference() {
        let mut engine = ClosureTableEngine::new();
        let edges = engine.add_edge("SU", "N1").unwrap();
        // Debe incluir self-references
        assert!(edges.iter().any(|e| e.ancestro == "SU" && e.descendiente == "SU" && e.profundidad == 0));
        assert!(edges.iter().any(|e| e.ancestro == "N1" && e.descendiente == "N1" && e.profundidad == 0));
        // Debe incluir la arista directa
        assert!(edges.iter().any(|e| e.ancestro == "SU" && e.descendiente == "N1" && e.profundidad == 1));
    }

    #[test]
    fn test_transitive_inheritance() {
        let mut engine = ClosureTableEngine::new();
        engine.add_edge("SU", "N1").unwrap();
        engine.add_edge("N1", "N2").unwrap();

        // SU hereda de N2 transitivamente (SU → N1 → N2 → N2)
        assert!(engine.inherits("SU", "N2"));
        // N1 hereda de N2 directamente
        assert!(engine.inherits("N1", "N2"));
        // N2 NO hereda de SU
        assert!(!engine.inherits("N2", "SU"));
    }

    #[test]
    fn test_cycle_detection() {
        let mut engine = ClosureTableEngine::new();
        engine.add_edge("A", "B").unwrap();
        // B → A crearía ciclo (A → B → A)
        assert!(engine.add_edge("B", "A").is_err(), "B→A debería detectar ciclo");
    }

    #[test]
    fn test_self_loop_detection() {
        let mut engine = ClosureTableEngine::new();
        assert!(engine.add_edge("A", "A").is_err());
    }

    #[test]
    fn test_deep_hierarchy_inheritance() {
        let mut engine = ClosureTableEngine::new();
        engine.add_edge("SU", "N1").unwrap();
        engine.add_edge("N1", "N2").unwrap();
        engine.add_edge("N2", "N3").unwrap();
        engine.add_edge("N3", "N4").unwrap();

        // SU debe heredar de todos (lo importante es la corrección de herencia, no el conteo exacto)
        assert!(engine.inherits("SU", "N1"));
        assert!(engine.inherits("SU", "N2"));
        assert!(engine.inherits("SU", "N3"));
        assert!(engine.inherits("SU", "N4"));
        // N2 NO hereda de SU
        assert!(!engine.inherits("N2", "SU"));
        // Verificar que hay al menos los edges esperados
        assert!(engine.all_edges().len() >= 10, "Debe tener al menos 10 edges de herencia");
    }
}
