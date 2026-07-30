// ==================================================================
// bauth::domain::versioning::semver — SemVer para roles T-041
//
// Parseo y validación de versiones "X.Y.Z" (o "X.Y" → "X.Y.0").
// Bump calculado según tipo de cambio: MAJOR/MINOR/PATCH.
// Validación fail-closed: el bump declarado no puede ser menor
// que el bump mínimo derivado de la clasificación de campos.
//
// NIST SP 800-53 CM-3 · 1.13 §9.2
// Sin I/O, sin DB, sin HTTP. Solo lógica pura.
// ==================================================================

#![allow(dead_code)]

use super::{ChangeType, VersioningError};

/// Versión semántica de un rol: mayor.menor.parche
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct Semver {
    pub mayor: u32,
    pub menor: u32,
    pub parche: u32,
}

impl Semver {
    pub fn nuevo(mayor: u32, menor: u32, parche: u32) -> Self {
        Semver { mayor, menor, parche }
    }

    /// Parsea "X.Y.Z" o "X.Y" (el parche se asume 0).
    pub fn parse(s: &str) -> Result<Self, VersioningError> {
        let partes: Vec<&str> = s.trim().split('.').collect();
        if partes.len() < 2 || partes.len() > 3 {
            return Err(VersioningError::VersionInvalida(format!(
                "formato inválido: '{s}' (esperado X.Y o X.Y.Z)"
            )));
        }
        let parse_num = |p: &str| -> Result<u32, VersioningError> {
            p.parse::<u32>().map_err(|_| VersioningError::VersionInvalida(
                format!("componente no numérico: '{p}' en '{s}'")
            ))
        };
        Ok(Semver {
            mayor:  parse_num(partes[0])?,
            menor:  parse_num(partes[1])?,
            parche: if partes.len() == 3 { parse_num(partes[2])? } else { 0 },
        })
    }

    /// Formatea como "X.Y.Z".
    pub fn format(&self) -> String {
        format!("{}.{}.{}", self.mayor, self.menor, self.parche)
    }

    /// Aplica un bump y retorna la nueva versión (immutable).
    pub fn bump(&self, tipo: ChangeType) -> Semver {
        match tipo {
            ChangeType::Major => Semver::nuevo(self.mayor + 1, 0, 0),
            ChangeType::Minor => Semver::nuevo(self.mayor, self.menor + 1, 0),
            ChangeType::Patch => Semver::nuevo(self.mayor, self.menor, self.parche + 1),
        }
    }

    /// Tipo de bump entre `self` (base) y `nueva` (propuesta).
    /// Retorna None si la versión propuesta no es mayor que la base.
    pub fn tipo_bump(&self, nueva: &Semver) -> Option<ChangeType> {
        if nueva.mayor > self.mayor {
            Some(ChangeType::Major)
        } else if nueva.mayor == self.mayor && nueva.menor > self.menor {
            Some(ChangeType::Minor)
        } else if nueva == self {
            None  // sin cambio
        } else if nueva.mayor == self.mayor && nueva.menor == self.menor && nueva.parche > self.parche {
            Some(ChangeType::Patch)
        } else {
            None  // versión propuesta menor que la base
        }
    }
}

/// Valida que el bump declarado sea suficiente para el cambio clasificado.
///
/// Política fail-closed (1.13 §9.2): si los campos cambiados requieren
/// MAJOR pero el caller declara solo MINOR → RECHAZADO.
pub fn validar_bump_declarado(
    base: &Semver,
    declarada: &Semver,
    min_tipo: ChangeType,
) -> Result<(), VersioningError> {
    let tipo_actual = base.tipo_bump(declarada).ok_or_else(|| {
        VersioningError::BumpInsuficiente(
            "la versión declarada debe ser mayor que la versión actual".into(),
        )
    })?;

    let es_suficiente = match min_tipo {
        ChangeType::Major => matches!(tipo_actual, ChangeType::Major),
        ChangeType::Minor => matches!(tipo_actual, ChangeType::Major | ChangeType::Minor),
        ChangeType::Patch => true,
    };

    if !es_suficiente {
        return Err(VersioningError::BumpInsuficiente(format!(
            "campos cambiados requieren bump {min_tipo} como mínimo; \
             se declaró solo {}",
            tipo_actual.as_str()
        )));
    }
    Ok(())
}

// ── TESTS ────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_tres_partes() {
        let v = Semver::parse("2.1.3").unwrap();
        assert_eq!(v, Semver::nuevo(2, 1, 3));
    }

    #[test]
    fn parse_dos_partes_asume_parche_cero() {
        let v = Semver::parse("1.0").unwrap();
        assert_eq!(v, Semver::nuevo(1, 0, 0));
    }

    #[test]
    fn format_incluye_parche() {
        assert_eq!(Semver::nuevo(1, 2, 3).format(), "1.2.3");
    }

    #[test]
    fn bump_major_resetea_menor_y_parche() {
        let v = Semver::nuevo(1, 5, 3);
        assert_eq!(v.bump(ChangeType::Major), Semver::nuevo(2, 0, 0));
    }

    #[test]
    fn bump_minor_resetea_parche() {
        let v = Semver::nuevo(1, 5, 3);
        assert_eq!(v.bump(ChangeType::Minor), Semver::nuevo(1, 6, 0));
    }

    #[test]
    fn bump_patch_solo_incrementa_parche() {
        let v = Semver::nuevo(1, 5, 3);
        assert_eq!(v.bump(ChangeType::Patch), Semver::nuevo(1, 5, 4));
    }

    #[test]
    fn validar_bump_major_aceptado_con_major() {
        let base = Semver::nuevo(1, 0, 0);
        let nueva = Semver::nuevo(2, 0, 0);
        assert!(validar_bump_declarado(&base, &nueva, ChangeType::Major).is_ok());
    }

    #[test]
    fn validar_bump_major_rechazado_con_minor() {
        let base = Semver::nuevo(1, 0, 0);
        let nueva = Semver::nuevo(1, 1, 0);
        assert!(validar_bump_declarado(&base, &nueva, ChangeType::Major).is_err());
    }

    #[test]
    fn validar_bump_minor_aceptado_con_major() {
        let base = Semver::nuevo(1, 0, 0);
        let nueva = Semver::nuevo(2, 0, 0);
        // MAJOR siempre satisface requisito MINOR
        assert!(validar_bump_declarado(&base, &nueva, ChangeType::Minor).is_ok());
    }

    #[test]
    fn validar_bump_igual_rechazado() {
        let base = Semver::nuevo(1, 0, 0);
        assert!(validar_bump_declarado(&base, &base.clone(), ChangeType::Patch).is_err());
    }
}
