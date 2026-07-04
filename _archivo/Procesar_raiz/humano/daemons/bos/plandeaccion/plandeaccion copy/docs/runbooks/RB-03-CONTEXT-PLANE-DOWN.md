# RB-03 — Context Plane Down
## Runbook Operacional · SBOS · SKULL

**Versión:** 1.0 · Junio 2026
**Tiempo estimado de resolución:** 5–20 minutos
**SLO afectado:** C-13 — `bos.ctx.device.register` debe responder en < 2s
**Contexto:** El Context Plane (SBOS-049) es la Capa 3 del modelo de efectividad.
Si falla, las Capas 4 (VDI) y 5 (usuario final) también fallan en cascada.
Este runbook cubre tanto el escenario donde F5.x ya está implementado como
el escenario donde todavía está pendiente.

---

## Síntomas que activan este runbook

```bash
# Síntoma 1: C-13 falla en bootstrap verify
bosctl bootstrap verify --only=C-13
# → C-13 ✗

# Síntoma 2: bos.ctx.device.register tarda > 2s o falla
time bosctl rpc bos.ctx.device.register '{"tenant_id":"skull","hostname":"test"}'
# → tarda más de 2000ms, o retorna error

# Síntoma 3: VDI Layer degradado (la capa que depende del Context Plane)
bosctl rpc bos.query.vdi | jq .semaforo_vdi
# → "AMARILLO" o "ROJO"
# + campo: context_plane_vdi.bitmask_cero_count > 0

# Síntoma 4: Usuarios no pueden hacer login (sesiones no se crean)
# Los pods Fedora Lógico están Running pero el usuario ve "error al iniciar sesión"
```

---

## Diagnóstico inicial (< 3 minutos)

```bash
# PASO 1 — ¿El problema es de infraestructura o de código?
bosctl rpc bos.health.check | jq '{redis: .redis, postgresql: .postgresql}'
# Si alguno muestra healthy: false → ir a CASO A (infra) o CASO B (infra)
# Si ambos muestran healthy: true → ir a CASO C (código/config)

# PASO 2 — ¿Qué retorna el endpoint directamente?
bosctl rpc bos.ctx.device.register \
  '{"tenant_id":"skull","hostname":"diagnostico-$(date +%s)"}' 2>&1
# Caso OK: {"dctx_id":"dctx-xxx...","state":"PENDIENTE"}
# Caso error: {"error":{"code":-32000,"message":"..."}}  → ver mensaje

# PASO 3 — ¿Qué dice el audit log sobre ctx?
grep "CTX\|context" /var/log/bos/audit.log | tail -20
```

---

## Árbol de decisión

```
¿Redis DB1 responde?
├── NO → CASO A — Redis DB1 caído
│
¿PostgreSQL responde?  
├── NO → CASO B — PostgreSQL no accesible
│
¿internal/context/ implementado?
├── NO → CASO C — F5.x pendiente (Context Plane no existe en código)
│
¿Código nuevo pero sin errores de infra?
├── SÍ → CASO D — Bug en internal/context/ (registrar y escalar)
│
¿TTL expirado en todos los contextos?
└── SÍ → CASO E — Contextos expirados (operación normal — no es fallo)
```

---

## CASO A — Redis DB1 caído

Redis DB1 es el cache del Context Plane (registros de dispositivos y sesiones).
Si está caído, cada `bos.ctx.device.register` va directo a PostgreSQL → lento.

```bash
# Verificar Redis:
bosctl rpc bos.health.check | jq .redis
# o directamente:
kubectl exec -n sbos-data redis-0 -- redis-cli ping
# "PONG" = OK, timeout = caído

# Verificar Redis DB1 específicamente (el que usa el Context Plane):
kubectl exec -n sbos-data redis-0 -- redis-cli -n 1 dbsize
# debe retornar un número (count de keys del Context Plane)
```

**Reparar Redis:**
```bash
# Verificar estado de la ficha:
bosctl rpc bos.state.read | jq '.fichas["redis"].state'

# Si DEGRADADA:
bosctl rpc bos.ficha.repair '{"ficha_id":"redis"}'
# Esperar a INSTALADA (1–3 minutos)

# Si el pod está Running pero Redis DB1 vacío (pérdida de datos de cache):
# El cache se regenera automáticamente en los próximos minutos
# conforme los dispositivos se re-registren. No requiere acción manual.

# Verificar que C-05 pasa:
bosctl bootstrap verify --only=C-05
# → C-05 ✓ (redis PONG en DB0, DB1, DB2)
```

---

## CASO B — PostgreSQL no accesible

PostgreSQL es el store persistente del Context Plane (tablas `context_sessions`
y `registered_devices`).

```bash
# Verificar PostgreSQL:
kubectl exec -n sbos-data postgresql-0 -- pg_isready
# "accepting connections" = OK, timeout = caído

# Verificar que el WAL slot existe (bkernel_db):
kubectl exec -n sbos-data postgresql-0 -- \
  psql -U bosagent -d bkernel_db -c "SELECT slot_name FROM pg_replication_slots;"
# debe mostrar: bkernel_slot
```

**Reparar PostgreSQL:**
```bash
# Si DEGRADADA:
bosctl rpc bos.ficha.repair '{"ficha_id":"postgresql"}'

# PostgreSQL es C-04 y es dependencia de Keycloak, Kong, y el Context Plane.
# Reparar PostgreSQL antes que cualquier otra ficha.
bosctl bootstrap verify --only=C-04
# → C-04 ✓

# Después de PostgreSQL, verificar que el Context Plane puede reconectar:
sleep 10  # dar tiempo al daemon para detectar que postgres volvió
time bosctl rpc bos.ctx.device.register '{"tenant_id":"skull","hostname":"post-repair-test"}'
# debe responder en < 2s
```

---

## CASO C — F5.x pendiente (Context Plane no implementado en código)

Este caso aplica cuando el átomo F5.x del plan maestro **no está completo**.
El paquete `internal/context/` no existe o está vacío.

```bash
# Verificar si F5.x está implementado:
[ -f internal/context/service.go ] \
  && grep -q "RegisterDevice" internal/context/service.go \
  && echo "✅ F5.x implementado" \
  || echo "❌ F5.x pendiente"

# Si F5.x no está implementado:
bosctl rpc bos.ctx.device.register '{"tenant_id":"skull","hostname":"test"}'
# Probablemente retorna: {"error":{"code":-32601,"message":"method not found"}}
# O usa la implementación parcial del domain/types.go (solo 2 métodos: create + validate)
```

**En este caso — lo que está disponible:**
```bash
# La implementación parcial del Context Plane (30% — domain/types.go) tiene:
bosctl rpc bos.ctx.create '{"tenant_id":"skull","ctx_data":{"hostname":"test"}}'
bosctl rpc bos.ctx.validate '{"traceparent":"...","tenant_id":"skull"}'

# Estos dos métodos pueden funcionar para operaciones básicas,
# pero NO tienen: dctx_id, states, BitMask, TTL completo, Redis cache
```

**Acción requerida:** implementar F5.x según el Plan Maestro v3.0. Este
runbook no puede resolver un gap de implementación — solo puede mitigar.

**Mitigación temporal:**
```bash
# El VDI Layer puede operar con funcionalidad reducida si se desactiva
# la verificación del Context Plane:
# En bos.toml: context_plane_required = false (si existe esa opción)
# O en Guacamole: deshabilitar la verificación de dctx_id para la sesión
# ⚠️  Esto reduce la seguridad — solo en entornos de desarrollo
```

---

## CASO D — Bug en `internal/context/` (F5.x implementado pero roto)

```bash
# Ver el error específico del servidor JSON-RPC:
bosctl rpc bos.ctx.device.register '{"tenant_id":"skull","hostname":"debug"}' 2>&1
# Capturar el código y mensaje de error exacto

# Ver el log del daemon en el momento del fallo:
journalctl -u bos --since "5 minutes ago" | grep -E "ERROR|PANIC|context"

# Ejecutar los tests del Context Plane:
ssh skull@144.91.76.130
cd <repositorio>
go test -race -v ./internal/context/... 2>&1 | tail -30
# Si algún test falla → el bug está en ese test
```

**Si hay PANIC en el daemon:**
```bash
# Capturar el stack trace:
journalctl -u bos | grep -A 30 "panic:" > /tmp/panic-$(date +%Y%m%d-%H%M).txt
# Reiniciar el daemon:
sudo systemctl restart bos.service
# Registrar el panic en docs/runbooks/INCIDENTES-LOG.md
# Abrir issue con el stack trace
```

---

## CASO E — Contextos expirados (operación normal)

Los contextos tienen TTL según ISO 27001 A.9.4.2:
- `DeviceContext` (dctx_id): TTL mínimo 8 horas
- `SessionContext` (ctx_id): TTL máximo 12 horas

Si el servidor lleva más de 12 horas sin actividad de usuarios, todos los
contextos activos expiran. Esto es correcto, no es un fallo.

```bash
# Verificar el estado de los contextos (saga F6.11 — distribución completa):
bosctl rpc bos.query.context '{"tenant_id":"skull"}' | jq '{
  activos: .resumen.ctx_activos,
  total: .resumen.ctx_total,
  expirados_no_invalidados: .anomalias.ctx_expirados_no_invalidados
}'

# Si el sistema puede crear nuevos contextos:
time bosctl rpc bos.ctx.device.register '{"tenant_id":"skull","hostname":"test"}'
# → responde en < 2s → el Context Plane está sano, solo los contextos expiraron

# Los nuevos contextos se crean automáticamente cuando los usuarios lleguen.
# No requiere intervención manual.
```

---

## Verificación final

```bash
# 1. C-13 pasa:
bosctl bootstrap verify --only=C-13
# → C-13 ✓

# 2. Latencia dentro del SLO:
time bosctl rpc bos.ctx.device.register \
  '{"tenant_id":"skull","hostname":"verify-final-$(date +%s)"}'
# → responde en < 2000ms

# 3. VDI Layer se recupera:
bosctl rpc bos.query.vdi | jq .semaforo_vdi
# → "VERDE"

# 4. Sin errores en audit log:
grep "CTX.*ERROR\|context.*ERROR" /var/log/bos/audit.log | tail -5
# → vacío (no hay errores recientes)
```

---

## Referencia rápida de comandos

```bash
# Diagnóstico rápido:
time bosctl rpc bos.ctx.device.register '{"tenant_id":"skull","hostname":"test"}'

# Verificar infraestructura:
bosctl rpc bos.health.check | jq '{redis: .redis, postgresql: .postgresql}'

# Verificar C-13:
bosctl bootstrap verify --only=C-13

# SLO del Context Plane — verificar que device.register responde < 2s (C-13):
time bosctl rpc bos.ctx.device.register '{"tenant_id":"skull","hostname":"slo-check"}'
# (la métrica p99 histórica llegará con Prometheus en F9.7;
#  mientras tanto bos.query.context muestra anomalías y TTLs)

# Si F5.x implementado — listar contextos activos:
bosctl ctx list --tenant=skull | head -10

# Reparar dependencias:
bosctl rpc bos.ficha.repair '{"ficha_id":"redis"}'      # cache
bosctl rpc bos.ficha.repair '{"ficha_id":"postgresql"}' # store
```

---

## Cadena de dependencias del Context Plane

```
PostgreSQL (C-04) ──────┐
                         ├── internal/context/store.go ── bos.ctx.device.register
Redis DB1 (C-05) ───────┘         │
                                    └── dctx_id → ctx_id → VDI Layer (C-09..C-14)
                                                             │
                                              Fedora Lógico ← Usuario final
```

Si PostgreSQL o Redis fallan → Context Plane falla → VDI falla → usuario no
puede trabajar. El orden de reparación es siempre de abajo hacia arriba.

---

*RB-03 v1.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
*Fuente primaria: BOS-REPAIR-08 (Context Plane SBOS-049), BOS-REPAIR-01 C-13*
*Solución permanente: Plan Maestro v3.0 → Fase 5 (F5.1..F5.6)*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
