# SBOS-023 — Arquitectura de Seguridad Zero Trust End-to-End
## Modelo de amenazas, controles por capa y cumplimiento de estándares

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-023
**Versión:** 1.0
**Estado:** ACTIVO — Complemento en SBOS-023-EXT-BREACH
**Extensión:** SBOS-023-DataBreachNotification.md — SBOS-023-EXT-BREACH (Notificación de Brechas de Datos — archivo separado permanente, 517+ líneas)
**Documento nuevo** — no reemplaza a ningún documento anterior
**Clasificación:** Especificación Técnica — Seguridad Zero Trust

---

## 1. El modelo Zero Trust del SBOS

Zero Trust no es un producto ni una configuración — es un principio de diseño: **nunca confiar, siempre verificar**. En un sistema Zero Trust, el perímetro de red no es la frontera de seguridad. Un pod dentro del cluster, un proceso del servidor, un usuario en la VPN — todos son sujetos no confiables hasta que prueban su identidad y sus permisos para cada operación.

El SBOS implementa Zero Trust en siete capas concéntricas. Cada capa asume que las capas externas pueden haber sido comprometidas.

### Los siete principios Zero Trust según NIST SP 800-207

El NIST SP 800-207 define siete principios que una arquitectura debe cumplir para ser considerada Zero Trust. El SBOS los cumple todos:

| Principio NIST SP 800-207 | Implementación en SBOS |
|---|---|
| 1. Todos los recursos se consideran no confiables | Linkerd mTLS entre todos los servicios — ningún pod confía en otro por estar en el mismo namespace |
| 2. Todas las comunicaciones están aseguradas independientemente de la ubicación de red | TLS 1.3 en todas las comunicaciones, mTLS entre servicios internos via Linkerd |
| 3. El acceso a recursos individuales se otorga por sesión | JWT de Keycloak con duración de 5 minutos — cada llamada API incluye el token |
| 4. El acceso a los recursos se determina por política dinámica | H-RBAC con atributos contextuales: horario laboral, ubicación geográfica, score conductual |
| 5. La integridad y la postura de seguridad de todos los dispositivos se monitorea | Wazuh agent en todos los servidores, Kyverno en todos los pods |
| 6. Todos los accesos a recursos se autentican y autorizan | Keycloak OIDC para usuarios, mTLS para servicios, Vault para secretos |
| 7. La empresa recoge información y la usa para mejorar la postura de seguridad | Wazuh SIEM + OpenMetadata + Airflow pipelines de análisis de seguridad |

---

## 2. Modelo de amenazas — vectores y controles

El SBOS es un sistema de negocio instalado en organizaciones con activos financieros, datos de empleados y documentos sensibles. Su superficie de ataque es real y concreta.

---

### Vector 1 — Acceso no autorizado a la interfaz de usuario

**Descripción del ataque:** Un atacante externo o un empleado sin autorización intenta acceder a SBOS VDI, Core UI o cualquier aplicación web del stack sin credenciales válidas, o usando credenciales robadas.

**Controles que lo mitigan:**

| Control | Herramienta | Cómo mitiga |
|---|---|---|
| Autenticación multifactor obligatoria | Keycloak + 5 SPIs | Sin segundo factor, el password no es suficiente |
| Análisis conductual | SkbosBehavioralScoreAuthenticator (SPI-4) | Detecta logins desde ubicaciones, horarios o dispositivos inusuales |
| Lockout progresivo | Keycloak Brute Force Protection | Bloqueo temporal después de N intentos fallidos |
| WAF en el perímetro | ModSecurity (Kong Gateway) | Bloquea ataques de inyección, XSS, path traversal antes de llegar a la app |
| Session timeout estricto | Keycloak realm settings | Access Token de 5 min, Refresh Token de 30 min, inactividad cierra sesión |

---

### Vector 2 — Intercepción de comunicaciones entre servicios

**Descripción del ataque:** Un atacante con acceso a la red del cluster (lateral movement desde un pod comprometido) intercepta tráfico entre servicios para robar tokens, datos o credenciales en tránsito.

**Controles que lo mitigan:**

| Control | Herramienta | Cómo mitiga |
|---|---|---|
| mTLS automático entre todos los pods | Linkerd service mesh | Cualquier tráfico sin certificado mutuo es rechazado |
| Network Policies de K8s | Calico CNI | Pods solo pueden comunicarse con los pods que el policy explícitamente permite |
| TLS 1.3 en todas las conexiones externas | cert-manager + Let's Encrypt / CA interna | Cifrado de extremo a extremo, sin fallback a versiones vulnerables |
| Cifrado en reposo | PostgreSQL + LUKS en los volúmenes del dataserver | Datos cifrados en disco si el servidor es comprometido físicamente |

---

### Vector 3 — Escalamiento de privilegios vía roles mal configurados

**Descripción del ataque:** Un usuario con acceso legítimo al sistema modifica sus propios roles en Keycloak, se asigna permisos adicionales, o explota una mala configuración del H-RBAC para acceder a recursos que no le corresponden.

**Controles que lo mitigan:**

| Control | Herramienta | Cómo mitiga |
|---|---|---|
| H-RBAC con mínimo privilegio | SBOS Auth Enforce + Tryton enforcement | Cada rol tiene exactamente los permisos declarados en su ficha. Ningún usuario puede asignarse roles. |
| Drift detection automático | IAM Installer reconciler | Cualquier cambio manual en Keycloak que no venga del IAM Installer es detectado y revertido en el siguiente ciclo de reconciliación |
| Immutable role attributes | bos_perm_base calculado por role_calculator | Los permisos son calculados matemáticamente a partir de los atributos del rol — no son configurables manualmente |
| Auditoría completa de cambios | Keycloak Admin Events | Cada cambio en roles, usuarios o clientes queda registrado con usuario, timestamp y IP |

---

### Vector 4 — Compromiso del canal de distribución

**Descripción del ataque:** Un atacante compromete el Release Server o el canal de distribución de fichas e inyecta una ficha maliciosa que se instala en los sistemas de los clientes de SKULL.

**Controles que lo mitigan:**

| Control | Herramienta | Cómo mitiga |
|---|---|---|
| Firma Ed25519 de todos los artefactos | SKULL Release Plane | Cada ficha, regla y ruta tiene una firma criptográfica. El IAM Installer verifica la firma antes de instalar cualquier artefacto. |
| Verificación de licencias en el validador | `ficha_validator` (módulo de dominio) | Una ficha con software de licencia no aprobada no pasa el validador y no puede llegar al Release Server |
| SBOM (Software Bill of Materials) | Integrado en el proceso de release | Cada versión del sistema tiene un inventario auditado de sus dependencias |
| Canal de distribución autenticado | Release Server con mTLS | El IAM Installer solo acepta artefactos del Release Server oficial con certificado válido |

---

### Vector 5 — Exfiltración de datos vía aplicaciones del stack

**Descripción del ataque:** Un usuario autenticado legítimo (o un proceso comprometido) extrae masivamente datos del sistema a través de las APIs de las aplicaciones del stack (Tryton, OrangeHRM, Superset).

**Controles que lo mitigan:**

| Control | Herramienta | Cómo mitiga |
|---|---|---|
| Rate limiting en el API Gateway | Kong Gateway | Limita el número de requests por usuario y por endpoint. Picos anómalos activan alertas. |
| Segmentación por roles | H-RBAC con granularidad de campo | Un usuario solo ve los campos de datos para los que su rol tiene permiso. El H-RBAC de Tryton opera a nivel de campo. |
| Detección de comportamiento anómalo | Wazuh SIEM | Patrones de acceso inusuales (muchas queries en poco tiempo, acceso a datos fuera del horario laboral) disparan alertas. |
| Logs inmutables | Wazuh + OpenSearch | Todos los accesos a datos quedan registrados. Los logs no pueden ser borrados por usuarios del sistema. |
| SBOS VDI sin portapapeles externo | SBOS VDI configuration | El escritorio virtual del usuario no puede copiar datos al portapapeles del dispositivo físico si el rol no lo permite. |

---

### Vector 6 — Inyección de código en fichas o plugins del sistema

**Descripción del ataque:** Un contribuidor malintencionado o un proceso externo inyecta código malicioso en una ficha, regla YAML o plugin del bKernel que luego se ejecuta en los sistemas de los clientes.

**Controles que lo mitigan:**

| Control | Herramienta | Cómo mitiga |
|---|---|---|
| Revisión obligatoria de PR | Proceso de desarrollo (SBOS-021) | Ningún cambio llega a producción sin revisión de al menos un contribuidor senior |
| Validador bloqueante en CI | `make validate` en el pipeline | Una ficha o regla que no pasa el validador no puede ser mergeada al main |
| Firma individual por contribuidor | Ed25519 personal de cada contribuidor | Cada artefacto tiene la firma de quien lo escribió — trazabilidad completa |
| Pods sin privilegios de root | Kyverno policy `runAsNonRoot: true` | Un pod comprometido no tiene permisos de root en el nodo — el blast radius es limitado |
| Read-only filesystem en pods | Kyverno policy | Los contenedores no pueden escribir en su filesystem — solo en los volúmenes explícitamente montados |

---

## 3. Vista unificada de controles por capa

| Capa del sistema | Control principal | Herramienta | Especificado en |
|---|---|---|---|
| Autenticación de usuarios | OIDC + MFA contextual | Keycloak + 5 SPIs custom | SBOS-019 |
| Autorización en aplicaciones | H-RBAC jerárquico con atributos | SBOS Auth Enforce + Tryton enforcement | SBOS-008 |
| Comunicación entre servicios | mTLS automático en el mesh | Linkerd | SBOS-004 |
| Secretos y credenciales de servicio | Vault con lease dinámico | HashiCorp Vault | SBOS-003 |
| Segmentación de red entre pods | NetworkPolicies deny-all + allow-list | Calico CNI | SBOS-004 |
| Hardening de contenedores | Políticas CIS K8s Level 1 | Kyverno admission controller | SBOS-004 |
| Supply chain del software | Firma Ed25519 de todos los artefactos | SKULL Release Plane | SBOS-005 |
| Detección de intrusiones y anomalías | SIEM + alertas en tiempo real | Wazuh | SBOS-003 |
| Protección perimetral (WAF) | ModSecurity en el API Gateway | Kong + ModSecurity | SBOS-003 |
| Drift de configuración | Reconciliación automática | IAM Installer reconciler | SBOS-005 |
| Acceso con privilegio mínimo | Roles calculados matemáticamente | role_calculator | SBOS-008 |
| Cifrado en reposo | Volúmenes cifrados | LUKS + PostgreSQL | SBOS-004 |

---

## 4. Los 5 SPIs de Keycloak — Firmas Java completas

Los SPIs son extensiones del flujo de autenticación de Keycloak. El SBOS implementa cinco SPIs propios para autenticación contextual. Cada uno implementa la interfaz `org.keycloak.authentication.Authenticator`.

---

### SPI-1 — SkbosGuardAuthenticator

Autenticación principal de guardia: verifica la identidad base del usuario y establece el contexto de la sesión.

```java
package io.skull.sbos.keycloak.spi;

import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.Authenticator;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;

public class SkbosGuardAuthenticator implements Authenticator {

    @Override
    public void authenticate(AuthenticationFlowContext context) {
        // Verifica credenciales base (username + password)
        // Establece bos_auth_type en el contexto de sesión
        // Si OK: context.success()
        // Si fallo: context.failure(AuthenticationFlowError.INVALID_CREDENTIALS)
        UserModel user = context.getUser();
        if (user == null || !user.isEnabled()) {
            context.failure(AuthenticationFlowError.UNKNOWN_USER);
            return;
        }
        // Evalúa el contexto del realm y establece bos_auth_domain
        String realm = context.getRealm().getName();
        context.getAuthenticationSession()
               .setAuthNote("bos_auth_domain", resolveDomain(realm));
        context.success();
    }

    @Override
    public void action(AuthenticationFlowContext context) {
        // Procesa el form submit del step de credenciales
        authenticate(context);
    }

    @Override
    public boolean requiresUser() {
        return true;
    }

    @Override
    public boolean configuredFor(KeycloakSession session,
                                  RealmModel realm,
                                  UserModel user) {
        // Siempre true — este SPI aplica a todos los usuarios del realm
        return true;
    }

    @Override
    public void setRequiredActions(KeycloakSession session,
                                    RealmModel realm,
                                    UserModel user) {
        // No añade required actions — la validación es en el momento
    }

    private String resolveDomain(String realmName) {
        // Extrae el dominio lógico del nombre del realm
        // "bos-main" → "logical"
        // "bos-acme-corp" → "tenant"
        return realmName.contains("-") ? "tenant" : "logical";
    }
}
```

---

### SPI-2 — SkbosFinancialPeriodAuthenticator

Verifica que el acceso ocurre dentro del período fiscal activo. Bloquea logins fuera de períodos válidos para roles financieros críticos.

```java
package io.skull.sbos.keycloak.spi;

import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.AuthenticationFlowError;
import org.keycloak.authentication.Authenticator;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;

public class SkbosFinancialPeriodAuthenticator implements Authenticator {

    private static final String PERIOD_ATTRIBUTE = "bos_financial_period_required";
    private static final String ACTIVE_PERIOD_NOTE = "bos_active_period";

    @Override
    public void authenticate(AuthenticationFlowContext context) {
        UserModel user = context.getUser();
        // Solo aplica a usuarios con el atributo de período requerido
        String periodRequired = user.getFirstAttribute(PERIOD_ATTRIBUTE);
        if (periodRequired == null || !Boolean.parseBoolean(periodRequired)) {
            context.success();
            return;
        }
        // Consulta el período fiscal activo desde la nota de realm
        // (cargada por el IAM Installer desde Tryton al iniciar el realm)
        String activePeriod = context.getRealm()
                                     .getAttribute(ACTIVE_PERIOD_NOTE);
        if (activePeriod == null || activePeriod.equals("CLOSED")) {
            context.failure(AuthenticationFlowError.GENERIC_AUTHENTICATION_ERROR,
                            context.form()
                                   .setError("sbos.period.closed")
                                   .createErrorPage(Response.Status.FORBIDDEN));
            return;
        }
        context.getAuthenticationSession()
               .setAuthNote("bos_financial_period", activePeriod);
        context.success();
    }

    @Override
    public void action(AuthenticationFlowContext context) {
        authenticate(context);
    }

    @Override
    public boolean requiresUser() {
        return true;
    }

    @Override
    public boolean configuredFor(KeycloakSession session,
                                  RealmModel realm,
                                  UserModel user) {
        // Activo para usuarios con el atributo de período requerido
        return user.getFirstAttribute(PERIOD_ATTRIBUTE) != null;
    }

    @Override
    public void setRequiredActions(KeycloakSession session,
                                    RealmModel realm,
                                    UserModel user) {
        // Sin required actions — bloqueo en tiempo de autenticación
    }
}
```

---

### SPI-3 — SkbosGeoContextAuthenticator

Verifica la ubicación geográfica del login y aplica restricciones basadas en el atributo `bos_geo_allowed` del rol del usuario.

```java
package io.skull.sbos.keycloak.spi;

import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.AuthenticationFlowError;
import org.keycloak.authentication.Authenticator;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;

public class SkbosGeoContextAuthenticator implements Authenticator {

    private static final String GEO_ALLOWED_ATTR = "bos_geo_allowed";
    private static final String GEO_BLOCK_ATTR   = "bos_geo_blocked";

    @Override
    public void authenticate(AuthenticationFlowContext context) {
        String clientIp = context.getConnection().getRemoteAddr();
        String geoAllowed = resolveUserGeoPolicy(context.getUser(), GEO_ALLOWED_ATTR);
        String geoBlocked = resolveUserGeoPolicy(context.getUser(), GEO_BLOCK_ATTR);

        if (geoAllowed == null && geoBlocked == null) {
            // Sin política geo: acceso libre
            context.success();
            return;
        }

        String countryCode = resolveCountryFromIp(clientIp);

        if (geoBlocked != null && geoBlocked.contains(countryCode)) {
            context.failure(AuthenticationFlowError.GENERIC_AUTHENTICATION_ERROR,
                            context.form()
                                   .setError("sbos.geo.blocked")
                                   .createErrorPage(Response.Status.FORBIDDEN));
            return;
        }

        if (geoAllowed != null && !geoAllowed.contains(countryCode)) {
            context.failure(AuthenticationFlowError.GENERIC_AUTHENTICATION_ERROR,
                            context.form()
                                   .setError("sbos.geo.not_allowed")
                                   .createErrorPage(Response.Status.FORBIDDEN));
            return;
        }

        context.getAuthenticationSession()
               .setAuthNote("bos_geo_country", countryCode);
        context.success();
    }

    @Override
    public void action(AuthenticationFlowContext context) {
        authenticate(context);
    }

    @Override
    public boolean requiresUser() {
        return true;
    }

    @Override
    public boolean configuredFor(KeycloakSession session,
                                  RealmModel realm,
                                  UserModel user) {
        return user.getFirstAttribute(GEO_ALLOWED_ATTR) != null
            || user.getFirstAttribute(GEO_BLOCK_ATTR) != null;
    }

    @Override
    public void setRequiredActions(KeycloakSession session,
                                    RealmModel realm,
                                    UserModel user) {
        // Sin required actions
    }

    private String resolveUserGeoPolicy(UserModel user, String attr) {
        // Evalúa el atributo del usuario o de su rol con mayor peso
        return user.getFirstAttribute(attr);
    }

    private String resolveCountryFromIp(String ip) {
        // Resolución de país por GeoIP2 (MaxMind GeoLite2 — Apache 2.0)
        // Retorna código ISO 3166-1 alpha-2: "MX", "BO", "AR", etc.
        return GeoIpResolver.resolve(ip);
    }
}
```

---

### SPI-4 — SkbosBehavioralScoreAuthenticator

Calcula un score conductual del login (0-100) comparando el comportamiento actual con el historial del usuario. Scores bajos disparan MFA adicional.

```java
package io.skull.sbos.keycloak.spi;

import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.AuthenticationFlowError;
import org.keycloak.authentication.Authenticator;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;

public class SkbosBehavioralScoreAuthenticator implements Authenticator {

    private static final double THRESHOLD_CHALLENGE = 70.0;
    private static final double THRESHOLD_BLOCK      = 30.0;

    @Override
    public void authenticate(AuthenticationFlowContext context) {
        UserModel user = context.getUser();
        BehavioralContext current = BehavioralContext.fromRequest(context);
        BehavioralProfile historical = BehavioralProfile.load(user.getId());

        double score = historical.score(current);

        // Registrar el score en el token (via Protocol Mapper posterior)
        context.getAuthenticationSession()
               .setAuthNote("bos_score", String.valueOf(score));

        if (score < THRESHOLD_BLOCK) {
            // Score muy bajo: bloquear y alertar al SIEM
            WazuhClient.alert("BEHAVIORAL_SCORE_BLOCK",
                              user.getUsername(),
                              context.getConnection().getRemoteAddr(),
                              score);
            context.failure(AuthenticationFlowError.GENERIC_AUTHENTICATION_ERROR,
                            context.form()
                                   .setError("sbos.behavioral.blocked")
                                   .createErrorPage(Response.Status.FORBIDDEN));
            return;
        }

        if (score < THRESHOLD_CHALLENGE) {
            // Score intermedio: requerir factor adicional
            context.getAuthenticationSession()
                   .setAuthNote("bos_auth_level", "step-up");
            // El siguiente step del flow verificará el MFA adicional
        } else {
            context.getAuthenticationSession()
                   .setAuthNote("bos_auth_level", "standard");
        }

        context.success();
    }

    @Override
    public void action(AuthenticationFlowContext context) {
        authenticate(context);
    }

    @Override
    public boolean requiresUser() {
        return true;
    }

    @Override
    public boolean configuredFor(KeycloakSession session,
                                  RealmModel realm,
                                  UserModel user) {
        // Aplica a todos los usuarios con historial conductual
        return BehavioralProfile.exists(user.getId());
    }

    @Override
    public void setRequiredActions(KeycloakSession session,
                                    RealmModel realm,
                                    UserModel user) {
        // Si el usuario no tiene perfil conductual, inicializarlo
        if (!BehavioralProfile.exists(user.getId())) {
            user.addRequiredAction("SBOS_INIT_BEHAVIORAL_PROFILE");
        }
    }
}
```

---

### SPI-5 — SkbosSmartCardPinAuthenticator

Valida el PIN del smart card del usuario para roles con acceso a operaciones financieras críticas. El PIN nunca llega al servidor — solo el resultado de la validación en el chip.

```java
package io.skull.sbos.keycloak.spi;

import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.AuthenticationFlowError;
import org.keycloak.authentication.Authenticator;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;

public class SkbosSmartCardPinAuthenticator implements Authenticator {

    private static final String SMARTCARD_REQUIRED_ATTR = "bos_smartcard_required";
    private static final String SMARTCARD_SERIAL_ATTR   = "bos_smartcard_serial";

    @Override
    public void authenticate(AuthenticationFlowContext context) {
        UserModel user = context.getUser();
        String smartcardRequired = user.getFirstAttribute(SMARTCARD_REQUIRED_ATTR);

        if (!"true".equals(smartcardRequired)) {
            context.success();
            return;
        }

        // Mostrar el formulario de validación del smart card
        // El cliente (SBOS VDI) tiene el WebAuthn Bridge que comunica
        // con el chip del smart card via PKCS#11
        Response challenge = context.form()
                                    .setAttribute("smartcardSerial",
                                                  user.getFirstAttribute(SMARTCARD_SERIAL_ATTR))
                                    .createForm("sbos-smartcard-challenge.ftl");
        context.challenge(challenge);
    }

    @Override
    public void action(AuthenticationFlowContext context) {
        // Recibe el resultado de la validación del chip (challenge-response)
        // El PIN nunca llega aquí — solo la firma del challenge con la clave privada del chip
        MultivaluedMap<String, String> formData =
            context.getHttpRequest().getDecodedFormParameters();

        String challengeResponse = formData.getFirst("challenge_response");
        String challenge          = context.getAuthenticationSession()
                                           .getAuthNote("smartcard_challenge");
        String publicKey          = context.getUser()
                                           .getFirstAttribute("bos_smartcard_pubkey");

        boolean valid = SmartCardVerifier.verify(challenge, challengeResponse, publicKey);

        if (!valid) {
            context.failureChallenge(AuthenticationFlowError.INVALID_CREDENTIALS,
                                     context.form()
                                            .setError("sbos.smartcard.invalid")
                                            .createForm("sbos-smartcard-challenge.ftl"));
            return;
        }

        context.getAuthenticationSession()
               .setAuthNote("bos_auth_type", "SMART_CARD");
        context.success();
    }

    @Override
    public boolean requiresUser() {
        return true;
    }

    @Override
    public boolean configuredFor(KeycloakSession session,
                                  RealmModel realm,
                                  UserModel user) {
        return "true".equals(user.getFirstAttribute(SMARTCARD_REQUIRED_ATTR));
    }

    @Override
    public void setRequiredActions(KeycloakSession session,
                                    RealmModel realm,
                                    UserModel user) {
        // Si el rol requiere smart card y el usuario no tiene serial registrado
        if (user.getFirstAttribute(SMARTCARD_SERIAL_ATTR) == null) {
            user.addRequiredAction("SBOS_REGISTER_SMARTCARD");
        }
    }
}
```

---

## 5. SLOs de seguridad

Los SLOs de seguridad son compromisos cuantificables sobre la postura de seguridad del sistema. A diferencia de los SLOs operacionales (SBOS-024), estos miden la efectividad de los controles de seguridad.

| SLO | Objetivo | Cómo se mide |
|---|---|---|
| Tiempo de detección de intrusión (MTTD) | < 5 minutos desde el evento hasta la alerta Wazuh | Wazuh dashboard — tiempo entre evento en log y alerta disparada |
| Tiempo de respuesta a incidente P0 de seguridad | < 30 minutos desde la alerta hasta acción de contención | Registro en el runbook de respuesta a incidentes |
| Frecuencia de rotación de secretos en Vault | Cada 24 horas para credenciales de servicio | Vault audit log — lease renewals |
| Tiempo máximo entre emisión de JWT y revocación efectiva | < 5 minutos (= duración del Access Token) | Por diseño — el AT expira en 5 min; no hay revocación en tiempo real de ATs cortos |
| Disponibilidad del sistema de autenticación (Keycloak) | > 99.99% mensual (< 4.3 min de downtime/mes) | Prometheus + Alertmanager |
| Cobertura de mTLS entre servicios | 100% del tráfico este-oeste en el cluster | Linkerd dashboard — % de tráfico con mTLS activo |
| Cobertura de Wazuh agents | 100% de los servidores del cluster | Wazuh manager — agents activos vs inventario de servidores |
| Tiempo de revocación de acceso al terminar un empleado | < 15 minutos desde `orangehrm.employee.terminated` hasta usuario deshabilitado en Keycloak | bKernel event lag + Keycloak reconciliation time |

---

## 6. Proceso de respuesta a incidentes de seguridad

### 6.1 Definición de severidad

| Nivel | Definición | Ejemplos |
|---|---|---|
| **P0 — Crítico** | Brecha de seguridad activa o datos comprometidos | Acceso no autorizado confirmado a datos de producción, credenciales de admin exfiltradas, ransomware activo |
| **P1 — Alto** | Control de seguridad comprometido, brecha potencial | Keycloak inaccesible (usuarios sin autenticación), Vault sellado (secretos inaccesibles), certificado TLS expirado en producción |
| **P2 — Medio** | Anomalía de seguridad detectada sin impacto confirmado | Score conductual bajo en múltiples usuarios, intentos de fuerza bruta detectados, drift de configuración detectado |
| **P3 — Bajo** | Evento de seguridad sin riesgo inmediato | Certificado TLS próximo a expirar (> 7 días), pod corriendo con imagen no firmada en staging |

### 6.2 Roles y responsabilidades

| Rol | P0 | P1 | P2 | P3 |
|---|---|---|---|---|
| Operador de turno | Detección + alerta inmediata | Detección + alerta | Detección + ticket | Ticket |
| Security Lead (SKULL) | Coordinación de respuesta | Coordinación | Revisión | Revisión |
| Fundador / Arquitecto | Decisiones de arquitectura de emergencia | Disponible | Informado | — |
| Equipo del cliente afectado | Notificado en < 15 min | Notificado en < 1h | Notificado en < 4h | Notificado en siguiente ciclo |

### 6.3 El proceso de respuesta estándar

```
FASE 1 — DETECCIÓN (P0: 0-5 min / P1: 0-15 min)
────────────────────────────────────────────────────────────
□ Wazuh dispara alerta → Alertmanager → canal #security-alerts
□ El operador de turno confirma que no es un falso positivo
□ Abre el incidente en el sistema de tickets con nivel de severidad
□ Notifica al Security Lead por canal de comunicación de emergencia

FASE 2 — CONTENCIÓN (P0: 5-30 min / P1: 15-60 min)
────────────────────────────────────────────────────────────
□ Aislar el componente comprometido (kubectl cordon del nodo si es necesario)
□ Revocar tokens y sesiones activas del usuario/servicio comprometido
  → keycloak-admin-cli users logout --userid={uuid}
□ Bloquear el acceso externo si corresponde (Kong Gateway — IP block)
□ Preservar evidencia: exportar logs de Wazuh + Keycloak antes de cualquier cambio

FASE 3 — ERRADICACIÓN (P0: 30 min - 4h / P1: 1h - 8h)
────────────────────────────────────────────────────────────
□ Identificar la causa raíz del incidente
□ Aplicar el fix (parche, rotación de credenciales, corrección de config)
□ El IAM Installer reconciler verifica que el estado deseado está restaurado
□ Verificar que la firma Ed25519 de todos los artefactos afectados es válida

FASE 4 — RECUPERACIÓN (post-erradicación)
────────────────────────────────────────────────────────────
□ Restaurar el componente afectado desde la versión anterior verificada
□ Confirmar que todos los health checks y SLOs de seguridad están en verde
□ Notificación de resolución al equipo del cliente

FASE 5 — POST-MORTEM (dentro de las 48h post-P0 / 72h post-P1)
────────────────────────────────────────────────────────────
□ Documento de post-mortem con: timeline, causa raíz, impacto, acciones correctivas
□ Actualizar este documento si el incidente revela un vector no documentado
□ Actualizar los runbooks de SBOS-024 si el proceso de respuesta puede mejorarse
```

---

## 7. Mapeo a NIST Cybersecurity Framework 2.0

El NIST CSF 2.0 (publicado en febrero 2024) organiza la ciberseguridad en seis funciones. El SBOS cubre las seis:

| Función CSF 2.0 | Descripción | Controles SBOS que la implementan |
|---|---|---|
| **GOVERN (GV)** | Establecer y monitorear la estrategia de riesgo de ciberseguridad | SBOS-018 (Estándares), SBOS-022 (Bounded Contexts y responsabilidades), este documento (política de seguridad) |
| **IDENTIFY (ID)** | Comprender los activos, riesgos y vulnerabilidades de la organización | Inventario de fichas (IAM Installer), OpenMetadata (catálogo de datos), Modelo de amenazas (§2 de este documento) |
| **PROTECT (PR)** | Implementar salvaguardas para prevenir o reducir el impacto de incidentes | mTLS (Linkerd), WAF (ModSecurity), H-RBAC (SBOS Auth Enforce), Vault, cifrado en reposo, firma Ed25519 |
| **DETECT (DE)** | Detectar la ocurrencia de eventos de ciberseguridad | Wazuh SIEM, Alertmanager, análisis conductual (SPI-4), drift detection (IAM Installer) |
| **RESPOND (RS)** | Tomar acción ante un incidente de ciberseguridad detectado | Proceso de respuesta (§6), runbooks (SBOS-024), revocación de acceso automatizada |
| **RECOVER (RC)** | Restaurar las capacidades afectadas por un incidente | Rollback del IAM Installer (CU-04 en SBOS-022), backups de PostgreSQL, versiones firmadas en Release Server |

---

## 8. Controles ISO 27001:2022 cubiertos

El Anexo A de ISO 27001:2022 tiene 93 controles en cuatro categorías. El SBOS cubre los controles más relevantes para un sistema de negocio operativo:

| Control ISO 27001:2022 | Nombre | Implementación en SBOS |
|---|---|---|
| A.5.2 | Roles y responsabilidades de seguridad | Definidos en §6.2 de este documento |
| A.5.15 | Control de acceso | H-RBAC (SBOS-008) + Keycloak (SBOS-019) |
| A.5.16 | Gestión de identidad | IAM Installer + Keycloak (SBOS-005) |
| A.5.17 | Información de autenticación | Vault con lease dinámico (SBOS-003) |
| A.5.18 | Derechos de acceso | SBOS Auth Enforce — mínimo privilegio calculado (SBOS-008) |
| A.5.23 | Seguridad en el uso de servicios en la nube | K8s soberano on-premise — no hay dependencia de nube pública |
| A.5.36 | Cumplimiento de políticas | `make validate` bloqueante en CI (SBOS-018) |
| A.6.8 | Reporte de eventos de seguridad | Wazuh → Alertmanager → canal de alertas (SBOS-003) |
| A.7.9 | Seguridad de activos fuera de las instalaciones | SBOS VDI — el escritorio no expone datos al dispositivo físico (SBOS-012) |
| A.8.3 | Restricción de acceso a la información | H-RBAC a nivel de campo en Tryton (SBOS-008) |
| A.8.5 | Autenticación segura | OIDC + MFA contextual con 5 SPIs (SBOS-019) |
| A.8.6 | Gestión de capacidad | SLOs y Alertmanager (SBOS-024) |
| A.8.8 | Gestión de vulnerabilidades técnicas | Wazuh vulnerability scanner, Kyverno policy enforcement |
| A.8.9 | Gestión de la configuración | IAM Installer drift detection + reconciliación automática (SBOS-005) |
| A.8.12 | Prevención de fuga de datos | SBOS VDI sin portapapeles externo, H-RBAC por campo, rate limiting en Kong |
| A.8.15 | Registro de actividad (logging) | Wazuh + Keycloak audit log + OpenSearch inmutable |
| A.8.20 | Seguridad de redes | NetworkPolicies Calico + mTLS Linkerd (SBOS-004) |
| A.8.24 | Uso de criptografía | TLS 1.3, mTLS, Ed25519, Vault, cifrado en reposo |
| A.8.25 | Ciclo de vida de desarrollo seguro | Validador bloqueante, firma de artefactos, revisión de PR (SBOS-018, SBOS-021) |

---

## 9. Registro de cambios

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| 1.0 | Marzo 2026 | SKULL Team | Documento inicial — modelo de amenazas, controles por capa, SPIs Java, SLOs de seguridad, proceso de respuesta a incidentes, NIST CSF 2.0, ISO 27001:2022 |

---

*SKULL · SBOS · SBOS-023-SECURITY · v1.0 · Marzo 2026*
*Complementa: SBOS-019 (métodos de autenticación), SBOS-020 (tokens y respuestas), SBOS-008 (H-RBAC)*
