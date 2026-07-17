# Batería de Pruebas — Testeador bi18n

**Versión:** 1.0.0
**Fecha:** 2026-07-17
**Bloque:** 12.3
**Destinatario:** Agente Testeador de la fábrica ORQUESTA
**Objetivo:** verificar la completitud y corrección funcional del daemon bi18n en el VPS.

---

## §0 Prerequisitos

### 0.1 Verificar que el daemon está activo

```bash
systemctl is-active bi18nd
# Esperado: active

bi18nctl estado
# Esperado: JSON con status="ok", paises_cargados≥3
```

### 0.2 Herramientas requeridas

```bash
# bi18nctl (instalado con el daemon)
which bi18nctl                           # /usr/local/bin/bi18nctl

# socat (para JSON-RPC raw sobre Unix socket)
socat -V | head -1                       # socat version X.Y.Z...

# websocat (para pruebas WebSocket — opcional si el testeador la tiene)
which websocat || echo "websocat no disponible"
```

### 0.3 Verificar socket y permisos

```bash
ls -la /run/bos/bi18n.sock
# Esperado: srw-rw---- ... bos bosagent ...

stat -c "%U %G %a" /run/bos/bi18n.sock
# Esperado: bos bosagent 660
```

---

## §1 Función helper para JSON-RPC raw

Guardar en la sesión del Testeador para simplificar las llamadas:

```bash
# Helper: enviar una llamada JSON-RPC al daemon por socket Unix
rpc() {
  local METHOD="$1"
  local PARAMS="$2"
  local CTX="${3:-test-$(date +%s)}"
  echo "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$METHOD\",\"params\":{\"ctx_id\":\"$CTX\",$PARAMS}}" \
    | socat - UNIX-CONNECT:/run/bos/bi18n.sock
  echo
}

# Verificar que el helper funciona
rpc "bi18n.health.check" ""
# Esperado: {"jsonrpc":"2.0","id":1,"result":{"status":"ok",...}}
```

---

## §2 Pruebas por método

### §2.1 `bi18n.health.check`

```bash
# P-01: Estado básico del daemon
bi18nctl estado
# VERIFICAR: status="ok", paises_cargados=3 (BO+AR+BR), version presente

# P-01b: Output JSON estructurado
bi18nctl --json estado
# VERIFICAR: JSON válido con campos status, version, paises_cargados, mensaje

# P-01c: Raw JSON-RPC
rpc "bi18n.health.check" ""
# VERIFICAR: {"result":{"status":"ok",...}} — sin campo "error"
```

**Criterio de éxito:** `status="ok"` y `paises_cargados≥3`.

---

### §2.2 `bi18n.locale.resolve`

```bash
# P-02: Resolver locale por defecto (sin tenant específico)
bi18nctl locale-resolver --tenant default
# VERIFICAR: locale="es-BO", timezone="America/La_Paz", text_direction="ltr"

# P-02b: Tenant ficticio (debe retornar locale por defecto)
bi18nctl --json locale-resolver --tenant tenant-inexistente
# VERIFICAR: locale="es-BO", fuente="default"

# P-02c: Raw con todos los campos opcionales
rpc "bi18n.locale.resolve" '"tenant_id":"empresa-sa","branch_id":"norte","user_id":"usr-1"'
# VERIFICAR: locale, timezone, currency, country, fuente, text_direction todos presentes
```

---

### §2.3 `bi18n.validate.email`

```bash
# P-03a: Email válido — normalización
bi18nctl --json validar-email "Usuario@Empresa.COM"
# VERIFICAR: valid=true, normalized="usuario@empresa.com", errores=[]

# P-03b: Email inválido
bi18nctl --json validar-email "no-es-un-email"
# VERIFICAR: valid=false, normalized="", errores=["..."]

# P-03c: Email con caracteres especiales válidos
bi18nctl --json validar-email "user.name+tag@sub.domain.com"
# VERIFICAR: valid=true

# P-03d: Email vacío
bi18nctl --quiet validar-email ""
echo "Exit code: $?"
# VERIFICAR: exit code 1 (inválido) o 2 (error)
```

---

### §2.4 `bi18n.validate.phone`

```bash
# P-04a: Teléfono boliviano local (debe convertir a E.164)
bi18nctl --json validar-telefono "71234567" --pais BO
# VERIFICAR: valid=true, e164="+59171234567"

# P-04b: Número E.164 directo
bi18nctl --json validar-telefono "+59171234567"
# VERIFICAR: valid=true, e164="+59171234567"

# P-04c: Número argentino
bi18nctl --json validar-telefono "11-1234-5678" --pais AR
# VERIFICAR: valid=true, e164 con código +54

# P-04d: Número inválido
bi18nctl --json validar-telefono "123" --pais BO
# VERIFICAR: valid=false, errores=["..."]
```

---

### §2.5 `bi18n.validate.national_id`

```bash
# P-05a: CI Bolivia válido
bi18nctl --json validar-id "7654321-LP" --tipo CI --pais BO
# VERIFICAR: valid=true, normalized="7654321-LP"

# P-05b: CI Bolivia — normalización de minúsculas
bi18nctl --json validar-id "7654321-lp" --tipo CI --pais BO
# VERIFICAR: valid=true, normalized="7654321-LP" (uppercase)

# P-05c: NIT Bolivia
bi18nctl --json validar-id "123456789" --tipo NIT --pais BO
# VERIFICAR: valid=true o false según longitud

# P-05d: CI Bolivia inválido — mensaje Fluent
bi18nctl --json validar-id "INVALIDO" --tipo CI --pais BO
# VERIFICAR: valid=false, errores contiene mensaje localizado en español

# P-05e: CPF Brasil
bi18nctl --json validar-id "123.456.789-09" --tipo CPF --pais BR
# VERIFICAR: valid=true, normalized con formato CPF

# P-05f: DNI Argentina
bi18nctl --json validar-id "12345678" --tipo DNI --pais AR
# VERIFICAR: valid=true, normalized="12345678"

# P-05g: País sin soporte del tipo de documento
rpc "bi18n.validate.national_id" '"value":"12345","kind":"CPF","country":"BO"'
# VERIFICAR: error con código -32602 o result.valid=false + errores descriptivos
```

---

### §2.6 `bi18n.mask.value`

```bash
# P-06a: Máscara parcial (últimos 4 visibles)
bi18nctl --json mask-valor "7654321-LP" --estrategia "partial(4)"
# VERIFICAR: masked="****321-LP" (primeros caracteres reemplazados por *)

# P-06b: Máscara total
bi18nctl --json mask-valor "7654321-LP" --estrategia "full"
# VERIFICAR: masked="**********" (longitud del original)

# P-06c: Sin máscara
bi18nctl --json mask-valor "7654321-LP" --estrategia "none"
# VERIFICAR: masked="7654321-LP" (sin cambio)

# P-06d: Prefijo visible
rpc "bi18n.mask.value" '"value":"7654321-LP","strategy":"prefix(3)","country":"BO"'
# VERIFICAR: masked="765*******" (primeros 3 visibles)

# P-06e: Ambos extremos
rpc "bi18n.mask.value" '"value":"7654321-LP","strategy":"partial_both(2,2)","country":"BO"'
# VERIFICAR: masked="76****-LP" (2 inicio, 2 fin visibles)
```

---

### §2.7 `bi18n.mask.pii`

```bash
# P-07a: Texto con email y teléfono
bi18nctl --json mask-pii "Contactar a juan@empresa.com o al +59171234567 urgente."
# VERIFICAR: redacted="Contactar a [EMAIL] o al [TELEFONO] urgente.", campos_redactados=2

# P-07b: Solo emails
rpc "bi18n.mask.pii" '"text":"admin@server.com y ops@system.org","mask_emails":true,"mask_phones":false'
# VERIFICAR: ambos emails reemplazados, sin teléfonos afectados

# P-07c: Texto sin PII
bi18nctl --json mask-pii "Texto sin datos sensibles aquí."
# VERIFICAR: redacted igual al texto original, campos_redactados=0

# P-07d: Email con subdominio
bi18nctl --json mask-pii "Escribir a support@mail.empresa.com.bo"
# VERIFICAR: [EMAIL] en lugar del email
```

---

### §2.8 `bi18n.format.date`

```bash
# P-08a: Solo fecha en español boliviano
bi18nctl --json format-fecha "2026-07-17T14:30:00Z" --granularidad SoloFecha --locale es-BO
# VERIFICAR: display="17 de julio de 2026" (fecha en lenguaje natural)

# P-08b: Fecha y hora con zona horaria
bi18nctl --json format-fecha "2026-07-17T14:30:00Z" --granularidad FechaHora --locale es-BO --timezone "America/La_Paz"
# VERIFICAR: display incluye fecha y hora local (UTC-4 Bolivia = 10:30)

# P-08c: Solo mes y año
bi18nctl --json format-fecha "2026-07-01T00:00:00Z" --granularidad MesAnio --locale es-BO
# VERIFICAR: display="julio de 2026" o similar

# P-08d: Locale inglés
bi18nctl --json format-fecha "2026-07-17T00:00:00Z" --granularidad SoloFecha --locale en-US
# VERIFICAR: display contiene "July 17, 2026" o similar en inglés

# P-08e: Locale portugués Brasil
bi18nctl --json format-fecha "2026-07-17T00:00:00Z" --granularidad SoloFecha --locale pt-BR
# VERIFICAR: display="17 de julho de 2026" o similar

# P-08f: Fecha inválida
rpc "bi18n.format.date" '"iso_datetime":"no-es-fecha","granularity":"SoloFecha","locale":"es-BO","timezone":"America/La_Paz"'
# VERIFICAR: error en result (fecha inválida)
```

---

### §2.9 `bi18n.format.number`

```bash
# P-09a: Número con separadores bolivianos
bi18nctl --json format-numero 1234567.89 --decimales 2 --locale es-BO
# VERIFICAR: display="1,234,567.89" (punto decimal, coma miles — bo.toml)

# P-09b: Número Brasil (coma decimal, punto miles)
rpc "bi18n.format.number" '"value":"1234567.89","decimales":2,"locale":"pt-BR","country":"BR"'
# VERIFICAR: display="1.234.567,89"

# P-09c: Sin decimales
bi18nctl --json format-numero 1000000 --decimales 0 --locale es-BO
# VERIFICAR: display="1,000,000"

# P-09d: Número negativo
bi18nctl --json format-numero -1234.56 --decimales 2 --locale es-BO
# VERIFICAR: display="-1,234.56"
```

---

### §2.10 `bi18n.format.money`

```bash
# P-10a: Bolivianos
bi18nctl --json format-monto 1234.56 --moneda BOB --locale es-BO
# VERIFICAR: display="Bs. 1,234.56", symbol_local="Bs."

# P-10b: Pesos argentinos
bi18nctl --json format-monto 50000.00 --moneda ARS --locale es-AR
# VERIFICAR: display contiene símbolo ARS y número formateado

# P-10c: Reales brasileños
rpc "bi18n.format.money" '"amount":"1234.56","currency_code":"BRL","locale":"pt-BR","country":"BR"'
# VERIFICAR: display="R$ 1.234,56", symbol_local="R$"

# P-10d: Monto cero
bi18nctl --json format-monto 0 --moneda BOB --locale es-BO
# VERIFICAR: display="Bs. 0.00"
```

---

### §2.11 `bi18n.enum.display`

```bash
# P-11a: Enum existente
bi18nctl --json enum-display ESTADO_CIVIL CASADO --locale es-BO
# VERIFICAR: label="Casado/a" o similar, found=true

# P-11b: Enum de género
bi18nctl --json enum-display GENERO M --locale es-BO
# VERIFICAR: label="Masculino" o similar, found=true

# P-11c: Valor no encontrado (fallback)
bi18nctl --json enum-display ESTADO_CIVIL VALOR_INEXISTENTE --locale es-BO
# VERIFICAR: found=false, fallback=true, label=el valor original

# P-11d: Enum inexistente
bi18nctl --json enum-display ENUM_INEXISTENTE VALOR --locale es-BO
# VERIFICAR: found=false, fallback=true
```

---

### §2.12 `bi18n.regional.snapshot`

```bash
# P-12a: Snapshot completo Bolivia
bi18nctl --json snapshot --tenant default
# VERIFICAR: locale="es-BO", timezone="America/La_Paz", currency="BOB", country="BO"
# VERIFICAR: separadores.decimal=".", separadores.miles=","
# VERIFICAR: documentos contiene CI, NIT
# VERIFICAR: enums_disponibles es array no vacío

# P-12b: Output en modo no-JSON
bi18nctl snapshot --tenant default
# VERIFICAR: output legible (pretty JSON o tabla)
```

---

### §2.13 `bi18n.attr.pipeline`

```bash
# P-13a: Pipeline completo CI Bolivia
rpc "bi18n.attr.pipeline" '"field_id":"ci_numero","value":"7654321-lp","validator_profile":"ID_BO","mask":"partial(4)","transforms":["trim","uppercase"],"locale":"es-BO","country":"BO","timezone":"America/La_Paz","currency":"BOB"'
# VERIFICAR:
#   raw="7654321-lp" (original)
#   valid=true
#   transformed="7654321-LP" (uppercase)
#   display="7654321-LP"
#   masked="****321-LP"
#   validation_errors=[]

# P-13b: Pipeline con valor inválido
rpc "bi18n.attr.pipeline" '"field_id":"ci_numero","value":"invalido","validator_profile":"ID_BO","mask":"none","transforms":[],"locale":"es-BO","country":"BO","timezone":"America/La_Paz","currency":"BOB"'
# VERIFICAR: valid=false, validation_errors=["...mensaje en español..."]

# P-13c: Pipeline de fecha
rpc "bi18n.attr.pipeline" '"field_id":"fecha_nacimiento","value":"1990-05-15T00:00:00Z","validator_profile":"FECHA","format_code":"FECHA_LARGA","mask":"none","transforms":[],"locale":"es-BO","country":"BO","timezone":"America/La_Paz","currency":"BOB"'
# VERIFICAR: display es fecha formateada en español
```

---

### §2.14 `bi18n.attr.build`

```bash
# P-14a: Build de fecha (sin validación)
rpc "bi18n.attr.build" '"key":"fecha_nacimiento","value":"1990-05-15T00:00:00Z","format_code":"FECHA_LARGA","mask":"none","locale":"es-BO","timezone":"America/La_Paz","currency":"BOB","country":"BO"'
# VERIFICAR: display="15 de mayo de 1990" o similar, raw y masked presentes

# P-14b: Build de monto
rpc "bi18n.attr.build" '"key":"saldo","value":"5000","format_code":"MONTO","mask":"none","locale":"es-BO","timezone":"America/La_Paz","currency":"BOB","country":"BO"'
# VERIFICAR: display formateado con separadores
```

---

### §2.15 `bi18n.attr.config`

```bash
# P-15a: Config de CI Bolivia
rpc "bi18n.attr.config" '"display_format":"ID_BO","locale":"es-BO"'
# VERIFICAR: display_format="ID_BO", validator_profile presente, mask_pattern presente

# P-15b: Config de email
rpc "bi18n.attr.config" '"display_format":"EMAIL","locale":"es-BO"'
# VERIFICAR: masks_pii=true

# P-15c: Config de fecha
rpc "bi18n.attr.config" '"display_format":"FECHA","locale":"es-BO"'
# VERIFICAR: input_mask="99/99/9999" o similar
```

---

### §2.16 `bi18n.attr.config_batch`

```bash
# P-16a: Batch de campos de un formulario
rpc "bi18n.attr.config_batch" '"tenant_id":"default","fields":["ci_numero","fecha_nacimiento","telefono_celular","email"]'
# VERIFICAR:
#   locale="es-BO", country="BO", text_direction="ltr"
#   campos es array de 4 elementos
#   cada campo tiene: key, display_format, validator_profile, mask_pattern, masks_pii

# P-16b: Batch con locale explícito (sin resolver por tenant)
rpc "bi18n.attr.config_batch" '"locale":"pt-BR","country":"BR","fields":["cpf","email"]'
# VERIFICAR: locale="pt-BR", country="BR"

# P-16c: Batch con locale RTL (árabe)
rpc "bi18n.attr.config_batch" '"locale":"ar-SA","country":"SA","fields":["email"]'
# VERIFICAR: text_direction="rtl"
```

---

### §2.17 `bi18n.admin.reload`

```bash
# P-17a: Recarga completa
bi18nctl recargar
# VERIFICAR: output indica recargado=true, country_rules="ok", fluent="ok"

# P-17b: Estado post-recarga
bi18nctl estado
# VERIFICAR: daemon sigue activo, paises_cargados no cambió

# P-17c: Raw JSON-RPC
rpc "bi18n.admin.reload" ""
# VERIFICAR: recargado=true, paises_cargados=3
```

---

### §2.18 `bi18n.admin.reload_translations`

```bash
# P-18a: Recarga solo FTL
bi18nctl recargar-traducciones
# VERIFICAR: recargado=true, mensaje="traducciones recargadas sin interrupción de servicio"

# P-18b: Verificar que el daemon sigue activo post-recarga
bi18nctl estado
# VERIFICAR: status="ok" — sin downtime

# P-18c: Recarga concurrente (varias peticiones durante la recarga)
# Enviar 10 peticiones paralelas mientras se recarga:
for i in $(seq 1 10); do
  rpc "bi18n.health.check" "" "check-$i" &
done
rpc "bi18n.admin.reload_translations" ""
wait
# VERIFICAR: todas las respuestas de health.check son correctas (sin corrupción)
```

---

## §3 Pruebas de error y casos límite

### §3.1 ctx_id ausente

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"bi18n.health.check","params":{}}' \
  | socat - UNIX-CONNECT:/run/bos/bi18n.sock
# VERIFICAR: error.code=-32602, message contiene "ctx_id"
```

### §3.2 ctx_id vacío

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"bi18n.health.check","params":{"ctx_id":""}}' \
  | socat - UNIX-CONNECT:/run/bos/bi18n.sock
# VERIFICAR: error.code=-32602
```

### §3.3 Método inexistente

```bash
rpc "bi18n.metodo.inexistente" ""
# VERIFICAR: error.code=-32601
```

### §3.4 JSON malformado

```bash
echo 'NO ES JSON{' | socat - UNIX-CONNECT:/run/bos/bi18n.sock
# VERIFICAR: error.code=-32700 (JSON parse error) o cierre de conexión
```

### §3.5 Locale BCP 47 inválido

```bash
bi18nctl --json format-fecha "2026-07-17T00:00:00Z" --locale "INVALIDO-99"
# VERIFICAR: no crashea, hace fallback a "und" o retorna error descriptivo
```

### §3.6 País no registrado

```bash
rpc "bi18n.validate.national_id" '"value":"12345","kind":"CI","country":"XX"'
# VERIFICAR: error descriptivo en español (país no soportado)
```

---

## §4 Pruebas de CLI bi18nctl

### §4.1 Subcomando local (sin daemon)

```bash
# P-CLI-01: check-parity con paridad correcta
cd /etc/bos/bi18n   # o donde estén los locales
bi18nctl --json translations check-parity --reference es-BO --locales-dir locales
# VERIFICAR: ok=true, faltantes={}

# P-CLI-02: check-parity con --fail-on-missing
bi18nctl translations check-parity --reference es-BO --locales-dir locales --fail-on-missing
echo "Exit: $?"
# VERIFICAR: exit 0 si paridad correcta, exit 1 si hay claves faltantes
```

### §4.2 Flags transversales

```bash
# P-CLI-03: --quiet (solo exit code)
bi18nctl --quiet estado
echo "Exit: $?"
# VERIFICAR: sin output, exit 0

# P-CLI-04: --json
bi18nctl --json estado | python3 -m json.tool > /dev/null
echo "Exit: $?"
# VERIFICAR: JSON válido (python3 -m json.tool no falla)

# P-CLI-05: --ctx-id explícito
bi18nctl --ctx-id "mi-ctx-personalizado-001" estado
# VERIFICAR: sin error (ctx_id aceptado)

# P-CLI-06: --socket personalizado
bi18nctl --socket /run/bos/bi18n.sock estado
# VERIFICAR: misma respuesta que sin --socket
```

---

## §5 Prueba de hot-reload de traducciones

```bash
# P-HR-01: Editar un mensaje FTL y verificar que se recarga

# Leer mensaje actual
MSG_ANTES=$(rpc "bi18n.validate.email" '"value":"invalido"' | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['result']['errores'][0] if 'result' in d and d['result']['errores'] else 'ERROR')")
echo "Mensaje antes: $MSG_ANTES"

# Editar el FTL (cambiar el mensaje)
FLUENT_DIR=$(bi18nctl --json estado | python3 -c "import sys,json;d=json.load(sys.stdin)" 2>/dev/null && echo "/etc/bos/bi18n/locales")
# Modificar locales/es-BO/main.ftl — cambiar "error-email-invalido" temporalmente:
# sed -i 's/Dirección de email inválida./PRUEBA-RECARGA-HOT-RELOAD./' $FLUENT_DIR/es-BO/main.ftl

# Esperar recarga automática (inotify < 2s)
sleep 3

# Verificar mensaje nuevo
MSG_DESPUES=$(rpc "bi18n.validate.email" '"value":"invalido"' | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['result']['errores'][0] if 'result' in d and d['result']['errores'] else 'ERROR')")
echo "Mensaje después: $MSG_DESPUES"

# VERIFICAR: MSG_DESPUES contiene "PRUEBA-RECARGA-HOT-RELOAD"

# Restaurar el mensaje original
# sed -i 's/PRUEBA-RECARGA-HOT-RELOAD./Dirección de email inválida./' $FLUENT_DIR/es-BO/main.ftl
sleep 3
```

---

## §6 Prueba de WebSocket (si websocat disponible)

```bash
# P-WS-01: Conexión básica por WebSocket
echo '{"jsonrpc":"2.0","id":1,"method":"bi18n.health.check","params":{"ctx_id":"ws-test-001"}}' \
  | timeout 5 websocat ws://127.0.0.1:9454/ 2>/dev/null || echo "websocat no disponible o timeout"
# VERIFICAR: {"result":{"status":"ok",...}} O "websocat no disponible"

# P-WS-02: Rate limit WebSocket
# Enviar 150 requests en 1 segundo (límite: 100 rps)
for i in $(seq 1 150); do
  echo '{"jsonrpc":"2.0","id":'$i',"method":"bi18n.health.check","params":{"ctx_id":"rate-'$i'"}}'
done | timeout 10 websocat -n ws://127.0.0.1:9454/ 2>/dev/null | grep -c '"code":-32000' || echo "skipped"
# VERIFICAR: algunos responses tienen error.code=-32000 (rate limit)
```

---

## §7 Prueba de disponibilidad del daemon

```bash
# P-DA-01: El daemon sobrevive SIGHUP sin apagarse
PID=$(systemctl show bi18nd --property MainPID | cut -d= -f2)
kill -HUP "$PID"
sleep 2

systemctl is-active bi18nd
# VERIFICAR: active (no se reinicia, solo recarga)

bi18nctl estado
# VERIFICAR: status="ok"
```

---

## §8 Checklist final de completitud

El Testeador debe responder VERDADERO/FALSO para cada línea:

```
[ ] VERDADERO/FALSO — bi18nd está activo como servicio systemd
[ ] VERDADERO/FALSO — paises_cargados = 3 (BO, AR, BR)
[ ] VERDADERO/FALSO — bi18n.health.check retorna status="ok"
[ ] VERDADERO/FALSO — bi18n.locale.resolve retorna text_direction
[ ] VERDADERO/FALSO — bi18n.validate.email normaliza a minúsculas
[ ] VERDADERO/FALSO — bi18n.validate.phone retorna E.164 para número boliviano
[ ] VERDADERO/FALSO — bi18n.validate.national_id valida CI boliviano 7654321-LP
[ ] VERDADERO/FALSO — bi18n.validate.national_id valida CPF brasileño
[ ] VERDADERO/FALSO — bi18n.validate.national_id valida DNI argentino
[ ] VERDADERO/FALSO — bi18n.mask.value con partial(4) produce ****321-LP
[ ] VERDADERO/FALSO — bi18n.mask.pii enmascara email y teléfono en texto libre
[ ] VERDADERO/FALSO — bi18n.format.date produce "17 de julio de 2026" para es-BO
[ ] VERDADERO/FALSO — bi18n.format.date produce texto en inglés para en-US
[ ] VERDADERO/FALSO — bi18n.format.number produce separadores correctos para es-BO
[ ] VERDADERO/FALSO — bi18n.format.number produce separadores correctos para pt-BR
[ ] VERDADERO/FALSO — bi18n.format.money produce "Bs. X,XXX.XX" para BOB
[ ] VERDADERO/FALSO — bi18n.enum.display traduce ESTADO_CIVIL.CASADO
[ ] VERDADERO/FALSO — bi18n.regional.snapshot retorna documentos y enums
[ ] VERDADERO/FALSO — bi18n.attr.pipeline transforma + valida + enmascara en un paso
[ ] VERDADERO/FALSO — bi18n.attr.config_batch retorna text_direction
[ ] VERDADERO/FALSO — bi18n.attr.config_batch retorna text_direction="rtl" para ar-SA
[ ] VERDADERO/FALSO — bi18n.admin.reload retorna recargado=true
[ ] VERDADERO/FALSO — bi18n.admin.reload_translations retorna recargado=true
[ ] VERDADERO/FALSO — ctx_id ausente retorna error -32602
[ ] VERDADERO/FALSO — método inexistente retorna error -32601
[ ] VERDADERO/FALSO — bi18nctl translations check-parity pasa con paridad correcta
[ ] VERDADERO/FALSO — daemon sobrevive SIGHUP (recarga sin apagarse)
[ ] VERDADERO/FALSO — all_checks: TODAS las anteriores son VERDADERO
```

**Dictamen:** `VERDADERO` si `all_checks=VERDADERO`. `FALSO` si cualquier verificación falla.
Adjuntar evidencia de cada `FALSO` con el output real del comando ejecutado.

---

## Historial

| Versión | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-17 | Creación. Bloque 12.3. 28 verificaciones del checklist, pruebas de los 18 métodos, casos límite, CLI, WebSocket, hot-reload, SIGHUP. |
