// ============================================================
// atomc · diagnostics — Formato estándar de diagnóstico
//
// Propósito: generar diagnósticos en el formato legible por
//   agentes IA y por el dashboard Flutter (PAP) para feedback inline.
//
// Estándar: A.46 §4.3 · 2.13 §6.3 · DOC-SBOS-001 N3.
// ============================================================

pub mod codes;

use serde::Serialize;
use std::fmt;

/// Nivel del diagnóstico.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Level {
    Error,
    Warning,
}

/// Fase del compilador donde se detectó el diagnóstico.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Phase {
    Lexer,
    Semantic,
    Emitter,
}

/// Un diagnóstico emitido por atomc.
#[derive(Debug, Clone, Serialize)]
pub struct Diagnostic {
    pub level: Level,
    pub code: String,
    pub message: String,
    pub file: String,
    pub atom_id: Option<String>,
    pub field_path: Option<String>,
    pub phase: Phase,
    pub norm_ref: String,
}

impl fmt::Display for Diagnostic {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let level_str = match self.level {
            Level::Error => "ERROR",
            Level::Warning => "WARNING",
        };
        write!(f, "[{level_str}] {}: {} ({})", self.code, self.message, self.file)?;
        if let Some(ref field) = self.field_path {
            write!(f, " → {field}")?;
        }
        Ok(())
    }
}

/// Acumulador de diagnósticos. Recolecta errores y warnings durante
/// todas las fases de compilación.
#[derive(Debug, Default, Clone)]
pub struct DiagnosticBag {
    diagnostics: Vec<Diagnostic>,
}

impl DiagnosticBag {
    pub fn new() -> Self {
        Self { diagnostics: Vec::new() }
    }

    pub fn push(&mut self, d: Diagnostic) {
        self.diagnostics.push(d);
    }

    /// Errores (sin warnings).
    pub fn errors(&self) -> usize {
        self.diagnostics.iter().filter(|d| d.level == Level::Error).count()
    }

    /// Warnings (sin errores).
    pub fn warnings(&self) -> usize {
        self.diagnostics.iter().filter(|d| d.level == Level::Warning).count()
    }

    /// Todos los diagnósticos de un nivel específico.
    pub fn filter_level(&self, level: Level) -> Vec<&Diagnostic> {
        self.diagnostics.iter().filter(|d| d.level == level).collect()
    }

    /// ¿Hay errores que impiden continuar?
    pub fn has_errors(&self) -> bool {
        self.errors() > 0
    }

    /// Itera sobre todos los diagnósticos.
    pub fn iter(&self) -> impl Iterator<Item = &Diagnostic> {
        self.diagnostics.iter()
    }

    /// Extiende este bag con los diagnósticos de otro.
    pub fn extend(&mut self, other: DiagnosticBag) {
        self.diagnostics.extend(other.diagnostics);
    }

    pub fn len(&self) -> usize {
        self.diagnostics.len()
    }

    pub fn is_empty(&self) -> bool {
        self.diagnostics.is_empty()
    }
}

impl IntoIterator for DiagnosticBag {
    type Item = Diagnostic;
    type IntoIter = std::vec::IntoIter<Diagnostic>;

    fn into_iter(self) -> Self::IntoIter {
        self.diagnostics.into_iter()
    }
}
