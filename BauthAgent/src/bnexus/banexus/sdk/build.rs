/// build.rs — banexus SDK (DLL para Flutter desktop).
///
/// En Windows: fuerza la exportación explícita de los símbolos FFI
/// pasando el archivo banexus.def al linker (Zig/lld en modo PE).
/// Sin esto, cargo-zigbuild no genera las entradas en la PE export table
/// para las funciones pub extern "C" de Rust.
fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        // El .drectve embebido en lib.rs (static DRECTVE) fuerza la exportación.
        // --no-gc-sections es un seguro adicional: GC no puede eliminar banexus_*
        // porque nadie en la DLL los llama (son el API externo).
        println!("cargo:rustc-link-arg=-Wl,--no-gc-sections");
        println!("cargo:rerun-if-changed=src/lib.rs");
    }
}
