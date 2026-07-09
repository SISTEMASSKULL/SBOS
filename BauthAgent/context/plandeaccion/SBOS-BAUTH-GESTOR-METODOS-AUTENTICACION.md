# SBOS — Gestor Centralizado de Métodos de Autenticación
## Investigación Profesional: Orquestación, Políticas, Ciclo de Vida
### SKULL · SBOS · Junio 2026 · v1.0

**Propósito:** Documentar estándares, arquitectura y mejores prácticas para un gestor centralizado de métodos de autenticación (Authentication Orchestration Engine) que administre TOTP, FIDO2, Passkeys, WebAuthn, NFC, QR, Push, SMS y Recovery Codes bajo políticas unificadas.

**Código:** SBOS-BAUTH-GESTOR-METODOS-AUTENTICACION-v1.0
**Complementa:** B9 (Policies), B17 (MFA Policy), B22 (Token Provisioning), B23 (SPIs)

---

## 1. ¿Qué es un Gestor Centralizado de Métodos de Autenticación?

Es un **motor de orquestación** que administra todos los métodos de autenticación disponibles en el sistema bajo un solo plano de control. No es un método más — es la capa que decide **qué método usar, cuándo y para quién**, basándose en políticas, contexto y riesgo.

### 1.1 El Problema que Resuelve

| Sin Gestor Centralizado | Con Gestor Centralizado |
|------------------------|------------------------|
| TOTP configurado en un lugar, FIDO2 en otro, Passkeys en un tercero | Un solo panel de administración para todos los métodos |
| Cada app decide su propio nivel de MFA (inconsistente) | Política unificada: "D3 requiere AAL2, D12-B requiere AAL3" |
| Usuario recibe push + SMS + email para el mismo login (fricción) | Motor adaptativo elige el método óptimo según riesgo |
| Sin visibilidad de qué métodos usa cada usuario | Dashboard: distribución, adopción, anomalías |
| Migrar de SMS a TOTP requiere contacto individual | Política global: "SMS deprecado → migrar usuarios a TOTP en 30 días" |

### 1.2 Referencia de la Industria

Microsoft Entra ID está migrando a un **Authentication Methods Policy** unificado (septiembre 2025) que consolida MFA, SSPR y passwordless bajo una sola política. Keycloak 26.4 introdujo **Conditional Credential Authenticator** que permite flujos condicionales basados en el método usado.

---

## 2. Arquitectura del Gestor de Métodos

```
┌─────────────────────────────────────────────────────────────────┐
│           GESTOR CENTRALIZADO DE MÉTODOS DE AUTENTICACIÓN        │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │              Policy Engine (Motor de Políticas)           │    │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │    │
│  │  │ Tier Policy │  │ Domain Policy│  │ Risk Policy    │  │    │
│  │  │ SU→FIDO2    │  │ D3→TOTP+     │  │ VPN?→OK        │  │    │
│  │  │ N1→TOTP     │  │ D12-B→FIDO2  │  │ New IP?→StepUp │  │    │
│  │  └─────────────┘  └──────────────┘  └────────────────┘  │    │
│  └──────────────────────────────────────────────────────────┘    │
│                              │                                    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │           Method Registry (Registro de Métodos)           │    │
│  │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ │    │
│  │  │TOTP  │ │FIDO2 │ │Passkey│ │NFC  │ │QR    │ │Push  │ │    │
│  │  │RFC   │ │CTAP  │ │WebAuthn│ │NFC  │ │ISO   │ │FCM/  │ │    │
│  │  │6238  │ │2.1   │ │L3     │ │Forum│ │18004 │ │APNs  │ │    │
│  │  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ │    │
│  │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                   │    │
│  │  │SMS*  │ │Email │ │Recovery│ │Biometric│               │    │
│  │  │(dep) │ │      │ │Codes  │ │(Finger, │               │    │
│  │  │      │ │      │ │SHA-256│ │Face)    │               │    │
│  │  └──────┘ └──────┘ └──────┘ └──────┘                   │    │
│  └──────────────────────────────────────────────────────────┘    │
│                              │                                    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │         Lifecycle Manager (Ciclo de Vida)                 │    │
│  │  Enroll → Activate → Use → Rotate → Revoke → Migrate     │    │
│  └──────────────────────────────────────────────────────────┘    │
│                              │                                    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │         Analytics & Compliance (Analíticas)               │    │
│  │  Adoption Rate | Method Distribution | Anomalies | Audit │    │
│  └──────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Catálogo de Métodos de Autenticación

### 3.1 Métodos Soportados

| Método | Estándar | AAL | Phishing-Resistant | Fricción | Estado en SBOS |
|--------|---------|-----|-------------------|---------|---------------|
| **FIDO2/WebAuthn HW Key** | CTAP 2.1, WebAuthn L3 | AAL3 | Sí (origen vinculado) | Baja | B9.T02 |
| **Passkey (Platform)** | WebAuthn L2, FIDO2 | AAL2 | Sí (device-bound) | Muy baja | B9.T03 |
| **TOTP (App Authenticator)** | RFC 6238 | AAL2 | No (phishable OTP) | Media | B22.T03, T08 |
| **HOTP (Hardware Token)** | RFC 4226 | AAL2 | No | Baja | B22.T03 |
| **NFC Tag (NTAG424DNA)** | NFC Forum, ISO 14443 | AAL2 | Sí (Secure Dynamic Messaging) | Baja | B22.T07 |
| **QR Físico (Papel)** | ISO 18004 | AAL1 | No (copia física) | Media | B22.T02 |
| **Push Notification** | FCM, APNs | AAL2 | No (fatiga) | Baja | B22.T09 |
| **SMS OTP** | GSM | AAL1 (DEPRECADO) | No (SIM-swap) | Alta | B22.T09 |
| **Email OTP** | SMTP | AAL1 (DEPRECADO) | No (phishing) | Alta | B22.T09 |
| **Recovery Codes** | SHA-256 | AAL1 | No (single-use) | Alta | B22.T05 |
| **Biométrico (Huella/Rostro)** | FIDO Biometrics | AAL3 | Sí | Muy baja | B5 |
| **Magic Link (Email)** | SMTP + Token URL | AAL1 | No | Media | B22.T05 |

### 3.2 Jerarquía de Preferencia (NIST SP 800-63B Rev.4)

```
1. FIDO2/WebAuthn Hardware Key    (AAL3 — máxima seguridad)
2. Passkey (Platform Authenticator) (AAL2 — phishing-resistant)
3. TOTP via App Authenticator      (AAL2 — requiere posesión)
4. NFC Tag (Secure Dynamic Messaging) (AAL2 — hardware-bound)
5. Push Notification               (AAL2 — conveniente, vulnerable a fatiga)
6. HOTP Hardware Token             (AAL2 — legacy)
7. QR Físico                       (AAL1 — solo para usuarios sin smartphone)
8. SMS OTP                         (AAL1 — DEPRECADO por NIST)
9. Email OTP                       (AAL1 — DEPRECADO por NIST)
```

---

## 4. Motor de Políticas — ¿Qué Método para Quién?

### 4.1 Matriz de Decisión

| Contexto | Método Requerido | Fundamento |
|----------|-----------------|-----------|
| **Superusuario (SU)** | FIDO2 HW Key (AAL3) | Máximo privilegio → máxima seguridad |
| **Admin N1 (S002-S005)** | FIDO2 HW Key o Passkey + TOTP backup | Privilegio elevado |
| **Admin N2 (S006-S015)** | TOTP mínimo, FIDO2 recomendado | Acceso a módulo |
| **Admin N3 (S016-S019)** | TOTP | Acceso a tenant |
| **BIZ N4-N5 (Gerentes)** | TOTP | Operación diaria |
| **BIZ N1-N2 (Operativos)** | TOTP opcional, Passkey | Baja criticidad |
| **EXT N0 (Clientes)** | Passkey opcional | Mínima fricción |
| **D3 — Transacción < $1,000** | TOTP | Umbral bajo |
| **D3 — Transacción > $1,000** | FIDO2 o TOTP + dual-approval | Umbral alto |
| **D3 — Transacción > $10,000** | FIDO2 HW + dual-approval + step-up | Crítico |
| **D12-B — Liquidación < $1,000** | TOTP | |
| **D12-B — Liquidación > $10,000** | FIDO2 HW + dual-approval | |
| **Login desde nueva IP** | Step-Up (TOTP adicional) | Riesgo elevado |
| **Login desde VPN corporativa** | Sin MFA adicional | Confianza de red |
| **Viaje imposible detectado** | Bloquear + FIDO2 requerido | Riesgo crítico |
| **Usuario sin smartphone** | NFC Tag o QR Físico | Inclusión (~40% Bolivia) |

### 4.2 Políticas de Migración

```
SMS → TOTP:     Deprecación progresiva. Notificar 90 días antes.
                Nuevos usuarios: sin opción SMS.
                Existentes: fecha límite para migrar.

TOTP → Passkey: Recomendación proactiva. Mostrar banner en
                portal de autogestión: "¿Sabías que Passkey es
                más seguro y no requiere código?"

Passkey → FIDO2: Para roles SU/N1/N2. La empresa provee el
                hardware key físico.
```

---

## 5. Ciclo de Vida del Método de Autenticación

### 5.1 Estados del Método por Usuario

```
┌──────────┐   enroll()   ┌──────────┐   verify()   ┌──────────┐
│  NONE    │──────────────│ PENDING  │──────────────│  ACTIVE   │
│(sin método)│             │(pendiente │              │(en uso)   │
└──────────┘             │verificar)│              └────┬─────┘
                           └──────────┘                  │
                                                    ┌────┴─────┐
                                                    │          │
                                              revoke()    rotate()
                                                    │          │
                                              ┌─────▼──┐  ┌──▼──────┐
                                              │REVOKED │  │ROTATING │
                                              │(perdida│  │(transic.│
                                              │ robo)  │  │ 24h)    │
                                              └────────┘  └─────────┘
```

### 5.2 Operaciones del Ciclo de Vida

| Operación | Descripción | API |
|-----------|------------|-----|
| `enroll` | Registrar nuevo método para el usuario | `bauth.mfa.enroll(method, params)` |
| `verify` | Verificar que el método funciona (prueba) | `bauth.mfa.verify(method_id, code)` |
| `activate` | Activar método verificado | Automático tras verify exitoso |
| `use` | Usar método en autenticación | Interno durante login |
| `rotate` | Rotar secreto/credencial | `bauth.mfa.rotate(method_id)` |
| `revoke` | Revocar método (pérdida, robo) | `bauth.mfa.revoke(method_id, reason)` |
| `migrate` | Migrar de un método a otro | `bauth.mfa.migrate(user_id, from, to)` |
| `list` | Listar métodos activos del usuario | `bauth.mfa.list(user_id)` |
| `policy` | Consultar política para contexto | `bauth.mfa.policy(user_context)` |

---

## 6. Integración con Keycloak (B23)

El gestor de métodos se integra con Keycloak vía SPIs:

| SPI | Función |
|-----|---------|
| **RolBitMaskProtocolMapper** (SPI 1) | Inyecta `bos_rol_bitmask` + `bos_atom_bitmask` en JWT |
| **StepUpAuthenticator** (SPI 2) | Eleva LoA temporalmente (RFC 9470) |
| **ContinuousVerificationAuthenticator** (SPI 3) | Re-evalúa cada 300s |
| **DomainPolicyEnforcer** (SPI 4) | Evalúa D4/D6/D7 en login |
| **ContextSessionBinder** (SPI 5) | Vincula dctx_id → ctx_id |

El gestor de métodos (nuevo gate B35) orquesta estos SPIs y decide qué método de autenticación se presenta al usuario en cada contexto.

---

## 7. Dashboard de Administración (Core UI)

### 7.1 Vistas del Administrador

1. **Panel de Métodos:** distribución de métodos activos (gráfico de torta: TOTP 60%, FIDO2 15%, Passkey 10%, NFC 8%, QR 5%, SMS 2%)
2. **Tasa de Adopción:** evolución mensual de adopción de métodos phishing-resistant
3. **Usuarios sin MFA:** lista de usuarios sin ningún método MFA activo
4. **Métodos Deprecados:** usuarios que aún usan SMS/Email → plan de migración
5. **Anomalías:** usuario que cambió de método 3 veces en 24h, recovery codes usados fuera de horario
6. **Políticas:** editor visual de la matriz de decisión

### 7.2 Vista del Usuario (Portal de Autogestión)

1. "Mis Métodos de Autenticación" — lista de métodos activos con estado
2. "Agregar Método" — opciones disponibles según tier
3. "Cambiar Método Principal" — elegir preferido
4. "Historial de Uso" — últimos 30 días

---

## 8. Referencias

- [NIST SP 800-63B Rev.4 — Digital Identity Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [Keycloak 26.4 — Passkeys Support](https://www.keycloak.org/2025/09/passkeys-support-26-4)
- [Keycloak — Conditional Authentication Flows](https://www.keycloak.org/docs/latest/server_admin/#_authentication-flows)
- [Microsoft Entra ID — Authentication Methods Policy Migration](https://learn.microsoft.com/en-us/entra/identity/authentication/)
- [IDMWORKS — Authentication Orchestration Best Practices](https://www.idmworks.com/insight/authentication-orchestration/)
- [RFC 9470 — OAuth 2.0 Step-Up Authentication](https://datatracker.ietf.org/doc/rfc9470/)
- [OWASP ASVS V2 — Authentication Verification Requirements](https://github.com/OWASP/ASVS/blob/master/5.0/en/0x11-V2-Authentication.md)
- [CISA Alert AA22-121A — MFA Fatigue Attacks](https://www.cisa.gov/news-events/cybersecurity-advisories/aa22-121a)

---

*SKULL · SBOS · SBOS-BAUTH-GESTOR-METODOS-AUTENTICACION-v1.0 · Junio 2026*
*Confidencial — Propiedad de SKULL Desarrollo de Software*
