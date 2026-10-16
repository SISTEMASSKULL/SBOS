#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — gitlab
# Imagen: gitlab/gitlab-ce:17.9.6-ce.0
# Namespace: sbos-ops
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/gitlab.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-ops"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [gitlab] $*" | tee -a "$FICHA_LOG"; }
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
        r=$(_k get statefulset gitlab -n "$NS" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5))
        (( e % 30 == 0 )) && _log "Esperando gitlab Ready... ${e}/${t}s"
    done; return 1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || {
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
        _log "Namespace $NS creado"
    }
    echo "${__STEP_OK__} verificar_namespace"

    echo "${__STEP_START__} crear_pv_gitlab_data"
    mkdir -p /data/gitlab-data
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-gitlab-data
spec:
  capacity:
    storage: 50Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  local:
    path: /data/gitlab-data
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: Exists
  claimRef:
    name: gitlab-data-gitlab-0
    namespace: sbos-ops
K8SEOF
    echo "${__STEP_OK__} crear_pv_gitlab_data"

    echo "${__STEP_START__} crear_pv_gitlab_config"
    mkdir -p /data/gitlab-config
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-gitlab-config
spec:
  capacity:
    storage: 1Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  local:
    path: /data/gitlab-config
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: Exists
  claimRef:
    name: gitlab-config-gitlab-0
    namespace: sbos-ops
K8SEOF
    echo "${__STEP_OK__} crear_pv_gitlab_config"

    echo "${__STEP_START__} crear_pv_gitlab_logs"
    mkdir -p /data/gitlab-logs
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-gitlab-logs
spec:
  capacity:
    storage: 5Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  local:
    path: /data/gitlab-logs
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: Exists
  claimRef:
    name: gitlab-logs-gitlab-0
    namespace: sbos-ops
K8SEOF
    echo "${__STEP_OK__} crear_pv_gitlab_logs"
    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"
    ficha_pre_install

    local r
    r=$(_k get statefulset gitlab -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r >= 1 )); then
        echo "${__STEP_SKIP__} gitlab_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} portman_gitlab"
    local SVC_PORT; SVC_PORT=$(_portman "gitlab" 1 "S14" "sbos-ops")
    SVC_PORT="${SVC_PORT:-21410}"
    _log "Puerto ClusterIP portman: ${SVC_PORT}"
    echo "${__STEP_OK__} portman_gitlab"

    echo "${__STEP_START__} aplicar_manifest_gitlab"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: gitlab
  namespace: sbos-ops
  labels:
    app: gitlab
    sbos.app/managed-by: bos
spec:
  serviceName: gitlab
  replicas: 1
  selector:
    matchLabels:
      app: gitlab
  template:
    metadata:
      labels:
        app: gitlab
    spec:
      containers:
        - name: gitlab
          image: gitlab/gitlab-ce:17.9.6-ce.0
          ports:
            - containerPort: 80
            - containerPort: 22
          env:
            - name: GITLAB_OMNIBUS_CONFIG
              value: |
                external_url 'http://gitlab.sbos-ops.svc.cluster.local'
                gitlab_rails['initial_root_password'] = ENV['GITLAB_ROOT_PASSWORD'] || 'SBOSgitlab2024!'
                gitlab_rails['time_zone'] = 'UTC'
                puma['worker_processes'] = 0
                sidekiq['max_concurrency'] = 2
                prometheus_monitoring['enable'] = false
                gitlab_exporter['enable'] = false
          resources:
            requests:
              cpu: "50m"
              memory: "1Mi"
            limits:
              cpu: "4000m"
              memory: "6Gi"
          volumeMounts:
            - name: gitlab-data
              mountPath: /var/opt/gitlab
            - name: gitlab-config
              mountPath: /etc/gitlab
            - name: gitlab-logs
              mountPath: /var/log/gitlab
  volumeClaimTemplates:
    - metadata:
        name: gitlab-data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: local-path
        resources:
          requests:
            storage: 50Gi
    - metadata:
        name: gitlab-config
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: local-path
        resources:
          requests:
            storage: 1Gi
    - metadata:
        name: gitlab-logs
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: local-path
        resources:
          requests:
            storage: 5Gi
K8SEOF

    _k apply -f - >> "$FICHA_LOG" 2>&1 <<SVCINNER
apiVersion: v1
kind: Service
metadata:
  name: gitlab
  namespace: sbos-ops
spec:
  selector:
    app: gitlab
  ports:
    - port: ${SVC_PORT}
      targetPort: 80
SVCINNER
    echo "${__STEP_OK__} aplicar_manifest_gitlab"

    echo "${__STEP_START__} esperar_gitlab_ready"
    _wait_ready 180 || { echo "${__STEP_FAIL__} esperar_gitlab_ready: timeout 180s"; return 1; }
    echo "${__STEP_OK__} esperar_gitlab_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_gitlab"
    local r
    r=$(_k get statefulset gitlab -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) || { echo "${__STEP_FAIL__} verificar_gitlab: ${r}/1"; return 1; }
    echo "${__STEP_OK__} verificar_gitlab (${r}/1)"
    return 0
}

ficha_health() {
    local r
    r=$(_k get statefulset gitlab -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: gitlab ${r}/1"
    return 1
}

ficha_post_install() {
    # Evitar post_install_generic (usa namespace default con label errado)
    return 0
}

ficha_repair() {
    _log "ficha_repair: re-aplicando manifests gitlab (idempotente)"
    ficha_install
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_gitlab_ready"
    local ready
    ready=$(_k get statefulset gitlab -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_OK__} test_gitlab_ready (${ready}/1)"
    else
        echo "${__STEP_FAIL__} test_gitlab_ready: ${ready}/1"; ok=1
    fi
    return $ok
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_gitlab"
    _k delete statefulset gitlab -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete service gitlab -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_gitlab"
    return 0
}
