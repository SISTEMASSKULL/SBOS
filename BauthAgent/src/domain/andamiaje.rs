// ============================================================
// bauth::domain::andamiaje — El andamiaje arquitectónico de bAuth
//
// Define los CONTRATOS (traits + firmas) que la arquitectura de bAuth
// necesita y que aún NO tienen implementación completa. Cada contrato lleva
// su firma exacta, su justificación (norma internacional + manual + anexo) y
// su estado. El desarrollador implementa el CUERPO; la firma ya está definida
// aquí — no se reinventa lo que ya está diseñado.
//
// PRINCIPIO FAIL-CLOSED (anti-estafa, ver anexo A.41):
//   Los métodos sin implementar retornan `Err(Pendiente)` — un error EXPLÍCITO
//   que dice "contrato definido, cuerpo por desarrollar". JAMÁS retornan un
//   valor ficticio de éxito. Un andamiaje honesto niega hasta que se implemente.
//
// Fuente del catálogo: A.41 §11 (BASE ARQUITECTÓNICA, contratos BA1–BA20).
// ESPECIFICACIÓN DEL CUERPO de cada contrato (parámetros + algoritmo paso a paso
// que la norma exige): anexo A.42. Este archivo tiene las FIRMAS; A.42 tiene los
// PASOS a programar. Se leen juntos: aquí el enganche en Rust, allá qué hacer dentro.
// Estándar de documentación: DOC-SBOS-001 N3 (todo en español, todo documentado).
// ============================================================

use serde::Serialize;

/// Error uniforme del andamiaje: un contrato ARQUITECTÓNICAMENTE DEFINIDO cuyo
/// cuerpo aún está por desarrollar. Es fail-closed: negar acceso/operación hasta
/// que el contrato se implemente. Nunca es un `Ok` disfrazado.
#[derive(Debug, Clone, Serialize)]
pub struct Pendiente {
    /// Código del contrato en el catálogo (ej. "BA2").
    pub contrato: &'static str,
    /// Descripción de lo que falta desarrollar.
    pub descripcion: &'static str,
    /// Norma internacional que lo exige (ej. "RFC 9449").
    pub norma: &'static str,
    /// Manual + anexo que lo justifican (ej. "2.03 / A.28").
    pub referencia: &'static str,
}

impl Pendiente {
    pub const fn nuevo(
        contrato: &'static str, descripcion: &'static str,
        norma: &'static str, referencia: &'static str,
    ) -> Self {
        Self { contrato, descripcion, norma, referencia }
    }
}

impl std::fmt::Display for Pendiente {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "[{} PENDIENTE] {} — exige {} (ver {})",
            self.contrato, self.descripcion, self.norma, self.referencia)
    }
}
impl std::error::Error for Pendiente {}

/// Estado de un contrato del andamiaje — para el registro consultable (§ REGISTRO).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum EstadoContrato {
    /// Implementado y verificado.
    Hecho,
    /// Existe base en el código; falta la parte crítica.
    AConectarOCompletar,
    /// No existe; por desarrollar desde el andamiaje.
    PorDesarrollar,
}

// ════════════════════════════════════════════════════════════
// BA2 — Verificación del proof DPoP (RFC 9449)
// NORMA: RFC 9449 · JUSTIFICA: MANUAL-TOKENS 2.03 / A.28-T1 / A.41 §2.2
// ESTADO: PorDesarrollar (hoy el handler retorna verified:true sin verificar).
// ════════════════════════════════════════════════════════════

/// Contrato de verificación de un proof DPoP (sender-constrained tokens, RFC 9449).
/// La implementación DEBE verificar: (a) la firma del proof con la `jwk` de su header,
/// (b) el `ath` = hash del access token, (c) `htm`/`htu` (método/URI HTTP),
/// (d) el `jti` contra un store anti-replay, (e) la ventana de `iat`.
pub trait VerificadorDpop: Send + Sync {
    fn verificar_proof(
        &self, proof_jwt: &str, access_token: &str, htm: &str, htu: &str,
    ) -> Result<(), Pendiente>;
}

/// Stub fail-closed del BA2 — niega hasta que exista la verificación real.
pub struct DpopPorDesarrollar;
impl VerificadorDpop for DpopPorDesarrollar {
    fn verificar_proof(&self, _p: &str, _t: &str, _m: &str, _u: &str) -> Result<(), Pendiente> {
        Err(Pendiente::nuevo("BA2",
            "verificación criptográfica del proof DPoP (firma jwk + ath + htm/htu + jti + iat)",
            "RFC 9449", "2.03 / A.28-T1"))
    }
}

// ════════════════════════════════════════════════════════════
// BA4 — Límite anti-fuerza-bruta en el login
// NORMA: OWASP ASVS 2.2.1 · NIST 800-63B §5.2.2 · JUSTIFICA: A.41 §8
// ESTADO: PorDesarrollar (la tabla ath_login_attempt existe; falta el motor).
// ════════════════════════════════════════════════════════════

/// Contrato del limitador de intentos de login (brute-force online).
/// La implementación consulta `ath_login_attempt` y bloquea tras N fallos por
/// cuenta/IP con backoff exponencial. `Ok` = puede intentar; `Err` = bloqueado.
pub trait LimitadorLogin: Send + Sync {
    fn permitir_intento(&self, username: &str, client_ip: &str) -> Result<(), Pendiente>;
}

pub struct LimitadorLoginPorDesarrollar;
impl LimitadorLogin for LimitadorLoginPorDesarrollar {
    fn permitir_intento(&self, _u: &str, _ip: &str) -> Result<(), Pendiente> {
        Err(Pendiente::nuevo("BA4",
            "bloqueo anti-fuerza-bruta por cuenta/IP (backoff) sobre ath_login_attempt",
            "OWASP ASVS 2.2.1 / NIST 800-63B §5.2.2", "2.01 / A.41 §8"))
    }
}

// ════════════════════════════════════════════════════════════
// BA6 — Identity Proofing (verificación de identidad IAL 1-3)
// NORMA: NIST SP 800-63A · JUSTIFICA: A.09 / A.02 §19.2-U1
// ESTADO: PorDesarrollar (el IAL 1-3 no tiene código; fuente de A.02 U1).
// ════════════════════════════════════════════════════════════

/// Nivel de aseguramiento de identidad alcanzado (NIST SP 800-63A).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum NivelIal { Ial1, Ial2, Ial3 }

/// Contrato del proofing de identidad. La implementación verifica la evidencia
/// (FAIR/STRONG/SUPERIOR) según el `objetivo`, emite un evento de auditoría del
/// proofing y persiste el resultado en la sección `identity_proofing` del UserTemplate.
pub trait ProofingIdentidad: Send + Sync {
    fn verificar(&self, evidencia_json: &str, objetivo: NivelIal) -> Result<NivelIal, Pendiente>;
}

pub struct ProofingPorDesarrollar;
impl ProofingIdentidad for ProofingPorDesarrollar {
    fn verificar(&self, _e: &str, _o: NivelIal) -> Result<NivelIal, Pendiente> {
        Err(Pendiente::nuevo("BA6",
            "verificación de identidad IAL1-3 (evidencia FAIR/STRONG/SUPERIOR) + registro identity_proofing",
            "NIST SP 800-63A", "A.09 / A.02-U1"))
    }
}

// ════════════════════════════════════════════════════════════
// BA8 — Motor de firma EXTERNO (ADSIB, validez jurídica Ley 164)
// NORMA: Ley 164 Art. 78 · ADSIB-FD-POLT-015 · eIDAS · JUSTIFICA: A.08 (F-C1)
// ESTADO: PorDesarrollar (solo existe el motor interno Ed25519).
// ════════════════════════════════════════════════════════════

/// Contrato del motor de firma externo con validez jurídica plena (RSA-SHA256,
/// certificado ADSIB). Firma documentos oponibles a terceros (facturación SIN,
/// contratos legales) — distinto del motor interno Ed25519 (que ya existe).
pub trait FirmaExternaLegal: Send + Sync {
    fn firmar_adsib(&self, doc_hash: &[u8], cert_serial: &str) -> Result<Vec<u8>, Pendiente>;
}

pub struct FirmaExternaPorDesarrollar;
impl FirmaExternaLegal for FirmaExternaPorDesarrollar {
    fn firmar_adsib(&self, _h: &[u8], _c: &str) -> Result<Vec<u8>, Pendiente> {
        Err(Pendiente::nuevo("BA8",
            "motor de firma legal externo RSA-SHA256 con certificado ADSIB (validez jurídica)",
            "Ley 164 Art. 78 / ADSIB-FD-POLT-015 / eIDAS", "2.04 / A.08 F-C1"))
    }
}

// ════════════════════════════════════════════════════════════
// BA11 — Emisor central de auditoría
// NORMA: NIST AU-12 · ISO 27001 A.8.15 · JUSTIFICA: A.27-AU1
// ESTADO: PorDesarrollar (src/audit/ es solo mod.rs; el DDL superior sin emisor).
// ════════════════════════════════════════════════════════════

/// Contrato del emisor central de eventos de auditoría. Toda operación que muta
/// estado emite por aquí, con su `iso_control[]` en origen y su severidad, hacia
/// `aud_event` (WORM) y — si severity ≥ WARNING — hacia el SIEM (Wazuh).
pub trait EmisorAuditoria: Send + Sync {
    fn emitir(
        &self, tipo_evento: &str, iso_control: &[&str], ctx_id: &str, payload_json: &str,
    ) -> Result<(), Pendiente>;
}

pub struct EmisorAuditoriaPorDesarrollar;
impl EmisorAuditoria for EmisorAuditoriaPorDesarrollar {
    fn emitir(&self, _t: &str, _c: &[&str], _x: &str, _p: &str) -> Result<(), Pendiente> {
        Err(Pendiente::nuevo("BA11",
            "emisor central de auditoría (aud_event + iso_control[] + salida SIEM Wazuh)",
            "NIST AU-12 / ISO 27001 A.8.15", "5.01 / A.27-AU1"))
    }
}

// ════════════════════════════════════════════════════════════
// BA13 — Motores IGA (certificación, barrido de huérfanas, JML)
// NORMA: NIST AC-2(j) · ISO 27001 A.5.18 · JUSTIFICA: A.10 / A.30
// ESTADO: AConectarOCompletar (tablas aud_review/aud_ghost_account existen).
// ════════════════════════════════════════════════════════════

/// Contrato de los motores de gobernanza (IGA). Cada método ejecuta un ciclo
/// completo sobre su tabla de sustrato (que ya existe en el DDL).
pub trait MotoresIga: Send + Sync {
    /// Campaña de certificación de acceso (sobre `aud_review`).
    fn correr_campana_certificacion(&self) -> Result<u32, Pendiente>;
    /// Barrido de cuentas huérfanas (sobre `aud_ghost_account`).
    fn barrer_huerfanas(&self) -> Result<u32, Pendiente>;
}

pub struct MotoresIgaPorDesarrollar;
impl MotoresIga for MotoresIgaPorDesarrollar {
    fn correr_campana_certificacion(&self) -> Result<u32, Pendiente> {
        Err(Pendiente::nuevo("BA13",
            "motor de campañas de certificación de acceso sobre aud_review",
            "NIST AC-2(j) / ISO 27001 A.5.18", "7.01 / A.30"))
    }
    fn barrer_huerfanas(&self) -> Result<u32, Pendiente> {
        Err(Pendiente::nuevo("BA13",
            "motor de barrido de cuentas huérfanas sobre aud_ghost_account",
            "NIST AC-2(j)", "7.01 / A.30"))
    }
}

// ════════════════════════════════════════════════════════════
// EL REGISTRO DEL ANDAMIAJE — el mapa consultable de qué falta
// ════════════════════════════════════════════════════════════

/// Una entrada del registro: un contrato de la base arquitectónica con su estado.
#[derive(Debug, Clone, Serialize)]
pub struct EntradaAndamiaje {
    pub contrato: &'static str,
    pub nombre: &'static str,
    pub norma: &'static str,
    pub referencia: &'static str,
    pub estado: EstadoContrato,
}

/// El registro completo de la base arquitectónica (A.41 §11). Fuente única de
/// verdad de "qué está hecho / qué completar / qué desarrollar" — consultable
/// por código (p. ej. un panel del dashboard o `bauthctl arquitectura`).
pub fn registro_base_arquitectonica() -> Vec<EntradaAndamiaje> {
    use EstadoContrato::*;
    vec![
        EntradaAndamiaje { contrato: "BA1",  nombre: "WebAuthn verify_assertion (firma real W3C §7.2)", norma: "W3C WebAuthn L3 §7.2", referencia: "2.01 / A.41 §2.1", estado: Hecho },
        EntradaAndamiaje { contrato: "BA2",  nombre: "DPoP proof verification",              norma: "RFC 9449",                    referencia: "2.03 / A.28",  estado: PorDesarrollar },
        EntradaAndamiaje { contrato: "BA3",  nombre: "Pipeline fail-closed (None => denegado)", norma: "fail-closed CLAUDE §8",     referencia: "1.01 / A.21",  estado: AConectarOCompletar },
        EntradaAndamiaje { contrato: "BA4",  nombre: "Rate-limit anti-brute-force login",    norma: "OWASP ASVS 2.2.1",            referencia: "2.01 / A.41",  estado: PorDesarrollar },
        EntradaAndamiaje { contrato: "BA5",  nombre: "mTLS parsing X.509 + token cnf (RFC 8705)", norma: "RFC 5280 / RFC 8705",     referencia: "2.03 / A.28",  estado: AConectarOCompletar },
        EntradaAndamiaje { contrato: "BA6",  nombre: "Identity Proofing IAL 1-3",            norma: "NIST SP 800-63A",             referencia: "A.09 / A.02-U1", estado: PorDesarrollar },
        EntradaAndamiaje { contrato: "BA7",  nombre: "DDL idn_identity_attribute + idn_policy_node_type", norma: "SCIM RFC 7643 / ISO 24760-1", referencia: "1.07 / A.31",  estado: PorDesarrollar },
        EntradaAndamiaje { contrato: "BA8",  nombre: "Motor de firma externo ADSIB (Ley 164)", norma: "Ley 164 / eIDAS",           referencia: "2.04 / A.08",  estado: PorDesarrollar },
        EntradaAndamiaje { contrato: "BA9",  nombre: "JWT signer a Vault PKI + rotación",    norma: "NIST 800-57",                 referencia: "2.04 / A.08",  estado: AConectarOCompletar },
        EntradaAndamiaje { contrato: "BA10", nombre: "Cablear Risk Engine al pipeline D8",   norma: "NIST 800-207 §4",             referencia: "3.01 / A.26",  estado: AConectarOCompletar },
        EntradaAndamiaje { contrato: "BA11", nombre: "Emisor central de auditoría",          norma: "NIST AU-12 / ISO A.8.15",     referencia: "5.01 / A.27",  estado: PorDesarrollar },
        EntradaAndamiaje { contrato: "BA12", nombre: "Aplicar bauth_44 WORM en VPS",         norma: "ISO 27001 A.5.33",            referencia: "5.01 / A.27",  estado: AConectarOCompletar },
        EntradaAndamiaje { contrato: "BA13", nombre: "Motores IGA (certificación/barrido/JML)", norma: "NIST AC-2(j) / ISO A.5.18", referencia: "7.01 / A.30", estado: AConectarOCompletar },
        EntradaAndamiaje { contrato: "BA14", nombre: "Seeds de átomos D2-D12 + D13",         norma: "Diseño SBOS",                 referencia: "1.03 / A.05",  estado: PorDesarrollar },
        EntradaAndamiaje { contrato: "BA15", nombre: "SAM-128: computar o deprecar B9",      norma: "G-B09",                       referencia: "1.04 / A.17",  estado: PorDesarrollar },
        EntradaAndamiaje { contrato: "BA16", nombre: "Completar evaluadores D5-D12 + D8/D9", norma: "NIST 800-207",                referencia: "1.01 / A.21",  estado: AConectarOCompletar },
        EntradaAndamiaje { contrato: "BA17", nombre: "RLS multi-tenant (defensa en profundidad)", norma: "NIST AC-4/SC-4",         referencia: "1.12 / A.22",  estado: PorDesarrollar },
        EntradaAndamiaje { contrato: "BA18", nombre: "Reemplazar 175 unwrap por Result",     norma: "DOC-SBOS-001 N3",             referencia: "A.41 §7",      estado: AConectarOCompletar },
        EntradaAndamiaje { contrato: "BA19", nombre: "Auditar 100 allow(dead_code)",         norma: "DOC-SBOS-001 N3",             referencia: "A.41 §5",      estado: AConectarOCompletar },
        EntradaAndamiaje { contrato: "BA20", nombre: "Retirar idp_external declarativo (KC eliminado)", norma: "ADR-010",          referencia: "1.12 / A.41",  estado: AConectarOCompletar },
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_stubs_son_fail_closed() {
        // El andamiaje JAMÁS retorna éxito: todo stub niega hasta implementarse.
        assert!(DpopPorDesarrollar.verificar_proof("", "", "", "").is_err());
        assert!(LimitadorLoginPorDesarrollar.permitir_intento("", "").is_err());
        assert!(ProofingPorDesarrollar.verificar("", NivelIal::Ial2).is_err());
        assert!(FirmaExternaPorDesarrollar.firmar_adsib(&[], "").is_err());
        assert!(EmisorAuditoriaPorDesarrollar.emitir("", &[], "", "").is_err());
        assert!(MotoresIgaPorDesarrollar.barrer_huerfanas().is_err());
    }

    #[test]
    fn test_registro_completo_20_contratos() {
        let reg = registro_base_arquitectonica();
        assert_eq!(reg.len(), 20, "el registro debe listar los 20 contratos BA1-BA20");
        // BA1 (WebAuthn) es el único Hecho a la fecha.
        assert_eq!(reg[0].contrato, "BA1");
        assert_eq!(reg[0].estado, EstadoContrato::Hecho);
    }

    #[test]
    fn test_pendiente_se_muestra_con_referencia() {
        let p = Pendiente::nuevo("BA2", "prueba", "RFC 9449", "A.28");
        let s = p.to_string();
        assert!(s.contains("BA2") && s.contains("RFC 9449") && s.contains("A.28"));
    }
}
