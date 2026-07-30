// ============================================================
// atomc · diagnostics/codes.rs — Catálogo de errores ATOMC
//
// Propósito: constructores tipados para cada código de diagnóstico
//   del compilador atomc. Cada builder garantiza code + norm_ref
//   correctos y produce un Diagnostic listo para emitir.
//
// Formato estándar del diagnóstico (A.46 §4.3):
//   { "level": "error|warning", "code": "ATOMC-E-042",
//     "message": "...", "file": "...", "atom_id": "...",
//     "field_path": "...", "phase": "semantic", "norm_ref": "..." }
//
// Catálogo completo:
//   Errores (detienen compilación):
//     ATOMC-E-001  YAML inválido (no parseable)
//     ATOMC-E-011  atomlang_version ausente
//     ATOMC-E-012  atomlang_version no soportada
//     ATOMC-E-013  identificador no snake_case
//     ATOMC-E-014  valor no registrado en catálogo Postgres
//     ATOMC-E-021  property_id duplicado (target.environment + condition)
//     ATOMC-E-031  Policy con 2+ Atoms sin combining_algorithm
//     ATOMC-E-032  Atom con application_id != null fuera de Policy
//     ATOMC-E-041  atom_id contiene dígitos de monto/moneda
//     ATOMC-E-042  literal numérico en campo AMOUNT
//     ATOMC-E-043  código de moneda literal en campo CURRENCY
//     ATOMC-E-051  effect.decision ≠ Permit/Deny
//     ATOMC-E-061  property_id resuelto pero data_type desconocido
//     ATOMC-E-062  UNSET contiene rol_ref que no existe en bauth.idn_role_template
//
//   Warnings (compilación continúa):
//     ATOMC-W-011  condition ausente (no declarado)
//     ATOMC-W-012  Policy con 1 solo Atom y combining_algorithm declarado
//     ATOMC-W-021  mismo set_id repetido en Atoms hermanos
//     ATOMC-W-031  subject.kind=ROL y el rol ya está en un Set de D98
//     ATOMC-W-032  rol en UNSET también en membresía SET → contradicción, UNSET prevalece
//
// Estándar: A.46 §4 · 2.13 §6.3 · DOC-SBOS-001 N3.
// ============================================================

use super::{Diagnostic, Level, Phase};

// ──── Constructores de error ──────────────────────────────────

#[allow(dead_code)]
pub fn yaml_invalido(file: &str, mensaje: &str) -> Diagnostic {
    Diagnostic {
        level: Level::Error,
        code: "ATOMC-E-001".into(),
        message: format!("YAML inválido: {mensaje}"),
        file: file.into(),
        atom_id: None,
        field_path: None,
        phase: Phase::Lexer,
        norm_ref: "A.46 §2.1".into(),
    }
}

#[allow(dead_code)]
pub fn version_no_soportada(file: &str, encontrada: u32, esperada: u32) -> Diagnostic {
    Diagnostic {
        level: Level::Error,
        code: "ATOMC-E-012".into(),
        message: format!(
            "atomlang_version {encontrada} no soportada — versión esperada: {esperada}"
        ),
        file: file.into(),
        atom_id: None,
        field_path: Some("atomlang_version".into()),
        phase: Phase::Lexer,
        norm_ref: "A.46 §2.1".into(),
    }
}

#[allow(dead_code)]
pub fn no_snake_case(file: &str, id: &str, field_path: &str) -> Diagnostic {
    Diagnostic {
        level: Level::Error,
        code: "ATOMC-E-013".into(),
        message: format!(
            "identificador '{id}' no está en snake_case — solo minúsculas, números y guiones bajos"
        ),
        file: file.into(),
        atom_id: None,
        field_path: Some(field_path.into()),
        phase: Phase::Lexer,
        norm_ref: "A.46 §2.1".into(),
    }
}

#[allow(dead_code)]
pub fn valor_no_catalogado(file: &str, valor: &str, catalogo: &str) -> Diagnostic {
    Diagnostic {
        level: Level::Error,
        code: "ATOMC-E-014".into(),
        message: format!("'{valor}' no existe en el catálogo {catalogo}"),
        file: file.into(),
        atom_id: None,
        field_path: None,
        phase: Phase::Lexer,
        norm_ref: "A.46 §2.1".into(),
    }
}

#[allow(dead_code)]
pub fn property_duplicado(file: &str, atom_id: &str, property_id: &str) -> Diagnostic {
    Diagnostic {
        level: Level::Error,
        code: "ATOMC-E-021".into(),
        message: format!(
            "property_id '{property_id}' aparece en target.environment y en condition del átomo '{atom_id}'"
        ),
        file: file.into(),
        atom_id: Some(atom_id.into()),
        field_path: Some("target.environment / condition".into()),
        phase: Phase::Semantic,
        norm_ref: "A.46 §2.2 G-04".into(),
    }
}

#[allow(dead_code)]
pub fn falta_combining_algorithm(file: &str, policy_id: &str) -> Diagnostic {
    Diagnostic {
        level: Level::Error,
        code: "ATOMC-E-031".into(),
        message: format!(
            "Policy '{policy_id}' tiene 2+ Atoms pero no declara combining_algorithm"
        ),
        file: file.into(),
        atom_id: None,
        field_path: Some("combining_algorithm".into()),
        phase: Phase::Semantic,
        norm_ref: "A.46 §2.2 G-01".into(),
    }
}

#[allow(dead_code)]
pub fn atom_huerfano(file: &str, atom_id: &str) -> Diagnostic {
    Diagnostic {
        level: Level::Error,
        code: "ATOMC-E-032".into(),
        message: format!(
            "Atom '{atom_id}' tiene application_id != null pero no está dentro de una Policy"
        ),
        file: file.into(),
        atom_id: Some(atom_id.into()),
        field_path: Some("application_id".into()),
        phase: Phase::Semantic,
        norm_ref: "A.46 §2.2 G-02".into(),
    }
}

#[allow(dead_code)]
pub fn atom_id_con_digitos_monetarios(file: &str, atom_id: &str) -> Diagnostic {
    Diagnostic {
        level: Level::Error,
        code: "ATOMC-E-041".into(),
        message: format!("atom_id '{atom_id}' contiene dígitos de monto o moneda"),
        file: file.into(),
        atom_id: Some(atom_id.into()),
        field_path: Some("atom_id".into()),
        phase: Phase::Semantic,
        norm_ref: "A.46 §2.2 G-10".into(),
    }
}

#[allow(dead_code)]
pub fn literal_numerico_en_amount(file: &str, atom_id: &str, field_path: &str) -> Diagnostic {
    Diagnostic {
        level: Level::Error,
        code: "ATOMC-E-042".into(),
        message: format!(
            "valor literal numérico en campo AMOUNT del átomo '{atom_id}' — usar @bauth_config_param"
        ),
        file: file.into(),
        atom_id: Some(atom_id.into()),
        field_path: Some(field_path.into()),
        phase: Phase::Semantic,
        norm_ref: "A.46 §2.2 G-08".into(),
    }
}

#[allow(dead_code)]
pub fn decision_invalida(file: &str, atom_id: &str, encontrada: &str) -> Diagnostic {
    Diagnostic {
        level: Level::Error,
        code: "ATOMC-E-051".into(),
        message: format!(
            "effect.decision = '{encontrada}' en átomo '{atom_id}' — solo Permit o Deny"
        ),
        file: file.into(),
        atom_id: Some(atom_id.into()),
        field_path: Some("effect.decision".into()),
        phase: Phase::Semantic,
        norm_ref: "A.46 §2.2 G-07".into(),
    }
}

/// ATOMC-E-062 — rol_ref dentro de UNSET no existe en bauth.idn_role_template.
/// Regla: R-D98-06 (A.47 §3.2). El compilador no puede emitir si el rol no está registrado.
#[allow(dead_code)]
pub fn unset_rol_no_registrado(file: &str, atom_id: &str, rol_ref: &str, field_path: &str) -> Diagnostic {
    Diagnostic {
        level: Level::Error,
        code: "ATOMC-E-062".into(),
        message: format!(
            "UNSET contiene '{rol_ref}' que no existe en bauth.idn_role_template"
        ),
        file: file.into(),
        atom_id: Some(atom_id.into()),
        field_path: Some(field_path.into()),
        phase: Phase::Semantic,
        norm_ref: "A.47 §3.2 R-D98-06".into(),
    }
}

// ──── Constructores de warning ────────────────────────────────

#[allow(dead_code)]
pub fn condition_ausente(file: &str, atom_id: &str) -> Diagnostic {
    Diagnostic {
        level: Level::Warning,
        code: "ATOMC-W-011".into(),
        message: format!(
            "condition no declarada en átomo '{atom_id}' — declarar 'condition: null' explícitamente"
        ),
        file: file.into(),
        atom_id: Some(atom_id.into()),
        field_path: Some("condition".into()),
        phase: Phase::Lexer,
        norm_ref: "A.46 §2.2 G-03".into(),
    }
}

#[allow(dead_code)]
pub fn combining_algorithm_redundante(file: &str, policy_id: &str) -> Diagnostic {
    Diagnostic {
        level: Level::Warning,
        code: "ATOMC-W-012".into(),
        message: format!(
            "Policy '{policy_id}' tiene 1 solo Atom — combining_algorithm es redundante"
        ),
        file: file.into(),
        atom_id: None,
        field_path: Some("combining_algorithm".into()),
        phase: Phase::Semantic,
        norm_ref: "A.46 §2.2 G-01".into(),
    }
}

/// ATOMC-W-032 — un rol aparece simultáneamente en UNSET y en la membresía del SET
/// referenciado por subject.set_id. Contradicción: UNSET prevalece sobre SET (R-D98-07).
/// La compilación continúa pero el árbol emitido excluirá al rol.
#[allow(dead_code)]
pub fn contradiccion_unset_set(file: &str, atom_id: &str, rol_ref: &str, set_id: &str) -> Diagnostic {
    Diagnostic {
        level: Level::Warning,
        code: "ATOMC-W-032".into(),
        message: format!(
            "'{rol_ref}' está en UNSET y también en la membresía del SET '{set_id}' — UNSET prevalece (R-D98-07)"
        ),
        file: file.into(),
        atom_id: Some(atom_id.into()),
        field_path: Some("target.unset".into()),
        phase: Phase::Semantic,
        norm_ref: "A.47 §3.2 R-D98-07".into(),
    }
}
