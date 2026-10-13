#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — tempo
# Grafana Tempo 2.7.2 — trazado distribuido OTLP.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/tempo.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-monitor"
TEMPO_VERSION="${TEMPO_VERSION:-2.7.2}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [tempo] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_deploy_ready() {
    local deploy="$1" ns="$2" timeout="${3:-120}" elapsed=0
    while (( elapsed < timeout )); do
        local ready
        ready=$(_k get deployment "$deploy" -n "$ns" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( ready >= 1 )) && return 0
        sleep 5; elapsed=$((elapsed + 5))
    done
    return 1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || { echo "${__STEP_FAIL__} verificar_namespace: $NS no existe"; return 1; }
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")" /data/tempo

    local ready
    ready=$(_k get deployment tempo -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_SKIP__} tempo_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} instalar_tempo_helm"
    if ! helm repo list 2>/dev/null | grep -q "^grafana"; then
        helm repo add grafana https://grafana.github.io/helm-charts >> "$FICHA_LOG" 2>&1
        helm repo update >> "$FICHA_LOG" 2>&1
    fi

    helm upgrade --install tempo grafana/tempo \
        --namespace "$NS" \
        --version "1.14.0" \
        --set tempo.storage.trace.backend=local \
        --set tempo.storage.trace.local.path=/var/tempo \
        --set "resources.requests.cpu=50m" \
        --set "resources.requests.memory=128Mi" \
        --set "resources.limits.cpu=500m" \
        --set "resources.limits.memory=512Mi" \
        --timeout 5m \
        >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} instalar_tempo_helm"

    echo "${__STEP_START__} esperar_tempo_ready"
    _wait_deploy_ready tempo "$NS" 120 || { echo "${__STEP_FAIL__} esperar_tempo_ready: timeout"; return 1; }
    echo "${__STEP_OK__} esperar_tempo_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_tempo"
    local ready
    ready=$(_k get deployment tempo -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( ready >= 1 )) || { echo "${__STEP_FAIL__} verificar_tempo: ${ready}/1"; return 1; }
    echo "${__STEP_OK__} verificar_tempo"
    return 0
}

ficha_health() {
    local ready
    ready=$(_k get deployment tempo -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( ready >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED"
    return 1
}

ficha_repair() {
    _log "ficha_repair: re-aplicando Helm tempo (idempotente via upgrade --install)"
    ficha_install
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_tempo_ready"
    local ready
    ready=$(helm status tempo -n "$NS" --output json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('info',{}).get('status','unknown'))" 2>/dev/null || echo "unknown")
    if [[ "$ready" == "deployed" ]]; then
        echo "${__STEP_OK__} test_tempo_ready (helm status=deployed)"
    else
        echo "${__STEP_FAIL__} test_tempo_ready: helm status=${ready}"; ok=1
    fi

    echo "${__STEP_START__} test_tempo_pod"
    local pods
    pods=$(_k get pods -n "$NS" -l app.kubernetes.io/name=tempo --no-headers 2>/dev/null | grep -c Running || echo "0")
    if (( pods >= 1 )); then
        echo "${__STEP_OK__} test_tempo_pod ($pods Running)"
    else
        echo "${__STEP_FAIL__} test_tempo_pod: 0 pods Running"; ok=1
    fi
    return $ok
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_tempo"
    helm uninstall tempo -n "$NS" >> "$FICHA_LOG" 2>&1 || true
    echo "${__STEP_OK__} eliminar_tempo"
    return 0
}
