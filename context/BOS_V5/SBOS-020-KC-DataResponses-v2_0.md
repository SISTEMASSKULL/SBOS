# SBOS-020 — Qué datos guarda Keycloak y qué devuelve
## Almacenamiento interno, respuesta autenticada y respuesta no autenticada

**SKULL · SBOS — Sovereign Business Operating System**
**v2.0 · Marzo 2026 — Basado en Keycloak 26.x**

---

**Código:** SBOS-020
**Versión:** 2.0
**Estado:** ACTIVO
**Reemplaza a:** SBOS-017-KC-DATA-RESPONSES v1.0 (SUPERSEDED)
**Clasificación:** Especificación Técnica — Gobierno de Identidad (SBOS-003)

---

## PARTE 1 — Qué datos guarda Keycloak en su base de datos

Keycloak usa PostgreSQL como su base de datos. Todo vive en tablas con prefijos claros. Estas son las tablas relevantes para el SBOS:

---

### Tabla `USER_ENTITY` — El registro central del usuario

Esta es la tabla principal. Una fila por usuario.

```sql
USER_ENTITY (
  ID                    VARCHAR(36)   -- UUID del usuario, la clave de todo
  EMAIL                 VARCHAR(255)  -- email (puede ser el username)
  EMAIL_CONSTRAINT      VARCHAR(255)  -- para garantizar unicidad del email
  EMAIL_VERIFIED        BOOLEAN       -- si el email fue verificado
  ENABLED               BOOLEAN       -- si la cuenta está activa
  FEDERATION_LINK       VARCHAR(255)  -- link al IdP externo si vino de LDAP/AD
  FIRST_NAME            VARCHAR(255)  -- nombre
  LAST_NAME             VARCHAR(255)  -- apellido
  REALM_ID              VARCHAR(255)  -- a qué realm pertenece
  USERNAME              VARCHAR(255)  -- username único dentro del realm
  CREATED_TIMESTAMP     BIGINT        -- timestamp de creación (milisegundos)
  SERVICE_ACCOUNT_CLIENT_LINK VARCHAR(36) -- si es service account
  NOT_BEFORE            INT           -- tokens emitidos antes de esta fecha no válidos
)
```

**Lo que Keycloak guarda en `USER_ENTITY` sobre un usuario humano:**

| Campo | Ejemplo |
|---|---|
| ID | `550e8400-e29b-41d4-a716-446655440000` |
| USERNAME | `maria.garcia` |
| EMAIL | `maria.garcia@acme.com` |
| FIRST_NAME | `Maria` |
| LAST_NAME | `García` |
| EMAIL_VERIFIED | `true` |
| ENABLED | `true` |
| REALM_ID | `bos-main` |
| CREATED_TIMESTAMP | `1741430000000` |
| NOT_BEFORE | `0` |

**Nada más.** Keycloak no guarda teléfono, dirección, cargo, departamento, fecha de nacimiento, ni ningún otro dato personal en `USER_ENTITY`. Todo eso va en `USER_ATTRIBUTE`.

---

### Tabla `USER_ATTRIBUTE` — Todos los atributos extra

Una fila por atributo por usuario.

```sql
USER_ATTRIBUTE (
  ID           VARCHAR(36)    -- UUID de esta fila
  NAME         VARCHAR(255)   -- nombre del atributo (clave)
  VALUE        VARCHAR(255)   -- valor (hasta 255 chars)
  USER_ID      VARCHAR(36)    -- FK a USER_ENTITY.ID
  LONG_VALUE   TEXT           -- valor largo (KC 24+ — sin límite de chars)
  LONG_VALUE_HASH VARCHAR(64) -- hash del LONG_VALUE para búsquedas
  LONG_VALUE_HASH_LOWER_CASE VARCHAR(64)
)
```

Los atributos `bos_*` del SBOS van aquí. Con KC 26.x los valores largos (JSON complejos) se almacenan automáticamente en `LONG_VALUE` — sin límite de tamaño.

---

### Tabla `CREDENTIAL` — Las credenciales del usuario

Una fila por credencial. Un usuario puede tener múltiples credenciales:

```sql
CREDENTIAL (
  ID             VARCHAR(36)     -- UUID
  SALT           BYTES           -- salt del hash
  TYPE           VARCHAR(255)    -- tipo: password, otp, webauthn
  USER_ID        VARCHAR(36)     -- FK a USER_ENTITY
  CREATED_DATE   BIGINT          -- cuándo se creó
  USER_LABEL     VARCHAR(255)    -- etiqueta legible: "Mi YubiKey", "iPhone"
  SECRET_DATA    TEXT            -- datos secretos en JSON (el hash, el secreto OTP)
  CREDENTIAL_DATA TEXT           -- configuración en JSON (algoritmo, contador)
  PRIORITY       INT             -- orden de preferencia
)
```

**Por tipo de credencial, qué guarda exactamente:**

**Password:**
```json
SECRET_DATA:    { "value": "$bcrypt$12$...", "salt": "base64..." }
CREDENTIAL_DATA:{ "hashIterations": 27500, "algorithm": "bcrypt" }
```

**TOTP / OTP:**
```json
SECRET_DATA:    { "value": "JBSWY3DPEHPK3PXP" }
CREDENTIAL_DATA:{ "subType": "totp", "digits": 6,
                  "counter": 0, "period": 30,
                  "algorithm": "HmacSHA1" }
```

**WebAuthn (biométrico y hardware keys):**
```json
SECRET_DATA:    { "publicKey": "base64...",
                  "privateKey": null }
CREDENTIAL_DATA:{ "credentialId": "base64...",
                  "counter": 47,
                  "aaguid": "uuid-del-fabricante",
                  "attestationStatement": "...",
                  "userVerification": "required",
                  "rpId": "bos.acme.com",
                  "origin": "https://bos.acme.com" }
```

**Keycloak NUNCA almacena:**
- La contraseña en claro — solo el hash
- La clave privada del WebAuthn — nunca sale del dispositivo del usuario
- Los datos biométricos — nunca llegan a Keycloak
- El PIN del smart card — es del chip del usuario

---

### Tabla `USER_ROLE_MAPPING` — Qué roles tiene el usuario

```sql
USER_ROLE_MAPPING (
  ROLE_ID  VARCHAR(36)  -- FK a KEYCLOAK_ROLE
  USER_ID  VARCHAR(36)  -- FK a USER_ENTITY
)
```

Tabla de relación muchos-a-muchos. María tiene dos filas: `bos-cajero` → `maria-uuid` y `bos-cajero-pagos` → `maria-uuid`.

---

### Tabla `USER_GROUP_MEMBERSHIP` — A qué grupos pertenece

```sql
USER_GROUP_MEMBERSHIP (
  GROUP_ID  VARCHAR(36)  -- FK a KEYCLOAK_GROUP
  USER_ID   VARCHAR(36)  -- FK a USER_ENTITY
)
```

---

### Tabla `KEYCLOAK_ROLE` — Los roles del realm

```sql
KEYCLOAK_ROLE (
  ID           VARCHAR(36)    -- UUID del rol
  CLIENT_REALM_CONSTRAINT VARCHAR(255)
  CLIENT_ROLE  BOOLEAN        -- si es rol de client (false = realm role)
  DESCRIPTION  VARCHAR(255)
  NAME         VARCHAR(255)   -- el nombre: "bos-cajero"
  REALM_ID     VARCHAR(36)
  CLIENT       VARCHAR(36)    -- si es client role
  REALM        VARCHAR(36)
)
```

Los atributos del rol (los `bos_la_*`, `bos_ft_*`, etc.) van en:

```sql
ROLE_ATTRIBUTE (
  ID       VARCHAR(36)
  ROLE_ID  VARCHAR(36)   -- FK a KEYCLOAK_ROLE
  NAME     VARCHAR(255)  -- nombre del atributo
  VALUE    VARCHAR(255)  -- valor (mismo mecanismo que USER_ATTRIBUTE)
)
```

---

### Tabla `USER_SESSION` — Las sesiones activas

```sql
USER_SESSION (
  ID           VARCHAR(36)   -- UUID de la sesión (= session_state en el JWT)
  AUTH_METHOD  VARCHAR(255)  -- qué método de autenticación se usó
  IP_ADDRESS   VARCHAR(255)  -- IP del usuario en el login
  LAST_SESSION_REFRESH INT
  LOGIN_USERNAME VARCHAR(255)
  REALM_ID     VARCHAR(36)
  REMEMBER_ME  BOOLEAN
  STARTED      INT           -- timestamp del inicio de sesión
  USER_ID      VARCHAR(36)   -- FK a USER_ENTITY
  USER_SESSION_STATE INT
  BROKER_SESSION_ID VARCHAR(255)
  BROKER_USER_ID    VARCHAR(255)
)
```

Las sesiones activas viven en memoria (Infinispan cache) y se persisten en la BD para sobrevivir reinicios.

---

### Otras tablas relevantes

| Tabla | Qué guarda |
|---|---|
| `KEYCLOAK_GROUP` | Definición de grupos con jerarquía |
| `GROUP_ATTRIBUTE` | Atributos de grupos (`bos_shift`, `bos_location`, etc.) |
| `GROUP_ROLE_MAPPING` | Qué roles tiene cada grupo |
| `OFFLINE_USER_SESSION` | Sesiones de refresh token de larga duración |
| `ADMIN_EVENT_ENTITY` | Auditoría de acciones administrativas |
| `EVENT_ENTITY` | Eventos de usuario (logins, logouts, errores) |
| `RESOURCE_SERVER` | Clientes con Authorization Services habilitado |
| `RESOURCE_SERVER_RESOURCE` | Recursos protegidos (`urn:sbos:tryton:pago`) |
| `RESOURCE_SERVER_POLICY` | Políticas de autorización |
| `RESOURCE_SERVER_PERM_TICKET` | Permisos otorgados (UMA tickets) |
| `AUTHENTICATOR_CONFIG` | Configuraciones de los Authentication Flows |
| `AUTHENTICATION_FLOW` | Definición de los flows de autenticación |
| `AUTHENTICATION_EXECUTION` | Pasos de cada flow |

---

## PARTE 2 — Qué devuelve Keycloak cuando el usuario ESTÁ autenticado

Cuando un usuario se autentica exitosamente, Keycloak devuelve tres tokens y opcionalmente responde al endpoint `/userinfo`.

---

### 2.1 La respuesta al token endpoint (login exitoso)

```
POST /realms/bos-main/protocol/openid-connect/token
```

**Respuesta HTTP 200:**

```json
{
  "access_token":       "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IlhxM...",
  "expires_in":         300,
  "refresh_expires_in": 1800,
  "refresh_token":      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IjIxY...",
  "token_type":         "Bearer",
  "id_token":           "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IlhxM...",
  "not-before-policy":  0,
  "session_state":      "f8530352-29b3-47f0-bfb5-914bc8b6536e",
  "scope":              "openid email profile"
}
```

---

### 2.2 El Access Token decodificado — Payload completo

Este es el JWT que las apps del SBOS reciben y usan en cada request. Keycloak agrega claims no estándar como `preferred_username`, `realm_access` y `resource_access` además de los claims estándar de OpenID Connect.

```json
{
  // ── CLAIMS ESTÁNDAR OAuth2/OIDC ──────────────────────────────────
  "exp":           1741430300,
  "iat":           1741430000,
  "jti":           "24690fd3-bf00-450f-8937-1893cea8bf8a",
  "iss":           "https://bos.acme.com/realms/bos-main",
  "aud":           "bos-apps",
  "sub":           "550e8400-e29b-41d4-a716-446655440000",
  "typ":           "Bearer",

  // ── CLAIMS KEYCLOAK PROPIOS ───────────────────────────────────────
  "azp":           "bos-frontend",
  "session_state": "f8530352-29b3-47f0-bfb5-914bc8b6536e",
  "acr":           "1",            // "1" = auth normal, "2" = step-up

  // ── CLAIMS DE IDENTIDAD (scope: profile) ─────────────────────────
  "preferred_username": "maria.garcia",
  "given_name":         "Maria",
  "family_name":        "García",
  "name":               "Maria García",

  // ── CLAIMS DE EMAIL (scope: email) ───────────────────────────────
  "email":          "maria.garcia@acme.com",
  "email_verified": true,

  // ── CLAIMS DE ROLES (configurados con Protocol Mappers) ───────────
  "realm_access": {
    "roles": [
      "bos-cajero",
      "bos-cajero-pagos",
      "offline_access",
      "uma_authorization"
    ]
  },
  "resource_access": {
    "bos-frontend": {
      "roles": ["bos-frontend-user"]
    },
    "account": {
      "roles": ["manage-account", "view-profile"]
    }
  },

  // ── CLAIMS DE GRUPOS ─────────────────────────────────────────────
  "groups": ["/sbos/acme/finanzas/caja-pagos"],

  // ── CLAIMS SBOS CUSTOM (via Protocol Mappers) ───────────────────
  // Solo aparecen si el Protocol Mapper está configurado
  // No vienen por defecto — el bridge los registra al instalar el realm

  "bos_perm_base":  11,
  "bos_perm_ui":    127,
  "bos_perm_vdi":   161,

  "bos_auth_type":   "NORMAL",
  "bos_auth_domain": "logical",
  "bos_auth_level":  "standard",
  "bos_score":       "94.5",

  "bos_language":    "es",
  "bos_theme":       "dark",

  "bos_vdi": {
    "apps":     ["tryton-caja", "tryton-pagos", "rocketchat"],
    "internet": "restricted",
    "print":    true,
    "usb":      false,
    "template": "bos-cajero-pagos-desktop"
  },

  // ── CLAIMS DE ORGANIZACIÓN (KC 26 Organizations) ──────────────────
  "organization": {
    "acme-corp": {}
  },

  // ── CLAIMS CONTEXTUALES DEL LOGIN ────────────────────────────────
  "allowed-origins": ["https://app.bos.acme.com"],
  "scope":           "openid email profile bos",
  "sid":             "f8530352-29b3-47f0-bfb5-914bc8b6536e"
}
```

---

### 2.3 El ID Token — Para el cliente, no para las APIs

El ID Token prueba quién es el usuario al client (el navegador/app). No debe enviarse a APIs de backend — ese es el trabajo del Access Token.

```json
{
  "exp":   1741430300,
  "iat":   1741430000,
  "jti":   "id-token-uuid",
  "iss":   "https://bos.acme.com/realms/bos-main",
  "aud":   "bos-frontend",
  "sub":   "550e8400-e29b-41d4-a716-446655440000",
  "typ":   "ID",

  "auth_time":    1741430000,
  "at_hash":      "hash-del-access-token",
  "acr":          "1",
  "session_state":"f8530352-29b3-47f0-bfb5-914bc8b6536e",

  "preferred_username": "maria.garcia",
  "given_name":         "Maria",
  "family_name":        "García",
  "name":               "Maria García",
  "email":              "maria.garcia@acme.com",
  "email_verified":     true
}
```

---

### 2.4 El Refresh Token — Para renovar la sesión

El Refresh Token es opaco para las apps. Solo lo usa el cliente para pedir un nuevo Access Token cuando el actual expira. Nunca debe enviarse a APIs. Tiene lifespan más largo (default 30 minutos, configurable por realm). Keycloak lo guarda en `OFFLINE_USER_SESSION` si es `offline_access`.

---

### 2.5 El endpoint `/userinfo` — Datos del usuario en tiempo real

```
GET /realms/bos-main/protocol/openid-connect/userinfo
Authorization: Bearer {access_token}
```

Devuelve los datos actuales del usuario desde la BD, no los del JWT:

```json
{
  "sub":                "550e8400-e29b-41d4-a716-446655440000",
  "name":               "Maria García",
  "given_name":         "Maria",
  "family_name":        "García",
  "preferred_username": "maria.garcia",
  "email":              "maria.garcia@acme.com",
  "email_verified":     true,

  // Claims custom con userinfo.token.claim = true en el mapper
  "bos_perm_base":  11,
  "bos_language":   "es",
  "groups":         ["/sbos/acme/finanzas/caja-pagos"]
}
```

**Diferencia clave JWT vs /userinfo:**

| | JWT (Access Token) | /userinfo |
|---|---|---|
| Origen | Datos al momento del login | Datos actuales en la BD |
| Frescura | Snapshot del login | Tiempo real |
| Latencia | 0ms (local) | ~50ms (llamada HTTP) |
| Cuándo usarlo | Cada request de API | Cuando los datos del usuario cambiaron post-login |

---

### 2.6 El endpoint `/token/introspect` — Validar un token en el servidor

```
POST /realms/bos-main/protocol/openid-connect/token/introspect
Authorization: Basic {client_credentials}
token: {access_token}
```

Útil para APIs que no pueden verificar la firma JWT localmente. Keycloak verifica si el token es válido, activo, y no fue revocado:

```json
{
  "active":    true,
  "sub":       "550e8400-e29b-41d4-a716-446655440000",
  "username":  "maria.garcia",
  "email":     "maria.garcia@acme.com",
  "exp":       1741430300,
  "iat":       1741430000,
  "iss":       "https://bos.acme.com/realms/bos-main",
  "aud":       "bos-apps",
  "realm_access": { "roles": ["bos-cajero", "bos-cajero-pagos"] },
  "client_id": "bos-frontend",
  "token_type":"Bearer",
  "scope":     "openid email profile bos"
}
```

Si el token es inválido o expirado: `{ "active": false }`

---

## PARTE 3 — Qué devuelve Keycloak cuando el usuario NO está autenticado

Esta parte es crítica para el SBOS. Hay distintos escenarios de "no autenticado" y cada uno produce una respuesta diferente.

---

### 3.1 Credenciales incorrectas en el login

```
POST /realms/bos-main/protocol/openid-connect/token
  username=maria.garcia
  password=contraseña_incorrecta
  grant_type=password
  client_id=bos-frontend
  client_secret=...
```

**HTTP 401 — Respuesta:**
```json
{
  "error":             "invalid_grant",
  "error_description": "Invalid user credentials"
}
```

Después de N intentos fallidos (configurable en Realm — Brute Force Protection):
```json
{
  "error":             "invalid_grant",
  "error_description": "Account temporarily disabled"
}
```

---

### 3.2 Token expirado en una llamada a la API

Keycloak no intercepta esto directamente — es la app o el API Gateway (Kong) quien verifica la firma y la expiración. La app responde:

```
HTTP 401 Unauthorized
WWW-Authenticate: Bearer realm="bos-main",
                  error="invalid_token",
                  error_description="The access token expired"
```

El cliente debe usar el Refresh Token para obtener un nuevo Access Token:

```
POST /realms/bos-main/protocol/openid-connect/token
  grant_type=refresh_token
  refresh_token={refresh_token}
  client_id=bos-frontend
```

Si el Refresh Token también expiró — el usuario debe hacer login de nuevo.

---

### 3.3 Token revocado (logout o sesión terminada por admin)

Si el admin termina la sesión, o el usuario hace logout, en introspección:

```json
{
  "active": false
}
```

En el JWT localmente: el token parecería válido hasta su `exp` — por eso las APIs críticas del SBOS usan introspección en tiempo real, no solo verificación local de la firma.

---

### 3.4 Usuario deshabilitado

Si el admin deshabilita la cuenta (`ENABLED = false`):

```json
{
  "error":             "invalid_grant",
  "error_description": "Account disabled"
}
```

---

### 3.5 Token con firma inválida (tampering)

```
HTTP 401 Unauthorized
{
  "error":             "invalid_token",
  "error_description": "Token signature verification failed"
}
```

---

### 3.6 Sesión expirada en el browser (SSO)

Cuando el usuario navega a una app y no tiene sesión activa, Keycloak redirige al login. NO hay respuesta JSON — es una redirección HTTP:

```
HTTP 302 Found
Location: https://bos.acme.com/realms/bos-main/protocol/openid-connect/auth
  ?client_id=bos-frontend
  &redirect_uri=https://app.bos.acme.com/callback
  &response_type=code
  &scope=openid+email+profile+bos
  &state=random-csrf-token
```

El usuario ve la pantalla de login de Keycloak.

---

### 3.7 Falta de permisos (token válido pero sin autorización)

Keycloak emitió el token correctamente. El usuario está autenticado. Pero intentó acceder a un recurso para el que no tiene permiso. **Esta respuesta NO la da Keycloak — la da la app o Kong:**

```
HTTP 403 Forbidden
{
  "error":   "access_denied",
  "message": "Insufficient permissions for this resource"
}
```

**La diferencia crítica:**
- `401 Unauthorized` → no está autenticado (no hay token, token inválido/expirado)
- `403 Forbidden` → está autenticado pero no tiene permiso

---

## PARTE 4 — El mapa completo: qué dato, dónde vive, qué endpoint lo devuelve

```
DATO                        DÓNDE VIVE EN KC         CUÁNDO LO DEVUELVE
─────────────────────────────────────────────────────────────────────────
UUID del usuario            USER_ENTITY.ID           JWT: sub
Username                    USER_ENTITY.USERNAME     JWT: preferred_username
Email                       USER_ENTITY.EMAIL        JWT: email (scope email)
Nombre                      USER_ENTITY.FIRST_NAME   JWT: given_name (scope profile)
Apellido                    USER_ENTITY.LAST_NAME    JWT: family_name (scope profile)
Roles del realm             USER_ROLE_MAPPING        JWT: realm_access.roles
Roles del client            USER_ROLE_MAPPING        JWT: resource_access.{client}.roles
Grupos                      USER_GROUP_MEMBERSHIP    JWT: groups (si hay mapper)
Atributos custom (bos_*)    USER_ATTRIBUTE           JWT: solo si hay Protocol Mapper
Hash de contraseña          CREDENTIAL.SECRET_DATA   Nunca — uso interno de KC
Secreto TOTP                CREDENTIAL.SECRET_DATA   Nunca — uso interno de KC
Clave pública WebAuthn      CREDENTIAL.SECRET_DATA   Nunca — uso interno de KC
Sesión activa               USER_SESSION             JWT: session_state
Tiempo de expiración        Calculado por KC         JWT: exp
Nivel de autenticación      Evaluado en el flow      JWT: acr
Métodos de auth del rol     ROLE_ATTRIBUTE           JWT: solo si hay mapper del atributo
```

---

## PARTE 5 — Lo que el SBOS necesita saber sobre estos datos

### Lo que el SBOS SÍ puede leer de Keycloak:

```
✓ JWT claims directamente en la app (sin llamada HTTP)
  → sub, roles, grupos, atributos custom mapeados, exp, acr

✓ /userinfo (llamada HTTP a Keycloak)
  → Cuando necesitas datos frescos del usuario (cambios de atributo post-login)

✓ /token/introspect (llamada HTTP a Keycloak)
  → Cuando necesitas verificar si el token fue revocado en tiempo real

✓ Admin REST API (con credenciales de admin)
  → Para gestión: crear/editar usuarios, asignar roles, leer atributos
  → El bridge del SBOS usa exclusivamente esta API
```

### Lo que el SBOS NUNCA puede leer de Keycloak:

```
✗ El hash de la contraseña del usuario (inaccesible por diseño)
✗ El secreto TOTP del usuario (inaccesible por diseño)
✗ La clave privada WebAuthn (nunca llega a Keycloak)
✗ Los datos biométricos (nunca llegan a Keycloak)
✗ El PIN del smart card (nunca llega a Keycloak)
```

### Los tres escenarios de respuesta resumidos:

```
AUTENTICADO CORRECTAMENTE:
  → HTTP 200
  → access_token (JWT firmado, 5 min)
  → refresh_token (opaco, 30 min)
  → id_token (JWT, solo para el client)
  → session_state (UUID de la sesión activa)

NO AUTENTICADO (credenciales incorrectas):
  → HTTP 401
  → { "error": "invalid_grant", "error_description": "..." }
  → Después de N intentos: cuenta bloqueada temporalmente

TOKEN INVÁLIDO/EXPIRADO EN UNA API:
  → HTTP 401 (la app/Kong lo detecta)
  → WWW-Authenticate header con el motivo
  → El client usa el refresh_token para renovar, o redirige al login
```

---

*SKULL · SBOS · SBOS-020-KC-DATA-RESPONSES · v2.0 · Marzo 2026*
*Reemplaza: SBOS-017-KC-DATA-RESPONSES v1.0 — SUPERSEDED*
