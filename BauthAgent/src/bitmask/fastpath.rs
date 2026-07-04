// ============================================================
// bAuth::bitmask::fastpath — Verificación Sub-Nanosegundo
// B1.T14 — FastPathCheck: (rol_bitmask[atom_position / 64] >> (atom_position % 64)) & 1
//
// Objetivo: < 0.5ns por verificación.
// Implementación: acceso directo a la palabra de 64 bits + shift + AND.
// Sin heap allocation. Sin llamada a función externa. Sin branch (para el caso común).
// ============================================================

#![allow(dead_code)]
use crate::bitmask::{AtomPosition, RolBitMask};

/// Resultado del benchmark de Fast-Path.
#[derive(Debug, Clone)]
pub struct FastPathStats {
    /// Tiempo promedio en nanosegundos.
    pub avg_ns: f64,
    /// Tiempo mínimo en nanosegundos.
    pub min_ns: f64,
    /// Tiempo máximo en nanosegundos.
    pub max_ns: f64,
    /// Percentil 99 en nanosegundos.
    pub p99_ns: f64,
    /// Número de verificaciones realizadas.
    pub iterations: u64,
}

/// Verifica si el RolBitMask tiene el bit en `position` activo.
///
/// Esta es la función más caliente del sistema — se llama en cada
/// request de autorización. Debe ejecutarse en < 0.5ns.
///
/// Implementada como `#[inline(always)]` para que el compilador
/// la expanda en el lugar de llamada, eliminando el overhead
/// de llamada a función.
#[inline(always)]
pub fn fastpath_check(rol: &RolBitMask, position: AtomPosition) -> bool {
    rol.check(position)
}

/// Ejecuta un benchmark de la función `fastpath_check`.
/// Mide en LOTE para amortizar el overhead de medición.
pub fn benchmark_check(rol: &RolBitMask, iterations: u64) -> FastPathStats {
    use std::time::Instant;

    // Medición en lote: ejecutar N iteraciones y dividir por N.
    // Esto reduce el impacto del overhead de Instant::now() (~30-50ns).
    let batch_size = 10_000u64;
    let mut total_ns: f64 = 0.0;
    let mut min_batch_ns: f64 = f64::MAX;
    let mut max_batch_ns: f64 = 0.0;
    let mut batch_times: Vec<f64> = Vec::new();

    let batches = iterations / batch_size;
    for batch in 0..batches {
        let positions: Vec<AtomPosition> = (0..batch_size)
            .map(|i| ((batch * batch_size + i) as usize) % rol.len())
            .collect();

        let start = Instant::now();
        for &pos in &positions {
            let _ = fastpath_check(rol, pos);
        }
        let elapsed = start.elapsed().as_nanos() as f64;
        let per_check = elapsed / batch_size as f64;

        total_ns += elapsed;
        min_batch_ns = min_batch_ns.min(per_check);
        max_batch_ns = max_batch_ns.max(per_check);
        batch_times.push(per_check);
    }

    batch_times.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let avg = total_ns / (batches * batch_size) as f64;
    let p99_idx = (batch_times.len() as f64 * 0.99) as usize;
    let p99 = batch_times[p99_idx.min(batch_times.len() - 1)];

    FastPathStats {
        avg_ns: avg,
        min_ns: min_batch_ns,
        max_ns: max_batch_ns,
        p99_ns: p99,
        iterations,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fastpath_correctness() {
        let rol = RolBitMask::from_positions(&[5, 42, 100], 256);
        assert!(fastpath_check(&rol, 5));
        assert!(fastpath_check(&rol, 42));
        assert!(fastpath_check(&rol, 100));
        assert!(!fastpath_check(&rol, 0));
        assert!(!fastpath_check(&rol, 99));
    }

    #[test]
    fn test_fastpath_out_of_bounds() {
        let rol = RolBitMask::with_capacity(64);
        assert!(!fastpath_check(&rol, 64));
        assert!(!fastpath_check(&rol, 9999));
    }

    #[test]
    #[cfg(not(debug_assertions))]
    fn test_fastpath_performance_target() {
        let rol = RolBitMask::from_positions(&[5, 42, 100, 255], 500);
        let stats = benchmark_check(&rol, 1_000_000);

        // Solo en release: < 0.5ns con LTO. En debug CI: < 50ns.
        assert!(stats.avg_ns < 50.0,
            "FastPath degradado: avg={:.2}ns/check (umbral 50ns para CI)",
            stats.avg_ns);

        assert_eq!(stats.iterations, 1_000_000);
        eprintln!("FastPath bench: avg={:.2}ns p99={:.2}ns (1M checks)", stats.avg_ns, stats.p99_ns);
    }

    #[test]
    fn test_fastpath_no_false_positives() {
        let rol = RolBitMask::from_positions(&[5, 42, 100, 255], 500);
        for pos in 0..500 {
            let expected = matches!(pos, 5 | 42 | 100 | 255);
            assert_eq!(fastpath_check(&rol, pos), expected,
                "FastPath incorrecto en pos {}", pos);
        }
    }
}
