# Requisitos de Seguridad — SBOS SmartRates

---

## Autenticación — Auth Switch

SmartRates implementa un mecanismo de doble modo de autenticación controlado por una única variable de entorno:

```env
AUTH_DRIVER=sanctum    # Modo desarrollo / standalone
AUTH_DRIVER=keycloak   # Modo producción SBOS
```

### Modo Sanctum (standalone)

- Tokens personales almacenados en tabla `personal_access_tokens`
- El desarrollador crea su token con `php artisan sanctum:create-token`
- Bearer token en header `Authorization: Bearer {token}`
- Sin SSO, sin RBAC complejo — ideal para desarrollo y pruebas
- Rate limiting por token aplicado en middleware Laravel

### Modo Keycloak (producción SBOS)

- OAuth2/OIDC con JWT firmado (RS256) emitido por Keycloak 24
- El JWT llega al middleware después de que Kong lo validó
- Kong inyecta headers SBOS en cada request validado:
  ```
  X-SBOS-CtxId:    ctx-88291-a4f9
  X-SBOS-Tenant:   skull
  X-SBOS-Empresa:  maya
  X-SBOS-User:     3397708
  X-SBOS-BitMask:  0x00000000000A3F21
  ```
- SmartRatesAPI NO valida el JWT directamente — Kong ya lo hizo
- SmartRatesAPI lee los headers inyectados y confía en Kong
- En modo SBOS, los requests que no vienen de Kong son rechazados (NetworkPolicy)

---

## Roles y autorización

### Roles en Keycloak (realm del tenant)

| Rol | Descripción | Quién lo recibe |
|---|---|---|
| `smartrates.admin` | Acceso completo — configuración, sync, audit | Responsable TI, gerente financiero |
| `smartrates.operator` | Operación diaria — confirmar ajuste, ver reportes | Operador financiero, contador |
| `smartrates.readonly` | Solo lectura de cotizaciones y conversión | Vendedores, analistas, usuarios generales |
| `smartrates.api` | Acceso API programático — aplicaciones externas | Service accounts, integraciones |

### Matriz de permisos detallada

| Endpoint | `readonly` | `operator` | `admin` | `api` |
|---|---|---|---|---|
| `GET /rates/*` | ✅ | ✅ | ✅ | ✅ |
| `GET /convert/*` | ✅ | ✅ | ✅ | ✅ |
| `GET /currencies/*` | ✅ | ✅ | ✅ | ✅ |
| `GET /countries/*` | ✅ | ✅ | ✅ | ✅ |
| `GET /company/adjustment/status` | ❌ | ✅ | ✅ | ❌ |
| `POST /company/adjustment/confirm` | ❌ | ✅ | ✅ | ❌ |
| `GET /company/rate-config` | ❌ | ✅ | ✅ | ❌ |
| `PUT /company/rate-config` | ❌ | ❌ | ✅ | ❌ |
| `GET /sync/status` | ❌ | ✅ | ✅ | ❌ |
| `GET /sync/sources` | ❌ | ✅ | ✅ | ❌ |
| `POST /sync/trigger` | ❌ | ❌ | ✅ | ❌ |
| `POST /sync/backfill` | ❌ | ❌ | ✅ | ❌ |
| `GET /metrics` | ❌ | ❌ | ✅ | ❌ |
| `GET /health` | ✅ sin auth | ✅ | ✅ | ✅ |
| `GET /ready` | ✅ sin auth | ✅ | ✅ | ✅ |
| `GET /status` | ❌ | ✅ | ✅ | ❌ |

### Autorización por BitMask SBOS (modo Keycloak)

En modo SBOS, la autorización puede usar el BitMask del JWT además de los roles:

```
Bits 20-29: AppsMask
  Bit 20: SMARTRATES_READ   → acceso de lectura
  Bit 21: SMARTRATES_WRITE  → operaciones (confirmar ajuste, etc.)
  Bit 22: SMARTRATES_ADMIN  → configuración y administración
```

Si el BitMask no contiene el bit requerido, la respuesta es `403` con `ctx_id` en el body para trazabilidad.

---

## Rate Limiting

### Por token (plan del cliente)

```php
'token' => [
    'basic'      => '1000 per hour',
    'standard'   => '5000 per hour',
    'enterprise' => '50000 per hour',
]
```

### Por IP (endpoints sin autenticación)

```php
'ip' => [
    'health_endpoints' => '60 per minute',
    'docs_endpoint'    => '30 per minute',
    'public_rates'     => '100 per hour',  // ticker y explorador público
]
```

### Respuesta al exceder el límite

```http
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1748044800
Retry-After: 3600
Content-Type: application/json

{
  "error_code": "SR-429",
  "error_type": "rate_limit_exceeded",
  "message": "Has excedido el límite de 1.000 requests por hora.",
  "retry_after": "2026-05-23T08:00:00Z",
  "documentation_url": "https://smartrates.bo/docs/errors/SR-429",
  "ctx_id": ""
}
```

---

## Headers de seguridad HTTP

Todos los responses incluyen:

```http
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
Content-Security-Policy: default-src 'none'; frame-ancestors 'none'
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

Eliminados:
```
X-Powered-By  (no revelar PHP)
Server        (no revelar Nginx/Apache)
```

---

## CORS Policy

```php
return [
    'paths'               => ['api/*'],
    'allowed_methods'     => ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    'allowed_origins'     => env('CORS_ALLOWED_ORIGINS', 'https://smartrates.bo'),
    'allowed_headers'     => ['Content-Type', 'Authorization', 'X-Request-ID'],
    'exposed_headers'     => [
        'X-RateLimit-Limit',
        'X-RateLimit-Remaining',
        'X-RateLimit-Reset',
        'X-Request-ID',
    ],
    'max_age'             => 3600,
    'supports_credentials' => false,
];
```

En modo SBOS, `CORS_ALLOWED_ORIGINS` se configura con el dominio del tenant. En desarrollo, `*`.

---

## HTTPS

- Todo el tráfico es HTTPS en producción. HTTP devuelve 301 → HTTPS.
- TLS 1.2 mínimo, TLS 1.3 preferido.
- En modo SBOS, Linkerd inyecta mTLS automáticamente entre servicios.
- `Strict-Transport-Security` con preload — el browser nunca intenta HTTP.

---

## Gestión de credenciales

### Modo desarrollo (standalone)

```bash
# Solo en .env.local — en .gitignore obligatorio
IMF_API_KEY=c2800287220f4bc18e147ad8dba321ab
DB_PASSWORD=...
REDIS_PASSWORD=...
KEYCLOAK_CLIENT_SECRET=...
```

El repositorio solo contiene `.env.example` con valores vacíos. Nunca credenciales reales en git.

### Modo producción SBOS

Todas las credenciales viven en Vault. El pod las recibe como variables de entorno inyectadas al inicio:

```yaml
# manifest.yml — vault_paths
vault_paths:
  - "secret/tenants/{realm}/smartrates/db"
  - "secret/tenants/{realm}/smartrates/redis"
  - "secret/tenants/{realm}/smartrates/keycloak"
  - "secret/tenants/{realm}/smartrates/imf-api-key"
  - "secret/tenants/{realm}/smartrates/bcb-config"
```

### API Key FMI

```
Key:  c2800287220f4bc18e147ad8dba321ab
Header: Ocp-Apim-Subscription-Key
TTL: sin expiración documentada — rotar anualmente
Runbook de rotación: SBOS-MANUAL §16 — Runbook: rotar key FMI
```

---

## Auditoría

Cada request autenticado genera un registro en `security.audit_log`:

```json
{
  "id": "0193f8a1-...",
  "ctx_id": "ctx-88291-a4f9",
  "request_id": "req_f7a8b9c0d1e2",
  "user_id": "3397708",
  "endpoint": "POST /api/v1/company/adjustment/confirm",
  "method": "POST",
  "ip_address": "192.168.1.50",
  "request_params": {"currency_code": "BOB", "adjustment_value": 0.50},
  "response_code": 200,
  "response_ms": 47,
  "created_at": "2026-05-23T09:15:22.847Z"
}
```

**Retención del audit_log:** 90 días (rolling — particiones trimestrales)  
**Acceso al audit_log:** solo rol `smartrates.admin`  
**ctx_id en audit_log:** en modo SBOS, permite cruzar con `bkernel_db.audit_events` para trazabilidad completa del ecosistema

---

## Datos sensibles y privacidad

SmartRates procesa principalmente **datos de tipos de cambio (no personales)**. Sin embargo:

- El `audit_log` registra IPs y user_ids → pueden considerarse datos personales bajo RGPD/Ley boliviana
- Política de retención del audit_log: 90 días rolling
- Los datos de tipos de cambio en sí son datos públicos — no hay PII en `rates.exchange_rates`
- La API key del FMI es confidencial — no se loguea ni se expone en responses

---

## Cumplimiento normativo Bolivia

- **Retención de datos financieros:** 10 años mínimo según normativa contable boliviana (Decreto Supremo 25977)
- **Datos BCB:** uso permitido — dato público según BCB. Redistribución con atribución
- **FMI SDMX:** uso comercial permitido, redistribución con atribución al FMI
- **fawazahmed0:** licencia MIT — uso comercial y redistribución permitidos con atribución
- **Frankfurter:** licencia MIT — ídem

---

## Catálogo de errores SR-XXX

| Código | HTTP | Nombre | Cuándo ocurre |
|---|---|---|---|
| SR-400 | 400 | bad_request | Parámetros malformados |
| SR-401 | 401 | unauthorized | Sin token o token inválido |
| SR-403 | 403 | forbidden | Token válido pero sin permiso |
| SR-404 | 404 | not_found | Moneda, país o fecha no existe |
| SR-422 | 422 | validation_error | Fecha futura, rango > 365 días, etc. |
| SR-429 | 429 | rate_limit_exceeded | Superado el rate limit |
| SR-503 | 503 | service_unavailable | BD o Redis no disponible |
| SR-504 | 504 | source_timeout | Fuente externa no responde |
| SR-1001 | 422 | invalid_currency_code | Código de moneda no reconocido |
| SR-1002 | 422 | invalid_date_format | Fecha en formato incorrecto |
| SR-1003 | 404 | rate_not_available | Sin dato para esa fecha y moneda |
| SR-1004 | 409 | adjustment_already_confirmed | El ajuste del día ya fue confirmado |
| SR-1005 | 503 | sync_source_circuit_open | Circuit breaker abierto para esa fuente |

**Formato estándar RFC 9457:**
```json
{
  "error_code": "SR-1001",
  "error_type": "invalid_currency_code",
  "message": "El código 'XYZ' no es un código ISO 4217 válido.",
  "invalid_field": "from",
  "documentation_url": "https://smartrates.bo/docs/errors/SR-1001",
  "ctx_id": "ctx-88291-a4f9"
}
```

---

## Sanitización de inputs

- Todos los códigos de moneda y país son normalizados a mayúsculas y validados contra el catálogo
- Las fechas son validadas y convertidas a `DATE` de PostgreSQL — nunca interpoladas en SQL
- Los montos NUMERIC son validados (positivos, < 10^20) antes de pasarse a `catalog.RATE()`
- Ningún parámetro se interpola directamente en SQL — se usan bindings preparados
- El parámetro `currencies` del Ticker se valida contra el catálogo antes de cualquier query

---
_SKULL · SBOS · SmartRates · 008-SEGURIDAD · v1.0 · 2026-05-23_

---

## Nuevo rol: smartrates.global_operator (post-simulación v3)

```
smartrates.global_operator
  → Confirma el ajuste global del SBOS para el tenant completo
  → Es el nivel base: todas las empresas sin ajuste propio heredan su confirmación
  → Generalmente: el responsable financiero del SBOS o del holding
  → Endpoints exclusivos:
      POST /api/v1/sbos/adjustment/global/confirm
      GET  /api/v1/sbos/adjustment/global/status
      GET  /api/v1/sbos/adjustment/global/history
```

| Rol | Alcance del ajuste | Quién es |
|---|---|---|
| `smartrates.global_operator` | Ajuste global — todo el tenant | Responsable financiero del SBOS/holding |
| `smartrates.admin` | Configuración total de empresa | Gerente TI, gerente financiero de la empresa |
| `smartrates.operator` | Ajuste de SU empresa (sobrescribe global) | Operador/contador de la empresa |
| `smartrates.readonly` | Solo lectura | Cualquier usuario de la empresa |
| `smartrates.api` | Service account | Integraciones, Tryton, SmartTax |

