# A.03 — Interfaz gRPC de bi18n (Interface Triple C11)

**Tipo:** A — especificación de interfaz
**Versión:** 1.0.0
**Fecha:** 2026-07-16
**Respalda a:** [1.01 bi18n Arquitectura v1.3.0](../1.01_MANUAL-BI18N-ARQUITECTURA-v1.2.md)
**Norma base:** C11 ORQUESTA-048 — Interface Triple obligatoria
**Código generado desde:** `proto/bi18n.proto` (compilado con `tonic-build` en `build.rs`)

---

## §1 Propósito y posición en la Interface Triple

La norma C11 (ORQUESTA-048) exige que todo componente exponga sus capacidades por **tres vías
con paridad de capacidades**:

| # | Vía | bi18n |
|---|---|---|
| 1 | **Sockets + JSON-RPC 2.0** | `/run/bos/bi18n.sock` — WebSocket RPC + JSON-RPC 2.0 newline-delimited |
| 2 | **JSON-RPC sobre Unix socket** | mismo socket, mismo protocolo, consumidores daemon-a-daemon |
| 3 | **gRPC** | `/run/bos/bi18n-grpc.sock` — gRPC sobre Unix domain socket (sin TCP) |

El gRPC de bi18n expone exactamente las mismas capacidades que el JSON-RPC. Cualquier método
disponible por JSON-RPC tiene su RPC equivalente en el proto. No hay funcionalidad exclusiva
de una sola vía.

---

## §2 Transporte — gRPC sobre Unix domain socket

### 2.1 Por qué Unix socket y no TCP

SBOS-050 P9 prohíbe HTTP/TCP entre daemons. gRPC usa HTTP/2 como transporte, pero puede
correr sobre cualquier stream bidireccional — incluyendo Unix domain sockets. `tonic` (la
librería gRPC estándar de Rust) soporta esto mediante `tokio::net::UnixListener`.

```
Daemon hermano (cliente tonic)          bi18nd (servidor tonic)
  │                                          │
  │  gRPC/HTTP2 sobre /run/bos/bi18n-grpc.sock
  │◄────────────────────────────────────────►│
  │  (Unix domain socket — sin TCP, sin red) │
```

### 2.2 Socket path y permisos

```
/run/bos/bi18n-grpc.sock   # creado por bi18nd al arrancar
Propietario: root:bos
Permisos:    0660
```

Mismo modelo de permisos que `/run/bos/bi18n.sock`. Solo procesos del grupo `bos` pueden conectarse.

### 2.3 Cómo conecta un cliente daemon

```rust
// Fragmento de cliente en otro daemon SBOS (ej: bAuth)
use tonic::transport::{Endpoint, Uri};
use tower::service_fn;
use tokio::net::UnixStream;

let channel = Endpoint::try_from("http://[::]:0")?
    .connect_with_connector(service_fn(|_: Uri| {
        UnixStream::connect("/run/bos/bi18n-grpc.sock")
    }))
    .await?;

let mut client = bi18n_v1::attr_service_client::AttrServiceClient::new(channel);
```

El `"http://[::]:0"` es un placeholder requerido por la API de tonic — la conexión real
se establece sobre el Unix socket, no sobre TCP.

---

## §3 Definición proto canónica

**Archivo:** `proto/bi18n.proto`
**Package:** `bi18n.v1`
**Opción Rust:** `package bi18n.v1;` → crate `bi18n_v1` (generado por prost)

```protobuf
syntax = "proto3";

package bi18n.v1;

option java_package = "com.sbos.bi18n.v1";

// ─────────────────────────────────────────────────────────────────────────────
// TIPOS COMPARTIDOS
// ─────────────────────────────────────────────────────────────────────────────

// Configuración regional resuelta para una operación.
// En producción bAuth la envía en cada request; en MVP se omite (bi18n usa
// la config estática de bi18n.toml).
message RegionalConfig {
  string locale   = 1;  // BCP 47 — ej: "es-BO", "en-US"
  string timezone = 2;  // IANA   — ej: "America/La_Paz"
  string currency = 3;  // ISO 4217 — ej: "BOB", "USD"
  string country  = 4;  // ISO 3166-1 alpha-2 — ej: "BO", "US"
}

// Contexto de operación — ctx_id obligatorio (SBOS-049).
message OperationContext {
  string ctx_id    = 1;  // UUID v4 — identificador de traza distribuida
  string tenant_id = 2;  // Identificador del tenant (puede ser vacío en MVP)
  optional RegionalConfig regional = 3;  // Enviado por bAuth en producción
}

// ─────────────────────────────────────────────────────────────────────────────
// HEALTH SERVICE
// ─────────────────────────────────────────────────────────────────────────────

service HealthService {
  // Verifica que el daemon está activo y sus recursos cargados.
  rpc Check(HealthCheckRequest) returns (HealthCheckResponse);
}

message HealthCheckRequest {
  string ctx_id = 1;
}

message HealthCheckResponse {
  // "ok" | "degradado" | "error"
  string status       = 1;
  string version      = 2;  // versión del daemon
  uint32 paises_cargados = 3;  // número de country-rules TOML en caché
  string mensaje      = 4;  // descripción en español
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMAT SERVICE
// ─────────────────────────────────────────────────────────────────────────────

service FormatService {
  // Formatea una fecha/hora con el locale del tenant vía ICU4X + jiff.
  rpc FormatDate(FormatDateRequest) returns (FormatDateResponse);

  // Formatea un número decimal con separadores del locale del tenant vía ICU4X.
  rpc FormatNumber(FormatNumberRequest) returns (FormatNumberResponse);

  // Formatea un monto monetario con símbolo y decimales del tenant.
  rpc FormatMoney(FormatMoneyRequest) returns (FormatMoneyResponse);

  // Formatea una dirección postal según el país del tenant (Post-MVP).
  rpc FormatAddress(FormatAddressRequest) returns (FormatAddressResponse);
}

// Granularidad de fecha — afecta el formatter ICU4X seleccionado.
enum DateGranularity {
  DATE_GRANULARITY_UNSPECIFIED = 0;
  DATE_TIME   = 1;  // created_at → "16 de julio de 2026, 05:00 AM"
  DATE_ONLY   = 2;  // birth_date → "16 de julio de 2026"
  YEAR_MONTH  = 3;  // credit_card_expiry → "julio 2026"
  YEAR_ONLY   = 4;  // anio_vehiculo → "2026"
  TIME_ONLY   = 5;  // horario → "05:00 AM"
}

message FormatDateRequest {
  OperationContext ctx      = 1;
  // Timestamp ISO 8601 / RFC 3339 en UTC. Ej: "2026-07-16T09:00:00Z"
  string iso_datetime       = 2;
  DateGranularity granularity = 3;
}

message FormatDateResponse {
  // Fecha formateada en el locale del tenant. Ej: "16 de julio de 2026"
  string display = 1;
}

message FormatNumberRequest {
  OperationContext ctx = 1;
  // Representación canónica del número (punto como separador decimal).
  // Ej: "1500.50"
  string value         = 2;
  uint32 decimal_places = 3;  // 0 = sin decimales
}

message FormatNumberResponse {
  // Número formateado. Ej (es-BO): "1.500,50" · Ej (en-US): "1,500.50"
  string display = 1;
}

message FormatMoneyRequest {
  OperationContext ctx = 1;
  // Monto en representación canónica. Ej: "1500.50"
  string amount        = 2;
  // ISO 4217 — si está vacío usa el currency del RegionalConfig del tenant.
  string currency_code = 3;
}

message FormatMoneyResponse {
  // Monto formateado con símbolo local. Ej (es-BO): "Bs. 1.500,50"
  string display       = 1;
  // Símbolo local de la moneda. Ej: "Bs.", "$", "€"
  string symbol_local  = 2;
}

message FormatAddressRequest {
  OperationContext ctx = 1;
  // Campos de dirección en clave-valor libre. El orden de presentación
  // lo define el [postal] del country-rules/{iso}.toml del tenant.
  map<string, string> fields = 2;
}

message FormatAddressResponse {
  // Dirección formateada en una sola línea según el país.
  string display_line  = 1;
  // Dirección formateada en múltiples líneas (cada elemento = una línea).
  repeated string display_multiline = 2;
}

// ─────────────────────────────────────────────────────────────────────────────
// VALIDATE SERVICE
// ─────────────────────────────────────────────────────────────────────────────

service ValidateService {
  // Valida un documento de identidad nacional contra el TOML del país del tenant.
  rpc ValidateNationalId(ValidateNationalIdRequest) returns (ValidateNationalIdResponse);

  // Valida un número de teléfono E.164 vía libphonenumber (phonenumber crate).
  rpc ValidatePhone(ValidatePhoneRequest) returns (ValidatePhoneResponse);

  // Valida una dirección de correo electrónico vía RFC 5321.
  rpc ValidateEmail(ValidateEmailRequest) returns (ValidateEmailResponse);
}

// Tipo de documento de identidad nacional.
enum NationalIdKind {
  NATIONAL_ID_KIND_UNSPECIFIED = 0;
  CI   = 1;   // Cédula de identidad (Bolivia, Argentina...)
  NIT  = 2;   // Número de identificación tributaria (Bolivia)
  CPF  = 3;   // Cadastro de Pessoas Físicas (Brasil)
  CNPJ = 4;   // Cadastro Nacional da Pessoa Jurídica (Brasil)
  DNI  = 5;   // Documento Nacional de Identidad (Argentina, Perú, España)
  CUIT = 6;   // Clave Única de Identificación Tributaria (Argentina)
  PASSPORT = 7; // Pasaporte ICAO
}

message ValidateNationalIdRequest {
  OperationContext ctx = 1;
  NationalIdKind kind  = 2;
  string value         = 3;  // Valor a validar. Ej: "7654321-LP"
}

message ValidateNationalIdResponse {
  bool valid                    = 1;
  // Valor normalizado (ej: uppercase, sin espacios). Vacío si es inválido.
  string normalized             = 2;
  repeated string errores       = 3;  // Mensajes de error en español si !valid
}

message ValidatePhoneRequest {
  OperationContext ctx = 1;
  // Número en formato E.164 o nacional. Ej: "+59171234567" o "71234567"
  string value         = 2;
  // ISO 3166-1 alpha-2 para parseo de número nacional. Ej: "BO"
  string country_hint  = 3;
}

message ValidatePhoneResponse {
  bool valid           = 1;
  // Número normalizado en E.164. Ej: "+59171234567"
  string e164          = 2;
  repeated string errores = 3;
}

message ValidateEmailRequest {
  OperationContext ctx = 1;
  string value         = 2;
}

message ValidateEmailResponse {
  bool valid              = 1;
  // Email normalizado (lowercase, sin espacios). Vacío si es inválido.
  string normalized       = 2;
  repeated string errores = 3;
}

// ─────────────────────────────────────────────────────────────────────────────
// MASK SERVICE
// ─────────────────────────────────────────────────────────────────────────────

service MaskService {
  // Enmascara un valor con una estrategia explícita.
  rpc MaskValue(MaskValueRequest) returns (MaskValueResponse);

  // Enmascara todos los campos PII detectados en un texto libre.
  rpc MaskPii(MaskPiiRequest) returns (MaskPiiResponse);
}

// Estrategia de enmascaramiento — espejo del enum MaskStrategy de Rust.
// Wire format documentado en §7.3 del manual de arquitectura.
enum MaskStrategyProto {
  MASK_STRATEGY_NONE         = 0;  // Sin máscara → valor original
  MASK_STRATEGY_FULL         = 1;  // "****"
  MASK_STRATEGY_PARTIAL      = 2;  // Últimos N visibles → "****321-LP" (N=4)
  MASK_STRATEGY_PREFIX       = 3;  // Primeros N visibles → "7654***"   (N=4)
  MASK_STRATEGY_BOTH         = 4;  // Extremos visibles → "76****LP"   (P=2,S=2)
  MASK_STRATEGY_COUNTRY_RULE = 5;  // Usa la estrategia definida en country-rules TOML
}

message MaskValueRequest {
  OperationContext ctx    = 1;
  string value            = 2;
  MaskStrategyProto strategy = 3;
  // Parámetro N para PARTIAL y PREFIX (caracteres visibles desde el extremo).
  uint32 n                = 4;
  // Parámetros P y S para BOTH (visibles desde prefijo y sufijo).
  uint32 prefix_visible   = 5;
  uint32 suffix_visible   = 6;
  // Tipo de documento para COUNTRY_RULE — necesario para buscar la estrategia en TOML.
  NationalIdKind kind_hint = 7;
}

message MaskValueResponse {
  string masked = 1;
}

message MaskPiiRequest {
  OperationContext ctx = 1;
  // Texto libre que puede contener emails, teléfonos, IDs nacionales.
  string text          = 2;
  // Si true, también enmascara emails y teléfonos detectados automáticamente.
  bool mask_emails     = 3;
  bool mask_phones     = 4;
}

message MaskPiiResponse {
  // Texto con PII enmascarado.
  string redacted = 1;
  // Número de campos PII detectados y enmascarados.
  uint32 campos_redactados = 2;
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCALE SERVICE
// ─────────────────────────────────────────────────────────────────────────────

service LocaleService {
  // Resuelve el RegionalConfig para un tenant/branch/user según la jerarquía
  // definida en §5.1 del manual: user → branch → tenant → default.
  rpc ResolveLocale(ResolveLocaleRequest) returns (ResolveLocaleResponse);
}

message ResolveLocaleRequest {
  OperationContext ctx = 1;
  // Identificadores opcionales para la jerarquía de resolución.
  string tenant_id  = 2;
  string branch_id  = 3;
  string user_id    = 4;
}

message ResolveLocaleResponse {
  RegionalConfig config = 1;
  // Nivel desde el que se resolvió la config ("user"|"branch"|"tenant"|"default").
  string fuente         = 2;
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTR SERVICE
// ─────────────────────────────────────────────────────────────────────────────

service AttrService {
  // Pipeline completo: raw → validate → transform* → format → mask → AttrResult.
  // Este es el método principal que bAuth invoca para CI/NIT/teléfono/email.
  rpc Pipeline(AttrPipelineRequest) returns (AttrPipelineResponse);

  // Construye un AttrResult aplicando solo las etapas especificadas.
  rpc Build(AttrBuildRequest) returns (AttrBuildResponse);
}

// Transformaciones de texto aplicadas en orden antes del format.
enum Transform {
  TRANSFORM_UNSPECIFIED  = 0;
  TRANSFORM_UPPERCASE    = 1;
  TRANSFORM_LOWERCASE    = 2;
  TRANSFORM_TITLECASE    = 3;
  TRANSFORM_TRIM         = 4;
  TRANSFORM_STRIP_HYPHEN = 5;
  TRANSFORM_STRIP_SPACES = 6;
  TRANSFORM_STRIP_ACCENTS = 7;
  TRANSFORM_DIGITS_ONLY  = 8;
  TRANSFORM_ALPHA_ONLY   = 9;
  TRANSFORM_PAD_LEFT     = 10;
  TRANSFORM_PAD_RIGHT    = 11;
}

message AttrPipelineRequest {
  OperationContext ctx        = 1;
  // Clave del atributo — nombre semántico. Ej: "CI", "NIT", "telefono"
  string key                  = 2;
  // Valor crudo del atributo. Ej: "7654321-lp"
  string value                = 3;
  // Código display_format para validación (18 códigos canónicos).
  // Ej: "ID_BO", "TAX_BO", "E164". Vacío = sin validación.
  string validate_format      = 4;
  // Transformaciones a aplicar en orden.
  repeated Transform transforms = 5;
  // Código display_format para presentación final.
  string format_code          = 6;
  // Estrategia de máscara PII.
  MaskStrategyProto mask_strategy = 7;
  uint32 mask_n               = 8;   // para PARTIAL / PREFIX
  uint32 mask_prefix_visible  = 9;   // para BOTH
  uint32 mask_suffix_visible  = 10;  // para BOTH
}

message AttrPipelineResponse {
  // Valor crudo original.
  string raw          = 1;
  // true si la validación pasó (o si no se solicitó validación).
  bool valid          = 2;
  // Valor después de transformaciones.
  string transformed  = 3;
  // Valor formateado para presentación.
  string display      = 4;
  // Valor enmascarado para logs / UI con privacidad.
  string masked       = 5;
  // Etiqueta de enum si el valor es un enum de negocio (gender, marital_status...).
  string enum_label   = 6;
  // Errores de validación en español.
  repeated string errores_validacion = 7;
}

message AttrBuildRequest {
  OperationContext ctx        = 1;
  string key                  = 2;
  string value                = 3;
  // Etapas a ejecutar (bitmask booleano en proto: campos separados).
  bool ejecutar_validate      = 4;
  string validate_format      = 5;
  bool ejecutar_transforms    = 6;
  repeated Transform transforms = 7;
  bool ejecutar_format        = 8;
  string format_code          = 9;
  bool ejecutar_mask          = 10;
  MaskStrategyProto mask_strategy = 11;
  uint32 mask_n               = 12;
  uint32 mask_prefix_visible  = 13;
  uint32 mask_suffix_visible  = 14;
}

message AttrBuildResponse {
  AttrPipelineResponse result = 1;
}

// ─────────────────────────────────────────────────────────────────────────────
// ENUM SERVICE
// ─────────────────────────────────────────────────────────────────────────────

service EnumService {
  // Traduce un valor de enum de negocio a su etiqueta localizada.
  // Ej: (gender, "M", es-BO) → "Masculino"
  rpc Display(EnumDisplayRequest) returns (EnumDisplayResponse);
}

message EnumDisplayRequest {
  OperationContext ctx  = 1;
  // Nombre del enum de negocio. Ej: "gender", "marital_status", "employment_type"
  string enum_name      = 2;
  // Valor canónico. Ej: "M", "MARRIED", "FULL_TIME"
  string value          = 3;
}

message EnumDisplayResponse {
  // Etiqueta localizada en el locale del tenant. Ej: "Masculino"
  string label          = 1;
  // true si el valor fue encontrado en los TOML del país.
  bool found            = 2;
  // Fallback: valor original si !found.
  string fallback       = 3;
}
```

---

## §4 Estructura de archivos proto y build

### 4.1 Ubicación en el árbol

```
Bi18nAgent/
├── proto/
│   └── bi18n.proto          # definición canónica (este anexo)
├── build.rs                 # compilación proto con tonic-build
└── src/
    └── server/
        └── grpc.rs          # implementación del servidor gRPC
```

### 4.2 `build.rs`

```rust
/// build.rs — compila proto/bi18n.proto en código Rust antes de compilar el crate.
/// Genera el módulo bi18n_v1 con los tipos prost + los traits de servicio tonic.
fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::configure()
        .build_server(true)   // genera traits de servidor para bi18nd
        .build_client(true)   // genera cliente para tests y i18nctl
        .out_dir("src/generated/")
        .compile_protos(&["proto/bi18n.proto"], &["proto/"])?;
    Ok(())
}
```

### 4.3 Dependencias Cargo.toml (sección [dependencies] + [build-dependencies])

```toml
# gRPC — Interface Triple C11
tonic      = { version = "0.12", features = ["transport"] }
prost      = "0.13"
# Para conectar el servidor gRPC al Unix socket
tokio-stream = { version = "0.1", features = ["net"] }

[build-dependencies]
tonic-build = "0.12"
```

---

## §5 Implementación del servidor gRPC (patrón canónico)

### 5.1 Módulo `src/server/grpc.rs`

```rust
/// Servidor gRPC de bi18n sobre Unix domain socket.
/// Implementa los 7 servicios definidos en proto/bi18n.proto.
/// Transporte: /run/bos/bi18n-grpc.sock (sin TCP — SBOS-050 P9).

use std::path::PathBuf;
use tokio::net::UnixListener;
use tokio_stream::wrappers::UnixListenerStream;
use tonic::transport::Server;

use crate::generated::bi18n_v1::{
    health_service_server::HealthServiceServer,
    format_service_server::FormatServiceServer,
    validate_service_server::ValidateServiceServer,
    mask_service_server::MaskServiceServer,
    locale_service_server::LocaleServiceServer,
    attr_service_server::AttrServiceServer,
    enum_service_server::EnumServiceServer,
};

/// Inicia el servidor gRPC y lo mantiene activo hasta que `shutdown` señale.
pub async fn iniciar_grpc(
    socket_path: PathBuf,
    ctx: crate::server::ServerContext,
    mut shutdown: tokio::sync::watch::Receiver<bool>,
) -> Result<(), crate::error::Bi18nError> {
    // Eliminar socket previo si existe (arranque limpio).
    let _ = tokio::fs::remove_file(&socket_path).await;

    let listener = UnixListener::bind(&socket_path)
        .map_err(|e| crate::error::Bi18nError::SocketBind {
            path: socket_path.clone(),
            causa: e.to_string(),
        })?;

    // Permisos 0660 — solo grupo bos puede conectarse.
    tokio::fs::set_permissions(
        &socket_path,
        std::os::unix::fs::PermissionsExt::from_mode(0o660),
    ).await.map_err(|e| crate::error::Bi18nError::SocketPermisos {
        path: socket_path.clone(),
        causa: e.to_string(),
    })?;

    tracing::info!(
        "gRPC escuchando en {:?} (Interface Triple C11)",
        socket_path
    );

    let incoming = UnixListenerStream::new(listener);

    Server::builder()
        .add_service(HealthServiceServer::new(ctx.clone()))
        .add_service(FormatServiceServer::new(ctx.clone()))
        .add_service(ValidateServiceServer::new(ctx.clone()))
        .add_service(MaskServiceServer::new(ctx.clone()))
        .add_service(LocaleServiceServer::new(ctx.clone()))
        .add_service(AttrServiceServer::new(ctx.clone()))
        .add_service(EnumServiceServer::new(ctx.clone()))
        .serve_with_incoming_shutdown(incoming, async move {
            let _ = shutdown.changed().await;
        })
        .await
        .map_err(|e| crate::error::Bi18nError::GrpcServer { causa: e.to_string() })
}
```

### 5.2 Arranque en `main.rs` — los tres servidores en paralelo

```rust
// En main.rs — los tres servidores (Interface Triple) se arrancan juntos.
tokio::select! {
    r = server::unix_socket::iniciar_jsonrpc(cfg.socket_path.clone(), ctx.clone(), sd_rx.clone()) =>
        tracing::error!("JSON-RPC terminó: {:?}", r),
    r = server::grpc::iniciar_grpc(cfg.grpc_socket_path.clone(), ctx.clone(), sd_rx.clone()) =>
        tracing::error!("gRPC terminó: {:?}", r),
    _ = signal::manejar_sighup(loader.clone(), activas.clone()) => {},
    _ = signal::manejar_sigterm(sd_tx.clone()) => {},
}
```

### 5.3 `ServerContext` — compartido entre los tres servidores

El mismo `ServerContext` que usa el servidor JSON-RPC se pasa al gRPC. Contiene
`Arc<CountryRulesLoader>`, `Arc<dyn RegionalConfigResolver>`, y los clientes ICU4X/jiff.
Esto garantiza paridad de capacidades: los dos servidores usan exactamente el mismo código
de dominio, solo el transporte difiere.

---

## §6 Tabla de paridad JSON-RPC ↔ gRPC

| Método JSON-RPC | Método gRPC | Servicio proto | Fase |
|---|---|---|---|
| `bi18n.health.check` | `HealthService.Check` | HealthService | 5 |
| `bi18n.format.date` | `FormatService.FormatDate` | FormatService | 1 |
| `bi18n.format.number` | `FormatService.FormatNumber` | FormatService | 1 |
| `bi18n.format.money` | `FormatService.FormatMoney` | FormatService | 1 |
| `bi18n.validate.national_id` | `ValidateService.ValidateNationalId` | ValidateService | 1 |
| `bi18n.mask.value` | `MaskService.MaskValue` | MaskService | 1 |
| `bi18n.mask.pii` | `MaskService.MaskPii` | MaskService | 1 |
| `bi18n.locale.resolve` | `LocaleService.ResolveLocale` | LocaleService | 1 |
| `bi18n.attr.pipeline` | `AttrService.Pipeline` | AttrService | 7 |
| `bi18n.attr.build` | `AttrService.Build` | AttrService | 7 |
| `bi18n.validate.phone` | `ValidateService.ValidatePhone` | ValidateService | 4 |
| `bi18n.validate.email` | `ValidateService.ValidateEmail` | ValidateService | 4 |
| `bi18n.format.address` | `FormatService.FormatAddress` | FormatService | Post-MVP |
| `bi18n.enum.display` | `EnumService.Display` | EnumService | 2 |

**Invariante:** todo método añadido a JSON-RPC DEBE añadirse simultáneamente al proto.
No existe funcionalidad exclusiva de una sola vía (C11: paridad de capacidades).

---

## §7 Verificación C11 en el Revisor y el Testeador

### 7.1 Lo que el Revisor verifica (estático)

```bash
# Las tres vías presentes en el código:
grep -r "unix_socket" src/server/     # Vía 1+2: JSON-RPC sobre Unix socket
grep -r "iniciar_grpc" src/           # Vía 3: gRPC
grep -r "bi18n-grpc.sock" src/        # Socket path correcto sin TCP

# Sin HTTP plano (BLOQUEANTE):
grep -rn "TcpListener\|HttpServer\|actix_web\|axum" src/  # debe dar 0 resultados
```

### 7.2 Lo que el Testeador verifica (VPS — empírico)

Conectarse por **las tres vías** y ejecutar al menos un caso por vía:

```bash
# Vía 1+2: JSON-RPC sobre Unix socket
echo '{"jsonrpc":"2.0","id":1,"method":"bi18n.health.check","params":{"ctx_id":"test-001"}}' \
  | nc -U /run/bos/bi18n.sock

# Vía 3: gRPC sobre Unix socket
# (requiere grpc_client_test binario compilado en desarrollo)
./grpc_client_test --socket /run/bos/bi18n-grpc.sock --method health.check --ctx test-002
```

Una vía que no se probó no existe (norma del Testeador).

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-16 | Creación. Interface Triple C11 para bi18n: proto completo con 7 servicios, 14 métodos MVP, transporte Unix socket, build.rs, patrón ServerContext compartido. |
