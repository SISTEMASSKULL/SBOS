// ============================================================
// atomc · parser — Construcción del AST desde YAML validado
//
// Propósito: parsear el RawAtomLangTree del Lexer y construir
//   el AST tipado (parser/ast.rs) que alimenta la Fase 3 (Semantic).
//
// Fase 2 del pipeline (2.13 §6.1):
//   1. Convertir RawAtomLangTree → AtomLangTree (AST tipado)
//   2. Validar combining_algorithm contra catálogo de 6 algoritmos
//   3. Validar effect.decision ∈ {Permit, Deny}
//   4. Verificar condition: null explícito → warning ATOMC-W-011
//   5. Emitir ATOMC-W-012 si Policy con 1 solo Atom tiene combining_algorithm
//
// Estándar: A.46 §2 · A.46 §6 · DOC-SBOS-001 N3.
// ============================================================

pub mod ast;

use crate::diagnostics::{Diagnostic, DiagnosticBag, Level, Phase};
use crate::lexer::RawAtomLangTree;
use ast::*;

/// Convierte el árbol crudo (RawAtomLangTree) en AST tipado (AtomLangTree).
/// Emite diagnósticos por: algoritmo inválido, decisión inválida,
/// condition ausente, combining_algorithm redundante.
pub fn parse(tree: RawAtomLangTree, file: &str) -> (AtomLangTree, DiagnosticBag) {
    let mut bag = DiagnosticBag::new();

    let policy_sets: Vec<PolicySet> = tree
        .policy_sets
        .into_iter()
        .map(|rps| parse_policy_set(rps, file, &mut bag))
        .collect();

    let ast = AtomLangTree {
        atomlang_version: tree.atomlang_version,
        policy_sets,
    };

    (ast, bag)
}

fn parse_policy_set(
    raw: crate::lexer::RawPolicySet,
    file: &str,
    bag: &mut DiagnosticBag,
) -> PolicySet {
    let combining_algorithm = parse_algorithm(&raw.combining_algorithm, &raw.policy_set_id, file, bag);
    let badge = raw
        .badge
        .as_deref()
        .map(|b| parse_badge(b))
        .unwrap_or(PolicySetBadge::Generic);

    let target = raw.target.map(|t| parse_target(t));
    let children: Vec<PolicySetChild> = raw
        .children
        .into_iter()
        .map(|c| parse_child(c, file, bag))
        .collect();

    PolicySet {
        policy_set_id: raw.policy_set_id,
        badge,
        combining_algorithm,
        target,
        children,
    }
}

fn parse_child(
    raw: crate::lexer::RawPolicySetChild,
    file: &str,
    bag: &mut DiagnosticBag,
) -> PolicySetChild {
    match raw {
        crate::lexer::RawPolicySetChild::PolicySet(ps) => {
            PolicySetChild::PolicySet(Box::new(parse_policy_set(ps, file, bag)))
        }
        crate::lexer::RawPolicySetChild::Policy(p) => {
            PolicySetChild::Policy(parse_policy(p, file, bag))
        }
    }
}

fn parse_policy(
    raw: crate::lexer::RawPolicy,
    file: &str,
    bag: &mut DiagnosticBag,
) -> Policy {
    let combining_algorithm = parse_algorithm(&raw.combining_algorithm, &raw.policy_id, file, bag);

    // ATOMC-W-012: Policy con 1 solo Atom + combining_algorithm redundante
    if raw.atoms.len() == 1 {
        bag.push(Diagnostic {
            level: Level::Warning,
            code: "ATOMC-W-012".into(),
            message: format!(
                "Policy '{}' tiene 1 solo Atom — combining_algorithm es redundante",
                raw.policy_id
            ),
            file: file.into(),
            atom_id: None,
            field_path: Some("combining_algorithm".into()),
            phase: Phase::Semantic,
            norm_ref: "A.46 §2.2 G-01".into(),
        });
    }

    let application_id = raw.application_id.map(|v| match v {
        serde_yaml::Value::Null => None,
        serde_yaml::Value::Number(n) => n.as_i64().map(|i| i as i32),
        _ => None,
    }).flatten();

    let target = raw.target.map(|t| parse_target(t));
    let atoms: Vec<Atom> = raw
        .atoms
        .into_iter()
        .map(|a| parse_atom(a, file, bag))
        .collect();

    Policy {
        policy_id: raw.policy_id,
        application_id,
        combining_algorithm,
        target,
        atoms,
    }
}

fn parse_atom(
    raw: crate::lexer::RawAtom,
    file: &str,
    bag: &mut DiagnosticBag,
) -> Atom {
    // G-03: condition → validado en semantic S03 (no aquí)
    let condition = raw.condition.map(|c| parse_condition(c));

    let effect = parse_effect(raw.effect, &raw.atom_id, file, bag);
    let target = parse_target(raw.target);

    Atom {
        atom_id: raw.atom_id,
        verb_id: raw.verb_id,
        target,
        condition,
        effect,
    }
}

fn parse_target(raw: crate::lexer::RawTarget) -> Target {
    Target {
        subject: parse_subject(raw.subject),
        resource: raw.resource,
        environment: raw
            .environment
            .into_iter()
            .map(|e| AttributeRef {
                property_id: e.property_id,
                operator: parse_operator_str(&e.operator),
                value: parse_value_ref(e.value),
            })
            .collect(),
    }
}

fn parse_subject(raw: crate::lexer::RawSubject) -> Subject {
    match raw {
        crate::lexer::RawSubject::Rol { role_id } => Subject::Rol { role_id },
        crate::lexer::RawSubject::Set { set_id } => Subject::Set { set_id },
        crate::lexer::RawSubject::Any => Subject::Any,
    }
}

fn parse_condition(raw: crate::lexer::RawCondition) -> Condition {
    Condition {
        property_id: raw.property_id,
        operator: parse_operator_str(&raw.operator),
        value: parse_value_ref(raw.value),
    }
}

fn parse_effect(
    raw: crate::lexer::RawEffect,
    atom_id: &str,
    file: &str,
    bag: &mut DiagnosticBag,
) -> Effect {
    let decision = match raw.decision.as_str() {
        "Permit" => Decision::Permit,
        "Deny" => Decision::Deny,
        other => {
            bag.push(Diagnostic {
                level: Level::Error,
                code: "ATOMC-E-051".into(),
                message: format!(
                    "effect.decision = '{other}' en átomo '{atom_id}' — solo Permit o Deny"
                ),
                file: file.into(),
                atom_id: Some(atom_id.into()),
                field_path: Some("effect.decision".into()),
                phase: Phase::Semantic,
                norm_ref: "A.46 §2.2 G-07".into(),
            });
            Decision::Deny // default seguro
        }
    };

    Effect {
        decision,
        obligation: raw.obligation,
        advice: raw.advice,
    }
}

/// Convierte string de algoritmo → enum CombiningAlgorithm.
/// Si no coincide con los 6 algoritmos conocidos, emite error y usa DenyOverrides.
fn parse_algorithm(
    algo_str: &str,
    container_id: &str,
    file: &str,
    bag: &mut DiagnosticBag,
) -> CombiningAlgorithm {
    match algo_str {
        "deny_overrides" | "deny-overrides" => CombiningAlgorithm::DenyOverrides,
        "permit_overrides" | "permit-overrides" => CombiningAlgorithm::PermitOverrides,
        "first_applicable" | "first-applicable" => CombiningAlgorithm::FirstApplicable,
        "deny_unless_permit" | "deny-unless-permit" => CombiningAlgorithm::DenyUnlessPermit,
        "permit_unless_deny" | "permit-unless-deny" => CombiningAlgorithm::PermitUnlessDeny,
        "aggregate_strictest" | "aggregate-strictest" => CombiningAlgorithm::AggregateStrictest,
        other => {
            bag.push(Diagnostic {
                level: Level::Error,
                code: "ATOMC-E-014".into(),
                message: format!(
                    "combining_algorithm '{other}' en '{container_id}' no es válido — usar: deny_overrides, permit_overrides, first_applicable, deny_unless_permit, permit_unless_deny, aggregate_strictest"
                ),
                file: file.into(),
                atom_id: None,
                field_path: Some("combining_algorithm".into()),
                phase: Phase::Lexer,
                norm_ref: "A.46 §2.1".into(),
            });
            CombiningAlgorithm::DenyOverrides
        }
    }
}

fn parse_operator_str(s: &str) -> Operator {
    match s {
        "==" => Operator::Eq,
        "!=" => Operator::Neq,
        ">" => Operator::Gt,
        "<" => Operator::Lt,
        ">=" => Operator::Gte,
        "<=" => Operator::Lte,
        "IN" | "in" => Operator::In,
        "NOT_IN" | "not_in" => Operator::NotIn,
        "BETWEEN" | "between" => Operator::Between,
        _ => Operator::Eq, // será validado en fase semántica
    }
}

fn parse_value_ref(value: serde_yaml::Value) -> ValueRef {
    match value {
        serde_yaml::Value::Bool(b) => ValueRef::Literal(LiteralValue::Bool(b)),
        serde_yaml::Value::String(s) => {
            if s.starts_with('@') {
                // Referencia PIP: @bauth_config_param.clave
                let parts: Vec<&str> = s[1..].splitn(2, '.').collect();
                if parts.len() == 2 {
                    ValueRef::PipRef {
                        source: parts[0].to_string(),
                        key: parts[1].to_string(),
                    }
                } else {
                    ValueRef::Literal(LiteralValue::String_(s))
                }
            } else {
                ValueRef::Literal(LiteralValue::StringEnum(s))
            }
        }
        serde_yaml::Value::Number(n) => {
            ValueRef::Literal(LiteralValue::String_(n.to_string()))
        }
        _ => ValueRef::Literal(LiteralValue::String_("".into())),
    }
}

fn parse_badge(s: &str) -> PolicySetBadge {
    match s {
        "domain" | "dominio" => PolicySetBadge::Domain,
        "zone" | "zona" => PolicySetBadge::Zone,
        "privilege_engine" => PolicySetBadge::PrivilegeEngine,
        _ => PolicySetBadge::Generic,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::lexer;

    #[test]
    fn parse_valid_tree() {
        let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: acceso_logico
    badge: domain
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
            condition:
              property_id: test_prop
              operator: ">="
              value: "@bauth_config_param.min_value"
            effect:
              decision: Permit
"#;
        let lexed = lexer::tokenize(std::path::Path::new("test.atm.yaml"), yaml).unwrap();
        assert_eq!(lexed.diagnostics.errors(), 0);

        let (ast, bag) = parse(lexed.tree, "test.atm.yaml");
        assert_eq!(ast.policy_sets.len(), 1);
        assert_eq!(ast.policy_sets[0].badge, PolicySetBadge::Domain);
        assert_eq!(bag.errors(), 0);
    }

    #[test]
    fn reject_invalid_decision() {
        let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: test
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
              resource: test
            condition:
              property_id: test
              operator: "=="
              value: test
            effect:
              decision: Allow
"#;
        let lexed = lexer::tokenize(std::path::Path::new("test.atm.yaml"), yaml).unwrap();
        let (_ast, bag) = parse(lexed.tree, "test.atm.yaml");
        assert!(bag.errors() > 0);
        assert!(bag.iter().any(|d| d.code == "ATOMC-E-051"));
    }

    #[test]
    fn condition_ausente_no_emitido_en_parser() {
        // W-011 ahora vive en semantic S03, no en parser
        let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: test
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
              resource: test
            effect:
              decision: Permit
"#;
        let lexed = lexer::tokenize(std::path::Path::new("test.atm.yaml"), yaml).unwrap();
        let (_ast, bag) = parse(lexed.tree, "test.atm.yaml");
        // El parser NO debe emitir W-011 — eso es responsabilidad de semantic
        assert!(!bag.iter().any(|d| d.code == "ATOMC-W-011"),
            "W-011 debe ser emitido por semantic S03, no por el parser");
    }

    #[test]
    fn warn_single_atom_policy_with_algorithm() {
        let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: test
    combining_algorithm: deny_overrides
    children:
      - policy_id: single_atom_policy
        combining_algorithm: deny_overrides
        atoms:
          - atom_id: lone_atom
            verb_id: read
            target:
              subject:
                kind: ANY
              resource: test
            condition:
              property_id: test
              operator: "=="
              value: test
            effect:
              decision: Permit
"#;
        let lexed = lexer::tokenize(std::path::Path::new("test.atm.yaml"), yaml).unwrap();
        let (_ast, bag) = parse(lexed.tree, "test.atm.yaml");
        assert!(bag.iter().any(|d| d.code == "ATOMC-W-012"));
    }
}
