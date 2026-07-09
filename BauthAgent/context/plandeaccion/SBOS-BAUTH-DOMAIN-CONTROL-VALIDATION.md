# SBOS — Validación Normativa: Domain Control Methodology v1.0
## Revisión técnica con evidencia de estándares internacionales y soluciones

> ⚠️ **ACTUALIZACIÓN — JUNIO 2026:** Esta validación se realizó sobre la metodología de 11 dominios. La metodología ahora cubre **12 dominios** (D1–D11 + D12 Blockchain). El modelo BitMask también ha sido actualizado (ver `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`). Los criterios de validación normativa (ISO 27001, NIST, PCI-DSS) siguen siendo correctos y aplicables; solo cambia la implementación técnica subyacente.

### SKULL · SBOS · SBOS-BAUTH-DOMAIN-CONTROL-VALIDATION v1.1 · Junio 2026

---

## VEREDICTO GENERAL

**El documento es arquitectónicamente correcto y sus decisiones de diseño están respaldadas por los estándares internacionales que cita.** La clasificación en Fast-Path / Policy-Path / External-Path corresponde con precisión a los patrones industriales establecidos (XACML 3.0 PEP/PDP/PIP, NIST SP 800-207 ZTA, Linux capabilities u64). Los 11 dominios están correctamente asignados a su capa de control. No hay errores de diseño fundamentales.

Este documento entrega **refuerzos normativos con evidencia**, **correcciones precisas con solución implementable**, y **gaps que deben cerrarse** antes de usar la metodología como referencia normativa en auditorías externas.

---

## SECCIÓN 1 — VALIDACIÓN DE LA ARQUITECTURA DE TRES CAPAS

### ✅ La clasificación Fast/Policy/External está respaldada por XACML 3.0 y NIST SP 800-207

El documento implementa correctamente la arquitectura PEP/PDP/PIP de XACML sin nombrarla explícitamente. Esta es la correspondencia normativa formal:

| Capa bAuth | Equivalente XACML 3.0 | Equivalente NIST SP 800-207 |
|---|---|---|
| Fast-Path (BitMask) | PEP local cache — verifica capability en el punto de enforcement | Policy Enforcement Point (PEP) cerca del recurso |
| Policy-Path (Reglas) | PDP (Policy Decision Point) — evalúa políticas contra atributos | Policy Engine (PE) + Policy Administrator (PA) |
| External-Path (API) | PIP (Policy Information Point) — provee atributos contextuales al PDP | Fuentes de datos de confianza continua |

**Recomendación:** Agregar al documento una nota de conformidad arquitectural con el texto:

> "La arquitectura de tres capas de bAuth es compatible con el modelo PEP/PDP/PIP de OASIS XACML 3.0 y con el marco de componentes lógicos de NIST SP 800-207 §3. Esta alineación permite que auditorías de conformidad externas usen terminología estándar al evaluar el sistema."

Esto no cambia implementación pero habilita trazabilidad directa con auditores externos.

---

### ✅ El BitMask u64 tiene precedente de kernel en producción

El kernel Linux implementa capabilities exactamente como `typedef struct { u64 val; } kernel_cap_t` (archivo `include/linux/capability.h`, repositorio Torvalds). La operación AND bitwise para verificar permisos efectivos es el patrón exacto del kernel desde la versión 2.6.24. El diseño del BitMask de bAuth es formalmente análogo al mecanismo de capabilities de Linux, basado en el draft POSIX.1e (retirado en 1999 pero implementado en el kernel).

**Refuerzo normativo para agregar al documento:**

> "El diseño del BitMask u64 sigue el patrón establecido por Linux capabilities (POSIX.1e draft, kernel ≥ 2.6.24), donde cada proceso mantiene tres bitmasks de 64 bits (permitted, effective, inheritable). La verificación `mask.has(bit)` es equivalente a la operación `capable(CAP_X)` del kernel, con latencia sub-nanosegundo en ambos casos."

---

## SECCIÓN 2 — OBSERVACIONES CON SOLUCIÓN POR DOMINIO

---

### D1 — DOMINIO LÓGICO

**Estado:** ✅ Correcto.

**Refuerzo de estándar:** La referencia "ZRB 2024" no corresponde a ningún estándar ISO, NIST, o OASIS publicado. Si es una norma interna SBOS, debe etiquetarse explícitamente como `[SBOS-INTERNO]` para que los auditores externos no intenten resolver la referencia.

**Solución:** Reemplazar "ZRB 2024" por la referencia correcta al estándar que se intenta citar, o agregar la anotación:

```
| **Estándar** | [SBOS-INTERNO] ZRB 2024, OASIS XACML 3.0, NIST RBAC §4, NIST SP 800-162 (ABAC Guide) |
```

**Adición recomendada:** **NIST SP 800-162** (Guide to Attribute Based Access Control) formaliza el mapeo atributo→permiso en el contexto ABAC/RBAC y es la referencia NIST más directa para la verificación zona×verbo del D1.

---

### D2 — DOMINIO FÍSICO

**Estado:** ✅ Correcto.

**Refuerzo de estándar:** Agregar a la fila de estándares:

- **EN 60839-11-1:2013** — Requisitos del sistema de control de acceso electrónico (norma madre de la serie IEC 60839-11). IEC 60839-11-5 (OSDP) es el protocolo de comunicación entre lector y controlador; EN 60839-11-1 define los requisitos funcionales del sistema completo.
- **ANSI/SIA AC-01-2010** — Format for Electronic Access Control. Define los campos de identidad y respuesta en readers, relevante para la arquitectura de `bos_dispositivo_fisico`.

**Solución:** Actualizar la fila de estándar en la tabla D2:

```
| **Estándar** | BS 5979:2007, IEC 60839-11-5 (OSDP v2.2), EN 60839-11-1:2013, ANSI/SIA AC-01-2010, CPTED/ASIS |
```

---

### D3 — DOMINIO FINANCIERO

**Estado:** ✅ Arquitectura correcta. ⚠️ Gap de especificación crítico para auditoría.

**Observación:** El campo `check_sod_conflict()` referenciado en la implementación contra un "Conflict Matrix" no existe en ningún lugar del documento ni de la especificación BAUTH-100. SOX §404 requiere que los controles internos sean **documentados y testeables** por auditores externos. Un `check_sod_conflict()` que consulta una matriz no definida es, desde la perspectiva de auditoría, un control sin evidencia.

La industria define el SoD Conflict Matrix como una tabla rol×rol (o función×función) donde cada intersección indica si la combinación es Conflicto / Permitida / Requiere compensación. En sistemas ERP como SAP, esta matriz es el artefacto de auditoría central para cumplimiento SOX.

**Solución — Definición normativa del Conflict Matrix para D3:**

Agregar a la especificación de D3 la siguiente tabla como parte del esquema `bos_financial_decision_matrix`:

```
CONFLICT MATRIX — bAuth Financial Domain (D3)
Nivel de riesgo: ALTO = bloquear, MEDIO = requiere compensación, BAJO = permitida con log

                    │ FINANCIAL_CREATE │ FINANCIAL_APPROVE │ BACKUP_TRIGGER │ REPORT_EXPORT │
────────────────────┼──────────────────┼───────────────────┼────────────────┼───────────────┤
FINANCIAL_CREATE    │      —           │      ALTO ❌       │     BAJO ✓     │    BAJO ✓     │
FINANCIAL_APPROVE   │    ALTO ❌        │      —            │     BAJO ✓     │    BAJO ✓     │
BACKUP_TRIGGER      │    BAJO ✓        │     BAJO ✓        │      —         │    BAJO ✓     │
REPORT_EXPORT       │    BAJO ✓        │     BAJO ✓        │     BAJO ✓     │      —        │
```

La regla fundamental: **quien crea una transacción (FINANCIAL_CREATE) no puede aprobarla (FINANCIAL_APPROVE)**. Este es el conflicto de SoD más auditado en SOX §404. La función `check_sod_conflict(user_uuid, role_to_assign)` debe consultar esta tabla antes de asignar cualquier combinación de bits financieros al BitMask efectivo de un usuario.

**Implementación en PostgreSQL:**

```sql
-- Tabla de conflictos SoD
CREATE TABLE bos_sod_conflict_matrix (
    bit_a        INTEGER NOT NULL,  -- bit del permiso A
    bit_b        INTEGER NOT NULL,  -- bit del permiso B
    risk_level   TEXT NOT NULL CHECK (risk_level IN ('ALTO', 'MEDIO', 'BAJO')),
    action       TEXT NOT NULL CHECK (action IN ('BLOCK', 'COMPENSATE', 'ALLOW_LOG')),
    rationale    TEXT NOT NULL,     -- justificación normativa (SOX §404, COSO, etc.)
    PRIMARY KEY (bit_a, bit_b)
);

-- Insertar conflicto central SOX
INSERT INTO bos_sod_conflict_matrix VALUES
  (14, 15, 'ALTO', 'BLOCK',
   'SOX §404 COSO Control Activities: quien crea no puede aprobar. Bit 14=FINANCIAL_APPROVE, Bit 15=FINANCIAL_CREATE.');
```

La función `check_sod_conflict()` consulta esta tabla; si encuentra `action = 'BLOCK'` para cualquier par de bits que el usuario ya tiene vs. el rol a asignar, rechaza la asignación y registra el intento en `bauth_audit_events`.

**Estándar adicional:** La matriz debe revisarse anualmente según **ISACA COBIT 2019 BAI09** (Managed Changes) y debe ser un artefacto entregable en auditorías SOX §404.

---

### D4 — DOMINIO TEMPORAL

**Estado:** ✅ Correcto.

**Refuerzo:** La referencia a GTRBAC es correcta como fundamento académico (Joshi, Bertino, Latif, Ghafoor — ACM TISSEC 2005, "A Generalized Temporal Role-Based Access Control Model"). Es la publicación de referencia para RBAC con restricciones temporales y puede citarse como: `GTRBAC (Joshi et al., ACM TISSEC 8(4), 2005)`.

**Contexto boliviano:** El sistema de control temporal debe respetar la **Ley General del Trabajo Bolivia (D.S. 13/1944 y sus modificaciones)**: jornada máxima de 8 horas diarias y 48 horas semanales (Art. 46 LGT). Las reglas de `bos_schedule` deben validar contra estos límites cuando se configuren turnos para trabajadores bajo relación de dependencia, especialmente para audit trails laborales.

---

### D5 — DOMINIO BIOMÉTRICO

**Estado:** ✅ Correcto. Requiere actualización de estándares y un matiz normativo importante.

**Matiz normativo NIST SP 800-63B-4 (2024):** La biometría en AAL3 **no es un factor de autenticación independiente**; funciona como mecanismo de desbloqueo de un autenticador hardware (FIDO2 hardware key, smart card). NIST SP 800-63B-4 §5.2.3 es explícito: "Biometrics SHALL be used only as part of multi-factor authentication with a physical authenticator." El documento debe aclarar este matiz para evitar implementaciones donde la biometría reemplaza al factor hardware en lugar de complementarlo.

**Solución:** Agregar a la fila de implementación de D5:

```
| **Implementación** | `BiometricEvaluator::evaluate(user_uuid, required_loa)` → consultar sensor → 
|                    | validar liveness (ISO/IEC 30107-3) → comparar hash Argon2id → responder.
|                    | NOTA: En AAL3, la biometría actúa como mecanismo de desbloqueo del
|                    | autenticador hardware (FIDO2/WebAuthn), NO como factor independiente.
|                    | (NIST SP 800-63B-4 §5.2.3) |
```

**Actualización de estándares:** Agregar:
- **ISO/IEC 19795-1:2021** y **ISO/IEC 19795-10:2024** — Estándares de testing de performance biométrico, ahora citados normativamente en NIST SP 800-63A-4. Los sistemas biométricos de bAuth deben ser conformes con estas normas de evaluación.
- **Ley 164 (Bolivia, 2011)** — Ley General de Telecomunicaciones, TIC, Arts. 54-56. Establece derechos sobre datos personales en sistemas de información. La biometría (dato sensible de categoría especial) está sujeta a esta normativa en el contexto boliviano, en ausencia de una ley específica de protección de datos.

**Solución — Fila de estándar actualizada:**

```
| **Estándar** | NIST SP 800-63B-4 (2024) AAL3, RGPD Art.9, ISO/IEC 30107-3 (liveness/PAD),
|              | ISO/IEC 19795-1:2021, ISO/IEC 19795-10:2024, FIDO2/WebAuthn (W3C),
|              | Ley 164 Bolivia Arts. 54-56 |
```

---

### D6 — DOMINIO GEOESPACIAL

**Estado:** ✅ Correcto. Dos ajustes técnicos recomendados.

**Ajuste 1 — Umbral de "viaje imposible":** El documento define el umbral en >500 km/h. El análisis de la industria indica que Microsoft Defender for Cloud Apps y Azure Sentinel usan un umbral de **~1000 km/h** como punto de corte para vuelos comerciales (velocidad real de crucero: ~900 km/h). Un umbral de 500 km/h genera falsos positivos para usuarios que viajan en vuelo entre ciudades bolivianas y ciudades vecinas (La Paz ↔ Buenos Aires en vuelo directo: ~900 km/h de velocidad promedio puerta a puerta).

**Solución:** Hacer el umbral configurable por tenant con valor default de **900 km/h** y documentar la justificación:

```
| **Implementación** | `GeospatialEvaluator::evaluate(ip, tenant_id)` → geo-IP lookup → 
|                    | ¿país autorizado? → ¿jurisdicción fiscal coincide? →
|                    | ¿viaje imposible? (velocidad > tenant.impossible_travel_kmh,
|                    |   default: 900 km/h — velocidad de crucero vuelo comercial).
|                    | El threshold es configurable por tenant via bos_tenant_config. |
```

**Ajuste 2 — Alineación con NIST SP 800-207 Tenet 3:** La reevaluación geoespacial cada 15 minutos es consistente con el tenet de Zero Trust que establece que el acceso se otorga por sesión con reevaluación continua. Documentar esta alineación explícitamente en el estándar:

```
| **Estándar** | NIST SP 800-207 (ZTA) Tenet 3, SBOS-044 FISCAL, ISO 3166,
|              | CISA Zero Trust Maturity Model v2.0 (2023) |
```

---

### D7 — DOMINIO DE RED

**Estado:** ⚠️ Inconsistencia que debe corregirse.

**Observación:** La tabla de D7 declara "No usa BitMask — evaluación de red". Sin embargo, la Sección 4 (definición del BitMask) asigna:
- Bit 11: `NETWORK_EXTERNAL` — acceso internet externo
- Bit 12: `VPN_ACCESS` — VPN corporativa

Ambas afirmaciones son verdaderas pero contradictorias como están escritas, lo que generará confusión en auditorías y en la implementación. La distinción correcta es que existen **dos niveles de control de red** que operan en capas diferentes:

1. **BitMask (Fast-Path):** indica si el *rol del usuario* tiene la *capacidad potencial* de usar internet externo o VPN. Es un atributo del rol, evaluado en < 0.5ns.
2. **Policy/External-Path:** evalúa si el *contexto actual de red* (IP real, CIDR, protocolo, rate limit) satisface la política. Lo ejecuta Kong y Calico sobre la solicitud concreta.

**Solución — Corrección de la tabla D7:**

```
| **Método**  | **Fast-Path (bits 11-12) + Policy-Path (network policy) + External-Path (Kong)** |
| **Bits**    | 11-12 del u64: CAPACITY bits (¿tiene el rol permiso potencial de red externa/VPN?) |
| **Evalúa**  | BitMask: capacidad del rol (cada request, < 0.5ns).                              |
|             | Policy/External: contexto real de red (IP, CIDR, protocolo, rate limit) en Kong.  |
| **Implementación** | Fase 1 — BitMask: `mask.has(NETWORK_EXTERNAL)` → ¿puede siquiera intentarlo?    |
|             | Fase 2 — Kong Plugin: `NetworkEvaluator::evaluate(ip, port, protocol, tenant_id)` |
|             | → ¿IP en rango autorizado? → ¿VPN requerida? → ¿rate limit excedido?             |
```

Esta corrección alinea D7 con el patrón de D3 (FINANCIAL_APPROVE como capacity bit + Policy-Path para el límite numérico).

---

### D8 — DOMINIO DE CONTEXTO

**Estado:** ✅ Correcto. Un gap de alineación entre subsistemas.

**Observación — Desincronización de TTL:** Si el TTL del `ctx:{id}` en Redis DB1 es mayor que el `inactivity_timeout` definido en D9, un usuario cuya sesión de credenciales expiró puede seguir pasando la verificación de ctx_id en Kong. Esto crea una ventana donde el PEP (Kong) considera válida una sesión que el autenticador (Keycloak) ya invalidó. Es el mismo problema descrito por Redis en su análisis de vulnerabilidades de JWT: una vez emitido el token, sigue siendo válido en el punto de validación hasta que el estado expira explícitamente.

**Solución:** Establecer como regla normativa en D8 y D9:

```
REGLA SBOS-CTX-TTL-001 (normativa):
  Redis TTL de ctx:{id} ≤ Keycloak session inactivity_timeout (D9)

Implementación:
  Al crear el ctx_id, calcular TTL = MIN(configured_ctx_ttl, kc_session_remaining_seconds)
  Al renovar la sesión en Keycloak, extender el TTL del ctx en Redis proporcionalmente.
  Al revocar sesión en Keycloak (logout/force-expire), DELETE ctx:{id} de Redis inmediatamente
  via Keycloak Event Listener → pub/sub → bAuth invalidation endpoint.
```

Este patrón es el recomendado por OWASP para sesiones Redis: el estado de Redis debe ser el canal de revocación inmediata, no solo de caché de lookup.

---

### D9 — DOMINIO DE CREDENCIALES

**Estado:** ✅ Correcto. Una corrección de nomenclatura y una actualización de política.

**Corrección de nomenclatura:** El documento cita "NIST SP 800-63B Rev.4". La publicación final de 2024 se denomina formalmente **NIST SP 800-63B-4** (no "Rev.4"). El cambio es menor pero es relevante en referencias formales de auditoría — "Rev.4" puede confundirse con la revisión 4 de la serie anterior.

**Solución:** Reemplazar todas las ocurrencias de "NIST SP 800-63B Rev.4" por "NIST SP 800-63B-4 (2024)".

**Actualización de política de rotación:** NIST SP 800-63B-4 §3.1.1 introduce dos cambios normativos relevantes:

1. **Elimina** el requisito de rotación periódica de passwords (antes era práctica recomendada cada 90 días). Las passwords ahora se rotan SOLO cuando hay evidencia de compromiso.
2. **Eleva a SHALL** (normativo) el screening de passwords contra listas de credenciales comprometidas (HIBP o equivalente).

Si `bos_credential_policy` tiene una política de rotación periódica configurada por default, esta debe revisarse para alinearse con NIST 800-63B-4.

**Solución — Política recomendada:**

```yaml
# bos_credential_policy defaults alineados con NIST SP 800-63B-4 (2024)
password_rotation:
  periodic_forced: false           # NIST 800-63B-4: NO rotation periódica sin causa
  on_compromise_detection: true    # NIST 800-63B-4 §3.1.1: SHALL rotate on compromise
  
hibp_screening:
  enabled: true                    # NIST 800-63B-4 §3.1.1: SHALL check against breached lists
  check_on_set: true
  check_on_login_if_flagged: true
```

---

### D10 — DOMINIO DE DELEGACIÓN

**Estado:** ✅ Correcto. Un ajuste operacional recomendado.

**Refuerzo normativo:** El patrón `delegated_mask = original_mask AND role_mask` implementa correctamente el principio de **Least Privilege** de NIST SP 800-53 Rev.5 Control AC-6: "Employ the principle of least privilege, allowing only authorized accesses for users [...] that are necessary to accomplish assigned organizational tasks." La operación AND garantiza matemáticamente que ninguna delegación puede escalar privilegios por encima del delegante.

**Observación operacional — Ventana de 60 segundos:** El cron de 60 segundos para auto-revocación introduce una ventana máxima de 60 segundos donde un delegado puede operar después de `valid_until`. Para delegaciones que incluyen bits de D2 (acceso físico a zonas restringidas) o D3 (FINANCIAL_APPROVE), esta ventana puede ser inaceptable en contextos de alta criticidad.

**Solución:** Implementar revocación event-driven complementaria al cron para delegaciones que cruzan umbrales de criticidad:

```go
// Al crear delegación, clasificar criticidad
func classifyDelegation(mask uint64) DelegationCriticality {
    criticalBits := []int{6, 7, 8, 14, 15} // DOOR_ZONE_C, FINANCIAL_APPROVE, FINANCIAL_CREATE
    for _, bit := range criticalBits {
        if mask & (1 << bit) != 0 {
            return CriticalityHigh
        }
    }
    return CriticalityNormal
}

// Política de revocación por criticidad
// CriticalityHigh:   revocación event-driven via Redis pub/sub (latencia < 1s)
// CriticalityNormal: cron cada 60s (comportamiento actual)
```

Esta clasificación debe documentarse en `bos_delegation_log.criticality` y aplicarse en el evaluador de delegaciones.

---

### D11 — DOMINIO DE AUDITORÍA

**Estado:** ✅ Correcto. Un gap de seguridad en el modelo de roles PostgreSQL.

**Observación — Integridad del WORM:** El documento establece "REVOKE UPDATE/DELETE a nivel BD" sobre `bauth_audit_events`. Sin embargo, si el role que hace el REVOKE es el mismo que posee (owns) la tabla, puede re-otorgarse los privilegios en cualquier momento — incluso involuntariamente vía SQL injection. Como documenta EnterpriseDB en su análisis de auditoría PostgreSQL: "el owner puede hacer `GRANT ALL ON t TO u` [restituyendo sus propios privilegios], defeating the whole privilege system."

**Solución — Modelo de roles para WORM garantizado en PostgreSQL:**

```sql
-- 1. Role de escritura de auditoría: SOLO INSERT, sin DDL, sin DELETE, sin UPDATE
CREATE ROLE bauth_audit_writer NOLOGIN NOINHERIT;
GRANT INSERT ON bauth_audit_events TO bauth_audit_writer;
-- No se otorga SELECT, UPDATE, DELETE, ni privilegios de schema

-- 2. Role de lectura de auditoría: SOLO SELECT (para Loki, Wazuh, queries forenses)
CREATE ROLE bauth_audit_reader NOLOGIN NOINHERIT;
GRANT SELECT ON bauth_audit_events TO bauth_audit_reader;

-- 3. El owner de la tabla debe ser un role administrativo que NO sea usado por la aplicación
-- La aplicación bAuth usa bauth_audit_writer; NUNCA el owner.

-- 4. Habilitar Row-Level Security para que bauth_audit_writer no pueda leer lo que escribe
ALTER TABLE bauth_audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE bauth_audit_events FORCE ROW LEVEL SECURITY;
CREATE POLICY audit_insert_only ON bauth_audit_events
    FOR INSERT TO bauth_audit_writer WITH CHECK (true);
-- Sin política SELECT para bauth_audit_writer = no puede leer sus propios inserts

-- 5. pgAudit para registrar cualquier intento de DDL sobre la tabla
-- (alerta si alguien intenta ALTER TABLE, DROP TABLE, o CREATE INDEX sobre audit_events)
ALTER SYSTEM SET pgaudit.log = 'DDL, ROLE';
```

Con este modelo, la aplicación bAuth opera exclusivamente con `bauth_audit_writer` (solo INSERT). Cualquier intento de UPDATE, DELETE, o DDL sobre `bauth_audit_events` falla en el nivel de permisos PostgreSQL y es registrado por pgAudit — independientemente de qué usuario de aplicación esté comprometido.

**Estándar adicional:** **PCI DSS 4.0 Req.10.3.2** requiere que los logs de auditoría estén protegidos contra modificación no autorizada. Este modelo de roles cumple con ese requisito de forma verificable.

---

## SECCIÓN 3 — OBSERVACIONES TRANSVERSALES

### OBS-01 — Terminología XACML ausente en el diagrama de Sección 3

El diagrama de bloques de la Sección 3 es funcionalmente correcto pero no usa terminología estándar, lo que dificulta la comunicación con auditores externos.

**Solución:** Agregar al pie del diagrama una tabla de equivalencias:

```
EQUIVALENCIA DE TERMINOLOGÍA
  bAuth Evaluators      →  XACML PIP (Policy Information Point)
  Kong Plugin SBOS      →  XACML PEP (Policy Enforcement Point) — capa HTTP
  Calico NetworkPolicy  →  XACML PEP — capa red
  bAuth Decision Engine →  XACML PDP (Policy Decision Point)
  bos_rol_template      →  XACML PAP/PRP (Policy Administration / Retrieval Point)
```

---

### OBS-02 — Dependencia TTL Redis (D8) ↔ Credential timeout (D9) no está documentada

Esta dependencia es una invariante del sistema que, si se viola, crea una ventana de seguridad real. Debe estar documentada como regla normativa cross-domain.

**Solución:** Agregar una sección de "Invariantes Cross-Domain" al documento con:

```
INVARIANTE SBOS-XDOM-001 (normativa):
  Redis TTL(ctx:{id}) ≤ Keycloak inactivity_timeout
  
  Violación: Un ctx_id en Redis puede sobrevivir a la sesión KC que lo originó,
  permitiendo que Kong acepte requests de una sesión ya revocada.
  
  Enforcement: Al crear ctx_id, TTL = MIN(ctx_configured_ttl, kc_remaining_seconds).
  Al revocar sesión KC, publicar evento en canal Redis 'sbos:session:revoked'
  → suscriptor elimina ctx:{id} inmediatamente.
```

---

### OBS-03 — Marco regulatorio boliviano incompleto en D5 y D9

El documento cita RGPD (regulación europea) para protección de datos biométricos pero no cita el marco boliviano aplicable, que es la fuente regulatoria primaria para tenants bolivianos.

**Solución:** Agregar a los estándares de D5 y D9:

```
| **Regulación Bolivia** | Ley 164/2011 (TIC) Arts. 54-56 — datos personales en sistemas de información.
|                        | Ley 45/2010 (Contra el Racismo) — protege datos de identidad étnica/biométrica.
|                        | Constitución Política del Estado, Art. 130 — Acción de Protección de Privacidad
|                        | (equivalente funcional al right-to-erasure del RGPD Art.17). |
```

---

## SECCIÓN 4 — TABLA DE CONFORMIDAD ACTUALIZADA

| Dominio | Estándares originales | Correcciones / Adiciones |
|---|---|---|
| D1 — Lógico | XACML 3.0, NIST RBAC §4 | Etiquetar "ZRB 2024" como [SBOS-INTERNO]; agregar NIST SP 800-162 |
| D2 — Físico | BS 5979:2007, IEC 60839-11-5, CPTED | Agregar EN 60839-11-1:2013, ANSI/SIA AC-01-2010 |
| D3 — Financiero | SOX §302/§404, COSO, PCI DSS 4.0, ISO 27001 A.5.3 | Definir Conflict Matrix como artefacto normativo; agregar ISACA COBIT 2019 BAI09 |
| D4 — Temporal | GTRBAC, ISO 8601, LGT Bolivia | Agregar cita académica formal de GTRBAC (Joshi et al., ACM TISSEC 2005) |
| D5 — Biométrico | NIST SP 800-63B AAL3, RGPD Art.9, ISO/IEC 30107-3, FIDO2 | Actualizar a NIST SP 800-63B-4 (2024); agregar ISO/IEC 19795-1:2021 y 19795-10:2024; Ley 164 Bolivia |
| D6 — Geoespacial | NIST SP 800-207, SBOS-044, ISO 3166 | Corregir umbral a 900 km/h configurable; agregar CISA ZT Maturity Model v2.0 (2023) |
| D7 — Red | SBOS-054, NIST SP 800-207, NSA/CISA K8s, CIS Benchmark | **Corregir inconsistencia BitMask**: agregar descripción de Fast-Path (bits 11-12 = capacity) + Policy/External (context) |
| D8 — Contexto | SBOS-049, NIST SP 800-207, W3C Trace Context, OpenTelemetry | Agregar Invariante TTL Redis ↔ KC; referencia OWASP Session Management Cheat Sheet |
| D9 — Credenciales | NIST SP 800-63B Rev.4, NIST SP 800-57, OWASP ASVS v5.0 | **Corregir a NIST SP 800-63B-4 (2024)**; actualizar política de rotación; Ley 164 Bolivia |
| D10 — Delegación | NIST AC-2, BAUTH-100 §15 | Agregar NIST SP 800-53 Rev.5 AC-6; revocación event-driven para delegaciones críticas |
| D11 — Auditoría | ISO 27001 A.8.15, PCI DSS Req.10, SOX §404 | Agregar role `bauth_audit_writer` con solo INSERT + RLS; pgAudit para DDL; PCI DSS 4.0 Req.10.3.2 |

---

## SECCIÓN 5 — PLAN DE ACCIÓN PRIORIZADO

| Prioridad | ID | Acción | Dominio | Esfuerzo |
|---|---|---|---|---|
| **CRÍTICA** | A-01 | Definir y versionar el SoD Conflict Matrix como tabla `bos_sod_conflict_matrix` | D3 | Alto |
| **CRÍTICA** | A-02 | Corregir inconsistencia D7: tabla y BitMask deben describir el mismo modelo (capacity bits + context eval) | D7 | Bajo |
| **ALTA** | A-03 | Actualizar nomenclatura "NIST SP 800-63B Rev.4" → "NIST SP 800-63B-4 (2024)" en todo el documento | D9 | Trivial |
| **ALTA** | A-04 | Implementar role `bauth_audit_writer` (solo INSERT) + RLS sobre `bauth_audit_events` | D11 | Medio |
| **ALTA** | A-05 | Documentar Invariante SBOS-XDOM-001: TTL Redis ≤ KC inactivity_timeout + revocación event-driven | D8/D9 | Medio |
| **MEDIA** | A-06 | Corregir umbral viaje imposible a 900 km/h, configurable por tenant | D6 | Bajo |
| **MEDIA** | A-07 | Agregar política de revocación event-driven para delegaciones de bits críticos (D2/D3) | D10 | Medio |
| **MEDIA** | A-08 | Agregar tabla de equivalencia bAuth ↔ XACML PEP/PDP/PIP al diagrama de Sección 3 | Transversal | Trivial |
| **BAJA** | A-09 | Agregar nota normativa AAL3: biometría = unlock de factor hardware, no factor independiente | D5 | Trivial |
| **BAJA** | A-10 | Agregar Ley 164 Bolivia como marco regulatorio primario en D5 y D9 | D5/D9 | Trivial |
| **BAJA** | A-11 | Etiquetar "ZRB 2024" como [SBOS-INTERNO]; agregar NIST SP 800-162 en D1 | D1 | Trivial |

---

## CONCLUSIÓN

El documento **SBOS-BAUTH-DOMAIN-CONTROL-METHODOLOGY v1.0** es sólido arquitectónicamente. Las tres capas de control (Fast-Path/Policy/External) están respaldadas por XACML 3.0, NIST SP 800-207, y los precedentes de Linux capabilities. Los 11 dominios están correctamente mapeados.

Los dos problemas que requieren corrección antes de usar el documento como referencia de auditoría son:

1. **A-01 (D3):** El Conflict Matrix de SoD es un artefacto exigible bajo SOX §404. Su ausencia es un gap de control documentable por auditores externos.
2. **A-02 (D7):** La inconsistencia entre la tabla del dominio ("No usa BitMask") y la Sección 4 (bits 11-12 definidos) creará confusión en implementación y auditoría. La solución es de bajo esfuerzo.

Los demás ítems son actualizaciones de estándares, ajustes de parámetros, y refuerzos de profundidad — ninguno invalida el diseño existente.

---

*Validación producida con evidencia de estándares internacionales: OASIS XACML 3.0, NIST SP 800-63B-4, NIST SP 800-53 Rev.5, NIST SP 800-207, SOX §302/§404, PCI DSS 4.0, ISO/IEC 27001:2022, ISO/IEC 30107-3, IEC 60839-11-5, pgAudit PostgreSQL, OWASP ASVS v5.0*  
*SKULL · SBOS · SBOS-BAUTH-DOMAIN-CONTROL-VALIDATION v1.1 · Junio 2026*
