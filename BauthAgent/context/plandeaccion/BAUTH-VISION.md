# BAUTH — Visión Unificada del Identity Control Plane

**Versión:** 1.0 · **Fecha:** 2026-06-26 · **Autor:** sbos-coordinador + bauth-developer
**Reemplaza:** BAUTH-AS-A-SERVICE.md + BAUTH-UNIVERSAL-SCALABILITY.md
**Fuentes:** SBOS-CONTEXT-PLANE-VISION.md · BAUTH-ARQUITECTURA-FRAMEWORK.md · BAUTH-CONTRATO-SYMBIOSIS.md

---

## PRINCIPIO ABSOLUTO

> **El USUARIO es la llave universal. Cualquier dispositivo registrado puede portar su identidad.**
> El celular es el dispositivo más común HOY. Mañana será un anillo, un reloj, un chip PUF
> o un implante médico. Todos se autentican contra el mismo Identity Control Plane.
> El ctx_id pertenece al USUARIO, no a un dispositivo específico.
>
> **El desarrollador hace UNA SOLA llamada.**
> `ctx := bos.GetContext()`
>
> **El mismo motor funciona para todos.**
> Del hogar de una persona a la multinacional de 50,000 empleados.

---

## 1. QUÉ ES BAUTH

bAuth es una **plataforma de contexto universal** — un Identity Control Plane que
resuelve tres problemas con un solo producto:

| # | Problema | Solución de bAuth |
|---|----------|-------------------|
| **1** | Cada programador construye su propio sistema de auth (20-38 meses) | `bos.GetContext()` — una llamada, 8 horas de integración |
| **2** | Cada persona carga 5+ objetos físicos para identificarse | El celular como llave universal — huella + QR + NFC |
| **3** | Las soluciones de IAM no escalan del hogar a la empresa | Mismo motor, misma DDL, misma API — configuración diferente |

```
                    ┌─────────────────────────────────────┐
                    │         BAUTH (Plataforma)           │
                    │    Identity Control Plane común      │
                    │    12 dominios · BitMask · 260 reglas│
                    └──────────┬──────────────────────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         ▼                     ▼                     ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ PARA            │  │ PARA            │  │ PARA            │
│ DESARROLLADORES │  │ USUARIOS        │  │ EMPRESAS        │
│                 │  │                 │  │                 │
│ bos.GetContext()│  │ Celular = llave │  │ 1 a 50,000      │
│ SDK/API         │  │ QR/NFC/huella   │  │ empleados       │
│ 8h integración  │  │ Cero passwords  │  │ Mismo motor     │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

---

## 2. PRODUCTO 1 — PARA DESARROLLADORES: `bos.GetContext()`

### El problema

Cada empresa gasta 20-38 meses construyendo infraestructura de autenticación
(password, MFA, sesiones, permisos, SSO, auditoría) antes de escribir una sola
línea de lógica de negocio.

### La solución

```go
ctx := bos.GetContext()
// El desarrollador recibe TODO:
// ctx.User, ctx.Tenant, ctx.Branch, ctx.Trust, ctx.Permissions,
// ctx.DeviceID, ctx.Location, ctx.Shift, ctx.AAL, ctx.RiskScore
```

### Lo que el desarrollador NUNCA más escribe

❌ Login · ❌ Password · ❌ MFA · ❌ Sesiones · ❌ Permisos · ❌ Auditoría
❌ SSO · ❌ Rate limiting · ❌ Token rotation · ❌ Recovery · ❌ Device trust
❌ Control de acceso físico · ❌ Verificación de horarios · ❌ Geo-fencing

### API JSON-RPC

| Método | Parámetros | Retorna |
|--------|-----------|---------|
| `bauth.access.evaluate` | `atom_slug`, `user_uuid` | `{veredicto, fastpath, policies}` |
| `bauth.context.evaluate` | `ctx_id`, `atom_slug` | `{12 dominios evaluados, veredicto}` |
| `bauth.token.validate` | `jwt` | `{valid, claims, exp}` |
| `bauth.token.issue` | `user_uuid`, `include_mask?` | `{jwt, merkle_leaf_keccak256, token_sha256, rolbitmask?}` |

---

## 2.5. TOKEN BAUTH — 4 CAPAS

### Principio

> **El token es la llave, no la carga.**
> La identidad viaja en el JWT. Los permisos se evalúan server-side con ctx_id vivo.
> Para contingencia offline, el RolBitMask se entrega como cookie paralela.
> Para verificación externa, el token se ancla en blockchain D12 (Besu QBFT).

### Capa 1: Identidad (JWT Ed25519, ~1.1 KB)

Token liviano firmado con EdDSA Ed25519 (FIPS 186-5, RFC 8032).

| Claim | Propósito |
|-------|-----------|
| `sub` | UUID del usuario |
| `iss` | `bauth.sbos.bo` |
| `ctx_id` | Contexto operativo (SBOS-049) |
| `tenant_id` | Tenant del usuario |
| `loa` | Level of Assurance (AAL1-3) |
| `acr` | `sbos_aal{N}` |
| `auth_chain` | Cadena de métodos de autenticación |

**NO incluye:** roles, permisos, bitmasks, átomos. Eso va server-side.

**Algoritmo:** Ed25519 — firma 64 bytes, clave pública 32 bytes.
40× más rápida que RS256, 4× más pequeña, 8× menor clave.

### Capa 2: RolBitMask Cookie (opcional, +968 B en respuesta, NO en JWT)

Para aplicaciones que necesitan modo offline/contingencia (POS en sucursal remota,
kioskos, lectores NFC). El RolBitMask se entrega como campo separado en la respuesta
para que Kong/nginx lo establezca como cookie `bAuth_mask`.

```bash
# Activación: include_mask: true
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"...","include_mask":true},"id":1}' | nc -U /tmp/bauth/bauth.sock
```

**Formato:** base64 one-hot, 91 palabras u64, 5,808 bits, ~968 caracteres.
**Uso:** FastPath local <0.5ns sin consultar al PDP.
**TTL:** 30s sincronizado con Redis cache.

### Capa 3: Blockchain D12 (Merkle proof)

Cada token emitido genera un Merkle leaf (Keccak-256) anclable en Besu QBFT.
Permite verificación externa sin confiar en el issuer.

```
SHA256(token) → Keccak-256 → Merkle leaf → batch → Merkle root → tx_hash en Besu QBFT
```

| Campo | Descripción |
|-------|------------|
| `merkle_leaf_keccak256` | Hash Keccak-256 del SHA-256 del token |
| `token_sha256` | Hash SHA-256 del JWT |
| `follow_up` | Anclaje batch en AnchorClient (B29) |

**Resistencia post-cuántica:** Keccak-256 ofrece 256-bit security contra ataques de Grover.

### Capa 4: Legacy RS256 (opcional, bajo demanda)

Para sistemas que no soportan Ed25519 (legado empresarial). RSA-SHA256 disponible
configurando `engines.keycloak.legacy_rsa` en `bauth.toml`.

| Algoritmo | Tamaño firma | Velocidad firma | Uso |
|-----------|:---:|:---:|------|
| **Ed25519** (default) | 64 B | ~50 µs | Moderno, rápido, compacto |
| RS256 (legacy) | 256 B | ~2,000 µs | Compatibilidad enterprise |

### Comparación con la industria

| | bAuth | Keycloak | Auth0 | Okta |
|---|:---:|:---:|:---:|:---:|
| Algoritmo default | **Ed25519** | RS256 | RS256 | RS256 |
| Token liviano | **1.1 KB** | 1.5-3 KB | 1-2 KB | 1-2 KB |
| Cookie RolBitMask | **Sí** | No | No | No |
| Anclaje Blockchain | **Sí (Besu QBFT)** | No | No | No |
| Server-side PDP | **Sí (12 dominios)** | No | No | No |
| Verificable sin issuer | **Sí (Merkle proof)** | No | No | No |

---

## 3. DOBLE MOTOR DE FIRMAS DIGITALES

bAuth es el ÚNICO IAM del mercado con dos motores de firma independientes
para propósitos distintos. No depende de un PKI externo para sus operaciones
internas, y cumple con la regulación estatal para facturación electrónica.

### Motor Interno — Vault PKI (EdDSA Ed25519)

Firma documentos, eventos y tokens que circulan DENTRO del ecosistema SBOS.

| Característica | Valor |
|---------------|-------|
| **Algoritmo** | EdDSA Ed25519 (FIPS 186-5, RFC 8032) |
| **CA** | Interna (Vault PKI Engine) |
| **TTL certificados** | 24h (M2M), 90 días (servicios) |
| **Formatos** | JWS (JWT firmados), CAdES (binarios), PAdES (PDF internos), XAdES (XML) |
| **Usos** | Firmar sagas de instalación, eventos CDC, JWT M2M entre daemons, logs de auditoría, contratos inter-tenant |
| **Tablas DDL** | `sec_key_inventory`, `sec_key_rotation`, `sec_key_recovery`, `certificate_pin_config` |

### Motor Externo — ADSIB/SIN Bolivia (RSA-SHA256)

Firma documentos con validez jurídica para entidades FUERA del SBOS,
especialmente facturación electrónica ante el SIN de Bolivia.

| Característica | Valor |
|---------------|-------|
| **Algoritmo** | RSA 2048/4096 + SHA-256 |
| **CA** | ADSIB (Jerarquía Bolivia: ATT → ADSIB → Signatario) |
| **TTL certificados** | 365 días (renovable) |
| **Formatos** | XAdES (XML factura SIN), PAdES (PDF factura), CAdES (archivos fiscales) |
| **Usos** | Facturación electrónica, notas de crédito/débito, documentos fiscales, certificación externa |
| **Cumplimiento** | Ley 164 Bolivia, SIN RND 102100000011, ADSIB-FD-POLT-015 v2.3 |

### Cuándo se usa cada motor

```
┌──────────────────────────────────────────────────────────────┐
│              bAuth Signature Service                          │
│                                                               │
│  ┌─────────────────────────┐  ┌─────────────────────────┐    │
│  │  MOTOR INTERNO           │  │  MOTOR EXTERNO           │    │
│  │  Vault PKI · Ed25519     │  │  ADSIB · RSA-SHA256      │    │
│  │                          │  │                           │    │
│  │  ✅ Firma de sagas       │  │  ✅ Facturación SIN       │    │
│  │  ✅ JWT M2M entre daemons│  │  ✅ Notas crédito/débito   │    │
│  │  ✅ Eventos CDC (bkernel)│  │  ✅ Documentos fiscales    │    │
│  │  ✅ Logs de auditoría    │  │  ✅ Certificación externa  │    │
│  │  ✅ Contratos internos   │  │  ✅ Cumplimiento Ley 164   │    │
│  │  ✅ PDFs internos        │  │  ✅ Validación ADSIB CRL   │    │
│  └─────────────────────────┘  └─────────────────────────┘    │
│                                                               │
│  ⚠️ NUNCA usar el motor equivocado para el contexto equivocado│
└──────────────────────────────────────────────────────────────┘
```

### Por qué esto es un diferenciador

| Capacidad | bAuth | Okta | Auth0 | Keycloak |
|-----------|:---:|:---:|:---:|:---:|
| Firma digital interna (PKI propio) | ✅ | ❌ | ❌ | ❌ |
| Firma digital estatal (ADSIB/SIN) | ✅ | ❌ | ❌ | ❌ |
| Doble motor con propósitos separados | ✅ | ❌ | ❌ | ❌ |
| JWT firmados con Ed25519 | ✅ | ❌ (solo RSA) | ❌ (solo RSA) | ❌ |
| Certificados M2M TTL 24h | ✅ | ❌ | ❌ | ❌ |
| Cumplimiento Ley 164 Bolivia | ✅ | ❌ | ❌ | ❌ |

---

## 4. PRODUCTO 2 — PARA USUARIOS: El Celular como Llave Universal

### El problema

Cada persona carga 5+ objetos físicos para identificarse: tarjeta de la oficina,
tarjeta del banco, llave de casa, token OTP, password en la cabeza.

### La solución

El celular los reemplaza TODOS. La huella se registra UNA VEZ en el teléfono.
A partir de ahí, el ctx_id viaja vía QR y NFC.

### 10 momentos reales documentados en SBOS-CONTEXT-PLANE-VISION.md

| # | Momento | Experiencia |
|---|---------|------------|
| 1 | Onboarding | Escanea QR → apoya huella → listo (5 min, cero teclado) |
| 2 | Inicio jornada | Escanea QR entrada → ctx_id activado |
| 3 | Usar apps | Desktop muestra QR → celular escanea → sesión transferida |
| 4 | Abrir puerta | Acerca celular al lector NFC → puerta abre (<500ms) |
| 5 | Cobrar en caja | bAuth evalúa 6 dimensiones en <5ms, transparente |
| 6 | Delegar | Delega permisos desde la app en 30 segundos |
| 7 | Usuario externo | Su Passkey ES su cuenta, sin registro manual |
| 8 | Emergencia | Supervisor autoriza override temporal vía QR |
| 9 | Visitante residencial | QR de invitación, acceso limitado por zona/horario |
| 10 | Control remoto | Dueño verifica y controla su residencia desde otra ciudad |

### Arquitectura del Identity Hub

```
SBOS Authenticator (Flutter)
  ├── Secure Storage (Keystore / Enclave)
  ├── Passkey Manager (FIDO2 / WebAuthn)
  ├── QR / NFC Engine (CTAP 2.2 Hybrid + NFC NDEF)
  └── ctx_id Store (token JWT, BitMask, trust level, overrides)
       │ QR / NFC / WebSocket mTLS
       ▼
bhnexus (Nexus Host) :9444 → bAuth (Identity Control Plane)
```

### Principios

| # | Principio |
|---|-----------|
| P1 | La biometría NUNCA sale del dispositivo — solo la firma criptográfica |
| P2 | Un solo registro biométrico para apps, puertas, cajas, todo |
| P3 | QR como transporte universal de contexto |
| P4 | NFC para acceso físico <500ms |
| P5 | Cero fricción post-onboarding |

---

## 5. ESCALABILIDAD: DEL HOGAR A LA MULTINACIONAL

El mismo motor, la misma DDL, la misma API. Lo que cambia es la configuración.

| Entorno | Usuarios | Dominios | Reglas | Compliance | Hardware |
|---------|:---:|:---:|:---:|------|------|
| **Hogar inteligente** | 1-5 | 4 | 5 | Ninguno | RPi 4 |
| **Pequeño negocio** | 5-20 | 5 | 15 | SIN | Mini PC |
| **PYME** | 50-200 | 9 | 80 | SOX+ISO | 2 servidores |
| **Empresa** | 500-50K | 12 | 260 | PCI+GDPR | K8s 10+ nodos |
| **Gobierno/Defensa** | 100-5K | 12 | 310 | FIPS+NIST | HSM+air-gap |
| **Edificio inteligente** | 30-120 | 4 | 10 | Ninguno | Servidor local |
| **IoT industrial** | 50+200 M2M | 6 | 50 | IEC 62443 | Edge servers |

### Por qué escala sin modificar el motor

| Propiedad | Valor |
|-----------|-------|
| **Evaluación BitMask** | O(1) — <0.5ns sin importar si hay 100 o 16 millones de átomos |
| **Reglas data-driven** | INSERT en `cfg_validation_rule` — sin recompilar, sin redeploy |
| **DDL escalable** | De SQLite (RPi) a PostgreSQL 18 particionado multi-region |
| **Compliance incremental** | De sin compliance a FIPS 140-3 agregando políticas, sin cambiar código |
| **Costo** | $0 open source, self-hosted, sin licencia por usuario |

---

## 6. ARQUITECTURA CENTRAL: EL IDENTITY CONTROL PLANE

```
USUARIO (celular/desktop)
  │ credenciales + método auth
  ▼
┌──────────────────────────────────────────────────────────────┐
│                    bAuth (Identity Control Plane)              │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  EngineRegistry: Keycloak(OIDC) | Vault(PKI) | Besu(ETH)│ │
│  └─────────────────────────────────────────────────────────┘ │
│                         │                                     │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Motor de Reglas (SIEMPRE se ejecuta)                    │ │
│  │  • BitMask Dual (Fast-Path <0.5ns)                      │ │
│  │  • DomainRegistry (12 evaluadores D1-D12)               │ │
│  │  • PolicyChain (políticas encadenadas por átomo)        │ │
│  │  • ConflictMatrix (SoD estático + dinámico)             │ │
│  │  • ClosureTable (herencia DAG transitiva)               │ │
│  │  • RuleEngine (260 reglas data-driven)                  │ │
│  └─────────────────────────────────────────────────────────┘ │
│                         │                                     │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Emisión de Token                                       │ │
│  │  • JWT con RolBitMask + ctx_id + domain_results         │ │
│  │  • Firma digital (Ed25519 Vault / RSA ADSIB)            │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
  │
  ▼
TOKEN JWT → Aplicaciones lo validan localmente con clave pública
```

### Reglas del Framework (R1-R6)

| # | Regla |
|---|-------|
| R1 | Ningún motor se consulta directamente — todo pasa por bAuth |
| R2 | Agregar un motor NO modifica los existentes (Open/Closed) |
| R3 | Cada motor declara `covered_domains()` |
| R4 | Dominio no cubierto → nuevo motor |
| R5 | bAuth normaliza la salida → JWT unificado |
| R6 | Orden de motores NO importa — son independientes |

---

## 7. QUÉ CUBRE LA DDL (165 TABLAS)

| Capacidad | Tablas clave | Estado |
|-----------|-------------|:---:|
| Identidad + autenticación | `idn_user_template`, `ath_method` (32), `ath_binding`, `ath_mfa_enrollment` | ✅ |
| Roles + permisos + BitMask | `privilege_atom` (5,808), `privilege_role_atom`, `idn_role_closure`, `fin_sod_rule` | ✅ |
| Sesiones + contexto | `ses_context`, `ses_context_switch`, `ses_superuser_context` | ✅ |
| Dispositivos + red | `net_device`, `user_client_device` (23 cols), `net_ztna_policy` | ✅ |
| Ubicación + geo | `geo_fence`, `geo_trust_tier`, `geo_velocity_policy` | ✅ |
| Horario + calendario | `cal_schedule`, `cal_holiday`, `cal_fiscal_year`, `cal_overtime_policy` | ✅ |
| Organización | `org_empresa`, `org_sucursal`, `org_pos_logico`, `idn_tenant` (45 cols) | ✅ |
| Físico + acceso | `fis_access_zone`, `fis_location`, `fis_device`, `fis_zone_member` | ✅ |
| Financiero + límites | `fin_transaction_type`, `fin_limit`, `fin_decision_matrix`, `fin_sod_rule` | ✅ |
| Firmas digitales | `sec_key_inventory`, `sec_key_rotation`, `sec_key_recovery` | ✅ |
| Blockchain | `blk_anchor`, `blk_merkle_batch`, `blk_merkle_leaf`, `blk_account` | ✅ |
| Auditoría WORM | `aud_event`, `aud_review`, `aud_ghost_account`, `aud_compliance_map` (290) | ✅ |
| Delegación | `dlg_delegation` (non-transitive, max 8h, auto-revoke) | ✅ |
| Visitantes + emergencias | `visitor_access_policy`, `fis_emergency_config`, `emergency_override_policy` | ✅ |
| Validación | `cfg_validation_rule` (260), `cfg_policy_library` (9,142) | ✅ |
| Framework normativo | `framework_raw` (16 estándares), `ath_federation_protocol` (16) | ✅ |
| **Mobile Identity Hub** | `user_mobile_device`, `ctx_transfer_log`, `idp_client`, `push_token_registry` | 🔴 T-700 a T-714 |

---

## 8. PLAN DE DESARROLLO

### Fase A — Token propio de bAuth (prioridad AHORA)

| Átomo | Descripción |
|-------|------------|
| B48.T01 | `JwtBuilder`: construir JWT con RolBitMask + ctx_id + domain_results |
| B48.T02 | `JwtSigner`: firmar JWT con Ed25519 via Vault PKI |
| B48.T03 | `bauth.token.issue/validate/refresh`: handlers JSON-RPC |

### Fase B — SDK Multi-lenguaje

| Átomo | Descripción |
|-------|------------|
| B48.T10 | SDK Go: `bos.GetContext()` + `bos.AccessEvaluate()` |
| B48.T11 | SDK Python: mismo API |
| B48.T12 | SDK JavaScript/TypeScript |

### Fase C — Identity Hub Mobile

| Átomo | Descripción |
|-------|------------|
| B48.T20 | `user_mobile_device` DDL + CRUD (T-700) |
| B48.T21 | `ctx_transfer_log` DDL + registro QR/NFC (T-701) |
| B48.T22 | Passkey registration flow: onboarding con huella |
| B48.T23 | QR context transfer: desktop/puerta/caja |

### Fase D — SCIM + Self-Service + IdP

| Átomo | Descripción |
|-------|------------|
| B48.T30 | SCIM v2 `/Users` + `/Groups` (RFC 7644) |
| B48.T31 | `bauth.self.password.change/mfa.enroll/recovery` |
| B48.T35 | `idp_client` (T-702): bAuth como IdP para apps externas |

---

## 9. VENTAJA FRENTE A LA INDUSTRIA

| Capacidad | bAuth | Okta | Auth0 | Keycloak | Azure AD |
|-----------|:---:|:---:|:---:|:---:|:---:|
| Evaluación <0.5ns | ✅ | ❌ | ❌ | ❌ | ❌ |
| 12 dominios simultáneos | ✅ | ❌ | ❌ | ❌ | ❌ |
| BitMask Dual | ✅ | ❌ | ❌ | ❌ | ❌ |
| SoD transaccional + DAG | ✅ | Parcial | ❌ | Parcial | Parcial |
| Doble motor de firmas | ✅ | ❌ | ❌ | ❌ | ❌ |
| Reglas data-driven (260) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Del hogar a la multinacional | ✅ | ❌ | ❌ | ❌ | ❌ |
| Self-hosted (tus datos) | ✅ | ❌ | ❌ | ✅ | ❌ |
| Open source ($0) | ✅ | ❌ | ❌ | ✅ | ❌ |
| SCIM v2 | 🔴 | ✅ | ✅ | ✅ | ✅ |
| SDK multi-lenguaje | 🔴 | ✅ | ✅ | Parcial | ✅ |

---

## 10. MÁS ALLÁ DEL CELULAR: PORTADORES DE IDENTIDAD

**Respuesta corta: No, el celular NO es el único medio.** La industria está convergiendo
hacia un ecosistema de dispositivos portadores de identidad. bAuth debe estar preparado
para soportarlos todos.

### El espectro completo de portadores de identidad

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DISPOSITIVOS PORTADORES DE IDENTIDAD                       │
│                                                                              │
│  ANILLOS       RELOJES       CELULARES     CHIPS       IMPLANTES   TARJETAS │
│  ────────      ───────       ─────────     ─────       ─────────   ──────── │
│  Galaxy Ring   Apple Watch   iPhone        PUF chips   Marcapasos  Smartcard│
│  Oura Ring     Galaxy Watch  Android       TPM 2.0     Neuro-est.  PIV/CAC │
│  Signet Ring   Pixel Watch   Passkeys      Secure Elem Cochlear    X.509   │
│  Dreame Ring   Fitbit        QR/NFC/BLE    YubiKey     Bomba ins.  RFID/NFC│
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                    BAUTH — AGNÓSTICO DE DISPOSITIVO                   │   │
│  │                                                                       │   │
│  │  Registra CUALQUIER dispositivo como portador de ctx_id              │   │
│  │  user_client_device (device_category, platform_authenticator,         │   │
│  │  secure_enclave_available, attestation_provider, trust_score)        │   │
│  │                                                                       │   │
│  │  El ctx_id NO está atado al celular — está atado al USUARIO.         │   │
│  │  El usuario puede autenticarse desde cualquier dispositivo            │   │
│  │  registrado. El ctx_id se transfiere entre dispositivos.              │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 10.1 — Lo que la industria está estandarizando AHORA (2025-2026)

| Estándar | Alcance | Estado | Plazo |
|---------|------|:---:|------|
| **EUDI Wallet (eIDAS 2.0)** | 27 países EU. Billetera digital obligatoria con identidad, licencia de conducir, diplomas, firma electrónica | 🔄 En rollout | Nov 2026 |
| **ISO 18013-5 (mDL)** | Licencia de conducir móvil. Verificación offline vía QR/NFC/BLE. Selective disclosure. | ✅ Publicado | Austria: 800K+ activas |
| **ISO 18013-7 (mDL remote)** | Verificación remota de identidad para KYC bancario, onboarding digital. OpenID4VC. | ✅ Publicado Oct 2024 | US Bank, Chime integrando |
| **FIDO2 CTAP 2.2 Hybrid Transport** | Autenticación cross-device: QR + BLE. Celular autentica en desktop/puerta sin transferir credenciales. | ✅ Publicado | Apple, Google, Microsoft |
| **FIDO Alliance CXP/CXF** | Formato de intercambio de passkeys entre ecosistemas (Apple ↔ Google ↔ 1Password). | 🔄 Draft | 1Password beta, Apple iOS 18.4 |
| **W3C WebAuthn Level 3** | Passkeys device-bound + synced. User verification, attestation, large blob storage. | ✅ Final | Todos los navegadores |
| **OpenID4VC / SD-JWT VC** | Verifiable Credentials con selective disclosure. Zero-knowledge proofs. | ✅ Publicado | EUDI Wallet backbone |
| **IETF SD-JWT VC (draft-13)** | Credenciales verificables en formato JWT con divulgación selectiva. | 🔄 Draft | Mar 2026 |

### 10.2 — Dispositivos portadores de identidad más allá del celular

| Categoría | Dispositivos reales | Tecnología de auth | Caso de uso |
|-----------|-------------------|-------------------|------------|
| **Anillo inteligente** | Samsung Galaxy Ring, Oura Ring, IOST Signet Ring, Dreame Ring | HRV (heartbeat), NFC, PUF chip | Acceso físico sin sacar el celular. Pagos. KYC alternativo. |
| **Reloj inteligente** | Apple Watch, Galaxy Watch, Pixel Watch, Fitbit | FIDO2/WebAuthn, NFC, PPG | Acceso físico, autenticación en desktop cercano, monitoreo continuo de presencia |
| **Chip seguro / PUF** | CLAP memristor, TPM 2.0, Secure Enclave, YubiKey | Physical Unclonable Function, certificados X.509 | Hardware root of trust. Implantes médicos. Dispositivos IoT industriales |
| **Implante médico** | Marcapasos, neuroestimulador, implante coclear, bomba de insulina | ECG-based key gen, blockchain auth | Identidad del paciente. Control de acceso a dispensadores de medicamentos. |
| **Tarjeta inteligente** | PIV/CAC (gobierno), HID Seos (empresarial), Smartcard X.509 | PKI + PIN, RFID/NFC | Acceso físico militar/gubernamental. Firma digital calificada (QES). |
| **Wearable industrial** | Casco inteligente, guante háptico, exoesqueleto ligero | NFC + PUF, BLE proximity | Control de acceso a zonas de producción. Verificación continua de presencia del operador. |

### 10.3 — Señales biométricas emergentes para autenticación continua

| Señal | Dispositivo | Precisión | Uso en auth |
|-------|-----------|:---:|------|
| **PPG (fotopletismografía)** | Reloj, anillo, auricular, smartphone | 95.5% | Cross-device: transfiere auth del celular al wearable por coincidencia de señal PPG |
| **ECG (electrocardiograma)** | Reloj, banda pectoral, implante | 99.56% | Generación de claves criptográficas desde el ritmo cardíaco único |
| **HRV (variabilidad cardíaca)** | Anillo inteligente, reloj | ~95% | Proof-of-personhood. Verificación de identidad sin credenciales explícitas |
| **Gait (marcha)** | Acelerómetro del celular/reloj | ~90% | Autenticación pasiva: ¿es realmente el dueño quien camina con el dispositivo? |
| **Voz** | Micrófono (cualquier dispositivo) | ~85% | Voiceprint como factor adicional. NIST 800-63B-4: PROHIBIDO como único factor en AAL2+. |

### 10.4 — Implicaciones para bAuth

```
HOY:           user_client_device (celular como único portador)
MAÑANA:        user_client_device con device_category = {
                 MOBILE,    // celular/tablet
                 WATCH,     // smartwatch
                 RING,      // anillo inteligente  
                 IMPLANT,   // dispositivo médico implantado
                 CARD,      // tarjeta inteligente
                 WEARABLE,  // casco, guante, exoesqueleto
                 IOT,       // sensor/actuador industrial
                 CHIP       // PUF / secure element standalone
               }

Cada dispositivo:
  • Tiene su propio trust_score (0-100)
  • Soporta diferentes platform_authenticator (FIDO2, PPG, ECG, HRV, PUF, NFC)
  • Puede ser GENERADOR o RECEPTOR de ctx_id
  • Se verifica continuamente (attestation, heartbeat, presencia)
  • Puede transferir ctx_id a otros dispositivos vía QR/NFC/BLE/UWB
```

**Tablas DDL que habilitan esto:**

| Tabla | Propósito |
|-------|------|
| `user_client_device` | Registro de TODOS los dispositivos del usuario, no solo celulares |
| `device_attestation_log` | Verificación de integridad por tipo de dispositivo (Play Integrity, App Attest, PUF challenge) |
| `ctx_transfer_log` | Transferencia de ctx_id entre cualquier par de dispositivos (QR, NFC, BLE, UWB) |
| `mobile_heartbeat_log` | Heartbeat de presencia continua del dispositivo |
| `ath_binding` | Vínculo authenticator↔usuario, agnóstico de tipo de dispositivo |
| `ses_context` | Sesión activa con mobile_device_id (FK a user_client_device) |

### 10.5 — El principio corregido

> **No es "el celular es la llave universal".**
> **Es "el USUARIO es la llave universal, y cualquier dispositivo registrado**
> **puede portar su identidad".**
>
> El celular es el dispositivo más común HOY. Pero bAuth debe estar diseñado
> para que mañana un anillo inteligente, un reloj, o un implante médico
> puedan autenticar con la misma facilidad, usando la misma API,
> contra el mismo Identity Control Plane.

---

## 11. PRINCIPIOS DE DISEÑO IRRENUNCIABLES

| # | Principio |
|---|-----------|
| P1 | El USUARIO es la llave universal — cualquier dispositivo registrado porta su identidad |
| P2 | La biometría NUNCA sale del dispositivo — GDPR Art.9 |
| P3 | El contexto es el producto — no vendemos features, vendemos `bos.GetContext()` |
| P4 | Una sola llamada — sin flags, sin parámetros complejos |
| P5 | El desarrollador no implementa reglas — las consume |
| P6 | 12 dominios de soberanía — evaluación determinista y auditable |
| P7 | Data-driven — sin hardcodear, sin recompilar |
| P8 | Zero Trust — nunca confiar, siempre verificar (NIST 800-207) |
| P9 | Fail-Closed absoluto — ambigüedad = DENEGAR (OWASP ASVS V8.2) |
| P10 | Open source, self-hosted — tus datos, tu infraestructura, tu control |

---

*BAUTH-VISION.md v1.0 — 2026-06-26 — SKULL / SBOS*
*Un solo motor. Una sola DDL. Una sola API. Todos los entornos.*

---

## 12. REGLA DE ACTUALIZACIÓN — SEGUIMIENTO DE OBJETIVOS

**Este documento DEBE actualizarse cada vez que se complete un objetivo de la visión.**

No es un documento estático. Es un **registro vivo del avance** hacia la plataforma
de contexto universal. Cada vez que un átomo, una fase o una capacidad se complete,
este documento debe reflejarlo.

### Tracking de objetivos

| # | Objetivo | Bloque/Átomos | Estado | Fecha | Commit |
|---|----------|:---:|:---:|------|--------|
| 1 | **Token propio de bAuth** — JWT firmado con Ed25519 | B48.T01-T05 | 🔴 | — | — |
| 2 | **SDK Multi-lenguaje** — Go, Python, JS, Java | B48.T10-T13 | 🔴 | — | — |
| 3 | **SCIM v2 Server** — Provisioning automático | B48.T30 | 🔴 | — | — |
| 4 | **User Self-Service** — Password, MFA, Recovery | B48.T31-T34 | 🔴 | — | — |
| 5 | **Universal Identity Hub** — 8 device_category | B48.T60-T66 | 🔴 | — | — |
| 6 | **Kong PEP + OAuth2-Proxy** — Proteger apps sin modificar código | B48.T50-T52 | 🔴 | — | — |
| 7 | **Token Exchange + DPoP** — Delegación segura entre servicios | B48.T40-T42 | 🔴 | — | — |
| 8 | **Hogar inteligente** — RPi 4, 1 usuario, 4 dominios | End-to-end | 🔴 | — | — |
| 9 | **Pequeño negocio** — Mini PC, 8 empleados, 5 dominios | End-to-end | 🔴 | — | — |
| 10 | **PYME** — 2 servidores, 45 empleados, 9 dominios, SOX+ISO | End-to-end | 🔴 | — | — |
| 11 | **Empresa** — K8s 10+ nodos, 3,500 empleados, 12 dominios | End-to-end | 🔴 | — | — |
| 12 | **Gobierno/Defensa** — HSM, air-gap, AAL3, FIPS 140-3 | End-to-end | 🔴 | — | — |
| 13 | **Edificio inteligente** — 30 familias, áreas comunes, visitantes | End-to-end | 🔴 | — | — |
| 14 | **IoT Industrial** — 200 dispositivos M2M, 50 operadores | End-to-end | 🔴 | — | — |

### Procedimiento de actualización

```
Cuando se complete un objetivo:
1. Cambiar estado de 🔴 a ✅ en esta tabla
2. Registrar fecha y commit
3. Actualizar el REGISTRO-ESTADO.md con los átomos completados
4. Si el objetivo completa una fase, marcar la fase como DONE
5. Si se descubre un nuevo objetivo, agregarlo a esta tabla
```

**Regla inmutable:** Este documento es la fuente de verdad de la visión.
Ningún otro documento debe describir "qué es bAuth" o "hacia dónde va".
Si hay conflicto entre este documento y cualquier otro, **este prevalece**.
