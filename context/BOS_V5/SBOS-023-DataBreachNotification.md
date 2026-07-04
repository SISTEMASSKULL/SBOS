# SBOS-023-EXT — Procedimiento de Notificación de Brechas de Datos Personales
## Extensión de SBOS-023 — Seguridad Zero Trust End-to-End

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-023-EXT-BREACH
**Versión:** 1.0
**Estado:** ACTIVO
**Extiende:** SBOS-023-Security-v1_0
**Clasificación:** Especificación Operacional — Cumplimiento Normativo

---

## Índice

1. [Marco regulatorio iberoamericano y europeo](#1-marco-regulatorio)
2. [Roles de responsabilidad: SKULL como procesador, cliente como controlador](#2-roles-de-responsabilidad)
3. [Datos personales en SBOS por bounded context](#3-datos-personales-por-bounded-context)
4. [Proceso de respuesta a brecha con tiempos SBOS-específicos](#4-proceso-de-respuesta)
5. [Templates de notificación](#5-templates-de-notificacion)
6. [Rotación de claves JWT y revocación de sesiones](#6-rotacion-de-claves-jwt)
7. [Registro de incidentes de datos personales](#7-registro-de-incidentes)

---

## 1. Marco Regulatorio

### 1.1 Tabla comparativa de jurisdicciones

El stack SBOS puede ser instalado por clientes en múltiples jurisdicciones. La normativa aplicable es la del país donde opera el **cliente** (controlador de datos), no la de SKULL Systems.

| Jurisdicción | Norma | Autoridad | Plazo notificación autoridad | Plazo notificación afectados | Umbral de notificación |
|---|---|---|---|---|---|
| **Bolivia** | Ley 164 Art. 29 + DS 1793 | ATIC (Agencia de Tecnologías de Información y Comunicación) | 72 horas desde conocimiento | Sin plazo legal fijo — sin demora indebida | Cuando hay riesgo para los derechos del titular |
| **Argentina** | Ley 25326 + Resoluciones AAIP | AAIP (Agencia de Acceso a la Información Pública) | 72 horas desde conocimiento | Sin plazo legal fijo — tan pronto como sea razonablemente posible | Incidentes que puedan ocasionar daño a los titulares |
| **México** | LFPDPPP + Lineamientos INAI 2021 | INAI (Instituto Nacional de Transparencia) | 72 horas para notificar al titular; sin plazo de notificación a autoridad salvo requerimiento | Tan pronto como sea posible — 72h es práctica recomendada | Cuando el incidente pueda afectar significativamente los derechos patrimoniales o morales |
| **España / UE** | RGPD Art. 33–34 + LOPDGDD | AEPD (Agencia Española de Protección de Datos) | 72 horas desde tener conocimiento (Art. 33) | Sin demora indebida si hay alto riesgo para derechos (Art. 34) | Cualquier violación de seguridad con riesgo para personas físicas |
| **Colombia** | Ley 1581/2012 + Decreto 1377/2013 | SIC (Superintendencia de Industria y Comercio) | 15 días hábiles desde conocimiento | Inmediata a los titulares afectados | Incidentes que afecten a más de 100 titulares o que impliquen datos sensibles |

### 1.2 Definición de "brecha de datos personales" en el contexto de SBOS

Una brecha de datos personales en SBOS es cualquier incidente de seguridad que resulte en la **destrucción, pérdida, alteración, divulgación no autorizada o acceso no autorizado** a datos personales tratados por el sistema.

Ejemplos concretos en SBOS:

- Acceso no autorizado a `orangehrm_db` (datos de empleados: nombre, salario, domicilio, datos de salud)
- Exfiltración de datos de clientes desde `saleor_db` (nombre, dirección de entrega, historial de compras)
- Compromiso de las claves de firma de Keycloak (permite suplantar identidad de usuarios)
- Acceso no autorizado al realm de Keycloak (exposición de usuarios, roles y atributos)
- Pérdida de datos en restore de PostgreSQL sin backup (destrucción de datos personales)

### 1.3 Datos que NO constituyen brecha notificable

- Fallo operacional sin exposición de datos (bKernel detenido, Kong inaccesible)
- Acceso de un usuario legítimo a datos fuera de su horario habitual (detectado por SPI-4 como anomalía, pero sin compromiso)
- Error de configuración sin materialización de acceso no autorizado

---

## 2. Roles de Responsabilidad

### 2.1 SKULL Systems como procesador de datos

SKULL Systems **desarrolla y distribuye** el software SBOS. En la mayoría de las instalaciones, SKULL **no accede** a los datos personales del cliente final. El rol de SKULL es el de **encargado del tratamiento (procesador)** conforme al RGPD y normativas equivalentes iberoamericanas.

**Obligaciones de SKULL como procesador:**

| Obligación | Implementación en SBOS |
|---|---|
| Notificar al cliente toda brecha detectada en sus sistemas | Canal de notificación: correo electrónico de emergencia + ticket en GitLab en < 24 horas |
| No subcontratar procesamiento sin autorización del cliente | Release Plane de SKULL no almacena datos del cliente — solo distribuye binarios firmados |
| Implementar medidas técnicas de seguridad adecuadas | SBOS-023: Zero Trust, mTLS, Vault, cifrado en reposo, Wazuh |
| Cooperar con el cliente en las investigaciones de brechas | SKULL provee logs de acceso al Release Server y evidencia de integridad (firmas Ed25519) si el canal de distribución es sospechado |
| Apoyar al cliente en el ejercicio de derechos de los titulares | El IAM Installer tiene endpoint para exportar datos de un tenant (cumplimiento ARCO) |

### 2.2 El cliente como controlador de datos

El **cliente que instala SBOS** es el **controlador (responsable del tratamiento)**. Es quien decide qué datos personales se procesan, con qué finalidad y por cuánto tiempo.

**Responsabilidades exclusivas del cliente controlador:**

- Decidir si el incidente requiere notificación a la autoridad reguladora
- Realizar la notificación a la autoridad dentro del plazo legal
- Notificar a los titulares afectados si corresponde
- Mantener el registro de actividades de tratamiento (RAT)
- Responder a las solicitudes de derechos ARCO/ARCOPOL de los titulares

### 2.3 Interfaz de comunicación procesador → controlador

SKULL solo activa la notificación al cliente cuando el incidente involucra la **infraestructura de distribución de SKULL** (Release Server, canal de actualización). Para incidentes en la instalación del cliente, el cliente es el primer respondedor.

---

## 3. Datos Personales por Bounded Context

### 3.1 Inventario de datos personales en SBOS

| Bounded Context | Aplicación | Categoría de datos personales | Datos sensibles (categoría especial) | Base de datos |
|---|---|---|---|---|
| BC-02 — RRHH | OrangeHRM | Nombre, DNI, dirección, fecha nacimiento, salario, historial laboral, evaluaciones | Datos de salud (bajas médicas), datos sindicales | `orangehrm_db` |
| BC-03 — Ventas/CRM | EspoCRM, Saleor | Nombre cliente, email, teléfono, dirección entrega, historial de compras | Ninguno por defecto | `espocrm_db`, `saleor_db` |
| BC-04 — Identidad | Keycloak | Nombre usuario, email, IP de acceso, historial de sesiones, roles | Datos de autenticación (credenciales hasheadas) | `keycloak_db` |
| BC-05 — Salud (opcional) | GNU Health | Nombre paciente, historial clínico, diagnósticos, tratamientos | **Todos los datos son categoría especial** | `health_db` |
| BC-01 — Finanzas | Tryton | Nombre proveedor/cliente, CUIT/NIT/RFC, datos bancarios | Ninguno por defecto | `tryton_db` |

### 3.2 Flujo de datos personales en el bus WAL

El bKernel propaga eventos que pueden contener referencias a datos personales entre bounded contexts. Aunque el WAL propaga solo identificadores (IDs), los logs del bKernel no deben contener datos personales en texto plano.

**Regla de privacidad en el bKernel:** Las reglas YAML del bKernel (`/etc/bos/blibs/bkernel/rules/`) no deben incluir datos personales en los campos de condición o acción. Los IDs de entidad son aceptables.

---

## 4. Proceso de Respuesta a Brecha

### 4.1 Diagrama de tiempos para SBOS

```
DETECCIÓN
──────────────────────────────────────────────────────────────────
T+0    Wazuh dispara alerta de brecha potencial
       → canal #security-alerts (Alertmanager)
       Tipos de alerta que indican brecha de datos:
       - unauthorized_db_access: acceso a PostgreSQL sin token válido
       - data_exfiltration_pattern: transferencia de volumen anómalo
       - keycloak_realm_admin_unauthorized: acceso admin sin MFA
       - file_integrity_violation: modificación de binarios systemd

CONTENCIÓN
──────────────────────────────────────────────────────────────────
T+1h   Acción inmediata de contención (según SBOS-023 §6.3 Fase 2):
       □ Revocar tokens del usuario/servicio comprometido:
           keycloak-admin-cli users logout --userid={uuid}
       □ Si el compromiso es de una base de datos completa:
           IAM Installer puede suspender fichas del tenant afectado:
           bos-ctl ficha suspend --tenant={realm} --ficha={app}
       □ Preservar evidencia antes de cualquier cambio:
           - Exportar Wazuh alerts: curl wazuh-api/alerts?timeframe=1h
           - Exportar Keycloak Admin Events: GET /admin/realms/{realm}/admin-events
           - Capturar pg_stat_activity snapshot

EVALUACIÓN DE ALCANCE
──────────────────────────────────────────────────────────────────
T+4h   Determinar qué datos personales fueron expuestos:
       □ Consultar Keycloak Admin Events para acceso no autorizado al realm
       □ Consultar Wazuh logs para queries SQL ejecutadas
       □ Revisar logs de Kong Gateway (acceso a endpoints de datos)
       □ Determinar bounded contexts afectados (tabla §3.1)
       □ Estimar número de titulares afectados

       Criterio de notificación obligatoria:
       SI (datos_personales_comprometidos = true)
         Y (riesgo_para_titulares >= MEDIO)
       → iniciar proceso de notificación

DECISIÓN DE NOTIFICACIÓN
──────────────────────────────────────────────────────────────────
T+24h  El cliente (controlador) decide:
       □ ¿Hay datos personales confirmadamente comprometidos?
       □ ¿El riesgo para los derechos de los titulares es real?
       □ ¿Qué jurisdicción aplica? (según domicilio del titular)
       □ ¿Cuántos titulares están afectados?

       SKULL notifica al cliente:
       □ Resumen del incidente con evidencia técnica
       □ Lista de bounded contexts y bases de datos afectadas
       □ Logs relevantes (Wazuh + Keycloak) anonimizados

NOTIFICACIÓN A AUTORIDAD REGULADORA
──────────────────────────────────────────────────────────────────
T+72h  Plazo máximo en la mayoría de jurisdicciones
       □ El cliente (controlador) presenta la notificación formal
       □ Usar el template §5.2 adaptado a la jurisdicción

NOTIFICACIÓN A TITULARES AFECTADOS
──────────────────────────────────────────────────────────────────
T+72h+ Si el riesgo es alto (datos de salud, financieros, credenciales):
       □ Notificar individualmente a cada titular afectado
       □ Usar el template §5.3
```

### 4.2 Criterios de evaluación de riesgo para titulares

| Tipo de datos comprometidos | Riesgo estimado | Notificación a titulares |
|---|---|---|
| Credenciales Keycloak (hashes bcrypt) | ALTO — posible acceso a la cuenta | Obligatoria — forzar cambio de contraseña |
| Datos de empleados OrangeHRM (salario, datos personales) | ALTO — discriminación, suplantación | Obligatoria |
| Datos de salud GNU Health | MUY ALTO — categoría especial | Obligatoria — notificación prioritaria |
| Emails y nombres de clientes Saleor | MEDIO — spam, phishing | Recomendada si >100 afectados |
| Datos financieros Tryton (facturas) | MEDIO-ALTO — fraude fiscal | Obligatoria si incluye datos bancarios |
| IDs internos sin datos personales directos | BAJO | No requerida |

---

## 5. Templates de Notificación

### 5.1 Template: SKULL → Cliente (Procesador → Controlador)

```
ASUNTO: [URGENTE] Notificación de Incidente de Seguridad — SBOS — {FECHA}

Estimado/a {NOMBRE_CONTACTO_CLIENTE},

En cumplimiento de nuestras obligaciones como encargado del tratamiento (procesador),
SKULL Systems le notifica el siguiente incidente de seguridad detectado en su
instalación de SBOS:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DATOS DEL INCIDENTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Fecha y hora de detección:    {DATETIME_UTC}
Identificador de incidente:   INC-{YYYY}-{NNN}
Componente afectado:          {COMPONENTE — ej: keycloak_db / orangehrm_db}
Bounded context afectado:     {BC-XX — ej: BC-02 RRHH}
Tipo de incidente:            {acceso_no_autorizado / exfiltración / destrucción / alteración}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ALCANCE PRELIMINAR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Datos personales posiblemente afectados:  {SÍ / NO / EN INVESTIGACIÓN}
Categorías de datos:                      {empleados / clientes / salud / financieros}
Número estimado de titulares:             {N o "en determinación"}
Período de exposición estimado:           {desde DATETIME hasta DATETIME}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MEDIDAS DE CONTENCIÓN APLICADAS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{Lista de acciones tomadas: revocación de tokens, suspensión de fichas, etc.}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EVIDENCIA DISPONIBLE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
□ Logs de Wazuh (adjunto — periodo {DATETIME} a {DATETIME})
□ Keycloak Admin Events (adjunto — realm {REALM_NAME})
□ Logs de Kong Gateway (adjunto — endpoints afectados)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PRÓXIMOS PASOS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Como controlador de los datos, usted debe determinar:
1. Si el incidente requiere notificación a la autoridad reguladora de su jurisdicción
   (plazo: 72 horas desde el conocimiento del incidente)
2. Si los titulares afectados deben ser notificados individualmente
3. Si se requiere documentar el incidente en su Registro de Violaciones de Seguridad

SKULL Systems permanece disponible para asistirle en la investigación.
Contacto de emergencia 24/7: security@skull.systems | {NÚMERO_EMERGENCIA}

Atentamente,
SKULL Systems — Security Response Team
```

### 5.2 Template: Cliente → Autoridad Reguladora

```
NOTIFICACIÓN DE VIOLACIÓN DE DATOS PERSONALES
(Art. 33 RGPD / Ley 25326 Argentina / Ley 164 Bolivia / LFPDPPP México)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DATOS DEL RESPONSABLE (CONTROLADOR)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Nombre / Razón social:        {NOMBRE_EMPRESA}
Domicilio:                    {DIRECCIÓN}
Responsable de Protección de Datos / DPO:  {NOMBRE} — {EMAIL}
Número de registro (si aplica):            {NRO_INSCRIPCIÓN_BASE_DE_DATOS}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DESCRIPCIÓN DEL INCIDENTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Fecha y hora de detección:         {DATETIME}
Fecha y hora del incidente:        {DATETIME o "en determinación"}
Naturaleza de la violación:        {acceso no autorizado / pérdida / alteración / divulgación}
Sistema afectado:                  SBOS — Sovereign Business Operating System
Proveedor del sistema:             SKULL Systems (procesador)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DATOS AFECTADOS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Categorías de datos personales:   {ej: nombre, email, datos de salud, datos financieros}
Categorías de titulares:          {ej: empleados, clientes, pacientes}
Número aproximado de titulares:   {N}
Número aproximado de registros:   {N}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
POSIBLES CONSECUENCIAS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{Descripción del riesgo para los derechos y libertades de los titulares}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MEDIDAS ADOPTADAS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Medidas de contención:    {descripción}
Medidas de recuperación:  {descripción}
Notificación a titulares: {SÍ / NO / PENDIENTE — justificación}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INFORMACIÓN ADICIONAL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{Cualquier información adicional relevante para la autoridad}

Firma del Responsable: ___________________
Fecha: {FECHA}
```

### 5.3 Template: Cliente → Titulares Afectados

```
ASUNTO: Notificación importante sobre la seguridad de sus datos personales

Estimado/a {NOMBRE_TITULAR},

Le informamos que hemos detectado un incidente de seguridad en nuestros sistemas
que puede haber afectado sus datos personales.

QUÉ OCURRIÓ
{Descripción clara y no técnica del incidente}

QUÉ DATOS PUEDEN ESTAR AFECTADOS
{Lista específica de categorías de datos del titular}

QUÉ HEMOS HECHO
{Medidas de contención y corrección ya aplicadas}

QUÉ PUEDE HACER USTED
□ Cambie su contraseña en nuestros sistemas de forma inmediata
□ Active la verificación en dos pasos si no lo ha hecho
□ Esté atento a comunicaciones sospechosas que usen sus datos
□ Contáctenos si detecta uso no autorizado de su información

CONTACTO
{EMAIL_DPO} | {TELÉFONO} | {HORARIO_ATENCIÓN}

Lamentamos profundamente este incidente y le garantizamos que hemos
tomado todas las medidas necesarias para evitar que se repita.

{NOMBRE_EMPRESA}
```

---

## 6. Rotación de Claves JWT y Revocación de Sesiones

### 6.1 Arquitectura de claves en Keycloak

Keycloak gestiona las claves de firma de JWT por realm. En SBOS:

- **Algoritmo de firma:** RS256 (asimétrico) — clave privada en Keycloak, clave pública accesible vía JWKS endpoint
- **Duración del Access Token:** 5 minutos (configuración fija del realm — SBOS-023 §1)
- **Rotación automática:** Keycloak rota las claves de forma automática según el parámetro `keystore-expiration` del realm

### 6.2 Rotación de emergencia ante sospecha de compromiso

Cuando se sospecha que las claves de firma de Keycloak han sido comprometidas:

```bash
# PASO 1: Identificar el realm afectado
# realm = nombre del tenant comprometido (ej: bos-acme-corp)

# PASO 2: Forzar rotación de claves vía Keycloak Admin API
curl -X DELETE \
  https://keycloak.{dominio}/admin/realms/{realm}/keys/{keyId} \
  -H "Authorization: Bearer {admin_token}"

# PASO 3: Generar nuevas claves
# Keycloak genera automáticamente nuevas claves al eliminar las anteriores

# PASO 4: Verificar que el JWKS endpoint tiene las nuevas claves
curl https://keycloak.{dominio}/realms/{realm}/protocol/openid-connect/certs

# PASO 5: Invalidar TODAS las sesiones activas del realm
curl -X POST \
  https://keycloak.{dominio}/admin/realms/{realm}/logout-all \
  -H "Authorization: Bearer {admin_token}"
```

### 6.3 Impacto de la rotación de emergencia

| Elemento | Impacto | Tiempo de recuperación |
|---|---|---|
| Access Tokens activos | Invalidados inmediatamente — todas las llamadas API fallan | 0 segundos (inmediato) |
| Sesiones de usuario | Invalidadas — usuarios deben re-autenticarse | 0 segundos |
| Refresh Tokens | Invalidados — no se pueden renovar Access Tokens | 0 segundos |
| Tiempo hasta recuperación de operación | Usuarios se re-autentican obteniendo nuevo AT con nueva clave | 1-2 minutos por usuario |

**Ventaja del diseño SBOS:** La duración de 5 minutos del Access Token significa que, incluso sin rotación de emergencia, **en 5 minutos todos los tokens comprometidos expiran naturalmente**. La rotación de emergencia reduce este tiempo a cero.

### 6.4 Revocación selectiva por usuario comprometido

Si solo un usuario (no el realm completo) está comprometido:

```bash
# Revocar todas las sesiones de un usuario específico
REALM="bos-acme-corp"
USER_ID=$(curl -s https://keycloak.{dominio}/admin/realms/${REALM}/users?username={username} \
  -H "Authorization: Bearer {admin_token}" | jq -r '.[0].id')

curl -X POST \
  https://keycloak.{dominio}/admin/realms/${REALM}/users/${USER_ID}/logout \
  -H "Authorization: Bearer {admin_token}"

# Deshabilitar el usuario para prevenir re-autenticación
curl -X PUT \
  https://keycloak.{dominio}/admin/realms/${REALM}/users/${USER_ID} \
  -H "Authorization: Bearer {admin_token}" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}'
```

---

## 7. Registro de Incidentes de Datos Personales

### 7.1 Registro obligatorio (Art. 33.5 RGPD y equivalentes iberoamericanos)

El cliente (controlador) debe mantener un registro de todos los incidentes de datos personales, independientemente de si requirieron notificación a la autoridad.

**Formato del registro:**

| Campo | Descripción |
|---|---|
| ID incidente | INC-{YYYY}-{NNN} — correlaciona con el ticket de SKULL |
| Fecha detección | Datetime UTC |
| Fecha incidente | Datetime UTC o "indeterminado" |
| Naturaleza | Acceso no autorizado / Pérdida / Alteración / Divulgación |
| Datos afectados | Categorías de datos y bounded context SBOS |
| Titulares afectados | Número estimado y categoría (empleados / clientes / etc.) |
| Consecuencias | Descripción del riesgo materializado o potencial |
| Medidas adoptadas | Acciones de contención, erradicación y recuperación |
| Notificación autoridad | Sí / No — Motivo — Fecha — Autoridad — Referencia |
| Notificación titulares | Sí / No — Motivo — Fecha — Canal |
| Resolución | Fecha y descripción del cierre del incidente |

### 7.2 Retención del registro

El registro de incidentes debe conservarse un mínimo de:

- **España/UE (RGPD):** Sin plazo mínimo legal explícito — recomendado 3 años
- **Argentina (Ley 25326):** 5 años según resoluciones de la AAIP
- **Bolivia (Ley 164):** No especificado — recomendado alinearse con RGPD (3 años)
- **México (LFPDPPP):** 3 años desde que finaliza la relación con el titular

### 7.3 Localización del registro en SBOS

El registro de incidentes se almacena fuera de SBOS, en los sistemas del cliente (controlador). SBOS no gestiona este registro — SKULL Systems provee la **evidencia técnica** (logs Wazuh, Keycloak Admin Events) que el cliente incorpora a su registro.

---

## 8. Procedimiento para Ejercicio de Derechos ARCO

Los titulares tienen derecho a Acceso, Rectificación, Cancelación/Supresión y Oposición (ARCO) sobre sus datos. En SBOS, el cliente (controlador) gestiona estas solicitudes. SBOS provee las herramientas técnicas:

### 8.1 Exportación de datos de un titular (Derecho de Acceso / Portabilidad)

```bash
# El IAM Installer tiene un comando de exportación de datos por titular
# Exporta todos los datos del titular en todos los bounded contexts del realm

bos-ctl data export-subject \
  --realm=bos-{tenant} \
  --user-id={keycloak_user_id} \
  --format=json \
  --output=/tmp/subject-export-{userid}-{date}.json

# El archivo incluye:
# - Datos de Keycloak (perfil, roles, historial de sesiones)
# - Datos de OrangeHRM (si aplica) referenciados por user_id
# - Datos de EspoCRM/Saleor (si aplica) referenciados por email
```

### 8.2 Supresión de datos de un titular (Derecho al Olvido)

```bash
# ADVERTENCIA: esta operación es irreversible
# Requiere confirmación explícita del administrador del cliente

bos-ctl data delete-subject \
  --realm=bos-{tenant} \
  --user-id={keycloak_user_id} \
  --confirm=YES_DELETE_PERMANENTLY \
  --justification="Solicitud ARCO #{ticket_number}"

# El comando:
# 1. Desactiva al usuario en Keycloak
# 2. Anonimiza los registros en OrangeHRM (sustituye PII por [ELIMINADO])
# 3. Anonimiza en EspoCRM/Saleor
# 4. Registra la operación en el audit log del IAM Installer
# NOTA: Los registros contables en Tryton NO se eliminan — obligación legal de retención fiscal
```

---

## 9. Referencias Cruzadas

- **SBOS-023** — Arquitectura de Seguridad Zero Trust (base de este documento)
- **SBOS-022** — Bounded Contexts (inventario de datos por dominio)
- **SBOS-030** — SGSI ISO 27001:2022 (Declaración de Aplicabilidad)
- **SBOS-024** — Operaciones (runbooks de respuesta a incidentes — §6)
- **SBOS-008** — SBOS Auth Enforce H-RBAC (control de acceso a datos)
- **SBOS-019** — Keycloak Auth Methods (SPIs y configuración de sesiones)

---

## 10. Registro de Cambios

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| 1.0 | Marzo 2026 | SKULL Team — Legal + CTO | Documento inicial — marco regulatorio iberoamericano, roles procesador/controlador, proceso de respuesta, templates de notificación, rotación de claves JWT, derechos ARCO |

---

*SKULL · SBOS · SBOS-023-EXT-BREACH · v1.0 · Marzo 2026*
*Extiende: SBOS-023-Security-v1_0 · Responsable: CTO + Dirección Legal*
*Clasificación: Especificación Operacional — Cumplimiento Normativo*
