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

_wait_tempo_ready() {
    local ns="$1" timeout="${2:-180}"
    # BUG-50: usar kubectl wait --for=condition=Ready que es robusto ante
    # el estado de transición del StatefulSet tras helm upgrade.
    _k wait --for=condition=Ready pod \
        -l app.kubernetes.io/name=tempo \
        -n "$ns" \
        --timeout="${timeout}s" >> "$FICHA_LOG" 2>&1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || { echo "${__STEP_FAIL__} verificar_namespace: $NS no existe"; return 1; }
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")" /data/tempo

    # BUG-49/50: verificar pods Running con label — más robusto que StatefulSet readyReplicas
    local pods
    pods=$(_k get pods -n "$NS" -l app.kubernetes.io/name=tempo \
        --no-headers 2>/dev/null | grep -c Running || echo "0")
    if (( pods >= 1 )); then
        echo "${__STEP_SKIP__} tempo_install: pod tempo ya Running — skip"
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
        --set "tempo.retention=720h" \
        --set "tempo.search.enabled=true" \
        --set "tempo.global_overrides.ingestion_rate_limit_bytes=15000000" \
        --set "resources.requests.cpu=50m" \
        --set "resources.requests.memory=128Mi" \
        --set "resources.limits.cpu=500m" \
        --set "resources.limits.memory=512Mi" \
        --timeout 5m \
        >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} instalar_tempo_helm"

    echo "${__STEP_START__} esperar_tempo_ready"
    _wait_tempo_ready "$NS" 180 || { echo "${__STEP_FAIL__} esperar_tempo_ready: timeout"; return 1; }
    echo "${__STEP_OK__} esperar_tempo_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_tempo"
    local pods
    pods=$(_k get pods -n "$NS" -l app.kubernetes.io/name=tempo \
        --no-headers 2>/dev/null | grep -c Running || echo "0")
    (( pods >= 1 )) || { echo "${__STEP_FAIL__} verificar_tempo: 0 pods Running"; return 1; }
    echo "${__STEP_OK__} verificar_tempo ($pods Running)"
    return 0
}

ficha_health() {
    local pods
    pods=$(_k get pods -n "$NS" -l app.kubernetes.io/name=tempo \
        --no-headers 2>/dev/null | grep -c Running || echo "0")
    (( pods >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: 0 pods Running"
    return 1
}

ficha_post_install() {
    # BUG-50: post_install_generic busca 'app=tempo' en namespace 'default' (incorrecto).
    # Tempo está en sbos-monitor con label app.kubernetes.io/name=tempo.
    # Función vacía explícita para que el framework no llame a post_install_generic.
    return 0
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
