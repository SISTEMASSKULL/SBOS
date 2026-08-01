# Sistema de Documentación Estratificada — SBOS_db
## Propuesta de Arquitectura, Estándar y Control de Avance

**Versión:** 1.0  
**Fecha:** 2026-08-01  
**Alcance:** 216 tablas padre · 4 schemas · 3 archivos DDL  
**Estado:** BORRADOR — pendiente aprobación HITL antes de cualquier implementación

---

## 1. Contexto y justificación técnica

SBOS_db es la base de datos de un **Identity Control Plane** empresarial: un sistema del que
dependen autenticación, autorización, firma digital, auditoría forense, acceso físico y facturación
electrónica. Con 216 tablas padre distribuidas en 4 schemas interrelacionados, el modelo de datos
es en sí mismo infraestructura crítica.

Un agente o programador que no entiende el modelo toma decisiones incorrectas: escribe en la tabla
equivocada, omite campos de trazabilidad obligatorios, no respeta restricciones WORM, o consulta
datos sin el contexto de seguridad correcto. En un sistema IAM estos errores no son bugs menores —
son vectores de brecha de seguridad o de incumplimiento normativo (ISO 27001, GDPR, Ley 164 Bolivia).

La documentación de la base de datos no es documentación técnica accesoria. Es parte de la
infraestructura de gobernanza del sistema.

---

## 2. Diagnóstico — estado verificado antes de esta propuesta

La siguiente tabla es el resultado de una auditoría automatizada ejecutada sobre los 3 archivos
DDL del proyecto. Los números son exactos y reproducibles.

### 2.1 Cobertura de COMMENT ON TABLE

| Archivo DDL | Tablas padre | Con COMMENT ON TABLE | Sin COMMENT ON TABLE |
|-------------|:-----------:|:--------------------:|:--------------------:|
| `SBOS_db_V2_DDL.sql` | 118 | 118 (100 %) | 0 |
| `bos_01__control_plane.sql` | 20 | 20 (100 %) | 0 |
| `migrations/bauth_dominios_pendientes_v2.0.sql` | 78 | **0 (0 %)** | **78** |
| **Total** | **216** | **138 (64 %)** | **78 (36 %)** |

### 2.2 Calidad de los COMMENT ON TABLE existentes

Los 138 comentarios existentes fueron evaluados contra los 6 elementos del estándar propuesto
(§ 3.1). Un comentario que menciona solo el propósito pero omite fuente, administración y
estándares no está completo — brinda contexto insuficiente para tomar decisiones correctas.

| Nivel | Criterio | `SBOS_db_V2_DDL.sql` | `bos_01` | `migración` |
|-------|----------|:--------------------:|:--------:|:-----------:|
| 🟢 Alto | 5–6 de 6 elementos | 29 tablas (25 %) | 9 tablas (45 %) | — |
| 🟡 Medio | 3–4 de 6 elementos | 70 tablas (59 %) | 11 tablas (55 %) | — |
| 🔴 Bajo | 0–2 de 6 elementos | 19 tablas (16 %) | 0 | **78 tablas (100 %)** |

**Elementos más frecuentemente ausentes en los comentarios existentes:**

| Elemento | Ausente en (%) |
|----------|:--------------:|
| Reglas de administración | 79 % |
| Fuente de alimentación | 68 % |
| Etiqueta de área funcional | 40 % |
| Estándares aplicables | 32 % |

### 2.3 Cobertura de COMMENT ON COLUMN

| Archivo | Tablas con ≥1 columna documentada | Tablas con 0 columnas documentadas |
|---------|:---------------------------------:|:----------------------------------:|
| `SBOS_db_V2_DDL.sql` | 38 (32 %) | **80 (68 %)** |
| `bos_01__control_plane.sql` | 15 (75 %) | 5 (25 %) |
| `migrations/...v2.0.sql` | 0 | **78 (100 %)** |

### 2.4 Tablas que requieren reescritura total (score bajo)

| Área funcional | Tablas |
|----------------|--------|
| Framework de autenticación | `auth_compliance_map` `auth_config` `auth_crypto_algorithm` `auth_method` `auth_policy` `auth_saga_catalog` |
| Firma digital interna | `sig_adsib_lifecycle` `sig_certificate` `sig_document_hash` `sig_document_policy` `sig_key` `sig_operation_log` |
| Blockchain | `blk_anchor` `blk_merkle_leaf` `blk_reconciliation` |
| Wallet / VC | `wallet` `wallet_issuance_log` |
| Calendario | `cal_fiscal_year` `cal_holiday` |

---

## 3. Estándar de documentación

### 3.1 Estructura canónica de COMMENT ON TABLE

Todos los `COMMENT ON TABLE` del proyecto deben contener exactamente los siguientes 6 elementos,
en el mismo orden, separados por salto de línea dentro del string SQL:

```
[1] ÁREA FUNCIONAL | Propósito en una oración precisa.
[2] Fuente: <proceso exacto que inserta datos aquí>.
[3] Administración: <quién gestiona, frecuencia, restricciones>.
[4] WORM: <sí — motivo y mecanismo> | no.
[5] Particionada: <sí — clave y frecuencia de nueva partición> | no.
[6] Estándar: <normas aplicables>. T-<código>.
```

**Ejemplo conforme:**
```sql
COMMENT ON TABLE bauth.auth_method IS
  'AUTENTICACIÓN | Catálogo declarativo del MethodRegistry — define los 47 métodos '
  'de autenticación disponibles con su LoA, resistencia a phishing y estándar rector. '
  'Fuente: seed inicial al desplegar el tenant; actualizaciones vía migración + HITL '
  'cuando se incorpora o depreca un método (no se modifica en caliente). '
  'Administración: tabla de referencia inmutable en producción; todo cambio requiere '
  'migración explícita, revisión del auth_saga_catalog asociado y re-seed en entornos. '
  'WORM: no — los métodos pueden actualizarse; nunca se eliminan (solo deprecated). '
  'Particionada: no. '
  'Estándar: NIST SP 800-63B-4 §5, FIDO2/WebAuthn W3C Level 3, RFC 6749, RFC 9449. T-335.';
```

**Ejemplo de lo que NO es aceptable (score 2/6 — actual):**
```sql
-- Repite el nombre de la tabla. No aporta nada operativo.
COMMENT ON TABLE bauth.auth_method IS
  'Catálogo de métodos de autenticación.';
```

### 3.2 Criterio de inclusión para COMMENT ON COLUMN

Documentar una columna es obligatorio si cumple al menos uno de estos criterios:

| Criterio | Ejemplos en SBOS_db |
|----------|---------------------|
| Nombre abreviado o ambiguo | `ctx_id`, `ip_hash`, `fal`, `aal_produced`, `ial` |
| Tipo genérico con estructura interna no obvia | `metadata JSONB`, `config JSONB`, `steps JSONB` |
| Restricción de seguridad no expresable en DDL | `vault_key_path` — nunca el valor, solo la ruta en Vault |
| Valor calculado automáticamente por trigger | `hash_actual` — nunca lo calcula la app |
| Dato anonimizado por norma | `ip_hash` — GDPR Art. 5(1)(c); nunca IP en claro |
| Enum no autodescriptivo en el dominio del negocio | `outcome` con valores 'PERMIT'/'STEP_UP_REQUIRED'/'DENIED' |
| FK cuya semántica no es evidente | `actor_id` — puede ser humano, NHI, daemon o bot |

### 3.3 Áreas funcionales canónicas

Toda tabla pertenece a exactamente una de las siguientes 19 áreas. El prefijo del COMMENT ON TABLE
debe usar este nombre exacto para permitir extracción automática por área:

```
GLOBAL · TENANT · CALENDARIO · ROLES · VERSIONADO · IDENTIDAD · NHI ·
USUARIOS · AUTENTICACIÓN · SESIÓN · PRIVILEGIOS · FIRMA DIGITAL ·
WALLET · AUDITORÍA IGA · BLOCKCHAIN · PAM · CONTEXT PLANE ·
DOMINIOS CONTROL (D02–D15) · META-REGISTRO (D98-D99)
```

---

## 4. Arquitectura del sistema en 3 capas

```
CAPA 0 ── COMMENT ON (en los archivos .sql)
│   Fuente única de verdad técnica. Vive en pg_description.
│   Siempre sincronizado con el DDL. Queryable por cualquier herramienta.
│   ↓ genera automáticamente
├── CAPA 1 ── catalog_sbos.yml (un solo archivo)
│   Consumo rápido por agentes IA. ~15 campos por tabla.
│   Generado por tools/generar_catalog.sh desde pg_description.
│   No se edita a mano. Se regenera tras cada migración.
│   ↓ sirve de base para
└── CAPA 2 ── Manuales por área funcional (uno por área, a demanda)
    Referencia profunda para programadores. Describe flujos, columnas,
    ejemplos operativos, reglas de administración con detalle.
    Se escribe cuando el área entra en desarrollo activo.
```

### 4.1 Consultas operativas estándar (Capa 0)

```sql
-- 1. Propósito de una tabla específica
SELECT obj_description('bauth.auth_method'::regclass, 'pg_class');

-- 2. Catálogo completo con score de documentación calculado en runtime
SELECT
    n.nspname                                           AS schema,
    c.relname                                           AS tabla,
    LEFT(obj_description(c.oid, 'pg_class'), 120)       AS resumen,
    (   (obj_description(c.oid,'pg_class') ~* 'fuente:')::int
      + (obj_description(c.oid,'pg_class') ~* 'administra')::int
      + (obj_description(c.oid,'pg_class') ~* 'T-[0-9]+')::int
      + (obj_description(c.oid,'pg_class') ~* 'estándar|ISO|NIST|RFC|PCI|GDPR')::int
      + (obj_description(c.oid,'pg_class') ~* 'WORM|particion')::int
      + (length(obj_description(c.oid,'pg_class')) > 80)::int
    )                                                   AS score_6
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('bauth','bglobal','bcalendar','bos')
  AND c.relkind = 'r'
  AND c.relispartition = false
ORDER BY score_6 ASC, n.nspname, c.relname;

-- 3. Columnas sin documentar en una tabla
SELECT a.attname, format_type(a.atttypid, a.atttypmod)
FROM pg_attribute a
WHERE a.attrelid = 'bauth.auth_method'::regclass
  AND a.attnum > 0
  AND NOT a.attisdropped
  AND col_description(a.attrelid, a.attnum) IS NULL
ORDER BY a.attnum;
```

### 4.2 catalog_sbos.yml — estructura por área

```yaml
# DDLs/catalog_sbos.yml
# GENERADO AUTOMÁTICAMENTE — no editar
# Comando: ./DDLs/tools/generar_catalog.sh SBOSDB
generado_en: "2026-08-01T00:00:00Z"
fuente: "pg_description de SBOSDB"
total_tablas_padre: 216
cobertura_comment_on_table: "64%"
cobertura_score_alto: "21%"

areas:
  AUTENTICACION:
    tablas:
      - t_code: T-335
        schema: bauth
        tabla: auth_method
        fqn: bauth.auth_method
        resumen: "Catálogo declarativo del MethodRegistry — 47 métodos con LoA y estándar rector"
        fuente: "seed + HITL"
        administracion: "inmutable en producción; cambios por migración"
        worm: false
        particionada: false
        columnas_documentadas: 0
        score: 6
        estandares: ["NIST SP 800-63B-4 §5", "FIDO2/WebAuthn W3C L3"]
```

---

## 5. Sistema de control de avance

Esta sección define cómo se mide, rastrea y certifica el avance de la tarea de documentación.
Sin este sistema no es posible saber si la tarea está completa ni detectar regresiones.

### 5.1 Definición de Done (DoD) por tabla

Una tabla se considera **DOCUMENTADA** cuando cumple simultáneamente:

| Criterio | Verificación |
|----------|--------------|
| COMMENT ON TABLE presente | `obj_description(tabla::regclass,'pg_class') IS NOT NULL` |
| Score ≥ 5/6 en los 6 elementos del estándar (§3.1) | Script `verificar_documentacion.sh` |
| Todas las columnas con criterio de inclusión (§3.2) tienen COMMENT ON COLUMN | Script `verificar_documentacion.sh` |
| El COMMENT ON existe en el archivo `.sql` fuente (no solo en BD) | `grep` sobre el archivo correspondiente |
| Verificado en SBOSDB_copia sin errores | Ejecutar el archivo DDL en copia y re-verificar |

Una tabla en estado **EN REVISIÓN** cumple 1–4 criterios. Una tabla **NO INICIADA** tiene 0.

### 5.2 Estados por tabla

| Estado | Definición | Transición siguiente |
|--------|-----------|---------------------|
| `NOT_STARTED` | Sin COMMENT ON TABLE | → `IN_PROGRESS` al empezar la sesión |
| `IN_PROGRESS` | COMMENT ON TABLE escrito en el `.sql` pero no verificado en BD | → `REVIEW` al ejecutar en copia |
| `REVIEW` | Ejecutado en SBOSDB_copia; script reporta score < 5 o columnas faltantes | → `IN_PROGRESS` para corrección |
| `DONE` | Score ≥ 5/6 + columnas cubiertas + verificado en copia + presente en `.sql` | Estado final |
| `BLOCKED` | Requiere decisión de dominio que no puede resolver el agente solo | → HITL desbloquea |

### 5.3 Script de verificación automática

`DDLs/tools/verificar_documentacion.sh` — corre contra cualquier BD y emite:

```
REPORTE DE DOCUMENTACIÓN — SBOS_db — 2026-08-01
================================================
Schema     Tabla                          Score   Cols  Estado
---------  -----------------------------  ------  ----  ----------
bauth      auth_method                    6/6     ✓     DONE
bauth      auth_policy                    2/6     ✗     IN_PROGRESS
bauth      blk_anchor                     2/6     ✗     IN_PROGRESS
bauth      idn_global_admin               0/6     ✗     NOT_STARTED
...

RESUMEN
  DONE        :  29 /216  (13 %)
  IN_PROGRESS :  90 /216  (42 %)
  NOT_STARTED :  78 /216  (36 %)
  REVIEW      :   0 /216   (0 %)
  BLOCKED     :   0 /216   (0 %)

COBERTURA OBJETIVO: 100 % en DONE
BRECHA ACTUAL     : 187 tablas (87 %)
```

El script se ejecuta:
- Al iniciar cualquier sesión de documentación (estado inicial)
- Al cerrar una sesión (estado de avance)
- Antes de cualquier commit (gate de calidad)
- Al regenerar `catalog_sbos.yml` (gate de generación)

### 5.4 Tracking en el archivo DDL fuente

Cada tabla en los archivos `.sql` lleva un marcador de estado como comentario SQL encima
del `CREATE TABLE`. Este marcador es legible por el script y por el agente:

```sql
-- [DOC:DONE]    ← tabla completamente documentada
-- [DOC:REVIEW]  ← documentada en el .sql, pendiente verificación en copia
-- [DOC:TODO]    ← pendiente de documentar

CREATE TABLE IF NOT EXISTS bauth.auth_method ( ... );
COMMENT ON TABLE bauth.auth_method IS '...';
```

El script `verificar_documentacion.sh` puede actualizar estos marcadores automáticamente
en función del estado real en BD.

---

## 6. Roadmap de implementación

Las fases están ordenadas por impacto. Cada fase tiene criterios de entrada, trabajo definido
y criterios de salida medibles. No se inicia una fase sin que la anterior esté en `DONE`.

### Fase 0 — Infraestructura de control (prerequisito)

**Criterio de entrada:** Esta propuesta aprobada por HITL.

**Trabajo:**
1. Crear `DDLs/tools/verificar_documentacion.sh` — emite el reporte de avance
2. Crear `DDLs/tools/generar_catalog.sh` — genera `catalog_sbos.yml` desde pg_description
3. Ejecutar `verificar_documentacion.sh` contra SBOSDB_copia → establece la línea base oficial
4. Registrar la línea base en `DDLs/LINEA-BASE-DOCUMENTACION.md`

**Criterio de salida:** Ambos scripts ejecutan sin errores. Línea base registrada.
**Estimado:** 1 sesión.

---

### Fase 1 — Tablas críticas sin ninguna documentación (78 tablas)

**Criterio de entrada:** Fase 0 completada.

**Tablas:** Todas las de `migrations/bauth_dominios_pendientes_v2.0.sql`
(D99, D07, D09, D02, D03, D04, D05, D06, D10, D11, D12, D13, D14, D15, D98).

**Trabajo por sesión:** ≈12 tablas (un dominio completo por sesión).
Orden de sesiones: D99 → D07 → D09 → D02 → D03 → D04 → D05 → D06 → D10 → D11 → D12 → D13 → D14 → D15 → D98.

**Gate de calidad por sesión:**
```
verificar_documentacion.sh SBOSDB_copia → score ≥ 5/6 en todas las tablas del dominio procesado
```

**Criterio de salida de la fase:**
```
NOT_STARTED en migrations/bauth_dominios_pendientes_v2.0.sql = 0
```
**Estimado:** 7 sesiones (≈ 2 dominios por sesión).

---

### Fase 2 — Reescritura de comentarios con score bajo (19 tablas)

**Criterio de entrada:** Fase 1 completada.

**Tablas:** Las 19 identificadas en §2.4 del diagnóstico.
Grupos: autenticación framework (6) · firma digital (6) · blockchain (3) · wallet (2) · calendario (2).

**Trabajo:** Reescribir el COMMENT ON TABLE completo con los 6 elementos del estándar.
El contenido previo se descarta — no es rescatable con un score de 0–2/6.

**Gate de calidad:**
```
verificar_documentacion.sh → score ≥ 5/6 en las 19 tablas
```

**Criterio de salida:**
```
Score bajo (0-2/6) en SBOS_db_V2_DDL.sql = 0
```
**Estimado:** 2 sesiones.

---

### Fase 3 — Completar elementos faltantes en comentarios de score medio (81 tablas)

**Criterio de entrada:** Fase 2 completada.

**Tablas:** 70 de score medio en `SBOS_db_V2_DDL.sql` + 11 de `bos_01__control_plane.sql`.

**Trabajo:** Para cada tabla, agregar los elementos ausentes según el reporte del script.
Los dos más frecuentes (fuente y administración) se añaden sin reescribir lo existente.

**Gate de calidad:**
```
verificar_documentacion.sh → score < 5 en SBOS_db_V2_DDL.sql = 0
                              score < 5 en bos_01__control_plane.sql = 0
```

**Criterio de salida:**
```
Score alto (5-6/6) en DDL principal + BOS = 100 %
```
**Estimado:** 4 sesiones.

---

### Fase 4 — COMMENT ON COLUMN en columnas con criterio de inclusión

**Criterio de entrada:** Fase 3 completada.

**Trabajo:** Recorrer las 216 tablas y aplicar el criterio §3.2. Documentar las columnas
que lo cumplan. Estimado ≈3 columnas por tabla en promedio para las que aplica.

**Organización:** Por área funcional, misma secuencia que las fases anteriores.

**Gate de calidad:**
```
verificar_documentacion.sh → tablas con columnas elegibles sin documentar = 0
```

**Criterio de salida:** Todas las columnas con criterio de inclusión tienen COMMENT ON COLUMN.
**Estimado:** 5 sesiones.

---

### Fase 5 — Generación del catálogo y cierre

**Criterio de entrada:** Fases 1–4 completadas. Score ≥ 5/6 en el 100 % de las tablas.

**Trabajo:**
1. Ejecutar `generar_catalog.sh SBOSDB` → genera `catalog_sbos.yml`
2. Revisar el YAML y validar que el 100 % de las tablas aparece con los campos correctos
3. Archivar la línea base final en `DDLs/LINEA-BASE-DOCUMENTACION.md`
4. Commit con evidencia del reporte final de `verificar_documentacion.sh`

**Criterio de salida:**
```
catalog_sbos.yml generado · cobertura_score_alto = 100 % · commit con evidencia AA-1
```
**Estimado:** 1 sesión.

---

## 7. Protocolo de mantenimiento (post-implementación)

La documentación se degrada si no existe un protocolo de mantenimiento. Cada vez que se crea
una nueva tabla o se modifica una existente:

| Evento | Acción obligatoria | Responsable |
|--------|--------------------|-------------|
| Nuevo `CREATE TABLE` en cualquier DDL | Agregar `COMMENT ON TABLE` con score ≥ 5/6 y marcador `[DOC:TODO]` | Agente que crea la tabla |
| Modificación de una tabla existente | Revisar si el COMMENT ON TABLE sigue siendo válido | Agente que modifica |
| Nueva migración aplicada a producción | Ejecutar `verificar_documentacion.sh` + regenerar `catalog_sbos.yml` | Gate automático pre-commit |
| Sesión de documentación cerrada | El script actualiza los marcadores `[DOC:*]` en el .sql fuente | Automático |

**Regla absoluta:** Ningún `CREATE TABLE` sin `COMMENT ON TABLE` con score ≥ 5/6 se commitea
al repositorio. El script `verificar_documentacion.sh` se ejecuta como hook pre-commit.

---

## 8. Resumen ejecutivo

| Métrica | Estado actual (auditado) | Meta al cerrar Fase 5 |
|---------|--------------------------|----------------------|
| Tablas padre totales | 216 | 216 |
| Con COMMENT ON TABLE | 138 (64 %) | 216 (100 %) |
| Score alto ≥5/6 | 38 (18 % del total) | 216 (100 %) |
| Score bajo 0–2/6 | 97 (45 % del total) | 0 |
| Con COMMENT ON COLUMN | ~53 (25 %) | Todas las que cumplen §3.2 |
| Catálogo para agentes | No existe | `catalog_sbos.yml` generado |
| Script de verificación | No existe | `verificar_documentacion.sh` |
| Control de avance | Manual / subjetivo | Script + marcadores en `.sql` |
| Mantenimiento post-impl | Sin protocolo | Hook pre-commit automático |

**Fases:** 0 (infraestructura) → 1 (78 tablas sin doc) → 2 (19 score bajo) → 
3 (81 score medio) → 4 (columnas) → 5 (catálogo + cierre)  
**Estimado total:** 20–21 sesiones de trabajo estructurado.

---

*Documento libre — sin número de anexo. Aprobación HITL requerida antes de iniciar Fase 0.*
