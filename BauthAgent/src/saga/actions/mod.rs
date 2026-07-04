//! bauth::saga::actions — Funciones de acción para pasos de saga
//!
//! H-11: HIBP k-anonymity screening
//! H-12: Risk scoring (en domain/risk.rs)

pub mod hibp;
pub mod login;    // B35: verify_argon2id + record_failed_attempt
