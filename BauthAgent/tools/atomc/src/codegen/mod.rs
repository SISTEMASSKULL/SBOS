// ============================================================
// atomc · codegen — Fase 4: AST → IR (.atm.json) + SHA256
// ============================================================

use crate::diagnostics::{DiagnosticBag, Level, Phase};
use crate::parser::ast::*;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::path::Path;

// ═══════════════════════════════════════════════ IR types

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledTree {
    pub ir_version: u32,
    pub atomlang_version: u32,
    pub compiled_at: String,
    pub source_sha256: String,
    pub compilation_id: String,
    pub domains: Vec<CompiledDomain>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledDomain {
    pub domain_id: u32,
    pub domain_slug: String,
    pub badge: String,
    pub combining_algorithm: String,
    pub children: Vec<CompiledChild>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum CompiledChild {
    PolicySet(Box<CompiledPolicySet>),
    Policy(CompiledPolicy),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledPolicySet {
    pub policy_set_slug: String,
    pub badge: String,
    pub combining_algorithm: String,
    pub children: Vec<CompiledChild>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledPolicy {
    pub policy_slug: String,
    pub application_id: u32,
    pub combining_algorithm: String,
    pub atoms: Vec<CompiledAtom>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledAtom {
    pub atom_slug: String,
    pub verb_id: u32,
    pub verb_slug: String,
    pub target: CompiledTarget,
    pub condition: Option<CompiledCondition>,
    pub effect: CompiledEffect,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledTarget {
    pub subject: CompiledSubject,
    pub resource_id: u32,
    pub resource_slug: String,
    pub environment: Vec<CompiledAttributeRef>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind")]
pub enum CompiledSubject {
    #[serde(rename = "ROL")] Rol { role_id: u32, role_slug: String },
    #[serde(rename = "SET")] Set { set_id: u32, set_slug: String },
    #[serde(rename = "ANY")] Any,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledCondition {
    pub property_id: u32,
    pub property_slug: String,
    pub operator: String,
    pub value: CompiledValue,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledAttributeRef {
    pub property_id: u32,
    pub property_slug: String,
    pub operator: String,
    pub value: CompiledValue,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum CompiledValue {
    PipRef { source: String, key: String },
    Literal(CompiledLiteral),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum CompiledLiteral {
    Bool(bool),
    Integer(i64),
    Decimal(f64),
    StringEnum(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledEffect {
    pub decision: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub obligation: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub advice: Option<String>,
}

// ═══════════════════════════════════════════════ Config

#[derive(Debug, Clone)]
pub struct CodegenConfig {
    pub out_dir: String,
    pub resolve_ids: bool,
}

impl Default for CodegenConfig {
    fn default() -> Self {
        Self { out_dir: "./compiled".into(), resolve_ids: false }
    }
}

#[derive(Debug)]
pub struct CodegenOutput {
    pub ir: CompiledTree,
    pub json_path: String,
    pub sha256_path: String,
    pub diagnostics: DiagnosticBag,
}

// ═══════════════════════════════════════════════ Emitter

pub fn compile(
    ast: &AtomLangTree,
    source_path: &Path,
    source_yaml: &str,
    config: &CodegenConfig,
) -> Result<CodegenOutput, std::io::Error> {
    let mut bag = DiagnosticBag::new();
    let sf = source_path.display().to_string();

    let source_sha256 = hex::encode(Sha256::digest(source_yaml.as_bytes()));
    let compilation_id = uuid::Uuid::now_v7().to_string();
    let compiled_at = chrono::Utc::now().to_rfc3339();

    let domains: Vec<CompiledDomain> = ast.policy_sets.iter()
        .map(|ps| cvt_domain(ps, &sf, &mut bag))
        .collect();

    let ir = CompiledTree {
        ir_version: 1,
        atomlang_version: ast.atomlang_version,
        compiled_at,
        source_sha256: source_sha256.clone(),
        compilation_id,
        domains,
    };

    std::fs::create_dir_all(&config.out_dir)?;

    let stem = source_path.file_stem()
        .map(|s| s.to_string_lossy().to_string())
        .unwrap_or_else(|| "output".to_string());

    let json_path = format!("{}/{}.atm.json", config.out_dir, stem);
    let sha256_path = format!("{}/{}.atm.json.sha256", config.out_dir, stem);

    let json_str = serde_json::to_string_pretty(&ir)
        .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e.to_string()))?;

    std::fs::write(&json_path, &json_str)?;
    std::fs::write(&sha256_path, format!("{source_sha256}  {stem}.atm.yaml\n"))?;

    Ok(CodegenOutput { ir, json_path, sha256_path, diagnostics: bag })
}

// ── conversores AST → IR ──

fn cvt_domain(ps: &PolicySet, sf: &str, bag: &mut DiagnosticBag) -> CompiledDomain {
    CompiledDomain {
        domain_id: 0, domain_slug: ps.policy_set_id.clone(),
        badge: badge_s(&ps.badge), combining_algorithm: algo_s(&ps.combining_algorithm),
        children: ps.children.iter().map(|c| cvt_child(c, sf, bag)).collect(),
    }
}

fn cvt_policyset(ps: &PolicySet, sf: &str, bag: &mut DiagnosticBag) -> CompiledPolicySet {
    CompiledPolicySet {
        policy_set_slug: ps.policy_set_id.clone(),
        badge: badge_s(&ps.badge), combining_algorithm: algo_s(&ps.combining_algorithm),
        children: ps.children.iter().map(|c| cvt_child(c, sf, bag)).collect(),
    }
}

fn cvt_child(child: &PolicySetChild, sf: &str, bag: &mut DiagnosticBag) -> CompiledChild {
    match child {
        PolicySetChild::PolicySet(ps) =>
            CompiledChild::PolicySet(Box::new(cvt_policyset(ps, sf, bag))),
        PolicySetChild::Policy(p) =>
            CompiledChild::Policy(cvt_policy(p, sf, bag)),
    }
}

fn cvt_policy(p: &Policy, sf: &str, bag: &mut DiagnosticBag) -> CompiledPolicy {
    CompiledPolicy {
        policy_slug: p.policy_id.clone(),
        application_id: p.application_id.unwrap_or(0) as u32,
        combining_algorithm: algo_s(&p.combining_algorithm),
        atoms: p.atoms.iter().map(|a| cvt_atom(a, sf, bag)).collect(),
    }
}

fn cvt_atom(atom: &Atom, sf: &str, bag: &mut DiagnosticBag) -> CompiledAtom {
    CompiledAtom {
        atom_slug: atom.atom_id.clone(),
        verb_id: 0, verb_slug: atom.verb_id.clone(),
        target: cvt_target(&atom.target),
        condition: atom.condition.as_ref().map(cvt_condition),
        effect: cvt_effect(&atom.effect),
    }
}

fn cvt_target(target: &Target) -> CompiledTarget {
    CompiledTarget {
        subject: cvt_subject(&target.subject),
        resource_id: 0, resource_slug: target.resource.clone(),
        environment: target.environment.iter().map(|e| CompiledAttributeRef {
            property_id: 0, property_slug: e.property_id.clone(),
            operator: op_s(&e.operator), value: cvt_value(&e.value),
        }).collect(),
    }
}

fn cvt_subject(subject: &Subject) -> CompiledSubject {
    match subject {
        Subject::Rol { role_id } => CompiledSubject::Rol { role_id: 0, role_slug: role_id.clone() },
        Subject::Set { set_id } => CompiledSubject::Set { set_id: 0, set_slug: set_id.clone() },
        Subject::Any => CompiledSubject::Any,
    }
}

fn cvt_condition(cond: &Condition) -> CompiledCondition {
    CompiledCondition {
        property_id: 0, property_slug: cond.property_id.clone(),
        operator: op_s(&cond.operator), value: cvt_value(&cond.value),
    }
}

fn cvt_value(value: &ValueRef) -> CompiledValue {
    match value {
        ValueRef::PipRef { source, key } =>
            CompiledValue::PipRef { source: source.clone(), key: key.clone() },
        ValueRef::Literal(lit) => CompiledValue::Literal(cvt_literal(lit)),
    }
}

fn cvt_literal(lit: &LiteralValue) -> CompiledLiteral {
    let s = match lit {
        LiteralValue::Bool(b) => return CompiledLiteral::Bool(*b),
        LiteralValue::StringEnum(s) | LiteralValue::String_(s) => s.as_str(),
    };
    if let Ok(i) = s.parse::<i64>() { CompiledLiteral::Integer(i) }
    else if let Ok(f) = s.parse::<f64>() { CompiledLiteral::Decimal(f) }
    else { CompiledLiteral::StringEnum(s.to_string()) }
}

fn cvt_effect(effect: &Effect) -> CompiledEffect {
    CompiledEffect {
        decision: dec_s(&effect.decision),
        obligation: effect.obligation.as_ref()
            .and_then(|v| serde_json::to_value(v).ok()),
        advice: effect.advice.clone(),
    }
}

// ── enum → string ──

fn algo_s(a: &CombiningAlgorithm) -> String { match a {
    CombiningAlgorithm::DenyOverrides => "deny-overrides",
    CombiningAlgorithm::PermitOverrides => "permit-overrides",
    CombiningAlgorithm::FirstApplicable => "first-applicable",
    CombiningAlgorithm::DenyUnlessPermit => "deny-unless-permit",
    CombiningAlgorithm::PermitUnlessDeny => "permit-unless-deny",
    CombiningAlgorithm::AggregateStrictest => "aggregate-strictest",
}.into() }

fn badge_s(b: &PolicySetBadge) -> String { match b {
    PolicySetBadge::Domain => "domain",
    PolicySetBadge::Zone => "zone",
    PolicySetBadge::PrivilegeEngine => "privilege_engine",
    PolicySetBadge::Generic => "generic",
}.into() }

fn op_s(o: &Operator) -> String { match o {
    Operator::Eq => "==", Operator::Neq => "!=",
    Operator::Gt => ">", Operator::Lt => "<",
    Operator::Gte => ">=", Operator::Lte => "<=",
    Operator::In => "IN", Operator::NotIn => "NOT_IN",
    Operator::Between => "BETWEEN",
}.into() }

fn dec_s(d: &Decision) -> String { match d {
    Decision::Permit => "Permit", Decision::Deny => "Deny",
}.into() }

// ═══════════════════════════════════════════════ Tests

#[cfg(test)]
mod tests {
    use super::*;
    use crate::lexer;
    use crate::parser;

    fn compile_yaml(yaml: &str) -> (CompiledTree, DiagnosticBag) {
        let path = std::path::Path::new("test.atm.yaml");
        let lexed = lexer::tokenize(path, yaml).unwrap();
        let (ast, _) = parser::parse(lexed.tree, "test.atm.yaml");
        let config = CodegenConfig {
            out_dir: std::env::temp_dir().to_string_lossy().to_string(),
            resolve_ids: false,
        };
        let output = compile(&ast, path, yaml, &config).unwrap();
        (output.ir, output.diagnostics)
    }

    #[test]
    fn emit_minimal() {
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
            target: { subject: { kind: ANY }, resource: cualquier_recurso }
            condition: { property_id: test, operator: "==", value: test }
            effect: { decision: Permit }
"#;
        let (ir, bag) = compile_yaml(yaml);
        assert_eq!(bag.errors(), 0);
        assert_eq!(ir.domains.len(), 1);
        assert_eq!(ir.domains[0].combining_algorithm, "deny-overrides");
        assert_eq!(ir.source_sha256.len(), 64);
    }

    #[test]
    fn emit_nested() {
        let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: d1
    badge: domain
    combining_algorithm: deny_overrides
    children:
      - policy_set_id: zona
        badge: zone
        combining_algorithm: first_applicable
        children:
          - policy_id: p1
            combining_algorithm: deny_overrides
            atoms:
              - atom_id: a1
                verb_id: approve
                target: { subject: { kind: ROL, role_id: cajero }, resource: r1 }
                condition: { property_id: amount, operator: "<=", value: "@bauth_config_param.max" }
                effect: { decision: Permit }
"#;
        let (ir, _) = compile_yaml(yaml);
        match &ir.domains[0].children[0] {
            CompiledChild::PolicySet(ps) => {
                assert_eq!(ps.policy_set_slug, "zona");
                match &ps.children[0] {
                    CompiledChild::Policy(p) => {
                        assert_eq!(p.atoms[0].verb_slug, "approve");
                        match &p.atoms[0].condition.as_ref().unwrap().value {
                            CompiledValue::PipRef { source, key } => {
                                assert_eq!(source, "bauth_config_param");
                                assert_eq!(key, "max");
                            }
                            _ => panic!(),
                        }
                    }
                    _ => panic!(),
                }
            }
            _ => panic!(),
        }
    }

    #[test]
    fn emit_multiple_domains() {
        let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: d1
    combining_algorithm: deny_overrides
    children: []
  - policy_set_id: d3
    combining_algorithm: permit_overrides
    children: []
"#;
        let (ir, _) = compile_yaml(yaml);
        assert_eq!(ir.domains.len(), 2);
        assert_eq!(ir.domains[1].combining_algorithm, "permit-overrides");
    }

    #[test]
    fn literal_tipado_fuerte() {
        let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: test
    combining_algorithm: deny_overrides
    children:
      - policy_id: p1
        combining_algorithm: deny_overrides
        atoms:
          - atom_id: a1
            verb_id: read
            target: { subject: { kind: ANY }, resource: r1 }
            condition: { property_id: p, operator: "<=", value: "5000" }
            effect: { decision: Permit }
"#;
        let (ir, _) = compile_yaml(yaml);
        match &ir.domains[0].children[0] {
            CompiledChild::Policy(p) => match &p.atoms[0].condition.as_ref().unwrap().value {
                CompiledValue::Literal(CompiledLiteral::Integer(5000)) => {}
                other => panic!("Expected Integer(5000), got {other:?}"),
            },
            _ => panic!(),
        }
    }

    #[test]
    fn sha256_consistente() {
        let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: test
    combining_algorithm: deny_overrides
    children: []
"#;
        let (ir1, _) = compile_yaml(yaml);
        let (ir2, _) = compile_yaml(yaml);
        assert_eq!(ir1.source_sha256, ir2.source_sha256);
    }
}
