-- ============================================================
-- bauth_T581__pol_atomlang_attr_schema.sql
-- Seed inicial — atributos (hojas) del árbol AtomLang
--
-- Fuente: ATOMLANG-ESTRUCTURA-JERARQUICA.md + ATOMLANG-NODOS-GRUPOS-ATRIBUTOS-BORRADOR.md
-- DEPENDE DE: bauth_T580__pol_atomlang_node_schema.sql (debe cargarse primero)
-- IDEMPOTENTE: ON CONFLICT DO NOTHING en todos los INSERTs.
--
-- NOTA: Los grupos de atom/rule/policy/etc. ahora tienen parent_id != NULL
--       (son hijos de las filas "self" de su tipo). Los SELECTs usan
--       solo (node_type, grupo_slug) — sin filtro parent_id — para
--       localizar el schema_id correctamente.
-- ============================================================

DO $$
DECLARE
    v_g UUID;  -- schema_id del grupo corriente (helper reutilizable)

BEGIN

-- ======================================================================
-- ATOM — identidad
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='atom' AND grupo_slug='identidad';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, readonly, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'id',
        '{"es":"ID","en":"ID"}',
        '{"es":"Identificador canónico del átomo: dNN.bloque.verbo — asignado por el motor.","en":"Canonical atom identifier: dNN.block.verb — assigned by the engine."}',
        'uuid',true,false,true,0,'key',true,'seed'),
    (v_g,'domain',
        '{"es":"Dominio","en":"Domain"}',
        '{"es":"Código del dominio de control (D00–D15, D98, D99).","en":"Control domain code (D00–D15, D98, D99)."}',
        'slug',false,false,true,1,'globe',true,'seed'),
    (v_g,'bloque',
        '{"es":"Bloque","en":"Block"}',
        '{"es":"Subdivisión funcional dentro del dominio (B01–B10).","en":"Functional subdivision within the domain (B01–B10)."}',
        'slug',false,false,true,2,'box',true,'seed'),
    (v_g,'verbo',
        '{"es":"Verbo","en":"Verb"}',
        '{"es":"Acción autorizada. FK a privilege_verb.verb_slug.","en":"Authorized action. FK to privilege_verb.verb_slug."}',
        'slug',false,false,true,3,'zap',true,'seed'),
    (v_g,'depends_on',
        '{"es":"Depende de","en":"Depends on"}',
        '{"es":"Árbol de dependencias: átomos padre que deben estar activos para que este átomo sea evaluable.","en":"Dependency tree: parent atoms that must be active for this atom to be evaluable."}',
        'slug[]',false,true,false,4,'git-merge',true,'seed'),
    (v_g,'version',
        '{"es":"Versión","en":"Version"}',
        '{"es":"Versión semántica del átomo (X.Y.Z).","en":"Semantic version of the atom (X.Y.Z)."}',
        'semver',false,true,false,5,'tag',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- ATOM — TARGET.subject (sub-grupo)
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='atom' AND grupo_slug='subject';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'set',
        '{"es":"Set (incluidos)","en":"Set (included)"}',
        '{"es":"Roles/sets INCLUIDOS en el target. Al menos uno requerido si kind=SET.","en":"INCLUDED roles/sets in target. At least one required if kind=SET."}',
        'slug[]',true,false,0,'user-check',true,'seed'),
    (v_g,'unset',
        '{"es":"Unset (excluidos)","en":"Unset (excluded)"}',
        '{"es":"Roles/sets EXCLUIDOS del target. El PEP niega si el sujeto pertenece a este conjunto.","en":"EXCLUDED roles/sets from target. PEP denies if subject belongs to this set."}',
        'slug[]',true,false,1,'user-x',true,'seed'),
    (v_g,'userset',
        '{"es":"Userset (usuarios incluidos)","en":"Userset (included users)"}',
        '{"es":"Usuarios específicos INCLUIDOS (nivel de identidad). Complementario a set/roles.","en":"Specific INCLUDED users (identity level). Complementary to set/roles."}',
        'slug[]',true,false,2,'users',true,'seed'),
    (v_g,'userunset',
        '{"es":"Userunset (usuarios excluidos)","en":"Userunset (excluded users)"}',
        '{"es":"Usuarios específicos EXCLUIDOS. Tiene prioridad sobre userset.","en":"Specific EXCLUDED users. Takes priority over userset."}',
        'slug[]',true,false,3,'user-minus',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- ATOM — TARGET (atributos directos de TARGET, no del sub-grupo subject)
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='atom' AND grupo_slug='TARGET';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'resource',
        '{"es":"Recurso","en":"Resource"}',
        '{"es":"Recurso sobre el que opera el átomo. FK al catálogo de recursos del dominio.","en":"Resource the atom operates on. FK to domain resource catalog."}',
        'slug',true,false,0,'database',true,'seed'),
    (v_g,'action',
        '{"es":"Acción","en":"Action"}',
        '{"es":"Acción/verbo permitida — mapea al verbo del átomo. FK a privilege_verb.","en":"Allowed action/verb — maps to atom verb. FK to privilege_verb."}',
        'slug',true,false,1,'play',true,'seed'),
    (v_g,'environment',
        '{"es":"Entorno","en":"Environment"}',
        '{"es":"Contexto ambiental: device · location · schedule · trust_level · red.","en":"Environmental context: device · location · schedule · trust_level · network."}',
        'text',true,false,2,'wifi',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- ATOM — CONDITION
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='atom' AND grupo_slug='CONDITION';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'condition',
        '{"es":"Expresión","en":"Expression"}',
        '{"es":"Expresión booleana evaluada en runtime (ej: ctx.location == ''BO''). null = sin condición adicional.","en":"Boolean expression evaluated at runtime (e.g.: ctx.location == ''BO''). null = no additional condition."}',
        'expression',true,false,0,'filter',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- ATOM — EFFECT.valor (atributo de valor del GRUPO EFFECT)
-- Regla AtomLang §1.1: EFFECT es GRUPO porque tiene hijos.
-- 'effect' es el atributo hoja que contiene el discriminante PERMIT|DENY.
-- En el árbol compilado atomc aplana este atributo al escalar normativo.
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='atom' AND grupo_slug='EFFECT';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, attr_enum_valores, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'effect',
        '{"es":"Decisión","en":"Decision"}',
        '{"es":"PERMIT = concede acceso · DENY = deniega acceso. Discriminante evaluado por el PDP.","en":"PERMIT = grants access · DENY = denies access. Evaluated discriminant by PDP."}',
        'enum',ARRAY['PERMIT','DENY'],false,true,0,'zap',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- ATOM — EFFECT.obligation_advice
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='atom' AND grupo_slug='obligation_advice';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, attr_enum_valores, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'fulfill_on',
        '{"es":"Disparar en","en":"Trigger on"}',
        '{"es":"PERMIT · ejecutar si se concedió el acceso · DENY · ejecutar si se denegó el acceso.","en":"PERMIT · execute if access was granted · DENY · execute if access was denied."}',
        'enum',ARRAY['PERMIT','DENY'],true,false,0,'toggle-left',true,'seed'),
    (v_g,'obligation',
        '{"es":"Obligation","en":"Obligation"}',
        '{"es":"Proceso vinculante que el PEP DEBE ejecutar cuando EFFECT == fulfill_on.","en":"Binding process the PEP MUST execute when EFFECT == fulfill_on."}',
        'text',NULL,true,false,1,'alert-triangle',true,'seed'),
    (v_g,'advice',
        '{"es":"Advice","en":"Advice"}',
        '{"es":"Sugerencia no vinculante al PEP. El PEP PUEDE ignorarla.","en":"Non-binding suggestion to PEP. PEP MAY ignore it."}',
        'text',NULL,true,false,2,'info',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- ATOM — EFFECT.worm (todos readonly)
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='atom' AND grupo_slug='worm';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, readonly, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'created_at',
        '{"es":"Creado en","en":"Created at"}',
        '{"es":"Timestamp de creación del átomo. Inmutable (WORM).","en":"Atom creation timestamp. Immutable (WORM)."}',
        'timestamptz',true,false,true,0,'clock',true,'seed'),
    (v_g,'created_by',
        '{"es":"Creado por","en":"Created by"}',
        '{"es":"UUID del actor que creó el átomo. FK a idn_identity_entity.","en":"UUID of actor who created the atom. FK to idn_identity_entity."}',
        'uuid',true,false,true,1,'user',true,'seed'),
    (v_g,'checksum',
        '{"es":"Checksum","en":"Checksum"}',
        '{"es":"SHA-256 del contenido del átomo. Verificación de integridad WORM.","en":"SHA-256 of atom content. WORM integrity verification."}',
        'text',true,false,true,2,'shield-check',true,'seed'),
    (v_g,'cdc_source',
        '{"es":"Fuente CDC","en":"CDC Source"}',
        '{"es":"Referencia WAL LSN del registro de cambio. Trazabilidad del evento de creación.","en":"WAL LSN reference of the change record. Creation event traceability."}',
        'text',true,true,false,3,'activity',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- ATOM — encoding_fisico (todos readonly)
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='atom' AND grupo_slug='encoding_fisico';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, readonly, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'bit_position',
        '{"es":"Bit Position","en":"Bit Position"}',
        '{"es":"Posición del átomo en el BitMask de 64 bits. Asignada por el motor PrivilegeEngine.","en":"Atom position in the 64-bit BitMask. Assigned by PrivilegeEngine."}',
        'bigint',true,true,false,0,'cpu',true,'seed'),
    (v_g,'role_mask',
        '{"es":"Role Mask","en":"Role Mask"}',
        '{"es":"One-hot encoding del rol en el BitMask. Calculado por el motor.","en":"Role one-hot encoding in the BitMask. Calculated by the engine."}',
        'bigint',true,true,false,1,'hash',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- POLICY_SET — atributos propios (en la fila self policy_set)
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='policy_set' AND grupo_slug='policy_set';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, attr_enum_valores, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'id',
        '{"es":"ID","en":"ID"}',
        '{"es":"Identificador del PolicySet.","en":"PolicySet identifier."}',
        'uuid',NULL,false,true,0,'key',true,'seed'),
    (v_g,'combining_algorithm',
        '{"es":"Algoritmo de combinación","en":"Combining Algorithm"}',
        '{"es":"Regla de combinación de decisiones de las Policies hijas.","en":"Decision combining rule for child Policies."}',
        'enum',ARRAY['deny-overrides','permit-overrides','first-applicable','deny-unless-permit','permit-unless-deny','aggregate-strictest'],
        false,true,1,'git-branch',true,'seed'),
    (v_g,'status',
        '{"es":"Estado","en":"Status"}',
        '{"es":"draft = borrador · active = activo · deprecated = obsoleto.","en":"draft = draft · active = active · deprecated = deprecated."}',
        'enum',ARRAY['draft','active','deprecated'],false,true,2,'activity',true,'seed'),
    (v_g,'version',
        '{"es":"Versión","en":"Version"}',
        '{"es":"Versión semántica del PolicySet.","en":"Semantic version of the PolicySet."}',
        'semver',NULL,true,false,3,'tag',true,'seed'),
    (v_g,'policy_issuer',
        '{"es":"Emisor","en":"Issuer"}',
        '{"es":"Equipo o rol que autorizó y firmó este PolicySet.","en":"Team or role that authorized and signed this PolicySet."}',
        'slug',NULL,true,false,4,'shield',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- POLICY_SET — target (attrs directas: resource, action, environment)
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='policy_set' AND grupo_slug='target';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'resource',
        '{"es":"Recurso","en":"Resource"}',
        '{"es":"Recurso heredable por las Policies hijas.","en":"Resource inheritable by child Policies."}',
        'slug',true,false,0,'database',true,'seed'),
    (v_g,'action',
        '{"es":"Acción","en":"Action"}',
        '{"es":"Acción/verbo heredable por las Policies hijas.","en":"Action/verb inheritable by child Policies."}',
        'slug',true,false,1,'play',true,'seed'),
    (v_g,'environment',
        '{"es":"Entorno","en":"Environment"}',
        '{"es":"Contexto ambiental heredable.","en":"Inheritable environmental context."}',
        'text',true,false,2,'wifi',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- POLICY_SET — target.subject
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='policy_set' AND grupo_slug='subject';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'set','{"es":"Set","en":"Set"}','{"es":"Roles/sets INCLUIDOS.","en":"INCLUDED roles/sets."}','slug[]',true,false,0,'user-check',true,'seed'),
    (v_g,'unset','{"es":"Unset","en":"Unset"}','{"es":"Roles/sets EXCLUIDOS.","en":"EXCLUDED roles/sets."}','slug[]',true,false,1,'user-x',true,'seed'),
    (v_g,'userset','{"es":"Userset","en":"Userset"}','{"es":"Usuarios específicos INCLUIDOS.","en":"Specific INCLUDED users."}','slug[]',true,false,2,'users',true,'seed'),
    (v_g,'userunset','{"es":"Userunset","en":"Userunset"}','{"es":"Usuarios específicos EXCLUIDOS.","en":"Specific EXCLUDED users."}','slug[]',true,false,3,'user-minus',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- POLICY — atributos propios (en la fila self policy)
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='policy' AND grupo_slug='policy';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, attr_enum_valores, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'id','{"es":"ID","en":"ID"}','{"es":"Identificador de la Policy.","en":"Policy identifier."}','uuid',NULL,false,true,0,'key',true,'seed'),
    (v_g,'type',
        '{"es":"Tipo","en":"Type"}',
        '{"es":"PolicySet = agrupa Policies · Policy = contiene Rules.","en":"PolicySet = groups Policies · Policy = contains Rules."}',
        'enum',ARRAY['PolicySet','Policy'],false,true,1,'layers',true,'seed'),
    (v_g,'combining_algorithm',
        '{"es":"Algoritmo de combinación","en":"Combining Algorithm"}',
        '{"es":"Regla de combinación de decisiones de los Rules hijos.","en":"Decision combining rule for child Rules."}',
        'enum',ARRAY['deny-overrides','permit-overrides','first-applicable','deny-unless-permit','permit-unless-deny','aggregate-strictest'],
        false,true,2,'git-branch',true,'seed'),
    (v_g,'status','{"es":"Estado","en":"Status"}','{"es":"draft · active · deprecated.","en":"draft · active · deprecated."}',
        'enum',ARRAY['draft','active','deprecated'],false,true,3,'activity',true,'seed'),
    (v_g,'version','{"es":"Versión","en":"Version"}','{"es":"Versión semántica.","en":"Semantic version."}','semver',NULL,true,false,4,'tag',true,'seed'),
    (v_g,'policy_issuer','{"es":"Emisor","en":"Issuer"}','{"es":"Equipo o rol que autorizó la Policy.","en":"Team or role that authorized the Policy."}','slug',NULL,true,false,5,'shield',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- POLICY — target (attrs directas)
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='policy' AND grupo_slug='target';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'resource','{"es":"Recurso","en":"Resource"}','{"es":"Recurso heredable por los Rules hijos.","en":"Resource inheritable by child Rules."}','slug',true,false,0,'database',true,'seed'),
    (v_g,'action','{"es":"Acción","en":"Action"}','{"es":"Acción heredable por los Rules hijos.","en":"Action inheritable by child Rules."}','slug',true,false,1,'play',true,'seed'),
    (v_g,'environment','{"es":"Entorno","en":"Environment"}','{"es":"Contexto ambiental heredable.","en":"Inheritable environmental context."}','text',true,false,2,'wifi',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- POLICY — target.subject
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='policy' AND grupo_slug='subject';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'set','{"es":"Set","en":"Set"}','{"es":"Roles/sets INCLUIDOS.","en":"INCLUDED roles/sets."}','slug[]',true,false,0,'user-check',true,'seed'),
    (v_g,'unset','{"es":"Unset","en":"Unset"}','{"es":"Roles/sets EXCLUIDOS.","en":"EXCLUDED roles/sets."}','slug[]',true,false,1,'user-x',true,'seed'),
    (v_g,'userset','{"es":"Userset","en":"Userset"}','{"es":"Usuarios específicos INCLUIDOS.","en":"Specific INCLUDED users."}','slug[]',true,false,2,'users',true,'seed'),
    (v_g,'userunset','{"es":"Userunset","en":"Userunset"}','{"es":"Usuarios específicos EXCLUIDOS.","en":"Specific EXCLUDED users."}','slug[]',true,false,3,'user-minus',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- RULE — atributos propios (en la fila self rule)
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='rule' AND grupo_slug='rule';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, attr_enum_valores, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'id','{"es":"ID","en":"ID"}','{"es":"Identificador del Rule.","en":"Rule identifier."}','uuid',NULL,false,true,0,'key',true,'seed'),
    (v_g,'policy_ref',
        '{"es":"Policy padre","en":"Parent Policy"}',
        '{"es":"FK a la Policy que contiene este Rule.","en":"FK to the Policy containing this Rule."}',
        'slug',NULL,false,true,1,'file-text',true,'seed'),
    (v_g,'description',
        '{"es":"Descripción","en":"Description"}',
        '{"es":"Semántica de negocio del Rule en lenguaje natural.","en":"Business semantics of the Rule in natural language."}',
        'text',NULL,true,false,2,'align-left',true,'seed'),
    (v_g,'rule_combining_algorithm',
        '{"es":"Algoritmo de combinación","en":"Combining Algorithm"}',
        '{"es":"Solo si el Rule tiene más de un Atom hijo.","en":"Only if the Rule has more than one child Atom."}',
        'enum',ARRAY['deny-overrides','permit-overrides','first-applicable','deny-unless-permit','permit-unless-deny','aggregate-strictest'],true,false,3,'git-branch',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- RULE — target (attrs directas)
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='rule' AND grupo_slug='target';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'resource','{"es":"Recurso (override)","en":"Resource (override)"}','{"es":"Override opcional del recurso heredado de la Policy padre.","en":"Optional override of resource inherited from parent Policy."}','slug',true,false,0,'database',true,'seed'),
    (v_g,'action','{"es":"Acción (override)","en":"Action (override)"}','{"es":"Override opcional de la acción heredada.","en":"Optional override of inherited action."}','slug',true,false,1,'play',true,'seed'),
    (v_g,'environment','{"es":"Entorno (override)","en":"Environment (override)"}','{"es":"Override opcional del contexto ambiental.","en":"Optional override of environmental context."}','text',true,false,2,'wifi',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- RULE — target.subject
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='rule' AND grupo_slug='subject';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'set','{"es":"Set (override)","en":"Set (override)"}','{"es":"Roles/sets INCLUIDOS (override).","en":"INCLUDED roles/sets (override)."}','slug[]',true,false,0,'user-check',true,'seed'),
    (v_g,'unset','{"es":"Unset (override)","en":"Unset (override)"}','{"es":"Roles/sets EXCLUIDOS (override).","en":"EXCLUDED roles/sets (override)."}','slug[]',true,false,1,'user-x',true,'seed'),
    (v_g,'userset','{"es":"Userset (override)","en":"Userset (override)"}','{"es":"Usuarios INCLUIDOS (override).","en":"INCLUDED users (override)."}','slug[]',true,false,2,'users',true,'seed'),
    (v_g,'userunset','{"es":"Userunset (override)","en":"Userunset (override)"}','{"es":"Usuarios EXCLUIDOS (override).","en":"EXCLUDED users (override)."}','slug[]',true,false,3,'user-minus',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- DOMAIN — atributos propios (en la fila self domain)
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='domain' AND grupo_slug='domain';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, attr_enum_valores, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'id','{"es":"ID","en":"ID"}','{"es":"Código del dominio (D00–D15, D98, D99).","en":"Domain code (D00–D15, D98, D99)."}','slug',NULL,false,true,0,'key',true,'seed'),
    (v_g,'nombre','{"es":"Nombre","en":"Name"}','{"es":"Nombre descriptivo del dominio.","en":"Descriptive name of the domain."}','text',NULL,false,true,1,'type',true,'seed'),
    (v_g,'owner','{"es":"Owner","en":"Owner"}','{"es":"Equipo o rol responsable de la gobernanza del dominio.","en":"Team or role responsible for domain governance."}','slug',NULL,true,false,2,'shield',true,'seed'),
    (v_g,'classification',
        '{"es":"Clasificación","en":"Classification"}',
        '{"es":"Sensibilidad general: financiero · PII · critico · interno.","en":"General sensitivity: financial · PII · critical · internal."}',
        'enum',ARRAY['financiero','PII','critico','interno','publico'],true,false,3,'tag',true,'seed'),
    (v_g,'version','{"es":"Versión","en":"Version"}','{"es":"Versión semántica del dominio.","en":"Domain semantic version."}','semver',NULL,true,false,4,'tag',true,'seed'),
    (v_g,'policy_set_ref','{"es":"PolicySet raíz","en":"Root PolicySet"}','{"es":"FK al PolicySet raíz del dominio.","en":"FK to the domain root PolicySet."}','slug',NULL,true,false,5,'layers',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- BLOCK — atributos propios (en la fila self block)
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='block' AND grupo_slug='block';

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'id','{"es":"ID","en":"ID"}','{"es":"Identificador del bloque.","en":"Block identifier."}','slug',false,true,0,'key',true,'seed'),
    (v_g,'domain_ref','{"es":"Dominio padre","en":"Parent Domain"}','{"es":"FK al dominio al que pertenece este bloque.","en":"FK to the domain this block belongs to."}','slug',false,true,1,'globe',true,'seed'),
    (v_g,'resource_type','{"es":"Tipo de recurso","en":"Resource Type"}','{"es":"Tipo de recurso agrupado por este bloque.","en":"Resource type grouped by this block."}','text',true,false,2,'box',true,'seed'),
    (v_g,'policy_ref','{"es":"Policy/PolicySet","en":"Policy/PolicySet"}','{"es":"FK a la Policy o PolicySet que representa este bloque.","en":"FK to the Policy or PolicySet representing this block."}','slug',true,false,3,'layers',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- ATTRIBUTE — datos
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='attribute' AND grupo_slug='datos' AND parent_id IS NULL;

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'value','{"es":"Valor","en":"Value"}','{"es":"Valor textual del atributo en el árbol.","en":"Textual value of the attribute in the tree."}','text',true,false,0,'tag',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- ENUM — datos
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='enum' AND grupo_slug='datos' AND parent_id IS NULL;

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'value','{"es":"Valor seleccionado","en":"Selected value"}','{"es":"Valor actualmente seleccionado del enumerador.","en":"Currently selected enumerator value."}','text',true,false,0,'check-square',true,'seed'),
    (v_g,'options','{"es":"Opciones válidas","en":"Valid options"}','{"es":"Conjunto de valores permitidos para este enumerador.","en":"Set of allowed values for this enumerator."}','text[]',false,true,1,'list',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- ======================================================================
-- _COMMON — Identidad (común a todos los nodos)
-- ======================================================================
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='_common' AND grupo_slug='identidad_comun' AND parent_id IS NULL;

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, readonly, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'id','{"es":"ID","en":"ID"}','{"es":"Identificador único del nodo (UUID v7).","en":"Unique node identifier (UUID v7)."}','uuid',true,false,true,0,'key',true,'seed'),
    (v_g,'tenant_id','{"es":"Tenant","en":"Tenant"}','{"es":"FK al tenant al que pertenece el nodo.","en":"FK to the tenant this node belongs to."}','uuid',true,false,true,1,'building',true,'seed'),
    (v_g,'parent_id','{"es":"Padre","en":"Parent"}','{"es":"FK al nodo padre en el árbol.","en":"FK to the parent node in the tree."}','uuid',true,true,false,2,'git-branch',true,'seed'),
    (v_g,'node_type','{"es":"Tipo de nodo","en":"Node type"}','{"es":"Tipo AtomLang del nodo: atom · rule · policy · policy_set · domain · block…","en":"AtomLang node type: atom · rule · policy · policy_set · domain · block…"}','slug',true,false,true,3,'tag',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- _COMMON — Nombre
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='_common' AND grupo_slug='nombre' AND parent_id IS NULL;

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'label','{"es":"Etiqueta","en":"Label"}','{"es":"Etiqueta corta multiidioma JSONB {es,en}.","en":"Short multilingual label JSONB {es,en}."}','jsonb',true,false,0,'tag',true,'seed'),
    (v_g,'name','{"es":"Nombre","en":"Name"}','{"es":"Nombre completo del nodo.","en":"Full name of the node."}','text',true,false,1,'type',true,'seed'),
    (v_g,'alias','{"es":"Alias","en":"Alias"}','{"es":"Alias técnico (slug).","en":"Technical alias (slug)."}','slug',true,false,2,'at-sign',true,'seed'),
    (v_g,'description','{"es":"Descripción","en":"Description"}','{"es":"Descripción extendida del nodo.","en":"Extended description of the node."}','text',true,false,3,'align-left',true,'seed'),
    (v_g,'help','{"es":"Ayuda","en":"Help"}','{"es":"Texto de ayuda contextual mostrado en el editor.","en":"Contextual help text shown in the editor."}','text',true,false,4,'help-circle',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- _COMMON — Posición
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='_common' AND grupo_slug='posicion' AND parent_id IS NULL;

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, readonly, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'depth','{"es":"Profundidad","en":"Depth"}','{"es":"Nivel de profundidad en el árbol (0 = raíz).","en":"Tree depth level (0 = root)."}','int',true,false,true,0,'layers',true,'seed'),
    (v_g,'path','{"es":"Ruta","en":"Path"}','{"es":"Ruta materializada del nodo en el árbol (ltree).","en":"Materialized path of the node in the tree (ltree)."}','text',true,false,true,1,'git-branch',true,'seed'),
    (v_g,'sort_order','{"es":"Orden","en":"Sort order"}','{"es":"Posición del nodo entre sus hermanos.","en":"Node position among its siblings."}','int',false,false,false,2,'list-ordered',true,'seed'),
    (v_g,'order_idx','{"es":"Índice de orden","en":"Order index"}','{"es":"Índice compuesto de ordenamiento (usado por el motor de árbol).","en":"Composite ordering index (used by tree engine)."}','text',true,true,false,3,'hash',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

-- _COMMON — Ciclo de vida
SELECT schema_id INTO v_g FROM bauth.pol_atomlang_node_schema
WHERE node_type='_common' AND grupo_slug='ciclo_de_vida' AND parent_id IS NULL;

INSERT INTO bauth.pol_atomlang_attr_schema
    (schema_id, attr_key, attr_label, attr_desc, attr_tipo, readonly, nullable, obligatorio, sort_order, icono, is_system, ctx_id)
VALUES
    (v_g,'is_active','{"es":"Activo","en":"Active"}','{"es":"false = nodo desactivado (no participa en la evaluación).","en":"false = deactivated node (does not participate in evaluation)."}','bool',false,false,true,0,'toggle-left',true,'seed'),
    (v_g,'version','{"es":"Versión","en":"Version"}','{"es":"Versión semántica del nodo.","en":"Semantic version of the node."}','semver',false,true,false,1,'tag',true,'seed'),
    (v_g,'valid_from','{"es":"Válido desde","en":"Valid from"}','{"es":"Fecha de inicio de vigencia del nodo.","en":"Node validity start date."}','timestamptz',false,true,false,2,'calendar',true,'seed'),
    (v_g,'valid_until','{"es":"Válido hasta","en":"Valid until"}','{"es":"Fecha de expiración del nodo. null = sin expiración.","en":"Node expiry date. null = no expiry."}','timestamptz',false,true,false,3,'calendar-x',true,'seed'),
    (v_g,'created_at','{"es":"Creado en","en":"Created at"}','{"es":"Timestamp de creación del nodo.","en":"Node creation timestamp."}','timestamptz',true,false,true,4,'clock',true,'seed'),
    (v_g,'updated_at','{"es":"Actualizado en","en":"Updated at"}','{"es":"Timestamp de última modificación del nodo.","en":"Node last modification timestamp."}','timestamptz',true,false,true,5,'refresh-cw',true,'seed')
ON CONFLICT ON CONSTRAINT uq_paas_schema_key DO NOTHING;

END $$;
