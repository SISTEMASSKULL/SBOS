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
12. [Ligadura de traducciones con frontends — patrón Bundle Prefetch](#12-ligadura-de-traducciones-con-frontends--patrón-bundle-prefetch)

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

---

## §12 Ligadura de traducciones con frontends — patrón Bundle Prefetch

Esta sección explica cómo los componentes visuales del frontend obtienen el texto en el idioma
correcto, y por qué el patrón elegido es el estándar de la industria con 30 años de historia.

---

### 12.1 El error conceptual que hay que evitar primero

La pregunta intuitiva es: "¿el componente llama a bi18n cada vez que necesita mostrar un texto?"

**No. Eso sería como llamar a un diccionario por teléfono cada vez que necesitas decir una palabra.**

Si un frontend llama a bi18n en cada renderizado, tiene estos problemas:
- La pantalla de login tiene ~20 textos → 20 llamadas de red antes de poder mostrarla
- Cada texto aparece con un retraso (espera respuesta de red antes de renderizar)
- La UI parpadea: primero muestra la clave cruda (`bauth.login.titulo`), luego el texto real
- Si bi18n falla un segundo, la pantalla queda en blanco

Nadie hace esto en producción. React, Android, iOS, Flutter — todos evitan este patrón sin excepción.

---

### 12.2 La analogía correcta — el diccionario de viaje

El patrón que usa la industria es este:

```
Antes de irte de viaje → llevas UN diccionario completo del idioma destino
                          (una sola compra, antes de salir)

Durante el viaje →       cuando necesitas una palabra, buscas EN TU DICCIONARIO
                          (sin llamar a ningún servicio, sin esperar nada)
```

Aplicado a SBOS:

```
Al iniciar sesión →      el frontend descarga UNA VEZ el diccionario del locale del usuario
                          (una sola llamada a bi18n, antes de mostrar la primera pantalla)

Al renderizar →          cada componente busca su texto EN EL DICCIONARIO QUE YA TIENE EN MEMORIA
                          (cero llamadas de red, resultado instantáneo)
```

El diccionario = el **bundle**. Cargar el bundle al inicio se llama **Bundle Prefetch**.

---

### 12.3 El flujo completo — paso a paso

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  FASE 1 — Una sola vez, al iniciar sesión                                    │
└──────────────────────────────────────────────────────────────────────────────┘

1. El usuario ingresa sus credenciales
2. bAuth valida y emite el JWT — el JWT contiene el claim: "locale": "es-BO"
3. El frontend lee ese claim y sabe qué idioma usar
4. El frontend llama a bi18n UNA SOLA VEZ:

   bi18n.translate.list_messages({ locale: "es-BO", namespace: "common" })
   bi18n.translate.list_messages({ locale: "es-BO", namespace: "bauth" })

5. bi18n responde con el diccionario completo del módulo:

   {
     "bauth.login.titulo":          "Acceso al Sistema",
     "bauth.login.boton-ingresar":  "Ingresar",
     "bauth.login.error-credenciales": "Credenciales incorrectas",
     "bauth.usuario.titulo-perfil": "Perfil de Usuario",
     "common.boton-cancelar":       "Cancelar",
     "common.cargando":             "Cargando...",
     ...todos los textos del módulo...
   }

6. El frontend guarda ese diccionario en MEMORIA (no en disco, no en base de datos)

┌──────────────────────────────────────────────────────────────────────────────┐
│  FASE 2 — Cero veces, por cada componente que renderiza                      │
└──────────────────────────────────────────────────────────────────────────────┘

7. El componente LoginScreen necesita mostrar el título:

   Text(t("bauth.login.titulo"))

8. La función t() NO llama a bi18n — simplemente busca en el diccionario en memoria:

   diccionario["bauth.login.titulo"] → "Acceso al Sistema"   ← instantáneo, 0 ms de red

9. El componente muestra: "Acceso al Sistema"

┌──────────────────────────────────────────────────────────────────────────────┐
│  bi18n no sabe que se está renderizando una pantalla — ya hizo su trabajo    │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 12.4 Carga progresiva por módulo — división del diccionario

En un ERP con múltiples módulos (bAuth, btax, bcms, bpay, bnotify) no es necesario descargar
el diccionario completo de todos los módulos al iniciar. Se usa carga progresiva:

```
Al iniciar sesión:
  → Descargar namespace "common" (siempre — tiene botones, errores genéricos)
  → Descargar namespace del módulo inicial (ej. "bauth" para la pantalla de login)

Al navegar a Facturación:
  → Descargar namespace "btax" (solo cuando el usuario abre esa sección)
  → El namespace "common" ya está en memoria — no se vuelve a descargar

Al navegar a Notificaciones:
  → Descargar namespace "bnotify"
  → "common" y "bauth" siguen en memoria
```

```
Memoria del frontend en un momento dado:
┌─────────────────────────────────────────────────────────┐
│  Diccionario en memoria (Map<String, String>)            │
│                                                         │
│  common.*   → siempre presente (precargado al inicio)   │
│  bauth.*    → presente (módulo de identidad abierto)    │
│  btax.*     → presente (módulo fiscal abierto antes)    │
│  bnotify.*  → ausente (el usuario nunca fue ahí)        │
│                                                         │
│  Total: ~800 claves × ~50 bytes/clave = ~40 KB en RAM   │
└─────────────────────────────────────────────────────────┘
```

40 KB en RAM es imperceptible. Un módulo de traducción completo es más pequeño que una imagen de UI.

---

### 12.5 Cuándo se actualiza el diccionario en el frontend

El diccionario en memoria es válido hasta que una de estas condiciones ocurre:

| Evento | Qué hace el frontend |
|---|---|
| El usuario cambia su idioma preferido | Recarga todos los bundles en el nuevo locale |
| El usuario hace logout + login | Los bundles se limpian y se vuelven a descargar al entrar |
| bi18nd emite evento WebSocket `translations.updated` | El frontend recarga silenciosamente solo el namespace afectado |
| El usuario fuerza recarga de la app (F5 / restart) | Descarga limpia de todos los bundles |

**El evento `translations.updated`** es el mecanismo de propagación en vivo: cuando el equipo de
negocio actualiza un texto en Weblate, ese cambio llega a todos los frontends conectados en
segundos, sin que los usuarios tengan que cerrar sesión.

```
Weblate guarda el cambio
        │
        ▼
bi18nd detecta el cambio en disco (notify crate)
bi18nd recarga el bundle interno (ArcSwap — atómico)
bi18nd emite evento WebSocket a todos los conectados:
  { "event": "translations.updated", "namespace": "bauth", "locale": "es-BO" }
        │
        ▼
Cada frontend conectado recibe el evento
  → descarta el bundle "bauth" en memoria
  → llama bi18n.translate.list_messages para el namespace afectado
  → actualiza el diccionario en memoria
  → los componentes que usan esas claves se re-renderizan
        │
        ▼
El texto nuevo aparece en pantalla sin que nadie cierre sesión
```

Este mecanismo es opcional — el sistema funciona perfectamente sin él. Solo aporta valor cuando
el equipo de negocio actualiza traducciones mientras los usuarios están trabajando.

---

### 12.6 Implementación — Flutter (frontend desktop de SBOS)

Flutter es el frontend principal de SBOS (`BauthAgent/src/desktop/`). El patrón Bundle Prefetch
se implementa con **Riverpod** como gestor de estado.

```dart
// ──────────────────────────────────────────────────────────────────
// PASO 1 — Provider que sabe el locale activo del usuario (del JWT)
// ──────────────────────────────────────────────────────────────────
@riverpod
String localeActivo(LocaleActivoRef ref) {
  // El JWT ya está validado — el claim "locale" contiene "es-BO"
  final jwt = ref.watch(sesionActivaProvider).jwt;
  return jwt.claims['locale'] ?? 'es-BO';
}

// ──────────────────────────────────────────────────────────────────
// PASO 2 — Provider que descarga el bundle de un namespace
//          Se ejecuta UNA SOLA VEZ por namespace al iniciar sesión
//          Si el locale cambia, Riverpod lo recalcula automáticamente
// ──────────────────────────────────────────────────────────────────
@riverpod
Future<Map<String, String>> i18nBundle(
  I18nBundleRef ref,
  String namespace,  // "bauth", "btax", "common", etc.
) async {
  final locale = ref.watch(localeActivoProvider);
  final cliente = ref.read(bi18nClientProvider);

  // UNA sola llamada RPC — descarga todo el namespace de una vez
  final respuesta = await cliente.listMessages(
    locale: locale,
    namespace: namespace,
  );
  return respuesta.messages; // Map<String, String>
}

// ──────────────────────────────────────────────────────────────────
// PASO 3 — Función t() que los widgets usan para resolver texto
//          NO hace llamadas de red — solo busca en el Map en memoria
// ──────────────────────────────────────────────────────────────────
String t(WidgetRef ref, String clave, {Map<String, String>? args}) {
  // Extrae el namespace del primer segmento: "bauth.login.titulo" → "bauth"
  final namespace = clave.split('.').first;

  // Lee el bundle ya cargado — si no está listo, devuelve la clave como fallback
  final bundle = ref.watch(i18nBundleProvider(namespace)).valueOrNull ?? {};

  final texto = bundle[clave] ?? clave; // clave como último recurso documentado

  // Interpolación de variables: "Bienvenido, { $nombre }" → "Bienvenido, María"
  if (args == null) return texto;
  return args.entries.fold(
    texto,
    (s, e) => s.replaceAll('{ \$${e.key} }', e.value),
  );
}

// ──────────────────────────────────────────────────────────────────
// PASO 4 — En cualquier widget — limpio, sin async, sin await
// ──────────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Precarga el bundle al renderizar por primera vez
    ref.watch(i18nBundleProvider('bauth'));
    ref.watch(i18nBundleProvider('common'));

    return Column(
      children: [
        Text(t(ref, 'bauth.login.titulo')),           // → "Acceso al Sistema"
        Text(t(ref, 'bauth.login.boton-ingresar')),   // → "Ingresar"
        Text(t(ref, 'common.boton-cancelar')),         // → "Cancelar"
        Text(t(ref, 'bauth.login.bienvenida',          // → "Bienvenido, Carlos"
               args: {'nombre': 'Carlos'})),
      ],
    );
  }
}
```

**Lo que sucede cuando se renderiza `LoginScreen`:**
1. Riverpod detecta que `i18nBundleProvider('bauth')` no está cargado → llama a bi18n UNA VEZ
2. Mientras carga: los `Text()` muestran un indicador de carga (o nada — configurable)
3. El bundle llega → Riverpod lo guarda → notifica a los widgets → se re-renderizan con texto real
4. La próxima vez que se renderice `LoginScreen` en la misma sesión: el bundle ya está en memoria → renderizado instantáneo

---

### 12.7 Implementación — Frontend web (TypeScript/JavaScript)

Para portales web del cliente que se sirven desde S16-webserver:

```typescript
// ──────────────────────────────────────────────────────────────────
// Clase I18nStore — almacén en memoria de todos los bundles cargados
// ──────────────────────────────────────────────────────────────────
class I18nStore {
  private bundles = new Map<string, Record<string, string>>();
  private locale: string;

  constructor(locale: string) {
    this.locale = locale;
  }

  // Carga el bundle de un namespace desde bi18n — llamado una sola vez por namespace
  async cargarNamespace(namespace: string): Promise<void> {
    if (this.bundles.has(namespace)) return; // ya cargado, no vuelve a llamar

    const respuesta = await bi18nClient.call('bi18n.translate.list_messages', {
      ctx_id: ctxId(),
      locale: this.locale,
      namespace,
    });
    this.bundles.set(namespace, respuesta.messages);
  }

  // Función t() — resolución local, cero red
  t(clave: string, args?: Record<string, string>): string {
    const namespace = clave.split('.')[0];
    const bundle = this.bundles.get(namespace) ?? {};
    const texto = bundle[clave] ?? clave;
    if (!args) return texto;
    return Object.entries(args).reduce(
      (s, [k, v]) => s.replace(`{ $${k} }`, v),
      texto
    );
  }

  // Recarga un namespace — llamado al recibir evento translations.updated
  async recargarNamespace(namespace: string): Promise<void> {
    this.bundles.delete(namespace);
    await this.cargarNamespace(namespace);
  }
}

// ──────────────────────────────────────────────────────────────────
// Al iniciar la app — precarga common + módulo inicial
// ──────────────────────────────────────────────────────────────────
const i18n = new I18nStore(jwt.claims.locale);
await Promise.all([
  i18n.cargarNamespace('common'),
  i18n.cargarNamespace('bauth'),  // módulo de la primera pantalla
]);

// ──────────────────────────────────────────────────────────────────
// En componentes React — limpio, sin async, sin await
// ──────────────────────────────────────────────────────────────────
function LoginScreen() {
  return (
    <div>
      <h1>{i18n.t('bauth.login.titulo')}</h1>
      <button>{i18n.t('bauth.login.boton-ingresar')}</button>
    </div>
  );
}
```

---

### 12.8 Tabla resumen — qué hace el frontend en cada momento

| Momento | Llamada a bi18n | Tiempo de espera |
|---|---|---|
| Inicio de sesión | Sí — descarga bundles `common` + módulo inicial | Una sola vez, ~50–200 ms |
| Al abrir un módulo nuevo | Sí — si el bundle de ese namespace no está en memoria | Una sola vez por módulo, ~50 ms |
| Al renderizar cada componente | **No** — resolución local en el Map | 0 ms |
| Al mostrar un error | **No** — la clave `bauth.error.*` ya está en el bundle | 0 ms |
| Al cambiar de locale | Sí — descarga todos los bundles en el nuevo locale | Una sola vez, al cambiar |
| Al recibir evento `translations.updated` | Sí — recarga solo el namespace afectado | Una sola vez, en segundo plano |

---

### 12.9 Estándares internacionales que avalan este patrón

Este no es un diseño propio de SBOS — es el patrón universal del sector:

| Sistema / Framework | Mecanismo | Equivalente en SBOS |
|---|---|---|
| **Android ResourceBundle** (Google, 2008) | Archivos `strings-XX.xml` cargados al iniciar la Activity | Bundle prefetch al iniciar la pantalla |
| **iOS NSBundle** (Apple, 2008) | `Localizable.strings` cargado al arrancar la app | Bundle prefetch al iniciar la app |
| **React-i18next** (2015 — 78% del ecosistema React) | Backend HTTP carga `/locales/es/translation.json` al iniciar | `list_messages` al iniciar, `t()` local |
| **Vue-i18n** (Vue 2016+) | `createI18n` con mensajes precargados | Idéntico |
| **Flutter AppLocalizations** (Google, 2021) | Archivos `.arb` compilados o cargados al arrancar | Bundle prefetch con Riverpod |
| **Angular i18n** (Google) | Archivos XLIFF/JSON cargados en build o runtime | Idéntico |
| **GNU gettext** (1990 — el original) | Archivo `.mo` compilado, cargado al arrancar el proceso | El patrón más antiguo del sector |

La invariante es siempre la misma: **cargar el diccionario una vez, resolver localmente**.

---

### 12.10 Lo que bi18n aporta que ningún framework da nativamente

Los frameworks anteriores cargan archivos estáticos (JSON, .xml, .arb). bi18n es más que eso:

| Capacidad | Framework estático | bi18n |
|---|---|---|
| Actualización de textos sin redeploy | ❌ Requiere nueva build | ✅ Weblate → disco → hot-reload → WebSocket |
| Plurales y géneros gramaticales complejos | ⚠️ Depende del formato | ✅ FTL/Fluent nativo |
| Validación de documentos nacionales (CI, NIT) | ❌ No incluido | ✅ `country-rules/*.toml` |
| Enums de negocio por país | ❌ No incluido | ✅ `bi18n.enum.display` |
| Soberanía total — sin CDN externo | ⚠️ Depende del proveedor | ✅ 100% on-premise |
| Mismo servidor para daemons y frontends | ❌ No aplica | ✅ Unix socket + WebSocket TCP |

---

## Historial

| Versión | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-17 | Anexo inicial. Define el rol arquitectónico de bi18n como servidor canónico de traducciones: locales soportados, estructura FTL, namespacing de claves, jerarquía de fallback, métodos RPC `bi18n.translate.*` y `bi18n.i18n.*`, contrato de consumo para daemons SBOS, integración con bglobal y cumplimiento normativo. |
| 1.1.0 | 2026-07-17 | Nueva §11 — Plataforma web Weblate: confirmación soporte FTL nativo (Weblate 2026.7), comparativa Weblate/Tolgee/Pontoon, flujo completo paso a paso, requisitos Docker Compose y configuración del componente Git. URLs de referencia: weblate.org, docs.weblate.org/formats/fluent.html. |
| 1.2.0 | 2026-07-17 | §11.3 reescrito: tres modos de operación (A directo al disco — soberano sin Git; B Gitea local — trazabilidad on-premise; C GitHub — solo SKULL en desarrollo). GitHub no es requerido para traducciones en producción. bi18nd notify crate detecta cambios en disco automáticamente. |
| 1.3.0 | 2026-07-17 | Nueva §12 — Ligadura con frontends: patrón Bundle Prefetch explicado desde primeros principios. Analogía del diccionario de viaje. Flujo completo 3 fases (prefetch → bundle en memoria → resolución local). Carga progresiva por namespace. Propagación en vivo vía WebSocket `translations.updated`. Implementación Flutter (Riverpod) e implementación web (TypeScript). Tabla resumen de llamadas. Estándares internacionales que avalan el patrón (Android, iOS, React-i18next, Vue-i18n, GNU gettext). |
