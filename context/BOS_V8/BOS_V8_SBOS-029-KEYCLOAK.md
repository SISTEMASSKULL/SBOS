# SBOS-029-KEYCLOAK
## Keycloak: Configuración de Identidad Soberana — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Identidad

| Campo | Valor |
|---|---|
| Servidor lógico | S02 (identityserver) |
| Versión | Keycloak 26.x (Quarkus) |
| Licencia | Apache 2.0 |
| BD | PostgreSQL dedicada |
| Clustering | JDBC-PING (default KC 26+), Infinispan embedded |
| Protocolo | OIDC / OAuth 2.0 / SAML 2.0 |
| Estándares | FAPI 2.0, DPoP (KC 26.4+), Passkeys, WebAuthn |

## 2. Principio Fundamental

> Keycloak verifica la prueba criptográfica de identidad. Lo que está antes — hardware, sensor, PIN, dedo — es responsabilidad del dispositivo del usuario.

KC nunca toca lector de huella, tarjeta física, ni red de telefonía. Recibe una afirmación criptográfica y la valida.

## 3. Best Practices de Producción (KC 26.x + investigación industria)

Según la documentación oficial de Keycloak y prácticas validadas en deployments enterprise:

- **Admin separado del público:** Admin REST API y Console en hostname/context-path diferente al de login flows. Reduce superficie de ataque.
- **TLS obligatorio:** `start` mode requiere HTTPS certificate. Todo tráfico interno y externo cifrado.
- **Reverse proxy:** Kong (SBOS) como gateway. Paths ocultos del público, health checks.
- **Clustering:** mínimo 2 réplicas, JDBC-PING para descubrimiento (nativo KC 26+, sin multicast).
- **BD externa:** PostgreSQL dedicada con connection pooling, backups diarios.
- **Observabilidad:** métricas Prometheus, logs estructurados, alertas antes de que el usuario note.
- **Passkeys (KC 26.4+):** soporte completo, UI condicional y modal, re-autenticación step-up.
- **Kubernetes service accounts:** para autenticación de pods sin distribuir credenciales extra (KC 26.4+).
- **FAPI 2.0 + DPoP:** Financial-grade API con Demonstrating Proof-of-Possession para tokens seguros.

## 4. 16 Métodos de Autenticación en 5 Categorías

### Categoría 1 — Conocimiento (algo que sabes)
| # | Método | KC nativo | Responsabilidad KC |
|---|---|---|---|
| 1 | Username + Password | ✅ | Hash bcrypt/PBKDF2, brute-force protection, políticas |
| 2 | TOTP | ✅ | Secreto compartido, QR, validación tiempo, múltiples dispositivos |
| 3 | HOTP | ✅ | Contador incremental, look-ahead, re-sync |
| 4 | Recovery Codes | ✅ | Hashes de códigos one-time, advertencia cuando quedan pocos |
| 5 | Security Questions | SPI | No recomendado (método débil) |

### Categoría 2 — Posesión (algo que tienes)
| # | Método | KC nativo | Responsabilidad KC |
|---|---|---|---|
| 6 | WebAuthn/FIDO2 (YubiKey) | ✅ | Relying Party, challenges, clave pública, signature counter |
| 7 | Passkeys (sincronizadas) | ✅ (26.4+) | WebAuthn + UI condicional/modal + re-auth step-up |
| 8 | X.509 Client Certificate | ✅ | Valida cert del proxy, CRL/OCSP, Subject DN mapping |
| 9 | Magic Link (email) | ✅ | Token one-time, TTL configurable |
| 10 | SMS OTP | SPI | Requiere proveedor externo (Twilio, AWS SNS) |
| 11 | Email OTP | ✅ (26+) | Código vía email, TTL |

### Categoría 3 — Inherencia (algo que eres)
| # | Método | KC nativo | Responsabilidad KC |
|---|---|---|---|
| 12 | WebAuthn Biométrico | ✅ | userVerification=REQUIRED. KC NUNCA recibe biometría (FIDO2 by design) |

### Categoría 4 — Contexto
| # | Método | KC nativo | Responsabilidad KC |
|---|---|---|---|
| 13 | Kerberos/SPNEGO | ✅ | Ticket validation, keytab, principal mapping |
| 14 | Social/Identity Brokering | ✅ | OIDC/SAML federation, token validation, user mapping |
| 15 | LDAP/AD Federation | ✅ | Bind, sync usuarios/grupos, mapeo atributos |

### Categoría 5 — SPI Custom SBOS
| # | Método | Implementación |
|---|---|---|
| 16 | Cualquier método propio | Authenticator SPI de KC |

## 5. Los 5 SPIs Custom del SBOS

### SPI 1 — BOS-Guard-SPI (el más crítico)
```java
// SkbosGuardAuthenticator — PRIMERO en cada Authentication Flow
// Lee bos_la_available del rol → bloquea métodos no autorizados
// Fallo: ACCESS_DENIED con lista de métodos disponibles
```

### SPI 2 — BOS-FinancialPeriod-SPI
```java
// SkbosFinancialPeriodAuthenticator
// Verifica bos_ft_periods → ventana quincenal
// Fallo: ACCESS_DENIED con próxima ventana (ISO8601)
```

### SPI 3 — BOS-GeoContext-SPI
```java
// SkbosGeoContextAuthenticator
// Compara IP con bos_la_geo y bos_ft_geo del rol
// Fallo: ACCESS_DENIED o challenge para VPN
```

### SPI 4 — BOS-BehavioralScore-SPI
```java
// SkbosBehavioralScoreAuthenticator
// Consulta bos_behavioral_score → si < threshold → deny
```

### SPI 5 — RolFramework SPIs (5 SPIs documentados en SBOS-021)
RolTemporalAuthenticator, RolGeoAuthenticator, RolRoleValidityAuthenticator, RolUserConfiguredCondition, RolStepUpCondition (RFC 9470).

## 6. BD Keycloak — Tablas Relevantes

### USER_ENTITY
```sql
USER_ENTITY (ID UUID PK, USERNAME, EMAIL, EMAIL_VERIFIED, ENABLED,
  FIRST_NAME, LAST_NAME, REALM_ID, CREATED_TIMESTAMP, NOT_BEFORE)
```
Solo datos básicos. Todo lo demás en USER_ATTRIBUTE.

### USER_ATTRIBUTE
```sql
USER_ATTRIBUTE (ID, NAME, VALUE, USER_ID FK, LONG_VALUE TEXT, LONG_VALUE_HASH)
```
Los atributos `bos_*` del SBOS viven aquí. KC 26+ soporta LONG_VALUE sin límite.

### CREDENTIAL
```sql
CREDENTIAL (ID, TYPE, USER_ID FK, USER_LABEL, SECRET_DATA JSON,
  CREDENTIAL_DATA JSON, PRIORITY, CREATED_DATE)
```
Tipos: password, otp, webauthn. Un usuario puede tener múltiples credenciales.

## 7. Mapeo SBOS → KC

| Concepto SBOS | Implementación KC | Responsable |
|---|---|---|
| RolTemplate | Composite Role + Auth Flow + User Attributes | bauth (sync) |
| availableMethods | BOS-Guard-SPI (filtra en login time) | SPI custom |
| requiredMethods | Authentication Flow executions (REQUIRED) | bauth (programa) |
| temporal_control | User attributes → RolTemporalAuthenticator SPI | bauth (escribe) |
| geospatial_control | User attributes → RolGeoAuthenticator SPI | bauth (escribe) |
| validity_period | User attribute → RolRoleValidityAuthenticator SPI | bauth (escribe) |
| session_management | Client session settings nativos KC | bauth (configura) |
| tryton_privileges | Grupos KC → Grupos Tryton (sync bauth) | bauth + Tryton |
| financial_transactions | Auth Flow financiero + BOS-FinancialPeriod-SPI | SPI custom |
| Step-Up (RFC 9470) | acr_values claim → RolStepUpCondition SPI | SPI custom |

## 8. Multi-Tenant por Realm

Cada empresa = un realm KC con separación completa: usuarios, clients, roles, auth flows, sessions. Según mejores prácticas de la industria, realm-per-tenant ofrece el mayor nivel de aislamiento para regulaciones estrictas y necesidades de personalización por cliente.

### Ciclo de vida realm
| Operación | Proceso |
|---|---|
| Alta | Saga 7 pasos: realm → SPIs → usuarios → fichas → BD → estado → evento |
| Suspensión | PUT realm enabled: false → JWTs expiran 5min |
| Baja | Sem -2: notificación + export. Día 1: eliminar namespace + realm + BD |

## 9. Deployment SBOS

| Aspecto | Configuración |
|---|---|
| Runtime | Quarkus (KC 26+) |
| Pod K8s | identityserver namespace, mínimo 2 réplicas |
| BD | PostgreSQL dedicada (sbos-data) |
| Proxy | Kong API Gateway (paths ocultos, TLS termination) |
| Descubrimiento | JDBC-PING (nativo KC 26+, sin multicast) |
| Caché | Infinispan embedded (sesiones distribuidas) |
| Métricas | Prometheus :9000/metrics → Grafana |
| TLS | Obligatorio en producción |

## 10. Scopes OIDC Registrados por SBOS

| Scope | Propósito |
|---|---|
| bos_la_available | Métodos de acceso lógico disponibles |
| bos_la_required | Métodos obligatorios del rol |
| bos_ft_available | Métodos para transacciones financieras |
| bos_bitmask | BitMask 64 bits del usuario |
| ai.chat.use | Chat Open WebUI |
| ai.admin | Gestionar modelos/colecciones |
| ai.observability.read | Ver trazas Langfuse |

---

## §11 — ENRIQUECIMIENTO V5: SPIs Detallados y Análisis por Método

### V5-1: Firma Completa de SPIs Java (desde SBOS-019 v2.0)

**CredentialProvider SPI — extensión para verificación de credenciales:**
```java
// org.keycloak.credential.CredentialProvider<T extends CredentialModel>
public interface CredentialProvider<T extends CredentialModel> {
    String getType();
    boolean isValid(RealmModel realm, UserModel user, CredentialInput input);
    CredentialModel createCredential(RealmModel realm, UserModel user, UserCredentialModel credentialModel);
    boolean deleteCredential(RealmModel realm, UserModel user, String credentialId);
}
```

**WebAuthn Authenticator SPI — autenticación con hardware security keys:**
```java
public interface Authenticator {
    void authenticate(AuthenticationFlowContext context);
    void action(AuthenticationFlowContext context);
    boolean requiresUser();
    boolean configuredFor(KeycloakSession session, RealmModel realm, UserModel user);
    void setRequiredActions(KeycloakSession session, RealmModel realm, UserModel user);
}
```

### V5-2: Detalle de Métodos de Autenticación (desde SBOS-019 v2.0)

**Username + Password:** Base de todos los Authentication Flows. Siempre presente como primer factor. El SBOS usa `username_password` en todos los dominios. Keycloak gestiona hash bcrypt/PBKDF2, brute-force protection, políticas de contraseña, expiración, lista negra de contraseñas comunes.

**TOTP:** `2fa_app` en `requiredMethods` del dominio `logical_access`. Segundo factor estándar para acceso lógico. Algoritmos: SHA1 (default), SHA256, SHA512. Longitud: 6 u 8 dígitos. Intervalo: 30 segundos. Múltiples dispositivos TOTP por usuario con nombres únicos (KC 26.3+).

**WebAuthn/FIDO2:** Actúa como WebAuthn Relying Party (RP). Genera challenges criptográficos. Almacena clave pública del autenticador. Verifica firmas y signature counter (detecta clonación). Gestión y revocación por autenticador.

### V5-3: Mapa Final de Métodos SBOS vs Implementación KC (desde SBOS-019 v2.0)

| Método SBOS | Implementación KC | Categoría |
|---|---|---|
| username_password | Native KC Form Authenticator | Conocimiento |
| 2fa_app | Native KC TOTP Authenticator | Posesión |
| 2fa_sms | SMS OTP via SPI (proveedor externo) | Posesión |
| 2fa_email | Native KC Email OTP (KC 26+) | Posesión |
| 2fa_webauthn | Native KC WebAuthn Authenticator | Posesión/Inherencia |
| 2fa_magic_link | Native KC Magic Link (reset credential) | Posesión |
| 2fa_recovery | Native KC Recovery Codes | Posesión |
| federated_ldap | Native KC LDAP/AD Federation | Contexto |
| federated_social | Native KC Identity Brokering | Contexto |
| kerberos | Native KC Kerberos/SPNEGO | Contexto |
| x509 | Native KC X.509 Client Certificate | Posesión |
| bos_guard | BOS-Guard-SPI (Authenticator SPI) | Custom SBOS |
| bos_financial_period | BOS-FinancialPeriod-SPI (Authenticator SPI) | Custom SBOS |
| bos_geo_context | BOS-GeoContext-SPI (Authenticator SPI) | Custom SBOS |
| bos_behavioral_score | BOS-BehavioralScore-SPI (Authenticator SPI) | Custom SBOS |

---

## §12 — ENRIQUECIMIENTO V7: Keycloak en la Arquitectura de 9 Dominios

### V7-1: Keycloak como Pilar del BC-04 — Identidad (desde V7 Dominios)

Keycloak es la aplicación propietaria del **BC-04 (Identidad)**, que posee las siguientes entidades:
- Usuario del sistema (credenciales, atributos de acceso)
- Rol de negocio y sus permisos (`bos_perm_base`, `bos_perm_ui`, `bos_perm_vdi`)
- Sesión de usuario, token de acceso
- Realm, cliente OIDC
- Política de autenticación contextual

### V7-2: Integración con los 3 DomainMasks (desde V7 Dominios)

Keycloak emite los scopes OIDC que transportan los valores de los tres DomainMasks:

```go
type TokenBitmaskClaims struct {
    PhysicalDomainMask  uint64 `json:"bos_pdm"`  // Acceso físico (escritorio)
    LogicalDomainMask   uint64 `json:"bos_ldm"`  // Acceso lógico (apps, datos)
    FinancialDomainMask uint64 `json:"bos_fdm"`  // Acceso financiero (transacciones)
}
```

Estos claims se inyectan en el JWT vía **User Attribute Mapper** custom de Keycloak, que lee los atributos `bos_*` del usuario desde `USER_ATTRIBUTE` y los serializa como claims numéricos.

### V7-3: Keycloak como Fuente de Verdad del LogicalDomainMask (desde V7 Dominios)

El LogicalDomainMask se calcula en base a los roles del usuario en Keycloak y se sincroniza en los atributos `bos_*`:

| Atributo USER_ATTRIBUTE | Descripción | DomainMask asociado |
|---|---|---|
| `bos_pdm` | PhysicalDomainMask (64-bit entero) | Físico |
| `bos_ldm` | LogicalDomainMask (64-bit entero) | Lógico |
| `bos_fdm` | FinancialDomainMask (64-bit entero) | Financiero |
| `bos_la_available` | Métodos de acceso lógico disponibles | Lógico |
| `bos_la_required` | Métodos obligatorios del rol | Lógico |
| `bos_ft_available` | Métodos para transacciones financieras | Financiero |
| `bos_la_geo` | Restricción geográfica de acceso lógico | Lógico |
| `bos_ft_geo` | Restricción geográfica financiera | Financiero |

### V7-4: Role del Identity Provider en el Contexto de 9 BCs (desde V7 Dominios)

Keycloak (BC-04) mantiene relación **Shared Kernel** con todos los demás bounded contexts a través del JWT. Las relaciones específicas son:

| BC | Relación con BC-04 | Descripción |
|---|---|---|
| BC-01 Financiero | Conformist | Acepta JWT sin reimplementar auth |
| BC-02 RRHH | Partnership | Empleado↔Usuario vinculados por email |
| BC-03 Ventas | Conformist | Acepta JWT de KC para sesiones |
| BC-05 Comunicaciones | Conformist | SSO vía Keycloak |
| BC-06 Reportes | Conformist | Solo lectura, auth vía KC |
| BC-07 IA | ACL | bSearch/Embedding Worker validan realm del JWT |
| BC-09 Plataforma | Shared Kernel infra | IAM Installer configura KC |

---

## §13 — ENRIQUECIMIENTO Smart* (V8)

### V8-1: SmartORC — Criptografía y Autenticación Documental (desde BOSORC-012-CRIPTOGRAFIA.md v2.0)

La arquitectura criptográfica de SmartORC extiende el modelo de autenticación de Keycloak al dominio documental:

**7-step signing flow con RSA-2048 + SHA-256 + Vault KV v2:**
| Paso | Acción | Responsable |
|---|---|---|
| 1. Init | Recepción del documento en ORC | SmartORC |
| 2. Re-auth | Re-autenticación forzada WebAuthn/TOTP | Keycloak |
| 3. DataPack | Construcción del JSON canónico del evento | SmartORC |
| 4. SHA-256 | Hash del DataPack | SmartORC |
| 5. RSA | Firma PKCS1v15 con clave privada del usuario | Vault KMS |
| 6. Atomic persist | Escritura en correspondence_custody | PostgreSQL |
| 7. Notify | Centrifugo push a los involucrados | Centrifugo |

**Context switching en la firma:** El ctx_id capturado en el Step 2 (re-auth) es el autoritativo. Si el ctx_id del JWT inicial difiere del ctx_id de re-authenticación, la firma se rechaza. Esto previene sesiones secuestradas.

**Key rotation policy:**
1. **Active (365 días):** clave en Vault KV v2, usada por ORC para firmar eventos
2. **Retired (día 366+):** movida a path .bvault-keys/ dentro de Vault Transit
3. **Revoked:** destrucción completa de la clave

**VerificationService.Go:**
```go
type VerificationService struct {
    vaultClient *api.Client
}
func (vs *VerificationService) VerifyCustodySignature(
    ctx context.Context, dataPack DataPack, signature string, keyVersion string,
) (bool, error)
```

**8 failure cases:** key not found, signature mismatch, expired key, revoked key, DataPack tampering, user not authenticated, duplicate event, timeout en firma.

### V8-2: SmartORC — Integración Tryton-Keycloak y SPIs (desde BOSORC-013-TRYTON-KEYCLOAK.md)

La integración de SmartORC con Tryton define extensiones ModelSQL/ModelView que complementan la arquitectura de Keycloak:

**Tryton Module — cms_correspondence:**
```python
# ModelSQL extension — hereda de account.invoice y party.party
# SIN modificar tablas nativas de Tryton
class CmsCorrespondence(models.ModelSQL, models.ModelView):
    "Correspondence document with ORC lifecycle"
    __name__ = 'cms.correspondence'
```

**Los 5 SPIs de Keycloak desde la perspectiva ORC:**
| SPI | Tryton Module | Propósito |
|---|---|---|
| BosRolTemplate | party.party extension | Roles base del usuario ORC |
| FinancialDomain | account.invoice | Máscara financiera para firmas ORC |
| PhysicalDomain | Pos (POS) | Máscara física para POS que procesan ORC |
| LogicalDomain | cms.correspondence | Máscara lógica para documentos |
| TemporalContext | cron tasks | Ventanas temporales de firma |

**WebAuthn Level 2 + Passkeys:** Keycloak 26.4+ soporta WebAuthn Level 2 (FIDO2) con biometric como credential type. Passkeys sincronizadas como segundo factor. El hardware security key (YubiKey) se registra como webauthn credential adicional.

**FAPI 2.0 + DPoP:** Financial-grade API con Demonstrating Proof-of-Possession. Implementado para operaciones de alta cuantía (Bit 26: DOC_SIGN de alto valor). DPoP binding entre el token y la clave privada del cliente.

**Multi-tenancy by realm:** Cada empresa/organización = un realm Keycloak separado. Separación completa de usuarios, clients, roles, auth flows y sessions.

**JWT claims para ORC:**
```json
{
  "bos_domains": {
    "logical": "<64-bit LogicalDomainMask>",
    "physical": "<64-bit PhysicalDomainMask>",
    "financial": "<64-bit FinancialDomainMask>"
  },
  "orc_sign_limit": "50000.00",
  "orc_sign_currency": "BOB"
}
```

**Legal framework:** Closed-scope signature (firma en sobre cerrado del contrato) vs state electronic signature (firma con validez estatal tipo Bolivia Ley 164/2011). El JWT con WebAuthn Level 2 cumple con los requisitos de la Ley 164/2011 para firma electrónica en Bolivia.

**Transaction atomicity como garantía legal:** PostgreSQL NOW() en cada firma provee evidencia forense del momento exacto. La firma RSA del DataPack que incluye el timestamp es la garantía de no-repudio.

### V8-3: Plan de Implementación SmartORC — 14 Semanas (desde BOSORC-015-IMPLEMENTACION.md)

El plan de implementación de SmartORC define cómo se integra con Keycloak a través de 4 fases:

| Sprint | Semanas | Alcance Keycloak |
|---|---|---|
| F1 | 1-3 | Creación del cliente OIDC para ORC en Keycloak, atributos `bos_orc_*` en USER_ATTRIBUTE, SPIs BosRolTemplate y TemporalContext configurados |
| F2 | 4-7 | SigningService 7-step completa, re-autenticación WebAuthn en Step 2, claims `orc_sign_limit` y `orc_sign_currency` en JWT |
| F3 | 8-11 | UI de ORC con autenticación biométrica para firmas, Rocket.Chat bot con OIDC de Keycloak |
| F4 | 12-14 | KPIs, 6 tests de seguridad criptográfica (incluyendo verificación de rotación de claves Keycloak), Go-Live |

**Riesgos y mitigaciones relacionadas con Keycloak:**
| Riesgo | Mitigación |
|---|---|
| Key rotation out of sync | Vault KV v2 + cron de verificación diaria |
| WebAuthn timeout en firma | Sesión extendida para operaciones de firma (30min) |
| JWT expiry durante el flujo de firma | Validar JWT al inicio del flujo, no re-validar durante |
| Realm configuration drift | IAM Installer reconciler diario |

### V8-4: Perfiles de Usuario Keycloak para SmartORC (desde BOSORC-003-USUARIOS.md)

5 perfiles de usuario ORC que se mapean a roles y políticas de Keycloak:

| Perfil | Frecuencia | Nivel técnico | Autenticación primaria | Restricciones Keycloak |
|---|---|---|---|---|
| **Recepcionista** | Diario, múltiple | Básico | Password + WebAuthn (fingerprint) | Solo su sucursal, no transferir custodia ajena, no modificar Hoja de Ruta |
| **Funcionario/Analista** | Diario, continuo | Básico-Intermedio | Password + TOTP | Solo documentos bajo su custodia, no modificar clasificación |
| **Gerente/Aprobador** | Diario, sesiones cortas | Básico | WebAuthn (biométrico móvil) | Visibilidad limitada a su empresa y sucursal, puede delegar firma |
| **Admin ORC** | Semanal | Intermedio-Avanzado | Password + TOTP + WebAuthn | Configuración del tenant, gestión de casillas email, grupos y áreas |
| **Auditor** | Esporádico | Básico-Intermedio | Password + TOTP | Solo lectura, acceso a cadena de custodia, exportación de evidencia |

**Mapeo Keycloak para cada perfil:**
- **Recepcionista:** Rol `orc_recepcionista`, requiredMethods: `[username_password, webauthn]`, `bos_la_available` limitado a recepción
- **Funcionario:** Rol `orc_funcionario`, requiredMethods: `[username_password, totp]`, bos_bitmask con DOC_READ + DOC_SIGN
- **Gerente:** Rol `orc_gerente`, requiredMethods: `[username_password, webauthn]`, Step-Up para firmas > límite
- **Admin ORC:** Rol `orc_admin`, requiredMethods: `[username_password, totp, webauthn]`, bos_bitmask con ADMIN_USERS + ADMIN_SYSTEM
- **Auditor:** Rol `orc_auditor`, requiredMethods: `[username_password, totp]`, solo verbos READ/AUDIT

**Casos de uso por perfil que definen las flows de autenticación:**
| UC | Perfil | Flujo de autenticación |
|---|---|---|
| UC-R-01: Registrar correspondencia física | Recepcionista | Password + WebAuthn → ORC crea HR |
| UC-F-04: Transferir custodia | Funcionario | Password + WebAuthn(fingerprint) → RSA firma evento |
| UC-G-02: Aprobar con firma biométrica | Gerente | WebAuthn(móvil unlock) → RSA firma → custodia cambia |
| UC-A-01: Configurar umbrales | Admin ORC | Password + TOTP + WebAuthn → acceso admin |
| UC-AU-01: Consultar cadena de custodia | Auditor | Password + TOTP → solo lectura |

### V8-5: SmartVaultFlow — Identidad, Autenticación y Trazabilidad OAIS (desde BVAULT-003-IDENTIDAD-AUTENTICACION.md)

El modelo de identidad y autenticación del ciclo ORC → bvault define 4 tipos de autenticación que complementan el modelo de Keycloak:

**Los 4 tipos de autenticación en el ciclo documental:**
| Tipo | Descripción | Responsable | Mecanismo |
|---|---|---|---|
| **Tipo A** | Autenticación de identidad del USUARIO | Keycloak 26.x | WebAuthn/Passkeys, TOTP, password+MFA |
| **Tipo B** | Autenticación (no-repudio) de la ACCIÓN | ORC (tránsito), bvault (custodia) | RSA-2048 + SHA-256 + DATA PACK |
| **Tipo C** | Autenticación (integridad) del ARCHIVO | ORC (establece hash), bvault (verifica) | SHA-256 del archivo en Nextcloud |
| **Tipo D** | Autenticación (provenance) del ACTIVO | ORC (establece), bvault (preserva) | Cadena de custodia + metadatos OAIS |

**Arquitectura de identificadores duales:**
```
HR-2026-001847  (ORC — identidad del Productor OAIS)
  ↕ trazabilidad cruzada permanente
BV-2026-000234  (bvault — identidad del Archivo OAIS)
```

Ambos identificadores son inmutables. Keycloak asigna el ctx_id que une ambos sistemas. El SHA-256 (Tipo C) es el "ADN digital" que verifica integridad a lo largo de todo el ciclo.

**Modelo OAIS aplicado (ISO 14721:2012):**
| Concepto OAIS | En SBOS | Auth involucrada |
|---|---|---|
| **Productor** | SmartORC | Keycloack (Tipo A) + RSA (Tipo B) |
| **SIP** | orc_handover payload | SHA-256 (Tipo C) |
| **Archivo** | bvault | Keycloak (Tipo A) + RSA (Tipo B) |
| **AIP** | vault_asset con Vault ID | Preservación Tipo D |
| **DIP** | Documento al destinatario | Tipo A (destinatario) + Tipo C (verificación) |
| **Consumidor** | Destinatario externo | Verificación independiente SHA-256 |

**PREMIS (Library of Congress v3.0):** El `file_hash` de ORC es el PREMIS fixity permanente. bvault verifica ese hash al recibir el SIP y lo preserva. La provenance incluye eventos de custodia, cambios de custodia, y eventos de validación de ambos sistemas.

**ISO 15489-1:2016 — División de responsabilidades:**
| Propiedad | Quién la establece | Quién la preserva |
|---|---|---|
| Autenticidad | ORC (firma + SHA-256 + ctx_id) | bvault (preserva cadena de custodia) |
| Integridad | ORC (file_hash) | bvault (verificación periódica) |
| Usabilidad | ORC (metadatos durante tránsito) | bvault (Ventanilla de Entrega) |

---

## ENRIQUECIMIENTO SBOS (Primera Versión)

### SBOS-019-014-1: Catalogo de Configuracion KC+Kong por App (desde SBOS-019-001-KC-KONG-CATALOG-v1_0.md)

Cada app del stack base tiene un client Keycloak, ruta Kong, BD PostgreSQL y bitmask bAuth que se crean durante la instalacion del producto. Convenciones: Realm `sbos`, Client IDs en lowercase (`tryton`, `orangehrm`), roles por app (`{app}-admin`, `{app}-operator`, `{app}-viewer`), Kong plugins minimos `jwt + rate-limiting + cors`.

**Mapa de rutas, clients y bits:**

| Path | App | KC Client ID | BitMask Bit | Producto | Kong Service |
|------|-----|-------------|:-----------:|----------|-------------|
| `/grafana` | Grafana | grafana | -- | bootstrap | grafana.sbos-monitor.svc:3000 |
| `/pgadmin` | PgAdmin 4 | pgadmin | -- | bootstrap | pgadmin.sbos-data.svc:5050 |
| `/erp` | Tryton ERP | tryton | 2 | erp | tryton.sbos-erp.svc:8000 |
| `/hr` | OrangeHRM | orangehrm | 3 | hr | orangehrm.sbos-apps.svc:80 |
| `/mail` | Roundcube | roundcube | -- | mail | roundcube.sbos-comms.svc:8080 |
| `/postfixadmin` | PostfixAdmin | postfixadmin | -- | mail | postfixadmin.sbos-comms.svc:8080 |
| `/zabbix` | Zabbix | zabbix | -- | monitoring | zabbix.sbos-monitor.svc:8080 |
| `/docs` | Paperless-NGX | paperless | -- | documents | paperless.sbos-docs.svc:8000 |
| `/sign` | DocuSeal | docuseal | -- | documents | docuseal.sbos-docs.svc:3000 |
| `/gitlab` | GitLab CE | gitlab | -- | devops | gitlab.sbos-ops.svc:80 |
| `/ai` | Open WebUI | openwebui | -- | ai | open-webui.sbos-ai.svc:8080 |
| `/desktop` | Kasm (SBOS VDI) | kasm | -- | vdi | kasm.sbos-vdi.svc:443 |

**Roles por app y permisos bAuth:**

| App | Roles KC | Default role | bitmask_bit | Governance |
|-----|----------|:------------:|:-----------:|:----------:|
| Tryton | admin, accountant, sales, warehouse, viewer | viewer | 2 (APP_TRYTON) | Cat 3 (dual approval) |
| OrangeHRM | admin, manager, employee, viewer | employee | 3 (APP_ORANGEHRM) | -- |
| Roundcube | user | user | -- | -- |
| Paperless | admin, editor, viewer | viewer | -- | -- |
| DocuSeal | admin, signer | -- | -- | -- |
| Grafana | admin, editor, viewer | viewer | -- | -- |
| Zabbix | admin, viewer | -- | -- | -- |
| GitLab | admin, developer, viewer | -- | -- | -- |
| Open WebUI | admin, analyst, viewer | -- | -- | -- |
| Kasm VDI | admin, user | -- | -- | -- |

**Apps con BD PostgreSQL dedicada:** Grafana (grafana_db), PgAdmin4 (pgadmin_db), Tryton (tryton_db), Zabbix (zabbix_db), Paperless (paperless_db), DocuSeal (docuseal_db), GitLab (gitlab_db). OrangeHRM usa MySQL con SymmetricDS para sincronizacion a PostgreSQL.

**Apps con Kong plugins especiales:** PgAdmin4 usa `ip-restriction` (solo red interna 10.0.0.0/8). Tryton tiene `rate-limit` de 100/minute.

### SBOS-019-014-2: Detalle de Tablas KC (desde SBOS-020-KC-DataResponses-v2_0.md)

Complemento de las tablas ya documentadas en §6:

**USER_ROLE_MAPPING** -- Relacion muchos-a-muchos: `ROLE_ID (FK KEYCLOAK_ROLE)`, `USER_ID (FK USER_ENTITY)`.

**USER_GROUP_MEMBERSHIP** -- `GROUP_ID (FK KEYCLOAK_GROUP)`, `USER_ID (FK USER_ENTITY)`.

**KEYCLOAK_ROLE** -- `ID, NAME, DESCRIPTION, REALM_ID, CLIENT_ROLE (boolean)`, `CLIENT (FK)`. Los atributos del rol (`bos_la_*`, `bos_ft_*`) viven en **ROLE_ATTRIBUTE**: `ID, ROLE_ID, NAME, VALUE`.

**USER_SESSION** -- Sesiones activas persistidas: `ID (= session_state JWT), AUTH_METHOD, IP_ADDRESS, STARTED, USER_ID, REMEMBER_ME, BROKER_SESSION_ID`.

**Otras tablas relevantes:**
| Tabla | Que guarda |
|-------|-----------|
| KEYCLOAK_GROUP | Definicion de grupos con jerarquia |
| GROUP_ATTRIBUTE | Atributos de grupos (`bos_shift`, `bos_location`) |
| GROUP_ROLE_MAPPING | Roles de cada grupo |
| OFFLINE_USER_SESSION | Sesiones de refresh token de larga duracion |
| ADMIN_EVENT_ENTITY | Auditoria de acciones administrativas |
| EVENT_ENTITY | Eventos de usuario (logins, logouts, errores) |
| RESOURCE_SERVER_POLICY | Politicas de autorizacion |
| AUTHENTICATOR_CONFIG | Configuraciones de Authentication Flows |

### SBOS-019-014-3: Token Responses y Endpoints (desde SBOS-020-KC-DataResponses-v2_0.md)

**Login exitoso** (`POST /realms/{realm}/protocol/openid-connect/token` -> HTTP 200):
```json
{
  "access_token": "eyJ...", "expires_in": 300, "refresh_expires_in": 1800,
  "refresh_token": "eyJ...", "token_type": "Bearer", "id_token": "eyJ...",
  "not-before-policy": 0, "session_state": "uuid",
  "scope": "openid email profile"
}
```

**Access Token claims clave:** `sub` (UUID), `preferred_username`, `realm_access.roles`, `resource_access.{client}.roles`, `groups`, `acr` (1=normal, 2=step-up), `session_state`, mas claims custom SBOS via Protocol Mappers (bos_perm_base, bos_perm_ui, bos_perm_vdi, bos_auth_type, bos_score, bos_vdi, etc.).

**ID Token:** Prueba de identidad para el cliente (navegador/app). No debe enviarse a APIs backend. Contiene `sub, name, email, preferred_username` y `at_hash`.

**Refresh Token:** Opaco, solo para renovar Access Token. Lifespan 30 min default. Nunca enviar a APIs.

**/userinfo** (`GET .../userinfo`, Bearer token): Datos actuales desde BD (no snapshot del JWT). Latencia ~50ms. Usar cuando datos del usuario cambiaron post-login.

**/token/introspect** (`POST .../token/introspect`, Basic client auth): Verifica si token es valido, activo, no revocado. Si valido: `{"active": true, "sub": "...", "username": "..."}`. Si invalido: `{"active": false}`.

### SBOS-019-014-4: Escenarios de Error (desde SBOS-020-KC-DataResponses-v2_0.md)

| Escenario | HTTP | Respuesta |
|-----------|:----:|-----------|
| Credenciales incorrectas | 401 | `{"error": "invalid_grant", "error_description": "Invalid user credentials"}` |
| Cuenta bloqueada (N intentos) | 401 | `{"error": "invalid_grant", "error_description": "Account temporarily disabled"}` |
| Token expirado en API | 401 | `WWW-Authenticate: Bearer error="invalid_token"` (detectado por Kong/app) |
| Token revocado (logout/admin) | 401 | Introspect: `{"active": false}` |
| Usuario deshabilitado | 401 | `{"error": "invalid_grant", "error_description": "Account disabled"}` |
| Firma invalida (tampering) | 401 | `{"error": "invalid_token", "error_description": "Token signature verification failed"}` |
| Sesion expirada (SSO browser) | 302 | Redirect a `/realms/{realm}/protocol/openid-connect/auth?client_id=...` |
| Token valido sin permiso | 403 | Lo da la app/Kong, NO Keycloak: `{"error": "access_denied", "message": "Insufficient permissions"}` |

**Diferencia critica:** 401 = no autenticado. 403 = autenticado pero sin permiso.

### SBOS-019-014-5: Mapa Completo Dato -> Tabla -> Endpoint (desde SBOS-020-KC-DataResponses-v2_0.md)

| Dato | Tabla KC | Endpoint que lo devuelve |
|------|----------|-------------------------|
| UUID del usuario | USER_ENTITY.ID | JWT: sub |
| Username | USER_ENTITY.USERNAME | JWT: preferred_username |
| Email | USER_ENTITY.EMAIL | JWT: email (scope email) |
| Nombre | USER_ENTITY.FIRST_NAME | JWT: given_name (scope profile) |
| Apellido | USER_ENTITY.LAST_NAME | JWT: family_name (scope profile) |
| Roles del realm | USER_ROLE_MAPPING | JWT: realm_access.roles |
| Roles del client | USER_ROLE_MAPPING | JWT: resource_access.{client}.roles |
| Grupos | USER_GROUP_MEMBERSHIP | JWT: groups (con mapper) |
| Atributos custom (bos_*) | USER_ATTRIBUTE | JWT solo con Protocol Mapper |
| Hash de contrasena | CREDENTIAL.SECRET_DATA | Nunca |
| Secreto TOTP | CREDENTIAL.SECRET_DATA | Nunca |
| Clave publica WebAuthn | CREDENTIAL.SECRET_DATA | Nunca |
| Sesion activa | USER_SESSION | JWT: session_state |
| Nivel de autenticacion | Flow evaluado | JWT: acr |
| Metodos auth del rol | ROLE_ATTRIBUTE | JWT con mapper del atributo |

### SBOS-019-014-6: Limites de Acceso del SBOS a Keycloak (desde SBOS-020-KC-DataResponses-v2_0.md)

**Lo que SBOS SI puede leer:**
- JWT claims directamente en la app (sub, roles, grupos, atributos mapeados, exp, acr)
- /userinfo: datos frescos del usuario (cambios post-login)
- /token/introspect: verificar si token fue revocado en tiempo real
- Admin REST API (con credenciales admin): gestion de usuarios, roles, atributos

**Lo que SBOS NUNCA puede leer:**
- Hash de la contrasena del usuario (inaccesible por diseno)
- Secreto TOTP del usuario (inaccesible por diseno)
- Clave privada WebAuthn (nunca llega a Keycloak)
- Datos biometricos (nunca llegan a Keycloak)
- PIN del smart card (nunca llega a Keycloak)

---

## Trazabilidad V8

| Sección | Fuente |
|---|---|
| §1-10 (V6 completo) | BOS_V6_SBOS-029-KEYCLOAK.md |
| §11 V5-1 a V5-3 | BOS_V5_SBOS-019-KC-AuthMethods-v2_0.md |
| §12 V7-1 a V7-4 | BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md |
| §13 V8-1 a V8-5 | SBOS Smart ORC (BOSORC-012-CRIPTOGRAFIA.md v2.0, BOSORC-013-TRYTON-KEYCLOAK.md, BOSORC-015-IMPLEMENTACION.md, BOSORC-003-USUARIOS.md), SBOS Smart Vault Flow (BVAULT-003-IDENTIDAD-AUTENTICACION.md) |
| §14 SBOS-019-014-1 | SBOS-019-001-KC-KONG-CATALOG-v1_0.md | Catalogo de configuracion KC+Kong por app (12 apps), mapa de rutas, roles, bits y productos |
| §14 SBOS-019-014-2 a SBOS-019-014-6 | SBOS-020-KC-DataResponses-v2_0.md | Tablas KC detalladas (USER_ROLE_MAPPING, USER_SESSION, etc.), token responses (access/id/refresh token, /userinfo, /introspect), escenarios de error (7 casos), mapa dato->tabla->endpoint, limites de acceso SBOS |

---

## Fuentas de Enriquecimiento V8

| Fuente | Tipo | Contenido aportado |
|---|---|---|
| BOS_V6_SBOS-029-KEYCLOAK.md | V6 (canonico) | Contenido base completo preservado |
| BOS_V5_SBOS-019-KC-AuthMethods-v2_0.md | V5 | SPIs detallados, metodos de autenticacion, mapa metodos SBOS vs KC |
| BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md | V7 | Keycloak como pilar BC-04, DomainMasks, relacion con 9 BCs |
| SBOS Smart ORC / Smart Vault Flow | Smart* (V8) | Criptografia documental ORC, integracion Tryton-KC, perfiles usuario, OAIS, autenticacion ciclo documental |
| SBOS-019-001-KC-KONG-CATALOG-v1_0.md | SBOS (V8) | Catalogo de configuracion KC+Kong por aplicacion base (12 apps, roles, rutas, bits, BDs) |
| SBOS-020-KC-DataResponses-v2_0.md | SBOS (V8) | Tablas KC detalladas, token responses, escenarios de error, mapa dato->tabla->endpoint, limites de acceso |

---

_SKULL · SBOS · SBOS-029-KEYCLOAK · HUMAN-DOC V8 ENRIQUECIDO · Mayo 2026_
