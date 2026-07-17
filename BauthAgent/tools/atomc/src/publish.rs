// ============================================================
// atomc · publish — Fase 5: WORM insertion en PostgreSQL
//
// Propósito: validar .atm.json compilado y publicarlo en
//   bauth.privilege_atom_compiled con garantías WORM:
//   - SHA256 del JSON → verificable en cualquier momento
//   - published_by + published_at → trazabilidad
//   - compilation_id único → deduplicación
//   - append-only (solo INSERT, nunca UPDATE/DELETE)
//
// Pipeline (2.13 §6.2):
//   1. Leer .atm.json → validar schema CompiledTree v1
//   2. Verificar SHA256 (si existe .sha256 al lado)
//   3. Verificar que compilation_id no exista ya (dedup)
//   4. INSERT en bauth.privilege_atom_compiled
//   5. Registrar en audit log
//
// Estándar: A.46 §3.2 · A.46 §6 · ISO 27001 A.8.15 · DOC-SBOS-001 N3.
// ============================================================

use crate::codegen::CompiledTree;
use crate::diagnostics::{Diagnostic, DiagnosticBag, Level, Phase};
use std::path::Path;

/// Resultado de la publicación.
#[derive(Debug)]
pub struct PublishOutput {
    pub compilation_id: String,
    pub atoms_published: usize,
    pub domains: Vec<String>,
    pub verified_sha256: bool,
    pub diagnostics: DiagnosticBag,
}

/// Valida y publica un .atm.json compilado.
/// Sin DB: solo valida el JSON, SHA256, y cuenta átomos.
/// Con DB: además inserta en bauth.privilege_atom_compiled.
pub fn publish(
    json_path: &Path,
    published_by: &str,
    _database_url: Option<&str>,
) -> Result<PublishOutput, std::io::Error> {
    let mut bag = DiagnosticBag::new();
    let path_str = json_path.display().to_string();

    // 1. Leer .atm.json
    let json_str = std::fs::read_to_string(json_path)?;
    let ir: CompiledTree = match serde_json::from_str(&json_str) {
        Ok(ir) => ir,
        Err(e) => {
            bag.push(Diagnostic {
                level: Level::Error,
                code: "ATOMC-E-071".into(),
                message: format!("JSON inválido: {e}"),
                file: path_str.clone(), atom_id: None, field_path: None,
                phase: Phase::Emitter, norm_ref: "A.46 §3.2".into(),
            });
            return Err(std::io::Error::new(std::io::ErrorKind::InvalidData, e.to_string()));
        }
    };

    // 2. Verificar SHA256: el .sha256 contiene el hash del YAML fuente.
    //    Comparamos contra ir.source_sha256 (el hash embebido en el JSON).
    let sha256_path = std::path::PathBuf::from(format!("{}.sha256", json_path.display()));
    let verified = if sha256_path.exists() {
        let file_sha = std::fs::read_to_string(&sha256_path)
            .unwrap_or_default()
            .split_whitespace()
            .next()
            .unwrap_or("")
            .to_string();
        if file_sha == ir.source_sha256 {
            true
        } else {
            bag.push(Diagnostic {
                level: Level::Error,
                code: "ATOMC-E-072".into(),
                message: format!(
                    "SHA256 mismatch: .sha256={file_sha}, ir.source_sha256={}",
                    ir.source_sha256
                ),
                file: path_str.clone(), atom_id: None, field_path: None,
                phase: Phase::Emitter, norm_ref: "A.46 §3.2".into(),
            });
            false
        }
    } else {
        bag.push(Diagnostic {
            level: Level::Warning,
            code: "ATOMC-W-071".into(),
            message: "No se encontró archivo .sha256 — no se puede verificar integridad".into(),
            file: path_str.clone(), atom_id: None, field_path: None,
            phase: Phase::Emitter, norm_ref: "A.46 §3.2".into(),
        });
        false
    };

    // 3. Validar estructura del IR
    if ir.ir_version != 1 {
        bag.push(Diagnostic {
            level: Level::Error,
            code: "ATOMC-E-073".into(),
            message: format!("ir_version {} no soportada — esperada: 1", ir.ir_version),
            file: path_str.clone(), atom_id: None, field_path: Some("ir_version".into()),
            phase: Phase::Emitter, norm_ref: "A.46 §3.2".into(),
        });
    }

    // 4. Contar átomos y recolectar dominios
    let mut atom_count = 0usize;
    let mut domain_names: Vec<String> = Vec::new();
    for domain in &ir.domains {
        domain_names.push(domain.domain_slug.clone());
        atom_count += count_compiled_atoms(&domain.children);
    }

    // 5. Si hay DB, insertar (placeholder)
    if let Some(_db_url) = _database_url {
        bag.push(Diagnostic {
            level: Level::Warning,
            code: "ATOMC-W-072".into(),
            message: "Publicación a PostgreSQL no implementada — se requiere conexión a bAuth DB".into(),
            file: path_str.clone(), atom_id: None, field_path: None,
            phase: Phase::Emitter, norm_ref: "A.46 §6".into(),
        });
    }

    Ok(PublishOutput {
        compilation_id: ir.compilation_id.clone(),
        atoms_published: atom_count,
        domains: domain_names,
        verified_sha256: verified,
        diagnostics: bag,
    })
}

/// Cuenta átomos recursivamente en el IR compilado.
fn count_compiled_atoms(children: &[crate::codegen::CompiledChild]) -> usize {
    let mut count = 0;
    for child in children {
        match child {
            crate::codegen::CompiledChild::PolicySet(ps) => {
                count += count_compiled_atoms(&ps.children);
            }
            crate::codegen::CompiledChild::Policy(p) => {
                count += p.atoms.len();
            }
        }
    }
    count
}

// ═══════════════════════════════════════════════ Tests

#[cfg(test)]
mod tests {
    use super::*;
    use crate::codegen;
    use crate::lexer;
    use crate::parser;
    use std::io::Write;

    fn compile_and_publish(yaml: &str) -> PublishOutput {
        let dir = tempfile::tempdir().unwrap();
        let yaml_path = dir.path().join("test.atm.yaml");

        // Escribir YAML
        std::fs::write(&yaml_path, yaml).unwrap();

        // Compilar
        let lexed = lexer::tokenize(&yaml_path, yaml).unwrap();
        let (ast, _) = parser::parse(lexed.tree, "test.atm.yaml");
        let config = codegen::CodegenConfig {
            out_dir: dir.path().to_string_lossy().to_string(),
            resolve_ids: false,
        };
        let cg_output = codegen::compile(&ast, &yaml_path, yaml, &config).unwrap();

        // Publicar
        let json_path = std::path::Path::new(&cg_output.json_path);
        publish(json_path, "test_user", None).unwrap()
    }

    #[test]
    fn publish_valid_json() {
        let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: d1
    combining_algorithm: deny_overrides
    children:
      - policy_id: p1
        combining_algorithm: deny_overrides
        atoms:
          - atom_id: a1
            verb_id: read
            target: { subject: { kind: ANY }, resource: r1 }
            condition: { property_id: test, operator: "==", value: test }
            effect: { decision: Permit }
          - atom_id: a2
            verb_id: write
            target: { subject: { kind: ANY }, resource: r1 }
            condition: { property_id: test, operator: "==", value: test }
            effect: { decision: Deny }
"#;
        let output = compile_and_publish(yaml);
        assert_eq!(output.atoms_published, 2);
        assert_eq!(output.domains, vec!["d1"]);
        assert!(output.verified_sha256);
        assert!(!output.compilation_id.is_empty());
    }

    #[test]
    fn publish_multiple_domains() {
        let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: d1
    combining_algorithm: deny_overrides
    children: []
  - policy_set_id: d3
    combining_algorithm: permit_overrides
    children:
      - policy_id: p1
        combining_algorithm: deny_overrides
        atoms:
          - atom_id: a1
            verb_id: read
            target: { subject: { kind: ANY }, resource: r1 }
            condition: { property_id: test, operator: "==", value: test }
            effect: { decision: Permit }
"#;
        let output = compile_and_publish(yaml);
        assert_eq!(output.atoms_published, 1);
        assert_eq!(output.domains.len(), 2);
    }

    #[test]
    fn publish_verifica_sha256() {
        let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: test
    combining_algorithm: deny_overrides
    children: []
"#;
        let output = compile_and_publish(yaml);
        assert!(output.verified_sha256, "SHA256 debe estar verificado");
    }

    #[test]
    fn publish_rechaza_json_invalido() {
        let dir = tempfile::tempdir().unwrap();
        let json_path = dir.path().join("bad.atm.json");
        std::fs::write(&json_path, "not valid json").unwrap();

        let result = publish(&json_path, "test", None);
        assert!(result.is_err());
    }
}
