/// error.rs — Errores tipados del orquestador bi18n.
/// Propósito: dominio único de errores (C6 ORQUESTA-048).
///   - Sin `unwrap()` ni `expect()` en producción.
///   - Mensajes de error en español (C10).
///   - Derivados de `thiserror` para From/Display automáticos.
/// Dependencias: thiserror, std::path::PathBuf
use std::path::PathBuf;

/// Error principal del daemon bi18n-daemon-orchestrator.
#[derive(Debug, thiserror::Error)]
pub enum Bi18nError {
    // ── Configuración ──────────────────────────────────────────────────────
    #[error("No se pudo leer la configuración '{ruta}': {causa}")]
    ConfigLectura { ruta: PathBuf, causa: String },

    #[error("Configuración TOML inválida en '{ruta}': {causa}")]
    ConfigParseo { ruta: PathBuf, causa: String },

    #[error("Falta el parámetro obligatorio '{parametro}' en la configuración")]
    ConfigFaltante { parametro: &'static str },

    // ── Country-rules TOML ─────────────────────────────────────────────────
    #[error("No se pudo cargar las reglas del país '{iso}': {causa}")]
    PaisNoEncontrado { iso: String, causa: String },

    #[error("TOML de país inválido '{ruta}': {causa}")]
    PaisParseo { ruta: PathBuf, causa: String },

    #[error("Directorio country-rules '{ruta}' no encontrado: {causa}")]
    PaisDirectorio { ruta: PathBuf, causa: String },

    // ── Socket Unix ────────────────────────────────────────────────────────
    #[error("No se pudo vincular al socket '{path}': {causa}")]
    SocketBind { path: PathBuf, causa: String },

    #[error("No se pudieron establecer permisos en '{path}': {causa}")]
    SocketPermisos { path: PathBuf, causa: String },

    // ── Servidor gRPC ──────────────────────────────────────────────────────
    #[error("Error del servidor gRPC: {causa}")]
    GrpcServer { causa: String },

    // ── Formateo ───────────────────────────────────────────────────────────
    #[error("Locale BCP 47 inválido '{locale}': {causa}")]
    LocaleInvalido { locale: String, causa: String },

    #[error("Fecha ISO 8601 inválida '{valor}': {causa}")]
    FechaInvalida { valor: String, causa: String },

    #[error("Zona horaria IANA inválida '{tz}': {causa}")]
    ZonaHorariaInvalida { tz: String, causa: String },

    #[error("Código de formato desconocido '{codigo}'")]
    FormatoDesconocido { codigo: String },

    // ── Validación ─────────────────────────────────────────────────────────
    #[error("Tipo de documento de identidad no soportado para país '{iso}'")]
    DocumentoNoSoportado { iso: String },

    #[error("Número de teléfono inválido '{valor}': {causa}")]
    TelefonoInvalido { valor: String, causa: String },

    // ── Enmascaramiento ────────────────────────────────────────────────────
    #[error("Parámetro de máscara inválido: {causa}")]
    MascaraParametro { causa: String },

    // ── ctx_id (SBOS-049) ──────────────────────────────────────────────────
    #[error("ctx_id ausente o inválido en la solicitud (SBOS-049)")]
    CtxIdAusente,

    // ── Señales del sistema ────────────────────────────────────────────────
    #[error("Error al recibir señal del sistema: {causa}")]
    Signal { causa: String },

    // ── I/O general ───────────────────────────────────────────────────────
    #[error("Error de E/S: {0}")]
    Io(#[from] std::io::Error),
}

/// Alias de resultado para toda función de bi18n.
pub type Resultado<T> = std::result::Result<T, Bi18nError>;
