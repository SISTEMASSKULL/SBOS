# Motor 4 — Cache (Cachear-SAM128)
## Auth Cache en bhnexus + Policy Cache en banexus

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Motor en MOTORES-INDEX:** `M-04`  
**Respalda:** `5.01_MANUAL-AUTH-CACHE-BHNEXUS.md` + `5.02_MANUAL-POLICY-CACHE-BANEXUS.md` + `5.03_MANUAL-OFFLINE-FAILSECURE.md`

---

## Responsabilidad del motor

El Motor de Cache gestiona **dos capas de cache independientes** que permiten a bNexus operar con baja latencia y soportar fallos de conectividad.

**Verbo central:** `Cachear` — almacena SAM-128 y policies para acceso O(1) y resiliencia offline.

## Las dos capas de cache

### Capa 1 — Auth Cache (bhnexus, en memoria)

- **Qué almacena**: `HashMap<(user_id, node_id), CacheEntry { sam128, actuator_commands, ttl, roltemplate_hash }>`
- **Tipo**: volátil (en RAM, no persiste al reiniciar)
- **TTL**: 30 segundos (configurable, máximo fijo)
- **Capacidad**: 10,000 entradas LRU (~15MB RAM)
- **Lookup**: O(1) por `(user_id, node_id)`
- **Invalidación**: 4 mecanismos:
  1. `emergency_revoke` por sub-canal B (inmediato)
  2. `policy_sync` por sub-canal B (selectivo por usuario o global)
  3. TTL lazy expiry (al siguiente lookup)
  4. `roltemplate_hash` cambia (detectado en el siguiente lookup)

### Capa 2 — Policy Cache (banexus, en disco cifrado)

- **Qué almacena**: snapshot completo de SAM-128 para todos los usuarios del nodo
- **Tipo**: persistente en disco, cifrado con AES-256-GCM
- **Clave**: HKDF-SHA256(private_key_mTLS, node_id, "banexus-policy-cache-v1") → 32 bytes
- **TTL**: 4 horas (configurable)
- **Archivo**: `/var/lib/banexus/policy_cache.enc`
- **Uso**: solo cuando bhnexus es inaccesible (modo offline)

## Lo que NO hace

- No modifica el SAM-128 — lo almacena tal como lo entregó bAuth
- No extiende el TTL — el TTL se fija en el momento de la consulta a bAuth
- No hace fail-open — si el cache expira offline → DENY siempre

## Comportamiento en fallos (cadena de resiliencia)

```
Fallo 1: banexus pierde conexión con bhnexus
  → banexus usa Policy Cache (Capa 2) — hasta 4h
  → Si Policy Cache expira → DENY todo (fail-secure)

Fallo 2: bhnexus pierde conexión con bAuth
  → bhnexus usa Auth Cache (Capa 1) — hasta 30s por entrada
  → Cache miss → DENY (bAuth no disponible)

Fallo 3: bAuth pierde conexión con SBOSDB
  → bAuth retorna error → bhnexus DENY (fail-secure)
```

---

*SKULL · SBOS · bNexus · MOTORES/motor-cache · v1.0.0 · Agosto 2026*
