#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — besu-qbft  Iteración 2 (K8s StatefulSet)
# Hyperledger Besu 24.12.0 · QBFT 1 validador · Chain ID 1337
# Namespace: sbos-chain
# Puertos ClusterIP: 8545 RPC-HTTP, 8546 WS, 30303 P2P
# Idempotente: checks en eth_chainId + StatefulSet Ready antes de instalar.
# Iteración 3 (pendiente): 4 validadores + TLS + Vault PKCS#11
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/besu-qbft.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-chain"
APP="besu-qbft"

readonly CHAIN_ID="1337"
readonly VALIDATOR_ADDR="0x3caea8b153a7e5522630ad8ab59e8194d6f3cc92"
readonly COINBASE="0xD2Fe542a74c9A7C45d52FcBB62F6b61032F4420A"
readonly BOS_KEY_BACKUP="/etc/bos/besu-validator.key"
readonly BOS_GENESIS_BACKUP="/etc/bos/besu-genesis.json"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [besu-qbft] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_rpc_from_pod() {
    local method="$1" params="${2:-[]}"
    _k exec -n "$NS" "${APP}-0" -c besu -- \
        curl -s --max-time 8 -X POST -H 'Content-Type: application/json' \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":${params},\"id\":1}" \
        "http://127.0.0.1:8545" 2>/dev/null || echo '{}'
}

_rpc_chain_id() {
    _rpc_from_pod "eth_chainId" "[]" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    v = d.get('result', '')
    print(int(v, 16) if isinstance(v, str) and v.startswith('0x') else '')
except:
    print('')
" 2>/dev/null || echo ""
}

_pod_ready() {
    local r
    r=$(_k get statefulset "$APP" -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 ))
}

_wait_pod_ready() {
    local t="${1:-300}" e=0
    while (( e < t )); do
        _pod_ready && return 0
        sleep 5; e=$((e+5)); (( e % 30 == 0 )) && _log "Esperando pod besu-qbft... ${e}/${t}s"
    done
    return 1
}

# ── Pre-install ──────────────────────────────────────────────────────
ficha_pre_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    echo "${__STEP_START__} verificar_clave_validador"
    [[ -f "$BOS_KEY_BACKUP" ]] || {
        echo "${__STEP_FAIL__} verificar_clave_validador: $BOS_KEY_BACKUP no existe"
        return 1
    }
    echo "${__STEP_OK__} verificar_clave_validador"
    return 0
}

# ── Install ──────────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # Idempotencia: pod Ready + RPC responde chain_id correcto → skip
    if _pod_ready; then
        local cid
        cid=$(_rpc_chain_id)
        if [[ "$cid" == "$CHAIN_ID" ]]; then
            _log "Besu QBFT operativo (pod Ready, chain_id=$cid) — skip"
            return 0
        fi
    fi

    echo "${__STEP_START__} crear_namespace"
    _k create namespace "$NS" --dry-run=client -o yaml | _k apply -f - >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} crear_namespace"

    echo "${__STEP_START__} crear_secret_validator_key"
    local key_hex key_raw
    key_hex=$(cat "$BOS_KEY_BACKUP" | tr -d '[:space:]')
    key_raw="${key_hex#0x}"
    _k create secret generic besu-validator-key -n "$NS" \
        --from-literal=key="$key_raw" \
        --dry-run=client -o yaml | _k apply -f - >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} crear_secret_validator_key"

    echo "${__STEP_START__} crear_configmap_genesis"
    local genesis_src="${BASH_SOURCE[0]%/*}/resources/genesis.json"
    [[ -f "$genesis_src" ]] || genesis_src="$BOS_GENESIS_BACKUP"
    _k create configmap besu-genesis -n "$NS" \
        --from-file=genesis.json="$genesis_src" \
        --dry-run=client -o yaml | _k apply -f - >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} crear_configmap_genesis"

    echo "${__STEP_START__} crear_pv_hostpath"
    local data_dir="/data/besu-qbft"
    mkdir -p "$data_dir"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<K8SEOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-besu-qbft-data
spec:
  capacity:
    storage: 10Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  volumeMode: Filesystem
  local:
    path: ${data_dir}
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: Exists
K8SEOF
    echo "${__STEP_OK__} crear_pv_hostpath"

    echo "${__STEP_START__} desplegar_recursos_k8s"
    _k apply -n "$NS" -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: v1
kind: Service
metadata:
  name: besu-qbft
  namespace: sbos-chain
  labels:
    app: besu-qbft
spec:
  type: ClusterIP
  selector:
    app: besu-qbft
  ports:
  - name: rpc-http
    port: 8545
    targetPort: 8545
  - name: rpc-ws
    port: 8546
    targetPort: 8546
  - name: p2p
    port: 30303
    targetPort: 30303
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: besu-data
  namespace: sbos-chain
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  volumeName: pv-besu-qbft-data
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: besu-qbft
  namespace: sbos-chain
  labels:
    app: besu-qbft
spec:
  serviceName: besu-qbft
  replicas: 1
  selector:
    matchLabels:
      app: besu-qbft
  template:
    metadata:
      labels:
        app: besu-qbft
        linkerd.io/inject: disabled
    spec:
      securityContext:
        runAsUser: 1000
        fsGroup: 1000
      initContainers:
      - name: init-key
        image: busybox:1.36
        command:
        - sh
        - -c
        - |
          mkdir -p /data/keys
          cp /secrets/key /data/keys/key
          chmod 600 /data/keys/key
        volumeMounts:
        - name: data
          mountPath: /data
        - name: validator-key
          mountPath: /secrets
      containers:
      - name: besu
        image: docker.io/hyperledger/besu:24.12.0
        args:
        - --genesis-file=/genesis/genesis.json
        - --data-path=/data/besu
        - --host-allowlist=*
        - --rpc-http-enabled
        - --rpc-http-host=0.0.0.0
        - --rpc-http-port=8545
        - --rpc-http-api=ETH,NET,WEB3,ADMIN,DEBUG,TXPOOL,QBFT
        - --rpc-http-cors-origins=all
        - --rpc-ws-enabled
        - --rpc-ws-host=0.0.0.0
        - --rpc-ws-port=8546
        - --rpc-ws-api=ETH,NET,WEB3,QBFT
        - --p2p-host=0.0.0.0
        - --p2p-port=30303
        - --node-private-key-file=/data/keys/key
        - --miner-enabled
        - --miner-coinbase=0xD2Fe542a74c9A7C45d52FcBB62F6b61032F4420A
        - --discovery-enabled=false
        - --min-block-occupancy-ratio=0.0
        - --logging=INFO
        ports:
        - containerPort: 8545
        - containerPort: 8546
        - containerPort: 30303
        resources:
          requests:
            cpu: 200m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        readinessProbe:
          httpGet:
            path: /liveness
            port: 8545
          initialDelaySeconds: 15
          periodSeconds: 10
          failureThreshold: 6
        livenessProbe:
          httpGet:
            path: /liveness
            port: 8545
          initialDelaySeconds: 30
          periodSeconds: 15
          failureThreshold: 3
        volumeMounts:
        - name: data
          mountPath: /data
        - name: genesis
          mountPath: /genesis
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: besu-data
      - name: validator-key
        secret:
          secretName: besu-validator-key
          defaultMode: 0600
      - name: genesis
        configMap:
          name: besu-genesis
K8SEOF
    echo "${__STEP_OK__} desplegar_recursos_k8s"

    echo "${__STEP_START__} networkpolicy_chain"
    _k apply -n "$NS" -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-sbos-to-besu
  namespace: sbos-chain
spec:
  podSelector:
    matchLabels:
      app: besu-qbft
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: sbos-security
    ports:
    - port: 8545
    - port: 8546
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: sbos-chain
K8SEOF
    echo "${__STEP_OK__} networkpolicy_chain"

    echo "${__STEP_START__} esperar_besu_ready"
    _wait_pod_ready 300 || { echo "${__STEP_FAIL__} esperar_besu_ready: timeout 300s"; return 1; }
    echo "${__STEP_OK__} esperar_besu_ready"

    echo "${__STEP_START__} verificar_chain_id"
    local cid
    cid=$(_rpc_chain_id 2>/dev/null || echo "")
    if [[ "$cid" == "$CHAIN_ID" ]]; then
        _log "Besu QBFT operativo: chain_id=$cid, validator=$VALIDATOR_ADDR"
        echo "${__STEP_OK__} verificar_chain_id ($cid)"
    else
        _log "ADVERTENCIA: chain_id='$cid' (esperado $CHAIN_ID) — nodo puede necesitar más tiempo"
        echo "${__STEP_SKIP__} verificar_chain_id: ficha_repair convergirá"
    fi

    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_besu_ready"
    _pod_ready || { echo "${__STEP_FAIL__} verificar_besu_ready: StatefulSet no Ready"; return 1; }
    echo "${__STEP_OK__} verificar_besu_ready"
    return 0
}

ficha_health() {
    local r
    r=$(_k get statefulset "$APP" -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: besu-qbft StatefulSet readyReplicas=${r}"
    return 1
}

ficha_post_install() {
    local cid height
    cid=$(_rpc_chain_id 2>/dev/null || echo "?")
    height=$(_rpc_from_pod "eth_blockNumber" "[]" 2>/dev/null | \
        python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    r=d.get('result','?')
    print(int(r,16) if isinstance(r,str) and r.startswith('0x') else r)
except:
    print('?')
" 2>/dev/null || echo "?")
    _log "=== Besu QBFT estado ==="
    _log "  chain_id:  $cid"
    _log "  altura:    $height"
    _log "  validator: $VALIDATOR_ADDR"
    _log "  namespace: $NS"
    return 0
}

ficha_repair() {
    _log "ficha_repair: verificando estado Besu QBFT K8s"
    if _pod_ready; then
        local cid
        cid=$(_rpc_chain_id 2>/dev/null || echo "")
        if [[ "$cid" == "$CHAIN_ID" ]]; then
            _log "Todo OK — chain_id=$cid, pod Ready → noop"
            return 0
        fi
        _log "Pod Ready pero RPC inaccesible — rollout restart"
        _k rollout restart statefulset/"$APP" -n "$NS" >> "$FICHA_LOG" 2>&1 || true
        _wait_pod_ready 180 || { _log "ERROR: timeout tras rollout restart"; return 1; }
    else
        _log "Pod no Ready — re-aplicando recursos"
        ficha_install
    fi
    return 0
}

ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_pod_ready"
    if _pod_ready; then
        echo "${__STEP_OK__} test_pod_ready"
    else
        echo "${__STEP_FAIL__} test_pod_ready"; ok=1
    fi

    echo "${__STEP_START__} test_chain_id"
    local cid
    cid=$(_rpc_chain_id 2>/dev/null || echo "")
    if [[ "$cid" == "$CHAIN_ID" ]]; then
        echo "${__STEP_OK__} test_chain_id ($cid)"
    else
        echo "${__STEP_FAIL__} test_chain_id: esperado=$CHAIN_ID real='$cid'"; ok=1
    fi

    return $ok
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_besu_qbft"
    _k delete statefulset "$APP" -n "$NS" >> "$FICHA_LOG" 2>&1 || true
    _k delete service "$APP" -n "$NS" >> "$FICHA_LOG" 2>&1 || true
    _k delete pvc besu-data -n "$NS" >> "$FICHA_LOG" 2>&1 || true
    _k delete configmap besu-genesis -n "$NS" >> "$FICHA_LOG" 2>&1 || true
    _k delete secret besu-validator-key -n "$NS" >> "$FICHA_LOG" 2>&1 || true
    echo "${__STEP_OK__} eliminar_besu_qbft"
}
