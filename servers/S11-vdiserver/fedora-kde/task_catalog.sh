#!/usr/bin/env bash
# task_catalog.sh — Fedora KDE Desktop (webtop noVNC)
# BC-11 · Order 355 · Deployment · sbos-vdi
# R16: sin paths hardcodeados — todo desde env vars con defaults

set -euo pipefail

SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/vdiserver/fedora-kde}"
SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-vdi}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"

    # Secret con credenciales del escritorio (Vault → secret o generadas)
    local user="${FEDORA_KDE_USER:-usuario}"
    local pass="${FEDORA_KDE_PASS:-$(openssl rand -base64 12)}"
    kubectl create secret generic fedora-kde-secret \
        -n "${SBOS_NAMESPACE}" \
        --from-literal=username="${user}" \
        --from-literal=password="${pass}" \
        --dry-run=client -o yaml | kubectl apply -f -

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/fedora-kde.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl rollout status deployment/fedora-kde \
        -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    ficha_health
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart deployment/fedora-kde -n "${SBOS_NAMESPACE}"
    kubectl rollout status deployment/fedora-kde -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart deployment/fedora-kde -n "${SBOS_NAMESPACE}"
    kubectl rollout status deployment/fedora-kde -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment fedora-kde -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete service fedora-kde -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete secret fedora-kde-secret -n "${SBOS_NAMESPACE}" --ignore-not-found
    # PVC se conserva (datos del usuario — Retain)
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    local pod
    pod=$(kubectl get pod -n "${SBOS_NAMESPACE}" -l app=fedora-kde \
          -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    [[ -n "${pod}" ]] || { echo "ERROR: ningún pod fedora-kde encontrado" >&2; return 1; }
    kubectl exec -n "${SBOS_NAMESPACE}" "${pod}" -- \
        curl -sf http://localhost:3000/ >/dev/null || \
        { echo "ERROR: noVNC no responde en :3000" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} health"
}

# ── describe ───────────────────────────────────────────────────
ficha_describe() {
    echo "=== Fedora KDE Desktop (noVNC) ==="
    kubectl get deployment fedora-kde -n "${SBOS_NAMESPACE}" 2>/dev/null || true
    kubectl get pvc fedora-kde-home -n "${SBOS_NAMESPACE}" 2>/dev/null || true
}
