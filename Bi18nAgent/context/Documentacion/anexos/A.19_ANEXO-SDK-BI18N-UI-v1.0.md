# A.19 — Especificación SDK bi18n UI
## Validación, Formato, Máscara y Mensajes de Campos

**Versión:** 1.0.0
**Fecha:** 2026-07-18
**Estado:** BORRADOR
**Daemon:** bi18n (i18n-orchestrator)
**Estándares:** ICU4X 2.0 · CLDR 46 · RFC 5321 · E.164 · NIST 800-63B Rev.4 · Mozilla Fluent · UTS 35

---

## Índice

1. [Propósito y Principio Rector](#1-propósito-y-principio-rector)
2. [Arquitectura del SDK — Tres Capas](#2-arquitectura-del-sdk--tres-capas)
3. [Protocolo Agnóstico de Framework](#3-protocolo-agnóstico-de-framework)
4. [Tabla DSL Tipo — Referencia Completa](#4-tabla-dsl-tipo--referencia-completa)
5. [Motor de Validación — Pipeline y Reglas](#5-motor-de-validación--pipeline-y-reglas)
6. [Sistema de Máscaras](#6-sistema-de-máscaras)
7. [Sistema de Formatos](#7-sistema-de-formatos)
8. [Mensajes de Validación (Fluent FTL)](#8-mensajes-de-validación-fluent-ftl)
9. [Ciclo UX — Timing de Validación](#9-ciclo-ux--timing-de-validación)
10. [Email — Caso de Estudio Completo](#10-email--caso-de-estudio-completo)
11. [API Fluent del SDK](#11-api-fluent-del-sdk)
12. [Adaptadores de Framework](#12-adaptadores-de-framework)
13. [Nuevos Métodos RPC del Daemon](#13-nuevos-métodos-rpc-del-daemon)

---

## 1. Propósito y Principio Rector

Este anexo especifica el **SDK bi18n UI**: la capa de abstracción que permite a desarrolladores
frontend vincular campos de formulario al daemon bi18n con una API declarativa y compacta.

### El problema que resuelve

Sin SDK, cada campo UI requiere llamadas RPC explícitas al daemon (~40 líneas por campo):

```
// Sin SDK — un campo CI: ~40 líneas
const resp = await ws.send({ method: "bi18n.validate.field",
  params: { tipo: "CI", valor, ctx_id } });
if (!resp.valido) { /* manejo manual de error */ }
const fmt = await ws.send({ method: "bi18n.format.value",
  params: { tipo: "CI", valor, formato: "display" } });
// 10 campos × ~40 líneas = 400 líneas de código boilerplate
```

Con SDK, el mismo campo se declara en una línea:

```
bi18n.campo("#ci").tipo("CI:BO").ligar()
```

### Principio rector

**La complejidad vive en el servidor.** El daemon bi18n (Rust) implementa toda la lógica de
validación, formato, máscara y mensajes. El SDK cliente es declarativo: indica *qué* tipo de
dato es el campo; el servidor decide *cómo* validarlo, formatearlo y enmascararlo.

---

## 2. Arquitectura del SDK — Tres Capas

```
┌─────────────────────────────────────────────────────────────────────┐
│  CAPA 3 — Adaptadores de Framework                                   │
│  Vue 3 (~35 líneas)  React (~30 líneas)  Flutter (~40 líneas)       │
│  PyQt6 (~35 líneas)  Vanilla JS (0 líneas — usa Capa 2 directo)     │
├─────────────────────────────────────────────────────────────────────┤
│  CAPA 2 — Bi18nSdk (API Fluent)                                      │
│  .valor() .campo() .formulario() .mostrar()                         │
│  DSL tipo parser · binding DOM · validación UX lifecycle            │
│  ~200 líneas — agnóstico de framework                               │
├─────────────────────────────────────────────────────────────────────┤
│  CAPA 1 — Bi18nClient (ya implementada — Manual 1.04 Parte II)       │
│  WebSocket + JSON-RPC 2.0 · reconexión · ctx_id · push events      │
│  ~120 líneas                                                        │
└─────────────────────────────────────────────────────────────────────┘
        │  ws://127.0.0.1:9454  (WebSocket JSON-RPC)
        ▼
┌───────────────────┐
│  daemon bi18n     │
│  (Rust — MUSL)    │
│  /run/bos/bi18n   │
└───────────────────┘
```

**Capa 1** — ya existe. No se modifica en este anexo.
**Capa 2** — nueva. Implementación de referencia en TypeScript; puede portarse a cualquier lenguaje.
**Capa 3** — adaptadores delgados. Solo mapean eventos del framework a callbacks del SDK.

---

## 3. Protocolo Agnóstico de Framework

El daemon bi18n expone los siguientes métodos RPC que el SDK utiliza.
Cualquier lenguaje puede implementar el cliente respetando este contrato.

### 3.1 Validar un campo

```json
// Request
{ "jsonrpc": "2.0", "id": 1, "method": "bi18n.validate.field",
  "params": {
    "tipo": "CI:BO",
    "valor": "1234567-1A",
    "opciones": { "rango": null, "requerido": true },
    "ctx_id": "uuid-v4"
  }
}

// Response — válido
{ "jsonrpc": "2.0", "id": 1, "result": {
    "valido": true,
    "errores": [],
    "valor_normalizado": "1234567-1A",
    "metadata": { "departamento": "La Paz" }
  }
}

// Response — inválido
{ "jsonrpc": "2.0", "id": 1, "result": {
    "valido": false,
    "errores": [
      { "codigo": "ci-digito-verificador",
        "mensaje": "El dígito verificador no corresponde al número de CI ingresado.",
        "etapa": "E4"
      }
    ],
    "valor_normalizado": null,
    "metadata": {}
  }
}
```

### 3.2 Formatear un valor

```json
// Request
{ "method": "bi18n.format.value",
  "params": {
    "tipo": "date", "valor": "2026-07-16",
    "formato": "date:long", "locale": "es-BO", "ctx_id": "uuid-v4"
  }
}
// Response
{ "result": { "formateado": "16 de julio de 2026" } }
```

### 3.3 Obtener patrón de máscara de entrada

```json
// Request
{ "method": "bi18n.mask.pattern",
  "params": { "tipo": "CI:BO", "ctx_id": "uuid-v4" }
}
// Response
{ "result": {
    "patron": "0000000-aA",
    "definiciones": { "0": "[0-9]", "a": "[A-Za-z]", "A": "[A-Za-z]" },
    "placeholder": "_______-__",
    "motor": "imask"
  }
}
```

### 3.4 Verificar existencia de email (async)

```json
// Request
{ "method": "bi18n.validate.email_existence",
  "params": { "email": "usuario@empresa.com", "timeout_ms": 2000, "ctx_id": "uuid-v4" }
}
// Response
{ "result": {
    "mx_valido": true,
    "smtp_acepta": true,
    "es_temporal": false,
    "confianza": 0.97,
    "sugerencia": null
  }
}
```

### 3.5 Formatear un lote de valores (batch)

```json
// Request
{ "method": "bi18n.format.batch",
  "params": {
    "items": [
      { "id": "ci",      "tipo": "CI:BO",    "valor": "1234567-1A", "mascara": "partial:2" },
      { "id": "salario", "tipo": "money:BOB", "valor": 2850.00,     "formato": "money:BOB" },
      { "id": "fecha",   "tipo": "date",      "valor": "2026-07-16", "formato": "date:medium" }
    ],
    "ctx_id": "uuid-v4"
  }
}
// Response
{ "result": {
    "items": [
      { "id": "ci",      "formateado": "****-**1A" },
      { "id": "salario", "formateado": "Bs. 2.850,00" },
      { "id": "fecha",   "formateado": "16 jul. 2026" }
    ]
  }
}
```

---

## 4. Tabla DSL Tipo — Referencia Completa

El DSL tipo es el mecanismo central del SDK. Un string compacto codifica el tipo de dato y
sus parámetros. Sintaxis: `<tipo>:<subtipo>:<param1>:<param2>`.

| DSL Tipo | Descripción | Validaciones automáticas | Máscara entrada | Formato display |
|---|---|---|---|---|
| `CI:BO` | Cédula Identidad Bolivia | 7 dígitos + complemento (letra+dígito o 2 letras de depto). Dígito verificador. | `0000000-aA` | `1234567-1A` |
| `CI:BO:{depto}` | CI con extensión forzada | Igual + extensión coincide con {depto} (LP, CB, OR, PT, TJ, SC, BE, PD) | `0000000-aA` | `1234567-LP` |
| `NIT:BO` | NIT Bolivia personas/empresas | 8–12 dígitos + dígito verificador módulo 11. SIN Bolivia. | `000000000-0` | `123456789-1` |
| `email` | Correo electrónico (formato) | RFC 5321: max 254 chars, `local@domain`, sin espacios. | libre (sin máscara) | tal cual |
| `email:verify` | Email con verificación existencia | RFC 5321 + DNS MX + SMTP handshake (async, E5) | libre | tal cual |
| `phone:BO` | Teléfono Bolivia (fijo y móvil) | 7–8 dígitos. Móvil: 6x, 7x. Fijo: prefijo por departamento. | `0 000-0000` | `7 123-4567` |
| `phone:E164` | Teléfono internacional E.164 | E.164: +[1-9][0-14 dígitos]. libphonenumber en daemon. | libre | `+591 7 123-4567` |
| `date` | Fecha ISO 8601 | Fecha válida gregoriana | `00/00/0000` (bloques con rangos) | según locale |
| `date:{min}:{max}` | Fecha con rango | ISO + min ≤ fecha ≤ max. Acepta expresiones relativas. | `00/00/0000` | según locale |
| `money:BOB` | Monto bolivianos | número ≥ 0, hasta 2 decimales | `#.##0,00` (Number mask) | `Bs. 1.250,50` |
| `money:USD` | Monto dólares | número ≥ 0, hasta 2 decimales | `#,##0.00` | `$ 1,250.50` |
| `money:EUR` | Monto euros | número ≥ 0, hasta 2 decimales | `#.##0,00` | `€ 1.250,50` |
| `money:{divisa}:{min}:{max}` | Monto con rango | número + min ≤ valor ≤ max | dinámico | dinámico |
| `number:integer` | Número entero | Solo dígitos, sin decimales | regex `[0-9]*` | `1.250` |
| `number:decimal:{n}` | Número con n decimales | Dígitos + separador, máx n decimales | Number mask | `1.250,50` |
| `number:percent` | Porcentaje 0–100 | rango [0, 100], 2 decimales | Number mask 0–100 | `85,30 %` |
| `number:percent:0` | Porcentaje entero | rango [0, 100], sin decimales | Number mask | `85 %` |
| `text` | Texto libre | sin restricción | ninguna | tal cual |
| `text:{min}:{max}` | Texto con longitud | min ≤ longitud ≤ max chars Unicode | contador visual | tal cual |
| `text:alpha` | Solo letras (incluye acentos) | `/^[\p{L}\s]+$/u` — Unicode Letter | bloquea no-letras | tal cual |
| `text:alphanumeric` | Alfanumérico | `/^[\p{L}\p{N}\s]+$/u` | bloquea especiales | tal cual |
| `password` | Contraseña NIST 800-63B Rev.4 | ≥ 8 chars. Sin restricción de tipos. Lista negra HIBP. | oculto (•••) | ••••••••• |
| `enum:{nombre}` | Valor de catálogo bi18n | valor ∈ lista del catálogo `nombre` (RPC catálogo) | selector/combobox | etiqueta localizada |
| `bool` | Booleano | true / false | checkbox / toggle | Sí / No |

### Expresiones de fecha relativa

En parámetros `min` y `max` del tipo `date:{min}:{max}`, el daemon resuelve:

| Expresión | Significado |
|---|---|
| `hoy` | Fecha actual del servidor |
| `hoy-Nd` | N días antes de hoy |
| `hoy+Nd` | N días después de hoy |
| `hoy-Na` | N años antes de hoy |
| `hoy+Na` | N años después de hoy |
| `inicio-mes` | Primer día del mes actual |
| `fin-mes` | Último día del mes actual |
| `inicio-año` | 1 de enero del año actual |
| `fin-año` | 31 de diciembre del año actual |
| ISO 8601 | Fecha absoluta: `2026-01-01` |

---

## 5. Motor de Validación — Pipeline y Reglas

### 5.1 Pipeline de cinco etapas

```
[E1 Pre-check] → [E2 Formato] → [E3 Rango] → [E4 Regla] → [E5 Async]
```

El pipeline se ejecuta en orden estricto. Si una etapa falla, las siguientes **no se ejecutan**
(cortocircuito). E5 solo se activa si E1–E4 pasan completamente.

| Etapa | Nombre | Qué valida | Tiempo |
|---|---|---|---|
| E1 | Pre-check | Campo requerido · no vacío · longitud mínima de sensatez | < 0.1 ms |
| E2 | Formato | Regex/tipo · caracteres permitidos · estructura sintáctica | < 1 ms |
| E3 | Rango | min/max numérico · rango de fecha · longitud de texto | < 1 ms |
| E4 | Regla | Dígito verificador · algoritmos de checksum · validación semántica | < 5 ms |
| E5 | Async | DNS MX · SMTP handshake · HaveIBeenPwned · RPC externo | 50–2000 ms |

### 5.2 Especificación de reglas por tipo

#### CI:BO — Cédula de Identidad Bolivia

```
E2: formato = /^\d{7}[-\s]?([0-9][A-Za-z]|[A-Z]{2})$/i
E4: dígito verificador = Luhn adaptado Bolivia (fórmula SEGIP)
    complemento válido = uno de: 1A, 2B, ... | LP, CB, OR, PT, TJ, SC, BE, PD, CH, SS
```

#### NIT:BO — Número de Identificación Tributaria

```
E2: formato = /^\d{7,11}-\d$/
E4: verificador = módulo 11 (algoritmo SIN Bolivia RND 102100000011)
    ≠ 0: empresa; = 0: persona natural con CI como raíz
```

#### email

```
E2: RFC 5321 — local part: max 64 chars, chars [a-z0-9!#$%&'*+/=?^_`{|}~.-]
              dominio: max 253 chars, etiquetas separadas por punto
    longitud total: max 254 chars
E3: (no aplica rango numérico)
E4: dominio no es IP literal sin corchetes; sin dos puntos consecutivos
E5 (email:verify):
    L2: dominio no está en blacklist de dominios temporales/desechables
    L3: DNS MX lookup — ¿el dominio acepta correo?
    L4: SMTP RCPT TO handshake — ¿el buzón existe? (timeout 2000ms)
```

#### phone:BO

```
E2: /^\d{7,8}$/  (sin código de país — se asume +591)
E3: longitud exacta 7 (fijo) u 8 (móvil)
E4: prefijos válidos:
    móvil:  6xxxxxxx, 7xxxxxxx
    fijo LP: 2xxxxxxx
    fijo CB: 4xxxxxxx
    fijo SC: 3xxxxxxx
    fijo OR: 46xxxxx
    (catálogo completo en bi18n: catálogo "PREFIJOS_BO")
```

#### date:{min}:{max}

```
E2: ISO 8601 YYYY-MM-DD — fecha válida del calendario gregoriano
E3: min ≤ fecha ≤ max (expresiones relativas resueltas en el servidor)
E4: año en rango [1900, 2200]
```

#### money:{divisa}:{min}:{max}

```
E2: número válido (punto o coma como decimal — normalizado al recibirlo)
E3: valor ≥ min AND valor ≤ max
E4: máximo 2 decimales para BOB/USD/EUR
    para divisas con 0 decimales (JPY): sin decimales
```

#### password — NIST 800-63B Rev.4 (2024)

```
E2: longitud ≥ 8 caracteres Unicode (no bytes)
    longitud máx: 64 (recomendado) — no imponer restricciones de tipos
E3: (no aplica)
E4: no debe ser igual al nombre de usuario / email / CI del mismo formulario
    no debe contener secuencias comunes: "12345678", "password", "qwerty"
E5: verificar en HaveIBeenPwned API (k-anonymity — solo primeros 5 chars del SHA-1)
```

### 5.3 Rangos y condiciones

```json
// Rango numérico
{ "tipo": "money:BOB", "rango": { "min": 2362, "max": 50000 } }

// Rango de fecha — mayoría de edad
{ "tipo": "date", "rango": { "min": "hoy-100a", "max": "hoy-18a" } }

// Longitud de texto
{ "tipo": "text", "rango": { "min_chars": 3, "max_chars": 100 } }

// Condición: campo activo solo si otro campo tiene valor
{ "tipo": "CI:BO", "condicion": {
    "cuando": { "campo": "tipo_doc", "igual_a": "CI" }
  }
}

// Condición: campo requerido si otro campo tiene cualquier valor
{ "tipo": "email", "condicion": {
    "cuando": { "campo": "contacto_email", "no_vacio": true }
  }
}
```

### 5.4 Validación cruzada entre campos

```json
// Contraseña y confirmación
{ "id": "pass_confirmar", "tipo": "password",
  "cruzada": { "igual_a": "pass_nueva",
               "error": "Las contraseñas no coinciden." }
}

// Fecha fin > fecha inicio
{ "id": "fecha_fin", "tipo": "date",
  "cruzada": { "mayor_que": "fecha_inicio",
               "error": "La fecha de fin debe ser posterior al inicio." }
}

// Monto total = suma de items
{ "id": "total", "tipo": "money:BOB",
  "cruzada": { "igual_a_suma": ["item1", "item2", "item3"] }
}
```

---

## 6. Sistema de Máscaras

### 6.1 Tipos de máscara — distinción fundamental

| Tipo | Cuándo aplica | Propósito |
|---|---|---|
| **Máscara de entrada** | Mientras el usuario escribe | Guiar la escritura al formato correcto |
| **Máscara de visualización** | Al mostrar un valor almacenado | Formato legible o censura de datos sensibles |

Son independientes. Un campo puede tener ambas, una sola, o ninguna.

### 6.2 Máscara de entrada

Basada en la notación de IMask.js (motor más flexible del ecosistema, 20 KB gz).
El daemon devuelve el patrón; el cliente lo aplica con IMask.js (web) o equivalente nativo.

**Cuándo usar (recomendación USWDS):**
- Usar: CI, NIT, fechas, teléfonos, montos, tarjetas — campos de formato fijo
- No usar: email, texto libre, contraseñas — formato variable o que el usuario ya conoce

**Notación de patrones:**

| Carácter | Significado | Ejemplo |
|---|---|---|
| `0` | Dígito 0–9 (requerido) | CI: `0000000` |
| `9` | Dígito 0–9 (opcional) | |
| `a` | Letra a–z, A–Z | Extensión CI: `a` |
| `A` | Letra A–Z mayúscula | |
| `*` | Cualquier carácter | |
| `{texto}` | Literal fijo | `{+}{5}{9}{1}` |
| `[char]` | Carácter opcional | `000[0]` |
| `blocks` | Bloque con rango | Mes: from:1, to:12 |

**Patrones por tipo:**

```
CI:BO     → "0000000-aA"     (7 dígitos, guión, letra, dígito/letra)
NIT:BO    → "000000000-0"    (hasta 9 dígitos, guión, verificador)
phone:BO  → "0 000-0000"     (prefijo espacio 3-4)
date      → bloques: d(1-31) / m(1-12) / Y(1900-2200)
money:BOB → Number mask: scale:2, thousandsSeparator:".", radix:","
money:USD → Number mask: scale:2, thousandsSeparator:",", radix:"."
```

### 6.3 Máscara de visualización

```
// DSL de visualización
mask:partial:{n}   → muestra los últimos n caracteres, resto como *
mask:full          → todos los caracteres como •
mask:format:{dsl}  → aplica formato del DSL tipo al valor almacenado
mask:e164          → normaliza a formato E.164 (+591xxxxxxxx)

// Ejemplos
"1234567-1A"  + mask:partial:2  → "****-**1A"
"1234567-1A"  + mask:full       → "••••••••••"
"71234567"    + mask:format:phone:national:BO → "7 123-4567"
"71234567"    + mask:e164       → "+59171234567"
```

---

## 7. Sistema de Formatos

Todos los formatos usan **ICU4X 2.0** (2025) en el daemon Rust.
Sintaxis semántica de campo (semantic field set) según UTS 35 + CLDR 46 + Unicode 16.

### 7.1 Formatos de fecha

| Token | Resultado (es-BO) | Resultado (en-US) |
|---|---|---|
| `date:short` | 16/07/2026 | 7/16/2026 |
| `date:medium` | 16 jul. 2026 | Jul 16, 2026 |
| `date:long` | 16 de julio de 2026 | July 16, 2026 |
| `date:full` | jueves, 16 de julio de 2026 | Thursday, July 16, 2026 |
| `datetime:short` | 16/07/2026 14:30 | 7/16/2026 2:30 PM |
| `datetime:long` | 16 de julio de 2026 a las 14:30 BOT | July 16, 2026 at 2:30 PM BOT |
| `time:short` | 14:30 | 2:30 PM |
| `time:medium` | 14:30:00 | 2:30:00 PM |
| `relative` | hace 2 horas | 2 hours ago |
| `relative:date` | hace 3 días | 3 days ago |
| `relative:short` | hace 2 h | 2 hr. ago |
| `iso` | 2026-07-16T14:30:00-04:00 | 2026-07-16T14:30:00-04:00 |

### 7.2 Formatos de monto

El separador de miles y decimal se rigen por el locale. Bolivia usa punto como miles y coma
como decimal (`es-BO` conforme a CLDR 46).

| Token | Resultado (es-BO) | Notas |
|---|---|---|
| `money:BOB` | Bs. 1.250,50 | Estándar Bolivia |
| `money:USD` | $ 1,250.50 | Estándar USA |
| `money:EUR` | € 1.250,50 | Estándar europeo |
| `money:BOB:no-symbol` | 1.250,50 | Sin símbolo (formularios) |
| `money:BOB:accounting` | (Bs. 1.250,50) | Negativos en paréntesis |
| `money:BOB:compact` | Bs. 1,25K | Para dashboards |
| `money:BOB:verbose` | Un mil doscientos cincuenta bolivianos con 50 centavos | Cheques, documentos |

### 7.3 Formatos de número

| Token | Resultado (es-BO) |
|---|---|
| `number:integer` | 1.250 |
| `number:decimal:2` | 1.250,50 |
| `number:percent:1` | 85,3 % |
| `number:percent:0` | 85 % |
| `number:scientific` | 1,25 × 10³ |
| `number:ordinal` | 3.° (masc) / 3.ª (fem) |
| `number:compact` | 1,25K / 2,3M |

### 7.4 Formatos de teléfono

Motor: bindings de **libphonenumber** (Google) en el daemon Rust. Normalización obligatoria
a E.164 para almacenamiento; display en formato nacional para UI.

| Token | Entrada | Resultado |
|---|---|---|
| `phone:national:BO` | `71234567` | 7 123-4567 |
| `phone:international:BO` | `71234567` | +591 7 123-4567 |
| `phone:e164` | `71234567` | +59171234567 |
| `phone:compact` | `71234567` | 71234567 |

**Regla de almacenamiento:** siempre guardar en E.164 en base de datos.
Display siempre en formato nacional para el locale del usuario.

---

## 8. Mensajes de Validación (Fluent FTL)

Los mensajes usan el formato **Mozilla Fluent (.ftl)**. Ventajas sobre `printf`/interpolación:
- Soporte nativo para plural (CLDR Plural Rules)
- Género gramatical
- Atributos por contexto (`.descripcion`, `.sugerencia`)
- Variables tipadas
- El cliente recibe el mensaje ya localizado y completo — nunca concatena strings

### 8.1 Catálogo de mensajes — es-BO

```fluent
## Validación general
campo-requerido = Este campo es obligatorio.
campo-demasiado-corto = Este campo debe tener al menos { $min } { $min ->
    [one] carácter
   *[other] caracteres
}.
campo-demasiado-largo = Este campo no puede exceder { $max } caracteres.
solo-letras = Solo se permiten letras y espacios.
solo-alfanumerico = Solo se permiten letras, números y espacios.

## CI Bolivia
ci-formato-invalido =
    El número de CI debe tener el formato { $formato }.
    .descripcion = Ejemplos: 1234567-1A (La Paz), 9876543-2B (Santa Cruz)
ci-digito-verificador =
    El dígito verificador no corresponde al número de CI ingresado.
ci-extension-invalida =
    La extensión "{ $extension }" no es válida.
    .descripcion = Extensiones válidas: LP, CB, OR, PT, TJ, SC, BE, PD, CH, SS.

## NIT Bolivia
nit-formato-invalido = El NIT debe tener entre 7 y 11 dígitos seguidos del dígito verificador.
nit-digito-invalido = El dígito verificador del NIT no es correcto.

## Email
email-formato-invalido =
    Ingrese un correo electrónico válido (ej.: usuario@empresa.com).
email-demasiado-largo = El correo electrónico no puede superar 254 caracteres.
email-verificando = Verificando dirección de correo…
email-no-encontrado =
    Esta dirección de correo no parece existir.
    .sugerencia = ¿Quiso escribir { $sugerencia }?
email-dominio-invalido =
    El dominio "{ $dominio }" no acepta correos electrónicos.
email-descartable =
    No se permiten correos temporales o desechables.
    .descripcion = Utilice una dirección de correo permanente.
email-error-verificacion =
    No se pudo verificar la dirección. Intente nuevamente.

## Teléfono
telefono-invalido =
    Número de teléfono no válido para { $pais }.
telefono-movil-invalido =
    Los números de celular en Bolivia comienzan con 6 o 7.
telefono-fijo-invalido =
    El número de teléfono fijo no es válido para el departamento indicado.

## Fecha
fecha-formato-invalido = Ingrese una fecha válida en formato DD/MM/AAAA.
fecha-fuera-rango =
    La fecha debe estar entre { $desde } y { $hasta }.
fecha-mayor-de-edad =
    Debe ser mayor de { $edad } años para completar este registro.
fecha-futura-requerida = La fecha debe ser posterior a hoy.
fecha-pasada-requerida = La fecha debe ser anterior a hoy.

## Monto
monto-invalido = Ingrese un monto numérico válido.
monto-negativo = El monto no puede ser negativo.
monto-fuera-rango =
    El monto debe estar entre { $min } y { $max }.
monto-demasiado-pequeno = El monto debe ser mayor o igual a { $min }.
monto-demasiado-grande = El monto debe ser menor o igual a { $max }.

## Número
numero-invalido = Ingrese un número válido.
numero-decimales-excedidos =
    Este campo acepta como máximo { $decimales } { $decimales ->
        [one] decimal
       *[other] decimales
    }.
porcentaje-fuera-rango = El porcentaje debe estar entre 0 y 100.

## Contraseña
password-muy-corto =
    La contraseña debe tener al menos { $min } caracteres.
password-comprometida =
    Esta contraseña aparece en filtraciones de datos conocidas.
    Elija una contraseña diferente.
password-muy-comun = Esta contraseña es demasiado común. Elija una más segura.
password-igual-usuario =
    La contraseña no puede ser igual a su nombre de usuario o correo.

## Validación cruzada
campos-no-coinciden =
    Los campos "{ $campo1 }" y "{ $campo2 }" no coinciden.
fecha-fin-antes-inicio =
    La fecha de fin debe ser posterior a la fecha de inicio.
total-no-cuadra =
    El total no coincide con la suma de los ítems.
```

### 8.2 Variables de interpolación disponibles

| Variable | Tipo | Descripción |
|---|---|---|
| `$min` | número/fecha/string | Valor mínimo del rango |
| `$max` | número/fecha/string | Valor máximo del rango |
| `$formato` | string | Descripción del formato esperado |
| `$pais` | string | Nombre del país para validación |
| `$campo` | string | Etiqueta del campo en error |
| `$campo1`, `$campo2` | string | Etiquetas en validación cruzada |
| `$desde`, `$hasta` | fecha formateada | Rango de fechas (ya formateadas) |
| `$edad` | número | Edad mínima requerida |
| `$sugerencia` | string | Sugerencia de corrección (typo de email) |
| `$decimales` | número | Cantidad de decimales permitidos |
| `$extension` | string | Extensión de CI inválida |
| `$dominio` | string | Dominio de email inválido |

---

## 9. Ciclo UX — Timing de Validación

Basado en investigación Nielsen Norman Group + estudios 2024–2026.

### 9.1 Tabla de timing

| Evento | Acción del SDK | Justificación |
|---|---|---|
| `keystroke` | Solo aplicar máscara de entrada | Errores al teclear son hostiles. El usuario aún no terminó. |
| `blur` (primera vez) | Ejecutar E1+E2+E3+E4 | El usuario terminó el campo. Mostrar error si hay. Mostrar ✓ si válido. |
| `blur` + E5 aplica | Ejecutar E5 con debounce 800ms | Solo si E1–E4 pasan y el tipo requiere verificación async. Mostrar spinner. |
| `change` (campo en error) | Re-ejecutar E1+E2+E3+E4 | Feedback positivo: el error desaparece cuando el usuario lo corrige. |
| `change` (password confirm) | Validar cruzada inmediatamente | Excepción: el usuario espera ver "coinciden" en tiempo real. |
| `submit` | Ejecutar E1–E5 en todos los campos | Última barrera. Mostrar todos los errores. Hacer scroll al primero. |

### 9.2 Estados visuales del campo

```
PRISTINE  → sin interacción del usuario. Sin indicador visual.
TOUCHED   → el usuario escribió algo pero no hizo blur.
            → mostrar máscara de entrada. Sin errores aún.
VALID     → blur + validación pasó. Mostrar ✓ verde.
INVALID   → blur + validación falló. Mostrar X rojo + mensaje de error.
VERIFYING → E5 en curso. Mostrar spinner. Campo no editable durante verificación.
VERIFIED  → E5 completó con éxito. Mostrar ✓ verde con ícono de escudo.
ERROR_SERVER → E5 falló por error de red. Mostrar aviso "no se pudo verificar".
```

### 9.3 Reducción de errores

La validación en `blur` + feedback positivo en `change` reduce los errores de formulario
un 22 % respecto a la validación solo en `submit` (Nielsen Norman Group, 2024).
La validación en `keystroke` es hostil: el formulario "regaña" al usuario antes de que
termine de escribir.

---

## 10. Email — Caso de Estudio Completo

### 10.1 Las cuatro capas de validación

```
L1 Formato (cliente, < 1ms)
   └─ Regex RFC 5321 + HTML5 type="email"
   └─ Rechaza: "usuario@" · "@dominio.com" · "sin arroba"
   └─ Acepta: cualquier string con @ y un punto posterior al @

L2 Sintaxis avanzada (daemon, < 5ms, al blur)
   └─ Caracteres SMTP-safe en local part
   └─ Blacklist de dominios temporales: mailnull.com, guerrillamail.*, 10minutemail.*, etc.
   └─ Detección de typos comunes: "gmial.com" → sugerencia "gmail.com"

L3 DNS MX (daemon, ~200ms, al blur con debounce 800ms)
   └─ ¿El dominio tiene registros MX?
   └─ ¿El servidor de correo responde?
   └─ Rechaza dominios sin infraestructura de correo

L4 SMTP RCPT TO (daemon, ~500-2000ms, al enviar formulario)
   └─ Handshake SMTP sin enviar correo
   └─ ¿El buzón específico existe?
   └─ ¿El servidor no bloquea la verificación?
   └─ Timeout configurable (default: 2000ms)
```

### 10.2 Configuración por caso de uso

```javascript
// Caso A: registro de usuario — máxima verificación
bi18n.campo("#email")
     .tipo("email")
     .validacion({
       formato:     true,     // L1: en keystroke (built-in HTML5)
       descartable: true,     // L2: blacklist de temporales
       typo:        true,     // L2: sugerir corrección
       mx:          true,     // L3: al blur, async
       smtp:        true,     // L4: al enviar
     })
     .ligar()

// Caso B: búsqueda — solo formato
bi18n.campo("#buscar")
     .tipo("email")
     .validacion({ formato: true })
     .ligar()

// Caso C: campo opcional con sugerencia de typo
bi18n.campo("#email-contacto")
     .tipo("email")
     .requerido(false)
     .validacion({ formato: true, typo: true })
     .ligar()
```

### 10.3 Formato ≠ Existencia

**Solo validación de formato** acepta:
- `usuario@dominioquenoexiste.xyz` (formato válido, dominio inexistente)
- `buzón-falso@gmail.com` (dominio real, buzón que no existe)
- `usuario@mailnull.com` (dominio temporal)

**Solo la verificación async (L3+L4)** detecta estos casos.
El 95 % de errores reales en direcciones de email son invisibles para una validación de formato.

---

## 11. API Fluent del SDK

### 11.1 `.valor(raw)` — Transformar un valor

```javascript
// Formato de fecha
bi18n.valor("2026-07-16").formato("date:long").obtener()
// → "16 de julio de 2026"

// Formato de monto
bi18n.valor(1250.50).formato("money:BOB").obtener()
// → "Bs. 1.250,50"

// Máscara de visualización sobre teléfono
bi18n.valor("71234567")
     .tipo("phone:BO")
     .formato("phone:national:BO")
     .mascara_display("partial:3")
     .obtener()
// → "7 ***-4567"

// Validar sin binding
const resultado = await bi18n.valor("1234567-1A")
                              .tipo("CI:BO")
                              .validar()
// → { valido: true, errores: [], normalizado: "1234567-1A" }
```

### 11.2 `.campo(selector)` — Binding a un campo DOM

```javascript
// Binding mínimo — bi18n infiere máscara y validaciones del tipo
bi18n.campo("#ci").tipo("CI:BO").ligar()

// Binding con rango de fecha
bi18n.campo("#fecha-nac")
     .tipo("date")
     .requerido(true)
     .rango({ min: "hoy-100a", max: "hoy-18a" })
     .formato("date:medium")
     .al_error(fn)      // fn(errores: string[], campo: string)
     .al_exito(fn)      // fn(valor_normalizado: string)
     .ligar()

// Binding con verificación async de email
bi18n.campo("#email")
     .tipo("email:verify")
     .requerido(true)
     .al_verificar(fn)  // fn({ verificando: true }) → mostrar spinner
     .ligar()

// Binding con validación cruzada
bi18n.campo("#pass-confirm")
     .tipo("password")
     .igual_a("#pass-nueva")
     .ligar()

// Desligar (limpieza)
const binding = bi18n.campo("#ci").tipo("CI:BO").ligar()
binding.desligar()  // remueve listeners y máscara
```

### 11.3 `.formulario(selector, schema)` — Binding completo

```javascript
bi18n.formulario("#form-empleado", [
  // Datos de identidad
  { id: "ci",           tipo: "CI:BO",           requerido: true },
  { id: "nit",          tipo: "NIT:BO",           requerido: false },
  { id: "nombre",       tipo: "text:alpha:2:100", requerido: true },
  // Contacto
  { id: "email",        tipo: "email:verify",     requerido: true },
  { id: "telefono",     tipo: "phone:BO",         requerido: true },
  // Información personal
  { id: "fecha_nac",    tipo: "date",
    rango: { min: "hoy-100a", max: "hoy-18a" } },
  { id: "estado_civil", tipo: "enum:ESTADO_CIVIL" },
  // Información laboral
  { id: "salario",      tipo: "money:BOB",
    rango: { min: 2362, max: 50000 } },
  // Seguridad
  { id: "pass_nueva",   tipo: "password" },
  { id: "pass_conf",    tipo: "password",         igual_a: "pass_nueva" },
])
.al_enviar(async (valores, meta) => {
  // valores: objecto con todos los campos ya normalizados
  // meta: { errores_count: 0, tiempo_validacion_ms: 120 }
  await api.crearEmpleado(valores)
})
.ligar()
```

### 11.4 `.mostrar(selector)` — Display sin edición

```javascript
// Campo de solo lectura
bi18n.mostrar("#ci-display")
     .valor(empleado.ci)
     .tipo("CI:BO")
     .render()

// Con censura parcial (auditoría)
bi18n.mostrar("#ci-audit")
     .valor(empleado.ci)
     .tipo("CI:BO")
     .mascara("partial:2")
     .render()
// → "****-**1A"

// Batch para tabla — una sola llamada RPC
bi18n.mostrar_lote(filas, [
  { campo: "ci",      tipo: "CI:BO",    mascara: "partial:2" },
  { campo: "salario", tipo: "money:BOB", formato: "money:BOB" },
  { campo: "fecha",   tipo: "date",      formato: "date:medium" },
]).render("#tabla-empleados tbody")
```

---

## 12. Adaptadores de Framework

Cada adaptador envuelve el SDK (Capa 2) con la semántica del framework. La lógica de
validación, máscara y formato no se duplica.

### 12.1 Vue 3

```vue
<!-- Uso: <bi18n-campo tipo="CI:BO" v-model="ci" /> -->
<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { Bi18nSdk } from '@sbos/bi18n-sdk'

const props = defineProps(['tipo', 'requerido', 'rango'])
const modelo = defineModel()
const inputRef = ref(null)
const error = ref(null)
let binding = null

onMounted(() => {
  binding = Bi18nSdk.campo(inputRef.value)
    .tipo(props.tipo)
    .requerido(props.requerido)
    .rango(props.rango)
    .al_error(errs => error.value = errs[0])
    .al_exito(v => { modelo.value = v; error.value = null })
    .ligar()
})
onUnmounted(() => binding?.desligar())
</script>
<template>
  <div class="bi18n-campo">
    <input ref="inputRef" :value="modelo" />
    <span class="error" v-if="error">{{ error }}</span>
  </div>
</template>
```

### 12.2 React

```jsx
// Uso: <Bi18nCampo tipo="CI:BO" value={ci} onChange={setCi} />
import { useRef, useEffect, useState, forwardRef } from 'react'
import { Bi18nSdk } from '@sbos/bi18n-sdk'

export const Bi18nCampo = forwardRef(({ tipo, requerido, rango, value, onChange }, ref) => {
  const inputRef = useRef(null)
  const [error, setError] = useState(null)

  useEffect(() => {
    const binding = Bi18nSdk.campo(inputRef.current)
      .tipo(tipo).requerido(requerido).rango(rango)
      .al_error(errs => setError(errs[0]))
      .al_exito(v => { onChange(v); setError(null) })
      .ligar()
    return () => binding.desligar()
  }, [tipo])

  return (
    <div className="bi18n-campo">
      <input ref={inputRef} defaultValue={value} />
      {error && <span className="error">{error}</span>}
    </div>
  )
})
```

### 12.3 Flutter / Dart

```dart
// Uso: Bi18nCampo(tipo: "CI:BO", controller: _ctrl)
class Bi18nCampo extends StatefulWidget {
  final String tipo;
  final bool requerido;
  final TextEditingController controller;
  const Bi18nCampo({required this.tipo, required this.controller,
                    this.requerido = false, super.key});
  @override State<Bi18nCampo> createState() => _Bi18nCampoState();
}

class _Bi18nCampoState extends State<Bi18nCampo> {
  String? _error;
  Bi18nBinding? _binding;

  @override
  void initState() {
    super.initState();
    _binding = Bi18nSdk.campo(widget.controller)
      .tipo(widget.tipo)
      .requerido(widget.requerido)
      .alError((errs) => setState(() => _error = errs.first))
      .alExito((_) => setState(() => _error = null))
      .ligar();
  }

  @override
  void dispose() { _binding?.desligar(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(controller: widget.controller,
        decoration: InputDecoration(errorText: _error)),
    ],
  );
}
```

### 12.4 PyQt6

```python
# Uso: campo = Bi18nCampo(parent, tipo="phone:BO")
from PyQt6.QtWidgets import QWidget, QLineEdit, QLabel, QVBoxLayout
from bi18n_sdk import Bi18nSdk

class Bi18nCampo(QWidget):
    def __init__(self, parent=None, tipo="text", requerido=False):
        super().__init__(parent)
        self._sdk = Bi18nSdk()
        self.input = QLineEdit(self)
        self.error_label = QLabel("", self)
        layout = QVBoxLayout(self)
        layout.addWidget(self.input)
        layout.addWidget(self.error_label)
        self._binding = (self._sdk.campo(self.input)
                         .tipo(tipo)
                         .requerido(requerido)
                         .al_error(self._mostrar_error)
                         .al_exito(self._limpiar_error)
                         .ligar())

    def _mostrar_error(self, errores): self.error_label.setText(errores[0])
    def _limpiar_error(self, valor):  self.error_label.setText("")

    def closeEvent(self, event):
        self._binding.desligar()
        super().closeEvent(event)
```

---

## 13. Nuevos Métodos RPC del Daemon

Este anexo requiere los siguientes nuevos métodos en el daemon bi18n (implementación posterior):

| Método RPC | Descripción | Prioridad |
|---|---|---|
| `bi18n.validate.field` | Validar un campo con tipo DSL | ALTA |
| `bi18n.format.value` | Formatear un valor con token de formato | ALTA |
| `bi18n.mask.pattern` | Obtener patrón de máscara de entrada | ALTA |
| `bi18n.format.batch` | Formatear un lote de valores (una llamada) | ALTA |
| `bi18n.validate.email_existence` | Verificar existencia de email (async L3+L4) | MEDIA |
| `bi18n.validate.form` | Validar un formulario completo | MEDIA |
| `bi18n.catalog.get` | Obtener valores de catálogo para tipo enum | MEDIA |
| `bi18n.mask.display` | Aplicar máscara de visualización | BAJA |

---

*Fin del Anexo A.19 — v1.0.0*
*Documento generado por bi18n-developer · bi18nAgent · SBOS*
