// ============================================================
// atomc · parser/ast.rs — Tipos del AST AtomLang
//
// Propósito: definir los structs Rust que representan el Árbol
//   ATOMLANG (AST intermedio) después de Fase 1 (Lexer) y antes
//   de Fase 3 (Emitter).
//
// Mapeo XACML 3.0 → tipos Rust (A.45 §2.1, A.46 §2.2):
//   PolicySet → PolicySet
//   Policy    → Policy
//   Rule      → Atom
//
// El AST es EFÍMERO: existe solo en memoria durante la compilación.
// No se persiste. El output persistente es el Árbol COMPILADO (IR).
//
// Estándar: A.46 §2 (EBNF) · A.46 §3 (JSON Schema) · DOC-SBOS-001 N3.
// ============================================================

use serde::{Deserialize, Serialize};

// ──── Árbol AtomLang (AST intermedio) ────────────────────────

/// Raíz del árbol AtomLang: uno o más PolicySets de nivel superior.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AtomLangTree {
    pub atomlang_version: u32,
    pub policy_sets: Vec<PolicySet>,
}

/// PolicySet XACML 3.0 §5.1 — contenedor de Policies o PolicySets.
/// En bAuth: Dominio (D00-D13), Zona (B6), B7 (PrivilegeEngine).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PolicySet {
    pub policy_set_id: String,
    pub badge: PolicySetBadge,
    pub combining_algorithm: CombiningAlgorithm,
    pub target: Option<Target>,
    pub children: Vec<PolicySetChild>,
}

/// Hijo de un PolicySet: puede ser otra PolicySet o una Policy.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum PolicySetChild {
    PolicySet(Box<PolicySet>),
    Policy(Policy),
}

/// Badge del PolicySet según su rol en el árbol (A.47 §2.1).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PolicySetBadge {
    /// PolicySet raíz de dominio D00-D13
    Domain,
    /// PolicySet de zona B6 (micro-segmento lógico)
    Zone,
    /// PolicySet de motor de privilegios B7
    PrivilegeEngine,
    /// PolicySet genérico (sin clasificación específica)
    Generic,
}

/// Policy XACML 3.0 §5.2 — unidad básica del PDP.
/// En bAuth: Aplicación, capa de B7.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Policy {
    pub policy_id: String,
    /// FK a bauth.privilege_application — null = Guardrail
    pub application_id: Option<i32>,
    pub combining_algorithm: CombiningAlgorithm,
    pub target: Option<Target>,
    pub atoms: Vec<Atom>,
}

/// Atom (Rule) XACML 3.0 §5.3 — unidad atómica evaluable.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Atom {
    pub atom_id: String,
    pub verb_id: String,
    pub target: Target,
    /// null explícito si no hay condición adicional (nunca omitir)
    pub condition: Option<Condition>,
    pub effect: Effect,
}

// ──── Target XACML 3.0 §5.5 ──────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Target {
    pub subject: Subject,
    pub resource: String,
    pub environment: Vec<AttributeRef>,
    /// Roles excluidos explícitamente de este nodo aunque pertenezcan al SET
    /// del subject. Prioridad sobre subject.set_id. R-D98-06/R-D98-07 (A.47 §3.2).
    #[serde(default)]
    pub unset: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind")]
pub enum Subject {
    #[serde(rename = "ROL")]
    Rol { role_id: String },
    #[serde(rename = "SET")]
    Set { set_id: String },
    #[serde(rename = "ANY")]
    Any,
}

// ──── Condition XACML 3.0 §5.6 ───────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Condition {
    pub property_id: String,
    pub operator: Operator,
    pub value: ValueRef,
}

/// Operadores de Condition (A.46 §2 EBNF, A.45 §4).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Operator {
    Eq,
    Neq,
    Gt,
    Lt,
    Gte,
    Lte,
    In,
    NotIn,
    Between,
}

/// Valor de una condición: referencia PIP o literal tipado.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum ValueRef {
    PipRef {
        source: String,   // "bauth_config_param"
        key: String,      // ej. "approval_threshold_tier1"
    },
    Literal(LiteralValue),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum LiteralValue {
    Bool(bool),
    StringEnum(String),
    String_(String),
}

/// Atributo de entorno en Target o Condition.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AttributeRef {
    pub property_id: String,
    pub operator: Operator,
    pub value: ValueRef,
}

// ──── Effect XACML 3.0 §2.6 ─────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Effect {
    pub decision: Decision,
    pub obligation: Option<serde_yaml::Value>,
    pub advice: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum Decision {
    Permit,
    Deny,
}

// ──── Combining Algorithm XACML 3.0 §7.18 ───────────────────

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum CombiningAlgorithm {
    DenyOverrides,
    PermitOverrides,
    FirstApplicable,
    DenyUnlessPermit,
    PermitUnlessDeny,
    /// Extensión bAuth — step-up concurrente (A.45 §6)
    AggregateStrictest,
}
