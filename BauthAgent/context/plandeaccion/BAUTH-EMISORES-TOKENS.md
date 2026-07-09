# BAUTH-EMISORES-TOKENS.md — Quién Emite los Tokens de Autorización

**Versión:** 1.0 · **Fecha:** 2026-06-25
**Pregunta:** ¿Quién emite los tokens de autorización en el ecosistema SBOS?

---

## RESPUESTA DIRECTA

| Token | ¿Quién lo emite? | ¿Quién lo valida? | ¿Quién lo configura? |
|-------|:---:|:---:|:---:|
| **Access Token (JWT)** | **Keycloak** | Kong, Tryton, bhnexus | bAuth (claims, TTL, scopes) |
| **Refresh Token** | **Keycloak** | Keycloak | bAuth (TTL, rotation policy) |
| **ID Token (OIDC)** | **Keycloak** | App cliente (verifica firma) | bAuth (claims incluidos) |
| **ctx_id** | **bAuth** | bAuth, bhnexus, Kong | bAuth (TTL, scope, 6 capas) |
| **dctx_id** | **bAuth** | bAuth (pre-autenticación) | bAuth (TTL 30min renovable) |
| **Token para app externa** | **Keycloak** | App externa (OIDC/SAML) | bAuth (idp_client + idp_token_config) |
| **M2M Token (Client Credentials)** | **Keycloak** | Daemon receptor (mTLS) | bAuth (idp_client) |
| **QR Challenge** | **bAuth** | bAuth (anti-replay) | bAuth (TTL 120s, HMAC-SHA256) |

---

## 1. KEYCLOAK — ÚNICO EMISOR DE JWT

Keycloak es el **único** emisor de JSON Web Tokens en el ecosistema SBOS.
Nadie más emite access_token, refresh_token ni id_token.

```
┌──────────────────────────────────────────────────────────────┐
│                      KEYCLOAK                                │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              TOKEN ENDPOINT                           │   │
│  │                                                       │   │
│  │  POST /realms/{realm}/protocol/openid-connect/token   │   │
│  │                                                       │   │
│  │  Entrada:  grant_type, client_id, credential          │   │
│  │  Salida:   {                                           │   │
│  │    "access_token":  "eyJhbGciOiJFZERTQSJ9...",         │   │
│  │    "refresh_token": "eyJhbGciOiJFZERTQSJ9...",         │   │
│  │    "id_token":      "eyJhbGciOiJFZERTQSJ9...",         │   │
│  │    "token_type":    "Bearer",                           │   │
│  │    "expires_in":    3600                                │   │
│  │  }                                                      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           ¿QUÉ CONTIENE EL JWT?                       │   │
│  │                                                       │   │
│  │  {                                                    │   │
│  │    "iss": "https://auth.sbos.app/realms/acme",        │   │
│  │    "sub": "uuid-maria-garcia",                         │   │
│  │    "aud": "tryton",                                    │   │
│  │    "exp": 1712345678,                                  │   │
│  │    "iat": 1712342078,                                  │   │
│  │    "ctx_id": "active-ctx-uuid",          ← bAuth       │   │
│  │    "tenant": "acme",                     ← bAuth       │   │
│  │    "empresa": "NIT-1234567890",          ← bAuth       │   │
│  │    "sucursal": "central",                ← bAuth       │   │
│  │    "bitmask": "0x0000010900030052",     ← bAuth       │   │
│  │    "loa": 2,                             ← bAuth       │   │
│  │    "zones": ["AREA-CAJA","AREA-VENT"],  ← bAuth       │   │
│  │    "scope": "BRANCH",                    ← bAuth       │   │
│  │    "permissions": [                      ← bAuth       │   │
│  │      "tryton.sale_pos.read",                           │   │
│  │      "tryton.sale_pos.write"                           │   │
│  │    ]                                                   │   │
│  │  }                                                     │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ⚠️ TODOS los claims de negocio (tenant, empresa,            │
│     sucursal, bitmask, zones, permissions) los CONFIGURA     │
│     bAuth y los SINCRONIZA a Keycloak vía Admin API.        │
│     Keycloak los INCLUYE en el JWT al emitirlo.              │
│     Pero Keycloak no sabe qué significan — solo los copia.  │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. BAUTH — EMISOR DE CONTEXTO, NO DE TOKENS

bAuth emite **identificadores de contexto**, no tokens de autorización.

| Identificador | Qué es | Cuándo se emite | Formato |
|--------------|--------|----------------|---------|
| **ctx_id** | Context Session ID | Después de autenticación exitosa. Identifica la sesión del usuario con sus 6 capas de contexto. | UUID v4 |
| **dctx_id** | Device Context ID | Antes de autenticación. Identifica el dispositivo anónimo que se conecta. | UUID v4 |
| **QR Challenge** | Challenge anti-replay | Cuando un dispositivo muestra un QR para transferencia de contexto. | 32 bytes random (base64url) |

```
FLUJO DE EMISIÓN DE ctx_id:
────────────────────────────
1. Usuario se autentica en Keycloak → recibe JWT
2. App SBOS Authenticator → WebSocket a bAuth: "promover dctx_id a ctx_id"
3. bAuth resuelve 6 capas de contexto:
   tenant + empresa + sucursal + pos_logico + user_uuid + session_kc
4. bAuth emite ctx_id → almacena en ses_context (PostgreSQL) + Redis (cache)
5. ctx_id se incluye como claim en el JWT (Keycloak lo copia vía User Attribute)
```

**bAuth NO emite JWT. bAuth emite contexto.**

---

## 3. QUIÉN CONFIGURA QUÉ EN EL TOKEN

| Claim del JWT | ¿Quién lo define? | ¿Quién lo escribe en el token? | Fuente |
|--------------|:---:|:---:|--------|
| `iss` | — | Keycloak | URL del realm |
| `sub` | bAuth | Keycloak | `idn_user_template.uuid` |
| `aud` | bAuth | Keycloak | `idp_client.client_id` |
| `exp` | bAuth | Keycloak | `idp_token_config.jwt_ttl_seconds` o `ath_config_d9` |
| `iat` | — | Keycloak | Timestamp actual |
| `ctx_id` | bAuth | Keycloak | `ses_context.ctx_id` (User Attribute) |
| `tenant` | bAuth | Keycloak | `idn_user_template.tenant_id` (User Attribute) |
| `empresa` | bAuth | Keycloak | `idn_user_template.empresa_id` (User Attribute) |
| `sucursal` | bAuth | Keycloak | `idn_user_template.sucursal_id` (User Attribute) |
| `bitmask` | bAuth (PrivilegeEngine) | Keycloak | `idn_user_template.mask_eff_hex` (User Attribute) |
| `loa` | bAuth | Keycloak | `ses_context.loa_current` (User Attribute) |
| `zones` | bAuth | Keycloak | `log_zone` del rol asignado (User Attribute) |
| `scope` | bAuth | Keycloak | `bos_permiso_logico.scope` (User Attribute) |
| `permissions` | bAuth (PrivilegeEngine) | Keycloak | `privilege_atom` del rol (User Attribute) |

---

## 4. TOKENS PARA APLICACIONES EXTERNAS

Cuando una aplicación de TERCERO usa bAuth como Identity Provider:

```
┌──────────────────────────────────────────────────────────────┐
│  APP EXTERNA (ej: Portal de Facturas ACME)                   │
│                                                              │
│  1. Usuario hace clic en "Iniciar sesión con SBOS"          │
│  2. Redirige a: https://auth.sbos.app/realms/acme/protocol/ │
│     openid-connect/auth?client_id=uuid-portal-facturas       │
│  3. KEYCLOAK autentica al usuario (Passkey, huella)          │
│  4. KEYCLOAK emite: access_token + id_token                  │
│  5. App externa recibe los tokens                            │
│                                                              │
│  ⚠️ La app externa NUNCA ve:                                 │
│     - El password del usuario                                │
│     - La huella del usuario                                  │
│     - La base de datos de bAuth                              │
│     - Los permisos internos del SBOS                         │
│                                                              │
│  ✅ Solo recibe los claims que bAuth configuró en            │
│     idp_token_config.include_claims                          │
└──────────────────────────────────────────────────────────────┘
```

---

## 5. RESUMEN VISUAL

```
           ¿QUIÉN EMITE QUÉ?

           TOKENS DE AUTORIZACIÓN (JWT)
           ────────────────────────────
           access_token  ──── KEYCLOAK ──── validado por KONG
           refresh_token ──── KEYCLOAK ──── validado por KEYCLOAK
           id_token      ──── KEYCLOAK ──── validado por APP CLIENTE
           M2M token     ──── KEYCLOAK ──── validado por DAEMON (mTLS)

           IDENTIFICADORES DE CONTEXTO
           ──────────────────────────
           ctx_id        ──── BAUTH    ──── validado por BAUTH (Redis O(1))
           dctx_id       ──── BAUTH    ──── validado por BAUTH
           QR Challenge  ──── BAUTH    ──── validado por BAUTH (anti-replay)

           CONFIGURACIÓN DE TOKENS
           ──────────────────────
           Claims        ──── BAUTH    ──── sincronizado a KEYCLOAK
           TTL           ──── BAUTH    ──── sincronizado a KEYCLOAK
           Scopes        ──── BAUTH    ──── sincronizado a KEYCLOAK
           Firmas        ──── VAULT    ──── usado por KEYCLOAK
```

**Keycloak = el que emite. bAuth = el que configura QUÉ se emite. Vault = el que guarda CON QUÉ se firma.**

---

*Documento generado 2026-06-25. Keycloak: único emisor de JWT. bAuth: emisor de contexto + configurador de claims.*
