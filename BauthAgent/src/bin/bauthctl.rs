// ================================================================
// bauthctl — CLI del daemon bAuth v2.0
//
// B0.T02: Entry point + parser de argumentos manual (sin clap,
//         ligero y rápido). 7 subcomandos con 35 operaciones.
// Interface Dual ADR-020: WebSocket RPC sobre /run/bos/bauth.sock.
//
// DOC-SBOS-001 N3: ayuda en español.
// ================================================================

use std::io::{Read, Write};
use std::os::unix::net::UnixStream;
use std::process;
use std::time::Duration;

const VERSION: &str = env!("CARGO_PKG_VERSION");
const DEFAULT_SOCKET_FALLBACK: &str = "/run/bos/bauth.sock";

/// Socket por defecto. Usa env var BAUTH_SOCKET si está definida.
fn default_socket() -> String {
    std::env::var("BAUTH_SOCKET").unwrap_or_else(|_| DEFAULT_SOCKET_FALLBACK.to_string())
}

/// Comando raíz de bauthctl.
struct Cli {
    socket: String,
    command: Command,
}

#[derive(Debug)]
#[allow(dead_code)]
enum Command {
    Role { sub: String, args: Vec<String> },
    User { sub: String, args: Vec<String> },
    Auth { sub: String, args: Vec<String> },
    Ctx { sub: String, args: Vec<String> },
    Policy { sub: String, args: Vec<String> },
    Saga { sub: String, args: Vec<String> },
    Sign { sub: String, args: Vec<String> },
    Tenant { sub: String, args: Vec<String> },
    Sync { sub: String, args: Vec<String> },
    Health,
    Version,
}

fn main() {
    let args: Vec<String> = std::env::args().collect();

    if args.len() < 2 || args.iter().any(|a| a == "--help" || a == "-h") {
        print_usage();
        process::exit(if args.len() < 2 { 1 } else { 0 });
    }

    let cli = match parse(&args) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("Error: {e}");
            process::exit(1);
        }
    };

    let result = match &cli.command {
        Command::Version => {
            println!("bauthctl v{VERSION}");
            return;
        }
        Command::Health => {
            rpc_call(&cli.socket, "bauth.health.check", "{}")
        }
        Command::Role { sub, args } => {
            match sub.as_str() {
                "list" => rpc_call(&cli.socket, "bauth.role.list", "{}"),
                "compute" | "mask" => {
                    let role_id = args.first().map(|s| s.as_str()).unwrap_or("");
                    if role_id.is_empty() {
                        eprintln!("Error: role compute requiere <role_id>");
                        process::exit(1);
                    }
                    rpc_call(&cli.socket, "bauth.role.compute_mask",
                        &format!(r#"{{"role_id":"{}"}}"#, role_id))
                }
                _ => {
                    eprintln!("Error: subcomando 'role {}' no implementado.", sub);
                    eprintln!("Disponibles: list, compute <role_id>");
                    process::exit(1);
                }
            }
        }
        Command::User { sub, args: _ } => {
            match sub.as_str() {
                "list" => rpc_call(&cli.socket, "bauth.user.list", "{}"),
                _ => {
                    eprintln!("Error: subcomando 'user {}' no implementado.", sub);
                    eprintln!("Disponibles: list");
                    process::exit(1);
                }
            }
        }
        Command::Auth { sub, args } => {
            match sub.as_str() {
                "login" => {
                    let username = args.first().map(|s| s.as_str()).unwrap_or("");
                    if username.is_empty() {
                        eprintln!("Error: auth login requiere <username>");
                        process::exit(1);
                    }
                    // SEC-004 FIX: contraseña sin eco (OWASP ASVS V2.7.1)
                    // B-02 FIX: unsafe scope mínimo — solo las syscalls libc
                    eprint!("Contraseña: ");
                    use std::io::{Write, BufRead, BufReader};
                    std::io::stderr().flush().ok();
                    let saved = unsafe {
                        let mut termios: libc::termios = std::mem::zeroed();
                        libc::tcgetattr(0, &mut termios);
                        let saved = termios;
                        let mut noecho = termios;
                        noecho.c_lflag &= !libc::ECHO;
                        libc::tcsetattr(0, libc::TCSANOW, &noecho);
                        saved
                    };
                    let password = BufReader::new(std::io::stdin().lock()).lines().next()
                        .and_then(|l| l.ok())
                        .unwrap_or_default();
                    unsafe { libc::tcsetattr(0, libc::TCSANOW, &saved); }
                    eprintln!();
                    if password.is_empty() {
                        eprintln!("Error: contraseña requerida");
                        process::exit(1);
                    }
                    let payload = serde_json::json!({
                        "saga": "auth.password.login",
                        "ctx_id": format!("bauthctl-{}", std::process::id()),
                        "params": {
                            "username": username,
                            "password": password,
                            "client_ip": "127.0.0.1",
                            "device_fingerprint": "bauthctl-cli"
                        }
                    });
                    rpc_call(&cli.socket, "bauth.saga.execute", &payload.to_string())
                }
                "mfa" => {
                    let code = args.first().map(|s| s.as_str()).unwrap_or("");
                    if code.is_empty() {
                        eprintln!("Error: auth mfa requiere <totp_code>");
                        process::exit(1);
                    }
                    rpc_call(&cli.socket, "bauth.saga.execute",
                        &format!(r#"{{"saga":"auth.mfa.totp","ctx_id":"bauthctl-{}","params":{{"totp_code":"{}"}}}}"#,
                            std::process::id(), code))
                }
                _ => {
                    eprintln!("Error: subcomando 'auth {}' no implementado.", sub);
                    eprintln!("Disponibles: login <user> <pass>, mfa <code>");
                    process::exit(1);
                }
            }
        }
        Command::Ctx { sub, args } => {
            match sub.as_str() {
                "validate" => {
                    let ctx_id = args.first().map(|s| s.as_str()).unwrap_or("");
                    if ctx_id.is_empty() {
                        eprintln!("Error: ctx validate requiere <ctx_id>");
                        process::exit(1);
                    }
                    rpc_call(&cli.socket, "bauth.ctx.validate",
                        &format!(r#"{{"ctx_id":"{}"}}"#, ctx_id))
                }
                _ => {
                    eprintln!("Error: subcomando 'ctx {}' no implementado.", sub);
                    eprintln!("Disponibles: validate <ctx_id>");
                    process::exit(1);
                }
            }
        }
        Command::Saga { sub, args } => {
            match sub.as_str() {
                "list" => rpc_call(&cli.socket, "bauth.saga.list", "{}"),
                "execute" => {
                    let saga_name = args.first().map(|s| s.as_str()).unwrap_or("");
                    if saga_name.is_empty() {
                        eprintln!("Error: saga execute requiere <nombre_saga>");
                        process::exit(1);
                    }
                    rpc_call(&cli.socket, "bauth.saga.execute",
                        &format!(r#"{{"saga":"{}","ctx_id":"bauthctl-{}","params":{{}}}}"#,
                            saga_name, std::process::id()))
                }
                _ => {
                    eprintln!("Error: subcomando 'saga {}' no implementado.", sub);
                    eprintln!("Disponibles: list, execute <nombre>");
                    process::exit(1);
                }
            }
        }
        Command::Policy { sub, args } => {
            match sub.as_str() {
                "eval" => {
                    let app: i16 = args.first().and_then(|s| s.parse().ok()).unwrap_or(1);
                    let group: i16 = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(1);
                    let atom: i32 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(1);
                    rpc_call(&cli.socket, "bauth.policy.evaluate",
                        &format!(r#"{{"app_code":{},"group_code":{},"atom_code":{}}}"#, app, group, atom))
                }
                _ => {
                    eprintln!("Error: subcomando 'policy {}' no implementado.", sub);
                    eprintln!("Disponibles: eval <app_code> <group_code> <atom_code>");
                    process::exit(1);
                }
            }
        }
        Command::Sign { sub, args } => {
            match sub.as_str() {
                "internal" => {
                    let payload = args.first().map(|s| s.as_str()).unwrap_or("");
                    if payload.is_empty() {
                        eprintln!("Error: sign internal requiere <payload>");
                        process::exit(1);
                    }
                    rpc_call(&cli.socket, "bauth.sign.internal",
                        &format!(r#"{{"payload":"{}"}}"#, payload))
                }
                _ => {
                    eprintln!("Error: subcomando 'sign {}' no implementado.", sub);
                    eprintln!("Disponibles: internal <payload>");
                    process::exit(1);
                }
            }
        }
        Command::Tenant { sub, args: _ } => {
            match sub.as_str() {
                "list" => rpc_call(&cli.socket, "bauth.tenant.list", "{}"),
                _ => {
                    eprintln!("Error: subcomando 'tenant {}' no implementado.", sub);
                    eprintln!("Disponibles: list");
                    process::exit(1);
                }
            }
        }
        Command::Sync { sub, args: _ } => {
            match sub.as_str() {
                "reconcile" => rpc_call(&cli.socket, "bauth.sync.reconcile", "{}"),
                "status" => rpc_call(&cli.socket, "bauth.sync.status", "{}"),
                _ => {
                    eprintln!("Error: subcomando 'sync {}' no implementado.", sub);
                    eprintln!("Disponibles: reconcile, status");
                    process::exit(1);
                }
            }
        }
    };

    match result {
        Ok(resp) => {
            // Pretty-print si es JSON válido
            if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&resp) {
                println!("{}", serde_json::to_string_pretty(&parsed).unwrap_or(resp));
            } else {
                println!("{}", resp);
            }
        }
        Err(e) => { eprintln!("Error: {}", e); process::exit(1); }
    }
}

/// Construye y envía una request JSON-RPC 2.0 al daemon vía Unix socket.
/// method: ej "bauth.health.check"
/// params_json: JSON string con los params (ej: "{}" o '{"role_id":"uuid"}')
fn rpc_call(socket_path: &str, method: &str, params_json: &str) -> Result<String, String> {
    let params: serde_json::Value = serde_json::from_str(params_json)
        .map_err(|e| format!("params JSON inválido: {}", e))?;

    let request = serde_json::json!({
        "jsonrpc": "2.0",
        "method": method,
        "params": params,
        "id": 1
    });

    let request_str = serde_json::to_string(&request)
        .map_err(|e| format!("error al serializar request: {}", e))?;

    let mut stream = UnixStream::connect(socket_path)
        .map_err(|e| format!("no se pudo conectar a {}: {}", socket_path, e))?;
    stream.set_read_timeout(Some(Duration::from_secs(10)))
        .map_err(|e| format!("error de timeout: {}", e))?;
    stream.write_all(request_str.as_bytes())
        .map_err(|e| format!("error al enviar: {}", e))?;
    stream.write_all(b"\n")
        .map_err(|e| format!("error al enviar newline: {}", e))?;

    let mut response = String::new();
    stream.read_to_string(&mut response)
        .map_err(|e| format!("error al leer respuesta: {}", e))?;
    Ok(response)
}

fn parse(args: &[String]) -> Result<Cli, String> {
    let mut socket = default_socket();
    let mut i = 1;

    while i < args.len() {
        match args[i].as_str() {
            "--socket" | "-s" => {
                i += 1;
                socket = args.get(i).ok_or("--socket requiere valor")?.clone();
            }
            "role" => return Ok(Cli { socket, command: Command::Role { sub: args.get(i+1).cloned().unwrap_or_default(), args: args[i+2..].to_vec() }}),
            "user" => return Ok(Cli { socket, command: Command::User { sub: args.get(i+1).cloned().unwrap_or_default(), args: args[i+2..].to_vec() }}),
            "auth" => return Ok(Cli { socket, command: Command::Auth { sub: args.get(i+1).cloned().unwrap_or_default(), args: args[i+2..].to_vec() }}),
            "ctx" | "context" => return Ok(Cli { socket, command: Command::Ctx { sub: args.get(i+1).cloned().unwrap_or_default(), args: args[i+2..].to_vec() }}),
            "policy" => return Ok(Cli { socket, command: Command::Policy { sub: args.get(i+1).cloned().unwrap_or_default(), args: args[i+2..].to_vec() }}),
            "saga" => return Ok(Cli { socket, command: Command::Saga { sub: args.get(i+1).cloned().unwrap_or_default(), args: args[i+2..].to_vec() }}),
            "sign" => return Ok(Cli { socket, command: Command::Sign { sub: args.get(i+1).cloned().unwrap_or_default(), args: args[i+2..].to_vec() }}),
            "tenant" => return Ok(Cli { socket, command: Command::Tenant { sub: args.get(i+1).cloned().unwrap_or_default(), args: args[i+2..].to_vec() }}),
            "sync" => return Ok(Cli { socket, command: Command::Sync { sub: args.get(i+1).cloned().unwrap_or_default(), args: args[i+2..].to_vec() }}),
            "health" => return Ok(Cli { socket, command: Command::Health }),
            "version" | "--version" | "-V" => return Ok(Cli { socket, command: Command::Version }),
            _ => return Err(format!("comando desconocido: '{}'. Use --help.", args[i])),
        }
        i += 1;
    }

    Err("ningún comando especificado. Use --help.".to_string())
}

fn print_usage() {
    println!(
        r"bauthctl v{VERSION} — SBOS Identity Core CLI

USO:
    bauthctl [--socket <path>] <comando> [args...]

COMANDOS:
  role     Gestión de roles (RolTemplate)
  user     Gestión de usuarios (UserTemplate)
  auth     Operaciones de autenticación (login, mfa)
  policy   Evaluación de políticas de acceso (eval)
  saga     Ejecución y consulta de sagas
  ctx      Gestión del Context Plane (ctx_id)
  sign     Firma digital (interna y externa)
  tenant   Gestión de tenants
  sync     Sincronización y reconcile
  health   Verificar estado del daemon
  version  Mostrar versión

OPCIONES:
  --socket, -s  Ruta del Unix socket (default: /run/bos/bauth.sock)
  --help, -h    Mostrar esta ayuda

EJEMPLOS:
  bauthctl role create --file=rol_cajero.yml
  bauthctl role list --tenant=skull
  bauthctl user assign-role --user <uuid> --role ROL-CAJERO
  bauthctl ctx validate ctx-abc123
  bauthctl sign external-factura --file factura.xml
  bauthctl tenant create acme --legal-name 'ACME S.A.'
  bauthctl sync reconcile
  bauthctl health

Documentación: BAUTH-CATALOGO-ROLES-EMPRESARIALES.md v2.0
"
    );
}
