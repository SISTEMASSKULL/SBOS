# A.66 — Gaps de Nombres y Arquitectura DDL · Decisiones Pendientes

**Versión:** 1.0  
**Fecha:** 2026-07-19  
**Estado:** PENDIENTE DE RESPUESTA — responder sección por sección  
**Contexto:** Estamos alineando los manuales 1.09 (Roles), 1.13 (Motor de Versionado) y el A.65
con la arquitectura actual. Este documento lista las decisiones que solo el humano puede tomar.

---

## Cómo responder

Después de cada pregunta hay un campo `> **Respuesta:**` — escribe tu decisión ahí.  
Responde una por una. Cuando hayas respondido todas, el agente actualiza los manuales.

---

## BLOQUE 1 — Nombres canónicos de tablas

### P-01 — Nombres en la sección ROLES de A.65

El A.65 muestra en cada fila dos nombres con la notación `nombre<br>↳ alternativo`.  
No está claro cuál de los dos es el canónico que quedará en el DDL real.

**Tablas afectadas:**

| T | Nombre principal | Nombre ↳ (alternativo) | Tipo |
|---|---|---|---|
| T-040 | `bauth.idn_role_type` | `bauth.idn_roles_rol_type` | [N] nueva |
| T-041 | `bauth.idn_role_template` | `bauth.idn_roles_rol_hierarchical` | [K] existente |
| T-042 | `bauth.idn_tier_policy` | `bauth.idn_roles_rol_tier` | [K] existente |
| T-063 | `bauth.idn_role_closure` | `bauth.idn_roles_rol_closure` | [K] existente |
| T-162 | `bauth.idn_roles_templates` | `bauth.idn_roles_template` (sin "s") | [N] nueva |

**Opciones:**

- **A)** Los nombres principales son los canónicos (`idn_role_template`, `idn_tier_policy`, etc.).  
  Los `↳` son alternativas descartadas. Los manuales 1.09 y 1.13 ya están correctos en este aspecto.

- **B)** Los nombres `↳` son los canónicos (nombres más descriptivos con prefijo `idn_roles_`).  
  Los manuales deben renombrarse para usar esos nombres.

- **C)** Decidir caso por caso (indica cuál nombre queda para cada tabla).

> **Respuesta P-01:**

- A: Los nombres de la primera linea son los actuales
   Los nombres de la segunda linea son los anombres por los cuales se reemplazara para evitar confuciones.
 - El primer eras nombre inicial que causa confusiones por eso el nombre de la segunda linea sera la nueva y vigente se lo puso asi para corregir en todos los docuemnto y en el codigo existente y nohaya errores.
- B : Si hay que corregir en la docuementacion y en el codigo existente con esos nombres ya definidos
- C : Esa sera l forma el T-162 `bauth.idn_roles_template` se llama role template es por que es solo un template para todos los roles: a esta tabla hay qeu trasladra toda la informacion que ahora esta contenida en : opt/skull/orquestador/proyectos/SBOS/BauthAgent/src/desktop/lib/datos/rol_template_datos.dart
- Lee todo el contenido de opt/skull/orquestador/proyectos/SBOS/BauthAgent/src/desktop/lib/datos/rol_template_datos.dart: despues de leer ya sabes como se contiene la informacion y sabes que esta indformacion se almacenara en `bauth.idn_roles_template` necesitamos una tabla para el histroial de esta tabla para preservar la auditoria y a trazabilidad de cualquier modificacion/eliminacion/etc en sus propiedades, quien, como, cuando, porque y para qeu se cambio esa propiedad desde donde y cuando se realizo la operacion.

---

### P-02 — Nombres en la sección VERSIONADO de A.65 (tablas MVU)

El manual 1.13 usa el prefijo `ver_` como convención de subsistema (igual que `aud_` para auditoría,
`ath_` para autenticación, `cfg_` para configuración). A.65 propone alternativas con prefijo `idn_`.

| T | Nombre en manual 1.13 | Nombre ↳ en A.65 |
|---|---|---|
| T-152 | `bauth.ver_history` | `bauth.idn_rol_hierarchical_ver_history` |
| T-153 | `bauth.ver_proposal` | `bauth.idn_roles_rol_ver_proposal` |
| T-154 | `bauth.ver_retention_schedule` | `bauth.idn_roles_rol_ver_retention_schedule` |
| T-155 | `bauth.ver_template_changelog` | `bauth.idn_roles_template_ver_changelog` |

**Opciones:**

- **A)** Los nombres del manual 1.13 son los canónicos (`ver_history`, `ver_proposal`, etc.).  
  El prefijo `ver_` es la convención del subsistema — coherente con `aud_`, `ath_`, `cfg_`.  
  Los `↳` del A.65 se eliminan.

- **B)** Los nombres `↳` del A.65 son los canónicos.  
  El manual 1.13 debe actualizarse para usar los nombres `idn_*`.

> **Respuesta P-02:**

- El mismo caso de la pregunta P1
---

## BLOQUE 2 — Arquitectura del campo `template jsonb` en `idn_role_template`

### P-03 — ¿Qué contiene el campo `template jsonb` después de la separación QUIÉN/QUÉ?

Esta es la decisión arquitectónica más importante de este bloque.

**Situación actual:**

El manual 1.09 §4.3 documenta `idn_role_template` con el campo `template jsonb NOT NULL` que
contiene los **14 bloques B1-B14** completos (permisos, SoD, políticas, delegación, etc.).

El A.65 v1.5 dice:

> `idn_role_template` = **el QUIÉN** — "jerarquía de los 548 roles con campos B1: id, parent_id,
> tier, status, name, metadata, version, audit"

> `idn_roles_templates` (T-162) = **el QUÉ PUEDE** — "árbol jerárquico de políticas, cada fila
> es un nodo (dominio, policy_set, policy, rule, atom, obligation, property)"

Esto implica que los bloques B2-B14 del contrato (permisos, dominio físico, finanzas, SoD,
delegación, etc.) pasarían a vivir como nodos en el árbol T-162, **no** como JSONB en
`idn_role_template`.

**Opciones:**

- **A) Eliminar el `template jsonb`:** `idn_role_template` solo tiene columnas planas del B1
  (id, role_name, tier, type_id, status, version, parent_id, y campos de control de acceso:
  loa_required, mfa_required, sod_group, etc.). El JSONB desaparece. Todo B2-B14 va al árbol T-162.

- **B) Conservar como metadatos ligeros:** `idn_role_template` mantiene el JSONB pero reducido
  a metadatos descriptivos de B1 solamente (role_template_name i18n, descripción, tags, hints de UI).
  Los bloques B2-B14 con semántica de acceso migran al árbol T-162.

- **C) Conservar completo hasta que T-162 esté aplicada:** La separación es futura.
  Mientras T-162 no esté en VPS, `idn_role_template` sigue con el `template jsonb` completo B1-B14.
  Los manuales documentan el estado transicional con la fecha de migración prevista.

> **Respuesta P-03:**

- Este tipo de interpretaciones es lo que causaba los primeros nombres de las tbalas por eso se definio el cambiar el nombre.
- El `template jsonb` tiene informacion pero de otro tipo no es la informacion de template solo son nombres de roles almacenados de forma jeraquica cumpliendo normas, la informacion de cad auno de os roles esta contenida en `bauth.idn_roles_template` si quieres revisar la informacion puedesa verlo en la VPS de prueba que esta en ambiente kubernets la DB se llama SBOS_db debes entrara como root password 12345678ubuntu

---

## BLOQUE 3 — Contenido faltante en manual 1.09

### P-04 — Documentar `idn_tier_policy` (T-042) en §4 del manual 1.09

La tabla `idn_tier_policy` existe en VPS (`[K]`) pero no tiene sección en el §4 del manual 1.09.
Contiene: tier, loa_required, mfa_methods[], session_timeout, max_sessions, step_up_allowed,
nist_aal_ref. Es la fuente de verdad de parámetros de autenticación por tier.

**Pregunta:** ¿Agrego el §4.X para `idn_tier_policy` al manual 1.09?

- **A)** Sí — agregar §4.X completo con DDL, propósito, norma.
- **B)** No — `idn_tier_policy` pertenece a un manual diferente (¿cuál?).

> **Respuesta P-04:**

- Esta tabla hay qeu analizar en el servidor por que creo que no esta almacenando la informacion que se espera se deb almaccenar y me das informe.
---

### P-05 — Documentar `idn_roles_templates` (T-162) en §4 del manual 1.09

La tabla T-162 `idn_roles_templates` (árbol de políticas) es nueva `[N]`, sin DDL en VPS.
Es la tabla más importante del sistema de roles pero no tiene sección en ningún manual.

**Pregunta:** ¿Dónde vive la documentación del árbol T-162?

- **A)** En el §4 de 1.09 (Roles) — es parte del sistema de roles.
- **B)** En un manual nuevo (ej. `1.09b_MANUAL-ARBOL-POLITICAS-v1.0.md`) — su complejidad lo justifica.
- **C)** En el manual 2.14 (Composición del Árbol) — ya existe y cubre el árbol.

> **Respuesta P-05:**

- Si es justamenete eso pero ya no se trara solamente de politicas se trata de todas las configuraciones desde la identidad, dominios, bloques politicas rules y atomos, todoa la informacion esta contenida ahi este arbol permite generar tdos los roles con una filtracion adecuada a travez de las propiedades SET, UNSET, pero es toda la informacion genral del sistema de autenticacion, para este punto ya debrias haber analizado la informacion ya recolectada y estructurada.
---

### P-06 — Actualizar §11.3 del manual 1.09 (handler que usa tabla superada)

El pseudocódigo del handler en 1.09 §11.3 hace `INSERT en idn_role_version_log` (paso 6).
El manual 1.13 dice que esa tabla está superada por `ver_history` del MVU.

**Pregunta:** ¿Actualizo el §11.3 para usar `ver_history`?

- **A)** Sí — actualizar el paso 6 del handler para insertar en `bauth.ver_history`
  con los campos adicionales del MVU (`blocks_touched`, `standard_ref`, `security_impact`).
- **B)** No todavía — dejar el pseudocódigo con `idn_role_version_log` y agregar solo
  una nota de evolución más visible que apunte al §11.4 (el puente hacia 1.13).
- **C)** Marcar §11.3 como LEGACY con una advertencia en rojo y crear un §11.5 nuevo
  con el pseudocódigo correcto para cuando F2 del MVU esté aplicado.

> **Respuesta P-06:**

- Con esta reaparacion de los nombres ya estamos solucionando este problema en los mimos comentarios del inventario de tabals ya veras que esta cambiando y porque.
- Hay qeu actualizar la docuemntacion y el codigo con los nuevos nombres que es el nombre de la segunda linea.

---

## BLOQUE 4 — Estado del Motor de Versionado (1.13)

### P-07 — Estado actual de F2 del MVU

El manual 1.13 dice "NO EXISTE — madurez L1". Las tablas T-152..T-155 están en `[N]` en A.65.

**Pregunta:** ¿Cuál es el estado real del MVU hoy (2026-07-19)?

- **A)** Sigue en L1 — F2 no está aplicada. Las migraciones `bauth_45` y `bauth_46` no existen en VPS.
- **B)** F2 parcialmente aplicada — algunas tablas del MVU ya existen en VPS.
- **C)** F2 completamente aplicada — `ver_history`, `ver_proposal`, etc. ya están en VPS.

> **Respuesta P-07:**

- Ya se esta habalndo de todo esto en las preguntas y respúestas anteririores, ahora ya no es encesario ver si esxuste o no exites estamos desarrolandfo la arquitecrtura de la nueva DDl y repara todo el bAuth, la idea principal es la reparacion pero si lo que hay qeu corregir es la docuemntacion y el codigo existente por eso se eta tratando de presrvar el nombre de las tablas existentes y darles un nuevo nombre pero si no encuentras tabals en la VPS de pruebas no te extrañes puede que sea una nueva tabal que necesita implementarse.

---

## BLOQUE 5 — Identidad (manual 1.06)

### P-08 — UUID en `idn_identidad_entidad`

El DDL de `idn_identidad_entidad` en el manual 1.06 usa `gen_random_uuid()` para el PK,
pero la convención del proyecto es `uuidv7()` (time-ordered, ya en producción en `idn_role_template`).

**Pregunta:** ¿Corrijo `gen_random_uuid()` → `uuidv7()` en el DDL del manual 1.06?

- **A)** Sí — corregir. La convención `uuidv7()` es estándar en todo el proyecto.
- **B)** No — mantener `gen_random_uuid()` por razón específica (indica cuál).

> **Respuesta P-08:**

- Se debe respetra las convenciones, punto por eso son convenciones.

---

## Resumen de respuestas pendientes

| Pregunta | Tema | Estado |
|----------|------|--------|
| P-01 | Nombres canónicos sección ROLES en A.65 | ✅ RESPONDIDO |
| P-02 | Nombres canónicos tablas MVU en A.65 | ✅ RESPONDIDO |
| P-03 | ¿Qué queda en `template jsonb`? | ✅ RESPONDIDO |
| P-04 | Documentar `idn_tier_policy` en 1.09 | ✅ RESPONDIDO |
| P-05 | Dónde vive la doc de T-162 | ✅ RESPONDIDO |
| P-06 | Actualizar §11.3 handler con `ver_history` | ✅ RESPONDIDO |
| P-07 | Estado actual del MVU F2 | ✅ RESPONDIDO |
| P-08 | `gen_random_uuid()` → `uuidv7()` en 1.06 | ✅ RESPONDIDO |

---

## INFORME DEL AGENTE — Ejecución post-decisiones

**Fecha de ejecución:** 2026-07-20  
**Agente:** bauth-developer  
**Fuentes consultadas:** VPS `root@13.140.128.230`, PostgreSQL 18.4 K8s puerto 15432, DB `SBOS_db`, `rol_template_datos.dart` (2437 líneas completas)

---

### I. MAPA DE NOMBRES CANÓNICOS DEFINITIVO

Todas las tablas a continuación deben corregirse en documentación **y** en código fuente. El nombre de la primera columna es el nombre actual en VPS (legacy). El nombre de la segunda columna es el nombre nuevo canónico que reemplaza al legacy en todos los documentos y en el código.

| T | Nombre legacy (VPS hoy) | Nombre canónico nuevo | Tipo | Acción |
|---|---|---|---|---|
| T-040 | `bauth.idn_role_type` | `bauth.idn_roles_rol_type` | [K] existente | RENOMBRAR |
| T-041 | `bauth.idn_role_template` | `bauth.idn_roles_rol_hierarchical` | [K] existente | RENOMBRAR |
| T-042 | `bauth.idn_tier_policy` | `bauth.idn_roles_rol_tier` | [K] existente | RENOMBRAR |
| T-063 | `bauth.idn_role_closure` | `bauth.idn_roles_rol_closure` | [K] existente | RENOMBRAR |
| T-162 | — no existe — | `bauth.idn_roles_template` | [N] nueva | CREAR |
| T-152 | — no existe — | `bauth.idn_rol_hierarchical_ver_history` | [N] nueva | CREAR |
| T-153 | — no existe — | `bauth.idn_roles_rol_ver_proposal` | [N] nueva | CREAR |
| T-154 | — no existe — | `bauth.idn_roles_rol_ver_retention_schedule` | [N] nueva | CREAR |
| T-155 | — no existe — | `bauth.idn_roles_template_ver_changelog` | [N] nueva | CREAR |

**Tablas MVU (T-152..T-155):** Confirmado en VPS — no existen. El MVU (F2) está en estado L1 (diseñado, sin DDL aplicado). Todas son nuevas a crear.

---

### II. ANÁLISIS VPS — `bauth.idn_tier_policy` (T-042)

**Verificado en:** VPS SBOS_db `bauth.idn_tier_policy` — 2026-07-20

#### Estructura real en VPS

```
tier (PK text) | tier_name | loa_default | mfa_default | mfa_methods[] | session_timeout_secs
max_sessions | audit_default | step_up_allowed | delegation_allowed | description | nist_aal_ref
```

**Constraints vigentes:**
- `chk_tp_tier`: solo permite SU, SYS, BIZ_N5..N1, EXT_N0, M2M, VISITANTE
- `chk_tp_loa`: loa_default entre 0 y 4
- `chk_tp_audit`: audit_default solo 'none'/'basic'/'full'

#### Contenido real (9 filas)

| tier | loa_default | mfa_default | mfa_methods | session_secs | max_sessions | step_up | delegation | nist_aal_ref |
|------|-------------|-------------|-------------|--------------|--------------|---------|------------|--------------|
| SU | 3 | true | {FIDO2,WebAuthn} | 14 400 | 0 | true | false | AAL3 |
| BIZ_N1 | 3 | true | {FIDO2,WebAuthn,TOTP} | 28 800 | 0 | true | true | AAL3 |
| BIZ_N2 | 2 | true | {WebAuthn,TOTP} | 28 800 | 3 | true | true | AAL2 |
| BIZ_N3 | 2 | true | {TOTP,WebAuthn} | 28 800 | 3 | true | true | AAL2 |
| BIZ_N4 | 2 | true | {TOTP} | 28 800 | 3 | false | false | AAL2 |
| BIZ_N5 | 2 | true | {TOTP} | 28 800 | 2 | false | false | AAL2 |
| EXT_N0 | 1 | false | {Password,Social} | 14 400 | 5 | false | false | AAL1 |
| M2M | 0 | false | {ClientCredentials,mTLS} | 86 400 | 0 | false | true | M2M |
| VISITANTE | 1 | false | {EmailOTP} | 3 600 | 1 | false | false | AAL1 |

#### Diagnóstico

**✅ CORRECTO — la tabla almacena exactamente lo esperado:** parámetros de autenticación planos por tier. No es una tabla de árbol XACML — es la fuente de valores por defecto de LoA, MFA y sesión para cada tier.

**⚠️ GAP-1 — Falta el tier `SYS`:** el `chk_tp_tier` incluye 'SYS' en la lista de valores válidos pero no hay fila para SYS en los datos. El tier Sistemas (SYS — daemons, service accounts internos) no tiene política de tier registrada.

**⚠️ GAP-2 — `max_sessions = 0` en SU y BIZ_N1 y M2M:** El valor 0 es ambiguo — no está documentado si 0 significa "sin límite" o "bloqueado". Requiere un comentario explícito de columna o un CHECK diferente (`max_sessions = -1` para ilimitado, eliminando la ambigüedad).

**⚠️ GAP-3 — `loa_default = 0` para M2M:** LoA 0 no es un nivel de garantía estándar en NIST 800-63B (AAL1-AAL3). M2M usa `ClientCredentials`/`mTLS` que corresponde a AAL1 con autenticación de cliente. Revisar si 0 es intencional o un gap de datos.

**⚠️ GAP-4 — Campos `description` y `nist_aal_ref` vacíos:** Todas las filas tienen `description = NULL` y `nist_aal_ref` solo tiene el nivel (AAL1/AAL2/AAL3/M2M) pero no la sección del estándar. Ej.: debería ser `"NIST SP 800-63B-4 §5.1.1 — AAL1"`.

**Decisión sobre nombre:** Esta tabla debe renombrarse `bauth.idn_roles_rol_tier` y documentarse en §4.X del manual 1.09 con estos hallazgos.

---

### III. ANÁLISIS VPS — `bauth.idn_role_template` (T-041) — campo `template jsonb`

**Verificado en:** VPS SBOS_db `bauth.idn_role_template` — 2026-07-20

#### Estructura real en VPS

La tabla tiene 30 columnas. Las columnas planas de identificación (B1) son:
`id (uuidv7)`, `role_name`, `tier`, `hierarchy_level`, `path_ids[]`, `status`, `loa_required`, `mfa_required`, `step_up_enabled`, `sod_group`, `max_sessions`, `session_timeout`, `audit_level`, `start_time`, `expiry_time`, `template_id`, `created_at/updated_at/created_by`, `template_version`, `scope`, `risk_level`, `review_period_days`, `role_type`, `applies_to_size`, `is_collaborative`, `role_template_name (jsonb i18n)`, `parent_id`, `type_id`.

#### Contenido real del campo `template jsonb`

```json
{
  "n": "Administrador de Infraestructura SBOS",
  "r": "S004",
  "v": "1.0.0",
  "issuer": "bauth-bootstrap",
  "domains": ["D02"],
  "sync_error": null,
  "sync_status": "PENDING",
  "last_sync_at": null,
  "sam128_logical": null,
  "sam128_physical": null,
  "sam128_financial": null,
  "sam128_governance": null,
  "rol_bitmask_base64": ""
}
```

#### Diagnóstico

El campo `template jsonb` **NO contiene los 14 bloques B1-B14** (la confusión estaba en el manual 1.09 que documentaba erróneamente su contenido). Contiene exclusivamente:

| Campo | Significado | Estado |
|-------|-------------|--------|
| `n` | Nombre largo del rol | Poblado |
| `r` | Código de referencia | Poblado |
| `v` | Versión | Poblado |
| `issuer` | Quién creó el seed | Poblado |
| `domains[]` | Dominios D0-D13 activos para el rol | Poblado (solo D02 en bootstrap) |
| `sync_status` | Estado del motor de sincronización | PENDING en todos |
| `last_sync_at` | Timestamp del último sync | null en todos |
| `sync_error` | Error de sincronización | null en todos |
| `sam128_logical/physical/financial/governance` | SAM-128 cuadruplas | null — no calculado |
| `rol_bitmask_base64` | BitMask 64-bit del rol | vacío — no calculado |

**Conclusión:** El campo `template jsonb` es un **registro de estado del motor de sincronización + metadatos de bootstrap**, no un árbol de políticas. El usuario lo describió correctamente: "nombres de roles almacenados de forma jerárquica cumpliendo normas". La información de políticas vive en `bauth.idn_roles_template` (T-162) que no existe aún.

**⚠️ GAP-5 — `sync_status = 'PENDING'` en todos los roles:** El motor de sincronización nunca ha corrido. Ningún rol tiene su SAM-128 calculado ni su BitMask generado. Esto es un gap de implementación crítico del reconcile loop.

**⚠️ GAP-6 — `domains = ["D02"]` en roles de bootstrap:** Todos los roles de bootstrap solo tienen D02 asignado. Los dominios D0-D13 reales deben asignarse cuando se pobla `idn_roles_template`.

---

### IV. ANÁLISIS COMPLETO DEL ÁRBOL `rol_template_datos.dart`

**Archivo:** `src/desktop/lib/datos/rol_template_datos.dart` (2437 líneas — leído completo)

#### Dominios del árbol (estructura canónica)

| Dominio | Clave | Bloque(s) | Propósito |
|---------|-------|-----------|-----------|
| D98 | `D98 · SETS DE ROLES` | — | 6 sets de roles: financieros_tier2, aprobadores_financieros, auditores_externos, vendedores, gerentes_ventas, atencion_clientes |
| D0 | `D0 · IDENTIDAD` | B1 (identificación), B3 (aprobación) | Metadata del rol + workflow de aprobación |
| D1 | `D1 · ACCESO LÓGICO` | B4 (métodos auth), B6 (zonas negocio), B7 (privilegios app 5 capas) | Todo el acceso digital |
| D2 | `D2 · ACCESO FÍSICO` | B5 (dominio físico) | Hardware OSDP, NFC, biométrico, zonas físicas |
| D3 | `D3 · FINANCIERO` | B8 (dominio financiero) | Límites, ventanas, SoD financiero, SIN Bolivia |
| D4 | `D4 · TEMPORAL` | B2 (vigencia y ciclo de vida) | Validity period, renovación, terminación |
| D5 | `D5 · BIOMÉTRICO` | B5 (biometric enrollment) | Enrolamiento ISO 30107-3, FMR, liveness |
| D6 | `D6 · GEOESPACIAL` | B15 (geospatial policy) | Ubicaciones permitidas, VPN, GPS, velocidad |
| D7 | `D7 · RED` | B16 (network access) | Zero Trust, device compliance, mTLS, rate limit |
| D8 | `D8 · CONTEXTO/SESIÓN` | B17 (adaptive context) | Motor de riesgo, CAEP, señales contexto, step-up adaptativo |
| D9 | `D9 · CREDENCIALES` | B18 (credential lifecycle) | NIST 800-63B-4 policy, enrollment, rotación, revocación, privilege creep |
| D10 | `D10 · DELEGACIÓN` | B10 (delegación DSD), B11 (grupos RBAC1), B12 (SoD conflicts) | Reglas de delegación, grupos, conflictos |
| D11 | `D11 · AUDITORÍA` | B13 (cumplimiento) | Revisión trimestral, marcos regulatorios, change tracking |
| D12 | `D12 · BLOCKCHAIN` | B19 (blockchain access) | Besu QBFT, wallet, contratos APPEND_ONLY |
| D13 | `D13 · FIRMA DIGITAL EXTERNA` | B20 (legal signature) | ADSIB RSA-SHA256, Ley 164 Bolivia |
| D99 | `D99 · ADMINISTRATIVO GLOBAL` | B9 (SAM-128, READONLY), B14 (sync status, READONLY) | Calculados por el PrivilegeEngine — jamás editables |

**Total:** 16 dominios (D98, D0-D13, D99) + 20 bloques (B1-B20, algunos compartidos entre dominios).

#### Tipos de nodo

```
TipoNodo: dominio | bloque | objeto | lista | politica | regla | evaluacion
        | atributo | enumerado | diagnostico
```

#### Constructores hoja

| Helper | Tipo nodo | Propósito |
|--------|-----------|-----------|
| `_a(clave, valor)` | atributo | Propiedad hoja con valor fijo |
| `_en(clave, default, opciones[])` | enumerado | Propiedad con lista de opciones válidas |
| `_ev(clave, condiciones[], verbo)` | evaluacion | Condición XACML (prop + op + val + efecto) |
| `_op(operador)` | objeto | Operador: ==, !=, IN, NOT_IN, >, <, BETWEEN, SUBSET_OF, etc. |
| `_val(valor)` | objeto | Valor de comparación |
| `_ef(descripción, obl?, adv?)` | objeto | Efecto XACML: PERMIT/DENY + obligaciones |
| `_olo(tipo)` | objeto | Conector lógico: AND/OR/NOT |
| `_prop(propiedad)` | objeto | Propiedad del sujeto/recurso/entorno |
| `_algo(algoritmo)` | objeto | Combining algorithm: deny-overrides/first-applicable/aggregate-strictest |

---

### V. PROPUESTA DE DDL — `bauth.idn_roles_template` (T-162)

La tabla T-162 es el árbol jerárquico de configuración del sistema. Cada fila es un nodo. La estructura es un **árbol de adyacencia** (adjacency list) con los campos de la clase `NodoTemplate` de Dart.

```sql
-- ╔══════════════════════════════════════════════════════════╗
-- ║  T-162  bauth.idn_roles_template                        ║
-- ║  Árbol jerárquico de configuración del sistema bAuth.   ║
-- ║  Cada fila = un nodo (dominio, bloque, politica, regla, ║
-- ║  evaluacion, atributo, enumerado, etc.)                 ║
-- ║  Contenido: D98 + D0..D13 + D99 — fuente: dart SSOT    ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE TABLE bauth.idn_roles_template (
    id              uuid        NOT NULL DEFAULT uuidv7(),
    parent_id       uuid        NULL     REFERENCES bauth.idn_roles_template(id) ON DELETE CASCADE,
    clave           text        NOT NULL,
    tipo            text        NOT NULL,
    valor           text        NULL,
    help            text        NULL,
    opciones        text[]      NULL     DEFAULT '{}',
    orden           integer     NOT NULL DEFAULT 0,
    activo          boolean     NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    created_by      text        NOT NULL,
    ctx_id          text        NOT NULL,
    CONSTRAINT idn_roles_template_pkey PRIMARY KEY (id),
    CONSTRAINT chk_irt_tipo CHECK (tipo IN (
        'dominio','bloque','objeto','lista','politica',
        'regla','evaluacion','atributo','enumerado','diagnostico'
    )),
    CONSTRAINT uq_irt_clave_parent UNIQUE (parent_id, clave)
);

CREATE INDEX idx_irt_parent  ON bauth.idn_roles_template (parent_id);
CREATE INDEX idx_irt_tipo    ON bauth.idn_roles_template (tipo);
CREATE INDEX idx_irt_activo  ON bauth.idn_roles_template (activo) WHERE activo = true;
COMMENT ON TABLE bauth.idn_roles_template IS
    'Árbol de configuración del sistema bAuth. Cada fila es un nodo del árbol '
    '(dominio D0-D13 + D98 + D99, bloques, políticas, reglas, átomos). '
    'Contenido canónico en rol_template_datos.dart. '
    'READONLY para B9 y B14 (calculados por PrivilegeEngine).';
```

**Nota sobre `uq_irt_clave_parent`:** La clave de un nodo es única dentro de su padre (misma semántica que el dart). Para la raíz (parent_id IS NULL), PostgreSQL trata NULLs distintos en UNIQUE — puede haber múltiples raíces (D98, D0..D13, D99) sin conflicto.

---

### VI. PROPUESTA DE DDL — Tabla de historial de `idn_roles_template`

```sql
-- ╔══════════════════════════════════════════════════════════╗
-- ║  T-163  bauth.idn_roles_template_history                ║
-- ║  Historial WORM de cambios en el árbol de configuración.║
-- ║  Preserva: quién, cómo, cuándo, por qué, para qué,     ║
-- ║  desde dónde y cuándo se realizó la operación.          ║
-- ║  Implementa hash-chain (ORQUESTA-056 §4 · ISO A.8.15). ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE TABLE bauth.idn_roles_template_history (
    id              uuid        NOT NULL DEFAULT uuidv7(),
    nodo_id         uuid        NOT NULL,
    nodo_clave      text        NOT NULL,
    nodo_tipo       text        NOT NULL,
    operacion       text        NOT NULL,
    campo_mod       text        NULL,
    valor_anterior  text        NULL,
    valor_nuevo     text        NULL,
    razon           text        NULL,
    actor_id        text        NOT NULL,
    actor_rol       text        NOT NULL,
    ctx_id          text        NOT NULL,
    origen_ip       inet        NULL,
    origen_sistema  text        NULL,
    ts_operacion    timestamptz NOT NULL DEFAULT now(),
    hash_anterior   text        NULL,
    hash_actual     text        NOT NULL,
    CONSTRAINT idn_roles_template_history_pkey PRIMARY KEY (id),
    CONSTRAINT chk_irth_op CHECK (operacion IN ('INSERT','UPDATE','DELETE','RESTORE')),
    CONSTRAINT chk_irth_tipo CHECK (nodo_tipo IN (
        'dominio','bloque','objeto','lista','politica',
        'regla','evaluacion','atributo','enumerado','diagnostico'
    ))
);

CREATE INDEX idx_irth_nodo    ON bauth.idn_roles_template_history (nodo_id);
CREATE INDEX idx_irth_actor   ON bauth.idn_roles_template_history (actor_id);
CREATE INDEX idx_irth_ts      ON bauth.idn_roles_template_history (ts_operacion DESC);
CREATE INDEX idx_irth_ctx     ON bauth.idn_roles_template_history (ctx_id);
COMMENT ON TABLE bauth.idn_roles_template_history IS
    'Historial WORM del árbol idn_roles_template. Una fila por cambio de campo. '
    'hash_anterior + hash_actual forman la cadena de integridad (hash-chain). '
    'Retención mínima 7 años (ISO 27001 A.8.15 + SOX §404). '
    'Purga solo con aprobación CISO.';
```

**Campos de trazabilidad completa (responde P-01 extra):**

| Dimensión | Campo | Responde a |
|-----------|-------|------------|
| Quién | `actor_id`, `actor_rol` | "quien hizo el cambio" |
| Cómo | `operacion`, `campo_mod` | "cómo se realizó" |
| Cuándo | `ts_operacion` | "cuándo se hizo" |
| Por qué | `razon` | "por qué se cambió" |
| Para qué | `valor_nuevo` + contexto del nodo | "para qué efecto" |
| Desde dónde | `origen_ip`, `origen_sistema` | "desde dónde se lanzó" |
| Contexto | `ctx_id` | SBOS-049 — trazabilidad de operación |

---

### VII. ROADMAP — ACTUALIZACIONES PENDIENTES EN MANUALES

#### Manual 1.09 (Roles) — cambios requeridos

| Sección | Cambio |
|---------|--------|
| §4.1 | Renombrar `idn_role_type` → `idn_roles_rol_type` en DDL y referencias |
| §4.2 | Renombrar `idn_role_template` → `idn_roles_rol_hierarchical` en DDL y referencias |
| §4.3 | Eliminar descripción de `template jsonb` como árbol B1-B14 — documentar contenido real (sync status + SAM-128 + domains[]). Renombrar tabla. |
| §4.4 | Renombrar `idn_role_closure` → `idn_roles_rol_closure` |
| §4.5 (nuevo) | Documentar `idn_roles_rol_tier` (renombrada desde `idn_tier_policy`) con DDL real, 9 tiers, 4 GAPs identificados (SYS faltante, max_sessions=0 ambiguo, loa M2M=0, description vacía) |
| §4.6 (nuevo) | Documentar `idn_roles_template` (T-162) — árbol de configuración completo (16 dominios D98+D0-D13+D99) |
| §4.7 (nuevo) | Documentar `idn_roles_template_history` (T-163) — historial WORM |
| §11.3 | Actualizar handler: reemplazar `idn_role_version_log` → `idn_rol_hierarchical_ver_history` (nombre MVU canónico) |

#### Manual 1.13 (Motor Versionado) — cambios requeridos

| Sección | Cambio |
|---------|--------|
| Todo el documento | Renombrar `ver_history` → `idn_rol_hierarchical_ver_history` |
| Todo el documento | Renombrar `ver_proposal` → `idn_roles_rol_ver_proposal` |
| Todo el documento | Renombrar `ver_retention_schedule` → `idn_roles_rol_ver_retention_schedule` |
| Todo el documento | Renombrar `ver_template_changelog` → `idn_roles_template_ver_changelog` |
| §estado | Confirmar estado L1 — F2 no aplicada en VPS (confirmado: ninguna tabla MVU existe) |

#### Manual 1.06 (Identidad D00) — cambios requeridos

| Sección | Cambio |
|---------|--------|
| DDL `idn_identidad_entidad` | `gen_random_uuid()` → `uuidv7()` (P-08, convención obligatoria) |

---

### VIII. ESTADO DE LOS GAPS (resumen ejecutivo)

| GAP | Descripción | Severidad | Acción |
|-----|-------------|-----------|--------|
| GAP-N1 | 9 tablas con nombres legacy (idn_role_*, idn_tier_policy) | ALTO | Migración DDL + actualizar docs y código |
| GAP-N2 | 4 tablas MVU no existen en VPS | ALTO | Crear DDL bauth_45/46 |
| GAP-N3 | `idn_roles_template` (T-162) no existe — árbol de configuración completo ausente | CRÍTICO | Crear DDL nuevo (propuesta §V) |
| GAP-N4 | `idn_roles_template_history` (T-163) no existe — auditoría del árbol ausente | CRÍTICO | Crear DDL nuevo (propuesta §VI) |
| GAP-T1 | Tier SYS sin fila en `idn_tier_policy` | MEDIO | Insertar seed para SYS |
| GAP-T2 | `max_sessions = 0` ambiguo en SU/BIZ_N1/M2M | BAJO | Aclarar semántica en DDL + comment |
| GAP-T3 | `loa_default = 0` para M2M (no estándar NIST) | BAJO | Revisar si es intencional o error de seed |
| GAP-T4 | `description` y `nist_aal_ref` vacíos en `idn_tier_policy` | BAJO | Poblar en seeds |
| GAP-S1 | `sync_status = PENDING` en todos los roles | CRÍTICO | Reconcile loop no ha corrido |
| GAP-S2 | SAM-128 null + BitMask vacío en todos los roles | CRÍTICO | PrivilegeEngine no ha generado los valores |
| GAP-D1 | `domains = ["D02"]` en todos los roles de bootstrap | MEDIO | Asignar dominios reales al poblar T-162 |
| GAP-UUID | `gen_random_uuid()` en manual 1.06 | BAJO | Corregir en DDL |

---

*Informe generado el 2026-07-20 por bauth-developer — evidencia: VPS consultada directamente, dart leído completo.*

---

## INFORME AMPLIADO — Revisión código bAuth + VPS

**Fecha:** 2026-07-20 (segunda pasada)  
**Fuente:** `src/bitmask/`, `src/catalog/`, `src/db/mod.rs`, `src/server/handlers/role_template.rs`, VPS SBOS_db tablas `privilege_*`

---

### IX. ARQUITECTURA REAL DEL MOTOR BITMASK (código fuente)

La revisión del código revela que el motor BitMask está **completamente implementado y funcional** en `src/bitmask/`. La arquitectura es de dos estructuras separadas e incompatibles — confundirlas es un error de diseño grave:

| Estructura | Encoding | Propósito | Operaciones válidas |
|---|---|---|---|
| `AtomBitMask` | 64-bit label encoding | Identifica UN átomo | Solo igualdad + extraer campos |
| `RolBitMask` | N-bit one-hot | Combina permisos de un rol | OR (unión), AND (delegación), AND NOT (revocar), XOR (delta) |

#### AtomBitMask — layout de 64 bits (actualizado B48.T67)

```
Contextual (bits 63-32): [8 device_allowed][4 domain][9 app][11 group]
Logical    (bits 31-0):  [3 min_trust][2 token_binding][1 blk_anchor][2 policy][24 verb]

device_allowed: bitmap 8 categorías (MOBILE, WATCH, RING, IMPLANT, CARD, WEARABLE, IOT, CHIP)
min_trust:      0=NONE, 1=LOW, 2=MEDIUM, 3=HIGH, 4=CRITICAL
token_binding:  0=NONE, 1=DEVICE, 2=SESSION, 3=HARDWARE
blockchain_anch: 0=no, 1=anclaje Besu requerido
policy:         00=NoAplica, 01=Pendiente, 10=Aprobado, 11=Rechazado
verb:           24 bits — código de verbo dentro del grupo
```

#### Flujo completo árbol → JWT

```
idn_roles_template (árbol T-162, por crear)
    │ nodos tipo 'evaluacion' con PERMIT + verbo + recurso
    ↓ [fábrica de átomos — proceso de compilación]
bauth.privilege_atom (5808 átomos hoy)
    │ app_code + group_code + domain_code + verb_code → AtomBitMask
    │ atom_position INMUTABLE — clave del one-hot encoding
    ↓ [asignación por rol con filtrado SET/UNSET del árbol]
bauth.privilege_role_atom (72 asignaciones hoy — INCOMPLETO)
    ↓ [al arrancar: catalog::startup → CatalogContext]
AtomPositionResolver: HashMap<atom_slug → atom_position> (TTL ∞)
    ↓ [al autenticar: compute_rol_bitmask / inherit_from_parents]
RolBitMask: BitVec<u64, Lsb0> N-bit one-hot
    │ check(position) → <0.5ns — el fast-path del evaluador
    ↓ [DomainRegistry.evaluate_all()]
D8→D9→D1→D3→D2→D10→D4→D6→D7→D5→D12→D11 con cortocircuito
    ↓ [JWT con claims]
rol_bitmask_base64 (URL_SAFE_NO_PAD ~63 bytes para 500 átomos)
```

#### Orden canónico de evaluación de dominios

```
Pre-BitMask:  D8 (ctx_id en Redis) → D9 (credenciales — 9 métodos nativo)
Fast-Path:    D1 (lógico — verbo suficiente) → D3 (financiero)
              D2 (físico — OSDP hardware)
Policy-Path:  D10 (delegación AND reduction) → D4 (temporal)
External:     D6 (geoespacial) → D7 (red/Kong) → D5 (biométrico) → D12 (blockchain)
Siempre:      D11 (auditoría WORM — post-hoc, no decide)
```

D11 es el único que **siempre** registra, independientemente de si hubo cortocircuito.

---

### X. ESTADO REAL DEL MOTOR BITMASK EN VPS

**Verificado en:** VPS SBOS_db — 2026-07-20

| Tabla | Filas | Estado |
|-------|-------|--------|
| `privilege_atom` | 5 808 | Motor poblado — 5808 átomos registrados |
| `privilege_domain` | 12 | OK — 12 dominios D1-D12 |
| `privilege_verb` | 50 | ⚠️ 50 verbos (el catálogo tiene más que los 4 CRUD básicos) |
| `privilege_application` | 12 | 12 aplicaciones registradas |
| `privilege_group` | 48 | 48 grupos funcionales |
| `privilege_role` | 3 | ⚠️ Solo 3 roles en el motor (de 548 de identidad) |
| `privilege_role_atom` | 72 | ⚠️ Solo 72 asignaciones para esos 3 roles |
| `idn_role_template` | 548 | 548 roles de identidad jerárquica |
| `idn_role_closure` | 1 673 | Closure table completa |

#### GAP CRÍTICO — Sincronización motor/identidad

**El problema más grave del sistema completo:**

- `idn_role_template` tiene **548 roles** de identidad jerárquica
- `privilege_role` tiene solo **3 roles** en el motor BitMask
- **545 roles sin BitMask asignado** → ninguno puede autenticarse correctamente
- `privilege_role_atom` tiene 72 asignaciones para esos 3 roles (24 átomos/rol en promedio)
- Los 545 roles restantes tienen `sync_status = PENDING` en el campo `idn_d00`

Esto confirma lo observado en el informe inicial: el reconcile loop nunca ha corrido para sincronizar los 548 roles de identidad hacia el motor BitMask.

**Estructura de `privilege_atom` (en VPS):**

```
atom_code (PK compuesto) | app_code | group_code | domain_code | verb_code
atom_name | atom_slug | atom_position (UNIQUE, INMUTABLE) | contextual_mask | logical_mask
```

Los campos `contextual_mask` y `logical_mask` son los dos mitades del `AtomBitMask` almacenados separados para consultas SQL eficientes.

---

### XI. CORRECCIÓN ARQUITECTÓNICA — CAMPO `template` → `idn_d00`

#### El problema

El handler `src/server/handlers/role_template.rs` hoy espera que el campo `template jsonb` contenga **14 secciones** del contrato v6.0:

```
role, logical_access, physical_access, financial_limits,
temporal_schedule, biometric, geospatial, network,
context, credentials, delegation, audit,
blockchain, compliance_security
```

Pero esto es diseño **LEGACY** — antes de la separación QUIÉN/QUÉ. La revisión del código y del árbol dart confirma que:

1. Esas 14 secciones = los dominios D1-D13 del árbol → **ya viven en T-162 `idn_roles_template`**
2. El campo `template` en `idn_role_template` hoy en VPS contiene solo datos de identidad D0·B1
3. El usuario confirma: ese campo debe llamarse `idn_d00` porque almacena los datos de D0 (Identidad)

#### La corrección

**Renombrar** `template jsonb` → `idn_d00 jsonb` en `idn_role_template`.

El campo `idn_d00` almacena los datos del dominio D0·B1 específicos de cada rol:

```json
{
  "n": "Nombre largo del rol (i18n — clave para bi18n)",
  "r": "código de referencia (ej: S004, VEN-MGR-001)",
  "v": "versión del template (ej: 1.0.0)",
  "issuer": "quién creó este rol (ej: bauth-bootstrap, tenant:skull)",
  "domains": ["D01", "D03", "D08"],
  "sync_status": "PENDING | SYNCED | ERROR | DRIFT",
  "last_sync_at": "timestamp ISO 8601 | null",
  "sync_error": "descripción del error | null",
  "sam128_logical": "hex | null",
  "sam128_physical": "hex | null",
  "sam128_financial": "hex | null",
  "sam128_governance": "hex | null",
  "rol_bitmask_base64": "base64url | empty string"
}
```

El campo `domains[]` es el enlace semántico hacia T-162: indica qué dominios del árbol global aplican a este rol. El árbol filtra por SET/UNSET de propiedades para determinar qué nodos son aplicables.

#### Impacto en el código

El handler `src/server/handlers/role_template.rs` debe actualizarse:

1. **`RoleTemplateGetHandler`**: leer columna `idn_d00` (no `template`)
2. **`RoleTemplateCreateHandler`**: insertar en columna `idn_d00` — ya no valida 14 secciones; valida estructura D0·B1
3. **`RoleTemplateUpdateHandler`**: actualizar `idn_d00` — ya no usa `validate_roltemplate()`
4. El validador `src/domain/roltemplate_validator.rs` necesita una versión nueva para D0·B1

El campo `template_version` puede renombrarse a `idn_d00_version` o eliminarse (la versión vive en `idn_d00.v`).

---

### XII. RELACIÓN `idn_roles_template` → FÁBRICA DE ÁTOMOS

El árbol T-162 `idn_roles_template` es la **fuente declarativa** de permisos del sistema. El proceso para convertir el árbol en átomos es:

#### Extracción de átomos del árbol

```
Árbol T-162:
  D1 · ACCESO LÓGICO
    B7 · app_privileges
      model_access
        evaluacion: crm_contacts_read (verbo=read, resource=app.crm/contact)
          PERMIT → efecto: "can_read_contacts"
                              ↓
                   app_code(CRM) + group_code(contacts) + domain_code(1) + verb_code(ver=4)
                              ↓
                   AtomRecord → INSERT privilege_atom
                              ↓
                   atom_position (INMUTABLE) → privilege_role_atom(role_id, atom_position, allowed=true)
```

#### Filtrado SET/UNSET por rol

El árbol tiene nodos con propiedades que filtran qué átomos aplican a qué roles:

```
_a('subject', 'SET(gerentes_ventas)')  →  solo aplica a roles del set gerentes_ventas
_a('subject', 'ANY')                   →  aplica a todos los roles que tengan el dominio activo
_a('subject', 'UNSET(auditores)')      →  no aplica a roles del set auditores
```

La fábrica de átomos debe interpretar estas propiedades `subject` para determinar qué filas insertar en `privilege_role_atom`.

#### Sets de roles (D98)

El dominio D98 del árbol define 6 sets:
- `financieros_tier2` — roles BIZ_N1-N2 con permisos financieros
- `aprobadores_financieros` — roles con permisos de aprobación dual
- `auditores_externos` — roles con solo lectura y auditoría
- `vendedores` — roles del área comercial
- `gerentes_ventas` — managers del área de ventas
- `atencion_clientes` — roles de soporte y atención

Estos sets necesitan una tabla en BD. Hoy en el código la referencia es:
```
'app.bnotify/notification' + _a('subject', 'SET(gerentes_ventas)')
```
→ `bauth.privilege_role_set` almacena la membresía: qué roles pertenecen a cada set.

La tabla `privilege_role_set` existe en la referencia del código (`D98 · bauth.privilege_role_set.gerentes_ventas *(propuesta)*`) pero no fue verificada en la lista de tablas VPS.

---

### XIII. TABLA `privilege_role_set` (T-NUEVA)

```sql
-- Membresía de roles en sets semánticos (D98 del árbol).
-- Ejemplo: rol VEN-MGR-001 pertenece al set 'gerentes_ventas'.
CREATE TABLE bauth.privilege_role_set (
    id         uuid    NOT NULL DEFAULT uuidv7(),
    set_name   text    NOT NULL,
    role_id    uuid    NOT NULL REFERENCES bauth.idn_role_template(id) ON DELETE CASCADE,
    ctx_id     text    NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT privilege_role_set_pkey PRIMARY KEY (id),
    CONSTRAINT uq_prs_set_role UNIQUE (set_name, role_id)
);
CREATE INDEX idx_prs_set ON bauth.privilege_role_set (set_name);
COMMENT ON TABLE bauth.privilege_role_set IS
    'Sets semánticos de roles definidos en D98 del árbol idn_roles_template. '
    'Usados por el filtrado subject=SET(nombre) al computar privilege_role_atom.';
```

Los 6 sets del árbol son los seeds iniciales: `financieros_tier2`, `aprobadores_financieros`, `auditores_externos`, `vendedores`, `gerentes_ventas`, `atencion_clientes`.

---

### XIV. RESUMEN EJECUTIVO AMPLIADO — GAPS Y PRIORIDADES

#### Prioridad P0 — Sistema inoperable sin esto

| GAP | Descripción | Causa raíz |
|-----|-------------|------------|
| **GAP-SYNC** | 545 de 548 roles sin BitMask → no pueden autenticarse | Reconcile loop nunca corrió; `privilege_role` solo tiene 3 filas |
| **GAP-T162** | `idn_roles_template` no existe → fábrica de átomos ausente | Tabla T-162 nunca fue creada |
| **GAP-ATOMS** | Sin T-162, no se pueden generar nuevos átomos para roles nuevos | Dependencia directa de GAP-T162 |

#### Prioridad P1 — Deuda arquitectónica que bloquea evolución

| GAP | Descripción |
|-----|-------------|
| **GAP-D00** | Campo `template jsonb` nombrado incorrectamente → debe ser `idn_d00` |
| **GAP-HANDLER** | Handler `role_template.rs` valida 14 secciones obsoletas → debe validar D0·B1 |
| **GAP-NAMES** | 9 tablas con nombres legacy → actualizar docs + migración DDL |
| **GAP-SETS** | `privilege_role_set` no verificada en VPS → crear si no existe |

#### Prioridad P2 — Calidad y cumplimiento

| GAP | Descripción |
|-----|-------------|
| **GAP-SYS** | Tier SYS sin fila en `idn_tier_policy` |
| **GAP-MVU** | 4 tablas MVU no existen (L1) |
| **GAP-T163** | Historia WORM del árbol ausente |
| **GAP-UUID** | `gen_random_uuid()` en manual 1.06 |

---

---

## SECCIÓN XV — Cobertura de A.01 y A.02: ¿están todos los datos requeridos en el corpus del roles template?

**Pregunta:** ¿Todos los datos que requieren las estructuras de A.01 (RolTemplate v6.0) y A.02
(UserTemplate v6.0) están presentes dentro del árbol `idn_roles_template` (T-162 / `rol_template_datos.dart`) y los documentos que lo cubren?

**Metodología:** Se leyeron completamente A.01 (v2.2.0, 1918 líneas) y A.02 (v1.2.0, 1653 líneas).
Se extrajeron todas las estructuras de datos definidas en sus 20+23 bloques (B1–B20 de RolTemplate;
B1–B16 de UserTemplate), más las resoluciones U1–U7 y las extensiones v2.2.0/v1.2.0 de la
arquitectura D00. Se cruzaron contra el árbol `rol_template_datos.dart` (2437 líneas, 16 dominios
D98+D0-D13+D99, 20 bloques) y los manuales que A.01 respalda.

---

### XV.1 Cobertura confirmada — datos sí presentes en el árbol

Los siguientes bloques de A.01 tienen cobertura completa o sustancial en el árbol T-162:

| Bloque A.01 | Dominio en árbol | Cobertura |
|---|---|:---:|
| B4 — Dominio lógico (métodos, requiredMethods, step_up, session) | D1·B4 | ✅ completo |
| B5 — Dominio físico (zonas, biometría Argon2id, anti_passback) | D2·B5 | ✅ completo |
| B8 — Financiero (límites, schedules, SoD, facturación Bolivia SIN) | D3·B8 | ✅ completo |
| B2 — Vigencia (INDEFINITE/FIXED/PROJECT_BASED/TEMPORARY/EMERGENCY, review_date, max_renewals) | D4·B2 | ✅ completo |
| B10 — Delegación (can_delegate, max_duration, non_delegable, max_depth 2) | D10·B10 | ✅ completo |
| B11 — Grupos y jerarquías (role_hierarchy, role_groups, quorum_requirements) | D10·B11 | ✅ completo |
| B12 — SoD (incompatible_roles, incompatible_functions, REAL_TIME, DIRECT+INHERITED+DELEGATION) | D10·B12 | ✅ completo |
| B13 — Cumplimiento y auditoría (review_frequency, regulatory_frameworks PCI/RGPD/SOX, retention 7 años) | D11·B13 | ✅ completo |
| B15 — Geoespacial unificado (D6, allowed_locations, gps_attestation, financial_override) | D6·B15 | ✅ propuesto, pendiente HITL |
| B16 — Red/ZTA (D7, zero_trust, device_compliance, mTLS RFC 8705) | D7·B16 | ✅ propuesto, pendiente HITL |
| B17 — Contexto adaptativo (D8, risk_engine, CAEP 4 event types, adaptive_policies) | D8·B17 | ✅ propuesto, pendiente HITL |
| B18 — Ciclo de vida credenciales (D9, enrollment IAL, rotation, privilege_creep 90d) | D9·B18 | ✅ propuesto, pendiente HITL |
| B19 — Blockchain (D12, Besu QBFT ECDSA secp256k1, smart_contract_permissions) | D12·B19 | ✅ propuesto, pendiente HITL |
| B20 — Firma legal (D13, ADSIB RSA-SHA256, operaciones con validez jurídica Ley 164) | D13·B20 | ✅ propuesto, pendiente HITL |
| D98 — Conjuntos de roles (6 sets: financieros_tier2, aprobadores, auditores, vendedores…) | D98 | ✅ completo |
| B9/B14 — SAM-128 + Sync (READONLY, calculado) | D99·B9/B14 | ✅ estructura presente; valores sin calcular (GAP-SYNC) |

**Veredicto para los dominios de acceso (D1–D13):** el árbol cubre todos los planos de control.

---

### XV.2 Gaps encontrados — datos requeridos AUSENTES del árbol y del corpus

#### GAP-IDE-01 — `idn_identidad_entidad` NO EXISTE · P0 · BLOQUEANTE

**Requieren:** A.02 §23.1 (v1.2.0) — el usuario ES una entidad en `idn_identidad_entidad` con
`nivel='actor'`. A.01 §22.2 — el rol también es una entidad con `entidad_tipo='role'`.
En la arquitectura D00 v2.0, toda entidad del sistema (HUMAN, SERVICE, rol, dispositivo, bot)
es primero una fila en `idn_identidad_entidad`, y el UserTemplate/RolTemplate son su extensión.

**Ausencia:** la tabla `idn_identidad_entidad` no existe en el DDL actual (`idn_role_template` e
`idn_user_template` son tablas independientes sin una base común de entidad). La relación
`idn_user_template (1:1) → idn_identidad_entidad` especificada en A.02 §23.1 no está materializada.

**Impacto:** sin esta tabla, la arquitectura D00 v2.0 (actor universal) no puede implementarse.
Los átomos D00 no tienen una entidad receptora canónica. El árbol T-162 genera átomos D00
(bauth_50 los siembra) pero no hay entidad base que los reciba.

---

#### GAP-IDE-02 — `idn_identidad_atributo` NO EXISTE · P0 · BLOQUEANTE

**Requieren:**
- A.02 §22.bis: los campos 1:N del usuario (emails, teléfonos, direcciones, documentos de identidad,
  certificaciones, idiomas) **deben** materializarse en `idn_identidad_atributo`, no en el JSONB.
  El validador (`usertemplate_validator.rs`, 495 líneas) existe, pero la tabla destino no.
- A.01 §22.2: los roles tienen atributos en `idn_identidad_atributo` con `entidad_tipo='role'`
  (normas de respaldo NIST/ISO, loa_required, mfa_required, sector_code CAEB).
- A.02 §23.4: los atributos del usuario están vinculados a átomos D00 vía `atom_code`. El
  UserBitMask (OR de RolBitMask activos) determina qué atributos puede ver/editar cada usuario.

**Ausencia:** confirmada en A.02 §22.bis con evidencia directa:
> "idn_identidad_atributo NO existe en DDL (A.31 — 0 menciones)"

**Impacto:** los campos 1:N van al JSONB (contra la regla de diseño) o no se guardan. La
gobernanza de atributos vía átomos D00 (ver/editar por rol) no puede funcionar sin esta tabla.

---

#### GAP-META-03 — B1 `metadata` organizacional del ROL ausente en árbol · P1

**Requiere:** A.01 §3 (B1 `metadata`):
- `department`, `cost_center`, `region`, `territory_code`
- `job_family`, `job_level` (escala I1-I5/M1-M5/D1-D3)
- `max_subordinates`, `required_certifications[]`, `reporting_line`
- `classification` (PUBLIC/INTERNAL/CONFIDENTIAL/RESTRICTED) → ISO A.5.12

**Ausencia:** el nodo D0·B1 en el árbol T-162 tiene: `nombre`, `código`, `versión`, `issuer`,
`categoría`, `active_domains[]`, `sync_status`. Los campos organizacionales (department,
cost_center, region, classification) NO están en ningún nodo del árbol ni en la tabla
`idn_role_template` actual en VPS (que solo tiene los campos de identidad y sync).

**¿Dónde deben estar?** En columnas de `idn_roles_rol_hierarchical` (T-041 canónico) o en
`idn_identidad_atributo` con `entidad_tipo='role'` (una vez que exista — GAP-IDE-02).

---

#### GAP-FIRMA-04 — B1 `digital_signature` del contrato del rol ausente · P1

**Requiere:** A.01 §3 — cada RolTemplate tiene una firma digital que garantiza su integridad:
- `algorithm: EdDSA_Ed25519`, `post_quantum_planned: ML-DSA (FIPS 204)`
- `certificate_thumbprint`, `timestamp`, `validity (not_before, not_after)`

**Ausencia:** el árbol T-162 no tiene ningún nodo de firma del contrato. Tampoco la tabla
`idn_role_template` en VPS tiene columnas para la firma. A.01 §19.bis marca esto como
"G-B01-08 pendiente" (no resuelto).

**Conecta con:** MANUAL-FIRMA (2.04) que documenta el motor dual — pero ese motor firma
documentos/tokens, no el contrato DDL del rol en sí.

---

#### GAP-MVU-05 — `audit.change_history[]` del rol sin materialización · P1

**Requiere:** A.01 §3 — B1 `audit.change_history[]`:
```json
[{
  "version": "3.1.0", "date": "...", "changed_by": "...", "approved_by": "...",
  "changes": ["delta semántico"], "change_reason": "...", "security_impact": "LOW"
}]
```
ISO 27001 A.8.15 — retención 7 años. El contrato especifica deltas semánticos (no copias completas).

**Ausencia:** las 4 tablas del Motor de Versionado Universal (T-152..T-155) no existen en VPS
(GAP-MVU ya documentado en §XIV). Sin MVU, los cambios al contrato del rol no tienen historial
auditado. El reconcile loop detectaría DRIFT pero no podría reconstruir por qué el rol cambió.

---

#### GAP-D94-06 — Conjuntos de usuarios (D94) sin tabla · P1

**Requieren:** A.01 §22.3 y A.02 §23.2 — la arquitectura v2.0 incluye USERSET análogo a los
conjuntos de roles (D98). Ejemplos:
```
D94 · USERSET(autenticacion) → todos los actores que pueden loguearse
D94 · USERSET(RRHH)          → todos los empleados HUMAN activos
D94 · USERSET(proveedor)     → actores que venden servicios freelance
D94 · USERSET(cliente)       → actores que compran en la tienda interna
```

**Ausencia:** el árbol T-162 tiene D98 (conjuntos de roles) con nodos `_ef()` pero NO tiene
nodos D94. No existe tabla `privilege_user_set` análoga a `privilege_role_set`.

---

#### GAP-B6-07 — B6 `zones{}` sin representación declarativa unificada · P1

**Requiere:** A.01 §8 — la estructura completa de B6:
- `scope`: GLOBAL / REGIONAL / LOCAL / PERSONAL (filtro automático de datos)
- `restrictions.data_classification[]`: accesible (PUBLIC/INTERNAL/CONFIDENTIAL)
- `restrictions.pii_access` + `masking_policy` (ej.: `lastFourVisible`)
- `zone_financial.limit_tier` (0=sin ops, 1=1k, 2=10k, 3=50k, 4=200k, 5=sin límite)
- `zone_financial.sod_cannot_also` (quien crea/aprueba no audita)
- `zone_financial.requires_dual_approval_above`

**Ausencia:** el árbol tiene átomos D1 individuales (d1.zona_ventas.read, d1.zona_ventas.approve)
y átomos D3 con límites financieros, pero NO tiene la estructura declarativa de `zones{}` como
bloque unificado. El `scope` (REGIONAL genera filtro de datos automático) y el `pii_access +
masking_policy` no están en ningún nodo del árbol.

**Impacto:** sin `scope`, las record rules de Tryton (capa 5 del B7) no pueden generarse
automáticamente. Sin `pii_access`, el logging extra de RGPD no se activa.

---

#### GAP-B7-08 — B7 privilegios ERP (5 capas) sin nodos en árbol · P1

**Requiere:** A.01 §9 — el patrón declarativo de 5 capas:
- Capa 1 `model_access[]`: CRUD por modelo de datos
- Capa 2 `visible_actions[]`: menús/acciones visibles
- Capa 3 `field_restrictions[]`: campos ocultos/readonly por rol
- Capa 4 `button_rules[]`: botones con condición PYSON + SoD + step_up_loa
- Capa 5 `record_rules[]`: filtros SQL automáticos por usuario

**Bajo ADR-010:** el enforcement es nativo (BitMask + PolicyEngine). Las 5 capas son el patrón
declarativo de integración de aplicaciones del ecosistema (átomos D1 + biedata — MANUAL-APLICACIONES 1.10).

**Ausencia:** el árbol T-162 tiene los átomos D1 (verb×zona) que mapean conceptualmente a las
5 capas, pero NO tiene nodos que representen la traducción explícita: qué átomo D1 activa qué
campo oculto, qué button_rule, qué record_rule. Sin esa traducción, el motor de aplicaciones no
sabe cómo convertir un RolBitMask en restricciones concretas de UI/datos.

---

#### GAP-D0-09 — Enriquecimientos D0 de B1 ausentes (pendientes HITL) · P2

**Requieren:** A.01 §17.3-D0 — 5 campos nuevos para `metadata` del rol:
- `org_unit_id`: unidad organizacional canónica (no solo nombre de departamento)
- `tenant_id`: tenant al que pertenece el rol
- `sector_code`: código CAEB SIN (21 sectores)
- `accountability_chain`: cadena de responsabilidad hasta el CEO
- `data_owner_roles[]`: custodios de los datos que el rol maneja

**Ausencia:** marcados como "pendientes HITL" en A.01 §17.3. No están en árbol ni en tablas.
El `sector_code` CAEB es particularmente importante para la Bolivia compliance (21 sectores SIN).

---

#### GAP-ADR010-10 — `revocation_policy.channels` obsoletos en D9 del árbol · P2

**Requiere:** A.01 §17.2-B18 — canales de propagación de revocación.

**Problema:** el árbol T-162 tiene en D9·B18 `revocation_policy.channels: ["keycloak", "vault", "kong"]`.
Bajo ADR-010, Keycloak fue eliminado. El canal correcto es `["bauth_native", "vault", "kong"]`.

**Impacto:** error de configuración cuando T-162 se materialice y el reconcile loop lea los channels.

---

#### GAP-U1-11 — `identity_proofing` del usuario sin materialización · P2

**Requiere:** A.02 §19.2-U1 — sección `identity_proofing` en B1 del usuario:
```json
{
  "ial_achieved": "IAL2",
  "proofing_type": "remote_attended",
  "evidence": [{"type": "STRONG", "kind": "...", "verified_at": "..."}],
  "proofed_at": "...", "proofed_by": "...", "reproofing_due": "..."
}
```
NIST SP 800-63A. Cada evento emite un `aud_event` inalterable.

**Ausencia:** especificado en A.02 §19.2-U1 pero sin columna en `idn_user_template` ni nodo
en árbol. El árbol de roles no lo cubre directamente (es del UserTemplate), pero los nodos D9
del árbol definen el nivel de verificación requerido (`enrollment_policy.verification_level`)
— la contraparte del sujeto debe existir para que la validación funcione.

---

#### GAP-U6-12 — `legal_signature_identity` del usuario sin materialización · P2

**Requiere:** A.02 §19.2-U6 — sección `legal_signature_identity` en el sujeto:
```json
{
  "wallet_address": "0x...", "wallet_custody": "vault",
  "adsib_cert_serial": "...", "adsib_cert_expiry": "...",
  "adsib_cert_status": "VALID", "blockchain_enabled_since": "..."
}
```
Ley 164 (la firma jurídica plena la ejerce una PERSONA física). El rol define cuándo se exige
firma (A.01 B20 `legal_signature_policy`); el sujeto porta el certificado.

**Ausencia:** especificado en A.02 §19.2-U6 pero sin columna en `idn_user_template`. Los nodos
D13·B20 del árbol (ADSIB, Ley 164) definen la política del ROL — la contraparte del usuario
(quién porta el certificado) no está materializada.

---

### XV.3 Tabla resumen de gaps — A.01/A.02 vs árbol y corpus

| ID | Descripción | A.01/A.02 §ref | En árbol | En tabla | Prioridad |
|---|---|---|:---:|:---:|:---:|
| GAP-IDE-01 | `idn_identidad_entidad` no existe — base de actores D00 v2.0 | A.02 §23.1 · A.01 §22.2 | ❌ | ❌ | **P0** |
| GAP-IDE-02 | `idn_identidad_atributo` no existe — 1:N usuarios y roles | A.02 §22.bis · A.01 §22.2 | ❌ | ❌ | **P0** |
| GAP-META-03 | B1 `metadata` organizacional del rol ausente (dept, cost_center, classification…) | A.01 §3 | ❌ | ❌ | **P1** |
| GAP-FIRMA-04 | B1 `digital_signature` del contrato del rol sin materialización | A.01 §3 (G-B01-08) | ❌ | ❌ | **P1** |
| GAP-MVU-05 | `audit.change_history[]` del rol sin historial (tablas MVU no existen) | A.01 §3 · 1.13 §9.2 | ❌ | ❌ | **P1** |
| GAP-D94-06 | Conjuntos de usuarios D94 sin tabla ni nodos en árbol | A.01 §22.3 · A.02 §23.2 | ❌ | ❌ | **P1** |
| GAP-B6-07 | B6 `zones{}` sin scope/pii_access/masking_policy declarativos | A.01 §8 | ⚠️ parcial | ❌ | **P1** |
| GAP-B7-08 | B7 5 capas ERP sin traducción declarativa en árbol | A.01 §9 | ⚠️ átomos sí, capas no | ❌ | **P1** |
| GAP-D0-09 | Enriquecimientos D0: org_unit_id, tenant_id, sector_code CAEB, accountability_chain | A.01 §17.3-D0 | ❌ | ❌ | **P2 HITL** |
| GAP-ADR010-10 | Canales revocación con "keycloak" → obsoleto bajo ADR-010 | A.01 §17.2-B18 | ⚠️ incorrecto | ❌ | **P2** |
| GAP-U1-11 | `identity_proofing` (IAL1/2/3) del usuario sin materialización | A.02 §19.2-U1 | N/A rol | ❌ | **P2** |
| GAP-U6-12 | `legal_signature_identity` (wallet + cert ADSIB) del usuario sin materialización | A.02 §19.2-U6 | N/A rol | ❌ | **P2** |

Leyenda: ✅ presente · ❌ ausente · ⚠️ parcialmente cubierto · N/A = corresponde al UserTemplate, no al árbol de roles

---

### XV.4 Veredicto — resumen ejecutivo

**De los 20 bloques de A.01 (RolTemplate v6.0):**

- **12 bloques plenamente cubiertos** en el árbol T-162: los dominios de acceso D1-D13 están todos representados, incluyendo los 6 bloques nuevos B15-B20 como propuestas pendientes de HITL. Los componentes RBAC (B10-B12) y de cumplimiento (B13) están completos.
- **4 gaps en B1** (metadata organizacional, firma del contrato, historial de cambios, enriquecimientos D0) — B1 tiene cobertura parcial. Los campos de identidad básica están, pero los campos organizacionales y la firma del contrato no.
- **1 gap en B6** (structure declarativa de zonas: scope, pii_access, masking_policy) — los átomos individuales están pero el bloque unificado no.
- **1 gap en B7** (traducción 5 capas ERP) — los átomos D1 existen, la traducción declarativa a capas no.
- **2 tablas base P0** (idn_identidad_entidad, idn_identidad_atributo) — ausentes y bloqueantes.

**De los 16 bloques de A.02 (UserTemplate v6.0):**

Los datos del UserTemplate son contraparte del RolTemplate — el árbol T-162 define las POLÍTICAS del rol; el usuario porta las instancias. La cobertura del árbol sobre el UserTemplate es la correcta por diseño (el rol no replica al usuario). Los gaps del UserTemplate son:
- GAP-IDE-01/02 (tablas base — afectan a ambos contratos)
- GAP-U1-11 (identity_proofing — contraparte de D9·B18 del árbol)
- GAP-U6-12 (legal_signature_identity — contraparte de D13·B20 del árbol)

**Respuesta directa a la pregunta:** No. Faltan **dos tablas P0 bloqueantes** (`idn_identidad_entidad` e `idn_identidad_atributo`) que son la base de la arquitectura D00 v2.0 y de las que dependen tanto el UserTemplate como el RolTemplate. Además, el campo `metadata` organizacional del rol (B1), la firma del contrato (B1), el historial de versiones (MVU), los conjuntos de usuarios (D94), y la traducción declarativa de zonas (B6) y capas ERP (B7) están ausentes del árbol y del corpus actual. Los gaps P1 no bloquean la autenticación básica (el motor BitMask puede funcionar) pero bloquean la gobernanza enterprise completa (certificaciones, clasificación de datos, scope regional automático, historial de cambios auditado).

---

---

## SECCIÓN XVI — Solución: SETUSER/UNSETUSER en el árbol T-162

**Propuesta (confirmada por el humano):** extender los valores posibles de los nodos `evaluacion`
del árbol T-162 de `{SET, UNSET}` a `{SET, UNSET, SETUSER, UNSETUSER}`.

Con esto el árbol T-162 se convierte en fuente única de configuración para dos niveles:

```
SET     / UNSET     → configura el átomo para todos los usuarios del ROL
SETUSER / UNSETUSER → define el catálogo de átomos que pueden ser excepción individual de usuario
```

Los nodos `SETUSER`/`UNSETUSER` del árbol NO contienen referencias a usuarios específicos
(eso haría el árbol crecer indefinidamente). En su lugar definen QUÉ átomos son elegibles como
excepción individual. La instanciación por usuario vive en una tabla separada.

**Flujo resultante del UserBitMask:**

```
RolBitMask del rol (átomos SET)
    ↓ OR
átomos SETUSER asignados al usuario (excepciones positivas)
    ↓ AND NOT
átomos UNSETUSER asignados al usuario (excepciones negativas)
    = UserBitMask final → JWT
```

**Impacto en `resolver.rs`:** el método existente `compute_rol_bitmask(pg, role_id)` se
complementa con un nuevo `compute_user_overrides(pg, user_id)` que carga las excepciones
individuales del usuario y las aplica sobre el RolBitMask base.

**Resultado:** el árbol T-162 puede generar la configuración completa tanto de un rol (vía
`privilege_role_atom`) como de un usuario individual (vía la tabla de excepciones), sin
duplicar la lógica ni crear un árbol separado.

---

*Informe ampliado el 2026-07-20 — fuente: código src/bitmask/, src/catalog/, src/db/, handlers/, VPS privilege_* tables.*
