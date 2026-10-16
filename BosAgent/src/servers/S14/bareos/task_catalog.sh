#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — bareos-director
# Imagen: barcosystems/bareos-director:23.0.1
# Namespace: sbos-ops
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/bareos-director.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-ops"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [bareos-director] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

# Motor de puertos BOS — asigna puerto ClusterIP según SBOS-050
_portman() {
    local ficha_id="$1" ficha_index="$2" server="$3" ns="${4:-default}"
    local TOKEN; TOKEN="$(cat /etc/bos/rpc-token 2>/dev/null)"
    BOS_RPC_TOKEN="$TOKEN" bosctl rpc bos.portman.assign \
      "{\"ficha_id\":\"$ficha_id\",\"ficha_index\":$ficha_index,\"logical_server\":\"$server\",\"port_types\":[\"K8S_CLUSTER_IP\"],\"namespace\":\"$ns\",\"ctx_id\":\"install-$ficha_id\"}" \
      2>/dev/null | python3 -I -c \
      "import json,sys; d=json.load(sys.stdin); a=d.get('assignments',[]); print(a[0]['port'] if a else '')" \
    2>/dev/null
}

_wait_ready() {
    local t="${1:-180}" e=0
    while (( e < t )); do
        local r
        r=$(_k get deployment bareos-director -n "$NS" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5))
        (( e % 30 == 0 )) && _log "Esperando bareos-director Ready... ${e}/${t}s"
    done; return 1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || {
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
        _log "Namespace $NS creado"
    }
    echo "${__STEP_OK__} verificar_namespace"

    echo "${__STEP_START__} networkpolicy_ops_to_data"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'NPEOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ops-postgresql
  namespace: sbos-data
spec:
  podSelector:
    matchLabels:
      app: postgresql
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-ops
      ports:
        - protocol: TCP
          port: 5432
NPEOF
    echo "${__STEP_OK__} networkpolicy_ops_to_data"

    echo "${__STEP_START__} crear_bareos_db"
    if _k exec postgresql-0 -n sbos-data -- psql -U postgres -tc \
        "SELECT 1 FROM pg_database WHERE datname='bareos_db'" 2>/dev/null | grep -q 1; then
        echo "${__STEP_SKIP__} crear_bareos_db: ya existe"
    else
        _k exec postgresql-0 -n sbos-data -- psql -U postgres -c \
            "CREATE DATABASE bareos_db;" >> "$FICHA_LOG" 2>&1
        echo "${__STEP_OK__} crear_bareos_db"
    fi
    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"
    ficha_pre_install

    local r
    r=$(_k get deployment bareos-director -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r >= 1 )); then
        echo "${__STEP_SKIP__} bareos-director_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} crear_pv_bareos"
    mkdir -p /data/bareos
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'PVEOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-bareos-data
  labels:
    app: bareos-director
    sbos.app/managed-by: bos
spec:
  capacity:
    storage: 10Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  local:
    path: /data/bareos
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: Exists
  claimRef:
    name: bareos-data
    namespace: sbos-ops
PVEOF
    echo "${__STEP_OK__} crear_pv_bareos"

    echo "${__STEP_START__} crear_pvc_bareos"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'PVCEOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: bareos-data
  namespace: sbos-ops
  labels:
    app: bareos-director
    sbos.app/managed-by: bos
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: local-path
  resources:
    requests:
      storage: 10Gi
PVCEOF
    echo "${__STEP_OK__} crear_pvc_bareos"

    echo "${__STEP_START__} aplicar_manifest_bareos-director"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bareos-director
  namespace: sbos-ops
  labels:
    app: bareos-director
    sbos.app/managed-by: bos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bareos-director
  template:
    metadata:
      labels:
        app: bareos-director
    spec:
      containers:
        - name: bareos-director
          image: barcosystems/bareos-director:23.0.1
          ports:
            - containerPort: 9100
          env:
            - name: DB_HOST
              value: postgresql.sbos-data.svc.cluster.local
            - name: DB_USER
              value: postgres
            - name: DB_NAME
              value: bareos_db
          resources:
            requests:
              cpu: "100m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          volumeMounts:
            - name: bareos-data
              mountPath: /var/lib/bareos
      volumes:
        - name: bareos-data
          persistentVolumeClaim:
            claimName: bareos-data
K8SEOF
    echo "${__STEP_START__} portman_bareos"
    local SVC_PORT; SVC_PORT=$(_portman "bareos" 0 "S14" "sbos-ops")
    SVC_PORT="${SVC_PORT:-21400}"
    _log "Puerto ClusterIP portman: ${SVC_PORT}"
    echo "${__STEP_OK__} portman_bareos"

    _k apply -f - >> "$FICHA_LOG" 2>&1 <<SVCINNER
apiVersion: v1
kind: Service
metadata:
  name: bareos-director
  namespace: sbos-ops
spec:
  selector:
    app: bareos-director
  ports:
    - port: ${SVC_PORT}
      targetPort: 9100
SVCINNER
    echo "${__STEP_OK__} aplicar_manifest_bareos-director"

    echo "${__STEP_START__} esperar_bareos-director_ready"
    _wait_ready 180 || { echo "${__STEP_FAIL__} esperar_bareos-director_ready: timeout 180s"; return 1; }
    echo "${__STEP_OK__} esperar_bareos-director_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_bareos-director"
    local r
    r=$(_k get deployment bareos-director -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) || { echo "${__STEP_FAIL__} verificar_bareos-director: ${r}/1"; return 1; }
    echo "${__STEP_OK__} verificar_bareos-director (${r}/1)"
    return 0
}

ficha_health() {
    local r
    r=$(_k get deployment bareos-director -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: bareos-director ${r}/1"
    return 1
}

ficha_post_install() {
    # Evitar post_install_generic (usa namespace default con label errado)
    return 0
}

ficha_repair() {
    _log "ficha_repair: re-aplicando manifests bareos (idempotente)"
    ficha_install
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_bareos-director_ready"
    local ready
    ready=$(_k get deployment bareos-director -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_OK__} test_bareos-director_ready (${ready}/1)"
    else
        echo "${__STEP_FAIL__} test_bareos-director_ready: ${ready}/1"; ok=1
    fi
    return $ok
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_bareos-director"
    _k delete deployment bareos-director -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete service bareos-director -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_bareos-director"
    return 0
}
