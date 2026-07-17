# A.08 — Garantía de Cobertura de Librerías bi18n
## ¿Puedo usar con `bi18nctl` todas las funciones de las librerías orquestadas?

**Tipo:** V — verificación de exposición de capacidades vía Interface Triple
**Versión del anexo:** 2.0.0
**Fecha:** 2026-07-17
**Bloque:** 12.1
**Respalda a:** [A.01 (Cobertura de Librerías)](A.01_ANEXO-BI18N-COBERTURA-LIBRERIAS-v1.0.md) · [Manual de Usuario](../MANUAL-USUARIO-BI18N-v1.0.md)

---

## §1 Pregunta que responde este anexo

> **¿Con `bi18nctl` (o cualquier cliente JSON-RPC de bi18n) puedo usar todos los métodos
> y funciones de las librerías que bi18n orquesta?**

**Respuesta directa: No para todas. Sí para todas las capacidades de i18n comprometidas.**

bi18n es un **orquestador de dominio**, no un proxy transparente de librerías. Su interfaz
pública son los **18 métodos RPC** — cada uno usa una o más librerías internamente.
Algunas librerías tienen exposición completa a través de esos métodos. Otras son
infraestructura interna, diferidas a Fases futuras, o aplican solo al CLI interactivo.

Este documento mapea **cada librería → qué función expone → qué método `bi18nctl` la activa**.

---

## §2 Mapa completo librería → método bi18nctl

### §2.1 Traducción — librerías: `fluent`, `fluent-bundle`, `rust-i18n`, `shakehand`

| Función de la librería | ¿Accesible con bi18nctl? | Cómo |
|---|---|---|
| Mensajes localizados con variables (`$ejemplo`) | ✅ SÍ | Aparece en `errores[]` de todos los métodos `validar-*` cuando el valor es inválido. El texto viene de FTL. |
| Mensajes con plurales (`[one] / [other]`) | ✅ SÍ | `bi18nctl estado` retorna `"mensaje"` generado por Fluent (ej: "3 países cargados"). |
| Cambio de locale en vivo sin reiniciar | ✅ SÍ | Editar `locales/*.ftl` → `bi18nctl recargar-traducciones` — el swap es atómico. |
| Términos (`-brand-name`) y atributos Fluent | ✅ SÍ | Accesibles en cualquier mensaje FTL que los use — transparente al consumidor. |
| `rust-i18n` (derive macros, YAML/JSON/TOML, fallback en cadena) | ⏳ Fase 6 | Declarada en Cargo.toml, sin método RPC propio aún. Coexiste con Fluent. |
| `shakehand` (enum `Languages` en compile-time) | ⏳ Fase 6 | Declarada. Sin método RPC propio. |

**Garantía §2.1:** toda funcionalidad de Fluent relevante para mensajes de error localizados
en los 18 métodos está activa y accesible. `rust-i18n` y `shakehand` están disponibles
para integrarse sin tocar Cargo.toml.

---

### §2.2 Fechas, horas y cálculo temporal — librerías: `jiff`, `icu_datetime`, `chrono`

| Función de la librería | ¿Accesible con bi18nctl? | Cómo |
|---|---|---|
| Formatear fecha en lenguaje natural ("17 de julio de 2026") | ✅ SÍ | `bi18nctl format-fecha <ISO8601> --granularidad SoloFecha --locale es-BO` |
| Formatear fecha+hora con zona horaria | ✅ SÍ | `bi18nctl format-fecha <ISO8601> --granularidad FechaHora --timezone America/La_Paz` |
| Formatear solo mes y año | ✅ SÍ | `--granularidad MesAnio` |
| Formatear solo año | ✅ SÍ | `--granularidad SoloAnio` |
| Formatear solo hora | ✅ SÍ | `--granularidad SoloHora` |
| Usar fecha/hora actual (sin pasar ISO8601) | ✅ SÍ | Omitir el timestamp — el daemon usa `jiff::Timestamp::now()` |
| 596 zonas horarias IANA (tzdb completo) | ✅ SÍ | Cualquier zona IANA en `--timezone` es aceptada (`jiff` las resuelve) |
| 1000+ locales CLDR para presentación | ✅ SÍ | Cualquier locale BCP 47 válido en `--locale` (`icu_datetime` lo usa) |
| Aritmética de fechas (sumar días, durations) | ❌ NO expuesto | `jiff` lo soporta internamente; no hay método RPC dedicado. Fase 6. |
| `chrono` (workhorse, integración sqlx/serde) | ⚙️ Disponible | Compila. `jiff` es la fuente de verdad de fechas en bi18n. `chrono` está como fallback. |

**Garantía §2.2:** las **5 granularidades de formato de fecha**, las **596 zonas IANA** y los
**1000+ locales CLDR** son accesibles vía `bi18nctl format-fecha`. La aritmética temporal
no está expuesta como RPC (no es una necesidad de i18n comprometida en el MVP).

---

### §2.3 Formatos regionales — librerías: `icu_locale_core`, `icu_datetime`, `icu_decimal`, `prism3-core`

| Función de la librería | ¿Accesible con bi18nctl? | Cómo |
|---|---|---|
| Validar locale BCP 47 | ✅ SÍ | `bi18nctl locale-resolver --tenant X` — locales inválidos son rechazados con error descriptivo en español |
| Resolver texto dirección RTL/LTR por locale | ✅ SÍ | `bi18nctl locale-resolver` retorna `"text_direction": "rtl"` para árabe, hebreo, etc. |
| Formatear número con separadores CLDR | ✅ SÍ | `bi18nctl format-numero 1234567.89 --locale es-BO` |
| Separadores de país (fuente: TOML soberano) | ✅ SÍ | Para BO, AR, BR: `country-rules/*.toml` toma prioridad sobre CLDR |
| Validación de argumentos con rangos/patrones (`prism3-core`) | ⏳ Fase 3 | Disponible en Cargo.toml. Sin método RPC propio en MVP. |

**Garantía §2.3:** locale BCP 47, dirección de texto y formato de números con separadores
por locale/país son accesibles con bi18nctl. `prism3-core` está disponible para Fase 3.

---

### §2.4 Validación de atributos — librerías: `valida`, `validy`, `validator`, `scrutiny`, `phonenumber`, `prism3-core`, `regex`

| Función de la librería | ¿Accesible con bi18nctl? | Cómo |
|---|---|---|
| Validar email (RFC 5321) | ✅ SÍ | `bi18nctl validar-email usuario@empresa.com` — usa `regex` internamente |
| Validar teléfono E.164 (200+ países) | ✅ SÍ | `bi18nctl validar-telefono 71234567 --pais BO` — usa `phonenumber` (libphonenumber) |
| Convertir teléfono a formato E.164 canónico | ✅ SÍ | `bi18nctl validar-telefono` retorna `"e164": "+59171234567"` |
| Validar CI boliviana (regex TOML) | ✅ SÍ | `bi18nctl validar-id 7654321-LP --tipo CI --pais BO` |
| Validar NIT boliviano | ✅ SÍ | `--tipo NIT --pais BO` |
| Validar CPF Brasil | ✅ SÍ | `--tipo CPF --pais BR` |
| Validar CNPJ Brasil | ✅ SÍ | `--tipo CNPJ --pais BR` |
| Validar DNI Argentina | ✅ SÍ | `--tipo DNI --pais AR` |
| Validar CUIT Argentina | ✅ SÍ | `--tipo CUIT --pais AR` |
| Validar PASSPORT (BO/AR/BR) | ✅ SÍ | `--tipo PASSPORT --pais BO|AR|BR` |
| Pipeline: validar + transformar + formatear + enmascarar en un paso | ✅ SÍ | `bi18nctl attr-pipeline ci_numero 7654321-lp --tenant X` |
| `valida` (#[derive(Validatable)], soporte i18n, anidamiento, async) | ⏳ Fase 3 | Disponible en Cargo.toml. Sin método RPC dedicado. Diseñada para validación de structs de dominio complejos. |
| `validy` (validación + modificación: trim, lowercase, snake_case) | ⏳ Fase 3 | Las transformaciones `trim`, `uppercase` del pipeline usan lógica propia; `validy` disponible para Fase 3. |
| `validator` (URL, rango, regex, crédito, longitud) | ⏳ Fase 3 | Disponible en Cargo.toml. URL, número de crédito y otros tipos no tienen método RPC en MVP. |
| `scrutiny` (reglas de negocio) | ⏳ Fase 3 | Disponible en Cargo.toml. Sin método RPC propio en MVP. |

**Garantía §2.4:** los **7 tipos de documento** de los 3 países base, email RFC 5321 y
teléfono E.164 de 200+ países son accesibles con bi18nctl. Validación de URL, tarjeta
de crédito, rango numérico y structs complejos requieren Fase 3 (librerías ya disponibles).

---

### §2.5 Enmascaramiento PII — librerías: `mask-pii`, `veil`, `universal_mask`

| Función de la librería | ¿Accesible con bi18nctl? | Cómo |
|---|---|---|
| Enmascarar valor individual (parcial, completo, prefijo, ambos extremos) | ✅ SÍ | `bi18nctl mask-valor 7654321-LP --estrategia partial(4)` |
| Enmascarar desde regla del TOML del país | ✅ SÍ | `--estrategia country_rule` — lee la sección `[mascaras]` del TOML |
| Detectar y redactar emails en texto libre | ✅ SÍ | `bi18nctl mask-pii "Texto con email@x.com"` — usa `regex` internamente |
| Detectar y redactar teléfonos E.164 en texto libre | ✅ SÍ | `bi18nctl mask-pii "... +59171234567 ..."` |
| `mask-pii` builder API (`.mask_emails().mask_phones()`) | ⏳ Fase 2 | Declarada en Cargo.toml. El handler `mask_pii` usa `regex` directamente (TODO en código). `mask-pii` crate se integrará en Fase 2 sin cambios de interfaz RPC. |
| `veil` (#[derive(Redact)], campos sensibles en logs) | ⚙️ Interno | Disponible en Cargo.toml. Aplica a structs de logging interno del daemon, no expuesto vía RPC. |
| `universal_mask` (máscaras estructurales SSN XXX-XX-XXXX) | ⏳ Fase 3 | Disponible en Cargo.toml. Útil para campos con formato fijo. Sin método RPC propio en MVP. |

**Garantía §2.5:** las 5 estrategias de enmascaramiento de valores individuales y la
detección automática de PII en texto libre son accesibles con bi18nctl. La interfaz RPC
de `mask.pii` no cambiará cuando se integre `mask-pii` crate en Fase 2.

---

### §2.6 Máscaras de entrada — librerías: `rat-input`, `clipass_rs`

| Función de la librería | ¿Accesible con bi18nctl? | Cómo |
|---|---|---|
| Patrón de máscara de input para un atributo | ✅ SÍ | `bi18nctl` → `attr.config` retorna `"input_mask": "99/99/9999"` para fechas, etc. El patrón es derivado de ICU4X/TOML — el cliente lo aplica. |
| `clipass_rs` (lectura enmascarada en terminal) | ⚙️ CLI | Disponible en Cargo.toml. Para bi18nctl modo interactivo (Fase 5 — passwords, tokens). No es un método RPC. |
| `rat-input` (MaskedInput widget TUI) | ❌ Removido | Removido de Cargo.toml por bug v0.16.6. No aplica al daemon. |

**Garantía §2.6:** el patrón de máscara de input (`input_mask`) es accesible vía
`attr.config` y `attr.config_batch`. La aplicación de la máscara en el formulario
es responsabilidad del adapter de cada plataforma (principio agnóstico de A.04).

---

### §2.7 Serialización — librerías: `serde`, `serde_json`, `serde_with`, `toml`

| Función de la librería | ¿Accesible con bi18nctl? | Cómo |
|---|---|---|
| Serializar/deserializar JSON-RPC | ✅ SÍ | Todo el protocolo bi18nctl — es la base del transporte |
| Leer country-rules TOML | ✅ SÍ | Transparente — bi18nctl accede a los datos del TOML vía todos los métodos de país |
| Leer bi18n.toml de configuración | ✅ SÍ | Transparente — bi18nctl usa la configuración cargada en el daemon |
| `serde_with` anotaciones avanzadas (base64, fechas, masks) | ⚙️ Interno | Disponible en Cargo.toml. Para uso interno en structs del daemon. Sin método RPC propio. |

---

### §2.8 Catálogo de referencia bglobal (PostgreSQL)

| Función | ¿Accesible con bi18nctl? | Cómo |
|---|---|---|
| Datos de 196 países (ISO, moneda, idiomas, timezones) | ✅ SÍ | Disponibles en `bi18nctl snapshot` — los datos fueron trasladados a `country-rules/*.toml` (GAP-02: bi18n es stateless) |
| Consulta en tiempo real a bglobal PostgreSQL | ❌ NO | Decisión de diseño: bi18n es stateless. Los admins consultan bglobal offline y actualizan los TOML. El daemon no tiene driver SQL. |

---

## §3 Resumen ejecutivo de cobertura

| Categoría | Librerías | Accesibles vía bi18nctl ahora | Accesibles en Fase futura | No aplica al RPC |
|---|---|---|---|---|
| Traducción | 3 | `fluent` + `fluent-bundle` (mensajes, plurales, variables, hot-reload) | `rust-i18n`, `shakehand` (Fase 6) | — |
| Fechas y horas | 3 | `jiff` + `icu_datetime` (5 granularidades, 596 IANA, 1000+ CLDR) | — | `chrono` (disponible, jiff prioridad) |
| Formatos regionales | 4 | `icu_locale_core` (BCP47) + `icu_decimal` (números) | `prism3-core` (Fase 3) | — |
| Validación | 7 | `phonenumber` (E.164) + `regex` (7 doc. nacionales) | `valida`, `validy`, `validator`, `scrutiny` (Fase 3) | — |
| Enmascaramiento PII | 3 | Estrategias propias (5 modos) + detección regex | `mask-pii` (Fase 2), `universal_mask` (Fase 3) | `veil` (logging interno) |
| Máscaras de entrada | 2 | `input_mask` pattern vía attr.config | `clipass_rs` (Fase 5 CLI) | `rat-input` (removido) |
| Serialización | 3 | `serde` + `serde_json` + `toml` (todo el protocolo) | `serde_with` (Fase 3) | — |
| Catálogo referencia | bglobal | Datos en country-rules/*.toml | — | Consulta directa SQL (no aplica — stateless) |

---

## §4 Lo que bi18nctl SÍ garantiza cubrir

Con `bi18nctl` y los 18 métodos RPC del daemon, el consumidor puede:

1. **Traducir mensajes de validación** al locale del tenant, con plurales y variables, en tiempo de ejecución (sin redeploy).
2. **Formatear cualquier fecha** en lenguaje natural para cualquier locale BCP 47 con zona horaria IANA.
3. **Validar email, teléfono y 7 tipos de documento nacional** de Bolivia, Argentina y Brasil.
4. **Enmascarar un valor individual** con 5 estrategias, o detectar y redactar PII automáticamente en texto libre.
5. **Formatear números y montos** con separadores del país (fuente TOML soberana) o CLDR.
6. **Resolver el locale efectivo** de un tenant/branch/usuario con dirección de texto RTL/LTR.
7. **Obtener la configuración completa de un atributo** (patrón de validación, máscara, input_mask, si es PII) en una sola llamada batch.
8. **Ejecutar el pipeline completo** (validar → transformar → formatear → enmascarar) de un atributo en un solo viaje de red.
9. **Recargar traducciones** sin downtime ni reinicio del daemon.
10. **Consultar el snapshot regional** completo de un tenant (separadores, documentos, enums, moneda).

---

## §5 Lo que bi18nctl NO cubre hoy (y por qué)

| Capacidad no expuesta | Librería que la provee | Por qué no está | Cuándo |
|---|---|---|---|
| Validar URL, número de crédito, rangos numéricos | `validator`, `valida`, `validy` | No es necesidad de i18n comprometida en MVP | Fase 3 |
| Validar structs complejos (anidamiento, async) | `valida` | Requiere definir esquema de dominio en el daemon | Fase 3 |
| Ordenamiento lingüístico (ch después de c en español) | `icu_collator` (no declarado aún) | Fase 6 | Fase 6 |
| Calendarios no gregorianos (jalali, hebreo, etíope) | `icu_datetime` (capacidad del crate) | Fase 6 | Fase 6 |
| Aritmética de fechas (+ 30 días, durations) | `jiff` (capacidad del crate) | No es necesidad de i18n; lo hace el Motor de Identidad | — |
| Consulta directa a bglobal PostgreSQL | `sqlx` (no declarado) | bi18n es stateless por diseño (GAP-02) | — |
| Máscaras de entrada aplicadas en TUI | `rat-input` | Removido por bug; aplica solo al CLI interactivo | Fase 5 |

**Regla de diseño:** bi18n expone lo que necesita el **consumidor de i18n** (bAuth, UI).
No es un proxy de librerías — es un servicio de dominio. Las librerías son su implementación.

---

## §6 Garantía formal

**Se garantiza que:**

1. **Toda capacidad de i18n comprometida en el MVP está accesible vía `bi18nctl`** — los 18 métodos cubren sin excepción las necesidades de formato, validación, enmascaramiento, locale y traducciones documentadas en 1.01 y A.02.

2. **Las librerías diferidas (Categoría B) están disponibles en Cargo.toml**, compiladas sin conflicto, y pueden integrarse a nuevos métodos RPC en Fases futuras sin cambios de infraestructura.

3. **La interfaz pública de `bi18nctl` no cambiará** cuando se integren `mask-pii` (Fase 2) o `valida`/`validy`/`validator` (Fase 3) — los métodos RPC existentes ampliarán su implementación interna, no su firma.

4. **Las librerías de infraestructura** (`serde`, `tokio`, `tracing`, `thiserror`, `arc-swap`, `notify`, `sd-notify`) son invisibles para el consumidor — trabajan de forma transparente detrás de cada llamada.

5. **`cargo check --all-targets` pasa limpio** (`RUSTFLAGS="-D warnings"`) — ninguna librería declarada produce error ni warning fatal. Verificado en CI (job `verificar`, workflow `ci-bi18n.yml`).

---

## Historial

| Versión | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-17 | Creación inicial — análisis de compilación y uso activo. |
| 2.0.0 | 2026-07-17 | Reescritura completa. Responde la pregunta real: ¿con bi18nctl accedo a todas las funciones de las librerías? Mapa explícito función→método bi18nctl, cobertura actual vs Fase futura, garantía formal de que toda capacidad de i18n comprometida está accesible. |
