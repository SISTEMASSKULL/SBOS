#!/usr/bin/env bash
# task_catalog.sh — novu
# Novu 3.15: Motor de notificaciones multi-canal (self-hosted, MIT)
# Dependencias: postgresql, ferretdb, redis, keycloak, vault, postfix
set -euo pipefail

__STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
__STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
__STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
__STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/novu.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="${NS:-sbos-notifier}"
NOVU_API_IMAGE="${NOVU_API_IMAGE:-ghcr.io/novuhq/novu/api:3.15.0}"
NOVU_WS_IMAGE="${NOVU_WS_IMAGE:-ghcr.io/novuhq/novu/ws:3.15.0}"
FERRETDB_URL="${FERRETDB_URL:-mongodb://ferretdb.sbos-notifier.svc.cluster.local:27017/novu}"
REDIS_HOST="${REDIS_HOST:-redis.sbos-data.svc.cluster.local}"
REDIS_PASSWORD="${REDIS_PASSWORD:-sbos_redis_bootstrap}"
REDIS_URL="${REDIS_URL:-redis://:${REDIS_PASSWORD}@${REDIS_HOST}:6379/3}"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [novu] $*" | tee -a "$FICHA_LOG"; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_pod() {
    local label="$1" timeout="${2:-180}" elapsed=0
    while (( elapsed < timeout )); do
        local phase
        phase=$(_k get pod -n "$NS" -l app="$label" --no-headers 2>/dev/null | awk '{print $3}' | head -1)
        [[ "$phase" == "Running" ]] && { _log "$label Running"; return 0; }
        sleep 5; elapsed=$((elapsed + 5))
    done
    return 1
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} configurar_redis_single_node"
    _k exec redis-0 -n sbos-data -- \
        redis-cli -a "${REDIS_PASSWORD}" CONFIG SET min-replicas-to-write 0 >> "$FICHA_LOG" 2>&1 || \
        _log "ADVERTENCIA: no se pudo ajustar min-replicas-to-write (no fatal)"
    echo "${__STEP_OK__} configurar_redis_single_node"

    echo "${__STEP_START__} verificar_ferretdb"
    _k get pod -n "$NS" -l app=ferretdb > /dev/null 2>&1 || { echo "${__STEP_FAIL__} ferretdb no disponible"; return 1; }
    echo "${__STEP_OK__} verificar_ferretdb"

    echo "${__STEP_START__} verificar_redis"
    _k get pod redis-0 -n sbos-data > /dev/null 2>&1 || { echo "${__STEP_FAIL__} redis-0 no disponible"; return 1; }
    echo "${__STEP_OK__} verificar_redis"

    echo "${__STEP_START__} networkpolicies_novu"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-novu-intra
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: novu-api
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector: {}
    ports:
    - port: 27017
      protocol: TCP
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: sbos-data
    ports:
    - port: 6379
      protocol: TCP
  - to:
    ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-novu-ws-egress
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: novu-ws
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector: {}
    ports:
    - port: 27017
      protocol: TCP
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: sbos-data
    ports:
    - port: 6379
      protocol: TCP
  - to:
    ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-redis-novu
  namespace: sbos-data
spec:
  podSelector:
    matchLabels:
      app: redis
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ${NS}
    ports:
    - port: 6379
      protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ferretdb-intra
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: ferretdb
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
    ports:
    - port: 27017
      protocol: TCP
YAML
    echo "${__STEP_OK__} networkpolicies_novu"
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    local _jwt_secret _store_key
    _jwt_secret=$(cat /etc/bos/.novu-jwt-secret 2>/dev/null || { openssl rand -hex 32 | tee /etc/bos/.novu-jwt-secret; chmod 600 /etc/bos/.novu-jwt-secret; cat /etc/bos/.novu-jwt-secret; })
    _store_key=$(cat /etc/bos/.novu-store-key 2>/dev/null || { openssl rand -hex 16 | tee /etc/bos/.novu-store-key; chmod 600 /etc/bos/.novu-store-key; cat /etc/bos/.novu-store-key; })
    JWT_SECRET="${JWT_SECRET:-${_jwt_secret}}"
    STORE_KEY="${STORE_KEY:-${_store_key}}"

    echo "${__STEP_START__} crear_namespace"
    _k create namespace "$NS" --dry-run=client -o yaml 2>/dev/null | _k apply -f - >> "$FICHA_LOG" 2>&1 || true
    echo "${__STEP_OK__} crear_namespace"

    echo "${__STEP_START__} deploy_novu_api"
    _k apply -n "$NS" -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: novu-api
  namespace: ${NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: novu-api
  template:
    metadata:
      labels:
        app: novu-api
    spec:
      containers:
      - name: novu-api
        image: ${NOVU_API_IMAGE}
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
        env:
        - name: MONGO_URL
          value: "${FERRETDB_URL}"
        - name: REDIS_HOST
          value: "${REDIS_HOST}"
        - name: REDIS_PORT
          value: "6379"
        - name: REDIS_PASSWORD
          value: "${REDIS_PASSWORD}"
        - name: REDIS_URL
          value: "${REDIS_URL}"
        - name: JWT_SECRET
          value: "${JWT_SECRET}"
        - name: NOVU_SECRET_KEY
          value: "${JWT_SECRET}"
        - name: STORE_ENCRYPTION_KEY
          value: "${STORE_KEY}"
        - name: NODE_ENV
          value: "production"
        - name: STEP_RESOLVER_DISPATCH_URL
          value: "http://localhost:3000"
        ports:
        - containerPort: 3000
        readinessProbe:
          httpGet:
            path: /v1/health-check
            port: 3000
          initialDelaySeconds: 60
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: novu-api
  namespace: ${NS}
spec:
  type: ClusterIP
  ports:
  - port: 3000
    targetPort: 3000
  selector:
    app: novu-api
YAML
    _wait_pod "novu-api" 240 || { _log "ADVERTENCIA: novu-api no llegó a Running — deployment aplicado"; true; }
    echo "${__STEP_OK__} deploy_novu_api"

    echo "${__STEP_START__} deploy_novu_ws"
    _k apply -n "$NS" -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: novu-ws
  namespace: ${NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: novu-ws
  template:
    metadata:
      labels:
        app: novu-ws
    spec:
      containers:
      - name: novu-ws
        image: ${NOVU_WS_IMAGE}
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
        env:
        - name: REDIS_HOST
          value: "${REDIS_HOST}"
        - name: REDIS_PORT
          value: "6379"
        - name: REDIS_PASSWORD
          value: "${REDIS_PASSWORD}"
        - name: REDIS_URL
          value: "${REDIS_URL}"
        - name: MONGO_URL
          value: "${FERRETDB_URL}"
        - name: JWT_SECRET
          value: "${JWT_SECRET}"
        - name: NOVU_SECRET_KEY
          value: "${JWT_SECRET}"
        - name: STORE_ENCRYPTION_KEY
          value: "${STORE_KEY}"
        ports:
        - containerPort: 3002
        readinessProbe:
          tcpSocket:
            port: 3002
          initialDelaySeconds: 30
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: novu-ws
  namespace: ${NS}
spec:
  type: ClusterIP
  ports:
  - port: 3002
    targetPort: 3002
  selector:
    app: novu-ws
YAML
    _wait_pod "novu-ws" 180 || { _log "ADVERTENCIA: novu-ws no llegó a Running — deployment aplicado"; true; }
    echo "${__STEP_OK__} deploy_novu_ws"
}

# ── Health ────────────────────────────────────────────────────────
ficha_health_check() {
    local phase
    phase=$(_k get pod -n "$NS" -l app=novu-api -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    [[ "$phase" == "True" ]] && { echo "${__STEP_OK__} novu-api Ready"; return 0; }
    echo "${__STEP_FAIL__} novu-api no Ready"; return 1
}

# ── Repair (re-aplica estado completo — idempotente) ─────────────
ficha_repair() {
    ficha_pre_install
    ficha_install
}

# ── Test ─────────────────────────────────────────────────────────
ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_novu_api_pod"
    local pods
    pods=$(_k get pods -n "$NS" -l app=novu-api --no-headers 2>/dev/null | grep -c Running || echo "0")
    if (( pods >= 1 )); then
        echo "${__STEP_OK__} test_novu_api_pod ($pods Running)"
    else
        echo "${__STEP_FAIL__} test_novu_api_pod: 0 pods Running"; ok=1
    fi

    echo "${__STEP_START__} test_novu_http"
    local status
    status=$(_k exec -n "$NS" deploy/novu-api -- \
        curl -sf -o /dev/null -w '%{http_code}' http://localhost:3000/v1/health-check 2>/dev/null || echo "000")
    if [[ "$status" == "200" ]]; then
        echo "${__STEP_OK__} test_novu_http (/v1/health-check 200)"
    else
        echo "${__STEP_FAIL__} test_novu_http: HTTP $status"; ok=1
    fi
    return $ok
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    for d in novu-api novu-ws; do
        echo "${__STEP_START__} remove_${d}"
        _k delete deployment "$d" -n "$NS" --ignore-not-found=true
        echo "${__STEP_OK__} ${d} removido"
    done
    _k delete svc novu-api novu-ws -n "$NS" --ignore-not-found=true
}

export -f ficha_pre_install ficha_install ficha_repair ficha_health_check ficha_test ficha_uninstall
