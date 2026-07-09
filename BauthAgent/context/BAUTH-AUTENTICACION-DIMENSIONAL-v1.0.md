# Autenticación Dimensional — Marco Conceptual y Técnico
**Documento:** BAUTH-AUTENTICACION-DIMENSIONAL-v1.0
**Versión:** 1.0.0 · **Clasificación:** INTERNO CRÍTICO
**Fecha:** 2026-06-30 · **Autor:** bauth-developer / sbos-coordinador
**Propósito:** Formalizar el concepto de Autenticación Dimensional como paradigma
de diseño de bAuth, establecer su fundamento normativo internacional y documentar
su capacidad de auditoría multidimensional orientada a certificación.

---

## 1. DEFINICIÓN DEL CONCEPTO

### 1.1 Autenticación Dimensional

**Autenticación Dimensional** es el paradigma de diseño de sistemas de identidad
y control de acceso en el que cada operación sobre cualquier dato de identidad
queda registrada con el conjunto completo de dimensiones de análisis necesarias
para responder cualquier consulta de auditoría, trazabilidad o cumplimiento
normativo desde cualquier eje de análisis, sin pérdida de información.

El sistema no solo controla **quién puede acceder** a un recurso, sino que
registra **quién, sobre qué campo exacto, con qué acción, desde qué contexto
organizacional, con qué nivel de confianza, desde qué tipo de dispositivo,
en qué momento** y **cuál fue el resultado**. Cada uno de estos ejes constituye
una dimensión de análisis independiente y combinable.

### 1.2 Alcance dentro de bAuth

La Autenticación Dimensional en bAuth se materializa en tres capas:

```
CAPA 1 — Control de acceso atómico
  Cada campo de datos de identidad es un átomo D.A.M.V independiente.
  El BitMask evalúa si el rol tiene el permiso exacto (campo + acción).
  Resolución: <0.5ns por evaluación (fast-path RolBitMask.check).

CAPA 2 — Registro dimensional completo
  Cada evaluación — permitida o denegada — genera un audit_event con
  todas las dimensiones embebidas (ctx_id, atom, actor, verbo, resultado).
  Inmutabilidad garantizada: append-only, no modificable post-escritura.

CAPA 3 — Análisis multidimensional
  Los audit_events son analizables desde cualquier combinación de dimensiones
  sin transformación previa: por tenant, por campo, por actor, por período,
  por resultado, por dominio, por dispositivo, por nivel de confianza.
```

---

## 2. FUNDAMENTO NORMATIVO

El diseño de Autenticación Dimensional no es una decisión de conveniencia técnica.
Es el resultado directo de los requisitos de los estándares internacionales de
seguridad, calidad e identidad que rigen la certificación del sistema.

### 2.1 ISO 9001:2015 — Sistema de Gestión de Calidad

| Cláusula | Requisito | Implementación en bAuth |
|----------|-----------|------------------------|
| §3.2.4 | Definición de cliente: receptor del producto o servicio. Los datos del cliente son activos controlados. | El `bdomain` representa al cliente. Sus datos (nombre, NIT, email, teléfono, dirección) son datos controlados con acceso definido por BitMask. |
| §7.5 | Información documentada (RolTemplates, UserTemplates) con control de cambios: quién puede crear, editar, eliminar, aprobar. | Cada operación sobre RolTemplate y UserTemplate tiene un átomo D.A.M.V propio. Solo roles autorizados tienen el bit correspondiente activo. |
| §8.2 | Captura y control de requisitos del cliente. Acceso solo por personal autorizado. | Campos de `bdomain` clasificados por sensibilidad. Acceso controlado por BitMask. Cada lectura y escritura trazada en audit_event. |
| §9.1.2 | Satisfacción del cliente: datos de contacto y comunicación mantenidos con integridad. | Datos de contacto en `org_contacto` con trazabilidad completa de cambios por campo. |
| §9.2 | Auditoría interna: toda modificación de datos del cliente debe ser trazable con evidencia objetiva. | audit_event con valor_anterior, valor_nuevo, user_id, timestamp, ctx_id, atom_slug por cada modificación. |
| §10.2 | No conformidad y acción correctiva documentada. | Accesos denegados registrados como no conformidades auditables. |

### 2.2 ISO 27001:2022 — Sistema de Gestión de Seguridad de la Información

| Control | Título | Implementación en bAuth |
|---------|--------|------------------------|
| A.5.15 | Control de acceso | Acceso basado en necesidad de conocer (need-to-know). Cada campo tiene su set de roles autorizados documentado en privilege_role_atom. |
| A.5.18 | Derechos de acceso | Provisión, revisión y revocación documentada. El RolBitMask es la representación formal de los derechos de acceso de cada rol. |
| A.8.2 | Gestión de identidad | Ciclo de vida completo de identidades en bAuth: registro, asignación, revisión trimestral, revocación. |
| A.8.15 | Logging | Registro de auditoría obligatorio por cada acceso a dato crítico. audit_event con mínimo: quién, qué, cuándo, desde dónde, resultado. |
| A.5.33 | Protección de registros | Los audit_events son append-only. Ningún rol tiene permisos de UPDATE o DELETE sobre la tabla de auditoría. |

### 2.3 ISO 24760-2:2025 — Gestión de Identidad

Estándar de referencia directa para el diseño del dominio D00:

| Sección | Requisito | Implementación |
|---------|-----------|---------------|
| §6.1 | Atributos de identidad clasificados por sensibilidad | Clasificación en 4 niveles: PUBLIC / INTERNAL / CONFIDENTIAL / CRITICAL aplicada a cada átomo D00. |
| §6.3 | Control de acceso diferenciado por clasificación | Los roles con acceso a datos CONFIDENTIAL requieren trust_level >= HIGH en el AtomBitMask. |
| §7.2 | Trazabilidad de cambios en atributos de identidad | Cada modificación de atributo de identidad genera audit_event con dimensiones completas. |

### 2.4 NIST SP 800-53 Rev.5 — Controles de Seguridad

| Control | Título | Implementación |
|---------|--------|---------------|
| AC-2 | Account Management | Roles documentados con permisos explícitos en privilege_role_atom. Revisión periódica obligatoria. |
| AC-6 | Least Privilege | El BitMask otorga solo los átomos estrictamente necesarios para cada rol. Ningún rol tiene acceso universal salvo SU. |
| AU-2 | Audit Events | Definición formal de qué eventos generar audit_event (toda operación CRUD sobre campos de dominios D00-D12). |
| AU-3 | Content of Audit Records | Contenido mínimo de cada registro: actor, objeto, acción, resultado, timestamp, ctx_id. Todos presentes en audit_event. |
| AU-9 | Protection of Audit Information | La tabla audit_event no es modificable por ningún rol operacional. Solo SU tiene acceso de lectura para análisis. |

---

## 3. CONTROL DE ACCESO GRANULAR POR CAMPO

### 3.1 El modelo D.A.M.V como unidad de permiso

Cada dato de identidad en cualquier dominio D00-D12 es identificado por el
cuadruplete **D.A.M.V** (Dominio · Aplicación · Módulo · Verbo):

```
D = domain_code  → qué dominio de soberanía (D00=Identidad, D1=Acceso Lógico, ...)
A = app_code     → qué aplicación dentro del dominio (org, tryton, kong, ...)
M = group_code   → qué campo o módulo específico (bdomain_email, roltemplate, ...)
V = verb_code    → qué acción sobre ese campo (1=crear, 2=editar, 3=eliminar, 4=ver)
```

El verbo V es siempre una **acción CRUD estándar**, nunca el nombre del campo.
El nombre del campo es el Módulo M (group_code). Esta distinción es fundamental:

```
INCORRECTO — campo como verbo (no evaluable por BitMask con granularidad):
  átomo: group=bdomain(g2), verb=email(54)
         ↑ un solo átomo para todo tipo de operación sobre email

CORRECTO — campo como módulo, acción como verbo:
  átomo: group=bdomain_email(g05), verb=ver(4)      → bit independiente
  átomo: group=bdomain_email(g05), verb=editar(2)   → bit independiente
  átomo: group=bdomain_email(g05), verb=crear(1)    → bit independiente
  átomo: group=bdomain_email(g05), verb=eliminar(3) → bit independiente
```

Con el modelo correcto, el RolBitMask puede expresar:
*"Este rol puede VER el email pero no EDITARLO"* — con granularidad de un solo bit.

### 3.2 Clasificación de datos por sensibilidad (ISO 24760-2:2025)

| Campo D00 | Clasificación ISO 24760 | Nivel min_trust requerido |
|-----------|:-----------------------:|:------------------------:|
| `tenant.type` | CRITICAL | CRITICAL |
| `bdomain.nit` | CONFIDENTIAL | HIGH |
| `bdomain.ci` | CONFIDENTIAL | HIGH |
| `actor.id_doc_type` + número | CONFIDENTIAL | HIGH |
| `actor.gender` | RESTRICTED | MEDIUM |
| `actor.marital_status` | RESTRICTED | MEDIUM |
| `bdomain.nombre` | INTERNAL | MEDIUM |
| `bdomain.email` | INTERNAL | LOW |
| `bdomain.telefono` | INTERNAL | LOW |
| `bdomain.direccion` | INTERNAL | LOW |
| `actor.email` | INTERNAL | LOW |
| `actor.telefono` | INTERNAL | LOW |
| `actor.locale` | PUBLIC | NONE |
| `actor.timezone` | PUBLIC | NONE |

### 3.3 Matriz de permisos por nivel de rol (ISO 27001 A.5.15 — Need-to-Know)

| Campo D00 | EXT_N0 Hogar | BIZ_N5 Operativo | BIZ_N3 Especialista | BIZ_N2 Supervisor | BIZ_N1 Admin | SU/SYS |
|-----------|:------------:|:----------------:|:-------------------:|:-----------------:|:------------:|:------:|
| `tenant.type` | — | — | — | ver | ver | todo |
| `bdomain.nit` | — | — | ver | ver | ver+editar | todo |
| `bdomain.ci` | — | — | — | ver | ver+editar | todo |
| `bdomain.nombre` | ver | ver | ver | ver+editar | todo | todo |
| `bdomain.email` | ver | ver | ver | ver+editar | todo | todo |
| `bdomain.telefono` | ver | ver | ver+editar | ver+editar | todo | todo |
| `bdomain.direccion` | ver | ver | ver | ver+editar | todo | todo |
| `actor.id_doc_type` | ver propio | ver propio | ver | ver+editar | todo | todo |
| `actor.telefono` | todo propio | ver+editar propio | ver+editar | todo | todo | todo |
| `actor.email` | todo propio | ver+editar propio | ver+editar | todo | todo | todo |
| `actor.gender` | ver propio | ver propio | ver | ver | ver+editar | todo |
| `actor.marital_status` | ver propio | ver propio | — | ver | ver+editar | todo |
| `actor.locale` | todo propio | todo propio | ver | todo | todo | todo |
| `actor.timezone` | todo propio | todo propio | ver | todo | todo | todo |
| `roltemplate.*` | — | — | ver | ver | ver+editar | todo |
| `roltemplate.rules` | — | — | — | ver+agregar | todo | todo |
| `usertemplate.*` | ver propio | ver propio | ver | ver+editar | todo | todo |
| `policies.*` | — | — | ver | ver | ver+editar | todo |

*todo = crear + editar + eliminar + ver · ver = solo lectura · — = sin acceso*

### 3.4 Evaluación BitMask: cómo se aplica esta matriz

```
Pregunta del sistema en runtime:
  ¿Puede el usuario (rol BIZ_N2) editar el NIT del bdomain activo?

Evaluación:
  position = AtomPositionResolver.resolve("D00.bdomain_nit.editar")
           → HashMap lookup O(1)

  resultado = rol_bitmask_BIZ_N2.check(position)
            → bit read <0.5ns
            → false  (BIZ_N2 no tiene ese bit activo)

  audit_event generado:
    atom     = "D00.bdomain_nit.editar"
    actor    = user_id
    result   = Denegado
    ctx_id   = false.T-depo.BD-depo.BS-norte
    timestamp= 2026-06-30T14:32:00Z
```

Cada denegación es tan trazable como cada permisión. Ambas generan evento.

---

## 4. COMPARACIÓN: CONTABILIDAD DIMENSIONAL vs AUTENTICACIÓN DIMENSIONAL

### 4.1 Analogía estructural

La Contabilidad Dimensional resuelve el problema de registrar transacciones
económicas con suficientes dimensiones para responder cualquier consulta analítica
posterior. La Autenticación Dimensional resuelve el mismo problema para
transacciones de identidad y acceso.

Ambos paradigmas comparten la misma arquitectura fundamental:

| Concepto | Contabilidad Dimensional | Autenticación Dimensional (bAuth) |
|----------|--------------------------|-----------------------------------|
| **Unidad de registro** | Asiento contable | audit_event |
| **Irrevocabilidad** | Asiento no se borra (NIIF) | audit_event append-only (ISO 27001 A.5.33) |
| **Dimensión de cuenta** | Plan de cuentas jerárquico | Catálogo de átomos D.A.M.V |
| **Cuenta analítica** | Centro de costo / proyecto | atom_slug (D00.actor.telefono.editar) |
| **Centro de costo** | Departamento / sucursal | ctx_id (tenant → bdomain → bsubdomain) |
| **Actor de la transacción** | Empleado / sistema | user_id + rol_tier |
| **Período contable** | Mes / trimestre / año fiscal | audit_period + timestamp |
| **Débito / Crédito** | Naturaleza de la cuenta | access_result (Permitido / Denegado) |
| **Importe** | Valor monetario | valor_anterior → valor_nuevo |
| **Cierre contable** | Balance de comprobación | reconcile loop 60s (reconcile.rs) |
| **Auditoría externa** | Auditor CPA / PCAOB | ISO 27001 A.8.15 + ISO 9001 §9.2 |
| **Segregación de funciones** | SoD contable (quien aprueba no ejecuta) | SoD matrix (domain/sod.rs) |
| **No repudio** | Firma del contador | D12 blockchain anchoring + Ed25519 |

### 4.2 Drill-down comparativo

**Contabilidad Dimensional:**
```
Nivel 1: Total gastos empresa             → 4,500,000 Bs
Nivel 2: Gastos por sucursal              → Sucursal Norte: 1,200,000 Bs
Nivel 3: Gastos por departamento          → Operaciones: 800,000 Bs
Nivel 4: Gastos por cuenta analítica      → Telefonía: 45,000 Bs
Nivel 5: Gastos por empleado              → Juan Pérez: 1,500 Bs
```

**Autenticación Dimensional:**
```
Nivel 1: Total eventos de acceso/tenant   → T-depo: 128,450 eventos/mes
Nivel 2: Eventos por sucursal (bsubdomain)→ BS-norte: 34,200 eventos
Nivel 3: Eventos por dominio              → D00 (Identidad): 8,100 eventos
Nivel 4: Eventos por campo (atom_slug)    → actor.telefono.editar: 234 eventos
Nivel 5: Eventos por actor (user_id)      → ana-flores: 12 ediciones de teléfono
Nivel 6: Detalle del evento               → valor_anterior, valor_nuevo, dispositivo, trust_level
```

En ambos casos, el analista puede comenzar desde cualquier nivel y navegar hacia
cualquier otro nivel sin perder información. Ningún agregado destruye el detalle.

### 4.3 Dimensiones de análisis

**Contabilidad Dimensional (5-7 dimensiones típicas):**
```
1. Temporal   → período contable
2. Geográfica → país, región, ciudad
3. Orgánica   → empresa, sucursal, departamento
4. Cuentas    → plan de cuentas (jerarquía)
5. Actor      → empleado, proveedor, cliente
6. Proyecto   → centro de costo analítico
7. Moneda     → moneda de origen + moneda funcional
```

**Autenticación Dimensional (10+ dimensiones):**
```
1.  Temporal       → timestamp con precisión microsegundo
2.  Organizacional → ctx_id = tenant + bdomain + bsubdomain + pos
3.  De dominio     → domain_code (D00-D12, 13 planos de control)
4.  De campo       → group_code (el átomo M del cuadruplete D.A.M.V)
5.  De acción      → verb_code (crear / editar / eliminar / ver)
6.  De actor       → user_id + rol_tier (7 niveles: SU→EXT_N0)
7.  De dispositivo → device_categories (8 tipos: MOBILE, CARD, IOT, ...)
8.  De confianza   → trust_level (NONE → CRITICAL)
9.  De resultado   → Permitido / Denegado / Pendiente
10. De binding     → token_binding (NONE / DEVICE / SESSION / HARDWARE)
11. De anclaje     → blockchain_anchored (D12, no-repudio)
12. De política    → policy_state (NoAplica / Pendiente / Aprobado / Rechazado)
13. De clasificación → data_classification (PUBLIC / INTERNAL / CONFIDENTIAL / CRITICAL)
```

La Autenticación Dimensional supera a la Contabilidad Dimensional en número de
dimensiones porque el dominio de identidad y acceso es inherentemente más
multidimensional que el dominio financiero.

### 4.4 Valoración comparativa formal

| Criterio | Contabilidad Dimensional | Autenticación Dimensional | Ventaja |
|----------|:------------------------:|:-------------------------:|:-------:|
| Dimensiones de análisis | 5-7 | 10-13 | Autenticación |
| Granularidad de registro | Por transacción | Por campo de dato | Autenticación |
| Irrevocabilidad garantizada | Estándar NIIF | Append-only + blockchain | Equivalente |
| Reconciliación automática | Manual / periódica | Automática 60s | Autenticación |
| Trazabilidad de cambios | Asiento reversivo | valor_anterior + valor_nuevo | Equivalente |
| Segregación de funciones | SoD contable | SoD matrix + BitMask | Autenticación |
| No repudio legal | Firma contador | Ed25519 + ADSIB (Ley 164 BO) | Autenticación |
| Velocidad de evaluación | N/A (post-facto) | <0.5ns (pre-facto) | Autenticación |
| Estándares de referencia | NIIF, PCAOB, NIC | ISO 27001, ISO 9001, NIST | Equivalente |
| Madurez del paradigma | 500+ años | Paradigma emergente | Contabilidad |

**Conclusión de la valoración:** La Autenticación Dimensional implementa los
principios fundamentales de la Contabilidad Dimensional (irrevocabilidad, múltiples
dimensiones, drill-down desde cualquier eje, segregación de funciones) y los extiende
con dimensiones propias del dominio de identidad y acceso que la contabilidad no
necesita. El paradigma es más joven pero técnicamente más rico en dimensiones.

---

## 5. CAPACIDADES DE AUDITORÍA QUE HABILITA EL PARADIGMA

### 5.1 Consultas que el sistema puede responder sin trabajo adicional

Las siguientes preguntas de auditoría son respondibles directamente desde los
audit_events sin transformación de datos ni trabajo de preparación:

```sql
-- ISO 27001 A.8.15 / ISO 9001 §9.2
-- ¿Quién modificó datos CONFIDENTIAL en los últimos 90 días?
SELECT user_id, atom_slug, valor_anterior, valor_nuevo, timestamp, ctx_id
FROM audit_event
WHERE data_classification = 'CONFIDENTIAL'
  AND verb_code IN (1, 2, 3)  -- crear, editar, eliminar
  AND timestamp >= NOW() - INTERVAL '90 days'
ORDER BY timestamp DESC;

-- ISO 27001 A.5.15 / NIST AC-6
-- ¿Qué roles tienen permiso de editar el NIT de un cliente?
SELECT rol_tier, rol_slug
FROM privilege_role_atom pra
JOIN privilege_atom pa ON pra.atom_code = pa.atom_code
WHERE pa.atom_slug = 'D00.bdomain_nit.editar'
  AND pra.allowed = true;

-- ISO 9001 §8.2
-- ¿Cuántas modificaciones al teléfono del cliente X ocurrieron este año?
SELECT COUNT(*), MIN(timestamp), MAX(timestamp)
FROM audit_event
WHERE atom_slug = 'D00.actor.telefono.editar'
  AND entidad_id = 'uuid-del-cliente-X'
  AND timestamp >= '2026-01-01';

-- ISO 27001 A.8.15 — Accesos denegados por sucursal
SELECT ctx_id, atom_slug, user_id, COUNT(*) as intentos
FROM audit_event
WHERE access_result = 'Denegado'
  AND ctx_id LIKE 'false.T-depo.%'
  AND timestamp BETWEEN '2026-04-01' AND '2026-06-30'
GROUP BY ctx_id, atom_slug, user_id
ORDER BY intentos DESC;

-- NIST AU-3 — Reconstruir el historial completo de un campo
SELECT timestamp, user_id, valor_anterior, valor_nuevo, device_category, trust_level
FROM audit_event
WHERE atom_slug = 'D00.bdomain.email.editar'
  AND entidad_id = 'uuid-del-bdomain'
ORDER BY timestamp ASC;
-- Resultado: línea de tiempo completa del campo, como un libro mayor
```

### 5.2 Capacidad de reconstrucción de estado

Al igual que la contabilidad puede reconstruir el balance en cualquier fecha
aplicando los asientos en secuencia, la Autenticación Dimensional puede reconstruir
el estado de cualquier campo de identidad en cualquier momento:

```
Estado actual del email:    "info@depo.com.bo"
                                 ↑
audit_event[T5]: editar  → valor_nuevo="info@depo.com.bo", actor=admin
audit_event[T4]: editar  → valor_nuevo="contacto@depo.com.bo", actor=BIZ_N1
audit_event[T3]: editar  → valor_nuevo="depo@gmail.com", actor=BIZ_N1
audit_event[T2]: crear   → valor_nuevo="depo@gmail.com", actor=SU
audit_event[T1]: (no existía)

→ Estado en T3: "depo@gmail.com"
→ Estado en T4: "contacto@depo.com.bo"
→ Estado actual: "info@depo.com.bo"
```

Esta capacidad de reconstrucción es el equivalente exacto al **libro mayor** en
contabilidad: cada asiento es inmutable y la secuencia de asientos determina el
estado actual y cualquier estado histórico.

---

## 6. GAPS PARA CERTIFICACIÓN COMPLETA

Los siguientes elementos están especificados pero pendientes de implementación
completa. Su ausencia no bloquea el desarrollo pero sí bloquea la certificación:

| Gap | Norma que lo exige | Prioridad |
|-----|--------------------|:---------:|
| audit_event append-only con enforcement a nivel BD (TRIGGER que previene UPDATE/DELETE) | ISO 27001 A.5.33 | ALTA |
| Cambios al catálogo de átomos (privilege_atom) con su propio audit_event | ISO 27001 A.8.15 | ALTA |
| Versioning de RolTemplate (snapshot en el momento del audit_event) | ISO 9001 §7.5 | MEDIA |
| Período de retención de audit_events documentado y enforceado (mínimo 2 años) | ISO 27001 A.5.33 | MEDIA |
| Firma digital de bloques de audit_events (non-repudiation grupal) | NIST AU-9 | MEDIA |
| Reporte de auditoría generado automáticamente por bAuth (no manual) | ISO 9001 §9.2 | BAJA |

---

## 7. CONCLUSIÓN

La Autenticación Dimensional es el paradigma correcto para un sistema de identidad
orientado a certificación ISO 27001, ISO 9001 e ISO 24760-2. No es un refinamiento
técnico opcional — es el mecanismo por el cual el sistema puede demostrar ante un
auditor externo que:

1. **Cada dato de identidad tiene controles de acceso documentados** por rol, por
   campo y por tipo de acción (D.A.M.V + BitMask).

2. **Cada acceso es trazable** con todas las dimensiones necesarias para cualquier
   análisis de auditoría (audit_event multidimensional).

3. **Ningún registro puede ser alterado** una vez emitido (append-only + blockchain
   anchoring D12).

4. **El estado de cualquier campo puede ser reconstruido** en cualquier punto del
   tiempo (historia inmutable de audit_events, equivalente al libro mayor contable).

5. **La segregación de funciones está implementada formalmente** y es verificable
   mediante consulta directa al catálogo de átomos (privilege_role_atom).

El término **Autenticación Dimensional** captura con precisión lo que el paradigma
implementa: autenticación y autorización con múltiples dimensiones de análisis,
al nivel de rigurosidad de la contabilidad dimensional, aplicado al dominio de
identidad y acceso.

---

*Documento técnico interno — no requiere aprobación DDL.*
*Referencia normativa: ISO 9001:2015, ISO 27001:2022, ISO 24760-2:2025,*
*NIST SP 800-53 Rev.5, NIST SP 800-63B Rev.4, NIIF (para la analogía contable).*
