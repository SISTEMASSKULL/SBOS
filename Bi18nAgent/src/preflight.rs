/// preflight.rs — Validaciones pre-arranque del daemon bi18n.
/// Propósito: verificar que el entorno de producción está correctamente preparado
///   ANTES de arrancar los servidores (JSON-RPC + gRPC). Si falla, el daemon no arranca.
///   Principio fail-fast: es mejor no arrancar que arrancar en estado degradado.
/// Checks:
///   C1 — country-rules: directorio existe y contiene al menos 1 TOML legible.
///   C2 — fluent_dir: directorio de mensajes Fluent existe (si está configurado).
///   C3 — socket JSON-RPC: directorio padre existe y tiene permisos de escritura.
///   C4 — socket gRPC: directorio padre existe y tiene permisos de escritura.
/// Dependencias: std::fs, crate::config, crate::error
use std::path::Path;
use crate::{config::Config, error::{Bi18nError, Resultado}};

/// Ejecuta todas las validaciones pre-arranque.
/// Retorna Ok(()) si el entorno está listo; Err con descripción del fallo en caso contrario.
pub async fn ejecutar(cfg: &Config) -> Resultado<()> {
    verificar_country_rules(&cfg.rutas.country_rules_dir)?;
    verificar_fluent_dir(&cfg.rutas.fluent_dir)?;
    verificar_socket_dir(&cfg.servidor.socket_path, "JSON-RPC")?;
    verificar_socket_dir(&cfg.servidor.grpc_socket_path, "gRPC")?;
    tracing::info!("preflight: todos los checks pasaron — bi18n listo para arrancar");
    Ok(())
}

/// C1 — Verifica que country-rules existe y tiene al menos 1 TOML.
fn verificar_country_rules(dir: &Path) -> Resultado<()> {
    if !dir.exists() {
        return Err(Bi18nError::PaisDirectorio {
            ruta: dir.to_path_buf(),
            causa: "el directorio country-rules no existe".to_string(),
        });
    }
    if !dir.is_dir() {
        return Err(Bi18nError::PaisDirectorio {
            ruta: dir.to_path_buf(),
            causa: "la ruta existe pero no es un directorio".to_string(),
        });
    }
    let n_toml = std::fs::read_dir(dir)
        .map_err(|e| Bi18nError::PaisDirectorio {
            ruta: dir.to_path_buf(),
            causa: format!("no se pudo leer: {}", e),
        })?
        .filter_map(|e| e.ok())
        .filter(|e| e.path().extension().and_then(|x| x.to_str()) == Some("toml"))
        .count();

    if n_toml == 0 {
        return Err(Bi18nError::PaisDirectorio {
            ruta: dir.to_path_buf(),
            causa: "no se encontró ningún archivo .toml de country-rules".to_string(),
        });
    }
    tracing::info!("preflight C1: country-rules OK — {} archivos TOML en {:?}", n_toml, dir);
    Ok(())
}

/// C2 — Verifica que fluent_dir existe (mensajes Fluent opcionales pero preferibles).
fn verificar_fluent_dir(dir: &Path) -> Resultado<()> {
    if !dir.exists() {
        // No es error fatal — FluentLoader arranca con fallback a ids literales.
        tracing::warn!(
            "preflight C2: fluent_dir {:?} no existe — mensajes en texto plano (ids literales)",
            dir
        );
        return Ok(());
    }
    tracing::info!("preflight C2: fluent_dir OK — {:?}", dir);
    Ok(())
}

/// C3/C4 — Verifica que el directorio padre del socket existe y tiene permisos de escritura.
fn verificar_socket_dir(socket_path: &Path, nombre: &str) -> Resultado<()> {
    let dir = socket_path.parent().unwrap_or(Path::new("/run"));
    if !dir.exists() {
        return Err(Bi18nError::SocketBind {
            path: socket_path.to_path_buf(),
            causa: format!(
                "el directorio '{}' no existe — crear con: mkdir -p {} && chown bos:bosagent {}",
                dir.display(), dir.display(), dir.display()
            ),
        });
    }
    // Verificar permisos de escritura intentando crear un archivo temporal.
    let prueba = dir.join(".bi18n_preflight_write_test");
    match std::fs::File::create(&prueba) {
        Ok(_) => {
            let _ = std::fs::remove_file(&prueba);
            tracing::info!("preflight C3/C4: socket {} OK — {:?}", nombre, socket_path);
        }
        Err(e) => {
            return Err(Bi18nError::SocketPermisos {
                path: socket_path.to_path_buf(),
                causa: format!("sin permisos de escritura en '{}': {}", dir.display(), e),
            });
        }
    }
    Ok(())
}
