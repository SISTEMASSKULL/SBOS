# SBOS — Roles de Componentes en bAuth: Keycloak, Tryton-PDP y el BitMask
## v1.7 — bAuth como orquestador extensible de motores de identidad y autorización
### SKULL · SBOS · SBOS-BAUTH-COMPONENT-ROLES v1.7 · Junio 2026

---

## 0. EL MODELO CORRECTO

bAuth es el proveedor de autenticación/identidad de SBOS. No es un motor más entre otros — es quien administra y orquesta todo lo demás.

```
bAuth — proveedor de autenticación, orquestador de motores
  │
  ├── Motor: Keycloak    (identidad y autenticación)
  │
  ├── Motor: Tryton-PDP  (autorización sobre recursos de gobierno —
  │                        pod separado, dedicado exclusivamente
  │                        al servicio de bAuth)
  │
  ├── Motor N...          (incorporado solo si un dominio lo exige —
  │                        ver Sección 0.1)
  │
  └── BitMask — instrumento independiente que bAuth administra
        (calcula el privilegio de un usuario sobre un recurso)
```

**Nota de alcance:** Tryton también opera como ERP — eso se trata en la Sección 2, dejando claro que no tiene relación con bAuth. El resto del documento (Secciones 3-7) trata exclusivamente los componentes de bAuth: KC, Tryton-PDP y el BitMask.

Dos precisiones que quedan fijas a partir de esta versión:

1. **KC y Tryton-PDP no se fusionan.** Cada uno es su propio motor, con su propio rol.
2. **bAuth administra el BitMask — no KC, no Tryton-PDP.** KC es el punto donde el cálculo se invoca, al emitir el token. Tryton-PDP puede ser una de las fuentes que alimentan ese cálculo para recursos de gobierno. Pero la autoridad sobre el BitMask — quién lo define, quién lo versiona, quién decide su estructura de 64 bits — es bAuth.

### 0.1 El modelo es extensible — bAuth orquesta, no está atado a dos motores

KC y Tryton-PDP son los dos motores que existen **hoy**, no un techo de diseño. El principio de fondo es más amplio: **bAuth es una capa de orquestación de identidad y autorización.** Si un dominio nuevo exige una lógica de evaluación que ni KC (identidad/sesión) ni Tryton-PDP (autorización ORM sobre recursos de gobierno) cubren adecuadamente, se incorpora un motor adicional — bAuth sigue siendo el único punto de administración y verdad, sin importar cuántos motores coordine por debajo.

**Esto no es una idea nueva — ya estaba en METHODOLOGY desde el principio**, en la capa External-Path de la metodología de 3 capas (Fast-Path / Policy-Path / External-Path). Vault (custodia y rotación de claves), Kong (políticas de red), los sensores biométricos (D5), y Loki/Wazuh (D11, auditoría) son, sin que se hubiera nombrado así hasta ahora, motores externos que bAuth ya orquesta para dominios que ni KC ni Tryton-PDP resuelven. Lo único que faltaba era declarar el principio explícitamente, junto a KC y Tryton-PDP, en el mismo documento de roles.

**Por qué esto es lo que permite que bAuth escale a negocios de cualquier tamaño:** una PyME puede operar con KC + Tryton-PDP solamente. Una empresa con necesidades más complejas — biometría avanzada, un HSM dedicado, un motor de riesgo/fraude específico, integración con un proveedor de PKI externo — incorpora el motor que ese dominio requiera, sin reemplazar la arquitectura central ni renegociar cómo se administra el resto del sistema.

**Criterios para incorporar un motor nuevo** (para que esto no se convierta en sprawl sin control):

1. El dominio requiere lógica de evaluación que ni KC ni Tryton-PDP cubren adecuadamente — no se agrega un motor "porque sí" o por preferencia tecnológica.
2. **bAuth sigue siendo el único administrador.** El motor nuevo nunca se convierte en un punto de entrada paralelo — la misma regla que NEXUS v3.0 confirmó de forma independiente para bhnexus/banexus: ningún ejecutor habla directamente con un motor, todos hablan con bAuth.
3. Se documenta con la misma plantilla usada para KC y Tryton-PDP: objetivo, alcance, papel en la solución, propósito, capacidades, método de actualización de datos, y qué NO hace.
4. Se evalúa su impacto en el BitMask: ¿el motor nuevo aporta un capacity-bit de Fast-Path, o se queda enteramente en Policy/External-Path? Esto evita repetir el error original de SBOS-008-001 v1.0 — mezclar capas de abstracción en el mismo vector de 64 bits.

---

## 1. KEYCLOAK — MOTOR DE IDENTIDAD

Keycloak es un Identity Provider basado en los estándares **OpenID Connect (OIDC)** y **OAuth2**. Dentro de bAuth, su responsabilidad se limita estrictamente a identidad y autenticación — nunca a autorización de datos de negocio ni de recursos de gobierno, eso es trabajo de Tryton-PDP.

| Atributo | Definición |
|---|---|
| **Objetivo** | Ser el único punto de verdad de identidad y autenticación de SBOS |
| **Alcance** | Autenticación (login, MFA, step-up), gestión de sesión/token (emisión, refresh, revocación), atributos de grupo que reflejan el RolTemplate compilado, ciclo de vida del realm por tenant |
| **Papel en la solución** | Policy Enforcement Point del login (gate de entrada). En ese punto, bAuth invoca el cálculo del BitMask y empaqueta el resultado como claim en el JWT que KC emite |
| **Propósito** | Resolver "¿quién eres y qué precondiciones de sesión cumples?" — una sola vez, al entrar o al refrescar el token |
| **Capacidades** | SPI custom `rolframework_sync`; Admin REST API para gestión de realms/grupos/usuarios; Authentication Flows configurables; protocol mappers para custom claims; ciclo de vida completo del realm (alta/suspensión/baja, SBOS-008-001 §5) |
| **Lo que NO hace** | No conoce el esquema de ninguna app cliente. No evalúa permisos por request. No controla hardware. No administra el BitMask — solo es el punto donde bAuth lo invoca |

### 1.1 Cómo bAuth actualiza datos en KC

Keycloak no se modifica escribiendo directamente en su base de datos. Toda actualización — crear un grupo, cambiar sus atributos, ajustar un Authentication Flow, revocar una sesión — pasa por la **Admin REST API**, bajo el patrón `/admin/realms/{realm}/...`.

El flujo que usa bAuth, vía `rolframework_sync`, es:

1. **Obtener un token de servicio.** bAuth está registrado en KC como client confidencial con *Service Account* habilitado, y a esa cuenta de servicio se le asignan roles administrativos acotados (p. ej. `manage-users`, `manage-realm` del client `realm-management`). El token se pide contra el endpoint OIDC estándar:
   ```
   POST /realms/{realm}/protocol/openid-connect/token
   grant_type=client_credentials
   client_id=bauth-sync
   client_secret=...
   ```
2. **Invocar la Admin REST API con ese token** como Bearer en el header `Authorization`. Ejemplo — actualizar los atributos de un grupo tras modificar un RolTemplate:
   ```
   PUT /admin/realms/{realm}/groups/{group_id}
   Authorization: Bearer eyJhbGci...
   ```
3. **Verificar** con un GET al mismo endpoint que el cambio se aplicó — el paso de verificación ya descrito en SBOS-008-001 §4.1.

**Por qué no se toca la base de datos directamente:** Keycloak cachea agresivamente sus datos de realm, grupos y sesiones. La propia comunidad de Keycloak ha documentado este problema en sus reportes públicos: editar una fila directamente en la base de datos (por ejemplo, un timestamp de sesión) no tiene ningún efecto visible para Keycloak hasta que se fuerza un flush de caché o se pasa por el endpoint REST correspondiente — el servidor sigue sirviendo el dato cacheado, ajeno al cambio. La única vía soportada y consistente es la Admin REST API.

**Nota de versión:** en distribuciones de Keycloak anteriores a la v17 (basadas en WildFly), todos estos endpoints llevaban el prefijo `/auth/` (`/auth/admin/realms/...`). Desde la migración a la distribución Quarkus (v17+), ese prefijo desaparece por defecto. Esto debe fijarse explícitamente en la integración de bAuth para no asumir la ruta equivocada según la versión desplegada.

**Separación de realms:** el realm `master` administra Keycloak mismo; cada tenant de SBOS vive en su propio realm — un patrón ya alineado con el aislamiento por tenant del resto de la arquitectura (SBOS-008-001 §5).

### 1.2 Salud y observabilidad

Desde la distribución Quarkus, Keycloak expone un **puerto de management separado (9000 por defecto)**, no accesible desde fuera del clúster, con los siguientes endpoints:

| Endpoint | Propósito |
|---|---|
| `/health/live` | ¿El proceso de Keycloak sigue vivo? |
| `/health/ready` | ¿Puede ya aceptar tráfico (DB conectada, etc.)? |
| `/health/started` | Probe de arranque inicial, usado antes de que el liveness probe tome el control |

bAuth debe consultar `/health/ready` antes de depender de KC para una decisión de login, y usar el resultado para decidir si aplica el principio de **fallo cerrado**: si KC no está disponible, no se emite ningún token nuevo — un login fallido es preferible a un login no verificado.

### 1.3 Seguridad de las credenciales de servicio

El `client_secret` de la cuenta de servicio `bauth-sync` y los tokens de acceso que emite son material sensible. Siguiendo el mismo patrón que SBOS-008-001 §7.2 ya define para las claves NFC (almacenadas en Vault, rotadas cada 90 días), el `client_secret` de KC debe vivir en Vault, no en configuración estática, con rotación periódica y revocación inmediata ante sospecha de compromiso. Los access tokens de la Admin REST API son de corta duración por diseño (minutos, no horas) — la credencial de larga vida que realmente hay que proteger es el `client_secret`, no el token.

---

## 2. TRYTON-ERP — APLICACIÓN DEL ECOSISTEMA, SIN RELACIÓN CON bAuth

Tryton también opera como ERP — ventas, inventario, RRHH, contabilidad — pero en ese rol es **una aplicación más del ecosistema SBOS**, igual que OrangeHRM o Saleor. Se comporta como tal, sin ningún vínculo especial con bAuth:

| Atributo | Definición |
|---|---|
| **Qué es** | Una aplicación gobernada por bAuth, como cualquier otra del ecosistema |
| **Relación con bAuth** | Ninguna especial — consume claims JWT y recibe sincronización de permisos exactamente igual que OrangeHRM o Saleor |
| **No es** | Un motor de bAuth. No participa en el cálculo del BitMask. No es Tryton-PDP — aunque comparta el mismo motor `trytond`, son despliegues distintos |
| **Dónde se define** | En otros documentos del proyecto — fuera del alcance de este documento |

La coincidencia de motor (`trytond`) entre Tryton-ERP y Tryton-PDP es una coincidencia de tecnología, no de arquitectura: son dos despliegues independientes con roles completamente distintos dentro del ecosistema. Que ambos corran sobre el mismo software no le da a Tryton-ERP ningún rol en bAuth.

---

## 3. TRYTON-PDP — MOTOR DE AUTORIZACIÓN DE bAuth

Pod separado del Tryton-ERP, corriendo el mismo motor `trytond` pero sin ningún módulo de negocio — dedicado exclusivamente a servirle a bAuth.

| Atributo | Definición |
|---|---|
| **Objetivo** | Ser el motor de decisión de autorización para recursos de gobierno de SBOS que se benefician de un modelo ORM con Access Rights — administrado por bAuth |
| **Alcance** | Solo los módulos núcleo `ir`/`res` + módulos custom de bAuth (`bauth.zone`, `bauth.financial_limit`, `bauth.delegation`, etc.) — **sin** módulos de negocio, sin acoplamiento al ERP |
| **Papel en la solución** | PDP de Policy-Path que bAuth consulta internamente. bhnexus, Kong y otras apps consultan a bAuth — nunca directamente a Tryton-PDP |
| **Propósito** | Resolver "¿qué puede hacer este grupo sobre este recurso de gobierno?" — zonas físicas, límites financieros, delegaciones |
| **Por qué es un pod separado** | Al no cargar módulos de negocio, no compite por CPU, conexiones a base de datos ni disponibilidad con ningún ERP |
| **Aislamiento por tenant** | Una instancia ligera de Tryton-PDP por tenant, siguiendo el mismo patrón que el resto del realm (SBOS-008-001 §5) |

### 3.1 Los 5 niveles de Access Rights, y cómo los usa bAuth

Tryton documenta oficialmente 5 niveles de control de acceso, todos basados en pertenencia a grupo. Si cualquiera de los 5 deniega el acceso, la operación falla — son condiciones independientes, no una jerarquía de permisividad.

| Nivel | Tabla | Qué controla | Cómo lo usa bAuth en Tryton-PDP |
|---|---|---|---|
| **Model** | `ir.model.access` | Permisos de `read`/`write`/`create`/`delete` por modelo × grupo | `rolframework_sync` crea un registro por cada combinación grupo/modelo custom (`bauth.zone`, `bauth.financial_limit`...) reflejando lo que el RolTemplate autoriza |
| **Actions** | `ir.action` (campo `groups`) | Qué menús/ventanas puede ver y lanzar un grupo | Limita qué pantallas de gobierno (asignar zona, definir límite) ve cada rol administrativo |
| **Field** | `ir.model.field.access` | Igual que Model, pero campo por campo | Oculta campos sensibles de un recurso de gobierno (p. ej. el monto exacto de un límite financiero) a grupos sin permiso de lectura |
| **Button** (+ Button Rule) | `ir.model.button` | Qué grupos pueden pulsar un botón; Button Rule exige múltiples clics de usuarios distintos | Implementa el dual-control nativo de aprobaciones financieras (`requires_dual_approval_above`) sin lógica custom — ver `SBOS-BAUTH-KC-TRYTON-CONTROL-MODELS` §4.2 |
| **Record Rule** | `ir.rule` / `ir.rule.group` | Qué filas puede ver/tocar un grupo, vía dominio de búsqueda | Filtra qué zonas o delegaciones ve un administrador según su alcance — el mecanismo detrás de `bos_domains.physical.zones` |

### 3.2 Cómo bAuth actualiza datos en Tryton-PDP — nunca SQL directo

Tryton no expone su base de datos para escritura externa. `trytond` soporta dos protocolos de red — **JSON-RPC** (recomendado) y XML-RPC — y, sobre esa base, dos mecanismos de autenticación con propósitos distintos.

**Mecanismo A — sesión de cliente interactivo (`common.db.login`).** Pensado para clientes humanos (el cliente desktop o web de Tryton). El método `common.db.login(usuario, parámetros)` contra `<base_de_datos>/rpc/` devuelve un ID de usuario y una sesión; las llamadas siguientes autorizan con un header `Authorization` construido en Base64 a partir de `usuario:ID_usuario:sesión`, o vía Basic Auth.

**Mecanismo B — User Application Key (recomendado para bAuth).** Tryton define un mecanismo separado, pensado exactamente para este caso: una aplicación externa con nombre propio que actúa en nombre de un usuario de servicio, autenticada con un token `Bearer` en vez de credenciales de sesión:

1. **Crear la key** — `POST /<base_de_datos>/user/application/` con cuerpo `{"user": "bauth-sync", "application": "bauth"}`. La respuesta entrega la key.
2. **Validación inicial (paso manual, una sola vez)** — Tryton exige que un usuario valide esa key desde las preferencias del cliente Tryton antes de que quede activa. Esto es un paso de aprovisionamiento, no recurrente — debe documentarse como parte del runbook de alta de un nuevo tenant, junto al resto del Realm Lifecycle de SBOS-008-001 §5.1.
3. **Uso** — cada llamada RPC posterior de `rolframework_sync` autoriza con `Authorization: Bearer <key>`.

Ejemplo conceptual de una llamada de `rolframework_sync` creando una regla de zona:
```json
{"method": "model.bauth.zone.create", "params": [[{...}], {}], "id": 1}
Authorization: Bearer <user-application-key>
```

En ambos mecanismos, cada método de modelo expuesto (`create`, `write`, `read`, `search`, `delete`) está decorado en el servidor con la clase `trytond.rpc.RPC`, que controla `check_access` (aplica los 5 niveles de Access Rights incluso a la cuenta de servicio) y `fresh_session` (exige una sesión recién autenticada para operaciones especialmente sensibles).

**Por qué no se toca la base de datos directamente:** escribir filas en PostgreSQL sin pasar por el ORM de Tryton evita por completo el motor de Access Rights, las validaciones `on_change`, los disparadores de workflow y la invalidación de caché interna del Pool de modelos — el mismo tipo de problema de consistencia descrito para Keycloak en la Sección 1.1, pero aquí además compromete la integridad de negocio.

**Por qué el canal debe ir cifrado, sin excepción:** Tryton tiene un antecedente de seguridad documentado — versiones anteriores a la 5.0.1 podían filtrar el token de sesión por una conexión en texto plano al bus de eventos bajo ciertas condiciones, exponiéndolo a captura por un atacante en la red (fijación de sesión, advisory GHSA-32w7-9whp-cjp9). La integración bAuth↔Tryton-PDP debe correr exclusivamente sobre TLS — vale tanto para el Mecanismo A como para el B.

### 3.3 Seguridad de las credenciales de servicio

La User Application Key de `bauth-sync`, igual que el `client_secret` de KC (Sección 1.3), debe vivir en Vault con rotación periódica — el mismo patrón ya establecido en SBOS-008-001 §7.2. Su revocación se hace con `DELETE /<base_de_datos>/user/application/`.

---

## 4. EL BITMASK — INSTRUMENTO QUE bAuth ADMINISTRA

| Atributo | Definición |
|---|---|
| **Objetivo** | Calcular, para un usuario y un recurso dados, el privilegio resultante representable en 64 bits |
| **Alcance** | Capacidades de sesión Fast-Path: sesión, apps críticas, hardware, zonas físicas, capacidades financieras, custom (rediseño v2, 6 grupos) |
| **Papel en la solución** | Instrumento de cálculo independiente, administrado por bAuth — no es propiedad de KC ni de Tryton-PDP. Se alimenta de identidad (KC) y, cuando aplica, de decisiones de gobierno (Tryton-PDP) |
| **Propósito** | Resolver, en sub-nanosegundos, "¿tiene este usuario, ahora mismo, el privilegio de actuar sobre este recurso?" |
| **Capacidades** | Operaciones bitwise (AND/OR/XOR/AND-NOT); empaquetado y distribución vía bhnexus hacia banexus |
| **Método de actualización de datos** | bAuth lo recalcula cuando cambia el RolTemplate del usuario. KC es el punto donde el cálculo se invoca y se embebe en el JWT — eso no lo convierte en propiedad de KC |
| **Quién lo administra** | bAuth |

---

## 5. VISTA CONSOLIDADA

| | Keycloak | Tryton-PDP | BitMask |
|---|---|---|---|
| Tipo | Motor de bAuth | Motor de bAuth | Instrumento que bAuth administra |
| Resuelve | Identidad y sesión | Autorización sobre recursos de gobierno | Cálculo de privilegio Fast-Path |
| Frecuencia | Login/refresh | Por consulta de bAuth | Por request, < 0.5ns |
| Protocolo de actualización | Admin REST API (OIDC Bearer token) | JSON-RPC — User Application Key (Bearer) | Recalculado por bAuth, embebido en JWT |
| Salud/observabilidad | `/health/live`, `/health/ready` (puerto 9000) | Sin endpoint estandarizado — usar `common.db.login` como verificación de disponibilidad | N/A — vive en el JWT |
| Credencial de servicio | `client_secret` (Vault, rotación periódica) | User Application Key (Vault, rotación periódica) | N/A |
| Quién lo consulta | El usuario, al autenticarse | bAuth (nunca actores externos directamente) | bhnexus/banexus, leyendo el claim del JWT |
| Administrado por | bAuth | bAuth | bAuth |

---

## 6. VEREDICTO SOBRE LOS 24 BITS

No, los 24 bits originales no alcanzaban — pero no por falta de espacio, sino porque mezclaban capacidad de sesión con permisos que nunca debieron vivir ahí. Los permisos finos de negocio tienen hogar en el ERP (fuera del alcance de este documento). Los recursos de gobierno (zonas, límites, delegaciones) tienen hogar en Tryton-PDP, administrado por bAuth. Bajo ese alcance correctamente delimitado, los 64 bits del rediseño v2 son suficientes, con margen real de crecimiento.

---

## 7. IMPACTO EN EL PLAN MAESTRO

- **M-22** — crear `SBOS-BAUTH-TRYTON-DEPLOYMENT-SEPARATION`: define qué recursos migran a Tryton-PDP, dónde vive cada credencial de servicio (Vault), y el paso manual de aprovisionamiento de la User Application Key como parte del runbook de alta de tenant.
- **M-23** — decisión: ¿se aprueba Tryton-PDP como pod separado por tenant?
- **M-24 (nuevo)** — definir explícitamente el comportamiento de fallo cerrado de bAuth ante indisponibilidad de KC o Tryton-PDP (Secciones 1.2 y 5).

---

## FUENTES

- Tryton Server Documentation — Access Rights: `docs.tryton.org/projects/server/en/latest/topics/access_rights.html`
- Tryton Server Documentation — Remote Procedure Call: `docs.tryton.org/projects/server/en/latest/topics/rpc.html`
- Tryton Server Documentation — User Application: `docs.tryton.org/projects/server/en/latest/topics/user_application.html`
- Tryton Server API Reference — `trytond.rpc.RPC`: `docs.tryton.org/latest/server/ref/rpc.html`
- GitHub Advisory Database — Session Fixation in Tryton (GHSA-32w7-9whp-cjp9), Tryton < 5.0.1
- Keycloak Admin REST API Reference: `keycloak.org/docs-api/latest/rest-api/index.html`
- Keycloak — Tracking instance status with health checks: `keycloak.org/observability/health`
- Keycloak — Configuring the Management Interface: `keycloak.org/server/management-interface`
- Keycloak — comportamiento de caché ante cambios directos en base de datos: reporte de la comunidad en GitHub, proyecto `keycloak/keycloak`

---

*SKULL · SBOS · SBOS-BAUTH-COMPONENT-ROLES v1.7 · Junio 2026*
