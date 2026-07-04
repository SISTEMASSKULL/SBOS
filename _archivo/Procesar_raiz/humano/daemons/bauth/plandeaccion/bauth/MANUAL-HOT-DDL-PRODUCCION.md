# MANUAL-HOT-DDL-PRODUCCION — Corrección y Ejecución de DDL en Caliente

**Versión:** 1.0.0 · **Fecha:** 2026-06-23 · **Autor:** sbos-coordinador
**Objetivo:** Guía paso a paso para aplicar cambios de schema en `bauth_db` (producción)
sin downtime, usando PostgreSQL 18.4 zero-downtime DDL.

---

## 0. Principios de Hot Migration

| Principio | Significado |
|-----------|------------|
| **Metadata-only** | Agregar columnas nullable sin DEFAULT no reescribe la tabla (milisegundos) |
| **lock_timeout** | Máximo 5 segundos esperando锁 — si no se obtiene, abortar y reintentar |
| **Idempotencia** | Cada statement puede ejecutarse N veces sin errores |
| **Sin table rewrite** | Nunca `ADD COLUMN NOT NULL DEFAULT X` en una sola sentencia |
| **Dos fases para NOT NULL** | `CHECK NOT VALID` → `VALIDATE CONSTRAINT` → `SET NOT NULL` |
| **Índices CONCURRENTLY** | `CREATE INDEX CONCURRENTLY` no bloquea escrituras |

---

## 1. Anatomía de un Bloque Hot Migration

Cada migración en caliente usa este patrón:

```sql
DO $$
BEGIN
    -- 1. Timeout de seguridad: máximo 5s esperando el lock
    PERFORM set_config('lock_timeout', '5s', false);

    -- 2. Verificar idempotencia: ¿ya existe la columna?
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'bauth'
          AND table_name   = 'nombre_tabla'
          AND column_name  = 'nombre_columna'
    ) THEN
        -- 3. Agregar columna nullable (metadata-only, instantáneo)
        ALTER TABLE bauth.nombre_tabla
            ADD COLUMN nombre_columna tipo_dato;

        -- 4. Documentar en el catálogo
        COMMENT ON COLUMN bauth.nombre_tabla.nombre_columna IS
          '[ESTÁNDAR] Descripción de la columna.';

        -- 5. Notificar éxito
        RAISE NOTICE '[HOT MIGRATION] bauth.%.% → AGREGADO',
            'nombre_tabla', 'nombre_columna';

    ELSE
        -- 6. Ya existe: skip silencioso
        RAISE NOTICE '[HOT MIGRATION] bauth.%.% → YA EXISTE (skip)',
            'nombre_tabla', 'nombre_columna';
    END IF;

    -- 7. Restaurar timeout
    PERFORM set_config('lock_timeout', '0', false);
END $$;
```

---

## 2. Procedimiento para Ejecutar en Producción

### 2.1 Antes de ejecutar

```bash
# 1. Verificar conectividad
kubectl --kubeconfig=/etc/kubernetes/admin.conf exec -n sbos-data postgresql-0 \
  -- psql -U postgres -d bauth_db -c "SELECT version(), current_database(), now()"

# 2. Respaldar schema actual (precaución)
kubectl --kubeconfig=/etc/kubernetes/admin.conf exec -n sbos-data postgresql-0 \
  -- pg_dump -U postgres -d bauth_db --schema-only \
  > backups/bauth_db_schema_$(date +%Y%m%d_%H%M%S).sql

# 3. Verificar espacio en disco
kubectl --kubeconfig=/etc/kubernetes/admin.conf exec -n sbos-data postgresql-0 \
  -- df -h /var/lib/postgresql/data

# 4. Verificar locks activos (debe estar limpio)
kubectl --kubeconfig=/etc/kubernetes/admin.conf exec -n sbos-data postgresql-0 \
  -- psql -U postgres -d bauth_db -c \
  "SELECT pid, state, wait_event_type, wait_event, query_start
   FROM pg_stat_activity
   WHERE state = 'active' AND wait_event_type = 'Lock'
   ORDER BY query_start;"
```

### 2.2 Ejecutar la migración

```bash
# Opción A: Ejecutar el archivo completo (recomendado para schema nuevo)
cat DDL_skSBOS_db.sql | kubectl --kubeconfig=/etc/kubernetes/admin.conf \
  exec -i -n sbos-data postgresql-0 -- psql -U postgres -d bauth_db

# Opción B: Ejecutar solo bloques específicos (para producción existente)
# Extraer y ejecutar solo los bloques DO $$ que necesitas
kubectl --kubeconfig=/etc/kubernetes/admin.conf \
  exec -i -n sbos-data postgresql-0 -- psql -U postgres -d bauth_db << 'SQL'
-- Pegar aquí solo los bloques DO $$ necesarios
SQL
```

### 2.3 Durante la ejecución (monitoreo)

```bash
# Monitorear locks en tiempo real
watch -n 2 "kubectl --kubeconfig=/etc/kubernetes/admin.conf \
  exec -n sbos-data postgresql-0 -- psql -U postgres -d bauth_db -c \"
    SELECT pid, state, wait_event_type, wait_event,
           regexp_replace(query, '[[:space:]]+', ' ', 'g') as query_preview
    FROM pg_stat_activity
    WHERE state != 'idle' AND pid != pg_backend_pid()
    ORDER BY query_start DESC LIMIT 10;
  \""
```

### 2.4 Después de ejecutar (verificación)

```bash
# Verificar columnas agregadas
kubectl --kubeconfig=/etc/kubernetes/admin.conf exec -n sbos-data postgresql-0 \
  -- psql -U postgres -d bauth_db -c \
  "SELECT table_name, column_name, data_type, is_nullable
   FROM information_schema.columns
   WHERE table_schema = 'bauth'
     AND column_name IN ('ctx_id', 'traceparent')
   ORDER BY table_name, ordinal_position;"

# Verificar que no hay errores en el log
kubectl --kubeconfig=/etc/kubernetes/admin.conf logs -n sbos-data postgresql-0 \
  --tail=50 | grep -i error
```

---

## 3. Recetas Comunes

### 3.1 Agregar una columna TEXT nullable

```sql
DO $$ BEGIN
    PERFORM set_config('lock_timeout', '5s', false);
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='bauth' AND table_name='idn_tenant' AND column_name='nueva_columna')
    THEN
        ALTER TABLE bauth.idn_tenant ADD COLUMN nueva_columna TEXT;
        COMMENT ON COLUMN bauth.idn_tenant.nueva_columna IS 'Descripción.';
        RAISE NOTICE '[OK] nueva_columna agregada';
    END IF;
    PERFORM set_config('lock_timeout', '0', false);
END $$;
```

### 3.2 Agregar una columna UUID con FK

```sql
DO $$ BEGIN
    PERFORM set_config('lock_timeout', '5s', false);
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='bauth' AND table_name='nueva_tabla' AND column_name='tenant_id')
    THEN
        -- Fase 1: Columna nullable
        ALTER TABLE bauth.nueva_tabla ADD COLUMN tenant_id UUID;
        -- Fase 2: Backfill (si hay datos)
        -- UPDATE bauth.nueva_tabla SET tenant_id = ... WHERE tenant_id IS NULL;
        -- Fase 3: FK constraint NOT VALID → VALIDATE
        ALTER TABLE bauth.nueva_tabla
            ADD CONSTRAINT fk_xxx_tenant
            FOREIGN KEY (tenant_id) REFERENCES bauth.idn_tenant(tenant_id)
            NOT VALID;
        ALTER TABLE bauth.nueva_tabla VALIDATE CONSTRAINT fk_xxx_tenant;
        RAISE NOTICE '[OK] tenant_id + FK agregados';
    END IF;
    PERFORM set_config('lock_timeout', '0', false);
END $$;
```

### 3.3 Crear un índice sin bloquear escrituras

```sql
-- No puede ir dentro de un bloque DO $$ ni transacción
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_xxx_columna
    ON bauth.idn_tenant(columna);
```

### 3.4 Migrar una columna TEXT a UUID (conversión de tipo)

```sql
DO $$ BEGIN
    PERFORM set_config('lock_timeout', '5s', false);
    -- Verificar si la columna vieja existe como TEXT
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='bauth' AND table_name='idn_tenant'
                 AND column_name='verified_by' AND data_type='text')
    THEN
        -- Fase 1: Agregar nueva columna UUID
        ALTER TABLE bauth.idn_tenant ADD COLUMN verified_by_uuid UUID;
        -- Fase 2: Migrar datos (si hay)
        -- UPDATE bauth.idn_tenant SET verified_by_uuid = verified_by::UUID WHERE verified_by IS NOT NULL;
        -- Fase 3: Eliminar columna vieja, renombrar nueva
        -- ALTER TABLE bauth.idn_tenant DROP COLUMN verified_by;
        -- ALTER TABLE bauth.idn_tenant RENAME COLUMN verified_by_uuid TO verified_by;
        RAISE NOTICE '[OK] verified_by migrado de TEXT a UUID';
    ELSE
        RAISE NOTICE '[SKIP] verified_by ya es UUID o no existe';
    END IF;
    PERFORM set_config('lock_timeout', '0', false);
END $$;
```

---

## 4. Plan de Ejecución para `bauth_db` (producción)

### Orden de ejecución (respetar dependencias)

| # | Bloque | Tipo | Impacto |
|---|--------|------|---------|
| 1 | Schemas nuevos (`bglobal`, `bcalendar`) | `CREATE SCHEMA IF NOT EXISTS` | 0 — schemas vacíos |
| 2 | `bauth.idn_tenant` (si no existe) | `CREATE TABLE IF NOT EXISTS` | 0 — tabla nueva |
| 3 | `bauth.idn_tenant.ctx_id` | Hot migration `DO $$` | 0 — columna nullable |
| 4 | `bauth.idn_tenant.traceparent` | Hot migration `DO $$` | 0 — columna nullable |
| 5 | Índices | `CREATE INDEX CONCURRENTLY` | Bajo — no bloquea escrituras |
| 6 | Constraints diferidas | `NOT VALID` → `VALIDATE` | Bajo — solo bloquea DDL |

### Rollback (si algo falla)

```sql
-- Las columnas agregadas con ADD COLUMN nullable se pueden eliminar:
-- ALTER TABLE bauth.idn_tenant DROP COLUMN IF EXISTS ctx_id;
-- Los índices CONCURRENTLY se pueden eliminar:
-- DROP INDEX CONCURRENTLY IF EXISTS idx_xxx;
-- Las constraints NOT VALID se pueden eliminar:
-- ALTER TABLE bauth.idn_tenant DROP CONSTRAINT IF EXISTS chk_xxx;
```

---

## 5. Checklist Pre-Ejecución

- [ ] Backup del schema actual (`pg_dump --schema-only`)
- [ ] Verificar conectividad a `bauth_db`
- [ ] Verificar espacio en disco (>20% libre)
- [ ] Verificar que no hay locks activos
- [ ] Verificar que la replicación está al día (si aplica)
- [ ] Ventana de mantenimiento notificada (si aplica)
- [ ] Rollback script preparado
- [ ] Monitoreo activo durante la ejecución

---

## 6. Referencias

- [PostgreSQL 18 ALTER TABLE](https://www.postgresql.org/docs/18/sql-altertable.html)
- [PostgreSQL CREATE INDEX CONCURRENTLY](https://www.postgresql.org/docs/18/sql-createindex.html)
- [Bytebase: Postgres Schema Migration without Downtime](https://www.bytebase.com/blog/postgres-schema-migration-without-downtime/)
- PLAN-RECONSTRUCCION-DDL.md §6.3 — Reglas para la DDL final
