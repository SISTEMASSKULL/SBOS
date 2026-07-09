# BAUTH-REDIS-CACHE-SCHEMA.md — Esquema de Cache Redis de bAuth
## B47.E03 · G7 del Manual v18.0 · 2026-06-29

**Propósito:** Documentar la estructura completa del cache Redis usado por bAuth.
Redis es cache volátil — PostgreSQL es fuente de verdad.

---

## Distribución por Database (6 DBs)

| DB | Propósito | TTL | Tamaño estimado |
|----|-----------|-----|----------------|
| **DB0** | ctx_id sessions | 8h | ~100 KB por 1000 sesiones |
| **DB1** | RolBitMask cache | 30s | ~50 KB por 100 roles |
| **DB2** | PolicyEngine cache | 5min | ~200 KB |
| **DB3** | Permission cache | 30s | ~100 KB por 1000 permisos |
| **DB4** | Rate limit counters | 1min | ~10 KB |
| **DB5** | OAuth2-Proxy sessions | 8h | ~50 KB por 100 sesiones |

### DB0 — Sesiones ctx_id

```
Key:   ctx:{ctx_id}
Value: JSON {
  "user_uuid": "uuid",
  "rol_bitmask": "base64",
  "atom_bitmask": "hex",
  "domain_results": {...},
  "tenant_id": "uuid",
  "empresa_id": "uuid",
  "sucursal_id": "uuid",
  "pos_logico": "uuid",
  "loa": 2,
  "device_trust": 85,
  "created_at": "ISO8601",
  "expires_at": "ISO8601"
}
TTL: 8h (28800s)
Invalidación: bauth.ctx.invalidate, logout, timeout
```

### DB1 — RolBitMask Cache

```
Key:   role:{role_code}
Value: base64(rol_bitmask_64bit)
TTL: 30s
Invalidación: al modificar rol_template (UPDATE trigger)
```

### DB2 — PolicyEngine Cache

```
Key:   policy:{domain}:{atom_slug}
Value: JSON { "result": "ALLOW|DENY|STEP_UP", "policies": [...], "trace": [...] }
TTL: 5min (300s)
Invalidación: al modificar ath_policy_d*, reload framework
```

### DB3 — Permission Cache

```
Key:   perm:{user_uuid}:{atom_slug}
Value: "ALLOW" | "DENY" | "STEP_UP"
TTL: 30s
Invalidación: cambio de rol, cambio de políticas, expiración natural
```

### DB4 — Rate Limit Counters

```
Key:   rl:{user_uuid}:{window}
Value: count (integer)
TTL: 1min (60s)
Invalidación: solo expiración
```

### DB5 — OAuth2-Proxy Sessions

```
Key:   oauth2:{session_id}
Value: JSON { "user_uuid": "...", "access_token": "...", "id_token": "...", "exp": 1234567890 }
TTL: 8h
Invalidación: logout, token refresh
```

---

## Políticas de Invalidación

1. **Toda invalidación es vía TTL natural** — Redis no tiene triggers desde PostgreSQL.
2. **DB1 (RolBitMask) se refresca cada 30s** — el reconcile loop re-evalúa contextos si detecta drift.
3. **En caso de inconsistencia, PostgreSQL gana** — Redis es solo acelerador.
4. **Flush seguro:** `FLUSHDB` por database individual, nunca `FLUSHALL`.

---

## Monitoreo

- `redis-cli INFO keyspace` — ver hits/misses por DB
- `redis-cli DBSIZE` — número de keys por DB
- Alertas: memory > 80%, hit rate < 90%

*BAUTH-REDIS-CACHE-SCHEMA.md v1.0 · 2026-06-29*
