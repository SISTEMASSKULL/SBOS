//! banexus-sdk — libbauth_nexus · SBOS
//! Librería nativa (iOS Swift Package / Android AAR) — Aliro CSA 2023: BLE + UWB + NFC.
//! STUB Etapa 1: API pública declarada, implementación en Etapa 3.
//! SSOT: BnexusAgent/context/Documentacion/ · SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md §24.3

mod aliro;
mod ffi;

/// Inicializa el SDK con la dirección de bhnexus y el cert de la CA.
/// Retorna 0 en éxito, código de error negativo en fallo.
#[no_mangle]
pub extern "C" fn bauth_nexus_init(_bhnexus_addr: *const i8, _ca_cert_pem: *const i8) -> i32 {
    // STUB — implementar en Etapa 3
    -1
}

/// Libera recursos del SDK.
#[no_mangle]
pub extern "C" fn bauth_nexus_destroy() {
    // STUB — implementar en Etapa 3
}
