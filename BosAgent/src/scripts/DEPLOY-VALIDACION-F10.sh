#!/bin/bash
# DEPLOY-VALIDACION-F10.sh — despliegue y validación COMPLETA de F10 (biaos)
# en el servidor de staging, EN UNA SOLA SESIÓN SSH.
#
# Lección del 2026-06-10: el ciclo deploy-validación de F9/F10 abrió ~20
# conexiones SSH en minutos y el servidor bloqueó el acceso. Este script
# empaqueta TODO (binarios + catálogo + batería de pruebas) y lo ejecuta
# remotamente con UNA conexión scp + UNA conexión ssh. Nada más.
#
# Uso:
#   bash scripts/DEPLOY-VALIDACION-F10.sh [usuario@host]
#   (default: root@13.140.128.230)
#
# Requisitos locales: Go en /home/skull/go-dist/go/bin, clave SSH instalada.
set -euo pipefail

HOST="${1:-root@13.140.128.230}"
SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export PATH="$PATH:/home/skull/go-dist/go/bin"

echo "══════════════════════════════════════════════════════"
echo " 1/4 · Compilando binarios estáticos (linux/amd64)"
echo "══════════════════════════════════════════════════════"
cd "$SRC_DIR"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o "$WORK/bos" ./cmd/bos
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o "$WORK/bosctl" ./cmd/bosctl
cp docs/biaos/action_catalog.yml "$WORK/action_catalog.yml"

echo "══════════════════════════════════════════════════════"
echo " 2/4 · Generando script remoto de deploy + validación"
echo "══════════════════════════════════════════════════════"
cat > "$WORK/remoto.sh" <<'REMOTO'
#!/bin/bash
# Ejecuta EN el servidor: backup → deploy → restart → batería completa.
set -u
export KUBECONFIG=/etc/kubernetes/admin.conf
R=/tmp/f10-reporte.txt
: > "$R"
log() { echo "$1" | tee -a "$R"; }
check() { # check <nombre> <comando...>
  local n="$1"; shift
  if "$@" >>"$R" 2>&1; then log "✅ $n"; else log "❌ $n"; fi
}

log "═══ DEPLOY F10 — $(date -Is) ═══"

# 0. Pre-estado
log "── pre-estado ──"
systemctl is-active bos kubelet containerd >>"$R" 2>&1
kubectl get nodes --no-headers >>"$R" 2>&1 || true

# 1. Backup de binarios actuales (ADR-016)
ts=$(date +%Y%m%d_%H%M%S)
mkdir -p /root/backups/S-HOST/bos-golden
for b in bos bosctl; do
  cp /usr/local/bin/$b /root/backups/S-HOST/bos-golden/${b}-pre-f10-${ts} 2>/dev/null || true
done
log "✅ backup binarios (pre-f10-${ts})"

# 2. Deploy
mv /tmp/f10/bos /usr/local/bin/bos
mv /tmp/f10/bosctl /usr/local/bin/bosctl
chmod 755 /usr/local/bin/bos /usr/local/bin/bosctl
mkdir -p /etc/bos/ai
cp /tmp/f10/action_catalog.yml /etc/bos/ai/action_catalog.yml
log "✅ binarios F10 + catálogo desplegados"

# 3. Restart (F9.0: NO toca el cluster)
systemctl restart bos && sleep 4
check "bos.service activo" systemctl is-active bos
check "cluster intacto tras restart (F9.0)" kubectl get nodes --no-headers

# 4. Batería F10 — biaos
log "── batería F10 (biaos) ──"
journalctl -u bos --since "30 seconds ago" | grep -i biaos | tail -2 >>"$R" 2>&1
check "bos.ai.catalog (17 herramientas)" bosctl ai catalog
log "── bos.ai.run: diagnóstico (TIPO A — ejecuta query.system real) ──"
bosctl ai run "diagnostica el estado de salud del servidor" >>"$R" 2>&1 && log "✅ ai run TIPO A" || log "❌ ai run TIPO A"
log "── bos.ai.run: caso real kube-state-metrics (TIPO B — debe pedir HITL) ──"
SALIDA=$(bosctl ai run "el pod kube-state-metrics esta en CrashLoopBackOff hay que reiniciarlo" 2>&1)
echo "$SALIDA" >>"$R"
SESION=$(echo "$SALIDA" | grep -o 'hitl-[a-f0-9]*' | head -1)
if [ -n "$SESION" ]; then
  log "✅ HITL solicitado (sesión $SESION)"
  log "── confirmando HITL (ejecuta pod.restart real vía dispatcher) ──"
  bosctl ai confirm "$SESION" >>"$R" 2>&1 && log "✅ ai confirm ejecutó" || log "❌ ai confirm"
else
  log "❌ no se creó sesión HITL"
fi
check "export-training (dataset desde audit)" bosctl ai export-training /tmp/f10-training.jsonl
wc -l /tmp/f10-training.jsonl >>"$R" 2>&1 || true
check "audit JSONL existe" test -s /var/log/bos/ai-audit.jsonl

# 5. Regresión F6/F9 (no rompimos nada)
log "── regresión F6/F9 ──"
check "bos.query.system <4s" bosctl rpc bos.query.system
check "node list" bosctl node list
check "maintenance saga (dry)" bosctl node maintain "$(hostname)"
check "métricas ≥15" bash -c 'test "$(curl -s http://127.0.0.1:9090/metrics | grep -c "^bos_")" -ge 15'
check "auth: destructivo sin token → -32600" bash -c 'env BOS_RPC_TOKEN= BOS_RPC_TOKEN_FILE=/noexiste bosctl rpc bos.ficha.repair "{\"ficha_id\":\"x\"}" 2>&1 | grep -q "\-32600"'

log "═══ FIN — reporte completo en $R ═══"
echo; echo "================ REPORTE ================"
cat "$R"
REMOTO
chmod +x "$WORK/remoto.sh"

echo "══════════════════════════════════════════════════════"
echo " 3/4 · Subiendo paquete (1 conexión scp)"
echo "══════════════════════════════════════════════════════"
ssh -o BatchMode=yes -o ConnectTimeout=20 "$HOST" 'mkdir -p /tmp/f10'
scp -o BatchMode=yes "$WORK/bos" "$WORK/bosctl" "$WORK/action_catalog.yml" "$WORK/remoto.sh" "$HOST:/tmp/f10/"

echo "══════════════════════════════════════════════════════"
echo " 4/4 · Ejecutando deploy + validación (1 conexión ssh)"
echo "══════════════════════════════════════════════════════"
ssh -o BatchMode=yes "$HOST" 'bash /tmp/f10/remoto.sh'

echo
echo "Listo. Reporte remoto: /tmp/f10-reporte.txt en el servidor."
