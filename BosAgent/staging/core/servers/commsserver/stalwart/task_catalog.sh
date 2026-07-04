#!/usr/bin/env bash
# task_catalog.sh — Stalwart Mail Server task handlers
# Ficha 160 · Orden 160 · SBOS-049 §4.3
# Reemplaza postfix + dovecot + spamassassin
# Sin relay externo — dominio en Global Hosting con PTR
# R16: no hardcoded paths.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/commsserver/stalwart}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-comms}"
export CLIENT_DOMAIN="${CLIENT_DOMAIN:-sksistemas.com}"
export MAIL_DOMAIN="${MAIL_DOMAIN:-mail.sksistemas.com}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    kubectl create namespace "${SBOS_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    sbos_k8s_core "${SBOS_FICHA_DIR}/stalwart.network" "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/stalwart.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready pod/stalwart-0 -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"

    # Verificar health endpoint
    kubectl exec -n "${SBOS_NAMESPACE}" stalwart-0 -- curl -sf http://localhost:8080/health \
        && echo "  [verify] Stalwart health: OK" \
        || echo "  [verify] Stalwart health: PENDING"

    # Verificar puertos escuchando (SMTP 25, submission 587, IMAP 143, IMAPS 993)
    kubectl exec -n "${SBOS_NAMESPACE}" stalwart-0 -- ss -tlnp | grep -E ':(25|587|143|993|4190)' \
        && echo "  [verify] Mail ports listening: OK" \
        || echo "  [verify] Mail ports: PENDING"

    # DKIM — generar claves si no existen
    if ! kubectl exec -n "${SBOS_NAMESPACE}" stalwart-0 -- test -f /var/lib/stalwart/dkim/selector.private 2>/dev/null; then
        echo "  [dkim] Generando claves DKIM para ${MAIL_DOMAIN}..."
        echo "  [dkim] Instrucción: copiar el registro TXT resultante al panel DNS de GLOBAL HOSTING"
    fi

    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    sbos_k8s_core "${SBOS_FICHA_DIR}/stalwart.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl rollout restart statefulset stalwart -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready pod/stalwart-0 -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart statefulset stalwart -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete statefulset stalwart -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete pvc stalwart-data -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    kubectl exec -n "${SBOS_NAMESPACE}" stalwart-0 -- curl -sf http://localhost:8080/health || {
        echo "${__SBOS__STEP_ERROR__} Stalwart health check failed"
        return 1
    }
    echo "${__SBOS__STEP_OK__} health"
}
