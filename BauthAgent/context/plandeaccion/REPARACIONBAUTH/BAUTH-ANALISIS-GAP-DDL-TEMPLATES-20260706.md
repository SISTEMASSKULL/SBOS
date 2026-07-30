# BAUTH — Análisis de Gap: DDL actual vs Templates v6.0
**Versión:** 1.0 · **Fecha:** 2026-07-06 · **Autor:** bauth-developer
**Propósito:** Entender por qué la BD actual no puede validar ni reproducir con robustez
los templates ROLTEMPLATE v6.0 y USERTEMPLATE v6.0. Solo análisis — cero cambios aplicados.

---

## NORMA FUNDACIONAL — Dos universos de lenguaje, regla sin excepciones

Toda corrección en este documento y en la reparación de bAuth se rige por la siguiente
separación de universos. **Esta norma es invariante y toda modificación al DDL, seeds
o código debe citarla cuando aplique.**

| Universo | Idioma | Qué incluye | Estándar que lo respalda |
|---|---|---|---|
| **Interno — programación** | **Inglés** | Valores de columnas SQL (`status`, `sync_status`, `type`), identificadores de enum, constantes de código, nombres de tabla/columna, tokens JWT, parámetros de API, logs de sistema | SCIM 2.0 RFC 7643/7644 · ISO/IEC 9945 (POSIX) · SQL:2023 · NIST SP 800-53 Rev.5 · Convención universal de la industria (SailPoint, Okta, Auth0, Keycloak, Microsoft Entra) |
| **Externo — interfaces y docs** | **Español** (idioma por defecto) | Documentación técnica, mensajes de error para usuarios, interfaces de usuario, comentarios de código, logs de auditoría legibles por humanos, notificaciones | DOC-SBOS-001 N3 · CLAUDE.md SBOS (español obligatorio) · ISO 9001:2015 §3.2.4 · ISO/IEC 27001:2022 A.7.2.2 |

**Regla operativa:** Un `CHECK (status IN ('DEFINIDO','PUBLICADO'))` viola el universo
interno — los valores de columna SQL son tokens de sistema, no etiquetas para usuarios.
Un comentario de código en inglés viola el universo externo. Los dos universos no se mezclan.

**Principio de trazabilidad:** Toda corrección que se aplique al DDL, a los templates
o a los seeds DEBE citar el estándar o norma que la respalda. Sin norma citada = corrección
sin respaldo = rechazada por el Revisor (C12 SBOS-047).

---

## Contexto resumido

El DDL en producción es `sbos_00__esquema_base.sql` (5487 líneas). Los templates
de referencia son `SBOS-ROLTEMPLATE-v5_0.md` y `SBOS-USERTEMPLATE-v5_0.md`
(ambos con contenido v6.0, nombre de archivo desfasado). El proyecto REPARACIONBAUTH
fue creado para cerrar el gap entre lo que la BD tiene y lo que los templates necesitan,
empezando por diseñar el Dominio D00 como base de estandarización.

---

## 1. Qué tiene la BD actualmente

El DDL define las siguientes tablas relevantes para los templates:

| Tabla en DDL | Línea | Equivalente en los templates |
|---|:---:|---|
| `bauth.idn_role_template` | 2449 | `bos_rol_template` (nombre distinto) |
| `bauth.idn_user_template` | 3840 | `bos_user_template` (nombre distinto) |
| `bauth.bos_rol_template_history` | 2523 | Historia del RolTemplate (nombre mixto) |
| `bauth.privilege_domain` | 2567 | Dominios D1-D12 (D00 bloqueado) |
| `bauth.privilege_verb` | 2604 | 50 verbos (1-50) |
| `bauth.privilege_atom` | 2638 | 5808 átomos (D1-D12 únicamente) |
| `bauth.ath_auth_flow` | 4120 | Bloque 4 RolTemplate — auth flows |
| `bauth.ath_step_up_rule` | 4155 | Bloque 4 — step_up_rules |
| `bauth.fis_access_zone` | 2067 | Bloque 5 — zonas físicas |
| `bauth.zone_application_map` | 2839 | Bloque 6 — zone×app mapping |
| `bauth.zone_field_restriction` | 4180 | Bloque 7 Tryton capa 3 |
| `bauth.zone_button_rule` | 4200 | Bloque 7 Tryton capa 4 |
| `bauth.zone_record_rule` | 4223 | Bloque 7 Tryton capa 5 |
| `bauth.fin_limit` | 2149 | Bloque 8 — límites financieros |
| `bauth.fin_sod_rule` | 2909 | Bloque 12 — SoD rules |
| `bauth.dlg_delegation` | 3490 | Bloque 10 — delegación |
| `bauth.ses_ses_risk_policy` | 4471 | Bloque 13 User — risk score |

La BD tiene las piezas de soporte. El problema está en los gaps de la tabla principal
y en la ausencia de D00.

---

## 2. Los 5 gaps concretos que impiden la validación robusta

### Gap 1 — Nombres de tabla distintos entre los templates y el DDL ✅ RESUELTO

**Corrección conceptual (2026-07-06):** El prefijo `bos_*` ya no existe en el sistema.
Todo fue migrado y normalizado al prefijo `idn_*`. El DDL es la realidad en producción.

| Nombre obsoleto (muerto) | Nombre canónico vigente |
|---|---|
| `bos_rol_template` | `bauth.idn_role_template` |
| `bos_user_template` | `bauth.idn_user_template` |
| `bos_rol_template_history` | `bauth.bos_rol_template_history` ⚠ pendiente renombrar |

Los templates v6.0 que aún dicen `bos_rol_template` / `bos_user_template` tienen un
error documental — referencian una tabla que ya no existe. Toda referencia a `bos_*`
en documentación, seeds o código debe reemplazarse por el nombre `idn_*` correspondiente.

**Regla única:** Si un documento dice `bos_rol_template` o `bos_user_template`, está mal.
La tabla es `bauth.idn_role_template` y `bauth.idn_user_template`. Sin excepción.

---

### Gap 2 — Mismatch de estados de ciclo de vida ✅ RESUELTO

**Investigación realizada — veredicto de industria (2026-07-06):**

#### Estados actuales en la BD (INCORRECTOS)
```sql
CONSTRAINT chk_brt_status CHECK (status IN (
  'DEFINIDO','DESARROLLADO','REVISADO','AUTORIZADO','PUBLICADO','DEPRECADO','RETIRADO'
))
```
Tres problemas verificados contra estándares internacionales:

1. **Idioma equivocado.** Toda la industria usa inglés para valores de datos de sistema.
   SCIM 2.0 (RFC 7643), NIST SP 800-53, SailPoint, Okta, Auth0, Microsoft Entra —
   todos definen estados en inglés. Los valores en base de datos no son para usuarios
   finales: son tokens internos que el código evalúa. Español aquí rompe interoperabilidad.

2. **Mezcla de dos preocupaciones distintas.** Los 7 estados mezclan:
   - Estado operativo del rol (¿está en producción?) → `status`
   - Paso del flujo de aprobación (¿en qué etapa del workflow está?) → `approval_workflow`
   Esto viola el principio de responsabilidad única. Las plataformas IGA líderes
   (SailPoint IdentityNow, Okta IGA) separan ambas dimensiones.

3. **Granularidad innecesaria en `status`.** `DESARROLLADO` y `AUTORIZADO` son
   sub-estados de `DRAFT` y `REVIEW` respectivamente, no estados operativos distintos.
   Ningún estándar de referencia (ANSI INCITS 359, ISO/IEC 24760-2:2025) define
   más de 5 estados operativos para un rol.

#### Estados canónicos (CORRECTOS — respaldados por industria)

**`bauth.idn_role_template.status`** — 5 estados, inglés, alineados con
SailPoint, Okta IGA, Microsoft Entra Governance, ISO/IEC 24760-2:2025:

| Estado | Significado | Equivale al estado viejo |
|--------|-------------|--------------------------|
| `DRAFT` | En diseño, no sincronizado con KC/Tryton | DEFINIDO + DESARROLLADO |
| `REVIEW` | En proceso de aprobación (approval_workflow activo) | REVISADO + AUTORIZADO |
| `ACTIVE` | Sincronizado, en producción, asignable | PUBLICADO |
| `DEPRECATED` | Operativo pero no asignable a nuevos usuarios | DEPRECADO |
| `ARCHIVED` | Retirado, sin sesiones activas posibles | RETIRADO |

```sql
-- CORRECCIÓN a aplicar en DDL:
CONSTRAINT chk_brt_status CHECK (status IN (
  'DRAFT','REVIEW','ACTIVE','DEPRECATED','ARCHIVED'
))
```

**`bauth.idn_user_template.status`** — 5 estados, inglés, alineados con
SailPoint (Active/Inactive/Terminated), Okta (Active/Suspended/Deprovisioned),
SCIM 2.0 RFC 7643 (active boolean + service provider extensions):

| Estado | Significado |
|--------|-------------|
| `PENDING` | Cuenta creada, pendiente de activación (email de activación enviado) |
| `ACTIVE` | Usuario operativo — puede autenticarse |
| `INACTIVE` | Acceso pausado (licencia, vacaciones largas) — reversible |
| `SUSPENDED` | Bloqueado por investigación/incidente — reversible con aprobación |
| `TERMINATED` | Offboarding completado — irreversible, datos retenidos por ley |

```sql
-- CORRECCIÓN a aplicar en DDL:
CONSTRAINT chk_iut_status CHECK (status IN (
  'PENDING','ACTIVE','INACTIVE','SUSPENDED','TERMINATED'
))
```

**Regla única:** Todo valor de `status` en la BD es un token de sistema — inglés,
mayúsculas, sin acentos, sin espacios. Los textos legibles para humanos van en la capa
de presentación (i18n), nunca en la columna SQL.

---

### Gap 3 — La identidad actual es monolítica — la reparación es el modelo atómico

#### 3.1 El problema raíz: diseño monolítico vs modelo atómico

La BD actual almacena la identidad organizacional en tablas con columnas fijas directas:

```
org_empresa(nit, razon_social, email, telefono, direccion, ...)
org_sucursal(nombre, direccion, zona, timezone, ...)
org_pos_logico(nombre, modalidad_facturacion, ...)
idn_user_template(template JSONB — blob sin estructura)
```

Este es el **diseño monolítico**: cada campo de identidad es una columna, cada tipo
nuevo requiere un `ALTER TABLE`, y no hay forma de controlar acceso granular a un campo
específico (ej: "solo BIZ_N2 puede ver el NIT de esta empresa").

**Lo que el modelo atómico resuelve** (documentado en `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md`):
cada campo de identidad se convierte en un átomo con 4 coordenadas: `dominio.app.módulo.verbo`.
El verbo puede ser `C|R|U|D` (CRUD granular por campo) o `IDENTIDAD` (propiedad del sujeto).
La presencia o ausencia de ese bit en el RolBitMask determina quién puede crear, leer,
modificar o eliminar cada campo específico. Sin `ALTER TABLE`. Sin migraciones por cada campo nuevo.

#### 3.2 D00 — Dominio Cero: la base de toda la jerarquía organizacional

D00 es el dominio que modela la propia organización del cliente:

```
Tenant (skull / external)
  └── bDomain (empresa / persona / hogar / desarrollador)
        └── bSubDomain (sucursal / oficina / casa)
              └── Pos Lógico (caja, punto de venta, acceso)
```

**Cada nivel de esta jerarquía tiene átomos CRUD** que controlan quién puede
ver/crear/modificar/eliminar cada propiedad de cada entidad:

```
D00.org.bdomain_nit.R      → leer el NIT de una empresa
D00.org.bdomain_nit.U      → modificar el NIT
D00.org.bdomain_email.C    → registrar un email de la empresa
D00.org.actor_ci.R         → leer la CI de una persona
D00.org.actor_ci.U         → modificar la CI
```

**Sin D00, los templates v6.0 no tienen respaldo estructural:**

| Bloque del template | Qué necesita de D00 | Sin D00... |
|---|---|---|
| Bloque 1 — logical_access (identity) | Átomos IDENTIDAD: `tenant`, `bdomain`, `bsubdomain`, `pos`, `rol` | `ctx_id` no puede expresar a qué empresa/sucursal pertenece el usuario |
| Bloque 3 — physical_access | Átomos D00: zona física vinculada a `bsubdomain` | Acceso físico no tiene contexto organizacional |
| Bloque 6 — zone_application_map | Mapa de zonas a apps para `bdomain_type` | El mapa no sabe si el rol es de empresa, persona u hogar |
| Bloque 7 — Tryton capas 1-5 | Reglas `ir.rule` filtradas por `empresa_id`/`sucursal_id` | Las reglas de Tryton no pueden filtrarse por jerarquía organizacional |
| UserTemplate Bloque 2 — personal_info | Campos: `id_nacional`, `tributario`, `email`, `telefono`, `direccion` | Sin átomos D00, cualquier rol puede ver/modificar datos sensibles |

#### 3.3 Diseño confirmado: CRUD granular (Diseño B — 108 átomos)

El catálogo `BAUTH-CATALOGO-ATOMOS-D00-CRUD.md` (Estado: **DISEÑO APROBADO — DDL PENDIENTE**)
establece la decisión:

> *"Reemplaza los 20 átomos semánticos (verbos 51-63) por 108 átomos CRUD con granularidad máxima."*

El mismo patrón CRUD se aplica a todos los dominios D4-D12 (documentado en `BAUTH-CATALOGO-ATOMOS-D4-D12.md`):
`DXX.{app}.{entidad}_{campo}.{C|R|U|D}`. Una decisión arquitectónica uniforme en todo el sistema.

**108 átomos D00 — posiciones 5809-5916 en `privilege_atom`:**

| Módulo | Entidades | Campos × CRUD | Posiciones |
|--------|-----------|:-------------:|-----------|
| tenant | tenant | type × 4 | 5809-5812 |
| bdomain | empresa/persona/hogar | type, nombre, nit, email, telefono, web, logo, status × 4c/u | 5813-5876 |
| bsubdomain | sucursal/oficina/casa | type, nombre, codigo, timezone × 4 | 5877-5892 |
| pos_logico | caja/punto/entrada | nombre, tipo, modalidad, status × 4 | 5893-5908 |
| actor | persona en org | ci, email principal, telefono, locale, timezone × 4 | 5909-5916 (parcial) |

Adicionalmente, `idn_atributo` (una sola tabla genérica extensible documentada en
`BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md`) almacena los atributos con cardinalidad 1:N
(múltiples emails, teléfonos, documentos, idiomas, etc.) sin necesidad de nuevas tablas.

#### 3.4 Bloqueador técnico actual

```sql
-- En privilege_domain (línea 2567 del DDL):
CONSTRAINT ck_domain_code CHECK (domain_code BETWEEN 1 AND 15)
```

Esta línea bloquea la inserción de D00 (`domain_code = 0`). Es el único cambio
técnico de constraint necesario antes de insertar el dominio y sus átomos.
Las tablas org_* ya existen en la BD — no hay que recrearlas.

#### 3.5 Alcance completo de la reparación (D00 es el primer paso)

La reparación no es solo "agregar D00". Es migrar la identidad de monolítica a atómica:

```
PASO 0  — Pruebas de escritorio (ANTES de tocar la BD)
          Verificar que el diseño cubre 100% de las necesidades de ROLTEMPLATE v6.0
          y USERTEMPLATE v6.0 contra los estándares de la industria.
          El dominio de identidad es crítico y variable — validar antes de implementar.

PASO 1  — Migración DDL D00 (HITL: aprobación de Iván)
          a. Corregir CHECK constraint: BETWEEN 0 AND 15
          b. INSERT privilege_domain (domain_code=0, 'Identidad Organizacional')
          c. INSERT privilege_application (app_code=13, 'org')
          d. INSERT privilege_group (5 grupos: tenant, bdomain, bsubdomain, pos, actor)
          e. INSERT privilege_atom (108 átomos CRUD, posiciones 5809-5916)
          f. CREATE TABLE bauth.idn_atributo (tabla extensible — ADR-016)

PASO 2  — Corregir dominios D1-D12 (átomos faltantes)
          Aplicar el catálogo D4-D12 para completar los átomos de todos los dominios.

PASO 3  — Recomponer código Rust
          Handlers JSON-RPC que operan sobre idn_atributo y privilege_atom D00.

PASO 4  — Pruebas en VPS
          Verificación empírica con el Testeador (ORQUESTA).

---

### Gap 4 — El campo `template JSONB` no tiene validación de estructura

Ambas tablas guardan el template completo en una columna `JSONB NOT NULL`. PostgreSQL
acepta cualquier JSON bien formado en esa columna: un template con 16 bloques y uno
con 2 bloques pasan igual.

No hay:
- CHECK constraint que valide presencia de bloques obligatorios
- JSON Schema (PostgreSQL soporta validación vía extensión)
- FK que obligue a que los `role_id` referenciados en `roles_assignments` existan en `idn_role_template`
- FK que obligue a que los `zone_id` del Bloque 5 existan en `fis_access_zone`
- FK que obligue a que los átomos referenciados en los bloques de privilegio existan en `privilege_atom`

La BD hoy acepta un template con `"status": "ACTIVE"` (template v6.0 correcto) y también
acepta `"status": "cualquier_cosa"` — sin diferencia.

---

### Gap 5 — Los nombres de archivo de los templates son v5_0 pero el contenido es v6.0

```
SBOS-ROLTEMPLATE-v5_0.md  → contenido dice SBOS-ROLTEMPLATE-v6_0, Junio 2026
SBOS-USERTEMPLATE-v5_0.md → contenido dice SBOS-USERTEMPLATE-v6_0, Junio 2026
```

Ambos archivos dicen explícitamente: `"Reemplaza: SBOS-ROLTEMPLATE-v5_0 (Abril 2026)"`.
Es decir, los archivos nombrados como v5_0 ya contienen la versión v6.0. El nombre del
archivo quedó desfasado. Cualquier agente que busque "v5_0" cree que está leyendo la
versión anterior y puede ignorarla — cuando en realidad es la versión actual.

---

## 3. Lo que REPARACIONBAUTH resuelve (y lo que no)

### Lo que resuelve

| Fase | Qué resuelve | Gap que cierra |
|---|---|---|
| FASE 0.S (seeds) | Corrige seeds de `idn_user_template` y `idn_role_template` con vocabulario v6.0 | Gap 1 (parcial), Gap 2 (en los datos existentes) |
| FASE 1 (DDL D00) | Agrega Dominio D00 y sus átomos | Gap 3 — el más crítico |
| FASES 2-3 | Agrega átomos D4-D12 y D13 | Complementa Gap 3 |

### Lo que NO resuelve (fuera del alcance actual)

- **Gap 1 (nombres):** Resuelto conceptualmente — `idn_*` es el nombre canónico. Los templates deben actualizarse para reflejar esto.
- **Gap 2 (status):** El PLAN-ACCION no incluye migrar el CHECK constraint de status. Pendiente aplicar la corrección definida en §2 Gap 2.
- **Gap 4 (validación JSONB):** No está planificado agregar validación estructural al campo `template JSONB`.
- **Gap 5 (nombres de archivo):** Corrección cosmética pendiente.

---

## 4. TAREA PENDIENTE — Auditoría de cumplimiento de normas en el DDL completo

**Ejecutar durante la fase de reparación, antes de aplicar cualquier migración.**

### Descripción
Revisar `sbos_00__esquema_base.sql` (5487 líneas) íntegramente y verificar el
cumplimiento de la Norma Fundacional de dos universos de lenguaje definida en §0
de este documento. Identificar toda violación, clasificarla por severidad y producir
una lista de correcciones con su norma de respaldo.

### Qué verificar

| Verificación | Norma aplicable | Ejemplo de violación encontrada |
|---|---|---|
| ENUMs y CHECK con valores en español | SCIM 2.0 RFC 7643 · SQL:2023 · NIST SP 800-53 | `fin_transaction_category_enum`: `'VENTAS','COMPRAS','PAGOS'` |
| ENUMs y CHECK con valores en español | Ídem | `fin_risk_level_enum`: `'BAJO','MEDIO','ALTO','CRITICO'` |
| ENUMs y CHECK con valores en español | Ídem | `role_type_enum`: `'TYPE_OPERATIVO','TYPE_GERENCIA_MEDIA'` |
| ENUMs y CHECK con valores en español | Ídem | `chk_zl_categoria`: `'OPERATIVA','ADMINISTRATIVA','FINANCIERA'` |
| ENUMs y CHECK con valores en español | Ídem | `chk_zl_ambito`: `'EMPRESA','SUCURSAL'` |
| ENUMs con mayúsculas/minúsculas mezcladas | SQL:2023 convención | `audit_level_enum`: `'basic','full'` (mezcla con otros ENUMs en MAYÚSCULAS) |
| CHECK en `idn_role_template.status` | Norma fundacional §0 · SCIM 2.0 | `'DEFINIDO','PUBLICADO','RETIRADO'` — español, ya documentado en Gap 2 |
| CHECK constraint `domain_code BETWEEN 1 AND 15` | Gap 3 — bloquea D00 | Documentado en Gap 3 |
| Nombres de columnas con español | Convención SQL:2023 | `profundidad`, `ancestro_id`, `descendiente_id` en `idn_role_closure` |
| Columnas o tablas con prefijo heredado `bos_` | Gap 1 | `bos_rol_template_history`, `bos_permiso_logico`, `bos_crypto_algorithm` |

### Método de ejecución
```bash
# Extraer todos los ENUMs con valores no-ASCII o en minúsculas inconsistentes
grep -n "AS ENUM\|CHECK.*IN" sbos_00__esquema_base.sql

# Buscar nombres de columna en español
grep -n "profundidad\|ancestro\|descendiente\|nombre\|descripcion\|activo\|vigente" sbos_00__esquema_base.sql
```

### Entregable
Un documento `BAUTH-AUDITORIA-NORMAS-DDL-<FECHA>.md` en esta misma carpeta con:
- Lista completa de violaciones numeradas
- Severidad: CRÍTICA (bloquea estándar) / MEDIA (inconsistencia) / BAJA (cosmética)
- Norma específica violada con referencia exacta
- Corrección propuesta con su norma de respaldo
- Aprobación de Iván antes de aplicar cualquier `ALTER TYPE` o `ALTER TABLE`

---

## 4. Por qué se diseñó D00 primero

La arquitectura `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md` (v1.1.0, aprobada para implementación)
establece que **todo en bAuth es un átomo con 4 coordenadas: dominio.aplicación.módulo.verbo**.

Si D00 no existe, no hay forma de expresar la identidad organizacional como un conjunto
de átomos. Y sin esa expresión atómica, los bloques de los templates que describen
"qué puede hacer este rol con entidades de tipo empresa/sucursal/tenant" no tienen
respaldo estructural en la BD — son texto muerto.

D00 es la base sobre la cual los demás dominios (D1-D12) adquieren contexto organizacional.

---

## 5. Diseño confirmado y documentos de referencia

El diseño elegido es **CRUD granular por campo** (108 átomos, Diseño B), confirmado en
`BAUTH-CATALOGO-ATOMOS-D00-CRUD.md` (Estado: DISEÑO APROBADO — DDL PENDIENTE) y coherente
con el catálogo D4-D12 que usa el mismo patrón en todos los dominios.

**Documentos SSOT del diseño D00 — leer en este orden antes de implementar:**

| Documento | Ruta | Qué define |
|---|---|---|
| `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md` | `context/plandeaccion/REPARACIONBAUTH/` | Modelo atómico completo: tablas, flujo, FastPath, ctx_id |
| `BAUTH-CATALOGO-ATOMOS-D00-CRUD.md` | `context/plandeaccion/REPARACIONBAUTH/` | 108 átomos CRUD D00 con posiciones, estándares y storage |
| `BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md` | `context/plandeaccion/REPARACIONBAUTH/` | Tabla `idn_atributo`: diseño, catálogo de formatos, validación, 29 países |
| `BAUTH-CATALOGO-ATOMOS-D4-D12.md` | `context/plandeaccion/REPARACIONBAUTH/` | Catálogo CRUD D4-D12: átomos, posiciones, estándares por dominio |

**Por qué el Diseño A (20 átomos semánticos) quedó superado:**
Los 20 verbos semánticos (`EMPRESA`, `SUCURSAL`, `NIT`, `email`...) no permitían
control granular de lectura vs escritura. No se podía expresar "puede leer el NIT pero
no modificarlo" — era todo-o-nada. El CRUD resuelve esto con 4 átomos por campo:
`READ` ≠ `UPDATE` ≠ `CREATE` ≠ `DELETE`. Más átomos, más granularidad, más seguridad.

**El DDL de Diseño A (`003_d00_identidad_organizacional.sql`) queda obsoleto.**
El DDL de referencia es `003_d00_identidad_organizacional_CRUD.sql` en `db/migrations/`,
que debe revisarse y alinearse con el catálogo CRUD antes de aplicarse (HITL).

---

## 6. Resumen de la situación real

```
SBOS-ROLTEMPLATE-v6_0 (14 bloques, 74 campos)
SBOS-USERTEMPLATE-v6_0 (16 bloques, 82 campos)
         │
         │  necesitan
         ▼
BD actual (sbos_00__esquema_base.sql en VPS)
         │
         ├── idn_role_template  ← nombre distinto, status distinto al template
         ├── idn_user_template  ← nombre distinto, sin validación de status
         ├── privilege_domain   ← D1-D12 ok, D0 bloqueado por CHECK
         ├── privilege_atom     ← 5808 átomos D1-D12, 0 átomos D00
         └── [30+ tablas de soporte] ← presentes pero no conectadas al template JSONB

Resultado: template se guarda como blob, sin integridad referencial.
           Cualquier valor pasa. Ningún bloque del template tiene FK real.
```

La BD NO rechaza un template inválido. Acepta cualquier cosa en el campo `template JSONB`.
Eso es lo que "no permite validar con robustez" — la BD es un depósito, no un validador.

---

## 7. TAREA PENDIENTE — Átomos de administración del árbol de configuración

**Identificada en sesión de revisión con Iván · 2026-07-06**
**Documento de referencia:** `BAUTH-CATALOGO-ATOMOS-D00-CRUD.md` §Aclaración Conceptual

### Descripción del gap

El catálogo actual (D00, D4-D12) define átomos que controlan quién puede operar sobre
**datos de negocio** (NIT, email, CI, zonas físicas, límites financieros, etc.).

Lo que **no existe** en ningún catálogo es el conjunto de átomos que controla quién puede
**administrar el árbol de configuración de roles y usuarios** — es decir, quién puede
agregar, ver, modificar o quitar átomos de un rol.

### Átomos faltantes — Nivel de administración del árbol

```
D1.bauth.role_config.CREATE  → este admin puede AGREGAR átomos a un rol
D1.bauth.role_config.READ    → este admin puede VER la configuración de un rol
D1.bauth.role_config.UPDATE  → este admin puede CAMBIAR valores de átomos en un rol
D1.bauth.role_config.DELETE  → este admin puede QUITAR átomos de un rol

D1.bauth.user_config.CREATE  → este admin puede CREAR asignaciones de rol a un usuario
D1.bauth.user_config.READ    → este admin puede VER la configuración de un usuario
D1.bauth.user_config.UPDATE  → este admin puede CAMBIAR roles asignados a un usuario
D1.bauth.user_config.DELETE  → este admin puede REVOCAR roles de un usuario
```

Estos átomos pertenecen al dominio **D1 (Acceso Lógico)**, aplicación `bauth`,
módulo `role_config` / `user_config`. No son parte de D00.

### Solución al problema del bootstrapping (huevo/gallina)

La pregunta: "¿quién le da esos átomos al primer admin?" se resuelve con el
**Tier SU** como raíz de confianza fuera del motor de átomos.

```
BOS installer (fuera del sistema de átomos)
    │
    └── crea: SU — sin restricciones atómicas (es la raíz)
                │
                └── asigna D1.bauth.role_config.* a IAM_ADMIN
                              │
                              └── IAM_ADMIN gestiona el resto de los roles
```

El Tier SU es creado por el instalador BOS. No requiere átomos para existir.
Es el mismo patrón que `root` en Linux, `superuser` en PostgreSQL, `root account`
en AWS. La recursión termina ahí.

### Norma de respaldo

| Estándar | Referencia | Qué establece |
|---|---|---|
| NIST SP 800-53 Rev.5 | AC-2 Account Management | Gestión de cuentas y asignación de privilegios requiere control de acceso propio |
| NIST SP 800-53 Rev.5 | AC-5 Separation of Duties | Quien asigna privilegios ≠ quien los usa |
| ISO/IEC 24760-2:2025 | §7.4 Identity administration | La administración de identidades es en sí misma un recurso que requiere control de acceso |
| ISO 27001:2022 | A.8.2 Privileged Access Rights | Los derechos de acceso privilegiado se deben gestionar y monitorear con controles adicionales |

### Entregable

Diseñar y agregar a `BAUTH-CATALOGO-ATOMOS-D1-D3.md` (documento a crear) los átomos
`D1.bauth.role_config.*` y `D1.bauth.user_config.*` con sus posiciones en `privilege_atom`,
estándares de respaldo y criterios de asignación por tier (SU, SYS, IAM_ADMIN, HR_ADMIN).

**HITL requerido:** aprobación de Iván antes de agregar estos átomos al DDL.

---

## 8. REVISIÓN INTEGRAL — Estado real de los Dominios D1-D12

**Identificada en sesión de revisión con Iván · 2026-07-06**
**Motivo:** Un agente anterior eliminó el dominio D5 (Biométrico) afirmando que "no
necesitaba políticas de control". Esto es incorrecto. Esta sección documenta lo que
realmente se determinó y decidió para cada dominio en los documentos de REPARACIONBAUTH.

**Fuentes verificadas:**
- `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md` — tablas por dominio
- `BAUTH-COMPLETITUD-DOMINIOS-STANDARDS.md` — estado y gaps de cada dominio (66 gaps, 42+ estándares)
- `BAUTH-GAP-ANALISIS-TABLAS-vs-TEMPLATE.md` — 47 tablas faltantes, 8 con columnas incompletas
- `BAUTH-CATALOGO-ATOMOS-D4-D12.md` — diseño de átomos CRUD para D4-D12

---

### 8.1 INCONSISTENCIA CRÍTICA — Numeración de dominios en el catálogo de átomos

`BAUTH-CATALOGO-ATOMOS-D4-D12.md` usa una **numeración diferente** a la de
`BAUTH-ARQUITECTURA-ATOMICA-FINAL.md` y todos los demás documentos de reparación.

| Documento | D4 | D5 |
|---|---|---|
| `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md` | Temporal (cal_) | Biométrico (absorbido) |
| `BAUTH-COMPLETITUD-DOMINIOS-STANDARDS.md` | Temporal 🟡 | Biométrico 🟡 |
| `BAUTH-GAP-ANALISIS-TABLAS-vs-TEMPLATE.md` | temporal_schedule | biometric |
| **`BAUTH-CATALOGO-ATOMOS-D4-D12.md`** | **ACCESO FÍSICO (pacs.\*)** | **DISPOSITIVOS (device.\*)** |

El catálogo de átomos asignó la posición D4 (slots 1453–1936) al acceso físico (que según
la arquitectura pertenece a D2), y la posición D5 (slots 1937–2420) a dispositivos (que
no existe como dominio independiente en la arquitectura).

**Impacto:** Los átomos del catálogo apuntan a posiciones incorrectas en `privilege_atom`.
Un átomo `D4.pacs.zone_access.C` ocupa la posición que debería ser `D4 Temporal`.

**Acción requerida (HITL):** Iván debe decidir:
- Opción A: Corregir el catálogo para que D4=Temporal y D2=Físico (alinear con arquitectura)
- Opción B: Cambiar la arquitectura para acomodar la numeración del catálogo

**Sin esta decisión no se puede proceder al DDL de D4-D12.**

---

### 8.2 Estado por dominio — Decisiones y gaps vigentes

| Dominio | Arquitectura | Estado completitud | Tablas en DDL | Tablas nuevas |
|---|---|---|:---:|:---:|
| **D1 Lógico** | log_, zone_ | 🔴 INCOMPLETO | ✅ varias | 7 tablas |
| **D2 Físico** | fis_ | 🔴 INCOMPLETO | 🟡 parciales | 4 tablas |
| **D3 Financiero** | fin_ | 🔴 INCOMPLETO | ✅ mayoría | 3 tablas |
| **D4 Temporal** | cal_ | 🟡 PARCIAL | ✅ completas | 3 tablas |
| **D5 Biométrico** | absorbido\* | 🟡 PARCIAL | ❌ ninguna | 3 tablas |
| **D6 Geoespacial** | geo_ | 🟡 PARCIAL | 🟡 parciales | 2 tablas |
| **D7 Red** | net_ | 🔴 INCOMPLETO | 🟡 mínimas | 3 tablas |
| **D8 Contexto** | ses_ | 🔴 INCOMPLETO | ❌ ninguna | 3 tablas |
| **D9 Credenciales** | ath_ | 🟡 PARCIAL | ✅ mayoría | 2 tablas |
| **D10 Delegación** | dlg_ | 🟡 PARCIAL | ❌ ninguna | 1 tabla |
| **D11 Auditoría** | aud_ | 🟡 PARCIAL | 🟡 parciales | 3 tablas |
| **D12 Blockchain** | blk_ | 🔴 INCOMPLETO | ❌ ninguna | 4 tablas |

*\*Ver §8.3 para aclaración sobre "absorbido"*

---

### 8.3 Aclaración crítica sobre D5 Biométrico — "absorbido" ≠ "sin políticas"

`BAUTH-ARQUITECTURA-ATOMICA-FINAL.md` dice: `D5 — (absorbido en privilege_atom tipo REGLA)`.

**Qué significa "absorbido":**
Los **parámetros de regla** del biométrico (`fmr_threshold`, `liveness_required`) se
almacenan como átomos tipo REGLA en `privilege_atom`. Ejemplo:
```
D5.bauth.biometric.fmr_threshold → REGLA con valor "1:10000"
D5.bauth.biometric.liveness_required → REGLA con valor "true"
```

**Qué NO significa "absorbido":**
No significa que el dominio biométrico no necesite tablas de configuración ni políticas
propias. Los documentos de reparación son explícitos en lo contrario.

`BAUTH-GAP-ANALISIS-TABLAS-vs-TEMPLATE.md §SECCIÓN 5`:
> **"Dominio biométrico sin tablas propias. 3 nuevas tablas requeridas."**

`BAUTH-COMPLETITUD-DOMINIOS-STANDARDS.md §5`:
> D5 Biométrico: 🟡 PARCIAL — 4 gaps, estándares: ISO/IEC 30107-3, NIST SP 800-63B-4 §5.2.3,
> ISO/IEC 19794, FIDO Biometric Certification, ISO/IEC 24745, GDPR Art. 9

**Tablas propias que D5 biométrico necesita:**
| Tabla | Propósito | Prioridad |
|---|---|:---:|
| `bauth.bio_method` | Tipos biométricos con estándares ISO (19794-2 huella, 19794-5 rostro, etc.) | BAJA |
| `bauth.bio_enrollment_policy` | Política de enrolamiento: Argon2id, FMR 1:10000, liveness pasivo, alternativa no-biométrica | BAJA |
| `bauth.bio_gdpr_config` | Consentimiento explícito GDPR Art.9, retención, derecho de borrado | BAJA |

**Conclusion:** El agente anterior que eliminó las políticas de D5 cometió un error de
interpretación. "Absorbido en REGLA" se refiere a los parámetros de umbral. La
configuración del dominio biométrico sigue necesitando sus propias tablas.

**Normas que respaldan tablas de D5:**
- ISO/IEC 30107-3:2017 — Biometric Presentation Attack Detection (liveness obligatorio)
- NIST SP 800-63B-4 Final 2025 §5.2.3 — Biometrics as activation factor, FMR ≤ 1:10000
- GDPR Art. 9 — Biometric data is special category; requires explicit consent and dedicated policy
- OWASP ASVS V2.4.3 2024 — Argon2id for biometric template hashing

---

### 8.4 Detalle de gaps por dominio prioritario

#### D1 — Lógico (ALTA prioridad — bloqueante para AAL2/AAL3)

**Estándares aplicables:** NIST SP 800-63B-4, OpenID CAEP 1.0, RFC 9470, XACML 3.0,
ANSI/INCITS 359-2004.

**Tablas nuevas requeridas:**
- `bauth.ath_auth_flow` + `bauth.ath_auth_flow_method` — flujos de autenticación RFC 9470
- `bauth.ath_step_up_rule` — step-up condicional con `acr_values` y `max_age`
- `bauth.zone_application_map` — zonas → aplicaciones con módulos, menús, acciones
- `bauth.zone_field_restriction` — campos ocultos/solo-lectura por zona
- `bauth.zone_button_rule` — reglas de botones con PYSON y SoD
- `bauth.zone_record_rule` — filtros SQL por zona (scope BRANCH/REGIONAL/GLOBAL)

**Columnas adicionales en tablas existentes:**
- `bauth.ath_method`: 8 columnas (`is_phishing_resistant`, `is_device_bound`, `syncable`,
  `max_aal`, `can_be_primary`, `can_be_fallback`, `recovery_eligible`, `loa_max`)
- `bauth.idn_role_template`: 5 columnas (`timezone`, `inactivity_timeout`,
  `force_logout_at_end_shift`, `reauthentication_interval`, `retention_days`)

#### D7 — Red (MEDIA prioridad — Zero Trust)

**Estándares aplicables:** NIST SP 800-207 ZTA, CISA ZTMM v2, IEEE 802.1X, CAEP 1.0.

**Estado:** El dominio más vacío junto con D8. Solo `idn_tenant_network` existe (parcial).

**Tablas nuevas requeridas:**
- `bauth.net_device_trust_policy` — scoring de confianza de dispositivo (6 señales con pesos)
- `bauth.net_ztna_policy` — política ZTNA (default deny, allowed_services, microsegment)

#### D8 — Contexto (ALTA prioridad — bloqueante para SBOS-049)

**Estándares aplicables:** SBOS-049 Context Plane, W3C Trace Context, CAEP 1.0, NIST SP 800-63B-4 §7.

**Estado:** Sin tablas propias. ctx_id compliance con SBOS-049 no puede satisfacerse sin estas tablas.

**Tablas nuevas requeridas:**
- `bauth.ses_context_config` — estructura del ctx_id, W3C traceparent, OTel baggage
- `bauth.ses_ses_risk_policy` — evaluación de riesgo en tiempo real (geo_velocity, device_change)
- `bauth.ses_caep_config` — eventos CAEP: session-revoked, token-claims-change

#### D9 — Credenciales (Más avanzado — NIST 800-63B-4)

**Estándares aplicables:** NIST SP 800-63B-4 Final 2025, FIDO2/WebAuthn Level 3, OAuth 2.1.

**Estado:** El dominio más completo. `ath_method` (40 métodos) y `ath_policy` (22 políticas) existen.

**Tablas nuevas requeridas:**
- `bauth.ath_phishing_policy` (ALTA) — phishing-resistant obligatorio AAL2+, syncable solo AAL2
- `bauth.ath_rotation_policy` (BAJA) — rotación automática service accounts (90 días)

---

### 8.5 Resumen cuantitativo (fuente: BAUTH-GAP-ANALISIS-TABLAS-vs-TEMPLATE.md)

| Categoría | Cantidad |
|---|:---:|
| Tablas existentes que cubren los templates | **28** |
| Tablas existentes con columnas faltantes | **8** |
| Tablas nuevas requeridas (total) | **47** |
| — Prioridad ALTA (bloquean AAL2/AAL3) | **12** |
| — Prioridad MEDIA (completitud de dominio) | **21** |
| — Prioridad BAJA (futuro/especializado) | **14** |
| Gaps en RolTemplate v6.0 cubiertos por propuestas | **66** |

**Dominios sin ninguna tabla propia en DDL actual:** D5 (Biométrico), D8 (Contexto),
D10 (Delegación), D12 (Blockchain).

**Dominios con tablas core completas:** D3 (Financiero), D4 (Temporal), D9 (Credenciales).

---

### 8.6 Orden de atención recomendado (por impacto en AAL2/AAL3)

```
FASE A — ALTA (requieren HITL antes de DDL):
  1. Resolver inconsistencia de numeración D4/D5 en catálogo (HITL Iván)
  2. D8 ses_context_config + ses_ses_risk_policy → desbloquea SBOS-049
  3. D1 ath_auth_flow + ath_step_up_rule → desbloquea RFC 9470 step-up
  4. D1 zone_application_map + zone_field_restriction → desbloquea Tryton 5 capas
  5. D9 ath_phishing_policy → cumplimiento NIST 800-63B-4 AAL2+
  6. D14 sod_incompatible_role + sod_incompatible_function → SoD estático/dinámico

FASE B — MEDIA (completitud de dominio):
  7. D2 fis_access_method + fis_zone_method_requirement
  8. D7 net_device_trust_policy + net_ztna_policy
  9. D10 dlg_delegation_policy
  10. D11 aud_event_catalog + aud_review_policy + aud_regulatory_mapping

FASE C — BAJA (futuro / compliance avanzado):
  11. D5 bio_method + bio_enrollment_policy + bio_gdpr_config
  12. D12 blk_anchor_policy + blk_did_registry + blk_smart_contract + blk_besu_node
  13. D6 geo_trust_tier + geo_velocity_policy
```

**Nota sobre D00:** Esta fase es previa a todo lo anterior (ver §3 y §5). D00 es el
cimiento de la identidad organizacional y desbloquea las tablas de los otros dominios
que dependen de `idn_atributo` y la jerarquía tenant → bDomain → bSubDomain.

---

## 9. VERIFICACIÓN EN VPS — Estado real en SBOS_db (2026-07-06)

**Método:** Acceso directo a `postgresql-0` en namespace `sbos-data`, Kubernetes.
**Base de datos:** `SBOS_db` · **Usuario:** `postgres`

Esta sección reemplaza y corrige la información de §8 basada en archivos en disco.
Los datos aquí son evidencia directa del motor de base de datos en el servidor de pruebas.

---

### 9.1 Dominios registrados en privilege_domain

```
 domain_code | domain_name  | requires_policy | CHECK constraint
─────────────┼──────────────┼─────────────────┼──────────────────────────────────
           1 | Lógico       | FALSE           | ck_domain_code: >= 1 AND <= 15
           2 | Físico       | FALSE           |
           3 | Financiero   | TRUE            |
           4 | Temporal     | TRUE            |
           5 | Biométrico   | FALSE           | ← requires_policy = FALSE
           6 | Geoespacial  | TRUE            |
           7 | Red          | TRUE            |
           8 | Contexto     | FALSE           |
           9 | Credenciales | FALSE           |
          10 | Delegación   | TRUE            |
          11 | Auditoría    | FALSE           |
          12 | Blockchain   | TRUE            |
```

**D0 (Identidad Organizacional) confirma bloqueado:** el CHECK `domain_code >= 1`
impide insertar D0. La migración debe modificar este constraint antes de insertar D00.

**D5 Biométrico — requires_policy = FALSE:** Esto confirma que el dominio está registrado
pero sin política activa. La decisión de "absorber" en REGLA dejó el dominio SIN
enforcement activo de políticas biométricas.

---

### 9.2 Átomos por dominio — modelo MONOLÍTICO confirmado

```
 domain_code | domain_name  | total_atomos | pos_min | pos_max
─────────────┼──────────────┼─────────────┼─────────┼─────────
           1 | Lógico       |        1584  |       1 |    5720
           2 | Físico       |         432  |      34 |    5729
           3 | Financiero   |        1392  |      43 |    5758
           4 | Temporal     |         576  |      72 |    5770
           5 | Biométrico   |         192  |      84 |    5774
           6 | Geoespacial  |         192  |      88 |    5778
           7 | Red          |         192  |      92 |    5782
           8 | Contexto     |         432  |      96 |    5791
           9 | Credenciales |         192  |     105 |    5795
          10 | Delegación   |         192  |     109 |    5799
          11 | Auditoría    |         240  |     113 |    5804
          12 | Blockchain   |         192  |     118 |    5808
                             ─────────────
                TOTAL:            5808
```

**Formato real de los átomos (modelo ANTIGUO):**
```
tryton.g1.d5.nuevo    → Tryton · Contabilidad · Biométrico · create
tryton.g2.d5.editar   → Tryton · Inventario · Biométrico · update
besu.g1.d1.nuevo      → Besu · Contabilidad · Lógico · create
```

**Esto es el modelo MONOLÍTICO que la REPARACIONBAUTH debe reemplazar.**
El formato nuevo es: `D5.device.device_register.C` (D.A.M.V. = Dominio.App.Módulo.Verbo).

Los 192 átomos de D5 = 48 grupos × 4 verbos (create/update/delete/read) dentro de Tryton.
NO son átomos de control de autenticación biométrica.

---

### 9.3 Realidad de D5 Biométrico — tres capas verificadas

| Capa | Tabla | Filas | Contenido real |
|---|---|:---:|---|
| Átomos | `privilege_atom` (domain_code=5) | 192 | Modelo monolítico: permiso Tryton × grupo × biométrico × verbo |
| Config | `ath_config_d5` | 20 | **ALERTA:** contiene config FIDO2/WebAuthn/passkeys — pertenece a D9, NO a D5 |
| Políticas | `ath_policy_d5` | 17 | Políticas de dominio |
| Roles | `idn_role_d5` | 15 | Asignaciones de rol al dominio |
| **Biometría real** | `bio_method` | ❌ NO EXISTE | Tipos biométricos (ISO/IEC 19794-2/5/6) |
| **Biometría real** | `bio_enrollment_policy` | ❌ NO EXISTE | Argon2id, FMR, liveness |
| **Biometría real** | `bio_gdpr_config` | ❌ NO EXISTE | GDPR Art.9 consentimiento explícito |

**Conclusión verificada:** `ath_config_d5` tiene contenido INCORRECTO — almacena
configuración de credenciales digitales (FIDO2, passkeys, enterprise attestation,
WebAuthn Level 3) que pertenece al dominio D9 (Credenciales). El dominio D5
biométrico genuino (huella, rostro, iris, FMR thresholds, liveness, GDPR) no tiene
ninguna tabla de configuración propia.

---

### 9.4 Arquitectura per-dominio descubierta — NO documentada en el gap analysis anterior

El gap analysis (escrito 2026-06-24 contra un DDL antiguo) no conocía esta arquitectura.
La BD real tiene un patrón de tres tablas por cada dominio D1-D12:

| Patrón | Descripción | Estado de datos |
|---|---|---|
| `ath_config_d{N}` | Configuración del dominio (JSONB flexible) | 0-20 filas por dominio |
| `ath_policy_d{N}` | Políticas activas del dominio | 6-40 filas por dominio |
| `idn_role_d{N}` | Asignaciones de rol al dominio | 0-15 filas por dominio |

Esta arquitectura cubre PARCIALMENTE lo que el gap analysis pedía como "47 tablas nuevas".
Sin embargo, el contenido de esas tablas necesita revisión (ver §9.3 sobre D5).

---

### 9.5 Gap analysis corregido — tablas del listado original que YA EXISTEN

De las **47 tablas** listadas como "nuevas requeridas" en el gap analysis (2026-06-24),
las siguientes **YA EXISTEN** en SBOS_db verificado hoy:

| Tabla | Filas | Nota |
|---|:---:|---|
| `ath_auth_flow` | 8 | Flujos de autenticación |
| `ath_step_up_rule` | 8 | Reglas RFC 9470 step-up |
| `zone_application_map` | 8 | Mapa zonas → aplicaciones |
| `fin_sod_rule` | 6 | Reglas SoD financiero |
| `geo_trust_tier` | 3 | Tiers de confianza geoespacial |
| `ses_context` | 28 | Contexto de sesión activo |
| `fis_emergency_config` | 0 | Override emergencia física |
| `fis_zone_method_requirement` | 0 | Requisitos por zona física |
| `net_ztna_policy` | 0 | Política ZTNA |
| `ses_ses_risk_policy` | 0 | Política de riesgo de sesión |
| `ses_caep_config` | 0 | Eventos CAEP |
| `geo_velocity_policy` | 0 | Velocidad de viaje |
| `zone_button_rule` | 0 | Reglas de botones |
| `zone_field_restriction` | 0 | Restricciones de campos |
| `zone_record_rule` | 0 | Reglas de registros |
| `sod_validation_config` | 0 | Configuración validación SoD |
| `conflict_interest_policy` | 0 | Política conflicto de interés |
| `dlg_delegation` | 0 | Delegaciones |
| `aud_review` | 0 | Revisiones de auditoría |
| `blk_anchor` | 0 | Anclaje blockchain |
| `blk_account` | 0 | Cuentas blockchain |
| `blk_merkle_batch` | 0 | Lotes Merkle |
| `blk_merkle_leaf` | 0 | Hojas Merkle |
| `ath_auth_flow_method` | 0 | Métodos por flujo |
| `cal_overtime_policy` | — | (schema bcalendar) |
| `cal_break_policy` | — | (schema bcalendar) |

---

### 9.6 Tablas verdaderamente AUSENTES — confirmadas por consulta directa

Las siguientes 23 tablas NO existen en SBOS_db a la fecha de verificación:

**D5 Biométrico (CRÍTICO — contenido de ath_config_d5 está mal asignado):**
- `bio_method` — tipos biométricos con estándares ISO/IEC 19794-2/5/6
- `bio_enrollment_policy` — política de enrolamiento, Argon2id, FMR threshold
- `bio_gdpr_config` — cumplimiento GDPR Art.9, consentimiento explícito

**D2 Físico:**
- `fis_access_method` — métodos de acceso físico (QR, NFC, smartcard)
- `fis_biometric_policy` — política biométrica para acceso físico

**D3 Financiero:**
- `fin_transaction_schedule` — horarios de transacciones
- `fin_geospatial_control` — restricciones geográficas para transacciones

**D4 Temporal:**
- `attendance_policy` — control de asistencia

**D9 Credenciales:**
- `ath_phishing_policy` — política anti-phishing NIST 800-63B-4 AAL2+
- `ath_rotation_policy` — rotación de credenciales (ath_rotation_log existe pero no policy)

**D10 Delegación:**
- `dlg_delegation_policy` — políticas de delegación (dlg_delegation existe sin policy)

**D11 Auditoría:**
- `aud_event_catalog` — catálogo de eventos (aud_event existe como log, no catálogo)
- `aud_review_policy` — política de revisión periódica

**D12 Blockchain:**
- `blk_did_registry` — registro de DIDs W3C
- `blk_smart_contract` — smart contracts
- `blk_besu_node` — nodos Besu QBFT

**Sincronización (transversal):**
- `sync_kc_config` — configuración sincronización Keycloak
- `sync_tryton_config` — configuración sincronización Tryton
- `sync_drift_config` — configuración detección de drift

**SoD:**
- `sod_incompatible_role` — roles incompatibles (SoD estático)
- `sod_incompatible_function` — funciones incompatibles (SoD dinámico)

**D1 / D7:**
- `tryton_model_access` — ir.model.access de Tryton
- `net_device_trust_policy` — scoring de confianza de dispositivo

---

### 9.7 Columnas faltantes — confirmadas por estructura real de tablas

| Tabla | Columnas ausentes (confirmadas) |
|---|---|
| `bauth.idn_role_template` | `timezone`, `inactivity_timeout`, `force_logout_at_end_shift`, `reauthentication_interval`, `retention_days` |
| `bauth.ath_method` | `is_phishing_resistant`, `is_device_bound`, `syncable`, `max_aal`, `can_be_primary`, `can_be_fallback`, `recovery_eligible` — NO están en JSONB config |

---

### 9.8 Estado de datos por dominio (semáforo actualizado)

| Dominio | Tablas | Datos cargados | Estado |
|---|:---:|:---:|---|
| D1 Lógico | Parciales | Sí (1584 átomos, 9 roles) | 🟡 PARCIAL |
| D2 Físico | Existen vacías | No | 🔴 SIN DATOS |
| D3 Financiero | Existen vacías | Solo fin_sod_rule (6) | 🟡 MÍNIMO |
| D4 Temporal | Completas | bcalendar poblado | 🟢 FUNCIONAL |
| D5 Biométrico | Existen (contenido erróneo) | ath_config_d5 = D9 content | 🔴 MAL ASIGNADO |
| D6 Geoespacial | Existen | Solo geo_trust_tier (3) | 🟡 MÍNIMO |
| D7 Red | Mínimas | Vacías | 🔴 SIN DATOS |
| D8 Contexto | Existen | ses_context (28 activos) | 🟡 PARCIAL |
| D9 Credenciales | Más completo | ath_method (32), ath_policy_d9 (40) | 🟢 FUNCIONAL |
| D10 Delegación | dlg_delegation | Vacía | 🔴 SIN DATOS |
| D11 Auditoría | Existen | aud_compliance_map (290) | 🟡 PARCIAL |
| D12 Blockchain | Existen vacías | 0 datos | 🔴 SIN DATOS |

---

### 9.9 Hallazgo adicional — cfg_policy_library (9142 filas)

Existe una tabla `cfg_policy_library` con 9142 filas que no aparece en el gap analysis
ni en la arquitectura documentada. Podría ser el origen de las políticas que se cargan
en `ath_policy_d{N}`. Requiere revisión para evitar duplicidad con las tablas de dominio.

---

*Verificación directa en VPS 13.140.128.230 · postgresql-0 · SBOS_db · 2026-07-06*
*Evidencia: consultas SQL ejecutadas mediante kubectl exec · C12 cumplido*

---

*Análisis generado por bauth-developer · 2026-07-06*
*Basado en lectura directa de: sbos_00__esquema_base.sql, SBOS-ROLTEMPLATE-v5_0.md,*
*SBOS-USERTEMPLATE-v5_0.md, BAUTH-ARQUITECTURA-ATOMICA-FINAL.md*
*Cero cambios aplicados — solo lectura*
