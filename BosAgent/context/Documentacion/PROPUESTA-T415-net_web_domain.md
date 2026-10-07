# PROPUESTA DDL — T-415: `bos.net_web_domain`

**Estado:** PENDIENTE DE APROBACIÓN HITL  
**Autor:** bos-developer  
**Fecha:** 2026-10-07  
**BC:** BC-06 Domain Manager S16-webserver  
**Esquema destino:** `bos` (Context Plane — T-395..T-402 ya existen)

---

## Propósito

Persistir los registros de dominios web gestionados por `WebDomainService` (BC-06) en
PostgreSQL. Actualmente el servicio usa `MemWebDomain` (en memoria) como implementación
de `WebDomainPort`. Esta tabla permite recuperar el estado tras reinicio del daemon y
auditarlo desde la BD.

---

## DDL propuesto

```sql
-- T-415: dominios web registrados en S16-webserver
-- Esquema: bos (Context Plane — SBOS-049)
CREATE TABLE IF NOT EXISTS bos.net_web_domain (
    id          BIGSERIAL PRIMARY KEY,

    domain      TEXT        NOT NULL UNIQUE,       -- hostname RFC 1123 (ej: api.empresa.com)
    target      TEXT        NOT NULL,              -- IP o host:puerto de destino
    ssl_auto    BOOLEAN     NOT NULL DEFAULT FALSE, -- provisionar SSL con certbot automáticamente

    ctx_id      TEXT        NOT NULL DEFAULT '',   -- ctx_id de la operación que creó el registro (SBOS-049)
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice para búsqueda directa por dominio
CREATE UNIQUE INDEX IF NOT EXISTS idx_net_web_domain_domain
    ON bos.net_web_domain (domain);

-- Trigger updated_at automático
CREATE OR REPLACE TRIGGER trg_net_web_domain_updated_at
    BEFORE UPDATE ON bos.net_web_domain
    FOR EACH ROW EXECUTE FUNCTION bos.set_updated_at();

COMMENT ON TABLE  bos.net_web_domain        IS 'T-415: Dominios web gestionados por BOS Domain Manager (S16-webserver, BC-06)';
COMMENT ON COLUMN bos.net_web_domain.domain  IS 'Hostname RFC 1123 del dominio web registrado';
COMMENT ON COLUMN bos.net_web_domain.target  IS 'IP o host:puerto de destino del reverse proxy nginx';
COMMENT ON COLUMN bos.net_web_domain.ssl_auto IS 'Si true, BOS provisiona automáticamente certificado Let\'s Encrypt vía certbot';
COMMENT ON COLUMN bos.net_web_domain.ctx_id  IS 'ctx_id de la operación que creó o modificó el registro (SBOS-049 trazabilidad)';
```

---

## Dependencias

| Requisito | Estado |
|-----------|--------|
| Función `bos.set_updated_at()` | Debe existir — ya creada en T-395 (Context Plane, sesión 2026-07-31) |
| Esquema `bos` | Ya existe (T-395..T-402, commit `b3f95bc`) |

---

## Implementación pendiente post-aprobación

Una vez aprobada la tabla, se debe implementar `PgWebDomain` en
`internal/domain/webdomain_infra.go`:

```go
// PgWebDomain implementa WebDomainPort sobre PostgreSQL (T-415).
type PgWebDomain struct {
    db *pgxpool.Pool
}
```

E inyectarla en `cmd/bos/run_normal.go`:

```go
if pool != nil {
    srv.SetWebDomainService(domain.NewWebDomainService(
        domain.NewPgWebDomain(pool),
        domain.NewNginxManager(""),
    ))
}
```

---

## Decisión HITL requerida

> **¿Se aprueba la creación de la tabla `bos.net_web_domain` en SBOSDB?**

- [ ] Aprobado — aplicar DDL en SBOSDB
- [ ] Rechazado — continuar con MemWebDomain indefinidamente
- [ ] Modificar — ajustar esquema antes de aplicar

**Nota:** Hasta la aprobación, `WebDomainService` funciona completamente con
`MemWebDomain` + `NoopNginx` en modo dev y con `MemWebDomain` + `NginxManager` en
producción (sin persistencia en BD entre reinicios).
