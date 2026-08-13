-- ============================================================
-- bauth_T580__pol_atomlang_node_schema.sql
-- Seed — catálogo de grupos del árbol AtomLang
--
-- ESTRUCTURA JERÁRQUICA (ATOMLANG-ESTRUCTURA-JERARQUICA.md §2):
--   domain → block → policy_set / policy → rule → atom
--
-- Cada tipo de nodo tiene una fila "self" (grupo_slug = node_type)
-- con parent_id apuntando al tipo padre. Los grupos de atributos
-- son hijos de la fila "self" de su tipo de nodo.
--
-- Árbol resultante:
--   domain (self, raíz)
--     datos  (grupo)
--     block  (self, hijo de domain)
--       datos (grupo)
--       policy_set (self, hijo de block)
--         datos  (grupo)
--         target (grupo) → subject (subgrupo)
--       policy (self, hijo de block)
--         datos  (grupo)
--         target (grupo) → subject (subgrupo)
--         rule (self, hijo de policy)
--           datos  (grupo)
--           target (grupo) → subject (subgrupo)
--           atom (self, hijo de rule)
--             identidad (grupo)
--             TARGET (grupo) → subject (subgrupo)
--             CONDITION (grupo)
--             EFFECT (grupo) → obligation_advice, worm (subgrupos)
--             encoding_fisico (grupo)
--
-- Regla: GRUPO = todo nodo con hijos en el árbol fuente.
--        ATRIBUTO = hoja (T-581).
-- ============================================================

DO $$
DECLARE
    -- Filas "self" (contenedor del tipo de nodo)
    v_domain      UUID;
    v_block       UUID;
    v_policy_set  UUID;
    v_policy      UUID;
    v_rule        UUID;
    v_atom        UUID;

    -- Grupos hijos de domain
    v_domain_datos UUID;

    -- Grupos hijos de block
    v_block_datos  UUID;

    -- Grupos hijos de policy_set
    v_ps_datos     UUID;
    v_ps_target    UUID;

    -- Grupos hijos de policy
    v_po_datos     UUID;
    v_po_target    UUID;

    -- Grupos hijos de rule
    v_ru_datos     UUID;
    v_ru_target    UUID;

    -- Grupos hijos de atom
    v_at_identidad UUID;
    v_at_target    UUID;
    v_at_condition UUID;
    v_at_effect    UUID;
    v_at_encoding  UUID;

    -- Grupos _common (cross-cutting)
    v_cm_identidad UUID;
    v_cm_nombre    UUID;
    v_cm_posicion  UUID;
    v_cm_ciclo     UUID;

BEGIN

-- ======================================================================
-- 0. Limpieza: eliminar seed previo (FK bypass temporal)
-- ======================================================================
EXECUTE 'SET LOCAL session_replication_role = replica';
DELETE FROM bauth.pol_atomlang_attr_schema WHERE ctx_id = 'seed';
DELETE FROM bauth.pol_atomlang_node_schema  WHERE ctx_id = 'seed';
EXECUTE 'SET LOCAL session_replication_role = origin';

-- ======================================================================
-- 1. DOMAIN — raíz de la jerarquía
-- ======================================================================

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('domain','domain',NULL,
        '{"es":"Dominio","en":"Domain"}',
        '{"es":"Namespace organizacional raíz. Agrupa Bloques y PolicySets de un área funcional.","en":"Root organizational namespace. Groups Blocks and PolicySets of a functional area."}',
        'globe','#6366F1',0,false,false,true,'seed')
RETURNING schema_id INTO v_domain;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('domain','datos',v_domain,
        '{"es":"Datos","en":"Data"}',
        '{"es":"Identificador, nombre, owner, clasificación, versión y PolicySet raíz del dominio.","en":"Identifier, name, owner, classification, version and root PolicySet of the domain."}',
        'database','#6366F1',0,false,false,true,'seed')
RETURNING schema_id INTO v_domain_datos;

-- ======================================================================
-- 2. BLOCK — hijo de domain
-- ======================================================================

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('block','block',v_domain,
        '{"es":"Bloque","en":"Block"}',
        '{"es":"Subdivisión funcional del dominio. Agrupa un tipo de recurso con su PolicySet representativo.","en":"Functional subdivision of the domain. Groups a resource type with its representative PolicySet."}',
        'box','#8B5CF6',1,false,false,true,'seed')
RETURNING schema_id INTO v_block;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('block','datos',v_block,
        '{"es":"Datos","en":"Data"}',
        '{"es":"Identificador, dominio padre, tipo de recurso agrupado y Policy/PolicySet representativo.","en":"Identifier, parent domain, grouped resource type and representative Policy/PolicySet."}',
        'database','#8B5CF6',0,false,false,true,'seed')
RETURNING schema_id INTO v_block_datos;

-- ======================================================================
-- 3. POLICY_SET — hijo de block
-- ======================================================================

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('policy_set','policy_set',v_block,
        '{"es":"PolicySet","en":"PolicySet"}',
        '{"es":"Nodo de combinación XACML. Agrupa Policies hijas con un algoritmo de decisión.","en":"XACML combination node. Groups child Policies with a decision algorithm."}',
        'layers','#0EA5E9',2,false,false,true,'seed')
RETURNING schema_id INTO v_policy_set;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('policy_set','datos',v_policy_set,
        '{"es":"Datos","en":"Data"}',
        '{"es":"Identificador, algoritmo de combinación, estado, versión e issuer del PolicySet.","en":"Identifier, combining algorithm, status, version and issuer of the PolicySet."}',
        'database','#0EA5E9',0,false,false,true,'seed')
RETURNING schema_id INTO v_ps_datos;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('policy_set','target',v_policy_set,
        '{"es":"Target","en":"Target"}',
        '{"es":"Heredable por las Policies hijas. Define el contexto del PolicySet.","en":"Inheritable by child Policies. Defines the PolicySet context."}',
        'crosshair','#0EA5E9',1,false,false,true,'seed')
RETURNING schema_id INTO v_ps_target;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('policy_set','subject',v_ps_target,
        '{"es":"Subject","en":"Subject"}',
        '{"es":"set/unset/userset/userunset. Quién queda incluido o excluido en este PolicySet.","en":"set/unset/userset/userunset. Who is included or excluded in this PolicySet."}',
        'users','#0EA5E9',0,false,false,true,'seed');

-- ======================================================================
-- 4. POLICY — hijo de block (hermano de policy_set)
-- ======================================================================

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('policy','policy',v_block,
        '{"es":"Policy","en":"Policy"}',
        '{"es":"Contiene Rules. Produce una decisión combinando los efectos de sus Rules hijos.","en":"Contains Rules. Produces a decision by combining the effects of its child Rules."}',
        'file-text','#06B6D4',3,false,false,true,'seed')
RETURNING schema_id INTO v_policy;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('policy','datos',v_policy,
        '{"es":"Datos","en":"Data"}',
        '{"es":"Identificador, tipo, algoritmo de combinación, estado, versión e issuer de la Policy.","en":"Identifier, type, combining algorithm, status, version and issuer of the Policy."}',
        'database','#06B6D4',0,false,false,true,'seed')
RETURNING schema_id INTO v_po_datos;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('policy','target',v_policy,
        '{"es":"Target","en":"Target"}',
        '{"es":"Heredable por los Rules hijos. No evaluable en este nivel — define el contexto de la Policy.","en":"Inheritable by child Rules. Not evaluated at this level — defines Policy context."}',
        'crosshair','#06B6D4',1,false,false,true,'seed')
RETURNING schema_id INTO v_po_target;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('policy','subject',v_po_target,
        '{"es":"Subject","en":"Subject"}',
        '{"es":"set/unset/userset/userunset. Quién queda incluido o excluido en esta Policy.","en":"set/unset/userset/userunset. Who is included or excluded in this Policy."}',
        'users','#06B6D4',0,false,false,true,'seed');

-- ======================================================================
-- 5. RULE — hijo de policy
-- ======================================================================

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('rule','rule',v_policy,
        '{"es":"Rule","en":"Rule"}',
        '{"es":"Unidad de autorización. Evalúa TARGET + CONDITION y produce EFFECT (PERMIT|DENY).","en":"Authorization unit. Evaluates TARGET + CONDITION and produces EFFECT (PERMIT|DENY)."}',
        'list','#10B981',2,false,false,true,'seed')
RETURNING schema_id INTO v_rule;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('rule','datos',v_rule,
        '{"es":"Datos","en":"Data"}',
        '{"es":"Identificador, Policy padre, descripción semántica y algoritmo de combinación si tiene múltiples Atoms.","en":"Identifier, parent Policy, semantic description and combining algorithm if multiple Atoms."}',
        'database','#10B981',0,false,false,true,'seed')
RETURNING schema_id INTO v_ru_datos;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('rule','target',v_rule,
        '{"es":"Target","en":"Target"}',
        '{"es":"Override opcional del Target heredado de la Policy padre.","en":"Optional override of Target inherited from parent Policy."}',
        'crosshair','#10B981',1,false,false,true,'seed')
RETURNING schema_id INTO v_ru_target;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('rule','subject',v_ru_target,
        '{"es":"Subject","en":"Subject"}',
        '{"es":"Override opcional: set/unset/userset/userunset para este Rule específico.","en":"Optional override: set/unset/userset/userunset for this specific Rule."}',
        'users','#10B981',0,false,false,true,'seed');

-- ======================================================================
-- 6. ATOM — hijo de rule
-- ======================================================================

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('atom','atom',v_rule,
        '{"es":"Átomo","en":"Atom"}',
        '{"es":"Unidad mínima de autorización. Define identidad, target, condición, efecto y encoding físico.","en":"Minimum authorization unit. Defines identity, target, condition, effect and physical encoding."}',
        'cpu','#F59E0B',3,false,false,true,'seed')
RETURNING schema_id INTO v_atom;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('atom','identidad',v_atom,
        '{"es":"Identidad","en":"Identity"}',
        '{"es":"ID canónico del átomo: dominio, bloque, verbo, dependencias y versión.","en":"Canonical atom ID: domain, block, verb, dependencies and version."}',
        'fingerprint','#6366F1',0,false,false,true,'seed')
RETURNING schema_id INTO v_at_identidad;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('atom','TARGET',v_atom,
        '{"es":"Target","en":"Target"}',
        '{"es":"Fase 1 de evaluación: ¿aplica esta regla? — subject + resource + action + environment.","en":"Phase 1 evaluation: does this rule apply? — subject + resource + action + environment."}',
        'crosshair','#0EA5E9',1,false,false,true,'seed')
RETURNING schema_id INTO v_at_target;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('atom','subject',v_at_target,
        '{"es":"Subject","en":"Subject"}',
        '{"es":"set/unset (por rol) + userset/userunset (por usuario). Quién queda incluido o excluido.","en":"set/unset (by role) + userset/userunset (by user). Who is included or excluded."}',
        'users','#0EA5E9',0,false,false,true,'seed');

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('atom','CONDITION',v_atom,
        '{"es":"Condition","en":"Condition"}',
        '{"es":"Condición de activación evaluada en runtime. null si no aplica.","en":"Runtime activation condition. null if not applicable."}',
        'filter','#F59E0B',2,false,false,true,'seed')
RETURNING schema_id INTO v_at_condition;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('atom','EFFECT',v_atom,
        '{"es":"Effect","en":"Effect"}',
        '{"es":"Decisión de autorización + obligation/advice post-decisión + auditoría WORM.","en":"Authorization decision + post-decision obligation/advice + WORM audit."}',
        'zap','#10B981',3,false,false,true,'seed')
RETURNING schema_id INTO v_at_effect;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('atom','obligation_advice',v_at_effect,
        '{"es":"Obligation / Advice","en":"Obligation / Advice"}',
        '{"es":"Reactivo condicional: obligation vinculante si EFFECT == fulfill_on. advice no vinculante.","en":"Conditional reactive: binding obligation if EFFECT == fulfill_on. Non-binding advice."}',
        'bell','#10B981',0,false,true,true,'seed');

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('atom','worm',v_at_effect,
        '{"es":"Auditoría WORM","en":"WORM Audit"}',
        '{"es":"Reactivo incondicional. Metadatos de creación inmutables: created_at, created_by, checksum SHA-256, referencia LSN WAL.","en":"Unconditional reactive. Immutable creation metadata: created_at, created_by, SHA-256 checksum, WAL LSN reference."}',
        'lock','#EF4444',1,true,true,true,'seed');

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('atom','encoding_fisico',v_atom,
        '{"es":"Encoding Físico","en":"Physical Encoding"}',
        '{"es":"Posición en el BitMask de 64 bits y one-hot del rol. Solo lectura — asignado por el motor.","en":"64-bit BitMask position and role one-hot. Read-only — assigned by the engine."}',
        'cpu','#64748B',4,true,false,true,'seed')
RETURNING schema_id INTO v_at_encoding;

-- ======================================================================
-- 7. TIPOS SIMPLES (sin jerarquía interna — no forman parte de la cadena principal)
-- ======================================================================

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('attribute','datos',NULL,
        '{"es":"Valor","en":"Value"}',
        '{"es":"Atributo textual del árbol.","en":"Textual tree attribute."}',
        'tag','#6366F1',0,false,false,true,'seed');

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('enum','datos',NULL,
        '{"es":"Enumeración","en":"Enumeration"}',
        '{"es":"Valor seleccionado y lista de opciones válidas del enumerador.","en":"Selected value and valid options list of the enumerator."}',
        'list-checks','#6366F1',0,false,false,true,'seed');

-- ======================================================================
-- 8. _COMMON — atributos comunes a todos los nodos (sin jerarquía interna)
-- ======================================================================

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('_common','identidad_comun',NULL,
        '{"es":"Identidad","en":"Identity"}',
        '{"es":"id, tenant_id, parent_id, node_type — identifica al nodo en el árbol.","en":"id, tenant_id, parent_id, node_type — identifies the node in the tree."}',
        'key','#6366F1',0,true,false,true,'seed')
RETURNING schema_id INTO v_cm_identidad;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('_common','nombre',NULL,
        '{"es":"Nombre","en":"Name"}',
        '{"es":"label, name, alias, description, help — presentación del nodo en la UI.","en":"label, name, alias, description, help — node presentation in the UI."}',
        'type','#0EA5E9',1,false,false,true,'seed')
RETURNING schema_id INTO v_cm_nombre;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('_common','posicion',NULL,
        '{"es":"Posición","en":"Position"}',
        '{"es":"depth, path, sort_order, order_idx — posición del nodo en el árbol jerárquico.","en":"depth, path, sort_order, order_idx — node position in the hierarchical tree."}',
        'git-branch','#10B981',2,true,false,true,'seed')
RETURNING schema_id INTO v_cm_posicion;

INSERT INTO bauth.pol_atomlang_node_schema
    (node_type, grupo_slug, parent_id, grupo_label, grupo_desc, icono, color,
     sort_order, readonly, reactivo, is_system, ctx_id)
VALUES
    ('_common','ciclo_de_vida',NULL,
        '{"es":"Ciclo de Vida","en":"Lifecycle"}',
        '{"es":"is_active, version, valid_from, valid_until, created_at, updated_at — estado temporal del nodo.","en":"is_active, version, valid_from, valid_until, created_at, updated_at — node temporal state."}',
        'clock','#F59E0B',3,true,false,true,'seed')
RETURNING schema_id INTO v_cm_ciclo;

END $$;
