//! bauth::saga — Motor de Sagas de Autenticación (H-10)
//!
//! Cada saga modela un flujo completo de autenticación con pasos
//! secuenciales y compensaciones inversas. Invocable vía JSON-RPC:
//! `bauth.saga.execute { saga, ctx_id, params }`.
//!
//! Átomos del plan: H-10 (Saga Engine), H-11 (HIBP), H-12 (Risk Scoring).
//! Estado actual: IMPLEMENTADO — Fase 3 completa.

pub mod step;
pub mod action;
pub mod validator;
pub mod executor;
pub mod catalog;
pub mod actions;
pub mod registry;       // B35: ActionRegistry (reemplaza simulate_action)
