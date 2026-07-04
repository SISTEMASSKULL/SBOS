# SBOS-010-WAL — Estrategia de Replay WAL, Idempotencia y Recovery del bKernel
## Sección para insertar en SBOS-010 (bKernel)

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-010-WAL (sección nueva de SBOS-010)
**Versión:** 1.0
**Estado:** ACTIVO
**Clasificación:** Especificación Técnica — Garantías de Delivery del bKernel
**Complementa:** SBOS-010-BKERNEL-v7_0.md (insertar como §28 — Estrategia de Replay WAL)
**Insertar en:** SBOS-010 como nueva sección §28

---

## §18 — Estrategia de Replay WAL, Idempotencia y Recovery del bKernel

### 18.1 Modelo de delivery: at-least-once con idempotencia garantizada

El bKernel opera bajo el modelo **at-least-once delivery**:

- **At-least-once:** ante un crash del bKernel entre el procesamiento de un batch y el checkpoint del LSN, ese batch puede procesarse dos veces al reiniciar. El sistema garantiza que no se pierden eventos, a costa de la posibilidad de procesar el mismo evento más de una vez.

- **Idempotencia garantizada:** el Writer Pool verifica la tabla `bkernel_db.processed_events` antes de cada escritura. Si el `event_id` ya existe en la tabla, la escritura se omite silenciosamente. Esto convierte el modelo at-least-once en exactly-once desde la perspectiva del estado resultante.

```
GARANTÍA FORMAL:
  Para todo evento E con event_id único:
  COUNT(E en destino) = 1
  — independientemente de cuántas veces el bKernel lo haya procesado
```

### 18.2 Mecanismo de checkpoint del LSN

El bKernel persiste el último LSN procesado en `bkernel_db.checkpoint` después de cada batch confirmado:

```sql
-- Esquema de la tabla de checkpoint
CREATE TABLE bkernel_db.checkpoint (
    id          SERIAL PRIMARY KEY,
    lsn         pg_lsn NOT NULL,           -- "0/1A2B3C4D" — posición en el WAL
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    batch_size  INTEGER,                   -- Cuántos eventos tenía el último batch
    hostname    TEXT                       -- Host donde corre el bKernel
);
```

**Ciclo de vida del LSN:**

```
INICIO bKernel:
  1. Leer el LSN de bkernel_db.checkpoint (SELECT lsn ORDER BY updated_at DESC LIMIT 1)
  2. Si no hay registro: arrancar desde LSN actual del slot (nuevo deployment)
  3. Si hay registro: arrancar desde ese LSN (recovery de crash o reinicio normal)

PROCESAMIENTO (ciclo normal):
  1. Leer el WAL desde el LSN checkpointado
  2. Procesar batch de hasta 1000 eventos
  3. Aplicar Rule Engine
  4. Ejecutar Writer Pool (con verificación de idempotencia)
  5. CHECKPOINT: UPDATE bkernel_db.checkpoint SET lsn = $nuevo_lsn

DETENCIÓN (SIGTERM limpio):
  1. Terminar el batch en vuelo
  2. CHECKPOINT del LSN final
  3. Cerrar la conexión al slot de replicación
  4. Salir con código 0
```

**Garantía:** si el bKernel sufre un crash entre el paso 4 (Writer Pool) y el paso 5 (CHECKPOINT), el batch se reprocesará al reiniciar. La idempotencia del Writer Pool garantiza que no habrá escrituras duplicadas.

### 18.3 Escenario A — Reinicio normal o crash (recovery automático)

Este escenario es el más frecuente: el bKernel se detiene (reboot del host, actualización, crash) y systemd lo reinicia.

**Proceso automático — sin intervención manual:**

```
1. systemd detecta que bkernel.service está caído
2. systemd espera RestartSec=5s (configurable)
3. systemd reinicia el proceso /usr/local/bin/bkernel
4. bKernel lee el LSN de bkernel_db.checkpoint
5. bKernel se reconecta al slot de replicación desde ese LSN
6. bKernel procesa los eventos pendientes (los que ocurrieron mientras estaba caído)
7. El lag WAL baja gradualmente hasta < 500ms
```

**Verificación:**

```bash
# Verificar que el bKernel está activo y procesando
systemctl status bkernel

# Verificar el lag WAL en tiempo real
journalctl -u bkernel -f | grep "wal_lag"

# En Grafana: métrica bkernel_wal_lag_seconds debe bajar a < 500ms en ~2 minutos
# Si no baja después de 5 minutos: ejecutar RK-003 (SBOS-024)
```

**Tiempo esperado de recuperación:** < 5 minutos para lag < 500ms.
**Pérdida de datos:** cero. El slot de replicación retiene el WAL mientras el bKernel está caído.

### 18.4 Escenario B — Reconstrucción de un bounded context desde un LSN específico

**Caso de uso:** la tabla de proyección de un bounded context se corrompió (bug en el Rule Engine, intervención manual incorrecta) y necesita reconstruirse desde el historial de eventos.

**Herramienta:** `pg_recvlogical`

```bash
# Paso 1: Identificar el LSN de inicio para el replay
# (el punto en el WAL justo antes de la corrupción)
sudo -u postgres psql -d bkernel_db \
  -c "SELECT lsn, updated_at FROM checkpoint ORDER BY updated_at DESC LIMIT 20;"

# Paso 2: Detener el bKernel para el replay manual
sudo systemctl stop bkernel

# Paso 3: Limpiar la tabla de proyección corrupta
sudo -u postgres psql -d bkernel_db \
  -c "TRUNCATE TABLE bkview_invoices_summary;"
# También limpiar processed_events para ese bounded context:
sudo -u postgres psql -d bkernel_db \
  -c "DELETE FROM processed_events WHERE source_app = 'tryton';"

# Paso 4: Replay manual desde el LSN específico
# --startpos: LSN desde donde empezar el replay
# --slot: el slot de replicación del bounded context a reconstruir
# --plugin: pgoutput

pg_recvlogical \
  --dbname=tryton_db \
  --slot=bkernel_tryton \
  --startpos=0/1A2B3C4D \
  --no-loop \
  --file=/tmp/wal_replay_tryton.json \
  --plugin=pgoutput

# Paso 5: Reiniciar el bKernel para procesar el replay
sudo systemctl start bkernel

# El bKernel procesará el archivo de replay y reconstruirá la proyección
# Verificar en Grafana que el lag baja a < 500ms
```

**Tiempo estimado:** 15-60 minutos dependiendo del volumen de eventos a rehacer.
**Pérdida de datos:** cero si el WAL del período a reconstruir está disponible en el slot.

### 18.5 Escenario C — Slot de replicación invalidado

**Causa:** el parámetro `max_slot_wal_keep_size` de PostgreSQL limita cuánto WAL puede retener un slot. Si el bKernel está detenido durante un tiempo prolongado y el WAL acumulado supera ese límite, PostgreSQL invalida el slot automáticamente para proteger el disco.

**Síntoma:** el bKernel arranca pero no puede conectarse al slot de replicación. El log muestra:
```
ERROR: replication slot "bkernel_tryton" does not exist
```

**Procedimiento de recuperación:**

```bash
# Paso 1: Confirmar que el slot está invalidado o eliminado
sudo -u postgres psql -c \
  "SELECT slot_name, active, invalidation_reason FROM pg_replication_slots;"
# invalidation_reason = "wal_removed" confirma el problema

# Paso 2: Detener el bKernel
sudo systemctl stop bkernel

# ⚠️ ADVERTENCIA: El WAL anterior al momento de invalidación ya fue eliminado.
# NO es posible recuperar los eventos perdidos desde el slot.
# La reconstrucción requiere restaurar desde backup.

# Paso 3: Evaluar el gap de eventos
# Tiempo de bKernel caído = tiempo_parada - tiempo_actual
# Si el gap es aceptable (< RPO del SLA): recrear slot y continuar
# Si el gap NO es aceptable: restaurar desde backup (RK-012 de SBOS-026)

# Paso 4 (si gap aceptable): Recrear el slot
sudo -u postgres psql -c \
  "SELECT pg_create_logical_replication_slot('bkernel_tryton', 'pgoutput');"
# Repetir para cada slot invalidado

# Paso 5: Actualizar el LSN en bkernel_db.checkpoint al LSN actual
sudo -u postgres psql -d bkernel_db -c \
  "UPDATE checkpoint SET lsn = pg_current_wal_lsn(), updated_at = NOW();"

# Paso 6: Reiniciar el bKernel
sudo systemctl start bkernel
```

**Prevención:** la alerta `WALSlotReplicationLag` de SBOS-026 §7 dispara cuando el slot acumula > 1GB sin consumir, antes de que `max_slot_wal_keep_size` lo invalide.

### 18.6 Tabla de garantías por escenario

| Escenario | Recovery automático | Pérdida de datos | Intervención manual | Tiempo estimado |
|-----------|-------------------|-----------------|--------------------|----|
| **A: Crash/reinicio** | ✅ Sí — systemd reinicia | ❌ Ninguna | No requerida | < 5 min para lag < 500ms |
| **B: Reconstrucción de BC** | ❌ No — proceso deliberado | ❌ Ninguna (si WAL disponible) | Sí — 4 pasos | 15-60 min |
| **C: Slot invalidado (gap aceptable)** | ❌ No | ✅ Sí — eventos durante el gap | Sí — 5 pasos | 15-30 min |
| **C: Slot invalidado (gap no aceptable)** | ❌ No | Depende del RPO | Sí — restore completo (RK-012) | 30-90 min |

---

*SKULL · SBOS · SBOS-010-WAL · v1.0 · Marzo 2026*
*Insertar como §18 en SBOS-010-BKERNEL*
*Complementa: SBOS-024 RK-003 (bKernel caído), SBOS-026 RK-012 (restore con recreación de slots)*
