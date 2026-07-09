# RB-01 — Ficha en Estado DEGRADADA
## Runbook Operacional · SBOS · SKULL

**Versión:** 1.0 · Junio 2026
**Tiempo estimado de resolución:** 2–15 minutos
**SLO objetivo:** MTTR < 10 minutos para fichas críticas (BOS-REPAIR-01)
**Contexto:** Este runbook aplica durante **y después** de la reparación del plan
BOS-REPAIR. Antes de F1.5 (mutex observer), una reparación puede dispararse
doble — ver sección §Advertencia pre-F1.5.

---

## Síntomas que activan este runbook

Cualquiera de estos:
```
- bosctl rpc bos.state.read | jq '.fichas[] | select(.state=="DEGRADADA")'
  → retorna una o más fichas
- Alerta WebSocket en bosctl: "⚠️  nextcloud DEGRADADA"
- journalctl -u bos -n 50 | grep "DEGRADADA"
- Email/notificación de GitHub Actions: "Deploy to Staging — health check failed"
```

---

## §Advertencia pre-F1.5 (leer si el plan aún no llegó a F1.5)

Si el átomo F1.5 (mutex observer en `internal/observer/`) **no está completo**,
el daemon puede lanzar **dos instancias paralelas** de la saga de reparación
sobre la misma ficha. Esto es la race condition P6/P14 documentada en
BOS-REPAIR-00.

**Señal de que P6/P14 está activa:**
```bash
journalctl -u bos --since "5 minutes ago" | grep -c "repair.*<ficha_id>"
# Si retorna 2 o más → P6/P14 activa — ejecutar PASO 0 antes de continuar
```

**PASO 0 (solo si P6/P14 activa) — Frenar la segunda instancia:**
```bash
# Detener el daemon para que no lance más repairs:
sudo systemctl stop bos.service

# Verificar que no queda ningún script de reparación corriendo:
ps aux | grep "MASTER_INSTALL_SBOS.sh"
# Si hay procesos: esperar a que terminen (no matar — pueden dejar estado corrupto)

# Después de que terminen, continuar con PASO 1
sudo systemctl start bos.service
```

---

## Diagnóstico inicial (< 2 minutos)

```bash
# 1. Identificar qué fichas están DEGRADADAS y desde cuándo
bosctl rpc bos.state.read | jq '
  .fichas | to_entries[]
  | select(.value.state == "DEGRADADA")
  | {ficha: .key, state: .value.state, since: .value.updated_at}
'

# 2. Diagnóstico rápido — sagas de consulta paralelas (requiere F6.7)
# Si F6.7 no está implementado aún, usar los comandos del PASO 2 directamente
bosctl rpc bos.query.repair | jq '{
  fichas_degradadas: .fichas_degradadas,
  causa_probable: .causa_probable,
  ultima_saga: .ultima_saga
}'

# 3. Ver los últimos eventos de la ficha degradada (audit log ISO 27001):
grep "<FICHA_ID>" /var/log/bos/audit.log | tail -5
# o en logs del daemon directamente:
journalctl -u bos --since "30 minutes ago" | grep "<FICHA_ID>"
```

---

## Árbol de decisión

```
¿Cuál es la causa?
│
├── OOMKilled / pod reiniciado → CASO A (más común)
├── Disco lleno / quota excedida → CASO B
├── Dependencia caída (ej: postgres para keycloak) → CASO C
├── Script de reparación anterior falló → CASO D
└── Estado corrupto en .sbos_state.json → CASO E (grave)
```

---

## CASO A — OOMKilled / Pod reiniciado (el más común)

**Verificar:**
```bash
kubectl describe pod -n sbos-<namespace> <pod-name> | grep -A5 "Last State:"
# Si muestra: "Reason: OOMKilled" → causa confirmada
```

**Reparar:**
```bash
# Ejecutar la saga de reparación estándar
bosctl rpc bos.ficha.repair '{"ficha_id":"<FICHA_ID>"}'

# Seguimiento en tiempo real (en otra terminal):
journalctl -u bos -f | grep "<FICHA_ID>"
# Debe mostrar la secuencia:
#   → REPARANDO (saga iniciada)
#   → step_ok: pre-diagnose
#   → step_ok: validate
#   → step_ok: execute-repair  (tarda 2–8 minutos según la ficha)
#   → step_ok: verify-recovery
#   → INSTALADA (saga completada)
```

**Verificar éxito:**
```bash
bosctl rpc bos.ficha.probe '{"ficha_id":"<FICHA_ID>"}'
# debe retornar: {"healthy": true}

bosctl rpc bos.state.read | jq '.fichas["<FICHA_ID>"].state'
# debe retornar: "INSTALADA"
```

---

## CASO B — Disco lleno / Quota excedida

**Verificar:**
```bash
df -h /var /data /opt
# Si algún filesystem está al >85%:
du -sh /var/lib/bos/* | sort -h | tail -10  # qué ocupa más en bos
du -sh /data/k8s/pvc/* | sort -h | tail -10  # PVCs más grandes
```

**Liberar espacio antes de reparar:**
```bash
# Limpiar logs antiguos de bos (>30 días):
journalctl --vacuum-time=30d

# Limpiar imágenes container no usadas:
crictl rmi --prune

# Revisar PVCs y su consumo (limpieza automatizada llega con F9 — bosctl storage):
kubectl get pvc --all-namespaces
kubectl -n sbos-skull exec <pod> -- du -sh /var/log 2>/dev/null  # si aplica

# Verificar espacio libre:
df -h /var | awk 'NR==2 {gsub(/%/,""); if ($5 > 85) print "❌ aún lleno: "$5"%"; else print "✅ espacio OK: "$5"%"}'
```

**Después de liberar espacio:**
```bash
bosctl rpc bos.ficha.repair '{"ficha_id":"<FICHA_ID>"}'
```

---

## CASO C — Dependencia caída

**Verificar el DAG de dependencias:**
```bash
bosctl rpc bos.state.read | jq '
  .fichas | to_entries[]
  | select(.value.state != "INSTALADA" and .value.state != "PENDIENTE")
  | {ficha: .key, state: .value.state}
'
# Muestra TODAS las fichas no-INSTALADA — puede haber una cadena de fallos
```

**Reparar en orden topológico** (las dependencias primero):
```bash
# Orden correcto para los servicios críticos:
# 1. sbos-bootstrap-os → 2. sbos-bootstrap-k8s → 3. postgresql → 4. redis
# → 5. vault → 6. keycloak → 7. kong → 8. resto de fichas

# Reparar la ficha más básica degradada:
bosctl rpc bos.ficha.repair '{"ficha_id":"postgresql"}'
# esperar a INSTALADA, luego:
bosctl rpc bos.ficha.repair '{"ficha_id":"redis"}'
# etc.
```

---

## CASO D — Saga anterior falló y dejó estado inconsistente

**Síntoma:**
```bash
bosctl rpc bos.state.read | jq '.fichas["<FICHA_ID>"].state'
# retorna: "FALLA_INSTALACION" o "FALLA_ACTUALIZACION"
```

**Verificar el audit log de la saga fallida:**
```bash
grep "FICHA_ID.*SAGA\|SAGA.*FICHA_ID" /var/log/bos/audit.log | tail -20
# Buscar: SAGA_STEP_FAIL con el mensaje de error
```

**Reparar:**
```bash
# Forzar re-evaluación del estado (bos.ficha.state.reset llega con F9):
# reiniciar el daemon — StartupReconcile re-verifica el estado real de
# cada ficha contra K8s al arrancar (F1.5) y corrige estados colgados:
sudo systemctl restart bos
bosctl rpc bos.ficha.status '{"ficha_id":"<FICHA_ID>"}'

# Luego reparar normalmente:
bosctl rpc bos.ficha.repair '{"ficha_id":"<FICHA_ID>"}'
```

---

## CASO E — Estado corrupto en `.sbos_state.json` (grave)

**Síntoma:** múltiples fichas en estado inconsistente sin causa aparente, o
`bosctl rpc bos.state.read` falla con error de parseo.

**Diagnóstico:**
```bash
# Verificar integridad del archivo de estado:
cat /etc/bos/.sbos_state.json | python3 -m json.tool > /dev/null
# Si falla: el JSON está corrupto

# Ver si existe el backup:
ls -la /etc/bos/.sbos_state.json*
# state.Manager mantiene: .sbos_state.json + .sbos_state.json.bak
```

**Recuperar desde backup:**
```bash
# Detener el daemon:
sudo systemctl stop bos.service

# Restaurar desde backup:
cp /etc/bos/.sbos_state.json /etc/bos/.sbos_state.json.corrupto
cp /etc/bos/.sbos_state.json.bak /etc/bos/.sbos_state.json

# Reiniciar y verificar:
sudo systemctl start bos.service
sleep 5
bosctl rpc bos.state.read | jq '.fichas | length'
# debe retornar el número de fichas esperado (22)
```

**Si el backup también está corrupto** (caso extremo):
```bash
# state.Manager tiene recovery: rebuilt from empty (ver internal/state/manager.go)
# Al arrancar sin .sbos_state.json, reconstruye el estado desde los pods K8s
rm /etc/bos/.sbos_state.json
sudo systemctl restart bos.service
# El daemon hace: recovery = RecoveryRebuilt, logs: "state file rebuilt from empty"
# Las fichas aparecen en PENDIENTE — el observer loop las re-detecta y actualiza
```

---

## Verificación final (obligatoria)

```bash
# 1. La ficha está INSTALADA:
bosctl rpc bos.state.read | jq '.fichas["<FICHA_ID>"].state'
# → "INSTALADA"

# 2. La probe de salud pasa:
bosctl rpc bos.ficha.probe '{"ficha_id":"<FICHA_ID>"}'
# → {"healthy": true}

# 3. El criterio de certificación correspondiente pasa:
#    (C-04 para postgresql, C-05 para redis, C-07 para keycloak, etc.)
bosctl bootstrap verify --only=C-0X
# → C-0X ✓

# 4. Sin más fichas DEGRADADAS:
bosctl rpc bos.state.read | jq '[.fichas[] | select(.state=="DEGRADADA")] | length'
# → 0
```

---

## Registro del incidente (obligatorio — ISO 27001 A.8.15)

```bash
# El audit log ya registra automáticamente:
grep "REPAIR_START\|REPAIR_OK\|SAGA_STEP" /var/log/bos/audit.log | tail -20

# Para incidentes significativos (impacto en usuarios reales), registrar manualmente:
# docs/runbooks/INCIDENTES-LOG.md — agregar entrada con:
# Fecha, ficha, causa, tiempo de resolución, acciones tomadas, preventiva
```

---

## Escalado (si nada funciona en 15 min)

```
1. Ejecutar: bosctl rpc bos.query.repair | jq . > /tmp/repair-$(date +%Y%m%d-%H%M).json
   (preservar el diagnóstico completo antes de cambiar algo más)

2. Ejecutar: journalctl -u bos --since "1 hour ago" > /tmp/bos-logs-$(date +%Y%m%d-%H%M).txt

3. Abrir issue con ambos archivos adjuntos.

4. Mientras se investiga: registrar la ficha en INCIDENTES-LOG.md como
   "en investigación" para que el equipo contextualice sus alertas.
   (bos.ficha.pause — estado PAUSADA de ADR-021 — se expone por RPC en F9)
```

---

*RB-01 v1.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
*Fuentes: BOS-REPAIR-00 P6/P14, BOS-REPAIR-01 saga estándar, BOS-REPAIR-13 flujo end-to-end*
*Referencia de código: internal/repair/repair_manager.go, internal/state/manager.go*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
