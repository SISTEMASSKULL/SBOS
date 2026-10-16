#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — cypht
# Imagen: sailfishsoftware/cypht:latest
# Namespace: sbos-comms
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/cypht.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-comms"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [cypht] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_ready() {
    local t="${1:-180}" e=0
    while (( e < t )); do
        local r
        r=$(_k get deployment cypht -n "$NS" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5))
        (( e % 30 == 0 )) && _log "Esperando cypht Ready... ${e}/${t}s"
    done; return 1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || {
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
        _log "Namespace $NS creado"
    }
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    local r
    r=$(_k get deployment cypht -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r >= 1 )); then
        echo "${__STEP_SKIP__} cypht_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} aplicar_manifest_cypht"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cypht
  namespace: sbos-comms
  labels:
    app: cypht
    sbos.app/managed-by: bos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cypht
  template:
    metadata:
      labels:
        app: cypht
    spec:
      containers:
        - name: cypht
          image: cypht/cypht:latest
          ports:
            - containerPort: 80
          env:
            - name: IMAP_SERVER
              value: "mailserver.sbos-comms.svc.cluster.local"
            - name: IMAP_PORT
              value: "993"
            - name: SMTP_SERVER
              value: "mailserver.sbos-comms.svc.cluster.local"
            - name: SMTP_PORT
              value: "587"
            - name: DB_CONNECTION_TYPE
              value: "pgsql"
            - name: DB_HOST
              value: "postgresql.sbos-data.svc.cluster.local"
            - name: DB_PORT
              value: "5432"
            - name: DB_USER
              value: "postgres"
            - name: DB_PASS
              value: "sbos_bootstrap_pass"
            - name: DB_NAME
              value: "cypht_db"
            - name: CYPHT_SESSION_TYPE
              value: "DB"
          resources:
            requests:
              cpu: "100m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
K8SEOF
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'SVCINNER'
apiVersion: v1
kind: Service
metadata:
  name: cypht
  namespace: sbos-comms
spec:
  selector:
    app: cypht
  ports:
    - port: 80
      targetPort: 80
SVCINNER
    echo "${__STEP_OK__} aplicar_manifest_cypht"

    echo "${__STEP_START__} esperar_cypht_ready"
    _wait_ready 180 || { echo "${__STEP_FAIL__} esperar_cypht_ready: timeout 180s"; return 1; }
    echo "${__STEP_OK__} esperar_cypht_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_cypht"
    local r
    r=$(_k get deployment cypht -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) || { echo "${__STEP_FAIL__} verificar_cypht: ${r}/1"; return 1; }
    echo "${__STEP_OK__} verificar_cypht (${r}/1)"
    return 0
}

ficha_health() {
    local r
    r=$(_k get deployment cypht -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: cypht ${r}/1"
    return 1
}

ficha_post_install() {
    local kc_ns="sbos-security"
    local secret_name="sbos-cypht-oidc"
    local realm="${TENANT_ID:-skull}"

    echo "${__STEP_START__} configurar_oidc_cypht"
    if ! _k get secret -n "$kc_ns" "$secret_name" &>/dev/null; then
        echo "${__STEP_SKIP__} configurar_oidc_cypht: secret $secret_name no disponible"
        return 0
    fi
    local client_id client_secret issuer
    client_id=$(_k get secret -n "$kc_ns" "$secret_name" -o jsonpath='{.data.client_id}' 2>/dev/null | base64 -d || echo "")
    client_secret=$(_k get secret -n "$kc_ns" "$secret_name" -o jsonpath='{.data.client_secret}' 2>/dev/null | base64 -d || echo "")
    issuer=$(_k get secret -n "$kc_ns" "$secret_name" -o jsonpath='{.data.issuer}' 2>/dev/null | base64 -d || echo "")
    if [[ -z "$client_id" || -z "$client_secret" ]]; then
        echo "${__STEP_SKIP__} configurar_oidc_cypht: credenciales no disponibles"
        return 0
    fi
    local cur
    cur=$(_k get deployment cypht -n "$NS" \
        -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="OIDC_CLIENT_ID")].value}' 2>/dev/null || echo "")
    if [[ "$cur" == "$client_id" ]]; then
        echo "${__STEP_SKIP__} configurar_oidc_cypht: ya configurado"
        return 0
    fi
    _k patch deployment cypht -n "$NS" --type=json -p="[
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"OIDC_CLIENT_ID\",\"value\":\"${client_id}\"}},
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"OIDC_CLIENT_SECRET\",\"value\":\"${client_secret}\"}},
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"OIDC_DISCOVERY_URL\",\"value\":\"${issuer}/.well-known/openid-configuration\"}}
    ]" >> "$FICHA_LOG" 2>&1 && \
        _log "  OIDC Keycloak configurado en cypht" || \
        _log "  ADVERTENCIA: no se pudo configurar OIDC en cypht"
    echo "${__STEP_OK__} configurar_oidc_cypht"
    return 0
}

ficha_repair() {
    _log "ficha_repair: re-aplicando manifests cypht (kubectl apply idempotente)"
    ficha_install
    ficha_post_install 2>/dev/null || true
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_pod_running"
    local r
    r=$(_k get deployment cypht -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r >= 1 )); then
        echo "${__STEP_OK__} test_pod_running (${r}/1)"
    else
        echo "${__STEP_FAIL__} test_pod_running: ${r}/1"
        ok=1
    fi

    echo "${__STEP_START__} test_http_responde"
    local clusterip
    clusterip=$(_k get service cypht -n "$NS" \
        -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
    if [[ -n "$clusterip" ]]; then
        local code
        code=$(curl -sk --max-time 5 -o /dev/null -w "%{http_code}" "http://${clusterip}/" 2>/dev/null || echo "000")
        if [[ "$code" == "200" || "$code" == "302" ]]; then
            echo "${__STEP_OK__} test_http_responde (HTTP ${code})"
        else
            echo "${__STEP_FAIL__} test_http_responde: HTTP ${code}"
            ok=1
        fi
    else
        echo "${__STEP_FAIL__} test_http_responde: ClusterIP no encontrada"
        ok=1
    fi
    return $ok
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_cypht"
    _k delete deployment cypht -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete service cypht -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_cypht"
    return 0
}
