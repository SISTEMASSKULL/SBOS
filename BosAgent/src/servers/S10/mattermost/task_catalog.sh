#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — mattermost (Ficha S10)
# Mattermost Team Edition 9.11 — Chat empresarial SBOS
#
# IDEMPOTENTE: install y update producen el mismo resultado.
# - Si el pod no existe → lo crea
# - Si el pod existe → verifica health y reconfigura canales
# ============================================================================
set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/mattermost.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-comm"
IMAGE="mattermost/mattermost-team-edition:9.11"
MATTERMOST_URL="${MATTERMOST_URL:-http://localhost:8065}"

# ── Step 1: Deploy/Verify pod ─────────────────────────────────
echo "$__STEP_START__ Deploy Mattermost $IMAGE"

kubectl --kubeconfig="$KUBECONFIG_DEST" create namespace "$NS" --dry-run=client -o yaml 2>/dev/null | kubectl apply -f - || true

# Verificar si ya existe
EXISTING=$(kubectl --kubeconfig="$KUBECONFIG_DEST" -n "$NS" get pods -l app=mattermost --no-headers 2>/dev/null | grep -c Running || echo 0)

if [ "$EXISTING" -eq 0 ]; then
  echo "[mattermost] Pod no existe — creando..."
  kubectl --kubeconfig="$KUBECONFIG_DEST" -n "$NS" apply -f - <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mattermost
  namespace: $NS
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mattermost
  template:
    metadata:
      labels:
        app: mattermost
    spec:
      containers:
      - name: mattermost
        image: $IMAGE
        env:
        - name: MM_SERVICESETTINGS_SITEURL
          value: "\${MM_SITEURL:-http://localhost:8065}"
        - name: MM_SERVICESETTINGS_LISTENADDRESS
          value: ":8065"
        - name: MM_SQLSETTINGS_DRIVERNAME
          value: "postgres"
        - name: MM_SQLSETTINGS_DATASOURCE
          value: "\${MM_DATASOURCE}"
        - name: MM_EMAILSETTINGS_SENDEMAILNOTIFICATIONS
          value: "false"
        - name: MM_LOGSETTINGS_FILELEVEL
          value: "ERROR"
        ports:
        - containerPort: 8065
        readinessProbe:
          httpGet:
            path: /api/v4/system/ping
            port: 8065
          initialDelaySeconds: 60
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: mattermost
  namespace: $NS
spec:
  type: ClusterIP
  ports:
  - port: 8065
    targetPort: 8065
  selector:
    app: mattermost
YAML

  echo "$__STEP_START__ Esperando pod ready (120s)..."
  kubectl --kubeconfig="$KUBECONFIG_DEST" -n "$NS" wait --for=condition=ready pod -l app=mattermost --timeout=180s 2>/dev/null || {
    echo "$__STEP_FAIL__ Timeout esperando Mattermost"
    exit 1
  }
else
  echo "[mattermost] Pod existente — verificando health..."
fi

echo "$__STEP_OK__ Mattermost pod operativo"

# ── Step 2: Configurar canales (idempotente) ──────────────────
echo "$__STEP_START__ Configuracion de canales"

# Esperar que la API responda
for i in $(seq 1 12); do
  if curl -sf -o /dev/null "$MATTERMOST_URL/api/v4/system/ping" 2>/dev/null; then
    break
  fi
  sleep 10
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/init_channels.sh"

echo "$__STEP_OK__ Canales configurados (idempotente)"
echo "[mattermost] Ficha instalada/actualizada correctamente."
