# Ficha del Daemon — bi18n (Orquestador Universal de Internacionalización)

**Versión:** 1.0.0  
**Fecha:** 2026-10-14  
**Plano:** Infraestructura transversal  
**Stack:** Rust 1.85+ (MUSL)  
**Estado:** ✅ Operativo — Fase 1 + Fase 2 completadas · 126 métodos RPC  
**Depende de:** [Manual de Arquitectura 1.01](1.01_MANUAL-BI18N-ARQUITECTURA-v1.2.md) · [Índice completo](INDICE.md)

---

## 1. Identidad y propósito

**bi18n** es el **Orquestador Universal de Internacionalización** de SBOS. No reimplementa lógica
de i18n: **orquesta** las mejores librerías Rust detrás de una sola API unificada.

Cualquier daemon SBOS que necesite:

- formatear fechas, números, monedas o unidades según el locale del tenant
- validar documentos de identidad, teléfonos, correos o placas por país
- enmascarar datos PII en logs o vistas
- resolver traducciones FTL multi-idioma
- aplicar el pipeline de atributos (raw → validate → transform → format → mask → localize)

…lo hace invocando a **bi18n** por su contrato JSON-RPC. Nunca duplica esa lógica en su propio código.

### Lo que bi18n NO es

| No es | Es |
|---|---|
| Un motor de autenticación | Un servicio de transformación de datos |
| Un motor de políticas (PDP) | Un servicio invocado por el PDP vía `obligation.service: bi18n` |
| Un servidor de base de datos | Un orquestador de librerías (sin PostgreSQL propio) |
| Un SDK por lenguaje | Un daemon agnóstico: cualquier cliente usa el mismo JSON-RPC |

---

## 2. Posición en el ecosistema SBOS

```
bAuth (PDP)  →  obligation → bi18n  →  atributos formateados / validados / enmascarados
bpay         →  JSON-RPC  → bi18n  →  monedas localizadas, documentos validados
btax         →  JSON-RPC  → bi18n  →  formatos SIN/NIT Bolivia
Dashboard    →  WebSocket → bi18n  →  máscaras de entrada en tiempo real
```

bi18n es **horizontal**: bAuth es uno de varios consumidores, no el propietario.

---

## 3. Stack y dependencias

| Componente | Tecnología |
|---|---|
| Lenguaje | Rust 1.85+ (MUSL, LTO, tokio async) |
| Daemon | `bi18nd` — systemd `Type=notify`, `WatchdogSec=30` |
| CLI | `bi18nctl` — 16+ subcomandos clap, JSON-RPC bajo el capó |
| Traducciones | Project Fluent (`fluent-bundle`) + hot-reload atómico (`arc-swap` + `inotify`) |
| Formato fecha/hora | `jiff` (zone-aware) + `icu_datetime` (CLDR) |
| Formato números/monedas | `icu_decimal` (GroupingStrategy, ISO 4217) |
| Localización | `icu_locale_core` (BCP 47), `icu_locale` |
| Validación teléfonos | `phonenumber` (E.164, libphonenumber) |
| Validación general | `validator` 0.19, `scrutiny`, `prism3-core` |
| Máscaras PII | `mask-pii`, `universal_mask` |
| Regex | `regex` 1.13 (compilaciones cacheadas) |
| Traducciones estáticas | `rust-i18n` 4.x |
| Infraestructura interna | `validy`, `valida`, `veil`, `shakehand`, `serde_with` |
| CLI admin | `clipass_rs` (solo en `bi18nctl`) |
| Reglas por país | TOML estático: `country-rules/bo.toml`, `ar.toml`, `br.toml` |
| Interfaz gRPC | `tonic` (Unix socket, `bi18n.proto`) |

---

## 4. Interfaz — Interface Triple (C11 ORQUESTA-048)

bi18n expone **tres vías de acceso** sobre el mismo Unix socket, sin ningún puerto TCP:

| Vía | Transporte | Protocolo | Consumidores típicos |
|---|---|---|---|
| **JSON-RPC 2.0** | `/run/bos/bi18n.sock` (Unix) | JSON-RPC 2.0 newline-delimited (ADR-020) | Daemons SBOS (bAuth, bpay, btax…) |
| **WebSocket RPC** | `/run/bos/bi18n.sock` (Unix) | WebSocket + JSON-RPC 2.0 framing | CLI humano, scripts, diagnóstico, frontends vía Kong |
| **gRPC** | `/run/bos/bi18n-grpc.sock` (Unix) | gRPC sobre Unix domain socket (HTTP/2 sin TCP) | Daemons con cliente tonic |

**Regla absoluta:** NUNCA HTTP/TCP entre daemons (SBOS-050 P9).

**Namespace JSON-RPC:** `bi18n.*`  
**Puertos TCP:** ninguno en producción (todo Unix socket)  
**Puertos de diagnóstico:** 9470–9475 (solo host)

---

## 5. API — 126 métodos RPC

### 5.1 Grupo `bi18n.format.*`

| Método | Descripción |
|---|---|
| `bi18n.format.date` | Fecha/hora según CLDR (icu_datetime + jiff) |
| `bi18n.format.number` | Número decimal con agrupación y separadores locales |
| `bi18n.format.money` | Monto con símbolo ISO 4217 y agrupación |
| `bi18n.format.address` | Dirección postal según esquema del país |
| `bi18n.format.name` | Nombre propio según convención del locale |
| `bi18n.format.unit` | Cantidad con unidades (ICU4X UnitsFormatter) |
| `bi18n.format.list` | Lista de elementos con conjunción/disyunción CLDR |
| `bi18n.format.relative` | Tiempo relativo ("hace 3 días", "en 2 horas") |

### 5.2 Grupo `bi18n.validate.*`

| Método | Descripción |
|---|---|
| `bi18n.validate.phone` | Validación E.164 con región y tipo (móvil/fijo) |
| `bi18n.validate.national_id` | Cédula/NIT/DNI/CPF/CNPJ/CUIT por país |
| `bi18n.validate.email` | Formato RFC 5321 + validación MX opcional |
| `bi18n.validate.plate` | Placa vehicular según formato del país |
| `bi18n.validate.field` | Validación por tipo semántico: CI, NIT, slug, uuid, semver, cidr, hex, datetime, role_id, json_array |

### 5.3 Grupo `bi18n.mask.*`

| Método | Descripción |
|---|---|
| `bi18n.mask.value` | Máscara de entrada tipada (CI:BO, money:BOB, date, email, phone) |
| `bi18n.mask.pii` | Redacción de PII para logs (GDPR Art. 25/32) |

### 5.4 Grupo `bi18n.locale.*`

| Método | Descripción |
|---|---|
| `bi18n.locale.resolve` | Resuelve BCP 47 + `text_direction` (ltr/rtl/ttb) para el tenant |
| `bi18n.enum.display` | Etiqueta localizada de un valor de enum |

### 5.5 Grupo `bi18n.attr.*` (pipeline AttrBuilder)

| Método | Descripción |
|---|---|
| `bi18n.attr.build` | Construye metadatos de atributo para un campo |
| `bi18n.attr.pipeline` | Ejecuta pipeline completo: raw → validate → transform → format → mask → localize |
| `bi18n.attr.config` | Devuelve configuración de un atributo |
| `bi18n.attr.config_batch` | Configuración de múltiples atributos en una llamada |

### 5.6 Grupo `bi18n.rules.*`

| Método | Descripción |
|---|---|
| `bi18n.rules.list` | Lista reglas de país disponibles (bo/ar/br/…) |
| `bi18n.rules.validate_file` | Valida un archivo TOML de reglas de país |

### 5.7 Grupo `bi18n.collate.*`

| Método | Descripción |
|---|---|
| `bi18n.collate.sort` | Ordena lista de strings con collation unicode por locale |

### 5.8 Grupos `bi18n.translate.*` / `bi18n.i18n.*` (traducciones)

bi18n actúa como **servidor canónico de traducciones** para todo SBOS:
- Cada daemon tiene su propio namespace de claves en los archivos FTL.
- Locales soportados: `es-BO`, `en-US` (+ fallback configurable).
- Hot-reload sin reinicio: `SIGHUP` o `bi18n.admin.reload_translations` → swap atómico en < 100 ms.
- Integración Weblate self-hosted para gestión editorial de traducciones.

### 5.9 Grupo `bi18n.admin.*`

| Método | Descripción |
|---|---|
| `bi18n.admin.reload` | Recarga configuración completa (señal SIGHUP equivalente) |
| `bi18n.admin.reload_translations` | Recarga solo archivos FTL (sin reiniciar handlers) |
| `bi18n.admin.status` | Estado interno del daemon (uptime, locale activo, métricas) |
| `bi18n.admin.metrics` | Métricas de rendimiento por método |

---

## 6. Reglas de país

bi18n conoce las reglas documentales de cada país mediante archivos TOML en `country-rules/`:

| Archivo | País | Contenido |
|---|---|---|
| `bo.toml` | Bolivia | CI, NIT, NUA, placa vehicular, teléfono, departamentos, municipios (7 documentos, 14 enums) |
| `ar.toml` | Argentina | DNI, CUIL/CUIT, CBU, teléfono, provincias (5 documentos, 16 enums) |
| `br.toml` | Brasil | CPF, CNPJ, CEP, teléfono pt-BR, 27 estados (6 documentos, 16 enums) |

Añadir un país nuevo = agregar un archivo TOML sin recompilar el daemon.

---

## 7. Pipeline AttrBuilder

El pipeline es la operación central de bi18n: transforma un valor crudo en un valor
listo para presentar al usuario final, aplicando reglas del locale del tenant.

```
raw value
   │
   ▼  E1 — Validate       (phonenumber, validator, scrutiny, prism3)
   ▼  E2 — Transform      (normalizar casing, strip whitespace, etc.)
   ▼  E3 — Format         (icu_datetime, icu_decimal, jiff)
   ▼  E4 — Mask           (mask-pii, universal_mask — solo si PII)
   ▼  E5 — Localize       (fluent-bundle, enum.display, text_direction)
   │
   └── resultado listo para UI / log / almacenamiento
```

---

## 8. SDK UI

bi18n expone un SDK de ligaduras GUI/UI **agnóstico de framework** (A.19):

- **DSL JSON** de 19 tipos base (CI, NIT, email, phone, date, money, number, slug, uuid, hex, semver, cidr, role_id, datetime, json_array, text, password, enum, opciones).
- **Catálogos de servidor:** 23 enums del dominio bAuth disponibles como validación en línea.
- **Eventos UX:** `onValid`, `onInvalid`, `onWarn`, `onError` por campo.
- **Validación cruzada:** `confirmar_valor`, `mayor_que_valor`, `menor_que_valor`, `warn_dias`.
- **Adaptadores de referencia:** TypeScript/WebSocket (implementado en `sdk/ts/`).
- **Principio:** el daemon es agnóstico de plataforma — cualquier lenguaje consume el mismo JSON.

---

## 9. Estructura de código

```
Bi18nAgent/
├── src/
│   ├── main.rs              # preflight + sd_notify + watchdog + tokio::select!
│   ├── lib.rs               # pub mod 7 módulos
│   ├── preflight.rs
│   ├── config/mod.rs
│   ├── domain/
│   │   ├── country_rules.rs
│   │   ├── file_watcher.rs  # inotify + ArcSwap (hot-reload)
│   │   ├── fluent_loader.rs # FluentLoader → Arc<TranslationsBundle>
│   │   ├── format_map.rs    # 18 códigos display_format
│   │   ├── input_mask.rs
│   │   ├── regional_config.rs
│   │   ├── signal.rs
│   │   └── translations.rs  # ArcSwap<BundleFluent>
│   ├── server/
│   │   ├── context.rs
│   │   ├── dispatcher.rs    # 126 métodos RPC
│   │   ├── dispatcher_helpers.rs
│   │   ├── grpc.rs          # Interface gRPC
│   │   ├── unix_socket.rs
│   │   ├── websocket.rs     # WebSocket rate-limit + timeout
│   │   └── handlers/        # format.rs, validate.rs, health.rs, mask.rs, locale.rs, …
│   ├── generated/
│   │   └── bi18n.v1.rs      # proto compilado (commiteado)
│   └── bin/
│       └── bi18nctl.rs      # CLI — 16+ subcomandos + translations check-parity
├── proto/bi18n.proto        # Contrato gRPC canónico
├── country-rules/           # bo.toml · ar.toml · br.toml
├── locales/                 # es-BO/ · en-US/ (archivos .ftl)
├── deploy/
│   └── bi18nd.service       # Unit systemd con hardening ISO 27001
└── sdk/ts/                  # SDK TypeScript de referencia
```

---

## 10. Operación

### Arranque
```bash
# El daemon lo gestiona systemd
systemctl start bi18nd

# Verificar salud
bi18nctl health
# o via JSON-RPC directo:
echo '{"jsonrpc":"2.0","id":1,"method":"bi18n.health.check","params":{}}' \
  | socat - UNIX-CONNECT:/run/bos/bi18n.sock
```

### Recarga de traducciones en caliente
```bash
# Sin reiniciar el daemon
kill -SIGHUP $(pidof bi18nd)
# o via RPC:
bi18nctl admin reload-translations
```

### Verificar paridad de claves FTL
```bash
bi18nctl translations check-parity
```

---

## 11. Seguridad y cumplimiento

| Norma | Aplicación en bi18n |
|---|---|
| ISO 27001:2022 A.8.15 | Auditoría de operaciones vía `ctx_id` obligatorio (SBOS-049) |
| GDPR Art. 5/25/32 | `bi18n.mask.pii` — redacción de PII en logs y vistas |
| BCP 47 (IETF) | Resolución de locale (sin locales inventados) |
| Unicode UTS #35 (CLDR) | Formatos de fecha, número, moneda y lista |
| E.164 (ITU-T) | Validación de teléfonos via libphonenumber |
| ISO 4217 | Codes de moneda (BOB, USD, ARS, BRL, …) |
| ISO 3166-1 | Códigos de país en reglas TOML |
| SBOS-050 P9 | Sin HTTP/TCP — todo Unix socket |
| veil + ISO 27001 | `#[redact]` en structs de logs (datos personales invisibles en trazas) |

---

## 12. Documentación de referencia

| Documento | Tipo | Estado |
|---|---|---|
| [1.01 Manual de Arquitectura](1.01_MANUAL-BI18N-ARQUITECTURA-v1.2.md) | Arquitectura | ✅ v1.4.0 |
| [1.02 Manual de Usuario](1.02_MANUAL-USUARIO-BI18N-v1.0.md) | Usuario final | ✅ v1.0.0 |
| [1.03 Manual del Programador](1.03_MANUAL-PROGRAMADOR-BI18N-v1.0.md) | Mantenimiento | ✅ v1.0.0 |
| [1.04 Manual del Usuario Programador](1.04_MANUAL-USUARIO-PROGRAMADOR-v1.0.md) | Integración | ✅ v5.0.0 |
| [A.01 Cobertura de Librerías](anexos/A.01_ANEXO-BI18N-COBERTURA-LIBRERIAS-v1.0.md) | Referencia | ✅ v2.1.0 |
| [A.03 Interfaz gRPC](anexos/A.03_ANEXO-BI18N-GRPC-INTERFACE-v1.0.md) | Contrato | ✅ v1.0.0 |
| [A.07 Protocolo WebSocket](anexos/A.07_ANEXO-BI18N-PROTOCOLO-WEBSOCKET-v1.0.md) | Protocolo | ✅ v1.0.0 |
| [A.08 Garantía de Librerías](anexos/A.08_ANEXO-BI18N-GARANTIA-LIBRERIAS-v1.0.md) | Verificación | ✅ v1.0.0 |
| [A.09 Servidor de Traducciones](anexos/A.09_ANEXO-BI18N-SERVIDOR-TRADUCCIONES-v1.0.md) | Arquitectura | ✅ v1.0.0 |
| [A.11 Batería de Pruebas CLI](anexos/A.11_ANEXO-BATERIA-PRUEBAS-CLI-v1.0.md) | Tests (261 TC) | ✅ v1.0.0 |
| [A.12 Batería de Pruebas WebSocket](anexos/A.12_ANEXO-BATERIA-PRUEBAS-FRONTEND-v1.0.md) | Tests (204 TC) | ✅ v1.0.0 |
| [A.19 SDK bi18n UI](anexos/A.19_ANEXO-SDK-BI18N-UI-v1.0.md) | SDK | ✅ v3.0.0 |
| [PROPOSITO.md](../../PROPOSITO.md) | Contrato daemon | ✅ |
| [CLAUDE.md](../../CLAUDE.md) | Directrices agente | ✅ |
