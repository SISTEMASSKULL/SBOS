---
codigo: BNOTIFY-002
version: 1.0.0
estado: BORRADOR
gate: G0
depende_de: [BNOTIFY-000, BNOTIFY-001]
doctrina_que_ejerce: [D2, D3, D5, D14, D16]
criterio_implementado: >
  GET /.well-known/openid-configuration de bAuth retorna JSON válido con todos
  los endpoints listados en §2. Un usuario real inicia sesión en bRocket usando
  OIDC de bAuth (no Keycloak) y el id_token contiene el claim sbos_roles con
  los roles correctos. bNotify consume un evento CAEP session-revoked de bAuth
  y suspende entregas al ctx_id revocado en menos de 30 segundos.
---

# BNOTIFY-002 — bAuth OIDC Superficie D9
## Especificación de la superficie OIDC de bAuth como Identity Provider nativo

**Versión:** 1.0.0 · **Gate:** G0 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §4.3, §5 · BNOTIFY-000 §8 (R2, primer bloqueante de G0)
**Nota:** este documento es una especificación para bAuth — lo que bNotify necesita
que bAuth provea. bAuth confirma en el campo §8.

⚠️ **Bloqueante G0:** sin este contrato aprobado e implementado en bAuth, bRocket
no puede hacer login y el programa no puede avanzar al gate G1.

---

## 1. Contexto

bAuth ya implementa un OIDC Provider nativo (verificado en `oidc_provider.rs`).
Este documento especifica **exactamente** qué superficie OIDC expone, qué claims
emite, y qué eventos CAEP publica — para que bRocket pueda configurarse sin
ambigüedad y bNotify pueda consumir los eventos de sesión.

**Principio D3:** bAuth es el plano de identidad. Keycloak es backup/redundancia.
La dirección es eliminar la dependencia de Keycloak — bAuth emite el JWT directamente.

---

## 2. Endpoints OIDC que bAuth debe exponer

### 2.1 Discovery (obligatorio primero)

```
GET /.well-known/openid-configuration
```

Respuesta JSON mínima requerida:

```json
{
  "issuer": "https://bauth.sbos.internal",
  "authorization_endpoint": "https://bauth.sbos.internal/auth/oidc/authorize",
  "token_endpoint": "https://bauth.sbos.internal/auth/oidc/token",
  "userinfo_endpoint": "https://bauth.sbos.internal/auth/oidc/userinfo",
  "jwks_uri": "https://bauth.sbos.internal/auth/oidc/jwks",
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "subject_types_supported": ["public"],
  "id_token_signing_alg_values_supported": ["EdDSA"],
  "scopes_supported": ["openid", "profile", "email", "sbos_roles", "offline_access"],
  "claims_supported": [
    "sub", "iss", "aud", "exp", "iat", "email", "name",
    "sbos_roles", "sbos_tenant", "ctx_id", "kyc_tier"
  ],
  "token_endpoint_auth_methods_supported": ["client_secret_post"],
  "code_challenge_methods_supported": ["S256"]
}
```

### 2.2 Authorization endpoint

```
GET /auth/oidc/authorize
```

Parámetros estándar OAuth 2.0 + PKCE (RFC 7636):

| Parámetro | Requerido | Descripción |
|-----------|:---------:|-------------|
| `client_id` | ✅ | Formato: `rocketchat-{tenant_id}` para bRocket |
| `redirect_uri` | ✅ | Debe coincidir con el registrado en bAuth |
| `response_type` | ✅ | Solo `code` |
| `scope` | ✅ | Al menos `openid`. Agregar `sbos_roles` para recibir roles |
| `state` | ✅ | CSRF protection |
| `code_challenge` | ✅ | PKCE — SHA-256 del code_verifier |
| `code_challenge_method` | ✅ | Solo `S256` |

### 2.3 Token endpoint

```
POST /auth/oidc/token
Content-Type: application/x-www-form-urlencoded
```

| Campo | Descripción |
|-------|-------------|
| `grant_type` | `authorization_code` o `refresh_token` |
| `code` | Código del authorization endpoint |
| `redirect_uri` | Igual que en authorize |
| `client_id` | ID del cliente |
| `client_secret` | Secreto (almacenado en Vault) |
| `code_verifier` | PKCE verifier |

Respuesta:
```json
{
  "access_token": "...",
  "id_token": "...",
  "refresh_token": "...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

### 2.4 UserInfo endpoint

```
GET /auth/oidc/userinfo
Authorization: Bearer {access_token}
```

Retorna el mismo conjunto de claims que el id_token (ver §3).

### 2.5 JWKS endpoint

```
GET /auth/oidc/jwks
```

Retorna las claves públicas Ed25519 actuales de bAuth en formato JWK:

```json
{
  "keys": [
    {
      "kty": "OKP",
      "crv": "Ed25519",
      "kid": "bauth-ed25519-2026-07",
      "use": "sig",
      "x": "..."
    }
  ]
}
```

Rotación de claves: al rotar, publicar la nueva Y mantener la anterior activa
durante el TTL máximo de los access_tokens en circulación (mínimo 1 hora).

---

## 3. Claims del id_token y access_token

### 3.1 Claims obligatorios en TODOS los tokens de bRocket/bChat

| Claim | Tipo | Descripción | Ejemplo |
|-------|------|-------------|---------|
| `sub` | string (UUID) | Identificador único del usuario en bAuth | `"abc123-..."` |
| `iss` | string | Emisor — siempre `https://bauth.sbos.internal` | |
| `aud` | string | Audiencia — `rocketchat-{tenant_id}` | `"rocketchat-empresa-abc"` |
| `exp` | number | Expiración en Unix timestamp | |
| `iat` | number | Emisión en Unix timestamp | |
| `email` | string | Email corporativo del usuario | `"juan@empresa.com"` |
| `name` | string | Nombre completo | `"Juan Quispe"` |
| `sbos_roles` | array[string] | Roles SBOS activos del usuario | `["CONSUMER_T0", "FINANCIERO_N1"]` |
| `sbos_tenant` | string | ID del tenant | `"empresa-abc"` |
| `ctx_id` | string (UUID) | Context ID de la sesión (SBOS-049) | `"ctx-xyz-..."` |

### 3.2 Claims opcionales (scope `sbos_roles` requerido para algunos)

| Claim | Scope requerido | Descripción |
|-------|:--------------:|-------------|
| `kyc_tier` | `sbos_roles` | T0/T1/T2 — nivel de verificación KYC |
| `locale` | `profile` | BCP-47 — idioma preferido del usuario |
| `zoneinfo` | `profile` | IANA timezone del usuario |
| `phone_number` | `profile` | Teléfono (solo si kyc_tier ≥ T0) |
| `phone_number_verified` | `profile` | Si el teléfono fue verificado |

### 3.3 Algoritmo de firma

Los tokens se firman con **Ed25519 (EdDSA)** usando la clave privada gestionada
por Vault PKI. `alg` en el JWT header: `"EdDSA"`. Kid: el `kid` del JWK activo.

---

## 4. Registro de clientes OIDC (Client Registration)

bAuth mantiene un registro de clientes OIDC. Para bRocket:

| Campo | Valor |
|-------|-------|
| `client_id` | `rocketchat-{tenant_id}` — uno por tenant |
| `client_secret` | Generado en bootstrap del tenant. Almacenado en Vault: `sbos/bauth/oidc/clients/{tenant_id}/rocketchat` |
| `redirect_uris` | `["https://{tenant_id}.sbos.app/chat/_oauth/bauth"]` |
| `grant_types` | `["authorization_code", "refresh_token"]` |
| `response_types` | `["code"]` |
| `scopes` | `["openid", "profile", "email", "sbos_roles"]` |
| `token_endpoint_auth_method` | `client_secret_post` |
| `id_token_signed_response_alg` | `EdDSA` |

---

## 5. Perfil de sesión CONSUMER_MOBILE

Para usuarios que acceden desde bChat móvil (perfil de consumo masivo — KYC tier T0+):

| Parámetro de sesión | Valor | Justificación |
|---------------------|:-----:|---------------|
| `access_token` TTL | 1 hora | Estándar OIDC para apps móviles |
| `refresh_token` TTL | 30 días | D8.bauth.session.ttl_consumer |
| `refresh_token` rotante | Sí | Cada uso invalida el anterior (CAEP-compatible) |
| Máx. sesiones concurrentes | 5 dispositivos | Política anti-compartición de cuenta |
| Renovación silenciosa | Sí | El cliente renueva en background sin interrumpir al usuario |

El `ctx_id` persiste en toda la duración del refresh_token. Al revocar:
bAuth publica `session-revoked` (CAEP) y bNotify suspende entregas en <30s.

---

## 6. Eventos CAEP que bAuth publica

bAuth actúa como **SSF Transmitter** (Shared Signals Framework). bNotify actúa como
**SSF Receiver**. El transporte es gRPC (ADR-001) — bAuth llama al endpoint de bNotify.

### 6.1 Método gRPC de bNotify para recibir eventos CAEP

```protobuf
// En bnotify.proto (extensión de BNOTIFY-001):
service NotifyDispatcher {
  // ...
  rpc ReceiveCaepEvent(CaepEvent) returns (CaepAck);
}

message CaepEvent {
  string event_type = 1;  // "session-revoked", "credential-change", etc.
  string subject_ctx_id = 2;  // ctx_id de la sesión afectada
  string subject_user_id = 3; // UUID de bAuth del usuario
  string tenant_id = 4;
  string occurred_at = 5;     // RFC3339
  map<string, string> event_data = 6; // Datos específicos del evento
}

message CaepAck {
  bool received = 1;
}
```

### 6.2 Eventos que bAuth debe emitir hacia bNotify

| Evento CAEP | Cuándo | Acción de bNotify |
|-------------|--------|-------------------|
| `session-revoked` | Offboarding, suspensión, violación de seguridad | Suspender todas las entregas pendientes al ctx_id. Cancelar refresh_tokens en curso |
| `credential-change` | Cambio de password, nuevo MFA registrado | Notificar al usuario por canal secundario (email/SMS) que hubo cambio de credencial |
| `assurance-level-change` | Promoción KYC T0→T1→T2 | Habilitar canales y funcionalidades nuevos para ese usuario |
| `device-compliance-change` | Jailbreak detectado, MDM fuera de compliance | Revocar token de push de ese dispositivo específico |
| `risk-level-change` | RiskEngine detecta anomalía | Escalar prioridad de las próximas notificaciones de seguridad a ese usuario |

---

## 7. Configuración de bRocket para OIDC bAuth

Variables de entorno del deployment K8s de bRocket (se inyectan como K8s Secret):

```yaml
# OAuth Custom Provider "bAuth" en Rocket.Chat CE
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth: "true"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_url: "https://bauth.sbos.internal"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_token_path: "/auth/oidc/token"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_identity_path: "/auth/oidc/userinfo"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_authorize_path: "/auth/oidc/authorize"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_scope: "openid profile email sbos_roles"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_id_field: "sub"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_username_field: "email"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_email_field: "email"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_name_field: "name"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_roles_claim_name: "sbos_roles"
OVERWRITE_SETTING_Accounts_OAuth_Custom_bAuth_client_id: "rocketchat-${TENANT_ID}"
# client_secret se inyecta desde Vault en tiempo de arranque del pod
```

### 7.1 Verificación pendiente (R2 de BNOTIFY-000 §8)

⚠️ Se debe confirmar en la instancia real de bRocket (RC CE 8.5.0) que el OIDC custom
con proveedor self-hosted opera pleno en Community Edition, especialmente:
- Que el campo `roles_claim_name` con un array de strings funciona sin EE
- Que el flow PKCE con `code_challenge_method=S256` está disponible en CE 8.5.0

Esta verificación es el gate G0 para BNOTIFY-003.

---

## 8. Respuesta de bAuth — campo de confirmación

*Este campo lo completa el agente bAuth al revisar y aceptar este documento.*

```
Estado bAuth: EN REVISIÓN
Fecha: 2026-07-06
Notas: bAuth tomó conocimiento de este documento. Los 5 endpoints OIDC
  están parcialmente implementados en oidc_provider.rs. Se abre contrato
  bilateral BAUTH-BNOTIFY-CONTRATOS.md (ver context/contracts/) para
  formalizar el intercambio. La confirmación definitiva requiere verificación
  empírica en VPS (Testeador) — ver REPARACIONBAUTH FASE 5.M tareas F5.M1-F5.M3.
Compatibilidad CE 8.5.0 verificada: ☐  (pendiente FASE 5.M)
PKCE S256 confirmado en CE: ☐  (pendiente FASE 5.M)
Evento CAEP session-revoked implementado: ☐  (pendiente FASE 5.M — F5.M4-F5.M5)
```

**Contratos abiertos:** BAUTH-BNOTIFY-CONTRATOS.md — C-BAUTH-001 (endpoints), C-BAUTH-002 (claims),
C-BAUTH-003 (CONSUMER_MOBILE), C-BAUTH-004 (CAEP) — todos en estado 📝 PROPUESTO a 2026-07-06.

---

*BNOTIFY-002 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*Sin este documento aprobado e implementado, el programa no arranca. Es el primer bloqueante real de G0.*
