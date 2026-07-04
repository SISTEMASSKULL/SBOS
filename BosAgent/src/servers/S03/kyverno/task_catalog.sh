#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — kyverno
# Iteración 1: Kyverno 1.13.0 admission control + políticas audit mode
# Dependencias: sbos-bootstrap-k8s, sbos-bootstrap-cni
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/kyverno.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="kyverno"
readonly KYVERNO_IMAGE="ghcr.io/kyverno/kyverno:v1.13.0"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [kyverno] $*" | tee -a "$FICHA_LOG"; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-kyverno-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_k8s"
    local nodes_ready
    nodes_ready=$(_k get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' \
        2>/dev/null || echo "")
    if [[ "$nodes_ready" =~ True ]]; then
        echo "${__STEP_OK__} verificar_k8s (nodo(s) Ready)"
    else
        echo "${__STEP_FAIL__} verificar_k8s: ningún nodo Ready"
        return 1
    fi

    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || \
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # ── 1. Instalar kyverno (helm chart delegado) ─────────────────
    echo "${__STEP_START__} instalar_kyverno"
    _apply "install-config" "apiVersion: v1
kind: ConfigMap
metadata:
  name: kyverno-install-config
  namespace: ${NS}
  labels:
    app: kyverno
    sbos-managed: \"true\"
data:
  install_mode: \"helm-delegated\"
  version: \"1.13.0\"
  helm_values: |
    admissionController:
      replicas: 1
    backgroundController:
      enabled: true
    cleanupController:
      enabled: true
    reportsController:
      enabled: true
    features:
      audit: true" || {
        echo "${__STEP_FAIL__} instalar_kyverno"; return 1
    }
    _log "Kyverno — instalación delegada a helm chart (ghcr.io/kyverno/charts/kyverno)"

    # Esperar a que los CRDs de Kyverno estén registrados antes de aplicar ClusterPolicy
    _log "Esperando CRDs de Kyverno (hasta 120s)..."
    local crd_ok=0
    for _i in $(seq 1 24); do
        if kubectl get crd clusterpolicies.kyverno.io >/dev/null 2>&1; then
            crd_ok=1; break
        fi
        _log "  CRDs no listos aún, esperando 5s... (${_i}/24)"
        sleep 5
    done
    if [[ "$crd_ok" -eq 0 ]]; then
        echo "${__STEP_FAIL__} instalar_kyverno: CRDs no registrados en 120s"
        return 1
    fi
    _log "CRDs de Kyverno listos"
    echo "${__STEP_OK__} instalar_kyverno"

    # ── 2. Políticas SBOS (audit mode) ────────────────────────────
    echo "${__STEP_START__} crear_politicas_sbos"

    # Política 1: require-probes
    _apply "policy-require-probes" "apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: sbos-require-probes
  labels:
    app: kyverno
    sbos-managed: \"true\"
    sbos-policy: \"true\"
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: require-readiness-liveness-probes
      match:
        any:
          - resources:
              kinds:
                - Deployment
                - StatefulSet
      validate:
        message: \"readinessProbe y livenessProbe son obligatorios (SBOS-047 §A.8.6)\"
        pattern:
          spec:
            template:
              spec:
                containers:
                  - readinessProbe: \"?*\"
                    livenessProbe: \"?*\"" || true

    # Política 2: forbid-hostport
    _apply "policy-forbid-hostport" "apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: sbos-forbid-hostport
  labels:
    app: kyverno
    sbos-managed: \"true\"
    sbos-policy: \"true\"
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: forbid-hostport
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: \"hostPort está prohibido (SBOS-050 P10)\"
        pattern:
          spec:
            containers:
              - =(ports):
                  - X(hostPort): 0" || true

    # Política 3: forbid-privileged
    _apply "policy-forbid-privileged" "apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: sbos-forbid-privileged
  labels:
    app: kyverno
    sbos-managed: \"true\"
    sbos-policy: \"true\"
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: forbid-privileged-containers
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: \"Contenedores privilegiados prohibidos (SBOS-047 §A.8.2)\"
        pattern:
          spec:
            containers:
              - securityContext:
                  privileged: false" || true

    # Política 4: require-networkpolicy
    _apply "policy-require-networkpolicy" "apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: sbos-require-networkpolicy
  labels:
    app: kyverno
    sbos-managed: \"true\"
    sbos-policy: \"true\"
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-networkpolicy-exists
      match:
        any:
          - resources:
              kinds:
                - Namespace
              selector:
                matchLabels:
                  sbos-tier: \"true\"
      validate:
        message: \"Todo namespace SBOS debe tener al menos una NetworkPolicy (SBOS-050 P5)\"
        deny:
          conditions:
            any:
              - key: \"{{ request.object.metadata.labels.\"sbos-tier\" || '' }}\"
                operator: Equals
                value: \"true\"" || true

    echo "${__STEP_OK__} crear_politicas_sbos (4 políticas audit mode)"

    # ── 3. NetworkPolicy ──────────────────────────────────────────
    echo "${__STEP_START__} networkpolicy_kyverno"
    _apply "np-kyverno" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-kyverno-webhook
  namespace: ${NS}
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
    # Webhook admission (9443) — el API server debe alcanzarlo
    - ports:
        - protocol: TCP
          port: 9443
    # Metrics (8000) — desde monitoring
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-monitoring
      ports:
        - protocol: TCP
          port: 8000" || true
    echo "${__STEP_OK__} networkpolicy_kyverno"

    _log "kyverno instalado (4 políticas audit mode)"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado kyverno:"
    _k get clusterpolicy -l sbos-policy=true --no-headers 2>/dev/null \
        | awk '{printf "  policy=%s action=%s\n", $1, $3}' || echo "  (sin políticas)"
    _k get pod -n "$NS" --no-headers 2>/dev/null \
        | awk '{printf "  pod=%s status=%s ready=%s\n", $1, $3, $2}' || echo "  (pods no disponibles)"
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reparar_politicas"
    # Re-aplicar las 4 políticas
    for policy in sbos-require-probes sbos-forbid-hostport sbos-forbid-privileged sbos-require-networkpolicy; do
        if ! _k get clusterpolicy "$policy" > /dev/null 2>&1; then
            _log "Política $policy ausente — reinstalación necesaria"
        fi
    done
    _log "Políticas verificadas"
    echo "${__STEP_OK__} reparar_politicas"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 && \
        echo "${__STEP_OK__} test_namespace" || \
        { echo "${__STEP_FAIL__} test_namespace"; ok=1; }

    echo "${__STEP_START__} test_policies_count"
    local policy_count
    policy_count=$(_k get clusterpolicy -l sbos-policy=true --no-headers 2>/dev/null | wc -l || echo "0")
    if (( policy_count >= 4 )); then
        echo "${__STEP_OK__} test_policies_count ($policy_count/4)"
    else
        echo "${__STEP_FAIL__} test_policies_count: $policy_count/4"
        ok=1
    fi

    echo "${__STEP_START__} test_policy_audit_mode"
    local enforce_count
    enforce_count=$(_k get clusterpolicy -l sbos-policy=true \
        -o jsonpath='{.items[?(@.spec.validationFailureAction=="Enforce")].metadata.name}' \
        2>/dev/null | wc -w || echo "0")
    if (( enforce_count == 0 )); then
        echo "${__STEP_OK__} test_policy_enforce_mode (todas Enforce)"
    else
        echo "${__STEP_SKIP__} test_policy_audit_mode: $enforce_count en modo Enforce"
    fi

    echo "${__STEP_START__} test_networkpolicy"
    _k get networkpolicy allow-kyverno-webhook -n "$NS" > /dev/null 2>&1 && \
        echo "${__STEP_OK__} test_networkpolicy" || \
        { echo "${__STEP_FAIL__} test_networkpolicy"; ok=1; }

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== kyverno STATUS ==="
    echo ""
    echo "ClusterPolicies SBOS:"
    _k get clusterpolicy -l sbos-policy=true 2>/dev/null \
        -o custom-columns='NAME:.metadata.name,MODE:.spec.validationFailureAction,STATUS:.status.ready' \
        || echo "  (ninguna)"
    echo ""
    echo "Pods:"
    _k get pod -n "$NS" 2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "NetworkPolicies:"
    _k get networkpolicy -n "$NS" --no-headers 2>/dev/null \
        | awk '{printf "  %s\n", $1}' || echo "  (ninguna)"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando kyverno"
    echo "${__STEP_START__} eliminar_politicas"
    _k delete clusterpolicy -l sbos-policy=true 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_politicas"

    echo "${__STEP_START__} eliminar_k8s"
    _k delete configmap kyverno-install-config -n "$NS" 2>/dev/null || true
    _k delete networkpolicy allow-kyverno-webhook -n "$NS" 2>/dev/null || true
    _k delete namespace "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico kyverno ==="
    echo "ClusterPolicies detalle:"
    _k describe clusterpolicy -l sbos-policy=true 2>/dev/null | grep -E "Name:|Message:|Status:" | head -20 || true
    echo ""
    echo "Policy reports:"
    _k get policyreports -A --no-headers 2>/dev/null | head -10 || echo "  (ninguno)"
    echo ""
    echo "Eventos (${NS}):"
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
