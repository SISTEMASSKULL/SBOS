#!/usr/bin/env bash
# task_catalog.sh — nginx Web Proxy Multi-tenant (S16-webserver)
# BC-13 · Deployment K8s · sbos-web · ADR-022
# R16: sin paths hardcodeados

set -euo pipefail

SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S16-webserver/nginx}"
SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-web}"
SBOS_DOMAIN="${SBOS_DOMAIN:-sbos.app}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"

    # ConfigMap base de nginx (virtual host por defecto + healthz)
    kubectl create configmap nginx-base-config \
        -n "${SBOS_NAMESPACE}" \
        --from-literal=healthz.conf='
server {
    listen 80;
    server_name _;
    location /healthz { return 200 "ok\n"; add_header Content-Type text/plain; }
    location / { return 301 https://$host$request_uri; }
}' \
        --dry-run=client -o yaml | kubectl apply -f -

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/nginx.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl rollout status deployment/nginx -n "${SBOS_NAMESPACE}" --timeout=300s
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
    kubectl rollout restart deployment/nginx -n "${SBOS_NAMESPACE}"
    kubectl rollout status deployment/nginx -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    # Reload de configuración sin reinicio (preserva conexiones activas)
    kubectl exec -n "${SBOS_NAMESPACE}" deployment/nginx -- \
        nginx -t && \
    kubectl exec -n "${SBOS_NAMESPACE}" deployment/nginx -- \
        nginx -s reload 2>/dev/null || \
    kubectl rollout restart deployment/nginx -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment nginx -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete service nginx -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete configmap nginx-base-config -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    kubectl exec -n "${SBOS_NAMESPACE}" deployment/nginx -- \
        curl -sf http://localhost/healthz >/dev/null || \
        { echo "ERROR: nginx /healthz no responde" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} health"
}

# ── describe ───────────────────────────────────────────────────
ficha_describe() {
    echo "=== nginx Web Proxy Multi-tenant ==="
    kubectl get deployment nginx -n "${SBOS_NAMESPACE}" 2>/dev/null || true
    echo "Dominios activos:"
    kubectl get configmap -n "${SBOS_NAMESPACE}" -l sbos.io/vhost=true \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true
}
