-- =============================================================================
-- T-430 — bos.net_web_domain
-- Aplicar en SBOSDB con:
--   psql -U postgres -h localhost -p 5432 SBOSDB -f bos_T430__net_web_domain.sql
-- Precondición: función uuidv7() y schema bos ya existen (T-395..T-414 aplicados).
-- =============================================================================

CREATE TABLE IF NOT EXISTS bos.net_web_domain (
    domain_id       UUID        NOT NULL DEFAULT uuidv7(),
    domain          TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT,
    sucursal_id     TEXT,
    is_active       BOOLEAN     NOT NULL DEFAULT true,
    ssl_provisioned BOOLEAN     NOT NULL DEFAULT false,
    ssl_expires_at  TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ctx_id          TEXT        NOT NULL,

    CONSTRAINT net_wd_pkey    PRIMARY KEY (domain_id),
    CONSTRAINT uq_net_wd_dom  UNIQUE (domain),
    CONSTRAINT chk_net_wd_len CHECK (length(domain) BETWEEN 4 AND 253),
    CONSTRAINT chk_net_wd_fmt CHECK (domain ~ '^[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?(\.[a-z]{2,})+$')
);

CREATE INDEX IF NOT EXISTS idx_net_wd_tenant  ON bos.net_web_domain (tenant_id);
CREATE INDEX IF NOT EXISTS idx_net_wd_active  ON bos.net_web_domain (is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_net_wd_ssl_exp ON bos.net_web_domain (ssl_expires_at)
    WHERE ssl_provisioned = true;

COMMENT ON TABLE bos.net_web_domain IS
  '[T-430] [BC-06] [S16-webserver] [manual 5.01 §6] [ADR-020]
   Registro de dominios web multi-tenant. Gestionado por bos.web.domain.* (5 métodos).
   nginx reverse proxy + certbot SSL. Un registro por dominio activo.
   Soft-delete via is_active=false. ssl_provisioned=true cuando certbot emitió cert.';

-- Verificar
SELECT schemaname, tablename, tableowner
FROM pg_tables
WHERE schemaname = 'bos' AND tablename = 'net_web_domain';
