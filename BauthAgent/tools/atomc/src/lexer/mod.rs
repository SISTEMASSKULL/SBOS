// ============================================================
// atomc · lexer — Fase 1 del compilador AtomLang
//
// Propósito: tokenizar archivos .atm.yaml, validar sintaxis básica
//   y emitir diagnósticos de nivel léxico (snake_case, versión,
//   estructura YAML). La resolución contra catálogos PostgreSQL
//   ocurre en Fase 2 (Validate).
//
// Reglas léxicas (A.46 §2.1):
//   1. Todo identificador en snake_case → rechazar camelCase, espacios, mayúsculas
//   2. atomlang_version es la primera clave del archivo
//   3. condition: null explícito si no hay condición — nunca omitir
//
// Estándar: A.46 §2 · A.46 §6 · DOC-SBOS-001 N3.
// ============================================================

use crate::diagnostics::{Diagnostic, DiagnosticBag, Level, Phase};
use serde::{Deserialize, Serialize};
use std::path::Path;

/// Versión soportada del lenguaje AtomLang.
const ATOMLANG_VERSION: u32 = 1;

/// Resultado de la fase léxica: AST crudo + diagnósticos.
#[derive(Debug)]
pub struct LexerOutput {
    pub tree: RawAtomLangTree,
    pub diagnostics: DiagnosticBag,
}

/// Árbol AtomLang crudo — parseado de YAML sin resolver referencias.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawAtomLangTree {
    pub atomlang_version: u32,
    pub policy_sets: Vec<RawPolicySet>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawPolicySet {
    pub policy_set_id: String,
    #[serde(default)]
    pub badge: Option<String>,
    pub combining_algorithm: String,
    #[serde(default)]
    pub target: Option<RawTarget>,
    #[serde(default)]
    pub children: Vec<RawPolicySetChild>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum RawPolicySetChild {
    PolicySet(RawPolicySet),
    Policy(RawPolicy),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawPolicy {
    pub policy_id: String,
    #[serde(default)]
    pub application_id: Option<serde_yaml::Value>,
    pub combining_algorithm: String,
    #[serde(default)]
    pub target: Option<RawTarget>,
    #[serde(default)]
    pub atoms: Vec<RawAtom>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawAtom {
    pub atom_id: String,
    pub verb_id: String,
    pub target: RawTarget,
    #[serde(default)]
    pub condition: Option<RawCondition>,
    pub effect: RawEffect,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawTarget {
    pub subject: RawSubject,
    pub resource: String,
    #[serde(default)]
    pub environment: Vec<RawAttributeRef>,
    /// Roles excluidos explícitamente de este nodo aunque pertenezcan al SET
    /// declarado en subject. Evaluado con prioridad sobre subject.set_id.
    /// Reglas: R-D98-06 / R-D98-07 (A.47 §3.2). Validación: ATOMC-E-062 / ATOMC-W-032.
    #[serde(default)]
    pub unset: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind")]
pub enum RawSubject {
    #[serde(rename = "ROL")]
    Rol { role_id: String },
    #[serde(rename = "SET")]
    Set { set_id: String },
    #[serde(rename = "ANY")]
    Any,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawCondition {
    pub property_id: String,
    pub operator: String,
    pub value: serde_yaml::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawEffect {
    pub decision: String,
    #[serde(default)]
    pub obligation: Option<serde_yaml::Value>,
    #[serde(default)]
    pub advice: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawAttributeRef {
    pub property_id: String,
    pub operator: String,
    pub value: serde_yaml::Value,
}

/// Tokeniza un archivo .atm.yaml. No resuelve referencias (eso lo hace Fase 2).
pub fn tokenize(path: &Path, yaml_str: &str) -> Result<LexerOutput, serde_yaml::Error> {
    let mut bag = DiagnosticBag::new();
    let file = path.display().to_string();

    // Intentar parsear YAML
    let tree: RawAtomLangTree = match serde_yaml::from_str(yaml_str) {
        Ok(t) => t,
        Err(e) => {
            bag.push(Diagnostic {
                level: Level::Error,
                code: "ATOMC-E-001".into(),
                message: format!("YAML inválido: {e}"),
                file: file.clone(),
                atom_id: None,
                field_path: None,
                phase: Phase::Lexer,
                norm_ref: "A.46 §2.1".into(),
            });
            return Err(e);
        }
    };

    // Validar versión
    if tree.atomlang_version != ATOMLANG_VERSION {
        bag.push(Diagnostic {
            level: Level::Error,
            code: "ATOMC-E-012".into(),
            message: format!(
                "atomlang_version {} no soportada — versión esperada: {ATOMLANG_VERSION}",
                tree.atomlang_version
            ),
            file: file.clone(),
            atom_id: None,
            field_path: Some("atomlang_version".into()),
            phase: Phase::Lexer,
            norm_ref: "A.46 §2.1".into(),
        });
    }

    // Validar snake_case en identificadores
    validate_snake_case(&tree, &file, &mut bag);

    Ok(LexerOutput { tree, diagnostics: bag })
}

/// Verifica que todos los identificadores del árbol estén en snake_case.
fn validate_snake_case(tree: &RawAtomLangTree, file: &str, bag: &mut DiagnosticBag) {
    for ps in &tree.policy_sets {
        check_id(&ps.policy_set_id, "policy_set_id", file, bag);
        if let Some(ref t) = ps.target {
            check_target(t, file, bag);
        }
        for child in &ps.children {
            validate_child_snake_case(child, file, bag);
        }
    }
}

fn validate_child_snake_case(child: &RawPolicySetChild, file: &str, bag: &mut DiagnosticBag) {
    match child {
        RawPolicySetChild::PolicySet(ps) => {
            check_id(&ps.policy_set_id, "policy_set_id", file, bag);
            if let Some(ref t) = ps.target {
                check_target(t, file, bag);
            }
            for c in &ps.children {
                validate_child_snake_case(c, file, bag);
            }
        }
        RawPolicySetChild::Policy(p) => {
            check_id(&p.policy_id, "policy_id", file, bag);
            if let Some(ref t) = p.target {
                check_target(t, file, bag);
            }
            for atom in &p.atoms {
                check_id(&atom.atom_id, "atom_id", file, bag);
                check_id(&atom.verb_id, "verb_id", file, bag);
                check_target(&atom.target, file, bag);
                if let Some(ref c) = atom.condition {
                    check_id(&c.property_id, "condition.property_id", file, bag);
                }
            }
        }
    }
}

fn check_target(target: &RawTarget, file: &str, bag: &mut DiagnosticBag) {
    check_id(&target.resource, "target.resource", file, bag);
    for env in &target.environment {
        check_id(&env.property_id, "target.environment.property_id", file, bag);
    }
    for (i, role_ref) in target.unset.iter().enumerate() {
        check_id(role_ref, &format!("target.unset[{i}]"), file, bag);
    }
}

fn check_id(id: &str, field_path: &str, file: &str, bag: &mut DiagnosticBag) {
    if !is_snake_case(id) {
        bag.push(Diagnostic {
            level: Level::Error,
            code: "ATOMC-E-013".into(),
            message: format!(
                "identificador '{id}' no está en snake_case — solo se permiten minúsculas, números y guiones bajos"
            ),
            file: file.into(),
            atom_id: None,
            field_path: Some(field_path.into()),
            phase: Phase::Lexer,
            norm_ref: "A.46 §2.1".into(),
        });
    }
}

/// Verifica snake_case: minúsculas, dígitos, guiones bajos y puntos jerárquicos.
/// Debe empezar con letra minúscula. Cada segmento separado por `.` debe
/// ser snake_case individualmente.
fn is_snake_case(s: &str) -> bool {
    if s.is_empty() {
        return false;
    }
    // Permitir paths jerárquicos: approval.elapsed_hours, location.velocity_km_h
    for segment in s.split('.') {
        if segment.is_empty() {
            return false;
        }
        let mut chars = segment.chars();
        match chars.next() {
            Some(c) if c.is_ascii_lowercase() => {}
            _ => return false,
        }
        if !chars.all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_') {
            return false;
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn write_temp(content: &str) -> (tempfile::TempDir, std::path::PathBuf) {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("test.atm.yaml");
        std::fs::write(&path, content).unwrap();
        (dir, path)
    }

    #[test]
    fn parse_minimal_policy() {
        let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: acceso_logico
    combining_algorithm: deny_overrides
    children:
      - policy_id: test_policy
        combining_algorithm: deny_overrides
        atoms:
          - atom_id: test_atom
            verb_id: read
            target:
              subject:
                kind: ANY
              resource: cualquier_recurso
            effect:
              decision: Permit
"#;
        let (_dir, path) = write_temp(yaml);
        let result = tokenize(&path, yaml);
        assert!(result.is_ok());
        let output = result.unwrap();
        assert_eq!(output.tree.atomlang_version, 1);
        assert_eq!(output.tree.policy_sets.len(), 1);
        assert_eq!(output.diagnostics.errors(), 0);
    }

    #[test]
    fn reject_camelcase_id() {
        let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: accesoLogico
    combining_algorithm: deny_overrides
    children: []
"#;
        let (_dir, path) = write_temp(yaml);
        let result = tokenize(&path, yaml);
        assert!(result.is_ok());
        let output = result.unwrap();
        assert_eq!(output.diagnostics.errors(), 1);
    }

    #[test]
    fn reject_unsupported_version() {
        let yaml = r#"
atomlang_version: 99
policy_sets:
  - policy_set_id: test
    combining_algorithm: deny_overrides
    children: []
"#;
        let (_dir, path) = write_temp(yaml);
        let result = tokenize(&path, yaml);
        assert!(result.is_ok());
        let output = result.unwrap();
        let diags = output.diagnostics.filter_level(Level::Error);
        assert!(diags.iter().any(|d| d.code == "ATOMC-E-012"));
    }

    #[test]
    fn snake_case_valid() {
        assert!(is_snake_case("acceso_logico"));
        assert!(is_snake_case("d1_zona_ventas"));
        assert!(is_snake_case("read"));
        assert!(is_snake_case("atom_01"));
        // Property paths with dots (hierarchical)
        assert!(is_snake_case("approval.elapsed_hours"));
        assert!(is_snake_case("location.velocity_km_h"));
        assert!(is_snake_case("gps_attestation.accuracy_meters"));
        assert!(is_snake_case("connection.type"));
    }

    #[test]
    fn snake_case_invalid() {
        assert!(!is_snake_case("accesoLogico"));
        assert!(!is_snake_case("Acceso_Logico"));
        assert!(!is_snake_case("acceso lógico"));
        assert!(!is_snake_case(""));
        assert!(!is_snake_case("_leading_underscore"));
        // Segmento no-snake_case dentro de path
        assert!(!is_snake_case("approval.CamelCase"));
        assert!(!is_snake_case("location.1_invalid_start"));
    }
}
