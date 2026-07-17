# A.12 — Batería de pruebas Frontend/WebSocket — bi18n (completa)

**Versión:** 1.0.0
**Fecha:** 2026-07-18
**Destinatario:** Agente Testeador (fábrica ORQUESTA) — dictamina VERDADERO/FALSO con evidencia.
**Protocolo:** WebSocket TCP (`ws://127.0.0.1:9454`) + JSON-RPC 2.0
**Herramienta de prueba principal:** `websocat` (WebSocket client para terminal)
**Herramienta alternativa:** `socat` (sobre el socket Unix `/run/bos/bi18n.sock`)
**Prerequisito:** `bi18nd` activo, WebSocket server escuchando en el puerto 9454.
**Manual de referencia:** [1.03 Manual del Programador](../1.03_MANUAL-PROGRAMADOR-BI18N-v1.0.md)
**Anexo de arquitectura:** [A.04 Ligadura Frontend](A.04_ANEXO-BI18N-TECNICA-LIGADURA-FRONTEND-v2.1.md)

**Convención de resultados:**
- `PASS` = respuesta contiene `"result"` con el campo esperado
- `FAIL` = respuesta contiene `"error"` o campo faltante
- Push events se verifican dejando la conexión abierta y esperando mensajes adicionales.

---

## §0 Preparación del entorno

```bash
# Instalar websocat (una sola vez)
cargo install websocat
# o en Debian/Ubuntu:
apt install websocat

# Verificar WebSocket activo
websocat -q ws://127.0.0.1:9454 <<< '{"jsonrpc":"2.0","id":0,"method":"bi18n.health.check","params":{"ctx_id":"ping"}}'
# Esperado: respuesta JSON

# Variable global
CTX="ws-test-$(date +%s)"
WSCAT="websocat ws://127.0.0.1:9454"

# Helper para enviar un request y leer la primera línea de respuesta
ws_call() {
  echo "$1" | websocat ws://127.0.0.1:9454
}
```

---

## §1 Formato base del protocolo JSON-RPC 2.0

Todo request debe tener:
```json
{
  "jsonrpc": "2.0",
  "id": <número>,
  "method": "<namespace>.<método>",
  "params": { "ctx_id": "<string-no-vacío>", ... }
}
```
Toda respuesta exitosa devuelve:
```json
{ "jsonrpc": "2.0", "id": <mismo-id>, "result": { ... } }
```
Todo error devuelve:
```json
{ "jsonrpc": "2.0", "id": <mismo-id>, "error": { "code": <int>, "message": "<string>" } }
```

---

## §2 Estado y salud

### TC-WS-001 — Health check
```bash
ws_call '{"jsonrpc":"2.0","id":1,"method":"bi18n.health.check","params":{"ctx_id":"'$CTX'"}}'
```
**Esperado (PASS):** `result.status` = "ok", `result.version` presente.

---

## §3 Locale

### TC-WS-010 — Resolver locale
```bash
ws_call '{"jsonrpc":"2.0","id":10,"method":"bi18n.locale.resolve","params":{"ctx_id":"'$CTX'","tenant_id":"default"}}'
```
**Esperado (PASS):** `result.locale`, `result.timezone`, `result.currency`, `result.country` presentes.

### TC-WS-011 — Snapshot regional
```bash
ws_call '{"jsonrpc":"2.0","id":11,"method":"bi18n.regional.snapshot","params":{"ctx_id":"'$CTX'","tenant_id":"default"}}'
```
**Esperado (PASS):** `result` contiene payload JSON con configuración regional completa.

---

## §4 Traducciones Fluent (A.08.01)

### TC-WS-020 — has_message
```bash
ws_call '{"jsonrpc":"2.0","id":20,"method":"bi18n.translate.has_message","params":{"ctx_id":"'$CTX'","id":"bienvenida","locale":"es-BO"}}'
```
**Esperado (PASS):** `result.existe` = true o false (campo presente).

### TC-WS-021 — message simple
```bash
ws_call '{"jsonrpc":"2.0","id":21,"method":"bi18n.translate.message","params":{"ctx_id":"'$CTX'","id":"bienvenida","locale":"es-BO"}}'
```
**Esperado (PASS):** `result.text` string no vacío.

### TC-WS-022 — message_with_args
```bash
ws_call '{"jsonrpc":"2.0","id":22,"method":"bi18n.translate.message_with_args","params":{"ctx_id":"'$CTX'","id":"saludo-usuario","locale":"es-BO","args":{"nombre":"María"}}}'
```
**Esperado (PASS):** `result.text` contiene "María" interpolada.

### TC-WS-023 — batch
```bash
ws_call '{"jsonrpc":"2.0","id":23,"method":"bi18n.translate.batch","params":{"ctx_id":"'$CTX'","ids":["bienvenida","titulo-app"],"locale":"es-BO"}}'
```
**Esperado (PASS):** `result` array con un item por id.

### TC-WS-024 — list_messages
```bash
ws_call '{"jsonrpc":"2.0","id":24,"method":"bi18n.translate.list_messages","params":{"ctx_id":"'$CTX'","locale":"es-BO","namespace":"ui"}}'
```
**Esperado (PASS):** `result.messages` objeto (id→texto), `result.count` > 0.

### TC-WS-025 — message_attribute
```bash
ws_call '{"jsonrpc":"2.0","id":25,"method":"bi18n.translate.message_attribute","params":{"ctx_id":"'$CTX'","id":"boton-guardar","attribute":"tooltip","locale":"es-BO"}}'
```
**Esperado (PASS):** `result.text` del atributo no vacío.

### TC-WS-026 — bundle (Bundle Prefetch — A.09 §12)
```bash
ws_call '{"jsonrpc":"2.0","id":26,"method":"bi18n.translate.bundle","params":{"ctx_id":"'$CTX'","locale":"es-BO","namespace":"ui"}}'
```
**Esperado (PASS):** `result.bundle` objeto con todos los mensajes del namespace, `result.count` > 0.

### TC-WS-027 — alias "attribute" (backward-compat)
```bash
ws_call '{"jsonrpc":"2.0","id":27,"method":"bi18n.translate.attribute","params":{"ctx_id":"'$CTX'","id":"boton-guardar","attribute":"tooltip","locale":"es-BO"}}'
```
**Esperado (PASS):** mismo resultado que TC-WS-025.

---

## §5 rust-i18n (A.08.02)

### TC-WS-030 — locale_activo
```bash
ws_call '{"jsonrpc":"2.0","id":30,"method":"bi18n.i18n.locale_activo","params":{"ctx_id":"'$CTX'"}}'
```
**Esperado (PASS):** `result.locale` BCP47 no vacío.

### TC-WS-031 — set_locale
```bash
ws_call '{"jsonrpc":"2.0","id":31,"method":"bi18n.i18n.set_locale","params":{"ctx_id":"'$CTX'","locale":"es-BO"}}'
```
**Esperado (PASS):** `result.ok` = true.

### TC-WS-032 — locales_disponibles (nombre canónico)
```bash
ws_call '{"jsonrpc":"2.0","id":32,"method":"bi18n.i18n.locales_disponibles","params":{"ctx_id":"'$CTX'"}}'
```
**Esperado (PASS):** `result.locales` array con al menos 1 elemento.

### TC-WS-033 — available_locales (alias backward-compat)
```bash
ws_call '{"jsonrpc":"2.0","id":33,"method":"bi18n.i18n.available_locales","params":{"ctx_id":"'$CTX'"}}'
```
**Esperado (PASS):** mismo resultado que TC-WS-032.

### TC-WS-034 — t (nombre canónico)
```bash
ws_call '{"jsonrpc":"2.0","id":34,"method":"bi18n.i18n.t","params":{"ctx_id":"'$CTX'","key":"app.title","locale":"es-BO"}}'
```
**Esperado (PASS):** `result.text` no vacío.

### TC-WS-035 — translate (alias backward-compat)
```bash
ws_call '{"jsonrpc":"2.0","id":35,"method":"bi18n.i18n.translate","params":{"ctx_id":"'$CTX'","key":"app.title","locale":"es-BO"}}'
```
**Esperado (PASS):** mismo resultado que TC-WS-034.

---

## §6 ICU locale BCP-47 (A.08.04)

### TC-WS-040 — parse_bcp47
```bash
ws_call '{"jsonrpc":"2.0","id":40,"method":"bi18n.locale.parse_bcp47","params":{"ctx_id":"'$CTX'","locale":"es-419"}}'
```
**Esperado (PASS):** `result.language` = "es", `result.region` = "419".

### TC-WS-041 — canonicalize
```bash
ws_call '{"jsonrpc":"2.0","id":41,"method":"bi18n.locale.canonicalize","params":{"ctx_id":"'$CTX'","locale":"es_BO"}}'
```
**Esperado (PASS):** `result.canonical` = "es-BO".

### TC-WS-042 — negotiate
```bash
ws_call '{"jsonrpc":"2.0","id":42,"method":"bi18n.locale.negotiate","params":{"ctx_id":"'$CTX'","requested":["es-AR","es","en"],"available":["es-BO","en-US"]}}'
```
**Esperado (PASS):** `result.negotiated` = "es-BO".

### TC-WS-043 — subtags
```bash
ws_call '{"jsonrpc":"2.0","id":43,"method":"bi18n.locale.subtags","params":{"ctx_id":"'$CTX'","locale":"es-BO-u-ca-gregory"}}'
```
**Esperado (PASS):** `result.language` = "es", `result.region` = "BO".

---

## §7 ICU datetime (A.08.03)

### TC-WS-050 — datetime_icu
```bash
ws_call '{"jsonrpc":"2.0","id":50,"method":"bi18n.format.datetime_icu","params":{"ctx_id":"'$CTX'","iso":"2026-07-18T14:30:00Z","locale":"es-BO","date_style":"full","time_style":"short"}}'
```
**Esperado (PASS):** `result.display` contiene fecha en español.

### TC-WS-051 — date_icu
```bash
ws_call '{"jsonrpc":"2.0","id":51,"method":"bi18n.format.date_icu","params":{"ctx_id":"'$CTX'","iso":"2026-07-18T00:00:00Z","locale":"es-BO","style":"long"}}'
```
**Esperado (PASS):** `result.display` = "18 de julio de 2026".

### TC-WS-052 — time_icu
```bash
ws_call '{"jsonrpc":"2.0","id":52,"method":"bi18n.format.time_icu","params":{"ctx_id":"'$CTX'","iso":"2026-07-18T14:30:00Z","locale":"es-BO","style":"short"}}'
```
**Esperado (PASS):** `result.display` contiene "14:30".

### TC-WS-053 — weekday_name
```bash
ws_call '{"jsonrpc":"2.0","id":53,"method":"bi18n.format.weekday_name","params":{"ctx_id":"'$CTX'","iso":"2026-07-18T00:00:00Z","locale":"es-BO","width":"wide"}}'
```
**Esperado (PASS):** `result.display` = "sábado".

### TC-WS-054 — month_name
```bash
ws_call '{"jsonrpc":"2.0","id":54,"method":"bi18n.format.month_name","params":{"ctx_id":"'$CTX'","iso":"2026-07-18T00:00:00Z","locale":"es-BO","width":"wide"}}'
```
**Esperado (PASS):** `result.display` = "julio".

### TC-WS-055 — datetime_with_time
```bash
ws_call '{"jsonrpc":"2.0","id":55,"method":"bi18n.format.datetime_with_time","params":{"ctx_id":"'$CTX'","iso":"2026-07-18T14:30:00Z","locale":"es-BO","timezone":"America/La_Paz"}}'
```
**Esperado (PASS):** `result.display` con hora ajustada a UTC-4.

---

## §8 ICU decimal (A.08.05)

### TC-WS-060 — number_icu
```bash
ws_call '{"jsonrpc":"2.0","id":60,"method":"bi18n.format.number_icu","params":{"ctx_id":"'$CTX'","value":"1234567.89","locale":"es-BO"}}'
```
**Esperado (PASS):** `result.display` con separadores de miles.

### TC-WS-061 — number_no_grouping
```bash
ws_call '{"jsonrpc":"2.0","id":61,"method":"bi18n.format.number_no_grouping","params":{"ctx_id":"'$CTX'","value":"1234567","locale":"es-BO"}}'
```
**Esperado (PASS):** `result.display` = "1234567" sin separadores.

### TC-WS-062 — number_grouping_always
```bash
ws_call '{"jsonrpc":"2.0","id":62,"method":"bi18n.format.number_grouping_always","params":{"ctx_id":"'$CTX'","value":"1234","locale":"es-BO"}}'
```
**Esperado (PASS):** `result.display` con separador aunque sea < 10000.

### TC-WS-063 — number_grouping_min2
```bash
ws_call '{"jsonrpc":"2.0","id":63,"method":"bi18n.format.number_grouping_min2","params":{"ctx_id":"'$CTX'","value":"9999","locale":"es-BO"}}'
```
**Esperado (PASS):** `result.display` = "9999" sin separador (< 10000, min2).

---

## §9 Validación (A.08.06 — validator)

### TC-WS-070 — email_html5
```bash
ws_call '{"jsonrpc":"2.0","id":70,"method":"bi18n.validate.email_html5","params":{"ctx_id":"'$CTX'","value":"test@example.com"}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-071 — url
```bash
ws_call '{"jsonrpc":"2.0","id":71,"method":"bi18n.validate.url","params":{"ctx_id":"'$CTX'","value":"https://sbos.local"}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-072 — ip
```bash
ws_call '{"jsonrpc":"2.0","id":72,"method":"bi18n.validate.ip","params":{"ctx_id":"'$CTX'","value":"192.168.1.1"}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-073 — ipv4
```bash
ws_call '{"jsonrpc":"2.0","id":73,"method":"bi18n.validate.ipv4","params":{"ctx_id":"'$CTX'","value":"10.0.0.1"}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-074 — ipv6
```bash
ws_call '{"jsonrpc":"2.0","id":74,"method":"bi18n.validate.ipv6","params":{"ctx_id":"'$CTX'","value":"::1"}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-075 — length
```bash
ws_call '{"jsonrpc":"2.0","id":75,"method":"bi18n.validate.length","params":{"ctx_id":"'$CTX'","value":"hola","min":2,"max":10}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-076 — range
```bash
ws_call '{"jsonrpc":"2.0","id":76,"method":"bi18n.validate.range","params":{"ctx_id":"'$CTX'","value":5.0,"min":1.0,"max":10.0}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-077 — contains
```bash
ws_call '{"jsonrpc":"2.0","id":77,"method":"bi18n.validate.contains","params":{"ctx_id":"'$CTX'","value":"hola mundo","needle":"mundo"}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-078 — not_contains
```bash
ws_call '{"jsonrpc":"2.0","id":78,"method":"bi18n.validate.not_contains","params":{"ctx_id":"'$CTX'","value":"hola mundo","needle":"adios"}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-079 — required
```bash
ws_call '{"jsonrpc":"2.0","id":79,"method":"bi18n.validate.required","params":{"ctx_id":"'$CTX'","value":"algo"}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-080 — credit_card
```bash
ws_call '{"jsonrpc":"2.0","id":80,"method":"bi18n.validate.credit_card","params":{"ctx_id":"'$CTX'","value":"4111111111111111"}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-081 — must_match
```bash
ws_call '{"jsonrpc":"2.0","id":81,"method":"bi18n.validate.must_match","params":{"ctx_id":"'$CTX'","a":"abc123","b":"abc123"}}'
```
**Esperado (PASS):** `result.valid` = true.

---

## §10 Formatos especiales (A.08.07 — scrutiny)

### TC-WS-090 — uuid
```bash
ws_call '{"jsonrpc":"2.0","id":90,"method":"bi18n.validate.uuid","params":{"ctx_id":"'$CTX'","value":"550e8400-e29b-41d4-a716-446655440000"}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-091 — ulid
```bash
ws_call '{"jsonrpc":"2.0","id":91,"method":"bi18n.validate.ulid","params":{"ctx_id":"'$CTX'","value":"01ARZ3NDEKTSV4RRFFQ69G5FAV"}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-092 — mac_address
```bash
ws_call '{"jsonrpc":"2.0","id":92,"method":"bi18n.validate.mac_address","params":{"ctx_id":"'$CTX'","value":"00:1A:2B:3C:4D:5E"}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-093 — hex_color
```bash
ws_call '{"jsonrpc":"2.0","id":93,"method":"bi18n.validate.hex_color","params":{"ctx_id":"'$CTX'","value":"#FF5733"}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-094 — timezone
```bash
ws_call '{"jsonrpc":"2.0","id":94,"method":"bi18n.validate.timezone","params":{"ctx_id":"'$CTX'","value":"America/La_Paz"}}'
```
**Esperado (PASS):** `result.valid` = true.

### TC-WS-095 — is_json
```bash
ws_call '{"jsonrpc":"2.0","id":95,"method":"bi18n.validate.is_json","params":{"ctx_id":"'$CTX'","value":"{\"clave\":\"valor\"}"}}'
```
**Esperado (PASS):** `result.valid` = true.

---

## §11 Máscaras PII en texto (A.08.08)

### TC-WS-100 — mask.email_in_text
```bash
ws_call '{"jsonrpc":"2.0","id":100,"method":"bi18n.mask.email_in_text","params":{"ctx_id":"'$CTX'","text":"Correo: user@test.com aquí."}}'
```
**Esperado (PASS):** `result.masked` con email reemplazado.

### TC-WS-101 — mask.phone_in_text
```bash
ws_call '{"jsonrpc":"2.0","id":101,"method":"bi18n.mask.phone_in_text","params":{"ctx_id":"'$CTX'","text":"Llame al +59171234567 ahora."}}'
```
**Esperado (PASS):** `result.masked` con teléfono reemplazado.

### TC-WS-102 — mask.pii (básico)
```bash
ws_call '{"jsonrpc":"2.0","id":102,"method":"bi18n.mask.pii","params":{"ctx_id":"'$CTX'","text":"Email: a@b.com Tel: +59171234567"}}'
```
**Esperado (PASS):** `result.redacted` con ambos datos enmascarados.

### TC-WS-103 — mask.pii_with_char
```bash
ws_call '{"jsonrpc":"2.0","id":103,"method":"bi18n.mask.pii_with_char","params":{"ctx_id":"'$CTX'","text":"Email: user@test.com","char":"X"}}'
```
**Esperado (PASS):** `result.masked` con "X" sustituyendo el email.

---

## §12 Máscaras estructurales (A.08.09)

### TC-WS-110 — format.structural_mask
```bash
ws_call '{"jsonrpc":"2.0","id":110,"method":"bi18n.format.structural_mask","params":{"ctx_id":"'$CTX'","text":"71234567","pattern":"XXXX-XXXX"}}'
```
**Esperado (PASS):** `result.masked` = "7123-4567".

### TC-WS-111 — format.mask_cnpj
```bash
ws_call '{"jsonrpc":"2.0","id":111,"method":"bi18n.format.mask_cnpj","params":{"ctx_id":"'$CTX'","text":"11222333000181"}}'
```
**Esperado (PASS):** `result.masked` = "11.222.333/0001-81".

### TC-WS-112 — format.mask_cpf
```bash
ws_call '{"jsonrpc":"2.0","id":112,"method":"bi18n.format.mask_cpf","params":{"ctx_id":"'$CTX'","text":"11144477735"}}'
```
**Esperado (PASS):** `result.masked` = "111.444.777-35".

### TC-WS-113 — format.mask_card
```bash
ws_call '{"jsonrpc":"2.0","id":113,"method":"bi18n.format.mask_card","params":{"ctx_id":"'$CTX'","text":"4111111111111111"}}'
```
**Esperado (PASS):** `result.masked` muestra solo últimos 4 dígitos.

### TC-WS-114 — format.mask_ci_bo
```bash
ws_call '{"jsonrpc":"2.0","id":114,"method":"bi18n.format.mask_ci_bo","params":{"ctx_id":"'$CTX'","text":"7654321LP"}}'
```
**Esperado (PASS):** `result.masked` = "7654321-LP".

---

## §13 jiff — fecha/hora (A.08.10)

### TC-WS-120 — datetime.now_utc
```bash
ws_call '{"jsonrpc":"2.0","id":120,"method":"bi18n.datetime.now_utc","params":{"ctx_id":"'$CTX'"}}'
```
**Esperado (PASS):** `result.datetime` en ISO 8601 con sufijo "Z".

### TC-WS-121 — datetime.now_tz
```bash
ws_call '{"jsonrpc":"2.0","id":121,"method":"bi18n.datetime.now_tz","params":{"ctx_id":"'$CTX'","timezone":"America/La_Paz"}}'
```
**Esperado (PASS):** `result.datetime` con offset -04:00.

### TC-WS-122 — datetime.parse_jiff
```bash
ws_call '{"jsonrpc":"2.0","id":122,"method":"bi18n.datetime.parse_jiff","params":{"ctx_id":"'$CTX'","datetime":"2026-07-18T14:30:00Z","timezone":"UTC"}}'
```
**Esperado (PASS):** `result.year` = 2026, `result.month` = 7.

### TC-WS-123 — datetime.from_unix
```bash
ws_call '{"jsonrpc":"2.0","id":123,"method":"bi18n.datetime.from_unix","params":{"ctx_id":"'$CTX'","unix":1753000000,"timezone":"UTC"}}'
```
**Esperado (PASS):** `result` con `year`, `month`, `day` correspondientes al timestamp.

### TC-WS-124 — datetime.format_jiff
```bash
ws_call '{"jsonrpc":"2.0","id":124,"method":"bi18n.datetime.format_jiff","params":{"ctx_id":"'$CTX'","datetime":"2026-07-18T14:30:00Z","format":"%Y-%m-%d","timezone":"UTC"}}'
```
**Esperado (PASS):** `result.formatted` = "2026-07-18".

### TC-WS-125 — datetime.series
```bash
ws_call '{"jsonrpc":"2.0","id":125,"method":"bi18n.datetime.series","params":{"ctx_id":"'$CTX'","start":"2026-07-01T00:00:00Z","end":"2026-07-05T00:00:00Z","unit":"day","step":1,"timezone":"UTC"}}'
```
**Esperado (PASS):** `result.series` array con 5 elementos.

### TC-WS-126 — datetime.add_span
```bash
ws_call '{"jsonrpc":"2.0","id":126,"method":"bi18n.datetime.add_span","params":{"ctx_id":"'$CTX'","datetime":"2026-07-18T00:00:00Z","timezone":"UTC","days":7}}'
```
**Esperado (PASS):** `result.result` = "2026-07-25T00:00:00Z".

### TC-WS-127 — datetime.sub_span
```bash
ws_call '{"jsonrpc":"2.0","id":127,"method":"bi18n.datetime.sub_span","params":{"ctx_id":"'$CTX'","datetime":"2026-07-18T00:00:00Z","timezone":"UTC","days":7}}'
```
**Esperado (PASS):** `result.result` = "2026-07-11T00:00:00Z".

### TC-WS-128 — datetime.diff_span
```bash
ws_call '{"jsonrpc":"2.0","id":128,"method":"bi18n.datetime.diff_span","params":{"ctx_id":"'$CTX'","start":"2026-07-01T00:00:00Z","end":"2026-07-18T00:00:00Z","unit":"day","timezone":"UTC"}}'
```
**Esperado (PASS):** `result.diff` = 17.

### TC-WS-129 — datetime.convert_tz
```bash
ws_call '{"jsonrpc":"2.0","id":129,"method":"bi18n.datetime.convert_tz","params":{"ctx_id":"'$CTX'","datetime":"2026-07-18T18:00:00Z","from":"UTC","to":"America/La_Paz"}}'
```
**Esperado (PASS):** `result.result` con hora 14:00 (UTC-4).

### TC-WS-130 — datetime.round
```bash
ws_call '{"jsonrpc":"2.0","id":130,"method":"bi18n.datetime.round","params":{"ctx_id":"'$CTX'","datetime":"2026-07-18T14:30:00Z","timezone":"UTC","unit":"day","mode":"floor"}}'
```
**Esperado (PASS):** `result.result` = "2026-07-18T00:00:00Z".

### TC-WS-131 — datetime.weekday_of_date
```bash
ws_call '{"jsonrpc":"2.0","id":131,"method":"bi18n.datetime.weekday_of_date","params":{"ctx_id":"'$CTX'","datetime":"2026-07-18T00:00:00Z","timezone":"UTC"}}'
```
**Esperado (PASS):** `result.weekday` = "Saturday" o 6.

### TC-WS-132 — datetime.days_in_month
```bash
ws_call '{"jsonrpc":"2.0","id":132,"method":"bi18n.datetime.days_in_month","params":{"ctx_id":"'$CTX'","datetime":"2026-07-01T00:00:00Z","timezone":"UTC"}}'
```
**Esperado (PASS):** `result.days` = 31.

### TC-WS-133 — datetime.is_leap_year
```bash
ws_call '{"jsonrpc":"2.0","id":133,"method":"bi18n.datetime.is_leap_year","params":{"ctx_id":"'$CTX'","datetime":"2024-01-01T00:00:00Z","timezone":"UTC"}}'
```
**Esperado (PASS):** `result.leap` = true.

### TC-WS-134 — datetime.nth_weekday
```bash
ws_call '{"jsonrpc":"2.0","id":134,"method":"bi18n.datetime.nth_weekday","params":{"ctx_id":"'$CTX'","year":2026,"month":7,"weekday":1,"nth":1}}'
```
**Esperado (PASS):** `result.date` = primer lunes de julio 2026.

### TC-WS-135 — datetime.span_total
```bash
ws_call '{"jsonrpc":"2.0","id":135,"method":"bi18n.datetime.span_total","params":{"ctx_id":"'$CTX'","days":1,"hours":2,"minutes":30,"unit":"minutes"}}'
```
**Esperado (PASS):** `result.total` = 1590.

### TC-WS-136 — datetime.tz_info
```bash
ws_call '{"jsonrpc":"2.0","id":136,"method":"bi18n.datetime.tz_info","params":{"ctx_id":"'$CTX'","timezone":"America/La_Paz"}}'
```
**Esperado (PASS):** `result.offset` = "-04:00".

---

## §14 chrono (A.08.11)

### TC-WS-140 — chrono_parse_rfc3339
```bash
ws_call '{"jsonrpc":"2.0","id":140,"method":"bi18n.datetime.chrono_parse_rfc3339","params":{"ctx_id":"'$CTX'","value":"2026-07-18T14:30:00+00:00"}}'
```
**Esperado (PASS):** `result.year` = 2026.

### TC-WS-141 — chrono_parse_rfc2822
```bash
ws_call '{"jsonrpc":"2.0","id":141,"method":"bi18n.datetime.chrono_parse_rfc2822","params":{"ctx_id":"'$CTX'","value":"Sat, 18 Jul 2026 14:30:00 +0000"}}'
```
**Esperado (PASS):** `result.year` = 2026.

### TC-WS-142 — chrono_to_rfc3339
```bash
ws_call '{"jsonrpc":"2.0","id":142,"method":"bi18n.datetime.chrono_to_rfc3339","params":{"ctx_id":"'$CTX'","unix":1753000000}}'
```
**Esperado (PASS):** `result.rfc3339` en formato RFC3339.

### TC-WS-143 — chrono_to_rfc2822
```bash
ws_call '{"jsonrpc":"2.0","id":143,"method":"bi18n.datetime.chrono_to_rfc2822","params":{"ctx_id":"'$CTX'","unix":1753000000}}'
```
**Esperado (PASS):** `result.rfc2822` en formato RFC 2822.

### TC-WS-144 — chrono_format
```bash
ws_call '{"jsonrpc":"2.0","id":144,"method":"bi18n.datetime.chrono_format","params":{"ctx_id":"'$CTX'","unix":1753000000,"format":"%Y-%m-%d"}}'
```
**Esperado (PASS):** `result.formatted` en formato YYYY-MM-DD.

### TC-WS-145 — chrono_format_localized
```bash
ws_call '{"jsonrpc":"2.0","id":145,"method":"bi18n.datetime.chrono_format_localized","params":{"ctx_id":"'$CTX'","unix":1753000000,"format":"%d %B %Y","locale":"es-BO"}}'
```
**Esperado (PASS):** `result.formatted` con mes en español.

### TC-WS-146 — chrono_to_unix
```bash
ws_call '{"jsonrpc":"2.0","id":146,"method":"bi18n.datetime.chrono_to_unix","params":{"ctx_id":"'$CTX'","value":"2026-07-18T00:00:00+00:00"}}'
```
**Esperado (PASS):** `result.unix` entero positivo.

### TC-WS-147 — chrono_leap_year
```bash
ws_call '{"jsonrpc":"2.0","id":147,"method":"bi18n.datetime.chrono_leap_year","params":{"ctx_id":"'$CTX'","year":2024,"month":2,"day":29}}'
```
**Esperado (PASS):** `result.leap` = true.

### TC-WS-148 — chrono_naive_parse
```bash
ws_call '{"jsonrpc":"2.0","id":148,"method":"bi18n.datetime.chrono_naive_parse","params":{"ctx_id":"'$CTX'","value":"2026-07-18","format":"%Y-%m-%d"}}'
```
**Esperado (PASS):** `result.year` = 2026, `result.month` = 7.

### TC-WS-149 — chrono_timedelta_total
```bash
ws_call '{"jsonrpc":"2.0","id":149,"method":"bi18n.datetime.chrono_timedelta_total","params":{"ctx_id":"'$CTX'","days":1,"hours":2,"minutes":30,"seconds":0,"unit":"seconds"}}'
```
**Esperado (PASS):** `result.total` = 95400.

---

## §15 Regex y texto (A.08.12)

### TC-WS-150 — text.regex_match
```bash
ws_call '{"jsonrpc":"2.0","id":150,"method":"bi18n.text.regex_match","params":{"ctx_id":"'$CTX'","text":"CI-7654321","pattern":"^CI-[0-9]+"}}'
```
**Esperado (PASS):** `result.matched` = true.

### TC-WS-151 — text.regex_extract
```bash
ws_call '{"jsonrpc":"2.0","id":151,"method":"bi18n.text.regex_extract","params":{"ctx_id":"'$CTX'","text":"Tel: +59171234567","pattern":"\\+\\d+"}}'
```
**Esperado (PASS):** `result.match` = "+59171234567".

### TC-WS-152 — text.regex_extract_all
```bash
ws_call '{"jsonrpc":"2.0","id":152,"method":"bi18n.text.regex_extract_all","params":{"ctx_id":"'$CTX'","text":"a1 b2 c3","pattern":"[a-z][0-9]"}}'
```
**Esperado (PASS):** `result.matches` = ["a1","b2","c3"].

### TC-WS-153 — text.regex_replace
```bash
ws_call '{"jsonrpc":"2.0","id":153,"method":"bi18n.text.regex_replace","params":{"ctx_id":"'$CTX'","text":"hello world","pattern":"world","replacement":"SBOS"}}'
```
**Esperado (PASS):** `result.result` = "hello SBOS".

### TC-WS-154 — text.regex_split
```bash
ws_call '{"jsonrpc":"2.0","id":154,"method":"bi18n.text.regex_split","params":{"ctx_id":"'$CTX'","text":"uno,dos;tres","pattern":"[,;]"}}'
```
**Esperado (PASS):** `result.parts` = ["uno","dos","tres"].

### TC-WS-155 — text.regex_match_set
```bash
ws_call '{"jsonrpc":"2.0","id":155,"method":"bi18n.text.regex_match_set","params":{"ctx_id":"'$CTX'","text":"usuario@empresa.com","patterns":["^[a-z]+@","\\.com$"]}}'
```
**Esperado (PASS):** `result.all_matched` = true.

---

## §16 Teléfonos (A.08.13)

### TC-WS-160 — phone.parse_e164
```bash
ws_call '{"jsonrpc":"2.0","id":160,"method":"bi18n.phone.parse_e164","params":{"ctx_id":"'$CTX'","number":"+59171234567"}}'
```
**Esperado (PASS):** `result.country_code` = 591.

### TC-WS-161 — phone.format
```bash
ws_call '{"jsonrpc":"2.0","id":161,"method":"bi18n.phone.format","params":{"ctx_id":"'$CTX'","number":"+59171234567","format":"national"}}'
```
**Esperado (PASS):** `result.formatted` en formato nacional.

### TC-WS-162 — phone.type
```bash
ws_call '{"jsonrpc":"2.0","id":162,"method":"bi18n.phone.type","params":{"ctx_id":"'$CTX'","number":"+59171234567"}}'
```
**Esperado (PASS):** `result.type` = "MOBILE" o "FIXED_LINE".

### TC-WS-163 — phone.is_viable
```bash
ws_call '{"jsonrpc":"2.0","id":163,"method":"bi18n.phone.is_viable","params":{"ctx_id":"'$CTX'","number":"+59171234567"}}'
```
**Esperado (PASS):** `result.viable` = true.

### TC-WS-164 — phone.info
```bash
ws_call '{"jsonrpc":"2.0","id":164,"method":"bi18n.phone.info","params":{"ctx_id":"'$CTX'","number":"+59171234567"}}'
```
**Esperado (PASS):** `result.country` = "BO", `result.e164` presente.

### TC-WS-165 — phone.parse_national
```bash
ws_call '{"jsonrpc":"2.0","id":165,"method":"bi18n.phone.parse_national","params":{"ctx_id":"'$CTX'","number":"71234567","country":"BO"}}'
```
**Esperado (PASS):** `result.e164` = "+59171234567".

### TC-WS-166 — phone.parse_rfc3966
```bash
ws_call '{"jsonrpc":"2.0","id":166,"method":"bi18n.phone.parse_rfc3966","params":{"ctx_id":"'$CTX'","number":"tel:+59171234567"}}'
```
**Esperado (PASS):** `result.e164` = "+59171234567".

### TC-WS-167 — phone.country_code
```bash
ws_call '{"jsonrpc":"2.0","id":167,"method":"bi18n.phone.country_code","params":{"ctx_id":"'$CTX'","number":"+59171234567"}}'
```
**Esperado (PASS):** `result.country_code` = 591.

---

## §17 Guardas (A.08.14)

### TC-WS-170 — guard.check_bounds
```bash
ws_call '{"jsonrpc":"2.0","id":170,"method":"bi18n.guard.check_bounds","params":{"ctx_id":"'$CTX'","offset":5,"length":3,"total_length":10}}'
```
**Esperado (PASS):** `result.ok` = true.

### TC-WS-171 — guard.check_element_index
```bash
ws_call '{"jsonrpc":"2.0","id":171,"method":"bi18n.guard.check_element_index","params":{"ctx_id":"'$CTX'","index":4,"size":5}}'
```
**Esperado (PASS):** `result.ok` = true.

### TC-WS-172 — guard.check_position_index
```bash
ws_call '{"jsonrpc":"2.0","id":172,"method":"bi18n.guard.check_position_index","params":{"ctx_id":"'$CTX'","index":5,"size":5}}'
```
**Esperado (PASS):** `result.ok` = true.

### TC-WS-173 — guard.num_compare
```bash
ws_call '{"jsonrpc":"2.0","id":173,"method":"bi18n.guard.num_compare","params":{"ctx_id":"'$CTX'","name1":"inicio","name2":"fin","v1":5.0}}'
```
**Esperado (PASS):** `result.ok` con resultado de comparación.

### TC-WS-174 — guard.num_positive
```bash
ws_call '{"jsonrpc":"2.0","id":174,"method":"bi18n.guard.num_positive","params":{"ctx_id":"'$CTX'","name":"precio","value":9.99}}'
```
**Esperado (PASS):** `result.ok` = true.

### TC-WS-175 — guard.num_non_negative
```bash
ws_call '{"jsonrpc":"2.0","id":175,"method":"bi18n.guard.num_non_negative","params":{"ctx_id":"'$CTX'","name":"cantidad","value":0.0}}'
```
**Esperado (PASS):** `result.ok` = true.

### TC-WS-176 — guard.num_in_range
```bash
ws_call '{"jsonrpc":"2.0","id":176,"method":"bi18n.guard.num_in_range","params":{"ctx_id":"'$CTX'","name":"nota","value":85.0,"min":0.0,"max":100.0}}'
```
**Esperado (PASS):** `result.ok` = true.

### TC-WS-177 — guard.str_non_blank
```bash
ws_call '{"jsonrpc":"2.0","id":177,"method":"bi18n.guard.str_non_blank","params":{"ctx_id":"'$CTX'","name":"nombre","value":"Juan"}}'
```
**Esperado (PASS):** `result.ok` = true.

### TC-WS-178 — guard.str_length_range
```bash
ws_call '{"jsonrpc":"2.0","id":178,"method":"bi18n.guard.str_length_range","params":{"ctx_id":"'$CTX'","name":"clave","value":"abc123","min":6,"max":20}}'
```
**Esperado (PASS):** `result.ok` = true.

### TC-WS-179 — guard.str_match
```bash
ws_call '{"jsonrpc":"2.0","id":179,"method":"bi18n.guard.str_match","params":{"ctx_id":"'$CTX'","name":"codigo","value":"ABC-001","pattern":"^[A-Z]+-\\d{3}$"}}'
```
**Esperado (PASS):** `result.ok` = true.

### TC-WS-180 — guard.col_non_empty
```bash
ws_call '{"jsonrpc":"2.0","id":180,"method":"bi18n.guard.col_non_empty","params":{"ctx_id":"'$CTX'","name":"roles","value":["admin","usuario"]}}'
```
**Esperado (PASS):** `result.ok` = true.

### TC-WS-181 — guard.col_length_range
```bash
ws_call '{"jsonrpc":"2.0","id":181,"method":"bi18n.guard.col_length_range","params":{"ctx_id":"'$CTX'","name":"permisos","value":["read","write"],"min":1,"max":5}}'
```
**Esperado (PASS):** `result.ok` = true.

---

## §18 Administración de traducciones

### TC-WS-190 — admin.list_locales
```bash
ws_call '{"jsonrpc":"2.0","id":190,"method":"bi18n.admin.list_locales","params":{"ctx_id":"'$CTX'"}}'
```
**Esperado (PASS):** `result.locales` array.

### TC-WS-191 — admin.list_messages
```bash
ws_call '{"jsonrpc":"2.0","id":191,"method":"bi18n.admin.list_messages","params":{"ctx_id":"'$CTX'","locale":"es-BO"}}'
```
**Esperado (PASS):** `result.messages` array de ids de mensajes FTL.

### TC-WS-192 — admin.get_message
```bash
ws_call '{"jsonrpc":"2.0","id":192,"method":"bi18n.admin.get_message","params":{"ctx_id":"'$CTX'","locale":"es-BO","id":"bienvenida"}}'
```
**Esperado (PASS):** `result.content` string con el valor FTL.

### TC-WS-193 — admin.reload
```bash
ws_call '{"jsonrpc":"2.0","id":193,"method":"bi18n.admin.reload","params":{"ctx_id":"'$CTX'"}}'
```
**Esperado (PASS):** `result.recargado` = true.

### TC-WS-194 — admin.reload_translations
```bash
ws_call '{"jsonrpc":"2.0","id":194,"method":"bi18n.admin.reload_translations","params":{"ctx_id":"'$CTX'"}}'
```
**Esperado (PASS):** `result.recargado` = true, `result.mensaje` contiene "sin interrupción".

---

## §19 Push events — suscripción a traducciones actualizadas (A.09 §10)

### TC-WS-P01 — Recibir evento translations.updated tras reload

```bash
# Terminal A: suscribir y esperar evento push
(websocat ws://127.0.0.1:9454 &)
# mantener conexión abierta

# Terminal B: forzar recarga que dispara el evento
ws_call '{"jsonrpc":"2.0","id":200,"method":"bi18n.admin.reload","params":{"ctx_id":"'$CTX'"}}'
```

**Esperado (PASS):** La Terminal A recibe un mensaje WebSocket con este formato:
```json
{"event":"translations.updated","namespace":"*","locale":"all"}
```

### TC-WS-P02 — Múltiples clientes reciben el evento (broadcast)

```bash
# Abrir dos conexiones simultáneas y disparar reload
websocat ws://127.0.0.1:9454 &
websocat ws://127.0.0.1:9454 &
sleep 0.2
ws_call '{"jsonrpc":"2.0","id":201,"method":"bi18n.admin.reload_translations","params":{"ctx_id":"'$CTX'"}}'
```

**Esperado (PASS):** Ambas conexiones reciben el evento `translations.updated`.

---

## §20 Casos de error de protocolo

### TC-WS-E01 — ctx_id ausente
```bash
ws_call '{"jsonrpc":"2.0","id":900,"method":"bi18n.health.check","params":{}}'
```
**Esperado (PASS):** `error.code` = -32602, mensaje menciona "ctx_id".

### TC-WS-E02 — Método inexistente
```bash
ws_call '{"jsonrpc":"2.0","id":901,"method":"bi18n.no_existe.metodo","params":{"ctx_id":"'$CTX'"}}'
```
**Esperado (PASS):** `error` con mensaje "método no encontrado".

### TC-WS-E03 — Parámetro requerido ausente
```bash
ws_call '{"jsonrpc":"2.0","id":902,"method":"bi18n.translate.message","params":{"ctx_id":"'$CTX'"}}'
```
**Esperado (PASS):** `error` con mensaje de parámetro faltante, o `result.text` vacío/fallback.

### TC-WS-E04 — JSON malformado
```bash
echo '{"jsonrpc":"2.0","id":903 MALFORMADO}' | websocat ws://127.0.0.1:9454
```
**Esperado (PASS):** `error.code` = -32700 (parse error).
