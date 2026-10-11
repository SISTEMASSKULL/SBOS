#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — sbos-vdi-config
# Configura Kong, Keycloak y NetworkPolicies para el producto VDI completo.
# Se ejecuta DESPUÉS de que nextcloud, onlyoffice, guacamole y fedora-kde
# están todos instalados.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-vdi-config.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-vdi"
DOMAIN="${BOS_DOMAIN:-sbos.app}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-vdi-config] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

ficha_pre_install() {
    echo "${__STEP_START__} verificar_vdi_pods"
    local pods_ready=0
    for app in nextcloud guacamole onlyoffice; do
        local ready
        ready=$(_k get deployment "$app" -n "$NS" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        if (( ready > 0 )); then
            (( pods_ready++ ))
        else
            _log "ADVERTENCIA: $app no está Ready"
        fi
    done
    if (( pods_ready < 2 )); then
        echo "${__STEP_FAIL__} verificar_vdi_pods: solo ${pods_ready}/3 apps VDI listas"
        return 1
    fi
    echo "${__STEP_OK__} verificar_vdi_pods (${pods_ready}/3 Ready)"
    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # Idempotencia
    if _k get configmap sbos-vdi-configured -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_SKIP__} sbos_vdi_config: ya configurado — skip"
        return 0
    fi

    # ── NetworkPolicies para acceso VDI → data ─────────────────────
    echo "${__STEP_START__} network_policies_vdi"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-vdi-to-data
  namespace: sbos-data
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-vdi
      ports:
        - protocol: TCP
          port: 5432
        - protocol: TCP
          port: 6379
EOF
    echo "${__STEP_OK__} network_policies_vdi"

    # ── NetworkPolicy: Kong → VDI ──────────────────────────────────
    echo "${__STEP_START__} network_policy_kong_vdi"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-gateway-ingress
  namespace: sbos-vdi
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-gateway
EOF
    echo "${__STEP_OK__} network_policy_kong_vdi"

    # ── Registrar configuración completada ─────────────────────────
    echo "${__STEP_START__} registrar_vdi_configurado"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    _k create configmap sbos-vdi-configured \
        -n "$NS" \
        --from-literal="configured_at=${ts}" \
        --from-literal="domain=${DOMAIN}" \
        >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} registrar_vdi_configurado (ts=${ts})"

    _log "VDI configurado: NetworkPolicies ✓"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_marker"
    if ! _k get configmap sbos-vdi-configured -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_marker: VDI no configurado"
        return 1
    fi
    echo "${__STEP_OK__} verificar_marker"
    return 0
}

ficha_health() {
    if _k get configmap sbos-vdi-configured -n "$NS" > /dev/null 2>&1; then
        echo "HEALTHY"
        return 0
    fi
    echo "DEGRADED: VDI sin configurar"
    return 1
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_vdi_config"
    _k delete configmap sbos-vdi-configured -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete networkpolicy allow-vdi-to-data -n sbos-data --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete networkpolicy allow-gateway-ingress -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_vdi_config"
    return 0
}
