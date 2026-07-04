// ============================================================
// bauth::domain::health — DomainHealthMonitor (B1.T22)
//
// Monitorea latencia y errores por dominio durante la evaluación.
// Sin dependencias externas — almacenamiento en memoria con
// resumen consultable vía JSON-RPC health check.
//
// Umbrales de alerta (NIST SP 800-53 CP-2, ISO 27001 A.8.15):
//   Fast-Path  (D1,D2):     P99 > 1ms  → WARN
//   Policy-Path (D3,D4,D10): P99 > 50ms → WARN
//   External-Path (D5-D9):   P99 > 100ms → WARN
//   Error rate > 1% en cualquier dominio → WARN
// ============================================================

#![allow(dead_code)]
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Duration;

/// Métricas acumuladas para un dominio.
#[derive(Debug, Clone, Default)]
struct DomainMetrics {
    /// Total de evaluaciones.
    total: u64,
    /// Evaluaciones con error.
    errors: u64,
    /// Latencia acumulada en nanosegundos.
    total_latency_ns: u64,
    /// Latencia máxima registrada (para P99 aproximado).
    max_latency_ns: u64,
    /// Última latencia registrada.
    last_latency_ns: u64,
}

impl DomainMetrics {
    fn record(&mut self, latency: Duration, is_error: bool) {
        let ns = latency.as_nanos() as u64;
        self.total += 1;
        self.total_latency_ns += ns;
        self.last_latency_ns = ns;
        if ns > self.max_latency_ns {
            self.max_latency_ns = ns;
        }
        if is_error {
            self.errors += 1;
        }
    }

    fn avg_ms(&self) -> f64 {
        if self.total == 0 { return 0.0; }
        (self.total_latency_ns as f64 / self.total as f64) / 1_000_000.0
    }

    fn error_rate(&self) -> f64 {
        if self.total == 0 { return 0.0; }
        self.errors as f64 / self.total as f64
    }

    fn max_ms(&self) -> f64 {
        self.max_latency_ns as f64 / 1_000_000.0
    }
}

/// Resumen de salud de un dominio.
#[derive(Debug, Clone, serde::Serialize)]
pub struct DomainHealth {
    pub domain_code: i16,
    pub domain_name: String,
    pub total_evaluations: u64,
    pub errors: u64,
    pub avg_latency_ms: f64,
    pub max_latency_ms: f64,
    pub last_latency_ms: f64,
    pub error_rate_pct: f64,
    pub status: HealthStatus,
}

#[derive(Debug, Clone, PartialEq, serde::Serialize)]
#[serde(rename_all = "snake_case")]
pub enum HealthStatus {
    Healthy,
    Degraded,
    Unhealthy,
}

/// Monitor de salud de dominios — thread-safe, sin I/O.
///
/// Cada dominio registra sus métricas después de cada evaluación.
/// El resumen se consulta vía `health_summary()` para exponer
/// en el endpoint JSON-RPC `bauth.health.check`.
pub struct DomainHealthMonitor {
    metrics: Mutex<HashMap<i16, DomainMetrics>>,
    domain_names: HashMap<i16, String>,
}

impl DomainHealthMonitor {
    /// Crea un monitor con los 12 dominios registrados.
    pub fn new() -> Self {
        let domain_names: HashMap<i16, String> = [
            (1, "Lógico"), (2, "Físico"), (3, "Financiero"),
            (4, "Temporal"), (5, "Biométrico"), (6, "Geoespacial"),
            (7, "Red"), (8, "Contexto"), (9, "Credenciales"),
            (10, "Delegación"), (11, "Auditoría"), (12, "Blockchain"),
        ].iter().map(|(k, v)| (*k, v.to_string())).collect();

        let mut metrics = HashMap::new();
        for code in 1..=12i16 {
            metrics.insert(code, DomainMetrics::default());
        }

        Self { metrics: Mutex::new(metrics), domain_names }
    }

    /// Registra una evaluación de dominio.
    pub fn record(&self, domain_code: i16, latency: Duration, is_error: bool) {
        if let Ok(mut guard) = self.metrics.lock() {
            if let Some(m) = guard.get_mut(&domain_code) {
                m.record(latency, is_error);
            }
        }
    }

    /// Retorna el resumen de salud de todos los dominios.
    pub fn health_summary(&self) -> Vec<DomainHealth> {
        let guard = match self.metrics.lock() {
            Ok(g) => g,
            Err(_) => return Vec::new(),
        };

        let mut result: Vec<DomainHealth> = guard.iter().map(|(code, m)| {
            let status = self.determine_status(*code, m);
            DomainHealth {
                domain_code: *code,
                domain_name: self.domain_names.get(code).cloned().unwrap_or_default(),
                total_evaluations: m.total,
                errors: m.errors,
                avg_latency_ms: m.avg_ms(),
                max_latency_ms: m.max_ms(),
                last_latency_ms: m.last_latency_ns as f64 / 1_000_000.0,
                error_rate_pct: m.error_rate() * 100.0,
                status,
            }
        }).collect();

        result.sort_by_key(|d| d.domain_code);
        result
    }

    /// Determina el estado de salud según umbrales por tipo de dominio.
    fn determine_status(&self, code: i16, m: &DomainMetrics) -> HealthStatus {
        if m.total == 0 {
            return HealthStatus::Healthy; // sin datos = saludable
        }

        let error_rate = m.error_rate();
        let max_ms = m.max_ms();

        // Umbrales por tipo de ruta
        let max_allowed_ms = match code {
            1 | 2 => 1.0,       // Fast-Path: 1ms
            3 | 4 | 10 => 50.0, // Policy-Path: 50ms
            _ => 100.0,          // External-Path: 100ms
        };

        if error_rate > 0.05 {
            HealthStatus::Unhealthy
        } else if error_rate > 0.01 || max_ms > max_allowed_ms {
            HealthStatus::Degraded
        } else {
            HealthStatus::Healthy
        }
    }

    /// ¿Hay algún dominio en estado no saludable?
    pub fn has_issues(&self) -> bool {
        self.health_summary().iter().any(|d| d.status != HealthStatus::Healthy)
    }
}

impl Default for DomainHealthMonitor {
    fn default() -> Self { Self::new() }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_monitor_records_and_reports() {
        let monitor = DomainHealthMonitor::new();
        monitor.record(3, Duration::from_micros(500), false);
        monitor.record(3, Duration::from_millis(2), false);
        monitor.record(1, Duration::from_nanos(300), false);

        let summary = monitor.health_summary();
        assert_eq!(summary.len(), 12);

        let d3 = summary.iter().find(|d| d.domain_code == 3).unwrap();
        assert_eq!(d3.total_evaluations, 2);
        assert!(d3.avg_latency_ms > 0.0);

        let d1 = summary.iter().find(|d| d.domain_code == 1).unwrap();
        assert_eq!(d1.total_evaluations, 1);
        assert_eq!(d1.status, HealthStatus::Healthy);
    }

    #[test]
    fn test_error_rate_detection() {
        let monitor = DomainHealthMonitor::new();
        // 10 evaluaciones con 2 errores = 20% error rate → Unhealthy
        for _ in 0..8 {
            monitor.record(3, Duration::from_millis(1), false);
        }
        monitor.record(3, Duration::from_millis(1), true);
        monitor.record(3, Duration::from_millis(1), true);

        let d3 = monitor.health_summary().into_iter()
            .find(|d| d.domain_code == 3).unwrap();
        assert_eq!(d3.errors, 2);
        assert!(d3.error_rate_pct > 15.0);
        assert_eq!(d3.status, HealthStatus::Unhealthy);
    }

    #[test]
    fn test_fastpath_latency_threshold() {
        let monitor = DomainHealthMonitor::new();
        // Fast-Path (D1) con latencia > 1ms → Degraded
        monitor.record(1, Duration::from_millis(5), false);
        let d1 = monitor.health_summary().into_iter()
            .find(|d| d.domain_code == 1).unwrap();
        assert_eq!(d1.status, HealthStatus::Degraded);
    }

    #[test]
    fn test_empty_monitor_all_healthy() {
        let monitor = DomainHealthMonitor::new();
        assert!(!monitor.has_issues());
        let summary = monitor.health_summary();
        assert!(summary.iter().all(|d| d.status == HealthStatus::Healthy));
    }
}
