# A.19 — Especificación SDK bi18n UI
## Validación, Formato, Máscara y Mensajes de Campos

**Versión:** 2.0.0
**Fecha:** 2026-07-18
**Estado:** ACTIVO
**Daemon:** bi18n (i18n-orchestrator)
**Estándares:** ICU4X 2.0 · CLDR 46 · RFC 5321 · E.164 · NIST 800-63B Rev.4 · Mozilla Fluent · UTS 35

---

## Índice

1. [Propósito y Principio Rector](#1-propósito-y-principio-rector)
2. [Arquitectura: JSON como Medio, SDK y CLI como Formas](#2-arquitectura-json-como-medio-sdk-y-cli-como-formas)
3. [JSON Config — Esquema Completo](#3-json-config--esquema-completo)
4. [Motor de Validación — Pipeline E1–E5](#4-motor-de-validación--pipeline-e1e5)
5. [Sistema de Máscaras](#5-sistema-de-máscaras)
6. [Sistema de Formatos](#6-sistema-de-formatos)
7. [Mensajes de Validación (Fluent FTL)](#7-mensajes-de-validación-fluent-ftl)
8. [Ciclo UX — Timing y Eventos](#8-ciclo-ux--timing-y-eventos)
9. [Email — Caso de Estudio Completo](#9-email--caso-de-estudio-completo)
10. [API del SDK — `bSet()` / `bUnSet()`](#10-api-del-sdk--bset--bunset)
11. [Adaptadores de Framework](#11-adaptadores-de-framework)
12. [CLI — Misma Validación desde Terminal](#12-cli--misma-validación-desde-terminal)
13. [Métodos RPC del Daemon](#13-métodos-rpc-del-daemon)

---

## 1. Propósito y Principio Rector

Este anexo especifica el **SDK bi18n UI**: la capa que permite a desarrolladores frontend
vincular campos de formulario al daemon bi18n con una API declarativa y uniforme.

### El problema que resuelve

Sin SDK, cada campo UI requiere llamadas RPC explícitas (~40 líneas por campo):

```javascript
// Sin SDK — un campo CI: ~40 líneas de boilerplate
const mascara = await ws.send({ method: "bi18n.mask.pattern", params: { tipo: "CI:BO" } })
IMask(document.querySelector("#ci"), mascara.result)
document.querySelector("#ci").addEventListener("blur", async () => {
  const r = await ws.send({ method: "bi18n.validate.field",
    params: { tipo: "CI:BO", value: campo.value, ctx_id: uuid() } })
  if (!r.result.valido) mostrarError(r.result.errores[0])
})
// × 10 campos = 400 líneas
```

Con SDK, el mismo campo se declara en una línea:

```javascript
bi18n.campo("#ci").tipo({ base: "CI", pais: "BO", msgError: "CI inválida" }).bSet()
```

### Principio rector

**La complejidad vive en el servidor. El JSON es el contrato. La forma de entregarlo no importa.**

El daemon bi18n (Rust) implementa toda la lógica: validación, formato, máscara y mensajes.
El SDK cliente es declarativo — describe *qué* es el campo en un JSON config.
El CLI hace exactamente lo mismo enviando el mismo JSON por JSON-RPC.
Un solo motor evalúa ambos.

---

## 2. Arquitectura: JSON como Medio, SDK y CLI como Formas

```
              ┌─────────────────────────────────────────┐
              │            JSON CONFIG                   │
              │  { base: "money", moneda: "BOB",        │
              │    min: 0, max: 50000,                  │
              │    msgOk: "Válido",                     │
              │    msgError: "Fuera de rango" }         │
              └──────────────┬──────────────────────────┘
                             │  (el medio — inmutable)
              ┌──────────────┴──────────────────────────┐
              │                                         │
   ┌──────────▼──────────┐               ┌─────────────▼──────────┐
   │    SDK  (forma 1)   │               │    CLI  (forma 2)      │
   │                     │               │                        │
   │  bi18n              │               │  bi18nctl validate     │
   │   .campo("#monto")  │               │  '{ "base":"money",    │
   │   .tipo({...})      │               │    "moneda":"BOB",     │
   │   .bSet()           │               │    "value":"75000",    │
   │   .onValid(cb)      │               │    "ctx_id":"t-001"}'  │
   │   .onInvalid(cb)    │               │                        │
   └──────────┬──────────┘               └─────────────┬──────────┘
              │                                         │
              └─────────────────┬───────────────────────┘
                                │
                   ┌────────────▼────────────┐
                   │      bi18n daemon       │
                   │                         │
                   │   UN SOLO MOTOR Rust    │
                   │   bi18n.validate.field  │
                   │                         │
                   │  Valida · Formatea      │
                   │  Enmascara · Mensajes   │
                   └─────────────────────────┘
```

**El JSON es el medio.** El SDK y el CLI son dos formas distintas de entregar el mismo
JSON al mismo motor. Lo que pasa en CLI pasa idéntico en SDK — no hay diferencia de motor.

**Consecuencia práctica:** un desarrollador puede diseñar y probar toda la lógica de
validación de un formulario desde el CLI antes de escribir una sola línea de frontend.
Si pasa en CLI → pasa en SDK. Garantizado.

---

## 3. JSON Config — Esquema Completo

`tipo()` siempre recibe un JSON. No existen atajos de string.
La consistencia entre desarrolladores es más valiosa que la brevedad.

### 3.1 Estructura general

```javascript
{
  // ── REQUERIDO ─────────────────────────────────────────────────────────
  "base": "CI|NIT|email|phone|date|money|number|text|password|bool|enum",

  // ── SUBTIPOS (según base) ─────────────────────────────────────────────
  "pais":     "BO|AR|BR|...",          // CI, NIT, phone
  "moneda":   "BOB|USD|EUR|...",       // money
  "subtipo":  "integer|decimal|percent|alpha|alphanumeric",  // number, text
  "decimales": 2,                      // number, money
  "catalogo": "nombre_enum",           // enum

  // ── RANGO ─────────────────────────────────────────────────────────────
  "min":       0,                      // number, money (valor mínimo)
  "max":       50000,                  // number, money (valor máximo)
  "min_fecha": "1900-01-01",           // date (ISO 8601 o expresión relativa)
  "max_fecha": "hoy-18a",             // date
  "min_chars": 3,                      // text
  "max_chars": 100,                    // text

  // ── VALIDACIÓN CRUZADA ENTRE CAMPOS ──────────────────────────────────
  "confirmar":  "#selector",           // valor debe coincidir con otro campo
  "distinto":   "#selector",           // valor debe diferir de otro campo
  "mayor_que":  "#selector",           // valor debe ser mayor (number, date)
  "menor_que":  "#selector",           // valor debe ser menor (number, date)

  // ── VERIFICACIÓN ASYNC (email) ────────────────────────────────────────
  "verificar_mx":   false,             // email: verificar registros MX (L3)
  "verificar_smtp": false,             // email: handshake SMTP RCPT TO (L4)
  "detectar_typo":  true,              // email: sugerir corrección de typo
  "rechazar_temporal": true,           // email: bloquear dominios desechables

  // ── CONTROL DE ENTRADA ────────────────────────────────────────────────
  "requerido":   true,                 // campo requerido
  "mask":        "0000000-aA",         // override de máscara de entrada
  "format":      "date:long",          // override de formato display

  // ── UX ────────────────────────────────────────────────────────────────
  "placeholder": "Ingrese valor",
  "label":       "Precio de venta",    // usado en mensajes de error

  // ── MENSAJES PERSONALIZADOS ───────────────────────────────────────────
  "msgOk":    "Dato válido",           // se emite en evento onValid
  "msgWarn":  "Monto alto — revise",  // se emite en evento onWarn
  "msgError": "Valor fuera de rango"  // se emite en evento onInvalid
}
```

### 3.2 Tabla de valores `base` válidos

| `base` | Descripción | Subtipos / parámetros clave |
|---|---|---|
| `CI` | Cédula de identidad | `pais: "BO\|AR\|BR"` |
| `NIT` | NIT/RUC/CUIT tributario | `pais: "BO\|AR\|PE"` |
| `email` | Correo electrónico | `verificar_mx`, `verificar_smtp`, `detectar_typo` |
| `phone` | Teléfono | `pais: "BO\|AR\|BR"` |
| `date` | Fecha | `min_fecha`, `max_fecha` (ISO o expresión relativa) |
| `money` | Monto monetario | `moneda: "BOB\|USD\|EUR"`, `min`, `max` |
| `number` | Número genérico | `subtipo: "integer\|decimal\|percent"`, `decimales`, `min`, `max` |
| `text` | Texto | `subtipo: "alpha\|alphanumeric"`, `min_chars`, `max_chars` |
| `password` | Contraseña NIST | — |
| `bool` | Booleano | — |
| `enum` | Catálogo bi18n | `catalogo: "nombre"` |

### 3.3 Expresiones de fecha relativa

En `min_fecha` y `max_fecha` el daemon resuelve:

| Expresión | Significado |
|---|---|
| `hoy` | Fecha actual del servidor |
| `hoy-Nd` | N días antes de hoy |
| `hoy+Nd` | N días después de hoy |
| `hoy-Na` | N años antes de hoy (ej: `hoy-18a` = mayoría de edad) |
| `inicio-mes` | Primer día del mes actual |
| `fin-anio` | 31 de diciembre del año actual |
| `2026-01-01` | Fecha absoluta ISO 8601 |

### 3.4 Ejemplos de JSON config por tipo

```javascript
// CI Bolivia
{ base: "CI", pais: "BO", requerido: true,
  msgError: "Cédula de identidad inválida" }

// Email con verificación completa
{ base: "email", requerido: true,
  verificar_mx: true, detectar_typo: true, rechazar_temporal: true,
  msgOk: "Correo válido", msgError: "Correo inválido o inexistente" }

// Confirmación de email
{ base: "email", confirmar: "#email",
  msgOk: "Los correos coinciden", msgError: "Los correos no coinciden" }

// Contraseña + confirmación
{ base: "password", requerido: true,
  msgOk: "Contraseña válida", msgError: "Mínimo 8 caracteres" }
{ base: "password", confirmar: "#password",
  msgOk: "Las contraseñas coinciden", msgError: "Las contraseñas no coinciden" }

// Fecha de nacimiento (mayoría de edad)
{ base: "date", min_fecha: "hoy-100a", max_fecha: "hoy-18a",
  requerido: true, msgError: "Debe ser mayor de 18 años" }

// Rango de fechas (fin > inicio)
{ base: "date", mayor_que: "#fecha_inicio",
  msgError: "La fecha fin debe ser posterior al inicio" }

// Monto con rango y advertencia
{ base: "money", moneda: "BOB", min: 0, max: 50000,
  msgOk: "Monto válido",
  msgWarn: "Montos mayores a Bs. 40.000 requieren aprobación",
  msgError: "El monto debe estar entre Bs. 0 y Bs. 50.000" }

// Número decimal con rango
{ base: "number", subtipo: "decimal", decimales: 2, min: 0.1, max: 100,
  msgError: "El valor debe estar entre 0,10 y 100,00" }

// Texto con longitud
{ base: "text", min_chars: 3, max_chars: 100, requerido: true,
  msgError: "El campo debe tener entre 3 y 100 caracteres" }

// Porcentaje
{ base: "number", subtipo: "percent",
  msgError: "El porcentaje debe estar entre 0 y 100" }
```

---

## 4. Motor de Validación — Pipeline E1–E5

### 4.1 Pipeline de cinco etapas

```
[E1 Pre-check] → [E2 Formato] → [E3 Rango] → [E4 Regla] → [E5 Async]
```

Ejecución en orden estricto con cortocircuito: si una etapa falla, las siguientes no se
ejecutan. E5 solo actúa si E1–E4 pasan y el tipo requiere verificación async.

| Etapa | Nombre | Qué valida | Tiempo |
|---|---|---|---|
| E1 | Pre-check | Campo requerido · no vacío · longitud mínima de sensatez | < 0.1 ms |
| E2 | Formato | Regex/tipo · caracteres permitidos · estructura sintáctica | < 1 ms |
| E3 | Rango | min/max numérico · rango de fecha · longitud de texto · comparación cruzada | < 1 ms |
| E4 | Regla | Dígito verificador · checksum · semántica · coincidencia cruzada | < 5 ms |
| E5 | Async | DNS MX · SMTP RCPT · HaveIBeenPwned · RPC externo | 50–2000 ms |

### 4.2 Reglas por tipo base

**CI:BO**
```
E2: /^\d{5,8}(-[A-Z]{2})?$/ (sin complemento) ó /^\d{5,8}-[A-Z0-9]{2,3}$/ (con complemento)
E4: extensión válida = LP|CB|SC|OR|PT|TJ|CH|BE|PD
```

**NIT:BO**
```
E2: /^\d{7,11}-\d$/
E4: verificador = módulo 11 (SIN Bolivia RND 102100000011)
```

**email**
```
E2: RFC 5321 — local part: max 64 chars; dominio max 253 chars; total max 254 chars
E4: sin puntos dobles; sin IP literal sin corchetes
E5 (verificar_mx):  DNS MX lookup (~200 ms)
E5 (verificar_smtp): SMTP RCPT TO handshake (~500–2000 ms)
```

**phone:BO**
```
E2: /^\d{7,8}$/
E4: prefijos válidos: 6x|7x (móvil) · 2x (LP) · 4x (CB) · 3x (SC)
```

**date**
```
E2: fecha gregoriana válida — día, mes, año coherentes
E3: min_fecha ≤ fecha ≤ max_fecha (expresiones relativas resueltas en servidor)
E4: año en rango [1900, 2200]
```

**money**
```
E2: número válido (coma o punto decimal — normalizado al recibir)
E3: valor ≥ min AND valor ≤ max
E4: máx 2 decimales (BOB/USD/EUR); 0 decimales (JPY)
```

**password** — NIST 800-63B Rev.4
```
E2: longitud ≥ 8 caracteres Unicode (no bytes)
E4: no igual a usuario/email/CI del formulario; sin secuencias comunes
E5: HaveIBeenPwned (k-anonymity: SHA-1[:5], ~100 ms)
```

**Validación cruzada** (E3/E4)
```
confirmar  → valor == campo_ref.valor_normalizado
distinto   → valor != campo_ref.valor_normalizado
mayor_que  → valor > campo_ref.valor_normalizado  (numérico o fecha ISO)
menor_que  → valor < campo_ref.valor_normalizado
```

---

## 5. Sistema de Máscaras

### 5.1 Máscara de entrada vs. máscara de visualización

| Tipo | Cuándo aplica | Propósito |
|---|---|---|
| **Entrada** | Mientras el usuario escribe | Guiar al formato correcto |
| **Visualización** | Al mostrar un valor almacenado | Formato legible o censura PII |

Son independientes. El campo `mask` del JSON config hace override de la máscara de entrada
por defecto del daemon (útil para formatos nacionales alternativos).

### 5.2 Máscaras de entrada por tipo (defaults del daemon)

Basadas en **IMask.js** — el cliente las aplica con `IMask(element, patron)`.

| base | Patrón | Motor IMask | Placeholder |
|---|---|---|---|
| `CI:BO` | `0000000-aA` | Pattern | `_______-__` |
| `NIT:BO` | `000000000-0` | Pattern | `_________-_` |
| `phone:BO` | `0 000-0000` | Pattern | `_ ___-____` |
| `date` | `DD/MM/YYYY` con bloques | Date | `dd/mm/aaaa` |
| `money:BOB` | scale:2 radix:"," sep:"." | Number | — |
| `money:USD` | scale:2 radix:"." sep:"," | Number | — |
| `number:decimal` | scale:n radix:"," sep:"." | Number | — |
| `email` `text` `password` | ninguna (libre) | none | — |

**Recomendación USWDS:** usar máscara solo en campos de formato fijo (CI, NIT, fecha,
teléfono, monto, tarjeta). No usar en email, texto libre ni contraseña.

### 5.3 Máscara de visualización (valores almacenados)

```
partial:{n}    → muestra los últimos n caracteres, resto como *
full           → todos los caracteres como •
format:{token} → aplica el formato display del tipo
e164           → normaliza a E.164 (+591xxxxxxxx)

Ejemplos:
"1234567-LP"  + partial:2  → "****-**LP"
"71234567"    + e164        → "+59171234567"
"71234567"    + format:phone:national:BO → "7 123-4567"
```

---

## 6. Sistema de Formatos

Todos los formatos usan **ICU4X 2.0** en el daemon Rust (datos CLDR 46 embebidos).

### 6.1 Fecha

| Token `format` | Resultado es-BO | Resultado en-US |
|---|---|---|
| `date:short` | 16/07/2026 | 7/16/2026 |
| `date:medium` | 16 jul. 2026 | Jul 16, 2026 |
| `date:long` | 16 de julio de 2026 | July 16, 2026 |
| `date:full` | jueves, 16 de julio de 2026 | Thursday, July 16, 2026 |
| `datetime:short` | 16/07/2026 14:30 | 7/16/2026 2:30 PM |
| `time:short` | 14:30 | 2:30 PM |
| `relative` | hace 2 horas | 2 hours ago |

### 6.2 Monto

| Token `format` | Resultado es-BO |
|---|---|
| `money:BOB` | Bs. 1.250,50 |
| `money:USD` | $ 1,250.50 |
| `money:BOB:no-symbol` | 1.250,50 |
| `money:BOB:accounting` | (Bs. 1.250,50) |
| `money:BOB:compact` | Bs. 1,25K |
| `money:BOB:verbose` | Un mil doscientos cincuenta bolivianos con 50 centavos |

### 6.3 Número

| Token `format` | Resultado es-BO |
|---|---|
| `number:integer` | 1.250 |
| `number:decimal:2` | 1.250,50 |
| `number:percent:1` | 85,3 % |
| `number:scientific` | 1,25 × 10³ |

### 6.4 Teléfono

| Token `format` | Resultado |
|---|---|
| `phone:national:BO` | 7 123-4567 |
| `phone:international:BO` | +591 7 123-4567 |
| `phone:e164` | +59171234567 |

**Regla de almacenamiento:** guardar siempre en E.164. Mostrar en formato nacional.

---

## 7. Mensajes de Validación (Fluent FTL)

### 7.1 Prioridad de mensajes

```
1. msgOk / msgWarn / msgError del JSON config     (máxima prioridad — campo específico)
2. Mensajes Fluent FTL del daemon                 (por tipo base — localizados)
3. Mensaje genérico de fallback                   (si FTL no tiene la clave)
```

El JSON config siempre gana. Fluent FTL es el fallback cuando el dev no especifica mensajes.

### 7.2 Catálogo Fluent FTL — es-BO (extracto)

```fluent
## General
campo-requerido = Este campo es obligatorio.
campo-demasiado-corto = Mínimo { $min } { $min -> [one] carácter *[other] caracteres }.
campo-demasiado-largo = Máximo { $max } caracteres.

## CI Bolivia
error-ci-invalido = Cédula de identidad inválida. Formato esperado: { $ejemplo }.

## NIT Bolivia
error-nit-invalido = NIT inválido. Formato esperado: { $ejemplo }.

## Email
error-email-invalido = Ingrese un correo electrónico válido (ej.: usuario@empresa.com).
email-no-encontrado =
    Esta dirección no parece existir.
    .sugerencia = ¿Quiso escribir { $sugerencia }?
email-descartable = No se permiten correos temporales o desechables.

## Teléfono
error-telefono-invalido = Número de teléfono no válido. { $detalle }
error-telefono-pais = El número no corresponde a { $pais }.

## Fecha
error-fecha-invalida = Fecha inválida. Use el formato DD/MM/AAAA.
fecha-fuera-rango = La fecha debe estar entre { $desde } y { $hasta }.
fecha-mayor-de-edad = Debe ser mayor de { $edad } años.

## Monto
monto-fuera-rango = El monto debe estar entre { $min } y { $max }.
monto-demasiado-grande = El monto no puede superar { $max }.

## Contraseña
error-password-corto = La contraseña debe tener al menos { $min } caracteres.
password-muy-comun = Esta contraseña es demasiado común. Elija una diferente.
password-comprometida = Esta contraseña aparece en filtraciones conocidas.

## Cruzada
campos-no-coinciden = Los valores de "{ $label1 }" y "{ $label2 }" no coinciden.
fecha-fin-antes-inicio = La fecha de fin debe ser posterior a la de inicio.
```

---

## 8. Ciclo UX — Timing y Eventos

### 8.1 Timing de validación

Basado en Nielsen Norman Group + estudios 2024–2026.

| Evento DOM | Acción del SDK | Justificación |
|---|---|---|
| `input` / `keydown` | Solo aplicar máscara de entrada | Errores al teclear son hostiles |
| `blur` (primera vez) | E1+E2+E3+E4 → `onValid` / `onInvalid` / `onWarn` | El usuario terminó el campo |
| `blur` + E5 aplica | E5 con debounce 800 ms → evento al completar | Solo si E1–E4 pasan |
| `input` (campo con error previo) | Re-ejecutar E1–E4 | Feedback positivo al corregir |
| `input` (campo `confirmar`) | Validar cruzada inmediatamente | Espera "coinciden" en tiempo real |
| `submit` | E1–E5 en todos los campos | Última barrera — mostrar todos los errores |

### 8.2 Eventos del Vinculo

Cada llamada a `bSet()` retorna un `Vinculo`. Sus cuatro eventos cubren todos los estados:

| Evento | Cuándo se dispara | Argumento del callback |
|---|---|---|
| `onValid(cb)` | Campo supera todas las validaciones | `{ valido: true, mensaje: msgOk, valor_normalizado, metadata }` |
| `onInvalid(cb)` | Campo falla alguna validación | `{ valido: false, mensaje: msgError, errores: [] }` |
| `onWarn(cb)` | Válido pero con advertencia (`msgWarn`) | `{ valido: true, mensaje: msgWarn, valor_normalizado }` |
| `onError(cb)` | Error de sistema (daemon no disponible) | `Error — detalles de la falla de red/socket` |

### 8.3 Estados visuales del campo

```
PRISTINE    → sin interacción. Sin indicador visual.
TOUCHED     → usuario escribe. Solo máscara activa.
VALID       → blur + validación OK. → emite onValid. Mostrar ✓ verde + msgOk.
WARN        → blur + válido con advertencia. → emite onWarn. Mostrar ⚠ amarillo + msgWarn.
INVALID     → blur + validación falla. → emite onInvalid. Mostrar ✗ rojo + msgError.
VERIFYING   → E5 en curso. Spinner. Campo no editable.
ERROR_SYS   → daemon no disponible. → emite onError. Aviso de sistema.
```

---

## 9. Email — Caso de Estudio Completo

### 9.1 Las cuatro capas de validación

```
L1 Formato (E2, < 1 ms)
   └─ Regex RFC 5321 — local part + dominio + longitud total
   └─ Rechaza: "usuario@" · "@dominio" · "sin-arroba"

L2 Sintaxis avanzada + blacklist (E4, < 5 ms)
   └─ Blacklist de dominios temporales: mailnull.com, 10minutemail.*, guerrillamail.*
   └─ Detección de typos: "gmial.com" → sugerencia "gmail.com"

L3 DNS MX (E5 verificar_mx: true, ~200 ms al blur con debounce 800 ms)
   └─ ¿El dominio tiene registros MX?

L4 SMTP RCPT TO (E5 verificar_smtp: true, ~500–2000 ms al submit)
   └─ Handshake SMTP sin enviar correo — ¿el buzón existe?
```

### 9.2 Configuración por caso de uso

```javascript
// Caso A: registro — máxima verificación
bi18n.campo("#email").tipo({
  base: "email", requerido: true,
  verificar_mx: true, verificar_smtp: true,
  detectar_typo: true, rechazar_temporal: true,
  msgOk:    "Correo verificado",
  msgError:  "Correo inválido o inexistente"
}).bSet().onValid(r => marcarVerde(r)).onInvalid(r => marcarRojo(r))

// Caso B: búsqueda — solo formato
bi18n.campo("#buscar").tipo({
  base: "email", requerido: false
}).bSet()

// Caso C: con confirmación
bi18n.campo("#email").tipo({
  base: "email", requerido: true, msgOk: "Email válido"
}).bSet()

bi18n.campo("#email_confirm").tipo({
  base: "email", confirmar: "#email",
  msgOk: "Los emails coinciden", msgError: "Los emails no coinciden"
}).bSet().onValid(r => mostrar(r.mensaje)).onInvalid(r => mostrar(r.mensaje))
```

---

## 10. API del SDK — `bSet()` / `bUnSet()`

### 10.1 Flujo completo

```javascript
const vinculo = bi18n
  .campo("#selector")     // selector CSS del elemento input
  .tipo({ ... })          // JSON config (siempre JSON — no strings)
  .bSet()                 // activa máscara + validación + eventos → retorna Vinculo
  .onValid(r  => { /* campo válido   */ })
  .onInvalid(r => { /* campo inválido */ })
  .onWarn(r   => { /* advertencia    */ })
  .onError(e  => { /* error sistema  */ })

// Al destruir el componente / cerrar modal / cambiar paso:
vinculo.bUnSet()
```

### 10.2 Interface `Vinculo`

```typescript
interface ResultadoValidacion {
  valido:            boolean;
  valor_normalizado: string;
  mensaje:           string;    // msgOk | msgWarn | msgError según estado
  errores:           string[];  // errores técnicos del pipeline
  metadata:          Record<string, unknown>;
}

interface Vinculo {
  bUnSet(): void;                                            // destruye máscara y listeners
  onValid  (cb: (r: ResultadoValidacion) => void): Vinculo; // chainable
  onInvalid(cb: (r: ResultadoValidacion) => void): Vinculo;
  onWarn   (cb: (r: ResultadoValidacion) => void): Vinculo;
  onError  (cb: (e: Error)              => void): Vinculo;
  readonly valor: string;   // valor normalizado actual
}
```

### 10.3 Ejemplos de formularios completos

**Formulario de registro (estático — página vive toda la sesión):**

```javascript
// Los vínculos se crean al cargar la página
const campos = [
  bi18n.campo("#ci").tipo({
    base: "CI", pais: "BO", requerido: true,
    msgOk: "CI válida", msgError: "CI inválida"
  }).bSet()
    .onValid(r  => marcar("#ci", "verde", r.mensaje))
    .onInvalid(r => marcar("#ci", "rojo",  r.mensaje)),

  bi18n.campo("#email").tipo({
    base: "email", requerido: true,
    verificar_mx: true, detectar_typo: true, rechazar_temporal: true,
    msgOk: "Email válido", msgError: "Email inválido"
  }).bSet()
    .onValid(r  => marcar("#email", "verde", r.mensaje))
    .onInvalid(r => marcar("#email", "rojo",  r.mensaje)),

  bi18n.campo("#fecha_nac").tipo({
    base: "date", min_fecha: "hoy-100a", max_fecha: "hoy-18a",
    requerido: true, msgError: "Debe ser mayor de 18 años"
  }).bSet()
    .onInvalid(r => marcar("#fecha_nac", "rojo", r.mensaje)),

  bi18n.campo("#password").tipo({
    base: "password", requerido: true,
    msgOk: "Contraseña válida", msgError: "Mínimo 8 caracteres"
  }).bSet(),

  bi18n.campo("#password_confirm").tipo({
    base: "password", confirmar: "#password",
    msgOk: "Las contraseñas coinciden", msgError: "Las contraseñas no coinciden"
  }).bSet()
    .onValid(r  => marcar("#password_confirm", "verde", r.mensaje))
    .onInvalid(r => marcar("#password_confirm", "rojo",  r.mensaje)),
]

// Al salir de la página (SPA navigation)
window.addEventListener("beforeunload", () => campos.forEach(v => v.bUnSet()))
```

**Modal que se abre y cierra (bUnSet obligatorio):**

```javascript
let vinculos = []

btnAbrir.onclick = () => {
  abrirModal()
  vinculos = [
    bi18n.campo("#monto").tipo({
      base: "money", moneda: "BOB", min: 100, max: 50000,
      msgOk:    "Monto válido",
      msgWarn:  "Monto alto — requiere aprobación de gerencia",
      msgError: "El monto debe estar entre Bs. 100 y Bs. 50.000"
    }).bSet()
      .onValid  (r => marcar("#monto", "verde",    r.mensaje))
      .onWarn   (r => marcar("#monto", "amarillo", r.mensaje))
      .onInvalid(r => marcar("#monto", "rojo",     r.mensaje))
      .onError  (e => mostrarAlerta("bi18n no disponible: " + e.message)),
  ]
}

btnCerrar.onclick = () => {
  vinculos.forEach(v => v.bUnSet())  // limpia listeners antes de cerrar
  vinculos = []
  cerrarModal()
}
```

**Formulario wizard multi-paso:**

```javascript
const pasos = { actual: 1, vinculos: [] }

function cargarPaso(n) {
  pasos.vinculos.forEach(v => v.bUnSet())  // destruir paso anterior
  pasos.vinculos = []
  pasos.actual = n

  if (n === 1) {
    pasos.vinculos = [
      bi18n.campo("#ci").tipo({ base: "CI", pais: "BO", requerido: true }).bSet(),
      bi18n.campo("#nombre").tipo({ base: "text", min_chars: 2, max_chars: 80, requerido: true }).bSet(),
    ]
  } else if (n === 2) {
    pasos.vinculos = [
      bi18n.campo("#monto").tipo({ base: "money", moneda: "BOB", min: 0, max: 50000 }).bSet(),
      bi18n.campo("#fecha_pago").tipo({ base: "date", min_fecha: "hoy" }).bSet(),
    ]
  }
}
```

### 10.4 `.mostrar()` — formato display sin binding

```javascript
// Mostrar un valor almacenado formateado
bi18n.mostrar("#span-fecha")
     .valor("2026-07-18")
     .formato({ base: "date", format: "date:long" })
     .aplicar()
// → span muestra "18 de julio de 2026"

// Lote de valores
bi18n.mostrar_lote([
  { selector: "#ci-display",    valor: "7654321-LP",  tipo: { base: "CI", mask: "partial:2" } },
  { selector: "#monto-display", valor: "2500.75",     tipo: { base: "money", moneda: "BOB" } },
  { selector: "#fecha-display", valor: "2026-07-18",  tipo: { base: "date", format: "date:long" } },
])
```

---

## 11. Adaptadores de Framework

Los adaptadores (~30 líneas) mapean el ciclo de vida del framework a `bSet()`/`bUnSet()`.

### 11.1 Vue 3

```javascript
// composable: usebi18n.js
import { onMounted, onUnmounted } from 'vue'

export function useCampo(selector, tipoConfig) {
  let vinculo = null
  const estado = reactive({ valido: null, mensaje: '' })

  onMounted(() => {
    vinculo = bi18n.campo(selector).tipo(tipoConfig).bSet()
      .onValid  (r => { estado.valido = true;  estado.mensaje = r.mensaje })
      .onInvalid(r => { estado.valido = false; estado.mensaje = r.mensaje })
      .onWarn   (r => { estado.valido = 'warn'; estado.mensaje = r.mensaje })
  })
  onUnmounted(() => vinculo?.bUnSet())

  return { estado }
}

// Uso en componente:
const { estado } = useCampo('#monto', {
  base: "money", moneda: "BOB", min: 0, max: 50000,
  msgOk: "Válido", msgError: "Fuera de rango"
})
```

### 11.2 React

```javascript
// hook: usebi18n.js
import { useEffect, useRef, useState } from 'react'

export function useCampo(selector, tipoConfig) {
  const vinculo = useRef(null)
  const [estado, setEstado] = useState({ valido: null, mensaje: '' })

  useEffect(() => {
    vinculo.current = bi18n.campo(selector).tipo(tipoConfig).bSet()
      .onValid  (r => setEstado({ valido: true,   mensaje: r.mensaje }))
      .onInvalid(r => setEstado({ valido: false,  mensaje: r.mensaje }))
      .onWarn   (r => setEstado({ valido: 'warn', mensaje: r.mensaje }))
    return () => vinculo.current?.bUnSet()
  }, [selector])

  return { estado }
}
```

### 11.3 Flutter (Dart)

```dart
class Bi18nField extends StatefulWidget {
  final String selector;
  final Map<String, dynamic> tipoConfig;
  const Bi18nField({ required this.selector, required this.tipoConfig });

  @override State<Bi18nField> createState() => _Bi18nFieldState();
}

class _Bi18nFieldState extends State<Bi18nField> {
  Vinculo? _vinculo;
  String _mensaje = '';
  bool? _valido;

  @override
  void initState() {
    super.initState();
    _vinculo = bi18n.campo(widget.selector).tipo(widget.tipoConfig).bSet()
      ..onValid  ((r) => setState(() { _valido = true;  _mensaje = r.mensaje; }))
      ..onInvalid((r) => setState(() { _valido = false; _mensaje = r.mensaje; }));
  }

  @override void dispose() { _vinculo?.bUnSet(); super.dispose(); }
}
```

### 11.4 PyQt6

```python
class Bi18nInput(QLineEdit):
    def __init__(self, tipo_config: dict, parent=None):
        super().__init__(parent)
        self._vinculo = None
        self._tipo_config = tipo_config

    def showEvent(self, event):
        super().showEvent(event)
        self._vinculo = (bi18n.campo(self)
            .tipo(self._tipo_config)
            .bSet()
            .on_valid(lambda r: self._marcar("verde", r["mensaje"]))
            .on_invalid(lambda r: self._marcar("rojo", r["mensaje"])))

    def hideEvent(self, event):
        if self._vinculo: self._vinculo.b_unset()
        super().hideEvent(event)
```

---

## 12. CLI — Misma Validación desde Terminal

El CLI (`bi18nctl`) entrega el mismo JSON al mismo motor. Lo que pasa en CLI es
exactamente lo que pasará en el SDK. Ideal para diseñar y probar reglas antes del frontend.

### 12.1 Validar un campo

```bash
# CI Bolivia válida
bi18nctl validate '{
  "base":     "CI",
  "pais":     "BO",
  "value":    "7654321-LP",
  "ctx_id":   "test-001"
}'
# → { "valido": true, "valor_normalizado": "7654321-LP", "errores": [] }

# Monto fuera de rango
bi18nctl validate '{
  "base":     "money",
  "moneda":   "BOB",
  "min":      100,
  "max":      50000,
  "value":    "75000",
  "msgError": "El monto excede el límite autorizado",
  "ctx_id":   "test-002"
}'
# → { "valido": false, "errores": ["El monto excede el límite autorizado"] }

# Validación cruzada — confirmación de email (simula dos campos)
bi18nctl validate '{
  "base":      "email",
  "confirmar_valor": "juan@empresa.com",
  "value":     "juan@empresa.com",
  "msgOk":     "Los emails coinciden",
  "msgError":  "Los emails no coinciden",
  "ctx_id":    "test-003"
}'
```

### 12.2 Obtener patrón de máscara

```bash
bi18nctl mask-pattern '{ "base": "CI", "pais": "BO", "ctx_id": "test-004" }'
# → { "motor": "Pattern", "patron": "0000000-aA", "placeholder": "_______-__", ... }

bi18nctl mask-pattern '{ "base": "money", "moneda": "BOB", "ctx_id": "test-005" }'
# → { "motor": "Number", "opciones": { "scale": 2, "radix": ",", ... } }
```

### 12.3 Formatear un valor

```bash
bi18nctl format '{
  "base":   "date",
  "format": "date:long",
  "value":  "2026-07-18T00:00:00Z",
  "regional_config": { "locale": "es-BO", "timezone": "America/La_Paz",
                       "currency": "BOB", "country": "BO" },
  "ctx_id": "test-006"
}'
# → { "formateado": "18 de julio de 2026" }
```

---

## 13. Métodos RPC del Daemon

Tres métodos SDK ya implementados y verificados en producción.

### 13.1 `bi18n.validate.field`

```json
// Request — el JSON config más "value" y "ctx_id"
{
  "jsonrpc": "2.0", "id": 1,
  "method": "bi18n.validate.field",
  "params": {
    "tipo":      { "base": "money", "moneda": "BOB", "min": 0, "max": 50000 },
    "value":     "2500.75",
    "required":  true,
    "ctx_id":    "uuid-v4"
  }
}

// Response — válido
{
  "result": {
    "valido": true,
    "errores": [],
    "valor_normalizado": "2500.75",
    "metadata": { "numerico": 2500.75 }
  }
}

// Response — inválido
{
  "result": {
    "valido": false,
    "errores": ["El valor debe ser menor o igual a 50000."],
    "valor_normalizado": "",
    "metadata": {}
  }
}
```

### 13.2 `bi18n.format.value`

```json
{
  "method": "bi18n.format.value",
  "params": {
    "formato": "money:BOB",
    "value":   "2500.75",
    "regional_config": { "locale": "es-BO", "timezone": "America/La_Paz",
                         "currency": "BOB", "country": "BO" },
    "ctx_id":  "uuid-v4"
  }
}
// Response: { "formateado": "Bs. 2.500,75" }
```

### 13.3 `bi18n.mask.pattern`

```json
{
  "method": "bi18n.mask.pattern",
  "params": { "tipo": { "base": "CI", "pais": "BO" }, "ctx_id": "uuid-v4" }
}
// Response:
{
  "result": {
    "motor":        "Pattern",
    "patron":       "0000000-aA",
    "opciones":     { "definitions": { "0": "[0-9]", "a": "[a-zA-Z]" } },
    "placeholder":  "_______-__",
    "usar_mascara": true
  }
}
```

### 13.4 Evidencia de funcionamiento (producción)

Pruebas verificadas contra daemon real en `/tmp/bi18n-test/bi18n.sock`:

```
✓ validate.field CI:BO "7654321-LP"      → { valido: true, normalizado: "7654321-LP" }
✓ validate.field email inválido           → { valido: false, errores: ["RFC 5321..."] }
✓ validate.field campo requerido vacío   → { valido: false, errores: ["Este campo es requerido."] }
✓ validate.field phone:BO "71234567"     → { valido: true, e164: "+59171234567" }
✓ validate.field date "18/07/2026"       → { valido: true, normalizado: "2026-07-18" }
✓ validate.field money rango [100,50000] → { valido: false, errores: ["≤ 50000"] }
✓ validate.field password corto          → { valido: false, errores: ["≥ 8 caracteres"] }
✓ format.value date → "17 de julio de 2026"
✓ format.value money:BOB → "Bs. 2.500,75"
✓ format.value phone:national:BO → "71234567"
✓ mask.pattern CI:BO → motor Pattern, patron "0000000-aA"
✓ mask.pattern date  → motor Date, patron "DD/MM/YYYY"
✓ mask.pattern money:BOB → motor Number, scale 2, radix ","
✓ mask.pattern email → motor none, usar_mascara: false
```
