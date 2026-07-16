/// build.rs — compila proto/bi18n.proto en código Rust antes de compilar el crate.
/// Genera el módulo bi18n_v1 con los tipos prost + los traits de servicio tonic.
/// Salida: src/generated/ (incluido en el control de versiones para auditoría).
/// Requiere: protoc instalado en el host de compilación (verificado: /usr/bin/protoc 3.21.12).
fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::configure()
        .build_server(true)     // genera traits de servidor para bi18nd
        .build_client(true)     // genera cliente para tests y i18nctl
        .out_dir("src/generated/")
        .compile_protos(&["proto/bi18n.proto"], &["proto/"])?;
    Ok(())
}
