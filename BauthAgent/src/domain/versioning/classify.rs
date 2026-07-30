// ==================================================================
// bauth::domain::versioning::classify — Diff JSON → bump mínimo
//
// Recibe el objeto `campos_nuevos` (solo los campos que cambian)
// y determina:
//   - qué bloques semánticos afecta
//   - cuál es el tipo mínimo de bump requerido (MAJOR/MINOR/PATCH)
//   - qué referencias normativas aplican
//
// Política fail-closed: si algún campo mapeado es MAJOR pero el
// caller declara MINOR → validar_bump_declarado rechaza después.
// Los campos SIN entrada en MapaBloques se ignoran (son operacionales).
//
// NIST SP 800-53 CM-3 · 1.13 §9.2
// Sin I/O, sin DB, sin HTTP. Solo lógica pura.
// ==================================================================

#![allow(dead_code)]

use super::{blocks::MapaBloques, ChangeType, VersioningError};
use serde_json::Value;

/// Resultado de clasificar un conjunto de campos cambiados.
#[derive(Debug, Default)]
pub struct ResultadoClasificacion {
    /// Bloques semánticos que el cambio afecta (dedupados).
    pub bloques_afectados: Vec<String>,
    /// Referencias normativas de todos los campos afectados (dedupadas).
    pub standard_ref: Vec<String>,
    /// Tipo mínimo de bump que el cambio exige.
    pub bump_minimo: ChangeType,
    /// Nombres de los campos que aparecen en el mapa y cambian.
    pub campos_cambiados: Vec<String>,
}

impl Default for ChangeType {
    fn default() -> Self { ChangeType::Patch }
}

/// Clasifica el conjunto de campos cambiados según el MapaBloques.
///
/// `campos_nuevos` — JSON object con SOLO los campos que van a cambiar.
/// Campos no presentes en el mapa se ignoran (son operacionales).
///
/// Retorna error si `campos_nuevos` no es un JSON object.
pub fn clasificar(
    mapa: &MapaBloques,
    campos_nuevos: &Value,
) -> Result<ResultadoClasificacion, VersioningError> {
    let obj = campos_nuevos.as_object().ok_or_else(|| {
        VersioningError::CamposInvalidos("campos_nuevos debe ser un objeto JSON".into())
    })?;

    let mut bloques: Vec<String> = Vec::new();
    let mut normas: Vec<String> = Vec::new();
    let mut campos: Vec<String> = Vec::new();
    let mut bump = ChangeType::Patch; // mínimo asumido

    for (nombre_campo, _nuevo_valor) in obj {
        let Some(entrada) = mapa.buscar(nombre_campo) else {
            // Campo operacional/sistema — ignorar sin error
            continue;
        };

        campos.push(nombre_campo.clone());

        if !bloques.contains(&entrada.bloque) {
            bloques.push(entrada.bloque.clone());
        }
        for norma in &entrada.standard_ref {
            if !normas.contains(norma) {
                normas.push(norma.clone());
            }
        }

        // El bump mínimo es el más alto encontrado
        bump = max_change_type(bump, entrada.change_type);
    }

    Ok(ResultadoClasificacion {
        bloques_afectados: bloques,
        standard_ref: normas,
        bump_minimo: bump,
        campos_cambiados: campos,
    })
}

/// Devuelve el tipo de cambio más severo entre dos.
fn max_change_type(a: ChangeType, b: ChangeType) -> ChangeType {
    match (a, b) {
        (ChangeType::Major, _) | (_, ChangeType::Major) => ChangeType::Major,
        (ChangeType::Minor, _) | (_, ChangeType::Minor) => ChangeType::Minor,
        _ => ChangeType::Patch,
    }
}

// ── TESTS ────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::versioning::blocks::MapaBloques;
    use serde_json::json;

    fn mapa_test() -> MapaBloques {
        MapaBloques::desde_str(r#"
        [[campo]]
        nombre = "tier"
        bloque = "B4_acceso_y_privilegio"
        change_type = "MAJOR"
        standard_ref = ["NIST-AC-2"]

        [[campo]]
        nombre = "name"
        bloque = "B1_identidad"
        change_type = "PATCH"
        standard_ref = ["INCITS-359"]

        [[campo]]
        nombre = "valid_until"
        bloque = "B2_vigencia"
        change_type = "MINOR"
        standard_ref = ["NIST-AC-2-g4"]
        "#).unwrap()
    }

    #[test]
    fn solo_patch_retorna_patch() {
        let m = mapa_test();
        let campos = json!({"name": "Nuevo Nombre"});
        let r = clasificar(&m, &campos).unwrap();
        assert_eq!(r.bump_minimo, ChangeType::Patch);
        assert!(r.bloques_afectados.contains(&"B1_identidad".into()));
    }

    #[test]
    fn campo_major_eleva_a_major() {
        let m = mapa_test();
        let campos = json!({"tier": "SU", "name": "x"});
        let r = clasificar(&m, &campos).unwrap();
        assert_eq!(r.bump_minimo, ChangeType::Major);
    }

    #[test]
    fn campo_operacional_ignorado() {
        let m = mapa_test();
        let campos = json!({"updated_at": "2026-01-01", "name": "x"});
        let r = clasificar(&m, &campos).unwrap();
        // updated_at no está en el mapa → solo name influye
        assert_eq!(r.campos_cambiados, vec!["name"]);
        assert_eq!(r.bump_minimo, ChangeType::Patch);
    }

    #[test]
    fn sin_campos_mapeados_retorna_patch_vacio() {
        let m = mapa_test();
        let campos = json!({"sys_since": "now()", "change_channel": "API"});
        let r = clasificar(&m, &campos).unwrap();
        assert!(r.campos_cambiados.is_empty());
        assert_eq!(r.bump_minimo, ChangeType::Patch);
    }

    #[test]
    fn error_si_no_es_objeto() {
        let m = mapa_test();
        assert!(clasificar(&m, &json!([1, 2, 3])).is_err());
    }
}
