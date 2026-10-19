#!/usr/bin/env bash
# task_catalog.sh — modsecurity WAF OWASP CRS (S16-webserver)
# BC-13 · ConfigBundle (módulo nginx) · sbos-web · ADR-022
# R16: sin paths hardcodeados — modsecurity no tiene pod propio

set -euo pipefail

SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S16-webserver/modsecurity}"
SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-web}"
MODSEC_PARANOIA="${MODSEC_PARANOIA:-2}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"

    # ConfigMap con configuración modsecurity (cargada por nginx como módulo)
    kubectl create configmap modsecurity-config \
        -n "${SBOS_NAMESPACE}" \
        --from-literal=modsecurity.conf="
SecRuleEngine On
SecRequestBodyAccess On
SecResponseBodyAccess Off
SecAuditEngine RelevantOnly
SecAuditLogParts ABCFHZ
SecAuditLog /var/log/nginx/modsec_audit.log
SecPcreMatchLimit 1000
SecPcreMatchLimitRecursion 1000
" \
        --from-literal=crs-setup.conf="
SecDefaultAction \"phase:1,log,auditlog,deny,status:403\"
SecDefaultAction \"phase:2,log,auditlog,deny,status:403\"
SecAction \"id:900000,phase:1,nolog,pass,t:none,setvar:tx.paranoia_level=${MODSEC_PARANOIA}\"
" \
        --dry-run=client -o yaml | kubectl apply -f -

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    # modsecurity se activa recargando nginx con la nueva configuración
    kubectl rollout restart deployment/nginx -n "${SBOS_NAMESPACE}"
    kubectl rollout status deployment/nginx -n "${SBOS_NAMESPACE}" --timeout=120s
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
    ficha_pre_install
    kubectl exec -n "${SBOS_NAMESPACE}" deployment/nginx -- nginx -s reload 2>/dev/null || \
        kubectl rollout restart deployment/nginx -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl exec -n "${SBOS_NAMESPACE}" deployment/nginx -- \
        nginx -t 2>/dev/null && \
    kubectl exec -n "${SBOS_NAMESPACE}" deployment/nginx -- \
        nginx -s reload 2>/dev/null || \
        { echo "ERROR: configuración nginx inválida — no recargando" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete configmap modsecurity-config -n "${SBOS_NAMESPACE}" --ignore-not-found
    # Recargar nginx sin modsecurity
    kubectl rollout restart deployment/nginx -n "${SBOS_NAMESPACE}" 2>/dev/null || true
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    kubectl exec -n "${SBOS_NAMESPACE}" deployment/nginx -- \
        nginx -T 2>/dev/null | grep -q "modsecurity" || \
        { echo "ADVERTENCIA: modsecurity no detectado en configuración nginx activa" >&2; }
    kubectl get configmap modsecurity-config -n "${SBOS_NAMESPACE}" >/dev/null || \
        { echo "ERROR: ConfigMap modsecurity-config no existe" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} health"
}

# ── describe ───────────────────────────────────────────────────
ficha_describe() {
    echo "=== modsecurity WAF OWASP CRS (módulo nginx) ==="
    echo "Paranoia level: ${MODSEC_PARANOIA}"
    kubectl get configmap modsecurity-config -n "${SBOS_NAMESPACE}" 2>/dev/null || true
    echo "Últimas líneas de audit log:"
    kubectl exec -n "${SBOS_NAMESPACE}" deployment/nginx -- \
        tail -20 /var/log/nginx/modsec_audit.log 2>/dev/null || true
}
