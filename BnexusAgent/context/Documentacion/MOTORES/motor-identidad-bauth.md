# Motor 2 — Identidad bAuth (Resolver-Identidad)
## Puerta 2: comunicación bidireccional bhnexus ↔ bAuth

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Motor en MOTORES-INDEX:** `M-02`  
**Respalda:** `2.02_MANUAL-PUERTA-2-BAUTH.md` + `5.01_MANUAL-AUTH-CACHE-BHNEXUS.md` + `6.01_MANUAL-FLUJO-POLITICA.md`

---

## Responsabilidad del motor

El Motor de Identidad bAuth gestiona **toda la comunicación entre bhnexus y bAuth**. Es la Puerta 2 del sistema, con dos sub-canales distintos.

**Verbo central:** `Resolver-Identidad` — obtiene el SAM-128 para cada credencial presentada.

## Qué hace

### Sub-canal A (consultas de bitmask)
1. **Recibe** `auth_request` del Motor de Hardware (credencial normalizada)
2. **Consulta** el Auth Cache en memoria — O(1) lookup
3. **Si cache hit**: retorna SAM-128 inmediatamente (~0.8ms total)
4. **Si cache miss**: envía `bitmask_request` a bAuth via Unix socket TLV `/run/bos/bauth.sock`
5. **Almacena** la respuesta en el Auth Cache (TTL 30s)
6. **Retorna** SAM-128 + actuator_commands al Motor de Actuación

### Sub-canal B (canal privilegiado bidireccional)
- **bAuth → bhnexus**: `emergency_revoke`, `invalidate_cache`, `security_level_up`, `blacklist_node`, `policy_sync`
- **bhnexus → bAuth**: `device_tamper`, `node_offline`, `auth_spike`, `hardware_failure`, `integrity_breach`

## Lo que NO hace

- No evalúa el bitmask (eso es bAuth)
- No decide si la acción está permitida (eso es bAuth)
- No almacena identidades de usuario (eso es SBOSDB vía bAuth)

## Parámetros de operación

| Parámetro | Valor |
|-----------|-------|
| Socket sub-canal A | `/run/bos/bauth.sock` |
| Socket sub-canal B | `/run/bos/bauth-nexus.sock` (bhnexus lo crea) |
| Frame | TLV: `[4B longitud][N bytes JSON UTF-8]` |
| Timeout sub-canal A | 1000ms |
| Max conexiones pool | 100 (sub-canal A) |
| Cache TTL | 30s |
| Cache capacidad | 10,000 entradas LRU |
| Latencia cache hit | < 1ms |
| Latencia cache miss | < 15ms end-to-end |

## Invariantes de seguridad

1. Solo bAuth puede emitir actuator_commands — nunca bhnexus directamente
2. Si bAuth no responde → DENY (fail-secure), nunca GRANT
3. Cache máximo 30s — no hay autorización permanente en bhnexus
4. El sub-canal B tiene rate limiting: 100 mensajes/segundo

---

*SKULL · SBOS · bNexus · MOTORES/motor-identidad-bauth · v1.0.0 · Agosto 2026*
