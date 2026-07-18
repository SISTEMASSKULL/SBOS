# A.11 — Batería de pruebas CLI — bi18nctl (completa)

**Versión:** 1.0.0
**Fecha:** 2026-07-18
**Destinatario:** Agente Testeador (fábrica ORQUESTA) — dictamina VERDADERO/FALSO con evidencia.
**Herramienta de prueba:** `bi18nctl` (binario en `/usr/local/bin/bi18nctl`)
**Socket:** `/run/bos/bi18n.sock` (el daemon debe estar activo: `systemctl is-active bi18nd`)
**Prerequisito:** `bi18nd` corriendo con country-rules y locales FTL cargados.
**Manual de referencia:** [1.03 Manual del Programador](../1.03_MANUAL-PROGRAMADOR-BI18N-v1.0.md)

**Convención de resultados:**
- `PASS` = salida contiene el campo esperado y exit code 0
- `FAIL` = salida inesperada o exit code ≠ 0
- Los casos de error esperan exit code 2

---

## §0 Preparación del entorno

```bash
# Verificar daemon activo
systemctl is-active bi18nd
# Esperado: "active"

# Verificar socket accesible
test -S /run/bos/bi18n.sock && echo "OK" || echo "FALTA SOCKET"

# Variable global para todas las pruebas
CTX="test-$(date +%s)"
```

---

## §1 Estado y salud

### TC-CLI-001 — Estado básico
```bash
bi18nctl estado --json
```
**Esperado (PASS):** JSON con `"status": "ok"` y campo `"version"` no vacío.

### TC-CLI-002 — Estado silencioso (para CI/CD)
```bash
bi18nctl --quiet estado; echo "exit=$?"
```
**Esperado (PASS):** `exit=0`, sin output.

### TC-CLI-003 — ctx_id explícito
```bash
bi18nctl --ctx-id "test-ctx-001" estado --json
```
**Esperado (PASS):** JSON con `"status": "ok"` (el ctx_id se acepta sin error).

---

## §2 Locale y región

### TC-CLI-010 — Resolver locale por defecto
```bash
bi18nctl locale-resolver --json
```
**Esperado (PASS):** JSON con campos `"locale"`, `"timezone"`, `"currency"`, `"country"`.

### TC-CLI-011 — Resolver locale con tenant explícito
```bash
bi18nctl locale-resolver --tenant "empresa-demo" --json
```
**Esperado (PASS):** JSON con `"locale"` no vacío.

### TC-CLI-012 — Snapshot regional
```bash
bi18nctl snapshot --tenant "default" --json
```
**Esperado (PASS):** JSON con payload de configuración regional.

---

## §3 Formato de fechas

### TC-CLI-020 — Fecha completa (fecha+hora)
```bash
bi18nctl format-fecha "2026-07-18T14:30:00Z" --locale es-BO --granularidad FechaHora --json
```
**Esperado (PASS):** JSON con `"display"` no vacío.

### TC-CLI-021 — Solo fecha
```bash
bi18nctl format-fecha "2026-07-18T00:00:00Z" --locale es-BO --granularidad SoloFecha --json
```
**Esperado (PASS):** `"display"` contiene la fecha sin hora.

### TC-CLI-022 — Mes y año
```bash
bi18nctl format-fecha "2026-07-01T00:00:00Z" --locale es-BO --granularidad MesAnio --json
```
**Esperado (PASS):** `"display"` contiene "julio 2026" o equivalente.

### TC-CLI-023 — Formato número
```bash
bi18nctl format-numero 1234567.89 --decimales 2 --locale es-BO --json
```
**Esperado (PASS):** `"display"` contiene separadores de miles en formato boliviano.

### TC-CLI-024 — Formato moneda
```bash
bi18nctl format-monto 1234.56 --moneda BOB --locale es-BO --json
```
**Esperado (PASS):** `"display"` contiene símbolo "Bs." o "BOB".

---

## §4 Validación básica (Fase 1)

### TC-CLI-030 — Email válido
```bash
bi18nctl validar-email "usuario@empresa.com" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-031 — Email inválido
```bash
bi18nctl validar-email "no-es-email" --json
```
**Esperado (PASS):** `"valid": false` o `"errores"` no vacío.

### TC-CLI-032 — Teléfono boliviano válido
```bash
bi18nctl validar-telefono "+59171234567" --pais BO --json
```
**Esperado (PASS):** `"valid": true` y `"e164"` = "+59171234567".

### TC-CLI-033 — CI boliviana
```bash
bi18nctl validar-id "7654321-LP" --tipo CI --pais BO --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-034 — NIT boliviano
```bash
bi18nctl validar-id "123456789" --tipo NIT --pais BO --json
```
**Esperado (PASS):** `"valid": true` o `"errores"` con razón si el NIT es inválido.

---

## §5 Enmascaramiento básico

### TC-CLI-040 — Mask parcial
```bash
bi18nctl mask-valor "7654321" --estrategia parcial --json
```
**Esperado (PASS):** `"masked"` con caracteres enmascarados.

### TC-CLI-041 — Mask total
```bash
bi18nctl mask-valor "secreto" --estrategia total --json
```
**Esperado (PASS):** `"masked"` con todos los caracteres reemplazados.

### TC-CLI-042 — Mask PII en texto
```bash
bi18nctl mask-pii "Mi email es juan@test.com y mi tel es +59171234567" --json
```
**Esperado (PASS):** `"redacted"` con email y teléfono enmascarados.

---

## §6 Enums

### TC-CLI-050 — Enum display
```bash
bi18nctl enum-display ESTADO_CIVIL CASADO --locale es-BO --json
```
**Esperado (PASS):** `"label"` no vacío (por ejemplo "Casado").

---

## §7 Pipeline de atributos

### TC-CLI-060 — Pipeline CI
```bash
bi18nctl attr-pipeline ci_numero "7654321-LP" --tenant default --json
```
**Esperado (PASS):** JSON con `"valid"`, `"display"`, `"masked"`.

---

## §8 Traducciones Fluent (A.08.01)

### TC-CLI-070 — Verificar existencia de mensaje
```bash
bi18nctl translate has-message --id "bienvenida" --locale "es-BO" --json
```
**Esperado (PASS):** JSON con `"existe"` booleano.

### TC-CLI-071 — Traducir mensaje simple
```bash
bi18nctl translate message --id "bienvenida" --locale "es-BO" --json
```
**Esperado (PASS):** JSON con `"text"` no vacío.

### TC-CLI-072 — Traducir con argumentos
```bash
bi18nctl translate message-with-args \
  --id "saludo-usuario" --locale "es-BO" \
  --args '{"nombre":"Ana"}' --json
```
**Esperado (PASS):** `"text"` contiene "Ana" interpolada.

### TC-CLI-073 — Batch de mensajes
```bash
bi18nctl translate batch \
  --ids "bienvenida,saludo-usuario" --locale "es-BO" --json
```
**Esperado (PASS):** JSON con array de resultados, uno por id.

### TC-CLI-074 — Listar mensajes de namespace
```bash
bi18nctl translate list-messages --locale "es-BO" --namespace "ui" --json
```
**Esperado (PASS):** JSON con `"messages"` (mapa id→texto) y `"count"` > 0.

### TC-CLI-075 — Traducir atributo de mensaje
```bash
bi18nctl translate message-attribute \
  --id "boton-guardar" --attribute "tooltip" --locale "es-BO" --json
```
**Esperado (PASS):** JSON con `"text"` del atributo.

### TC-CLI-076 — Bundle completo de namespace
```bash
bi18nctl translate bundle --locale "es-BO" --namespace "ui" --json
```
**Esperado (PASS):** JSON con `"bundle"` (mapa id→texto), `"count"` > 0, `"locale"` = "es-BO".

---

## §9 rust-i18n (A.08.02)

### TC-CLI-080 — Locale activo
```bash
bi18nctl i18n locale-activo --json
```
**Esperado (PASS):** JSON con `"locale"` BCP47 no vacío.

### TC-CLI-081 — Locales disponibles
```bash
bi18nctl i18n available-locales --json
```
**Esperado (PASS):** JSON con `"locales"` array, longitud > 0.

### TC-CLI-082 — Establecer locale
```bash
bi18nctl i18n set-locale --locale "es-BO" --json
```
**Esperado (PASS):** JSON con `"ok": true`.

### TC-CLI-083 — Traducción inline
```bash
bi18nctl i18n t --key "app.title" --locale "es-BO" --json
```
**Esperado (PASS):** JSON con `"text"` no vacío.

---

## §10 ICU locale BCP-47 (A.08.04)

### TC-CLI-090 — Parsear BCP47
```bash
bi18nctl locale-fase2 parse-bcp47 --locale "es-419" --json
```
**Esperado (PASS):** JSON con `"language"` = "es", `"region"` = "419".

### TC-CLI-091 — Canonicalizar
```bash
bi18nctl locale-fase2 canonicalize --locale "es_BO" --json
```
**Esperado (PASS):** `"canonical"` = "es-BO" (guion, no guion bajo).

### TC-CLI-092 — Negociación de locales
```bash
bi18nctl locale-fase2 negotiate \
  --requested "es-AR,es,en" --available "es-BO,en-US" --json
```
**Esperado (PASS):** `"negotiated"` = "es-BO" o similar.

### TC-CLI-093 — Subtags de locale
```bash
bi18nctl locale-fase2 subtags --locale "es-BO-u-ca-gregory" --json
```
**Esperado (PASS):** JSON con `"language"`, `"region"` y opcionalmente `"extensions"`.

---

## §11 ICU datetime format (A.08.03)

### TC-CLI-100 — Datetime ICU full
```bash
bi18nctl format-fase2 datetime-icu \
  --iso "2026-07-18T14:30:00Z" --locale "es-BO" \
  --date-style "full" --time-style "short" --json
```
**Esperado (PASS):** `"display"` contiene fecha en español.

### TC-CLI-101 — Solo fecha ICU
```bash
bi18nctl format-fase2 date-icu \
  --iso "2026-07-18T00:00:00Z" --locale "es-BO" --style "long" --json
```
**Esperado (PASS):** `"display"` = "18 de julio de 2026" o similar.

### TC-CLI-102 — Solo hora ICU
```bash
bi18nctl format-fase2 time-icu \
  --iso "2026-07-18T14:30:00Z" --locale "es-BO" --style "short" --json
```
**Esperado (PASS):** `"display"` contiene "14:30" o "2:30 p.m." según locale.

### TC-CLI-103 — Nombre de día
```bash
bi18nctl format-fase2 weekday-name \
  --iso "2026-07-18T00:00:00Z" --locale "es-BO" --width "wide" --json
```
**Esperado (PASS):** `"display"` = "sábado" (18/07/2026 es sábado).

### TC-CLI-104 — Nombre de mes
```bash
bi18nctl format-fase2 month-name \
  --iso "2026-07-18T00:00:00Z" --locale "es-BO" --width "wide" --json
```
**Esperado (PASS):** `"display"` = "julio".

### TC-CLI-105 — Datetime con timezone
```bash
bi18nctl format-fase2 datetime-with-time \
  --iso "2026-07-18T14:30:00Z" --locale "es-BO" --timezone "America/La_Paz" --json
```
**Esperado (PASS):** `"display"` contiene hora ajustada a UTC-4.

---

## §12 ICU decimal (A.08.05)

### TC-CLI-110 — Número ICU estándar
```bash
bi18nctl format-fase2 number-icu --value "1234567.89" --locale "es-BO" --json
```
**Esperado (PASS):** `"display"` con separadores de miles.

### TC-CLI-111 — Sin agrupamiento
```bash
bi18nctl format-fase2 number-no-grouping --value "1234567" --locale "es-BO" --json
```
**Esperado (PASS):** `"display"` = "1234567" (sin separadores).

### TC-CLI-112 — Agrupamiento siempre
```bash
bi18nctl format-fase2 number-grouping-always --value "12345" --locale "es-BO" --json
```
**Esperado (PASS):** `"display"` con separador de miles aunque sea < 10000.

### TC-CLI-113 — Agrupamiento mínimo 2
```bash
bi18nctl format-fase2 number-grouping-min2 --value "9999" --locale "es-BO" --json
```
**Esperado (PASS):** `"display"` sin separador (< 10000, regla min2).

---

## §13 Validación de formatos (A.08.06 — validator)

### TC-CLI-120 — Email HTML5 válido
```bash
bi18nctl validate-fase2 email-html5 --value "test@example.com" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-121 — URL válida
```bash
bi18nctl validate-fase2 url --value "https://sbos.local" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-122 — IP genérica válida
```bash
bi18nctl validate-fase2 ip --value "192.168.1.1" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-123 — IPv4
```bash
bi18nctl validate-fase2 ipv4 --value "10.0.0.1" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-124 — IPv6
```bash
bi18nctl validate-fase2 ipv6 --value "::1" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-125 — Longitud de string
```bash
bi18nctl validate-fase2 length --value "hola" --min 2 --max 10 --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-126 — Rango numérico
```bash
bi18nctl validate-fase2 range --value 5.0 --min 1.0 --max 10.0 --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-127 — Contiene subcadena
```bash
bi18nctl validate-fase2 contains --value "hola mundo" --needle "mundo" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-128 — No contiene subcadena
```bash
bi18nctl validate-fase2 not-contains --value "hola mundo" --needle "adios" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-129 — Requerido (no vacío)
```bash
bi18nctl validate-fase2 required --value "algo" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-130 — Tarjeta de crédito (Luhn)
```bash
bi18nctl validate-fase2 credit-card --value "4111111111111111" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-131 — Coincidencia exacta
```bash
bi18nctl validate-fase2 must-match --a "abc123" --b "abc123" --json
```
**Esperado (PASS):** `"valid": true`.

---

## §14 Validación formatos especiales (A.08.07 — scrutiny)

### TC-CLI-140 — UUID válido
```bash
bi18nctl validate-fase2 uuid --value "550e8400-e29b-41d4-a716-446655440000" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-141 — ULID válido
```bash
bi18nctl validate-fase2 ulid --value "01ARZ3NDEKTSV4RRFFQ69G5FAV" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-142 — MAC address
```bash
bi18nctl validate-fase2 mac-address --value "00:1A:2B:3C:4D:5E" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-143 — Color hexadecimal
```bash
bi18nctl validate-fase2 hex-color --value "#FF5733" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-144 — Zona horaria IANA
```bash
bi18nctl validate-fase2 timezone --value "America/La_Paz" --json
```
**Esperado (PASS):** `"valid": true`.

### TC-CLI-145 — JSON válido
```bash
bi18nctl validate-fase2 is-json --value '{"clave":"valor"}' --json
```
**Esperado (PASS):** `"valid": true`.

---

## §15 Máscaras PII en texto (A.08.08)

### TC-CLI-150 — Enmascarar email en texto
```bash
bi18nctl mask-fase2 email-in-text --text "El email es user@test.com aquí." --json
```
**Esperado (PASS):** `"masked"` con email reemplazado.

### TC-CLI-151 — Enmascarar teléfono en texto
```bash
bi18nctl mask-fase2 phone-in-text --text "Llame al +59171234567 ahora." --json
```
**Esperado (PASS):** `"masked"` con teléfono reemplazado.

### TC-CLI-152 — Enmascarar PII completo
```bash
bi18nctl mask-fase2 pii --text "Email: a@b.com Tel: +59171234567" --json
```
**Esperado (PASS):** `"masked"` con ambos datos reemplazados.

### TC-CLI-153 — Enmascarar PII con carácter personalizado
```bash
bi18nctl mask-fase2 pii-with-char --text "Email: user@test.com" --char "X" --json
```
**Esperado (PASS):** `"masked"` con caracteres X en lugar del email.

---

## §16 Máscaras estructurales (A.08.09)

### TC-CLI-160 — Máscara estructural libre
```bash
bi18nctl format-fase2 structural-mask \
  --text "71234567" --pattern "XXXX-XXXX" --json
```
**Esperado (PASS):** `"masked"` = "7123-4567".

### TC-CLI-161 — CNPJ brasileño
```bash
bi18nctl format-fase2 mask-cnpj --text "11222333000181" --json
```
**Esperado (PASS):** `"masked"` = "11.222.333/0001-81".

### TC-CLI-162 — CPF brasileño
```bash
bi18nctl format-fase2 mask-cpf --text "11144477735" --json
```
**Esperado (PASS):** `"masked"` = "111.444.777-35".

### TC-CLI-163 — Tarjeta de crédito
```bash
bi18nctl format-fase2 mask-card --text "4111111111111111" --json
```
**Esperado (PASS):** `"masked"` muestra solo últimos 4 dígitos.

### TC-CLI-164 — CI boliviana
```bash
bi18nctl format-fase2 mask-ci-bo --text "7654321LP" --json
```
**Esperado (PASS):** `"masked"` = "7654321-LP" o formato normalizado.

---

## §17 Fecha/hora jiff (A.08.10)

### TC-CLI-170 — Ahora UTC
```bash
bi18nctl datetime now-utc --json
```
**Esperado (PASS):** `"datetime"` en formato ISO 8601, sufijo Z.

### TC-CLI-171 — Ahora con zona horaria
```bash
bi18nctl datetime now-tz --timezone "America/La_Paz" --json
```
**Esperado (PASS):** `"datetime"` con offset -04:00.

### TC-CLI-172 — Parsear datetime jiff
```bash
bi18nctl datetime parse-jiff \
  --datetime "2026-07-18T14:30:00Z" --timezone "UTC" --json
```
**Esperado (PASS):** JSON con `"year"` = 2026, `"month"` = 7, `"day"` = 18.

### TC-CLI-173 — Desde unix timestamp
```bash
bi18nctl datetime from-unix --unix 1753000000 --timezone "UTC" --json
```
**Esperado (PASS):** JSON con fecha/hora correspondiente al timestamp.

### TC-CLI-174 — Formatear datetime jiff
```bash
bi18nctl datetime format-jiff \
  --datetime "2026-07-18T14:30:00Z" \
  --format "%Y-%m-%d" --timezone "UTC" --json
```
**Esperado (PASS):** `"formatted"` = "2026-07-18".

### TC-CLI-175 — Serie de fechas
```bash
bi18nctl datetime series \
  --start "2026-07-01T00:00:00Z" --end "2026-07-05T00:00:00Z" \
  --unit "day" --step 1 --timezone "UTC" --json
```
**Esperado (PASS):** `"series"` con 5 elementos (2026-07-01 a 2026-07-05).

### TC-CLI-176 — Sumar span
```bash
bi18nctl datetime add-span \
  --datetime "2026-07-18T00:00:00Z" --timezone "UTC" \
  --days 7 --json
```
**Esperado (PASS):** `"result"` = "2026-07-25T00:00:00Z".

### TC-CLI-177 — Restar span
```bash
bi18nctl datetime sub-span \
  --datetime "2026-07-18T00:00:00Z" --timezone "UTC" \
  --days 7 --json
```
**Esperado (PASS):** `"result"` = "2026-07-11T00:00:00Z".

### TC-CLI-178 — Diferencia entre fechas
```bash
bi18nctl datetime diff-span \
  --start "2026-07-01T00:00:00Z" \
  --end "2026-07-18T00:00:00Z" \
  --unit "day" --timezone "UTC" --json
```
**Esperado (PASS):** `"diff"` = 17.

### TC-CLI-179 — Convertir zona horaria
```bash
bi18nctl datetime convert-tz \
  --datetime "2026-07-18T18:00:00Z" \
  --from "UTC" --to "America/La_Paz" --json
```
**Esperado (PASS):** `"result"` con hora ajustada a UTC-4 (14:00).

### TC-CLI-180 — Redondear al día
```bash
bi18nctl datetime round \
  --datetime "2026-07-18T14:30:00Z" --timezone "UTC" \
  --unit "day" --mode "floor" --json
```
**Esperado (PASS):** `"result"` = "2026-07-18T00:00:00Z".

### TC-CLI-181 — Día de la semana
```bash
bi18nctl datetime weekday-of-date \
  --datetime "2026-07-18T00:00:00Z" --timezone "UTC" --json
```
**Esperado (PASS):** `"weekday"` = "Saturday" o 6 (18/07/2026 es sábado).

### TC-CLI-182 — Días en el mes
```bash
bi18nctl datetime days-in-month \
  --datetime "2026-07-01T00:00:00Z" --timezone "UTC" --json
```
**Esperado (PASS):** `"days"` = 31.

### TC-CLI-183 — Año bisiesto
```bash
bi18nctl datetime is-leap-year \
  --datetime "2024-01-01T00:00:00Z" --timezone "UTC" --json
```
**Esperado (PASS):** `"leap"` = true (2024 es bisiesto).

### TC-CLI-184 — Enésimo día de la semana del mes
```bash
bi18nctl datetime nth-weekday \
  --year 2026 --month 7 --weekday 1 --nth 1 --json
```
**Esperado (PASS):** `"date"` = primer lunes de julio 2026.

### TC-CLI-185 — Total de span en unidades
```bash
bi18nctl datetime span-total \
  --days 1 --hours 2 --minutes 30 --unit "minutes" --json
```
**Esperado (PASS):** `"total"` = 1590 (1 día + 2:30 = 26.5 horas = 1590 min).

### TC-CLI-186 — Información de timezone
```bash
bi18nctl datetime tz-info --timezone "America/La_Paz" --json
```
**Esperado (PASS):** JSON con `"offset"` = "-04:00" y `"name"` = "America/La_Paz".

---

## §18 Chrono (A.08.11)

### TC-CLI-190 — Parsear RFC3339
```bash
bi18nctl datetime chrono-parse-rfc3339 \
  --value "2026-07-18T14:30:00+00:00" --json
```
**Esperado (PASS):** JSON con `"year"` = 2026.

### TC-CLI-191 — Parsear RFC2822
```bash
bi18nctl datetime chrono-parse-rfc2822 \
  --value "Sat, 18 Jul 2026 14:30:00 +0000" --json
```
**Esperado (PASS):** JSON con `"year"` = 2026.

### TC-CLI-192 — A RFC3339
```bash
bi18nctl datetime chrono-to-rfc3339 \
  --unix 1753000000 --json
```
**Esperado (PASS):** `"rfc3339"` con timestamp en formato RFC3339.

### TC-CLI-193 — A RFC2822
```bash
bi18nctl datetime chrono-to-rfc2822 \
  --unix 1753000000 --json
```
**Esperado (PASS):** `"rfc2822"` en formato RFC 2822.

### TC-CLI-194 — Formatear con strftime
```bash
bi18nctl datetime chrono-format \
  --unix 1753000000 --format "%Y-%m-%d" --json
```
**Esperado (PASS):** `"formatted"` en formato YYYY-MM-DD.

### TC-CLI-195 — Formatear localizado
```bash
bi18nctl datetime chrono-format-localized \
  --unix 1753000000 --format "%d %B %Y" --locale "es-BO" --json
```
**Esperado (PASS):** `"formatted"` con nombre del mes en español.

### TC-CLI-196 — A unix timestamp
```bash
bi18nctl datetime chrono-to-unix \
  --value "2026-07-18T00:00:00+00:00" --json
```
**Esperado (PASS):** `"unix"` entero > 0.

### TC-CLI-197 — Año bisiesto (chrono)
```bash
bi18nctl datetime chrono-leap-year \
  --year 2024 --month 2 --day 29 --json
```
**Esperado (PASS):** `"leap"` = true.

### TC-CLI-198 — Parsear fecha naive (sin zona)
```bash
bi18nctl datetime chrono-naive-parse \
  --value "2026-07-18" --format "%Y-%m-%d" --json
```
**Esperado (PASS):** JSON con `"year"` = 2026, `"month"` = 7.

### TC-CLI-199 — Total de timedelta
```bash
bi18nctl datetime chrono-timedelta-total \
  --days 1 --hours 2 --minutes 30 --seconds 0 --unit "seconds" --json
```
**Esperado (PASS):** `"total"` = 95400 (1d + 2.5h en segundos).

---

## §19 Texto y regex (A.08.12)

### TC-CLI-200 — Verificar match de regex
```bash
bi18nctl text regex-match \
  --text "CI-7654321-LP" --pattern "^CI-[0-9]+" --json
```
**Esperado (PASS):** `"matched"` = true.

### TC-CLI-201 — Extraer primer match
```bash
bi18nctl text regex-extract \
  --text "Teléfono: +59171234567" \
  --pattern "\+\d{3}\d{8,9}" --json
```
**Esperado (PASS):** `"match"` = "+59171234567".

### TC-CLI-202 — Extraer todos los matches
```bash
bi18nctl text regex-extract-all \
  --text "a1 b2 c3" --pattern "[a-z][0-9]" --json
```
**Esperado (PASS):** `"matches"` = ["a1", "b2", "c3"].

### TC-CLI-203 — Reemplazar con regex
```bash
bi18nctl text regex-replace \
  --text "hello world" --pattern "world" --replacement "SBOS" --json
```
**Esperado (PASS):** `"result"` = "hello SBOS".

### TC-CLI-204 — Dividir con regex
```bash
bi18nctl text regex-split \
  --text "uno,dos;tres" --pattern "[,;]" --json
```
**Esperado (PASS):** `"parts"` = ["uno", "dos", "tres"].

### TC-CLI-205 — Verificar match en conjunto de patrones
```bash
bi18nctl text regex-match-set \
  --text "usuario@empresa.com" \
  --patterns '^[a-z]+@','\.com$' --json
```
**Esperado (PASS):** `"all_matched"` = true.

---

## §20 Teléfonos (A.08.13)

### TC-CLI-210 — Parsear E.164
```bash
bi18nctl phone parse-e164 --number "+59171234567" --json
```
**Esperado (PASS):** JSON con `"country_code"` = 591.

### TC-CLI-211 — Formatear teléfono
```bash
bi18nctl phone format --number "+59171234567" --format "national" --json
```
**Esperado (PASS):** `"formatted"` en formato nacional boliviano.

### TC-CLI-212 — Tipo de teléfono
```bash
bi18nctl phone type --number "+59171234567" --json
```
**Esperado (PASS):** `"type"` = "MOBILE" o "FIXED_LINE".

### TC-CLI-213 — Es viable
```bash
bi18nctl phone is-viable --number "+59171234567" --json
```
**Esperado (PASS):** `"viable"` = true.

### TC-CLI-214 — Información completa
```bash
bi18nctl phone info --number "+59171234567" --json
```
**Esperado (PASS):** JSON con `"country"` = "BO", `"e164"`, `"type"`.

### TC-CLI-215 — Parsear número nacional
```bash
bi18nctl phone parse-national --number "71234567" --country "BO" --json
```
**Esperado (PASS):** JSON con `"e164"` = "+59171234567".

### TC-CLI-216 — Parsear RFC3966
```bash
bi18nctl phone parse-rfc3966 --number "tel:+59171234567" --json
```
**Esperado (PASS):** JSON con `"e164"` = "+59171234567".

### TC-CLI-217 — Código de país
```bash
bi18nctl phone country-code --number "+59171234567" --json
```
**Esperado (PASS):** `"country_code"` = 591.

---

## §21 Guardas / precondiciones (A.08.14)

### TC-CLI-220 — Verificar bounds
```bash
bi18nctl guard check-bounds --offset 5 --length 3 --total-length 10 --json
```
**Esperado (PASS):** `"ok"` = true (5+3=8 ≤ 10).

### TC-CLI-221 — Verificar índice de elemento
```bash
bi18nctl guard check-element-index --index 4 --size 5 --json
```
**Esperado (PASS):** `"ok"` = true (índice 4 válido en array de 5).

### TC-CLI-222 — Verificar índice de posición
```bash
bi18nctl guard check-position-index --index 5 --size 5 --json
```
**Esperado (PASS):** `"ok"` = true (posición 5 válida para inserción en array de 5).

### TC-CLI-223 — Comparar nombres de valores
```bash
bi18nctl guard num-compare \
  --name1 "inicio" --name2 "fin" --v1 5.0 --json
```
**Esperado (PASS):** `"ok"` con resultado de la comparación.

### TC-CLI-224 — Número positivo
```bash
bi18nctl guard num-positive --name "precio" --value 9.99 --json
```
**Esperado (PASS):** `"ok"` = true.

### TC-CLI-225 — Número no negativo
```bash
bi18nctl guard num-non-negative --name "cantidad" --value 0.0 --json
```
**Esperado (PASS):** `"ok"` = true (0 es no-negativo).

### TC-CLI-226 — Número en rango
```bash
bi18nctl guard num-in-range --name "nota" --value 85.0 --min 0.0 --max 100.0 --json
```
**Esperado (PASS):** `"ok"` = true.

### TC-CLI-227 — String no en blanco
```bash
bi18nctl guard str-non-blank --name "nombre" --value "Juan" --json
```
**Esperado (PASS):** `"ok"` = true.

### TC-CLI-228 — String en rango de longitud
```bash
bi18nctl guard str-length-range --name "clave" --value "abc123" --min 6 --max 20 --json
```
**Esperado (PASS):** `"ok"` = true.

### TC-CLI-229 — String match regex
```bash
bi18nctl guard str-match --name "codigo" --value "ABC-001" --pattern "^[A-Z]+-\d{3}$" --json
```
**Esperado (PASS):** `"ok"` = true.

### TC-CLI-230 — Colección no vacía
```bash
bi18nctl guard col-non-empty --name "roles" --value "admin,usuario" --json
```
**Esperado (PASS):** `"ok"` = true.

### TC-CLI-231 — Colección en rango
```bash
bi18nctl guard col-length-range --name "permisos" --value "read,write" --min 1 --max 5 --json
```
**Esperado (PASS):** `"ok"` = true.

---

## §22 Administración de traducciones (admin protegido)

> Estos tests requieren la contraseña admin. En entorno de prueba usar `--ctx-id` y autenticación preconfigurada.

### TC-CLI-240 — Listar locales disponibles
```bash
bi18nctl admin traducciones list-locales --json
```
**Esperado (PASS):** JSON con `"locales"` array.

### TC-CLI-241 — Listar mensajes de un locale
```bash
bi18nctl admin traducciones list-messages --locale "es-BO" --json
```
**Esperado (PASS):** JSON con `"messages"` array de ids.

### TC-CLI-242 — Obtener un mensaje
```bash
bi18nctl admin traducciones get-message --locale "es-BO" --id "bienvenida" --json
```
**Esperado (PASS):** JSON con `"content"` del mensaje FTL.

### TC-CLI-243 — Actualizar un mensaje (solo en entorno de test)
```bash
bi18nctl admin traducciones update-message \
  --locale "es-BO" --id "bienvenida" --content "Bienvenido al sistema SBOS" --json
```
**Esperado (PASS):** `"ok"` = true, mensaje actualizado en disco.

---

## §23 Administración general

### TC-CLI-250 — Recargar country-rules
```bash
bi18nctl recargar --json
```
**Esperado (PASS):** `"recargado"` = true.

### TC-CLI-251 — Recargar solo traducciones
```bash
bi18nctl recargar-traducciones --json
```
**Esperado (PASS):** `"recargado"` = true, `"mensaje"` contiene "sin interrupción".

---

## §24 Traduciones — paridad de claves (local, sin daemon)

### TC-CLI-260 — Verificar paridad de claves FTL
```bash
bi18nctl translations check-parity \
  --reference "es-BO" --locales-dir "locales" --json
```
**Esperado (PASS):** `"ok"` = true (sin claves faltantes).

### TC-CLI-261 — Paridad con fail-on-missing
```bash
bi18nctl translations check-parity \
  --reference "es-BO" --locales-dir "locales" --fail-on-missing --json
# Si hay claves faltantes:
echo "exit=$?"
```
**Esperado (PASS):** exit=1 si hay claves faltantes, exit=0 si no.

---

## §25 Casos de error esperados

### TC-CLI-E01 — ctx_id ausente (error de protocolo)
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"bi18n.health.check","params":{}}' \
  | socat - UNIX-CONNECT:/run/bos/bi18n.sock
```
**Esperado (PASS):** respuesta con `"error"` código -32602 (ctx_id ausente).

### TC-CLI-E02 — Método inexistente
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"bi18n.inexistente","params":{"ctx_id":"test"}}' \
  | socat - UNIX-CONNECT:/run/bos/bi18n.sock
```
**Esperado (PASS):** `"error"` con mensaje "método no encontrado".

### TC-CLI-E03 — Socket no disponible
```bash
bi18nctl --socket /tmp/no-existe.sock estado; echo "exit=$?"
```
**Esperado (PASS):** exit=2, mensaje de error en stderr.

---

## §26 SDK — `bi18n.validate.field` + `bi18n.mask.pattern` con JSON config

Estos casos prueban los **3 métodos SDK** usando JSON config completo.
La herramienta es `socat` sobre el socket Unix (o `bi18nctl validate`).
Todos los requests incluyen `ctx_id` y el JSON config en el campo `tipo`.

```bash
# Helper compacto para esta sección
sdk_validate() {
  printf '%s' "$1" | socat - UNIX-CONNECT:/run/bos/bi18n.sock
}
sdk_mask() {
  printf '%s' "$1" | socat - UNIX-CONNECT:/run/bos/bi18n.sock
}
CTX="sdk-$(date +%s)"
```

### TC-CLI-200 — validate.field CI Bolivia
```bash
sdk_validate '{"jsonrpc":"2.0","id":200,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"CI","pais":"BO"},"value":"7654321-LP"}}'
```
**Esperado (PASS):** `result.valido: true`, `result.valor_normalizado: "7654321-LP"`.

### TC-CLI-201 — validate.field email válido
```bash
sdk_validate '{"jsonrpc":"2.0","id":201,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"email","requerido":true},"value":"usuario@empresa.com"}}'
```
**Esperado (PASS):** `result.valido: true`.

### TC-CLI-202 — validate.field date con max_fecha relativa
```bash
sdk_validate '{"jsonrpc":"2.0","id":202,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"date","max_fecha":"hoy-18a","msgError":"Debe ser mayor de 18 anios"},"value":"1990-01-01"}}'
```
**Esperado (PASS):** `result.valido: true` (fecha anterior a 18 años atrás).

### TC-CLI-203 — validate.field money fuera de rango
```bash
sdk_validate '{"jsonrpc":"2.0","id":203,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"money","moneda":"BOB","min":0,"max":50000,"msgError":"Monto excede limite"},"value":"75000"}}'
```
**Esperado (PASS):** `result.valido: false`, `result.errores` contiene "Monto excede limite".

### TC-CLI-204 — validate.field warn_max (advertencia)
```bash
sdk_validate '{"jsonrpc":"2.0","id":204,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"money","moneda":"BOB","min":0,"max":500000,"warn_max":40000},"value":"75000"}}'
```
**Esperado (PASS):** `result.valido: true`, `result.metadata.advertencia: true`.

### TC-CLI-205 — validate.field warn_min (advertencia baja)
```bash
sdk_validate '{"jsonrpc":"2.0","id":205,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"number","subtipo":"decimal","warn_min":100},"value":"50"}}'
```
**Esperado (PASS):** `result.valido: true`, `result.metadata.advertencia: true`.

### TC-CLI-206 — validate.field confirmar_valor OK
```bash
sdk_validate '{"jsonrpc":"2.0","id":206,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"email","msgOk":"Coinciden"},"confirmar_valor":"a@b.com","value":"a@b.com"}}'
```
**Esperado (PASS):** `result.valido: true`.

### TC-CLI-207 — validate.field confirmar_valor FAIL
```bash
sdk_validate '{"jsonrpc":"2.0","id":207,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"email","msgError":"No coinciden"},"confirmar_valor":"a@b.com","value":"x@b.com"}}'
```
**Esperado (PASS):** `result.valido: false`, error menciona confirmación.

### TC-CLI-208 — validate.field mayor_que_valor (fechas ISO)
```bash
sdk_validate '{"jsonrpc":"2.0","id":208,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"date","msgError":"Fin debe ser posterior al inicio"},"mayor_que_valor":"2026-01-01","value":"2026-07-18"}}'
```
**Esperado (PASS):** `result.valido: true`.

### TC-CLI-209 — validate.field menor_que_valor FAIL
```bash
sdk_validate '{"jsonrpc":"2.0","id":209,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"number","subtipo":"decimal","msgError":"Debe ser menor"},"menor_que_valor":"100","value":"200"}}'
```
**Esperado (PASS):** `result.valido: false`.

### TC-CLI-210 — validate.field enum inline opciones
```bash
sdk_validate '{"jsonrpc":"2.0","id":210,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"enum","catalogo":"combining_algorithm","opciones":["deny-overrides","permit-overrides","first-applicable"]},"value":"deny-overrides"}}'
```
**Esperado (PASS):** `result.valido: true`, `result.metadata.catalogo: "combining_algorithm"`.

### TC-CLI-211 — validate.field enum inline valor inválido
```bash
sdk_validate '{"jsonrpc":"2.0","id":211,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"enum","catalogo":"combining_algorithm","opciones":["deny-overrides","permit-overrides"]},"value":"INVALIDO"}}'
```
**Esperado (PASS):** `result.valido: false`.

### TC-CLI-212 — validate.field slug válido
```bash
sdk_validate '{"jsonrpc":"2.0","id":212,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"slug"},"value":"mi-rol-comercial"}}'
```
**Esperado (PASS):** `result.valido: true`, `result.valor_normalizado: "mi-rol-comercial"`.

### TC-CLI-213 — validate.field slug inválido (mayúscula)
```bash
sdk_validate '{"jsonrpc":"2.0","id":213,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"slug"},"value":"Mi-Rol"}}'
```
**Esperado (PASS):** `result.valido: false` ó normalizado a minúsculas según implementación.

### TC-CLI-214 — validate.field semver válido
```bash
sdk_validate '{"jsonrpc":"2.0","id":214,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"semver"},"value":"3.0.0"}}'
```
**Esperado (PASS):** `result.valido: true`.

### TC-CLI-215 — validate.field semver inválido
```bash
sdk_validate '{"jsonrpc":"2.0","id":215,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"semver"},"value":"3.0"}}'
```
**Esperado (PASS):** `result.valido: false` (solo 2 segmentos).

### TC-CLI-216 — validate.field cidr válido
```bash
sdk_validate '{"jsonrpc":"2.0","id":216,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"cidr"},"value":"192.168.0.0/24"}}'
```
**Esperado (PASS):** `result.valido: true`.

### TC-CLI-217 — validate.field cidr "any"
```bash
sdk_validate '{"jsonrpc":"2.0","id":217,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"cidr"},"value":"any"}}'
```
**Esperado (PASS):** `result.valido: true`.

### TC-CLI-218 — validate.field uuid válido
```bash
sdk_validate '{"jsonrpc":"2.0","id":218,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"uuid"},"value":"550e8400-e29b-41d4-a716-446655440000"}}'
```
**Esperado (PASS):** `result.valido: true`, `result.metadata.version` presente.

### TC-CLI-219 — validate.field hex 64 bits
```bash
sdk_validate '{"jsonrpc":"2.0","id":219,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"hex","bits":64},"value":"0x00000000003FFFFF"}}'
```
**Esperado (PASS):** `result.valido: true`, `result.valor_normalizado` empieza con `"0x"`.

### TC-CLI-220 — validate.field hex 32 bits
```bash
sdk_validate '{"jsonrpc":"2.0","id":220,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"hex","bits":32},"value":"0x003FFFFF"}}'
```
**Esperado (PASS):** `result.valido: true`.

### TC-CLI-221 — validate.field hex excede ancho
```bash
sdk_validate '{"jsonrpc":"2.0","id":221,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"hex","bits":32},"value":"0x003FFFFFFFFFFFFF"}}'
```
**Esperado (PASS):** `result.valido: false` (demasiados dígitos para 32 bits).

### TC-CLI-222 — validate.field datetime ISO 8601
```bash
sdk_validate '{"jsonrpc":"2.0","id":222,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"datetime"},"value":"2026-07-18T14:30:00Z"}}'
```
**Esperado (PASS):** `result.valido: true`.

### TC-CLI-223 — validate.field json_array
```bash
sdk_validate '{"jsonrpc":"2.0","id":223,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"json_array"},"value":"[\"RGV-001\",\"RGV-002\"]"}}'
```
**Esperado (PASS):** `result.valido: true`, `result.metadata.items: 2`.

### TC-CLI-224 — validate.field role_id válido
```bash
sdk_validate '{"jsonrpc":"2.0","id":224,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"role_id"},"value":"RGV-001"}}'
```
**Esperado (PASS):** `result.valido: true`, `result.valor_normalizado: "RGV-001"`.

### TC-CLI-225 — validate.field role_id inválido
```bash
sdk_validate '{"jsonrpc":"2.0","id":225,"method":"bi18n.validate.field","params":{"ctx_id":"'$CTX'","tipo":{"base":"role_id"},"value":"RGV"}}'
```
**Esperado (PASS):** `result.valido: false` (sin segmento numérico).

### TC-CLI-226 — mask.pattern CI:BO
```bash
sdk_mask '{"jsonrpc":"2.0","id":226,"method":"bi18n.mask.pattern","params":{"ctx_id":"'$CTX'","tipo":{"base":"CI","pais":"BO"}}}'
```
**Esperado (PASS):** `result.motor: "Pattern"`, `result.patron: "0000000-aA"`, `result.usar_mascara: true`.

### TC-CLI-227 — mask.pattern money BOB
```bash
sdk_mask '{"jsonrpc":"2.0","id":227,"method":"bi18n.mask.pattern","params":{"ctx_id":"'$CTX'","tipo":{"base":"money","moneda":"BOB"}}}'
```
**Esperado (PASS):** `result.motor: "Number"`, `result.opciones.scale: 2`, `result.usar_mascara: true`.

### TC-CLI-228 — mask.pattern uuid
```bash
sdk_mask '{"jsonrpc":"2.0","id":228,"method":"bi18n.mask.pattern","params":{"ctx_id":"'$CTX'","tipo":{"base":"uuid"}}}'
```
**Esperado (PASS):** `result.motor: "Pattern"`, `result.patron` contiene `"HHHHHHHH-HHHH"`, `result.usar_mascara: true`.

### TC-CLI-229 — mask.pattern hex 64 bits
```bash
sdk_mask '{"jsonrpc":"2.0","id":229,"method":"bi18n.mask.pattern","params":{"ctx_id":"'$CTX'","tipo":{"base":"hex","bits":64}}}'
```
**Esperado (PASS):** `result.patron` contiene 16 caracteres `H` después de `"0x"`.

### TC-CLI-230 — mask.pattern hex 32 bits
```bash
sdk_mask '{"jsonrpc":"2.0","id":230,"method":"bi18n.mask.pattern","params":{"ctx_id":"'$CTX'","tipo":{"base":"hex","bits":32}}}'
```
**Esperado (PASS):** `result.patron` contiene 8 caracteres `H` después de `"0x"` (no 16).

### TC-CLI-231 — mask.pattern email (sin máscara)
```bash
sdk_mask '{"jsonrpc":"2.0","id":231,"method":"bi18n.mask.pattern","params":{"ctx_id":"'$CTX'","tipo":{"base":"email"}}}'
```
**Esperado (PASS):** `result.usar_mascara: false`, `result.motor: "none"`.

### TC-CLI-232 — format.value fecha larga
```bash
printf '%s' '{"jsonrpc":"2.0","id":232,"method":"bi18n.format.value","params":{"ctx_id":"'$CTX'","formato":"date:long","value":"2026-07-18T00:00:00Z","regional_config":{"locale":"es-BO","timezone":"America/La_Paz","currency":"BOB","country":"BO"}}}' | socat - UNIX-CONNECT:/run/bos/bi18n.sock
```
**Esperado (PASS):** `result.formateado` contiene `"julio"` y `"2026"`.

### TC-CLI-233 — format.value money BOB
```bash
printf '%s' '{"jsonrpc":"2.0","id":233,"method":"bi18n.format.value","params":{"ctx_id":"'$CTX'","formato":"money:BOB","value":"2500.75","regional_config":{"locale":"es-BO","timezone":"America/La_Paz","currency":"BOB","country":"BO"}}}' | socat - UNIX-CONNECT:/run/bos/bi18n.sock
```
**Esperado (PASS):** `result.formateado: "Bs. 2.500,75"` (o equivalente con separadores españoles).
