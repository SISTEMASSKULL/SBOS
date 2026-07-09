# RB-02 — DATA RACE Detectada en Logs
## Runbook Operacional · SBOS · SKULL

**Versión:** 1.0 · Junio 2026
**Tiempo estimado de resolución:** 5–30 minutos
**Criticidad:** 🔴 ALTA — una DATA RACE puede corromper el estado de fichas silenciosamente
**Contexto:** Este runbook existe por la race condition P6/P14 documentada en
BOS-REPAIR-00. Es el riesgo más crítico del sistema hasta que el átomo F1.5
(mutex observer) esté completo.

---

## Síntomas que activan este runbook

**Síntoma primario — en logs del daemon:**
```bash
journalctl -u bos | grep "DATA RACE"
# Si retorna algún resultado → ACTIVAR ESTE RUNBOOK INMEDIATAMENTE
```

**Síntoma secundario — en el pipeline CI:**
```
GitHub Actions → Race Detection (HARD GATE) → ❌ FAILED
Log del job: "DATA RACE detected"
```

**Síntoma terciario — comportamiento extraño en producción:**
```
- Ficha aparece como INSTALADA en bos.state.read pero el pod está caído
- Ficha pasa de DEGRADADA a INSTALADA y vuelve a DEGRADADA en ciclos rápidos
- Dos entradas REPAIR_START para la misma ficha con < 1 segundo de diferencia
  en /var/log/bos/audit.log
```

---

## Entender el problema antes de actuar

La race condition P6/P14 es una **condición de carrera entre dos loops**:

```
runObserverLoop (cmd/bos/main.go)     reconcile.Scheduler (internal/reconcile/)
        │                                       │
        ├─ ve ficha DEGRADADA                   ├─ ve ficha DEGRADADA
        ├─ llama orchestrator.Repair("redis")   ├─ llama s.installer.Repair("redis")
        │                                       │
        └─────────── AMBOS CORREN EN PARALELO ──┘
                     sin exclusión mutua
                     → dos bash scripts simultáneos
                     → estado del archivo JSON corrupto
```

**Resultado observable:** `00_MASTER_INSTALL_SBOS.sh repair redis` corre
dos veces en paralelo. Los scripts bash de SBOS no son idempotentes —
pueden dejar la ficha en un estado inconsistente entre DEGRADADA e INSTALADA.

---

## PASO 1 — Confirmar y capturar el reporte de race

```bash
# Capturar el reporte completo antes de que rote el log:
journalctl -u bos --since "1 hour ago" | grep -A 30 "DATA RACE" \
  > /tmp/race-report-$(date +%Y%m%d-%H%M).txt

echo "Reporte guardado en: /tmp/race-report-$(date +%Y%m%d-%H%M).txt"
cat /tmp/race-report-*.txt | head -50
```

**Leer el reporte — qué buscar:**
```
==================
WARNING: DATA RACE
Read at 0x... by goroutine N:
  bos/cmd/bos.runObserverLoop(...)    ← goroutine 1
      cmd/bos/main.go:XXX

Previous write at 0x... by goroutine M:
  bos/internal/reconcile.(*Scheduler).reconcile(...)  ← goroutine 2
      internal/reconcile/scheduler.go:YYY
==================
```

Si el reporte apunta a `runObserverLoop` y `reconcile.Scheduler` — es P6/P14.
Si apunta a otra parte — documentar la ubicación y continuar de todos modos.

---

## PASO 2 — Verificar si hay corrupción de estado actual

```bash
# ¿El estado JSON es parseable?
python3 -m json.tool /etc/bos/.sbos_state.json > /dev/null \
  && echo "✅ JSON válido" || echo "❌ JSON CORRUPTO — ir a CASO ESTADO CORRUPTO"

# ¿Hay fichas en estado inconsistente?
bosctl rpc bos.state.read | jq '
  .fichas | to_entries[]
  | select(.value.state == "REPARANDO")
  | {ficha: .key, desde: .value.updated_at}
'
# Si una ficha lleva REPARANDO más de 10 minutos → saga colgada

# ¿Hay dos entradas REPAIR_START para la misma ficha en el audit log?
grep "REPAIR_START" /var/log/bos/audit.log | awk '{print $5}' | sort | uniq -d
# Si retorna algún ficha_id → doble repair confirmado
```

---

## CASO: Corrupción confirmada (REPARANDO bloqueado o JSON inválido)

```bash
# 1. Detener el daemon para parar la race:
sudo systemctl stop bos.service

# 2. Si JSON inválido: restaurar desde backup
python3 -m json.tool /etc/bos/.sbos_state.json > /dev/null || {
  echo "Restaurando desde backup..."
  cp /etc/bos/.sbos_state.json /etc/bos/.sbos_state.json.corrupto
  cp /etc/bos/.sbos_state.json.bak /etc/bos/.sbos_state.json
}

# 3. Si ficha quedó en REPARANDO: resetear manualmente al estado anterior
# (editar el JSON directamente — solo en emergencia):
python3 << 'PYEOF'
import json
with open('/etc/bos/.sbos_state.json', 'r') as f:
    state = json.load(f)
for name, ficha in state.get('fichas', {}).items():
    if ficha.get('state') == 'REPARANDO':
        print(f"Reseteando {name}: REPARANDO → DEGRADADA")
        ficha['state'] = 'DEGRADADA'
with open('/etc/bos/.sbos_state.json', 'w') as f:
    json.dump(state, f, indent=2)
print("Estado corregido.")
PYEOF

# 4. Reiniciar el daemon:
sudo systemctl start bos.service
sleep 5
bosctl rpc bos.state.read | jq '[.fichas[] | select(.state=="REPARANDO")] | length'
# debe retornar 0
```

---

## PASO 3 — Reproducir localmente y confirmar la race

Este paso es **obligatorio** — confirmar que la race existe antes de implementar F1.5.

```bash
# En VPS DEV (144.91.76.130):
ssh skull@144.91.76.130
cd <repositorio>

# Ejecutar con race detector (puede tardar varios minutos):
go test -race -count=20 -timeout=5m ./... 2>&1 | grep -E "DATA RACE|PASS|FAIL"

# Si se encuentra la race en internal/reconcile o cmd/bos:
echo "✅ Race confirmada — proceder con F1.5"

# Si NO se encuentra:
echo "⚠️  Race no reproducible localmente"
echo "    Puede ser intermitente — aumentar count:"
go test -race -count=100 -run TestObserver ./... 2>&1 | tail -5
```

---

## PASO 4 — Solución correcta: implementar F1.5

La solución permanente es el átomo F1.5 del plan maestro:
crear `internal/observer/` con `sync.Mutex` que impida que observer y
reconciler ejecuten `Repair()` simultáneamente.

```bash
# Verificar si F1.5 ya está implementado:
[ -f internal/observer/observer.go ] \
  && grep -q "sync.Mutex" internal/observer/observer.go \
  && echo "✅ F1.5 implementado" \
  || echo "❌ F1.5 pendiente — implementar según EJECUCION-F1.5-INSTRUCCIONES-AGENTE.md"
```

**Si F1.5 no está implementado — solución temporal:**
```bash
# Deshabilitar el auto-repair del scheduler hasta que F1.5 esté listo:
# En bos.toml agregar:
# [reconcile]
# watchdog_auto_repair = false

sudo nano /etc/bos/bos.toml
# Agregar o cambiar: watchdog_auto_repair = false

sudo systemctl restart bos.service
journalctl -u bos -n 20 | grep "autoRepair\|auto_repair"
# debe mostrar: autoRepair: false
```

**Advertencia sobre la solución temporal:** deshabilitar `watchdog_auto_repair`
hace que las fichas DEGRADADAS no se reparen automáticamente. El operador
debe ejecutar las reparaciones manualmente con `bosctl rpc bos.ficha.repair`
hasta que F1.5 esté completo.

---

## PASO 5 — Verificar que la race está resuelta

```bash
# Después de implementar F1.5:
go test -race -count=100 -timeout=10m ./internal/observer/ \
  -run TestObserver_NoParallelRepair
# debe mostrar: ok  bos/internal/observer  [100 runs]
# debe NO mostrar: DATA RACE

# Verificar en staging (BOS_OBSERVER_V2=true):
ssh root@13.140.128.230
journalctl -u bos-staging --since "1 hour ago" | grep "DATA RACE"
# debe retornar vacío
```

---

## PASO 6 — Registro post-incidente (obligatorio)

```bash
# En docs/runbooks/INCIDENTES-LOG.md agregar:
cat >> docs/runbooks/INCIDENTES-LOG.md << EOF
## $(date '+%Y-%m-%d %H:%M') — DATA RACE P6/P14

**Ficha afectada:** <FICHA_ID>
**Causa:** Race condition entre runObserverLoop y reconcile.Scheduler
**Detectado por:** [pipeline CI / journalctl / comportamiento extraño]
**Corrupción de estado:** [sí/no — describir si sí]
**Tiempo de resolución:** X minutos
**Solución aplicada:** [temporal (watchdog_auto_repair=false) / F1.5 implementado]
**Próximos pasos:** [completar F1.5 / ya resuelto]
EOF
```

---

## Referencia rápida de comandos

```bash
# Detectar race activa:
journalctl -u bos | grep "DATA RACE"

# Capturar reporte:
journalctl -u bos --since "1h ago" | grep -A 30 "DATA RACE" > /tmp/race-report.txt

# Verificar estado del daemon:
bosctl rpc bos.state.read | jq '[.fichas[] | select(.state=="REPARANDO")] | length'

# Solución temporal:
# En bos.toml: watchdog_auto_repair = false → restart bos.service

# Solución permanente:
# Implementar F1.5 → go test -race -count=100 ./internal/observer/ → verde

# Verificar F1.5 implementado:
grep -q "sync.Mutex" internal/observer/observer.go && echo "✅ mutex presente"
```

---

*RB-02 v1.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
*Fuente primaria: BOS-REPAIR-00 §Problema 6 (P6) y §Problema 14 (P14)*
*Solución permanente: Plan Maestro v3.0 → Átomo F1.5*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
