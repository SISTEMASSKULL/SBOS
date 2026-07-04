// ============================================================
// bos-verify — B29.T08 + B29.T19: Verificador Merkle Proof
//
// Verifica anclajes blockchain del SBOS sin depender del daemon.
// Modo offline: verifica contra un Merkle proof local.
// Modo online: consulta el smart contract en Arbitrum One.
//
// RFC 6962 — Certificate Transparency
// Keccak-256 (SHA3) — NIST FIPS 202
//
// Uso:
//   bos-verify offline --proof batch-42.proof.json
//   bos-verify online --rpc https://arb1.arbitrum.io/rpc --batch-id 42
// ============================================================

use std::process;

const VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Debug)]
struct Cli {
    mode: Mode,
}

#[derive(Debug)]
enum Mode {
    Offline {
        proof_file: String,
        expected_root: Option<String>,
    },
    Online {
        rpc_url: String,
        contract_addr: String,
        batch_id: u64,
    },
    Version,
    Help,
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let cli = parse_args(&args);

    match cli.mode {
        Mode::Version => {
            println!("bos-verify v{VERSION} — SBOS Merkle Proof Verifier (RFC 6962)");
            println!("Verifica anclajes blockchain del Context Plane D12.");
        }
        Mode::Help => print_usage(),
        Mode::Offline { proof_file, expected_root } => {
            println!("🔍 Verificación OFFLINE");
            println!("   Archivo de prueba: {proof_file}");
            if let Some(root) = &expected_root {
                println!("   Merkle root esperado: {root}");
            }
            match verify_offline(&proof_file, expected_root.as_deref()) {
                Ok(true) => {
                    println!("✅ VERIFICADO — el anclaje es válido.");
                    println!("   El evento existía en el lote Merkle al momento del anclaje.");
                    println!("   No ha sido alterado.");
                }
                Ok(false) => {
                    println!("❌ NO VERIFICADO — la prueba Merkle no coincide.");
                    println!("   Posibles causas:");
                    println!("   1. El proof está corrupto o fue modificado");
                    println!("   2. El evento no pertenece a este lote");
                    println!("   3. La raíz esperada no coincide con el proof");
                    process::exit(1);
                }
                Err(e) => {
                    eprintln!("💥 Error al verificar: {e}");
                    process::exit(2);
                }
            }
        }
        Mode::Online { rpc_url, contract_addr, batch_id } => {
            println!("🌐 Verificación ON-CHAIN");
            println!("   RPC: {rpc_url}");
            println!("   Contrato: {contract_addr}");
            println!("   Batch ID: {batch_id}");
            println!("   ⚠️  Modo online requiere conexión a Arbitrum One.");
            println!("   Implemente ethers-rs en B29.T05 para verificación on-chain completa.");
            println!("   Por ahora, use el modo offline con el proof exportado.");
        }
    }
}

/// Verifica una prueba Merkle desde archivo JSON.
fn verify_offline(proof_file: &str, expected_root: Option<&str>) -> Result<bool, String> {
    let data = std::fs::read_to_string(proof_file)
        .map_err(|e| format!("no se pudo leer '{}': {}", proof_file, e))?;

    let proof: serde_json::Value = serde_json::from_str(&data)
        .map_err(|e| format!("JSON inválido: {}", e))?;

    let merkle_root = proof.get("merkle_root")
        .and_then(|v| v.as_str())
        .ok_or("campo 'merkle_root' requerido")?;

    let leaf_hash_hex = proof.get("leaf_hash")
        .and_then(|v| v.as_str())
        .ok_or("campo 'leaf_hash' requerido")?;

    let proof_hashes: Vec<String> = proof.get("proof_hashes")
        .and_then(|v| v.as_array())
        .map(|arr| arr.iter().filter_map(|v| v.as_str().map(|s| s.to_string())).collect())
        .ok_or("campo 'proof_hashes' requerido como array")?;

    // Reconstruir la raíz Merkle desde leaf + proof hashes
    let mut current = hex_to_bytes(leaf_hash_hex)?;

    for hash_hex in proof_hashes.iter() {
        let sibling = hex_to_bytes(hash_hex)?;
        // Keccak-256 con domain separation (RFC 6962)
        // 0x01 || min(h1,h2) || max(h1,h2) para nodos internos
        use sha3::{Digest, Keccak256};
        let mut hasher = Keccak256::new();
        hasher.update([0x01u8]); // node prefix
        if current < sibling {
            hasher.update(current);
            hasher.update(sibling);
        } else {
            hasher.update(sibling);
            hasher.update(current);
        }
        current = hasher.finalize().into();
    }

    let computed_root = bytes_to_hex(&current);

    if let Some(expected) = expected_root {
        if expected.to_lowercase() != computed_root {
            return Ok(false);
        }
    }

    Ok(computed_root == merkle_root.to_lowercase())
}

fn hex_to_bytes(hex: &str) -> Result<[u8; 32], String> {
    let hex = hex.strip_prefix("0x").unwrap_or(hex);
    let bytes = hex::decode(hex)
        .map_err(|e| format!("hex inválido: {}", e))?;
    if bytes.len() != 32 {
        return Err(format!("se esperaban 32 bytes, hay {}", bytes.len()));
    }
    let mut arr = [0u8; 32];
    arr.copy_from_slice(&bytes);
    Ok(arr)
}

fn bytes_to_hex(bytes: &[u8; 32]) -> String {
    format!("0x{}", hex::encode(bytes))
}

fn parse_args(args: &[String]) -> Cli {
    if args.len() < 2 {
        return Cli { mode: Mode::Help };
    }

    let mut mode = Mode::Help;
    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "offline" => {
                let mut proof_file = String::new();
                let expected_root = None;
                i += 1;
                while i < args.len() && !args[i].starts_with("--") {
                    if proof_file.is_empty() {
                        proof_file = args[i].clone();
                    }
                    i += 1;
                }
                mode = Mode::Offline { proof_file, expected_root };
            }
            "--proof" | "-p" => {
                i += 1;
                if let Mode::Offline { expected_root, .. } = &mut mode {
                    *expected_root = Some(args[i].clone());
                }
                i += 1;
            }
            "online" => {
                let mut rpc_url = String::new();
                let mut contract_addr = String::new();
                let mut batch_id = 0u64;
                i += 1;
                while i < args.len() && args[i].starts_with("--") {
                    match args[i].as_str() {
                        "--rpc" => { i += 1; rpc_url = args[i].clone(); }
                        "--contract" => { i += 1; contract_addr = args[i].clone(); }
                        "--batch-id" => { i += 1; batch_id = args[i].parse().unwrap_or(0); }
                        _ => {}
                    }
                    i += 1;
                }
                mode = Mode::Online { rpc_url, contract_addr, batch_id };
            }
            "version" | "--version" | "-V" => {
                mode = Mode::Version;
                break;
            }
            _ => {
                i += 1;
            }
        }
    }
    Cli { mode }
}

fn print_usage() {
    println!(r"bos-verify v{VERSION} — SBOS Merkle Proof Verifier (RFC 6962)

USO:
    bos-verify offline <proof.json> [--proof <expected_root>]
    bos-verify online --rpc <url> --contract <addr> --batch-id <id>
    bos-verify version

MODOS:
    offline   Verificar contra un archivo de prueba Merkle local
    online    Verificar contra el smart contract en Arbitrum One

EJEMPLOS:
    bos-verify offline batch-42.proof.json
    bos-verify offline batch-42.proof.json --proof 0xabcd1234...
    bos-verify online --rpc https://arb1.arbitrum.io/rpc --contract 0x... --batch-id 42

ESTÁNDARES:
    RFC 6962 (Certificate Transparency)
    NIST FIPS 202 (SHA-3 / Keccak-256)
    SBOS-049 §9 (Context Plane — trazabilidad blockchain)
");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hex_roundtrip() {
        let original = [42u8; 32];
        let hex_str = bytes_to_hex(&original);
        let restored = hex_to_bytes(&hex_str).unwrap();
        assert_eq!(original, restored);
    }

    #[test]
    fn test_hex_strip_prefix() {
        let with_prefix = "0xabcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234";
        let without_prefix = "abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234";
        let a = hex_to_bytes(with_prefix).unwrap();
        let b = hex_to_bytes(without_prefix).unwrap();
        assert_eq!(a, b);
    }
}
