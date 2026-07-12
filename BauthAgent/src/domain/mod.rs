// ================================================================
// bauth::domain — Lógica pura del dominio de identidad
//
// REGLA ABSOLUTA: SIN I/O. Sin HTTP, DB, Redis, filesystem.
//
// Módulos:
//   domain/bitmask → REEMPLAZADO por crate::bitmask (BitMask Dual v3.0)
//   lifecycle.rs   → Ciclo de vida del rol (7 estados)
//
// DOC-SBOS-001 N3 · SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md §4-6
// SAM-128 ELIMINADO. BitmaskBundle ELIMINADO.
// ================================================================

pub mod inheritance;
pub mod lifecycle;
pub mod password;
pub mod sod;
pub mod physical;
pub mod logical;
pub mod financial;
pub mod auth_methods; // Fase 1 Roadmap: validadores nativos de autenticación
pub mod notify;          // G2: cliente bnotify — contrato + stub para desarrollo
pub mod security_notify; // Notificaciones automaticas de seguridad → Mattermost
pub mod user_notify;          // Notificaciones personales → DM al usuario
pub mod hierarchical_notify;  // Notificacion jerarquica: tenant/empresa/sucursal/usuario
pub mod notify_config;        // Configuracion de notificaciones (H-001..H-004 fix)
pub mod roltemplate_validator;  // Validacion 14 secciones RolTemplate v6.0
pub mod usertemplate_validator; // Validacion 15 secciones UserTemplate v6.0
pub mod validate;             // Validacion de datos con garde (email, phone, date, text)
pub mod temporal;
pub mod biometric;
pub mod geospatial;
pub mod network;
pub mod context;
pub mod credential;
pub mod delegation;
pub mod audit_domain;
pub mod blockchain;
pub mod policy;
pub mod policy_chain;
pub mod jwt_builder;    // B48.T01: Constructor de tokens JWT de bAuth
pub mod jwt_signer;     // B48.T02: Firmador Ed25519 de tokens JWT
pub mod jwe_encrypt;    // B48.T02: Cifrado JWE AES-256-GCM (RFC 7516)
pub mod config;
pub mod health;
pub mod startup;        // Fase 2: DomainRegistry + PolicyChainResolver + FastPath + Closure + ConflictMatrix
pub mod merge;           // B45.D02: merge_role_templates() — 12 idn_role_d* → JSONB v6.0
pub mod merkle;         // B29: Merkle Tree Engine (RFC 6962 + Keccak-256)
pub mod risk;           // H-12: Risk Scoring Engine (Zero Trust NIST 800-207)
pub mod rule_engine;    // B45: RuleEngine — validación de valores contra cfg_validation_rule
pub mod calendar_alarm; // B47.C01: Cron Job poll_cal_alarms() — alarma→bnotify→WORM log
pub mod caep;           // C-BAUTH-004: eventos CAEP (SSF) hacia bNotify — tipos puros
pub mod andamiaje;      // La base arquitectónica: contratos BA1-BA20 (A.41 §11) — fail-closed

// Re-export del nuevo motor BitMask Dual
