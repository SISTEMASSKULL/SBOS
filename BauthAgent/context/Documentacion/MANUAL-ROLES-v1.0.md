# Manual de Roles — bAuth Identity Control Plane

**Versión del manual:** 1.0.0  
**Fecha:** 2026-07-10  
**Normas base:** NIST SP 800-53 Rev.5 · ANSI INCITS 359-2012 · ISO 27001:2022 · ISO 24760-2:2025  
**Estado de datos:** Verificado en VPS · PostgreSQL 18.4 · 548 roles · 2026-07-10

---

## Tabla de contenidos

1. [Fundamentos](#1-fundamentos)
2. [Taxonomía de roles](#2-taxonomía-de-roles)
3. [Anatomía del contrato — RolTemplate v6.0](#3-anatomía-del-contrato--roltemplate-v60)
4. [Herencia y árbol organizacional](#4-herencia-y-árbol-organizacional)
5. [Ciclo de vida del rol](#5-ciclo-de-vida-del-rol)
6. [Sistema de versiones](#6-sistema-de-versiones)
7. [Integración con Keycloak y Tryton](#7-integración-con-keycloak-y-tryton)
8. [Gestión operativa de roles](#8-gestión-operativa-de-roles)
9. [Referencias](#9-referencias)

---

## 1. Fundamentos

### 1.1 ¿Qué es un Rol en bAuth?

Un **Rol** en bAuth es un **contrato de acceso normalizado** que define qué puede hacer un tipo de actor dentro del ecosistema SBOS. No es una lista de permisos planos — es una entidad gestionada con identidad, versión, ciclo de vida y trazabilidad.

Un Rol responde a tres preguntas:

| Pregunta | Campo | Ejemplo |
|----------|-------|---------|
| ¿Quién puede tenerlo? | `type_id` + `applies_to_size` | Solo personas físicas (`INDIVIDUAL`), empresas grandes |
| ¿Qué puede hacer? | BitMask 64-bit + átomos | Lectura D1, escritura D3, firma digital D9 |
| ¿Bajo qué condiciones? | `loa_required`, `mfa_required`, `step_up_enabled` | LoA 2, MFA obligatorio, step-up en operaciones críticas |

### 1.2 El Rol como contrato: RolTemplate v6.0

El **RolTemplate v6.0** es el formato canónico del contrato de rol. Tiene 14 bloques normalizados (`B1`–`B21`) que cubren identificación, vigencia, control de acceso, firma digital, auditoría, y sincronización con los motores (Keycloak, Tryton, OAuth2-Proxy).

En la base de datos, cada rol es una fila en `bauth.idn_role_template`. El campo `template` (JSONB) contiene metadatos operativos del contrato. El campo `template_version` indica qué versión del esquema de contrato usa el registro.

### 1.3 Diferencias fundamentales

| Concepto | Definición | Tabla |
|----------|------------|-------|
| **Rol** | Contrato de acceso para un tipo de actor | `bauth.idn_role_template` |
| **Permiso** | Autorización atómica (lectura, escritura, ejecución) sobre un recurso específico | Calculado desde el BitMask |
| **Átomo** | Unidad mínima de capacidad funcional en un dominio (D1–D12) | `bauth.cfg_policy_library` |
| **Verbo** | Acción HTTP/RPC que un átomo autoriza (GET, POST, DELETE, …) | Definido en el contrato del átomo |
| **BitMask** | Representación compacta de 64 bits del conjunto de permisos del rol | Campo calculado en el JWT |

Un rol **no contiene permisos directamente** — contiene una referencia a su posición en el árbol de herencia y sus condiciones de uso. El motor `PrivilegeEngine` de bAuth calcula el BitMask resultante en tiempo real combinando herencia OR + SoD + PolicyChain.

### 1.4 bAuth como orquestador, no como motor de autenticación

bAuth **no autentica** directamente. Orquesta:

```
Actor presenta credenciales
        ↓
bAuth enruta al motor correcto (Keycloak OIDC / Vault PKI / Besu ECDSA)
        ↓
Motor devuelve resultado
        ↓
bAuth aplica: BitMask + DomainRegistry + PolicyChain + SoD + DAG
        ↓
bAuth emite JWT unificado con RolBitMask + ctx_id + firma
```

El Rol es la pieza central de este proceso: define qué puede pedir el JWT.

---

## 2. Taxonomía de roles

### 2.1 Los 7 Tiers

Los tiers clasifican los roles por su nivel de privilegio en la organización. Son el eje vertical del catálogo.

| Tier | Nombre | Descripción | Ejemplo |
|------|--------|-------------|---------|
| `SU` | Superusuario | Acceso total al sistema. Solo existe uno. | ROL-SYS-SUPERUSUARIO |
| `SYS` | Sistema | Roles de infraestructura y daemons internos | ROL-SYS-BANEXUS-DAEMON |
| `BIZ_N1` | Nivel ejecutivo | C-Level, directores generales | ROL-GERENTE-GENERAL |
| `BIZ_N2` | Nivel dirección | Jefes de área, gerentes de departamento | ROL-JEFE-IT, ROL-JEFE-RRHH |
| `BIZ_N3` | Nivel gerencia media | Supervisores, coordinadores | ROL-SUPERVISOR-PLANTA |
| `BIZ_N4` | Nivel profesional | Analistas, especialistas, técnicos calificados | ROL-DESARROLLADOR |
| `BIZ_N5` | Nivel operativo | Operarios, cajeros, asistentes | ROL-CAJERO |
| `EXT_N0` | Externo | Clientes, proveedores, visitantes, auditores externos | ROL-EXT-CUENTAHABIENTE |
| `M2M` | Machine-to-Machine | Daemons, APIs, integraciones automáticas | ROL-SYS-BIEDATA-DAEMON |
| `VISITANTE` | Visitante | Acceso mínimo, sin autenticación fuerte requerida | ROL-EXT-VISITANTE |

### 2.2 Los 10 tipos normativos de cuenta

El campo `type_id` apunta a la tabla `bauth.idn_role_type` que cataloga los tipos de cuenta según **NIST SP 800-53 AC-2(a)**. Cada rol está clasificado en uno de estos 10 tipos:

| Tipo | Código | Descripción | Es humano | Riesgo elevado |
|------|--------|-------------|-----------|----------------|
| Individual | `INDIVIDUAL` | Persona física empleada de la organización | Sí | No |
| Externo | `EXTERNAL` | Persona física fuera de la organización (cliente, proveedor) | Sí | No |
| Visitante | `GUEST` | Acceso temporal sin credenciales permanentes | Sí | No |
| Grupo | `GROUP` | Conjunto de usuarios con permisos compartidos | No | No |
| Sistema | `SYSTEM` | Cuenta del sistema operativo o infraestructura | No | Sí |
| Servicio | `SERVICE` | Aplicación o microservicio interno | No | Sí |
| M2M | `M2M` | Comunicación automatizada entre máquinas | No | Sí |
| Emergencia | `EMERGENCY` | Acceso de emergencia con expiración obligatoria | Sí | Sí |
| Temporal | `TEMPORARY` | Acceso de corta duración con fecha fin fija | Sí | No |
| Desarrollador | `DEVELOPER` | Acceso técnico a entornos de desarrollo | Sí | Sí |

**Distribución verificada en VPS (2026-07-10):**
`INDIVIDUAL=334` · `EXTERNAL=162` · `M2M=29` · `SYSTEM=19` · `GUEST=4` · Total: 548

### 2.3 Los 21 sectores CAEB SIN

Los roles están organizados por sector económico según la **Clasificación de Actividades Económicas de Bolivia (CAEB SIN)**. Esto permite que un mismo rol (ej. `ROL-CONTADOR`) tenga herencia distinta en cada sector.

| Sección | Nombre | Ejemplos de roles |
|---------|--------|-------------------|
| A | Agricultura, ganadería, silvicultura | ROL-CAPATAZ, ROL-PEON-RURAL, ROL-VETERINARIO |
| B | Minería y explotación de canteras | ROL-JEFE-PRODUCCION, ROL-OPERARIO-PRODUCCION |
| C | Industrias manufactureras | ROL-JEFE-LOGISTICA, ROL-SUPERVISOR-ALMACENES |
| D | Suministro de electricidad y gas | ROL-SYSADMIN, ROL-PLANIFICADOR-PRODUCCION |
| E | Suministro de agua y gestión de residuos | ROL-EXT-USUARIO-AGUA, ROL-EXT-GENERADOR-RESIDUOS |
| F | Construcción | ROL-MAESTRO-OBRA, ROL-ALBANIL, ROL-INGENIERO-CIVIL |
| G | Comercio al por mayor y menor | ROL-JEFE-LOCAL, ROL-CAJERO, ROL-VENDEDOR |
| H | Transporte y almacenamiento | ROL-CHOFER-CAMION, ROL-DESPACHADOR-FLOTA |
| I | Alojamiento y servicio de comidas | ROL-CHEF, ROL-RECEPCION-HOTEL, ROL-MESERO |
| J | Información y comunicaciones | ROL-DESARROLLADOR, ROL-SOPORTE-TECNICO |
| K | Actividades financieras y de seguros | ROL-GERENTE-BANCO, ROL-CAJERO-BANCO, ROL-OFICIAL-CREDITOS |
| L | Actividades inmobiliarias | ROL-ADMINISTRATIVO, ROL-EXT-INQUILINO |
| M | Actividades profesionales y científicas | ROL-CONTADOR, ROL-INGENIERO-CIVIL |
| N | Actividades administrativas y de servicios | ROL-JEFE-RRHH, ROL-ANALISTA-RRHH |
| O | Administración pública y defensa | ROL-PORTERO, ROL-EXT-CIUDADANO |
| P | Enseñanza | ROL-DIRECTOR-COLEGIO, ROL-DOCENTE, ROL-AUXILIAR-DOCENTE |
| Q | Actividades de atención de salud | ROL-MEDICO-GENERAL, ROL-ENFERMERO, ROL-FARMACEUTICO |
| R | Arte, entretenimiento y recreación | ROL-EXT-ESPECTADOR, ROL-EXT-VISITANTE-MUSEO |
| S | Otras actividades de servicios | ROL-ADMINISTRATIVO |
| T | Hogares como empleadores | ROL-EXT-EMPLEADOR-DOMESTICO, ROL-EXT-TRABAJADOR-HOGAR |
| U | Organizaciones extraterritoriales | ROL-EXT-DIPLOMATICO, ROL-EXT-SOLICITANTE-VISA |

---

## 3. Anatomía del contrato — RolTemplate v6.0

### 3.1 Campos de la tabla `bauth.idn_role_template`

La tabla tiene columnas nativas (consultables, indexables) y un campo JSONB (`template`) para metadatos operativos adicionales.

#### Columnas de identificación

| Columna | Tipo | Norma | Descripción |
|---------|------|-------|-------------|
| `id` | `uuid` — PK — `uuidv7()` | ISO 24760-2 | Identificador único time-ordered. Nunca reutilizado. |
| `role_name` | `text` NOT NULL UNIQUE | INCITS 359 §3.1 | Clave natural del rol. Formato: `ROL-<CATEGORIA>[-<SUBCATEGORIA>]`. Inmutable una vez asignado. |
| `type_id` | `uuid` FK → `idn_role_type` | NIST AC-2(a) | Tipo normativo de cuenta (ver §2.2). |
| `role_type` | `text` CHECK | Operativo interno | Tipo operativo legible: `GERENCIAL`, `TECNICO_PROFESIONAL`, `OPERATIVO`, `EXTERNO`, etc. |

#### Columnas de clasificación

| Columna | Tipo | Norma | Descripción |
|---------|------|-------|-------------|
| `tier` | `text` | INCITS 359 §3.3 | Nivel de privilegio en la organización (ver §2.1). |
| `hierarchy_level` | `integer` | INCITS 359 §3.3 | Profundidad real del nodo en el árbol `parent_id`. Calculado automáticamente por `bauth_62`. Nivel 0 = raíz. |
| `scope` | `text` | NIST AC-6 | Sector o dominio de aplicación del rol (ej. `'Banca y Seguros'`). |
| `applies_to_size` | `text` | ISO 24760-2 | Tamaño de empresa donde aplica: `MICRO`, `PEQUEÑA`, `MEDIANA`, `GRANDE`, `TODAS`. |
| `risk_level` | `text` | ISO 27001 A.8.2 | Nivel de riesgo: `BAJO`, `MEDIO`, `ALTO`, `CRÍTICO`. |

#### Columnas de control de acceso

| Columna | Tipo | Norma | Descripción |
|---------|------|-------|-------------|
| `loa_required` | `integer` | NIST SP 800-63B §4 | Nivel de aseguramiento requerido: 1=AAL1, 2=AAL2, 3=AAL3. |
| `mfa_required` | `boolean` | NIST SP 800-63B §5.1.8 | Si el rol requiere segundo factor obligatoriamente. |
| `step_up_enabled` | `boolean` | RFC 9470 | Si el rol puede solicitar elevación de LoA en operaciones críticas. |
| `sod_group` | `text` | NIST AC-5 | Grupo de Separación de Funciones. Dos roles del mismo grupo no pueden coexistir en un usuario. |
| `max_sessions` | `integer` | NIST AC-10 | Número máximo de sesiones concurrentes permitidas. |
| `session_timeout` | `integer` | NIST AC-12 | Tiempo máximo de sesión en segundos. |
| `audit_level` | `text` | ISO 27001 A.8.15 | Nivel de auditoría: `basic` (eventos críticos) o `full` (toda operación). |

#### Columnas de ciclo de vida

| Columna | Tipo | Norma | Descripción |
|---------|------|-------|-------------|
| `status` | `bauth.role_status_type` | NIST AC-2(j) | Estado del ciclo de vida del rol (ver §5). Valores: DRAFT/REVIEW/ACTIVE/SUSPENDED/DEPRECATED/ARCHIVED. |
| `version` | `text` CHECK SemVer | ISO 27001 A.8.32 | Versión de la **definición individual del rol**. SemVer `MAJOR.MINOR.PATCH`. ⚙ En implementación (G-B01-06). |
| `template_version` | `text` CHECK SemVer | ISO 27001 A.8.32 | Versión del **esquema de contrato** RolTemplate. ⚙ En implementación (G-B01-06). |
| `review_period_days` | `integer` | ISO 27001 A.5.18 | Días entre revisiones periódicas del rol. 90 días para privilegiados (PCI DSS 4.0 Req.7). |
| `is_collaborative` | `boolean` | NIST AC-6 | Si el rol puede ser compartido simultáneamente entre múltiples usuarios. |
| `path_ids` | `text[]` | Interno | Array de role_names del camino desde la raíz hasta este nodo (para navegación de árbol). |

#### Columnas de herencia

| Columna | Tipo | Norma | Descripción |
|---------|------|-------|-------------|
| `parent_id` | `uuid` FK → `id` NULL | INCITS 359 §3.3 | Nodo padre en el árbol de herencia. NULL solo para la raíz (ROL-SYS-SUPERUSUARIO). |

#### Columnas de metadatos operativos

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `template` | `jsonb` | Metadatos operativos del contrato: `{n, v, r, issuer, domains, sync_status, last_sync_at, sam128_*}` |
| `role_template_name` | `jsonb` | Nombre y descripción bilingüe del rol: `{es: {name, description}, en: {name, description}, scope, type_id, role_name, role_type, classification}` |
| `template_id` | `uuid` | FK a la plantilla base de la que deriva este rol. |
| `created_by` | `text` | Agente o usuario que creó el registro. |
| `created_at` / `updated_at` | `timestamptz` | Marcas de tiempo de creación y última modificación. |

### 3.2 El campo `template` (JSONB)

```json
{
  "n": "Gerente General/Director",
  "v": "1.0.0",
  "r": "3.7.65",
  "issuer": "bauth-bootstrap",
  "domains": ["D02"],
  "sync_status": "PENDING",
  "last_sync_at": null,
  "sam128_logical": null,
  "sam128_physical": null,
  "sam128_financial": null,
  "sam128_governance": null,
  "sync_error": null,
  "rol_bitmask_base64": ""
}
```

| Clave | Descripción |
|-------|-------------|
| `n` | Nombre corto del rol (para logs y JWT claims) |
| `v` | Versión de la definición del rol (duplicada del campo `version` — se mantendrá en sync) |
| `r` | Referencia al rol en el framework de autenticación (Authentication_Framework.json) |
| `issuer` | Quién creó este registro (`bauth-bootstrap`, `admin@tenant`, agente) |
| `domains` | Dominios de soberanía aplicables: D1-D12 |
| `sync_status` | Estado de sincronización con KC y Tryton: `PENDING`, `SYNCED`, `ERROR`, `DRIFT` |
| `last_sync_at` | Timestamp del último sync exitoso |
| `sam128_*` | BitMask 128-bit dividido en 4 cuadrantes de 32 bits (lógico, físico, financiero, gobernanza) |
| `rol_bitmask_base64` | BitMask 64-bit del rol codificado en Base64 (calculado por PrivilegeEngine) |

---

## 4. Herencia y árbol organizacional

### 4.1 Concepto de herencia OR

bAuth implementa **herencia OR** según INCITS 359 §3.3 (RBAC1): un usuario que tiene el rol `ROL-GERENTE-GENERAL` hereda automáticamente todos los permisos de sus roles descendientes en el árbol. No es herencia AND — basta con que un ancestro en el árbol tenga el permiso para que el usuario lo herede.

### 4.2 El árbol padre-hijo

Todos los roles forman un **árbol único** con raíz en `ROL-SYS-SUPERUSUARIO`. El árbol se define mediante la columna `parent_id`:

```
ROL-SYS-SUPERUSUARIO (raíz, parent_id = NULL)
├── ROL-GERENTE-GENERAL (BIZ_N1)
│   ├── ROL-JEFE-IT (BIZ_N2)
│   │   ├── ROL-SYSADMIN (BIZ_N3)
│   │   │   └── ROL-EXT-USUARIO-RESIDENCIAL (EXT_N0)
│   │   └── ROL-DESARROLLADOR (BIZ_N4)
│   │       └── ROL-EXT-CLIENTE-SAAS (EXT_N0)
│   ├── ROL-JEFE-RRHH (BIZ_N2)
│   │   └── ROL-ANALISTA-RRHH (BIZ_N4)
│   └── ROL-CONTADOR (BIZ_N3)
│       └── ROL-ASISTENTE-CONTABLE (BIZ_N5)
├── ROL-SYS-BANEXUS-DAEMON (SYS/M2M)
└── ... (547 nodos adicionales)
```

**Estado verificado en VPS (2026-07-10):**
- 548 roles · 547 con `parent_id` · 1 raíz (ROL-SYS-SUPERUSUARIO)
- Profundidad máxima: 7 niveles

### 4.3 El campo `hierarchy_level`

Entero que indica la profundidad del nodo desde la raíz. **No es una clasificación empresarial** — es una propiedad del árbol.

| Nivel | Total roles | Descripción típica |
|-------|-------------|-------------------|
| 0 | 1 | Raíz del sistema |
| 1 | 34 | Directivos top y daemons M2M directos |
| 2 | 152 | Mandos altos y jefaturas |
| 3 | 168 | Mandos medios y coordinadores |
| 4 | 144 | Profesionales y analistas |
| 5 | 40 | Operativos calificados |
| 6 | 8 | Operativos de base |
| 7 | 1 | Hoja más profunda del árbol |

**Cálculo:** `bauth_62__idn_role_closure.sql` Pase 3 recalcula `hierarchy_level` via `WITH RECURSIVE` cada vez que se reconstruye la closure. No se edita manualmente.

### 4.4 La closure table (`bauth.idn_role_closure`)

La closure es una **tabla derivada** que almacena todas las relaciones transitivas del árbol. Permite consultar en O(1) si un rol es ancestro de otro, sin recorrer el árbol.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `closure_id` | uuid PK | Identificador de la arista |
| `ancestro_id` | uuid FK | Rol padre/abuelo/raíz |
| `descendiente_id` | uuid FK | Rol hijo/nieto/hoja |
| `profundidad` | integer | Saltos entre ancestro y descendiente |
| `ctx_id` | text | Contexto de origen (`seed` / `seed-transitivo` / `runtime`) |

**Estado verificado en VPS (2026-07-10):**
- 547 aristas directas (profundidad=1)
- 1126 aristas transitivas
- **1673 filas totales**

**Regla de mantenimiento:** la closure es datos derivados — siempre se puede reconstruir desde `parent_id`. Ante cualquier cambio en el árbol, ejecutar `bauth_62__idn_role_closure.sql`.

---

## 5. Ciclo de vida del rol

### 5.1 Los 6 estados (`bauth.role_status_type`)

**Norma:** NIST SP 800-53 AC-2(j) — *"Disable accounts when no longer required."*

```
DRAFT ──► REVIEW ──► ACTIVE ◄──► SUSPENDED
                       │
                       ▼
                  DEPRECATED ──► ARCHIVED
```

| Estado | Descripción | Asignable a usuarios | Sincronizado KC/Tryton |
|--------|-------------|---------------------|------------------------|
| `DRAFT` | Definido, pendiente aprobación formal | No | No |
| `REVIEW` | En revisión por `role_owner` + aprobador | No | No |
| `ACTIVE` | En producción | **Sí** | **Sí** |
| `SUSPENDED` | Congelado temporalmente | No (usuarios existentes bloqueados en KC) | Parcial |
| `DEPRECATED` | Obsoleto — en proceso de retiro | No nuevos | Sí (usuarios existentes) |
| `ARCHIVED` | Cerrado definitivamente | No | No (eliminado de KC y Tryton) |

### 5.2 Reglas de transición

| Desde | Hacia | Quién puede | Condición |
|-------|-------|-------------|-----------|
| `DRAFT` | `REVIEW` | bAuth daemon | `change_reason` presente |
| `REVIEW` | `ACTIVE` | Aprobador autorizado | Aprobación formal registrada |
| `REVIEW` | `DRAFT` | Aprobador autorizado | Rechazo de la revisión |
| `ACTIVE` | `SUSPENDED` | SU / administrador | Emergencia o auditoría |
| `ACTIVE` | `DEPRECATED` | SU / role_owner | Plan de retiro aprobado |
| `SUSPENDED` | `ACTIVE` | Aprobador autorizado | Resolución del motivo de suspensión |
| `DEPRECATED` | `ARCHIVED` | SU | 0 usuarios asignados al rol |

**Regla absoluta:** ningún rol pasa de `ARCHIVED` a otro estado. El archivado es irreversible. Si se necesita el rol de nuevo, se crea como nuevo con `role_name` diferente.

### 5.3 El reconcile loop y drift

El daemon bAuth ejecuta un reconcile loop cada 60 segundos que compara el estado declarado en `bauth_db` contra el estado real en KC y Tryton. Si detecta drift:

- `sync_status = 'DRIFT'` en el campo `template`
- bAuth intenta auto-corrección
- Si falla, crea un evento de auditoría `DRIFT_DETECTED` y alerta al `role_owner`

### 5.4 Vigencia temporal (`role_validity_type`)

Dimensión **ortogonal** al `status`. Define cuánto tiempo puede existir un rol en el sistema, independientemente de su estado:

| Tipo | Descripción | `end_date` |
|------|-------------|-----------|
| `INDEFINITE` | Sin fecha fin — roles estructurales permanentes | NULL |
| `FIXED` | Fecha fin contractual — contratistas, proyectos | Obligatorio al crear |
| `PROJECT_BASED` | Hasta el cierre del proyecto (milestone) | Obligatorio al crear |
| `TEMPORARY` | Corta duración — calculado desde `created_at` | Calculado automáticamente |
| `EMERGENCY` | Máximo 72 horas — NIST AC-2(2) | `created_at + '72 hours'` |

---

## 6. Sistema de versiones

> ⚙ **En implementación** — G-B01-06 — DDL pendiente de ejecución en VPS

### 6.1 Las dos dimensiones de versión

| Campo | Semántica | Ejemplo | Cambia cuando |
|-------|-----------|---------|---------------|
| `template_version` | Versión del **esquema de contrato** (formato RolTemplate) | `1.0.0` | Se cambia el formato del contrato para todos los roles |
| `version` | Versión de la **definición individual** del rol | `1.0.0` | Se modifica este rol específico |

Ambas usan **SemVer 2.0.0** (`MAJOR.MINOR.PATCH`) con CHECK constraint:
```sql
CHECK (version ~ '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$')
```

### 6.2 Reglas de incremento para la versión del rol individual

| Cambio | Segmento | Consecuencia |
|--------|----------|-------------|
| Se revoca un permiso existente · cambia `loa_required` · cambia `tier` · modifica `sod_group` · cambia `mfa_required` | **MAJOR** `X+1.0.0` | `status` → `REVIEW` · `change_reason` obligatorio · `approved_by` pendiente |
| Se agrega permiso nuevo · amplía `scope` · cambia `applies_to_size` · modifica `review_period_days` | **MINOR** `X.Y+1.0` | `status` sin cambio · auto-aprobado |
| Corrección de descripción · ajuste de nombre · cambio en metadatos sin impacto en permisos | **PATCH** `X.Y.Z+1` | `status` sin cambio · auto-aprobado |
| Cambio de `status`, `parent_id`, `path_ids` | **Sin versión** | No es un cambio de definición — es gestión del ciclo de vida |

### 6.3 Tabla de historial: `bauth.idn_role_version_log`

Cada modificación a un rol genera una fila de auditoría:

| Columna | Tipo | Obligatorio | Descripción |
|---------|------|-------------|-------------|
| `id` | uuid PK | Siempre | uuidv7() — identificador de la entrada |
| `role_id` | uuid FK | Siempre | Rol modificado |
| `change_type` | `semver_change_type` ENUM | Siempre | MAJOR / MINOR / PATCH |
| `version_from` | text SemVer | Siempre | Versión antes del cambio |
| `version_to` | text SemVer | Siempre | Versión después del cambio |
| `fields_changed` | jsonb | Siempre | `{"campo": {"from": X, "to": Y}, ...}` |
| `change_reason` | text | Solo MAJOR | Justificación del cambio breaking |
| `changed_by` | text | Siempre | `agent_id` / `user_id` que ejecutó el cambio |
| `approved_by` | text | MAJOR aprobado | Quién aprobó el cambio breaking |
| `approved_at` | timestamptz | MAJOR aprobado | Cuándo se aprobó |
| `ctx_id` | text | Siempre | SBOS-049 Context Plane |
| `created_at` | timestamptz | Siempre | Timestamp del registro |

### 6.4 Protocolo bAuth para registrar un cambio

bAuth (código Rust, handler de modificación de roles) sigue este protocolo:

```
1. Leer estado actual del rol (version, status, campos)
2. Calcular qué campos cambian
3. Determinar change_type (MAJOR/MINOR/PATCH) según tabla §6.2
4. Si MAJOR y change_reason ausente → rechazar la operación (error 422)
5. Calcular version_to desde version_from según change_type
6. Si MAJOR → set status = 'REVIEW', cleared approved_by
7. Actualizar idn_role_template (campos + version)
8. INSERT en idn_role_version_log (auditoría)
9. Si MINOR/PATCH → marcar approved_by = changed_by (auto-aprobado)
10. Si MAJOR → notificar al role_owner vía bNotify para aprobación pendiente
```

**La lógica de versiones NO vive en triggers de BD** — vive en el handler Rust de bAuth. La BD solo valida formato SemVer y constraints de integridad.

---

## 7. Integración con Keycloak y Tryton

### 7.1 Principio de sincronización

bAuth sincroniza el estado de `idn_role_template` hacia los motores **antes del login, no durante**. El reconcile loop (60 s) detecta drift y corrige.

Solo los roles en estado `ACTIVE` se sincronizan. `DRAFT`, `REVIEW`, `SUSPENDED`, `DEPRECATED` y `ARCHIVED` no tienen representación activa en KC ni Tryton.

### 7.2 Integración con Keycloak 26.6.2

bAuth traduce cada `RolTemplate` → objetos nativos Keycloak:

| Objeto KC | Origen en idn_role_template |
|-----------|----------------------------|
| Realm Role | `role_name` + `tier` |
| Composite Role | herencia del árbol `parent_id` |
| Auth Flow | `loa_required` + `mfa_required` |
| User Attribute | `sod_group` + `max_sessions` |
| Session Policy | `session_timeout` |

**3 realms por tenant:**
- `<tenant>-internal` — usuarios internos (BIZ_N1–BIZ_N5, SYS, M2M)
- `<tenant>-external` — usuarios externos (EXT_N0, VISITANTE)
- `<tenant>-b2b` — federación con otros tenants

**Los 5 SPIs Java 21** amplían Keycloak para soportar las reglas de bAuth:

| SPI | Función |
|-----|---------|
| `RolTemporalAuthenticator` | Valida que la sesión no supere el tiempo definido en `session_timeout` del rol activo más restrictivo |
| `RolGeoAuthenticator` | Valida restricciones geográficas de acceso según el dominio D6 del rol |
| `RolRoleValidityAuthenticator` | Verifica que el rol asignado al usuario no esté `DEPRECATED` ni `ARCHIVED` |
| `RolUserConfiguredCondition` | Condición configurable por usuario para step-up selectivo |
| `RolStepUpCondition` | Implementa RFC 9470 — eleva LoA cuando el rol lo requiere en operaciones críticas |

### 7.3 Integración con Tryton — 5 capas de enforcement

| Capa | Objeto Tryton | Qué controla |
|------|---------------|--------------|
| 1 | `ir.model.access` | CRUD a nivel de modelo (tabla) |
| 2 | `ir.rule` | Filtros SQL por zona/tenant/contexto |
| 3 | `ir.model.button` | Visibilidad y acción de botones en UI |
| 4 | `ir.model.field` | Campos visibles/editables por rol |
| 5 | `ir.action.groups` | Menús y acciones visibles en la interfaz |

El mapeo `tier` → permisos Tryton sigue el principio de **privilegio mínimo** (NIST AC-6): cada tier tiene acceso solo a lo estrictamente necesario para su función.

---

## 8. Gestión operativa de roles

### 8.1 Crear un rol nuevo

```
1. Verificar que role_name no exista (UNIQUE constraint)
2. Seleccionar tier, type_id, scope, applies_to_size según la función del rol
3. Determinar parent_id en el árbol (¿de quién hereda?)
4. Definir loa_required, mfa_required, step_up_enabled según el nivel de riesgo
5. Asignar sod_group si el rol tiene conflictos potenciales con otros roles
6. Insertar en idn_role_template con status = 'DRAFT', version = '1.0.0'
7. INSERT en idn_role_version_log: version_from=NULL, version_to='1.0.0', change_type='MAJOR'
8. Iniciar flujo de aprobación (status → 'REVIEW')
9. Al aprobar: status → 'ACTIVE', trigger reconcile con KC y Tryton
10. Reconstruir closure (bauth_62) para incluir el nuevo nodo
```

### 8.2 Modificar un rol existente

Ver protocolo completo en **§6.4**. Regla principal: si el cambio afecta permisos (MAJOR), el rol vuelve a `REVIEW` y pierde `approved_by` hasta nueva aprobación.

### 8.3 Deprecar un rol

```
1. Verificar que existe un rol sucesor o que la función ya no es necesaria
2. status → 'DEPRECATED'
3. bNotify alerta a todos los usuarios con el rol activo
4. Periodo de gracia: 30 días (o según review_period_days)
5. Pasado el periodo: los usuarios son de-asignados automáticamente
6. bAuth elimina el rol de KC y Tryton (sync_status → 'REMOVED')
7. Cuando usuarios_activos = 0 → status puede pasar a 'ARCHIVED'
```

### 8.4 Autorización requerida por tipo de operación

| Operación | Autorización mínima | Rol requerido |
|-----------|--------------------|-|
| Crear rol `BIZ_N5` / `EXT_N0` | Auto-aprobado por administrador | `ROL-SYS-ADMIN-INFRA` |
| Crear rol `BIZ_N3` o superior | Aprobación de `role_owner` | `ROL-JEFE-IT` + `ROL-GERENTE-GENERAL` |
| Crear rol `SYS` / `M2M` | Aprobación dual | `ROL-SYS-SUPERUSUARIO` |
| Cambio MAJOR en cualquier rol | Aprobación de `role_owner` | Según tier del rol |
| Archivar cualquier rol | Solo SU | `ROL-SYS-SUPERUSUARIO` |
| Reactivar rol `SUSPENDED` | Aprobación formal documentada | `ROL-JEFE-SEGURIDAD` + `role_owner` |

---

## 9. Referencias

### 9.1 Normas aplicables

| Código | Norma | Aplica a |
|--------|-------|----------|
| NIST AC-2 | NIST SP 800-53 Rev.5 — Account Management | Tipos de cuenta, ciclo de vida, deshabilitación |
| NIST AC-5 | NIST SP 800-53 Rev.5 — Separation of Duties | `sod_group`, SoD matrix |
| NIST AC-6 | NIST SP 800-53 Rev.5 — Least Privilege | `loa_required`, `tier`, `applies_to_size` |
| NIST AC-10 | NIST SP 800-53 Rev.5 — Concurrent Session Control | `max_sessions` |
| NIST AC-12 | NIST SP 800-53 Rev.5 — Session Termination | `session_timeout` |
| NIST 800-63B | NIST SP 800-63B Rev.4 — Digital Identity | `loa_required`, `mfa_required`, AAL1-3 |
| INCITS 359 | ANSI INCITS 359-2012 (R2022) — RBAC Standard | Árbol de herencia, closure, tier |
| ISO 27001 A.5.18 | ISO 27001:2022 — Access Rights | `review_period_days`, vigencia |
| ISO 27001 A.8.2 | ISO 27001:2022 — Privileged Access Rights | `risk_level`, `audit_level` |
| ISO 27001 A.8.15 | ISO 27001:2022 — Logging | `audit_level`, eventos de ciclo de vida |
| ISO 27001 A.8.32 | ISO 27001:2022 — Change Management | `version`, `template_version`, historial |
| ISO 24760-2 | ISO/IEC 24760-2:2025 — Identity Management | `id`, `role_name`, ciclo de vida |
| RFC 9470 | Step-Up Authentication | `step_up_enabled`, SPIs KC |
| PCI DSS 4.0 | Req. 7 — Restrict Access | `review_period_days` = 90 para privilegiados |

### 9.2 Documentos relacionados en el proyecto

| Documento | Ubicación | Propósito |
|-----------|-----------|-----------|
| Catálogo de roles | `context/BAUTH-CATALOGO-ROLES-EMPRESARIALES.md` | 368+ roles, 66 plantillas, 7 tiers |
| Cadenas de jerarquía | `context/BAUTH-CADENAS-JERARQUIA.md` | 186 aristas DAG originales |
| Authentication Framework | `context/plandeaccion/Authentication_Framework.json` | 27+1 grupos, arquitectura completa |
| RolTemplate v6.0 | `context/SBOS-ROLTEMPLATE-v6_0.md` | 14 bloques JSONB contrato canónico |
| Reparación bAuth | `context/plandeaccion/REPARACIONBAUTH/` | Gaps detectados y resoluciones |
| DDL esquema | `../DDLs/seeds/bauth_48__idn_role_template.sql` | 548 roles, seed idempotente |
| Closure rebuild | `../DDLs/seeds/bauth_62__idn_role_closure.sql` | Reconstrucción del DAG |

### 9.3 Historial del manual

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.0.0 | 2026-07-10 | Versión inicial. Incorpora G-B01-03 (type_id), G-B01-04 (hierarchy_level), G-B01-05 (status ENUM), G-B01-06 (versiones — en implementación). Verificado contra VPS: 548 roles, closure 1673 filas. |
