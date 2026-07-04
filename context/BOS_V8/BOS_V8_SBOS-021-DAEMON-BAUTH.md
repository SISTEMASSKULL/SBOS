# BOS_V8_SBOS-021-DAEMON-BAUTH
## SBOS Auth Enforce: Unified Identity & Permissions Orchestrator — Estándar HUMAN-DOC
### SKULL · SBOS · v1.3 · Junio 2026
### ENRIQUECIDO V8 — V6 + V5 + V7 + Smart* Enrichment + ADR-BAUTH-001 (Rust)

---

> **⚠️ ENMIENDA v1.3 — Junio 2026:** Este documento recibe la enmienda ADR-BAUTH-001 que
> **reemplaza Go por Rust 1.85+** como lenguaje del daemon. La justificación original V6
> (§1: "I/O-bound puro") ha sido revisada y corregida a la luz de benchmarks 2025-2026
> y del diseño final de bAuth con cache Redis y Unix socket. Ver `BAUTH-JUSTIFICACION-RUST.md`
> para el análisis completo. El contenido V6 se preserva como referencia histórica.
>
> **Documentos vinculados a esta enmienda:**
> - `BAUTH-JUSTIFICACION-RUST.md` — ADR-BAUTH-001: evidencia de benchmarks
> - `BAUTH-CONTRATO-SYMBIOSIS.md` — Principio Simbiótico bAuth↔KC↔Tryton
> - `INFORME-COMPONENTES-BAUTH.md` — 10 componentes constitutivos
> - `REGISTRO-ESTADO.md` — 57 átomos en 11 gates (B0–B9 + FICHA)

---

> **ENRIQUECIMIENTO V8:** Este documento consolida el contenido canónico V6 (SBOS-021-DAEMON-BAUTH v1.2) con enriquecimiento de V5 (SBOS-008 ROLFRAMEWORK v2.0, SBOS-008-001 DOMAINS-BITMASK-REALM v1.0, SBOS-009 IDENTITY-CONTRACTS v1.0) y V7 (SBOS-BAUTH-CONCEPTUALIZACION v5.0, SBOS-BAUTH-DECISIONES-ARQUITECTURA v1.0, SBOS-ROLTEMPLATE v5.0, SBOS-USERTEMPLATE v5.0). Contenido V6 preservado íntegramente como referencia histórica. Enmiendas V8 aplicadas como prefacio.

---

## CONTENIDO V6 — PRESERVADO ÍNTEGRAMENTE

<!-- INICIO V6: SBOS-021-DAEMON-BAUTH v1.2 -->

## 1. Identidad del Daemon

| Campo | Valor |
|---|---|
| Nombre | SBOS Auth Enforce |
| Daemon | `bauth` |
| Servicio | `bauth.service` |
| Lenguaje | Go 1.22+ (I/O-bound: HTTP REST a KC, XML-RPC a Tryton, WebSocket a VDI) |
| Unidad declarativa | Ficha auth |
| Directorio | `/etc/bos/blibs/bauth/auths/<nombre_auth>/` |
| Tabla fuente de verdad | `bos_bauth_template` en PostgreSQL |

**⚠️ ENMENDADO v1.3 (Junio 2026):** La justificación original V6 ha sido revisada. El daemon bAuth
ahora se desarrolla en **Rust 1.85+ (Edition 2024, MUSL, LTO, tokio)** por las siguientes razones
documentadas en ADR-BAUTH-001 (`BAUTH-JUSTIFICACION-RUST.md`):

1. **Cache Redis elimina el 95% del I/O:** Con TTL 30s, las consultas de auth no tocan PostgreSQL
   ni Keycloak. El runtime SÍ es el factor dominante en el hot path.
2. **Unix socket sin red TCP:** `/run/bos/bauth.sock` elimina latencia de red. Sin I/O de red,
   el runtime ES el factor dominante.
3. **BitMask es CPU-bound puro:** Operaciones AND NOT sobre 4×uint64 son cero I/O.
4. **GC spikes de Go impactan el P99 de todo el ecosistema:** 28ms P99.9 con GC vs 9ms en Rust
   (3.1× mejor). Cada request del SBOS pasa por bAuth — los spikes se propagan.
5. **Ecosistema unificado con bkernel:** Mismo runtime (tokio), mismos crates, mismo perfil MUSL.

El contenido V6 original se preserva abajo como referencia histórica.

---

## 2. Principio Central: Separación Sincronización vs Login Time

> Keycloak NO consulta el RolTemplate en tiempo de login. bauth TRADUCE el RolTemplate a objetos nativos de KC durante la sincronización — antes de que llegue ningún usuario. En login time KC solo lee su BD interna.

No hay consulta externa durante autenticación, no hay latencia adicional, no hay punto de fallo dependiente del SBOS.

**Tiempo total Guardar → SYNCED: < 5 segundos.**

### Principio de Cero Invasión

| bauth NUNCA hace | bauth SÍ hace |
|---|---|
| Modifica código fuente de Keycloak | Usa Admin API REST de Keycloak |
| Modifica código fuente de Tryton | Usa XML-RPC API de Tryton |
| Agrega triggers a bases de datos | Lee bos_bauth_template vía WAL (bKernel) |
| Intercepta requests HTTP de usuarios | Sincroniza grupos y políticas ANTES de que lleguen |
| Evalúa permisos en tiempo de ejecución | Calcula y sincroniza proactivamente e idempotentemente |

---

## 3. Patrón PAP/PIP/PDP/PEP

| Punto | Función | Implementación SBOS |
|---|---|---|
| PAP | Administra políticas | Core UI (SBOS-007) — formulario RolTemplate/UserTemplate |
| PIP | Datos de políticas | PostgreSQL → `bos_bauth_template` |
| PDP | Decide acceso | Keycloak (autenticación + contexto) + Tryton (enforcement) |
| PEP | Bloquea/permite | Tryton (5 capas nativas) + OAuth2-Proxy (gateway) |

bauth.service es el traductor que mantiene PIP → PDP → PEP permanentemente sincronizados.

---

## 4. Flujo de Sincronización Maestro

```
1. Admin edita RolTemplate en Core UI → INSERT/UPDATE en bos_bauth_template
2. bKernel detecta evento WAL → activa regla ROLF-001 → publica Redis bkernel:identity_events
3. bauth.service consume evento Redis → PrivilegeEngine.calculate(role_id)
   → aplica AND NOT si el rol tiene parent_id → produce máscara binaria final
4. KeycloakSynchronizer.sync_role():
   - Crea/actualiza Composite Role con nombre canónico
   - Genera realm roles atómicos desde máscara (cada bit activo = 1 realm role)
   - Configura Authentication Flow (MFA) por rol
   - Escribe user attributes (horario, geo, vigencia) en cada usuario del rol
   - Configura Session Settings nativos
5. TrytonSynchronizer.sync_groups():
   - Sincroniza 5 niveles de acceso del grupo en Tryton
6. bKernel registra evento en bkernel_db.audit_events (ISO 27001)
7. bauth actualiza sync_status = 'SYNCED' en bos_bauth_template
```

---

## 5. Los 5 SPIs de Keycloak — Firma Java Completa

Los SPIs son authenticators personalizados desplegados como JAR en `providers/`. Implementan `ConditionalAuthenticator` con acceso a `AuthenticationFlowContext`. **Leen atributos del usuario que bauth escribió durante sincronización — no consultan RolTemplate en login time.**

### SPI 1 — RolTemporalAuthenticator

**Responsabilidad:** verifica login en día/hora permitidos por el rol.
**Atributos:** `allowed_days`, `shift_start`, `shift_end`, `timezone`
**Fallo:** `401 — login_outside_allowed_schedule`

```java
public class RolTemporalAuthenticator implements ConditionalAuthenticator {
    public static final String PROVIDER_ID = "rol-temporal-authenticator";

    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        UserModel user = context.getUser();
        String allowedDays = user.getFirstAttribute("allowed_days");
        String shiftStart  = user.getFirstAttribute("shift_start");
        String shiftEnd    = user.getFirstAttribute("shift_end");
        String timezone    = user.getFirstAttribute("timezone");

        if (allowedDays == null || shiftStart == null || shiftEnd == null || timezone == null)
            return true;  // Sin atributos temporales → check no aplica

        ZonedDateTime now = ZonedDateTime.now(ZoneId.of(timezone));
        boolean dayOk  = Arrays.asList(allowedDays.split(","))
                               .contains(now.getDayOfWeek().name());
        boolean timeOk = now.toLocalTime().isAfter(LocalTime.parse(shiftStart))
                      && now.toLocalTime().isBefore(LocalTime.parse(shiftEnd));

        if (!dayOk || !timeOk) {
            context.getEvent().error("login_outside_allowed_schedule");
            return false;
        }
        return true;
    }

    @Override public void authenticate(AuthenticationFlowContext c) { c.attempted(); }
    @Override public boolean requiresUser() { return true; }
    @Override public boolean configuredFor(KeycloakSession s, RealmModel r, UserModel u) {
        return u.getFirstAttribute("allowed_days") != null;
    }
}
```

### SPI 2 — RolGeoAuthenticator

**Responsabilidad:** verifica conexión desde red autorizada.
**Atributos:** `allowed_networks` (CIDRs separados por coma), `require_vpn`, `allowed_vpn_range`
**Fallo:** `401 — login_from_unauthorized_location`

```java
public class RolGeoAuthenticator implements ConditionalAuthenticator {
    public static final String PROVIDER_ID = "rol-geo-authenticator";

    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        UserModel user = context.getUser();
        String allowedNetworks = user.getFirstAttribute("allowed_networks");
        String requireVpn      = user.getFirstAttribute("require_vpn");
        String allowedVpnRange = user.getFirstAttribute("allowed_vpn_range");

        if (allowedNetworks == null) return true;

        String remoteAddr = context.getConnection().getRemoteAddr();
        boolean inAllowed = Arrays.stream(allowedNetworks.split(","))
                                  .anyMatch(cidr -> isInCidr(remoteAddr, cidr.trim()));
        if (inAllowed) return true;

        if ("true".equalsIgnoreCase(requireVpn) && allowedVpnRange != null) {
            if (isInCidr(remoteAddr, allowedVpnRange.trim())) return true;
        }

        context.getEvent().error("login_from_unauthorized_location");
        return false;
    }

    private boolean isInCidr(String ip, String cidr) {
        try {
            String[] parts = cidr.split("/");
            InetAddress network = InetAddress.getByName(parts[0]);
            int prefix = Integer.parseInt(parts[1]);
            InetAddress address = InetAddress.getByName(ip);
            byte[] netBytes  = network.getAddress();
            byte[] addrBytes = address.getAddress();
            if (netBytes.length != addrBytes.length) return false;

            int fullBytes = prefix / 8;
            int remBits   = prefix % 8;
            for (int i = 0; i < fullBytes; i++)
                if (netBytes[i] != addrBytes[i]) return false;
            if (remBits > 0) {
                int mask = (0xFF << (8 - remBits)) & 0xFF;
                return (netBytes[fullBytes] & mask) == (addrBytes[fullBytes] & mask);
            }
            return true;
        } catch (UnknownHostException | NumberFormatException e) { return false; }
    }
}
```

### SPI 3 — RolRoleValidityAuthenticator

**Responsabilidad:** verifica que el rol no ha expirado.
**Atributo:** `role_valid_until` (ISO 8601 UTC)
**Fallo:** `401 — role_expired` → bauth inicia revocación automática en KC y Tryton.

```java
public class RolRoleValidityAuthenticator implements ConditionalAuthenticator {
    public static final String PROVIDER_ID = "rol-role-validity-authenticator";

    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        String validUntil = context.getUser().getFirstAttribute("role_valid_until");
        if (validUntil == null) return true;
        try {
            Instant expiresAt = Instant.parse(validUntil);
            if (Instant.now().isAfter(expiresAt)) {
                context.getEvent().error("role_expired");
                return false;
            }
        } catch (DateTimeParseException e) {
            context.getEvent().detail("warning", "role_valid_until_parse_error:" + validUntil);
        }
        return true;
    }
}
```

### SPI 4 — RolUserConfiguredCondition

**Responsabilidad:** verifica si usuario tiene MFA configurado (OTP o WebAuthn). Actúa como condición del subflow MFA: sin factor registrado → subflow bloqueado → no puede autenticarse con este rol.

```java
public class RolUserConfiguredCondition implements ConditionalAuthenticator {
    public static final String PROVIDER_ID = "rol-user-configured-condition";

    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        UserModel user = context.getUser();
        KeycloakSession sess = context.getSession();
        RealmModel realm = context.getRealm();

        return sess.userCredentialManager()
            .getStoredCredentials(realm, user).stream()
            .anyMatch(c ->
                OTPCredentialModel.TYPE.equals(c.getType()) ||
                WebAuthnCredentialModel.TYPE_TWOFACTOR.equals(c.getType()) ||
                WebAuthnCredentialModel.TYPE_PASSWORDLESS.equals(c.getType())
            );
    }
}
```

### SPI 5 — RolStepUpCondition (RFC 9470)

**Responsabilidad:** evalúa si LoA del token actual satisface el requisito de la operación. Si insuficiente → Keycloak lanza challenge Step-Up (solo factor faltante, sin interrumpir sesión).

```java
public class RolStepUpCondition implements ConditionalAuthenticator {
    public static final String PROVIDER_ID = "rol-step-up-condition";

    private static final Map<String, Integer> LOA_ORDER = Map.of(
        "standard", 1, "elevated", 2, "high_security", 3, "critical", 4
    );

    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        String requiredAcr = context.getAuthenticationSession()
                                    .getClientNote("requested_acr");
        if (requiredAcr == null) return true;

        String currentAcr = AuthenticationManager.getSessionAcr(
            context.getAuthenticationSession());

        int requiredLevel = LOA_ORDER.getOrDefault(requiredAcr, 1);
        int currentLevel  = LOA_ORDER.getOrDefault(currentAcr, 0);
        return currentLevel >= requiredLevel;
    }
}
```

### Niveles de LoA y sus significados operacionales

| LoA | ACR | Requisito | Duración | Uso |
|---|---|---|---|---|
| 1 | standard | pwd + otp | Sesión completa | Operaciones bajo riesgo |
| 2 | elevated | pwd + otp fresco ≤300s | 300s | Pagos >$10k |
| 3 | high_security | pwd + WebAuthn | Solo esa operación | Pagos >$50k |
| 4 | critical | WebAuthn + quórum | Solo esa operación | Cierre fiscal, pagos >$200k |

### Authentication Flow por Rol

```
FLOW: RGV_001_browser_flow
│
├── [ALTERNATIVE] Cookie Check (nativo KC)
│
├── [REQUIRED] Subflow: Credentials
│   ├── [REQUIRED] Username Password Form (nativo KC)
│   └── [REQUIRED] Subflow: MFA
│       ├── [CONDITIONAL] RolUserConfiguredCondition (SPI 4)
│       ├── [ALTERNATIVE] OTP Form (nativo KC)
│       └── [ALTERNATIVE] WebAuthn Authenticator (nativo KC)
│
├── [CONDITIONAL] Subflow: Contextual Checks
│   ├── [CONDITIONAL] RolTemporalAuthenticator (SPI 1)
│   ├── [CONDITIONAL] RolGeoAuthenticator (SPI 2)
│   └── [CONDITIONAL] RolRoleValidityAuthenticator (SPI 3)
│
└── [NATIVE] Session Enforcement
      max_session_duration, inactivity_timeout, concurrent limit
```

---

## 6. Cómo bauth Programa Keycloak (Sincronización)

### Operación 1: Escritura de atributos del usuario

```
PUT /admin/realms/{realm}/users/{userId}
{
  "attributes": {
    "allowed_days":      "MONDAY,WEDNESDAY,FRIDAY",
    "shift_start":       "08:00",
    "shift_end":         "17:00",
    "timezone":          "America/La_Paz",
    "allowed_networks":  "192.168.10.0/24,10.10.0.0/16",
    "require_vpn":       "true",
    "allowed_vpn_range": "10.10.0.0/16",
    "role_valid_until":  "2025-12-31T23:59:59Z"
  }
}
```

### Operación 2: Composite Role por rol

```
POST /admin/realms/{realm}/roles
{ "name": "RGV_001", "composite": true }

POST /admin/realms/{realm}/roles/RGV_001/composites
["SALES_VIEW", "SALES_EDIT", "SALES_APPROVE_50K", "REPORTS_REGIONAL"]
```

Realm roles atómicos generados desde máscara: cada bit activo = un realm role `{MODULO}_{ACCION}`.

### Operación 3: Session settings nativos

| Parámetro RolTemplate | Admin API Keycloak | Evaluado por |
|---|---|---|
| max_session_duration: 28800 | client.session.max.lifespan: 28800 | KC nativo |
| inactivity_timeout: 900 | client.offline.session.idle.timeout: 900 | KC nativo |
| force_logout_at_end_shift: true | Session Lifespan = fin del turno | KC nativo |
| concurrent_sessions_allowed: false | maxSessionCount: 1 | KC nativo |

### Tabla completa: RolTemplate → Keycloak

| Condición RolTemplate | Cómo bauth la escribe en KC | Cómo KC la evalúa | Si falla |
|---|---|---|---|
| requiredMethods (MFA) | Auth Flow con executions REQUIRED | Authenticators nativos OTP/WebAuthn | 401 |
| temporal_control | User attributes: allowed_days, shift_start, shift_end | RolTemporalAuthenticator SPI | 401 |
| geospatial_control | User attributes: allowed_networks, require_vpn | RolGeoAuthenticator SPI | 401 |
| validity_period | User attribute: role_valid_until | RolRoleValidityAuthenticator SPI | 401 |
| max_session_duration | PUT /clients → session.max.lifespan | KC nativo cada request | Expiración 401 |
| concurrent_sessions | PUT /realms → maxSessionCount: 1 | KC nativo al login | 401 |

---

## 7. Tres Dominios de Soberanía

### Dominio Lógico
```yaml
logical:
  allowed_networks: ["10.0.0.0/24", "192.168.1.0/24"]
  allowed_devices: ["registered"]        # registered | any | managed_only
  level_of_assurance: 2                  # 1-4
  allowed_apps:
    - app: "tryton"
      permissions: ["sale.sale:read,write", "party.party:read"]
  session_max_minutes: 480
  concurrent_sessions: 1
```

### Dominio Físico
```yaml
physical:
  allowed_zones:
    - zone_id: "ZONE-VENTAS"
      access_points: ["AP-PUERTA-01", "AP-PUERTA-02"]
  schedule:
    days: ["mon", "tue", "wed", "thu", "fri"]
    time_start: "08:00"
    time_end: "18:00"
    timezone: "America/La_Paz"
  proximity_required: false
  max_failed_physical_attempts: 3
```

### Dominio Financiero
```yaml
financial:
  daily_transaction_limit: 50000         # BOB
  monthly_transaction_limit: 500000
  single_transaction_limit: 10000
  sod_rules:
    - action: "approve_purchase_order"
      cannot_also: "create_purchase_order"
  requires_dual_approval_above: 25000
  currency: "BOB"
```

### Evaluación Combinada
```
Solicitud de acceso
  ├── Dominio Lógico: ¿red? ¿dispositivo? ¿LoA? ¿app?
  │     └── FAIL → deny: "network_not_allowed" | "loa_insufficient"
  ├── Dominio Físico: ¿zona? ¿horario? ¿proximidad?
  │     └── FAIL → deny: "zone_denied" | "outside_schedule"
  ├── Dominio Financiero: ¿límite? ¿SoD?
  │     └── FAIL → deny: "limit_exceeded" | "sod_violation"
  └── TODOS OK → GRANT (generar BitMask)
```

---

## 8. BitMask 64 bits

### TABLA MAESTRA BITMASK 64-bit — Unificación ROLFRAMEWORK + VDI

El BitMask de 64 bits tiene dos capas conceptuales que conviven en el mismo entero. Las capas ERP/Tryton (bits 0–9, definidas por el ROLFRAMEWORK) y VDI/físico/hardware (bits 10–23) no son sistemas distintos — son regiones del mismo valor de 64 bits que bAuth calcula, el JWT transporta y bhnexus/banexus evalúan.

```
CAPA 1 — PERMISOS ERP/TRYTON (bits 0–9):
  Bit 0: PERM_VIEW     — Lectura en Tryton         → ROLE_VIEW, perm_read=True
  Bit 1: PERM_EDIT     — Escritura en Tryton        → ROLE_EDIT, perm_write=True
  Bit 2: PERM_PRINT    — Impresión de reportes      → ROLE_PRINT, acción reporte
  Bit 3: PERM_DELETE   — Eliminación de registros   → ROLE_DELETE, perm_delete=True
  Bit 4: PERM_EXPORT   — Exportación de datos       → ROLE_EXPORT, botón exportar
  Bit 5: PERM_IMPORT   — Importación de datos       → ROLE_IMPORT, botón importar
  Bit 6: PERM_CONFIG   — Configuración del sistema  → ROLE_CONFIG, menú configuración
  Bit 7: PERM_SHARE    — Compartir registros        → ROLE_SHARE, campo compartir
  Bit 8: PERM_BACKUP   — Disparar backup manual     → ROLE_BACKUP, acción backup
  Bit 9: PERM_ARCHIVE  — Archivar registros         → ROLE_ARCHIVE, botón archivar

CAPA 2 — PERMISOS VDI/ESCRITORIO/HARDWARE (bits 10–23):
  Bit 10: SESSION_VALID    — sesión activa y autenticada
  Bit 11: SHELL_UNLOCK     — desbloquear shell de Fedora
  Bit 12: APP_TRYTON       — acceso a Tryton
  Bit 13: APP_ORANGEHRM    — acceso a OrangeHRM
  Bit 14: APP_SALEOR       — acceso a Saleor
  Bit 15: DRAWER_OPEN      — activar relé cajón de dinero
  Bit 16: DOOR_ZONE_A      — abrir puertas Zona A
  Bit 17: DOOR_ZONE_B      — abrir puertas Zona B
  Bit 18: DOOR_ZONE_C      — abrir puertas Zona C (restringida)
  Bit 19: PRINT_ALLOWED    — imprimir documentos físicos
  Bit 20: USB_STORAGE      — acceso USB almacenamiento
  Bit 21: NETWORK_EXTERNAL — acceso internet externo
  Bit 22: VPN_ACCESS       — VPN corporativa
  Bit 23: ADMIN_PANEL      — panel administración

RESERVADOS Y CUSTOM:
  Bits 24-31: RESERVED — extensión dominio lógico
  Bits 32-47: RESERVED — extensión dominio físico
  Bits 48-63: CUSTOM   — definibles por cliente en RolTemplate
```

**Nota de migración:** Los bits de la Capa 2 fueron renumerados respecto al mapa original (que comenzaba en 0). En la Tabla Maestra unificada, los bits ERP ocupan 0–9 y los bits VDI/hardware comienzan en 10. Esta numeración es la canónica para todas las implementaciones nuevas.

### Ejemplo: BitMask de un Vendedor de Tienda

```
Rol: Vendedor de Tienda
Descripción: acceso ERP lectura + cajón + puertas Zona A + impresión + inventario

CAPA ERP (bits 0-9):
  Bit 0: 1  PERM_VIEW      ✓ (puede ver registros Tryton)
  Bit 1: 0  PERM_EDIT      ✗
  Bit 2: 1  PERM_PRINT     ✓ (puede imprimir reportes)
  Bits 3-9: 0              ✗

CAPA VDI/HARDWARE (bits 10-23):
  Bit 10: 1  SESSION_VALID  ✓
  Bit 11: 1  SHELL_UNLOCK   ✓
  Bit 12: 1  APP_TRYTON     ✓ (granularidad por KC)
  Bit 15: 1  DRAWER_OPEN    ✓
  Bit 16: 1  DOOR_ZONE_A    ✓
  Bit 19: 1  PRINT_ALLOWED  ✓

Binario (64 bits, mostrado 32 bajos):
  0000 0000 0001 1101 1100 0000 0000 0101
```

### Operaciones BitMask en Go (bhnexus)

Las tres operaciones fundamentales que bAuth implementa sobre el BitMask de 64 bits:

```go
// Verificar permiso individual
func HasPermission(mask uint64, bit int) bool {
    return (mask & (1 << bit)) != 0
}

// Otorgar permiso
func GrantBit(mask uint64, bit int) uint64 {
    return mask | (1 << bit)
}

// Revocar permiso
func RevokeBit(mask uint64, bit int) uint64 {
    return mask &^ (1 << bit)
}

// Ejemplo: verificar si puede abrir cajón (bit 15 en Tabla Maestra)
if HasPermission(userMask, 15) { // DRAWER_OPEN
    sendActuatorCommand("OPEN_RELAY", nodeId)
}
```

### Herencia AND NOT

Cuando un RolTemplate tiene `parent_id`, bAuth calcula la máscara del hijo quitando bits del padre explícitamente:

```go
// AND NOT → herencia (hijo hereda MENOS que el padre)
func InheritFromParent(parentMask, bitsToRemove uint64) uint64 {
    return parentMask &^ bitsToRemove
}

// Ejemplo:
// Director General (DGV_001): máscara = 0xFFFFFF (todos los permisos)
// Regional Ventas (RGV_001): parent_id = DGV_001
//   → AND NOT quita: PERM_CONFIG (bit 6), ADMIN_PANEL (bit 23)
//   → RGV_001.mask = DGV_001.mask & ~(1<<6 | 1<<23)
```

### OR — Múltiples roles simultáneos

Cuando un usuario tiene dos roles activos a la vez, bAuth los combina por unión:

```go
// OR → usuario con múltiples roles simultáneos (unión de permisos)
func MergeRoles(maskA, maskB uint64) uint64 {
    return maskA | maskB
}

// Ejemplo:
// ROL_VENTAS:  bits activos = PERM_VIEW (0), APP_TRYTON (12), DRAWER_OPEN (15)
// ROL_AUDITOR: bits activos = PERM_VIEW (0), PERM_EXPORT (4), NETWORK_EXTERNAL (21)
// Usuario con ambos: ROL_VENTAS | ROL_AUDITOR = unión de todos los bits activos
```

### AND — Delegaciones temporales (mínimo privilegio)

Cuando un gerente delega temporalmente a un cajero, el resultado es la **intersección** — el delegante opera solo con los permisos que ambos roles tienen en común:

```go
// AND → delegación temporal (intersección = mínimo privilegio)
func DelegateTemporarily(grantorMask, delegateeMask uint64) uint64 {
    return grantorMask & delegateeMask
}

// Ejemplo:
// ROL_GERENTE:  0b1111111111 (todos los permisos)
// ROL_CAJERO:   0b0000110101 (PERM_VIEW, PERM_PRINT, DRAWER_OPEN, SESSION_VALID)
// Delegación:   ROL_GERENTE AND ROL_CAJERO = 0b0000110101
// → El gerente opera SOLO con los permisos del cajero durante la delegación
// → El principio de mínimo privilegio se aplica automáticamente por aritmética

// En bAuth, la delegación temporal crea un RolTemplate transitorio:
// DEL_{AÑO}_{ID}_{USUARIO} con mask = grantorMask & delegateeMask
// válido hasta valid_until, con auto_revoke: true
```

### Flujo BitMask: bAuth → bhnexus → banexus

```
bAuth calcula BitMask → escribe en JWT como claim bos_bitmask
bhnexus recibe JWT → extrae bos_bitmask → empaqueta en frame binario
bhnexus envía frame a banexus del nodo (WebSocket mTLS)
banexus evalúa bits localmente para decisiones de baja latencia:
  HasPermission(mask, 5) → abrir cajón
  HasPermission(mask, 6) → abrir puerta Zona A
  → Sin consultar al servidor — decisión en <1ms
```

### Claims SBOS en el JWT

```json
{
  "sub": "uuid-user",
  "realm_access": { "roles": ["vendedor"] },
  "bos_bitmask": "0x000000000003E627",
  "bos_domains": {
    "logical": { "loa": 2, "apps": ["tryton", "saleor"] },
    "physical": { "zones": ["ZONE-VENTAS"], "schedule": "08:00-18:00" },
    "financial": { "daily_limit": 50000, "sod": ["create_sale"] }
  },
  "bos_node_id": "Ventas-01",
  "bos_template_version": "1.3.2"
}
```

## 9. Las 5 Capas de Enforcement en Tryton

Cinco capas nativas de control de acceso, **estructurales no programáticas**. Si cualquier capa es violada, Tryton lanza excepción antes de ejecutar SQL. Sin bypass posible.

### Capa 0 — Secuencias (ir.sequence.type)

| Recurso de Secuencia | Grupo Autorizado | Si no configurado |
|---|---|---|
| Numeración Facturas Fiscales | FINANCE_INVOICING | Cualquier usuario crea facturas en cualquier serie |
| Numeración Contratos | LEGAL_CONTRACTS | Cualquier usuario genera numeración contrato |
| Órdenes Venta por Región | RGV_001, RGV_002 | Gerente regional usa serie de otra región |

### Capa 1 — Acceso a Modelos (ir.model.access)

| Modelo Tryton | RGV_001 | CAJERO | AUDITOR |
|---|---|---|---|
| sale.order | R✓ W✓ C✓ D✗ | R✓ W✗ C✗ D✗ | R✓ W✗ C✗ D✗ |
| account.invoice | R✓ W✗ C✗ D✗ | R✗ W✗ C✗ D✗ | R✓ W✗ C✗ D✗ |
| account.payment | R✓ W✓ C✓ D✗ | R✓ W✓ C✓ D✗ | R✓ W✗ C✗ D✗ |

### Capa 2 — Menús y Acciones (ir.action.groups)

```
Grupo RGV_001:
  ✓ Ventas > Órdenes de Venta
  ✓ Ventas > Reportes Región Norte
  ✗ Administración > Configuración del Sistema  (invisible)
  ✗ Finanzas > Transferencias Bancarias          (invisible)
```

Menús sin acceso no producen error — simplemente no existen para ese usuario.

### Capa 3 — Acceso a Campos (ir.model.field.access)

| Modelo | Campo | RGV_001 | CAJERO |
|---|---|---|---|
| account.invoice | amount_total | Lectura: ✓ | Lectura: ✗ |
| account.invoice | cost_center | Lectura: ✗ | Lectura: ✗ |
| sale.order | discount | R✓ W✓ | R✓ W✗ |

Campos sin permiso de lectura se eliminan automáticamente de las vistas.

### Capa 4 — Botones y Aprobación (ir.model.button + Button Rules)

| Botón | Condición PYSON | Grupos | Quórum |
|---|---|---|---|
| Confirmar Venta | amount ≤ 50,000 | RGV_001 | 1 |
| Confirmar Transferencia | amount ≤ 10,000 | APPROVER_STANDARD | 1 |
| Confirmar Transferencia | 10,001 ≤ amount ≤ 50,000 | APPROVER_STANDARD | 2 distintos |
| Confirmar Transferencia | amount > 50,000 | FINANCE_DIRECTOR | 1 |
| Cerrar Ejercicio Fiscal | Siempre | CFO_ROLE | 1 + acr=critical |
| Aprobar Nómina | Siempre | HR_DIRECTOR + CFO_ROLE | 2 distintos |

### Capa 5 — Reglas de Registros (ir.rule.group)

Filtra qué registros ve/modifica el usuario. Tryton agrega filtro automáticamente a cada SQL.

```python
# Record Rule para RGV_001:
Modelo: sale.order
Dominio PYSON: [('shop.region', '=', Eval('context', {}).get('user_region', ''))]

# SQL generado automáticamente:
SELECT * FROM sale_order so
  JOIN sale_shop sh ON so.shop = sh.id
WHERE sh.region = 'NORTH'
```

---

## 10. Segregación de Funciones (SoD)

| Función 1 | Función 2 | Riesgo | Implementación |
|---|---|---|---|
| CREATE_VENDOR | APPROVE_PAYMENTS | Proveedor fantasma + autopago | Button Rule: creador ≠ aprobador |
| PAYROLL_INPUT | PAYROLL_APPROVE | Montos manipulados | Dos usuarios obligatorios |
| PURCHASE_REQUEST | PURCHASE_APPROVE | Solicitudes fraudulentas | Creador ≠ aprobador |
| INVOICE_CREATE | INVOICE_POST | Contabilizar sin revisión | Revisor ≠ creador |

---

## 11. Módulo trytond-auth-keycloak (código Python)

```python
class User(metaclass=PoolMeta):
    __name__ = 'res.user'

    @classmethod
    def _login_keycloak(cls, login, parameters):
        token = parameters.get('keycloak_token')
        if not token:
            return None  # Tryton prueba siguiente método (password)

        # PASO 1: Validar firma RSA del JWT con JWKS de KC
        try:
            claims = KeycloakJWTValidator.verify(
                token    = token,
                jwks_url = settings.KEYCLOAK_JWKS_URL,
                audience = settings.KEYCLOAK_CLIENT_ID,
                issuer   = settings.KEYCLOAK_ISSUER
            )
        except InvalidTokenError:
            return None

        # PASO 2: Extraer realm_roles y acr
        realm_roles = claims['realm_access']['roles']
        acr         = claims.get('acr', 'standard')

        # PASO 3: Encontrar o provisionar usuario en Tryton
        user = cls._find_by_keycloak_sub(claims['sub'])
        if not user:
            user = cls._create_from_jwt(claims)  # auto-provisioning

        # PASO 4: Sincronizar grupos por nombre canónico
        Group    = Pool().get('res.group')
        expected = Group.search([('name', 'in', realm_roles)])
        if set(user.groups) != set(expected):
            user.groups = expected
            user.save()

        # PASO 5: Guardar acr en contexto para @require_loa
        Transaction().context.update({'keycloak_acr': acr})

        return user.id  # → Sesión Tryton abierta
```

Validación JWT completa: decode header → kid → JWKS público KC → verificar firma RSA → exp → iss → aud → claims confiables → grupos → sesión.

---

## 12. Flujos de Operación Completos

### Flujo de Login (diagrama completo sync time → login time)

```
═══ TIEMPO DE SINCRONIZACIÓN (admin guarda RolTemplate) ═══════

bos_bauth_template → bKernel WAL → bauth
                              │
              ┌───────────────┴────────────────┐
              ▼                                ▼
    Keycloak Admin API               Tryton XML-RPC
    PUT /users/{id}/attributes       res.group.upsert
      allowed_days, shift_start      ir.model.access
      allowed_networks, require_vpn  ir.action.groups
      role_valid_until               ir.model.field
    PUT /authentication/flows/{rol}  ir.model.button
      SPI 1-5 configurados           ir.rule.group
    PUT /clients → session settings

═══ TIEMPO DE LOGIN (usuario accede) ══════════════════════════

Browser → OAuth2-Proxy → KC ejecuta RGV_001_browser_flow:
  1. UsernamePasswordForm (nativo) → verifica en BD KC
  2. OTP Form (nativo) → verifica TOTP en BD KC
  3. RolTemporalAuthenticator (SPI) → lee user.attribute → OK o 401
  4. RolGeoAuthenticator (SPI) → lee user.attribute → OK o 401
  5. RolRoleValidityAuthenticator (SPI) → lee user.attribute → OK o 401
  6. Session settings (nativo) → concurrencia, duración
  → Todos OK: emite JWT firmado RSA → Browser recibe token
  → Cualquier fallo: 401 — sin JWT — sin acceso

Browser con JWT → Tryton:
  trytond-auth-keycloak._login_keycloak()
  → Valida RSA → extrae realm_roles → asigna grupos → sesión
```

### Flujo Step-Up Authentication

```
1. Usuario LoA 1 → "Confirmar Transferencia $80,000"
2. @require_loa('high_security'): acr='standard' < 'high_security' → StepUpRequiredException
3. KC recibe challenge: acr_values='high_security', max_age=0
4. KC muestra SOLO factor faltante (WebAuthn) — usuario no pierde su trabajo
5. Usuario completa WebAuthn → token con acr='high_security', max_age=0
6. Button Rule: acr ≥ high_security ✓, amount > $50k ✓, FINANCE_APPROVER ✓ → ejecutado
```

---

## 13. Stack Tecnológico bauth

| Componente | Herramienta | Propósito |
|---|---|---|
| Lenguaje | Go 1.22+ | Daemon principal |
| HTTP client KC | net/http + oauth2 | Keycloak Admin REST API |
| XML-RPC client | github.com/kolo/xmlrpc | Tryton user sync |
| WebSocket server | github.com/coder/websocket | Notificaciones sesión SBOS VDI |
| PostgreSQL | github.com/jackc/pgx/v5 | Estado sesiones bauth_db |
| JWT | github.com/golang-jwt/jwt/v5 | Tokens sesión VDI |
| YAML | gopkg.in/yaml.v3 | auth_engine.yml |
| Config | github.com/BurntSushi/toml | bauth.toml |
| Logging | github.com/rs/zerolog | Audit log autenticaciones |
| Testing | go test + testify + WireMock | Mock KC + Tryton |

### Pipeline CI/CD bauth

| Etapa | Comando | Criterio |
|---|---|---|
| Format | gofmt -l . | 0 archivos sin formato |
| Vet | go vet ./... | Sin errores |
| Lint | golangci-lint run | 0 issues |
| Test | go test -race -count=1 ./... | 0 fallos, 0 race conditions |
| Build | go build -ldflags='-s -w' -o bin/ | Binario estático |
| Sign | ed25519 | Firma verificable por bos |

---

## 14. Tabla bos_bauth_template

| Campo | Tipo | Contenido |
|---|---|---|
| id | TEXT PK | Nombre canónico: RGV-001 |
| parent_id | TEXT FK | ID rol padre para AND NOT |
| auth_framework | JSONB | MFA, geo, horario, sesión |
| tryton_privileges | JSONB | 5 niveles acceso Tryton |
| privilege_mask | BIGINT | Máscara calculada (cache) |
| sync_status | TEXT | PENDING / SYNCED / ERROR / DRIFT |

### Nomenclatura del Sistema

| Tipo | Formato | Ejemplos |
|---|---|---|
| Rol jerárquico | {SIGLA}_{NUM} | DGV_001, RGV_001, CAJERO_001 |
| Realm role atómico | {MODULO}_{ACCION} | SALES_VIEW, SALES_APPROVE_50K |
| Rol configuración | CONFIG_{SCOPE} | CONFIG_SYSTEM, CONFIG_REGION |
| Delegación temporal | DEL_{AÑO}_{ID}_{USUARIO} | DEL_2025_001_JUAN |

---

## 15. Idempotencia de Sincronización

```python
# KeycloakSynchronizer:
current  = set(api.get_composite_members(role_id))
expected = set(privilege_set.realm_roles)

to_add    = expected - current   # solo añade lo que falta
to_remove = current - expected   # solo quita lo que sobra

if to_add:    api.add_roles_to_composite(role_id, to_add)
if to_remove: api.remove_roles_from_composite(role_id, to_remove)
# Si to_add == {} y to_remove == {} → cero llamadas API
```

---

## 16. Drift Detection, Troubleshooting y Alertas Wazuh

Reconcile loop cada 60s: estado declarado (RolTemplate) vs estado real (KC Admin API + Tryton SQL). Si drift → auto-corrección → si falla → alerta crítica.

### Tabla de alertas por situación

| Situación | Nivel alerta | Acción |
|---|---|---|
| sync_status = ERROR | MEDIA | Notifica admin |
| sync_status = DRIFT | ALTA | Auto-corrección |
| Drift con permisos de más | CRÍTICA | Re-sync automática + Wazuh SIEM |
| Delegación vencida no revocada | CRÍTICA | Revocación forzada |
| Composite Role modificado en KC sin bauth | CRÍTICA | Re-sync + alerta seguridad |

### Catálogo de Troubleshooting de Sincronización

Guía de diagnóstico y resolución para los errores más frecuentes de sincronización bAuth ↔ Keycloak ↔ Tryton. Cada error incluye el síntoma observable, el comando de diagnóstico y la solución.

| Error | Síntoma observable | Comando de diagnóstico | Solución |
|---|---|---|---|
| `sync_status = ERROR` | `bauth.service` logea exception en cada ciclo de reconciliación (cada 60s) | `journalctl -u bauth.service -n 50 \| grep ERROR` | Revisar conectividad: KC Admin API (puerto 8080/8443) y Tryton XML-RPC (puerto 8000). Verificar credenciales en Vault: `vault kv get secret/tenants/{realm}/svc-bauth` |
| `sync_status = DRIFT` | KC tiene roles que no coinciden con el RolTemplate en `bos_bauth_template` | `bosctl bauth drift list` | `bosctl bauth sync --force {role_id}` — fuerza re-sincronización completa del rol desde cero, sobreescribiendo el estado actual en KC |
| Composite Role faltante en KC | Usuario no puede autenticarse con su rol; KC rechaza el login con error `invalid_grant` o "role not found" | `curl -H "Authorization: Bearer {admin_token}" http://keycloak/admin/realms/{realm}/roles` — verificar que el Composite Role canónico existe | Re-sincronizar: `bosctl bauth sync {role_id}` — bAuth crea el Composite Role y sus realm roles atómicos |
| Atributos de usuario incorrectos | SPI temporal/geo rechaza logins que deberían ser válidos (usuario en horario y red correctos, pero KC devuelve 401 con `login_outside_allowed_schedule`) | `curl -H "Authorization: Bearer {admin_token}" http://keycloak/admin/realms/{realm}/users/{user_id}` — comparar atributos `allowed_days`, `shift_start`, `allowed_networks` con RolTemplate en `bos_bauth_template` | `bosctl bauth sync-user {user_id}` — re-escribe todos los atributos del usuario desde el RolTemplate asignado |
| Grupo Tryton desincronizado | Usuario puede autenticarse vía KC pero no ve los menús/modelos que debería ver en Tryton | Verificar grupos del usuario en Tryton via XML-RPC: `model.execute('tryton_db', uid, 'pass', 'res.user', 'read', [user_id], ['groups'])` | `bosctl bauth sync {role_id} --target=tryton` — re-sincroniza solo el destino Tryton sin tocar KC |
| WAL event perdido | `sync_status` queda en `PENDING` indefinidamente sin avanzar a `SYNCED` | Verificar DLQ de bKernel: `bosctl bkernel dlq list --rule=ROLF-001` | `bosctl bkernel retry --rule=ROLF-001` — reencola el evento de sincronización de identidad |
| BitMask incorrecto en JWT | banexus niega acciones que el usuario debería tener (DRAWER_OPEN, puertas) — el usuario tiene el rol correcto pero los actuadores no responden | `bosctl bauth get-bitmask {user_id}` — comparar bits activos con la Tabla Maestra (§8) y el RolTemplate esperado | `bosctl bauth recalculate-mask {role_id}` — fuerza recálculo de la máscara desde el RolTemplate y re-sincroniza KC |
| Delegación no revocada al vencer | Usuario delegado conserva permisos tras `valid_until` (bAuth debería auto-revocar en ≤60s del ciclo de reconciliación) | `bosctl bauth delegations list --expired` | `bosctl bauth revoke-delegation {delegation_id}` — revocación manual. Si el auto-revoke falla sistemáticamente, revisar `bauth_delegations` en bauth_db: `SELECT * FROM bauth_delegations WHERE status='active' AND valid_until < NOW()` |

**Nota de diagnóstico general:** antes de aplicar cualquier corrección individual, ejecutar `bosctl bauth drift list` para obtener un mapa completo de todos los drifts activos. Corregir primero los de `severity=critical` (permisos de más que el usuario no debería tener) antes que los de `severity=warning` (permisos de menos).

---

## 17. Regla bKernel ROLF-001

```yaml
rule:
  id: "ROLF-001"
  when:
    source: "bos_core"
    table: "bos_bauth_template"
    operation: "INSERT, UPDATE"
  then:
    - action: "plugin"
      name: "bauth_sync"
    - action: "catalog"
      task: "log_audit_event"
```

---

## 18. Provisioning Realm + Onboarding + Identidad Física

### Provisioning Realm Nuevo (6 pasos)
1. Crear realm KC via Admin API
2. Configurar clients (tryton, saleor, sbos-admin, kong)
3. Desplegar 5 SPIs (JARs → providers/)
4. Cargar RolTemplates iniciales (mín. ADMIN_CLIENTE)
5. Sincronizar KC + Tryton (automático via WAL)
6. Primer login admin → configura credenciales → MFA → JWT → acceso

### Ciclo de Vida del Realm

| Operación | Proceso |
|---|---|
| Alta | Saga 7 pasos: realm → SPIs → usuarios → fichas → BD → estado → evento |
| Suspensión | PUT realm enabled: false → JWTs expiran 5min |
| Baja | Sem -2: notificación + export. Día 1: eliminar namespace + realm + BD |

### Delegación Temporal
```yaml
delegations:
  - delegated_to: "maria-uuid"
    role_template: "RGV_001"
    valid_from: "2026-03-15T00:00:00Z"
    valid_until: "2026-03-30T23:59:59Z"
    auto_revoke: true
    requires_approval: true
```

### Identidad Física

**QR Dinámico:** bauth genera user_id + timestamp + HMAC-SHA256. Válido 30s. banexus captura → bhnexus verifica → BitMask.

**NFC/RFID:** tag contiene user_id cifrado AES-256-GCM. Clave Vault, rotada 90 días.

**Biométrico:** lector genera template hash local. banexus envía hash (NUNCA raw biometric) → bhnexus match → BitMask. bhnexus NUNCA almacena templates.

---

<!-- FIN V6 -->

## TRAZABILIDAD V6

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1-4 | SBOS-008 v2.0 | §1-§5 Principio central, PAP/PIP/PDP/PEP, sincronización |
| §5 SPIs | SBOS-008 v2.0 | §4 Los 5 SPIs (código Java completo, javadoc, CIDR eval) |
| §6 Programa KC | SBOS-008 v2.0 | §5 Operaciones 1-3 + tabla responsabilidades |
| §7 Dominios | SBOS-008-001 v1.0 | §1 Los Tres Dominios (YAML completo + evaluación) |
| §8 BitMask — Tabla Maestra | SBOS-COMPLETITUD-v2 §4.2 + ROLFRAMEWORK §1 | Unificación Capa 1 ERP (bits 0–9) + Capa 2 VDI (bits 10–23). Operaciones AND NOT (herencia), OR (múltiples roles), AND (delegaciones temporales mínimo privilegio) |
| §9 5 Capas | SBOS-008 v2.0 | §10 Las 5 capas (tablas CRUD, menús, campos, Button Rules, Record Rules con SQL) |
| §10 SoD | SBOS-008 v2.0 | §9 Segregación funciones |
| §11 trytond | SBOS-008 v2.0 | §5 código Python _login_keycloak completo |
| §12 Login flow | SBOS-008 v2.0 | §8 Flujos (diagrama sync→login, Step-Up completo) |
| §13 Stack | SBOS-008 v2.0 | §10b Stack + CI/CD |
| §14 Tabla | SBOS-008 v2.0 | §11 bos_bauth_template + nomenclatura |
| §15 Idempotencia | SBOS-008 v2.0 | §11 código Python idempotencia |
| §16 Drift + Troubleshooting | SBOS-008 v2.0 + SBOS-COMPLETITUD-v2 §4.4 + ROLFRAMEWORK §14 | §8 Flujo 4, §14 + catálogo completo de troubleshooting (8 errores con síntoma observable, comando de diagnóstico, solución con comandos exactos) |
| §17 Regla | SBOS-008 v2.0 | §9 ROLF-001 |
| §18 Realm | SBOS-008 v2.0 + 008-001 | §12-§13 + §5-§7 |

---

## ENRIQUECIMIENTO V5

### V5-1: Mapa completo de bits del SAM-128 (de SBOS-008-001 v1.0)

Los tres dominios (Lógico, Físico, Financiero) se representan como un mapa de 128 bits (no 64), donde los bits 0–63 corresponden al dominio lógico+físico y los bits 64–127 al dominio financiero+governanza.

**Mapa de bits extendido (bits 64-127):**

```
DOMINIO FINANCIERO (bits 64-95):
  Bits 64-67:  FIN_LIMIT_TIER — nivel de límite transaccional (0-15)
  Bit  68:     FIN_SOD_ACTIVE — SoD activo para este rol
  Bit  69:     FIN_DUAL_CONTROL — operaciones requieren 2 aprobadores
  Bit  70:     FIN_TIMESTAMP_SEAL — transacciones con sello de tiempo
  Bits 71-95:  RESERVADOS para extensiones financieras

DOMINIO GOVERNANZA (bits 96-127):
  Bits 96-98:  GOV_LOA_LEVEL — Level of Assurance (1-4)
  Bit  99:     GOV_AUDIT_ALL — auditoría completa de todas las acciones
  Bit  100:    GOV_AUDIT_FINANCE — auditoría financiera reforzada
  Bit  101:    GOV_IMMUTABLE_LOG — logs inmutables para este actor
  Bit  102:    GOV_ALERT_HIGH — acciones generan alertas de alta prioridad
  Bits 103-127: RESERVADOS (incluyendo bits jurisdiccionales)
```

### V5-2: Flujo de Sincronización Detallado (de SBOS-008 v2.0)

```
FASE 1: DETECCIÓN
  bkernel detecta WAL en bos_bauth_template
  → Compara LSN: skip si ya procesado (exactly-once)
  → Publica Redis: XADD bkernel:identity_events

FASE 2: CÁLCULO (PrivilegeEngine)
  bauth consume Redis → busca RolTemplate en PostgreSQL
  → Si parent_id existe: InheritFromParent() = parent &^ bits_removed
  → Si no parent: base_mask = all_zeros
  → Por cada bit en zones.*.verbs: activar bit correspondiente
  → Por cada bit en tryton_privileges.*: activar bit ERP
  → Calcular FinancialDomainMask por separado
  → Componer SAM-128 final

FASE 3: SYNC KC
  Para cada realm donde el rol está desplegado:
  → PUT /roles: crear/actualizar Composite Role
  → POST /roles/{id}/composites: realm roles atómicos
  → Para usuarios del grupo: PUT atributos
  → Configurar Authentication Flow

FASE 4: SYNC TRYTON
  → res.group: upsert por nombre canónico
  → ir.model.access: permisos CRUD por modelo
  → ir.action.groups: menús visibles
  → ir.model.field.access: campos visibles/editables
  → ir.model.button: Button Rules con PYSON
  → ir.rule.group: Record Rules automáticas

FASE 5: AUDITORÍA
  → bkernel_db.audit_events: INSERT con contexto completo
  → Si error: DLQ + retry (3 intentos: 1s, 5s, 15s)
```

### V5-3: Ciclo de Vida del RolTemplate (de SBOS-009 v1.0)

```
DRAFT (borrador) → REVIEW (revisión) → ACTIVE (activo)
  → DEPRECATED (solo lectura) → ARCHIVED (histórico)

Transiciones:
  DRAFT → REVIEW: admin envía para aprobación
  REVIEW → ACTIVE: N aprobaciones según approval_workflow
  ACTIVE → DEPRECATED: al expirar validity_period.end_date
  DEPRECATED → ARCHIVED: sin usuarios activos asignados
  ACTIVE → DRAFT: solo si 0 usuarios activos
```

---

## ENRIQUECIMIENTO V7

### V7-1: Correcciones Críticas SAM-128 (de V7 BAUTH-CONCEPTUALIZACION v5.0)

La versión V6 utilizaba un BitMask único de 64 bits. El V7 introduce el **BitmaskBundle**: tres registros uint64 independientes que reemplazan el bos_bitmask único.

```go
type BitmaskBundle struct {
    PhysicalDomainMask  uint64 `json:"bos_physical_mask"`   // DOMINIO FÍSICO — evaluado por: banexus
    LogicalDomainMask   uint64 `json:"bos_logical_mask"`    // DOMINIO LÓGICO — evaluado por: LogicalDomainEvaluator
    FinancialDomainMask uint64 `json:"bos_financial_mask,omitempty"` // DOMINIO FINANCIERO
}
```

**Correcciones aplicadas vs V6:**
1. XOR eliminado para SoD → **Conflict Matrix** (evaluada en asignación). XOR puede elevar privilegios involuntariamente.
2. NAND eliminado para KillSwitch → **AND NOT** (`&^`). NAND puede otorgar ALL_PERMISSIONS cuando usuario tiene bits distintos.
3. Bits `GOV_NORMATIVE_BO/AR/MX` eliminados del SAM-128 → pertenecen a `deploy.yml` (corrección J2).
4. `bos_bitmask` único 64 bits reemplazado por **BitmaskBundle** 3×uint64 independientes.
5. `VDIMask` renombrado a `PhysicalDomainMask` y `ERPMask` a `LogicalDomainMask`.

### V7-2: Mapa de Bits PhysicalDomainMask (V7 corregido)

```
PHYSICAL DOMAIN MASK — bos_physical_mask
Zona 1 — Sesión y Shell (bits 0–7):
  Bit 0:  SESSION_VALID          Bit 1:  SHELL_UNLOCK
  Bit 2:  APP_TRYTON             Bit 3:  APP_ORANGEHRM
  Bit 4:  APP_SALEOR             Bit 5:  DRAWER_OPEN
  Bit 6:  APP_FIREFOX            Bit 7:  APP_LIBREOFFICE

Zona 2 — Puertas y Zonas Físicas (bits 8–15):
  Bit 8:  DOOR_ZONE_A            Bit 9:  DOOR_ZONE_B
  Bit 10: DOOR_ZONE_C            Bit 11: DOOR_ZONE_D
  Bit 12: PHY_SECURITY_LEVEL_1   Bit 13: PHY_SECURITY_LEVEL_2
  Bit 14: PHY_SECURITY_LEVEL_3   Bit 15: PHY_SECURITY_LEVEL_4

Zona 3 — Hardware y Red (bits 16–23):
  Bit 16: PRINT_ALLOWED          Bit 17: USB_STORAGE
  Bit 18: NETWORK_EXTERNAL       Bit 19: VPN_ACCESS
  Bit 20: ADMIN_PANEL            Bit 21: APP_THUNDERBIRD
  Bit 22: TERMINAL_POS           Bit 23: CAMERA_VIEW

Zona 4 — Operaciones de Caja (bits 24–31):
  Bit 24: BOS_CAJA_APERTURA      Bit 25: BOS_CAJA_CIERRE
  Bit 26: BOS_CAJA_ARQUEO        Bit 27: PHY_CHECKIN
  Bit 28: PHY_CHECKOUT           Bit 29: PHY_BIOMETRIC_VALID
  Bits 30–31: PHY_CUSTOM_1/2
```

### V7-3: Mapa de Bits LogicalDomainMask (V7 corregido)

```
LOGICAL DOMAIN MASK — bos_logical_mask
Zona CONTABILIDAD (bits 0–3):
  Bit 0: CONTABILIDAD_READ       Bit 1: CONTABILIDAD_WRITE
  Bit 2: CONTABILIDAD_APPROVE    Bit 3: CONTABILIDAD_AUDIT

Zona RRHH (bits 4–7):
  Bit 4: RRHH_READ               Bit 5: RRHH_WRITE
  Bit 6: RRHH_APPROVE            Bit 7: RRHH_AUDIT

Zona VENTAS (bits 8–11):
  Bit 8: VENTAS_READ             Bit 9: VENTAS_WRITE
  Bit 10: VENTAS_APPROVE         Bit 11: VENTAS_AUDIT

Zona SOPORTE (bits 12–15):
  Bit 12: SOPORTE_READ           Bit 13: SOPORTE_WRITE
  Bit 14: SOPORTE_CONFIGURE      Bit 15: SOPORTE_AUDIT

Zona FACTURACIÓN (bits 16–19):
  Bit 16: FACTURACION_READ       Bit 17: FACTURACION_WRITE
  Bit 18: FACTURACION_EMIT       Bit 19: FACTURACION_VOID

Zona REPORTES (bits 20–23):
  Bit 20: REPORTES_READ          Bit 21: REPORTES_EXECUTE
  Bit 22: REPORTES_EXPORT        Bit 23: REPORTES_CONFIGURE

Zona ADMIN SISTEMA (bits 24–27):
  Bit 24: ADMIN_SYSTEM_READ      Bit 25: ADMIN_SYSTEM_WRITE
  Bit 26: ADMIN_USERS            Bit 27: ADMIN_AUDIT

Bit 63: SUPERZONE — NUNCA asignar por RolTemplate
```

### V7-4: GovernanceMask (de V7 BAUTH-CONCEPTUALIZACION v5.0 §8.6)

```
GOVERNANCE MASK — metadata de gobernanza
Zona 1 — Nivel de Autoridad (bits 0–7):
  Bits 0–3:  GOV_LOA_LEVEL       Bits 4–7:  GOV_ROLE_TIER

Zona 2 — Auditoría Forzada (bits 8–15):
  Bit 8:  GOV_AUDIT_ALL          Bit 9:  GOV_AUDIT_FINANCE
  Bit 10: GOV_AUDIT_ACCESS       Bit 11: GOV_AUDIT_CONFIG
  Bit 12: GOV_IMMUTABLE_LOG      Bit 13: GOV_ALERT_HIGH
  Bit 14: GOV_AUDIT_PCI          Bit 15: GOV_AUDIT_GDPR_BIO

Zona 3 — Identidad Especial (bits 16–31):
  Bit 16: GOV_IS_SUPERUSER       Bit 17: GOV_CONTEXT_ACTIVE
  Bit 18: GOV_IS_MACHINE         Bit 19: GOV_EMERGENCY
  Bit 20: GOV_DELEGATE_ACTIVE    Bit 21: GOV_BIOMETRIC_REQ
  Bit 22: GOV_STEP_UP_PENDING    Bits 23–31: GOV_CUSTOM
```

### V7-5: 15 Métodos de Autenticación Canónicos (de V7 BAUTH-CONCEPTUALIZACION v5.0 §6)

| ID Canónico | Categoría | LoA | Phishing-Resistant | NIST SP 800-63B-4 | KC Soporte |
|---|---|---|---|---|---|
| `username_password` | Conocimiento | 1 | No | PERMITTED (mín 8 chars con MFA) | Nativo |
| `totp` | Posesión | 2 | No | PERMITTED (RFC 6238) | Nativo |
| `hotp` | Posesión | 2 | No | PERMITTED (RFC 4226) | Nativo |
| `backup_codes` | Conocimiento | 1 | No | PERMITTED_RECOVERY_ONLY | Nativo |
| `security_questions` | Conocimiento | 0 | No | NOT_RECOMMENDED | Solo SPI |
| `webauthn_roaming` | Posesión | 3 | **Sí** | PERMITTED_AAL3 | Nativo KC 21+ |
| `passkey` | Posesión+Inherencia | 2 | **Sí** | PERMITTED_AAL2 (NIST SP 800-63B-4) | Nativo KC 26.6+ |
| `x509_smartcard` | Posesión+Conocimiento | 3-4 | **Sí** | PERMITTED_AAL3 | Nativo + SPI |
| `magic_link` | Posesión | 1 | No | PERMITTED (TTL 5min) | Nativo |
| `email_otp` | Posesión | 1 | No | RESTRICTED_AS_SOLE_2FA | Nativo KC 26+ |
| `sms_otp` | Posesión | 1 | No | RESTRICTED §5.2.10 | SPI externo |
| `push_notification` | Posesión | 2 | No | PERMITTED | SPI externo |
| `webauthn_platform` | Posesión+Inherencia | 2 | **Sí** | PERMITTED_AAL2 | Nativo KC 21+ |
| `kerberos_spnego` | Posesión | 2 | Sí (red corp.) | PERMITTED | Nativo |
| `federated_identity` | Contexto | Variable | Variable | PERMITTED | Nativo (OIDC/SAML) |

### V7-6: KC 26.6.1 — Versión Canónica (de V7 BAUTH-CONCEPTUALIZACION v5.0 §7.2)

La versión canónica de Keycloak para el SBOS es **26.6.1** (patch de seguridad sobre 26.6.0 — CVE-2026-4366 SSRF y CVE-2026-4633 user enumeration corregidos).

| Versión | Fecha | Relevancia SBOS |
|---|---|---|
| KC 26.4.0 | Sep 2025 | Passkeys production-ready, FAPI 2.0 Final, DPoP (RFC 9449) |
| KC 26.6.0 | 8 Abr 2026 | JWT Auth Grant (RFC 7523) prod, Workflows IGA, Zero-downtime patches |
| **KC 26.6.1** | **~14 Abr 2026** | **VERSIÓN CANÓNICA SBOS — parche CVE-2026-4366 + CVE-2026-4633** |

**Configuración en bauth.toml:**
```toml
[keycloak]
keycloak_version = "26.6.1"   # versión canónica SBOS — NO usar 26.6.0 (CVEs activos)
```

### V7-7: SPI Nombres Actualizados (de V7 BAUTH-CONCEPTUALIZACION v5.0 §12)

Los nombres de los 5 SPIs en V7 fueron actualizados:

| V6 (original) | V7 (actualizado) | Propósito |
|---|---|---|
| RolTemporalAuthenticator | **SkbosGuardAuthenticator** | Filtra métodos no autorizados (BOS-Guard) |
| RolGeoAuthenticator | **SkbosGeoContextAuthenticator** | Verifica IP contra allowed_networks |
| RolRoleValidityAuthenticator | **SkbosFinancialPeriodAuthenticator** | Verifica ventana de operación financiera |
| RolUserConfiguredCondition | **SkbosRoleValidityAuthenticator** | Verifica role_valid_until |
| RolStepUpCondition | **SkbosStepUpCondition** | RFC 9470 Step-Up |

### V7-8: Arquitectura de 6 Capas de Resolución de Contexto (de V7 BAUTH-CONCEPTUALIZACION v5.0 §9)

```
CAPA 1 — TENANT (Soberanía de Infraestructura)
  Control: sbos-admin via bos (IAM Installer)
  Pregunta: "¿Existe este módulo en este servidor SBOS?"

CAPA 2 — EMPRESA (Soberanía de Datos)
  Control: realm Keycloak — un realm por empresa (NIT)
  Pregunta: "¿A qué empresa pertenece este usuario?"

CAPA 3 — ROL (Soberanía Operativa)
  Control: RolTemplate → bAuth → KC Composite Role
  Pregunta: "¿Qué puede hacer un Contador vs un Gerente?"

CAPA 4 — APLICACIÓN / ZONA (Soberanía de Contexto)
  Control: bAuth configura qué zonas tiene el rol habilitadas
  Nota: La zona es ABSTRACTA — "zona_contabilidad", no "Tryton módulo account"
  Pregunta: "¿En qué zona de negocio puede operar?"

CAPA 5 — DOMINIO (Dimensión de Actuación)
  Control: BitmaskBundle calculado por PrivilegeEngine
  Pregunta: "¿En qué dominio (físico/lógico/financiero) puede actuar?"

CAPA 6 — BitmaskBundle (Vector de Ejecución)
  Control: banexus / LogicalEvaluator / FinancialEvaluator evalúan O(1)
  Pregunta: "¿Tiene ESTE bit específico activo en ESTE dominio?"
```

### V7-9: SQL Schema Completo bauth_db (de V7 BAUTH-DECISIONES-ARQUITECTURA v1.0 §6)

```sql
-- RolTemplates con BitmaskBundle (3 columnas uint64)
CREATE TABLE bos_rol_template (
    id              TEXT PRIMARY KEY,
    tenant_id       TEXT NOT NULL,
    empresa_id      TEXT NOT NULL,
    parent_id       TEXT REFERENCES bos_rol_template(id),
    status          TEXT NOT NULL DEFAULT 'DRAFT',
    sam128_physical  BIGINT,    -- PhysicalDomainMask
    sam128_logical   BIGINT,    -- LogicalDomainMask
    sam128_financial BIGINT,    -- FinancialDomainMask
    sam128_governance BIGINT,   -- GovernanceMask
    sync_status     TEXT NOT NULL DEFAULT 'PENDING',
    last_sync_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now(),
    template        JSONB NOT NULL
);

-- Historial inmutable (WORM — ISO 27001 A.8.15)
CREATE TABLE bos_rol_template_history (
    history_id    BIGSERIAL PRIMARY KEY,
    rol_id        TEXT NOT NULL,
    version       TEXT NOT NULL,
    template_snap JSONB NOT NULL,
    changed_by    TEXT NOT NULL,
    changed_at    TIMESTAMPTZ DEFAULT now(),
    change_reason TEXT,
    entry_hash    TEXT  -- SHA-256 para cadena de integridad
);

-- UserTemplates
CREATE TABLE bos_user_template (
    uuid        TEXT PRIMARY KEY,
    username    TEXT NOT NULL,
    email       TEXT NOT NULL,
    tenant_id   TEXT NOT NULL,
    empresa_id  TEXT NOT NULL,
    rol_id      TEXT REFERENCES bos_rol_template(id),
    status      TEXT NOT NULL DEFAULT 'ACTIVE',
    sync_status TEXT NOT NULL DEFAULT 'PENDING',
    kc_user_id  TEXT,
    tryton_user_id INTEGER,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now(),
    template    JSONB NOT NULL,
    UNIQUE (tenant_id, username)
);

-- Hashes biométricos — NUNCA raw biometric (RGPD Art.9)
CREATE TABLE bauth_biometric_templates (
    id                BIGSERIAL PRIMARY KEY,
    user_uuid         TEXT NOT NULL REFERENCES bos_user_template(uuid),
    tenant_id         TEXT NOT NULL,
    biometric_type    TEXT NOT NULL,
    finger            SMALLINT,
    template_hash     BYTEA NOT NULL,
    salt              BYTEA NOT NULL,
    enrollment_policy TEXT NOT NULL DEFAULT 'admin_only',
    liveness_verified BOOLEAN DEFAULT false,
    admin_verified    BOOLEAN DEFAULT false,
    enrolled_at       TIMESTAMPTZ,
    enrolled_by       TEXT,
    revoked_at        TIMESTAMPTZ,
    CONSTRAINT chk_biometric_type CHECK (biometric_type IN ('fingerprint','face','iris','palm_vein')),
    UNIQUE (user_uuid, biometric_type, COALESCE(finger, 0))
);

-- Log de sincronización
CREATE TABLE bauth_sync_log (
    id              BIGSERIAL PRIMARY KEY,
    rol_id          TEXT NOT NULL,
    tenant_id       TEXT NOT NULL,
    sync_type       TEXT NOT NULL,
    triggered_by    TEXT NOT NULL,
    status          TEXT NOT NULL,
    kc_status       TEXT,
    tryton_status   TEXT,
    error_message   TEXT,
    retry_count     INTEGER DEFAULT 0,
    next_retry_at   TIMESTAMPTZ,
    started_at      TIMESTAMPTZ DEFAULT now(),
    completed_at    TIMESTAMPTZ
);
```

### V7-10: Protocolo Unix Socket /run/bos/bauth.sock (de V7 BAUTH-DECISIONES v1.0 §4)

```
Frame format:
  [4 bytes: uint32 big-endian = longitud del payload en bytes]
  [N bytes: JSON payload UTF-8]

Timeout por request: 1000ms (configurable)
Max payload size: 65536 bytes (64KB)
Max conexiones simultáneas: 100
```

**Request:**
```json
{
  "request_id": "uuid-v4",
  "user_id":    "550e8400-e29b-41d4-a716-446655440000",
  "node_id":    "Ventas-01",
  "query_type": "bitmask",
  "timestamp":  "2026-04-15T10:30:00.000Z"
}
```

**Response (granted):**
```json
{
  "request_id": "uuid-v4",
  "granted":    true,
  "bos_physical_mask":  "0x0000000003E60053",
  "bos_logical_mask":   "0x0000000000000303",
  "bos_financial_mask": "0x0000000000506011",
  "bos_context": { "zone_logical": { "ventas": ["READ", "WRITE"] } },
  "ttl_seconds": 28800,
  "timestamp":  "2026-04-15T10:30:00.008Z"
}
```

### V7-11: JWT Enriquecido (de V7 BAUTH-CONCEPTUALIZACION v5.0 §8.8)

```json
{
  "sub": "uuid-cajero",
  "preferred_username": "ivan.cajero",
  "realm_access": {"roles": ["ROL-CAJERO-001"]},
  "bos_physical_mask":  "0x0000000003E60053",
  "bos_logical_mask":   "0x0000000000000303",
  "bos_financial_mask": "0x0000000000506011",
  "bos_context": {
    "zone_logical": {
      "ventas":      ["READ", "WRITE"],
      "facturacion": ["READ", "EMIT"]
    },
    "zone_physical": {
      "pos_caja":    ["EXECUTE", "OPEN"],
      "zone_ventas": ["ACCESS"]
    },
    "zone_financial": {
      "caja":       ["OPEN", "CLOSE"],
      "limit_tier": 2,
      "daily_limit": 10000,
      "currency":   "BOB",
      "sod_active": true
    }
  },
  "bos_governance": {
    "loa_level":        2,
    "role_tier":        "operativo",
    "role_valid_until": "2027-01-01",
    "sod_active":       true,
    "is_superuser":     false,
    "audit_finance":    true
  },
  "bos_node_id":          "Ventas-01",
  "bos_template_version": "3.1.0",
  "acr": "2",
  "amr": ["pwd", "totp"]
}
```

### V7-12: Motor Algebraico Go — Corregido (de V7 BAUTH-CONCEPTUALIZACION v5.0 §8.7)

```go
package bitmask

type BitmaskBundle struct {
    PhysicalDomainMask  uint64 `json:"bos_physical_mask"`
    LogicalDomainMask   uint64 `json:"bos_logical_mask"`
    FinancialDomainMask uint64 `json:"bos_financial_mask,omitempty"`
}

// HasPhysicalPermission — O(1), ~0.45 ns/op, zero allocations
func (b BitmaskBundle) HasPhysicalPermission(bit uint64) bool {
    return b.PhysicalDomainMask & bit != 0
}

// InheritFromParent — AND NOT: H-RBAC con herencia jerárquica
// NUNCA usar XOR (puede otorgar permisos involuntariamente)
func InheritFromParent(parent, bitsToRemove BitmaskBundle) BitmaskBundle {
    return BitmaskBundle{
        PhysicalDomainMask:  parent.PhysicalDomainMask  &^ bitsToRemove.PhysicalDomainMask,
        LogicalDomainMask:   parent.LogicalDomainMask   &^ bitsToRemove.LogicalDomainMask,
        FinancialDomainMask: parent.FinancialDomainMask &^ bitsToRemove.FinancialDomainMask,
    }
}

// MergeRoles — OR: unión de roles activos simultáneamente
// PRE-CONDICIÓN: Conflict Matrix verificada ANTES de llamar esto
func MergeRoles(a, b BitmaskBundle) BitmaskBundle {
    return BitmaskBundle{
        PhysicalDomainMask:  a.PhysicalDomainMask  | b.PhysicalDomainMask,
        LogicalDomainMask:   a.LogicalDomainMask   | b.LogicalDomainMask,
        FinancialDomainMask: a.FinancialDomainMask | b.FinancialDomainMask,
    }
}

// DelegateWithMinPrivilege — AND: delegación con mínimo privilegio
func DelegateWithMinPrivilege(grantor, delegatee BitmaskBundle) BitmaskBundle {
    return BitmaskBundle{
        PhysicalDomainMask:  grantor.PhysicalDomainMask  & delegatee.PhysicalDomainMask,
        LogicalDomainMask:   grantor.LogicalDomainMask   & delegatee.LogicalDomainMask,
        FinancialDomainMask: grantor.FinancialDomainMask & delegatee.FinancialDomainMask,
    }
}

// RevokeEmergency — AND NOT: KillSwitch en emergencia
// NUNCA NAND (puede elevar privilegios)
func RevokeEmergency(current, toRevoke BitmaskBundle) BitmaskBundle {
    return BitmaskBundle{
        PhysicalDomainMask:  current.PhysicalDomainMask  &^ toRevoke.PhysicalDomainMask,
        LogicalDomainMask:   current.LogicalDomainMask   &^ toRevoke.LogicalDomainMask,
        FinancialDomainMask: current.FinancialDomainMask &^ toRevoke.FinancialDomainMask,
    }
}
```

### V7-13: Plan de Escalado Gradual (de V7 BAUTH-CONCEPTUALIZACION v5.0 §19)

```
FASE 1: Desarrollo (VPS 10 — €4.50/mes)
  Contabo: 4 vCPU / 8 GB / 75 GB NVMe
  Capacidad: 5-10 usuarios concurrentes
  Todo en un solo VPS

FASE 2: Staging (VPS 20 — €6.80/mes)
  Contabo: 6 vCPU / 12 GB / 100 GB NVMe
  Capacidad: 20-50 usuarios concurrentes

FASE 3: Producción Small (VPS 30 — €13.70/mes)
  Contabo: 8 vCPU / 24 GB / 200 GB NVMe
  Capacidad: 100-200 usuarios concurrentes

FASE 4: Enterprise (VPS 60+ — €47.70/mes)
  Contabo: 16+ vCPU / 96 GB / 350 GB NVMe
  Capacidad: 500-1000+ usuarios concurrentes
```

### V7-14: Gestión de Emergencias — AssumeTenantContext (de V7 BAUTH-CONCEPTUALIZACION v5.0 §17)

```go
func (b *BAuth) AssumeTenantContext(
    adminUserID string, realmID string, reason string, durationMinutes int,
) (*TenantContext, error) {
    if !b.isGlobalAdmin(adminUserID) {
        return nil, ErrNotAuthorized
    }
    // TTL: mínimo 15 min, máximo 4h
    if durationMinutes < 15 || durationMinutes > 240 {
        return nil, ErrInvalidTTL
    }
    ctx := &TenantContext{
        AdminID:   adminUserID,
        RealmID:   realmID,
        Mask:      BitmaskBundle{
            PhysicalDomainMask:  ^uint64(0),
            LogicalDomainMask:   ^uint64(0),
            FinancialDomainMask: ^uint64(0),
        },
        Reason:    reason,
        ExpiresAt: time.Now().Add(time.Duration(durationMinutes) * time.Minute),
        ContextID: uuid.New().String(),
    }
    // Log inmutable (ISO 27001 A.8.15) → Wazuh alerta HIGH
    b.auditLog.Write(AuditEvent{
        EventType: "superuser_context_assumed",
        AdminID:   adminUserID,
        RealmID:   realmID,
        Reason:    reason,
        Severity:  "HIGH",
    })
    return ctx, nil
}
```

### V7-15: Política de Contraseñas NIST SP 800-63B-4 (de V7 BAUTH-CONCEPTUALIZACION v5.0 §22)

Correcciones J1-J11 integradas desde Plan Consolidado v3.0:

| ID | Corrección |
|---|---|
| J1 | Jurisdicción eliminada del RolTemplate y SAM-128 → movida a `deploy.yml` |
| J2 | Bits GOV_NORMATIVE_BO/AR/MX eliminados del SAM-128 |
| J6 | Longitud mínima: 15 chars (factor único), 8 chars (con MFA) |
| J7 | Rotación periódica de contraseñas: SHALL NOT — solo cambiar ante compromiso |
| J8 | SMS OTP = "Restricted Authenticator" (terminología NIST SP 800-63B-4) |
| J9 | Passkeys = AAL2 válido (NIST SP 800-63B-4 Apéndice B) |
| J10 | email_otp prohibido como único segundo factor |
---

## ENRIQUECIMIENTO Smart* (V8)

### Smart*-1: Modelo de Autenticación TIPO A/B/C/D (desde BVAULT-003 §4.1)

El modelo de autenticación BVAULT-003 define cuatro tipos de autenticación que atraviesan todo el ciclo de vida del documento, complementando el modelo de 5 SPIs de bauth:

| Tipo | Responsabilidad | Implementación | Evaluado por |
|---|---|---|---|
| TIPO A | Identidad del usuario (autenticación en Keycloak) | WebAuthn, TOTP, password + MFA | Keycloak (SPIs 1-5) |
| TIPO B | No repudio (firma RSA-2048+SHA-256 del DATA PACK) | `CanonicalJSON()` + `SignPKCS1v15()` | bVault + bhnexus |
| TIPO C | Integridad del archivo (SHA-256 del contenido) | Hash sobre GZIP output (INVARIANTE_001) | bVault integrity_log |
| TIPO D | Preservación de procedencia (OAIS SIP→AIP→DIP) | bKernel como mediador del handover | bKernel audit_events |

**Flujo completo en autenticación:**
```
1. TIPO A → Usuario autentica en KC (bauth sync + SPIs) → JWT emitido
2. TIPO B → ORC genera DATA PACK con RSA-2048+SHA-256 → bVault verifica
3. TIPO C → Archivo firmado → SHA-256 sobre GZIP → fixity check
4. TIPO D → bKernel media handover ORC→bVault → procedencia preservada
   SIP (ORC genera) → AIP (bVault archiva) → DIP (destinatario consulta)
```

### Smart*-2: OAIS Model (ISO 14721:2012) aplicado a Autenticación (desde BVAULT-003 §3.1)

El modelo OAIS aplicado al flujo de autenticación y autorización en SBOS:

| Fase OAIS | Sistema SBOS | Responsabilidad |
|---|---|---|
| SIP (Submission Information Package) | ORC genera DATA PACK con ctx_id + bos_template_version | SmartORC |
| AIP (Archival Information Package) | bVault recibe, verifica (TIPO B + TIPO C), archiva | bVault + bKernel |
| DIP (Dissemination Information Package) | Destinatario externo consulta vía API con verificación de integridad | bVault API |

**Implicaciones para bauth:**
- El JWT que bauth genera (vía KC) es el vehículo TIPO A que permite la autenticación en ORC para generar el DATA PACK
- El `ctx_id` que bauth propaga en el JWT es el nexo entre la sesión de autenticación y el documento firmado
- La firma TIPO B (RSA-2048+SHA-256) requiere que bauth haya establecido correctamente la identidad del firmante vía SPIs

### Smart*-3: Acoplamiento bVault-bAuth — Bits 25-29 y Tabla vault_integrity_log (desde BVAULT-001)

El sistema bVault depende de bauth para la autenticación de usuarios. Los siguientes bits del PhysicalDomainMask corresponden a operaciones de bVault:

```
Bit 25: BOS_VAULT_READ         — leer documentos del vault
Bit 26: BOS_VAULT_WRITE        — subir documentos al vault
Bit 27: BOS_VAULT_APPROVE      — aprobar flujos de aprobación
Bit 28: BOS_VAULT_AUDIT         — auditar vault (solo lectura logs)
Bit 29: BOS_VAULT_ADMIN        — administrar vault (configurar flujos, rutas)
```

**Integración bAuth → bVault en flujo de firma:**
```
1. bauth autentica usuario (TIPO A) → JWT con bits vault
2. smartORC verifica JWT → permite firma digital
3. bVault registra DATA PACK en vault_assets
4. bKernel detecta INSERT en vault_assets → audit_events
5. bauth reconcilia credenciales_compliance si aplica
```

**Tabla vault_integrity_log (PostgreSQL 17):**
```sql
CREATE TABLE vault_integrity_log (
    id BIGSERIAL PRIMARY KEY,
    asset_id TEXT NOT NULL,
    event_type TEXT NOT NULL,       -- upload | sign | approve | reject | verify | audit
    performed_by TEXT NOT NULL,
    ctx_id TEXT,
    sha256_hex TEXT NOT NULL,
    tstamp TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (asset_id) REFERENCES vault_assets(id)
);
```

### Smart*-4: DATA PACK y Criptografía (desde BOSORC-012, BVAULT-001)

**Estructura del DATA PACK para no repudio (TIPO B):**

```go
type DataPack struct {
    ObjectID    string `json:"object_id"`              // UUID del documento
    ObjectHash  string `json:"object_hash"`            // SHA-256 del contenido
    SignedBy    string `json:"signed_by"`              // KC user UUID
    SignedAt    string `json:"signed_at"`              // PostgreSQL NOW()
    Signature   string `json:"signature"`              // RSA-2048 PKCS1v15
    Certificate string `json:"certificate"`             // X.509 del firmante
    ctx_id      string `json:"ctx_id"`                  // Context Plane ID
    Version     string `json:"version"`                 // Versión del template
    Algorithm   string `json:"algorithm"`               // SHA256withRSA
    PrevHash    string `json:"prev_hash"`               // Hash del DATA PACK anterior (cadena)
}
```

**Rotación de llaves RSA-2048 (política obligatoria):**
- Periodo de rotación: 365 días
- Llaves activas en Vault KV v2 (KEK cifrado con AES-256-GCM via Vault Transit Engine)
- Llaves retiradas archivadas en bVault con metadatos de periodo de validez
- La verificación de firmas históricas usa el key_id versionado
- El KEK nunca sale de Vault Transit — PEM en claro nunca toca disco (SBOS-VAULT-008)

**Flujo de firma de 7 pasos:**
```
1. ORC serializa documento → CanonicalJSON() (orden alfabético, sin espacios)
2. ORC solicita llave firmadora a Vault → KEK decifra RSA privada en memoria
3. ORC genera Hash = SHA-256(CanonicalJSON(documento))
4. ORC firma: SignPKCS1v15(priv_key, Hash)
5. ORC construye DATA PACK con los 10 campos
6. ORC envía DATA PACK + documento a bVault vía REST mTLS
7. bVault verifica: (a) Hash coincide con documento, (b) Firma RSA válida, (c) ctx_id activo
   → Si OK: vault_integrity_log INSERT + bKernel detecta WAL y propaga
```

### Smart*-5: FAPI 2.0, DPoP y WebAuthn+Passkeys (desde BOSORC-013)

**Integración de SmartORC con los 5 SPIs de bauth:**

| SPI bauth | Método SmartORC | Propósito |
|---|---|---|
| RolTemporalAuthenticator | Horario laboral del firmante | No firmas fuera del horario asignado |
| RolGeoAuthenticator | IP del dispositivo de firma | No firmas desde ubicaciones no autorizadas |
| RolRoleValidityAuthenticator | Vigencia del perfil firmante | No firmas con rol vencido |
| RolUserConfiguredCondition | WebAuthn/Passkey registrados | Firma solo si tiene método biométrico registrado |
| RolStepUpCondition | FAPI 2.0 + DPoP para alto valor | Step-Up a WebAuthn para documentos críticos |

**Campos JWT específicos de SmartORC:**
```json
{
  "smartorc_role": "firmante_autorizado",
  "orc_sign_limit": 50,
  "orc_pending_signatures": 12,
  "firma_ambito": "cerrado"  // "cerrado" | "estatal"
}
```

**Firma de ámbito cerrado vs firma estatal:**
- `firma_ambito = "cerrado"`: operaciones dentro de la misma empresa. No requiere validación externa.
- `firma_ambito = "estatal"`: operaciones que cruzan frontera organizacional. Requiere validación adicional (quórum, acr=critical, auditoría externa).

**Atomicidad como garantía legal (BOSORC-013):**
La operación de firma es atómica en PostgreSQL — signed_at usa `NOW()` del servidor, nunca timestamp del cliente. Esto garantiza la secuencia legal de eventos: primero se autentica, luego firma, y el orden es verificable por auditoría externa.

### Smart*-6: Context Plane — ctx_id y Context Registry (desde SBOS-049)

**Arquitectura de propagación de contexto (responsabilidad de bos IAM Installer):**

```yaml
Flujo completo de ctx_id:
  1. POS Lógico inicia sesión → KC emite JWT con ctx_id en claim
  2. bos IAM Installer inyecta ctx_id en headers OTel Baggage + W3C Trace Context
  3. Cada microservicio propaga ctx_id en sus llamadas internas
  4. bKernel registra ctx_id en context_sessions al procesar eventos WAL
  5. Context Registry en Redis mantiene estado activo de contexto
```

**Tabla context_sessions en bkernel_db:**
```sql
CREATE TABLE context_sessions (
    ctx_id UUID PRIMARY KEY,
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    tenant_id TEXT NOT NULL,
    pos_logico_id TEXT,
    pos_fisico_id TEXT,
    device_id TEXT,
    auth_method TEXT,
    loa_level INTEGER,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    last_active_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    metadata JSONB
);
```

**Evento context.promoted:**
```json
{
  "event_type": "context.promoted",
  "ctx_id": "uuid",
  "user_id": "kc-user-uuid",
  "device_id": "POS-01",
  "auth_method": "password+webauthn",
  "loa": 3,
  "tenant_id": "acme-nit"
}
```

### Smart*-7: 8 Perfiles de Usuario bVault (desde SBOS-VAULT-003)

bauth debe sincronizar los siguientes perfiles como RolTemplates predefinidos para interoperar con bVault:

| Perfil bVault | RolTemplate SBOS | LoA Mínimo | Bits Vault Requeridos |
|---|---|---|---|
| Gestor Documental | VAULT-DOC-MGR-001 | 2 | BOS_VAULT_READ + BOS_VAULT_WRITE |
| Firmante/Aprobador | VAULT-SIGNER-001 | 3 | BOS_VAULT_READ + BOS_VAULT_APPROVE |
| Consultante/Lector | VAULT-READER-001 | 1 | BOS_VAULT_READ |
| Admin bvault | VAULT-ADMIN-001 | 3 | BOS_VAULT_ADMIN |
| Auditor Interno | VAULT-AUDITOR-001 | 2 | BOS_VAULT_AUDIT |
| Destinatario Externo | VAULT-EXT-READER-001 | 2 | BOS_VAULT_READ |
| SmartORC (sistema) | VAULT-ORC-SVC-001 | — | Service account (no humano) |
| Auditor Externo | VAULT-EXT-AUDITOR-001 | 3 | BOS_VAULT_AUDIT + audit_scope |

### Smart*-8: Vault Transit Engine y Cifrado de Llaves (desde SBOS-VAULT-008)

**Arquitectura de protección de claves RSA en reposo:**
```
Vault Transit Engine (KEK) ← nunca sale de Vault
    │
    └── AES-256-GCM encrypts → RSA private key PEM
         │
         └── Almacenado en Vault KV v2 (cifrado)
              │
              └── Solo descifrado en memoria para firmar → limpiado inmediatamente después
```

**Matriz de autorización bits 25-29 (desde SBOS-VAULT-008):**

| Operación | Bit | Quién puede |
|---|---|---|
| vault:document:read | 25 | Gestor, Firmante, Consultante, Admin, Auditor, Externo |
| vault:document:upload | 26 | Gestor, Admin, SmartORC |
| vault:document:approve | 27 | Firmante/Aprobador |
| vault:audit:log | 28 | Auditor Interno, Auditor Externo (con audit_scope) |
| vault:admin:config | 29 | Admin bvault |

**Proceso de resolución de alertas de integridad (3 etapas):**
1. **Investigación** — auditor determina causa raíz
2. **Contención** — si breach confirmado: rotación de llaves + revocación de certificados
3. **Resolución** — firma de aceptación de riesgo o remediación completa

---

## TRAZABILIDAD V8

| Sección | Fuente | Documento fuente |
|---|---|---|
| §1-18 (V6 íntegro) | V6 preservado | BOS_V6_SBOS-021-DAEMON-BAUTH.md |
| V5-1 | Enriquecimiento V5 | BOS_V5_SBOS-008-001-DOMAINS-BITMASK-REALM-v1_0.md |
| V5-2 | Enriquecimiento V5 | BOS_V5_SBOS-008-ROLFRAMEWORK-v1_0.md |
| V5-3 | Enriquecimiento V5 | BOS_V5_SBOS-009-IDENTITY-CONTRACTS-v1_0.md |
| V7-1 a V7-15 | Enriquecimiento V7 | BOS_V7_SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md, BOS_V7_SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1_0.md, BOS_V7_SBOS-ROLTEMPLATE-v5_0.md, BOS_V7_SBOS-USERTEMPLATE-v5_0.md |
| Smart*-1 | Enriquecimiento Smart* V8 | BVAULT-003-IDENTIDAD-AUTENTICACION.md |
| Smart*-2 | Enriquecimiento Smart* V8 | BVAULT-003-IDENTIDAD-AUTENTICACION.md |
| Smart*-3 | Enriquecimiento Smart* V8 | BVAULT-001-ACOPLAMIENTO.md |
| Smart*-4 | Enriquecimiento Smart* V8 | BOSORC-012-CRIPTOGRAFIA.md, BVAULT-001-ACOPLAMIENTO.md, SBOS-VAULT-008-SEGURIDAD.md |
| Smart*-5 | Enriquecimiento Smart* V8 | BOSORC-013-TRYTON-KEYCLOAK.md |
| Smart*-6 | Enriquecimiento Smart* V8 | SBOS-049-CONTEXT-PLANE.md |
| Smart*-7 | Enriquecimiento Smart* V8 | SBOS-VAULT-003-USUARIOS.md |
| Smart*-8 | Enriquecimiento Smart* V8 | SBOS-VAULT-008-SEGURIDAD.md |

---

_SKULL · SBOS · BOS_V8_SBOS-021-DAEMON-BAUTH · v1.2+V5+V7+Smart* · Mayo 2026_
