# Registro de Estado de Implementación — bi18n (i18n-orchestrator)

**Versión:** 1.0.0
**Fecha:** 2026-07-16
**Propósito:** Guía accionable de todo lo que falta implementar. Cada ítem tiene
archivos exactos a modificar y criterio de done. Usar este documento como hoja de
ruta de sesión en sesión — marcar ✅ al completar, anotar commit.

---

## Leyenda de estado

| Símbolo | Significado |
|---|---|
| ✅ | Completado y commiteado |
| 🔴 | Crítico — bloquea daemons hermanos o la Interface Triple C11 |
| 🟠 | Alta — cumplimiento de diseño, paridad JSON-RPC ↔ gRPC |
| 🟡 | Normal — calidad, modularidad, normas DOC-SBOS-001 N3 |
| ⚪ | Diferido — post-MVP, Fases 3/6/7/8 |

---

## Resumen ejecutivo de estado actual

| Componente | Implementado | Pendiente |
|---|---|---|
| Daemon bi18nd (arranque, sockets, signals) | ✅ | — |
| SIGHUP recarga atómica country-rules | ✅ | — |
| SIGTERM drain de conexiones activas | ✅ | — |
| SBOS-049 ctx_id obligatorio | ✅ | — |
| gRPC Vía 3 (estructura + proto generado) | ✅ parcial | FormatAddress stub |
| JSON-RPC dispatcher (16 de 16 métodos) | ✅ 16/16 `9e0c95d` | — |
| Dispatcher separado (dispatcher.rs) | ❌ | — |
| country-rules/bo.toml completo | ✅ | — |
| country-rules/ar.toml básico | ✅ parcial | Ampliar al nivel de bo.toml |
| Handlers de lógica (format, validate, mask, attr) | ✅ todos wired | — |
| format_map 18 códigos display_format | ✅ | — |
| ICU4X integrado en código (llamadas reales) | ❌ | Declarado, sin llamadas |
| fluent integrado (mensajes localizados) | ❌ | Declarado, sin código ni locales/ |
| i18nctl CLI funcional | ❌ | Stub — solo imprime, no llama al daemon |
| preflight.rs | ❌ | Módulo definido en arquitectura, no existe |
| systemd sd_notify + watchdog | ❌ | Necesario para Type=notify |

---

## BLOQUE 1 — Dispatcher JSON-RPC: métodos sin wiring 🔴

> **Impacto:** bAuth y otros daemons no pueden invocar estas capacidades por Vía 1+2 aunque
> el handler ya existe. Bloquea la paridad C11 y los casos de uso del Motor de Identidad.

Archivo a modificar: **`src/server/unix_socket.rs`** (función `ejecutar_metodo`, línea ~130)

### 1.1 `bi18n.format.number`

- **Handler:** `handlers::format::format_number()` — existe en `src/server/handlers/format.rs:92`
- **Params JSON-RPC:** `ctx_id`, `valor` (string numérico canónico), `decimales` (u32), `tenant_id`
- **Retorno:** `{ "display": "1,234.567" }`
- **Criterio de done:** el handler ya resuelve el locale desde `RegionalConfig`; solo agregar el
  arm `"bi18n.format.number" =>` en el match del dispatcher y resolver el `RegionalConfig` del tenant.
- **Estado:** ✅ `9e0c95d` — Fix añadido: lee `[numeracion]` TOML del país (Bolivia: `.` decimal, `,` miles)

### 1.2 `bi18n.format.money`

- **Handler:** `handlers::format::format_money()` — existe en `src/server/handlers/format.rs:119`
- **Params JSON-RPC:** `ctx_id`, `monto` (string), `currency_code` (ej: "BOB"), `tenant_id`
- **Retorno:** `{ "display": "Bs. 1.234,50", "symbol_local": "Bs." }`
- **Criterio de done:** arm `"bi18n.format.money" =>` en dispatcher.
- **Estado:** ✅ `9e0c95d`

### 1.3 `bi18n.validate.national_id`

- **Handler:** `handlers::validate::validate_national_id()` — existe en
  `src/server/handlers/validate.rs`
- **Params JSON-RPC:** `ctx_id`, `value`, `kind` (ej: "CI"), `country` (ej: "BO")
- **Retorno:** `{ "valid": true, "normalized": "7654321-LP", "errores": [] }`
- **Criterio de done:** arm `"bi18n.validate.national_id" =>` en dispatcher; extraer
  `IsoAlpha2` del param `country`.
- **Estado:** ✅ `9e0c95d`

### 1.4 `bi18n.mask.value`

- **Handler:** `handlers::mask::mask_value()` — existe en `src/server/handlers/mask.rs`
- **Params JSON-RPC:** `ctx_id`, `value`, `strategy` (ej: `"partial(4)"`, `"full"`, `"partial_both(2,2)"`)
- **Retorno:** `{ "masked": "****321-LP" }`
- **Criterio de done:** arm `"bi18n.mask.value" =>` en dispatcher; parsear el string
  de estrategia al enum `MaskStrategy` (convención wire definida en 1.01 §7.3).
- **Estado:** ✅ `9e0c95d`

### 1.5 `bi18n.attr.pipeline`

- **Handler:** `handlers::attr::pipeline()` — existe en `src/server/handlers/attr.rs`
- **Params JSON-RPC:** `ctx_id`, `key`, `value`, `validate_format`, `transforms[]`,
  `format_code`, `mask`, `regional_config{locale, timezone, currency, country}`
- **Retorno:** `{ "raw", "valid", "transformed", "display", "masked", "errores_validacion" }`
- **Ejemplo canónico:** manual 1.01 §8.3
- **Criterio de done:** arm `"bi18n.attr.pipeline" =>` en dispatcher.
- **Estado:** ✅ `9e0c95d`

### 1.6 `bi18n.attr.build`

- **Handler:** `handlers::attr::build()` (o en `grpc_attr.rs`) — verificar existencia exacta
- **Params JSON-RPC:** `ctx_id`, `key`, `value`, `regional_config` (simplificado vs pipeline)
- **Criterio de done:** arm `"bi18n.attr.build" =>` en dispatcher.
- **Estado:** ✅ `9e0c95d`

### 1.7 `bi18n.attr.config`

- **Handler:** no existe — definido en A.02 §3.2
- **Propósito:** devuelve la configuración de un atributo por clave y tenant (qué máscara aplica,
  qué display_format, qué validación).
- **Params:** `ctx_id`, `key` (ej: "CI"), `tenant_id`
- **Retorno:** `{ "key": "CI", "display_format": "ID_BO", "mask": "partial_both(2,3)", "validate_format": "ID_BO" }`
- **Criterio de done:** crear handler en `handlers/attr.rs` + arm en dispatcher.
- **Estado:** ✅ `9e0c95d`

### 1.8 `bi18n.attr.config_batch`

- **Handler:** no existe — definido en A.02 §3.3
- **Propósito:** misma operación que config pero para un array de claves en una sola llamada.
- **Params:** `ctx_id`, `keys[]`, `tenant_id`
- **Criterio de done:** handler que llame `attr_config()` en loop + arm en dispatcher.
- **Estado:** ✅ `9e0c95d`

---

## BLOQUE 2 — DOC-SBOS-001 N3: módulos sobre 200 líneas 🟠

> **Impacto:** violación de la norma de modularidad. El Revisor rechazará el código si el
> conteo supera 200 líneas y no se ha dividido en submódulos.

### 2.1 Split de `unix_socket.rs` (231 líneas → ≤200)

- **Archivo:** `src/server/unix_socket.rs` — 231 líneas actuales
- **Acción:** extraer la función `ejecutar_metodo` y el match completo de métodos a
  un nuevo archivo `src/server/dispatcher.rs`.
  - `unix_socket.rs` retiene: `iniciar_jsonrpc`, `manejar_conexion`, `despachar_request`,
    `JsonRpcRequest`, `error_jsonrpc`.
  - `dispatcher.rs` contiene: `ejecutar_metodo` completo (el match de métodos).
- **Criterio de done:** ambos archivos ≤200 líneas. `unix_socket.rs` llama
  `crate::server::dispatcher::ejecutar_metodo(...)`.
- **Estado:** ✅ `9e0c95d`

### 2.2 Split de `format.rs` (218 líneas → ≤200)

- **Archivo:** `src/server/handlers/format.rs` — 218 líneas actuales
- **Acción:** extraer `formatear_numero` + `separadores` a `src/server/handlers/format_utils.rs`.
  - `format.rs` retiene: `format_date`, `format_number`, `format_money`, `format_fecha_o_ahora`,
    structs `FormatDateResult`, `FormatNumberResult`, `FormatMoneyResult`, `GranularidadFecha`.
  - `format_utils.rs` contiene: `formatear_numero`, `separadores`.
- **Criterio de done:** ambos archivos ≤200 líneas. `format.rs` importa desde `format_utils`.
- **Estado:** ✅ `043236f`

---

## BLOQUE 3 — ICU4X: integración real 🟠

> **Impacto:** el manual 1.01 especifica ICU4X como fuente de verdad para formatos CLDR.
> Actualmente format.rs usa formateo manual con `format!()`. Las librerías están en Cargo.toml
> pero sin ninguna llamada real.
>
> **Precondición:** completar Bloque 1 antes (los handlers que llamen ICU4X ya deben estar wired).

### 3.1 `format_date` con ICU4X `icu_datetime`

- **Archivo:** `src/server/handlers/format.rs` (o `format_utils.rs` tras split)
- **Acción:** reemplazar el bloque `match granularidad { format!(...) }` por
  `icu_datetime::DateTimeFormatter` con locale BCP 47 del tenant.
  - Para `SoloFecha` → `DateFormatter` · para `FechaHora` → `DateTimeFormatter`
  - Para `MesAnio` → `YearMonthFormatter` · para `SoloHora` → `TimeFormatter`
- **Resultado esperado:** "16 de julio de 2026" en lugar de "2026-07-16" para `es-BO`.
- **Criterio de done:** test con tenant `es-BO` devuelve fecha en lenguaje natural.
- **Estado:** ✅ `66d7d25`

### 3.2 `format_number` con ICU4X `icu_decimal`

- **Archivo:** `src/server/handlers/format.rs`
- **Acción:** reemplazar `formatear_numero()` manual por `icu_decimal::FixedDecimalFormatter`
  configurado con el locale del tenant.
- **Criterio de done:** "1,234,567.0000000" para `en-US` y "1.234.567,0000000" para `es-ES`.
  Bolivia con `es-BO` lee separadores de `country-rules/bo.toml` (sep_decimal=".") — la
  función `separadores()` ya tiene la lógica correcta; el `FixedDecimalFormatter` debe usar esos mismos.
- **Estado:** ✅ `66d7d25`

### 3.3 `icu_locale_core` — validación BCP 47

- **Archivo:** `src/server/handlers/locale.rs` (o donde `resolver_locale` esté implementado)
- **Acción:** al recibir un locale BCP 47 en el request, validarlo con `icu_locale_core::Locale`
  antes de usarlo. Retornar error descriptivo si el locale no es válido.
- **Criterio de done:** `"es-INVALIDO"` retorna error con mensaje en español; `"es-BO"` pasa.
- **Estado:** ✅ `66d7d25`

### 3.4 Derivación de máscaras de entrada desde CLDR (Mecanismo §7.2)

- **Archivo:** nuevo `src/domain/input_mask.rs` (o agregar función en `format_map.rs`)
- **Acción:** implementar la traducción patrón CLDR → máscara de formulario:
  - Obtener patrón CLDR del locale vía `icu_datetime` (ej: `dd/MM/yyyy`)
  - Traducir `d`→`9`, `M`→`9`, `y`→`9`, `/`→`/`
  - Exponer vía `bi18n.attr.config` (campo `input_mask`)
- **Referencia:** manual 1.01 §7.2, tabla de conversión
- **Criterio de done:** `bi18n.attr.config{ key: "fecha_nacimiento", locale: "es-BO" }` devuelve `input_mask: "99/99/9999"`.
- **Estado:** ✅ `66d7d25`

---

## BLOQUE 4 — fluent: mensajes localizados ✅

> **Impacto:** sin fluent, `bi18n.enum.display` usa solo TOML plano — funciona para enums
> simples pero no soporta plurales ni concordancia de género.

### 4.1 Crear directorio `locales/` con archivo base

- **Acción:** crear `Bi18nAgent/locales/es-BO/main.ftl` con mensajes de ejemplo:
  ```fluent
  -brand-name = SBOS bi18n

  # Errores de validación
  error-ci-invalido = Cédula de identidad boliviana inválida. Formato esperado: { $ejemplo }.
  error-nit-invalido = NIT boliviano inválido. Debe tener entre 7 y 12 dígitos.

  # Mensajes de estado
  paises-cargados = { $n ->
      [one] 1 país cargado
     *[other] { $n } países cargados
  }
  ```
- **Criterio de done:** directorio existe, al menos un archivo FTL con un plural.
- **Estado:** ✅ — `locales/es-BO/main.ftl` + `locales/en-US/main.ftl` (plurales, variables)

### 4.2 Integrar `FluentBundle` en el contexto del servidor

- **Archivo:** `src/server/context.rs` (o `src/config/mod.rs`)
- **Acción:** al inicializar `ServerContext`, cargar los archivos FTL del `fluent_dir`
  de la config en un `FluentBundle` cacheado en `Arc<RwLock<FluentBundle>>`.
- **Criterio de done:** `ServerContext` expone método `traducir(id, args)` que devuelve
  el mensaje localizado; si no existe, retorna el id como fallback.
- **Estado:** ✅ — `FluentLoader` en `Arc<RwLock<Bundle>>`; `ctx.fluent.traducir()` funcional; SIGHUP recarga

### 4.3 Usar FluentBundle en mensajes de error

- **Archivos:** `src/server/handlers/validate.rs`, `src/error.rs`
- **Acción:** los errores de validación (`errores_validacion[]`) deben venir de FluentBundle
  en lugar de ser strings hardcodeados.
- **Criterio de done:** al cambiar el FTL y recargar (SIGHUP), los mensajes de error cambian.
- **Estado:** ✅ — validate.rs + health.rs usan Fluent; SIGHUP verificado en vivo

---

## BLOQUE 5 — i18nctl: implementación real ✅

> **Impacto:** la CLI es la Vía 3 del operador. Actualmente solo parsea argumentos e imprime
> "Fase 5 pendiente" — no conecta con el daemon.

Archivo a modificar: **`src/bin/i18nctl.rs`**
Precondición: daemon bi18nd activo en `/run/bos/bi18n.sock`.

### 5.1 Cliente JSON-RPC sobre Unix socket

- **Acción:** agregar función interna `enviar_jsonrpc(socket_path, method, params) -> Value`
  que:
  1. Abre `tokio::net::UnixStream` (o `std::os::unix::net::UnixStream` si se hace síncrono)
  2. Escribe request `{"jsonrpc":"2.0","id":1,"method":...,"params":...}\n`
  3. Lee la línea de respuesta
  4. Parsea y retorna el `result` o imprime el `error`
- **Criterio de done:** `i18nctl estado` conecta al socket y muestra el resultado de
  `bi18n.health.check`.
- **Estado:** ✅ — `enviar_jsonrpc()` síncrono vía `UnixStream`; timeouts 5s/10s

### 5.2 Subcomandos base (Estado, Recargar)

- **Estado:** enviar `bi18n.health.check` + imprimir `status`, `version`, `paises_cargados`
- **Recargar:** enviar SIGHUP al daemon **o** un método JSON-RPC de recarga (agregar
  `bi18n.admin.reload` en el dispatcher si se prefiere no usar señales desde el CLI)
- **Criterio de done:** ambos comandos producen output legible en terminal.
- **Estado:** ✅ — `estado`→`bi18n.health.check`; `recargar`→`bi18n.admin.reload` (dispatcher + context)

### 5.3 Subcomandos de formato y validación

Agregar los subcomandos que faltan (según A.02 §4.3):

| Subcomando | Método JSON-RPC | Params clave |
|---|---|---|
| `format-fecha` | `bi18n.format.date` | `--fecha`, `--granularidad`, `--tenant` |
| `format-numero` | `bi18n.format.number` | `--valor`, `--decimales`, `--tenant` |
| `format-monto` | `bi18n.format.money` | `--monto`, `--moneda`, `--tenant` |
| `validar-id` | `bi18n.validate.national_id` | `--valor`, `--tipo`, `--pais` |
| `validar-email` | `bi18n.validate.email` | `--valor` |
| `validar-telefono` | `bi18n.validate.phone` | `--valor`, `--pais` |
| `mask-valor` | `bi18n.mask.value` | `--valor`, `--estrategia` |
| `mask-pii` | `bi18n.mask.pii` | `--texto` |
| `locale-resolver` | `bi18n.locale.resolve` | `--tenant`, `--branch`, `--usuario` |
| `enum-display` | `bi18n.enum.display` | `--enum`, `--valor`, `--locale` |
| `snapshot` | `bi18n.regional.snapshot` | `--tenant` |
| `attr-pipeline` | `bi18n.attr.pipeline` | `--clave`, `--valor`, `--tenant` |

- **Criterio de done:** todos los subcomandos listados tienen implementación que llama
  al daemon y formatea la respuesta en la terminal. `--json` produce JSON crudo.
- **Estado:** ✅ — 12 subcomandos implementados: format-fecha/numero/monto, validar-id/email/telefono, mask-valor/pii, locale-resolver, enum-display, snapshot, attr-pipeline

### 5.4 Flags transversales

- `--json` → imprimir `result` JSON crudo (para scripts, CI/CD)
- `--quiet` → solo exit code (0=ok, 1=inválido, 2=error daemon)
- `--ctx-id UUID` → pasar ctx_id explícito (por defecto: UUID generado localmente)
- **Criterio de done:** `i18nctl --json snapshot --tenant acme-sa` imprime JSON.
- **Estado:** ✅ — `--json`, `--quiet`, `--ctx-id` globales; exit codes 0/2

---

## BLOQUE 6 — Infraestructura de producción ✅

### 6.1 `preflight.rs` — validaciones pre-arranque

- **Archivo:** `src/preflight.rs` (no existe — crear)
- **Referencia:** manual 1.01 §4 menciona el módulo explícitamente
- **Contenido mínimo:**
  ```rust
  pub async fn ejecutar(cfg: &Config) -> Result<(), Bi18nError> {
      // 1. country-rules/ existe y tiene al menos 1 TOML legible
      // 2. El socket puede crearse (dir /run/bos/ existe y permisos correctos)
      // 3. fluent_dir existe si está definida en la config
      // 4. grpc_socket_path accesible
  }
  ```
- **Criterio de done:** `main.rs` llama `preflight::ejecutar(&cfg).await?` antes de iniciar
  los servidores. Si falla, el daemon no arranca y loguea el error en español.
- **Estado:** ✅ — `src/preflight.rs` con 4 checks (C1-C4); main.rs llama preflight antes de arrancar servidores

### 6.2 `systemd sd_notify` + WatchdogSec

- **Archivo:** `src/domain/signal.rs` o `src/main.rs`
- **Dependencia:** crate `sd-notify` (agregar a Cargo.toml en feature `systemd`)
- **Acción:**
  - Después del arranque exitoso (sockets listos): `sd_notify::notify(false, &[sd_notify::NotifyState::Ready])`
  - En SIGTERM drain completado: `sd_notify::notify(false, &[sd_notify::NotifyState::Stopping])`
  - Watchdog: responder al watchdog en el loop principal cada `WatchdogSec/2`
- **Criterio de done:** `systemctl status bi18nd` muestra `active (running)` sin timeout.
- **Estado:** ✅ — sd_notify READY=1 en main.rs; watchdog loop en signal.rs (WatchdogSec/2); dep sd-notify 0.4

### 6.3 Archivo `bi18nd.service` (systemd unit)

- **Archivo:** `Bi18nAgent/deploy/bi18nd.service` (crear directorio `deploy/`)
- **Contenido:**
  ```ini
  [Unit]
  Description=SBOS bi18n — Orquestador de internacionalización
  After=network.target

  [Service]
  Type=notify
  ExecStart=/usr/local/bin/bi18nd
  WatchdogSec=30
  Restart=on-failure
  RestartSec=5
  User=bos
  Group=bosagent

  [Install]
  WantedBy=multi-user.target
  ```
- **Criterio de done:** archivo existe en el repo, instalable con `systemctl enable`.
- **Estado:** ✅ — `deploy/bi18nd.service` con Type=notify, WatchdogSec=30, hardening de seguridad ISO 27001

---

## BLOQUE 7 — Country-rules: ampliar cobertura ✅

### 7.1 Ampliar `ar.toml` al nivel de `bo.toml`

- **Archivo:** `country-rules/ar.toml` — actualmente básico
- **Agregar:** sección `[numeracion]` (sep_decimal=",", sep_miles=".", decimales_defecto=2),
  `[moneda]` con `decimales_operacion`, `[pais]` completo, documentos (DNI, CUIL, CUIT),
  máscaras, 14+ enums al nivel de Bolivia.
- **Referencia:** AFIP Argentina, RENAPER, ANSES, ARCA.
- **Criterio de done:** `bi18n.regional.snapshot{ tenant_id: "acme-ar" }` devuelve
  numeracion + enums completos.
- **Estado:** ✅ — ar.toml: [numeracion]+5 docs+16 enums (DNI/CUIT/CUIL/PASSPORT/CDI + provincias/sectores CIIU)

### 7.2 `br.toml` — Brasil

- **Archivo:** `country-rules/br.toml` (crear)
- **Documentos:** CPF (`^\d{3}\.\d{3}\.\d{3}-\d{2}$`), CNPJ (`^\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}$`),
  RG (variable por estado)
- **Moneda:** BRL, símbolo "R$", `sep_decimal=","`, `sep_miles="."`
- **Locale:** `pt-BR`, `America/Sao_Paulo`
- **Criterio de done:** `bi18n.validate.national_id{ country:"BR", kind:"CPF", value:"123.456.789-09" }` valida correctamente.
- **Estado:** ✅ — br.toml creado: CPF/CNPJ/RG/CNH/TITULO_ELEITOR/PASSPORT + 16 enums pt-BR (27 estados, sectores CNAE)

---

## BLOQUE 8 — Fases diferidas (post-MVP) ⚪

> Estos ítems están documentados en el roadmap del manual 1.01 §9 como fases posteriores.
> No bloquean el MVP. Registrarlos aquí para no perderlos.

### Fase 3 — Multi-tenant completo

- Sección `[tenants.*]` en `bi18n.toml` para configurar locales por tenant sin reiniciar
- `RequestBoundRegionalConfigResolver`: leer `RegionalConfig` del payload de cada request
  (en producción, bAuth lo envía — no se necesita consultar la BD)

### Fase 6 — Collation, bidi, calendarios no gregorianos

- `icu_collator` para ordenamiento lingüístico (ej: `ch` después de `c` en español)
- Soporte bidi (árabe, hebreo) — RTL en campos de texto
- Calendarios no gregorianos (jalali, hebreo, etíope) vía ICU4X

### Fase 7 — AtomLang pipeline completo

- `bi18n.attr.config` y `bi18n.attr.config_batch` usados desde políticas AtomLang
- `obligation.service: bi18n` con llamadas desde el Motor de Identidad de bAuth

### Fase 8 — Empaquetado y distribución

- Compilación MUSL: `cargo build --target x86_64-unknown-linux-musl --release`
- Features opcionales: `cargo build --features systemd` (con sd-notify), `--features grpc`
- Script de instalación que crea usuario `bos`, directorio `/run/bos/`, instala unit file

### FormatAddress (Post-MVP)

- **Archivo:** `src/server/grpc.rs` línea 111 — actualmente `Status::unimplemented`
- **Acción:** implementar formato de dirección postal según `[postal]` del TOML del país
- **Nota:** no hay sección `[postal]` en `bo.toml` aún — agregar cuando se implemente

---

## BLOQUE 9 — Ligadura Frontend (A.04) 🔴

> **Principio fundamental:** bi18n es **agnóstico de plataforma**. El daemon expone un protocolo
> (WebSocket + JSON-RPC 2.0 newline-delimited). Cualquier cliente — sea cual sea el lenguaje,
> framework o entorno — implementa su propio adapter local. El daemon no conoce ni depende de
> Flutter, Vue, React, Swift, Kotlin, ni ningún otro. Las tareas de este bloque son EXCLUSIVAMENTE
> del daemon; los adapters por plataforma son responsabilidad de cada equipo cliente.

### 9.1 WebSocket listener en bi18nd (transporte universal para clientes remotos)

- **Acción:** agregar un listener WebSocket al daemon (junto al Unix socket existente) para
  que Kong pueda exponer el endpoint y cualquier cliente remoto se conecte por TLS.
  - Mismo dispatcher `ejecutar_metodo` que usa el JSON-RPC Unix socket — un solo core,
    dos transportes. El daemon no distingue entre un cliente Flutter, un Vue app o un script bash.
  - Autenticación por token JWT (bAuth) en el handshake WebSocket.
  - El protocolo es JSON-RPC 2.0 newline-delimited — idéntico al del Unix socket. Quien ya
    sabe llamar al socket local puede llamar al WebSocket cambiando solo el transporte.
- **Archivo(s):** `src/server/websocket.rs` (crear) + `src/server/mod.rs` (registrar) + `src/main.rs`
- **Criterio de done:** cualquier cliente WebSocket estándar (`websocat`, `wscat`, script bash con
  `curl --include --no-buffer -H "Upgrade: websocket"`) conecta y recibe respuesta de
  `bi18n.health.check` en JSON-RPC 2.0 — sin adapter específico.
- **Estado:** ❌

### 9.2 Método `bi18n.attr.config_batch` + `bi18n.attr.pipeline` en el dispatcher

- **Acción:** implementar los dos métodos que forman el contrato de ligadura (A.04 §3):
  - `bi18n.attr.config_batch` — recibe lista de `field_id`, devuelve `{mask_pattern, display_format, validator_profile}` por campo.
  - `bi18n.attr.pipeline` — recibe `{field_id, value, validator_profile, locale}`, devuelve `{valid, display, masked, validation_errors}`.
  - Ambos deben funcionar tanto en Unix socket (daemons internos, CLI) como en WebSocket (clientes remotos).
  - Cache de `country-rules` en memoria — no leer TOML por request, sino servir desde el cache ya cargado.
- **Archivo(s):** `src/server/dispatcher.rs` + `src/server/handlers/attr.rs` (crear)
- **Criterio de done:** `i18nctl attr-pipeline --field-id CI --valor "1234567" --locale es-BO`
  retorna `{valid: true, display: "1234567", masked: "123****"}` — verificable sin ningún framework de frontend.
- **Estado:** ❌

### 9.3 Resolución de locale por tenant — una vez por sesión, no por campo

- **Acción:** en `attr.config_batch`, resolver el locale efectivo (tenant + branch + usuario)
  **una sola vez** antes de iterar los campos — no repetir la resolución 20 veces por batch.
  - Reutilizar `bi18n.locale.resolve` internamente como función, no como RPC.
- **Archivo(s):** `src/server/handlers/attr.rs` + `src/domain/regional_config.rs`
- **Criterio de done:** `attr.config_batch` con 20 campos hace exactamente 1 consulta de locale
  (verificable con `tracing::debug!` o un contador atómico en el loader).
- **Estado:** ❌

### 9.4 Rate limiting por conexión WebSocket + timeout por request

- **Acción:** en `src/server/websocket.rs`, limitar la tasa de requests por conexión para
  `attr.pipeline` (protege el daemon de clientes sin debounce — eso es responsabilidad del
  cliente, pero el daemon no puede confiar en ello).
  - Rate limit: N requests/s por conexión (configurable en TOML).
  - Timeout explícito por request: si el handler no responde en X ms, el WebSocket retorna error.
  - El cliente recibe `{"error": {"code": -32000, "message": "rate limit excedido"}}`.
- **Criterio de done:** `websocat ws://... < /dev/stdin` enviando 200 requests/s recibe
  respuestas de error en el campo `error.code` después del umbral — sin crash del daemon.
- **Estado:** ❌

### 9.5 Documentación del protocolo WebSocket (contract-first, agnóstico de plataforma)

- **Acción:** crear `context/Documentacion/anexos/A.07_ANEXO-BI18N-PROTOCOLO-WEBSOCKET-v1.0.md`
  con la especificación formal del protocolo:
  - URL del endpoint expuesto por Kong.
  - Handshake JWT (qué header, qué claim).
  - Framing: JSON-RPC 2.0 newline-delimited (un objeto JSON por línea, `\n` como delimitador).
  - Los métodos disponibles y sus parámetros exactos.
  - Códigos de error específicos del WebSocket (-32000 rate limit, -32001 auth, etc.).
  - Fragmento de conexión mínimo en pseudocódigo neutro (no en ningún lenguaje concreto).
- **Criterio de done:** un equipo nuevo puede implementar un cliente WebSocket funcional leyendo
  solo este anexo, sin consultar el código fuente del daemon.
- **Estado:** ❌

---

## BLOQUE 10 — Cierre de Gaps (A.05) 🟠

> **Impacto:** RTL desbloquea locales árabe/hebreo; gobernanza evita regresiones fiscales;
> CI de paridad detecta claves faltantes antes de llegar a producción.

### 10.1 RTL — `text_direction` en locale.resolve y attr.config_batch

- **Acción:** agregar campo `text_direction: "ltr" | "rtl"` al response de `bi18n.locale.resolve`
  y de `bi18n.attr.config_batch`. Se resuelve una vez por sesión, no por campo.
  - `icu_locale_core::DataLocale` ya expone esta info de CLDR — sin cálculo manual.
- **Archivo(s):** `src/server/handlers/locale.rs` + `src/server/handlers/attr.rs`
  + `src/domain/regional_config.rs`
- **Criterio de done:** `bi18n.locale.resolve { locale: "ar-SA" }` retorna `"text_direction": "rtl"`;
  `bi18n.locale.resolve { locale: "es-BO" }` retorna `"text_direction": "ltr"`.
- **Estado:** ❌

### 10.2 CODEOWNERS — gobernanza sobre country-rules y translations

- **Acción:** crear `.github/CODEOWNERS` en la raíz del repo con:
  ```
  /Bi18nAgent/country-rules/  @equipo-legal-fiscal @arquitecto-sbos
  /Bi18nAgent/translations/   @equipo-i18n
  ```
  + regla de protección de rama que requiere aprobación de CODEOWNER para `country-rules/**`.
  + Campo `[meta] version = "X.Y.Z"` obligatorio en cada TOML de país.
- **Criterio de done:** un PR que toque `country-rules/bo.toml` sin aprobación del CODEOWNER
  no puede mergearse — verificar intentando mergear uno de prueba.
- **Estado:** ❌

### 10.3 CI de paridad de claves — `i18nctl translations check-parity`

- **Acción:** agregar subcomando `translations check-parity` a `src/bin/i18nctl.rs`:
  - Lee todos los archivos FTL/TOML de `locales/` por locale.
  - Compara el set de claves de cada locale contra el locale de referencia (`es-BO`).
  - Exit code 1 si falta alguna clave en cualquier locale secundario.
  - Agregar como job obligatorio en `.github/workflows/ci.yml`.
- **Criterio de done:** si `locales/pt-BR/main.ftl` no tiene la clave `paises-cargados`,
  el job de CI falla con mensaje indicando la clave faltante y el locale afectado.
- **Estado:** ❌

### 10.4 Alta disponibilidad — 2+ réplicas bi18nd detrás de Kong

- **Acción:**
  1. Verificar que el build empaqueta `country-rules/` dentro del artefacto (inmutable).
  2. Definir volumen/storage compartido para `translations/`, accesible por igual desde
     todas las réplicas (no un disco local por instancia).
  3. Configurar 2+ réplicas de `bi18nd` con Kong apuntando a ambas vía `bi18n.health.check`.
  4. El pipeline de A.06 llama `bi18n.admin.reload_translations` en cada réplica individualmente.
- **Criterio de done:** `systemctl stop bi18nd` en una réplica → Kong redirige sin error
  al cliente; al restaurarla, re-entra al pool automáticamente.
- **Estado:** ❌

### 10.5 Accesibilidad (a11y) en los ejemplos de referencia de A.04 §9

> **Nota:** bi18n es agnóstico de plataforma. Esta tarea es una actualización a los
> **ejemplos de referencia** del anexo — no código del daemon. Cada equipo cliente aplica
> los atributos de a11y en su mecanismo nativo; los ejemplos deben mostrar cómo hacerlo.

- **Acción:** actualizar los 4 ejemplos de referencia de A.04 §9 para incluir los atributos
  de accesibilidad en el contenedor del mensaje de error:
  - Ejemplo web vanilla: `aria-live="polite"` y `role="alert"` en el div de error.
  - Ejemplo JS/Vue: `aria-live="polite"` en el elemento `<small class="p-error">`.
  - Ejemplo Flutter: `Semantics(liveRegion: true, label: errorMessage)` en el widget de error.
  - Ejemplo Rust (servidor): sin cambio — el servidor no renderiza UI.
  - Para otros lenguajes/plataformas: el mismo principio — el contenedor del error debe ser
    anunciable por lector de pantalla sin que el usuario mueva el foco al campo.
- **Criterio de done:** A.04 §9 contiene el atributo de a11y en los 3 ejemplos de cliente
  (web, Flutter, Vue). La descripción de §5 menciona la a11y como parte del adapter pattern.
- **Estado:** ❌

### 10.6 A.07 — Especificación formal del protocolo WebSocket (agnóstico de plataforma)

> **Nota:** bi18n no crea ni mantiene SDKs en lenguajes/frameworks de frontend. Su
> responsabilidad es publicar el contrato del protocolo para que cualquier equipo lo implemente.

- **Acción:** crear `context/Documentacion/anexos/A.07_ANEXO-BI18N-PROTOCOLO-WEBSOCKET-v1.0.md`
  con la especificación formal del protocolo WebSocket de bi18n:
  - URL del endpoint Kong + path de upgrade.
  - Handshake JWT: qué header, qué claim, qué retorna si falla.
  - Framing: JSON-RPC 2.0 newline-delimited — explicado sin asumir ningún lenguaje.
  - Tabla de todos los métodos JSON-RPC disponibles vía WebSocket con parámetros y respuestas.
  - Códigos de error del transporte WebSocket (-32000 rate limit, -32001 auth, etc.).
  - Pseudocódigo neutro (sin lenguaje concreto) de una sesión mínima: connect → auth → request → response.
- **Criterio de done:** un equipo nuevo puede implementar un cliente funcional leyendo solo
  A.07, sin consultar el código del daemon, en cualquier lenguaje que soporte WebSocket.
- **Estado:** ❌

---

## BLOQUE 11 — Daemon de Traducciones (A.06) 🟡

> **Impacto:** hoy cambiar un texto de UI requiere que un desarrollador edite un FTL y
> redeploy el daemon. Con este bloque, un responsable de negocio cambia el texto en Weblate
> y en minutos está en producción — sin tocar Git, sin redeploy del binario.

### 11.1 Weblate self-hosteado

- **Acción:** levantar Weblate con Docker Compose (app + PostgreSQL + Redis) en VPS de STAGING,
  conectado al repo donde viven `locales/` (solo `locales/`, no `country-rules/`).
  Importar las claves existentes de `locales/es-BO/main.ftl` como import inicial.
- **Criterio de done:** un usuario de negocio (no desarrollador) edita una clave de `es-BO`
  en Weblate de principio a fin sin tocar Git ni FTL directamente; Weblate commitea al repo.
- **Estado:** ❌

### 11.2 `bi18n.admin.reload_translations` con ArcSwap

- **Acción:** implementar el nuevo método RPC `bi18n.admin.reload_translations` en el dispatcher.
  - Usar crate `arc-swap` (143M+ descargas): las traducciones en memoria viven detrás de
    `ArcSwap<Translations>` — los requests hacen `load()` sin bloqueo.
  - El reload construye la nueva `Translations` completa en memoria **antes** de hacer `store()`
    (swap atómico). Si el parseo falla, la versión anterior sigue sirviendo.
  - El RPC **no** debe exponerse en la ruta pública de Kong — solo accesible desde el pipeline
    de CI/deploy o el socket Unix local.
- **Archivo(s):** `src/server/dispatcher.rs` + nuevo `src/domain/translations.rs`
  + `Cargo.toml` (agregar `arc-swap = "1"`)
- **Criterio de done:** `bi18n.admin.reload_translations` llamado mientras hay requests
  concurrentes en curso no produce errores ni estado corrupto (verificar con `cargo test`
  de estrés o wrk/vegeta).
- **Estado:** ❌

### 11.3 File watcher con `notify` crate

- **Acción:** agregar un file watcher sobre `cfg.rutas.fluent_dir` usando el crate `notify`
  (usado por rust-analyzer, deno, mdBook — patrón estándar).
  - Al detectar cambio, dispara el mismo reload que `bi18n.admin.reload_translations`.
  - Es la red de seguridad: cubre el caso de edición manual en el VPS sin pasar por el pipeline.
- **Archivo(s):** `src/domain/signal.rs` o nuevo `src/domain/file_watcher.rs`
- **Criterio de done:** editar `locales/es-BO/main.ftl` directamente en el VPS produce
  recarga automática en < 2s sin reiniciar el daemon.
- **Estado:** ❌

### 11.4 Pipeline CI: Weblate → commit → check paridad → deploy → RPC reload

- **Acción:** en `.github/workflows/ci.yml`, agregar paso que después de sincronizar
  `locales/` al VPS, llame a `bi18n.admin.reload_translations` en **cada réplica de bi18nd**
  individualmente (nunca a través de la ruta balanceada de Kong).
- **Criterio de done:** el ciclo completo (editar en Weblate → commit → CI → deploy → reload
  visible en `bi18n.health.check`) se mide de punta a punta en < 5 minutos.
- **Estado:** ❌

### 11.5 Ajuste CODEOWNERS — liberar translations/ de aprobación obligatoria

- **Acción:** actualizar `.github/CODEOWNERS` para que `translations/**` fluya de Weblate
  a `main` **solo con el gate de CI de paridad de claves** (Bloque 10.3), sin aprobación
  humana obligatoria. `country-rules/**` mantiene la aprobación obligatoria.
- **Criterio de done:** un PR de Weblate que solo toque `locales/*.ftl` se mergea
  automáticamente si CI pasa — sin esperar aprobación de CODEOWNER.
- **Estado:** ❌

---

## Orden de ejecución recomendado

```
Sesión 1:  Bloque 1 (dispatcher) + Bloque 2 (split módulos)
           → todos los métodos wired → paridad C11 completa
           → cargo build limpio → commit

Sesión 2:  Bloque 3 (ICU4X real)
           → format.rs usa ICU4X en lugar de format!()
           → cargo build limpio + tests → commit

Sesión 3:  Bloque 5 (i18nctl CLI real)
           → cliente JSON-RPC sobre socket
           → todos los subcomandos de A.02 §4.3
           → cargo build limpio → commit

Sesión 4:  Bloque 6 (preflight + systemd)
           → sd_notify + bi18nd.service
           → cargo build limpio → commit

Sesión 5:  Bloque 4 (fluent) + Bloque 7 (country-rules adicionales)
           → locales/ con FTL · ar.toml completo · br.toml nuevo
           → cargo build limpio → commit

Sesiones posteriores: Bloque 8 (fases diferidas)
```

---

## Checklist de sesión activa

Al comenzar una sesión, copiar este bloque y marcar:

```
[ ] Revisé este documento al iniciar
[ ] El daemon compila: cd Bi18nAgent && cargo build 2>&1 | tail -5
[ ] Cada módulo nuevo ≤ 200 líneas (DOC-SBOS-001 N3)
[ ] Cada función nueva ≤ 50 líneas
[ ] Cero unwrap() en código de producción
[ ] Tests pasan: cargo test 2>&1 | tail -10
[ ] Actualicé este documento con los ✅ de la sesión
[ ] Commit con mensaje en español
```

---

## Historial de actualizaciones

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | 2026-07-16 | Creación inicial — inventario completo de pendientes post-análisis de documentación y código |
