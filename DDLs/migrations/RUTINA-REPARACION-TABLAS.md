---
name: rutina-reparacion-tablas-ddl
description: Protocolo estandarizado para reparar cualquier tabla del DDL skSBOS_db — 5 pasos obligatorios
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1884976e-c041-4110-9dd1-189c744e9a6b
---

**Protocolo de reparación de tablas — 5 pasos:**

## ⚠️ NORMA UUIDv7 — INNEGOCIABLE

**Toda tabla sin excepción debe tener `UUID PRIMARY KEY DEFAULT uuidv7()`.**
Las claves naturales (BCP 47, ISO 4217, ISO 3166-1, IANA) van como `UNIQUE NOT NULL`,
**nunca** como PRIMARY KEY.

```sql
-- ✅ CORRECTO
CREATE TABLE ejemplo (
    ejemplo_id   UUID   PRIMARY KEY DEFAULT uuidv7(),   -- RFC 9562, PG18 nativo
    codigo       TEXT   UNIQUE NOT NULL,                 -- clave natural, NO es PK
    ...
);

-- ❌ PROHIBIDO
CREATE TABLE ejemplo (
    codigo       TEXT   PRIMARY KEY,    -- PK natural → RECHAZADO
    ...
);
```

**Fundamento:** RFC 9562 (UUID v7 time-ordered), PostgreSQL 18.4 nativo, mejor para
índices B-tree que UUIDv4. Joins uniformes, replicación sin colisiones, portabilidad.

---

## Comandos del humano

```
next                             → analizar DDL antigua y proponer siguiente tabla (orden lógico)
next-doc                         → documentar rechazo: investigación + motivo + reemplazo + limpiar DDL antigua
limpiar                          → copiar tabla propuesta de DDL antigua a nueva, borrar de antigua
revisar {nombre_tabla} --seed    → tabla con seed (catálogo)
revisar {nombre_tabla}           → tabla operativa (sin seed)
```

### Flujo completo

```
next → limpiar → revisar {tabla} --seed → next → ...
next → next-doc (si la tabla es innecesaria) → next → ...
```

### Comando `next-doc`

Cuando una tabla se determina **innecesaria** (tecnología obsoleta, dato obtenible por otro medio, redundante):

1. **Investigar en internet** por qué la tabla es innecesaria (estándares actuales, alternativas)
2. **Documentar la decisión** en el encabezado de la DDL antigua (bloque de comentario explicando motivo + fuente + qué la reemplaza)
3. **Marcar en PLAN-RECONSTRUCCION-DDL.md:** `❌ INNECESARIA — {motivo breve} — Reemplazada por: {alternativa}`
4. **Borrar la tabla** de `001_bauth_pendientes.sql` (limpiar)
5. **Mostrar resumen:** tabla omitida, motivo, qué la reemplaza, siguiente tabla lógica

**Regla:** La decisión debe estar respaldada por investigación en internet, no por opinión.

### Comando `next`

1. Analizar `001_bauth_pendientes.sql` y `PLAN-RECONSTRUCCION-DDL.md`
2. Identificar la clasificación de cada tabla: `bglobal` (catálogos), `bauth` (identidad), `bcalendar` (calendario)
3. Proponer la siguiente tabla según orden lógico de dependencias:
   - **Fase 1 — Catálogos globales (bglobal, Nivel 0):** sin dependencias, se procesan primero. Incluye: geo_ciudad, geo_sitio_fisico, geo_edificio, geo_piso, geo_area_fisica, geo_dispositivo
   - **Fase 2 — Identidad core (bauth, Nivel 1):** dependen de idn_tenant y catálogos. Incluye: idn_tenant_config, idn_tenant_verification, idn_empresa, idn_sucursal, idn_pos
   - **Fase 3 — Calendario fiscal (bcalendar):** dependen de idn_tenant. Incluye: cal_interval, cal_schedule
   - **Fase 4 — Usuarios y roles (bauth, Nivel 2)**
   - **Fase 5 — Privilegios, blockchain, auditoría**
4. **Mostrar informe completo:**
   - Mapa de fases con progreso (✅ procesadas, 📍 siguiente, ⏳ pendientes)
   - **Estructura actual de la tabla** (columnas del DDL antiguo, tipos, PK)
   - **Propósito de la tabla** en la base de datos (qué representa, por qué existe, quién la usa)
   - Nombre propuesto: `tabla_original → tabla_destino (schema)`
5. Esperar confirmación del humano antes de `limpiar`

### Comando `limpiar`

1. **Primera vez:** hacer copia de seguridad de `001_bauth_pendientes.sql` por precaución
2. Analizar `001_bauth_pendientes.sql` (DDL antigua) — identificar la siguiente tabla a procesar
3. Copiar el CREATE TABLE completo (con índices, constraints, comentarios) a `DDL_skSBOS_db.sql`
4. Borrar esa tabla de `001_bauth_pendientes.sql`
5. Decir **"listo"** — el humano dará el siguiente comando `revisar`

**Archivos involucrados:**
- DDL antigua: `BauthAgent/db/migrations/001_bauth_pendientes.sql` (se va vaciando)
- DDL nueva: `BauthAgent/db/migrations/DDL_skSBOS_db.sql` (se va llenando)
- La DDL antigua sirve como indicador de avance: lo que queda es lo pendiente

## Paso 1 — Investigar estándares
- La tabla debe cumplir con TODAS las normas y estándares internacionales aplicables a su dominio
- No se admite cumplimiento parcial: si un estándar exige 10 columnas, la tabla tiene 10 columnas
- Identificar los estándares internacionales aplicables a esa tabla
- Buscar en internet si es necesario
- Listar columnas requeridas por cada estándar

## Paso 2 — Corregir tabla en DDL
- **Verificar schema correcto:** ¿es un catálogo global? → `bglobal`. ¿Es identidad? → `bauth`. ¿Es calendario fiscal? → `bcalendar`. ¿Es BOS? → `bos`. Si el schema actual es incorrecto, corregirlo primero.
- PK UUIDv7 (nunca TEXT, CHAR, INTEGER, SERIAL)
- Clave natural como UNIQUE NOT NULL (no PK)
- Columnas en inglés, sin mezclar español
- ENUM types para valores controlados (nunca CHECK IN hardcodeado)
- Si hay demasiados valores → tabla de opciones separada, no ENUMs gigantes
- ctx_id en tablas Nivel 1+
- created_at / updated_at en toda tabla
- **COMMENT ON obligatorio en TODAS las partes:** tabla, cada columna, cada índice relevante
- Cada COMMENT ON debe referenciar el estándar internacional que lo respalda (ej: `[ISO 4217]`, `[RFC 9562]`)
- Índices skip scan + GIN sobre JSONB
- **Normalización — 3 formas normales (1FN, 2FN, 3FN) obligatorias en TODA la DDL nueva:**
  - **1FN:** sin grupos repetidos, sin arrays no atómicos, cada columna con valor atómico
  - **2FN:** sin dependencias parciales — toda columna no-clave depende de la PK completa
  - **3FN:** sin dependencias transitivas — toda columna no-clave depende solo de la PK

## Paso 3 — Generar seed (si --seed)
- **Semillas completas, no muestras:** el seed debe contener el catálogo entero (todos los países, todas las monedas, todos los idiomas). Cero registros de muestra.
- Archivo: `db/migrations/seeds/seed_{nombre_tabla}.sql`
- Idempotente: TRUNCATE RESTART IDENTITY CASCADE + REINDEX + INSERT
- Nombres de columnas en inglés
- JSONB para campos multi-lenguaje

## Paso 4 — Probar en VPS
- `DROP DATABASE IF EXISTS bauth_test WITH (FORCE)` + `CREATE DATABASE`
- Ejecutar DDL completa → verificar 0 errores
- Ejecutar seed 3 veces → verificar mismo resultado
- Verificar: total, active, unique, null_ids, FK integrity
- **Verificar integridad referencial de TODA la DDL nueva:** al finalizar cada revisión, comprobar que todas las FKs resuelven, que no hay tablas huérfanas, y que las dependencias entre tablas son consistentes. Esto evita perder el control de la consistencia de la base de datos.

## Paso 5 — Corregir fallos
- Si hay errores: depurar en VPS, corregir, re-ejecutar
- Repetir hasta 3 ejecuciones idempotentes con 0 errores

## Paso 6 — Actualizar PLAN-RECONSTRUCCION-DDL.md (OBLIGATORIO)
- Actualizar la tabla resumen (§4.1) con: schema, PK, columnas, **línea en DDL nueva**, seed final
- Actualizar la tabla de mapeo de nombres: `nombre_antes → nombre_despues` con estado ✅ REPARADO
- Obtener línea exacta: `grep -n "CREATE TABLE IF NOT EXISTS.*nombre_tabla" DDL_skSBOS_db.sql`
- Esto mantiene el plan sincronizado con el DDL real y sirve para corregir el código después
- Archivo: `context/sbos/Procesar/humano/daemons/bauth/plandeaccion/bauth/PLAN-RECONSTRUCCION-DDL.md`

## Paso 7 — Actualizar MANUAL_DB_DDL.md (OBLIGATORIO)
- Agregar/actualizar la sección de la tabla con todas sus columnas
- Cada columna debe documentar: tipo, obligatoriedad, significado, cómo se obtiene el dato, ejemplo
- Mantener actualizada la lista de estándares aplicados y ENUMs
- Esto es la referencia para desarrollar interfaces, APIs y validaciones
- Archivo: `BauthAgent/db/migrations/MANUAL_DB_DDL.md`

**Reglas absolutas:**
- **UUIDv7 PK en TODA tabla** — sin excepción. Natural keys → UNIQUE, nunca PK.
- **Verificar schema correcto** — catálogos globales van en `bglobal` (timezone, currency, language, country). Identidad en `bauth`. Calendario en `bcalendar`. Si una tabla no encaja en el schema actual, corregir el schema ANTES de continuar.
- **Capacidad contratada → JSONB snapshot.** Si un dato depende del plan_tier (monedas, regiones, idiomas habilitados), se almacena como JSONB snapshot de la tabla global vía tabla puente. No es preferencia libre, es capacidad licenciada. Analizar siempre: ¿esto lo eligió el operador libremente o lo compró en su plan?
- No hardcodear valores en tablas → ENUM types
- Posibilidades muy amplias → tabla de opciones + FK (no ENUMs largos)
- Cero mezcla español/inglés en columnas
- Cero ALTER TABLE
- Cero INSERTs en DDL (van en seeds)
- **Seeds completos, no muestras** — el catálogo debe ser exhaustivo (todos los registros)
- **COMMENT ON en todo** — tabla, columnas, índices. Cada comentario con estándar de referencia

**Why:** El humano definió este protocolo para estandarizar la reparación del DDL.
Cada tabla sigue exactamente los mismos 5 pasos.

**How to apply:** Cuando el humano diga "revisar {tabla} --seed", ejecutar los 5 pasos
en orden. Sin saltar ninguno. Sin hacer de más. Sin preguntar — solo ejecutar y reportar.

[[tablas-cumplen-normas-internacionales]] [[uuidv7-pk-obligatorio-toda-tabla]]
