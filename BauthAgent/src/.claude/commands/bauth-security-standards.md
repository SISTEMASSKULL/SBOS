---
name: bauth-security-standards
description: Cuerpo de conocimiento de seguridad obligatorio para BauthAgent. Define los estándares normativos (NIST SP 800-63-4, OWASP ASVS 5.0.0, FIDO2), el mapa completo de 10 vectores de ataque que bAuth debe resistir, los controles de acceso al entorno de desarrollo (Zero Trust, SSH, Vault, RBAC, TLS), los principios de diseño seguro (fail-closed, defense in depth, mínimo privilegio), los criterios de evaluación de seguridad, y la obligación de investigación continua en internet antes de implementar. Activar esta skill SIEMPRE que se trabaje en autenticación, autorización, sesiones, criptografía, BitMask, o acceso al entorno.
---

# CLAUDE_BAUTH_SECURITY_STANDARDS.md — BauthAgent
## Estándares de Seguridad, Vectores de Ataque y Control de Acceso al Entorno
**Versión:** 1.0.0 · **Clasificación:** INTERNO CRÍTICO · **Complementa:** CLAUDE_BAUTH_AGENT.md

---

## PROPÓSITO DE ESTE DOCUMENTO

Este documento es el cuerpo de conocimiento de seguridad obligatorio para BauthAgent. Define los estándares normativos que rigen la implementación de bAuth, el mapa completo de vectores de ataque que el sistema debe resistir, los controles de acceso al entorno de desarrollo, y los criterios de evaluación de seguridad que toda implementación debe satisfacer.

No es documentación de referencia opcional. Es condición de habilitación para trabajar en cualquier componente de bAuth que tenga superficie de ataque o que toque autenticación, autorización, sesiones, criptografía, o acceso al entorno.

---

## PARTE I — ESTÁNDARES NORMATIVOS

### 1.1 Marco normativo principal: NIST SP 800-63 Revisión 4 (Julio 2025)

El estándar de referencia principal para bAuth es **NIST SP 800-63-4**, publicado en julio de 2025. Esta revisión supera a SP 800-63B y representa el estado del arte en directrices de identidad digital. Toda implementación de autenticación en bAuth debe ser conforme a sus requisitos.

Los tres niveles de aseguramiento del autenticador (AAL) definen el rigor requerido:

**AAL1 — Aseguramiento básico:**
Factor único o múltiple. Cualquiera de los nueve tipos de autenticador reconocidos es aceptable. Requiere reautenticación al menos cada 30 días en sesiones extendidas.

**AAL2 — Aseguramiento estándar:**
Requiere autenticación multifactor con al menos un autenticador resistente a phishing. A partir de SP 800-63B-4, la MFA resistente a phishing es el nuevo estándar base para AAL2. Los OTP por correo electrónico han sido explícitamente degradados y los OTP por SMS considerados restringidos por su vulnerabilidad a SIM swapping.

**AAL3 — Aseguramiento máximo:**
Requiere autenticador criptográfico vinculado a hardware. Obligatorio para operaciones de administración crítica, cambios en el motor BitMask con impacto multitenant, y cualquier acción sobre identidades con privilegios elevados.

La elección del AAL requerido para cada operación de bAuth no es discrecional. Debe surgir del análisis de riesgo documentado en los archivos de plandeaccion. Si ese análisis no cubre un caso específico, debe escalarse al humano antes de asumir un nivel.

### 1.2 FIDO2 y Passkeys como nuevo estándar de autenticación resistente a phishing

SP 800-63-4 integra explícitamente FIDO2 Passkeys (tanto vinculadas a dispositivo como sincronizables) en los requisitos de AAL2 y AAL3. FIDO2 es ahora el estándar de oro para autenticación sin contraseña. Las razones son arquitecturales: un secreto vinculado a hardware no puede ser exfiltrado por credential stuffing ni interceptado por phishing, porque el secreto nunca sale del dispositivo.

bAuth debe implementar soporte FIDO2/WebAuthn conforme a la especificación. Los nombres de algoritmos post-cuánticos (PQC) en los documentos del sistema usan la nomenclatura FIPS vigente — úsala exactamente como está documentada.

### 1.3 OWASP ASVS 5.0.0 (Mayo 2025)

El segundo estándar normativo obligatorio es **OWASP Application Security Verification Standard versión 5.0.0**, publicado en mayo de 2025. Esta versión incluye aproximadamente 350 requisitos en 17 capítulos, con cobertura ampliada de OAuth/OIDC, WebRTC, y controles modernos de identidad.

ASVS opera en tres niveles de verificación:

- **Nivel 1:** Mínimo absoluto. Aplicaciones sin datos sensibles. No es el nivel objetivo de bAuth.
- **Nivel 2:** Recomendado para aplicaciones que manejan datos sensibles o transacciones. Es el mínimo objetivo de bAuth.
- **Nivel 3:** Para aplicaciones donde el fallo tiene consecuencias graves. Es el objetivo para las rutas de administración y operaciones sobre el motor BitMask de bAuth.

Los capítulos de ASVS más directamente relevantes para bAuth son:

**V2 — Autenticación:** Políticas de contraseñas, MFA, almacenamiento de credenciales, y binding de sesión. Incluye requisitos sobre listas negras de contraseñas comprometidas, límites de intentos fallidos, y prohibición de rotación periódica forzada sin evidencia de compromiso.

**V3 — Gestión de sesiones:** Generación de tokens de sesión, timeout, invalidación, y protección contra fixation y session hijacking. Toda operación de cierre de sesión debe invalidar el token en el servidor, no solo en el cliente.

**V4 — Control de acceso:** Principio de mínimo privilegio, RBAC, y protección contra escalada de privilegios. La evaluación de acceso debe ocurrir en la capa de servicio de confianza, nunca solo en el cliente.

**V7 — Criptografía:** Algoritmos aprobados, longitudes de clave, gestión del ciclo de vida de secretos. Sin algoritmos deprecados. Sin claves hardcodeadas.

**V8 — Protección de datos:** Clasificación de datos, minimización, y controles sobre PII.

Toda implementación de bAuth que toque alguno de estos capítulos debe verificarse contra los requisitos concretos de ASVS 5.0.0 antes de considerarse completa.

### 1.4 Otros estándares aplicables

Estos estándares son referenciados en los documentos de especificación de bAuth. No los inferas desde este documento — léelos cuando la especificación los cite:

- **ISO/IEC 27001:** Gestión de seguridad de la información. ASVS proporciona los controles técnicos de aplicación que ISO 27001 no especifica.
- **PCI DSS:** El nivel 2 de ASVS cubre una parte sustancial de los requisitos de aplicaciones web de PCI DSS (Requisito 6). Si bAuth procesa contextos de pago, los requisitos de PCI DSS aplican directamente.
- **FIPS 140-2 / FIPS 140-3:** Requisitos de módulos criptográficos. AAL2 y AAL3 los requieren. Verifica qué nivel exige cada componente en los documentos de especificación.
- **RFC 6749 (OAuth 2.0), RFC 7519 (JWT), RFC 8628 (Device Flow), OpenID Connect 1.0:** Protocolos de federación e identidad. Las implementaciones deben ser conformes al estándar, no a interpretaciones libres.

---

## PARTE II — MAPA DE VECTORES DE ATAQUE

Esta sección define los vectores de ataque que bAuth debe resistir. No es exhaustiva de todas las amenazas posibles, pero cubre los vectores de mayor impacto y frecuencia documentados en 2025-2026. Para cada vector se describe el mecanismo, por qué es relevante para bAuth, y el control requerido.

### 2.1 Credential Stuffing

**Mecanismo:** El atacante obtiene pares usuario/contraseña de filtraciones previas (en 2025 hay más de 312 millones de credenciales comprometidas en marketplaces de dark web) y los prueba automáticamente contra el sistema. A diferencia del brute force clásico, credential stuffing intenta cada par una sola vez, lo que hace ineficaces los controles basados únicamente en bloqueo por múltiples intentos fallidos del mismo usuario.

**Relevancia para bAuth:** Es el vector de entrada más frecuente. En 2024-2025 representó el 22% de todos los data breaches, superando al phishing como vector único más común.

**Controles requeridos:**
- Rate limiting por IP y por subred, no solo por usuario. El límite por usuario no detiene credential stuffing porque el atacante nunca supera el umbral en una sola cuenta.
- Detección de patrones de volumen anómalo en intentos de autenticación (20-25% del tráfico de login en sistemas enterprise es credential stuffing).
- Lista negra actualizada de contraseñas comprometidas (Have I Been Pwned dataset o equivalente), verificada en cada cambio de contraseña.
- MFA obligatorio como capa de defensa adicional. Credential stuffing con contraseña válida es inútil si el segundo factor no puede ser comprometido de la misma forma.
- Detección de botnet: análisis de User-Agent, comportamiento de timing, y fingerprint de dispositivo para distinguir humanos de bots.

### 2.2 Brute Force y Password Spraying

**Mecanismo:** Brute force prueba combinaciones de contraseñas contra una cuenta específica. Password spraying prueba una contraseña común (ej. "Enero2024!") contra muchas cuentas para evitar el bloqueo por intentos fallidos.

**Controles requeridos:**
- Bloqueo progresivo de cuenta con cooldown exponencial tras intentos fallidos.
- Alertas en tiempo real al administrador cuando se detecta un patrón de spraying (muchas cuentas, pocos intentos cada una).
- CAPTCHA o desafío adicional tras un número configurable de intentos fallidos.
- Passwords mínimos de 15 caracteres según NIST SP 800-63B-4. No imponer reglas de complejidad que generen patrones predecibles (mayúscula + número + símbolo al final).
- Verificación contra lista de contraseñas comprometidas en registro y cambio.

### 2.3 Phishing y Adversary-in-the-Middle (AiTM)

**Mecanismo:** El atacante crea una página falsa de login (o un proxy transparente) que captura credenciales y, en ataques AiTM modernos (Evilginx, Modlishka), también roba el token de sesión post-autenticación, incluyendo después de que el MFA fue completado. Esto hace que la MFA tradicional (TOTP, SMS) sea bypasseable.

**Relevancia para bAuth:** AiTM es el vector de escalada cuando credential stuffing falla. El atacante que tiene la contraseña pero no puede pasar el MFA usa un proxy que captura la sesión autenticada en tiempo real.

**Controles requeridos:**
- Autenticación resistente a phishing como estándar. FIDO2/WebAuthn es resistente a AiTM porque el secreto está vinculado al origen criptográfico del sitio — un proxy no puede hacer que el autenticador responda a un dominio falso.
- Binding de sesión: los tokens de sesión deben estar vinculados a características del cliente (IP de origen, fingerprint TLS, o device binding) para que un token robado no sea usable desde otro contexto.
- Certificate pinning en clientes que lo soporten.
- Verificación de origen en el servidor para requests de autenticación.

### 2.4 MFA Fatigue (Push Bombing)

**Mecanismo:** El atacante con credenciales válidas genera una ráfaga continua de solicitudes de autenticación que envían notificaciones push al dispositivo del usuario. El ataque explota la tendencia humana a aprobar una solicitud para detener el bombardeo, especialmente en horarios fuera de oficina. En 2025 hubo un aumento del 217% en este vector según el Verizon DBIR.

**Controles requeridos:**
- Limite de solicitudes push por período de tiempo por cuenta.
- Número de matching: el usuario debe ingresar un código que aparece en la pantalla de login antes de aprobar la notificación push. Esto hace imposible aprobar inadvertidamente.
- Alertas automáticas al administrador cuando una cuenta recibe más de N solicitudes de MFA en un período configurable.
- Opción de bloqueo automático de la cuenta tras un umbral de solicitudes push rechazadas o sin respuesta.

### 2.5 Session Hijacking y Token Theft

**Mecanismo:** El atacante roba un token de sesión válido (cookie, JWT, token OAuth) mediante XSS, malware infostealer, sniffing, o AiTM. En 2024, infostealers robaron 17 mil millones de session cookies. Con el token, el atacante puede impersonar al usuario sin necesidad de credenciales.

**Controles requeridos:**
- Tokens de sesión con TTL corto y renovación activa. TTL largo = ventana de explotación larga.
- Invalidación de sesión en el servidor al logout. No es suficiente eliminar la cookie en el cliente.
- Rotación de tokens tras operaciones privilegiadas. Un token válido antes de una escalada de privilegios no debe ser válido después sin revalidación.
- Binding de token a contexto del cliente (IP, User-Agent, device fingerprint). Un token válido en un contexto debe ser inválido en otro.
- Flags HttpOnly y Secure en cookies. HttpOnly previene acceso desde JavaScript (mitiga XSS). Secure previene transmisión en claro.
- SameSite=Strict en cookies para mitigar CSRF.
- Monitoreo de anomalías en uso de tokens: misma sesión desde múltiples IPs, cambios súbitos de User-Agent, o acceso desde geolocalización imposible.

### 2.6 Privilege Escalation

**Mecanismo:** El atacante con acceso legítimo de bajo privilegio encuentra un mecanismo para elevar sus permisos, sea por fallo en la evaluación de acceso, race conditions en el motor de autorización, o manipulación de parámetros.

**Relevancia para bAuth:** El motor BitMask de bAuth es el componente más crítico para este vector. Un fallo en la evaluación de los bits puede otorgar permisos que no deberían estar activos.

**Controles requeridos:**
- Evaluación de acceso en la capa de servicio de confianza, nunca en el cliente. El cliente no puede ser fuente de verdad de los permisos.
- Principio de mínimo privilegio en el diseño de átomos y roles. Los átomos se asignan a lo mínimo necesario.
- Verificación de la evaluación BitMask contra el DDL canónico. Ningún cambio en la lógica de evaluación sin verificación exhaustiva.
- Logs de auditoría de todos los cambios de asignación de roles. Deben ser inmutables (append-only con RLS en PostgreSQL, como está definido en la especificación).
- Re-autenticación requerida antes de operaciones que eleven privilegios significativamente (step-up authentication).
- Doble aprobación para operaciones en dominios de alto riesgo según la especificación.

### 2.7 Credential Dumping y Memory Extraction

**Mecanismo:** Un atacante con acceso al sistema intenta extraer credenciales de la memoria del proceso (LSASS en Windows, equivalentes en Linux), de la base de datos de identidades, o de archivos de configuración. Técnicas documentadas en MITRE ATT&CK TA0006 incluyen T1003 (credential dumping), T1552 (unsecured credentials), y T1555 (credentials from password stores).

**Controles requeridos:**
- Secretos y credenciales gestionados exclusivamente a través de Vault. Nunca en variables de entorno sin cifrar, archivos de configuración en texto plano, o código fuente.
- Contraseñas almacenadas siempre como hash con algoritmos modernos (Argon2id recomendado por OWASP, bcrypt con work factor mínimo 12 como alternativa). Nunca MD5, SHA-1, o SHA-256 sin salt para contraseñas.
- Secretos de servicio rotados automáticamente según el ciclo definido en la especificación.
- Principio de mínimo privilegio en el acceso a la base de datos. El daemon de bAuth no tiene permisos de superusuario en PostgreSQL.
- Secretos nunca en logs. Cualquier operación de logging debe redactar automáticamente valores que correspondan a credenciales, tokens, o claves.

### 2.8 Replay Attacks

**Mecanismo:** El atacante captura una respuesta de autenticación válida (challenge-response, token, OTP) y la reutiliza para autenticarse sin conocer el secreto original.

**Controles requeridos:**
- Nonces de un solo uso en flujos de challenge-response.
- Timestamps verificados en tokens: los tokens emitidos tienen una ventana de validez estricta y son rechazados fuera de ella.
- OTPs con ventana temporal mínima (TOTP con ventana de ±1 intervalo de 30 segundos, no más).
- JTI (JWT ID) único por token con registro de tokens ya usados durante su período de validez.

### 2.9 Harvest Now, Decrypt Later (HNDL) — Amenaza Post-Cuántica

**Mecanismo:** Un adversario con capacidades avanzadas captura tráfico cifrado hoy y lo almacena para descifrarlo cuando tenga acceso a un computador cuántico suficientemente potente. Los datos capturados hoy que sigan siendo sensibles en 10-15 años están en riesgo.

**Relevancia para bAuth:** Los tokens de larga duración, los materiales de clave de identidad, y las credenciales de larga vida son los objetivos. Este vector justifica la adopción de criptografía post-cuántica (PQC) en la especificación de bAuth.

**Controles requeridos:**
- Uso exclusivo de los algoritmos PQC documentados con nomenclatura FIPS vigente en la especificación. No usar variantes no documentadas ni nombres de versiones anteriores.
- Perfect Forward Secrecy (PFS) en todos los canales TLS. PFS limita la exposición retrospectiva porque cada sesión usa claves efímeras.
- TTL corto en tokens de alta sensibilidad. Un token que expira en 1 hora limita la ventana de explotación futura.

### 2.10 Supply Chain Attacks y Dependencias

**Mecanismo:** Un atacante compromete una dependencia (librería, paquete, imagen de contenedor) que bAuth usa. En 2025 los ataques de supply chain crecieron un 156% año sobre año.

**Controles requeridos:**
- Todas las dependencias con versiones fijadas (pinned) en el manifiesto. No usar rangos de versiones que permitan actualizaciones automáticas no verificadas.
- Verificación de integridad (hash) de dependencias en el proceso de build.
- Análisis de dependencias en el pipeline de CI para detectar vulnerabilidades conocidas (CVEs).
- Mínimo de dependencias externas en componentes del path crítico de autenticación.

---

## PARTE III — CONTROL DE ACCESO AL ENTORNO

Esta sección es específica a la seguridad del entorno de desarrollo y operación de bAuth en la VPS. Un sistema de autenticación robusto desplegado en un entorno inseguro es inútil. La seguridad del entorno es tan crítica como la seguridad del código.

### 3.1 Principio Zero Trust aplicado al entorno

El entorno de bAuth opera bajo el principio Zero Trust: ningún acceso es confiable por defecto, independientemente del origen. Esto significa:

- **Nunca trust implícita por red:** Estar en la misma red que el servicio no otorga acceso. Cada llamada interna entre servicios se autentica.
- **Verificación continua:** La identidad de un servicio o usuario se verifica en cada operación, no solo al inicio de la sesión.
- **Mínimo privilegio por diseño:** Ningún componente tiene más acceso del estrictamente necesario para su función. Esto aplica a cuentas de servicio, cuentas de base de datos, y cuentas de administración.
- **Microsegmentación:** Los servicios internos están aislados entre sí. Un compromiso en un componente no debe dar acceso lateral automático a los demás.

### 3.2 Acceso SSH al entorno

El acceso SSH a la VPS es la superficie de ataque más directa del entorno. Los controles son obligatorios:

- **Autenticación por clave únicamente.** Autenticación por contraseña deshabilitada en el servidor SSH. Sin excepciones.
- **Puerto SSH no estándar.** El puerto 22 es escaneado continuamente por bots. Cambiar al puerto configurado en el sistema reduce el ruido de ataques automatizados.
- **Fail2ban o equivalente activo.** Bloqueo automático de IPs con intentos fallidos repetidos.
- **AllowUsers restringido.** Solo los usuarios explícitamente listados pueden conectarse vía SSH. Sin acceso root directo — solo escalada mediante sudo con logging.
- **Logs de acceso SSH monitoreados.** Toda conexión SSH exitosa y fallida debe aparecer en el registro de auditoría del sistema. Anomalías (horario inusual, IP desconocida) generan alerta.
- **Claves SSH con passphrase.** Las claves privadas de acceso al entorno deben estar protegidas con passphrase. Una clave sin passphrase robada es acceso inmediato al entorno.

### 3.3 Gestión de secretos del entorno con Vault

Todos los secretos del entorno — credenciales de base de datos, claves de API, certificados, claves de cifrado — deben estar en Vault. Esta no es una recomendación: es un requisito arquitectural documentado en la especificación de bAuth.

Controles específicos:
- **Sin secretos en variables de entorno en texto plano.** Las variables de entorno son visibles en logs de proceso, en archivos de configuración del sistema de init, y a cualquier proceso con el mismo UID.
- **Sin secretos en el repositorio git.** Bajo ninguna circunstancia. Si un secreto llega a git, debe considerarse comprometido y rotado inmediatamente.
- **Rotación automática de secretos de corta vida.** Vault puede emitir credenciales dinámicas con TTL corto. Usarlas para acceso a base de datos y servicios internos.
- **Acceso a Vault con mínimo privilegio.** El daemon de bAuth solo tiene acceso a los paths de Vault que necesita. No tiene acceso al árbol completo de secretos.
- **Auditoría de acceso a Vault.** Todo acceso a un secreto en Vault genera un log. Revisar regularmente quién accedió a qué.

### 3.4 Gestión de privilegios en el entorno

**Cuentas de servicio:**
Cada componente (daemon bAuth, PostgreSQL, Redis, Keycloak) corre con su propia cuenta de sistema con permisos mínimos. Ningún servicio corre como root. La cuenta del daemon de bAuth no tiene acceso de escritura fuera de sus directorios de trabajo definidos.

**Acceso a base de datos:**
El daemon de bAuth se conecta a PostgreSQL con un usuario de base de datos que tiene únicamente los permisos necesarios para sus operaciones. No tiene permisos de CREATE, DROP, o ALTER sobre el esquema. Las migraciones DDL se ejecutan con una cuenta separada de mayor privilegio, solo cuando se despliega una migración explícita.

**Acceso a Redis:**
Redis no expuesto fuera del loopback. Si Redis tiene datos sensibles de sesión, debe estar configurado con autenticación (`requirepass`) y acceso restringido por red.

**Kubernetes / Contenedores:**
- Ningún contenedor con `privileged: true` sin justificación explícita y revisada.
- Security contexts con `runAsNonRoot: true` y `readOnlyRootFilesystem: true` donde sea posible.
- Network Policies que restrinjan el tráfico entre pods al mínimo necesario.
- RBAC de Kubernetes con roles de mínimo privilegio para las cuentas de servicio de los pods.

### 3.5 Monitoreo y detección en el entorno

Un entorno no monitoreado no es un entorno seguro. El tiempo mediano para identificar un breach en 2025 fue de 204 días. Sin monitoreo activo, los ataques operan sin ser detectados por meses.

**Logs que deben existir y estar centralizados:**
- Logs de autenticación de todos los servicios (intentos exitosos y fallidos).
- Logs de acceso a Vault.
- Logs SSH de acceso al sistema.
- Logs de operaciones en PostgreSQL relevantes (conexiones, queries sobre tablas de identidad).
- Logs de Kubernetes: creación y eliminación de pods, cambios en RBAC.

**Alertas que deben estar configuradas:**
- Múltiples intentos de autenticación fallidos en un período corto (brute force / spraying).
- Acceso desde una IP no vista previamente en el entorno.
- Acceso en horario inusual (madrugada en la zona horaria del operador).
- Uso de credenciales de Vault por un servicio en un volumen inusualmente alto.
- Cambios en la configuración de RBAC de Kubernetes.
- Reinicio inesperado de un servicio crítico (daemon bAuth, Keycloak, PostgreSQL).

**Retención de logs:**
Los logs de auditoría de eventos de seguridad deben retenerse el tiempo definido en la política de compliance aplicable. No eliminar logs antes de que expire ese período.

### 3.6 Gestión de certificados TLS

- Todos los endpoints de bAuth expuestos (incluso internos) deben estar bajo TLS. Sin HTTP plano en ninguna ruta del sistema.
- Certificados con rotación automática antes de expiración. Un certificado expirado es una interrupción de servicio que puede convertirse en un incidente de seguridad.
- Configuración TLS con solo versiones modernas habilitadas: TLS 1.3 como estándar, TLS 1.2 como mínimo aceptable. Sin SSLv3, TLS 1.0, TLS 1.1.
- Cipher suites modernas con Perfect Forward Secrecy. Sin RC4, DES, 3DES, o export ciphers.

### 3.7 Actualizaciones y gestión de vulnerabilidades

- Sistema operativo de la VPS con parches de seguridad aplicados regularmente. Las vulnerabilidades del kernel y del sistema base son vectores de escalada de privilegios.
- Imágenes de contenedor actualizadas cuando aparecen CVEs críticos en sus dependencias. No usar imágenes con base obsoleta.
- Seguimiento de CVEs en las dependencias de bAuth (Rust crates, Go modules). Los CVEs de alta severidad en el path crítico de autenticación requieren actualización urgente.

---

## PARTE IV — PRINCIPIOS DE DISEÑO SEGURO

### 4.1 Fail-Closed como invariante de seguridad

Un sistema de autenticación que falla de forma abierta (permitiendo el acceso cuando hay un error) es tan peligroso como uno sin autenticación. En bAuth, el comportamiento ante cualquier fallo — error de base de datos, timeout, excepción no manejada, resultado ambiguo — es siempre denegar el acceso.

No existe justificación para fail-open en ninguna ruta de autenticación o evaluación de acceso. Si el sistema no puede determinar con certeza que el acceso está autorizado, deniega.

### 4.2 Defense in Depth

Ningún control de seguridad único es suficiente. bAuth implementa múltiples capas:

- Capa 1: Autenticación fuerte (MFA resistente a phishing).
- Capa 2: Evaluación de autorización (motor BitMask).
- Capa 3: Binding de sesión y tokens de corta vida.
- Capa 4: Rate limiting y detección de anomalías.
- Capa 5: Auditoría forense inmutable.
- Capa 6: Controles del entorno (acceso SSH restringido, Vault, RBAC).

Un atacante que supera una capa debe encontrar resistencia en la siguiente. La seguridad por capas significa que el compromiso de un control no es el compromiso del sistema.

### 4.3 Mínimo Privilegio como diseño, no como política

El principio de mínimo privilegio no es solo una política de administración — es un principio de diseño. Al diseñar un átomo, un rol, una cuenta de servicio, o una integración, la pregunta es: ¿cuál es el mínimo de privilegio que permite esta función? Eso es lo que se asigna. No lo que es conveniente. No lo que podría necesitarse en el futuro.

Los privilegios no usados son superficie de ataque. Los privilegios innecesarios son vectores de escalada esperando ser explotados.

### 4.4 Trazabilidad forense como requisito de diseño, no de auditoría

Un sistema de autenticación que no puede responder "¿quién hizo qué, cuándo, y desde dónde?" no puede usarse para forensia de incidentes. La trazabilidad no es una funcionalidad que se agrega al final — es una dimensión que debe estar presente en el diseño de cada operación.

Todo evento de seguridad (autenticación, evaluación de acceso, cambio de privilegios, emisión de credencial) debe generar un registro forense que contenga: identidad del sujeto, recurso afectado, timestamp con microsegundos, resultado, contexto de sesión, y origen de la solicitud.

El registro de auditoría es append-only por diseño y protegido por Row Security Policy en PostgreSQL. Esta restricción no es eludible ni negociable.

### 4.5 Separación de responsabilidades en componentes críticos

Las operaciones más sensibles del sistema deben requerir la participación de más de un componente o actor para ejecutarse. Esto limita el daño que puede causar un componente comprometido.

Ejemplos concretos documentados en la especificación: doble aprobación para cambios en dominios de alto riesgo, separación entre el componente que evalúa el acceso y el que registra la evaluación, separación entre el daemon y la TUI (el daemon nunca importa la TUI).

---

## PARTE V — EVALUACIÓN DE SEGURIDAD DE IMPLEMENTACIONES

Antes de declarar completada cualquier implementación de bAuth, debe pasar por esta evaluación de seguridad. Estos criterios se aplican además de los criterios de calidad generales del documento principal.

### 5.1 Evaluación de superficie de ataque

- ¿Qué vectores de la Parte II aplican a esta implementación?
- ¿Cada vector identificado tiene al menos un control implementado?
- ¿Hay algún vector que aplica y que no tiene control? Si es así, es un hallazgo de seguridad que debe escalarse antes de desplegar.

### 5.2 Evaluación de conformidad con estándares

- ¿La implementación es conforme al nivel ASVS correspondiente (L2 para flujos estándar, L3 para administración)?
- ¿Los AAL asignados a cada operación son correctos según la especificación?
- ¿Los algoritmos criptográficos usados son los documentados en la especificación con nomenclatura FIPS correcta?

### 5.3 Evaluación de controles del entorno

- ¿La implementación requiere nuevos secretos? ¿Están en Vault?
- ¿La implementación requiere nuevos permisos para cuentas de servicio? ¿Son los mínimos necesarios?
- ¿La implementación genera nuevos logs de auditoría? ¿Son forenses y van al sistema centralizado?
- ¿Hay nuevas alertas que deben configurarse para detectar comportamiento anómalo en esta funcionalidad?

### 5.4 Evaluación de comportamiento de fallo

- ¿Cómo falla esta implementación ante: error de base de datos, timeout, resultado ambiguo, input malformado?
- En todos esos casos, ¿el sistema falla de forma cerrada (deniega el acceso)?
- ¿Los errores retornados al cliente son informativamente seguros (no revelan detalles internos)?

---

## PARTE VI — OBLIGACIÓN DE INVESTIGACIÓN CONTINUA EN INTERNET

### 6.1 Por qué la investigación continua es un requisito de seguridad, no una mejora opcional

Los estándares de seguridad no son documentos estáticos. El paisaje de amenazas evoluciona continuamente: aparecen nuevos vectores de ataque, se deprecan algoritmos antes seguros, se publican CVEs críticos en componentes del stack, organismos normativos actualizan sus requisitos, y emerge nueva jurisprudencia regulatoria. Un agente que trabaja exclusivamente desde su conocimiento de entrenamiento construye sobre una base que envejece con cada sesión.

En sistemas de autenticación esto es especialmente grave. La diferencia entre un algoritmo criptográfico activo y uno deprecado puede ser la diferencia entre un sistema conforme a estándar y uno explotable. Una versión de una librería de autenticación con un CVE crítico publicado hace tres semanas que el agente no conoce es una vulnerabilidad activa que el agente introducirá sin saberlo.

**La investigación en internet antes de implementar cualquier componente de seguridad no es una cortesía — es un control de seguridad.**

### 6.2 Cuándo buscar en internet — obligaciones no negociables

El agente **debe** buscar en internet en los siguientes casos, sin excepción:

**Antes de usar cualquier librería o crate de criptografía o autenticación:**
Verificar la versión más reciente, el estado de mantenimiento activo, y si existen CVEs publicados contra versiones recientes. Una librería criptográfica con un CVE crítico no parchado no se usa, independientemente de que esté en los documentos de especificación — en ese caso se escala al humano.

Fuentes canónicas a consultar:
- `https://crates.io` / `https://advisories.rs` para crates de Rust
- `https://pkg.go.dev` / `https://pkg.go.dev/vuln/` para módulos Go
- `https://nvd.nist.gov` para CVEs por componente

**Antes de implementar o modificar cualquier flujo criptográfico:**
Verificar que el algoritmo sigue siendo recomendado por NIST y no ha sido deprecado o atacado desde el conocimiento de entrenamiento. Los algoritmos criptográficos tienen vida útil y pueden ser atacados en el intervalo entre una sesión y la siguiente.

Fuentes canónicas:
- `https://csrc.nist.gov` — publicaciones de NIST, incluyendo FIPS y SP 800-*
- `https://nvlpubs.nist.gov` — PDFs de publicaciones vigentes
- `https://csrc.nist.gov/projects/post-quantum-cryptography` — estado actual de PQC

**Antes de implementar cualquier flujo de autenticación federada (OAuth, OIDC, SAML):**
Verificar la versión vigente de la especificación, los security advisories del proveedor (Keycloak, en el caso de bAuth), y si existen vulnerabilidades activas conocidas en el flujo específico a implementar.

Fuentes canónicas:
- `https://openid.net/specs/` — especificaciones OIDC vigentes
- `https://oauth.net/2/` — especificaciones OAuth 2.0 y extensiones
- `https://www.keycloak.org/security.html` — security advisories de Keycloak

**Al inicio de cualquier sesión que toque el motor BitMask o los 12 dominios de control:**
Verificar si hay actualizaciones en los estándares de autorización (XACML, OPA, Casbin) que sean relevantes para el diseño del motor, o si han aparecido patrones de ataque contra motores de autorización basados en bitmask.

**Al inicio de cualquier sesión de trabajo, como parte del protocolo de arranque:**
Buscar si hay nuevos advisories de seguridad publicados en las últimas semanas para los componentes centrales del stack: Keycloak, PostgreSQL, Redis, Vault, Kong, y el sistema operativo base. Si hay CVEs críticos no atendidos, reportarlos al humano antes de continuar con cualquier otra tarea.

**Antes de declarar conforme a estándar cualquier implementación:**
Verificar la versión actual de OWASP ASVS, NIST SP 800-63B, y cualquier otro estándar citado en la especificación para confirmar que no ha habido una revisión mayor desde el conocimiento de entrenamiento. Las versiones en los documentos de especificación son las vigentes al momento de redacción — pueden haber sido superadas.

Fuentes canónicas:
- `https://owasp.org/www-project-application-security-verification-standard/` — ASVS versión actual
- `https://pages.nist.gov/800-63-4/` — SP 800-63 Revisión 4 y actualizaciones
- `https://cheatsheetseries.owasp.org` — OWASP Cheat Sheet Series (referencia táctica)

### 6.3 Cómo investigar — protocolo de búsqueda rigurosa

La investigación en internet no es una búsqueda casual. Es una actividad con protocolo definido:

**1. Identificar qué se necesita saber antes de buscar.**
Antes de lanzar una búsqueda, formular con precisión la pregunta: ¿Qué versión de este componente es la más reciente y está activamente mantenida? ¿Existen CVEs publicados contra las versiones X.Y.Z o anteriores de esta librería? ¿El algoritmo A sigue siendo recomendado por NIST en su publicación más reciente? Preguntas vagas producen resultados irrelevantes.

**2. Ir a fuentes primarias, no a blogs ni foros.**
Para estándares: el sitio oficial del organismo (NIST, OWASP, IETF, ISO). Para vulnerabilidades: NVD o el advisory del mantenedor del componente. Para especificaciones de protocolo: el RFC o la especificación oficial. Los blogs de seguridad y los foros son útiles para contexto pero no son fuentes normativas.

**3. Verificar la fecha de publicación.**
Un artículo de 2022 sobre mejores prácticas de autenticación puede ser obsoleto en aspectos críticos. Los estándares evolucionan. Siempre verificar si existe una versión más reciente del documento consultado.

**4. Contrastar con la especificación del sistema.**
Si la investigación revela que un estándar ha cambiado de manera que contradice algo en los documentos de especificación de bAuth, no implementar silenciosamente la versión actualizada. Reportar la discrepancia al humano con precisión: el documento de especificación dice X, el estándar actual en su versión Y dice Z, en el contexto de la tarea T. El humano decide.

**5. Documentar lo encontrado antes de actuar.**
Si la búsqueda revela algo relevante — un CVE, una deprecación, una actualización normativa — registrarlo como hallazgo antes de continuar. Si el hallazgo genera trabajo nuevo (por ejemplo, actualizar una dependencia vulnerable), registrar esa tarea en `REGISTRO-ESTADO.md` antes de ejecutarla.

### 6.4 Fuentes canónicas de referencia continua

Estas son las fuentes primarias que el agente debe consultar de forma recurrente. No son exhaustivas — cualquier fuente oficial relevante puede y debe ser consultada — pero estas son el punto de partida obligatorio para los dominios que cubren:

**Estándares de identidad y autenticación:**
- NIST SP 800-63-4 y sub-volúmenes: `https://pages.nist.gov/800-63-4/`
- NIST CSRC (todas las publicaciones): `https://csrc.nist.gov/publications`
- OWASP ASVS: `https://owasp.org/www-project-application-security-verification-standard/`
- OWASP Cheat Sheets: `https://cheatsheetseries.owasp.org`
- OWASP Top 10: `https://owasp.org/www-project-top-ten/`

**Estándares de protocolo de autenticación y autorización:**
- OAuth 2.0 y extensiones: `https://oauth.net/2/`
- OpenID Connect: `https://openid.net/specs/`
- WebAuthn / FIDO2: `https://www.w3.org/TR/webauthn/` y `https://fidoalliance.org/specs/`
- IETF RFCs: `https://datatracker.ietf.org` (buscar por número de RFC o por tecnología)

**Criptografía post-cuántica y algoritmos:**
- Proyecto PQC de NIST: `https://csrc.nist.gov/projects/post-quantum-cryptography`
- FIPS vigentes: `https://csrc.nist.gov/publications/fips`

**Vulnerabilidades y CVEs:**
- NVD (National Vulnerability Database): `https://nvd.nist.gov/vuln/search`
- MITRE ATT&CK (tácticas y técnicas de ataque): `https://attack.mitre.org`
- MITRE CVE: `https://cve.mitre.org`
- OSV (Open Source Vulnerabilities): `https://osv.dev` — especialmente útil para Rust y Go
- RustSec Advisory Database: `https://rustsec.org/advisories/`

**Advisories de componentes del stack de bAuth:**
- Keycloak security: `https://www.keycloak.org/security.html`
- PostgreSQL security: `https://www.postgresql.org/support/security/`
- HashiCorp Vault: `https://discuss.hashicorp.com/c/vault/announcements/`
- Redis: `https://redis.io/docs/latest/operate/rs/release-notes/`

**Inteligencia de amenazas y tendencias:**
- Verizon DBIR (anual): `https://www.verizon.com/business/resources/reports/dbir/`
- CISA advisories: `https://www.cisa.gov/known-exploited-vulnerabilities-catalog`
- MITRE D3FEND: `https://d3fend.mitre.org` — controles defensivos mapeados a técnicas de ataque

### 6.5 Alineación continua con el estándar — no solo al inicio

Conocer los estándares al momento de diseñar una funcionalidad no es suficiente. Los estándares evolucionan. Una implementación que era conforme al momento de su creación puede dejar de serlo si el estándar se actualiza con nuevos requisitos.

bAuth debe mantenerse alineado con los estándares de forma continua. Esto significa:

**Al revisar código existente:** Verificar si los estándares que lo rigen han sido actualizados y si esas actualizaciones introducen nuevos requisitos o deprecan controles existentes.

**Cuando el humano reporta un incidente o un comportamiento inesperado:** Buscar activamente si existe un vector de ataque documentado que explique el comportamiento antes de asumir que es un bug de implementación. La mitad de las veces, un comportamiento "raro" en autenticación es una técnica de ataque conocida.

**Cuando aparece una nueva versión de un componente del stack:** Leer las release notes con atención forense antes de recomendar actualizar. Las actualizaciones de componentes de seguridad a veces incluyen breaking changes en comportamiento de seguridad que deben propagarse al código de bAuth.

**Cuando el humano solicita evaluar la adopción de una nueva tecnología:** Investigar su estado de estandarización, si ha pasado auditoría de seguridad independiente, y si algún organismo normativo la ha posicionado como recomendada, experimental, o explícitamente no recomendada.

### 6.6 Lo que el agente nunca hace respecto a estándares

- **No asume que su conocimiento de entrenamiento sobre un estándar es la versión vigente.** Los estándares se actualizan. La versión que el agente conoce puede haber sido superada.
- **No implementa basándose en un resumen de terceros cuando puede consultar la fuente primaria.** Los resúmenes simplifican y a veces omiten requisitos críticos.
- **No declara conformidad con un estándar sin haberlo verificado contra la versión actual de ese estándar.** Declarar conformidad con ASVS 4.0 cuando existe ASVS 5.0.0 es una declaración técnicamente falsa.
- **No omite reportar una discrepancia entre el estándar actual y la especificación del sistema.** Si el estándar cambió y la especificación no refleja ese cambio, eso es una brecha de conformidad que el humano debe evaluar.
- **No trata la investigación como un paso opcional que se omite cuando hay presión de tiempo.** En seguridad, la presión de tiempo es el argumento más frecuente para saltarse controles críticos — y la causa más frecuente de vulnerabilidades introducidas con buena intención.

---

*BauthAgent Security Standards v1.0.0 — SKULL / SBOS · INTERNO CRÍTICO*
*Complementa CLAUDE_BAUTH_AGENT.md — Debe leerse junto con él, no en lugar de él.*
*Un sistema de autenticación es tan seguro como el conocimiento de quien lo construye sobre cómo puede ser atacado.*
*El conocimiento de entrenamiento tiene fecha de vencimiento. Los estándares no esperan. Busca antes de implementar.*
