# SBOS-008
## SBOS Auth Enforce: Unified Identity & Permissions Orchestrator

### SKULL · SBOS — Sovereign Business Operating System
### v2.0 · Marzo 2026 · BitMask Dual Jun 2026

---

**Código:** SBOS-008
**Versión:** 1.0
**Estado:** ACTIVO — Complemento en SBOS-MP01 §PARTE-A
**Complemento:** SBOS-MP01-CompletarDocs-v1_0.md PARTE A (Ciclo de Vida del Realm — integrado en v2.0)
**Clasificación:** Especificación Técnica — Gobierno de Identidad

| Campo | Valor |
|-------|-------|
| **Nombre original** | SBOS Auth Enforce |
| **Nombre conceptual** | SBOS Auth Enforce: Unified Identity & Permissions Orchestrator |
| **Daemon** | `bauth` |
| **Servicio systemd** | `bauth.service` |
| **Lenguaje** | Go |
| **Unidad declarativa** | Ficha auth |
| **Directorio** | `/etc/bos/blibs/bauth/auths/<nombre_auth>/` |
| **Naturaleza** | Daemon soberano — orquestador de autenticación |

---

> ⚠️ **CORRECCIÓN BITMASK — JUNIO 2026:** El modelo BitMask de este documento ha sido reemplazado. El diseño correcto es el **BitMask Dual**: BitMask Átomo (64-bit label encoding para identificar) + Rol BitMask (N-bit one-hot encoding para combinar roles). Las referencias a SAM-128, "2 capas", "7×64 bits", "BitmaskBundle" o "capa 1/capa 2" son del modelo anterior. **Fuentes de verdad actuales:** `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md` (especificación + DDL), `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7 (arquitectura de motores), `SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md` v2.1 (D12 blockchain).

## Tabla de Contenidos

1. [El principio central: separación entre sincronización y login time](#1-el-principio-central-separación-entre-sincronización-y-login-time)
2. [Cómo funciona Keycloak internamente](#2-cómo-funciona-keycloak-internamente)
3. [El SPI de Keycloak — mecanismo de extensión](#3-el-spi-de-keycloak--mecanismo-de-extensión)
4. [Los 5 SPIs dSBOS Auth Enforce con firma Java completa](#4-los-5-spis-del-bauth-con-firma-java-completa)
5. [Cómo SBOS Auth Enforce programa Keycloak (sincronización)](#5-cómo-el-bauth-programa-keycloak-sincronización)
6. [El nombre canónico: un identificador, dos sistemas](#6-el-nombre-canónico-un-identificador-dos-sistemas)
7. [El modelo de identidad en Keycloak](#7-el-modelo-de-identidad-en-keycloak)
8. [Los flujos de operación completos](#8-los-flujos-de-operación-completos)
9. [Segregación de funciones](#9-segregación-de-funciones)
10. [Las 5 capas de enforcement en Tryton](#10-las-5-capas-de-enforcement-en-tryton)
11. [Implementación técnica de la librería](#11-implementación-técnica-de-la-librería)
12. [Provisioning de un realm nuevo](#12-provisioning-de-un-realm-nuevo)
13. [Flujo de onboarding de usuario](#13-flujo-de-onboarding-de-usuario)
14. [Troubleshooting de sincronización](#14-troubleshooting-de-sincronización)
15. [Hoja de ruta de implementación](#15-hoja-de-ruta-de-implementación)
16. [Glosario técnico](#16-glosario-técnico)
17. [Registro de cambios v2.0](#17-registro-de-cambios-v10)

---

## 1. El principio central: separación entre sincronización y login time

### El problema que resuelve SBOS Auth Enforce

Los enfoques tradicionales de control de acceso fallan por tres razones:

- **Desincronización:** los permisos configurados en el sistema de identidad no coinciden con los del ERP.
- **Herencia manual:** al crear un rol derivado de otro, el administrador copia y modifica manualmente, introduciendo errores.
- **Enforcement inconsistente:** algunas apps verifican permisos, otras no. La seguridad depende del código de cada aplicación.

El SBOS Auth Enforce elimina los tres problemas: calcula automáticamente la herencia mediante aritmética binaria, sincroniza proactivamente a Keycloak y Tryton antes de que llegue cualquier usuario, y el enforcement es estructural a nivel de ERP.

### La separación más importante

> **Keycloak no consulta el RolTemplate en tiempo de login.** El SBOS Auth Enforce TRADUCE el RolTemplate a objetos nativos de Keycloak durante la sincronización — antes de que llegue ningún usuario. En login time, Keycloak solo lee su propia base de datos interna.

Esta separación entre tiempo de sincronización y tiempo de login es el principio de diseño más importante del sistema. No hay consulta externa durante la autenticación, no hay latencia adicional, no hay punto de fallo dependiente del SBOS mientras Keycloak evalúa.

### El patrón PAP / PIP / PDP / PEP en el SBOS

| Punto | Función | Implementación en SBOS |
|---|---|---|
| PAP — Policy Administration Point | Donde se administran las políticas | Core UI (SBOS-007) → formulario de RolTemplate |
| PIP — Policy Information Point | Donde viven los datos de las políticas | PostgreSQL → tabla `bos_bauth_template` |
| PDP — Policy Decision Point | Quien decide si se permite el acceso | Keycloak (autenticación + contexto) + Tryton (enforcement) |
| PEP — Policy Enforcement Point | Quien bloquea o permite la operación | Tryton (5 capas nativas) + OAuth2-Proxy (gateway) |

SBOS Auth Enforce (bauth.service) es el traductor que mantiene PIP → PDP → PEP permanentemente sincronizados.

### El flujo de sincronización maestro

1. El administrador edita el RolTemplate en Core UI y hace clic en Guardar.
2. PostgreSQL ejecuta INSERT o UPDATE en `bos_bauth_template` y genera un evento WAL.
3. El SBOS Data Kernel (SBOS-010) detecta el evento WAL y ejecuta la regla ROLF-001 que activa el plugin `bauth_sync` (plugin legacy → `bauth_sync` en v2) y publica en Redis pub/sub canal `bkernel:identity_events`.
4. bauth.service consume el evento Redis y ejecuta `PrivilegeEngine.calculate(role_id)`, aplicando AND NOT si el rol tiene `parent_id`, produciendo la máscara binaria final.
5. `KeycloakSynchronizer.sync_role()` sincroniza: Composite Role, realm roles atómicos, Authentication Flow (MFA), atributos del usuario (horario, geo, vigencia) y Session Settings.
6. `TrytonSynchronizer.sync_groups()` sincroniza los 5 niveles de acceso del grupo en Tryton.
7. El SBOS Data Kernel registra el evento en `bkernel_db.audit_events` para cumplimiento ISO 27001.
8. El SBOS Auth Enforce actualiza `sync_status = 'SYNCED'` en `bos_bauth_template`.

**Tiempo total desde Guardar hasta SYNCED: < 5 segundos.**

### Principio de Cero Invasión

| El SBOS Auth Enforce NUNCA hace | El SBOS Auth Enforce SÍ hace |
|---|---|
| Modifica código fuente de Keycloak | Usa la Admin API REST de Keycloak |
| Modifica código fuente de Tryton | Usa la XML-RPC API de Tryton |
| Agrega triggers a bases de datos | Lee `bos_bauth_template` vía WAL (detectado por SBOS Data Kernel) |
| Intercepta requests HTTP de usuarios | Sincroniza grupos y políticas ANTES de que lleguen |
| Evalúa permisos en tiempo de ejecución | Calcula y sincroniza de forma proactiva e idempotente |
| Toma decisiones de autenticación | Keycloak toma TODAS las decisiones de autenticación |
| Modifica RolTemplates de forma autónoma | Solo reacciona a cambios que hizo un humano autorizado |

### El motor binario de privilegios — aritmética bitwise

El sistema implementa RBAC Jerárquico (H-RBAC) según el estándar ANSI/INCITS 359-2004, extendido con un motor de cálculo binario propio del SBOS. Cada permiso es un bit en una máscara de 64 bits:

| Bit | Permiso Base | Realm Role KC | Permiso Tryton (Nivel 1) |
|---|---|---|---|
| Bit 0 | Lectura (view) | `ROLE_VIEW` | `perm_read = True` |
| Bit 1 | Escritura (edit) | `ROLE_EDIT` | `perm_write = True` |
| Bit 2 | Impresión (print) | `ROLE_PRINT` | Acción de reporte habilitada (Nivel 2) |
| Bit 3 | Eliminación (delete) | `ROLE_DELETE` | `perm_delete = True` |
| Bit 4 | Exportación (export) | `ROLE_EXPORT` | Botón Exportar habilitado (Nivel 4) |
| Bit 5 | Importación (import) | `ROLE_IMPORT` | Botón Importar habilitado (Nivel 4) |
| Bit 6 | Configuración (configure) | `ROLE_CONFIG` | Menú Configuración visible (Nivel 2) |
| Bit 7 | Compartir (share) | `ROLE_SHARE` | Campo compartir editable (Nivel 3) |
| Bit 8 | Backup | `ROLE_BACKUP` | Acción Backup habilitada (Nivel 2) |
| Bit 9 | Archivado | `ROLE_ARCHIVE` | Botón Archivar habilitado (Nivel 4) |
| Bit N | Aprobar pago estándar | `APPROVE_PAYMENT_STD` | Button Rule: amount ≤ 10,000 (Nivel 4) |
| Bit M | Aprobar pago alto valor | `APPROVE_PAYMENT_HIGH` | Button Rule: amount ≤ 50,000 (Nivel 4) |

**AND NOT — el principio central de herencia:**

```
DGV-001 (padre):   1111111111  →  $100k límite, scope ALL, CONFIG_SYSTEM
Bits a quitar:     1000001000  →  CONFIG_SYSTEM + APPROVE_ALL

AND NOT:
  1111111111
& ~1000001000  (complemento: 0111110111)
= 0111110111   ← máscara de RGV-001
```

RGV-001 hereda todos los permisos de DGV-001 excepto `CONFIG_SYSTEM` y `APPROVE_PAYMENT_ALL`. El límite heredado de aprobación es $50,000 y el scope es REGIONAL.

**OR — usuarios con múltiples roles simultáneos:**
```
ROL_VENTAS:   0b0001010011
ROL_AUDITOR:  0b0000110001
= 0b0001110011  ← todo lo de ventas Y auditoría
```

**AND — delegaciones temporales (mínimo privilegio):**
```
ROL_GERENTE:  0b1111111111
ROL_CAJERO:   0b0001010101
= 0b0001010101  ← gerente opera CON PERMISOS DEL CAJERO
```

---

## 2. Cómo funciona Keycloak internamente

Keycloak tiene su propia base de datos donde almacena usuarios con credenciales y atributos, realms, clients, Authentication Flows, Authorization Policies y Session settings. Cuando un usuario intenta hacer login, Keycloak ejecuta el Authentication Flow configurado para ese realm o cliente, leyendo exclusivamente de su propia base de datos.

Un **Authentication Flow** es una secuencia de pasos (executions) con estos requisitos posibles:

| Requisito | Comportamiento |
|---|---|
| REQUIRED | Debe completarse obligatoriamente. Si falla: 401. |
| ALTERNATIVE | Basta con que uno de los alternativos pase. |
| CONDITIONAL | Se ejecuta solo si una condición previa retorna true. |
| DISABLED | Se omite siempre. |

### Authenticators nativos de Keycloak

| Authenticator nativo | Qué evalúa | Fuente de datos |
|---|---|---|
| Username Password Form | Verifica la contraseña | BD interna de Keycloak (hash bcrypt) |
| OTP Form | Verifica el código TOTP | Credencial tipo `otp` del usuario en KC |
| WebAuthn Authenticator | Verifica la clave de seguridad o huella | Credencial tipo `webauthn` del usuario en KC |
| Cookie | Verifica sesión activa por cookie SSO | Session store de Keycloak |

### Las limitaciones del sistema nativo de Tryton

| Capacidad requerida | Tryton Nativo | Keycloak |
|---|---|---|
| MFA granular por rol | No — global para toda la instancia | Sí — por Authentication Flow, por grupo |
| Control de horario | No existe | Sí — via SPI `RolTemporalAuthenticator` |
| Control de geolocalización | No existe | Sí — via SPI `RolGeoAuthenticator` |
| Control de vigencia de rol | No existe | Sí — via SPI `RolRoleValidityAuthenticator` |
| Sesiones concurrentes | No existe | Sí — `maxSessionCount` nativo |
| SSO con otras aplicaciones | No existe | Sí — es su función principal (OIDC/OAuth2) |
| WebAuthn / FIDO2 nativo | No existe en v7.0 | Sí — authenticator nativo |
| Step-up Authentication (RFC 9470) | No existe | Sí — nativo desde KC 21+ |

> **Conclusión:** En el SBOS, Tryton **deja de ser el autenticador** y pasa a ser exclusivamente el **motor de enforcement de autorización**. La autenticación la toma Keycloak por completo.

### El JWT: el token firmado

```json
{
  "sub":                "uuid-maria-garcia",
  "preferred_username": "maria.garcia",
  "realm_access": {
    "roles": ["RGV_001", "SALES_VIEW", "SALES_EDIT", "SALES_APPROVE_50K"]
  },
  "acr": "standard",
  "amr": ["pwd", "otp"],
  "exp": 1737849600,
  "iss": "https://auth.sbos.empresa.com/realms/sbos"
}
```

---

## 3. El SPI de Keycloak — mecanismo de extensión

Para las condiciones contextuales del RolTemplate (horario, geolocalización, vigencia), el sistema usa el SPI (Service Provider Interface) de Keycloak. El SPI permite escribir authenticators personalizados en Java que se despliegan como archivos JAR en `providers/`. Un authenticator personalizado implementa `ConditionalAuthenticator` y tiene acceso a `AuthenticationFlowContext`.

**La clave:** el authenticator SPI lee los atributos del usuario que SBOS Auth Enforce escribió previamente durante la sincronización — no consulta el RolTemplate en tiempo de login.

```java
// Lo que un SPI custom puede leer en tiempo de login:
context.getUser().getFirstAttribute("allowed_days")
  // ↑ Atributos que SBOS Auth Enforce escribió en este usuario

context.getConnection().getRemoteAddr()   // IP del request
context.getHttpRequest().getHttpHeaders() // Headers HTTP
```

### El Authentication Flow por rol

```
FLOW: RGV_001_browser_flow
│
├── [ALTERNATIVE] Cookie Check (nativo KC)
│
├── [REQUIRED] Subflow: Credentials
│   ├── [REQUIRED] Username Password Form (nativo KC)
│   └── [REQUIRED] Subflow: MFA
│       ├── [CONDITIONAL] RolUserConfiguredCondition (SPI)
│       ├── [ALTERNATIVE] OTP Form (nativo KC)
│       └── [ALTERNATIVE] WebAuthn Authenticator (nativo KC)
│
├── [CONDITIONAL] Subflow: Contextual Checks
│   ├── [CONDITIONAL] RolTemporalAuthenticator (SPI)
│   ├── [CONDITIONAL] RolGeoAuthenticator (SPI)
│   └── [CONDITIONAL] RolRoleValidityAuthenticator (SPI)
│
└── [NATIVE] Session Enforcement
      max_session_duration, inactivity_timeout, concurrent limit
```

---

## 4. Los 5 SPIs dSBOS Auth Enforce con firma Java completa

El SBOS Auth Enforce despliega cinco SPIs de Keycloak. A continuación se documenta la firma de interfaz Java completa de cada uno: nombre de clase, método que implementa, parámetros de entrada, valor de retorno, y condición de fallo. Un desarrollador puede implementar un SPI nuevo leyendo esta sección sin consultar a nadie.

---

### SPI 1 — `RolTemporalAuthenticator`

**Responsabilidad:** verifica que el usuario intenta autenticarse en un día y hora permitidos por su rol.

**Atributos del usuario que lee:** `allowed_days`, `shift_start`, `shift_end`, `timezone`

**Condición de fallo:** el día actual no está en `allowed_days`, o la hora actual está fuera del rango `[shift_start, shift_end]` en el timezone del rol.

**Acción al fallar:** `401 — login_outside_allowed_schedule`

```java
package com.skull.sbos.keycloak.spi;

import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.authenticators.conditional.ConditionalAuthenticator;
import org.keycloak.models.AuthenticatorConfigModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;

import java.time.DayOfWeek;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.Arrays;

public class RolTemporalAuthenticator implements ConditionalAuthenticator {

    public static final String PROVIDER_ID = "rol-temporal-authenticator";

    /**
     * Evalúa si el login ocurre dentro del horario permitido por el RolTemplate.
     *
     * @param context Contexto del flujo de autenticación. Provee acceso al usuario,
     *                la sesión de Keycloak, la conexión y los headers HTTP.
     * @return true si el login está dentro del horario permitido; false en caso contrario.
     *         Cuando retorna false, Keycloak registra el error y deniega la autenticación (401).
     */
    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        UserModel user = context.getUser();

        String allowedDays = user.getFirstAttribute("allowed_days");
        String shiftStart  = user.getFirstAttribute("shift_start");
        String shiftEnd    = user.getFirstAttribute("shift_end");
        String timezone    = user.getFirstAttribute("timezone");

        // Si no tiene atributos temporales configurados, el check no aplica
        if (allowedDays == null || shiftStart == null || shiftEnd == null || timezone == null) {
            return true;
        }

        ZonedDateTime now  = ZonedDateTime.now(ZoneId.of(timezone));
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

    /**
     * Acción a ejecutar si este authenticator es REQUIRED y matchCondition retorna false.
     * En modo CONDITIONAL, Keycloak no llama a authenticate() — solo a matchCondition().
     */
    @Override
    public void authenticate(AuthenticationFlowContext context) {
        context.attempted();
    }

    @Override
    public boolean requiresUser() { return true; }

    @Override
    public boolean configuredFor(KeycloakSession session, RealmModel realm, UserModel user) {
        return user.getFirstAttribute("allowed_days") != null;
    }

    @Override
    public void setRequiredActions(KeycloakSession session, RealmModel realm, UserModel user) {}

    @Override
    public void action(AuthenticationFlowContext context) {}

    @Override
    public void close() {}
}
```

---

### SPI 2 — `RolGeoAuthenticator`

**Responsabilidad:** verifica que el usuario se conecta desde una red autorizada por su rol.

**Atributos del usuario que lee:** `allowed_networks` (lista de CIDRs separados por coma), `require_vpn` (boolean string), `allowed_vpn_range` (CIDR)

**Condición de fallo:** la IP del request no pertenece a ninguno de los CIDRs de `allowed_networks`, y si `require_vpn=true`, tampoco pertenece a `allowed_vpn_range`.

**Acción al fallar:** `401 — login_from_unauthorized_location`

```java
package com.skull.sbos.keycloak.spi;

import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.authenticators.conditional.ConditionalAuthenticator;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.Arrays;

public class RolGeoAuthenticator implements ConditionalAuthenticator {

    public static final String PROVIDER_ID = "rol-geo-authenticator";

    /**
     * Evalúa si la IP de la conexión está en una red autorizada por el RolTemplate.
     *
     * @param context Contexto del flujo. context.getConnection().getRemoteAddr() provee la IP.
     * @return true si la IP está en allowed_networks o en allowed_vpn_range (cuando require_vpn=true).
     *         false si la IP no está en ninguna red autorizada.
     */
    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        UserModel user = context.getUser();

        String allowedNetworks = user.getFirstAttribute("allowed_networks");
        String requireVpn      = user.getFirstAttribute("require_vpn");
        String allowedVpnRange = user.getFirstAttribute("allowed_vpn_range");

        if (allowedNetworks == null) return true;

        String remoteAddr = context.getConnection().getRemoteAddr();

        boolean inAllowedNetwork = Arrays.stream(allowedNetworks.split(","))
                                         .anyMatch(cidr -> isInCidr(remoteAddr, cidr.trim()));

        if (inAllowedNetwork) return true;

        // Verificación VPN
        if ("true".equalsIgnoreCase(requireVpn) && allowedVpnRange != null) {
            boolean inVpn = isInCidr(remoteAddr, allowedVpnRange.trim());
            if (inVpn) return true;
        }

        context.getEvent().error("login_from_unauthorized_location");
        return false;
    }

    /**
     * Verifica si una IP está dentro de un rango CIDR.
     *
     * @param ip    Dirección IP en formato string (IPv4 o IPv6)
     * @param cidr  Rango CIDR (ej: "192.168.10.0/24")
     * @return true si la IP pertenece al CIDR
     */
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

            for (int i = 0; i < fullBytes; i++) {
                if (netBytes[i] != addrBytes[i]) return false;
            }
            if (remBits > 0) {
                int mask = (0xFF << (8 - remBits)) & 0xFF;
                return (netBytes[fullBytes] & mask) == (addrBytes[fullBytes] & mask);
            }
            return true;
        } catch (UnknownHostException | NumberFormatException e) {
            return false;
        }
    }

    @Override
    public void authenticate(AuthenticationFlowContext context) { context.attempted(); }

    @Override
    public boolean requiresUser() { return true; }

    @Override
    public boolean configuredFor(KeycloakSession session, RealmModel realm, UserModel user) {
        return user.getFirstAttribute("allowed_networks") != null;
    }

    @Override
    public void setRequiredActions(KeycloakSession session, RealmModel realm, UserModel user) {}

    @Override
    public void action(AuthenticationFlowContext context) {}

    @Override
    public void close() {}
}
```

---

### SPI 3 — `RolRoleValidityAuthenticator`

**Responsabilidad:** verifica que el rol del usuario no ha expirado.

**Atributos del usuario que lee:** `role_valid_until` (timestamp ISO 8601 UTC)

**Condición de fallo:** `now() > role_valid_until`

**Acción al fallar:** `401 — role_expired`. El SBOS Auth Enforce inicia automáticamente el proceso de revocación del rol en KC y Tryton.

```java
package com.skull.sbos.keycloak.spi;

import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.authenticators.conditional.ConditionalAuthenticator;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;

import java.time.Instant;
import java.time.format.DateTimeParseException;

public class RolRoleValidityAuthenticator implements ConditionalAuthenticator {

    public static final String PROVIDER_ID = "rol-role-validity-authenticator";

    /**
     * Verifica que el rol del usuario no ha expirado comparando
     * el timestamp de vigencia con el instante actual UTC.
     *
     * @param context Contexto del flujo de autenticación.
     * @return true si el rol está vigente (now < role_valid_until) o si no tiene vigencia configurada.
     *         false si el rol ha expirado.
     */
    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        UserModel user = context.getUser();
        String validUntil = user.getFirstAttribute("role_valid_until");

        if (validUntil == null) return true;

        try {
            Instant expiresAt = Instant.parse(validUntil);
            if (Instant.now().isAfter(expiresAt)) {
                context.getEvent().error("role_expired");
                return false;
            }
        } catch (DateTimeParseException e) {
            // Atributo malformado — dejar pasar pero registrar
            context.getEvent().detail("warning", "role_valid_until_parse_error:" + validUntil);
        }
        return true;
    }

    @Override
    public void authenticate(AuthenticationFlowContext context) { context.attempted(); }

    @Override
    public boolean requiresUser() { return true; }

    @Override
    public boolean configuredFor(KeycloakSession session, RealmModel realm, UserModel user) {
        return user.getFirstAttribute("role_valid_until") != null;
    }

    @Override
    public void setRequiredActions(KeycloakSession session, RealmModel realm, UserModel user) {}

    @Override
    public void action(AuthenticationFlowContext context) {}

    @Override
    public void close() {}
}
```

---

### SPI 4 — `RolUserConfiguredCondition`

**Responsabilidad:** verifica si el usuario tiene configurado el método MFA requerido por su rol. Actúa como condición del subflow MFA: si el usuario no tiene ningún factor configurado, el subflow MFA no se activa (y el usuario no puede autenticarse con este rol).

**Atributos del usuario que lee:** credenciales registradas en Keycloak (`otp`, `webauthn`)

**Condición de fallo:** el usuario no tiene ninguna credencial de factor múltiple registrada.

**Acción al fallar:** el subflow MFA queda bloqueado — el usuario no puede completar el login.

```java
package com.skull.sbos.keycloak.spi;

import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.authenticators.conditional.ConditionalAuthenticator;
import org.keycloak.credential.CredentialModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;
import org.keycloak.models.credential.OTPCredentialModel;
import org.keycloak.models.credential.WebAuthnCredentialModel;

import java.util.stream.Stream;

public class RolUserConfiguredCondition implements ConditionalAuthenticator {

    public static final String PROVIDER_ID = "rol-user-configured-condition";

    /**
     * Verifica si el usuario tiene al menos un factor de autenticación secundario registrado.
     * Este SPI actúa como condición del subflow MFA del Authentication Flow por rol.
     * Si el usuario no tiene MFA configurado, el subflow MFA no se activa.
     *
     * @param context Contexto del flujo. context.getUser() permite acceder a las credenciales.
     * @return true si el usuario tiene al menos una credencial OTP o WebAuthn registrada.
     *         false si no tiene ningún factor MFA configurado.
     */
    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        UserModel user       = context.getUser();
        KeycloakSession sess = context.getSession();
        RealmModel realm     = context.getRealm();

        Stream<CredentialModel> credentials = sess.userCredentialManager()
            .getStoredCredentials(realm, user).stream();

        return credentials.anyMatch(c ->
            OTPCredentialModel.TYPE.equals(c.getType()) ||
            WebAuthnCredentialModel.TYPE_TWOFACTOR.equals(c.getType()) ||
            WebAuthnCredentialModel.TYPE_PASSWORDLESS.equals(c.getType())
        );
    }

    @Override
    public void authenticate(AuthenticationFlowContext context) { context.attempted(); }

    @Override
    public boolean requiresUser() { return true; }

    @Override
    public boolean configuredFor(KeycloakSession session, RealmModel realm, UserModel user) {
        return true;
    }

    @Override
    public void setRequiredActions(KeycloakSession session, RealmModel realm, UserModel user) {}

    @Override
    public void action(AuthenticationFlowContext context) {}

    @Override
    public void close() {}
}
```

---

### SPI 5 — `RolStepUpCondition`

**Responsabilidad:** verifica si el nivel de autenticación (LoA) del token actual satisface el requisito de la operación solicitada. Implementa Step-Up Authentication según RFC 9470.

**Atributos evaluados:** `acr` claim del JWT actual vs `acr_values` requerido por el cliente o la operación.

**Condición de fallo:** `acr_actual < acr_requerido`

**Acción al fallar:** Keycloak lanza un challenge de Step-Up — solicita al usuario solo el factor faltante sin interrumpir la sesión existente.

```java
package com.skull.sbos.keycloak.spi;

import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.authenticators.conditional.ConditionalAuthenticator;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;
import org.keycloak.services.managers.AuthenticationManager;

import java.util.Map;

public class RolStepUpCondition implements ConditionalAuthenticator {

    public static final String PROVIDER_ID = "rol-step-up-condition";

    // Mapa de orden de LoA: nivel numérico por ACR string
    private static final Map<String, Integer> LOA_ORDER = Map.of(
        "standard",      1,
        "elevated",      2,
        "high_security", 3,
        "critical",      4
    );

    /**
     * Evalúa si el LoA actual del usuario satisface el requisito de Step-Up.
     * Se activa cuando el cliente envía acr_values en el authorization request.
     *
     * @param context Contexto del flujo. Contiene el acr_values requerido por el cliente
     *                y el acr del token existente en la sesión activa.
     * @return true si el LoA actual >= LoA requerido (no necesita step-up).
     *         false si se necesita autenticación adicional (step-up requerido).
     */
    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        String requiredAcr = context.getAuthenticationSession()
                                    .getClientNote("requested_acr");

        if (requiredAcr == null) return true;

        // Obtener el LoA actual de la sesión existente
        String currentAcr = AuthenticationManager.getSessionAcr(context.getAuthenticationSession());

        int requiredLevel = LOA_ORDER.getOrDefault(requiredAcr, 1);
        int currentLevel  = LOA_ORDER.getOrDefault(currentAcr, 0);

        return currentLevel >= requiredLevel;
    }

    /**
     * Los niveles de LoA y sus significados operacionales:
     *
     * LoA 1 - "standard"      → pwd + otp · Sesión completa · Operaciones de bajo riesgo
     * LoA 2 - "elevated"      → pwd + otp (fresco ≤ 300s) · 300s · Pagos > $10k
     * LoA 3 - "high_security" → pwd + WebAuthn · 0s (solo esa operación) · Pagos > $50k
     * LoA 4 - "critical"      → WebAuthn + quórum · 0s · Cierre fiscal, pagos > $200k
     */

    @Override
    public void authenticate(AuthenticationFlowContext context) { context.attempted(); }

    @Override
    public boolean requiresUser() { return true; }

    @Override
    public boolean configuredFor(KeycloakSession session, RealmModel realm, UserModel user) {
        return true;
    }

    @Override
    public void setRequiredActions(KeycloakSession session, RealmModel realm, UserModel user) {}

    @Override
    public void action(AuthenticationFlowContext context) {}

    @Override
    public void close() {}
}
```

---

## 5. Cómo SBOS Auth Enforce programa Keycloak (sincronización)

### Operación 1: Escritura de atributos del usuario

```
// SBOS Auth Enforce → Keycloak Admin API (tiempo de sincronización):
PUT /admin/realms/{realm}/users/{userId}
{
  "attributes": {
    // Desde temporal_control:
    "allowed_days":    "MONDAY,WEDNESDAY,FRIDAY",
    "shift_start":     "08:00",
    "shift_end":       "17:00",
    "timezone":        "America/La_Paz",

    // Desde geospatial_control:
    "allowed_networks":  "192.168.10.0/24,10.10.0.0/16",
    "require_vpn":       "true",
    "allowed_vpn_range": "10.10.0.0/16",

    // Desde validity_period:
    "role_valid_until": "2025-12-31T23:59:59Z"
  }
}
```

### Operación 2: Composite Role por rol

El SBOS Auth Enforce crea un Composite Role con nombre canónico igual al `id` del RolTemplate. Los realm roles atómicos son generados a partir de la máscara binaria: cada bit activo produce un realm role con nombre `{MODULO}_{ACCION}`.

```
POST /admin/realms/{realm}/roles
{ "name": "RGV_001", "composite": true }

POST /admin/realms/{realm}/roles/RGV_001/composites
["SALES_VIEW", "SALES_EDIT", "SALES_APPROVE_50K", "REPORTS_REGIONAL"]
```

### Operación 3: Session settings nativos

| Parámetro RolTemplate | Admin API Keycloak | Evaluado por |
|---|---|---|
| `max_session_duration: 28800` | `client.session.max.lifespan: 28800` | Keycloak nativo |
| `inactivity_timeout: 900` | `client.offline.session.idle.timeout: 900` | Keycloak nativo |
| `force_logout_at_end_shift: true` | Session Lifespan = fin del turno | Keycloak nativo |
| `concurrent_sessions_allowed: false` | `maxSessionCount: 1` | Keycloak nativo |

### Tabla de responsabilidades: RolTemplate → Keycloak

| Condición del RolTemplate | Cómo el RF la escribe en KC | Cómo Keycloak la evalúa | Si falla |
|---|---|---|---|
| `requiredMethods` (MFA) | Configura Authentication Flow con executions REQUIRED | Authenticators nativos OTP / WebAuthn | 401 |
| `temporal_control` (horario) | Escribe `allowed_days`, `shift_start`, `shift_end` como user attributes | `RolTemporalAuthenticator` SPI | 401 |
| `geospatial_control` (red/IP) | Escribe `allowed_networks`, `require_vpn` como user attributes | `RolGeoAuthenticator` SPI | 401 |
| `validity_period` (vigencia) | Escribe `role_valid_until` como user attribute | `RolRoleValidityAuthenticator` SPI | 401 |
| `max_session_duration` | `PUT /clients → client.session.max.lifespan` | Keycloak nativo, cada request | Expiración — 401 |
| `concurrent_sessions_allowed` | `PUT /realms → maxSessionCount: 1` | Keycloak nativo al login | 401 |

### El módulo trytond-auth-keycloak: el puente con Tryton

```python
# trytond_auth_keycloak/res.py
class User(metaclass=PoolMeta):
  __name__ = 'res.user'

  @classmethod
  def _login_keycloak(cls, login, parameters):
    token = parameters.get('keycloak_token')
    if not token:
      return None  # Tryton prueba el siguiente método (password)

    # PASO 1: Validar firma RSA del JWT con JWKS de Keycloak
    try:
      claims = KeycloakJWTValidator.verify(
        token    = token,
        jwks_url = settings.KEYCLOAK_JWKS_URL,
        audience = settings.KEYCLOAK_CLIENT_ID,
        issuer   = settings.KEYCLOAK_ISSUER
      )
    except InvalidTokenError:
      return None  # JWT inválido o expirado

    # PASO 2: Extraer realm_roles y acr del JWT
    realm_roles = claims['realm_access']['roles']
    acr         = claims.get('acr', 'standard')

    # PASO 3: Encontrar o provisionar el usuario en Tryton
    user = cls._find_by_keycloak_sub(claims['sub'])
    if not user:
      user = cls._create_from_jwt(claims)  # auto-provisioning

    # PASO 4: Sincronizar grupos de Tryton por nombre canónico
    Group    = Pool().get('res.group')
    expected = Group.search([('name', 'in', realm_roles)])
    if set(user.groups) != set(expected):
      user.groups = expected
      user.save()

    # PASO 5: Guardar acr en contexto para @require_loa
    Transaction().context.update({'keycloak_acr': acr})

    return user.id  # → Sesión de Tryton abierta
```

---

## 6. El nombre canónico: un identificador, dos sistemas

Un identificador como `RGV_001` existe en exactamente dos lugares con el mismo nombre y el mismo significado:

- Como **Composite Role** en Keycloak (con sus realm roles atómicos)
- Como **Grupo** en Tryton (con sus 5 capas de acceso configuradas)

El módulo `trytond-auth-keycloak` extrae los `realm_access.roles` del JWT y busca en Tryton grupos con el mismo nombre. La correspondencia es perfecta porque el mismo SBOS Auth Enforce los creó.

### Nomenclatura del sistema

| Tipo | Formato | Ejemplos |
|---|---|---|
| Rol jerárquico principal | `{SIGLA}_{NUM}` | `DGV_001`, `RGV_001`, `CAJERO_001` |
| Realm role atómico de permiso | `{MODULO}_{ACCION}` | `SALES_VIEW`, `SALES_EDIT`, `SALES_APPROVE_50K` |
| Rol de configuración | `CONFIG_{SCOPE}` | `CONFIG_SYSTEM`, `CONFIG_REGION` |
| Delegación temporal | `DEL_{AÑO}_{ID}_{USUARIO}` | `DEL_2025_001_JUAN` |

---

## 7. El modelo de identidad en Keycloak

### Grupos (jerarquía organizacional)

```
/Empresa-ACME                          → realm role: EMPRESA_ACME_MEMBER
  /Empresa-ACME/Ventas                 → realm role: VENTAS_BASE
    /Empresa-ACME/Ventas/Norte         → realm role: RGV_001
```

María García en `/Ventas/Norte` hereda: `RGV_001` + `VENTAS_BASE` + `EMPRESA_ACME_MEMBER`.

### Composite Roles (jerarquía de permisos)

```
Composite Role RGV_001 (calculado por RF con AND NOT sobre DGV_001):
  SALES_VIEW, SALES_EDIT, SALES_APPROVE_50K, REPORTS_REGIONAL
  (sin CONFIG_SYSTEM)  → bit 6 quitado por AND NOT
  (sin APPROVE_ALL)    → bit 3 quitado por AND NOT
```

### La validación criptográfica del JWT

1. Decodifica el header del JWT → obtiene el `kid` (Key ID).
2. Llama al JWKS endpoint público de Keycloak → obtiene la clave pública RSA identificada por ese `kid`.
3. Verifica la firma RSA — si inválida: rechazado.
4. Verifica `exp` (expiration) — si expirado: el usuario debe re-autenticarse.
5. Verifica `iss` (issuer) — si es otro issuer: rechazado.
6. Verifica `aud` (audience) — si es para otro cliente: rechazado.
7. Todos pasan → claims confiables → grupos asignados → sesión abierta.

> Tryton confía en los roles del JWT porque confía en que Keycloak los verificó antes de firmar. No hay consulta a Keycloak en tiempo real para cada request posterior — la firma RSA es la prueba de autenticidad.

---

## 8. Los flujos de operación completos

### Flujo 1: Creación de un nuevo RolTemplate

1. Admin define el RolTemplate en Core UI (SBOS-007) y hace clic en Guardar → INSERT en `bos_bauth_template`.
2. SBOS Data Kernel (SBOS-010) detecta WAL → activa regla ROLF-001 → llama `bauth_sync`.
3. `PrivilegeEngine.calculate()` calcula máscara (con AND NOT si tiene `parent_id`).
4. En paralelo: KC Sync crea Composite Role + escribe user attributes + configura Flow. Tryton Sync crea Grupo + configura 5 capas.
5. SBOS Data Kernel registra auditoría. RF actualiza `sync_status = 'SYNCED'`.

### Flujo 2: Login de usuario

```
═══ TIEMPO DE SINCRONIZACIÓN (admin guarda RolTemplate) ═══════════

bos_bauth_template → SBOS Data Kernel WAL → SBOS Auth Enforce
                                     │
                       ┌─────────────┴──────────────────┐
                       ▼                                ▼
             Keycloak Admin API                  Tryton XML-RPC
             PUT /users/{id}/attributes          res.group.upsert
               allowed_days, shift_start         ir.model.access
               allowed_networks, require_vpn     ir.action.groups
               role_valid_until                  ir.model.field
             PUT /authentication/flows/{rol}     ir.model.button
               RolTemporalAuthenticator          ir.rule.group
               RolGeoAuthenticator
               RolRoleValidityAuthenticator
             PUT /clients → session settings

═══ TIEMPO DE LOGIN (usuario intenta acceder) ═══════════════════════

Browser → OAuth2-Proxy → Keycloak ejecuta RGV_001_browser_flow:
  1. UsernamePasswordForm (nativo) → verifica en BD interna KC
  2. OTP Form (nativo) → verifica credencial TOTP en BD KC
  3. RolTemporalAuthenticator (SPI) → lee user.attribute
       allowed_days → evalúa now() → OK o 401
  4. RolGeoAuthenticator (SPI) → lee user.attribute
       allowed_networks → evalúa IP → OK o 401
  5. RolRoleValidityAuthenticator (SPI) → lee user.attribute
       role_valid_until → evalúa now() → OK o 401
  6. Session settings (nativo) → verifica concurrencia, duración
  → Todos OK: emite JWT firmado con RSA
  → Cualquier fallo: 401 — no hay JWT — no hay acceso

JWT → OAuth2-Proxy → trytond-auth-keycloak:
  1. Valida firma RSA con JWKS de Keycloak → OK
  2. Verifica exp, iss, aud → OK
  3. Extrae realm_roles → ['RGV_001', 'SALES_VIEW', ...]
  4. Asigna grupos de Tryton por nombre canónico
  5. Guarda acr en contexto de transacción
  6. Retorna user.id → sesión de Tryton abierta

Tryton enforcea 5 capas en cada operación. Silenciosamente.
```

### Flujo 3: Delegación temporal con revocación automática

1. Admin activa delegación en Core UI → UPDATE en `bos_bauth_template`.
2. RF calcula `base_juan AND intersect(delegation_permissions)` → máscara reducida.
3. RF crea Composite Role temporal en KC y grupo temporal en Tryton con vigencia.
4. Al vencer `validity_period.end_date`: SBOS Data Kernel detecta → RF revoca automáticamente en KC y Tryton.

### Flujo 4: Detección y corrección de drift

1. RF verifica periódicamente si el estado de KC/Tryton coincide con las máscaras calculadas.
2. Si divergencia: `sync_status = 'DRIFT'` + alerta a Wazuh SIEM.
3. Admin puede forzar re-sincronización desde Core UI. Si el drift implica permisos de más: alerta crítica + re-sincronización automática.

### Flujo 5: Step-Up Authentication

1. Usuario con sesión LoA 1 hace clic en "Confirmar Transferencia $80,000".
2. `@require_loa('high_security')` intercepta: `acr_actual='standard'` < `acr_requerido='high_security'` → `StepUpRequiredException`.
3. Keycloak recibe challenge con `acr_values='high_security'`, `max_age=0`.
4. Keycloak muestra SOLO el factor faltante (WebAuthn). El usuario no pierde su trabajo.
5. Usuario completa WebAuthn. Keycloak emite token con `acr='high_security'`, `max_age=0`.
6. Button Rule evalúa: `acr ≥ high_security ✓`, `amount > $50k ✓`, grupo `FINANCE_APPROVER ✓` → Transferencia ejecutada.

---

## 9. Segregación de funciones

### Principio de Segregación de Funciones (SoD)

| Función 1 | Función 2 | Riesgo que Previene | Implementación |
|---|---|---|---|
| `CREATE_VENDOR` | `APPROVE_PAYMENTS` | Fraude: crear proveedor fantasma y pagarse | Button Rule: si el usuario creó el proveedor, botón Aprobar es readonly |
| `PAYROLL_INPUT` | `PAYROLL_APPROVE` | Modificar montos y autoaprobar | Dos usuarios distintos obligatorios |
| `PURCHASE_REQUEST` | `PURCHASE_APPROVE` | Solicitudes fraudulentas autoaprobadas | Button Rule: creador ≠ aprobador |
| `INVOICE_CREATE` | `INVOICE_POST` | Contabilizar sin revisión | Revisor distinto al creador |

### La regla SBOS Data Kernel ROLF-001

```yaml
rule:
  id:   "ROLF-001"
  when:
    source:    "bos_core"
    table:     "bos_bauth_template"
    operation: "INSERT, UPDATE"
  then:
    - action: "plugin"
      name:   "bauth_sync"
    - action: "catalog"
      task:   "log_audit_event"
```

---

## 10. Las 5 capas de enforcement en Tryton

Tryton implementa cinco capas nativas de control de acceso que son estructurales, no programáticas. Si cualquier capa es violada, Tryton lanza una excepción antes de ejecutar ningún SQL. No hay bypass posible.

### Capa 0 — Secuencias (`ir.sequence.type`)

Controla el acceso a las series numéricas de negocio (facturas, contratos, pedidos).

| Recurso de Secuencia | Grupo Autorizado | Impacto si no configurado |
|---|---|---|
| Numeración de Facturas Fiscales | `FINANCE_INVOICING` | Cualquier usuario podría crear facturas en cualquier serie |
| Numeración de Contratos | `LEGAL_CONTRACTS` | Cualquier usuario podría generar numeración de contrato |
| Órdenes de Venta por Región | `RGV_001`, `RGV_002`, etc. | Un gerente regional podría usar la serie de otra región |

### Capa 1 — Acceso a Modelos (`ir.model.access`)

Permisos CRUD por grupo sobre cada modelo de datos. Sin lectura en un modelo, el usuario no ve ningún dato de ese modelo.

| Modelo Tryton | Grupo RGV_001 | Grupo CAJERO | Grupo AUDITOR |
|---|---|---|---|
| `sale.order` | R=✓ W=✓ C=✓ D=✗ | R=✓ W=✗ C=✗ D=✗ | R=✓ W=✗ C=✗ D=✗ |
| `account.invoice` | R=✓ W=✗ C=✗ D=✗ | R=✗ W=✗ C=✗ D=✗ | R=✓ W=✗ C=✗ D=✗ |
| `account.payment` | R=✓ W=✓ C=✓ D=✗ | R=✓ W=✓ C=✓ D=✗ | R=✓ W=✗ C=✗ D=✗ |

### Capa 2 — Menús y Acciones (`ir.action.groups`)

Los menús sin acceso no aparecen — no producen error, simplemente no existen para ese usuario.

```
Grupo RGV_001:
  ✓ Ventas > Órdenes de Venta
  ✓ Ventas > Reportes Región Norte
  ✗ Administración > Configuración del Sistema  (invisible)
  ✗ Finanzas > Transferencias Bancarias          (invisible)
```

### Capa 3 — Acceso a Campos (`ir.model.field.access`)

Los campos sin permiso de lectura se eliminan automáticamente de las vistas.

| Modelo | Campo | Grupo RGV_001 | Grupo CAJERO |
|---|---|---|---|
| `account.invoice` | `amount_total` | Lectura: ✓ | Lectura: ✗ |
| `account.invoice` | `cost_center` | Lectura: ✗ | Lectura: ✗ |
| `sale.order` | `discount` | Lectura: ✓ Escritura: ✓ | Lectura: ✓ Escritura: ✗ |

### Capa 4 — Botones y Aprobación (`ir.model.button` + Button Rules)

| Botón | Condición PYSON | Grupos Autorizados | Quórum |
|---|---|---|---|
| Confirmar Venta | amount ≤ 50,000 | `RGV_001` | 1 |
| Confirmar Transferencia | amount ≤ 10,000 | `APPROVER_STANDARD` | 1 |
| Confirmar Transferencia | 10,001 ≤ amount ≤ 50,000 | `APPROVER_STANDARD` | 2 distintos |
| Confirmar Transferencia | amount > 50,000 | `FINANCE_DIRECTOR` | 1 |
| Cerrar Ejercicio Fiscal | Siempre | `CFO_ROLE` | 1 + acr=critical |
| Aprobar Nómina | Siempre | `HR_DIRECTOR` + `CFO_ROLE` | 2 distintos |

### Capa 5 — Reglas de Registros (`ir.rule.group`)

Filtra qué registros puede ver o modificar el usuario. Tryton agrega el filtro automáticamente a cada SQL.

```python
# Record Rule para Grupo RGV_001:
Modelo: sale.order
Dominio PYSON: [('shop.region', '=', Eval('context', {}).get('user_region', ''))]

# SQL generado automáticamente:
SELECT * FROM sale_order so
  JOIN sale_shop sh ON so.shop = sh.id
WHERE sh.region = 'NORTH'
```

---

## 10b. Stack Tecnológico del Daemon bauth

### Justificación técnica de Go para orquestación de autenticación

El SBOS Auth Enforce orquesta autenticación federada: HTTP a la Admin API de Keycloak, XML-RPC a Tryton para sincronización de usuarios, y WebSockets para notificaciones de sesión al SBOS VDI. Es un workload I/O-bound puro con alta concurrencia de llamadas API heterogéneas.

**Concurrencia heterogénea — el patrón exacto de Go:**
- **Keycloak Admin API:** REST HTTP, hasta 100 requests/s durante onboarding masivo. `context.Context` para timeouts per-request garantiza que ningún goroutine queda bloqueado indefinidamente.
- **Tryton XML-RPC:** protocolo síncrono, pero bauth lo envuelve en goroutines para no bloquear el loop principal. El scheduler de Go gestiona la espera de XML-RPC sin threads adicionales del OS.
- **WebSocket notifications:** sesiones activas del SBOS VDI reciben notificaciones de cambio de permisos en tiempo real. Go maneja miles de conexiones WebSocket simultáneas con el mismo scheduler de goroutines.

Go maneja los tres protocolos (HTTP REST, XML-RPC, WebSocket) con el mismo scheduler de goroutines sin threads adicionales del OS — esto es imposible de replicar con la misma elegancia en Java o Python.

**Por qué no Rust para bauth:** la ausencia de GC que hace a Rust indispensable en bkernel no aporta ventaja en bauth. El workload es I/O-bound: el tiempo de ejecución de bauth está dominado por la latencia de red a Keycloak y Tryton, no por procesamiento de CPU. Go maneja esta concurrencia de forma más idiomática y con menor tiempo de desarrollo.

### Stack de dependencias

| Componente | Herramienta / Módulo | Propósito |
|---|---|---|
| **Lenguaje** | Go 1.22+ | Daemon principal |
| **HTTP client KC** | net/http + oauth2 | Keycloak Admin REST API |
| **XML-RPC client** | github.com/kolo/xmlrpc | Tryton user sync |
| **WebSocket server** | github.com/coder/websocket | Notificaciones de sesión SBOS VDI |
| **PostgreSQL client** | github.com/jackc/pgx/v5 | Estado de sesiones en bauth_db |
| **JWT generation** | github.com/golang-jwt/jwt/v5 | Tokens de sesión SBOS VDI |
| **Auth rules YAML** | gopkg.in/yaml.v3 | Parsing de auth_engine.yml |
| **Hot-reload .so** | plugin stdlib (Go plugins) | Carga de auth_catalog.so |
| **Config** | github.com/BurntSushi/toml | Lectura de bauth.toml |
| **Logging** | github.com/rs/zerolog | Audit log de autenticaciones |
| **Testing** | go test + testify + WireMock | Mock de Keycloak y Tryton |
| **Build** | `go build -ldflags='-s -w'` | Binario estático |

### Pipeline CI/CD — bauth

| Etapa | Comando | Criterio de éxito |
|---|---|---|
| **Format** | `gofmt -l . \| grep -c .` | 0 archivos sin formato |
| **Vet** | `go vet ./...` | Sin errores de análisis |
| **Lint** | `golangci-lint run` | 0 issues |
| **Test** | `go test -race -count=1 ./...` | 0 fallos, 0 race conditions |
| **Build** | `go build -ldflags='-s -w' -o bin/` | Binario estático generado |
| **Sign** | ed25519 firma del binario | Firma verificable por bos |

---


## 11. Implementación técnica de la librería

### Estructura de la librería

| Componente | Módulo Python | Responsabilidad |
|---|---|---|
| Motor de Cálculo | `bauth.engine.PrivilegeEngine` | Calcula máscaras bitwise con herencia AND NOT recursiva. Produce `PrivilegeSet`. |
| Sincronizador Keycloak | `bauth.keycloak.KeycloakSynchronizer` | Composite Roles, realm roles, Flows, user attributes, Session Settings via Admin API REST. |
| Sincronizador Tryton | `bauth.tryton.TrytonSynchronizer` | 5 niveles de acceso por grupo via XML-RPC. |
| Módulo Tryton Auth | `trytond-auth-keycloak` | Valida JWT, asigna grupos por nombre canónico, implementa Step-up con `@require_loa`. |

### Idempotencia

```python
# Lógica de idempotencia en KeycloakSynchronizer:
current  = set(api.get_composite_members(role_id))
expected = set(privilege_set.realm_roles)

to_add    = expected - current   # solo añade lo que falta
to_remove = current - expected   # solo quita lo que sobra

if to_add:    api.add_roles_to_composite(role_id, to_add)
if to_remove: api.remove_roles_from_composite(role_id, to_remove)
# Si to_add == {} y to_remove == {} → cero llamadas API
```

### La tabla bos_bauth_template

| Campo | Tipo | Contenido |
|---|---|---|
| `id` | TEXT PK | Nombre canónico: `RGV-001` |
| `parent_id` | TEXT FK | ID del rol padre para AND NOT |
| `auth_framework` | JSONB | MFA, geo, horario, sesión |
| `tryton_privileges` | JSONB | Los 5 niveles de acceso de Tryton |
| `privilege_mask` | BIGINT | Máscara calculada (cache) |
| `sync_status` | TEXT | `PENDING` / `SYNCED` / `ERROR` / `DRIFT` |

### Alertas Wazuh SIEM

- `sync_status = 'ERROR'` → alerta MEDIA
- `sync_status = 'DRIFT'` → alerta ALTA
- Drift con permisos de más → alerta CRÍTICA + re-sincronización automática
- Delegación vencida no revocada → alerta CRÍTICA
- Modificación directa de Composite Role en KC sin pasar por RF → alerta CRÍTICA

---

## 12. Provisioning de un realm nuevo

Este flujo documenta el proceso completo de onboarding de un cliente nuevo. Cubre desde la creación del realm hasta el primer login del administrador del cliente.

### Paso 1: Crear el realm en Keycloak

El SBOS IAM Installer ejecuta el plugin `realm_bootstrap` del SBOS Data Kernel Task Catalog:

```
SBOS Data Kernel plugin: realm_bootstrap
Parámetros:
  realm_name:     "empresa-acme"
  admin_email:    "admin@acme.com"
  display_name:   "Empresa ACME S.R.L."
  locale:         "es"
  timezone:       "America/La_Paz"

El plugin crea via Keycloak Admin API:
  POST /admin/realms
  {
    "realm": "empresa-acme",
    "displayName": "Empresa ACME S.R.L.",
    "enabled": true,
    "defaultLocale": "es",
    "internationalizationEnabled": true,
    "supportedLocales": ["es", "en"]
  }
```

### Paso 2: Configurar los clients del realm

El plugin configura automáticamente los clients necesarios:

- `tryton` — client para el ERP Tryton (confidential, Authorization Code Flow)
- `saleor` — client para el e-commerce (si está en el stack)
- `sbos-admin` — client para el Core UI
- `kong` — client para el API Gateway

Cada client recibe sus redirect URIs, allowed origins, y session settings base.

### Paso 3: Desplegar los SPIs dSBOS Auth Enforce

```bash
# El SBOS IAM Installer copia los JARs al directorio providers de Keycloak
kubectl cp bauth-spi-1.0.jar keycloak-pod:/opt/keycloak/providers/
kubectl cp bauth-spi-1.0.jar keycloak-pod:/opt/keycloak/providers/

# Keycloak detecta los nuevos providers en el próximo arranque
# o mediante hot-reload si está configurado
kubectl exec keycloak-pod -- /opt/keycloak/bin/kc.sh build
kubectl rollout restart deployment/keycloak -n sbos-identity
```

Los 5 SPIs quedan disponibles como providers en el realm: `rol-temporal-authenticator`, `rol-geo-authenticator`, `rol-role-validity-authenticator`, `rol-user-configured-condition`, `rol-step-up-condition`.

### Paso 4: Cargar RolTemplates iniciales

El administrador de SKULL carga los RolTemplates base desde el catálogo (ver SBOS-009) usando el Core UI. Como mínimo, debe existir un RolTemplate para el administrador del cliente antes de que pueda iniciar sesión:

```json
{
  "id": "ADMIN_CLIENTE",
  "name": { "es": "Administrador del Sistema" },
  "status": "ACTIVE",
  "auth_framework": {
    "keycloak": {
      "authentication_flow": "browser_mfa",
      "requiredMethods": ["password", "totp"]
    }
  }
}
```

### Paso 5: Sincronizar KC + Tryton

El SBOS Auth Enforce sincroniza automáticamente al detectar los INSERTs en `bos_bauth_template` via SBOS Data Kernel WAL. La sincronización crea:
- En Keycloak: Composite Roles + Authentication Flows por cada RolTemplate
- En Tryton: Grupos con las 5 capas de acceso configuradas

Verificación de sincronización completa:
```
GET /api/v1/iam/sincronizacion
→ { "estado_servicio": "OK", "roles_en_drift": [] }
```

### Paso 6: Primer login del administrador del cliente

1. SKULL crea el usuario administrador del cliente vía Core UI con el RolTemplate `ADMIN_CLIENTE`.
2. El SBOS Auth Enforce sincroniza el usuario en Keycloak y Tryton.
3. Keycloak envía email de activación al admin con link para configurar contraseña y TOTP.
4. El admin configura sus credenciales.
5. Primer login: Keycloak ejecuta `ADMIN_CLIENTE_browser_flow` → password ✓ → TOTP ✓ → JWT emitido.
6. El admin puede ahora gestionar su propia organización desde el Core UI.

---

## 13. Flujo de onboarding de usuario

Este flujo documenta el recorrido completo desde que el administrador crea un UserTemplate en el Core UI hasta que el empleado puede autenticarse y ver su escritorio en SBOS VDI con los permisos correctos.

### Paso 1: Administrador crea el UserTemplate en Core UI

El administrador navega a Vista IAM → Gestión de Usuarios → Nuevo Usuario. Completa el formulario con los datos del empleado y selecciona los RolTemplates correspondientes (ej: `RGV_001` para una gerente regional de ventas).

El Core UI valida el formulario y hace:
```
POST /api/v1/iam/usuarios
{
  "username": "maria.garcia",
  "email": "maria.garcia@acme.com",
  "roles_assignments": {
    "active_roles": ["RGV_001"]
  },
  ...
}
```

### Paso 2: SBOS Auth Enforce sincroniza el usuario en Keycloak y Tryton

El SBOS Data Kernel detecta el INSERT en la tabla de UserTemplates y activa el plugin de sincronización. En menos de 5 segundos:

**En Keycloak:**
- Se crea el usuario con email, nombre, y atributos del RolTemplate (`allowed_days`, `shift_start`, `allowed_networks`, `role_valid_until`)
- Se asigna al grupo `/Empresa-ACME/Ventas/Norte`
- Se configura el Authentication Flow `RGV_001_browser_flow`
- Se envía email de activación

**En Tryton:**
- Se crea o actualiza `res.user` con `login = maria.garcia`
- Se asigna al grupo `RGV_001`
- Las 5 capas de enforcement quedan activas automáticamente

### Paso 3: Empleado configura sus credenciales

La empleada recibe el email de activación de Keycloak. Establece su contraseña y configura el segundo factor (TOTP con Google Authenticator o Authy, o WebAuthn con huella dactilar si el dispositivo lo soporta).

### Paso 4: Primer login

```
Browser de María → OAuth2-Proxy → Keycloak:
  1. Username + Password ✓ (verifica en BD interna KC)
  2. OTP 6 dígitos ✓ (verifica credencial TOTP en BD KC)
  3. RolTemporalAuthenticator ✓ (allowed_days incluye el día actual)
  4. RolGeoAuthenticator ✓ (IP en allowed_networks)
  5. RolRoleValidityAuthenticator ✓ (role_valid_until en el futuro)
  6. Session settings ✓ (no hay sesión concurrente activa)
  → JWT emitido con roles: ["RGV_001", "SALES_VIEW", "SALES_EDIT", "SALES_APPROVE_50K"]
```

### Paso 5: Acceso a SBOS VDI con los permisos correctos

El JWT de María llega al gateway de SBOS VDI (SBOS-009). SBOS VDI valida la firma RSA del JWT, extrae los roles, y presenta el escritorio virtual configurado para `RGV_001`: las aplicaciones del escritorio, los accesos de red, y las carpetas compartidas corresponden exactamente a los permisos de su rol.

**En Tryton:** María accede al ERP, ve solo las órdenes de venta de la Región Norte (Record Rule Capa 5), puede confirmar ventas hasta $50,000 (Button Rule Capa 4), y no ve el menú de Configuración del Sistema (Capa 2).

---

## 14. Troubleshooting de sincronización

### Casos de drift más comunes

#### Caso 1: Composite Role modificado manualmente en Keycloak

**Síntoma:** `sync_status = 'DRIFT'` en el Core UI. El Composite Role `RGV_001` en Keycloak tiene roles que no corresponden a la máscara calculada.

**Causa más frecuente:** un administrador entró directamente a la consola de Keycloak y modificó el Composite Role sin pasar por el Core UI.

**Alerta Wazuh:** `MODIFICACION_DIRECTA_COMPOSITE_ROLE` — alerta CRÍTICA.

**Detección:**
```python
# El SBOS Auth Enforce compara periódicamente:
current_in_kc = set(api.get_composite_members("RGV_001"))
expected      = set(privilege_set.realm_roles)
if current_in_kc != expected:
    update_sync_status("RGV_001", "DRIFT")
```

**Corrección desde Core UI:**
1. Ir a Vista IAM → Monitor de Sincronización.
2. Seleccionar el rol en DRIFT.
3. Hacer clic en "Forzar re-sincronización".
4. El RF ejecuta la sincronización idempotente: elimina roles de más, agrega roles faltantes.

**Corrección forzada si el Core UI no está disponible:**
```bash
# Via CLI en el host del Core
sbos iam sync-role RGV_001 --force
```

---

#### Caso 2: Usuario sin grupos en Tryton después de sincronización

**Síntoma:** el usuario puede hacer login (Keycloak emite JWT con roles), pero Tryton muestra una interfaz vacía sin ningún menú.

**Causa más frecuente:** el grupo `RGV_001` no existe en Tryton (la sincronización del RolTemplate falló antes de que se creara el usuario).

**Diagnóstico:**
```python
# En Tryton, verificar si el grupo existe:
Group.search([('name', '=', 'RGV_001')])
# Si retorna lista vacía → el grupo no se sincronizó

# Verificar sync_status en bos_bauth_template:
# SELECT sync_status, sync_error FROM bos_bauth_template WHERE id = 'RGV_001'
# → Si es 'ERROR', ver el campo sync_error para la causa
```

**Corrección:**
1. Forzar re-sincronización del RolTemplate `RGV_001` desde el Core UI.
2. Verificar que el sync_status pase a `SYNCED`.
3. El usuario debe hacer logout y login nuevamente para que `trytond-auth-keycloak` re-asigne los grupos.

---

#### Caso 3: SPI temporal bloqueando logins en horario correcto

**Síntoma:** usuarios con rol `RGV_001` no pueden hacer login aunque están dentro del horario permitido. El log de Keycloak muestra `login_outside_allowed_schedule`.

**Causa más frecuente:** el atributo `timezone` del usuario en Keycloak no coincide con el timezone real del rol (ej: `America/La_Paz` vs `America/Santiago`).

**Diagnóstico:**
```bash
# Verificar atributos del usuario en Keycloak:
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  https://auth.acme.com/admin/realms/empresa-acme/users/{user_id} \
  | jq '.attributes'
# → Verificar timezone, allowed_days, shift_start, shift_end
```

**Corrección:**
1. Actualizar el RolTemplate en el Core UI con el timezone correcto.
2. El SBOS Auth Enforce actualiza el atributo en todos los usuarios del rol.
3. O actualizar directamente el atributo del usuario afectado via Admin API de Keycloak como fix de emergencia.

---

#### Caso 4: Forzar re-sincronización completa de todos los roles

En casos de corrupción masiva del estado de Keycloak (ej: restauración de backup de KC a versión anterior), puede ser necesario re-sincronizar todos los RolTemplates.

```bash
# Desde el Core UI: Vista IAM → Monitor de Sincronización → "Re-sincronizar todo"

# Via CLI (para operación masiva):
sbos iam sync-all --force --confirm=RESINC-TOTAL-$(date +%Y%m%d)

# El comando itera sobre todos los RolTemplates en bos_bauth_template
# y ejecuta la sincronización idempotente para cada uno.
# Tiempo estimado: ~5s por rol → 50 roles = ~4 minutos
```

---

#### Caso 5: Delegación no revocada al vencer la vigencia

**Síntoma:** un usuario con delegación temporal sigue teniendo acceso ampliado después de que la fecha de vencimiento ha pasado.

**Causa:** el SBOS Data Kernel no detectó el vencimiento (estaba caído o con lag alto en el WAL).

**Detección:**
```sql
-- En bos_bauth_template, buscar delegaciones vencidas no revocadas:
SELECT id, validity_period->>'end_date', sync_status
FROM bos_bauth_template
WHERE id LIKE 'DEL_%'
  AND (validity_period->>'end_date')::timestamptz < now()
  AND sync_status != 'REVOKED';
```

**Corrección:**
```bash
# Revocar manualmente la delegación:
sbos iam revoke-delegation DEL_2025_001_JUAN --force --confirm=REVOCAR-DEL_2025_001_JUAN
```

**Alerta Wazuh:** `DELEGACION_VENCIDA_NO_REVOCADA` — alerta CRÍTICA. Wazuh detecta este estado y escala automáticamente al equipo de seguridad.

---

## 15. Hoja de ruta de implementación

| Fase | Período | Entregables Clave | Criterio de Éxito |
|---|---|---|---|
| Fase 1 — Fundación | Meses 1–2 | `bos_bauth_template` + historial. Core UI básico (PAP). `PrivilegeEngine` (AND/OR/XOR/AND NOT). KC Sync: Composite Roles. SBOS Data Kernel ROLF-001. | 5 roles sincronizados en KC y Tryton. Drift detection funcional. |
| Fase 2 — Políticas de Contexto | Meses 3–4 | Los 5 SPIs en KC (Temporal, Geo, Validity, UserConfigured, StepUp). User attributes sincronizados. `TrytonSynchronizer`: 5 capas. `trytond-auth-keycloak`: validación JWT + grupos. | Login rechazado fuera de horario. Login rechazado fuera de red. Grupos asignados automáticamente. |
| Fase 3 — Step-up y Delegaciones | Meses 5–6 | Step-up LoA 1–4. Button Rules con PYSON. Delegaciones temporales con revocación automática. SoD en Capa 4. Flujo de onboarding completo. | Operaciones de alto riesgo requieren WebAuthn. Delegaciones vencen solas. SoD bloquea incompatibles. |
| Fase 4 — Madurez | Meses 7–9 | Cobertura completa (110+ apps). Dashboard Core UI: sync, historial, drift. Integración Wazuh. Provisioning de realm completo automatizado. | Cero config manual en KC ni Tryton. Tiempo sync < 5s. |

---

## 16. Glosario técnico

| Término | Definición |
|---|---|
| **ACR** | Authentication Context Reference. Valor que describe el nivel de autenticación. Ej: `standard`, `elevated`, `high_security`, `critical`. |
| **AMR** | Authentication Method Reference (RFC 8176). Array de métodos usados. Ej: `['pwd', 'otp', 'hwk']`. |
| **AND NOT** | Operación bitwise `A & ~B`. Implementa la reducción de privilegios en la herencia jerárquica. |
| **SBOS Data Kernel** | Componente soberano del SBOS (SBOS-010) que escucha el WAL de PostgreSQL y activa plugins de forma proactiva. |
| **Button Rule** | Regla en Tryton (`ir.model.button`) que define cuántos usuarios deben pulsar un botón con condición PYSON. |
| **Composite Role** | Rol en Keycloak que contiene otros realm roles atómicos. Creado y mantenido por SBOS Auth Enforce. |
| **Core UI** | Frontend Flutter del SBOS IAM Installer (SBOS-007). Actúa como PAP dSBOS Auth Enforce. |
| **Drift** | Estado donde KC o Tryton divergen de lo que define `bos_bauth_template`. |
| **H-RBAC** | Hierarchical RBAC (ANSI/INCITS 359-2004). Roles organizados en jerarquías con herencia de privilegios. |
| **Idempotencia** | Propiedad de las sincronizaciones dSBOS Auth Enforce: si el estado ya es correcto, cero llamadas API. |
| **JWT** | JSON Web Token. Token firmado con RSA que Keycloak emite. Tryton lo valida con la clave pública JWKS. |
| **JWKS** | JSON Web Key Set. Endpoint público de Keycloak con su clave pública RSA para verificar JWTs. |
| **LoA** | Level of Assurance. Nivel numérico (1–4) de seguridad de la autenticación. |
| **Máscara Binaria** | Entero de 64 bits donde cada bit representa un permiso. Calculada por `PrivilegeEngine`. |
| **Nombre Canónico** | Identificador único usado simultáneamente como Composite Role en KC y Grupo en Tryton. |
| **PAP** | Policy Administration Point. Core UI del SBOS (SBOS-007). |
| **PDP** | Policy Decision Point. Keycloak (autenticación) + Tryton (enforcement). |
| **PEP** | Policy Enforcement Point. Tryton (5 capas) + OAuth2-Proxy. |
| **PIP** | Policy Information Point. Tabla `bos_bauth_template` en PostgreSQL. |
| **PrivilegeSet** | Objeto producido por `PrivilegeEngine` con la máscara calculada, realm roles y configuración de Tryton. |
| **PYSON** | Lenguaje de expresiones de Tryton. Se evalúa en tiempo real en el servidor. |
| **Realm Role** | Rol atómico en Keycloak con alcance global para el realm. Cada bit activo de una máscara = un realm role. |
| **Record Rule** | Regla en Tryton que agrega filtros PYSON automáticos a cada SQL. Estructural e irrompible. |
| **SBOS Auth Enforce** | Librería soberana Python de SKULL. Traduce RolTemplates al lenguaje de Keycloak y Tryton. |
| **RolTemplate** | Especificación técnica completa de un rol empresarial. Fuente de verdad única. Ver SBOS-009. |
| **SoD** | Separation of Duties. Garantiza que ningún usuario puede ejecutar sola una operación crítica de punta a punta. |
| **SPI** | Service Provider Interface de Keycloak. Mecanismo de extensión via JARs que implementan authenticators personalizados. |
| **Step-up Authentication** | RFC 9470. El servidor de recursos requiere LoA superior sin interrumpir la sesión. |
| **UserTemplate** | Especificación técnica de un usuario concreto: credenciales, roles asignados, datos de identidad. Ver SBOS-009. |
| **WAL** | Write-Ahead Log de PostgreSQL. El SBOS Data Kernel lo monitorea para detectar cambios en `bos_bauth_template`. |

---

## 17. Registro de cambios v2.0

### Creación del documento v2.0

Este documento formaliza el gobierno de identidad del SBOS que anteriormente estaba distribuido en el MANUAL-INTEGRACION-BAUTH v1.1 (sin número de documento formal) y en referencias dispersas en otros documentos del ecosistema.

**Contenido trasladado íntegramente desde MANUAL-INTEGRACION-BAUTH v1.1:**
Todo el contenido del manual original se ha trasladado sin eliminar ni condensar: el principio central de separación sincronización/login, el motor binario de privilegios (aritmética bitwise con AND NOT, OR, AND, XOR), la arquitectura completa de Keycloak, el SPI de Keycloak y su mecanismo de extensión, cómo SBOS Auth Enforce programa Keycloak durante la sincronización, el nombre canónico como identificador dual KC+Tryton, todos los flujos de operación (creación de rol, login, delegación, drift, step-up), la segregación de funciones, la implementación técnica de la librería, las 5 capas de enforcement en Tryton, la hoja de ruta de implementación, y el glosario técnico.

**Sección §4 expandida — Los 5 SPIs con firma Java completa:**
El manual original identificaba los SPIs con nombre y responsabilidad (tabla de 4 SPIs). Esta sección agrega la firma de interfaz Java completa de los 5 SPIs: `RolTemporalAuthenticator`, `RolGeoAuthenticator`, `RolRoleValidityAuthenticator`, `RolUserConfiguredCondition`, y `RolStepUpCondition` (este último es nuevo). Para cada SPI se documenta la clase Java, el método que implementa, los parámetros de entrada, el valor de retorno, y la condición de fallo. Un desarrollador puede implementar un SPI nuevo leyendo esta sección sin consultar al equipo original.

**Sección §12 nueva — Provisioning de un realm nuevo:**
El manual cubría el modelo de roles pero no el proceso de onboarding de un cliente nuevo completo. Esta sección documenta el flujo completo en 6 pasos: crear realm → configurar clients → desplegar SPIs → cargar RolTemplates iniciales → sincronizar KC + Tryton → primer login del administrador del cliente.

**Sección §13 nueva — Flujo de onboarding de usuario:**
El flujo completo Core UI → KC → Tryton → SBOS VDI no estaba documentado. Esta sección cubre desde que el administrador crea un UserTemplate en el Core UI hasta que el empleado puede autenticarse en SBOS VDI y ver su escritorio con los permisos correctos.

**Sección §14 nueva — Troubleshooting de sincronización:**
Los casos de drift entre KC y Tryton son los más frecuentes en producción. Esta sección documenta los 5 casos más comunes: Composite Role modificado manualmente, usuario sin grupos en Tryton, SPI temporal bloqueando logins en horario correcto, re-sincronización completa de emergencia, y delegación no revocada al vencer la vigencia. Para cada caso: diagnóstico, causa, y corrección paso a paso.

**Actualización de referencias de numeración:** todas las referencias se actualizan a la nueva numeración: SBOS-007 (Core UI / PAP), SBOS-009 (Contratos de Identidad), SBOS-010 (SBOS Data Kernel).

---

## Unidades Declarativas: Fichas auth

```
/etc/bos/blibs/bauth/auths/<nombre_auth>/
├── manifest.yml          ← identidad, contexto, trigger
├── auth_engine.yml       ← lógica declarativa KC + Tryton
├── auth_catalog.so       ← cálculos complejos (C ABI)
└── resources/
    └── role_templates/   ← plantillas de roles
```

Agregar un dominio de autenticación nuevo = crear su carpeta en `/etc/bos/blibs/bauth/auths/`.
El motor bauth no cambia. Hot-reload via inotify.

---

*SKULL · SBOS · SBOS-008 · v2.0 · Marzo 2026*  
*CONFIDENCIAL — Propiedad de SKULL Desarrollo de Software*

> **Referencias:** ANSI/INCITS 359-2004 — Role Based Access Control Standard · Keycloak Documentation — SPI Reference · Keycloak Documentation — Authentication Flows · RFC 9470 — OAuth 2.0 Step Up Authentication Challenge Protocol · RFC 8176 — Authentication Method Reference Values · RFC 7519 — JSON Web Token · OpenID Connect Core 1.0 · Tryton Documentation — Access Control · ISO/IEC 27001:2022 — Information Security Management · SBOS-007 Core UI v4.0 · SBOS-009 Contratos de Identidad v2.0 · SBOS-010 SBOS Data Kernel v7.0

---

## Dominios de Soberanía, BitMask y Ciclo de Vida del Realm

> **Integrado desde SBOS-008-001 y SBOS-MP01 PARTE A en v2.0.**


El Auth Enforce opera en tres dominios simultáneos. Un cambio en el RolTemplate actualiza los tres dominios en menos de 5 segundos de forma atómica.

### 1.1 Dominio Lógico

Controla acceso a recursos digitales: redes, dispositivos, aplicaciones, niveles de aseguramiento (LoA).

```yaml
# Dentro del RolTemplate
logical:
  allowed_networks: ["10.0.0.0/24", "192.168.1.0/24"]
  allowed_devices: ["registered"]     # registered | any | managed_only
  level_of_assurance: 2               # 1=password, 2=MFA, 3=MFA+biometric
  allowed_apps:
    - app: "tryton"
      permissions: ["sale.sale:read,write", "party.party:read"]
    - app: "orangehrm"
      permissions: ["portal:read"]
  session_max_minutes: 480            # 8 horas
  concurrent_sessions: 1             # 1 = no permite sesiones paralelas
```

### 1.2 Dominio Físico

Controla acceso a espacios y recursos físicos: zonas, horarios, hardware de proximidad.

```yaml
physical:
  allowed_zones:
    - zone_id: "ZONE-VENTAS"
      name: "Piso de Ventas"
      access_points: ["AP-PUERTA-01", "AP-PUERTA-02"]
    - zone_id: "ZONE-ALMACEN"
      name: "Almacén"
      access_points: ["AP-ALMACEN-01"]
  schedule:
    days: ["mon", "tue", "wed", "thu", "fri"]
    time_start: "08:00"
    time_end: "18:00"
    timezone: "America/La_Paz"
  proximity_required: false           # true = requiere proximidad NFC/BLE
  max_failed_physical_attempts: 3     # bloqueo tras 3 intentos fallidos
```

### 1.3 Dominio Financiero

Controla límites transaccionales y separación de deberes (SoD) para operaciones de valor.

```yaml
financial:
  daily_transaction_limit: 50000      # BOB
  monthly_transaction_limit: 500000   # BOB
  single_transaction_limit: 10000     # BOB — requiere aprobación si supera
  sod_rules:                          # Separation of Duties
    - action: "approve_purchase_order"
      cannot_also: "create_purchase_order"
    - action: "approve_payment"
      cannot_also: "create_payment"
  requires_dual_approval_above: 25000 # BOB — dos firmantes requeridos
  currency: "BOB"
```

### 1.4 Evaluación Combinada

Cuando un usuario solicita acceso, bauth evalúa los tres dominios en paralelo. TODOS deben aprobar:

```
Solicitud de acceso
  │
  ├── Dominio Lógico: ¿red autorizada? ¿dispositivo registrado? ¿LoA suficiente? ¿app permitida?
  │     └── FAIL → deny: "network_not_allowed" | "device_not_registered" | "loa_insufficient"
  │
  ├── Dominio Físico: ¿zona autorizada? ¿dentro de horario? ¿proximidad OK?
  │     └── FAIL → deny: "zone_denied" | "outside_schedule" | "proximity_required"
  │
  ├── Dominio Financiero: ¿dentro de límite? ¿SoD cumplido?
  │     └── FAIL → deny: "limit_exceeded" | "sod_violation"
  │
  └── TODOS OK → GRANT (generar BitMask)
```

---

## 2. Formato BitMask (64 bits)

La BitMask es un entero de 64 bits donde cada bit representa un privilegio específico. El bhnexus la empaqueta y envía a los banexus para decisiones de baja latencia sin consultar al servidor.

### 2.1 Mapa de Bits

```
Bit  0: SESSION_VALID          — sesión activa y autenticada
Bit  1: SHELL_UNLOCK           — desbloquear shell de Fedora
Bit  2: APP_TRYTON             — acceso a Tryton
Bit  3: APP_ORANGEHRM          — acceso a OrangeHRM
Bit  4: APP_SALEOR             — acceso a Saleor
Bit  5: DRAWER_OPEN            — activar relé cajón de dinero
Bit  6: DOOR_ZONE_A            — abrir puertas Zona A
Bit  7: DOOR_ZONE_B            — abrir puertas Zona B
Bit  8: DOOR_ZONE_C            — abrir puertas Zona C (restringida)
Bit  9: PRINT_ALLOWED          — imprimir documentos
Bit 10: USB_STORAGE            — acceso a dispositivos USB de almacenamiento
Bit 11: NETWORK_EXTERNAL       — acceso a internet externo
Bit 12: VPN_ACCESS             — acceso a VPN corporativa
Bit 13: ADMIN_PANEL            — acceso a panel de administración
Bit 14: FINANCIAL_APPROVE      — aprobar transacciones financieras
Bit 15: FINANCIAL_CREATE       — crear transacciones financieras
Bit 16: INVENTORY_WRITE        — modificar inventario
Bit 17: INVENTORY_READ         — consultar inventario
Bit 18: HR_WRITE               — modificar datos de RRHH
Bit 19: HR_READ                — consultar datos de RRHH
Bit 20: REPORT_GENERATE        — generar reportes
Bit 21: REPORT_EXPORT          — exportar reportes
Bit 22: BACKUP_TRIGGER         — disparar backup manual
Bit 23: SYSTEM_CONFIG          — modificar configuración del sistema
Bits 24-31: RESERVED           — reservados para extensión del dominio lógico
Bits 32-47: RESERVED           — reservados para extensión del dominio físico
Bits 48-63: CUSTOM             — definibles por cliente en RolTemplate
```

### 2.2 Ejemplo de BitMask para un Vendedor

```
Rol: Vendedor de Tienda
BitMask: 0x000000000003E627

Bit  0: 1  SESSION_VALID
Bit  1: 1  SHELL_UNLOCK
Bit  2: 1  APP_TRYTON (solo lectura — granularidad en KC)
Bit  5: 1  DRAWER_OPEN
Bit  6: 1  DOOR_ZONE_A
Bit  9: 1  PRINT_ALLOWED
Bit 13: 0  ADMIN_PANEL (no)
Bit 17: 1  INVENTORY_READ
```

### 2.3 Operaciones sobre BitMask

```go
// En bhnexus (Go)
func HasPermission(mask uint64, bit int) bool {
    return (mask & (1 << bit)) != 0
}

func GrantBit(mask uint64, bit int) uint64 {
    return mask | (1 << bit)
}

func RevokeBit(mask uint64, bit int) uint64 {
    return mask &^ (1 << bit)
}

// Ejemplo: verificar si puede abrir cajón
if HasPermission(userMask, 5) { // DRAWER_OPEN
    sendActuatorCommand("OPEN_RELAY", nodeId)
}
```

---

## 3. Plugin Keycloak: rolframework_sync

### 3.1 Tipo de SPI

El plugin es un **Authentication SPI** de Keycloak que se ejecuta durante el flujo de autenticación, DESPUÉS de que el usuario se autentica pero ANTES de que el token se emita.

### 3.2 Flujo de ejecución

```
Usuario ingresa credenciales
  │
  ▼
Keycloak: Autenticación estándar (username/password + MFA si aplica)
  │
  ▼
KC Authentication Flow → rolframework_sync execution
  │
  ├── 1. Leer RolTemplate del usuario desde atributos del grupo KC
  ├── 2. Evaluar requiredMethods del rol:
  │       ¿El nivel de autenticación actual cumple el LoA requerido?
  │       ¿El dispositivo está en la lista de allowed_devices?
  │       ¿La IP está en allowed_networks?
  │
  ├── 3. SI NO CUMPLE → AuthenticationFlowException
  │       → Token NO se emite
  │       → Usuario recibe error contextual: "Se requiere MFA para este rol"
  │
  ├── 4. SI CUMPLE → Enriquecer token con claims bos_*:
  │       bos_bitmask: "0x000000000003E627"
  │       bos_domains: ["logical", "physical", "financial"]
  │       bos_zone_allowed: ["ZONE-VENTAS"]
  │       bos_financial_limit: 50000
  │       bos_schedule: {"days":["mon-fri"],"start":"08:00","end":"18:00"}
  │
  └── 5. Token emitido con claims SBOS en el JWT
```

### 3.3 Claims SBOS en el JWT

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

---

## 4. Sincronización Atómica KC ↔ Tryton

### 4.1 Flujo de sincronización cuando se modifica un RolTemplate

```
Admin modifica RolTemplate en Core UI
  │
  ▼
bauth recibe evento via API REST
  │
  ▼
PASO 1: Validar RolTemplate (schema, SoD, herencia)
  │
  ▼
PASO 2: Sincronizar a Keycloak
  │  ├── Actualizar grupo KC con atributos del template
  │  ├── Actualizar Authentication Flow si requiredMethods cambió
  │  └── Verificar: GET /admin/realms/{realm}/groups/{group_id}
  │
  ▼
PASO 3: Sincronizar a Tryton
  │  ├── Actualizar reglas de acceso a campos (ir.rule)
  │  ├── Actualizar permisos de modelo (ir.model.access)
  │  └── Verificar: SQL query en ir_model_access
  │
  ▼
PASO 4: Registrar sync en bauth_sync_log
  │
  ▼
PASO 5: Emitir evento via Redis
  │  └── bkernel:events → {"type":"roltemplate_synced","id":"RGV_001"}
  │
  ▼
Tiempo total objetivo: < 5 segundos
```

### 4.2 Drift Detection

bauth ejecuta un check de drift cada 60 segundos:

```
RECONCILE LOOP (cada 60s):
  │
  Para cada RolTemplate activo:
  │
  ├── Leer estado declarado (RolTemplate YAML)
  ├── Leer estado real en KC (Admin API)
  ├── Leer estado real en Tryton (SQL)
  │
  ├── Comparar:
  │   ├── KC group attributes == template.logical?
  │   ├── KC auth flow == template.requiredMethods?
  │   ├── Tryton ir.rule == template.logical.apps.permissions?
  │   └── Tryton ir_model_access == template permisos por modelo?
  │
  ├── SI HAY DRIFT:
  │   ├── Log: "DRIFT detected: RolTemplate RGV_001, KC group missing attribute X"
  │   ├── Auto-corrección: re-sincronizar el template
  │   ├── Emitir evento: roltemplate_drift_corrected
  │   └── Si auto-corrección falla → alerta crítica al admin
  │
  └── SI NO HAY DRIFT: next template
```

---

## 5. Ciclo de Vida del Realm (integración SBOS-MP01 PARTE A)

### 5.1 Alta de tenant

```
Saga "onboard-tenant":
  Paso 1: Crear realm en Keycloak via Admin API
          Compensación: DELETE realm
  Paso 2: Configurar 5 SPIs custom en el realm nuevo
          Compensación: (incluido en DELETE realm)
  Paso 3: Crear usuarios iniciales (admin + service accounts)
          Compensación: DELETE usuarios
  Paso 4: Desplegar fichas contratadas en namespace K8s
          Compensación: DELETE namespace
  Paso 5: Crear BD del tenant en PostgreSQL
          Compensación: DROP DATABASE
  Paso 6: Actualizar .sbos_state.json
          Compensación: Revertir estado
  Paso 7: Emitir evento WAL "tenant.onboarded"
```

### 5.2 Suspensión temporal

```bash
# Deshabilitar realm (login bloqueado, datos conservados)
bauth tenant suspend <realm_name>
# Internamente: PUT /admin/realms/{realm} {"enabled": false}
# JWTs activos expiran en 5 minutos
```

### 5.3 Baja definitiva

```
SEMANA -2: Notificación + export de datos al cliente
DÍA 0:    Deshabilitar realm
DÍA 1:    Eliminar namespace K8s + realm KC + BD PostgreSQL
RETENCIÓN: Logs de auditoría según jurisdicción (BO:10 años, AR:10 años, MX:5 años)
```

---

## 6. Delegación Temporal con Vigencia

```yaml
# En UserTemplate
delegations:
  - delegated_to: "user-uuid-maria"
    delegated_from: "user-uuid-gerente"
    role_template: "RGV_001"
    reason: "Vacaciones del gerente"
    valid_from: "2026-03-15T00:00:00Z"
    valid_until: "2026-03-30T23:59:59Z"
    auto_revoke: true                  # bauth revoca automáticamente al expirar
    requires_approval: true            # segundo admin debe aprobar la delegación
    approved_by: "admin-uuid"
    approved_at: "2026-03-14T15:00:00Z"
```

bauth verifica vigencia en cada evaluación de acceso. Si `valid_until` ha pasado y `auto_revoke: true`, la delegación se revoca automáticamente y se emite evento `delegation_expired`.

---

## 7. Presentación de Identidad Física

### 7.1 QR Dinámico

```
Generación:
  bauth genera QR con: user_id + timestamp + HMAC-SHA256(secret)
  QR válido por 30 segundos (configurable)
  El QR codifica: "sbos://auth/{user_id}/{timestamp}/{hmac}"

Validación:
  banexus captura QR del lector USB
  banexus envía a bhnexus: {"type":"qr","data":"sbos://auth/..."}
  bhnexus extrae user_id + timestamp
  bhnexus verifica: timestamp < 30s ago AND HMAC válido
  bhnexus consulta bauth para BitMask
```

### 7.2 NFC/RFID

```
El tag NFC contiene: user_id cifrado con AES-256-GCM
Clave de cifrado almacenada en Vault, rotada cada 90 días
banexus lee tag → envía payload cifrado a bhnexus
bhnexus descifra con clave de Vault → obtiene user_id
bhnexus consulta bauth para BitMask
```

### 7.3 Biométrico (huella)

```
El lector biométrico genera template hash local
banexus envía hash a bhnexus (NUNCA el raw biometric)
bhnexus consulta bauth: match template contra UserTemplate.biometric_hash
Si match → generar BitMask
bhnexus NUNCA almacena templates biométricos — son transitorios
```

---

## 8. Registro de Cambios

### v2.0 — Marzo 2026

Documento nuevo. Integra los 3 dominios de soberanía (lógico/físico/financiero) del compendio del arquitecto, formato completo de BitMask de 64 bits con mapa de bits, plugin rolframework_sync para Keycloak con flujo de claims JWT, sincronización atómica KC↔Tryton con drift detection, ciclo de vida del realm (integra SBOS-MP01 PARTE A), delegación temporal con vigencia, y presentación de identidad física (QR/NFC/biométrico).

---

*SKULL · SBOS · SBOS-008-001 · Anexo 001 · v2.0 · Marzo 2026*

> **Referencias:** NIST SP 800-207 Zero Trust Architecture · NIST SP 800-63B Digital Identity Guidelines · Keycloak SPI Documentation · Bitmask RBAC patterns · FIDO2/WebAuthn for biometric authentication · OSDP v2 for physical access control

---

## Ciclo de Vida Completo del Realm

> **Integrado desde SBOS-MP01 PARTE A en v2.0.**

## PARTE A — Para insertar en SBOS-008: Ciclo de Vida Completo del Realm

### A.1 Alta de empresa cliente (nuevo realm)

El alta de una empresa cliente en SBOS es la creación de un nuevo **realm de Keycloak** + el despliegue de las fichas que esa empresa ha contratado.

**Proceso completo:**

```
1. El administrador de SKULL crea la empresa en el Core UI:
   - Nombre del realm (ej: "acme-corp")
   - Plan contratado (qué fichas/módulos están habilitados)
   - Datos del administrador principal del cliente

2. El IAM Installer recibe la instrucción via API REST y ejecuta la Saga "onboard-tenant":
   Paso 1: Crear realm en Keycloak via Admin API
           → POST /admin/realms con la configuración base del realm SBOS
   Paso 2: Configurar los 5 SPIs custom en el realm nuevo
           → SkbosBehavioralScoreAuthenticator, SkbosRolFrameworkProvider, etc.
   Paso 3: Crear usuarios iniciales (admin del cliente + service accounts)
   Paso 4: Desplegar las fichas contratadas en el namespace K8s del tenant
           → kubectl create namespace acme-corp
           → Desplegar fichas según el plan
   Paso 5: Crear la base de datos del tenant en PostgreSQL
           → CREATE DATABASE acme_corp_tryton OWNER tryton
   Paso 6: Actualizar .sbos_state.json con el nuevo tenant
   Paso 7: Emitir evento WAL "tenant.onboarded" → bKernel lo propaga

3. Evento WAL emitido:
   Tabla: bos_tenants, operación: INSERT
   Campos: tenant_id, realm_name, plan, created_at
   bKernel detecta este evento y activa las reglas de configuración inicial del tenant
```

**Tiempo estimado de alta:** 15-30 minutos.

**Compensación de la Saga si falla:**
- Si falla en Paso 3: eliminar realm creado en Keycloak (rollback Paso 1-2)
- Si falla en Paso 4: eliminar namespace K8s + eliminar realm (rollback completo)
- Si falla en Paso 5: eliminar BD + namespace + realm

### A.2 Modificación del tenant

| Tipo de modificación | Proceso | Impacto |
|---------------------|---------|---------|
| **Cambio de plan** (más módulos) | Desplegar nuevas fichas + actualizar atributos del realm en Keycloak | Sin downtime — las apps nuevas se añaden al namespace existente |
| **Cambio de dominio** | Actualizar issuer URL en realm + regenerar certificados | Requiere ventana de mantenimiento de 5 minutos |
| **Activar SPI adicional** | Modificar Authentication Flow del realm | Sin downtime si se usa la Admin API |
| **Cambiar configuración de feature flag** | Actualizar atributo del realm via Core UI | Inmediato — el IAM Installer lo propaga en el próximo ciclo |

### A.3 Suspensión temporal del tenant

**Caso de uso:** el cliente no paga o solicita pausar el servicio temporalmente. Los datos se conservan.

```bash
# Via Keycloak Admin API: deshabilitar el realm
curl -X PUT \
  https://bos.skull.bo/admin/realms/acme-corp \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}'

# Efecto inmediato: ningún usuario del realm puede autenticarse
# Los JWTs activos expiran en 5 minutos (duración JWT SBOS)
```

**Qué pasa con el bKernel durante la suspensión:**
- Los slots de replicación del tenant siguen activos
- Si hay actividad de base de datos (procesos internos), el bKernel la procesa
- La suspensión es a nivel de identidad (login bloqueado), no de datos

**Para suspender también el procesamiento del bKernel** (suspensión completa de datos):

```bash
# Detener el slot de replicación del tenant
sudo -u postgres psql -c \
  "SELECT pg_drop_replication_slot('bkernel_acme_corp');"
# ⚠️ Esto causa pérdida de eventos WAL del tenant durante la suspensión
# Solo hacer si la suspensión es > 1 día para evitar acumulación de WAL
```

### A.4 Baja definitiva del tenant

La baja definitiva elimina todos los datos del tenant. Es irreversible.

**Proceso formal de offboarding:**

```
SEMANA -2 (notificación al cliente):
□ Enviar aviso formal de cierre de cuenta
□ Generar y entregar export de datos al cliente:
  - pg_dump de todas las bases de datos del tenant
  - Export de usuarios y roles de Keycloak (realm export)
  - Archivos de MinIO del tenant
□ El cliente firma el recibo del export

DÍA 0 (baja efectiva):
□ Deshabilitar realm en Keycloak (acceso bloqueado)
□ Esperar 24 horas (ventana de gracia)

DÍA 1:
□ Eliminar fichas del namespace del tenant:
  kubectl delete namespace acme-corp
□ Eliminar realm de Keycloak:
  curl -X DELETE https://bos.skull.bo/admin/realms/acme-corp
□ Eliminar bases de datos del tenant en PostgreSQL:
  DROP DATABASE acme_corp_tryton;
  DROP DATABASE acme_corp_keycloak; -- ya fue eliminada con el realm
□ Eliminar slots de replicación del tenant (si quedan):
  SELECT pg_drop_replication_slot('bkernel_acme_corp_tryton');
□ Eliminar datos de MinIO del tenant
□ Actualizar .sbos_state.json removiendo el tenant

RETENCIÓN LEGAL:
□ Retener logs de auditoría en S14 (GitLab) durante el período requerido por la jurisdicción del cliente
  Bolivia: 10 años (Ley 843 en materia contable)
  Argentina: 10 años (Código Comercial)
  México: 5 años (SAT)
□ Estos logs son de solo lectura y no contienen datos de negocio — solo eventos de acceso y cambios de configuración
```

---

