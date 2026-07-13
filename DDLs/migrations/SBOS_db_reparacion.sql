-- ============================================================
-- SBOS_db_reparacion.sql
-- Tablas PROPUESTAS para bauth — gap AtomLang / árbol SOURCE
--
-- Estado: PROPUESTA — requiere revisión y aprobación HITL
--         antes de ejecutar en SBOS_db.
-- Propósito: registrar las 5 tablas que el árbol SOURCE referencia
--            como *(propuesta)* y que aún no existen en el DDL principal.
-- Orden de ejecución: después de sbos_00__esquema_base.sql
-- Autor: bauth-developer · 2026-07-13
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- R-01  CATÁLOGO DE RECURSOS
--       Target.Resource del átomo AtomLang.
--       Equivale a Salesforce Object Permissions / SAP Authorization Object.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bauth.privilege_resource (
    resource_id     UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id       UUID         NOT NULL,
    app_code        SMALLINT     NOT NULL,
    resource_slug   VARCHAR(128) NOT NULL,
    resource_name   VARCHAR(256) NOT NULL,
    resource_type   VARCHAR(64)  NOT NULL,
    description     TEXT,
    active          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_privilege_resource  PRIMARY KEY (resource_id),
    CONSTRAINT uq_privilege_resource  UNIQUE (tenant_id, resource_slug),
    CONSTRAINT fk_resource_app        FOREIGN KEY (app_code)
        REFERENCES bauth.privilege_application (app_code),
    CONSTRAINT ck_resource_type       CHECK (resource_type IN (
        'model', 'endpoint', 'report', 'file', 'queue', 'socket', 'widget', 'other'
    ))
);
COMMENT ON TABLE  bauth.privilege_resource IS
    'Catálogo de recursos registrados como Target.Resource en átomos AtomLang. '
    'Cada recurso pertenece a una aplicación (app_code) y un tenant. '
    'resource_type clasifica el objeto: modelo ORM, endpoint REST/RPC, '
    'reporte, archivo, cola, socket Unix, widget de UI u otro.';
COMMENT ON COLUMN bauth.privilege_resource.resource_slug IS
    'Identificador canónico usado en el SOURCE del átomo, ej. "sale.order", '
    '"hr.employee", "bnotify.template". Debe ser único por tenant.';
COMMENT ON COLUMN bauth.privilege_resource.resource_type IS
    'Tipo de objeto: model=ORM/tabla, endpoint=JSON-RPC/REST, '
    'report=informe, file=archivo/blob, queue=cola de mensajes, '
    'socket=Unix socket, widget=componente UI, other=otro.';

CREATE INDEX IF NOT EXISTS ix_privilege_resource_app
    ON bauth.privilege_resource (app_code, active) WHERE active = TRUE;

-- ────────────────────────────────────────────────────────────
-- R-02  CATÁLOGO DE ATRIBUTOS
--       Condition.propiedad del átomo AtomLang.
--       Catálogo global (sin tenant) — como privilege_verb.
--       Equivale a SAP Authorization Field / XACML AttributeDesignator.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bauth.privilege_attribute (
    attribute_id    UUID         NOT NULL DEFAULT gen_random_uuid(),
    attribute_slug  VARCHAR(128) NOT NULL,
    attribute_name  VARCHAR(256) NOT NULL,
    data_type       VARCHAR(32)  NOT NULL,
    source          VARCHAR(32)  NOT NULL,
    description     TEXT,
    active          BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_privilege_attribute PRIMARY KEY (attribute_id),
    CONSTRAINT uq_privilege_attribute  UNIQUE (attribute_slug),
    CONSTRAINT ck_attribute_data_type  CHECK (data_type IN (
        'string', 'integer', 'decimal', 'boolean', 'uuid',
        'timestamptz', 'inet', 'jsonb', 'array'
    )),
    CONSTRAINT ck_attribute_source CHECK (source IN (
        'ctx', 'subject', 'resource', 'environment', 'action'
    ))
);
COMMENT ON TABLE  bauth.privilege_attribute IS
    'Catálogo global de atributos para condiciones de átomos AtomLang. '
    'Equivale al AttributeDesignator de XACML 3.0. '
    'Sin tenant_id — compartido por todas las aplicaciones del ecosistema.';
COMMENT ON COLUMN bauth.privilege_attribute.attribute_slug IS
    'Ruta canónica del atributo usada en Condition.propiedad del SOURCE, '
    'ej. "ctx.risk_score", "subject.department", "resource.classification", '
    '"environment.time_utc", "action.amount_bob".';
COMMENT ON COLUMN bauth.privilege_attribute.source IS
    'Origen del valor en tiempo de evaluación: '
    'ctx=Context Plane (ctx_id), subject=identidad del sujeto, '
    'resource=objeto accedido, environment=entorno (hora, red), '
    'action=parámetros de la acción (monto, cantidad).';

-- ────────────────────────────────────────────────────────────
-- R-03  CONJUNTOS DE ROLES  (D98 · Registro Estructural)
--       Target.Subject SET del átomo AtomLang.
--       Equivale a AWS IAM Group / Okta Group / AD Security Group.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bauth.privilege_role_set (
    set_id          UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id       UUID         NOT NULL,
    set_slug        VARCHAR(64)  NOT NULL,
    set_name        VARCHAR(128) NOT NULL,
    set_description TEXT,
    active          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_privilege_role_set PRIMARY KEY (set_id),
    CONSTRAINT uq_privilege_role_set  UNIQUE (tenant_id, set_slug)
);
COMMENT ON TABLE  bauth.privilege_role_set IS
    'Conjuntos lógicos de roles usados como Target.Subject SET en átomos AtomLang. '
    'D98 · Registro Estructural — no produce Decision ni entra al BitMask funcional. '
    'Equivale a AWS IAM Group / Okta Group. '
    'Un conjunto puede contener N roles; un rol puede pertenecer a N conjuntos.';
COMMENT ON COLUMN bauth.privilege_role_set.set_slug IS
    'Identificador canónico del conjunto, ej. "tier_descuento_alto", '
    '"aprobadores_financieros", "auditores_externos". Único por tenant.';

CREATE INDEX IF NOT EXISTS ix_privilege_role_set_tenant
    ON bauth.privilege_role_set (tenant_id, active) WHERE active = TRUE;

-- ────────────────────────────────────────────────────────────
-- R-04  MIEMBROS DE CONJUNTO DE ROLES
--       Relación N:M entre privilege_role_set y privilege_role.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bauth.privilege_role_set_member (
    set_id      UUID        NOT NULL,
    role_id     UUID        NOT NULL,
    added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    added_by    UUID,
    CONSTRAINT pk_privilege_role_set_member PRIMARY KEY (set_id, role_id),
    CONSTRAINT fk_set_member_set  FOREIGN KEY (set_id)
        REFERENCES bauth.privilege_role_set (set_id) ON DELETE CASCADE,
    CONSTRAINT fk_set_member_role FOREIGN KEY (role_id)
        REFERENCES bauth.privilege_role (role_id) ON DELETE CASCADE
);
COMMENT ON TABLE  bauth.privilege_role_set_member IS
    'Membresía N:M entre conjuntos y roles. '
    'Un rol en un conjunto hereda los átomos cuyo Target.Subject SET '
    'referencia ese conjunto.';
COMMENT ON COLUMN bauth.privilege_role_set_member.added_by IS
    'UUID del administrador que añadió el rol al conjunto. '
    'NULL si fue seed/migración automática.';

CREATE INDEX IF NOT EXISTS ix_role_set_member_role
    ON bauth.privilege_role_set_member (role_id);

-- ────────────────────────────────────────────────────────────
-- R-05  IR COMPILADO DE ÁTOMOS  (salida de atomc)
--       El PDP lee SOLO esta tabla — nunca el SOURCE.
--       Equivale al OPA bundle / Cedar policy store compilado.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bauth.privilege_atom_compiled (
    compiled_id         UUID        NOT NULL DEFAULT gen_random_uuid(),
    app_code            SMALLINT    NOT NULL,
    group_code          SMALLINT    NOT NULL,
    atom_code           INTEGER     NOT NULL,
    policy_slug         VARCHAR(64) NOT NULL,
    source_hash         CHAR(64)    NOT NULL,
    ir_version          INTEGER     NOT NULL DEFAULT 1,
    combining_algorithm VARCHAR(32) NOT NULL DEFAULT 'deny-overrides',
    ir_data             JSONB       NOT NULL,
    active              BOOLEAN     NOT NULL DEFAULT TRUE,
    compiled_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    compiled_by         VARCHAR(128) NOT NULL,
    CONSTRAINT pk_privilege_atom_compiled PRIMARY KEY (compiled_id),
    CONSTRAINT uq_atom_compiled_slug      UNIQUE (app_code, group_code, atom_code, policy_slug),
    CONSTRAINT fk_compiled_atom           FOREIGN KEY (app_code, group_code, atom_code)
        REFERENCES bauth.privilege_atom (app_code, group_code, atom_code),
    CONSTRAINT ck_compiled_algorithm      CHECK (combining_algorithm IN (
        'deny-overrides', 'permit-overrides', 'first-applicable',
        'only-one-applicable', 'aggregate-strictest'
    )),
    CONSTRAINT ck_compiled_ir_schema      CHECK (
        ir_data ? '$schema'
        AND ir_data ? 'effect'
        AND ir_data ? 'target'
        AND ir_data ? 'conditions'
        AND (ir_data ->> 'effect') IN ('PERMIT', 'DENY')
    )
);
COMMENT ON TABLE  bauth.privilege_atom_compiled IS
    'IR canónico producido por el compilador atomc a partir del árbol SOURCE. '
    'El PDP (PolicyDecisionPoint) de bAuth lee EXCLUSIVAMENTE esta tabla — '
    'nunca el árbol SOURCE. Una fila = un átomo compilado con su política. '
    'source_hash (SHA-256) permite detectar si el SOURCE cambió sin recompilar. '
    'Equivale al OPA bundle compilado / Cedar policy store.';
COMMENT ON COLUMN bauth.privilege_atom_compiled.source_hash IS
    'SHA-256 del documento SOURCE que produjo este IR. '
    'Si el SOURCE cambia, este hash difiere → recompilación obligatoria.';
COMMENT ON COLUMN bauth.privilege_atom_compiled.combining_algorithm IS
    'Algoritmo de combinación XACML 3.0 aplicado a las reglas del átomo. '
    'deny-overrides: un DENY gana siempre (SoD, límites financieros). '
    'permit-overrides: un PERMIT gana (whitelist). '
    'aggregate-strictest: el nivel más restrictivo gana (step-up).';
COMMENT ON COLUMN bauth.privilege_atom_compiled.ir_data IS
    'Representación IR completa del átomo en JSONB. '
    'Estructura mínima: {"$schema":"atomc_ir_v1","effect":"PERMIT|DENY",'
    '"target":{...},"conditions":[...]}. '
    'El PDP evalúa este documento sin interpretar el SOURCE.';
COMMENT ON COLUMN bauth.privilege_atom_compiled.compiled_by IS
    'Identificador del proceso atomc que compiló: '
    '"atomc/1.0.0 ctx_id=<uuid>" — trazabilidad de compilación.';

CREATE INDEX IF NOT EXISTS ix_atom_compiled_active
    ON bauth.privilege_atom_compiled (app_code, group_code, atom_code, active)
    WHERE active = TRUE;
CREATE INDEX IF NOT EXISTS ix_atom_compiled_ir
    ON bauth.privilege_atom_compiled USING GIN (ir_data jsonb_path_ops);
