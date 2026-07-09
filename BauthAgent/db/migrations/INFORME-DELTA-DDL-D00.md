# INFORME DELTA DDL — Dominio D00 Identidad Organizacional

**Documento:** INFORME-DELTA-DDL-D00
**Versión:** 2.0.0 · **Fecha:** 2026-07-06 · **Autor:** bauth-developer
**Estado:** PROPUESTA — requiere aprobación de Iván (ADR-016) antes de aplicar
**DDL objetivo:** `DDLs/migrations/bauth_10__d00_identidad_organizacional.sql`
**Normas:** ADR-016 · ADR-020 · SBOS-049 · NIST SP 800-63B · ISO 24760-2:2025

---

## ⚠️ ADVERTENCIA — CONFLICTO ARQUITECTÓNICO ACTIVO

Coexisten dos diseños incompatibles en la documentación. **Iván debe decidir cuál aplicar.**

| Diseño | Fuente | Átomos | Verbos | Estado en MASTER §6.3 |
|--------|--------|:------:|:------:|:---------------------:|
| **A — Semántico** (verbos-campo) | `BAUTH-D00-IDENTIDAD-ORGANIZACIONAL-MASTER.md §2.2` | 20 | 51-63 | ✅ Diseñado — listo para aprobación |
| **B — D.A.M.V.** (dominio×acción×campo) | `BAUTH-CATALOGO-ATOMOS-D00-CRUD.md` | ~80-120 | 1-4 + 51-63 | ⏳ Pendiente diseño — aprobación de concepto primero |

El MASTER (§6.3) dice explícitamente:
> "20 átomos D00 ✅ Diseñados — Aprobación DDL + aplicar migración 003"
> "Rediseño D.A.M.V. ⏳ Pendiente diseño — **Aprobación de concepto primero**"

**Este informe documenta el Diseño A (semántico) como candidato a aplicar**, por ser el único
aprobado según el MASTER. El Diseño B requiere decisión de concepto antes de cualquier DDL.

---

## 1. ESTADO REAL DE LA BD — EVIDENCIA DIRECTA

> Fuente: consultas ejecutadas en VPS de prueba `13.140.128.230`, base de datos `SBOS_db`,
> pod `postgresql-0` namespace `sbos-data`, 2026-07-06.

### 1.1 Tablas de privilegios — estado actual

| Objeto | Estado en BD | Detalle |
|--------|:------------:|---------|
| `privilege_verb` | ✅ 50 verbos | verb_code 1-50, confirmado |
| `privilege_domain` | ⚠️ D1-D12 solamente | CHECK: `domain_code BETWEEN 1 AND 15`. Falta D0 |
| `privilege_application` | ⚠️ apps 1-12 | No existe app_code=13 (Org) |
| `privilege_group` | ⚠️ 48 grupos | Solo para apps 1-12. Faltan 5 grupos Org |
| `privilege_atom` | ⚠️ 5808 átomos | Solo D1-D12. 0 átomos con domain_code=0 |
| `idn_tenant.is_internal` | ❌ No existe | Columna ausente — PASO 1 de la migración pendiente |

### 1.2 Tablas organizacionales existentes

Las tablas `org_*` **ya existen** en la BD (espejo del esquema base). Están en restructuración
y **NO deben ser creadas de nuevo**. Son la base de datos real del dominio D00.

| Tabla | Rows actuales | Jerarquía D00 | Campos clave |
|-------|:-------------:|:-------------:|-------------|
| `bauth.idn_tenant` | 1 (skull) | Tenant | tenant_id, tenant_slug, legal_name, tax_id, country |
| `bauth.org_empresa` | 1 (skull) | bDomain | empresa_id, tenant_id, razon_social, nit, locale_default, timezone_default |
| `bauth.org_sucursal` | 1 (skull-central) | bSubDomain | sucursal_id, empresa_id, nombre, direccion, zona, timezone |
| `bauth.org_pos_logico` | 0 | Pos | pos_id, sucursal_id, empresa_id, nombre, modalidad_facturacion |
| `bauth.idn_user_template` | 9 | Actor | uuid, email, empresa_id, sucursal_id, template (JSONB) |

### 1.3 Estado de los archivos DDL del directorio compartido

| Archivo | Estado | Problema |
|---------|--------|---------|
| `sbos_00__esquema_base.sql` | ✅ Completo | DDL principal unida. Fuente de verdad absoluta |
| `bauth_10__d00_identidad_organizacional.sql` | ⚠️ Incompleto | INSERT de domain, app, grupos, verbos y átomos todos comentados |
| `bauth_20__framework_politicas.sql` | ✅ Completo | Crea framework_raw y cfg_policy_library correctamente |
| `bauth_30__compliance_qa.sql` | ❌ Problemático | Usa `DROP TABLE IF EXISTS ... CASCADE` — destructivo, no idempotente |
| `bglobal_00__referencia.sql` | ℹ️ Solo puntero | No ejecuta nada. Documentación de referencias al esquema base |
| `bcalendar_00__referencia.sql` | ℹ️ Solo puntero | No ejecuta nada. Documentación de referencias al esquema base |

---

## 2. VERBOS EN LA BD — INVENTARIO COMPLETO CON NOMBRES EXPLÍCITOS

> **Fuente real:** `SELECT verb_code, verb_name, verb_slug FROM bauth.privilege_verb ORDER BY verb_code`
> ejecutado en SBOS_db el 2026-07-06. Los 50 verbos están cargados y confirmados.

### 2.1 Verbos existentes (verb_code 1-50) — confirmados en BD

#### Grupo CRUD base (1-4)
| verb_code | verb_name | verb_slug |
|:---------:|-----------|-----------|
| 1 | create | nuevo |
| 2 | update | editar |
| 3 | delete | eliminar |
| 4 | read | ver |

> ⚠️ **Nota de orden crítico:** verb_code 2 = `update` (no `read`), verb_code 4 = `read` (no `update`).
> El catálogo CRUD `BAUTH-CATALOGO-ATOMOS-D00-CRUD.md` tiene error: asigna R=2, U=3, D=4.
> El orden correcto verificado en BD es: create=1, **update=2**, **delete=3**, **read=4**.

#### Verbos SAP ACTVT (5-29)
| verb_code | verb_name | verb_slug |
|:---------:|-----------|-----------|
| 5 | print | imprimir |
| 6 | lock | bloquear |
| 7 | unlock | desbloquear |
| 8 | check | verificar |
| 9 | post | contabilizar |
| 10 | release | liberar |
| 11 | undo_release | deshacer_liberar |
| 12 | complete | completar |
| 13 | reverse | reversar |
| 14 | execute | ejecutar |
| 15 | approve | aprobar |
| 16 | reject | rechazar |
| 17 | block_entity | bloquear_entidad |
| 18 | unblock_entity | desbloquear_entidad |
| 19 | archive | archivar |
| 20 | copy | copiar |
| 21 | save | guardar |
| 22 | submit | enviar |
| 23 | transfer | transferir |
| 24 | close | cerrar |
| 25 | reopen | reabrir |
| 26 | display_totals | ver_totales |
| 27 | display_items | ver_partidas |
| 28 | settle_rule | liquidar_regla |
| 29 | settle_params | param_liq |

#### Verbos Tryton + Dynamics + ServiceNow (30-46)
| verb_code | verb_name | verb_slug |
|:---------:|-----------|-----------|
| 30 | duplicate | duplicar |
| 31 | export | exportar |
| 32 | import | importar |
| 33 | reconcile | conciliar |
| 34 | validate | validar |
| 35 | void | anular |
| 36 | draft | borrador |
| 37 | confirm | confirmar |
| 38 | assign | asignar |
| 39 | share | compartir |
| 40 | append | anexar |
| 41 | append_to | ser_anexado |
| 42 | schedule | programar |
| 43 | delegate | delegar |
| 44 | impersonate | suplantar |
| 45 | notify | notificar |
| 46 | configure | configurar |

#### Verbos especiales de acceso privilegiado (47-50)
| verb_code | verb_name | verb_slug |
|:---------:|-----------|-----------|
| 47 | schedule_task | programar_tarea |
| 48 | delegate_access | delegar_acceso |
| 49 | impersonate_user | suplantar_usuario |
| 50 | emergency_access | acceso_emergencia |

---

### 2.2 Verbos que se deben agregar para D00 (verb_code 51-63)

> **Fuente:** `bauth_10__d00_identidad_organizacional.sql` PASO 6 (actualmente comentado).
> Fuente documental: `BAUTH-D00-IDENTIDAD-ORGANIZACIONAL-MASTER.md §2.3`.
> Estos verbos NO son verbos de acción/negocio — son **verbos de atributo de identidad**:
> cada uno representa un campo específico de una entidad del dominio organizacional.
> Un átomo D00 con verb_code=53 (nit) dice "este rol puede ver/gestionar el NIT de esa entidad".

| verb_code | verb_name | verb_slug | Campo que representa | Entidad |
|:---------:|-----------|-----------|----------------------|---------|
| 51 | Tipo | type | Tipo de entidad (enum) | Tenant, bDomain, bSubDomain, Pos, Actor |
| 52 | Nombre | nombre | Nombre o razón social | bDomain, bSubDomain, Pos, Actor |
| 53 | NIT | nit | NIT / número tributario | bDomain (`org_empresa.nit`) |
| 54 | Email | email | Correo electrónico | bDomain, Actor |
| 55 | Teléfono | telefono | Número telefónico | bDomain, Actor |
| 56 | Carnet | ci | Carnet de identidad (CI) | Actor (`idn_user_template.template`) |
| 57 | Dirección | direccion | Dirección física | bDomain, bSubDomain (`org_sucursal.direccion`) |
| 58 | Tipo empleo | employee_type | Modalidad de contrato | Actor (`idn_user_template.template`) |
| 59 | Género | gender | Género | Actor (`idn_user_template.template`) |
| 60 | Estado civil | marital_status | Estado civil | Actor (`idn_user_template.template`) |
| 61 | Tipo documento | id_doc_type | Tipo de documento de identidad | Actor (`idn_user_template.template`) |
| 62 | Locale | locale | Locale BCP 47 (es-BO) | bDomain (`org_empresa.locale_default`) |
| 63 | Zona horaria | timezone | Zona horaria IANA | bDomain (`org_empresa.timezone_default`), bSubDomain (`org_sucursal.timezone`) |

**Total verbos a agregar para D00: 13 (verb_code 51 a 63)**

---

## 3. ESTRUCTURA DE LOS 20 ÁTOMOS D00 — DISEÑO SEMÁNTICO

> Fuente: `bauth_10__d00_identidad_organizacional.sql` PASO 7 (actualmente comentado).
> **Posición inicial:** 5809 (después de los 5808 átomos dinámicos D1-D12).
> **Fórmula de máscaras (MANUAL_DB_DDL.md §4.2/4.3):**
> - contextual_mask = (domain_code << 8) | (app_code << 12) | (group_code << 21)
> - logical_mask = verb_code << 8
> - domain_code=0, app_code=13 → base_contextual = (0<<8)|(13<<12) = 53248

| atom_position | atom_slug | app | grupo | domain | verb_code | verb_name | Entidad |
|:-------------:|-----------|:---:|:-----:|:------:|:---------:|-----------|---------|
| 5809 | org.g1.d0.type | 13 | 1 | 0 | 51 | Tipo | Tenant |
| 5810 | org.g2.d0.type | 13 | 2 | 0 | 51 | Tipo | bDomain |
| 5811 | org.g2.d0.nombre | 13 | 2 | 0 | 52 | Nombre | bDomain |
| 5812 | org.g2.d0.nit | 13 | 2 | 0 | 53 | NIT | bDomain |
| 5813 | org.g2.d0.email | 13 | 2 | 0 | 54 | Email | bDomain |
| 5814 | org.g2.d0.telefono | 13 | 2 | 0 | 55 | Teléfono | bDomain |
| 5815 | org.g2.d0.ci | 13 | 2 | 0 | 56 | Carnet | bDomain |
| 5816 | org.g2.d0.direccion | 13 | 2 | 0 | 57 | Dirección | bDomain |
| 5817 | org.g3.d0.type | 13 | 3 | 0 | 51 | Tipo | bSubDomain |
| 5818 | org.g3.d0.nombre | 13 | 3 | 0 | 52 | Nombre | bSubDomain |
| 5819 | org.g3.d0.direccion | 13 | 3 | 0 | 57 | Dirección | bSubDomain |
| 5820 | org.g4.d0.type | 13 | 4 | 0 | 51 | Tipo | Pos |
| 5821 | org.g4.d0.nombre | 13 | 4 | 0 | 52 | Nombre | Pos |
| 5822 | org.g5.d0.type | 13 | 5 | 0 | 51 | Tipo | Actor |
| 5823 | org.g5.d0.employee_type | 13 | 5 | 0 | 58 | Tipo empleo | Actor |
| 5824 | org.g5.d0.gender | 13 | 5 | 0 | 59 | Género | Actor |
| 5825 | org.g5.d0.marital_status | 13 | 5 | 0 | 60 | Estado civil | Actor |
| 5826 | org.g5.d0.id_doc_type | 13 | 5 | 0 | 61 | Tipo documento | Actor |
| 5827 | org.g5.d0.locale | 13 | 5 | 0 | 62 | Locale | Actor |
| 5828 | org.g5.d0.timezone | 13 | 5 | 0 | 63 | Zona horaria | Actor |

**Total átomos D00 (diseño semántico): 20 (posiciones 5809-5828)**

---

## 4. DELTA EXACTO — QUÉ FALTA APLICAR

### 4.1 En `bauth_10__d00_identidad_organizacional.sql`

Los siguientes pasos están **comentados** y deben completarse (descomentarse o moverse a seeds):

| Paso | Descripción | Objeto afectado | Acción requerida |
|:----:|-------------|----------------|-----------------|
| PASO 1 | ADD COLUMN `is_internal` BOOLEAN a `idn_tenant` | `bauth.idn_tenant` | ✅ Ya en DDL (no comentado) |
| PASO 2 | DROP + ADD CHECK `domain_code BETWEEN 0 AND 15` | `bauth.privilege_domain` | ✅ Ya en DDL (no comentado) |
| PASO 3 | INSERT domain_code=0 'Identidad Organizacional' | `bauth.privilege_domain` | ⚠️ Comentado — mover a seed |
| PASO 4 | INSERT app_code=13 'Org' | `bauth.privilege_application` | ⚠️ Comentado — mover a seed |
| PASO 5 | INSERT 5 grupos (Tenant, bDomain, bSubDomain, Pos, Actor) | `bauth.privilege_group` | ⚠️ Comentado — mover a seed |
| PASO 6 | INSERT verbos 51-63 (13 verbos de atributo) | `bauth.privilege_verb` | ⚠️ Comentado — mover a seed |
| PASO 7 | INSERT 20 átomos D00 (posiciones 5809-5828) | `bauth.privilege_atom` | ⚠️ Comentado — mover a seed |
| PASO 8 | INSERT tenant externo DEPO srl | `bauth.idn_tenant` | ⚠️ Comentado — datos de ejemplo, aprobar con Iván |

### 4.2 Seeds que deben actualizarse

Los seeds actuales usan `TRUNCATE CASCADE` — si se re-ejecutan DESPUÉS de la migración D00,
borrarán los datos de D00. Deben actualizarse para incluir D00:

| Seed | Cambio requerido | Impacto si no se actualiza |
|------|-----------------|---------------------------|
| `seed_privilege_domain.sql` | Agregar fila domain_code=0 'Identidad Organizacional' | TRUNCATE borra D00 al re-ejecutar |
| `seed_privilege_application.sql` | Agregar fila app_code=13 'Org' | TRUNCATE borra app Org al re-ejecutar |
| `seed_privilege_group.sql` | Agregar 5 grupos para app_code=13 | TRUNCATE borra grupos Org al re-ejecutar |
| `seed_privilege_verb.sql` | Agregar verbos 51-63 | TRUNCATE borra verbos D00 al re-ejecutar |
| `seed_privilege_atom.sql` | Agregar condición `OR (v.verb_code BETWEEN 51 AND 63 AND d.domain_code = 0)` al WHERE | TRUNCATE borra átomos D00 al re-ejecutar |

### 4.3 Problema detectado en `bauth_30__compliance_qa.sql`

Este archivo usa el patrón `DROP TABLE IF EXISTS ... CASCADE` antes de `CREATE TABLE IF NOT EXISTS`.
El patrón correcto del proyecto es `CREATE TABLE IF NOT EXISTS` sin DROP previo.
El `DROP CASCADE` borrará los datos de compliance acumulados al re-ejecutar.

**Acción requerida:** Reescribir `bauth_30__compliance_qa.sql` eliminando los `DROP TABLE IF EXISTS CASCADE`
y dejando solo `CREATE TABLE IF NOT EXISTS`. Requiere aprobación (ADR-016).

---

## 5. TABLAS ORGANIZACIONALES — RELACIÓN CON D00

Las tablas `org_*` existen en la BD y representan la jerarquía del Dominio D00.
**Están en restructuración** (no completas). No crear tablas nuevas — estas son las canónicas.

```
idn_tenant (Tenant)
    └── org_empresa (bDomain)         ← NIT, locale, timezone, razón social
            └── org_sucursal (bSubDomain)  ← nombre, dirección, zona, timezone
                    └── org_pos_logico (Pos) ← punto de venta, CUIS SIN
                            └── idn_user_template (Actor) ← usuario, roles, CI, género
```

**Correspondencia verbos D00 ↔ campos de tablas existentes:**

| verb_code | verb_name | Tabla org | Columna |
|:---------:|-----------|-----------|---------|
| 51 | Tipo | (enum en app logic) | tenant_type, regimen_fiscal, modalidad_facturacion |
| 52 | Nombre | org_empresa, org_sucursal, org_pos_logico | razon_social, nombre, nombre |
| 53 | NIT | org_empresa | nit |
| 54 | Email | idn_tenant, idn_user_template | legal_contact_email, template.email |
| 55 | Teléfono | idn_user_template | template.phone |
| 56 | Carnet | idn_user_template | template.ci |
| 57 | Dirección | org_sucursal | direccion |
| 58 | Tipo empleo | idn_user_template | template.employee_type |
| 59 | Género | idn_user_template | template.gender |
| 60 | Estado civil | idn_user_template | template.marital_status |
| 61 | Tipo documento | idn_user_template | template.id_doc_type |
| 62 | Locale | org_empresa | locale_default |
| 63 | Zona horaria | org_empresa, org_sucursal | timezone_default, timezone |

---

## 6. ORDEN DE EJECUCIÓN PROPUESTO

Una vez que Iván apruebe el diseño semántico (ADR-016):

```
1. Ejecutar bauth_10__d00_identidad_organizacional.sql
   → Solo aplica PASO 1 (is_internal) y PASO 2 (CHECK domain_code)
   → Verificar: SELECT column_name FROM information_schema.columns
                WHERE table_name='idn_tenant' AND column_name='is_internal';
   → Verificar: SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='ck_domain_code';

2. Actualizar seed_privilege_domain.sql → agregar domain_code=0
3. Actualizar seed_privilege_application.sql → agregar app_code=13
4. Actualizar seed_privilege_group.sql → agregar 5 grupos
5. Actualizar seed_privilege_verb.sql → agregar verbos 51-63
6. Actualizar seed_privilege_atom.sql → agregar condición D00

7. Ejecutar seeds en orden (dependencias FK):
   seed_privilege_domain.sql → seed_privilege_application.sql →
   seed_privilege_group.sql → seed_privilege_verb.sql → seed_privilege_atom.sql

8. Verificar resultado final:
   SELECT count(*) FROM bauth.privilege_atom WHERE domain_code = 0; → debe ser 20
   SELECT count(*) FROM bauth.privilege_verb WHERE verb_code BETWEEN 51 AND 63; → debe ser 13
   SELECT count(*) FROM bauth.privilege_domain; → debe ser 13 (D0 + D1-D12)
```

---

## 7. PENDIENTES QUE REQUIEREN DECISIÓN DE IVÁN

| # | Decisión | Urgencia | Impacto si no se decide |
|---|----------|:--------:|------------------------|
| 1 | **¿Diseño A (semántico, 20 átomos) o Diseño B (D.A.M.V., ~80-120 átomos)?** | 🔴 Alta | Sin esta decisión no se puede completar ningún seed ni migración D00 |
| 2 | ¿Incluir tenant DEPO srl como ejemplo en la migración? | 🟡 Media | La migración puede aplicarse sin ese dato |
| 3 | ¿Reescribir `bauth_30__compliance_qa.sql` eliminando DROP CASCADE? | 🟡 Media | Riesgo de pérdida de datos de compliance al re-ejecutar |
| 4 | ¿Las tablas `org_*` continúan en restructuración o se congelan para D00? | 🟠 Alta | Los átomos D00 apuntan a campos de org_* — si cambia el schema cambian los verbos |

---

## 8. RESUMEN EJECUTIVO

**Lo que existe hoy en la BD real (SBOS_db en VPS 13.140.128.230):**
- 50 verbos (create, update, delete, read + 46 de negocio)
- 12 dominios (D1-D12), sin D0
- 12 aplicaciones (apps 1-12), sin app Org (13)
- 48 grupos, sin grupos Org
- 5808 átomos (solo D1-D12)
- Tablas org_empresa, org_sucursal, org_pos_logico, idn_user_template: existen
- `idn_tenant.is_internal`: columna ausente

**Lo que falta para tener D00 operativo:**
- Columna `is_internal` en `idn_tenant` (PASO 1 de la migración — está en el DDL pero no ejecutado)
- CHECK ampliado `domain_code BETWEEN 0 AND 15` (PASO 2 — está en el DDL pero no ejecutado)
- 1 dominio nuevo (D0), 1 app nueva (Org/13), 5 grupos, 13 verbos, 20 átomos → todos en seeds
- Actualización de los 5 seeds existentes para que TRUNCATE no destruya D00

**Bloqueante:** Decisión de Iván sobre Diseño A vs Diseño B (§7, item 1).
