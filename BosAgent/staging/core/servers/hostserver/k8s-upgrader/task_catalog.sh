#!/usr/bin/env bash
# task_catalog.sh — K8s Upgrader task handlers
# Ficha 17 · Order 310 · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/hostserver/k8s-upgrader}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-installer}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    echo "Applying k8s-upgrader RBAC..."

    # Create ServiceAccount
    kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: k8s-upgrader-sa
  namespace: sbos-installer
YAML

    # ClusterRole for node management (cordon, drain) + workload rolling upgrades
    kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8s-upgrader-role
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch", "patch", "update"]
  - apiGroups: [""]
    resources: ["pods", "pods/eviction"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments", "daemonsets", "statefulsets"]
    verbs: ["get", "list", "watch", "patch", "update"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "patch"]
YAML

    # ClusterRoleBinding
    kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: k8s-upgrader-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: k8s-upgrader-role
subjects:
  - kind: ServiceAccount
    name: k8s-upgrader-sa
    namespace: sbos-installer
YAML

    # Label namespace
    kubectl label namespace sbos-installer sbos.io/role=infra --overwrite 2>/dev/null || true

    echo "k8s-upgrader RBAC applied"
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "Verifying k8s-upgrader..."

    if kubectl get serviceaccount k8s-upgrader-sa -n sbos-installer &>/dev/null; then
        echo "  ServiceAccount k8s-upgrader-sa: OK"
    else
        echo "  WARNING: ServiceAccount not found"
    fi

    if kubectl get clusterrole k8s-upgrader-role &>/dev/null; then
        echo "  ClusterRole k8s-upgrader-role: OK"
    else
        echo "  WARNING: ClusterRole not found"
    fi

    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    ficha_install
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    ficha_install
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete clusterrolebinding k8s-upgrader-binding --ignore-not-found 2>/dev/null || true
    kubectl delete clusterrole k8s-upgrader-role --ignore-not-found 2>/dev/null || true
    kubectl delete serviceaccount k8s-upgrader-sa -n sbos-installer --ignore-not-found 2>/dev/null || true
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    if kubectl get serviceaccount k8s-upgrader-sa -n sbos-installer &>/dev/null; then
        echo "k8s-upgrader: HEALTHY"
        echo "${__SBOS__STEP_OK__} health"
    else
        echo "k8s-upgrader: NOT APPLIED"
        echo "${__SBOS__STEP_FAIL__} health"
        return 1
    fi
}

# ── diagnosis ──────────────────────────────────────────────────
ficha_diagnosis() {
    echo "=== k8s-upgrader Diagnosis ==="
    kubectl get serviceaccount k8s-upgrader-sa -n sbos-installer 2>/dev/null || echo "  No SA"
    kubectl get clusterrole k8s-upgrader-role 2>/dev/null || echo "  No role"
    kubectl get clusterrolebinding k8s-upgrader-binding 2>/dev/null || echo "  No binding"
}
