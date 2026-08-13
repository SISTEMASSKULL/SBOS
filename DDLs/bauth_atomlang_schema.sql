-- ============================================================
-- bauth_atomlang_schema.sql
-- DDL exclusivo: Catálogo dinámico de grupos y atributos del árbol AtomLang
--
-- Propósito:
--   Define la jerarquía de grupos y atributos que describe cada node_type
--   del árbol AtomLang (atom, rule, policy, policy_set, domain, block…).
--   La estructura es data-driven y configurable por CRUD desde el desktop,
--   sin necesidad de recompilar el daemon cuando cambian normas o estándares.
--
-- Analogía con identidad:
--   pol_atomlang_node_schema  ≈  idn_identity_entity    (jerarquía de grupos)
--   pol_atomlang_attr_schema  ≈  idn_identity_attribute  (hojas/atributos de cada grupo)
--
-- Seed inicial:
--   DDLs/seeds/bauth_T580__pol_atomlang_node_schema.sql
--   DDLs/seeds/bauth_T581__pol_atomlang_attr_schema.sql
--   Fuente de los valores iniciales: ATOMLANG-ESTRUCTURA-JERARQUICA.md
--
-- Tablas:
--   T-580  pol_atomlang_node_schema   — grupos (nodos con hijos, auto-referencial)
--   T-581  pol_atomlang_attr_schema   — atributos (hojas de cada grupo)
--   T-582  pol_atomlang_schema_history — historial WORM de cambios
--
-- Schema: bauth
-- Prefijo columnas: pol_
-- Normas: ATOMLANG-ESTRUCTURA-JERARQUICA.md · A.46 §2 · DOC-SBOS-001 N3
-- ============================================================

-- ======================================================================
-- ENUMs exclusivos de este módulo
-- ======================================================================

DO $$ BEGIN
    CREATE TYPE bauth.atomlang_attr_tipo_enum AS ENUM (
        'uuid',           -- UUID v7
        'text',           -- texto libre
        'slug',           -- identificador snake_case FK a catálogo
        'slug[]',         -- array de slugs (ej: set, unset, userset)
        'text[]',         -- array de texto libre
        'bool',           -- booleano
        'bigint',         -- entero grande (ej: bit_position)
        'int',            -- entero
        'semver',         -- versión semántica X.Y.Z
        'enum',           -- valor de lista cerrada (valores en attr_enum_valores)
        'expression',     -- expresión booleana AtomLang (condition)
        'jsonb',          -- JSONB libre
        'timestamptz',    -- timestamp con zona horaria
        'date'            -- fecha
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ======================================================================
-- T-580 — bauth.pol_atomlang_node_schema
-- Catálogo de grupos del árbol AtomLang. Auto-referencial (subgrupos).
-- Análogo a idn_identity_entity: jerarquía de nodos con parent_id.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.pol_atomlang_node_schema (
    schema_id        UUID         PRIMARY KEY DEFAULT uuidv7(),

    -- Identificación
    node_type        TEXT         NOT NULL
        CHECK (node_type IN (
            'tenant','domain','block',
            'policy_set','policy','rule','atom',
            'object','list','event',
            'attribute','enum',
            '_common'           -- grupos comunes a todos los node_type (tab Atrib. comunes)
        )),
    grupo_slug       TEXT         NOT NULL,        -- snake_case, ej: identidad, TARGET, subject
    parent_id        UUID         REFERENCES bauth.pol_atomlang_node_schema(schema_id)
                                  ON DELETE RESTRICT,   -- subgrupos: subject dentro de TARGET

    -- Presentación
    grupo_label      JSONB        NOT NULL DEFAULT '{"es":"","en":""}',
                                  -- {es: "Identidad", en: "Identity"}
    grupo_desc       JSONB        NOT NULL DEFAULT '{"es":"","en":""}',
                                  -- descripción visible en UI tooltip
    icono            TEXT         NULL,            -- nombre de ícono Lucide (ej: "fingerprint")
    color            TEXT         NULL,            -- hex color para el encabezado del grupo (ej: "#6366F1")

    -- Comportamiento
    sort_order       SMALLINT     NOT NULL DEFAULT 0,
    readonly         BOOLEAN      NOT NULL DEFAULT false,
                                  -- true = el grupo entero es solo lectura (ej: encoding físico, WORM)
    reactivo         BOOLEAN      NOT NULL DEFAULT false,
                                  -- true = el grupo es reactivo post-EFFECT (ej: obligation/advice, WORM)

    -- Gobernanza
    is_system        BOOLEAN      NOT NULL DEFAULT true,
                                  -- true = viene del seed (no se puede eliminar, solo desactivar)
    is_active        BOOLEAN      NOT NULL DEFAULT true,
    ctx_id           TEXT         NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_pans_nodetype_slug UNIQUE (node_type, grupo_slug, parent_id)
);

CREATE INDEX IF NOT EXISTS idx_pans_nodetype   ON bauth.pol_atomlang_node_schema(node_type, sort_order);
CREATE INDEX IF NOT EXISTS idx_pans_parent     ON bauth.pol_atomlang_node_schema(parent_id);
CREATE INDEX IF NOT EXISTS idx_pans_active     ON bauth.pol_atomlang_node_schema(node_type, is_active)
    WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_pans_label      ON bauth.pol_atomlang_node_schema
    USING GIN (grupo_label jsonb_path_ops);

COMMENT ON TABLE bauth.pol_atomlang_node_schema IS
'ATOMLANG SCHEMA | Catálogo dinámico de grupos (nodos con hijos) del árbol AtomLang.
Análogo a idn_identity_entity (T-156): jerarquía auto-referencial con parent_id
para representar subgrupos (ej: "subject" dentro de "TARGET").

Cada fila = un grupo visible en el panel "Atrib. grupo" del desktop editor.
Un grupo es cualquier nodo del árbol AtomLang que tiene hijos — por oposición a
los atributos (pol_atomlang_attr_schema T-581) que son las hojas sin hijos.

node_type: a qué tipo de nodo AtomLang pertenece este grupo. Valor especial
"_common" para grupos comunes a todos los node_type (tab Atrib. comunes).
parent_id: NULL = grupo de primer nivel. No-NULL = subgrupo (ej: subject ⊂ TARGET).

Seed inicial desde ATOMLANG-ESTRUCTURA-JERARQUICA.md.
Modificable por CRUD desde el desktop sin recompilar el daemon.
is_system=true: viene del seed canónico, no se puede eliminar (solo is_active=false).
reactivo=true: el grupo se ejecuta después de que EFFECT tomó su valor (obligation/advice, WORM).

Fuente: bauth.rol_template.schema.node_type RPC lee esta tabla.
Escritura: bauth.atomlang.schema.grupo.* (CRUD completo para admin).
Normas: ATOMLANG-ESTRUCTURA-JERARQUICA.md · A.46 §2 · DOC-SBOS-001 N3. T-580.';

COMMENT ON COLUMN bauth.pol_atomlang_node_schema.node_type    IS 'Tipo de nodo AtomLang al que pertenece este grupo. _common = aplica a todos.';
COMMENT ON COLUMN bauth.pol_atomlang_node_schema.grupo_slug   IS 'Identificador técnico snake_case único por (node_type, parent_id). Ej: identidad, TARGET, subject, EFFECT, encoding_fisico.';
COMMENT ON COLUMN bauth.pol_atomlang_node_schema.parent_id    IS 'NULL = grupo raíz del node_type. No-NULL = subgrupo (ej: subject es hijo de TARGET).';
COMMENT ON COLUMN bauth.pol_atomlang_node_schema.grupo_label  IS 'Etiqueta visible multiidioma {es, en}. Renderizada como encabezado del grupo en el panel.';
COMMENT ON COLUMN bauth.pol_atomlang_node_schema.grupo_desc   IS 'Descripción del grupo {es, en}. Mostrada como subcabecera o tooltip en el panel.';
COMMENT ON COLUMN bauth.pol_atomlang_node_schema.icono        IS 'Nombre de ícono Lucide (ej: fingerprint, shield, zap). Mostrado junto al título del grupo.';
COMMENT ON COLUMN bauth.pol_atomlang_node_schema.color        IS 'Color hex del encabezado del grupo (ej: #6366F1). NULL = color del tema.';
COMMENT ON COLUMN bauth.pol_atomlang_node_schema.sort_order   IS 'Orden de presentación entre grupos del mismo (node_type, parent_id).';
COMMENT ON COLUMN bauth.pol_atomlang_node_schema.readonly     IS 'true = ningún atributo del grupo es editable (ej: encoding físico, WORM).';
COMMENT ON COLUMN bauth.pol_atomlang_node_schema.reactivo     IS 'true = el grupo es reactivo post-EFFECT (obligation/advice, auditoría WORM). No participa en la evaluación PERMIT/DENY.';
COMMENT ON COLUMN bauth.pol_atomlang_node_schema.is_system    IS 'true = definido en el seed canónico. No se puede eliminar, solo desactivar.';


-- ======================================================================
-- T-581 — bauth.pol_atomlang_attr_schema
-- Atributos (hojas) de cada grupo. Análogo a idn_identity_attribute (T-157).
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.pol_atomlang_attr_schema (
    attr_id          UUID         PRIMARY KEY DEFAULT uuidv7(),
    schema_id        UUID         NOT NULL
                                  REFERENCES bauth.pol_atomlang_node_schema(schema_id)
                                  ON DELETE CASCADE,

    -- Identificación del atributo
    attr_key         TEXT         NOT NULL,        -- snake_case, ej: id, verb_id, set, effect
    attr_label       JSONB        NOT NULL DEFAULT '{"es":"","en":""}',
    attr_desc        JSONB        NOT NULL DEFAULT '{"es":"","en":""}',

    -- Tipo y valores
    attr_tipo        bauth.atomlang_attr_tipo_enum NOT NULL DEFAULT 'text',
    attr_enum_valores TEXT[]      NULL,            -- solo si attr_tipo = 'enum'
    attr_default     JSONB        NULL,            -- valor por defecto (puede ser null)

    -- Presentación
    icono            TEXT         NULL,            -- ícono Lucide para el campo individual
    color            TEXT         NULL,            -- color hex del campo (highlight)
    sort_order       SMALLINT     NOT NULL DEFAULT 0,

    -- Comportamiento
    readonly         BOOLEAN      NOT NULL DEFAULT false,
    nullable         BOOLEAN      NOT NULL DEFAULT true,
    obligatorio      BOOLEAN      NOT NULL DEFAULT false,

    -- Gobernanza
    is_system        BOOLEAN      NOT NULL DEFAULT true,
    is_active        BOOLEAN      NOT NULL DEFAULT true,
    ctx_id           TEXT         NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_paas_schema_key  UNIQUE (schema_id, attr_key),
    CONSTRAINT chk_paas_enum_vals  CHECK (
        attr_tipo != 'enum' OR (attr_enum_valores IS NOT NULL AND array_length(attr_enum_valores, 1) > 0)
    )
);

CREATE INDEX IF NOT EXISTS idx_paas_schema    ON bauth.pol_atomlang_attr_schema(schema_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_paas_key       ON bauth.pol_atomlang_attr_schema(attr_key);
CREATE INDEX IF NOT EXISTS idx_paas_active    ON bauth.pol_atomlang_attr_schema(schema_id, is_active)
    WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_paas_tipo      ON bauth.pol_atomlang_attr_schema(attr_tipo);

COMMENT ON TABLE bauth.pol_atomlang_attr_schema IS
'ATOMLANG SCHEMA | Atributos (hojas) de cada grupo del árbol AtomLang.
Análogo a idn_identity_attribute (T-157): cada fila es un atributo (campo editable)
que pertenece a un grupo (T-580). Un atributo es un nodo HOJA — no tiene hijos.

La combinación (schema_id, attr_key) es única: un grupo no puede tener dos
atributos con el mismo key. El CRUD del desktop permite agregar, modificar o
desactivar atributos sin tocar código. Cuando los estándares cambian (nueva norma
exige un nuevo campo), el admin lo agrega desde la UI — sin recompilar el daemon.

attr_tipo: controla qué tipo de input se renderiza en _CampoFila (texto libre,
enum dropdown, UUID read-only, expresión booleana, array de slugs con chips…).
attr_enum_valores: solo si attr_tipo=enum. CHECK garantiza que no esté vacío.
attr_default: valor inicial en la UI al crear un nuevo nodo. Puede ser null.

Seed inicial desde ATOMLANG-ESTRUCTURA-JERARQUICA.md.
Fuente: bauth.rol_template.schema.node_type incluye estos atributos en la respuesta.
Escritura: bauth.atomlang.schema.attr.* (CRUD completo para admin).
Normas: ATOMLANG-ESTRUCTURA-JERARQUICA.md · A.46 §2 · DOC-SBOS-001 N3. T-581.';

COMMENT ON COLUMN bauth.pol_atomlang_attr_schema.schema_id        IS 'FK al grupo padre (T-580). ON DELETE CASCADE: si se elimina el grupo, se eliminan todos sus atributos.';
COMMENT ON COLUMN bauth.pol_atomlang_attr_schema.attr_key         IS 'Clave técnica snake_case del atributo (ej: id, verb_id, set, fulfill_on, bit_position). Única por grupo.';
COMMENT ON COLUMN bauth.pol_atomlang_attr_schema.attr_label       IS 'Etiqueta visible multiidioma {es, en}. Renderizada como nombre del campo en _CampoFila.';
COMMENT ON COLUMN bauth.pol_atomlang_attr_schema.attr_desc        IS 'Descripción del campo {es, en}. Mostrada debajo del label en _CampoFila como descripción secundaria.';
COMMENT ON COLUMN bauth.pol_atomlang_attr_schema.attr_tipo        IS 'Tipo de dato del atributo. Controla el input widget en el desktop y la validación en el daemon.';
COMMENT ON COLUMN bauth.pol_atomlang_attr_schema.attr_enum_valores IS 'Valores válidos si attr_tipo=enum (ej: {PERMIT, DENY}). CHECK garantiza no vacío cuando tipo=enum.';
COMMENT ON COLUMN bauth.pol_atomlang_attr_schema.attr_default     IS 'Valor por defecto JSONB al crear un nuevo nodo. NULL = sin valor por defecto.';
COMMENT ON COLUMN bauth.pol_atomlang_attr_schema.icono            IS 'Ícono Lucide individual para este campo (ej: key, lock, user). NULL = sin ícono.';
COMMENT ON COLUMN bauth.pol_atomlang_attr_schema.color            IS 'Color hex de resaltado del campo. NULL = color del tema.';
COMMENT ON COLUMN bauth.pol_atomlang_attr_schema.readonly         IS 'true = el campo es solo lectura en el editor (ej: id, bit_position, created_at).';
COMMENT ON COLUMN bauth.pol_atomlang_attr_schema.nullable         IS 'true = el campo puede ser null en el nodo (ej: condition puede ser null si no aplica).';
COMMENT ON COLUMN bauth.pol_atomlang_attr_schema.obligatorio      IS 'true = el campo es requerido para guardar el nodo (el daemon rechaza si es null y obligatorio=true).';
COMMENT ON COLUMN bauth.pol_atomlang_attr_schema.is_system        IS 'true = definido en el seed canónico. No se puede eliminar, solo desactivar.';


-- ======================================================================
-- T-582 — bauth.pol_atomlang_schema_history
-- Historial WORM de cambios en grupos y atributos del esquema.
-- Quién cambió qué y cuándo — trazabilidad de modificaciones al catálogo.
-- ======================================================================
CREATE TABLE IF NOT EXISTS bauth.pol_atomlang_schema_history (
    history_id       UUID         NOT NULL DEFAULT uuidv7(),
    target_table     TEXT         NOT NULL
        CHECK (target_table IN ('pol_atomlang_node_schema', 'pol_atomlang_attr_schema')),
    target_id        UUID         NOT NULL,        -- schema_id o attr_id que cambió
    operation        TEXT         NOT NULL
        CHECK (operation IN ('INSERT', 'UPDATE', 'DEACTIVATE', 'ACTIVATE')),
    changed_by       UUID         NULL
                                  REFERENCES bauth.idn_identity_entity(entity_id)
                                  ON DELETE SET NULL,
    before_value     JSONB        NULL,            -- estado antes del cambio
    after_value      JSONB        NOT NULL,        -- estado después del cambio
    motivo           TEXT         NULL,            -- razón del cambio (texto libre)
    ctx_id           TEXT         NOT NULL DEFAULT 'system',
    changed_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    PRIMARY KEY (history_id, changed_at)
) PARTITION BY RANGE (changed_at);

-- Partición inicial — ajustar según el año de arranque
CREATE TABLE IF NOT EXISTS bauth.pol_atomlang_schema_history_2026
    PARTITION OF bauth.pol_atomlang_schema_history
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE TABLE IF NOT EXISTS bauth.pol_atomlang_schema_history_2027
    PARTITION OF bauth.pol_atomlang_schema_history
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

CREATE INDEX IF NOT EXISTS idx_pash_target   ON bauth.pol_atomlang_schema_history(target_id, changed_at DESC);
COMMENT ON TABLE bauth.pol_atomlang_schema_history IS
'ATOMLANG SCHEMA | Historial WORM de cambios en el catálogo de esquema.
Cada vez que un admin modifica un grupo (T-580) o un atributo (T-581)
se registra aquí: quién lo cambió, cuándo, desde qué valor y a cuál.
Particionado por mes. Solo INSERT — nunca UPDATE ni DELETE.
Permite auditar quién cambió la definición del árbol y por qué motivo.
Normas: ISO 27001 A.8.15 (logging). T-582.';


-- ======================================================================
-- Trigger: actualizar updated_at automáticamente en T-580 y T-581
-- ======================================================================
CREATE OR REPLACE FUNCTION bauth.fn_pol_atomlang_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_pans_updated_at
    BEFORE UPDATE ON bauth.pol_atomlang_node_schema
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_pol_atomlang_updated_at();

CREATE OR REPLACE TRIGGER trg_paas_updated_at
    BEFORE UPDATE ON bauth.pol_atomlang_attr_schema
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_pol_atomlang_updated_at();
