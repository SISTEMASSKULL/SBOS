#!/usr/bin/env bash
# task_catalog.sh — sbos-repair
# Unified multi-layer repair execution engine (D1)
set -euo pipefail
FICHA="sbos-repair"

echo "__SBOS__STEP_START__ repair-os-ubuntu"
    if command -v bosctl &>/dev/null; then
        bosctl repair --target=os 2>&1 || true
    else
        echo "=== Fase 1/4: Ubuntu OS Repair ==="
        echo "  Running dpkg --audit..."
        dpkg --audit 2>&1 || true
        echo "  Running apt-get --fix-broken..."
        apt-get --fix-broken install -y -q 2>&1 || true
        echo "  Running systemctl reset-failed..."
        systemctl reset-failed 2>&1 || true
    fi
echo "__SBOS__STEP_OK__ repair-os-ubuntu"

echo "__SBOS__STEP_START__ repair-k8s-node"
    if command -v bosctl &>/dev/null; then
        bosctl repair --target=k8s 2>&1 || true
    elif command -v kubectl &>/dev/null; then
        NODE=$(hostname)
        echo "=== Fase 2/4: K8s Node Repair (node=$NODE) ==="
        kubectl cordon "$NODE" 2>&1 || true
        kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data \
            --grace-period=30 --timeout=120s --force 2>&1 || true
        systemctl restart kubelet 2>&1 || true
        sleep 5
        kubectl uncordon "$NODE" 2>&1 || true
    else
        echo "  kubectl not available — skipping K8s repair"
    fi
echo "__SBOS__STEP_OK__ repair-k8s-node"

echo "__SBOS__STEP_START__ repair-bos-fichas"
    if command -v bosctl &>/dev/null; then
        bosctl repair --target=bos 2>&1 || true
    else
        echo "=== Fase 3/4: BOS Ficha Reconciliation ==="
        if [ -f /etc/bos/.sbos_state.json ]; then
            echo "  State file exists — manual reconciliation skipped"
        else
            echo "  State file not found — nothing to reconcile"
        fi
    fi
echo "__SBOS__STEP_OK__ repair-bos-fichas"

echo "__SBOS__STEP_START__ repair-verify"
    echo "=== Fase 4/4: Post-Repair Verification ==="
    echo "  dpkg --audit..."
    dpkg --audit 2>&1 || true
    echo "  containerd: $(systemctl is-active containerd 2>/dev/null || echo 'N/A')"
    echo "  kubelet: $(systemctl is-active kubelet 2>/dev/null || echo 'N/A')"
    if command -v kubectl &>/dev/null; then
        kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "  0 nodes Ready"
    fi
    echo "  disk: $(df -h / | tail -1 | awk '{print $5}')"
echo "__SBOS__STEP_OK__ repair-verify"
