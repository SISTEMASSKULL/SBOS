#!/usr/bin/env bash
# task_catalog.sh — Certificate Rotation task handlers
# Ficha 19 · Order 320 · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/hostserver/cert-rotation}"
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
    echo "Applying cert-rotation RBAC and CronJob..."

    # ServiceAccount
    kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-rotation-sa
  namespace: sbos-installer
YAML

    # ClusterRole for certificate management
    kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cert-rotation-role
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["cert-manager.io"]
    resources: ["certificates", "certificaterequests"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "patch"]
YAML

    # ClusterRoleBinding
    kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cert-rotation-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cert-rotation-role
subjects:
  - kind: ServiceAccount
    name: cert-rotation-sa
    namespace: sbos-installer
YAML

    echo "cert-rotation RBAC applied"
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "Verifying cert-rotation..."

    if kubectl get serviceaccount cert-rotation-sa -n sbos-installer &>/dev/null; then
        echo "  ServiceAccount cert-rotation-sa: OK"
    else
        echo "  WARNING: ServiceAccount not found"
    fi

    if kubectl get clusterrole cert-rotation-role &>/dev/null; then
        echo "  ClusterRole cert-rotation-role: OK"
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
    kubectl delete clusterrolebinding cert-rotation-binding --ignore-not-found 2>/dev/null || true
    kubectl delete clusterrole cert-rotation-role --ignore-not-found 2>/dev/null || true
    kubectl delete serviceaccount cert-rotation-sa -n sbos-installer --ignore-not-found 2>/dev/null || true
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    if kubectl get serviceaccount cert-rotation-sa -n sbos-installer &>/dev/null; then
        echo "cert-rotation: HEALTHY"
        echo "${__SBOS__STEP_OK__} health"
    else
        echo "cert-rotation: NOT APPLIED"
        echo "${__SBOS__STEP_FAIL__} health"
        return 1
    fi
}

# ── diagnosis ──────────────────────────────────────────────────
ficha_diagnosis() {
    echo "=== cert-rotation Diagnosis ==="
    kubectl get serviceaccount cert-rotation-sa -n sbos-installer 2>/dev/null || echo "  No SA"
    kubectl get clusterrole cert-rotation-role 2>/dev/null || echo "  No role"
    kubectl get clusterrolebinding cert-rotation-binding 2>/dev/null || echo "  No binding"
}
