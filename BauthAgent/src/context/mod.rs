//! bauth::context — B16 Context Plane (SBOS-049)
//!
//! ARQUITECTURA:
//!   BOS → CREA dctx_id/ctx_id (governor del ciclo de vida)
//!   bAuth → VALIDA + INYECTA tenant/user/role (authenticate/inject)
//!   Kong → ENFORCE vía PEP (X-SBOS-Context header)
//!   Todos → PROPAGAN vía W3C traceparent + OTel Baggage
//!
//! Referencias: W3C Trace Context Level 2, NIST SP 800-207, ISO 27001 A.8.15

pub mod plane;
pub mod engine;
