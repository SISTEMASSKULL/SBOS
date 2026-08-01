# Manual de Documentación Estratificada — SBOSDB

**Código:** SBOS-DB-DOC-001  
**Versión:** 1.1.0  
**Fecha de emisión:** 2026-08-01  
**Clasificación:** OPERACIONAL — uso interno por agentes y programadores  
**Alcance:** Todos los archivos DDL del proyecto SBOS · 4 schemas · Base de datos SBOSDB  
**Custodio:** Bibliotecario ORQUESTA (lectura libre; cambio requiere HITL)

---

## Preámbulo

Este manual define el sistema obligatorio de documentación de la base de datos SBOSDB. No es
una propuesta ni una guía de estilo: es el estándar operacional que todo agente y programador
debe aplicar al crear o modificar cualquier tabla en los archivos DDL del proyecto.

El incumplimiento de este estándar es una causa de rechazo por el Revisor y bloquea el merge
a `main`.

---

## §1 Propósito y justificación

SBOSDB es la base de datos de un Identity Control Plane empresarial. Sus tablas sustentan
autenticación, autorización, firma digital, auditoría forense, acceso físico y facturación
electrónica. Con más de 200 tablas padre distribuidas en 4 schemas interrelacionados, el modelo
de datos es en sí mismo infraestructura crítica de gobernanza.

Un agente que no entiende el modelo toma decisiones incorrectas: escribe en la tabla equivocada,
omite campos de trazabilidad obligatorios, no respeta restricciones WORM, o consulta datos sin
el contexto de seguridad correcto. En un sistema IAM estos errores no son bugs menores — son
vectores de brecha de seguridad o de incumplimiento normativo (ISO 27001, GDPR, Ley 164 Bolivia).

**La documentación de la base de datos no es documentación técnica accesoria. Es parte de la
infraestructura de gobernanza del sistema.**

---

## §2 Inventario de archivos DDL

La base de datos SBOSDB está definida en **3 archivos DDL separados** (separación por tamaño de
archivo — no fusionar):

| Archivo | Schemas | Tablas padre | COMMENT ON TABLE | Score 6/6 |
|---------|---------|:------------:|:----------------:|:---------:|
| `DDLs/SBOS_db_V2_DDL.sql` | `bauth`, `bglobal`, `bcalendar` | ~136 | 100 % | 100 % |
| `DDLs/bos_01__control_plane.sql` | `bos` | ~22 | 100 % | 100 % |
| `DDLs/migrations/bauth_dominios_pendientes_v2.0.sql` | `bauth` | 81 padre + 21 particiones | 100 % tablas padre | 100 % |

> Las 21 tablas restantes en el archivo de migraciones son **particiones por fecha**
> (`_2026_07`, `_2026_08`, `_default`). Las particiones heredan el COMMENT de la tabla
> padre — no llevan COMMENT propio. No son tablas pendientes.

El índice completo de tablas vive en `DDLs/catalog_sbos.yml` (kardex del proyecto).  
El manual de la DDL (intención detrás de cada tabla) vive en `DDLs/SBOS_db_V2_DDL_MANUAL.md`.

**Estado de sincronización:** VPS (SBOSDB) · archivos DDL · `catalog_sbos.yml` deben estar
siempre sincronizados. Verificar con el script §5.1 antes de cada sesión de trabajo.

---

## §3 Estándar de documentación

### §3.1 Estructura canónica de COMMENT ON TABLE

Todo `COMMENT ON TABLE` del proyecto debe contener exactamente los siguientes 6 elementos,
en el mismo orden, dentro del string SQL:

```
[1] ÁREA FUNCIONAL | Propósito en una oración precisa.
[2] Fuente: <proceso exacto que inserta datos aquí>.
[3] Administración: <quién gestiona, frecuencia, restricciones de modificación>.
[4] WORM: <sí — motivo y mecanismo> | no.
[5] Particionada: <sí — clave y frecuencia de nueva partición> | no.
[6] Estándar: <normas aplicables>. T-<código>.
```

**Ejemplo conforme (score 6/6):**
```sql
-- [DOC:DONE]
COMMENT ON TABLE bauth.auth_method IS
  'AUTENTICACIÓN | Catálogo declarativo del MethodRegistry — define los métodos '
  'de autenticación disponibles con su LoA, resistencia a phishing y estándar rector. '
  'Fuente: seed inicial al desplegar el tenant; actualizaciones vía migración + HITL '
  'cuando se incorpora o depreca un método (no se modifica en caliente). '
  'Administración: tabla de referencia inmutable en producción; todo cambio requiere '
  'migración explícita, revisión del auth_saga_catalog asociado y re-seed en entornos. '
  'WORM: no — los métodos pueden actualizarse; nunca se eliminan (solo deprecated). '
  'Particionada: no. '
  'Estándar: NIST SP 800-63B-4 §5, FIDO2/WebAuthn W3C Level 3, RFC 6749, RFC 9449. T-335.';
```

**Ejemplo no aceptable (score 1/6 — rechazado):**
```sql
-- [DOC:TODO]
COMMENT ON TABLE bauth.auth_method IS
  'Catálogo de métodos de autenticación.';
```

**Score mínimo para merge:** ≥ 5 de 6 elementos presentes.

### §3.2 Criterio de inclusión para COMMENT ON COLUMN

Documentar una columna es **obligatorio** si cumple al menos uno de estos criterios:

| Criterio | Ejemplos en SBOSDB |
|----------|---------------------|
| Nombre abreviado o ambiguo | `ctx_id`, `ip_hash`, `fal`, `aal_produced`, `ial` |
| Tipo genérico con estructura interna no obvia | `metadata JSONB`, `config JSONB`, `steps JSONB` |
| Restricción de seguridad no expresable en DDL | `vault_key_path` — nunca el valor, solo la ruta en Vault |
| Valor calculado automáticamente por trigger | `hash_actual` — nunca lo calcula la app |
| Dato anonimizado por norma | `ip_hash` — GDPR Art. 5(1)(c); nunca IP en claro |
| Enum no autodescriptivo en el dominio del negocio | `outcome` con valores 'PERMIT'/'STEP_UP_REQUIRED'/'DENIED' |
| FK cuya semántica no es evidente | `actor_id` — puede ser humano, NHI, daemon o bot |

### §3.3 Áreas funcionales canónicas (19)

Toda tabla pertenece a exactamente una de las siguientes áreas. El COMMENT ON TABLE **debe**
comenzar con este nombre exacto (en mayúsculas) para permitir extracción automática por área:

```
GLOBAL · TENANT · CALENDARIO · ROLES · VERSIONADO · IDENTIDAD · NHI ·
USUARIOS · AUTENTICACIÓN · SESIÓN · PRIVILEGIOS · FIRMA DIGITAL ·
WALLET · AUDITORÍA IGA · BLOCKCHAIN · PAM · CONTEXT PLANE ·
DOMINIOS CONTROL (D02–D15) · META-REGISTRO (D98-D99)
```

### §3.4 Marcadores de estado en el archivo .sql

Cada tabla lleva un marcador encima del `CREATE TABLE`:

```sql
-- [DOC:DONE]    ← score ≥5/6 + columnas cubiertas + verificado en SBOSDB_copia
-- [DOC:REVIEW]  ← COMMENT escrito en el .sql, pendiente verificación en BD
-- [DOC:TODO]    ← pendiente de documentar (default para tablas nuevas)
```

El script §5.1 actualiza estos marcadores automáticamente.

---

## §4 Arquitectura del sistema en 3 capas

```
CAPA 0 ── COMMENT ON (en los archivos .sql)
│   Fuente única de verdad técnica. Persiste en pg_description.
│   Siempre sincronizado con el DDL. Queryable por cualquier herramienta SQL.
│   ↓ genera automáticamente
├── CAPA 1 ── DDLs/catalog_sbos.yml (un solo archivo)
│   Consumo rápido por agentes IA. ~18 campos por tabla (fqn, ddl_archivo,
│   ddl_linea, t_code, schema, resumen, fuente, worm, particionada, score...).
│   Generado por DDLs/tools/generar_catalog.sh desde pg_description.
│   No se edita a mano. Se regenera tras cada migración.
│   ↓ sirve de base para
└── CAPA 2 ── Manuales por área funcional (bajo demanda)
    Referencia profunda para programadores. Describe flujos completos,
    semántica de columnas, ejemplos operativos, reglas de administración.
    Se crea cuando el área entra en desarrollo activo.
    Ubicación: BauthAgent/context/Documentacion/anexos/A.65.02.NN_*.md
```

### §4.1 Consultas operativas estándar (Capa 0)

```sql
-- Propósito de una tabla específica
SELECT obj_description('bauth.auth_method'::regclass, 'pg_class');

-- Catálogo completo con score calculado en runtime
SELECT
    n.nspname                                            AS schema,
    c.relname                                            AS tabla,
    LEFT(obj_description(c.oid, 'pg_class'), 120)        AS resumen,
    (   (obj_description(c.oid,'pg_class') ~* 'fuente:')::int
      + (obj_description(c.oid,'pg_class') ~* 'administra')::int
      + (obj_description(c.oid,'pg_class') ~* 'T-[0-9]+')::int
      + (obj_description(c.oid,'pg_class') ~* 'estándar|ISO|NIST|RFC|PCI|GDPR')::int
      + (obj_description(c.oid,'pg_class') ~* 'WORM|particion')::int
      + (length(obj_description(c.oid,'pg_class')) > 80)::int
    )                                                    AS score_6
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('bauth','bglobal','bcalendar','bos')
  AND c.relkind = 'r'
  AND c.relispartition = false
ORDER BY score_6 ASC, n.nspname, c.relname;

-- Columnas sin documentar en una tabla
SELECT a.attname, format_type(a.atttypid, a.atttypmod)
FROM pg_attribute a
WHERE a.attrelid = 'bauth.auth_method'::regclass
  AND a.attnum > 0
  AND NOT a.attisdropped
  AND col_description(a.attrelid, a.attnum) IS NULL
ORDER BY a.attnum;
```

### §4.2 Estructura del catalog_sbos.yml

```yaml
# DDLs/catalog_sbos.yml
# GENERADO AUTOMÁTICAMENTE — no editar a mano
# Comando: ./DDLs/tools/generar_catalog.sh SBOSDB
generado_en: "2026-08-01T00:00:00Z"
fuente: "pg_description de SBOSDB"
total_tablas_padre: 246
cobertura_comment_on_table: "64%"
cobertura_score_alto: "21%"

areas:
  AUTENTICACION:
    tablas:
      - fqn: bauth.auth_method
        ddl_archivo: "DDLs/SBOS_db_V2_DDL.sql"
        ddl_linea: 3560
        t_code: "T-335"
        schema: bauth
        tabla: auth_method
        resumen: "Catálogo declarativo del MethodRegistry — 18 métodos con LoA y estándar rector"
        fuente: "seed + HITL"
        administracion: "inmutable en producción; cambios por migración"
        worm: false
        particionada: false
        columnas_documentadas: 6
        score: 6
        estandares: ["NIST SP 800-63B-4 §5", "FIDO2/WebAuthn W3C L3"]
```

---

## §5 Herramientas

### §5.1 Script de verificación — `DDLs/tools/verificar_documentacion.sh`

Emite el reporte de avance por tabla y schema. Salida esperada:

```
REPORTE DE DOCUMENTACIÓN — SBOSDB — 2026-08-01
================================================
Schema     Tabla                          Score   Cols  Estado
---------  -----------------------------  ------  ----  ----------
bauth      auth_method                    6/6     ✓     DONE
bauth      auth_policy                    2/6     ✗     IN_PROGRESS
bauth      idn_global_admin               0/6     ✗     NOT_STARTED
...

RESUMEN
  DONE        :  38 /246  (15 %)
  IN_PROGRESS :  90 /246  (37 %)
  NOT_STARTED :  88 /246  (36 %)
  REVIEW      :   0 /246   (0 %)
  BLOCKED     :   0 /246   (0 %)

COBERTURA OBJETIVO: 100 % DONE
BRECHA ACTUAL     : 208 tablas (85 %)
```

**Cuándo ejecutarlo:**
- Al iniciar cualquier sesión de documentación (línea base de la sesión)
- Al cerrar una sesión (delta de avance)
- Como hook pre-commit (gate de calidad — bloquea si hay tablas nuevas sin `[DOC:TODO]`)
- Al regenerar `catalog_sbos.yml` (gate de generación)

### §5.2 Script de generación — `DDLs/tools/generar_catalog.sh`

Genera `catalog_sbos.yml` leyendo `pg_description` de SBOSDB. No reemplaza
a `verificar_documentacion.sh` — lo complementa.

```bash
./DDLs/tools/generar_catalog.sh SBOSDB
```

El script: (1) conecta a SBOSDB, (2) lee `pg_class + pg_namespace + obj_description`,
(3) calcula score por tabla, (4) escribe `DDLs/catalog_sbos.yml` en formato YAML agrupado
por área funcional.

**No editar `catalog_sbos.yml` a mano.** Todo cambio en el catálogo se hace en el
`COMMENT ON TABLE` del archivo `.sql` correspondiente y luego se regenera.

---

## §6 Sistema de control de avance

### §6.1 Definición de Done (DoD) por tabla

Una tabla se considera **DONE** cuando cumple simultáneamente los 5 criterios:

| # | Criterio | Verificación |
|---|----------|--------------|
| 1 | `COMMENT ON TABLE` presente en el archivo `.sql` | `grep 'COMMENT ON TABLE <tabla>'` |
| 2 | Score ≥ 5/6 en los 6 elementos del estándar §3.1 | `verificar_documentacion.sh` |
| 3 | Todas las columnas con criterio §3.2 tienen `COMMENT ON COLUMN` | `verificar_documentacion.sh` |
| 4 | El `COMMENT ON` existe en el archivo `.sql` fuente (no solo en BD) | `grep` sobre el archivo DDL |
| 5 | Verificado en SBOSDB_copia sin errores | Ejecutar el DDL en copia y re-verificar |

### §6.2 Estados por tabla

| Estado | Definición | Transición |
|--------|-----------|-----------|
| `NOT_STARTED` | Sin `COMMENT ON TABLE` en el `.sql` | → `IN_PROGRESS` al empezar |
| `IN_PROGRESS` | `COMMENT ON TABLE` escrito en el `.sql` pero no verificado en BD | → `REVIEW` tras ejecutar en copia |
| `REVIEW` | Ejecutado en copia; score < 5 o columnas con criterio sin documentar | → `IN_PROGRESS` para corrección |
| `DONE` | Los 5 criterios §6.1 cumplidos | Estado final; no regresa |
| `BLOCKED` | Requiere decisión de dominio que el agente no puede resolver solo | → HITL desbloquea |

### §6.3 Reglas de sesión

1. **Registrar antes de ejecutar:** declarar qué tablas se van a documentar al iniciar la sesión.
2. **Un dominio por sesión:** procesar un área funcional completa, no saltar entre áreas.
3. **Verificar antes de cerrar:** ejecutar `verificar_documentacion.sh` al cerrar y registrar el delta.
4. **No mezclar DONE y NOT_STARTED en un mismo commit:** un commit de documentación solo
   avanza tablas; no mezcla creación de tablas nuevas.

---

## §7 Roadmap de implementación

Las fases están ordenadas por impacto. Criterio de entrada de cada fase: la anterior cerrada
(0 tablas en estado anterior a `DONE` para el lote de esa fase).

### Fase 0 — Infraestructura de control

**Trabajo:**
1. Crear `DDLs/tools/verificar_documentacion.sh` — reporte de avance
2. Crear `DDLs/tools/generar_catalog.sh` — genera `catalog_sbos.yml` desde pg_description
3. Ejecutar el script contra SBOSDB → establece la línea base oficial
4. Registrar la línea base en `DDLs/LINEA-BASE-DOCUMENTACION.md`

**Criterio de salida:** Ambos scripts ejecutan sin errores. Línea base registrada con fecha y
commit SHA. **Estimado: 1 sesión.**

---

### Fase 1 — Tablas sin ninguna documentación ✅ COMPLETADA

**Estado:** Todas las 81 tablas padre del archivo de migraciones tienen COMMENT ON TABLE
con score 6/6. Documentadas durante la sesión 2026-07-31.

Las 21 tablas restantes son particiones por fecha (no tablas padre) — no requieren COMMENT.

**Criterio de salida:** Cumplido. `NOT_STARTED` = 0.

---

### Fase 2 — Reescritura de comentarios con score 0–2/6 (~19 tablas)

**Tablas identificadas en el diagnóstico inicial:**

| Área | Tablas |
|------|--------|
| Framework de autenticación | `auth_compliance_map`, `auth_config`, `auth_crypto_algorithm`, `auth_policy`, `auth_saga_catalog` |
| Firma digital | `sig_adsib_lifecycle`, `sig_certificate`, `sig_document_hash`, `sig_document_policy`, `sig_key`, `sig_operation_log` |
| Blockchain | `blk_anchor`, `blk_merkle_leaf`, `blk_reconciliation` |
| Wallet / VC | `wallet`, `wallet_issuance_log` |
| Calendario | `cal_fiscal_year`, `cal_holiday` |

**Trabajo:** Reescribir el `COMMENT ON TABLE` completo con los 6 elementos. El contenido
previo se descarta — con score 0–2/6 no es rescatable parcialmente.

**Criterio de salida:** Score bajo (0–2/6) en `SBOS_db_V2_DDL.sql` = 0.  
**Estimado: 2 sesiones.**

---

### Fase 3 — Completar elementos faltantes en score medio 3–4/6 (~81 tablas)

**Tablas:** ~70 de score medio en `SBOS_db_V2_DDL.sql` + ~11 en `bos_01__control_plane.sql`.

**Elementos más frecuentemente ausentes (añadir sin reescribir lo existente):**

| Elemento | Ausente en |
|----------|:----------:|
| Reglas de administración | ~79 % de tablas con score medio |
| Fuente de alimentación | ~68 % |
| Etiqueta de área funcional | ~40 % |
| Estándares aplicables | ~32 % |

**Criterio de salida:** Score ≥ 5/6 en el 100 % de `SBOS_db_V2_DDL.sql` y `bos_01`.  
**Estimado: 4 sesiones.**

---

### Fase 4 — COMMENT ON COLUMN en columnas con criterio §3.2

**Trabajo:** Recorrer las tablas (por área funcional, mismo orden que fases anteriores)
y documentar las columnas que cumplan el criterio §3.2.

**Gate de calidad:**
```bash
./DDLs/tools/verificar_documentacion.sh SBOSDB_copia --columnas
```

**Criterio de salida:** Tablas con columnas elegibles sin documentar = 0.  
**Estimado: 5 sesiones.**

---

### Fase 5 — Catálogo final y cierre

**Trabajo:**
1. Ejecutar `./DDLs/tools/generar_catalog.sh SBOSDB` → `catalog_sbos.yml` completo
2. Validar que el 100 % de las tablas aparece con los 18 campos correctos
3. Archivar la línea base final en `DDLs/LINEA-BASE-DOCUMENTACION.md`
4. Commit con evidencia del reporte final `verificar_documentacion.sh` (AA-1)

**Criterio de salida:**
```
catalog_sbos.yml generado · cobertura_score_alto = 100 % · commit con evidencia
```
**Estimado: 1 sesión.**

---

**Resumen del roadmap:**

| Fase | Alcance | Estado |
|------|---------|--------|
| 0 | Infraestructura de scripts (`verificar_documentacion.sh`, `generar_catalog.sh`) | PENDIENTE |
| 1 | Tablas sin documentación (migrations) | ✅ COMPLETADA (2026-07-31) |
| 2 | Score bajo 0–2/6 | ✅ COMPLETADA (2026-07-31) — todas las tablas tienen score 6/6 |
| 3 | Score medio 3–4/6 | ✅ COMPLETADA (2026-07-31) — todas las tablas tienen score 6/6 |
| 4 | COMMENT ON COLUMN en columnas con criterio §3.2 | PENDIENTE |
| 5 | Catálogo final + cierre (`catalog_sbos.yml` regenerado desde BD) | PENDIENTE |

---

## §8 Protocolo de mantenimiento

Una vez completadas las fases, la documentación se mantiene viva con estas reglas:

| Evento | Acción obligatoria | Quién |
|--------|--------------------|-------|
| Nuevo `CREATE TABLE` en cualquier DDL | Agregar `COMMENT ON TABLE` con score ≥ 5/6 y marcador `-- [DOC:DONE]` antes del commit | Agente que crea la tabla |
| Modificación de una tabla existente | Revisar si el `COMMENT ON TABLE` sigue siendo válido; actualizar si cambió la semántica | Agente que modifica |
| Nueva migración aplicada a producción | Ejecutar `verificar_documentacion.sh` + regenerar `catalog_sbos.yml` | Gate automático pre-commit |
| Sesión de documentación cerrada | El script actualiza los marcadores `[DOC:*]` en el `.sql` fuente | Automático |
| Nuevo dominio DDL incorporado | Agregar al roadmap, crear sesión en Fase 1 antes de commitear | Agente bauth |

**Regla absoluta de merge:**
```
Ningún CREATE TABLE sin COMMENT ON TABLE con score ≥ 5/6 se commitea al repositorio.
verificar_documentacion.sh se ejecuta como hook pre-commit.
```

---

## §10 Mapa de documentos — guía de consulta y modificación de SBOSDB

Este mapa es el punto de entrada para cualquier análisis, estudio o modificación de la base de datos
SBOSDB. Clasifica todos los documentos relevantes por propósito y señala cuáles leer antes de actuar.

> **Regla:** Leer primero, actuar después. Antes de cualquier INSERT/ALTER/CREATE, consultar el
> inventario (A.65.02) y la doctrina (ddls.yml). Antes de crear un menú contextual, consultar A.65.04.
> Antes de modificar un control ISO 27001, consultar A.71. Antes de escribir semántica, leer el Manual.

---

### §10.1 Archivos DDL — fuentes de verdad de estructura

| Archivo | Propósito | Cuándo leer |
|---------|-----------|-------------|
| `DDLs/SBOS_db_V2_DDL.sql` | DDL canónico principal — schemas `bglobal`, `bauth`, `bcalendar`. ~136 tablas padre. Fuente de verdad absoluta de estructura. | Antes de crear o modificar CUALQUIER tabla en estos schemas |
| `DDLs/migrations/bauth_dominios_pendientes_v2.0.sql` | Migración D02–D15 + D98 + D99. 102 tablas. Commit `c420dc2`. APLICADO en SBOSDB. | Antes de trabajar con dominios de control D02–D99 |
| `DDLs/migrations/iso27001_backlog_t520_t529.sql` | Migración ISO 27001:2022 BACKLOG. 10 tablas nuevas + ALTER T-157. Commit `634f6b5`. APLICADO en SBOSDB. | Antes de trabajar con incidentes, THI, vulnerabilidades, retención, PII |
| `DDLs/bos_01__control_plane.sql` | Schema `bos` — Context Plane + BOS Control Plane. ~22 tablas. | Antes de trabajar con `bos.*` (ctx_id, fichas, watchdog, etc.) |

### §10.2 Doctrina y conteos

| Archivo | Propósito | Cuándo leer |
|---------|-----------|-------------|
| `DDLs/ddls.yml` | Doctrina DDL del proyecto — convención de nombres, ciclo de vida, conteo oficial de tablas (144), lista de migrations activas, orden de carga. | Al inicio de CUALQUIER sesión de trabajo en DDL |
| `DDLs/SBOS_db_V2_DDL_MANUAL.md` | Manual operativo — intención detrás de cada tabla, decisiones de diseño, semántica de columnas, invariantes. v2.14.0. | Antes de modificar la semántica de una tabla o columna existente |
| `DDLs/MANUAL-DOCUMENTACION-ESTRATIFICADA-SBOS_DB.md` | Este documento — estándar de COMMENT ON TABLE, roadmap de documentación, §10 este mapa. | Al iniciar cualquier tarea de documentación de tablas |

### §10.3 Seeds

| Archivo | Propósito | Cuándo leer |
|---------|-----------|-------------|
| `DDLs/seeds/bglobal_T060__menu_context.sql` | ENUMs formales (`menu_type_enum` = CONTEXTUAL/NAVIGATIONAL/CONFIGURATION/SYSTEM) — 58 entradas MC-0001..MC-0058. | Antes de agregar nuevas entradas raíz a `bglobal.menu_context` |
| `DDLs/seeds/bglobal_T061__menu_context_checks.sql` | Menús contextuales para CHECK constraints — 261 entradas MC-0059..MC-0340 en bloques DO $$. Último código activo: MC-0340. | Antes de agregar menús para un CHECK constraint nuevo |
| `DDLs/seeds/` | Otros seeds: `bglobal_01..04`, `bcalendar_01..03`, `bauth_16__*`, `T016`, `T162`. | Según el dominio de datos que se trabaje |

### §10.4 Inventario y completitud de tablas

| Archivo | Propósito | Cuándo leer |
|---------|-----------|-------------|
| `BauthAgent/context/Documentacion/anexos/A.65.02_ANEXO-NUEVA-DDL-v1.0.md` | Inventario completo T-NNN → tabla. Incluye D00–D99, schema bos, ISO 27001 BACKLOG (T-520..T-565). Máximo T-code activo: T-565. | Al asignar un T-code nuevo, verificar aquí que no hay conflicto |
| `BauthAgent/context/Documentacion/anexos/A.65.03.01.01_*.md` | Completitud del dominio D00 — Identidad Organizacional | Antes de añadir tablas o átomos a D00 |
| `BauthAgent/context/Documentacion/anexos/A.65.03.01.02_*.md` | Completitud del dominio D01 | Antes de añadir tablas a D01 |
| `BauthAgent/context/Documentacion/anexos/A.65.03.01.03_*.md` .. `A.65.03.01.17_*.md` | Completitud D02..D15 | Antes de añadir tablas a cada dominio respectivo |
| `BauthAgent/context/Documentacion/anexos/A.65.03.01.18_*.md` | Vista consolidada — inventario de 18 dominios, núcleo L3 (D00+D01+D08+D11+D14+D15), ~80 tablas propuestas T-200..T-515 | Visión global del modelo de identidad |
| `BauthAgent/context/Documentacion/anexos/A.65.04_*.md` | Kardex de menús contextuales — inventario de 319+ MC-XXXX con índice inverso (columna→MC) | Antes de agregar un CHECK o ENUM, verificar si ya existe |

### §10.5 Cumplimiento normativo

| Archivo | Propósito | Cuándo leer |
|---------|-----------|-------------|
| `BauthAgent/context/Documentacion/anexos/A.71_INFORME-CUMPLIMIENTO-ISO27001-2022-v1.0.md` | Informe ISO 27001:2022 — v1.13.0 — score 122/123 (99.2%). 41 controles evaluados. Único gap real restante: A.8.25 (CI pipeline DevOps). | Antes de crear tablas relacionadas con controles ISO 27001 |
| `BauthAgent/context/Documentacion/anexos/BACKLOG-DDL-ISO27001.md` | BACKLOG cerrado — T-BACKLOG-001..009 COMPLETADOS. Referencia histórica de qué gap cerraba cada tabla. | Para entender qué control cierra cada tabla del S21 |

### §10.6 Acceso VPS para verificación contra BD real

```bash
# Conexión a SBOSDB (BD OFICIAL — NUNCA otra BD)
psql "postgres://postgres:postgres@localhost:15432/SBOSDB"

# Contar tablas por schema
SELECT schemaname, count(*) FROM pg_tables
WHERE schemaname IN ('bglobal','bauth','bcalendar','bos')
GROUP BY schemaname ORDER BY schemaname;

# Verificar que una tabla existe
SELECT tablename FROM pg_tables
WHERE schemaname='bauth' AND tablename='inc_incident';

# Ver COMMENT ON TABLE de una tabla
SELECT obj_description('bauth.inc_incident'::regclass, 'pg_class');

# Listar columnas de una tabla con tipos
SELECT a.attname, format_type(a.atttypid, a.atttypmod), a.attnotnull
FROM pg_attribute a
WHERE a.attrelid = 'bauth.inc_incident'::regclass
  AND a.attnum > 0 AND NOT a.attisdropped
ORDER BY a.attnum;

# Ver CHECK constraints de una tabla
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'bauth.inc_incident'::regclass AND contype='c';
```

**Acceso SSH:**
```bash
ssh root@13.140.128.230   # pass: 12345678ubuntu
psql -p 15432 -U postgres SBOSDB
```

### §10.7 Flujo de trabajo estándar para añadir una tabla nueva

1. **Verificar T-code libre** en A.65.02 (próximo libre: T-566 o superior)
2. **Verificar dominio** en A.65.03.01.NN del dominio correspondiente
3. **Escribir `CREATE TABLE`** en el DDL correcto (DDL unificado o migrations/)
4. **Agregar COMMENT ON TABLE** con score 6/6 (ver §3.1) y marcador `-- [DOC:DONE]`
5. **Actualizar A.65.02** con la nueva entrada T-code → tabla
6. **Actualizar ddls.yml** → `tablas:` (incrementar)
7. **Actualizar SBOS_db_V2_DDL_MANUAL.md** → sección correspondiente + changelog
8. **Si hay CHECK constraints** → agregar MC-XXXX en T061 y actualizar A.65.04
9. **Aplicar en SBOSDB** con verificación de idempotencia (2 pasadas, 0 errores)
10. **Commit con evidencia AA-1** (`verificar_afirmacion.sh`)

### §10.8 Jerarquía de autoridad en conflicto entre documentos

Si dos documentos dan información contradictoria sobre una tabla:

```
1. BD SBOSDB (pg_class/pg_constraint)    ← autoridad máxima (lo que EXISTE)
2. DDL canónico (.sql)                   ← fuente de verdad de DISEÑO
3. SBOS_db_V2_DDL_MANUAL.md             ← fuente de verdad de INTENCIÓN
4. A.65.02 (inventario)                 ← fuente de verdad de ASIGNACIÓN T-code
5. ddls.yml                             ← fuente de verdad de CONTEOS y DOCTRINA
6. Demás manuales (A.65.03, A.71…)     ← análisis y contexto normativo
```

**Si SBOSDB y el DDL difieren:** actualizar el DDL para reflejar la BD (no al revés) y documentar la discrepancia.

---

## §9 Referencias normativas

| Norma | Aplica a |
|-------|---------|
| ISO 27001:2022 A.8.15 | Trazabilidad en tablas de auditoría (WORM) |
| GDPR Art. 5(1)(c) | Columnas con datos personales anonimizados |
| NIST SP 800-207 | Context Plane — schema `bos` |
| Ley 164 Bolivia | Firma digital — schema `bauth` (tablas `sig_*`) |
| NIST SP 800-63B-4 | Autenticación — tablas `auth_*` |
| SIN RND 102100000011 | Facturación — tablas vinculadas a `bglobal` |

---

## Historial de versiones

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 1.1.0 | 2026-08-01 | §10 Mapa de documentos — guía completa de consulta y modificación de SBOSDB (8 subsecciones: DDLs, doctrina, seeds, inventario, cumplimiento, VPS, flujo de trabajo, jerarquía de autoridad) |
| 1.0.0 | 2026-08-01 | Documento inicial — elevado de propuesta a manual operacional |

---

*Este manual es custodiado por el Bibliotecario ORQUESTA. Cambios en §3 (estándar) o §7
(roadmap) requieren aprobación HITL. El resto puede actualizarse por sesión de documentación
sin aprobación previa.*
