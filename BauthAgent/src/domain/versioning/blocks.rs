// ==================================================================
// bauth::domain::versioning::blocks — Mapa campo→bloque T-041
//
// Carga desde TOML la tabla de clasificación de campos:
//   campo → (bloque semántico, change_type mínimo, standard_ref)
//
// La ruta del TOML se pasa explícitamente; el daemon la lee desde
// config.versioning.blocks_map_path (default /etc/bos/blocks_map.toml).
//
// Sin I/O en tiempo de request — se carga al inicio y se comparte
// como referencia inmutable (Arc<MapaBloques>).
//
// NIST SP 800-53 CM-3 · 1.09 §11.2 · 1.13 §9.2
// Sin HTTP, sin DB. Solo lógica de clasificación pura.
// ==================================================================

#![allow(dead_code)]

use super::{ChangeType, VersioningError};
use serde::Deserialize;
use std::collections::HashMap;

/// Ruta por defecto del mapa de bloques.
pub const RUTA_DEFAULT: &str = "/etc/bos/blocks_map.toml";

/// Una entrada del mapa: un campo T-041 y su clasificación.
#[derive(Debug, Clone)]
pub struct EntradaBloque {
    /// Nombre de la columna en T-041.
    pub campo: String,
    /// Bloque semántico (B1_identidad, B2_vigencia, B3_aprobacion_cambios, B4_acceso_y_privilegio, …).
    pub bloque: String,
    /// Tipo mínimo de bump que produce cambiar este campo.
    pub change_type: ChangeType,
    /// Referencias normativas relacionadas.
    pub standard_ref: Vec<String>,
}

/// Mapa campo→bloque indexado para búsqueda O(1).
pub struct MapaBloques {
    entradas: Vec<EntradaBloque>,
    indice: HashMap<String, usize>,
}

impl MapaBloques {
    /// Busca la clasificación de un campo por su nombre exacto.
    pub fn buscar(&self, campo: &str) -> Option<&EntradaBloque> {
        self.indice.get(campo).map(|&idx| &self.entradas[idx])
    }

    /// Carga el mapa desde un archivo TOML.
    pub fn desde_toml(ruta: &str) -> Result<Self, VersioningError> {
        let contenido = std::fs::read_to_string(ruta).map_err(|e| {
            VersioningError::Configuracion(format!("no se pudo leer '{ruta}': {e}"))
        })?;
        Self::desde_str(&contenido)
    }

    /// Parsea el mapa desde un string TOML (útil para tests).
    pub fn desde_str(toml_str: &str) -> Result<Self, VersioningError> {
        let raw: ConfigBloquesCruda = toml::from_str(toml_str).map_err(|e| {
            VersioningError::Configuracion(format!("TOML inválido en blocks_map: {e}"))
        })?;

        let mut entradas = Vec::with_capacity(raw.campo.len());
        let mut indice = HashMap::with_capacity(raw.campo.len());

        for (i, c) in raw.campo.into_iter().enumerate() {
            let change_type = parse_change_type(&c.change_type, &c.nombre)?;
            indice.insert(c.nombre.clone(), i);
            entradas.push(EntradaBloque {
                campo: c.nombre,
                bloque: c.bloque,
                change_type,
                standard_ref: c.standard_ref,
            });
        }

        Ok(MapaBloques { entradas, indice })
    }

    /// Total de campos registrados.
    pub fn len(&self) -> usize { self.entradas.len() }

    /// Lista todos los campos MAJOR (para validación de propuestas B03).
    pub fn campos_major(&self) -> Vec<&str> {
        self.entradas.iter()
            .filter(|e| e.change_type == ChangeType::Major)
            .map(|e| e.campo.as_str())
            .collect()
    }
}

// ── Estructuras de deserialización TOML ─────────────────────────

#[derive(Debug, Deserialize)]
struct EntradaBloqueCruda {
    nombre: String,
    bloque: String,
    change_type: String,
    standard_ref: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct ConfigBloquesCruda {
    campo: Vec<EntradaBloqueCruda>,
}

fn parse_change_type(s: &str, campo: &str) -> Result<ChangeType, VersioningError> {
    match s {
        "MAJOR" => Ok(ChangeType::Major),
        "MINOR" => Ok(ChangeType::Minor),
        "PATCH" => Ok(ChangeType::Patch),
        otro => Err(VersioningError::Configuracion(format!(
            "change_type '{otro}' inválido en campo '{campo}' (use MAJOR/MINOR/PATCH)"
        ))),
    }
}

// ── TESTS ────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn toml_minimo() -> &'static str {
        r#"
        [[campo]]
        nombre = "tier"
        bloque = "B4_acceso_y_privilegio"
        change_type = "MAJOR"
        standard_ref = ["NIST AC-2"]

        [[campo]]
        nombre = "name"
        bloque = "B1_identidad"
        change_type = "PATCH"
        standard_ref = ["INCITS-359"]
        "#
    }

    #[test]
    fn carga_desde_str() {
        let mapa = MapaBloques::desde_str(toml_minimo()).unwrap();
        assert_eq!(mapa.len(), 2);
    }

    #[test]
    fn busca_campo_existente() {
        let mapa = MapaBloques::desde_str(toml_minimo()).unwrap();
        let e = mapa.buscar("tier").unwrap();
        assert_eq!(e.change_type, ChangeType::Major);
        assert_eq!(e.bloque, "B4_acceso_y_privilegio");
    }

    #[test]
    fn busca_campo_inexistente_retorna_none() {
        let mapa = MapaBloques::desde_str(toml_minimo()).unwrap();
        assert!(mapa.buscar("columna_operacional").is_none());
    }

    #[test]
    fn change_type_invalido_falla() {
        let bad = r#"
        [[campo]]
        nombre = "x"
        bloque = "B1"
        change_type = "HOTFIX"
        standard_ref = []
        "#;
        assert!(MapaBloques::desde_str(bad).is_err());
    }
}
