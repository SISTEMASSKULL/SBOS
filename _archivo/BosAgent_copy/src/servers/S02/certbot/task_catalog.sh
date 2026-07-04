#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — certbot (HOST S02)
# Iteración 1: Certbot en host. HTTP-01 challenge vía webroot nginx,
#              systemd timer renovación semanal, staging Let's Encrypt.
# Dependencias: nginx (debe estar corriendo en :80)
#
# ⚠️  Esta ficha corre en el HOST, no en un pod. Usa apt, systemd, /etc/letsencrypt.
# ⚠️  NO usa kubectl — el runtime es bash puro en el sistema operativo.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/certbot.log}"
readonly CERTBOT_CERTS="/etc/letsencrypt"
readonly CERTBOT_WEBROOT="/var/www/certbot"
readonly CERTBOT_SCRIPT="/usr/local/sbin/sbos-certbot-renew.sh"
readonly DOMAIN="${SBOS_DOMAIN:-sbos.sksistemas.com}"
readonly EMAIL="${SBOS_ADMIN_EMAIL:-admin@sksistemas.com}"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [certbot] $*" | tee -a "$FICHA_LOG" >&2; }

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_root"
    if [[ $EUID -ne 0 ]]; then
        echo "${__STEP_FAIL__} verificar_root: se requiere root para instalar certbot en el host"
        return 1
    fi
    echo "${__STEP_OK__} verificar_root"

    echo "${__STEP_START__} verificar_nginx"
    if systemctl is-active nginx > /dev/null 2>&1; then
        echo "${__STEP_OK__} verificar_nginx (systemd active)"
    else
        _log "ADVERTENCIA: nginx no está corriendo — HTTP-01 challenge no funcionará"
        echo "${__STEP_SKIP__} verificar_nginx: nginx inactivo (certbot fallará sin :80)"
    fi

    echo "${__STEP_START__} verificar_dominio_resoluble"
    if command -v dig > /dev/null 2>&1; then
        if dig +short "$DOMAIN" A 2>/dev/null | grep -q "."; then
            echo "${__STEP_OK__} verificar_dominio_resoluble ($DOMAIN)"
        else
            _log "ADVERTENCIA: $DOMAIN no resuelve a una IP — Let's Encrypt no podrá verificar"
            echo "${__STEP_SKIP__} verificar_dominio_resoluble: $DOMAIN no resuelve (requiere DNS)"
        fi
    else
        echo "${__STEP_SKIP__} verificar_dominio_resoluble: dig no disponible"
    fi
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")" "$CERTBOT_CERTS" "$CERTBOT_WEBROOT"

    # ── 1. Instalar certbot vía apt ──────────────────────────────
    echo "${__STEP_START__} instalar_certbot"
    export DEBIAN_FRONTEND=noninteractive
    if ! command -v certbot > /dev/null 2>&1; then
        apt-get update -qq 2>/dev/null || _log "ADVERTENCIA: apt-get update falló (sin internet?)"
        apt-get install -y -qq certbot 2>/dev/null || {
            echo "${__STEP_FAIL__} instalar_certbot: apt-get install certbot falló"
            return 1
        }
    fi
    local certbot_ver
    certbot_ver=$(certbot --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "?")
    _log "certbot versión $certbot_ver instalado"
    echo "${__STEP_OK__} instalar_certbot (v${certbot_ver})"

    # ── 2. Crear webroot para HTTP-01 challenge ──────────────────
    echo "${__STEP_START__} crear_webroot"
    mkdir -p "${CERTBOT_WEBROOT}/.well-known/acme-challenge"
    chown -R www-data:www-data "$CERTBOT_WEBROOT" 2>/dev/null || true
    chmod 755 "$CERTBOT_WEBROOT"
    echo "${__STEP_OK__} crear_webroot"

    # ── 3. Añadir location /.well-known a nginx ───────────────────
    echo "${__STEP_START__} configurar_nginx_acme"
    # Añadir el bloque acme-challenge en el server :80 si no existe
    if [[ -f /etc/nginx/sites-enabled/default ]]; then
        if ! grep -q "acme-challenge" /etc/nginx/sites-enabled/default 2>/dev/null; then
            # Insertar antes del location / {
            sed -i '/location \/ {/i \
    # ACME challenge para Let'"'"'s Encrypt (certbot HTTP-01)\
    location /.well-known/acme-challenge/ {\
        root /var/www/certbot;\
        default_type text/plain;\
    }\
' /etc/nginx/sites-enabled/default 2>/dev/null || true
            _log "Bloque acme-challenge añadido a nginx"
            systemctl reload nginx 2>/dev/null || true
        fi
    fi
    echo "${__STEP_OK__} configurar_nginx_acme"

    # ── 4. Script de renovación ───────────────────────────────────
    echo "${__STEP_START__} crear_script_renovacion"
    cat > "$CERTBOT_SCRIPT" <<'SCRIPT_EOF'
#!/bin/bash
# SBOS certbot renewal script
# Ejecutado semanalmente por systemd timer.

set -e
LOG="/var/log/letsencrypt/renew.log"
mkdir -p "$(dirname "$LOG")"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] certbot renew iniciado" | tee -a "$LOG"

# Renovar todos los certificados
certbot renew \
    --webroot -w /var/www/certbot \
    --non-interactive \
    --quiet \
    --max-log-backups 10 \
    2>&1 | tee -a "$LOG" || {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] certbot renew FALLÓ" | tee -a "$LOG"
    exit 1
}

# Recargar nginx si los certificados cambiaron
if systemctl is-active nginx > /dev/null 2>&1; then
    systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] nginx recargado" | tee -a "$LOG"
fi

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] certbot renew completado" | tee -a "$LOG"
SCRIPT_EOF
    chmod 755 "$CERTBOT_SCRIPT"
    echo "${__STEP_OK__} crear_script_renovacion"

    # ── 5. systemd timer para renovación ──────────────────────────
    echo "${__STEP_START__} crear_systemd_timer"

    cat > /etc/systemd/system/certbot-renew.service <<'UNIT_EOF'
[Unit]
Description=SBOS Certbot Renewal
Documentation=https://eff.org/certbot
After=network.target nginx.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/sbos-certbot-renew.sh
User=root
StandardOutput=journal
StandardError=journal
UNIT_EOF

    cat > /etc/systemd/system/certbot-renew.timer <<'TIMER_EOF'
[Unit]
Description=SBOS Certbot Weekly Renewal Timer
Documentation=https://eff.org/certbot

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=3600

[Install]
WantedBy=timers.target
TIMER_EOF

    systemctl daemon-reload 2>/dev/null || true
    systemctl enable certbot-renew.timer 2>/dev/null || true
    systemctl start certbot-renew.timer 2>/dev/null || true
    echo "${__STEP_OK__} crear_systemd_timer"

    # ── 6. Primer intento: certificado staging ────────────────────
    echo "${__STEP_START__} obtener_certificado_staging"
    if certbot certonly \
        --webroot -w "$CERTBOT_WEBROOT" \
        -d "$DOMAIN" \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --staging \
        --non-interactive \
        --max-log-backups 10 \
        2>&1 | tee -a "$FICHA_LOG"; then
        _log "Certificado staging obtenido para $DOMAIN"
        systemctl reload nginx 2>/dev/null || true
        echo "${__STEP_OK__} obtener_certificado_staging"
    else
        _log "ADVERTENCIA: certificado staging no obtenido — esperado si no hay dominio real o internet"
        echo "${__STEP_SKIP__} obtener_certificado_staging: falló (requiere dominio real + internet)"
    fi

    _log "certbot instalado en HOST S02"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado certbot:"
    if systemctl is-active certbot-renew.timer > /dev/null 2>&1; then
        _log "  timer: active"
    else
        _log "  timer: inactive"
    fi

    if [[ -d "${CERTBOT_CERTS}/live" ]]; then
        local cert_count
        cert_count=$(find "${CERTBOT_CERTS}/live" -maxdepth 1 -name "*.pem" -o -type d | wc -l)
        _log "  certificados: $((cert_count - 1)) directorio(s) en live/"
    else
        _log "  certificados: sin certificados (normal tras staging fallido)"
    fi
    _log "  webroot: ${CERTBOT_WEBROOT}"
    _log "  script: ${CERTBOT_SCRIPT}"
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reparar_certbot"

    # Verificar timer
    if ! systemctl is-active certbot-renew.timer > /dev/null 2>&1; then
        systemctl start certbot-renew.timer 2>/dev/null || true
    fi

    # Reintentar obtener certificado si no hay ninguno
    if [[ ! -d "${CERTBOT_CERTS}/live/${DOMAIN}" ]]; then
        _log "Sin certificado — reintentando staging"
        certbot certonly \
            --webroot -w "$CERTBOT_WEBROOT" \
            -d "$DOMAIN" \
            --email "$EMAIL" \
            --agree-tos \
            --no-eff-email \
            --staging \
            --non-interactive 2>&1 | tee -a "$FICHA_LOG" || \
            _log "Staging falló nuevamente — requiere dominio real e internet"
    fi

    echo "${__STEP_OK__} reparar_certbot"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_certbot_instalado"
    if command -v certbot > /dev/null 2>&1; then
        echo "${__STEP_OK__} test_certbot_instalado ($(certbot --version 2>&1 | head -c 30))"
    else
        echo "${__STEP_FAIL__} test_certbot_instalado"
        ok=1
    fi

    echo "${__STEP_START__} test_timer_active"
    if systemctl is-active certbot-renew.timer > /dev/null 2>&1; then
        echo "${__STEP_OK__} test_timer_active"
    else
        echo "${__STEP_FAIL__} test_timer_active"
        ok=1
    fi

    echo "${__STEP_START__} test_timer_enabled"
    if systemctl is-enabled certbot-renew.timer > /dev/null 2>&1; then
        echo "${__STEP_OK__} test_timer_enabled"
    else
        echo "${__STEP_FAIL__} test_timer_enabled"
        ok=1
    fi

    echo "${__STEP_START__} test_webroot"
    if [[ -d "${CERTBOT_WEBROOT}/.well-known/acme-challenge" ]]; then
        echo "${__STEP_OK__} test_webroot"
    else
        echo "${__STEP_FAIL__} test_webroot: directorio acme-challenge no existe"
        ok=1
    fi

    echo "${__STEP_START__} test_script_renovacion"
    if [[ -x "$CERTBOT_SCRIPT" ]]; then
        echo "${__STEP_OK__} test_script_renovacion"
    else
        echo "${__STEP_FAIL__} test_script_renovacion"
        ok=1
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== certbot STATUS (HOST S02) ==="
    echo ""
    echo "Versión: $(certbot --version 2>/dev/null || echo 'no instalado')"
    echo "Timer:   $(systemctl is-active certbot-renew.timer 2>/dev/null || echo 'inactive')"
    echo "Webroot: ${CERTBOT_WEBROOT}"
    echo "Certs:   ${CERTBOT_CERTS}/live/"
    echo ""
    if [[ -d "${CERTBOT_CERTS}/live" ]]; then
        ls -la "${CERTBOT_CERTS}/live/" 2>/dev/null | awk 'NR>1 {printf "  %s\n", $0}' || echo "  (vacío)"
    else
        echo "  (sin certificados)"
    fi
    echo ""
    echo "Próxima renovación:"
    systemctl list-timers certbot-renew.timer 2>/dev/null | tail -1 || echo "  (no disponible)"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando certbot del host"
    echo "${__STEP_START__} detener_timer"
    systemctl stop certbot-renew.timer 2>/dev/null || true
    systemctl disable certbot-renew.timer 2>/dev/null || true
    rm -f /etc/systemd/system/certbot-renew.service 2>/dev/null || true
    rm -f /etc/systemd/system/certbot-renew.timer 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    echo "${__STEP_OK__} detener_timer"

    echo "${__STEP_START__} eliminar_scripts"
    rm -f "$CERTBOT_SCRIPT" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_scripts"

    echo "${__STEP_START__} eliminar_certs"
    # Respaldar antes de eliminar
    if [[ -d "$CERTBOT_CERTS" ]]; then
        tar -czf "/tmp/certbot-backup-$(date +%Y%m%d_%H%M%S).tar.gz" -C /etc letsencrypt 2>/dev/null || true
        rm -rf "$CERTBOT_CERTS" 2>/dev/null || true
        _log "Certificados respaldados y eliminados"
    fi
    echo "${__STEP_OK__} eliminar_certs"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico certbot (HOST S02) ==="
    echo "Timer status:"
    systemctl status certbot-renew.timer --no-pager -l 2>/dev/null | head -15 || echo "  no disponible"
    echo ""
    echo "Última renovación:"
    journalctl -u certbot-renew.service --no-pager -n 20 2>/dev/null || echo "  sin logs"
    echo ""
    echo "Certificados existentes:"
    if command -v certbot > /dev/null 2>&1; then
        certbot certificates 2>/dev/null || echo "  ninguno"
    fi
    echo ""
    echo "Webroot:"
    ls -la "$CERTBOT_WEBROOT"/.well-known/acme-challenge/ 2>/dev/null || echo "  vacío o no existe"
}
