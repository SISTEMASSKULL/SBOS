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

# _apply_network_policies: aplica TODAS las NetworkPolicies del namespace sbos-vdi.
# Idempotente: kubectl apply no modifica políticas que ya están en el estado deseado.
# Se llama desde ficha_install Y ficha_repair para garantizar consistencia.
_apply_network_policies() {
    # Ingress en sbos-data: permitir que sbos-vdi alcance PostgreSQL y Redis
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
          port: 6432
        - protocol: TCP
          port: 6379
EOF

    # Egress en sbos-vdi: pods VDI pueden conectar a sbos-data (PostgreSQL/Redis)
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'EOF2'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-to-data
  namespace: sbos-vdi
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-data
      ports:
        - protocol: TCP
          port: 5432
        - protocol: TCP
          port: 6432
        - protocol: TCP
          port: 6379
EOF2

    # Egress intra-vdi: pods VDI pueden conectar entre sí (nextcloud↔onlyoffice, etc.)
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'EOF3'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-intra-vdi-egress
  namespace: sbos-vdi
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - podSelector: {}
EOF3

    # Ingress: Kong gateway puede enviar tráfico a todos los pods VDI
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'EOF4'
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
EOF4

    # Egress: fedora-kde desktop requiere acceso irrestricto a internet.
    # El desktop corporativo es una estación de trabajo — los usuarios necesitan
    # navegar, usar servicios externos y descargar recursos sin restricción.
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'EOF5'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-fedora-kde-internet-egress
  namespace: sbos-vdi
spec:
  podSelector:
    matchLabels:
      app: fedora-kde
  policyTypes: [Egress]
  egress:
    - {}
EOF5
}

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

    echo "${__STEP_START__} network_policies_vdi"
    _apply_network_policies
    echo "${__STEP_OK__} network_policies_vdi"

    # Registrar configuración completada
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

ficha_repair() {
    # Re-aplica todas las NetworkPolicies (idempotente vía kubectl apply).
    # Corrige cualquier drift sin destruir el estado existente.
    echo "${__STEP_START__} reparar_network_policies"
    _apply_network_policies
    echo "${__STEP_OK__} reparar_network_policies"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_marker"
    if ! _k get configmap sbos-vdi-configured -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_marker: VDI no configurado"
        return 1
    fi
    echo "${__STEP_OK__} verificar_marker"

    echo "${__STEP_START__} verificar_internet_policy"
    if _k get networkpolicy allow-fedora-kde-internet-egress -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_OK__} verificar_internet_policy"
    else
        echo "${__STEP_FAIL__} verificar_internet_policy: política ausente"
        return 1
    fi
    return 0
}

ficha_health() {
    if _k get configmap sbos-vdi-configured -n "$NS" > /dev/null 2>&1 \
    && _k get networkpolicy allow-fedora-kde-internet-egress -n "$NS" > /dev/null 2>&1; then
        echo "HEALTHY"
        return 0
    fi
    echo "DEGRADED: VDI sin configurar o NetworkPolicy internet ausente"
    return 1
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_vdi_config"
    _k delete configmap sbos-vdi-configured -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete networkpolicy allow-vdi-to-data -n sbos-data --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete networkpolicy allow-gateway-ingress -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete networkpolicy allow-fedora-kde-internet-egress -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_vdi_config"
    return 0
}
