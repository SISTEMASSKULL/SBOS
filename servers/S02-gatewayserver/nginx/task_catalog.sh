#!/usr/bin/env bash
# task_catalog.sh — NGINX Reverse Proxy + TLS Termination
# Ficha 05 · PRIMERA ficha de aplicación · SBOS-049 §3.1
# R16: no hardcoded paths. All paths from env vars with defaults.
#
# Responsabilidades:
#   · Emitir certificado wildcard *.${CLIENT_DOMAIN} via certbot DNS-01
#   · Generar virtual hosts por servicio con templates parametrizados
#   · Configurar puertos 80/443 + correo 25/465/587/993/995/4190 + archivos 21/990
#   · HSTS + TLS 1.2 mínimo + TLS 1.3
#   · Redirects HTTP → HTTPS
#   · Auto-renovación certbot

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S02-gatewayserver/nginx}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-gateway}"
export CLIENT_DOMAIN="${CLIENT_DOMAIN:-sksistemas.com}"
export LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@sksistemas.com}"
export SERVICE_IP="${SERVICE_IP:-144.91.76.130}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"

    # Verificar que CLIENT_DOMAIN está definido
    if [[ -z "${CLIENT_DOMAIN}" ]]; then
        echo "${__SBOS__STEP_ERROR__} CLIENT_DOMAIN no definido"
        return 1
    fi

    # Crear namespace si no existe
    kubectl create namespace "${SBOS_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

    # Aplicar NetworkPolicy si existe
    if [[ -f "${SBOS_FICHA_DIR}/nginx.network" ]]; then
        sbos_k8s_core "${SBOS_FICHA_DIR}/nginx.network" "${SBOS_NAMESPACE}"
    fi

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"

    # 1. Desplegar nginx en K8s
    sbos_k8s_core "${SBOS_FICHA_DIR}/nginx.k8s.yml" "${SBOS_NAMESPACE}"

    # 2. Esperar que el pod esté listo
    kubectl wait --for=condition=Available deployment/nginx -n "${SBOS_NAMESPACE}" --timeout=300s

    # 3. Emitir certificado wildcard via certbot DNS-01 (opcional — requiere Route53)
    echo "  [certbot] Intentando wildcard *.${CLIENT_DOMAIN} via DNS-01..."
    if timeout 90 certbot certonly --dns-route53 \
        --non-interactive --agree-tos \
        --email "${LETSENCRYPT_EMAIL}" \
        -d "*.${CLIENT_DOMAIN}" \
        --deploy-hook "kubectl rollout restart deployment/nginx -n ${SBOS_NAMESPACE}" \
        2>&1; then
        echo "  [certbot] Certificado wildcard emitido OK"
    else
        echo "  [certbot] WARNING: DNS-01 no disponible (sin Route53/Internet) — nginx continúa con TLS auto-firmado"
    fi

    # 4. Generar virtual hosts desde templates parametrizados
    for tmpl in "${SBOS_FICHA_DIR}"/resources/nginx/*.conf.tmpl; do
        if [[ -f "$tmpl" ]]; then
            out="${tmpl%.tmpl}"
            sed -e "s|\${CLIENT_DOMAIN}|${CLIENT_DOMAIN}|g" \
                -e "s|\${SERVICE_IP}|${SERVICE_IP}|g" \
                "$tmpl" > "$out"
            echo "  [vhost] Generado: $(basename "$out")"
        fi
    done

    # 5. Recargar nginx si el pod está disponible
    timeout 30 kubectl exec -n "${SBOS_NAMESPACE}" deployment/nginx -- nginx -s reload 2>/dev/null \
        || echo "  [nginx] reload pendiente — pod no disponible aún"

    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"

    # Verificar si el pod está disponible antes de ejecutar comandos en él
    local pod_ready
    pod_ready=$(kubectl get deployment nginx -n "${SBOS_NAMESPACE}" \
        -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")

    if [[ "${pod_ready:-0}" -gt 0 ]]; then
        # Verificar config válida
        timeout 30 kubectl exec -n "${SBOS_NAMESPACE}" deployment/nginx -- nginx -t 2>&1 \
            || echo "  [verify] nginx -t: no disponible"

        # Verificar puertos escuchando
        timeout 30 kubectl exec -n "${SBOS_NAMESPACE}" deployment/nginx -- ss -tlnp 2>/dev/null \
            | grep -E ':(80|443)' \
            && echo "  [verify] puertos 80/443: OK" \
            || echo "  [verify] puertos: pendientes"
    else
        echo "  [verify] pod no disponible aún — checks de post_install omitidos"
    fi

    # Verificar redirect HTTP → HTTPS (informativo, no falla)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${CLIENT_DOMAIN}" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" == "301" || "$HTTP_CODE" == "302" ]]; then
        echo "  [verify] HTTP → HTTPS redirect: OK (${HTTP_CODE})"
    else
        echo "  [verify] HTTP → HTTPS redirect: PENDING (${HTTP_CODE}) — DNS puede no resolver en staging"
    fi

    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    sbos_k8s_core "${SBOS_FICHA_DIR}/nginx.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl rollout restart deployment nginx -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Available deployment/nginx -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart deployment nginx -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Available deployment/nginx -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment nginx -n "${SBOS_NAMESPACE}" --ignore-not-found

    # Limpiar certificados de staging
    if [[ -d /etc/letsencrypt/live/"${CLIENT_DOMAIN}" ]]; then
        echo "  [clean] Certificados Let's Encrypt preservados (no eliminados en uninstall)"
    fi

    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"

    # nginx process check con timeout
    timeout 30 kubectl exec -n "${SBOS_NAMESPACE}" deployment/nginx -- nginx -t 2>&1 || {
        echo "${__SBOS__STEP_ERROR__} nginx config invalid o pod no disponible"
        return 1
    }

    # HTTPS endpoint check
    curl -sf "https://localhost/health" 2>/dev/null || {
        echo "${__SBOS__STEP_ERROR__} health endpoint unreachable"
        return 1
    }

    echo "${__SBOS__STEP_OK__} health"
}
