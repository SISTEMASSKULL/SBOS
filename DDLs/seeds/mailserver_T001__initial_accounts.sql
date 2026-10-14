-- =============================================================================
-- mailserver_T001__initial_accounts.sql
-- Schema PostfixAdmin en mailserver_db + cuenta postmaster inicial.
-- Ejecutado por sbos-database-init en la base de datos mailserver_db.
-- Idempotente: IF NOT EXISTS + ON CONFLICT DO NOTHING.
-- =============================================================================

-- Extensión necesaria para hashes de contraseña
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Tabla: dominio virtual ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS domain (
    domain          VARCHAR(255) NOT NULL,
    description     VARCHAR(255) NOT NULL DEFAULT '',
    aliases         INT          NOT NULL DEFAULT 0,
    mailboxes       INT          NOT NULL DEFAULT 0,
    maxquota        BIGINT       NOT NULL DEFAULT 0,
    quota           BIGINT       NOT NULL DEFAULT 0,
    transport       VARCHAR(255) NOT NULL DEFAULT 'virtual',
    backupmx        BOOLEAN      NOT NULL DEFAULT FALSE,
    created         TIMESTAMP    NOT NULL DEFAULT NOW(),
    modified        TIMESTAMP    NOT NULL DEFAULT NOW(),
    active          BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_domain PRIMARY KEY (domain)
);

-- ── Tabla: buzones virtuales ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mailbox (
    username        VARCHAR(255) NOT NULL,
    password        VARCHAR(255) NOT NULL,
    name            VARCHAR(255) NOT NULL DEFAULT '',
    maildir         VARCHAR(255) NOT NULL,
    quota           BIGINT       NOT NULL DEFAULT 0,
    local_part      VARCHAR(255) NOT NULL,
    domain          VARCHAR(255) NOT NULL,
    created         TIMESTAMP    NOT NULL DEFAULT NOW(),
    modified        TIMESTAMP    NOT NULL DEFAULT NOW(),
    active          BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_mailbox PRIMARY KEY (username),
    CONSTRAINT fk_mailbox_domain FOREIGN KEY (domain) REFERENCES domain (domain)
);

-- ── Tabla: alias de correo ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS alias (
    address         VARCHAR(255) NOT NULL,
    goto            TEXT         NOT NULL,
    domain          VARCHAR(255) NOT NULL,
    created         TIMESTAMP    NOT NULL DEFAULT NOW(),
    modified        TIMESTAMP    NOT NULL DEFAULT NOW(),
    active          BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_alias PRIMARY KEY (address),
    CONSTRAINT fk_alias_domain FOREIGN KEY (domain) REFERENCES domain (domain)
);

-- ── Tabla: administradores globales ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS admin (
    username        VARCHAR(255) NOT NULL,
    password        VARCHAR(255) NOT NULL,
    created         TIMESTAMP    NOT NULL DEFAULT NOW(),
    modified        TIMESTAMP    NOT NULL DEFAULT NOW(),
    active          BOOLEAN      NOT NULL DEFAULT TRUE,
    superadmin      BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_admin PRIMARY KEY (username)
);

-- ── Tabla: admins por dominio ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS domain_admins (
    username        VARCHAR(255) NOT NULL,
    domain          VARCHAR(255) NOT NULL,
    created         TIMESTAMP    NOT NULL DEFAULT NOW(),
    active          BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_domain_admins PRIMARY KEY (username, domain)
);

-- ── Tabla: log de auditoría ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS log (
    timestamp       TIMESTAMP    NOT NULL DEFAULT NOW(),
    username        VARCHAR(255) NOT NULL DEFAULT '',
    domain          VARCHAR(255) NOT NULL DEFAULT '',
    action          VARCHAR(255) NOT NULL DEFAULT '',
    data            TEXT         NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_log_timestamp ON log (timestamp);

-- ── Tabla: cuotas (Dovecot quota2) ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS quota2 (
    username        VARCHAR(100) NOT NULL,
    component       VARCHAR(16)  NOT NULL,
    bytes           BIGINT       NOT NULL DEFAULT 0,
    messages        INTEGER      NOT NULL DEFAULT 0,
    CONSTRAINT pk_quota2 PRIMARY KEY (username, component)
);

-- =============================================================================
-- SEEDS: dominio y cuenta postmaster inicial
-- El dominio `mail.sbos.local` es el dominio de correo interno por defecto.
-- La contraseña se cambia en el wizard de configuración del tenant (HITL).
-- Formato: {BCRYPT}hash — compatible con Dovecot + PostfixAdmin.
-- =============================================================================

-- Dominio interno por defecto
INSERT INTO domain (domain, description, transport, active)
VALUES ('mail.sbos.local', 'Dominio de correo interno SBOS', 'virtual', TRUE)
ON CONFLICT (domain) DO NOTHING;

-- Cuenta postmaster (contraseña inicial: 'changeme_postmaster' — CAMBIAR EN PRODUCCIÓN)
-- Hash generado con: echo "changeme_postmaster" | openssl passwd -6 -stdin
INSERT INTO admin (username, password, superadmin, active)
VALUES (
    'postmaster@mail.sbos.local',
    crypt('changeme_postmaster', gen_salt('bf', 10)),
    TRUE,
    TRUE
)
ON CONFLICT (username) DO NOTHING;

INSERT INTO domain_admins (username, domain, active)
VALUES ('postmaster@mail.sbos.local', 'mail.sbos.local', TRUE)
ON CONFLICT (username, domain) DO NOTHING;

INSERT INTO mailbox (username, password, name, maildir, local_part, domain, active)
VALUES (
    'postmaster@mail.sbos.local',
    crypt('changeme_postmaster', gen_salt('bf', 10)),
    'Postmaster SBOS',
    'mail.sbos.local/postmaster/',
    'postmaster',
    'mail.sbos.local',
    TRUE
)
ON CONFLICT (username) DO NOTHING;

INSERT INTO alias (address, goto, domain, active)
VALUES (
    'postmaster@mail.sbos.local',
    'postmaster@mail.sbos.local',
    'mail.sbos.local',
    TRUE
)
ON CONFLICT (address) DO NOTHING;
