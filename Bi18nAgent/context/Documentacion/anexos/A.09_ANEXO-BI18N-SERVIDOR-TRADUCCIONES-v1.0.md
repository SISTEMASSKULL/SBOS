# A.09 — bi18n como Servidor Canónico de Traducciones de Lenguajes

**Tipo:** A/G — arquitectura + guía de consumo
**Versión del anexo:** 1.2.0
**Fecha:** 2026-07-17
**Respalda a:** [1.01 Manual de Arquitectura](../1.01_MANUAL-BI18N-ARQUITECTURA-v1.2.md) · [A.06 Daemon de Traducciones](A.06_ANEXO-BI18N-DAEMON-TRADUCCIONES-v1.1.md) · [A.08.01 Inventario fluent-bundle](A.08.01_INVENTARIO-LIB-FLUENT-BUNDLE-v1.0.md) · [A.08.02 Inventario rust-i18n](A.08.02_INVENTARIO-LIB-RUST-I18N-v1.0.md)
**Relacionado con:** [REGISTRO-ESTADO-DOS Bloques A y B](../REGISTRO-ESTADO-DOS.md)

---

## Tabla de contenidos

1. [El problema — por qué un servidor centralizado](#1-el-problema--por-qué-un-servidor-centralizado)
2. [El rol arquitectónico — bi18n como SSOT de traducciones](#2-el-rol-arquitectónico--bi18n-como-ssot-de-traducciones)
3. [Locales soportados y ciclo de vida](#3-locales-soportados-y-ciclo-de-vida)
4. [Estructura de archivos FTL](#4-estructura-de-archivos-ftl)
5. [Namespacing de claves — convención para múltiples daemons](#5-namespacing-de-claves--convención-para-múltiples-daemons)
6. [Resolución de locale — jerarquía y fallback](#6-resolución-de-locale--jerarquía-y-fallback)
7. [Métodos RPC de traducción](#7-métodos-rpc-de-traducción)
8. [Contrato de consumo para daemons SBOS](#8-contrato-de-consumo-para-daemons-sbos)
9. [Integración con bglobal](#9-integración-con-bglobal)
10. [Cumplimiento normativo](#10-cumplimiento-normativo)
11. [Plataforma web de gestión de traducciones — Weblate](#11-plataforma-web-de-gestión-de-traducciones--weblate)

---

## §1 El problema — por qué un servidor centralizado

Sin bi18n, cada daemon o aplicación de SBOS tiene dos caminos igualmente malos:

| Opción | Problema |
|---|---|
| Cada daemon tiene su propio motor i18n | Siete motores distintos, siete formatos de archivos, siete políticas de fallback — texto del mismo sistema en idiomas distintos según qué pantalla, sin gobernanza unificada |
| El texto está hardcodeado | Imposible desplegar el sistema en otro idioma sin recompilación — inviable para un ERP soberano multi-país |

**bi18n resuelve ambos problemas con una sola decisión arquitectónica:** existe un único servidor de traducciones que todo el ecosistema invoca. Cualquier string que el sistema muestre al usuario pasa por bi18n — sin excepción.

---

## §2 El rol arquitectónico — bi18n como SSOT de traducciones

bi18n es el **único servidor autorizado de traducciones de cadenas de texto de interfaz para todo el ecosistema SBOS.**

```
                    ┌──────────────────────────────────────┐
                    │           bi18nd                     │
                    │   Servidor Canónico de Traducciones  │
                    │                                      │
                    │  ┌─────────────┐ ┌────────────────┐  │
                    │  │ fluent-bundle│ │   rust-i18n    │  │
                    │  │  FTL + args │ │  TOML + macros │  │
                    │  └─────────────┘ └────────────────┘  │
                    │        ↑ ArcSwap hot-reload           │
                    └──────────────┬───────────────────────┘
                                   │ JSON-RPC 2.0
                    ┌──────────────┴───────────────────────┐
                    │                                       │
        ┌───────────▼──────────┐            ┌──────────────▼────────────┐
        │   Daemons SBOS       │            │   Aplicaciones y frontends │
        │  bAuth, btax, bcms,  │            │  dashboard, web, móvil,    │
        │  bpay, bnotify…      │            │  CLI, reportes, correos     │
        └──────────────────────┘            └───────────────────────────┘
```

### 2.1 Principio fundamental

**ningún componente de SBOS posee traducciones propias** — todas las cadenas de UI, mensajes de error, etiquetas de campos, opciones de enum y textos de notificación viven en bi18n y solo en bi18n.

Un daemon como bAuth puede tener mensajes de error (`credenciales incorrectas`, `token expirado`) pero el texto visible para el usuario siempre lo resuelve bi18n, no bAuth:

```
bAuth: validación fallida → emite código "AUTH_CREDENTIALS_INVALID"
               ↓
bi18n.translate.message(locale="es-BO", id="auth.credenciales-invalidas")
               ↓
bi18n devuelve: "Las credenciales proporcionadas son incorrectas."
               ↓
bAuth (o el frontend) muestra esa cadena al usuario
```

### 2.2 Qué traduce bi18n y qué no traduce

| Tipo de texto | ¿Lo traduce bi18n? | Fuente |
|---|---|---|
| Mensajes de UI (botones, etiquetas, títulos) | ✅ Sí | FTL por módulo |
| Mensajes de error visibles al usuario | ✅ Sí | FTL por daemon |
| Notificaciones y correos | ✅ Sí | FTL con args |
| Opciones de enum de negocio (género, estado, tipo) | ✅ Sí | `country-rules/*.toml` (§5.3) |
| Logs internos del sistema | ❌ No | Inglés técnico en el binario |
| Mensajes de audit trail (ISO 27001) | ❌ No | Inglés técnico en el binario |
| Comentarios y documentación interna | ❌ No | Español (CLAUDE.md regla idioma) |
| Patrones de documentos nacionales (CI, NIT) | ❌ No | `country-rules/*.toml` (A.01) |

---

## §3 Locales soportados y ciclo de vida

### 3.1 Locales activos (Fase 1)

| Código BCP 47 | Idioma | País/Región | Estado |
|---|---|---|---|
| `es-BO` | Español | Bolivia | ✅ Activo — locale principal |
| `en-US` | Inglés | Estados Unidos | ✅ Activo — fallback universal |

### 3.2 Locales planificados (Fase 3 — multi-tenant regional)

| Código BCP 47 | Idioma | País/Región |
|---|---|---|
| `es-AR` | Español | Argentina |
| `pt-BR` | Portugués | Brasil |
| `es-MX` | Español | México |
| `es-PE` | Español | Perú |
| `es-CL` | Español | Chile |
| `es-CO` | Español | Colombia |

### 3.3 Cómo agregar un locale nuevo

1. Crear el archivo de traducciones: `translations/<codigo-bcp47>.ftl` (o `.toml` para rust-i18n).
2. Copiar todas las claves del locale base (`es-BO`) con valores vacíos — herramienta: `bi18nctl translations check-parity`.
3. Traducir las claves vía Weblate (A.06 §2) o PR directo con revisión.
4. El gate de CI verificará paridad de claves antes de merge.
5. SIGHUP o `bi18n.admin.reload_translations` activa el nuevo locale sin redeploy.

**Regla:** un locale nunca queda activo con claves faltantes. El gate de CI bloquea el merge si `check-parity` reporta claves ausentes respecto al locale base (`es-BO`).

---

## §4 Estructura de archivos FTL

bi18n usa **Project Fluent** (FTL) como formato primario de traducciones, con rust-i18n TOML como formato secundario para traducciones simples (sin plurales ni géneros complejos).

### 4.1 Árbol de archivos

```
translations/
├── es-BO/                          # Locale base — todas las claves deben estar aquí
│   ├── common.ftl                  # Cadenas compartidas por todo el sistema
│   ├── bauth.ftl                   # Cadenas propias del módulo de identidad
│   ├── btax.ftl                    # Cadenas propias del módulo fiscal
│   ├── bcms.ftl                    # Cadenas propias del módulo de contenido
│   ├── bpay.ftl                    # Cadenas propias del módulo de pago
│   ├── bnotify.ftl                 # Cadenas propias de notificaciones
│   └── errors.ftl                  # Mensajes de error del sistema
├── en-US/                          # Fallback universal
│   ├── common.ftl
│   ├── bauth.ftl
│   └── ...
└── es-AR/                          # Locale regional (cuando se activa)
    └── ...
```

### 4.2 Formato FTL — reglas de escritura

**FTL soporta plurales, géneros, variables e interpolación.** Todo lo que no requiere lógica va en FTL:

```ftl
# Cadena simple
boton-guardar = Guardar

# Con variable de interpolación
bienvenida = Bienvenido, { $nombre }

# Con plural
registros-encontrados = { $total ->
    [one]  Se encontró { $total } registro
   *[other] Se encontraron { $total } registros
}

# Con atributo (tooltip, placeholder, aria-label juntos)
campo-ci =
    .label = Cédula de Identidad
    .placeholder = 7654321-LP
    .tooltip = Formato: números + letra departamento

# Error
error-credenciales = Las credenciales proporcionadas son incorrectas.
    Verifique su usuario y contraseña e intente nuevamente.
```

### 4.3 Qué no va en FTL

- Patrones de documentos nacionales (CI, NIT, placa) → `country-rules/*.toml`
- Opciones de enum que varían por país → `country-rules/*.toml [enum_display]`
- Configuración de formato de fechas y monedas → ICU4X vía `bi18n.format.*`
- Mensajes de log técnico → hardcodeados en inglés en el binario (no son strings de UI)

---

## §5 Namespacing de claves — convención para múltiples daemons

### 5.1 El problema del espacio de nombres

Si `bAuth` y `btax` ambos tienen una clave llamada `error-no-encontrado`, colisionan en el mismo bundle. La convención de namespacing evita esto sin necesidad de bundles separados por daemon.

### 5.2 Convención canónica de nombres de clave

```
<módulo>.<componente>.<descripción-kebab-case>
```

| Segmento | Regla | Ejemplos |
|---|---|---|
| `<módulo>` | Nombre del daemon o área de negocio | `bauth`, `btax`, `bcms`, `bpay`, `bnotify`, `common` |
| `<componente>` | Pantalla, formulario o entidad | `login`, `usuario`, `factura`, `rol` |
| `<descripción>` | Acción o concepto en kebab-case | `boton-guardar`, `error-campo-requerido`, `titulo-pagina` |

```ftl
# bauth.ftl — módulo de identidad
bauth.login.titulo = Acceso al Sistema
bauth.login.boton-ingresar = Ingresar
bauth.login.error-credenciales = Credenciales incorrectas
bauth.login.enlace-recuperar = Recuperar contraseña
bauth.usuario.titulo-perfil = Perfil de Usuario
bauth.usuario.boton-guardar = Guardar Cambios
bauth.rol.etiqueta-nombre = Nombre del Rol
bauth.error.token-expirado = Su sesión ha expirado. Por favor, ingrese nuevamente.
bauth.error.permiso-denegado = No tiene permiso para realizar esta acción.

# btax.ftl — módulo fiscal
btax.factura.titulo = Factura Electrónica
btax.factura.boton-emitir = Emitir Factura
btax.factura.error-nit-invalido = El NIT ingresado no es válido.

# common.ftl — compartido
common.boton-cancelar = Cancelar
common.boton-confirmar = Confirmar
common.error-conexion = Error de conexión. Intente nuevamente.
common.cargando = Cargando...
```

### 5.3 Enums de negocio — fuente TOML, servidos por bi18n

Los enums de negocio (género, tipo de persona, estado civil, etc.) se definen en `country-rules/*.toml` bajo la sección `[enum_display]` porque sus opciones pueden variar por país. bi18n los sirve vía `bi18n.enum.display`:

```toml
# country-rules/bo.toml
[enum_display.gender]
M = "Masculino"
F = "Femenino"
NB = "No binario"
ND = "Prefiero no decir"

[enum_display.persona_tipo]
NATURAL = "Persona Natural"
JURIDICA = "Persona Jurídica"
EXTRANJERO = "Persona Extranjera"

[enum_display.estado_civil]
SOLTERO = "Soltero/a"
CASADO = "Casado/a"
DIVORCIADO = "Divorciado/a"
VIUDO = "Viudo/a"
UNION_LIBRE = "Unión libre"
```

---

## §6 Resolución de locale — jerarquía y fallback

### 6.1 Jerarquía de resolución (por request)

Cada llamada a bi18n lleva el locale en los parámetros — bi18n no lo resuelve de forma autónoma, sino que el consumidor (el daemon o frontend) le pasa el locale ya resuelto:

```
Consumidor resuelve locale:
  1. Preferencia del usuario   (ej. "en-US" configurada por el propio usuario)
          ↓ si no definida
  2. Configuración de sucursal (ej. una sucursal opera en otro país)
          ↓ si no definida
  3. Configuración del tenant  (ej. empresa con locale corporativo "es-BO")
          ↓ si no definida
  4. Default del sistema       ("es-BO" — locale base del ecosistema)

Consumidor llama:
  bi18n.translate.message(locale="es-BO", id="bauth.login.titulo")
```

**Regla:** el consumidor es responsable de resolver el locale antes de llamar a bi18n. bi18n recibe un locale ya determinado, no decide cuál aplicar. Esta separación mantiene bi18n sin estado de sesión.

### 6.2 Fallback de idioma

Si la clave no existe en el locale solicitado, bi18n aplica la siguiente cadena de fallback:

```
Locale solicitado: "es-AR"
  → 1. Buscar en translations/es-AR/
  → 2. Si no encontrada: buscar en translations/es-BO/   (fallback regional)
  → 3. Si no encontrada: buscar en translations/en-US/   (fallback universal)
  → 4. Si no encontrada: devolver { "text": null, "fallback": true, "error": "MSG_NOT_FOUND" }
```

**Nunca se devuelve la clave cruda** (ej. `"bauth.login.titulo"`) como fallback visible — eso indica un bug en el código del consumidor. El campo `fallback: true` en la respuesta permite que el consumidor decida si loguear la degradación de experiencia.

### 6.3 Tabla de comportamiento por escenario

| Escenario | Resultado |
|---|---|
| Locale + clave existen | Texto en el locale solicitado, `fallback: false` |
| Locale existe, clave ausente | Texto en locale de fallback, `fallback: true` |
| Locale inexistente | Error inmediato (`LOCALE_NOT_AVAILABLE`), no fallback silencioso |
| Clave con args, args faltantes | Fluent sustituye con `{$arg}` literal — logueable, no fatal |
| Bundle en hot-reload mientras se lee | ArcSwap garantiza vista consistente — nunca estado parcial |

---

## §7 Métodos RPC de traducción

Los métodos de traducción se agrupan en dos namespaces según su librería subyacente.

### 7.1 Namespace `bi18n.translate.*` — fluent-bundle (FTL)

| Método | Descripción | Params | Retorno |
|---|---|---|---|
| `bi18n.translate.message` | Traduce una clave simple | `ctx_id`, `locale`, `id` | `{ "text": "...", "fallback": bool }` |
| `bi18n.translate.message_with_args` | Traduce con variables de interpolación | `ctx_id`, `locale`, `id`, `args: {}` | `{ "text": "...", "fallback": bool }` |
| `bi18n.translate.batch` | Traduce múltiples claves de una vez | `ctx_id`, `locale`, `ids: []` | `{ "texts": { "id": "..." }, "fallbacks": [] }` |
| `bi18n.translate.has_message` | Comprueba si una clave existe en el locale | `ctx_id`, `locale`, `id` | `{ "exists": bool }` |
| `bi18n.translate.list_messages` | Lista todas las claves disponibles en un locale | `ctx_id`, `locale` | `{ "ids": ["..."] }` |
| `bi18n.translate.message_attribute` | Obtiene un atributo FTL de una clave (label, placeholder, tooltip) | `ctx_id`, `locale`, `id`, `attr` | `{ "text": "..." }` |

**Ejemplos:**

```json
// Traducción simple
→ {"jsonrpc":"2.0","id":1,"method":"bi18n.translate.message","params":{
    "ctx_id":"a1b2-...","locale":"es-BO","id":"bauth.login.titulo"}}
← {"jsonrpc":"2.0","result":{"text":"Acceso al Sistema","fallback":false},"id":1}

// Traducción con variables
→ {"jsonrpc":"2.0","id":2,"method":"bi18n.translate.message_with_args","params":{
    "ctx_id":"a1b2-...","locale":"es-BO",
    "id":"bauth.usuario.bienvenida",
    "args":{"nombre":"María","rol":"Administradora"}}}
← {"jsonrpc":"2.0","result":{"text":"Bienvenida, María. Rol: Administradora","fallback":false},"id":2}

// Batch — una sola llamada para cargar una pantalla completa
→ {"jsonrpc":"2.0","id":3,"method":"bi18n.translate.batch","params":{
    "ctx_id":"a1b2-...","locale":"es-BO",
    "ids":["bauth.login.titulo","bauth.login.boton-ingresar","common.boton-cancelar"]}}
← {"jsonrpc":"2.0","result":{
    "texts":{"bauth.login.titulo":"Acceso al Sistema",
             "bauth.login.boton-ingresar":"Ingresar",
             "common.boton-cancelar":"Cancelar"},
    "fallbacks":[]},"id":3}

// Atributos de un campo (label + placeholder + tooltip en una llamada)
→ {"jsonrpc":"2.0","id":4,"method":"bi18n.translate.message_attribute","params":{
    "ctx_id":"a1b2-...","locale":"es-BO","id":"bauth.campo-ci","attr":"placeholder"}}
← {"jsonrpc":"2.0","result":{"text":"7654321-LP"},"id":4}
```

### 7.2 Namespace `bi18n.i18n.*` — rust-i18n (TOML)

| Método | Descripción | Params | Retorno |
|---|---|---|---|
| `bi18n.i18n.locale_activo` | Informa el locale activo del daemon | `ctx_id` | `{ "locale": "es-BO" }` |
| `bi18n.i18n.locales_disponibles` | Lista los locales cargados en memoria | `ctx_id` | `{ "locales": ["es-BO","en-US"] }` |
| `bi18n.i18n.set_locale` | Cambia el locale activo del daemon (afecta macros `t!`) | `ctx_id`, `locale` | `{ "ok": true }` |
| `bi18n.i18n.t` | Traduce una clave con el motor rust-i18n | `ctx_id`, `key`, `locale?`, `args?: {}` | `{ "text": "..." }` |

**Cuándo usar cada namespace:**

| Situación | Namespace recomendado |
|---|---|
| Cadenas con plurales, géneros, variables complejas | `bi18n.translate.*` (fluent-bundle, FTL) |
| Traducciones simples clave→valor sin lógica | `bi18n.i18n.t` (rust-i18n, TOML) |
| Introspección (¿qué locales hay disponibles?) | `bi18n.i18n.locales_disponibles` |
| Batch de múltiples claves en una pantalla | `bi18n.translate.batch` |
| Atributos de campos (label, placeholder, tooltip) | `bi18n.translate.message_attribute` |

---

## §8 Contrato de consumo para daemons SBOS

### 8.1 El daemon como cliente de bi18n

Cualquier daemon SBOS que necesite mostrar texto al usuario sigue este protocolo:

```
┌─────────────────────────────────────────────────────────────────────┐
│  CONTRATO DE CONSUMO bi18n — reglas irrenunciables                  │
├─────────────────────────────────────────────────────────────────────┤
│ 1. Ningún daemon tiene strings de UI hardcodeadas en su código      │
│ 2. El locale se pasa en cada llamada — nunca se asume un global     │
│ 3. Se usa bi18n.translate.batch para cargar pantallas completas     │
│ 4. Los errores de traducción (clave no encontrada) se loguean       │
│    pero no bloquean — se muestra la clave como último recurso solo  │
│    en modo de emergencia, con log explícito de degradación          │
│ 5. Los enums se traducen siempre con bi18n.enum.display             │
│ 6. El ctx_id se propaga en cada llamada a bi18n                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 8.2 Dos formas de consumo

| Forma | Cuándo | Cómo |
|---|---|---|
| **JSON-RPC sobre Unix socket** | Daemons de SBOS (bAuth, btax, bcms, bpay, bnotify) que corren en el mismo VPS | `{"method":"bi18n.translate.message","params":{...}}` sobre `/run/bos/bi18n.sock` |
| **Crate directo** (`i18n-orchestrator`) | Componente Rust que necesita alta frecuencia sin overhead de IPC | Dependencia en `Cargo.toml` + llamada de función directa al core |

**Cuándo usar el crate directo:** cuando un daemon Rust valida o formatea en cada fila de un proceso batch masivo (ej. `btax` emitiendo 10 000 facturas). Para uso normal de UI, JSON-RPC es suficiente.

### 8.3 Patrón de integración en un daemon SBOS

```rust
// En el handler de bAuth que devuelve un error al usuario:
async fn manejar_login_fallido(
    ctx: &RequestContext,
    bi18n_client: &Bi18nClient,
    locale: &str,
) -> String {
    bi18n_client
        .translate_message(ctx.ctx_id, locale, "bauth.login.error-credenciales")
        .await
        .unwrap_or_else(|_| {
            // Degradación documentada — nunca silenciosa
            tracing::warn!(ctx_id=%ctx.ctx_id, "bi18n no disponible — usando fallback hardcodeado");
            "Error de autenticación".to_string()
        })
}
```

### 8.4 Patrón batch para carga de pantalla

```rust
// Al abrir la pantalla de login — una sola llamada para todas las cadenas:
let textos = bi18n_client.translate_batch(
    ctx_id,
    locale,
    &[
        "bauth.login.titulo",
        "bauth.login.boton-ingresar",
        "bauth.login.enlace-recuperar",
        "common.boton-cancelar",
    ]
).await?;

// textos["bauth.login.titulo"] = "Acceso al Sistema"
// textos["bauth.login.boton-ingresar"] = "Ingresar"
// ...
```

### 8.5 Comportamiento de degradación (bi18n no disponible)

Si el daemon bi18nd no está disponible (reinicio, fallo transitorio), el consumidor aplica el siguiente orden de degradación:

```
1. Cache local de traducciones (TTL: 60 segundos) → usar si disponible
2. Archivo de traducciones embebido en el binario del daemon (solo es-BO + en-US)
3. Clave técnica como último recurso, con log explícito de degradación
```

**Ningún daemon asume que bi18n siempre estará disponible.** La degradación es parte del contrato — no un estado de error fatal.

---

## §9 Integración con bglobal

El daemon `bglobal` provee el catálogo de idiomas del sistema:

```sql
-- bglobal.global_language
SELECT code_bcp47, nombre_es, direccion_texto, estado
FROM bglobal.global_language
WHERE estado = 'ACTIVO';
```

bi18n consulta `bglobal` para:

| Necesidad | Tabla bglobal | Uso en bi18n |
|---|---|---|
| Nombre del idioma en la UI (`"Español (Bolivia)"`) | `global_language.nombre_es` | Respuesta de `bi18n.i18n.locales_disponibles` |
| Dirección de texto (`LTR`/`RTL`) | `global_language.direccion_texto` | Respuesta de `bi18n.locale.resolve` (campo `text_direction`) |
| Locales habilitados para el tenant | `global_language + tenant config` | Validación de locale solicitado |
| Nombre de moneda/país para UI | `global_currency`, `global_country` | `bi18n.format.money`, `bi18n.locale.resolve` |

**bglobal NO es la fuente de los textos de traducción** — esos viven en los archivos FTL. bglobal es el catálogo de referencia de idiomas (qué idiomas existen, cómo se llaman, en qué dirección se escriben).

---

## §10 Cumplimiento normativo

| Norma | Cómo la cumple este subsistema |
|---|---|
| **ISO 9001:2015 §3.2.4** — cliente como receptor del output | bi18n asegura que todo output textual al usuario está en su idioma esperado |
| **Unicode BCP 47** | Todos los códigos de locale usan BCP 47 (ej. `es-BO`, `pt-BR`, no `es_BO` ni `pt_br`) |
| **Unicode CLDR UTS #35** | El formato de fechas, números y monedas usa patrones CLDR vía ICU4X |
| **W3C Internationalization** | Cadenas FTL soportan bidi, plurales y géneros gramaticales conforme W3C i18n best practices |
| **GDPR Art. 5** — comunicaciones comprensibles | Los mensajes de error y consentimiento se sirven en el idioma del usuario, no del servidor |
| **Ley 164 Bolivia** — soberanía digital | bi18n opera 100% on-premise, sin CDN ni servicios de traducción externos. Los textos son propiedad del cliente |

---

## §11 Plataforma web de gestión de traducciones — Weblate

La plataforma web que permite a personas no técnicas editar traducciones sin tocar Git ni archivos FTL directamente es **Weblate** — self-hosteado en el VPS del cliente.

**URL oficial:** [https://weblate.org/en/](https://weblate.org/en/)

### 11.1 Por qué Weblate para SBOS

| Criterio | Weblate | Razón |
|---|---|---|
| **Soporte FTL/Fluent** | ✅ Nativo — confirmado en v2026.7 | bi18n usa FTL como formato primario |
| **Soporte TOML** | ✅ Sí | bi18n usa TOML para rust-i18n y country-rules |
| **Integración Git** | ✅ Nativa — commitea al repo automáticamente | El flujo de SBOS es Git-céntrico |
| **Licencia self-hosted** | GPLv3+ — sin límite de proyectos ni usuarios | Un ERP multi-módulo y multi-país no puede tener límite de claves |
| **Madurez** | 14 años en producción (2012) | Usado por Debian, Fedora, LibreOffice, 2500+ proyectos |
| **Soberanía** | 100% on-premise, sin nube externa | Ley 164, SBOS soberano |

**Documentación de soporte FTL:** [https://docs.weblate.org/en/latest/formats/fluent.html](https://docs.weblate.org/en/latest/formats/fluent.html)

### 11.2 Comparativa con alternativas evaluadas

| | **Weblate** ✅ Elegido | Tolgee | Pontoon |
|---|---|---|---|
| **URL** | weblate.org | tolgee.io | github/mozilla/pontoon |
| **FTL/Fluent** | ✅ Sí | ❌ No documentado | ✅ Nativo (lo creó Mozilla) |
| **TOML** | ✅ Sí | ✅ Sí | ❌ No |
| **Git nativo** | ✅ Sí | ✅ Buena | ⚠️ Básica |
| **Límite usuarios** | Sin límite | 10 seats gratis | Sin límite |
| **RAM mínima** | 4 GB | 2 GB | 4 GB |
| **Complejidad setup** | Media | Baja | Alta |
| **Diferencial** | Git-céntrico, 50+ formatos | Editor in-context sobre la app viva | Soporte FTL nativo |

**Tolgee** quedaría como opción solo si en el futuro se quiere que el equipo de negocio edite texto directamente mirando la pantalla de la app en vivo. No es necesario para el flujo actual.

**Pontoon** tiene FTL nativo pero su integración Git es básica y el setup es el más complejo — incompatible con el flujo CI/CD de SBOS.

### 11.3 El flujo completo — tres modos de operación

Weblate no necesita GitHub para funcionar. El modo de operación depende de lo que el cliente necesite:

---

#### Modo A — Directo al disco (recomendado para producción soberana)

El más simple y el más soberano: Weblate escribe los archivos FTL directamente en el directorio que lee bi18nd. El daemon los detecta y recarga solo.

```
Traductor guarda en Weblate
        │
        │ Weblate escribe en disco
        ▼
/etc/bos/bi18n/translations/es-BO/bauth.ftl   ← en el VPS del cliente
        │
        │ bi18nd tiene un file watcher activo (notify crate)
        │ detecta el cambio automáticamente
        ▼
Hot-reload atómico (ArcSwap) — sin CI, sin GitHub, sin RPC manual
        │
        ▼
Texto nuevo visible en pantalla en segundos
```

**Sin dependencias externas. Sin internet. 100% soberano.**

---

#### Modo B — Con repositorio Git local (Gitea self-hosted, opcional)

Si el cliente quiere historial de quién cambió qué texto y poder revertir errores, se agrega **Gitea** — un GitHub propio que corre en el mismo VPS, sin depender de ningún servicio externo:

```
Traductor guarda en Weblate
        │
        │ Weblate commitea (autor = nombre del traductor)
        ▼
Gitea (VPS) — repositorio local de traducciones
        │
        │ webhook interno
        ▼
Script: sync FTL → /etc/bos/bi18n/translations/
        │
        │ file watcher o RPC admin.reload_translations
        ▼
Hot-reload atómico — texto nuevo visible en segundos
```

Gitea es opcional. Lo que aporta es trazabilidad: "María cambió esta clave el martes, antes decía X". Sin Gitea sigue funcionando igual de bien.

---

#### Modo C — Con GitHub (solo para el equipo de SKULL en desarrollo)

GitHub aparece únicamente cuando el equipo de SKULL está desarrollando el sistema — es donde vive el código fuente de SBOS. Las traducciones de un cliente en producción **no pasan por GitHub**.

```
SKULL desarrolla SBOS → GitHub (código fuente)
Cliente opera SBOS    → Weblate + disco local (o Gitea)
                        Sin GitHub. Sin internet requerido.
```

---

#### Resumen de modos

| Modo | Git externo | Internet requerido | Trazabilidad | Cuándo usarlo |
|---|---|---|---|---|
| **A — Directo al disco** | No | No | No (solo logs de bi18nd) | Producción soberana — el más común |
| **B — Gitea local** | Local (Gitea en el VPS) | No | Sí — historial completo | Clientes que quieren auditoría de cambios |
| **C — GitHub** | GitHub (externo) | Sí | Sí | Solo SKULL en desarrollo de SBOS |

### 11.4 Requisitos de despliegue de Weblate

Weblate se despliega en el VPS de STAGING (o uno dedicado) con Docker Compose:

```yaml
# deploy/weblate/docker-compose.yml (ya existe en el repo desde Bloque 11)
services:
  weblate:
    image: weblate/weblate:latest
    environment:
      WEBLATE_SITE_DOMAIN: weblate.miempresa.com
      WEBLATE_ADMIN_EMAIL: admin@miempresa.com
      DATABASE_BACKUP: rescaled  # PostgreSQL propio
    volumes:
      - weblate-data:/app/data   # traducciones + configuración
    depends_on:
      - database
      - cache

  database:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: weblate
      POSTGRES_USER: weblate
      POSTGRES_PASSWORD: ${DB_PASSWORD}

  cache:
    image: redis:7-alpine
```

**RAM mínima:** 4 GB · **Disco:** 10 GB (crece con el historial de traducciones) · **Puerto:** 80/443 (detrás de Kong o nginx)

### 11.5 Conexión Weblate ↔ repositorio Git de SBOS

Weblate se configura apuntando al repositorio de SBOS con acceso de lectura/escritura:

```
Componente Weblate: "bi18n — Traducciones principales"
  → Repositorio: git@github.com:SISTEMASSKULL/SBOS.git
  → Rama: traducciones (o main con merge automático)
  → Máscara de archivos: Bi18nAgent/translations/*/**.ftl
  → Formato: Project Fluent (FTL)
  → Locale base: es-BO
  → Locales adicionales: en-US, es-AR, pt-BR (se agregan al activar Fase 3)
```

Cada vez que el traductor guarda un cambio, Weblate hace push al repo usando las credenciales Git configuradas al instalar — sin intervención del desarrollador.

---

## Historial

| Versión | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-17 | Anexo inicial. Define el rol arquitectónico de bi18n como servidor canónico de traducciones: locales soportados, estructura FTL, namespacing de claves, jerarquía de fallback, métodos RPC `bi18n.translate.*` y `bi18n.i18n.*`, contrato de consumo para daemons SBOS, integración con bglobal y cumplimiento normativo. |
| 1.1.0 | 2026-07-17 | Nueva §11 — Plataforma web Weblate: confirmación soporte FTL nativo (Weblate 2026.7), comparativa Weblate/Tolgee/Pontoon, flujo completo paso a paso, requisitos Docker Compose y configuración del componente Git. URLs de referencia: weblate.org, docs.weblate.org/formats/fluent.html. |
| 1.2.0 | 2026-07-17 | §11.3 reescrito: tres modos de operación (A directo al disco — soberano sin Git; B Gitea local — trazabilidad on-premise; C GitHub — solo SKULL en desarrollo). GitHub no es requerido para traducciones en producción. bi18nd notify crate detecta cambios en disco automáticamente. |
