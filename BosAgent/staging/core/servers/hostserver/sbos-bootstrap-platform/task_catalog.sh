#!/usr/bin/env bash
# task_catalog.sh — SBOS Bootstrap Platform
# Ficha 03 — StorageClass + Core Services
# Orden topológico: 3 (SBOS-049 §3.1)
# R16: sin hardcode de paths

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/hostserver/sbos-bootstrap-platform}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-installer}"
export KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    echo "Checking platform prerequisites..."

    local errors=0

    # Verify K8s cluster is accessible
    if ! kubectl cluster-info --request-timeout=10s &>/dev/null; then
        echo "ERROR: Kubernetes cluster not reachable"
        errors=$((errors + 1))
    else
        echo "K8s cluster: reachable"
    fi

    # Verify at least 1 Ready node
    local ready_nodes
    ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready' || echo "0")
    if (( ready_nodes < 1 )); then
        echo "ERROR: no Ready nodes (found $ready_nodes)"
        errors=$((errors + 1))
    else
        echo "Ready nodes: $ready_nodes"
    fi

    if (( errors > 0 )); then
        echo "Pre-flight FAILED: $errors error(s)"
        return 1
    fi
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    echo "Installing platform components..."

    # Create core namespaces
    echo "Creating core namespaces..."
    for ns in sbos-system sbos-staging sbos-infra cert-manager; do
        kubectl create namespace "$ns" --dry-run=client -o yaml 2>/dev/null | kubectl apply -f - 2>/dev/null
        echo "  namespace: $ns"
    done

    # Create default StorageClass (local-path for single-node)
    echo "Creating default StorageClass..."
    kubectl apply -f - <<'YAML'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: sbos-local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
YAML

    # Create SBOS core ConfigMap
    kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: sbos-platform-info
  namespace: sbos-system
data:
  version: "1.0.0"
  bootstrap_date: "__DATE__"
  cluster_cidr: "10.244.0.0/16"
  service_cidr: "10.96.0.0/12"
YAML
    kubectl patch configmap sbos-platform-info -n sbos-system \
      --type merge -p "{\"data\":{\"bootstrap_date\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}" 2>/dev/null || true

    # Label nodes for SBOS
    kubectl label nodes --all sbos.io/role=control-plane --overwrite 2>/dev/null || true
    kubectl label nodes --all sbos.io/bootstrap=complete --overwrite 2>/dev/null || true

    echo "Platform components installed"
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "Verifying platform components..."

    # Verify StorageClass exists
    if kubectl get storageclass sbos-local-path &>/dev/null; then
        echo "  StorageClass sbos-local-path: OK"
    else
        echo "  WARNING: StorageClass not found"
    fi

    # Verify namespaces
    for ns in sbos-system sbos-staging sbos-infra; do
        if kubectl get namespace "$ns" &>/dev/null; then
            echo "  Namespace $ns: OK"
        else
            echo "  WARNING: Namespace $ns missing"
        fi
    done

    echo "Platform verification complete"
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    echo "Platform update: refreshing core ConfigMaps..."
    kubectl patch configmap sbos-platform-info -n sbos-system \
      --type merge -p "{\"data\":{\"bootstrap_date\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}" 2>/dev/null || true
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    echo "Repairing platform: recreating namespaces if needed..."
    for ns in sbos-system sbos-staging sbos-infra cert-manager; do
        kubectl create namespace "$ns" --dry-run=client -o yaml 2>/dev/null | kubectl apply -f - 2>/dev/null || true
    done
    kubectl apply -f - <<'YAML' 2>/dev/null || true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: sbos-local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
YAML
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    echo "Removing platform components..."
    kubectl delete storageclass sbos-local-path --ignore-not-found 2>/dev/null || true
    kubectl delete configmap sbos-platform-info -n sbos-system --ignore-not-found 2>/dev/null || true
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    if kubectl get storageclass sbos-local-path &>/dev/null && \
       kubectl get namespace sbos-system &>/dev/null; then
        echo "Platform: HEALTHY"
        echo "${__SBOS__STEP_OK__} health"
    else
        echo "Platform: DEGRADED"
        echo "${__SBOS__STEP_FAIL__} health"
        return 1
    fi
}

# ── diagnosis ──────────────────────────────────────────────────
ficha_diagnosis() {
    echo "=== Platform Diagnosis ==="
    kubectl get nodes 2>/dev/null || echo "  No nodes"
    kubectl get namespaces -l sbos.io/managed=true 2>/dev/null || echo "  No managed namespaces"
    kubectl get storageclass 2>/dev/null || echo "  No storage classes"
    kubectl get configmap -n sbos-system 2>/dev/null || echo "  No core configmaps"
}
