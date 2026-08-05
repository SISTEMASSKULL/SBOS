//! Dev CA autofirmada para Puerta 1 (Etapa 1 únicamente).
//! Genera cert CA + cert servidor con rcgen si no existen en disco.
//! Etapa 3: sustituir por SPIFFE/SVID con Vault/SPIRE.
//! SSOT: BnexusAgent/context/Documentacion/2.01_MANUAL-PUERTA-1-AGENTES.md

use rcgen::{CertificateParams, DistinguishedName, DnType, KeyPair};
use std::path::Path;
use thiserror::Error;
use tracing::{info, warn};

/// Errores del ciclo de vida de la dev CA.
#[derive(Debug, Error)]
pub enum DevCaError {
    #[error("Error rcgen generando certificado: {0}")]
    Generacion(#[from] rcgen::Error),

    #[error("Error de I/O al persistir dev CA: {0}")]
    Io(#[from] std::io::Error),
}

/// Dev CA autofirmada para TLS mutuo en Puerta 1.
/// Solo existe en modo dev — Etapa 1 bootstrap.
#[allow(dead_code)]
pub struct DevCa {
    /// DER del cert CA para validar peers en Puerta 1.
    pub cert_ca_der: Vec<u8>,
    /// PEM del cert del servidor para presentar en TLS.
    pub cert_servidor_pem: String,
    /// PEM de la clave privada del servidor.
    pub clave_servidor_pem: String,
}

impl DevCa {
    /// Genera o carga la dev CA. Persiste PEM en rutas indicadas.
    pub fn generar_o_cargar(
        cert_path: &str,
        key_path: &str,
    ) -> Result<Self, DevCaError> {
        if Path::new(cert_path).exists() && Path::new(key_path).exists() {
            info!("Dev CA encontrada en disco — cargando");
            return Self::desde_disco(cert_path, key_path);
        }

        warn!("Dev CA no encontrada — generando (solo Etapa 1)");
        Self::generar_nueva(cert_path, key_path)
    }

    /// Carga dev CA existente desde disco.
    fn desde_disco(cert_path: &str, _key_path: &str) -> Result<Self, DevCaError> {
        let cert_pem = std::fs::read_to_string(cert_path)?;
        // En Etapa 1 reutilizamos el mismo par para CA y servidor.
        Ok(Self {
            cert_ca_der: pem_a_der(&cert_pem),
            cert_servidor_pem: cert_pem.clone(),
            clave_servidor_pem: std::fs::read_to_string(_key_path)?,
        })
    }

    /// Genera CA autofirmada nueva y la persiste en disco.
    fn generar_nueva(cert_path: &str, key_path: &str) -> Result<Self, DevCaError> {
        let key_pair = KeyPair::generate()?;

        let mut params = CertificateParams::default();
        params.is_ca = rcgen::IsCa::Ca(rcgen::BasicConstraints::Unconstrained);
        let mut dn = DistinguishedName::new();
        dn.push(DnType::CommonName, "bhnexus-dev-ca");
        dn.push(DnType::OrganizationName, "SBOS Dev");
        params.distinguished_name = dn;

        let cert = params.self_signed(&key_pair)?;

        let cert_pem = cert.pem();
        let key_pem  = key_pair.serialize_pem();

        if let Some(dir) = Path::new(cert_path).parent() {
            std::fs::create_dir_all(dir)?;
        }
        std::fs::write(cert_path, &cert_pem)?;
        std::fs::write(key_path, &key_pem)?;

        info!(cert = cert_path, "Dev CA generada y persistida");

        Ok(Self {
            cert_ca_der: cert.der().to_vec(),
            cert_servidor_pem: cert_pem,
            clave_servidor_pem: key_pem,
        })
    }
}

/// Extrae el bloque DER de un PEM de certificado (primer bloque).
fn pem_a_der(pem: &str) -> Vec<u8> {
    use base64::Engine;
    let cuerpo: String = pem
        .lines()
        .filter(|l| !l.starts_with("-----"))
        .collect();
    base64::engine::general_purpose::STANDARD
        .decode(cuerpo)
        .unwrap_or_default()
}
