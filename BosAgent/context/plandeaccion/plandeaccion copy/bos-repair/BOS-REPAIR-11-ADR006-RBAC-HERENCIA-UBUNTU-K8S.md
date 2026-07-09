---
id: ADR-006
titulo: "BOS delega autorización a Ubuntu (PAM/sudoers) y Kubernetes (RBAC API)"
estado: ACEPTADO
fecha: 2026-06-07
version: 2.0
decisores:
  - Equipo BOS
  - Arquitectura SBOS
consultados:
  - Equipo de Seguridad SKULL
  - SRE Leads
informados:
  - Todos los operadores de infraestructura SBOS
reemplaza: rbac_provider.go (RoleAdmin / RoleOperator / RoleReadonly)
relacionado_con:
  - ADR-002 (privilegios del daemon sobre K8s)
  - SBOS-BOOTSTRAP-MANUAL.md (Capa 4 — bauth rolling restart)
estandares_aplicados:
  - NIST SP 800-53 (Principle of Least Privilege)
  - NIST SP 800-207 (Zero Trust Architecture)
  - NIST SP 800-123 (Guide to General Server Security)
  - CIS Ubuntu Linux 24.04 LTS Benchmark
  - CIS Kubernetes Benchmark v1.9
  - NSA/CISA Kubernetes Hardening Guide (2023)
  - ISO/IEC 27001:2022 (A.9 — Access Control)
  - BeyondCorp / Google Identity-Aware Proxy pattern
  - MADR 4.0.0 (Markdown Architectural Decision Records)
---

# BOS — Business Operative System
## Sistema Operativo Soberano de Negocio para Ubuntu + Kubernetes

**ADR-006 + BOS-RBAC-DESIGN**
**Herencia de Autorización desde Ubuntu y Kubernetes**

*Versión 2.0  ·  Junio 2026  ·  Estado: ACEPTADO*

---

## Metadata del documento

| Campo | Valor |
|---|---|
| Identificador ADR | ADR-006 |
| Formato ADR | MADR 4.0.0 (Nygard + extensiones RACI) |
| Documento complementario | BOS-RBAC-DESIGN-v2 |
| Estado | ACEPTADO |
| Fecha de decisión | 2026-06-07 |
| Autores / Decisores | Equipo BOS / Arquitectura SBOS |
| Consultados | Equipo de Seguridad SKULL, SRE Leads |
| Informados | Todos los operadores de infraestructura SBOS |
| Reemplaza a | `rbac_provider.go` (RoleAdmin / RoleOperator / RoleReadonly) |
| Relacionado con | ADR-001 (bosctl reemplaza sudo), ADR-002 (privilegios daemon), ADR-004 (Operator Soberano — ClusterRole bosagent), ADR-005 (abstracción bosctl), BOS-REPAIR-10 (biaos safety.go), BOS-REPAIR-05 §Fase 4 tarea F4.5 |
| Estándares aplicados | NIST SP 800-53, NIST SP 800-207, NIST SP 800-123, CIS Ubuntu 24.04, CIS K8s v1.9, NSA/CISA K8s Hardening Guide, ISO 27001:2022 A.9 |

---

## Índice

1. Qué es BOS — definición correcta
2. Contexto y propósito del documento
3. El error de diseño: rbac_provider.go
4. Investigación de estándares de industria
5. Decisión arquitectural: herencia de autorización
6. Cómo funciona el modelo — flujo detallado
7. Mecanismos técnicos: Ubuntu (PAM + sudoers)
8. Mecanismos técnicos: Kubernetes (RBAC + Impersonation)
9. Matriz de operaciones BOS → permisos requeridos
10. Hardening de producción: K8s Audit Policy y controles adicionales
11. Procedimientos operacionales: onboarding y offboarding
12. Plan de migración: eliminación de rbac_provider.go
13. Preguntas operacionales resueltas (Gap anterior)
14. Configuración de referencia completa
15. Análisis de riesgos y mitigaciones
16. Glosario
17. Registro de decisiones — ADR-006 (formal MADR)

---

## 1. Qué es BOS — definición correcta

**BOS** son las siglas de **Business Operative System** — Sistema Operativo de Negocio. No es un sistema de administración ni un panel de control: es un sistema operativo soberano de alto nivel que se asienta sobre Ubuntu Linux y Kubernetes para proveer una capa unificada de operación de procesos de negocio de grado empresarial.

La distinción semántica importa arquitecturalmente:

| Término incorrecto | Término correcto | Por qué importa |
|---|---|---|
| "Sistema de Administración" | Business Operative System | Un sistema de administración gestiona configuración. BOS orquesta sagas de negocio (procesos, decisiones, flujos de trabajo complejos). |
| "Panel de control de K8s" | Capa soberana de operación | BOS no administra K8s — usa K8s como sustrato de ejecución con las mismas garantías que tiene cualquier workload soberano. |
| "Wrapper de Ubuntu" | OS de negocio sobre Ubuntu | BOS no envuelve Ubuntu — extiende Ubuntu con capacidad de orquestación de negocio preservando todos los contratos de seguridad del OS base. |

SBOS (**Sovereign Business Operative System** / Sistema Base de Operaciones Soberanas) es la instancia de producción de BOS dentro de la arquitectura SKULL: un BOS desplegado con criterios de soberanía total (sin dependencias de cloud externo, sin SaaS crítico, sin servicios de identidad de terceros).

### La pila completa

```
Ubuntu 24.04 LTS (OS soberano)
  └─ Kubernetes / Podman (orquestador soberano)
       └─ SBOS (Business Operative System — capa de operación soberana)
            ├─ bosctl         (CLI del operador humano)
            ├─ bos daemon     (motor de sagas y proxy de identidad)
            ├─ biaos          (motor HITL — Human In The Loop)
            ├─ bkernel        (detección de eventos WAL)
            ├─ bauth          (autorización de negocio)
            ├─ biedata        (único daemon autorizado para HTTP externo)
            └─ bcompass / bhnexus / bsearch (daemons soberanos)
```

---

## 2. Contexto y propósito del documento

### 2.1 Arquitectura de capas de autorización

BOS opera sobre dos sistemas que tienen su propio RBAC maduro y probado en producción durante décadas:

| Capa | Sistema | RBAC nativo | Maduro desde |
|---|---|---|---|
| OS base | Ubuntu Linux | PAM / sudoers / grupos Unix | 1992 (Linux kernel) / 1997 (PAM) |
| Orquestador | Kubernetes | RBAC API (ClusterRole, RoleBinding) | 2016 (K8s 1.5) |
| Negocio | BOS | NINGUNO — hereda de las capas inferiores | 2024 (BOS v1) |

### 2.2 Misión de BOS respecto a la autorización

BOS **no es** un sistema de identidad ni de permisos. BOS es un proxy operacional de negocio que:

- Expone operaciones de alto nivel (sagas de negocio) sobre Ubuntu y Kubernetes bajo una interfaz unificada (`bosctl`).
- Traduce operaciones de negocio a llamadas concretas sobre cada sistema subyacente.
- Delega completamente la decisión de autorización a cada sistema subyacente, propagando la identidad del usuario sin reinterpretarla.
- Registra un audit log unificado correlacionando eventos de ambos sistemas.

> **PRINCIPIO FUNDAMENTAL:** Un operador de BOS es, simultáneamente, un usuario Unix en Ubuntu y un sujeto RBAC en Kubernetes. BOS no añade ni quita permisos: los propaga. La soberanía del sistema de autorización reside en Ubuntu y Kubernetes — no en BOS.

---

## 2. El error de diseño: rbac_provider.go

### 2.1 Descripción del artefacto

El archivo `internal/security/rbac_provider.go` definía tres roles propios de BOS:

```
RoleAdmin    → "*" (todo)
RoleOperator → "install", "repair", "top", "logs", "ask", "diagnose"...
RoleReadonly → "status", "top", "logs", "health"...
```

### 2.2 Por qué es un error arquitectural

Este diseño crea un tercer sistema de autorización desincronizado de los dos sistemas ya existentes. Los problemas concretos:

| Problema | Consecuencia operacional |
|---|---|
| Triple capa de autorización (Ubuntu + K8s + BOS) | El administrador gestiona permisos en tres lugares distintos para el mismo operador. |
| Desincronización de identidades | Un operador removido de sudoers puede seguir teniendo `RoleOperator` en BOS. |
| Bypass de auditoría nativa | Las operaciones vía BOS no aparecen en los audit logs de K8s ni en journald con la identidad real. |
| Violación del Principle of Least Privilege | BOS no puede conocer con precisión los permisos reales del operador en Ubuntu/K8s. |
| Superficie de ataque adicional | Un bug en `rbacGuard()` puede conceder acceso que los sistemas subyacentes denegarían. |
| Ruptura del modelo mental del operador | El equipo ya conoce `sudoers` y `ClusterRoles` — no necesita aprender un tercer modelo. |

> **DECISIÓN:** `rbac_provider.go` es un error de diseño y será eliminado. BOS adopta íntegramente los modelos de autorización de Ubuntu (PAM/sudoers) y Kubernetes (RBAC API), sin capa intermedia propia.

---

## 3. Investigación de estándares de industria

### 3.1 Caso de referencia: Teleport — análisis profundo

#### ¿Qué es Teleport?

Teleport es una autoridad de certificados y proxy consciente de identidad que implementa protocolos como SSH, RDP, HTTPS, la API de Kubernetes, y una variedad de protocolos de bases de datos SQL y NoSQL. Es completamente transparente para las herramientas del lado del cliente y está diseñado para funcionar con todo el ecosistema DevOps actual.

Más precisamente: Teleport es una plataforma de identidad de infraestructura open-source (Apache 2.0 / AGPL-3.0, más de 20.000 estrellas en GitHub) que aplica acceso Zero Trust sobre servidores, bases de datos, clusters de Kubernetes, y — a partir de 2025 — infraestructura de agentes de IA incluyendo servidores MCP. En lugar de distribuir claves SSH, tokens de API o contraseñas de bases de datos, emite certificados criptográficos de corta duración vinculados a una identidad verificada. Cada sesión es autenticada, autorizada contra políticas basadas en roles, y completamente registrada.

#### El problema que Teleport resuelve (y que BOS también enfrenta)

Los kubeconfigs estándar usan tokens de larga duración o certificados de cliente válidos por años. Este patrón — credenciales estáticas vinculadas a un servicio en lugar de a una identidad de usuario — es exactamente el anti-patrón que `rbac_provider.go` representa para BOS.

#### Arquitectura interna de Teleport: analogía directa con BOS

Teleport opera en dos modos principales: como **Proxy Service** (proxy consciente de identidad que intercepta tráfico SSH, HTTPS y Kubernetes API) y como **Auth Server** (autoridad de certificados que todos los daemons deben autenticar). El Auth Server emite certificados para usuarios y servidores y almacena el audit log.

| Componente Teleport | Equivalente BOS | Función |
|---|---|---|
| Auth Server (CA) | K8s API server + PAM | Autoridad de identidad y verificación |
| Proxy Service | `bos daemon` | Proxy transparente que propaga identidad |
| Client (`tsh`) | `bosctl` | CLI del operador humano |
| Teleport Agent | Nodo Ubuntu / K8s node | Sistema destino que aplica la decisión de autorización |

#### Certificados de corta duración: el corazón del modelo

En Teleport, al inicio de cada conexión el usuario debe presentar un certificado válido emitido por una CA de confianza. La Autoridad de Certificados emite certificados x.509 de corta duración para Kubernetes, bases de datos, escritorios y certificados SSH para OpenSSH. Los certificados están vinculados a la identidad del usuario. Expiran automáticamente — sin necesidad de listas de revocación. Los períodos de validez cortos garantizan que los ingenieros solo tengan acceso privilegiado a la infraestructura durante el tiempo necesario para completar una tarea.

Esto elimina el problema de las *standing credentials* (credenciales permanentes), que son la causa principal de brechas en infraestructura: credenciales robadas que permanecen válidas indefinidamente.

#### El patrón de delegación de Teleport aplicado a BOS

El punto arquitectural crítico: Teleport **no implementa su propio RBAC para Kubernetes**. La autenticación basada en certificados elimina las credenciales permanentes, pero la autorización la decide siempre el sistema destino — K8s RBAC — no el proxy. Teleport es el proxy; K8s es el árbitro. Esta es la separación exacta que BOS debe implementar.

#### BeyondCorp y el modelo Zero Trust que BOS hereda

En el diseño BeyondCorp, solo usuarios con identidades verificadas y dispositivos de confianza acceden a servicios registrados a través de un proxy consciente de identidad con control de acceso centralizado. A medida que los usuarios cambian de rol o abandonan la organización, el sistema de acceso lo refleja automáticamente. En el mundo BeyondCorp no hay diferencia entre acceso local y remoto — lo que es especialmente relevante para BOS soberano, donde los operadores dentro o fuera del cluster deben tener exactamente el mismo modelo de autorización.

> **LECCIÓN DE TELEPORT PARA BOS:** Teleport resolvió exactamente el problema que BOS enfrenta — un proxy que actúa sobre infraestructura en nombre de usuarios reales sin acumular un sistema de permisos propio. Su respuesta: certificados de corta duración + propagación de identidad + delegación al sistema destino. ADR-006 formaliza este mismo patrón para BOS.

### 3.2 Principios de industria aplicados

| Principio | Estándar | Aplicación en BOS |
|---|---|---|
| Principle of Least Privilege (PoLP) | NIST SP 800-53 / CIS Benchmark | BOS solo puede hacer lo que el operador ya puede en Ubuntu/K8s — nunca más. |
| Single Source of Truth para identidad | Zero Trust Architecture (NIST SP 800-207) | Ubuntu y K8s son la fuente de verdad. BOS no duplica esa información. |
| Identity-Aware Proxy | BeyondCorp / Google Zero Trust | `bosctl` actúa como proxy que propaga identidad, no como gate keeper de permisos. |
| No Standing Credentials | Teleport / HashiCorp Vault pattern | Los certificados K8s usados por BOS son de corta duración y scoped al usuario. |
| Audit by the enforcing system | SOC 2 / ISO 27001 A.12.4 | K8s audit log y journald registran operaciones con la identidad real del operador. |
| Separation of Duties | ISO 27001:2022 A.5.3 | El iniciador de una saga destructiva no puede ser su propio aprobador (HITL). |
| Defense in Depth | NSA/CISA K8s Hardening Guide (2023) | Ubuntu PAM + sudoers + K8s RBAC + K8s Audit Policy = múltiples capas independientes. |

### 3.3 Estándar Kubernetes: User Impersonation

Kubernetes tiene un mecanismo nativo diseñado exactamente para el caso de uso de BOS: el proxy que actúa en nombre de un usuario sin usurpar su identidad.

El mecanismo se llama **User Impersonation** y funciona así:

1. El operador ejecuta `bosctl rpc bos.ficha.repair`.
2. `bosctl` autentica al operador (certificado, kubeconfig, token OIDC).
3. El bos daemon reenvía la operación al API server con los headers:
```http
Impersonate-User: ivan@sbos.local
Impersonate-Group: bos-operators
```
4. El API server autentica al daemon (service account) y verifica que tenga permiso de impersonar.
5. El API server evalúa si `ivan@sbos.local` con el grupo `bos-operators` puede ejecutar la operación. Esta decisión la toma K8s usando sus ClusterRoles — no BOS.
6. K8s permite o deniega. El resultado se propaga de vuelta a `bosctl`.

> **CLAVE:** El daemon BOS tiene un service account con el único permiso de impersonar (verbo `impersonate` sobre resource `users` en K8s). Ese es el único privilegio especial que BOS necesita en K8s.

### 3.4 Estándar Linux: PAM y sudoers como fuente de verdad

Linux-PAM es un sistema de librerías que maneja las tareas de autenticación de aplicaciones (servicios) en el sistema. La librería provee una interfaz API estable que los programas que otorgan privilegios (como `login`, `su`) usan para realizar tareas de autenticación estándar. La característica principal de PAM es que la naturaleza de la autenticación es dinámicamente configurable.

PAM separa la autenticación en cuatro grupos independientes: **account** (valida que la cuenta sea válida), **authentication** (verifica identidad), **password** (gestión de credenciales) y **session** (acciones de apertura/cierre de sesión). BOS usa PAM como verificador de account en tiempo real, no como sistema de autorización propio.

Para autorización en Ubuntu, la fuente de verdad es sudoers. BOS ejecuta comandos con la identidad del operador real:

```bash
sudo -u <operador_real> -n -- <comando_concreto>
```

Si el operador no tiene el permiso en sudoers, la operación falla — exactamente igual que si el operador lo ejecutara directamente en la terminal.

---

## 4. Decisión arquitectural: herencia de autorización

### 4.1 Enunciado de la decisión

> **ADR-006 — DECISIÓN FORMAL:** BOS no implementa RBAC propio. Delega íntegramente la decisión de autorización a PAM/sudoers para operaciones sobre Ubuntu y a la RBAC API de Kubernetes (con User Impersonation) para operaciones sobre el cluster. El archivo `rbac_provider.go` será eliminado.

### 4.2 Alternativas consideradas y descartadas

| Alternativa | Descripción | Razón de descarte |
|---|---|---|
| RBAC propio — estado actual | `rbac_provider.go` con RoleAdmin/Operator/Readonly | Triple capa desincronizada. Error de diseño confirmado. |
| RBAC propio mapeado a K8s | BOS mantiene roles propios y los traduce a ClusterRoles | Complejidad sin beneficio. Mantiene desincronización. Capa extra con su propio surface de ataque. |
| LDAP / Active Directory central | Identity provider externo centralizado | Válido en entornos enterprise grandes; agrega dependencia externa incompatible con soberanía SBOS. |
| OPA / Gatekeeper como capa media | Policy engine entre BOS y K8s | Válido para multi-tenant; innecesario para un sistema soberano con un único tenant y contratos de identidad bien definidos. |
| **Delegación completa (ADOPTADA)** | BOS propaga identidad; Ubuntu/K8s deciden | Correcto arquitecturalmente. Elimina duplicación. Compatible con todos los estándares de industria identificados. |

### 4.3 Consecuencias de la decisión

#### Positivas

- Un administrador configura acceso en exactamente dos lugares que ya conoce: `visudo` (Ubuntu) y `kubectl apply ClusterRoleBinding` (K8s).
- Los audit logs de K8s y journald registran la identidad real del operador — no la del daemon BOS.
- Revocar acceso a BOS es una operación atómica: `gpasswd -d ivan bos-operators` o `kubectl delete rolebinding`.
- La superficie de ataque se reduce: sin tercera capa de permisos que pueda tener bugs.
- Compatibilidad inmediata con herramientas estándar: `kubectl auth can-i`, `sudo -l`, `getent group`.

#### Que requieren acción

- `rbac_provider.go` debe ser eliminado (sección 12).
- El bos daemon requiere un K8s service account con permiso de impersonación.
- Cada operación BOS debe documentar qué ClusterRole y/o entrada sudoers la habilita (sección 9).
- Los operadores deben conocer que la configuración de acceso a BOS se realiza en Ubuntu/K8s, no en BOS.
- Se requiere audit policy del API server de K8s para registrar impersonation events (sección 10).

---

## 5. Cómo funciona el modelo — flujo detallado

### 5.1 Flujo general de autorización

| Paso | Actor | Acción | Sistema de autorización |
|---|---|---|---|
| 1 | Operador | Ejecuta `bosctl rpc bos.ficha.repair` | — |
| 2 | `bosctl` | Autentica al operador (kubeconfig / certificado / token OIDC) | K8s API server |
| 3 | `bos daemon` | Identifica el destino de la operación: ¿Ubuntu u K8s? | — |
| 4a | `bos daemon` | Si K8s: reenvía con header `Impersonate-User` | K8s RBAC (ClusterRole del operador) |
| 4b | `bos daemon` | Si Ubuntu: ejecuta `sudo -u <operador> -n <cmd>` | Linux PAM + sudoers del operador |
| 5 | Ubuntu / K8s | Evalúa si el operador (real) tiene el permiso | **El sistema subyacente decide — BOS no interviene** |
| 6 | `bos daemon` | Propaga resultado (permitido / denegado) a `bosctl` | — |
| 7 | `bos daemon` | Escribe en audit log unificado con identidad real | journald + K8s audit log |

### 5.2 Flujo de saga con HITL (operación destructiva)

Para operaciones como `bos.maintenance.start` que incluyen confirmación humana (HITL de biaos):

1. El operador ejecuta `bosctl rpc bos.maintenance.start --node worker-03`.
2. BOS verifica (vía K8s impersonation) que el operador tenga `bos:maintenance-initiator`. Si no → deniega inmediatamente.
3. BOS inicia la saga y la pausa en el punto HITL, emitiendo solicitud de aprobación.
4. Un segundo operador (el confirmador) recibe la solicitud.
5. BOS verifica (vía K8s impersonation) que el confirmador tenga `bos:maintenance-approver` — distinto del rol de iniciador.
6. Si el confirmador tiene el ClusterRole correcto, la saga continúa.
7. Ambas verificaciones quedan en el K8s audit log con identidades reales de ambos operadores.

> **SEPARACIÓN DE DEBERES (ISO 27001:2022 A.5.3):** El iniciador de una saga destructiva no puede ser su propio aprobador. Esta separación se configura en K8s — no en BOS.

---

## 6. Mecanismos técnicos: Ubuntu (PAM + sudoers)

### 6.1 El problema de los dos mundos de identidad

Ubuntu tiene su propio universo de identidad, completamente separado de Kubernetes:

| Plano | Identificador | Mecanismo de autorización |
|---|---|---|
| Kubernetes | `ivan@sbos.local` + grupos K8s | ClusterRole / RoleBinding |
| Ubuntu (Unix) | UID numérico (ej: `1001`) + grupos Unix | `/etc/sudoers` + `/etc/group` |

Para que BOS actúe sobre Ubuntu, cada operador debe tener también una cuenta Unix en cada nodo del cluster. Esto no es una limitación de BOS — es el modelo de seguridad del OS, y es correcto.

> **INVARIANTE DEL SISTEMA:** Un operador con capacidad de actuar sobre Ubuntu vía BOS es simultáneamente una cuenta Kubernetes (`ivan@sbos.local`) y una cuenta Unix en cada nodo (`ivan`, UID 1001). Sin la cuenta Unix, la operación Ubuntu es imposible — comportamiento correcto de seguridad.

### 6.2 La cuenta de daemon del bos daemon en Ubuntu

El daemon BOS (`bosd`) corre en Ubuntu como un service account de sistema dedicado con privilegios mínimos:

```bash
# Creación del service account del daemon — una vez en la instalación
useradd --system --no-create-home --shell /usr/sbin/nologin bosd
# bosd tiene UID en el rango system (< 1000), sin shell de login, sin home
```

Este service account tiene exactamente un privilegio especial en sudoers: el derecho de ejecutar comandos **en nombre de otros usuarios** (`sudo -u <otro_usuario>`). Esta es **delegación de identidad**, no escalada de privilegios.

| Concepto | Ejemplo | Seguro |
|---|---|---|
| Escalada de privilegios | `bosd` ejecuta como `root` | ❌ Prohibido — BOS nunca ejecuta como root |
| Delegación de identidad | `bosd` ejecuta como `ivan` | ✅ Correcto — Ivan debe tener el permiso en sudoers |

### 6.3 Mecanismo de sudoers: delegación de identidad

La sintaxis sudoers que BOS usa es:

```
bosd ALL=(bos-operators) NOPASSWD: /ruta/absoluta/comando
```

Lectura: "el usuario `bosd`, desde cualquier host, puede ejecutar `/ruta/absoluta/comando` **actuando como cualquier miembro del grupo `bos-operators`**, sin password." Si `ivan` no es miembro de `bos-operators`, el comando falla — el daemon no puede elevar a `ivan` a permisos que `ivan` no tiene.

### 6.4 El flujo completo de 9 pasos: de `bosctl` a la syscall en Ubuntu

```
[1] Operador ejecuta: bosctl rpc bos.ficha.repair --node worker-03

[2] bosctl autentica al operador contra Keycloak/OIDC
    → obtiene: { username: "ivan", unix_username: "ivan", groups: ["bos-operators"] }

[3] bosctl envía la petición al bos daemon vía JSON-RPC
    → header X-BOS-Caller-Unix: ivan
    → header X-BOS-Caller-Groups: bos-operators,bos-readonly

[4] bos daemon recibe la petición e identifica: operación Ubuntu (systemd)

[5] bos daemon construye el comando con delegación de identidad:
    sudo -u ivan -n -- /usr/bin/systemctl restart bos-ficha.service

[6] Ubuntu PAM verifica la solicitud de sudo:
    - account: ¿está la cuenta "ivan" activa y no expirada? → sí
    - sudoers policy: ¿puede "bosd" ejecutar systemctl restart bos-* como miembro de bos-operators? → sí
    - ¿es "ivan" miembro de bos-operators? → sí → AUTORIZADO

[7] El proceso se lanza con effective UID = UID de ivan
    → journald registra: "bosd ejecutó sudo como ivan: systemctl restart bos-ficha"

[8] bos daemon propaga resultado (exit code, stdout/stderr) a bosctl

[9] bos daemon escribe en audit log unificado con identidad real: ivan
    → campo auid = UID de ivan (trazabilidad forense, SOC 2 / ISO 27001)
```

La clave del paso 6: PAM verifica la membresía de grupo de Ivan **en el momento de la ejecución**. Si Ivan es removido del grupo (`gpasswd -d ivan bos-operators`), la siguiente operación falla inmediatamente — sin caché, sin sesión persistente.

### 6.5 PAM como verificador de account: el módulo `pam_unix`

Sudo llama a PAM para todas las verificaciones de autenticación. El perfil PAM de sudo en Ubuntu 24.04:

```
# /etc/pam.d/sudo
#%PAM-1.0
auth       include      system-auth
account    include      system-auth     ← verifica que ivan no esté bloqueado/expirado
password   include      system-auth
session    optional     pam_keyinit.so revoke
session    required     pam_limits.so
session    include      system-auth
```

El módulo `account` (`pam_unix.so`) verifica en tiempo real que la cuenta de Ivan sea válida: que no haya expirado, que no esté bloqueada (`passwd -l ivan`), y que tenga acceso al servicio `sudo`. Check en tiempo real — no hay estado residual en el daemon BOS que pueda bypassear esta verificación.

> **CONSECUENCIA DE SEGURIDAD:** Deshabilitar la cuenta Unix de un operador (`usermod -L ivan`) revoca inmediatamente su capacidad de ejecutar operaciones Ubuntu a través de BOS. El daemon BOS no tiene ninguna forma de continuar actuando como ese usuario.

### 6.6 Hardening de sudoers: anti-patrones prohibidos (CIS Ubuntu Benchmark)

El CIS Benchmark para Ubuntu y NIST SP 800-123 identifican los siguientes anti-patrones que BOS debe evitar:

| Anti-patrón | Riesgo | Regla BOS |
|---|---|---|
| `ALL=(ALL) NOPASSWD: ALL` | Escala cualquier usuario a root completo | **Prohibido.** Los comandos BOS son siempre explícitos. |
| `NOPASSWD` en editores (`vim`, `nano`) | Shell escape a root desde el editor | **Prohibido.** BOS no necesita editores. |
| `NOPASSWD` en intérpretes (`python3`, `bash`) | Ejecución arbitraria de código como root | **Prohibido.** Solo binarios específicos con paths absolutos. |
| Ruta relativa en sudoers (`systemctl` sin path) | PATH hijacking | **Prohibido.** Todas las rutas en `/etc/sudoers.d/bos` son absolutas. |
| `bosd ALL=(ALL) NOPASSWD: ALL` | Daemon con privilegio universal | **Prohibido.** El daemon solo opera como miembros de grupos BOS. |

### 6.7 Audit trail en Ubuntu: journald + auditd

Cuando BOS ejecuta `sudo -u ivan systemctl restart bos-ficha.service`, se generan tres eventos correlacionados:

```
# Evento 1: sudo registra la delegación en journald
Jun 07 14:32:11 worker-03 sudo[12345]: bosd : TTY=unknown ; PWD=/ ; USER=ivan ; COMMAND=/usr/bin/systemctl restart bos-ficha.service

# Evento 2: systemd registra el restart con el usuario efectivo
Jun 07 14:32:11 worker-03 systemd[1]: bos-ficha.service: Triggered by: user@1001.service (ivan)

# Evento 3: auditd registra la syscall con auid = UID real del operador
type=USER_CMD msg=audit(1717768331.123:456): pid=12345 uid=999(bosd) auid=1001(ivan) ses=42 cmd="systemctl restart bos-ficha.service" exe=/usr/bin/sudo
```

El campo `auid` (audit UID) persiste incluso a través de cambios de usuario vía `sudo` y es el identificador de trazabilidad forense mandatorio bajo SOC 2, ISO 27001 y HIPAA.

```bash
# /etc/audit/rules.d/bos.rules — reglas de auditd para trazabilidad BOS
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/sudo -F key=bos-sudo-delegation
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/systemctl -F key=bos-systemctl
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/apt-get -F key=bos-apt
```

### 6.8 Archivo completo `/etc/sudoers.d/bos`

```bash
# /etc/sudoers.d/bos
# ─────────────────────────────────────────────────────────────────────────────
# BOS — Política de delegación de identidad para el daemon bosd
# Principio: bosd actúa COMO el operador real — nunca como root
# Estándares: CIS Ubuntu 24.04 Benchmark, NIST SP 800-123, ADR-006
# ─────────────────────────────────────────────────────────────────────────────

# ── Grupo bos-readonly: solo lectura ────────────────────────────────────────
bosd ALL=(bos-readonly) NOPASSWD: /usr/bin/journalctl -u bos-* --no-pager
bosd ALL=(bos-readonly) NOPASSWD: /usr/bin/systemctl status bos-*
bosd ALL=(bos-readonly) NOPASSWD: /usr/bin/systemctl is-active bos-*
bosd ALL=(bos-readonly) NOPASSWD: /usr/bin/systemctl is-enabled bos-*

# ── Grupo bos-operators: operaciones de reparación no destructivas ──────────
bosd ALL=(bos-operators) NOPASSWD: /usr/bin/systemctl restart bos-*
bosd ALL=(bos-operators) NOPASSWD: /usr/bin/systemctl reload bos-*
bosd ALL=(bos-operators) NOPASSWD: /usr/bin/systemctl start bos-*
bosd ALL=(bos-operators) NOPASSWD: /usr/bin/apt-get install -y bos-*

# ── Grupo bos-maintenance: operaciones destructivas (requieren HITL aprobado)
bosd ALL=(bos-maintenance) NOPASSWD: /usr/bin/systemctl stop bos-*
bosd ALL=(bos-maintenance) NOPASSWD: /usr/bin/systemctl disable bos-*
bosd ALL=(bos-maintenance) NOPASSWD: /sbin/reboot
bosd ALL=(bos-maintenance) NOPASSWD: /usr/local/sbin/bos-node-drain

# ── Denegaciones explícitas (defensa en profundidad) ─────────────────────────
bosd ALL=(ALL) !/bin/bash
bosd ALL=(ALL) !/bin/sh
bosd ALL=(ALL) !/usr/bin/python3
bosd ALL=(ALL) !/usr/bin/vim
bosd ALL=(ALL) !/usr/bin/nano
```

---

## 7. Mecanismos técnicos: Kubernetes (RBAC + Impersonation)

### 7.1 Service account del daemon con permiso de impersonación

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: bos-daemon-impersonator
  labels:
    app.kubernetes.io/part-of: bos
    bos.io/component: daemon
rules:
- apiGroups: [""]
  resources: ["users", "groups", "serviceaccounts"]
  verbs: ["impersonate"]
- apiGroups: ["authentication.k8s.io"]
  resources: ["userextras/scopes"]
  verbs: ["impersonate"]
```

Ese es el único privilegio especial del daemon. Todo lo demás lo hereda del operador al que impersona.

### 7.2 Implementación Go: cómo el daemon propaga la identidad

```go
// En el cliente K8s del daemon bos — pkg/k8sclient/impersonator.go
cfg.Impersonate = rest.ImpersonationConfig{
    UserName: callerIdentity.Username,   // "ivan@sbos.local"
    Groups:   callerIdentity.Groups,     // ["bos-operators", "system:authenticated"]
}
```

### 7.3 Implementación Go: cómo el daemon propaga la identidad en Ubuntu

```go
// En el daemon bos — pkg/ubuntu/executor.go
func Execute(callerIdentity Identity, targetCommand []string) ([]byte, error) {
    args := []string{"-u", callerIdentity.UnixUsername, "-n", "--"}
    args = append(args, targetCommand...)
    cmd := exec.Command("sudo", args...)
    // "-n" = non-interactive: falla si necesita password (sin bypass posible)
    // "--" = separador de opciones de sudo y el comando (previene injection)
    return cmd.CombinedOutput()
}
```

> **SEGURIDAD:** La flag `-n` en `sudo` hace que el comando falle inmediatamente si el operador necesitaría ingresar contraseña. El separador `--` previene que un nombre de usuario malicioso sea interpretado como opción de sudo.

### 7.4 ClusterRoles recomendados para operaciones BOS

| ClusterRole | Operaciones BOS habilitadas | Quién debe tenerlo |
|---|---|---|
| `bos:readonly` | status, top, logs, health, diagnose | Todo el equipo de operaciones |
| `bos:operator` | repair, install, ask — no destructivas | Operadores senior |
| `bos:maintenance-initiator` | `bos.maintenance.start` (iniciar saga destructiva) | Operadores senior con autorización explícita |
| `bos:maintenance-approver` | Confirmar HITL de sagas destructivas | Solo leads / on-call primario |
| `bos:admin` | Todas las operaciones incluyendo configuración BOS | Arquitectos / SRE leads |

---

## 8. Matriz de operaciones BOS → permisos requeridos

Esta tabla es la referencia operacional primaria. Cada operación BOS tiene documentado exactamente qué permiso se necesita en cada sistema.

| Operación BOS | Destino | ClusterRole K8s requerido | Grupo sudoers Ubuntu requerido |
|---|---|---|---|
| `bos.status` | ambos | `bos:readonly` | `bos-readonly` |
| `bos.logs` | Ubuntu | `bos:readonly` | `bos-readonly` |
| `bos.health` | ambos | `bos:readonly` | `bos-readonly` |
| `bos.diagnose` | ambos | `bos:readonly` | `bos-readonly` |
| `bos.top` | K8s | `bos:readonly` | — |
| `bos.ficha.repair` | Ubuntu | `bos:operator` | `bos-operators` |
| `bos.ficha.install` | Ubuntu | `bos:operator` | `bos-operators` |
| `bos.ask` | K8s | `bos:operator` | — |
| `bos.ficha.restart` | Ubuntu | `bos:operator` | `bos-operators` |
| `bos.maintenance.start` | ambos | `bos:maintenance-initiator` | `bos-maintenance` |
| `bos.maintenance.confirm` (HITL) | K8s | `bos:maintenance-approver` | — |
| `bos.node.drain` | ambos | `bos:maintenance-initiator` | `bos-maintenance` |
| `bos.node.reboot` | Ubuntu | `bos:maintenance-initiator` | `bos-maintenance` |
| `bos.config.*` | K8s | `bos:admin` | — |
| `bos.daemon.manage` | Ubuntu | `bos:admin` | `bos-maintenance` |

> **REGLA DE INTERPRETACIÓN:** Si una operación toca Ubuntu Y K8s, el operador debe tener el permiso en **ambos sistemas** para que la saga complete exitosamente. La verificación K8s (impersonation) ocurre primero; si falla, la operación Ubuntu no se intenta.

---

## 9. Hardening de producción: K8s Audit Policy y controles adicionales

### 9.1 Por qué el audit logging es obligatorio

La Guía de Hardening de Kubernetes del NSA/CISA (2023) y el CIS Kubernetes Benchmark v1.9 establecen como control mandatorio la habilitación del audit logging en el API server con política explícita. Sin audit logs, es imposible investigar incidentes o detectar abuso de RBAC, especialmente en patrones de impersonación.

### 9.2 Política de auditoría K8s para eventos BOS

```yaml
# /etc/kubernetes/audit-policy.yaml — Política BOS
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Registrar TODOS los eventos de impersonación con cuerpo completo
  - level: RequestResponse
    users: ["system:serviceaccount:bos-system:bos-daemon"]
    verbs: ["impersonate"]
    resources:
      - group: ""
        resources: ["users", "groups"]

  # Registrar operaciones BOS sobre recursos propios
  - level: Request
    users: ["system:serviceaccount:bos-system:bos-daemon"]
    resources:
      - group: "bos.io"
        resources: ["*"]

  # Registrar cambios de ClusterRole y RoleBinding (gestión de acceso)
  - level: RequestResponse
    verbs: ["create", "update", "patch", "delete"]
    resources:
      - group: "rbac.authorization.k8s.io"
        resources: ["clusterroles", "clusterrolebindings", "roles", "rolebindings"]

  # Ignorar lectura de secrets de sistema (ruido)
  - level: None
    resources:
      - group: ""
        resources: ["secrets"]
    verbs: ["get", "watch", "list"]
    namespaces: ["kube-system"]

  # Por defecto: registrar metadata de todas las operaciones
  - level: Metadata
```

```bash
# Flags del kube-apiserver para activar audit logging
--audit-log-path=/var/log/kubernetes/audit.log
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
--audit-log-maxage=30
--audit-log-maxbackup=10
--audit-log-maxsize=100
```

### 9.3 Flags adicionales del kube-apiserver recomendados (CIS K8s Benchmark v1.9)

```bash
kube-apiserver \
  --authorization-mode=Node,RBAC \   # Solo Node y RBAC — sin modos inseguros
  --anonymous-auth=false \            # Sin acceso anónimo
  --audit-log-path=/var/log/kubernetes/audit.log \
  --audit-policy-file=/etc/kubernetes/audit-policy.yaml \
  --encryption-provider-config=/etc/kubernetes/encryption-config.yaml \
  --tls-min-version=VersionTLS12     # TLS 1.2+ obligatorio
```

### 9.4 Verificación del service account del daemon

```bash
# Verificar que el daemon solo tenga el permiso de impersonación
kubectl auth can-i impersonate users \
  --as=system:serviceaccount:bos-system:bos-daemon
# → yes

kubectl auth can-i create pods \
  --as=system:serviceaccount:bos-system:bos-daemon
# → no  (correcto — el daemon no debe poder crear recursos directamente)

# Auditar si el daemon tiene permisos que no debería
kubectl auth can-i --list \
  --as=system:serviceaccount:bos-system:bos-daemon
```

---

## 10. Procedimientos operacionales: onboarding y offboarding

### 10.1 Alta de un nuevo operador BOS

```bash
# ── PASO 1: Cuenta Unix en CADA nodo del cluster ────────────────────────────
for NODE in worker-01 worker-02 worker-03 control-01; do
  ssh root@$NODE "
    useradd -m -s /bin/bash -G bos-readonly ivan
    # Añadir al grupo de operaciones si procede:
    usermod -aG bos-operators ivan
    # Verificar:
    id ivan
  "
done

# ── PASO 2: ClusterRoleBinding en Kubernetes ─────────────────────────────────
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: bos-operator-ivan
  labels:
    bos.io/managed-by: bos-rbac
    bos.io/operator: ivan
subjects:
- kind: User
  name: ivan@sbos.local
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: bos:operator
  apiGroup: rbac.authorization.k8s.io
EOF

# ── PASO 3: Verificación de acceso ──────────────────────────────────────────
kubectl auth can-i --list --as=ivan@sbos.local | grep bos
sudo -l -U ivan
```

### 10.2 Baja o revocación de acceso (efecto inmediato)

```bash
# Revocar acceso Ubuntu en todos los nodos (efecto inmediato en próxima operación)
for NODE in worker-01 worker-02 worker-03 control-01; do
  ssh root@$NODE "gpasswd -d ivan bos-operators && gpasswd -d ivan bos-maintenance"
done

# Revocar acceso Kubernetes
kubectl delete clusterrolebinding bos-operator-ivan

# Bloquear cuenta Unix (extra — previene login SSH directo)
for NODE in worker-01 worker-02 worker-03 control-01; do
  ssh root@$NODE "usermod -L ivan"
done

# Verificar que el acceso fue revocado
kubectl auth can-i create bosops --as=ivan@sbos.local
# → no
```

### 10.3 Tabla de responsabilidades (RACI)

| Actividad | Arquitecto BOS | SRE Lead | Operador Senior | Auditor |
|---|---|---|---|---|
| Alta de operador nuevo | C | A/R | I | I |
| Cambio de grupo (bos-operators → bos-maintenance) | A | R | I | I |
| Revocación de acceso por incidente | A | R | I | R |
| Revisión trimestral de accesos | C | R | I | A |
| Modificación de sudoers | A | R | — | I |
| Modificación de ClusterRoles | A | R | — | I |

*A = Accountable, R = Responsible, C = Consulted, I = Informed*

---

## 11. Plan de migración: eliminación de rbac_provider.go

### 11.1 Inventario de impacto

```bash
grep -r "rbac_provider\|rbacGuard\|RoleAdmin\|RoleOperator\|RoleReadonly" ./internal/ --include="*.go"
```

### 11.2 Pasos de migración

| Paso | Acción | Criterio de completitud |
|---|---|---|
| 1 | Inventariar todas las llamadas a `rbacGuard()` | Lista completa en issue de tracking |
| 2 | Para cada llamada, documentar qué ClusterRole / grupo sudoers la reemplaza | Tabla de mapeo (ver sección 9) completada y revisada |
| 3 | Crear los ClusterRoles y RoleBindings de K8s | `kubectl get clusterrole bos:*` retorna todos los roles |
| 4 | Crear `/etc/sudoers.d/bos` en todos los nodos Ubuntu | `visudo -c -f /etc/sudoers.d/bos` OK en cada nodo |
| 5 | Implementar impersonación en el daemon | Tests de integración: usuario sin ClusterRole → denegado |
| 6 | Implementar `sudo -u <operador> -n` para operaciones Ubuntu | Tests de integración: usuario sin sudoers entry → denegado |
| 7 | Ejecutar tests de regresión completos | Suite de tests verde |
| 8 | Eliminar `rbac_provider.go` y sus referencias | `go build` sin errores, `go vet` sin warnings |
| 9 | Activar K8s Audit Policy (sección 10) | Eventos de impersonación visibles en audit.log |
| 10 | Actualizar documentación operacional | Runbooks actualizados, ADR-006 → IMPLEMENTADO |

> **RIESGO DE COEXISTENCIA:** Durante los pasos 1-7, ambos mecanismos coexistirán. `rbacGuard()` debe ser el **último** en verificar (after the underlying system). Si K8s o sudo deniegan, la operación falla independientemente de `rbacGuard()`.

---

## 12. Preguntas operacionales resueltas (Gap anterior)

El análisis previo (BOS-REPAIR Gap 2) identificó cinco preguntas sin respuesta. Con ADR-006, todas tienen respuesta:

| Pregunta | Respuesta con el nuevo modelo |
|---|---|
| ¿Quién puede ejecutar `bosctl rpc bos.ficha.repair`? | Operador con ClusterRole `bos:operator` en K8s Y miembro del grupo `bos-operators` en Ubuntu. Ambas condiciones verificadas en tiempo real. |
| ¿Quién puede confirmar un HITL de biaos? | Operador con ClusterRole `bos:maintenance-approver`. Distinto del que inició la saga. Configurado en K8s. |
| ¿Quién puede ejecutar `bos.maintenance.start`? | Operador con `bos:maintenance-initiator` (K8s) Y miembro de `bos-maintenance` (Ubuntu). Ambas capas verificadas. |
| ¿Puede un Operator ejecutar node_maintain sin aprobación de Admin? | No. Requiere `bos:maintenance-initiator` para iniciar Y `bos:maintenance-approver` para confirmar. Roles distintos, ambos verificados por K8s. |
| ¿El RBAC de bosctl y el RBAC del JSON-RPC son el mismo? | Sí: el RBAC de K8s. bosctl pasa la identidad al daemon, el daemon la propaga al API server. No hay capas propias de BOS. |

---


> **INTEGRACIÓN CON biaos (BOS-REPAIR-10):** El módulo `internal/biaos/safety.go`
> verifica autorización vía K8s impersonation ANTES de ejecutar cualquier acción
> del catálogo ICAP:
>
> - Categoría 2 (`repair_ficha`, `scale_deployment`): verifica ClusterRole `bos:operator`
> - Categoría 3 (`node_maintain`, `tenant_suspend`): verifica `bos:maintenance-initiator`
>   para iniciar y `bos:maintenance-approver` para confirmar el HITL
>
> La verificación usa `kubectl auth can-i --as=<operador>` internamente — el mismo
> mecanismo de impersonación definido en este ADR-006. Sin ambas condiciones
> (ClusterRole K8s + grupo Ubuntu sudoers), la acción no se ejecuta.
> Esto garantiza que biaos nunca pueda ejecutar una acción que el operador
> no podría ejecutar directamente con `bosctl`.

## 13. Configuración de referencia completa

### 13.1 ClusterRoles completos

```yaml
# bos-clusterroles.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: bos:readonly
  labels:
    bos.io/role: readonly
rules:
- apiGroups: ["bos.io"]
  resources: ["fichas", "logs", "metrics", "health"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: bos:operator
  labels:
    bos.io/role: operator
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      bos.io/role: operator
rules: []   # heredado por aggregation — incluye bos:readonly
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: bos:maintenance-initiator
  labels:
    bos.io/role: maintenance-initiator
rules:
- apiGroups: ["bos.io"]
  resources: ["maintenancerequests"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: bos:maintenance-approver
  labels:
    bos.io/role: maintenance-approver
rules:
- apiGroups: ["bos.io"]
  resources: ["maintenancerequests"]
  verbs: ["update"]   # solo update = solo confirmar/rechazar
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: bos:admin
  labels:
    bos.io/role: admin
rules:
- apiGroups: ["bos.io"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  namespaces: ["bos-system"]
  verbs: ["get", "list", "update", "patch"]
```

### 13.2 Service account del daemon con impersonación

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: bos-daemon-impersonator
rules:
- apiGroups: [""]
  resources: ["users", "groups", "serviceaccounts"]
  verbs: ["impersonate"]
- apiGroups: ["authentication.k8s.io"]
  resources: ["userextras/scopes"]
  verbs: ["impersonate"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: bos-daemon-impersonator
subjects:
- kind: ServiceAccount
  name: bos-daemon
  namespace: bos-system
roleRef:
  kind: ClusterRole
  name: bos-daemon-impersonator
  apiGroup: rbac.authorization.k8s.io
```

### 13.3 Grupos Unix y verificación en todos los nodos

```bash
# En cada nodo Ubuntu del cluster (idempotente):
groupadd -f bos-readonly
groupadd -f bos-operators
groupadd -f bos-maintenance

# Verificar que el sudoers es sintácticamente correcto:
visudo -c -f /etc/sudoers.d/bos
# /etc/sudoers.d/bos: parsed OK

# Verificar membresía de grupos:
getent group bos-operators
# bos-operators:x:1002:ivan,maria
```

---

## 14. Análisis de riesgos y mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Grupo Unix de nodo no sincronizado entre nodos | Media | Alto | Configuración con Ansible/Salt idempotente. Verificación post-deploy. |
| Service account `bosd` con permisos excesivos | Baja | Crítico | Auditoría trimestral con `kubectl auth can-i --list --as=system:serviceaccount:bos-system:bos-daemon`. |
| Operador revocado en K8s pero no en Ubuntu | Media | Alto | Procedimiento de offboarding RACI (sección 11) con checklist obligatorio en ambos sistemas. |
| Wildcard en sudoers añadido por error | Baja | Crítico | `visudo -c` en CI/CD antes de desplegar cambios a sudoers. Alertas auditd por cambios en `/etc/sudoers.d/`. |
| K8s audit policy desactivada | Baja | Alto | Alerta de monitoreo sobre `--audit-log-path` del API server. Verificación en bootstrap manual. |
| Privilege escalation vía PATH hijacking en sudo | Muy Baja | Crítico | Paths absolutos en todas las reglas sudoers. `secure_path` configurado en `/etc/sudoers`. |
| Compromiso del service account `bos-daemon` | Muy Baja | Crítico | Rotación periódica del token del SA. Restricción de montaje automático de tokens en pods BOS (`automountServiceAccountToken: false` excepto en el pod del daemon). |

---

## 15. Glosario

| Término | Definición en el contexto de BOS |
|---|---|
| **BOS** | Business Operative System — sistema operativo soberano de negocio. |
| **SBOS** | Sovereign Business Operative System — instancia de producción de BOS en arquitectura SKULL. |
| **ADR** | Architecture Decision Record — documento que captura una decisión arquitectural significativa con contexto, opciones y consecuencias. |
| **MADR** | Markdown Architectural Decision Records — formato estándar de ADR (MADR 4.0.0). |
| **bosctl** | CLI del operador humano para interactuar con BOS. |
| **bos daemon** / `bosd` | Proceso central de BOS que actúa como proxy de identidad y motor de sagas. |
| **biaos** | Motor HITL (Human In The Loop) de BOS para operaciones que requieren confirmación humana. |
| **HITL** | Human In The Loop — punto de pausa en una saga que requiere aprobación explícita de un humano. |
| **Impersonation (K8s)** | Mecanismo nativo de Kubernetes que permite a un service account actuar en nombre de un usuario, propagando su identidad al sistema de autorización. |
| **Delegación de identidad (Ubuntu)** | Uso de `sudo -u <usuario>` para que el daemon ejecute un comando con la identidad real del operador, sujeto a la política sudoers del operador. |
| **PAM** | Pluggable Authentication Modules — librería Linux que maneja autenticación y verificación de cuenta en tiempo real. |
| **Sudoers** | Archivo de política (`/etc/sudoers`) que define qué usuarios pueden ejecutar qué comandos como qué otros usuarios. |
| **ClusterRole** | Recurso Kubernetes que define un conjunto de permisos sobre recursos del cluster. |
| **RoleBinding / ClusterRoleBinding** | Recurso Kubernetes que vincula un ClusterRole a un usuario, grupo o service account. |
| **auid** | Audit UID — identificador de trazabilidad del usuario original en auditd Linux, que persiste a través de cambios de contexto de usuario. |
| **Standing Credentials** | Credenciales de larga duración que permanecen válidas indefinidamente — el anti-patrón que BOS evita. |
| **PoLP** | Principle of Least Privilege — principio de mínimo privilegio, NIST SP 800-53. |
| **IAP** | Identity-Aware Proxy — patrón de proxy que toma decisiones de acceso basadas en identidad verificada, no en posición de red. |

---

## 16. Registro de decisiones — ADR-006 (formato MADR 4.0.0 formal)

| Campo MADR | Contenido |
|---|---|
| Título | Delegar autorización de BOS a Ubuntu (PAM/sudoers) y Kubernetes (RBAC API) |
| Estado | ACEPTADO |
| Fecha | 2026-06-07 |
| Decisores | Equipo BOS / Arquitectura SBOS |
| Consultados | Equipo de Seguridad SKULL, SRE Leads |
| Informados | Todos los operadores de infraestructura SBOS |
| Issue vinculado | BOS-REPAIR-11 — Gap 2 — RBAC de bosctl para operaciones de reparación |

### Contexto y enunciado del problema

BOS es un Business Operative System soberano que opera sobre Ubuntu y Kubernetes. Al inicio del proyecto se implementó un RBAC propio (`rbac_provider.go`) con tres roles internos: RoleAdmin, RoleOperator, RoleReadonly. Este diseño fue reconocido como un error arquitectural porque crea una tercera capa de autorización desincronizada de dos sistemas subyacentes con RBAC maduro, probado por la industria y estandarizado por NIST, CIS y NSA/CISA.

### Factores de decisión

- Evitar desincronización de identidades entre sistemas.
- Preservar la trazabilidad forense con la identidad real del operador en audit logs.
- Minimizar la superficie de ataque eliminando capas propias de permisos.
- Mantener el modelo mental del operador usando herramientas que ya conoce.
- Cumplir con NIST SP 800-53 (PoLP), NIST SP 800-207 (Zero Trust), ISO 27001:2022 A.9 (Access Control) y CIS Benchmarks.

### Decisión

BOS no implementará ni mantendrá RBAC propio. La decisión de autorización para toda operación BOS será delegada íntegramente a:

- **Ubuntu Linux** — mediante PAM y `/etc/sudoers` para operaciones sobre el sistema operativo. El daemon `bosd` actúa con la identidad del operador real vía `sudo -u <operador> -n`.
- **Kubernetes** — mediante la RBAC API nativa (ClusterRole / RoleBinding) con User Impersonation para operaciones sobre el cluster.

El bos daemon actuará como proxy de identidad transparente: propagará la identidad del operador sin reinterpretarla ni añadir capas de permisos propias.

### Consecuencias

- `rbac_provider.go` será eliminado del código base.
- El bos daemon requiere un service account K8s con permiso de impersonación (ClusterRole `bos-daemon-impersonator`).
- Cada operación BOS documenta su permiso requerido en la Matriz de Operaciones (sección 9).
- Los administradores configuran acceso BOS con `kubectl` y `visudo` — sin configuración en BOS.
- Los audit logs de K8s y journald contendrán la identidad real del operador en cada operación BOS.
- Se requiere K8s Audit Policy activa para registrar eventos de impersonación (sección 10).

### Estándares de industria que respaldan esta decisión

- **NIST SP 800-53** — Principle of Least Privilege (AC-6)
- **NIST SP 800-207** — Zero Trust Architecture
- **NIST SP 800-123** — Guide to General Server Security
- **CIS Ubuntu 24.04 LTS Benchmark** — hardening de sudoers y PAM
- **CIS Kubernetes Benchmark v1.9** — RBAC, audit logging, API server hardening
- **NSA/CISA Kubernetes Hardening Guide (2023)** — audit policy, RBAC granular
- **ISO/IEC 27001:2022 A.9** — Access Control / A.5.3 Separation of Duties
- **BeyondCorp / Google** — Identity-Aware Proxy pattern
- **Teleport (goteleport.com)** — referencia de implementación de access plane con delegación completa
- **MADR 4.0.0** — formato de este documento (adr.github.io/madr)

---

*BOS-RBAC-DESIGN-v2.0  ·  ADR-006  ·  BOS-REPAIR-11  ·  2026-06-07  ·  SKULL / SBOS*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
