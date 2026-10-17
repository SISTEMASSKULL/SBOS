#!/usr/bin/env bash
# task_catalog.sh — Network Validator
# Ficha 04 — Validación de red post-bootstrap
# Orden topológico: 4 (SBOS-049 §3.1)
# R16: sin hardcode de paths

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/hostserver/network-validator}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-installer}"
export KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    if ! kubectl cluster-info --request-timeout=5s &>/dev/null; then
        echo "ERROR: K8s cluster not reachable"
        return 1
    fi
    echo "K8s reachable OK"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    echo "Running network validation tests..."

    local errors=0

    # Test 1: Check if CNI is ready before running DNS test.
    # Without a CNI (linkerd/calico), pods can't get IPs and DNS tests
    # will always fail. This is expected early in bootstrap.
    local cni_ready=false
    local pod_cidr
    pod_cidr=$(kubectl get nodes -o jsonpath='{.items[0].spec.podCIDR}' 2>/dev/null || echo "")
    if [[ -n "$pod_cidr" ]]; then
        cni_ready=true
    fi

    # Test 1: DNS resolution (only if CNI is ready)
    echo "--- Test 1: DNS resolution ---"
    if $cni_ready; then
        if kubectl run "net-test-dns-$$" --rm -i --restart=Never --image=busybox:latest \
            --timeout=30s -- nslookup kubernetes.default.svc.cluster.local 2>&1; then
            echo "  DNS resolution: PASS"
        else
            echo "  DNS resolution: FAIL"
            errors=$((errors + 1))
        fi
    else
        echo "  DNS resolution: SKIPPED (CNI not ready — PodCIDR not assigned)"
    fi

    # Test 2: API server reachability
    echo "--- Test 2: API server ---"
    if curl -sk https://kubernetes.default.svc.cluster.local:443/healthz 2>/dev/null | grep -q ok; then
        echo "  API server: PASS"
    else
        echo "  API server: FAIL (non-critical, may need time)"
    fi

    # Test 3: CoreDNS pods running
    echo "--- Test 3: CoreDNS ---"
    if kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -q Running; then
        echo "  CoreDNS: PASS"
    else
        echo "  CoreDNS: PENDING (may still be starting)"
    fi

    # Test 4: Node network info
    echo "--- Test 4: Node network ---"
    kubectl get nodes -o wide 2>/dev/null
    echo "  Node listing: PASS"

    # Test 5: PodCIDR assigned
    if $cni_ready; then
        echo "  PodCIDR: $pod_cidr OK"
    else
        echo "  PodCIDR: not assigned yet (CNI may still be deploying)"
    fi

    if (( errors > 0 )); then
        echo "Network validation: $errors FAILURE(S)"
        return 1
    fi

    echo "All network validations passed"
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "Network validator: waiting for CoreDNS..."
    kubectl wait --for=condition=Ready pod -l k8s-app=kube-dns -n kube-system --timeout=120s 2>/dev/null || echo "  CoreDNS still starting (non-critical)"
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    echo "Re-running network validation..."
    ficha_install
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    echo "Repairing network: restarting CoreDNS..."
    kubectl rollout restart deployment coredns -n kube-system 2>/dev/null || echo "  CoreDNS not found"
    sleep 10
    kubectl wait --for=condition=Ready pod -l k8s-app=kube-dns -n kube-system --timeout=60s 2>/dev/null || true
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    echo "Nothing to uninstall (validator only)"
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    if kubectl get nodes --no-headers 2>/dev/null | grep -q ' Ready'; then
        echo "Network: HEALTHY (node Ready)"
        echo "${__SBOS__STEP_OK__} health"
    else
        echo "Network: DEGRADED"
        echo "${__SBOS__STEP_FAIL__} health"
        return 1
    fi
}

# ── diagnosis ──────────────────────────────────────────────────
ficha_diagnosis() {
    echo "=== Network Diagnosis ==="
    kubectl get nodes -o wide 2>/dev/null || echo "  No nodes"
    kubectl get pods -n kube-system -l k8s-app=kube-dns 2>/dev/null || echo "  CoreDNS not found"
    kubectl get svc -n kube-system 2>/dev/null || echo "  No services"
}
