#!/usr/bin/env bash
# task_catalog.sh — SBOS Bootstrap Hardening
# Ficha 16 — NetworkPolicies + RBAC base
# Orden topológico: 16 (SBOS-049 §3.1)
# R16: sin hardcode de paths

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/hostserver/sbos-bootstrap-hardening}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-installer}"
export KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    if ! kubectl cluster-info --request-timeout=5s &>/dev/null; then
        echo "ERROR: K8s cluster not reachable"
        return 1
    fi
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    echo "Applying security hardening..."

    # Restrictive default-deny NetworkPolicy for core namespaces
    kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sbos-default-deny
  namespace: sbos-system
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            sbos.io/role: infra
  egress:
    - to:
      - namespaceSelector: {}
YAML

    # Allow DNS from all pods
    kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: kube-system
spec:
  podSelector:
    matchLabels:
      k8s-app: kube-dns
  policyTypes:
    - Ingress
  ingress:
    - from:
      - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
YAML

    # Create RBAC: sbos-installer ServiceAccount
    kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sbos-installer
  namespace: sbos-installer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: sbos-installer-role
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "secrets", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["roles", "rolebindings"]
    verbs: ["get", "list", "watch", "create", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: sbos-installer-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: sbos-installer-role
subjects:
  - kind: ServiceAccount
    name: sbos-installer
    namespace: sbos-installer
YAML

    # Label namespace for SBOS
    kubectl label namespace sbos-installer sbos.io/role=infra --overwrite 2>/dev/null || true

    echo "Hardening applied"
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "Verifying hardening..."

    if kubectl get networkpolicy sbos-default-deny -n sbos-system &>/dev/null; then
        echo "  NetworkPolicy sbos-default-deny: OK"
    else
        echo "  WARNING: NetworkPolicy not found"
    fi

    if kubectl get serviceaccount sbos-installer -n sbos-installer &>/dev/null; then
        echo "  ServiceAccount sbos-installer: OK"
    else
        echo "  WARNING: ServiceAccount not found"
    fi

    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    echo "Re-applying hardening..."
    ficha_install
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    echo "Repairing hardening..."
    ficha_install
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    echo "Removing hardening..."
    kubectl delete networkpolicy sbos-default-deny -n sbos-system --ignore-not-found 2>/dev/null || true
    kubectl delete networkpolicy allow-dns -n kube-system --ignore-not-found 2>/dev/null || true
    kubectl delete clusterrolebinding sbos-installer-binding --ignore-not-found 2>/dev/null || true
    kubectl delete clusterrole sbos-installer-role --ignore-not-found 2>/dev/null || true
    kubectl delete serviceaccount sbos-installer -n sbos-installer --ignore-not-found 2>/dev/null || true
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    if kubectl get serviceaccount sbos-installer -n sbos-installer &>/dev/null; then
        echo "Hardening: HEALTHY"
        echo "${__SBOS__STEP_OK__} health"
    else
        echo "Hardening: NOT APPLIED"
        echo "${__SBOS__STEP_FAIL__} health"
        return 1
    fi
}

# ── diagnosis ──────────────────────────────────────────────────
ficha_diagnosis() {
    echo "=== Hardening Diagnosis ==="
    kubectl get networkpolicy -A 2>/dev/null || echo "  No network policies"
    kubectl get serviceaccount sbos-installer -n sbos-installer 2>/dev/null || echo "  No installer SA"
    kubectl get clusterrole sbos-installer-role 2>/dev/null || echo "  No installer role"
}
