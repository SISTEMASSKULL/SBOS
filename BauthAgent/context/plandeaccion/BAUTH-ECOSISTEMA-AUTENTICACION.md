# BAUTH-ECOSISTEMA-AUTENTICACION.md — Todas las Aplicaciones que Colaboran con bAuth

**Versión:** 1.0 · **Fecha:** 2026-06-25
**Propósito:** Documentar CADA aplicación y daemon que participa en la autenticación del SBOS.
bAuth orquesta, pero no actúa solo. Este documento mapea QUIÉN hace QUÉ en cada paso del flujo.

---

## 1. EL ECOSISTEMA COMPLETO

```
                        USUARIO
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
          Celular     Desktop      Lector Físico
         (Passkey)   (Windows Hello)  (NFC/QR)
              │            │            │
              └────────────┼────────────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │         KONG            │  ← API Gateway
              │  • Valida JWT           │
              │  • Rate limiting        │
              │  • Header injection     │
              │  • OIDC plugin          │
              └───────────┬─────────────┘
                          │
              ┌───────────┴───────────┐
              ▼                       ▼
    ┌─────────────────┐     ┌─────────────────┐
    │    KEYCLOAK      │     │     bAuth        │
    │  • IdP (OIDC)    │     │  • Orquestador   │
    │  • Passwords      │◄───▶│  • PrivilegeEngine│
    │  • MFA (TOTP)    │     │  • 12 dominios    │
    │  • WebAuthn       │     │  • RolTemplate   │
    │  • JWT issuance   │     │  • UserTemplate  │
    │  • Session mgmt   │     │  • SoD validation │
    └────────┬──────────┘     └────────┬──────────┘
             │                         │
             │    ┌────────────────────┤
             │    ▼                    ▼
             │  ┌─────────────────┐  ┌─────────────────┐
             │  │     VAULT        │  │     TRYTON       │
             │  │  • Secrets      │  │  • ir.model.access│
             │  │  • API Keys     │  │  • ir.rule        │
             │  │  • Certs (mTLS) │  │  • ir.model.button│
             │  │  • Encryption   │  │  • res.groups     │
             │  └─────────────────┘  └─────────────────┘
             │
    ┌────────┴──────────┐
    ▼                   ▼
┌────────────┐    ┌────────────┐
│  bhnexus    │    │  banexus    │
│  Nexus Host │    │  Nexus Agent│
│  • WebSocket│    │  • Fedora   │
│  • mTLS     │    │  • udev     │
│  • Puertas  │    │  • PAM      │
│  • OSDP     │    │  • polkit   │
│  • Cámaras  │    │  • USB      │
└──────┬──────┘    └──────┬──────┘
       │                  │
       └────────┬─────────┘
                │
    ┌───────────┴───────────┐
    ▼                       ▼
┌────────────┐        ┌────────────┐
│  Besu QBFT  │        │  PostgreSQL │
│  • D12      │        │  • 177 tablas│
│  • Merkle   │        │  • PostGIS  │
│  • Anclaje  │        │  • WAL CDC  │
│  • DID      │        │             │
└────────────┘        └──────┬──────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
        ┌────────────┐              ┌────────────┐
        │  bkernel    │              │   Redis     │
        │  • CDC      │              │  • Cache    │
        │  • Fanout   │              │  • Streams  │
        │  • WAL→Redis│              │  • ctx_id   │
        └──────┬──────┘              └────────────┘
               │
               ▼
        ┌────────────┐
        │  biedata    │
        │  • JSON-RPC │
        │  • Sagas    │
        └────────────┘
```

---

## 2. QUÉ HACE CADA APLICACIÓN EN LA AUTENTICACIÓN

### 2.1 Keycloak — Identity Provider (IdP)

| Responsabilidad | Cómo lo hace | Tablas bAuth relacionadas |
|----------------|-------------|--------------------------|
| **Registro de usuarios** | User creation, credential storage | `idn_user_template`, `ath_binding` |
| **Autenticación primaria** | Password verification, OTP, WebAuthn | `ath_method`, `ath_mfa_enrollment` |
| **Emisión de JWT** | Access token + Refresh token + ID token | `idp_token_config`, `external_session_registry` |
| **Gestión de sesiones** | Session TTL, concurrent sessions, reauth | `ses_context`, `ath_config_d9` |
| **MFA** | TOTP, WebAuthn, Passkeys, Backup Codes | `ath_mfa_enrollment`, `ath_recovery_method` |
| **Federación** | OIDC, SAML 2.0, OAuth 2.1, CIBA | `ath_federation_protocol` |
| **Composite Roles** | Agrupa roles de bAuth en KC | `idn_role_template` |
| **Auth Flows** | Flujos de autenticación (standard, elevated) | `ath_auth_flow`, `ath_auth_flow_method` |
| **User Attributes** | Atributos en el JWT (zones, scope, LoA) | `log_zone`, `bos_permiso_logico` |
| **Step-Up** | RFC 9470 — elevación temporal de LoA | `ath_step_up_rule` |

### 2.2 Vault — Secrets & Certificates Management

| Responsabilidad | Cómo lo hace | Tablas bAuth relacionadas |
|----------------|-------------|--------------------------|
| **API Keys** | Almacenamiento seguro de client_secret para idp_client | `idp_client.client_secret_hash` |
| **Certificados mTLS** | Emisión y rotación de certificados X.509 | `sec_key_inventory`, `sec_key_rotation` |
| **Claves de firma JWT** | Almacenamiento de claves EdDSA/RS256 | `sec_key_inventory` (key_type=JWT_SIGNING) |
| **Claves de encriptación** | AES-256-GCM para datos en reposo | `sec_key_inventory` (key_type=AES_ENCRYPTION) |
| **Break-Glass** | Unseal 2-of-3 para acceso de emergencia | `ses_superuser_context`, `sec_key_recovery` |
| **Certificados SIN Bolivia** | ADSIB certificates para facturación electrónica | `sec_key_inventory` (key_type=ADSIB_CERT) |
| **CA interna** | Root CA, Sub-CA para dispositivos y servicios | `sec_key_inventory` (key_type=ROOT_CA, SUB_CA_*) |

### 2.3 Kong — API Gateway

| Responsabilidad | Cómo lo hace | Tablas bAuth relacionadas |
|----------------|-------------|--------------------------|
| **Validación JWT** | Cada request → verifica firma, exp, aud | — (configuración en Kong) |
| **Rate Limiting** | 100 req/s por IP. 429 con retry_after | `ath_config_d9` (config_key=rate_limit) |
| **Inyección de headers** | X-SBOS-Tenant, X-SBOS-Ctx-Id, X-SBOS-Empresa, X-SBOS-Sucursal | `ses_context` |
| **OIDC Plugin** | Proxy inverso con autenticación OIDC hacia Keycloak | `idp_client` (client_id, redirect_uris) |
| **ACL** | Control de acceso por grupo/rol a rutas específicas | `idn_role_template` |
| **mTLS** | Autenticación mutua para daemons (bAuth→bKernel) | `certificate_pin_config` |
| **WebSocket** | Proxy wss:// para bSearch y bhnexus | — |

### 2.4 bhnexus — Nexus Host (Acceso Físico)

| Responsabilidad | Cómo lo hace | Tablas bAuth relacionadas |
|----------------|-------------|--------------------------|
| **WebSocket mTLS** | Conexión persistente con dispositivos físicos | `net_device` |
| **Puente Físico** | OSDP ↔ bAuth. Traduce señales de lectores | `fis_device`, `fis_controller` |
| **Control de puertas** | Abre/cierra chapas según decisión de bAuth | `fis_access_zone`, `fis_zone_member` |
| **Lectores biométricos** | Recibe template hash del lector, consulta a bAuth | `fis_device` (device_type=BIOMETRIC_READER) |
| **Cámaras ONVIF** | Streaming + detección de movimiento | `fis_device` (device_type=IP_CAMERA) |
| **Anti-passback** | Controla entrada/salida por zona | `fis_area_config` |
| **QR Dinámico** | Muestra QR en lectores de puerta para acceso móvil | `qr_challenge_registry`, `ctx_transfer_log` |
| **NFC** | Recibe ctx_id vía NFC del celular | `ctx_transfer_log` (transfer_method=NFC) |

### 2.5 banexus — Nexus Agent (Edge en VDI/Fedora)

| Responsabilidad | Cómo lo hace | Tablas bAuth relacionadas |
|----------------|-------------|--------------------------|
| **Login en VDI** | Intercepta login vía PAM + polkit | `ses_context` |
| **USB interceptor** | udev rules — detecta dispositivos USB conectados | `net_device` |
| **Política de dispositivo** | Aplica políticas de seguridad en el endpoint | `net_ztna_policy` |
| **Cache de contexto** | Almacena ctx_id localmente en el VDI | `ses_context` |
| **Heartbeat** | Reporta estado del dispositivo cada 30s | `mobile_heartbeat_log` |

### 2.6 Besu QBFT — Blockchain (D12)

| Responsabilidad | Cómo lo hace | Tablas bAuth relacionadas |
|----------------|-------------|--------------------------|
| **Anclaje Merkle** | Cada lote de eventos de auditoría → Merkle root → Arbitrum L2 | `blk_merkle_batch`, `blk_merkle_leaf` |
| **Verificación independiente** | Cualquier tercero puede verificar un evento sin acceso a la BD | `blk_merkle_leaf.merkle_proof` |
| **Reconciliación cross-chain** | Compara Merkle root DB vs on-chain | `blk_reconciliation` |
| **Identidad Descentralizada (DID)** | W3C DID Core — identidad soberana on-chain | `blk_account` |
| **Smart Contracts** | EIP-725 (Identity), EIP-735 (Claims) | `blk_account` |

### 2.7 PostgreSQL — Base de Datos

| Responsabilidad | Cómo lo hace | Tablas relacionadas |
|----------------|-------------|---------------------|
| **177 tablas DDL** | Almacena toda la configuración y estado | Todo el schema `bauth` |
| **PostGIS** | Consultas geoespaciales (point-in-polygon, distance) | `geo_fence`, `geo_location_log` |
| **WAL CDC** | Write-Ahead Log → bkernel escucha cambios | `pg_replication_origin` |
| **Particionado** | `aud_event`, `ath_login_attempt` — por mes | Tablas particionadas |
| **UUIDv7** | PKs time-ordered para rendimiento B-tree | RFC 9562 |

### 2.8 Redis — Cache & Streams

| Responsabilidad | Cómo lo hace | Tablas relacionadas |
|----------------|-------------|---------------------|
| **ctx_id cache** | Lookup O(1) de sesiones activas | `ses_context` |
| **Rate limiting** | Contadores de intentos fallidos por IP/usuario | `ath_login_attempt` |
| **Streams (bkernel)** | Publicación de eventos CDC en tiempo real | — |
| **Session cache** | TTL de sesiones en Redis DB1 | `ses_context` |

### 2.9 bkernel — CDC & Fanout

| Responsabilidad | Cómo lo hace | Tablas relacionadas |
|----------------|-------------|---------------------|
| **WAL Listener** | Escucha cambios en PostgreSQL WAL | — |
| **Normalización** | Convierte eventos SQL a eventos de dominio | — |
| **Fanout** | Publica en Redis Streams: `bkernel:auth_events`, `bkernel:audit_queue` | `aud_event` |

### 2.10 biedata — Data Orchestrator

| Responsabilidad | Cómo lo hace | Tablas relacionadas |
|----------------|-------------|---------------------|
| **JSON-RPC 2.0** | Interface estándar para comunicación entre daemons | — |
| **Sagas** | Orquestación de operaciones multi-paso con compensación | — |

### 2.11 bSearch — Motor de Búsqueda

| Responsabilidad | Cómo lo hace | Tablas relacionadas |
|----------------|-------------|---------------------|
| **Búsqueda de auditoría** | Índices GIN + tsvector sobre aud_event | `aud_event` |
| **Búsqueda de usuarios** | Búsqueda full-text sobre idn_user_template | `idn_user_template` |

---

## 3. FLUJO COMPLETO DE AUTENTICACIÓN — PASO A PASO

```
PASO 1: USUARIO LLEGA
─────────────────────
Juan acerca su celular al lector NFC de la puerta.
→ banexus (si es VDI) o bhnexus (si es puerta física) recibe la señal.

PASO 2: NEXUS RECIBE
────────────────────
bhnexus recibe ctx_id vía NFC/QR.
→ bhnexus → WebSocket mTLS → bAuth
→ "¿Puede Juan entrar a PHY_ZONE_VENTAS?"

PASO 3: bAuth EVALÚA
────────────────────
bAuth PrivilegeEngine evalúa 12 dominios en <5ms:
→ D8: ¿ctx_id válido? → Redis cache → ✅ ACTIVE
→ D9: ¿Credenciales? → ath_binding → ✅ WEBAUTHN_PWDLESS
→ D1: ¿Permiso lógico? → privilege_atom → ✅ zone_logical/ventas
→ D2: ¿Acceso físico? → fis_access_zone → ✅ PHY_ZONE_VENTAS
→ D3: ¿Límite financiero? → N/A para acceso físico
→ D4: ¿Horario? → cal_schedule → ✅ Lun 14:30, en turno
→ D6: ¿Ubicación? → geo_fence (PostGIS) → ✅ inside
→ D7: ¿Dispositivo? → net_device → ✅ trust_score 98
→ D5: ¿Biométrico? → ath_binding → ✅ FACE_ID verificado
→ D10: ¿Delegación? → N/A
→ D11: Auditoría → aud_event ← INSERT evento
→ D12: Blockchain → N/A (no requerido para acceso físico)

PASO 4: bAuth RESPONDE
──────────────────────
→ ALLOW
→ bhnexus → controladora OSDP → abre puerta
→ audit_event registrado (WORM, hash-chain)

PASO 5: JUAN USA APLICACIONES
──────────────────────────────
Juan escanea QR de la computadora.
→ KONG recibe request con JWT
→ KONG valida JWT (firma, exp, aud) → ✅
→ KONG inyecta headers: X-SBOS-Tenant, X-SBOS-Ctx-Id
→ TRYTON recibe request con headers
→ TRYTON aplica ir.model.access + ir.rule + campo visibility
→ bAuth audit: INSERT en privilege_atom_audit
→ bkernel captura evento WAL → publica en Redis Stream
→ biedata puede disparar saga si es necesario
→ BESU: cada hora, lote de eventos → Merkle root → Arbitrum L2

PASO 6: KEYCLOAK RENUEVA TOKEN
───────────────────────────────
Después de 55 minutos, el token JWT está por expirar.
→ App SBOS Authenticator (celular) detecta expiración
→ Dio AuthInterceptor → refresh_token → POST /token
→ KEYCLOAK emite nuevo access_token + refresh_token
→ Firma con clave almacenada en VAULT
→ Token TTL configurado en ath_config_d9
```

---

## 4. MATRIZ COMPLETA: APLICACIÓN vs DOMINIO

| Aplicación | D1 | D2 | D3 | D4 | D5 | D6 | D7 | D8 | D9 | D10 | D11 | D12 |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **bAuth** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Keycloak** | — | — | — | — | — | — | — | ✅ | ✅ | — | — | — |
| **Kong** | — | — | — | — | — | — | ✅ | ✅ | — | — | — | — |
| **Vault** | — | — | — | — | — | — | ✅ | — | ✅ | — | — | — |
| **Tryton** | ✅ | — | ✅ | — | — | — | — | — | — | — | — | — |
| **bhnexus** | — | ✅ | — | — | — | — | — | — | — | — | — | — |
| **banexus** | — | ✅ | — | — | — | — | ✅ | — | — | — | — | — |
| **Besu QBFT** | — | — | — | — | — | — | — | — | — | — | ✅ | ✅ |
| **PostgreSQL** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Redis** | — | — | — | — | — | — | — | ✅ | — | — | — | — |
| **bkernel** | — | — | — | — | — | — | — | — | — | — | ✅ | — |
| **biedata** | — | — | — | — | — | — | — | — | — | — | — | — |
| **bSearch** | — | — | — | — | — | — | — | — | — | — | ✅ | — |

---

## 5. RESUMEN: ¿QUIÉN CUBRE QUÉ MÉTODO DE AUTENTICACIÓN?

| Método | Implementado por | bAuth provee |
|--------|-----------------|-------------|
| **Password** | Keycloak | Política (NIST 800-63B-4), historial (Argon2id), screening (HIBP) |
| **TOTP** | Keycloak | Configuración (RFC 6238), dispositivos enrolados |
| **WebAuthn / Passkey** | Keycloak | Binding (NIST §5.2.1), tipo (synced vs device-bound), AAGUID |
| **FIDO2 Security Key** | Keycloak | Attestation verification, credential ID |
| **Smart Card X.509** | Keycloak + Vault | Certificados (Vault), políticas de uso (bAuth) |
| **mTLS (M2M)** | Kong + Vault | Certificados (Vault), políticas (bAuth), enforcement (Kong) |
| **OAuth 2.1 / OIDC** | Keycloak + Kong | Clientes (idp_client), scopes, PKCE, DPoP |
| **SAML 2.0** | Keycloak | Configuración de SP, assertion signing (Vault) |
| **CIBA (Decoupled)** | Keycloak | Política de binding message, timeout |
| **QR Dinámico (físico)** | bhnexus | Challenge (HMAC-SHA256), TTL 30s, anti-replay |
| **NFC (físico)** | bhnexus | ctx_id validation, zone authorization |
| **Huella Dactilar (físico)** | bhnexus | Template hash (Argon2id), FMR, liveness, consent |
| **Reconocimiento Facial** | bhnexus | Template hash, liveness active (desafío), FMR 1:100K |
| **Play Integrity (Android)** | App → bAuth | Verificación server-side, score, trust_level |
| **App Attest (iOS)** | App → bAuth | Verificación server-side, team_id, bundle_id |
| **Anclaje Merkle (D12)** | Besu QBFT | Lotes, hojas, proof, reconciliación |
| **DID (D12)** | Besu QBFT | W3C DID Core, EIP-725/735 |

---

*Documento generado 2026-06-25. 12 aplicaciones colaboran con bAuth en la autenticación.*
*bAuth orquesta. Keycloak identifica. Vault protege secretos. Kong enrutra. bhnexus abre puertas.*
*Besu ancla auditoría. PostgreSQL almacena. Redis cachea. bkernel propaga eventos.*
