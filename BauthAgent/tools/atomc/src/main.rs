// ============================================================
// atomc — Compilador AtomLang v1
//
// Propósito: compilar árboles SOURCE (.atm.yaml) al formato
//   CANONICAL (.atm.json) que consume el PDP de bAuth.
//
// Pipeline de 4 fases (2.13 §6.1):
//   Fase 1 — Lexer:    tokeniza YAML, valida snake_case, versión
//   Fase 2 — Parser:   RawAtomLangTree → AST tipado (AtomLangTree)
//   Fase 3 — Semantic: staged pipeline G-01..G-10 + AP1-AP6
//   Fase 4 — Codegen:  AST → IR (.atm.json) + SHA256
//
// Comandos CLI (2.13 §6.2):
//   atomc lint     — sintaxis + estilo (sin DB, rápido)
//   atomc validate — lint + parser + semantic (sin DB = 9 stages)
//   atomc compile  — validate + codegen (genera .atm.json)
//   atomc publish  — inserta en bauth.privilege_atom_compiled (WORM)
//
// Invariante: atomc falla el build completo (exit ≠ 0) si cualquier
//   archivo contiene un error — no hay compilación parcial (2.13 §6.2).
//
// Estándar: 2.13 §6 · A.46 §4 · A.46 §6 · DOC-SBOS-001 N3.
// ============================================================

use atomc::{lexer, parser, semantic, codegen, diagnostics, publish};
use clap::{Parser, Subcommand};
use std::path::Path;

/// Compilador AtomLang v1 — SOURCE (.atm.yaml) → CANONICAL (.atm.json)
#[derive(Parser)]
#[command(name = "atomc", version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Solo sintaxis + estilo — sin conexión a base de datos
    Lint {
        /// Archivo(s) .atm.yaml a verificar
        files: Vec<String>,
    },
    /// Lint + parser + semantic (sin DB = 9 stages, con DB = 11 stages)
    Validate {
        /// Archivo(s) .atm.yaml a validar
        files: Vec<String>,
        /// Connection string de PostgreSQL (opcional — sin DB solo lint+parser+semantic)
        #[arg(long, env = "DATABASE_URL")]
        database_url: Option<String>,
    },
    /// Validate + emisión del Árbol CANONICAL (.atm.json)
    Compile {
        /// Archivo(s) .atm.yaml a compilar
        files: Vec<String>,
        /// Connection string de PostgreSQL (opcional)
        #[arg(long, env = "DATABASE_URL")]
        database_url: Option<String>,
        /// Directorio de salida para los .atm.json compilados
        #[arg(long, default_value = "./compiled")]
        out_dir: String,
    },
    /// Publicar árbol compilado en bauth.privilege_atom_compiled (WORM)
    Publish {
        /// Archivo(s) .atm.json a publicar
        files: Vec<String>,
        /// Connection string de PostgreSQL
        #[arg(long, env = "DATABASE_URL")]
        database_url: String,
        /// Usuario que publica (para auditoría)
        #[arg(long)]
        published_by: String,
    },
}

fn main() {
    tracing_subscriber::fmt::init();

    let cli = Cli::parse();

    let exit_code = match cli.command {
        Command::Lint { files } => run_lint(&files),
        Command::Validate { files, database_url: _ } => run_validate(&files),
        Command::Compile { files, database_url: _, out_dir } => run_compile(&files, &out_dir),
        Command::Publish { files, database_url, published_by } => {
            run_publish(&files, &published_by, Some(database_url.as_str()))
        }
    };

    std::process::exit(exit_code);
}

/// Ejecuta el comando `lint`: solo sintaxis y estilo, sin base de datos.
fn run_lint(files: &[String]) -> i32 {
    if files.is_empty() {
        eprintln!("atomc lint: se requiere al menos un archivo .atm.yaml");
        return 1;
    }

    let mut total_errors = 0u32;
    let mut total_warnings = 0u32;
    let mut files_ok = 0u32;
    let mut files_err = 0u32;

    for file_path in files {
        let path = Path::new(file_path);
        let yaml_str = match std::fs::read_to_string(path) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("atomc lint: no se pudo leer '{file_path}': {e}");
                files_err += 1;
                continue;
            }
        };

        match lexer::tokenize(path, &yaml_str) {
            Ok(output) => {
                let errors = output.diagnostics.errors() as u32;
                let warnings = output.diagnostics.warnings() as u32;
                if output.diagnostics.is_empty() {
                    println!("✅ {file_path}: sin problemas");
                    files_ok += 1;
                } else {
                    for d in output.diagnostics.iter() { println!("{d}"); }
                    if errors > 0 { files_err += 1; } else { files_ok += 1; }
                }
                total_errors += errors;
                total_warnings += warnings;
            }
            Err(e) => {
                eprintln!("❌ {file_path}: error de parseo — {e}");
                files_err += 1;
                total_errors += 1;
            }
        }
    }

    println!("\n📊 atomc lint: {files_ok} OK, {files_err} error(es) — {total_errors} error(es), {total_warnings} warning(s)");
    if total_errors > 0 { 1 } else { 0 }
}

/// Ejecuta el comando `validate`: lint + parser + semantic (staged pipeline).
fn run_validate(files: &[String]) -> i32 {
    if files.is_empty() {
        eprintln!("atomc validate: se requiere al menos un archivo .atm.yaml");
        return 1;
    }

    let mut total_errors = 0u32;
    let mut total_warnings = 0u32;
    let mut files_ok = 0u32;
    let mut files_err = 0u32;

    for file_path in files {
        let path = Path::new(file_path);
        let yaml_str = match std::fs::read_to_string(path) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("atomc validate: no se pudo leer '{file_path}': {e}");
                files_err += 1;
                continue;
            }
        };

        // Fase 1: Lexer
        let lexed = match lexer::tokenize(path, &yaml_str) {
            Ok(output) => output,
            Err(e) => {
                eprintln!("❌ {file_path}: error de parseo YAML — {e}");
                files_err += 1; total_errors += 1; continue;
            }
        };
        let lex_errors = lexed.diagnostics.errors() as u32;
        let lex_warnings = lexed.diagnostics.warnings() as u32;
        for d in lexed.diagnostics.iter() { println!("{d}"); }
        if lex_errors > 0 {
            files_err += 1;
            total_errors += lex_errors;
            total_warnings += lex_warnings;
            continue;
        }

        // Fase 2: Parser
        let (ast, parser_bag) = parser::parse(lexed.tree, file_path);
        let parse_errors = parser_bag.errors() as u32;
        let parse_warnings = parser_bag.warnings() as u32;
        for d in parser_bag.iter() { println!("{d}"); }
        if parse_errors > 0 {
            files_err += 1;
            total_errors += lex_errors + parse_errors;
            total_warnings += lex_warnings + parse_warnings;
            continue;
        }

        // Fase 3: Semantic
        let sem_config = semantic::SemanticConfig::default();
        let sem_output = semantic::analyze(&ast, file_path, &sem_config);
        let sem_errors = sem_output.diagnostics.errors() as u32;
        let sem_warnings = sem_output.diagnostics.warnings() as u32;
        for d in sem_output.diagnostics.iter() { println!("{d}"); }
        if sem_errors > 0 {
            files_err += 1;
            total_errors += lex_errors + parse_errors + sem_errors;
            total_warnings += lex_warnings + parse_warnings + sem_warnings;
            continue;
        }

        println!("✅ {file_path}: validado ({n} stages semánticos ejecutados)", n = sem_output.stages_run);
        files_ok += 1;
        total_errors += lex_errors + parse_errors + sem_errors;
        total_warnings += lex_warnings + parse_warnings + sem_warnings;
    }

    println!("\n📊 atomc validate: {files_ok} OK, {files_err} error(es) — {total_errors} error(es), {total_warnings} warning(s)");
    if total_errors > 0 { 1 } else { 0 }
}

/// Ejecuta el comando `compile`: pipeline completo lint→parser→semantic→codegen.
fn run_compile(files: &[String], out_dir: &str) -> i32 {
    if files.is_empty() {
        eprintln!("atomc compile: se requiere al menos un archivo .atm.yaml");
        return 1;
    }

    let mut total_errors = 0u32;
    let mut total_warnings = 0u32;
    let mut files_ok = 0u32;
    let mut files_err = 0u32;

    if let Err(e) = std::fs::create_dir_all(out_dir) {
        eprintln!("atomc compile: no se pudo crear directorio de salida '{out_dir}': {e}");
        return 1;
    }

    for file_path in files {
        let path = Path::new(file_path);
        let yaml_str = match std::fs::read_to_string(path) {
            Ok(s) => s,
            Err(e) => { eprintln!("❌ {file_path}: {e}"); files_err += 1; continue; }
        };

        // Fase 1: Lexer
        let lexed = match lexer::tokenize(path, &yaml_str) {
            Ok(o) => o,
            Err(e) => { eprintln!("❌ {file_path}: YAML inválido — {e}"); files_err += 1; continue; }
        };
        if lexed.diagnostics.errors() > 0 {
            for d in lexed.diagnostics.iter() { eprintln!("{d}"); }
            files_err += 1; continue;
        }

        // Fase 2: Parser
        let (ast, parser_bag) = parser::parse(lexed.tree, file_path);
        for d in parser_bag.iter() { eprintln!("{d}"); }
        if parser_bag.errors() > 0 {
            files_err += 1; total_errors += parser_bag.errors() as u32; continue;
        }
        total_warnings += parser_bag.warnings() as u32;

        // Fase 3: Semantic
        let sem_config = semantic::SemanticConfig::default();
        let sem_output = semantic::analyze(&ast, file_path, &sem_config);
        for d in sem_output.diagnostics.iter() { eprintln!("{d}"); }
        if sem_output.diagnostics.errors() > 0 {
            files_err += 1;
            total_errors += sem_output.diagnostics.errors() as u32;
            continue;
        }
        total_warnings += sem_output.diagnostics.warnings() as u32;

        // Fase 4: Codegen
        let cg_config = codegen::CodegenConfig {
            out_dir: out_dir.to_string(),
            resolve_ids: false,
        };
        match codegen::compile(&ast, path, &yaml_str, &cg_config) {
            Ok(output) => {
                for d in output.diagnostics.iter() { eprintln!("{d}"); }
                total_warnings += output.diagnostics.warnings() as u32;
                println!("✅ {file_path} → {}", output.json_path);
                println!("   SHA256: {}", output.ir.source_sha256);
                files_ok += 1;
            }
            Err(e) => {
                eprintln!("❌ {file_path}: error de codegen — {e}");
                files_err += 1; total_errors += 1;
            }
        }
    }

    println!("\n📊 atomc compile: {files_ok} OK, {files_err} error(es) — {total_errors} error(es), {total_warnings} warning(s)");
    println!("   Output: {out_dir}/");
    if total_errors > 0 { 1 } else { 0 }
}

/// Ejecuta el comando `publish`: valida .atm.json y lo publica (WORM).
fn run_publish(files: &[String], published_by: &str, database_url: Option<&str>) -> i32 {
    use std::path::Path;

    if files.is_empty() {
        eprintln!("atomc publish: se requiere al menos un archivo .atm.json");
        return 1;
    }

    let mut files_ok = 0u32;
    let mut files_err = 0u32;
    let mut total_atoms = 0usize;

    for file_path in files {
        let path = Path::new(file_path);

        if path.extension().map(|e| e != "json").unwrap_or(true) {
            eprintln!("⚠ {file_path}: extensión no es .json — omitido");
            files_err += 1;
            continue;
        }

        match publish::publish(path, published_by, database_url) {
            Ok(output) => {
                for d in output.diagnostics.iter() {
                    eprintln!("{d}");
                }
                if output.diagnostics.errors() > 0 {
                    files_err += 1;
                } else {
                    println!("✅ {file_path}: publicado — {} átomos en {} dominio(s)",
                        output.atoms_published, output.domains.len());
                    if output.verified_sha256 {
                        println!("   SHA256 verificado ✅");
                    }
                    total_atoms += output.atoms_published;
                    files_ok += 1;
                }
            }
            Err(e) => {
                eprintln!("❌ {file_path}: {e}");
                files_err += 1;
            }
        }
    }

    println!("\n📊 atomc publish: {files_ok} OK, {files_err} error(es) — {total_atoms} átomos publicados");
    println!("   Publicado por: {published_by}");

    if files_err > 0 { 1 } else { 0 }
}
