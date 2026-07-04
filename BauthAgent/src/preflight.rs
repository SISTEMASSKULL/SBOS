// ================================================================
// bauth::preflight — Validador de Pre-Vuelo (B0.T09)
//
// Se ejecuta ANTES de cualquier inicialización del daemon.
// Verifica que el entorno cumple todos los requisitos mínimos.
// Si falla → el daemon aborta con mensajes en español accionables.
//
// Estándares:
//   NIST SP 800-53 Rev.5 CM-2 (Baseline Configuration)
//   NIST SP 800-53 Rev.5 CM-6 (Configuration Settings)
//   NIST SP 800-53 Rev.5 CM-8 (Information System Component Inventory)
//   ISO 27001:2022 A.8.1 (Operational procedures and responsibilities)
//   ISO 27001:2022 A.8.9 (Configuration management)
//
// Principios:
//   - Cada chequeo es independiente — un fallo no oculta los demás
//   - Todos los errores se recolectan antes de abortar
//   - Mensajes en español con la causa y la acción correctiva
//   - Sin hardcodear — paths y umbrales vienen de configuración
// ================================================================

#![allow(dead_code)]
use std::path::{Path, PathBuf};
use tracing::{info, warn};

// ─── Tipos ─────────────────────────────────────────────────────

/// Resultado de un chequeo individual.
#[derive(Debug)]
pub struct CheckResult {
    /// Nombre del chequeo (ej: "socket_dir", "config_file").
    pub check: &'static str,
    /// true = pasó, false = falló.
    pub passed: bool,
    /// Mensaje descriptivo en español.
    pub message: String,
}

/// Configuración del validador — sin hardcodear paths ni umbrales.
#[derive(Debug, Clone)]
pub struct PreflightConfig {
    /// Path del socket Unix que el daemon debe bindear.
    pub socket_path: PathBuf,
    /// Grupo propietario esperado del directorio socket.
    pub socket_group: String,
    /// Permisos esperados del directorio socket (máscara octal).
    pub socket_dir_perms: u32,
    /// Path del archivo de configuración TOML.
    pub config_path: Option<PathBuf>,
    /// Mínimo de file descriptors requeridos.
    pub min_fd_limit: u64,
}

impl Default for PreflightConfig {
    fn default() -> Self {
        Self {
            socket_path: PathBuf::from("/run/bos/bauth.sock"),
            socket_group: "bosagent".into(),
            socket_dir_perms: 0o750,
            config_path: Some(PathBuf::from("/etc/bos/bauth.toml")),
            min_fd_limit: 4096,
        }
    }
}

// ─── Validador ──────────────────────────────────────────────────

/// Ejecuta todos los chequeos de pre-vuelo.
///
/// # Orden de chequeos
/// 1. Identidad del proceso (usuario, grupo)
/// 2. Recursos del sistema (file descriptors, memoria)
/// 3. Sistema de archivos (paths, permisos)
/// 4. Binarios requeridos (si aplica)
///
/// # Retorno
/// - `Ok(())` si todos los chequeos pasan
/// - `Err(Vec<CheckResult>)` con TODOS los fallos encontrados
pub fn run(config: &PreflightConfig) -> Result<(), Vec<CheckResult>> {
    let mut results: Vec<CheckResult> = Vec::new();

    // ── Fase 1: Identidad ──────────────────────────────
    check_user(&mut results);
    check_groups(config, &mut results);

    // ── Fase 2: Recursos del sistema ──────────────────
    check_fd_limit(config, &mut results);
    check_cpu_available(&mut results);

    // ── Fase 3: Sistema de archivos ────────────────────
    check_socket_dir(config, &mut results);
    if let Some(ref config_path) = config.config_path {
        check_config_file(config_path, &mut results);
    }

    // ── Fase 4: Binarios del sistema ───────────────────
    check_system_binaries(&mut results);

    // ── Evaluar ────────────────────────────────────────
    let failures: Vec<CheckResult> = results.into_iter().filter(|r| !r.passed).collect();

    if failures.is_empty() {
        info!("preflight: todos los chequeos superados");
        Ok(())
    } else {
        warn!(fallos = failures.len(), "preflight: detectados problemas");
        Err(failures)
    }
}

// ─── Chequeos individuales ──────────────────────────────────────

/// Verifica que el proceso se ejecuta como un usuario concreto (no root).
fn check_user(results: &mut Vec<CheckResult>) {
    // SAFETY: geteuid() es thread-safe, no toma parámetros, y retorna el UID efectivo.
    // No hay riesgo de UB porque no accede a memoria del proceso.
    let uid = unsafe { libc::geteuid() };
    let user = std::env::var("USER").unwrap_or_else(|_| String::from("desconocido"));

    if uid == 0 {
        results.push(CheckResult {
            check: "user_not_root",
            passed: false,
            message: format!(
                "bauth no debe ejecutarse como root (UID=0, usuario='{user}'). \
                 Configure User= en bauth.service con un usuario sin privilegios."
            ),
        });
    } else {
        results.push(CheckResult {
            check: "user_not_root",
            passed: true,
            message: format!("Usuario '{}' (UID={}) correcto — no root", user, uid),
        });
    }
}

/// Verifica pertenencia a los grupos requeridos.
fn check_groups(config: &PreflightConfig, results: &mut Vec<CheckResult>) {
    let group = &config.socket_group;

    // Verificar que el grupo existe en el sistema
    let gid = get_gid_by_name(group);

    match gid {
        Some(g) => results.push(CheckResult {
            check: "socket_group_exists",
            passed: true,
            message: format!("Grupo '{}' existe (GID={})", group, g),
        }),
        None => results.push(CheckResult {
            check: "socket_group_exists",
            passed: false,
            message: format!(
                "Grupo '{}' no existe en el sistema. \
                 Créelo con: groupadd --system {}",
                group, group
            ),
        }),
    }

    // Verificar que el usuario actual pertenece al grupo
    let user = std::env::var("USER").unwrap_or_else(|_| "bauth".into());
    let in_group = match gid {
        Some(g) => user_in_group(&user, g),
        None => false,
    };

    if in_group {
        results.push(CheckResult {
            check: "user_in_socket_group",
            passed: true,
            message: format!("Usuario '{}' pertenece al grupo '{}'", user, group),
        });
    } else {
        results.push(CheckResult {
            check: "user_in_socket_group",
            passed: false,
            message: format!(
                "El usuario '{}' no pertenece al grupo '{}'. \
                 Agréguelo con: usermod -a -G {} {}",
                user, group, group, user
            ),
        });
    }
}

/// Busca el GID de un grupo por nombre. Retorna None si no existe.
fn get_gid_by_name(name: &str) -> Option<libc::gid_t> {
    let cname = std::ffi::CString::new(name).ok()?;
    let mut buf = vec![0u8; 4096];
    let mut grp: libc::group = unsafe { std::mem::zeroed() };
    let mut result: *mut libc::group = std::ptr::null_mut();

    let rc = unsafe {
        libc::getgrnam_r(
            cname.as_ptr(),
            &mut grp,
            buf.as_mut_ptr() as *mut libc::c_char,
            buf.len(),
            &mut result,
        )
    };

    if rc == 0 && !result.is_null() {
        Some(grp.gr_gid)
    } else {
        None
    }
}

/// Verifica si un usuario pertenece a un grupo específico.
fn user_in_group(username: &str, gid: libc::gid_t) -> bool {
    let cuser = match std::ffi::CString::new(username) {
        Ok(c) => c,
        Err(_) => return false,
    };

    let mut groups: [libc::gid_t; 64] = [0; 64];
    let mut count = 64i32;
    let egid = unsafe { libc::getegid() };

    let rc = unsafe {
        libc::getgrouplist(
            cuser.as_ptr(),
            egid,
            groups.as_mut_ptr(),
            &mut count,
        )
    };

    rc >= 0 && groups[..count as usize].contains(&gid)
}

/// Verifica que el límite de file descriptors es suficiente.
fn check_fd_limit(config: &PreflightConfig, results: &mut Vec<CheckResult>) {
    let mut rlimit = libc::rlimit {
        rlim_cur: 0,
        rlim_max: 0,
    };
    let rc = unsafe { libc::getrlimit(libc::RLIMIT_NOFILE, &mut rlimit) };

    if rc == 0 {
        if rlimit.rlim_cur >= config.min_fd_limit {
            results.push(CheckResult {
                check: "fd_limit",
                passed: true,
                message: format!(
                    "Límite de file descriptors: {} (mínimo requerido: {})",
                    rlimit.rlim_cur, config.min_fd_limit
                ),
            });
        } else {
            results.push(CheckResult {
                check: "fd_limit",
                passed: false,
                message: format!(
                    "Límite de file descriptors ({}) insuficiente. \
                     Mínimo requerido: {}. Configure LimitNOFILE={} en bauth.service.",
                    rlimit.rlim_cur, config.min_fd_limit, config.min_fd_limit
                ),
            });
        }
    } else {
        results.push(CheckResult {
            check: "fd_limit",
            passed: false,
            message: "No se pudo consultar el límite de file descriptors (getrlimit falló).".into(),
        });
    }
}

/// Verifica que hay al menos 1 CPU disponible.
fn check_cpu_available(results: &mut Vec<CheckResult>) {
    let ncpus = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(1);
    if ncpus > 0 {
        results.push(CheckResult {
            check: "cpu_available",
            passed: true,
            message: format!("CPUs disponibles: {}", ncpus),
        });
    } else {
        results.push(CheckResult {
            check: "cpu_available",
            passed: false,
            message: "No se detectaron CPUs disponibles.".into(),
        });
    }
}

/// Verifica que el directorio del socket existe y tiene permisos correctos.
fn check_socket_dir(config: &PreflightConfig, results: &mut Vec<CheckResult>) {
    let socket_path = &config.socket_path;
    let dir = socket_path.parent().unwrap_or(Path::new("/run"));

    match std::fs::metadata(dir) {
        Ok(meta) => {
            if meta.is_dir() {
                results.push(CheckResult {
                    check: "socket_dir_exists",
                    passed: true,
                    message: format!("Directorio del socket existe: {}", dir.display()),
                });
            } else {
                results.push(CheckResult {
                    check: "socket_dir_exists",
                    passed: false,
                    message: format!(
                        "La ruta '{}' existe pero no es un directorio.",
                        dir.display()
                    ),
                });
                return;
            }

            // Verificar permisos (no world-writable)
            use std::os::unix::fs::PermissionsExt;
            let mode = meta.permissions().mode() & 0o777;
            let expected = config.socket_dir_perms;
            // Solo advertir si es más permisivo de lo esperado
            if mode & 0o002 != 0 {
                results.push(CheckResult {
                    check: "socket_dir_not_world_writable",
                    passed: false,
                    message: format!(
                        "El directorio '{}' tiene permisos {:o} (world-writable). \
                         Corrija con: chmod {} {}",
                        dir.display(),
                        mode,
                        expected,
                        dir.display()
                    ),
                });
            } else {
                results.push(CheckResult {
                    check: "socket_dir_not_world_writable",
                    passed: true,
                    message: format!(
                        "Permisos del directorio '{}': {:o} (correcto)",
                        dir.display(),
                        mode
                    ),
                });
            }
        }
        Err(e) => {
            results.push(CheckResult {
                check: "socket_dir_exists",
                passed: false,
                message: format!(
                    "El directorio del socket '{}' no es accesible: {}. \
                     Créelo con: mkdir -p {} && chown :{} {} && chmod {} {}",
                    dir.display(),
                    e,
                    dir.display(),
                    config.socket_group,
                    dir.display(),
                    config.socket_dir_perms,
                    dir.display()
                ),
            });
        }
    }

    // Verificar que se puede crear/borrar el socket (limpiar huérfano)
    if socket_path.exists() {
        // Intentar eliminar socket huérfano
        match std::fs::remove_file(socket_path) {
            Ok(_) => results.push(CheckResult {
                check: "socket_cleanup",
                passed: true,
                message: format!(
                    "Socket huérfano eliminado: {}",
                    socket_path.display()
                ),
            }),
            Err(e) => results.push(CheckResult {
                check: "socket_cleanup",
                passed: false,
                message: format!(
                    "No se pudo eliminar el socket huérfano '{}': {}. \
                     Elimínelo manualmente: rm -f {}",
                    socket_path.display(),
                    e,
                    socket_path.display()
                ),
            }),
        }
    } else {
        results.push(CheckResult {
            check: "socket_cleanup",
            passed: true,
            message: format!(
                "No hay socket huérfano en {}",
                socket_path.display()
            ),
        });
    }
}

/// Verifica que el archivo de configuración existe y es legible.
fn check_config_file(config_path: &PathBuf, results: &mut Vec<CheckResult>) {
    match std::fs::metadata(config_path) {
        Ok(meta) => {
            if meta.is_file() {
                results.push(CheckResult {
                    check: "config_file_exists",
                    passed: true,
                    message: format!(
                        "Archivo de configuración existe: {}",
                        config_path.display()
                    ),
                });
            } else {
                results.push(CheckResult {
                    check: "config_file_exists",
                    passed: false,
                    message: format!(
                        "'{}' no es un archivo regular.",
                        config_path.display()
                    ),
                });
                return;
            }

            // Verificar que es legible
            match std::fs::File::open(config_path) {
                Ok(_) => results.push(CheckResult {
                    check: "config_file_readable",
                    passed: true,
                    message: "Archivo de configuración legible.".into(),
                }),
                Err(e) => results.push(CheckResult {
                    check: "config_file_readable",
                    passed: false,
                    message: format!(
                        "No se puede leer '{}': {}. \
                         Verifique permisos con: ls -l {}",
                        config_path.display(),
                        e,
                        config_path.display()
                    ),
                }),
            }

            // Verificar permisos (no world-readable contiene secretos)
            use std::os::unix::fs::PermissionsExt;
            let mode = meta.permissions().mode() & 0o777;
            if mode & 0o004 != 0 {
                results.push(CheckResult {
                    check: "config_file_secure",
                    passed: false,
                    message: format!(
                        "El archivo de configuración '{}' tiene permisos {:o} \
                         (world-readable — puede exponer secretos). \
                         Corrija: chmod 640 {}",
                        config_path.display(),
                        mode,
                        config_path.display()
                    ),
                });
            } else {
                results.push(CheckResult {
                    check: "config_file_secure",
                    passed: true,
                    message: format!(
                        "Permisos de '{}': {:o} (seguro)",
                        config_path.display(),
                        mode
                    ),
                });
            }
        }
        Err(e) => results.push(CheckResult {
            check: "config_file_exists",
            passed: false,
            message: format!(
                "Archivo de configuración '{}' no encontrado: {}. \
                 Cópielo desde bauth.toml.example y ajuste los valores.",
                config_path.display(),
                e
            ),
        }),
    }
}

/// Verifica binarios del sistema y entropía criptográfica.
fn check_system_binaries(results: &mut Vec<CheckResult>) {
    let required: &[(&str, &str)] = &[
        ("/usr/bin/getent", "getent — consultar usuarios/grupos del sistema"),
    ];

    for (bin_path, description) in required {
        match std::fs::metadata(bin_path) {
            Ok(meta) if meta.is_file() => results.push(CheckResult {
                check: "system_binary",
                passed: true,
                message: format!("Binario disponible: {} ({})", bin_path, description),
            }),
            _ => results.push(CheckResult {
                check: "system_binary",
                passed: false,
                message: format!(
                    "Binario requerido no encontrado: {} ({}).",
                    bin_path, description
                ),
            }),
        }
    }

    // Verificar fuente de entropía (getrandom) — requerida por operaciones criptográficas
    check_crypto_entropy(results);
}

/// Verifica que el sistema tiene fuente de entropía para CSPRNG.
/// Requerido por: rand::OsRng, getrandom (NIST SP 800-90A).
fn check_crypto_entropy(results: &mut Vec<CheckResult>) {
    // Leer solo 32 bytes para verificar disponibilidad del CSPRNG.
    // ⚠️ NUNCA usar std::fs::read() en /dev/urandom — es un device
    // de caracteres infinito que nunca devuelve EOF. read_to_end()
    // aloca sin límite hasta que el OOM killer mata el proceso.
    use std::io::Read;
    let mut buf = [0u8; 32];
    match std::fs::File::open("/dev/urandom")
        .and_then(|mut f| f.read_exact(&mut buf))
    {
        Ok(()) => results.push(CheckResult {
            check: "crypto_entropy",
            passed: true,
            message: "/dev/urandom disponible — CSPRNG operativo (NIST SP 800-90A)".into(),
        }),
        Err(e) => results.push(CheckResult {
            check: "crypto_entropy",
            passed: false,
            message: format!(
                "/dev/urandom no accesible: {}. \
                 Sin entropía, las operaciones criptográficas fallarán. \
                 Verifique que /dev/urandom existe y tiene permisos de lectura.",
                e
            ),
        }),
    }
}

// ─── Helpers para imprimir resultados ──────────────────────────

/// Formatea los resultados de preflight para salida por logs/stderr.
pub fn format_results(results: &[CheckResult]) -> String {
    let mut out = String::from("\n═══ PREFLIGHT — Resultados ═══\n");
    for r in results {
        let icon = if r.passed { "✅" } else { "❌" };
        out.push_str(&format!("{} {}: {}\n", icon, r.check, r.message));
    }
    out
}

/// Formatea SOLO los fallos para salida crítica.
pub fn format_failures(failures: &[CheckResult]) -> String {
    let mut out = String::from("\n═══ PREFLIGHT — FALLOS DETECTADOS ═══\n");
    for f in failures {
        out.push_str(&format!(
            "❌ {}: {}\n   Acción: {}\n",
            f.check,
            f.message,
            extract_action(&f.message)
        ));
    }
    out.push_str("\nCorrija los problemas arriba y reinicie el daemon.\n");
    out
}

fn extract_action(msg: &str) -> &str {
    // Extrae la parte después de "Corrija:" o después de la primera oración
    if let Some(pos) = msg.find("Corrija") {
        &msg[pos..]
    } else if let Some(pos) = msg.find("Créelo") {
        &msg[pos..]
    } else if let Some(pos) = msg.find("Configure") {
        &msg[pos..]
    } else if let Some(pos) = msg.find("Instálelo") {
        &msg[pos..]
    } else {
        "Verifique la configuración y el entorno del sistema."
    }
}

// ─── Tests ──────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_preflight_all_checks_execute() {
        let config = PreflightConfig {
            socket_path: PathBuf::from("/tmp/test-bauth-sock"),
            socket_group: "root".into(), // root siempre existe
            socket_dir_perms: 0o755,
            config_path: None, // sin config → no chequea archivo
            min_fd_limit: 1,   // mínimo posible, siempre pasa
        };

        let result = run(&config);
        // Test unitario: puede pasar o fallar según entorno, pero nunca panickea
        match result {
            Ok(()) => {} // todos los checks pasaron
            Err(failures) => {
                // Verificamos que los fallos tienen mensajes no vacíos
                for f in &failures {
                    assert!(!f.message.is_empty(), "mensaje vacío en: {}", f.check);
                }
            }
        }
    }

    #[test]
    fn test_default_config() {
        let config = PreflightConfig::default();
        assert_eq!(config.socket_path, PathBuf::from("/run/bos/bauth.sock"));
        assert_eq!(config.socket_group, "bosagent");
        assert_eq!(config.min_fd_limit, 4096);
    }

    #[test]
    fn test_format_results_contains_icons() {
        let results = vec![
            CheckResult {
                check: "test_ok",
                passed: true,
                message: "Todo bien".into(),
            },
            CheckResult {
                check: "test_fail",
                passed: false,
                message: "Algo mal".into(),
            },
        ];
        let formatted = format_results(&results);
        assert!(formatted.contains("✅"));
        assert!(formatted.contains("❌"));
    }

    #[test]
    fn test_format_failures_actionable() {
        let failures = vec![CheckResult {
            check: "socket_dir_exists",
            passed: false,
            message: "El directorio '/run/bos' no existe. Créelo con: mkdir -p /run/bos".into(),
        }];
        let formatted = format_failures(&failures);
        assert!(formatted.contains("Acción:"));
        assert!(formatted.contains("mkdir"));
    }

    #[test]
    fn test_preflight_does_not_panic_on_missing_paths() {
        let config = PreflightConfig {
            socket_path: PathBuf::from("/nonexistent/path/that/does/not/exist/sock"),
            socket_group: "probably_doesnt_exist_group_xyz".into(),
            socket_dir_perms: 0o750,
            config_path: Some(PathBuf::from("/nonexistent/config/file.toml")),
            min_fd_limit: 999_999_999, // imposiblemente alto
        };

        // No debe panickear, debe retornar errores
        let result = run(&config);
        assert!(result.is_err(), "Debe fallar con paths inválidos");
        let failures = result.unwrap_err();
        assert!(!failures.is_empty(), "Debe haber al menos un fallo");
    }
}
