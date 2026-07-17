# Manual de Usuario — Daemon bi18n (i18n-orchestrator)

**Versión:** 1.0.0
**Fecha:** 2026-07-17
**Bloque:** 12.2
**Público objetivo:** integradores de sistemas, operadores de la plataforma SBOS,
desarrolladores de daemons hermanos que consumen bi18n vía JSON-RPC.

---

## §1 Qué es bi18n

**bi18n** es el **Orquestador Universal de Internacionalización** del ecosistema SBOS.
Centraliza todo lo relacionado con idioma, región, formato y validación de atributos
para que los demás daemons no dupliquen esa lógica.

**No es** un motor de autenticación, ni valida contraseñas, ni decide Permit/Deny.
Es un servicio de transformación: recibe datos crudos y devuelve datos presentables.

| Qué hace | Qué NO hace |
|---|---|
| Formatea fechas, números y monedas por locale | Autenticar usuarios |
| Valida documentos (CI, NIT, CPF, DNI, CUIT) | Gestionar roles o permisos |
| Valida teléfonos E.164 | Conectarse a Keycloak o Tryton |
| Enmascara PII en texto libre | Persistir datos (es stateless) |
| Resuelve el locale de un tenant | Hablar HTTP/TCP entre daemons |
| Traduce enums de negocio | Manejar tokens JWT |

---

## §2 Cómo se comunica con bi18n

bi18n expone **Interface Triple C11** — tres transportes, un solo núcleo:

| Vía | Transporte | Uso recomendado |
|---|---|---|
| **1** | Unix socket `/run/bos/bi18n.sock` — JSON-RPC 2.0 (línea por conexión) | Daemons SBOS (bAuth, biedata, etc.) |
| **2** | Unix socket `/run/bos/bi18n-grpc.sock` — gRPC/protobuf | Daemons con cliente gRPC |
| **3** | TCP `127.0.0.1:9454` — WebSocket + JSON-RPC 2.0 | Clientes remotos vía Kong (UI, scripts) |

**Todos los métodos son idénticos en las tres vías.** El core es el mismo dispatcher.

---

## §3 Formato del protocolo JSON-RPC 2.0

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "bi18n.<grupo>.<accion>",
  "params": {
    "ctx_id": "uuid-v4-requerido",
    "...": "parámetros del método"
  }
}
```

**`ctx_id` es OBLIGATORIO** en toda operación (SBOS-049 Context Plane).
Si está ausente o vacío, el daemon retorna error `-32602`.

### Response exitoso

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": { "...": "campos del resultado" }
}
```

### Response con error

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32602,
    "message": "ctx_id ausente o vacío — SBOS-049"
  }
}
```

### Códigos de error

| Código | Significado |
|---|---|
| `-32700` | JSON inválido en el request |
| `-32600` | Request mal formado (sin jsonrpc/method/params) |
| `-32601` | Método no encontrado |
| `-32602` | ctx_id ausente o vacío |
| `-32000` | Rate limit WebSocket superado (WS únicamente) |
| `-32001` | Timeout de request WebSocket (WS únicamente) |

---

## §4 Los 18 métodos RPC

### §4.1 `bi18n.health.check`

Verifica el estado del daemon. No requiere parámetros más allá del `ctx_id`.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 1,
  "method": "bi18n.health.check",
  "params": { "ctx_id": "diag-001" }
}
```

**Response:**
```json
{
  "result": {
    "status": "ok",
    "version": "0.1.0",
    "paises_cargados": 3,
    "mensaje": "bi18n operativo"
  }
}
```

**bi18nctl:** `bi18nctl estado`

---

### §4.2 `bi18n.locale.resolve`

Resuelve el locale efectivo para un tenant/branch/usuario según la jerarquía:
organización → sucursal → usuario. El campo más específico gana.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 2,
  "method": "bi18n.locale.resolve",
  "params": {
    "ctx_id": "ctx-abc",
    "tenant_id": "empresa-sa",
    "branch_id": "sucursal-norte",
    "user_id": "usr-42"
  }
}
```

**Response:**
```json
{
  "result": {
    "locale": "es-BO",
    "timezone": "America/La_Paz",
    "currency": "BOB",
    "country": "BO",
    "fuente": "default",
    "text_direction": "ltr"
  }
}
```

`fuente` indica de dónde viene la resolución: `"default"`, `"tenant"`, `"branch"` o `"user"`.
`text_direction` es `"ltr"` o `"rtl"` — útil para UI (árabe, hebreo, etc.).

**bi18nctl:** `bi18nctl locale-resolver --tenant empresa-sa`

---

### §4.3 `bi18n.validate.email`

Valida una dirección de email con regex RFC 5321. Normaliza a minúsculas.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 3,
  "method": "bi18n.validate.email",
  "params": { "ctx_id": "ctx-001", "value": "Usuario@Empresa.COM" }
}
```

**Response (válido):**
```json
{ "result": { "valid": true, "normalized": "usuario@empresa.com", "errores": [] } }
```

**Response (inválido):**
```json
{ "result": { "valid": false, "normalized": "", "errores": ["Email inválido. Formato esperado: usuario@dominio.com"] } }
```

**bi18nctl:** `bi18nctl validar-email usuario@empresa.com`

---

### §4.4 `bi18n.validate.phone`

Valida teléfono vía libphonenumber (E.164). `country_hint` = ISO 3166-1 alpha-2.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 4,
  "method": "bi18n.validate.phone",
  "params": { "ctx_id": "ctx-002", "value": "71234567", "country_hint": "BO" }
}
```

**Response (válido):**
```json
{ "result": { "valid": true, "e164": "+59171234567", "errores": [] } }
```

**bi18nctl:** `bi18nctl validar-telefono 71234567 --pais BO`

---

### §4.5 `bi18n.validate.national_id`

Valida documento de identidad nacional contra el regex del `country-rules/{iso}.toml`.
`kind` acepta: `CI`, `NIT`, `DNI`, `CPF`, `CNPJ`, `CUIT`, `PASSPORT`.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 5,
  "method": "bi18n.validate.national_id",
  "params": {
    "ctx_id": "ctx-003",
    "value": "7654321-LP",
    "kind": "CI",
    "country": "BO"
  }
}
```

**Response (válido):**
```json
{ "result": { "valid": true, "normalized": "7654321-LP", "errores": [] } }
```

**Response (inválido — mensaje Fluent localizado):**
```json
{ "result": { "valid": false, "normalized": "", "errores": ["Cédula de identidad boliviana inválida. Formato esperado: 7654321-LP."] } }
```

**bi18nctl:** `bi18nctl validar-id 7654321-LP --tipo CI --pais BO`

---

### §4.6 `bi18n.mask.value`

Enmascara un valor individual con la estrategia indicada.

**Estrategias disponibles:** `none`, `full`, `partial(N)`, `prefix(N)`, `partial_both(P,S)`, `country_rule`.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 6,
  "method": "bi18n.mask.value",
  "params": {
    "ctx_id": "ctx-004",
    "value": "7654321-LP",
    "strategy": "partial(4)",
    "country": "BO",
    "kind": "CI"
  }
}
```

**Response:**
```json
{ "result": { "masked": "****321-LP" } }
```

**bi18nctl:** `bi18nctl mask-valor 7654321-LP --estrategia parcial`

---

### §4.7 `bi18n.mask.pii`

Detecta y enmascara automáticamente emails y teléfonos en texto libre.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 7,
  "method": "bi18n.mask.pii",
  "params": {
    "ctx_id": "ctx-005",
    "text": "Contactar a juan@empresa.com o al +59171234567 para más info.",
    "mask_emails": true,
    "mask_phones": true
  }
}
```

**Response:**
```json
{
  "result": {
    "redacted": "Contactar a [EMAIL] o al [TELEFONO] para más info.",
    "campos_redactados": 2
  }
}
```

**bi18nctl:** `bi18nctl mask-pii "Texto con juan@empresa.com y +59171234567"`

---

### §4.8 `bi18n.format.date`

Formatea una fecha/hora ISO 8601 al locale del tenant usando ICU4X + datos CLDR.
Convierte a la zona horaria del tenant con jiff (IANA tzdb).

**Valores de `granularity`:** `FechaHora` (default), `SoloFecha`, `MesAnio`, `SoloAnio`, `SoloHora`.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 8,
  "method": "bi18n.format.date",
  "params": {
    "ctx_id": "ctx-006",
    "iso_datetime": "2026-07-17T14:30:00Z",
    "granularity": "SoloFecha",
    "locale": "es-BO",
    "timezone": "America/La_Paz"
  }
}
```

**Response:**
```json
{ "result": { "display": "17 de julio de 2026", "timezone": "America/La_Paz", "locale": "es-BO" } }
```

**bi18nctl:** `bi18nctl format-fecha 2026-07-17T14:30:00Z --granularidad SoloFecha --locale es-BO`

---

### §4.9 `bi18n.format.number`

Formatea un número decimal con los separadores del locale del tenant.
Bolivia: `.` decimal, `,` miles (bo.toml toma prioridad sobre CLDR).

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 9,
  "method": "bi18n.format.number",
  "params": {
    "ctx_id": "ctx-007",
    "value": "1234567.89",
    "decimales": 2,
    "locale": "es-BO",
    "country": "BO"
  }
}
```

**Response:**
```json
{ "result": { "display": "1,234,567.89" } }
```

**bi18nctl:** `bi18nctl format-numero 1234567.89 --decimales 2 --locale es-BO`

---

### §4.10 `bi18n.format.money`

Formatea un monto con el símbolo y decimales del país del tenant (desde country-rules TOML).

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 10,
  "method": "bi18n.format.money",
  "params": {
    "ctx_id": "ctx-008",
    "amount": "1234.56",
    "currency_code": "BOB",
    "locale": "es-BO",
    "country": "BO"
  }
}
```

**Response:**
```json
{ "result": { "display": "Bs. 1,234.56", "symbol_local": "Bs." } }
```

**bi18nctl:** `bi18nctl format-monto 1234.56 --moneda BOB --locale es-BO`

---

### §4.11 `bi18n.enum.display`

Traduce un valor de enum de negocio a su etiqueta localizada (desde `[enum_display]` del TOML del país).

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 11,
  "method": "bi18n.enum.display",
  "params": {
    "ctx_id": "ctx-009",
    "enum_name": "ESTADO_CIVIL",
    "value": "CASADO",
    "locale": "es-BO"
  }
}
```

**Response:**
```json
{ "result": { "label": "Casado/a", "found": true, "fallback": false } }
```

Si `found=false` y `fallback=true`, `label` contiene el valor original sin traducir.

**bi18nctl:** `bi18nctl enum-display ESTADO_CIVIL CASADO --locale es-BO`

---

### §4.12 `bi18n.regional.snapshot`

Retorna el snapshot completo de configuración regional de un tenant:
locale, timezone, currency, numeración, documentos, enums y máscaras.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 12,
  "method": "bi18n.regional.snapshot",
  "params": {
    "ctx_id": "ctx-010",
    "tenant_id": "empresa-sa"
  }
}
```

**Response (extracto):**
```json
{
  "result": {
    "locale": "es-BO",
    "timezone": "America/La_Paz",
    "currency": "BOB",
    "country": "BO",
    "separadores": { "decimal": ".", "miles": "," },
    "documentos": ["CI", "NIT", "PASSPORT"],
    "enums_disponibles": ["ESTADO_CIVIL", "GENERO", "TIPO_SANGRE", "..."]
  }
}
```

**bi18nctl:** `bi18nctl snapshot --tenant empresa-sa`

---

### §4.13 `bi18n.attr.pipeline`

Pipeline completo para un atributo: **validar → transformar → formatear → enmascarar**.
Es el método principal del Motor de Identidad (bAuth lo invoca en el flujo de AtomLang).

| Alias soportado | Equivale a |
|---|---|
| `field_id` | `key` |
| `validator_profile` | `validate_format` + `format_code` |

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 13,
  "method": "bi18n.attr.pipeline",
  "params": {
    "ctx_id": "ctx-011",
    "field_id": "ci_numero",
    "value": "7654321-lp",
    "validator_profile": "ID_BO",
    "mask": "partial(4)",
    "transforms": ["trim", "uppercase"],
    "locale": "es-BO",
    "country": "BO",
    "timezone": "America/La_Paz",
    "currency": "BOB"
  }
}
```

**Response:**
```json
{
  "result": {
    "raw": "7654321-lp",
    "valid": true,
    "transformed": "7654321-LP",
    "display": "7654321-LP",
    "masked": "****321-LP",
    "validation_errors": []
  }
}
```

**bi18nctl:** `bi18nctl attr-pipeline ci_numero 7654321-lp --tenant empresa-sa`

---

### §4.14 `bi18n.attr.build`

Pipeline simplificado: **transformar → formatear → enmascarar** (sin validación).
Útil cuando el atributo ya fue validado en un paso anterior.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 14,
  "method": "bi18n.attr.build",
  "params": {
    "ctx_id": "ctx-012",
    "key": "fecha_nacimiento",
    "value": "1990-05-15T00:00:00Z",
    "format_code": "FECHA_LARGA",
    "mask": "none",
    "locale": "es-BO",
    "timezone": "America/La_Paz",
    "currency": "BOB",
    "country": "BO"
  }
}
```

**Response:**
```json
{ "result": { "raw": "1990-05-15T00:00:00Z", "display": "15 de mayo de 1990", "masked": "15 de mayo de 1990" } }
```

---

### §4.15 `bi18n.attr.config`

Retorna la configuración de presentación de un atributo por `display_format`:
qué perfil de validación aplicar, qué máscara, qué patrón de input, si es PII.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 15,
  "method": "bi18n.attr.config",
  "params": {
    "ctx_id": "ctx-013",
    "display_format": "ID_BO",
    "locale": "es-BO"
  }
}
```

**Response:**
```json
{
  "result": {
    "display_format": "ID_BO",
    "validator_profile": "ID_BO",
    "mask_pattern": "partial(4)",
    "input_mask": "99999999-AA",
    "masks_pii": true
  }
}
```

---

### §4.16 `bi18n.attr.config_batch`

Retorna configuración para un lote de atributos en una sola llamada.
Resuelve el locale UNA SOLA VEZ antes de iterar campos — eficiente para formularios grandes.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 16,
  "method": "bi18n.attr.config_batch",
  "params": {
    "ctx_id": "ctx-014",
    "tenant_id": "empresa-sa",
    "fields": ["ci_numero", "fecha_nacimiento", "telefono_celular", "email"]
  }
}
```

**Response:**
```json
{
  "result": {
    "locale": "es-BO",
    "country": "BO",
    "text_direction": "ltr",
    "campos": [
      { "key": "ci_numero", "display_format": "ID_BO", "validator_profile": "ID_BO", "mask_pattern": "partial(4)", "input_mask": "99999999-AA", "masks_pii": true },
      { "key": "fecha_nacimiento", "display_format": "FECHA", "validator_profile": "FECHA", "mask_pattern": "none", "input_mask": "99/99/9999", "masks_pii": false },
      { "key": "telefono_celular", "display_format": "TELEFONO", "validator_profile": "TELEFONO", "mask_pattern": "partial(4)", "input_mask": "+9999999999", "masks_pii": true },
      { "key": "email", "display_format": "EMAIL", "validator_profile": "EMAIL", "mask_pattern": "partial(4)", "input_mask": null, "masks_pii": true }
    ]
  }
}
```

---

### §4.17 `bi18n.admin.reload`

Recarga tanto las `country-rules/*.toml` como el `FluentBundle` (mensajes FTL) sin reiniciar
el daemon. Equivalente a un SIGHUP pero por RPC.

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 17,
  "method": "bi18n.admin.reload",
  "params": { "ctx_id": "ops-001" }
}
```

**Response:**
```json
{
  "result": {
    "recargado": true,
    "paises_cargados": 3,
    "country_rules": "ok",
    "fluent": "ok"
  }
}
```

**bi18nctl:** `bi18nctl recargar`

**Cuándo usarlo:** después de modificar un archivo `country-rules/*.toml` en el servidor.

---

### §4.18 `bi18n.admin.reload_translations`

Recarga **solo los archivos FTL** de traducciones sin recargar country-rules.
Swap atómico con `ArcSwap` — cero tiempo de parada, cero bloqueo de lectores.
Si los FTL tienen errores de sintaxis, se mantiene la versión anterior (rollback implícito).

**⚠️ Seguridad:** no exponer en ruta pública de Kong. Solo accesible por socket Unix (CI/deploy).

**Request:**
```json
{
  "jsonrpc": "2.0", "id": 18,
  "method": "bi18n.admin.reload_translations",
  "params": { "ctx_id": "ci-deploy-001" }
}
```

**Response:**
```json
{
  "result": {
    "recargado": true,
    "locale": "es-BO",
    "mensaje": "traducciones recargadas sin interrupción de servicio"
  }
}
```

**bi18nctl:** `bi18nctl recargar-traducciones`

---

## §5 CLI bi18nctl

### Instalación

```bash
# En el servidor VPS donde corre bi18nd:
# El binario bi18nctl se instala junto a bi18nd en /usr/local/bin/
which bi18nctl   # /usr/local/bin/bi18nctl
```

### Flags transversales

```bash
bi18nctl [FLAGS] <subcomando> [args]

FLAGS:
  --socket <ruta>     Socket Unix del daemon (default: /run/bos/bi18n.sock)
  --json              Imprime JSON crudo (para scripts y CI/CD)
  --quiet             Solo exit code: 0=ok, 1=inválido, 2=error
  --ctx-id <uuid>     ctx_id explícito (default: UUID v4 generado automáticamente)
```

### Referencia rápida de subcomandos

| Subcomando | Método RPC | Ejemplo |
|---|---|---|
| `estado` | `bi18n.health.check` | `bi18nctl estado` |
| `recargar` | `bi18n.admin.reload` | `bi18nctl recargar` |
| `recargar-traducciones` | `bi18n.admin.reload_translations` | `bi18nctl recargar-traducciones` |
| `locale-resolver` | `bi18n.locale.resolve` | `bi18nctl locale-resolver --tenant acme-sa` |
| `validar-email` | `bi18n.validate.email` | `bi18nctl validar-email user@corp.com` |
| `validar-telefono` | `bi18n.validate.phone` | `bi18nctl validar-telefono +59171234567` |
| `validar-id` | `bi18n.validate.national_id` | `bi18nctl validar-id 7654321-LP --tipo CI --pais BO` |
| `mask-valor` | `bi18n.mask.value` | `bi18nctl mask-valor 7654321-LP --estrategia parcial` |
| `mask-pii` | `bi18n.mask.pii` | `bi18nctl mask-pii "Texto con PII"` |
| `format-fecha` | `bi18n.format.date` | `bi18nctl format-fecha 2026-07-17T14:30:00Z` |
| `format-numero` | `bi18n.format.number` | `bi18nctl format-numero 1234567.89` |
| `format-monto` | `bi18n.format.money` | `bi18nctl format-monto 1234.56 --moneda BOB` |
| `enum-display` | `bi18n.enum.display` | `bi18nctl enum-display ESTADO_CIVIL CASADO` |
| `snapshot` | `bi18n.regional.snapshot` | `bi18nctl snapshot --tenant acme-sa` |
| `attr-pipeline` | `bi18n.attr.pipeline` | `bi18nctl attr-pipeline ci_numero 7654321-LP` |
| `translations check-parity` | local (sin daemon) | `bi18nctl translations check-parity` |

### Subcomando local: `translations check-parity`

No requiere el daemon activo. Opera sobre el sistema de archivos directamente.

```bash
# Verificar paridad — muestra diferencias pero no falla
bi18nctl translations check-parity --reference es-BO --locales-dir locales

# Con fallo en CI (exit 1 si faltan claves)
bi18nctl translations check-parity --reference es-BO --locales-dir locales --fail-on-missing

# Output JSON para scripts
bi18nctl --json translations check-parity --reference es-BO --locales-dir locales
```

---

## §6 Configuración — bi18n.toml

El archivo de configuración se carga desde `$BI18N_CONFIG` o `/etc/bos/bi18n.toml`.

```toml
# /etc/bos/bi18n.toml — configuración del daemon bi18nd

[regional]
locale   = "es-BO"
timezone = "America/La_Paz"
currency = "BOB"
country  = "BO"

[servidor]
socket_path       = "/run/bos/bi18n.sock"
grpc_socket_path  = "/run/bos/bi18n-grpc.sock"
ws_bind           = "127.0.0.1:9454"
ws_rate_limit_rps = 100
ws_timeout_ms     = 5000
drain_timeout_secs = 30

[rutas]
country_rules_dir = "/etc/bos/bi18n/country-rules"
fluent_dir        = "/etc/bos/bi18n/locales"

[log]
level  = "info"   # trace|debug|info|warn|error
format = "json"   # json|pretty
```

### Variables de entorno

| Variable | Efecto |
|---|---|
| `BI18N_CONFIG` | Ruta al archivo TOML de configuración |
| `RUST_LOG` | Nivel de log (sobreescribe `[log].level`) |
| `NOTIFY_SOCKET` | Socket systemd sd_notify (gestionado por systemd) |

---

## §7 Despliegue

### Instalación básica

```bash
# 1. Copiar binarios
install -m 755 bi18nd      /usr/local/bin/bi18nd
install -m 755 bi18nctl    /usr/local/bin/bi18nctl

# 2. Crear directorio de configuración
mkdir -p /etc/bos/bi18n/country-rules
mkdir -p /etc/bos/bi18n/locales/es-BO

# 3. Copiar archivos de país y traducciones
cp country-rules/*.toml /etc/bos/bi18n/country-rules/
cp -r locales/*         /etc/bos/bi18n/locales/

# 4. Instalar unit systemd
install -m 644 deploy/bi18nd.service /etc/systemd/system/bi18nd.service
systemctl daemon-reload
systemctl enable --now bi18nd

# 5. Verificar
systemctl status bi18nd
bi18nctl estado
```

### Verificación de arranque

```bash
# Estado systemd
systemctl is-active bi18nd   # → active

# Salud del daemon
bi18nctl estado               # → status: ok, paises_cargados: 3

# Socket accesible
ls -la /run/bos/bi18n.sock    # → srw-rw---- bos bosagent
```

### Alta disponibilidad (HA)

Para despliegue con 2+ réplicas detrás de Kong, ver:
`deploy/DESPLIEGUE-HA.md` — contiene configuración Kong upstream, plantilla `bi18nd@.service`,
volumen NFS para locales/ y script de recarga coordinada.

---

## §8 Gestión de traducciones

### Estructura de locales

```
locales/
├── es-BO/main.ftl    # Locale de referencia (fuente de verdad de claves)
├── en-US/main.ftl    # Inglés
└── pt-BR/main.ftl    # Portugués Brasil
```

### Formato FTL (Project Fluent)

```fluent
# Errores de validación
error-ci-invalido = Cédula de identidad boliviana inválida. Formato esperado: { $ejemplo }.
error-email-invalido = Dirección de email inválida.

# Mensajes con plurales
paises-cargados = { $n ->
    [one] 1 país cargado
   *[other] { $n } países cargados
}
```

### Añadir un locale nuevo

```bash
# 1. Crear directorio y traducir el FTL de referencia
mkdir locales/fr-FR
cp locales/es-BO/main.ftl locales/fr-FR/main.ftl
# Editar fr-FR/main.ftl con traducciones al francés

# 2. Verificar paridad de claves
bi18nctl translations check-parity --reference es-BO --locales-dir locales

# 3. Recargar traducciones en el daemon
bi18nctl recargar-traducciones
```

### Hot-reload automático

El daemon vigila los archivos FTL con inotify (Linux). Si detecta un cambio en `*.ftl`,
recarga automáticamente en < 100ms. No se necesita reiniciar el daemon ni llamar a
`recargar-traducciones` manualmente cuando se edita en el servidor directamente.

---

## §9 Protocolo WebSocket

Documentación formal: `context/Documentacion/anexos/A.07_ANEXO-BI18N-PROTOCOLO-WEBSOCKET-v1.0.md`

**Resumen de conexión:**
```bash
# Ejemplo con websocat (herramienta de prueba)
websocat ws://localhost:9454/bi18n

# Handshake JWT
{"type":"auth","token":"Bearer <JWT>"}

# Llamada
{"jsonrpc":"2.0","id":1,"method":"bi18n.health.check","params":{"ctx_id":"ws-test-001"}}
```

El WebSocket es el transporte recomendado para clientes UI remotos que acceden a bi18n
a través de Kong. Los daemons SBOS internos usan el Unix socket directamente.

---

## §10 Países soportados

| País | Código | Locale | Documentos | Moneda |
|---|---|---|---|---|
| Bolivia | BO | es-BO | CI, NIT, PASSPORT | BOB (Bs.) |
| Argentina | AR | es-AR | DNI, CUIT, CUIL, CDI, PASSPORT | ARS ($) |
| Brasil | BR | pt-BR | CPF, CNPJ, RG, CNH, TITULO_ELEITOR, PASSPORT | BRL (R$) |

Para agregar un nuevo país, crear `country-rules/{iso2}.toml` siguiendo la estructura de
`country-rules/bo.toml` como referencia. Ver `A.01 §2.9` para las secciones TOML requeridas.

---

## Historial

| Versión | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-17 | Creación. Bloque 12.2. Manual completo: 18 métodos RPC, bi18nctl CLI, configuración, despliegue, traducciones, WebSocket, 3 países. |
