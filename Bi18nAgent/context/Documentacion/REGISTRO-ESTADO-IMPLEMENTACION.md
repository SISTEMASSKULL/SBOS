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

## BLOQUE 6 — Infraestructura de producción 🟡

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
- **Estado:** ❌

### 6.2 `systemd sd_notify` + WatchdogSec

- **Archivo:** `src/domain/signal.rs` o `src/main.rs`
- **Dependencia:** crate `sd-notify` (agregar a Cargo.toml en feature `systemd`)
- **Acción:**
  - Después del arranque exitoso (sockets listos): `sd_notify::notify(false, &[sd_notify::NotifyState::Ready])`
  - En SIGTERM drain completado: `sd_notify::notify(false, &[sd_notify::NotifyState::Stopping])`
  - Watchdog: responder al watchdog en el loop principal cada `WatchdogSec/2`
- **Criterio de done:** `systemctl status bi18nd` muestra `active (running)` sin timeout.
- **Estado:** ❌

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
- **Estado:** ❌

---

## BLOQUE 7 — Country-rules: ampliar cobertura 🟡

### 7.1 Ampliar `ar.toml` al nivel de `bo.toml`

- **Archivo:** `country-rules/ar.toml` — actualmente básico
- **Agregar:** sección `[numeracion]` (sep_decimal=",", sep_miles=".", decimales_defecto=2),
  `[moneda]` con `decimales_operacion`, `[pais]` completo, documentos (DNI, CUIL, CUIT),
  máscaras, 14+ enums al nivel de Bolivia.
- **Referencia:** AFIP Argentina, RENAPER, ANSES, ARCA.
- **Criterio de done:** `bi18n.regional.snapshot{ tenant_id: "acme-ar" }` devuelve
  numeracion + enums completos.
- **Estado:** ❌

### 7.2 `br.toml` — Brasil

- **Archivo:** `country-rules/br.toml` (crear)
- **Documentos:** CPF (`^\d{3}\.\d{3}\.\d{3}-\d{2}$`), CNPJ (`^\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}$`),
  RG (variable por estado)
- **Moneda:** BRL, símbolo "R$", `sep_decimal=","`, `sep_miles="."`
- **Locale:** `pt-BR`, `America/Sao_Paulo`
- **Criterio de done:** `bi18n.validate.national_id{ country:"BR", kind:"CPF", value:"123.456.789-09" }` valida correctamente.
- **Estado:** ❌

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
