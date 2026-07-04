# pgvector en PostgreSQL 18: Guía Completa
## Base de Datos Paralela, Implementación No Invasiva y Evaluación de Crecimiento

---

## Prólogo: El Enfoque Correcto

Este documento responde a dos preguntas distintas que deben tratarse juntas:

1. **¿Cómo se implementa pgvector sin tocar las bases de datos existentes?**
2. **¿Qué pasa con el crecimiento cuando vienen datos de 110+ aplicaciones?**

La primera pregunta tiene una respuesta técnica concreta. La segunda tiene una
respuesta que cambia la arquitectura. Ignorar cualquiera de las dos produce un
sistema incompleto.

---

## Parte I — Arquitectura: La Base de Datos Paralela

### 1.1 El principio de no invasión

pgvector como extensión de PostgreSQL no modifica ninguna tabla existente. El
problema no es la herramienta, sino dónde se instala y cómo se alimenta. La
solución correcta es construir una **base de datos dedicada exclusivamente al
índice semántico**, completamente separada de las bases operativas.

```
LO QUE NO SE HACE (invasivo):
──────────────────────────────────────────────────────────────────
  Base operativa "clientes"
    └── tabla clientes (50 columnas existentes)
          └── + columna embedding VECTOR(1536)   ← NUNCA esto
──────────────────────────────────────────────────────────────────

LO QUE SE HACE (paralelo, no invasivo):
──────────────────────────────────────────────────────────────────
  Base operativa "clientes"  ←  no se toca, no se modifica
  Base operativa "ventas"    ←  no se toca, no se modifica
  Base operativa "erp"       ←  no se toca, no se modifica
          ↓ CDC / WAL (solo lectura del log)
  Base paralela "semantic_store"
    └── tabla semantic_index  ←  aquí viven los vectores
──────────────────────────────────────────────────────────────────
```

Las bases operativas **nunca saben que existe el índice semántico**. No hay
dependencias, no hay claves foráneas cruzadas, no hay triggers, no hay columnas
nuevas. La captura es por lectura del WAL o CDC, que es una operación de solo
lectura sobre el log de transacciones.

### 1.2 Mapa completo de la arquitectura

```
┌─────────────────────────────────────────────────────────────────────────┐
│              FUENTES DE DATOS (sin modificación alguna)                 │
│                                                                         │
│  PostgreSQL     Oracle        SQL Server    MySQL         Otros         │
│  (clientes)     (ERP)         (CRM)         (ecommerce)   gestores      │
│  port: 5432     port: 1521    port: 1433    port: 3306    ...           │
└──────────┬───────────┬───────────┬───────────┬───────────┬─────────────┘
           │ WAL/CDC   │ LogMiner  │ CDC       │ BinLog    │ CDC
           │ (lectura  │           │           │           │
           │ del log)  │           │           │           │
           └───────────┴───────────┴───────────┴─────────┬─┘
                                                         │
                                              ┌──────────▼──────────┐
                                              │   CAPA DE CAPTURA   │
                                              │  Debezium / Kafka   │
                                              │  (o proceso propio) │
                                              └──────────┬──────────┘
                                                         │ eventos de cambio
                                              ┌──────────▼──────────┐
                                              │  NORMALIZADOR DE    │
                                              │  TEXTO CANÓNICO     │
                                              │  (texto plano por   │
                                              │   tipo de entidad)  │
                                              └──────────┬──────────┘
                                                         │ texto plano
                                              ┌──────────▼──────────┐
                                              │  SERVICIO DE        │
                                              │  EMBEDDINGS         │
                                              │  (OpenAI / local /  │
                                              │   sentence-transf.) │
                                              └──────────┬──────────┘
                                                         │ vector[N]
                            ┌────────────────────────────▼──────────────────────────┐
                            │          semantic_store  (PostgreSQL 18 + pgvector)    │
                            │                                                        │
                            │   CREATE DATABASE semantic_store;                      │
                            │   CREATE EXTENSION vector;                             │
                            │                                                        │
                            │   tabla: semantic_index                                │
                            │   ┌────────────────────────────────────────────────┐  │
                            │   │ tenant_id │ entity_type │ entity_id │ embedding │  │
                            │   │    45     │  CLIENTE    │   12345   │ [0.02...] │  │
                            │   │    45     │  PRODUCTO   │     87    │ [0.91...] │  │
                            │   │    72     │  FACTURA    │   99901   │ [-0.3...] │  │
                            │   └────────────────────────────────────────────────┘  │
                            └──────────────────────────┬─────────────────────────────┘
                                                       │
                                          ┌────────────▼────────────┐
                                          │     BÚSQUEDA            │
                                          │                         │
                                          │  1. consulta semántica  │
                                          │  2. → Top-K entity_ids  │
                                          │  3. → SELECT en base    │
                                          │       operativa original│
                                          └─────────────────────────┘
```

---

## Parte II — Creación de la Base de Datos Paralela

### 2.1 Instalación de pgvector en PostgreSQL 18

**Ubuntu / Debian:**
```bash
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt \
  $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc \
  | sudo apt-key add -
sudo apt update
sudo apt install -y postgresql-18-pgvector
```

**RHEL / Rocky / AlmaLinux:**
```bash
sudo dnf install -y \
  https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo dnf -qy module disable postgresql
sudo dnf install -y pgvector_18
```

**Compilación desde fuente (versión más reciente, v0.8.2):**
```bash
cd /tmp
git clone --branch v0.8.2 https://github.com/pgvector/pgvector.git
cd pgvector
make && sudo make install
```

### 2.2 Creación de la base de datos paralela

Este es el paso central. Se crea una base de datos **nueva, independiente**,
en el mismo servidor PostgreSQL 18 o en un servidor dedicado:

```sql
-- Conectarse como superusuario
\c postgres

-- Crear la base de datos dedicada al índice semántico
CREATE DATABASE semantic_store
    ENCODING    = 'UTF8'
    LC_COLLATE  = 'es_BO.UTF-8'   -- ajustar según entorno
    LC_CTYPE    = 'es_BO.UTF-8'
    TEMPLATE    = template0;

COMMENT ON DATABASE semantic_store IS
    'Base de datos paralela para índice semántico vectorial. '
    'Alimentada por CDC/WAL. No es fuente de verdad. '
    'No tiene dependencias con las bases operativas.';

-- Crear usuario dedicado para el servicio de indexación
CREATE USER semantic_svc
    WITH PASSWORD 'cambiar_en_produccion'
    NOCREATEDB
    NOCREATEROLE;

-- Crear usuario de solo lectura para el servicio de búsqueda
CREATE USER semantic_reader
    WITH PASSWORD 'cambiar_en_produccion'
    NOCREATEDB
    NOCREATEROLE;

-- Conectarse a la nueva base y habilitar pgvector
\c semantic_store

CREATE EXTENSION IF NOT EXISTS vector;

-- Verificar instalación
SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';
```

### 2.3 Esquema de la tabla principal

```sql
-- Conectado a semantic_store

CREATE TABLE semantic_index (
    -- Identificación propia
    id              BIGSERIAL       NOT NULL,

    -- Origen del dato (apunta a la base operativa, sin FK cruzada)
    tenant_id       BIGINT          NOT NULL,
    entity_type     VARCHAR(100)    NOT NULL,
    -- Ejemplos: 'CLIENTE', 'PRODUCTO', 'FACTURA', 'TICKET', 'EMPLEADO'
    entity_id       BIGINT          NOT NULL,
    -- ID del registro en su base operativa original

    -- Contenido del índice
    plain_text      TEXT            NOT NULL,
    -- Representación textual del registro. Permite reindexar
    -- sin volver a consultar la base operativa.

    embedding       HALFVEC(1536)   NOT NULL,
    -- HALFVEC en lugar de VECTOR: ahorra 50% de almacenamiento
    -- con pérdida de recall mínima en embeddings de texto.
    -- Cambiar la dimensión según el modelo usado:
    --   OpenAI text-embedding-3-small : 1536
    --   sentence-transformers/all-MiniLM: 384
    --   OpenAI text-embedding-3-large :  3072

    -- Metadata para filtros rápidos (sin ir a la base operativa)
    metadata        JSONB           NOT NULL DEFAULT '{}',
    -- Ejemplo: {"ciudad": "La Paz", "categoria": "Premium", "estado": "ACTIVO"}

    -- Control del índice
    model_version   VARCHAR(80)     NOT NULL DEFAULT 'text-embedding-3-small',
    source_db       VARCHAR(100),
    -- Nombre de la base operativa origen ('db_tenant_45', 'erp_oracle', etc.)
    indexed_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    source_updated  TIMESTAMPTZ,
    -- Cuándo cambió el registro en la fuente. Permite detectar
    -- registros cuyo embedding puede estar desactualizado.

    -- Restricciones
    CONSTRAINT pk_semantic PRIMARY KEY (id),
    CONSTRAINT uq_entity   UNIQUE (tenant_id, entity_type, entity_id)
);

COMMENT ON TABLE semantic_index IS
    'Índice semántico global. Derivado de CDC/WAL de las bases operativas. '
    'No es fuente de verdad. Los datos definitivos viven en sus bases originales. '
    'Los entity_id apuntan a registros en esas bases, sin FK explícita.';

-- Permisos para el servicio de indexación (lectura + escritura)
GRANT SELECT, INSERT, UPDATE, DELETE ON semantic_index TO semantic_svc;
GRANT USAGE, SELECT ON SEQUENCE semantic_index_id_seq TO semantic_svc;

-- Permisos para el servicio de búsqueda (solo lectura)
GRANT SELECT ON semantic_index TO semantic_reader;
```

### 2.4 Índices de rendimiento

```sql
-- ÍNDICE VECTORIAL HNSW (principal, para búsqueda semántica)
-- CONCURRENTLY: no bloquea inserciones mientras se construye
CREATE INDEX CONCURRENTLY idx_si_hnsw
    ON semantic_index
    USING hnsw (embedding halfvec_cosine_ops)
    WITH (
        m               = 16,   -- conexiones por nodo (8-64)
        ef_construction = 64    -- calidad de construcción (32-200)
    );

-- ÍNDICE POR TENANT (siempre presente en consultas multitenant)
CREATE INDEX CONCURRENTLY idx_si_tenant
    ON semantic_index (tenant_id, entity_type);

-- ÍNDICE GIN PARA METADATA (filtros rápidos sobre JSON)
CREATE INDEX CONCURRENTLY idx_si_metadata
    ON semantic_index USING gin (metadata jsonb_path_ops);

-- ÍNDICE PARA DETECTAR EMBEDDINGS DESACTUALIZADOS
CREATE INDEX CONCURRENTLY idx_si_stale
    ON semantic_index (source_updated, indexed_at)
    WHERE source_updated > indexed_at;
```

### 2.5 Particionado desde el inicio (obligatorio para 110+ apps)

Para el escenario de múltiples aplicaciones y tenants, la tabla debe estar
particionada desde el primer día. Agregar particionado después de tener datos
es una operación costosa.

```sql
-- Versión particionada de la tabla (usar esta en lugar de la anterior
-- si se anticipa más de 5 millones de registros)

CREATE TABLE semantic_index (
    id              BIGSERIAL       NOT NULL,
    tenant_id       BIGINT          NOT NULL,
    entity_type     VARCHAR(100)    NOT NULL,
    entity_id       BIGINT          NOT NULL,
    plain_text      TEXT            NOT NULL,
    embedding       HALFVEC(1536)   NOT NULL,
    metadata        JSONB           NOT NULL DEFAULT '{}',
    model_version   VARCHAR(80)     NOT NULL DEFAULT 'text-embedding-3-small',
    source_db       VARCHAR(100),
    indexed_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    source_updated  TIMESTAMPTZ,
    PRIMARY KEY (id, tenant_id)        -- tenant_id en la PK es requerido por particionado
) PARTITION BY HASH (tenant_id);       -- distribución uniforme por tenant

-- 16 particiones como punto de partida razonable
-- (ajustar según número real de tenants; potencia de 2)
CREATE TABLE semantic_index_p00  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 0);
CREATE TABLE semantic_index_p01  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 1);
CREATE TABLE semantic_index_p02  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 2);
CREATE TABLE semantic_index_p03  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 3);
CREATE TABLE semantic_index_p04  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 4);
CREATE TABLE semantic_index_p05  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 5);
CREATE TABLE semantic_index_p06  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 6);
CREATE TABLE semantic_index_p07  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 7);
CREATE TABLE semantic_index_p08  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 8);
CREATE TABLE semantic_index_p09  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 9);
CREATE TABLE semantic_index_p10  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 10);
CREATE TABLE semantic_index_p11  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 11);
CREATE TABLE semantic_index_p12  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 12);
CREATE TABLE semantic_index_p13  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 13);
CREATE TABLE semantic_index_p14  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 14);
CREATE TABLE semantic_index_p15  PARTITION OF semantic_index FOR VALUES WITH (MODULUS 16, REMAINDER 15);

-- Crear índice HNSW en cada partición
DO $$
DECLARE
    i INT;
BEGIN
    FOR i IN 0..15 LOOP
        EXECUTE format(
            'CREATE INDEX CONCURRENTLY idx_si_hnsw_p%s ON semantic_index_p%s '
            'USING hnsw (embedding halfvec_cosine_ops) WITH (m=16, ef_construction=64)',
            lpad(i::text, 2, '0'), lpad(i::text, 2, '0')
        );
    END LOOP;
END $$;
```

**Ventaja clave del particionado por tenant_id:**
```sql
-- Eliminar todos los datos de un tenant es instantáneo:
-- En lugar de DELETE (que genera dead tuples y requiere VACUUM):
TRUNCATE TABLE semantic_index_p03;  -- si el tenant cae en esa partición

-- O aún mejor, si se usa un tenant_id propio como partition key:
-- DROP TABLE semantic_index_tenant_45;   -- instantáneo, sin bloat
```

---

## Parte III — Proceso de Indexación

### 3.1 Normalización de texto canónico

La normalización convierte un registro relacional en texto plano descriptivo.
Este texto es lo que se envía al modelo de embeddings y lo que se guarda en
`plain_text` para futuras reindexaciones.

```python
# Ejemplos de funciones de normalización por tipo de entidad

def normalizar_cliente(row: dict) -> tuple[str, dict]:
    """
    Construye el texto canónico y la metadata de un cliente.
    Retorna (texto_para_embedding, metadata_para_filtros)
    """
    partes = []
    if row.get('nombre'):
        partes.append(f"Cliente: {row['nombre']} {row.get('apellido', '')}")
    if row.get('ciudad'):
        partes.append(f"Ciudad: {row['ciudad']}")
    if row.get('categoria'):
        partes.append(f"Categoría: {row['categoria']}")
    if row.get('estado'):
        partes.append(f"Estado: {row['estado']}")
    if row.get('observaciones'):
        partes.append(f"Observaciones: {row['observaciones']}")

    texto = " | ".join(partes)

    metadata = {
        "ciudad":    row.get("ciudad"),
        "categoria": row.get("categoria"),
        "estado":    row.get("estado"),
    }
    # Limpiar nulls del metadata
    metadata = {k: v for k, v in metadata.items() if v is not None}

    return texto, metadata


def normalizar_producto(row: dict) -> tuple[str, dict]:
    partes = [
        f"Producto: {row.get('nombre', '')}",
        f"Categoría: {row.get('categoria', '')}",
        f"Descripción: {row.get('descripcion', '')}",
        f"Marca: {row.get('marca', '')}",
    ]
    texto = " | ".join(p for p in partes if p.split(': ')[1])
    metadata = {
        "categoria": row.get("categoria"),
        "marca":     row.get("marca"),
        "activo":    row.get("activo", True),
    }
    return texto, {k: v for k, v in metadata.items() if v is not None}


# Registro de normalizadores por tipo de entidad
NORMALIZADORES = {
    "CLIENTE":  normalizar_cliente,
    "PRODUCTO": normalizar_producto,
    # agregar por cada tipo de entidad relevante
}
```

### 3.2 Inserción y actualización de embeddings (upsert)

```sql
-- Insertar o actualizar un embedding en la base paralela
-- (ejecutado desde el servicio de indexación)

INSERT INTO semantic_index (
    tenant_id,
    entity_type,
    entity_id,
    plain_text,
    embedding,
    metadata,
    model_version,
    source_db,
    source_updated
)
VALUES (
    $1,                             -- tenant_id
    $2,                             -- entity_type ('CLIENTE', 'PRODUCTO', ...)
    $3,                             -- entity_id (ID en la base operativa)
    $4,                             -- plain_text normalizado
    $5::halfvec,                    -- embedding generado [0.023, -0.45, ...]
    $6::jsonb,                      -- metadata {"ciudad": "La Paz", ...}
    'text-embedding-3-small',
    $7,                             -- source_db ('db_tenant_45', 'erp_oracle')
    $8                              -- source_updated (timestamp del cambio en origen)
)
ON CONFLICT (tenant_id, entity_type, entity_id)
DO UPDATE SET
    plain_text     = EXCLUDED.plain_text,
    embedding      = EXCLUDED.embedding,
    metadata       = EXCLUDED.metadata,
    model_version  = EXCLUDED.model_version,
    indexed_at     = NOW(),
    source_updated = EXCLUDED.source_updated;
```

### 3.3 Eliminación cuando se borra en la fuente

```sql
-- CDC captura un DELETE en la base operativa.
-- El servicio de indexación ejecuta en semantic_store:
DELETE FROM semantic_index
WHERE tenant_id   = $1
  AND entity_type = $2
  AND entity_id   = $3;
-- No hay cascadas, no hay triggers. Solo DELETE directo.
```

---

## Parte IV — Consultas de Búsqueda

### 4.1 Búsqueda semántica básica

```sql
-- Configurar precisión del índice (mayor = más recall, más lento)
-- SET LOCAL garantiza que vuelve al default al terminar la transacción
BEGIN;
SET LOCAL hnsw.ef_search = 100;  -- default: 40

SELECT
    entity_type,
    entity_id,
    1 - (embedding <=> $1::halfvec) AS score
FROM semantic_index
WHERE tenant_id = $2
ORDER BY embedding <=> $1::halfvec
LIMIT 20;
COMMIT;
```

### 4.2 Búsqueda híbrida: vectorial + filtros de metadata

```sql
BEGIN;
SET LOCAL hnsw.ef_search = 100;

SELECT
    entity_type,
    entity_id,
    1 - (embedding <=> $1::halfvec) AS score,
    metadata
FROM semantic_index
WHERE
    tenant_id              = $2
    AND entity_type        = 'CLIENTE'
    AND metadata->>'ciudad'    = 'La Paz'
    AND metadata->>'categoria' = 'Premium'
ORDER BY embedding <=> $1::halfvec
LIMIT 10;
COMMIT;
```

### 4.3 Flujo completo: semántica → base operativa

El patrón de dos pasos: primero al índice semántico, luego a la fuente de verdad:

```python
async def buscar_clientes(
    consulta: str,
    tenant_id: int,
    filtros: dict = None,
    limite: int = 10
) -> list[dict]:
    """
    Búsqueda semántica + recuperación de datos reales.
    La base operativa nunca participa en la búsqueda vectorial.
    """

    # PASO 1: generar embedding de la consulta
    embedding = await generar_embedding(consulta)
    # embedding = [0.023, -0.45, 0.11, ...]  (1536 floats)

    # PASO 2: buscar en semantic_store (base paralela)
    async with semantic_store_pool.acquire() as conn:
        rows = await conn.fetch("""
            SELECT entity_id, entity_type,
                   1 - (embedding <=> $1::halfvec) AS score
            FROM semantic_index
            WHERE tenant_id = $2
              AND ($3::text IS NULL OR entity_type = $3)
              AND ($4::jsonb IS NULL OR metadata @> $4)
            ORDER BY embedding <=> $1::halfvec
            LIMIT $5
        """,
            embedding,           # $1
            tenant_id,           # $2
            filtros.get('entity_type'),          # $3
            json.dumps(filtros.get('metadata'))  # $4
                if filtros and filtros.get('metadata') else None,
            limite * 2           # $5  (pedir más para filtrar después)
        )

    if not rows:
        return []

    # PASO 3: agrupar IDs por tipo de entidad
    ids_por_tipo = {}
    scores = {}
    for row in rows:
        tipo = row['entity_type']
        eid  = row['entity_id']
        if tipo not in ids_por_tipo:
            ids_por_tipo[tipo] = []
        ids_por_tipo[tipo].append(eid)
        scores[eid] = row['score']

    # PASO 4: recuperar datos reales desde la base operativa del tenant
    resultados = []
    async with operativa_pool[tenant_id].acquire() as conn:
        if 'CLIENTE' in ids_por_tipo:
            clientes = await conn.fetch("""
                SELECT id, nombre, apellido, ciudad, categoria, estado
                FROM clientes
                WHERE id = ANY($1::bigint[])
                  AND estado = 'ACTIVO'        -- filtro adicional en la fuente de verdad
            """, ids_por_tipo['CLIENTE'])
            for c in clientes:
                resultados.append({
                    **dict(c),
                    'entity_type': 'CLIENTE',
                    'score': scores[c['id']]
                })

        # Agregar otros tipos según corresponda...

    # Ordenar por score y devolver
    return sorted(resultados, key=lambda x: x['score'], reverse=True)[:limite]
```

---

## Parte V — El Problema de Crecimiento (Evaluación Honesta)

Aquí está la parte que no puede ignorarse. La arquitectura paralela resuelve el
problema de invasión. El crecimiento es un problema distinto que la arquitectura
sola no resuelve.

### 5.1 Los números reales

Cada registro en `semantic_index` con `HALFVEC(1536)` ocupa aproximadamente:
- Fila en tabla: ~3.3 KB
- Su parte en el índice HNSW: ~4.9 KB
- **Total real por registro indexado: ~8 KB**

| Registros totales | Storage VECTOR (float32) | Storage HALFVEC | RAM HNSW (halfvec) |
|---|---|---|---|
| 500,000 | 7.5 GB | **3.8 GB** | 2.3 GB |
| 1,000,000 | 15.1 GB | **7.6 GB** | 4.6 GB |
| 5,000,000 | 75.3 GB | **38.1 GB** | 22.9 GB |
| 10,000,000 | 150.6 GB | **76.2 GB** | 45.8 GB |
| 30,000,000 | 451.9 GB | **228.7 GB** | 137.3 GB |
| 55,000,000 | 828.5 GB | **419.4 GB** | 251.8 GB |
| 100,000,000 | 1.47 TB | **762.5 GB** | 457.8 GB |

**Proyección para 110 aplicaciones (20% crecimiento anual):**

| Año | Registros | Storage halfvec | RAM HNSW |
|-----|-----------|----------------|----------|
| 1 | 55,000,000 | 419 GB | 252 GB |
| 2 | 66,000,000 | 503 GB | 302 GB |
| 3 | 79,200,000 | 604 GB | 363 GB |
| 4 | 95,000,000 | 725 GB | 435 GB |
| 5 | 114,000,000 | 870 GB | 523 GB |

El cuello de botella crítico no es el disco: es la RAM. Cuando el índice HNSW
supera la RAM disponible del servidor, la latencia de consulta sube de milisegundos
a segundos. No hay ajuste de configuración que solucione un problema de capacidad.

### 5.2 Mitigaciones estructurales (no opcionales)

Estas cuatro decisiones deben tomarse **antes** de indexar el primer registro,
no después de que el problema ya existe.

#### A. Usar HALFVEC desde el inicio (no VECTOR)

```sql
-- NUNCA esto:
embedding VECTOR(1536)   -- float32, 6 KB por fila

-- SIEMPRE esto:
embedding HALFVEC(1536)  -- float16, 3 KB por fila, ~50% ahorro, recall >99%
```

El impacto acumulado a 5 años es la diferencia entre 1.68 TB y 870 GB.
Cambiar el tipo después de tener datos requiere reconstruir toda la tabla.

#### B. Reducir dimensiones si el modelo lo permite

```sql
-- text-embedding-3-small de OpenAI soporta dimensiones reducidas nativamente:
embedding HALFVEC(512)   -- 83% menos espacio que 1536, recall ~94%
embedding HALFVEC(768)   -- 50% menos espacio que 1536, recall ~97%

-- Para datos empresariales estructurados (clientes, productos, facturas),
-- 512 dimensiones suele ser suficiente.
```

#### C. Política de elegibilidad: no indexar todo

Este es el control más potente. Definir formalmente qué registros merecen un embedding:

```yaml
# elegibilidad.yaml — definir antes de comenzar
indexar:
  - CLIENTES activos con nombre completo y ciudad
  - PRODUCTOS vigentes en catálogo
  - FACTURAS de los últimos 24 meses
  - TICKETS abiertos o cerrados hace menos de 90 días

no_indexar:
  - tablas de parámetros y configuración
  - registros de auditoría y log
  - registros con soft-delete activo
  - entidades secundarias (direcciones, teléfonos de soporte)
  - cambios en campos no semánticos (timestamps, contadores, flags)
  - duplicados dentro del mismo tenant
```

En la práctica, esta política reduce el volumen real en 40-70%.

#### D. TTL: el índice semántico no es eterno

```sql
-- Job nocturno: limpiar embeddings de registros inactivos
-- El dato original sigue en la base operativa. Solo se borra el embedding.
DELETE FROM semantic_index
WHERE
    entity_type    = 'TICKET'
    AND indexed_at < NOW() - INTERVAL '6 months'
    AND (metadata->>'estado') IN ('CERRADO', 'CANCELADO');

DELETE FROM semantic_index
WHERE
    entity_type    = 'FACTURA'
    AND source_updated < NOW() - INTERVAL '24 months';
```

### 5.3 El umbral de migración

pgvector es la respuesta correcta hasta cierto punto. Más allá, hay que migrar
el motor vectorial sin tocar las bases operativas (los IDs no cambian).

```
ZONA VERDE   — pgvector funciona bien
  < 5 millones de registros
  Latencias: 5-50 ms consistentes
  Acción: monitorear crecimiento mensual

ZONA AMARILLA — pgvector bajo presión
  5-15 millones de registros
  Latencias: a veces > 500 ms
  Acción: evaluar pgvectorscale (DiskANN) como extensión intermedia
          o Qdrant en paralelo para nuevas consultas

ZONA ROJA     — pgvector no es suficiente
  > 15 millones de registros en una sola instancia sin sharding
  El índice HNSW supera la RAM disponible
  Acción: migrar a Qdrant (self-hosted) o Milvus según la escala
          Los IDs siguen apuntando a las mismas bases operativas
          La migración es transparente para las aplicaciones de negocio
```

---

## Parte VI — Configuración del Servidor PostgreSQL

Ajustes en `postgresql.conf` específicos para la base `semantic_store`:

```ini
# Construcción paralela de índices HNSW
# Regla: mínimo 2 GB por millón de vectores durante la construcción
maintenance_work_mem = 4GB

# Paralelismo en construcción de índices
max_parallel_maintenance_workers = 4

# Buffers compartidos (incrementar si el índice cabe en RAM)
shared_buffers = 16GB

# Autovacuum más agresivo para tablas vectoriales
# (los vectores son grandes, el bloat se acumula más rápido)
autovacuum_vacuum_scale_factor  = 0.05
autovacuum_analyze_scale_factor = 0.02
```

```sql
-- Configurar autovacuum específicamente en la tabla vectorial
ALTER TABLE semantic_index SET (
    autovacuum_vacuum_scale_factor  = 0.05,
    autovacuum_analyze_scale_factor = 0.02
);
```

---

## Parte VII — Checklist de Implementación

**Antes de escribir código:**
- [ ] Definir la política de elegibilidad (qué se indexa, qué no)
- [ ] Decidir las dimensiones del embedding (1536 / 768 / 512)
- [ ] Estimar el volumen inicial y proyección a 3 años
- [ ] Verificar RAM disponible en el servidor destino vs RAM necesaria para HNSW

**Infraestructura:**
- [ ] Crear base de datos `semantic_store` separada de las operativas
- [ ] Instalar pgvector solo en `semantic_store`
- [ ] Crear usuarios `semantic_svc` y `semantic_reader` con permisos mínimos
- [ ] Crear tabla `semantic_index` con `HALFVEC`, no `VECTOR`
- [ ] Crear tabla particionada desde el inicio si se proyectan > 5M registros
- [ ] Crear índice HNSW con `CONCURRENTLY`
- [ ] Configurar `maintenance_work_mem` y `max_parallel_maintenance_workers`
- [ ] Configurar autovacuum agresivo en la tabla vectorial

**Proceso de indexación:**
- [ ] Implementar normalizadores de texto por tipo de entidad
- [ ] Conectar el normalizador al CDC/WAL existente
- [ ] Implementar upsert con `ON CONFLICT`
- [ ] Implementar eliminación cuando CDC captura un DELETE
- [ ] Implementar el job de TTL/limpieza nocturno

**Búsqueda:**
- [ ] Implementar búsqueda en dos pasos (índice → base operativa)
- [ ] Usar `SET LOCAL hnsw.ef_search` dentro de transacción, no `SET` global
- [ ] Establecer umbral mínimo de score (descartar resultados < 0.70)

**Monitoreo:**
- [ ] Alertas sobre crecimiento mensual de `semantic_index`
- [ ] Monitoreo de latencia de consultas vectoriales (p95, p99)
- [ ] Reporte mensual de distribución por tenant y tipo de entidad
- [ ] Detección de embeddings desactualizados (`source_updated > indexed_at`)

---

## Resumen

| Pregunta | Respuesta |
|---|---|
| ¿Afecta las bases existentes? | **No.** La extensión vive en `semantic_store`, una BD completamente separada |
| ¿Requiere modificar tablas existentes? | **No.** El CDC lee el WAL sin tocar nada |
| ¿Qué tipo de columna usar? | **HALFVEC, no VECTOR.** 50% menos espacio, mismo recall |
| ¿Cuándo particionar? | **Desde el inicio** si se proyectan > 5M registros |
| ¿Qué es lo más importante antes de indexar? | **La política de elegibilidad** |
| ¿pgvector escala a 110+ apps? | **Con mitigaciones sí, hasta ~15M registros** |
| ¿Cuándo migrar a Qdrant/Milvus? | **Cuando el índice HNSW supere la RAM del servidor** |
| ¿La migración afecta las bases operativas? | **Nunca. Los entity_id siguen siendo los mismos** |

---

*Documento unificado. Combina implementación no invasiva, diseño de BD paralela*
*y evaluación de crecimiento para el escenario de 110+ aplicaciones.*
*pgvector v0.8.2 | PostgreSQL 18 | Proyecciones calculadas sobre datos reales de producción.*
